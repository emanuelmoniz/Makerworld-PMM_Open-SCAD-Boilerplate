// ============================================================
// Sliding-Lid Box (demo)  |  Part: box_body
// ------------------------------------------------------------
// Open-top box with a groove along both long side walls that the lid
// slides into from the +X end, whose end wall is cut down to let it in.
//
// Conventions shown (docs/conventions/geometry.md):
//   - origin at the outer front-left-bottom corner, print orientation
//     (open top up -- the only overhang is the groove ceiling, about
//     1.4 mm deep at defaults, which bridges without support)
//   - lid_clearance widens the GROOVE (params.scad); the lid is nominal
//   - every cut overshoots the surface it opens by 1 mm (the "+ 1"s) so
//     no two faces are coincident -- do not "clean these up"
// ============================================================

include <../lib/params.scad>

use <../lib/shapes.scad>

module box_body() {
    difference() {
        rounded_block([outer_length, outer_width, outer_height], corner_radius);

        // Cavity, open to the top.
        translate([wall, wall, floor_thickness])
            cube([inner_length, inner_width, outer_height]);

        // Lid groove, running out through the +X end wall.
        translate([wall - groove_depth - lid_clearance, groove_y0, groove_z])
            cube([outer_length, groove_width, groove_height]);

        // +X end wall removed above the groove floor, so the lid can pass.
        translate([outer_length - wall - 1, wall, groove_z])
            cube([wall + 2, inner_width, outer_height]);
    }
}

// BUILD:EXCLUDE-START (standalone preview only; stripped from every bundle)
color(box_color) box_body();
// BUILD:EXCLUDE-END
