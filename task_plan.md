# Task Plan: P0/P1 verification fidelity + unit resolution correctness

## Goal

按外部审查报告的优先级收口当前批次，把“看起来完整”推进到“结果可信、边界诚实、核心路径更正确”。

这轮收口标准不是再扩一批新架构名词，而是先把当前仓库最危险的两类问题关掉：

- `harness` / CI 不能再给出容易误导的假绿结果
- unit resolver 不能再漏掉根单元 implementation uses、错绑 unit 名，或让 synthetic
  `System` 遮蔽真实源码

同时，这轮还要把文档、规划文件和仓库卫生同步到真实实现状态。

说明：下面的 addendum 按时间保留当时的批次范围；当前 reality 以最新 addendum 与
fresh `bash build/verify_local.sh` 为准。

当前最新本轮为 Batch 104 Function Result Call Type Mismatch Evidence；并行收口包含
Platform Time L0 Surface Coverage 与 Platform API Boundary Cleanup；Batch 103 Object Release
Invalid Trap Policy、Batch 102 Object Release Invalid Boundary、
Batch 101 Object Release Poison Contract、Batch 100 Object Release Valid Boundary、
Batch 99 Object Header Magic Validation、
Batch 98 Platform Time FFI Boundary、
Batch 97 Object Header Ownership Contract、
Batch 96 Object Allocation Helper Boundary 与 Batch 93 Platform Thread FFI Boundary 是并行
platform/core 工作流保留下来的已完成记录。

## Addendum: 2026-05-26 Batch 104 Function Result Call Type Mismatch Evidence

### Goal

把 Batch 81 之前明确 deferred 的 root-owned function result evidence 推进成第一条安全切片：
当 bare procedure/function call 只有 root-owned 单一 target、arity 已匹配，且参数是同一 root source 中
零参 function 的内建标量/字符串返回值时，若与 target param signature 明确不兼容，发出
`sema.type-mismatch`。

本批次新增并冻结：

- `function Flag: Boolean; Pick(Flag);` 调 `Pick(Value: Integer)` 必须失败为
  `sema.type-mismatch`，且失败调用不注册 `call` binding。
- stable function-result evidence 只接受 root-owned、零参、`function` symbol，且返回类型必须通过
  `TypeIdHasStableScalarFact(...)`。
- imported function result、带参 function result、class/record/alias/Pointer/Text/Variant、member
  function result、多 overload signature no-match 继续 deferred。
- `build/verify_local.sh` 新增 `type-mismatch-function-result-call-check`，固定 stage0 failure
  projection 与 final verify envelope 的 `typeMismatchFunctionResultCallCheck`。

### Architecture Decision

这是 value fact evidence 的第三条安全切片，不是完整 expression evaluator：

- root-owned function symbol 已经在 semantic model 中有 owner、param count 和 return type id，因此
  零参 builtin scalar/string result 可以作为 compile-time type evidence。
- 只扩展 diagnostics evidence，不改变 callable lookup 的 root/imported 优先级，不引入 implicit
  conversion、ranking、effect analysis 或 function pointer semantics。
- 失败时仍通过现有 `LookupCallBindingDeclaration(...)` 的 `type-mismatch` failure kind 投影到
  diagnostics sink。

### Status

Completed

### Planned Steps

- [x] RED：把 focused semantic guard 从 function result deferred 改成 `sema.type-mismatch`
- [x] 新增 `tests/fixtures/type_mismatch_function_result_call` 与 verify gate
- [x] 在 stable evidence 中接受 root-owned 零参 builtin function result
- [x] focused semantic gate 转绿
- [x] 同步 semantic model / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 失败在
  `semantic-call-bindings-failure=missing-bare-function-result-type-mismatch-diagnostic`。
- GREEN focused: focused semantic test 输出 `semantic-call-bindings-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出
  `type-mismatch-function-result-call-check=pass`、`typeMismatchFunctionResultCallCheck":"pass"`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不把 imported function result 纳入 type mismatch diagnostics
- 不把带参 function result / function pointer / member function result 纳入 evidence
- 不实现 implicit conversion / overload ranking / no-matching-overload diagnostics
- 不修改 `core/`

## Addendum: 2026-05-26 Platform Time L0 Surface Coverage

### Goal

把 `platform.time` 的可用性证明保持在 L0 系统平台 API 边界内：

- 新增 platform clock 示例项目，展示 `platform_monotonic_ns`、`platform_realtime_ns`、
  `platform_monotonic_resolution_ns` 的系统 API contract。
- 新增 platform clock 基准项目，测量 monotonic/realtime 原生 clock 调用开销。
- 新示例/基准必须位于 `nextpas.core.platform.time` 命名空间，不能出现 `Stopwatch`、`Duration`
  等 L1 convenience API。
- `build/verify_local.sh` 必须把 platform.time 边界测试、示例和基准纳入官方本地验证 envelope。

### Architecture Decision

- `platform.time` 是 L0 clock source，不是计时器、秒表或日期时间库。
- `Duration` / `Instant` / `Stopwatch` / Timer 属于 L1 `nextpas.core.time`
  或后续独立 `nextpas.core.stopwatch`，不能出现在 `nextpas.core.platform.*` 的 API、示例或基准里。
- 示例和基准只调用 platform-owned clock 函数，输出 machine-readable 状态行，便于 gate 检查。
- 旧 `codex/platform-time-integration` 中的 `demo_stopwatch` / `bench_platform_time` 不按原样合入；
  正确的 L1 time 示例应另走 `nextpas.core.time` 批次。

### Status

Completed; verification passed.

### Planned Steps

- [x] RED：确认 `core/examples/nextpas.core.platform.time/platform_time_clock` 缺失
- [x] RED：确认 `core/benchmarks/nextpas.core.platform.time/bench_platform_time_clock` 缺失
- [x] 新增 L0 platform clock 示例项目和独立 Makefile
- [x] 新增 L0 platform clock 基准项目和独立 Makefile
- [x] 新增 L0 boundary guard 测试，防止 L1 time API 混入 platform.time
- [x] `build/verify_local.sh` 新增 platform.time boundary/example/benchmark gates
- [x] 运行 focused example/benchmark
- [x] 运行 `make -C core test`
- [x] 运行 `make -C core examples`
- [x] 运行 `make -C core benchmarks`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 复盘

### Verification

- RED: `test -f core/examples/nextpas.core.platform.time/platform_time_clock/platform_time_clock.lpr`
  失败。
- RED: `test -f core/benchmarks/nextpas.core.platform.time/bench_platform_time_clock/bench_platform_time_clock.lpr`
  失败。
- Focused GREEN: `make -C core/examples/nextpas.core.platform.time/platform_time_clock run` 输出
  `platform-time-clock-status=pass`。
- Focused GREEN: `make -C core/benchmarks/nextpas.core.platform.time/bench_platform_time_clock run`
  输出 `platform-time-bench-status=pass`。
- RED: `test -f core/tests/nextpas.core.platform.time/test_platform_time_l0_boundary/test_platform_time_l0_boundary.lpr`
  失败。
- Focused GREEN: `make -C core/tests/nextpas.core.platform.time/test_platform_time_l0_boundary test`
  输出 `nextpas.core.platform.time.l0_boundary: 4 total, 4 passed, 0 failed`。
- Aggregate GREEN: `make test` 输出 `All tests passed.`。
- Aggregate GREEN: `make examples` 输出 `All examples compiled.`。
- Aggregate GREEN: `make benchmarks` 输出 `All benchmarks passed.`。
- Official GREEN: fresh `bash build/verify_local.sh` 输出
  `corePlatformTimeL0BoundaryCheck=pass`、`corePlatformTimeExampleCheck=pass`、
  `corePlatformTimeBenchCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不新增 `Stopwatch` 示例或基准
- 不把 `Duration` / `Instant` 的 L1 行为放进 platform 命名空间
- 不改变 `platform.time` ABI 或 clock conversion 语义
- 不从旧 `platform-time-integration` 整条合入混杂改动

## Addendum: 2026-05-26 Batch 103 Object Release Invalid Trap Policy

### Goal

把 Batch 102 的 no-op invalid-release boundary 推进成最小真实 failure policy：

- `@np_object_release_invalid(ptr %raw, i64 %size, i64 %magic)` 必须调用 `@llvm.trap()`。
- trap 后必须发出 `unreachable`，避免非法释放路径继续被视为可正常返回。
- 本批仍不实现结构化 diagnostics、不抛 Pascal exception、不接 `core/` allocator，也不改变 object
  header layout。

### Architecture Decision

invalid release 当前采用 always-trap 策略：

- nil receiver 仍由 `@np_object_free_release` 的 null guard 安全跳过。
- magic-valid release 仍走 `@np_object_release_valid` 并 poison header magic。
- magic mismatch 代表 double free 或 foreign payload pointer；进入 invalid helper 后触发
  `llvm.trap`，这是当前最小 fatal runtime behavior。
- helper ABI 保持 Batch 102 的 `raw` / `size` / `magic` 证据参数，后续结构化 diagnostics 可以复用。

### Status

Completed

### Planned Steps

- [x] 写 RED：invalid helper 必须调用 `@llvm.trap()`、发出 `unreachable` 并声明 intrinsic
- [x] 实现 LLVM invalid-release trap policy
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-object-free-release-invalid-trap-call`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不修改或暂存 `core/`
- 不改变 object header layout
- 不实现结构化 diagnostics / Pascal exception path
- 不实现完整 dynamic dispatch runtime

## Addendum: 2026-05-26 Batch 102 Object Release Invalid Boundary

### Goal

继续推进目标树 G3 / G1.5，把 Batch 101 后仍然无声 skip 的 magic mismatch 路径升级成
compiler-owned invalid-release boundary：

- `@np_object_free_release` 在 header magic mismatch 时必须进入 `invalid:` 块。
- `invalid:` 块必须调用 `@np_object_release_invalid(ptr %raw, i64 %size, i64 %magic)`，再汇合到
  `done:`。
- 本批只固定 invalid-release ABI 和后续 diagnostics/trap 挂载点，不实现 trap、不抛异常、不接
  `core/` allocator，也不改变 object header layout。

### Architecture Decision

invalid-release helper 当前是 no-op boundary：

- `raw` 仍是 object header 起点，`size` 和 `magic` 是已经读取出的 header 证据。
- mismatch path 不再和 nil receiver 一样直接静默进入 `done:`；它先进入唯一的 invalid-release
  hook，再回到 `done:`。
- helper 不做额外 dereference，不 poison header，不调用 allocator free；后续 diagnostics/trap 只能从
  这个边界继续演进。

### Status

Completed

### Planned Steps

- [x] 写 RED：magic mismatch 必须进入 `invalid:` 并调用 invalid-release helper
- [x] 实现 LLVM invalid-release boundary helper
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-object-free-release-header-magic-branch`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不修改或暂存 `core/`
- 不改变 object header layout
- 不实现 diagnostics / trap / exception failure path
- 不实现完整 dynamic dispatch runtime

## Addendum: 2026-05-26 Platform API Boundary Cleanup

### Goal

纠正 platform 模块的归属边界：`platform` 是 L0 系统平台 API/ABI 适配层，只承载 OS/CPU、
thread/sync/time clock 等低层契约；`Stopwatch`、`Duration` 等用户便利抽象属于
`nextpas.core.time` 或后续更高层模块。

本批只做边界收口：

- platform.time focused tests 迁入 `core/tests/nextpas.core.platform.time/`。
- `nextpas.core.time/test_time` 继续只覆盖 L1 time public API。
- 顶层 `build/verify_local.sh` 的 platform time gates 指向 platform 命名空间。
- 平台设计约定同步 Windows FFI 文件名，并明确 Linux/macOS/Windows/Unix/BSD/Android 目标。

### Architecture Decision

- `platform` 不放 stopwatch 示例，不把 L1 time API 伪装成 platform 成果。
- platform 子模块的测试、基准、示例命名必须贴着 platform contract；L1 模块使用自己的命名空间。
- 本批不新增平台 ABI、不改 time/sync/thread 行为，只修正 ownership 和验证入口。

### Status

Completed; verification passed.

### Planned Steps

- [x] 停止并删除错误的 `platform-time-extras-preview` 切片，确认未合入 main
- [x] 写 RED：确认 `nextpas.core.platform.time` focused test 目录缺失
- [x] 将 platform.time helper/no-FPC focused tests 移到 `nextpas.core.platform.time`
- [x] 同步 `build/verify_local.sh` focused gate 路径
- [x] 同步平台设计约定中的目标平台和 Windows FFI 文件名
- [x] 跑 focused platform.time tests
- [x] 跑 `make -C core test`
- [x] 跑 `bash build/verify_local.sh`
- [x] 跑 `make -C core examples` 与 `make -C core benchmarks`
- [x] 复盘并准备提交/安全合并

### Verification

- RED: `test -d core/tests/nextpas.core.platform.time/test_platform_time_helpers` 失败，确认
  platform.time tests 仍挂在 L1 time 命名空间。
- Focused GREEN: `test_platform_time_helpers` 输出 `9 total, 9 passed, 0 failed`；
  `test_platform_time_no_fpc_units` 输出 `1 total, 1 passed, 0 failed`。
- Aggregate GREEN: `make -C core test` 输出 `All tests passed.`。
- Examples/benchmarks GREEN: `make -C core examples` 输出 `All examples compiled.`；
  `make -C core benchmarks` 输出 `All benchmarks passed.`。
- Official GREEN: fresh `bash build/verify_local.sh` 输出 `corePlatformTimeHelpersCheck=pass`、
  `corePlatformTimeNoFpcCheck=pass`、`corePlatformTimeWin64Check=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不新增 stopwatch 示例或 benchmark
- 不改 `nextpas.core.time` 的 public API
- 不改 platform.time ABI/FFI 行为
- 不声明非 Linux 主机 runtime 已验证


## Addendum: 2026-05-26 Batch 101 Object Release Poison Contract

### Goal

继续推进目标树 G3 / G1.5，把 Batch 100 的 no-op valid-release boundary 推进成最小安全行为：

- `@np_object_release_valid(ptr %raw, i64 %size)` 必须在 valid release 后把 header magic 清零。
- 后续重复释放同一 payload pointer 时，会因为 magic mismatch 走 `done:` skip 路径。
- 本批仍不实现真实 allocator free，不接入 `core/` allocator，不改变 object header layout。

### Architecture Decision

valid-release helper 当前只做 header poisoning：

- raw pointer 仍是 object header 起点，magic slot 固定为 `raw + 8`。
- poison 值固定为 `0`，与 live object magic `1313882451` 区分。
- payload size 保留不变，给后续 diagnostics/statistics/free 继续使用。

### Status

Completed

### Planned Steps

- [x] 写 RED：valid release helper 必须定位 magic slot 并 `store i64 0`
- [x] 实现 LLVM release poison 行为
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-object-free-release-poison-magic-slot`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不修改或暂存 `core/`
- 不改变 object header layout
- 不实现 diagnostics / trap / exception failure path
- 不实现完整 dynamic dispatch runtime

## Addendum: 2026-05-26 Batch 100 Object Release Valid Boundary

### Goal

继续推进目标树 G3 / G1.5，把 Batch 99 的 `release:` 占位块升级为 compiler-owned release
boundary：

- `@np_object_free_release` 只有在 object header magic 校验通过后，才能调用
  `@np_object_release_valid(ptr %raw, i64 %size)`。
- 传入 release boundary 的必须是 header raw pointer 与 payload size，避免后续 allocator free
  重新猜测 object layout。
- 当前底层仍只有 bump-style `@np_alloc`，没有配对 free；本批只固定 valid-release ABI，不声明真实
  allocator free 已完成，不修改 `core/`。

### Architecture Decision

释放路径现在分三层固定：

- null receiver 直接进入 `done:`。
- 非 null receiver 回退读取 header；magic mismatch 直接进入 `done:`。
- magic match 进入 `release:` 并调用 `@np_object_release_valid(ptr %raw, i64 %size)`；该 helper
  当前是内部 no-op，占住 future allocator free / poison / statistics 的唯一挂载点。

### Status

Completed

### Planned Steps

- [x] 写 RED：valid release 分支必须调用 `@np_object_release_valid(ptr %raw, i64 %size)` 并存在 helper
- [x] 实现 LLVM release valid boundary helper
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-object-free-release-valid-boundary-call`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不修改或暂存 `core/`
- 不改变 object header layout
- 不实现 diagnostics / trap / exception failure path
- 不实现完整 dynamic dispatch runtime

## Addendum: 2026-05-26 Batch 99 Object Header Magic Validation

### Goal

继续推进目标树 G3 / G1.5，在不修改 `core/` 的前提下，把 object release helper 从“读取
header”推进到“校验 header magic 并分流”：

- `@np_object_free_release` 读取 payload 前 16 bytes header 后，必须校验 magic
  `1313882451`。
- 合法 header 进入 `release:` 占位块，非法 header 直接汇合到 `done:`，为后续真实 allocator
  free / diagnostics / trap 固定分支形状。
- 本批仍不实现真实 free，不接入 `core/` allocator，不改变 object header layout。

### Architecture Decision

object helper 的 ownership contract 继续保持一个入口、一种 header layout：

- Header layout 仍是 16 bytes：offset 0 为 payload size，offset 8 为 magic
  `1313882451`。
- `@np_object_free_release` 先保留 null guard，再回退到 header 并读取 size / magic。
- magic mismatch 当前是 defensive skip：直接进入 `done:`；magic match 进入 `release:` 占位块，
  以后 allocator free 必须挂到这个块里，避免非法 payload pointer 继续走释放路径。

### Status

Completed

### Planned Steps

- [x] 写 RED：release helper 必须包含 magic compare、valid/invalid branch 和 `release:` label
- [x] 实现 LLVM release helper magic 校验分支
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-object-free-release-header-magic-check`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不修改或暂存 `core/`
- 不改变 object header layout
- 不实现 diagnostics / trap / exception failure path
- 不实现完整 dynamic dispatch runtime

## Addendum: 2026-05-26 Batch 98 Platform Time FFI Boundary

### Goal

从当前 main 重新整理 clean preview，把 `platform.time` 从 FPC 平台单元迁到 nextPas-owned
FFI 边界：

- `nextpas.core.platform.time` 不直接 `uses Linux`、`UnixType`、`Windows` 等 FPC 平台单元。
- POSIX、macOS 和 Windows ABI 声明分别由 nextPas 自己的 FFI 单元承载。
- time conversion helper 对溢出、负 timespec 和 resolution rounding 给出稳定契约。
- QPC / mach timebase 换算在极大 divisor 的 fractional 路径上不能把可表示结果误判为饱和。
- official local verification 覆盖 no-FPC 静态检查、helper 行为和 Win64 compile-only。

### Status

Completed.

### Planned Steps

- [x] 写 RED：`platform.time` 静态测试禁止 FPC 平台单元和 implementation-local external ABI
- [x] 将 POSIX clock API 改为 `nextpas.core.platform.posix.ffi`
- [x] 新增 `nextpas.core.platform.darwin.ffi`
- [x] 将 Windows QPC/FILETIME API 追加到 `nextpas.core.platform.windows.ffi`
- [x] 补 helper 边界测试和 Win64 compile-only
- [x] 跑 aggregate / official verification
- [x] 复盘后提交并择优合并

### Architecture Decision

- `posix.ffi` 保留 sync/thread 所需 pthread 与 sleep/yield/sysconf 声明，同时追加 time 所需
  `clock_getres`。
- `windows.ffi` 保留 thread/TLS 声明，同时追加 time 所需 `FILETIME`、
  `QueryPerformanceFrequency`、`QueryPerformanceCounter`、`GetSystemTimeAsFileTime`。
- `platform.time` 只保留 platform contract 与换算逻辑，所有 native ABI 声明都在 FFI 单元。
- conversion helpers 用饱和和 ceil 策略避免溢出或高估精度；fractional multiply/divide
  在普通路径保持 O(1)，只在乘法会溢出的边界走逐位 fallback。

### Verification

- RED: `test_platform_time_no_fpc_units` 旧实现失败在 `UnixType`。
- Focused GREEN 已通过：time no-FPC 1/1、time helpers 9/9、time 13/13。
- Win64 compile-only 已通过：`fpc -Twin64 -Cn ... test_time.lpr` 编译 1931 行。
- Aggregate 已通过：`make -C core test`、`make -C core examples`、
  `make -C core benchmarks`。
- Full verification 已通过：fresh `bash build/verify_local.sh` 输出
  `corePlatformTimeHelpersCheck=pass`、`corePlatformTimeNoFpcCheck=pass`、
  `corePlatformTimeWin64Check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现完整 DateTime/timezone/timer/scheduler/async runtime。
- 不声明 macOS 或 Windows runtime 行为已经在真实主机运行验证。
- 不合并旧 `platform-time-integration` 中过期的 sync/thread/compiler 内容。

## Addendum: 2026-05-26 Batch 97 Object Header Ownership Contract

### Goal

继续推进目标树 G3 / G1.5，把 Batch 96 的对象分配/释放 helper boundary 升级为最小
object header ownership contract：

- `@np_object_alloc` 必须分配 `size + 16`，写入 payload size 与 magic header，再返回 payload
  pointer。
- `@np_object_free_release` 必须从 payload pointer 回退到 header 并读取 size / magic，为后续真实
  allocator free 和 ownership validation 固定入口。
- 本批仍不实现真实 free，不改变 constructor lowering，不修改 `core/`。

### Architecture Decision

对象 helper 先拥有 object header 的物理布局，再逐步接 allocator：

- Header layout 当前固定为 16 bytes：offset 0 存 payload size，offset 8 存 magic
  `1313882451`。
- `@np_object_alloc` 从底层 `@np_alloc` 申请 header + payload，返回 header 后的 object payload
  pointer，保持 class field / VMT store 使用 payload 起点。
- `@np_object_free_release` 仍由 object-free nil guard 后调用；helper 自身也防御性处理 null，并从
  payload pointer 回退 16 bytes 读取 header。读取 header 只是 ownership contract 证据，还不释放。

### Status

Completed

### Planned Steps

- [x] 写 RED：allocation helper 必须写 header，release helper 必须读取 header
- [x] 实现 LLVM helper header 写入与 release header 读取
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: class alloc focused test 失败在 `missing-hir-class-alloc-header-size`；
  object-free focused test 失败在 `missing-object-free-release-header-base`。
- GREEN focused: focused tests 输出 `hir-class-alloc-contract-status=pass` 与
  `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-class-alloc-contract=pass`、
  `hir-object-free-contract=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不接入 `core/` allocator 或修改 `core/`
- 不改变 constructor lowering 或 object payload layout
- 不实现完整 dynamic virtual dispatch runtime
- 不让 implicit runtime 自动进入 backend extra assemble/link

## Addendum: 2026-05-26 Batch 96 Object Allocation Helper Boundary

### Goal

继续推进目标树 G3 / G1.5，把对象生命周期 ABI 从释放侧补齐到分配侧：

- `class_alloc` LLVM lowering 必须调用 compiler-owned `@np_object_alloc(i64 size)`。
- `@np_object_alloc` 当前只作为内部 helper boundary，委托到底层 `@np_alloc`。
- 这一步只建立 object allocation/release 的成对 runtime 接入口；不声明真实 object header、
  ownership metadata、allocator free 或完整 dynamic dispatch runtime 已完成。
- 不修改 `core/`。

### Architecture Decision

对象生命周期边界先分层稳定，再逐步替换底层实现：

- HIR 仍用 `class_alloc` intrinsic 表达 class instance allocation intent。
- LLVM emitter 不再让 `class_alloc` 直接碰底层 bump allocator，而是生成
  `call ptr @np_object_alloc(i64 ...)`。
- `@np_object_alloc` 当前内部调用 `@np_alloc(i64 %size)`；后续 object header、allocator
  ownership 和释放侧真实 free 都应收敛到这个 helper/ABI，而不是散落到 class lowering 中。

### Status

Completed

### Planned Steps

- [x] 写 RED：focused HIR test 必须看到 `@np_object_alloc` call、helper 定义和 `@np_alloc`
      delegate，并拒绝 class allocation site 直接 `@np_alloc`
- [x] 实现 LLVM class allocation helper lowering
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-hir-class-alloc-object-helper-call`。
- GREEN focused: focused HIR test 输出 `hir-class-alloc-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-class-alloc-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不定义 object allocation header / ownership metadata
- 不改变 constructor lowering
- 不实现完整 dynamic virtual dispatch runtime
- 不让 implicit runtime 自动进入 backend extra assemble/link
- 不修改 `core/`

## Addendum: 2026-05-26 Batch 95 Object-free Heap-release Hook

### Goal

继续推进目标树 G3 / G1.5，把 `object-free-runtime` 中已经记录的 `heap-release true`
从语义意图推进到 HIR/LLVM 后端可见边界：

- `THIRBuilder` 在匹配 owned `Destroy` 后，必须基于 `heap-release true` 追加
  `np.system.object_free.release` intrinsic。
- `THIRLlvmEmitter` 必须把 release marker 降成非空分支内的
  `call void @np_object_free_release(ptr ...)`，顺序为 nil check -> destroy label ->
  `Destroy` call -> release hook -> end label。
- 本批只建立稳定 backend/runtime helper hook；当前 helper 是内部空实现，不声明真实 allocator
  free、object header ownership、完整 dynamic dispatch runtime 或完整 `System` 平替已完成。
- 不修改 `core/`。

### Architecture Decision

object-free lifecycle contract 现在分三段传递：

- semantic typed HIR 继续记录 receiver、effective `Destroy`、`nil-guard true` 与
  `heap-release true`。
- `THIRBuilder` 把 `heap-release true` 保存到 pending object-free contract；只有紧随的
  matching owned `Destroy` 成功消费该 contract 后，才追加 `np.system.object_free.release`。
- `THIRLlvmEmitter` 允许 owned destroy 与 release marker 留在同一个 `objectfree.destroy.*`
  非空分支里；release hook 关闭 guard 并汇合到 `objectfree.end.*`。

### Status

Completed

### Planned Steps

- [x] 写 RED：focused HIR test 必须看到 release intrinsic、LLVM release call 和 release helper
- [x] 实现 builder 侧 `heap-release true` pending contract 消费
- [x] 实现 LLVM release hook emission 与内部 helper 边界
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-object-free-release-intrinsic`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不定义 object allocation header / ownership metadata
- 不实现完整 dynamic virtual dispatch runtime
- 不让 implicit runtime 自动进入 backend extra assemble/link
- 不修改 `core/`

## Addendum: 2026-05-26 Batch 93 Platform Thread FFI Boundary

### Goal

把 `platform.thread` 从 FPC 平台单元迁到 nextPas-owned FFI 边界，并和已合入主线的
`platform.sync` FFI 声明兼容；本 clean preview 基于 `main@ad236a2`，不混入独立
`platform.time` worktree 的提交。

### Status

Completed.

### Planned Steps

- [x] 写 RED：`platform.thread` 静态测试禁止直接引用 FPC 平台单元和旧 Win32 `@AProc` entry
- [x] 将 POSIX 分支改为 `nextpas.core.platform.posix.ffi`
- [x] 将 Windows 分支改为 `nextpas.core.platform.windows.ffi` trampoline state
- [x] 补 detach focused 行为测试
- [x] 从最新 `main@ad236a2` 整理 clean merge-preview，避免把独立 `platform.time` commit 混入
- [x] 跑 focused / aggregate / verify-local 验证
- [x] 复盘后提交

### Architecture Decision

- POSIX create 返回 nextPas-owned opaque state pointer，join/detach 成功后释放 state。
- Windows create 返回 state pointer，state 内部保存 native handle、user proc、arg、return value 和
  refcount；thread entry 与 join/detach 各释放自己的引用。
- `posix.ffi` 保留 sync 所需 mutex/rwlock/condvar pthread 声明，同时追加 thread 所需
  detach/self/TLS/nanosleep/sched_yield/sysconf。
- `windows.ffi` 本批只声明 thread/TLS/yield/sleep/cpu-count 所需 Win32 ABI，不携带 time-only FFI。

### Verification

- RED: `test_platform_thread_no_fpc_units` 旧实现失败在 `BaseUnix`。
- Focused GREEN 已通过：thread no-FPC static 1/1、platform.thread 7/7、nextpas.core.thread 6/6、
  platform.sync 14/14、platform.sync.sizes 4/4。
- Win64 compile-only 已通过：`fpc -Twin64 -Cn ... test_platform_thread.lpr` 编译 875 行。
- Aggregate 已通过：`make -C core test`、`make -C core examples`、`make -C core benchmarks`。
- Official verify 已通过：`bash build/verify_local.sh` 输出 `verify-local=pass`、
  `human-summary=local verification passed`。

### Non-goals

- 不修改 `platform.sync` 的 public API 或 futex/wait-wake 语义。
- 不声明 Windows runtime 行为已在真实 Windows 主机运行验证；本批只做 Win64 compile-only。
- 不合并独立 `platform.time` worktree 的 hardening commit。
- 不引入完整 thread pool、scheduler 或 async runtime 设计。

## Addendum: 2026-05-26 Batch 94 Object-free LLVM Nil Guard

### Goal

继续推进目标树 G3 / G1.5，把 `np.system.object_free` 从 HIR lifecycle marker 推进到
LLVM HIR emitter 可见的真实 nil guard：

- `np.system.object_free` 必须在 LLVM 文本中生成 receiver pointer 的 `icmp eq ptr ..., null`
  和 conditional branch。
- `np.system.object_free.destroy` 必须落在非空 `objectfree.destroy.*` 分支内，并在析构后
  汇合到 `objectfree.end.*`。
- owned destroy 必须复用 object-free contract 已解析的 receiver pointer，避免 guard 与析构
  call 之间出现额外 receiver reload，把 call 挤出非空分支。
- 本批只实现 nil branch 与 owned destroy call enclosure；不声明 allocator free、完整 dynamic
  dispatch runtime、implicit `System.pas` 自动 assemble/link 或完整 `System` 平替已完成。
- 不修改 `core/`。

### Architecture Decision

object-free 的 backend-facing contract 现在分两层落地：

- `THIRBuilder.ProcessObjectFreeRuntime(...)` 仍负责把 semantic contract 投影为
  `np.system.object_free` marker，并记录 pending destroy 名称、receiver 名称和 receiver pointer。
- 紧随的匹配 `call-runtime <Destroy>` 被改写为 `np.system.object_free.destroy` owned marker，
  且直接复用 pending receiver pointer，不再重复生成 receiver load。
- `THIRLlvmEmitter` 在看到 `np.system.object_free` 时打开 `objectfree.destroy.*` /
  `objectfree.end.*` guard，在 owned destroy call 后关闭 guard；普通 call lowering 继续复用统一
  `EmitCallInstr(...)`。

### Status

Completed

### Planned Steps

