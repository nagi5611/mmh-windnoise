#!/usr/bin/env bash
# 1 ケースのメッシュ生成（blockMesh → snappyHexMesh → checkMesh）
set -euo pipefail

CASE="${1:?Usage: mesh_case.sh <case_name>}"
CASE_DIR="/workspace/cases/run/${CASE}"

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
