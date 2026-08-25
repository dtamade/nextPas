unit nextpas.core.db.sqlite.adapter;

{** @desc IDbConnection/IDbQuery 的 SQLite 适配器。
       包装 nextpas.core.db.sqlite.conn 的类表面并统一错误模型
       （ESqliteError -> EDbError）；事务控制面委托 db.sqlite.tx，
       autocommit 守卫与嵌套计数语义原样保留。

       所有权：适配器持有被包装的 TSqliteDb/TSqliteQuery 并在析构
       时释放；消费方只持有接口引用，不手写 Free。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.trace,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.sqlite.conn;

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

uses
  nextpas.core.base.utils,
  nextpas.core.text.conv,
  nextpas.core.text.scan,
  nextpas.core.atomic,
  nextpas.core.db.err,
  { 直接用 lrucache 子单元：collections 门面对泛型接口名不可透传
    （实证），且本处需具名特化类型作字段类型 }
  nextpas.core.collections.lrucache.intf,
  nextpas.core.collections.lrucache,
  nextpas.core.db.sqlite.ffi,
  nextpas.core.db.sqlite.tx,
  { 统一层 tx 后声明：裸名 WithTransaction 绑定到 IDbConnection 版本
    （db.sqlite.tx 的 TSqliteDb 版重载仅经全限定名使用） }
  nextpas.core.db.tx;

type
  {** 空闲语句持有者：LRU 的值形态。用接口而非裸对象指针——驱逐/
    Clear/缓存析构路径由编译器引用计数释放底层 stmt（S4 同款托管
    纪律，杜绝容器裸搬移泄漏）。 *}
  ISqliteStmtHolder = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE008}']
    { 所有权移交：返回底层语句并清空持有（未被 Detach 的语句在
      holder 析构时释放 = 驱逐/清空路径） }
    function Detach: TSqliteQuery;
  end;

  TSqliteStmtHolder = class(TInterfacedObject, ISqliteStmtHolder)
  private
    FStmt: TSqliteQuery;
  public
    constructor Create(AStmt: TSqliteQuery);   { 取得所有权 }
    destructor Destroy; override;
    function Detach: TSqliteQuery;
  end;

  {** 查询→连接的归还通道。查询持本接口强引用：即使消费方先释放
    连接接口再释放查询，连接仍存活可安全回插（对抗序安全；无环——
    连接只缓存空闲语句，从不引用在途查询）。 *}
  ISqliteStmtHome = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE009}']
    procedure ReturnStmt(const ASql: string; AStmt: TSqliteQuery);
  end;

  ISqliteStmtCache = specialize ILruCache<string, ISqliteStmtHolder>;

  {** sqlite 行内 blob 单元流（INC-8，IDbBlobStream）：sqlite3_blob_*
      薄包装。定长模型——Size 即单元字节数，写不得越过末尾；位置由
      本对象维护（原生 API 每次调用显式带 offset）。接口释放即
      blob_close。 *}
  TDbSqliteBlobStream = class(TInterfacedObject, IDbBlobStream)
  private
    FHandle: TSqliteHandle;
    FBlob: TSqliteBlob;    { nil = 已关闭 }
    FSize: Int64;
    FPos: Int64;
  public
    constructor Create(AHandle: TSqliteHandle; const ATable, AColumn: string;
      const ARowId: Int64; const AReadWrite: Boolean);
    destructor Destroy; override;
    function Read(ABuf: PByte; ACount: SizeUInt): SizeUInt;
    procedure Write(ABuf: PByte; ACount: SizeUInt);
    function Seek(AOffset: Int64; AOrigin: TDbSeekOrigin): Int64;
    function Size: Int64;
  end;

procedure RaiseSqliteAsDb(const AE: ESqliteError);
var
  LCategory: TDbErrorCategory;
  LConstraint: TDbConstraintKind;
begin
  ClassifySqlite(AE.ErrorCode, AE.ExtendedErrorCode, LCategory, LConstraint);
  raise EDbError.CreateFullSqlite(AE.ErrorCode, AE.ExtendedErrorCode,
    LCategory, LConstraint, AE.Message);
