# Platform 模块规划路线图

**日期**: 2026-07-06
**版本**: v2.0
**状态**: 活跃规划
**Owner**: Claude

---

## 1. 当前状态总结

### 1.1 基础数据

| 指标 | 数值 | 状态 |
|------|------|------|
| 源文件 | 59 个 / 19,096 行 | ✅ 稳定 |
| 测试文件 | 61 个 (27 套件) | ✅ 覆盖充分 |
| 公开 API | ~489 个 | ✅ 完整 |
| nil guard | 297 处 (60.3%) | ✅ 良好 |
| 可用性评分 | 8.56 / 10 | ✅ 达标 |
| PLATFORM_ERR_* 使用 | 310 处 | ✅ 统一 |

### 1.2 平台覆盖矩阵

| 平台 | 编译 | 运行 | 测试 | 证据层级 |
|------|------|------|------|----------|
| Linux x86_64 | ✅ | ✅ | 226 passed | focused-runtime |
| Windows x86_64 (Wine) | ✅ | ✅ | 174 passed | wine-runtime-smoke |
| Windows x86_64 (Real) | ✅ | ✅ | 26 tests | focused-runtime (io+socket) |
| Linux aarch64 | ✅ | ⬜ | — | forced-compile |
| Linux arm32 | ✅ | ⬜ | — | forced-compile |
| Linux riscv64 | ✅ | ⬜ | — | forced-compile |
| macOS x86_64 | ✅ | ⬜ | — | source-contract |
| FreeBSD | ✅ | ⬜ | — | source-contract |
| Android | ✅ | ⬜ | — | forced-compile |

### 1.3 已完成里程碑

| 里程碑 | 状态 | 说明 |
|--------|------|------|
| P1 Host ABI Inventory | ✅ | 主机常量、记录、句柄、原始声明 |
| P2 Feature Facades | ✅ | 14/14 模块 focused-runtime on Windows |
| P3 Readiness Lane | ✅ | platform_poller_*, wake, userdata |
| P4 Completion Lane | ✅ | IOCP AsyncSend/Recv/Accept/Connect |
| P5 Tier 2 Targets | ✅ | riscv64/aarch64/arm32 交叉编译 |
| P6 Benchmarks | ✅ | 14-operation baseline |
| P7 FFI Coverage Audit | ✅ | 评分 9/10, 6 个新 FFI 绑定 |
| 可用性改进 v1-v6 | ✅ | 7.73 → 8.56 |
| 跨平台修复 (字节序/InterlockedDecrement/LongBool/路径分隔符) | ✅ | 2026-07-06 |
| Windows API 覆盖审计 | ✅ | 146 FFI 声明，覆盖完整 |

---

## 2. 未完成工作清单

### 2.1 P8: macOS/Darwin 运行时证据

**目标**: 将 macOS 从 source-contract 提升到 forced-compile 或更高

| 任务 | 优先级 | 复杂度 | 说明 |
|------|--------|--------|------|
| Darwin 交叉编译环境搭建 | P1 | 高 | 需要 osxcross 或 GitHub Actions macOS runner |
| macOS compile gate | P1 | 中 | 13-module forced-compile on macOS |
| macOS runtime smoke | P2 | 中 | 核心模块 runtime 测试 (time/sync/thread/files/io) |
| kqueue IO backend 验证 | P2 | 高 | macOS 用 kqueue 替代 epoll/io_uring |

**阻塞项**:
- 需要 macOS 交叉编译工具链 (osxcross) 或 CI 环境
- kqueue 与 epoll/io_uring 的语义差异需要验证

**预期时间**: 季度级

---

### 2.2 P9: FreeBSD 运行时证据

**目标**: 将 FreeBSD 从 source-contract 提升到 forced-compile

| 任务 | 优先级 | 复杂度 | 说明 |
|------|--------|--------|------|
| FreeBSD 交叉编译环境搭建 | P1 | 高 | 需要 FreeBSD cross-compiler 或 cross-platform-actions CI |
| FreeBSD compile gate | P1 | 中 | 13-module forced-compile on FreeBSD |
| kqueue IO backend 验证 | P2 | 高 | FreeBSD 也用 kqueue |
| FreeBSD-specific syscall 差异 | P2 | 中 | 如 `closefrom`, `pdfork` 等 |

