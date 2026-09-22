#!/bin/bash
# ============================================================
# <PROJECT NAME>  |  Smoke check: does everything actually compile?
# ------------------------------------------------------------
# The cheap safety net the original project lacked. Two stages:
#
#   1. SOURCES -- every parts/*.scad and assembly/*.scad in SOURCE_FILES is
#      exported to STL on its own (i.e. through its BUILD:EXCLUDE preview
#      block). Catches syntax errors, broken include/use paths, and
#      non-manifold results OpenSCAD refuses to export.
#
#   2. SHIPPED BUNDLE -- for every mw_plate_N() defined in the MakerWorld
#      bundle, a temporary wrapper `include <bundle>; mw_plate_N();` is
#      exported, i.e. the plates are built from the EXACT file you upload.
#      Each plate's X/Y footprint is checked against mw_plate_size (the
#      oversize plates PMM fails to arrange). Empty plates are reported,
#      not failed -- a count-driven plate can legitimately be empty.
#      mw_assembly_view() is built the same way when ASSEMBLY_PLATE_VIEWS is
#      set: it must compile and not be empty (no size limit -- a preview).
#
# OpenSCAD WARNINGs are printed but do not fail the check; ERRORs and
# failed exports do. Uses a full CGAL/Manifold render, so it takes as long
# as rendering every part once.
#
# Usage:  scripts/check/smoke.sh [-p project_dir]
# Exit:   1 on any failure.
# See:    docs/toolchain/pipelines.md ("Checks")
# ============================================================
set -u

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
source "$SCRIPTS_DIR/shared/find_tools.sh"

PROJECT_DIR="$REPO_ROOT"
while [ "$#" -gt 0 ]; do
    case "$1" in
        -p|--project) PROJECT_DIR="$(cd "$REPO_ROOT" && cd "$2" && pwd)"; shift 2 ;;
        *) echo "Usage: smoke.sh [-p project_dir]" >&2; exit 1 ;;
    esac
done
require_tool OPENSCAD "OpenSCAD" "OPENSCAD_BIN"
require_tool PYTHON "Python 3" "PYTHON_BIN"

# shellcheck disable=SC1091
source "$PROJECT_DIR/scripts/project_config.sh"
cd "$PROJECT_DIR"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
failures=0

# export <label> <scad file> <stl out>  -> 0 ok, 1 failed, 2 empty
export_stl() {
    local log="$WORKDIR/log.txt"
    "$OPENSCAD" --render -o "$3" "$2" > "$log" 2>&1
    local status=$?
    grep -E "^(WARNING|DEPRECATED)" "$log" | sed "s/^/        /" | head -5
    # Unresolvable includes/modules are real failures even though OpenSCAD
    # only WARNs and then renders an (empty) result.
    if grep -qE "Can't open include file|Ignoring unknown module|Ignoring unknown function" "$log"; then
        return 1
    fi
    if grep -qiE "top level object is empty" "$log"; then
        return 2
    fi
    if [ $status -ne 0 ] || grep -q "^ERROR" "$log" || [ ! -s "$3" ]; then
        grep -E "^ERROR|error" "$log" | sed "s/^/        /" | head -5
        return 1
    fi
    return 0
}

