# db stage-review  remediation 计划 — 2026-09-01

> 来源：`stage-review nextpas.core.db` 12m39s 完成，10 项 confirmed（P0 3 代码 + P1 7 文档漂移）。本文为双切片并行收口计划，worktree 隔离执行。

## 目标

- P0 资金/并发硬伤清零：wallet 超兑与时间比较、pool 双重出借
- P1 文档与实现再对齐：DM DPI 六后端全链路（CONTRACT/README/national-guide/benchmarks/ROADMAP/门禁）

## 切片

### Slice A — P0 热修（最高优先）

| 项 | 文件 | 修复 | 验收 |
|---|---|---|---|
| A1 | `core/src/nextpas.core.db.wallet.pas:224-228` | `UPDATE redeem_codes SET remaining_uses=remaining_uses-1 WHERE code=?1 AND remaining_uses>0` 后校验 `Conn.Changes = 1` 否则抛 `exhausted`（并发超兑闭环，事务内原子校验） | `WalletTryRedeem` 并发回归 + `test_db_* heaptrc0` |
| A2 | `core/src/nextpas.core.db.wallet.pas:222 / 150-173` | 过期用 `TryParseISO8601DateTimeOffset` 解析 `Rc.ExpiresAt` 与 `DateTimeUtcNow` 比较；`WalletCreateRedeemCode` 对 `AExpiresAt<>''` 做同型校验，非法 fail-fast | 单测覆盖含分数秒 `...T%H:%M:%fZ` 与空串 |
| A3 | `core/src/nextpas.core.db.pool.pas:587-610` | `ReturnProxy` 区分读写：仅读租约 `IdlePush`，写租约不入 `FIdle`（`FWriterConn` 单例复用），消除同一 `IDbConnection` 双重出借 | `test_db_pool_v2` 8T×3000 + writer 竞争不变式 `opens=4` |

依赖：A 独立于 B，可并行。

### Slice B — P1 文档收口（六后端对齐）

| 项 | 文件 | 动作 |
|---|---|---|
| B1 | `core/docs/db/CONTRACT.md` | 头注 `Last updated 2026-09-01 / v1.3`；§1 家族布局补 `mysql/odbc/redis/dm/bulk/factory/async/listen/subscribe/sqlscan`；新增 §2.21 DM DPI 原生契约（能力/Savepoints/Bulk）；§2.10 能力矩阵加 dm 列；§2.14 “内建五驱动”→六驱动；§5 门禁追加 `test_db_dm_adapter` + `NEXTPAS_DM_TEST_CONN` |
| B2 | `core/docs/db/README.md` | 特性矩阵加 dm 列，统一入口文案“五驱动”→六驱动，`DbOpen('dm',…)` 示例 |
| B3 | `core/docs/db/national-db-guide.md` | §1 决策表达梦行改为双路径（P1 ODBC / P2 DPI 原生，Savepoints 差异成文），§2.4 已含双路径保持与 CONTRACT §2.21 互证 |
| B4 | `core/docs/db/benchmarks.md` | 新增 dm DPI 口径行（translate/batch 零分配沿用 text.kv，诚实缺席登记） |
| B5 | `core/docs/db/ROADMAP_FINAL_20260828.md` | 增补 §2 增补说明：2026-08-30 DM DPI 为 R1-R5 递延后的独立增量，非封版内，版本 bump 至 1.3，不推翻 20260828 裁定 |

## 验收门

- `make hygiene` pass + `git diff --check` 0
- `make focused FOCUS=core/tests/nextpas.core.db/test_db_pool_v2` / `test_db_unified` heaptrc0
- 文档 `grep` 校验：`内建五驱动` 0 命中，能力矩阵列数 6 对齐

## 风险

- wallet 时间解析引入 `nextpas.core.time.iso8601` 依赖为 L0→L3 允许方向，零回退
- pool 改法缩小语义（写不回池），回退单写复用不变，需压测验证
