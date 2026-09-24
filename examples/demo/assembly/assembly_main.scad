// ============================================================
// Sliding-Lid Box (demo)  |  Assembly + MakerWorld output modules
// ------------------------------------------------------------
// Views (each = module assembly_<name>() + function assembly_<name>_footprint()):
//   main   lid slid fully into the box
//   open   lid pulled about halfway out
// PMM output modules (called by PMM, never by us):
//   mw_plate_1()        box body, centered on the plate
//   mw_plate_2()        lid, centered on the plate
//   mw_assembly_view()  the views in ASSEMBLY_PLATE_VIEWS
//                       (examples/demo/scripts/plates_config.sh), stacked
// Color regions: every view wraps each solid in assembly_region(), so the
// 3mf export's preview plate is multicolor like plate 2's lid.
//
// The build validates mw_plate_1/2 against PLATE_1_PARTS / PLATE_2_PARTS,
// and every configured view against its module, footprint and dispatcher
// branches. Compare with the commented stub in the repo-root
// assembly/assembly_main.scad.
// ============================================================

include <../lib/params.scad>

use <../parts/box_body.scad>
use <../parts/sliding_lid.scad>

// ---- 1. Assembled views ----------------------------------------------------

// How far the lid sticks out in the "open" view. One function, read by both
// the view and its footprint, so the two can never disagree.
function open_lid_pull() = lid_length * 0.45;

// Every solid sits in one assembly_region() (section 3), so the 3mf export's
// preview plate shows the lid's label in its own filament, exactly like the
// lid on plate 2. That is why the lid is drawn as its two region modules
// rather than sliding_lid(): the same calls, in the same order (label last),
// as parts/sliding_lid.scad's BUILD:EXCLUDE block. No color() around the lid
// regions -- they color themselves; the box's color() sits INSIDE its region
// and on its own line, so the MakerWorld build still flattens it.
module assembly_main(lid_pull = 0) {
    assembly_region("box")
        color(box_color) box_body();
    translate([lid_x + lid_pull, lid_y, lid_z]) {
        assembly_region("lid")
            sliding_lid_body();
        assembly_region("label")
            sliding_lid_label();
    }
}

function assembly_main_footprint() = [0, 0, outer_length, outer_width];

module assembly_open() {
    assembly_main(lid_pull = open_lid_pull());
}

function assembly_open_footprint() =
    [0, 0, max(outer_length, lid_x + open_lid_pull() + lid_length), outer_width];

// ---- 2. Print plates ---------------------------------------------------------

module mw_plate_1() {
    translate([-outer_length / 2, -outer_width / 2, 0])
        color(box_color) box_body();
}

module mw_plate_2() {
    translate([-lid_length / 2, -lid_width / 2, 0])
        sliding_lid();
}

// ---- 3. Assembly preview plate ---------------------------------------------
// Same generic machinery as the repo-root stub: dispatchers + stacking.

// Marks one COLOR REGION of an assembled view, for the 3mf export's preview
// plate -- the assembly-side twin of a multicolor part's top-level region
// calls (docs/workflows/multicolor.md, "The assembly preview plate").
// Wrap every solid of every view in exactly one, OUTSIDE its color():
//     assembly_region("lid")   sliding_lid_body();
// With $assembly_region unset (MakerWorld, previews) it draws its children
// unchanged. The export first sets it to "?" to list the region names, then
// renders one solid per name. A view that uses none is exported as one
// single-color object, as before.
module assembly_region(name) {
    if (is_undef($assembly_region))
        children();
    else if ($assembly_region == "?")
        echo(str("ASSEMBLY_REGION:", name));
    else if ($assembly_region == name)
        children();
}

module assembly_view(name) {
    if (name == "main") {
        assembly_main();
    } else if (name == "open") {
        assembly_open();
    } else {
        echo(str("WARNING: unknown assembly view \"", name, "\" -- skipped"));
    }
}

function assembly_view_footprint(name) =
    name == "main" ? assembly_main_footprint() :
    name == "open" ? assembly_open_footprint() :
    [0, 0, 0, 0];

function assembly_stack_offsets(fps, gap, i = 0, acc = []) =
    i >= len(fps) ? acc :
    assembly_stack_offsets(fps, gap, i + 1, concat(acc, [
        i == 0 ? 0 : acc[i - 1] + fps[i - 1][3] + gap - fps[i][1]
    ]));

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
assembly_main();
// BUILD:EXCLUDE-END
