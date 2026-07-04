# nextPas 技术债看板

> 最后更新：2026-07-05
> 用途：统一追踪所有已知技术债，每个 sprint 结束时 review

## 看板说明

| 字段 | 含义 |
|------|------|
| **严重度** |   阻塞自举 /   影响多模块 /   局部 /   文档/规范 |
| **范围** | compiler / core / rtl / 跨模块 |
| **预估** | 人天 |

---

## 活跃债务

### 编译器

| # | 债务 | 严重度 | 范围 | 预估 | 状态 |
|---|------|--------|------|------|------|
| C1 | **sema 主文件过大** (12,175 行 → 目标 <8000) |    | compiler/sema | 3d |   待拆分 |
| C2 | **permissive overload resolution** (选第一个候选) |    | compiler/sema | 3d |   C8 临时方案 |
| C3 | **增量编译** (符号表热缓存) |    | compiler/frontend | 5d |   方案已有 |
| C4 | **并行编译** (拓扑序分层) |    | compiler/frontend | 3d |   依赖 C3 |
| C5 | **Gate 2 unit lifecycle** (@llvm.global_ctors) |    | compiler/ir | 5d |   方案已有 |
| C6 | **Gate 4 heap manager** (真实 malloc/free) |    | compiler/ir + core/mem | 4.5d |   方案已有 |
| C7 | **c2p_win32_compat** (平台排除) |    | compiler | 1d |   最后残留 |

### Core 框架

| # | 债务 | 严重度 | 范围 | 预估 | 状态 |
|---|------|--------|------|------|------|
| L1 | **mail 模块契约缺失** (L3 2/3 → 3/3) |    | core/docs | 0.5d |   最后一块 |
| L2 | **TInterfacedObject 替代** (TRefCountedObject) |    | core/base | 5d |   方案已有 |
| L3 | **TThread 替代** (TWorkerThread) |    | core/thread | 3d |   方案已有 |
| L4 | **StrComp SysUtils 依赖** (lhash.pas) |    | core/base | 0.25d |   最后一个 SysUtils |
| L5 | **泛型构造器传播** (collections, crypto.*) |    | compiler/sema | 10d |   未开始 |
| L6 | **Class helper 完整支持** (thread.future, text.format) |    | compiler/sema | 10d |   未开始 |

### 平台/构建

| # | 债务 | 严重度 | 范围 | 预估 | 状态 |
|---|------|--------|------|------|------|
| P1 | **platform.pipe** FPC 汇编问题 |    | core/platform | ? |   后续修复 |
| P2 | **platform.signal** FPC 汇编问题 |    | core/platform | ? |   后续修复 |
| P3 | **platform.which** FPC 汇编问题 |    | core/platform | ? |   后续修复 |
| P4 | **simd.sse42** 内联汇编 |    | core/simd | ? |   后续修复 |
| P5 | **tui.widget.linechart** FPC 汇编问题 |    | core/tui | ? |   后续修复 |
| P6 | **io.mapped.ring_buffer.sharded** FPC 编译错误 |    | core/io | ? |   后续修复 |
| P7 | **net.server.runtime** FPC 编译错误 |    | core/net | ? |   后续修复 |

---

## 已清偿

| # | 债务 | 清偿日期 |
|---|------|----------|
| ✅ | IsBuiltinProcedure 重构为注册表 | 2026-06 |
| ✅ | IsDeferredSystemObjectMember 清理 | 2026-06 |
| ✅ | sema 17,735 → 12,175 行拆分 | 2026-06 |
| ✅ | C5 `{$IFDEF}` 预处理器支持 | 2026-07-03 |
| ✅ | C6-H4 owned string return | 2026-07-03 |
| ✅ | C7 自举验证 | 2026-07-03 |
| ✅ | FPC RTL 清零 (0 直接 SysUtils/Classes/System) | 2026-07-03 |
| ✅ | Exception 自给自足 | 2026-06-24 |
| ✅ | 平台类型自足 (SizeInt/SizeUInt) | 2026-06-24 |
| ✅ | 57 模块契约全覆盖 | 2026-07-04 |
| ✅ | mem 审计 R4+R5 清零 | 2026-07-05 |
| ✅ | bench 审计 14/17 修复 | 2026-07-05 |
| ✅ | StrComp (Sprint 1) | 2026-06 |
| ✅ | Gate 3 process lifecycle | 2026-06 |
| ✅ | Platform Phase 1-4 (DynLibs/Socket/Windows/Unix) | 2026-06 |
| ✅ | TThread: platform_thread 迁移 | 2026-06 |

---

## Sprint 建议

### 当前 Sprint (2026-07-05 起)

| 优先级 | 债务 | 理由 |
|--------|------|------|
| P0 | C7: c2p_win32_compat | C8 最后残留 |
| P0 | L1: mail 模块契约 | L3 最后一块 |
| P1 | C1: sema 继续拆分 | 降低改动风险 |
| P1 | C5: Gate 2 unit lifecycle | 自举硬依赖 |

### 下一 Sprint

| 优先级 | 债务 | 理由 |
|--------|------|------|
| P0 | C6: Gate 4 heap manager | 自举硬依赖 |
| P1 | C3: 增量编译 | 开发体验质变 |
| P1 | C2: permissive overload → 正式 | 正确性 |

---

## 治理关联

- 项目总控: `PLAN.md`
- 目标树: `docs/plans/goal-tree.md`
- 自举路线图: `docs/plans/selfhost-roadmap.md`
- 原始债务方案: `docs/plans/2026-06-18-debt-roadmap.md` (已归档)

---

*最后 review: 2026-07-05*
