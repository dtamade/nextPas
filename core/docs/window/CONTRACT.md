# nextpas.core.window 代码契约（冻结草案）

**模块路径**：`core/src/nextpas.core.window*.pas`
**层级**：L2 家族（依赖 L0-L1：base/errors/platform.dl 缝；被 L3 的
`gpu` / `directui` / `webview` 与外部 `game888` 复用）
**Owner**：core-window lane
**最后更新**：2026-08-29（5.0：11 后端×4件套 + 12 事件 + QtIsLoaded inline + 5× 365µs/24.3ns 4.1% 方差 + fake 16→20 全矩阵 + bench 可复现 + shim removal 5.0，13 门禁全绿）
**版本**：5.0（11-backend 完全体：`wkGtk2/wkGtk3/wkGtk4/wkQt/wkSdl2/wkWin32/wkCocoa/wkAndroid/wkUIKit/wkWasm/wkFake` + `weResized/weMoved/weCloseRequested/weClosed/weFocusChanged/weScaleChanged/weDpiChanged/weKeyDown/weKeyUp/weMouseDown/weMouseUp/weMouseMove` 12 事件；11×4 `base←ffi←loader←impl` 严格、共享 `gtk.impl.inc`、零 `PAnsiChar(AnsiString)` Via `text.ansi`；`TWindowEvent` `KeyCode/Modifiers/Button`；legacy `window.gtk` shim 冻结 8 inline forward removal 5.0；本文件冻结单元布局、类型/接口签名、线程模型、不变量、错误族、Deferred 与门禁。）
**对标基准**: Rust `winit` + `tao`（窗口壳最小集）/ GLFW / SDL2 Window /
Flutter View / Android `Activity.getWindow()` / iOS `UIWindow`

---

## 1. 家族布局

| 单元 | 层 | 职责 | 波次 |
|------|----|------|------|
| `nextpas.core.window.base` | 类型根 | kinds/options/event/句柄别名/错误族（含 `EWindowError` 族）；只依赖 `errors` owner | S1 |
| `nextpas.core.window.intf` | 接口 | `IWindow` / `IWindowDispatcher` / 回调命名类型全集 | S1 |
| `nextpas.core.window.fake` | 测试后端 | 无头脚本化后端：注入事件、手动泵 dispatcher，契约测试唯一载体 | S1 |
| `nextpas.core.window.factory` | 工厂 | 后端注册/探测/选择 + `TWindowBuilder` + `WindowRunLoop/ExitLoop` | S1 |
| `nextpas.core.window` | 门面 | 聚合 re-export 全部公共 API | S1 |
| `nextpas.core.gtk3/4/2.base` / `.ffi` / `.loader` | L2 独立家族 | GTK 2/3/4 ABI+动态装载（dlopen 多 soname，BindOpt，可选符号）；window 仅为消费者（伦理扭转，单向依赖） | S2-扭转 |
| `nextpas.core.qt.base` / `.ffi` / `.loader` + `qt.base/ffi/loader` | L2 独立家族 | Qt 绑定（qt5pas 复用 libQt5Pas.so；qt 为自包装 `libnextpas-qt.so` 多版本 shim，window 消费经 `QtIsLoaded` inline 零开销判活） | qt |
| `nextpas.core.window.gtk2/3/4` | 后端适配 | Linux GTK 2/3/4 薄适配（共享 `window.gtk.impl.inc` 718 行，族显式 `WindowGtk4IsAvailable` 等；`window.gtk` 为 deprecated shim→gtk3；`gtk3` 另暴露 `WindowGtkRaw*` 12 项低阶壳供 L3 webview 单源复用） | S2+扭转+F4 |
| `nextpas.core.window.gtk.impl.inc` | 共享实现 | 消除 gtk3/4/2 三拷贝重复（dispatcher+信号+窗口类同一份，族以 `TGtkLoadInfo/TryLoadGtk` 注入） | polish |
| `nextpas.core.window.sdl2.base/.ffi/.loader/.sdl2` | 后端 | SDL2 `SDL_Window`，game888 未来底座（4件套严格） | S3 |
| `nextpas.core.window.win32.base/.ffi/.loader/.win32` | 后端 | `CreateWindowEx` + `WM_*`（4件套） | S4 |
| `nextpas.core.window.cocoa.base/.ffi/.loader/.cocoa` | 后端 | `NSWindow` / `NSView`（4件套） | S4 |
| `nextpas.core.window.wasm.base/.ffi/.loader/.wasm` | 后端 | WASM `<canvas>` attach（`devicePixelRatio` + CSS/物理双口径，4件套） | S2a |
| `nextpas.core.window.android.base/.ffi/.loader/.android` / `.uikit.base/.ffi/.loader/.uikit` | 后端 | 宿主 surface attach（`ParentHandle` 非 nil 路径，4件套） | S5 |
| `nextpas.core.window.fake.base/.ffi/.loader/.fake` | 后端 | 无头脚本化后端占位（ffi/loader no-op placeholder 满足 11×4 均匀） | S1 |