end;

function SqliteCategoryOf(const AE: ESqliteError): TDbErrorCategory;
var
  LConstraint: TDbConstraintKind;
begin
  { 观测钩子（V3-B3）用：抛前取归一类目，与 RaiseSqliteAsDb 同表 }
  ClassifySqlite(AE.ErrorCode, AE.ExtendedErrorCode, Result, LConstraint);
end;

{ blob I/O 结果码检查：从原生句柄取诊断并走统一错误模型。
  注意必须单次直接构造并 raise——若先建 ESqliteError 再转抛 EDbError，
  手工创建的临时异常对象会因异常对象非引用计数而泄漏（实证）。 }
procedure BlobCheck(AHandle: TSqliteHandle; ARC: Integer); inline;
var
  LCategory: TDbErrorCategory;
  LConstraint: TDbConstraintKind;
begin
  if ARC = SQLITE_OK then
    Exit;
  ClassifySqlite(ARC, sqlite3_extended_errcode(AHandle),
    LCategory, LConstraint);
  raise EDbError.CreateFullSqlite(ARC, sqlite3_extended_errcode(AHandle),
    LCategory, LConstraint, string(AnsiString(sqlite3_errmsg(AHandle))));
end;

function MapColumnType(const ASqliteType: Integer): TDbColumnType;
begin
  case ASqliteType of
    SQLITE_INTEGER: Result := dbcInteger;
    SQLITE_FLOAT:   Result := dbcFloat;
    SQLITE_TEXT:    Result := dbcText;
    SQLITE_BLOB:    Result := dbcBlob;
  else
    Result := dbcNull;
  end;
end;

type
  TDbSqliteQuery = class(TInterfacedObject, IDbQuery)
  private
    FHome: ISqliteStmtHome;   { 归还通道；nil = 无缓存直通路径 }
    FSql: string;             { 回插键 = 原始 SQL 文本 }
    FQuery: TSqliteQuery;
    { 观测钩子（V3-B3）：nil = 无枢纽；FEmitted = 本执行周期已发
      OnQuery（首 Step 计时，同周期后续 Step 不再发）}
    FTrace: TDbTraceHub;
    FEmitted: Boolean;
  public
    constructor Create(const AHome: ISqliteStmtHome; const ASql: string;
      AQuery: TSqliteQuery; ATrace: TDbTraceHub);    { 取得语句所有权 }
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

  TDbSqliteConnection = class(TInterfacedObject, IDbConnection, IDbTxControl,
    IDbSavepointControl, IDbBatchExecutor, IDbStmtCacheControl,
    IDbRowBlobControl, IDbCapabilities, IDbTraceControl, ISqliteStmtHome,
    IDbCancelControl)
  private
    FDb: TSqliteDb;
    { V3-B6 取消标志：0 = 无取消；1 = RequestCancel 已请求。原子访问
      （跨线程写、progress handler 在 sqlite 工作线程读）。 }
    FCancelFlag: Integer;
    { 空闲预编译语句池：键 = 原始 SQL，借出即移除（同 SQL 并发活动
      查询各持独立实例），归还回插；LRU 只管空闲驱逐。
      nil = 缓存关闭直通。单连接单逻辑线程（CONTRACT §2.1），
      无需并发防护。 }
    FCache: ISqliteStmtCache;
    { 观测钩子枢纽（V3-B3）：监听器存取/摘要/计时/分发统一委托 }
    FTrace: TDbTraceHub;
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

    { IDbTxControl：委托 db.sqlite.tx（嵌套计数 + autocommit 守卫） }
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

    { ISqliteStmtHome：查询析构的归还通道（实现区接口，单元内可见） }
    procedure ReturnStmt(const ASql: string; AStmt: TSqliteQuery);

    { IDbRowBlobControl：行内 blob 单元流（INC-8） }
    function OpenRowBlob(const ATable, AColumn: string;
      const ARowId: Int64; const AReadWrite: Boolean): IDbBlobStream;

    { IDbCancelControl（V3-B6）：db.async 取消映射面。
      FCancelFlag 由任意线程经 RequestCancel 原子置位；progress
      handler（Arm 期间安装）读到非零即中断在途 step。 }
    function ArmCancel: Boolean;
    procedure DisarmCancel;
    procedure RequestCancel;
  end;

