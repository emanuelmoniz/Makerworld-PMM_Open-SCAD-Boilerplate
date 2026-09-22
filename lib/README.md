# lib/: parameters and shared geometry

| File | Role |
|---|---|
| `params.scad` | **Every parameter**: customizer tabs, then `[Hidden]` constants, then derived values. The single source of truth, and PMM's customizer UI. Always first in `SOURCE_FILES`. |
| `helpers.scad` | Shared building blocks with no printed part of their own. Rename, split or delete as needed. |

- Parts reach `params.scad` with `include` and everything else with `use`
  ([source-architecture](../docs/conventions/source-architecture.md)).
- Every new file here must be added to `SOURCE_FILES` in `scripts/project_config.sh`.
- Give modules distinctive names. The bundle is flat and the last definition wins
  ([naming](../docs/conventions/naming.md)).
