# nextpas.core.window 抽象设计 — 不约束平台的优雅底座

**状态**: Design S2 预研（与 CONTRACT 0.1 + ARCHITECTURE S0 同源，补充抽象原则）
**Owner**: core-window lane
**更新**: 2026-08-28
**一句话**: **最小完整核心 + 显式平台扩展**，核心永不为“最低公共子集”牺牲平台能力

---

## 1. 问题的本质

窗口是平台差异最大的 L2 能力：

- 桌面：TopLevel 创建、decorations、fullscreen、icon、alwaysOnTop、dragRegion
- 移动：**无** TopLevel，只能 `attach` 宿主 `Surface`（`ParentHandle`）
- WASM：**无** OS 窗口，只有 `<canvas>` + `devicePixelRatio` + `requestAnimationFrame`
- Wayland：`NativeHandle = nil` 诚实，`weMoved` 不发

若把所有平台能力硬塞进一个扁平 `IWindow`（30+ 方法），必成“最低公共子集”——要么为不存在的能力抛错，要么为每个平台加 `ifdefs` 分叉。两种都是屎山。

**本模块立场**：
- `IWindow` 只承载**跨平台最小完整闭包**（S1 已冻结，见 `CONTRACT §4`）
- 平台特有能力**不进核心**，通过**显式扩展接口 + NativeHandle 逃生舱**交付，核心永不否决平台

---

## 2. 两层抽象

```
┌─────────────────────────────────────────────────────────┐
│ 核心层（稳定，永不为平台加方法）                          │
│  IWindow / IWindowDispatcher / TWindowOptions / TWindowEvent │
│  生命周期 + 可见性 + 标题几何 + 状态最小集 + DPI只读 + 句柄 │
└──────────────────┬──────────────────────────────────────┘
                   │ QueryInterface / Supports
┌──────────────────▼──────────────────────────────────────┐
│ 平台扩展层（按需出现，用到才引）                          │
│  IWindowWin32 / IWindowCocoa / IWindowGtk                │
│  IWindowAndroid / IWindowUIKit / IWindowWasm / IWindowSdl2 │
│  IWindowInput / IWindowDrag / IWindowFullscreen ...       │
└─────────────────────────────────────────────────────────┘
```

**规则**
1. **核心不认识扩展**：`window.base/intf` 禁止 `uses window.win32/gtk/...`（`INV-3`）
2. **扩展不污染核心**：扩展接口单独单元 `nextpas.core.window.<backend>.intf.pas`，仅在需要时 `uses`
3. **能力发现显式**：`Supports(LWin, IWindowWin32, LExt)`，不支持即 `False`，不抛错不假装（`INV-9` 延伸）
4. **逃生舱永远可用**：`NativeHandle` + `GetScaleFactor` 足以让 `gpu` 自建 `GL` 上下文，无需等待扩展

---

## 3. 核心为什么“小”却是“完整”

`CONTRACT §4` 的 `IWindow` 已是 **winit/tao 最小子集**的完整闭包：

- 创建/显示/隐藏/关闭（幂等 marshal）/焦点
- `SetTitle/SetBounds/Min/Max/Resizable/Maximize/Minimize/Restore/GetScaleFactor`
- `OnEvent(TWindowEvent)` 单一事件入口（`weCloseRequested/weResized/weMoved/weFocusIn/Out/weScaleChanged`）

这 6 类事件 + 8 组方法已覆盖 `gpu`（视口+scale）、`directui`（失效通知）、`webview`（壳）、`game888`（SDL 复用）四消费者的**必需要**。其余（`decorations/transparent/icon/fullscreen/dragRegion/键盘鼠标/IME`）登记 `CONTRACT §9 Deferred`，触发前**不占位**——占位即对未出现场景做猜测，必错。

**小 ≠ 简陋**：小的是**方法数**，完整的是**语义**（诚实表 + INV-1..9 + 线程模型）

---