{ ---- TSqliteStmtHolder ---- }

constructor TSqliteStmtHolder.Create(AStmt: TSqliteQuery);
begin
  inherited Create;
  FStmt := AStmt;
end;

destructor TSqliteStmtHolder.Destroy;
begin
  FStmt.Free;                          { 未 Detach 的空闲语句在此关闭 }
  inherited Destroy;
end;

function TSqliteStmtHolder.Detach: TSqliteQuery;
begin
  Result := FStmt;
  FStmt := nil;                        { 所有权移交借出方 }
end;

{ ---- TDbSqliteBlobStream ---- }

constructor TDbSqliteBlobStream.Create(AHandle: TSqliteHandle;
  const ATable, AColumn: string; const ARowId: Int64;
  const AReadWrite: Boolean);
var
  LFlags: Integer;
begin
  inherited Create;
  FHandle := AHandle;
  if AReadWrite then
    LFlags := SQLITE_OPEN_READWRITE
  else
    LFlags := SQLITE_OPEN_READONLY;
  BlobCheck(FHandle, sqlite3_blob_open(FHandle, 'main',
    PAnsiChar(AnsiString(ATable)), PAnsiChar(AnsiString(AColumn)),
    ARowId, LFlags, FBlob));
  FSize := sqlite3_blob_bytes(FBlob);
  FPos := 0;
end;

destructor TDbSqliteBlobStream.Destroy;
begin
  if FBlob <> nil then
  begin
    sqlite3_blob_close(FBlob);         { 接口释放即关闭；析构内不抛 }
    FBlob := nil;
  end;
  inherited Destroy;
end;

function TDbSqliteBlobStream.Read(ABuf: PByte; ACount: SizeUInt): SizeUInt;
var
  N: SizeUInt;
begin
  Result := 0;
  if FPos >= FSize then
    Exit;                              { EOF }
  N := SizeUInt(FSize - FPos);        { 可读余量 }
  if ACount < N then
    N := ACount;
  if N > SizeUInt(MaxInt) then
    N := SizeUInt(MaxInt);             { 原生 API 单次 32 位上限 }
  BlobCheck(FHandle, sqlite3_blob_read(FBlob, ABuf, Integer(N), FPos));
  Inc(FPos, N);
  Result := N;
end;

procedure TDbSqliteBlobStream.Write(ABuf: PByte; ACount: SizeUInt);
var
  N: SizeUInt;
begin
  if FPos + Int64(ACount) > FSize then
    raise EDbError.CreateSimple(dbkSqlite,
      'blob write beyond end of fixed cell (reserve via zeroblob(N))');
  N := ACount;
  if N > SizeUInt(MaxInt) then
    N := SizeUInt(MaxInt);
  BlobCheck(FHandle, sqlite3_blob_write(FBlob, ABuf, Integer(N), FPos));
  Inc(FPos, N);
end;

function TDbSqliteBlobStream.Seek(AOffset: Int64;
  AOrigin: TDbSeekOrigin): Int64;
var
  NP: Int64;
begin
  // 事前兜底缺省（未来扩枚举时防御）；三分支显式全覆盖——原写法的
  // else 分支在枚举全覆盖下静态不可达（FPC 6018）
  NP := AOffset;
  case AOrigin of
    dsoBegin:   NP := AOffset;
    dsoCurrent: NP := FPos + AOffset;
    dsoEnd:     NP := FSize + AOffset;
  end;
  if (NP < 0) or (NP > FSize) then
    raise EDbError.CreateSimple(dbkSqlite,
      'blob seek out of range [0..' + IntToStr(FSize) + ']');
  FPos := NP;
  Result := FPos;
end;

function TDbSqliteBlobStream.Size: Int64;
begin
  Result := FSize;
end;

{ ---- TDbSqliteQuery ---- }

