unit nextpas.core.db.pool;

{** @desc 通用连接池（INC-1，V2-S4）。对任意后端的 IDbConnection 池化，
       后端特化经连接工厂闭包注入，池体不懂方言。

    - 所有权即归还：Acquire 返回代理接口；消费方释放引用即自动归还
      （D3 的池化形态，零手工 Free）。致命错误可先经
      IDbPooledHandle.Discard 弃置，防坏连接复用。
    - 生命周期安全：池核心态经 IDbPoolCore 引用计数保活——门面 Free
      只停止出借并清空空闲队列，在途代理归还时直接销毁底层连接，
      最后一个代理释放后核心态自毁。持租约时 Free 池无悬垂。
    - 单写者：Writer 槽位独立信号量（1）形式化单写连接。
    - 等待队列：读槽位由 sync.semaphore 支撑；AcquireTimeoutMs>0 排队
      等待，=0 耗尽立即抛 decCapacity（同 v1 sqlite 薄池行为）。
    - 无看门狗线程（诚实同步模型）：空闲超时/寿命在 Acquire 取出检查点
      惰性执行（含空闲队列冷端清扫）；0 = 不限。
    - 泄漏检测（V3-C3）：LeakDetectionThresholdMs>0 时，持有超阈值的
      在途租约在任意检查点（Acquire/归还）被扫描入账（Warned 一次，
      检测不干预所有权）；报告只在安全点冲刷——Acquire/Writer 入口
      或显式 FlushDiagnostics。归还路径发生在代理析构链内，只入账
      不触发用户代码（实测本工具链上析构链内调闭包回调会破坏堆，
      属硬边界而非风格选择）。DebugAcquireStack 开启时报告附调用栈
      线索。默认全关零成本。
    - 预热：MinConnections 在 Create 内建满，失败 fail-fast 抛原建连错。
    - 线程模型：池方法线程安全（互斥锁保护簿记；信号量阻塞不持锁；
      接口引用计数为原子操作）。连接本身仍遵循 CONTRACT §2.1 一连接
      一逻辑线程。池为单生命周期：Close/Free 后不可复用，需重建。 体积注记：本单元约834行超 800 行软阈值，内聚性强（池单职责），暂不拆分，拆分预留见 roadmap。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.conv,
  nextpas.core.base,
  nextpas.core.sync,
  nextpas.core.time,
  nextpas.core.db.base,
  nextpas.core.db.intf;

type
  { 连接工厂闭包：后端特化唯一入口 }
  TDbConnectFunc = reference to function: IDbConnection;

  { 泄漏报告通道（V3-C3）：nil = 写 StdErr。回调在池调用线程同步
    执行，实现内不得再进本池（死锁自担）。 }
  TDbPoolLeakEvent = reference to procedure(const AReport: string);

  { 单次检查点收集到的泄漏报告串集 }
  TDbPoolLeakReports = array of string;

  TDbPoolPolicy = record
    MaxReadConnections: Integer;   { 读连接硬上限 }
    AcquireTimeoutMs: Integer;     { >0 耗尽排队等待；=0 立即抛 }
    ValidateOnAcquire: Boolean;    { 取出前 SELECT 1 探活 }
    MaxLifetimeSec: Integer;       { 连接最长寿命（建连起算）；0 = 不限 }
    IdleTimeoutSec: Integer;       { 空闲超时回收；0 = 不限 }
    MinConnections: Integer;       { 预热下限（Create 即建满） }
    { ---- V3-C3 HikariCP 三招（尾部追加，纯增量）---- }
    { 泄漏检测阈值：租约持有超过阈值后在检查点扫描入账（Warned 一次），
      报告于安全点冲刷；0 = 关（默认）。诚实模型：无看门狗线程——
      发现依赖下一次池活动或显式 FlushDiagnostics；检测到 ≠ 回收，
      租约所有权仍归持有者。 }
    LeakDetectionThresholdMs: Integer;
    { 报告通道：nil = 写 StdErr。回调在池调用线程同步执行，
      实现内不得再进本池（死锁自担）。 }
    OnLeakDetected: TDbPoolLeakEvent;
    { 获取栈采样（debug 开关）：Acquire 捕获 ≤16 帧原始代码地址，
      泄漏报告附带作定位线索；默认 False 零成本。地址行经
      BackTraceStrFunc 格式化，符号解析取决于链接器调试信息。 }
    DebugAcquireStack: Boolean;
    class function Default: TDbPoolPolicy; static;
  end;

  {** 归还句柄能力（池代理实现）：捕获数据库错误后调用 Discard 弃置
      当前底层连接，释放引用时不回池而直接关闭。 *}
  IDbPooledHandle = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE006}']
    procedure Discard;
  end;

  {** 池核心态接口：引用计数所有权的载体。每个在途代理持强引用，
      核心态存活到最后一个代理归还；门面提前 Free 时由代理侧自然
      排空。（内部扩展缝：门面只是薄壳，核心态可独立驱动） *}
  IDbPoolCore = interface
    ['{8F2E7A64-9C1D-4B0E-A3D7-51C2B90FE007}']
    function AcquireRead: IDbConnection;
    function AcquireWriter: IDbConnection;
    procedure Shutdown;
    function Policy: TDbPoolPolicy;
    procedure ReturnProxy(AProxy: TObject);
    { 安全点冲刷：扫描到期租约并入账，随后在锁外触发已积压报告。
      只允许在非析构链上下文调用（见单元头注泄漏检测条目）。 }
    procedure FlushDiagnostics;
  end;

  { 门面：策略校验与预热在 Create 内完成；其余全数委派核心态 }
  TDbPool = class
  private
    FCore: IDbPoolCore;
  public
    constructor Create(const AConnect: TDbConnectFunc;
      const APolicy: TDbPoolPolicy);
    destructor Destroy; override;

    { 读连接：受 MaxReadConnections/等待队列/惰性回收/探活策略约束 }
    function Acquire: IDbConnection;
    { 单写连接：全池仅一条，被占用期间再次 Writer 按 AcquireTimeoutMs
      排队或抛 decCapacity }
    function Writer: IDbConnection;
    { 关闭并清空空闲连接与写连接，停止出借；已取出的代理归还时直接
      销毁其底层连接（排空语义，不等待）。幂等。 }
    procedure Close;
    function Policy: TDbPoolPolicy;
    { 泄漏检测安全点：扫描入账并冲刷积压报告（同 Acquire 入口语义）。
      供应用在确定性时机排空诊断，不必等下一次池活动。 }
    procedure FlushDiagnostics;
  end;

