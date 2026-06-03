# Findings: process PATH resolution contract and child wait warning batch 11

## Current state

- 当前共享工作树是脏的，但 `process` 相关未提交改动只直接落在
  `tests/nextpas.core.platform.process/test_platform_process/test_platform_process.lpr`。
- `src/nextpas.core.process.*` 当前 Linux focused tests 已经是绿的：
  功能表面没有红，但存在一个编译 warning，且 PATH 解析还有 contract 级别设计债。

## Root causes

- `src/nextpas.core.process.pathresolve.pas` 当前用 `nextpas.core.fs.Exists` 判断候选路径，
  这只能证明“路径存在”，不能证明“这是可执行文件”。
- 结果是当 PATH 前面出现同名但不可执行的文件时，`ResolveExecutablePath` 会提前命中坏路径，
  然后 `execve` 直接失败，而不是像 `execvp` / `which` 一样继续搜索后续目录。
- 仓库里已经有 `src/nextpas.core.platform.which.pas`，它的判断更接近系统语义：
  Unix 下用 `access(..., X_OK)`，Windows 下至少要求是普通文件。`process.pathresolve`
  当前与这条语义重复但更弱。
- `src/nextpas.core.process.child.pas` 的 `TChild.Wait` 会在 `FillChar(Result, ...)` 后才分支填充
  managed record，FPC 因此给出 “Function result variable of a managed type does not seem to be initialized”
  warning。

## Design direction for this batch

- `process` 高层 builder contract 应该在 `tests/nextpas.core.process/test_process/test_process.lpr`
  里锁定，而不是主要漂在 `platform.process` suite。
- PATH 解析应提升到“只接受真正可执行候选”的语义，并优先复用现有平台能力，
  避免 `process` 模块自带一份较弱的 PATH 搜索实现。
- warning 清理不能靠压制编译器，而要让 `TProcessOutput` 的初始化路径对编译器也清晰可证。
