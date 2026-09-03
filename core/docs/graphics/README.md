# nextpas.core.graphics — 惊艳的 Pascal 图形地基

> **一句 `uses` 画海报，一套 `ICanvas` 撑专业图像能力。**（S2 已落地：`graphics.base/color/path` + `image.base` + `vector.tess` + `canvas.raster` + `effect.graph` 全量可用，`image.dispatch` 6 格式注册 `png/jpeg/webp/bmp/gif/qoi`，见 `CONTRACT.md` 0.2.1-source-contract，`bench_image` 1MB 固化 `512×512`）
> 为 `directui` 与高性能矢量系统而生，提供图像设计、矢量排版、滤镜与转换的完整能力支撑，对标 `gui-framework` 的 `UiScene → DrawPlan → RenderGraph → RenderBackend`，图形只产 `TBitmap/ICanvas`。
> **铁律**：零直引 FPC RTL（`SysUtils/Graphics/FPImage`），缺失反哺 `nextpas.core`；存量可抽代码迁入本家族；超越 Go 1.22 / Rust tiny-skia 0.11。

## Hero：7 行 vs 20 行（高级感）

```pascal
// Pascal 7 行 — 值类型 + 不可变链 + 流式 With（优雅）
uses nextpas.core.graphics, nextpas.core.image, nextpas.core.canvas;
var B := TBitmap.Create(800, 600, RGBA);
var C := TCanvasRaster.Create(B);
var P := TPath.New.MoveTo(0,0).CubicTo(50,0,50,100,100,100).Close;
C.FillPath(P, TBrush.Solid($FF3B82F6).WithOpacity(0.9).WithTransform(TMat2D.Scale(2,2)));
B.SaveToFile('poster.png'); // 零 RTL，经 image.png + compress.deflate
```

```pascal
// 图像转换：异常直线 vs Try 分支（双形态惊艳）
try
  B := ImageDecode(FileToBytes('in.jpg'), Info); // 直线，异常上抛（默认）
except on E: EImageDecodeError do Exit; end;
// 分支走 Try（Go单error/Rust单Result，我们双形态）
if not TryImageDecode(FileToBytes('in.jpg'), B, Info) then Exit;
B := EffectResize(B, 1920, 1080, High);
WriteBytes('out.webp', ImageEncode(B, WebP));
```

*DirectUI 亦同：`Widget.Build → C.FillPath/DrawGlyphRun → DrawPlan`，一套 `ICanvas` 通吃。*

## 定位（模块化）

- **L1 底座** `nextpas.core.graphics`（`base ≤800行 + color + path`，`Single` 外部，零堆/零 `bytes`）
- **L2 能力** `image(TBitmap, Stride 64B)` / `vector(布尔/描边, Double内)` / `canvas(tiled 16x16 + simd)` / `graphics.effect(非破坏图, 序列化)` — 仅 L0-L1
- **L3 粘合** `nextpas.core.gpu.canvas(TAtlas/ScaleFactor)` — 消费 L2，`canvas` 不反向
- **消费者** `directui` 等上层 + 专业图像软件（`document` 等应用模型落 `packages/`，core 仅能力支撑）

## 统一漏斗（复用度）

```
vector(路径布尔) ─┐
image(TBitmap)  ──┼─→ canvas(ICanvas, 2口: DrawGlyphRun/DrawBitmap) ─→ DrawPlan ─→ RenderGraph ─→ gpu/window
font→graphics.text(GlyphRun) ─┘                ↑  effect.graph(Bake 并行)
```

`Go` 矢量/图像/文本割裂，`Rust` 滤镜无图；我们 **四段合一**。

## 模块清单（完整性）

