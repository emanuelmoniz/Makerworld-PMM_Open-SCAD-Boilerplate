#!/bin/bash
# ============================================================
# <PROJECT NAME>  |  Freshness check: are the generated files current?
# ------------------------------------------------------------
# The tracked MakerWorld bundle and the generated parameter tables must
# match the sources they are built from. It is easy to change params.scad
# (a default, a label) after the last build and commit a stale bundle --
# CI then fails, or worse, MakerWorld gets the old one. This catches it
# locally, independent of git state:
#   1. build the MakerWorld bundle into a temp file (build.ps1 -OutFile,
#      which touches nothing tracked) and compare it with the tracked one
#   2. param_tables.py --check: the PARAM_TABLES tables match params.scad
# Fix: run the MakerWorld build (it rewrites both), then commit the result.
#
# Run by check.sh, and by the pre-commit hook in .githooks/ (enabled with
# `git config core.hooksPath .githooks`; init_project.py does it).
#
# Usage: scripts/check/fresh.sh [-p project_dir]
# See:   docs/toolchain/pipelines.md ("Checks")
# ============================================================
set -u
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
source "$SCRIPTS_DIR/shared/find_tools.sh"

PROJECT_DIR="$REPO_ROOT"
while [ "$#" -gt 0 ]; do
    case "$1" in
        -p|--project) PROJECT_DIR="$(cd "$REPO_ROOT" && cd "$2" && pwd)"; shift 2 ;;
        *) echo "Usage: fresh.sh [-p project_dir]" >&2; exit 1 ;;
    esac
done
require_tool POWERSHELL "PowerShell (pwsh or powershell.exe)" "POWERSHELL_BIN"
require_tool PYTHON "Python 3" "PYTHON_BIN"

# shellcheck disable=SC1091
source "$PROJECT_DIR/scripts/project_config.sh"   # PROJECT_SLUG
BUNDLE="$PROJECT_DIR/dist/${PROJECT_SLUG}_makerworld.scad"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
fresh="$WORKDIR/fresh.scad"
# Paths handed to Windows PowerShell / Python need the C:/... form.
win() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }

failures=0
if ! "$POWERSHELL" -NoProfile -ExecutionPolicy Bypass -File "$(win "$SCRIPTS_DIR/build/build.ps1")" \
        -Project "$(win "$PROJECT_DIR")" -OutFile "$(win "$fresh")" > "$WORKDIR/build.log" 2>&1; then
    sed 's/^/        /' "$WORKDIR/build.log" | head -20
    echo "  FAIL   MakerWorld build failed"
    failures=$((failures + 1))
elif [ ! -f "$BUNDLE" ]; then
    echo "  FAIL   dist/$(basename "$BUNDLE") is missing -- run the MakerWorld build"
    failures=$((failures + 1))
elif ! cmp -s "$fresh" "$BUNDLE"; then
    echo "  STALE  dist/$(basename "$BUNDLE") differs from a fresh build of the sources -- run the MakerWorld build"
    diff "$BUNDLE" "$fresh" | head -10 | sed 's/^/        /'
    failures=$((failures + 1))
else
    echo "  ok     dist/$(basename "$BUNDLE") matches the sources"
fi

if "$PYTHON" "$(win "$SCRIPTS_DIR/shared/param_tables.py")" "$(win "$PROJECT_DIR")" --check; then
    [ -n "${PARAM_TABLES[*]:-}" ] && echo "  ok     parameter tables match params.scad"
else
    failures=$((failures + 1))
fi

[ $failures -eq 0 ] || { echo "FRESHNESS: $failures problem(s)"; exit 1; }
echo "FRESHNESS: all current"
