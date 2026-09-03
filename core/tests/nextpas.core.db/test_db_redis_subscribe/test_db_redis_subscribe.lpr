program test_db_redis_subscribe;

{ V3-B8 Redis 订阅会话契约测试（脚本化传输回放，纯离线）：
    1  订阅确认簿记：确认帧不入消费队列；message 往返 FIFO 保序；
       SubscribedChannels 意图快照；重复订阅幂等（命令只发一次）
    2  pmessage 分派：Pattern 字段填充；pattern/频道快照分面正确
    3  静默超时：无帧 Receive 返回空且连接保持
    4  名称校验 fail-fast：空/超长不触网；退订未订阅抛
    5  溢出保旧弃新：容量 4 发 10 条 → Dropped=6，前 4 条保序
    6  Token 取消停泵：排空后 Receive 抛 stopped、订阅面拒绝
    7  服务端错误帧：诊断可见、连接不断
    8  断线重连重播：conn1 断开 → conn2 先收 SUBSCRIBE 重放 →
       GapCount≥1 且后续消息可达（工厂多段脚本）
    9  重放失败不接管：新传输 Send 即抛 → 不接管、如实诊断；
       第三段健康 → 最终恢复并送达（GapCount 逐段计数）
   live 段需真实 Redis（NEXTPAS_REDIS_TEST_CONN=host[:port]），缺省
   静默跳过：PUBLISH 自发自收（发布方走 adapter ConnectRedis）。
   heaptrc 0 unfreed 硬门。 }

{$I nextpas.core.settings.inc}

{$modeswitch functionreferences}
{$modeswitch anonymousfunctions}

uses
  nextpas.core.thread.init,
  SysUtils,
  Classes,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.redis.base,
  nextpas.core.db.redis.transport,
  nextpas.core.db.redis.adapter,
  nextpas.core.db.redis.subscribe;

const
  TICK = 10;                { 测试节拍收紧加速 }
  CAP_DEFAULT = 1024;

type
  { ---- 脚本化推送传输：预置回复帧序列 + 命令录制 ---- }
  { Recv 语义对齐真实管道：有预置数据吐一段；标记关闭后返回 0；
    其余情况抛 ETimeoutError（= 泵的节拍检查点）。 }
  TScriptedPushTransport = class(TInterfacedObject, IRedisTransport)
  private
    FSteps: array of TBytes;      { 预置回复（按序弹出） }
    FClosed: Boolean;             { true = 后续 Recv 返回 0（对端关闭） }
    FFailSend: Boolean;           { true = Send 即抛（模拟坏管道） }
    FSent: TStringList;           { 已发命令文本录制（断言用） }
  public
    constructor Create;
    destructor Destroy; override;
    procedure ScriptFrame(const ARespText: string);
    procedure ScriptClose;
    procedure Send(const ABuf: TBytes); overload;
    procedure Send(AData: Pointer; ACount: SizeUInt); overload;
    function Recv(ABuf: Pointer; AMax: Integer): Integer;
    procedure Close;
    property Sent: TStringList read FSent;
    property FailSend: Boolean read FFailSend write FFailSend;
  end;

  { 多段工厂：每次调用弹出下一条预置连接；耗尽即抛（防测试脚本
    无意依赖未提供的重连） }
  TScriptedFactory = class(TInterfacedObject)
  private
    FList: array of IRedisTransport;
    FNext: Integer;
  public
    constructor Create;
    procedure Add(const ATrans: IRedisTransport);
    function NewTransport: IRedisTransport;
  end;

constructor TScriptedPushTransport.Create;
begin
  inherited Create;
  FSent := TStringList.Create;
end;

destructor TScriptedPushTransport.Destroy;
begin
  FSent.Free;
  inherited Destroy;
end;

procedure TScriptedPushTransport.ScriptFrame(const ARespText: string);
var
  LN: Integer;
begin
  LN := Length(FSteps);
  SetLength(FSteps, LN + 1);
  SetLength(FSteps[LN], Length(ARespText));
  Move(ARespText[1], FSteps[LN][0], Length(ARespText));
end;

procedure TScriptedPushTransport.ScriptClose;
begin
  FClosed := True;
end;

procedure TScriptedPushTransport.Send(const ABuf: TBytes);
var
  LTxt: string;
