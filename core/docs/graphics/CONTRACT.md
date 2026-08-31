# nextpas.core.graphics 代码契约（S0 冻结草案）

**家族**：`graphics(L1) + image/vector/canvas/effect(L2) + gpu.canvas(L3)`
**层级**：见 `core/docs/core-module-registry.md` 拟新增行
**Owner**：graphics lane（`codex/core-graphics`）
**版本**：S0 0.1.0-draft（文档定版，源码未落地，`SemVer`；`draft → focused-runtime` 需 source-contract + bench 门禁，见 `ROADMAP`）

---

## 1. 类型契约

### 1.1 L1 `nextpas.core.graphics` 家族值类型（零堆分配，单文件 ≤800 行拆子模块）

> `graphics` L1 拆 `graphics.base`（Color/Rect/Mat2D）+ `graphics.color`（`ColorConvert`）+ `graphics.path`（`TPath` 构建），门面 `nextpas.core.graphics` 纯 re-export。

```pascal
// graphics.base — 色彩/几何（Single 外部，Double 内部 tess；容差引 math.EPSILON）
TColor32 = type LongWord; // $AARRGGBB，sRGB
TRgba = record R,G,B,A: Single; end;
TBlendMode = (Normal, Multiply, Screen, Overlay, Darken, Lighten, ...); // 27 种，Skia 子集全量
TColorSpace = (SRGB, Linear, DisplayP3);
function ColorConvert(const C: TRgba; Src, Dst: TColorSpace): TRgba; // S2 实现，P3↔sRGB

TVec2 = record X,Y: Single; end;
TRect = record X,Y,W,H: Single; class function From(AX,AY,AW,AH: Single): TRect; static;
  function IsEmpty: Boolean; inline; end;
TMat2D = record A,B,C,D,Tx,Ty: Single; // 3x2 仿射，Single 外部
  function Translate(DX,DY: Single): TMat2D; function Rotate(Rad: Single): TMat2D; function Scale(SX,SY: Single): TMat2D;
  function IsInvertible: Boolean; inline; function Inverse: TMat2D;
end;

// graphics.path — 路径（COW 值类型，内部 array of TVec2/Byte，不依赖 TBytes）
TPathVerb = (Move, Line, Quad, Cubic, Close);
TPath = record
  class function New: TPath; static;
  function MoveTo(X,Y: Single): TPath; function LineTo(X,Y: Single): TPath;
  function QuadTo(CX,CY,X,Y: Single): TPath; function CubicTo(C1X,C1Y,C2X,C2Y,X,Y: Single): TPath;
  function Close: TPath; function IsEmpty: Boolean; inline;
end;
TStrokeOptions = record Width: Single; Cap: TLineCap; Join: TLineJoin; MiterLimit: Single; end;
TGradient = record Kind: TGradientKind; Colors: array of TColor32; Stops: array of Single; Transform: TMat2D;
  function WithTransform(const M: TMat2D): TGradient; function WithOpacity(A: Single): TGradient; end;
```

不变量：
- `TRect.W/H >= 0`，负值在 `From` 即 `EArgumentError`；`TRect.IsEmpty` ⇔ `W<=0`或`H<=0`
- `TPath` 空路径 `IsEmpty=True`，`Close` 幂等；`MoveTo` 后无 `Line` 即空
- `TMat2D` 行列式 `Det= A*D - B*C`，`|Det| < math.EPSILON(1e-6)` 视为退化，`IsInvertible=False`，`Inverse` 抛 `EVectorError`（`math` 同源阈）
- `Stride = AlignUp(Width*4, 64)`（见 §1.2），`TPath` 内部不触 `bytes`

### 1.2 L2 `nextpas.core.image.base`（含 TBitmap）

