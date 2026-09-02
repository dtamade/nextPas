# nextpas.core.graphics 代码契约（S2 冻结，source-contract + bench 门禁）

**家族**：`graphics(L1) + image/vector/canvas/effect(L2) + gpu.canvas(L3)`
**层级**：见 `core/docs/core-module-registry.md` 拟新增行
**Owner**：graphics lane（`codex/core-graphics`）
**最后更新**：2026-09-02
**版本**：S2 0.2.1-source-contract focused-runtime preparation（自 S0 0.1.0-draft 提升：已落地 `graphics.base/color/path + image.base/vector.tess/canvas.raster/effect.graph`；L1/L2 四件套 `base←intf←实现←门面` + `errors` 闭环 `EGraphicsError→EColorError/EImageError(EImageDecodeError)/EVectorError/ECanvasError/EEffectError` + `bench` 门禁 `nextpas.core.bench`（`bench_raster/bench_image` 单次调用 `ns/op + MB/s`，锁 `Go1.22/tiny-skia0.11`，`bench_image` 1MB 固化 `512×512×4`）已齐并由 `source-contract` 锁定，层级 `graphics L1 + image/vector/canvas/effect L2 + gpu.canvas L3` 已在 `core/docs/core-module-registry.md` 冻结；`draft → focused-runtime` 升档待 `source-contract` 全绿，见 `ROADMAP Gates`；0.2.1 新增 `image.dispatch` 6 格式注册 `png/jpeg/webp/bmp/gif/qoi` + `bench_image --verify` 锁表）

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

// graphics.path — 路径（COW 值类型，内部 array of TVec2/Byte，不依赖 TBytes；批量 Append/AppendPath 单次 Reserve+Move 零拷贝，复用 bytes.ops 单源；邻近 Move 折叠）
TPathVerb = (Move, Line, Quad, Cubic, Close);
TPath = record
  class function New: TPath; static;
  function MoveTo(X,Y: Single): TPath; function LineTo(X,Y: Single): TPath;
  function QuadTo(CX,CY,X,Y: Single): TPath; function CubicTo(C1X,C1Y,C2X,C2Y,X,Y: Single): TPath;
  function Close: TPath; function Append(const AOther: TPath): TPath; inline; // 批量零拷贝 Move，邻近 Move 折叠
  function IsEmpty: Boolean; inline;
end;
TPathBuilder = record procedure AppendPath(const AOther: TPath); inline; end; // Builder 批量零拷贝
TStrokeOptions = record Width: Single; Cap: TLineCap; Join: TLineJoin; MiterLimit: Single; end;
TGradient = record Kind: TGradientKind; Colors: array of TColor32; Stops: array of Single; Transform: TMat2D;
  function WithTransform(const M: TMat2D): TGradient; function WithOpacity(A: Single): TGradient;
  // Colors/Stops 防御性 Copy（不可变，冷路径）；高频用 ColorCount/StopCount/GetColor/GetStop/ColorsView/StopsView inline 零拷贝
  end;
```

不变量：
- `TRect.W/H >= 0`，负值在 `From` 即 `EArgumentError`；`TRect.IsEmpty` ⇔ `W<=0`或`H<=0`
- `TPath` 空路径 `IsEmpty=True`，`Close` 幂等；`MoveTo` 后无 `Line` 即空
- `TMat2D` 行列式 `Det= A*D - B*C`，`|Det| < math.EPSILON(1e-6)` 视为退化，`IsInvertible=False`，`Inverse` 抛 `EVectorError`（`math` 同源阈）
- `Stride = AlignUp(Width*4, 64)`（见 §1.2），`TPath` 内部不触 `bytes`

### 1.2 L2 `nextpas.core.image.base`（含 TBitmap）

```pascal
TBitmapFormat = (bfRGBA, bfBGRA, bfGray8);
TBitmap = record // COW，TBytes 持有像素，Stride 64B 对齐（AVX cacheline）
  Width, Height, Stride: Integer; // Stride = AlignUp(Width*4, 64)
  Format: TBitmapFormat;
  Pixels: TBytes;
  class function Create(AW,AH: Integer; AFmt: TBitmapFormat): TBitmap; static;
  function IsEmpty: Boolean; inline;
  procedure Premultiply; procedure Unpremultiply;
end;
TImageFormat = (ifUnknown, ifPng, ifJpeg, ifWebP, ifBmp, ifGif, ifQoi); // ifUnknown 为探测/空输入哨兵，6 格式全量：png/jpeg/webp/bmp/gif/qoi 均经 image.dispatch 注册，Probe 纯嗅探不解，Try* 不抛
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

### 1.4 L2 `effect.graph` BoxBlur 不变量（S0 固化，可测试）

