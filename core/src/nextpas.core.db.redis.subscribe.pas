unit nextpas.core.db.redis.subscribe;

{** @desc Redis SUBSCRIBE/PSUBSCRIBE 订阅会话（V3-B8）。

       形态：TRedisSubscriber 独占一条专用连接（私有传输 + 握手，
       不暴露查询面——RESP2 订阅态下除 SUBSCRIBE/UNSUBSCRIBE/
       PSUBSCRIBE/PUNSUBSCRIBE/RESET/QUIT 外的命令一律被服务端
       拒绝，独占性比 pg LISTEN 更强且由协议结构性保证，见
       CONTRACT §2.19）。泵线程独占 IRedisTransport：阻塞 Recv
       （deadline 到期抛 ETimeoutError = 节拍检查点；0 返回 = 对端
       关闭）→ 增量 RESP 解析 → 推送帧投递进内建有界记录队列；
       消费方 Receive 阻塞取用。

       体积注记：本单元约1170行超 800 行软阈值，内聚性强（订阅会话单职责），暂不拆分，拆分预留见 roadmap。
       底座全部来自 core 家族（不在本单元造平行宇宙），骨架自
       nextpas.core.db.pg.listen 泛化：
       - 线程运行时初始化：nextpas.core.thread.init；
       - 泵线程：nextpas.core.thread.pool 单工池；
       - 互斥/事件：nextpas.core.sync；
       - 取消令牌：nextpas.core.async.cancellation（Token 属性外露，
         Cancel 即协同停泵）。

       与 B7 的关键差异（提案 D1-D6，CONTRACT §2.19 同文）：
       - 推送帧分支：message / pmessage 入消费队列；subscribe 等
         确认帧不入队列、转为订阅簿记回执（v1 吸收不外露）；
       - pmessage 比 message 多 pattern 字段（TDbRedisMessage）；
         频道/pattern 无字符集限制（与 pg NAMEDATALEN 约束的语义
         差异如实保留），仅做非空 + 防御性长度上界；
       - 会话级失效：断线即服务端订阅全失，重连后按意图快照重放
         SUBSCRIBE/PSUBSCRIBE；GapCount/DroppedCount/at-most-once
         语义与 §2.18 逐字同款；
       - 可选 PING 保活（默认关）：订阅态长连接无流量防中间设备
         掐断；回复帧由通用帧消费路径吸收；
       - 协议解析复用 nextpas.core.db.resp 增量解析器，零新造协议。

       语义承诺：
       - at-most-once 如实上报：断线窗口内的消息不补发，GapCount
         记断线次数，不假装 at-least-once；
       - 溢出保旧弃新：队列满丢弃最新并计 DroppedCount（顺序不打断）。
       - 时延界：消息到达即唤醒（Recv deadline 只是上界，不影响
         传播延迟——"节拍 + RTT"契约同 §2.18）；停泵/断线检出上界
         = IO deadline（内部建连缺省 max(2×节拍, 1000)ms，为握手
         安全让路——与 pg 的纯节拍上界差异如实登记）。 *}

{$I nextpas.core.settings.inc}

{$modeswitch functionreferences}
{$modeswitch anonymousfunctions}

interface

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.db.base,
  nextpas.core.db.redis.base,
  nextpas.core.db.redis.transport,
  nextpas.core.async.cancellation,
  nextpas.core.sync.intf,
  nextpas.core.thread.intf,
  nextpas.core.thread.pool;

const
  { Receive 的无限等待哨兵（其余值 = 毫秒超时；0 = 非阻塞探测） }
  REDIS_SUBSCRIBE_INFINITE = Cardinal($FFFFFFFF);

  { 泵默认节拍：同时是 Receive 分片等待与重连退避基数 }
  REDIS_SUBSCRIBE_DEFAULT_TICK_MS = 50;
  { 默认投递队列容量（条）；满后保旧弃新 }
  REDIS_SUBSCRIBE_DEFAULT_QUEUE_CAPACITY = 1024;

