unit nextpas.core.db.dm.adapter.conn;

{** @desc DM 适配器连接分治（L3 实现子模块）。
       封装 TDbDmConnection 的连接/事务/批量/能力探针与语句缓存编排：
       事务深度簿记+锁、Bulk 单事务管道、探针委托 capprobe 同源。
       层级：L3 适配子模块（严格下向 L2 dm.base/ffi/base + L1 text/bytes/collections/sync，
       同层单向依赖 query/common，不反向；被 adapter 单向依赖）。
       性能：事务 Begin/Commit/Rollback 互斥零额外分配，BulkExec inline 薄转发，
       缓存 LRU 单遍命中，ProductVersion 单次 dpi_version 零拷贝，bytes.ops 单源。
       稳定性：Destroy 先 NotifyRelease 再 Free 句柄，FCache 接口托管自动清，
       BulkAbort/Clear 接口释放不丢，锁内簿记锁外执行（Commit/Rollback 原子深度）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.dm.base,
  nextpas.core.db.trace,
  nextpas.core.db.bulk,
  nextpas.core.db.dm.adapter.query,
  nextpas.core.sync;

type
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
    procedure SetListener(const AListener: IDbTraceListener);
    function HasListener: Boolean;
    function Kind: TDbKind;
    procedure Exec(const ASql: string); overload;
    procedure Exec(const ASql: string; const AOptions: TDbExecOptions); overload;
    function Query(const ASql: string): IDbQuery; overload;
    function Query(const ASql: string; const AOptions: TDbExecOptions): IDbQuery; overload;
    function Changes: Int64;
    function Raw: Pointer;
    procedure BeginTxn(const AImmediate: Boolean = False);
    procedure CommitTxn;
    procedure RollbackTxn;
    function InTransaction: Boolean;
    function TxDepth: Integer;
    procedure Savepoint(const AName: string);
    procedure RollbackTo(const AName: string);
    procedure ReleaseTo(const AName: string);
    procedure ExecuteBatch(const ASteps: TDbSqlSteps);
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
    procedure BeginCopy(const ATable: string; const AColumns: array of string);
    procedure WriteRow(const AValues: array of string);
    procedure EndCopy;
    procedure AbortCopy;
    procedure Clear;
    function Size: Integer;
    function HitRate: Double;
    procedure ReturnStmt(const ASql: string; AStmt: TDmStmt);
    function ArmCancel: Boolean;
    procedure DisarmCancel;
    procedure RequestCancel;
  end;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.text.conv,
  nextpas.core.db.err,
  nextpas.core.db.savepoint,
  nextpas.core.db.capprobe,
  nextpas.core.db.dm.ffi,
  nextpas.core.db.dm.adapter.common,
  nextpas.core.collections.lrucache;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: db.dm.adapter.conn must reuse bytes.ops'}
{$IFEND}

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
    LSql := nextpas.core.bytes.ops.StringToAnsiString(ASql);
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
  Exec(ASql);
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
  // 收敛至 db.savepoint 单源：Validate+单分配单 Move 零拷贝 inline 薄转发，bytes.ops 单源；DM 方言带 SAVEPOINT 见 savepoint 单源
  DmExec(DbValidatedSavepointSql(dbkDm, AName));
end;

procedure TDbDmConnection.RollbackTo(const AName: string);
begin
  DmExec(DbValidatedRollbackToSavepointSql(dbkDm, AName));
end;

procedure TDbDmConnection.ReleaseTo(const AName: string);
begin
  DmExec(DbValidatedReleaseSavepointSql(dbkDm, AName));
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
  DbBulkEndCopy(FBulk, MaxPlaceholders, InTransaction, @BulkExec, @BeginTxn, @CommitTxn, @RollbackTxn, SupportsSavepoints);
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
  end;
end;

end.
