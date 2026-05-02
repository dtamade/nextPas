# nextPas rtl/core/system/

`rtl/core/system/` 为 nextPas 第一阶段 `System` 基线预留显式落点。这里的职责不是现在就
完整重做 FPC `System`，而是先把程序启动、退出、基础运行时服务以及相关 smoke 路径
依赖的最小公开表面固定下来。

这里还要明确一个常见误区：`System` 很重要，但 `System` 不是整个 toolchain RTL。
nextPas 的 allocator、text/path、fs/process、collections 这类 compiler/toolchain
共享基础设施应该待在 `rtl/core/` 的其他明确模块里，而不是继续被塞进 `System` 杂项。

如果你要看长期边界，先读 `docs/architecture/rtl-specification.md`。如果你要看 compiler
如何与这里做启动握手，读 `docs/architecture/runtime-bootstrap-specification.md`。如果你要看为什么
这个目录要从 CRT 分离，读 `docs/architecture/crt-specification.md`。

## 第一阶段这里先承接什么

- `System` 相关的最小公开表面
- 后续必须直接服务 `stage0`、`tests/rtl/` 或 smoke 路径的基础运行时逻辑
- 能够清楚解释为“核心运行时”而不是“控制台行为”的实现落点
- compiler 与 runtime handshake 的 process-level 边界

## 当前占位文件

- `system_placeholder.pas`：为未来 `System` 相关实现保留仓库位置

## 这里现在不做什么

- 不在这里放控制台状态管理或 CRT 专属逻辑。
- 不把未定归属的工具辅助代码随手丢进来。
- 不把这份骨架误写成“第一阶段完整 System 替换”。
- 不把 allocator、path、fs、process 之类非 `System` 特有能力重新塞回这里。
