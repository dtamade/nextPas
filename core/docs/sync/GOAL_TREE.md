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
- [x] CondVar / `INativeMutex` 类型级配对；`TFutexMutex` 不可配 CondVar
- [x] `TSyncPool` TLS freelist + 并发测试与 bench；per-pool TLS；冷路径 `IMutex`
- [x] 文档 SSOT：README + CONTRACT + SCORECARD + 本 GOAL_TREE
- [x] source-contract + 行为测试 + Windows compile gate
- [x] path-limited land 到 `origin/main`（2026-07-20）
- [x] Stress / 超时边界补强（WaitGroup 高并发、Event multi-waiter、Semaphore timeout 0、CondVar signal）
- [x] Darwin forced compile gate（`-dNEXTPAS_FORCE_HOST_DARWIN`）
- [x] Destroy 持锁策略写入 CONTRACT

---

## Now

- [ ] path-limited landing（本批 B1–B3 提交）
- [ ] SCORECARD contended 数字刷新（可选）

---

## Next

1. FreeBSD compile gate（若 FORCE_HOST 稳定）
2. SCORECARD SC7/SC8 contended 本机基线固化
3. 是否公开 `RecursiveMutex`；是否门面化 Pool（默认暂缓）
4. 销毁持锁可检测路径（仅在有跨平台语义后）

---

## Deferred

- Channel / Latch / Notify（可能属 async 或独立模块）
- 公开 API 重命名（`Do_` 等）— **冻结**
- FPC `SyncObjs` 兼容层 — **禁止**

---

## 非目标

- 拥有 platform ABI 细节
- 替代 `async` 事件循环内同步原语
- 在本 lane 无理由大改 http/tls 消费者
