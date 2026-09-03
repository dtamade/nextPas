# nextpas.core.wallet 独立不变量 CONTRACT（E1 已独立 Owner=wallet lane）

**模块路径**：`core/src/nextpas.core.wallet.base.pas` + `core/src/nextpas.core.wallet.intf.pas` + `core/src/nextpas.core.wallet.impl.pas`（四件套 wallet.base←wallet.intf←wallet.impl←wallet 已独立，Owner=wallet lane 单源承载事务/过期/Migrations，见 §0）+ `core/src/nextpas.core.wallet.pas`（独立门面 inline 薄转发至 wallet.impl 单源，纯聚合）+ 兼容薄别名已物理删除(2026-09-02)：`core/src/nextpas.core.db.wallet.pas` / `billing.wallet.pas` / `db.wallet.impl.pas` 均已物理删除，文件已移除，不再计入 src 模块清单，统一使用 `nextpas.core.wallet`（可裁剪性债务已闭环）
**可抽新模块候选（已独立·物理已迁）**：本 CONTRACT 已满足四件套 `wallet.base←wallet.intf←wallet.impl←wallet` 纯聚合与编译期 `{$IF IDENTITY_USER_PROFILES_TABLE}` + 运行时 `WalletRequireIdentityReady` 双重守卫零漂移，**已独立为 `nextpas.core.wallet`（L3，Owner=wallet lane，L3 业务独立）**；通用 billing 已独立为 `nextpas.core.billing`（L3，Owner=billing lane，四件套 billing.base←billing.intf←billing.impl←billing 已落地，独立于 wallet，L0-L2 严格单向，bytes.ops 单源 inline/零拷贝，见 billing 家族）；类型/接口单源 `nextpas.core.wallet.base/intf`，物理实现已迁至 `nextpas.core.wallet.impl` 单一事实源（原寄生 `db.wallet.impl` 已物理删除 2026-09-02），兼容薄别名已物理删除(2026-09-02)（原 `db.wallet`/`billing.wallet` 薄别名已移除，文件已移除，不再计入 src 模块清单，见 `db/CONTRACT.md §1`），复用 wallet 不再捆绑 db 家族全量（可裁剪 wallet 单选），业务以 CONTRACT 为准，缺能力先反哺 owner（`wallet` → L2 infra `db.pool`/`db.migrate` 严格向下 + `bytes.ops`/`text.*`，身份域能力→`nextpas.core.identity` 已落地 L2，`IdentityMakeMigrations v14` 单源，`Trim`/`iso8601`/`bytes.ops` 文本/时间/字节独立单源闭环；历史 L3→L3 受控例外已随 infra 下沉消除）。**统一编排已闭合**：`WalletFullMigrations`（v14+v15 单源有序）与 `WalletMigrateAll(AConn/APool)` 已落地，手序易错闭合；DM 真机端到端已納入回归门禁（`bench_db_adapter_overhead` DM 段 env-gated `dpi_execute`），sqlite file-backed 612ms/3286 ops/s 见 benchmarks。
**层级**：L3 业务（Owner=wallet lane 独立；依赖 L0-L2 严格单向，`db.pool`/`db.migrate` 为 L2 基础设施无同层耦合，历史受控例外已随 infra 下沉消除见 `db/CONTRACT §1/§2.22`；不另建平行存储，99% 复用池/迁移/词法/时间单源）
**最后更新**：2026-09-01（E1 wallet 账本域候选单立，补身份域前置依赖序与统一编排 `WalletMigrateAll`；身份域 `nextpas.core.identity` v14 落地，反哺闭环）
**版本**：1.2（寄生 `db/CONTRACT.md §2.22` → 独立 CONTRACT 单源；`wallet/CONTRACT.md` 为真相，`db/CONTRACT.md §2.22` 仅薄索引；身份域由占位 stub 升格为独立模块 `nextpas.core.identity`；统一编排 `WalletMigrateAll` 落地，手序闭合）

---

## 0. 抽离边界（已独立）

