# nextpas.core.db V3 工业级路线图（2026-08-23）

> 基线：`2026-08-23-db-v2-architecture.md`（V2 已全部落地 S1-S8）、
> `2026-08-23-db-v2-increment-go-rust.md`（INC 清单）。
> 本文回答一个问题：**从"双后端统一层"到"工业级数据库模块"还差什么，
> 按什么顺序补齐。**

---

## 1. 工业级的定义（对标系）

"工业级"不是形容词，是四个可检验维度。每个维度给出我们当前的位置与
差距来源。

### 1.1 后端覆盖面

| 对标 | 覆盖 | 我们的差距 |
|---|---|---|
| Go database/sql | 驱动生态几十个，主流全有 | 仅 sqlite + pg |
| Rust sqlx/diesel | MySQL/Postgres/sqlite/TLS 全家 | 同上 |
| FireDAC / ZeosLib / SQLdb | FireDAC 十余驱动；Zeos 几十个 | 同上 |

**结论**：双后端是"统一层验证平台"，不是产品形态。V3 第一主线 =
后端扩张（见 §3 主线 A）。优先级依据是消费方需求密度与实现杠杆：

1. **MySQL/MariaDB**（原生 C API）：需求密度最高；libmysqlclient 的
   prepared 协议成熟；dlopen loader 模式直接复制 `db.pg.loader`
   （已验证的运行时加载+符号绑定模式，含 soname 探测）。
2. **ODBC 网关**（unixODBC/Windows ODBC）：一个适配器打开一片——
   MSSQL、Oracle、DuckDB、ClickHouse、Db2 全部经 ODBC 驱动可达。
   这是杠杆最大的一步，也是 ADO.NET/JDBC/ODBC 三大工业生态共同验证
   过的路径。
3. DuckDB 专属适配器（分析场景）暂列观察项：先看仓内消费方是否有
   真实需求，不为简历驱动开发。

### 1.2 架构关系（接口设计与组合律）

| 对标物 | 它做对了什么 | 我们的状态 |
|---|---|---|
| ADO.NET DbProviderFactory | provider 无关工厂 + 能力自描述 | 有 per-backend 工厂函数，**无统一入口** |
| Go database/sql | 注册制驱动 + 统一 Open(driver, dsn) | 同上 |
| JDBC Connection 元数据 | DatabaseMetaData.getDriverName 等 | 明确拒绝全家桶（基线 §9），但**最小能力探测缺失** |
| FireDAC 驱动抽象层 | 统一 API + 每驱动 escape hatch | Raw 逃生舱已有，方向一致 |
| HikariCP | 池即默认推荐路径、fail-fast、泄漏检测 | pool 已有，硬化项缺（§3 主线 C） |
| sqlx (Rust) | 连接级语句缓存、超时、TLS 一等公民 | sqlite 缓存有；pg 缓存 G8 未做；TLS 经 conninfo 未成文 |

**结论**：V3 第二主线 = 架构收口（统一工厂、能力矩阵自描述、观测钩子、
重试助手），把"两个工厂函数 + 约定俗成"升级为"一个入口 + 自描述 +
可观测"。原则不变：接口隔离（能力接口族）、诚实语义（不冒充）、
引用计数所有权。

### 1.3 性能

| 对标 | 判据 | 我们的状态 |
|---|---|---|
| pgx | prepared 复用、COPY 流式装载 | 点查缓存仅 sqlite（1.54×）；pg 侧 G8 未做；COPY 门控中 |
| Array DML (FireDAC) | 批量绑定一次往返 | IDbBatchExecutor 多语句合并已做（S3 Tier1）；参数级批量绑定未做 |
| HikariCP | 池开销微秒级、零误回收 | 功能齐但无标准化基准护栏 |

**结论**：V3 第三主线 = 性能工业化。核心动作：G8 pg 语句缓存 →
参数级批量绑定（Array DML 对标）→ 池硬化 → **基准门禁化**
（现有 bench 从"参考数据"升级为"防回归判据"，固定口径入册）。
每一步都有既有基准对照，不做无判据的优化。

### 1.4 可靠性与可运维性

工业模块的可运维底线：出问题时有钩子看得见、瞬时故障有标准恢复姿势、
慢查询有超时兜底。

- 超时：INC-7 已落地（连接级）。查询级单次超时随 §3 B2 补齐。
- 观测：**完全没有**。补 IDbTraceListener 观测钩子（B3）。
- 重试：瞬时错误（decConnection、死锁 40P01、序列化失败）没有标准
  恢复助手。core.async 已有 RetryWithBackoff 资产，同步形态包装即可（B5）。
- 取消：core.async 已有 IAsyncCancellationToken；同步模型下的诚实取消
  面 = pg PQcancel（libpq 原生异步安全取消），sqlite 侧 progress handler。
  随 INC-4 异步挂载一并设计（B6 提前，理由见 §2）。

---

## 2. 关键前提变化：core.async 已经存在

V2 设计时 core.async 未就绪，故 INC-4 写"等 core.async"、G9 LISTEN/
NOTIFY 同样挂起。**现状：`nextpas.core.async.*` 已提供 loop/cancellation/
channel/retry/semaphore/shutdown 完整件。**

这改变两点排期判断：

