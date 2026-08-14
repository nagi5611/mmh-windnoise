# scripts/lib/env.sh — リポジトリルートと OpenFOAM 環境を読み込む

# shellcheck disable=SC2034
MMH_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

mmh_source_openfoam() {
  if [[ -n "${MMH_OPENFOAM_LOADED:-}" ]]; then
    return 0
  fi

  local candidates=(
    "${OPENFOAM_BASHRC:-}"
    /opt/openfoam13/etc/bashrc
    /usr/lib/openfoam/openfoam2412/etc/bashrc
    /usr/lib/openfoam/openfoam2406/etc/bashrc
    /usr/lib/openfoam/openfoam2312/etc/bashrc
  )

  local rc
  for rc in "${candidates[@]}"; do
    [[ -n "${rc}" && -f "${rc}" ]] || continue
    # shellcheck disable=SC1090
    source "${rc}"
    export OPENFOAM_BASHRC="${rc}"
    export MMH_OPENFOAM_LOADED=1
    return 0
  done

  echo "ERROR: OpenFOAM が見つかりません。先に ./scripts/setup-native.sh を実行してください。" >&2
  return 1
}

mmh_require_openfoam() {
  mmh_source_openfoam || exit 1
  command -v blockMesh >/dev/null 2>&1 || {
    echo "ERROR: blockMesh が PATH にありません。OpenFOAM 環境を確認してください。" >&2
    exit 1
  }
}
