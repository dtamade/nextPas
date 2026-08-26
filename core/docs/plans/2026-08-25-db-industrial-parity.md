# nextpas.core.db 工业级对标规划（Go database/sql / Rust sqlx 基准）

> 2026-08-25。基线：`2026-08-23-db-v3-industrial-roadmap.md`（V3 主线，
> 大部分已落地）。本文回答两个问题：
> ① 对标 Go/Rust 工业生态，当前模块**还缺什么**（逐能力对照）；
> ② 剩余缺口按什么优先级收口（P0/P1/P2 分片）。
> 状态列以本文为准回填；与 V3 路线图冲突时以本文为准。

---

## 1. 能力对照矩阵（对标系 ↔ 本模块现状）

判据来源：Go `database/sql` + `pgx` v5、Rust `sqlx` 0.8 / `diesel`、
HikariCP、ADO.NET `DbProviderFactory`。✅=已落地有门禁证据；
🟡=部分/降级诚实登记；❌=缺口（进 §2 分片）。

| # | 能力 | Go/Rust 形态 | 本模块 | 状态 |
|---|---|---|---|---|
| 1 | 统一后端抽象 | `driver.Conn` / `Row/QueryRow` | `IDbConnection`/`IDbQuery` + conformance 十套用例 | ✅ |
| 2 | 后端覆盖 | pg/mysql/sqlite/… | sqlite+pg+mysql+odbc(网关)+redis 五族 | ✅ |
| 3 | 注册制驱动入口 | `sql.Open(driver, dsn)`；`sql.Register` | **无**——per-backend 工厂函数各自为政 | ❌ P0-1 |
| 4 | Open 即池 | `*sql.DB` 天生是池；Hikari 池即默认路径 | 池已工业级（V2-S4+C3），但**与统一入口脱节**——消费方手工拼工厂闭包 | ❌ P0-1（组合缝） |
| 5 | 可插拔驱动 | `sql.Register` 第三方注入 | 无注册面 | ❌ P0-1 |
| 6 | 预编译语句缓存 | pgx stmt cache / sqlx prepared | sqlite ✅(1.54×)、pg ✅ G8(2.22×)；mysql/odbc 未见缓存 | 🟡 C2/C4 评估 |
| 7 | 参数级批量绑定 | pgx COPY / `unnest` Array DML | ✅ C2：IDbArrayBinding unnest 路径（pg 10K 行 29ms vs batch 174ms = 6.0×）；其余后端诚实缺席 | ✅ C2 |
| 8 | 事务 + 重试 | sqlx `BeginTxx` + 死锁重试库 | WithTransaction(+Retry) 瞬时段位退避 | ✅ B5 |
| 9 | 连接池硬化 | HikariCP 探活/泄漏检测/寿命 | ValidateOnAcquire/LeakDetection/Lifetime/Idle 全有，15 组门禁 | ✅ C3 |
| 10 | 观测钩子 | otelsql / Hikari metrics | IDbTraceListener 四后端同构 + Hub | ✅ B3 |
| 11 | 错误归一 | pgx pgconn.PgError；MySQL SQLState | Classify{Sqlite,Pg,My,Odbc(+Ex),Redis} 词元/码位表 | ✅ |
| 12 | 查询超时 | context deadline | TDbExecOptions advisory（pg SET 窗口/mysql max_execution_time/odbc QUERY_TIMEOUT/sqlite 忽略）——conformance §12 advisory 全后端复跑 + pg 真机超时 decTimeout 与会话恢复钉死（V3-B2 门禁） | ✅ B2 |
| 13 | 取消 | ctx 取消传播 | ✅ B6：TDbAsyncExecutor 令牌级联 → IDbCancelControl（pg PQcancel / sqlite progress handler），归一 decTimeout；句柄直呼 Cancel 同面；同步模型本身仍无取消（契约明示） | ✅ B6 |
| 14 | LISTEN/NOTIFY | pgx notification | ✅ B7：nextpas.core.db.pg.listen 订阅会话——专用连接独占 + 泵线程投递 + Token（IAsyncCancellationToken）取消 + 断线自动重连重放订阅；at-most-once 如实上报（GapCount/DroppedCount）；投递面偏差（原案 async.channel → 内建有界记录队列）入 CONTRACT §2.18 | ✅ B7 |
| 15 | TLS 一等公民 | sslmode/verify-full | CONTRACT §2.1-TLS 责任表成文（pg conninfo 透传/redis UseTls+TLSDial/odbc connstr/sqlite N/A）+ verify-full 推荐样例；带证书 conformance 冒烟本地无环境未跑（env 门控余项，诚实登记不假装验证） | ✅ B4（文档） |
| 16 | 迁移框架 | sqlx migrate/golang-migrate | db.migrate 版本表+dry-run | ✅ |
| 17 | 国产库覆盖 | —（对标系外，总控指令） | D1 指南✅；D2/D3/D4 待真机 | 🟡 环境门控 |