1. INC-4（异步挂载硬规则 + 预留契约形状）从"无限期搁置"提为 V3 正式
   分片（B6）。规则本身不变（基线 D8：不造平行宇宙，db 的异步面必须
   建立在 core.async 之上）。
2. G9 LISTEN/NOTIFY 解锁：pg PQconsumeInput/PQnotifies 轮询泵 +
   async.channel 投递，取消经 IAsyncCancellationToken。排在 B6 之后
   （依赖其取消语义）。

---

## 3. 三条主线与分片路线

每片独立可 landing；lane 纪律同仓库规范；破坏性变更须显式标注并获
总控确认。

### 主线 A：后端扩张

| 分片 | 内容 | 关键设计点 | 门禁 |
|---|---|---|---|
| **A1 mysql.base/ffi/loader** ✅ | 候选 soname 表顺序探测（libmysqlclient.so.21/.20/.19/.18 → libmariadb.so.3/.so.2），首个命中者绑定全部符号；flavor 经 MariaDB 独有符号存在性探测 | **双方言 ABI 分叉隔离在 loader/ffi 单点，本机实证三处**：① Connector/C 不导出 `mysql_library_init/end`（头文件宏别名→`mysql_server_init/end`）——首选+回退绑定；② `mysql_real_escape_string_quote` 仅 Oracle ≥5.7.6 有，MariaDB 只有 3 参旧版且 **ABI 不同**——分开声明，quote 变体可缺席（nil），连接层优先降级；③ flavor 探针用 `mariadb_connection`（实证导出），原计划的 `mariadb_version` 本机不存在。MYSQL_FIELD 镜像 128B、双方言 MYSQL_BIND 镜像 72B/120B 由门禁 sizeof 钉死防漂移 | test_db_mysql 七组全绿 ✅（离线：负连接落 CR_* 族、stmt 未连服 prepare 必败、ABI 尺寸钉死；heaptrc 0 unfreed）。**真机 stmt 参数绑定路径待 A2 经 NEXTPAS_MYSQL_TEST_CONN 实证** |
| **A2 mysql.adapter** ✅ | TDbKind 尾部追加 dbkMysql（序号稳定契约有钉死用例）；IDbQuery 走 **prepared stmt 二进制协议**（与 pg execParams 同级，参数化即注入安全），执行惰性触发；?N 经槽位计划重写为顺序 ? 并携带物理槽→逻辑号映射（扫描隔离字面量/反引号/--、#注释/块注释） | 错误归一 ClassifyMy 入 db.err 纯函数表（码位优先：约束双码位 1062/1022→unique、1048→notnull、1216/1217/1451/1452→fk、3819/4025→check；1213/1206→transaction；1205/3024/1969→timeout；CR_* 族整体 decConnection 但 OOM→capacity、协议乱序欠归一）；MYSQL_BIND 双方言编组单点实现于 adapter（A1 镜像布局 + 门禁字节级验证）；结果绑定按声明类型请求（整数族 LONGLONG/浮点族 DOUBLE/其余 VAR_STRING 含 DECIMAL——二进制协议本就是 length-prefixed 文本；截断扩缓冲 fetch_column 重取）；事务簿记对齐 pg；RELEASE 需带 SAVEPOINT 关键字（方言差异成文）；BEGIN IMMEDIATE 无对应语义接受为 no-op | test_db_mysql_adapter 七组门禁 ✅（六组离线全绿 heaptrc 0 unfreed + 真机组 env 门控 Skip）；**真机 conformance 第三后端段待环境**：设 NEXTPAS_MYSQL_TEST_CONN 即自动启用 live 冒烟（roundtrip/列类型四分类/savepoint 回滚） |
| **A3 odbc.base/ffi/loader** ✅ | unixODBC（Linux libodbc.so.2 / Windows odbc32）加载；SQLAllocHandle/SQLDriverConnect/SQLEndTran/SQLExecDirect/SQLPrepare/SQLExecute/SQLFetch/SQLGetData/SQLBindCol/SQLBindParameter/SQLGetDiagRec 等 21 符号最小面 | 句柄层级（ENV→DBC→STMT）所有权模型；诊断记录 SQLGetDiagRec 经 OdbcDiag/OdbcRaise 归一为 TOdbcDiagRecs/EDbOdbcError（SqlState 前缀分类留给 A4）；**仅绑 ANSI API 不绑 W 系列**（SQLWCHAR 宽度在 unixODBC=4B 与 Windows=2B 分歧，规避于绑定层）；本机实证 libodbc.so.2 无头文件可加载，bogus DSN 真库诊断路径 IM002 全链路验证。工具链陷阱第二例入册：`string(AnsiString(ptr))` 强转在返回托管记录数组的函数内损坏临时管理 → 一律 StrPas | test_db_odbc_base 七组全绿 + live 段 NEXTPAS_ODBC_TEST_CONN 门控 ✅（heaptrc 0 泄漏；无驱动环境 CI 化）|
| **A4 odbc.adapter** ✅ | 第四后端：经 ODBC 打开任意 DSN（connstr 原文透传 DriverConnect，DSN/DSN-less 皆可）；SQLPrepare/BindParameter/Execute 参数化 + SQLFetch/GetData 惰性物化；AUTOCOMMIT 切换 + SQLEndTran 计数式事务面；GetInfo 探测（DBMS_NAME/VER、IDENTIFIER_CASE、TXN_CAPABLE——常量经微软 ODBC SDK 头核实） | 能力降级矩阵成文（CONTRACT §2.10 表 + §2.11 + adapter 头注三处同文）：Savepoints/MultiStatementExec/NativeBool=False 不假装，BatchExecutor=True（逐条+单事务），StatementTimeout=QUERY_TIMEOUT 逐语句秒粒度；ClassifyOdbc 只信 SqlState（IM*/HY* 精确码 + ISO 类前缀兜底），NativeError 跨驱动无语义仅透传——MySQL 系 HY000+1062 欠归一缺口登记 D 线 flavor 细化（已由 D5 ClassifyOdbcEx 收口）；GetData 截断整值重取假设由 live 门禁 >4KB 往返钉死、指示符不自洽 fail-fast；参数延迟绑定要求稳定缓冲（对象字段托管）禁表达式临时地址；ffi 增绑 SQLGetInfo 至 22 符号 | test_db_odbc_adapter 五组离线全绿 + live 段 NEXTPAS_ODBC_TEST_CONN 门控 ✅（heaptrc 0 泄漏；负连接走管理器 IM002 真实诊断链路，无驱动环境 CI 化）；回归 odbc_base/mysql_adapter/unified/conformance/tx_v2 全绿 |
| **A5 redis.adapter** ✅ | RESP2 原生客户端第五后端（无 C 库依赖；db(L2)→net(L2) 同层单向依赖合规）：命令文本分词 + ?/?N 槽位 bulk 参数（协议级注入安全）；回复→行诚实映射（数组逐元素行/null 零行/error 执行点抛）；MULTI/EXEC/DISCARD 事务直映 + EXEC 数组逐元素校验；BatchExecutor 真流水线；§2.12 观测钩子同构 | db.err 新增 ClassifyRedis 词元表（ERR/Wrongpass/MOVED/LOADING/EXECABORT/NOSCRIPT…未识别欠归一）；db.base 尾部追加 dbkRedis（序号稳定契约钉死）+ CreateFullRedis（错误首词存 SqlState 槽）；transport 接口化（IRedisTransport 可注入，net.tcp 默认实现）供离线门禁脚本回放；工程坑登记：FPC implementation-uses SysUtils 会遮蔽 base.TBytes 致接口/实现签名不匹配——家族 uses 全部集中接口段 | test_db_redis_base 十组全绿（帧字节级/增量解析/fail-fast/归一表）+ test_db_redis_adapter 十一组全绿（脚本化传输离线全契约 + live env 门控 NEXTPAS_REDIS_TEST_CONN），heaptrc 0 unfreed ✅ |
| **A5.1/A5.1b redis 增强** ✅ | INFO server 版本探测（redis_version→valkey_version 回退，失败保守降级）经 ProductVersion 暴露；`ConnectRedis(AAddr, TDbRedisConnectOptions)` 选项重载 + UseTls/TlsServerName TLS 变体（TLSDial 一体阻塞，SNI 规则：显式名否则 Host）；拨号失败桥接 decConnection、ErrType='NET' | 受控跨模块修复：nextpas.core.tls.dialer ResolveAndConnect 把 resolve 的网络序输出直喂要求主机序的 sockaddr_ipv4，127.0.0.1 被连成 1.0.0.127（TLS 拨拒绝端口假握手 10s+），补 platform_ntohl 一行并登记坑；BridgeNetError 由 CreateSimple(decUnknown) 改 CreateFullRedis(decConnection) | test_db_redis_adapter 十五组全绿（新增 tls 负路径离线 11.1s→1.0s + live-tls env 门控 NEXTPAS_REDIS_TEST_TLS_CONN/_PASSWORD）+ test_db_redis_base 十一组 + test_dialer 17 组（main 对照同泄漏特征，非本次引入），heaptrc 0 unfreed ✅ |
| **A5 统一工厂** ✅ | `nextpas.core.db.factory`：IDbDriver 注册表（内建五驱动单元初始化自注册，第三方 DbRegisterDriver 注入，重复名 fail-closed）+ `DbOpen(name\|kind, dsn[, opts])`（Go sql.Open 语义）+ `DbOpenPool(...)` 返回 V3-C3 池——对齐 Go「*sql.DB 即池」；pg 建连失败补 SQLSTATE '08000'→decConnection 归一 | 工程坑登记：FPC trunk「const 接口临时实参 + 锁内 try-finally 提前退出」组合泄漏调用方临时对象（本地变量/继续追加路径均无现象）——DbRegisterDriver 改托管传参 + 锁内单出口 + 异常移锁外规避；门禁偏差说明：独立 test_db_factory 门（15 组）而非并入 test_db_v2，与 trace/retry 分门惯例一致 | test_db_factory 15 组全绿 heaptrc 0 unfreed ✅（注册表快照/kind+名双形态分派负路径逐后端证达/第三方插拔/重复拒绝/能力互证/pool 冒烟）；回归 pg 13/unified 18/pool_v2 15/tx_v2 7/v2 2 全绿 ✅ |

