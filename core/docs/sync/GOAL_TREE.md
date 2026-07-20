# nextpas.core.sync Goal Tree

**Lane**: `sync` @ `.worktrees/sync`
**状态**: **Maintenance Ready**
**更新**: 2026-07-21（CONTRACT **1.6** usability harden）

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
- [x] **1.4 usability**：`TDuration` 超时、`DoOnce`、`sync.errors`、`TWorkerThread` 消费者
- [x] **1.5 P3**：`RecursiveMutex`、`Latch`、`Notify`、`Channel`、Scoped、`TSyncPool` 门面
- [x] **1.6 harden**：Channel timeout 枚举；CondVar 错误/超时分离；NotifyAll 语义；Once 闭包；Pool `TPoolItem` 检查
- [x] path-limited land 多批

---

## Now

**无主动功能批。**

| 触发 | 响应 |
|------|------|
| 测试/生产缺陷 | 最小修复 + focused gate + path-limited land |
| 需要无界 / 泛型 channel | 新契约切片 |
| 跨平台 held-destroy | owner-thread / debug 检测层 |

---

## Deferred（硬禁止 / 冻结）

- 公开 API 重命名（如删除 `Do_`）— **冻结**
- FPC `SyncObjs` / 消费者直接 `SysUtils`/`Classes` — **禁止**
- 无界 channel / rendezvous(0) / 非 Pointer 载荷 — **待消费者驱动**
- Event 默认改 auto — **不做**（破坏性；文档说明即可）

---

## 验证入口

```bash
make focused FOCUS=core/tests/nextpas.core.sync
make -C core/examples/nextpas.core.sync/sync_basics run
```

## 非目标

- 拥有 platform ABI 细节
- 替代 `async` 事件循环内同步原语