type
  {** 传输工厂：默认实现按选项建 TCP/TLS 管道并完成 AUTH/SELECT
      握手；离线门禁注入脚本化回放工厂（每次调用返回一条"新连接"
      ——重连测试据此提供多段脚本）。 *}
  TRedisTransportFactory = reference to function: IRedisTransport;

  {** 订阅会话。契约：
      - 独占专用连接：本类私有建连并持有，消费方不得将该连接用于
        普通命令（结构上无命令执行面）。
      - Subscribe/PSubscribe 客户端校验先行（非空、长度 ≤1024），
        非法即抛 EDbError 不触网；合法命令异步应用到泵线程（典型
        ≤1 节拍生效）。重复订阅幂等；退订未订阅项 fail-fast。
      - Receive(ATimeoutMs) 阻塞至 ≥1 条或超时；一次带回全部积压
        （FIFO 保序）。泵停止且余量取尽后抛 EDbError（防消费者
        无限等）；停止前已入队的消息仍可取尽。
      - 断线自动重连（间隔 = 4×节拍），成功后按意图快照重放
        SUBSCRIBE/PSUBSCRIBE；重放中途失败则本传输不接管，恢复
        机器统一拥有重试权（避免半配置连接常驻导致 Connected
        长期失真、GapCount 双计——pg.listen 评审 m1 同款纪律）。
      - Token 取消即协同停泵；Destroy 同步收尾（先停泵再关传输，
        不留后台线程）。 *}
  TRedisSubscriber = class
  private type
    TSubCmdKind = (ckSubscribe, ckUnsubscribe, ckPSubscribe,
      ckPUnsubscribe, ckUnsubscribeAll);
    TSubCmd = record
      Kind: TSubCmdKind;
      Channel: string;              { ckUnsubscribeAll 忽略 }
    end;
    TSubCmdArray = array of TSubCmd;
    TSubEntry = record
      Name: string;
      IsPattern: Boolean;
    end;
    TSubEntryArray = array of TSubEntry;
  private
    FOptions: TDbRedisConnectOptions;
    FFactory: TRedisTransportFactory;
    FTickMs: Cardinal;
    FCapacity: Integer;
    FKeepAliveMs: Cardinal;         { 0 = 关（v1 默认） }
    FKeepAliveLastMs: Int64;
    FTransport: IRedisTransport;    { 仅泵线程触碰；nil = 断线中 }
    FRcvBuf: TBytes;                { 接收累积缓冲（仅泵线程触碰） }
    FHaveLen: Integer;              { FRcvBuf 有效字节数 }
    FLk: ILock;
    FIdle: IEvent;                  { 断线退避等待的唤醒源（自动复位） }
    FData: IEvent;                  { 投递队列非空信号（自动复位） }
    FPool: IThreadPool;
    FToken: IAsyncCancellationToken;
    FPumpAlive: Integer;            { 原子：1 = 泵在跑；0 = 已收尾 }
    FStopping: Integer;             { 原子：析构/取消置位 }
    { 以下均受 FLk 保护 }
    FCmds: TSubCmdArray;
    FSubs: TSubEntryArray;          { 订阅意图快照（重连重放依据） }
    FRing: TDbRedisMessageArray;
    FHead: Integer;
    FCount: Integer;
    FConnected: Boolean;
    FGapCount: Int64;
    FDropped: Int64;
    FLastError: string;
    procedure ApplyCommand(const ACmd: TSubCmd);
    procedure TryReconnect;
    function TakeCommands: TSubCmdArray;
    procedure PumpLoop;
    procedure PumpLoopBody(var ANextRetryMs: Int64);
    procedure PumpRecvOnce;
    procedure ConsumeFrame(const AValue: TRespValue);
    procedure EnqueueLocked(const AM: TDbRedisMessage);
    procedure MarkDisconnected(const ADiag: string);
    procedure SendArgs(const AArgs: array of TBytes);
    procedure KeepAliveTick;
    function AddSubEntry(const AName: string;
      const AIsPattern: Boolean): Boolean;
    procedure RemoveSubEntry(const AName: string; const AIsPattern: Boolean);
    procedure AppendCmd(const ACmd: TSubCmd);
    function TakeAllMessages: TDbRedisMessageArray;
    procedure ValidateName(const AName: string);
    procedure RequireAlive;
    procedure RecordErrorLocked(const ADiag: string);
    procedure StopPump;
    function GetConnected: Boolean;
    function GetGapCount: Int64;
    function GetDroppedCount: Int64;
    function GetLastErrorText: string;
    function GetSubscribedChannels: TDbStringArray;
    function GetSubscribedPatterns: TDbStringArray;
  public
    {** live 构造：按选项私有建连（AUTH/SELECT 握手同步完成，坏
        地址/口令在消费方线程 fail-fast）。IoTimeoutMs<=0 时以
        max(2×节拍, 1000)ms 兜底，防坏网络拖死首连/泵循环。 *}
    constructor Create(const AOptions: TDbRedisConnectOptions); overload;
    constructor Create(const AOptions: TDbRedisConnectOptions;
      const ATickMs: Cardinal; const AQueueCapacity: Integer;
      const AKeepAliveMs: Cardinal = 0); overload;
    {** DI/replay 构造：注入传输工厂（离线门禁；工厂每次调用返回
        一条新连接，握手责任随注入方）。 *}
    constructor Create(const AFactory: TRedisTransportFactory;
      const ATickMs: Cardinal = REDIS_SUBSCRIBE_DEFAULT_TICK_MS;
      const AQueueCapacity: Integer =
        REDIS_SUBSCRIBE_DEFAULT_QUEUE_CAPACITY;
      const AKeepAliveMs: Cardinal = 0); overload;
    destructor Destroy; override;

    procedure Subscribe(const AChannel: string);
    procedure Unsubscribe(const AChannel: string);
    procedure PSubscribe(const APattern: string);
    procedure PUnsubscribe(const APattern: string);
    procedure UnsubscribeAll;

    {** 阻塞取推送（见类注）。返回本次取到的全部积压（空数组 =
        超时）。 *}
    function Receive(const ATimeoutMs: Cardinal): TDbRedisMessageArray;

    property Connected: Boolean read GetConnected;
    property GapCount: Int64 read GetGapCount;
    property DroppedCount: Int64 read GetDroppedCount;
    property LastError: string read GetLastErrorText;
    property SubscribedChannels: TDbStringArray read GetSubscribedChannels;
    property SubscribedPatterns: TDbStringArray read GetSubscribedPatterns;
    { 协同取消令牌：Cancel 即停泵；可挂子令牌级联 }
    property Token: IAsyncCancellationToken read FToken;
  end;

