# Sliding-Lid Box

A parametric storage box with a lid that slides into grooves along its side walls. Size it to
whatever you want to store, and add a name to the lid.

## Features

- **Fully parametric**: set the inside length, width and height, plus wall and floor thickness.
- **Sliding lid**: glides in from one end, sits flush, and has a finger scoop to pull it open.
- **Lid label**: engraved (cut in) or embossed (raised, in its own color for multi-color
  printing), in the font of your choice.
- **No supports**: both parts print flat, straight off the plate.
- **Tunable fit**: one clearance setting controls how snugly the lid slides.

## Printing tips

- PLA or PETG, 0.4 mm nozzle, 0.2 mm layers, no supports.
- Print the box open side up and the lid label side up.
- If the lid is too tight or too loose, regenerate with **Lid fit** nudged by 0.05 mm.

## Using it

1. Slide the lid into the grooves from the open end of the box, label side up.
2. Pull it out with the finger scoop.

## Complete options available

<!-- PARAMETERS:START -->

| Parameter | Description | Compatibility |
|---|---|---|
| **BOX** | | |
| Inside length | Inside length (X), in mm |  |
| Inside width | Inside width (Y), in mm |  |
| Inside height | Inside height (Z), in mm |  |
| Wall thickness | Wall thickness, in mm | Thicker walls also make deeper lid grooves |
| Floor thickness | Floor thickness, in mm |  |
| **LID LABEL** | | |
| Label style | Label style (None to disable) |  |
| Label text | Label text | Only when Label style is not None |
| Label size | Label size, in mm | Only when Label style is not None |
| Label font | Label font | Only when Label style is not None |
| Embossed label color | Embossed label color (multi-color printing) | Only when Label style is Embossed |
| **CLEARANCES - TUNE FOR YOUR PRINTER** | | |
| Lid fit | Lid fit: gap added to the groove the lid slides in (mm) |  |

<!-- PARAMETERS:END -->

## Changelog

### 1.0.0
- First release.
