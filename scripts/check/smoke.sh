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
#   3. VARIANTS -- stage 2 again for every entry of SMOKE_VARIANTS
#      (scripts/project_config.sh), each a set of parameter overrides passed
#      as -D: extreme sizes, every dropdown option, optional features on and
#      off. Same failures as stage 2; an empty plate or preview is reported,
#      not failed, since a variant may switch a part off.
#
#   CLEARANCE CHECKS -- with the defaults and with every variant, each
#      CLEARANCE_CHECKS entry (scripts/project_config.sh) intersects two
#      OpenSCAD expressions evaluated in the shipped bundle and expects the
#      result to be "empty" (they never touch: a moving part clears the
#      body, a lid slides in) or "solid" (they do: a latch holds, a peg
#      blocks). Catches collisions no plate-size check can see.
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

# export <label> <scad file> <stl out> [openscad args]  -> 0 ok, 1 failed, 2 empty
export_stl() {
    local log="$WORKDIR/log.txt"
    "$OPENSCAD" --render "${@:4}" -o "$3" "$2" > "$log" 2>&1
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

# Builds every output of the shipped bundle -- each mw_plate_N() (footprint
# checked against mw_plate_size), the top-level call of a plate-less bundle,
# and mw_assembly_view() when views are configured -- with the given
# OpenSCAD args (-D overrides). $1 is a tag for the messages ("" = defaults).
check_outputs() {
    local tag="$1"; shift
    local pre="" what="default parameters"
    [ -n "$tag" ] && { pre="[$tag] "; what="these parameters"; }

    if [ -z "$plates" ]; then
        if [ -n "${MAKERWORLD_TOP_LEVEL_CALL:-}" ]; then
            export_stl bundle "$BUNDLE" "$WORKDIR/bundle.stl" "$@"
            case $? in
                0) echo "  ok     ${pre}top-level call" ;;
                2) echo "  empty  ${pre}top-level call  (renders nothing with $what)" ;;
                *) echo "  FAIL   ${pre}top-level call"; failures=$((failures + 1)) ;;
            esac
        fi
    fi
    local plate wrapper over dx dy dz
    for plate in $plates; do
        wrapper="$WORKDIR/${plate}.scad"
        printf 'include <%s>\n%s();\n' "$abs_bundle" "$plate" > "$wrapper"
        export_stl "$plate" "$wrapper" "$WORKDIR/${plate}.stl" "$@"
        case $? in
            0)
                read -r dx dy dz < <("$PYTHON" "$SCRIPTS_DIR/shared/stl_bbox.py" --extents "$WORKDIR/${plate}.stl" | tr -d '\r') || true
                over="$(awk -v x="$dx" -v y="$dy" -v s="${plate_size:-0}" 'BEGIN { print (s > 0 && (x > s || y > s)) ? 1 : 0 }')"
                if [ "$over" = "1" ]; then
                    echo "  FAIL   ${pre}$plate  footprint ${dx} x ${dy} mm exceeds mw_plate_size ${plate_size}"
                    failures=$((failures + 1))
                else
                    echo "  ok     ${pre}$plate  (${dx} x ${dy} x ${dz} mm)"
                fi
                ;;
            2) echo "  empty  ${pre}$plate  (renders nothing with $what -- fine if intended)" ;;
            *) echo "  FAIL   ${pre}$plate"; failures=$((failures + 1)) ;;
        esac
    done

    # Assembly preview: must compile and show something when views are
    # configured. No size check -- a preview may be larger than the bed.
    if [ "$has_views" = "1" ]; then
        wrapper="$WORKDIR/mw_assembly_view.scad"
        printf 'include <%s>\nmw_assembly_view();\n' "$abs_bundle" > "$wrapper"
        export_stl mw_assembly_view "$wrapper" "$WORKDIR/mw_assembly_view.stl" "$@"
        case $? in
            0)
                read -r dx dy dz < <("$PYTHON" "$SCRIPTS_DIR/shared/stl_bbox.py" --extents "$WORKDIR/mw_assembly_view.stl" | tr -d '\r') || true
                echo "  ok     ${pre}mw_assembly_view  (${dx} x ${dy} x ${dz} mm; ${views_line%%;*})"
                ;;
            2)
                if [ -n "$tag" ]; then
                    echo "  empty  ${pre}mw_assembly_view  (renders nothing with $what)"
                else
                    echo "  FAIL   mw_assembly_view renders nothing although views are configured"
                    failures=$((failures + 1))
                fi
                ;;
            *) echo "  FAIL   ${pre}mw_assembly_view"; failures=$((failures + 1)) ;;
        esac
    fi
}

