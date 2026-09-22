# Platform contract: which shell runs what

> **Scope.** The toolchain deliberately uses three shells. This page says which one runs each
> piece, why, and what must hold for them to cooperate. Read it before adding or changing a
> script.

## Who runs what

| Piece | Language | Runs on | Why this language |
|---|---|---|---|
| `scripts/*.bat` | cmd batch | Windows | double-clickable entry points |
| `scripts/build/*.ps1`, `Bundle.psm1` | PowerShell 5.1 / 7 | Windows natively, macOS/Linux via `pwsh` | text transformation with good regex, available on every Windows machine |
| `scripts/render/`, `export/`, `check/*.sh` | bash | Git Bash (Windows), macOS, Linux | orchestrating CLIs (OpenSCAD, Bambu Studio) |
| `scripts/shared/*.py`, `check/pmm_lint.py` | Python 3 stdlib | everywhere | parsing, JSON, ZIP/XML, geometry math, shared by the other two |
| `scripts/*_config.sh` | constrained bash | read by all | one human-friendly format with comments (see below) |

## Invariants

1. **Configs are bash, parsed identically everywhere.** bash scripts `source` them. PowerShell and
   Python read them through `scripts/shared/bash_config.py`. Keep configs inside that parser's
   subset: `NAME="value"`, multi-line arrays with one item per line, full-line comments. No
   `$VAR` expansion.
2. **No hardcoded tool paths.** Tools are discovered by `scripts/shared/find_tools.sh` (bash), the
   discovery in `Bundle.psm1` (PowerShell) and `find_bash.cmd` (batch), each with an environment
   variable override ([setup.md](setup.md#environment-variables-all-optional)).
3. **Line endings per type** (`.gitattributes`): `.sh`/`.py`/`.scad` LF (a CRLF shebang breaks bash),
   `.bat`/`.ps1` CRLF (cmd mis-parses LF batch files).
4. **Generated `.scad` files are UTF-8 *without* BOM.** OpenSCAD rejects a BOM.
5. **Windows Python prints CRLF.** Bash code reading Python output strips `\r` (`| tr -d '\r'`).
6. **Paths written *inside files* on Windows use `C:/...` form.** Git Bash converts `/c/...`
   *arguments* for native programs automatically, but not paths inside file contents
   (`cygpath -m` in `smoke.sh`).
7. **PowerShell stays 5.1-compatible**: no `??`, `?:`, `&&`, or `-AsHashtable`.
8. **Every script takes a project folder** (default: repo root) and resolves all project paths
   relative to it, so the same scripts build `examples/demo` or any other project folder.

## macOS / Linux

Everything except the `.bat` wrappers works: run `pwsh scripts/build/build.ps1`,
`bash scripts/check/check.sh`, and so on. CI (`.github/workflows/check.yml`) runs exactly this on
Ubuntu.
