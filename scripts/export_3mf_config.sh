# ============================================================
# <PROJECT NAME>  |  Bambu 3MF export configuration   (OPTIONAL PIPELINE)
# ------------------------------------------------------------
# scripts/export/export_3mf.sh sources this file and produces ONE print-
# ready, multi-plate .3mf for Bambu Studio. Plates, parts and PRINTER live
# in scripts/plates_config.sh (shared with the MakerWorld build) -- this
# file holds only what varies per export run.
#
# The assembly preview plate (plates_config.sh section 3) is appended LAST,
# unarranged, rendered from the dev bundle -- PARAM_OVERRIDES apply to it too.
#
# Needs Bambu Studio installed (its CLI does the per-plate arranging).
# Skip this pipeline entirely if you never slice locally.
#
# RELIABILITY: Bambu Studio's CLI can arrange ONE plate per call but cannot
# build a multi-plate project. scripts/export/assemble_3mf.py merges the
# plates by hand -- reverse-engineered from real Bambu files, not from a
# spec. OPEN THE FIRST FILE IT PRODUCES in Bambu Studio and check it before
# printing from it. See docs/toolchain/pipelines.md ("3MF export").
#
# Want variants (e.g. two feature sets)? Keep one copy of this file per
# variant and pass it with: export_3mf.sh -c path/to/variant_config.sh
# ============================================================

# ---- 1. PARAMETER OVERRIDES -----------------------------------------------
# Same convention as render_config.sh: OpenSCAD -D flags, applied to every
# part. Omitted = params.scad default.
PARAM_OVERRIDES=(
    # "size_x=60"
)

# ---- 2. FACE DETAIL (STL tessellation) ------------------------------------
FACE_DETAIL_FN=0
FACE_DETAIL_FA=2
FACE_DETAIL_FS=0.4

# ---- 3. REFERENCE_3MF: where print settings come from ---------------------
# A .3mf saved once from the Bambu Studio GUI. Its printer/filament/process
# settings (Metadata/project_settings.config) are copied wholesale onto the
# export -- Bambu's CLI cannot load a full preset by name.
# The shipped file is: Bambu Lab A1 0.4 nozzle / 0.20mm Standard @BBL A1 /
# Bambu PLA Matte @BBL A1. To use your own: in Bambu Studio pick your
# printer + process + filament, add any small object, File > Save Project
# As..., save it over this path (keep PRINTER in plates_config.sh matching).
REFERENCE_3MF="scripts/export/base_settings.3mf"

# ---- 3b. FILAMENT MAP (multicolor parts only) -----------------------------
# Which AMS slot each COLOR in the model prints in: "<hex>=<slot>", slots
# 1-based, matching REFERENCE_3MF's filament order (its filament_colour --
# `python scripts/export/list_settings.py --grep filament_colour`).
#
# Only parts marked `multicolor=1` in plates_config.sh consult this, plus the
# assembly preview plate when its views use assembly_region() -- then every
# color in those views needs an entry too. Leave it empty for a single-color
# project. The hex is the color OpenSCAD actually
# exported, so named colors (color("SteelBlue")) work too -- run the export
# once and it lists the colors it found, ready to paste in here. A color the
# export finds and this map doesn't have aborts the export rather than
# guessing a slot.
#
# REFERENCE_3MF must already have that many filaments: slots cannot be added
# here (a synthesized slot crashes Bambu Studio). Load them in the GUI, save
# the project, point REFERENCE_3MF at it.
# See: docs/workflows/multicolor.md
FILAMENT_MAP=(
    # "#1A2F4A=1"
    # "#E67E22=2"
)

# ---- 4. GLOBAL PRINT-SETTING OVERRIDES ------------------------------------
# "key=value" entries applied on top of REFERENCE_3MF for every plate. Keys
# must already exist in REFERENCE_3MF (unknown keys abort the export).
# List every valid key and its current value with:
#     python scripts/export/list_settings.py
# (The original project pasted all ~580 keys here as comments; generating
# the list on demand keeps this file readable and never out of date.)
PRINT_SETTINGS_OVERRIDES=(
    # "sparse_infill_density=15%"
    # "wall_loops=3"
    # "brim_type=no_brim"
)

# ---- 5. OUTPUT ------------------------------------------------------------
# Relative to the project folder. The name should say what it is -- e.g. a
# variant suffix -- because printables/ also holds hand-curated profiles.
OUTPUT="printables/project_generated.3mf"
