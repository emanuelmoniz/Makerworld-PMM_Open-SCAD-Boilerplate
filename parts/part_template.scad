// ============================================================
// <PROJECT NAME>  |  Part: part_template   (COPY ME for each new part)
// ------------------------------------------------------------
// ONE FILE = ONE PRINTED PART. To add a part (docs/workflows/add-a-part.md):
//   1. copy this file to parts/<part_name>.scad
//   2. rename the module to EXACTLY <part_name> -- the plate validator
//      counts calls to a module named like the file
//   3. add the file to SOURCE_FILES (scripts/project_config.sh)
//   4. place it on a plate: scripts/plates_config.sh AND the matching
//      mw_plate_N() in assembly/assembly_main.scad (the build fails if
//      the two disagree)
//   5. document it: README "Parts to print" table, CHANGELOG [Unreleased]
//
// CONVENTIONS (docs/conventions/geometry.md):
//   - Author the part with its outer FRONT-LEFT-BOTTOM corner at (0,0,0),
//     in its PRINT orientation (flat face down, support-free if possible).
//     Assembly files rotate/translate it into its assembled pose.
//   - Clearances WIDEN THE CAVITY, never shrink the nominal part.
//   - Keep deliberate small overlaps (+0.01..+1) on cuts to avoid
//     coincident faces; comment why each one is there.
// ============================================================

include <../lib/params.scad>   // include: we need its VARIABLES

use <../lib/helpers.scad>      // use: modules/functions only

// REPLACE ME -- the whole body of this module is a placeholder.
// Arguments default to params.scad values so callers can override for
// variants without touching the customizer.
module part_template(size = [size_x, size_y, size_z], r = effective_radius) {
    rounded_block(size, r);
}

// BUILD:EXCLUDE-START (standalone preview only; stripped from every bundle)
// Lets you open THIS file directly in OpenSCAD (and lets render.sh and the
// smoke check export it). Anything a standalone preview needs that the
// build normally injects -- e.g. mw_plate_size -- is defined here.
part_template();
// BUILD:EXCLUDE-END