{ 打开 SUBSCRIBE 订阅会话（对齐 PgOpenListener 先例；失败抛
  EDbError，诊断并入消息）。 }
function RedisOpenSubscriber(
  const AOptions: TDbRedisConnectOptions): TRedisSubscriber;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.exception,
  nextpas.core.platform,
  nextpas.core.sync.mutex,
  nextpas.core.sync.event,
  nextpas.core.db.redis.resp;

const
  RECONNECT_TICK_FACTOR = 4;   { 重连尝试间隔 = 4 × 泵节拍 }
  { 单帧防御性上界：超过仍未解析出完整帧即判对端异常断开，防伪造
    长度头把接收缓冲无限撑大（resp 解析器在字节未到齐前不分配，
    上界由本层守） }
  MAX_FRAME_BYTES = 16 * 1024 * 1024;

{ 默认传输工厂的 IO deadline 兜底：max(2×节拍, 1000) ms }
function EffectiveIoTimeoutMs(const AOptions: TDbRedisConnectOptions;
  const ATickMs: Cardinal): Integer;
begin
  Result := AOptions.IoTimeoutMs;
  if Result <= 0 then
  begin
    Result := Integer(ATickMs) * 2;
    if Result < 1000 then
      Result := 1000;
  end;
  if Result > 3600000 then
    Result := 3600000;                 { 防御性上界：1h }
end;

function BytesOfText(const AStr: string): TBytes;
begin
  if Length(AStr) = 0 then
    Exit(nil);
  SetLength(Result, Length(AStr));
  Move(AStr[1], Result[0], Length(AStr));
end;

function RespToStr(const AB: TBytes): string;
begin
  Result := RespBytesToStr(AB);
end;

{ 取消桥（Token.Cancel）：置停泵位并惊动断线退避等待与数据等待。
  连接在途时泵阻塞在带 deadline 的 Recv 上，最迟一个 IO deadline
  内察觉（IRedisTransport 无中断面，该延迟诚实登记于单元头）；
  hole-aware：同时惊动 FData 让 Receive 尾窗口及时察觉停泵，
  不让已入队消息在停泵后仍被睡满节拍。 }
procedure RedisSubscriberStopBridge(AData: Pointer);
var
  LSub: TRedisSubscriber;
begin
  LSub := TRedisSubscriber(AData);
  if LSub <> nil then
  begin
    LSub.StopPump;
    if LSub.FIdle <> nil then
      LSub.FIdle.SetEvent;
    if LSub.FData <> nil then
      LSub.FData.SetEvent;
  end;
end;

function RedisNowMs: Int64;
begin
  Result := Int64(platform_monotonic_ns div 1000000);
end;

{ 在指定传输上发送命令帧（重连重放期 FTransport 尚未接管，需显式
  传目标——接管后统一走 SendArgs） }
procedure SendArgsOn(const ATrans: IRedisTransport;
  const AArgs: array of TBytes);
var
  LFrame: TBytes;
begin
  RespEncodeCommand(AArgs, LFrame);
  ATrans.Send(LFrame);
end;

procedure TRedisSubscriber.SendArgs(const AArgs: array of TBytes);
begin
  SendArgsOn(FTransport, AArgs);
end;

{ 读一条完整回复帧（握手用）：缓冲不足继续 Recv；IO 超时按原样
  上抛（fail-fast，不无限等）；错误帧转 EDbError。 }
procedure ReadReplyFrame(const ATrans: IRedisTransport;
  var ABuf: TBytes; var ALen: Integer; out AValue: TRespValue);
var
  LN, LPos, LLeft: Integer;
  LView: TBytes;
  LNeedMore: Boolean;
begin
  if ABuf = nil then
    SetLength(ABuf, 4096);
  ALen := 0;
  while True do
  begin
    if ALen > 0 then
    begin
      { resp 解析器以 High(ABuf) 为扫描界——必须喂精确有效长度
        视图，残料之外的陈旧字节会被误扫（与泵循环同款纪律） }
      LView := Copy(ABuf, 0, ALen);
      LPos := 0;
      if RespTryParse(LView, LPos, AValue, LNeedMore) then
      begin
        LLeft := ALen - LPos;
        if LLeft > 0 then
          Move(LView[LPos], ABuf[0], LLeft);
        Dec(ALen, LPos);
        Exit;
      end;
    end;
    if ALen + 4096 > Length(ABuf) then
      SetLength(ABuf, Length(ABuf) * 2);
    LN := ATrans.Recv(@ABuf[ALen], Length(ABuf) - ALen);
    if LN <= 0 then
      raise EDbError.CreateSimple(dbkRedis,
        'redis subscriber: handshake transport closed');
    Inc(ALen, LN);
  end;
end;

{ 默认工厂的握手：AUTH → SELECT。错误回复即建连失败（对齐
  adapter.Handshake 语义；INFO 探测不适用订阅会话故省略）。 }
procedure HandshakeTransport(const ATrans: IRedisTransport;
  const APassword: string; const ADbIndex: Integer);
