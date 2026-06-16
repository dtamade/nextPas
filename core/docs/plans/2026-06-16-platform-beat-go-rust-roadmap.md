# Platform 模块「拳打 Go 脚踢 Rust」全面升级路线图

> **For Claude:** 按阶段顺序执行，每阶段完成后提交 git 并与 Codex 复盘。
> 使用 superpowers:subagent-driven-development 进行任务分发。

**Goal:** 将 nextPas platform 模块打造成 Free Pascal 领域最优秀的平台抽象层，在接口设计、性能、正确性、跨平台覆盖上与 Go runtime/Rust std 看齐并超越。

**Architecture:** 分 6 个 Phase 推进：紧急修复→API完整性→跨平台深化→性能优化→基准对照→文档收官。每个 Phase 独立可验证，完成后可合并 main。

**Tech Stack:** FPC 3.3.1, Free Pascal, Linux x86_64/Win64 cross, Wine, 纯 Pascal FFI

---

## 当前基线

| 指标 | 值 |
|------|-----|
| 子模块 | 14 facade + 8 host |
| Public API | ~221 functions |
| 测试程序 | ~85 (.lpr) |
| 测试用例 | ~580+ (T.Run > 0) |
| 内存泄漏 | 0 unfreed (全量 heaptrc) |
| Linux focused-runtime | 14/14 modules ✅ |
| Wine runtime-smoke | 14/14 modules ✅ |
| Win64 real-VM | 14/14 modules ✅ |
| riscv64/aarch64/arm32 compile | ✅ |
| macOS/FreeBSD/Android runtime | ❌ deferred |
| Benchmark | ❌ deferred |

---

## Phase 1: 债务清零 — 紧急修复 + 已知缺陷修复 (2-3天)

### 目标
修复审计发现的 5 个明确缺陷，消除所有编译阻断和测试失败。

### 任务清单

#### Task 1.1: 修复 mmap page_size 硬编码问题
- **文件:** `core/src/nextpas.core.platform.linux.base.pas`, `core/src/nextpas.core.platform.mmap.pas`
- **问题:** `platform_mmap_page_size` 硬编码返回 4096，测试期望调用 `sysconf(_SC_PAGESIZE)`
- **修复:**
  1. 在 `linux.base` 添加 `SC_PAGESIZE = 30` 常量
  2. 在 `mmap.pas` 实现中调用 `sysconf(SC_PAGESIZE)` 替代硬编码
  3. 添加 macOS/FreeBSD 的对应常量
- **验收:** `test_platform_mmap` 11/11 通过

#### Task 1.2: 修复 Windows WaitOnAddress 64位绕过 lazy-load
- **文件:** `core/src/nextpas.core.platform.sync.pas`
- **问题:** `platform_wait_address64` 直接调用 `WaitOnAddress` 而非 lazy-load 函数指针，Wine 下可能失败
- **修复:**
  1. 将 64 位 WaitOnAddress 也改为通过 `_WaitOnAddress` 函数指针调用
  2. 确保 `ResolveWaitAddress` 在 64 位路径上也生效
- **验收:** `test_platform_sync_wine` 在 Wine 下运行正确

#### Task 1.3: 修复 Windows SecureZero 使用 FillChar 替代
- **文件:** `core/src/nextpas.core.platform.memory.pas`, `core/src/nextpas.core.platform.windows.ffi.pas`
- **问题:** `SecureZeroMemory` Windows API 未使用，改用 `FillChar` + barrier
- **修复:**
  1. 在 `windows.ffi` 添加 `SecureZeroMemory` 声明
  2. 在 `memory.pas` Windows 路径调用 `SecureZeroMemory`
  3. 添加 secure_zero 的 Windows 运行时测试
- **验收:** `test_platform_memory` 全通过，secure_zero 测试覆盖 Windows

#### Task 1.4: 修复 Windows RtlGenRandom 废弃问题
- **文件:** `core/src/nextpas.core.platform.random.pas`, `core/src/nextpas.core.platform.windows.ffi.pas`
- **问题:** 使用已废弃的 `RtlGenRandom`，应改用 `BCryptGenRandom`
- **修复:**
  1. 在 `windows.ffi` 添加 `BCryptGenRandom` 声明
  2. 在 `random.pas` Windows 路径改用 `BCryptGenRandom`
  3. 添加 fallback 到 RtlGenRandom（旧系统兼容）
- **验收:** `test_platform_random` 全通过

