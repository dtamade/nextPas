unit nextpas.core.db.sqlite.conn;

{** @desc SQLite L2 implementation: safe facade over nextpas.core.db.sqlite.ffi.
       - TSqliteDb: open/close, Exec (DDL/DML), prepared queries,
         last_insert_rowid / changes, busy timeout, WAL checkpoint.
       - TSqliteQuery: prepared statement lifecycle (step, bind, columns).
       - ESqliteError: carries the native SQLite result code and the
         extended result code (precise constraint kind for SQLITE_CONSTRAINT,
         e.g. SQLITE_CONSTRAINT_UNIQUE vs FOREIGNKEY — see sqlite.base).
       Text is UTF-8 (SQLite native). Connections opened with FULLMUTEX
       are safe for cross-thread use; write serialization stays at
       the caller (proxy888 db layer serializes writers). *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.sqlite.ffi;

type
  ESqliteError = class(ENextPasError)
  private
    FErrorCode: Integer;
    FExtendedErrorCode: Integer;
  public
    { 双参构造保留（extended := AErrorCode 兜底），三参构造带精确 extended code }
    constructor Create(const AErrorCode: Integer; const AMessage: string); overload;
    constructor Create(const AErrorCode: Integer; const AExtendedErrorCode: Integer;
      const AMessage: string); overload;
    property ErrorCode: Integer read FErrorCode;
    property ExtendedErrorCode: Integer read FExtendedErrorCode;
  end;

  TSqliteQuery = class
  private
    FStmt: TSqliteStmt;
    FDb: TSqliteHandle;
  public
    constructor Create(const ADb: TSqliteHandle; const ASql: string);
    destructor Destroy; override;

    procedure BindText(const AIndex: Integer; const AValue: string);
    procedure BindInt64(const AIndex: Integer; const AValue: Int64);
    procedure BindDouble(const AIndex: Integer; const AValue: Double);
    procedure BindBlob(const AIndex: Integer; const AValue: TBytes);
    procedure BindNull(const AIndex: Integer);
    function Step: Boolean;
    procedure Reset;
    { 清除全部绑定（语句复用前的干净状态保障） }
    procedure ClearBindings;
    function ColumnCount: Integer;
    function ColumnName(const AIndex: Integer): string;
    function ColumnType(const AIndex: Integer): Integer;
    { 声明亲和类型（静态）；-1 = 无声明（表达式/聚合） }
    function ColumnDeclaredType(const AIndex: Integer): Integer;
    { 原始声明类型文本（大写化；空串 = 无声明）。供 adapter 做亲和
      规则之外的子串判定（如 INC-6 的 BOOLEAN）。 }
    function ColumnDeclaredTypeName(const AIndex: Integer): string;
    function GetInt64(const AIndex: Integer): Int64;
    function GetDouble(const AIndex: Integer): Double;
    function GetText(const AIndex: Integer): string;
    function GetBlob(const AIndex: Integer): TBytes;
  end;

  TSqliteDb = class
  private
    FDb: TSqliteHandle;
    FPath: string;
    procedure CheckOk(const ARC: Integer);
  public
    constructor Create(const APath: string); overload;
    constructor Create(const APath: string; const AFlags: Integer); overload;
    destructor Destroy; override;

    procedure Exec(const ASql: string);
    function Query(const ASql: string): TSqliteQuery;
    function Changes: Integer;
    function LastInsertRowId: Int64;
    procedure BusyTimeout(const AMs: Integer);
    procedure Checkpoint;
    function Version: string;
    property Path: string read FPath;
    { 原生 sqlite3* 句柄——供 sqlite.ffi 直接调用（如事务助手判断 autocommit）。 }
    property Handle: TSqliteHandle read FDb;
  end;

{ Open or create a SQLite database file (''memory'' for in-memory). }
function SqliteOpen(const APath: string): TSqliteDb;

implementation

{ ===== helpers ===== }

procedure RaiseError(const ACode: Integer; const ADb: TSqliteHandle);
begin
  raise ESqliteError.Create(ACode, sqlite3_extended_errcode(ADb),
    string(AnsiString(sqlite3_errmsg(ADb))));
end;

{ ===== ESqliteError ===== }

constructor ESqliteError.Create(const AErrorCode: Integer; const AMessage: string);
begin
  Create(AErrorCode, AErrorCode, AMessage);
end;

constructor ESqliteError.Create(const AErrorCode: Integer;
  const AExtendedErrorCode: Integer; const AMessage: string);
begin
  inherited Create(AMessage);
  FErrorCode := AErrorCode;
  FExtendedErrorCode := AExtendedErrorCode;
end;

{ ===== TSqliteDb ===== }

constructor TSqliteDb.Create(const APath: string);
begin
  Create(APath, SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE or
    SQLITE_OPEN_FULLMUTEX);
end;

constructor TSqliteDb.Create(const APath: string; const AFlags: Integer);
var
  LRC: Integer;
begin
  inherited Create;
  FPath := APath;
  LRC := sqlite3_open_v2(PAnsiChar(AnsiString(APath)), FDb, AFlags, nil);
  if LRC <> SQLITE_OK then
    raise ESqliteError.Create(LRC, sqlite3_extended_errcode(FDb),
      string(AnsiString(sqlite3_errmsg(FDb))));
end;

destructor TSqliteDb.Destroy;
begin
  if FDb <> nil then
    sqlite3_close_v2(FDb);
  inherited;
end;

procedure TSqliteDb.CheckOk(const ARC: Integer);
begin
  if ARC <> SQLITE_OK then
    RaiseError(ARC, FDb);
end;

procedure TSqliteDb.Exec(const ASql: string);
var
  LErr: PAnsiChar;
  LRC: Integer;
begin
  LErr := nil;
  LRC := sqlite3_exec(FDb, PAnsiChar(AnsiString(ASql)), nil, nil, LErr);
  if LRC <> SQLITE_OK then
  begin
    if LErr <> nil then
    begin
      try
        raise ESqliteError.Create(LRC, sqlite3_extended_errcode(FDb),
          string(AnsiString(LErr)));
      finally
        sqlite3_free(LErr);
      end;
    end
    else
      RaiseError(LRC, FDb);
  end;
end;

function TSqliteDb.Query(const ASql: string): TSqliteQuery;
begin
  Result := TSqliteQuery.Create(FDb, ASql);
end;

function TSqliteDb.Changes: Integer;
begin
  Result := sqlite3_changes(FDb);
end;

function TSqliteDb.LastInsertRowId: Int64;
begin
  Result := sqlite3_last_insert_rowid(FDb);
end;

procedure TSqliteDb.BusyTimeout(const AMs: Integer);
begin
  CheckOk(sqlite3_busy_timeout(FDb, AMs));
end;

procedure TSqliteDb.Checkpoint;
begin
  CheckOk(sqlite3_wal_checkpoint(FDb, nil));
end;

function TSqliteDb.Version: string;
begin
  Result := string(AnsiString(sqlite3_libversion));
end;

function SqliteOpen(const APath: string): TSqliteDb;
begin
  Result := TSqliteDb.Create(APath);
end;

{ ===== TSqliteQuery ===== }

constructor TSqliteQuery.Create(const ADb: TSqliteHandle; const ASql: string);
var
  LRC: Integer;
  LTail: PAnsiChar;
begin
  inherited Create;
  FDb := ADb;
  LRC := sqlite3_prepare_v2(FDb, PAnsiChar(AnsiString(ASql)), -1, FStmt, @LTail);
  if LRC <> SQLITE_OK then
    RaiseError(LRC, FDb);
end;

destructor TSqliteQuery.Destroy;
begin
  if FStmt <> nil then
    sqlite3_finalize(FStmt);
  inherited;
end;

procedure TSqliteQuery.BindText(const AIndex: Integer; const AValue: string);
begin
  if sqlite3_bind_text(FStmt, AIndex, PAnsiChar(AnsiString(AValue)), -1,
    sqlite3_destructor_type(SQLITE_TRANSIENT)) <> SQLITE_OK then
    RaiseError(sqlite3_errcode(FDb), FDb);
end;

procedure TSqliteQuery.BindInt64(const AIndex: Integer; const AValue: Int64);
begin
  if sqlite3_bind_int64(FStmt, AIndex, AValue) <> SQLITE_OK then
    RaiseError(sqlite3_errcode(FDb), FDb);
end;

procedure TSqliteQuery.BindDouble(const AIndex: Integer; const AValue: Double);
begin
  if sqlite3_bind_double(FStmt, AIndex, AValue) <> SQLITE_OK then
    RaiseError(sqlite3_errcode(FDb), FDb);
end;

procedure TSqliteQuery.BindBlob(const AIndex: Integer; const AValue: TBytes);
var
  LP: Pointer;
  LL: Integer;
begin
  LP := nil;
  LL := Length(AValue);
  if LL > 0 then
    LP := @AValue[0];
  if sqlite3_bind_blob(FStmt, AIndex, LP, LL,
    sqlite3_destructor_type(SQLITE_TRANSIENT)) <> SQLITE_OK then
    RaiseError(sqlite3_errcode(FDb), FDb);
end;

procedure TSqliteQuery.BindNull(const AIndex: Integer);
begin
  if sqlite3_bind_null(FStmt, AIndex) <> SQLITE_OK then
    RaiseError(sqlite3_errcode(FDb), FDb);
end;

function TSqliteQuery.Step: Boolean;
var
  LRC: Integer;
begin
  Result := False;
  LRC := sqlite3_step(FStmt);
  case LRC of
    SQLITE_ROW: Result := True;
    SQLITE_DONE: Result := False;
  else
    RaiseError(LRC, FDb);
  end;
end;

procedure TSqliteQuery.Reset;
begin
  if sqlite3_reset(FStmt) <> SQLITE_OK then
    RaiseError(sqlite3_errcode(FDb), FDb);
end;

procedure TSqliteQuery.ClearBindings;
begin
  if sqlite3_clear_bindings(FStmt) <> SQLITE_OK then
    RaiseError(sqlite3_errcode(FDb), FDb);
end;

function TSqliteQuery.ColumnCount: Integer;
begin
  Result := sqlite3_column_count(FStmt);
end;

function TSqliteQuery.ColumnName(const AIndex: Integer): string;
begin
  Result := string(AnsiString(sqlite3_column_name(FStmt, AIndex)));
end;

{ ASCII 大写（避免为本文件引入 SysUtils 依赖） }
function UpCaseAscii(const ASrc: string): string;
var
  I: Integer;
begin
  Result := ASrc;
  for I := 1 to Length(Result) do
    if Result[I] in ['a'..'z'] then
      Dec(Result[I], 32);
end;

function TSqliteQuery.ColumnType(const AIndex: Integer): Integer;
begin
  Result := sqlite3_column_type(FStmt, AIndex);
end;

{ 声明亲和类型（静态，空结果集亦可读，对齐 pg 静态 OID 行为）。
  返回 -1 = 无声明（表达式/聚合），由调用方回落到行值类型。
  亲和子串规则依 sqlite3 文档（datatype3.html）。 }
function TSqliteQuery.ColumnDeclaredType(const AIndex: Integer): Integer;
var
  LDecl: PAnsiChar;
  LU: string;
begin
  Result := -1;
  LDecl := sqlite3_column_decltype(FStmt, AIndex);
  if LDecl = nil then
    Exit;
  LU := UpCaseAscii(string(AnsiString(LDecl)));
  if Pos('INT', LU) > 0 then
    Exit(SQLITE_INTEGER);
  if (Pos('CHAR', LU) > 0) or (Pos('CLOB', LU) > 0)
    or (Pos('TEXT', LU) > 0) then
    Exit(SQLITE_TEXT);
  if (LU = '') or (Pos('BLOB', LU) > 0) then
    Exit(SQLITE_BLOB);
  if (Pos('REAL', LU) > 0) or (Pos('FLOA', LU) > 0)
    or (Pos('DOUB', LU) > 0) then
    Exit(SQLITE_FLOAT);
end;

function TSqliteQuery.ColumnDeclaredTypeName(const AIndex: Integer): string;
var
  LDecl: PAnsiChar;
begin
  LDecl := sqlite3_column_decltype(FStmt, AIndex);
  if LDecl = nil then
    Exit('');
  Result := UpCaseAscii(string(AnsiString(LDecl)));
end;

function TSqliteQuery.GetInt64(const AIndex: Integer): Int64;
begin
  Result := sqlite3_column_int64(FStmt, AIndex);
end;

function TSqliteQuery.GetDouble(const AIndex: Integer): Double;
begin
  Result := sqlite3_column_double(FStmt, AIndex);
end;

function TSqliteQuery.GetText(const AIndex: Integer): string;
var
  LP: PAnsiChar;
  LL: Integer;
begin
  LP := sqlite3_column_text(FStmt, AIndex);
  LL := sqlite3_column_bytes(FStmt, AIndex);
  SetString(Result, LP, LL);
end;

function TSqliteQuery.GetBlob(const AIndex: Integer): TBytes;
var
  LP: Pointer;
  LL: Integer;
begin
  LP := sqlite3_column_blob(FStmt, AIndex);
  LL := sqlite3_column_bytes(FStmt, AIndex);
  Result := nil;
  SetLength(Result, LL);
  if LL > 0 then
    Move(LP^, Result[0], LL);
end;

end.