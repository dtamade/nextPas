# nextpas.core.sync Goal Tree

**Lane**: `sync` @ `.worktrees/sync`
**状态**: **Maintenance (idle)**
**更新**: 2026-07-20

## 愿景

成为 nextPas 最可信的 L1 同步词汇表：契约与代码一致、测试可证明、与 `platform.sync` 边界清晰、下游可安全依赖。

---

## Done

- [x] 门面 + 原语 + platform.sync / INativeMutex / per-pool TLS
- [x] Compile gates: Windows + Darwin + FreeBSD + Android
- [x] Stress / Barrier 多线程 / Destroy 错误面 / source-contract
- [x] SCORECARD SC1–SC10 multi-sample contended
- [x] 示例 `core/examples/nextpas.core.sync/sync_basics`
- [x] RecursiveMutex / Pool 门面 — **暂缓**（无生产消费者）
- [x] path-limited land 多批

---

## Now

- [ ] （无主动功能批）响应消费者缺陷 / 平台契约变化

---

## Next（仅触发再开）

| 触发 | 工作 |
|------|------|
| 生产需要递归锁 | 评估 `RecursiveMutex: INativeMutex` |
| 生产广泛使用 Pool | 评估门面 re-export + 契约升级 |
| 跨平台要求统一 held-destroy | owner-thread 或 debug 检测层 |
| 架构确认归属 | Channel / Latch / Notify |

---

## Deferred

- API 重命名 `Do_` — **冻结**
- FPC `SyncObjs` 兼容层 — **禁止**
