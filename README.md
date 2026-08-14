# mmh-windnoise

人頭モデル（Super Average Head）への定常風に対する **圧力場** を OpenFOAM で計算するリポジトリ。

## 計算マトリクス

| パラメータ | 値 |
|-----------|-----|
| 顔の向き（ヨー） | 0°, 90°, 180°, 270° |
| 風速 | 0.0〜5.0 m/s（0.5 m/s 刻み） |
| **合計** | **44 ケース** |
| 物理時間 | 10 s（`pimpleFoam`） |
| ソルバー | `pimpleFoam` + `kOmegaSST`（推奨） |

詳細は [docs/conditions.md](docs/conditions.md) を参照。

## 前提環境

- Docker Desktop（Windows + WSL2 でも可）
- ローカル PC: Ryzen 9 8940HX / 32 GB RAM
- GPU（RTX 5070）は **OpenFOAM では未使用**

## クイックスタート

```bash
git clone https://github.com/nagi5611/mmh-windnoise.git
cd mmh-windnoise

# 1. ケース生成（44 通り）
python3 scripts/generate_cases.py

# 2. OpenFOAM コンテナに入る
make shell
# または: docker compose run --rm openfoam bash

# 3. 1 ケースでメッシュ確認
make mesh CASE=psi000_U010

# 4-A. 定常で全ケース（高速スクリーニング、推奨まずここ）
make run-steady

# 4-B. 非定常 10 s で全ケース（時間かかる）
make run-transient

# 5. VTK 出力 → ParaView で開く
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