var
  LBuf: TBytes;
  LLn: Integer;
  LValue: TRespValue;

  procedure ExpectOk(const AWhat: string);
  begin
    ReadReplyFrame(ATrans, LBuf, LLn, LValue);
    if LValue.Kind = rvkError then
      raise EDbError.CreateSimple(dbkRedis,
        'redis subscriber: ' + AWhat + ': ' + RespToStr(LValue.Data));
  end;

begin
  LBuf := nil;
  LLn := 0;
  if APassword <> '' then
  begin
    SendArgsOn(ATrans, [BytesOfText('AUTH'), BytesOfText(APassword)]);
    ExpectOk('auth failed');
  end;
  if ADbIndex <> 0 then
  begin
    SendArgsOn(ATrans, [BytesOfText('SELECT'),
      BytesOfText(IntToStr(ADbIndex))]);
    ExpectOk('select failed');
  end;
end;

{ ---- 构造/析构 ---- }

constructor TRedisSubscriber.Create(
  const AOptions: TDbRedisConnectOptions);
begin
  Create(AOptions, REDIS_SUBSCRIBE_DEFAULT_TICK_MS,
    REDIS_SUBSCRIBE_DEFAULT_QUEUE_CAPACITY, 0);
end;

constructor TRedisSubscriber.Create(const AOptions: TDbRedisConnectOptions;
  const ATickMs: Cardinal; const AQueueCapacity: Integer;
  const AKeepAliveMs: Cardinal);
var
  LOpts: TDbRedisConnectOptions;
begin
  LOpts := AOptions;
  LOpts.IoTimeoutMs := EffectiveIoTimeoutMs(AOptions, ATickMs);
  Create(
    function: IRedisTransport
    var
      LT: IRedisTransport;
    begin
      LT := NewNetRedisTransport(LOpts);
      try
        HandshakeTransport(LT, LOpts.Password, LOpts.DbIndex);
      except
        LT := nil;
        raise;
      end;
      Result := LT;
    end,
    ATickMs, AQueueCapacity, AKeepAliveMs);
  FOptions := LOpts;
end;

constructor TRedisSubscriber.Create(const AFactory: TRedisTransportFactory;
  const ATickMs: Cardinal; const AQueueCapacity: Integer;
  const AKeepAliveMs: Cardinal);
var
  LSelf: TRedisSubscriber;
begin
  inherited Create;
  if AFactory = nil then
    raise EDbError.CreateSimple(dbkRedis,
      'redis subscriber: transport factory nil');
  if ATickMs < 1 then
    raise EDbError.CreateSimple(dbkRedis, 'redis subscriber: tick < 1ms');
  if AQueueCapacity < 1 then
    raise EDbError.CreateSimple(dbkRedis,
      'redis subscriber: queue capacity < 1');
  FFactory := AFactory;
  FTickMs := ATickMs;
  FCapacity := AQueueCapacity;
  FKeepAliveMs := AKeepAliveMs;
  FKeepAliveLastMs := 0;
  SetLength(FRcvBuf, 65536);
  FHaveLen := 0;
  FLk := nextpas.core.sync.mutex.TMutex.Create;
  FIdle := CreateEvent(False);
  FData := CreateEvent(False);
  SetLength(FRing, FCapacity);
  FHead := 0;
  FCount := 0;
  FGapCount := 0;
  FDropped := 0;
  FStopping := 0;
  FPumpAlive := 1;
  { 首连同步完成：坏地址/口令在消费方线程 fail-fast（可读诊断），
    泵线程只负责后续的重连循环 }
  FTransport := FFactory();
  FLk.Acquire;
  try
    FConnected := True;
  finally
    FLk.Release;
  end;
  FToken := CreateCancellationToken;
  FToken.OnCancel(@RedisSubscriberStopBridge, Self);
  { 单工池常驻一个循环任务：关停顺序 = 置停止位 + 惊动退避等待 →
    WaitAll（任务 ≤ 一个 IO deadline 内退出）→ Shutdown 收线程，
    不留后台线程 }
  FPool := CreateThreadPool(1);
  LSelf := Self;
  FPool.Submit(procedure
    begin
      LSelf.PumpLoop;
    end);
end;

destructor TRedisSubscriber.Destroy;
begin
  { 先摘取消回调链（pg.listen 评审 M1 同款）：Token 是公开属性、
    消费方可合法持有至任意时刻——不摘链的话，订阅器释放后任何一次
    Token.Cancel 都会以已释放的 Self 调桥函数（悬垂 UAF）。
    RemoveOnCancel 幂等。其后为构造期建连失败自动析构的判空收尾
    （FPC 契约：ctor 异常调 dtor），池可能未装配。 }
  if FToken <> nil then
    FToken.RemoveOnCancel(@RedisSubscriberStopBridge, Self);
  atomic_exchange(FStopping, 1, mo_acq_rel);
  if FIdle <> nil then
    FIdle.SetEvent;
  if FData <> nil then
    FData.SetEvent;
  if FPool <> nil then
  begin
    FPool.WaitAll;                     { 泵自然收尾后才动池 }
    FPool.Shutdown;
  end;
  FTransport := nil;                   { 接口释放即关闭管道 }
  inherited Destroy;
end;