| 不变量 | 值/策略 | 源码锚点 | 测试门禁 |
|---|---|---|---|
| 大图上限 | `BOXBLUR_MAX_PIXELS = 16 * 1024 * 1024` 像素，`W*H > 16M` → `EEffectError` fail-closed | `nextpas.core.graphics.effect.graph.pas: BoxBlur` 首卫 + `core/src/nextpas.core.graphics.effect.graph.pas:BOXBLUR_MAX_PIXELS` | `test_effect_graph` 注入 `W*H=16M+1` 抛 `EEffectError` |
| arena 预算 | `BOXBLUR_ARENA_LIMIT = 32 * 1024 * 1024` 字节；`NeedHH=AlignUp64(H*W*4*4+W*4+W*4+64) <=32M` 时走 `TLocalArena` 全量 `HH/Cnt`，否则堆回退 Tile 分块 | `BOXBLUR_ARENA_LIMIT / NeedHH` + `Arena.AllocAligned(...,BOXBLUR_ALIGN)` | `source-contract` 断言 `NeedHH` 与阈值 + `arena vs heap` 分支覆盖 |
| Tile64 分片 | `BOXBLUR_TILE=64` 行；`Tile = max(64, R*4)`，`NumStrips=(H+Tile-1) div Tile`，`H/V` 均按 Tile 并行 | `Tile` 计算 + `HorzTaskProc/BlurStripTaskProc` + `SubmitDirect→WaitAll` | `test_effect_graph BoxBlur 512x512 r=32 ≤21ms` 线性门禁 + `IsMultiThread` 回退 |
| AlignUp64 缓存行 | `BOXBLUR_ALIGN=64`（`MEM_CACHE_LINE_SIZE`）；所有分配 `AlignUp(...,64)`：`NeedHH`、Arena `AllocAligned 64`、`Scratch = AlignUp(NumWorkers*W*4*4,64)`、`Chunk = AlignUp(MaxCH*W*4*4,64)`、`Persist = AlignUp(Chunk*NumWorkers,64)`、`Halo = AlignUp(2*R*W*4*4,64)`、`Cnt/CntInv AlignUp(W*4,64)`；`Halo/Persist/Chunk` 与 `Tile64` 对齐避免 false sharing | `nextpas.core.mem.base.AlignUp` 单源 + `BOXBLUR_ALIGN` 常量 + 621/674/534 行号对齐 | `source-contract` 扫描 `GetMem(*, AlignUp(*,64))` 与 `AllocAligned(*,64)` 非 16；`test_effect_graph` 对齐不变量 |
| heaptrc0 资源 | `nil`-init 所有堆指针，统一 `try/finally FreeMem`，无 `raise` 前手动 `FreeMem` | `// heaptrc0 guard: nil-init...` + `finally FreeMem` | `heaptrc` 0 unfreed + `source-contract` 禁 `raise` 前 `FreeMem` |
| 零拷贝/内联 | `Move` 零拷贝复用 `bytes.ops` 单源语义，`HorzRowInto/VecAddI32/VecSubI32/AlignUp` 为 `inline`，`VSum`/`HH` 按指针算术无额外拷贝 | `Move((HH_R+...)^, HH_R^, ...)` + `inline` | `bench` 证明 `BoxBlur r 无关 O(WH)` + `inline` 零拷贝 |

> 缺能力先反哺 owner：`AlignUp` 复用 `nextpas.core.mem.base`（`MEM_CACHE_LINE_SIZE=64`），不自研；`bytes.ops` 为 `Move` 单源。

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
- 版本：`SemVer 0.2.1-source-contract` focused-runtime preparation（自 S0 0.1.0-draft 提升：L1/L2 四件套 `base←intf←实现←门面` + `errors` 闭环 `EGraphicsError` 五子类 + `bench` 门禁 `bench_raster/bench_image`（`bench_image` 1MB `512×512×4` 单次 `ns/op + MB/s`）已齐并由 `source-contract` 锁定，层级 `L1/L2/L3` 已冻结于 `core/docs/core-module-registry.md`；`draft → focused-runtime` 升档待 `source-contract` 全绿，见 `ROADMAP Gates`；0.2.1 `image.dispatch` 6 格式 `png/jpeg/webp/bmp/gif/qoi` 注册闭环，`bytes.ops` 单源 `Move` 零拷贝 + `inline` 转发，`TBitmap` COW `EnsureUnique` 资源释放不丢）

## 4. 依赖边界

- `graphics` L1：仅 `base/math`（+ `mem` 分配器间接），零 `bytes/font` 依赖（`TPath` 不用 `TBytes`）
- `image/vector/canvas/effect` L2：仅 L0-L1，同层仅 `effect` 单向依赖 `image.base TBitmap`（Stride 64B 承载，已在 `core-module-registry.md` 显式 allowlist `L0-L1 plus same-layer one-way image`，禁止循环），`canvas.raster` 依赖 `vector.tess`，不依赖 `gpu`
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
| BoxBlur 16M/32M/Tile64/AlignUp64 + heaptrc0 不变量 | `tests/nextpas.core.graphics/test_graphics_base` + `tests/nextpas.core.effect/test_effect_graph` + `source-contract` | 稳定性 |
| 文本 GlyphRun | `tests/nextpas.core.graphics/test_graphics_text` | 复用度 |

Bench（`nextpas.core.bench`，禁手搓计时，单次调用不内循环）：
- `bench_raster: FillPath/Stroke/DrawBitmap(256x256)` + `bench_image: Decode/Encode(1MB)`（`512×512×4 = 1,048,576 bytes` 单次，`Encode 512x512 + Decode 512x512`），输出 `ns/op + MB/s`，`--verify` 锁表回 `bench-image.json` + 门禁 `Decode 512x512 < 800µs × (Bytes/1MB)`（`GATE_DECODE_US=800.0`）
- 锁版本 `Go 1.22 / tiny-skia 0.11`，`bench --verify` 对比表，见 `PARITY-go-rust.md`；0.2.1 `image.dispatch` 6 格式 `ifPng/ifJpeg/ifWebP/ifBmp/ifGif/ifQoi` 均经 `ImageRegisterCodec` 注册，`DetectImageFormat` 嗅探命中
- `make focused FOCUS=benchmarks/nextpas.core.canvas/bench_raster` + `make focused FOCUS=benchmarks/nextpas.core.image/bench_image --verify` + `bench --verify-go-rust`