**A 线验收判据**：conformance 套件对每个新后端跑满十套用例；任何后端
差异先登记 CONTRACT §2.6 再放行；shim 纪律照旧。

### 主线 B：架构收口

| 分片 | 内容 | 关键设计点 | 门禁 |
|---|---|---|---|
| **B1 能力矩阵自描述** ✅ | `IDbCapabilities` 可选能力接口 12 项（Kind/ProductName/ProductVersion + 8 布尔 + MaxPlaceholders）；门面 `DbCapabilities(Conn)` 统一探测，无值=nil（仓库惯例） | 只描述统一层契约内能力，**SQL 方言差异（DDL 类型名/约束子码细分/错误定位深度）留在 §2.6 文档域——两套机制职责分离成文**；布尔声明 ⇔ 可选接口 QueryInterface 存在性互证（conformance 钉死防漂移）；mysql StatementTimeout 建连期按 flavor+server 版本探测定格为实例常量；sqlite MaxPlaceholders=999 跨版本保守下界（新栈实际 32766，消费方按 ≤999 编码全后端安全） | conformance 新 RunCapabilitySuite（四对接口互证 + savepoint 行为探针）+ sqlite/pg 静态钉子全绿；mysql 段入 test_db_mysql_adapter 真机组（env 门控）✅ |
| **B2 查询级选项** ✅ | `TDbExecOptions`（TimeoutMs advisory 语义：可安全应用则生效否则忽略，对齐 INC-7 提示语义保跨后端可移植）+ IDbConnection Exec/Query 重载（池代理 TPooledConn 同步透传） | pg = Exec 同步窗口 SET/SHOW 恢复包裹、Query 以查询对象存活期为生效窗口（析构恢复原值——惰性执行与会话级机制的折中）；mysql = Oracle ≥8.0 探测经 max_execution_time（@@ 读回恢复基线），Query(opts) v1 忽略登记升级路径；odbc = QUERY_TIMEOUT 逐语句双路径零会话污染；sqlite = 忽略诚实登记；超时归一 decTimeout 与 INC-7 同类目；**规范反馈落地**：pg.conn 不引 FPC RTL，反哺 `text.conv.AnsiPtrToStr` 统一 PAnsiChar 读回入口（§7.1 账本） | conformance §12 advisory 全后端复跑 + pg 真机 exec/query 双路径超时 decTimeout 与会话恢复钉死 ✅；回归 unified/pool_v2/odbc/mysql/text_conv 五门禁全绿 heaptrc 干净 |
| **B3 观测钩子** ✅ | `IDbTraceListener`（OnAcquire/OnRelease/OnQuery(DurationMs, Sql 摘要)/OnError(Category)）+ `IDbTraceControl` 挂载面 + `TDbTraceHub` 共享枢纽（锁内快照锁外回调——C3 硬边界推广；摘要折叠截断 ≤512 防日志爆炸；platform_monotonic_ns 单调计时，不引 FPC RTL）；门面 `DbTraceControl(Conn)` 统一探测（照 DbCapabilities 模式） | 默认零成本（无监听器不取时钟不摘要不发事件）；**挂载即补发 OnAcquire**——建连先于挂载的常驻场景可观测，Acquire/Release 由此 1:1 配对；回调调用线程同步执行（诚实模型）；四后端同构接线：sqlite/pg/mysql 逐路径插桩（Exec 单点 + 查询首 Step、Reset 重武装），odbc 收敛 DoExec/DoQuery 单点天然无双发，pg 的 B2 超时恢复钩互不影响 | test_db_trace 新门禁：摘要纯函数边界 + sqlite 全量契约（计数 5 OnQuery / 多 Step 只计一次 / 错误类目直透且不发 OnQuery / SetListener(nil) 归零 / 配对 1:1 / 零监听冒烟）+ pg 真机 decSyntax 直透与 opts 超时路径 + mysql/odbc live 探针 ✅；回归 unified/conformance/v2/pg/stmt_cache/tx_v2/mysql_adapter/odbc_adapter 全绿 heaptrc 干净 |
| **B4 TLS 成文** ✅(文档+2026-08-26 本机 PG17 自签 CA 实例冒烟：verify-full 全门禁 13+11 组 heaptrc 干净、错误 CA 拒绝、require 加密确认——余项清零) | CONTRACT §2.1-TLS 小节：责任表（pg=libpq 透传/redis=UseTls+TLSDial/odbc=connstr 驱动负责/sqlite=N/A）+ 样例 + verify-full 推荐；mysql v1 无 ssl 键解析诚实登记升级路径 | 诚实注记成文：sslmode=require 只加密不验书（libpq 语义）；redis TLS 负路径桥接 decConnection/ErrType='NET' 交叉引用 §2.13 | 文档落地 ✅；带证书 conformance 冒烟本地无环境未跑（env 门控余项，不假装验证）|
| **B5 重试助手** ✅ | `WithTransactionRetry(Conn, Proc[, Policy])`：瞬时段位自动退避重试整事务，业务异常直抛 | 缺省段位 DbRetryableDefault：decTransaction + sqlite BUSY/LOCKED 可重试；**decConnection 从原计划的可重试清单移除**——连接断亡需重连（池的领域），同一死连接重试必然复败，静默重试是假恢复；幂等责任在回调；退避词汇对齐 core.async.retry | test_db_retry 七组全绿 ✅ |
| **B6 INC-4 异步挂载** ✅ | `nextpas.core.db.async`：TDbAsyncExecutor——阻塞调用投递到专用单工执行线程，返回可等待/可取消句柄 IDbAsyncHandle（IsDone/IsCanceled/WaitFor/ErrorObj/Cancel） | 硬规则落地：连接仍一连接一线程（G3），异步的是"等待"不是"并发复用"；**零 FPC RTL 直引**——执行线程复用 core.thread.pool 单工池、运行时初始化用 core.thread.init（cthreads 正替）、等待/互斥用 core.sync、异常基座 core.errors；取消经 IAsyncCancellationToken 子令牌级联 → IDbCancelControl（pg PQcancel / sqlite progress handler，只在异步操作期间安装、finalize 即摘除保同步路径零成本）；时序不变式 = 级联注册先于入队；析构 WaitAll 诚实等自然收尾；消费方先行丢句柄由 op 托管保活；顺带反哺修复 async.cancellation 子令牌生命周期缺陷（父持引用+摘链，f2b 跨模块改动单独登记） | test_db_async 十二组全绿 heaptrc 0 ✅（sqlite 离线：往返/错误传播/单飞/令牌级联/直呼取消/终态 no-op/超时分支/丢句柄/析构等待/同步路径不受扰 + pg 真机：往返/PQcancel 真中断 57014→decTimeout ~200ms/单飞恢复）；bench_db_async 入册：固定挂载成本 ~15–20µs/往返（两次跨线程唤醒），sqlite 微查询场景倍数放大 10×+ 属物理事实——**>20% 回退条款评估：设计目标场景（长查询让出+取消）无实质劣化（真机取消 ~200ms vs 自然完成秒级），微查询场景以 CONTRACT §2.17 使用指引处置（明示不要异步挂载），模块保留** |
| **B7 LISTEN/NOTIFY（G9 收口）** ✅ | `nextpas.core.db.pg.listen`：TPgListener 专用连接独占（"LISTEN 会话不跑查询"由结构保证——无查询面）+ 单工池泵线程轮询 PQconsumeInput/PQnotifies 投递内建有界记录队列；重连自动按订阅快照重放 LISTEN；取消经 IAsyncCancellationToken（Token 外露可级联，Cancel 即协同停泵） | at-most-once 如实上报（GapCount/DroppedCount，不假装 at-least-once）；投递面偏差成文（原案 async.channel → 内建记录队列：字节通道 vs 托管串错配 + db.async 已立 thread.pool/core.sync 惯例，CONTRACT §2.18）；不经 db 门面防线程依赖传染（§2.17 同纪律）；TPGnotify 按 libpq C 布局逐字段钉死（relname/be_pid/extra——首版声明字段序错位致解引用整数当指针 AV，真机往返门禁捕获后修正入册） | test_db_pg_listen 十一组真机全绿 heaptrc 0 ✅（自发自收往返/无载 NOTIFY/FIFO 保序/静默超时/频道名 fail-fast/unlisten↔relisten/UNLISTEN */溢出保旧弃新/令牌取消/坏 conninfo fail-fast 构造期异常自动析构干净/pg_terminate_backend 真断线→GapCount≥1→重连重订阅再达）；回归 test_db_pg 13 组 + unified 18 组全绿 heaptrc 干净 ✅ |

