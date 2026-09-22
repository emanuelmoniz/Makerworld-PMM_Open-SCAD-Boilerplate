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
// ============================================================

include <../lib/params.scad>

use <../lib/shapes.scad>

module sliding_lid() {
    label_center = [lid_length / 2, lid_width / 2];

    difference() {
        color(lid_color)
            cube([lid_length, lid_width, lid_thickness]);

        // Finger notch at the pull (+X) end: a shallow scoop in the top.
        translate([lid_length - notch_radius / 2, lid_width / 2, lid_thickness])
            scale([1, 1, 0.5])
                sphere(r = notch_radius);

        if (label_style == "engraved")
            translate([label_center[0], label_center[1], lid_thickness - label_depth])
                label_solid(label_text, label_size, label_font, label_depth + 1);
    }

    if (label_style == "embossed")
        color(label_color)
            translate([label_center[0], label_center[1], lid_thickness - 0.01])
                label_solid(label_text, label_size, label_font, label_depth + 0.01);
}

// BUILD:EXCLUDE-START (standalone preview only; stripped from every bundle)
sliding_lid();
// BUILD:EXCLUDE-END
