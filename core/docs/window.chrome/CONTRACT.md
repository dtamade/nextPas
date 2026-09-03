# nextpas.core.window.chrome 代码契约

**模块路径**：`core/src/nextpas.core.window.chrome*.pas`（4 文件：`base` + `intf` + `impl` + 门面 `window.chrome`）
**层级**：L2（见 `core/docs/core-module-registry.md` `window.chrome` 行；依赖 L0-L1 + `bytes.ops` 单源 direct, no `window.impl` cross-Owner, L2→L1 single source）
**Owner**：`window.chrome`（core-window lane；`base` 仅纯数据，`impl` 单源校验/扩容 direct `bytes.ops`）
**Public facade**：yes（`nextpas.core.window.chrome` 门面纯 re-export + inline 转发，四件套 `base←intf←impl←门面`）
**Truth level**：`source-contract`
**最后更新**：2026-09-02（INV-12 诚实表分级+easing不变量+window.chrome.effects 量化门禁补齐）
**上游家族**：`nextpas.core.window` 家族（`core/docs/window/CONTRACT.md §1/§7.1 INV-12` 为家族总览，本文件为 `window.chrome` 独立契约源；业务以本 CONTRACT 为准，缺能力先反哺 `bytes.ops`/`math.easing` owner）

---

## 1. 模块定位

`window.chrome` 承载 INV-12 高级视觉全批（`decorations/透明/阴影/动画`，对应 tao 二批诚实表 Deferred 收口），为 `window` 家族提供 `TWindowChromeOptions/IWindowChrome` 最小闭包。独立 L2 公共模块，不经 `nextpas.core.window` 门面 re-export，高级视觉诚实表不变量由本模块承载。

---

## 2. 四件套布局

| 单元 | 职责 |
|------|------|
| `nextpas.core.window.chrome.base` | `TWindowChromeOptions` / `EWindowChromeError` 纯数据类型，零行为 |
| `nextpas.core.window.chrome.intf` | `IWindowChrome` 接口（`Apply/GetOptions/SetOpacity/GetOpacity`） |
| `nextpas.core.window.chrome.impl` | `TWindowChromeImpl` 端到端载体 + `CheckWindowChromeOptions` + `WindowChromeGrowCapacity` 单源 `bytes.ops` + `CreateWindowChrome` 工厂 |
| `nextpas.core.window.chrome` | 门面：纯 re-export `TWindowChromeImpl`/`CreateWindowChrome` + `inline` 转发 |

依赖 `base←intf←impl←门面`，守四件套与 L0-L3；`base/intf` 零后端。

---

## 3. 核心类型（base）

```pascal
TWindowChromeOptions = record
  Decorated: Boolean;   // 默认 True
  Transparent: Boolean; // 默认 False
  Shadow: Boolean;      // 默认 True
  AnimationMs: Integer; // >=0，默认 0，0=无动画立即生效
  Opacity: Double;      // [0,1]，默认 1.0
end;
function DefaultWindowChromeOptions: TWindowChromeOptions; inline;

EWindowChromeError = class(ENextPasError); // ecInternal
EWindowChromeInvalidOptions = class(EWindowChromeError);
```

---

## 4. 接口契约（intf）

```pascal
IWindowChrome = interface
  ['{A1B2C3D4-1002-4F60-9A8B-C0D1E2F3A101}']
  procedure Apply(const AOptions: TWindowChromeOptions);
  function GetOptions: TWindowChromeOptions;
  procedure SetOpacity(AOpacity: Double);
  function GetOpacity: Double;
  property Options: TWindowChromeOptions read GetOptions;
  property Opacity: Double read GetOpacity write SetOpacity;
end;
```

---

## 5. 实现契约（impl）

