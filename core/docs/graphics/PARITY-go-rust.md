# nextpas.core.graphics 质量对标 — 超越 Go/Rust

> **不是追平，是 Pascal 的惊艳超越。** 锁版本 `Go 1.22 / Rust tiny-skia 0.11 / image 0.25`，Bench 冻结 `nextpas.core.bench`。

## 超越柱状图（预演，S2 实测补实线）

```
FillPath 100x100        ████ 350ns (nextpas 目标)  vs  ████████████ 1200ns (Go)  vs  ██████ 600ns (tiny-skia)
Decode 1MB PNG          █████ 800µs vs  ███████████ 2100µs vs  ██████ 1100µs
DrawBitmap 256x256      ████ 400ns vs  █████████ 900ns vs  █████ 550ns
```

*单次调用不内循环，`-O2`，`ns/op + MB/s`，`bench --verify`。*

## 六维超越

| 维 | Go 痛点 | Rust 痛点 | nextpas 惊艳 |
|---|---|---|---|
| 模块化 | `image` 单包泥球 | 单 crate | L1 三子模块(≤800) + L2 四能力 + `document` 外置 `packages/` |
| 性能 | 无 tiled/simd/Stride | 无 Stride 对齐 | `Stride 64B + Tile16x16 + simd + Single外/Double内` |
| 高级感 | `draw.Draw` 命令式 | `PathBuilder` 可变 | `TPath` 不可变链 + `TBrush.WithTransform/WithOpacity` 流式 + RAII |
| 复用度 | 图像/文本割裂 | `text` 另起炉灶 | `Grapheme→Glyph→GlyphRun→canvas` 四段复用，`TAtlas/ScaleFactor` 通 `window` |
| 稳定性 | `error` 不分类 | `Result` 单轨 | `EGraphicsError` 五子类 + `Try` 双形态 + `fuzz` + `source-contract` |
| 完整性 | 无矢量/滤镜图 | 无序列化 | `Path布尔/EffectGraph序列化/ColorConvert P3/SvgImport预留` 闭环 |

## API 对标

| 能力 | Go | Rust | nextpas |
|---|---|---|---|
| 几何 | `Rectangle` | `IntRect/Transform` | `TRect/TMat2D` 值类型 |
| 路径 | 无 | `PathBuilder` 堆 | `TPath.New.MoveTo.Cubic.Close` 不可变链 + `PathUnion/Stroke` |
| 画布 | `draw.Draw` | `fill_path` | `ICanvas.FillPath/Stroke/Clip/DrawBitmap/DrawGlyphRun` |
| 渐变 | 无 | `LinearGradient` | `TGradient.WithTransform` + `TBrush` 流式 |
| 编解码 | `png.Decode` | `image::load` | `ImageDecode/TryImageDecode(ImageFormat)` |
| 滤镜 | 无 | `FilterQuality` | `EffectGraph(Blur/Shadow/Hue/LUT) + Bake并行` |

## 暂缺反哺项（S1 审计 `examples/tools`）

- `grep -r "FPImage\|Graphics" core/examples core/tools` 零命中已验（`image.png` 纯 Pascal）；有则逐项登记并在 S1 反哺进 `image/effect/vector`。

## Bench 门禁

- `benchmarks/nextpas.core.canvas/bench_raster` + `bench_image`，`TBenchSuite` 模板，`bench --verify-go-rust`，禁手搓 `GetTickCount64`，校准/统计/异常值由框架统一。
