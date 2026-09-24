# Workflow: start a new project

> **Goal.** Go from this template to your own project with a green build, about 15 minutes before
> any geometry. Each step names the file it touches.

## 1. Create the repository

- On GitHub: **Use this template → Create a new repository**, then clone it.
- Or locally: copy this folder without `.git/`, then `git init`.

## 2. Check the toolchain

Install the prerequisites ([setup.md](../toolchain/setup.md)), then prove they work on the demo:

```bat
scripts\build.bat examples\demo
scripts\check.bat examples\demo
```

## 3. Fill the template tokens

```sh
python scripts/init_project.py --name "Parametric Spice Rack" --slug spice_rack \
    --owner <github-user> --repo <repo-name> --holder "<Your Name>"
```

This replaces `<PROJECT NAME>`, `<OWNER>`, `<REPO>`, `<YEAR>` and `<COPYRIGHT HOLDER>` in every
text file, sets `PROJECT_NAME`/`PROJECT_SLUG` in `scripts/project_config.sh`, and removes the
TEMPLATE banner from `README.md`. Options:

- `--drop-examples` deletes `examples/`
- `--check` lists any tokens still left, without changing anything
- `--dry-run` shows what would change

Then pick a license (`LICENSE`, MIT by default). MakerWorld asks you to choose a license for the
**model** separately when you publish.

## 4. Refresh the PMM inventories

```sh
python scripts/shared/pmm_inventory.py
```

## 5. Describe the project

| File | Fill in |
|---|---|
| `README.md` | `BUNDLE-DESCRIPTION` paragraph (ships inside the bundle), features, parts (the parameter table is generated) |
| `AGENTS.md` → *Project overview* | what the model is, its parts, how they mate, mode switches |
| `dist/makerworld_listing.md` | the customer-facing listing (can wait until the first release) |

## 6. Replace the stubs with your model

1. `lib/params.scad`: replace the `REPLACE ME` parameters with yours
   ([add-a-parameter.md](add-a-parameter.md)).
2. `lib/helpers.scad`: keep, rename or delete.
3. For each printed part, copy `parts/part_template.scad` to `parts/<name>.scad`
   ([add-a-part.md](add-a-part.md)). Then delete the template part.
4. `assembly/assembly_main.scad`: compose the parts, and write one `mw_plate_N()` per plate.
5. `scripts/project_config.sh`: `SOURCE_FILES`, `DEV_VIEWS`, `BUNDLED_LIBRARIES` (remove unused),
   `COLOR_PASSTHROUGH`, and `SMOKE_VARIANTS` (the extremes the smoke check should build).
6. `scripts/plates_config.sh`: `PLATE_NAMES`, `PLATE_N_PARTS`, `PRINTER`.
7. `scripts/render_config.sh`: `TARGETS`.

**Single-part model?** Delete the `mw_*` modules, set `PLATE_ASSEMBLY_FILE=""` and
`MAKERWORLD_TOP_LEVEL_CALL="<part>();"`, and empty `PLATE_NAMES`. This keeps PMM's STL download.

## 7. Build, check, commit

```bat
scripts\build.bat
scripts\dev_build.bat
scripts\check.bat
```

Add a `CHANGELOG.md` entry, then make the first commit.

## 8. Optional: CI

`.github/workflows/check.yml` runs the freshness check (committed bundle and parameter tables match
the sources), lint and smoke with every `SMOKE_VARIANTS` set on every push. It works as-is on
GitHub. Locally, the pre-commit hook `init_project.py` enabled runs the freshness check before
each commit.
