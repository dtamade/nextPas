unit nextpas.core.db.dm.adapter;

{** @desc IDbConnection 的达梦 DM8 DPI 适配器（原生 DPI 类表面统一错误/事务簿记）。
       能力与契约见 CONTRACT §2.21，事务/池语义同 sqlite/pg 家族。
       依赖收敛：占位符扫描复用 db.sqlscan，DSN 解析复用 text.kv，池/追踪/重试复用既有抽象。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.capprobe;

function ConnectDm(const ADsn: string): IDbConnection; overload;
function ConnectDm(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection; overload;
function ConnectDm(const ADsn: string; const AOptions: TDbConnectOptions; const AStmtCacheCapacity: Integer): IDbConnection; overload;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.text.kv,
  nextpas.core.db.sqlscan,
  nextpas.core.db.bulk,
  nextpas.core.db.err,
  nextpas.core.db.trace,
  nextpas.core.db.dm.base,
  nextpas.core.db.dm.ffi,
  nextpas.core.db.dm.loader,
  nextpas.core.collections.lrucache.intf,
  nextpas.core.collections.lrucache,
  nextpas.core.sync,
  nextpas.core.text.builder;

const
  DBSQLSCAN_DM: TDbSqlScanDialect = (DoubleQuoteIdents: True; BacktickIdents: False; BracketIdents: False; HashComments: False);

procedure RaiseDmAsDb(const AE: EDmError);
var
  LCategory: TDbErrorCategory;
  LConstraint: TDbConstraintKind;
begin
  ClassifyDm(AE.ErrorCode, AE.SqlState, LCategory, LConstraint);
  raise EDbError.CreateFullDm(AE.ErrorCode, AE.SqlState, AE.Message, LCategory, LConstraint);
end;

function TranslatePlaceholders(const ASql: string): string;
begin
  Result := SqlScanRenderDollar(ASql, DBSQLSCAN_DM);
  // DM DPI 同 pg 使用 $N 形态（若驱动接受 ? 则保持原文亦可，翻译为 $N 兼容性更宽）
end;

type
  IDmStmtHolder = interface
    ['{E2F3A9C4-8B11-4D2E-9F7C-1A2B3C4D5E6F}']
    function Detach: TDmStmt;
  end;

  TDmStmtHolder = class(TInterfacedObject, IDmStmtHolder)
  private
    FStmt: TDmStmt;
  public
    constructor Create(AStmt: TDmStmt);
    destructor Destroy; override;
    function Detach: TDmStmt;
  end;

  IDmStmtHome = interface
    ['{F3A4B5C6-9C22-4E3F-8A7D-2B3C4D5E6F70}']
    procedure ReturnStmt(const ASql: string; AStmt: TDmStmt);
  end;

  IDmStmtCache = specialize ILruCache<string, IDmStmtHolder>;

  TDbDmQuery = class(TInterfacedObject, IDbQuery)
  private
    FConn: TDmConn;
    FEnv: TDmEnv;
    FStmt: TDmStmt;
    FSql: string;
    FHome: IDmStmtHome;
    FTrace: TDbTraceHub;
    FEmitted: Boolean;
    FColCount: Integer;
    FHasRow: Boolean;
    FParams: array of string;
    FParamIsNull: array of Boolean;
    FParamAnsi: array of AnsiString;   { stable buffers for DPI bind (no dangling PAnsiChar) }
    FIsNullInt: array of Integer;      { DPI expects PInteger 0/1, stable storage }
    FRows: array of array of string;
    FRowIdx: Integer;
    procedure EnsureStmt;
    procedure DoBind;
  public
    constructor Create(AEnv: TDmEnv; AConn: TDmConn; const ASql: string; ATrace: TDbTraceHub); overload;
    constructor Create(AEnv: TDmEnv; AConn: TDmConn; const ASql: string; ATrace: TDbTraceHub; const AHome: IDmStmtHome; AStmt: TDmStmt); overload;
    destructor Destroy; override;
    procedure BindText(AIndex: Integer; const AValue: string);
    procedure BindInt64(AIndex: Integer; const AValue: Int64);
    procedure BindDouble(AIndex: Integer; const AValue: Double);
    procedure BindBlob(AIndex: Integer; const AValue: TBytes);
    procedure BindNull(AIndex: Integer);
    function Step: Boolean;
    procedure Reset;
    function ColumnCount: Integer;
    function ColumnName(AIndex: Integer): string;
    function ColumnType(AIndex: Integer): TDbColumnType;
    function IsNull(AIndex: Integer): Boolean;
    function GetInt64(AIndex: Integer): Int64;
    function GetDouble(AIndex: Integer): Double;
    function GetText(AIndex: Integer): string;
    function GetBlob(AIndex: Integer): TBytes;
  end;

  TDbDmConnection = class(TInterfacedObject, IDbConnection, IDbTxControl, IDbSavepointControl, IDbBatchExecutor, IDbCapabilities, IDbTraceControl, IDbCancelControl, IDbBulkCopy, IDbStmtCacheControl, IDmStmtHome)
  private
    FEnv: TDmEnv;
    FConn: TDmConn;
    FLock: INativeMutex;
    FDepth: Integer;
    FTrace: TDbTraceHub;
    FChanges: Int64;
    FServerVersion: Integer;
    FServerVersionProbed: Boolean;
    FBulk: TDbBulkBuffer;
    FCache: IDmStmtCache;
    procedure DmExec(const ASql: string);
    procedure BulkExec(const ASql: string);
    procedure EnsureConnected;
  public
    constructor Create(AEnv: TDmEnv; AConn: TDmConn; const AStmtCacheCapacity: Integer = DEFAULT_DM_STMT_CACHE_CAPACITY);
    destructor Destroy; override;
    { IDbTraceControl }
    procedure SetListener(const AListener: IDbTraceListener);
    function HasListener: Boolean;
    function Kind: TDbKind;
    procedure Exec(const ASql: string); overload;
    procedure Exec(const ASql: string; const AOptions: TDbExecOptions); overload;
    function Query(const ASql: string): IDbQuery; overload;
    function Query(const ASql: string; const AOptions: TDbExecOptions): IDbQuery; overload;
    function Changes: Int64;
    function Raw: Pointer;
    { IDbTxControl }
    procedure BeginTxn(const AImmediate: Boolean = False);
    procedure CommitTxn;
    procedure RollbackTxn;
    function InTransaction: Boolean;
    function TxDepth: Integer;
    { IDbSavepointControl }
    procedure Savepoint(const AName: string);
    procedure RollbackTo(const AName: string);
    procedure ReleaseTo(const AName: string);
    { IDbBatchExecutor }
    procedure ExecuteBatch(const ASteps: TDbSqlSteps);
    { IDbCapabilities }
    function ProductName: string;
    function ProductVersion: string;
    function SupportsSavepoints: Boolean;
    function SupportsBatchExecutor: Boolean;
    function SupportsStmtCacheControl: Boolean;
    function SupportsLargeObjects: Boolean;
    function SupportsArrayBinding: Boolean;
    function SupportsNativeBool: Boolean;
    function SupportsMultiStatementExec: Boolean;
    function SupportsStatementTimeout: Boolean;
    function CaseSensitiveIdentifiers: Boolean;
    function MaxPlaceholders: Integer;
    function ServerVersion: Integer;
    function SupportsNativeVector: Boolean;
    function SupportsJsonPath: Boolean;
    function SupportsRangeTypes: Boolean;
    function SupportsBulkCopy: Boolean;
    { IDbBulkCopy V4.3: 单事务批量行复制（复用 Exec 批，V4.3 universal true） }
    procedure BeginCopy(const ATable: string; const AColumns: array of string);
    procedure WriteRow(const AValues: array of string);
    procedure EndCopy;
    procedure AbortCopy;
    { IDbStmtCacheControl }
    procedure Clear;
    function Size: Integer;
    function HitRate: Double;
    { IDmStmtHome }
    procedure ReturnStmt(const ASql: string; AStmt: TDmStmt);
    { IDbCancelControl }
    function ArmCancel: Boolean;
    procedure DisarmCancel;
    procedure RequestCancel;
  end;

function ValidateDmDsn(const ADsn: string): string;
var
  LErr: string;
begin
  if ADsn = '' then
    raise EDbError.CreateSimple(dbkDm, 'DM DSN empty');
  if not ValidateKV(ADsn, LErr) then
    raise EDbError.CreateSimple(dbkDm, 'DM DSN malformed: ' + LErr);
  Result := ADsn;
end;

function DsnToDpiConnStr(const ADsn: string): AnsiString;
begin
  Result := AnsiString(ADsn);
end;

procedure CheckDpi(const ACode: Integer; AHandle: Pointer; AHandleType: Integer);
var
  LCode: Integer;
  LMsg: array[0..1023] of AnsiChar;
  LState: array[0..15] of AnsiChar;
begin
  if ACode = DPI_SUCCESS then Exit;
  if ACode = DPI_NO_DATA then Exit;
  LCode := ACode;
  LMsg[0] := #0; LState[0] := #0;
  if Assigned(dpi_get_error) then
    dpi_get_error(AHandle, AHandleType, @LCode, @LMsg[0], SizeOf(LMsg), @LState[0]);
  raise EDmError.Create(AnsiPtrToStr(@LMsg[0]), LCode, AnsiPtrToStr(@LState[0]));
end;

{ ---- TDmStmtHolder ---- }

constructor TDmStmtHolder.Create(AStmt: TDmStmt);
begin
  inherited Create;
  FStmt := AStmt;
end;

destructor TDmStmtHolder.Destroy;
begin
  if FStmt <> nil then
  begin
    dpi_free_stmt(FStmt);
    FStmt := nil;
  end;
  inherited Destroy;
end;

function TDmStmtHolder.Detach: TDmStmt;
begin
  Result := FStmt;
  FStmt := nil;
end;

constructor TDbDmQuery.Create(AEnv: TDmEnv; AConn: TDmConn; const ASql: string; ATrace: TDbTraceHub);
begin
  Create(AEnv, AConn, ASql, ATrace, nil, nil);
end;

constructor TDbDmQuery.Create(AEnv: TDmEnv; AConn: TDmConn; const ASql: string; ATrace: TDbTraceHub; const AHome: IDmStmtHome; AStmt: TDmStmt);
begin
  inherited Create;
  FEnv := AEnv; FConn := AConn; FSql := ASql; FTrace := ATrace; FHome := AHome;
  FStmt := AStmt; FColCount := 0; FHasRow := False; FRowIdx := -1;
  SetLength(FParams, 8); SetLength(FParamIsNull, 8);
  SetLength(FParamAnsi, 8); SetLength(FIsNullInt, 8);
end;

destructor TDbDmQuery.Destroy;
begin
  if FStmt <> nil then
  begin
    if FHome <> nil then
    begin
      FHome.ReturnStmt(FSql, FStmt);
      FStmt := nil;
    end
    else
    begin
      dpi_free_stmt(FStmt); FStmt := nil;
    end;
  end;
  FHome := nil;
  inherited Destroy;
end;

procedure TDbDmQuery.EnsureStmt;
var
  LSql: AnsiString;
  LCode: Integer;
begin
  if FStmt <> nil then Exit;
  LCode := dpi_create_stmt(FConn, @FStmt);
  CheckDpi(LCode, FConn, DPI_HANDLE_DBC);
  LSql := AnsiString(TranslatePlaceholders(FSql));
  LCode := dpi_prepare(FStmt, PAnsiChar(LSql), Length(LSql));
  if LCode <> DPI_SUCCESS then
  begin
    CheckDpi(LCode, FStmt, DPI_HANDLE_STMT);
  end;
end;

procedure TDbDmQuery.DoBind;
var
  I: Integer;
begin
  { ensure stable storage sized }
  if Length(FParamAnsi) < Length(FParams) then
  begin
    SetLength(FParamAnsi, Length(FParams));
    SetLength(FIsNullInt, Length(FParams));
  end;
  for I := 0 to High(FParams) do
  begin
    if FParamIsNull[I] then
    begin
      FIsNullInt[I] := 1;
      FParamAnsi[I] := '';
      dpi_bind_param(FStmt, I+1, DPI_TYPE_VARCHAR, nil, 0, @FIsNullInt[I]);
    end else
    begin
      FIsNullInt[I] := 0;
      FParamAnsi[I] := AnsiString(FParams[I]);
      if FParamAnsi[I] <> '' then
        dpi_bind_param(FStmt, I+1, DPI_TYPE_VARCHAR, PAnsiChar(FParamAnsi[I]), Length(FParamAnsi[I]), @FIsNullInt[I])
      else
        dpi_bind_param(FStmt, I+1, DPI_TYPE_VARCHAR, PAnsiChar(''), 0, @FIsNullInt[I]);
    end;
  end;
end;

procedure TDbDmQuery.BindText(AIndex: Integer; const AValue: string);
begin
  if (AIndex < 1) then raise EDbError.CreateSimple(dbkDm, 'bind index out of range');
  if Length(FParams) < AIndex then
  begin
    SetLength(FParams, AIndex);
    SetLength(FParamIsNull, AIndex);
    SetLength(FParamAnsi, AIndex);
    SetLength(FIsNullInt, AIndex);
  end;
  FParams[AIndex-1] := AValue; FParamIsNull[AIndex-1] := False;
end;

procedure TDbDmQuery.BindInt64(AIndex: Integer; const AValue: Int64);
begin
  BindText(AIndex, IntToStr(AValue));
end;

procedure TDbDmQuery.BindDouble(AIndex: Integer; const AValue: Double);
begin
  BindText(AIndex, FloatToStr(AValue));
end;

procedure TDbDmQuery.BindBlob(AIndex: Integer; const AValue: TBytes);
var
  S: string; I: Integer;
begin
  S := ''; SetLength(S, Length(AValue));
  for I := 0 to High(AValue) do S[I+1] := Chr(AValue[I]);
  BindText(AIndex, S);
end;

procedure TDbDmQuery.BindNull(AIndex: Integer);
begin
  if (AIndex < 1) then raise EDbError.CreateSimple(dbkDm, 'bind index out of range');
  if Length(FParams) < AIndex then
  begin
    SetLength(FParams, AIndex);
    SetLength(FParamIsNull, AIndex);
    SetLength(FParamAnsi, AIndex);
    SetLength(FIsNullInt, AIndex);
  end;
  FParamIsNull[AIndex-1] := True;
end;

function TDbDmQuery.Step: Boolean;
var
  LT0: QWord; LTimed: Boolean; LCode: Integer;
  LCat: TDbErrorCategory; LCon: TDbConstraintKind;
begin
  LT0 := 0; LTimed := (FTrace <> nil) and (not FEmitted) and FTrace.BeginOp(LT0);
  try
    EnsureStmt;
    DoBind;
    LCode := dpi_execute(FStmt);
    if LCode <> DPI_SUCCESS then CheckDpi(LCode, FStmt, DPI_HANDLE_STMT);
    LCode := dpi_fetch(FStmt, 0, 0);
    if LCode = DPI_NO_DATA then Result := False
    else begin CheckDpi(LCode, FStmt, DPI_HANDLE_STMT); Result := True; end;
    if LTimed then begin FEmitted := True; FTrace.NotifyQuery(LT0, FSql); end;
  except
    on E: EDmError do
    begin
      if LTimed then
      begin
        ClassifyDm(E.ErrorCode, E.SqlState, LCat, LCon);
        FTrace.NotifyError(LCat, FSql);
      end;
      RaiseDmAsDb(E);
    end;
    on E: EDbError do
    begin
      if LTimed then FTrace.NotifyError(E.Category, FSql);
      raise;
    end;
  end;
end;

procedure TDbDmQuery.Reset;
begin
  FEmitted := False;
  if FStmt <> nil then dpi_close_cursor(FStmt);
end;

function TDbDmQuery.ColumnCount: Integer;
var
  C: Integer;
begin
  EnsureStmt; dpi_col_count(FStmt, @C); Result := C;
end;

function TDbDmQuery.ColumnName(AIndex: Integer): string;
var
  N: array[0..255] of AnsiChar; T, Len, Prec, Scale, Nullable: Integer;
begin
  EnsureStmt;
  N[0] := #0;
  dpi_describe_col(FStmt, AIndex, @N[0], SizeOf(N), @T, @Len, @Prec, @Scale, @Nullable);
  Result := AnsiPtrToStr(@N[0]);
end;

function TDbDmQuery.ColumnType(AIndex: Integer): TDbColumnType;
var
  N: array[0..255] of AnsiChar; T, Len, Prec, Scale, Nullable: Integer;
begin
  dpi_describe_col(FStmt, AIndex, @N[0], SizeOf(N), @T, @Len, @Prec, @Scale, @Nullable);
  case T of
    DPI_TYPE_INTEGER, DPI_TYPE_BIGINT: Result := dbcInteger;
    DPI_TYPE_DOUBLE: Result := dbcFloat;
    DPI_TYPE_BLOB: Result := dbcBlob;
    else Result := dbcText;
  end;
end;

function TDbDmQuery.IsNull(AIndex: Integer): Boolean;
var
  Buf: array[0..7] of Byte; Len: Integer;
begin
  Len := -1;
  dpi_get_data(FStmt, AIndex, DPI_TYPE_VARCHAR, @Buf[0], SizeOf(Buf), @Len);
  Result := Len < 0;
end;

function TDbDmQuery.GetInt64(AIndex: Integer): Int64;
begin
  Result := StrToInt64Def(GetText(AIndex), 0);
end;

function TDbDmQuery.GetDouble(AIndex: Integer): Double;
begin
  Result := StrToFloatDef(GetText(AIndex), 0);
end;

function TDbDmQuery.GetText(AIndex: Integer): string;
var
  Buf: array[0..4095] of AnsiChar; Len: Integer;
  LAnsi: AnsiString;
begin
  Buf[0] := #0; Len := 0;
  dpi_get_data(FStmt, AIndex, DPI_TYPE_VARCHAR, @Buf[0], SizeOf(Buf), @Len);
  if Len < 0 then Exit('');
  if Len < SizeOf(Buf) then
  begin
    Buf[Len] := #0;
    Result := AnsiPtrToStr(@Buf[0]);
    Exit;
  end;
  // 截断路径：按真实 Len 重取（避免 4K 静默截断，见稳定性复审）
  SetLength(LAnsi, Len);
  Len := 0;
  dpi_get_data(FStmt, AIndex, DPI_TYPE_VARCHAR, PAnsiChar(LAnsi), Length(LAnsi)+1, @Len);
  if Len < 0 then Exit('');
  if Len < Length(LAnsi) then SetLength(LAnsi, Len);
  Result := string(LAnsi);
end;

function TDbDmQuery.GetBlob(AIndex: Integer): TBytes;
var
  S: string; I: Integer;
begin
  S := GetText(AIndex);
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do Result[I-1] := Byte(S[I]);
end;

constructor TDbDmConnection.Create(AEnv: TDmEnv; AConn: TDmConn; const AStmtCacheCapacity: Integer);
begin
  inherited Create;
  FEnv := AEnv; FConn := AConn; FLock := nextpas.core.sync.Mutex; FDepth := 0;
  FTrace := TDbTraceHub.Create; FChanges := 0;
  if AStmtCacheCapacity > 0 then
    FCache := specialize TLruCache<string, IDmStmtHolder>.Create(SizeUInt(AStmtCacheCapacity));
end;

destructor TDbDmConnection.Destroy;
begin
  FTrace.NotifyRelease;
  FTrace.Free;
  FCache := nil;
  if FConn <> nil then begin dpi_disconnect(FConn); dpi_free_conn(FConn); end;
  if FEnv <> nil then dpi_free_env(FEnv);
  inherited Destroy;
end;

procedure TDbDmConnection.SetListener(const AListener: IDbTraceListener);
begin
  FTrace.SetListener(AListener);
end;

function TDbDmConnection.HasListener: Boolean;
begin
  Result := FTrace.Active;
end;

function TDbDmConnection.Kind: TDbKind;
begin
  Result := dbkDm;
end;

procedure TDbDmConnection.DmExec(const ASql: string);
var
  Stmt: TDmStmt; LSql: AnsiString; LCode: Integer;
begin
  Stmt := nil;
  LCode := dpi_create_stmt(FConn, @Stmt);
  CheckDpi(LCode, FConn, DPI_HANDLE_DBC);
  try
    LSql := AnsiString(ASql);
    LCode := dpi_prepare(Stmt, PAnsiChar(LSql), Length(LSql));
    CheckDpi(LCode, Stmt, DPI_HANDLE_STMT);
    LCode := dpi_execute(Stmt);
    CheckDpi(LCode, Stmt, DPI_HANDLE_STMT);
    dpi_row_count(Stmt, @FChanges);
  finally
    if Stmt <> nil then dpi_free_stmt(Stmt);
  end;
end;

procedure TDbDmConnection.EnsureConnected;
begin
  if (FEnv = nil) or (FConn = nil) then
    raise EDbError.CreateSimple(dbkDm, 'DM connection not established');
end;

procedure TDbDmConnection.Exec(const ASql: string);
var
  LT0: QWord; LTimed: Boolean;
begin
  LT0 := 0; LTimed := FTrace.BeginOp(LT0);
  try
    try DmExec(ASql); except on E: EDmError do RaiseDmAsDb(E); end;
    if LTimed then FTrace.NotifyQuery(LT0, ASql);
  except on E: EDbError do begin if LTimed then FTrace.NotifyError(E.Category, ASql); raise; end; end;
end;

procedure TDbDmConnection.Exec(const ASql: string; const AOptions: TDbExecOptions);
begin
  Exec(ASql); // advisory timeout ignored v1
end;

procedure TDbDmConnection.BulkExec(const ASql: string);
begin
  Exec(ASql);
end;

function TDbDmConnection.Query(const ASql: string): IDbQuery;
var Holder: IDmStmtHolder; S: TDmStmt;
begin
  EnsureConnected;
  if (FCache <> nil) and FCache.Get(ASql, Holder) then
  begin
    FCache.Remove(ASql);
    S := Holder.Detach;
    Holder := nil;
    Result := TDbDmQuery.Create(FEnv, FConn, ASql, FTrace, Self as IDmStmtHome, S);
    Exit;
  end;
  Result := TDbDmQuery.Create(FEnv, FConn, ASql, FTrace);
end;

function TDbDmConnection.Query(const ASql: string; const AOptions: TDbExecOptions): IDbQuery;
begin
  Result := Query(ASql);
end;

function TDbDmConnection.Changes: Int64;
begin
  Result := FChanges;
end;

function TDbDmConnection.Raw: Pointer;
begin
  Result := FConn;
end;

procedure TDbDmConnection.BeginTxn(const AImmediate: Boolean = False);
begin
  { DM DPI 事务由 dpi_commit/rollback 驱动，无显式 BEGIN 语句（隐式开启）。
    仅做深度簿记，与 sqlite/pg 的 BeginTxn(True) no-op 语义一致。 }
  FLock.Acquire;
  try
    Inc(FDepth);
  finally
    FLock.Release;
  end;
end;

procedure TDbDmConnection.CommitTxn;
var
  LDoCommit: Boolean;
begin
  FLock.Acquire;
  try
    if FDepth = 0 then raise EDbError.CreateSimple(dbkDm, 'no transaction');
    Dec(FDepth);
    LDoCommit := FDepth = 0;
  finally
    FLock.Release;
  end;
  if LDoCommit then CheckDpi(dpi_commit(FConn), FConn, DPI_HANDLE_DBC);
end;

procedure TDbDmConnection.RollbackTxn;
begin
  FLock.Acquire;
  try
    if FDepth = 0 then raise EDbError.CreateSimple(dbkDm, 'no transaction');
    FDepth := 0;
  finally
    FLock.Release;
  end;
  CheckDpi(dpi_rollback(FConn), FConn, DPI_HANDLE_DBC);
end;

function TDbDmConnection.InTransaction: Boolean;
begin
  FLock.Acquire;
  try
    Result := FDepth > 0;
  finally
    FLock.Release;
  end;
end;

function TDbDmConnection.TxDepth: Integer;
begin
  FLock.Acquire;
  try
    Result := FDepth;
  finally
    FLock.Release;
  end;
end;

procedure TDbDmConnection.Savepoint(const AName: string);
begin
  ValidateDbSavepointName(dbkDm, AName);
  DmExec('SAVEPOINT ' + AName);
end;

procedure TDbDmConnection.RollbackTo(const AName: string);
begin
  ValidateDbSavepointName(dbkDm, AName);
  DmExec('ROLLBACK TO SAVEPOINT ' + AName);
end;

procedure TDbDmConnection.ReleaseTo(const AName: string);
begin
  ValidateDbSavepointName(dbkDm, AName);
  DmExec('RELEASE SAVEPOINT ' + AName);
end;

procedure TDbDmConnection.ExecuteBatch(const ASteps: TDbSqlSteps);
var
  I: Integer;
begin
  if Length(ASteps) = 0 then Exit;
  BeginTxn(False);
  try
    for I := 0 to High(ASteps) do DmExec(ASteps[I]);
    CommitTxn;
  except
    RollbackTxn; raise;
  end;
end;

function TDbDmConnection.ProductName: string;
begin
  Result := 'DM';
end;

function TDbDmConnection.ProductVersion: string;
var
  Buf: array[0..127] of AnsiChar;
begin
  Buf[0] := #0;
  if Assigned(dpi_version) and (dpi_version(FConn, @Buf[0], SizeOf(Buf)) = DPI_SUCCESS) then
    Result := AnsiPtrToStr(@Buf[0])
  else
    Result := '';
end;

function TDbDmConnection.SupportsSavepoints: Boolean;
begin
  Result := True;
end;

function TDbDmConnection.SupportsBatchExecutor: Boolean;
begin
  Result := True;
end;

function TDbDmConnection.SupportsStmtCacheControl: Boolean;
begin
  Result := True;
end;

procedure TDbDmConnection.Clear;
begin
  if FCache <> nil then FCache.Clear;
end;

function TDbDmConnection.Size: Integer;
begin
  if FCache <> nil then Result := Integer(FCache.GetSize) else Result := 0;
end;

function TDbDmConnection.HitRate: Double;
begin
  if FCache <> nil then Result := FCache.GetHitRate else Result := 0.0;
end;

procedure TDbDmConnection.ReturnStmt(const ASql: string; AStmt: TDmStmt);
begin
  if AStmt = nil then Exit;
  if FCache <> nil then
  begin
    dpi_close_cursor(AStmt);
    FCache.Put(ASql, TDmStmtHolder.Create(AStmt));
  end
  else
    dpi_free_stmt(AStmt);
end;

function TDbDmConnection.SupportsLargeObjects: Boolean;
begin
  Result := False;
end;

function TDbDmConnection.SupportsArrayBinding: Boolean;
begin
  Result := False;
end;

function TDbDmConnection.SupportsNativeBool: Boolean;
begin
  Result := False;
end;

function TDbDmConnection.SupportsMultiStatementExec: Boolean;
begin
  Result := False;
end;

function TDbDmConnection.SupportsStatementTimeout: Boolean;
begin
  Result := False;
end;

function TDbDmConnection.CaseSensitiveIdentifiers: Boolean;
begin
  Result := False;
end;

function TDbDmConnection.MaxPlaceholders: Integer;
begin
  Result := 999;
end;


function TDbDmConnection.ServerVersion: Integer;
begin
  if FServerVersionProbed then Exit(FServerVersion);
  FServerVersionProbed := True;
  FServerVersion := ParseServerVersion(ProductVersion);
  Result := FServerVersion;
end;

function TDbDmConnection.SupportsNativeVector: Boolean;
begin
  Result := ProbeNativeVector(ServerVersion, False);
end;

function TDbDmConnection.SupportsJsonPath: Boolean;
begin
  Result := ProbeJsonPath(ServerVersion);
end;

function TDbDmConnection.SupportsRangeTypes: Boolean;
begin
  Result := ProbeRangeTypes(ServerVersion);
end;

function TDbDmConnection.SupportsBulkCopy: Boolean;
begin
  Result := ProbeSupportsBulkCopy(dbkDm, ServerVersion);
end;

procedure TDbDmConnection.BeginCopy(const ATable: string; const AColumns: array of string);
begin
  DbBulkBeginCopy(FBulk, dbkDm, ATable, AColumns);
end;

procedure TDbDmConnection.WriteRow(const AValues: array of string);
begin
  DbBulkWriteRow(FBulk, dbkDm, AValues);
end;

procedure TDbDmConnection.EndCopy;
begin
  DbBulkEndCopy(FBulk, MaxPlaceholders, InTransaction, SupportsSavepoints,
    @BulkExec, @BeginTxn, @CommitTxn, @RollbackTxn);
end;

procedure TDbDmConnection.AbortCopy;
begin
  DbBulkAbortCopy(FBulk);
end;

function TDbDmConnection.ArmCancel: Boolean;
begin
  Result := False;
end;

procedure TDbDmConnection.DisarmCancel;
begin
end;

procedure TDbDmConnection.RequestCancel;
begin
  if Assigned(dpi_cancel) then
  begin
    // best effort per connection handle not stmt; no-op v1
  end;
end;

function ConnectDm(const ADsn: string): IDbConnection;
var
  Opts: TDbConnectOptions;
begin
  Opts := TDbConnectOptions.Default;
  Result := ConnectDm(ADsn, Opts);
end;

function ConnectDm(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection;
begin
  Result := ConnectDm(ADsn, AOptions, DEFAULT_DM_STMT_CACHE_CAPACITY);
end;

function ConnectDm(const ADsn: string; const AOptions: TDbConnectOptions; const AStmtCacheCapacity: Integer): IDbConnection;
var
  Env: TDmEnv; Conn: TDmConn; LCode: Integer; LConnStr: AnsiString;
begin
  ValidateDmDsn(ADsn);
  if not DmEnsureLoaded then
    raise EDbError.CreateFullDm(-2003, '08001', 'DM DPI library not found: ' + DmLibraryName, decConnection, dckNone);
  Env := nil; Conn := nil;
  LCode := dpi_create_env(@Env);
  CheckDpi(LCode, nil, DPI_HANDLE_ENV);
  try
    LCode := dpi_create_conn(Env, @Conn);
    CheckDpi(LCode, Env, DPI_HANDLE_ENV);
    LConnStr := DsnToDpiConnStr(ADsn);
    LCode := dpi_connect(Conn, PAnsiChar(LConnStr));
    if LCode <> DPI_SUCCESS then
    begin
      // fetch diagnostic
      CheckDpi(LCode, Conn, DPI_HANDLE_DBC);
    end;
    Result := TDbDmConnection.Create(Env, Conn, AStmtCacheCapacity);
    Env := nil; Conn := nil; // ownership transferred
  except
    if Conn <> nil then dpi_free_conn(Conn);
    if Env <> nil then dpi_free_env(Env);
    raise;
  end;
end;

initialization
finalization

end.
