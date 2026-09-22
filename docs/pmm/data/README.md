# PMM inventory snapshots

Machine-readable copies of MakerWorld PMM's own public inventories. `scripts/check/pmm_lint.py`
reads them offline, and humans and agents can search them directly.

| File | Contents | Shape |
|---|---|---|
| `libraries.json` | Bundled OpenSCAD libraries and their include method | `{"Libraries": [{"name", "url", "description", "includeMethod"}]}` |
| `fonts-installed.json` | Fonts **installed** in PMM's renderer. **Authoritative.** | `{"fontNames": ["Family:style=Style", ...]}` |
| `fonts-catalog.json` | The broader **display catalog**. **Not a guarantee.** | `{"fontNames": [...]}` |
| `manifest.json` | When the snapshot was taken and from which URLs | `{"fetched_utc", "sources"}` |

**Refresh** when starting a project and before each MakerWorld release:

```sh
python scripts/shared/pmm_inventory.py
```

Commit the refreshed files, since they're part of the reference. Quick lookups:

```sh
# is a font installed?
python -c "import json;print([f for f in json.load(open('docs/pmm/data/fonts-installed.json',encoding='utf-8'))['fontNames'] if f.startswith('Roboto Mono')])"
```

See [../sources.md](../sources.md) for URLs and caveats.
