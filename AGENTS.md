# AGENTS.md

Instructions for AI coding agents (and humans) working in this repository. This is the
**canonical** agent file: `CLAUDE.md` and any other tool-specific file only point here, so every
tool follows the same rules.

## What this repository is

A parametric 3D-printable model written in **OpenSCAD** and published on **MakerWorld** through
its **Parametric Model Maker (PMM)** customizer. PMM takes a single `.scad` file, so the
multi-file sources (`lib/`, `parts/`, `assembly/`) are flattened by a build script into
`dist/<slug>_makerworld.scad`.

> **If `README.md` still starts with a TEMPLATE banner**, this is the unmodified boilerplate.
> The model-specific sections below (`Project overview`) are placeholders until a project fills them.

## Read before acting

Read what the task touches, in this order:

1. **This file**: layout, commands, standing directives.
2. [docs/INDEX.md](docs/INDEX.md): the map of every reference doc and when to read it.
3. Before **any customizer-facing change** (parameters, colors, fonts, uploads, plates):
   [docs/pmm/specification.md](docs/pmm/specification.md) and
   [docs/pmm/compatibility-rules.md](docs/pmm/compatibility-rules.md).
4. Before **any geometry change**: [docs/conventions/geometry.md](docs/conventions/geometry.md).
5. Before **adding a file, module, or library**:
   [docs/conventions/source-architecture.md](docs/conventions/source-architecture.md) and
   [docs/conventions/naming.md](docs/conventions/naming.md).

## Project overview

<!-- FILL IN when the project is created: 1-3 paragraphs on what the object is, its parts and
     how they mate, and any mode switches (booleans that change geometry). This is the context an
     agent needs before touching geometry. -->
<PROJECT OVERVIEW: what the model is, its parts, how they fit together.>

## Folder layout

| Path | What lives there | Hand-edited? |
|---|---|---|
| `lib/params.scad` | Every parameter, split into customizer tabs, then `[Hidden]` constants and derived values. **The single source of truth.** | yes |
| `lib/*.scad` | Shared geometry helpers with no printed part of their own | yes |
| `parts/<name>.scad` | One printed part per file; main module named exactly `<name>` | yes |
| `assembly/assembly_main.scad` | Assembled views (`assembly_<name>()` + `assembly_<name>_footprint()`), PMM output modules `mw_plate_N()` / `mw_assembly_view()` | yes |
| `scripts/*_config.sh` | Pipeline configs (bash syntax, heavily commented) | yes |
| `scripts/{build,render,export,check,shared}/` | Pipeline implementations | rarely |
| `dist/<slug>_makerworld.scad` | **Generated** MakerWorld bundle (tracked) | **never** |
| `dist/<slug>_dev.scad` | **Generated** dev bundle (gitignored) | **never** |
| `dist/makerworld_listing.md` | Customer-facing MakerWorld listing text | yes |
| `renders/`, `stl/`, `printables/` | Published assets (PNG / STL / 3MF) | produced by scripts |
| `.build/` | Generated intermediates such as `plates.json` (gitignored) | **never** |
| `docs/` | Reference library: PMM specs, conventions, toolchain, workflows | yes |
| `examples/demo/` | Independent runnable example project, safe to delete | — |

## Commands

All scripts accept a project folder (default: the repo root), e.g. `-Project examples/demo`
(PowerShell) or `-p examples/demo` (bash). On Windows, the `.bat` wrappers take it as the first
argument.

| Task | Windows | Direct |
|---|---|---|
| MakerWorld bundle | `scripts\build.bat` | `powershell -File scripts/build/build.ps1` |
| Dev bundle | `scripts\dev_build.bat` | `powershell -File scripts/build/dev_build.ps1` |
| Freshness + lint + smoke check | `scripts\check.bat` | `bash scripts/check/check.sh` |
| Render PNGs | `scripts\render.bat` | `bash scripts/render/render.sh` |
| Bambu 3MF export | `scripts\export_3mf.bat` | `bash scripts/export/export_3mf.sh` |
| Refresh PMM inventories | — | `python scripts/shared/pmm_inventory.py` |
| List Bambu setting keys | — | `python scripts/export/list_settings.py [--grep KEY]` |

To preview one part, open `parts/<name>.scad` in OpenSCAD: its `BUILD:EXCLUDE` block renders it
standalone. There is no package manager. The test suite is `scripts/check/`: freshness (the
tracked bundle and the generated parameter tables match the sources), lint, and smoke (every
plate built from the shipped bundle, with the defaults and with every `SMOKE_VARIANTS` set, plus
the `CLEARANCE_CHECKS` interference tests).

## Standing directives

Follow these automatically, without being asked. Check this list after every change, before
ending a turn. If the user's explicit instruction in a turn conflicts with one of them, the
user's instruction wins **for that turn only**.

**Trigger: any change that affects the printed object**: a source edit under `lib/`, `parts/` or
`assembly/`, a change to `SOURCE_FILES`, or anything else that changes what the bundle contains.
Editing docs, configs that don't touch the bundle, or this file does **not** trigger it.
Do all four, in the same turn as the change:

1. **Rebuild both bundles**: `scripts/build/build.ps1` and `scripts/build/dev_build.ps1`. Never
   hand-edit anything in `dist/` except `makerworld_listing.md`.
