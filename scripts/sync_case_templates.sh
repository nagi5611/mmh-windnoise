#!/usr/bin/env bash
# テンプレートの system/constant/0 を既存ケースへ同期する
# git pull だけでは cases/run/ は更新されないため使用
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE="${REPO_ROOT}/cases/template"
RUN_DIR="${REPO_ROOT}/cases/run"
MANIFEST="${RUN_DIR}/case_manifest.txt"

if [[ ! -f "${MANIFEST}" ]]; then
  echo "Manifest not found. Run: python3 scripts/generate_cases.py"
  exit 1
fi

SYNC_PATHS=(
  system/fvSolution
  system/controlDict
  system/fvSchemes
  system/snappyHexMeshDict
  system/blockMeshDict
)

while IFS= read -r CASE; do
  CASE_DIR="${RUN_DIR}/${CASE}"
  [[ -d "${CASE_DIR}" ]] || continue

  echo "Sync: ${CASE}"
  for rel in "${SYNC_PATHS[@]}"; do
    src="${TEMPLATE}/${rel}"
    dst="${CASE_DIR}/${rel}"
    if [[ -f "${src}" ]]; then
      cp "${src}" "${dst}"
    fi
  done
done < "${MANIFEST}"

echo "Done. Synced template files to existing cases in ${RUN_DIR}"
