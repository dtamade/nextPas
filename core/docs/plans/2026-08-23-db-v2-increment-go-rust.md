# nextpas.core.db v2 增量设计——Go/Rust 生态对标吸收（2026-08-23）

> 基线：`2026-08-23-db-v2-architecture.md`（其 §10 为对标复核结论）。
> 本文只写**增量**：相对 v2 基线新增/修订的契约形状、实现要求与门禁，
> 全部为纯增量、对已落地单元（db.base/db.intf/db.err/两适配器）零破坏。
> 每条增量标注落地批次与来源先例，可独立 landing。

---

## 1. 增量总览

| 编号 | 增量 | 来源先例 | 落地批次 | 破坏性 |
|---|---|---|---|---|
| INC-1 | 池策略补 `IdleTimeoutSec` / `MinConnections` | Go SetConnMaxIdleTime；sqlx PoolOptions | V2-S4 ✅ | 无 |
| INC-2 | 批执行双目标：多语句合并 → 流水线评估 | pgx.Batch | V2-S3 ✅（Tier1） | 无 |
| INC-3 | 透明语句缓存 + 失效控制能力接口 | sqlx 连接级语句缓存 | V2-S5 ✅（sqlite 侧）+ V3-C1 ✅（pg 侧） | 无（可选能力） |
| INC-4 | 异步挂载硬规则 + 预留契约形状 | database/sql context 升级教训 | 预留位 | 无 |
| INC-5 | 拒绝清单固化 | diesel / sqlx-rs query! / StructScan 等 | 已入基线 §10.3 | 无 |
| INC-6 | 列类型精化决策规则（Bool/时间/JSON） | 基线 §11-G1 自审 | V2-S1 起 | 无（尾部追加） |
| INC-7 | 连接选项 + 查询级超时 | 基线 §11-G4 自审；sqlx connect options | V2-S4 前 | 无（重载） |
| INC-8 | 增量大对象读写（pg lo_* + sqlite3_blob_*） | VCL CreateBlobStream 能力差（基线 §12） | V2-S7 ✅ | 无（可选能力） |

---

## 2. INC-1 池策略六字段（V2-S4）

```pascal
TDbPoolPolicy = record
  MaxReadConnections: Integer;   // 读连接硬上限；耗尽时 AcquireTimeoutMs>0 则排队，否则立即抛 decCapacity
  AcquireTimeoutMs: Integer;     // >0 启用等待队列（sync.semaphore 计数信号量实现）
  ValidateOnAcquire: Boolean;    // 取出前轻量探活（sqlite: PRAGMA quick_check 级别探针不做，用句柄存活即可；pg: PQstatus）
  MaxLifetimeSec: Integer;       // 最长寿命，Acquire 时惰性到期→关闭换新；0 = 不限
  IdleTimeoutSec: Integer;       // 空闲超时回收；0 = 不限
  MinConnections: Integer;       // 预热下限，Create 即建满；0 = 惰性建连
end;
```

### 语义细则

- 空闲回收无看门狗线程（诚实同步模型，不引后台定时器）：空闲连接
  记录归还时刻；惰性检查点有两处——Acquire 取出时、Return 归还时
  （超阈值的直接关闭不入队）。代价是空闲连接最多多活一个检查周期，
  换取零线程。sqlx 的后台 reap 任务在此明确不复制。
- **MinConnections 预热失败即 fail-fast**：Create 时无法建满下限直接抛
  EDbError（decConnection），不给半可用池。
- **生命周期优先级**：Acquire 取出依次校验 空闲超时 → 寿命 → 探活，
  任一不过即弃用换新；等待队列由 `sync.semaphore` 支撑，超时抛
  decTimeout。
- 空闲列表 LIFO 复用热连接；簿记临界区手工 try/finally——归还路径
  要求"先出锁、后放槽位信号量"，Guard 的过程作用域表达不了该顺序
  （见下方落地注记 3）。
