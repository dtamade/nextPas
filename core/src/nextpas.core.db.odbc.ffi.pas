unit nextpas.core.db.odbc.ffi;

{** @desc Raw ODBC (ISO CLI) C ABI as cdecl procedure types. Loaded at
       runtime by nextpas.core.db.odbc.loader (dlopen across a candidate
       soname list) — same rationale as the pg/mysql loaders: build hosts
       ship versioned sonames only, and unixODBC/iODBC/Windows managers
       must resolve without relinking. Raw declarations only — no
       helpers, no marshaling.

       Type mapping for LP64 Unix (matches pg/mysql ffi conventions):
         SQLRETURN / SQLSMALLINT   -> SmallInt   (16-bit)
         SQLUSMALLINT              -> Word       (16-bit)
         SQLINTEGER                -> Integer    (32-bit)
         SQLHWND                   -> Pointer    (unused on Linux)
         SQLULEN / SQLLEN          -> QWord / Int64 (64-bit on LP64)
       All functions are cdecl on SysV; the Windows stdcall divergence is
       handled by the compiler's cdecl-on-win equivalence for these ABIs
       at the win64 lane (same approach as pg.ffi). W-functions are
       deliberately NOT bound: ANSI API + driver-side conversion only,
       avoids SQLWCHAR width divergence between unixODBC (4-byte) and
       Windows (2-byte) — documented in CONTRACT §2.7/adapter notes. *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.odbc.base;

type
  { ===== handle lifecycle ===== }
  TSqlAllocHandle = function(AHandleType: SmallInt; AInput: Pointer;
    out AOutput: Pointer): SmallInt; cdecl;
  TSqlFreeHandle = function(AHandleType: SmallInt;
    AHandle: Pointer): SmallInt; cdecl;

  { ===== attributes ===== }
  TSqlSetEnvAttr = function(AEnv: Pointer; AAttr: Integer;
    AValue: Pointer; ALen: Integer): SmallInt; cdecl;
  TSqlSetConnectAttr = function(ADbc: Pointer; AAttr: Integer;
    AValue: Pointer; ALen: Integer): SmallInt; cdecl;
  TSqlSetStmtAttr = function(AStmt: Pointer; AAttr: Integer;
    AValue: Pointer; ALen: Integer): SmallInt; cdecl;

  { ===== connection ===== }
  { DriverConnect：DSN/FileDSN/键值串直连（"DSN=x;UID=y;PWD=z"）。
    OutConnStr 缓冲由调用方提供，完整串长写回 AOutLen。 }
  TSqlDriverConnect = function(ADbc: Pointer; AWnd: Pointer;
    AConnStr: PAnsiChar; AConnStrLen: SmallInt;
    AOutConnStr: PAnsiChar; AOutBufLen: SmallInt;
    out AOutLen: SmallInt; ADriverCompletion: Word): SmallInt; cdecl;
  TSqlDisconnect = function(ADbc: Pointer): SmallInt; cdecl;

  { ===== transaction ===== }
  TSqlEndTran = function(AHandleType: SmallInt; AHandle: Pointer;
    ACompletion: SmallInt): SmallInt; cdecl;

  { ===== execution ===== }
  TSqlExecDirect = function(AStmt: Pointer; AText: PAnsiChar;
    ATextLen: Integer): SmallInt; cdecl;
  TSqlPrepare = function(AStmt: Pointer; AText: PAnsiChar;
    ATextLen: Integer): SmallInt; cdecl;
  TSqlExecute = function(AStmt: Pointer): SmallInt; cdecl;
  TSqlCloseCursor = function(AStmt: Pointer): SmallInt; cdecl;

  { ===== result metadata ===== }
  TSqlNumResultCols = function(AStmt: Pointer;
    out ACount: SmallInt): SmallInt; cdecl;
  { DescribeCol：列号 1 起；NameLen/Size/Digits/Nullable 均可 out }
  TSqlDescribeCol = function(AStmt: Pointer; AColNo: Word;
    AName: PAnsiChar; ANameBufLen: SmallInt; out ANameLen: SmallInt;
    out AType: SmallInt; out ASize: QWord; out ADigits: SmallInt;
    out ANullable: SmallInt): SmallInt; cdecl;
  TSqlRowCount = function(AStmt: Pointer; out ACount: Int64): SmallInt; cdecl;

  { ===== fetch ===== }
  TSqlFetch = function(AStmt: Pointer): SmallInt; cdecl;
  TSqlGetData = function(AStmt: Pointer; AColNo: Word;
    ATargetType: SmallInt; ABuf: Pointer; ABufLen: Int64;
    out AInd: Int64): SmallInt; cdecl;
  TSqlBindCol = function(AStmt: Pointer; AColNo: Word;
    ATargetType: SmallInt; ABuf: Pointer; ABufLen: Int64;
    AInd: Pointer): SmallInt; cdecl;

  { ===== parameters ===== }
  TSqlNumParams = function(AStmt: Pointer;
    out ACount: SmallInt): SmallInt; cdecl;
  { BindParameter：InputOutputType=SQL_PARAM_INPUT(1)；流式参数经
    SQL_LEN_DATA_AT_EXEC 由 A4 决定是否引入。 }
  TSqlBindParameter = function(AStmt: Pointer; AParamNo: Word;
    AInputOutputType: SmallInt; AValueType: SmallInt;
    AParamType: SmallInt; AColumnSize: QWord; ADigits: SmallInt;
    AValue: Pointer; ABufLen: Int64; AInd: Pointer): SmallInt; cdecl;

const
  SQL_PARAM_INPUT = 1;
  SQL_PARAM_OUTPUT = 4;
  SQL_PARAM_INPUT_OUTPUT = 2;

type
  { ===== capability probing ===== }
  { GetInfo：连接级能力/元信息查询（InfoType 值与结果词汇见 odbc.base）。
    数值型 InfoType 的结果直接写入 AInfoValue 缓冲（宽度依 InfoType，
    常见为 16/32 位整数）；字符串型经 AStrLen 回报实际长度。 }
  TSqlGetInfo = function(ADbc: Pointer; AInfoType: Word;
    AInfoValue: Pointer; ABufLen: SmallInt;
    out AStrLen: SmallInt): SmallInt; cdecl;

type
  { ===== diagnostics ===== }
  TSqlGetDiagRec = function(AHandleType: SmallInt; AHandle: Pointer;
    ARecNumber: SmallInt; ASqlState: PAnsiChar;
    out ANativeError: Integer; AMsg: PAnsiChar; AMsgBufLen: SmallInt;
    out AMsgLen: SmallInt): SmallInt; cdecl;

var
  sql_allocHandle:     TSqlAllocHandle;
  sql_freeHandle:      TSqlFreeHandle;
  sql_setEnvAttr:      TSqlSetEnvAttr;
  sql_setConnectAttr:  TSqlSetConnectAttr;
  sql_setStmtAttr:     TSqlSetStmtAttr;
  sql_driverConnect:   TSqlDriverConnect;
  sql_disconnect:      TSqlDisconnect;
  sql_endTran:         TSqlEndTran;
  sql_execDirect:      TSqlExecDirect;
  sql_prepare:         TSqlPrepare;
  sql_execute:         TSqlExecute;
  sql_closeCursor:     TSqlCloseCursor;
  sql_numResultCols:   TSqlNumResultCols;
  sql_describeCol:     TSqlDescribeCol;
  sql_rowCount:        TSqlRowCount;
  sql_fetch:           TSqlFetch;
  sql_getData:         TSqlGetData;
  sql_bindCol:         TSqlBindCol;
  sql_numParams:       TSqlNumParams;
  sql_bindParameter:   TSqlBindParameter;
  sql_getInfo:         TSqlGetInfo;
  sql_getDiagRec:      TSqlGetDiagRec;

implementation

end.
