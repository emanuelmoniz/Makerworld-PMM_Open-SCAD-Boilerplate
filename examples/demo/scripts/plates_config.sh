# ============================================================
# Sliding-Lid Box (demo)  |  Plates configuration (shared by 2 pipelines)
# ------------------------------------------------------------
# The ONE place that says which parts go on which print plate. Read by:
#   - the MakerWorld build (scripts/build/*.ps1): plate names + part lists
#     are VALIDATED against PLATE_ASSEMBLY_FILE's mw_plate_N() modules (the
#     build fails on drift), and MW_PLATE_SIZE / PRINTER set `mw_plate_size`.
#   - the Bambu 3mf export (scripts/export/export_3mf.sh): everything.
#
# OpenSCAD/PMM cannot receive print settings, so PRINTER, per-part overrides,
# arrange and auto-orient are used by the Bambu export ONLY.
#
# Regenerated into <project>/.build/plates.json on every run (gitignored).
# FORMAT: constrained bash, see scripts/project_config.sh's header.
# See: docs/toolchain/pipelines.md ("Plates"), docs/pmm/specification.md
# ============================================================

# ---- 1. PRINTER + MAKERWORLD PLATE SIZE -----------------------------------
# PRINTER: a Bambu Studio machine preset name, exactly as Bambu names it
#   (resources/profiles/BBL/machine/<name>.json without .json). Used by the
#   3mf export for the real bed shape; keep it matching REFERENCE_3MF in
#   export_3mf_config.sh. List every name with:
#       python scripts/shared/printer_bed.py "?"
#
# MW_PLATE_SIZE: the square bound (mm) your mw_plate_N() modules use to wrap
#   parts into new rows (injected into the bundle as `mw_plate_size`).
#   - a number (DEFAULT): deterministic -- same bundle on every machine/CI.
#   - "" (empty): derived from PRINTER's bed minus MW_PLATE_SIZE_MARGIN,
#     which makes the tracked bundle depend on locally installed Bambu presets.
#   Always capped at MW_PLATE_SIZE_CEILING. PMM has a practical plate ceiling
#   of about 240 x 235 mm (Bambu-employee-confirmed); oversize plates can
#   fail 3MF generation (docs/pmm/compatibility-rules.md).
PRINTER="Bambu Lab A1 0.4 nozzle"
MW_PLATE_SIZE="235"
MW_PLATE_SIZE_MARGIN="6"
MW_PLATE_SIZE_CEILING="235"

# ---- 2. PLATES ------------------------------------------------------------
# PLATE_NAMES: one name per plate. Then one PLATE_<N>_PARTS array per plate
# (1-indexed, same order), listing that plate's part files -- one object per
# entry; list a file twice for two copies.
#
# PART NAMING CONTRACT: the validator counts calls to a module named after
# the file (parts/lid.scad -> lid(...)) inside mw_plate_N(). Keep "one main
# module per part file, named like the file" (docs/conventions/naming.md).
#
# Per-part suffixes (Bambu export only), ";"-separated after a "|":
#   "parts/lid.scad|enable_support=1;support_remove_small_overhang=0"
#       -> print-setting overrides for this one object. Keys must exist in
#          REFERENCE_3MF (list them: python scripts/export/list_settings.py);
#          an unknown key aborts the export instead of being ignored.
#   "parts/lid.scad|auto_orient=1"
#       -> Bambu Studio's "auto orient selected object" for this part only.
#          Parts are authored in print orientation already
#          (docs/conventions/geometry.md), so this is rarely needed.
#
# Optional per-plate settings (add after that plate's PARTS array):
#   PLATE_<N>_ARRANGE=false       keep as-exported positions (default true).
#                                 Several un-arranged parts will overlap.
#   PLATE_<N>_AUTO_ORIENT=true    orient every part on the plate (default false)
#   PLATE_<N>_MW_PLATE=<k>        link to mw_plate_<k>() (default: N itself);
#                                 "" = Bambu-only plate, no MakerWorld twin.
#                                 A fully parametric mw_plate (e.g. a count-
#                                 driven grid) should NOT be listed here.
PLATE_NAMES=(
    "Box"
    "Lid"
)
PLATE_1_PARTS=(
    "parts/box_body.scad"
)
PLATE_2_PARTS=(
    "parts/sliding_lid.scad"
)
PLATE_1_ARRANGE=true
PLATE_2_ARRANGE=true

# ---- 3. ASSEMBLY PREVIEW PLATE --------------------------------------------
# Drives BOTH MakerWorld's assembly view (mw_assembly_view()) and a matching
# preview plate in the Bambu 3mf export.
#
# ASSEMBLY_PLATE_VIEWS: which assembled views appear, in order, stacked front
#   to back (assembly_view_gap apart, lib/params.scad) and centered as one
#   group. Each entry is a view NAME; view "<name>" requires, in the bundle:
#     module assembly_<name>()              the view itself
#     function assembly_<name>_footprint()  its XY box [xmin, ymin, xmax, ymax]
#     a branch in assembly_view() AND assembly_view_footprint()
#                                           (in PLATE_ASSEMBLY_FILE)
#   The build fails if any of these is missing, instead of silently
#   rendering nothing. Injected into both bundles as `mw_assembly_views`.
#   Leave it empty (paren lines only) for no assembly view and no preview
#   plate.
#
# ASSEMBLY_PLATE_NAME: name of that plate in the 3mf export. It is added as
#   the LAST plate (plates 1..N keep matching mw_plate_1()..mw_plate_N()),
#   rendered as one object from the dev bundle, centered on the bed, and NEVER
#   run through Bambu Studio's arrange -- it keeps exactly the layout
#   MakerWorld shows. A visual reference, not meant to be printed; it may be
#   larger than the bed.
ASSEMBLY_PLATE_NAME="_preview assembly DO NOT PRINT"
ASSEMBLY_PLATE_VIEWS=(
    "main"
    "open"
)
