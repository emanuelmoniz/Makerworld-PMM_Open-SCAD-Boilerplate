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
#   3. per plate: export each part to STL (OpenSCAD) -- or, for a part marked
#      `multicolor=1`, to a Bambu multi-part object with one filament per
#      color region (multicolor_3mf.py); optionally auto-orient a single part
#      or the whole plate; arrange the plate with Bambu Studio's own
#      `--arrange=1` inside the real bed. A part that renders nothing with
#      this run's parameters (an optional part switched off, by its own
#      parameter or by PARAM_OVERRIDES) is skipped, and a plate left with no
#      parts is dropped altogether: later plates move up, so the project never
#      has an empty plate
#   4. if ASSEMBLY_PLATE_VIEWS is set (plates_config.sh section 3): add the
#      assembly preview as the LAST plate -- MakerWorld's mw_assembly_view()
#      layout rendered from the dev bundle, centered on the bed, NEVER arranged
#      -- multicolor too, when its views mark their color regions with
#      assembly_region()
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

# FILAMENT_MAP (export_3mf_config.sh) -> multicolor_3mf.py --map arguments.
# Only parts marked multicolor=1 consult it; an empty map is normal for a
# single-color project.
FILAMENT_MAP_ARGS=()
for mapping in "${FILAMENT_MAP[@]+"${FILAMENT_MAP[@]}"}"; do
    FILAMENT_MAP_ARGS+=(--map "$mapping")
done

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

BED_EXCLUDE_ARGS=()
[ -n "$BED_EXCLUDE_AREA" ] && BED_EXCLUDE_ARGS=(--bed-exclude-area="$BED_EXCLUDE_AREA")

# Exports part file $1 to $2 with OpenSCAD, extra flags in $3.. .
# Returns 0 on success and 2 when the part renders nothing (switched off with
# this run's parameters); exits the script on any other failure.
openscad_export_part() {
    local src="$1" out="$2"; shift 2
    local log
    if log="$("$OPENSCAD" "${QUALITY_ARGS[@]}" "${PARAM_ARGS[@]}" "$@" -o "$out" "$src" 2>&1)"; then
        return 0
    fi
    if grep -qi "top level object is empty" <<< "$log"; then
        return 2
    fi
    echo "  OpenSCAD failed to export $src" >&2
    exit 1
}

# One Bambu Studio CLI call turning a plate's part files into a single-plate
# 3mf (plate.3mf in that plate's dir) -- shared by the regular plates and the
# assembly preview plate. Part files are .stl, or .3mf for a multicolor part
# (Bambu Studio's CLI takes a mix of both in one call, and arranges a
# multi-part object as one unit).
#   $1 plate dir   $2 --enable-support value   $3 orient (true/false)
#   $4 arrange (true/false)   $5.. part file names, relative to $1
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
OUT_PLATE=0    # plate number in the output project; dropped plates don't count

