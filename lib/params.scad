// ============================================================
// <PROJECT NAME>  |  Global parameters  (SINGLE SOURCE OF TRUTH)
// ------------------------------------------------------------
// Every other .scad file does `include <../lib/params.scad>` to read these
// variables. Nothing downstream redefines or recomputes them.
//
// THIS FILE IS ALSO THE MAKERWORLD CUSTOMIZER UI. PMM follows the OpenSCAD
// Customizer syntax (docs/openscad/customizer-syntax.md):
//   /* [TAB NAME] */            starts a tab; parameters below belong to it
//   // Help text               the comment line ABOVE a parameter is its
//                              label/help text in the UI
//   x = 10; // [1:0.5:50]      slider: [min:step:max]
//   s = "a"; // [a:Label A, b:Label B]    dropdown (value:Label pairs)
//   flag = true;               checkbox (plain boolean)
//   c = "#FF6600"; // color    PMM color picker -- HEX string ONLY
//   f = "Roboto"; // font      PMM font picker -- name must be in the
//                              INSTALLED inventory (docs/pmm/data/)
//   /* [Hidden] */             everything below is invisible in the UI
//
// GENERATED TABLES: the README and listing parameter tables are built from
// this file (PARAM_TABLES, scripts/project_config.sh). Two optional lines
// ABOVE a parameter's help line feed the customer table only -- the
// customizer reads just the line directly above, and the MakerWorld build
// strips these:
//   // @label: Length            label in the listing (default: the name)
//   // @note: Only with X on     the listing's Compatibility column
//
// BUILD COUPLING (scripts/build/Bundle.psm1): in the MakerWorld bundle,
// comments in every tab EXCEPT [Hidden] are kept verbatim (they are the
// UI help text); comments under [Hidden] are stripped. Write user-facing
// comments for customers, and [Hidden] comments for maintainers.
//
// ORDER OF SECTIONS -- keep it:
//   1. user-facing tabs     (what a MakerWorld customer changes)
//   2. [Hidden] constants   (fixed design values)
//   3. [Hidden] derived     (computed ONCE here, read everywhere)
//
// `mw_plate_size` and `mw_assembly_views` are deliberately NOT defined here:
// the build injects both right after this file (scripts/plates_config.sh:
// MW_PLATE_SIZE, ASSEMBLY_PLATE_VIEWS). Standalone previews of individual
// files that need them must define fallbacks in their BUILD:EXCLUDE block.
//
// See: docs/workflows/add-a-parameter.md, docs/conventions/naming.md
// ============================================================

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

// ---- Fixed design constants (not customer-facing) ----
corner_radius = 3;

// ---- Visualization colors (local previews only) ----
// Named colors are fine HERE because these are never exposed to the PMM UI.
// The MakerWorld build flattens color(<variable>) calls to one uniform hex
// (scripts/project_config.sh FLATTEN_COLORS). A color you DO expose to
// customers must be a hex string with a trailing `// color` comment.
part_color = "SteelBlue";

// ---- Layout spacing ----
// Clear space between consecutive assembled views' bounding boxes on the
// assembly preview plate (mw_assembly_view()). WHICH views appear is not set
// here: `mw_assembly_views` is injected by the build from
// scripts/plates_config.sh ASSEMBLY_PLATE_VIEWS, like mw_plate_size.
assembly_view_gap = 30;

// ---- Render quality ----
// Defaults match what PMM renders. The dev bundle and render pipeline
// override these; keep them as plain `$fa = N;` / `$fs = N;` lines.
$fa = 2;
$fs = 0.4;

// ---- Derived values (single source of truth) ----
// Compute here, once, as plain top-level variables. Never recompute a
// derived value inside a part file -- read it from here instead.
effective_radius = rounded ? min(corner_radius, size_x / 2, size_y / 2) : 0;