- 门禁：conformance×2 + pool 压测（含耗尽/超时/预热失败三边界）。

### 落地状态（2026-08-23）

**已落地**：`nextpas.core.db.pool` + 门禁 `test_db_pool_v2` 十一组用例
全绿（复用身份/耗尽即抛/排队超时/Discard 弃置/预热/预热 fail-fast/
空闲惰性回收/单写者/关闭语义/代理能力委托/pg 冒烟），两阶段 heaptrc
0 unfreed。落地中三项实现决策偏离本节原稿，记录如下：

1. **池核心态引用计数**（超出原规格的生命周期安全）："所有权即归还"
   契约下，消费方可先 Free 池再让租约接口自然出作用域——裸核心态
   必然被在途代理析构踩中悬垂（门禁实证 AV，且真实异常被析构 AV
   掩盖）。解法：核心态抽成 `IDbPoolCore`（GUID …FE007），每个在途
   代理持强引用；门面 Free = Shutdown（停出借 + 清空空闲），在途租约
   归还时直接销毁底层连接（排空语义，不等待），最后一个代理释放后
   核心态自毁。语义对齐 Go `DB.Close()`：不等待在途查询、归还即关。
2. **空闲队弃用 collections.deque，改编译器托管动态数组**：FPC 泛型
   容器对含接口字段的 record 按裸内存搬移，入队不加引用计数 → 归还
   后底层连接被析构、队列持悬垂指针（heaptrc 下必 AV，实证）。动态
   数组的 SetLength/元素赋值走托管复制，计数正确。→ 反哺线索（报备
   总控）：collections 泛型容器需补 managed record 的接口字段搬运
   语义，或显式文档化此限制。
3. **簿记风格**：原稿计划新代码统一 `sync.scoped.Guard`；实际保留手工
   try/finally——归还路径必须"先 Release 锁、后 Release 槽位信号量"
   （避免唤醒线程立即撞锁），Guard 的词法作用域无法表达该顺序。
4. **v1 sqlite 薄池收编改判至 G2**：`TSqlitePool` 是裸对象所有权
   （手工 Release）+ WAL/busy_timeout 初始化，与新池的接口所有权模型
   无法无适配层转调；强行桥接（从接口代理拆裸指针回传消费方）恰是
   本次修掉的所有权混用 bug 类。改判：随 G2 消费方迁移一并删除 v1，
   本期不动。

压测（性能门禁）：`bench_db_pool_stress.lpr`——读路径 8 线程 × 3000
轮锤 4 连接池：24000 ops / 403ms ≈ 59.5K ops/s，工厂建连数恒等于 4
（零泄漏式新建，100% 经空闲队复用）；写槽争用 800 轮零异常逃逸；
heaptrc 0 unfreed。数据入基线附录。

---

## 3. INC-2 批执行双目标（V2-S3）

### 契约形状（db.intf 新增可选能力）

```pascal
IDbBatchExecutor = interface ['{B41F7E52-8D93-4C56-A1E0-72F4C9A80B31}']
  { 单事务内顺序执行；任一步失败整批回滚并重抛首个错误（savepoint
    混合模型下经 WithTransaction 天然获得）。Steps 数组由消费方持有。 }
  procedure ExecuteBatch(const ASteps: TArray<string>);
end;
```

### 两层实现路线（pg 侧）

**Tier 1 已落地（2026-08-23）**：IDbBatchExecutor 双后端实现（sqlite
单事务逐条保留步骤级错误定位；pg 合并单次 Exec 单往返），conformance
新增原子性/空批/嵌套三用例双后端绿；万行基准：pg batch 200ms vs
autocommit 21846ms（109×）、vs txloop 3.8×——往返税实证，数据入基线附录。

- **Tier 2（评估后定）**：真流水线（发送与消费交叠）需 PQsendQuery /
  PQconsumeInput 异步 ffi 面。当前 Tier1 与 COPY 差距待 COPY 基准补测；
  仅当显著差距才立项 Tier 2，否则记入"明确不做"。
