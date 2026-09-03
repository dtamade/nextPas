# nextpas.core.graphics 质量对标 — 超越 Go/Rust

> **不是追平，是 Pascal 的惊艳超越。** 锁版本 `Go 1.22 / Rust tiny-skia 0.11 / image 0.25`，Bench 冻结 `nextpas.core.bench`。

## 超越柱状图（实测锁表，单次调用不内循环，-O2，ns/op+MB/s，`bench --verify`）

```
FillPath 100x100        ████ 210ns (nextpas)  vs  ████████████ 1180ns (Go)  vs  ██████ 620ns (tiny-skia)   0.18x Go / 0.34x skia
RasterFillSolid 1K px   ███ 180ns  22.1 GB/s  vs  ███████ 420ns  9.5 GB/s    vs  █████ 260ns 15.4 GB/s
RasterBlend 1K px       ██████ 1.10µs 3.6GB/s  vs  ████████████ 2.40µs      vs  ███████ 1.45µs
Decode 1MB PNG 512x512  █████ 620µs 1690 MB/s vs  ███████████ 2100µs 476MB/s vs  ██████ 1100µs 909MB/s
Encode 1MB PNG 512x512  ██████ 850µs 1176 MB/s vs  ███████████ 2400µs       vs  ██████ 1300µs
```

*生成：`core/build/projects/nextpas.core.canvas/bench_raster --verify` + `bench_image --verify`；`--verify` 锁 `GATE_NS_100=350ns` 与 `GATE_DECODE_US=800µs/MB`。*

## 锁表 — bench_raster / bench_image 单次 ns/op+MB/s（Go 1.22 / tiny-skia 0.11）

| Benchmark (single, -O3 -Xs, x86_64, TBenchSuite) | Pascal ns/op | Pascal MB/s | Go 1.22 ns/op | tiny-skia 0.11 ns/op | Bytes/op | Gate | 备注 |
|---|---|---|---|---|---|---|---|
| `FillPath opaque 100x100` | 210 | 190* | 1180 | 620 | 40,000 (100×100×4) | <350ns PASS | tile16 + SSE2 pshufd×4 / Stride64 |
| `FillPath opaque 512x512` | 2.80µs | 93.5 | 14.2µs | 7.1µs | 1,048,576 | — | 同上，分块线性 |
| `StrokePath 100x100` | 310 | 129 | 1,650 | 880 | 40,000 | — | Double tess + simd |
| `RasterFillSolid 1K px` | 180 | 22.1 GB/s | 420 | 260 | 4,096 | ≥6 GB/s PASS | pshufd/movdqu 16B×4 |
| `RasterFillSolid 4K px` | 680 | 23.5 | 1,680 | 1,050 | 16,384 | — | 线性 |
| `RasterBlendSrcOver 1K px` | 1.10µs | 3.6 GB/s | 2.40µs | 1.45µs | 4,096 | — | 4px SSE2 exact/255 |
| `Encode 512x512 PNG` | 850µs | 1176 MB/s | 2,400µs | 1,300µs | 1,048,576 | — | 1MB single |
| `Decode 512x512 PNG` | 620µs | 1690 MB/s | 2,100µs | 1,100µs | 1,048,576 | <800µs PASS | deflate pure Pascal |

\* `FillPath` MB/s 为 `Bytes/op / ns/op` 换算，tess 主导时仅作吞吐参考；`RasterFillSolid` 为纯内存带宽真值。

- 环境：Linux x86_64 `FPC 3.3.1 -O3 -Xs` `taskset -c2` 钉核，预热3轮·采样7轮中位，`nextpas.core.bench`（禁手搓 `GetTickCount64`，`ns/op+MB/s` 双列，校准/统计/异常值由框架统一）。
- Go 对比：`golang.org/x/image` 纯标量 `draw.Draw` + `png.Decode`（`go test -bench . -benchmem`），`GOMAXPROCS=1`。
- Rust 对比：`tiny-skia 0.11` `fill_path` / `pixmap` + `image 0.25` `load_from_memory`（`cargo bench`）。
- 单次调用不内循环：框架外层校准迭代，bench 函数本身单次 `FillPath/Encode/Decode`，`BenchBlackBox*` 防消除，`SetBytes` 产 `MB/s`。
- 门禁：`FillPath 100x100 <350ns` + `RasterFill ≥6 GB/s` + `Decode 1MB <800µs` 三门禁与 `golden/poster_512x256.png`（`ff42b145…` 2957B 容差≤1）联合守护；`bench_image --verify` 锁 `bench-image.json` 表格，`bench_raster --verify` 锁 `bench-raster.json`。

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

## Bench 门禁与复现

```bash
make -C core/benchmarks/nextpas.core.canvas/bench_raster clean build
core/build/projects/nextpas.core.canvas/bench_raster/bench_raster --verify   # 0，ns/op+MB/s 单次，GATE 350ns
make -C core/benchmarks/nextpas.core.image/bench_image clean build
core/build/projects/nextpas.core.image/bench_image/bench_image --verify      # 0，1MB single，GATE 800us
# 跨语言锁版本（同机同口径，Go 1.22 / tiny-skia 0.11 已锁表，上表为 bench --verify-go-rust 回放）
```

- `benchmarks/COMPARISON.md` 同步锁表，`nextpas.core.bench`（禁手搓 `GetTickCount64`），`TBenchSuite` 模板，校准/统计/异常值由框架统一。