- [x] 写 RED：LLVM output 必须包含 object-free null check / conditional branch / destroy-end labels
- [x] 实现 builder receiver pointer reuse，保证 owned destroy call 位于 guard 内
- [x] 实现 `THIRLlvmEmitter` object-free guard start / close
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-object-free-llvm-null-check`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不实现完整 dynamic virtual dispatch runtime
- 不让 implicit runtime 自动进入 backend extra assemble/link
- 不修改 `core/`

## Addendum: 2026-05-26 Batch 92 Object-free Owned Destroy HIR Marker

### Goal

继续推进目标树 G3 / G1.5，让 `np.system.object_free` 不只作为孤立 marker 存在，还要约束
紧随其后的 effective `Destroy` lowering：

- typed HIR 中 `object-free-runtime` 后接匹配的 `call-runtime <Destroy>` 时，HIR builder
  不能再把这个析构投影成裸 `hikCall`。
- 该析构要成为 `np.system.object_free` contract 拥有的 HIR marker：
  `hikIntrinsic` / `np.system.object_free.destroy`，并保留原 `CallTarget` 与 receiver pointer
  operand。
- LLVM HIR emitter 继续把 owned destroy marker lowering 成现有 call，保持当前可执行析构行为；
  本批不声明真实 nil branch、allocator free 或完整 dynamic dispatch runtime 已完成。
- 不修改 `core/`。

### Architecture Decision

`object-free-runtime` 与后续 `Destroy` 是一个生命周期组，而不是两个互不相关的普通操作：

- `THIRBuilder.ProcessObjectFreeRuntime(...)` 发出 `np.system.object_free` 后，记录一个只允许被
  紧随 `call-runtime` 消费的 pending receiver/destroy contract。
- `ProcessCallRuntime(...)` 只有在 destroy target 和首个 `var <receiver>` operand 同时匹配时，
  才把该 call 改写为 `np.system.object_free.destroy` intrinsic；否则仍保持普通 `hikCall`。
- LLVM emitter 抽出统一 call emission helper，让 `hikCall` 和 owned destroy intrinsic 使用同一
  lowering 逻辑，避免复制和行为漂移。

### Status

Completed

### Planned Steps

- [x] 写 RED：匹配 object-free 后续 `TObject.Destroy` 不能再是裸 `hikCall`
- [x] 实现 pending object-free destroy contract consumption
- [x] 让 LLVM emitter 对 owned destroy marker 走现有 call lowering
- [x] 同步目标树 / runtime / semantic / RTL / stage0 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `plain-object-free-destroy-call`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不生成真实 nil branch
- 不实现完整 dynamic virtual dispatch runtime
- 不让 implicit runtime 自动进入 backend extra assemble/link
- 不修改 `core/`

## Addendum: 2026-05-26 Batch 91 Object-free Contract HIR Bridge

### Goal

继续推进目标树 G3 / G1.5，把 Batch 90 已经产生的 `np.system.object_free`
typed HIR contract 接到下一层 HIR：

- `THIRBuilder` 不能再静默忽略 `object-free-runtime`。
- HIR 中要有稳定、可验证的 `np.system.object_free` intrinsic marker，保留 receiver pointer
  operand 和 effective `Destroy` target。
- 本批只建立 compiler-owned HIR/backend-facing contract，不声明真实 nil branch、allocator free、
  dynamic dispatch runtime 或 implicit `System.pas` link 已完成。
- 不修改 `core/`。

### Architecture Decision

`object-free-runtime` 是 compound lifecycle contract，不是普通函数调用：

- semantic typed HIR 仍负责选择 effective `Destroy` 并记录 nil guard / heap release intent。
- HIR builder 把 receiver 解析为 pointer operand，把 effective `Destroy` 名称放入
  `CallTarget`，并用 `hikIntrinsic` / `np.system.object_free` 表示后续 runtime helper 接口。
- 当前 LLVM HIR emitter 对这个 intrinsic 仍不展开真实代码，避免把“可见契约”误说成
  “释放实现已完成”。

### Status

Completed

### Planned Steps

- [x] 写 RED：`object-free-runtime` 必须投影成 HIR `np.system.object_free` intrinsic
- [x] 实现 `THIRBuilder.ProcessObjectFreeRuntime`
- [x] 把 focused HIR gate 纳入 `build/verify_local.sh`
- [x] 同步目标树 / semantic / runtime 文档与持续记录
- [x] 运行 focused gate 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused HIR test 失败在 `missing-object-free-hir-intrinsic`。
- GREEN focused: focused HIR test 输出 `hir-object-free-contract-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `hir-object-free-contract=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现真实 allocator free
- 不生成真实 nil branch
- 不实现完整 dynamic virtual dispatch runtime
- 不让 implicit runtime 自动进入 backend extra assemble/link
- 不修改 `core/`

## Addendum: 2026-05-26 Platform Sync Merge-preview Closeout

### Goal

把 `platform.sync` hardening 分支合入最新主线预览分支，确保主线新增 core/test 结构与
platform.sync 的无 FPC 平台单元依赖、测试、example、benchmark、官方验证入口能够同时成立。

### Status

Completed

### Planned Steps

- [x] 在干净的 `codex/platform-sync-merge-preview` worktree 合并 `codex/platform-sync-hardening`
- [x] 择优解决文档和跟踪文件冲突
- [x] 收紧 `linux.ffi`，只保留 external ABI 声明
- [x] 为主线新增 core 测试项目补齐单独 Makefile
- [x] 运行 platform.sync focused tests、examples、benchmarks、core aggregate gates 和顶层验证
- [x] 简短 review 后提交 merge-preview

### Verification

- `make -C core test`: All tests passed。
- `make -C core examples`: All examples compiled。
- `make -C core benchmarks`: All benchmarks passed。
- `bash build/verify_local.sh`: `verify-local=pass`、
  `human-summary=local verification passed`。

### Next

主 checkout 仍有未提交同事工作；preview 分支验证通过后，等待主线现场干净或由负责人确认可集成，
再合入 `main`、删除旧 `platform-sync-hardening` worktree，并从最新主线重新开新 worktree。

## Addendum: 2026-05-26 Batch 89 Inherited TObject.Destroy Free Lowering

### Goal

继续推进目标树 G3 / G1.5，把 Batch 88 的 source-backed implicit `System` truth 往对象生命周期
下一层推进：

- 普通 `class` 即使没有显式父类，也要继承 `System.TObject` 的 VMT slot/function truth。
- `Worker.Free` 在 no-fold typed HIR 中不能只停在 `TObject.Free` binding；当 receiver class
  只继承 `System.TObject.Destroy` 时，也要 lowering 到有效 `TObject.Destroy` runtime call。
- 这条 gate 只证明 compiler semantic/HIR 层的 lifecycle intent，不宣称完整 heap free、完整
  virtual dispatch 或 backend/link 已接管 nextPas `System.pas`。
- 不修改 `core/`。

### Architecture Decision

这是最小 `Free -> effective Destroy` semantic lowering，不是完整对象释放：

- `ProcessClassFields(...)` 要同时消费显式父类和 `ProcessTypeSection(...)` 设置的隐式
  `ParentTypeId`，让隐式 `System.TObject` 的 VMT metadata 可以被子类复制。
- `Free` lowering 不再硬写 `TClass.Destroy`；它先查 `TClass$vmt_slot_Destroy`，再通过
  `TClass$vmt_func_<slot>` 找到当前有效 destructor，继承路径可落到 `TObject.Destroy`。
- 仍不在本批处理析构后的内存释放、nil guard、动态 dispatch table 运行时布局或 unit init/fini。

### Status

Completed

### Planned Steps

- [x] 写 RED：implicit source-backed `System` 下，普通 class 的 `Worker.Free` 必须 lowering 到继承的
      `TObject.Destroy`
- [x] 让隐式父类也复制父类 VMT slot/function metadata
- [x] 让 `Free` lowering 使用 VMT slot 对应的有效 destructor function name
- [x] 同步 System / runtime bootstrap / semantic docs 与持续记录
- [x] 运行 focused semantic test 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 失败在
  `semantic-call-bindings-failure=missing-implicit-system-free-inherited-destroy-lowering`。
- GREEN focused: focused semantic test 输出 `semantic-call-bindings-status=pass`。
- Full: fresh `bash build/verify_local.sh` 输出 `semantic-call-bindings-check=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现完整 FPC `System`
- 不实现完整 heap free / nil guard / dynamic virtual dispatch runtime
- 不让 implicit runtime 自动进入 backend extra assemble/link
- 不实现 unit init-fini
- 不修改 `core/`

## Addendum: 2026-05-26 Batch 88 Implicit Runtime Source-backed System Semantics

### Goal

继续推进目标树 G3 / G1.5，把 implicit runtime 的 `System` 从“只有 graph placeholder”
推进到“语义层可消费 target-installed `System.pas`”：

- 没有显式 `uses System` 的 program 也能在 semantic model 中看到 nextPas-owned
  `System.TObject`。
- 普通 `class` 的隐式父类必须能通过 implicit runtime source-backed `System` 指向
  `TObject`。
- `Worker.Free` 必须绑定到真实 `TObject.Free` method symbol，并从 `query definitions`
  回指 `units/linux-x86_64/System.pas`。
- build/backend 仍不能因为 implicit runtime 自动把 `System.pas` 当作额外 source-backed unit
  编译/链接。
- 显式 `uses System` 仍必须继续解析真实源码，并能把 implicit runtime 节点升级为
  `installed-source` provenance。

### Architecture Decision

这是 semantic truth upgrade，不是 full runtime/link upgrade：

- `EnsureRuntimeUnit` 只给 implicit runtime `System` 填入 target-installed `System.pas` 的
  `SourcePath`，但保留 `OriginClass=implicit-runtime`。
- `TCompilationSession.CollectAdditionalAssemblyBaseNames()` 已跳过 `implicit-runtime`，因此本批不会
  让所有程序额外 assemble/link `System.pas`。
- `ResolveDependency(...)` 遇到显式 `uses System` 时不能因为已有 implicit runtime source path
  就短路；它必须继续走 normal search，并让 `TUnitGraph.AddResolvedUnit(...)` 支持从
  source-backed implicit runtime 升级到 explicit source provenance。
- 不修改 `core/`。

### Status

Completed

### Planned Steps

- [x] 写 RED：无显式 `uses System` 的 `Worker.Free` 必须通过 implicit source-backed System 绑定
- [x] 让 implicit runtime `System` 指向 target-installed `units/linux-x86_64/System.pas`
- [x] 保持 explicit `uses System` 可升级 implicit runtime 节点，不被 source path 短路
- [x] 新增 stage0 query gate，固定 implicit `TObject.Free` binding / definition source path
- [x] 同步 System / RTL / runtime bootstrap / unit resolution / semantic docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused stage0 query 旧实现输出 `query-bindings=[]` 与 `query-definitions=[]`，缺少
  implicit source-backed `TObject.Free` binding。
- GREEN focused: rebuilt stage0 query 已显示 implicit fixture 中 `TWorker.typeParentId` 指向
  `TObject`，`query-bindings` 含 `Free` member-call，`query-definitions.targetSourcePath`
  为 `units/linux-x86_64/System.pas`。
- Full: fresh `bash build/verify_local.sh` 输出
  `stage0-query-system-object-free-implicit-check=pass`、
  `stage0QuerySystemObjectFreeImplicitCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现完整 FPC `System`
- 不让 implicit runtime 自动进入 backend extra assemble/link
- 不实现 destructor lowering / virtual dispatch / unit init-fini
- 不修改 `core/`

## Addendum: 2026-05-26 Batch 87 Source-backed System/TObject Truth

### Goal

推进目标树 G3 / G1.5，把 `Obj.Free` 从“缺 System 基线时临时 deferred”推进到
nextPas-owned source-backed truth：

- 提供最小 `System.pas` / `TObject` 源码事实，先覆盖 `Create` / `Destroy` / `Free`。
- 显式 `uses System` 时，resolver / sema 必须消费 target-installed `System.pas`，而不是只看到
  placeholder unit symbol。
- 普通 `class` 在已有 source-backed `System.TObject` 时默认继承 `TObject`。
- `Worker.Free` 必须通过继承 member lookup 绑定到真实 `TObject.Free` method symbol，并能从
  `query definitions` 回指 `units/linux-x86_64/System.pas`。

### Architecture Decision

这是最小 System/TObject truth，不是完整 FPC `System` 重写：

- canonical 位置落在 `rtl/core/system/System.pas`，target-installed truth 落在
  `units/linux-x86_64/System.pas`。
- implicit runtime edge 仍保持 placeholder；本批不让所有 implicit runtime 自动编译/链接
  `System.pas`，避免扩大到宿主 FPC `System` 影子边界。
- 当 source-backed `System.TObject` 已进 semantic model 时，class 默认父类由 `TypeId` 指向
  owner=`system` 的 `TObject`；member lookup 继续沿现有 `ParentTypeId` 链工作。
- 没有 source-backed System truth 的路径仍保持 `Free` deferred，避免把 runtime baseline 缺口误报成
  普通 unknown member。
- 不修改 `core/`。

### Status

Completed

### Planned Steps

- [x] 写 focused RED：显式 source-backed `System` 下普通 `class` 的 `Worker.Free` 必须绑定到
      `System.TObject.Free`
- [x] 新增最小 `rtl/core/system/System.pas` 与 target-installed `units/linux-x86_64/System.pas`
- [x] 让普通 class 在 source-backed `System.TObject` 已解析时默认继承 `TObject`
- [x] 新增 stage0 query fixture / gate，固定 `TObject.Free` symbol、`member-call` binding 和
      definition source path
- [x] 同步 System / RTL / runtime bootstrap / semantic docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 失败在
  `semantic-call-bindings-failure=missing-source-backed-system-free-binding`。
- GREEN focused: focused semantic test 输出 `semantic-call-bindings-status=pass`。
- Focused stage0 query with freshly rebuilt stage0: `query-bindings` 含 `Free` member-call，
  `query-definitions` target 为 `TObject.Free`，`targetSourcePath` 为
  `units/linux-x86_64/System.pas`。
- Full: fresh `bash build/verify_local.sh` 输出 `stage0-query-system-object-free-check=pass`、
  `stage0QuerySystemObjectFreeCheck":"pass"`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现完整 FPC `System`
- 不把 implicit runtime placeholder 自动升级为 source-backed compile/link
- 不实现 destructor lowering / virtual dispatch / unit init-fini
- 不修改 `core/`

## Addendum: 2026-05-26 Platform Sync Worktree-safe Verification

### Goal

收口 `platform.sync` worktree 的官方顶层验证问题：`build/verify_local.sh` 不能再假设仓库路径
一定以 `/nextPas` 结尾，也不能写死主 checkout 的 `/home/dtamade/projects/nextPas` 路径。

### Architecture Decision

`verify_local` 的路径契约继续保持精确，但精确性来自当前 `REPO_ROOT`、workspace artifact root、
distribution/runtime root 等派生变量，而不是固定目录名。对 line output 优先使用 literal
断言；对 JSON envelope 使用经过 ERE escaping 的路径 pattern。

### Status

Completed

### Planned Steps

- [x] 复现 worktree 下的 `missing-stage0-workspace-root`
- [x] 在 `build/verify_local.sh` 增加 ERE path escaping helper 与派生路径 pattern
- [x] 替换所有写死 `.*/nextPas` 与主 checkout 的断言
- [x] 同步 `core-platform-sync-check` 当前 14 项接口覆盖 summary
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: fresh `bash build/verify_local.sh` 失败在 `missing-stage0-workspace-root`，而实际
  `workspace-root` 是当前 linked worktree 路径。
- GREEN: fresh `bash build/verify_local.sh` 输出 `verify-local=pass` 与
  `human-summary=local verification passed`。

## Addendum: 2026-05-26 Batch 86 Unknown Member Diagnostic

### Goal

按目标树 G1.5/G1.6，补上 direct class member-call 的第一条 name miss 诊断：

- `Worker.Missing(1)` 这类 receiver type 已知、class/parent chain 都没有同名 method 的调用
  必须进入 `sema.unknown-member`。
- 诊断进入统一 diagnostics projection，semantic model status 进入 `failure`。
- 失败 member call 不注册 `member-call` binding。

### Architecture Decision

这是 unknown member 的保守首切片，不是完整 member resolver：

- receiver type 必须可由当前 semantic model 解析。
- receiver type 还必须已有 class layout truth；alias、generic specialization、record-like receiver
  继续 deferred，避免把尚未 materialize 的 member truth 误报成 unknown member。
- 已知 field / property name 不报 unknown member，继续 deferred 给后续 field/property access。
- inherited method 仍沿现有 parent chain lookup 成功绑定。
- 在 source-backed nextPas `System` / `TObject` truth 落地前，`Free` 这类最低对象生命周期入口
  不作为普通 unknown member 报错，避免把 System 基线缺口误报成用户成员缺失。
- 未知 receiver、record/property/array/deref receiver、visibility、implicit conversion、default parameter
  与 full overload ranking 不在本批内。

### Status

Completed

### Planned Steps

- [x] 写 focused RED：direct class unknown member 必须产生 `sema.unknown-member`
- [x] 在 semantic analyzer 接入保守 unknown-member failure kind
- [x] 固定同名 field 与临时 System object `Free` deferred 边界，避免 known non-method / System 基线误报
- [x] 固定 specialized generic receiver deferred 边界，避免 generic instantiation truth 未落地前误报
- [x] 新增 stage0 fail fixture 和 `unknown-member-check`
- [x] 同步 sema / semantic model / stage0 / goal tree / rolling plan 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 失败在 `semantic-call-bindings-failure=missing-unknown-member-diagnostic`。
- GREEN focused: focused semantic test 输出 `semantic-call-bindings-status=pass`。
- First full attempt: detached clean worktree 暴露 `examples/smoke/llvm_destructor.pas` 的
  `C.Free` 被误报 `sema.unknown-member`；该边界已改为 deferred，并记录为下一步
  source-backed `System` / `TObject` truth 工作。
- Second full attempt: `llvm-destructor-program=pass` 且 `unknown-member-check=pass`，后段
  `stage0-test-smoke-check` 暴露 `tests/parser/generics_pass.pas` 的 specialized generic receiver
  被误报；该边界已收紧为没有 class layout truth 时 deferred。
- Final full: fresh detached clean worktree 已输出 `unknown-member-check=pass`、
  `unknownMemberCheck":"pass"`、`stage0-test-smoke-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Next

下一轮继续 G1.5/G1.6，优先补 callable/member no-matching-overload 或进一步收紧 known non-callable
诊断边界。

## Addendum: 2026-05-26 Batch 85 Latest Baseline Verification Closure

### Goal

把并行推进后的最新 baseline 收口到可继续开发的状态：

- 确认 `sema.unknown-callable` 的保守边界已经不再误伤 compiler self-compile 中的
  `inherited Create` / implicit self bare method call。
- 确认 `unit_root_precedence` 不再被 host FPC 旧 `.ppu/.o/.s` 中间产物污染。
- 保持协作边界：不修改、不 stage、不提交 `core/` 负责人当前工作。

### Status

Completed

### Planned Steps

- [x] 复核最新 HEAD、工作树和非 `core/` 变更边界
- [x] 用 focused semantic call binding test 确认 unknown callable 回归已转绿
- [x] 用 detached clean worktree 运行 fresh `bash build/verify_local.sh`
- [x] 复核 verify 失败历史，确认当前最高 blocker 已从 self-compile / unit-root precedence 关闭
- [x] 同步计划记录，提交本轮收口状态

### Verification

- Focused: `semantic-call-bindings-status=pass`。
- Full: detached clean worktree 基于 `287d13d` 输出
  `unknown-callable-check=pass`、`unit-root-precedence-check=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`。

### Next

下一轮继续走非 `core/` 路线，优先从目标树 G1.5/G1.6 中选择 source-owned、
误报风险可控的 callable/member diagnostics：unknown member 或 no-matching-overload。

## Addendum: 2026-05-26 Batch 84 Unknown Bare Callable Diagnostic

### Goal

按 `docs/architecture/nextpas-goal-tree.md` 的 G1.5/G1.6，补上第一条 source-owned unknown
bare callable 语义诊断：

- `MissingThing(1)` 这类 root source 里没有任何已知 callable/symbol/type/builtin 含义的 bare call
  必须进入 `sema.unknown-callable`。
- 诊断进入统一 diagnostics projection，semantic model status 进入 `failure`。
- 失败调用不注册 `call` binding。

### Architecture Decision

这是 unknown callable 的保守首切片，不是完整 callable resolver：

- 已知 builtin callable 继续 deferred 给现有 runtime/builtin lowering，不报 unknown。
- 已知 symbol 或 type name 不报 unknown；未来再区分 not-callable、typecast、function pointer。
- imported helper no-match、unknown member、record/property/array/deref receiver、implicit conversion、
  no-matching-overload 仍保留给后续 G1.5/G1.6。

### Status

Completed

### Planned Steps

- [x] 写 focused RED：bare unknown callable 必须产生 `sema.unknown-callable`
- [x] 新增 stage0 fail fixture 和 `unknown-callable-check`
- [x] 在 semantic analyzer 接入保守 unknown-callable failure kind
- [x] 同步 sema spec、goal tree、stage0 README 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 失败在
  `semantic-call-bindings-failure=missing-bare-unknown-callable-diagnostic`。
- GREEN focused: focused semantic test 输出 `semantic-call-bindings-status=pass`。
- Full: fresh `bash build/verify_local.sh` 必须输出 `unknown-callable-check=pass`、
  `unknownCallableCheck":"pass"`、`verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不修改 `core/` 代码
- 不实现 unknown member
- 不实现 full overload resolver / implicit conversion / no-matching-overload
- 不把 typecast、function pointer 或 known non-callable symbol 误归类为 unknown callable

## Addendum: 2026-05-26 Batch 83 Capability Goal Tree

### Goal

把 nextPas 的长期目标从“继续推进”收成一份可执行、可检查、可复盘的目标树：

- 定义 nextPas 的北极星目标：现代 Pascal 编译器、RTL/core/framework、workspace/package/tooling、
  language service、IDE 与 FPC 兼容生态。
- 把完整能力拆成 G0-G8：项目控制面、编译器语言能力、IR/backend/toolchain、RTL/core/framework、
  workspace/package、developer tools、language service/IDE、FPC compatibility、performance/reliability。
- 标注当前完成度、下一步证据和近期优先级，让后续每轮 batch 都能绑定目标节点。
- 明确当前协作边界：不直接修改 `core/`，core 相关需求以 integration requirement 或 review/suggestion
  形式反馈。

### Architecture Decision

目标树不是新路线图替代品，而是总控索引：

- `docs/architecture/master-roadmap.md` 继续负责产品顺序。
- `docs/architecture/compiler-roadmap.md` 继续负责 compiler execution spine。
- `docs/architecture/bootstrap-roadmap.md` 继续负责 `stage0 -> stage1 -> stage2` 所有权迁移。
- `docs/architecture/nextpas-goal-tree.md` 负责把上述路线收成能力目标、当前状态、优先级和每轮报告格式。

### Status

Completed

### Planned Steps

- [x] 新增 `docs/architecture/nextpas-goal-tree.md`
- [x] 在 `docs/architecture/master-roadmap.md` 接入目标树入口
- [x] 在 `build/verify_local.sh` docs-check 中加入目标树文件
- [x] 同步 rolling plan 顶部状态到 Batch 83
- [x] 同步 `task_plan.md`、`progress.md` 与 `findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 必须输出 `verified-path=docs/architecture/nextpas-goal-tree.md`、
  `docs-check=pass`、`verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不修改 `core/` 代码
- 不打开 package manager resolver/fetch/install/publish
- 不把目标树当作替代真实功能实现的完成标准

## Addendum: 2026-05-26 Batch 82 Core Time Verification Closure

### Goal

把 `nextpas.core.time` 从“已提交模块但未进入顶层官方验证”的状态收口为可追溯的
core 基础设施批次：

- `core.platform.time` 正式承载平台时间源，并由 `nextpas.core.platform` facade re-export。
- `TInstant.Now` 使用 platform-owned monotonic clock，不在 `time.base` 内直接依赖 OS 单元。
- `build/verify_local.sh` 新增 `core-time-check`，编译并运行
  `core/tests/nextpas.core.time/test_time/test_time.lpr`，最终 envelope 暴露 `coreTimeCheck`。
- `core/README.md` 同步当前 core reality，避免继续只描述 L0 初始状态。

### Architecture Decision

这是 L1 `time` 的验证收口，不扩大成完整跨平台时间/日历库：

- 当前承诺 `Duration`、`Instant`、`Stopwatch` 与 platform monotonic/realtime/resolution 最小入口。
- Linux 路径使用 `clock_gettime` / `clock_getres`；Windows 路径保留
  `QueryPerformanceCounter` / `GetSystemTimeAsFileTime` 结构；未知平台 fallback 只保证可编译。
- 不引入 DateTime、timezone、timer、scheduler、async runtime 或 benchmark layer。

### Status

Completed

### Planned Steps

- [x] 复查 `core.time` / `core.platform.time` 的当前 dirty tree 与 core 模块约定
- [x] 修正 `core.platform.time` 的 implementation `uses` 顺序与保守 fallback
- [x] 给 focused time 测试补 direct platform time facade coverage
- [x] 在 `build/verify_local.sh` 增加 `core-time-check` 与 `coreTimeCheck` envelope field
- [x] 同步 core README 与持续记录
- [x] 运行 focused core test / `make -C core test`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- Focused compile/run 已通过：`nextpas.core.time: 13 total, 13 passed, 0 failed`。
- Core matrix: `make -C core test` 已通过，覆盖 base / errors / platform / time / bytes /
  testing / mem。
- Full: `bash build/verify_local.sh` 已输出 `core-time-check=pass`、
  `coreTimeCheck":"pass"`、`smoke-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现 DateTime / timezone / calendar formatting
- 不实现 Timer / scheduler / async runtime
- 不把未知平台 fallback 宣称为高精度时间源
- 不重开 sema / package manager / backend 路线

## Addendum: 2026-05-26 Batch 81 Parameter Call Type Mismatch Evidence

### Goal

把 Batch 80 的稳定变量 evidence 继续推进到过程/函数参数：
当 bare procedure/function call 或 direct member-call 只有 root-owned 单一 target、arity 已匹配，且
argument signature 来自当前 callable scope 中已声明为内建标量/字符串类型的参数时，若与 target
param signature 明确不兼容，发出 `sema.type-mismatch`。

本批次新增并冻结：

- parameter symbol 现在记录声明中的 `TypeId`，不再只记录名字与 scope。
- `SeedCallBindingsInNode(...)` 进入 procedure/function declaration body 时切换到对应 callable
  scope，让参数 lookup 消费真实 scope chain。
- stable scalar evidence 只接受 `variable` / `parameter` symbol；function result symbol 即使有
  builtin return type，也继续不作为 diagnostic evidence，且 single-target mismatch 不注册错误 binding。
- `build/verify_local.sh` 新增 `type-mismatch-parameter-call-check` 与
  `member-type-mismatch-parameter-call-check`，固定 stage0 failure projection 与 final verify envelope 的
  `typeMismatchParameterCallCheck` / `memberTypeMismatchParameterCallCheck`。

### Architecture Decision

这是 scalar value fact 的第二条安全切片，不是完整 expression value-flow：

- 只覆盖当前 semantic model 中已能稳定解析为内建标量/字符串 type id 的变量与参数。
- function result、class/record/Pointer/Text/Variant、declared alias、成员访问、imported target 与多
  overload signature no-match 继续 deferred；已知 signature mismatch 但缺少 stable evidence 时不诊断也不绑定。
- 不引入 implicit conversion/ranking、default parameter lowering、var/out compatibility 或完整 overload resolver。

### Status

Completed

### Planned Steps

- [x] RED：新增 bare `Pick(Flag)`，其中 `Flag` 是 `Run(Flag: Boolean)` 的参数
- [x] RED：新增 `Self.Pick(Flag)` 的 member 参数 regression
- [x] RED：新增 bare function result guard，确认 `function Flag: Boolean` 不被当成 stable value evidence
- [x] 给 parameter symbol 写入 type id，并让 call binding walker 进入 callable scope
- [x] 将 stable scalar evidence 限定到 variable / parameter symbol
- [x] 新增 `tests/fixtures/type_mismatch_parameter_call` /
      `member_type_mismatch_parameter_call` 与 verify gates
- [x] 同步 semantic model / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已失败在
  `semantic-call-bindings-failure=missing-bare-parameter-call-type-mismatch-diagnostic`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full: `bash build/verify_local.sh` 已输出 `type-mismatch-parameter-call-check=pass`、
  `member-type-mismatch-parameter-call-check=pass`、`semantic-call-bindings-check=pass`、
  `smoke-check=pass`、`verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不把 function result 纳入 type mismatch diagnostic evidence
- 不把 class/record/Pointer/Text/Variant/declared alias 参数纳入 type mismatch evidence
- 不实现 imported target type-mismatch diagnostics
- 不实现 multi-target no-matching-overload diagnostics
- 不实现 implicit conversion / overload ranking / default parameter lowering
- 不实现 unknown callable / unknown member diagnostics

## Addendum: 2026-05-26 Batch 80 Scalar Variable Call Type Mismatch Evidence

### Goal

把 Batch 79 的 `sema.type-mismatch` evidence 从 literal/纯表达式推进到第一条变量事实：
当 bare procedure/function call 或 direct member-call 只有 root-owned 单一 target、arity 已匹配，且
argument signature 来自当前 scope 中已声明为内建标量/字符串类型的变量时，若与 target param signature
明确不兼容，发出 `sema.type-mismatch`。

本批次新增并冻结：

- `ExpressionTypeFactIsStable(...)` 对 identifier 不再只接受 `True` / `False`，还会通过当前 scope
  的 symbol `TypeId` 判断是否为稳定内建标量事实。
- 新增 `TypeIdHasStableScalarFact(...)`，只认可 `Boolean`、整数/浮点、`Char` 与内建字符串族；
  `Pointer`、`Text`、`Variant`、declared class/record/alias 等继续不作为 diagnostic evidence。
- `build/verify_local.sh` 新增 `type-mismatch-variable-call-check` 与
  `member-type-mismatch-variable-call-check`，固定 stage0 failure projection 与 final verify envelope 的
  `typeMismatchVariableCallCheck` / `memberTypeMismatchVariableCallCheck`。

### Architecture Decision

这是 variable argument type mismatch evidence 的第一条安全切片，不是完整 variable type flow：

- 只覆盖当前 semantic model 中已能稳定解析为内建标量/字符串 type id 的变量参数。
- class/record/Pointer/Text/Variant、declared alias、成员访问、函数结果、imported target 与多 overload
  signature no-match 继续 deferred。
- 不引入 implicit conversion/ranking、default parameter lowering、var/out compatibility 或完整 overload resolver。

### Status

Completed

### Planned Steps

- [x] RED：新增 bare `Pick(Flag)`，其中 `Flag: Boolean` 调 `Pick(Integer)` 的 focused regression
- [x] RED：新增 `Worker.Pick(Flag)` 的 member focused regression
- [x] 新增内建标量变量 evidence gate
- [x] 新增 `tests/fixtures/type_mismatch_variable_call` /
      `member_type_mismatch_variable_call` 与 verify gates
