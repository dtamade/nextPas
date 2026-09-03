unit nextpas.core.db.err;

{** @desc 跨后端错误语义归一表。
       把 sqlite 结果码 / PG SQLSTATE 映射为统一的
       TDbErrorCategory / TDbConstraintKind。纯函数、无后端依赖、
       独立可测——dbman 式"每个驱动自己决定抛哪个异常叶子"的问题
       在这里收敛为一张带门禁的表。

       归一原则：宁可欠归一（decUnknown）不错归一；原始码位字段
       永远并存，本表只做增量不做有损替换。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.base,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.mysql.base;

const
  { 单源化：词汇表唯一真实来源为各后端 base (sqlite.base / mysql.base)，
    本单元仅作别名透传，供分类表与对外 API 复用，避免双源漂移。 }
  DB_SQLITE_BUSY        = SQLITE_BUSY;
  DB_SQLITE_LOCKED      = SQLITE_LOCKED;
  DB_SQLITE_INTERRUPT   = SQLITE_INTERRUPT;   { V3-B6：progress handler/中断触发 }
  DB_SQLITE_CANTOPEN    = SQLITE_CANTOPEN;
  DB_SQLITE_AUTH        = SQLITE_AUTH;
  DB_SQLITE_NOMEM       = SQLITE_NOMEM;
  DB_SQLITE_IOERR       = SQLITE_IOERR;
  DB_SQLITE_CORRUPT     = SQLITE_CORRUPT;
  DB_SQLITE_FULL        = SQLITE_FULL;
  DB_SQLITE_CONSTRAINT  = SQLITE_CONSTRAINT;

  { sqlite3.h SQLITE_CONSTRAINT 扩展子码 — 单源透传 }
  DB_SQLITE_CONSTRAINT_CHECK        = SQLITE_CONSTRAINT_CHECK;
  DB_SQLITE_CONSTRAINT_FOREIGNKEY   = SQLITE_CONSTRAINT_FOREIGNKEY;
  DB_SQLITE_CONSTRAINT_NOTNULL      = SQLITE_CONSTRAINT_NOTNULL;
  DB_SQLITE_CONSTRAINT_PRIMARYKEY   = SQLITE_CONSTRAINT_PRIMARYKEY;
  DB_SQLITE_CONSTRAINT_UNIQUE       = SQLITE_CONSTRAINT_UNIQUE;

  { mysql_er.h / mysqld_error.h 错误码 — 单源透传自 mysql.base }
  DB_MYSQL_ER_BAD_FIELD_ERROR       = ER_BAD_FIELD_ERROR;  { unknown column }
  DB_MYSQL_ER_TABLE_EXISTS_ERROR    = ER_TABLE_EXISTS_ERROR;
  DB_MYSQL_ER_BAD_TABLE_ERROR       = ER_BAD_TABLE_ERROR;
  DB_MYSQL_ER_DUP_KEY               = ER_DUP_KEY;
  DB_MYSQL_ER_DUP_ENTRY             = ER_DUP_ENTRY;
  DB_MYSQL_ER_PARSE_ERROR           = ER_PARSE_ERROR;
  DB_MYSQL_ER_EMPTY_QUERY           = ER_EMPTY_QUERY;
  DB_MYSQL_ER_NO_SUCH_TABLE         = ER_NO_SUCH_TABLE;
  DB_MYSQL_ER_LOCK_DEADLOCK         = ER_LOCK_DEADLOCK;
  DB_MYSQL_ER_LOCK_TABLE_FULL       = ER_LOCK_TABLE_FULL;
  DB_MYSQL_ER_LOCK_WAIT_TIMEOUT     = ER_LOCK_WAIT_TIMEOUT;
  DB_MYSQL_ER_NOT_SUPPORTED_YET     = ER_NOT_SUPPORTED_YET;
  DB_MYSQL_ER_OPTION_PREVENTS_STATEMENT = ER_OPTION_PREVENTS_STATEMENT;
  DB_MYSQL_ER_NO_REFERENCED_ROW     = ER_NO_REFERENCED_ROW;
  DB_MYSQL_ER_ROW_IS_REFERENCED     = ER_ROW_IS_REFERENCED;
  DB_MYSQL_ER_NO_REFERENCED_ROW_2   = ER_NO_REFERENCED_ROW_2;
  DB_MYSQL_ER_ROW_IS_REFERENCED_2   = ER_ROW_IS_REFERENCED_2;
  DB_MYSQL_ER_CANT_CREATE_TABLE     = ER_CANT_CREATE_TABLE;
  DB_MYSQL_ER_DB_CREATE_EXISTS      = ER_DB_CREATE_EXISTS;
  DB_MYSQL_ER_BAD_DB_ERROR          = ER_BAD_DB_ERROR;
  DB_MYSQL_ER_UNKNOWN_ERROR         = ER_UNKNOWN_ERROR;
  DB_MYSQL_ER_TRUNCATED_WRONG_VALUE = ER_TRUNCATED_WRONG_VALUE;
  DB_MYSQL_ER_DATA_TOO_LONG         = ER_DATA_TOO_LONG;
  DB_MYSQL_ER_DBACCESS_DENIED_ERROR = ER_DBACCESS_DENIED_ERROR;
  DB_MYSQL_ER_ACCESS_DENIED_ERROR   = ER_ACCESS_DENIED_ERROR;
  DB_MYSQL_ER_BAD_NULL_ERROR        = ER_BAD_NULL_ERROR;  { Column cannot be null }
  DB_MYSQL_ER_CHECK_CONSTRAINT_VIOLATED = ER_CHECK_CONSTRAINT_VIOLATED;  { 8.0.16+ CHECK }
  DB_MYSQL_ER_CONSTRAINT_FAILED     = ER_CONSTRAINT_FAILED;      { MariaDB CHECK }
  DB_MYSQL_ER_QUERY_TIMEOUT         = ER_QUERY_TIMEOUT;  { 8.0 MAX_EXECUTION_TIME }
  DB_MYSQL_ER_STATEMENT_TIMEOUT     = ER_STATEMENT_TIMEOUT;  { MariaDB max_statement_time }

  { errmsg.h 客户端错误码族（CR_*，2000..2999）与特例 — 单源透传 }
  DB_MYSQL_CR_MIN                   = CR_MIN_ERROR;
  DB_MYSQL_CR_MAX                   = CR_MAX_ERROR;
  DB_MYSQL_CR_OUT_OF_MEMORY         = CR_OUT_OF_MEMORY;
  DB_MYSQL_CR_COMMANDS_OUT_OF_SYNC  = CR_COMMANDS_OUT_OF_SYNC;

{ sqlite：结果码 + extended 子码 → 类目/约束细分 }
procedure ClassifySqlite(const ACode, AExtended: Integer;
  out ACategory: TDbErrorCategory; out AConstraint: TDbConstraintKind);

{ postgres：SQLSTATE → 类目/约束细分 }
procedure ClassifyPg(const ASqlState: string;
  out ACategory: TDbErrorCategory; out AConstraint: TDbConstraintKind);

{ mysql：CR_*/ER_* 码位 + SQLSTATE → 类目/约束细分。
  码位优先（MySQL 服务端错误以数字为准），SQLSTATE 类前缀只做
  未识别码的兜底；CR_* 客户端族整体落 decConnection（OOM 与
  协议乱序除外——宁可欠归一不错归一）。 }
procedure ClassifyMy(const ACode: Integer; const ASqlState: string;
  out ACategory: TDbErrorCategory; out AConstraint: TDbConstraintKind);

{ odbc：ISO SQLSTATE → 类目/约束细分（V3-A4）。
  ODBC 网关的统一可信信号是 5 字符 SQLSTATE（管理器与驱动按 ISO
  标准填写，含管理器族 IM*/HY*）；NativeError 是驱动专属整数、跨
  驱动无一致语义，本表不消费它（只透传到 EDbError.BackendCode）。
  MySQL 系驱动的欠归一缺口（HY000+1062）由 ClassifyOdbcEx 的
  flavor 感知细化收口。精确码优先，类前缀兜底；
  未识别一律 decUnknown（宁可欠归一不错归一）。 }
procedure ClassifyOdbc(const ASqlState: string;
  out ACategory: TDbErrorCategory; out AConstraint: TDbConstraintKind);

{ odbc + 驱动 flavor 感知归一（D 线收口）：先按 ISO SQLSTATE 归一，
  再在调用方确认驱动为 MySQL 系（SQL_DRIVER_NAME / SQL_DBMS_NAME
  探测命中 mysql/mariadb 词元）时用 NativeError 对照 MySQL 服务端
  码位表做单调提精——
    - 基础归一 decUnknown 且码位可识别 → 采纳 MySQL 类目/细分；
    - 基础已 decConstraint 但泛码（如 23000 无细分）且码位给出
      约束细分 → 只补细分；
    - 其余一律维持基础结果（永不降级、永不矛盾）。
  非 MySQL 驱动（达梦/GBase 等 native code 自成体系）行为与
  ClassifyOdbc 完全一致。 }
procedure ClassifyOdbcEx(const ASqlState: string;
  const ANativeCode: Integer; const AMyFlavor: Boolean;
  out ACategory: TDbErrorCategory; out AConstraint: TDbConstraintKind);

{ redis：错误回复首词 → 类目细分（V3-A5）。
  RESP 错误无数字码位，唯一信号是首词（ERR/Wrongpass/MOVED…，
  调用方经 RespErrorType 大写化后传入）。词元精确匹配，未识别
  一律 decUnknown（宁可欠归一不错归一）；约束细分对键值模型
  不适用（dckNone 恒定）。 }
procedure ClassifyRedis(const AErrType: string;
  out ACategory: TDbErrorCategory; out AConstraint: TDbConstraintKind);

{ dm：DM 原生码位 → 类目/约束细分（V3-DM）。码位优先，SQLSTATE 兜底；
  未识别 decUnknown。 }
procedure ClassifyDm(const ACode: Integer; const ASqlState: string;
  out ACategory: TDbErrorCategory; out AConstraint: TDbConstraintKind);

{ 纯数据载体工厂（owner 反哺：base 零后端细节，db.err 薄转发）。
  L2 依赖根 EDbError 仅暴露泛化 CreateFull；后端细节（Backend 枚举钉死、
  码位/状态槽复用）由本 owner 单源封装，适配层经此构造零聚合 base。
  全部 inline 薄转发至 EDbError.CreateFull 单源，零拷贝（托管串 refcount
  浅拷贝），BYTES_OPS_SINGLE_SOURCE 由外层工厂保证（本单元纯工厂零分配）。 }
function NewDbErrorSqlite(ACode, AExtended: Integer;
  ACategory: TDbErrorCategory; AConstraint: TDbConstraintKind;
  const AMessage: string): EDbError; inline;
function NewDbErrorPg(const ASqlState, ASeverity, ADetail, AMessage: string;
  ACategory: TDbErrorCategory; AConstraint: TDbConstraintKind): EDbError; inline;
function NewDbErrorPgEx(const ASqlState, ASeverity, ADetail, AMessage: string;
  ACategory: TDbErrorCategory; AConstraint: TDbConstraintKind;
  const ASchemaName, ATableName, AColumnName: string): EDbError; inline;
function NewDbErrorMy(ACode: Integer; const ASqlState, AMessage: string;
  ACategory: TDbErrorCategory; AConstraint: TDbConstraintKind): EDbError; inline;
function NewDbErrorOdbc(ANativeCode: Integer; const ASqlState, AMessage: string;
  ACategory: TDbErrorCategory; AConstraint: TDbConstraintKind): EDbError; inline;
function NewDbErrorRedis(const AErrType, AMessage: string;
  ACategory: TDbErrorCategory; AConstraint: TDbConstraintKind): EDbError; inline;
function NewDbErrorDm(ACode: Integer; const ASqlState, AMessage: string;
  ACategory: TDbErrorCategory; AConstraint: TDbConstraintKind): EDbError; inline;

{ IDbSavepointControl 契约输入守卫：名字必须 [A-Za-z0-9_]+
  （会被内插进 SAVEPOINT 语句），违规 fail-closed 抛 EDbError。 }

procedure ValidateDbSavepointName(const ABackend: TDbKind; const AName: string);

implementation

uses
  nextpas.core.bytes.ops;


procedure ClassifySqlite(const ACode, AExtended: Integer;
  out ACategory: TDbErrorCategory; out AConstraint: TDbConstraintKind);
begin
  ACategory := decUnknown;
  AConstraint := dckNone;
  if ACode = DB_SQLITE_CONSTRAINT then
  begin
    ACategory := decConstraint;
    if AExtended = DB_SQLITE_CONSTRAINT_UNIQUE then
      AConstraint := dckUnique
    else if AExtended = DB_SQLITE_CONSTRAINT_PRIMARYKEY then
      AConstraint := dckPrimaryKey
    else if AExtended = DB_SQLITE_CONSTRAINT_FOREIGNKEY then
      AConstraint := dckForeignKey
    else if AExtended = DB_SQLITE_CONSTRAINT_NOTNULL then
      AConstraint := dckNotNull
    else if AExtended = DB_SQLITE_CONSTRAINT_CHECK then
      AConstraint := dckCheck;
    Exit;
  end;
  case ACode of
    DB_SQLITE_BUSY, DB_SQLITE_LOCKED:
      ACategory := decTimeout;         { 锁竞争 }
    DB_SQLITE_INTERRUPT:
      ACategory := decTimeout;         { V3-B6：查询取消（与 pg 57014 同归一） }
    DB_SQLITE_CANTOPEN:
      ACategory := decConnection;      { 库文件打不开 }
    DB_SQLITE_AUTH:
      ACategory := decAuth;
    DB_SQLITE_NOMEM, DB_SQLITE_IOERR, DB_SQLITE_CORRUPT, DB_SQLITE_FULL:
      ACategory := decCapacity;
  end;
end;

procedure ClassifyPg(const ASqlState: string;
  out ACategory: TDbErrorCategory; out AConstraint: TDbConstraintKind);
begin
  ACategory := decUnknown;
  AConstraint := dckNone;
  if Length(ASqlState) < 2 then
    Exit;
  { 精确码优先，类前缀兜底 }
  if ASqlState = '23505' then
  begin
    ACategory := decConstraint;
    AConstraint := dckUnique;
    Exit;
  end
  else if ASqlState = '23503' then
  begin
    ACategory := decConstraint;
    AConstraint := dckForeignKey;
    Exit;
  end
  else if ASqlState = '23502' then
  begin
    ACategory := decConstraint;
    AConstraint := dckNotNull;
    Exit;
  end
  else if ASqlState = '23514' then
  begin
    ACategory := decConstraint;
    AConstraint := dckCheck;
    Exit;
  end
  else if ASqlState = '23P01' then
  begin
    ACategory := decConstraint;
    AConstraint := dckExclusion;
    Exit;
  end
  else if ASqlState = '40P01' then
  begin
    ACategory := decTransaction;       { deadlock_detected }
    Exit;
  end
  else if ASqlState = '57014' then
  begin
    ACategory := decTimeout;           { query_canceled }
    Exit;
  end;

  { 类前缀映射 }
  case ASqlState[1] of
    '0': if Copy(ASqlState, 1, 2) = '08' then
           ACategory := decConnection
         else if Copy(ASqlState, 1, 2) = '0A' then
           ACategory := decNotSupported;
    '2': if Copy(ASqlState, 1, 2) = '23' then
           ACategory := decConstraint
         else if Copy(ASqlState, 1, 2) = '25' then
           ACategory := decTransaction
         else if Copy(ASqlState, 1, 2) = '28' then
           ACategory := decAuth;
    '4': if Copy(ASqlState, 1, 2) = '42' then
           ACategory := decSyntax
         else if Copy(ASqlState, 1, 2) = '40' then
           ACategory := decTransaction;
    '5': if Copy(ASqlState, 1, 2) = '53' then
           ACategory := decCapacity
         else if Copy(ASqlState, 1, 2) = '54' then
           ACategory := decCapacity;
  end;
end;

procedure ClassifyMy(const ACode: Integer; const ASqlState: string;
  out ACategory: TDbErrorCategory; out AConstraint: TDbConstraintKind);
begin
  ACategory := decUnknown;
  AConstraint := dckNone;

  { 约束族：双码位细分 }
  if (ACode = DB_MYSQL_ER_DUP_ENTRY) or (ACode = DB_MYSQL_ER_DUP_KEY) then
  begin
    ACategory := decConstraint;
    AConstraint := dckUnique;
    Exit;
  end
  else if (ACode = DB_MYSQL_ER_NO_REFERENCED_ROW) or
          (ACode = DB_MYSQL_ER_NO_REFERENCED_ROW_2) or
          (ACode = DB_MYSQL_ER_ROW_IS_REFERENCED) or
          (ACode = DB_MYSQL_ER_ROW_IS_REFERENCED_2) then
  begin
    ACategory := decConstraint;
    AConstraint := dckForeignKey;
    Exit;
  end
  else if ACode = DB_MYSQL_ER_BAD_NULL_ERROR then
  begin
    ACategory := decConstraint;
    AConstraint := dckNotNull;
    Exit;
  end
  else if (ACode = DB_MYSQL_ER_CHECK_CONSTRAINT_VIOLATED) or
          (ACode = DB_MYSQL_ER_CONSTRAINT_FAILED) then
  begin
    ACategory := decConstraint;
    AConstraint := dckCheck;
    Exit;
  end
  else if (ACode = DB_MYSQL_ER_TRUNCATED_WRONG_VALUE) or
          (ACode = DB_MYSQL_ER_DATA_TOO_LONG) then
  begin
    ACategory := decConstraint;
    Exit;
  end;

  case ACode of
    DB_MYSQL_ER_LOCK_DEADLOCK, DB_MYSQL_ER_LOCK_TABLE_FULL:
      ACategory := decTransaction;
    DB_MYSQL_ER_LOCK_WAIT_TIMEOUT, DB_MYSQL_ER_QUERY_TIMEOUT,
    DB_MYSQL_ER_STATEMENT_TIMEOUT:
      ACategory := decTimeout;
    DB_MYSQL_ER_DBACCESS_DENIED_ERROR, DB_MYSQL_ER_ACCESS_DENIED_ERROR:
      ACategory := decAuth;
    DB_MYSQL_ER_PARSE_ERROR, DB_MYSQL_ER_EMPTY_QUERY,
    DB_MYSQL_ER_BAD_FIELD_ERROR, DB_MYSQL_ER_NO_SUCH_TABLE,
    DB_MYSQL_ER_TABLE_EXISTS_ERROR, DB_MYSQL_ER_BAD_TABLE_ERROR:
      ACategory := decSyntax;             { 对齐 pg class-42 归一 }
    DB_MYSQL_ER_NOT_SUPPORTED_YET, DB_MYSQL_ER_OPTION_PREVENTS_STATEMENT:
      ACategory := decNotSupported;
    DB_MYSQL_ER_CANT_CREATE_TABLE, DB_MYSQL_ER_UNKNOWN_ERROR:
      ACategory := decConstraint;        { 1005/1105 容量过度归一修正：约束失败细分（外键/表定义），非资源容量 }
    DB_MYSQL_ER_BAD_DB_ERROR, DB_MYSQL_ER_DB_CREATE_EXISTS:
      ACategory := decConnection;
    DB_MYSQL_CR_OUT_OF_MEMORY:
      ACategory := decCapacity;          { 全量容量：仅 OOM 归容量，其余容量误判已收敛 }
  else
    { CR_* 客户端族整体落 decConnection；协议乱序(2014)是编程错误，欠归一 }
    if (ACode >= DB_MYSQL_CR_MIN) and (ACode <= DB_MYSQL_CR_MAX) and
       (ACode <> DB_MYSQL_CR_COMMANDS_OUT_OF_SYNC) then
      ACategory := decConnection;
  end;

  { 未识别码：SQLSTATE 类前缀兜底（MySQL 的 SQLSTATE 可信度低于 pg，
    只收高置信类） }
  if (ACategory = decUnknown) and (Length(ASqlState) >= 2) then
  begin
    if Copy(ASqlState, 1, 2) = '23' then
      ACategory := decConstraint
    else if Copy(ASqlState, 1, 2) = '08' then
      ACategory := decConnection
    else if Copy(ASqlState, 1, 2) = '28' then
      ACategory := decAuth
    else if Copy(ASqlState, 1, 2) = '42' then
      ACategory := decSyntax;
  end;
end;

procedure ClassifyOdbc(const ASqlState: string;
  out ACategory: TDbErrorCategory; out AConstraint: TDbConstraintKind);
begin
  ACategory := decUnknown;
  AConstraint := dckNone;
  if Length(ASqlState) < 2 then
    Exit;

  { 约束族精确细分：ISO 23000 类子码与 pg 同构（conformant 驱动
    原样透传），直接复用统一约束细分 }
  if ASqlState = '23505' then
  begin
    ACategory := decConstraint;
    AConstraint := dckUnique;
    Exit;
  end
  else if ASqlState = '23503' then
  begin
    ACategory := decConstraint;
    AConstraint := dckForeignKey;
    Exit;
  end
  else if ASqlState = '23502' then
  begin
    ACategory := decConstraint;
    AConstraint := dckNotNull;
    Exit;
  end
  else if ASqlState = '23514' then
  begin
    ACategory := decConstraint;
    AConstraint := dckCheck;
    Exit;
  end;

  { 管理器/驱动族与高频状态码精确钉死 }
  case ASqlState of
    '40001': ACategory := decTransaction;   { serialization failure / deadlock }
    '57014',                                  { query canceled（pg 经网关透传）}
    'HYT00', 'HYT01',                         { timeout expired / conn timeout }
    'HY008': ACategory := decTimeout;         { operation canceled }
    'HY001', 'HY013':
      ACategory := decCapacity;               { 管理器内存分配/管理失败 }
    'IM002', 'IM003':
      ACategory := decConnection;             { 数据源未找到 / 驱动加载失败 }
    'IM001', 'HYC00':
      ACategory := decNotSupported;           { 驱动不支持该函数/可选特性未实现 }
  else
    begin
      { ISO SQL 类前缀兜底（08 连接 / 23 完整性 / 25,40 事务 /
        28 授权 / 42 语法与访问规则 / 0A 特性不支持 /
        53,54 资源与程序上限 / 58 系统错误）；
        IM 族其余（IM004..IM014 分配/建连失败）落连接类；
        HY 族其余（HY010 函数顺序、HY092 无效属性等编程错误）
        欠归一保持 unknown。 }
      case Copy(ASqlState, 1, 2) of
        '08': ACategory := decConnection;
        '23': ACategory := decConstraint;
        '25', '40': ACategory := decTransaction;
        '28': ACategory := decAuth;
        '42': ACategory := decSyntax;
        '0A': ACategory := decNotSupported;
        '53', '54': ACategory := decCapacity;
        '58': ACategory := decConnection;
        'IM': ACategory := decConnection;
      end;
    end;
  end;
end;

{ MySQL 码位表单调提精（仅 ClassifyOdbcEx 消费）。
  ClassifyMy 第二参传空串：跳过其 SQLSTATE 兜底分支，纯码位判定。 }
procedure RefineWithMyCode(const ANativeCode: Integer;
  var ACategory: TDbErrorCategory; var AConstraint: TDbConstraintKind);
var
  LCat: TDbErrorCategory;
  LCon: TDbConstraintKind;
begin
  ClassifyMy(ANativeCode, '', LCat, LCon);
  if LCat = decUnknown then
    Exit;                                { 未识别码位：维持基础归一 }
  if ACategory = decUnknown then
  begin
    ACategory := LCat;                   { 欠归一 → 采纳码位类目 }
    AConstraint := LCon;
  end
  else if (ACategory = LCat) and (AConstraint = dckNone) and
          (LCon <> dckNone) then
    AConstraint := LCon;                 { 同类泛约束 → 只补细分 }
end;

procedure ClassifyOdbcEx(const ASqlState: string;
  const ANativeCode: Integer; const AMyFlavor: Boolean;
  out ACategory: TDbErrorCategory; out AConstraint: TDbConstraintKind);
begin
  ClassifyOdbc(ASqlState, ACategory, AConstraint);
  if AMyFlavor and (ANativeCode <> 0) then
    RefineWithMyCode(ANativeCode, ACategory, AConstraint);
end;

procedure ClassifyRedis(const AErrType: string;
  out ACategory: TDbErrorCategory; out AConstraint: TDbConstraintKind);
begin
  ACategory := decUnknown;
  AConstraint := dckNone;
  if AErrType = 'ERR' then
    ACategory := decSyntax              { unknown cmd / arity / 非法值 }
  else if (AErrType = 'WRONGPASS') or (AErrType = 'NOAUTH') then
    ACategory := decAuth
  else if (AErrType = 'MOVED') or (AErrType = 'ASK') or
          (AErrType = 'CLUSTERDOWN') or (AErrType = 'READONLY') then
    ACategory := decConnection          { 集群路由/副本拒写 }
  else if (AErrType = 'LOADING') or (AErrType = 'BUSY') or
          (AErrType = 'MASTERDOWN') or (AErrType = 'TRYAGAIN') then
    ACategory := decCapacity            { 服务端瞬态资源态/集群重试 }
  else if AErrType = 'EXECABORT' then
    ACategory := decTransaction         { MULTI 队列被 watch/语法否决 }
  else if AErrType = 'NOSCRIPT' then
    ACategory := decNotSupported
  else if AErrType = 'CROSSSLOT' then
    ACategory := decSyntax              { 跨槽键不满足集群约束 }
  else if AErrType = 'WRONGTYPE' then
  begin
    ACategory := decConstraint;         { 类型不匹配视为约束 }
  end;
end;

procedure ClassifyDm(const ACode: Integer; const ASqlState: string;
  out ACategory: TDbErrorCategory; out AConstraint: TDbConstraintKind);
begin
  ACategory := decUnknown;
  AConstraint := dckNone;
  case ACode of
    -1007: begin ACategory := decConstraint; AConstraint := dckUnique; Exit; end;
    -1048: begin ACategory := decConstraint; AConstraint := dckNotNull; Exit; end;
    -1216, -1217, -1451, -1452: begin ACategory := decConstraint; AConstraint := dckForeignKey; Exit; end;
    -3819: begin ACategory := decConstraint; AConstraint := dckCheck; Exit; end;
    -2007, -2106, -2105: begin ACategory := decSyntax; Exit; end;
    -1213: begin ACategory := decTransaction; Exit; end;
    -1205: begin ACategory := decTimeout; Exit; end;
    -2003, -11011, -6001: begin ACategory := decConnection; Exit; end;
    -11000: begin ACategory := decNotSupported; Exit; end;
    -11007, -11012: begin ACategory := decCapacity; Exit; end;
  end;
  if Length(ASqlState) >= 2 then
  begin
    if Copy(ASqlState, 1, 2) = '23' then ACategory := decConstraint
    else if Copy(ASqlState, 1, 2) = '08' then ACategory := decConnection
    else if Copy(ASqlState, 1, 2) = '28' then ACategory := decAuth
    else if Copy(ASqlState, 1, 2) = '42' then ACategory := decSyntax;
  end;
end;

function NewDbErrorSqlite(ACode, AExtended: Integer;
  ACategory: TDbErrorCategory; AConstraint: TDbConstraintKind;
  const AMessage: string): EDbError; inline;
begin
  Result := EDbError.CreateFull(dbkSqlite, ACode, AExtended, '', '', '', ACategory, AConstraint, AMessage);
end;

function NewDbErrorPg(const ASqlState, ASeverity, ADetail, AMessage: string;
  ACategory: TDbErrorCategory; AConstraint: TDbConstraintKind): EDbError; inline;
begin
  Result := EDbError.CreateFull(dbkPostgres, 0, 0, ASqlState, ASeverity, ADetail, ACategory, AConstraint, AMessage);
end;

function NewDbErrorPgEx(const ASqlState, ASeverity, ADetail, AMessage: string;
  ACategory: TDbErrorCategory; AConstraint: TDbConstraintKind;
  const ASchemaName, ATableName, AColumnName: string): EDbError; inline;
begin
  Result := EDbError.CreateFull(dbkPostgres, 0, 0, ASqlState, ASeverity, ADetail, ACategory, AConstraint, ASchemaName, ATableName, AColumnName, AMessage);
end;

function NewDbErrorMy(ACode: Integer; const ASqlState, AMessage: string;
  ACategory: TDbErrorCategory; AConstraint: TDbConstraintKind): EDbError; inline;
begin
  Result := EDbError.CreateFull(dbkMysql, ACode, 0, ASqlState, '', '', ACategory, AConstraint, AMessage);
end;

function NewDbErrorOdbc(ANativeCode: Integer; const ASqlState, AMessage: string;
  ACategory: TDbErrorCategory; AConstraint: TDbConstraintKind): EDbError; inline;
begin
  Result := EDbError.CreateFull(dbkOdbc, ANativeCode, 0, ASqlState, '', '', ACategory, AConstraint, AMessage);
end;

function NewDbErrorRedis(const AErrType, AMessage: string;
  ACategory: TDbErrorCategory; AConstraint: TDbConstraintKind): EDbError; inline;
begin
  Result := EDbError.CreateFull(dbkRedis, 0, 0, AErrType, '', '', ACategory, AConstraint, AMessage);
end;

function NewDbErrorDm(ACode: Integer; const ASqlState, AMessage: string;
  ACategory: TDbErrorCategory; AConstraint: TDbConstraintKind): EDbError; inline;
begin
  Result := EDbError.CreateFull(dbkDm, ACode, 0, ASqlState, '', '', ACategory, AConstraint, AMessage);
end;

procedure ValidateDbSavepointName(const ABackend: TDbKind;
  const AName: string);
var
  I: Integer;
begin
  if AName = '' then
    raise EDbError.CreateSimple(ABackend, 'empty savepoint name');
  for I := 1 to Length(AName) do
    if not (AName[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      raise EDbError.CreateSimple(ABackend,
        'savepoint name must be [A-Za-z0-9_]: "' + AName + '"');
end;

end.
