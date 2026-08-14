# ParaView 可視化手順 — 圧力＋色付き矢印

## 入力データ

| ソース | パス | 内容 |
|--------|------|------|
| VTK（体積） | `postprocess/vtk/<case>/VTK/` | 圧力 p、速度 U |
| 表面サンプル | `cases/run/<case>/postProcessing/surfaces/` | 頭表面の p, U 時系列 |

## 手順 A: 頭表面の圧力カラー

1. ParaView を起動
2. **File → Open** → `postprocess/vtk/psi000_U010/VTK/` を選択
3. タイムステップを最新（または `pMean` がある場合はそれ）に設定
4. **Apply**
5. **Coloring** を `p` または `pMean` に変更
6. カラーマップを **Cool to Warm** などに設定

## 手順 B: 圧力で色付けした矢印（Glyph）

1. 上記のデータを読み込んだ状態で、フィルタを追加:

```
Filters → Common → Glyph
```

2. 設定:

| 項目 | 値 |
|------|-----|
| Glyph Type | Arrow |
| Orientation | `U`（速度ベクトル） |
| Scale Array | `U` または `mag(U)` |
| Scale Factor | 0.01〜0.05（見やすく調整） |
| Coloring | `p` |

3. **Apply** → 頭表面に「圧力の色が付いた速度矢印」が表示される

## 手順 C: 圧力勾配ベクトル（代替）

圧力の「ベクトル」として勾配を見たい場合:

1. **Filters → Alphabetical → Calculator**
2. 式: `grad(p)` は直接不可のため、**Generate Surface Normals** 後に
3. **Filters → Alphabetical → Gradient Of Unstructured DataSet**
   - Scalar Array: `p`
4. 結果の `Gradients` を Glyph の Orientation に使用
5. Coloring: `p`

## 複数ケースの比較

- ヨー角・風速ごとに ParaView の **Layout** で並べて表示
- アニメーション: タイムステップをスライドして非定常圧力の変動を確認

## 出力画像

**File → Save Screenshot** で PNG 出力。

バッチ処理が必要なら `pvpython` スクリプト化も可能（将来追加予定）。