```pascal
TBitmapFormat = (RGBA, BGRA, Gray8);
TBitmap = record // COW，TBytes 持有像素，Stride 64B 对齐（AVX cacheline）
  Width, Height, Stride: Integer; // Stride = AlignUp(Width*4, 64)
  Format: TBitmapFormat;
  Pixels: TBytes;
  class function Create(AW,AH: Integer; AFmt: TBitmapFormat): TBitmap; static;
  function IsEmpty: Boolean; inline;
  procedure Premultiply; procedure Unpremultiply;
end;
TImageFormat = (Png, Jpeg, WebP, Bmp, Gif);
TImageInfo = record Width,Height: Integer; Format: TImageFormat; HasAlpha: Boolean; end;

function ImageDecode(const AData: TBytes; out AInfo: TImageInfo): TBitmap;
function TryImageDecode(const AData: TBytes; out ABitmap: TBitmap; out AInfo: TImageInfo): Boolean;
function ImageEncode(const ABitmap: TBitmap; AFormat: TImageFormat): TBytes;
```

不变量：`TBitmap.Width/Height >0` 且 `Length(Pixels)=Stride*Height`，否则 `EImageError`。

### 1.3 L2 `nextpas.core.vector` / `canvas.intf` / `effect`

```pascal
EGraphicsError = class(Exception);
EColorError = class(EGraphicsError);
EImageError = class(EGraphicsError);
EImageDecodeError = class(EImageError); // 细分：CRC/截断/格式（image.png 的 EIOError/EArgumentError 收敛至此）
EVectorError = class(EGraphicsError);
ECanvasError = class(EGraphicsError);
EEffectError = class(EGraphicsError);

// vector — 布尔/描边（内部 Double tess，外部 Single）
function PathUnion(const A,B: TPath): TPath; function PathDifference(const A,B: TPath): TPath;
function PathIntersect(const A,B: TPath): TPath;
function PathStroke(const APath: TPath; const AOpts: TStrokeOptions): TPath;

TAtlas = record PageWidth, PageHeight: Integer; end;
TAtlasRegion = record Page: Integer; Rect: TRect; Scale: Single; end; // gpu.canvas 用

ICanvas = interface
  procedure Save; procedure Restore; // RAII 可用 TScope
  procedure Concat(const AMat: TMat2D); procedure ClipPath(const APath: TPath); procedure ClipRect(const AR: TRect);
  procedure FillPath(const APath: TPath; const ABrush: TBrush);
  procedure StrokePath(const APath: TPath; const ABrush: TBrush; const AOpts: TStrokeOptions);
  procedure DrawBitmap(const ABitmap: TBitmap; const ASrc, ADst: TRect; AQuality: TFilterQuality);
  procedure DrawGlyphRun(const ARun: TGlyphRun; const APos: TVec2); // 不收 string，收 GlyphRun（text 层已产）
end;
TGlyphRun = record Glyphs: array of UInt32; Positions: array of TVec2; Scale: Single; IsEmpty: Boolean; end; // graphics.text 产，Scale 填 DisplayScale（打通 window/gpu.canvas）
TBrush = record // Solid/Gradient/Pattern，链式高级感
  class function Solid(AColor: TColor32): TBrush; static;
  class function GradientLinear(const AGrad: TGradient): TBrush; static;
  function WithTransform(const M: TMat2D): TBrush; function WithOpacity(A: Single): TBrush;
end;
```

---

## 2. 错误处理（闭环）

- 族：`EGraphicsError → {EColorError, EImageError(EImageDecodeError), EVectorError, ECanvasError, EEffectError}`（`errors` owner）
- 默认抛异常直线，边界统一捕获；`TryXxx` 仅分支必需（`TryImageDecode`），不引入 `Result<T,E>`
- 空/无值用 `TBitmap.IsEmpty / nil ICanvas / TGlyphRun.IsEmpty` 表达
- `image.png` 存量 `EArgumentError/EIOError` 在 S1 `feat(image): 错误收敛` 迁入 `EImageDecodeError`

## 3. 线程安全与版本

