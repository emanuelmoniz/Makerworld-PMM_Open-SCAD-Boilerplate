# scripts/: pipelines and their configs

**Edit these** (configs, heavily commented, constrained bash syntax):

| Config | Controls |
|---|---|
| `project_config.sh` | identity, `SOURCE_FILES`, plate file, libraries, colors, README markers, dev views, generated parameter tables, smoke variants, clearance checks |
| `plates_config.sh` | printer, `MW_PLATE_SIZE`, plates → parts, per-part Bambu overrides |
| `render_config.sh` | render targets, angles, ratios, quality |
| `export_3mf_config.sh` | 3MF export overrides, reference profile, output |

**Run these** (Windows wrappers; each takes an optional project folder):
`build.bat`, `dev_build.bat`, `check.bat`, `render.bat`, `export_3mf.bat`.

**Implementations:** `build/` (PowerShell), `render/`, `export/`, `check/` (bash + Python),
`shared/` (Python helpers, tool discovery, `param_tables.py`, `render_fit.py`). Also `init_project.py` (fill template
tokens, enable the git hooks in `../.githooks/`).

Docs: [pipelines](../docs/toolchain/pipelines.md), [platform contract](../docs/toolchain/platform-contract.md).
