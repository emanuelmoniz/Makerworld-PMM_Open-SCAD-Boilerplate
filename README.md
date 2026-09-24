<!-- TEMPLATE-BANNER:START  (delete from here to TEMPLATE-BANNER:END once your project is set up;
     `python scripts/init_project.py` does it for you) -->
> [!NOTE]
> **This is the MakerWorld PMM OpenSCAD boilerplate.** It's a GitHub template for parametric
> OpenSCAD models published through MakerWorld's **Parametric Model Maker (PMM)**: folder
> structure, build and render scripts, a Bambu 3MF exporter, a PMM compatibility lint, agent
> directives, and a reference library of PMM specifications.
>
> - **Starting a project?** Click **Use this template**, then follow [docs/START-HERE.md](docs/START-HERE.md).
> - **Want to see it working first?** A runnable example lives in [examples/demo/](examples/demo/).
> - **Using an AI assistant?** Point it at [AGENTS.md](AGENTS.md). The doc map is [docs/INDEX.md](docs/INDEX.md).
>
> Everything below this banner is the README **template** for your project. `<ANGLE BRACKET>`
> tokens are placeholders.
<!-- TEMPLATE-BANNER:END -->

<!--
  README TEMPLATE -- how this file is used (docs/conventions/documentation.md):
  - The span between BUNDLE-DESCRIPTION markers is LIVE CONTENT: the build copies it into the
    header comment of dist/<slug>_makerworld.scad. Keep it short, self-contained and accurate.
    Do not rename or remove the two marker lines (they are configured in scripts/project_config.sh).
  - Everything else is developer-facing documentation for the repo.
  - The customer-facing MakerWorld listing text lives separately in dist/makerworld_listing.md.
  - Standing directive: update this file whenever a change affects what someone prints or
    customizes (AGENTS.md).
-->

<!-- BUNDLE-DESCRIPTION:START -->
# <PROJECT NAME>

<!-- One paragraph: what the object is, what it's for, what the customer can customize. Written for someone who has only the .scad file in front of them. (Single-line HTML comments here are not copied into the bundle.) -->
<PROJECT DESCRIPTION>
<!-- BUNDLE-DESCRIPTION:END -->

## Features

- **Fully parametric**: <what dimensions / options the customizer exposes>.
- **<Feature>**: <one line each; mirror the MakerWorld listing's feature list>.
- **Tunable fit**: clearance parameters widen the mating cavities, so you can dial in the fit
  for your printer without scaling the model.

## Parts to print

| Part | File | Qty | Notes |
|---|---|---|---|
| <Part name> | `parts/<part_name>.scad` | 1 | <supports? orientation?> |

## Assembly

1. <Step one.>
2. <Step two.>

## Print settings

- <Material, nozzle, layer height, infill, and supports, per part if they differ.>
- If a fit is too tight or too loose, adjust the matching clearance parameter. Don't scale
  the model.

## Parameters

<!-- Generated from lib/params.scad by the MakerWorld build (PARAM_TABLES in
     scripts/project_config.sh). Don't edit between the markers: change params.scad and rebuild. -->
<!-- PARAMETERS:START -->

### DIMENSIONS

| Parameter | Description | Default | Range |
|---|---|---|---|
| `size_x` | REPLACE ME -- Overall length (X), in mm | 40 | 10–200, step 1 |
| `size_y` | REPLACE ME -- Overall depth (Y), in mm | 30 | 10–200, step 1 |
| `size_z` | REPLACE ME -- Overall height (Z), in mm | 10 | 2–100, step 0.5 |

### OPTIONS

| Parameter | Description | Default | Range |
|---|---|---|---|
| `rounded` | REPLACE ME -- Example checkbox: round the vertical edges | on | on/off |

### CLEARANCES - TUNE FOR YOUR PRINTER

| Parameter | Description | Default | Range |
|---|---|---|---|
| `fit_clearance` | Gap added to every mating cavity (mm). Nominal parts are never shrunk. | 0.15 | 0–0.6, step 0.05 |

<!-- PARAMETERS:END -->

## Development

This project follows the [MakerWorld PMM OpenSCAD boilerplate](docs/START-HERE.md).
The source is split across `lib/`, `parts/` and `assembly/`. PMM accepts a single `.scad`
file, so the build flattens everything into one bundle.

| Task | Command (Windows) | Docs |
|---|---|---|
| Build the MakerWorld bundle | `scripts\build.bat` | [pipelines](docs/toolchain/pipelines.md) |
| Build the local dev bundle | `scripts\dev_build.bat` | [pipelines](docs/toolchain/pipelines.md) |
| Lint + smoke check | `scripts\check.bat` | [pipelines](docs/toolchain/pipelines.md) |
| Render preview images | `scripts\render.bat` | [pipelines](docs/toolchain/pipelines.md) |
| Export a Bambu `.3mf` | `scripts\export_3mf.bat` | [pipelines](docs/toolchain/pipelines.md), [multicolor](docs/workflows/multicolor.md) |

Prerequisites (OpenSCAD, Python 3, Git Bash, and optionally Bambu Studio, BOSL2 and fonts) are
listed in [docs/toolchain/setup.md](docs/toolchain/setup.md). To preview a single part, open
its file under `parts/` in OpenSCAD.

## License

<LICENSE NAME>. See [LICENSE](LICENSE).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