### 主线 C：性能工业化

| 分片 | 内容 | 关键设计点 | 门禁 |
|---|---|---|---|
| **C1 G8 pg 语句缓存** ✅ | PQprepare/PQexecPrepared 空闲语句池（注册表 LRU，migrate 联动自动失效） | 键 = bytea cast 后规范形（绑定形态分键）；仅参数化语句入缓存；26000/42P05 双自愈覆盖 PREPARE 事务性；IDbStmtCacheControl 契约与 sqlite 一致 | test_db_stmt_cache 十二组全绿 ✅；实测 pg 点查 2.22×（10.1K→22.4K ops/s）、scan 1.13×；sqlite 对照点查 2.12× |
| **C2 参数级批量绑定（Array DML 对标）** ✅ | `IDbArrayBinding`（可选能力，探测对象=IDbQuery，门面 DbArrayBinding）：每列一数组 + 可选 NULL 掩码，一次执行服务端展开 N 行 | pg = unnest 数组展开路径定案（binary COPY 留 P2 评估）；SQL 消费方显式 cast（`?::bigint[]`），适配器只做 ？→$N；fail-fast 全客户端侧：BeginBind 缺失/负行数/长度失配/掩码失配/重复列/NUL 元素拒绝；数组模式 Step 强制全覆盖（防 unnest(NULL) 静默零行），标量+数组混绑 last-wins；文本恒引号+转义、double 走 Schubfach 最短往返（区域设置无关，NaN/Inf 原生）；能力布尔 SupportsArrayBinding ⇔ 探测存在互证（conformance 钉死）；sqlite/mysql/odbc/redis 诚实缺席 | test_db_array_bind 十九组全绿 heaptrc 0 ✅（离线诚实契约 + pg 真机段：转义酷刑/NULL 往返/int64 边界/double 位还原/RETURNING/Reset 重臂/空批/千行/七例 fail-fast）；conformance 互证双后端 ✅；四路基准 pg 10K 行：array **29ms**（稳态）vs batch 174ms（**6.0×**）vs txloop 526ms（18×）vs autocommit 21.8s——≈345K 行/s |
| **C3 池硬化（HikariCP 三招）** ✅ | ①验证探活策略化（ValidateOnAcquire 已有，SELECT 1 硬编码跨三后端通用——诚实记录不重复造）②泄漏检测（LeakDetectionThresholdMs 租约持有超阈值入账告警，默认关）③获取栈采样（DebugAcquireStack ≤16 帧，报告附 BackTraceStrFunc 地址行） | 全部策略字段进 TDbPoolPolicy（尾部追加，纯增量）；**回调只在安全点冲刷**：任意检查点只扫描入账（Warned once），Acquire/Writer 入口或显式 `TDbPool.FlushDiagnostics` 才触发用户代码——归还路径在代理析构链内绝不调闭包（实测本工具链析构链内调 reference-to 回调会破坏堆，硬边界）；登记键 = 代理对象基址（本工具链 COM 接口指针带固定偏移 +72B，与对象基址混比必失配——簿记曾因此永久失配） | test_db_pool_v2 十五组全绿 ✅（含 heaptrc 双轮 0 泄漏）；bench_db_pool_stress 回归 read 25.2K ops/s 无退化 ✅ |
| **C4 基准门禁化** ✅ | 六个 bench 口径入册 docs/db/benchmarks.md：adapter_overhead(J1 开销比≤1.15×)/translate_complexity/batch_insert(C2 基线：pg batch 对 txloop 2.8×)/stmt_cache(sqlite point 2.39×、pg 2.12×)/blob_stream(J3 流式 +0.2MB vs 物化 +256MB)/pool_stress(J2 opens==Max 不变式 fail-fast) | bench 手动目标 Makefile（core/benchmarks/nextpas.core.db/），不进默认 verify，编译不带 heaptrc 插桩；pg 段程序内 NEXTPAS_PG_TEST_CONN 自门控；登记纪律：优化引用须同机同口径对照、±15% 内视为环境噪声 | 全量采集入册 ✅（Xeon E5-2696 v4/FPC 3.3.1 trunk/PG 17.11 同机）：J1 持平 ✅ J2 opens=4/4 ✅ J3 ✅ |
| **C5 sqlite 调优预设** ✅ | `TDbSqlitePragmas`（JournalMode/Synchronous/ForeignKeys 三态/CacheSize/MmapSize）进 ConnectSqlite 新重载；旧入口全 unset 行为零变化 | 安全缺省 = WAL+NORMAL+FK ON 仅显式传入生效；:memory: 过滤 journal_mode；**journal_mode 回读校验 fail-closed**（网络 FS 静默拒绝 WAL → decNotSupported，不静默降级）；mmap advisory（部分构建编译期禁用）；工厂内建 sqlite 驱动不烘 PRAGMA（WAL 持久化文件头，统一入口静默改写波及外部工具） | 门禁偏差：独立 test_db_sqlite_pragmas 七组全绿 heaptrc 0 ✅（原计划扩 test_db_sqlite——该门测裸 conn 层，pragmas 挂统一层，分门与 trace/factory 惯例一致）：默认钉子/过滤/显式组合/负 KiB/advisory/unset 零变化/stmt cache 正交 |
| **C6 SQL 词法扫描共享引擎（sqlscan 抽取）** ✅ | §7.2 候选触发条件实测超额满足——同一"字符串/标识符/注释状态机"在家族内复制**五份**（pg/mysql/odbc 三份占位符翻译 + pg.conn MaxParamIndex 计数 + pg.conn AppendByteaCasts bytea 装饰，后者头注自证与计数面同款）→ 收敛为纯函数单元 `nextpas.core.db.sqlscan`，四消费方改薄委托，公开签名零变化 | 方言词法集记录化（双引号/反引号/方括号标识符 + # 注释四布尔）；四公开面共享单遍私有引擎：TranslateQuestion（保形+槽位计划）/RenderDollar（$N 重算渲染）/MaxPlaceholderIndex（原始编号计数）/Decorate（命中原位追加后缀、源数字回显）；dollar/count 热路径零槽数组分配保 J1 开销比判据；受控边界成文不变（dollar-quote 体不识别、行注释仅 #10 终止、占位符数字无溢出防护、mysql 不处理 " 定界）；**历史怪癖随黄金语料一并成文**（块注释起始 `/` 不落输出；超 Int32 编号回绕记槽） | **换牙零漂移实证**：临时 harness 把五份原实现跑 30 案例语料落盘黄金 → 换牙后新引擎重放逐字节 diff 全等；test_db_sqlscan 十二组离线全绿 heaptrc 0（方言矩阵/混合编号不变式 [2,1,3,2]/字面量注释吞噬/方言隔离/装饰前导零回显与溢出失配/包装互洽/容量翻倍/CRLF 多字节）；回归 pg/mysql_adapter/odbc_adapter/array_bind（bytea 直接受害者）/stmt_cache/unified/conformance 七门全绿 ✅ |
| **C8 RTL 收敛 sweep（词汇表收口）** ✅ | 家族 39 单元 12→0 `uses SysUtils`（仅注释豁免），`text.conv/text.format/base.utils/core.time/core.errors` 全量替换，零反哺新增 | 四切片串行：C8-1 文本归一（factory/tx/migrate/db.pas/redis.transport）/ C8-2 池与时间（pool Format→TextFormat + GetTickCount64→core.time）/ C8-3 协议诊断（odbc.loader/adapter/redis.resp Format/IntToHex）/ C8-4 C ABI（mysql/redis adapter AnsiPtrToStr + FreeAndNil + Exception 别名）；Format 仅 `%s/%d/%%`，dollar/count 热路径零分配保 J1；C ABI 少一次 AnsiString 临时堆分配微优 | test_db_factory 15 + migrate_v2 10 + tx_v2 9 / pool_v2 19 / odbc_base 7+1skip + odbc_adapter 6+1skip + redis_base 11 + redis_adapter 15 / mysql_adapter 6+1skip + redis_subscribe 10 + pg 13 + sqlscan 12 + conformance 2 全绿 heaptrc 0；`grep -l "^\s*SysUtils"` 0 行 ✅ |

