# Changelog

All notable changes to the Sliding-Lid Box demo. Format based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

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