| 维度 | 已独立现状 | 兼容与演进 |
|---|---|---|
| Owner | `nextpas.core.wallet` 为单一事实源（wallet lane 独立；四件套 wallet.base←wallet.intf←wallet.impl←wallet 已落地，类型/接口单源 wallet.base/intf，纯聚合；唯一真相见本节） | 兼容别名已物理删除(2026-09-02)：`nextpas.core.db.wallet` / `billing.wallet` / `db.wallet.impl` 均已物理删除，文件已移除，不再计入 src 模块清单，原 `db.wallet` Owner 已结束，统一使用 `nextpas.core.wallet` |
| 依赖 | `db.pool`/`db.migrate`(L2 基础设施，统一编排 `WalletMigrateAll` 已落地)`/bytes.ops`/`text.kv|sqlscan|builder|conv`/`time|iso8601`/`id.uuid` | L0-L2 严格单向（pool/migrate 已下沉 L2，无 L3→L3），物理已迁至 `wallet.impl`，复用 wallet 不再捆绑 db 家族全量（见 `db/CONTRACT §1/§2.22`） |
| 门面 | `nextpas.core.wallet` 单一真源（兼容别名已物理删除 2026-09-02，`db.wallet`/`billing.wallet`/`db.wallet.impl` 均已物理删除，文件已移除，不再计入 src 模块清单，统一使用 `nextpas.core.wallet`；通用 billing 请用 `nextpas.core.billing` 独立家族，物理 wallet.impl 单源） | 已物理删除：兼容别名均已移除，文件已移除，不再计入 src 模块清单，选型分裂与三级链式已消除，物理单源统一为 `nextpas.core.wallet`；通用 billing 已独立为 `nextpas.core.billing`（L3，Owner=billing lane）并缺能力先反哺 owner；双源索引漂移防护：`wallet/CONTRACT.md` 为唯一真相，`db/CONTRACT.md §2.22` 仅薄索引 |
| 身份域 | 外键 `user_profiles(id)` 由已落地 `nextpas.core.identity` 提供（`IdentityMakeMigrations v14`，`identity/CONTRACT.md`） | 独立后仍以前置迁移依赖序 `v14→v15` 保障 FK，不在 wallet 内伪造身份表；`WalletMigrateAll`/`WalletFullMigrations` 单源编排已闭合 |

> **四件套守则**：wallet 域遵循 `nextpas.core.wallet(.base/.intf/.wallet.impl/.wallet)` 独立四件套范式（已落地 `wallet.base` 记录类型、`wallet.intf` 身份/成员抽象、`wallet.impl` 单源实现、`wallet` 门面 inline 薄转发纯聚合，物理已迁至 wallet.impl）；兼容层 `nextpas.core.db.wallet` / `billing.wallet` / `db.wallet.impl` 已物理删除(2026-09-02)，文件已移除，不再计入 src 模块清单，统一使用 `nextpas.core.wallet`（物理 wallet.impl 单源）；身份域 `nextpas.core.identity.base` 为 L0 常量单源，wallet FK 经 `IDENTITY_USER_PROFILES_TABLE` 构造，零硬编码漂移。依赖单向 base←intf←impl←facade 且 L0-L2 严格向下（`db.pool`/`db.migrate` 已下沉 L2，无 L3→L3，历史受控例外已消除），可裁剪（门面零拖六后端工厂）；见 `db/CONTRACT §1/§2.22` 与 `design-conventions.md` 层级纯度。

---

## 1. 前置依赖序（身份域不变量候选）

**不变量**：`wallet_balances(user_id PK→user_profiles(id) ON DELETE CASCADE)` 等三表均 FK 指向身份域候选 `nextpas.core.identity` 的 `user_profiles(id)`。

