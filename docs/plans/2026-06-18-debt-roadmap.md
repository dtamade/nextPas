# nextPas 剩余技术债务路线图

> 日期: 2026-06-18
> 来源: Codex 架构研究 + Claude 执行
> 状态: 方案就绪，待执行

## 七项债务总览

| # | 项目 | 工作量 | 风险 | 推荐方案 |
|---|------|--------|------|---------|
| 1 | StrComp 替代 | 0.25天 | 极低 | base 新增 StrComp(PAnsiChar) |
| 2 | TInterfacedObject seam | 1+5天 | 中 | B→A: 先迁移平台单元，后建 TRefCountedObject |
| 3 | TThread worker | 3天 | 中 | 创建 TWorkerThread (platform_thread_create) |
| 4 | Gate 2 unit lifecycle | 5天 | 高 | @llvm.global_ctors/dtors |
| 5 | Gate 3 process lifecycle | 3天 | 中 | hnkProcessInitRuntime + LLVM helper |
| 6 | Gate 4 heap manager | 4.5天 | 高 | 分阶段委托 core.mem |
| 7 | Platform layer | 5.5天 | 低-中 | 分层替换 DynLibs→Socket→Windows→Unix |

## 依赖关系

```
[1. StrComp]        ── 无依赖
[7. Platform]       ── 无依赖
[3. TThread]        ── 无依赖
[5. Gate 3]         ── 无依赖，但应先于 4 和 2
[2. TInterfacedObj] ── 依赖 7 (socket)
[4. Gate 2]         ── 依赖 5
[6. Gate 4]         ── 依赖 5 (runtime linkage)
```

## Sprint 路线图

### Sprint 1 (第 1 周)
- [x] #1 StrComp (0.25天) — 消除最后 1 个 SysUtils
- [x] #5 Gate 3 process lifecycle (已完成) — HIR→LLVM 管道已全通
- [x] #7 Platform Phase 1: DynLibs→platform.dl (已完成)

### Sprint 2 (第 2 周)
- [x] #7 Platform Phase 2-4: Socket/Windows/Unix (已完成 — 57文件, 149/149 OpenSSL API 全绿)
- [x] #3 TThread: platform_thread 迁移 (已完成 — 4文件, Codex 8项整改)

### Sprint 3 (第 3 周)
- [x] #2 transport.pas 平台单元替换 (Sprint 2 已完成)
- [ ] #4 Gate 2 unit lifecycle: @llvm.global_ctors (5天)

### Sprint 4 (第 4 周)
- [ ] #6 Gate 4 heap: 阶段 1-2 (3.5天)

### Sprint 5 (第 5 周)
- [ ] #6 Gate 4 heap: 阶段 3-4
- [ ] #2 全局 TInterfacedObject 替换 (5天)

## 各项详细方案

### 1. StrComp (0.25天, 极低风险)
在 `nextpas.core.base` 新增 `function StrComp(a, b: PAnsiChar): Integer;`
实现: 逐字节循环比较到 null terminator。lhash.pas 删除 `uses SysUtils`。

### 2. TInterfacedObject (1+5天, 中风险)
短期: transport.pas 的 BaseUnix/Sockets/WinSock2 → platform.socket (1天)
长期: 创建 `nextpas.core.base.TRefCountedObject` 替代 TInterfacedObject (5天)

### 3. TThread worker (3天, 中风险)
创建 `nextpas.core.thread.worker.TWorkerThread`:
- 基于 platform_thread_create (不继承 TThread)
- Execute 虚方法 + Terminated 标志 + WaitFor
- 改造 tui.task.pas + ocsp.stapling.pas
- TRTLCriticalSection → IMutex

### 4. Gate 2 unit lifecycle (5天, 高风险)
使用 @llvm.global_ctors/@llvm.global_dtors:
- HIR: hnkUnitInitRuntime/hnkUnitFiniRuntime
- LLVM: 每个 unit init/fini 编译为独立函数，注入 global_ctors/dtors
- 依赖 Gate 3 先完成

### 5. Gate 3 process lifecycle (3天, 中风险)
打通 HIR→LLVM 管道:
- ParseHirNodeKind: 'process-init-runtime' → hnkProcessInitRuntime
- SeedRuntimeContracts: emit 特定 kind 字符串
- LLVM: @np_process_init/@np_process_fini helper
- _start: init → user code → fini → halt

### 6. Gate 4 heap manager (4.5天, 高风险)
分阶段:
- 阶段 1: 文档标记为 bootstrap-temporary (0.5天)
- 阶段 2: 创建 runtime.allocator 模块 (3天)
- 阶段 3: LLVM emitter 改为外部声明 (1天)

### 7. Platform layer (5.5天, 低-中风险)
- Phase 1: DynLibs→platform.dl (2天, 16文件)
- Phase 2: Socket/BaseUnix→platform.socket (2天)
- Phase 3: Windows→platform.windows (1天)
- Phase 4: Unix→platform.posix (0.5天)