### 主线 D：国产数据库支持（总控指令入册）

目标：最最全的 db 模块必须覆盖国产数据库。工业级路径判断——国产主流
库大多兼容 pg/MySQL 线协议，**优先复用既有驱动 + 兼容性探测与文档化，
不为协议兼容库重写适配器；真不兼容的（如达梦）走专用驱动或 ODBC 网关
（A3/A4 的直接消费场景）**。全部真机验证经 `NEXTPAS_*_TEST_CONN` 环境
变量门控；无环境时只推进离线面（归一表/文档/连接指南），不假装验证。

| 分片 | 内容 | 关键设计点 | 门禁 |
|---|---|---|---|
| **D1 兼容性矩阵与连接指南** ✅ | openGauss / 人大金仓 KingbaseES / TiDB / OceanBase / PolarDB / TDSQL / GoldenDB 经现有 ConnectPostgres / ConnectMysql 的连通事实表（端口、方言开关、已知差异）；成文落点改为 docs/db/national-db-guide.md | 分类三档：①pg 协议系（openGauss/KingbaseES）②MySQL 协议系（TiDB/OceanBase MySQL 模式/PolarDB/TDSQL/GoldenDB）③私有协议（达梦 DM 等→D4/A3/A4 路径）；每库登记认证方式差异（如 openGauss 密码加密策略 sha256/md5）、SSL 要求、版本基线；跨库能力预期矩阵 + HY000+1062 缺口处置登记 | 文档门禁 ✅：national-db-guide.md 进 docs/db/README 地图；真机路径明标"理论/未验证"，无真机不写"已验证" |
| **D2 pg 协议系兼容层** | openGauss/KingbaseES 连通性 conformance 变体（env 门控）：错误归一表核对（SQLSTATE 沿用 PG 类目？）、能力矩阵实测回填、方言差异清单 | 复用 IDbCapabilities 自述 + conformance 全套件直接跑（B1 的直接收益：新后端零改造接入套件）；差异项（系统目录查询、savepoint 语义、批量返回值）逐条登记 §2.6 扩展节，不改统一契约除非确需增量 | NEXTPAS_OPENGAUSS_TEST_CONN / NEXTPAS_KINGBASE_TEST_CONN 门控的 conformance 全绿；离线侧归一表用例先行 |
| **D3 MySQL 协议系兼容层** | TiDB/OceanBase/PolarDB 经 ConnectMysql 的 conformance 变体；TiDB 的 savepoint/事务语义差异（乐观事务重试语义）与 B5 重试助手的组合验证 | TiDB 无真 savepoint（早期版本）/悲观事务模式差异登记；OceanBase MySQL 租户占位符与多语句支持核实；prepared stmt 二进制协议在 TiDB 的支持度实测（可能回落文本协议——诚实降级路径评估） | NEXTPAS_TIDB_TEST_CONN 等门控 conformance 全绿；差异清单成文 |
| **D4 达梦 DM 专用适配器** | 达梦 C 驱动（libdmdpi dlopen，复制 mysql.loader 多候选模式）或 ODBC 网关路径二选一（厂商 C API 可得性调研后定） | 错误码体系独立（非 SQLSTATE）→ ClassifyDm 归一表新增；SQL 方言 Oracle 系（序列/分页 ROWNUM）；占位符 ? 支持度核实；若走 ODBC 则 A3/A4 能力矩阵降级声明即答案 | test_db_dm 门禁（loader 离线组 + env 门控 conformance）；决策记录进 docs/adr |
| **D5 ODBC 错误归一 flavor 细化** ✅ | 收口 §2.11 登记缺口：MySQL 系驱动经网关把约束违约报 HY000+1062 → decUnknown（D1 指南同步登记） | db.err 新增 ClassifyOdbcEx：先按 ISO SQLSTATE 归一，再在连接建连期经 SQL_DRIVER_NAME / SQL_DBMS_NAME 命中 mysql/mariadb 词元时按 MySQL 服务端码位表**单调提精**（基础 unknown→采纳类目、同类泛约束→只补细分、永不降级矛盾）；「NativeError 跨驱动无语义」原则不破——达梦/GBase 等码位自成体系驱动行为与旧 ClassifyOdbc 完全一致；建连失败路径恒 False（连接对象未建） | test_db_odbc_adapter 新增 classify-ex-flavor 组：1062 头条回归 + 约束/事务/超时/授权/语法/容量全族采纳 + 23000 泛码提精 + 23505/40001 不被覆盖 + flavor 关闭与未知/负数码位欠归一，全部离线断言绿 heaptrc 干净 ✅ |