## 4. 平台扩展的形态（示例，非冻结）

### 4.1 扩展接口（按后端/能力维度）

```pascal
// 仅在 win32 后端可用，桌面 ParentHandle 已抛 EWindowUnsupported 的正交扩展
IWindowWin32 = interface
  ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A101}']
  procedure SetIcon(const AIconPath: string);
  procedure SetDecorations(AEnabled: Boolean);
  function GetHwnd: HWND; // 强类型句柄，NativeHandle 的类型安全视图
end;

IWindowGtk = interface
  ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A102}']
  procedure SetTransientFor(AParent: IWindow);
end;

IWindowWasm = interface
  ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A103}']
  function CanvasId: string;
  procedure SetCanvasSize(AWidth,AHeight: Integer); // CSS 像素，内部转物理
  function DevicePixelRatio: Double;
end;

// 输入能力（deferred-In 触发时立项，不提前）
IWindowInput = interface
  ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A104}']
  procedure OnKey(AHandler: TWindowKeyHandler);
end;
```

使用：

```pascal
var LWin32: IWindowWin32;
if Supports(LWin, IWindowWin32, LWin32) then
  LWin32.SetDecorations(False) // 仅 win32 生效，gtk/cocoa 上 Supports=False
else
  // 诚实回退：用 NativeHandle 自行处理或提示不支持
```

### 4.2 选项扩展（Builder 不膨胀）

```pascal
// 核心 Builder 保持最小（Title/Size/Min/Max/Resizable/Parent）
LWin := TWindowBuilder.New.Title('Demo').Size(1280,720).Build;

// 平台特有选项走扩展 Builder 或二次配置，不进 TWindowOptions
if Supports(LWin, IWindowWin32, LWin32) then
  LWin32.SetDecorations(False);
// 或：TWindowBuilder.New.Win32Options(...).Build  — 仅 win32 单元提供
```

`TWindowOptions` 永远不为某个平台加 `Transparent: Boolean` 这种“对 5 个后端无意义”的字段。需要时，平台在自己的 `window.<backend>.base.pas` 定义 `TWin32WindowOptions`，`Factory` 经重载 `Build` 识别。

### 4.3 事件扩展

核心 `TWindowEvent` 保持 6 类，平台特有输入走 `IWindowInput` 独立事件流，不混入 `weResized`。`fake` 的 `InjectEvent` 仍走同一 `DoDispatch`，输入扩展的 `InjectKey` 走同一 `DoDispatchInput`，无旁路。

---

## 5. 为什么不抽象成“统一大接口”

| 方案 | 后果 |
|------|------|
| 扁平大接口（30 方法） | Wayland 上 10 方法抛 `Unsupported`，调用方 `try/except` 遍地；新增平台能力必改核心，屎山 |
| 最低公共子集 | 平台特色（`WASM OffscreenCanvas` / `Android immersive` / `Win32 Acrylic`）永无出头之日，消费者被迫绕过 `window` 直接调 `emscripten`/`Android NDK`，抽象失效 |
| **最小核心 + 显式扩展** | 核心 5 年稳定，平台能力按需 `Supports`，`NativeHandle` 始终可逃生，测试 fake 仅实现核心，扩展 `SKIP` 不阻塞 CI |

对标：`winit` 的 `WindowExtWindows / WindowExtMacOS` trait 扩展、`raw-window-handle` 的 `HasWindowHandle` + `HasDisplayHandle` 分离，本质同构。

---

## 6. 演进纪律

1. **Deferred 登记簿是门禁**：`CONTRACT §9` 9 项触发前不占位，占位即技术债
2. **扩展先 `Supports` 后方法**：新能力先以 `IWindowXxx` 形式在 `window.<backend>.intf.pas` 试用，稳定后再评估是否提升为核心（需跨 3 后端通用且测试全绿）
3. **fake 诚实**：`fake` 实现核心 + `Supports` 对扩展一律 `False`（除 `ParentHandle` 记录供 S5 预演），不为测试伪造平台行为
4. **文档即契约**：每新增扩展必同步 `CONTRACT 诚实表` 一行 + `ARCHITECTURE §3` 组合契约 + `source-contract` 扫描（`INV-3/4/5`）