- [x] 同步 semantic model / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已失败在
  `semantic-call-bindings-failure=missing-bare-variable-call-type-mismatch-diagnostic`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full: `bash build/verify_local.sh` 已输出 `type-mismatch-variable-call-check=pass`、
  `member-type-mismatch-variable-call-check=pass`、`semantic-call-bindings-check=pass`、
  `smoke-check=pass`、`verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不把 class/record/Pointer/Text/Variant/declared alias 变量纳入 type mismatch evidence
- 不实现 imported target type-mismatch diagnostics
- 不实现 multi-target no-matching-overload diagnostics
- 不实现 implicit conversion / overload ranking / default parameter lowering
- 不实现 unknown callable / unknown member diagnostics

## Addendum: 2026-05-26 Batch 79 Single-target Call Type Mismatch Diagnostics

### Goal

把 semantic binding/type relation 从“能绑定正确 target”推进到第一条可证明 type no-match：
当 bare procedure/function call 或 direct member-call 只有 root-owned 单一 target、arity 已匹配，且当前
argument signature 来自 literal/纯表达式等稳定事实、可推断为与 target param signature 明确不兼容时，
发出 `sema.type-mismatch`。

本批次新增并冻结：

- `InferExpressionType(...)` 识别 `True` / `False` 为 `Boolean`，让 boolean literal 进入
  call argument signature。
- `LookupCallBindingDeclaration(...)` 对 bare call 的单一 target signature mismatch 透传
  `type-mismatch` failure kind，不再错误注册 `call` binding。
- `MethodSymbolIdForExactClassTypeMember(...)` 对 direct member-call 的单一 target signature
  mismatch 透传 `type-mismatch` failure kind。
- `build/verify_local.sh` 新增 `type-mismatch-call-check` 与
  `member-type-mismatch-call-check`，固定 stage0 failure projection 与 final verify envelope 的
  `typeMismatchCallCheck` / `memberTypeMismatchCallCheck`。

### Architecture Decision

这是 root-owned single-target type mismatch diagnostics，不是完整 no-matching-overload resolver：

- 只覆盖 root-owned target 唯一、arity 已匹配、argument signature 来自稳定 facts 且明确不兼容的路径。
- imported target 继续 deferred；当前 compact signature 尚不足以可靠覆盖 RTL/package helper surface。
- 变量/成员/函数结果相关 no-match 继续 deferred；当前变量声明与 symbol type facts 还不能作为
  diagnostic 证据使用。
- 多 overload 的 signature no-match 仍保持 deferred，避免把 implicit conversion、ranking 或 future
  resolver 能力误报成错误。
- 未知 callable / unknown member、receiver 未覆盖、record/property/array/deref receiver、visibility、
  implicit conversion、default parameter lowering/ranking 与完整 overload ranking 继续 deferred。

### Status

Completed

### Planned Steps

- [x] RED：新增 bare `Pick(True)` 调 `Pick(Integer)` 的 type mismatch focused regression
- [x] RED：新增 `Worker.Pick(True)` 调 `TWorker.Pick(Integer)` 的 member type mismatch regression
- [x] 让 boolean literal 进入 expression type inference / argument signature
- [x] 在 bare call lookup 中带出 `type-mismatch` failure kind，避免错误绑定
- [x] 在 member target lookup 中带出 `type-mismatch` failure kind
- [x] 新增 `tests/fixtures/type_mismatch_call` / `member_type_mismatch_call` 与 verify gates
- [x] 同步 semantic model / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已失败在
  `semantic-call-bindings-failure=missing-bare-call-type-mismatch-diagnostic`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full first pass: `bash build/verify_local.sh` 曾失败在
  `compiler-module-workspace-model-self-compile-failed`，原因为 imported `SysUtils.ExpandFileName` /
  `FileExists` 被过宽 type-mismatch 规则误报。
- Full second pass: `bash build/verify_local.sh` 曾失败在 `llvm-linked-list-build-failed`，原因为
  root-owned `SetNext(TNode)` 的变量参数 `B` / `C` 被不稳定 variable type fact 误报。
- Full: `bash build/verify_local.sh` 已输出 `type-mismatch-call-check=pass`、
  `member-type-mismatch-call-check=pass`、`semantic-call-bindings-check=pass`、
  `smoke-check=pass`、`verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现 multi-target no-matching-overload diagnostics
- 不实现 implicit conversion / overload ranking / default parameter lowering
- 不实现 unknown callable / unknown member diagnostics
- 不扩展 record/property/array/deref receiver、virtual dispatch 或完整 member resolver
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 78 Member Wrong Argument Count Diagnostics

### Goal

把 Batch 77 的 `sema.wrong-argument-count` 从 bare call 扩展到当前已支持的 direct
member-call：当 receiver type 上已经存在同名 method，但没有任何同 arity target 时，发出
`sema.wrong-argument-count`。

本批次新增并冻结：

- `MethodSymbolIdForExactClassTypeMember(...)` 在同名 method 已知但 arity 全不匹配时透传
  `wrong-argument-count` failure kind。
- `SeedCallBindingsInNode(...)` 对 direct member-call 的 `wrong-argument-count` failure kind 发
  `sema.wrong-argument-count`。
- `build/verify_local.sh` 新增 `member-wrong-argument-count-check`，固定 stage0 failure projection
  与 final verify envelope 的 `memberWrongArgumentCountCheck`。

### Architecture Decision

这是 direct member-call 的 arity no-match diagnostics，不是完整 Pascal member resolver：

- 只覆盖当前已支持的 direct class/type receiver path。
- 只在 receiver type 已解析且同名 method 已知、但没有任何同 arity target 时发 diagnostic。
- 未知 member、receiver 未覆盖、body mismatch、signature no-match 仍保持 deferred。
- 不实现 implicit conversion、default parameter lowering/ranking、visibility、virtual dispatch、
  record/property receiver 或完整 type-based overload ranking。

### Status

Completed

### Planned Steps

- [x] RED：新增 `Worker.Pick(1, 2)` 的 member wrong-argument-count focused regression
- [x] 在 member target lookup 中带出 `wrong-argument-count` failure kind
- [x] 在 semantic analyzer 中为 direct member-call 发 `sema.wrong-argument-count`
- [x] 新增 `tests/fixtures/member_wrong_argument_count` 与 `member-wrong-argument-count-check`
- [x] 将 `query_member_call_bindings` 的历史缺参负例迁移到 dedicated failure fixture
- [x] 同步 semantic model / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已失败在
  `semantic-call-bindings-failure=missing-member-wrong-argument-count-diagnostic`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full first pass: `bash build/verify_local.sh` 曾失败在
  `stage0-query-member-call-bindings-failed`，原因为 success query fixture 仍含历史缺参负例。
- Full: `bash build/verify_local.sh` 已输出 `member-wrong-argument-count-check=pass`、
  `semantic-call-bindings-check=pass`、`smoke-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现 unknown member diagnostics
- 不实现 type-based no-matching-overload diagnostics
- 不实现 implicit conversion / default parameter lowering/ranking / var-out compatibility / visibility checking
- 不扩展 record/property/array/deref receiver、virtual dispatch 或完整 member resolver
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 77 Bare Wrong Argument Count Diagnostics

### Goal

把 bare callable failure 从 ambiguity 继续推进到第一条 no-match 形态：当 root/imported
优先级内已经存在同名 callable，但没有任何候选的参数个数与调用匹配时，发出
`sema.wrong-argument-count`。

本批次新增并冻结：

- `LookupCallBindingDeclaration(...)` 先按 owner priority 统计同名候选，再判断 call arity 是否落在
  declaration 的必填参数数到总参数数之间。
- root callable name 存在但 arity 全不匹配时，不回落 imported，直接发
  `sema.wrong-argument-count`。
- imported callable name 存在但 arity 全不匹配时，同样发 `sema.wrong-argument-count`。
- `build/verify_local.sh` 新增 `wrong-argument-count-check`，固定 stage0 failure projection 与
  final verify envelope 的 `wrongArgumentCountCheck`。

### Architecture Decision

这是 bare callable 的 arity no-match diagnostics，不是完整 no-matching-overload resolver：

- 只覆盖 bare procedure/function call，不覆盖 member-call wrong arity。
- 只在 callable name 已知、但同优先级没有任何 arity match 时发 diagnostic；默认参数只参与
  bare call 的 arity 区间与 provided-argument signature prefix 判断。
- 可接受 arity 存在但 compact signature match count 为 0 时仍 deferred，避免把 implicit conversion、
  type ranking 或 future resolver 能力误报成 wrong-argument-count。
- builtin / 未知 callable name 继续不报错，避免误伤 `WriteLn` 等内建或未来 callable forms。

### Status

Completed

### Planned Steps

- [x] RED：新增 overloaded bare `Pick` 调用 `Pick(1, 2)` 的 wrong-argument-count regression
- [x] 在 bare call lookup 中带出 `wrong-argument-count` failure kind
- [x] 在 semantic analyzer 中发 `sema.wrong-argument-count`
- [x] 新增 `tests/fixtures/wrong_argument_count` 与 `wrong-argument-count-check`
- [x] 修复 `default_params_pass.pas` 暴露的默认参数 arity false positive
- [x] 同步 semantic model / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已失败在
  `semantic-call-bindings-failure=missing-bare-wrong-argument-count-diagnostic`。
- RED: 默认参数 focused regression 已失败在
  `semantic-call-bindings-failure=unexpected-default-parameter-diagnostics`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Focused parser: `./tests/run_all_tests.sh --filter parser` 已输出
  `failed-fixture-count=0` 与 `human-summary=group parser passed`。
- Full: `bash build/verify_local.sh` 已输出 `wrong-argument-count-check=pass`、
  `semantic-call-bindings-check=pass`、`smoke-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现 member-call wrong-argument-count diagnostics
- 不实现 type-based no-matching-overload diagnostics
- 不把未知 callable / builtin 统一报错
- 不实现 implicit conversion / default parameter lowering/ranking / var-out compatibility / visibility checking
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 76 Member Ambiguous Overload Diagnostics

### Goal

把 Batch 75 的 structured overload failure 从 bare call 推进到 direct member-call：当
`member-call` target lookup 在 receiver exact/parent class 上遇到同 owner、同 qualified name、
同参数个数且 compact signature 无法唯一选择的 method 候选时，发出
`sema.ambiguous-overload`。

本批次新增并冻结：

- `MethodSymbolIdForExactClassTypeMember(...)` / `MethodSymbolIdForClassTypeMember(...)`
  透传 `ambiguous-overload` failure kind。
- `TryRegisterMemberCallBinding(...)` 在明确 member overload ambiguity 时让
  `SeedCallBindingsInNode(...)` 发 `sema.ambiguous-overload`。
- `build/verify_local.sh` 新增 `ambiguous-member-overload-check`，固定 stage0 failure projection 与
  final verify envelope 的 `ambiguousMemberOverloadCheck`。

### Architecture Decision

这是 member-call diagnostics 的第一条 ambiguity 切片，不是完整 Pascal member resolver：

- 只覆盖 direct class/member call 已支持的 receiver path。
- 只在 compact signature collision 或无法签名消歧的多候选上报 ambiguity。
- signature match count 为 0 仍保持 deferred，不报 no-matching-overload。
- 不实现 implicit conversion、default parameter、visibility、virtual dispatch、record/property receiver
  或完整 type-based overload ranking。

### Status

Completed

### Planned Steps

- [x] RED：新增 `Integer` / `LongInt` compact signature collision 的 member-call focused regression
- [x] 在 member target lookup 中带出 `ambiguous-overload` failure kind
- [x] 在 semantic analyzer 中为 direct member-call 发 `sema.ambiguous-overload`
- [x] 新增 `tests/fixtures/ambiguous_member_overload` 与 `ambiguous-member-overload-check`
- [x] 同步 semantic model / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已失败在
  `semantic-call-bindings-failure=missing-ambiguous-member-overload-diagnostic`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full: `bash build/verify_local.sh` 已输出 `ambiguous-member-overload-check=pass`、
  `semantic-call-bindings-check=pass`、`smoke-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现 no-matching-overload / unresolved callable diagnostics
- 不把全部 member-call binding miss 统一报错
- 不扩展 receiver grammar 或 member lookup coverage
- 不实现 implicit conversion / default parameter / visibility / virtual dispatch
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 75 Bare Ambiguous Overload Diagnostics

### Goal

把 Batch 74 后仍然“静默不绑定”的第一条 overload 失败边界接进结构化 diagnostics：
当 bare procedure/function call 在同一优先级内存在同名同参数个数 callable 候选，但当前
compact argument signature 不能唯一选出 target 时，发出 `sema.ambiguous-overload`。

本批次新增并冻结：

- `LookupCallBindingDeclaration(...)` 在 root/imported 各自优先级内报告
  `ambiguous-overload` resolution failure，而不是只返回“未绑定”。
- `SeedCallBindingsInNode(...)` 只在明确的 ambiguous overload failure 上发
  `sema.ambiguous-overload`，保持普通 unresolved call / builtin / future callable path deferred。
- `build/verify_local.sh` 新增 `ambiguous-overload-check`，固定 stage0 failure projection 与
  final verify envelope 的 `ambiguousOverloadCheck`。

### Architecture Decision

这是 semantic diagnostics 的第一条 overload 失败切片，不是完整 overload resolver：

- 只覆盖 bare procedure/function call，不覆盖 member-call overload ambiguity。
- root callable 仍优先；root 明确 ambiguous 时不会回落 imported 代偿。
- 同名同 arity 候选存在但 signature match count 为 0 时仍保持 deferred，避免把缺失的
  conversion/ranking/内建函数能力误报成 ambiguity。
- 不新增 implicit conversion、default parameter、var/out compatibility、visibility checking 或
  complete Pascal overload ranking。

### Status

Completed

### Planned Steps

- [x] RED：新增 imported `HelperA.Pick(Integer)` / `HelperB.Pick(Integer)` ambiguous diagnostic
      focused regression
- [x] 在 bare call lookup 中带出 `ambiguous-overload` failure kind
- [x] 在 semantic analyzer 中发 `sema.ambiguous-overload`
- [x] 新增 `tests/fixtures/ambiguous_overload` 与 `ambiguous-overload-check`
- [x] 同步 semantic model / sema / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已失败在 `semantic-call-bindings-failure=missing-ambiguous-overload-diagnostic`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full: `bash build/verify_local.sh` 已输出 `ambiguous-overload-check=pass`、
  `semantic-call-bindings-check=pass`、`smoke-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现 member-call ambiguous overload diagnostics
- 不实现 no-matching-overload / unresolved callable diagnostics
- 不把全部 unresolved call 统一报错
- 不实现 implicit conversion / default parameter / var-out compatibility / visibility checking
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 74 Bare Typed Call Binding

### Goal

把 Batch 73 的 compact typed argument relation 从 `member-call` 复用到 bare
procedure/function call binding：当 root 或 imported callable 中存在同名同参数个数但参数类型不同的
overload 时，例如 `Pick(Integer)` 与 `Pick(Boolean)`，`Pick(1)` 和 `Pick(1 = 1)` 应分别绑定到
对应 `ParamSignature` 的 callable symbol。

本批次新增并冻结：

- bare procedure/function symbol 同步记录 `ParamSignature`。
- `LookupCallBindingDeclaration(...)` 在 root/imported 各自优先级内，先按 name + arity 收集候选；
  若同 arity 多候选，则用当前可推断 argument signature 选择唯一 target。
- root callable 继续优先；root 存在同名同 arity 但无法唯一 typed match 时，不回落 imported。
- `querySymbols` / `queryDefinitions` stage0 gate 固定 bare typed overload 的 symbol signature 与
  target signature。

### Architecture Decision

这是 bare call 的最小 typed overload binding，不是完整 Pascal overload resolver：

- argument signature 仍只来自当前 `InferExpressionType(...)` 可证明的表达式类型。
- root/imported 优先级保持 Batch 60 以来的保守策略。
- 无法推断 argument type、同 signature 不唯一、implicit conversion / default parameter /
  var-out compatibility / visibility 等情况仍不绑定。

### Status

Completed

### Planned Steps

- [x] RED：新增 bare `Pick(Integer)` / `Pick(Boolean)` 同 arity focused regression
- [x] 为 bare procedure/function symbol 写入 `ParamSignature`
- [x] bare call lookup 在同 arity 多候选时按 signature 唯一匹配
- [x] 扩展 stage0 `query_call_bindings` fixture 与 verify gate
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已失败在 `semantic-call-bindings-failure=missing-integer-bare-overload-symbol`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full: `bash build/verify_local.sh` 已输出 `stage0-query-call-bindings-check=pass`、
  `stage0-query-member-call-bindings-check=pass`、`smoke-check=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`。

### Non-goals

- 不实现完整 overload ranking
- 不实现 implicit conversion / default parameter / var-out compatibility
- 不改变 selector/member binding 边界
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 73 Member Typed Overload Binding

### Goal

关闭 Batch 72 后的下一条 overload 缺口：当同一个 class 内存在同参数个数但参数类型不同的
method overload 时，例如 `TWorker.Pick(Integer)` 与 `TWorker.Pick(Boolean)`，`Worker.Pick(1)`
和 `Worker.Pick(1 = 1)` 应分别绑定到对应参数签名的 method symbol，而不是因为 arity 相同而
保守不绑定。

本批次新增并冻结：

- `TSemanticSymbol.ParamSignature`，作为当前最小 callable/member 参数类型签名。
- class method symbol 同步记录 `ParamCount` 与 `ParamSignature`。
- member-call lookup 在同 owner / 同 qualified name / 同 arity 有多个候选时，用 call argument
  signature 做二次唯一匹配。
- `queryDefinitions` / `querySymbols` 对 target / symbol 参数签名做只读投影。

### Architecture Decision

这是最小 typed overload binding，不是完整 Pascal overload resolver：

- argument signature 只来自当前 `InferExpressionType(...)` 已能证明的表达式类型。
- 当前签名仍是 compact semantic signature：`i` / `b` / `s` / `r` / `p`。
- 如果 call argument type 无法推断，或同签名候选不唯一，保持不绑定。
- 不实现 implicit conversion ranking、default parameter、open array、var/out compatibility、
  visibility、virtual dispatch 或 property/record/array receiver。

### Status

Completed

### Planned Steps

- [x] RED：新增 Integer / Boolean 同 arity member overload focused regression
- [x] 为 `TSemanticSymbol` 增加 `ParamSignature`
- [x] 为 class method symbol 写入 `ParamSignature`
- [x] 从 member call arguments 推导 compact argument signature
- [x] exact member lookup 在同 arity 多候选时按 signature 唯一匹配
- [x] 扩展 `queryDefinitions` / `querySymbols` 参数签名投影与 stage0 gate
- [x] 运行 focused semantic test 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test build 曾失败在 `Identifier idents no member "ParamSignature"`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full: `bash build/verify_local.sh` 已输出 `stage0-query-member-call-bindings-check=pass`、
  `smoke-check=pass`、`verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现完整 type-based overload ranking
- 不实现 implicit conversion / default parameter / var-out compatibility
- 不实现 visibility checking 或 virtual/override dispatch
- 不实现 record/property/array/deref receiver
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 72 Member Overload Target Identity

### Goal

关闭 Batch 71 后暴露出的下一个 member-call identity 缺口：当同一个 class 内存在同名 method
overload 时，例如 `TWorker.Pick` 同时有 0 参数与 1 参数版本，`Worker.Pick(1)` 必须绑定到
1 参数 method symbol，而不是只拿第一个同名 `TWorker.Pick` symbol。

本批次新增并冻结：

- class method declaration 的 parameter list 进入 green tree，不再在 parser 中被跳过。
- `method` semantic symbol 记录 `ParamCount`，member target lookup 用 call arg-count 选择同名
  method symbol。
- `queryDefinitions` 对 target symbol 额外投影 `targetParamCount`，让 stage0 / automation 能直接
  验证 overloaded target identity。

### Architecture Decision

这是 argument-count based overload identity，不是完整 type-based overload resolution：

- target 仍必须同 owner unit、同 qualified method name。
- 同 owner 同名同参数个数 method symbol 若不唯一，保守不绑定。
- body declaration 仍作为二次确认：若存在 method body，则必须恰好一个 body 的参数个数与 call
  arg-count 匹配。
- 不实现 typed argument conversion、default parameter、visibility、virtual/override dispatch 或
  property/record/array receiver。

### Status

Completed

### Planned Steps

- [x] RED：新增同名 `TWorker.Pick` 0 参/1 参 focused semantic regression
- [x] 让 class method declaration parameter list 进入 syntax tree
- [x] 为 `method` symbol 设置 `ParamCount`
- [x] 让 exact member lookup 按 `ParamCount` 选择 target method symbol
- [x] 在 `queryDefinitions` 投影 `targetParamCount`
- [x] 扩展 `stage0-query-member-call-bindings-check`
- [x] 运行 focused semantic test 与 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 曾失败在
  `semantic-call-bindings-failure=missing-zero-arg-member-overload-symbol`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full: `bash build/verify_local.sh` 已输出 `stage0-query-member-call-bindings-check=pass`、
  `smoke-check=pass`、`verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现完整 type-based overload resolution
- 不实现 default parameter / implicit conversion matching
- 不实现 visibility checking 或 virtual/override dispatch
- 不实现 record/property/array/deref receiver
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 71 Inherited Member Receiver Binding

### Goal

关闭 Batch 70 后最直接的 member-call 缺口：当 receiver 的 declared class type 没有直接声明
目标 method，但其 parent class 声明了该 method 时，例如 `TChild = class(TBase)` 后
`Worker: TChild; Worker.Touch;`，binding table 应注册 `member-call`，target 指向
`TBase.Touch` method symbol。

本批次新增并冻结：

- member target lookup 先查 receiver exact type，再沿 `ParentTypeId` 链查 parent type。
- parent traversal 仍使用 type symbol owner 限定 `TClass.Method`，不回退到裸字符串 lookup。
- child exact type 若已声明同名 method 但 arity/body 不唯一，则保守停止，不穿透到 parent 代偿。

### Architecture Decision

这是 inherited lookup 的最小正向边界，不是完整 Pascal member resolver：

- 只覆盖 class parent chain 上已 seed 的 method symbol 与 body declaration argument count。
- 不实现 visibility rules、override/virtual dispatch semantics、record/property/array/deref receiver、
  runtime constructor lowering 或 type-based overload resolution。
- parent chain 设置仍来自声明期 `TypeId` / `ParentTypeId`，不会从 source text 重新猜 class。

### Status

Completed

### Planned Steps

- [x] RED：新增 `TChild` receiver 调用 inherited `TBase.Touch` 的 focused semantic regression
- [x] 拆出 exact type method lookup，并区分“没找到 method”和“找到但 arity/实现不匹配”
- [x] 让 member target lookup 沿 owner-safe `ParentTypeId` 链查找 inherited method
- [x] focused semantic test 转绿
- [x] 同步 semantic model / language service / developer tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 曾失败在 `semantic-call-bindings-failure=missing-inherited-member-call-binding`。
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`。
- Full: `bash build/verify_local.sh` 已输出 `stage0-query-member-call-bindings-check=pass`、
  `smoke-check=pass`、`verify-local=pass` 与 `human-summary=local verification passed`。

### Non-goals

- 不实现 visibility checking
- 不实现完整 overload/type dispatch 或 virtual/override dispatch
- 不实现 record method、property accessor、array/deref receiver
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 70 Owner-aware Member Receiver Binding

### Goal

修正 Batch 69 留下的 owner boundary 风险：当 root source 与 imported unit 同时声明同名 class
（例如都叫 `TWorker`）时，root variable receiver 的 `Worker.Add(...)` 必须绑定到该变量真实
`TypeId` 对应 owner unit 下的 `TWorker.Add`，不能因为 imported type/method 先 seed 而误绑到
imported `Worker.TWorker.Add`。

本批次新增并冻结：

- root declaration type resolution 对同名 imported/root class 保持 owner-aware 优先级。
- member receiver lookup 返回稳定 `TypeId`，target lookup 通过 type symbol owner + class name
  选择 method symbol，而不是只靠 `TClass.Method` 字符串的第一个匹配。
- focused semantic regression 覆盖 root/imported 同名 class 的 direct member function call。

### Architecture Decision

这是 member-call binding 的 identity 修补，不是完整 member resolver：

- root owner unit 中同名 type 优先于 imported unit；若只有一个 imported candidate，则仍可解析。
- target method 必须与 receiver type symbol 的 owner unit 对齐。
- 本批不实现 inherited lookup、visibility rules、record/property/array/deref receiver、runtime
  constructor lowering、virtual dispatch 或 type-based overload。

### Status

Completed

### Planned Steps

- [x] RED：新增 root/imported 同名 `TWorker` focused semantic regression，确认旧实现误绑 imported
      method symbol
- [x] 让 type resolution 对当前 owner unit 优先，并在 ambiguity 时保守失败
- [x] 让 member receiver / target lookup 走 `TypeId` + owner unit，而不是裸 class name
- [x] focused semantic test 转绿
- [x] 同步 semantic model / language service / developer tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 曾失败在 `semantic-call-bindings-failure=missing-owner-aware-member-call-binding`
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`
- Fresh full verification: `bash build/verify_local.sh` 输出 `semantic-call-bindings-check=pass`、
  `stage0-query-member-call-bindings-check=pass`、`smoke-check=pass`、`verify-local=pass`
  与 `human-summary=local verification passed`

### Non-goals

- 不实现 inherited member lookup / visibility checking
- 不实现完整 overload/type dispatch 或 virtual/override dispatch
- 不实现 record method、property accessor、array/deref receiver
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 69 Self / Imported Member Receiver Binding

### Goal

把 Batch 68 的 class type-name receiver 继续推进到两个高价值但仍然保守的 member-call
边界：

- class method body 内的 `Self.SetValue(9)` 应解析到当前 method context 的 class type，并注册
  `member-call`，target 指向 `TWorker.SetValue` method symbol。
- root source 中变量类型来自 imported unit 时，例如 `uses Worker; var Worker: TWorker;` 后的
  `Worker.Add(1, 2)`，也应能通过 imported unit 中 seed 出来的 `TWorker` type / `TWorker.Add`
  method symbol 完成同一份 binding truth。

本批次新增并冻结：

- `SeedCallBindingsInNode(...)` 携带当前 qualified method declaration 的 class context，让
  `Self` 不靠文本猜测，而是只在 class method body 语境下解析。
- imported project/source unit 的 type section 与 class method symbols 在 root declarations 之前进入
  `TSemanticModel`，让 root variable type resolution 能消费 imported class types。
- `query symbols` 的 member-call gate 增加 `Self.SetValue(9)` 的 `queryBindings` /
  `queryDefinitions` mirror，证明 stage0 query surface 能消费这条 source occurrence truth。
- focused semantic regression 覆盖 imported class variable receiver，证明 imported class type/method
  symbols 与 root source binding table 之间不需要 CLI 重扫源码或独立 lookup。

### Architecture Decision

这仍是 `TSemanticAnalyzer` binding seeding 的渐进增强，而不是完整 Pascal member resolver：

- `Self` 只在当前 walker 已进入 `TClass.Method` / `TClass.Function` declaration body 后可解析，
  没有 method context 时仍不特殊处理。
- imported type/method symbols 继续归入各自 owner unit scope；root source 只通过同一份
  `TSemanticModel` 的 type id / method symbol id 消费它们。
- member target 仍复用 `TClass.Method` symbol 与 body declaration argument count 的唯一匹配规则。
- 本批不实现继承链 lookup、visibility rules、virtual dispatch、record/property/array/deref receiver、
  runtime constructor lowering、完整 overload/type dispatch 或 LSP incremental overlay。

### Status

Completed

### Planned Steps

- [x] RED/GREEN：扩展 `tests/semantic/test_semantic_call_bindings.pas`，加入
      `Self.SetValue(9)` 并要求 `SetValue` binding count 从 1 变为 2
- [x] 在 `TSemanticAnalyzer` 中传递 current method class context，并让 `Self` receiver 消费它
- [x] 为 imported unit class receiver 增加 focused semantic regression
- [x] 在 `SeedImportedUnitBodies` 中 seed imported type sections / class methods，并确保 root
      declarations 可解析 imported class type id
- [x] 扩展 `tests/fixtures/query_member_call_bindings/member_call_bindings.pas` 与
      `stage0-query-member-call-bindings-check`，固定 `Self.SetValue(9)` 的 query binding /
      definition projection
- [x] 同步 semantic model / language service / developer tooling / stage0 docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 曾失败在 `semantic-call-bindings-failure=unexpected-member-call-argument-binding-count:1`
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`
- focused query probe: `query symbols tests/fixtures/query_member_call_bindings/member_call_bindings.pas`
  已输出 `Self.SetValue(9)` 的 `member-call` / `queryDefinitions`，target 为 `TWorker.SetValue`
  的 `method` symbol
- Fresh full verification: `bash build/verify_local.sh` 输出 `semantic-call-bindings-check=pass`、
  `stage0-query-member-call-bindings-check=pass`、
  `stage0QueryMemberCallBindingsCheck":"pass"`、`smoke-check=pass`、`verify-local=pass`
  与 `human-summary=local verification passed`

### Non-goals

- 不实现完整 member lookup / inherited member lookup / visibility checking
- 不实现 runtime constructor allocation / lowering / initialization semantics
- 不实现完整 overload/type dispatch 或 virtual/override dispatch
- 不实现 record method、property accessor、array/deref receiver
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 68 Constructor Class Receiver Binding

### Goal

关闭 Batch 67 留下的 constructor / class type-name receiver 断点：`TWorker.Create(42)`
这类以已声明 class type 名作为 receiver 的 direct member call，也应注册为 `member-call`，
并指向 class declaration 产生的 `TWorker.Create` method symbol。

本批次新增并冻结：

- direct member-call receiver lookup 先使用变量 receiver 类型；若 receiver 不是变量，再只允许回落到
  已声明的 `type` symbol
- `TWorker.Create(42)` 的 `member-call` binding 与 `queryDefinitions` target projection
- focused semantic regression，证明 class type-name receiver 可被 compiler-owned binding table 消费
- stage0 query gate，证明 CLI-facing query surface 同步公开 constructor receiver binding truth

### Architecture Decision

这仍是 `TSemanticAnalyzer` binding seeding 的渐进增强，而不是完整 constructor 或 member resolver：

- receiver fallback 只接受同一份 `TSemanticModel` 中已声明的 `type` symbol，不从文本猜 class 名。
- target lookup 继续复用 Batch 66 的 `TClass.Method` method symbol 与 body declaration argument count
  matching。
- binding kind 继续使用 `member-call`，让 query consumer 通过同一份 binding/definition projection
  消费 source occurrence truth。
- 本批不实现 runtime object allocation、constructor lowering、完整 static class method semantics、
  full overload/type dispatch、virtual dispatch、record/property/array/deref receiver 或完整 member resolver。

### Status

Completed

### Planned Steps

- [x] RED：扩展 `tests/semantic/test_semantic_call_bindings.pas`，加入
      `Worker := TWorker.Create(42);`
- [x] 在 `TSemanticAnalyzer` 中实现 member receiver 的 declared type fallback
- [x] focused semantic call binding test 转绿
- [x] 扩展 `tests/fixtures/query_member_call_bindings/member_call_bindings.pas` 与
      `stage0-query-member-call-bindings-check`
