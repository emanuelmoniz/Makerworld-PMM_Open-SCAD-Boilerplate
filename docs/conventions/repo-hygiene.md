# Repository hygiene: what is tracked and why

> **Scope.** Which files belong in git, which are generated, and which are gitignored. When in
> doubt, check this table before adding or ignoring something.

| Path | Tracked? | Generated? | Why |
|---|---|---|---|
| `lib/`, `parts/`, `assembly/` | ✅ | no | the source |
| `scripts/*_config.sh` | ✅ | no | hand-edited configuration |
| `dist/<slug>_makerworld.scad` | ✅ | **yes** | the file you upload. Tracking it makes every release's exact upload recoverable, and CI checks it's up to date. |
| `dist/makerworld_listing.md` | ✅ | no | the one hand-written file in `dist/` |
| `dist/<slug>_dev.scad` | ❌ | yes | local convenience, rebuilt any time |
| `.build/` (e.g. `plates.json`) | ❌ | yes | regenerated on every run. Tracking it would only add diff churn. |
| `renders/` | ✅ | yes (manually) | published listing images |
| `stl/` | ✅ | yes (manually) | published default-parameter STLs |
| `printables/` | ✅ | mixed | hand-curated profiles and generated `*_generated.3mf` |
| `docs/pmm/data/*.json` | ✅ | yes (refresh script) | offline reference and lint input |
| `scripts/export/base_settings.3mf` | ✅ | no (saved from Bambu Studio) | reference print profile |
| `.claude/`, `.vscode/` | ❌ | — | per-user tool state |

## Rules

- **Never hand-edit a generated file.** Change its source and regenerate.
- **Keep published assets consistent with the current version.** Regenerate renders and STLs when
  the geometry they show changes (only when asked; renders are opt-in). Delete stale ones
  instead of leaving outdated files next to current ones.
- **Spell asset names exactly like the part.** `stl/stopper.stl`, not `stl/stoper.stl`.
- **No scratch files in the repo root.** Track to-dos in GitHub issues or a
  `## [Unreleased]`-adjacent `docs/` note, not an untracked `_todo.txt`.
- **Agent worktrees and caches** (e.g. `.claude/worktrees/`) stay out of the repo. Delete stale
  ones, since they're full copies of the project.
- Line endings are fixed by `.gitattributes`. Don't override them per machine.
