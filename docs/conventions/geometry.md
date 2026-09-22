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

## 2. Clearances widen the cavity, never shrink the part

- A part's **nominal** dimensions stay nominal. The **mating cavity** (hole, groove, slot, socket)
  is widened by a dedicated clearance parameter.
- One clearance parameter per kind of fit (sliding, press-fit, pivot …), in the
  **CLEARANCES** customizer tab, so customers can tune the fit to their printer.
- Apply a clearance to **every face** of the cavity that touches the part (usually `2 * c` across).
- Never tell a customer to scale the model to fix fit. Point them to the clearance.

*Example:* `examples/demo/lib/params.scad` → `groove_height = lid_thickness + 2 * lid_clearance`.
The lid stays `lid_thickness`.

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

## 6. Performance (PMM timeouts)

- Use `$fa = 2; $fs = 0.4;`, set once in `params.scad`. Avoid global `$fn`. If one feature needs
  a fixed segment count, pass `$fn` locally to that call.
- Avoid `minkowski()` on complex shapes and `hull()` inside large loops.
- See [compatibility-rules.md](../pmm/compatibility-rules.md#timeouts--community).
