# Pipelines

> **Scope.** The five pipelines: what each one does, what it reads and writes, and how they share
> configuration. Commands are in [AGENTS.md](../../AGENTS.md#commands).

```mermaid
flowchart LR
    subgraph src[Sources]
        P[lib/params.scad]
        L[lib/*.scad]
        T[parts/*.scad]
        A[assembly/assembly_main.scad]
    end
    subgraph cfg[Configs: scripts/]
        PC[project_config.sh]
        PL[plates_config.sh]
        RC[render_config.sh]
        EC[export_3mf_config.sh]
    end
    PL --> J[.build/plates.json]
    src --> B[build.ps1] --> MW[dist/slug_makerworld.scad]
    src --> D[dev_build.ps1] --> DV[dist/slug_dev.scad]
    PC --> B & D
    J -->|validate mw_plate_N + mw_plate_size| B & D
    MW --> C[check: lint + smoke]
    src --> C
    src --> R[render.sh] --> PNG[renders/*.png]
    RC --> R
    src --> E[export_3mf.sh] --> M3[printables/*.3mf]
    J --> E
    EC --> E
```

## Config files

| File | Read by | Holds |
|---|---|---|
| `scripts/project_config.sh` | builds, checks | identity, `SOURCE_FILES`, plate file, bundled libraries, color flattening, README markers, dev views, generated parameter tables, smoke variants |
| `scripts/plates_config.sh` | builds (validation, injected values), 3MF export | printer, `MW_PLATE_SIZE`, plates → parts, per-part Bambu overrides, assembly preview views |
| `scripts/render_config.sh` | render | targets, perspectives, ratios, quality, parameter overrides |
| `scripts/export_3mf_config.sh` | 3MF export | parameter overrides, quality, reference profile, global overrides, output |

All four are constrained bash ([platform-contract.md](platform-contract.md#invariants)), relative
to the project folder.

---

## MakerWorld bundle

`scripts\build.bat` · `scripts/build/build.ps1 [-Project dir] [-OutFile path]` → `dist/<slug>_makerworld.scad`

1. Regenerate `.build/plates.json` from `plates_config.sh`.
2. **Validate**: every `mw_plate_N()` in `PLATE_ASSEMBLY_FILE` must call the same part modules, the
   same number of times, as the matching `PLATE_N_PARTS`. Drift fails the build.
3. Resolve `mw_plate_size` (`MW_PLATE_SIZE`, else derived from `PRINTER`'s bed minus margin,
   always capped at `MW_PLATE_SIZE_CEILING`, 235 by default). **Validate** every view in
   `ASSEMBLY_PLATE_VIEWS`: its `assembly_<name>()`, `assembly_<name>_footprint()` and both
   dispatcher branches must exist, or the build fails.
4. Concatenate `SOURCE_FILES`, transforming each line:
   - drop local `include`/`use`; keep ones matching `BUNDLED_LIBRARIES`
   - drop `// BUILD:EXCLUDE-START … -END` blocks
   - drop comments, **except** in `params.scad` user-facing tabs (PMM help text) and same-line
     widget annotations (`// [..]`, `// color`, `// font`); the `// @label:` / `// @note:` lines
     are dropped too (they only feed the parameter tables)
   - rewrite `color(<var>)` to `MAKERWORLD_COLOR` unless `<var>` is in `COLOR_PASSTHROUGH`
5. Inject `mw_plate_size = N;` and `mw_assembly_views = [...];`: rewrite `params.scad`'s own
   placeholder line for each, in place, or append the line right after `params.scad` when there
   is none ([source-architecture](../conventions/source-architecture.md#injected-values-mw_plate_size-mw_assembly_views)).
6. Prepend the README `BUNDLE-DESCRIPTION` span as a header comment.
7. Append `MAKERWORLD_TOP_LEVEL_CALL` if set (single-part models).
8. Write UTF-8 without BOM.
9. Regenerate the **parameter tables** of every `PARAM_TABLES` file from `params.scad`
   (`scripts/shared/param_tables.py`), between `<!-- PARAMETERS:START -->` and
   `<!-- PARAMETERS:END -->`. Style `readme`: one table per tab (variable, help text, default,
   range). Style `listing`: one customer table (label, help text, compatibility), where the label
   and compatibility come from optional `// @label:` / `// @note:` lines above the help line.

`-OutFile` writes the bundle elsewhere and skips step 9, touching nothing tracked; the freshness
check uses it.

**Why `MW_PLATE_SIZE` is explicit by default:** a value derived from locally installed Bambu
presets would make the tracked bundle differ between machines, and between your machine and CI.

## Dev bundle

`scripts\dev_build.bat` · `scripts/build/dev_build.ps1` → `dist/<slug>_dev.scad` (gitignored)

Same flattening, but it keeps comments and colors, drops `params.scad`'s `$fa`/`$fs`, and adds a
`dev_view` dropdown (from `DEV_VIEWS`, plus "MakerWorld assembly plate" whenever assembly views
are configured), a `dev_view_offset` XY shift, and coarse-preview quality sliders. Open it in
OpenSCAD to see the whole project as one file. The 3MF export also renders its assembly preview
plate from it.

## Checks

`scripts\check.bat` · `scripts/check/check.sh [-p dir]` runs:

- **`fresh.sh`**: the tracked bundle and the generated parameter tables match the sources. It
  builds the bundle into a temp file (`build.ps1 -OutFile`) and compares, then runs
  `param_tables.py --check`, so it works regardless of git state. This catches the classic
  mistake of changing `params.scad` after the last build. The **pre-commit hook**
  (`.githooks/pre-commit`, enabled by `git config core.hooksPath .githooks`) runs it before every
  commit.
- **`pmm_lint.py`**: static rules P01–P12 on the shipped bundle
  ([compatibility-rules.md](../pmm/compatibility-rules.md)). Offline, using `docs/pmm/data/`.
- **`smoke.sh`**: (1) every `parts/`/`assembly/` file in `SOURCE_FILES` exports to STL standalone;
  (2) every `mw_plate_N()` is built **from the shipped bundle** and its footprint is checked
  against `mw_plate_size`, and `mw_assembly_view()` must compile and be non-empty when views are
  configured (no size limit: it's a preview). Unresolved includes or modules count as failures.
  (3) the same for every **`SMOKE_VARIANTS`** entry (`project_config.sh`), a named set of
  parameter overrides (`"name|a=1; b=\"x\""`, one `-D` per assignment): extreme sizes, every
  dropdown option, optional features on and off. There an empty plate or preview is reported,
  not failed, since a variant may switch a part off.

Run after every build, before releases, and in CI. `.github/workflows/check.yml` builds the dev
bundle and runs these checks (without running the MakerWorld build first, which would hide a
stale commit) for the root project and `examples/demo` on every push,
pull request and published release, using **OpenSCAD Nightly** (`openscad-nightly` from the
official OBS apt repo), the same kind of build PMM uses.

## Render (manual only)

`scripts\render.bat` · `scripts/render/render.sh [-p dir] [-c config]` → `renders/{parts,assembly}/`

One PNG per target × perspective × aspect ratio. The camera is fitted to the sphere
circumscribing each model's bounding box (via a throwaway STL and `scripts/shared/stl_bbox.py`),
so no perspective crops. OpenSCAD's own `--viewall` crops elongated models in mismatched aspect
ratios. **Agents never render unless asked** (AGENTS.md).

## 3MF export (optional, Bambu Studio)

`scripts\export_3mf.bat` · `scripts/export/export_3mf.sh [-p dir] [-c config] [-D 'param=value' ...] [-o file]` → `OUTPUT`

For a one-off test, `-D` adds a parameter override on top of `PARAM_OVERRIDES` (repeatable) and
`-o` writes somewhere other than `OUTPUT`, so `export_3mf_config.sh` stays untouched:
`bash scripts/export/export_3mf.sh -D 'handle="none"' -o .build/test.3mf`. (The `.bat` wrapper
only takes a project folder; quoted `-D` values are easiest from Git Bash.)

1. Resolve `PRINTER`'s real bed (`printer_bed.py` walks Bambu's preset inheritance).
2. Per plate: export each part to STL — or, for a part marked `|multicolor=1`, to a Bambu object
   with one part per color region, each on its own filament
   ([multicolor](../workflows/multicolor.md)). Optionally auto-orient one part
   (`|auto_orient=1`) or the whole plate. Arrange with Bambu Studio's CLI `--arrange=1` inside the
   real bed, passing `--enable-support` because it changes arrange spacing.
   **Optional parts:** a part that renders nothing with this run's parameters (OpenSCAD reports
   "top level object is empty") is skipped, and a plate left with no parts is dropped: later
   plates move up and the project has no empty plate. For this, an optional part's main module
   must draw nothing when it is switched off, so its standalone `BUILD:EXCLUDE` preview is empty.
   Per-part `--object-set` overrides follow the output plate numbering.
3. If `ASSEMBLY_PLATE_VIEWS` is set, add the **assembly preview** as the last plate
   (`ASSEMBLY_PLATE_NAME`, default `_preview assembly DO NOT PRINT`), so plates 1..N still match
   `mw_plate_1()`..`mw_plate_N()`. It's rendered as one object from the freshly rebuilt dev bundle
   (`-D dev_view="mw_assembly_view"`, `-D dev_view_offset=[bed center]`), keeps MakerWorld's
   exact layout, and is **never** passed through Bambu's arrange. It may be larger than the bed.
   If its views mark two or more color regions with `assembly_region()`, it's rendered one solid
   per region (`dev_assembly_regions`, `--enable=lazy-union`) and goes through
   `multicolor_3mf.py` and `FILAMENT_MAP` like a multicolor part. Otherwise it's one STL
   ([multicolor](../workflows/multicolor.md#the-assembly-preview-plate)).
4. `assemble_3mf.py` merges the single-plate exports into one multi-plate project. It renumbers
   ids, shifts each plate by a rigid world-space offset (without it, Bambu piles everything onto
   plate 1), grafts `REFERENCE_3MF`'s print settings, and applies global (`--set`) and per-part
   (`--object-set`) overrides. Unknown setting keys abort the export.

**Reverse-engineered:** Bambu's multi-plate project format isn't documented. Open the first
export of any new project in Bambu Studio and check every plate before printing. List valid
override keys with `python scripts/export/list_settings.py [--grep KEY]`.

## Maintenance helpers

| Command | Does |
|---|---|
| `python scripts/shared/pmm_inventory.py` | refresh `docs/pmm/data/` from PMM's endpoints |
| `python scripts/shared/printer_bed.py "?"` | list every Bambu printer preset name |
| `python scripts/export/list_settings.py` | list every overridable Bambu setting |
| `python scripts/init_project.py ...` | fill template tokens for a new project ([new-project.md](../workflows/new-project.md)) |
