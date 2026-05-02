# nextPas rtl/core/

`rtl/core/` 承接 nextPas 第一阶段核心运行时服务的显式边界。这里负责 `System` 基线、
核心文本与文件处理路径，以及其他必须直接服务 Linux x86_64 `stage0` 基线的运行时
能力。

更关键的是：`rtl/core/` 不是只为 future user program 预留的运行时位置，它还会成为
nextPas compiler / toolchain 自己的共享基础层。我们后续要自举，就不能让编译器长期依赖
宿主 FPC 的习惯性基础设施，也不能让编译器单独长出一套私有 core library。

如果你要看长期边界，先读 `docs/architecture/rtl-specification.md`。如果你要看当前
目录为什么要和 CRT 拆开，补读 `docs/architecture/crt-specification.md`。

## 当前目录分工

- `system/`：`System` 相关的最小公开表面与后续实现落点
- `base/`：共享基础类型、status/result 约定、span 与 small support types
- `mem/`：allocator contract、arena 与 compiler-friendly memory discipline
- `text/`：path/identity normalization 与 text file ingestion primitive
- 其他核心运行时单元：后续只在明确服务 `stage0`、`tests/rtl/` 或 smoke 路径时进入

推荐的长期分层是：

- `system`
  - process startup / shutdown、unit init/fini、runtime contract dispatch
- `base`
  - 基础类型、错误/result 约定、stable id / span / small support types
- `mem`
  - allocator、arena、buffer、copy/fill、compiler-friendly memory discipline
- `text`
  - bytes、string/piece、path、symbol/interned-friendly text helpers
- `collections`
  - vector、map、set、deque 等工具链高频数据结构
- `fs` / `process` / `time`
  - 直接服务编译器、构建器、包管理器与 future IDE 的系统抽象

## 第一阶段这里先做什么

- 把核心 RTL 边界从顶层 `rtl/` 继续往下细化，让 `System` 不会和控制台行为混成一层。
- 为后续 `tests/rtl/`、`tests/harness/` 和 smoke 路径保留稳定的代码归属。
- 继续只服务 Linux x86_64 `stage0` 基线，而不是提前承诺整体 RTL 替换。
- 先把 `base` 和 `mem` 这两层落成真实仓库实体，给 compiler/session/diagnostics/lowering
  后续接入统一 vocabulary 与 arena discipline 的地方。
- 继续把 `text` 这一层落成真实仓库实体，让 source/path/identity 不再散落在 compiler
  私有 helper 里。
- 先让 compiler / toolchain 真正能复用的 `base/mem/text/fs/process` 这类核心层长出来，
  再决定哪些能力继续升格成面向普通程序的更宽公共 RTL。

## 这里现在不做什么

- 不把控制台状态管理、交互式输入或终端假设塞进 `rtl/core/`。
- 不把 `system/` 变成任意辅助代码的杂项目录。
- 不承诺完整 FPC RTL 树迁入。
- 不让 compiler / toolchain 为了追求短期速度各自复制一套私有基础设施。
