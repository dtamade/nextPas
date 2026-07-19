# nextpas.core.tui 代码契约

**模块路径**：`core/src/nextpas.core.tui*.pas`（81 个源文件）
**层级**：L3（依赖 L0-L2: text, sync, platform）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-19
**版本**：1.2

---

## 概要

L3 终端 UI：双缓冲 + immediate-mode widget + 分层 facade（core / ext / experimental / full）。
默认 `nextpas.core.tui` 只保证终端正确性；app/runtime 走 `.ext`，协议能力走 `.experimental`。

---

## 1. 接口契约

### 1.1 架构概览

```
┌──────────────────────────────────────────────────────────┐
│ Public facades                                           │
│ nextpas.core.tui | .ext | .experimental | .full          │
├──────────────────────────────────────────────────────────┤
│ App/runtime layer                                        │
│ TApp, screens, tasks, themes, panel orchestration        │
├──────────────────────────────────────────────────────────┤
│ Widget layer                                              │
│ IWidget hierarchy, basic widgets, advanced widgets       │
├──────────────────────────────────────────────────────────┤
│ Text/layout/render model                                  │
│ TText, TLayout, TBuffer, overlay, diff                   │
├──────────────────────────────────────────────────────────┤
│ Terminal/runtime truth                                    │
│ TTerminal, capability profile, ANSI backend, input       │
├──────────────────────────────────────────────────────────┤
│ Platform                                                  │
│ console, signal, time, io                                │
└──────────────────────────────────────────────────────────┘
```

**核心模块**:
- `tui.base` ← 基础类型 (TColor, TKeyEvent, TRect, TSize)
- `tui.buffer` ← 双缓冲区 (framebuffer)
- `tui.style` ← 样式系统 (bold/italic/underline/fg/bg)
- `tui.widget.*` ← 控件集合 (Block/Paragraph/List/Table/...)
- `tui.layout.*` ← 布局引擎 (VBox/HBox/Grid/Flex)
- `tui.event` ← 事件系统 (键盘/鼠标/焦点/resize)
- `tui.backend.ansi` ← ANSI 终端渲染后端
- `tui.input` ← 终端输入 (raw mode, mouse tracking)
- `tui.app` ← TApplication 主循环
- `tui.pas` ← 门面

### 1.2 核心接口（Immediate Mode）

```pascal
{ 无状态渲染契约 —— 所有 widget 的统一接口 }
IWidget = interface
  procedure Render(const AArea: TRect; ABuffer: TBuffer);
end;

{ 有状态 widget 通过专属接口的 RenderStateful 扩展 }
IXxx = interface(IWidget)
  procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer;
    var AState: TXxxState);
end;

{ 事件处理在 state record 上直接调用（非接口方法） }
TXxxState = record
  function HandleKey(const K: TKeyEvent): Boolean;
  // ...
end;
```

**设计意图**:
- IWidget 仅定义渲染契约，不持有状态、不缓存渲染结果
- 有状态 widget 的 state record 类型各异，无法统一到泛型接口（FPC 限制）
- 事件处理在 state 上而非 interface 上，与 ratatui `StatefulWidget` 模式一致
- widget 不持有子引用——这是 immediate mode，不是 retained mode 控件树

### 1.3 控件列表

详见 `WIDGET_CATALOG.md`。按 facade 分层：

| Facade | Widget 数量 | 定位 |
|--------|------------|------|
| `nextpas.core.tui` | 8 | 终端正确性最小闭包 |
| `nextpas.core.tui.ext` | 1 | 稳定 app/runtime 编排 |
| `nextpas.core.tui.full` | 30+ | 完整 widget 目录 |

---

## 2. 不变量

- **[INV-1]** 双缓冲：仅 dirty 区域刷新到终端（dirty row bitmask）
- **[INV-2]** Immediate mode：widget 不保留帧间状态，state 由调用方持有
- **[INV-3]** 接口引用计数：widget 通过 COM 接口引用计数管理生命周期
- **[INV-4]** 门面分层：`core` 不依赖 `ext`/`full`，`ext` 不依赖 `full`

---

## 3. 错误处理

- 热路径绝不靠异常控制流——越界走返回 nil / 边界裁剪
- 异常仅用于违反不变量（帧生命周期违规、nil 渲染函数）
- 异常层次：`ETui` > `ETuiBuffer` / `ETuiLayout` / `ETuiBackend` / `ETuiInput`
- Debug 模式 Assert 验证前置条件（release 零开销）

---

## 4. 线程安全

- UI 线程单线程操作
- 事件队列通过 `nextpas.core.sync` 原语跨线程投递
- `TTaskManager` 提供后台任务调度

---

## 5. 内存管理

- TBuffer 动态分配，CreateEmpty/CreateFilled 构造
- widget 通过接口引用计数自动释放
- 无 IAllocator 集成（计划中）

---

## 6. 测试

- 95 个测试目录，1630 T.Test 注册
- heaptrc 全覆盖（编译器标志 `-gh -dHEAPTRC_ACTIVE`）
- 0 泄漏，0 失败
- 测试源 0 SysUtils / BaseUnix / Unix 直接引用

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-19 | 1.2 | 测试计数 1567→1630；测试 SysUtils 清零；docs/contracts 改指针 | Claude |
| 2026-07-11 | 1.1 | 全面重写：对齐实际实现，修正接口签名、控件列表、不变量 | Claude |
| 2026-07-01 | 1.0 | 初始版本 | Claude |