---

## 7. 与现有模块的正交性 — directui / 游戏 UI 不被束缚的证明

### 7.1 职责切分：window 只给壳，内容归消费者

```
window（壳：创建/显隐/几何/DPI/句柄/事件/投递）
  ─┬─ directui（渲染树 + 排版 + 命中 + 自带/扩展输入栈）
   ├─ gpu（GL/Vk 上下文，swapchain/vsync 自管）
   ├─ webview（webkit 引擎内容，window 仅为容器）
   └─ game888 / 游戏 UI（SDL2 窗口壳 + 自有 tick/输入/全屏）
```

- `window` **不提供** `swapchain` / `canvas` / `render` / `vsync` / `OffscreenCanvas` 等渲染概念；那是 `gpu` 的职责。`directui` 与游戏 UI 的高频渲染（60/144fps）通过 `weResized/weScaleChanged` 失效 + `NativeHandle+GetScaleFactor` 自建上下文完成，`window` 不成为瓶颈。
- `window` **不提供**键盘/鼠标/触摸/IME 事件（`deferred-In`）；`directui` 立项时若仍无触发条件则自带输入栈，或通过 `IWindowInput` 扩展接入，核心 `IWindow` 永不为输入加方法。
- `tui` 不依赖 `window`（终端格网），天然正交。

### 7.2 directui 为什么能复用同一窗口契约

| directui 需要 | window 已给 | 不束缚的体现 |
|---------------|------------|--------------|
| 物理像素视口 | `weResized(Width/Height)` 物理口径 | 无需换算，`gpu` 直接视口 |
| DPI 换算 | `GetScaleFactor` + `weScaleChanged(NewScale)` | 只读 + 事件，`directui` 自行重排，不代劳 per-monitor 策略 |
| 失效通知 | 同上 + `Dispatcher.Post` 回主线程提交布局结果 | 高频失效不阻塞 `RunLoop` |
| 句柄建上下文 | `NativeHandle` + 诚实表（Wayland `nil` 由 `gpu/EGL` 处理） | 不解释句柄，`directui` 按 `platform.info` 自行判别 |
| 无装饰/透明 | `IWindowWin32.SetDecorations/SetTransparent` 扩展（`Supports` 发现） | 不进 `TWindowOptions`，桌面独有能力不污染核心 |

**性能**：`directui` 的 `Dispatcher` 泵（`g_idle_add_full` / SDL 用户事件 / `PostMessage` / JS 任务队列）在各后端均为 O(1) 唤醒，无轮询；`fake` 的环形 FIFO 供 CI 确定性驱动。

### 7.3 游戏 UI 为什么能复用同一窗口契约

- **循环所有权**：游戏自有 `tick`（`IterateOnce` 形态，`deferred-LI`），阻塞式 `WindowRunLoop` 不适用；立项前游戏侧直接泵 `SDL_PollEvent` 或 `wasm requestAnimationFrame`，`window.sdl2/wasm` 仅提供 `NativeHandle` 与 `GetScaleFactor`。
- **全屏/原始输入**：`IWindowFullscreen` / `IWindowInput` 扩展承载，`Supports` 显式发现；未实现时游戏可经 `NativeHandle` 直调 `SDL_SetWindowFullscreen` / `emscripten` API，不被抽象卡死。
- **多窗口**：`TWindowBuilder.New.Build` 多次调用各得独立 `IWindow`，共享同一主循环；游戏的“主窗口 + 子窗口/覆盖层”无需 `window` 提供父子窗口原语（`deferred-Arch`）。
- **外部复用**：`game888.graphics.window` 私有 `SDL_Window` → S3 `wkSdl2` 后端一对一替换，外部仓库按需排期，契约稳定即迁移成本为零。

