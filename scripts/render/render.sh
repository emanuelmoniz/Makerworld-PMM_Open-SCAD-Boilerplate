#!/bin/bash
# ============================================================
# <PROJECT NAME>  |  Render manager
# ------------------------------------------------------------
# Renders one PNG per TARGET x PERSPECTIVE x ASPECT_RATIO selected in
# scripts/render_config.sh, with its parameter overrides, face detail and
# resolution passed to OpenSCAD's CLI.
#
# CAMERA FIT: OpenSCAD's --autocenter/--viewall fits only the SMALLER of
# the image's two angular extents, so an elongated model in a mismatched
# aspect ratio gets its long axis cropped. Instead, for each target this
# exports a throwaway STL, asks scripts/shared/stl_bbox.py for the sphere
# circumscribing its bounding box, and places an explicit --camera that
# fits that sphere at RENDER_FOV (plus RENDER_MARGIN). A sphere looks the
# same from every angle, so no perspective can crop.
# RENDER_FIT="tight" fits each perspective to the model's actual outline
# instead (scripts/shared/render_fit.py): the model fills the frame up to
# RENDER_MARGIN, which suits tall or long models the sphere leaves small.
#
# MANUAL ONLY -- nothing else calls this script (AGENTS.md: never render
# unless asked in that turn).
#
# Usage:
#   scripts/render/render.sh                       # this project
#   scripts/render/render.sh -p examples/demo      # another project folder
#   scripts/render/render.sh -c path/to/config.sh  # alternate config
# Output: <project>/renders/{parts,assembly}/<name>_<PERSPECTIVE>_<RATIO>.png
# See: docs/toolchain/pipelines.md ("Render")
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
        *) echo "Usage: render.sh [-p project_dir] [-c config.sh]" >&2; exit 1 ;;
    esac
done
CONFIG="${CONFIG:-$PROJECT_DIR/scripts/render_config.sh}"
[ -f "$CONFIG" ] || { echo "Config file not found: $CONFIG" >&2; exit 1; }

require_tool OPENSCAD "OpenSCAD" "OPENSCAD_BIN"
require_tool PYTHON "Python 3" "PYTHON_BIN"

# shellcheck disable=SC1090
source "$CONFIG"
cd "$PROJECT_DIR"

# Fixed 55 deg tilt; only the azimuth (rotation about Z) differs.
declare -A PERSPECTIVE_AZIMUTH=(
    ["ISO_TOP_LEFT_FRONT"]=35
    ["ISO_TOP_LEFT_BACK"]=125
    ["ISO_TOP_RIGHT_BACK"]=215
    ["ISO_TOP_RIGHT_FRONT"]=305
)

for arr in PERSPECTIVES TARGETS ASPECT_RATIOS; do
    declare -n ref="$arr"
    if [ "${#ref[@]}" -eq 0 ]; then
        echo "Nothing to render: $arr is empty in $CONFIG" >&2
        exit 1
    fi
done

RENDER_FOV="${RENDER_FOV:-22.5}"
RENDER_MARGIN="${RENDER_MARGIN:-0.1}"
RENDER_WIDTH="${RENDER_WIDTH:-1600}"
RENDER_COLORSCHEME="${RENDER_COLORSCHEME:-Tomorrow}"
RENDER_FIT="${RENDER_FIT:-sphere}"
case "$RENDER_FIT" in sphere|tight) ;; *) echo "RENDER_FIT must be sphere or tight, not: $RENDER_FIT" >&2; exit 1 ;; esac

# $vpf is passed explicitly so OpenSCAD's FOV and the distance formula
# below can never disagree.
if [ "${FACE_DETAIL_FN:-0}" != "0" ]; then
    QUALITY_ARGS=(-D "\$fn=${FACE_DETAIL_FN}")
else
    QUALITY_ARGS=(-D "\$fn=0" -D "\$fa=${FACE_DETAIL_FA:-2}" -D "\$fs=${FACE_DETAIL_FS:-0.4}")
fi
QUALITY_ARGS+=(-D "\$vpf=${RENDER_FOV}")

PARAM_ARGS=()
for override in "${PARAM_OVERRIDES[@]}"; do PARAM_ARGS+=(-D "$override"); done