constructor TDbSqliteQuery.Create(const AHome: ISqliteStmtHome;
  const ASql: string; AQuery: TSqliteQuery; ATrace: TDbTraceHub);
begin
  inherited Create;
  FHome := AHome;
  FSql := ASql;
  FQuery := AQuery;
  FTrace := ATrace;
  FEmitted := False;
end;

destructor TDbSqliteQuery.Destroy;
begin
  if (FHome <> nil) and (FQuery <> nil) then
    FHome.ReturnStmt(FSql, FQuery)     { 归还回插（Reset+ClearBindings 在通道内） }
  else
    FQuery.Free;                       { 兜底：无通道即直接释放 }
  FQuery := nil;
  inherited Destroy;
end;

procedure TDbSqliteQuery.BindText(AIndex: Integer; const AValue: string);
begin
  try
    FQuery.BindText(AIndex, AValue);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

procedure TDbSqliteQuery.BindInt64(AIndex: Integer; const AValue: Int64);
begin
  try
    FQuery.BindInt64(AIndex, AValue);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

procedure TDbSqliteQuery.BindDouble(AIndex: Integer; const AValue: Double);
begin
  try
    FQuery.BindDouble(AIndex, AValue);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

procedure TDbSqliteQuery.BindBlob(AIndex: Integer; const AValue: TBytes);
begin
  try
    FQuery.BindBlob(AIndex, AValue);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

procedure TDbSqliteQuery.BindNull(AIndex: Integer);
begin
  try
    FQuery.BindNull(AIndex);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.Step: Boolean;
var
  LT0: QWord;
  LTimed: Boolean;
begin
  { 观测窗口 = 本执行周期首个 Step（绑定+执行+首行），见 §2.12 }
  LT0 := 0;
  LTimed := (FTrace <> nil) and (not FEmitted) and FTrace.BeginOp(LT0);
  try
    Result := FQuery.Step;
    if LTimed then
    begin
      FEmitted := True;
      FTrace.NotifyQuery(LT0, FSql);
    end;
  except
    on E: EDbError do
    begin
      if LTimed then
        FTrace.NotifyError(E.Category, FSql);
      raise;
    end;
  end;
end;

procedure TDbSqliteQuery.Reset;
begin
  FEmitted := False;   { 重执行周期重新计时 }
  try
    FQuery.Reset;
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.ColumnCount: Integer;
begin
  try
    Result := FQuery.ColumnCount;
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.ColumnName(AIndex: Integer): string;
begin
  try
    Result := FQuery.ColumnName(AIndex);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.ColumnType(AIndex: Integer): TDbColumnType;
var
  LT: Integer;
  LDecl: string;
begin
  try
    { 四层规则：无声明（表达式/聚合）→ 行值类型；有声明且值为 NULL →
      dbcNull（行级信号，Is* 契约）；声明含 BOOL → dbcBool（INC-6，
      亲和规则把 BOOLEAN 归 INTEGER 前的显式拦截）；否则声明亲和
      （静态、空结果集可读） }
    LDecl := FQuery.ColumnDeclaredTypeName(AIndex);
    if ScanFindSubstringCI(PChar(LDecl), Length(LDecl), 'BOOL', 4) >= 0 then
    begin
      if FQuery.ColumnType(AIndex) = SQLITE_NULL then
        Exit(dbcNull);
      Exit(dbcBool);
    end;
    LT := FQuery.ColumnDeclaredType(AIndex);
    if LT < 0 then
      LT := FQuery.ColumnType(AIndex)
    else if FQuery.ColumnType(AIndex) = SQLITE_NULL then
      LT := SQLITE_NULL;
    Result := MapColumnType(LT);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.IsNull(AIndex: Integer): Boolean;
begin
  try
    { 判空必须用行值类型，不能用声明亲和 }
    Result := FQuery.ColumnType(AIndex) = SQLITE_NULL;
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.GetInt64(AIndex: Integer): Int64;
begin
  try
    Result := FQuery.GetInt64(AIndex);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.GetDouble(AIndex: Integer): Double;
