# Text on curved surfaces

> **Scope.** Putting a label on a round part (a collar, a cup, a jar lid) so it prints well and
> renders fast on PMM. The helper is `cylinder_wrap_text()` in `lib/helpers.scad`.

## Why not just `text()`?

A flat `linear_extrude(text(...))` pushed into a cylinder has a depth that changes along the
word: at 20 mm from the text's center on a 50 mm radius, the surface is already 4 mm away, so
the letters are deep in the middle and missing at the ends. Projecting the text onto the curve
fixes that.

## How the helper wraps it

The flat text is cut into thin vertical **strips** (2D intersections, cheap), and each strip is
stood up tangent to the cylinder at its own angle along the arc. Because every strip keeps its
slice of the real glyphs, letter spacing and kerning are exactly the font's, with no need for
`textmetrics()` (experimental, and not something to rely on in PMM).

- **Strip width** is `size / 8`, between 0.3 and 1.5 mm: fine enough that the flat facets hug the
  surface (the gap at a strip's edge is under 0.01 mm at a 50 mm radius), coarse enough to stay
  fast. A 20-character label at 40 mm renders in about 5 s; typical labels in about 1 s.
- **Overlap:** strips are 0.05 mm wider than their pitch, so neighbors overlap instead of leaving
  hairline gaps.
- **Width:** OpenSCAD can't measure a text's width, so the helper slices an **overestimate**
  (`len * size * advance`). Extra strips are just empty. Cap it with `max_width` so the text
  stops short of anything else on the surface (a handle, a peg): the text is then cut off there
  instead of running into it. Say in the parameter's help text that long text is cut off.

## Engraved, embossed, inlay

`r0`/`r1` are the letters' radial extent, which makes all three modes one call each:

| Mode | Call | Use |
|---|---|---|
| Engraved | `difference() { body(); cylinder_wrap_text(..., r0 = r - d, r1 = r + 1); }` | cut `d` deep, 1 mm past the surface |
| Embossed | `union() { body(); cylinder_wrap_text(..., r0 = r - 0.5, r1 = r + d); }` | 0.5 mm overlap into the wall for a clean union |
| Inlay (2 colors) | the engraving above for the body, plus `color(c) cylinder_wrap_text(..., r0 = r - d, r1 = r)` as a separate color region | fills the cut exactly ([multicolor](../workflows/multicolor.md)) |

Keep an engraving at least ~0.4 mm short of the wall thickness, and clamp the letter size to the
band it sits on ([geometry, "Clamp, then say so"](../conventions/geometry.md#clamp-then-say-so)).
Embossed letters stick out: count them in the part's plate footprint.

## Placement

`center_angle` is in degrees from +X, counter-clockwise; 270 is the front (-Y, OpenSCAD's front
view), where a customer reads it. The text reads left to right from outside. `z` is the height of
its center line, e.g. the middle of a collar.