**结论**：架构骨架（抽象/池/观测/重试/迁移/错误归一）已达工业形态；
剩余缺口的**根是第 3/4 行**——没有统一注册入口，"Open 即池"的 Go 核心体验
在本模块断链。P0 即补此缝。

## 2. 分片计划

### P0-1 统一驱动工厂 + Open 即池（本片）

- `nextpas.core.db.factory`：`IDbDriver`(Name/Kind/Open) 注册表；
  内建五驱动单元初始化自注册；第三方 `DbRegisterDriver` 注入；
  重复注册 fail-closed。
- 入口：`DbOpen(name|kind, dsn[, opts])`（Go `sql.Open` 语义）+
  `DbOpenPool(...)`（返回 TDbPool——对齐"`*sql.DB` 即池"核心体验，
  复用既有 V3-C3 池，不造新轮子）。
- 诚实边界：DSN 形态沿用各后端现行约定（pg conninfo/mysql dsn/odbc
  connstr/sqlite path/redis addr）；redis:// URL 富解析不进本片
  （细控走 ConnectRedis options 重载）；TDbConnectOptions advisory
  映射逐后端成文。
- 门禁：test_db_factory（注册表快照/未知 fail-fast/kind 分派负路径
  逐后端证达/第三方插拔/重复拒绝/能力互证/pool 组合冒烟）。

### P1（按序）

| 片 | 内容 | 对标锚点 |
|---|---|---|
| C5 | sqlite PRAGMA 调优预设（WAL+NORMAL 安全缺省，:memory: 过滤 journal 类） | sqlx `SqliteConnectOptions.JournalMode` |
| B4 | TLS 契约成文 ✅：§2.1-TLS 责任表 + 样例落地（带证书冒烟 env 门控余项如实保留） | pgx sslmode 表 |
| C4 | 基准口径入册 ✅：docs/db/benchmarks.md（J1 开销比 ≤1.15×/J2 池建连不变式/J3 大对象内存界三判据 + 七个 bench 逐一口径；2026-08-25 全量采集；bench 不进根 verify 链）+ V3-B7 追加 bench_db_listen 投递面口径 | Hikari 泄漏率判据思路 |
| C2 | 参数级批量绑定 ✅：pg unnest 定案（binary COPY 留 P2 评估）；sqlite/mysql/odbc/redis 如实缺席；四路基准 array 29ms/10K 行稳态（batch 的 6.0×） | pgx CopyFrom / FireDAC Array DML |

### P2（依赖最晚就绪/外部环境）

- B6 异步挂载（core.async 执行器投递 + IAsyncCancellationToken→
  PQcancel/sqlite progress handler）；B7 LISTEN/NOTIFY 随后。
- mysql/odbc 语句缓存的收益评估（先 bench 后立项，不做无判据优化）。
  2026-08-26 环境探测：本机无 mysql/mariadb 客户端与服务，odbc 无
  isql/odbcinst——评估维持环境门控待办；pg 侧已有 G8 缓存判据
  （2.1–2.4×）与 sqlite 侧 2.39× 在册可作跨后端预期锚点。
- D2/D3 国产协议系真机 conformance、D4 达梦路线决策（需环境/硬件）。

### 维持不做（V3 §4 不变）

XA/分布式事务、分库分表路由、SQL 方言转换器、ORM/反射行映射/
编译期校验。

## 3. 验收判据

- 每片独立 landing：focused gate 全绿 + heaptrc 0 unfreed +
  hygiene + 家族回归抽查（unified/conformance/tx_v2/pool_v2）。
- 新公开 API 必有 CONTRACT 节 + README 地图行 + 本表状态回填。
- 诚实纪律：env 门控的真机项没跑过就写"未验证"；能力降级矩阵
  有变化先改 §2.6 再放行。
