#!/usr/bin/env bash
# 1 ケースのメッシュ生成（blockMesh → snappyHexMesh → checkMesh）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/env.sh"

CASE="${1:?Usage: mesh_case.sh <case_name>}"
CASE_DIR="${MMH_REPO_ROOT}/cases/run/${CASE}"

mmh_require_openfoam

if [[ ! -d "${CASE_DIR}" ]]; then
  echo "Case not found: ${CASE_DIR}"
  echo "Run: python3 scripts/generate_cases.py"
  exit 1
fi

cd "${CASE_DIR}"

echo "=== blockMesh ==="
blockMesh | tee log.blockMesh

echo "=== snappyHexMesh ==="
snappyHexMesh -overwrite | tee log.snappyHexMesh

echo "=== checkMesh ==="
checkMesh | tee log.checkMesh

echo "Done: ${CASE}"
