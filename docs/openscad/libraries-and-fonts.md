# Libraries and fonts

> **Scope.** Using external OpenSCAD libraries and fonts so the model works **both** locally and on
> PMM. PMM's lists are in [../pmm/data/](../pmm/data/). Rules P02, P04 and P09 are in
> [../pmm/compatibility-rules.md](../pmm/compatibility-rules.md).

## Libraries

### Which libraries you may use

Only PMM's **bundled** libraries ([specification.md §7](../pmm/specification.md#7-bundled-libraries--endpoint)):
BOSL2, UB, KeyV2, gridfinity-rebuilt-openscad, threads-scad, Getriebe, knurledFinishLib_v2.
Their include prefixes are listed in `BUNDLED_LIBRARIES` (`scripts/project_config.sh`). Includes
matching a prefix survive the build, and every other include is stripped. Remove the entries you
don't use, so an accidental include gets caught.

Need something else? Copy the minimal helper into `lib/` (respect its license and credit it in a
comment), rename its symbols distinctively, and add the file to `SOURCE_FILES`.

### Installing a library locally (BOSL2 example)

OpenSCAD looks for libraries in its **user library folder**:

| OS | Folder |
|---|---|
| Windows | `Documents\OpenSCAD\libraries` (may be `OneDrive\Documents\...`) |
| macOS | `~/Documents/OpenSCAD/libraries` |
| Linux | `~/.local/share/OpenSCAD/libraries` |

`openscad --info` prints the exact "User Library Path". Or set `OPENSCADPATH`.

For **parity with PMM**, pin BOSL2 to the commit PMM uses:

```sh
cd "<user library folder>"
git clone https://github.com/BelfrySCAD/BOSL2.git
cd BOSL2 && git checkout 99fcfc6867e739aa1cd8ffc49fe39276036681f1
```

### The name-collision rule (read this if you use BOSL2)

OpenSCAD resolves a module/function name to the **last definition** in the file, silently. The
MakerWorld bundle is one file. So if you define `cuboid()`, `dovetail()`, `rounded_prism()` or any
other name BOSL2 also defines, one definition silently replaces the other **for every user**.
The failure shows up as wrong geometry, not an error.

- Use distinctive names: `dovetail_wedge()`, `stadium_prism()`, `lid_rounded_block()`.
- Don't rely on include order to "win": it's fragile under reordering and under BOSL2 updates
  that add new names.
- `pmm_lint.py` rule **P09** scans your local BOSL2 checkout and flags collisions. Rule **P08**
  flags names you defined twice yourself.
- To check one name by hand:
  `grep -rE "^\s*(module|function)\s+NAME\b" "<library folder>/BOSL2"`

## Fonts

### Pick a font that exists in both places

A font must be **installed in PMM** ([data/fonts-installed.json](../pmm/data/fonts-installed.json))
**and** installed **locally**. If it's missing locally, desktop OpenSCAD **silently substitutes
another font**. Previews look plausible, but any code that depends on glyph metrics (auto-fit
text, per-letter spacing on curves) computes the wrong result.

**Safest defaults:** `Liberation Sans`, `Liberation Serif`, `Liberation Mono`. They ship with
OpenSCAD and are installed on PMM. For monospace on PMM: `Roboto Mono`, `Noto Sans Mono`,
`Ubuntu Mono`, `Ubuntu Sans Mono`.

**Trap:** PMM's *display catalog* ([data/fonts-catalog.json](../pmm/data/fonts-catalog.json)) lists
fonts that are **not** installed. `B612 Mono` is one (snapshot 2026-09-22). Lint rule **P04**
catches this.

### Installing a font locally (Windows)

The usual right-click **Install** (per-user font store) is **often not seen** by OpenSCAD's
bundled font engine. Reliable options:

1. Copy the `.ttf` into `%USERPROFILE%\.fonts` (create the folder). No admin rights needed.
2. Or install for all users into `C:\Windows\Fonts` (admin).

Verify with `openscad --info` (look at the font path list), or in OpenSCAD via
*Help → Font List*.

### Font names

OpenSCAD form: `"Family:style=Style"`, e.g. `"Roboto:style=Bold"`. Match PMM's inventory
strings exactly, including the style name.

### Text metrics

OpenSCAD's `textmetrics()` is an experimental feature and **isn't available on PMM**. Estimate
text width from a measured, font-specific width ratio kept in `params.scad` `[Hidden]`, and
measure it against the real font rather than guessing.
