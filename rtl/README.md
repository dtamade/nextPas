# nextPas rtl/

`rtl/` 是 nextPas 第一阶段运行时兼容工作的父边界。它的职责是把核心运行时服务和
控制台导向行为保持显式，而不是把整个 FPC RTL 树一次性搬进来。

这里还要再加一条现在已经冻结下来的方向：`rtl/` 不只是 future user program 的运行时位置，
它也会成为 nextPas 自家 compiler / toolchain 的共享基础设施来源。也就是说，nextPas
不会把长期自举路线建立在仓库外的 core library 之上，而是直接在仓库内把
`toolchain-first RTL` 长成自己的正式资产。

如果你要看冻结后的长期边界，先读
`docs/architecture/rtl-specification.md`、
`docs/architecture/crt-specification.md` 和
`docs/architecture/directory-structure-specification.md`。

## 当前目录分工

- `core/`：核心运行时服务，以及 `System` 和相关基线 units 所需行为
- `crt/`：控制台导向行为，保持独立边界和独立测试归属
- `core/system/`：`System` 相关的最小公开表面与后续实现落点
- `core/base/`：compiler / toolchain 优先复用的基础类型、status/result 与 span vocabulary
- `core/mem/`：allocator contract、arena 与其他 compiler-friendly memory discipline
- `core/text/`：path/identity normalization 与 text file ingestion primitive

长期来看，`rtl/core/` 还会继续长成编译器与工具链共享的基础层，例如：

- allocator / arena / memory helpers
- text / bytes / path / interned-friendly primitives
- collections / ids / spans / diagnostics-friendly support types
- fs / process / time 等 toolchain-facing runtime services

## 第一阶段这里先做什么

- 先把运行时边界写清楚，让 `tests/rtl/`、`tests/crt/`、`tests/harness/` 和 smoke
  路径有稳定依附点。
- 继续服务 Linux x86_64 上的 `stage0` 基线，而不是抢跑到整体 RTL 替换。
- 保持 RTL 与 CRT 的职责分离，避免控制台假设回流成泛化运行时前提。
- 当前已经补齐 `rtl/core/`、`rtl/core/system/` 和 `rtl/crt/` 的第一版 README 与
  最小占位文件，让仓库边界和架构规范真正对上。
- 当前已经开始把 `rtl/core/base/` 与 `rtl/core/mem/` 落成真实 Pascal 单元，
  让 nextPas-native core runtime 从仓库实体开始生长，而不是继续停在抽象层。
- 当前已经继续把 `rtl/core/text/` 接进 `SourceDatabase`、resolver 与 diagnostics vocabulary，
  让 text/path primitive 开始真正服务 compiler 代码，而不是只停在目录名上。
- 接下来优先让 `rtl/core/` 长成 compiler / toolchain 可复用的 nextPas-native core runtime，
  而不是先做一套面向应用生态的大而全标准库。

## 这里现在不做什么

- 不承诺完整 FPC RTL 树覆盖面。
- 不把 CRT 行为折叠回泛化 RTL 文案。
- 不混入 Linux x86_64 之外的平台分支。
- 不把 ABI 稳定性写成当前 gate，`ABI compatibility is deferred`。
- 不把仓库外未完成的 core framework 当作长期正式依赖。
