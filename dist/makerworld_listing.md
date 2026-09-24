<!--
  MAKERWORLD LISTING -- the ONLY hand-maintained file in dist/.
  Paste this into the MakerWorld model description. Audience: CUSTOMERS, not developers:
  no file names, scripts or internals. Keep in sync with README.md (standing directive, AGENTS.md).
  The Changelog section below is the customer-facing subset of CHANGELOG.md: only changes that
  affect what someone prints or customizes, plus which parts to reprint after a fix.
  Structure reference: docs/conventions/documentation.md. Delete this comment before pasting.
-->

# <PROJECT NAME>

<Two or three sentences: what it is, what problem it solves, the headline mechanism or feature.>

## Features

- **Fully parametric**: <what the customer can size or choose>.
- **<Feature>**: <benefit in plain language>.
- **Tunable fit**: separate clearance settings let you dial in the fit for your printer and
  material, with no scaling needed.

## Printing tips

- <Material, nozzle, layer height.>
- <Which plates need supports, and which settings.>
- If a part fits too tight or too loose, regenerate with the matching clearance nudged slightly
  instead of scaling the model.

## Using it

1. <Assembly step.>
2. <Assembly step.>

## Complete options available

Every parameter in the customizer, grouped by tab.

<!-- PARAMETERS:START -->

| Parameter | Description | Compatibility |
|---|---|---|
| **DIMENSIONS** | | |
| Size x | REPLACE ME -- Overall length (X), in mm |  |
| Size y | REPLACE ME -- Overall depth (Y), in mm |  |
| Size z | REPLACE ME -- Overall height (Z), in mm |  |
| **OPTIONS** | | |
| Rounded | REPLACE ME -- Example checkbox: round the vertical edges |  |
| **CLEARANCES - TUNE FOR YOUR PRINTER** | | |
| Fit clearance | Gap added to every mating cavity (mm). Nominal parts are never shrunk. |  |

<!-- PARAMETERS:END -->

## Ready to print

<Optional: curated print profiles (printables/) and what each one is, for customers who don't
want to customize.>

## Changelog

### 1.0.0
- First release.