**阻塞项**:
- 需要 FreeBSD 交叉编译工具链
- cross-platform-actions CI 限制

**预期时间**: 季度级

---

### 2.3 P10: Android 运行时证据

**目标**: 将 Android 从 forced-compile 提升到 runtime smoke

| 任务 | 优先级 | 复杂度 | 说明 |
|------|--------|--------|------|
| Android NDK 交叉编译环境 | P1 | 高 | 需要 Android NDK + bionic libc |
| Android compile gate 增强 | P1 | 中 | 当前只有 files+mmap，扩展到 13 模块 |
| Android runtime smoke | P2 | 高 | 需要 Android 模拟器或设备 |
| bionic libc 差异处理 | P2 | 高 | 与 glibc 的系统调用差异 |

**阻塞项**:
- 需要 Android NDK 工具链
- bionic libc 与 glibc 差异大 (如 `pthread_*` 实现)
- 需要 Android 模拟器或真机环境

**预期时间**: 半年级

---

### 2.4 P11: Windows CI Runner

**目标**: 真实 Windows CI 环境，替代 Wine 验证

| 任务 | 优先级 | 复杂度 | 说明 |
|------|--------|--------|------|
| Windows CI runner 搭建 | P1 | 中 | GitHub Actions Windows runner 或自建 VM |
| Windows 全模块 runtime 测试 | P1 | 中 | 将 Wine 测试迁移到真实 Windows |
| IOCP completion 深度测试 | P2 | 高 | AcceptEx/ConnectEx/TransmitFile 完整覆盖 |
| Windows arm64 交叉编译 | P3 | 中 | aarch64-windows 交叉编译 |

**阻塞项**:
- 需要 Windows CI 环境 (GitHub Actions 或自建)
- IOCP 测试需要真实 Windows 网络栈

**预期时间**: 季度级

---

### 2.5 P12: 测试覆盖补全

**目标**: 消除测试盲区，提升覆盖率

| 任务 | 优先级 | 复杂度 | 说明 |
|------|--------|--------|------|
| signal 模块 Windows 测试 | P2 | 中 | SetConsoleCtrlHandler 行为验证 |
| console 模块 Windows 测试 | P2 | 中 | Wine pseudo-TTY 不适合，需真实 Windows |
| resource 模块 Windows 测试 | P2 | 中 | Windows 资源限制语义不同 |
| dl 模块 macOS/FreeBSD 测试 | P3 | 中 | dlopen/dlsym 跨平台行为 |
| pty 模块 macOS 测试 | P3 | 中 | macOS PTY 行为差异 |
| watch 模块 macOS 测试 | P3 | 中 | FSEvents vs inotify |

**预期时间**: 持续进行

---

### 2.6 P13: 性能优化与基准扩展

**目标**: 跨平台性能对比，发现优化机会

| 任务 | 优先级 | 复杂度 | 说明 |
|------|--------|--------|------|
| 跨平台基准对比 | P2 | 中 | Linux vs Windows 性能对比 |
| socket 性能优化 | P2 | 高 | TCP/UDP 吞吐量基准 |
| IO 性能优化 | P2 | 高 | 大文件读写、随机访问 |
| 内存分配器对比 | P2 | 中 | 平台分配器 vs nextpas.core.mem |

**预期时间**: 季度级

---

### 2.7 P14: API 完善与文档

**目标**: 提升 API 完整性和文档质量

| 任务 | 优先级 | 复杂度 | 说明 |
|------|--------|--------|------|
| API 参考文档完善 | P2 | 低 | 补充缺失的 API 文档 |
| 错误处理最佳实践 | P2 | 低 | PLATFORM_ERR_* 使用指南 |
| 跨平台移植指南 | P3 | 中 | 从 Linux 移植到 Windows/macOS 的注意事项 |
| 性能调优指南 | P3 | 中 | 平台特定的性能优化建议 |

**预期时间**: 持续进行

---

## 3. 优先级排序

### 3.1 立即行动 (本月)

