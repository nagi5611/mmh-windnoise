# scripts/lib/env.sh — リポジトリルートと OpenFOAM 環境を読み込む

# shellcheck disable=SC2034
MMH_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# OpenFOAM の bashrc は ZSH_NAME 等の未定義変数を参照するため、
# set -u 有効時は一時的に無効化してから source する
mmh_source_openfoam_file() {
  local rc="$1"
  # OpenFOAM bashrc は ZSH_NAME 参照・ParaView の head パイプ・bash_completion で
  # 非対話シェルが落ちるため、source 中だけ緩める
  set +eu
  unset BASH
  # shellcheck disable=SC1090
  source "${rc}"
  set -e
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

# 並列再実行用: processor* と結果時刻を削除（初期条件 0/ は残す）
mmh_clean_case_solver_state() {
  local case_dir="${1:?case_dir required}"
  (
    cd "${case_dir}"
    rm -rf processor* postProcessing 2>/dev/null || true
    shopt -s nullglob
    for d in [1-9]* [0-9][0-9]* 0.[0-9]*; do
      [[ -d "${d}" ]] && rm -rf "${d}"
    done
  )
}

# 0/ が欠けていたらテンプレートから復元（ケース名の U### から風速を設定）
mmh_ensure_case_initial_fields() {
  local case_dir="${1:?case_dir required}"
  local case_name
  case_name="$(basename "${case_dir}")"
  local f
  local missing=0

  for f in p U k omega nut; do
    if [[ ! -f "${case_dir}/0/${f}" ]]; then
      missing=1
      break
    fi
  done

  if [[ "${missing}" -eq 0 ]]; then
    return 0
  fi

  echo "WARNING: ${case_dir}/0/ が不完全なためテンプレートから復元します" >&2
  rm -rf "${case_dir}/0"
  cp -r "${MMH_REPO_ROOT}/cases/template/0" "${case_dir}/0"

  if [[ "${case_name}" =~ _U([0-9]+)$ ]]; then
    local u_tag="${BASH_REMATCH[1]}"
    local u_val
    u_val="$(awk "BEGIN {printf \"%.6f\", ${u_tag}/10}")"
    sed -i "s/__U_INF__/${u_val}/g" "${case_dir}/0/U"
  else
    echo "ERROR: ケース名から風速を読めません: ${case_name}" >&2
    return 1
  fi
}

# decomposePar 前後の並列ディレクトリを整える
mmh_decompose_case() {
  local case_dir="${1:?case_dir required}"
  local np="${2:?np required}"
  local log_tag="${3:-decomposePar}"

  mmh_ensure_case_initial_fields "${case_dir}"
  mmh_clean_case_solver_state "${case_dir}"

  (
    cd "${case_dir}"
    foamDictionary system/decomposeParDict -entry numberOfSubdomains -set "${np}"
    decomposePar -force | tee "log.${log_tag}"

    local f
    for f in p U k omega nut; do
      if [[ ! -f "processor0/0/${f}" ]]; then
        echo "ERROR: decomposePar 後に processor0/0/${f} がありません。" >&2
        echo "  ルート 0/${f}: $(test -f "0/${f}" && echo OK || echo MISSING)" >&2
        echo "  対処: bash scripts/restore_case_ic.sh $(basename "${case_dir}")" >&2
        echo "        rm -rf processor* && make run-both CASE=$(basename "${case_dir}") NP=${np}" >&2
        return 1
      fi
    done
  )
}

# 同一ヨー角の別風速ケースからメッシュを流用（幾何は同じ）
mmh_ensure_case_mesh() {
  local case_dir="${1:?case_dir required}"
  local case_name run_dir yaw donor_mesh donor_case

  if [[ -f "${case_dir}/constant/polyMesh/points" ]]; then
    return 0
  fi

  case_name="$(basename "${case_dir}")"
  run_dir="$(dirname "${case_dir}")"
  yaw="${case_name%%_*}"

  shopt -s nullglob
  for donor_mesh in "${run_dir}/${yaw}"_U*/constant/polyMesh/points; do
    [[ -f "${donor_mesh}" ]] || continue
    donor_case="$(basename "$(dirname "$(dirname "$(dirname "${donor_mesh}")")")")"
    [[ "${donor_case}" == "${case_name}" ]] && continue
    echo "INFO: メッシュを流用: ${donor_case} -> ${case_name}"
    rm -rf "${case_dir}/constant/polyMesh"
    mkdir -p "${case_dir}/constant"
    cp -a "$(dirname "${donor_mesh}")" "${case_dir}/constant/"
    return 0
  done

  return 1
}

mmh_configure_steady_control() {
  local case_dir="${1:?case_dir required}"
  local ctrl="${case_dir}/system/controlDict"

  if [[ ! -f "${ctrl}.transient.bak" ]]; then
    cp "${ctrl}" "${ctrl}.transient.bak"
  fi

  foamDictionary "${ctrl}" -entry application -set simpleFoam
  foamDictionary "${ctrl}" -entry endTime -set 2000
  foamDictionary "${ctrl}" -entry deltaT -set 1
  foamDictionary "${ctrl}" -entry writeInterval -set 2000
  foamDictionary "${ctrl}" -entry writeControl -set timeStep
  foamDictionary "${ctrl}" -entry adjustTimeStep -set false
}

mmh_mpi_run() {
  local np="${1:?np required}"
  shift
  local extra=()

  if [[ "${np}" -gt "$(nproc)" ]]; then
    echo "WARNING: NP=${np} > $(nproc) コア。mpirun --oversubscribe を使用します。" >&2
    extra+=(--oversubscribe)
  fi

  mpirun "${extra[@]}" -np "${np}" "$@"
}
