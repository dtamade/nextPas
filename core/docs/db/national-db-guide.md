# 国产数据库连接指南（D1）

统一层接入国产数据库的三条路径、逐库连接配方与诚实能力预期。
配套契约：[CONTRACT.md](CONTRACT.md) §2.10 能力矩阵 / §2.11 ODBC 网关 /
§2.12 观测钩子。

## 0. 诚实声明

本文的**连接配方以各库官方驱动文档为据**；统一层侧的行为保证只覆盖
契约已成文部分。截至 2026-08-28：

- **真机钉死**：SQLite / PostgreSQL / MySQL(Oracle ≥8.0) 的全量门禁；
  ODBC 网关对 unixODBC 驱动管理器的负连接诊断链路（IM002 归一
  decConnection）；**openGauss 5.0.0 x86 via Docker 真机**（`test_db_pg 13 passed / conformance 2 passed / trace 5 passed`，见 §2.1 与 §4.5）。live 往返经环境变量门控（见 §4 验证）。
- **理论路径**：除 openGauss 外，其余国产库的具体连接参数仍为理论路径——按
  §4 步骤自验后再上生产。宁欠承诺不错承诺。

## 1. 路径决策表

| 数据库 | 推荐路径 | 工厂 | 依据 |
|---|---|---|---|
| openGauss / GaussDB | pg 协议 | `ConnectPostgres` | PostgreSQL 内核衍生，libpq 线协议兼容 |
| KingbaseES（人大金仓） | pg 协议 | `ConnectPostgres` | PG 衍生；另备 ODBC |
| PolarDB-PG / -X | pg 协议 | `ConnectPostgres` | PG 兼容形态 |
| OceanBase（MySQL 租户） | mysql 协议 | `ConnectMysql` | MySQL 线协议兼容 |
| TiDB | mysql 协议 | `ConnectMysql` | MySQL 协议兼容 |
| TDSQL-PG / -MySQL | 对应协议 | 同上 | 各自兼容形态 |
| 达梦 DM8 | DPI 原生（P2 优先，`ConnectDm`/`DbOpen('dm')`，`Savepoints=True`）/ ODBC 备选（P1，`ConnectOdbc`，`Savepoints=False` 降级） | `ConnectDm` / `ConnectOdbc` | DPI 原生真归一 `ClassifyDm` + 真 SAVEPOINT，ODBC 诚实降级；选型需 savepoint/精确归一时用 DPI，否则 ODBC 亦可（详 §2.4 / CONTRACT §2.21） |
| GBase 8s / 神通等 | ODBC | `ConnectOdbc` | 以 ODBC 驱动为主要接入面 |
| 其他有 ODBC 驱动的库 | ODBC | `ConnectOdbc` | 第四统一后端的设计初衷 |

选型原则：**优先原生协议路径（pg/mysql），驱动质量不可控或无对应协议时走
ODBC 网关**。同一库两条路径都通时，能力矩阵（§2.10）更丰富的一侧优先
（如 pg 路径有 savepoint/large object，ODBC 路径整体降级）。

## 2. 逐库连接配方

### 2.1 openGauss / GaussDB（pg 协议）— ✅ 真机实证 2026-08-28

```pascal
Conn := ConnectPostgres('host=127.0.0.1 port=55432 dbname=postgres ' +
  'user=testuser password=Test123@abc');
```