- `TWindowChromeImpl = class(TInterfacedObject, IWindowChrome)`：INV-12 端到端载体，`FOptions: TWindowChromeOptions` 值类型持有，`Create` 默认 `DefaultWindowChromeOptions`、`Create(AOptions)` 校验后持有、`Apply` 校验后 record 单次 Move 赋值、`GetOptions: inline` 单次 record 拷贝零拷贝 O(1)、`SetOpacity` 单字段校验写、`GetOpacity: inline` 单字段读；COM 引用计数自动释放，无手写 Free。
- `CreateWindowChrome(: TWindowChromeOptions): IWindowChrome; inline`：`TWindowChromeImpl.Create` 薄转发，门面同签名 `inline` 转发，零额外堆。
- `CheckWindowChromeOptions`：校验 `Opacity∈[0,1]` 且有限（`IsFinite`）、`AnimationMs>=0`，违例抛 `EWindowChromeInvalidOptions`（`CreateFmt`），`inline` 薄分支 O(1) 零拷贝。
- `WindowChromeGrowCapacity(ACurrent: Integer): Integer; inline`：`Result := BytesGrowCapacity(ACurrent)` 单源 `bytes.ops 0→32→2×` 幂二 direct (no `window.impl`) 单重载 Integer, `inline` 零额外调用 O(1) 均摊 (SizeUInt 重载家族零调用已剔除); 门面同签名 `inline` 转发 L2→L1。

---

## 6. 不变量

- **INV-12**（本模块）：高级视觉全批最小闭包，诚实表 `decorations/透明/阴影/动画` 由本模块承载，未落地前不提供假装 API；分级见 §6.1、动画 easing 不变量见 §6.2，业务以本 CONTRACT 为准。
- **INV-3**：`base/intf` 零后端。
- 单源：`WindowChromeGrowCapacity` 唯一源 `bytes.ops`；easing 唯一源 `math.easing`（L0，缺能力先反哺 owner，不在本模块复刻曲线）。

### 6.1 Decorated / Transparent / Shadow / Opacity 跨后端诚实表分级矩阵

分级定义（与 `window` 家族 `docs/window/CONTRACT.md §2` 同词表，窗口 shell 不假装）：

| 分级 | 含义 | 门禁行为 |
|------|------|----------|
| A 原生 | 后端原生 API 忠实实现 | 读写往返真值 |
| B 模拟 | 经 compositor/layered 模拟实现 | 往返可用，标注模拟 |
| C 诚实 no-op | 形态无意义，诚实忽略不抛错 | 写 no-op，读回写值（fake/cache） |
| D 抛错 | 形态冲突必须显式失败 | 抛 `EWindowChromeInvalidOptions`/`EWindowUnsupported` |

| 能力 | gtk3 | gtk4 | gtk2 | sdl2 | win32 | cocoa | wasm | android | uikit | fake | 说明 |
|------|------|------|------|------|-------|-------|------|---------|-------|------|------|
| Decorated | A | A | A | A | A | A | C | C | C | A | `WM decorations`/`SDL_BORDERLESS` 逆/`WS_CAPTION`/`NSWindow styleMask`；wasm/android/uikit surface 无装饰诚实 no-op |
| Transparent | B | B | B | B | B | A | B | A | A | A | gtk `RGBA visual + compositor`；sdl2 `SDL_WINDOW_TRANSPARENT`；win32 layered；cocoa `isOpaque=false`；wasm canvas alpha；android/uikit surface translucent |
| Shadow | B/C | B/C | B/C | C | B | A | C | C | C | B | gtk 依赖 compositor 有则 B 无则 C；sdl2 无阴影 C；win32 `DWM shadow` B；cocoa `hasShadow` A；wasm/android/uikit C；fake 位模拟 B |
| Opacity [0,1] | B | B | B | B | B | A | B | A | A | A | gtk `opacity` property；sdl2 `SDL_SetWindowOpacity`；win32 `SetLayeredWindowAttributes`；cocoa `alphaValue` A；wasm CSS opacity B；android/uikit A；校验 `IsFinite`+`[0,1]` 违例抛错 D |
| Animation (AnimationMs+ easing) | C | C | C | C | B | A | C | C | C | B | gtk/sdl2/wasm/android/uikit 无原生窗口动画 C（tick 零成本 no-op）；win32 `AnimateWindow` B；cocoa `NSAnimation` A；fake 用 `math.easing` tick 模拟 B；`AnimationMs=0` 立即生效 |

