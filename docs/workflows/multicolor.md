# Multicolor parts

> **Goal.** A part that prints in more than one filament: a label, an inlay, a logo — one object
> on the plate, each region on its own AMS slot, assigned before you ever open Bambu Studio.

**MakerWorld needs none of this.** PMM colors the generated 3MF from your `color()` calls
([specification §3](../pmm/specification.md)); keep the color variable in `COLOR_PASSTHROUGH`
(`scripts/project_config.sh`) so the build doesn't flatten it, and a MakerWorld customer gets a
multi-color model. Everything below is about the **local Bambu 3MF export** — the file you slice
and print yourself.

## The short version

1. Split the part into one module per color, each wrapped in a single `color()`.
2. Call those modules as **separate top-level children** in the part's `BUILD:EXCLUDE` block.
3. Mark the part `multicolor=1` in `scripts/plates_config.sh`.
4. Map each color to a filament slot in `FILAMENT_MAP` (`scripts/export_3mf_config.sh`).
5. Point `REFERENCE_3MF` at a project saved with at least that many filaments.

`examples/demo` does all five: `parts/sliding_lid.scad` is a lid body plus an embossed label.

## 1. One module per color

```openscad
// Region 1: the lid plate, in lid_color.
module sliding_lid_body() {
    color(lid_color)
    difference() {
        cube([lid_length, lid_width, lid_thickness]);
        translate(...) sphere(r = notch_radius);     // finger notch
    }
}

// Region 2: the raised label, in label_color.
module sliding_lid_label() {
    if (label_style == "embossed")
        color(label_color)
            translate(...) label_solid(label_text, label_size, label_font, label_depth);
}

module sliding_lid() {
    sliding_lid_body();
    sliding_lid_label();
}
```

`sliding_lid()` still exists and still unions the regions: it is what `mw_plate_N()` and every
assembled view call, so the bundle and MakerWorld are unchanged.

**The `color()` must wrap the whole region, not a child inside it.** A `color()` sitting inside a
`difference()` or `intersection()` does not cover the faces that the cut creates — those export
uncolored, the region comes out with two colors, and the export stops with exactly that message.
This is the one trap that bites; it is the same "outermost `color()` wins" rule as everywhere
else ([compatibility-rules](../pmm/compatibility-rules.md)).

Shared geometry between regions goes in a **function** (`sliding_lid_label_center()`), the same
way an assembled view shares formulas with its footprint, so two regions can't drift apart.

## 2. Call the regions at the top level

```openscad
// BUILD:EXCLUDE-START (standalone preview only; stripped from every bundle)
sliding_lid_body();
sliding_lid_label();
// BUILD:EXCLUDE-END
```

Not `sliding_lid();`. Opening the file in OpenSCAD looks identical (top-level children are
unioned for a normal render), but the export runs OpenSCAD with `--enable=lazy-union`, which
keeps those children as **separate closed solids** — and a solid per color is the whole point.
`lazy-union` does **not** propagate through a module call, which is why the calls have to be here
rather than inside `sliding_lid()`.

