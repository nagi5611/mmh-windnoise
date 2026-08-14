#!/usr/bin/env bash
# 1ケースで定常(simpleFoam)と非定常(pimpleFoam)を MPI 並列実行
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/env.sh"

CASE="${1:?Usage: run_case_both.sh <case_name> [nProcs]}"
NP="${2:-${MMH_NPROCS:-8}}"

CASE_DIR="${MMH_REPO_ROOT}/cases/run/${CASE}"
mmh_require_openfoam

if [[ ! "${NP}" =~ ^[0-9]+$ ]] || [[ "${NP}" -lt 2 ]]; then
  echo "ERROR: 並列実行には NP>=2 が必要です。例: make run-both CASE=${CASE} NP=8" >&2
  exit 1
fi

if [[ ! -d "${CASE_DIR}/constant/polyMesh" ]]; then
  echo "Mesh not found. Run: make mesh CASE=${CASE}"
  exit 1
fi

run_parallel() {
  local solver="$1"
  local label="$2"

  echo ""
  echo "========================================"
  echo " ${label} (${solver}, np=${NP})"
  echo "========================================"

  mmh_decompose_case "${CASE_DIR}" "${NP}" "decomposePar.${solver}"

  (
    cd "${CASE_DIR}"
    mmh_mpi_run "${NP}" "${solver}" -parallel | tee "log.${solver}.parallel"
    reconstructPar | tee "log.reconstructPar.${solver}"
  )
}

# --- 定常 ---
cp "${CASE_DIR}/system/controlDict" "${CASE_DIR}/system/controlDict.transient.bak"
foamDictionary "${CASE_DIR}/system/controlDict" -entry application -set simpleFoam
foamDictionary "${CASE_DIR}/system/controlDict" -entry endTime -set 2000
foamDictionary "${CASE_DIR}/system/controlDict" -entry deltaT -set 1
foamDictionary "${CASE_DIR}/system/controlDict" -entry writeInterval -set 2000
foamDictionary "${CASE_DIR}/system/controlDict" -entry writeControl -set timeStep

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