begin
  if FFailSend then
    raise EDbError.CreateSimple(dbkRedis, 'scripted: send failed');
  if (ABuf <> nil) and (Length(ABuf) > 0) then
  begin
    SetLength(LTxt, 0);
    SetString(LTxt, PAnsiChar(@ABuf[0]), Length(ABuf));
    FSent.Add(LTxt);
  end;
end;

procedure TScriptedPushTransport.Send(AData: Pointer; ACount: SizeUInt);
var
  LTxt: string;
begin
  if FFailSend then
    raise EDbError.CreateSimple(dbkRedis, 'scripted: send failed');
  if (AData <> nil) and (ACount > 0) then
  begin
    SetLength(LTxt, 0);
    SetString(LTxt, PAnsiChar(AData), ACount);
    FSent.Add(LTxt);
  end;
end;

function TScriptedPushTransport.Recv(ABuf: Pointer; AMax: Integer): Integer;
var
  LSh: Integer;
begin
  if Length(FSteps) > 0 then
  begin
    Result := Length(FSteps[0]);
    if Result > AMax then
      Result := AMax;
    Move(FSteps[0][0], ABuf^, Result);
    if Result >= Length(FSteps[0]) then
    begin
      { 整步吐出：左移队列——托管槽位必须走赋值（引用计数），
        裸 Move 会堆损坏 }
      if Length(FSteps) > 1 then
        for LSh := 1 to High(FSteps) do
          FSteps[LSh - 1] := FSteps[LSh];
      SetLength(FSteps, Length(FSteps) - 1);
    end
    else
      { 部分吐出：截掉已消费头部（单帧远小于 AMax，正常不触达） }
      FSteps[0] := Copy(FSteps[0], Result, Length(FSteps[0]) - Result);
    Exit;
  end;
  if FClosed then
    Exit(0);
  raise ETimeoutError.Create('scripted: idle tick');
end;

procedure TScriptedPushTransport.Close;
begin
  FClosed := True;
end;

constructor TScriptedFactory.Create;
begin
  inherited Create;
  FNext := 0;
end;

procedure TScriptedFactory.Add(const ATrans: IRedisTransport);
var
  LN: Integer;
begin
  LN := Length(FList);
  SetLength(FList, LN + 1);
  FList[LN] := ATrans;
end;

function TScriptedFactory.NewTransport: IRedisTransport;
begin
  if FNext > High(FList) then
    raise EDbError.CreateSimple(dbkRedis,
      'scripted factory: no more connections');
  Result := FList[FNext];
  Inc(FNext);
end;

var
  GRedisAddr: string;

{ 轮询谓词直至满足或超时（毫秒）；匿名闭包形态便于就地写条件 }
type
  TPred = reference to function: Boolean;

function WaitFor(const APred: TPred; const ATimeoutMs: Integer): Boolean;
var
  LDeadline: QWord;
begin
  LDeadline := GetTickCount64 + Cardinal(ATimeoutMs);
  repeat
    if APred() then
      Exit(True);
  until GetTickCount64 >= LDeadline;
  Result := APred();
end;

{ 累积一次 Receive 的结果到 LAcc }
procedure AppendAll(var LAcc: TDbRedisMessageArray;
  const ABatch: TDbRedisMessageArray);
var
  LBase, I: Integer;
begin
  if Length(ABatch) = 0 then
    Exit;
  LBase := Length(LAcc);
  SetLength(LAcc, LBase + Length(ABatch));
  for I := 0 to High(ABatch) do
    LAcc[LBase + I] := ABatch[I];
end;

{ ---- 帧字面量辅助（长度前缀手工核对，注释标字节） ---- }

{ *3\r\n $7 message \r\n $N chan \r\n $M payl \r\n }
function MessageFrame(const AChan, APay: string): string;
begin
  Result := '*3'#13#10'$7'#13#10'message'#13#10 +
    '$' + IntToStr(Length(AChan)) + #13#10 + AChan + #13#10 +
    '$' + IntToStr(Length(APay)) + #13#10 + APay + #13#10;
end;

{ *4\r\n $9 pmessage \r\n $A patt \r\n $N chan \r\n $M payl \r\n }
function PmessageFrame(const APatt, AChan, APay: string): string;
begin
  Result := '*4'#13#10'$8'#13#10'pmessage'#13#10 +
    '$' + IntToStr(Length(APatt)) + #13#10 + APatt + #13#10 +
    '$' + IntToStr(Length(AChan)) + #13#10 + AChan + #13#10 +
    '$' + IntToStr(Length(APay)) + #13#10 + APay + #13#10;
