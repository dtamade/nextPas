unit nextpas.core.db.mysql.ffi;

{** @desc Raw MySQL/MariaDB client C ABI as cdecl procedure types.
       Loaded at runtime by nextpas.core.db.mysql.loader (dlopen across a
       candidate soname list) — same rationale as the pg loader: build
       hosts ship versioned sonames only, and both library flavors must
       resolve without relinking. Raw declarations only — no helpers.

       Type mapping for LP64 Unix (matches pg.ffi conventions):
         C int / unsigned int      -> Integer / Cardinal
         C unsigned long           -> QWord   (mysql lengths, versions)
         C my_ulonglong            -> QWord   (TMysqlUll)
         C bool / my_bool returns  -> Boolean (1 byte, ABI reads AL)
         MYSQL_BIND arrays are passed as Pointer: the two flavors lay the
         struct out differently (see TMysqlBindMysql/TMysqlBindMariadb);
         the conn layer marshals from canonical TMysqlParamBind records,
         keeping the divergence isolated to one place. *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.mysql.base;

type
  PMysqlFieldRec = ^TMysqlFieldRec;

  { ===== library / thread lifecycle ===== }
  TMysqlLibraryInit = function(AArgc: Integer; AArgv: PPAnsiChar;
    AGroups: PPAnsiChar): Integer; cdecl;
  TMysqlLibraryEnd  = procedure; cdecl;

  { ===== version probes ===== }
  TMysqlGetClientVersion = function: QWord; cdecl;
  TMysqlGetServerVersion = function(AConn: TMysql): QWord; cdecl;

  { ===== connection ===== }
  TMysqlInit        = function(AArg: Pointer): TMysql; cdecl;  { mysql_init(NULL) }
  TMysqlOptions     = function(AConn: TMysql; AOption: Integer;
    AArg: Pointer): Integer; cdecl;  { 头文件为 varargs，ABI 等价三参 }
  TMysqlRealConnect = function(AConn: TMysql; AHost, AUser, APasswd,
    ADb: PAnsiChar; APort: Cardinal; ASocket: PAnsiChar;
    AClientFlag: QWord): TMysql; cdecl;
  TMysqlClose       = procedure(AConn: TMysql); cdecl;
  TMysqlPing        = function(AConn: TMysql): Integer; cdecl;
  TMysqlSelectDb    = function(AConn: TMysql; ADb: PAnsiChar): Integer; cdecl;
  TMysqlSetCharacterSet = function(AConn: TMysql;
    ACsName: PAnsiChar): Integer; cdecl;
  TMysqlAutocommit  = function(AConn: TMysql; AMode: Boolean): Boolean; cdecl;
  TMysqlCommit      = function(AConn: TMysql): Boolean; cdecl;
  TMysqlRollback    = function(AConn: TMysql): Boolean; cdecl;

  { ===== diagnostics ===== }
  TMysqlErrno    = function(AConn: TMysql): Cardinal; cdecl;
  TMysqlError_   = function(AConn: TMysql): PAnsiChar; cdecl;  { mysql_error }
  TMysqlSqlstate = function(AConn: TMysql): PAnsiChar; cdecl;

  { ===== text protocol ===== }
  TMysqlRealQuery     = function(AConn: TMysql; const AStmt: PAnsiChar;
    ALength: QWord): Integer; cdecl;
  TMysqlFieldCount    = function(AConn: TMysql): Cardinal; cdecl;
  TMysqlStoreResult   = function(AConn: TMysql): TMysqlRes; cdecl;
  TMysqlUseResult     = function(AConn: TMysql): TMysqlRes; cdecl;
  TMysqlFreeResult    = procedure(ARes: TMysqlRes); cdecl;
  TMysqlNumRows       = function(ARes: TMysqlRes): TMysqlUll; cdecl;
  TMysqlNumFields     = function(ARes: TMysqlRes): Cardinal; cdecl;
  TMysqlFetchRow      = function(ARes: TMysqlRes): TMysqlRow; cdecl;
  TMysqlFetchLengths  = function(ARes: TMysqlRes): PQWord; cdecl;
  TMysqlFetchField    = function(ARes: TMysqlRes): PMysqlFieldRec; cdecl;
  TMysqlFetchFieldDirect = function(ARes: TMysqlRes;
    AIdx: Cardinal): PMysqlFieldRec; cdecl;
  TMysqlNextResult    = function(AConn: TMysql): Integer; cdecl;
  TMysqlMoreResults   = function(AConn: TMysql): Boolean; cdecl;
  TMysqlAffectedRows  = function(AConn: TMysql): TMysqlUll; cdecl;
  TMysqlInsertId      = function(AConn: TMysql): TMysqlUll; cdecl;
  TMysqlWarningCount  = function(AConn: TMysql): Cardinal; cdecl;
  TMysqlRealEscapeStringQuote = function(AConn: TMysql; ATo, AFrom: PAnsiChar;
    ALength: QWord; AQuote: AnsiChar): QWord; cdecl;
  { 3 参旧版：MariaDB Connector/C 只导出此符号；Oracle ≥5.7.6 两者都有。
    连接层优先 _quote，缺席时降级（ABI 不同，必须分开声明）。 }
  TMysqlRealEscapeString = function(AConn: TMysql; ATo, AFrom: PAnsiChar;
    ALength: QWord): QWord; cdecl;

  { ===== prepared statement lifecycle（签名不涉 MYSQL_BIND 的面） ===== }
  TMysqlStmtInit          = function(AConn: TMysql): TMysqlStmt; cdecl;
  TMysqlStmtPrepare       = function(AStmt: TMysqlStmt; const AQuery: PAnsiChar;
    ALength: QWord): Integer; cdecl;
  TMysqlStmtParamCount    = function(AStmt: TMysqlStmt): QWord; cdecl;
  TMysqlStmtFieldCount    = function(AStmt: TMysqlStmt): Cardinal; cdecl;
  TMysqlStmtExecute       = function(AStmt: TMysqlStmt): Integer; cdecl;
  TMysqlStmtFetch         = function(AStmt: TMysqlStmt): Integer; cdecl;
  { 截断重取：按列从服务端取全量到指定 BIND 槽 }
  TMysqlStmtFetchColumn   = function(AStmt: TMysqlStmt; ABinds: Pointer;
    AColumn: Cardinal; AOffset: QWord): Boolean; cdecl;
  TMysqlStmtStoreResult   = function(AStmt: TMysqlStmt): Integer; cdecl;
  TMysqlStmtFreeResult    = function(AStmt: TMysqlStmt): Boolean; cdecl;
  TMysqlStmtClose         = function(AStmt: TMysqlStmt): Boolean; cdecl;
  TMysqlStmtReset         = function(AStmt: TMysqlStmt): Boolean; cdecl;
  TMysqlStmtResultMetadata = function(AStmt: TMysqlStmt): TMysqlRes; cdecl;
  TMysqlStmtAffectedRows  = function(AStmt: TMysqlStmt): TMysqlUll; cdecl;
  TMysqlStmtInsertId      = function(AStmt: TMysqlStmt): TMysqlUll; cdecl;
  TMysqlStmtNumRows       = function(AStmt: TMysqlStmt): TMysqlUll; cdecl;
  TMysqlStmtErrno         = function(AStmt: TMysqlStmt): Cardinal; cdecl;
  TMysqlStmtError         = function(AStmt: TMysqlStmt): PAnsiChar; cdecl;
  TMysqlStmtSqlstate      = function(AStmt: TMysqlStmt): PAnsiChar; cdecl;
  TMysqlStmtSendLongData  = function(AStmt: TMysqlStmt; AParamNr: Cardinal;
    const AData: PAnsiChar; ALength: QWord): Boolean; cdecl;
  TMysqlStmtNextResult    = function(AStmt: TMysqlStmt): Integer; cdecl;
  { 绑定两入口收 Pointer：原生布局按 flavor 由连接层编组（见单元头注） }
  TMysqlStmtBindParam     = function(AStmt: TMysqlStmt;
    ABinds: Pointer): Boolean; cdecl;
  TMysqlStmtBindResult    = function(AStmt: TMysqlStmt;
    ABinds: Pointer): Boolean; cdecl;

var
  { Bound by nextpas.core.db.mysql.loader; callers must MySqlEnsureLoaded
    first. Never call while nil. }
  my_library_init:  TMysqlLibraryInit;
  my_library_end:   TMysqlLibraryEnd;
  my_getClientVersion: TMysqlGetClientVersion;
  my_getServerVersion: TMysqlGetServerVersion;
  my_init:          TMysqlInit;
  my_options:       TMysqlOptions;
  my_realConnect:   TMysqlRealConnect;
  my_close:         TMysqlClose;
  my_ping:          TMysqlPing;
  my_selectDb:      TMysqlSelectDb;
  my_setCharacterSet: TMysqlSetCharacterSet;
  my_autocommit:    TMysqlAutocommit;
  my_commit:        TMysqlCommit;
  my_rollback:      TMysqlRollback;
  my_errno:         TMysqlErrno;
  my_error:         TMysqlError_;
  my_sqlstate:      TMysqlSqlstate;
  my_realQuery:     TMysqlRealQuery;
  my_fieldCount:    TMysqlFieldCount;
  my_storeResult:   TMysqlStoreResult;
  my_useResult:     TMysqlUseResult;
  my_freeResult:    TMysqlFreeResult;
  my_numRows:       TMysqlNumRows;
  my_numFields:     TMysqlNumFields;
  my_fetchRow:      TMysqlFetchRow;
  my_fetchLengths:  TMysqlFetchLengths;
  my_fetchField:    TMysqlFetchField;
  my_fetchFieldDirect: TMysqlFetchFieldDirect;
  my_nextResult:    TMysqlNextResult;
  my_moreResults:   TMysqlMoreResults;
  my_affectedRows:  TMysqlAffectedRows;
  my_insertId:      TMysqlInsertId;
  my_warningCount:  TMysqlWarningCount;
  { my_realEscapeStringQuote 可为 nil（MariaDB 只导出 3 参旧版），
    连接层须先判 Assigned 再调用。 }
  my_realEscapeStringQuote: TMysqlRealEscapeStringQuote;
  my_realEscapeString: TMysqlRealEscapeString;
  my_stmtInit:      TMysqlStmtInit;
  my_stmtPrepare:   TMysqlStmtPrepare;
  my_stmtParamCount: TMysqlStmtParamCount;
  my_stmtFieldCount: TMysqlStmtFieldCount;
  my_stmtExecute:   TMysqlStmtExecute;
  my_stmtFetch:     TMysqlStmtFetch;
  my_stmtFetchColumn: TMysqlStmtFetchColumn;
  my_stmtStoreResult: TMysqlStmtStoreResult;
  my_stmtFreeResult: TMysqlStmtFreeResult;
  my_stmtClose:     TMysqlStmtClose;
  my_stmtReset:     TMysqlStmtReset;
  my_stmtResultMetadata: TMysqlStmtResultMetadata;
  my_stmtAffectedRows: TMysqlStmtAffectedRows;
  my_stmtInsertId:  TMysqlStmtInsertId;
  my_stmtNumRows:   TMysqlStmtNumRows;
  my_stmtErrno:     TMysqlStmtErrno;
  my_stmtError:     TMysqlStmtError;
  my_stmtSqlstate:  TMysqlStmtSqlstate;
  my_stmtSendLongData: TMysqlStmtSendLongData;
  my_stmtNextResult: TMysqlStmtNextResult;
  my_stmtBindParam: TMysqlStmtBindParam;
  my_stmtBindResult: TMysqlStmtBindResult;

const
  { 双方言 MYSQL_BIND 原生镜像尺寸（LP64）。声明见下；门禁用 sizeof
    钉死防漂移。MariaDB 3.3 实测 sizeof=112（见本机 usr/include/mariadb/mariadb_stmt.h
    的 st_mysql_bind），Oracle 侧按 8.x 公开头文件记录 72。 }
  SIZE_MYSQL_BIND_MYSQL   = 72;
  SIZE_MYSQL_BIND_MARIADB = 112;

  { 双方言偏移常量（与下方记录注释一一对应，adapter 单点复用，防魔数漂移） }
  MYSQL_BIND_MYSQL_OFF_LENGTH       = 0;
  MYSQL_BIND_MYSQL_OFF_IS_NULL      = 8;
  MYSQL_BIND_MYSQL_OFF_BUFFER       = 16;
  MYSQL_BIND_MYSQL_OFF_ERROR        = 24;
  MYSQL_BIND_MYSQL_OFF_BUFFERLENGTH = 40;
  MYSQL_BIND_MYSQL_OFF_BUFFERTYPE   = 68;
  MYSQL_BIND_MYSQL_OFF_IS_UNSIGNED  = 70;

  MYSQL_BIND_MARIADB_OFF_LENGTH       = 0;
  MYSQL_BIND_MARIADB_OFF_IS_NULL      = 8;
  MYSQL_BIND_MARIADB_OFF_BUFFER       = 16;
  MYSQL_BIND_MARIADB_OFF_ERROR        = 24;
  MYSQL_BIND_MARIADB_OFF_BUFFERLENGTH = 64;
  MYSQL_BIND_MARIADB_OFF_BUFFERTYPE   = 96;
  MYSQL_BIND_MARIADB_OFF_IS_UNSIGNED  = 101;

type
  { Oracle libmysqlclient 8.x st_mysql_bind 镜像。
    偏移: length 0 / is_null 8 / buffer 16 / error 24 / extension 32 /
    buffer_length 40 / offset 48 / length_value 56 / flags 64 /
    buffer_type 68(1 字节) / error_value 69 / is_unsigned 70 /
    long_data_used 71。 }
  TMysqlBindMysql = record
    Length_: PQWord;          { 0  }
    IsNull: PBoolean;         { 8  }
    Buffer: Pointer;          { 16 }
    Error: Pointer;           { 24 }
    Extension: Pointer;       { 32 }
    BufferLength: QWord;      { 40 }
    Offset: QWord;            { 48 }
    LengthValue: QWord;       { 56 }
    Flags: Cardinal;          { 64 }
    BufferType: Byte;         { 68 — 注意宽度 1 字节 }
    ErrorValue: Byte;         { 69 }
    IsUnsignedByte: Byte;     { 70 }
    LongDataUsed: Byte;       { 71 }
  end;                        { sizeof = 72 }

  { MariaDB Connector/C 3.3 st_mysql_bind（112 字节，LP64）。
    实测偏移（usr/include/mariadb/mariadb_stmt.h）:
    length 0 / is_null 8 / buffer 16 / error 24 /
    row_ptr 32 / store_param_func 40 / fetch_result 48 / skip_result 56 /
    buffer_length 64 / offset 72 / length_value 80 / flags 88 /
    pack_length 92 / buffer_type 96(4 字节) / error_value 100 /
    is_unsigned 101 / long_data_used 102 / is_null_value 103 /
    extension 104。 }
  TMysqlBindMariadb = record
    Length_: PQWord;          { 0  }
    IsNull: PBoolean;         { 8  }
    Buffer: Pointer;          { 16 }
    Error: Pointer;           { 24 }
    RowPtr: Pointer;          { 32 }
    StoreParamF: Pointer;     { 40 }
    FetchResultF: Pointer;    { 48 }
    SkipResultF: Pointer;     { 56 }
    BufferLength: QWord;      { 64 }
    Offset: QWord;            { 72 }
    LengthValue: QWord;       { 80 }
    Flags: Cardinal;          { 88 }
    PackLength: Cardinal;     { 92 }
    BufferType: Cardinal;     { 96 — 4 字节 enum }
    ErrorValue: Byte;         { 100 }
    IsUnsignedByte: Byte;     { 101 }
    LongDataUsed: Byte;       { 102 }
    IsNullValue: Byte;        { 103 }
    Extension: Pointer;       { 104 }
  end;                        { sizeof = 112 }

implementation

end.