- **迁移清单声明**：`WalletMakeMigrations v15` 仅产 wallet 四表 DDL（`wallet_balances`/`wallet_ledger`/`redeem_codes`/`redeem_redemptions` + `idx_wallet_ledger_user`），不含 `user_profiles` 定义；**部署序 = 身份域迁移先行 → wallet 迁移**，否则 `FOREIGN KEY` 指向缺失在 `FOREIGN_KEYS=ON` 时 fail-closed；**运行时守卫**：`WalletRequireIdentityReady/WalletIsIdentityReady` 在 Writer 事务与读路径入口探针 `user_profiles` 是否已迁移，即使 `FOREIGN_KEYS=OFF` 亦 fail-closed 抛 `decConstraint/dckForeignKey`，编译期 `{$IF IDENTITY_USER_PROFILES_TABLE<>'user_profiles'}` 互证零漂移 + 运行时双重守卫。**统一编排复用入口**：`WalletFullMigrations`（`Identity v14 + Wallet v15` 单源有序数组）与 `WalletMigrateAll(AConn/APool)` 已落地（`nextpas.core.wallet.impl` 单源，`Migrate` 经 `db.migrate` CRC32 单源，幂等/校验单源；`db.wallet.impl` 已物理删除），调用方直接 `Migrate(WalletFullMigrations)` 或 `WalletMigrateAll(Conn|Pool)` 单次完成两段，无需手序 v14→v15，手序易错闭合；生产/测试均可走此入口，幂等追加。
- **能力矩阵声明**：见 `core/docs/db/CONTRACT.md §2.10` 正交声明——wallet 业务不新增 `Supports*` 能力位；存储/事务能力由 `db.pool`/`db.migrate` 既有面透传，缺口先反哺 owner（余额原子性→`db` 事务原语，时间→`nextpas.core.time`，词法→`text.kv|sqlscan|builder`，身份→`nextpas.core.identity`）。
- **测试保障（落地后，统一编排已闭合）**：离线/真机均以 `FOREIGN_KEYS=ON` 经 `WalletMigrateAll` 或 `Migrate(WalletFullMigrations)` 单次完成 `Identity v14 → Wallet v15` 有序幂等（亦可显式 `Migrate(IdentityMakeMigrations) → Migrate(WalletMakeMigrations)` 手序等价）；`user_profiles(id TEXT PRIMARY KEY)` 真表由 `nextpas.core.identity` 单源提供（`Trim`/`iso8601` 文本/时间独立单源，`bytes.ops` 零拷贝）；生产环境同此单入口幂等追加，离线 stub 仅作 `FOREIGN_KEYS` 语义回退验证，不作长期真相。配套门禁 `test_wallet`（`core/tests/nextpas.core.wallet/test_wallet` 分治单源，db 族零拖业务域）双路径（手序与编排入口）全绿。
- **已落地身份域**：`nextpas.core.identity`（L2 能力域，Owner = identity lane）已落地，拥有 `user_profiles` 最小不变量（`id PK TEXT` + `created_at/updated_at iso8601` 生命周期，`IdentityMakeMigrations v14` 单源），详 `core/docs/identity/CONTRACT.md`；wallet 仅消费 FK，不拥有身份写入面；文本 `Trim` 经 `nextpas.core.text.utils` inline 零拷贝、时间 `NowUtc/ToUnixNanos` 经 `nextpas.core.time` 单源、`StringToBytes` 经 `nextpas.core.bytes.ops` 单 Move 零拷贝，复用依赖已落地，满足“独立 text/time 单源基准”审计。
- **实现侧接口抽象**：`nextpas.core.wallet.intf` 单源提供 `IWalletIdentity`（`UserExists`）与 `IWalletMembership`（`IsMember/Join` 跨域注入，wallet 不拥有 `project_members`，单 Owner 单表边界；`nextpas.core.db.wallet.intf` 已物理删除）及 `nextpas.core.identity.base` 常量/版本单源（`IDENTITY_MIGRATION_VERSION=14`），wallet 实现侧经接口探针/常量构造 FK，不硬编码非本域 SQL；`WalletMakeMigrations` 经 `{$IF IDENTITY_USER_PROFILES_TABLE<>'user_profiles'}` 编译期互证零漂移；`WalletWithWriterTxn` 事务样板收敛三处 Writer 零重复，`WalletListLedger` 游标经 `text.builder` 单分配 + 指数倍增摊还 O(1) 零 `Count+16` 线性复制。