# Runs every CLEARANCE_CHECKS entry ("name|expression A|expression B|empty
# or solid") against the shipped bundle, with the given OpenSCAD args.
# $1 is a tag for the messages ("" = defaults).
check_clearances() {
    local tag="$1"; shift
    local pre=""
    [ -n "$tag" ] && pre="[$tag] "
    local entry name rest a b expect wrapper got
    for entry in "${CLEARANCE_CHECKS[@]}"; do
        IFS='|' read -r name a b expect <<< "$entry"
        expect="$(echo "$expect" | tr -d '[:space:]')"
        if [ "$expect" != "empty" ] && [ "$expect" != "solid" ]; then
            echo "  FAIL   CLEARANCE_CHECKS \"$name\": last field must be empty or solid"
            failures=$((failures + 1)); continue
        fi
        wrapper="$WORKDIR/clearance.scad"
        # Each side in its own union(): OpenSCAD drops an `if` whose condition
        # is false from a node's children, so `intersection() { A; if (c) B; }`
        # would return all of A when c is false. A union with nothing in it
        # is an empty child instead, and the intersection is empty.
        printf 'include <%s>\nintersection() {\n    union() { %s }\n    union() { %s }\n}\n' \
            "$clearance_bundle" "$a" "$b" > "$wrapper"
        export_stl clearance "$wrapper" "$WORKDIR/clearance.stl" "$@"
        case $? in
            0) got="solid" ;;
            2) got="empty" ;;
            *) echo "  FAIL   ${pre}clearance: $name (did not compile)"; failures=$((failures + 1)); continue ;;
        esac
        if [ "$got" = "$expect" ]; then
            echo "  ok     ${pre}clearance: $name ($got)"
        else
            echo "  FAIL   ${pre}clearance: $name -- expected $expect, got $got"
            failures=$((failures + 1))
        fi
    done
}

echo "== Stage 2: shipped bundle ($BUNDLE)"
if [ ! -f "$BUNDLE" ]; then
    echo "  FAIL   bundle missing -- run the MakerWorld build first"
    failures=$((failures + 1))
else
    plate_size="$(sed -nE 's/^mw_plate_size = ([0-9.]+);.*/\1/p' "$BUNDLE" | head -1)"
    plates="$(sed -nE 's/^[[:space:]]*module[[:space:]]+(mw_plate_[0-9]+)[[:space:]]*\(.*/\1/p' "$BUNDLE")"
    if [ -z "$plates" ] && [ -z "${MAKERWORLD_TOP_LEVEL_CALL:-}" ]; then
        echo "  FAIL   bundle defines no mw_plate_N() and MAKERWORLD_TOP_LEVEL_CALL is empty -- PMM would render nothing"
        failures=$((failures + 1))
    fi
    abs_bundle="$(cd "$(dirname "$BUNDLE")" && pwd)/$(basename "$BUNDLE")"
    # The path is written INSIDE a file, where Git Bash's automatic path
    # conversion does not apply -- native Windows OpenSCAD needs C:/... form.
    command -v cygpath >/dev/null 2>&1 && abs_bundle="$(cygpath -m "$abs_bundle")"
    views_line="$(grep -E '^mw_assembly_views = ' "$BUNDLE" | head -1)"
    has_views=0
    if grep -qE '^[[:space:]]*module[[:space:]]+mw_assembly_view[[:space:]]*\(' "$BUNDLE" \
            && [ -n "$views_line" ] && ! echo "$views_line" | grep -q '= \[\]'; then
        has_views=1
    fi

    # Clearance checks include the bundle: a plate-less bundle's own
    # top-level call would add its part to every intersection, so they use
    # a copy without that line.
    clearance_bundle="$abs_bundle"
    if [ -n "${CLEARANCE_CHECKS[*]:-}" ] && [ -z "$plates" ] && [ -n "${MAKERWORLD_TOP_LEVEL_CALL:-}" ]; then
        grep -vxF "$MAKERWORLD_TOP_LEVEL_CALL" "$BUNDLE" > "$WORKDIR/bundle_no_call.scad"
        clearance_bundle="$WORKDIR/bundle_no_call.scad"
        command -v cygpath >/dev/null 2>&1 && clearance_bundle="$(cygpath -m "$clearance_bundle")"
    fi

    check_outputs ""
    [ -n "${CLEARANCE_CHECKS[*]:-}" ] && check_clearances ""

    # ---- Stage 3: parameter variants (SMOKE_VARIANTS) ----
    # Entry: "name|param=value; param=value; ...". Each assignment becomes
    # one -D, so values may contain spaces; strings keep their quotes.
    if [ -n "${SMOKE_VARIANTS[*]:-}" ]; then
        echo "== Stage 3: parameter variants (SMOKE_VARIANTS)"
        for entry in "${SMOKE_VARIANTS[@]}"; do
            name="${entry%%|*}"
            vargs=()
            IFS=';' read -ra assignments <<< "${entry#*|}"
            for a in "${assignments[@]}"; do
                a="$(echo "$a" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
                [ -n "$a" ] && vargs+=(-D "$a")
            done
            check_outputs "$name" "${vargs[@]}"
            [ -n "${CLEARANCE_CHECKS[*]:-}" ] && check_clearances "$name" "${vargs[@]}"
        done
    fi
fi

if [ $failures -gt 0 ]; then
    echo "SMOKE: $failures failure(s)"
    exit 1
fi
echo "SMOKE: all good"
