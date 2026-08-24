unit nextpas.core.db.base;

{** @desc nextpas.core.db L3 家族：公共类型与统一错误模型。
       本单元只依赖 L0（exception），是整个 db 家族的依赖根；
       禁止 uses 任何具体后端单元（sqlite/pg）。

       错误模型：适配层把后端异常转译为 EDbError，双码位并存——
       适用哪个后端就填哪个字段，不做跨后端语义归一（无真实消费
       需求前不发明映射表）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

const
  { sqlite 透明语句缓存的默认空闲容量（LRU，键 = 原始 SQL 文本）；
    0 = 关闭缓存。词汇归 base：门面与适配器共同引用。 }
  DEFAULT_SQLITE_STMT_CACHE_CAPACITY = 64;
  { pg 透明语句缓存的默认容量（服务端 prepared statement 名注册表，
    键 = bytea cast 后的规范形 SQL 文本）；0 = 关闭缓存。 }
  DEFAULT_PG_STMT_CACHE_CAPACITY = 64;

type  { 数据库后端种类 }
  TDbKind = (
    dbkUnknown,     { 统一层自身的错误（无后端归属，如 nil 连接误用） }
    dbkSqlite,
    dbkPostgres,
    dbkMysql,       { V3-A2：尾部追加，枚举序号稳定契约 }
    dbkOdbc,        { V3-A4：尾部追加，枚举序号稳定契约（ODBC 网关，
                      覆盖达梦等提供 ODBC 驱动的国产库——路线图 D4） }
    dbkRedis        { V3-A5：尾部追加，枚举序号稳定契约（RESP 协议
                      原生客户端，键值面映射统一层） }
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

  {** 统一数据库错误：单一异常类 + 字段化载荷。
      Message 恒为后端原始消息；字段按引发后端填充：
      - sqlite：BackendCode / ExtendedCode 有值，SqlState 等空串
      - postgres：SqlState / Severity / Detail 有值，码位字段 0
      Category / Constraint 由 db.err 归一表填充（两后端同语义错误
      得到相同枚举值——消费方一个 case 分支跨后端成立）。
      Schema/Table/Column 为约束定位保留位（可得则填，v1 恒空串）。 *}
  EDbError = class(ENextPasError)
  private
    FBackend: TDbKind;
    FBackendCode: Integer;
    FExtendedCode: Integer;
    FSqlState: string;
    FSeverity: string;
    FDetail: string;
    FCategory: TDbErrorCategory;
    FConstraint: TDbConstraintKind;
    FSchemaName: string;
    FTableName: string;
    FColumnName: string;
  public
    constructor CreateSimple(const ABackend: TDbKind; const AMessage: string); overload;
    constructor CreateSqlite(const ACode, AExtendedCode: Integer;
      const AMessage: string); overload;
    constructor CreatePg(const ASqlState, ASeverity, ADetail,
      AMessage: string); overload;

    { 全量构造（db.err 归一后的标准入口） }
    constructor CreateFullSqlite(const ACode, AExtendedCode: Integer;
      const ACategory: TDbErrorCategory; const AConstraint: TDbConstraintKind;
      const AMessage: string); overload;
    constructor CreateFullPg(const ASqlState, ASeverity, ADetail,
      AMessage: string; const ACategory: TDbErrorCategory;
      const AConstraint: TDbConstraintKind); overload;
    constructor CreateFullPg(const ASqlState, ASeverity, ADetail,
      AMessage: string; const ACategory: TDbErrorCategory;
      const AConstraint: TDbConstraintKind;
      const ASchemaName, ATableName, AColumnName: string); overload;
    { V3-A2：MySQL 全量构造（db.err ClassifyMy 归一后的标准入口）。
      BackendCode = CR_*/ER_* 原始码位；SqlState 5 字符或空串。
      MySQL 服务端不提供约束定位字段，Schema/Table/Column 恒空。 }
    constructor CreateFullMy(const ACode: Integer; const ASqlState,
      AMessage: string; const ACategory: TDbErrorCategory;
      const AConstraint: TDbConstraintKind); overload;

    { V3-A4：ODBC 全量构造（db.err ClassifyOdbc 归一后的标准入口）。
      BackendCode = 诊断记录 NativeError（驱动专属整数，跨驱动无
      可移植语义）；SqlState = 5 字符 ISO 状态码。 }
    constructor CreateFullOdbc(const ANativeCode: Integer;
      const ASqlState, AMessage: string; const ACategory: TDbErrorCategory;
      const AConstraint: TDbConstraintKind); overload;

    { V3-A5：Redis 全量构造（db.err ClassifyRedis 归一后的标准
      入口）。AErrType = 错误回复首词（ERR/Wrongpass/MOVED…），
      存 SqlState 槽；BackendCode 恒 0（RESP 无数字码位）。 }
    constructor CreateFullRedis(const AErrType, AMessage: string;
      const ACategory: TDbErrorCategory;
      const AConstraint: TDbConstraintKind); overload;

    property Backend: TDbKind read FBackend;
    { sqlite 结果码；非 sqlite 引发时为 0 }
    property BackendCode: Integer read FBackendCode;
    { sqlite extended code；否则 0 }
    property ExtendedCode: Integer read FExtendedCode;
    { pg SQLSTATE；否则空串 }
    property SqlState: string read FSqlState;
    property Severity: string read FSeverity;
    property Detail: string read FDetail;
    { 受控归一语义（db.err 表）；未识别 = decUnknown }
    property Category: TDbErrorCategory read FCategory;
    property Constraint: TDbConstraintKind read FConstraint;
    { 约束定位（可得则填） }
    property SchemaName: string read FSchemaName;
    property TableName: string read FTableName;
    property ColumnName: string read FColumnName;
  end;

  { 后端能力未覆盖（如当前版本 pg 侧不支持的绑定形态）。
    fail-closed：宁可报不支持也不静默降级。 }
  EDbNotSupported = class(EDbError);

implementation

constructor EDbError.CreateSimple(const ABackend: TDbKind;
  const AMessage: string);
begin
  inherited Create(AMessage);
  FBackend := ABackend;
  FCategory := decUnknown;
  FConstraint := dckNone;
end;

constructor EDbError.CreateSqlite(const ACode, AExtendedCode: Integer;
  const AMessage: string);
begin
  inherited Create(AMessage);
  FBackend := dbkSqlite;
  FBackendCode := ACode;
  FExtendedCode := AExtendedCode;
  FCategory := decUnknown;
  FConstraint := dckNone;
end;

constructor EDbError.CreatePg(const ASqlState, ASeverity, ADetail,
  AMessage: string);
begin
  inherited Create(AMessage);
  FBackend := dbkPostgres;
  FSqlState := ASqlState;
  FSeverity := ASeverity;
  FDetail := ADetail;
  FCategory := decUnknown;
  FConstraint := dckNone;
end;

constructor EDbError.CreateFullSqlite(const ACode, AExtendedCode: Integer;
  const ACategory: TDbErrorCategory; const AConstraint: TDbConstraintKind;
  const AMessage: string);
begin
  inherited Create(AMessage);
  FBackend := dbkSqlite;
  FBackendCode := ACode;
  FExtendedCode := AExtendedCode;
  FCategory := ACategory;
  FConstraint := AConstraint;
end;

constructor EDbError.CreateFullPg(const ASqlState, ASeverity, ADetail,
  AMessage: string; const ACategory: TDbErrorCategory;
  const AConstraint: TDbConstraintKind);
begin
  inherited Create(AMessage);
  FBackend := dbkPostgres;
  FSqlState := ASqlState;
  FSeverity := ASeverity;
  FDetail := ADetail;
  FCategory := ACategory;
  FConstraint := AConstraint;
end;

constructor EDbError.CreateFullPg(const ASqlState, ASeverity, ADetail,
  AMessage: string; const ACategory: TDbErrorCategory;
  const AConstraint: TDbConstraintKind;
  const ASchemaName, ATableName, AColumnName: string);
begin
  inherited Create(AMessage);
  FBackend := dbkPostgres;
  FSqlState := ASqlState;
  FSeverity := ASeverity;
  FDetail := ADetail;
  FCategory := ACategory;
  FConstraint := AConstraint;
  FSchemaName := ASchemaName;
  FTableName := ATableName;
  FColumnName := AColumnName;
end;

constructor EDbError.CreateFullMy(const ACode: Integer; const ASqlState,
  AMessage: string; const ACategory: TDbErrorCategory;
  const AConstraint: TDbConstraintKind);
begin
  inherited Create(AMessage);
  FBackend := dbkMysql;
  FBackendCode := ACode;
  FSqlState := ASqlState;
  FCategory := ACategory;
  FConstraint := AConstraint;
end;

constructor EDbError.CreateFullOdbc(const ANativeCode: Integer;
  const ASqlState, AMessage: string; const ACategory: TDbErrorCategory;
  const AConstraint: TDbConstraintKind);
begin
  inherited Create(AMessage);
  FBackend := dbkOdbc;
  FBackendCode := ANativeCode;
  FSqlState := ASqlState;
  FCategory := ACategory;
  FConstraint := AConstraint;
end;

constructor EDbError.CreateFullRedis(const AErrType, AMessage: string;
  const ACategory: TDbErrorCategory;
  const AConstraint: TDbConstraintKind);
begin
  inherited Create(AMessage);
  FBackend := dbkRedis;
  FBackendCode := 0;      { RESP 错误无数字码位 }
  FSqlState := AErrType;
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
