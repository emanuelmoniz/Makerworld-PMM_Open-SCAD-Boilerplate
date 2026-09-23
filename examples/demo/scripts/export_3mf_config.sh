# ============================================================
# Sliding-Lid Box (demo)  |  Bambu 3MF export configuration   (OPTIONAL PIPELINE)
# ------------------------------------------------------------
# scripts/export/export_3mf.sh sources this file and produces ONE print-
# ready, multi-plate .3mf for Bambu Studio. Plates, parts and PRINTER live
# in scripts/plates_config.sh (shared with the MakerWorld build) -- this
# file holds only what varies per export run.
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
#
# label_style: the demo ships engraved (one color). Embossed puts the label
# in its own filament, which is what makes the lid a MULTICOLOR part here --
# these overrides reach a multicolor part exactly like any other, so with
# label_style back at its default the export just reports one region and
# prints the lid single-filament. -> docs/workflows/multicolor.md
PARAM_OVERRIDES=(
    "label_style=\"embossed\""
    # "inner_length=120"
)

# ---- 2. FACE DETAIL (STL tessellation) ------------------------------------
FACE_DETAIL_FN=0
FACE_DETAIL_FA=2
FACE_DETAIL_FS=0.4

# ---- 3. REFERENCE_3MF: where print settings come from ---------------------
# A .3mf saved once from the Bambu Studio GUI. Its printer/filament/process
# settings (Metadata/project_settings.config) are copied wholesale onto the
# export -- Bambu's CLI cannot load a full preset by name.
# This demo keeps its OWN reference rather than sharing the root project's,
# because the lid is a multicolor part: the reference has to carry at least
# as many filaments as FILAMENT_MAP uses, and the root one has a single
# filament. It is: Bambu Lab A1 0.4 nozzle / 0.20mm Standard @BBL A1 / two
# slots of Bambu PLA Basic @BBL A1, colored like the model. To use your own:
# in Bambu Studio pick your printer + process + filaments, add any small
# object, File > Save Project As..., save it over this path (keep PRINTER in
# plates_config.sh matching).
REFERENCE_3MF="scripts/base_settings.3mf"

# ---- 3b. FILAMENT MAP (multicolor parts only) -----------------------------
# Which slot each color in the model prints in, 1-based, in REFERENCE_3MF's
# filament order. The two colors here are lib/params.scad's lid_color
# ("LightSlateGray", which OpenSCAD exports as #778899) and the user-facing
# label_color. Change label_color in the customizer and this map needs the
# new hex -- the export prints the colors it found when one is missing.
#
# The assembly preview plate goes through this map too: its views mark
# their color regions with assembly_region() (assembly/assembly_main.scad),
# so it shows the box as well -- box_color ("SteelBlue", #4682B4). It shares
# slot 1 with the lid: the preview is a visual reference, not a print, and
# the reference project has only two filaments.
FILAMENT_MAP=(
    "#778899=1"     # lid_color: the lid body
    "#E67E22=2"     # label_color: the embossed label
    "#4682B4=1"     # box_color: the box, on the assembly preview plate only
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
OUTPUT="printables/sliding_lid_box_generated.3mf"
