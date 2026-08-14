# mmh-windnoise

人頭モデル（Super Average Head）への定常風に対する **圧力場** を OpenFOAM で計算するリポジトリ。

## 計算マトリクス

| パラメータ | 値 |
|-----------|-----|
| 顔の向き（ヨー ψ） | 0°=**正面風**, 90°=左横顔, 180°=背面, 270°=右横顔 |
| 風速 | 0.0〜5.0 m/s（0.5 m/s 刻み）、流向 +X |
| **合計** | **44 ケース** |
| 物理時間 | 10 s（`pimpleFoam`） |
| ソルバー | `pimpleFoam` + `kOmegaSST`（推奨） |

詳細は [docs/conditions.md](docs/conditions.md) を参照。

## 前提環境

### 推奨: Ubuntu Server 24.04 ネイティブ（Docker 不要）

```bash
git clone https://github.com/nagi5611/mmh-windnoise.git
cd mmh-windnoise
  ./scripts/setup-native.sh    # これでセットアップ完了

# GPG / apt エラー時
./scripts/reset-openfoam-apt.sh
```

詳細: [docs/setup-ubuntu-native.md](docs/setup-ubuntu-native.md)

| 項目 | 要件 |
|------|------|
| OS | Ubuntu Server 24.04 LTS |
| RAM | 32 GB 推奨 |
| GPU | 不要（OpenFOAM は CPU 計算） |

### 任意: Docker

- Docker Desktop（Windows + WSL2 でも可）
- `docker compose` + `make docker-shell`

## クイックスタート（ネイティブ Linux）

```bash
# 初回のみ
./scripts/setup-native.sh

# 計算
source ~/.bashrc
make mesh CASE=psi000_U010
make run-steady
make post
```

## クイックスタート（Docker）

```bash
docker compose pull
make docker-shell
make mesh CASE=psi000_U010
make run-steady
make post
```

## ParaView で圧力＋矢印を表示

1. `postprocess/vtk/<ケース名>/` 内の `.vtp` / `.vtk` を開く
2. 頭表面パッチ `head` を選択
3. **Coloring:** `p` または `pMean`
4. **Filter → Glyph:**
   - Orientation: `U` または `Normals`
   - Coloring: `p`
   - Scale: 適宜調整

詳細: [docs/paraview.md](docs/paraview.md)

## ディレクトリ構成

```
models/                  # 頭 STL
cases/template/          # OpenFOAM テンプレート
cases/run/               # 生成された 44 ケース
scripts/                 # 生成・実行・後処理
docs/                    # 条件定義・可視化手順
postprocess/vtk/         # VTK 出力
```

## 推奨ワークフロー（ノート PC）

1. **Phase A:** `simpleFoam` で 44 ケース → 平均圧力場を確認（数時間）
2. **Phase B:** 代表ケースのみ `pimpleFoam` 10 s（必要な向き・風速）
3. **Phase C:** 周波数解析（将来、`noise` ユーティリティ or Python FFT）

## ライセンス

MIT
