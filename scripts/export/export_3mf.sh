#!/bin/bash
# ============================================================
# <PROJECT NAME>  |  Bambu multi-plate 3MF export   (OPTIONAL PIPELINE)
# ------------------------------------------------------------
# Produces one print-ready, multi-plate .3mf from:
#   scripts/plates_config.sh     PRINTER, plates, parts, per-part overrides
#   scripts/export_3mf_config.sh parameter overrides, quality, reference
#                                settings file, global overrides, output
#
# Steps:
#   1. plates_config.sh -> .build/plates.json (shared generator) -> bash vars
#   2. resolve the real bed of PRINTER from Bambu presets (printer_bed.py)
#   3. per plate: export each part to STL (OpenSCAD); optionally auto-orient
#      a single part or the whole plate; arrange the plate with Bambu
#      Studio's own `--arrange=1` inside the real bed
#   4. if ASSEMBLY_PLATE_VIEWS is set (plates_config.sh section 3): add the
#      assembly preview as the LAST plate -- MakerWorld's mw_assembly_view()
#      layout rendered from the dev bundle, centered on the bed, NEVER arranged
#   5. merge every single-plate export into one project and graft the
#      REFERENCE_3MF print settings + overrides (assemble_3mf.py)
#
# Positions are exactly what Bambu Studio decided within each plate. The
# one adjustment is a rigid per-plate offset in world space (see
# assemble_3mf.py grid_cell()), without which Bambu Studio piles every
# object onto plate 1.
#
# `--enable-support` is passed to `--arrange`, because Bambu's arrange
# spaces support-needing objects differently; it is 1 for any plate with a
# part overriding enable_support=1, else REFERENCE_3MF's own value.
#
# Usage:
#   scripts/export/export_3mf.sh [-p project_dir] [-c export_config.sh]
# Requires: OpenSCAD, Bambu Studio, Python 3 (stdlib) -- see find_tools.sh
# See: docs/toolchain/pipelines.md ("3MF export")
# ============================================================
set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
source "$SCRIPTS_DIR/shared/find_tools.sh"

PROJECT_DIR="$REPO_ROOT"
CONFIG=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -p|--project) PROJECT_DIR="$(cd "$REPO_ROOT" && cd "$2" && pwd)"; shift 2 ;;
        -c|--config)  CONFIG="$2"; shift 2 ;;
        *) echo "Usage: export_3mf.sh [-p project_dir] [-c config.sh]" >&2; exit 1 ;;
    esac
done
CONFIG="${CONFIG:-$PROJECT_DIR/scripts/export_3mf_config.sh}"
[ -f "$CONFIG" ] || { echo "Config file not found: $CONFIG" >&2; exit 1; }

require_tool OPENSCAD "OpenSCAD" "OPENSCAD_BIN"
require_tool BAMBU_STUDIO "Bambu Studio" "BAMBU_STUDIO_BIN"
require_tool PYTHON "Python 3" "PYTHON_BIN"

# shellcheck disable=SC1090
source "$CONFIG"
# shellcheck disable=SC1091
source "$PROJECT_DIR/scripts/project_config.sh"   # PROJECT_SLUG
cd "$PROJECT_DIR"

PLATES_JSON="$PROJECT_DIR/.build/plates.json"
"$PYTHON" "$SCRIPTS_DIR/shared/generate_plates_json.py" "$PROJECT_DIR/scripts/plates_config.sh" "$PLATES_JSON"
eval "$("$PYTHON" "$SCRIPTS_DIR/shared/plates_config.py" "$PLATES_JSON" | tr -d '\r')"

[ "${#PLATE_NAMES[@]}" -gt 0 ] || { echo "PLATE_NAMES is empty in scripts/plates_config.sh" >&2; exit 1; }
[ -n "$PRINTER" ] || { echo "PRINTER is not set in scripts/plates_config.sh" >&2; exit 1; }
[ -n "$OUTPUT" ]  || { echo "OUTPUT is not set in $CONFIG" >&2; exit 1; }
[ -f "$REFERENCE_3MF" ] || { echo "REFERENCE_3MF not found: $REFERENCE_3MF" >&2; exit 1; }

echo "Resolving bed for printer: $PRINTER ..."
eval "$("$PYTHON" "$SCRIPTS_DIR/shared/printer_bed.py" "$PRINTER" | tr -d '\r')"
echo "  Bed: ${BED_WIDTH}x${BED_DEPTH} mm, height ${BED_HEIGHT} mm"

