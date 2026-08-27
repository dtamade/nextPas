# 国产数据库连接指南（D1）

统一层接入国产数据库的三条路径、逐库连接配方与诚实能力预期。
配套契约：[CONTRACT.md](CONTRACT.md) §2.10 能力矩阵 / §2.11 ODBC 网关 /
§2.12 观测钩子。

## 0. 诚实声明

本文的**连接配方以各库官方驱动文档为据**；统一层侧的行为保证只覆盖
契约已成文部分。截至 2026-08-25：

- **真机钉死**：SQLite / PostgreSQL / MySQL(Oracle ≥8.0) 的全量门禁；
  ODBC 网关对 unixODBC 驱动管理器的负连接诊断链路（IM002 归一
  decConnection）。live 往返经环境变量门控（见 §4 验证）。
- **理论路径**：下表各国产库的具体连接参数未经本仓真机验证——按
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
| 达梦 DM8 | ODBC | `ConnectOdbc` | 无原生 pg/mysql 协议；官方 ODBC 驱动 |
| GBase 8s / 神通等 | ODBC | `ConnectOdbc` | 以 ODBC 驱动为主要接入面 |
| 其他有 ODBC 驱动的库 | ODBC | `ConnectOdbc` | 第四统一后端的设计初衷 |

选型原则：**优先原生协议路径（pg/mysql），驱动质量不可控或无对应协议时走
ODBC 网关**。同一库两条路径都通时，能力矩阵（§2.10）更丰富的一侧优先
（如 pg 路径有 savepoint/large object，ODBC 路径整体降级）。

## 2. 逐库连接配方

### 2.1 openGauss / GaussDB（pg 协议）

```pascal
Conn := ConnectPostgres('host=127.0.0.1 port=5432 dbname=app ' +
  'user=app password=secret');
```

- 服务端需允许密码认证（openGauss 默认 sha256：`pg_hba.conf` 配
  `sha256`，libpq ≥10 支持该机制协商；旧 libpq 报认证方式不支持属
  环境问题非统一层问题）。
- 预期差异：错误消息措辞与社区 PG 不同，但 **SqlState 保留**——统一层
  归一只消费 SqlState（§2.2），类目归一不受影响。
- 能力预期：savepoint/batch/native bool/statement_timeout 按 §2.10 PG 列
  预期成立；large object（lo_* fastpath）未真机验证，上生产前先跑 §4 探针。

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

### 2.4 达梦 DM8（ODBC）

```pascal
{ DSN-less（推荐）：驱动名以达梦安装的 odbcinst 为准 }
Conn := ConnectOdbc('Driver=DM8 ODBC DRIVER;Server=127.0.0.1;' +
  'Port=5236;Database=SYSDBA;UID=SYSDBA;PWD=secret');
```

- 默认端口 5236；驱动管理器 unixODBC（本仓 ODBC 门禁的同款环境）。
- 统一层走 SQLPrepare/SQLBindParameter 参数化（注入安全），?N 槽位计划
  与 pg/mysql 同构。
- 能力预期按 §2.11 诚实降级：**savepoints 不可用**（ISO CLI 无发现机制，
  BeginTxn 前先确认业务可接受）、语句超时秒粒度向上取整、约束违约归一
  依赖驱动的 SqlState 质量。
- 事务面 = AUTOCOMMIT OFF + SQLEndTran；`AImmediate` 参数接受为 no-op。

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

| 能力 | pg 协议系 | mysql 协议系 | ODBC 网关 |
|---|---|---|---|
| savepoints | ✅ 预期 | ✅ 预期 | ❌（§2.11 降级） |
| 批执行 IDbBatchExecutor | ✅ 单次往返 | ✅ | ✅ 逐条+单事务 |
| 原生 bool | ✅ OID16 | ❌ TINYINT(1) 约定 | ❌ 异构欠归一 |
| 语句超时 | ✅ 会话级 | 探测定格（多半忽略） | ✅ 秒粒度逐语句 |
| 大对象流 | ✅ lo_*（待逐库验证） | ❌ | ❌ |
| 占位符上限 | 65535 | 65535 | 999 保守下界 |

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

## 5. 离线预研结论（2026-08-28，无真机，不假验证）

- **预研覆盖**：openGauss / KingbaseES / OceanBase MySQL 租户 / TiDB /
  PolarDB（PG+X）/ GoldenDB / TDSQL（PG+MySQL）/ 达梦 DM8 / GBase 8s/8a /
  神通——全部按 §1 三档分类并给出连接配方与能力预期，落点本文。
- **未验证**：任意国产库的 conformance / trace 真机门禁均未跑过（无
  `NEXTPAS_*_TEST_CONN` 环境），本文 §2 能力预期与 §3 矩阵均为**理论预期**，
  上生产前必须按 §4 步骤自验。
- **已收口**：ODBC MySQL 系 `HY000+1062` 欠归一由 D5 `ClassifyOdbcEx`
  单调提精收口（仅 MySQL 词元驱动生效，达梦等仍欠归一诚实保留）。
- **下一步**：真机环境就绪后，D2（pg 协议系）/ D3（mysql 协议系）按
  env 门控跑 `test_db_conformance` + `test_db_trace`，结果回填本文对应小节
  并同步路线图 D2/D3 状态列。

## 6. 反馈回路

国产库暴露出的底层缺陷按 AGENTS.md 跨模块纪律处理：优先修统一层/网关
实现，不在消费方堆 workaround；发现归一缺口登记 CONTRACT §2.11/D 线
账本并同步路线图。
