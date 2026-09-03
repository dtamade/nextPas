unit nextpas.core.db.intf;

{** @desc nextpas.core.db L3 家族：统一接口契约。
       只依赖 db.base；具体后端在各自的 *.adapter 单元实现这些接口。

       所有权模型：对外一律 interface（COM 引用计数），消费方不手写
       Free。IDbConnection.Query 返回的 IDbQuery 由引用计数释放。

       约定：
       - 参数化 SQL 一律使用顺序 ? 占位符（1-based 绑定索引对应第 k
         个 ?）；后端方言翻译由适配器负责（pg: ? -> $N）。
       - Exec 不做参数绑定，SQL 原文透传。
       - 绑定索引 1-based；列索引 0-based。
       - Raw 是逃生舱（sqlite3* / PGconn*），仅限抽象层未覆盖的特性；
         使用纪律见 core/docs/db/CONTRACT.md。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.base;

type
  {** 参数化语句 + 行游标（对齐两后端现状：query 对象合一两者）。 *}
  IDbQuery = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE001}']
    procedure BindText(AIndex: Integer; const AValue: string);
    procedure BindInt64(AIndex: Integer; const AValue: Int64);
    procedure BindDouble(AIndex: Integer; const AValue: Double);
    procedure BindBlob(AIndex: Integer; const AValue: TBytes);
    procedure BindNull(AIndex: Integer);

    { True=有行；首次调用触发执行 }
    function Step: Boolean;
    procedure Reset;
    function ColumnCount: Integer;
    function ColumnName(AIndex: Integer): string;
    function ColumnType(AIndex: Integer): TDbColumnType;
    function IsNull(AIndex: Integer): Boolean;
    function GetInt64(AIndex: Integer): Int64;
    function GetDouble(AIndex: Integer): Double;
    function GetText(AIndex: Integer): string;
    function GetBlob(AIndex: Integer): TBytes;
  end;

  {** 事务控制面。由支持事务的连接适配器实现；泛化事务助手
      （nextpas.core.db.tx）经 QueryInterface 取用。
      手动控制面语义（v1 计数式，与自动助手 savepoint 模型分工见
      CONTRACT.md §2.3）：Begin 加深计数、内层 Commit 只降计数、
      任意深度 Rollback 回滚整个事务并清簿记。
      TxDepth = 真实 SQL 事务深度（savepoint 层不计入）。 *}
  IDbTxControl = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE002}']
    procedure BeginTxn(const AImmediate: Boolean = False);
    procedure CommitTxn;
    procedure RollbackTxn;
    function InTransaction: Boolean;
    function TxDepth: Integer;
  end;

  {** 保存点控制（可选能力；两后端原生支持 SAVEPOINT）。
      与 IDbTxControl 组合实现嵌套事务的部分回滚语义：
        Savepoint(A) -> 出错段 -> RollbackTo(A) 撤销出错段 ->
        ReleaseTo(A) 并入父事务。
      命名约束 [A-Za-z0-9_]+，违规抛 EDbError。 *}
  IDbSavepointControl = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE004}']
    { 建立命名保存点 }
    procedure Savepoint(const AName: string);
    { 回滚到保存点（保存点本身保留，可继续 RollbackTo） }
    procedure RollbackTo(const AName: string);
    { 释放保存点（其后的变更并入父事务） }
    procedure ReleaseTo(const AName: string);
  end;

  {** 批量执行（可选能力）。单事务内顺序执行完整 SQL 步骤：
      任一步失败整批回滚并重抛首个错误；空列表为无操作成功。
      可嵌套——已在外层事务内时按计数语义并入外层（失败由最外层
      定夺）。实现注记：pg 侧合并为单次往返，sqlite 侧逐条执行，
      语义两端一致。 *}
  IDbBatchExecutor = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE005}']
    procedure ExecuteBatch(const ASteps: TDbSqlSteps);
  end;

  {** 语句缓存控制能力（连接实现按需支持，经 QueryInterface 探测）：
      预编译语句缓存对消费方完全透明（Query 内部复用空闲句柄，
      借出即移除——同 SQL 并发活动查询各自持有独立实例），本接口仅供
      失效控制与诊断。DDL/迁移后建议整体失效；Migrate 应用成功后
      自动调用 Clear。 *}
  IDbStmtCacheControl = interface
    ['{7C9D2E18-3A64-4B7F-9E25-D81C04FA67B9}']
    procedure Clear;            { DDL/迁移后整体失效 }
    function Size: Integer;     { 当前空闲缓存条数（不含在途借出） }
    function HitRate: Double;   { 命中率 0..1；诊断用，不做行为依据 }
  end;

  {** 参数级批量绑定（V3-C2，可选能力，QueryInterface 于 IDbQuery
      对象探测；门面 DbArrayBinding 统一探测并允许 nil）。语义：
      单条参数化 SQL 的每个 ? 绑一个"列数组"而非标量，一次执行由
      服务端展开为 N 行——pg 走 unnest 数组展开路径，10K 行单次
      往返（对照 IDbBatchExecutor：那是多语句往返压缩的通用路径；
      本面是单语句参数级快路径，两者分工见 CONTRACT §2.16）。
      用法（SQL 由消费方显式写目标类型 cast）：
        INSERT INTO t(a, b) SELECT * FROM unnest(?::bigint[], ?::text[])
        BeginBind(N); BindInt64Column(1, ...); BindTextColumn(2, ...); Step;
      契约钉死项：
      - BeginBind 先行且必填：声明本批行数；此后每列长度与之全等，
        违者 fail-fast（客户端侧拒绝，不触网）。
      - 标量绑定与数组绑定可混用（常量列 + 展开列）；数组模式激活
        后 Step 强制全覆盖检查——任何占位符未绑定即抛，防 unnest(NULL)
        静默零行。
      - NULL 掩码（可选重载）：True = 该行 NULL，值被忽略；掩码长度
        同样必须与行数全等。
      - Reset + Step 重执行同一批（参数持久）；INSERT ... RETURNING
        可读回展开行。
      - 文本元素含 NUL(#0) 拒绝（文本协议会在 NUL 截断，静默损坏
        不可接受）；转义规则（引号加倍/反斜杠）由实现负责，对消费方
        透明。
      仅 pg 实现（v1）；sqlite/mysql/odbc/redis 探测失败 = 未支持，
      能力布尔 SupportsArrayBinding 与接口存在性互证（conformance 钉死）。 *}
  IDbArrayBinding = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE00C}']
    { 声明本批行数（后续每列长度必须与之全等）；可重复调用重新开批 }
    procedure BeginBind(const ARows: Integer);
    procedure BindInt64Column(const AIndex: Integer;
      const AValues: TDbInt64Array); overload;
    procedure BindInt64Column(const AIndex: Integer;
      const AValues: TDbInt64Array; const ANullMask: TDbBoolArray); overload;
    procedure BindDoubleColumn(const AIndex: Integer;
      const AValues: TDbDoubleArray); overload;
    procedure BindDoubleColumn(const AIndex: Integer;
      const AValues: TDbDoubleArray; const ANullMask: TDbBoolArray); overload;
    procedure BindTextColumn(const AIndex: Integer;
      const AValues: TDbStringArray); overload;
    procedure BindTextColumn(const AIndex: Integer;
      const AValues: TDbStringArray; const ANullMask: TDbBoolArray); overload;
    procedure BindBoolColumn(const AIndex: Integer;
      const AValues: TDbBoolArray); overload;
    procedure BindBoolColumn(const AIndex: Integer;
      const AValues: TDbBoolArray; const ANullMask: TDbBoolArray); overload;
  end;

  {** 打开的大对象流（INC-8，两后端统一流面）：接口释放即关闭。
      Read 返回实读字节数（0 = EOF）；Write 短写即异常。
      后端差异显式入契约：sqlite 为行内 blob 单元定长区间（写不得
      越过单元末尾，占位经 zeroblob(N) 预留；行更新/schema 变更使
      句柄失效须重新打开）；pg 为 large object OID 句柄（可扩容；
      描述符在事务结束时失效，操作须存活于事务内）。 *}
  IDbBlobStream = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE00A}']
    function Read(ABuf: PByte; ACount: SizeUInt): SizeUInt;
    procedure Write(ABuf: PByte; ACount: SizeUInt);
    function Seek(AOffset: Int64; AOrigin: TDbSeekOrigin): Int64;
    function Size: Int64;
  end;

  {** pg 大对象控制能力（OID 存储模型）：CreateLO 建空对象返回 OID，
      OpenLO 开流，UnlinkLO 删除。事务耦合不对称（libpq 实现决定）：
      CreateLO/OpenLO 要求活动事务——描述符在事务结束时失效，消费方
      以 WithTransaction 包裹；UnlinkLO 反之要求**事务外**调用——
      其客户端实现自管 BEGIN/END，事务内调用会提前终结外部事务。
      两者均 fail-fast 强制。sqlite 走 IDbRowBlobControl（cell 模型），
      两模型不互仿。 *}
  IDbLargeObjectControl = interface
    ['{E5A1C7D2-94B3-46F8-A0C6-31B7D95E02F4}']
    function CreateLO: Int64;
    function OpenLO(const AOid: Int64; const AReadWrite: Boolean): IDbBlobStream;
    procedure UnlinkLO(const AOid: Int64);
  end;

  {** sqlite 行内 blob 流能力（cell 存储模型）：打开既有行的 blob 列
      （rowid 寻址）。pg 无对应机制（协议层不支持单元级流读），探测
      失败即降级 GetBlob 全量路径——两模型分面是诚实契约而非缺陷。 *}
  IDbRowBlobControl = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE00B}']
    function OpenRowBlob(const ATable, AColumn: string;
      const ARowId: Int64; const AReadWrite: Boolean): IDbBlobStream;
  end;

  {** 异步取消控制（V3-B6，可选能力，QueryInterface 于 IDbConnection
      探测）。db.async 执行器经本面把消费方取消令牌映射为后端中断
      原语。语义：
      - ArmCancel/DisarmCancel 配对：sqlite 装/卸 progress handler
        （探测内部取消标志）；pg 等其余后端无操作返回 True。
        只允许在无在途调用时调用（执行器单飞模型保证）。
      - RequestCancel 线程安全、尽力而为：pg = PQcancel（在途语句以
        57014 query_canceled 收场）；sqlite = 原子标志 → 已装 handler
        中断 → SQLITE_INTERRUPT；无在途调用时无害 no-op。
      - 取消引发失败的归一：两端均 decTimeout（"查询取消"语义位，
        ClassifyPg 57014 / ClassifySqlite INTERRUPT 同词表）。
      无布尔能力位（与 IDbRowBlobControl 同例）：探测即能力，无需自述。 *}
  IDbCancelControl = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE00D}']
    function ArmCancel: Boolean;
    procedure DisarmCancel;
    procedure RequestCancel;
  end;

  {** 连接句柄内标记：PRAGMA foreign_keys=ON 去重（wallet 热租约零锁/零哈希）。
      可选能力：sqlite 实现，pg/mysql 忽略；QueryInterface 探测，未实现 = 回退单次 Exec。 *}
  IDbForeignKeysControl = interface
    ['{F7C2E1A0-3B2D-4E8F-A9C1-5D6E7F8A9B0C}']
    function ForeignKeysOn: Boolean;
    procedure SetForeignKeysOn(const AValue: Boolean);
  end;

  {** 后端能力自述（V3-B1）：只描述统一层契约内的能力面，不做元数据
      全家桶。可选能力接口——QueryInterface 探测，未实现 = 连接来自
      早于本契约的适配器；门面 DbCapabilities 统一探测并允许 nil。
      布尔项与可选接口存在性必须互证为真（conformance 钉死）：
      SupportsBatchExecutor ⇔ IDbBatchExecutor、SupportsStmtCacheControl
      ⇔ IDbStmtCacheControl、SupportsLargeObjects ⇔ IDbLargeObjectControl、
      SupportsSavepoints ⇔ IDbSavepointControl、SupportsArrayBinding
      ⇔ IDbArrayBinding（后者探测对象是 IDbQuery，非连接）。 *}
  IDbCapabilities = interface
    ['{5B3E9C71-8A24-46D3-B7F0-C92E14AD6038}']
    function Kind: TDbKind;
    { 服务端产品名/版本串：'SQLite'/'PostgreSQL'/'MySQL'/'MariaDB' +
      库报告的版本号原文；诊断展示用，不做行为依据 }
    function ProductName: string;
    function ProductVersion: string;
    function SupportsSavepoints: Boolean;
    function SupportsBatchExecutor: Boolean;
    function SupportsStmtCacheControl: Boolean;
    function SupportsLargeObjects: Boolean;
    { 参数级批量绑定（V3-C2）：本连接的 Query 对象可探测到
      IDbArrayBinding；pg unnest 路径 = True }
    function SupportsArrayBinding: Boolean;
    { 原生布尔列类型：pg bool(OID16)=True；sqlite 靠声明亲和、
      mysql 靠 TINYINT(1) 约定 = False }
    function SupportsNativeBool: Boolean;
    { 单次 Exec 多语句（mysql 需连接期 CLIENT_MULTI_STATEMENTS） }
    function SupportsMultiStatementExec: Boolean;
    { StatementTimeoutMs 连接选项在本后端真实生效（pg 会话级 /
      mysql Oracle≥8.0 探测后；sqlite 恒 False 不冒充） }
    function SupportsStatementTimeout: Boolean;
    { 未加引号标识符大小写敏感（sqlite 保留声明形式 True；
      pg 折叠小写 / mysql 列名不敏感 = False） }
    function CaseSensitiveIdentifiers: Boolean;
    { 单语句占位符上限的保守下界：sqlite=999（跨版本保证值，
      新栈实际更高）、pg/mysql 协议上限 65535 }
    function MaxPlaceholders: Integer;
    { 服务端版本整数：major*10000+minor*100+patch（pg server_version_num 同构）；
      0 = 未探测或网关/键值不探 }
    function ServerVersion: Integer;
    { V4 高级能力（V3-E 探针预留，当前诚实 false，未来升 true 不破契约） }
    function SupportsNativeVector: Boolean;
    function SupportsJsonPath: Boolean;
    function SupportsRangeTypes: Boolean;
    function SupportsBulkCopy: Boolean;
  end;

  {** Bulk copy 高速面（V4.3 universal：sqlite/pg/mysql/odbc/dm 单事务批量已实现，redis 键值 honest false）。
      语义：单事务内行复制（pg COPY BINARY 未来高速路径预留）。
      契约：BeginCopy 前置，WriteRow 逐行，EndCopy 提交；任一步失败回滚。
      IDbCapabilities.SupportsBulkCopy ⇔ QI 互证（conformance 钉死）。 *}
  IDbBulkCopy = interface
    ['{A1B2C3D4-E5F6-4711-8899-AABBCCDDEEFF}']
    procedure BeginCopy(const ATable: string; const AColumns: array of string);
    procedure WriteRow(const AValues: array of string);
    procedure EndCopy;
    procedure AbortCopy;
  end;

  {** 观测钩子监听器（V3-B3）：连接生命周期与执行事件的同步回调面。
      语义契约（CONTRACT §2.12 同文）：
      - OnAcquire 在监听器挂载（SetListener 非 nil）时同步补发一次，
        语义 = "本连接已建立"（建连先于挂载的常驻场景由此可观测）；
        OnRelease = 连接关闭（析构内）。同一监听器的一次挂载对应
        析构时恰好一次 OnRelease。池化场景内层连接常驻，租约借还
        不在本面——池侧观测走 db.pool 既有诊断（C3）。
      - OnQuery(DurationMs, Summary) = 成功执行一次：Exec 计全程；
        查询计"首个 Step 全程"（绑定+服务端执行+首行，惰性执行模型
        的统一执行窗口），同周期后续 Step 不再发，Reset 后重计。
      - OnError(Category, Summary) = 执行路径失败；此时不发 OnQuery。
        覆盖 Exec/查询首 Step 抛出的 EDbError（绑定索引等编程错误
        不在内）。Category 直透 EDbError.Category 归一枚举。
      - Summary 是折叠空白并截断到 DB_TRACE_SQL_SUMMARY_MAX 的 SQL
        摘要（防日志爆炸）；参数值从不进入摘要（占位符原文保留，
        注入安全）。
      - 回调在调用线程同步执行（诚实模型，无后台线程）；实现不得
        重入本连接。 *}
  IDbTraceListener = interface
    ['{C7A4D2E8-51B9-4F63-9E0A-88D3B21F70C1}']
    procedure OnAcquire;
    procedure OnRelease;
    procedure OnQuery(const ADurationMs: Int64;
      const ASqlSummary: string);
    procedure OnError(const ACategory: TDbErrorCategory;
      const ASqlSummary: string);
  end;

  {** 追踪控制面（可选能力）：SetListener(nil) 关闭。默认零成本：
    无监听器时适配器不取时间戳、不做摘要、不发事件。 }
  IDbTraceControl = interface
    ['{C7A4D2E8-51B9-4F63-9E0A-88D3B21F70C2}']
    procedure SetListener(const AListener: IDbTraceListener);
    function HasListener: Boolean;
  end;

  {** 统一连接表面。 *}
  IDbConnection = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE003}']
    function Kind: TDbKind;
    { 多语句 DDL/DML；SQL 原文透传，不做占位符翻译 }
    procedure Exec(const ASql: string); overload;
    { 查询级选项版（V3-B2）：TimeoutMs 为建议值——后端有可安全
      应用的机制则生效（超时归一 decTimeout），否则忽略不报错；
      逐后端语义登记 CONTRACT §2.6/§2.11 与 TDbExecOptions 注记 }
    procedure Exec(const ASql: string;
      const AOptions: TDbExecOptions); overload;
    { 参数化查询；SQL 用顺序 ? 占位符 }
    function Query(const ASql: string): IDbQuery; overload;
    function Query(const ASql: string;
      const AOptions: TDbExecOptions): IDbQuery; overload;
    { 最近一次写入影响行数 }
    function Changes: Int64;
    { 原生句柄逃生舱：sqlite3* / PGconn*。仅限 LastInsertRowId、
      BusyTimeout、Checkpoint、LISTEN/NOTIFY 等未覆盖特性。 }
    function Raw: Pointer;
  end;

  {** 参数化连接回调（B13 租约纪律，owner=intf）：连接由框架作实参传入，回调体零捕获，语句结束即归还。单源于 db.intf（IDbConnection 所在），L2 pool 直接 uses 本面零 L2→L3 上向；tx 侧 thin alias。 *}
  TDbConnProc = reference to procedure(const AConn: IDbConnection);

implementation

end.