| 模块 | 层 | 惊艳点 |
|---|---|---|
| `graphics` | L1 | `TColor32/TRgba/TBlendMode 27种/TColorSpace/TRect/TVec2/TMat2D/TPath/TGradient.WithTransform`，值类型 COW |
| `image` | L2 | `TBitmap(Stride AlignUp 64B)` + `Png/Jpeg/WebP/Bmp/Gif/Qoi` 6 格式 `image.dispatch` 注册（`ImageRegisterCodec` 6 项闭环，`DetectImageFormat` 嗅探，`TryImageDecode` 不抛），纯 Pascal 四格式恒 `graphics.gif/jpeg/webp/qoi.888` 禁 `*.pure`/`image.gif`，`bytes.ops` 单源 `Move` 零拷贝 `inline` |
| `vector` | L2 | `PathUnion/Diff/Stroke` + `tess(Double)` |
| `canvas` | L2 | `ICanvas(Save/Restore RAII)` + `DrawGlyphRun`，CPU 光栅 `simd` 批 blend（`simd.raster` 直联 `inline` 零 `dispatch`） |
| `graphics.effect` | L2 | `EffectGraph(Blur/Shadow/Hue/LUT)` 序列化，`Bake` tile64 并行（`BOXBLUR_MAX_PIXELS 16M` fail-closed） |
| `gpu.canvas` | L3 | `TAtlas/TAtlasRegion/ScaleFactor`，复用 `gpu.gl` |

`font`/`text.unicode` 复用，不另立 `text`。

## 性能底牌（性能）

- `Single` 外部 / `Double` 内部 tess（`math.EPSILON 1e-6`），`Tile 16x16` + `simd`，`Stride 64B`（AVX cacheline），`Move` 零拷贝复用 `bytes.ops` 单源 + `bytes.binary` 单源，`inline` 行拷贝
- Bench 冻结：`bench_raster(Fill/Stroke/DrawBitmap256)` + `bench_image(1MB Decode)`（`512×512×4 = 1,048,576 bytes` 单次，`Encode 512×512 + Decode 512×512` 双项，`ns/op + MB/s`，`--verify` 锁 `bench-image.json` + `Decode <800µs/MB` 门禁 `GATE_DECODE_US 800`），锁版本 `Go1.22/tiny-skia0.11`，`nextpas.core.bench`（禁手搓），见 `CONTRACT §5`

## 稳定性

- 族 `EGraphicsError → {EColorError, EImageDecodeError(EImageDecodeError), EVectorError, ECanvasError, EEffectError}`（`EImageDecodeError` 收敛 `EArgumentError/EIOError/ENotImplemented`），`TryImageDecode` 分支不抛，`BoxBlur >16M` 抛 `EEffectError` fail-closed，`fuzz` 门禁
- 888 守卫：纯 Pascal 后端恒 `nextpas.core.graphics.<fmt>.<fmt>888`（`gif/jpeg/webp/qoi`），禁 `*.pure`/`image.gif` 回退，`image.pas` 显式 `uses` 四 888 锚定，`grep -r "\.pure" core/src --include="*.pas" | grep graphics/image` 0，门禁 `test_image_888_guard`
- `SemVer 0.2.1-source-contract`，`focused-runtime` 准备中（L1/L2 四件套 `base←intf←实现←门面` + `errors` 闭环五子类 + 6 格式调度 + `bench_image` 1MB 已齐，待 `source-contract` 全绿升档，见 `CONTRACT §4.0/§5`）

## 测试入口

```bash
make focused FOCUS=core/tests/nextpas.core.graphics/test_graphics_base
make focused FOCUS=core/tests/nextpas.core.graphics/test_image_888_guard  # 888 命名 + dispatch 6 格式 + no .pure
make focused FOCUS=core/tests/nextpas.core.graphics/test_poster_golden   # 海报 512×256 md5 27b73e0d9a765c491bee8c85b367cef2
make focused FOCUS=core/tests/nextpas.core.canvas/test_canvas_raster  # golden PNG 容差 ≤1
```

Bench：`benchmarks/nextpas.core.canvas/bench_raster --verify` + `benchmarks/nextpas.core.image/bench_image --verify`（`1MB 512×512×4 ns/op+MB/s`，`--verify-go-rust` 锁 `Go1.22/tiny-skia0.11`）

## 文档索引

- 契约：`CONTRACT.md`（类型/不变量/错误/线程/门禁）
- 架构：`ARCHITECTURE.md`（依赖漏斗 + 超越锚点）
- 路线图：`ROADMAP.md`（S0→S3 活文档，Perf Gate）
- 目标树：`GOAL_TREE.md`（S1-00~S3 可勾选）
- 对标：`PARITY-go-rust.md`（6维超越 + 柱状图预演）
- 定版：`../plans/2026-08-30-graphics-framework-v1.md`
