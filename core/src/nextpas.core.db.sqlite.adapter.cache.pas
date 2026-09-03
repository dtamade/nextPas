unit nextpas.core.db.sqlite.adapter.cache;

{** @desc SQLite 语句缓存分治（L3 实现子模块，INC-3/C5）。
       LRU 空闲语句池（键 = 原始 SQL）+ Holder/Home 通道 + Query 包装。
       Query 持 Home 强引用（连接先于查询释放仍可安全回插，无环——
       连接只缓存空闲语句，不引用在途查询）；归还路径 Reset+ClearBindings。
       层级：L3 适配子模块（严格下向 L2 sqlite.conn/base + L1 collections/text，
       同层单向依赖 observe，不反向；被 adapter 单向依赖）。
       性能：LRU 单遍命中、声明亲和整行缓存零扫描零分配（首次整行物化每列
       IsBool/DeclType 复用 conn 层零拷贝 SIMD 缓存，50k 点查零重复判定）、
       HoldAnsi 单分配零拷贝桥接，inline 薄转发，复用 bytes.ops 单源。
       稳定性：Holder 接口托管（驱逐/Clear 自动释放），Detach 移交所有权；
       Return 路径 fail-closed 弃置不可信语句。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.sqlite.conn,
  nextpas.core.db.sqlite.base,
  nextpas.core.db.trace,
  nextpas.core.collections.lrucache.intf;

type
  {** 空闲语句持有者：LRU 的值形态。用接口而非裸对象指针——驱逐/
    Clear/缓存析构路径由编译器引用计数释放底层 stmt（S4 同款托管
    纪律，杜绝容器裸搬移泄漏）。 *}
  ISqliteStmtHolder = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE008}']
    { 所有权移交：返回底层语句并清空持有（未被 Detach 的语句在
      holder 析构时释放 = 驱逐/清空路径） }
    function Detach: TSqliteQuery;
    procedure Attach(AStmt: TSqliteQuery);
    function GetStmt: TSqliteQuery;
  end;

  TSqliteStmtHolder = class(TInterfacedObject, ISqliteStmtHolder)
  private
    FStmt: TSqliteQuery;
  public
    constructor Create(AStmt: TSqliteQuery);   { 取得所有权 }
    destructor Destroy; override;
    function Detach: TSqliteQuery;
    procedure Attach(AStmt: TSqliteQuery);
    function GetStmt: TSqliteQuery;
  end;

  {** 查询→连接的归还通道。查询持本接口强引用：即使消费方先释放
    连接接口再释放查询，连接仍存活可安全回插（对抗序安全；无环——
    连接只缓存空闲语句，从不引用在途查询）。 *}
  ISqliteStmtHome = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE009}']
    procedure ReturnStmt(const ASql: string; AStmt: TSqliteQuery);
    procedure ReturnHolder(const ASql: string; const AHolder: ISqliteStmtHolder);
  end;

  ISqliteStmtCache = specialize ILruCache<string, ISqliteStmtHolder>;

function CreateSqliteStmtCache(const ACapacity: Integer): ISqliteStmtCache;
{ 键哈希/相等：内容寻址零拷贝（500k ops 下消除指针哈希误命中，FNV-1a 单遍零分配，命中时 refcount 浅比对快路径） }
function SqliteStmtCacheHash(const AKey: string; AData: Pointer): UInt64; inline;
function SqliteStmtCacheEquals(const ALeft, ARight: string; AData: Pointer): Boolean; inline;

  TDbSqliteQuery = class(TInterfacedObject, IDbQuery)
  private
    FHome: ISqliteStmtHome;   { 归还通道；nil = 无缓存直通路径 }
    FSql: string;             { 回插键 = 原始 SQL 文本 }
    FQuery: TSqliteQuery;
    FHolder: ISqliteStmtHolder; { 命中时携带的可复用 holder，归还时零分配回插 }
    { 观测钩子（V3-B3）：nil = 无枢纽；FEmitted = 本执行周期已发
      OnQuery（首 Step 计时，同周期后续 Step 不再发）}
    FTrace: TDbTraceHub;
    FEmitted: Boolean;
    { 声明亲和整行缓存：首次 ColumnType 整行物化每列 IsBool/DeclType（复用
      conn 层 per-column 已缓存的零扫描结果），后续 50k 点查热路径仅单次
      行值类型 + 缓存亲和判定，零重复 ColumnDeclaredIsBool/DeclType 分支 }
    FColAffinity: array of record
      Ready: Boolean;
      IsBool: Boolean;
      DeclType: Integer;
    end;
    procedure EnsureColAffinity; inline;
  public
    constructor Create(const AHome: ISqliteStmtHome; const ASql: string;
      AQuery: TSqliteQuery; ATrace: TDbTraceHub); overload;    { 取得语句所有权 }
    constructor Create(const AHome: ISqliteStmtHome; const ASql: string;
      AQuery: TSqliteQuery; ATrace: TDbTraceHub; const AHolder: ISqliteStmtHolder); overload;
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

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.collections.lrucache,
  nextpas.core.db.sqlite.adapter.observe;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: sqlite.adapter.cache must reuse bytes.ops'}
{$IFEND}

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

procedure TSqliteStmtHolder.Attach(AStmt: TSqliteQuery);
begin
  FStmt := AStmt;
end;

function TSqliteStmtHolder.GetStmt: TSqliteQuery;
begin
  Result := FStmt;
end;