**D 线验收判据**：每个协议兼容库有连接指南 + env 门控 conformance
结果登记（跑过=绿，没跑过=明说未验证）；达梦有明确技术路线决策记录。
优先级排序建议：openGauss/KingbaseES（政企存量最大）→ TiDB →
OceanBase → 达梦 → 其余。

### 排期原则

A/B/C 三线并行度由 lane 纪律决定（本 lane 串行推进时建议顺序：
**C1 → B5 → A1/A2 → B1 → C3 → A3/A4 → B2 → B3 → C4 → A5 → B4 → C2 → C5 → B6 → B7**）。
排序依据：正确性增强 > 需求最密的后端 > 观测性 > 杠杆型后端 >
异步面（依赖最晚就绪）。每片 landing 后回填本文状态列。
D 线（国产数据库）插在 A5 之后推进（D1 连接指南可随时先行；
D2/D3 依赖 pg/mysql 驱动稳定即已满足）。

---

## 4. 明确不做（维持基线 §9，新增四条）

- XA / 分布式事务（JDBC 世界的历史包袱，微服务时代用 outbox/saga）
- 分库分表中间件、读写分离路由（pool 已给读池原语，编排是消费方事）
- SQL 解析器 / 方言转换器（QueryBuilder 拒绝的延伸）
- ORM / 反射行映射 / 编译期查询校验（维持 INC-5 拒绝清单）

