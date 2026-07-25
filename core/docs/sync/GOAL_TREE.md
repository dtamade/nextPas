# nextpas.core.sync Goal Tree

**Lane**: `sync` @ `.worktrees/sync`
**状态**: **Maintenance Ready**
**更新**: 2026-07-21（CONTRACT **1.6.1** N1 测试 + N2 文档决议）

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
- [x] **1.4–1.6** 可用性与 P3 词汇表
- [x] **1.6.1 N1**：Channel close 竞态 / multi-recv / Once 闭包异常 / Boolean 矩阵 / Barrier 2×2 gen
- [x] **1.6.1 N2**：F-R1 决议（Send/Recv 保持 Boolean）；通道选型表；Notify 注释；Deferred 登记
- [x] path-limited land 多批

---

## Now

**无主动功能批。**

| 触发 | 响应 |
|------|------|
| 测试/生产缺陷 | 最小修复 + focused gate + path-limited land |
| Barrier.WaitTimeout / Mutex timed lock | 有明确消费者再开切片 |
| Pool DrainTLS 自动 | **cross-module** thread 退出钩子（Needs Review） |
| 无界 / 泛型 sync.Channel | 与 `thread.IChannel<T>` 去重评审后再定 |

---

## Deferred（硬禁止 / 冻结）

- 公开 API 重命名（删除 `Do_`）— **冻结**
- `Send`/`Recv` 改为枚举返回 — **否决**（1.6.1 决议；破坏面 > 收益）
- FPC `SyncObjs` / 消费者直接 `SysUtils`/`Classes` — **禁止**
- Event 默认改 auto — **不做**
- 无界 channel / rendezvous(0) / 非 Pointer 载荷 — **待消费者驱动**
- DrainTLS 自动回收 — **独立 cross-lane**

---

## 验证入口

```bash
make focused FOCUS=core/tests/nextpas.core.sync
make -C core/examples/nextpas.core.sync/sync_basics run
```

## 非目标

- 拥有 platform ABI 细节
- 替代 `async` 事件循环内同步原语
