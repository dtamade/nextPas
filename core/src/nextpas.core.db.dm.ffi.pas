unit nextpas.core.db.dm.ffi;

{** @desc Raw DM8 DPI C ABI as cdecl procedure types.
       Loaded at runtime by nextpas.core.db.dm.loader (dlopen across candidate
       list) — same rationale as mysql/pg loaders.

       Type mapping for LP64 Unix:
         C int / DINT            -> Integer
         C void* (handles)       -> Pointer (TDmEnv/TDmConn/TDmStmt)
         C char*                 -> PAnsiChar
         C unsigned long/long    -> QWord / Int64
         C bool returns          -> Integer (0=false) or Boolean per header
       DPI handles are opaque; adapter never touches struct fields. *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.db.dm.base;

type
  { ===== env lifecycle ===== }
  TDpiCreateEnv   = function(AEnv: PPointer): Integer; cdecl;
  TDpiFreeEnv     = function(AEnv: TDmEnv): Integer; cdecl;

  { ===== connection ===== }
  TDpiCreateConn  = function(AEnv: TDmEnv; AConn: PPointer): Integer; cdecl;
  TDpiFreeConn    = function(AConn: TDmConn): Integer; cdecl;
  TDpiConnect     = function(AConn: TDmConn; AConnStr: PAnsiChar): Integer; cdecl;
  TDpiDisconnect  = function(AConn: TDmConn): Integer; cdecl;
  TDpiCommit      = function(AConn: TDmConn): Integer; cdecl;
  TDpiRollback    = function(AConn: TDmConn): Integer; cdecl;

  { ===== statement ===== }
  TDpiCreateStmt  = function(AConn: TDmConn; AStmt: PPointer): Integer; cdecl;
  TDpiFreeStmt    = function(AStmt: TDmStmt): Integer; cdecl;
  TDpiPrepare     = function(AStmt: TDmStmt; ASql: PAnsiChar; ALen: Integer): Integer; cdecl;
  TDpiExecute     = function(AStmt: TDmStmt): Integer; cdecl;
  TDpiFetch       = function(AStmt: TDmStmt; AOri: Integer; AOff: Int64): Integer; cdecl;
  TDpiCloseCursor = function(AStmt: TDmStmt): Integer; cdecl;

  { ===== bind ===== }
  TDpiBindParam   = function(AStmt: TDmStmt; AIdx: Integer; AType: Integer; ABuf: Pointer; ALen: Integer; AIsNull: PInteger): Integer; cdecl;
  TDpiBindCol     = function(AStmt: TDmStmt; ACol: Integer; AType: Integer; ABuf: Pointer; ABufLen: Integer; ALen: PInteger): Integer; cdecl;

  { ===== describe / data ===== }
  TDpiGetData     = function(AStmt: TDmStmt; ACol: Integer; AType: Integer; ABuf: Pointer; ABufLen: Integer; ALen: PInteger): Integer; cdecl;
  TDpiRowCount    = function(AStmt: TDmStmt; ACount: PInt64): Integer; cdecl;
  TDpiColCount    = function(AStmt: TDmStmt; ACount: PInteger): Integer; cdecl;
  TDpiDescribeCol = function(AStmt: TDmStmt; ACol: Integer; AName: PAnsiChar; ANameLen: Integer; AType: PInteger; ALen: PInteger; APrec: PInteger; AScale: PInteger; ANullable: PInteger): Integer; cdecl;

  { ===== diagnostics ===== }
  TDpiGetError    = function(AHandle: Pointer; AHandleType: Integer; ACode: PInteger; AMsg: PAnsiChar; AMsgLen: Integer; ASqlState: PAnsiChar): Integer; cdecl;

  { ===== optional ===== }
  TDpiCancel      = function(AStmt: TDmStmt): Integer; cdecl;
  TDpiVersion     = function(AConn: TDmConn; ABuf: PAnsiChar; ABufLen: Integer): Integer; cdecl;

var
  dpi_create_env:   TDpiCreateEnv;
  dpi_free_env:     TDpiFreeEnv;
  dpi_create_conn:  TDpiCreateConn;
  dpi_free_conn:    TDpiFreeConn;
  dpi_connect:      TDpiConnect;
  dpi_disconnect:   TDpiDisconnect;
  dpi_commit:       TDpiCommit;
  dpi_rollback:     TDpiRollback;
  dpi_create_stmt:  TDpiCreateStmt;
  dpi_free_stmt:    TDpiFreeStmt;
  dpi_prepare:      TDpiPrepare;
  dpi_execute:      TDpiExecute;
  dpi_fetch:        TDpiFetch;
  dpi_close_cursor: TDpiCloseCursor;
  dpi_bind_param:   TDpiBindParam;
  dpi_bind_col:     TDpiBindCol;
  dpi_get_data:     TDpiGetData;
  dpi_row_count:    TDpiRowCount;
  dpi_col_count:    TDpiColCount;
  dpi_describe_col: TDpiDescribeCol;
  dpi_get_error:    TDpiGetError;
  dpi_cancel:       TDpiCancel;
  dpi_version:      TDpiVersion;

const
  DPI_SUCCESS        = 0;
  DPI_NO_DATA        = 100;
  DPI_HANDLE_ENV     = 1;
  DPI_HANDLE_DBC     = 2;
  DPI_HANDLE_STMT    = 3;

  { DM C types for bind }
  DPI_TYPE_CHAR      = 1;
  DPI_TYPE_VARCHAR   = 2;
  DPI_TYPE_INTEGER   = 3;
  DPI_TYPE_BIGINT    = 4;
  DPI_TYPE_DOUBLE    = 5;
  DPI_TYPE_BLOB      = 6;
  DPI_TYPE_CLOB      = 7;
  DPI_TYPE_DATE      = 8;
  DPI_TYPE_TIMESTAMP = 9;

implementation

end.
