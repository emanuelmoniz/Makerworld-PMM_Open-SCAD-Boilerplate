# Documentation conventions

> **Scope.** Which document holds what, who reads it, and which parts are coupled to the build.
> Every project doc has one job. Don't duplicate content across them: link instead.

| File | Audience | Job | Coupled to |
|---|---|---|---|
| `README.md` | developers, GitHub visitors | what the model is, parts, assembly, parameters, how to build | **build**: the `BUNDLE-DESCRIPTION` span is copied into the bundle header; the parameter table is generated from `params.scad` |
| `dist/makerworld_listing.md` | MakerWorld customers | the listing description, pasted into MakerWorld | **build**: the *Complete options* table is generated from `params.scad`; the rest is hand-maintained |
| `CHANGELOG.md` | maintainers | complete change history | release process |
| `AGENTS.md` | AI agents and humans | rules, commands, standing directives | — |
| `CLAUDE.md` | Claude Code | imports `AGENTS.md` | — |
| `docs/` | everyone | reference: PMM specs, conventions, toolchain, workflows | — |
| folder `README.md`s | whoever opens the folder | what belongs in this folder | — |

## The README ↔ bundle coupling

```markdown
<!-- BUNDLE-DESCRIPTION:START -->
# Model name

One paragraph a customer can understand with only the .scad in front of them.
<!-- BUNDLE-DESCRIPTION:END -->
```

- The build copies the lines between the markers into the header of
  `dist/<slug>_makerworld.scad`, as `// ` comments (heading `#`s removed).
- The markers are HTML comments: invisible on GitHub, and independent of heading text. (The
  original project keyed this on literal headings, so renaming a heading silently emptied the
  description.)
- Marker strings are configurable in `scripts/project_config.sh` (section 6).

## The MakerWorld listing (`dist/makerworld_listing.md`)

Structure (the template is in the file itself): title and pitch, Features, Printing tips,
Using it (assembly), Complete options (every customizer parameter by tab, with a
"compatibility" column saying when an option has no effect), Ready-to-print (curated profiles),
Changelog (customer-facing only).

## Standing directive

Any change that affects the printed object updates `README.md`, `dist/makerworld_listing.md` and
`CHANGELOG.md` in the same change ([AGENTS.md](../../AGENTS.md#standing-directives)).