{ ---- 校验 ---- }

procedure TRedisSubscriber.ValidateName(const AName: string);
begin
  { redis 频道/pattern 为任意二进制串（与 pg 的 NAMEDATALEN 字符集
    限制不同——语义差异如实保留）；仅做非空与防御性长度上界 }
  if (AName = '') or (Length(AName) > 1024) then
    raise EDbError.CreateSimple(dbkRedis,
      'redis subscriber: name empty or longer than 1024 chars');
end;

procedure TRedisSubscriber.RequireAlive;
begin
  if atomic_load(FPumpAlive, mo_acquire) = 0 then
    raise EDbError.CreateSimple(dbkRedis, 'redis subscriber: stopped');
end;

procedure TRedisSubscriber.StopPump;
begin
  atomic_exchange(FStopping, 1, mo_acq_rel);
end;

{ ---- 快照/命令队列辅助（须持 FLk 调用） ---- }

function TRedisSubscriber.AddSubEntry(const AName: string;
  const AIsPattern: Boolean): Boolean;
var
  I, N: Integer;
begin
  Result := False;
  for I := 0 to High(FSubs) do
    if (FSubs[I].IsPattern = AIsPattern) and (FSubs[I].Name = AName) then
      Exit;                            { 幂等：重复订阅不重复发 }
  N := Length(FSubs);
  SetLength(FSubs, N + 1);
  FSubs[N].Name := AName;
  FSubs[N].IsPattern := AIsPattern;
  Result := True;
end;

procedure TRedisSubscriber.RemoveSubEntry(const AName: string;
  const AIsPattern: Boolean);
var
  I, K: Integer;
begin
  for I := 0 to High(FSubs) do
    if (FSubs[I].IsPattern = AIsPattern) and (FSubs[I].Name = AName) then
    begin
      for K := I to High(FSubs) - 1 do
        FSubs[K] := FSubs[K + 1];
      SetLength(FSubs, Length(FSubs) - 1);
      Exit;
    end;
  raise EDbError.CreateSimple(dbkRedis,
    'redis subscriber: not subscribed: "' + AName + '"');
end;

procedure TRedisSubscriber.AppendCmd(const ACmd: TSubCmd);
begin
  SetLength(FCmds, Length(FCmds) + 1);
  FCmds[High(FCmds)] := ACmd;
end;

{ ---- 公开订阅面（消费方线程：校验 + 快照维护 + 入命令队列） ---- }

procedure TRedisSubscriber.Subscribe(const AChannel: string);
var
  LC: TSubCmd;
begin
  ValidateName(AChannel);
  LC.Kind := ckSubscribe;
  LC.Channel := AChannel;
  FLk.Acquire;
  try
    RequireAlive;
    if AddSubEntry(AChannel, False) then
      AppendCmd(LC);
  finally
    FLk.Release;
  end;
end;

procedure TRedisSubscriber.PSubscribe(const APattern: string);
var
  LC: TSubCmd;
begin
  ValidateName(APattern);
  LC.Kind := ckPSubscribe;
  LC.Channel := APattern;
  FLk.Acquire;
  try
    RequireAlive;
    if AddSubEntry(APattern, True) then
      AppendCmd(LC);
  finally
    FLk.Release;
  end;
end;

procedure TRedisSubscriber.Unsubscribe(const AChannel: string);
var
  LC: TSubCmd;
begin
  ValidateName(AChannel);
  LC.Kind := ckUnsubscribe;
  LC.Channel := AChannel;
  FLk.Acquire;
  try
    RequireAlive;
    RemoveSubEntry(AChannel, False);
    AppendCmd(LC);
  finally
    FLk.Release;
  end;
end;

procedure TRedisSubscriber.PUnsubscribe(const APattern: string);
var
  LC: TSubCmd;
begin
  ValidateName(APattern);
  LC.Kind := ckPUnsubscribe;
  LC.Channel := APattern;
  FLk.Acquire;
  try
    RequireAlive;
    RemoveSubEntry(APattern, True);
    AppendCmd(LC);
  finally
    FLk.Release;
  end;
end;

procedure TRedisSubscriber.UnsubscribeAll;
var
  LC: TSubCmd;
begin
  LC.Kind := ckUnsubscribeAll;
  LC.Channel := '';
  FLk.Acquire;
  try
    RequireAlive;
    SetLength(FSubs, 0);
    AppendCmd(LC);
  finally
    FLk.Release;
  end;
end;

{ ---- 接收面 ---- }

function TRedisSubscriber.Receive(
  const ATimeoutMs: Cardinal): TDbRedisMessageArray;
var
  LDeadlineMs, LRemainMs, LChunkMs, LChunkNs: Int64;
begin
  Result := TakeAllMessages;
  if Length(Result) > 0 then
    Exit;
  if ATimeoutMs = 0 then
    Exit;
  if ATimeoutMs = REDIS_SUBSCRIBE_INFINITE then
    LDeadlineMs := High(Int64)
  else
    LDeadlineMs := RedisNowMs + Int64(ATimeoutMs);
  while True do
  begin
    { 余量优先：停泵前后已入队消息都可取尽 }
    Result := TakeAllMessages;
    if Length(Result) > 0 then
      Exit;
    if atomic_load(FPumpAlive, mo_acquire) = 0 then
      raise EDbError.CreateSimple(dbkRedis, 'redis subscriber: stopped');
    { 分片等待：上限一个节拍，停泵可被及时察觉而非睡满全程 }
    LRemainMs := LDeadlineMs - RedisNowMs;
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

