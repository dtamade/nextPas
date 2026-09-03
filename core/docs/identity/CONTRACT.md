# nextpas.core.identity 独立不变量 CONTRACT（wallet 前置依赖落地）

**模块路径**：`core/src/nextpas.core.identity.pas`（L2 能力域，Owner = identity lane；常量单源 `core/src/nextpas.core.identity.base.pas`，`IDENTITY_MIGRATION_VERSION=14`）
**层级**：L2（依赖 L0-L1；钱包 L3 单向依赖本域，不循环）
**最后更新**：2026-09-01（wallet FK 前置依赖落地，反哺闭环）
**版本**：1.0（wallet 占位 stub → 独立模块落地；`user_profiles` 单源 `IdentityMakeMigrations v14`）

---

## 0. 模块定位与抽离边界

| 维度 | 现状 | 契约 |
|---|---|---|
| Owner | `nextpas.core.identity` 独立 Owner（L2 能力域） | 拥有 `user_profiles` 最小不变量主权，wallet 仅消费 FK |
| 依赖 | `text.utils`/`time`/`bytes.ops`/`db.migrate`（零平行实现） | 只向下依赖，复用 `text.*`/`time`/`bytes.ops` 单源，不另建存储/词法/时间 |
| 表 | `user_profiles(id PK)` 单表 | `id TEXT PRIMARY KEY` + `created_at/updated_at iso8601` 生命周期，ON DELETE CASCADE 由 wallet 消费方执行 |
| 四件套 | `identity.base`（常量/版本）← `identity`（实现+门面最小形态） | 不机械建空 `intf/ffi`；实现侧 `base←impl←facade` 单向，门面 inline 薄转发 |
| 迁移 | `IdentityMakeMigrations v14` 单源 | wallet `v15` 前置依赖本迁移，部署序 v14→v15，checksum 经 `db.migrate` CRC32 单源 |

> **单源声明**：`IdentityMakeMigrations` 为 `user_profiles` DDL 唯一事实源；`wallet` 经 `IDENTITY_USER_PROFILES_TABLE/IDENTITY_MIGRATION_VERSION` 常量与 `{$IF}` 编译期互证零漂移。

---

## 1. 表契约（IdentityMakeMigrations v14 单源）

| 表 | 不变量 |
|---|---|
| `user_profiles(id PK TEXT, display_name TEXT, created_at iso8601, updated_at iso8601)` | `id` 主键，`display_name` 可空；`created_at/updated_at` 默认 `strftime('%Y-%m-%dT%H:%M:%fZ','now')`；主键级联由 `wallet_*` 外键 `ON DELETE CASCADE` 消费，身份删除自动清理关联余额/账本/兑现记录，无孤儿行 |

> DDL 单源：`IdentityMakeMigrations` 内 `CREATE TABLE IF NOT EXISTS user_profiles (...)`，checksum 经 `db.migrate` CRC32 八位小写十六进制，防篡改与 dry-run 同 `db/CONTRACT.md §2.4` 契约。

---

## 2. 文本/时间独立单源基准（复用依赖已落地）

- **文本**：`IdentityNormalizeId/IsValidId` 归一化经 `nextpas.core.text.utils.Trim` inline 单源；无修剪时原串共享零拷贝，有修剪时单次 `Copy` 单遍扫描 `O(n)`；不自建 `text.kv/sqlscan` 状态机，词法复用 `text.*` 单源。
- **时间**：`IdentityNowIso8601` 经 `nextpas.core.time` `TOffsetDateTime.NowUtc` 单源（`platform_monotonic_ns`），序列化 `ToISO8601` 走 `nextpas.core.time.iso8601` 单源；过期/比较统一 `ToUnixNanos` 单路径，时区无歧义，wallet 同源复用。
- **字节**：`IdentityIdToBytes` 经 `nextpas.core.bytes.ops.StringToBytes` 单 `Move` 零拷贝，`BYTES_OPS_SINGLE_SOURCE` 编译期守卫零漂移；先 `Trim` 再单 `Move`，避免含空白的身份键污染存储。
- **迁移**：`IdentityMakeMigrations` inline 零额外分配（`MakeMigrations` 经 `db.migrate` 单源），与 wallet `WalletMakeMigrations v15` 正交，部署序保障 FK 不在 `FOREIGN_KEYS=ON` 时 fail-closed。

---

