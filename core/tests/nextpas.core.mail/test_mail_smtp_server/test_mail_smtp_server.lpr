program test_mail_smtp_server;

{ 批次 2：事件驱动 SMTP 服务器会话（mail.smtp.server）集成测试。
  覆盖：banner、EHLO 能力列表、HELO、MAIL/RCPT/DATA 全流程与点转义、
  SIZE 拒绝、RCPT 先于 MAIL、DATA 缺收件人、未知命令、VRFY/EXPN、
  STARTTLS 探测拒、AUTH 未启用拒、RequireAuth、收件人上限、QUIT 关闭、
  读空闲超时、出站队列溢出中止。

  服务器走 epoll readiness 路径（Linux），客户端用 mail.smtp 客户端与
  裸 TcpConnect 行协议。sink 计数经 SpinWait 由主线程观察（与
  test_net_server_ws_session 同范式，无锁）。 }

{$I nextpas.core.settings.inc}

{$IF not defined(NEXTPAS_LINUX)}
  {$ERROR test_mail_smtp_server requires the Linux epoll backend}
{$ENDIF}

uses
  nextpas.core.thread.init,
  Classes,
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.net.server,
  nextpas.core.platform.thread,
  nextpas.core.text.conv,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.mail;

type
  PServerFixture = ^TServerFixture;
  TServerFixture = record
    Server: ITcpServer;
    Handler: ITcpServerHandler;
    Addr: string;
    Port: UInt16;
  end;

  { 测试 sink：仅由 reactor 线程回调；计数字段在主线程经等待循环观察
    （与 test_net_server_ws_session 既有范式一致，无锁）。 }
  TTestSmtpSink = class(TInterfacedObject, ISmtpServerSink)
  public
    MsgCount: Int32;
    TimeoutCount: Int32;
    OverflowCount: Int32;
    ClosedCount: Int32;
    LastFrom: string;
    LastRcptCount: Int32;
    LastData: string;
    LastClientIP: string;
    LastClosedIP: string;
    constructor Create;
    procedure OnServerEvent(const AEvent: TMailSmtpServerEvent;
      const AEnvelope: TMailSmtpEnvelope);
  end;

  TTestSmtpHandler = class(TInterfacedObject, ITcpServerHandler,
    ITcpServerSessionFactoryWithContext)
  public
    CreateCount: Int32;
    ServeConnCalled: Boolean;
    constructor Create(const ASink: TTestSmtpSink;
      const AConfig: TMailSmtpServerConfig);
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream;
      const AContext: ITcpServerSessionContext): ITcpServerSession;
  private
    FSinkObj: TTestSmtpSink;
    FSink: ISmtpServerSink;
    FConfig: TMailSmtpServerConfig;
  end;

  { MAIL/RCPT 策略钩子 mock：可切换放行/拒绝，记录调用与入参 }
  TTestMailPolicy = class(TInterfacedObject, ISmtpMailPolicyHook)
  public
    RejectReply: string;       { '' = 放行 MAIL; 非空 = 完整拒绝行(含 CRLF) }
    RcptRejectReply: string;   { '' = 放行 RCPT; 非空 = 完整拒绝行(含 CRLF) }
    Calls: Int32;              { EvaluateMailFrom 次数 }
    RcptCalls: Int32;          { EvaluateRcptTo 次数 }
    LastFrom: string;
    LastRcpt: string;
    LastIP: string;
    constructor Create;
    function EvaluateMailFrom(const AFrom: TMailAddress;
      const AClientIP: string): string;
    function EvaluateRcptTo(const AFrom: TMailAddress; const ARcpt: TMailAddress;
      const AClientIP: string): string;
  end;

{ 服务器线程：ListenAndServe 阻塞运行，退出时释放引用 }
function ServerThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PServerFixture;
begin
  Result := nil;
  LCtx := PServerFixture(AArg);
  try
    LCtx^.Server.ListenAndServe(LCtx^.Addr, LCtx^.Port, LCtx^.Handler);
  finally
    LCtx^.Server := nil;
    LCtx^.Handler := nil;
    Dispose(LCtx);
  end;
end;

{ 启动 epoll 事件驱动 SMTP 服务器（factory → poll-driven 会话路径）。 }
procedure StartSmtpServer(const ASink: TTestSmtpSink;
  const AConfig: TMailSmtpServerConfig; out AServer: ITcpServer;
  out AHandler: TTestSmtpHandler; out AThread: TPlatformThreadHandle);
