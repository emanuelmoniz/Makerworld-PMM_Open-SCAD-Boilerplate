# Boilerplate changelog

History of the **boilerplate itself** (scripts, docs, conventions). A project created from the
template keeps its own root `CHANGELOG.md` and can delete this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), [SemVer](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-09-22

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
- `init_project.py` token filler, CI workflow, `.gitattributes` / `.editorconfig`.
