// ============================================================
// <PROJECT NAME>  |  Shared geometry helpers
// ------------------------------------------------------------
// lib/ holds building blocks that have NO printed part of their own:
// shapes, profiles, joints, and functions reused by several parts.
// Parts reach this file with `use <../lib/helpers.scad>` (modules and
// functions only -- never its top-level variables).
//
// RULES FOR EVERY HELPER (docs/conventions/geometry.md):
//   - Build tapered/rounded solids with hull() of true primitives, not
//     rotate() + linear_extrude(): floating-point rotations are a common
//     source of "not a valid 2-manifold" errors.
//   - Give every module/function a DISTINCTIVE name. The MakerWorld bundle
//     is one flat file where the LAST definition of a name wins silently,
//     including names from bundled libraries (BOSL2 defines e.g. cuboid,
//     dovetail, rounded_prism). Prefix or qualify: rounded_block, not box.
//   - Document the argument contract (units, origin) in a comment above.
//
// REPLACE ME: delete rounded_block() if you do not need it, and add your
// own helpers. Remember: a new lib/ file must also be added to
// SOURCE_FILES in scripts/project_config.sh.
// ============================================================

// A box with rounded vertical edges, authored from its outer
// front-left-bottom corner at the origin (docs/conventions/geometry.md).
//   size : [x, y, z] outer dimensions, mm
//   r    : vertical-edge radius, mm (0 = plain cube)
module rounded_block(size, r = 0) {
    if (r <= 0) {
        cube(size);
    } else {
        hull() {
            for (x = [r, size[0] - r], y = [r, size[1] - r])
                translate([x, y, 0])
                    cylinder(h = size[2], r = r);
        }
    }
}

// Text wrapped around a vertical cylinder (a collar, a cup, a jar): the
// flat 2D text is cut into thin vertical strips and each strip is stood up
// tangent to the cylinder at its own angle, so the font keeps its real
// spacing without textmetrics (which PMM may not enable). 2D intersections
// only, so it renders fast -- see docs/openscad/text-on-curved-surfaces.md.
//   txt, size, font : as for text(); size ~ letter height, mm
//   r               : cylinder radius the text is wrapped at, mm
//   r0, r1          : radial extent of the letters, mm. Engraving or inlay
//                     cutter: r - depth .. r + 1. Inlay fill: r - depth .. r.
//                     Embossing: r - 0.5 (overlap into the wall) .. r + depth.
//   center_angle    : where the text is centered, degrees from +X,
//                     counter-clockwise (270 = the front, -Y)
//   z               : height of the text's center line
//   max_width       : longest arc the text may cover, mm (default: one turn).
//                     Text beyond it is cut off -- set it to stop short of a
//                     handle or peg.
//   advance         : rough character width / size; only sizes the slicing
//                     range, overestimating just adds empty strips
// Strips are 0.05 mm wider than their pitch so neighbors overlap instead
// of leaving hairline gaps on the outer face.
module cylinder_wrap_text(txt, size, font, r, r0, r1, center_angle = 270, z = 0,
                          max_width = undef, advance = 1.0) {
    slice_w = min(1.5, max(0.3, size / 8));
    width = min(len(txt) * size * advance,
                is_undef(max_width) ? 2 * PI * r - 2 * slice_w : max_width);
    n = ceil(width / slice_w);
    for (i = [0 : n - 1]) {
        x = (i + 0.5) * slice_w - width / 2;            // strip center, along the arc
        rotate([0, 0, center_angle + x / r * 180 / PI])
            translate([r0, 0, z])
                rotate([90, 0, 90])                       // 2D x -> +Y, y -> +Z, extrude -> +X
                    linear_extrude(r1 - r0)
                        translate([-x, 0])
                            intersection() {
                                text(txt, size = size, font = font,
                                     halign = "center", valign = "center");
                                translate([x - slice_w / 2 - 0.025, -size * 2])
                                    square([slice_w + 0.05, size * 4]);
                            }
    }
}
