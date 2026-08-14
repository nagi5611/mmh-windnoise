#!/usr/bin/env bash
# 時間平均圧力・速度を VTK にエクスポート（ParaView 用）
set -euo pipefail

MANIFEST="/workspace/cases/run/case_manifest.txt"

if [[ -f /usr/lib/openfoam/openfoam2312/etc/bashrc ]]; then
  source /usr/lib/openfoam/openfoam2312/etc/bashrc
fi

OUT_ROOT="/workspace/postprocess/vtk"
mkdir -p "${OUT_ROOT}"

while IFS= read -r CASE; do
  CASE_DIR="/workspace/cases/run/${CASE}"
  [[ -d "${CASE_DIR}" ]] || continue

  echo "Exporting VTK: ${CASE}"
  cd "${CASE_DIR}"

  # 最新タイムステップを VTK 出力
  LATEST=$(foamListTimes -latestTime 2>/dev/null | tail -1 || echo "2000")
  foamToVTK -time "${LATEST}" -fields '(p U)' | tee log.foamToVTK

  mkdir -p "${OUT_ROOT}/${CASE}"
  cp -r VTK "${OUT_ROOT}/${CASE}/" 2>/dev/null || true
done < "${MANIFEST}"

echo "VTK files -> ${OUT_ROOT}"
