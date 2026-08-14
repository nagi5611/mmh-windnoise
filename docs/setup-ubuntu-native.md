# Ubuntu Server 24.04 ネイティブセットアップ

Docker なしで OpenFOAM を直接インストールし、計算まで進める手順です。

## 最短（セットアップ一式）

```bash
git clone https://github.com/nagi5611/mmh-windnoise.git
cd mmh-windnoise
git checkout cursor/head-wind-pressure-c2c2   # PR 未マージ時のみ

chmod +x scripts/setup-native.sh scripts/reset-openfoam-apt.sh
./scripts/setup-native.sh
```

これで以下が完了します。

| 項目 | 内容 |
|------|------|
| パッケージ | git, python3, make, curl など |
| OpenFOAM | Foundation **v13**（Ubuntu 24.04 noble 対応） |
| シェル設定 | `~/.bashrc` に OpenFOAM 環境を追記 |
| ケース | 44 通りを `cases/run/` に生成 |

終了時に **「セットアップ完了」** と表示されれば OK です。

## オプション

```bash
# メッシュ生成まで動作確認したい場合（10〜30分かかることがあります）
./scripts/setup-native.sh --verify-mesh

# ParaView も入れる（デスクトップ Ubuntu 向け）
./scripts/setup-native.sh --with-paraview

# OpenFOAM だけ入れてケース生成は後で
./scripts/setup-native.sh --skip-cases
```

## セットアップ後の計算フロー

```bash
# 新しいターミナルなら（初回のみ）
source ~/.bashrc

cd mmh-windnoise

# 1. メッシュ確認（1ケース）
make mesh CASE=psi000_U010

# 2. 定常計算（44ケース、推奨・まずここ）
make run-steady

# 3. VTK 出力
make post
```

非定常 10 s（時間がかかる）:

```bash
make run-transient
```

## 結果の見方

- 計算ログ: `cases/run/<ケース名>/log.simpleFoam` など
- VTK: `postprocess/vtk/<ケース名>/VTK/`
- Server に GUI がなければ、VTK を手元 PC の ParaView にコピーして開く

```bash
# 例: 手元 PC へコピー
scp -r user@server:~/mmh-windnoise/postprocess/vtk/psi000_U010 ./
```

## 前提

| 項目 | 要件 |
|------|------|
| OS | Ubuntu Server **24.04 LTS** (noble) |
| RAM | 16 GB 以上（32 GB 推奨） |
| ディスク | 空き 30 GB 以上推奨 |
| GPU | 不要（OpenFOAM は CPU 計算） |
| 権限 | `sudo` 可能なユーザー |

## トラブルシュート

### `OpenFOAM が見つかりません`

```bash
source /opt/openfoam13/etc/bashrc
# または
source ~/.bashrc
```

### `add-apt-repository` で失敗

```bash
sudo apt-get install -y software-properties-common
```

### `set: Illegal option -o pipefail`

`sh` や `sudo sh` で実行しています。`dash` では動きません。

```bash
# 正しい
./scripts/setup-native.sh

# 間違い
sh scripts/setup-native.sh
sudo sh scripts/setup-native.sh
```

### `NO_PUBKEY 6C0DAC728B29D817` / repository is not signed

OpenFOAM の GPG 鍵が未登録、または壊れた設定が残っています。

```bash
./scripts/reset-openfoam-apt.sh
./scripts/setup-native.sh
```

手動で直す場合:

```bash
wget -qO- https://dl.openfoam.org/gpg.key | sudo tee /etc/apt/trusted.gpg.d/openfoam.asc >/dev/null
sudo rm -f /etc/apt/sources.list.d/*dl_openfoam_org*list
sudo add-apt-repository "http://dl.openfoam.org/ubuntu main dev"
sudo apt update
```

### snappyHexMesh が失敗

```bash
tail -50 cases/run/psi000_U010/log.snappyHexMesh
```

メモリ不足の場合は他のプロセスを止めるか、`cases/template/system/snappyHexMeshDict` の `maxGlobalCells` を下げる。

## OpenFOAM のバージョンについて

Ubuntu 24.04 では **OpenFOAM Foundation v13**（`openfoam13` パッケージ）を使用します。

出典: [OpenFOAM v13 Ubuntu インストール](https://openfoam.org/download/13-ubuntu/)

Docker 版（`opencfd/openfoam-default:2312`）とはメジャーバージョンが異なりますが、本リポジトリのケース設定は両方で動く想定です。
