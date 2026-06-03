# nextpas.core.tui

`nextpas.core.tui` 是一个 FreePascal TUI 框架。它保留了 ratatui 风格的 immediate-mode
rendering、双缓冲 diff 和数组化 cell 布局，但现在 public surface 已经按方案 C 冻结成四层 facade，
默认入口不再把 app/runtime、图像协议和迁移期兼容能力全塞到一个单元里。

## 先选对 facade

- `uses nextpas.core.tui`
  Core 默认入口。只带终端正确性的最小闭包：`TTerminal`、`TBuffer`、`TEvent`、布局、文本、
  ANSI backend，以及基础 widget。
- `uses nextpas.core.tui.ext`
  稳定增强入口。需要 `TApp`、theme、task、panel、focus、interaction、frame budget 时用它。
- `uses nextpas.core.tui.experimental`
  实验能力入口。图像协议、clipboard 这类高波动能力显式 opt-in。
- `uses nextpas.core.tui.full`
  迁移兼容入口。保留旧的宽门面，方便已有代码先迁进来，再逐步收窄依赖。

如果你只需要自己持有终端循环和 buffer，默认 `nextpas.core.tui` 就够了。只要一进入应用框架层，
就直接从 `nextpas.core.tui.ext` 开始，不要再假设 `TApp` 会从默认 core facade 漏出来。

## 用 `nextpas.core.tui.ext` 启动应用

```pascal
uses nextpas.core.tui.ext;

type
  TDemoScreen = class(TScreen)
  public
    procedure Render(const AArea: TRect; ABuffer: TBuffer); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

procedure TDemoScreen.Render(const AArea: TRect; ABuffer: TBuffer);
begin
  ABuffer.SetString(0, 0, 'hello', StyleDefault);
end;

procedure TDemoScreen.HandleEvent(const Ev: TEvent);
begin
  if IsQuit(Ev) then
    Stack.RequestQuit;
end;

var
  App: TApp;
begin
  App := TApp.Create;
  try
    App.Screens.Push(TDemoScreen.Create);
    App.Run;
  finally
    App.Free;
  end;
end;
```

这是 ext 现在的默认 happy path：`TApp` 拥有 `Screens`，在没有显式
`OnRenderCb` / `OnEventCb` 时，默认 render/event path 会委托给栈顶 `TScreen`。
如果你只是写一个很轻的单屏 demo，callbacks 仍然可用，但多屏应用优先走
`TApp + TScreenStack`。

## 用 `nextpas.core.tui` 持有底层循环

默认 core facade 适合自己拥有 render loop 的场景：

- 直接操作 `TTerminal.BeginFrame` / `EndFrame`
- 直接处理 `PollEvent` 返回的 `TEvent`
- 组合 `TBuffer`、`TText`、`TLayout` 和基础 widget

这条路径故意不直接导出 `TApp`、`TClipboard` 或 `TImageProtocol`。这样 core default surface 才能保持
“终端正确性第一”的边界。

## 把 capability truth 放在 `TTerminal.CapabilityProfile`

增强终端能力的 runtime truth 现在集中在 `TTerminal.CapabilityProfile`：

- `Truecolor`
- `KittyKeyboard`
- `ImageProtocol`

每项能力都区分 `Requested`、`Detected`、`Active`、`Verified` 和 `FallbackReason`。兼容属性
`HasTruecolor`、`HasKittyKeyboard`、`ImageProtocol` 仍然保留，但它们现在只是 active-state projection，
不再自己承担 hint heuristic。

这点对 kitty keyboard 很关键：终端 hint 可以说明“候选能力存在”，但在真正完成会话协商前，它不应该被
当成 `Active=True`。

## 继续看哪里

- 架构边界看 [ARCHITECTURE.md](./ARCHITECTURE.md)
- 四层 facade 的冻结 ownership 看 [TIER_REGISTRY.md](./TIER_REGISTRY.md)
- widget catalog 与 widget facade ownership 看 [WIDGET_CATALOG.md](./WIDGET_CATALOG.md)
- benchmark smoke 口径看 [BENCHMARK.md](./BENCHMARK.md)

## 当前 focused verification envelope

这条演进线只维护 TUI focused gates，不把全仓验证重新拖进来。当前里程碑的最小闭环是：

- `test_tui_cap_base`
- `test_tui_core_facade`
- `test_tui_ext_facade`
- `test_tui_experimental_facade`
- `test_tui_facade`
- `test_tui_terminal`
- `test_tui_image_cap`
- `test_tui_backend`
- `test_tui_buffer`
- `test_tui_widget_intf`
- `core/benchmarks/nextpas.core.tui/run_all.sh`
