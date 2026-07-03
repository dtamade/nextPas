# nextpas.core.tui 代码契约

> 模块路径: `core/src/nextpas.core.tui.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

终端 UI 框架门面。提供单元格、缓冲区、布局、边框、颜色、样式、
事件处理和 ANSI 转义序列。支持 overlay 和 DSL 布局。

---

## 模块族

| 子模块 | 职责 |
|--------|------|
| tui.base | 基础类型 |
| tui.cell | TCell 单元格 |
| tui.buffer | TBuffer 画布 |
| tui.layout.* | 布局系统（Grid, DSL） |
| tui.borders | 边框字符 |
| tui.color | 颜色模型 |
| tui.style | 样式组合 |
| tui.modifier | 文本修饰 |
| tui.text | 文本渲染 |
| tui.event | 事件模型 |
| tui.input | 输入处理 |
| tui.ansi | ANSI 转义 |
| tui.overlay | 浮动层 |

---

## 线程安全

- TBuffer 不线程安全（per-frame 构建）
- 事件处理在主线程

---

## 依赖关系

- 依赖: base, text, platform.console
- 被依赖: CLI 工具、TUI 应用

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
