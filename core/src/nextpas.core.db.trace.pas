unit nextpas.core.db.trace;

{** @desc 观测钩子共享枢纽（V3-B3）。四后端适配器各持一个
       TDbTraceHub 实例，统一承担：监听器存取（互斥保护）、SQL 摘要
       折叠截断、单调时钟取点与毫秒换算、事件分发。

       层级 L2 观测：契约面仅 base/intf（不依赖具体后端），设施依赖
       L1 nextpas.core.sync（INativeMutex）与 L0
       nextpas.core.platform.time（单调时钟）；L0-L3 单向，零上向
       （CONTRACT §1/§2.12 与 trace.md 单源，L2文档不变量已对齐实现）。

       硬边界纪律：回调绝不在持锁状态下调用——先在锁内快照接口引用，
       解锁后调用（C3 析构链教训的推广：内部锁范围内不得触碰用户
       代码）。默认零成本：无监听器时 BeginOp 返回 False，适配器不
       取时钟不做摘要。

       单调时钟用 nextpas.core.platform.time（core 自有设施，不引
       FPC RTL——§7.1 账本方向）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync,
  nextpas.core.db.base,
  nextpas.core.db.intf;

const
  { SQL 摘要截断上限（字符）：防日志爆炸；参数值从不进入摘要 }
  DB_TRACE_SQL_SUMMARY_MAX = 512;

type
  TDbTraceHub = class
  private
    FLock: INativeMutex;
    FListener: IDbTraceListener;
    function SnapshotListener: IDbTraceListener;
  public
    constructor Create;

    { 控制面（IDbTraceControl 委托目标）。挂载非 nil 监听器时在
      锁外同步补发一次 OnAcquire——"本连接已建立"事实对迟挂载的
      监听器可观测（CONTRACT §2.12），Acquire/Release 由此 1:1 配对。 }
    procedure SetListener(const AListener: IDbTraceListener);
    function Active: Boolean; inline;

    { 计时入口：有活动监听器时返回 True 并写回当前单调时钟读数
      （纳秒）；无监听器零成本返回 False。 }
    function BeginOp(out AStartNs: QWord): Boolean; inline;

    { 事件分发（AStartNs 为 BeginOp 写回的读数）}
    procedure NotifyRelease;
    procedure NotifyQuery(const AStartNs: QWord; const ASql: string);
    procedure NotifyError(const ACategory: TDbErrorCategory;
      const ASql: string);
  end;

{ SQL 摘要：折叠连续空白为单空格并截断到 DB_TRACE_SQL_SUMMARY_MAX。
  纯函数，门禁离线可测。 }
function DbTraceSqlSummary(const ASql: string): string;

{ ---- 门面探测薄转发单源（L2 owner，facade 纯聚合） ---- }
{ perf: inline 薄转发，bytes.ops 单源零拷贝，接口引用计数自动归还，nil 安全 }
function DbProbeTraceControl(const AConn: IDbConnection): IDbTraceControl; inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.platform.time;

function TDbTraceHub.SnapshotListener: IDbTraceListener;
begin
  FLock.Acquire;
  try
    Result := FListener;
  finally
    FLock.Release;
  end;
end;

constructor TDbTraceHub.Create;
begin
  inherited Create;
  FLock := nextpas.core.sync.Mutex;
end;

procedure TDbTraceHub.SetListener(const AListener: IDbTraceListener);
begin
  FLock.Acquire;
  try
    FListener := AListener;
  finally
    FLock.Release;
  end;
  { 挂载即补发 OnAcquire（§2.12）：锁外回调——C3 硬边界 }
  if AListener <> nil then
    AListener.OnAcquire;
end;

function TDbTraceHub.Active: Boolean; inline;
begin
  // perf: 零成本 fast path——无监听器时不加锁直接返回，避免 Exec/Query/Step 热路径每次 FLock.Acquire；Pointer Peek 零拷贝无 AddRef，有监听器时再 SnapshotListener 加锁快照（C3 硬边界：锁内快照锁外回调）
  if Pointer(FListener) = nil then
    Exit(False);
  Result := SnapshotListener <> nil;
end;

function TDbTraceHub.BeginOp(out AStartNs: QWord): Boolean; inline;
begin
  AStartNs := 0;
  if not Active then
    Exit(False);
  AStartNs := QWord(platform_monotonic_ns);
  Result := True;
end;

procedure TDbTraceHub.NotifyRelease;
var
  L: IDbTraceListener;
begin
  L := SnapshotListener;
  if L <> nil then
    L.OnRelease;
end;

procedure TDbTraceHub.NotifyQuery(const AStartNs: QWord;
  const ASql: string);
var
  L: IDbTraceListener;
  LElapsedMs: Int64;
begin
  L := SnapshotListener;
  if L = nil then
    Exit;
  LElapsedMs := (Int64(QWord(platform_monotonic_ns)) - Int64(AStartNs))
    div 1000000;
  if LElapsedMs < 0 then
    LElapsedMs := 0;   { 时钟回退防御 }
  L.OnQuery(LElapsedMs, DbTraceSqlSummary(ASql));
end;

procedure TDbTraceHub.NotifyError(const ACategory: TDbErrorCategory;
  const ASql: string);
var
  L: IDbTraceListener;
begin
  L := SnapshotListener;
  if L <> nil then
    L.OnError(ACategory, DbTraceSqlSummary(ASql));
end;

function DbProbeTraceControl(const AConn: IDbConnection): IDbTraceControl; inline;
begin
  // perf: inline 薄转发，零拷贝接口引用计数自动归还，nil 安全；bytes.ops 单源由 trace 单元继承
  Result := nil;
  if AConn = nil then Exit;
  Supports(AConn, IDbTraceControl, Result);
end;

function DbTraceSqlSummary(const ASql: string): string;
var
  LB: array of Char;
  LCap, LN, LI: Integer;
  C, P: Char;
begin
  { 连续空白（#9/#10/#13/#32）折叠为单空格 + 截断；无正则依赖。
    输出不可能超过输入长度，缓冲按截断上限封顶。 }
  if Length(ASql) < DB_TRACE_SQL_SUMMARY_MAX then
    LCap := Length(ASql)
  else
    LCap := DB_TRACE_SQL_SUMMARY_MAX;
  SetLength(LB, LCap);
  LN := 0;
  P := #0;
  for LI := 1 to Length(ASql) do
  begin
    C := ASql[LI];
    if (C = ' ') or (C = #9) or (C = #10) or (C = #13) then
    begin
      if (P <> ' ') and (P <> #0) and (LN < LCap) then
      begin
        Inc(LN);
        LB[LN - 1] := ' ';
        P := ' ';
      end;
    end
    else
    begin
      if LN >= LCap then
        Break;   { 截断后无需继续扫描 }
      Inc(LN);
      LB[LN - 1] := C;
      P := C;
    end;
  end;
  { 尾部若因折叠停在空格则去掉 }
  while (LN > 0) and (LB[LN - 1] = ' ') do
    Dec(LN);
  SetLength(Result, LN);
  if LN > 0 then
    nextpas.core.bytes.ops.BytesCopy(@Result[1], @LB[0], SizeUInt(LN) * SizeOf(Char)); // perf: inline single Move via bytes.ops.BytesCopy single source (zero-copy, INV-5)
end;

end.
