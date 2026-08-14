#!/usr/bin/env bash
# Ubuntu Server 24.04 (noble) 向けネイティブ OpenFOAM セットアップ
# 使い方: ./scripts/setup-native.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_PARAVIEW=0
SKIP_CASES=0
VERIFY_MESH=0

usage() {
  cat <<'EOF'
Usage: ./scripts/setup-native.sh [options]

  Ubuntu Server 24.04 に OpenFOAM (Foundation v13) を入れ、
  このリポジトリの計算準備まで完了します。

Options:
  --with-paraview   ParaView もインストール（GUI 環境向け）
  --skip-cases      44 ケース生成をスキップ
  --verify-mesh     セットアップ後に psi000_U010 でメッシュ生成テスト
  -h, --help        このヘルプ

例:
  ./scripts/setup-native.sh
  ./scripts/setup-native.sh --verify-mesh
EOF
}

log() { printf '\n[mmh-setup] %s\n' "$*"; }
die() { echo "[mmh-setup] ERROR: $*" >&2; exit 1; }

for arg in "$@"; do
  case "${arg}" in
    --with-paraview) INSTALL_PARAVIEW=1 ;;
    --skip-cases) SKIP_CASES=1 ;;
    --verify-mesh) VERIFY_MESH=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "不明なオプション: ${arg}" ;;
  esac
done

if [[ "$(id -u)" -eq 0 ]]; then
  die "root ではなく通常ユーザーで実行してください（内部で sudo を使います）"
fi

if ! command -v sudo >/dev/null 2>&1; then
  die "sudo が必要です"
fi

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  log "OS: ${PRETTY_NAME:-unknown}"
  if [[ "${VERSION_ID:-}" != "24.04" ]]; then
    echo "警告: Ubuntu 24.04 向けです。${VERSION_ID:-unknown} では動作未確認です。" >&2
  fi
else
  echo "警告: /etc/os-release を読めません。Ubuntu 24.04 以外は未確認です。" >&2
fi

log "基本パッケージをインストール"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates \
  curl \
  git \
  make \
  python3 \
  software-properties-common \
  wget

if ! apt-cache show openfoam13 >/dev/null 2>&1; then
  log "OpenFOAM リポジトリを追加"
  sudo add-apt-repository -y "http://dl.openfoam.org/ubuntu main dev"
  sudo apt-get update
fi

log "OpenFOAM 13 をインストール"
if [[ "${INSTALL_PARAVIEW}" -eq 1 ]]; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openfoam13
else
  # Server 向け: ParaView 推奨パッケージは入れない
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends openfoam13
fi

OPENFOAM_BASHRC="/opt/openfoam13/etc/bashrc"
[[ -f "${OPENFOAM_BASHRC}" ]] || die "OpenFOAM の bashrc が見つかりません: ${OPENFOAM_BASHRC}"

MARKER="# mmh-windnoise OpenFOAM"
PROFILE_FILE="${HOME}/.bashrc"
if ! grep -qF "${MARKER}" "${PROFILE_FILE}" 2>/dev/null; then
  log "シェル設定に OpenFOAM 環境を追加 (~/.bashrc)"
  cat >>"${PROFILE_FILE}" <<EOF

${MARKER}
export OPENFOAM_BASHRC="${OPENFOAM_BASHRC}"
source "\${OPENFOAM_BASHRC}"
export MMH_REPO_ROOT="${REPO_ROOT}"
EOF
fi

# 現在のシェルでも使えるようにする
# shellcheck disable=SC1090
source "${OPENFOAM_BASHRC}"
export MMH_OPENFOAM_LOADED=1

log "OpenFOAM 動作確認"
simpleFoam -help >/dev/null
blockMesh -help >/dev/null
python3 --version

if [[ "${SKIP_CASES}" -eq 0 ]]; then
  log "44 ケースを生成"
  python3 "${REPO_ROOT}/scripts/generate_cases.py"
else
  log "ケース生成はスキップ (--skip-cases)"
fi

if [[ "${VERIFY_MESH}" -eq 1 ]]; then
  log "テストメッシュ生成: psi000_U010"
  bash "${REPO_ROOT}/scripts/mesh_case.sh" psi000_U010
fi

cat <<EOF

============================================================
  mmh-windnoise セットアップ完了
============================================================

リポジトリ : ${REPO_ROOT}
OpenFOAM   : ${OPENFOAM_BASHRC}

次のコマンド（新しいターミナルでは先に source ~/.bashrc）:

  cd ${REPO_ROOT}
  make help
  make mesh CASE=psi000_U010      # メッシュ確認
  make run-steady                 # 定常 44 ケース
  make run-transient              # 非定常 10 s
  make post                       # VTK 出力

VTK は別マシンの ParaView で開けます:
  postprocess/vtk/<ケース名>/VTK/

============================================================
EOF
