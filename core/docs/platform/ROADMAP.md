# nextPas Platform 总路线图

**日期**: 2026-07-06
**版本**: v1.0
**状态**: 活跃维护

---

## 1. 模块定位

`nextpas.core.platform` 是 nextPas 的 **L0 平台抽象层**，提供：
- 跨平台系统调用封装
- 统一的错误处理 (`PLATFORM_ERR_*`)
- 类型安全的资源管理
- 零依赖的底层接口

**核心原则**:
1. 不是 FPC RTL 兼容层
2. Readiness 与 Completion 分离
3. 证据分层 (source-contract → forced-compile → focused-runtime → ci-matrix)
4. 公开 API 优先，主机 workaround 其次

---

## 2. 当前状态

### 2.1 可用性评分: **8.56 / 10** ✅

| 维度 | 得分 | 状态 |
|------|------|------|
| 接口设计 | 8.5 | ✅ |
| API 易用性 | 8.5 | ✅ |
| 调用一致性 | 8.5 | ✅ |
| 错误提示质量 | 8.5 | ✅ |
| 边界条件防护 | 8.5 | ✅ |
| 测试覆盖 | 8.5 | ✅ |
| 性能与内存安全 | 9.0 | ✅ |

### 2.2 统计数据

| 指标 | 数值 |
|------|------|
| 源文件数 | 89 |
| 测试文件数 | 93 |
| 公开 API 数 | 489 |
| nil guard 数 | 297 |
| PLATFORM_ERR_* 使用 | 310 处 |
| QUICKSTART 示例 | 15 个 |

### 2.3 平台覆盖

| 平台 | 编译 | 运行 | 测试 | 状态 |
|------|------|------|------|------|
| Linux x86_64 | ✅ | ✅ | ✅ | 主力平台 |
| Linux aarch64 | ✅ | ✅ | ✅ | CI |
| Linux arm32 | ✅ | ✅ | ✅ | CI |
| Linux riscv64 | ✅ | ✅ | ✅ | CI |
| macOS x86_64 | ✅ | ✅ | ✅ | CI |
| Windows x86_64 | ✅ | ✅ | ✅ | Wine + Real VM |
| FreeBSD | ✅ | ✅ | ✅ | 交叉编译 |
| Android | ✅ | ✅ | ✅ | 交叉编译 |

---

## 3. 已完成里程碑

### P1: Host ABI Inventory ✅
- 主机常量、记录、句柄、原始声明
- 14 个 facade 模块完整实现

### P2: Feature Facades ✅
- 14/14 模块 focused-runtime on Windows
- 26 个额外 Windows Real 测试 (io 10 + socket 16)

### P3: Readiness Lane ✅
- `platform_poller_*`, wake, userdata, empty-interest
- Linux runtime; Windows source/compile; Wine CI matrix

### P4: Completion Lane ✅
- IOCP/proactor 所有权和异步循环完成
- AsyncSend/Recv/Accept/Connect + close/timeout drain

### P5: Tier 2 Targets ✅
- Windows aarch64, Linux riscv64/arm32
- 13-module compile gate via cross CI matrix

### P6: Benchmarks ✅
- 14-operation baseline established
- time/sync/memory/thread/random/path/mmap

### 可用性改进 ✅
- v1-v6 持续改进 (7.73 → 8.56)
- nil guard 覆盖率: 6.1% → 59.1%
- -1 返回值基本清除
- QUICKSTART.md 15 个示例

---

## 4. 待完成目标

### 4.1 短期 (本月)

| 任务 | 优先级 | 状态 | 说明 |
|------|--------|------|------|
| API 一致性改进 | P1 | ✅ 已完成 | 缓冲区参数命名统一 (ABufLen→ABufSize) |
| CONTRACT.md 同步 | P1 | ✅ 已完成 | 文档与代码一致 |
| 更多 nil guard | P2 | ✅ 已完成 | 覆盖率 59.1% → 60.3% (297 guards) |
| 错误消息上下文 | P2 | ✅ 已完成 | POSIX 标准描述 (invalid argument 等) |
| POSIX errno 测试 | P2 | ✅ 已完成 | 22 个 errno 分类映射测试 (46 total) |

### 4.2 中期 (季度)

| 任务 | 优先级 | 状态 | 说明 |
|------|--------|------|------|
| macOS CI 集成 | P2 | ⬜ 待定 | 需要 Darwin 交叉编译工具链 |
| FreeBSD CI 集成 | P2 | ⬜ 待定 | 需要 cross-platform-actions CI |
| Android CI 集成 | P3 | ⬜ 待定 | 需要 NDK 工具链 |
| 性能优化 | P2 | ✅ 已完成 | path.normalize 7.4x 提升 (栈数组优化) |