---

## 2. 表契约（WalletMakeMigrations v15 单源）

| 表 | 不变量 |
|---|---|
| `wallet_balances(user_id PK→user_profiles(id), balance_cents≥0, updated_at iso8601)` | `balance_cents CHECK ≥0`；`user_id PK` 级联 `ON DELETE CASCADE`；**前置依赖**见 §1；更新经 `UPDATE … SET balance_cents=balance_cents+? WHERE balance_cents+?≥0 RETURNING` 原子守卫，非负违例 fail-closed `insufficient balance` |
| `wallet_ledger(id PK uuidv7, user_id FK→user_profiles, delta_cents, reason, ref_id, created_at iso8601)` | Append-only 账本；`id` 主键防重复写入；`idx_wallet_ledger_user(user_id, created_at desc, id desc)` 支撑游标分页；`user_id FK→user_profiles` 同 §1 前置序 |
| `redeem_codes(code PK, total_cents>0, remaining_uses≥0, max_uses>0, expires_at? iso8601, created_at)` | `total_cents>0`/`max_uses>0` 约束；`remaining_uses` 递减守卫 `WHERE remaining_uses>0`；重码报 `duplicate code`（捕获 `UNIQUE` 归一 `decConstraint/dckUnique`） |
| `redeem_redemptions(code FK, user_id FK, PK(code,user_id))` | 复合主键幂等：同一用户对同一兑换码仅一次兑现，重复 `already redeemed` fail-fast；双 FK 分别指向 `redeem_codes` 与 `user_profiles`，后者同 §1 前置序 |

> DDL 单源：`WalletMakeMigrations` 内四 `CREATE TABLE IF NOT EXISTS` + 一索引，checksum 经 `db.migrate` CRC32 八位小写十六进制，防篡改与 dry-run 同 §2.4 契约。

---

## 3. 原子不变量（单 Writer 事务内，复用 `db.pool` Writer + `db.tx` 计数面）

- **余额变更**：`WalletAdjustBalance` = `INSERT OR IGNORE balances` (幂等建户) → `UPDATE … +delta WHERE …+delta≥0 RETURNING` (原子扣减/充值) → `INSERT ledger` → `Commit`；任一步失败 `Rollback`，连接归还不丢（`IDbTxControl` depth 簿记，接口引用计数自动归还）。
- **核销**：`WalletTryRedeem` = 查重 `redeem_redemptions` → 读 `redeem_codes` 并校验 `remaining_uses>0` + `expires_at`（`TryParseISO8601DateTimeOffset/Time` 双形态，过期或非法判 `expired`，`NowUtc` 单源）→ `UPDATE remaining_uses-1 WHERE >0`（`Changes=1` 钉死防并发超兑）→ `INSERT OR IGNORE balances` → `UPDATE balances +total RETURNING` → `INSERT ledger(reason='redeem')` → `INSERT redemptions` → `Commit`；全程 Writer 独占，失败 `Rollback` 不留半事务。
- **过期**：`expires_at` 空串 = 永不过期；非空须为 ISO8601（`TryParse…` 双重载），过去时 `expired` fail-fast；文本比对不做时区歧义，统一转 `ToUnixNanos` 单源比较（`nextpas.core.time`）。
- **扣减并入组**：`WalletTryDeductAndJoin` = （可选成员面）`IWalletMembership.IsMember` 查重（已成员即幂等返回现余额，不二次扣减，成员面由调用方注入，wallet 不拥有 `project_members`）→ `INSERT OR IGNORE balances` → `UPDATE balances -price WHERE balance≥price RETURNING`（余额不足 fail-closed）→ `INSERT ledger(reason='project_join')` → （可选）`IWalletMembership.Join` → `Commit`；无成员面注入时仅做扣减+账本，单 Owner 单表边界（project_members 归属非 wallet，见 `wallet.intf`）；已成员分支 `Commit` 后提前返回，租约语句边界归还。通用 Writer 事务经 `WalletWithWriterTxn` 收敛，零重复样板。