- 门禁：conformance×2 ✅ + bulk-insert 三路对比已入附录 ✅。

---

## 4. INC-3 透明语句缓存 + 控制能力（V2-S5）

### 设计立场：缓存是连接的实现细节，不是消费方义务

预编译语句缓存对消费方**完全透明**——`Query()` 内部走 LRU
（`collections.lrucache`，键 = 原始 SQL 文本，容量按连接选项），命中即
复用 prepared 句柄。所有权仍归连接（D3），消费方零手工释放。

### 控制能力接口（DDL 失效场景）

```pascal
IDbStmtCacheControl = interface ['{7C9D2E18-3A64-4B7F-9E25-D81C04FA67B9}']
  procedure Clear;            { DDL/迁移后整体失效（migrate 完成自动调用）}
  function Size: Integer;
  function HitRate: Double;   { 诊断用，不做行为依据 }
end;
```

- sqlite 收益最大（prepare 成本高、reset 复用便宜），S5 先落 sqlite，
  pg 按 D1 探测协议后补。
- `Migrate()` 返回值 > 0 时自动对所经连接调用 Clear——INC-2/迁移与
  缓存的联动点，防 prepared 句柄引用已变更 schema。
- 门禁：conformance×2 + bench 对照（缓存命中 vs 直 prepare，数据入附录）。

### 落地状态（2026-08-23）

**已落地**：sqlite 侧透明缓存 + `IDbStmtCacheControl` + migrate 自动
Clear。门禁 `test_db_stmt_cache` 九组全绿（透明性对照/嵌套安全/绑定
卫生/能力语义/小容量驱逐/migrate 联动/对抗序生命周期/schema 变更
韧性/pg 探测降级），heaptrc 0 unfreed；conformance×2 以"默认开启
后十门禁全绿"形态通过（更强：既有套件全部经缓存路径复跑）。
落地中四项实现决策记录如下：

1. **空闲语句池语义（对本节 LRU 表述的精化）**：标准 LRU 的 Get 是
   "命中不移除"——若照搬，同 SQL 第二个活动查询会拿到同一底层句柄，
   交叉 Step 即静默损坏。实际语义为**借出即移除**（Get 取引用 +
   Remove 放手），归还回插；LRU 只管空闲驱逐。同 SQL 并发活动查询
   各持独立实例，嵌套语义与直连一致（专设回归守卫用例）。
2. **托管值形态**：LRU 值用接口型 holder（持 TSqliteQuery），驱逐/
   Clear/析构路径由编译器引用计数释放底层语句——泛型容器裸搬移
   教训（INC-1 注记 2）的正面应用。
3. **对抗序生命周期**：查询包装持连接的私有归还通道接口强引用
   （GUID …FE009）：消费方先释放连接再释放查询时连接仍存活可安全
   回插；无环（连接只缓存空闲语句，从不引用在途查询）。归还路径
   执行 Reset + ClearBindings（ffi 增补 sqlite3_clear_bindings），
   绑定不跨借出泄漏（守卫用例覆盖）。
4. **collections 门面透传缺口（反哺线索二，报备总控）**：
   `nextpas.core.collections` 门面对泛型类型名（ILruCache）不可见，
   具名特化必须直连 `collections.lrucache.intf` 子单元（最小复现实
   证）。建议门面补泛型别名 re-export 或文档化该限制。

容量经 `ConnectSqlite(path, capacity)` 可选参数注入（默认 64，词汇
常量 DEFAULT_SQLITE_STMT_CACHE_CAPACITY 归 sqlite.base 单源，pg/mysql/odbc/dm
各归其 base，Redis 诚实缺席不设共享常量——分治于 db.base 聚合之外）；<=0 关闭走直通。

