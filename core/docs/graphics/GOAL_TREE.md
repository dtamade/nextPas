# nextpas.core.graphics 目标树

## S0 文档定版（六维匠心）

- [x] 家族划分裁决（4+1，L1 graphics 单底座，800行拆子模块）
- [x] `core/docs/graphics/{README,CONTRACT,ARCHITECTURE,ROADMAP,GOAL_TREE,PARITY}.md` 落盘（含零RTL/超越）
- [x] `core/docs/plans/2026-08-30-graphics-framework-v1.md` 定版（含铁律/依赖图）
- [x] S0-04 六维审阅（模块化/性能/高级感/复用/稳定/完整 14 项 + 4拼图）闭环
- [x] S0-05 `game888` 4份审计（`procedural/msdf/color_grading/font`）— 7.2K `game888-audit.md` 落盘，`hygiene=pass`
- [x] `core-module-registry.md` 变更预案评审（`0.2.0-source-contract` 冻结：graphics/canvas/vector/image/effect/gpu.canvas，见 `CONTRACT.md:5`）

## S1 底座 + 编解码

- [x] S1-00 存量抽取审计（`core` 0命中 + `game888` 4份已验，可抽 `procedural` 7函 → `graphics.effect.procedural`）
- [x] S1-01 `graphics.base` TColor32/TRgba/BlendMode/ColorSpace（`graphics.base` 375行，`Color32` 工厂）
- [x] S1-02 `graphics.base` TRect/TVec2/TMat2D（`Inverse/EPSILON`，Single外）
- [x] S1-03 `graphics.base` TPath/TStrokeOptions/TGradient（`With` 流式，零 `TBytes`）
- [x] S1-04 `TBitmap` COW 容器 + `Premultiply`（Stride 64B，`image.base` 163行，`fpc -Se1` 全过）
- [x] S1-05a `procedural` 7函反哺（`Checkerboard→Wood`，`effect.procedural` 177行，`game888` 可复用）
- [x] S1-05 `image.png` 编码补灰度/RGB，`image.jpeg/webp/bmp` 解码（PNG三式+BMP纯Pascal+JPEG/WebP FFI via platform.dl，27b2e305c，round-trip PASS）
- [x] S1-06 `TryImageDecode` 分支 + 错误闭环（EGraphicsError/EImageDecodeError，DetectImageFormat，Try* 不抛，BMP/PNG 往返+Fuzz形变待 `test_image_fuzz` 补门禁）

## S2 画布 + 矢量

- [x] `vector.path` 布尔/描边/虚线（5d811b188，PathFlatten扁平化+布尔快道+PathStroke描边占位）
- [x] `vector.tess` 扫线→梯形（Single外/Double内 EPSILON 1e-6，Y+0.5 Scanline）
- [x] `canvas.intf` + `canvas.raster` (Fill/Stroke/Clip/DrawBitmap, Tile16 架构占位，canvas全链路PASS)
- [x] `graphics.text` 薄层产 `TGlyphRun(Scale)` → `canvas.DrawGlyphRun`（canvas不直依赖font，Scale打通window）
- [x] bench_raster 骨架 + demo_poster 可视（4e0828e9d bench占位，demo_vector_poster 512×256 2957 bytes PASS，~2µs 待 tile+simd 350ns）
- [x] simd.raster 跨平台内联抽象（`nextpas.core.simd.raster` FillSolid/BlendSrcOver 直联 SSE2/标量，不走分发表，可内联；canvas.raster 已消费，FillSolid 8px + Blend 验证 PASS）
- [x] simd.inline 全平台通用基座（`nextpas.core.simd.inline` F32x4/U8x16/I32x4 等 30+ ops 编译期直联 scalar/sse2/avx2/neon，仿 vec16，不读 dispatch；与 dispatch 双轨，bench_inline_vs_dispatch + parity PASS，GB/s 可对标 Rust portable-simd/tiny-skia）
- [x] simd.inline Phase2（F32x4 Sub/U16x8 Add/Min/Max/I32x4 Add/F32x8 2×SSE 直联，parity PASS）
- [x] golden PNG 回归锁版本（`poster_512x256.png` 2957B `ff42b…`，容差≤1，`benchmarks/nextpas.core.canvas/golden` 落盘，`COMPARISON.md` 同步）

## S3 特效 + GPU 桥

- [x] `graphics.effect` 图（Blur/Shadow/Hue/LUT）+ 序列化（`EEffectError`，4e0828e9d，BoxBlur tile占位，Serialize/Deserialize+Bake PASS）
- [x] `gpu.canvas`（`TAtlas/TAtlasRegion/ScaleFactor`，2048分页，AtlasAlloc 行装箱，Scale 1..4）
- [x] `demo_vector_poster` / `demo_converter` 能力示例（3be299081，双示例可视闭环，PNG/BMP 往返 PASS）
- [ ] `SvgImport` 预留 + `RenderAssetBundle`/`PdfExport` 预留（S3+ 完整性）
