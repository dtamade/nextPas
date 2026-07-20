# nextpas.core.sync 契约索引

> **权威契约**：[`core/docs/sync/CONTRACT.md`](../../core/docs/sync/CONTRACT.md)
> **模块入口**：[`core/docs/sync/README.md`](../../core/docs/sync/README.md)
> **目标树**：[`core/docs/sync/GOAL_TREE.md`](../../core/docs/sync/GOAL_TREE.md)

本文件仅作仓库级 `docs/contracts/` 入口，**不**维护第二套 API 签名或语义描述。
任何接口、错误语义、线程安全不变量的变更必须先改 `core/docs/sync/CONTRACT.md`，并同步行为 / source-contract 测试。

---

## 一句话

L1 同步原语门面：Mutex、FutexMutex、RWLock、SpinLock、WaitGroup、CondVar、Once、Semaphore、Barrier、Event；实验旁路 `TSyncPool`（未进门面）。

## 测试

```bash
make -C core/tests/nextpas.core.sync test
```

## 依赖边界

- 依赖：`nextpas.core.platform.sync`（宿主原语）、`nextpas.core.atomic`（用户态无锁路径）
- 被依赖：http、tls、thread、test.runner、collections.concurrent、net 等

## 变更记录

| 日期 | 变更 |
|------|------|
| 2026-07-04 | 初始（含已过时的方法名描述） |
| 2026-07-20 | 收敛为薄索引；权威迁至 `core/docs/sync/CONTRACT.md` |
