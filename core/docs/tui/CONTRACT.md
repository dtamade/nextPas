# nextpas.core.tui 代码契约

**模块路径**：`core/src/nextpas.core.tui*.pas`（81 个源文件）
**层级**：L3（依赖 L0-L2: text, sync, platform）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 架构概览

```
tui.base         ← 基础类型 (TColor, TKeyEvent, TRect, TSize)
tui.buffer       ← 双缓冲区 (framebuffer)
tui.style        ← 样式系统 (bold/italic/underline/fg/bg)
tui.widget.*     ← 控件树 (Label/Button/Input/List/Container/...)
tui.layout.*     ← 布局引擎 (VBox/HBox/Grid/Flex)
tui.event        ← 事件系统 (键盘/鼠标/焦点/resize)
tui.renderer     ← 终端渲染器 (ANSI escape sequences)
tui.input        ← 终端输入 (raw mode, mouse tracking)
tui.app          ← TApplication 主循环
tui.pas          ← 门面
```

### 1.2 核心接口

```pascal
IWidget = interface
  procedure Render(ABuffer: TFrameBuffer);
  function HandleEvent(const AEvent: TEvent): Boolean;
  function GetBounds: TRect;
  procedure SetBounds(const ARect: TRect);
  function GetFocused: Boolean;
  procedure SetFocused(AValue: Boolean);
end;
```

### 1.3 控件列表

Label, Button, TextInput, TextArea, ListView, CheckBox, RadioButton, ProgressBar, Container, ScrollView, SplitView, TabView, MenuBar, StatusBar, Dialog

---

## 2. 不变量

- **[INV-1]** 双缓冲：仅 dirty 区域刷新到终端
- **[INV-2]** 控件树单父：一个 widget 只属于一个 container
- **[INV-3]** 焦点链：Tab 键按 Z-order 遍历
- **[INV-4]** 样式继承：子控件继承父控件样式（可覆盖）

---

## 3-6. 概要

- **错误**: 非法布局参数抛 EInvalidArgument; 无控件异常
- **线程安全**: UI 线程单线程操作; 事件队列通过 sync 原语跨线程投递
- **内存**: 控件树拥有子控件; TFrameBuffer 动态分配
- **测试**: 46 个测试目录

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
