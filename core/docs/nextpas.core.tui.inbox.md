# nextpas.core.tui Inbox

> 这是给后续每轮快速查看的工作看板，不是日志。

## 现在看什么

- 目标树已经推进到 API surface 收口后，下一轮先做消费方验证。
- 当前已确认：32 个测试项目、236 用例全通过，heaptrc 0 泄漏。
- `uses nextpas.core.tui` 是首选入口，`TTui*` / `ITui*` 继续保留兼容。
- `TWidgetAdapter` 暂保留为外部渲染桥接点，未完成消费方验证前不主动删除。

## 下一轮第一动作

- 先建/跑 facade-only smoke：只 `uses nextpas.core.tui`，不直接依赖子单元。

## 路线图

1. 消费方集成，确认门面是否自然。
2. 补 Unicode / grapheme 测试：family emoji、skin tone、复杂 ZWJ。
3. 收尾前做全量回归、文档真相审计，准备合并到 main。
4. 最后一轮再做 benchmark 对照：FPC RTL / Go / Rust。

## 完成门槛

- facade-only smoke 通过。
- 相关公开接口改动都有单测。
- heaptrc 继续保持 0 泄漏。
- 通过后再进入 benchmark / 性能整理。

## 暂不做

- 这一轮不做 benchmark 定稿。
- 不主动删除 `TWidgetAdapter`，除非后续有更完整的替代方案。
- warning 清理不是当前主目标。