var
  LCtx: PServerFixture;
  LOptions: TTcpServerOptions;
  LWait: Int32;
begin
  AHandler := TTestSmtpHandler.Create(ASink, AConfig);
  LOptions := TTcpServerOptions.Default;
  LOptions.Backend := TCP_SERVER_BACKEND_EPOLL;
  AServer := NewTcpServer(LOptions);
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Handler := AHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(AThread, @ServerThreadFunc, LCtx);
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 600) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  Check(AServer.IsRunning, 'smtp server should start');
  Check(AServer.LocalAddr.Port > 0, 'smtp server exposes bound port');
end;

{ 停止服务器并回收线程 }
procedure StopSmtpServer(var AServer: ITcpServer; const AThread: TPlatformThreadHandle);
var
  LRet: Pointer;
begin
  if AServer <> nil then
    AServer.Shutdown;
  platform_thread_join(AThread, LRet);
  AServer := nil;
end;

{ 等待某计数达到目标（5ms 步进，最大 3s）。 }
function SpinWait(var AValue: Int32; const ATarget: Int32): Boolean;
var
  I: Int32;
begin
  Result := False;
  for I := 1 to 600 do
  begin
    if AValue >= ATarget then
      Exit(True);
    platform_thread_sleep_ns(5000000);
  end;
end;

{ ── 裸行协议客户端助手 ───────────────────────────────────────────── }

type
  TRawClient = record
    Stream: ITcpStream;
    function Open(const APort: UInt16): Boolean;
    function ReadLine(const ATimeoutMs: Int64; out ALine: string): Boolean;
    function SendLine(const ALine: string): Boolean;
    procedure Close;
  end;

function TRawClient.Open(const APort: UInt16): Boolean;
begin
  try
    Stream := TcpConnect('127.0.0.1', APort, 2000);
    Result := True;
  except
    Result := False;
  end;
end;

function TRawClient.ReadLine(const ATimeoutMs: Int64; out ALine: string): Boolean;
var
  LB: TBytes;
  LCap: Integer;
  LRaw: Byte;
begin
  Result := False;
  ALine := '';
  SetLength(LB, 256);
  LCap := 0;
  try
    if ATimeoutMs > 0 then
      Stream.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs)))
    else
      Stream.SetReadDeadline(TDeadline.Infinite);
    while True do
    begin
      LRaw := 0;
      if Stream.Read(LRaw, 1) = 0 then
        Exit;
      if LRaw = 10 then
        Break;
      if LRaw <> 13 then
      begin
        if LCap >= Length(LB) then
          SetLength(LB, LCap * 2);
        LB[LCap] := LRaw;
        Inc(LCap);
      end;
    end;
    SetLength(LB, LCap);
    ALine := ASCIIBytesToString(LB);
    Result := True;
  except
    Result := False;
  end;
end;

function TRawClient.SendLine(const ALine: string): Boolean;
var
  LB: TBytes;