function TRedisSubscriber.GetConnected: Boolean;
begin
  FLk.Acquire;
  try
    Result := FConnected;
  finally
    FLk.Release;
  end;
end;

function TRedisSubscriber.GetGapCount: Int64;
begin
  FLk.Acquire;
  try
    Result := FGapCount;
  finally
    FLk.Release;
  end;
end;

function TRedisSubscriber.GetDroppedCount: Int64;
begin
  FLk.Acquire;
  try
    Result := FDropped;
  finally
    FLk.Release;
  end;
end;

function TRedisSubscriber.GetLastErrorText: string;
begin
  FLk.Acquire;
  try
    Result := FLastError;
  finally
    FLk.Release;
  end;
end;

function TRedisSubscriber.GetSubscribedChannels: TDbStringArray;
var
  I, N: Integer;
begin
  Result := nil;
  FLk.Acquire;
  try
    N := 0;
    SetLength(Result, Length(FSubs));
    for I := 0 to High(FSubs) do
      if not FSubs[I].IsPattern then
      begin
        Result[N] := FSubs[I].Name;
        Inc(N);
      end;
    SetLength(Result, N);
  finally
    FLk.Release;
  end;
end;

function TRedisSubscriber.GetSubscribedPatterns: TDbStringArray;
var
  I, N: Integer;
begin
  Result := nil;
  FLk.Acquire;
  try
    N := 0;
    SetLength(Result, Length(FSubs));
    for I := 0 to High(FSubs) do
      if FSubs[I].IsPattern then
      begin
        Result[N] := FSubs[I].Name;
        Inc(N);
      end;
    SetLength(Result, N);
  finally
    FLk.Release;
  end;
end;

{ ---- 投递队列（锁内） ---- }

procedure TRedisSubscriber.EnqueueLocked(const AM: TDbRedisMessage);
var
  ITail: Integer;
begin
  if FCount >= FCapacity then
  begin
    Inc(FDropped);                     { 保旧弃新，顺序不打断 }
    Exit;
  end;
  ITail := (FHead + FCount) mod FCapacity;
  FRing[ITail] := AM;
  Inc(FCount);
end;

function TRedisSubscriber.TakeAllMessages: TDbRedisMessageArray;
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

{ ---- 泵线程侧（IRedisTransport 独占） ---- }

procedure TRedisSubscriber.RecordErrorLocked(const ADiag: string);
begin
  FLastError := ADiag;
end;

procedure TRedisSubscriber.MarkDisconnected(const ADiag: string);
var
  LPos: Integer;
  LValue: TRespValue;
  LNeedMore: Boolean;
  LView: TBytes;
begin
  { hole-aware 尾窗口：断线前若 FRcvBuf 中已有完整帧（上一轮 Recv
    已到但尚未及 Consume 就被判对端关闭），先尽力投递再丢半帧，
    不让已完整到达的消息因“半帧丢弃”一并丢失。 }
  if FHaveLen > 0 then
  begin
    LView := Copy(FRcvBuf, 0, FHaveLen);
    LPos := 0;
    try
      while LPos < FHaveLen do
      begin
        if not RespTryParse(LView, LPos, LValue, LNeedMore) then
          Break;
        ConsumeFrame(LValue);
      end;
      if LPos > 0 then
      begin
        if LPos < FHaveLen then
          Move(FRcvBuf[LPos], FRcvBuf[0], FHaveLen - LPos);
        Dec(FHaveLen, LPos);
        if FHaveLen < 0 then FHaveLen := 0;
      end;
    except
      { 解析异常已在外层转断线，此处静默忽略以保活计数 }
    end;
  end;
  FTransport := nil;
  FHaveLen := 0;                       { 丢弃半帧残料（不完整尾） }
  FLk.Acquire;
  try
    FConnected := False;
    Inc(FGapCount);                    { 一次断线 = 一段如实缺口 }
    if ADiag <> '' then
      FLastError := ADiag;
  finally
    FLk.Release;
  end;
end;

function TRedisSubscriber.TakeCommands: TSubCmdArray;
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

procedure TRedisSubscriber.ApplyCommand(const ACmd: TSubCmd);
begin
  case ACmd.Kind of
    ckSubscribe:
      SendArgs([BytesOfText('SUBSCRIBE'), BytesOfText(ACmd.Channel)]);
    ckUnsubscribe:
      SendArgs([BytesOfText('UNSUBSCRIBE'), BytesOfText(ACmd.Channel)]);
    ckPSubscribe:
      SendArgs([BytesOfText('PSUBSCRIBE'), BytesOfText(ACmd.Channel)]);
    ckPUnsubscribe:
      SendArgs([BytesOfText('PUNSUBSCRIBE'), BytesOfText(ACmd.Channel)]);
    ckUnsubscribeAll:
      begin
        { RESP2：无参 UNSUBSCRIBE / PUNSUBSCRIBE 各清空频道/pattern 面 }
        SendArgs([BytesOfText('UNSUBSCRIBE')]);
        SendArgs([BytesOfText('PUNSUBSCRIBE')]);
      end;
  end;