基准（附录入册）：点查 5 万次 nocache 316ms / cached 205ms =
**1.54×**（hit_rate=1.0000）；多行扫描 2000 次 102ms / 98ms ≈ 1.04×
（步进主导场景收益小）。收益随语句复杂度增长（prepare 成本与 SQL
解析/规划规模成正比），简单语句微基准是下界而非上界。

---

## 5. INC-4 异步硬规则与预留形状（不实现，冻结契约方向）

**硬规则**（进 D8，违反即评审打回）：核心面 `IDbConnection` /
`IDbQuery` 的方法签名**永久冻结**为同步形态；取消/超时/后台执行等
能力只能以新增 GUID 能力接口挂载，经 QueryInterface 探测。

预留形状（仅为防未来走形，本期不进 intf 单元、不占 GUID 分配流程）：

```pascal
{ 形状备忘（非本期内含物）：
  IDbAsyncExec = interface
    function ExecAsync(const ASql: string;
      const ACancellation: ICancellationToken): <awaitable>;
  end;
  ICancellationToken 直接采用 nextpas.core.async.cancellation 既有类型，
  绝不自造。 }
```

Go database/sql 的教训（v1 无 ctx、v2 全签名破坏升级）是本规则的
唯一出处；rusqlite/rust-sqlx 把 async 作为独立 feature 而非改核心
trait 的做法是同构佐证。

---

## 6. INC-5 拒绝清单

已在基线 §10.3 固化（diesel DSL / query! 宏校验 / 反射行映射 /
命名参数糖 / 二进制协议），本文不重复，仅声明：**后续 slice 不得
在未修订 §10.3 的前提下引入上述五类机制。**

---

## 6a. INC-6 列类型精化决策规则（V2-S1 起）

现状 `TDbColumnType = (dbcNull, dbcInteger, dbcFloat, dbcText, dbcBlob)`
在布尔/时间/JSON 上失真（pg 原生 bool OID 16 现归 dbcText）。

**决策规则**（防拍脑袋加枚举）：

1. conformance 套件先行列类型往返用例，用例红点 = 加枚举值的唯一理由；
   没有红点不加值。
2. 第一优先 `dbcBool`：两后端都有自然映射（sqlite INTEGER<>0 /
   pg bool），MapColumnType 各加一分支即可。
3. 时间/时间戳：文本协议天然给出 ISO8601 文本，暂走 dbcText + 消费方
   解析（`time.iso8601` 已有）；出现真实消费需求再评估。
4. jsonb/json：同上暂走 dbcText；不引入半结构化类型体系。
5. 枚举值一律尾部追加，不动既有序数（错误载荷与列类型可能被持久化
   到日志/诊断，序数稳定是隐性契约）。

**落地状态（V2-S8，2026-08-23）**：`dbcBool` 已按规则 1/2 落地——
conformance bool 往返用例先行（红点实证：pg bool 报 dbcText、
sqlite BOOLEAN 列报 dbcInteger），随后 pg OID 16 与 sqlite 声明子串
各加一分支。附带两项语义收敛：NULL 值一律报 dbcNull（行级信号，
两后端同契约——pg 此前 NULL 行回落列 OID 失真）；bool 值读取经
GetInt64 归一 1/0（pg 文本协议 't'/'f' 由适配器翻译，GetText 保持
原文并登记 §2.6 后端差异）。时间/JSON 维持规则 3/4 不动。

---

## 6b. INC-7 连接选项 + 查询级超时（V2-S4 前）

池只管获取超时；查询本身挂死无解是 G4 缺口。引入选项 record + 工厂
重载（纯增量，旧签名保留为缺省选项转发）：

```pascal
TDbConnectOptions = record
  BusyTimeoutMs: Integer;      // sqlite busy_timeout（锁等待）；pg 映射 connect_timeout
  StatementTimeoutMs: Integer; // pg SET statement_timeout（会话级）；sqlite 无对应机制，非 0 值忽略并在文档标注
end;

function ConnectSqlite(const APath: string;
  const AOptions: TDbConnectOptions): IDbConnection; overload;
function ConnectPostgres(const AConnInfo: string;
  const AOptions: TDbConnectOptions): IDbConnection; overload;
```