- [x] 同步 semantic model / language service / developer tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已先失败在 `semantic-call-bindings-failure=missing-member-constructor-binding`
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`
- focused query probe: `query symbols tests/fixtures/query_member_call_bindings/member_call_bindings.pas`
  已输出 `Create` 的 `member-call` / `queryDefinitions`，target 为 `TWorker.Create` 的 `method`
  symbol
- final: fresh `bash build/verify_local.sh` 已输出 `semantic-call-bindings-check=pass`、
  `stage0-query-member-call-bindings-check=pass`、
  `stage0QueryMemberCallBindingsCheck":"pass"`、`smoke-check=pass`、
  `verify-local=pass` 与 `human-summary=local verification passed`

### Non-goals

- 不实现 runtime constructor allocation / lowering / initialization semantics
- 不实现完整 static class method semantics
- 不实现完整 type-based overload resolution
- 不实现 virtual/override dispatch、record method、property accessor、array/deref receiver
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 67 Expression Member Function Binding

### Goal

关闭 Batch 66 留下的 expression-position member function call 断点：`Halt(Worker.Add(1, 2));`
这类作为表达式参数出现的 direct class variable receiver method call，也应注册为 `member-call`，
并指向 `TWorker.Add` method symbol。

本批次新增并冻结：

- wrapped procedure-call statement 的 inner `gnkFunctionCall` 不再整棵跳过；只跳过 wrapper
  callee 自身，继续递归其参数表达式
- direct class receiver method function call 在表达式位置的 `member-call` binding
- `query symbols` 对 expression-position `member-call` / `queryDefinitions` 的 stage0 gate
- focused semantic regression，证明 `Halt(Worker.Add(1, 2));` 可被 compiler-owned binding table 消费

### Architecture Decision

这仍是 `TSemanticAnalyzer` binding seeding 的渐进增强，而不是完整 member resolver：

- 重用 Batch 65/66 的 receiver variable type lookup、`TClass.Method` symbol lookup 与 arity matching。
- wrapper child 处理只影响 binding walker 的遍历策略：避免对同 offset wrapper call 重复注册，同时不丢失参数里的嵌套 call。
- 表达式位置只承诺 direct variable receiver 的 dot-access method function call。
- constructor call、record/property/array/deref receiver、virtual/override dispatch 与 type-based overload
  resolution 继续保持 deferred。

### Status

Completed

### Planned Steps

- [x] RED：扩展 `tests/semantic/test_semantic_call_bindings.pas`，加入
      `Halt(Worker.Add(1, 2));`
- [x] 修正 `SeedCallBindingsInNode(...)` 对 wrapped function-call child 的参数遍历
- [x] focused semantic call binding test 转绿
- [x] 扩展 `tests/fixtures/query_member_call_bindings/member_call_bindings.pas` 与
      `stage0-query-member-call-bindings-check`
- [x] 同步 semantic model / language service / developer tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 先失败在 `semantic-call-bindings-failure=missing-member-function-expression-binding`
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`
- final: fresh `bash build/verify_local.sh` 已输出 `semantic-call-bindings-check=pass`、
  `stage0-query-member-call-bindings-check=pass`、`stage0QueryMemberCallBindingsCheck":"pass"`、
  `verify-local=pass` 与 `human-summary=local verification passed`

### Non-goals

- 不实现完整 type-based overload resolution
- 不实现 constructor binding
- 不实现 virtual/override dispatch、record method、property accessor、array/deref receiver
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 66 Member Call Argument Arity

### Goal

把 Batch 65 的 direct class variable receiver member-call 从零参数推进到参数个数匹配：
`Worker.SetValue(7);` 这类带参数 method call 应注册为 `member-call`，并指向
`TWorker.SetValue` method symbol；缺参的 `Worker.SetValue;` 不能因为 name match 被误绑。

本批次新增并冻结：

- direct class receiver method call 的 argument count matching
- `TClass.Method` body declaration arity 作为最小匹配依据
- `query symbols` 对 `member-call` / `queryDefinitions` 的 stage0 gate
- focused semantic regression，证明带参数 member-call 和缺参防误绑同时成立

### Architecture Decision

member-call 仍然归属于 `TSemanticAnalyzer` 的 binding seeding，不引入完整 method overload
resolver：

- receiver 类型仍来自 `TSemanticModel` 中 root variable symbol 的 `TypeId`。
- target symbol 仍是 class declaration 产生的 `TClass.Method` / `method` symbol。
- 参数个数只从同名 `TClass.Method` body declaration 的 `CountDeclParams(...)` 读取；如果存在
  body declarations，则必须恰好一个 declaration 与 call argument count 匹配。
- 没有 body declaration 时只保留零参数 declaration-only binding；非零参调用不猜测参数列表。
- 这不是 type-based overload resolution：同名同参数个数的多个 body declaration 仍不会绑定。

### Status

Completed

### Planned Steps

- [x] RED：扩展 `tests/semantic/test_semantic_call_bindings.pas`，加入 `Worker.SetValue(7);`
      与缺参 `Worker.SetValue;`，确认旧实现绑定到了错误 occurrence
- [x] 在 `TSemanticAnalyzer.MethodSymbolIdForClassMember(...)` 中加入 body declaration arity
      matching
- [x] focused semantic call binding test 转绿
- [x] 新增 `tests/fixtures/query_member_call_bindings/member_call_bindings.pas`，并把
      `stage0-query-member-call-bindings-check` 纳入 verify-local
- [x] 同步 semantic model / language service / developer tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 先失败在
  `semantic-call-bindings-failure=member-call-argument-binding-offset-mismatch`
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`
- focused query probe: `query symbols tests/fixtures/query_member_call_bindings/member_call_bindings.pas`
  已输出 `member-call` / `queryDefinitions` for `Run` 与 `SetValue`
- final: fresh `bash build/verify_local.sh` 已通过，并确认
  `semantic-call-bindings-check=pass`、`stage0-query-member-call-bindings-check=pass`、
  `stage0QueryMemberCallBindingsCheck":"pass"` 与 `verify-local=pass`

### Non-goals

- 不实现完整 type-based overload resolution
- 不实现 expression-position member function call binding
- 不实现 virtual/override dispatch、record method、property accessor、array/deref receiver 或 constructor binding
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 65 Class Member Call Binding Foundation

### Goal

把 Batch 64 的 selector/member 误绑定防线推进成第一条正向 member binding truth：当 root
source 中已有 class type、class method declaration 和同类型变量时，`Worker.Run;` 这类
无参数 class method call 应进入 `TSemanticModel` binding table，并指向 `TWorker.Run` method
semantic symbol。

本批次新增并冻结：

- class receiver variable -> declared class type 的最小 lookup
- dot-access method callee -> `TClass.Method` semantic symbol binding
- `member-call` binding kind，用于区别 bare procedure/function `call`
- focused semantic regression，证明 selector/member binding 不再只是“排除误绑”

### Architecture Decision

member call binding 继续归属于 `TSemanticAnalyzer`，但不借助 imported bare callable lookup：

- receiver 的类型先从已 seed 的 root `variable` symbol + `TypeId` 读取，不依赖后端 runtime
  lowering 的 `RegisterClassVar(...)` 副表。
- target 只接受当前 semantic model 已声明的 `method` symbol，名字为 `TClass.Method`。
- 本批次只覆盖直接变量 receiver 的 dot-access class method call；record field、property、
  array/deref receiver、constructor dispatch、override/virtual dispatch 和 overload/type-based
  resolution 继续保持 deferred。
- `query-bindings` / `query-definitions` 复用既有 projection，不新增 language-service session。

### Status

Completed

### Planned Steps

- [x] RED：扩展 `tests/semantic/test_semantic_call_bindings.pas`，要求 `Worker.Run;`
      产生 `member-call` binding 并指向 `TWorker.Run`
- [x] 在 `TSemanticAnalyzer` 中实现 direct class variable receiver 的 method symbol lookup
- [x] focused semantic call binding test 转绿
- [x] 同步 semantic model / language service / developer tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 已先失败在 `missing-member-call-binding`
- GREEN focused: focused semantic test 已输出 `semantic-call-bindings-status=pass`
- final: fresh `bash build/verify_local.sh` 已通过，并确认
  `semantic-call-bindings-check=pass`、`semanticCallBindingsCheck":"pass"`、
  `stage0QueryBindingsCheck":"pass"`、`stage0QueryDefinitionsCheck":"pass"` 与
  `verify-local=pass`

### Non-goals

- 不实现完整 selector/member access binding
- 不实现 class method overload / virtual dispatch / override dispatch
- 不实现 record method、property accessor、array/deref receiver 或 constructor binding
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 64 Selector Call Binding Guard

### Goal

把 Batch 61-63 已经公开的 call binding / definition target truth 继续加固到 selector/member
边界：在完整 member binding 与 type-based dispatch 尚未实现前，`Holder.Help();` 这类 qualified
callee 不能被 name-only lookup 误绑定成 imported unit 的 bare `Help` procedure。

本批次新增并冻结：

- selector/member statement call 不进入 name-only call binding
- qualified function-call wrapper 不注册 imported bare callable binding
- `semantic-call-bindings-check` 覆盖 `Holder.Help;` 与 `Holder.Help();` 两种 selector statement
  边界

### Architecture Decision

selector/member call guard 继续归属于 `TSemanticAnalyzer` 的 binding seeding：

- `TSemanticModel` 仍只持有已经被 analyzer 确认的 source occurrence binding truth。
- 当前 name-only binding 只适用于 bare procedure/function call；qualified callee 需要后续真正的
  member lookup / type dispatch，而不是借 imported callable lookup 兜底。
- `IsQualifiedCallNode(...)` 只识别当前 parser 已生成的 selector wrapper 形态，不新增完整 member
  resolution、不改 `query` projection、不执行 MIR/backend/toolchain。

### Status

Completed

### Planned Steps

- [x] RED：扩展 `tests/semantic/test_semantic_call_bindings.pas`，加入 `Holder.Help();`，确认旧实现
      会产生第二条 imported `Help` binding
- [x] 在 `TSemanticAnalyzer.SeedCallBindingsInNode(...)` 前加入 qualified callee guard
- [x] focused semantic call binding test 重新转绿
- [x] 同步 language service / semantic model / stage0 tooling docs 与持续记录
- [x] 收口验证中把 `verify_local` 的 stage0 / bench build dirs 改成 run-private 临时目录，并让
      lexer/parser/sema bench 显式投影 process CPU timing source
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused semantic test 先失败在
  `semantic-call-bindings-failure=unexpected-imported-call-binding-count:2`
- GREEN focused: focused semantic test 输出 `semantic-call-bindings-status=pass`
- final: fresh `bash build/verify_local.sh` 已通过，并确认 `semantic-call-bindings-check=pass`、
  `semanticCallBindingsCheck":"pass"`、`stage0QueryBindingsCheck":"pass"`、
  `stage0QueryDefinitionsCheck":"pass"` 与 `verify-local=pass`

### Non-goals

- 不实现 selector/member access binding
- 不实现 bare identifier function-reference binding
- 不实现完整 type-based overload resolution
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 63 Query Definition Target Projection

### Goal

把 Batch 62 已经公开的 `query-bindings` 从“source occurrence -> target symbol id”
继续推进到可直接消费的 definition target metadata：CLI、automation 与 future
language-service adapter 不应为了 go-to-definition / hover 自己再用 `targetSymbolId`
回扫 `querySymbols` 或重读源码。

本批次新增并冻结：

- `TCompilationSession.DefinitionsJson`
- line-based `query-definitions=<json-array>`
- envelope `queryDefinitions`
- `stage0QueryDefinitionsCheck`

### Architecture Decision

query definition projection 继续归属于 compilation-session-backed query surface：

- `TSemanticModel` 仍持有 binding 与 symbol truth；`TCompilationSession` 只在同一份 model 内把
  `TargetSymbolId` join 到目标 `TSemanticSymbol`
- `TUnitGraph` 只用于补 target owner unit name 与 source path，`stage0` CLI 不重扫源码、不解析
  build output、不维护第二套 semantic lookup
- `query-definitions` 与 `query-bindings`、`query-symbols`、`query-scopes`、`query-types`
  同属只读 semantic query projection，不执行 MIR、backend 或 toolchain
- 每个 definition 条目公开稳定最小字段：binding id/kind/name/owner/offset 与 target
  symbol id/name/kind/owner/source path/offset
- 本批次不新增完整 language service session、不做 references/rename/completion，也不扩展
  selector/member access binding 或 type-based overload resolution

### Status

Completed

### Planned Steps

- [x] RED：新增 `stage0-query-definitions-check`，要求 `query-definitions` 与
      `queryDefinitions` 同时投影 binding target metadata
- [x] 在 `TCompilationSession` 中从 session-owned `TSemanticModel.BindingAt(...)` /
      `SymbolAt(...)` 暴露 `DefinitionsJson`
- [x] 扩展 query projection context、line output 与 envelope mirror
- [x] focused probe 确认 `hello_with_units.pas` 的 `SayHello` call definition target 已投影
- [x] 同步 language service / semantic model / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: fresh verification 先失败在 `missing-stage0-query-definitions-detail`
- GREEN focused: `nextpas query symbols examples/smoke/hello_with_units.pas ...` 输出
  `query-definitions=[{"bindingId":1,"bindingKind":"call","bindingName":"SayHello",...}]`，
  且 envelope 同步带上 `queryDefinitions`
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `stage0-query-definitions-check=pass`、`stage0QueryDefinitionsCheck":"pass"` 与
  `verify-local=pass`

### Non-goals

- 不实现 selector/member access binding
- 不实现 bare identifier function-reference binding
- 不实现完整 type-based overload resolution
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 62 Query Binding Projection

### Goal

把 Batch 61 已经进入 `TSemanticModel` 的 call binding truth 公开到
`nextpas query symbols`，让 CLI、automation 与 future language-service adapter 可以直接消费
source occurrence -> semantic symbol 的绑定关系，而不是重扫源码或自己猜名字解析。

本批次新增并冻结：

- `TCompilationSession.BindingsJson`
- line-based `query-bindings=<json-array>`
- envelope `queryBindings`
- `stage0QueryBindingsCheck`

### Architecture Decision

query binding projection 继续归属于 compilation-session-backed query surface：

- `TSemanticModel` 仍是 binding truth owner；`stage0` 只透传 `TCompilationSession` 生成的 JSON。
- `query-bindings` 与 `query-symbols`、`query-scopes`、`query-types` 同属只读 semantic query
  projection，不执行 MIR、backend 或 toolchain。
- 每个 binding 条目先公开稳定最小字段：`bindingId`、`kind`、`name`、`ownerUnitId`、
  `byteOffset`、`targetSymbolId`。
- 本批次不新增完整 language service session、不做 references/rename/completion，也不扩展
  selector/member access binding 或 type-based overload resolution。

### Status

Completed

### Planned Steps

- [x] RED：新增 `stage0-query-bindings-check`，要求 `query-bindings` 与 `queryBindings`
- [x] 在 `TCompilationSession` 中从 session-owned `TSemanticModel.BindingAt(...)` 暴露
      `BindingsJson`
- [x] 扩展 query projection context、line output 与 envelope mirror
- [x] focused probe 确认 `hello_with_units.pas` 的 `SayHello` call binding 已投影
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 同步 language service / semantic model / stage0 tooling docs 与持续记录
- [x] 简短 review 后提交

### Verification

- RED: fresh verification 先失败在 `missing-stage0-query-bindings-detail`
- GREEN focused: `nextpas query symbols examples/smoke/hello_with_units.pas ...` 输出
  `query-bindings=[{"bindingId":1,"kind":"call","name":"SayHello",...}]`，且 envelope 同步带上
  `queryBindings`
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `stage0-query-bindings-check=pass`、`stage0QueryBindingsCheck":"pass"` 与 `verify-local=pass`

### Non-goals

- 不实现 selector/member access binding
- 不实现 bare identifier function-reference binding
- 不实现完整 type-based overload resolution
- 不新增 `LanguageServiceSession` / overlay / incremental invalidation
- 不执行 MIR、backend、toolchain 或 package workflow mutation

## Addendum: 2026-05-26 Batch 61 Target Snapshot and Imported Call Binding Closure

### Goal

把上一批已经暴露出来的两条真实边界一起收口：

- semantic binding 不再只覆盖 root unit 内声明的 callable，root source 中调用 imported unit
  的 procedure/function 时也要能绑定到 imported unit 拥有的 callable semantic symbol。
- `pkg plan` 在 canonical `nextpas.lock` 已经带有 target-sensitive `[[snapshot]]` skeleton 时，
  不能把“没有当前 target snapshot”的 lockfile 误判成 install-plan ready。

本批次新增并冻结：

- imported unit call occurrence -> imported callable `SymbolId`
- owner-aware callable body registry / callable symbol seeding
- `package-lock-target-snapshot-missing`
- `stage0PkgPlanLockTargetSnapshotMissingCheck`
- `tests/fixtures/package_lock_target_snapshot_missing`

### Architecture Decision

semantic follow-up 继续归属于 `TSemanticModel` / `TSemanticAnalyzer`：

- imported unit bodies 只作为 compiler-owned semantic truth 输入，不让 LSP/query/IDE adapter
  自行解析 imported source。
- imported callable symbol 必须带 owner unit id，并挂到对应 unit scope；root callable 优先，
  imported callable 只有唯一匹配时才作为 binding target。
- selector/member access 继续排除，避免把 `Holder.Help` 误绑定成 imported procedure call。

package workflow follow-up 继续保持 read-only preflight：

- `BuildPackageWorkflowTruthFromWorkspaceModel(...)` 把 resolved target id 传入 install-plan truth。
- lockfile valid 且 manifest-lock identity 匹配后，如果 lockfile 已有 snapshot 集合但没有当前
  target snapshot，`pkg plan` 阻塞为 `package-lock-target-snapshot-missing`。
- 没有 `[[snapshot]]` 的既有最小 v1 lockfile 继续兼容 ready path；本批次不执行 resolver、
  version solving、fetch/install、lockfile write 或 migration。

### Status

Completed

### Planned Steps

- [x] RED：扩展 semantic call binding focused test，覆盖 imported unit `Help;`
- [x] 在 semantic analyzer 中为 imported unit callable 补 owner-aware body/symbol registration
- [x] 修正参数签名抽取中的 `TypeChild` nil guard，避免 imported body seeding 触发未初始化访问
- [x] RED：新增 target snapshot missing fixture 与 `stage0PkgPlanLockTargetSnapshotMissingCheck`
- [x] 在 package workflow install-plan truth 中加入 target snapshot preflight blocker
- [x] 调整 semantic smoke symbol count 到 owner-aware imported callable truth 的真实值
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 同步 package workflow / workspace file / semantic / stage0 tooling docs 与持续记录
- [x] 简短 review 后提交

### Verification

- focused semantic test 输出 `semantic-call-bindings-status=pass`
- target snapshot missing fixture 输出 `package-install-plan-status=blocked`、
  `package-install-plan-blocker-code=package-lock-target-snapshot-missing` 与
  `package-install-plan-blocker-message=canonical package lockfile has no snapshot for requested target`
- final: fresh `bash build/verify_local.sh` 通过，并确认
  `semantic-call-bindings-check=pass`、`stage0PkgPlanLockTargetSnapshotMissingCheck":"pass"` 与
  `verify-local=pass`

### Non-goals

- 不实现 selector/member access binding
- 不实现 bare identifier function-reference binding
- 不实现完整 type-based overload resolution
- 不执行 package resolver、version solving、fetch/install 或 lockfile write

## Addendum: 2026-05-26 Semantic Call Binding Contract

### Goal

为 FPDev LSP 和后续 language-service 工作暴露第一条 source-addressable callable binding
truth：semantic model 不只告诉调用方“有哪些 callable symbol”，还要能说明 root source 中
某个 procedure/function call occurrence 绑定到了哪个 callable semantic symbol。

本批次新增并冻结：

- `TSemanticBinding`
- root procedure/function call binding -> callable `SymbolId`
- overload arg-count 消歧
- `semantic-call-bindings-check`
- verify-local envelope `semanticCallBindingsCheck`

### Architecture Decision

binding contract 归属于 `TSemanticModel`：

- analyzer 负责从已有 callable body registry 生成 binding
- model 持有稳定 identity：binding kind、name、owner unit id、byte offset、target symbol id
- downstream LSP/query/IDE adapter 只消费 model truth，不重扫源码、不自建 parser/type checker
- wrapper `procedure-call-statement -> function-call` AST 只产生一条 binding，避免同一 source offset
  被重复绑定

本批次仍只承诺 root source call binding。selector/member access、imported unit call binding、
bare identifier function-reference binding、完整 overload/type-based resolution 不在本批次内。

### Status

Completed

### Planned Steps

- [x] RED：新增 `tests/semantic/test_semantic_call_bindings.pas`
- [x] 扩展 `TSemanticModel`，新增 `TSemanticBinding` 与 add/read API
- [x] 扩展 `TSemanticAnalyzer`，在 scope assignment 后生成 call bindings
- [x] 对 overloaded procedure call 使用 argument count 选择 target declaration
- [x] 对 wrapper call AST 去重，避免同一 `Pick(1)` 产生两条 binding
- [x] 新增 `semantic-call-bindings-check` 并纳入 verify-local envelope
- [x] 运行 focused semantic test 与 fresh `bash build/verify_local.sh`
- [x] 同步持续记录并提交

### Verification

- RED: focused test 必须先暴露旧实现无法正确处理 overload binding
- GREEN: focused test 输出 `semantic-call-bindings-status=pass`
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `semantic-call-bindings-check=pass`、`semanticCallBindingsCheck":"pass"` 与
  `verify-local=pass`

### Non-goals

- 不新增 standalone language service session
- 不实现 selector/member access binding
- 不实现 imported unit call occurrence binding
- 不把 name-only fallback 包装成 semantic binding truth

## Addendum: 2026-05-25 Batch 60 Package Lock Snapshot Consistency

### Goal

把 Batch 59 已公开的 `[[snapshot]]` skeleton 从“字段可见”推进到“最小一致性可信”：
`nextpas.lock` 仍然只读，但 snapshot replay shape 不能再声明一个 lock entries 中不存在的
selection。

本批次新增并冻结：

- `package.lock.snapshot-selection-unmatched`
- `stage0PkgPlanLockSnapshotInvalidCheck`
- `tests/fixtures/package_lock_snapshot_invalid`

### Architecture Decision

本批次仍只在 lockfile v1 parser 内做 read-only validation：

- snapshot `selection` 必须匹配某个 `[[package]] name/version` 组合，即 `name@version`
- snapshot `digest` 目前只接受 `sha256:` scheme；空 digest 仍沿用 Batch 59 的 missing issue
- 同一 lockfile 内重复 snapshot target 会被标成 invalid issue
- 所有问题都进入 `package-lock-status=invalid` 与 `package-lock-invalid` preflight blocker
- 不做 resolver、version solving、target selection、fetch/install 或 lockfile write

### Status

Completed

### Planned Steps

- [x] RED：新增 snapshot invalid fixture 与 `stage0PkgPlanLockSnapshotInvalidCheck`
- [x] 实现 snapshot selection / digest / target 的最小 parser-side consistency validation
- [x] GREEN：focused fresh `bash build/verify_local.sh` 确认新增 gate 通过
- [x] 同步 package workflow / workspace file / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: fresh verification 必须先失败在
  `missing-stage0-pkg-plan-lock-snapshot-invalid-lock-status`
- GREEN: `tests/fixtures/package_lock_snapshot_invalid` 必须投影
  `package.lock.snapshot-selection-unmatched`，并停在 `package-lock-invalid`
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `stage0PkgPlanLockSnapshotInvalidCheck=pass`

### Non-goals

- 不做 dependency resolver 或 version solving
- 不选择或执行 target snapshot
- 不联网，不 fetch，不 install
- 不写入、重写或 migrate `nextpas.lock`

## Addendum: 2026-05-25 Batch 59 Package Lock Snapshot Skeleton

### Goal

把 `nextpas.lock` 的只读 detail 从 package entries 继续推进到最小 resolver snapshot
skeleton，让 CLI / IDE / automation 能看到 target-sensitive replay shape 的第一层事实，
但仍不执行 resolver、version solving、fetch/install 或 lockfile write：

- `package-lock-snapshot-count`
- `package-lock-snapshots`
- envelope `packageLockSnapshotCount`
- envelope `packageLockSnapshots`

### Architecture Decision

本批次只扩展 lockfile v1 的只读 parser 和 projection：

- `[[snapshot]]` 是 resolver snapshot 的最小可解释骨架，当前只读取
  `target`、`provenance`、`digest` 与 `selection`
- snapshot detail 只进入 package lock truth，不改变 install-plan preflight 的 ready /
  blocked / missing 判定
- 缺少 snapshot 的现有 v1 lockfile 仍然合法；有 `[[snapshot]]` 但缺必需字段时才进入
  `package-lock-invalid`
- `pkg inspect`、`pkg plan`、`pkg graph` 与 `doctor` 继续消费同一份
  `TPackageWorkflowTruth`

### Status

Completed

### Planned Steps

- [x] RED：扩展 `stage0PkgLockSnapshotCheck`，要求 lock snapshot count/detail line 与 envelope
- [x] 扩展 `np_package_lock.pas` 只读解析 `[[snapshot]]`
- [x] 扩展 package workflow truth 与 stage0 text/json projection
- [x] GREEN：focused rerun 确认 lock detail fixture 输出 snapshot，且现有 ready path 不被阻塞
- [x] 同步 package workflow / workspace file / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: fresh verification 必须先失败在缺少
  `package-lock-snapshot-count` / `package-lock-snapshots`
- GREEN: `tests/fixtures/package_lock_detail` 必须投影一个
  `target=linux-x86_64` 的 snapshot detail
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `stage0PkgLockSnapshotCheck=pass`

### Non-goals

- 不做 dependency resolver 或 version solving
- 不联网，不 fetch，不 install
- 不写入、重写或 migrate `nextpas.lock`
- 不把 snapshot skeleton 扩成完整 lock writer grammar

## Addendum: 2026-05-25 Batch 58 Manifest-Lock Mismatch Detail

### Goal

把 `package-lock-out-of-sync` 从一个裸 blocker 推进到可解释的 preflight detail：`pkg plan`
在 manifest package identity 与 lock entries 不一致时，必须同时公开 manifest 期望的
package name/version，以及当前 lockfile 实际 entries。

### Architecture Decision

本批次仍然只做 read-only preflight detail：

- `TPackageInstallPlanTruth` 在 out-of-sync blocker 上携带 expected package identity 与 lock entries
- stage0 line output 新增
  `package-install-plan-blocker-expected-package` 与
  `package-install-plan-blocker-lock-entries`
- command envelope 新增
  `packageInstallPlanBlockerExpectedPackage` 与
  `packageInstallPlanBlockerLockEntries`
- ready path 不输出 blocker detail，避免调用方把空 detail 误解成真实阻塞
- 不做 resolver、version solving、lockfile writer、lockfile rewrite 或 install mutation

### Status

Completed

### Planned Steps

- [x] RED：扩展 `stage0PkgPlanLockOutOfSyncCheck`，要求 expected package 与 lock entries detail
- [x] 在 install-plan truth 中携带 out-of-sync blocker detail
- [x] 扩展 stage0 text/json projection
- [x] focused GREEN：确认 out-of-sync path 有 detail，ready path 不带 blocker detail
- [x] 同步 package workflow / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused probe 确认旧输出没有
  `package-install-plan-blocker-expected-package` /
  `package-install-plan-blocker-lock-entries`
- GREEN: focused probe 确认 out-of-sync fixture 输出 expected manifest identity 与 actual lock entries，
  且 ready fixture 不输出 blocker detail
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `stage0PkgPlanLockOutOfSyncCheck=pass`

### Non-goals

- 不做 resolver 或 version solving
- 不写入或重写 `nextpas.lock`
- 不把 lockfile skeleton 扩展成完整 target snapshot grammar

## Addendum: 2026-05-25 Batch 57 Manifest-Lock Consistency Preflight

### Goal

把 `pkg plan` 的 lockfile preflight 从“lockfile 可解析”继续推进到“manifest 与 lock 的最小
identity 一致”：当 `nextpas.package.toml` 声明的 package name/version 在 canonical
`nextpas.lock` entries 中找不到同名同版本 package 时，`pkg plan` 必须停在明确的
`package-lock-out-of-sync` blocker。

### Architecture Decision

本批次仍然只做 read-only preflight：

- `TPackageManifestInfo` 开始保存 `[package].version`，并通过 `WorkspaceModel` 传给
  `TPackageWorkflowTruth`
- `BuildPackageInstallPlanTruth` 在 lock status 为 `ready` 后检查 manifest package
  name/version 是否存在于 lock entries
- install-plan blocker 顺序更新为 manifest missing -> dependency invalid -> source roots missing ->
  lock invalid -> lock missing -> lock out of sync -> ready
- 不做 dependency resolution、version solving、lockfile writer、lockfile rewrite 或 install mutation

### Status

Completed

### Planned Steps

- [x] 新增 out-of-sync lock fixture，并把 ready lock fixtures 调整为当前 package identity
- [x] 新增 `stage0PkgPlanLockOutOfSyncCheck`，冻结 `package-lock-out-of-sync` blocker
- [x] 将 package manifest version 纳入 manifest/workspace/workflow truth
- [x] 在 install-plan preflight 中加入 manifest-lock identity match
- [x] 同步 package workflow / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: focused probe 确认 out-of-sync fixture 在实现前仍被误报为
  `package-install-plan-status=ready`
- GREEN: focused probe 确认 out-of-sync fixture 投影
  `package-install-plan-status=blocked` 与
  `package-install-plan-blocker-code=package-lock-out-of-sync`
- final: fresh `bash build/verify_local.sh` 必须通过，并确认
  `stage0PkgPlanLockOutOfSyncCheck=pass`

### Non-goals

- 不做 resolver 或 version solving
- 不写入或重写 `nextpas.lock`
- 不把 lockfile skeleton 扩展成完整 target snapshot grammar

## Addendum: 2026-05-25 Batch 56 Package Lockfile v1 Read-only Detail

### Goal

把 canonical `nextpas.lock` 从“存在即 ready”的布尔事实推进到最小 v1 只读 detail：
CLI / IDE / automation 应能直接看到 lockfile format version、package entries 与 validation
issues，并且 `pkg plan` 在 lockfile 无效时必须停在明确的 `package-lock-invalid` blocker。

### Architecture Decision

本批次新增 `compiler/frontend/np_package_lock.pas`，但仍保持 read-only boundary：

- 当前只读取最小 TOML v1：`[lockfile] format-version = 1` 与 `[[package]] name/version`
- `package-lock-status` 扩展为 `missing|ready|invalid`
- install-plan blocker 顺序更新为 manifest missing -> dependency invalid -> source roots missing ->
  lock invalid -> lock missing -> ready
- 不做 resolver、fetch/install、publish、lockfile writer 或 lockfile mutation

### Status

Completed

### Planned Steps