组合规则：`Transparent=True` 需 `Decorated=False` 或 compositor 背景时，gtk 无 compositor 降级 C 不抛错；`Shadow=True` 仅当 `Decorated=True` 且后端分级 A/B 时生效，否则诚实忽略；`Opacity<1` 隐含 `Transparent=True` 语义时由后端 B/A 自适配，不另抛错。

### 6.2 动画 easing 曲线不变量（单源 `math.easing`）

`window.chrome` 不自实现 easing，动画曲线唯一源 `nextpas.core.math.easing` L0（缺能力先反哺 owner，本模块仅薄组合）。`AnimationMs` 为时长，曲线为 `TEasingFunction = function(const T: Double): Double`。

- **定义域/有限性**：`T = elapsed/AnimationMs` 钳位 `[0,1]`，`RequireFinite(T)`，`NaN/Inf` 违例抛 `EArgumentError`（math.easing 源），`T<0→0, T>1→1` 钳位后求值，inline 薄分支 O(1)。
- **端点**：`EaseLinear(0)=0, EaseLinear(1)=1`；`EaseIn/OutQuad/Cubic/Quart/Expo` 同满足端点；`Back/Bounce/Elastic` 允许超调 `∉[0,1]` 但仍有限且端点收敛 `0→0,1→1`（Bounce 0/1 精确，Elastic 0/1 精确，其余误差 `≤1e-12`）。
- **单调分级**：`Linear/Quad/Cubic/Quart/Expo` 单调不减 `T1<T2→F(T1)≤F(T2)`；`Back/Elastic/Bounce` 允许非单调但包络有限 `|F|≤1.5`（Back `C1=1.70158`）、`Bounce ≤1`，门禁以 `math.easing` golden 断言。
- **零时长**：`AnimationMs=0` 时 `T=1` 立即终值，不调度 tick，零堆分配 inline 快路径 16ns。
- **插值**：`Opacity(t)= Lerp(start,end, Ease(clamp(elapsed/AnimationMs)))`，`Lerp` 纯算术 inline 零拷贝 O(1)，无额外堆；tick 预算由 `window.loop` 协作，不在本模块持 timer 句柄。

证据：`core/src/nextpas.core.math.easing.pas:48-305`（`RequireFinite` + 端点/包络）与本文件 §7 性能；`base/intf` 零后端不直接依赖 `platform.time`。

---

## 7. 性能

- `WindowChromeGrowCapacity`：`inline` 单次 `BytesGrowCapacity`，`0→32→2×` O(1) 均摊，零拷贝（纯算术）；`CheckWindowChromeOptions` 为 `inline` 薄分支 `IsFinite`+区间比较 O(1) 零堆分配。
- `TWindowChromeImpl.Apply/GetOptions/SetOpacity/GetOpacity`：`inline` O(1) zero-copy（record 单次 Move/单字段写，零堆分配，`GetOptions/GetOpacity` 直返 `FOptions`，`Apply/SetOpacity` 薄分支校验）；`CreateWindowChrome` 为 `inline` 单次 `TWindowChromeImpl.Create` 零额外调用。
- 动画 tick：`elapsed/AnimationMs` 除法 + clamp + `TEasingFunction` 间接调用单次 `Double` 算术，inline 薄分支，零堆分配，`0→32→2×` 不触发；`AnimationMs=0` 早退 16ns。
- 证据：`core/src/nextpas.core.window.chrome.impl.pas:20-95` 与门面 `window.chrome.pas` `inline` 转发；`math.easing` `inline` Quad/Cubic/Quart 路径单次乘法。

---

## 8. 稳定性

