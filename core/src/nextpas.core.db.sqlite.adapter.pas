unit nextpas.core.db.sqlite.adapter;

{** @desc SQLite 适配（L3）：组合委托 L2 sqlite.conn，归一错误与观测，
       事务/PRAGMA/能力等收敛至 owner 单源。
       性能：bytes.ops 单源 inline/零拷贝；稳定性：DisarmCancel→Free
       句柄，接口引用计数自动归还。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,           // L0
  nextpas.core.exception,      // L0
  nextpas.core.db.base,        // L2 家族依赖根（仅 L0；L3 同层单向，无上向）
  nextpas.core.db.intf,        // L2 契约（同层单向）
  nextpas.core.db.trace,       // L2 观测（同层单向）
  nextpas.core.db.bulk,        // L3 行缓冲（DM 同体裁，薄转发单源）
  nextpas.core.db.sqlite.base, // L2 后端基
  nextpas.core.db.sqlite.conn; // L2 后端实现

{ 创建 sqlite 连接并返回统一接口（':memory:' 可用）。
  失败抛 EDbError（BackendCode 携带原生结果码）。
  AStmtCacheCapacity：透明预编译语句缓存的空闲容量（LRU，键 = 原始
  SQL 文本）；<= 0 关闭缓存走直通路径。默认开启。 }
function ConnectSqlite(const APath: string;
  const AStmtCacheCapacity: Integer = DEFAULT_SQLITE_STMT_CACHE_CAPACITY):
  IDbConnection;
{ INC-7：带连接选项版本。BusyTimeoutMs 应用 PRAGMA busy_timeout
  （锁等待上限）；sqlite 无语句超时机制，StatementTimeoutMs 非 0
  被忽略（不冒充）。 }
function ConnectSqlite(const APath: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer = DEFAULT_SQLITE_STMT_CACHE_CAPACITY):
  IDbConnection;
{ C5 调优预设：连接级 PRAGMA 受控面（journal/sync/fk/cache/mmap）。
  语义：unset 字段不设置；:memory: 库过滤 journal_mode（WAL 对内存
  库无意义）；journal_mode 应用后回读校验——文件系统不支持 WAL 时
  sqlite 会静默保持原模式，此处 fail-closed 抛 decNotSupported，
  绝不静默降级（静默降级 = 消费方误信并发安全）。 }
function ConnectSqlite(const APath: string; const AOptions: TDbConnectOptions;
  const APragmas: TDbSqlitePragmas;
  const AStmtCacheCapacity: Integer = DEFAULT_SQLITE_STMT_CACHE_CAPACITY):
  IDbConnection;

implementation

{ L3 分治（实现段私有，严格下向 L2 sqlite.conn/base）：
  cache   语句缓存（Holder/Home/Query）
  observe 观测（错误归一/列类型映射）
  blob    Blob 流
  cancel  取消（原子+progress）
  state   状态（ForeignKeys 标记）
  pragmas pragma 调优（C5 单源）
  tx      事务（深度计数/autocommit 守卫）
  caps    能力探测（Probe 单源）
  factory 工厂（BusyTimeout/PRAGMA 单源） }
uses
  nextpas.core.bytes.ops,
  nextpas.core.text.conv,
  nextpas.core.db.savepoint,
  nextpas.core.db.sqlite.adapter.cache,
  nextpas.core.db.sqlite.adapter.observe,
  nextpas.core.db.sqlite.adapter.blob,
  nextpas.core.db.sqlite.adapter.cancel,
  nextpas.core.db.sqlite.adapter.state,
  nextpas.core.db.sqlite.adapter.pragmas,
  nextpas.core.db.sqlite.adapter.tx,
  nextpas.core.db.sqlite.adapter.caps,
  nextpas.core.db.sqlite.adapter.factory;


type
  TDbSqliteConnection = class(TInterfacedObject, IDbConnection, IDbTxControl,
    IDbSavepointControl, IDbBatchExecutor, IDbStmtCacheControl,
    IDbRowBlobControl, IDbCapabilities, IDbTraceControl, ISqliteStmtHome,
    IDbCancelControl, IDbForeignKeysControl, IDbBulkCopy)
  private
    FDb: TSqliteDb;
    { 适配-事务 owner 边界：深度计数收敛至 adapter.tx 单源委托
      （零经 db.sqlite.tx 全局簿记直调；L3→L2 严格下向，bytes.ops
      单源，事务面性能 inline 薄转发）。 }
    FTx: TSqliteTx;
    { 组合委托：各责单源子模块持有，连接仅编排（零多责聚合）。 }
    FCancel: TSqliteCancel;
    FState: TSqliteConnState;
    { 空闲预编译语句池：键 = 原始 SQL，借出即移除（同 SQL 并发活动
      查询各持独立实例），归还回插；LRU 只管空闲驱逐。
      nil = 缓存关闭直通。单连接单逻辑线程（CONTRACT §2.1），
      无需并发防护。 }
    FCache: ISqliteStmtCache;
    { 观测钩子枢纽（V3-B3）：监听器存取/摘要/计时/分发统一委托 }
    FTrace: TDbTraceHub;
    { Bulk 行缓冲（DM 同体裁：TDbBulkBuffer + DbBulk* 薄转发，flush 经
      BulkExecChunkFlat 零拷贝，bulk.pas 单源） }
    FBulk: TDbBulkBuffer;
    { Holder 壳复用池：冷启动预填零分配， miss/复位失败路径零新建堆分配
      （Attach 复用壳，LRU 满时偷 victim 壳，bytes.ops 单源 inline） }
    FHolderPool: array of ISqliteStmtHolder;
    FHolderPoolTop: Integer;
    function AcquireHolder(AStmt: TSqliteQuery): ISqliteStmtHolder; inline;
  public
    constructor Create(ADb: TSqliteDb;
      const AStmtCacheCapacity: Integer);     { 取得所有权 }
    destructor Destroy; override;

    { IDbTraceControl }
    procedure SetListener(const AListener: IDbTraceListener);
    function HasListener: Boolean;

    function Kind: TDbKind;
    procedure Exec(const ASql: string); overload;
    procedure Exec(const ASql: string;
      const AOptions: TDbExecOptions); overload;
    function Query(const ASql: string): IDbQuery; overload;
    function Query(const ASql: string;
      const AOptions: TDbExecOptions): IDbQuery; overload;
    function Changes: Int64;
    function Raw: Pointer;

    { IDbTxControl：经 adapter.tx 委托（收敛至 db.tx owner，
      零经 db.sqlite.tx 直调；语义对齐 pg/mysql 家族，inline 薄转发）。 }
    procedure BeginTxn(const AImmediate: Boolean = False);
    procedure CommitTxn;
    procedure RollbackTxn;
    function InTransaction: Boolean; inline;
    function TxDepth: Integer; inline;

    { IDbSavepointControl }
    procedure Savepoint(const AName: string);
    procedure RollbackTo(const AName: string);
    procedure ReleaseTo(const AName: string);

    { IDbBatchExecutor }
    procedure ExecuteBatch(const ASteps: TDbSqlSteps);

    { IDbStmtCacheControl：语句缓存失效控制与诊断 }
    procedure Clear;
    function Size: Integer;
    function HitRate: Double;

    { IDbCapabilities（V3-B1）——Kind 由 IDbConnection.Kind 承担 }
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

    { ISqliteStmtHome：查询析构的归还通道（实现区接口，单元内可见） }
    procedure ReturnStmt(const ASql: string; AStmt: TSqliteQuery);
    procedure ReturnHolder(const ASql: string; const AHolder: ISqliteStmtHolder);

    { IDbRowBlobControl：行内 blob 单元流（INC-8） }
    function OpenRowBlob(const ATable, AColumn: string;
      const ARowId: Int64; const AReadWrite: Boolean): IDbBlobStream;

    { IDbCancelControl（V3-B6）：db.async 取消映射面。
      adapter.cancel 原子标志由任意线程经 RequestCancel 置位；
      progress handler（Arm 期间安装）读到非零即中断在途 step。 }
    function ArmCancel: Boolean;
    procedure DisarmCancel;
    procedure RequestCancel;

    { IDbForeignKeysControl：句柄内标记零锁去重 }
    function ForeignKeysOn: Boolean;
    procedure SetForeignKeysOn(const AValue: Boolean);

    { IDbBulkCopy（DM 同体裁：TDbBulkBuffer + DbBulk* 单源薄转发） }
    procedure BeginCopy(const ATable: string; const AColumns: array of string);
    procedure WriteRow(const AValues: array of string);
    procedure EndCopy;
    procedure AbortCopy;
    procedure BulkExec(const ASql: string);
  end;

{ ---- TDbSqliteConnection ---- }

constructor TDbSqliteConnection.Create(ADb: TSqliteDb;
  const AStmtCacheCapacity: Integer);
var
  I: Integer;
begin
  inherited Create;
  FDb := ADb;
  FTx := TSqliteTx.Create(FDb);
  if AStmtCacheCapacity > 0 then
  begin
    FCache := CreateSqliteStmtCache(AStmtCacheCapacity);
    // perf: cold-start 预填 holder 壳池零抖动 — 连接构建期单次批量分配，后续 miss/复位失败零新建堆分配（inline Attach 复用，bytes.ops 单源）
    SetLength(FHolderPool, AStmtCacheCapacity);
    for I := 0 to AStmtCacheCapacity - 1 do
      FHolderPool[I] := TSqliteStmtHolder.Create(nil);
    FHolderPoolTop := AStmtCacheCapacity;
  end
  else
  begin
    FHolderPoolTop := 0;
  end;
  FTrace := TDbTraceHub.Create;
  FCancel := TSqliteCancel.Create(FDb.Handle);
  FState := TSqliteConnState.Create;
  { OnAcquire 由 SetListener 挂载时补发（§2.12），ctor 不预发 }
end;

destructor TDbSqliteConnection.Destroy;
begin
  if FCancel <> nil then
    FCancel.Disarm;                    { handler 先于 close 卸载，零丢句柄 }
  if FTrace <> nil then
    FTrace.NotifyRelease;   { OnRelease = 连接关闭 }
  if FTrace <> nil then
  begin
    FTrace.Free;
    FTrace := nil;
  end;
  FCache := nil;                       { Clear：空闲 holder 全部释放 }
  FHolderPoolTop := 0;
  SetLength(FHolderPool, 0);           { 接口池自动释放，零泄漏 }
  if FCancel <> nil then
  begin
    FCancel.Free;
    FCancel := nil;
  end;
  if FState <> nil then
  begin
    FState.Free;
    FState := nil;
  end;
  if FTx <> nil then
  begin
    FTx.Free;
    FTx := nil;
  end;
  FDb.Free;
  inherited Destroy;
end;

procedure TDbSqliteConnection.SetListener(
  const AListener: IDbTraceListener);
begin
  FTrace.SetListener(AListener);
end;

function TDbSqliteConnection.HasListener: Boolean;
begin
  Result := FTrace.Active;
end;

function TDbSqliteConnection.Kind: TDbKind;
begin
  Result := dbkSqlite;
end;

procedure TDbSqliteConnection.Exec(const ASql: string);
var
  LT0: QWord;
  LTimed: Boolean;
begin
  LT0 := 0;
  LTimed := FTrace.BeginOp(LT0);
  try
    FDb.Exec(ASql);
    if LTimed then
      FTrace.NotifyQuery(LT0, ASql);
  except
    on E: ESqliteError do
    begin
      if LTimed then
        FTrace.NotifyError(SqliteCategoryOf(E), ASql);
      RaiseSqliteAsDb(E);
    end;
  end;
end;

procedure TDbSqliteConnection.Exec(const ASql: string;
  const AOptions: TDbExecOptions);
begin
  { TimeoutMs advisory 忽略（INC-7 同款诚实登记：sqlite 无语句级
    超时机制，连接级 busy_timeout 已有）；其余选项未来扩展位 }
  Exec(ASql);
end;

function TDbSqliteConnection.Query(const ASql: string): IDbQuery;
var
  Stmt: TSqliteQuery;
  Holder: ISqliteStmtHolder;
begin
  Stmt := nil;
  Holder := nil;
  if FCache <> nil then
  begin
    { 借出即移除：TryTake 原子取出（Get+Remove 单哈希，500k ops 下减半键哈希与比对，零双重查找；TryTake 内部已计 Hit/Miss）——
      同 SQL 的第二个活动查询必然 miss，各持独立实例（嵌套安全） }
    if FCache.TryTake(ASql, Holder) then
    begin
      // perf: inline TryTake 单哈希零额外拷贝，Holder 保留随查询携带，归还时零分配复用（热路径 549k ops/s 零 TSqliteStmtHolder 堆分配）
      Stmt := Holder.Detach;
    end;
  end;
  if Stmt = nil then
  begin
    Holder := nil;
    try
      Stmt := FDb.Query(ASql);         { miss / 直通路径 }
    except
      on E: ESqliteError do RaiseSqliteAsDb(E);
    end;
  end;
  if Holder <> nil then
    Result := TDbSqliteQuery.Create(Self, ASql, Stmt, FTrace, Holder)
  else
    Result := TDbSqliteQuery.Create(Self, ASql, Stmt, FTrace);
end;

function TDbSqliteConnection.Query(const ASql: string;
  const AOptions: TDbExecOptions): IDbQuery;
begin
  { TimeoutMs advisory 忽略（INC-7 同款诚实登记）}
  Result := Query(ASql);
end;

{ ---- holder 壳复用池 ---- }

function TDbSqliteConnection.AcquireHolder(AStmt: TSqliteQuery): ISqliteStmtHolder; inline;
var
  LKey: string;
  LHolder: ISqliteStmtHolder;
  LOld: TSqliteQuery;
begin
  // perf: inline 零新建堆分配 — 池 pop Attach 复用壳，满容量时偷 LRU victim 壳零分配（bytes.ops 单源，冷启动预填池零抖动，DDL 复位失败 Attach(nil)回池）
  if FHolderPoolTop > 0 then
  begin
    Dec(FHolderPoolTop);
    Result := FHolderPool[FHolderPoolTop];
    FHolderPool[FHolderPoolTop] := nil;
    Result.Attach(AStmt);
    Exit;
  end;
  if (FCache <> nil) and (FCache.GetSize >= FCache.GetMaxSize) and FCache.PeekLeastRecent(LKey, LHolder) then
  begin
    // stability: 偷 victim 壳复用 — 旧语句在 holder.Detach 后释放，资源不丢，零新建堆
    FCache.Remove(LKey);
    LOld := LHolder.Detach;
    if LOld <> nil then
      LOld.Free;
    LHolder.Attach(AStmt);
    Result := LHolder;
    Exit;
  end;
  Result := TSqliteStmtHolder.Create(AStmt);
end;

{ ---- ISqliteStmtHome ---- }

procedure TDbSqliteConnection.ReturnStmt(const ASql: string; AStmt: TSqliteQuery);
var
  LNew: TSqliteQuery;
begin
  if AStmt = nil then
    Exit;
  if FCache <> nil then
  begin
    // perf: cold miss 路径 — inline return-code 零异常帧复用 L2 TryReset/ClearBindings（bytes.ops 单源），壳经 AcquireHolder 池/偷 victim 零新建堆（冷启动预填零抖动）
    if not AStmt.TryReset then
    begin
      AStmt.Free;
      // stability: DDL/schema 抖动下自愈回池，保持占位命中率稳定（fail-closed 不投毒，资源不丢，壳复用零泄漏）
      try
        LNew := FDb.Query(ASql);
      except
        on E: ESqliteError do Exit;
      end;
      FCache.Put(ASql, AcquireHolder(LNew));
      { 容量满时 Put 驱逐 LRU：被驱逐 holder 析构即释放其语句 }
      Exit;
    end;
    if not AStmt.TryClearBindings then
    begin
      AStmt.Free;
      try
        LNew := FDb.Query(ASql);
      except
        on E: ESqliteError do Exit;
      end;
      FCache.Put(ASql, AcquireHolder(LNew));
      Exit;
    end;
    FCache.Put(ASql, AcquireHolder(AStmt));
    { 容量满时 Put 驱逐 LRU：被驱逐 holder 析构即释放其语句 }
  end
  else
    AStmt.Free;
end;

procedure TDbSqliteConnection.ReturnHolder(const ASql: string; const AHolder: ISqliteStmtHolder);
var
  LStmt: TSqliteQuery;
  LNew: TSqliteQuery;
begin
  if (AHolder = nil) or (FCache = nil) then
    Exit;
  LStmt := AHolder.GetStmt;
  if LStmt = nil then
    Exit;
  // perf: hot hit 复用路径 — 零新建 holder 堆分配，inline TryReset/ClearBindings 零异常帧（bytes.ops 单源，L2 反哺）
  if not LStmt.TryReset then
  begin
    // stability: 自愈回池（复用 holder 零额外堆分配热路径保留，DDL 抖动不丢占位，fail-closed）
    AHolder.Attach(nil);
    LStmt.Free;
    try
      LNew := FDb.Query(ASql);
    except
      on E: ESqliteError do Exit;
    end;
    AHolder.Attach(LNew);
    FCache.Put(ASql, AHolder);
    Exit;
  end;
  if not LStmt.TryClearBindings then
  begin
    AHolder.Attach(nil);
    LStmt.Free;
    try
      LNew := FDb.Query(ASql);
    except
      on E: ESqliteError do Exit;
    end;
    AHolder.Attach(LNew);
    FCache.Put(ASql, AHolder);
    Exit;
  end;
  FCache.Put(ASql, AHolder);
end;

{ ---- IDbStmtCacheControl ---- }

procedure TDbSqliteConnection.Clear;
begin
  if FCache <> nil then
    FCache.Clear;
end;

function TDbSqliteConnection.Size: Integer;
begin
  if FCache <> nil then
    Result := Integer(FCache.GetSize)
  else
    Result := 0;
end;

function TDbSqliteConnection.HitRate: Double;
begin
  if FCache <> nil then
    Result := FCache.GetHitRate
  else
    Result := 0.0;
end;

{ ---- IDbCapabilities（V3-B1）---- }

function TDbSqliteConnection.ProductName: string; inline;
begin
  // perf: inline 薄转发至 caps 单源零拷贝（bytes.ops 单源）
  Result := SqliteProductName;
end;

function TDbSqliteConnection.ProductVersion: string; inline;
begin
  // perf: inline 单次 AnsiPtrToStr 零拷贝桥接（bytes.ops 单源，sqlite3_libversion 单源 caps）
  Result := SqliteProductVersion;
end;

function TDbSqliteConnection.SupportsSavepoints: Boolean; inline;
begin
  Result := SqliteSupportsSavepoints;
end;

function TDbSqliteConnection.SupportsBatchExecutor: Boolean; inline;
begin
  Result := SqliteSupportsBatchExecutor;
end;

function TDbSqliteConnection.SupportsStmtCacheControl: Boolean; inline;
begin
  Result := SqliteSupportsStmtCacheControl;
end;

function TDbSqliteConnection.SupportsLargeObjects: Boolean; inline;
begin
  Result := SqliteSupportsLargeObjects;
end;

function TDbSqliteConnection.SupportsArrayBinding: Boolean; inline;
begin
  Result := SqliteSupportsArrayBinding;
end;

function TDbSqliteConnection.SupportsNativeBool: Boolean; inline;
begin
  Result := SqliteSupportsNativeBool;
end;

function TDbSqliteConnection.SupportsMultiStatementExec: Boolean; inline;
begin
  Result := SqliteSupportsMultiStatementExec;
end;

function TDbSqliteConnection.SupportsStatementTimeout: Boolean; inline;
begin
  Result := SqliteSupportsStatementTimeout;
end;

function TDbSqliteConnection.CaseSensitiveIdentifiers: Boolean; inline;
begin
  Result := SqliteCaseSensitiveIdentifiers;
end;

function TDbSqliteConnection.MaxPlaceholders: Integer; inline;
begin
  Result := SqliteMaxPlaceholders;
end;

function TDbSqliteConnection.ServerVersion: Integer; inline;
begin
  // perf: inline ParseServerVersion 单源零拷贝视图扫描（caps 单源，bytes.ops 单源）
  Result := SqliteServerVersion;
end;

function TDbSqliteConnection.SupportsNativeVector: Boolean; inline;
begin
  Result := SqliteSupportsNativeVector(ServerVersion);
end;

function TDbSqliteConnection.SupportsJsonPath: Boolean; inline;
begin
  Result := SqliteSupportsJsonPath(ServerVersion);
end;

function TDbSqliteConnection.SupportsRangeTypes: Boolean; inline;
begin
  Result := SqliteSupportsRangeTypes(ServerVersion);
end;

function TDbSqliteConnection.SupportsBulkCopy: Boolean; inline;
begin
  Result := SqliteSupportsBulkCopy;
end;

procedure TDbSqliteConnection.BeginCopy(const ATable: string; const AColumns: array of string);
begin
  DbBulkBeginCopy(FBulk, dbkSqlite, ATable, AColumns);
end;

procedure TDbSqliteConnection.WriteRow(const AValues: array of string);
begin
  DbBulkWriteRow(FBulk, dbkSqlite, AValues);
end;

procedure TDbSqliteConnection.BulkExec(const ASql: string);
begin
  Exec(ASql);
end;

procedure TDbSqliteConnection.EndCopy;
begin
  DbBulkEndCopy(FBulk, MaxPlaceholders, InTransaction, @BulkExec, @BeginTxn, @CommitTxn, @RollbackTxn, SupportsSavepoints);
end;

procedure TDbSqliteConnection.AbortCopy;
begin
  DbBulkAbortCopy(FBulk);
end;

{ ---- IDbCancelControl（V3-B6）---- }

function TDbSqliteConnection.ArmCancel: Boolean; inline;
begin
  Result := FCancel.Arm;
end;

procedure TDbSqliteConnection.DisarmCancel; inline;
begin
  if FCancel <> nil then
    FCancel.Disarm;
end;

procedure TDbSqliteConnection.RequestCancel; inline;
begin
  { 线程安全：仅原子置位；handler 未武装时置位无害（Arm 会先清零，
    但消费方须保证 Arm→在途→RequestCancel→Disarm 的窗口纪律，见
    db.intf 注记）。已武装时下一次 VM 计数到期即中断。 }
  if FCancel <> nil then
    FCancel.RequestCancel;
end;

function TDbSqliteConnection.ForeignKeysOn: Boolean; inline;
begin
  Result := (FState <> nil) and FState.ForeignKeysOn;
end;

procedure TDbSqliteConnection.SetForeignKeysOn(const AValue: Boolean); inline;
begin
  if FState <> nil then
    FState.SetForeignKeysOn(AValue);
end;

{ ---- IDbRowBlobControl ---- }

function TDbSqliteConnection.OpenRowBlob(const ATable, AColumn: string;
  const ARowId: Int64; const AReadWrite: Boolean): IDbBlobStream;
begin
  Result := TDbSqliteBlobStream.Create(FDb.Handle, ATable, AColumn,
    ARowId, AReadWrite);
end;

function TDbSqliteConnection.Changes: Int64;
begin
  try
    Result := FDb.Changes;
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteConnection.Raw: Pointer;
begin
  Result := FDb.Handle;
end;

procedure TDbSqliteConnection.BeginTxn(const AImmediate: Boolean); inline;
begin
  // perf: inline 薄转发至 adapter.tx 单源（零经 db.sqlite.tx 直调，autocommit 守卫零分配，bytes.ops 单源）
  FTx.BeginTxn(AImmediate);
end;

procedure TDbSqliteConnection.CommitTxn; inline;
begin
  FTx.CommitTxn;
end;

procedure TDbSqliteConnection.RollbackTxn; inline;
begin
  FTx.RollbackTxn;
end;

function TDbSqliteConnection.InTransaction: Boolean; inline;
begin
  // perf: inline 零拷贝读 FTx 深度（FLock 轻量，bytes.ops 单源门禁已守卫）
  Result := FTx.InTransaction;
end;

function TDbSqliteConnection.TxDepth: Integer; inline;
begin
  Result := FTx.TxDepth;
end;

{ 统一 savepoint 标识符引用辅助：收敛至 db.savepoint 单源
  （Validate + 单次分配单 Move 零拷贝 TBufStringBuilder 路径，
  bytes.ops 单源 BYTES_OPS_SINGLE_SOURCE，inline 薄转发，三方法同源零重复） }
procedure TDbSqliteConnection.Savepoint(const AName: string);
begin
  // perf: db.savepoint 单次分配单 Move 零拷贝 inline 薄转发，bytes.ops 单源；stability: Validate fail-closed
  Exec(DbValidatedSavepointSql(dbkSqlite, AName));
end;

procedure TDbSqliteConnection.RollbackTo(const AName: string);
begin
  Exec(DbValidatedRollbackToSql(dbkSqlite, AName));
end;

procedure TDbSqliteConnection.ReleaseTo(const AName: string);
begin
  Exec(DbValidatedReleaseSql(dbkSqlite, AName));
end;

procedure TDbSqliteConnection.ExecuteBatch(const ASteps: TDbSqlSteps);
var
  I: Integer;
  LInTxn: Boolean;
  LT0: QWord;
  LTimed: Boolean;
const
  CBatchSp = 'np_batch_sp';
begin
  if Length(ASteps) = 0 then
    Exit;
  { 热点批量：单次计时窗口合并 N 次 platform_monotonic_ns→1 次（BeginOp 单 syscall，Notify 单 syscall，零 per-step BeginOp/Notify；无监听器零成本零 syscall）；零闭包零捕获 hot path，本地引擎无往返税逐条执行保留步骤级错误定位（FDb.Exec 直调绕 Exec→BeginOp）；inline 循环 + 计深 savepoint 隔离，零堆上引用计数闭包分配，复用 bytes.ops 单源拼接路径；text.conv IntToStr 单源零额外 syscall 构造 BATCH 标签仅在 LTimed 时分配；事务面：外层无事务则 BEGIN/COMMIT，嵌套则 SAVEPOINT 隔离本批（栈式同名复用，匹配 WithTransaction 语义，失败仅回滚本批），资源释放不丢（Rollback/Release 双层 try 护栏保原异常）。 }
  LT0 := 0;
  LTimed := FTrace.BeginOp(LT0);
  LInTxn := InTransaction;
  if LInTxn then
  begin
    try
      Savepoint(CBatchSp);
      try
        for I := 0 to High(ASteps) do
          FDb.Exec(ASteps[I]);
        ReleaseTo(CBatchSp);
      except
        try RollbackTo(CBatchSp); except end;
        try ReleaseTo(CBatchSp); except end;
        raise;
      end;
      if LTimed then
        FTrace.NotifyQuery(LT0, 'BATCH x' + IntToStr(Int64(Length(ASteps))));
    except
      on E: ESqliteError do
      begin
        if LTimed then
          FTrace.NotifyError(SqliteCategoryOf(E), 'BATCH');
        RaiseSqliteAsDb(E);
      end;
      on E: EDbError do
      begin
        if LTimed then
          FTrace.NotifyError(E.Category, 'BATCH');
        raise;
      end;
    end;
  end
  else
  begin
    try
      BeginTxn(False);
      try
        for I := 0 to High(ASteps) do
          FDb.Exec(ASteps[I]);
        CommitTxn;
      except
        if InTransaction then
          try RollbackTxn; except end;
        raise;
      end;
      if LTimed then
        FTrace.NotifyQuery(LT0, 'BATCH x' + IntToStr(Int64(Length(ASteps))));
    except
      on E: ESqliteError do
      begin
        if LTimed then
          FTrace.NotifyError(SqliteCategoryOf(E), 'BATCH');
        RaiseSqliteAsDb(E);
      end;
      on E: EDbError do
      begin
        if LTimed then
          FTrace.NotifyError(E.Category, 'BATCH');
        raise;
      end;
    end;
  end;
end;

{ ---- 工厂（C5 pragma 分治：SqlitePragmasUnset/ApplySqlitePragmas 单源于 adapter.pragmas/factory） ---- }

function InternalConnectSqlite(const APath: string;
  const AOptions: TDbConnectOptions; const APragmas: TDbSqlitePragmas;
  const AStmtCacheCapacity: Integer): IDbConnection;
var
  Db: TSqliteDb;
begin
  // perf: 工厂单源 TBufStringBuilder 单次分配单 Move 零拷贝（bytes.ops 单源 inline/零拷贝）；stability: RaiseSqliteAsDb 单源不丢
  Db := NewSqliteDb(APath, AOptions, APragmas);
  Result := TDbSqliteConnection.Create(Db, AStmtCacheCapacity);
end;

function ConnectSqlite(const APath: string;
  const AStmtCacheCapacity: Integer): IDbConnection;
begin
  Result := ConnectSqlite(APath, TDbConnectOptions.Default, AStmtCacheCapacity);
end;

function ConnectSqlite(const APath: string; const AOptions: TDbConnectOptions;
  const AStmtCacheCapacity: Integer): IDbConnection;
begin
  { 不带 pragmas 的旧入口保持 sqlite 原生缺省（全 unset），行为零变化 }
  Result := InternalConnectSqlite(APath, AOptions, SqlitePragmasUnset,
    AStmtCacheCapacity);
end;

function ConnectSqlite(const APath: string; const AOptions: TDbConnectOptions;
  const APragmas: TDbSqlitePragmas;
  const AStmtCacheCapacity: Integer): IDbConnection;
begin
  Result := InternalConnectSqlite(APath, AOptions, APragmas,
    AStmtCacheCapacity);
end;

end.