| 任务 | 优先级 | 工作量 |
|------|--------|--------|
| 测试覆盖补全 (signal/console/resource Windows) | P2 | 1-2 天 |
| API 参考文档完善 | P2 | 1 天 |
| 错误处理最佳实践文档 | P2 | 0.5 天 | ✅ 已完成 |

### 3.2 短期目标 (本季度)

| 任务 | 优先级 | 工作量 |
|------|--------|--------|
| Windows CI Runner 搭建 | P1 | 2-3 天 |
| Windows 全模块 runtime 测试 | P1 | 2-3 天 |
| IOCP completion 深度测试 | P2 | 3-5 天 |
| 跨平台基准对比 | P2 | 2-3 天 |

### 3.3 中期目标 (下季度)

| 任务 | 优先级 | 工作量 |
|------|--------|--------|
| macOS 交叉编译环境搭建 | P1 | 3-5 天 |
| macOS compile gate | P1 | 2-3 天 |
| FreeBSD 交叉编译环境搭建 | P1 | 3-5 天 |
| socket/IO 性能优化 | P2 | 5-7 天 |

### 3.4 长期目标 (半年)

| 任务 | 优先级 | 工作量 |
|------|--------|--------|
| Android NDK 交叉编译环境 | P1 | 5-7 天 |
| macOS runtime smoke | P2 | 3-5 天 |
| FreeBSD runtime smoke | P2 | 3-5 天 |
| Android runtime smoke | P2 | 5-7 天 |

---

## 4. 资源需求

### 4.1 CI/CD 环境

| 环境 | 需求 | 当前状态 |
|------|------|----------|
| Linux x86_64 | ✅ 已有 | 主力开发环境 |
| Windows x86_64 | GitHub Actions 或自建 VM | Wine 替代 |
| macOS x86_64 | osxcross 或 GitHub Actions | 无 |
| FreeBSD | cross-platform-actions CI | 无 |
| Android | NDK + 模拟器 | 无 |

### 4.2 工具链

| 工具链 | 需求 | 当前状态 |
|--------|------|----------|
| FPC cross-compiler (Windows) | ✅ ppcrossx64 -Twin64 | 已有 |
| FPC cross-compiler (macOS) | osxcross + FPC | 待搭建 |
| FPC cross-compiler (FreeBSD) | FreeBSD cross-compiler | 待搭建 |
| FPC cross-compiler (Android) | Android NDK + FPC | 待搭建 |

---

## 5. 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| macOS/FreeBSD 交叉编译复杂 | 中 | 高 | 优先使用 GitHub Actions 环境 |
| Android bionic libc 差异大 | 高 | 高 | 逐步适配，优先核心模块 |
| Windows CI 成本高 | 中 | 中 | 使用 GitHub Actions 免费额度 |
| IOCP 测试复杂 | 中 | 中 | 分阶段实现，先基础后高级 |
| 跨平台性能差异 | 中 | 低 | 建立基准，持续监控 |

---

## 6. 成功标准

### 6.1 短期成功标准 (本季度)

- ✅ Windows CI Runner 搭建完成
- ✅ Windows 全模块 runtime 测试通过
- ✅ 测试覆盖率提升到 85%+

### 6.2 中期成功标准 (下季度)

- ✅ macOS compile gate 通过
- ✅ FreeBSD compile gate 通过
- ✅ 跨平台基准对比完成

### 6.3 长期成功标准 (半年)

- ✅ macOS runtime smoke 通过
- ✅ FreeBSD runtime smoke 通过
- ✅ Android runtime smoke 通过
- ✅ 可用性评分达到 9.0+

---

## 7. 维护计划

- **每月审查**: 检查进度，调整优先级
- **季度评估**: 评估里程碑完成情况，更新路线图
- **年度回顾**: 总结成果，规划下一年目标

---

**路线图维护**: 每月审查一次，根据进展调整优先级
**最后更新**: 2026-07-06 (错误处理最佳实践文档完成)
**API 覆盖矩阵**: 见 [API-COVERAGE-MATRIX.md](API-COVERAGE-MATRIX.md)
**错误处理指南**: 见 [ERROR-HANDLING.md](ERROR-HANDLING.md)