for (( p=1; p<=PLATE_COUNT; p++ )); do
    plate_name="${PLATE_NAMES[$((p-1))]}"
    parts_var="PLATE_${p}_PARTS[@]";        plate_parts=("${!parts_var}")
    orient_var="PLATE_${p}_AUTO_ORIENT";    plate_auto_orient="${!orient_var:-false}"
    arrange_var="PLATE_${p}_ARRANGE";       plate_arrange="${!arrange_var:-true}"

    plate_dir="$WORKDIR/plate_$p"
    mkdir -p "$plate_dir"
    echo "[Plate $p \"$plate_name\"] exporting ${#plate_parts[@]} part(s) ..."

    unset NAME_COUNT; declare -A NAME_COUNT=()
    PART_FILES=()
    plate_enable_support="$REFERENCE_ENABLE_SUPPORT"
    for entry in "${plate_parts[@]}"; do
        src="${entry%%|*}"
        part_overrides=""
        [[ "$entry" == *"|"* ]] && part_overrides="${entry#*|}"
        [ -f "$src" ] || { echo "  Part file not found: $src" >&2; exit 1; }

        base="$(basename "$src" .scad)"
        n=$(( ${NAME_COUNT[$base]:-0} + 1 )); NAME_COUNT[$base]=$n
        name="$base"; [ "$n" -gt 1 ] && name="${base}_${n}"

        # multicolor=1 changes how this part is exported, so it has to be
        # known before the export -- the other suffixes are applied after.
        part_multicolor=false
        [[ ";$part_overrides;" == *";multicolor=1;"* ]] && part_multicolor=true

        if [ "$part_multicolor" = "true" ]; then
            # ONE OpenSCAD run: --enable=lazy-union keeps the part's
            # top-level children (its color regions) as separate closed
            # solids instead of unioning them, and material-type=color
            # records which color each one was drawn in. multicolor_3mf.py
            # turns that into a single Bambu object whose parts each carry
            # an `extruder` -- real per-volume filament assignment, which
            # colors baked into the mesh cannot give (see its header).
            # PARAM_OVERRIDES reach this the same as any other part: the
            # part file is still OpenSCAD's main file.
            rc=0
            openscad_export_part "$src" "$plate_dir/${name}_regions.3mf" \
                --enable=lazy-union \
                -O export-3mf/color-mode=model \
                -O export-3mf/material-type=color || rc=$?
            if [ "$rc" = 2 ]; then
                echo "  $src renders nothing with these parameters -- skipped"
                continue
            fi
            echo "  $src -> ${name}.3mf (multicolor)"
            if ! "$PYTHON" "$SCRIPTS_DIR/export/multicolor_3mf.py" \
                    "$plate_dir/${name}_regions.3mf" "$plate_dir/${name}.3mf" \
                    --reference "$REFERENCE_3MF" --name "${name}.3mf" \
                    "${FILAMENT_MAP_ARGS[@]+"${FILAMENT_MAP_ARGS[@]}"}"; then
                exit 1
            fi
            PART_FILES+=("${name}.3mf")
            part_file="${name}.3mf"
        else
            rc=0
            openscad_export_part "$src" "$plate_dir/${name}.stl" || rc=$?
            if [ "$rc" = 2 ]; then
                echo "  $src renders nothing with these parameters -- skipped"
                continue
            fi
            echo "  $src -> ${name}.stl"
            PART_FILES+=("${name}.stl")
            part_file="${name}.stl"
        fi

        [ -z "$part_overrides" ] && continue
        IFS=';' read -ra kv_pairs <<< "$part_overrides"
        for kv in "${kv_pairs[@]}"; do
            if [ "$kv" = "multicolor=1" ]; then
                continue    # already handled, above
            elif [ "$kv" = "auto_orient=1" ]; then
                if [ "$part_multicolor" = "true" ]; then
                    # Bambu's per-object orient goes through --export-stl,
                    # which would flatten the object's parts back into one
                    # mesh and lose every filament assignment. Plate-level
                    # PLATE_<N>_AUTO_ORIENT does keep them (it orients the
                    # object as a unit), so say which one to use.
                    echo "  auto_orient=1 cannot be combined with multicolor=1 ($src):" >&2
                    echo "  it would merge the color regions back into one mesh." >&2
                    echo "  Use PLATE_${p}_AUTO_ORIENT=true instead." >&2
                    exit 1
                fi
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
                OBJECT_SET_ARGS+=(--object-set "$((OUT_PLATE + 1))" "$part_file" "$kv")
                [ "$kv" = "enable_support=1" ] && plate_enable_support="1"
            fi
        done
    done

    if [ "${#PART_FILES[@]}" -eq 0 ]; then
        echo "  no parts left -- plate dropped"
        continue
    fi
    echo "  bambu-studio: arrange=$plate_arrange orient=$plate_auto_orient support=$plate_enable_support"
    bambu_export_plate "$plate_dir" "$plate_enable_support" "$plate_auto_orient" "$plate_arrange" "${PART_FILES[@]}"
    ASSEMBLE_ARGS+=(--plate "$plate_name" "$plate_dir/plate.3mf")
    OUT_PLATE=$((OUT_PLATE + 1))
done

