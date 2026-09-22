# Customizer syntax

> **Scope.** How to annotate parameters in `lib/params.scad` so they show up correctly in both the
> OpenSCAD desktop Customizer and MakerWorld PMM. PMM follows the
> [OpenSCAD Customizer manual](https://en.wikibooks.org/wiki/OpenSCAD_User_Manual/Customizer)
> plus two PMM-only markers (`// color`, `// font`).

## Anatomy of a parameter

```openscad
/* [Dimensions] */          // 1. tab: applies to every parameter below it

// Inside length, in mm     // 2. label/help: the comment line directly ABOVE
inner_length = 80; // [30:1:200]   // 3. value   4. widget annotation, SAME line
```

- The **value** must be a literal (number, string, boolean, or vector of literals). An expression
  like `a = b * 2;` isn't shown in the UI, so keep those under `[Hidden]`.
- The **annotation** must be on the **same line** as the value. The build preserves it exactly
  (`Remove-TrailingComment` in `scripts/build/Bundle.psm1`). Lose it and the widget disappears.
- The Customizer only lists parameters declared **before the first module/function**. That's why
  `params.scad` is always first in `SOURCE_FILES`.

## Widgets

| Widget | Syntax | Notes |
|---|---|---|
| Slider | `x = 10; // [0:0.5:50]` | `[min:step:max]`. `[min:max]` uses step 1. |
| Spinbox | `x = 10;` | plain number, no annotation |
| Dropdown (numbers) | `n = 2; // [1, 2, 4, 8]` | |
| Dropdown (labelled) | `s = "a"; // [a:Label A, b:Label B]` | `value:Label` pairs. Keep values short and stable. |
| Checkbox | `on = true;` | booleans |
| Text box | `t = "hello";` | plain string |
| Text box, max length | `t = "hi"; // 8` | |
| Vector | `v = [1, 2, 3]; // [0:1:10]` | up to 4 elements, one range for all |
| **Color picker** (PMM) | `c = "#FF6600"; // color` | **hex only** |
| **Font picker** (PMM) | `f = "Roboto"; // font` | must be in the **installed** inventory |

## Tabs

```openscad
/* [Dimensions] */
/* [Clearances - tune for your printer] */
/* [Hidden] */      // reserved name: nothing below appears in the UI
```

Boilerplate conventions:

- User-facing tabs first, then **exactly one** `[Hidden]` section holding constants and derived
  values.
- Name tabs for the customer ("LID LABEL", not "TEXT_PARAMS").
- A **CLEARANCES** tab, marked "tune for your printer", holds every fit clearance.
- **Build coupling:** in the MakerWorld bundle, comments inside user-facing tabs are **kept**
  (they're the UI help text) and comments under `[Hidden]` are **stripped**. Write the first
  kind for customers and the second for maintainers.

## Changing a parameter is an API change

Customers save presets and remix. Renaming or removing a parameter, or changing a dropdown's
*value* (not its label), breaks their saved configurations. That's a **major** version bump
([versioning-and-changelog.md](../conventions/versioning-and-changelog.md)). Adding one is minor.

## Not supported in PMM

- `// preview[...]` (Thingiverse). Ignored. → lint P05
- Named colors on a `// color` parameter. → lint P03
