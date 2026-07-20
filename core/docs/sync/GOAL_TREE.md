# nextpas.core.sync Goal Tree

**Lane**: `sync` @ `.worktrees/sync`
**状态**: **Maintenance**
**更新**: 2026-07-20

## 愿景

成为 nextPas 最可信的 L1 同步词汇表：契约与代码一致、测试可证明、与 `platform.sync` 边界清晰、下游可安全依赖。

---

## Done

- [x] 门面 + 原语 + platform.sync / INativeMutex / per-pool TLS
- [x] Compile gates: Windows + Darwin + FreeBSD + Android
- [x] Stress / 超时 / Barrier 多线程 / Destroy 错误面
- [x] SCORECARD SC1–SC10 multi-sample contended
- [x] source-contract（门面、Destroy raise、四 compile gate）
- [x] RecursiveMutex / Pool 门面 — **暂缓**（无生产消费者）
- [x] path-limited land 多批

---

## Now

- [ ] 本批 Maintenance landing

---

## Next（仅真实触发再开）

1. owner-thread Destroy 检测（需跨平台统一语义时）
2. RecursiveMutex / Pool 门面（出现生产消费者时）
3. Channel / Latch（架构归属确认后）

---

## Deferred

- API 重命名 `Do_` — **冻结**
- FPC `SyncObjs` 兼容层 — **禁止**