### 依赖方向（伦理扭转后：gtk/qt 独立 L2，window 消费）

```
gtk3/4/2.base ← gtk3/4/2.ffi ← gtk3/4/2.loader  (独立 L2 家族，不知 window)
qt5pas/qt.base ← qt5pas/qt.ffi ← qt5pas/qt.loader (独立 L2，deferred)
                      │
base ← intf ← fake ─┐ │ one-way depends (redis→net 模式)
                 factory ← 门面 ←───┘  (ProbeGtk 聚合 gtk4>gtk3>gtk2 智能回退)
base ← window.gtk3/4/2 ←┘  (薄适配，共享 gtk.impl.inc)
```
           sdl2.ffi ← sdl2.loader ← sdl2 ─┘  （同位）
           win32.* / cocoa.* / android.* / uikit.*  同 gtk 位，波次接入
```

- **`base` / `intf` 零后端依赖**：uses 闭包里禁止出现任何 `window.<backend>*`、
  `window.fake`、`window.factory` 单元（INV-3，source-contract 门禁冻结）。
- `*.ffi` 只含 ABI 类型、常量与函数指针变量，**无逻辑、无 `external`**；
  这是家族级纪律，严于 design-conventions §6 的静态链接形态——窗口系统库
  （GTK/SDL2/Win32/ObjC runtime）一律是系统运行库，走运行时装载，
  不做链接期依赖。
- **`*.loader` 是家族内唯一允许触碰动态装载设施的单元**，原语一律来自
  `nextpas.core.platform.dl`，**禁止 FPC `DynLibs`**。
- 生产单元（非 loader）禁止出现 raw host units（`Windows` / `BaseUnix` /
  `Unix` / `ctypes` / `X` / `CocoaAll` 等，INV-4）；平台真相全部收敛在各
  后端 `ffi` + `loader`。
- 装载失败降级诚实：`WindowBackendAvailable(kind)=False`；强行 `Build` 抛
  `EWindowBackendUnavailable`，消息携带探测过的 soname 列表。

### 注册表时机

module registry 条目必须与首个源码家族同批落地（S1）：注册表门禁
`check_architecture_source_contracts.py` 会拒绝没有 source family 的注册行。
S0 文档 slice 不改 `core/docs/core-module-registry.md`。届时条目：
L2 / owner core-window / public facade yes / allowed deps L0-L1 +
`platform.dl` 缝 / truth level `draft`。

---

## 2. 语义诚实表

跨平台差异显式声明，不做假装。每个后端接入前逐格复核本表并在其
focused/runtime 门禁中断言可测格。

### 2.1 NativeHandle 诚实表（冻结，S2a 补 wasm 行）

| 后端 | `NativeHandle` 返回 | 说明 |
|------|---------------------|------|
| `gtk`（X11 会话） | X11 Window id（XID，以指针宽度整数承载） | `gdk_x11_window_get_xid` |
| `gtk`（Wayland 会话） | **nil** | Wayland 合成器不暴露可嵌入原生句柄；嵌入场景非目标 |
| `sdl2` | 按 windowing subsystem：X11 XID / HWND / NSWindow* / Wayland nil | `SDL_GetWindowWMInfo` 判别 subsystem |
| `win32` | HWND | 客户区顶层窗口句柄 |
| `cocoa` | NSWindow* | 外部消费须自行桥接 ObjC 世界 |
| `wasm` | `EMSCRIPTEN` canvas 元素指针（attach 形态；`ParentHandle` 携带 canvas id 指针） | `emscripten_get_canvas_element_size` 的 `target` 指向的 `<canvas>`；`Close` 后 nil，生命周期归 DOM |
| `android` | ANativeWindow* | attach 形态；surface 生命周期归宿主 Activity |
| `uikit` | UIWindow* | attach 形态 |
| `fake` | 确定性生成的非零假句柄 | 仅用于断言句柄传递链，永不解释内容 |

规则：

- 本模块只交付句柄，**永不解释其内容**；解释权归消费方（gpu 建 GL 上下文、
  webview 组合内容等），消费方自行承担平台判别。
- 句柄有效性：`Show` 完成后除 Wayland 外保证非 nil（GTK realize 前
  `gdk` window 未建，故不给 Show 前承诺）；`Close` 完成后一律返回 nil。
- 平台判别不进公共 API（不做 `HandleOS(): TTargetOS` 之类伪抽象）；
  消费方用 `platform.info` 自行判别。

### 2.2 行为差异矩阵

| 能力 | gtk | sdl2 | win32 | cocoa | wasm | android | uikit | fake |
|------|-----|------|-------|-------|------|---------|-------|------|
| Min/Max 尺寸约束 | `gtk_geometry_hints` 生效 | `SDL_SetWindowMinimumSize` 生效 | `WM_GETMINMAXINFO` 生效 | `contentMinSize`/`contentMaxSize` 生效 | **忽略**：canvas 尺寸归 CSS/浏览器布局，`Build` 选项 `Min/Max` 诚实 no-op | **忽略**：surface 尺寸归宿主布局，诚实 no-op | **忽略**：同 android | 生效（校验逻辑同 base） |
| GetScaleFactor | 整数诚实升格（典型 1/2） | ≥2.24 `SDL_GetWindowDisplayScale`；缺席回退 1.0（诚实标注） | `GetDpiForWindow/96` | `backingScaleFactor` | `emscripten_get_device_pixel_ratio`（`1.0..3.0`），浏览器缩放时 `weScaleChanged` | 宿主 display metrics（当前 1.0 诚实） | `UIScreen.scale`（当前 2.0/3.0 诚实） | 固定 1.0，可脚本化改 |
| weMoved 事件 | 发（配置协议决定精度） | 发 | 发 | 发 | **不发**：canvas 无全局屏幕坐标 | **不发**：surface 无全局屏幕坐标 | **不发** | 仅脚本注入 |
| Wayland weMoved | **不发**（无全局坐标） | 不发 | — | — | — | — | — | — |
| GetTitle | WM 级同步读；未设置过 '' | `SDL_GetWindowTitle` | `GetWindowText` | `title` property | `document.title` 同步（宿主归 `webview.wasm`） | 缓存（宿主标题归 Activity） | 缓存（宿主标题归 UIWindow） | 缓存读 |
| Focus | `present` | `RaiseWindow` | `SetForegroundWindow` | `makeKeyAndOrderFront` | `canvas.focus()`（宿主可为 no-op） | 宿主焦点（no-op） | 宿主焦点（no-op） | 状态位翻转 |
| IsMinimized/Maximized | 查询式真值（gdk window state 位） | `SDL_WINDOW_*` 状态位 | `IsIconic/IsZoomed` | `isMiniaturized`/`isZoomed` | **诚实 no-op**：`IsMinimized=False`/`IsMaximized=False` 恒假 | **诚实 no-op** | **诚实 no-op** | 状态位 |
| ParentHandle（attach） | **不支持**：Build 抛 `EWindowUnsupported` | 同左（S3） | 同左 | 同左 | **接受**：`ParentHandle` 携带 canvas 元素指针/id 指针（attach 唯一形态） | **必需**：携带 `ANativeWindow*`，缺失抛 `Unsupported` | **必需**：携带 `UIWindow*`，缺失抛 `Unsupported` | 记录并接受（供 attach 契约预演） |
| weKeyDown/Up/weMouse* | `key-press/release/button-press/release/motion` 5信号（honest最小 KeyCode0） | `SDL_KEYDOWN/UP/MOUSE*` 端到端（KeyCode Modifiers Button X/Y） | `WM_KEYDOWN/UP/L/R/MBUTTON/DOWN/UP/MOUSEMOVE` 端到端（KeyCode Modifiers via GetKeyState） | honest no-op（NSEvent deferred, compile-only） | **不发**（无OS键盘） | **不发**（host驱动） | **不发**（host驱动） | `InjectKey/InjectMouse` 端到端（确定性） |
| 几何单位换算 | 内部逻辑像素，读写按 scale 换算物理口径，往返误差 ±1px | 同左（点坐标） | 物理像素直通 | 点坐标换算，±1px | CSS 像素×`devicePixelRatio`=物理像素；`SetBounds` 写 CSS 尺度，内部×ratio 得物理往返 | 物理像素直通（只读） | 点坐标（只读，×scale） | 物理像素直通 |

几何契约统一口径：`SetBounds/GetWidth/GetHeight/weResized/weMoved` 一律
**物理像素**；逻辑像素 = 物理像素 / `GetScaleFactor`，换算时机归消费方。
内部以逻辑坐标存储的后端负责双向换算并把舍入误差如实写进上表。

---

## 3. 核心类型（window.base）

### 3.1 后端种类

```pascal
TWindowKind = (wkGtk2, wkGtk3, wkGtk4, wkQt, wkSdl2, wkWin32, wkCocoa, wkAndroid, wkUIKit, wkWasm, wkFake);
const wkGtk = wkGtk3; // 兼容别名，指向 gtk3
```

生产种类在前、`wkFake` 收尾（对齐 `TWebviewKind` 排列惯例，`wkWasm` 紧邻 `wkFake` 之前属 attach 族；gtk 家族显式分裂为 2/3/4 三枚举，`wkGtk` 保留为 `wkGtk3` 别名）。能力驱动的
缺省选择 `DefaultWindowKind: TWindowKind` 定义在 **factory**（探测需要
loader 参与），base 只拥有枚举本身。`BACKENDS[11]` 注册表顺序 `win32>cocoa>android>uikit>wasm>gtk4>gtk3>gtk2>qt>sdl2>fake` 冻结。

### 3.2 窗口选项

```pascal
TWindowNativeHandle = type Pointer;