- [x] 新增 lock detail / invalid lock fixtures，并把既有 ready lock fixtures 升级为最小 v1 TOML
- [x] 新增 `np_package_lock` 只读 parser 与 validation issue model
- [x] 扩展 package workflow truth、line output 与 command envelope 的 lock detail 投影
- [x] 扩展 `build/verify_local.sh`，覆盖 lock detail ready path 与 invalid-lock blocked plan path
- [x] 同步 package workflow / workspace file / stage0 tooling docs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- RED: fresh `bash build/verify_local.sh` 先失败在
  `missing-stage0-pkg-lock-detail-format-version`
- GREEN: fresh `bash build/verify_local.sh` 通过，确认 `stage0PkgLockDetailCheck=pass`、
  `stage0PkgPlanLockInvalidCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolution、fetch、install 或 publish
- 不写入或重写 `nextpas.lock`
- 不把最小 v1 skeleton 扩展成完整 resolver snapshot grammar

## Addendum: 2026-05-25 Batch 55 Package Plan Blocker Matrix Gates

### Goal

把 `nextpas pkg plan` 的 install-plan preflight 从“三态已公开”继续推进到“关键 blocker
原因全覆盖”：同一条 `pkg plan` 专用只读面必须覆盖当前 `TPackageWorkflowTruth` 已经拥有的
四类终止原因，避免 CLI / IDE / automation 在 blocked 场景里还要绕回 `pkg inspect` 推断。

### Architecture Decision

本批次仍不新增 resolver、fetch、install 或第二套 planner。`pkg plan` 继续复用
`WorkspaceModel` + `TPackageManifestInfo` + `TPackageWorkflowTruth`；这轮只把剩余 blocker 纳入
promotion gate：

- malformed dependency fixture 必须投影 `blocked` 与 `package-dependencies-invalid`
- manifest / lock ready 但无 source roots 的 fixture 必须投影 `blocked` 与
  `package-source-roots-missing`

### Status

Completed

### Planned Steps

- [x] 新增 `package_manifest_no_source_roots` fixture，冻结 manifest / lock ready 但 source roots
      为空的 package truth
- [x] 扩展 `build/verify_local.sh`，覆盖 `pkg plan` dependency-invalid 与 source-roots-missing
      blocked 命令结果
- [x] 同步 tools README、package workflow / developer tooling spec、rolling roadmap 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 通过，确认
  `stage0PkgPlanDependencyBlockedCheck=pass`、
  `stage0PkgPlanSourceRootsBlockedCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolution、fetch、install 或 publish
- 不改 install plan blocker 顺序
- 不改 lockfile write path

## Addendum: 2026-05-25 Batch 54 Package Plan Blocked/Missing Gates

### Goal

把 `nextpas pkg plan` 从只验证 ready path 推进到完整 preflight 状态边界：同一条公开面必须
直接覆盖 `ready`、`blocked` 与 `missing`，让 CLI / IDE / automation 不需要从
`pkg inspect` 或 `doctor` 间接推断 install plan 为什么不能继续。

### Architecture Decision

本批次不新增第二套 plan logic。`pkg plan` 继续复用 `WorkspaceModel` +
`TPackageManifestInfo` + `TPackageWorkflowTruth`；这轮只把现有 truth 的 blocked / missing
行为纳入 promotion gate：

- workspace member fixture 缺 canonical lockfile 时必须投影 `blocked` 与
  `package-lock-missing`
- package-free workspace 必须投影 `missing` 与 `package-manifest-missing`

### Status

Completed

### Planned Steps

- [x] 扩展 `build/verify_local.sh`，覆盖 `pkg plan` blocked 与 missing 正向命令结果
- [x] 同步 tools README、package workflow / developer tooling / stage0 README 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 通过，确认 `stage0PkgPlanBlockedCheck=pass`、
  `stage0PkgPlanMissingCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolution、fetch、install 或 publish
- 不改 lockfile write path
- 不新增 install planner；只冻结现有 preflight truth 的状态边界

## Addendum: 2026-05-25 Batch 53 Package Plan Read-only Surface

### Goal

把 package workflow 的 install plan preflight truth 公开成真实 `nextpas pkg plan` 面，
让 CLI / IDE / automation 直接消费 workspace-model-backed package install-plan truth，
而不是继续只在 `doctor` / `pkg inspect` 里间接看到它。

### Architecture Decision

`pkg plan` 只做 read-only projection，直接复用 `WorkspaceModel` + `TPackageManifestInfo` +
`TPackageWorkflowTruth`，不碰 resolver、fetch、install 或 lockfile write。install plan 语义
仍然维持 Batch 48 冻结下来的 `ready|blocked|missing` preflight truth；`pkg plan` 只是把同一份
truth 公开成一个专用只读面，而不是第二套 install planner。

### Status

Completed

### Planned Steps

- [x] 扩展 `build/verify_local.sh`，覆盖 `pkg plan` 正向样本与负向参数 gate
- [x] 同步 stage0 / developer tooling / package workflow / stage0 driver 文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 通过，确认 `stage0PkgPlanCheck=pass`、
  `stage0PkgPlanInvalidArgumentsCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolution、fetch、install 或 publish
- 不改 lockfile write path
- 不引入第二套 package install plan truth

## Addendum: 2026-05-25 Batch 52 Package Graph Read-only Surface

### Goal

把 package workflow 的只读 graph surface 收成真实 `nextpas pkg graph` 公开面，让 CLI / IDE /
automation 直接消费 workspace-model-backed package graph truth，而不是自己重拼 declared
dependency intent。

### Architecture Decision

graph 只做 read-only projection，直接复用 `WorkspaceModel` + `TPackageManifestInfo` +
`TPackageWorkflowTruth`，不碰 resolver、fetch、install 或 lockfile write。图语义固定为
package root node + declared-dependency nodes + `declared-dependency` edges；它只是同一份
package workflow truth 的另一种只读视图，不是第二套 graph engine。

### Status

Completed

### Planned Steps

- [x] 扩展 `build/verify_local.sh`，覆盖 `pkg graph` 正向样本与负向参数 gate
- [x] 同步 stage0 / developer tooling / package workflow / stage0 driver 文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 通过，确认 `stage0PkgGraphCheck=pass`、
  `stage0PkgGraphInvalidArgumentsCheck=pass`、`verify-local=pass` 与
  `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolution、fetch、install 或 publish
- 不改 lockfile write path
- 不引入第二套 package graph truth

## Addendum: 2026-05-24 Batch 51 Env Clean Workspace-Local Cache Cleanup

### Goal

把 `env` family 的最小维护面继续收口到 workspace-local cleanup：

- 新增 `nextpas env clean --target linux-x86_64 --workspace <root>`
- `env clean` 只删除 `<workspace>/.nextpas/env/selections/<target>.toml` 与
  `<workspace>/.nextpas/env/resolution/<target>.toml`
- 输出与 `command-envelope=<json>` 必须暴露 cleanup path / status / change /
  removed-count，方便 CLI、IDE 与 automation 判断清理范围

### Architecture Decision

本批次只清理 workspace-local selection / resolution sidecar，不下载、不解包、不安装 runtime SDK，
不改写 workspace descriptor、package manifest、lockfile 或公开 install result。`env clean` 是显式
maintenance surface，不是 `env gc`，也不承诺清掉更广义的 metadata/archive/staging bucket。

### Status

Completed

### Planned Steps

- [x] 确认 `env clean` 只接受 `--target` 与必须的 `--workspace`
- [x] 实现 `env clean` parser、workspace-local selection/resolution 删除与 line / envelope 投影
- [x] 扩展 `build/verify_local.sh`，覆盖首次 removed、二次 unchanged 与 invalid-arguments
- [x] 同步 stage0 / developer tooling / workspace file / distribution specs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Non-goals

- 不做 `env gc`
- 不下载、不解包、不安装 runtime SDK
- 不改写 workspace descriptor、package manifest、lockfile
- 不删除 `units/`、`lib/`、`share/` 或公开 install result

## Addendum: 2026-05-24 Batch 50 Env Sync Workspace Resolution Cache

### Goal

把 `env` family 从 selection mutation 继续推进到第一条 workspace-local sync 闭环：

- 新增 `nextpas env sync --target linux-x86_64 --workspace <root> [--toolchain-binding <id>]`
- `env sync` 在未显式传 `--toolchain-binding` 时读取 Batch 49 的 workspace selection
- 只写 `<workspace>/.nextpas/env/resolution/<target>.toml`，记录当前 resolved binding、distribution、runtime SDK readiness 与 selection 输入
- 公开输出与 `command-envelope=<json>` 必须暴露 resolution path / status / sync delta，方便 CLI、IDE 与 automation 判断本机环境 resolution 是否已经刷新

### Architecture Decision

本批次只 materialize ArtifactRootSet 管辖下的 machine-local environment resolution cache，
不下载、不解包、不安装 runtime SDK，不改写 `env/selections`、`nextpas.workspace.toml`、
`nextpas.package.toml` 或 `nextpas.lock`。`env sync` 是 workspace-local sync surface，
不是 `env bootstrap` 或完整 distribution installer。

### Status

Completed

### Planned Steps

- [x] 确认当前 `env` 已有 `status/use` 和 workspace selection sidecar，但没有 `sync` 入口
- [x] 实现 `env sync` parser、resolution sidecar write、line output 与 command envelope projection
- [x] 扩展 `build/verify_local.sh`，覆盖首次 materialized 与二次 unchanged
- [x] 同步 stage0 / developer tooling / workspace file / distribution specs 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Non-goals

- 不做 `env bootstrap`、下载、解包、archive cache、metadata channel resolver 或 runtime SDK 安装
- 不让 `env sync` 改写 selection sidecar；切换 binding 仍由 `env use` 负责
- 不回写 workspace descriptor、package manifest 或 lockfile
- 不让 `build` / `doctor` / `pkg` 在本批次隐式消费 resolution cache

## Addendum: 2026-05-24 Batch 49 Env Use Workspace Selection Sidecar

### Goal

把 `env` family 从纯只读 `status` 推进到第一条真实但最小的 mutation verb：

- 新增 `nextpas env use --target linux-x86_64 --toolchain-binding <id> --workspace <root>`
- `env use` 只写 workspace-local machine state：
  `<workspace>/.nextpas/env/selections/<target>.toml`
- `env status --target <target> --workspace <root>` 在没有显式
  `--toolchain-binding` 时读取该 selection，并继续复用同一份 target / binding /
  distribution / runtime projection
- 公开输出与 `command-envelope=<json>` 必须暴露 selection path / status / target /
  selected binding，方便 CLI、IDE 与 automation 判断当前机器选择

### Architecture Decision

本批次只让 `env use` 改变 ArtifactRootSet 管辖下的 machine-local selection sidecar，不改
`nextpas.workspace.toml`、`nextpas.package.toml`、`nextpas.lock`、target config 或 toolchain
binding config。显式 `--toolchain-binding` 继续高于 selection；`env sync` / `env bootstrap`
仍然不开启下载、解包、runtime SDK materialize 或 install result mutation。

### Status

Completed

### Planned Steps

- [x] 确认当前 `env` 入口只有只读 `status`，且文档已把
      `env/selections` 归入 ArtifactRootSet machine-local sidecar
- [x] 实现 `env use` parser、selection sidecar write，以及
      `env status --workspace` selection read
- [x] 扩展 line-based output、command envelope 与 `build/verify_local.sh` gate
- [x] 同步 stage0 / developer tooling / workspace 文件层文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Non-goals

- 不做 `env sync`、`env bootstrap`、下载、解包或 runtime SDK 安装
- 不让 `build` / `doctor` 在本批次隐式消费 workspace selection
- 不把 active selection 写进 workspace descriptor、package manifest 或 lockfile
- 不新增 channel / distribution resolver；本批次只冻结 preferred binding selection

## Addendum: 2026-05-24 Batch 48 Package Install Plan Preflight Truth

### Goal

把 package workflow 里还停在 `deferred` 的 install plan truth 收成真正可消费的只读预检结果，
让 CLI / automation 能直接判断“现在能不能进入 install plan 生成前置阶段”，而不是只看到一条
没有解释力的占位状态：

- `package-install-plan-status` 继续作为公开 surface，但状态语义改为 `ready|blocked|missing`
- `missing` 只表示 package workflow 本身不可用，或没有可解释的 package truth
- `blocked` 表示 package truth 已存在，但仍有明确阻塞，必要时补 `package-install-plan-blocker-code`
  与 `package-install-plan-blocker-message`
- `ready` 表示 install plan preflight 已满足，仍不代表真正执行 resolver / install / write-back
- `doctor` / `pkg inspect` 继续共享同一份 package workflow truth，不分裂成两套解释

### Architecture Decision

install plan preflight 只负责回答“能否进入下一步”，不提前打开任何 resolver、fetch、install、
lockfile write 或 mutation path。它的状态边界会按 package workflow truth 的现有层级做最小派生：

- manifest 不存在时，install plan 直接 `missing`
- manifest 存在但被 dependency validation、lock presence 或 source-root completeness 阻塞时，install plan
  投影为 `blocked`
- 只有 manifest、lock、dependency 与 source-root 前置条件都满足时，才投影为 `ready`

### Status

Completed

### Planned Steps

- [x] 确认当前 install-plan 投影仍然固定为 `deferred`，并定位相关 truth / projection / verify
      代码路径
- [x] 在 `compiler/frontend/np_package_workflow.pas` 落 install plan preflight truth 与 blocker 详情
- [x] 同步 `tools/stage0` 投影、`tests/toolchain/toolchain_contract_smoke.pas`、`build/verify_local.sh`
      与相关文档
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

### Verification

- fresh `bash build/verify_local.sh` 通过，最终输出 `verify-local=pass`
  与 `human-summary=local verification passed`

### Non-goals

- 不做 dependency resolver
- 不做 install plan writer
- 不做 lockfile mutation
- 不改 `nextpas.lock` 文件语法或 registry 语义

## Addendum: 2026-05-24 Batch 47 Package Lockfile Presence Truth

### Goal

把 package workflow 里仍然固定为 deferred 的 lock truth 收成真实只读事实：

- `package-lock-status` 继续只读投影 canonical `nextpas.lock` 的存在性
- lockfile 存在时投影 `ready`
- lockfile 不存在时投影 `missing`
- `package-install-plan-status` 继续保持 deferred，本批次不打开 install plan 生成、resolver、
  write-back 或 lockfile mutation
- `doctor` / `pkg inspect` 继续共享同一份 package workflow truth，不再让 lock truth 被固定成
  失真的默认值

### Architecture Decision

lock truth 现在属于 package workflow 的最小可见状态，不再只靠“path 已知但 status deferred”
来表达。我们只读观察 canonical lockfile 是否存在，先让 CLI / automation 能区分“有锁”和“没锁”，
不提前打开真正的 lock write。

### Status

Completed

### Acceptance

- ready package fixture 必须稳定投影 `package-lock-status=ready`
- 没有 lockfile 的 workspace / package root 必须稳定投影 `package-lock-status=missing`
- `command-envelope=<json>.result` 必须同步投影 `packageLockStatus`
- `package-install-plan-status` 仍然保持 deferred
- fresh `bash build/verify_local.sh` 必须通过

### Non-goals

- 不做 lockfile writer
- 不做 dependency resolution
- 不做 install plan generation
- 不改变现有 package manifest / dependency validation grammar

### Planned Steps

- [x] 确认当前 lock truth 与 verify gate 的现状
- [x] 实现 lockfile presence truth 并补 package fixture lockfile
- [x] 同步 verify gate、文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 46 Dependency Requirement Grammar Validation

### Goal

把 Batch 45 已经公开的 declared dependency intent 从“字符串被投影”推进到“格式可信、
违规可解释”的最小 deterministic contract：

- `[dependencies]` 继续只接受 keyed inline table 形状：
  `"package.name" = { version = ">=0.1.0" }`
- dependency requirement string 第一阶段只支持 comparator grammar：`=`、`>`、`>=`、`<`、`<=`
- 多 comparator 用逗号表达 intersection，例如 `>=0.1.0, <0.2.0`
- invalid dependency requirement 不能静默消失；`doctor` / `pkg inspect` 必须能暴露可解释的
  malformed dependency intent
- read-only inspection command 可以继续成功返回，但 package workflow truth 必须把 invalid
  manifest/dependency state 投影给 IDE、CI 与 automation

### Architecture Decision

本批次不打开 resolver。dependency requirement validation 属于 manifest / workflow truth 的输入
可信度边界，先挡住不可信 declaration 进入后续 lock、solver、IDE package view 或 CI automation。

第一阶段明确不支持 union range、feature flag、optional dependency、target-specific dependency
table 或 solver annotation；这些属于 future schema / resolver batch，而不是本批次的 parser
扩张。

### Status

Completed

### Acceptance

- valid examples 必须保留为 declared dependency intent：
  `=0.1.0`、`>0.1.0`、`>=0.1.0`、`<0.2.0`、`<=0.2.0`、
  `>=0.1.0, <0.2.0`
- invalid examples 必须被稳定暴露为 malformed dependency intent，而不是被忽略：
  `^0.1.0`、`~>0.1`、`>=`、`>=0.1.0 || <0.2.0`、empty requirement
- `doctor --workspace` 与 `pkg inspect` 至少一条公开 projection surface 能显示 dependency
  validation status / malformed dependency detail；理想路径是两者共享同一份 package workflow truth
- `build/verify_local.sh` 必须新增 malformed dependency fixture gate，并在最终 envelope 暴露
  对应 check pass 字段
- fresh `bash build/verify_local.sh` 必须通过

### Non-goals

- 不做 dependency resolution、version selection、registry lookup、fetch/install 或 lockfile write
- 不做 semantic version ordering / compatibility solving；本批次只验证 requirement syntax shape
- 不把 target-specific dependency table、optional dependency 或 feature flag 写进当前 grammar
- 不把 diagnostics contract 大重构塞进本批次；只补足本批次需要的 deterministic invalid state

### Planned Steps

- [x] focused probe 当前 parser 对 malformed dependency 的行为，确认 `^0.1.0` 会作为 raw string
      投影且没有 invalid signal
- [x] 设计 manifest/workflow 层的 validation result 承载方式，避免 CLI 两侧各自解析
- [x] 新增 malformed dependency fixture，覆盖 invalid requirement 不静默消失
- [x] 先把 `build/verify_local.sh` gate 写成 RED，冻结 `doctor` / `pkg inspect` 预期
- [x] 实现最小 comparator grammar validation 与 projection
- [x] 同步 stage0 README、workspace/package workflow specs、rolling plan 与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 45 Declared Dependencies Projection

### Goal

把 package manifest 的 `[dependencies]` declared intent 接入 shared package workflow truth，并
通过 `doctor --workspace` / `pkg inspect` 做只读投影：

- manifest parser 支持当前规范已冻结的 keyed inline table 形状：
  `"package.name" = { version = ">=0.1.0" }`
- `TPackageManifestInfo`、`TWorkspaceModel.PackageRef` 与 `TPackageManifestTruth` 持有
  declared dependency name / requirement
- line-based output 新增 `package-dependency-count` 与 `package-dependencies=<json-array>`
- `command-envelope=<json>.result` 同步新增 `packageDependencyCount` 与 `packageDependencies`
- non-goal：不做 dependency resolution、solver、fetch/install、lockfile write、target-specific
  dependencies 或 feature flags

### Status

Completed

### Planned Steps

- [x] 确认当前 parser/workflow 只持有 package identity 与 source roots
- [x] 扩展 manifest parser、workspace model 与 workflow truth
- [x] 扩展 package projection text/json 输出
- [x] 加严 `build/verify_local.sh` 的 doctor / pkg inspect declared dependency gate
- [x] 同步必要文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 44 Package Source Roots Projection

### Goal

把 package workflow truth 中已经存在的 `SourceRoots` 从内部事实提升为公开只读投影，避免
IDE、CI 或 automation 只能拿到 `package-source-root-count` 后再回头解析 manifest：

- `pkg inspect` 与 `doctor --workspace` 必须继续复用同一份 `PackageWorkflowTruth`
- line-based output 在 `package-source-root-count` 之外新增
  `package-source-roots=<json-array>`
- `command-envelope=<json>.result` 同步新增 `packageSourceRoots`
- 缺少 package truth 时投影 `package-source-roots=[]`，与
  `package-source-root-count=0` 保持一致
- non-goal：不做 package resolution、fetch、install、lockfile write 或 manifest 格式扩展

### Status

Completed

### Planned Steps

- [x] 扩展 `TPackageProjectionContext`，承载 `SourceRootsJson`
- [x] 在 `CapturePackageProjectionFromWorkflowTruth(...)` 中从
      `ManifestTruth.SourceRoots` 生成 JSON array
- [x] 扩展 line-based output 与 command envelope
- [x] 加严 `build/verify_local.sh` 的 doctor / pkg inspect package roots detail gate
- [x] 同步最小文档与持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 43 Pkg Inspect Workspace Member Contract

### Goal

把 Batch 42 已冻结的 workspace descriptor root + member package ready contract，从 `doctor`
同步扩展到只读 `pkg inspect`：

- `pkg inspect --workspace <workspace descriptor root>` 必须复用 shared `WorkspaceModel` /
  `PackageWorkflowTruth`
- workspace descriptor root 必须稳定解析到 member package manifest
  `app/nextpas.package.toml`
- package workflow 正向字段必须投影 `package-workflow-status=ready`、
  `package-manifest-status=ready`、`package-source-root-count=1` 与 member
  manifest/root/name/lockfile detail fields
- `command-envelope=<json>.result` 必须同步保留 workspace descriptor path 与 member
  package detail fields
- non-goal：不修改 `pkg inspect` 实现、不做 package resolution/fetch/install、不打开
  lockfile write、publish workflow 或 package manager mutation verbs

### Status

Completed

### Planned Steps

- [x] focused probe 确认 `tests/fixtures/workspace_member_source_root` 下 `pkg inspect` 已经返回
      workspace descriptor + member package ready
- [x] 扩展 `build/verify_local.sh`，新增 `stage0-pkg-workspace-member-check`
- [x] 同步 verify-local success envelope，新增 `stage0PkgWorkspaceMemberCheck`
- [x] 同步 `tools/stage0/README.md`、stage0 / developer tooling / package workflow specs、
      rolling plan、`progress.md`、`findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 42 Doctor Workspace Member Package Contract

### Goal

把 Batch 41 的 ready package workspace gate 从单包 manifest root 扩展到 workspace descriptor
root + member package 的真实形态：

- `doctor --workspace <workspace descriptor root>` 必须复用 shared `WorkspaceModel`
- workspace descriptor root 必须稳定解析到 member package manifest
  `app/nextpas.package.toml`
- package workflow 正向字段必须投影 `package-workflow-status=ready`、
  `package-manifest-status=ready`、`package-source-root-count=1` 与 member
  manifest/root/name/lockfile detail fields
- 正向样本仍可因为当前 runtime SDK 缺失而有 `doctor.runtime-sdk-missing`，但不能出现
  `doctor.package-workspace-missing`
- `command-envelope=<json>.result` 必须同步保留 workspace descriptor path 与 member
  package detail fields
- non-goal：不修改 `doctor` 实现、不做 package resolution/fetch/install、不打开
  `env sync` 或 package manager mutation verbs

### Status

Completed

### Planned Steps

- [x] focused probe 确认 `tests/fixtures/workspace_member_source_root` 下 `doctor` 已经返回
      workspace descriptor + member package ready，且没有 `doctor.package-workspace-missing`
- [x] 扩展 `build/verify_local.sh`，新增 `stage0-doctor-workspace-member-check`
- [x] 同步 verify-local success envelope，新增 `stage0DoctorWorkspaceMemberCheck`
- [x] 同步 `tools/stage0/README.md`、stage0 / developer tooling / package workflow specs、
      rolling plan、`progress.md`、`findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 41 Doctor Package Workspace Positive Contract

### Goal

把 Batch 40 已接入的 `doctor` package/workspace coherence 从“只冻结缺失路径”推进到
“ready 与 missing 两侧都被 promotion gate 保护”：

- `doctor --workspace <package root>` 必须复用同一份 `WorkspaceModel` / `PackageWorkflowTruth`
- package workspace 正向样本必须稳定投影 `package-workflow-status=ready`、
  `package-manifest-status=ready`、`package-source-root-count=1` 与 manifest/root/name/lockfile
  detail fields
- 正向样本仍可因为当前 runtime SDK 缺失而有 `doctor.runtime-sdk-missing`，但不能出现
  `doctor.package-workspace-missing`
- `command-envelope=<json>.result` 必须同步保留同一批 package detail fields
- non-goal：不修改 `doctor` 实现、不执行 fetch/install/resolution、不进入 `env sync` 或
  package manager mutation verbs

### Status

Completed

### Planned Steps

- [x] focused probe 确认 `tests/fixtures/package_manifest_source_root` 下 `doctor` 已经返回
      package workflow ready，且没有 `doctor.package-workspace-missing`
- [x] 扩展 `build/verify_local.sh`，新增 `stage0-doctor-package-workspace-check`
- [x] 同步 verify-local success envelope，新增 `stage0DoctorPackageWorkspaceCheck`
- [x] 同步 `tools/stage0/README.md`、stage0 / developer tooling / package workflow specs、
      rolling plan、`progress.md`、`findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 40 Doctor Package/Workspace Coherence

### Goal

把 `doctor` 的只读 health inspection 再往 package/workspace truth 收拢：在有 `--workspace`
时复用 `ResolvePackageInspectionSourcePath(...)` + `ResolveWorkspaceModel(...)`，打印
`PackageProjection`，并在缺少 package workspace truth 时投影
`doctor.package-workspace-missing`；以 repo root 缺少 package descriptor 作为负向样本，
但继续保持 `doctor` 不是 `env sync`、`env use` 或 `env bootstrap`。

- owner 继续是 `tools/stage0/nextpas_command_doctor.pas` 与
  `tools/stage0/nextpas_projection_context.pas`
- truth objects 是 `TEnvironmentProjectionContext`、`TPackageProjectionContext` 与
  `TDoctorProjectionContext`
- line-based output 与 command envelope 同步投影 package workflow truth
- promotion gate 继续落在 `build/verify_local.sh` 的 `stage0-doctor-check`
- non-goal：不把 `doctor` 变成 package manager 执行面，也不修改环境状态

### Status

Completed

### Planned Steps

- [x] 先确认 `doctor` 的 package/workspace coherence 仍然是只读 inspection，而不是执行面
- [x] 在 `tools/stage0/nextpas_command_doctor.pas` 中有 `--workspace` 时复用 package inspection
      source path 与 workspace model，并打印 `PackageProjection`
- [x] 在 `tools/stage0/nextpas_projection_context.pas` 中加入
      `doctor.package-workspace-missing` finding，并把 package workflow truth 纳入 doctor check count
- [x] 扩展 `build/verify_local.sh` 的 `stage0-doctor-check`，冻结 repo root 的 package truth
      缺失边界与 envelope finding
- [x] 同步 `tools/stage0/README.md`、architecture specs、roadmap、`task_plan.md`、
      `progress.md`、`findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 39 Query Semantic Graph Side Tables

### Goal

把 `query symbols` 从“每个 symbol 都携带可读 metadata”继续推进到可被 CLI、automation
和 future IDE adapter 直接消费的 normalized semantic graph projection：

- owner 继续是 `TCompilationSession`；`stage0` CLI 不重扫源码、不解析 stdout、不维护第二套
  semantic lookup
- truth objects 是同一份 `TSemanticModel` 的 `TSemanticSymbol`、`TSemanticScope` 与
  `TSemanticType`
- line-based output 在 `query-symbols` 之外新增 `query-scopes=<json-array>` 与
  `query-types=<json-array>`，让 `scopeId` / `typeId` 可以通过同一份 query result 回查
- `command-envelope=<json>.result` 同步新增 `queryScopes` 与 `queryTypes`
- promotion gate 新增 `stage0-query-symbols-semantic-graph-check`，用 `var_halt.pas`
  冻结 unit scope `VarHalt` 与 builtin type `Integer` side table
- non-goal：不新增 LSP / language service session，不做 overlay、incremental invalidation、
  references、rename、completion，也不执行 MIR/backend/toolchain

### Status

Completed

### Planned Steps

- [x] 先把 `stage0-query-symbols-semantic-graph-check` 写成 RED gate
- [x] 在 `TCompilationSession` 中从 session-owned `TSemanticModel` 暴露 `ScopesJson` 与
      `TypesJson`
- [x] 扩展 query projection context、line output 与 envelope mirror
- [x] focused probe 确认 `var_halt.pas` 的 scope/type side tables 与 symbol metadata 同步
- [x] 同步 stage0 / developer tooling / rolling plan 文档和持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 38 Query Symbols Semantic Metadata

### Goal

把 Batch 37 已经公开的 `query-symbols` 从 raw ids 继续推进到可被 CLI、future IDE adapter
和 automation 直接消费的 semantic metadata projection，同时继续守住 query 只读边界：

- owner 继续是 `TCompilationSession`；`stage0` CLI 不从 stdout、源码文本或 build output
  反推 symbol metadata
- truth objects 是同一份 `TSemanticModel` 的 `TSemanticSymbol` / `TSemanticScope` /
  `TSemanticType`，以及同一份 `TUnitGraph` 的 owner unit truth
- `querySymbols[]` 在保留 raw `ownerUnitId`、`scopeId`、`typeId` 的同时，补充
  `ownerUnitName`、`scopeKind`、`scopeName`、`scopeParentId`、`typeName`、`typeKind`
  与 `typeParentId`
- promotion gate 继续落在 `build/verify_local.sh` 的 query check，新增 `var_halt.pas`
  focused probe，冻结变量符号 `x` 的 owner/scope/type metadata
- non-goal：不实现 references、rename、completion、open document overlay、incremental
  invalidation，也不执行 MIR/backend/toolchain

### Status

Completed

### Planned Steps

- [x] 先把 `stage0-query-symbols-semantic-metadata-check` 写成 RED gate
- [x] 在 `TCompilationSession.SymbolsJson` 中从 session-owned model / unit graph 补 semantic metadata
- [x] focused probe 确认 `var_halt.pas` 的变量符号输出 `ownerUnitName`、scope metadata 与 type metadata
- [x] 同步 stage0 / developer tooling / rolling plan 文档和持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Batch 37 Query Symbols Detail Projection

### Goal

把已经存在的只读 `query symbols` 从“只给 aggregate count”推进到可被 CLI、IDE adapter
和 automation 直接消费的结构化 symbol detail projection，同时继续守住它不是完整
language service / LSP 的边界：

- owner 继续是 `TCompilationSession` / `TSemanticModel`，不在 stage0 CLI 旁路重扫源码或解析输出
- truth object 是当前 semantic symbol graph 中的 `TSemanticSymbol`
- line-based output 必须新增 `query-symbols=<json-array>`，与 `query-result-count` 表达同一批结果
- `command-envelope=<json>.result` 必须新增 `querySymbols`，字段来自同一份 session-owned JSON
- promotion gate 继续落在 `build/verify_local.sh` 的 `stage0-query-symbols-check`
- non-goal：不实现 LSP server、open document overlay、incremental invalidation、references、
  rename preflight、completion 或 backend/toolchain execution

### Status

Completed

### Planned Steps

- [x] 先把 `stage0-query-symbols-check` 写成 RED gate，要求 line/envelope 两层 symbol detail
- [x] 在 `TCompilationSession` 暴露 session-owned `SymbolsJson`
- [x] 扩展 `TQueryProjectionContext`、text/json projection helper 与 `RunQuerySymbols`
- [x] 同步 stage0 / developer tooling / rolling plan 文档和持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Rolling Plan Batch 36 Truth Sync

### Goal

把当前 rolling plan 的入口状态同步到真实最新基线，避免后续恢复时误以为 production-path
contract 仍停在 `Batch 35`：

- `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md` 顶部必须写明当前最新完成批次是
  `Batch 36`
- 当前状态段必须把 stage0 driver decomposition、projection ownership、malformed manifest
  fallback、diagnostic record extensibility 与 resolver search-index staleness tracking 写成
  `Batch 36` 已验证 baseline
- `build/verify_local.sh` docs-check 必须要求当前 rolling plan 存在，避免活动主线入口从验证入口漂走
- 同步 `task_plan.md`、`progress.md`、`findings.md`，让下一次“继续”从真实最新批次恢复

### Status

Completed

### Planned Steps

- [x] 同步 rolling plan 顶部状态到 `Batch 36`
- [x] 将 rolling plan 纳入 docs-check
- [x] 同步持续记录
- [x] 运行 fresh `bash build/verify_local.sh`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 Architecture Principles and Quality Bar

### Goal

把“打造 FreePascal 领域一流现代 Pascal 开发环境”的高阶目标固化为可引用、可验证、
可执行的架构原则，而不是停留在愿景口号：

- 新增 `docs/architecture/architecture-principles-specification.md`，明确正确性、shared truth、
  thin entrypoint、性能前置、可维护性、统一词汇与兼容性诚实这些长期门槛
- 让 `overview.md`、`master-roadmap.md`、仓库 README 与架构目录都把这份规范作为后续设计入口
- 将新规范纳入 `build/verify_local.sh` 的 docs-check，避免架构质量门槛从仓库验证入口漂走
- 同步 `task_plan.md`、`progress.md`、`findings.md`，让后续“继续”能直接沿该质量门槛推进

### Status

Completed

### Completed Steps

- [x] 新增 `docs/architecture/architecture-principles-specification.md`
- [x] 同步 README、架构目录、总览、主路线图与 docs-check
- [x] 同步 `task_plan.md`、`progress.md`、`findings.md`
- [x] 运行 fresh `bash build/verify_local.sh`，确认新规范进入 docs-check 且整套
      `verify-local=pass`
- [x] 简短 review 后提交

## Addendum: 2026-05-24 `pkg inspect` package workflow detail hardening

### Goal

把已经存在的 package workflow truth 从 aggregate status 继续推进到可消费的只读细节投影，
同时继续守住 non-executing package manager 边界：

- `pkg inspect` 必须继续复用 `WorkspaceModel` / `PackageWorkflowTruth`，不执行 fetch、install、
  dependency resolution、lockfile write 或 publish workflow
- line-based output 必须冻结 workflow-owned manifest path、package root、package name、
  lock status 与 canonical lockfile path
- `command-envelope=<json>.result` 必须同步带上 `packageWorkflowManifestPath`、
  `packageRootPath`、`packageName`、`packageLockStatus` 与 `packageLockfilePath`
- `build/verify_local.sh` 必须把这批 detail fields 纳入 `stage0-pkg-inspect-check`

### Status

Completed

### Completed Steps

- [x] 扩展 `tools/stage0/nextpas_projection_text.pas`，新增
      `package-workflow-manifest-path`
- [x] 扩展 `tools/stage0/nextpas_projection_json.pas`，新增
      `packageWorkflowManifestPath`
- [x] 加严 `build/verify_local.sh` 的 `stage0-pkg-inspect-check`，冻结
      manifest path、package root、package name、lock status 与 lockfile path 的 line/envelope
      contract
- [x] 同步回写 `tools/stage0/README.md`、package workflow / roadmap docs 与持续记录
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass`