# ---- Assembly preview plate (plates_config.sh section 3) ------------------
# MakerWorld's assembly view (mw_assembly_view()), added LAST so plates 1..N
# keep matching mw_plate_1()..mw_plate_N(). A visual reference, not a print:
#   - Rendered from the freshly rebuilt DEV bundle (one flat file), so
#     PARAM_OVERRIDES reach every part however the sources include/use each
#     other, and its injected mw_assembly_views matches this run's config.
#   - One object, NEVER Bambu-arranged: it keeps mw_assembly_view()'s own
#     layout (what MakerWorld shows), moved from the origin to the bed center
#     with dev_view_offset.
#   - Multicolor when the views wrap their solids in assembly_region()
#     (PLATE_ASSEMBLY_FILE): a geometry-free run with $assembly_region="?"
#     lists the region names; with two or more, the dev bundle's top-level
#     loop renders one solid per region under --enable=lazy-union, and
#     multicolor_3mf.py maps their colors through FILAMENT_MAP exactly as
#     for a multicolor=1 part. Otherwise: one STL on one filament.
#     (docs/workflows/multicolor.md, "The assembly preview plate")
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
    VIEW_ARGS=(-D 'dev_view="mw_assembly_view"' -D "dev_view_offset=[$bed_cx,$bed_cy]")

    # Region discovery: an .echo export evaluates the views without building
    # any geometry. Names are kept in first-seen order -- the order the
    # solids are written in, so a later region owns what it shares with an
    # earlier one, the same rule as a multicolor part's top-level calls.
    if ! "$OPENSCAD" "${PARAM_ARGS[@]}" "${VIEW_ARGS[@]}" \
            -D 'dev_assembly_regions=["?"]' \
            -o "$assembly_dir/regions.echo" "$dev_bundle" > /dev/null 2>&1; then
        echo "  OpenSCAD failed to evaluate the assembly preview from $dev_bundle" >&2; exit 1
    fi
    ASSEMBLY_REGIONS=()
    while IFS= read -r region; do
        [ -n "$region" ] && ASSEMBLY_REGIONS+=("$region")
    done < <(tr -d '\r' < "$assembly_dir/regions.echo" \
             | sed -n 's/^ECHO: "ASSEMBLY_REGION:\(.*\)"$/\1/p' | awk '!seen[$0]++')

    if [ "${#ASSEMBLY_REGIONS[@]}" -ge 2 ]; then
        # Same path as a multicolor=1 part: one solid per region, colors
        # mapped to filaments through FILAMENT_MAP.
        echo "  multicolor: regions ${ASSEMBLY_REGIONS[*]}"
        region_list="$(printf '"%s",' "${ASSEMBLY_REGIONS[@]}")"
        if ! "$OPENSCAD" "${QUALITY_ARGS[@]}" "${PARAM_ARGS[@]}" "${VIEW_ARGS[@]}" \
                -D "dev_assembly_regions=[${region_list%,}]" \
                --enable=lazy-union \
                -O export-3mf/color-mode=model \
                -O export-3mf/material-type=color \
                -o "$assembly_dir/assembly_preview_regions.3mf" "$dev_bundle" > /dev/null 2>&1; then
            echo "  OpenSCAD failed to render the assembly preview from $dev_bundle" >&2; exit 1
        fi
        if ! "$PYTHON" "$SCRIPTS_DIR/export/multicolor_3mf.py" \
                "$assembly_dir/assembly_preview_regions.3mf" "$assembly_dir/assembly_preview.3mf" \
                --reference "$REFERENCE_3MF" --name "assembly_preview.3mf" \
                "${FILAMENT_MAP_ARGS[@]+"${FILAMENT_MAP_ARGS[@]}"}"; then
            exit 1
        fi
        assembly_file="assembly_preview.3mf"
    else
        if ! "$OPENSCAD" "${QUALITY_ARGS[@]}" "${PARAM_ARGS[@]}" "${VIEW_ARGS[@]}" \
                -o "$assembly_dir/assembly_preview.stl" "$dev_bundle" > /dev/null 2>&1; then
            echo "  OpenSCAD failed to render the assembly preview from $dev_bundle" >&2; exit 1
        fi
        assembly_file="assembly_preview.stl"
    fi
    echo "  not arranging -- keeping mw_assembly_view()'s layout, centered on the bed"
    bambu_export_plate "$assembly_dir" 0 false false "$assembly_file"
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