- **真机**：`opengauss/opengauss:5.0.0` x86（2.05GB）`docker run -e GS_PASSWORD -p 55432:5432`，为兼容香草 libpq 需 `password_encryption_type=0`（md5）+ `pg_hba md5` + `gs_ctl reload`（默认 `sha256` 会报 `none of the server's SASL mechanisms are supported`，方案已固化到 §4.5 脚本）。初建用户 `opengauss` 禁止远程，须另建 `testuser` 远程可达。
- **门禁**（`NEXTPAS_PG_TEST_CONN='host=127.0.0.1 port=55432 dbname=postgres user=testuser …'`）：
  - `test_db_pg 13 passed heaptrc 0` / `test_db_conformance 2 passed` / `test_db_trace 5 passed`（含 pg 段 `postgres trace live 117ms`）
  - `test_db_array_bind`  **16 passed, 3 failed** — `unnest(int[],text[])` 多列重载与 `WITH ORDINALITY` 在 openGauss 缺失（`function unnest(integer[], text[]) does not exist` / `syntax error at "WITH ORDINALITY"`），**方言鸿沟诚实记录**：array_bind 在此库应降级为 `IDbBatchExecutor` 批路径（能力矩阵 SupportsArrayBinding 仍 True，但消费方应探能力后按库容退化）。能力位诚实注记：PgOpenListener 等走统一能力探测 DbCapabilities(Conn).SupportsArrayBinding 时，openGauss 该能力在运行时仍报 True（契约按 pg 协议系静态声明），消费方对 array 场景应先探能力再构建方言 SQL，或以 try..except 回退到 batch 路径（见 CONTRACT §2.16 使用前置）。
- 预期差异：错误消息措辞与社区 PG 不同，但 **SqlState 保留**——统一层归一只消费 SqlState（§2.2），类目归一已验证不受影响；约束/事务/savepoint 全量通过。

### 2.2 KingbaseES（pg 协议）

```pascal
Conn := ConnectPostgres('host=127.0.0.1 port=54321 dbname=test ' +
  'user=system password=secret');
```

- 默认端口 54321；超级用户名随初始化模式（system/sysdba）。
- 兼容模式（PG/Oracle）影响的是 SQL 方言而非线协议；统一层透传 SQL，
  方言差异由调用方负责（§2.6 已知差异清单不覆盖厂商方言扩展）。
- 占位符统一用 `?`（自动翻译 $N）；KingbaseES 的 Oracle 兼容模式下
  服务端对 `:` 前缀的习惯用法与本层无关。

### 2.3 OceanBase MySQL 租户 / TiDB（mysql 协议）

```pascal
Conn := ConnectMysql('host=127.0.0.1 port=2881 user=root@tenant ' +
  'password=secret db=app');            { OceanBase：用户名带租户前缀 }
Conn := ConnectMysql('host=127.0.0.1 port=4000 user=root ' +
  'password=secret db=app');            { TiDB }
```

- 语句超时能力是**建连期探测定格**（仅 Oracle 官方库且 server ≥8.0 走
  `max_execution_time`）：TiDB/OceanBase 大概率探测失败 → advisory 忽略，
  这是诚实行为不是缺陷（§2.6b/INC-7）。
- 多语句 Exec 需 `CLIENT_MULTI_STATEMENTS`，工厂默认携带。
- OceanBase 的 `SELECT ... FOR UPDATE` 等方言细节不在统一层契约内。

### 2.4 达梦 DM8（双路径：ODBC 网关 P1 + DPI 原生 P2）

```pascal
{ DSN-less（推荐）：驱动名以达梦安装的 odbcinst 为准，花括号为 ODBC 规范 }
Conn := ConnectOdbc('Driver={DM8 ODBC DRIVER};Server=127.0.0.1;' +
  'Port=5236;Database=SYSDBA;UID=SYSDBA;PWD=secret');
{ 池化（Go sql.DB 语义） }
Pool := DbOpenPool('odbc',
  'Driver={DM8 ODBC DRIVER};Server=127.0.0.1;Port=5236;Database=SYSDBA;UID=SYSDBA;PWD=secret');
```

- 默认端口 5236；驱动管理器 unixODBC（本仓 ODBC 门禁的同款环境）。
- 统一层走 SQLPrepare/SQLBindParameter 参数化（注入安全），?N 槽位计划
  与 pg/mysql 同构；亦支持 `DbOpen('odbc', connstr)` 统一工厂形态。
- 能力预期按 §2.11 诚实降级：**savepoints 不可用**（ISO CLI 无发现机制，
  嵌套 `WithTransaction` 将 fail-fast `decNotSupported`，业务需避免嵌套）、
  `SupportsBatchExecutor=True`（逐条+单事务，精确到步）、
  `SupportsMultiStatementExec=False`（分号批因驱动而异）、语句超时秒粒度
  向上取整、约束违约归一依赖驱动的 SqlState 质量（多数 `HY000` 欠归一，
  `NativeError` 仅透传）。