function SqliteStmtCacheHash(const AKey: string; AData: Pointer): UInt64; inline;
begin
  // perf: inline 零拷贝 FNV-1a 内容哈希（nextpas.core.base HashString 单源，bytes.ops 单源门禁），非指针哈希，单遍扫描零分配，适配 TLruCache 内容寻址
  Result := UInt64(HashString(AKey));
end;

function SqliteStmtCacheEquals(const ALeft, ARight: string; AData: Pointer): Boolean; inline;
begin
  // perf: inline 零拷贝内容比对（managed string refcount 浅比对快路径，命中时指针相等零扫描），适配 TLruCache
  Result := ALeft = ARight;
end;

function CreateSqliteStmtCache(const ACapacity: Integer): ISqliteStmtCache;
begin
  // perf: inline 零拷贝内容哈希 LRU（bytes.ops 单源，FNV-1a 单遍，TryTake 单哈希借出，Put 单哈希回插，零 Get+Remove 双哈希放大，500k ops 键拷贝减半）
  Result := specialize TLruCache<string, ISqliteStmtHolder>.Create(SizeUInt(ACapacity), nil, @SqliteStmtCacheHash, @SqliteStmtCacheEquals);
end;

{ ---- TDbSqliteQuery ---- }

constructor TDbSqliteQuery.Create(const AHome: ISqliteStmtHome;
  const ASql: string; AQuery: TSqliteQuery; ATrace: TDbTraceHub);
begin
  Create(AHome, ASql, AQuery, ATrace, nil);
end;

constructor TDbSqliteQuery.Create(const AHome: ISqliteStmtHome;
  const ASql: string; AQuery: TSqliteQuery; ATrace: TDbTraceHub;
  const AHolder: ISqliteStmtHolder);
begin
  inherited Create;
  FHome := AHome;
  FSql := ASql;
  FQuery := AQuery;
  FTrace := ATrace;
  FHolder := AHolder;
  FEmitted := False;
end;

destructor TDbSqliteQuery.Destroy;
begin
  if (FHome <> nil) and (FQuery <> nil) then
  begin
    if FHolder <> nil then
    begin
      // perf: hot hit path zero holder alloc — reuse borrowed holder (549k ops/s 点查零额外堆分配，LRU Put 仅节点分配)
      FHolder.Attach(FQuery);
      FQuery := nil;
      FHome.ReturnHolder(FSql, FHolder);
      FHolder := nil;
    end
    else
      FHome.ReturnStmt(FSql, FQuery)     { 归还回插（Reset+ClearBindings 在通道内） }
  end
  else
    FQuery.Free;                       { 兜底：无通道即直接释放 }
  FQuery := nil;
  FHolder := nil;
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

procedure TDbSqliteQuery.EnsureColAffinity; inline;
var
  LCnt, I: Integer;
  LIsBool: Boolean;
  LDecl: Integer;
begin
  // perf: inline 整行亲和缓存物化（复用 conn 层 PrefetchDeclAffinity 批量预取+GetDeclAffinity 单遍单fetch单扫 零拷贝 SIMD 缓存，双亲和单次物化，首行整行 O(N) 单遍批量预取摊还宽表首行可观 FFI 成本，50k 点查后续零重复 ColumnDeclaredIsBool/DeclType 分支，零分配；bytes.ops 单源，单次 ColumnCount 同步长度，inline 薄转发）
  LCnt := FQuery.ColumnCount;
  if Length(FColAffinity) <> LCnt then
    SetLength(FColAffinity, LCnt)
  else if (LCnt > 0) and FColAffinity[0].Ready and FColAffinity[LCnt - 1].Ready then
    Exit;
  // wide-table批量预取：首行一次性 FFI+亲和物化，减少 N 次分散 EnsureDeclAffinity 调用开销，单次 ColumnCount 同步+紧凑循环，缓存后零扫描零分配
  if LCnt > 0 then
    FQuery.PrefetchDeclAffinity;
  for I := 0 to LCnt - 1 do
    if not FColAffinity[I].Ready then
    begin
      FQuery.GetDeclAffinity(I, LIsBool, LDecl);
      FColAffinity[I].IsBool := LIsBool;
      FColAffinity[I].DeclType := LDecl;
      FColAffinity[I].Ready := True;
    end;
end;

function TDbSqliteQuery.ColumnType(AIndex: Integer): TDbColumnType;
var
  LRow, LDecl: Integer;
begin
  try
    { 四层规则（整行缓存版）：首行整行物化每列声明亲和（IsBool/DeclType，复用
      conn 层零扫描缓存），后续行仅单次行值类型检测 + 缓存命中分支；无声明
      → 行值类型；有声明且行值为 NULL → dbcNull（Is* 契约）；声明含 BOOL →
      dbcBool（INC-6 优先）；否则声明亲和（静态、空结果集可读）
      perf: inline EnsureColAffinity 整行缓存 + 单次 ColumnType 判空，点查
      50k 次场景列类型分支零重复判定、零扫描零分配（bytes.ops 单源） }
    EnsureColAffinity;
    LRow := FQuery.ColumnType(AIndex);
    if LRow = SQLITE_NULL then
      Exit(dbcNull);
    if (AIndex >= 0) and (AIndex < Length(FColAffinity)) then
    begin
      if FColAffinity[AIndex].IsBool then
        Exit(dbcBool);
      LDecl := FColAffinity[AIndex].DeclType;
      if LDecl < 0 then
        LDecl := LRow;
      Result := MapColumnType(LDecl);
    end
    else
    begin
      // 越界兜底（不经缓存，直通行值类型，避免异常掩盖）
      Result := MapColumnType(LRow);
    end;
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

end.