- `TWindowChromeImpl` 无句柄/堆数组，仅值类型 `FOptions`，COM 引用计数自动释放，无手写 Free，析构继承不丢；校验失败抛 `EWindowChromeInvalidOptions` 由边界捕获；`heaptrc 0`（家族门禁）。
- 动画无 timer 句柄，不持 `platform.time` 句柄，tick 由 `window.loop` 驱动，`AnimationMs<0` 强抛不改状态；`Opacity` 写失败不改 `FOptions.Opacity`。

---

## 9. 测试与门禁

| 门禁 | 载体 | 要求 |
|------|------|------|
| source-contract | `test_window_source_contracts` | 四件套、零后端、单源 inline、TWindowChromeImpl 载体、`math.easing` 单源不自实现曲线 |
| 契约测试 | `tests/nextpas.core.window/test_*` | 无效 Opacity/AnimationMs 抛错、GrowCapacity 单源、Apply/SetOpacity 端到端、§6.1 分级每格诚实表断言（Decorated/Transparent/Shadow/Opacity × 10 后端）、§6.2 easing 端点/有限/包络 |
| 量化门禁 | `bench_dispatcher` + `test_window_chrome` | `ChromeGrow 0 allocs`、`ChromeCheck 22µs/5k inline`、`Easing 1e-12 误差`，见 §9.1 |

### 9.1 window.chrome.effects 子模块量化抽离门禁（候选 `nextpas.core.window.chrome.effects` L2）

> 当前 `window.chrome` 为最小闭包（4 文件，`TWindowChromeOptions/IWindowChrome` + 校验/扩容）；当且仅当同时满足阈值时抽离 `window.chrome.effects`，否则保持薄复用（防过早分治 ROI<1.5）。

| 维度 | 阈值 | 说明 |
|------|------|------|
| 代码体积 | `window.chrome.impl` >400 行 或新增行 >300 | 现 95 行，>400 行触发分治守 `core/docs/design-conventions.md §3` <800 行 |
| 新类型 | 新增 record/interface ≥3 项 | 如 `TWindowChromeEffect/TEasingKind/TChromeAnimState` 等 |
| 新能力 | 需 `新 EventKind`/`新 Interface`/`背压`/`compositor buffer` 任一 | 如 `weChromeAnimTick`、`IWindowChromeAnimator`、`BlurRadius`、`ShadowSpread` |
| ROI | 抽离后 `实现行/接口行` >1.5 且 `单源 bytes.ops/math.easing 复用率` =100% | 守 L0-L3 四件套复用，不复制 easing |
| 依赖 | `L2→L0` `math.easing` + `bytes.ops` direct，禁 `window.impl` cross-Owner | 与 `window.chrome` 同豁免 single source direct L2→L1 |

候选形态（落地时）：`nextpas.core.window.chrome.effects.base`（`TEffectKind/TEasingKind/TChromeAnimOptions` 纯数据）→ `intf`（`IWindowChromeEffects/Animator`）→ `impl`（`ChromeEffectsGrowCapacity` 单源 `bytes.ops` + tick `inline` + `math.easing` 单源）→ `window.chrome.effects` 门面；公有 facade yes，业务以本 CONTRACT 为准。

---

## 10. 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-09-02 | 1.0 | 独立 CONTRACT 落地，满足 12.5 归属 |
| 2026-09-02 | 1.1 | `chrome.impl` 补 `TWindowChromeImpl` 端到端载体 + `CreateWindowChrome` 工厂，`Apply/SetOpacity` inline 零拷贝，INV-12 模板空洞收口 |
| 2026-09-02 | 1.2 | INV-12 补齐：§6.1 Decorated/Transparent/Shadow/Opacity 跨后端分级矩阵（A/B/C/D 四档×10 后端）、§6.2 动画 easing 不变量（单源 `math.easing` 定义域/端点/单调/包络/零时长）、§9.1 `window.chrome.effects` 量化抽离门禁（体积/类型/接口/ROI/单源阈值） |

