#!/usr/bin/env bash
# 1 ケースを MPI 並列で実行（decomposePar → solver -parallel → reconstructPar）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/env.sh"

CASE="${1:?Usage: run_case_parallel.sh <case_name> [solver] [nProcs]}"
SOLVER="${2:-pimpleFoam}"
NP="${3:-${MMH_NPROCS:-8}}"

CASE_DIR="${MMH_REPO_ROOT}/cases/run/${CASE}"
mmh_require_openfoam

if [[ ! "${NP}" =~ ^[0-9]+$ ]] || [[ "${NP}" -lt 2 ]]; then
  echo "ERROR: 並列実行には NP>=2 が必要です。例: make run-parallel CASE=${CASE} NP=8" >&2
  exit 1
fi

if [[ ! -d "${CASE_DIR}/constant/polyMesh" ]]; then
  echo "Mesh not found. Run: make mesh CASE=${CASE}"
  exit 1
fi

mmh_decompose_case "${CASE_DIR}" "${NP}" "decomposePar"

cd "${CASE_DIR}"

echo "=== ${SOLVER} -parallel (np=${NP}) ==="
mpirun -np "${NP}" "${SOLVER}" -parallel | tee "log.${SOLVER}.parallel"

echo "=== reconstructPar ==="
reconstructPar | tee log.reconstructPar

echo "Done: ${CASE} (${NP} cores)"
