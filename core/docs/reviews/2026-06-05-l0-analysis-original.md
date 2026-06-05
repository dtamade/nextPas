# nextPas Core L0 层深度分析报告

> Historical input report. This file preserves the external analysis that drove
> the 2026-06-06 L0 cleanup work. It is not a current unresolved-issue list:
> several findings below have since been landed or partially closed on `main`.
> Re-run focused source/test checks before treating any item as still open.
>
> 分析日期: 2026-06-05
> 范围: base / errors / platform / mem / atomic / math / simd

---

## 一、总体评估

L0 层整体架构设计水平很高，分层清晰，模块边界明确。但存在 **3 个严重设计缺陷** 和若干中等/低优先级问题。

| 等级 | 数量 | 模块分布 |
|------|------|----------|
| 🔴 严重 | 3 | base(errors)、atomic、math |
| 🟡 中等 | 12 | platform(4)、mem(3)、atomic(2)、math(2)、simd(1) |
| 🔵 低/建议 | 15+ | 各模块 |

---

## 二、🔴 严重问题

### 2.1 双异常根体系冲突（base + errors）

框架存在两套互不相交的异常层次结构：

**体系 A — `nextpas.core.base.pas:39-52`：**
```pascal
ECore = class(Exception);           // 根类
EWow = class(ECore);                // 命名无语义
EArgumentNil = class(ECore);
EEmptyCollection = class(ECore);
ETimeoutError = class(ECore);
EOutOfMemory = class(ECore);
```

**体系 B — `nextpas.core.errors.pas:42-136`：**
```pascal
ENextPasError = class(Exception)    // 另一个根类，带 Category + Inner
ETimeoutError = class(ENextPasError);
EArgumentError = class(ENextPasError);
EIOError = class(ENextPasError);
EOutOfMemoryError = class(ENextPasError);
```

**后果：**
- `ETimeoutError` 在两个体系中同名但不同类型，同时 uses 会编译歧义
- `EOutOfMemory` (base) vs `EOutOfMemoryError` (errors) 语义相同但不可互捕
- collections/memory/bytes 模块用 ECore 体系，net/http/compress 用 ENextPasError 体系
- 上层代码无法用统一 `except on E: ENextPasError do` 捕获所有框架异常

**建议：** 让 `ECore` 继承 `ENextPasError`，或废弃 `ECore` 体系，全部迁移到 `ENextPasError`。

### 2.2 atomic seq_cst load 实现不正确（atomic）

`nextpas.core.atomic.pas:948-951`：
```pascal
{$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
  Result := aObj;
  _compiler_barrier;
```

在 x86 上 seq_cst load 仅用编译器屏障是**不够的**。x86 TSO 保证了 acquire 语义，但 seq_cst 还要求阻止 store-load 重排序，需要硬件 fence（`MFENCE`）或 `LOCK` 前缀操作。

正确做法（同文件 .inc 版本已实现）：
```pascal
Result := InterlockedExchangeAdd(ATarget, 0);  // LOCK 前缀，提供全屏障
```

此外，6 个 64 位 RMW 函数（`atomic_fetch_and_64` / `_or_64` / `_xor_64` / `_max_64` / `_min_64` / `_nand_64`）的非 x86 分支 `case` 缺少 `else` 分支，当 memory order 为 `mo_relaxed`/`mo_consume`/`mo_acquire` 时可能触发 range check error。

### 2.3 math.trig.pas / math.ffi.pas 是死代码（math）

全局搜索确认：**没有任何文件** `uses nextpas.core.math.trig`。该模块（219 行）及其依赖 `math.ffi.pas`（43 行）完全未被使用。

同时 `math.ffi.pas:12` 硬编码 `external 'm'`，在 Windows 上链接会直接失败（Windows 的 C 运行时是 `msvcrt` 或 `ucrtbase`）。

---

## 三、🟡 中等问题

### 3.1 platform — Windows I/O poller 完全未实现

`nextpas.core.platform.io.pas:477-536`：`platform_poller_create` 在 Windows 下直接返回 -1。虽然已导入 IOCP API（`CreateIoCompletionPort`），但未封装。这意味着 async/event loop 在 Windows 上不可用。

### 3.2 platform — Windows 信号处理为纯 stub

`nextpas.core.platform.signal.pas:293-323`：所有 `platform_signal_*` 在 Windows 下返回 -1。至少应封装 `SetConsoleCtrlHandler` 处理 Ctrl+C/Ctrl+Break。

### 3.3 platform — 子进程 FD 关闭硬编码 1024

`nextpas.core.platform.process.pas:223`：
```pascal
for LFd := 3 to 1023 do
```
现代 Linux 默认 fd limit 为 1048576。应使用 `sysconf(_SC_OPEN_MAX)` 或 `close_range`（已在 `linux.modern.pas` 中定义）。

### 3.4 platform — Windows 全部使用 ANSI 路径

所有文件操作使用 `CreateFileA` / `ReadFile` 等 A 后缀函数，对非 ASCII 路径支持不足。`windows.ffi.pas` 已导入 W 版本但封装层未使用。

### 3.5 mem — 双分配器接口体系

存在 `IAllocator`（`mem.intf.pas`）、`IAllocator`（`mem.allocator.base.pas`，继承前者）、`IAlloc`（`mem.alloc.pas`，Rust 风格）三套接口。用户难以理解各自定位。

### 3.6 mem — TArena/TPool 命名冲突