implementation

type
  { 池代理：核心面转发内层；能力面经 QueryInterface 委托真实连接；
    析构即归还（或弃置销毁）。持核心态强引用。 }
  TPooledConn = class(TInterfacedObject, IDbConnection, IDbPooledHandle)
  private
    FCore: IDbPoolCore;
    FInner: IDbConnection;
    FIsWriter: Boolean;
    FCreatedTick: QWord;
    FDiscarded: Boolean;
    FReturned: Boolean;
  public
    constructor Create(const ACore: IDbPoolCore; const AInner: IDbConnection;
      const AIsWriter: Boolean; const ACreatedTick: QWord);
    destructor Destroy; override;

    function QueryInterface(constref IID: TGUID; out Obj): HResult; cdecl;

    function Kind: TDbKind;
    procedure Exec(const ASql: string); overload;
    procedure Exec(const ASql: string;
      const AOptions: TDbExecOptions); overload;
    function Query(const ASql: string): IDbQuery; overload;
    function Query(const ASql: string;
      const AOptions: TDbExecOptions): IDbQuery; overload;
    function Changes: Int64;
    function Raw: Pointer;

    procedure Discard;
  end;

  { 核心态：簿记、槽位信号量、空闲队列与惰性回收的全部状态 }
  TDbPoolCore = class(TInterfacedObject, IDbPoolCore)
  private type
    TIdleEntry = record
      Conn: IDbConnection;
      CreatedTick: QWord;
      ReturnedTick: QWord;
    end;
    { 在途租约簿记（V3-C3）：Obj 是弱引用指针（簿记用，不加接口
      计数——代理自身由消费方引用计数保活）；Frames 仅 debug 采样
      开启时有效。记录无托管字段，SetLength 裸搬移安全。注意 Obj
      必须存代理对象基址（TPooledConn 实例指针），不是接口指针：
      本工具链上 COM 接口指针相对对象基址有偏移，两者不可混比。 }
    TOutstanding = record
      Obj: TObject;
      Tick: QWord;
      Warned: Boolean;
      IsWriter: Boolean;
      Frames: array[0..15] of CodePointer;
      FrameCount: Integer;
    end;
  private
    { 空闲队列用编译器托管的动态数组而非泛型容器：条目含接口字段，
      SetLength/元素赋值走托管复制（正确增减引用计数）；泛型 deque
      对记录内接口按裸内存搬移，入队不持引用 → 悬垂指针（实证）。
      尾端 = LIFO 热端。 }
    FPolicy: TDbPoolPolicy;
    FConnect: TDbConnectFunc;
    FLock: INativeMutex;
    FReadSlots: ISemaphore;
    FWriterSlot: ISemaphore;
    FIdle: array of TIdleEntry;
    FWriterConn: IDbConnection;
    FWriterCreatedTick: QWord;
    FClosed: Boolean;
    FOutstanding: array of TOutstanding;
    { 已入账待冲刷的泄漏报告（托管串数组，锁保护） }
    FPending: TDbPoolLeakReports;
    function NowTick: QWord; inline;
    function OpenFresh(out ACreatedTick: QWord): IDbConnection;
    function Stale(const ACreatedTick, ANow: QWord): Boolean;
    function IdleStale(const AEntry: TIdleEntry; const ANow: QWord): Boolean;
    procedure IdlePush(const AEntry: TIdleEntry); inline;
    function IdlePop(var AEntry: TIdleEntry): Boolean; inline;
    procedure EvictColdStaleLocked(const ANow: QWord);
    function TakeUsableIdleLocked(out ACreatedTick: QWord): IDbConnection;
    { ---- V3-C3 泄漏检测（Scan/Take 要求持锁调用）---- }
    procedure RegisterLeaseLocked(AObj: TObject; const ATick: QWord;
      const AIsWriter: Boolean; const AFrames: PCodePointer;
      const ACount: Integer);
    procedure UnregisterLeaseLocked(AObj: TObject);
    { 扫描到期租约：标记 Warned 并把报告串追加进 FPending。
      任何检查点都可调用（含归还路径），绝不触发用户代码。 }
    procedure ScanDueLeasesLocked(const ANow: QWord);
    { 取走全部积压报告（换出置空） }
    procedure TakePendingLocked(out AReports: TDbPoolLeakReports);
    { 锁外逐条触发报告通道 }
    procedure FireLeakReports(const AReports: TDbPoolLeakReports);
    { 安全点全流程：扫描入账 + 取走积压 + 锁外冲刷。
      仅限 Acquire/Writer 入口与显式 FlushDiagnostics 调用。 }
    procedure FlushLeaksSafePoint;
  public
    constructor Create(const AConnect: TDbConnectFunc;
      const APolicy: TDbPoolPolicy);
    destructor Destroy; override;
    function AcquireRead: IDbConnection;
    function AcquireWriter: IDbConnection;
    procedure Shutdown;
    function Policy: TDbPoolPolicy;
    procedure ReturnProxy(AProxy: TObject);
    procedure FlushDiagnostics;
  end;