## Addendum: 2026-05-23 Installed-source Extra Assemble Boundary Closure

### Goal

把这轮 Stage2 / semantic smoke follow-up 从“linked root 缺少 source-backed unit `.o`”和
“unit root 被误扩成 transitive extra assemble”两侧一起收口，形成更诚实的最小边界：

- `compiler/diagnostics/np_diagnostics_sink.pas` 必须能稳定解析同目录
  `nextpas_json_helpers`，不再依赖偶然 search path
- `units/linux-x86_64/SysUtils.pas` 必须补齐当前 compiler path 真实需要的
  `IntToHex(Value: Int64; Digits: Integer)`
- `compiler/frontend/np_compilation_session.pas` 的
  `CollectAdditionalAssemblyBaseNames()` 必须只在 `program|library|package` 这类 linked root
  上收集额外 assemble base name，并允许 `installed-source` units 进入集合
- `unit` root 必须继续停留在 `host-fpc-emit-asm -> native-assemble`，不能为 transitive deps
  伪造 extra assemble steps
- `build/verify_local.sh` 必须把 `hello_with_units` 的 semantic-smoke reality 冻结为
  `typed-hir-node-count=8`、`tool-invocation-count=5`、`tool-run-step-count=5`、
  `tool-status-event-count=16`

### Status

Completed

### Completed Steps

- [x] 先复现 `hello_with_units` link failure，确认真实缺口是
      `Stage0Greeter.o` / `Stage0GreeterImpl.o` 没有物化，而不是 link command 本身错误
- [x] 在 `compiler/diagnostics/np_diagnostics_sink.pas` 补上 `{$UNITPATH .}`，让同目录
      `nextpas_json_helpers` 成为明确依赖
- [x] 在 `units/linux-x86_64/SysUtils.pas` 补上
      `IntToHex(Value: Int64; Digits: Integer)`，消除当前 compiler/self-host path 的 RTL 缺口
- [x] 调整 `CollectAdditionalAssemblyBaseNames()`：
      `unit` root 直接返回空集合；linked root 只跳过 `implicit-runtime`，不再错误排除
      `installed-source`
- [x] 回写 `build/verify_local.sh` 的 semantic-smoke contract，固定
      `hello_with_units` 为 5-step / 16-event，并把 `typedHirNodeCount` 改回真实 `8`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass`

## Addendum: 2026-05-23 Stage2 Self-compile Coverage Parity

### Goal

把 Stage2 compiler-module self-compile 的记录与 promotion path 对齐：上一批 notes 已经把
`np_workspace_model` 写成 fresh 成功，但 `build/verify_local.sh` 只 gate 了
`np_diagnostics_sink` 与 `np_source_database`。这批不扩大 self-hosting 语义，只把已经成立的
`np_workspace_model` unit-root object-file contract 固化进 verify。

### Status

Completed

### Completed Steps

- [x] 核对当前记录与 `build/verify_local.sh`，确认 drift 只在
      `np_workspace_model` 是否进入 promotion path
- [x] 在 `build/verify_local.sh` 增加
      `compiler/frontend/np_workspace_model.pas` self-compile probe
- [x] 复用 unit-root contract：`backend-output-kind=object-file`、
      `toolchain-plan-family=bootstrap-native-assemble`、
      `logical-link-request-status=deferred`
- [x] 额外冻结 `tool-invocation-count=2` / `tool-run-step-count=2` 与 no-`native-link`，
      防止 unit root 漂回 transitive extra assemble 或 link
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass`

## Addendum: 2026-05-23 Stage2 unit self-compile boundary

### Goal

把 Stage2 自编译从“卡在 target-installed `SysUtils` parser failure”和“把 `unit` 误当成
`executable` 去 link”的混合失败，收口成一个真实、可验证、可持续的最小成功边界：

- target-installed / compiler source 里的 `= class(Exception);` shorthand 改成 parser 已稳定支持的
  `class(Exception) ... end;`
- `compiler/backend/np_backend_plan.pas` 改为按 root kind 区分输出：
  `program|library|package -> executable`，`unit -> object-file`
- `compiler/toolchain/np_toolchain_plan.pas` 为 unit roots 走
  `bootstrap-native-assemble`（`host-fpc-emit-asm -> native-assemble`），不再伪造
  `native-link`
- `build/verify_local.sh` 纳入 compiler-module self-compile gate，冻结
  `np_diagnostics_sink`、`np_source_database` 与 `np_workspace_model` 的 object-file self-host
  contract

### Status

Completed

### Completed Steps

- [x] 重现并定位 `parser.syntax-error: "IMPLEMENTATION" expected but "END" found`
      到 `SysUtils` / compiler units 中的 `class(Exception);` shorthand
- [x] 将 `SysUtils`、compiler/toolchain/frontend 相关 unit 里的 shorthand class 统一改为
      显式空 body 形式
- [x] 让 backend plan 按 root kind 选择 `object-file` / `executable`
- [x] 让 toolchain plan 为 unit roots 选择 `bootstrap-native-assemble`
- [x] 移除遗留 `DBG-FALL:` stderr 调试输出
- [x] `build/verify_local.sh` 新增 compiler-module self-compile gate
- [x] fresh `bash build/verify_local.sh` 通过，确认 `verify-local=pass`

### Notes

- 这批不是宣称 nextPas 已经能把 compiler units “完整链接成可执行”，而是把当前真实 ownership
  诚实地推进到“能把 compiler units 编译成 object-file 并经过 native assemble”
- `np_diagnostics_sink` / `np_source_database` / `np_workspace_model` 现在都已在
  `backend-output-kind=object-file`、`toolchain-plan-family=bootstrap-native-assemble` 下进入
  fresh verify gate
- `array of const` 这一合法参数形态已补入 parser，并在 `TSemanticAnalyzer.GetParamSignature(...)`
  里补了 nil guard；`tests/parser/array_of_const_pass.pas` 已加入 parser smoke，fresh verify 通过

## Addendum: 2026-05-23 HIR LLVM alloca hoisting safety

### Goal

把 HIR LLVM emitter 的 SSA 命名从匿名数值寄存器切到稳定 named values，并让
`THIRBuilder.EnsureAlloca(...)` 真正写入函数 entry block。这样晚到的 slot materialization
不再受 LLVM 文本 IR 顺序编号约束，也不会再依赖 emitter 按 `ResultId` 重新排序 block。

- 修改 `compiler/ir/np_hir_builder.pas`：`EnsureAlloca(...)` 在函数上下文中直接调用
  `FModule.AddInstr(FCurrentFuncId, FEntryBlockId, Instr)`，把 fallback alloca hoist 到 entry block
- 修改 `compiler/ir/np_hir_llvm_emitter.pas`：新增 `ValueRef(...)`，把 raw `%` + 数值引用统一发射为
  `%vN` named SSA values（覆盖定义、使用与 function params）
- 去掉 `EmitFunction(...)` 中按首个 `ResultId` 重新排序 block 的 hack，恢复按 HIR block 原始顺序发射
- 新增 `tests/hir/test_hir_late_alloca_hoist.pas` focused probe：构造“非 entry block 首次 materialize
  late slot” 的 synthetic HIR，断言生成 IR 既能过 `opt` 解析，又把 `alloca` 放在 entry block
- 扩展 `build/verify_local.sh`：正式纳入上述 focused probe，并冻结 `%vN` named-value evidence

### Status

Completed

### Completed Steps

- [x] `THIRBuilder.EnsureAlloca(...)` 改为 entry-block insertion
- [x] `THIRLlvmEmitter` 新增 `ValueRef(...)` 并切换 raw numeric SSA refs 到 `%vN`
- [x] `EmitFunction(...)` 改为按 HIR block 原始顺序发射，不再按 `ResultId` 排序
- [x] 新增 `tests/hir/test_hir_late_alloca_hoist.pas`
- [x] `build/verify_local.sh` 纳入 focused hoist gate，并用 `opt -disable-output` 验证 IR
- [x] fresh `bash build/verify_local.sh` 通过，确认 LLVM/host 路径无回退

### Notes

- 这批不是扩 LLVM 语义面，而是把既有 HIR path 的文本 IR 稳定性补齐，为后续更多 late alloca /
  synthetic slot 场景扫掉结构性约束
- `%arralloc.*`、`%abs.*`、`%is.*`、`%callstr.*` 这类已有显式命名 helper SSA 名继续保留；
  变化的是原先裸 `%1/%2/...` 的 result / operand / param 引用现在统一成为 `%vN`

## Addendum: 2026-05-17 Sema Const Identifier Resolution — Halt(MyConst) → exit(42)

### Goal

把 sema 折叠器从"只折常量字面量表达式"推进到"能解析 const 声明的标识符引用"。
上一批次让 `Halt(40 + 2)` 折叠为 42；这一批让 `const FortyTwo = 42; begin Halt(FortyTwo); end.`
也能正确退出 42。

- 扩展 `compiler/sema/np_semantic_model.pas` 加 `TSemanticConstValue` record 与
  `FConstValues: array of TSemanticConstValue`；新增 `AddConstValue(name, value)` 与
  `LookupConstValue(name, out value): Boolean`
- 扩展 `EvaluateIntegerConstant` 加 `gnkIdentifier` 分支：从 `FModel.LookupConstValue`
  查表，命中即返回常量值
- 改造 `ProcessConstSection`：每个 `gnkConstDecl` 子节点尝试 `EvaluateIntegerConstant`
  折叠值，命中即 `AddConstValue(name, value)` 注册到表
- 新增 `examples/smoke/halt_const.pas`：`program HaltConst; const FortyTwo = 42; begin Halt(FortyTwo); end.`
- 新增 `build/verify_local.sh` 的 `llvm-halt-const-program` gate：用真 opt/llc/ld 编译
  halt_const.pas，断言 IR 含 `exit-code: 42`、含 `movl $$42, %edi`，可执行 exit 42

### Status

Completed

### Completed Steps

- [x] sema model 加 `TSemanticConstValue` 与 `FConstValues` 数组，constructor 初始化
- [x] sema model 加 `AddConstValue` / `LookupConstValue`（大小写不敏感名称比对，重复 name 覆盖旧值）
- [x] `EvaluateIntegerConstant` 新增 `gnkIdentifier` case，从 `LookupConstValue` 查表
- [x] `ProcessConstSection` 遍历每个 `gnkConstDecl` 子节点尝试折叠并 `AddConstValue` 注册
- [x] 新增 `examples/smoke/halt_const.pas` fixture
- [x] `build/verify_local.sh` 加 `LLVM_HALT_CONST_PROGRAM_OUTPUT` /
      `LLVM_HALT_CONST_PROGRAM_OUT_DIR` 临时文件，新增 `llvm-halt-const-program` gate，
      success envelope 加 `llvmHaltConstProgram`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass`

### Decisions Made

| Decision | Rationale |
| --- | --- |
| const 表用大小写不敏感名称比对 | Pascal 标识符传统大小写不敏感；与 `WalkHaltCalls` 的 `SameText('Halt')` 一致 |
| ProcessConstSection 折叠失败时只跳过 AddConstValue，不报诊断 | const 声明可能是非整数（字符串、记录），折叠失败不代表错；当前批次只关心整数常量；非整数 const 引用在 EvaluateIntegerConstant 自动失败回到 fallback |
| const 表挂在 `TSemanticModel` 而不是 `TSemanticAnalyzer` | 与现有 `FSymbols` / `FTypes` 等 model-owned 数据保持一致；分析器只负责填充，model 持有真实数据 |
| 重复名称覆盖而不是报错 | 当前 sema 还没有完整 redeclaration 检查；先静默覆盖避免假诊断，等真正的 symbol-redecl 检查批次再加 |

### Notes

- 这是 sema 第一次跨节点引用解析：表达式折叠器从纯 AST-recursive 升级到 model-aware
- 当前 const 表只支持整数类型；string / 浮点 / 数组 const 值仍属未来批次
- `verify-local` 现在含四条 LLVM 端到端 gate：`llvmEmptyProgram`（exit 0）、
  `llvmHaltProgram`（exit 42 from literal）、`llvmHaltExprProgram`（exit 42 from 40+2）、
  `llvmHaltConstProgram`（exit 42 from const FortyTwo = 42）

## Addendum: 2026-05-17 Sema Integer Constant Folding — Halt(40 + 2) → exit(42)

### Goal

把 nextPas 的 sema 从"只接受 Halt 直接字面量参数"推进到"折叠任意整数常量表达式"。
上一批次 `Halt(N)` 走 LLVM 退出 N，但 `Halt(40 + 2)` 会因 sema 仅匹配 `gnkIntegerLiteral`
直接子节点而退化到默认 0。这一批让 sema 在编译期完成整数常量折叠，
让 `Halt(N op M)` / `Halt(-N)` 等表达式也能正确决定退出码。

- 扩展 `compiler/sema/np_semantic_analyzer.pas` 新增 `EvaluateIntegerConstant(Node, out Value)`：
  递归折叠 `gnkIntegerLiteral` / `gnkUnaryExpression`(+/-) /
  `gnkBinaryExpression`(+/-/*/div/mod)；除零返回 false；非整数节点或未识别 op 返回 false
- 改造 `WalkHaltCalls`：把"只匹配 `gnkIntegerLiteral`"换成 `EvaluateIntegerConstant`，
  折叠成功才发射 `halt-call` HIR 节点；失败时 operand 默认 `0`
- 新增 `examples/smoke/halt_expr.pas`：`program HaltExpr; begin Halt(40 + 2); end.`
- 新增 `build/verify_local.sh` 的 `llvm-halt-expr-program` gate：用真 opt/llc/ld 编译
  halt_expr.pas，断言 IR 含 `exit-code: 42`、含 `movl $$42, %edi`，可执行 exit 42

### Status

Completed

### Completed Steps

- [x] sema 加 `EvaluateIntegerConstant` 折叠器（unary +/-、binary +/-/*/div/mod、字面量）
- [x] `WalkHaltCalls` 改用 `EvaluateIntegerConstant` 替代直接 `gnkIntegerLiteral` 匹配
- [x] 新增 `examples/smoke/halt_expr.pas` fixture
- [x] `build/verify_local.sh` 加 `LLVM_HALT_EXPR_PROGRAM_OUTPUT` /
      `LLVM_HALT_EXPR_PROGRAM_OUT_DIR` 临时文件，新增 `llvm-halt-expr-program` gate，
      success envelope 加 `llvmHaltExprProgram`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass`

### Decisions Made

