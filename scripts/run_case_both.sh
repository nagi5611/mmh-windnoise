#!/usr/bin/env bash
# 1ケースで定常(simpleFoam)と非定常(pimpleFoam)を MPI 並列実行
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/env.sh"

CASE="${1:?Usage: run_case_both.sh <case_name> [nProcs]}"
NP="${2:-${MMH_NPROCS:-8}}"

CASE_DIR="${MMH_REPO_ROOT}/cases/run/${CASE}"
TEMPLATE_CTRL="${MMH_REPO_ROOT}/cases/template/system/controlDict"
mmh_require_openfoam

if [[ ! -d "${CASE_DIR}/constant/polyMesh" ]]; then
  echo "Mesh not found. Run: make mesh CASE=${CASE}"
  exit 1
fi

run_parallel() {
  local solver="$1"
  local label="$2"

  cd "${CASE_DIR}"

  echo ""
  echo "========================================"
  echo " ${label} (${solver}, np=${NP})"
  echo "========================================"

  rm -rf processor* postProcessing/[0-9]* [0-9]* [0-9][0-9]* 2>/dev/null || true

  foamDictionary system/decomposeParDict -entry numberOfSubdomains -set "${NP}"
  decomposePar -force | tee "log.decomposePar.${solver}"

  mpirun -np "${NP}" ${solver} -parallel | tee "log.${solver}.parallel"
  reconstructPar | tee "log.reconstructPar.${solver}"
}

# --- 定常 ---
cp "${TEMPLATE_CTRL}" "${CASE_DIR}/system/controlDict.transient.bak"
foamDictionary "${CASE_DIR}/system/controlDict" -entry application -set simpleFoam
foamDictionary "${CASE_DIR}/system/controlDict" -entry endTime -set 2000
foamDictionary "${CASE_DIR}/system/controlDict" -entry deltaT -set 1
foamDictionary "${CASE_DIR}/system/controlDict" -entry writeInterval -set 2000
foamDictionary "${CASE_DIR}/system/controlDict" -entry writeControl -set timeStep
foamDictionary "${CASE_DIR}/system/controlDict" -entry adjustTimeStep -set false

run_parallel simpleFoam "定常 simpleFoam"

# --- 非定常（controlDict を戻す）---
cp "${CASE_DIR}/system/controlDict.transient.bak" "${CASE_DIR}/system/controlDict"

run_parallel pimpleFoam "非定常 pimpleFoam 10s"

cat <<EOF

========================================
  完了: ${CASE}
========================================
定常ログ   : cases/run/${CASE}/log.simpleFoam.parallel
非定常ログ : cases/run/${CASE}/log.pimpleFoam.parallel

VTK 出力:
  cd cases/run/${CASE} && foamToVTK -latestTime -fields '(p U)'

EOF