REFERENCE_ENABLE_SUPPORT="$("$PYTHON" -c "
import json, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    d = json.loads(z.read('Metadata/project_settings.config'))
print(d.get('enable_support', '0'))
" "$REFERENCE_3MF")"

if [ "${FACE_DETAIL_FN:-0}" != "0" ]; then
    QUALITY_ARGS=(-D "\$fn=${FACE_DETAIL_FN}")
else
    QUALITY_ARGS=(-D "\$fn=0" -D "\$fa=${FACE_DETAIL_FA:-2}" -D "\$fs=${FACE_DETAIL_FS:-0.4}")
fi
PARAM_ARGS=()
for override in "${PARAM_OVERRIDES[@]}"; do PARAM_ARGS+=(-D "$override"); done
SET_ARGS=()
for override in "${PRINT_SETTINGS_OVERRIDES[@]}"; do SET_ARGS+=(--set "$override"); done
OBJECT_SET_ARGS=()

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

BED_EXCLUDE_ARGS=()
[ -n "$BED_EXCLUDE_AREA" ] && BED_EXCLUDE_ARGS=(--bed-exclude-area="$BED_EXCLUDE_AREA")

# One Bambu Studio CLI call turning a plate's STLs into a single-plate 3mf
# (plate.3mf in that plate's dir) -- shared by the regular plates and the
# assembly preview plate.
#   $1 plate dir   $2 --enable-support value   $3 orient (true/false)
#   $4 arrange (true/false)   $5.. STL file names, relative to $1
bambu_export_plate() {
    local dir="$1" enable_support="$2" orient="$3" arrange="$4"
    shift 4
    local orient_args=() arrange_args=()
    [ "$orient" = "true" ] && orient_args=(--orient=1)
    [ "$arrange" = "true" ] && arrange_args=(--arrange=1)

    (cd "$dir" && "$BAMBU_STUDIO" \
        --printable-area="$PRINTABLE_AREA" \
        --printable-height="$BED_HEIGHT" \
        "${BED_EXCLUDE_ARGS[@]}" \
        --enable-support="$enable_support" \
        "${orient_args[@]}" "${arrange_args[@]}" \
        --export-3mf="plate.3mf" \
        "$@" > /dev/null 2>&1) || true

    if [ ! -f "$dir/plate.3mf" ]; then
        echo "Bambu Studio produced no 3mf (expected: $dir/plate.3mf)" >&2
        exit 1
    fi
}

PLATE_COUNT="${#PLATE_NAMES[@]}"
ASSEMBLE_ARGS=()

for (( p=1; p<=PLATE_COUNT; p++ )); do
    plate_name="${PLATE_NAMES[$((p-1))]}"
    parts_var="PLATE_${p}_PARTS[@]";        plate_parts=("${!parts_var}")
    orient_var="PLATE_${p}_AUTO_ORIENT";    plate_auto_orient="${!orient_var:-false}"
    arrange_var="PLATE_${p}_ARRANGE";       plate_arrange="${!arrange_var:-true}"

    plate_dir="$WORKDIR/plate_$p"
    mkdir -p "$plate_dir"
    echo "[Plate $p \"$plate_name\"] exporting ${#plate_parts[@]} part(s) ..."

    unset NAME_COUNT; declare -A NAME_COUNT=()
    STL_FILES=()
    plate_enable_support="$REFERENCE_ENABLE_SUPPORT"
    for entry in "${plate_parts[@]}"; do
        src="${entry%%|*}"
        part_overrides=""
        [[ "$entry" == *"|"* ]] && part_overrides="${entry#*|}"
        [ -f "$src" ] || { echo "  Part file not found: $src" >&2; exit 1; }

        base="$(basename "$src" .scad)"
        n=$(( ${NAME_COUNT[$base]:-0} + 1 )); NAME_COUNT[$base]=$n
        name="$base"; [ "$n" -gt 1 ] && name="${base}_${n}"

        echo "  $src -> ${name}.stl"
        if ! "$OPENSCAD" "${QUALITY_ARGS[@]}" "${PARAM_ARGS[@]}" \
                -o "$plate_dir/${name}.stl" "$src" > /dev/null 2>&1; then
            echo "  OpenSCAD failed to export $src" >&2; exit 1
        fi
        STL_FILES+=("${name}.stl")

        [ -z "$part_overrides" ] && continue
        IFS=';' read -ra kv_pairs <<< "$part_overrides"
        for kv in "${kv_pairs[@]}"; do
            if [ "$kv" = "auto_orient=1" ]; then
                # Bambu's "auto orient selected object", this part alone.
                # --export-stl ignores the filename it is given and always
                # writes stl/obj_1_<basename>.stl in the working directory.
                echo "  auto-orienting ${name}.stl"
                odir="$plate_dir/_orient_${name}"; mkdir -p "$odir"
                cp "$plate_dir/${name}.stl" "$odir/${name}.stl"
                (cd "$odir" && "$BAMBU_STUDIO" --orient=1 --export-stl=x "${name}.stl" > /dev/null 2>&1) || true
                if [ -f "$odir/stl/obj_1_${name}.stl" ]; then
                    cp "$odir/stl/obj_1_${name}.stl" "$plate_dir/${name}.stl"
                else
                    echo "  warning: auto-orient produced nothing; keeping authored orientation" >&2
                fi
            else
                OBJECT_SET_ARGS+=(--object-set "$p" "${name}.stl" "$kv")
                [ "$kv" = "enable_support=1" ] && plate_enable_support="1"
            fi
        done
    done

    echo "  bambu-studio: arrange=$plate_arrange orient=$plate_auto_orient support=$plate_enable_support"
    bambu_export_plate "$plate_dir" "$plate_enable_support" "$plate_auto_orient" "$plate_arrange" "${STL_FILES[@]}"
    ASSEMBLE_ARGS+=(--plate "$plate_name" "$plate_dir/plate.3mf")
