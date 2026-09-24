# Geometry conventions

> **Scope.** How parts are modeled, so they mate predictably, print without supports where
> possible, and stay manifold on PMM's renderer. Read this before any geometry change.

## 1. Origin and orientation

- **Every part module is authored with its outer front-left-bottom corner at `(0,0,0)`.**
  FRONT is the `Y = 0` face, LEFT is `X = 0`, BOTTOM is `Z = 0`. Render perspectives
  (`render_config.sh`) are named from this convention.
- **Author parts in their print orientation**: the flattest, most support-free face down. The
  assembly file rotates and translates each part into its assembled pose, with a comment saying
  why.
- If a part extends past its nominal footprint (a flap, a flange), expose its real footprint and
  offset as derived values in `params.scad`, and use those to center it on its plate.
- **Exception: parts of revolution** (funnels, cups, knobs, lids, anything built with
  `rotate_extrude()`) may be authored **centered on their axis** instead, bottom still at `Z = 0`
  and still in print orientation. A corner origin would only add a translate on the way in and one
  on the way out, and features placed by angle (a handle at 45°) are naturally described around the
  axis. Say so in the part's header and in `AGENTS.md`'s project overview, expose the footprint
  (radius, plus anything sticking out) as derived values, and let `mw_plate_N()` rotate the part
  about its axis and center it on the plate from that footprint. Front and back still follow
  OpenSCAD's view: FRONT is `-Y`.

## 2. Clearances widen the cavity, never shrink the part

- A part's **nominal** dimensions stay nominal. The **mating cavity** (hole, groove, slot, socket)
  is widened by a dedicated clearance parameter.
- One clearance parameter per kind of fit (sliding, press-fit, pivot …), in the
  **CLEARANCES** customizer tab, so customers can tune the fit to their printer.
- Apply a clearance to **every face** of the cavity that touches the part (usually `2 * c` across).
- Never tell a customer to scale the model to fix fit. Point them to the clearance.

*Example:* `examples/demo/lib/params.scad` → `groove_height = lid_thickness + 2 * lid_clearance`.
The lid stays `lid_thickness`.

**Prove it** with a `CLEARANCE_CHECKS` entry (`scripts/project_config.sh`): the smoke check
intersects the two parts in their assembled pose and expects nothing, at every smoke variant. The
demo checks both sides of its fit: the lid slides in (`empty`), and lifted 1 mm it hits the lip
that holds it (`solid`).

## 3. Manifold safety

- **No coincident faces.** Every cut overshoots the surface it opens (`+1`, `-0.01` …) so no
  two faces lie exactly in the same plane. Keep these overlaps, and comment why each one is
  there. Don't "clean them up" to exact boundaries.
- **Tapered and rounded solids: `hull()` of true primitives**, not `rotate()` + `linear_extrude()`.
  Floating-point rotations cause "not a valid 2-manifold" errors. A dovetail is a `hull()` of two
  thin end-caps. A rounded box is a `hull()` of four cylinders.
- **Tangent contacts in previews** (two parts exactly touching in an assembly view) can confuse
  CGAL. Nudge them by a hairline **in the preview only**, with a comment, and never in a
  printed part.
- Union many, subtract once: build all cutters inside one `union()` and `difference()` it a single
  time. This is faster and more robust than dozens of nested differences.

## 4. Printability

- Default target: FDM, 0.4 mm nozzle, 0.2 mm layers.
- Prefer overhangs ≤ 45° from vertical, chamfers over fillets on downward-facing edges, and
  short horizontal bridges (a few mm).
- If a part needs supports, say so in three places: `plates_config.sh` (per-part
  `enable_support=1` for the Bambu export), the README parts table, and the MakerWorld listing.

## 5. Parameters and derived values

- **Every dimension comes from `lib/params.scad`.** No magic numbers in part files, except local,
  self-explanatory overlaps (§3).
- Values derived from parameters are computed **once**, in the `[Hidden]` derived section of
  `params.scad`, and read everywhere. Never recompute a derived value in a part file.
- A module whose geometry changes with a mode flag takes the value as an argument defaulting to
  the parameter (`module cap(half_len = key_half_length)`). Callers can then build variants
  without touching global state.

### Clamp, then say so

A customizer lets customers combine values that don't work together: a tab too long for the
plate, text too big for its band, a groove deeper than the wall. Don't fail and don't silently
build something else. **Clamp** the value in the derived section (`x = min(asked, limit);`), use
the clamped value everywhere, and **tell the customer** with a `NOTE:` in the console:

```openscad
function param_note(adjusted, msg) = adjusted ? echo(str("NOTE: ", msg)) true : false;
param_notes = [
    param_note(tab_l != tab_length, str("tab_length limited to ", tab_l, " mm to fit the plate")),
    param_note(text_s != text_size, str("text_size limited to ", text_s, " mm")),
];
```

The echo sits inside an **assignment**: a top-level `if (...) echo(...)` would trip lint rule P12
(top-level statements next to `mw_plate_N()`). Say in the parameter's help text that it may be
limited ("Limited so it fits the plate"), so the customer isn't surprised. When one limit
depends on the plate size, read `mw_plate_size` from its placeholder in `params.scad`
([source-architecture](source-architecture.md#injected-values-mw_plate_size-mw_assembly_views)).
Cover the clamps with `SMOKE_VARIANTS` entries at the extremes.

## 6. Performance (PMM timeouts)

- Use `$fa = 2; $fs = 0.4;`, set once in `params.scad`. Avoid global `$fn`. If one feature needs
  a fixed segment count, pass `$fn` locally to that call.
- Avoid `minkowski()` on complex shapes and `hull()` inside large loops.
- See [compatibility-rules.md](../pmm/compatibility-rules.md#timeouts--community).
