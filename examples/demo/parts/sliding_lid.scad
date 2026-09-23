// ============================================================
// Sliding-Lid Box (demo)  |  Part: sliding_lid
// ------------------------------------------------------------
// Flat lid at its NOMINAL size (the box groove carries the clearance),
// with a finger notch at the pull end and an optional label.
//
// COLOR RULE demonstrated here: OpenSCAD's outermost color() wins for the
// whole subtree. So this part colors ITSELF (lid body + a distinct
// embossed label) and callers must NOT wrap sliding_lid() in color() --
// that would repaint the label. label_color survives the MakerWorld
// bundle's color flattening because it is listed in COLOR_PASSTHROUGH.
//
// MULTICOLOR PART (docs/workflows/multicolor.md): each color lives in its
// own region module, sliding_lid() unions them for the bundle, and the
// BUILD:EXCLUDE block below calls them as separate top-level children so
// the Bambu 3mf export can give each one its own filament. Keep those two
// facts true together: a region that is not called below never gets a
// filament, and a region that draws in two colors fails the export.
// ============================================================

include <../lib/params.scad>

use <../lib/shapes.scad>

// Where the label sits on the lid. Shared by both regions so the engraved
// cut and the embossed solid can never drift apart.
function sliding_lid_label_center() = [lid_length / 2, lid_width / 2];

// Region 1: the lid plate itself, in lid_color. The color() wraps the whole
// difference(), not just the cube: faces a cut creates are NOT covered by a
// color() that sits inside the difference, and would export uncolored.
module sliding_lid_body() {
    label_center = sliding_lid_label_center();

    color(lid_color)
    difference() {
        cube([lid_length, lid_width, lid_thickness]);

        // Finger notch at the pull (+X) end: a shallow scoop in the top.
        translate([lid_length - notch_radius / 2, lid_width / 2, lid_thickness])
            scale([1, 1, 0.5])
                sphere(r = notch_radius);

        if (label_style == "engraved")
            translate([label_center[0], label_center[1], lid_thickness - label_depth])
                label_solid(label_text, label_size, label_font, label_depth + 1);
    }
}

// Region 2: the raised label, in label_color. Empty unless the label is
// embossed -- with label_style=none or engraved the lid is a one-color
// part and the export says so instead of failing.
module sliding_lid_label() {
    label_center = sliding_lid_label_center();

    if (label_style == "embossed")
        color(label_color)
            translate([label_center[0], label_center[1], lid_thickness - 0.01])
                label_solid(label_text, label_size, label_font, label_depth + 0.01);
}

module sliding_lid() {
    sliding_lid_body();
    sliding_lid_label();
}

// BUILD:EXCLUDE-START (standalone preview only; stripped from every bundle)
// One call per color region, NOT sliding_lid(): OpenSCAD unions them for a
// normal preview, and the 3mf export (with --enable=lazy-union) gets them
// as separate solids to assign filaments to. The label goes LAST because a
// later region owns whatever it shares with an earlier one -- here the
// 0.01 the label is sunk into the lid, which should print as label.
sliding_lid_body();
sliding_lid_label();
// BUILD:EXCLUDE-END
