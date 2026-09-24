# ============================================================
# <PROJECT NAME>  |  Project configuration  (EDIT ME FIRST)
# ------------------------------------------------------------
# The ONE file describing what this project is and how its sources become
# a MakerWorld bundle. Read by BOTH build scripts (build.ps1, dev_build.ps1)
# through scripts/shared/bash_config.py, and by the check scripts.
#
# FORMAT: a constrained subset of bash (see bash_config.py's header):
#   NAME="value"             one assignment per line
#   NAME=(                   arrays: paren alone on its line,
#       "item"               one quoted item per line,
#   )                        closing paren alone on its line
# No $VARIABLE expansion. Full-line `#` comments anywhere.
#
# Every path below is RELATIVE TO THE PROJECT FOLDER (the folder holding
# this scripts/ directory) -- which is how the same scripts also build
# examples/demo with `-Project examples/demo`.
#
# See: docs/toolchain/pipelines.md, docs/workflows/new-project.md
# ============================================================

# ---- 1. IDENTITY ----------------------------------------------------------
# PROJECT_NAME: human-readable, appears in the bundle header comment.
# PROJECT_SLUG: lowercase_with_underscores; names the output files
#   dist/<slug>_makerworld.scad and dist/<slug>_dev.scad.
PROJECT_NAME="<PROJECT NAME>"
PROJECT_SLUG="project"

# ---- 2. SOURCE FILES, in bundle order -------------------------------------
# Every .scad file that makes up the model, in the order they are
# concatenated into the bundle. RULES (docs/conventions/source-architecture.md):
#   - PARAMS_FILE comes first -- everything else reads its variables.
#   - A file must come AFTER anything it depends on only for top-level
#     VARIABLES. Modules and functions resolve regardless of order.
#   - Adding a new .scad file? Add it here, or it silently will not ship.
#   - NAME COLLISIONS: in a flattened file, the LAST definition of a module
#     or function name wins, silently. That includes names from bundled
#     libraries like BOSL2 (docs/openscad/libraries-and-fonts.md).
PARAMS_FILE="lib/params.scad"
SOURCE_FILES=(
    "lib/params.scad"
    "lib/helpers.scad"
    "parts/part_template.scad"
    "assembly/assembly_main.scad"
)

# ---- 3. MAKERWORLD OUTPUT STRUCTURE ---------------------------------------
# PLATE_ASSEMBLY_FILE: the file defining mw_plate_N() / mw_assembly_view().
#   The build validates its mw_plate_N() bodies against plates_config.sh.
#   Leave empty ("") for a single-part model with no plate modules.
# MAKERWORLD_TOP_LEVEL_CALL: a statement appended to the END of the bundle.
#   Leave EMPTY when you define mw_plate_N() (PMM calls those itself; an
#   extra top-level call would add geometry on top of them). Set it for a
#   single-part model, e.g. "part_template();" -- a single-part model keeps
#   PMM's direct STL download, which multi-plate models lose
#   (docs/pmm/specification.md "mw_plate_N").
PLATE_ASSEMBLY_FILE="assembly/assembly_main.scad"
MAKERWORLD_TOP_LEVEL_CALL=""

# ---- 4. PMM-BUNDLED LIBRARIES ---------------------------------------------
# include/use lines whose path starts with one of these prefixes are KEPT in
# the bundle (PMM ships these libraries). Every OTHER include/use is
# stripped, because the bundle is flat and PMM rejects local include trees.
# This list mirrors docs/pmm/data/libraries.json (refresh with
# scripts/shared/pmm_inventory.py). Remove entries you do not use -- the
# lint (scripts/check/pmm_lint.py) flags includes not on this list.
BUNDLED_LIBRARIES=(
    "BOSL2/"
    "KeyV2/"
    "gridfinity-rebuilt-openscad/"
    "threads-scad/"
    "ub.scad"
    "Getriebe.scad"
    "knurledFinishLib_v2.scad"
)

# ---- 5. COLORS IN THE MAKERWORLD BUNDLE -----------------------------------
# FLATTEN_COLORS="true": every `color(some_variable)` call is rewritten to
#   MAKERWORLD_COLOR, so PMM previews the model in one uniform color while
#   your local assembly previews keep distinct per-part colors.
# COLOR_PASSTHROUGH: variable names whose color() calls are left untouched --
#   use it for colors that must stay distinct on MakerWorld (an inlay, or a
#   user-facing `// color` parameter for multi-color prints).
# Literal colors, e.g. color("#ff0000"), are never rewritten.
# PMM needs HEX strings; named CSS colors do not trigger its color picker.
FLATTEN_COLORS="true"
MAKERWORLD_COLOR="#1a2f4a"
COLOR_PASSTHROUGH=(
)

# ---- 6. README -> BUNDLE HEADER COUPLING ----------------------------------
# The README text between these two marker lines is copied into the
# bundle's header comment ("PROJECT DESCRIPTION"). So that span is LIVE
# CONTENT that ships to MakerWorld: keep it accurate and self-contained --
# it is read without the rest of the README around it.
README_FILE="README.md"
README_DESCRIPTION_START="<!-- BUNDLE-DESCRIPTION:START -->"
README_DESCRIPTION_END="<!-- BUNDLE-DESCRIPTION:END -->"

# ---- 7. DEV BUNDLE VIEWS --------------------------------------------------
# "module_name:Label" entries shown in the dev bundle's dev_view dropdown.
# The FIRST entry is the default view. Every module must exist in a
# SOURCE_FILES file and take no required arguments.
DEV_VIEWS=(
    "assembly_main:Assembly"
    "mw_assembly_view:MakerWorld assembly view"
    "mw_plate_1:Plate 1"
)

# ---- 8. GENERATED PARAMETER TABLES ----------------------------------------
# "file|style" entries: files whose parameter table is generated from
# PARAMS_FILE by the MakerWorld build (scripts/shared/param_tables.py),
# between the lines <!-- PARAMETERS:START --> and <!-- PARAMETERS:END -->.
# The freshness check fails when a table no longer matches params.scad.
#   readme   one table per tab: variable | description | default | range
#   listing  customer table: label | description | compatibility
# Labels and the compatibility column come from optional `// @label:` and
# `// @note:` lines above a parameter's help line (docs/workflows/
# add-a-parameter.md). Remove an entry to maintain that table by hand.
PARAM_TABLES=(
    "README.md|readme"
    "dist/makerworld_listing.md|listing"
)

# ---- 9. SMOKE VARIANTS ----------------------------------------------------
# Extra parameter sets the smoke check builds every plate (and the assembly
# preview) with, on top of the defaults: "name|param=value; param=value".
# Each assignment is one -D, so values may contain spaces; strings keep
# their escaped quotes. Cover the extremes: min and max sizes, every
# dropdown option, every optional feature on and off. Every variant costs a
# full render of every plate, locally and in CI.
SMOKE_VARIANTS=(
    # "smallest|size_x=10; size_y=10; size_z=2"
    # "largest|size_x=200; size_y=200; size_z=100"
    # "square edges|rounded=false"
)
