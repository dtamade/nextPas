# nextpas.core.sync Goal Tree

**Lane**: `sync` @ `.worktrees/sync`
**更新**: 2026-07-20

## 愿景

成为 nextPas 最可信的 L1 同步词汇表：契约与代码一致、测试可证明、与 `platform.sync` 边界清晰、下游可安全依赖。

---

## Done

- [x] 门面 + 十种原语 + platform.sync 路径
- [x] INativeMutex / per-pool TLS / pool IMutex 冷路径
- [x] 文档 SSOT + source-contract + stress 边界
- [x] Windows + Darwin + FreeBSD forced compile gate
- [x] SCORECARD SC1–SC10（含 2T contended wall ns/op）
- [x] Destroy 持锁策略文档化
- [x] path-limited land 到 origin/main（多批）

---

## Now

- [ ] 本批 path-limited landing（FreeBSD gate + bench contended + docs）

---

## Next

1. 销毁持锁可检测路径（仅在有跨平台语义后）
2. 更稳的 contended bench（更多 sample / 排除噪声）
3. 公开 `RecursiveMutex` / 门面化 Pool — **默认暂缓**（见 SCORECARD 决策表）

---

## Deferred

- Channel / Latch / Notify
- 公开 API 重命名（`Do_`）— **冻结**
- FPC `SyncObjs` 兼容层 — **禁止**

---

## 非目标

- 拥有 platform ABI 细节
- 替代 `async` 事件循环内同步原语