2. **Run the checks**: `scripts/check/check.sh`. A STALE freshness result, a lint ERROR or a smoke
   failure is a blocker. Fix it or report it; don't leave it silently. A new option or size range
   gets a `SMOKE_VARIANTS` entry (`scripts/project_config.sh`) that exercises it; a new moving or
   mating part gets a `CLEARANCE_CHECKS` entry proving it clears (or holds).
3. **Update both READMEs** with whatever is newly relevant: `README.md` (keep the
   `BUNDLE-DESCRIPTION` span accurate, since it ships inside the bundle) and
   `dist/makerworld_listing.md`. The **parameter tables** in both (between the
   `<!-- PARAMETERS:START/END -->` markers) are generated by the build from `params.scad`: never
   edit them, change the help text or the `// @label:` / `// @note:` lines in `params.scad`
   instead. The listing's changelog is **customer-facing only**: features,
   fixes and parameter changes that affect what someone prints or customizes. Leave out build
   scripts, refactors and tooling.
4. **Update `CHANGELOG.md`** under `## [Unreleased]` (Added / Changed / Fixed / Removed). This one
   is **complete**: dev-facing changes belong here too.

**Always in force:**

- **Never render, export a 3MF, or produce images unless the user asks in that turn**, not even
  after a qualifying change. Renders are opt-in. Builds and checks are automatic.
- **Never commit, push, tag or release unless the user asks in that turn.** Leave changes in the
  working tree and say they're uncommitted. Release steps are in
  [docs/workflows/release.md](docs/workflows/release.md).
- **Never edit generated files** (`dist/*.scad`, `.build/*`). Change the source and rebuild.
- **Don't bypass the pre-commit hook** (`git commit --no-verify`) unless the user asks. It refuses a
  commit whose bundle or parameter tables are stale; rebuild and stage the result instead.
- **An optional part draws nothing when switched off.** Its main module checks its own enable
  parameter, not just the `mw_plate_N()` that calls it: the Bambu export renders the part file's
  `BUILD:EXCLUDE` preview, skips a part that comes out empty and drops a plate left with no parts
  ([pipelines](docs/toolchain/pipelines.md#3mf-export-optional-bambu-studio)).
- **Keep `plates_config.sh` and `mw_plate_N()` in sync.** The build fails on drift. Fix the cause,
  never the check. The same goes for `ASSEMBLY_PLATE_VIEWS` and the assembled views it names.

## Rules that are easy to break

The full rationale is in the linked docs. These are the ones that fail silently.

- **Name collisions are silent.** The bundle is one flat file, and the *last* definition of a
  module or function name wins, including names from BOSL2 and other bundled libraries. Give
  every module/function a distinctive name, and let `pmm_lint.py` (rule P08/P09) confirm it.
  → [naming](docs/conventions/naming.md)
- **`include` vs `use`.** Parts `include <../lib/params.scad>` (they need its variables) but `use`
  every other file (modules/functions only). Paths are relative to the file that contains the
  statement. → [source-architecture](docs/conventions/source-architecture.md)
- **Every new `.scad` file goes into `SOURCE_FILES`** in `scripts/project_config.sh`, or it
  silently won't ship.
- **Clearances widen the cavity, never shrink the part.** Deliberate small overlaps on cuts
  (`+0.01`, `+1`) prevent coincident faces. Don't "clean them up".
  → [geometry](docs/conventions/geometry.md)
- **Parts are authored at their outer front-left-bottom corner, in print orientation.** Assemblies
  move them into place. Parts of revolution may be centered on their axis instead
  ([geometry](docs/conventions/geometry.md#1-origin-and-orientation)); say so in the part's header.
- **PMM customizer syntax:** a user-facing color must be a hex string with `// color`; a user-facing
  font needs `// font` and must be in PMM's **installed** inventory (`docs/pmm/data/`), not just its
  display catalog. `// preview[...]` doesn't work in PMM. → [specification](docs/pmm/specification.md)
- **Never call `mw_plate_N()` or `mw_assembly_view()` yourself.** PMM calls them. Shared geometry
  goes in neutral helper modules.
- **A multicolor part is one module per color, called as separate top-level children** in its
  `BUILD:EXCLUDE` block, plus `multicolor=1` in `plates_config.sh` and a `FILAMENT_MAP` entry per
  color. **The assembled views must mirror it** so the preview plate is multicolor too. Wrap every
  solid of every view in `assembly_region("<name>")`, on its own line above the `color()`, and
  call the part's region modules, not its main module. Any other color in the views also needs a
  `FILAMENT_MAP` entry. Each region's `color()` must wrap the whole region: a `color()` inside a `difference()`
  leaves the cut faces uncolored and the export rejects the part. MakerWorld is unaffected either
  way. → [multicolor](docs/workflows/multicolor.md)
- **An assembled view "<name>" is three things:** `module assembly_<name>()`, a matching
  `function assembly_<name>_footprint()` (its XY box, used to lay the MakerWorld preview out),
  and a branch in both dispatchers `assembly_view()` / `assembly_view_footprint()`. Share formulas
  between a view and its footprint through functions so they can't drift. The build checks all
  three for every view in `ASSEMBLY_PLATE_VIEWS`.
- **Plates must fit about 235 × 235 mm** (PMM's practical ceiling). Wrap many parts into rows
  bounded by the injected `mw_plate_size`.
- **Heavy geometry can time out on PMM** even when it renders locally. Avoid needlessly high
  `$fn` and huge `minkowski()` / deep `hull()` chains.