**Order matters:** where two regions share volume, the one called later owns it (see
[below](#where-regions-overlap-the-last-one-wins)). Keep the usual deliberate `+0.01` so no two
faces are coincident — under an embossed label that overlap then belongs to the label, which is
why the label is called second.

## 3. Flag the part

```bash
PLATE_2_PARTS=(
    "parts/sliding_lid.scad|multicolor=1"
)
```

Without the flag the part exports as one single-filament STL, exactly as before — so this costs
nothing for the rest of your parts, and one extra OpenSCAD run for none of them.

`multicolor=1` cannot be combined with `|auto_orient=1`: Bambu's per-object orient goes through
`--export-stl`, which merges the parts back into one mesh and loses every filament assignment.
Plate-level `PLATE_<N>_AUTO_ORIENT=true` is fine — it orients the object as a unit.

## 4. Map colors to slots

```bash
FILAMENT_MAP=(
    "#778899=1"     # lid_color ("LightSlateGray")
    "#E67E22=2"     # label_color
)
```

Slots are 1-based, in `REFERENCE_3MF`'s filament order. The key is the hex **OpenSCAD exported**,
so named colors work too. You don't have to guess it: run the export once and a missing color
prints as

```
sliding_lid.3mf: no FILAMENT_MAP entry for #E67E22.
       Regions found, in order: #778899, #E67E22
```

An unmapped color always aborts the export. Nothing here silently picks a slot, because a wrong
slot is a wrong print.

## 5. A reference project with enough filaments

`REFERENCE_3MF` supplies the whole print profile, filaments included. If `FILAMENT_MAP` asks for
filament 2 and the reference has one, the export stops and says so. Load the filaments in Bambu
Studio, add any small object, *File > Save Project As...*, and point `REFERENCE_3MF` at that file.

Slots cannot be synthesized: widening the per-filament lists in a saved profile by hand **crashes
Bambu Studio** (tested — `flush_volumes_matrix` alone is N×N, and per-extruder keys must not be
touched). The demo therefore keeps its own two-filament reference at
`examples/demo/scripts/base_settings.3mf` instead of sharing the root project's single-filament one.

## What the export produces

```
  parts/sliding_lid.scad -> sliding_lid.3mf (multicolor)
    region 1: #778899 -> filament 1
    region 2: #E67E22 -> filament 2
```

One OpenSCAD run writes the regions as separate colored solids; `multicolor_3mf.py` turns them
into **one Bambu object with one part per region**, each carrying an `extruder`, and strips the
mesh colors (leaving them in would re-arm Bambu's own color parser). Bambu Studio's CLI then
arranges that object as a single unit, and `assemble_3mf.py` merges it into the multi-plate
project with its parts intact.

If a parameter collapses the part to one region — the demo with `label_style=none` — that is not
an error: the export warns and writes an ordinary single-filament object.

## Why not the obvious alternatives

| Approach | Why not |
|---|---|
| Export a colored 3MF and let Bambu figure it out | Its color parsing is a **GUI dialog**; through the CLI the colors are dropped and the object comes back on one extruder. |
| …and open that file by hand | Bambu 2.5+ converts standard-3MF colors into **Color Painting**: a surface property that bleeds into the interior, not "this volume is filament 2" ([BambuStudio#9666](https://github.com/bambulab/BambuStudio/issues/9666)). |
| Export one mesh, split it by color afterwards | 3MF color is per-triangle. In a body + embossed label, the union dissolved the interface, so neither color's triangles form a closed volume. There is nothing to split. |
| OBJ + MTL | OpenSCAD's OBJ export writes no color at all — no `usemtl`, no vertex colors. Strictly less than 3MF, and the import is still a GUI dialog. |

## Where regions overlap, the LAST one wins

Regions are allowed to share volume, and the region called **later** in the `BUILD:EXCLUDE` block
owns whatever the two of them share. Measured, on a plate sliced through this pipeline:

| Two regions, filament 1 then filament 2 | Sliced result |
|---|---|
| Identical solids, fully coincident | filament 1 not used at all — region 2 took everything |
| Region 2 buried entirely inside region 1 | filament 2 still printed: the buried volume is region 2's |
| Region 2 half sunk into region 1 | filament 2 gets both the sunk and the proud half |

So the deliberate `+0.01` overlap under an embossed label belongs to the *label* — which is what
you want, and why the label is called second. If you ever need the other answer, swap the order of
the two calls. For overlaps big enough to care about, the honest fix is to subtract one region from
the other so the volumes are disjoint and nothing depends on order at all.

## Other things worth knowing

- **Positions come from Bambu either way.** A multicolor part enters Bambu Studio as a 3MF rather
  than an STL, and that changes nothing about placement: neither format keeps the coordinates a
  part was authored at — one object per plate lands centered, two objects get laid out side by
  side. That is why `PLATE_<N>_ARRANGE=false` already warns that unarranged parts overlap
  ([plates_config.sh](../../scripts/plates_config.sh)). Arranged plates, the default, are
  positioned by Bambu's arrange as always.
- **The color is the key.** Change `label_color` in the customizer and `FILAMENT_MAP` needs the
  new hex. Two regions sharing one color share one slot, which is usually what you want.
- **Only the finished project slices.** The per-part `.3mf` the export writes on its way through
  is an intermediate: Bambu Studio's CLI segfaults if you hand it one directly. Slice the file
  `OUTPUT` points at.