class function TDbPoolPolicy.Default: TDbPoolPolicy;
begin
  { 逐字段显式赋值：类方法名 Default 与 System.Default 内建同形参
    调用冲突，且托管字段（闭包）显式置 nil 更直白 }
  Result.MaxReadConnections := 4;
  Result.AcquireTimeoutMs := 5000;
  Result.ValidateOnAcquire := False;
  Result.MaxLifetimeSec := 0;
  Result.IdleTimeoutSec := 60;
  Result.MinConnections := 0;
  { V3-C3：三招全部默认关 }
  Result.LeakDetectionThresholdMs := 0;
  Result.OnLeakDetected := nil;
  Result.DebugAcquireStack := False;
end;

{ ---- TPooledConn ---- }

constructor TPooledConn.Create(const ACore: IDbPoolCore;
  const AInner: IDbConnection; const AIsWriter: Boolean;
  const ACreatedTick: QWord);
begin
  inherited Create;
  FCore := ACore;
  FInner := AInner;
  FIsWriter := AIsWriter;
  FCreatedTick := ACreatedTick;
end;

destructor TPooledConn.Destroy;
begin
  if not FReturned then
  begin
    FReturned := True;
    if (FCore <> nil) and not FDiscarded then
      FCore.ReturnProxy(Self);           { 释放即归还 }
  end;
  FInner := nil;                       { 引用归零 = 底层连接关闭 }
  inherited Destroy;
