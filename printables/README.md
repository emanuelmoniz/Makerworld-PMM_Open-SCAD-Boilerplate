# printables/: print-ready 3MF projects

| Name pattern | Source |
|---|---|
| `<slug>_generated.3mf` | `scripts\export_3mf.bat` (configured in `scripts/export_3mf_config.sh`) |
| `<slug>_<variant>.3mf` | hand-curated in Bambu Studio, e.g. ready-to-print profiles for the listing |

Open every generated file in Bambu Studio before printing from it: the multi-plate format is
reverse-engineered ([pipelines](../docs/toolchain/pipelines.md#3mf-export-optional-bambu-studio)).