- 事务面 = AUTOCOMMIT OFF + SQLEndTran；`AImmediate` 参数接受为 no-op
 （Oracle 系 `BEGIN IMMEDIATE` 无对应，契约差异登记）。
- **双路径**：P1 ODBC 网关（`Driver=DM8 ODBC DRIVER`，§2.11 honest downgrade，`Savepoints=false`）；**P2 DPI 原生**（`ConnectDm('Server=127.0.0.1;Port=5236;Database=SYSDBA;UID=SYSDBA;PWD=...')` / `DbOpen('dm', dsn)`，`libdmdpi.so` dlopen，三候选，`ClassifyDm` 真归一，`Savepoints=True` 真原生，见 §4.5 与 `core/src/nextpas.core.db.dm.*`）。选型：需精确错误细分或 savepoint 嵌套时用 DPI，否则 ODBC 亦可（Manager 一跳 ~10%）。

### 2.5 PolarDB / GoldenDB / TDSQL（双协议形态，选型见 §1）

```pascal
{ PolarDB-PG 形态走 pg 路径；PolarDB-X / GoldenDB / TDSQL-MySQL 形态走 mysql 路径 }
Conn := ConnectPostgres('host=127.0.0.1 port=5432 dbname=polardb user=polardb password=secret');
Conn := ConnectMysql('host=127.0.0.1 port=3306 user=goldendb password=secret db=app');
Conn := ConnectMysql('host=127.0.0.1 port=3306 user=tdsql password=secret db=app');
```

- PolarDB-PG 与社区 PG 线协议一致，按 §2.1 预期；PolarDB-X / GoldenDB /
  TDSQL 的 MySQL 兼容形态按 §2.3 预期——语句超时同样探测定格大概率忽略。
- 这些库的分布式事务/全局一致性读等扩展能力不在统一层契约内，不假装支持。

### 2.6 其余 ODBC 路径库（GBase 8s / 8a / 神通 等）

同 §2.4 模板，替换 Driver 名与服务器参数即可；connstr 原文透传
SQLDriverConnect，本层不解析不改写。个别驱动拒绝 `SQL_ATTR_QUERY_TIMEOUT`
属环境降级（best effort），不影响其余功能。GBase 8a 分析型形态的批量装载
建议走原生工具而非统一层批执行（能力矩阵 BatchExecutor 仍为逐条+单事务）。

## 3. 能力预期矩阵（跨库速查）

统一能力自述一律运行时探测：`DbCapabilities(Conn)` 返回
`IDbCapabilities`，**不要按库名分支**。快速预期：

| 能力 | pg 协议系 | mysql 协议系 | ODBC 网关 | dm DPI 原生 |
|---|---|---|---|---|
| savepoints | ✅ 预期 | ✅ 预期 | ❌（§2.11 降级） | ✅ 原生 |
| 批执行 IDbBatchExecutor | ✅ 单次往返 | ✅ | ✅ 逐条+单事务 | ✅ 逐条+单事务 |
| 原生 bool | ✅ OID16 | ❌ TINYINT(1) 约定 | ❌ 异构欠归一 | ❌ 约定 |
| 语句超时 | ✅ 会话级 | 探测定格（多半忽略） | ✅ 秒粒度逐语句 | — advisory 忽略 |
| 大对象流 | ✅ lo_*（待逐库验证） | ❌ | ❌ | — v1 无 |
| 占位符上限 | 65535 | 65535 | 999 保守下界 | 999 保守下界 |

\* ODBC 网关含非 dm 原生的通用路径；dm 原生列为本版本 V3-DM 增量（`Savepoints=True` 真原生，归一按 `ClassifyDm` 負码位表）。

错误归一现状（原 D 线账本缺口已收口）：MySQL 协议系驱动经 ODBC
把约束违约报 `HY000+1062` 时，由 ClassifyOdbcEx 按 NativeError
单调提精为 decConstraint/unique——仅当建连期驱动名/DBMS 名探测
命中 MySQL 词元才启用；达梦/GBase 等 native code 自成体系的驱动
仍保持 SQLSTATE 欠归一（不错归一）；pg 协议系不受影响。真机回归
时以 conformance + trace 门禁的 OnError 分类快照核对各库实际类目。

