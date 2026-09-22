# ============================================================
# <PROJECT NAME>  |  Render configuration
# ------------------------------------------------------------
# scripts/render/render.sh sources this file and renders one PNG per
# selected TARGET x PERSPECTIVE x ASPECT_RATIO combination. Edit, then run
# scripts\render.bat (or: bash scripts/render/render.sh [-p <project>]).
#
# Renders are MANUAL ONLY: nothing else in this repo triggers them, and
# agents must never render unless asked in that turn (AGENTS.md).
# Comment a line out with a leading `#` to disable it.
# See: docs/toolchain/pipelines.md ("Render")
# ============================================================

# ---- 1. PERSPECTIVES ------------------------------------------------------
# Fixed isometric-style cameras: 55 deg tilt, orthographic projection.
# Named from the model convention "origin at the outer FRONT-LEFT-BOTTOM
# corner" (docs/conventions/geometry.md): FRONT is the Y=0 face, LEFT is
# the X=0 side. The four walk around the model 90 degrees apart.
PERSPECTIVES=(
    "ISO_TOP_LEFT_FRONT"
    # "ISO_TOP_LEFT_BACK"
    # "ISO_TOP_RIGHT_BACK"
    # "ISO_TOP_RIGHT_FRONT"
)

# ---- 2. TARGETS -----------------------------------------------------------
# Source .scad files, relative to the project folder. Output goes to
# renders/parts/ for parts/*, renders/assembly/ for assembly/*, named
# <file>_<PERSPECTIVE>_<RATIO>.png.
# A target must render something when opened directly -- i.e. its
# BUILD:EXCLUDE preview block must call a module (see parts/README.md).
TARGETS=(
    "parts/part_template.scad"
    # "assembly/assembly_main.scad"
)

# ---- 3. PARAMETER OVERRIDES -----------------------------------------------
# Passed to OpenSCAD as -D flags; anything omitted keeps params.scad's
# default. Strings need escaped quotes: "style=\"round\"". Keep the same
# tab grouping as lib/params.scad so the two are easy to cross-check.
PARAM_OVERRIDES=(
    # -- DIMENSIONS --
    # "size_x=60"
)

# ---- 4. FACE DETAIL -------------------------------------------------------
# OpenSCAD's $fn / $fa / $fs. FACE_DETAIL_FN=0 uses $fa/$fs (defaults match
# lib/params.scad, i.e. MakerWorld-bundle fidelity); FN > 0 forces a fixed
# fragment count instead (finer for a hero shot, coarser for a draft).
FACE_DETAIL_FN=0
FACE_DETAIL_FA=2
FACE_DETAIL_FS=0.4

# ---- 5. ASPECT RATIOS & RESOLUTION ----------------------------------------
# Height is derived from RENDER_WIDTH per ratio -- no height to keep in sync.
ASPECT_RATIOS=(
    "4x3"
    # "1x1"
    # "3x4"
    # "16x9"
)
RENDER_WIDTH=1600

# ---- 6. FIT & MARGIN ------------------------------------------------------
# render.sh fits the camera to the sphere circumscribing each model's
# bounding box (never crops, at any angle). RENDER_MARGIN adds breathing
# room as a fraction of that distance; RENDER_FOV is OpenSCAD's $vpf.
RENDER_MARGIN=0.1
RENDER_FOV=22.5
RENDER_COLORSCHEME="Tomorrow"
