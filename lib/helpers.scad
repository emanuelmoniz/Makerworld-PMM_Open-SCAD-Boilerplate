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
