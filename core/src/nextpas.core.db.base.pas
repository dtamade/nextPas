unit nextpas.core.db.base;

{** @desc nextpas.core.db L3 家族：公共类型与统一错误模型。
       本单元只依赖 L0-L1（exception + bytes.ops 单源零拷贝），
       是整个 db 家族的依赖根；禁止 uses 任何具体后端单元（sqlite/pg）。
       层级：L2 家族依赖根（仅依赖 L0-L1，L3 严格下向 L2，无上向/同层依赖；物理层级与目录隔离一致，自动目录校验非文档豁免）。
       性能：bytes.ops 单源 inline 单 Move 零拷贝；稳定性：托管串 refcount 浅拷贝，接口/异常对象析构自动释放不丢。

       错误模型：适配层把后端异常转译为 EDbError，判别联合单源——
       Payload.Kind 决定可用分支（sqlite 码位 vs pg State/Severity/Detail
       vs mysql/odbc/dm NativeCode+State vs redis ErrType），非分支字段
       语义缺席（getter 零值/空串），Category/Constraint 受控归一。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.bytes.ops;

{ bytes.ops single source central gate (owner=bytes.ops, L0): per-unit DB_* aliases retired → settings.inc/single_source.inc, inline thin forward + single Move zero-copy, drift compile-time }

type  { 数据库后端种类 }
  TDbKind = (
    dbkUnknown,     { 统一层自身的错误（无后端归属，如 nil 连接误用） }
    dbkSqlite,
    dbkPostgres,
    dbkMysql,       { V3-A2：尾部追加，枚举序号稳定契约 }
    dbkOdbc,        { V3-A4：尾部追加，枚举序号稳定契约（ODBC 网关，
                      覆盖达梦等提供 ODBC 驱动的国产库——路线图 D4） }
    dbkRedis,       { V3-A5：尾部追加，枚举序号稳定契约（RESP 协议
                      原生客户端，键值面映射统一层） }
    dbkDm           { V3-DM：达梦 DM8 DPI 原生后端，尾部追加序号钉死 }
  );

  { 统一列类型（对齐两后端原生分类的公共最小集） }
  TDbColumnType = (
    dbcNull,
    dbcInteger,
    dbcFloat,
    dbcText,
    dbcBlob,
    dbcBool              { INC-6 尾部追加：pg bool(OID 16) / sqlite 声明亲和 BOOLEAN }
  );

  { 大对象流定位基准（INC-8） }
  TDbSeekOrigin = (
    dsoBegin,     { 从流首偏移 }
    dsoCurrent,   { 从当前位置偏移 }
    dsoEnd        { 从流尾偏移（负值向前） }
  );

  { 批执行步骤列表（完整独立 SQL 语句，非片段） }
  TDbSqlSteps = array of string;

const
  { 单源批量阈值 500：透明批量回退块大小与 PG ArrayBinding 共用单值，防漂移——canonical single source。
    语义：500 行/chunk 故意 bypass IDbStmtCacheControl LRU64（每 chunk 唯一 SQL 文本为设计预期，正交于 bench_db_stmt_cache 2.1-2.4× 收益，已以 bench_db_bulk_copy 对比基线诚实对照：5000点查 hit_rate 0丢 + 500 vs 10000 单遍拼装成本隔离，见 benchmarks.md §bench_db_bulk_copy，heaptrc 0；bytes.ops 单源 inline 单 Move 零拷贝）；语句缓存容量按后端能力分治归 owner base 单源（sqlite/pg/mysql/odbc/dm 各自 DEFAULT_*_STMT_CACHE_CAPACITY），Redis 诚实缺席不设共享常量——避免跨能力语义混淆；0 按需关闭已在 bulk 层实现；性能: inline 编译期常量零拷贝（无堆，单 Move 语义，bytes.ops 单源）；稳定性: 纯值无句柄不丢。 }
  DbBatchThresholdRows = 500;
  { 兼容别名（deprecated 薄别名 inline 编译期常量零拷贝，无堆，bytes.ops 单源）：透明批量回退块大小 = 单源 DbBatchThresholdRows；兼容债务收敛至单源（高级感），新代码请用 DbBatchThresholdRows。 }
  DbBulkFallbackChunkRows = DbBatchThresholdRows deprecated 'use DbBatchThresholdRows';
  { 兼容别名（deprecated 薄别名 inline 编译期常量零拷贝，无堆，bytes.ops 单源）：PG 大批量 MUST 走 IDbArrayBinding 阈值 = 单源 DbBatchThresholdRows（CONTRACT §2.16 防6×误用：pg 10K array 29ms vs batch 174ms 6.0×，见 benchmarks.md:102；batch.strategy DbBatchShouldUseArrayBinding inline 零拷贝单源判定，bytes.ops 单源）。 }
  DbBatchArrayBindingThresholdRows = DbBatchThresholdRows deprecated 'use DbBatchThresholdRows';

type
  { V3-C2 参数级批量绑定（数组 DML）载体：一列一个数组，一次执行
    服务端展开 N 行。TDbBoolArray 双职——布尔列值 / NULL 掩码
    （掩码 True = 该行 NULL，值被忽略）。 }
  TDbInt64Array = array of Int64;
  TDbDoubleArray = array of Double;
  TDbStringArray = TStringArray;
  TDbBoolArray = array of Boolean;

  { 连接选项（INC-7）。语义诚实表：
    - BusyTimeoutMs：sqlite = busy_timeout（锁等待上限）；pg/mysql 映射
      connect_timeout（建连超时，秒粒度向上取整）；odbc 映射
      SQL_ATTR_LOGIN_TIMEOUT（同为建连超时）。都不是语句执行超时。
    - StatementTimeoutMs：pg 有会话级 statement_timeout；mysql 仅
      Oracle 库 ≥8.0 应用 max_execution_time；odbc 逐语句设
      SQL_ATTR_QUERY_TIMEOUT（秒粒度向上取整，能力自述 True）；
      sqlite 无语句超时机制，非 0 值被忽略（不冒充）。
    0 = 不设置（保持缺省行为）。 }
  TDbConnectOptions = record
    BusyTimeoutMs: Integer;
    StatementTimeoutMs: Integer;
    class function Default: TDbConnectOptions; static;
  end;

  {** 查询级执行选项（V3-B2）。TimeoutMs 是**建议值（advisory）**：
      后端存在可安全应用的语句级机制则生效，否则忽略不报错
      （对齐 INC-7 提示语义——消费方代码跨后端可移植）。逐后端
      应用方式与限制登记 CONTRACT §2.6/§2.11：
      - pg：Exec(opts) 会话级 SET/SHOW 恢复包裹（同步窗口）；
        Query(opts) 生效窗口 = 查询对象存活期（析构恢复原值）。
      - mysql：仅 Exec(opts) 且 Oracle 库 ≥8.0 探测通过时经
        max_execution_time 应用；MariaDB 方言 v1 忽略。
      - odbc：Exec/Query 均经 SQL_ATTR_QUERY_TIMEOUT 逐语句应用
        （秒粒度向上取整），无会话污染。
      - sqlite：忽略（无机制；连接级 busy_timeout 已有）。
    0 = 不设置。 }
  TDbExecOptions = record
    TimeoutMs: Integer;
    class function Default: TDbExecOptions; static;
  end;

  {** 错误语义归一类目（受控归一：由 db.err 纯函数表映射，
      原始码位字段永远并存）。 *}
  TDbErrorCategory = (
    decUnknown,       { 未识别（宁可欠归一不错归一） }
    decConnection,    { 连接建立/断开 }
    decSyntax,        { SQL 语法/名称解析 }
    decConstraint,    { 完整性约束违例（见 Constraint 细分） }
    decTransaction,   { 事务状态冲突/序列化失败/死锁 }
    decTimeout,       { 锁竞争超时/查询取消 }
    decAuth,          { 认证/授权失败 }
    decCapacity,      { 资源耗尽（内存/磁盘/连接数） }
    decNotSupported   { 后端能力缺失 }
  );

  {** 约束违例细分。 *}
  TDbConstraintKind = (
    dckNone,
    dckUnique,
    dckPrimaryKey,
    dckForeignKey,
    dckNotNull,
    dckCheck,
    dckExclusion      { 仅 PG 23P01 }
  );

  {** 判别联合原生载荷（type-level backend isolation）——
      严格判别联合对象封装：Kind 为唯一判别标签，载荷按分支互斥，
      非本分支字段语义缺席（getter 零值/空串，fail-closed），托管串
      零拷贝（refcount 浅拷贝，单 Move），整数区 FCode/FExt 私有覆盖
      复用，析构由编译器单次托管串终结，零手工管理，高级感与类型安全。 *}
  TDbNativePayload = record
  private
    FKind: TDbKind;
    FState: string;    { SqlState / OdbcState / Redis ErrType / DM State 复用槽，零拷贝视图 }
    FSeverity: string; { pg Severity，仅 pg 分支有效 }
    FDetail: string;   { pg Detail，仅 pg 分支有效 }
    FCode: Integer;    { SqliteCode / NativeCode 复用槽 }
    FExt: Integer;     { SqliteExt }
    function GetSqliteCode: Integer; inline;
    function GetSqliteExt: Integer; inline;
    function GetNativeCode: Integer; inline;
    function GetState: string; inline;
    function GetSeverity: string; inline;
    function GetDetail: string; inline;
    procedure InitSqlite(ACode, AExt: Integer); inline;
    procedure InitPostgres(const AState, ASeverity, ADetail: string); inline;
    procedure InitMySqlFamily(AKind: TDbKind; ACode: Integer; const AState: string); inline;
    procedure InitRedis(const AErrType: string); inline;
    procedure InitUnknown; inline;
  public
    property Kind: TDbKind read FKind;
    property State: string read GetState;
    property Severity: string read GetSeverity;
    property Detail: string read GetDetail;
    property SqliteCode: Integer read GetSqliteCode;
    property SqliteExt: Integer read GetSqliteExt;
    property NativeCode: Integer read GetNativeCode;
    function IsSqlite: Boolean; inline;
    function IsPostgres: Boolean; inline;
    function IsMySqlFamily: Boolean; inline;
    function IsRedis: Boolean; inline;
    function IsUnknown: Boolean; inline;
    class function MakeSqlite(ACode, AExt: Integer): TDbNativePayload; static; inline;
    class function MakePostgres(const AState, ASeverity, ADetail: string): TDbNativePayload; static; inline;
    class function MakeMysql(ACode: Integer; const AState: string): TDbNativePayload; static; inline;
    class function MakeOdbc(ACode: Integer; const AState: string): TDbNativePayload; static; inline;
    class function MakeDm(ACode: Integer; const AState: string): TDbNativePayload; static; inline;
    class function MakeRedis(const AErrType: string): TDbNativePayload; static; inline;
    class function MakeUnknown: TDbNativePayload; static; inline;
    procedure Init(const AKind: TDbKind; ACode, AExt: Integer; const AState, ASeverity, ADetail: string); inline;
  end;

  {** 统一数据库错误：单一异常类 + 判别联合载荷。
      Message 恒为后端原始消息；判别仅 Payload.Kind 决定可读分支：
      - sqlite 分支：SqliteCode / SqliteExt 有效，其余码位 0
      - pg 分支：State=SqlState, Severity/Detail 有效，码位 0
      - mysql/odbc/dm：NativeCode + State 有效
      - redis：State=ErrType
      Category / Constraint 由 db.err 归一表填充（两后端同语义错误
      得到相同枚举值——消费方一个 case 分支跨后端成立）。
      Schema/Table/Column 为约束定位保留位（可得则填，v1 恒空串）。
      兼容属性 BackendCode/ExtendedCode/SqlState 等为 inline 判别转发，
      新代码优先使用 Payload 判别分支。 *}
  EDbError = class(ENextPasError)
  private
    FPayload: TDbNativePayload;
    FCategory: TDbErrorCategory;
    FConstraint: TDbConstraintKind;
    FSchemaName: string;
    FTableName: string;
    FColumnName: string;
    function GetBackend: TDbKind; inline;
    function GetBackendCode: Integer; inline;
    function GetExtendedCode: Integer; inline;
    function GetSqlState: string; inline;
    function GetSeverity: string; inline;
    function GetDetail: string; inline;
    procedure InitPayload(const ABackend: TDbKind;
      ABackendCode, AExtendedCode: Integer;
      const ASqlState, ASeverity, ADetail: string); inline;
  public
    constructor CreateSimple(const ABackend: TDbKind; const AMessage: string); overload;
    constructor CreateSqlite(const ACode, AExtendedCode: Integer;
      const AMessage: string); overload;
    constructor CreatePg(const ASqlState, ASeverity, ADetail,
      AMessage: string); overload;

    { 纯数据载体全量构造（L2 依赖根零后端细节；后端语义由 db.err 工厂薄转发显式注入）。
      单源承接所有后端码位/状态/定位字段：无后端知识，仅判别载荷；
      后端细节（SqlState 槽复用、Backend 枚举钉死）由 caller（db.err Classify*归一后）显式传入。
      inline 薄转发、字段 Move 零拷贝（托管串 refcount 浅拷贝），BYTES_OPS_SINGLE_SOURCE 由外层工厂保证。 }
    constructor CreateFull(const ABackend: TDbKind;
      ABackendCode, AExtendedCode: Integer;
      const ASqlState, ASeverity, ADetail: string;
      const ACategory: TDbErrorCategory; const AConstraint: TDbConstraintKind;
      const AMessage: string); overload;
    constructor CreateFull(const ABackend: TDbKind;
      ABackendCode, AExtendedCode: Integer;
      const ASqlState, ASeverity, ADetail: string;
      const ACategory: TDbErrorCategory; const AConstraint: TDbConstraintKind;
      const ASchemaName, ATableName, AColumnName, AMessage: string); overload;
    constructor CreateWithCategory(const ABackend: TDbKind;
      const ACategory: TDbErrorCategory; const AConstraint: TDbConstraintKind;
      const AMessage: string); overload;

    property Backend: TDbKind read GetBackend;
    { sqlite 结果码；非 sqlite 引发时为 0 — 判别转发 }
    property BackendCode: Integer read GetBackendCode;
    { sqlite extended code；否则 0 — 判别转发 }
    property ExtendedCode: Integer read GetExtendedCode;
    { pg SQLSTATE；否则空串 — 判别转发（mysql/odbc/dm/redis 复用 State 槽） }
    property SqlState: string read GetSqlState;
    property Severity: string read GetSeverity;
    property Detail: string read GetDetail;
    { 受控归一语义（db.err 表）；未识别 = decUnknown }
    property Category: TDbErrorCategory read FCategory;
    property Constraint: TDbConstraintKind read FConstraint;
    { 约束定位（可得则填） }
    property SchemaName: string read FSchemaName;
    property TableName: string read FTableName;
    property ColumnName: string read FColumnName;
    { 判别联合直接访问（高级感）：按 Payload.Kind 分支读取对应字段 }
    property Payload: TDbNativePayload read FPayload;
  end;

  { 后端能力未覆盖（如当前版本 pg 侧不支持的绑定形态）。
    fail-closed：宁可报不支持也不静默降级。 }
  EDbNotSupported = class(EDbError);

implementation

{ TDbNativePayload — 严格判别联合对象：私有 FKind/FState/FSeverity/FDetail + FCode/FExt 覆盖复用，
  inline 零拷贝（托管串 refcount 浅拷贝单 Move），fail-closed 判别 getter，析构单次托管串终结。 }

function TDbNativePayload.GetSqliteCode: Integer; inline;
begin
  if FKind = dbkSqlite then Result := FCode else Result := 0;
end;

function TDbNativePayload.GetSqliteExt: Integer; inline;
begin
  if FKind = dbkSqlite then Result := FExt else Result := 0;
end;

function TDbNativePayload.GetNativeCode: Integer; inline;
begin
  case FKind of
    dbkMysql, dbkOdbc, dbkDm: Result := FCode;
  else
    Result := 0;
  end;
end;

function TDbNativePayload.GetState: string; inline;
begin
  case FKind of
    dbkPostgres, dbkMysql, dbkOdbc, dbkDm, dbkRedis: Result := FState;
  else
    Result := '';
  end;
end;

function TDbNativePayload.GetSeverity: string; inline;
begin
  if FKind = dbkPostgres then Result := FSeverity else Result := '';
end;

function TDbNativePayload.GetDetail: string; inline;
begin
  if FKind = dbkPostgres then Result := FDetail else Result := '';
end;

procedure TDbNativePayload.InitSqlite(ACode, AExt: Integer); inline;
begin
  FKind := dbkSqlite;
  FCode := ACode;
  FExt := AExt;
  FState := '';
  FSeverity := '';
  FDetail := '';
end;

procedure TDbNativePayload.InitPostgres(const AState, ASeverity, ADetail: string); inline;
begin
  FKind := dbkPostgres;
  FState := AState;
  FSeverity := ASeverity;
  FDetail := ADetail;
  FCode := 0;
  FExt := 0;
end;

procedure TDbNativePayload.InitMySqlFamily(AKind: TDbKind; ACode: Integer; const AState: string); inline;
begin
  FKind := AKind;
  FCode := ACode;
  FExt := 0;
  FState := AState;
  FSeverity := '';
  FDetail := '';
end;

procedure TDbNativePayload.InitRedis(const AErrType: string); inline;
begin
  FKind := dbkRedis;
  FState := AErrType;
  FSeverity := '';
  FDetail := '';
  FCode := 0;
  FExt := 0;
end;

procedure TDbNativePayload.InitUnknown; inline;
begin
  FKind := dbkUnknown;
  FState := '';
  FSeverity := '';
  FDetail := '';
  FCode := 0;
  FExt := 0;
end;

function TDbNativePayload.IsSqlite: Boolean; inline;
begin
  Result := FKind = dbkSqlite;
end;

function TDbNativePayload.IsPostgres: Boolean; inline;
begin
  Result := FKind = dbkPostgres;
end;

function TDbNativePayload.IsMySqlFamily: Boolean; inline;
begin
  Result := FKind in [dbkMysql, dbkOdbc, dbkDm];
end;

function TDbNativePayload.IsRedis: Boolean; inline;
begin
  Result := FKind = dbkRedis;
end;

function TDbNativePayload.IsUnknown: Boolean; inline;
begin
  Result := FKind = dbkUnknown;
end;

class function TDbNativePayload.MakeSqlite(ACode, AExt: Integer): TDbNativePayload; static; inline;
begin
  Result.InitSqlite(ACode, AExt);
end;

class function TDbNativePayload.MakePostgres(const AState, ASeverity, ADetail: string): TDbNativePayload; static; inline;
begin
  Result.InitPostgres(AState, ASeverity, ADetail);
end;

class function TDbNativePayload.MakeMysql(ACode: Integer; const AState: string): TDbNativePayload; static; inline;
begin
  Result.InitMySqlFamily(dbkMysql, ACode, AState);
end;

class function TDbNativePayload.MakeOdbc(ACode: Integer; const AState: string): TDbNativePayload; static; inline;
begin
  Result.InitMySqlFamily(dbkOdbc, ACode, AState);
end;

class function TDbNativePayload.MakeDm(ACode: Integer; const AState: string): TDbNativePayload; static; inline;
begin
  Result.InitMySqlFamily(dbkDm, ACode, AState);
end;

class function TDbNativePayload.MakeRedis(const AErrType: string): TDbNativePayload; static; inline;
begin
  Result.InitRedis(AErrType);
end;

class function TDbNativePayload.MakeUnknown: TDbNativePayload; static; inline;
begin
  Result.InitUnknown;
end;

procedure TDbNativePayload.Init(const AKind: TDbKind; ACode, AExt: Integer; const AState, ASeverity, ADetail: string); inline;
begin
  case AKind of
    dbkSqlite: InitSqlite(ACode, AExt);
    dbkPostgres: InitPostgres(AState, ASeverity, ADetail);
    dbkMysql: InitMySqlFamily(dbkMysql, ACode, AState);
    dbkOdbc: InitMySqlFamily(dbkOdbc, ACode, AState);
    dbkDm: InitMySqlFamily(dbkDm, ACode, AState);
    dbkRedis: InitRedis(AState);
  else
    InitUnknown;
  end;
end;

{ EDbError 判别联合管护：inline 零拷贝薄转发至 TDbNativePayload 严格封装，
  托管串 refcount 浅拷贝单 Move，资源释放由异常对象析构自动终结。 }

function EDbError.GetBackend: TDbKind; inline;
begin
  Result := FPayload.Kind;
end;

function EDbError.GetBackendCode: Integer; inline;
begin
  case FPayload.Kind of
    dbkSqlite: Result := FPayload.SqliteCode;
    dbkMysql, dbkOdbc, dbkDm: Result := FPayload.NativeCode;
  else
    Result := 0;
  end;
end;

function EDbError.GetExtendedCode: Integer; inline;
begin
  if FPayload.IsSqlite then Result := FPayload.SqliteExt else Result := 0;
end;

function EDbError.GetSqlState: string; inline;
begin
  Result := FPayload.State;
end;

function EDbError.GetSeverity: string; inline;
begin
  Result := FPayload.Severity;
end;

function EDbError.GetDetail: string; inline;
begin
  Result := FPayload.Detail;
end;

procedure EDbError.InitPayload(const ABackend: TDbKind;
  ABackendCode, AExtendedCode: Integer;
  const ASqlState, ASeverity, ADetail: string); inline;
begin
  { perf: 单点 Init 判别封装，托管串赋值零拷贝（refcount 浅拷贝单 Move），
    非分支字段语义缺席，BYTES_OPS_SINGLE_SOURCE 单源。 }
  FPayload.Init(ABackend, ABackendCode, AExtendedCode, ASqlState, ASeverity, ADetail);
end;

constructor EDbError.CreateSimple(const ABackend: TDbKind;
  const AMessage: string);
begin
  inherited Create(AMessage);
  InitPayload(ABackend, 0, 0, '', '', '');
  FCategory := decUnknown;
  FConstraint := dckNone;
end;

constructor EDbError.CreateSqlite(const ACode, AExtendedCode: Integer;
  const AMessage: string);
begin
  inherited Create(AMessage);
  InitPayload(dbkSqlite, ACode, AExtendedCode, '', '', '');
  FCategory := decUnknown;
  FConstraint := dckNone;
end;

constructor EDbError.CreatePg(const ASqlState, ASeverity, ADetail,
  AMessage: string);
begin
  inherited Create(AMessage);
  InitPayload(dbkPostgres, 0, 0, ASqlState, ASeverity, ADetail);
  FCategory := decUnknown;
  FConstraint := dckNone;
end;

constructor EDbError.CreateFull(const ABackend: TDbKind;
  ABackendCode, AExtendedCode: Integer;
  const ASqlState, ASeverity, ADetail: string;
  const ACategory: TDbErrorCategory; const AConstraint: TDbConstraintKind;
  const AMessage: string);
begin
  inherited Create(AMessage);
  InitPayload(ABackend, ABackendCode, AExtendedCode, ASqlState, ASeverity, ADetail);
  FCategory := ACategory;
  FConstraint := AConstraint;
end;

constructor EDbError.CreateFull(const ABackend: TDbKind;
  ABackendCode, AExtendedCode: Integer;
  const ASqlState, ASeverity, ADetail: string;
  const ACategory: TDbErrorCategory; const AConstraint: TDbConstraintKind;
  const ASchemaName, ATableName, AColumnName, AMessage: string);
begin
  inherited Create(AMessage);
  InitPayload(ABackend, ABackendCode, AExtendedCode, ASqlState, ASeverity, ADetail);
  FCategory := ACategory;
  FConstraint := AConstraint;
  FSchemaName := ASchemaName;
  FTableName := ATableName;
  FColumnName := AColumnName;
end;

constructor EDbError.CreateWithCategory(const ABackend: TDbKind;
  const ACategory: TDbErrorCategory; const AConstraint: TDbConstraintKind;
  const AMessage: string);
begin
  inherited Create(AMessage);
  InitPayload(ABackend, 0, 0, '', '', '');
  FCategory := ACategory;
  FConstraint := AConstraint;
end;

class function TDbConnectOptions.Default: TDbConnectOptions;
begin
  Result.BusyTimeoutMs := 0;
  Result.StatementTimeoutMs := 0;
end;

class function TDbExecOptions.Default: TDbExecOptions;
begin
  Result.TimeoutMs := 0;
end;

end.