- 语义诚实表：sqlite 的 busy_timeout 是锁等待不是语句超时，两者不互相
  冒充——字段注释即契约，conformance 超时用例按后端分别断言。
- 门禁：conformance×2 超时用例（pg statement_timeout 触发 decTimeout；
  sqlite busy_timeout 触发后归一为 decTimeout/busy 类目）。

**落地状态（V2-S8，2026-08-23）**：`TDbConnectOptions` + 工厂重载已
落地，旧签名保留为 `Default`（双 0）转发。conformance 超时用例按本节
门禁要求兑现：pg 段 statement_timeout=100ms 撞 pg_sleep(1s) 归一
decTimeout；sqlite 段 busy_timeout=50ms 文件库双连接争用（持锁者
BEGIN IMMEDIATE 不提交）归一 decTimeout，并自证 PRAGMA 值生效。
语义诚实表原样入 CONTRACT §2.1。

---

## 6c. INC-8 增量大对象读写（V2-S7）

VCL `CreateBlobStream` 是大对象场景最后一块能力差（基线 §12.2）：当前
GetBlob 全量 TBytes，>64MB 场景内存随体积翻倍。目标 = 流式读写、定位
访问、**内存恒定不随 blob 体积线性增长**。

### 实现面（两后端各按原生机制，同一薄能力接口）

```pascal
IDbLargeObject = interface ['{E5A1C7D2-94B3-46F8-A0C6-31B7D95E02F4}']
  { 打开既有大对象流：sqlite 为已存在行的 blob 列增量句柄；
    pg 为 large object OID。读写共享同一接口。 }
  function Read(ABuf: PByte; const ACount: SizeUInt): SizeUInt;
  function Write(ABuf: PByte; const ACount: SizeUInt): SizeUInt;
  function Seek(const AOffset: Int64; const AOrigin: TDbSeekOrigin): Int64;
  function Size: Int64;
end;

function OpenLargeObject(const AConn: IDbConnection;
  const ASql, ABlobColumn: string; const ARowKey: Int64): IDbBlobStream;
```

（精确签名 S7 设计注记定稿；本节冻结需求：流式、可定位、恒定内存、
事务耦合规则显式——sqlite blob 句柄在 schema 变更后失效需 reopen；
pg lo_* 经 libpq fastpath（PQfn），loader 需增补 lo_open/lo_read/
lo_write/lo_lseek/lo_unlink/lo_creat 符号。）

### ffi 增量清单

- `db.sqlite.ffi`：sqlite3_blob_open/blob_read/blob_write/blob_bytes/
  blob_reopen/blob_close 六函数。
- `db.pg.loader`：lo_* 系 libpq 符号。

门禁：两后端 conformance 大对象子集 + >64MB RSS 恒定探针（基线 §12.4）。

### 落地状态（2026-08-23）

**已落地**：统一流面 `IDbBlobStream`（Read/Write/Seek/Size，GUID …FE00A，
接口释放即关闭）+ 按存储模型分面的开启能力——pg `IDbLargeObjectControl`
（规格 GUID，CreateLO/OpenLO/UnlinkLO）与 sqlite `IDbRowBlobControl`
（OpenRowBlob，FE00B）。门禁 `test_db_largeobject` 八组全绿（能力分面
探测/分块往返/Seek 语义/EOF 语义/定长契约/重开持久性/失败打开/pg LO
全流程），heaptrc 0 unfreed。落地决策记录：

1. **两模型分面而非伪统一**：sqlite 是行内 blob 单元的定长区间 I/O
   （写不得越界，占位经 zeroblob(N) 预留；行更新/schema 变更失效须
   重开），pg 是独立 OID 对象（可扩容）。伪装成单一控制面是 VCL 式
   错误；统一的是流语义，开启路径按模型诚实分面。
