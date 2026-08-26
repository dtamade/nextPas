unit nextpas.core.db.pg.listen;

{** @desc PostgreSQL LISTEN/NOTIFY 订阅会话（V3-B7，G9 收口）。

       形态：TPgListener 独占一条专用连接（构造时由 conninfo 私有建连，
       不暴露查询面——"LISTEN 会话不能跑普通查询"的诚实约束由结构
       保证，见 CONTRACT §2.18）。泵线程独占 PGconn：轮询
       PQconsumeInput → 逐条 PQnotifies（PQfreemem 成对）→ 投递进
       监听器内建有界记录队列；消费方 Receive 阻塞取用。

       底座全部来自 core 家族（不在本单元造平行宇宙）：
       - 线程运行时初始化：nextpas.core.thread.init（cthreads 正替）；
       - 泵线程：nextpas.core.thread.pool 单工池（1 worker 常驻循环）；
       - 互斥/事件：nextpas.core.sync；
       - 取消令牌：nextpas.core.async.cancellation（Token 属性外露，
         消费方取消树可挂子令牌；Cancel 即协同停泵）。
       投递面说明：路线图原案"async.channel 投递"落为内建有界记录
       队列——IAsyncChannel 是字节通道，托管串记录需手工扁平化/释放，
       且 db.async 已确立 thread.pool + core.sync 的家族线程惯例；
       偏差与理由入 CONTRACT §2.18。

       语义承诺（路线图 B7 行）：
       - at-most-once 如实上报：断线窗口内的通知不补发，GapCount
         记断线次数，不假装 at-least-once；
       - 重连自动重新 LISTEN：重连成功后按订阅快照逐通道重发 LISTEN；
       - 溢出保旧弃新：队列满丢弃最新并计 DroppedCount（顺序不打断）。 *}

{$I nextpas.core.settings.inc}

{$modeswitch functionreferences}
{$modeswitch anonymousfunctions}

interface

uses
  nextpas.core.thread.init,
  nextpas.core.db.base,
  nextpas.core.db.pg.base,
  nextpas.core.db.pg.conn,
  nextpas.core.async.cancellation,
  nextpas.core.sync.intf,
  nextpas.core.thread.intf,
  nextpas.core.thread.pool;

const
  { Receive 的无限等待哨兵（其余值 = 毫秒超时；0 = 非阻塞探测） }
  PG_LISTEN_INFINITE = Cardinal($FFFFFFFF);

  { 泵默认轮询节拍：通知延迟上界 ≈ 节拍 + 服务端 RTT（无 OS poller
    依赖的诚实折中；升级路径见 CONTRACT §2.18） }
  PG_LISTEN_DEFAULT_TICK_MS = 50;
  { 默认投递队列容量（条）；满后保旧弃新 }
  PG_LISTEN_DEFAULT_QUEUE_CAPACITY = 1024;

