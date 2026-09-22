# Naming conventions

> **Scope.** Names for files, modules, functions, parameters and outputs. Several of these are
> **load-bearing**: tooling depends on them.

## Load-bearing rules (tooling breaks without them)

| Rule | Depends on it |
|---|---|
| A part file's main module has **exactly** the file's name: `parts/sliding_lid.scad` → `module sliding_lid()` | Plate validator (build), 3MF export object names |
| Output modules are named `mw_plate_1()` … `mw_plate_N()` (sequential) and `mw_assembly_view()` | PMM itself, validator, smoke check |
| The assembly file defining those is `PLATE_ASSEMBLY_FILE` | Validator |
| An assembled view `<name>` is `module assembly_<name>()` + `function assembly_<name>_footprint()`, dispatched by name in `assembly_view()` / `assembly_view_footprint()` | Assembly-view validator (build), `mw_assembly_view()` layout |
| View names are `lowercase_digits_underscores` | Assembly-view validator |
| Render/export targets live under `parts/` or `assembly/` | Render output folder routing |

## Distinctive module and function names

The bundle is one flat file where the **last definition wins silently** (rule P08), including
against bundled libraries like BOSL2 (P09). So:

- ✅ `lid_rounded_block`, `dovetail_wedge`, `stadium_prism`, `label_solid`
- ❌ `box`, `cube_rounded`, `dovetail`, `rounded_prism`, `cuboid`, `text_block`

Rule of thumb: if the name could plausibly exist in a general-purpose library, qualify it.

## Style

| Kind | Style | Example |
|---|---|---|
| Files | `snake_case.scad` | `shelf_slider.scad` |
| Modules / functions | `snake_case` | `divider_grid()`, `lane_width()` |
| Parameters / variables | `snake_case`, units in the help text, not the name | `inner_length`, `wall` |
| Clearances | `<fit>_clearance` | `lid_clearance`, `pivot_clearance` |
| Derived footprints | `<part>_footprint_x`, `<part>_offset_x` | `shelf_footprint_x` |
| Visualization colors | `<part>_color` (Hidden) | `box_color` |
| Mode flags | `<feature>_enabled` (bool) or `<thing>_style` (dropdown) | `flap_enabled`, `shelf_style` |
| Project slug | `lowercase_underscore` | `sliding_lid_box` |

## Output file names

| Output | Pattern |
|---|---|
| MakerWorld bundle | `dist/<slug>_makerworld.scad` |
| Dev bundle | `dist/<slug>_dev.scad` |
| Renders | `renders/{parts,assembly}/<file>_<PERSPECTIVE>_<RATIO>.png` |
| Generated 3MF | `printables/<slug>[_<variant>]_generated.3mf` |
| Hand-curated 3MF | `printables/<slug>_<variant>.3mf` (no `_generated`) |
| STL exports | `stl/<part_name>.stl` (spelled exactly like the part) |
