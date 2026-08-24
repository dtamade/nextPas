unit nextpas.core.db.odbc.base;

{** @desc ODBC L2 module: public constants, handle vocabulary and error
       type. Raw C ABI declarations live in nextpas.core.db.odbc.ffi
       (resolved at runtime via nextpas.core.db.odbc.loader, dlopen on
       unixODBC libodbc.so.2 — same shape as the pg/mysql loader lanes).
       The friendly adapter surface (IDbConnection over a DSN) will be
       nextpas.core.db.odbc.adapter (V3-A4); the unified factory lane is
       V3-A5. This unit is also the gateway seam for driver-managed
       national databases via ODBC (roadmap D4 option B).

       Constants are the ISO CLI / sql.h+sqlext.h stable vocabulary:
       return codes, handle types, env/conn/statement attributes, SQL
       data types and C binding types. Only values exercised by A3/A4 are
       pinned; nothing speculative. EDbOdbcError lives here so the loader
       can raise it too. *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

const
  { ===== shared-library candidates, probed in order =====
    Linux ships unixODBC as versioned soname only (.so.2 current, .so.1
    legacy); iODBC registers .so.1 too but exports the identical ISO CLI
    surface we bind. Windows name kept for the future win64 lane. }
  ODBC_LIBRARY_CANDIDATES: array[0..3] of string = (
    'libodbc.so.2',
    'libodbc.so.1',
    'libodbc.so',
    'odbc32.dll'
  );

const
  { ===== return codes (SQLRETURN) ===== }
  SQL_SUCCESS            = 0;
  SQL_SUCCESS_WITH_INFO  = 1;
  SQL_STILL_EXECUTING    = 2;
  SQL_NEED_DATA          = 99;
  SQL_NO_DATA            = 100;   { fetch 越界 / update 无匹配行 }
  SQL_ERROR              = -1;
  SQL_INVALID_HANDLE     = -2;

const
  { ===== handle types ===== }
  SQL_HANDLE_ENV   = 1;
  SQL_HANDLE_DBC   = 2;
  SQL_HANDLE_STMT  = 3;
  SQL_HANDLE_DESC  = 4;

const
  { ===== boolean literals ===== }
  SQL_FALSE = 0;
  SQL_TRUE  = 1;

const
  { ===== environment attributes ===== }
  SQL_ATTR_ODBC_VERSION = 200;
  SQL_OV_ODBC2          = 2;
  SQL_OV_ODBC3          = 3;

const
  { ===== connection attributes ===== }
  SQL_ATTR_ACCESS_MODE         = 101;
  SQL_ATTR_AUTOCOMMIT          = 102;
  SQL_AUTOCOMMIT_OFF           = 0;
  SQL_AUTOCOMMIT_ON            = 1;
  SQL_ATTR_LOGIN_TIMEOUT       = 103;
  SQL_ATTR_CONNECTION_TIMEOUT  = 113;

const
  { ===== statement attributes ===== }
  SQL_ATTR_QUERY_TIMEOUT = 0;    { 秒；0 = 驱动默认 }
  SQL_ATTR_MAX_ROWS      = 1;
  SQL_ATTR_PARAMSET_SIZE = 22;   { 数组绑定行数（C2 预留） }
  SQL_ATTR_ROW_ARRAY_SIZE = 27;  { 行集大小（批量 fetch，C2 预留） }

const
  { ===== transaction completion (SQLEndTran) ===== }
  SQL_COMMIT   = 0;
  SQL_ROLLBACK = 1;

const
  { ===== SQL data types（描述符 ParamType/DescribeCol 用）===== }
  SQL_UNKNOWN_TYPE   = 0;
  SQL_CHAR           = 1;
  SQL_NUMERIC        = 2;
  SQL_DECIMAL        = 3;
  SQL_INTEGER        = 4;
  SQL_SMALLINT       = 5;
  SQL_FLOAT          = 6;
  SQL_REAL           = 7;
  SQL_DOUBLE         = 8;
  SQL_DATETIME       = 9;
  SQL_VARCHAR        = 12;
  SQL_LONGVARCHAR    = -1;
  SQL_BINARY         = -2;
  SQL_VARBINARY      = -3;
  SQL_LONGVARBINARY  = -4;
  SQL_BIGINT         = -5;
  SQL_TINYINT        = -6;
  SQL_BIT            = -7;
  SQL_WCHAR          = -8;
  SQL_WVARCHAR       = -9;
  SQL_WLONGVARCHAR   = -10;
  SQL_GUID           = -11;
  SQL_TYPE_DATE      = 91;
  SQL_TYPE_TIME      = 92;
  SQL_TYPE_TIMESTAMP = 93;

const
  { ===== C binding types for GetData/BindCol/BindParameter =====
    有符号/无符号变体 = 基型 + offset（sql.h 定义，非自造）。}
  SQL_SIGNED_OFFSET   = -20;
  SQL_UNSIGNED_OFFSET = -22;

  SQL_C_CHAR    = SQL_CHAR;        { 1 }
  SQL_C_WCHAR   = SQL_WCHAR;       { -8 }
  SQL_C_BINARY  = SQL_BINARY;      { -2 }
  SQL_C_BIT     = SQL_BIT;         { -7 }
  SQL_C_TINYINT = SQL_TINYINT;     { -6 }
  SQL_C_STINYINT = SQL_C_TINYINT + SQL_SIGNED_OFFSET;    { -26 }
  SQL_C_UTINYINT = SQL_C_TINYINT + SQL_UNSIGNED_OFFSET;  { -28 }
  SQL_C_SHORT   = SQL_SMALLINT;    { 5 }
  SQL_C_SSHORT  = SQL_C_SHORT + SQL_SIGNED_OFFSET;      { -15 }
  SQL_C_USHORT  = SQL_C_SHORT + SQL_UNSIGNED_OFFSET;    { -17 }
  SQL_C_LONG    = SQL_INTEGER;     { 4 }
  SQL_C_SLONG   = SQL_C_LONG + SQL_SIGNED_OFFSET;       { -16 }
  SQL_C_ULONG   = SQL_C_LONG + SQL_UNSIGNED_OFFSET;     { -18 }
  SQL_C_FLOAT   = SQL_REAL;        { 7 }
  SQL_C_DOUBLE  = SQL_DOUBLE;      { 8 }
  SQL_C_SBIGINT = SQL_BIGINT + SQL_SIGNED_OFFSET;       { -25 }
  SQL_C_UBIGINT = SQL_BIGINT + SQL_UNSIGNED_OFFSET;     { -27 }
  SQL_C_TYPE_TIMESTAMP = SQL_TYPE_TIMESTAMP;            { 93 }
  SQL_C_DEFAULT = 99;

const
  { ===== length indicators ===== }
  SQL_NULL_DATA = -1;   { 绑定指示符：值为 NULL }
  SQL_NTS       = -3;   { 输入串以 NUL 结尾 }
  SQL_NO_TOTAL  = -4;   { GetData 截断时长度未知 }

const
  { ===== SQLGetInfo InfoTypes（V3-A4 能力探测）=====
    数值出处：微软官方 ODBC SDK 头（sql.h/sqlext.h；本机以
    mingw-w64 交付件核实），unixODBC 同值实现同一规范。 }
  SQL_DRIVER_NAME            = 6;    { 驱动库文件名（诊断展示）}
  SQL_DRIVER_VER             = 7;    { 驱动版本串 }
  SQL_DBMS_NAME              = 17;   { 后端产品名（如 'PostgreSQL'）}
  SQL_DBMS_VER               = 18;   { 后端产品版本串 }
  SQL_IDENTIFIER_CASE        = 28;   { 标识符大小写处理方式，SQL_IC_* }
  SQL_IDENTIFIER_QUOTE_CHAR  = 29;   { 引用标识符字符（通常 '"'）}
  SQL_TXN_CAPABLE            = 46;   { 事务支持范围，SQL_TC_* }
  SQL_GETDATA_EXTENSIONS     = 81;   { GetData 放宽能力位，SQL_GD_* }

const
  { ===== SQLGetInfo 结果词汇 ===== }
  { 标识符大小写（SQL_IDENTIFIER_CASE 取值）}
  SQL_IC_UPPER     = 1;  { 折叠大写 → 大小写不敏感 }
  SQL_IC_LOWER     = 2;
  SQL_IC_SENSITIVE = 3;  { 大小写敏感 }
  SQL_IC_MIXED     = 4;

  { 事务支持范围（SQL_TXN_CAPABLE 取值）：SQL_TC_NONE = 不支持事务 }
  SQL_TC_NONE       = 0;
  SQL_TC_DML        = 1;
  SQL_TC_ALL        = 2;   { 注意：ALL=2 在 DDL_COMMIT(3)/DDL_IGNORE(4) 之前 }
  SQL_TC_DDL_COMMIT = 3;
  SQL_TC_DDL_IGNORE = 4;

  { GetData 放宽能力位（SQL_GETDATA_EXTENSIONS 位掩码）}
  SQL_GD_ANY_COLUMN = $00000001;  { 列可乱序取 }
  SQL_GD_ANY_ORDER  = $00000002;  { 可重复/乱序取同列 }

const
  { ===== nullability（DescribeCol）===== }
  SQL_NO_NULLS        = 0;
  SQL_NULLABLE        = 1;
  SQL_NULLABLE_UNKNOWN = 2;

const
  { ===== SQLDriverConnect completion ===== }
  SQL_DRIVER_NOPROMPT = 0;

type
  { 诊断记录：SQLGetDiagRec 单条归一结果。SqlState 是 5 字符 ANSI 状态码
    （ISO 标准，如 IM002=数据源未找到、08001=无法建立连接、23000=完整性
    违约），A4 据此前缀分类到 TDbErrorCategory。 }
  TOdbcDiagRec = record
    SqlState: string;
    NativeError: Integer;
    Message: string;
  end;

  { 诊断记录集：一次失败可有多条（驱动栈逐层附加） }
  TOdbcDiagRecs = array of TOdbcDiagRec;

  {** ODBC 层错误：loader 失败与 A4 归一前的原始诊断都走本类型。
      RetCode 是 SQLRETURN，SqlState 取首条诊断（可能为空——句柄无效
      时连诊断都取不到）。 *}
  EDbOdbcError = class(ENextPasError)
  private
    FRetCode: Integer;
    FSqlState: string;
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AMessage: string; ARetCode: Integer;
      const ASqlState: string = ''); overload;
    property RetCode: Integer read FRetCode;
    property SqlState: string read FSqlState;
  end;

implementation

constructor EDbOdbcError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
  FRetCode := 0;
  FSqlState := '';
end;

constructor EDbOdbcError.Create(const AMessage: string; ARetCode: Integer;
  const ASqlState: string);
begin
  inherited Create(AMessage);
  FRetCode := ARetCode;
  FSqlState := ASqlState;
end;

end.