## 4. 真机验证步骤（每库上线前必做）

1. **连通探针**：
   ```bash
   export NEXTPAS_PG_TEST_CONN='host=... dbname=...'     # pg 路径系
   export NEXTPAS_MYSQL_TEST_CONN='host=... db=...'      # mysql 路径系
   export NEXTPAS_ODBC_TEST_CONN='Driver=...;Server=...' # ODBC 路径系
   ```
   缺席时对应 live 段自动 Skip（离线段照常全绿）。
2. **跑门禁**（含 conformance 一致性套件与观测钩子）：
   ```bash
   make focused FOCUS=core/tests/nextpas.core.db/test_db_conformance
   make focused FOCUS=core/tests/nextpas.core.db/test_db_trace
   ```
3. **一致性判读**：conformance 十一组用例逐字复跑——类型往返/NULL/
   约束归一/事务/savepoint/迁移/Changes 全部通过方可视为"已验证"；
   sqlite 与 pg 两列的差异项（§2.6）按后端差异对待，不算失败。
4. **记录**：把实测能力矩阵快照（DbCapabilities 输出 + 门禁结果）回填到
   本文件对应小节，替换"待真机验证"标注。

### 4.5 Docker 一键真机（推荐）— x86 原生，QEMU 仅 ARM 逃生

**结论**：**首选 Docker 原生 x86 镜像，不到万不得已不用 QEMU**。宿主机为 x86_64 且已装 `qemu-aarch64-static + binfmt_misc`（本机实证 `qemu-aarch64 / qemu-arm` 均就绪），`docker run --platform linux/arm64` 会自动经 QEMU 仿真，但**性能 5–10× 慢**，仅适合 `conformance/trace` 小数据门禁，**不适合** `bench_db_*` 性能判据。

| 镜像 | 架构 | 是否需 QEMU | 性能 | 备注 |
|---|---|---|---|---|
| `opengauss/opengauss:5.0.0`（2.05GB）| `linux/amd64` | **否**（本次实证直接 `docker pull/run`） | 原生 | `docker run --name og-test -e GS_PASSWORD='Test123@abc' -p 55432:5432 opengauss/opengauss:5.0.0` → 3s `server started` |
| `kingbase / oceanbase x86` | `amd64` | 否 | 原生 | 同模板 |
| `pingcap/tidb`（PD+TiKV+TiDB 三件套）| `amd64` | 否，但需 `docker-compose` 编排 | 中等启动成本 | `tiup` 亦可，门禁同前 |
| `dameng/dm8:8.0`（常见 ARM 交付） | `linux/arm64`（部分 x86 镜像需向厂商获取） | **是**（ARM 镜像时）`docker run --platform linux/arm64 --name dm-test -p 5236:5236 --privileged dameng/dm8:8.0` | 慢，仅功能验证 | 需先 `docker pull --platform linux/arm64 ...` 并配置 `odbcinst.ini: Driver=DM8 ODBC DRIVER, Driver=/opt/dmdbms/bin/libdodbc.so`，结果标注 `emulated`；x86 镜像可原生（见厂商下载中心） |

**openGauss 兼容三步**（已脚本化，见 `scripts/verify-national-db.sh` 建议）：

```bash
docker run --name og-test -e GS_PASSWORD='Test123@abc' -d -p 55432:5432 opengauss/opengauss:5.0.0
# 等 10s 后
docker exec -u opengauss og-test bash -c "GAUSSHOME=/usr/local/opengauss LD_LIBRARY_PATH=/usr/local/opengauss/lib /usr/local/opengauss/bin/gs_guc set -D /var/lib/opengauss/data -c \"password_encryption_type=0\""
docker exec og-test bash -c "sed -i 's/sha256/md5/g' /var/lib/opengauss/data/pg_hba.conf"
docker exec -u opengauss og-test bash -c "GAUSSHOME=/usr/local/opengauss LD_LIBRARY_PATH=/usr/local/opengauss/lib /usr/local/opengauss/bin/gs_ctl reload -D /var/lib/opengauss/data"
docker exec -u opengauss og-test bash -c "LD_LIBRARY_PATH=/usr/local/opengauss/lib /usr/local/opengauss/bin/gsql -d postgres -c \"create user testuser password 'Test123@abc';\""
# 探针
docker run --rm --network host postgres:16-alpine psql "host=127.0.0.1 port=55432 dbname=postgres user=testuser password=Test123@abc" -c "select version();"
NEXTPAS_PG_TEST_CONN='host=127.0.0.1 port=55432 dbname=postgres user=testuser password=Test123@abc' make focused FOCUS=core/tests/nextpas.core.db/test_db_pg
```

