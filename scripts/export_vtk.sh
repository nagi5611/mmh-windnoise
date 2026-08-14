#!/usr/bin/env bash
# 時間平均圧力・速度を VTK にエクスポート（ParaView 用）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/env.sh"

MANIFEST="${MMH_REPO_ROOT}/cases/run/case_manifest.txt"
OUT_ROOT="${MMH_REPO_ROOT}/postprocess/vtk"

mmh_require_openfoam

if [[ ! -f "${MANIFEST}" ]]; then
  echo "Manifest not found. Run: python3 scripts/generate_cases.py"
  exit 1
fi

mkdir -p "${OUT_ROOT}"

while IFS= read -r CASE; do
  CASE_DIR="${MMH_REPO_ROOT}/cases/run/${CASE}"
  [[ -d "${CASE_DIR}" ]] || continue

  echo "Exporting VTK: ${CASE}"
  cd "${CASE_DIR}"

  LATEST=$(foamListTimes -latestTime 2>/dev/null | tail -1 || echo "2000")
  foamToVTK -time "${LATEST}" -fields '(p U)' | tee log.foamToVTK

  mkdir -p "${OUT_ROOT}/${CASE}"
  cp -r VTK "${OUT_ROOT}/${CASE}/" 2>/dev/null || true
done < "${MANIFEST}"

echo "VTK files -> ${OUT_ROOT}"
