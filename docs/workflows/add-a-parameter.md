# Workflow: add or change a parameter

> **Goal.** A parameter that appears correctly in PMM's customizer, is documented everywhere a
> customer looks, and doesn't break existing customers' saved settings.

## Decide: user-facing or hidden?

- **User-facing** (a customer should change it): goes in a customizer tab, needs a widget
  annotation and help text, and becomes part of the model's public API.
- **Hidden** (a design constant): goes under `/* [Hidden] */`. Derived values go in the derived
  section at the bottom.

## Add a user-facing parameter

1. In `lib/params.scad`, under the right tab:

   ```openscad
   // @label: New parameter             optional: label in the listing's table
   // @note: Only when Feature is on    optional: the listing's Compatibility column
   // Short help text a customer understands, with units
   new_param = 10; // [1:0.5:50]
   ```

   The help text is the **one** comment line directly above the parameter (that is all the
   customizer reads). The `@` lines go above it; the MakerWorld build strips them.

   Syntax reference: [customizer-syntax.md](../openscad/customizer-syntax.md). Color: hex +
   `// color`. Font: `// font`, checked against the installed inventory.
2. If other values depend on it, add them to the derived section. Never recompute them in a part.
3. Use it in parts through the variable, or as a module argument default.
4. If it only matters when another option is on, say so in a `// @note:` line (it becomes the
   listing's *Compatibility* column).
5. Add it to `PARAM_OVERRIDES` (commented out) in `render_config.sh` and `export_3mf_config.sh`,
   in the same tab order.
6. If it has a range or options worth exercising (a size extreme, a dropdown value, a feature
   toggle), add a `SMOKE_VARIANTS` entry in `scripts/project_config.sh`.
7. Build and check (standing directive). The build regenerates the README and listing parameter
   tables (`PARAM_TABLES`); don't edit them by hand.
8. Add a `CHANGELOG.md` entry under **Added** (minor), and describe the feature in the README and
   listing prose if it's more than a size.

## Change or remove one: this is an API change

| Change | Version bump |
|---|---|
| Rename, remove, change meaning, change a dropdown *value* | **major** (saved presets break) |
| Change a default, a range, or a label | minor or patch |

When renaming, update every reference: `grep -rn "old_name" lib parts assembly scripts docs`.