`TArena` 同时存在于 `arena.pas`（record）和 `blockpool.pas`（class）。`TPool` 存在于 `pool.pas`（record）和各 pool 子单元（class）。通过单元限定可区分但不够直观。

### 3.7 mem — TMappedSlabPool 是伪实现

`mapped_slab_pool.pas:646-649`：`FreeBlock` 仅增加计数器不实际释放内存。注释标注为"简化实现"。

### 3.8 atomic — API 表面过于庞大（3468 行）

三层 API 并存：C 风格函数（`atomic_load`）、Pascal 风格封装（`AtomicLoad32`）、类型安全泛型（`TAtomicInt32`）。中间层仅是简单转发，增加维护负担。建议废弃中间层。

### 3.9 atomic — 两套实现未合并

`nextpas.core.atomic.x86_64.inc` 与主 `.pas` 文件存在相同签名的函数，但未被 include。维护两套实现增加不一致风险。

### 3.10 math — 符号冲突

`math.pas`、`math.trig.pas`、`simd.mathutil.pas` 都声明了 `Min/Max(Double, Double): Double`。同时 uses 会产生编译歧义。

### 3.11 math — Ceil 边界溢出

`math.pas:77-83` 对 `|x| > 2^63` 的 Double 调用 `System.Trunc` 时 Int64 溢出未做防护。

### 3.12 simd — 512-bit 对齐受限

`nextpas.core.simd.base.pas:170-172`：FPC `CODEALIGN RECORDMIN` 最大 32 字节，AVX-512 理论需要 64 字节对齐。栈分配的 512-bit 向量可能未对齐。堆分配通过 `SimdAlloc` 可保证。

---

## 四、🔵 低优先级 / 改善建议

### base
- `EWow` 应重命名为 `EInvariantViolation`
- `ZeroMem`/`CopyMem` 缺少 nil 保护（`CompareMem` 有）
- `HashString` 在 Windows `UnicodeString` 模式下只哈希前一半字节
- 契约函数 `Ensure`/`CheckState` 使用 SysUtils 异常而非框架异常
- 缺少 `Nullable<T>`、`Option<T>`、`Result<T,E>` 基础类型

### platform
- Darwin `mach_timebase_info` 初始化无原子保护（data race，但结果相同）
- FreeBSD 缺少 `getrandom`（FreeBSD 12+ 已支持）
- Android FFI 层仅 23 行，过于单薄
- poller 最大事件数硬编码 64，超传静默截断
- 缺少 sendfile/rlimit/umask/cpu affinity/stack size 封装
- `execve` vs `execvp` 在 envp=nil 时行为不一致

### atomic
- 默认无参数 `atomic_load` 在 x86 上为 relaxed（C++ 标准应为 seq_cst）
- AArch64 seq_cst load 使用普通 load + barrier，可能被编译器优化
- 缺少 `AtomicWait`/`AtomicNotify`（C++20）
- 缺少专用 `TAtomicRefCount` 类型

### mem
- `TDefaultAllocator` 初始化使用自旋等待
- `TStackPoolScope.GrowPool` 可能使旧指针悬空
- 无 mmap-backed `IAllocator` 实现
- 无 NUMA 感知
- `mimalloc` 的 `mi_usable_size` 未接入（`HasMemSize := False`）

### math
- 缺少 GCD/LCM/Hypot/Fmod/SmoothStep
- 缺少 Single 精度函数（散落在 `simd.mathutil.pas`）
- `SimdLnF32` 对 `ln(0)` 返回 `-1e30` 而非 `-Inf`
- `Abs(Int32)`/`Abs(Int64)` 未处理 `Low()` 溢出
- FFI 调用 `sin`/`cos` 等有调用约定切换开销

### simd
- NEON 内联汇编默认禁用（需 FPC 3.3.1+）
- RISC-V V 和 LoongArch 为实验性占位
- 缺少 Gather/Scatter 实现
- 缺少 F16（半精度）支持
- 缺少矩阵转置操作
- NEON AArch64 每个函数需 4-6 条 GPR→向量寄存器组装指令（FPC ABI 限制）

---

## 五、修复优先级建议

### P0 — 立即修复
1. **atomic seq_cst load**：改用 `InterlockedExchangeAdd(ATarget, 0)` + 补齐 6 个 `else` 分支
2. **异常体系统一**：让 `ECore` 继承 `ENextPasError`，或标记废弃计划
3. **清理死代码**：`math.trig.pas` 和 `math.ffi.pas` 要么删除要么接入

### P1 — 短期改进
4. **Windows platform**：实现 IOCP poller + `SetConsoleCtrlHandler` + W 路径
5. **FD 上限**：`process.spawn_fds` 改用 `close_range` 或 `sysconf`
6. **mem 接口收敛**：明确 `IAllocator` vs `IAlloc` 的定位，文档化选择指南
7. **math 符号冲突**：合并 `math.pas` 和 `math.trig.pas`，消除重复导出

### P2 — 中期优化
8. atomic API 瘦身（废弃中间层）
9. math 补齐 Single 精度 + GCD/LCM
10. simd 512-bit 对齐文档化 workaround
11. platform 补齐 sendfile/rlimit/环境变量枚举

### P3 — 长期规划
12. NEON 汇编接入（等待 FPC 3.3.1+ 稳定）
13. NUMA 感知分配
14. atomic wait/notify
15. F16 支持