end;

procedure TRedisSubscriber.KeepAliveTick;
var
  LNow: Int64;
begin
  if FKeepAliveMs = 0 then
    Exit;
  LNow := RedisNowMs;
  if (FKeepAliveLastMs <> 0) and
     (LNow - FKeepAliveLastMs < Int64(FKeepAliveMs)) then
    Exit;
  SendArgs([BytesOfText('PING')]);
  FKeepAliveLastMs := LNow;
end;

procedure TRedisSubscriber.TryReconnect;
var
  I: Integer;
  LTrans: IRedisTransport;
  LSnap: TSubEntryArray;
begin
  LTrans := FFactory();
  { 快照副本先行；重放是网络 IO，不持锁执行 }
  FLk.Acquire;
  try
    SetLength(LSnap, Length(FSubs));
    for I := 0 to High(FSubs) do
      LSnap[I] := FSubs[I];
  finally
    FLk.Release;
  end;
  { 按订阅意图快照重放 SUBSCRIBE/PSUBSCRIBE（at-most-once 承诺的
    另一半——会话换了，订阅必须自己补回来）。重放中途失败则本传输
    不接管：FTransport 保持 nil，恢复机器统一拥有重试权——避免半
    配置连接常驻导致 Connected 长期失真、GapCount 双计（pg.listen
    评审 m1 同款纪律）。 }
  try
    for I := 0 to High(LSnap) do
      if LSnap[I].IsPattern then
        SendArgsOn(LTrans, [BytesOfText('PSUBSCRIBE'),
          BytesOfText(LSnap[I].Name)])
      else
        SendArgsOn(LTrans, [BytesOfText('SUBSCRIBE'),
          BytesOfText(LSnap[I].Name)]);
  except
    LTrans := nil;
    raise;                              { 诊断由 PumpLoop 统一记录 }
  end;
  { 全部成功才接管并翻转状态读数 }
  FLk.Acquire;
  try
    FTransport := LTrans;
    FHaveLen := 0;
    FConnected := True;
    FLastError := '';
  finally
    FLk.Release;
  end;
  FKeepAliveLastMs := 0;               { 新会话立即做一次保活校准 }
end;

procedure TRedisSubscriber.PumpRecvOnce;
var
  LN, LPos: Integer;
  LValue: TRespValue;
  LNeedMore: Boolean;
  LView: TBytes;
begin
  { hole-aware 取消检查：已置停泵位时不再阻塞 Recv，直接让外层
    循环感知停止并进入尾窗口投递 }
  if (atomic_load(FStopping, mo_acquire) <> 0) or FToken.IsCancelled then
    Exit;
  if FHaveLen >= MAX_FRAME_BYTES then
  begin
    MarkDisconnected('frame too large');
    Exit;
  end;
  { 缓冲扩容：有效区接近写满时翻倍 }
  if FHaveLen + 4096 > Length(FRcvBuf) then
    SetLength(FRcvBuf, Length(FRcvBuf) * 2);
  try
    LN := FTransport.Recv(@FRcvBuf[FHaveLen],
      Length(FRcvBuf) - FHaveLen);
  except
    on E: ETimeoutError do
      Exit;                             { deadline 到期：本轮无数据 }
  end;
  if LN <= 0 then
  begin
    MarkDisconnected('transport closed');
    Exit;
  end;
  Inc(FHaveLen, LN);
  { 精确视图解析：resp 解析器以 High(ABuf) 为扫描界，直接扫工作
    缓冲会把压缩后残料区外的陈旧字节误当帧——按有效长度取副本 }
  LView := Copy(FRcvBuf, 0, FHaveLen);
  try
    LPos := 0;
    while LPos < FHaveLen do
    begin
      if not RespTryParse(LView, LPos, LValue, LNeedMore) then
        Break;
      ConsumeFrame(LValue);
    end;
  except
    on E: EDbError do
    begin
      { 协议层破损（对端非 redis / 流错位）：转断线态走重连恢复，
        不让异常杀死泵任务 }
      MarkDisconnected('protocol: ' + E.Message);
      Exit;
    end;
  end;
  if (LPos > 0) and (FTransport <> nil) then
  begin
    { 压缩残料到缓冲头（断线转换后缓冲已弃，无需压缩） }
    if LPos < FHaveLen then
      Move(FRcvBuf[LPos], FRcvBuf[0], FHaveLen - LPos);
    Dec(FHaveLen, LPos);
  end;
end;

procedure TRedisSubscriber.ConsumeFrame(const AValue: TRespValue);
var
  LKindTxt: string;
  LM: TDbRedisMessage;
  LAny: Boolean;