TWindowOptions = record
  Title: string;              // 默认 ''
  Width: Integer;             // 默认 1024；<=0 用引擎默认
  Height: Integer;            // 默认 768
  MinWidth: Integer;          // 0 = 不设限制
  MinHeight: Integer;
  MaxWidth: Integer;          // 0 = 不设限制
  MaxHeight: Integer;
  Resizable: Boolean;         // 默认 True
  Maximized: Boolean;         // 默认 False；启动即最大化
  ParentHandle: TWindowNativeHandle; // 默认 nil；非 nil = embedded attach
                              // （S5 android/uikit 生效；桌面后端 Build 抛
                              //   EWindowInvalidState，见诚实表）
end;

function DefaultWindowOptions: TWindowOptions;
procedure CheckWindowOptions(const AOptions: TWindowOptions);
```

`CheckWindowOptions` 校验规则（违反即 `EWindowInvalidState`）：
尺寸字段一律 >= 0；`<=0` 的 Width/Height 表示引擎默认；
Max 与 Min 同时为正时必须满足 max >= min。窗口创建后一律隐藏，
可见性由 `Show` 显式给出（无 `Visible` 选项——事件 handler 应先于
Show 注册，示例即此顺序）。

### 3.3 事件 record（3.0 input 扩展：7→12，单 dispatch 不变式保持）

```pascal
TWindowEventKind =
  (weResized, weMoved, weCloseRequested, weClosed, weFocusChanged, weScaleChanged, weDpiChanged,
   weKeyDown, weKeyUp, weMouseDown, weMouseUp, weMouseMove);
