# Documentation index

> **For AI agents:** read [../AGENTS.md](../AGENTS.md) first. Then use this table to load only the
> docs your task needs. The "Read when" column is the trigger.

## Entry points

| Doc | Answers | Read when |
|---|---|---|
| [../AGENTS.md](../AGENTS.md) | Rules, commands, standing directives, layout | always, first |
| [START-HERE.md](START-HERE.md) | What this boilerplate is, how the pieces connect | first visit |
| [../llms.txt](../llms.txt) | Compact machine-readable map | loading context into an LLM |

## PMM (MakerWorld Parametric Model Maker)

| Doc | Answers | Read when |
|---|---|---|
| [pmm/specification.md](pmm/specification.md) | What PMM supports: plates, assembly view, colors, fonts, uploads, libraries, backend | any customizer-facing or output-structure change |
| [pmm/compatibility-rules.md](pmm/compatibility-rules.md) | Rules P01–P12, the size ceiling, timeouts, fixes | a lint finding; before publishing |
| [pmm/sources.md](pmm/sources.md) | Where each claim comes from; endpoint URLs; verification log | a claim seems wrong or outdated |
| [pmm/data/](pmm/data/) | Installed fonts, font catalog, bundled libraries (JSON) | choosing a font or library |

## OpenSCAD

| Doc | Answers | Read when |
|---|---|---|
| [openscad/customizer-syntax.md](openscad/customizer-syntax.md) | Tabs, sliders, dropdowns, color and font pickers | adding or changing a parameter |
| [openscad/libraries-and-fonts.md](openscad/libraries-and-fonts.md) | BOSL2 install and pinning, name collisions, local fonts | using a library or text |

## Conventions

| Doc | Answers | Read when |
|---|---|---|
| [conventions/geometry.md](conventions/geometry.md) | Origin, print orientation, clearances, manifold safety, performance | any geometry change |
| [conventions/source-architecture.md](conventions/source-architecture.md) | Layers, `include` vs `use`, `BUILD:EXCLUDE`, `SOURCE_FILES` | adding a file or module |
| [conventions/naming.md](conventions/naming.md) | Load-bearing names, collision-safe names, output names | naming anything |
| [conventions/code-style.md](conventions/code-style.md) | Formatting, commenting (two audiences in params.scad) | writing code or config |
| [conventions/documentation.md](conventions/documentation.md) | Which doc holds what; README ↔ bundle coupling | editing docs |
| [conventions/versioning-and-changelog.md](conventions/versioning-and-changelog.md) | SemVer for parametric models, the two changelogs | recording a change, releasing |
| [conventions/repo-hygiene.md](conventions/repo-hygiene.md) | What's tracked, generated or ignored, and why | adding or ignoring files |

## Toolchain

| Doc | Answers | Read when |
|---|---|---|
| [toolchain/setup.md](toolchain/setup.md) | What to install, env vars, verifying the setup | new machine; a tool isn't found |
| [toolchain/pipelines.md](toolchain/pipelines.md) | Build, dev, check, render, 3MF: inputs, outputs, steps | running or changing a pipeline |
| [toolchain/platform-contract.md](toolchain/platform-contract.md) | Which shell runs what; cross-shell invariants | changing a script |

## Workflows

| Doc | Goal |
|---|---|
| [workflows/new-project.md](workflows/new-project.md) | Template → your project, green build |
| [workflows/add-a-part.md](workflows/add-a-part.md) | New printed part, placed and validated |
| [workflows/add-a-parameter.md](workflows/add-a-parameter.md) | New or changed customizer parameter |
| [workflows/multicolor.md](workflows/multicolor.md) | A part that prints in several filaments, in the Bambu 3MF export |
| [workflows/release.md](workflows/release.md) | Tagged version with consistent docs and assets |
| [workflows/publish-to-makerworld.md](workflows/publish-to-makerworld.md) | Upload, verify on PMM, update the listing |

## Where each file is explained

| File | Explained in |
|---|---|
| `lib/params.scad` | its header, [customizer-syntax](openscad/customizer-syntax.md), [add-a-parameter](workflows/add-a-parameter.md) |
| `parts/part_template.scad` | its header, [add-a-part](workflows/add-a-part.md) |
| `assembly/assembly_main.scad` | its header, [specification §6](pmm/specification.md#6-output-structure-plates-and-assembly-view--official-v0100) |
| `scripts/project_config.sh` | its header, [pipelines](toolchain/pipelines.md#config-files) |
| `scripts/plates_config.sh` | its header, [pipelines](toolchain/pipelines.md#makerworld-bundle) |
| `scripts/check/pmm_lint.py` | its header, [compatibility-rules](pmm/compatibility-rules.md) |
| `scripts/check/fresh.sh`, `scripts/shared/param_tables.py` | their headers, [pipelines](toolchain/pipelines.md#checks) |
| `dist/makerworld_listing.md` | its header comment, [documentation](conventions/documentation.md) |
