# scripts/lib/env.sh — リポジトリルートと OpenFOAM 環境を読み込む

# shellcheck disable=SC2034
MMH_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# OpenFOAM の bashrc は ZSH_NAME 等の未定義変数を参照するため、
# set -u 有効時は一時的に無効化してから source する
mmh_source_openfoam_file() {
  local rc="$1"
  set +u
  # shellcheck disable=SC1090
  source "${rc}"
}

mmh_remove_openfoam_profile_block() {
  local profile_file="$1"
  local marker="# mmh-windnoise OpenFOAM"
  [[ -f "${profile_file}" ]] || return 0
  if grep -qF "${marker}" "${profile_file}"; then
    sed -i "/${marker}/,\$d" "${profile_file}"
  fi
  # 以前の壊れた1行 source だけが残っている場合
  if grep -qF 'OPENFOAM_BASHRC' "${profile_file}" && grep -qF '/opt/openfoam13/etc/bashrc' "${profile_file}"; then
    sed -i '\|/opt/openfoam13/etc/bashrc|d' "${profile_file}"
    sed -i '\|OPENFOAM_BASHRC|d' "${profile_file}"
  fi
}

mmh_append_openfoam_profile() {
  local profile_file="$1"
  local openfoam_bashrc="$2"
  local repo_root="$3"
  local marker="# mmh-windnoise OpenFOAM"

  mmh_remove_openfoam_profile_block "${profile_file}"
  touch "${profile_file}"

  if [[ "${profile_file}" == *zshrc ]]; then
    cat >>"${profile_file}" <<EOF

${marker}
export OPENFOAM_BASHRC="${openfoam_bashrc}"
. "\${OPENFOAM_BASHRC}"
export MMH_REPO_ROOT="${repo_root}"
EOF
  else
    cat >>"${profile_file}" <<EOF

${marker}
export OPENFOAM_BASHRC="${openfoam_bashrc}"
set +u
. "\${OPENFOAM_BASHRC}"
export MMH_REPO_ROOT="${repo_root}"
EOF
  fi
}

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
    mmh_source_openfoam_file "${rc}"
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
