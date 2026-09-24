# Setup: dependencies and installation

> **Scope.** Everything to install before working on a project, what each piece is for, and how
> the scripts find it. Only OpenSCAD is strictly required to *edit* a model. The rest enables
> the pipelines.

## Dependencies

| Tool | Needed for | Required? | Found via |
|---|---|---|---|
| **OpenSCAD** (development snapshot recommended) | editing, smoke check, render, 3MF export | **yes** | `OPENSCAD_BIN`, PATH, standard install folders |
| **Python 3.8+** (stdlib only, no `pip install`) | every pipeline (config parsing, plates, lint, bbox) | **yes** | `PYTHON_BIN`, `python` / `python3` / `py` |
| **PowerShell** (5.1 built into Windows, or pwsh 7) | MakerWorld and dev builds | **yes** | built in (pwsh on macOS/Linux) |
| **Git for Windows** (provides Git Bash) | render, 3MF export, checks, and version control | **yes** on Windows | `GIT_BASH_BIN`, standard Git folders |
| **Bambu Studio** | 3MF export only (and optional printer-derived plate size) | optional | `BAMBU_STUDIO_BIN`, PATH, standard install folders |
| **BOSL2** (or other bundled libraries) | only if your model includes them | optional | OpenSCAD user library folder / `OPENSCADPATH` |
| Project fonts | only if your model uses text | optional | OS font folders (see below) |

No other package manager is involved.

## 1. OpenSCAD: use a development snapshot

PMM renders with a recent OpenSCAD development build **with the Manifold backend**
([specification.md §8](../pmm/specification.md#8-backend)). The **2021.01** stable release is
CGAL-only: it's often **10–100× slower** on booleans, and it differs in some edge cases.

1. Download a **development snapshot** from <https://openscad.org/downloads.html#snapshots>.
   The Windows installer puts it in `C:\Program Files\OpenSCAD (Nightly)\`. The scripts look
   there first.
2. Enable Manifold: *Edit → Preferences → Features* (or *Advanced*) → **Manifold** backend.
   On the command line, recent snapshots accept `--backend=manifold`.
3. Check: `openscad --version`.

Keeping 2021.01 installed alongside is fine. Force one explicitly with `OPENSCAD_BIN`.

## 2. Python 3

Install from <https://www.python.org/downloads/> and tick **"Add python.exe to PATH"**. Check:
`python --version`. On Windows, a `python3` command on PATH may be the Microsoft Store stub. The
scripts detect this and skip it.

## 3. Git Bash (Windows)

Install **Git for Windows** (<https://git-scm.com/download/win>). The `.bat` wrappers locate
`bash.exe` in the standard Git folders even when it isn't on PATH, and deliberately avoid WSL's
`System32\bash.exe`.

## 4. Bambu Studio (optional)

Needed only for `scripts\export_3mf.bat`. Install from <https://bambulab.com/download/studio>.
The export uses its CLI (`bambu-studio.exe`) and its machine presets (bed shapes).

## 5. Libraries (only if used)

See [libraries-and-fonts.md](../openscad/libraries-and-fonts.md#installing-a-library-locally-bosl2-example).
For BOSL2, pin the commit PMM uses.

## 6. Fonts (only if your model uses text)

Pick fonts installed on PMM **and** locally. The Windows install trap and the recommended
defaults are in
[libraries-and-fonts.md](../openscad/libraries-and-fonts.md#fonts).

## Environment variables (all optional)

| Variable | Overrides |
|---|---|
| `OPENSCAD_BIN` | path to `openscad` / `openscad.exe` |
| `PYTHON_BIN` | Python interpreter |
| `GIT_BASH_BIN` | `bash.exe` used by the `.bat` wrappers |
| `BAMBU_STUDIO_BIN` | path to `bambu-studio` |
| `BAMBU_PROFILES_DIR` | Bambu machine presets folder (`.../profiles/BBL/machine`) |
| `OPENSCADPATH` | extra OpenSCAD library folders (also used by the lint's BOSL2 scan) |
| `CI` | when set, the `.bat` wrappers don't `pause` |

## Verify the whole toolchain

From the repository root:

```bat
scripts\build.bat examples\demo
scripts\check.bat examples\demo
```

Both should end successfully (`ALL CHECKS PASSED`). Then optionally `scripts\render.bat
examples\demo` and `scripts\export_3mf.bat examples\demo`.

## Git hooks (once per clone)

```sh
git config core.hooksPath .githooks
```

Enables `.githooks/pre-commit`, which refuses a commit whose MakerWorld bundle or generated
parameter tables are stale (`scripts/check/fresh.sh`). `init_project.py` sets it for the clone
it runs in; every other clone needs the command above.

## VS Code (optional)

Open `project.code-workspace`. Useful extensions: *OpenSCAD* (syntax), *EditorConfig*,
*ShellCheck*, *PowerShell*, *Python*.