end;

function TPooledConn.QueryInterface(constref IID: TGUID; out Obj): HResult; cdecl;
begin
  { 核心面/归还句柄由代理自答；其余能力（TxControl/Savepoint/
    BatchExecutor）委托内层真实连接——探测语义与直连一致 }
  if GetInterface(IID, Obj) then
    Exit(S_OK);
  Result := FInner.QueryInterface(IID, Obj);
end;

function TPooledConn.Kind: TDbKind;
begin
  Result := FInner.Kind;
end;

procedure TPooledConn.Exec(const ASql: string);
begin
  FInner.Exec(ASql);
end;

procedure TPooledConn.Exec(const ASql: string;
  const AOptions: TDbExecOptions);
begin
  FInner.Exec(ASql, AOptions);
end;

function TPooledConn.Query(const ASql: string): IDbQuery;
begin
  Result := FInner.Query(ASql);
end;

function TPooledConn.Query(const ASql: string;
  const AOptions: TDbExecOptions): IDbQuery;
begin
  Result := FInner.Query(ASql, AOptions);
end;

function TPooledConn.Changes: Int64;
begin
  Result := FInner.Changes;
end;

function TPooledConn.Raw: Pointer;
begin
  Result := FInner.Raw;
end;

procedure TPooledConn.Discard;
begin
  FDiscarded := True;
end;

{ ---- TDbPoolCore ---- }

constructor TDbPoolCore.Create(const AConnect: TDbConnectFunc;
  const APolicy: TDbPoolPolicy);
var
  I: Integer;
  E: TIdleEntry;
begin
  inherited Create;
  if AConnect = nil then
    raise EDbError.CreateSimple(dbkUnknown, 'pool: nil connect factory');
  if APolicy.MaxReadConnections < 1 then
    raise EDbError.CreateSimple(dbkUnknown,
      'pool: MaxReadConnections must be >= 1');
  if APolicy.MinConnections > APolicy.MaxReadConnections then
    raise EDbError.CreateSimple(dbkUnknown,
      'pool: MinConnections exceeds MaxReadConnections');
  FConnect := AConnect;
  FPolicy := APolicy;
  FLock := Mutex;
  FReadSlots := Semaphore(APolicy.MaxReadConnections);
  FWriterSlot := Semaphore(1);

  { 预热 fail-fast：任一建连失败原样上抛，不给半可用池 }
  for I := 1 to APolicy.MinConnections do
  begin
    E.Conn := OpenFresh(E.CreatedTick);
    E.ReturnedTick := E.CreatedTick;
    IdlePush(E);
  end;
end;

destructor TDbPoolCore.Destroy;
begin
  Shutdown;
  inherited Destroy;
end;

function TDbPoolCore.Policy: TDbPoolPolicy;
begin
  Result := FPolicy;
end;

function TDbPoolCore.NowTick: QWord;
begin
  Result := GetTickCount64;
end;

function TDbPoolCore.OpenFresh(out ACreatedTick: QWord): IDbConnection;
begin
  ACreatedTick := NowTick;
  Result := FConnect();
  if Result = nil then
    raise EDbError.CreateSimple(dbkUnknown,
      'pool: connect factory returned nil');
end;

function TDbPoolCore.Stale(const ACreatedTick, ANow: QWord): Boolean;
begin
  Result := (FPolicy.MaxLifetimeSec > 0) and
    (ANow >= ACreatedTick + QWord(FPolicy.MaxLifetimeSec) * 1000);
end;

function TDbPoolCore.IdleStale(const AEntry: TIdleEntry;
  const ANow: QWord): Boolean;
begin
  if Stale(AEntry.CreatedTick, ANow) then
    Exit(True);
  Result := (FPolicy.IdleTimeoutSec > 0) and
    (ANow >= AEntry.ReturnedTick + QWord(FPolicy.IdleTimeoutSec) * 1000);
end;

{ 冷端清扫：空闲队列最旧端只会在下次 Acquire 被动清理（惰性契约），
  规避看门狗线程。O(1) 移除 = 与尾端交换后截断（队列顺序无外部观察者） }
procedure TDbPoolCore.EvictColdStaleLocked(const ANow: QWord);
var
  E: TIdleEntry;
