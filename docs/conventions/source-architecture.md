# Source architecture

> **Scope.** How the `.scad` sources are split, how they reference each other, and how that maps
> onto the single-file bundle PMM needs.

## Layers

```
lib/params.scad          parameters + derived values      <- everything includes this
lib/*.scad               shared helpers (no printed part)  <- parts `use` these
parts/<name>.scad        one printed part each             <- assembly `use`s these
assembly/assembly_main.scad  assembled preview + mw_plate_N() / mw_assembly_view()
```

Dependencies point **down** only: a part never depends on an assembly, and a helper never
depends on a part. If two parts share geometry, move it into `lib/`. The exception is a helper
that is intrinsically part of one part (e.g. its profile, reused as a cutter elsewhere). That
may live in the part file, documented at the definition and at each use.

## `include` vs `use`

| Statement | Imports | Runs top-level code? | Use it for |
|---|---|---|---|
| `include <f.scad>` | variables, modules, functions | **yes** | `lib/params.scad` only |
| `use <f.scad>` | modules, functions | no | every other file |

- Parts `include <../lib/params.scad>` because they need its variables.
- Everything else is `use`d, so another file's top-level variables and preview calls can't leak
  in.
- **Paths are relative to the file containing the statement**, not the file you opened:
  `parts/x.scad` reaches params with `../lib/params.scad`.
- In the bundle, all local `include`/`use` lines are removed, since everything is already in one
  file.

## The standalone preview block

Every part and assembly file ends with:

```openscad
// BUILD:EXCLUDE-START (standalone preview only; stripped from every bundle)
part_name();
// BUILD:EXCLUDE-END
```

- It lets you open the file directly in OpenSCAD, and lets the render and smoke pipelines export
  it.
- The build strips it, so the bundle doesn't render every part on top of each other.
- It's also where a standalone preview defines anything the build normally injects
  (e.g. `mw_plate_size = 235;`).

## `SOURCE_FILES`: the bundle manifest

`scripts/project_config.sh` → `SOURCE_FILES` lists every file in the bundle, **in order**:

1. `lib/params.scad` first, always. The Customizer only shows parameters declared before the first
   module.
2. Then helpers, parts and assemblies. Module/function order doesn't matter to OpenSCAD, but
   top-level **variables** must be defined before files that use them at top level.
3. **A file not listed here silently doesn't ship.** The smoke check only tests listed files.

## What the bundle build does

See [pipelines.md](../toolchain/pipelines.md#makerworld-bundle) for the full list. In short: strip
local includes, strip `BUILD:EXCLUDE` blocks, strip maintainer comments (keep UI help text and
widget annotations), flatten colors, inject `mw_plate_size` and `mw_assembly_views`, prepend the
README description.

## Injected values: `mw_plate_size`, `mw_assembly_views`

Neither is defined in `params.scad`. The build injects both right after it, from
`scripts/plates_config.sh`, so each value is written in exactly one place:

| Variable | From | Read by |
|---|---|---|
| `mw_plate_size` | `MW_PLATE_SIZE` (section 1) | plate modules that wrap parts into rows |
| `mw_assembly_views` | `ASSEMBLY_PLATE_VIEWS` (section 3) | `mw_assembly_view()` |

Standalone previews that need them define fallbacks inside their `BUILD:EXCLUDE` block.

## The assembly preview pattern

`mw_assembly_view()` doesn't hardcode which views it shows. Each view has a footprint function
returning its XY box `[xmin, ymin, xmax, ymax]`. `mw_assembly_view()` stacks the listed views front
to back with `assembly_view_gap` of clear space between boxes (`assembly_stack_offsets()`), then
centers the combined box. All views share one X translate, so parts authored at the same origin
line up across views. OpenSCAD can't call a module by name, so `assembly_view()` and
`assembly_view_footprint()` dispatch explicitly. See `assembly/assembly_main.scad`.
