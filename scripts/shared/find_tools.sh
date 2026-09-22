# ============================================================
# <PROJECT NAME>  |  External tool discovery (bash side, SOURCED)
# ------------------------------------------------------------
# `source scripts/shared/find_tools.sh` from any bash script, then use
# "$OPENSCAD", "$BAMBU_STUDIO", "$PYTHON". Replaces the hardcoded
# "/c/Program Files/..." paths the original project baked into each
# script -- a clone on a different machine / OS / install location now
# works without editing any script.
#
# Resolution order for each tool, first hit wins:
#   1. an environment variable you set (OPENSCAD_BIN, BAMBU_STUDIO_BIN,
#      PYTHON_BIN) -- the escape hatch for unusual installs
#   2. the tool on PATH
#   3. standard install locations (Windows via Git Bash, macOS, Linux)
#
# Nothing here exits: a tool that is not found is left EMPTY, and each
# script calls require_tool for only the tools it actually needs (the
# render pipeline never needs Bambu Studio, for example).
#
# See: docs/toolchain/setup.md, docs/toolchain/platform-contract.md
# ============================================================

_first_existing() {
    local candidate
    for candidate in "$@"; do
        if [ -n "$candidate" ] && [ -x "$candidate" ]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

# ---- OpenSCAD ------------------------------------------------------------
# The Nightly locations come first: PMM runs OpenSCAD with the Manifold
# backend (docs/pmm/specification.md "Backend"), which only development
# snapshots / 2025+ releases have. A Nightly install is the closest local
# match to what MakerWorld actually runs.
if [ -z "${OPENSCAD:-}" ]; then
    OPENSCAD="$(_first_existing \
        "${OPENSCAD_BIN:-}" \
        "$(command -v openscad-nightly 2>/dev/null)" \
        "$(command -v openscad 2>/dev/null)" \
        "/c/Program Files/OpenSCAD (Nightly)/openscad.exe" \
        "/c/Program Files/OpenSCAD/openscad.exe" \
        "/Applications/OpenSCAD-Nightly.app/Contents/MacOS/OpenSCAD" \
        "/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD" \
        "/usr/bin/openscad" \
    )" || OPENSCAD=""
fi

# ---- Bambu Studio (3mf export only) --------------------------------------
if [ -z "${BAMBU_STUDIO:-}" ]; then
    BAMBU_STUDIO="$(_first_existing \
        "${BAMBU_STUDIO_BIN:-}" \
        "$(command -v bambu-studio 2>/dev/null)" \
        "/c/Program Files/Bambu Studio/bambu-studio.exe" \
        "/Applications/BambuStudio.app/Contents/MacOS/BambuStudio" \
        "/usr/bin/bambu-studio" \
    )" || BAMBU_STUDIO=""
fi

# ---- Python 3 (stdlib only) ----------------------------------------------
# `python3` is tried by actually running it: on Windows a `python3` on PATH
# is often the Microsoft Store stub, which exists but only prints an
# install hint.
if [ -z "${PYTHON:-}" ]; then
    for _py in "${PYTHON_BIN:-}" python3 python py; do
        [ -z "$_py" ] && continue
        if "$_py" -c "import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)" >/dev/null 2>&1; then
            PYTHON="$_py"
            break
        fi
    done
    unset _py
fi

# ---- PowerShell (the export rebuilds the dev bundle with it) -------------
# pwsh (PowerShell 7, any OS) first, then Windows PowerShell 5.1.
if [ -z "${POWERSHELL:-}" ]; then
    POWERSHELL="$(_first_existing \
        "${POWERSHELL_BIN:-}" \
        "$(command -v pwsh 2>/dev/null)" \
        "$(command -v powershell.exe 2>/dev/null)" \
        "$(command -v powershell 2>/dev/null)" \
    )" || POWERSHELL=""
fi

# require_tool <VAR_NAME> <human name> <env var to set>
require_tool() {
    local value="${!1:-}"
    if [ -z "$value" ]; then
        echo "ERROR: $2 not found. Install it, add it to PATH, or set $3 to its full path." >&2
        echo "       See docs/toolchain/setup.md" >&2
        exit 1
    fi
}
