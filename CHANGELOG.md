# Changelog

All notable changes to this project are documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/). Rules for this project, including what counts as a
major, minor or patch change for a parametric model: [docs/conventions/versioning-and-changelog.md](docs/conventions/versioning-and-changelog.md).

<!--
  HOW TO USE (standing directive -- see AGENTS.md):
  - Every change goes under [Unreleased] in the same turn/commit as the change itself, grouped
    as Added / Changed / Fixed / Removed (omit empty groups). Include dev-facing changes too
    (scripts, docs) -- this file is complete; dist/makerworld_listing.md is the filtered,
    customer-facing copy.
  - A release moves [Unreleased] under "## [x.y.z] - YYYY-MM-DD" and updates the compare links
    at the bottom. Only release when asked.
  - Replace <OWNER>/<REPO> below with your GitHub path (scripts/init_project.py does it).
-->

## [Unreleased]

### Added
- Project created from the MakerWorld PMM OpenSCAD boilerplate.
- **Multicolor parts in the Bambu 3MF export.** A part marked `multicolor=1` in
  `scripts/plates_config.sh` is exported as one Bambu object with one part per color region, each
  assigned its own filament, instead of a single-filament mesh. New `FILAMENT_MAP` in
  `scripts/export_3mf_config.sh` maps colors to slots; new `scripts/export/multicolor_3mf.py` does
  the conversion; `assemble_3mf.py` now merges objects with several components. Documented in
  [docs/workflows/multicolor.md](docs/workflows/multicolor.md). MakerWorld output is unchanged —
  PMM already colors the model from the same `color()` calls.
- Demo: the sliding lid is now a multicolor part (body + embossed label on two filaments), with
  its own two-filament `examples/demo/scripts/base_settings.3mf` reference project.
- **Multicolor assembly preview plate.** New `assembly_region(name)` in
  `assembly/assembly_main.scad` marks a color region of an assembled view. When the views mark two
  or more, the 3MF export renders the preview plate one solid per region (new
  `dev_assembly_regions` top-level loop in the dev bundle, `--enable=lazy-union`) and maps them
  through `multicolor_3mf.py` / `FILAMENT_MAP`, so it shows the same colors as the print plates.
  Views without regions export as a single STL, as before. MakerWorld output is unchanged.
  Documented in [docs/workflows/multicolor.md](docs/workflows/multicolor.md#the-assembly-preview-plate)
  and AGENTS.md.
- Demo: the assembled views draw the box, lid body and label as three regions, and
  `FILAMENT_MAP` gains `box_color` (#4682B4) on filament 1.

### Changed
- CI (`.github/workflows/check.yml`) now installs **OpenSCAD Nightly** (`openscad-nightly` from
  the official OBS apt repo) instead of Ubuntu's 2021.01 package, so the smoke check matches the
  development build PMM renders with. It also runs on published releases (and on demand), in
  addition to pushes and pull requests, for both the root project and `examples/demo`. The runner
  is pinned to `ubuntu-24.04` because the nightly repo is per Ubuntu release.

[Unreleased]: https://github.com/<OWNER>/<REPO>/commits/HEAD