const weFocusIn = weFocusChanged; weFocusOut = weFocusChanged; // 兼容别名

TWindowEvent = record
  Kind: TWindowEventKind;
  Width: Integer;     // weResized：新客户区宽（物理像素）
  Height: Integer;    // weResized：新客户区高（物理像素）
  X: Integer;         // weMoved/weMouse*：X（物理像素；Wayland weMoved 不发）
  Y: Integer;         // weMoved/weMouse*：Y
  NewScale: Double;   // weScaleChanged/weDpiChanged：新 scale factor
  KeyCode: Integer;   // weKeyDown/Up：平台 keycode（与 sdl2/win32/cocoa 对齐，未触发为 0）
  Modifiers: Integer; // weKey*/weMouse*：bitmask 1=Shift 2=Ctrl 4=Alt 8=Super
  Button: Integer;    // weMouseDown/Up/Move：1=left 2=right 3=middle
end;

TWindowEventHandler = reference to procedure(const AEvent: TWindowEvent);
```

无关字段保持零值（`Default(TWindowEvent)`）。**单一事件入口**：一切通知（含 scale 变化与 3.0 input）都经
`OnEvent` 以 `TWindowEvent` 分发，不设第二套 per-event 注册面——这是对
webview `OnScaleChanged` 独立注册面的有意收紧，理由见 §4.2。`weKey*/weMouse*` 5 种仅为 `TWindowEventKind` 的新增枚举与字段复用，不引入第二分发路径，不破坏 INV-2 FIFO。

### 3.4 错误族

派生自框架根异常；类目定值在 S1 对照 `nextpas.core.exception.TErrorCategory`
校准并逐类写测试（括号内为暂定映射）：

```pascal
EWindowError                = class(ENextPasError); // 族基类（ecInternal）
EWindowBackendUnavailable   = class(EWindowError);  // dlopen/探测失败（ecNotFound）
EWindowNotInitialized       = class(EWindowError);  // 后端未初始化即使用（ecInternal）
EWindowInvalidState         = class(EWindowError);  // 选项非法/重复误用/Close 后操作等（ecInternal）
EWindowClosed               = class(EWindowError);  // Close 之后仍发起操作（ecInternal）
EWindowUnsupported          = class(EWindowError);  // 后端诚实表明确不支持的能力（ecInternal）
```

`EWindowUnsupported` 用于"诚实表说不支持且调用方仍请求"的显式失败
（如桌面后端收到 `ParentHandle`），与静默 no-op 严格区分：能安全 no-op 的
能力按诚实表 no-op，不能伪装的能力必须抛错。

---

## 4. 接口契约

对外一律 interface（COM 引用计数），消费方不手写释放。三种回调形式
（ref/method/proc）并存遵循 design-conventions §8；下文签名只列匿名形，
method/proc 重载同形省略。

### 4.1 主线程投递（intf）

```pascal
TWindowProcRef    = reference to procedure;
TWindowProcMethod = procedure of object;
TWindowProc       = procedure;

