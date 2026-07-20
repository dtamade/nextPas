# nextpas.core.sync Goal Tree

**Lane**: `sync` @ `.worktrees/sync`
**状态**: **Maintenance Ready**
**更新**: 2026-07-20（CONTRACT 1.4 usability slice）

## 愿景

成为 nextPas 最可信的 L1 同步词汇表：契约与代码一致、测试可证明、与 `platform.sync` 边界清晰、下游可安全依赖。

---

## Done（能力面）

- [x] 门面 + 原语 + `platform.sync` / `INativeMutex` / per-pool TLS
- [x] Compile gates: Windows + Darwin + FreeBSD + Android
- [x] Stress / Barrier 多线程 / Destroy 错误面 / source-contract
- [x] SCORECARD SC1–SC10（含 multi-sample contended）
- [x] 示例 `core/examples/nextpas.core.sync/sync_basics`
- [x] 文档 SSOT：README / CONTRACT / SCORECARD / 本 GOAL_TREE
- [x] RecursiveMutex / Pool 门面 — **暂缓**（无生产消费者）
- [x] path-limited land 多批；landing worktree 已清理
- [x] **1.4 usability**：`TDuration` 超时重载、`DoOnce`、`WaitGroup.WaitTimeout`、`sync.errors`、`FHandle` private
- [x] 测试 / 示例 / bench 剥离 `SysUtils`/`Classes`/`SyncObjs`，统一 `TWorkerThread`

---

## Now

**无主动功能批。**

Lane 保持与 `origin/main` 对齐；仅在下列触发时再开 slice：

| 触发 | 响应 |
|------|------|
| 测试/生产缺陷 | 最小修复 + focused gate + path-limited land |
| 生产需要递归锁 | 评估 `RecursiveMutex: INativeMutex` |
| 生产广泛使用 Pool | 评估门面 re-export + 契约升级 |
| 跨平台要求统一 held-destroy | owner-thread / debug 检测层 |
| 架构确认归属 | Channel / Latch / Notify |

---

## Deferred（硬禁止 / 冻结）

- 公开 API 重命名（如 `Do_`）— **冻结**（`DoOnce` 为别名，不替换）
- FPC `SyncObjs` / 在 L1 消费者直接依赖 `SysUtils`/`Classes` — **禁止**
- P3 扩展（Channel / Latch / Notify / Scoped 组合器）— **待消费者驱动**

---

## 验证入口（交接）

```bash
make focused FOCUS=core/tests/nextpas.core.sync
make -C core/examples/nextpas.core.sync/sync_basics run
make -C core/benchmarks/nextpas.core.sync/bench_sync run   # 可选 SCORECARD
```

## 非目标

- 拥有 platform ABI 细节
- 替代 `async` 事件循环内同步原语
- 无消费者驱动的 API 扩张