begin
  try
    Result := FQuery.GetDouble(AIndex);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.GetText(AIndex: Integer): string;
begin
  try
    Result := FQuery.GetText(AIndex);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

function TDbSqliteQuery.GetBlob(AIndex: Integer): TBytes;
begin
  try
    Result := FQuery.GetBlob(AIndex);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
end;

{ ---- TDbSqliteConnection ---- }

constructor TDbSqliteConnection.Create(ADb: TSqliteDb;
  const AStmtCacheCapacity: Integer);
begin
  inherited Create;
  FDb := ADb;
  if AStmtCacheCapacity > 0 then
    FCache := specialize TLruCache<string, ISqliteStmtHolder>.Create(
      SizeUInt(AStmtCacheCapacity));
  FTrace := TDbTraceHub.Create;
  { OnAcquire 由 SetListener 挂载时补发（§2.12），ctor 不预发 }
end;

destructor TDbSqliteConnection.Destroy;
begin
  DisarmCancel;                        { handler 指向本对象，先于 close 卸载 }
  FTrace.NotifyRelease;   { OnRelease = 连接关闭 }
  FreeAndNil(FTrace);
  FCache := nil;                       { Clear：空闲 holder 全部释放 }
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
  if FCache <> nil then
  begin
    { 借出即移除：Get 取引用并更新热度，Remove 放缓存侧的手——
      同 SQL 的第二个活动查询必然 miss，各持独立实例（嵌套安全） }
    if FCache.Get(ASql, Holder) then
    begin
      FCache.Remove(ASql);
      Stmt := Holder.Detach;
      Holder := nil;
    end;
  end;
  if Stmt = nil then
  begin
    try
      Stmt := FDb.Query(ASql);         { miss / 直通路径 }
    except
      on E: ESqliteError do RaiseSqliteAsDb(E);
    end;
  end;
  Result := TDbSqliteQuery.Create(Self, ASql, Stmt, FTrace);
end;

function TDbSqliteConnection.Query(const ASql: string;
  const AOptions: TDbExecOptions): IDbQuery;
begin
  { TimeoutMs advisory 忽略（INC-7 同款诚实登记）}
  Result := Query(ASql);
end;

{ ---- ISqliteStmtHome ---- }

procedure TDbSqliteConnection.ReturnStmt(const ASql: string; AStmt: TSqliteQuery);
begin
  if AStmt = nil then
    Exit;
  if FCache <> nil then
  begin
    try
      AStmt.Reset;                     { 复位执行状态 }
      AStmt.ClearBindings;             { 清绑定：下次借出从干净状态开始 }
    except
      on E: ESqliteError do
      begin
        { 复位失败 = 状态不可信：弃置不回池 }
        AStmt.Free;
        Exit;
      end;
    end;
    FCache.Put(ASql, TSqliteStmtHolder.Create(AStmt));
    { 容量满时 Put 驱逐 LRU：被驱逐 holder 析构即释放其语句 }
  end
  else
    AStmt.Free;
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

function TDbSqliteConnection.ProductName: string;
begin
  Result := 'SQLite';
end;

function TDbSqliteConnection.ProductVersion: string;
begin
  Result := string(AnsiString(sqlite3_libversion));
end;

function TDbSqliteConnection.SupportsSavepoints: Boolean;
begin
  Result := True;
end;

function TDbSqliteConnection.SupportsBatchExecutor: Boolean;
begin
  Result := True;
end;

function TDbSqliteConnection.SupportsStmtCacheControl: Boolean;
begin
  Result := True;
end;

function TDbSqliteConnection.SupportsLargeObjects: Boolean;
begin
  Result := False;   { cell 模型走 IDbRowBlobControl，无 lo_* 等价面 }
end;

function TDbSqliteConnection.SupportsArrayBinding: Boolean;
begin
  Result := False;   { v1 未实现参数级批量绑定（诚实契约） }
end;

{ ---- IDbCancelControl（V3-B6）---- }

{ progress handler 桩：探测连接的原子取消标志（非零 = 中断）。
  sqlite 在执行线程回调；RequestCancel 可从任意线程写标志。 }