IWindowDispatcher = interface
  { 任意线程把闭包投递到 UI 主线程执行；末窗关闭后投递被静默丢弃 }
  procedure Post(AProc: TWindowProcRef); overload;
  procedure Post(AProc: TWindowProcMethod); overload;
  procedure Post(AProc: TWindowProc); overload;
  function IsOnMainThread: Boolean;
  property OnMainThread: Boolean read IsOnMainThread;
end;
```

各后端主线程唤醒原语：GTK = `g_idle_add_full`；sdl2 = 用户事件
（`SDL_RegisterEvents` + `SDL_PushEvent`）经自家泵分发；win32 =
隐藏 message-only window `PostMessage`；cocoa = `dispatch_async(main)`；
fake = 待泵队列。唤醒原语属于后端接口的一部分（ARCHITECTURE §4）。

### 4.2 窗口（intf）

```pascal
IWindow = interface
  { 生命周期 }
  procedure Close;                    // 幂等；跨线程安全（内部 marshal）
  function IsClosed: Boolean;

  { 可见性与焦点 }
  procedure Show;
  procedure Hide;
  function IsVisible: Boolean;
  procedure Focus;                    // 无焦点概念的宿主为诚实 no-op

  { 标题与几何（物理像素口径，见诚实表换算行） }
  procedure SetTitle(const ATitle: string);
  function GetTitle: string;
  procedure SetBounds(AWidth, AHeight: Integer);
  function GetWidth: Integer;
  function GetHeight: Integer;        // GetWidth/GetHeight 即 GetBounds 读面
  procedure SetResizable(AResizable: Boolean);

  { 状态（tao 对齐最小集） }
  procedure Maximize;
  procedure Unmaximize;
  function IsMaximized: Boolean;
  procedure Minimize;
  procedure Restore;
  function IsMinimized: Boolean;

  { DPI 只读最小集 }
  function GetScaleFactor: Double;

  { 平台原生句柄（诚实表 §2.1；Close 后返回 nil） }
  function NativeHandle: TWindowNativeHandle;

  { 主线程投递（转发到本窗所属后端的 dispatcher） }
  function GetDispatcher: IWindowDispatcher;
  property Dispatcher: IWindowDispatcher read GetDispatcher;

  { 事件注册：唯一事件入口；重复注册覆盖旧 handler（最后注册者生效） }
  procedure OnEvent(AHandler: TWindowEventHandler); overload;
  procedure OnEvent(AHandler: TWindowEventMethod); overload;
  procedure OnEvent(AHandler: TWindowEventProc); overload;