begin
  while (Length(FIdle) > 0) and IdleStale(FIdle[0], ANow) do
  begin
    E := FIdle[0];
    FIdle[0] := Default(TIdleEntry);   { 显式清引用再截断 }
    FIdle[High(FIdle)] := E;
    SetLength(FIdle, Length(FIdle) - 1);
  end;
end;

procedure TDbPoolCore.IdlePush(const AEntry: TIdleEntry); inline;
var
  N: Integer;
begin
  { 先扩容并落一个空位，再按托管赋值写入：接口字段正确 +1 }
  N := Length(FIdle);
  SetLength(FIdle, N + 1);
  FIdle[N] := Default(TIdleEntry);
  FIdle[N] := AEntry;
end;

function TDbPoolCore.IdlePop(var AEntry: TIdleEntry): Boolean; inline;
var
  N: Integer;
begin
  N := Length(FIdle);
  if N = 0 then
    Exit(False);
  AEntry := FIdle[N - 1];              { 托管读出：+1 归调用方 }
  FIdle[N - 1] := Default(TIdleEntry); { 队列侧 -1 }
  SetLength(FIdle, N - 1);
  Result := True;
end;

function TDbPoolCore.TakeUsableIdleLocked(
  out ACreatedTick: QWord): IDbConnection;
var
  E: TIdleEntry;
  ANow: QWord;
begin
  ANow := NowTick;
  { LIFO 热端优先复用热连接 }
  while IdlePop(E) do
  begin
    if IdleStale(E, ANow) then
      Continue;                        { 陈旧：E 出栈即引用清零，连接关闭 }
    if FPolicy.ValidateOnAcquire then
    begin
      try
        E.Conn.Exec('SELECT 1');
      except
        Continue;                      { 探活失败：弃置换新 }
      end;
    end;
    ACreatedTick := E.CreatedTick;
    Exit(E.Conn);
  end;
  Result := nil;
end;

{ ---- V3-C3 泄漏检测 ---- }

procedure TDbPoolCore.RegisterLeaseLocked(AObj: TObject; const ATick: QWord;
  const AIsWriter: Boolean; const AFrames: PCodePointer;
  const ACount: Integer);
var
  N, K: Integer;
begin
  N := Length(FOutstanding);
  SetLength(FOutstanding, N + 1);
  FOutstanding[N].Obj := AObj;
  FOutstanding[N].Tick := ATick;
  FOutstanding[N].Warned := False;
  FOutstanding[N].IsWriter := AIsWriter;
  FOutstanding[N].FrameCount := 0;
  FillChar(FOutstanding[N].Frames, SizeOf(FOutstanding[N].Frames), 0);
  if (AFrames <> nil) and (ACount > 0) then
  begin
    K := ACount;
    if K > Length(FOutstanding[N].Frames) then
      K := Length(FOutstanding[N].Frames);
    Move(AFrames^, FOutstanding[N].Frames, SizeOf(CodePointer) * K);
    FOutstanding[N].FrameCount := K;
  end;
end;

procedure TDbPoolCore.UnregisterLeaseLocked(AObj: TObject);
var
  I, LLast: Integer;
begin
  for I := High(FOutstanding) downto 0 do
    if FOutstanding[I].Obj = AObj then
    begin
      LLast := High(FOutstanding);
      FOutstanding[I] := FOutstanding[LLast];   { 无托管字段，交换安全 }
      SetLength(FOutstanding, LLast);
      Exit;
    end;
end;

procedure TDbPoolCore.ScanDueLeasesLocked(const ANow: QWord);
var
  I, J, N: Integer;
  LHeldMs: QWord;
  LRole: string;
begin
  if FPolicy.LeakDetectionThresholdMs <= 0 then
    Exit;
  for I := 0 to High(FOutstanding) do
  begin
    if FOutstanding[I].Warned then
      Continue;
    LHeldMs := ANow - FOutstanding[I].Tick;
    if LHeldMs < QWord(FPolicy.LeakDetectionThresholdMs) then
      Continue;
    FOutstanding[I].Warned := True;
    if FOutstanding[I].IsWriter then
      LRole := 'writer'
    else
      LRole := 'read';
    N := Length(FPending);
    SetLength(FPending, N + 1);
    FPending[N] := Format(
      'pool: lease leak suspected — held %dms (threshold %dms), %s lease',
      [LHeldMs, FPolicy.LeakDetectionThresholdMs, LRole]);
    if FOutstanding[I].FrameCount > 0 then
      for J := 0 to FOutstanding[I].FrameCount - 1 do
      begin
        N := Length(FPending);
        SetLength(FPending, N + 1);
        FPending[N] :=
          '  ' + BackTraceStrFunc(FOutstanding[I].Frames[J]);
      end;
  end;