function SqliteCancelProbe(AUser: Pointer): Integer; cdecl;
begin
  Result := Ord(atomic_load(PInteger(AUser)^, mo_acquire) <> 0);
end;

function TDbSqliteConnection.ArmCancel: Boolean;
begin
  FCancelFlag := 0;
  sqlite3_progress_handler(FDb.Handle, 10000,
    @SqliteCancelProbe, @FCancelFlag);
  Result := True;
end;

procedure TDbSqliteConnection.DisarmCancel;
begin
  atomic_exchange(FCancelFlag, 0, mo_acq_rel);
  sqlite3_progress_handler(FDb.Handle, 0, nil, nil);
end;

procedure TDbSqliteConnection.RequestCancel;
begin
  { 线程安全：仅原子置位；handler 未武装时置位无害（Arm 会先清零，
    但消费方须保证 Arm→在途→RequestCancel→Disarm 的窗口纪律，见
    db.intf 注记）。已武装时下一次 VM 计数到期即中断。 }
  atomic_exchange(FCancelFlag, 1, mo_acq_rel);
end;

function TDbSqliteConnection.SupportsNativeBool: Boolean;
begin
  Result := False;   { 声明亲和模拟（含 BOOL 声明的列），非原生类型 }
end;

function TDbSqliteConnection.SupportsMultiStatementExec: Boolean;
begin
  Result := True;    { sqlite3_exec 语义原生多语句 }
end;

function TDbSqliteConnection.SupportsStatementTimeout: Boolean;
begin
  Result := False;   { busy_timeout 是锁等待上限；语句超时被诚实忽略 }
end;

function TDbSqliteConnection.CaseSensitiveIdentifiers: Boolean;
begin
  Result := True;    { 保留声明形式（§2.6） }
end;

function TDbSqliteConnection.MaxPlaceholders: Integer;
begin
  { SQLITE_MAX_VARIABLE_NUMBER 跨版本保守下界：999 自古保证；
    libsqlite3 ≥3.32 实际默认 32766。消费方按 ≤999 编码全后端安全。 }
  Result := 999;
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

procedure TDbSqliteConnection.BeginTxn(const AImmediate: Boolean);
begin
  try
    nextpas.core.db.sqlite.tx.BeginTxn(FDb, AImmediate);
  except
    on E: ESqliteTxError do
      raise EDbError.CreateSimple(dbkSqlite, E.Message);
  end;
end;

procedure TDbSqliteConnection.CommitTxn;
begin
  try
    nextpas.core.db.sqlite.tx.CommitTxn(FDb);
  except
    on E: ESqliteTxError do
      raise EDbError.CreateSimple(dbkSqlite, E.Message);
  end;
end;

procedure TDbSqliteConnection.RollbackTxn;
begin
  try
    nextpas.core.db.sqlite.tx.RollbackTxn(FDb);
  except
    on E: ESqliteTxError do
      raise EDbError.CreateSimple(dbkSqlite, E.Message);
  end;
end;

function TDbSqliteConnection.InTransaction: Boolean;
begin
  Result := nextpas.core.db.sqlite.tx.InTransaction(FDb);
end;

function TDbSqliteConnection.TxDepth: Integer;
begin
  Result := nextpas.core.db.sqlite.tx.TxDepth(FDb);
end;

procedure TDbSqliteConnection.Savepoint(const AName: string);
begin
  ValidateDbSavepointName(dbkSqlite, AName);
  Exec('SAVEPOINT ' + AName);
end;

procedure TDbSqliteConnection.RollbackTo(const AName: string);
begin
  ValidateDbSavepointName(dbkSqlite, AName);
  Exec('ROLLBACK TO ' + AName);
end;

procedure TDbSqliteConnection.ReleaseTo(const AName: string);
begin
  ValidateDbSavepointName(dbkSqlite, AName);
  Exec('RELEASE ' + AName);
end;

procedure TDbSqliteConnection.ExecuteBatch(const ASteps: TDbSqlSteps);
var
  K: Integer;