type
  {** 订阅会话。契约：
      - 独占专用连接：本类私有建连并持有，消费方不得复用该连接跑
        查询（结构上无查询面）。
      - Listen/Unlisten 客户端校验先行（[A-Za-z0-9_]、长度 ≤63——
        pg 标识符 NAMEDATALEN-1 上界），非法即抛 EDbError 不触网；
        合法命令异步应用到泵线程（典型 ≤1 节拍生效）。
      - Receive(ATimeoutMs) 阻塞至 ≥1 条或超时；一次带回全部积压
        （FIFO 保序）。泵停止且余量取尽后抛 EDbError（防消费者
        无限等）；停止前已入队的通知仍可取尽。
      - 断线自动重连（间隔 = 4×节拍），成功后自动重放订阅快照；
        断线窗口丢失如实计数不补发。重连建连在 conninfo 无
        connect_timeout 时追加 connect_timeout=2，防泵线程无限期
        阻塞拖死关停。
      - Token 取消即协同停泵；Destroy 同步收尾（先停泵再关连接，
        不留后台线程）。 *}
  TPgListener = class
  private type
    TListenCmdKind = (ckListen, ckUnlisten, ckUnlistenAll);
    TListenCmd = record
      Kind: TListenCmdKind;
      Channel: string;
    end;
    TListenCmdArray = array of TListenCmd;
  private
    FConnInfo: string;
    FTickMs: Cardinal;
    FCapacity: Integer;
    FConn: TPgConn;                 { 仅泵线程触碰；nil = 断线中 }
    FLk: ILock;
    FWake: IEvent;                  { 命令/停止/节拍唤醒源（自动复位） }
    FData: IEvent;                  { 投递队列非空信号（自动复位） }
    FPool: IThreadPool;
    FToken: IAsyncCancellationToken;
    FPumpAlive: Integer;            { 原子：1 = 泵在跑；0 = 已收尾 }
    FStopping: Integer;             { 原子：析构/取消置位 }
    { 以下均受 FLk 保护 }
    FCmds: TListenCmdArray;
    FChannels: array of string;     { 订阅快照（重连重放依据） }
    FRing: TDbPgNotificationArray;
    FHead: Integer;                 { 队首下标（环形） }
    FCount: Integer;
    FConnected: Boolean;
    FGapCount: Int64;
    FDropped: Int64;
    FBackendPid: Integer;           { -1 = 未知/断线 }
    FLastError: string;
    procedure ApplyCommand(const ACmd: TListenCmd);
    procedure TryReconnect;
    function TakeCommands: TListenCmdArray;
    procedure PumpLoop;
    procedure ConsumeAndDeliver;
    procedure MarkDisconnected(const ADiag: string);
    procedure EnqueueLocked(const AN: TDbPgNotification);
    function TakeAllNotifications: TDbPgNotificationArray;
    function ValidateChannel(const AChannel: string): string;
    procedure RequireAlive;
    procedure RecordErrorLocked(const ADiag: string);
    function GetConnected: Boolean;
    function GetGapCount: Int64;
    function GetDroppedCount: Int64;
    function GetBackendPid: Integer;
    function GetLastErrorText: string;
    function GetSubscribedChannels: TDbStringArray;
  public
    constructor Create(const AConnInfo: string); overload;
    constructor Create(const AConnInfo: string; const ATickMs: Cardinal;
      const AQueueCapacity: Integer); overload;
    destructor Destroy; override;

    procedure Listen(const AChannel: string);
    procedure Unlisten(const AChannel: string);
    procedure UnlistenAll;

    {** 阻塞取通知（见类注）。返回本次取到的全部积压（空数组 = 超时）。 *}
    function Receive(const ATimeoutMs: Cardinal): TDbPgNotificationArray;

    property Connected: Boolean read GetConnected;
    property GapCount: Int64 read GetGapCount;
    property DroppedCount: Int64 read GetDroppedCount;
    property BackendPid: Integer read GetBackendPid;
    property LastError: string read GetLastErrorText;
    property SubscribedChannels: TDbStringArray read GetSubscribedChannels;
    { 协同取消令牌：Cancel 即停泵（桥接唤醒事件）；可挂子令牌级联 }
    property Token: IAsyncCancellationToken read FToken;
  end;

{ 打开 LISTEN/NOTIFY 订阅会话（对齐 PgOpen 先例；失败抛 EDbError，
  内因 EPgError 诊断并入消息）。 }
function PgOpenListener(const AConnInfo: string): TPgListener;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.atomic,
  nextpas.core.text.conv,
  nextpas.core.platform,
  nextpas.core.exception,
  nextpas.core.sync.mutex,
  nextpas.core.sync.event,
  nextpas.core.db.pg.ffi;

const
  RECONNECT_TICK_FACTOR = 4;   { 重连尝试间隔 = 4 × 泵节拍 }
  RECONNECT_CONNECT_TIMEOUT_S = 2;

{ 取消桥（Token.Cancel）：惊动泵线程立即退出，不等下一节拍。
  生命周期：回调注册于构造器、令牌随监听器销毁——Self 全程存活。 }
procedure PgListenerStopBridge(AData: Pointer);
var
  LListener: TPgListener;
begin
  LListener := TPgListener(AData);
  if LListener <> nil then
    LListener.FWake.SetEvent;
end;

function PgNowMs: Int64;
begin
  Result := Int64(platform_monotonic_ns div 1000000);
end;

{ conninfo 是否已显式携带 connect_timeout 键。按"行首/空白 + 关键字
  + 紧随 ="的键位边界匹配（评审 n1）：口令等值内恰好含该子串不再
  误判。带引号含空格值的完整词法解析超出本面范围，此处为尽力扫描。 }
