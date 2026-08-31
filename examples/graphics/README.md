# examples/graphics — 图形族示例

演示 `nextpas.core.graphics` L1 底座与 `image` / `canvas` / `vector` / `effect` L2 能力的最小可视闭环。

## 前置概念（必读）

### Stride 64B 对齐
- `TBitmap` 由 `nextpas.core.image.base` 承载：`Stride = AlignUp64(Width * BytesPerPixel)`（64B 对齐，AVX cacheline），`Length(Pixels) = Stride * Height`，行尾含 pad。
- **禁止** `Move(Pixels[0], Compact[0], Width*Height*4)` 直拷整块；**必须**逐行 `Move(Pixels[Y*Stride], Compact[Y*Width*4], Width*4)` 去 pad，或用 `GetPixelPtr(X,Y)`（内部 `Y*Stride+X*Bpp`）。
- 紧凑缓冲（`PngEncodeRgba` 入参、`ImageDecode` 出参）为 `Width*4` 紧排；`TBitmap` 为对齐缓冲，二者互转需 Stride 感知。

### COW 语义
- `TBitmap`（`FPixels: TBytes` 引用计数）与 `TPath`（`FVerbs/FPoints: array` 引用计数）均为**值类型 COW**：赋值共享，写时 `Copy`/`SetLength` 独占。
- `TBitmap.Clone` / `Snapshot` / `Premultiply` / `Unpremultiply` 均 `Copy(Pixels)` 后操作；`TPath.MoveTo/LineTo/QuadTo/CubicTo/Close/WithOpacity` 均 `Copy` 后扩容。
- 读并发安全，写需外同步；示例中 `B := C.Snapshot; B2 := B.Clone` 后各自修改互不影响，`EffectGraph.Bake` 返回新位图不改输入。

## 示例

### demo_vector_poster (`demo_vector_poster.lpr`)
> 矢量 + 文本 + 滤镜 同源海报（DirectUI 7 行范式）

```
C := CreateRasterCanvas(512, 256);
P := TPath.New.MoveTo(...).LineTo(...).Close; // COW 链式，不污染原路径
C.FillPath(P, TBrush.Solid(...));
Layout := LayoutText('nextPas graphics', 20, 1.0);
C.DrawGlyphRun(Layout.GlyphRun, TVec2.Create(64,110));
B := C.Snapshot; // COW Clone，Stride 64B（512*4=2048 已对齐，256*2048）
G.Clear; G.AddBlur(1); B := G.Bake(B); // COW：输入不动，输出新图，tile64 并行
Compact ←逐行去 pad→ PngEncodeRgba → /tmp/demo_poster.png
```

运行：`fpc -Fu../../core/src demo_vector_poster.lpr && ./demo_vector_poster` → `/tmp/demo_poster.png`（golden `512×256`，2957B 容差 ≤1）

### demo_converter (`demo_converter.lpr`)
> PNG↔BMP 往返 + 缩放（Decode→Resize→Encode，Stride 与 COW 可视）

- 64×64 紧凑 `Pix` → `PngEncodeRgba`/`BmpEncodeRgba` → `TryImageDecode`（嗅探 `DetectImageFormat`，`EImageDecodeError` 闭环）
- `TBitmap.Create(64,64)` 后 `Stride=256`，用 `GetPixelPtr(0,H)^` 逐行填紧凑数据，验证对齐层透明
- `CreateRasterCanvas(128,128).DrawBitmap(64→128)` 缩放，`Snapshot` COW 隔离后校验 128×128
- 紧凑→位图→紧凑 往返一致性校验

运行：`fpc -Fu../../core/src demo_converter.lpr && ./demo_converter` → `demo_converter PASS (Decode→Resize→Encode Stride 64B 对齐 + COW 往返正确)`

## 依赖漏斗
```
graphics(L1: base/color/path, Single外/Double内, EPSILON 1e-6)
  → image(L2: base Stride64B COW + png/bmp/jpeg/webp + dispatch)
  → vector(L2: path/tess) → canvas(L2: intf/raster, tiled 16x16 + simd.raster)
  → effect(L2: graph/procedural) → gpu.canvas(L3)
```
门面 `nextpas.core.graphics` / `nextpas.core.image` / `nextpas.core.canvas` / `nextpas.core.vector` 均为纯 re-export（`image.dispatch` 承载嗅探调度，保持门面无逻辑）。

## 门禁
```bash
make hygiene
fpc -Se1 -Fu core/src -Fu units/linux-x86_64 examples/graphics/demo_vector_poster.lpr
fpc -Se1 -Fu core/src -Fu units/linux-x86_64 examples/graphics/demo_converter.lpr
```
