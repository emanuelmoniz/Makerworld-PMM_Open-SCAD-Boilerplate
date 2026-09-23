# Changelog

All notable changes to the Sliding-Lid Box demo. Format based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- The lid is now a **multicolor part** for the local Bambu 3MF export: `sliding_lid_body()` and
  `sliding_lid_label()` are separate color regions, exported as one object with the label on
  filament 2 (`multicolor=1` + `FILAMENT_MAP`, see
  [docs/workflows/multicolor.md](../../docs/workflows/multicolor.md)).
- `scripts/base_settings.3mf`: the demo's own reference project, with two filaments — the root
  project's has one, which is not enough for the label's slot.

### Changed
- `sliding_lid()` now unions two region modules instead of drawing the lid inline. Same geometry,
  same customizer, same MakerWorld output.
- The lid's `color(lid_color)` moved outside its `difference()`, so the finger scoop's cut faces
  take the lid color too (they previously exported uncolored).
- The 3MF export runs with `label_style="embossed"`, the configuration the multicolor path
  demonstrates.

## [1.0.0] - 2026-09-22

### Added
- Box body with lid grooves on both long walls and an open +X end.
- Sliding lid with a finger scoop and an optional engraved or embossed label (font and color
  pickers).
- `lid_clearance` parameter widening the groove, not the lid.
- Two MakerWorld plates (box, lid).
- Two assembled views, `main` (lid closed) and `open` (lid half out), each with a footprint
  function. MakerWorld's assembly view stacks them via `ASSEMBLY_PLATE_VIEWS`, and the 3MF export
  repeats the layout as a non-printing preview plate.