| Decision | Rationale |
| --- | --- |
| 折叠器在 sema 层而非 MIR lowerer | 折叠产生的整数常量需要进 HIR 的 `Operand` 字段以传给 MIR；MIR lowerer 只读 HIR 操作数；当前没有 typed value system，sema 是唯一能消费 AST 表达式形态的层 |
| 用 `Int64` 内部计算 | 避免 Pascal 整数子集分歧；Halt 退出码最终被截到 8 位（POSIX `_exit` 语义），但中间表达式可以触及 64 位范围 |
| 折叠失败默认 0，不发诊断 | 当前批次专注 Halt 表达式折叠路径；非常量表达式（变量、未支持运算）应进入下一批的真实 codegen，不该在此批次假装"已支持但 silently 错"。先静默 fallback、保留 0 行为，等 typed expression codegen 落地再加诊断 |
| 折叠器涵盖 +/-/*/div/mod 而非仅 +/- | 这五个 op 是 Pascal 整数常量表达式核心子集；新增成本 ~每 op 5 行，但避免下次再来一批 "MUL 折叠" |

### Notes

- 这是 sema 第一次具备**编译期求值**能力。不是完整 const-eval 系统，但已经能把
  `Halt(40 + 2)` 这类整数常量表达式正确折叠到运行时退出码
- 当前 emitter 仍只看 MIR `halt` op 的 operand 字段；变量、函数返回值、
  字符串等非常量参数仍属下一批次（需要真实 LLVM 表达式 codegen）
- `verify-local` 现在含三条 LLVM 端到端 gate：`llvmEmptyProgram`（exit 0）、
  `llvmHaltProgram`（exit 42 from literal）、`llvmHaltExprProgram`（exit 42 from 40+2）

## Addendum: 2026-05-17 MIR-driven LLVM Codegen — Halt(N) → exit(N)

### Goal

把 nextPas 的 LLVM 路径从"无论源代码写什么都 exit 0"推进到"程序退出码由源代码决定"。
这是首个 **MIR 真实决定运行时行为** 的批次：MIR operand 不再恒为空字符串，
LLVM emitter 不再发射固定 empty shell。

- 扩展 `compiler/ir/np_mir_model.pas` 的 `TMirOperation` 加 `Operand: string` 字段，
  `AddOperation` 多一个 operand 参数，新增 `OperationAt(Index)` 让 emitter 能读取 ops
- 扩展 `compiler/sema/np_semantic_model.pas` 的 `TTypedHirNode` 同样加 `Operand: string`
  字段，`AddTypedHirNode` 多一个 operand 参数
- 扩展 `compiler/sema/np_semantic_analyzer.pas` 新增 `WalkHaltCalls` + `SeedHaltCalls`：
  遍历 program body 找 `gnkProcedureCallStatement` 文本为 `Halt`，捕获第一个
  `gnkIntegerLiteral` 子节点作为 operand，发射 `halt-call` HIR 节点
- 扩展 `TMirLowerer.MirKindForTypedHirNode` 把 `halt-call` HIR 翻译为 `halt` MIR op，
  operand 透传
- 扩展 `compiler/backend/np_llvm_emitter.pas`：扫 MIR ops 找 `halt` 提取 operand（默认 0），
  发射 `_start` 时把 syscall arg 写为该 operand 值；emitter 不再写死 `xorl %edi, %edi`
- 新增 `examples/smoke/halt_42.pas` fixture：`program HaltFortyTwo; begin Halt(42); end.`
- 修复 `tests/toolchain/toolchain_contract_smoke.pas` 的 `MirModel.AddOperation` 调用
  对齐新签名
- 新增 `build/verify_local.sh` 的 `llvm-halt-program` gate：用真 opt/llc/ld 编译
  halt_42.pas，断言 IR 含 `exit-code: 42`、含 `movl $$42, %edi`，可执行 exit 42

### Status

Completed

### Completed Steps

- [x] `TMirOperation` + `AddOperation` 加 Operand 字段，新增 `OperationAt(Index)` accessor
- [x] `TTypedHirNode` + `AddTypedHirNode` 加 Operand 字段；6 处现有调用点全部跟进
- [x] `TSemanticAnalyzer` 新增 `WalkHaltCalls` + `SeedHaltCalls`，挂进 `Analyze`
      末尾在 `SeedRuntimeContracts` 之后
- [x] `TMirLowerer.MirKindForTypedHirNode` 加 `halt-call -> halt` 分支；
      lowerer 主循环把 HIR operand 透传给 MIR `AddOperation`
- [x] `TLlvmEmitter.ResolveExitCode` 扫 MIR ops 找 `halt`，从 operand 解析整数
      （Val 解析失败默认 0）；`EmitToFile` 发射 syscall arg 为该值
- [x] 新增 `examples/smoke/halt_42.pas`
- [x] 修复 `tests/toolchain/toolchain_contract_smoke.pas:536` 的 `AddOperation` 4 参签名
- [x] `build/verify_local.sh` 加 `LLVM_HALT_PROGRAM_OUTPUT` / `LLVM_HALT_PROGRAM_OUT_DIR`
      临时文件，新增 `llvm-halt-program` gate（IR 含 marker、可执行 exit 42），
      success envelope 加 `llvmHaltProgram`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass` 与
      `human-summary=local verification passed`

### Decisions Made

| Decision | Rationale |
| --- | --- |
| 用 `string` 字段载 operand，而不是引入 typed `TMirValue` 联合体 | 当前只需透传字面量给 emitter；引入 value system 会牵动 MIR/HIR/sema/emitter 四层，扩展面太大；string 可后续被 typed value 替换而不破坏调用接口 |
| `halt-call` HIR 节点直接挂在 typed-hir 序列尾部，不进 block-structured CFG | 当前 MIR 仍是平铺 op 序列、单 entry block；引入 control-flow 应单独批次 |
| emitter `ResolveExitCode` 解析失败默认 0，不报 diagnostic | sema 已经只在捕获到 `gnkIntegerLiteral` 时才发 operand，emitter 收到非数字 operand 是内部 bug 不是用户错误；先静默 fallback，等 typed value 再加诊断 |
| `WalkHaltCalls` 做大小写不敏感比对（`SameText`） | Pascal 标识符传统大小写不敏感；与 `gnkProcedureCallStatement.Text` 保留原 lexeme 一致 |

### Notes

- 这是 MIR 第一次真实决定运行时行为：之前 MIR 即使存在也只是路径占位符，
  `verify-local` 里 empty-program 和 halt-program 现在是两条**结果不同**的真实测试
- 当前 emitter 仍只生成 `_start` + 单条 syscall；多条 `Halt(N)` 会让最后一条赢，
  control-flow / function call / multiple statements 仍属下一批次
- `halt_42.pas` 通过 LLVM binding 编译运行 exit 42，但默认 binding (gnu) 走宿主 FPC，
  那条路径仍由宿主决定行为；这是预期的，因为只有 LLVM 路径走 nextPas 自有 codegen
- 这一批不替换历史 addendum；下一批次自然入口是把 MIR 操作扩到包含
  整数 const / 二元运算 / 简单条件，让 `Halt(2 + 3)` 类表达式也能正确 lower

## Addendum: 2026-05-17 LLVM Backend First Codegen — Empty Program End-to-end

### Goal

把 nextPas 从“所有编译成功都是宿主 FPC 干的”推进到“nextPas 自己拥有 codegen ownership 的最小真实链路”。
之前 `compiler/ir/np_mir_model.pas` 是字符串占位符、`compiler/backend/np_backend_plan.pas` 90% 在算路径
0% 生成代码，所有 `.s` 都来自 `host-fpc-emit-asm`。这一批让 nextPas 自己写出 `.ll` 文件并由 LLVM
工具链产出真实可执行：

- 新增 `compiler/backend/np_llvm_emitter.pas`：从 `TMirModel` + `TTargetFactsView` 发射文本 LLVM IR
  到磁盘；当前批次只发射最小 empty-program shell（`define void @_start` + inline syscall exit(0)），
  绕开缺失的 distribution runtime libc，让 nextPas 真正拥有 entry point
- 让 `TBackendPlanner.Plan` 在 `BackendFamily='llvm'` 时调用 emitter 真实写 `.ll`，
  而不是只注册 artifact 路径
- 把 `compiler/toolchain/np_toolchain_plan.pas` 的 `PlanLlvmIrOptObjectLink` link step 从硬编码的
  `ExecutableSet.Lld` 切到 `LinkerProfile.DriverCandidates`，使 LLVM binding 复用 linker profile
- 把 `build/toolchains/linux-x86_64-to-linux-x86_64-llvm.toml` 的 linker 从 `lld-elf` 切到 `gnu-ld`，
  不引入新依赖（系统未安装 `ld.lld`，但 `ld` 与 native binding 已在用）
- 默认 backend 不变（`bootstrap-native-assemble-link`），LLVM 路径通过
  `--toolchain-binding linux-x86_64-to-linux-x86_64-llvm` 显式选择

### Status

Completed

### Completed Steps

- [x] 摸清现有 LLVM skeleton：`PlanLlvmIrOptObjectLink`、`PrepareLlvmContract`、`TBackendPlan`
      LLVM 字段已就位；缺口是 (a) 没有 IR emitter，(b) link step 写死 `ld.lld`，(c) binding 配置
      指向未安装的 `ld.lld`
- [x] 手工验证最小 LLVM 链路（`opt → llc → ld` + 自写 `_start` syscall exit(0)）能产出 exit 0
      可执行，确认 IR 模板可行
- [x] 新增 `compiler/backend/np_llvm_emitter.pas`，提供 `TLlvmEmitter.EmitToFile`，按
      target triple/data layout 发射 IR header，再发射 empty-program shell
- [x] 修改 `compiler/backend/np_backend_plan.pas`：在 `BackendFamily='llvm'` 分支调用
      `Emitter.EmitToFile`，`ForceDirectories` 后再发射；失败时 `MarkFailure`
- [x] 修改 `compiler/toolchain/np_toolchain_plan.pas:1394` link step：从 `ExecutableSet.Lld`
      改为 `FirstStringOrDefault(LinkerProfile.DriverCandidates, 'ld')`
- [x] 修改 `build/toolchains/linux-x86_64-to-linux-x86_64-llvm.toml`：linker 从 `lld-elf`
      切到 `gnu-ld`
- [x] 修改 `build/verify_local.sh` 的现有 `llvm-binding-smoke` gate：fake stub 从 `ld.lld`
      改名为 `ld`，`linker-profile-id` 断言从 `lld-elf` 改为 `gnu-ld`
- [x] 在 `build/verify_local.sh` 新增 `llvm-empty-program` gate：用真 `opt`/`llc`/`ld` 编译
      `examples/smoke/hello.pas`，断言 `toolchain-plan-family=llvm-ir-opt-llc-link`、
      `backend-artifact-count=4`、`.ll` 文件存在并含 `@_start`、可执行 exit 0
- [x] 把 `llvmBindingSmoke`/`llvmEmptyProgram` 加进 verify-local success envelope
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass` 与
      `human-summary=local verification passed`

### Decisions Made

| Decision | Rationale |
| --- | --- |
| LLVM linker 切到系统 `ld`（gnu-ld），不装 `ld.lld` | 与 native binding 对称、零新依赖；后续如果引入 `ld.lld` 可独立切回 |
| Empty program 自写 `_start` + inline syscall exit(0)，不依赖 libc/_start | 当前 distribution runtime SDK 缺 `lib/nextpas/runtime/linux-x86_64/libc.so`；自写 `_start` 顺带让 nextPas 拥有 entry point ownership，与"独立 RTL"长期方向一致 |
| 默认 backend 保持 `bootstrap-native-assemble-link`，LLVM 通过 `--toolchain-binding` 显式选择 | 现有 40+ verify gate 全围绕 native 默认路径；一次性切默认会大面积翻车，不该和 codegen 引入混在一批 |
| 这一批 emitter 只发射 empty-program shell，不消费 MIR operations | 当前 MIR 是字符串占位符（`Kind: string` + `DisplayName`），还没有 value semantics；先把"自有 codegen 链路"打通，再分批扩 IR 表达力 |

### Notes

- 这是 nextPas 第一次真实生成代码：之前任何 `.s` 都来自 `host-fpc-emit-asm`，现在 `.ll` 由
  `TLlvmEmitter` 自己写
- 当前 LLVM 路径的真实功能只覆盖 `program X; begin end.` 这一种程序：任何带 `WriteLn`、表达式、
  类型、调用的程序都会发射同样的 empty shell（IR 中只有 `_start`+syscall），运行时仍 exit 0
  但实际语义被丢失。下一批次需要在 emitter 中开始消费 MIR operation
- LLVM 路径仍不能 self-host：MIR 还没有 value/type/control-flow，所以 nextPas 自己的 compiler module
  不能用 LLVM backend 编译；这与 `docs/plans/2026-05-02-stage2-feasibility-assessment.md` 的判断一致
- `compiler-roadmap.md` 第 5 段 “Target / Cross / LLVM / C Interop” 的 LLVM 部分从“skeleton 已就位”
  正式进入“最小真实闭环已就位”
- 这一批不替换历史 addendum，也不动 `bootstrap-native-assemble-link` 路径

## Addendum: 2026-05-17 Repo Hygiene + Classes RTL Source-of-truth Convergence

### Goal

把这次会话前发现的两类工作树级问题一次收口，并把下一批次入口明确转向 RTL Classes 实现，
而不是继续在 verify gate 上叠 addendum：

- 工作树污染：`core.997688`（22MB FPC core dump）、四个空 `crash_*.txt`、`ppas.sh`、
  `tools/stage0/nextpas_*.s`（5 个 ~250KB 残留汇编中间产物）必须从 untracked 状态清掉，
  并在 `.gitignore` 中通过 `core.*` / `crash_*.txt` / `ppas.sh` / `tools/stage0/*.s`
  正式 ignore，避免下一次崩溃或中断重新污染
- RTL Classes 必须收敛到与 SysUtils 一致的 source-of-truth 模式：
  `rtl/core/classes/np_classes.pas` 是唯一源，checked-in `Classes.pas` / `Classes.o` /
  `Classes.ppu` 一律由 build 派生并通过 `.gitignore` 排除；删掉之前与 `np_classes.pas`
  字节级一致的 `Classes.pas` 重复源
- 这一批不引入新代码、不改公开 line-based output / `command-envelope=<json>` 契约；
  fresh `bash build/verify_local.sh` 必须继续全绿

### Status

Completed

### Completed Steps

- [x] 删除工作树污染文件：`core.997688`、`crash_err.txt`、`crash_out.txt`、
      `crash_output.txt`、`crash_stdout.txt`、`ppas.sh`、
      `tools/stage0/nextpas_command_envelope.s`、`tools/stage0/nextpas_json_helpers.s`、
      `tools/stage0/nextpas_projection_json.s`、`tools/stage0/nextpas_projection_text.s`、
      `tools/stage0/nextpas_projection_types.s`
- [x] 删除 `rtl/core/classes/Classes.pas`（与 `np_classes.pas` 字节级一致的重复源），
      并清理其残留 `Classes.o` / `Classes.ppu`
- [x] 扩展 `.gitignore`，新增
      `rtl/core/classes/Classes.pas`、`rtl/core/classes/Classes.o`、
      `rtl/core/classes/Classes.ppu`、`core.*`、`crash_*.txt`、`ppas.sh`、
      `tools/stage0/*.s`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认整套 `verify-local=pass` 与
      `human-summary=local verification passed`

### Decisions Made

| Decision                                                                        | Rationale                                                                                                |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Classes 收敛到 `np_classes.pas` 唯一源 + ignore 派生 `Classes.{pas,o,ppu}`      | 与 `rtl/core/sysutils/` 已建立的模式一致；checked-in 重复源会让 source-of-truth 漂移并误导下游 contributor |
| 工作树污染统一通过 `.gitignore` 模式封堵，不靠每次手动清理                      | FPC 崩溃 core dump、`ppas.sh` 中断脚本、`tools/stage0/*.s` 汇编中间产物都是已知会复现的工件             |
| 这一批不动 `np_classes.pas` 内容，也不实现 Classes 容器                         | 先把 source-of-truth 边界定清楚，再进入 RTL Classes 实现批次；避免一次混入两个方向                       |

### Notes

- 下一批次入口正式转向 RTL Classes 实现：`np_classes.pas` 当前只暴露最小 `TFileStream`
  shape，离 compiler module 真正能 `uses Classes` 还差容器类（`TStringList`、`TList`）；
  这与 `docs/plans/2026-05-02-stage2-feasibility-assessment.md` 列出的 Stage2 阻塞项一致
- 这一批不替换历史 addendum，也不改架构规范；`docs/plans/2026-05-02-rtl-implementation-plan.md`
  仍然是 RTL 推进的 owning plan，本 addendum 只负责把仓库卫生与 source-of-truth 模式
  同步到 task_plan 顶层，避免下一轮恢复时再被这批工件分散注意力

## Addendum: 2026-04-29 Package Workflow Truth Skeleton

### Goal

把 package workflow 的第一批 shared truth 从文档语义推进到 compiler-owned 最小实体，同时继续
守住“只读 truth / 非执行 workflow / 不伪装完整 package manager”这条边界：

- 新增 `compiler/frontend/np_package_workflow.pas`，至少拥有
  `TPackageManifestTruth`、`TPackageLockTruth`、`TPackageInstallPlanTruth` 与
  `TPackageWorkflowTruth`
- 这批 truth 必须消费 `np_package_manifest.pas` 已有的 `TPackageManifestInfo`，不重新发明 parser
- `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh` 必须冻结
  `package-workflow-manifest-status=ready`、`package-workflow-lock-status=deferred`、
  `package-install-plan-status=deferred` 与 `package-workflow-source-root-count=<non-zero>`
- 文档与持续记录必须同步成当前 reality，并明确这批不做 registry、fetch、install、solver
  或 lockfile write

### Status

Completed

### Completed Steps

- [x] 先在 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
      写出 package workflow truth 的 RED contract，并 fresh 运行确认失败点正好落在
      `np_package_workflow` unit 尚未存在
- [x] 新增 `compiler/frontend/np_package_workflow.pas`，最小落地
      `TPackageManifestTruth`、`TPackageLockTruth`、`TPackageInstallPlanTruth` 与
      `TPackageWorkflowTruth`
- [x] 让 manifest truth 消费 `TPackageManifestInfo` 的 manifest/package/source-root 事实；
      让 lock/install truth 只暴露 canonical path/provenance，并继续保持 `deferred`
- [x] 同步回写 `docs/architecture/package-workflow-specification.md`、
      `docs/architecture/workspace-file-format-specification.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 package workflow contract 与
      整套 `verify-local=pass`

## Addendum: 2026-04-29 Minimal Query Symbols Surface

### Goal

把 developer tooling 里的第一条 semantic query surface 收成最小但真实的统一 `nextpas`
命令入口，同时继续守住“query / language service / build execution”的分层：

- `tools/stage0/nextpas.pas` 必须新增最小 `query` family，至少支持
  `nextpas query symbols <source> --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`
- `query symbols` 只负责只读 semantic query，不承担 LSP、open document overlay、
  incremental invalidation、references、rename 或 completion
- 当前 query 必须复用 compilation session 的 syntax / resolution / semantic truth，
  并显式投影 `analysis-source=compilation-session`
- `build/verify_local.sh` 必须新增 `nextpas query symbols` 的 success gate 与 bare
  `nextpas query` 的 invalid-arguments gate
- 文档与持续记录必须同步成当前 reality，并明确这批不执行 MIR、backend 或 toolchain

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 为
      `nextpas query symbols examples/smoke/hello_with_units.pas --target linux-x86_64 --workspace <repo>`
      与 bare `nextpas query` 写出 RED contract，并 fresh 运行确认失败点正好落在
      `query` command 尚未实现
- [x] 扩展 `tools/stage0/nextpas.pas`，新增 `query` command parse/usage 与 `symbols`
      selector，支持可选 `--toolchain-binding <id>` 与 `--workspace <root>`
- [x] 让 `query symbols` 复用 `ResolveWorkspaceModel(...)`、target facts 与
      `TCompilationSession`，只执行 syntax、unit resolution 与 semantic analysis
- [x] 新增最小 query projection，把 `query-kind`、`query-status`、`analysis-source`
      与 `query-result-count` 投影到 line-based output 和 `command-envelope=<json>.result`
- [x] 同步回写 `tools/stage0/README.md`、`tools/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/language-service-specification.md`、
      `docs/architecture/developer-tooling-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 `stage0QueryCheck`、
      `stage0QueryInvalidArgumentsCheck` 与整套 `verify-local=pass`

## Addendum: 2026-04-29 Stage0 Doctor Minimal Read-only Health Surface

### Goal

把 developer tooling 里下一条最小但真实的 health inspection surface 收成统一 `nextpas`
命令壳，同时继续守住“状态解析 / 健康诊断 / 环境修改”分层：

- `tools/stage0/nextpas.pas` 必须新增最小 `doctor` family，至少支持
  `nextpas doctor --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`
- `doctor` 只负责只读 inspection，不承担 `env sync` / `env use` / `env bootstrap`
  这类环境修改
- 当前 environment 即使仍不完整，命令也应保持 execution-successful；真实健康摘要通过
  `doctor-status`、`doctor-check-count` 与 `doctor-finding-count` 投影
- `build/verify_local.sh` 必须新增 `nextpas doctor` 的 success gate 与 bare
  `nextpas doctor` 的 invalid-arguments gate
- 文档与持续记录必须同步成当前 reality，并明确这批故意不把 richer finding taxonomy /
  suggested action / `query` / package workflow 伪装成已落地能力

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 为
      `nextpas doctor --target linux-x86_64 --workspace <repo>` 与 bare
      `nextpas doctor` 写出 RED contract，并 fresh 运行确认失败点正好落在
      `doctor` command 尚未实现
- [x] 扩展 `tools/stage0/nextpas.pas`，新增 `doctor` command parse/usage 与最小
      `doctor` selector，支持可选 `--toolchain-binding <id>` 与 `--workspace <root>`
- [x] 让 `doctor` 复用现有 target/toolchain/distribution/runtime truth 与可选 workspace root，
      投影 `runtime-libc-present`、`environment-readiness`、`runtime-sdk-status`、
      `doctor-status`、`doctor-check-count` 与 `doctor-finding-count`
- [x] 保持 `doctor` 为只读 health inspection：即使当前 runtime libc 缺失，也继续以
      `status=success` / `result=success` 完成，并把“不健康”写进 doctor fields
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/developer-tooling-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 `stage0DoctorCheck`、
      `stage0DoctorInvalidArgumentsCheck` 与整套 `verify-local=pass`

## Addendum: 2026-04-29 Doctor Result Contract Hardening

### Goal

把 `doctor` 从 aggregate health summary 继续加固成可被 CLI、CI 与 future IDE adapter
稳定消费的结构化 result contract，同时不把 health finding 误放进 compiler diagnostics sink：

- `build/verify_local.sh` 必须冻结 `doctor-workspace-status` 与
  `doctor-toolchain-binding-status`
- runtime SDK 缺失必须输出代表性 finding：
  `doctor-finding-code=doctor.runtime-sdk-missing` 与
  `doctor-finding-severity=warning`
- `command-envelope=<json>.result.doctorFindings[]` 必须同步保留
  `code`、`severity`、`subject`、`summary` 与 `suggestedAction`

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 加入 focused RED gate，确认 fresh
      `bash build/verify_local.sh` 失败于缺少 `doctor-workspace-status`
- [x] 在 `tools/stage0/nextpas.pas` 引入最小 `TDoctorFinding` 与扩展后的
      `TDoctorProjectionContext`，保留 first finding line projection 与 envelope array
- [x] 继续保持 `doctor` 为只读 inspection：当前 runtime SDK 缺失仍返回
      `status=success` / `result=success`，健康问题写进 `doctorFindings`
- [x] 同步回写 `docs/architecture/diagnostics-specification.md`、
      `docs/architecture/developer-tooling-specification.md`、`task_plan.md`、
      `findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认结构化 finding contract 与
      `verify-local=pass`

## Addendum: 2026-04-29 Richer Env Status Readiness Evidence

### Goal

把 `env status` 的只读 state projection 从路径与 runtime 状态继续加固到可供
`doctor` 与 future `env sync` 复用的 readiness evidence：

- `environment-readiness` 保留为兼容字段，但与新增 `environment-status` 使用同一
  derived readiness vocabulary
- `runtime-sdk-status` 继续表达 runtime SDK 是否 ready / missing
- 新增 `toolchain-binding-status` 与 `distribution-status`
- `command-envelope=<json>.result` 必须同步保留 `environmentStatus`、
  `runtimeSdkStatus`、`toolchainBindingStatus` 与 `distributionStatus`

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 加入 focused RED gate，确认 fresh
      `bash build/verify_local.sh` 失败于缺少 `environment-status`
- [x] 扩展 `tools/stage0/nextpas.pas` 的 `TEnvironmentProjectionContext`，
      从既有 target/binding/distribution/runtime truth 推导 environment、runtime SDK、
      binding 与 distribution readiness
- [x] 保持 `env status` 为 execution-successful 的只读 projection：当前 runtime SDK /
      distribution 仍不完整时继续返回 `status=success` / `result=success`
- [x] 让 `doctor` 复用同一份 `toolchain-binding-status`，避免 doctor/env 各自推导
      binding readiness
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/developer-tooling-specification.md`、`task_plan.md`、
      `findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 readiness evidence 与
      `verify-local=pass`

## Addendum: 2026-04-26 Stage0 Env Status Read-only Projection

### Goal

把 developer tooling 里下一条最小但真实的 environment surface 收成统一 `nextpas` 命令壳，
但继续守住“状态解析”和“健康诊断/环境修改”分层：

- `tools/stage0/nextpas.pas` 必须新增最小 `env` family，至少支持
  `nextpas env status --target linux-x86_64 [--toolchain-binding <id>]`
- `env status` 只负责解析 target / binding / distribution / runtime state，不承担
  `doctor` 诊断，也不提前引入 `env use` / `env sync` / `env bootstrap`
- 当前 environment 即使仍不完整，命令也应保持 execution-successful；真实 readiness 继续通过
  `environment-readiness`、`runtime-sdk-status` 与 `runtime-libc-present` 投影
- `build/verify_local.sh` 必须新增 `nextpas env status` 的 success gate 与
  bare `nextpas env` 的 invalid-arguments gate
- 文档与持续记录必须同步成当前 reality，并明确这批故意不把 mutation verbs / `doctor` /
  `query` 伪装成已落地能力

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 为 `nextpas env status --target linux-x86_64` 与
      bare `nextpas env` 写出 RED contract，并 fresh 运行确认失败点正好落在
      `env` command 尚未实现
- [x] 扩展 `tools/stage0/nextpas.pas`，新增 `env` command parse/usage 与最小
      `status` selector，支持可选 `--toolchain-binding <id>`
- [x] 让 `tools/stage0/nextpas.pas` 复用现有 target/toolchain/distribution/runtime truth，
      投影 `toolchain-binding-path`、distribution dirs、`runtime-root`、`runtime-libc`、
      `runtime-libc-present`、`environment-readiness` 与 `runtime-sdk-status`
- [x] 保持 `env status` 为只读 state projection：即使当前 runtime libc 缺失，也继续以
      `status=success` / `result=success` 完成，并把“不完整”写进 readiness fields
- [x] 同步回写 `tools/stage0/README.md`、
      `tools/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/developer-tooling-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 `stage0EnvStatusCheck`、
      `stage0EnvInvalidArgumentsCheck` 与整套 `verify-local=pass`

## Addendum: 2026-04-05 Workspace Model Shared Truth Convergence
asd
### Goal

把当前已经存在但仍散落在 `tools/stage0/nextpas.pas` driver helper 与 session 选项字段里的
workspace/package/artifact discovery，收口成 compiler-owned shared model，同时保持现有
公开 line-based output、`command-envelope=<json>`、resolver precedence 与 early-failure
behavior 不漂移：

- 新增最小 `WorkspaceModel` / `PackageRef` / `TargetSelection` / `ArtifactRootSet`
  Pascal 实体，承接当前真实存在的 workspace root、package refs、source roots、
  artifact root、output dir 与 host-fpc cache root truth
- `TCompilationSession` 正式拥有这份 model，不再只持有一组散落的 workspace/build 字段
- `tools/stage0/nextpas.pas` 只保留 CLI override 与 orchestration，不再自己维护
  workspace discovery、package roots 与 artifact placement 规则
- `build/verify_local.sh` 与 focused smoke 必须继续全绿，证明这次是 ownership convergence，
  不是 surface drift

### Status

Completed

### Completed Steps

- [x] 先在 `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
      写出 shared workspace model 的 RED contract，覆盖 explicit workspace、
      nearest package manifest 与 workspace member 三条代表路径
- [x] 新增 `compiler/frontend/np_workspace_model.pas`，最小落地
      `WorkspaceModel` / `PackageRef` / `TargetSelection` / `ArtifactRootSet`
- [x] 让 `np_package_manifest.pas` 提供 workspace model 所需的 typed inputs，
      保留 parser 职责但不再承担最终 ownership
- [x] 让 `TCompilationSession` 正式拥有 workspace model，并让 session getters /
      resolver roots 从 model 读取，而不是从 driver 拼装字段读取
- [x] 把 `tools/stage0/nextpas.pas` 的 workspace/package/artifact discovery
      切到 shared model，保持 line/envelope/early-failure 契约不变
- [x] 运行 fresh `bash build/verify_local.sh`，并同步回写文档、路线图与持续记录

## Addendum: 2026-04-05 Toolchain Plan Runner Execution Contract

### Goal

把 `Batch 16` / `Batch 17` 已冻结的 typed `TToolchainPlan` 从“可投影对象”推进到
“可真实执行 contract”，但继续守住当前 backend truth 的边界：

- 新增通用 runner，按 step 顺序真实执行 ready `TToolchainPlan`
- runner 必须负责当前已落地的 sidecar kinds：
  `response-file`、`resource-list-script`、`archive-command-script`
- `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`
  必须真实执行 fake `as` + `ld` 的 `native-assemble-link` plan，
  验证 object/output 生成、response capture 与 `delete-on-success` cleanup
- 仍不把 `stage0 build` 伪装成已经切到 native assembler/linker production path；
  `compiler/backend/np_backend_plan.pas` 还没有正式拥有 assembly/object
  intermediate artifact truth

### Status

Completed

### Completed Steps

- [x] 审查 `compiler/backend/np_backend_plan.pas`、
      `compiler/toolchain/np_toolchain_plan.pas` 与
      `tests/toolchain/toolchain_contract_smoke.pas`，确认当前最小真实推进点是
      generic runner，而不是强行让 `PlanFromBackend` 改选 `native-assemble-link`
- [x] 新增 `compiler/toolchain/np_toolchain_runner.pas`，提供
      `ExecuteToolchainPlan(...)` 与 per-step `TToolchainRunResult`
- [x] 在 `compiler/toolchain/np_toolchain_plan.pas` 暴露 `StepAt(...)`，
      让 runner / contract smoke 能读取 typed step truth
- [x] 把 `tests/toolchain/toolchain_contract_smoke.pas` 与
      `build/verify_local.sh` 扩成 fake `as` / `ld` 的真实 multi-step execution gate，
      覆盖 response sidecar materialize、capture 与 delete-on-success cleanup
- [x] 运行 fresh `bash build/verify_local.sh`，确认 `native-run-*` contract、
      `toolchainContractCheck=pass` 与整套 `verify-local=pass`

## Addendum: 2026-04-05 Host-compiler Runner Reuse + Tool Run Projection

### Goal

把刚落地的 generic `TToolchainPlan` runner 真正接回当前 one-step host-compiler
production path，避免 `stage0 build` 继续维护第二套手写 `TProcess` 执行路径：

- `tools/stage0/nextpas.pas` 不再手工 `ResolveCompilerExecutable + TProcess`
- 当前 host-compiler production path 必须复用 `compiler/toolchain/np_toolchain_runner.pas`
- session / CLI / envelope 需要显式投影真实 execution result：
  `tool-run-status`、`tool-run-step-count`、`primary-tool-run-status`
- fresh `bash build/verify_local.sh` 必须继续全绿，证明 runner reuse 没有破坏现有
  tool invocation plan、status event、build trace 与 failure diagnostic contract

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 为 `stage0-smoke`、`semantic-smoke` 与
      `toolchain-failure` 写出 `tool-run-*` RED gate，并 fresh 运行确认失败点正好落在
      新增 execution-result fields 缺失
- [x] 在 `compiler/frontend/np_compilation_session.pas` 增加 generic runner 执行入口，
      让 session 正式拥有 `tool run` status / step count / primary-step status
- [x] 把 `tools/stage0/nextpas.pas` 的 host-compiler production path 切到
      `Session.ExecuteToolchain(...)`，去掉 hand-written execute path 与 duplicated state update
- [x] 把 `tool-run-status`、`tool-run-step-count`、`primary-tool-run-status`
      接进 line-based projection 与 `command-envelope=<json>.result`
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/toolchain-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md` 与持续记录文件
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 `tool-run-*` contract 与
      整套 `verify-local=pass`

## Addendum: 2026-04-05 Backend Intermediate Artifact Truth + Logical Object Input

### Goal

把 backend 对 artifact truth 的 ownership 从“只有 final executable”推进到
`assembly-text/object-file/executable` 三类正式 artifacts，同时继续保持当前 production path
仍是 host-compiler single-step execution：

- `compiler/backend/np_backend_plan.pas` 必须正式拥有 target-aware `.s/.o/<program>`
  artifact truth，并把 `.s/.o` 收口到 `<artifact-root>/cache/backend/<target>/`
- `compiler/frontend/np_compilation_session.pas` 与 `tools/stage0/nextpas.pas`
  必须把这份 truth 投影成 `backend-artifact-count`、`backend-artifacts` 与 camelCase
  `backendArtifactCount`、`backendArtifacts`
- `compiler/toolchain/np_toolchain_plan.pas` 的 `logical-link-request.objectInputs`
  必须开始消费 backend-owned `object-file` artifact
- `PlanFromBackend` 仍不提前切到 `native-assemble-link`；下一批才处理合法 production-path
  selection

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 为 `backend-artifact-count`、`backend-artifacts`、
      `logical-link-request.objectInputs` 与 camelCase envelope fields 写出 RED gate，
      并 fresh 运行确认失败点落在新 truth 缺失
- [x] 扩展 `compiler/backend/np_backend_plan.pas`，让 backend plan 固定持有
      `assembly-text`、`object-file` 与 `executable` 三类 artifacts，并补齐 helper /
      backend cache root 计算
- [x] 扩展 `compiler/frontend/np_compilation_session.pas` 与
      `tools/stage0/nextpas.pas`，把 backend artifact count / artifact JSON 接进 session、
      line-based projection 与 `command-envelope=<json>.result`
- [x] 扩展 `compiler/toolchain/np_toolchain_plan.pas`，让
      `logical-link-request.objectInputs` 开始引用 backend-owned `.o`
- [x] 同步回写架构规范、路线图与持续记录，并重新运行 fresh
      `bash build/verify_local.sh`，确认整套 `verify-local=pass`

## Addendum: 2026-04-05 Bootstrap-native Assemble/Link Production Path

### Goal

把已经落地的 backend-owned `assembly-text/object-file/executable` truth 真正接进当前
production path，让 `PlanFromBackend` 不再停留在 single-step host-compiler execution：

- `compiler/toolchain/np_toolchain_plan.pas` 必须合法选择
  `bootstrap-native-assemble-link`
- 当前真实执行面必须改成
  `host-fpc-emit-asm -> native-assemble -> native-link`
- 根程序与 source-backed units 的 `.s`、backend-owned `.o` 和确定性的
  `<program>_link.res` 必须进入 backend cache 并被真实消费
- `build/verify_local.sh`、README、架构规范、路线图与持续记录必须全部同步到这条新 reality
- 当批次结束时仍要诚实标注残余风险：later-step failure attribution 当时还是
  primary-step-centric（已在 2026-04-06 addendum 收口）

### Status

Completed

### Completed Steps

- [x] 先在 `compiler/toolchain/np_toolchain_plan.pas` 审核当前 backend artifact / profile /
      runner 前提，确认最小安全切换点已经具备，不再需要继续停在
      `host-compiler` single-step selection
- [x] 扩展 `compiler/toolchain/np_toolchain_plan.pas`，让 `PlanFromBackend` 直接选择
      `PlanBootstrapNativeAssembleLink(...)`，并真实生成
      `host-fpc-emit-asm`、`native-assemble`、`native-link`
- [x] 扩展 `compiler/frontend/np_compilation_session.pas`，收集 source-backed units 的额外
      assembly base names，使 explicit unit root / 多文件场景能够继续追加
      `native-assemble-<unit>` steps
- [x] 扩展 `build/verify_local.sh`，把
      `toolchain-plan-family=bootstrap-native-assemble-link`、
      `tool-invocation-count=3`、`tool-run-step-count=3`、
      `primary-tool-step-id=host-fpc-emit-asm`、
      `build-trace-ref=...-host-fpc-emit-asm` 与 extra native-assemble step contract
      纳入 promotion path
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/toolchain-specification.md`、
      `docs/architecture/diagnostics-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `verify-local=pass` 与 `human-summary=local verification passed`

## Addendum: 2026-04-06 Later-step Failure Attribution for bootstrap-native assemble/link

### Goal

把当前 `bootstrap-native-assemble-link` production path 的 later-step failure attribution
从“真实执行但仍锚定 primary step”推进到“失败 metadata 跟随真实失败 step”：

- `native-assemble` / `native-link` failure 必须分别投影
  `toolchain.assembler-exec-failed` / `toolchain.linker-exec-failed`
- `compiler/frontend/np_compilation_session.pas` 必须把 failure diagnostic、build trace、
  status event 与 `buildTraceRef` 对齐到真实失败 step，而不是继续锚定
  `host-fpc-emit-asm`
- `tools/stage0/nextpas.pas` 必须优先使用 session 产出的真实 diagnostic code，
  不能再把 later-step failure 回退成 primary-tool failure mapping
- `build/verify_local.sh` 必须新增 fake `as` / `ld` 负路径 gate，并在 success envelope
  暴露 `assemblerFailureAttributionCheck` / `linkerFailureAttributionCheck`
- 文档与持续记录必须同步成当前 reality，并诚实注明这批收口时留下的
  success-path transcript gap；该缺口已在紧随其后的 transcript addendum 收口

### Status

Completed

### Completed Steps

- [x] 先在 `build/verify_local.sh` 写出 fake `as` / `ld` 的 RED gate，确认 later-step failure
      还没有按真实 step 归位
- [x] 扩展 `compiler/toolchain/np_toolchain_plan.pas`，让 invocation steps 显式持有
      `toolRole/profileId/sysrootRef`，并为 `native-assemble` / `native-link` 写入 step context
- [x] 扩展 `compiler/frontend/np_compilation_session.pas`，让 tool status event、diagnostic、
      build trace 与 `buildTraceRef` 在 failure path 上跟随真实失败 step
- [x] 扩展 `tools/stage0/nextpas.pas`，让 runner failure 优先使用 `Session.LastDiagnosticCode`
      作为公开 failure kind
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/toolchain-specification.md`、
      `docs/architecture/diagnostics-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `assembler-failure-attribution-check=pass`、
      `linker-failure-attribution-check=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-06 Stage0 Test Command Thin Wrapper

### Goal

把 developer tooling 里最容易失真的 `nextpas test` 入口收成最小真实公开面，但继续保持
`tests/run_all_tests.sh` / `tests/harness/runner.pas` 为 execution owner：

- `tools/stage0/nextpas.pas` 必须新增最小 `test` family，至少支持
  `nextpas test --list-groups [--workspace <root>]` 与
  `nextpas test --filter <group> [--workspace <root>]`
- `stage0` 只负责参数解析、workspace root 选择与 thin wrapper；不重写 harness 分组、
  snapshot policy、fixture execution 或 bootstrap diagnostics
- `stage0` 调起 harness 时必须显式传入
  `NEXTPAS_STAGE0`、`NEXTPAS_WORKSPACE_ROOT`、`NEXTPAS_REPO_ROOT`
- `build/verify_local.sh` 必须新增 `nextpas test` 的
  `list-groups`、`invalid-arguments`、`unknown-group`、`compiler-pass`、`smoke`
  五条 contract
- 文档与持续记录必须同步成当前 reality，并明确这批故意不提前把
  `doctor` / `env` / `query` 拉进来

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas`、`tests/run_all_tests.sh` 与
      `tests/harness/runner.pas`，确认这批最小真实推进点是 stage0 thin wrapper，而不是
      再发明一套 driver-owned test runner
- [x] 扩展 `tools/stage0/nextpas.pas`，新增 `test` command parse/usage，
      支持 `--list-groups`、`--filter <group>` 与可选 `--workspace <root>`，并把
      driver-side test parse failure 映射成 `selector=test`
- [x] 在 `tools/stage0/nextpas.pas` 中通过 `/usr/bin/env` thin-wrap
      `tests/run_all_tests.sh`，显式传入 `NEXTPAS_STAGE0`、
      `NEXTPAS_WORKSPACE_ROOT` 与 `NEXTPAS_REPO_ROOT`
- [x] 扩展 `build/verify_local.sh`，把 `nextpas test` 的 list-groups、
      invalid-arguments、unknown-group、compiler-pass 与 smoke contract
      纳入正式 gate
- [x] 同步回写 `tools/stage0/README.md`、
      `tools/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/developer-tooling-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认新增 `nextpas test` gate 与
      整套 `verify-local=pass`

## Addendum: 2026-04-06 Success-path Toolchain Observability Transcript Hardening

### Goal

把当前 `bootstrap-native-assemble-link` production path 的 success-path observability
从“仍有单步摘要残留”推进到“success/failure 都暴露完整 executed-step
transcript”：

- `compiler/toolchain/np_toolchain_runner.pas` 必须把 executed sidecar truth 收进正式
  transcript，至少暴露 `materialized` 与 `cleanupStatus`
- `compiler/frontend/np_compilation_session.pas` 必须让 success/failure 两侧都按全部
  executed steps 投影 `tool-status-events` 与 `buildTrace.steps[*]`
- `buildTraceRef` 必须统一升级成 plan-level
  `trace-<session-id>-toolchain-plan`，而不是继续随某个 step 变化
- `build/verify_local.sh` 必须冻结 success-path `tool-status-event-count=10`、
  later-step failure 的 plan-level trace ref，以及 `native-run-transcript` 的
  sidecar cleanup truth
- 文档与持续记录必须同步成当前 reality，把“success path 仍是单步摘要”的旧说法
  全部清掉

### Status

Completed

### Completed Steps

- [x] 扩展 `compiler/toolchain/np_toolchain_runner.pas`，把 executed sidecar truth 收进
      `TToolchainExecutedStep`
- [x] 扩展 `compiler/frontend/np_compilation_session.pas`，让 success/failure 两侧都按全部
      executed steps 投影 `tool-status-events` / `buildTrace.steps[*]`，并把
      `buildTraceRef` 升级成 plan-level locator
- [x] 扩展 `tests/toolchain/toolchain_contract_smoke.pas`，新增
      `native-run-transcript=<json>` 输出，冻结 sidecar execution truth
- [x] 扩展 `build/verify_local.sh`，把 success-path transcript、plan-level trace ref、
      later-step failure transcript 与 `native-run-transcript` sidecar cleanup truth
      纳入 promotion path
- [x] 同步回写 `tools/stage0/README.md`、
      `docs/architecture/stage0-driver-specification.md`、
      `docs/architecture/toolchain-specification.md`、
      `docs/architecture/diagnostics-specification.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`、
      `task_plan.md`、`findings.md` 与 `progress.md`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`toolchainFailureCheck=pass`、
      `assemblerFailureAttributionCheck=pass`、`linkerFailureAttributionCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-02 Stage0 Projection Clear/Capture Helper Convergence

### Goal

继续把 `tools/stage0/nextpas.pas` 的内部 projection ownership 收紧，但仍不改公开
line-based output / `command-envelope=<json>` 契约：

- `ClearSessionContext(...)` 不应继续直接维护一整段跨多个 projection record 的字段清理逻辑
- `CaptureSessionContext(...)` 不应继续直接维护一整段跨多个 projection record 的字段复制逻辑
- `ClearBuildCommandContext(...)` / `CaptureBuildCommandContext(...)` 也应对齐到同样的 helper
  形状，避免 clear/capture 路径继续半收口半内联
- fresh `verify_local` 必须继续全绿，证明这次只是 clear/capture helper convergence，
  不是行为或契约漂移

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas` 中 `ClearBuildCommandContext(...)`、
      `ClearSessionContext(...)`、`CaptureBuildCommandContext(...)`、
      `CaptureSessionContext(...)` 的剩余大块字段搬运，确认最小安全边界是按现有
      build/session/diagnostics/syntax/resolution/semantic/mir/backend/toolchain record
      抽 helper，而不是改输出 surface
- [x] 新增按 record 分组的 clear helper 与 capture helper，并让上述四个入口统一调 helper，
      保持字段来源、更新时机和 pre-session/session-owned 边界不变
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Build=pass`、`stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`smokeCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-02 Stage0 Projection Helper Convergence

### Goal

继续把 `tools/stage0/nextpas.pas` 的内部 projection 实现收紧，但仍不改公开
line-based output / `command-envelope=<json>` 契约：

- `BuildCommandEnvelopeJson(...)` 不应继续内联维护一整段分组字段拼接逻辑
- `PrintSessionProjection(...)` 不应继续内联维护按 group 展开的 line-based projection 细节
- fresh `verify_local` 必须继续全绿，证明这次只是 helper convergence，不是字段顺序、
  启停条件或 pre-session/session-owned 边界漂移

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas` 中 `BuildCommandEnvelopeJson(...)` /
      `PrintSessionProjection(...)` 的剩余内联 projection 逻辑，确认最小安全边界是抽出
      JSON helper 与 print helper，而不是继续改公开字段
- [x] 新增按 build/session/syntax/resolution/semantic/mir/backend/toolchain 分组的 JSON helper，
      并新增 session identity / diagnostics / syntax / resolution / semantic / MIR /
      backend / toolchain / diagnostics detail / build trace / lifecycle 的 print helper，
      再把 `BuildCommandEnvelopeJson(...)` 与 `PrintSessionProjection(...)` 改成统一调 helper
- [x] 核对 helper 化后的字段顺序与启停条件，特别确认
      `diagnosticCount` / `diagnosticErrorCount` / `diagnosticWarningCount` /
      `diagnosticsPolicy` 仍位于 `sessionLifetime` / `unitLifetime` / `stageLifetime` 之前
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Build=pass`、`stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`smokeCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-02 Stage0 Projection Owner Context Convergence

### Goal

继续把 `tools/stage0/nextpas.pas` 的内部 projection state 收口到一致的 owned shape，
但仍不改公开 line-based output / `command-envelope=<json>` 契约：

- 剩余的 `ActiveSession*`、`ActiveSyntax*`、`ActiveResolution*`、
  `ActiveSemantic*`、`ActiveMir*`、`ActiveBackend*` 不应继续散落成平铺全局
- `BuildCommandEnvelopeJson(...)`、`ClearSessionContext(...)`、
  `CaptureSessionContext(...)`、`PrintSessionProjection(...)` 应统一走分组 record
- fresh `verify_local` 必须继续全绿，证明这次只是 owner-context convergence，
  不是 surface 变化

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas` 中剩余 session/syntax/resolution/semantic/mir/backend
      平铺 `Active*` 状态，确认最小安全边界是按 projection 分组收口，而不是再改输出 helper
- [x] 引入 `TSessionProjectionContext`、`TSyntaxProjectionContext`、
      `TResolutionProjectionContext`、`TSemanticProjectionContext`、
      `TMirProjectionContext`、`TBackendProjectionContext`，并同步替换
      `BuildCommandEnvelopeJson(...)`、`ClearSessionContext(...)`、
      `CaptureSessionContext(...)`、`PrintSessionProjection(...)` 的消费点
- [x] 用搜索确认 `tools/stage0/nextpas.pas` 中已不再残留这批旧
      `ActiveSession*` / `ActiveSyntax*` / `ActiveResolution*` /
      `ActiveSemantic*` / `ActiveMir*` / `ActiveBackend*` 平铺字段
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Build=pass`、`stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`smokeCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-02 Convergence-first Verification Hygiene + Build-context Compaction

### Goal

把当前 rolling window 的优先级继续收回到“已落地路径的收敛质量”，而不是继续向外扩 richer
toolchain 表面：

- `verify_local` 不能再让 toolchain contract smoke 的二进制 / `.o` 落回源码树
- `harness` bootstrap failure 不能再吞掉关键回放线索
- `stage0` / `CompilationSession` 共享的 build truth 要继续从散落字段收口到更小的 owned shape
- 文档、路线图和持续记录必须同步这条 convergence-first 取向

### Status

Completed

### Completed Steps

- [x] 把 `build/verify_local.sh` 的 toolchain contract smoke 改成编译到临时 `mktemp -d`
      build dir，并显式断言源码树里不存在
      `tests/toolchain/toolchain_contract_smoke` 与
      `tests/toolchain/toolchain_contract_smoke.o`
- [x] 让 `tests/run_all_tests.sh` 在 stage0 bootstrap failure 时稳定投影
      `bootstrap-step`、`bootstrap-command`、`bootstrap-stderr-file`，并在 stderr 文件存在内容时回显原始 evidence
- [x] 在 `tools/stage0/nextpas.pas` 用 `TBuildCommandContext` 收拢 command-level build truth，
      并在 `compiler/frontend/np_compilation_session.pas` 用 `TBuildContext` 收拢 session-owned build context
- [x] 回写 `build/README.md`、`tests/harness/README.md`、
      `docs/architecture/test-harness-specification.md`、
      `docs/architecture/stage0-driver-specification.md`、`tools/stage0/README.md`、
      `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md` 与持续记录文件
- [x] 运行 fresh `bash build/verify_local.sh`，确认
      `toolchainContractCheck=pass`、`harnessBootstrapDiagnosticsCheck=pass` 与整套
      `verify-local` 继续全绿

## Addendum: 2026-04-02 Stage0 Projection Context Compaction Closure

### Goal

把上一轮已经开始的 `stage0` 内部状态收口继续做完，但只限于实现内部，不改公开
line-based output / `command-envelope=<json>` 契约：

- `tools/stage0/nextpas.pas` 不应再在 projection record 已落地后，继续混用残留的
  `ActiveDiagnostic*` / `ActiveToolchain*` 平铺全局
- `PrintSessionProjection(...)` 必须和 `BuildCommandEnvelopeJson(...)`、
  `ClearSessionContext(...)`、`CaptureSessionContext(...)` 一样，统一走 owned context
- fresh `verify_local` 必须继续全绿，证明这次只是内部 compaction，不是行为漂移

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas` 中 diagnostics/toolchain projection 的剩余旧引用，
      确认遗留点集中在 `PrintSessionProjection(...)`
- [x] 把 stdout/stderr session projection 中残留的旧平铺字段访问全部改为
      `ActiveDiagnosticsProjection` / `ActiveToolchainProjection`
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Build=pass`、`stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`smokeCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-04-02 Stage0 Projection Writer Convergence

### Goal

继续收紧 `tools/stage0/nextpas.pas` 的内部实现形状，但仍不改公开 CLI / envelope 契约：

- `PrintBuildContextProjection(...)` 与 `PrintSessionProjection(...)` 不应继续维护
  stdout/stderr 两套大段镜像逻辑
- projection 输出路径应收敛到一组统一 helper，降低后续继续 compaction 时的漏改风险
- fresh `verify_local` 必须继续全绿，证明只是 writer convergence，不是 surface 变化

### Status

Completed

### Completed Steps

- [x] 审查 `tools/stage0/nextpas.pas` 中 build/session projection 的 stdout/stderr
      双分支重复，确认最小安全边界只需要收敛 writer helper，不需要改字段本身
- [x] 引入统一 projection writer helper，并把
      `PrintBuildContextProjection(...)` / `PrintSessionProjection(...)`
      改成单一路径输出，保持字段名、顺序和条件不变
- [x] 重新运行 fresh `bash build/verify_local.sh`，确认
      `stage0Build=pass`、`stage0Smoke=pass`、`semanticSmokeCheck=pass`、
      `toolchainContractCheck=pass`、`smokeCheck=pass` 与
      `verify-local=pass`

## Addendum: 2026-03-27 Toolchain Contract Hardening + Roadmap Review

### Goal

把上一轮审查里价值最高、且已经能在当前仓库落地的几项建议直接收口成代码和文档：

- 让 `session-id`、`tool-invocation-plan-ref`、`build-trace-ref` 改成每次 build 唯一
- 给 diagnostics sink 补上最小 warning / warning-as-error contract
- 给 unit resolver 补上可复用的 root index，避免重复全量重扫 search roots
- 回写路线图与实现计划，把近期优先级从“继续堆 toolchain projection”调回
  semantic/workspace truth

### Status

Completed

### Completed Steps

- [x] 先把 `build/verify_local.sh` 和 `tests/toolchain/toolchain_contract_smoke.pas`
      扩成会先对唯一 locator、warning contract 和 resolver index 提出 RED
- [x] 在 `np_compilation_session.pas` 里把 build session locator 改成带 timestamp + nonce 的唯一值
- [x] 在 `np_diagnostics_sink.pas` 里补齐 `EmitWarning`、`WarningCount`、
      `SetWarningAsError`
- [x] 在 `np_unit_resolver.pas` 里补齐最小 per-root search index，并暴露 index status /
      indexed root count / scan count contract
- [x] 回写 `master-roadmap.md`、`stage0-driver-specification.md`、
      `toolchain-specification.md`、`diagnostics-specification.md`、
      `tools/stage0/README.md` 与 master roadmap plan
- [x] 运行 fresh `./build/verify_local.sh`，确认整套 verify-local 继续全绿

## Addendum: 2026-03-27 Diagnostics Accounting + Search-index Projection Sync

### Goal

把上一轮已经落地的两条最小 contract 写成正式、持续一致的仓库 truth：

- diagnostics 不再只写 total count，而要明确 split error/warning accounting
- resolver search index 不再只留在 resolver 内部，而要作为 session-owned projection
  被公开说明
- 路线图与持续记录要明确这条 search index 仍然是 lazy contract，而不是假装“总该 ready”

### Status

Completed

### Completed Steps

- [x] 回看 `np_diagnostics_sink.pas`、`np_compilation_session.pas`、
      `np_unit_resolver.pas`、`tools/stage0/nextpas.pas`、
      `tests/toolchain/toolchain_contract_smoke.pas` 与 `build/verify_local.sh`，
      确认真实 contract 已经在代码和 verify path 中生效
- [x] 回写 `compiler-specification.md`，把 diagnostics split accounting 与
      search-index projection 写成 compiler-owned truth
- [x] 回写 `diagnostics-specification.md`，把 `ErrorCount` / `WarningCount` /
      warning-as-error promotion contract 写清楚
- [x] 回写 `unit-resolution-specification.md`，把 per-root lazy search index 与
      `deferred -> ready` 投影行为写清楚
- [x] 回写 `task_plan.md`、`findings.md` 与 `progress.md`，同步这轮已验证结论
- [x] 重新运行 fresh `./build/verify_local.sh`，确认 docs/planning sync 之后整套 verify-local 继续全绿

## Addendum: 2026-03-27 Partial Search-index Contract Hardening

### Goal

把 resolver search-index 的第三种真实状态 `partial` 正式冻结进 promotion path，避免后续
precedence 路径悄悄退化成 eager 全扫描或丢失 scan accounting。

### Status

Completed

### Completed Steps

- [x] 用 focused probe 确认 `explicit_unit_root`、`package_manifest_source_precedence`、
      `root_source_precedence`、`unit_root_precedence` 四类成功路径都会稳定投影
      `search-index-status=partial`
- [x] 在 `build/verify_local.sh` 为上述 representative precedence 路径补齐
      line-based 与 envelope 两层 `searchIndexStatus` / `indexedSearchRootCount` /
      `searchIndexScanCount` 断言
- [x] 回写 `unit-resolution-specification.md` 与 `tools/stage0/README.md`，
      说明 `partial` 表示“高优先级 root 提前命中后，低优先级 tiers 未被继续扫描”
- [x] 回写 `task_plan.md`、`findings.md` 与 `progress.md`，记录这次 verify hardening
- [x] 重新运行 fresh `./build/verify_local.sh`，确认新增 partial-state gate 后整套 verify-local 继续全绿

## Current Phase

Completed

## Phases

### Phase 1: Review Report Against Codebase Reality

- [x] 逐条对照外部审查报告与当前代码
- [x] 确认优先级切到 `P0` 验证失真，再到 `P1` resolver correctness
- [x] 锁定当前最小收口范围：
      harness truthfulness、resolver correctness、docs sync、repo hygiene、fresh verification
- **Status:** completed

### Phase 2: Harness Truthfulness

- [x] 修正 `tests/harness/runner.pas`，让 fixture 收集只接收符合 group 契约的 `.pas`
- [x] 让 `compiler-pass`、`compiler-fail`、`diagnostics`、`rtl`、`crt`、`regression`
      都走真实执行路径，而不是只统计 fixture / snapshot
- [x] 为 group 与 smoke 补齐真实执行投影：
      `fixture-result`、`executed-fixture-count`、`passed-fixture-count`、
      `failed-fixture-count`、`smoke-group ... executed=<n>`
- [x] 让 snapshot-bearing groups 比较 canonical actual text，并在 mismatch / missing 时写出
      diff evidence
- [x] 把 runner bootstrap 产物从源码树移到 `.sisyphus/tmp/harness/bootstrap/runner`
- **Status:** completed

### Phase 3: Resolver Correctness

- [x] 修正 `ResolveRoot(...)`，让根单元也解析 `implementation uses`
- [x] 修正 `ResolveDependency(...)`，要求 requested unit name 与文件内部声明名一致
- [x] 新增 `resolver.unit-name-mismatch` failure baseline 与对应 fixture/snapshot
- [x] 修正 synthetic `System` 行为：
      implicit runtime placeholder 可以存在，但显式 `uses System` 仍必须尝试加载真实源码
- [x] 让 `TUnitGraph.AddResolvedUnit(...)` 支持从 placeholder 升级为真实 source-backed unit
- **Status:** completed

### Phase 4: Docs, Hygiene, and Planning Sync

- [x] 更新 `.gitignore`，把 `.sisyphus/`、FPC 生成物、runner/bootstrap 产物、snapshot
      diff evidence 和当前已知 smoke/example 产物统一排除
- [x] 清理源码树里的历史 runner/fixture 生成物与过期 diff
- [x] 更新 `tests/harness/README.md`、`tests/README.md`
- [x] 更新 `test-harness-specification.md` 与 `unit-resolution-specification.md`
- [x] 更新 `task_plan.md`、`findings.md` 与 `progress.md`
- **Status:** completed

### Phase 5: Fresh Verification

- [x] 运行 fresh `./tests/run_all_tests.sh --filter smoke`
- [x] 运行 fresh `./build/verify_local.sh`
- [x] 记录当前收口结论时，明确区分“真实 resolution / harness gate”与“仍 host-backed 的外层编译路径”
- **Status:** completed

### Phase 6: Workspace Discovery Truth Projection

- [x] 为 `build/verify_local.sh` 补齐 workspace/artifact discovery projection gate：
      `workspace-root`、`workspace-discovery-kind`、`workspace-descriptor-path`、
      `package-manifest-path`、`artifact-root`、`output-dir`，以及 envelope 对应 camelCase 字段
- [x] 为 `TCompilationOptions` / `TCompilationSession` 补齐最小 discovery metadata owned fields
- [x] 让 `tools/stage0/nextpas.pas` 复用现有 nearest workspace/package helper，
      把当前真实 workspace/package/artifact 事实投影到 line-based output 与
      `command-envelope=<json>`
- [x] 运行 fresh `bash build/verify_local.sh`，确认 stage0 smoke、
      package manifest fixture 与 workspace member fixture 全部转绿
- **Status:** completed

### Phase 7: Pre-session Build Context Projection

- [x] 为 `build/verify_local.sh` 的 `invalid-unit-root-check` 补齐 early failure gate：
      line-based output 至少要保留 `workspace-root`、`workspace-discovery-kind`、
      `artifact-root`、`output-dir`，而 envelope 继续带上
      `failureKind`、`source`、`target`、`workspaceRoot`、`workspaceDiscoveryKind`、
      `artifactRoot`、`outputDir`
- [x] 在 `tools/stage0/nextpas.pas` 里把 source/target/workspace/artifact/output
      这批 command-level truth 提前 capture 到 `Active...` context，
      不再等 session 创建后才可见
- [x] 让 `PrintSessionProjection(...)` 先打印 build context，再只在有 `session-id`
      时继续打印 session-owned fields，避免伪造 pseudo-session
- [x] 运行 fresh `bash build/verify_local.sh`，确认 `invalid-unit-root` 这类
      pre-session failure 也能稳定投影已知 build context，且 verify-local 全绿
- **Status:** completed

### Phase 8: Pre-session Failure Gate Expansion

- [x] 先做 focused probe，确认 `invalid-out-dir` 与 `invalid-artifact-root`
      当前已经真实复用同一条 pre-session build-context projection，
      不需要再改 `tools/stage0/nextpas.pas`
- [x] 为 `build/verify_local.sh` 增加 `invalid-out-dir-check`，冻结
      `workspace-root`、`workspace-discovery-kind`、`artifact-root`、`output-dir`
      及 envelope 对应 camelCase 字段
- [x] 为 `build/verify_local.sh` 增加 `invalid-artifact-root-check`，冻结同一批
      pre-session build context fields
- [x] 运行 fresh `bash build/verify_local.sh`，确认新增 gate 全绿，
      且 `invalid-unit-root` / `invalid-out-dir` / `invalid-artifact-root`
      三条 early failure baseline 同时受保护
- **Status:** completed

### Phase 9: Source-directory-fallback Verify Coverage

- [x] 先做 focused probe，确认不传 `--workspace`、且 source 周围没有 workspace/package marker 时，
      当前真实行为已经是 `workspace-discovery-kind=source-directory-fallback`
- [x] 为 `build/verify_local.sh` 增加 `source-directory-fallback-check`，冻结
      `workspace-root`、`workspace-discovery-kind=source-directory-fallback`、
      `artifact-root`、`output-dir`、artifact 默认落点、tool plan argv 与 envelope 对应字段
- [x] 额外断言这条路径不会投影 `workspace-descriptor-path` / `package-manifest-path`
- [x] 同步补齐 `verify-local` success envelope，把
      `sourceDirectoryFallbackCheck`、`invalidOutDirCheck`、`invalidArtifactRootCheck`
      正式写进结构化结果
- [x] 运行 fresh `bash build/verify_local.sh`，确认新增 gate 与整套 verify-local 全绿
- **Status:** completed

### Phase 10: Verify-local Success Envelope Parity

- [x] 对照 `build/verify_local.sh` 的 `*=pass` gate 集合与最终
      `command-envelope=<json>.result`，确认结构化结果仍缺
      `packageManifestSourceRootCheck`、`workspaceMemberSourceRootCheck`、
      `packageManifestSourcePrecedenceCheck`
- [x] 在 `build/verify_local.sh` 补齐上述三条 success field，保持 verify-local 的
      machine-readable result 与真实 promotion path 同步
- [x] 回写 `task_plan.md`、`findings.md`、`progress.md`，记录这次 envelope parity 修补
- [x] 运行 fresh `bash build/verify_local.sh`，确认 success envelope 扩充后整套 verify-local 继续全绿
- **Status:** completed

### Phase 11: Success-path Envelope Coverage Hardening

- [x] 对 `explicit-unit-root`、`out-dir-override`、`package-manifest-source-precedence`、
      `root-source-precedence`、`unit-root-precedence` 做 focused probe，确认当前真实输出
      已经在 `command-envelope=<json>.result` 中带上 `outputDir`、`artifact`、`searchPathCount`
      与 `searchPaths`
- [x] 在 `build/verify_local.sh` 为上述 gate 补齐最小 machine-readable 断言，
      冻结 success path 的 envelope search-path/output truth，而不改 stage0 实现
- [x] 回写 `task_plan.md`、`findings.md`、`progress.md`，记录这批 verify hardening
- [x] 运行 fresh `bash build/verify_local.sh`，确认新增 envelope 断言后整套 verify-local 继续全绿
- **Status:** completed

### Phase 12: Descriptor/Manifest Presence Contract Hardening

- [x] 对 `stage0-smoke`、`package-manifest-source-root`、
      `package-manifest-source-precedence`、`source-directory-fallback`、
      `invalid-unit-root`、`invalid-out-dir`、`invalid-artifact-root`
      做 focused probe，确认 `workspaceDescriptorPath` / `packageManifestPath`
      当前真实行为是“按需出现、否则省略”，而不是投影成空字段
- [x] 在 `build/verify_local.sh` 为上述代表性路径补齐出现/缺失断言，冻结
      line-based output 与 `command-envelope=<json>.result` 的 presence-vs-absence contract
- [x] 回写 `task_plan.md`、`findings.md`、`progress.md`，记录这批 absence hardening
- [x] 运行 fresh `bash build/verify_local.sh`，确认 descriptor/manifest absence 断言加入后整套 verify-local 继续全绿
- **Status:** completed

### Phase 13: Explicit-workspace Omission Coverage Expansion

- [x] 对 `semantic-smoke`、`explicit-unit-root`、`out-dir-override`、
      `root-source-precedence`、`unit-root-precedence`、`toolchain-failure`
      做 focused probe，确认这些 remaining explicit-workspace 路径也都会稳定省略
      `workspaceDescriptorPath` / `packageManifestPath`
- [x] 在 `build/verify_local.sh` 为上述路径补齐 line/envelope absence 断言，
      把 explicit-workspace omission contract 从“代表性覆盖”扩成“主要路径全覆盖”
- [x] 回写 `task_plan.md`、`findings.md`、`progress.md`，记录这批 omission coverage expansion
- [x] 运行 fresh `bash build/verify_local.sh`，确认新增 absence gate 后整套 verify-local 继续全绿
- **Status:** completed

### Phase 14: Summary Surface Contract Hardening

- [x] 对 `stage0-smoke`、`semantic-smoke`、`syntax-failure`、`missing-unit`、
      `duplicate-import`、`toolchain-failure` 与显式 workspace 的 pre-session failure
      做 focused probe，确认当前真实输出已经稳定携带
      line-based `diagnostics-summary` / `human-summary`，以及 envelope 中的
      `diagnosticsSummary` / `humanSummary`
- [x] 在 `build/verify_local.sh` 为上述代表性 success / sessionful failure /
      pre-session failure 路径补齐 summary-surface 断言，不改 `tools/stage0/nextpas.pas`
- [x] 回写 `task_plan.md`、`findings.md`、`progress.md`，记录这批 summary contract hardening
- [x] 运行 fresh `bash build/verify_local.sh`，确认新增 summary 断言后整套 verify-local 继续全绿
- **Status:** completed

## Decisions Made

| Decision                                                                                          | Rationale                                                                                          |
| ------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | ----------------------------- | --------------------------------------------------------------------- |
| 先修验证失真，再谈更多架构扩张                                                                    | 假绿会污染后续所有判断，先修它才能让路线图有可信地基                                               |
| harness 继续只保留 6 个稳定 group，`smoke` 保持为 cross-group minimal view                        | 保持公开 surface 少而硬，不增加无必要实体                                                          |
| `compiler-fail` / `diagnostics` 统一改成 canonical actual text compare                            | 让 snapshot baseline 对比真正基于执行结果，而不是文件存在性                                        |
| synthetic `System` 只保留为 implicit runtime edge 的 placeholder，不再遮蔽真实 source             | 同时保留 graph 显式性与正确 provenance                                                             |
| 当前文档必须诚实写出 host-backed 边界和 search path 限制                                          | 避免对内排期和对外表述高估现状                                                                     |
| pre-session failure 要投影已知 command truth，但不能伪造 session-owned state                      | 让 early failure 更诚实，同时保持 session ownership 边界                                           |
| 对已存在的 early-failure 行为，优先先补 verify gate，再决定是否需要改实现                         | 保持批次 grounded，避免为“也许存在的问题”过早改结构                                                |
| verify 脚本自己的 success envelope 也必须跟上真实 gate 集合                                       | 避免 shell gate 已扩充，但结构化 verify 结果仍落后                                                 |
| `diagnostics-summary` / `human-summary` 也要被当成共享 command contract，而不是 incidental stdout | 规格已经把它们列为最小结果表面，verify 应同时保护 line/envelope 两层 mirror                        |
| resolver search index 继续保持 lazy，并把 `deferred                                               | partial                                                                                            | ready` 当成真实 session truth | 避免为了看起来“更完整”而引入 eager 扫描副作用，反而模糊真实 ownership |
| precedence success path 上的 `partial` 必须进入 verify gate，而不只停在手工 probe                 | 这能防止 resolver 以后命中高优先级 root 后仍去全扫低优先级 tiers，或者丢掉 indexed/scan accounting |

## Notes

- 工作区不是 Git 仓库。
- 当前 `build/verify_local.sh` 已经把以下 gate 纳入 promotion path：
  `missing-unit-check`、`ambiguous-unit-check`、
  `root-implementation-check`、`requested-name-mismatch-check`、
  `explicit-system-check`、`package-manifest-source-root-check`、
  `workspace-member-source-root-check`、`package-manifest-source-precedence-check`、
  `source-directory-fallback-check`、`invalid-unit-root-check`、`invalid-out-dir-check`、
  `invalid-artifact-root-check`、`harness-compiler-pass-check`、`smoke-check`
- 最小 package/workspace-declared source roots 已真实落地：
  nearest `nextpas.package.toml` 的 `[sources].roots` 与
  `nextpas.workspace.toml` 的 member package source roots 已进入
  `TCompilationOptions` / `TSearchPathSet` / verify path。
- 当前 stage0 CLI / envelope 也已把最小 workspace discovery truth 正式投影出来：
  `workspace-root`、`workspace-discovery-kind`、`workspace-descriptor-path`、
  `package-manifest-path`、`artifact-root`、`output-dir`，以及
  `workspaceRoot`、`workspaceDiscoveryKind`、`workspaceDescriptorPath`、
  `packageManifestPath`、`artifactRoot`、`outputDir`。
- 当前 `invalid-unit-root` 这类在 `TCompilationSession` 创建前就失败的路径，也会继续投影
  已知的 build command context：line-based output 至少保留 `target`、
  `workspace-root`、`workspace-discovery-kind`、`artifact-root`、`output-dir`，
  `command-envelope=<json>.result` 则继续带上 `source`、`target` 与对应 camelCase
  build-context 字段。
- 当前同一类 pre-session build-context projection 也已经被 verify gate 扩到
  `invalid-out-dir` 与 `invalid-artifact-root`，所以 workspace/artifact/output truth
  不再只在一条 `invalid-unit-root` 路径上被保护。
- 当前 `source-directory-fallback` 成功路径也已经有 verify gate：
  不传 `--workspace` 时，workspace root 会退回 source 所在目录，artifact 默认进入
  `<source-dir>/.nextpas/out/<target>/`，并且不会凭空投影
  `workspace-descriptor-path` / `package-manifest-path`。
- 当前 `verify-local` 的 success envelope 也已经和真实 gate 集合对齐：
  `packageManifestSourceRootCheck`、`workspaceMemberSourceRootCheck`、
  `packageManifestSourcePrecedenceCheck` 不再只存在于 shell 输出里，而会进入最终
  `command-envelope=<json>.result`。
- 当前 success path 上与 search precedence / out-dir override 相关的 gate，
  也已经不只冻结 line-based output：`explicit-unit-root`、`out-dir-override`、
  `package-manifest-source-precedence`、`root-source-precedence`、
  `unit-root-precedence` 现在都会额外断言 `command-envelope=<json>.result` 中的
  `outputDir`、`artifact`、`searchPathCount` 与 `searchPaths`。
- 当前 `workspace-descriptor-path` / `package-manifest-path` 的出现边界也已经被 verify
  冻结到“出现与缺失”两个方向：
  `stage0-smoke`、`source-directory-fallback` 与显式 workspace 的 pre-session failure
  不会误投影这两个字段；`package-manifest-source-root` 与
  `package-manifest-source-precedence` 则会继续稳定表现为“只有 manifest，没有 descriptor”。
- 当前 explicit-workspace 主路径上的 omission contract 也已经从代表性 case 扩成主要路径全覆盖：
  `semantic-smoke`、`explicit-unit-root`、`out-dir-override`、
  `root-source-precedence`、`unit-root-precedence` 与 `toolchain-failure`
  也都会显式验证 descriptor/manifest 字段不会误投影。
- 当前 summary surface 也不再只靠实现自觉：
  `stage0-smoke` / `semantic-smoke` 会稳定验证 `diagnostics-summary=none` 与
  `human-summary=build succeeded`，而 representative sessionful failure /
  pre-session failure 也会同时验证 line-based summary 与 envelope
  `diagnosticsSummary` / `humanSummary` mirror。
- 当前 diagnostics accounting 也已经不是只有 total count：
  `diagnostics-error-count`、`diagnostics-warning-count` 与 envelope 对应的
  `diagnosticErrorCount`、`diagnosticWarningCount` 已进入 `stage0-smoke`、
  `semantic-smoke` 与 `toolchain-contract` gate。
- 当前 resolver search index 也已经作为 session-owned truth 进入 verify path：
  `examples/smoke/hello.pas` 会稳定表现为 `search-index-status=deferred`、
  `indexed-search-root-count=0`、`search-index-scan-count=0`；
  `examples/smoke/hello_with_units.pas` 则会稳定表现为
  `search-index-status=ready`、`indexed-search-root-count=2`、
  `search-index-scan-count=2`。
- 当前 `partial` 也已经不再只靠 focused probe 留证：
  `explicit-unit-root`、`package-manifest-source-precedence`、
  `root-source-precedence`、`unit-root-precedence` 现在都会额外断言
  `search-index-status=partial` 与对应 `indexedSearchRootCount` /
  `searchIndexScanCount`，其中 root-source precedence 稳定为 `1/1`，
  explicit/package precedence 代表路径稳定为 `2/2`。
- 这批只补“当前命令级 truth 的稳定投影”，不宣称完整 `WorkspaceModel`、
  richer package/workspace graph 或 target default persistence 已落地。
- `resolver.unit-not-found` 与 `resolver.ambiguous-unit-source` 当前也已经消费
  `TSearchPathSet` 的 typed metadata，在 diagnostic message 中投影
  `scope` / `provenance` / `root`，并在 candidate 场景额外投影 `path`。
- 当前仍未完成的更大项不是这轮收口内容：
  完整 multi-root workspace model、更丰富的 package/workspace provenance 与
  nextPas 完整脱离宿主 FPC 的最终 codegen
