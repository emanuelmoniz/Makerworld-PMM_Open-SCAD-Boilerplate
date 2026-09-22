# Workflow: add a printed part

> **Goal.** A new part that previews on its own, ships in the bundle, sits on a plate, and is
> documented, with the build validating that plates and output modules agree.

## Checklist

1. **Create the file.** Copy `parts/part_template.scad` to `parts/<part_name>.scad`.
2. **Name the module exactly `<part_name>`.** The plate validator counts calls to a module named
   like the file ([naming.md](../conventions/naming.md#load-bearing-rules-tooling-breaks-without-them)).
   Make sure the name can't collide with a library symbol.
3. **Model it** following [geometry.md](../conventions/geometry.md): origin at the outer
   front-left-bottom corner, print orientation, clearances on the mating cavity, overlaps on cuts.
   Any new dimension goes into `lib/params.scad` ([add-a-parameter.md](add-a-parameter.md)).
4. **Keep the standalone preview** at the end of the file, inside `BUILD:EXCLUDE-START/-END`.
5. **Register it in the bundle.** Add it to `SOURCE_FILES` (`scripts/project_config.sh`), after
   `lib/` and before the assembly.
6. **Place it on a plate, in both places:**
   - `scripts/plates_config.sh`: add it to a `PLATE_N_PARTS` array (listed twice for two copies),
     with `|enable_support=1` etc. if needed.
   - `assembly/assembly_main.scad`: call it inside the matching `mw_plate_N()`, the same number
     of times, centered and within `mw_plate_size`.
   - Add it to `assembly_main()` (and any other view) in its assembled pose. If it extends a
     view's bounding box, update that view's `assembly_<name>_footprint()` too.
7. **Build and check:** `scripts\build.bat`, `scripts\dev_build.bat`, `scripts\check.bat`. A plate
   drift error means step 6 is out of sync.
8. **Document it:** the README *Parts to print* table, the listing, and a `CHANGELOG.md` entry
   (usually **Added**, minor version).
9. Optionally add it to `TARGETS` in `render_config.sh` and render when you want images.
