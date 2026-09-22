# PMM specification: what MakerWorld's Parametric Model Maker supports

> **Scope.** The author-facing surface of MakerWorld's **Parametric Model Maker (PMM)**: what a
> `.scad` file can use and how PMM interprets it. Rules and limits are in
> [compatibility-rules.md](compatibility-rules.md). Sources and evidence for every claim are in
> [sources.md](sources.md).
>
> **Status of this information.** Bambu Lab doesn't publish official PMM documentation. Everything
> here comes from official release notes, Bambu employees' forum replies, PMM's own public
> inventory endpoints, and community testing, as compiled by the
> [unofficial PMM docs project](https://github.com/nelsonjchen/unofficial-makerworld-parametric-model-maker-openscad-docs)
> and verified where possible. Each item carries an **evidence level**:
>
> | Level | Meaning |
> |---|---|
> | **Official** | stated in a PMM release note |
> | **Employee** | confirmed by a Bambu Lab employee |
> | **Endpoint** | read from PMM's own public JSON inventory |
> | **Community** | observed by users, not confirmed by Bambu |
>
> *Last verified: 2026-09-22.*

---

## 1. Input: one `.scad` file

PMM takes **a single `.scad` file**. It resolves includes of its own **bundled libraries**, but
not arbitrary local include trees. *(Employee)*

**In this boilerplate:** the build flattens `lib/`, `parts/` and `assembly/` into
`dist/<slug>_makerworld.scad`, keeping only bundled-library includes
([pipelines.md](../toolchain/pipelines.md)).

## 2. Customizer parameters

PMM "mainly follows the **OpenSCAD Customizer** manual". *(Employee)* The full syntax reference is
[customizer-syntax.md](../openscad/customizer-syntax.md). In short:

```openscad
/* [Tab name] */                     // starts a tab
// Help text shown for the parameter  // comment line ABOVE the parameter
width = 40;        // [10:1:200]      // slider  [min:step:max]
style = "round";   // [round:Round, square:Square]   // dropdown
rounded = true;                       // checkbox
/* [Hidden] */                        // everything below is hidden from the UI
```

- **Not supported:** Thingiverse-style `// preview[view:..., tilt:...]` comments. PMM ignores them.
  *(Employee)* → lint **P05**

## 3. Colors: `// color`  *(Official, v0.9.0)*

A parameter becomes a **color picker** only if it's a **hex string** with a trailing `// color`:

```openscad
accent = "#FF6600"; // color
```

Named CSS colors (`"Red"`) don't trigger the picker. → lint **P03**. Colors used only for local
previews can stay named, as long as they aren't exposed (put them under `[Hidden]`).

## 4. Fonts: `// font`  *(Official, v0.10.0)*

A parameter becomes a **font picker** only with a trailing `// font`:

```openscad
label_font = "Roboto:style=Bold"; // font
```

- The `// font` marker is **required**. Without it the value is valid OpenSCAD but gets no picker.
- The font must be in PMM's **installed** inventory
  ([data/fonts-installed.json](data/fonts-installed.json)), not just its **display catalog**
  ([data/fonts-catalog.json](data/fonts-catalog.json)). A catalog-only font can appear in the picker
  and still be substituted at render time. *(Endpoint)* → lint **P04**
- Names use OpenSCAD's `"Family:style=Style"` form, e.g. `"Liberation Sans:style=Bold"`.

## 5. File uploads: `default.*`  *(Official, v0.8.0)*

Customers can upload a file. The script must reference it by one of the three default names:

```openscad
import("default.svg");   // or default.png (surface()), default.stl
```

Arbitrary names like `import("logo.svg")` aren't supported. → lint **P07**

## 6. Output structure: plates and assembly view  *(Official, v0.10.0)*

| Module | Purpose | Notes |
|---|---|---|
| `mw_plate_1()` … `mw_plate_N()` | One module per **print plate** of the generated 3MF | Numbered sequentially. PMM calls them. |
| `mw_assembly_view()` | Combined **preview** of the assembled model | Preview only, **excluded from the 3MF** |

- **Never call these modules yourself.** Keep reusable geometry in neutral helper modules. → lint **P06**
- **Trade-off:** a script that defines `mw_plate_N()` **doesn't offer STL download**. For a
  single-part model, skip plate modules and use a top-level call instead
  (`MAKERWORLD_TOP_LEVEL_CALL` in `scripts/project_config.sh`), or publish separate variants.
- **Size:** keep each plate within about **240 × 235 mm**. Oversize plates can make 3MF generation
  fail. *(Employee)* → smoke check + lint **P11**. See [compatibility-rules.md](compatibility-rules.md#p11-plate-size-ceiling--employee).
- Center each plate's content on X/Y with Z resting at 0 (boilerplate convention; parts are
  authored from a corner).
- **In this boilerplate** `mw_assembly_view()` is configurable: it stacks and centers the views
  listed in `ASSEMBLY_PLATE_VIEWS` (`scripts/plates_config.sh`), and the 3MF export reproduces the
  same layout as a non-printing preview plate
  ([source-architecture](../conventions/source-architecture.md#the-assembly-preview-pattern)).

**If there are no plate modules,** PMM renders the file's top-level geometry, as the desktop
OpenSCAD app does.

## 7. Bundled libraries  *(Endpoint)*

Available through `include`/`use` without uploading anything. The snapshot is
[data/libraries.json](data/libraries.json), refreshed with `python scripts/shared/pmm_inventory.py`.

| Library | Include method |
|---|---|
| [BOSL2](https://github.com/BelfrySCAD/BOSL2) | `include <BOSL2/*.scad>;` (usually `include <BOSL2/std.scad>`) |
| [UB](https://github.com/UBaer21/UB.scad) | `include <ub.scad>;` |
| [KeyV2](https://github.com/rsheldiii/keyv2) | `include <KeyV2/*.scad>;` |
| [gridfinity-rebuilt-openscad](https://github.com/kennetek/gridfinity-rebuilt-openscad) | `include <gridfinity-rebuilt-openscad/*.scad>;` |
| [threads-scad](https://github.com/rcolyer/threads-scad/) | `include <threads-scad/threads.scad>;` |
| [Getriebe](https://github.com/janssen86/OpenSCAD-Getriebebibliothek) | `include <Getriebe.scad>;` |
| [knurledFinishLib_v2](https://www.thingiverse.com/thing:32122) | `include <knurledFinishLib_v2.scad>;` |

BOSL2 is pinned to commit **`99fcfc6867e739aa1cd8ffc49fe39276036681f1`** (v1.1.0 backend refresh).
*(Official)* For local parity, check out that commit (see
[libraries-and-fonts.md](../openscad/libraries-and-fonts.md)).

## 8. Backend

- PMM renders with an OpenSCAD development build **with the Manifold backend enabled**.
  *(Employee, 2025-03-13)* Backend commits documented so far: `b550957…` (2025-03), then
  `c8fbef05ba900e46892e9a44ea05f7d88e576e13` (v1.1.0). *(Official)*
- **Consequence for local work:** the OpenSCAD **2021.01** stable release uses CGAL only. It is
  much slower and not a faithful stand-in. Use a recent **development snapshot (Nightly)**
  locally and enable Manifold (*Preferences → Features / Advanced → Backend: Manifold*). See
  [setup.md](../toolchain/setup.md).
- Heavy geometry can **time out** on PMM even when it renders locally. *(Community)*

## 9. Profiles

PMM exposes a selection of print-profile settings when generating the 3MF (v0.10.0). *(Official)*
Only some settings are configurable there. Put print guidance that matters (supports,
orientation, infill) in the listing text.

## 10. PMM release history

| Version | Added |
|---|---|
| v0.8.0 | File upload (`default.*`), bundled library inventory, font inventory endpoint |
| v0.9.0 | Parameterized colors (`// color`) and multi-color modeling |
| v0.10.0 | Font picker (`// font`), multi-plate 3MF (`mw_plate_N`), `mw_assembly_view`, profile configuration |
| v1.1.0 | Backend refresh (new OpenSCAD and BOSL2 commits); code editor moved behind a *Code* button |
