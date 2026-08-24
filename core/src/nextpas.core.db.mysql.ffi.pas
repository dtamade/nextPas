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
    钉死防漂移。MariaDB 侧尺寸可在本机对真实头文件复核；Oracle 侧
    按 8.x 公开头文件记录。 }
  SIZE_MYSQL_BIND_MYSQL   = 72;
  SIZE_MYSQL_BIND_MARIADB = 120;

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

  { MariaDB Connector/C 3.x st_mysql_bind 镜像。
    偏移: length 0 / is_null 8 / buffer 16 / error 24 / row_ptr 32 /
    store_param_f 40 / fetch_result 48 / fetch_value 56 / extension 64 /
    buffer_length 72 / offset 80 / length_value 88 / flags 96 /
    buffer_type 100(4 字节 enum) / error_value 104 / is_unsigned 105 /
    long_data_used 106 / is_null_value 107 / extension2 112。
    函数指针成员由驱动在 bind 时自填，调用方保持零值即可。 }
  TMysqlBindMariadb = record
    Length_: PQWord;          { 0  }
    IsNull: PBoolean;         { 8  }
    Buffer: Pointer;          { 16 }
    Error: Pointer;           { 24 }
    RowPtr: Pointer;          { 32 }
    StoreParamF: Pointer;     { 40 }
    FetchResultF: Pointer;    { 48 }
    FetchValueF: Pointer;     { 56 }
    Extension: Pointer;       { 64 }
    BufferLength: QWord;      { 72 }
    Offset: QWord;            { 80 }
    LengthValue: QWord;       { 88 }
    Flags: Cardinal;          { 96 }
    BufferType: Cardinal;     { 100 — 注意宽度 4 字节、位置与 Oracle 不同 }
    ErrorValue: Byte;         { 104 }
    IsUnsignedByte: Byte;     { 105 }
    LongDataUsed: Byte;       { 106 }
    IsNullValue: Byte;        { 107 }
    Extension2: Pointer;      { 112 }
  end;                        { sizeof = 120 }

implementation

end.