function ConnInfoHasTimeoutKey(const AInfo: string): Boolean;
const
  KEY = 'connect_timeout';
var
  I, J: Integer;
begin
  Result := False;
  for I := 1 to Length(AInfo) - Length(KEY) + 1 do
    if (AInfo[I] = 'c') and (Copy(AInfo, I, Length(KEY)) = KEY) then
      if (I = 1) or (AInfo[I - 1] in [' ', #9]) then
      begin
        J := I + Length(KEY);
        while (J <= Length(AInfo)) and (AInfo[J] = ' ') do
          Inc(J);
        if (J <= Length(AInfo)) and (AInfo[J] = '=') then
        begin
          Result := True;
          Exit;
        end;
      end;
end;

{ 无 connect_timeout 时追加护栏：防 PQconnectdb 在坏网络下无限阻塞
  拖死调用线程（首连）/泵线程与关停路径（重连）。首连与重连同款。 }
function ConnInfoWithGuard(const AInfo: string): string;
begin
  Result := AInfo;
  if not ConnInfoHasTimeoutKey(Result) then
    Result := Result + ' connect_timeout=' +
      IntToStr(RECONNECT_CONNECT_TIMEOUT_S);
end;

{ ---- 构造/析构 ---- }

constructor TPgListener.Create(const AConnInfo: string);
begin
  Create(AConnInfo, PG_LISTEN_DEFAULT_TICK_MS,
    PG_LISTEN_DEFAULT_QUEUE_CAPACITY);
end;

constructor TPgListener.Create(const AConnInfo: string;
  const ATickMs: Cardinal; const AQueueCapacity: Integer);
var
  LSelf: TPgListener;
begin
  inherited Create;
  if ATickMs < 1 then
    raise EDbError.CreateSimple(dbkPostgres, 'pg listener: tick < 1ms');
  if AQueueCapacity < 1 then
    raise EDbError.CreateSimple(dbkPostgres,
      'pg listener: queue capacity < 1');
  FConnInfo := AConnInfo;
  FTickMs := ATickMs;
  FCapacity := AQueueCapacity;
  FLk := nextpas.core.sync.mutex.TMutex.Create;
  FWake := CreateEvent(False);
  FData := CreateEvent(False);
  SetLength(FRing, FCapacity);
  FHead := 0;
  FCount := 0;
  FGapCount := 0;
  FDropped := 0;
  FBackendPid := -1;
  FStopping := 0;
  FPumpAlive := 1;
  { 首连同步完成：坏 conninfo 在消费方线程 fail-fast（可读诊断），
    泵线程只负责后续的重连循环；无 connect_timeout 时同款追加护栏
    ——fail-fast 不该被 OS 级 TCP 超时拖成分钟级阻塞（评审 m2） }
  try
    FConn := TPgConn.Create(ConnInfoWithGuard(AConnInfo));
  except
    on E: EPgError do
      raise EDbError.CreateSimple(dbkPostgres,
        'pg listener: ' + E.Message);
  end;
  FConnected := True;
  FBackendPid := pq_backendPID(FConn.Handle);
  FToken := CreateCancellationToken;
  FToken.OnCancel(@PgListenerStopBridge, Self);
  { 单工池常驻一个循环任务：关停顺序 = 置停止位 + 唤醒 → WaitAll
    （任务 ≤ 重连间隔上限内退出）→ Shutdown 收线程，不留后台线程 }
  FPool := CreateThreadPool(1);
  LSelf := Self;
  FPool.Submit(procedure
    begin
      LSelf.PumpLoop;
    end);
end;

destructor TPgListener.Destroy;
begin
  { 先摘取消回调链（评审 M1）：Token 是公开属性、消费方可合法持有
    至任意时刻——不摘链的话，监听器释放后任何一次 Token.Cancel 都会
    以已释放的 Self 调桥函数（悬垂 UAF）。RemoveOnCancel 幂等。
    其后为构造期建连失败自动析构的判空收尾（FPC 契约：ctor 异常调
    dtor），池/事件可能未装配。 }
  if FToken <> nil then
    FToken.RemoveOnCancel(@PgListenerStopBridge, Self);
  atomic_exchange(FStopping, 1, mo_acq_rel);
  if FWake <> nil then
    FWake.SetEvent;
  if FPool <> nil then
  begin
    FPool.WaitAll;                     { 泵自然收尾后才动连接与池 }
    FPool.Shutdown;
  end;
  FreeAndNil(FConn);
  inherited Destroy;
end;

{ ---- 校验 ---- }

function TPgListener.ValidateChannel(const AChannel: string): string;
var
  I: Integer;
begin
  Result := AChannel;
  if (AChannel = '') or (Length(AChannel) > 63) then
    raise EDbError.CreateSimple(dbkPostgres,
      'pg listener: channel name empty or longer than 63 chars');
  for I := 1 to Length(AChannel) do
    if not (AChannel[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      raise EDbError.CreateSimple(dbkPostgres,
        'pg listener: channel name must be [A-Za-z0-9_]: "' +
        AChannel + '"');
end;

procedure TPgListener.RequireAlive;
begin
  if atomic_load(FPumpAlive, mo_acquire) = 0 then
    raise EDbError.CreateSimple(dbkPostgres, 'pg listener: stopped');
end;

{ ---- 公开订阅面（消费方线程：校验 + 快照维护 + 入命令队列） ---- }

procedure TPgListener.Listen(const AChannel: string);
var
  LC: TListenCmd;
  I, N: Integer;
  LDup: Boolean;
begin
  ValidateChannel(AChannel);
  LC.Kind := ckListen;
  LC.Channel := AChannel;
  FLk.Acquire;
  try
    RequireAlive;
    LDup := False;
    for I := 0 to High(FChannels) do
      if FChannels[I] = AChannel then
      begin
        LDup := True;
        Break;
      end;
    if not LDup then
    begin
      N := Length(FChannels);
      SetLength(FChannels, N + 1);
      FChannels[N] := AChannel;
    end;
    SetLength(FCmds, Length(FCmds) + 1);
    FCmds[High(FCmds)] := LC;
  finally
    FLk.Release;
  end;
  FWake.SetEvent;
end;

procedure TPgListener.Unlisten(const AChannel: string);
var
  LC: TListenCmd;
  I, K: Integer;
  LFound: Boolean;
begin
  ValidateChannel(AChannel);
  LC.Kind := ckUnlisten;
  LC.Channel := AChannel;
  FLk.Acquire;
  try
    RequireAlive;
    LFound := False;
    for I := 0 to High(FChannels) do
      if FChannels[I] = AChannel then
      begin
        LFound := True;
        for K := I to High(FChannels) - 1 do
          FChannels[K] := FChannels[K + 1];
        SetLength(FChannels, Length(FChannels) - 1);
        Break;
      end;
    if not LFound then
      raise EDbError.CreateSimple(dbkPostgres,
        'pg listener: channel not subscribed: "' + AChannel + '"');
    SetLength(FCmds, Length(FCmds) + 1);
    FCmds[High(FCmds)] := LC;
  finally
    FLk.Release;
  end;
  FWake.SetEvent;
end;

procedure TPgListener.UnlistenAll;
var
  LC: TListenCmd;
begin
  LC.Kind := ckUnlistenAll;
  LC.Channel := '';
  FLk.Acquire;
  try
    RequireAlive;
    SetLength(FChannels, 0);
    SetLength(FCmds, Length(FCmds) + 1);
    FCmds[High(FCmds)] := LC;
  finally
    FLk.Release;
  end;
  FWake.SetEvent;
end;

{ ---- 接收面 ---- }

function TPgListener.Receive(
  const ATimeoutMs: Cardinal): TDbPgNotificationArray;
var
  LDeadlineMs, LRemainMs, LChunkMs, LChunkNs: Int64;
begin
  Result := TakeAllNotifications;
  if Length(Result) > 0 then
    Exit;
  if ATimeoutMs = 0 then
    Exit;
  if ATimeoutMs = PG_LISTEN_INFINITE then
    LDeadlineMs := High(Int64)
  else
    LDeadlineMs := PgNowMs + Int64(ATimeoutMs);
  while True do
  begin
    { 余量优先：停泵前后已入队通知都可取尽 }
    Result := TakeAllNotifications;
    if Length(Result) > 0 then
      Exit;
    if atomic_load(FPumpAlive, mo_acquire) = 0 then
      raise EDbError.CreateSimple(dbkPostgres,
        'pg listener: stopped');
    { 分片等待：上限一个节拍，停泵可被及时察觉而非睡满全程 }
    LRemainMs := LDeadlineMs - PgNowMs;
    if LRemainMs <= 0 then
      Exit(nil);
    LChunkMs := LRemainMs;
    if LChunkMs > Int64(FTickMs) then
      LChunkMs := Int64(FTickMs);
    LChunkNs := LChunkMs * 1000000;
    FData.WaitTimeout(LChunkNs);
  end;
end;

{ ---- 状态读数（锁内快照） ---- }

function TPgListener.GetConnected: Boolean;
begin
  FLk.Acquire;
  try
    Result := FConnected;
  finally
    FLk.Release;
  end;
end;

function TPgListener.GetGapCount: Int64;
begin
  FLk.Acquire;
  try
    Result := FGapCount;
  finally
    FLk.Release;
  end;
end;

function TPgListener.GetDroppedCount: Int64;
begin
  FLk.Acquire;
  try
    Result := FDropped;
  finally
    FLk.Release;
  end;
end;

function TPgListener.GetBackendPid: Integer;
begin
  FLk.Acquire;
  try
    Result := FBackendPid;
  finally
    FLk.Release;
  end;
end;

function TPgListener.GetLastErrorText: string;
begin
  FLk.Acquire;
  try
    Result := FLastError;
  finally
    FLk.Release;
  end;
end;

function TPgListener.GetSubscribedChannels: TDbStringArray;
var
  I: Integer;
begin
  Result := nil;
  FLk.Acquire;
  try
    SetLength(Result, Length(FChannels));
    for I := 0 to High(FChannels) do
      Result[I] := FChannels[I];
  finally
    FLk.Release;
  end;
end;

{ ---- 投递队列（锁内） ---- }

procedure TPgListener.EnqueueLocked(const AN: TDbPgNotification);
var
  ITail: Integer;
begin
  if FCount >= FCapacity then
  begin
    Inc(FDropped);                     { 保旧弃新，顺序不打断 }
    Exit;
  end;
  ITail := (FHead + FCount) mod FCapacity;
  FRing[ITail] := AN;
  Inc(FCount);
end;

function TPgListener.TakeAllNotifications: TDbPgNotificationArray;
var
  K, I: Integer;
begin
  Result := nil;
  FLk.Acquire;
  try
    if FCount = 0 then
      Exit;
    SetLength(Result, FCount);
    for K := 0 to FCount - 1 do
    begin
      I := (FHead + K) mod FCapacity;
      Result[K] := FRing[I];
    end;
    FHead := (FHead + FCount) mod FCapacity;
    FCount := 0;
  finally
    FLk.Release;
  end;
end;

{ ---- 泵线程侧（PGconn 独占） ---- }

procedure TPgListener.RecordErrorLocked(const ADiag: string);
begin
  FLastError := ADiag;
end;

procedure TPgListener.MarkDisconnected(const ADiag: string);
begin
  FreeAndNil(FConn);
  FLk.Acquire;
  try
    FConnected := False;
    Inc(FGapCount);                    { 一次断线 = 一段如实缺口 }
    FBackendPid := -1;
    if ADiag <> '' then
      FLastError := ADiag;
  finally
    FLk.Release;
  end;
end;

function TPgListener.TakeCommands: TListenCmdArray;
begin
  Result := nil;
  FLk.Acquire;
  try
    if Length(FCmds) > 0 then
    begin
      Result := FCmds;
      FCmds := nil;
    end;
  finally
    FLk.Release;
  end;
end;

procedure TPgListener.ApplyCommand(const ACmd: TListenCmd);
begin
  case ACmd.Kind of
    ckListen:      FConn.Exec('LISTEN ' + ACmd.Channel);
    ckUnlisten:    FConn.Exec('UNLISTEN ' + ACmd.Channel);
    ckUnlistenAll: FConn.Exec('UNLISTEN *');
  end;
end;

procedure TPgListener.TryReconnect;
var
  LInfo: string;
  I: Integer;
  LConn: TPgConn;
  LSnap: TDbStringArray;
begin
  { 建连走公共护栏（评审 m2/n1：首连/重连同一关键字边界判定） }
  LInfo := ConnInfoWithGuard(FConnInfo);
  LConn := TPgConn.Create(LInfo);
  { 快照副本先行；重放是网络 IO，不持锁执行 }
  FLk.Acquire;
  try
    SetLength(LSnap, Length(FChannels));
    for I := 0 to High(FChannels) do
      LSnap[I] := FChannels[I];
  finally
    FLk.Release;
  end;
  { 按订阅快照重放 LISTEN（at-most-once 承诺的另一半——会话换了，
    订阅必须自己补回来）。重放中途失败则本连接不接管：FConn 保持
    nil，恢复机器统一拥有重试权——避免半配置连接常驻导致 Connected
    长期失真、GapCount 双计（评审 m1） }
  try
    for I := 0 to High(LSnap) do
      LConn.Exec('LISTEN ' + LSnap[I]);
  except
    LConn.Free;
    raise;                              { 诊断由 PumpLoop 统一记录 }
  end;
  { 全部成功才接管并翻转状态读数 }
  FLk.Acquire;
  try
    FConn := LConn;
    FConnected := True;
    FBackendPid := pq_backendPID(LConn.Handle);
    FLastError := '';
  finally
    FLk.Release;
  end;
end;

procedure TPgListener.ConsumeAndDeliver;
var
  H: PGconn;
  LN: PPGnotify;
  LNn: TDbPgNotification;
  LDiag: string;
  LAny: Boolean;
begin
  H := FConn.Handle;
  if pq_status(H) <> CONNECTION_OK then
  begin
    MarkDisconnected('connection status bad');
    Exit;
  end;
  if pq_consumeInput(H) = 0 then
  begin
    LDiag := string(AnsiString(pq_errorMessage(H)));
    MarkDisconnected(LDiag);
    Exit;
  end;
  LAny := False;
  while True do
  begin
    LN := pq_notifies(H);
    if LN = nil then
      Break;
    LNn.Channel := AnsiPtrToStr(LN^.Relname);
    LNn.Payload := AnsiPtrToStr(LN^.Extra);
    LNn.SenderPid := LN^.BePid;
    pq_freemem(LN);                    { libpq 契约：逐条释放 }
    FLk.Acquire;
    try
      EnqueueLocked(LNn);
    finally
      FLk.Release;
    end;
    LAny := True;
  end;
  if LAny then
    FData.SetEvent;
end;

procedure TPgListener.PumpLoop;
var
  LCmds: TListenCmdArray;
  I: Integer;
  LNextRetryMs: Int64;
begin
  LNextRetryMs := 0;
  { 停止两源：析构置 FStopping；消费方 Token.Cancel 走协同取消 }
  while (atomic_load(FStopping, mo_acquire) = 0) and
        (not FToken.IsCancelled) do
  begin
    if FConn = nil then
    begin
      if PgNowMs >= LNextRetryMs then
      begin
        try
          TryReconnect;
        except
          on E: Exception do
          begin
            FLk.Acquire;
            try
              RecordErrorLocked(E.Message);
            finally
              FLk.Release;
            end;
          end;
        end;
        LNextRetryMs := PgNowMs +
          Int64(FTickMs) * RECONNECT_TICK_FACTOR;
      end;
    end;
    if (FConn <> nil) and (atomic_load(FStopping, mo_acquire) = 0) then
    begin
      LCmds := TakeCommands;
      for I := 0 to High(LCmds) do
      begin
        try
          ApplyCommand(LCmds[I]);
        except
          on E: Exception do
          begin
            { 命令失败不致命：诊断入 LastError 可见；连接是否真断
              由下一步 ConsumeAndDeliver 的状态检查裁决 }
            FLk.Acquire;
            try
              RecordErrorLocked(E.Message);
            finally
              FLk.Release;
            end;
          end;
        end;
      end;
      if atomic_load(FStopping, mo_acquire) = 0 then
        ConsumeAndDeliver;             { 可能就地转断线态 }
    end;
    if atomic_load(FStopping, mo_acquire) <> 0 then
      Break;
    { 节拍兜底 + 多源唤醒（新命令 / 取消 / 析构） }
    FWake.WaitTimeout(Int64(FTickMs) * 1000000);
  end;
  atomic_exchange(FPumpAlive, 0, mo_acq_rel);
end;

function PgOpenListener(const AConnInfo: string): TPgListener;
begin
  Result := TPgListener.Create(AConnInfo);
end;

end.
