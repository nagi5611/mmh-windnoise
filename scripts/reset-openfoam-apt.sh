#!/usr/bin/env bash
# OpenFOAM apt リポジトリと GPG 鍵を完全リセットして再設定する
# 使い方: ./scripts/reset-openfoam-apt.sh
if [ -z "${BASH_VERSION:-}" ]; then
  exec /usr/bin/env bash "$0" "$@"
fi

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/reset-openfoam-apt.sh [options]

  OpenFOAM (dl.openfoam.org) の apt / GPG 設定を削除し、
  公式手順どおりに再登録します。

  NO_PUBKEY / repository is not signed などの修復用。

Options:
  --purge-package   openfoam13 パッケージもアンインストールする
  --no-update       最後の apt update をスキップ
  -h, --help        このヘルプ

例:
  ./scripts/reset-openfoam-apt.sh
  ./scripts/reset-openfoam-apt.sh --purge-package
EOF
}

log() { printf '[reset-openfoam] %s\n' "$*"; }
die() { echo "[reset-openfoam] ERROR: $*" >&2; exit 1; }

PURGE_PACKAGE=0
SKIP_UPDATE=0

for arg in "$@"; do
  case "${arg}" in
    --purge-package) PURGE_PACKAGE=1 ;;
    --no-update) SKIP_UPDATE=1 ;;
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

download_gpg_key() {
  local dest="/etc/apt/trusted.gpg.d/openfoam.asc"
  sudo mkdir -p /etc/apt/trusted.gpg.d

  log "GPG 鍵を取得: https://dl.openfoam.org/gpg.key"
  if command -v wget >/dev/null 2>&1; then
    wget -qO- https://dl.openfoam.org/gpg.key | sudo tee "${dest}" >/dev/null
  elif command -v curl >/dev/null 2>&1; then
    curl -fsSL https://dl.openfoam.org/gpg.key | sudo tee "${dest}" >/dev/null
  else
    die "wget または curl が必要です。先に sudo apt install wget を実行してください"
  fi

  sudo chmod 644 "${dest}"
  [[ -s "${dest}" ]] || die "GPG 鍵ファイルが空です: ${dest}"
}

remove_openfoam_apt_config() {
  log "OpenFOAM apt ソースリストを削除"

  # add-apt-repository が作るファイル
  sudo rm -f /etc/apt/sources.list.d/*dl_openfoam_org*list 2>/dev/null || true
  sudo rm -f /etc/apt/sources.list.d/openfoam*.list 2>/dev/null || true

  # 古い形式の設定が sources.list に直書きされている場合
  if [[ -f /etc/apt/sources.list ]]; then
    if grep -q "dl.openfoam.org" /etc/apt/sources.list 2>/dev/null; then
      log "/etc/apt/sources.list から dl.openfoam.org 行をコメントアウト"
      sudo sed -i '/dl\.openfoam\.org/s/^/# mmh-reset /' /etc/apt/sources.list
    fi
  fi

  log "OpenFOAM 関連 GPG 鍵ファイルを削除"
  sudo rm -f \
    /etc/apt/trusted.gpg.d/openfoam.asc \
    /etc/apt/trusted.gpg.d/openfoam.gpg \
    /etc/apt/keyrings/openfoam.gpg \
    /usr/share/keyrings/openfoam.gpg 2>/dev/null || true

  # 古い apt-key 登録（残っていれば）
  if command -v apt-key >/dev/null 2>&1; then
  OPENFOAM_KEY_IDS=("6C0DAC728B29D817" "518F1B72FCD217B6")
    for key_id in "${OPENFOAM_KEY_IDS[@]}"; do
      if apt-key list 2>/dev/null | grep -qi "${key_id}"; then
        log "apt-key から削除: ${key_id}"
        sudo apt-key del "${key_id}" 2>/dev/null || true
      fi
    done
  fi
}

add_openfoam_repo() {
  log "OpenFOAM リポジトリを再追加"
  if ! command -v add-apt-repository >/dev/null 2>&1; then
    die "add-apt-repository がありません: sudo apt install software-properties-common"
  fi
  sudo add-apt-repository -y "http://dl.openfoam.org/ubuntu main dev"
}

verify_apt() {
  log "apt update で検証"
  set +e
  local out
  out="$(sudo apt-get update 2>&1)"
  local rc=$?
  set -e

  if [[ "${rc}" -ne 0 ]]; then
    echo "${out}" >&2
    die "apt update に失敗しました。上記ログを確認してください"
  fi

  if echo "${out}" | grep -qE "NO_PUBKEY|not signed|GPG error"; then
    echo "${out}" >&2
    die "GPG エラーが残っています"
  fi

  log "apt update 成功"
}

main() {
  log "=== OpenFOAM apt / GPG 完全リセット開始 ==="

  if [[ "${PURGE_PACKAGE}" -eq 1 ]]; then
    if dpkg -l openfoam13 2>/dev/null | grep -q "^ii"; then
      log "openfoam13 をアンインストール"
      sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y openfoam13 || true
      sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y || true
    else
      log "openfoam13 はインストールされていません（スキップ）"
    fi
  fi

  remove_openfoam_apt_config
  download_gpg_key
  add_openfoam_repo

  if [[ "${SKIP_UPDATE}" -eq 0 ]]; then
    verify_apt
  fi

  cat <<'EOF'

============================================================
  OpenFOAM apt / GPG リセット完了
============================================================

次のコマンド:

  sudo apt install openfoam13
  ./scripts/setup-native.sh

または:

  source /opt/openfoam13/etc/bashrc
  simpleFoam -help

============================================================
EOF
}

main "$@"
