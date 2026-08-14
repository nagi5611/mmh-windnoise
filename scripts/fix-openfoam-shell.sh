#!/usr/bin/env bash
# OpenFOAM シェル環境の修復（ZSH_NAME unbound variable 対策）
# OpenFOAM インストール済みで setup が途中失敗した場合に使う
if [ -z "${BASH_VERSION:-}" ]; then
  exec /usr/bin/env bash "$0" "$@"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OPENFOAM_BASHRC="/opt/openfoam13/etc/bashrc"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/env.sh"

[[ -f "${OPENFOAM_BASHRC}" ]] || {
  echo "ERROR: OpenFOAM が見つかりません: ${OPENFOAM_BASHRC}" >&2
  echo "先に: sudo apt install openfoam13" >&2
  exit 1
}

echo "[fix-openfoam-shell] ~/.bashrc / ~/.zshrc を修復"
mmh_append_openfoam_profile "${HOME}/.bashrc" "${OPENFOAM_BASHRC}" "${REPO_ROOT}"
if [[ -f "${HOME}/.zshrc" ]]; then
  mmh_append_openfoam_profile "${HOME}/.zshrc" "${OPENFOAM_BASHRC}" "${REPO_ROOT}"
fi

echo "[fix-openfoam-shell] OpenFOAM 環境を読み込み"
mmh_source_openfoam_file "${OPENFOAM_BASHRC}"
export MMH_OPENFOAM_LOADED=1

simpleFoam -help >/dev/null
blockMesh -help >/dev/null

cat <<EOF

============================================================
  OpenFOAM シェル修復完了
============================================================

次を実行:

  source ~/.bashrc    # bash
  # または
  source ~/.zshrc     # zsh

  cd ${REPO_ROOT}
  python3 scripts/generate_cases.py
  make mesh CASE=psi000_U010

============================================================
EOF