end;

procedure TDbPoolCore.TakePendingLocked(out AReports: TDbPoolLeakReports);
begin
  AReports := FPending;
  FPending := nil;
end;

procedure TDbPoolCore.FireLeakReports(const AReports: TDbPoolLeakReports);
var
  I: Integer;
  LEvent: TDbPoolLeakEvent;
begin
  LEvent := FPolicy.OnLeakDetected;
  for I := 0 to High(AReports) do
  begin
    if Assigned(LEvent) then
      LEvent(AReports[I])
    else
      WriteLn(StdErr, AReports[I]);
  end;
end;

procedure TDbPoolCore.FlushLeaksSafePoint;
var
  LReports: TDbPoolLeakReports;
begin
  if FPolicy.LeakDetectionThresholdMs <= 0 then
    Exit;
  LReports := nil;
  FLock.Acquire;
  try
    ScanDueLeasesLocked(NowTick);
    TakePendingLocked(LReports);
  finally
    FLock.Release;
  end;
  { 锁外触发用户代码：回调可重入池方法而不死锁 }
  if Length(LReports) > 0 then
    FireLeakReports(LReports);
end;

procedure TDbPoolCore.FlushDiagnostics;
begin
  FlushLeaksSafePoint;
end;

procedure TDbPoolCore.ReturnProxy(AProxy: TObject);
var
  P: TPooledConn;
  E: TIdleEntry;
  IsWriter: Boolean;
begin
  P := TPooledConn(AProxy);
  IsWriter := P.FIsWriter;
  FLock.Acquire;
  try
    UnregisterLeaseLocked(P);            { V3-C3：出账 }
    if (not FClosed) and (not P.FDiscarded) then
    begin
      E.Conn := P.FInner;
      E.CreatedTick := P.FCreatedTick; { 绝对寿命跨租期累计 }
      E.ReturnedTick := NowTick;
      IdlePush(E);                     { LIFO 热端 }
    end;
    { FClosed/Discarded：不入队，引用随析构链自然关闭 }
    { 归还也是检查点——但只扫描入账，绝不在析构链内触发用户代码 }
    ScanDueLeasesLocked(NowTick);
  finally
    FLock.Release;
  end;
  if IsWriter then
    FWriterSlot.Release
  else
    FReadSlots.Release;
end;

function TDbPoolCore.AcquireRead: IDbConnection;
var
  Inner: IDbConnection;
  CreatedTick: QWord;
  LFrames: array[0..15] of CodePointer;
  LFrameCount: Integer;
  LProxy: TPooledConn;
begin
  if FClosed then
    raise EDbError.CreateSimple(dbkUnknown, 'pool: closed');

  { V3-C3 泄漏检查点（安全点）：先于等待——池耗尽排队时也能发现既有
    租约泄漏，并顺带冲刷归还路径积压的报告 }
  FlushLeaksSafePoint;

  if FPolicy.AcquireTimeoutMs > 0 then
  begin
    if not FReadSlots.TryAcquireTimeout(
         Int64(FPolicy.AcquireTimeoutMs) * 1000000) then
      raise EDbError.CreateSimple(dbkUnknown,
        'pool: read connections exhausted (timeout ' +
          IntToStr(FPolicy.AcquireTimeoutMs) + 'ms)');
  end
  else
  begin
    if not FReadSlots.TryAcquire then
      raise EDbError.CreateSimple(dbkUnknown,
        'pool: read connections exhausted');
  end;

  try
    FLock.Acquire;
    try
      EvictColdStaleLocked(NowTick);
      Inner := TakeUsableIdleLocked(CreatedTick);
      if Inner = nil then
        Inner := OpenFresh(CreatedTick);
    finally
      FLock.Release;
    end;
  except
    FReadSlots.Release;
    raise;
  end;

  LFrameCount := 0;
  FillChar(LFrames, SizeOf(LFrames), 0);
  if FPolicy.DebugAcquireStack then
    LFrameCount := CaptureBacktrace(0, Length(LFrames), @LFrames[0]);
  LProxy := TPooledConn.Create(Self, Inner, False, CreatedTick);
  Result := LProxy;
  FLock.Acquire;
  try
    { 登记对象基址（非接口指针——两者相差固定偏移，混比必失配） }
    RegisterLeaseLocked(LProxy, NowTick, False,
      @LFrames[0], LFrameCount);
  finally
    FLock.Release;
  end;
