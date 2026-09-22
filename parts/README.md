# parts/: one file per printed part

- `parts/<name>.scad` defines `module <name>()`, with exactly that name. The plate validator
  depends on it.
- Authored at the outer front-left-bottom corner, in print orientation
  ([geometry](../docs/conventions/geometry.md)).
- Ends with a `// BUILD:EXCLUDE-START` … `-END` block calling its own module. That's what makes the
  file previewable, renderable and smoke-testable on its own.
- `part_template.scad` is the file to copy. Delete it once you have real parts.

Adding one: [docs/workflows/add-a-part.md](../docs/workflows/add-a-part.md).
