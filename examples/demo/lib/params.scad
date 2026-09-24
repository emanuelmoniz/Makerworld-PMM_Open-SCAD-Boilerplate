// ============================================================
// Sliding-Lid Box (demo)  |  Global parameters
// ------------------------------------------------------------
// WORKED EXAMPLE of the boilerplate conventions -- compare with the
// commented stub in the repo-root lib/params.scad, which explains every
// rule. What this file demonstrates:
//   - customizer tabs, sliders, a dropdown, a checkbox
//   - a user-facing COLOR parameter: hex string + `// color`, kept
//     distinct in the MakerWorld bundle via COLOR_PASSTHROUGH
//     (examples/demo/scripts/project_config.sh)
//   - a user-facing FONT parameter: `// font`, with a default that is in
//     PMM's INSTALLED font inventory AND bundled with desktop OpenSCAD
//   - a clearance that widens the CAVITY (the lid groove), never the part
//   - [Hidden] constants, then derived values computed once
// ============================================================

/* [BOX] */

// @label: Inside length
// Inside length (X), in mm
inner_length = 80; // [30:1:200]

// @label: Inside width
// Inside width (Y), in mm
inner_width = 50; // [20:1:150]

// @label: Inside height
// Inside height (Z), in mm
inner_height = 30; // [10:1:100]

// @label: Wall thickness
// @note: Thicker walls also make deeper lid grooves
// Wall thickness, in mm
wall = 2.4; // [1.6:0.2:5]

// Floor thickness, in mm
floor_thickness = 2; // [1.2:0.2:5]

/* [LID LABEL] */

// Label style (None to disable)
label_style = "engraved"; // [none:None, engraved:Engraved (cut in), embossed:Embossed (raised)]

// @note: Only when Label style is not None
// Label text
label_text = "BOX";

// @note: Only when Label style is not None
// Label size, in mm
label_size = 10; // [4:1:30]

// @note: Only when Label style is not None
// Label font
label_font = "Liberation Sans:style=Bold"; // font

// @label: Embossed label color
// @note: Only when Label style is Embossed
// Embossed label color (multi-color printing)
label_color = "#E67E22"; // color

/* [CLEARANCES - TUNE FOR YOUR PRINTER] */

// @label: Lid fit
// Lid fit: gap added to the groove the lid slides in (mm)
lid_clearance = 0.2; // [0:0.05:0.6]

/* [Hidden] */

// ---- Fixed design constants ----
lid_thickness = 2;          // nominal lid plate thickness -- never shrunk for fit
lip_height = 1.2;           // solid rim above the groove, holding the lid down
label_depth = 0.6;          // engrave depth / emboss height
notch_radius = 6;           // finger notch at the lid's pull end
corner_radius = 2;          // outer vertical-edge rounding

// ---- Visualization colors (local previews; flattened in the bundle) ----
box_color = "SteelBlue";
lid_color = "LightSlateGray";

// ---- Layout spacing ----
// Clear space between stacked views on the assembly preview plate. Which
// views appear comes from ASSEMBLY_PLATE_VIEWS (scripts/plates_config.sh).
assembly_view_gap = 20;

// ---- Render quality (what PMM renders) ----
$fa = 2;
$fs = 0.4;

// ---- Derived values (single source of truth) ----
// Groove depth into each long side wall: half the wall, so the remaining
// wall behind the groove is never thinner than the groove itself.
groove_depth = wall / 2;

outer_length = inner_length + 2 * wall;
outer_width  = inner_width + 2 * wall;
outer_height = floor_thickness + inner_height + lid_thickness + lip_height;

// Groove: sits right on top of the cavity. Widened by lid_clearance on
// every face -- the lid itself stays at its nominal size.
groove_z      = floor_thickness + inner_height - lid_clearance;
groove_height = lid_thickness + 2 * lid_clearance;
groove_y0     = wall - groove_depth - lid_clearance;
groove_width  = inner_width + 2 * (groove_depth + lid_clearance);

// Lid: runs from the far groove end (x = wall - groove_depth) to flush
// with the open end of the box (x = outer_length).
lid_length = outer_length - (wall - groove_depth);
lid_width  = inner_width + 2 * groove_depth;

// Assembled lid position (inside the groove, centered in its clearance).
lid_x = wall - groove_depth;
lid_y = wall - groove_depth;
lid_z = groove_z + lid_clearance;