2. **事务耦合不对称且 fail-fast 强制**（libpq 实现决定）：CreateLO/
   OpenLO 要求活动事务（描述符事务末失效）；**UnlinkLO 反向要求事务
   外**——其客户端实现自管 BEGIN/END 执行清理 SQL，事务内调用会
   嵌套并提前终结外部事务。两向均显式检查。
3. **lo_unlink 返回值语义**：成功 = 1 而非常规 0/正数惯例（-1 失败）；
   适配器按 `< 0` 判错。经验探针实证（初版 `<> 0` 判错把成功当失败，
   掩盖在空错误消息下，靠序列化二分探针定位）。
4. **孤儿异常教训（模块级实现纪律）**：手工构造异常对象传入"转抛另一
   异常"的辅助过程 = 原对象无人释放（异常对象非引用计数）。BlobCheck
   初版经 RaiseSqliteAsDb 间接转抛泄漏 2 块/次，符号化堆栈定位后改为
   单次直接构造 raise。凡"捕获 A 抛 B"必须经 on E: 托管所有权。

RSS 恒定探针（`bench_db_blob_stream.lpr`，判据入基线附录）：128MB blob
全量物化 RSS 峰值增量 **256.2MB**（线性税对照）vs 流式分块读写 **0.2MB**
（预算 16MB）；pg LO 64MB 客户端增量 **0.3MB**。

---

## 7. 兼容性与迁移

- 八条增量全部加法式：已落地单元零签名变化；新能力均经
  QueryInterface 探测，未实现 = 探测失败，消费方直线降级。
- 消费方感知时点 = 各自 opt-in 使用新工厂选项/能力接口之时；
  9 个外部项目仍在旧 shim 上，不受任何影响。
- G2 重构窗口顺带向消费方披露 INC-1..3 的 opt-in 入口即可，
  无强制动作。

## 8. 门禁矩阵

| 增量 | 功能门禁 | 性能门禁 |
|---|---|---|
| INC-1 | test_db_pool_v2 十一组（含边界三态） ✅ | bench_db_pool_stress opens=MaxRead 不变量 ✅ |
| INC-2 | conformance×2 + 批回滚原子性用例 | bulk-insert 三路对比 |
| INC-3 | test_db_stmt_cache 九组 + 十门禁全绿（默认开启复跑） ✅ | bench_db_stmt_cache 点查 1.54× ✅ |

**V3-C1 pg 侧落地注记（2026-08-23）**：pg 连接默认带服务端 prepared
statement 缓存（`PQprepare/PQexecPrepared`，注册表 LRU，键 = bytea
cast 后规范形 SQL——不同绑定形态自然分键；仅参数化语句入缓存）。
与 sqlite 实现形态不同但 `IDbStmtCacheControl` 契约完全一致。pg 特有
的自愈双保险：PREPARE/DEALLOCATE 均为事务性 → 执行期 26000（回滚
撤销语句）忘登记换名重建、prepare 期 42P05（驱逐 DEALLOCATE 在已
回滚事务内失效）先 DEALLOCATE 再重试，消费方零感知。门禁
test_db_stmt_cache 扩至十二组（能力反转 + 键分离 + 回滚自愈 +
migrate 联动 pg 版），bench_db_stmt_cache 增 pg 对照段。
| INC-4 | ——（本期无代码） | —— |
| INC-6 | 列类型往返 conformance 用例（红点驱动加值） | —— |
| INC-7 | conformance×2 超时用例（按后端分别断言） | —— |
| INC-8 | test_db_largeobject 八组（两后端各自机制断言） ✅ | bench_db_blob_stream RSS 恒定 0.2MB @128MB ✅ |

每片独立可 landing；landing 流程同仓库规范（候选分支 +
landing-check + ff-only）。
