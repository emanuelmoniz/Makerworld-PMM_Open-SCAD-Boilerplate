# Boilerplate changelog

History of the **boilerplate itself** (scripts, docs, conventions). A project created from the
template keeps its own root `CHANGELOG.md` and can delete this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), [SemVer](https://semver.org/).

## [Unreleased]

## [1.3.1] - 2026-09-24

### Fixed
- Clearance checks: each expression is now wrapped in `union() { }`. OpenSCAD drops an `if` whose
  condition is false from a node's children, so `intersection() { A; if (c) B; }` returned all of
  A when `c` was false, and a guarded check reported `solid` instead of `empty`. Found when the
  first real project (the funnel) imported v1.3.0.
- `.gitignore`: `**/dist/*_dev.json`, the customizer parameter sets OpenSCAD saves next to the
  dev bundle, is no longer offered for commit.

## [1.3.0] - 2026-09-24

### Added
- **Tight render framing.** `RENDER_FIT="tight"` (`render_config.sh`, the new template default)
  fits each perspective and ratio to the model's actual outline with the new
  `scripts/shared/render_fit.py`, centered, filling the frame to `1 / (1 + RENDER_MARGIN)`. On the
  demo every view now fills 91% of its limiting side (the sphere fit, still available as
  `RENDER_FIT="sphere"`, gave 58–84%). The view-space convention of OpenSCAD's `--camera` was
  established by rendering, not assumed: top view at `[0,0,0]`, scene turned by the inverse
  rotation.
- **Clearance checks.** `CLEARANCE_CHECKS` in `project_config.sh`: `"name|A|B|empty or solid"`,
  intersected in the shipped bundle with the defaults and every `SMOKE_VARIANTS` set, so a
  collision (or a latch that no longer holds) fails the smoke check. The demo proves its lid fit
  both ways. A plate-less bundle's top-level call is stripped for these checks.
- `cylinder_wrap_text()` in the template's `lib/helpers.scad`: text wrapped around a cylinder,
  strip by strip, with the font's real spacing and no `textmetrics()`; engraved, embossed or inlay
  through its radial extent. Recipe in the new `docs/openscad/text-on-curved-surfaces.md`.
- `CLAUDE.md`: write multi-line scripts to a file instead of a heredoc, assert-once patch
  scripts, raw strings can't end in a backslash, stale VS Code OpenSCAD diagnostics.

## [1.2.0] - 2026-09-24

### Added
- `params.scad` may declare `mw_plate_size` and `mw_assembly_views` as **placeholders** in its
  `[Hidden]` section; the build rewrites them in place (new `Set-InjectedValues` in
  `Bundle.psm1`, used by both builds) instead of appending them after the file. Derived values
  can now use the plate size: before, anything computed in `params.scad` read it as undef,
  because OpenSCAD evaluates top-level assignments in order. Without placeholders the build
  appends the lines as before. The root template and the demo declare them, so their assembly
  previews drop the `BUILD:EXCLUDE` fallbacks.
- "Clamp, then say so" pattern (`docs/conventions/geometry.md`): clamp an impossible customer
  value in the derived section and print a `NOTE:` with `param_note()`, an echo inside an
  assignment (a top-level `if/echo` trips lint P12). The template `params.scad` ships the helper
  with an example.
- `export_3mf.sh -D 'param=value'` (repeatable) and `-o file`: a one-off test export without
  editing `export_3mf_config.sh`.
- Release workflow: GitHub release step (`gh release create` with the changelog section as notes
  and the bundle, 3MF and STLs attached).

### Changed
- Geometry convention: parts of revolution may be authored centered on their axis instead of at
  the front-left-bottom corner (`geometry.md` §1, `AGENTS.md`, `add-a-part.md`, part template).

### Fixed
- `.gitattributes`: the `.githooks/*` rule had a trailing comment, which git reads as attribute
  names ("# is not a valid attribute name"). The LF rule itself applied.

## [1.1.0] - 2026-09-24

Lessons from the first project built on the template (a parametric funnel with optional parts,
a two-color label and a hanging arc).

### Added
- **Generated parameter tables.** `scripts/shared/param_tables.py` writes the README and listing
  parameter tables from `params.scad` between `<!-- PARAMETERS:START/END -->` markers, so they
  can't drift from the code (hand-kept tables went stale in practice). Configured by
  `PARAM_TABLES` in `project_config.sh` (styles `readme` / `listing`). Optional `// @label:` and
  `// @note:` lines above a parameter's help line feed the customer table; the MakerWorld build
  strips them. The build regenerates the tables after writing the bundle.
- **Freshness check** `scripts/check/fresh.sh`, first stage of `check.sh`: builds the bundle into
  a temp file (new `build.ps1 -OutFile`) and compares it with the tracked one, then checks the
  parameter tables. Catches a `params.scad` change committed without a rebuild (which failed CI
  in that project) regardless of git state.
- **Pre-commit hook** `.githooks/pre-commit` running the freshness check for the root project and
  the demo; `init_project.py` enables it (`git config core.hooksPath .githooks`).
- **Smoke variants.** `SMOKE_VARIANTS` in `project_config.sh`: named parameter-override sets
  (`"name|a=1; b=\"x\""`) for which the smoke check builds every plate and the assembly
  preview again, with the same plate-size check (new stage 3). The demo ships four.

### Changed
- Bambu 3MF export: a part that renders nothing with the run's parameters is skipped, and a plate
  left with no parts is dropped (was: the export aborted). Per-part `--object-set` overrides
  follow the output plate numbering. New standing rule in `AGENTS.md`: an optional part's main
  module draws nothing when switched off.
- CI no longer runs the MakerWorld build before checking (it would rewrite a stale bundle and
  tables and hide them); `check.sh`'s freshness stage compares against a temp build instead.
- `smoke.sh`: plate / preview checks moved into `check_outputs()`, shared by stages 2 and 3;
  `export_stl` passes extra OpenSCAD arguments.

### Fixed
- Demo: an embossed label is clipped to the lid. A long or large one overhung it (plate 2 grew
  to 349 mm with "SPICES & HERBS" at size 30); found by the new smoke variants.

## [1.0.0] - 2026-09-23

### Added
- Initial boilerplate, extracted and generalized from a released multi-part PMM project
  (v2.0.0 of a parametric spice-rack drawer).
- Source layout `lib/` → `parts/` → `assembly/` with commented, minimally valid stubs.
- MakerWorld bundle and dev bundle builds sharing one PowerShell module (`Bundle.psm1`), driven
  by `scripts/project_config.sh`. Every script takes a project folder.
- Plate validation: `mw_plate_N()` bodies are checked against `scripts/plates_config.sh` and the
  build fails on drift.
- `mw_plate_size` resolution: explicit (deterministic default), or printer-derived, always capped
  at PMM's ~235 mm practical ceiling.
- README ↔ bundle coupling through HTML-comment markers (was literal headings).
- Configurable assembly preview (ported from the source project's v2.0.1):
  `ASSEMBLY_PLATE_VIEWS` / `ASSEMBLY_PLATE_NAME` in `plates_config.sh`, injected as
  `mw_assembly_views`. View-agnostic stacking math driven by per-view footprint functions.
  Build-time validation of every configured view. The 3MF export appends the same layout as an
  unarranged, bed-centered, non-printing last plate rendered from the dev bundle, and the dev
  bundle gains `dev_view_offset`. `bambu_export_plate()` is shared by all plates.
- PMM lint (`pmm_lint.py`, rules P01–P12), including installed-vs-catalog font checks, font
  variables, BOSL2 name-collision scan, direct output-module calls, and duplicate definitions.
- Smoke check that exports every source file and builds every plate from the shipped bundle,
  measuring footprints.
- Render manager with a Python bounding-sphere camera fit (no PowerShell dependency).
- Bambu multi-plate 3MF export with a reference settings profile and `list_settings.py` (replaces
  a 580-line pasted key dump).
- Tool discovery with environment-variable overrides (no hardcoded paths). Git Bash locator that
  avoids WSL bash.
- PMM inventory refresher and snapshot (`docs/pmm/data/`), with the working endpoint URLs.
- `AGENTS.md` (canonical, tool-agnostic) imported by `CLAUDE.md`. `llms.txt`.
- Reference docs: PMM specification, compatibility rules, sources; OpenSCAD customizer syntax,
  libraries and fonts; conventions; toolchain; workflows.
- `examples/demo`: a runnable sliding-lid box exercising every convention.
- `init_project.py` token filler, `.gitattributes` / `.editorconfig`.
- Multicolor parts in the Bambu 3MF export: a part marked `multicolor=1` exports as one object
  with one part per color region, each on its own filament (`FILAMENT_MAP`,
  `multicolor_3mf.py`). `assembly_region(name)` makes the assembly preview plate multicolor too.
  The demo's lid (body + embossed label) and assembled views use both.
- CI workflow (`.github/workflows/check.yml`): builds, stale-bundle check, lint and smoke for the
  root project and `examples/demo` on every push, pull request and published release, using
  **OpenSCAD Nightly** (`openscad-nightly` from the official OBS apt repo).

[Unreleased]: https://github.com/emanuelmoniz/Makerworld-PMM_Open-SCAD-Boilerplate/compare/v1.3.1...HEAD
[1.3.1]: https://github.com/emanuelmoniz/Makerworld-PMM_Open-SCAD-Boilerplate/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/emanuelmoniz/Makerworld-PMM_Open-SCAD-Boilerplate/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/emanuelmoniz/Makerworld-PMM_Open-SCAD-Boilerplate/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/emanuelmoniz/Makerworld-PMM_Open-SCAD-Boilerplate/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/emanuelmoniz/Makerworld-PMM_Open-SCAD-Boilerplate/releases/tag/v1.0.0