begin
  LAny := False;
  case AValue.Kind of
    rvkArray:
      if Length(AValue.Items) >= 3 then
      begin
        if AValue.Items[0].Kind <> rvkBulk then
          Exit;                        { 形态不符：静默忽略 }
        LKindTxt := RespToStr(AValue.Items[0].Data);
        if LKindTxt = 'message' then
        begin
          if (Length(AValue.Items) <> 3) or
             (AValue.Items[1].Kind <> rvkBulk) or
             (AValue.Items[2].Kind <> rvkBulk) then
            Exit;
          LM.Pattern := '';
          LM.Channel := RespToStr(AValue.Items[1].Data);
          LM.Payload := RespToStr(AValue.Items[2].Data);
          FLk.Acquire;
          try
            EnqueueLocked(LM);
          finally
            FLk.Release;
          end;
          LAny := True;
        end
        else if LKindTxt = 'pmessage' then
        begin
          if (Length(AValue.Items) <> 4) or
             (AValue.Items[1].Kind <> rvkBulk) or
             (AValue.Items[2].Kind <> rvkBulk) or
             (AValue.Items[3].Kind <> rvkBulk) then
            Exit;
          LM.Pattern := RespToStr(AValue.Items[1].Data);
          LM.Channel := RespToStr(AValue.Items[2].Data);
          LM.Payload := RespToStr(AValue.Items[3].Data);
          FLk.Acquire;
          try
            EnqueueLocked(LM);
          finally
            FLk.Release;
          end;
          LAny := True;
        end;
        { else：subscribe/unsubscribe/psubscribe/punsubscribe/pong
          等确认/心跳帧——簿记回执，v1 吸收不外露（单元头同文） }
      end;
    rvkError:
      begin
        { 服务端错误帧（如订阅态误发命令被拒）：诊断可见，不断线——
          连接健康与否由下一轮 Recv 裁决 }
        FLk.Acquire;
        try
          RecordErrorLocked('server error: ' + RespToStr(AValue.Data));
        finally
          FLk.Release;
        end;
      end;
    rvkSimple, rvkInteger, rvkBulk, rvkNull:
      ;                                { 非推送帧：吸收（+OK/PONG 等） }
  end;
  if LAny then
    FData.SetEvent;
end;

procedure TRedisSubscriber.PumpLoop;
var
  LNextRetryMs: Int64;
  LPos: Integer;
  LValue: TRespValue;
  LNeedMore: Boolean;
  LView: TBytes;
begin
  LNextRetryMs := 0;
  try
    PumpLoopBody(LNextRetryMs);
  finally
    { hole-aware 收尾：泵退出前尽力把 FRcvBuf 中已完整到达的帧
      投递进环形队列（不计 Gap），再落存活位并惊动 FData，让
      Receive 尾窗口能取尽余量而非睡满节拍后才察觉 stopped。 }
    if FHaveLen > 0 then
    try
      LView := Copy(FRcvBuf, 0, FHaveLen);
      LPos := 0;
      while LPos < FHaveLen do
      begin
        if not RespTryParse(LView, LPos, LValue, LNeedMore) then
          Break;
        ConsumeFrame(LValue);
      end;
      if LPos > 0 then
      begin
        if LPos < FHaveLen then
          Move(FRcvBuf[LPos], FRcvBuf[0], FHaveLen - LPos);
        Dec(FHaveLen, LPos);
        if FHaveLen < 0 then FHaveLen := 0;
      end;
    except
      FHaveLen := 0;
    end;
    atomic_exchange(FPumpAlive, 0, mo_acq_rel);
    if FData <> nil then FData.SetEvent;
    if FIdle <> nil then FIdle.SetEvent;
  end;
end;

procedure TRedisSubscriber.PumpLoopBody(var ANextRetryMs: Int64);
var
  LCmds: TSubCmdArray;
  I: Integer;
begin
  { 停止两源：析构置 FStopping；消费方 Token.Cancel 走协同取消。
    连接在途时阻塞于带 deadline 的 Recv（≤ 一个 IO deadline 察觉
    停止）；断线退避期阻塞于 FIdle（桥接/析构即时惊动）。 }
  while (atomic_load(FStopping, mo_acquire) = 0) and
        (not FToken.IsCancelled) do
  begin
    if FTransport = nil then
    begin
      if RedisNowMs >= ANextRetryMs then
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
        ANextRetryMs := RedisNowMs +
          Int64(FTickMs) * RECONNECT_TICK_FACTOR;
      end;
      if atomic_load(FStopping, mo_acquire) <> 0 then
        Break;
      FIdle.WaitTimeout(Int64(FTickMs) * 1000000);
      Continue;
    end;
    LCmds := TakeCommands;
    for I := 0 to High(LCmds) do
    begin
      try
        ApplyCommand(LCmds[I]);
      except
        on E: Exception do
        begin
          { 命令失败不致命：诊断入 LastError 可见；连接是否真断
            由下一步 PumpRecvOnce 的结果裁决 }
          FLk.Acquire;
          try
            RecordErrorLocked(E.Message);
          finally
            FLk.Release;
          end;
        end;
      end;
    end;
    if atomic_load(FStopping, mo_acquire) <> 0 then
      Break;
    { 保活与接收的外层兜底：任何漏网异常转断线态，不让任务死亡 }
    try
      KeepAliveTick;
      PumpRecvOnce;                      { 可能就地转断线态 }
    except
      on E: Exception do
        MarkDisconnected(E.Message);
    end;
  end;
end;

function RedisOpenSubscriber(
  const AOptions: TDbRedisConnectOptions): TRedisSubscriber;
begin
  Result := TRedisSubscriber.Create(AOptions);
end;

end.
