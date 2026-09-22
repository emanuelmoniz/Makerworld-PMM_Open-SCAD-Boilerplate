// ============================================================
// Sliding-Lid Box (demo)  |  Shared shape helpers
// ------------------------------------------------------------
// Building blocks with no printed part of their own. Reached with
// `use <../lib/shapes.scad>`. hull() of true cylinders (not rotate +
// linear_extrude) keeps results manifold -- docs/conventions/geometry.md.
// ============================================================

// Box with rounded vertical edges; origin at the outer front-left-bottom
// corner.  size = [x, y, z] mm, r = edge radius mm (0 = plain cube).
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

// Centered 2D label, extruded `h` mm upward from z = 0.
module label_solid(text_value, size, font, h) {
    linear_extrude(height = h)
        text(text_value, size = size, font = font, halign = "center", valign = "center");
}