end;
```

设计决定（对 README 能力表的收紧，在此钉死）：

- **不设独立 `OnScaleChanged` 注册方法**：scale 变化统一以
  `weScaleChanged` 事件走 `OnEvent`（`NewScale` 字段携带新值）。双通道
  投递同一信号会造成触发序歧义；winit 亦为单通道事件流。
- **不设运行时 `SetMinSize/SetMaxSize`**：min/max 约束 S1 只有 options
  创建期形态；运行期改约束随 deferred-Win 批次评估。
- 事件反注册句柄推迟到真实用例出现（YAGNI，同 webview 立场）。

### 4.3 工厂与主循环（factory）

```pascal
IWindowBuilder = interface
  function Kind(AKind: TWindowKind): IWindowBuilder;   // 显式钉后端
  function Title(const ATitle: string): IWindowBuilder;
  function Size(AWidth, AHeight: Integer): IWindowBuilder;
  function MinSize(AWidth, AHeight: Integer): IWindowBuilder;
  function MaxSize(AWidth, AHeight: Integer): IWindowBuilder;
  function Resizable(AResizable: Boolean): IWindowBuilder;
  function StartMaximized(AMaximized: Boolean): IWindowBuilder;
  function Parent(AHandle: TWindowNativeHandle): IWindowBuilder;
  function Options(const AOptions: TWindowOptions): IWindowBuilder; // 整体覆盖
  function Build: IWindow;
end;

TWindowBuilder = record
  class function New: IWindowBuilder; static;
end;

{ 主循环所有权：阻塞直到最后一个未 Close 的窗口关闭，或 ExitLoop 被调 }
procedure WindowRunLoop;
procedure WindowExitLoop;

{ 非阻塞泵：为 game/directui tick 循环提供单步迭代（M-band 落地，不阻塞） }
function WindowPumpOnce: Boolean;
procedure WindowPumpAll;

{ 能力探测（factory 持 loader 真相；base 不知道这些函数的存在） }
function WindowBackendAvailable(AKind: TWindowKind): Boolean;
function DefaultWindowKind: TWindowKind;

{ 宿主驱动扩展：attach 后端由宿主经 Supports 探测调用，拒绝 LM_ 消息伪装 }
type
  IWindowHost = interface
    ['{7E9A2B3C-3D4E-4F60-9A8B-C1D2E3F4A005}']
    procedure HostResized(AWidth, AHeight: Integer);
    procedure HostScaleChanged(ANewScale: Double);
    procedure HostCloseRequested;
  end;
```

- `Kind()` 缺省 = `DefaultWindowKind` 能力驱动（探测顺序：平台原生 >
  wasm > gtk > sdl2；wasm 在浏览器宿主为原生；细节 S2a 补 wasm 并写测试）；`Build` 时后端不可用按工厂语义
  fail-fast 抛 `EWindowBackendUnavailable`。
- `Build` 可多次调用创建多个独立窗口；同一进程所有窗口共享同一 UI 主线程
  与同一后端主循环。builder 出的窗口与工厂路径同一生命周期纪律：消费方
  负责 `Close`（幂等），接口引用释放不替代关闭。
- 循环退出条件：最后一个未 Close 窗口关闭，或 `WindowExitLoop` 被调；
  该窗的 `weCloseRequested`/关闭路径事件先于退出判定完成投递。
- `WindowRunLoop` 期间宿主不得再占用该线程做长计算；后台工作 post 给应用
  自己的执行设施，完成后 `Dispatcher.Post` 回主线程收尾。
- 本模块不 uses `TAsyncLoop`；应用层自行把两者接起来。`IterateOnce`
  （单步迭代融合宿主循环）登记 deferred-LI，S1 不实现不预留接口；M-band 以 `WindowPumpOnce/PumpAll` 提供最小非阻塞泵，供 game/directui 的 `tick` 循环复用，不经消息号。

### 4.4 fake 驱动面（fake）

纯 Pascal、无线程、无图形依赖；契约测试的唯一载体（INV-7）。驱动面
经 `Supports` 探测获得，命名在 S1 定案，语义现在冻结：

- **注入事件**：把构造好的 `TWindowEvent` 送入与本生产后端同一条
  `OnEvent` 分发路径（不是旁路直呼 handler）——保证被测的就是分发机制。3.0 input 便捷：`InjectKey(weKeyDown/Up, KeyCode, Modifiers)` 与 `InjectMouse(weMouseDown/Up/Move, X,Y, Button, Modifiers)` 均为 `InjectEvent` 的薄包装。
- **手动泵**：`PumpOnce` 至多执行一条待处理投递、`PumpAll` 清空队列；
  顺序 FIFO 确定。`Post` 在 fake 上不入队真线程，只积累待泵闭包。
- **状态脚本**：scale 值、最大化/最小化/焦点/可见状态位均可直接改写，
  用于驱动 `weScaleChanged` 等派生事件的生成路径。
- **句柄**：确定性生成的非零假句柄，`Close` 后归 nil（与生产后端同规）。

---

## 5. 线程模型

1. **UI 主线程** = 创建窗口并驱动后端主循环的线程。一个进程可有多个窗口，
   但全部窗口共享同一 UI 主线程与同一主循环。
2. **一切用户回调（`OnEvent` handler、`Post` 投递的闭包）都在 UI 主线程
   触发**。引擎/OS 事件天然在主线程到达，后端不得把它们抛到别的线程。
3. **跨线程安全面只有两处**，其余方法按"UI 线程亲和"对待（违例属编程
   错误，debug 构建断言）：
   - `IWindowDispatcher.Post`（任意线程 → 主线程）
   - `IWindow.Close`（任意线程；内部 marshal 到主线程执行，幂等）
4. **不提供任何同步阻塞形态**（无 `WaitForClose`、无嵌套消息泵、无忙轮询）。
   fafafa 教训 #1 制度化。
5. handler 内抛出的异常沿主循环栈向上传播、使 `WindowRunLoop` 展开
   （try/finally 保证运行态标志复位）——编程错误 fail-fast，由应用边界
   （main）统一捕获；本模块不吞不包装用户回调异常。
6. 与 `async.loop` 的关系见 §4.3：无编译期依赖，应用层组合。

---

## 6. 生命周期 / DPI / 多窗口

### 6.1 窗口生命周期

```
Build（隐藏创建，选项已校验）
  → Show → [OnEvent 流]
  → 用户点关闭钮 / 系统 close 请求 → weCloseRequested（可忽略 = 不关）
  → 应用调 Close（幂等；marshal 主线程）
  → 后端销毁原生资源（主线程完成）→ IsClosed=True → NativeHandle=nil
  → COM 引用计数归零释放接口壳
