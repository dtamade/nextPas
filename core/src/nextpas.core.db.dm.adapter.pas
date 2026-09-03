unit nextpas.core.db.dm.adapter;

{** @desc IDbConnection 的达梦 DM8 DPI 适配器门面（L3 适配层）。
       聚合分治子模块：common（占位符/DSN/诊断单源零锁）、query（语句/参数/存取单缓冲）、
       conn（连接/事务/缓存/能力探针）、synthetic（合成代理 surrounding cost 单源，独立 helper）。
       能力与契约见 CONTRACT §2.21，事务/池语义同 sqlite/pg 家族。
       依赖收敛：占位符扫描直连 text.sqlscan L1 单源（db.sqlscan 已物理删除），DSN 解析复用 text.kv。
       层级：L3 适配门面（严格下向 L2 dm.* + L1 text/bytes/collections/sync，无上向；四件套聚合，
       单向依赖 common/query/conn/synthetic 无环，门面 <200 行软阈内，编译增量与 I-Cache 压力分治）。
       性能：DSN 纯函数零锁（去 GDmDsnLock 热点读锁争用，池 Acquire 零额外锁），
       DmSyntheticTranslate/DsnToDpiConnStr 单次 Move 单分配零拷贝 inline 薄转发至 synthetic 单源，bytes.ops 单源 BYTES_OPS_SINGLE_SOURCE。
       批量 10k 经 DmSyntheticDpiProxyReuse(var ADest)/DmSyntheticBatchBuild 复用 ADest/Builder 预分配 amortized 1 堆分配（AnsiEnsureCapacity BytesCalcGrowCap doubling/TBufStringBuilder 预分配单源，10k 堆分配→1 次 amortized via BytesCalcGrowCap，inline 零拷贝，try..finally Done；单行 DmSyntheticDpiProxy/E2EProxy per-row 单分配历史债务已物理删除于门面（synthetic 单源 deprecated 仅内部兼容），批量仅 var ADest reuse amortized 1 alloc 防 heap churn 彻底收敛）。
       稳定性：纯转发无资源，所有权由 conn/query 托管，析构链不丢，Builder 复用 try..finally Done 不泄漏。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.capprobe,
  nextpas.core.db.dm.adapter.common,
  nextpas.core.db.dm.adapter.query,
  nextpas.core.db.dm.adapter.conn;

function ConnectDm(const ADsn: string): IDbConnection; overload;
function ConnectDm(const ADsn: string; const AOptions: TDbConnectOptions): IDbConnection; overload;
function ConnectDm(const ADsn: string; const AOptions: TDbConnectOptions; const AStmtCacheCapacity: Integer): IDbConnection; overload;

// DM 合成代理见 CONTRACT §2.21（门面薄转发至 synthetic 单源，零锁纯函数 inline，已抽独立 helper 单元 dm.adapter.synthetic）
// bulk reuse (heap churn fix 已收敛): 10k 行经 DmSyntheticDpiProxyReuse(var ADest)/DmSyntheticBatchBuild 复用 ADest/Builder 预分配 amortized 1 堆分配（10k heap→1 via BytesCalcGrowCap doubling，bytes.ops 单源 AnsiEnsureCapacity+AnsiSetLogicalLenNoRealloc+2×Move 零拷贝，单源于 synthetic；单行 DmSyntheticDpiProxy/E2EProxy per-row 单分配历史债务已物理删除于门面，synthetic 内部 deprecated 仅兼容，facade 零暴露，批量仅 var ADest reuse amortized 1 alloc 彻底收敛）
function DmSyntheticTranslate(const ASql: string): string; inline;
procedure DmSyntheticDpiProxyReuse(var ADest: AnsiString; const ASql: string; const AValue: string); overload;
procedure DmSyntheticDpiProxyReuseTranslated(var ADest: AnsiString; const LTranslated: string; const AValue: string); overload;
procedure DmSyntheticE2EProxyReuse(var ADest: AnsiString; const ASql: string; const AValue: string); overload;
procedure DmSyntheticE2EProxyReuseTranslated(var ADest: AnsiString; const LTranslated: string; const AValue: string); overload;
function DmSyntheticBatchBuild(const ASql: string; const AValues: array of string): AnsiString;
procedure DmSyntheticCacheClear; inline;
procedure DmSyntheticCacheInvalidate(const ASql: string); inline;
function DsnToDpiConnStr(const ADsn: string): AnsiString; inline;
function DmNativeDirectBench(const ASql: string): string; inline;

type
  TDbDmConnection = nextpas.core.db.dm.adapter.conn.TDbDmConnection;
  TDbDmQuery = nextpas.core.db.dm.adapter.query.TDbDmQuery;
  IDmStmtHolder = nextpas.core.db.dm.adapter.query.IDmStmtHolder;
  TDmStmtHolder = nextpas.core.db.dm.adapter.query.TDmStmtHolder;
  IDmStmtHome = nextpas.core.db.dm.adapter.query.IDmStmtHome;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.db.dm.base,
  nextpas.core.db.dm.ffi,
  nextpas.core.db.dm.loader,
  nextpas.core.db.dm.adapter.synthetic,
  nextpas.core.db.err;

{$IF not BYTES_OPS_SINGLE_SOURCE}
  {$FATAL 'bytes.ops single source drift: db.dm.adapter must reuse bytes.ops'}
{$IFEND}

function DmSyntheticTranslate(const ASql: string): string; inline;
begin
  Result := nextpas.core.db.dm.adapter.synthetic.DmSyntheticTranslate(ASql);
end;

procedure DmSyntheticDpiProxyReuse(var ADest: AnsiString; const ASql: string; const AValue: string);
begin
  nextpas.core.db.dm.adapter.synthetic.DmSyntheticDpiProxyReuse(ADest, ASql, AValue);
end;

procedure DmSyntheticDpiProxyReuseTranslated(var ADest: AnsiString; const LTranslated: string; const AValue: string);
begin
  nextpas.core.db.dm.adapter.synthetic.DmSyntheticDpiProxyReuseTranslated(ADest, LTranslated, AValue);
end;

procedure DmSyntheticE2EProxyReuse(var ADest: AnsiString; const ASql: string; const AValue: string);
begin
  nextpas.core.db.dm.adapter.synthetic.DmSyntheticE2EProxyReuse(ADest, ASql, AValue);
end;

procedure DmSyntheticE2EProxyReuseTranslated(var ADest: AnsiString; const LTranslated: string; const AValue: string);
begin
  nextpas.core.db.dm.adapter.synthetic.DmSyntheticE2EProxyReuseTranslated(ADest, LTranslated, AValue);
end;

function DmSyntheticBatchBuild(const ASql: string; const AValues: array of string): AnsiString;
begin
  Result := nextpas.core.db.dm.adapter.synthetic.DmSyntheticBatchBuild(ASql, AValues);
end;

procedure DmSyntheticCacheClear; inline;
begin
  nextpas.core.db.dm.adapter.synthetic.DmSyntheticCacheClear;
end;

procedure DmSyntheticCacheInvalidate(const ASql: string); inline;
begin
  nextpas.core.db.dm.adapter.synthetic.DmSyntheticCacheInvalidate(ASql);
end;

function DsnToDpiConnStr(const ADsn: string): AnsiString; inline;
begin
  // perf: inline thin forward to common pure function zero-lock single Move, avoids GDmDsnLock contention on pool Acquire hot path
  Result := nextpas.core.db.dm.adapter.common.DsnToDpiConnStr(ADsn);
end;

function DmNativeDirectBench(const ASql: string): string; inline;
begin
  Result := nextpas.core.db.dm.adapter.synthetic.DmNativeDirectBench(ASql);
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
  nextpas.core.db.dm.adapter.common.ValidateDmDsn(ADsn);
  if not DmEnsureLoaded then
    raise NewDbErrorDm(-2003, '08001', 'DM DPI library not found: ' + DmLibraryName, decConnection, dckNone);
  Env := nil; Conn := nil;
  LCode := dpi_create_env(@Env);
  nextpas.core.db.dm.adapter.common.CheckDpi(LCode, nil, DPI_HANDLE_ENV);
  try
    LCode := dpi_create_conn(Env, @Conn);
    nextpas.core.db.dm.adapter.common.CheckDpi(LCode, Env, DPI_HANDLE_ENV);
    LConnStr := DsnToDpiConnStr(ADsn);
    LCode := dpi_connect(Conn, PAnsiChar(LConnStr));
    if LCode <> DPI_SUCCESS then
    begin
      nextpas.core.db.dm.adapter.common.CheckDpi(LCode, Conn, DPI_HANDLE_DBC);
    end;
    Result := nextpas.core.db.dm.adapter.conn.TDbDmConnection.Create(Env, Conn, AStmtCacheCapacity);
    Env := nil; Conn := nil;
  except
    if Conn <> nil then dpi_free_conn(Conn);
    if Env <> nil then dpi_free_env(Env);
    raise;
  end;
end;

end.
