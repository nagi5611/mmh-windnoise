#!/usr/bin/env bash
# 全ケースを指定ソルバーで直列実行する
set -euo pipefail

SOLVER="${1:-simpleFoam}"
MANIFEST="/workspace/cases/run/case_manifest.txt"

if [[ ! -f "${MANIFEST}" ]]; then
  echo "Manifest not found. Run: python3 scripts/generate_cases.py"
  exit 1
fi

# OpenFOAM 環境
if [[ -f /usr/lib/openfoam/openfoam2312/etc/bashrc ]]; then
  source /usr/lib/openfoam/openfoam2312/etc/bashrc
fi

TOTAL=$(wc -l < "${MANIFEST}")
IDX=0

while IFS= read -r CASE; do
  IDX=$((IDX + 1))
  CASE_DIR="/workspace/cases/run/${CASE}"

  if [[ ! -d "${CASE_DIR}/constant/polyMesh" ]]; then
    echo "[${IDX}/${TOTAL}] ${CASE}: meshing..."
    bash /workspace/scripts/mesh_case.sh "${CASE}"
  fi

  echo "[${IDX}/${TOTAL}] ${CASE}: running ${SOLVER}..."
  cd "${CASE_DIR}"

  if [[ "${SOLVER}" == "simpleFoam" ]]; then
  # 定常: controlDict を steady に切替
    foamDictionary system/controlDict -entry application -set simpleFoam
    foamDictionary system/controlDict -entry endTime -set 2000
    foamDictionary system/controlDict -entry deltaT -set 1
    foamDictionary system/controlDict -entry writeInterval -set 2000
  fi

  ${SOLVER} | tee "log.${SOLVER}"

  echo "[${IDX}/${TOTAL}] ${CASE}: done"
done < "${MANIFEST}"

echo "All cases finished with ${SOLVER}"