---

## 5. 文档完善清单（随分片同步）

- [x] `core/docs/db/README.md` 模块入口（本次新增：快速上手 + 特性矩阵；C8 增词汇表行）
- [x] CONTRACT §2.x 随每片同步 + §6 增 C8 节（2026-08-28）
- [x] `docs/db/benchmarks.md`（C4 产出：基准口径册）
- [x] 各新后端一页指南（对齐 sqlite.md/pg.md 体例：A2/A4 产出）
- [x] 本路线图每片 landing 回填状态 ✅（C6/C8 已回填§7.1/C线表）

---

## 6. 证伪条件

- 若 conformance 套件无法在不阉割的前提下接入 MySQL（如错误归一
  无法覆盖其错误模型），则统一层抽象有洞，停下来修抽象而不是绕。
- 若 ODBC 适配器的能力降级矩阵超过 1/3 条目不可探测，则 ODBC 网关
  价值主张不成立，砍掉 A3/A4 转 DuckDB 专属适配器评估。
- 若异步挂载（B6）实测引入 P99 尾延迟劣化 >20%，则诚实回到同步模型
  并在契约里写明"本模块是同步 API"，不硬留半吊子异步面。

---

## 7. 模块抽取与 FPC RTL 收敛账本（总控指令）

两条仓库规范在本家族的落地账本：
**不准直接依赖 FPC RTL——经 nextpas.core 解决；缺失能力反哺
nextpas.core；可复用代码考虑抽成新模块。**