end;

function TDbPoolCore.AcquireWriter: IDbConnection;
var
  NeedFresh: Boolean;
  CreatedTick: QWord;
  LFrames: array[0..15] of CodePointer;
  LFrameCount: Integer;
  LProxy: TPooledConn;
begin
  if FClosed then
    raise EDbError.CreateSimple(dbkUnknown, 'pool: closed');

  { V3-C3 泄漏检查点（安全点）：写槽被占时也能发现既有租约泄漏
    （含上一任写租约未释放的场景） }
  FlushLeaksSafePoint;

  if FPolicy.AcquireTimeoutMs > 0 then
  begin
    if not FWriterSlot.TryAcquireTimeout(
         Int64(FPolicy.AcquireTimeoutMs) * 1000000) then
      raise EDbError.CreateSimple(dbkUnknown,
        'pool: writer occupied (timeout ' +
          IntToStr(FPolicy.AcquireTimeoutMs) + 'ms)');
  end
  else
  begin
    if not FWriterSlot.TryAcquire then
      raise EDbError.CreateSimple(dbkUnknown, 'pool: writer occupied');
  end;

  try
    FLock.Acquire;
    try
      NeedFresh := (FWriterConn = nil) or
        Stale(FWriterCreatedTick, NowTick);
      if NeedFresh then
      begin
        FWriterConn := nil;
        FWriterConn := OpenFresh(CreatedTick);
        FWriterCreatedTick := CreatedTick;
      end
      else
        CreatedTick := FWriterCreatedTick;
    finally
      FLock.Release;
    end;
  except
    FWriterSlot.Release;
    raise;
  end;

  LFrameCount := 0;
  FillChar(LFrames, SizeOf(LFrames), 0);
  if FPolicy.DebugAcquireStack then
    LFrameCount := CaptureBacktrace(0, Length(LFrames), @LFrames[0]);
  LProxy := TPooledConn.Create(Self, FWriterConn, True, CreatedTick);
  Result := LProxy;
  FLock.Acquire;
  try
    RegisterLeaseLocked(LProxy, NowTick, True,
      @LFrames[0], LFrameCount);
  finally
    FLock.Release;
  end;
end;

procedure TDbPoolCore.Shutdown;
var
  E: TIdleEntry;
begin
  { 构造器早期失败（如 nil 工厂检查）时 FLock 尚未创建：
    析构链会调本方法，须容忍半构造状态 }
  if FLock = nil then
  begin
    FClosed := True;
    Exit;
  end;
  FLock.Acquire;
  try
    FClosed := True;
    while IdlePop(E) do
      E.Conn := nil;                   { 引用清零即关闭 }
    FWriterConn := nil;
  finally
    FLock.Release;
  end;
end;

{ ---- TDbPool 门面 ---- }

constructor TDbPool.Create(const AConnect: TDbConnectFunc;
  const APolicy: TDbPoolPolicy);
begin
  inherited Create;
  FCore := TDbPoolCore.Create(AConnect, APolicy);
end;

destructor TDbPool.Destroy;
begin
  if FCore <> nil then
  begin
    FCore.Shutdown;                    { 停止出借并清空空闲；在途代理归还时排空 }
    FCore := nil;                      { 仅弃门面引用：核心态由在途代理保活 }
  end;
  inherited Destroy;
end;

function TDbPool.Acquire: IDbConnection;
begin
  Result := FCore.AcquireRead;
end;

function TDbPool.Writer: IDbConnection;
begin
  Result := FCore.AcquireWriter;
end;

procedure TDbPool.Close;
begin
  FCore.Shutdown;
end;

function TDbPool.Policy: TDbPoolPolicy;
begin
  Result := FCore.Policy;
end;

procedure TDbPool.FlushDiagnostics;
begin
  FCore.FlushDiagnostics;
end;

end.
