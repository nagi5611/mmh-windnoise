#!/usr/bin/env bash
# 1 ケースを定常 simpleFoam で MPI 並列実行（ローカル PC 向け）
# Usage: run_steady_parallel.sh [case_name] [nProcs]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/env.sh"

CASE="${1:-psi000_U050}"
NP="${2:-${MMH_NPROCS:-8}}"
CASE_DIR="${MMH_REPO_ROOT}/cases/run/${CASE}"

mmh_require_openfoam

if [[ ! "${NP}" =~ ^[0-9]+$ ]] || [[ "${NP}" -lt 2 ]]; then
  echo "ERROR: NP>=2 が必要です。例: bash scripts/run_steady_parallel.sh psi000_U050 8" >&2
  exit 1
fi

if [[ ! -d "${CASE_DIR}" ]]; then
  echo "Case not found: ${CASE_DIR}" >&2
  echo "Run: python3 scripts/generate_cases.py" >&2
  exit 1
fi

if ! mmh_ensure_case_mesh "${CASE_DIR}"; then
  echo "メッシュがありません。生成します: ${CASE}"
  bash "${SCRIPT_DIR}/mesh_case.sh" "${CASE}"
fi

mmh_ensure_case_initial_fields "${CASE_DIR}"
mmh_configure_steady_control "${CASE_DIR}"

echo ""
echo "========================================"
echo " 定常 simpleFoam: ${CASE}  (np=${NP})"
echo " 風速: $(grep -m1 internalField "${CASE_DIR}/0/U")"
echo "========================================"
echo ""

bash "${SCRIPT_DIR}/run_case_parallel.sh" "${CASE}" simpleFoam "${NP}"

cat <<EOF

完了: ${CASE}
ログ: cases/run/${CASE}/log.simpleFoam.parallel

VTK:
  cd cases/run/${CASE} && foamToVTK -latestTime -fields '(p U)'
  paraview

EOF