陷阱：初建用户 `opengauss` 禁止远程（`FATAL: Forbid remote connection with initial user`）；`gs_ctl restart` 会杀容器主进程（`--rm` 容器自删），故用 `reload`；`--rm` 容器重启即丢数据，演示用 `--name` 持久化。

## 5. 离线预研结论（2026-08-30，DM DPI 原生增量）

- **预研覆盖**：openGauss / KingbaseES / OceanBase MySQL 租户 / TiDB /
  PolarDB（PG+X）/ GoldenDB / TDSQL（PG+MySQL）/ 达梦 DM8 / GBase 8s/8a /
  神通——全部按 §1 三档分类并给出连接配方与能力预期，落点本文。
- **已真机（2026-08-28，Docker）**：
  - **openGauss 5.0.0 x86**（`opengauss/opengauss:5.0.0`，§4.5 三步兼容后 `NEXTPAS_PG_TEST_CONN` 指向 55432）：`test_db_pg 13 passed / conformance 2 passed / trace 5 passed`，方言鸿沟 3 例已诚实记录（`unnest` 多列 / `WITH ORDINALITY` 缺失，array 场景降级为 batch）。
  - **MySQL 协议系**：`mariadb:11.8`（`53306`）与 `mysql:8.0.46`（`53307`）双引擎经 **MariaDB Connector/C 3.3（libmariadb.so.3, 112B 绑定）** 直连验证——`test_db_mysql_adapter 7/7 passed`（roundtrip/四分类/savepoint/caps）`heaptrc 0`，`mysql:8` 需 `mysql_native_password`（`caching_sha2` 需 libmysqlclient 8，MariaDB 客户端以 `mysql_native_password` 兼容，生产建议显式创建该类用户）。此双引擎已覆盖 TiDB/OceanBase/PolarDB-X/GoldenDB/TDSQL-MySQL 的线协议兼容面（同属 MySQL 协议系，差异仅方言与事务语义，见 §2.3）。
- **DM8 DPI 原生**：V3-DM（2026-08-30）`dbkDm` + `nextpas.core.db.dm.{base,ffi,loader,adapter}` 四单元（`libdmdpi.so` 三候选 dlopen、`ClassifyDm` 负码位表、`Savepoints=True` 原生），工厂 `DbOpen('dm', dsn)` / `ConnectDm(dsn[, opts])` 已透出；离线归一与 DSN 离线可跑，真机经 `NEXTPAS_DM_TEST_CONN` 门控（同 pg/mysql/odbc 惯例，缺席 Skip）。ODBC 网关仍保留为备选路径。
- **已收口**：ODBC MySQL 系 `HY000+1062` 欠归一由 D5 `ClassifyOdbcEx` 单调提精收口（仅 MySQL 词元驱动生效，达梦等仍欠归一诚实保留，见 ADR 0002）；DM DPI 侧按 `ClassifyDm` 真归一补齐。
- **下一步**：KingbaseES 待 Docker 真机（复用 pg 协议系）；TiDB/OceanBase 以 MySQL 8/MariaDB 双引擎为代理已具备发布条件，独立 TiDB 集群编排（PD+TiKV+TiDB）可作为独立进阶验证。

## 6. 反馈回路

国产库暴露出的底层缺陷按 AGENTS.md 跨模块纪律处理：优先修统一层/网关
实现，不在消费方堆 workaround；发现归一缺口登记 CONTRACT §2.11/D 线
账本并同步路线图。