```

- `weCloseRequested` 只是通知：不响应就不关闭（close-request veto 的
  交互式确认 UI 属 deferred，见 §9）。
- Close 后除 `IsClosed`/`NativeHandle` 外一切方法抛 `EWindowClosed`（INV-1）。
- 进程退出不强制要求显式 Close：末窗关闭驱动循环退出；残留接口壳由
  引用计数兜底。

### 6.2 DPI 契约

- `GetScaleFactor: Double` 只读；GTK 整数值诚实升格（1.0/2.0…），
  各后端取值方式见诚实表。
- 逻辑坐标 = 物理像素 / scale；换算时机归消费方。
- scale 变化（显示器迁移、系统缩放变更）以 `weScaleChanged(NewScale)`
  经 `OnEvent` 投递；**不做 per-monitor 动态重排承诺**（deferred-DPI）。
- 移动端（S5）scale 来自宿主 surface 的 display metrics；attach 形态下
  窗口几何只读（尺寸归宿主布局），SetBounds 为诚实 no-op——S5 定案前
  此行先冻在诚实表。
- wasm 端 scale = `devicePixelRatio`（浏览器缩放/显示器迁移时 `weScaleChanged`），几何写 CSS 尺度内部×ratio 得物理；attach 形态下 `ParentHandle` 携带 canvas 指针/id 指针，`Min/Max` 诚实 no-op。

### 6.3 多窗口

- `TWindowBuilder.New...Build` 可多次调用；每窗独立 `IWindow`，共享主循环。
- 事件顺序：单窗内严格 FIFO；跨窗相对顺序未定义（不得依赖）。
- 循环退出条件与计数口径见 §4.3；`WindowExitLoop` 幂等且可在任意时刻调用
  （主线程亲和）。

---

## 7. 不变量

- **INV-1** `Close` 幂等；Close 后除 `IsClosed` / `NativeHandle` 外一切
  方法抛 `EWindowClosed`；`NativeHandle` 在 Close 完成后恒为 nil。
- **INV-2** 一切用户回调恰在 UI 主线程触发；每事件对当前 handler 恰好
  投递一次；单窗事件序 FIFO；窗口销毁后不再产生该窗事件。
- **INV-3** `base`/`intf` 的 uses 闭包不出现任何 `window.<backend>*`、
  `window.fake`、`window.factory` 单元（source-contract 门禁冻结）。
- **INV-4** 生产单元（非 loader）不出现 raw host units（`DynLibs`/
  `Windows`/`BaseUnix`/`Unix`/`ctypes`/`X`/`CocoaAll`…）；平台真相全部
  收敛在后端 `ffi` + `loader`。
- **INV-5** `*.ffi` 无逻辑、无 `external`：只有类型、常量、函数指针变量；
  装载动作只存在于 `*.loader` 且只经 `nextpas.core.platform.dl`。
- **INV-6** `weCloseRequested` 先于任何销毁动作投递；不响应即不关闭。
- **INV-7** `fake` 是契约测试唯一载体；CI 无图形环境全绿。fake 注入事件
  走与生产后端同一条分发路径，不存在测试专用旁路。
- **INV-8** 几何公开口径恒为物理像素；内部逻辑坐标的后端负责换算并把
  误差写入诚实表，不得让消费方感知单位漂移。
- **INV-9** 后端不支持且无法安全 no-op 的能力必须显式抛
  `EWindowUnsupported`，禁止静默假装成功（诚实原则）。

---

## 8. 测试门禁

| 门禁 | 载体 | 要求 |
|------|------|------|
| 契约测试（CI 必跑，全走 fake） | `tests/nextpas.core.window/test_*` | options 校验、状态机（show/hide/maximize/minimize/close 幂等）、事件注入与分发序（INV-2/INV-6）、dispatcher 泵语义、factory 选择逻辑与 fail-fast、错误族类目、句柄 nil 纪律（Close 后） |
| source-contract | `tests/architecture/source_contracts/` 扩展 | INV-3/INV-4 静态扫描；INV-5 `*.ffi` 无逻辑无 `external` 检查；raw host units 白名单外零容忍 |
| 运行时冒烟（本地/Linux CI） | `test_window_gtk_runtime`（S2 起） | 探测到 GTK3 才跑；Xvfb 下建窗→title/bounds/maximize 往返→scale 读取→close 幂等；未探测到输出 SKIP，`NEXTPAS_WINDOW_GTK_REQUIRED=1` 强制 |
| compile-only | 非 Linux host | gtk/sdl2/win32/cocoa 单元参与语法级编译门禁（不链接） |
| benchmark | `benchmarks/nextpas.core.window/bench_dispatcher`（S2 起） | dispatcher Post 往返延迟 ns/op（nextpas.core.bench 框架，禁自定义计时） |

runtime 冒烟允许的最大环境假设：存在 GTK3 运行库；不要求 dev 包
（ABI 自声明）。

---

## 9. Deferred 登记簿（防止半成品混进 S1）

| 能力 | 类别 | 触发条件 |
|------|------|----------|
| `IterateOnce` 主循环融合（接 `TAsyncLoop.WaitForWake`） | deferred-LI | 应用真要把 window loop 接进 TAsyncLoop 时立项（M-band 已以 `WindowPumpOnce` 提供最小非阻塞泵，完整融合仍 deferred） |
| close-request 交互确认（弹窗 veto UI） | deferred-Win | 应用需要"关闭前确认"完整交互时（`weCloseRequested` 忽略即 veto 已覆盖判定面） |
| fullscreen / decorations / transparent / icon / alwaysOnTop / drag region | deferred-Win | tao 对齐第二批；每批过诚实表复核 |
| 运行期 SetMinSize/SetMaxSize | deferred-Win | 出现运行中改变约束的真实场景 |
| 键盘/鼠标/触摸/滚轮/IME 输入事件 | **3.0-input 已落地最小集**（`weKeyDown/Up/weMouseDown/Up/Move` 5 种，`KeyCode/Modifiers/Button/X/Y`）；触摸/滚轮/IME 仍 deferred-In | directui/game888 接入需要触摸/滚轮/IME 时再评估（当前 5 种已覆盖基础交互，剩余 per-后端信号映射：gtk key-press/button/motion、sdl2 SDL_KEYDOWN/MOUSE*、win32 WM_KEY*/WM_MOUSE*、cocoa NSEvent） |
| per-monitor 动态重排 | deferred-DPI | 多显示器动态迁移成为一等需求 |
| 多 view 单窗 / 窗口间通信 | deferred-Arch | 出现真实消费者 |
| 父子窗口 / modal 对话框原语 | deferred-Arch | 对话框家族立项 |
| 事件反注册句柄 | deferred-Ev | 出现高频换 handler 的真实用例 |

规则：Deferred ≠ 计划内；每一项都要有触发条件，触发前接口不留占位。

---

## 10. 稳定性

- 当前 `draft`；registry 条目随 S1 首个 family 源码落地，truth level 记
  `draft`（S1 fake 面达标后升 `focused-runtime`；边界面 `source-contract`）。
- 公共 API 变更纪律：`intf` 单元视为冻结候选，改动必须过契约测试并更新
  本文件（含诚实表逐格复核）。