### 7.1 RTL 收敛

- **政策现状**：双编译器过渡期允许 `uses SysUtils` 经 stub 桥接
  （CLAUDE.md），但方向是最终消除；**新写的代码一律优先
  nextpas.core 既有设施**。
- **已反哺**：`nextpas.core.text.conv.AnsiPtrToStr`（PAnsiChar→string
  统一入口，nil 安全）——源自 db 家族 PAnsiChar 读回硬边界纪律，
  此前各 adapter 各自为政（StrPas/强转混用）。消费方逐步切换。
- **收敛路径**：text.conv 已有 IntToStr/StrToIntDef/Trim/LowerCase/
  Format(→text.format) 全套对应物；C 线架构收口时逐单元把 db 家族
  implementation uses 的 SysUtils 面替换掉，完成条件 = 家族全部单元
  不再引用 FPC RTL 单元名。登记为 C8（RTL 收敛 sweep）排期占位。
- **C8 完成（2026-08-28）**：家族 39 单元 12→0 `uses SysUtils`（仅注释 3 行豁免；`grep -l "^\s*SysUtils"` 0），词汇表收敛至 `text.conv/text.format/base.utils/core.time/core.errors` 全量替换，零反哺新增，见 `2026-08-28-db-v3-c8-rtl-convergence-proposal.md`（四切片独立 landing：C8-1 文本归一/C8-2 池与时间/C8-3 协议诊断/C8-4 C ABI，全量 gates 全绿 heaptrc 0）。
- **红线**：不得为此新建"FPC 兼容层"单元（维持基线禁令）；只允许
  反哺进既有 core 模块或按四件套范式立新模块。

### 7.2 抽取候选（形成新模块的评估对象）

| 候选 | 现状 | 建议 |
|---|---|---|
| SQL 占位符扫描器 / 槽位计划 | ~~三份近似实现~~ **实测五份**（C6 复核时发现 pg.conn 计数面与 bytea 装饰面同款复制） | ✅ 已抽 `nextpas.core.db.sqlscan`（V3-C6 落地，黄金语料逐字节零漂移换牙；触发条件"第四份复制"超额满足） |
| DSN key=value 解析 | 仅 mysql 侧持有（odbc 直透、pg conninfo 原生、sqlite 路径直用） | 不抽（单点实现，无重复税） |
| 错误归一表 | 已收敛于 db.err 单一纯函数表（ClassifySqlite/Pg/My/Odbc） | ✅ 先例即答案：跨后端语义归一只此一处 |
