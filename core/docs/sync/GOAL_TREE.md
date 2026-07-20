# nextpas.core.sync Goal Tree

**Lane**: `sync` @ `.worktrees/sync`
**更新**: 2026-07-20

## 愿景

成为 nextPas 最可信的 L1 同步词汇表：契约与代码一致、测试可证明、与 `platform.sync` 边界清晰、下游可安全依赖。

---

## Done

- [x] 门面 + 十种原语实现（Mutex / FutexMutex / RWLock / CondVar / SpinLock / WaitGroup / Once / Semaphore / Barrier / Event）
- [x] 平台句柄路径走 `platform.sync`（含 rwlock 分模式 unlock）
- [x] 用户态原语基于 atomic + address-wait
- [x] CondVar 拒绝 `TFutexMutex` 配对
- [x] `TSyncPool` TLS freelist + 并发测试与 bench
- [x] 基础 `test_sync` / `test_sync_pool` 行为覆盖
- [x] 文档 SSOT：README + CONTRACT 1.1 + 本 GOAL_TREE
- [x] 删除空壳 `test_sync_posix_fallback`
- [x] 模块级测试 Makefile + source-contract gate
- [x] 关键错误路径行为测试补强

---

## Now（当前 lane 焦点）

- [x] 基线验证证据落盘（focused gates + hygiene，2026-07-20）
- [ ] Ready 报告与 path-limited landing 准备（由总控/用户触发 commit）

---

## Next

1. **E2 Pool 去 FPC 债**：`TRTLCriticalSection` → nextpas `IMutex`/`TMutex`；评估 per-pool TLS
2. CondVar / Futex 类型级隔离（若可无破坏消费者）
3. L1 Windows / Darwin compile gate（与 platform 对齐）
4. Stress / 超时边界 / 销毁持锁策略统一
5. SCORECARD + 可复现 uncontended/contended bench 入口
6. 是否公开 `RecursiveMutex`；是否门面化 Pool

---

## Deferred

- Channel / Latch / Notify（可能属 async 或独立模块）
- 公开 API 重命名（`Do_` 等）— **冻结**，需大版本策略
- 把 sync 做成 FPC `SyncObjs` 兼容层 — **禁止**（见双编译器原则）

---

## 非目标

- 拥有 platform ABI 细节
- 替代 `async` 事件循环内同步原语
- 在本 lane 无理由大改 http/tls 消费者
