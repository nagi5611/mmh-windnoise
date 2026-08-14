#!/usr/bin/env bash
# 1 ケースのメッシュ生成（blockMesh → snappyHexMesh → checkMesh）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/env.sh"

CASE="${1:?Usage: mesh_case.sh <case_name>}"
CASE_DIR="${MMH_REPO_ROOT}/cases/run/${CASE}"

mmh_require_openfoam

if [[ ! -d "${CASE_DIR}" ]]; then
  echo "Case not found: ${CASE_DIR}"
  echo "Run: python3 scripts/generate_cases.py"
  if [[ "${CASE}" =~ ^ps[0-9]+_U ]]; then
    fixed="psi${CASE#ps}"
    if [[ -d "${MMH_REPO_ROOT}/cases/run/${fixed}" ]]; then
      echo "Did you mean: ${fixed} ?"
      echo "  make mesh CASE=${fixed}"
    fi
  fi
  exit 1
fi

cd "${CASE_DIR}"

TEMPLATE="${MMH_REPO_ROOT}/cases/template"
SFE_DICT="${CASE_DIR}/system/surfaceFeatureExtractDict"
if [[ ! -f "${SFE_DICT}" && -f "${TEMPLATE}/system/surfaceFeatureExtractDict" ]]; then
  echo "=== copy surfaceFeatureExtractDict (missing in case) ==="
  cp "${TEMPLATE}/system/surfaceFeatureExtractDict" "${SFE_DICT}"
fi

echo "=== blockMesh ==="
blockMesh | tee log.blockMesh

echo "=== surfaceFeatureExtract ==="
if ! surfaceFeatureExtract | tee log.surfaceFeatureExtract; then
  echo "ERROR: surfaceFeatureExtract が失敗しました。" >&2
  exit 1
fi

EMESH="${CASE_DIR}/constant/triSurface/head.eMesh"
if [[ ! -f "${EMESH}" ]]; then
  echo "ERROR: head.eMesh が生成されていません: ${EMESH}" >&2
  echo "  snappyHexMesh の features がこのファイルを要求しています。" >&2
  echo "  対処: git pull 後に make sync-templates && make mesh CASE=${CASE} を再実行" >&2
  exit 1
fi

echo "=== snappyHexMesh ==="
snappyHexMesh -overwrite | tee log.snappyHexMesh

echo "=== checkMesh ==="
set +e
checkMesh | tee log.checkMesh
CHECK_RC=${PIPESTATUS[0]}
set -e

if [[ "${CHECK_RC}" -ne 0 ]]; then
  echo ""
  echo "WARNING: checkMesh が警告/失敗を報告しました (exit ${CHECK_RC})"
  echo "  軽微な skewness のみなら計算は続行可能なことが多いです。"
  echo "  気になる場合はケース再生成後に make mesh を再実行してください。"
  echo ""
fi

echo "Done: ${CASE}"
