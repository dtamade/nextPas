unit nextpas.core.db.dm.base;

{** @desc DM8 DPI L2 module: public constants and error types.
       Raw DPI C ABI lives in nextpas.core.db.dm.ffi (resolved at runtime
       via nextpas.core.db.dm.loader, dlopen on libdmdpi.so.*).
       Friendly surface (TDbDmConn / TDbDmQuery) lives in
       nextpas.core.db.dm.adapter and is re-exported by the factory.

       Error-code vocabulary mirrors DM8 DPI Programming Guide:
       negative integers (<0) are DM server codes, classification into
       TDbErrorCategory happens at adapter layer via ClassifyDm. *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

const
  { ===== shared-library candidates, probed in order =====
    DM8 ships libdmdpi.so (unversioned) + versioned .so.8; Windows dmdpi.dll.
    First open wins. }
  DM_LIBRARY_CANDIDATES: array[0..2] of string = (
    'libdmdpi.so',
    'libdmdpi.so.8',
    'libdodbc.so'
  );

const
  { ===== DM8 DPI error codes (subset fixed for classification) =====
    按手册 DM8_SQL-xxx 映射：约束/语法/连接/事务/容量五族。 }
  DM_ERR_DUP_KEY               = -1007;  { unique violation }
  DM_ERR_NOT_NULL              = -1048;  { Column 'x' cannot be null }
  DM_ERR_FK_VIOLATION          = -1216;  { foreign key }
  DM_ERR_FK_CHILD              = -1217;
  DM_ERR_CHECK_VIOLATION       = -3819;  { check constraint }
  DM_ERR_SYNTAX                = -2007;  { syntax error }
  DM_ERR_TABLE_NOT_EXIST       = -2106;  { table or view does not exist }
  DM_ERR_COLUMN_NOT_EXIST      = -2105;
  DM_ERR_DEADLOCK              = -1213;
  DM_ERR_LOCK_TIMEOUT          = -1205;
  DM_ERR_CONNECTION_LOST       = -2003;
  DM_ERR_AUTH_FAILED           = -11011;
  DM_ERR_OUT_OF_MEMORY         = -11007;
  DM_ERR_DISK_FULL             = -11012;
  DM_ERR_NOT_SUPPORTED         = -11000;
  DM_ERR_UNKNOWN               = -10999;

type
  { Opaque DPI handles }
  TDmEnv  = Pointer;
  TDmConn = Pointer;
  TDmStmt = Pointer;

  {** @desc DM error, carries DPI diagnostic triple. *}
  EDmError = class(ENextPasError)
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

constructor EDmError.Create(const AMessage: string);
begin
  inherited Create(AMessage);
  FErrorCode := 0;
  FSqlState := '';
end;

constructor EDmError.Create(const AMessage: string; ACode: Integer;
  const ASqlState: string);
begin
  inherited Create(AMessage);
  FErrorCode := ACode;
  FSqlState := ASqlState;
end;

end.