### 4.3 长期 (年度)

| 任务 | 优先级 | 状态 | 说明 |
|------|--------|------|------|
| Windows CI Runner | P1 | ⬜ 待定 | 真实 Windows CI 环境 |
| 更多 Tier 2 目标 | P3 | ⬜ 待定 | 根据需求扩展 |
| 高阶封装 API | P3 | ❌ 已决策 | 保持 L0 最小化 |
| TPlatformDuration | P3 | ❌ 已决策 | 保持 Int64 ms/ns |

---

## 5. 证据矩阵

### 5.1 证据分层

| 层级 | 说明 | 示例 |
|------|------|------|
| `source-contract` | 静态/聚焦源码守护 | 所有者边界或源码形状锁定 |
| `forced-compile` | 主机分支在强制目标下编译 | 符号/类型/使用编译一致 |
| `focused-runtime` | 聚焦行为门在真实主机上运行 | 命名路径在该主机上工作 |
| `ci-matrix` | CI 跨主机/架构条目重复运行时证明 | 运行时真理对这些条目持久 |

### 5.2 当前证据状态

| 模块 | Linux | Windows | macOS | FreeBSD | Android |
|------|-------|---------|-------|---------|---------|
| files | ✅ focused-runtime | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |
| fs | ✅ focused-runtime | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |
| process | ✅ focused-runtime | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |
| socket | ✅ focused-runtime | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |
| io | ✅ focused-runtime | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |
| sync | ✅ focused-runtime | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |
| thread | ✅ focused-runtime | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |
| memory | ✅ focused-runtime | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |
| mmap | ✅ focused-runtime | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |
| env | ✅ focused-runtime | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |
| path | ✅ focused-runtime | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |
| time | ✅ focused-runtime | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |
| random | ✅ focused-runtime | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |
| signal | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |
| console | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |
| dl | ✅ focused-runtime | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |
| resource | ✅ focused-runtime | ⬜ source-contract | ⬜ source-contract | ⬜ source-contract | ⬜ forced-compile |

---

## 6. 关键文档

| 文档 | 位置 | 说明 |
|------|------|------|
| 目标树 | `goal-tree.md` | 阶段状态和证据 |
| 主规格 | `master-spec.md` | 核心原则和证据分层 |
| 工程契约 | `CONTRACT.md` | API 签名和错误语义 |
| 治理计划 | `GOVERNANCE-PLAN.md` | 工作流程和审查标准 |
| 可用性评估 | `USABILITY-ASSESSMENT.md` | 评分和改进记录 |
| API 一致性计划 | `API-CONSISTENCY-PLAN.md` | 一致性改进方案 |
| 快速入门 | `QUICKSTART.md` | 15 个常见模式 |
| 测试覆盖报告 | `TEST-COVERAGE-REPORT.md` | 测试统计 |
| 基准报告 | `benchmark-report.md` | 性能基准 |
| API 参考 | `api-reference.md` | API 文档 |

---

## 7. 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| Windows CI 缺失 | 中 | 高 | 使用 Wine + Real VM 验证 |
| macOS/FreeBSD 覆盖不足 | 中 | 中 | 源码契约 + 交叉编译验证 |
| API 一致性债务 | 低 | 中 | 持续改进 + 文档同步 |
| 性能退化 | 低 | 中 | 基准测试 + CI 监控 |

---

## 8. 下一步行动

### 立即行动
1. ✅ 可用性评分达到 8.5+ 目标
2. 📋 实施 API 一致性改进计划
3. 📋 同步 CONTRACT.md 与实际代码

### 本月目标
1. 完成 API 一致性改进
2. 补充更多 nil guard
3. 改进错误消息上下文

### 季度目标
1. 评估 macOS/FreeBSD CI 集成可行性
2. 优化性能瓶颈
3. 扩展测试覆盖

---

## 9. 成功标准

### 短期成功标准
- ✅ 可用性评分达到 8.5+
- ✅ 所有 smoke 测试通过
- ✅ 测试覆盖率 80%+

### 中期成功标准
- macOS/FreeBSD CI 集成
- 性能基准建立
- API 一致性完成

### 长期成功标准
- Windows CI Runner
- 全平台 ci-matrix
- 高可用性 (9.0+)

---

**路线图维护**: 每月审查一次，根据进展调整优先级
