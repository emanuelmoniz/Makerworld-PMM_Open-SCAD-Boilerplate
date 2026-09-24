#!/bin/bash
# ============================================================
# <PROJECT NAME>  |  Run every check (freshness + lint + smoke)
# ------------------------------------------------------------
# 1. fresh.sh     -- the tracked bundle and the generated parameter tables
#                    match the sources (catches a forgotten rebuild)
# 2. pmm_lint.py  -- static PMM-compatibility rules on the shipped bundle
# 3. smoke.sh     -- every source file and every plate actually compiles,
#                    with the defaults and with every SMOKE_VARIANTS set
# Run it after building, before committing a release, and in CI.
#
# Usage: scripts/check/check.sh [-p project_dir]
# See:   docs/toolchain/pipelines.md ("Checks")
# ============================================================
set -u
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPTS_DIR/shared/find_tools.sh"
require_tool PYTHON "Python 3" "PYTHON_BIN"

PROJECT_ARGS=()
[ "${1:-}" = "-p" ] && PROJECT_ARGS=(-p "$2")

status=0
echo "==================== Freshness ==================="
bash "$SCRIPTS_DIR/check/fresh.sh" "${PROJECT_ARGS[@]}" || status=1
echo "==================== PMM lint ===================="
"$PYTHON" "$SCRIPTS_DIR/check/pmm_lint.py" "${PROJECT_ARGS[@]}" || status=1
echo "==================== Smoke ======================="
bash "$SCRIPTS_DIR/check/smoke.sh" "${PROJECT_ARGS[@]}" || status=1
echo "=================================================="
[ $status -eq 0 ] && echo "ALL CHECKS PASSED" || echo "CHECKS FAILED"
exit $status