---

## 4. 分页/幂等/资源

- `WalletListLedger(After, Limit)` 稳定游标：`ORDER BY created_at DESC, id DESC LIMIT ?`，`After` 以单行值 `(created_at,id) < (SELECT created_at,id WHERE id=?2 AND user_id=?1)` 相关子查询内联（由三重复 `created_at<?`/`created_at=? AND id<?` 简化为单行值比较 + `IS NULL` 回退，解析/执行开销减半）单往返完成（无额外点查，`IS NULL` 回退首尾页），预分配 `ALimit`（1..100）零指数扩容拷贝（`text.builder` 单分配零拷贝 Move，`?N→?+槽位` 复用）；空 `user_id`/`Limit<1` 零查询返回空数组（无值用空数组表达）。性能：游标分页 1 RTT 替代 2 RTT，延迟减半；行值单查询 + 预分配较 16 起步指数扩容减少 3 次拷贝。
- `WalletGetBalance/FindRedeemCode` 只读 `Pool.Acquire` 短租约，`Step` 后即释放，接口引用计数自动归还，不滞留 Writer 槽位。
- 所有入口 `Pool.Acquire/Writer` 返回接口句柄，消费方不手写 Free；事务内 `try..except try Rollback except end; raise` 硬边界，句柄/语句析构不丢（`dpi_free_*`/`FreeExecutionState` 析构链对齐，`db.pool` 排空语义）。

---

## 5. 性能契约（inline/零拷贝证据）

- **薄转发**：`nextpas.core.wallet` 为唯一真源纯聚合，全入口 `inline` 薄转发至 `wallet.impl` 单源（物理 wallet.impl 单源，bytes.ops 单源；兼容别名 `db.wallet` / `billing.wallet` / `db.wallet.impl` 已物理删除 2026-09-02，文件已移除，不再计入 src 模块清单）；`WalletMakeMigrations` 常量抽离非 inline（`WALLET_DDL_*` 五常量，避 I-Cache 复制膨胀，`design-conventions §inline 红线`），`WalletFullMigrations`/`WalletMigrateAll` 为 `inline` 薄包装（单次 `Migrate` 委托零额外逻辑，无额外分配）。
- **零拷贝单源**：`StringToBytes` 单 `Move` 经 `nextpas.core.bytes.ops` 单源（`BYTES_OPS_SINGLE_SOURCE` 编译期守卫零漂移），`Trim/IntToStr` 经 `nextpas.core.text.utils|conv` 单源，`text.builder` IStringBuilder 单遍追加，`text.kv|sqlscan` 单遍状态机 `O(n)` 零额外 `TextBuilder`（见 `core/docs/db/CONTRACT.md §2.20/L1 真源` 与 `benchmarks.md §bench_text_kv 739–1131 MB/s`）。
- **避免膨胀**：真实 IO/循环体（`GetBalance/FindRedeemCode`）与 `WalletMakeMigrations` 不 inline 避 I-Cache 复制膨胀；`WalletListLedger` 游标拼接仅一次 `text.builder` 分配 + 预分配 `ALimit` 零额外拷贝（较 16 起步指数扩容减少 3 次 SetLength 拷贝），行值单查询较三重复解析减半。
- **定量基准**：`bench_db_wallet`（`core/benchmarks/nextpas.core.db`）单源量化 Adjust/Redeem/ListLedger 热路径（sqlite file-backed `PRAGMA foreign_keys=ON`，`Writer` 单写者事务，见 `core/docs/db/benchmarks.md §bench_db_wallet`：adjust 2000 612 ms 3,268 ops/s / redeem 1000 487 ms 2,053 ops/s / list_ledger 2000 284 ms 7,042 ops/s，2026-09-01 在册）；DM/MySQL 真机端到端 `NEXTPAS_DM_TEST_CONN`/`NEXTPAS_MYSQL_TEST_CONN` env-gated honest skip（`bench_db_adapter_overhead` DM 段 + `bench_db_wallet` pg/dm 段待 live 补采，不以 `text.kv 739–1131 MB/s` 或 `Translate` 微基准冒充事务链吞吐）；防回归以同机同口径复跑为准。