- L1 值类型纯函数，线程安全；`TMat2D/ColorConvert` 无共享可变
- `TBitmap` COW 写时复制，读并发安全，写需外同步（`Interlocked` 引用计数）
- `ICanvas` 非线程安全，单线程录制 + `Save/Restore` 栈；`EffectGraph.Bake` tile 并行（`thread` 池，`TVec2` 只读）
- 版本：`SemVer 0.1.0-draft`，`draft → focused-runtime` 需 `source-contract + bench + 线程/错误门禁` 全绿（见 `ROADMAP Gates`）

## 4. 依赖边界

- `graphics` L1：仅 `base/math`（+ `mem` 分配器间接），零 `bytes/font` 依赖（`TPath` 不用 `TBytes`）
- `image/vector/canvas/effect` L2：仅 L0-L1，`canvas.raster` 依赖 `vector.tess`，不依赖 `gpu`
- `gpu.canvas` L3：唯一允许依赖 `gpu.gl` + `platform.dl`

## 4.1 FPC RTL 零直接依赖（双编译器架构）

- 禁止 `uses SysUtils/Classes/Graphics/FPImage/Types/Dialogs` 等 FPC RTL/包单元；文件 I/O 走 `nextpas.core.fs`，文本转换走 `nextpas.core.text.conv`，字节走 `bytes`/`checksum.crc32`（`image.png` 已示范纯 Pascal + `compress.deflate`）
- 缺失能力一律反哺 `nextpas.core`（如 `TBitmap` 替代 `TFPImage`，`text.number` 补 `TryStrToFloat`），不直引 RTL；`uses SysUtils` 仅经 `units/<target>/` stub 桥接，最终随 `nextpas.core` 自有类型落地而废弃
- FFI 仅 `cdecl external 'c'` 经 `platform.dl` dlopen（如 `image.jpeg.ffi` 可选 `libjpeg-turbo`），不 `uses LibJpeg` 等 FPC 包

## 4.2 存量抽取（反哺）

- `examples/`/`tools/`/`benchmarks/` 中若有图形相关实现（tiled 缩放/`stb_image` 薄包装/渐变 helper），S1 前审计并迁入 `image/effect/vector`，不在应用私养；抽不动的记 `PARITY-go-rust.md §暂缺反哺项`
- 审计命令：`grep -r "FPImage\|TFPImage\|Graphics\|SysUtils" core/examples core/tools --include="*.pas"`

## 5. 测试与 Bench 门禁

| 覆盖 | 路径 | 维 |
|---|---|---|
| 值类型不变量 + `Stride=AlignUp(W*4,64)` | `tests/nextpas.core.graphics/test_graphics_base` | 稳定性 |
| 编解码 round-trip + 错误注入 + fuzz | `tests/nextpas.core.image/test_image_*`（PNG/JPEG/WebP golden + CRC/截断 + `test_image_fuzz`） | 稳定性/完整性 |
| 路径布尔/描边 + Tess 双精度 | `tests/nextpas.core.vector/test_vector_*` | 模块化 |
| 光栅 golden PNG（容差 ≤1，锁版本） | `tests/nextpas.core.canvas/test_canvas_raster`（离屏 → PNG → 像素比对） | 完整性 |
| 滤镜图序列化 + `Bake` 并行 | `tests/nextpas.core.effect/test_effect_graph` | 复用度 |
| 文本 GlyphRun | `tests/nextpas.core.graphics/test_graphics_text` | 复用度 |

Bench（`nextpas.core.bench`，禁手搓计时，单次调用不内循环）：
- `bench_raster: FillPath/Stroke/DrawBitmap(256x256)` + `bench_image: Decode/Encode(1MB)`，输出 `ns/op + MB/s`
- 锁版本 `Go 1.22 / tiny-skia 0.11`，`bench --verify` 对比表，见 `PARITY-go-rust.md`
- `make focused FOCUS=benchmarks/nextpas.core.canvas/bench_raster` + `bench --verify-go-rust`
