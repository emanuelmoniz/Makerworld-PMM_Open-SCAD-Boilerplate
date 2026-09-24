// ============================================================
// <PROJECT NAME>  |  MAKERWORLD BUNDLE
// ============================================================
// GENERATED FILE -- do not edit. Built from this project's lib/,
// parts/ and assembly/ sources by scripts/build/build.ps1.
//
// Made for the MakerWorld Parametric Model Maker (PMM) customizer.
// It has no top-level render call: PMM invokes the mw_plate_N() and
// mw_assembly_view() modules itself, so opening this file in the
// OpenSCAD desktop app shows an empty preview. That is expected.
// ============================================================
//
// PROJECT DESCRIPTION
//
// <PROJECT NAME>
//
// <PROJECT DESCRIPTION>
// ============================================================

// ---- from lib/params.scad ----
/* [DIMENSIONS] */

// REPLACE ME -- Overall length (X), in mm
size_x = 40; // [10:1:200]

// REPLACE ME -- Overall depth (Y), in mm
size_y = 30; // [10:1:200]

// REPLACE ME -- Overall height (Z), in mm
size_z = 10; // [2:0.5:100]

/* [OPTIONS] */

// REPLACE ME -- Example checkbox: round the vertical edges
rounded = true;

/* [CLEARANCES - TUNE FOR YOUR PRINTER] */

// Gap added to every mating cavity (mm). Nominal parts are never shrunk.
fit_clearance = 0.15; // [0:0.05:0.6]

/* [Hidden] */
corner_radius = 3;
part_color = "SteelBlue";
mw_plate_size = 235; // layout bound -- see scripts/plates_config.sh
mw_assembly_views = ["main"]; // ASSEMBLY_PLATE_VIEWS -- see scripts/plates_config.sh
assembly_view_gap = 30;
$fa = 2;
$fs = 0.4;
effective_radius = rounded ? min(corner_radius, size_x / 2, size_y / 2) : 0;
function param_note(adjusted, msg) = adjusted ? echo(str("NOTE: ", msg)) true : false;
param_notes = [
    param_note(rounded && effective_radius < corner_radius,
        str("corner radius reduced to ", effective_radius, " mm to fit the size")),
];

// ---- from lib/helpers.scad ----
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
module cylinder_wrap_text(txt, size, font, r, r0, r1, center_angle = 270, z = 0,
                          max_width = undef, advance = 1.0) {
    slice_w = min(1.5, max(0.3, size / 8));
    width = min(len(txt) * size * advance,
                is_undef(max_width) ? 2 * PI * r - 2 * slice_w : max_width);
    n = ceil(width / slice_w);
    for (i = [0 : n - 1]) {
        x = (i + 0.5) * slice_w - width / 2;
        rotate([0, 0, center_angle + x / r * 180 / PI])
            translate([r0, 0, z])
                rotate([90, 0, 90])
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

// ---- from parts/part_template.scad ----
module part_template(size = [size_x, size_y, size_z], r = effective_radius) {
    rounded_block(size, r);
}

// ---- from assembly/assembly_main.scad ----
module assembly_main() {
    color("#1a2f4a") part_template();
}
function assembly_main_footprint() = [0, 0, size_x, size_y];
module mw_plate_1() {
    translate([-size_x / 2, -size_y / 2, 0])
        color("#1a2f4a") part_template();
}
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
    } else {
        echo(str("WARNING: unknown assembly view \"", name, "\" -- skipped"));
    }
}
function assembly_view_footprint(name) =
    name == "main" ? assembly_main_footprint() :
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