### 7.4 平台差异不向上泄漏

- **移动 attach**：`ParentHandle` 非 nil 即 `attach` 形态（`wasm/android/uikit` 接受，桌面抛 `EWindowUnsupported`）；`fake` 记录供契约预演。
- **WASM attach**：`<canvas>` 为唯一形态，`ParentHandle` 携带 canvas 指针/id 指针，`Min/Max` no-op、`weMoved` 不发、`IsMinimized/Max` 恒假、`devicePixelRatio` 为 scale 来源——全部诚实表可见，调用方无需 `{$IFDEF WASM}`。
- **逃生舱**：任何平台特有能力（`Acrylic/Mica`、`OffscreenCanvas`、`immersive`）均可经 `NativeHandle` 直达，无需等待模块发版。

---

## 8. WASM / 移动端的完整适配证据

| 维度 | WASM | Android / UIKit | 桌面 |
|------|------|-----------------|------|
| 形态 | attach 唯一（`<canvas>`） | attach 唯一（宿主 `Surface/UIView`） | TopLevel 创建 |
| 创建 | `ParentHandle` 携带 canvas 句柄 | `ParentHandle` 携带 `ANativeWindow/UIWindow` | `ParentHandle=nil`，非 nil 抛错 |
| 句柄 | canvas 元素指针 | `ANativeWindow*/UIWindow*` | XID/HWND/NSWindow* |
| 几何 | CSS 像素×`devicePixelRatio`=物理；`Min/Max` no-op | 只读（宿主布局），`SetBounds` no-op | 物理像素直通或逻辑换算±1px |
| DPI | `devicePixelRatio`，`weScaleChanged` 来自 `matchMedia` | 宿主 `displayMetrics` | GDK/`GetDpiForWindow`/`backingScaleFactor` |
| 事件 | `weResized/weScaleChanged/weFocusIn/Out/weCloseRequested`；`weMoved` 不发 | `weResized/weCloseRequested`（`destroy` 映射） | 全量 |
| 循环 | 浏览器宿主循环（`RunLoop` 诚实 no-op/`RAF`） | 宿主 `Activity/UIApplication` 循环 | `gtk_main`/`SDL_PollEvent`/`GetMessage`/`NSApp run` |
| 投递 | `emscripten_async_call / setTimeout(0)` JS 队列 | `ALooper` / `dispatch_async(main)` | 各自唤醒原语（见 ARCHITECTURE §4.2） |

**结论**：同一 `IWindow` 口径（物理像素 + `GetScaleFactor` 只读 + `we*` 6 类 + `NativeHandle` 诚实）在四类宿主上均自洽；差异行在 `CONTRACT §2.2` 与 `ARCHITECTURE §6` 诚实表可审，无 `IFDEF` 分叉。

---

## 9. 检验清单（完整适配的证据）

- [ ] `base/intf` 零后端依赖（`INV-3`）
- [ ] 每个后端 `NativeHandle` 诚实值在 `CONTRACT §2.1` 有行
- [ ] `ParentHandle` 在桌面抛 `EWindowUnsupported`，在 `android/uikit/wasm` 接受（`fake` 记录）
- [ ] `GetScaleFactor` 在每后端有来源行（`gtk 整数升格 / win32 GetDpiForWindow / cocoa backingScaleFactor / wasm devicePixelRatio / fake 1.0 可脚本`）
- [ ] `WindowRunLoop` 在每后端有退出原语行（`ARCHITECTURE §4.1`）
- [ ] `fake` 注入走生产同一 `DoDispatch`，`CI 无图形全绿`
- [ ] `source-contract` 绿，`git diff --check` 干净，`make hygiene` pass

---

*本文件与 `CONTRACT.md` `ARCHITECTURE.md` `ROADMAP.md` 同为 `core/docs/window/` 四件套的抽象原则补充，后续波次以此为准，不为平台加方法到核心。*