#### Task 1.5: 修复 platform.fs copy_file 性能
- **文件:** `core/src/nextpas.core.platform.fs.pas`
- **问题:** `platform_fs_copy_file` 使用简单的 read/write 循环 (8KB buffer)，未使用 `sendfile`/`copy_file_range`
- **修复:**
  1. Linux 上优先使用 `copy_file_range` syscall
  2. macOS/FreeBSD 上使用 `fcopyfile`/`sendfile`
  3. 保留 read/write fallback
- **验收:** `test_platform_fs` 全通过

### Phase 1 验收标准
- [ ] 5 个已知缺陷全部修复
- [ ] 所有 85 个测试程序通过
- [ ] 0 unfreed memory blocks
- [ ] make hygiene 通过
- [ ] git diff --check 通过
- [ ] 与 Codex 复盘通过

---

## Phase 2: API 完整性 — 补充缺失的跨平台 API (3-5天)

### 目标
补齐 Go/Rust 标准库中有而 platform 缺失的关键 API，确保接口完整性对标。

### 任务清单

#### Task 2.1: platform.socket — IPv6 支持
- **新增 API:** `platform_socket_create6`, `platform_sockaddr_ipv6`, `platform_resolve_ipv6`
- **对标:** Go `net.Dial("tcp6", ...)`, Rust `SocketAddr::V6`
- **测试:** IPv6 socket create/bind/connect/accept

#### Task 2.2: platform.socket — UDP 完整支持
- **新增 API:** `platform_socket_sendto`, `platform_socket_recvfrom` 已有但需要测试
- **对标:** Go `net.ListenUDP`, Rust `UdpSocket`
- **测试:** UDP send/recv, broadcast, multicast

#### Task 2.3: platform.socket — socket option 完善
- **新增常量:** `SO_REUSEPORT`, `SO_KEEPALIVE`, `TCP_NODELAY`, `SO_LINGER`
- **修复:** `SO_REUSEPORT` 硬编码 15 问题（各平台值不同）
- **测试:** setsockopt/getsockopt 覆盖

#### Task 2.4: platform.time — 高精度计时完善
- **新增 API:** `platform_cpu_timer` (基于 RDTSC/CNTVCT), `platform_monotonic_us`
- **对标:** Go `time.Now()`, Rust `Instant::now()`
- **测试:** 单调性验证，精度验证

#### Task 2.5: platform.files — 文件锁完善
- **新增 API:** `platform_file_lock_shared`, `platform_file_lock_exclusive`, `platform_file_trylock`
- **对标:** Go `syscall.Flock`, Rust `fs2::FileExt::lock_exclusive`
- **测试:** 共享锁/排他锁/非阻塞锁

#### Task 2.6: platform.memory — 大页支持
- **新增 API:** `platform_mmap_huge_page_size`, `platform_aligned_alloc_huge`
- **对标:** Go runtime huge page, Rust `memmap2`
- **测试:** 大页检测和分配

#### Task 2.7: platform.process — 信号处理完善
- **新增 API:** `platform_process_send_signal`, `platform_process_wait_timeout`
- **对标:** Go `os.Signal`, Rust `nix::sys::signal`
- **测试:** SIGTERM/SIGKILL 发送，超时等待

### Phase 2 验收标准
- [ ] 新增 15+ API
- [ ] 新增 30+ 测试用例
- [ ] 0 unfreed memory blocks
- [ ] 所有新增 API 有对应测试

---

## Phase 3: 跨平台深化 — macOS/FreeBSD/Android Runtime (5-7天)

### 目标
将 macOS、FreeBSD、Android 从 "source-contract/compile-only" 提升到 "focused-runtime"。

### 任务清单

#### Task 3.1: macOS runtime 验证
- 在 macOS CI 环境运行所有 14 模块测试
- 修复 macOS 特有 bug
- 更新 goal-tree.md 证据矩阵

#### Task 3.2: FreeBSD runtime 验证
- 在 FreeBSD CI 环境运行所有 14 模块测试
- 修复 FreeBSD 特有 bug
- 更新 goal-tree.md 证据矩阵

#### Task 3.3: Android NDK runtime 验证
- 在 Android 模拟器/设备运行所有 14 模块测试
- 修复 bionic libc 差异
- 更新 goal-tree.md 证据矩阵

#### Task 3.4: 补齐 host FFI gap matrix
- 根据 runtime 验证结果更新 `docs/platform-host-ffi-gap-matrix.md`
- 确保每个 host 的 base/ffi 声明完整

### Phase 3 验收标准
- [ ] macOS 14/14 modules focused-runtime
- [ ] FreeBSD 14/14 modules focused-runtime
- [ ] Android 14/14 modules focused-runtime
- [ ] FFI gap matrix 更新

---