## 3. 迁移与部署序

- **版本**：`IDENTITY_MIGRATION_VERSION = 14`（L2），wallet `WALLET_MIGRATION_VERSION = 15`（L3）；`14 < 15` 单调递增，部署序 `identity → wallet` 强制。
- **幂等**：`Migrate(IdentityMakeMigrations)` 与 `Migrate(WalletMakeMigrations)` 各自幂等/版本/checksum 承载，重复调用零副作用；wallet 前置依赖失败时 `FOREIGN_KEYS=ON` fail-closed，不静默建孤儿表。
- **测试**：离线/真机 `Migrate(IdentityMakeMigrations) → Migrate(WalletMakeMigrations)` 两段式；旧 stub 仅作 `FOREIGN_KEYS` 语义回退验证，不作长期真相。

---

## 4. 性能契约（inline/零拷贝证据）

- **薄转发**：`IdentityMakeMigrations/NormalizeId/IsValidId/IdToBytes/NowIso8601` 全 `inline`，无额外分配；热点 `Trim` 单次分配缓存（无修剪原串共享零拷贝）。
- **零拷贝单源**：`StringToBytes` 单 `Move` 经 `nextpas.core.bytes.ops` 单源（`BYTES_OPS_SINGLE_SOURCE` 守卫），`Trim` 经 `nextpas.core.text.utils` 单源，`time` 经 `nextpas.core.time` 单源，`text.builder` 未用（无 SQL 拼接），`text.kv/sqlscan` 未重建状态机。
- **避免膨胀**：本域无重 IO/循环体，迁移清单纯构造 inline 安全；若扩展 DB 读写则真实 IO 体不 inline 避 I-Cache 复制膨胀（沿 wallet 同纪律）。

---

## 5. 稳定性契约（资源释放不丢）

- 迁移幂等经 `db.migrate` 承载，重复调用零副作用；`ON DELETE CASCADE` 由 SQLite 外键执行，无孤儿行。
- 未来 DB 读写若落地，沿 `Pool.Acquire/Writer` 接口句柄 + `try..finally Q:=nil; Conn:=nil` 语句边界归还（B13），`try..except try Rollback except end; raise` 硬边界不丢连接，接口引用计数自动归还。

---

## 6. 能力反哺 Owner 声明

- 身份域不新增 `IDbCapabilities` 位（复用 `db.pool`/`db.migrate` 既有面）；文本/时间缺口反哺 `nextpas.core.text`/`nextpas.core.time`，字节缺口反哺 `nextpas.core.bytes.ops`，不在本域内另建平行词法/时间/字节实现。
- wallet 余额原子性→`db` 事务原语缺口反哺 `nextpas.core.db`；身份生命周期→本域。

---

## 7. 门禁

```bash
make focused FOCUS=core/tests/nextpas.core.db/test_db_unified   # 统一层 + heaptrc 0，含 identity→wallet 部署序
make focused FOCUS=core/tests/nextpas.core.wallet/test_wallet     # wallet 分治后单源（见 wallet/CONTRACT.md），db 族零拖业务域
make focused FOCUS=core/tests/nextpas.core.identity/test_identity # identity 专属离线门禁：v14 单表 + 文本/时间/字节单源 + heaptrc 0（分治后单源于 identity 模块，L2 零拖 wallet）
# 身份域离线门禁（wallet 共享 gate 已分治，identity 单源见本模块）
#  - FK 前置依赖：Migrate(IdentityMakeMigrations v14) → Migrate(WalletMakeMigrations v15)，FOREIGN_KEYS=ON
#  - 文本/时间独立单源：Trim via text.utils / iso8601 via time / StringToBytes via bytes.ops 单 Move 零拷贝
#  - 资源释放不丢（heaptrc 0）
```

每个 gate 含 `heaptrc 0 unfreed` 硬门禁；真机段沿用 `db` 既有 `NEXTPAS_*_TEST_CONN` 门控惯例，缺席 Skip。

---

## 8. 关联

- 消费方：`core/docs/db/wallet/CONTRACT.md §1` 前置依赖序（本域为前置真源，wallet 仅消费 FK）
- 家族总纲：`core/docs/db/CONTRACT.md §2.22` wallet 域（含本域前置声明）
- 实现：`core/src/nextpas.core.identity.pas`（inline/零拷贝单源），常量：`core/src/nextpas.core.identity.base.pas`
