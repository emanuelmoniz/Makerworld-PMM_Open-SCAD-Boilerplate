// ============================================================
// <PROJECT NAME>  |  Main assembly + MakerWorld output modules
// ------------------------------------------------------------
// Everything PMM-facing lives in this one file (PLATE_ASSEMBLY_FILE in
// scripts/project_config.sh):
//
//   1. ASSEMBLED VIEWS -- the parts composed in their assembled pose, for
//      local preview and for MakerWorld's assembly view. Each view "<name>"
//      is a module assembly_<name>() plus a function
//      assembly_<name>_footprint() returning its XY box. More views (open,
//      exploded ...) can live here or in their own assembly/*.scad files.
//
//   2. PMM OUTPUT MODULES (docs/pmm/specification.md). PMM calls these
//      ITSELF -- never call them from your own code:
//        mw_plate_1() .. mw_plate_N()  one module per print plate
//        mw_assembly_view()            preview only, NOT exported to 3MF
//
// TRADE-OFF: defining mw_plate_N() turns off PMM's direct STL download for
// this model. For a single-part model, delete every mw_* module, set
// PLATE_ASSEMBLY_FILE="" and MAKERWORLD_TOP_LEVEL_CALL="<part>();" in
// scripts/project_config.sh, and empty ASSEMBLY_PLATE_VIEWS.
//
// VALIDATION (the build fails on either):
//   - each mw_plate_N() body must call the same part modules, the same
//     number of times, as PLATE_N_PARTS in scripts/plates_config.sh
//   - each view in ASSEMBLY_PLATE_VIEWS needs assembly_<name>(),
//     assembly_<name>_footprint(), and a branch in BOTH dispatchers below
//
// PLATE RULES (docs/pmm/compatibility-rules.md):
//   - Center each plate on X/Y (parts are authored from a corner, so
//     translate by -footprint/2), Z resting at 0.
//   - Keep every print plate inside mw_plate_size x mw_plate_size (injected
//     by the build; PMM ceiling about 240 x 235 mm). Wrap many small parts
//     into rows/columns -- oversize plates make 3MF generation fail.
// ============================================================

include <../lib/params.scad>

use <../parts/part_template.scad>

// ---- 1. Assembled views ----------------------------------------------------
// REPLACE ME: compose your parts in their assembled pose.
module assembly_main() {
    color(part_color) part_template();
}

// XY bounding box of assembly_main(), [xmin, ymin, xmax, ymax], in its own
// frame. Keep it in sync with the module -- mw_assembly_view() lays views
// out by these boxes. Share formulas between a view and its footprint via
// functions (e.g. a positions() function both call) so they cannot drift.
function assembly_main_footprint() = [0, 0, size_x, size_y];

// ---- 2. PMM output modules -------------------------------------------------
// REPLACE ME: one mw_plate_N() per entry in PLATE_NAMES (plates_config.sh).
module mw_plate_1() {
    translate([-size_x / 2, -size_y / 2, 0])
        color(part_color) part_template();
}

// ---- 3. Assembly preview plate (mw_assembly_view) ---------------------------
// View-agnostic: it shows the views listed in `mw_assembly_views` (injected
// by the build from ASSEMBLY_PLATE_VIEWS), stacked front to back with
// assembly_view_gap of clear space between bounding boxes, and centers the
// combined group on X/Y. The 3mf export renders the same layout as its
// "_preview assembly DO NOT PRINT" plate, never re-arranged by Bambu Studio.
//
// Adding a view "<name>": define assembly_<name>() and
// assembly_<name>_footprint(), add one branch to EACH dispatcher below, and
// list it in ASSEMBLY_PLATE_VIEWS. (OpenSCAD cannot call a module by name,
// hence the explicit dispatchers.)

// Dispatches a view name to its module.
module assembly_view(name) {
    if (name == "main") {
        assembly_main();
    } else {
        echo(str("WARNING: unknown assembly view \"", name, "\" -- skipped"));
    }
}

// Dispatches a view name to its footprint; [0, 0, 0, 0] if unknown.
function assembly_view_footprint(name) =
    name == "main" ? assembly_main_footprint() :
    [0, 0, 0, 0];

// Y offset for each footprint in `fps` so they stack front to back with
// exactly `gap` of clear space between one's back edge (ymax) and the next
// one's front edge (ymin). The first stays at 0.
function assembly_stack_offsets(fps, gap, i = 0, acc = []) =
    i >= len(fps) ? acc :
    assembly_stack_offsets(fps, gap, i + 1, concat(acc, [
        i == 0 ? 0 : acc[i - 1] + fps[i - 1][3] + gap - fps[i][1]
    ]));

// All views share ONE X translate, so parts authored at the same origin in
// every view line up; a bigger view simply widens the group's box.
module mw_assembly_view() {
    views = is_undef(mw_assembly_views) ? [] : mw_assembly_views;
    n = len(views);

    if (n > 0) {
        fps  = [for (v = views) assembly_view_footprint(v)];
        offs = assembly_stack_offsets(fps, assembly_view_gap);

        xmin = min([for (f = fps) f[0]]);
        xmax = max([for (f = fps) f[2]]);
        ymin = min([for (i = [0 : n - 1]) offs[i] + fps[i][1]]);
        ymax = max([for (i = [0 : n - 1]) offs[i] + fps[i][3]]);

        for (i = [0 : n - 1])
            translate([-(xmin + xmax) / 2, -(ymin + ymax) / 2 + offs[i], 0])
                assembly_view(views[i]);
    }
}

// BUILD:EXCLUDE-START (standalone preview only; stripped from every bundle)
mw_plate_size = 235;              // the build injects the real values
mw_assembly_views = ["main"];     // into both bundles
assembly_main();
// BUILD:EXCLUDE-END
