# PMM compatibility rules

> **Scope.** The rules a `.scad` file must follow to work in MakerWorld's PMM, and what enforces
> each one here. **Rule IDs (P01–P12) match `scripts/check/pmm_lint.py` output**, so a lint finding
> leads straight to its section. The underlying API is in [specification.md](specification.md);
> sources are in [sources.md](sources.md).

## Summary

| ID | Level | Rule | Enforced by |
|---|---|---|---|
| P01 | ERROR | No local `include`/`use`, only PMM-bundled libraries | build (strips) + lint |
| P02 | ERROR | Bundled-library includes must be in PMM's inventory | lint |
| P03 | ERROR | `// color` parameters must be hex strings | lint |
| P04 | ERROR | Fonts must be in PMM's **installed** inventory | lint |
| P05 | ERROR | No `// preview[...]` comments | lint |
| P06 | ERROR | Never call `mw_plate_N()` / `mw_assembly_view()` yourself | lint |
| P07 | ERROR | `import()` only `default.stl` / `default.svg` / `default.png` | lint |
| P08 | ERROR | No module/function name defined twice | lint |
| P09 | ERROR | No name colliding with BOSL2 when BOSL2 is included | lint (needs local BOSL2) |
| P10 | ERROR | No UTF-8 BOM | build (writes without BOM) + lint |
| P11 | WARN | `mw_plate_size` ≤ about 235 mm | build (caps) + lint + smoke |
| P12 | WARN | Plate modules and top-level geometry shouldn't coexist | lint |
| — | — | Plates match `plates_config.sh` | build (fails on drift) |
| — | — | Every plate compiles from the shipped bundle and fits `mw_plate_size` | smoke |
| — | — | Geometry stays light enough to avoid timeouts | review (not automatable) |

---

## P01: No local includes  *(Employee)*

PMM resolves its own bundled libraries, but not arbitrary local include trees. The build removes
every local `include`/`use` (the bundle is flat, so they aren't needed) and keeps only paths
matching `BUNDLED_LIBRARIES` in `scripts/project_config.sh`.

**Fix:** add the file to `SOURCE_FILES` so its content is flattened in. Never commit a bundle
that still includes a local file.

## P02: Only inventory libraries  *(Endpoint)*

Only the libraries in [data/libraries.json](data/libraries.json) exist on PMM. Don't overcorrect
by removing BOSL2 because "includes don't work". Bundled libraries are fine. *(Endpoint)*

**Fix:** vendor the minimum helpers you need into `lib/` (check the library's license), or pick a
bundled alternative.

## P03: Hex colors for `// color`  *(Official)*

`accent = "#FF6600"; // color` gets a picker. `accent = "Red"; // color` doesn't.

**Related (bundle color flattening):** by default the build rewrites every `color(<variable>)` to
one uniform `MAKERWORLD_COLOR`, so PMM previews look consistent. List a variable in
`COLOR_PASSTHROUGH` to keep its color, e.g. any user-facing `// color` parameter.

**Related (the outermost `color()` wins):** in OpenSCAD, a `color()` wrapping a subtree overrides
every color inside it. A part with an internal distinct color (an inlay or label) must color
itself, and callers must not wrap it. See `examples/demo/parts/sliding_lid.scad`.

## P04: Installed fonts only  *(Endpoint)*

PMM publishes two font lists:

| File | What it is | Trust it for rendering? |
|---|---|---|
| [data/fonts-installed.json](data/fonts-installed.json) | Fonts **installed** in the renderer | **Yes** |
| [data/fonts-catalog.json](data/fonts-catalog.json) | A broader **display catalog** | **No**: may be substituted |

The lint checks every `// font` parameter, every literal `font = "..."`, and every string
variable passed as `font = var`. A catalog-only font gets a specific error.

**Known case:** `"B612 Mono"` is in the catalog but **not** the installed inventory (snapshot
2026-09-22). Installed monospace families include `Roboto Mono`, `Noto Sans Mono`,
`Ubuntu Mono` and `Ubuntu Sans Mono`.

**Also:** the font must be installed **locally** too, or desktop OpenSCAD silently substitutes one
([libraries-and-fonts.md](../openscad/libraries-and-fonts.md#fonts)). Defaults such as
`Liberation Sans` ship with OpenSCAD **and** are installed on PMM, so they're the safest choice.

## P05: No `// preview[...]`  *(Employee)*

A Thingiverse Customizer convention that PMM doesn't use. Delete it.

## P06: Don't call output modules  *(Official)*

`mw_plate_N()` and `mw_assembly_view()` are called by PMM. Calling them from your own code
(including one output module calling another) produces duplicated geometry and couples
unrelated outputs.

**Fix:** move the shared geometry into a normal helper module (e.g. `assembly_main()`) and call
that from each output module.

## P07: Default upload names  *(Official)*

Uploads are reachable only as `default.stl`, `default.svg` or `default.png`. Arbitrary
co-uploaded file names are fragile. *(Community)*

## P08: Duplicate definitions  (OpenSCAD language behavior)

In one flat file, **the last definition of a module/function name silently wins**: no error, no
warning. Two source files defining `helper()` means one of them is silently replaced everywhere.

## P09: BOSL2 name collisions  (OpenSCAD language behavior)

Same mechanism as P08, but against **library** symbols. BOSL2 defines hundreds of generic names
(`cuboid`, `dovetail`, `rounded_prism`, `path_text` …). If your bundle includes BOSL2 and defines
one of those, whichever definition comes last wins, **for every user**, whether or not the
feature using BOSL2 is enabled.

**Fix:** use distinctive names (`dovetail_wedge()`, not `dovetail()`). Don't rely on file order to
"win". The lint scans a local BOSL2 checkout (found through `OPENSCADPATH` or the standard
library folders) for collisions.

## P10: No BOM

OpenSCAD rejects a UTF-8 BOM with a syntax error on line 1. Windows PowerShell 5.1's
`-Encoding utf8` always writes one, which is why the build writes files with
`UTF8Encoding($false)`.

## P11: Plate size ceiling  *(Employee)*

Oversized plates make PMM's 3MF generation fail at the auto-arrange step. The practical ceiling
reported by Bambu staff is about **240 × 235 mm**.

- The build injects `mw_plate_size` (default **235**, from `MW_PLATE_SIZE` in
  `scripts/plates_config.sh`) and caps any derived value at `MW_PLATE_SIZE_CEILING`.
- A plate whose content count grows with parameters must **wrap into rows/columns** bounded by
  `mw_plate_size`, not grow as one long strip.
- The smoke check measures each plate built from the real bundle against `mw_plate_size`.

## P12: Plates *or* top-level geometry

With `mw_plate_N()` defined, PMM renders plates itself. Extra top-level geometry is at best
ignored and at worst duplicated. Leave `MAKERWORLD_TOP_LEVEL_CALL` empty when you use plates.

## Timeouts  *(Community)*

PMM has practical runtime limits. Geometry that eventually renders locally can still time out.
The expensive patterns to watch:

- very high `$fn` (prefer `$fa`/`$fs`; this boilerplate defaults to `$fa = 2; $fs = 0.4;`)
- `minkowski()` on complex shapes, long `hull()` chains inside loops
- text with many glyphs cut into curved surfaces
- large `for` loops of booleans (union many, then subtract once)

The smoke check's render time is a rough local proxy. If a render takes minutes on your machine
with Manifold, simplify.
