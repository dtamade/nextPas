# nextPas rtl/crt/

`rtl/crt/` 承接 nextPas 第一阶段控制台导向行为的显式边界。这里和 `rtl/core/` 分开，
是为了让文本控制台、交互式输入、会话状态与清理路径拥有独立的规范、独立的测试归属，
而不是被泛化 RTL 文案吞掉。

如果你要看长期边界，先读 `docs/architecture/crt-specification.md`。如果你要看它和
核心 RTL 的分工，再读 `docs/architecture/rtl-specification.md`。

## 第一阶段这里先承接什么

- 控制台文本输出与最小 smoke 路径需要的可观察行为
- 终端状态、会话清理和后续 `tests/crt/` 需要的独立归属
- 在不支持场景下可确定性失败的控制台入口

## 当前占位文件

- `crt_placeholder.pas`：为未来 CRT 公开表面与内部实现保留仓库位置

## 这里现在不做什么

- 不把 CRT 行为重新折叠进 `rtl/core/`。
- 不把完整终端抽象层或跨平台控制台矩阵提前做进来。
- 不把第一阶段写成完整 CRT 替换。