total=$(( ${#TARGETS[@]} * ${#PERSPECTIVES[@]} * ${#ASPECT_RATIOS[@]} ))
count=0
i=0
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

for src in "${TARGETS[@]}"; do
    if [ ! -f "$src" ]; then
        echo "Skipping missing target: $src" >&2
        i=$(( i + ${#PERSPECTIVES[@]} * ${#ASPECT_RATIOS[@]} ))
        continue
    fi
    case "$src" in
        parts/*)    out_dir="renders/parts" ;;
        assembly/*) out_dir="renders/assembly" ;;
        *)          out_dir="renders" ;;
    esac
    base="$(basename "$src" .scad)"
    mkdir -p "$out_dir"

    echo "Computing camera fit for $src ..."
    stl_tmp="$WORKDIR/$base.stl"
    if ! "$OPENSCAD" --render "${QUALITY_ARGS[@]}" "${PARAM_ARGS[@]}" \
            -o "$stl_tmp" "$src" > /dev/null 2>&1; then
        echo "  STL export failed for $src -- skipping (open it in OpenSCAD to see why)." >&2
        i=$(( i + ${#PERSPECTIVES[@]} * ${#ASPECT_RATIOS[@]} ))
        continue
    fi
    read -r cx cy cz radius < <("$PYTHON" "$SCRIPTS_DIR/shared/stl_bbox.py" "$stl_tmp" | tr -d '\r') || true
    if [ -z "$radius" ]; then
        echo "  Could not compute a bounding sphere for $src -- skipping." >&2
        i=$(( i + ${#PERSPECTIVES[@]} * ${#ASPECT_RATIOS[@]} ))
        continue
    fi

    for ratio in "${ASPECT_RATIOS[@]}"; do
        rw="${ratio%%x*}"; rh="${ratio#*x}"
        if [ -z "$rw" ] || [ -z "$rh" ] || [ "$rw" = "$ratio" ]; then
            echo "Skipping malformed aspect ratio (expected WxH): $ratio" >&2
            i=$(( i + ${#PERSPECTIVES[@]} ))
            continue
        fi
        height=$(( (RENDER_WIDTH * rh + rw / 2) / rw ))
        distance=$(awk -v r="$radius" -v w="$RENDER_WIDTH" -v h="$height" \
                       -v fov="$RENDER_FOV" -v m="$RENDER_MARGIN" 'BEGIN {
            pi = atan2(0, -1); half = (fov * pi / 180.0) / 2.0
            t = sin(half) / cos(half); a = w / h; mn = (a < 1) ? a : 1
            printf "%.6f", (r / (t * mn)) * (1.0 + m) }')

        for perspective in "${PERSPECTIVES[@]}"; do
            i=$(( i + 1 ))
            az="${PERSPECTIVE_AZIMUTH[$perspective]}"
            if [ -z "$az" ]; then
                echo "[$i/$total] Unknown perspective: $perspective" >&2
                continue
            fi
            out="$out_dir/${base}_${perspective}_${ratio}.png"
            tx="$cx"; ty="$cy"; tz="$cz"; dist="$distance"
            if [ "$RENDER_FIT" = "tight" ]; then
                aspect="$(awk -v w="$RENDER_WIDTH" -v h="$height" 'BEGIN { printf "%.6f", w / h }')"
                read -r tx ty tz dist < <("$PYTHON" "$SCRIPTS_DIR/shared/render_fit.py" "$stl_tmp" \
                    55 0 "$az" "$RENDER_FOV" "$aspect" "$RENDER_MARGIN" | tr -d '\r') || true
                [ -n "$dist" ] || { tx="$cx"; ty="$cy"; tz="$cz"; dist="$distance"; }
            fi
            echo "[$i/$total] $src ($perspective, $ratio, ${RENDER_WIDTH}x${height}) -> $out"
            "$OPENSCAD" --render --projection=ortho \
                --imgsize="${RENDER_WIDTH},${height}" \
                --camera="${tx},${ty},${tz},55,0,${az},${dist}" \
                --colorscheme="$RENDER_COLORSCHEME" \
                "${QUALITY_ARGS[@]}" "${PARAM_ARGS[@]}" \
                -o "$out" "$src" > /dev/null 2>&1
            count=$(( count + 1 ))
        done
    done
done

echo "Rendered $count image(s)."
