# assembly/: assembled preview and PMM output modules

`assembly_main.scad` (`PLATE_ASSEMBLY_FILE` in `scripts/project_config.sh`) holds:

- `assembly_main()` + `assembly_main_footprint()`: the default **view** (parts in their assembled
  pose) and its XY box. Add more views the same way: `assembly_<name>()` +
  `assembly_<name>_footprint()`, plus a branch in `assembly_view()` and `assembly_view_footprint()`.
- `mw_plate_1()` … `mw_plate_N()`: one per print plate. **Called by PMM, never by you.** The build
  checks them against `scripts/plates_config.sh`.
- `mw_assembly_view()`: PMM's preview, excluded from PMM's 3MF. It stacks and centers the views
  listed in `ASSEMBLY_PLATE_VIEWS` (`scripts/plates_config.sh`). The Bambu export adds the same
  layout as a non-printing last plate.
- `assembly_region(name)`: marks one color region of a view. If a part is multicolor, wrap every
  solid of every view in one, and call that part's region modules rather than its main module. The
  preview plate then gets one filament per color, like the print plates. See
  [docs/workflows/multicolor.md](../docs/workflows/multicolor.md#the-assembly-preview-plate).

More preview states (exploded, open …) can live in extra files here. Add them to `SOURCE_FILES`
only if the bundle needs them, and to `DEV_VIEWS` to preview them in the dev bundle.

Reference: [docs/pmm/specification.md §6](../docs/pmm/specification.md).
