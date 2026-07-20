# nextpas.core.sync Goal Tree

**Lane**: `sync` @ `.worktrees/sync`
**更新**: 2026-07-20

## 愿景

成为 nextPas 最可信的 L1 同步词汇表：契约与代码一致、测试可证明、与 `platform.sync` 边界清晰、下游可安全依赖。

---

## Done

- [x] 门面 + 原语 + platform.sync / INativeMutex / per-pool TLS
- [x] Windows + Darwin + FreeBSD compile gate
- [x] Stress / 超时边界 + source-contract
- [x] SCORECARD SC1–SC10；contended multi-sample median/p95
- [x] Destroy：传播 `platform_*_destroy` 错误；held destroy 最佳努力测试
- [x] RecursiveMutex / Pool 门面 — **暂缓**（无生产消费者，已文档化）
- [x] path-limited land 多批

---

## Now

- [ ] 本批 path-limited landing

---

## Next

1. owner-thread 级 Destroy 检测（仅当需要跨平台统一语义时）
2. contended bench 更高分辨率 / 绑核（可选）
3. 有真实消费者时再评估 RecursiveMutex / Pool 门面

---

## Deferred

- Channel / Latch / Notify
- API 重命名 `Do_` — **冻结**
- FPC `SyncObjs` 兼容层 — **禁止**
