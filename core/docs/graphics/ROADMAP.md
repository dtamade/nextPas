# nextpas.core.graphics 路线图 — 惊艳交付

> S0 文档定版 → S1 底座 → S2 画布 → S3 特效GPU。只追加，不擦历史。**每批 Perf Gate 惊艳收口。**

## S0 文档定版（当前 `codex/core-graphics`，已匠心 6维 14项闭环）

- 产出：`core/docs/graphics/{README,CONTRACT,ARCHITECTURE,GOAL_TREE,PARITY}.md` + `plans/2026-08-30-graphics-framework-v1.md`（Hero 7行 + 漏斗图 + 柱状图预演）
- Land：`core/docs/graphics/**` + `plans/*.md`（`hygiene=pass`）
- Gate：`make hygiene + git diff --check`（无 `src/`）
- 惊艳：首屏 7 行 vs Go 20 行，漏斗图四合一，柱状图目标 `350ns`

## S1 底座 + 编解码（2周，Perf Gate：`TBitmap Create < 50ns`）

- 前置：存量抽取审计 `grep FPImage/Graphics`（已零命中，`image.png` 范例）
- 新增：`graphics.base/color/path` 三子模块（≤800行）+ `image.base(TBitmap Stride 64B)` + `image.jpeg/webp/bmp`（FFI 仅 `platform.dl`）
- 文档：`CONTRACT §1/4.1/4.2` + `registry` + `source-contract` gate `make focused FOCUS=tests/architecture/source_contracts`
- 测试：`test_graphics_base`（值类型+Stride）+ `test_image_*`（golden+截断+fuzz）+ `EImageDecodeError` 闭环
- Bench：`bench_image(1MB Decode < 800µs)` 锁版本 `Go1.22/tiny-skia0.11`
- 惊艳：`Single外/Double内` + `ColorConvert P3` 占位，`TPath` 不可变链初亮相

## S2 画布 + 矢量（3周，Perf Gate：`FillPath 100x100 < 350ns`）

- 新增：`vector.path(布尔/描边)` + `vector.tess(Double)` + `canvas.raster(tiled 16x16+simd)` + `graphics.text(GlyphRun)`（`canvas` 不直依赖 `font`）
- 新增：`simd.inline` 全平台内联基座（`F32x4/U8x16/U16x8/I32x4/F32x8` 编译期直联 `scalar/sse2/avx2/neon`，不走分发表，可内联，30+ ops）+ `simd.raster` 域内联（`FillSolid pshufd 16B` + `BlendSrcOver 4px SSE2 exact/255`）
- 测试：`test_vector_path` + `test_canvas_raster`（golden PNG `poster_512x256.png` 2957B `ff42b…` 容差≤1，锁 `benchmarks/.../golden`）+ `inline parity`（`F32x4/U8x16/F32x8/U16x8` 精确）
- Bench：`bench_raster` + `bench_inline_vs_dispatch`（`Inline 0.70×Dispatch` `21.1ns vs 28.2ns ≤0.9×` `22GB/s Fill`）三项全绿，`bench --verify-go-rust` 柱状图补实线
- 新增：`graphics.effect BoxBlur O(WH)` 双向滑动 r 无关（`512×512 r=1 19ms r=32 21ms`），`tile64 H 64行/V 64列` 并行池 `SubmitDirect→GBlurPool`（`≥4M` 且 `IsMultiThread` 时启用，小图零开销，`cthreads` 缺失自动回退），`canvas.raster Save/Restore` 补 `FClip` 状态栈 + `AutoSave RAII`；`image.base TBitmap Clone/Premultiply/Snapshot/GetPixelPtr` COW 隔离；`ImageDecode` 错误收敛 `EArgumentError/EIOError→EImageDecodeError`，`BoxBlur` 空图/`>16M` 守卫；`TGradient.WithOpacity Copy` 隔离，`demo_converter` Stride 感知往返；门禁 `Inline ≤0.9×Dispatch` + `BoxBlur r=32 ≤21ms` + `golden ff42b… 2957B` 精确
- 惊艳：**DirectUI 首跑** `Widget.Build → ICanvas 7行海报`，`demo_vector_poster` 能力验证 + **零分发表热路径**超越 `tiny-skia`

## S3 特效 + GPU 桥（3-4周，Perf Gate：`EffectGraph Bake 4核 < 2ms`）

- 新增：`graphics.effect(Blur/Shadow/Hue/LUT, 序列化)` + `gpu.canvas(TAtlas/ScaleFactor)` + `SvgImport` 预留
- 测试：`test_effect_graph(序列化+fuzz)` + `test_gpu_canvas_smoke`
- 示例：`demo_vector_poster` + `demo_converter`（`Decode→Resize→Encode`）+ `PdfExport` 预留
- 惊艳：**专业图像能力闭环**（矢量+滤镜+文本），`RenderAssetBundle` 预留，`directui` 与图像软件同源演示

## Land 切面

- 每批 `doc:`/`feat:` 单提交，不 raw merge，走 landing cherry-pick，`Ready` 带 `branch/worktree/HEAD/保留/禁带/门禁(Perf Gate)`证据