begin
  if Length(ASteps) = 0 then
    Exit;
  { 本地引擎无往返税：逐条执行保留精确到步骤的错误定位。
    计数器为捕获变量，FPC 禁其用于 for，故用 while }
  WithTransaction(Self, procedure
  begin
    K := 0;
    while K <= High(ASteps) do
    begin
      Exec(ASteps[K]);
      Inc(K);
    end;
  end);
end;

{ ---- 工厂 ---- }

{ C5 全不设置形态：旧重载经此保持 sqlite 原生缺省，行为零变化 }
function SqlitePragmasUnset: TDbSqlitePragmas;
begin
  Result.JournalMode := sjmUnset;
  Result.Synchronous := sysUnset;
  Result.ForeignKeys := fkUnset;
  Result.CacheSize := 0;      { 0 = 不设置 }
  Result.MmapSize := -1;      { <0 = 不设置；0 = 显式禁用 mmap }
end;

{ C5：应用调优 PRAGMA。journal_mode 应用后回读校验——文件系统不支持
  WAL 时 sqlite 静默保持原模式，此处 fail-closed 抛 decNotSupported，
  绝不静默降级（静默降级 = 消费方误信读写并发安全）。:memory: 库
  过滤 journal_mode（WAL 对内存库无意义，其余 PRAGMA 照常）。 }
procedure ApplySqlitePragmas(Db: TSqliteDb; const APath: string;
  const AP: TDbSqlitePragmas);
const
  JStr: array[TDbSqliteJournalMode] of string = ('', 'delete', 'truncate',
    'persist', 'memory', 'wal');
  SStr: array[TDbSqliteSync] of string = ('', 'off', 'normal', 'full');
var
  LMem: Boolean;
  LQ: TSqliteQuery;
  LGot: string;
begin
  LMem := (APath = ':memory:') or
    (ScanFindSubstringCI(PChar(APath), Length(APath),
      'mode=memory', 11) >= 0);
  if (AP.JournalMode <> sjmUnset) and (not LMem) then
  begin
    Db.Exec('PRAGMA journal_mode = ' + JStr[AP.JournalMode]);
    LGot := '';
    LQ := Db.Query('PRAGMA journal_mode');
    try
      if LQ.Step then
        LGot := LowerCase(LQ.GetText(0));
    finally
      LQ.Free;
    end;
    if LGot <> JStr[AP.JournalMode] then
      raise EDbError.CreateFullSqlite(SQLITE_ERROR, SQLITE_ERROR,
        decNotSupported, dckNone,
        'sqlite journal_mode=' + JStr[AP.JournalMode] +
        ' rejected (got "' + LGot + '"); filesystem may not support WAL');
  end;
  case AP.Synchronous of
    sysOff, sysNormal, sysFull:
      Db.Exec('PRAGMA synchronous = ' + SStr[AP.Synchronous]);
  end;
  case AP.ForeignKeys of
    fkOff: Db.Exec('PRAGMA foreign_keys = off');
    fkOn:  Db.Exec('PRAGMA foreign_keys = on');
  end;
  if AP.CacheSize <> 0 then
    Db.Exec('PRAGMA cache_size = ' + IntToStr(AP.CacheSize));
  if AP.MmapSize >= 0 then
    Db.Exec('PRAGMA mmap_size = ' + IntToStr(AP.MmapSize));
end;

function InternalConnectSqlite(const APath: string;
  const AOptions: TDbConnectOptions; const APragmas: TDbSqlitePragmas;
  const AStmtCacheCapacity: Integer): IDbConnection;
var
  Db: TSqliteDb;
begin
  try
    Db := TSqliteDb.Create(APath);
    { 锁等待上限（INC-7）：非语句执行超时，语义见 db.base 注释 }
    if AOptions.BusyTimeoutMs > 0 then
      Db.Exec('PRAGMA busy_timeout = ' + IntToStr(AOptions.BusyTimeoutMs));
    ApplySqlitePragmas(Db, APath, APragmas);
  except
    on E: ESqliteError do RaiseSqliteAsDb(E);
  end;
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
