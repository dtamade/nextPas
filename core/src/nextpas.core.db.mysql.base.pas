unit nextpas.core.db.mysql.base;

{** @desc MySQL/MariaDB L2 module: public constants and error types.
       Raw C ABI declarations live in nextpas.core.db.mysql.ffi (resolved
       at runtime via nextpas.core.db.mysql.loader, dlopen on
       libmysqlclient.so.* or libmariadb.so.*). The friendly surface
       (TMyConn / TMyQuery) will live in nextpas.core.db.mysql.conn (V3-A2)
       and be re-exported by the nextpas.core.db factory lane (V3-A3/A5).
       EMySqlError lives here so the loader can raise it too.

       Error-code vocabulary spans two disjoint ranges, mirroring the C
       headers: CR_* client errors (2000..2999, raised before/during
       transport) and ER_* server errors (>1000, parsed from the wire).
       Classification into TDbErrorCategory happens at the adapter layer
       (A2); this unit only fixes the numbers. *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

const
  { ===== shared-library candidates, probed in order =====
    Linux ships versioned sonames only (no dev symlinks), hence dlopen.
    Oracle libmysqlclient current soname is .so.21 (8.x); older stacks
    carry .20/.19/.18. MariaDB Connector/C is ABI-compatible for the
    whole client C API and registers as .so.3/.so.2. First open wins;
    flavor is auto-detected afterwards (see TMysqlFlavor). }
  MYSQL_LIBRARY_CANDIDATES: array[0..5] of string = (
    'libmysqlclient.so.21',
    'libmysqlclient.so.20',
    'libmysqlclient.so.19',
    'libmysqlclient.so.18',
    'libmariadb.so.3',
    'libmariadb.so.2'
  );

const
  { ===== mysql_option values (stable across both flavors) ===== }
  MYSQL_OPT_CONNECT_TIMEOUT = 0;
  MYSQL_OPT_COMPRESS        = 1;
  MYSQL_INIT_COMMAND        = 3;
  MYSQL_SET_CHARSET_NAME    = 7;
  MYSQL_OPT_LOCAL_INFILE    = 8;
  MYSQL_OPT_READ_TIMEOUT    = 11;
  MYSQL_OPT_WRITE_TIMEOUT   = 12;
  MYSQL_OPT_RECONNECT       = 20;

  { ===== CLIENT_* capability flags for mysql_real_connect ===== }
  CLIENT_LONG_PASSWORD     = 1;
  CLIENT_FOUND_ROWS        = 2;
  CLIENT_LONG_FLAG         = 4;
  CLIENT_CONNECT_WITH_DB   = 8;
  CLIENT_COMPRESS          = 32;
  CLIENT_LOCAL_FILES       = 128;
  CLIENT_PROTOCOL_41       = 512;
  CLIENT_INTERACTIVE       = 1024;
  CLIENT_SSL               = 2048;
  CLIENT_TRANSACTIONS      = 8192;
  CLIENT_SECURE_CONNECTION = 32768;
  CLIENT_MULTI_STATEMENTS  = 65536;   { 1 shl 16 — 脚本执行前提 }
  CLIENT_MULTI_RESULTS     = 131072;  { 1 shl 17 — 多语句必须伴随位 }

  { ===== mysql_stmt_fetch return codes ===== }
  MYSQL_NO_DATA        = 100;
  MYSQL_DATA_TRUNCATED = 101;

const
  { ===== CR_* client error codes (transport/pre-query failures) =====
    Retry-relevant family: SERVER_GONE / SERVER_LOST / CONN_HOST_ERROR.
    Adapter maps these to decConnection/decTimeout (A2). }
  CR_MIN_ERROR            = 2000;
  CR_UNKNOWN_ERROR        = 2000;
  CR_SOCKET_CREATE_ERROR  = 2001;
  CR_CONNECTION_ERROR     = 2002;  { 本地 socket 连不上 }
  CR_CONN_HOST_ERROR      = 2003;  { TCP 主机连不上/拒绝 }
  CR_IPSOCK_ERROR         = 2004;
  CR_UNKNOWN_HOST         = 2005;
  CR_SERVER_GONE_ERROR    = 2006;  { server has gone away }
  CR_VERSION_ERROR        = 2007;
  CR_OUT_OF_MEMORY        = 2008;
  CR_SERVER_HANDSHAKE_ERR = 2012;
  CR_SERVER_LOST          = 2013;  { 查询中途断连 }
  CR_COMMANDS_OUT_OF_SYNC = 2014;
  CR_SSL_CONNECTION_ERROR = 2026;
  CR_MALFORMED_PACKET     = 2030;
  CR_INVALID_CONN_HANDLE  = 2048;
  CR_NO_RESULT_SET        = 2053;
  CR_NOT_IMPLEMENTED      = 2054;
  CR_SERVER_LOST_EXTENDED = 2055;
  CR_MAX_ERROR            = 2999;

  { ===== ER_* server error codes (subset fixed for classification) =====
    按数值升序排列，便于审计与门禁对照；分类见 db.err ClassifyMy：
    约束族 1022/1062/1048/1366/1406/1216/1217/1451/1452/3819/4025 →
      decConstraint；重试族 1205/1206/1213 → Transaction/Timeout；
    鉴权 1044/1045 → Auth；语法 1054/1146/1050/1051/1064/1065 → Syntax；
    能力 1235/1290 → NotSupported；容量/连接 1005/1105/1049/1007。 }
  ER_CANT_CREATE_TABLE         = 1005;  { decCapacity }
  ER_DB_CREATE_EXISTS          = 1007;  { decConnection }
  ER_DUP_KEY                   = 1022;  { decConstraint unique }
  ER_DBACCESS_DENIED_ERROR     = 1044;  { decAuth }
  ER_ACCESS_DENIED_ERROR       = 1045;  { decAuth }
  ER_BAD_NULL_ERROR            = 1048;  { decConstraint notnull }
  ER_BAD_DB_ERROR              = 1049;  { decConnection }
  ER_TABLE_EXISTS_ERROR        = 1050;  { decSyntax }
  ER_BAD_TABLE_ERROR           = 1051;  { decSyntax }
  ER_BAD_FIELD_ERROR           = 1054;  { decSyntax }
  ER_DUP_ENTRY                 = 1062;  { decConstraint unique }
  ER_PARSE_ERROR               = 1064;  { decSyntax }
  ER_EMPTY_QUERY               = 1065;  { decSyntax }
  ER_UNKNOWN_ERROR             = 1105;  { decCapacity }
  ER_NO_SUCH_TABLE             = 1146;  { decSyntax }
  ER_LOCK_WAIT_TIMEOUT         = 1205;  { decTimeout }
  ER_LOCK_TABLE_FULL           = 1206;  { decTransaction }
  ER_LOCK_DEADLOCK             = 1213;  { decTransaction }
  ER_NO_REFERENCED_ROW         = 1216;  { decConstraint fk }
  ER_ROW_IS_REFERENCED         = 1217;  { decConstraint fk }
  ER_NOT_SUPPORTED_YET         = 1235;  { decNotSupported }
  ER_OPTION_PREVENTS_STATEMENT = 1290;  { decNotSupported }
  ER_TRUCATED_WRONG_VALUE      = 1366;  { 拼写沿用历史常量名；新代码用 TRUNCATED 拼写 }
  ER_TRUNCATED_WRONG_VALUE     = 1366;  { 正确拼写别名 decConstraint }
  ER_DATA_TOO_LONG             = 1406;  { decConstraint }
  ER_ROW_IS_REFERENCED_2       = 1451;  { decConstraint fk }
  ER_NO_REFERENCED_ROW_2       = 1452;  { decConstraint fk }
  ER_STATEMENT_TIMEOUT         = 1969;  { decTimeout MariaDB }
  ER_QUERY_TIMEOUT             = 3024;  { decTimeout 8.0 }
  ER_CHECK_CONSTRAINT_VIOLATED = 3819;  { decConstraint check 8.0.16+ }
  ER_CONSTRAINT_FAILED         = 4025;  { decConstraint check MariaDB }

const
  { ===== enum_field_types (列类型元数据；adapter 映射到 TDbColumnType) ===== }
  MYSQL_TYPE_DECIMAL     = 0;
  MYSQL_TYPE_TINY        = 1;
  MYSQL_TYPE_SHORT       = 2;
  MYSQL_TYPE_LONG        = 3;
  MYSQL_TYPE_FLOAT       = 4;
  MYSQL_TYPE_DOUBLE      = 5;
  MYSQL_TYPE_NULL        = 6;
  MYSQL_TYPE_TIMESTAMP   = 7;
  MYSQL_TYPE_LONGLONG    = 8;
  MYSQL_TYPE_INT24       = 9;
  MYSQL_TYPE_DATE        = 10;
  MYSQL_TYPE_TIME        = 11;
  MYSQL_TYPE_DATETIME    = 12;
  MYSQL_TYPE_YEAR        = 13;
  MYSQL_TYPE_NEWDATE     = 14;
  MYSQL_TYPE_VARCHAR     = 15;
  MYSQL_TYPE_BIT         = 16;
  MYSQL_TYPE_TIMESTAMP2  = 17;
  MYSQL_TYPE_DATETIME2   = 18;
  MYSQL_TYPE_TIME2       = 19;
  MYSQL_TYPE_JSON        = 245;
  MYSQL_TYPE_NEWDECIMAL  = 246;
  MYSQL_TYPE_ENUM        = 247;
  MYSQL_TYPE_SET         = 248;
  MYSQL_TYPE_TINY_BLOB   = 249;
  MYSQL_TYPE_MEDIUM_BLOB = 250;
  MYSQL_TYPE_LONG_BLOB   = 251;
  MYSQL_TYPE_BLOB        = 252;
  MYSQL_TYPE_VAR_STRING  = 253;
  MYSQL_TYPE_STRING      = 254;
  MYSQL_TYPE_GEOMETRY    = 255;

  { ===== 字段标志位（结果元数据用） ===== }
  NOT_NULL_FLAG       = 1;
  PRI_KEY_FLAG        = 2;
  UNIQUE_KEY_FLAG     = 4;
  MULTIPLE_KEY_FLAG   = 8;
  BLOB_FLAG           = 16;
  UNSIGNED_FLAG       = 32;
  ZEROFILL_FLAG       = 64;
  BINARY_FLAG         = 128;
  AUTO_INCREMENT_FLAG = 512;
  NUM_FLAG            = 32768;

type
  { Opaque C handles — adapter never touches struct fields directly }
  TMysql      = Pointer;      { MYSQL*      }
  TMysqlRes   = Pointer;      { MYSQL_RES*  }
  TMysqlStmt  = Pointer;      { MYSQL_STMT* }
  TMysqlRow   = PPAnsiChar;   { MYSQL_ROW (char**) — 第 i 列 = (Row + i)^ }
  TMysqlUll   = QWord;        { my_ulonglong }

  { 库方言：同一 C API、两套实现。影响 MYSQL_BIND 内部布局与个别符号
    导出（library_init/end、escape_quote 仅 Oracle 有真符号）；loader
    经 MariaDB 独有符号存在性探测填充。 }
  TMysqlFlavor = (
    mfUnknown,
    mfMysql,     { Oracle libmysqlclient }
    mfMariadb    { MariaDB Connector/C }
  );

  {** @desc MYSQL_FIELD 镜像（LP64，两家头文件自 4.x 起布局一致）。
    只声明 adapter 消费的成员，按自然对齐排布；sizeof 由门禁钉死=128。
    偏移注释即契约。 *}
  TMysqlFieldRec = record
    Name: PAnsiChar;            { 0   }
    OrgName: PAnsiChar;         { 8   }
    Table_: PAnsiChar;          { 16  }
    OrgTable: PAnsiChar;        { 24  }
    Db: PAnsiChar;              { 32  }
    Catalog: PAnsiChar;         { 40  }
    Def: PAnsiChar;             { 48  }
    Length: QWord;              { 56  C unsigned long }
    MaxLength: QWord;           { 64  }
    NameLength: Cardinal;       { 72  }
    OrgNameLength: Cardinal;    { 76  }
    TableLength: Cardinal;      { 80  }
    OrgTableLength: Cardinal;   { 84  }
    DbLength: Cardinal;         { 88  }
    CatalogLength: Cardinal;    { 92  }
    DefLength: Cardinal;        { 96  }
    Flags: Cardinal;            { 100 }
    Decimals: Cardinal;         { 104 }
    CharsetNr: Cardinal;        { 108 }
    Typ: Cardinal;              { 112 enum_field_types }
    Extension: Pointer;         { 120 }
  end;                          { sizeof = 128 }

  {** @desc 规范参数绑定描述符。两家方言的 MYSQL_BIND 原生布局在
    buffer_type/is_unsigned 上偏移与宽度不同，且无法从 dlsym 校验；
    连接层（A2）把本描述符按检测到的 flavor 编组为原生块，ABI 分叉
    只允许存在于该一处。原生镜像 TMysqlBindMysql/TMysqlBindMariadb
    见 nextpas.core.db.mysql.ffi。 *}
  TMysqlParamBind = record
    BufferType: Cardinal;    { enum_field_types 值 }
    Buffer: Pointer;
    BufferLength: QWord;     { 字符串/blob 缓冲容量 }
    IsNull: PBoolean;        { 指向 1 字节空值标志；nil=非 NULL 参数 }
    Length: PQWord;          { 实际字节数出参/入参 }
    IsUnsigned: Boolean;
  end;

  {** @desc MySQL error, carries the C-API diagnostic triple:
    number (CR_* 或 ER_*)、message、SQLSTATE（5 字符或空串）。 *}
  EMySqlError = class(ENextPasError)
  private
    FErrorCode: Integer;
    FSqlState: string;
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AMessage: string; ACode: Integer;
      const ASqlState: string = ''); overload;
    property ErrorCode: Integer read FErrorCode;
    property SqlState: string read FSqlState;
  end;

implementation

constructor EMySqlError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
  FErrorCode := 0;
  FSqlState := '';
end;

constructor EMySqlError.Create(const AMessage: string; ACode: Integer;
  const ASqlState: string);
begin
  inherited Create(AMessage);
  FErrorCode := ACode;
  FSqlState := ASqlState;
end;

end.
