// ============================================================
// Sliding-Lid Box (demo)  |  MAKERWORLD BUNDLE
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
// Sliding-Lid Box
//
// A parametric storage box with a lid that slides into grooves along its side walls.
// Set the inside length, width and height, the wall and floor thickness, and an optional
// engraved or embossed label on the lid. Prints as two plates, box and lid, with no
// supports needed.
// ============================================================

// ---- from lib/params.scad ----
/* [BOX] */

// Inside length (X), in mm
inner_length = 80; // [30:1:200]

// Inside width (Y), in mm
inner_width = 50; // [20:1:150]

// Inside height (Z), in mm
inner_height = 30; // [10:1:100]

// Wall thickness, in mm
wall = 2.4; // [1.6:0.2:5]

// Floor thickness, in mm
floor_thickness = 2; // [1.2:0.2:5]

/* [LID LABEL] */

// Label style (None to disable)
label_style = "engraved"; // [none:None, engraved:Engraved (cut in), embossed:Embossed (raised)]

// Label text
label_text = "BOX";

// Label size, in mm
label_size = 10; // [4:1:30]

// Label font
label_font = "Liberation Sans:style=Bold"; // font

// Embossed label color (multi-color printing)
label_color = "#E67E22"; // color

/* [CLEARANCES - TUNE FOR YOUR PRINTER] */

// Lid fit: gap added to the groove the lid slides in (mm)
lid_clearance = 0.2; // [0:0.05:0.6]

/* [Hidden] */
lid_thickness = 2;
lip_height = 1.2;
label_depth = 0.6;
notch_radius = 6;
corner_radius = 2;
box_color = "SteelBlue";
lid_color = "LightSlateGray";
assembly_view_gap = 20;
$fa = 2;
$fs = 0.4;
groove_depth = wall / 2;
outer_length = inner_length + 2 * wall;
outer_width  = inner_width + 2 * wall;
outer_height = floor_thickness + inner_height + lid_thickness + lip_height;
groove_z      = floor_thickness + inner_height - lid_clearance;
groove_height = lid_thickness + 2 * lid_clearance;
groove_y0     = wall - groove_depth - lid_clearance;
groove_width  = inner_width + 2 * (groove_depth + lid_clearance);
lid_length = outer_length - (wall - groove_depth);
lid_width  = inner_width + 2 * groove_depth;
lid_x = wall - groove_depth;
lid_y = wall - groove_depth;
lid_z = groove_z + lid_clearance;
mw_plate_size = 235; // layout bound -- see scripts/plates_config.sh
mw_assembly_views = ["main", "open"]; // ASSEMBLY_PLATE_VIEWS -- see scripts/plates_config.sh

// ---- from lib/shapes.scad ----
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
module label_solid(text_value, size, font, h) {
    linear_extrude(height = h)
        text(text_value, size = size, font = font, halign = "center", valign = "center");
}

// ---- from parts/box_body.scad ----
module box_body() {
    difference() {
        rounded_block([outer_length, outer_width, outer_height], corner_radius);
        translate([wall, wall, floor_thickness])
            cube([inner_length, inner_width, outer_height]);
        translate([wall - groove_depth - lid_clearance, groove_y0, groove_z])
            cube([outer_length, groove_width, groove_height]);
        translate([outer_length - wall - 1, wall, groove_z])
            cube([wall + 2, inner_width, outer_height]);
    }
}

// ---- from parts/sliding_lid.scad ----
function sliding_lid_label_center() = [lid_length / 2, lid_width / 2];
module sliding_lid_body() {
    label_center = sliding_lid_label_center();
    color("#1a2f4a") 
    difference() {
        cube([lid_length, lid_width, lid_thickness]);
        translate([lid_length - notch_radius / 2, lid_width / 2, lid_thickness])
            scale([1, 1, 0.5])
                sphere(r = notch_radius);
        if (label_style == "engraved")
            translate([label_center[0], label_center[1], lid_thickness - label_depth])
                label_solid(label_text, label_size, label_font, label_depth + 1);
    }
}
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

// ---- from assembly/assembly_main.scad ----
function open_lid_pull() = lid_length * 0.45;
module assembly_main(lid_pull = 0) {
    assembly_region("box")
        color("#1a2f4a") box_body();
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
module mw_plate_1() {
    translate([-outer_length / 2, -outer_width / 2, 0])
        color("#1a2f4a") box_body();
}
module mw_plate_2() {
    translate([-lid_length / 2, -lid_width / 2, 0])
        sliding_lid();
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

