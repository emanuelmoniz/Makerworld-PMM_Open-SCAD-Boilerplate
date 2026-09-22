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
   // Short help text a customer understands, with units
   new_param = 10; // [1:0.5:50]
   ```

   Syntax reference: [customizer-syntax.md](../openscad/customizer-syntax.md). Color: hex +
   `// color`. Font: `// font`, checked against the installed inventory.
2. If other values depend on it, add them to the derived section. Never recompute them in a part.
3. Use it in parts through the variable, or as a module argument default.
4. If it only matters when another option is on, say so in the listing's *Compatibility* column.
5. Add it to `PARAM_OVERRIDES` (commented out) in `render_config.sh` and `export_3mf_config.sh`,
   in the same tab order.
6. Build and check (standing directive).
7. Document it: the README parameter table (same tab order as `params.scad`), the listing's
   *Complete Options* table, and a `CHANGELOG.md` entry under **Added** (minor).

## Change or remove one: this is an API change

| Change | Version bump |
|---|---|
| Rename, remove, change meaning, change a dropdown *value* | **major** (saved presets break) |
| Change a default, a range, or a label | minor or patch |

When renaming, update every reference: `grep -rn "old_name" lib parts assembly scripts docs`.
