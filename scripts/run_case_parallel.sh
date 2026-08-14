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

if [[ ! -d "${CASE_DIR}/constant/polyMesh" ]]; then
  echo "Mesh not found. Run: make mesh CASE=${CASE}"
  exit 1
fi

cd "${CASE_DIR}"

if [[ ! -d processor0 ]]; then
  echo "=== decomposePar (${NP} cores) ==="
  foamDictionary system/decomposeParDict -entry numberOfSubdomains -set "${NP}"
  decomposePar -force | tee log.decomposePar
fi

echo "=== ${SOLVER} -parallel (np=${NP}) ==="
mpirun -np "${NP}" ${SOLVER} -parallel | tee "log.${SOLVER}.parallel"

echo "=== reconstructPar ==="
reconstructPar | tee log.reconstructPar

echo "Done: ${CASE} (${NP} cores)"
