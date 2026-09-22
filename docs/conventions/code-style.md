# Code style and commenting

> **Scope.** Formatting and commenting for `.scad`, scripts and configs. Line-ending and
> whitespace rules that actually break things are enforced by `.editorconfig` and
> `.gitattributes`.

## Formatting

- 4-space indent, no tabs, lines ≤ 100 characters in `.scad`.
- One statement per line. A transform chain gets one transform per line, indented:

  ```openscad
  translate([x, y, 0])
      rotate([180, 0, 0])
          cap();
  ```

- Line endings: LF for `.scad` / `.sh` / `.py` / `.md`, CRLF for `.bat` / `.ps1`
  (see `.gitattributes` for why. Mixing them breaks bash or cmd).

## Commenting: the "why", generously

This convention comes from the source project and is deliberate: **source is commented for the
next maintainer, human or AI**. The MakerWorld bundle strips maintainer comments, so they cost
customers nothing.

Comment:

- **Every file**: a header block saying what it is, what it depends on, and where to read more.
- **Every module/function**: its argument contract (units, origin, defaults) and anything
  non-obvious about its shape.
- **Every non-obvious number**: why this overlap, why this ratio, what was measured.
- **Every workaround**: what fails without it, and how you know ("confirmed by rendering …",
  not "I think").
- **Cross-file couplings**: when changing X requires changing Y, say so at **both** ends.

Don't comment what the code already says (`// translate by x`).

## Two audiences in `params.scad`

| Location | Audience | Survives the bundle? |
|---|---|---|
| Comment above a parameter in a **user-facing tab** | MakerWorld customer (UI help text) | **Yes, verbatim** |
| Same-line widget annotation (`// [..]`, `// color`, `// font`) | PMM's UI builder | **Yes** |
| Anything under `[Hidden]`, and every other file | Maintainers | No |

So user-facing help text is short, plain and free of internals ("Wall thickness, in mm"), and
`[Hidden]` comments can be as long as needed.

## Scripts and configs

- Every script and config starts with the same header block style (`# ====` / `# ----`),
  naming its purpose, inputs, outputs, usage and the doc that explains it.
- Configs are **documentation first**: each option carries a comment saying what it does,
  its allowed values, and its default.
- Scripts never hardcode tool paths: use `scripts/shared/find_tools.sh` (bash) or the discovery
  in `Bundle.psm1` (PowerShell).
- PowerShell must run on Windows PowerShell 5.1 **and** pwsh 7 (CI). No `??`, `?:`, `&&`, or
  `-AsHashtable`.