## Phase 4: 性能优化 — 关键路径加速 (3-5天)

### 目标
对性能关键路径进行优化，为 Benchmark 阶段做好准备。

### 任务清单

#### Task 4.1: platform.io — epoll batch 优化
- epoll_wait 批量处理
- 减少系统调用次数
- 对标: Go runtime netpoll

#### Task 4.2: platform.sync — futex fast path
- 消除不必要的原子操作
- 减少 futex 系统调用
- 对标: Rust parking_lot

#### Task 4.3: platform.memory — SIMD 加速
- 使用 SIMD 指令加速 secure_zero
- 使用 SIMD 加速 copy 操作
- 对标: glibc memcpy/memset

#### Task 4.4: platform.files — I/O 优化
- 大文件 I/O 使用 O_DIRECT
- read/write 批量优化
- 对标: Go os.File

#### Task 4.5: 消除平台间性能差异
- 确保 Windows 路径不低于 Linux 路径性能
- 消除条件编译中的不必要开销

### Phase 4 验收标准
- [ ] 关键路径性能不退化
- [ ] 优化项有独立 micro-benchmark 证据

---

## Phase 5: Benchmark — 跨语言基准对照 (3-5天)

### 目标
建立与 Go runtime / Rust std 的可信基准对照体系。

### 任务清单

#### Task 5.1: 基准框架搭建
- `benchmarks/nextpas.core.platform/` 目录结构
- 统一基准输出格式 (ns/op, MB/s, allocs/op)
- 基准编译器标志 (-O2, release mode)

#### Task 5.2: platform.time 基准
- `platform_monotonic_ns` vs Go `time.Now()` vs Rust `Instant::now()`
- 时钟分辨率对比

#### Task 5.3: platform.sync 基准
- Mutex lock/unlock vs Go `sync.Mutex` vs Rust `std::sync::Mutex`
- RwLock vs Go `sync.RWMutex` vs Rust `std::sync::RwLock`
- Futex wait/wake vs Rust parking_lot

#### Task 5.4: platform.memory 基准
- aligned_alloc vs Go make vs Rust alloc
- secure_zero vs Go/Rust 内存清零

#### Task 5.5: platform.files 基准
- 文件 I/O (read/write) vs Go os.File vs Rust std::fs
- 目录遍历 vs Go filepath.Walk vs Rust walkdir

#### Task 5.6: platform.socket 基准
- TCP echo throughput vs Go net vs Rust tokio
- UDP throughput

#### Task 5.7: 基准报告
- 汇总所有基准结果
- 诚实标注差异和 caveats
- 写入 `docs/platform/benchmark-report.md`

### Phase 5 验收标准
- [ ] 6 个基准类别全部完成
- [ ] 每个基准有 Go/Rust 对照数据
- [ ] 关键路径不低于 Go/Rust 80% 性能
- [ ] 基准报告完成

---

## Phase 6: 文档与治理收官 (2-3天)

### 目标
完善文档体系，更新目标树，做好模块治理收尾。

### 任务清单

#### Task 6.1: API 参考文档
- 每个子模块的 API 参考
- 写入 `docs/platform/api-reference/`

#### Task 6.2: 设计决策记录
- ADR: SO_REUSEPORT 多平台值管理
- ADR: IOCP vs WSAPoll 架构决策
- ADR: WaitOnAddress lazy-load 策略

#### Task 6.3: 目标树更新
- 更新 goal-tree.md 到最终状态
- 标记所有 Phase 完成证据

#### Task 6.4: 模块注册表更新
- 更新 `docs/core-module-registry.md` 中 platform 条目
- 更新稳定性分级

### Phase 6 验收标准
- [ ] API 参考文档完整
- [ ] ADR 记录完整
- [ ] goal-tree.md 最终更新
- [ ] 模块注册表更新

---

## 总路线图位置

```
Phase 1: 债务清零        [████████░░] 当前 ← 我们在这里
Phase 2: API 完整性      [░░░░░░░░░░]
Phase 3: 跨平台深化       [░░░░░░░░░░]
Phase 4: 性能优化         [░░░░░░░░░░]
Phase 5: Benchmark       [░░░░░░░░░░]
Phase 6: 文档与治理       [░░░░░░░░░░]
```

## 总预计工时: 18-28 天

## 验收总标准
- [ ] 所有 14 模块在 5 个宿主上 focused-runtime 验证
- [ ] API 接口对标 Go/Rust 标准库
- [ ] 关键路径性能不低于 Go/Rust 80%
- [ ] 0 内存泄漏
- [ ] 100% 测试覆盖
- [ ] 文档完整
