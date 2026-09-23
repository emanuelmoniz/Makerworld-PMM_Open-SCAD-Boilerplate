# Sliding-Lid Box (demo)

> **Worked example.** This folder is a complete, runnable project built on the boilerplate
> in the repository root. It exists so you can see every convention *working* before
> you write your own geometry, and verify your toolchain end to end. Delete `examples/`
> once you no longer need it. It is independent of the root project.

<!-- BUNDLE-DESCRIPTION:START -->
# Sliding-Lid Box

A parametric storage box with a lid that slides into grooves along its side walls.
Set the inside length, width and height, the wall and floor thickness, and an optional
engraved or embossed label on the lid. Prints as two plates, box and lid, with no
supports needed.
<!-- BUNDLE-DESCRIPTION:END -->

## What this demo shows

| Convention | Where to look |
|---|---|
| Customizer tabs, slider, dropdown, checkbox | [lib/params.scad](lib/params.scad) |
| User-facing `// color` (hex) kept distinct in the bundle | `label_color` + `COLOR_PASSTHROUGH` in [scripts/project_config.sh](scripts/project_config.sh) |
| User-facing `// font` from PMM's *installed* inventory | `label_font` in [lib/params.scad](lib/params.scad) |
| Clearance widens the cavity, never the part | `groove_*` in [lib/params.scad](lib/params.scad), [parts/box_body.scad](parts/box_body.scad) |
| Deliberate `+ 1` overshoot on cuts (no coincident faces) | [parts/box_body.scad](parts/box_body.scad) |
| A part that colors itself (outermost `color()` wins) | [parts/sliding_lid.scad](parts/sliding_lid.scad) |
| A multicolor part: one module per color, one filament each | [parts/sliding_lid.scad](parts/sliding_lid.scad) + `multicolor=1` / `FILAMENT_MAP` in [scripts/](scripts/), [multicolor](../../docs/workflows/multicolor.md) |
| The assembly preview plate in the same colors: every solid in an `assembly_region()`, the lid as its region modules | [assembly/assembly_main.scad](assembly/assembly_main.scad) + `FILAMENT_MAP`, [multicolor](../../docs/workflows/multicolor.md#the-assembly-preview-plate) |
| Multi-plate output + assembly view | [assembly/assembly_main.scad](assembly/assembly_main.scad) |
| Two assembled views (`main`, `open`) stacked on the preview plate by footprint | `ASSEMBLY_PLATE_VIEWS` in [scripts/plates_config.sh](scripts/plates_config.sh) |
| Plates validated against `mw_plate_N()` at build time | [scripts/plates_config.sh](scripts/plates_config.sh) |

## Run it

From the **repository root** (the scripts live there and take a project folder):

```bat
scripts\build.bat examples\demo        :: MakerWorld bundle -> examples\demo\dist\
scripts\dev_build.bat examples\demo    :: dev bundle, open it in OpenSCAD
scripts\check.bat examples\demo        :: PMM lint + smoke check
scripts\render.bat examples\demo       :: preview PNGs -> examples\demo\renders\
scripts\export_3mf.bat examples\demo   :: Bambu .3mf (needs Bambu Studio)
```

Or open any file under `parts/` or `assembly/` directly in OpenSCAD.

## Parts to print

| Part | File | Qty | Notes |
|---|---|---|---|
| Box | `parts/box_body.scad` | 1 | Open side up. The groove ceiling (about 1.4 mm) bridges without support. |
| Lid | `parts/sliding_lid.scad` | 1 | Flat, label side up. With an embossed label the 3MF export puts the label on filament 2. |

## Parameters

| Tab | Parameter | Default | Range |
|---|---|---|---|
| BOX | `inner_length` / `inner_width` / `inner_height` | 80 / 50 / 30 | 30–200 / 20–150 / 10–100 |
| BOX | `wall` / `floor_thickness` | 2.4 / 2 | 1.6–5 / 1.2–5 |
| LID LABEL | `label_style` | engraved | none, engraved, embossed |
| LID LABEL | `label_text` / `label_size` | BOX / 10 | — / 4–30 |
| LID LABEL | `label_font` / `label_color` | Liberation Sans Bold / `#E67E22` | font picker / color picker |
| CLEARANCES | `lid_clearance` | 0.2 | 0–0.6 |

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
