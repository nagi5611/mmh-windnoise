#!/usr/bin/env bash
# ケースの初期条件 0/ をテンプレートから復元する
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/env.sh"

CASE="${1:?Usage: restore_case_ic.sh <case_name>}"
CASE_DIR="${MMH_REPO_ROOT}/cases/run/${CASE}"

if [[ ! -d "${CASE_DIR}" ]]; then
  echo "Case not found: ${CASE_DIR}"
  exit 1
fi

rm -rf "${CASE_DIR}/0"
mmh_ensure_case_initial_fields "${CASE_DIR}"

echo "Restored: ${CASE_DIR}/0/"
ls -1 "${CASE_DIR}/0"
