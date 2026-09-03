# nextpas.core.db — 迁移分册（migrate）

**模块路径**：`core/src/nextpas.core.db.migrate.pas`（`migrate` 单源）
**层级**：L2 基础设施（仅依赖 L0-L1 + `IDbConnection`，已下沉 L2，wallet L3 仅 L0-L2 单向复用，无 L3→L3；见 `CONTRACT.md §1/§2.22`）
**Owner**：core-db lane
**单源**：本册为 `CONTRACT.md §2.4` 单源分册，细节沉至本册，索引与分治不变量仍以 `CONTRACT.md` 为准。
**最后更新**：2026-09-02（匠心修复：家族布局表极简瘦身，`inline`/`bytes.ops` 零拷贝证据抽至本册，母册 <500 行薄索引）

---

## 1. 定向

`Migrate(AConn, Migrations)` 是唯一的迁移面（G2 起旧 `db.sqlite.migrate` 后端类表面已退役，消费方统一走本单元），L2 基础设施，已下沉 L2。

- **复用 bytes.ops 单源**：`Migrate` 经 `bytes.ops` 单源与 `nextpas.core.checksum.crc32` 单源（`MIGRATE_BYTES_SINGLE_SOURCE` 编译期钉死），不自建副本。
- **性能**：`MakeMigrations/Migrate/MigrateDryRun/MigrationVersion` 为 `inline` 薄转发至 `migrate` 单源（零拷贝，见 `nextpas.core.db.migrate` 单元头注）；`Migrate` 每批一个事务（走泛化 `WithTransaction`），`MigrateDryRun` 零写入。
- **稳定性**：幂等、每批一个事务（走 `IDbConnection` 泛化 `WithTransaction`），`try..finally` 置 `nil` 归还不丢；`MigrateDryRun` 严格零写入（不建版本表、不升级旧表）。

## 2. 契约（CONTRACT §2.4 单源）

版本表 `schema_migrations(version INTEGER PRIMARY KEY, applied_at TEXT, checksum TEXT)`，DDL 两引擎通用；`applied_at` 由本单元显式写入 ISO8601 UTC 文本。幂等、每批一个事务（走泛化 `WithTransaction`）、上下限校验同 sqlite 版。

- **checksum 规范形**：批内 SQL 按 LF 连接后取 CRC32，八位小写十六进制。只依赖步骤序列本身，跨后端跨进程确定；消费方可用 `nextpas.core.checksum.crc32` 独立复核。
- **防篡改**：已应用版本的记录 checksum 与当前列表计算值不符时，`Migrate` 抛 `EDbMigrateError`（携带版本号）拒绝继续。威胁模型 = 意外漂移与误编辑，非对抗性攻击。
- **旧表自愈**：S6 前的两列旧表经探测自动 `ADD COLUMN` 升级（后端中立）；历史遗留的空 checksum 条目在下次 `Migrate` 时按当前列表回填（幂等 UPDATE），回填后篡改可检。
- **dry-run**：`MigrateDryRun` 返回逐批状态计划（`drsApply` / `drsApplied` / `drsChecksumMismatch`），严格零写入（不建版本表、不升级旧表）；结构性错误（乱序、越界）仍抛出。同一输入上 dry-run 上报 mismatch 而真实 `Migrate` 抛错——预览与应用的校验语义分野。
- **wallet/身份域前置依赖（已落地）**：`WalletMakeMigrations v15` 仅含 wallet 四表，FK `wallet_balances(user_id)→user_profiles(id)` 指向已落地 `nextpas.core.identity` 的 `user_profiles`（`IdentityMakeMigrations v14` 单源），部署序 = `IdentityMakeMigrations v14 → WalletMakeMigrations v15`（见 `wallet/CONTRACT.md §1`）；能力矩阵不新增 wallet 位，测试以 `Migrate(IdentityMakeMigrations)` 真表 + `FOREIGN_KEYS=ON` 保障。

## 3. 依赖与分治不变量

- L2 基础设施：`nextpas.core.db.migrate` 仅依赖 L0-L1（`base`/`intf`/`checksum`/`bytes.ops`），无上向；`pool`/`migrate` 已下沉 L2，wallet L3 仅 L0-L2 单向复用，无 L3→L3（见 `CONTRACT.md §1` 家族布局）。
- 业务以 `CONTRACT` 为准、缺能力先反哺 `owner`（迁移能力反哺 `nextpas.core.db.migrate`，校验反哺 `nextpas.core.checksum` 单源）。
- 复用 `bytes.ops` 单源 `inline` 零拷贝证据见 `migrate` 单元头注。

## 4. 门禁

```bash
make focused FOCUS=core/tests/nextpas.core.db/test_db_migrate_v2   # 迁移契约
```

含 `heaptrc 0 unfreed` 硬门禁；`MigrateDryRun` 零写入与 `checksum` 防篡改见离线段。