begin
  try
    LB := StringToUTF8Bytes(ALine + #13#10);
    Stream.Write(LB[0], Length(LB));
    Result := True;
  except
    Result := False;
  end;
end;

procedure TRawClient.Close;
begin
  if Stream <> nil then
    try
      Stream.Close;
    except
    end;
  Stream := nil;
end;

{ 读横幅并断言 220 }
procedure ExpectBanner(const C: TRawClient; const ATimeoutMs: Int64);
var
  LLine: string;
begin
  Check(C.ReadLine(ATimeoutMs, LLine), 'banner read');
  Check(Copy(LLine, 1, 3) = '220', 'banner 220, got: ' + LLine);
end;

{ 读单行回复并断言码 }
procedure ExpectReply(const C: TRawClient; const ATimeoutMs: Int64;
  const ACode: string; const AWhat: string);
var
  LLine: string;
begin
  Check(C.ReadLine(ATimeoutMs, LLine), 'reply read for ' + AWhat);
  Check(Copy(LLine, 1, 3) = ACode,
    AWhat + ' expects ' + ACode + ', got: ' + LLine);
end;

{ 读多行回复直到非 '-' 结尾行；断言最终码；返回是否含某能力行 }
function ExpectMultiLine(const C: TRawClient; const ATimeoutMs: Int64;
  const ACode: string; const ACapPrefix: string; const AWhat: string): Boolean;
var
  LLine: string;
begin
  Result := False;
  while True do
  begin
    Check(C.ReadLine(ATimeoutMs, LLine), 'multiline reply read for ' + AWhat);
    Check(Copy(LLine, 1, 3) = ACode, AWhat + ' expects ' + ACode + ', got: ' + LLine);
    if Copy(LLine, 4, 1) = '-' then
    begin
      if Pos(ACapPrefix, Copy(LLine, 5, Length(LLine) - 4)) = 1 then
        Result := True;
      Continue;
    end;
    Break;
  end;
end;

{ ── 事件类型 ──────────────────────────────────────────────────────── }

constructor TTestSmtpSink.Create;
begin
  inherited Create;
end;

procedure TTestSmtpSink.OnServerEvent(const AEvent: TMailSmtpServerEvent;
  const AEnvelope: TMailSmtpEnvelope);
begin
  case AEvent of
    msseMessage:
      begin
        Inc(MsgCount);
        LastFrom := AEnvelope.From.Full;
        LastRcptCount := Length(AEnvelope.Recipients);
        LastData := UTF8BytesToString(AEnvelope.Data);
        LastClientIP := AEnvelope.ClientIP;
      end;
    msseTimeout:
      Inc(TimeoutCount);
    msseOverflow:
      Inc(OverflowCount);
    msseClosed:
      begin
        Inc(ClosedCount);
        LastClosedIP := AEnvelope.ClientIP;
      end;
  end;
end;

constructor TTestSmtpHandler.Create(const ASink: TTestSmtpSink;
  const AConfig: TMailSmtpServerConfig);
begin
  inherited Create;
  FSinkObj := ASink;
  FSink := ASink;
  FConfig := AConfig;
end;

function TTestSmtpHandler.ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
begin
  { factory 路径应绕过 legacy ServeConn（对齐 ws 测试断言） }
  ServeConnCalled := True;
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

function TTestSmtpHandler.NewSession(const AConn: ITcpStream;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
begin
  Inc(CreateCount);
  Result := TMailSmtpServerSession.Create(AConn, FSink, FConfig);
end;

constructor TTestMailPolicy.Create;
begin
  inherited Create;
  RejectReply := '';
  RcptRejectReply := '';
end;

function TTestMailPolicy.EvaluateMailFrom(const AFrom: TMailAddress;
  const AClientIP: string): string;
begin
  Inc(Calls);
  LastFrom := AFrom.Full;
  LastIP := AClientIP;
  Result := RejectReply;
end;

function TTestMailPolicy.EvaluateRcptTo(const AFrom: TMailAddress;
  const ARcpt: TMailAddress; const AClientIP: string): string;
begin
  Inc(RcptCalls);
  LastFrom := AFrom.Full;
  LastRcpt := ARcpt.Full;
  LastIP := AClientIP;
  Result := RcptRejectReply;
end;

{ ── 测试用例 ──────────────────────────────────────────────────────── }

function MakeConfig(APort: UInt16; AIoMs, AConnectMs: Int64): TSmtpClientConfig;
begin
  Result.Host := '127.0.0.1';
  Result.Port := APort;
  Result.HeloDomain := '';
  Result.ConnectTimeoutMs := AConnectMs;
  Result.IoTimeoutMs := AIoMs;
end;

procedure Test_Full;
var
  LH: TPlatformThreadHandle;
  LServer: ITcpServer;
  LHandler: TTestSmtpHandler;
  LSink: TTestSmtpSink;
  LConfig: TMailSmtpServerConfig;
  LPort: UInt16;
  C: TRawClient;
begin
  LSink := TTestSmtpSink.Create;
  LConfig := TMailSmtpServerConfig.Default;
  StartSmtpServer(LSink, LConfig, LServer, LHandler, LH);
  LPort := LServer.LocalAddr.Port;

  { EHLO 能力列表 }
  C.Open(LPort);
  ExpectBanner(C, 2000);
  C.SendLine('EHLO test.example');
  Check(ExpectMultiLine(C, 2000, '250', '8BITMIME', 'EHLO caps'), '8BITMIME advertised');
  // PIPELINING + SIZE 也应出现
  C.SendLine('QUIT');
  ExpectReply(C, 2000, '221', 'QUIT');
  C.Close;
  Check(SpinWait(LSink.ClosedCount, 1), 'closed after quit');

  StopSmtpServer(LServer, LH);
  LHandler := nil;
  LSink := nil;
end;

procedure StartFixture(const AConfig: TMailSmtpServerConfig;
  const ASink: TTestSmtpSink; out AServer: ITcpServer;
  out AHandler: TTestSmtpHandler; out AThread: TPlatformThreadHandle;
  out APort: UInt16);
begin
  StartSmtpServer(ASink, AConfig, AServer, AHandler, AThread);
  APort := AServer.LocalAddr.Port;
end;

procedure TestHelloCommands;
var
  LH: TPlatformThreadHandle;
  LServer: ITcpServer;
  LHandler: TTestSmtpHandler;
  LSink: TTestSmtpSink;
  LConfig: TMailSmtpServerConfig;
  LPort: UInt16;
  C: TRawClient;
  LLine: string;
begin
  LSink := TTestSmtpSink.Create;
  LConfig := TMailSmtpServerConfig.Default;
  StartFixture(LConfig, LSink, LServer, LHandler, LH, LPort);

  C.Open(LPort);
  ExpectBanner(C, 2000);
  C.SendLine('HELO old.example');
  ExpectReply(C, 2000, '250', 'HELO');
  C.SendLine('QUIT');
  ExpectReply(C, 2000, '221', 'QUIT2');
  C.Close;
  Check(SpinWait(LSink.ClosedCount, 1), 'closed after quit2');

  StopSmtpServer(LServer, LH);
  LSink := nil;
end;

procedure TestMailRcptDataFlow;
var
  LH: TPlatformThreadHandle;
  LServer: ITcpServer;
  LHandler: TTestSmtpHandler;
  LSink: TTestSmtpSink;
  LConfig: TMailSmtpServerConfig;
  LPort: UInt16;
  LClient: TSmtpClient;
  LFrom: TMailAddress;
  LTo: TMailAddressArray;
  LData: string;
begin
  LSink := TTestSmtpSink.Create;
  LConfig := TMailSmtpServerConfig.Default;
  StartFixture(LConfig, LSink, LServer, LHandler, LH, LPort);

  { 用 mail.smtp 客户端走完整会话：EHLO/MAIL/RCPT/DATA（点转义）/QUIT }
  LClient := TSmtpClient.Create(MakeConfig(LPort, 2000, 2000));
  try
    Check(LClient.TryConnect, 'client connect');
    LFrom := TMailAddress.Parse('alice@example.com');
    SetLength(LTo, 2);
    LTo[0] := TMailAddress.Parse('bob@example.com');
    LTo[1] := TMailAddress.Parse('carol@example.com');
    LData := 'From: alice@example.com' + #13#10 +
             'To: bob@example.com' + #13#10 +
             'Subject: test' + #13#10 + #13#10 +
             'line1' + #13#10 +
             '.line' + #13#10 +
             '..double' + #13#10 +
             'end';
    Check(LClient.TrySendMail(LFrom, LTo, LData), 'send mail accepted');
    CheckEqual(250, LClient.LastReply.Code, 'final reply code');
    Check(LClient.TryQuit, 'quit ok');
  finally
    LClient.Free;
  end;

  { 事件交付核验 }
  Check(SpinWait(LSink.MsgCount, 1), 'server received message');
  CheckEqual('alice@example.com', LSink.LastFrom, 'envelope from');
  CheckEqual(2, LSink.LastRcptCount, 'envelope recipients');
  CheckEqual('127.0.0.1', LSink.LastClientIP, 'envelope client ip (loopback peer)');
  { 点转义还原：'.line' 与 '..double' 应原样回到应用 }
  Check(Pos('.line' + #13#10, LSink.LastData) > 0, 'dot unstuff single');
  Check(Pos('..double' + #13#10, LSink.LastData) > 0, 'dot unstuff double');
  { 关闭事件携带对端 IP（批次 9.4：连接生命周期按 IP 归账的前提） }
  Check(SpinWait(LSink.ClosedCount, 1), 'closed event delivered');
  CheckEqual('127.0.0.1', LSink.LastClosedIP, 'closed event carries peer ip');

  StopSmtpServer(LServer, LH);
  LSink := nil;
end;

procedure TestSizeReject;
var
  LH: TPlatformThreadHandle;
  LServer: ITcpServer;
  LHandler: TTestSmtpHandler;
  LSink: TTestSmtpSink;
  LConfig: TMailSmtpServerConfig;
  LPort: UInt16;
  C: TRawClient;
begin
  LSink := TTestSmtpSink.Create;
  LConfig := TMailSmtpServerConfig.Default;
  StartFixture(LConfig, LSink, LServer, LHandler, LH, LPort);

  C.Open(LPort);
  ExpectBanner(C, 2000);
  C.SendLine('EHLO test.example');
  ExpectMultiLine(C, 2000, '250', 'SIZE', 'EHLO');
  C.SendLine('MAIL FROM:<a@b.com> SIZE=99999999999');
  ExpectReply(C, 2000, '552', 'SIZE reject');
  C.SendLine('MAIL FROM:<a@b.com>');
  ExpectReply(C, 2000, '250', 'MAIL ok');
  C.SendLine('QUIT');
  ExpectReply(C, 2000, '221', 'QUIT');
  C.Close;

  StopSmtpServer(LServer, LH);
  LSink := nil;
end;

{ MAIL 阶段同步策略钩子：放行路径（250 + 信封正常）与拒绝路径
  （452 + 信封未定值 → RCPT 503 + 策略放开后重发成功） }
procedure TestMailPolicyHook;
var
  LH: TPlatformThreadHandle;
  LServer: ITcpServer;
  LHandler: TTestSmtpHandler;
  LSink: TTestSmtpSink;
  LConfig: TMailSmtpServerConfig;
  LPort: UInt16;
  C: TRawClient;
  LPolicy: TTestMailPolicy;
  LPolicyRef: ISmtpMailPolicyHook;
begin
  { 放行路径：钩子被调用并拿到 From + 对端 IP }
  LSink := TTestSmtpSink.Create;
  LPolicy := TTestMailPolicy.Create;
  LPolicyRef := LPolicy;
  LConfig := TMailSmtpServerConfig.Default;
  LConfig.MailPolicy := LPolicyRef;
  StartFixture(LConfig, LSink, LServer, LHandler, LH, LPort);

  C.Open(LPort);
  ExpectBanner(C, 2000);
  C.SendLine('EHLO test.example');
  ExpectMultiLine(C, 2000, '250', 'PIPELINING', 'EHLO');
  C.SendLine('MAIL FROM:<a@b.com>');
  ExpectReply(C, 2000, '250', 'mail ok (policy allow)');
  C.SendLine('RCPT TO:<x@y.com>');
  ExpectReply(C, 2000, '250', 'rcpt ok after policy allow');
  C.SendLine('QUIT');
  ExpectReply(C, 2000, '221', 'QUIT');
  C.Close;
  { 250 回复已读回 ⇒ EvaluateMailFrom 必已完成（回复在回调后入队） }
  CheckEqual(1, LPolicy.Calls, 'policy called once on allow');
  CheckEqual('a@b.com', LPolicy.LastFrom, 'policy sees from');
  CheckEqual('127.0.0.1', LPolicy.LastIP, 'policy sees peer ip');

  StopSmtpServer(LServer, LH);
  LSink := nil;
  LPolicyRef := nil;

  { 拒绝路径：452；信封未定值（RCPT → 503）；策略放开后重发成功 }
  LSink := TTestSmtpSink.Create;
  LPolicy := TTestMailPolicy.Create;
  LPolicy.RejectReply := '452 4.7.1 Too many messages' + #13#10;
  LPolicyRef := LPolicy;
  LConfig := TMailSmtpServerConfig.Default;
  LConfig.MailPolicy := LPolicyRef;
  StartFixture(LConfig, LSink, LServer, LHandler, LH, LPort);

  C.Open(LPort);
  ExpectBanner(C, 2000);
  C.SendLine('EHLO test.example');
  ExpectMultiLine(C, 2000, '250', 'PIPELINING', 'EHLO');
  C.SendLine('MAIL FROM:<a@b.com>');
  ExpectReply(C, 2000, '452', 'mail rejected by policy');
  C.SendLine('RCPT TO:<x@y.com>');
  ExpectReply(C, 2000, '503', 'rcpt after policy reject');
  LPolicy.RejectReply := '';
  C.SendLine('MAIL FROM:<a@b.com>');
  ExpectReply(C, 2000, '250', 'mail ok after policy release');
  C.SendLine('RCPT TO:<x@y.com>');
  ExpectReply(C, 2000, '250', 'rcpt ok after policy release');
  C.SendLine('QUIT');
  ExpectReply(C, 2000, '221', 'QUIT');
  C.Close;
  CheckEqual(2, LPolicy.Calls, 'policy called twice (reject + allow)');

  StopSmtpServer(LServer, LH);
  LSink := nil;
  LPolicyRef := nil;
end;

{ RCPT 阶段同步策略钩子(9.5)：拒绝 → 该收件人未入列(DATA 缺 RCPT → 503)，
  释放后重发 RCPT 成功并完成 DATA }
procedure TestRcptPolicyHook;
var
  LH: TPlatformThreadHandle;
  LServer: ITcpServer;
  LHandler: TTestSmtpHandler;
  LSink: TTestSmtpSink;
  LConfig: TMailSmtpServerConfig;
  LPort: UInt16;
  C: TRawClient;
  LPolicy: TTestMailPolicy;
  LPolicyRef: ISmtpMailPolicyHook;
begin
  LSink := TTestSmtpSink.Create;
  LPolicy := TTestMailPolicy.Create;
  LPolicy.RcptRejectReply := '451 4.7.1 Greylisted, try again later' + #13#10;
  LPolicyRef := LPolicy;
  LConfig := TMailSmtpServerConfig.Default;
  LConfig.MailPolicy := LPolicyRef;
  StartFixture(LConfig, LSink, LServer, LHandler, LH, LPort);

  C.Open(LPort);
  ExpectBanner(C, 2000);
  C.SendLine('EHLO test.example');
  ExpectMultiLine(C, 2000, '250', 'PIPELINING', 'EHLO');
  C.SendLine('MAIL FROM:<a@b.com>');
  ExpectReply(C, 2000, '250', 'mail ok');
  C.SendLine('RCPT TO:<x@y.com>');
  ExpectReply(C, 2000, '451', 'rcpt rejected by policy');
  { 收件人未入列: DATA → 503 }
  C.SendLine('DATA');
  ExpectReply(C, 2000, '503', 'data after rejected rcpt (no recipients)');
  { 释放后重发 RCPT 成功 }
  LPolicy.RcptRejectReply := '';
  C.SendLine('RCPT TO:<x@y.com>');
  ExpectReply(C, 2000, '250', 'rcpt ok after policy release');
  C.SendLine('DATA');
  ExpectReply(C, 2000, '354', 'data accepted');
  C.SendLine('Subject: t');
  C.SendLine('');
  C.SendLine('body');
  C.SendLine('.');
  ExpectReply(C, 2000, '250', 'message queued');
  C.SendLine('QUIT');
  ExpectReply(C, 2000, '221', 'QUIT');
  C.Close;
  { 250 回复已读回 ⇒ EvaluateRcptTo 必已完成 }
  CheckEqual(2, LPolicy.RcptCalls, 'rcpt policy called twice (reject + allow)');
  CheckEqual('a@b.com', LPolicy.LastFrom, 'rcpt policy sees mail from');
  CheckEqual('x@y.com', LPolicy.LastRcpt, 'rcpt policy sees rcpt to');
  CheckEqual('127.0.0.1', LPolicy.LastIP, 'rcpt policy sees peer ip');
  Check(SpinWait(LSink.MsgCount, 1), 'message delivered after rcpt release');

  StopSmtpServer(LServer, LH);
  LSink := nil;
  LPolicyRef := nil;
end;

procedure TestOrderAndSyntax;
var
  LH: TPlatformThreadHandle;
  LServer: ITcpServer;
  LHandler: TTestSmtpHandler;
  LSink: TTestSmtpSink;
  LConfig: TMailSmtpServerConfig;
  LPort: UInt16;
  C: TRawClient;
begin
  LSink := TTestSmtpSink.Create;
  LConfig := TMailSmtpServerConfig.Default;
  StartFixture(LConfig, LSink, LServer, LHandler, LH, LPort);

  C.Open(LPort);
  ExpectBanner(C, 2000);
  { 未 HELO 先 RCPT → 503 }
  C.SendLine('RCPT TO:<x@y.com>');
  ExpectReply(C, 2000, '503', 'rcpt before helo');
  C.SendLine('EHLO test.example');
  ExpectMultiLine(C, 2000, '250', 'PIPELINING', 'EHLO');
  { RCPT 先于 MAIL → 503 }
  C.SendLine('RCPT TO:<x@y.com>');
  ExpectReply(C, 2000, '503', 'rcpt before mail');
  { 坏 MAIL 语法 → 501 }
  C.SendLine('MAIL FROM:not-an-address');
  ExpectReply(C, 2000, '501', 'bad from');
  { 小写命令参数 → 大小写不敏感；RSET 清信封 }
  C.SendLine('mail from:<lower@case.com>');
  ExpectReply(C, 2000, '250', 'lowercase mail');
  C.SendLine('RSET');
  ExpectReply(C, 2000, '250', 'rset clears envelope');
  { 坏 RCPT 语法 → 501 }
  C.SendLine('MAIL FROM:<a@b.com>');
  ExpectReply(C, 2000, '250', 'from ok');
  C.SendLine('RCPT TO:bad');
  ExpectReply(C, 2000, '501', 'bad rcpt');
  { DATA 无 RCPT → 503 }
  C.SendLine('DATA');
  ExpectReply(C, 2000, '503', 'data no rcpt');
  { 未知命令 → 500 }
  C.SendLine('FOO BAR');
  ExpectReply(C, 2000, '500', 'unknown cmd');
  { 超长行（>64KiB）→ 500 }
  C.SendLine(StringOfChar('A', 70000));
  ExpectReply(C, 2000, '500', 'overlong line');
  { VRFY/EXPN → 252 }
  C.SendLine('VRFY user');
  ExpectReply(C, 2000, '252', 'vrfy');
  C.SendLine('EXPN list');
  ExpectReply(C, 2000, '252', 'expn');
  { STARTTLS 探测 → 454 }
  C.SendLine('STARTTLS');
  ExpectReply(C, 2000, '454', 'starttls probe');
  { AUTH 未启用 → 503 }
  C.SendLine('AUTH PLAIN AAAA');
  ExpectReply(C, 2000, '503', 'auth disabled');
  C.SendLine('QUIT');
  ExpectReply(C, 2000, '221', 'QUIT');
  C.Close;

  StopSmtpServer(LServer, LH);
  LSink := nil;
end;

procedure TestRequireAuth;
var
  LH: TPlatformThreadHandle;
  LServer: ITcpServer;
  LHandler: TTestSmtpHandler;
  LSink: TTestSmtpSink;
  LConfig: TMailSmtpServerConfig;
  LPort: UInt16;
  C: TRawClient;
begin
  LSink := TTestSmtpSink.Create;
  LConfig := TMailSmtpServerConfig.Default;
  LConfig.RequireAuth := True;
  LConfig.AuthEnabled := True;
  StartFixture(LConfig, LSink, LServer, LHandler, LH, LPort);

  C.Open(LPort);
  ExpectBanner(C, 2000);
  C.SendLine('EHLO test.example');
  ExpectMultiLine(C, 2000, '250', 'AUTH', 'EHLO auth');
  C.SendLine('MAIL FROM:<a@b.com>');
  ExpectReply(C, 2000, '530', 'auth required');
  C.SendLine('AUTH PLAIN AAAA');
  ExpectReply(C, 2000, '503', 'auth impl pending');
  C.SendLine('QUIT');
  ExpectReply(C, 2000, '221', 'QUIT');
  C.Close;

  StopSmtpServer(LServer, LH);
  LSink := nil;
end;

procedure TestMaxRecipients;
var
  LH: TPlatformThreadHandle;
  LServer: ITcpServer;
  LHandler: TTestSmtpHandler;
  LSink: TTestSmtpSink;
  LConfig: TMailSmtpServerConfig;
  LPort: UInt16;
  C: TRawClient;
begin
  LSink := TTestSmtpSink.Create;
  LConfig := TMailSmtpServerConfig.Default;
  LConfig.MaxRecipients := 1;
  StartFixture(LConfig, LSink, LServer, LHandler, LH, LPort);

  C.Open(LPort);
  ExpectBanner(C, 2000);
  C.SendLine('EHLO t');
  ExpectMultiLine(C, 2000, '250', 'SIZE', 'EHLO');
  C.SendLine('MAIL FROM:<a@b.com>');
  ExpectReply(C, 2000, '250', 'from');
  C.SendLine('RCPT TO:<x@y.com>');
  ExpectReply(C, 2000, '250', 'rcpt1');
  C.SendLine('RCPT TO:<w@z.com>');
  ExpectReply(C, 2000, '452', 'too many rcpt');
  C.SendLine('QUIT');
  ExpectReply(C, 2000, '221', 'QUIT');
  C.Close;

  StopSmtpServer(LServer, LH);
  LSink := nil;
end;

procedure TestIdleTimeout;
var
  LH: TPlatformThreadHandle;
  LServer: ITcpServer;
  LHandler: TTestSmtpHandler;
  LSink: TTestSmtpSink;
  LConfig: TMailSmtpServerConfig;
  LPort: UInt16;
  C: TRawClient;
  LLine: string;
begin
  LSink := TTestSmtpSink.Create;
  LConfig := TMailSmtpServerConfig.Default;
  LConfig.IdleTimeout := TDuration.FromMilliseconds(300);
  StartFixture(LConfig, LSink, LServer, LHandler, LH, LPort);

  C.Open(LPort);
  ExpectBanner(C, 2000);
  { 静默 → 服务器超时关闭；客户端读 EOF }
  Check(not C.ReadLine(1500, LLine), 'idle timeout closes conn');
  Check(SpinWait(LSink.TimeoutCount, 1), 'timeout event fired');
  C.Close;

  StopSmtpServer(LServer, LH);
  LSink := nil;
end;

procedure TestOverflowAbort;
var
  LH: TPlatformThreadHandle;
  LServer: ITcpServer;
  LHandler: TTestSmtpHandler;
  LSink: TTestSmtpSink;
  LConfig: TMailSmtpServerConfig;
  LPort: UInt16;
  C: TRawClient;
  LLine: string;
begin
  LSink := TTestSmtpSink.Create;
  LConfig := TMailSmtpServerConfig.Default;
  { 回复队列上限极小（< banner 22B）：首个回复即溢出 }
  LConfig.OutboundQueueLimit := 16;
  StartFixture(LConfig, LSink, LServer, LHandler, LH, LPort);

  C.Open(LPort);
  { banner 超出 24B → 溢出中止 }
  Check(not C.ReadLine(1500, LLine), 'overflow aborts conn');
  Check(SpinWait(LSink.OverflowCount, 1), 'overflow event fired');
  C.Close;

  StopSmtpServer(LServer, LH);
  LSink := nil;
end;

procedure TestPipelinedCommands;
var
  LH: TPlatformThreadHandle;
  LServer: ITcpServer;
  LHandler: TTestSmtpHandler;
  LSink: TTestSmtpSink;
  LConfig: TMailSmtpServerConfig;
  LPort: UInt16;
  C: TRawClient;
  LPayload: string;
begin
  LSink := TTestSmtpSink.Create;
  LConfig := TMailSmtpServerConfig.Default;
  StartFixture(LConfig, LSink, LServer, LHandler, LH, LPort);

  C.Open(LPort);
  ExpectBanner(C, 2000);
  { 单包管线: EHLO+MAIL+RCPT+DATA 一次写入。
    服务器一次 TryRead 读入全部行, 首行处理即切 Flushing;
    缓冲内剩余命令必须续存处理, 不得丢行(回归: 见 DrainReadable 断点续存)。 }
  LPayload := 'EHLO t'#13#10'MAIL FROM:<a@b.c>'#13#10'RCPT TO:<r@b.c>'#13#10
    + 'DATA'#13#10;
  try
    C.Stream.Write(PAnsiChar(LPayload)^, Length(LPayload));
  except
  end;
  ExpectMultiLine(C, 3000, '250', 'pipelined EHLO', '');
  ExpectReply(C, 3000, '250', 'pipelined MAIL');
  ExpectReply(C, 3000, '250', 'pipelined RCPT');
  ExpectReply(C, 3000, '354', 'pipelined DATA');
  { 正文与终止点紧随其后: 354 后同一数据流续存处理 }
  LPayload := 'hello'#13#10'.'#13#10;
  try
    C.Stream.Write(PAnsiChar(LPayload)^, Length(LPayload));
  except
  end;
  ExpectReply(C, 3000, '250', 'pipelined DATA done');
  Check(SpinWait(LSink.MsgCount, 1), 'pipelined message delivered');
  C.Close;

  StopSmtpServer(LServer, LH);
  LSink := nil;
end;

var
  T: TTestSuite;

begin
  T := TTestSuite.Create('nextpas.core.mail.smtp.server');
  T.Test('HelloCommands', @TestHelloCommands);
  T.Test('EhloCapabilities', @Test_Full);
  T.Test('MailRcptDataFlow', @TestMailRcptDataFlow);
  T.Test('SizeReject', @TestSizeReject);
  T.Test('MailPolicyHook', @TestMailPolicyHook);
  T.Test('RcptPolicyHook', @TestRcptPolicyHook);
  T.Test('OrderAndSyntax', @TestOrderAndSyntax);
  T.Test('RequireAuth', @TestRequireAuth);
  T.Test('MaxRecipients', @TestMaxRecipients);
  T.Test('IdleTimeout', @TestIdleTimeout);
  T.Test('OverflowAbort', @TestOverflowAbort);
  T.Test('PipelinedCommands', @TestPipelinedCommands);
  if not T.Run then
    Halt(1);
end.