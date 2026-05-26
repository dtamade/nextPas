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
- nextPas 编译器自举代码和 `core` 框架共同依赖的最低运行时基线
- FPC `System` 中必须先被平替的对象生命周期事实，例如所有 class 都能消费的
  `TObject.Free` / destructor 调度边界
- 后续必须直接服务 `stage0`、`tests/rtl/` 或 smoke 路径的基础运行时逻辑
- 能够清楚解释为“核心运行时”而不是“控制台行为”的实现落点
- compiler 与 runtime handshake 的 process-level 边界

## System 是最低依赖层

nextPas 后续不能让编译器自举代码和 `core` 框架继续从宿主 FPC RTL 的隐式 `System`
开始。这里要成为 nextPas-owned 的最低依赖层：先提供足以支撑自举、对象生命周期、
基础内建类型、启动/退出和 runtime helper 的最小 `System` 子集，再逐步扩展到更完整的
FreePascal 兼容表面。

这层不是 `core` 框架本身。`core` 可以在它之上提供更现代、更完整的 base/mem/text/time/
collections 等开发框架能力；但 `core` 不能反过来成为编译器理解 `TObject`、`Free`、程序入口
或 unit init/fini 的最低前提。

## 当前实现文件

- `System.pas`：当前最小 source-backed `System` truth，先提供 `TObject.Create`、
  `TObject.Destroy` 和 `TObject.Free` 的对象生命周期符号。
- `system_placeholder.pas`：保留历史占位入口，后续应逐步让真实 `System.pas` 接管更多
  runtime baseline。
- `units/linux-x86_64/System.pas`：target-installed 拷贝，供 resolver / semantic query 消费真实
  source provenance。

当前这一步已经让 implicit runtime 的普通 `class` 默认继承 `System.TObject`，并让
`Worker.Free` 通过继承 member lookup 绑定到 `TObject.Free`。no-fold typed HIR 还会复制
隐式 `TObject` 父类的 VMT slot/function truth，让只继承 `System.TObject.Destroy` 的普通
class 可以把 `Worker.Free` lowering 到 `TObject.Destroy` runtime call。这不是完整 FPC
`System`，也还没有把 implicit runtime 改成自动编译/链接 `System.pas`；backend 仍会跳过
`OriginClass=implicit-runtime` 的额外 assemble/link。

## 这里现在不做什么

- 不在这里放控制台状态管理或 CRT 专属逻辑。
- 不把未定归属的工具辅助代码随手丢进来。
- 不把这份骨架误写成“第一阶段完整 System 替换”。
- 不把 allocator、path、fs、process 之类非 `System` 特有能力重新塞回这里。