echo "== Stage 1: sources ($PROJECT_DIR)"
for src in "${SOURCE_FILES[@]}"; do
    case "$src" in parts/*|assembly/*) ;; *) continue ;; esac
    export_stl "$src" "$src" "$WORKDIR/$(basename "$src" .scad).stl"
    case $? in
        0) echo "  ok     $src" ;;
        2) echo "  EMPTY  $src  (its BUILD:EXCLUDE preview renders nothing)"; failures=$((failures + 1)) ;;
        *) echo "  FAIL   $src"; failures=$((failures + 1)) ;;
    esac
done

BUNDLE="dist/${PROJECT_SLUG}_makerworld.scad"
echo "== Stage 2: shipped bundle ($BUNDLE)"
if [ ! -f "$BUNDLE" ]; then
    echo "  FAIL   bundle missing -- run the MakerWorld build first"
    failures=$((failures + 1))
else
    plate_size="$(sed -nE 's/^mw_plate_size = ([0-9.]+);.*/\1/p' "$BUNDLE" | head -1)"
    plates="$(sed -nE 's/^[[:space:]]*module[[:space:]]+(mw_plate_[0-9]+)[[:space:]]*\(.*/\1/p' "$BUNDLE")"
    if [ -z "$plates" ]; then
        if [ -n "${MAKERWORLD_TOP_LEVEL_CALL:-}" ]; then
            export_stl bundle "$BUNDLE" "$WORKDIR/bundle.stl"
            [ $? -eq 0 ] && echo "  ok     top-level call" || { echo "  FAIL   top-level call"; failures=$((failures + 1)); }
        else
            echo "  FAIL   bundle defines no mw_plate_N() and MAKERWORLD_TOP_LEVEL_CALL is empty -- PMM would render nothing"
            failures=$((failures + 1))
        fi
    fi
    abs_bundle="$(cd "$(dirname "$BUNDLE")" && pwd)/$(basename "$BUNDLE")"
    # The path is written INSIDE a file, where Git Bash's automatic path
    # conversion does not apply -- native Windows OpenSCAD needs C:/... form.
    command -v cygpath >/dev/null 2>&1 && abs_bundle="$(cygpath -m "$abs_bundle")"
    for plate in $plates; do
        wrapper="$WORKDIR/${plate}.scad"
        printf 'include <%s>\n%s();\n' "$abs_bundle" "$plate" > "$wrapper"
        export_stl "$plate" "$wrapper" "$WORKDIR/${plate}.stl"
        case $? in
            0)
                read -r dx dy dz < <("$PYTHON" "$SCRIPTS_DIR/shared/stl_bbox.py" --extents "$WORKDIR/${plate}.stl" | tr -d '\r') || true
                over="$(awk -v x="$dx" -v y="$dy" -v s="${plate_size:-0}" 'BEGIN { print (s > 0 && (x > s || y > s)) ? 1 : 0 }')"
                if [ "$over" = "1" ]; then
                    echo "  FAIL   $plate  footprint ${dx} x ${dy} mm exceeds mw_plate_size ${plate_size}"
                    failures=$((failures + 1))
                else
                    echo "  ok     $plate  (${dx} x ${dy} x ${dz} mm)"
                fi
                ;;
            2) echo "  empty  $plate  (renders nothing with default parameters -- fine if intended)" ;;
            *) echo "  FAIL   $plate"; failures=$((failures + 1)) ;;
        esac
    done

    # Assembly preview: must compile and show something when views are
    # configured. No size check -- a preview may be larger than the bed.
    views_line="$(grep -E '^mw_assembly_views = ' "$BUNDLE" | head -1)"
    if grep -qE '^[[:space:]]*module[[:space:]]+mw_assembly_view[[:space:]]*\(' "$BUNDLE" \
            && [ -n "$views_line" ] && ! echo "$views_line" | grep -q '= \[\]'; then
        wrapper="$WORKDIR/mw_assembly_view.scad"
        printf 'include <%s>\nmw_assembly_view();\n' "$abs_bundle" > "$wrapper"
        export_stl mw_assembly_view "$wrapper" "$WORKDIR/mw_assembly_view.stl"
        case $? in
            0)
                read -r dx dy dz < <("$PYTHON" "$SCRIPTS_DIR/shared/stl_bbox.py" --extents "$WORKDIR/mw_assembly_view.stl" | tr -d '\r') || true
                echo "  ok     mw_assembly_view  (${dx} x ${dy} x ${dz} mm; ${views_line%%;*})"
                ;;
            2) echo "  FAIL   mw_assembly_view renders nothing although views are configured"; failures=$((failures + 1)) ;;
            *) echo "  FAIL   mw_assembly_view"; failures=$((failures + 1)) ;;
        esac
    fi
fi

if [ $failures -gt 0 ]; then
    echo "SMOKE: $failures failure(s)"
    exit 1
fi
echo "SMOKE: all good"
