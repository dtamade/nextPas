# nextpas.core.graphics 架构 — 惊艳的统一

## 设计哲学（为什么超越）

> **Pascal 的惊艳 = 极简 API 承载统一能力，性能是底牌。**
> Go 极简但无矢量，Rust 零成本但堆+割裂。我们以 **L1 值类型零堆 + L2 四能力合一 + `EffectGraph` 序列化**，让 `directui` 与专业图像软件共用一套 `ICanvas`。

## 1. 统一漏斗（模块化 + 复用度）

```
                ┌─ vector(路径布尔/描边, Double内) ─┐
graphics(L1) ──┼─ image(TBitmap, Stride 64B) ───────┼─→ canvas(ICanvas: Fill/Stroke/DrawBitmap/DrawGlyphRun)
(base/color/path)└─ graphics.text(GlyphRun) ← font+text.unicode ┘  │  tiled 16x16 + simd
                                                         │  effect.graph(Bake 并行, 序列化)
                                                         ↓
                                              DrawPlan(backend-neutral) → RenderGraph → SurfaceFrame → RenderBackend+PlatformShell
                                                         ↑  RenderAssetBundle(atlas/shader, toolchain)
```

- `graphics` L1 ≤800行三子模块（`base/color/path`），零 `bytes/font`（`TPath` 用 `array of`），门面 `nextpas.core.graphics` re-export
- `image` 的 `TBitmap.Pixels: TBytes` 是唯一跨 `bytes` 触点；`canvas` 只收 `TGlyphRun`，不直依赖 `font(L3)`（`graphics.text` 在上游转）
- `gpu.canvas(L3)` 薄桥 `TAtlas/TAtlasRegion/ScaleFactor` → `window`/`gpu.gl`，`canvas` 不反向
- **零 RTL**：禁 `SysUtils/Classes/Graphics/FPImage`，缺反哺 `nextpas.core`（`image.png` 纯 Pascal 范例），`units/<target>/` 仅过渡；`examples/tools` 抽取见 `CONTRACT §4.2`

## 2. 与 gui-framework 的惊艳交接

`Pascal app / DirectUI Widget` → `graphics` 值类型 → `canvas` 录制（7行海报）→ `DrawPlan` 片段（clip/transform/brush/GlyphRun）→ `RenderGraph` 合并 → `gpu.canvas` 上传。**不定义 `UiScene`**，但保证 `UiScene` 不用二猜。

## 3. 四件套（模块化）

- `graphics`：`graphics.base` + `graphics.color(ColorConvert)` + `graphics.path` + `graphics.pas` 门面
- `image`：`image.base(TBitmap)` + `image.intf` + `image.png/.jpeg/.webp` + `image.pas`；FFI `image.jpeg.ffi` 经 `platform.dl`
- `vector`：`vector.base` + `vector.path` + `vector.tess(Double)` + `vector.pas`
- `canvas`：`canvas.base` + `canvas.intf(ICanvas)` + `canvas.raster(tiled)` + `canvas.pas`
- `graphics.effect`：`effect.base` + `effect.graph(序列化)` + `effect.pas`
- `graphics.text`：`text.layout` 薄层（`text.unicode Grapheme → font.shaper Glyph → TGlyphRun`）

高级感：`TPath` 不可变链 + `TBrush.WithTransform/WithOpacity` + `Save/Restore` RAII。

## 4. 关键决策（完整性）

- **为何 L1 不拆 `color/geometry/bitmap`**：防 `registry` 碎片与 L1→`bytes` 违规；`TBitmap` 下沉 `image` L2
- **为何 text 不另立**：复用 `font` + `text.unicode`，`canvas` 只收 `GlyphRun`
- **为何 document 不进 core**：应用模型（artboard/layer）落 `packages/`，core 只给矢量/像素/文本/滤镜积木
- **CPU→GPU**：P1-P2 纯 CPU 扫线（`simd`），`gpu.canvas` P3 上，避免锁 API

## 5. 稳定性

`EGraphicsError → {EColorError, EImageDecodeError, EVectorError, ECanvasError, EEffectError}`，`TryImageDecode` 分支不抛（`EArgumentError/EIOError/ENotImplemented→EImageDecodeError` 收敛），`BoxBlur` 空图/`>16M` 抛 `EEffectError` fail-closed，`TBitmap/TPath` COW（`Premultiply/Clone/Snapshot SetLength unique`），`ICanvas` COM + `AutoSave RAII`，版本 `0.2.0-source-contract`（见 CONTRACT，已齐 bench/门禁，`draft→focused-runtime` 三门禁）。

## 6. 性能（底牌）

`Single` 外部 / `Double` 内部 tess（`1e-6` 容差，`math.EPSILON`），`Stride AlignUp(W*4,64)`，Tile 16x16 并行（`thread` 池），`simd` 批 blend。Bench 冻结 `Fill/Stroke/DrawBitmap256 + 1MB Decode`，`ns/op + MB/s`，锁 `Go1.22/tiny-skia0.11`，`bench --verify`。
> **simd 内联抽象**：图形热路径（`canvas.raster FillTrapezoids`）不再走 `simd.dispatch` 原子分发表间接调用，而直联 `nextpas.core.simd.raster` 跨平台内联层（`RasterFillSolid`/`RasterBlendSrcOver`）：`CPUX86_64` 用 `SSE2 pshufd/movdqu` 批写 4 像素/16B，`NEON`/其余走 `scalar`，编译期选优、可内联、无 `atomic_load`。此模式与 `simd.vec16` 一致，图形发现的缺口即反哺 `simd`，避免高层私设加速。
> **BoxBlur O(WH) tile64 并行**：`graphics.effect BoxBlur` 由 `O(r²·WH)`→`O(r·WH)` 可分离→双向滑动 `O(WH)` r 无关（`H init[0..r]→slide` + `V init→slide`，`cnt` 可变精确 `skip`），`tile64 H 64行/V 64列` 分片 `SubmitDirect→GBlurPool.WaitAll`（`≥4M` 且 `IsMultiThread` 时启用，小图零开销；无 `cthreads` 自动回退避免 `RunError 232`），`512×512 r=1 19ms r=32 21ms / 1024×1024 r=32 84ms` 线性，单例 `GBlurPool` 复用；`canvas.raster Save/Restore` 已补 `FClip/FHasClip` 状态栈并空栈抛 `ECanvasError`，`AutoSave→ICanvasGuard` RAII；`TBitmap Premultiply/Clone/Snapshot/GetPixelPtr` 已 COW 隔离；`TGradient.WithOpacity Copy` 隔离；`inline bench Inline 21.1ns vs Dispatch 28.2ns 0.75× ≤0.9×`。

## 7. 超越（六维）

- **模块化**：Go 单包泥球/Rust 单 crate → 我们 L1 三子模块 + L2 四能力 + 外置 `document`
- **性能**：Go 无 tiled/Rust 无 Stride → 我们 64B + tiled + simd
- **高级感**：Go 命令式/Rust 可变 → 我们不可变链 + 流式 With
- **复用度**：割裂 → 四段 `Grapheme→Glyph→GlyphRun→canvas`
- **稳定性**：单轨 error → 五子类 + `fuzz` + `source-contract`
- **完整性**：无矢量/无图 → `Path布尔/EffectGraph序列化/ColorConvert P3/Svg预留` 闭环