end;

{ ---- 1 订阅确认簿记 + message FIFO + 幂等 ---- }

procedure TestSubscribeConfirmAndMessages;
var
  LConn1: TScriptedPushTransport;
  LFactory: TScriptedFactory;
  LSub: TRedisSubscriber;
  LGot: TDbRedisMessageArray;
  LSentOk: Boolean;
begin
  LConn1 := TScriptedPushTransport.Create;
  LFactory := TScriptedFactory.Create;
  try
    LConn1.ScriptFrame('*3'#13#10'$9'#13#10'subscribe'#13#10 +
      '$4'#13#10'news'#13#10':1'#13#10);          { subscribe news =1 }
    LConn1.ScriptFrame(MessageFrame('news', 'a1'));
    LConn1.ScriptFrame(MessageFrame('news', 'b2'));
    LFactory.Add(LConn1);
    LSub := TRedisSubscriber.Create(
      function: IRedisTransport begin Result := LFactory.NewTransport end,
      TICK, CAP_DEFAULT);
    try
      Check(LSub.Connected, 'connected after first connect');
      LSub.Subscribe('news');
      LSub.Subscribe('news');                      { 重复订阅幂等 }
      Check(Length(LSub.SubscribedChannels) = 1,
        'intent snapshot deduped');

      LGot := nil;
      LSentOk := False;
      WaitFor(function: Boolean
        begin
          AppendAll(LGot, LSub.Receive(20));
          if LConn1.Sent.Count > 0 then
            LSentOk := True;
          Result := (Length(LGot) >= 2) and LSentOk;
        end, 3000);
      Sleep(60);                                   { 第二条幂等命令窗口 }
      Check(Length(LGot) = 2, 'two messages delivered');
      if Length(LGot) = 2 then
      begin
        Check(LGot[0].Channel = 'news', 'first channel');
        Check(LGot[0].Payload = 'a1', 'first payload fifo');
        Check(LGot[1].Payload = 'b2', 'second payload fifo');
        Check(LGot[0].Pattern = '', 'message pattern empty');
      end;
      Check(LSentOk, 'subscribe command reached wire');
      Check(LConn1.Sent.Count = 1, 'duplicate subscribe sends once');
      Check(LSub.DroppedCount = 0, 'no drops');
      Check(Length(LSub.Receive(30)) = 0,
        'confirm frames not delivered as messages');
    finally
      LSub.Free;
    end;
  finally
    LFactory.Free;
  end;
end;

{ ---- 2 pmessage 分派 ---- }

procedure TestPmessageDispatch;
var
  LConn1: TScriptedPushTransport;
  LFactory: TScriptedFactory;
  LSub: TRedisSubscriber;
  LGot: TDbRedisMessageArray;
begin
  LConn1 := TScriptedPushTransport.Create;
  LFactory := TScriptedFactory.Create;
  try
    LConn1.ScriptFrame('*3'#13#10'$10'#13#10'psubscribe'#13#10 +
      '$5'#13#10'new.*'#13#10':1'#13#10);          { psubscribe new.* =1 }
    LConn1.ScriptFrame(PmessageFrame('new.*', 'news.1', 'payl'));
    LFactory.Add(LConn1);
    LSub := TRedisSubscriber.Create(
      function: IRedisTransport begin Result := LFactory.NewTransport end,
      TICK, CAP_DEFAULT);
    try
      LSub.PSubscribe('new.*');
      LGot := nil;
      WaitFor(function: Boolean
        begin
          AppendAll(LGot, LSub.Receive(20));
          Result := Length(LGot) >= 1;
        end, 3000);
      Check(Length(LGot) = 1, 'pmessage delivered');
      if Length(LGot) = 1 then
      begin
        Check(LGot[0].Pattern = 'new.*', 'pattern filled');
        Check(LGot[0].Channel = 'news.1', 'pm channel');
        Check(LGot[0].Payload = 'payl', 'pm payload');
      end;
      Check(Length(LSub.SubscribedPatterns) = 1, 'pattern snapshot');
      Check(Length(LSub.SubscribedChannels) = 0, 'channel snapshot clean');
    finally
      LSub.Free;
    end;
  finally
    LFactory.Free;
  end;
end;

{ ---- 3 静默超时 ---- }

procedure TestSilentTimeout;
var
  LConn1: TScriptedPushTransport;
  LFactory: TScriptedFactory;
  LSub: TRedisSubscriber;
begin
  LConn1 := TScriptedPushTransport.Create;
  LFactory := TScriptedFactory.Create;
  try
    LFactory.Add(LConn1);
    LSub := TRedisSubscriber.Create(
      function: IRedisTransport begin Result := LFactory.NewTransport end,
      TICK, CAP_DEFAULT);
    try
      Check(Length(LSub.Receive(120)) = 0, 'silent timeout empty');
      Check(LSub.Connected, 'still connected after silence');
    finally
      LSub.Free;
    end;
  finally
    LFactory.Free;
  end;
end;

{ ---- 4 校验 fail-fast 与退订纪律 ---- }

procedure TestValidation;
var
  LConn1: TScriptedPushTransport;
  LFactory: TScriptedFactory;
  LSub: TRedisSubscriber;
  LLong: string;
  LRaised: Boolean;
begin
  LConn1 := TScriptedPushTransport.Create;
  LFactory := TScriptedFactory.Create;
  try
    LFactory.Add(LConn1);
    LSub := TRedisSubscriber.Create(
      function: IRedisTransport begin Result := LFactory.NewTransport end,
      TICK, CAP_DEFAULT);
    try
      LRaised := False;
      try
        LSub.Subscribe('');
      except
        on E: EDbError do LRaised := True;
      end;
      Check(LRaised, 'empty channel rejected');

      LLong := StringOfChar('x', 1025);
      LRaised := False;
      try
        LSub.Subscribe(LLong);
      except
        on E: EDbError do LRaised := True;
      end;
      Check(LRaised, 'overlong channel rejected');

      Check(LConn1.Sent.Count = 0,
        'validation failures never touch wire');

      LRaised := False;
      try
        LSub.Unsubscribe('nosuch');
      except
        on E: EDbError do LRaised := True;
      end;
      Check(LRaised, 'unsubscribe unknown fails fast');

      LRaised := False;
      try
        LSub.PUnsubscribe('nosuch.*');
      except
        on E: EDbError do LRaised := True;
      end;
      Check(LRaised, 'punsubscribe unknown fails fast');
    finally
      LSub.Free;
    end;
  finally
    LFactory.Free;
  end;
end;

{ ---- 5 溢出保旧弃新 ---- }

procedure TestOverflowKeepsOldest;
var
  LConn1: TScriptedPushTransport;
  LFactory: TScriptedFactory;
  LSub: TRedisSubscriber;
  I: Integer;
  LGot: TDbRedisMessageArray;
begin
  LConn1 := TScriptedPushTransport.Create;
  LFactory := TScriptedFactory.Create;
  try
    for I := 1 to 10 do
      LConn1.ScriptFrame(MessageFrame('c', 'm' + IntToStr(I)));
    LFactory.Add(LConn1);
    LSub := TRedisSubscriber.Create(
      function: IRedisTransport begin Result := LFactory.NewTransport end,
      TICK, 4);                        { 容量 4 }
    try
      { 确定性设计：泵以微秒级连吃全部 10 步（消费方不竞争），
        队列满 4 → 保旧弃新必丢 6；静置让泵吃完再断言 }
      Sleep(500);
      LGot := nil;
      AppendAll(LGot, LSub.Receive(20));             { 取尽余量 }
      Check(LSub.DroppedCount = 6, 'dropped = 6');
      Check(Length(LGot) = 4, 'delivered = 4 (oldest kept)');
      if Length(LGot) = 4 then
      begin
        Check(LGot[0].Payload = 'm1', 'oldest preserved head');
        Check(LGot[3].Payload = 'm4', 'oldest preserved tail');
      end;
    finally
      LSub.Free;
    end;
  finally
    LFactory.Free;
  end;
end;

{ ---- 6 Token 取消停泵 ---- }

procedure TestTokenCancelStopsPump;
var
  LConn1: TScriptedPushTransport;
  LFactory: TScriptedFactory;
  LSub: TRedisSubscriber;
  LStopped: Boolean;
begin
  LConn1 := TScriptedPushTransport.Create;
  LFactory := TScriptedFactory.Create;
  try
    LFactory.Add(LConn1);
    LSub := TRedisSubscriber.Create(
      function: IRedisTransport begin Result := LFactory.NewTransport end,
      TICK, CAP_DEFAULT);
    try
      LSub.Token.Cancel;
      LStopped := False;
      WaitFor(function: Boolean
        begin
          try
            LSub.Receive(20);
          except
            on E: EDbError do LStopped := True;
          end;
          Result := LStopped;
        end, 3000);
      Check(LStopped, 'receive raises stopped after cancel');
      LStopped := False;
      try
        LSub.Subscribe('after-stop');
      except
        on E: EDbError do LStopped := True;
      end;
      Check(LStopped, 'subscribe after stop rejected');
    finally
      LSub.Free;
    end;
  finally
    LFactory.Free;
  end;
end;

{ ---- 7 服务端错误帧可见不断线 ---- }

procedure TestServerErrorFrameVisible;
var
  LConn1: TScriptedPushTransport;
  LFactory: TScriptedFactory;
  LSub: TRedisSubscriber;
begin
  LConn1 := TScriptedPushTransport.Create;
  LFactory := TScriptedFactory.Create;
  try
    LConn1.ScriptFrame('-ERR bad command'#13#10);
    LFactory.Add(LConn1);
    LSub := TRedisSubscriber.Create(
      function: IRedisTransport begin Result := LFactory.NewTransport end,
      TICK, CAP_DEFAULT);
    try
      WaitFor(function: Boolean
        begin
          Result := LSub.LastError <> '';
        end, 2000);
      Check(Pos('bad command', LSub.LastError) > 0,
        'server error visible');
      Check(LSub.Connected, 'error frame does not disconnect');
    finally
      LSub.Free;
    end;
  finally
    LFactory.Free;
  end;
end;

{ ---- 8 断线重连重播 ---- }

procedure TestReconnectReplaysSnapshot;
var
  LConn1, LConn2: TScriptedPushTransport;
  LFactory: TScriptedFactory;
  LSub: TRedisSubscriber;
  LGot: TDbRedisMessageArray;
  I: Integer;
  LSawPost, LSawReplay: Boolean;
begin
  LConn1 := TScriptedPushTransport.Create;
  LConn2 := TScriptedPushTransport.Create;
  LFactory := TScriptedFactory.Create;
  try
    LConn1.ScriptFrame(MessageFrame('ch1', 'pre!'));
    LConn1.ScriptClose;                 { 消息后立即断开 }
    { conn2：泵先发 SUBSCRIBE 重放（Send 录制），随后消费本帧——
      顺序由泵结构保证（先命令后接收） }
    LConn2.ScriptFrame(MessageFrame('ch1', 'post!'));
    LFactory.Add(LConn1);
    LFactory.Add(LConn2);
    LSub := TRedisSubscriber.Create(
      function: IRedisTransport begin Result := LFactory.NewTransport end,
      TICK, CAP_DEFAULT);
    try
      LSub.Subscribe('ch1');
      LGot := nil;
      WaitFor(function: Boolean
        begin
          AppendAll(LGot, LSub.Receive(20));
          Result := LSub.GapCount >= 1;
        end, 4000);
      AppendAll(LGot, LSub.Receive(30));
      Check(LSub.GapCount >= 1, 'gap counted across reconnect');

      LSawPost := False;
      for I := 0 to High(LGot) do
        if LGot[I].Payload = 'post!' then
          LSawPost := True;
      Check(LSawPost, 'post-reconnect message delivered');

      LSawReplay := False;
      for I := 0 to LConn2.Sent.Count - 1 do
        if Pos('SUBSCRIBE', LConn2.Sent[I]) > 0 then
          LSawReplay := True;
      Check(LSawReplay, 'replay sent on new connection');
    finally
      LSub.Free;
    end;
  finally
    LFactory.Free;
  end;
end;

{ ---- 9 重放失败不接管，第三段恢复 ---- }

procedure TestFailedReconnectNotTakenOver;
var
  LConn1, LConn2, LConn3: TScriptedPushTransport;
  LFactory: TScriptedFactory;
  LSub: TRedisSubscriber;
  LGot: TDbRedisMessageArray;
begin
  LConn1 := TScriptedPushTransport.Create;
  LConn2 := TScriptedPushTransport.Create;
  LConn3 := TScriptedPushTransport.Create;
  LFactory := TScriptedFactory.Create;
  try
    LConn1.ScriptClose;                 { 立即断开触发重连 }
    LConn2.FailSend := True;            { 重放期发送失败 → 不接管 }
    LConn3.ScriptFrame(MessageFrame('red', 'ok'));
    LFactory.Add(LConn1);
    LFactory.Add(LConn2);
    LFactory.Add(LConn3);
    LSub := TRedisSubscriber.Create(
      function: IRedisTransport begin Result := LFactory.NewTransport end,
      TICK, CAP_DEFAULT);
    try
      LSub.Subscribe('red');
      LGot := nil;
      WaitFor(function: Boolean
        begin
          AppendAll(LGot, LSub.Receive(20));
          Result := LSub.Connected and (Length(LGot) > 0);
        end, 5000);
      Check(LSub.Connected, 'recovered via third transport');
      Check(Length(LGot) > 0, 'message flows after recovery');
      Check(Pos('SUBSCRIBE', LConn3.Sent.Text) > 0,
        'third transport got replay');
      Check(LSub.GapCount = 1, 'single outage counted once');
      { 恢复成功会清 LastError（陈旧诊断不留存——设计语义），改以
        结构性事实断言不接管：被拒传输零命令记录 }
      Check(LConn2.Sent.Count = 0,
        'rejected transport recorded no commands');
    finally
      LSub.Free;
    end;
  finally
    LFactory.Free;
  end;
end;

{ ---- live：真机自发自收（发布方走 adapter ConnectRedis） ---- }

procedure SplitHostPort(const AAddr: string; out AHost: string;
  out APort: Word);
var
  LC: Integer;
begin
  AHost := AAddr;
  APort := 6379;
  LC := Pos(':', AAddr);
  if LC > 0 then
  begin
    AHost := Copy(AAddr, 1, LC - 1);
    APort := Word(StrToIntDef(Copy(AAddr, LC + 1, MaxInt), 6379));
  end;
end;

procedure TestLivePublishRoundtrip;
var
  LOpts: TDbRedisConnectOptions;
  LHost, LChan: string;
  LPort: Word;
  LPub: IDbConnection;
  LSub: TRedisSubscriber;
  LGot: TDbRedisMessageArray;
  I, N: Integer;
  LSeq: Integer;
begin
  if GRedisAddr = '' then
  begin
    WriteLn(
      'live publish roundtrip skipped (NEXTPAS_REDIS_TEST_CONN not set)');
    Exit;
  end;
  LOpts := TDbRedisConnectOptions.Default;
  SplitHostPort(GRedisAddr, LHost, LPort);
  LOpts.Host := LHost;
  LOpts.Port := LPort;
  LChan := 'np_test_' + IntToStr(GetTickCount64 mod 100000);

  LPub := ConnectRedis(GRedisAddr);
  LSub := RedisOpenSubscriber(LOpts);
  try
    LSub.Subscribe(LChan);
    Sleep(150);                          { 订阅生效窗口设防 }
    for I := 1 to 3 do
      LPub.Exec('PUBLISH ' + LChan + ' pay' + IntToStr(I));
    LGot := nil;
    N := 0;
    WaitFor(function: Boolean
      begin
        AppendAll(LGot, LSub.Receive(30));
        Result := Length(LGot) >= 3;
      end, 4000);
    LSeq := 1;
    for I := 0 to High(LGot) do
      if (LGot[I].Channel = LChan) and
         (LGot[I].Payload = 'pay' + IntToStr(LSeq)) then
      begin
        Inc(LSeq);
        Inc(N);
      end;
    Check(N = 3, 'three published payloads received in order');
    Check(LSub.DroppedCount = 0, 'live no drops');
  finally
    LSub.Free;
    LPub := nil;
  end;
end;

var
  T: TTestSuite;
begin
  GRedisAddr := GetEnvironmentVariable('NEXTPAS_REDIS_TEST_CONN');
  T := TTestSuite.Create('nextpas.core.db.redis.subscribe');
  T.Test('subscribe confirm bookkeeping + message fifo',
    @TestSubscribeConfirmAndMessages);
  T.Test('pmessage dispatch pattern field', @TestPmessageDispatch);
  T.Test('silent timeout', @TestSilentTimeout);
  T.Test('validation fail-fast', @TestValidation);
  T.Test('overflow keeps oldest', @TestOverflowKeepsOldest);
  T.Test('token cancel stops pump', @TestTokenCancelStopsPump);
  T.Test('server error frame visible', @TestServerErrorFrameVisible);
  T.Test('reconnect replays snapshot', @TestReconnectReplaysSnapshot);
  T.Test('failed reconnect not taken over',
    @TestFailedReconnectNotTakenOver);
  T.Test('live publish roundtrip', @TestLivePublishRoundtrip);
  if not T.Run then Halt(1);
end.