---

## 6. 稳定性契约（资源释放不丢）

- Writer 单写者事务 + 接口引用计数自动归还，`try..except Rollback` 不丢连接，`Q:=nil` 断句柄防滞留。
- 迁移幂等：`MakeMigrations`/`Migrate` 经 `db.migrate` 幂等/版本/checksum 承载，重复调用零副作用。
- 外键级联：`ON DELETE CASCADE` 由 SQLite 外键执行，`FOREIGN_KEYS=ON` 时身份删除自动清理余额/账本/兑现记录，无孤儿行；**运行期每连接 `PRAGMA foreign_keys=ON` 由 `wallet.impl` per-conn 防御式设置（`WalletEnsureForeignKeysOn` inline 单 Exec 零拷贝，仅 `dbkSqlite`，`pg` 等天生强约束不触发），默认 `OFF` 时亦 fail-closed 零孤儿，部署序 `identity v14 → wallet v15` 与运行期开关互补（见 §1）。

---

## 7. 能力反哺 Owner 声明

- wallet 业务不新增 `IDbCapabilities` 位（正交于 `db/CONTRACT.md §2.10`）；存储依赖透传 `db.pool`/`db.migrate` 既有面。
- 缺能力先反哺 owner：余额原子性→`db` 事务原语缺口反哺 `nextpas.core.db`；时间→`nextpas.core.time`；词法→`text.*`；身份→`nextpas.core.identity`；不在 wallet 内另建平行存储/平行词法/平行时间解析。

---

## 8. 门禁

```bash
make focused FOCUS=core/tests/nextpas.core.wallet/test_wallet     # wallet 专属离线门禁：FK 前置 + Changes 原子 + heaptrc 0（本 gate，分治后单源于 wallet 模块，db 族零拖业务域）
#  - FK 前置依赖：WalletMigrateAll / WalletFullMigrations 统一编排（v14→v15 有序，Migrate 单源）+ 手序双路径验证，FOREIGN_KEYS=ON 真表
#  - 文本/时间独立单源：Trim via text.utils inline 零拷贝 / iso8601 via time / StringToBytes via bytes.ops 单 Move 零拷贝
#  - 原子性：核销 UPDATE … WHERE remaining_uses>0 后 Changes=1 钉死防超兑，余额非负 fail-closed
#  - 游标分页稳定序 + 资源释放不丢（heaptrc 0）
make focused FOCUS=core/tests/nextpas.core.db/test_db_unified   # 统一层 + heaptrc 0（通用面，不显式覆 FK/Changes）
```

每个 gate 含 `heaptrc 0 unfreed` 硬门禁；真机段沿用 `db` 既有 `NEXTPAS_*_TEST_CONN` 门控惯例，缺席 Skip。

---

## 9. 关联

- 前置身份域：`core/docs/identity/CONTRACT.md`（`nextpas.core.identity` v14，已落地，文本/时间/字节独立单源，`IdentityMakeMigrations` 单源）
- 家族总纲：`core/docs/db/CONTRACT.md §2.22`（本文件为单立真相，彼为薄索引）
- 门面：`core/src/nextpas.core.wallet.pas` 单一真源（兼容薄别名 `billing.wallet` / `db.wallet` / `db.wallet.impl` 已物理删除 2026-09-02，文件已移除，不再计入 src 模块清单，统一使用 `nextpas.core.wallet`；物理 wallet.impl 单源，bytes.ops 单源）
- 实现：`core/src/nextpas.core.identity.pas`（v14 真表）与 `core/src/nextpas.core.wallet.impl.pas`（v15 业务单源，`IDENTITY_*` 编译期校验）+ 兼容薄别名已物理删除，不再计入 src 模块清单
- 路线图：`core/docs/db/ROADMAP_FINAL_20260828.md`，`core/docs/plans/2026-08-23-db-v3-industrial-roadmap.md`