done

# ---- Assembly preview plate (plates_config.sh section 3) ------------------
# MakerWorld's assembly view (mw_assembly_view()), added LAST so plates 1..N
# keep matching mw_plate_1()..mw_plate_N(). A visual reference, not a print:
#   - Rendered from the freshly rebuilt DEV bundle (one flat file), so
#     PARAM_OVERRIDES reach every part however the sources include/use each
#     other, and its injected mw_assembly_views matches this run's config.
#   - One STL, one object, NEVER Bambu-arranged: it keeps mw_assembly_view()'s
#     own layout (what MakerWorld shows), moved from the origin to the bed
#     center with dev_view_offset. Plain STL import keeps coordinates as-is.
if [ "${#ASSEMBLY_PLATE_VIEWS[@]}" -gt 0 ]; then
    echo "[Plate \"$ASSEMBLY_PLATE_NAME\"] rendering assembly preview (${ASSEMBLY_PLATE_VIEWS[*]}) ..."
    require_tool POWERSHELL "PowerShell (pwsh or powershell.exe)" "POWERSHELL_BIN"
    "$POWERSHELL" -NoProfile -ExecutionPolicy Bypass -File "$SCRIPTS_DIR/build/dev_build.ps1" \
        -Project "$PROJECT_DIR" > /dev/null || { echo "dev_build.ps1 failed" >&2; exit 1; }

    dev_bundle="dist/${PROJECT_SLUG}_dev.scad"
    bed_cx="$(awk "BEGIN { print ${BED_MIN_X:-0} + $BED_WIDTH / 2 }")"
    bed_cy="$(awk "BEGIN { print ${BED_MIN_Y:-0} + $BED_DEPTH / 2 }")"
    assembly_dir="$WORKDIR/plate_assembly"
    mkdir -p "$assembly_dir"
    if ! "$OPENSCAD" "${QUALITY_ARGS[@]}" "${PARAM_ARGS[@]}" \
            -D 'dev_view="mw_assembly_view"' \
            -D "dev_view_offset=[$bed_cx,$bed_cy]" \
            -o "$assembly_dir/assembly_preview.stl" "$dev_bundle" > /dev/null 2>&1; then
        echo "  OpenSCAD failed to render the assembly preview from $dev_bundle" >&2; exit 1
    fi
    echo "  not arranging -- keeping mw_assembly_view()'s layout, centered on the bed"
    bambu_export_plate "$assembly_dir" 0 false false "assembly_preview.stl"
    ASSEMBLE_ARGS+=(--plate "$ASSEMBLY_PLATE_NAME" "$assembly_dir/plate.3mf")
fi

mkdir -p "$(dirname "$OUTPUT")"
echo "Assembling $(( ${#ASSEMBLE_ARGS[@]} / 3 )) plate(s) with settings from $REFERENCE_3MF ..."
"$PYTHON" "$SCRIPTS_DIR/export/assemble_3mf.py" "$OUTPUT" \
    --reference "$REFERENCE_3MF" \
    --bed-width "$BED_WIDTH" --bed-depth "$BED_DEPTH" \
    "${ASSEMBLE_ARGS[@]}" "${SET_ARGS[@]}" "${OBJECT_SET_ARGS[@]}"

echo "Done -> $PROJECT_DIR/$OUTPUT"
echo "Open it in Bambu Studio and check every plate before printing from it."
