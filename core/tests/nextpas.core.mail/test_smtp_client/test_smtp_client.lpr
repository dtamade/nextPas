program test_smtp_client;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.exception,
  nextpas.core.time,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.encoding.base64,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.platform.thread,
  nextpas.core.mail,
  nextpas.core.mail.smtp;

const
  SERVER_READ_TIMEOUT_SEC = 5;

type
  { 单步脚本：Reply 为回复全文（含 3 位码，多行 CRLF 分隔）；
    空 Reply 表示不回复；ReadUntilDot 用于 DATA 后读到 '.' 再回复。 }
  TMockStep = record
    Reply: string;
    ReplyDelayMs: Integer;
    ReadUntilDot: Boolean;
  end;
  TMockSteps = array of TMockStep;

  TMockServer = record
    Port: UInt16;
    Ready: Int32;
    Done: Int32;
    Transcript: string;
    Err: string;
  end;

  TSendWorker = record
    Client: TSmtpClient;
    Done: Int32;
    Result: Boolean;
    LastError: string;
    From: TMailAddress;
    ToList: TMailAddressArray;
    Data: string;
  end;

var
  GSteps: array of TMockStep;
  GStepBuild: TMockSteps;
  GServer: TMockServer;
  GWorker: TSendWorker;
  { CheckRaises 用全局状态（测试顺序执行） }
  GAuthClient: TSmtpClient;
  GSendClient: TSmtpClient;
  GConnectClient: TSmtpClient;
  GFromAddr: TMailAddress;
  GToAddrs: TMailAddressArray;

procedure RaiseAuth;
begin
  GAuthClient.Auth('user', 'bad');
end;

procedure RaiseSend;
begin
  GSendClient.SendMail(GFromAddr, GToAddrs, 'body');
end;

procedure RaiseConnect;
begin
  GConnectClient.Connect;
end;

{ ── 脚本构建：累积式，规避数组构造器/开数组限制 ───────────────────── }

procedure BeginSteps;
begin
  GStepBuild := nil;
end;

procedure AddStep(const AReply: string; ADelayMs: Integer = 0;
  AReadUntilDot: Boolean = False);
var
  LStep: TMockStep;
begin
  LStep.Reply := AReply;
  LStep.ReplyDelayMs := ADelayMs;
  LStep.ReadUntilDot := AReadUntilDot;
  SetLength(GStepBuild, Length(GStepBuild) + 1);
  GStepBuild[High(GStepBuild)] := LStep;
end;

function ServerReadLine(const AStream: ITcpStream; out ALine: string): Boolean;
var
  LB: Byte;
  LBuf: TBytes;
  LCap: Integer;
begin
  Result := False;
  ALine := '';
  SetLength(LBuf, 256);
  LCap := 0;
  AStream.SetReadDeadline(
    TDeadline.After(TDuration.FromSeconds(SERVER_READ_TIMEOUT_SEC)));
  while True do
  begin
    if AStream.Read(LB, 1) = 0 then
      Exit(False);
    if LB = 10 then
      Break;
    if LB <> 13 then
    begin
      if LCap >= Length(LBuf) then
        SetLength(LBuf, LCap * 2);
      LBuf[LCap] := LB;
      Inc(LCap);
    end;
  end;
  SetLength(LBuf, LCap);
  ALine := ASCIIBytesToString(LBuf);
  Result := True;
end;

procedure ServerWrite(const AStream: ITcpStream; const AText: string);
var
  LB: TBytes;
begin
  LB := StringToUTF8Bytes(AText);
  if Length(LB) > 0 then
    AStream.Write(LB[0], Length(LB));
end;

function MockServerThread(AArg: Pointer): Pointer; cdecl;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LStep: Integer;
  LLine: string;
begin
  Result := nil;
  try
    LListener := TcpListen('127.0.0.1', 0);
    GServer.Port := LListener.LocalAddr.Port;
    InterlockedExchange(GServer.Ready, 1);
    LClient := LListener.Accept;
    GServer.Transcript := '';
    if Length(GSteps) > 0 then
    begin
      if GSteps[0].ReplyDelayMs > 0 then
        platform_thread_sleep_ms(GSteps[0].ReplyDelayMs);
      if GSteps[0].Reply <> '' then
        ServerWrite(LClient, GSteps[0].Reply + #13#10);
    end;
    for LStep := 1 to Length(GSteps) - 1 do
    begin
      if not ServerReadLine(LClient, LLine) then
        Break;
      GServer.Transcript := GServer.Transcript + LLine + #13#10;
      if GSteps[LStep].ReadUntilDot then
      begin
        repeat
          if not ServerReadLine(LClient, LLine) then
            Break;
          GServer.Transcript := GServer.Transcript + LLine + #13#10;
        until LLine = '.';
      end;
      if GSteps[LStep].ReplyDelayMs > 0 then
        platform_thread_sleep_ms(GSteps[LStep].ReplyDelayMs);
      if GSteps[LStep].Reply <> '' then
        ServerWrite(LClient, GSteps[LStep].Reply + #13#10);
    end;
    if LClient <> nil then
      LClient.Close;
    LListener.Close;
  except
    on E: Exception do
      GServer.Err := E.ClassName + ': ' + E.Message;
  end;
  InterlockedExchange(GServer.Done, 1);
end;

{ 启动 mock 服务器并等待就绪 }
procedure StartMockServer(var AHandler: TPlatformThreadHandle;
  const ASteps: TMockSteps; out APort: UInt16);
var
  I: Integer;
  LStart: UInt64;
begin
  SetLength(GSteps, Length(ASteps));
  for I := 0 to Length(ASteps) - 1 do
    GSteps[I] := ASteps[I];
  GServer.Transcript := '';
  GServer.Err := '';
  InterlockedExchange(GServer.Ready, 0);
  InterlockedExchange(GServer.Done, 0);
  platform_thread_create(AHandler, @MockServerThread, nil);
  LStart := GetTickCount64;
  while InterlockedCompareExchange(GServer.Ready, 0, 0) = 0 do
  begin
    platform_thread_sleep_ms(2);
    if GetTickCount64 - LStart > 5000 then
    begin
      Check(False, 'mock server start timeout');
      Break;
    end;
  end;
  APort := GServer.Port;
end;

procedure WaitServerDone(AHandler: TPlatformThreadHandle);
var
  LRet: Pointer;
  LStart: UInt64;
begin
  LStart := GetTickCount64;
  while InterlockedCompareExchange(GServer.Done, 0, 0) = 0 do
  begin
    platform_thread_sleep_ms(5);
    if GetTickCount64 - LStart > 20000 then
    begin
      Check(False, 'mock server done timeout');
      Break;
    end;
  end;
  platform_thread_join(AHandler, LRet);
end;

function MakeConfig(APort: UInt16; AIoMs, AConnectMs: Int64): TSmtpClientConfig;
begin
  Result.Host := '127.0.0.1';
  Result.Port := APort;
  Result.HeloDomain := '';
  Result.ConnectTimeoutMs := AConnectMs;
  Result.IoTimeoutMs := AIoMs;
end;

procedure TestBasicSession;
var
  LH: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: TSmtpClient;
  LFrom: TMailAddress;
  LTo: TMailAddressArray;
  LData: string;
begin
  BeginSteps;
  AddStep('220 mock.example ESMTP ready');
  AddStep('250-mock.example' + #13#10 + '250-8BITMIME' + #13#10 +
    '250 SIZE 100000');
  AddStep('250 2.1.0 ok');
  AddStep('250 2.1.5 ok');
  AddStep('250 2.1.5 ok');
  AddStep('354 End data with <CRLF>.<CRLF>');
  AddStep('250 2.0.0 queued as 123', 0, True);
  AddStep('221 2.0.0 bye');
  StartMockServer(LH, GStepBuild, LPort);
  LClient := TSmtpClient.Create(MakeConfig(LPort, 2000, 2000));
  try
    Check(LClient.TryConnect, 'connect ok');
    Check(LClient.Connected, 'connected flag');
    CheckEqual('mock.example ESMTP ready', LClient.Greeting, 'greeting');
    Check(LClient.Capabilities.Supports('8bitmime'), '8bitmime capability');
    Check(not LClient.Capabilities.Supports('starttls'), 'no starttls here');
    CheckEqual(100000, LClient.Capabilities.MaxSize, 'size capability');

    LFrom := TMailAddress.Parse('alice@example.com');
    SetLength(LTo, 2);
    LTo[0] := TMailAddress.Parse('bob@example.com');
    LTo[1] := TMailAddress.Parse('carol@example.com');
    LData := 'From: alice@example.com' + #13#10 +
             'To: bob@example.com' + #13#10 +
             'Subject: greet' + #13#10 + #13#10 +
             'hi bob' + #13#10 +
             '.line';
    Check(LClient.TrySendMail(LFrom, LTo, LData), 'mail accepted');
    CheckEqual(250, LClient.LastReply.Code, 'final reply code');
    Check(LClient.LastReply.IsSuccess, 'final reply success');
    Check(LClient.TryQuit, 'quit ok');
    CheckEqual(221, LClient.LastReply.Code, 'quit reply code');
  finally
    LClient.Free;
  end;
  WaitServerDone(LH);
  { 完整会话序列 + 点转义 + 结束点 }
  CheckEqual(
    'EHLO localhost' + #13#10 +
    'MAIL FROM:<alice@example.com>' + #13#10 +
    'RCPT TO:<bob@example.com>' + #13#10 +
    'RCPT TO:<carol@example.com>' + #13#10 +
    'DATA' + #13#10 +
    'From: alice@example.com' + #13#10 +
    'To: bob@example.com' + #13#10 +
    'Subject: greet' + #13#10 +
    '' + #13#10 +
    'hi bob' + #13#10 +
    '..line' + #13#10 +
    '.' + #13#10 +
    'QUIT' + #13#10,
    GServer.Transcript, 'full session transcript with dot-stuffing');
end;

procedure TestEhloFallsBackToHelo;
var
  LH: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: TSmtpClient;
begin
  BeginSteps;
  AddStep('220 mock.example ESMTP');
  AddStep('500 ehlo not supported');
  AddStep('250 mock.example hello');
  AddStep('221 bye');
  StartMockServer(LH, GStepBuild, LPort);
  LClient := TSmtpClient.Create(MakeConfig(LPort, 2000, 2000));
  try
    Check(LClient.TryConnect, 'connect via helo fallback');
    CheckEqual(0, Length(LClient.Capabilities.Extensions), 'no caps on helo');
    Check(not LClient.Capabilities.Supports('8bitmime'), 'no 8bitmime');
    Check(LClient.TryQuit, 'quit');
  finally
    LClient.Free;
  end;
  WaitServerDone(LH);
  Check(Pos('EHLO localhost' + #13#10, GServer.Transcript) > 0, 'ehlo attempted');
  Check(Pos('HELO localhost' + #13#10, GServer.Transcript) > 0, 'helo attempted');
end;

procedure TestMultiLineReply;
var
  LH: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: TSmtpClient;
  LFrom: TMailAddress;
  LTo: TMailAddressArray;
begin
  BeginSteps;
  AddStep('220-line1' + #13#10 + '220-line2' + #13#10 + '220 ready');
  AddStep('250-ok-a' + #13#10 + '250-ok-b' + #13#10 + '250 ok-c');
  AddStep('250 2.1.0 ok');
  AddStep('250 2.1.5 ok');
  AddStep('354 go ahead');
  AddStep('250 queued', 0, True);
  AddStep('221-2.0.0 closing' + #13#10 + '221 bye');
  StartMockServer(LH, GStepBuild, LPort);
  LClient := TSmtpClient.Create(MakeConfig(LPort, 2000, 2000));
  try
    Check(LClient.TryConnect, 'connect');
    CheckEqual('line1 line2 ready', LClient.Greeting, 'multi-line greeting text');
    CheckEqual(3, Length(LClient.LastReply.Lines), 'ehlo multi-line count');
    CheckEqual('ok-a ok-b ok-c', LClient.LastReply.Text, 'ehlo multiline text');
    LFrom := TMailAddress.Parse('a@b.com');
    SetLength(LTo, 1);
    LTo[0] := TMailAddress.Parse('c@d.com');
    Check(LClient.TrySendMail(LFrom, LTo, 'x'), 'send');
    Check(LClient.TryQuit, 'quit');
    CheckEqual(221, LClient.LastReply.Code, 'multi-line quit code');
    CheckEqual(2, Length(LClient.LastReply.Lines), 'multi-line quit lines');
    CheckEqual('2.0.0 closing bye', LClient.LastReply.Text, 'multi-line quit text');
  finally
    LClient.Free;
  end;
  WaitServerDone(LH);
end;

procedure TestStartTlsCapability;
var
  LH: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: TSmtpClient;
begin
  BeginSteps;
  AddStep('220 mock.example ESMTP');
  AddStep('250-mock.example' + #13#10 + '250-STARTTLS' + #13#10 +
    '250-AUTH PLAIN LOGIN' + #13#10 + '250 8BITMIME');
  AddStep('221 bye');
  StartMockServer(LH, GStepBuild, LPort);
  LClient := TSmtpClient.Create(MakeConfig(LPort, 2000, 2000));
  try
    Check(LClient.TryConnect, 'connect');
    Check(LClient.Capabilities.Supports('starttls'), 'starttls probed');
    Check(LClient.Capabilities.SupportsAuth('plain'), 'auth plain');
    Check(LClient.Capabilities.SupportsAuth('LOGIN'), 'auth login');
    Check(LClient.Capabilities.Supports('8bitmime'), '8bitmime');
    Check(not LClient.Capabilities.Supports('smtputf8'), 'other ext absent');
    Check(LClient.TryQuit, 'quit');
  finally
    LClient.Free;
  end;
  WaitServerDone(LH);
end;

procedure TestAuthPlain;
var
  LH: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: TSmtpClient;
begin
  BeginSteps;
  AddStep('220 mock.example ESMTP');
  AddStep('250-mock.example' + #13#10 + '250-AUTH PLAIN LOGIN' + #13#10 + '250 ok');
  AddStep('235 2.7.0 authentication successful');
  AddStep('221 bye');
  StartMockServer(LH, GStepBuild, LPort);
  LClient := TSmtpClient.Create(MakeConfig(LPort, 2000, 2000));
  try
    Check(LClient.TryConnect, 'connect');
    Check(LClient.TryAuth('user', 's3cret'), 'plain auth ok');
    CheckEqual(235, LClient.LastReply.Code, 'auth reply code');
    Check(LClient.TryQuit, 'quit');
  finally
    LClient.Free;
  end;
  WaitServerDone(LH);
  Check(Pos('AUTH PLAIN AHVzZXIAczNjcmV0' + #13#10,
    GServer.Transcript) > 0, 'plain payload exact');
end;

procedure TestAuthLogin;
var
  LH: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: TSmtpClient;
begin
  BeginSteps;
  AddStep('220 mock.example ESMTP');
  AddStep('250-mock.example' + #13#10 + '250-AUTH LOGIN' + #13#10 + '250 ok');
  AddStep('334 VXNlcm5hbWU6');
  AddStep('334 UGFzc3dvcmQ6');
  AddStep('235 2.7.0 ok');
  AddStep('221 bye');
  StartMockServer(LH, GStepBuild, LPort);
  LClient := TSmtpClient.Create(MakeConfig(LPort, 2000, 2000));
  try
    Check(LClient.TryConnect, 'connect');
    Check(LClient.Capabilities.SupportsAuth('LOGIN'), 'login advertised');
    Check(not LClient.Capabilities.SupportsAuth('PLAIN'), 'plain not advertised');
    Check(LClient.TryAuth('user', 's3cret'), 'login auth ok');
    CheckEqual(235, LClient.LastReply.Code, 'auth reply code');
    Check(LClient.TryQuit, 'quit');
  finally
    LClient.Free;
  end;
  WaitServerDone(LH);
  CheckEqual('EHLO localhost' + #13#10 + 'AUTH LOGIN' + #13#10 + 'dXNlcg==' + #13#10 +
    'czNjcmV0' + #13#10 + 'QUIT' + #13#10, GServer.Transcript, 'login challenge sequence');
end;

procedure TestAuthRejected;
var
  LH: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: TSmtpClient;
begin
  BeginSteps;
  AddStep('220 mock.example ESMTP');
  AddStep('250-mock.example' + #13#10 + '250 ok');
  AddStep('535 5.7.8 authentication credentials invalid');
  { CheckRaises 重放一次 Auth：再给一次 535 而非把 '221 bye' 喂给第二次 AUTH }
  AddStep('535 5.7.8 authentication credentials invalid');
  AddStep('221 bye');
  StartMockServer(LH, GStepBuild, LPort);
  LClient := TSmtpClient.Create(MakeConfig(LPort, 2000, 2000));
  try
    Check(LClient.TryConnect, 'connect');
    Check(not LClient.TryAuth('user', 'bad'), 'auth rejected');
    CheckEqual(535, LClient.LastReply.Code, 'reject code');
    GAuthClient := LClient;
    CheckRaises(ESmtpAuthError, @RaiseAuth, 'AUTH PLAIN failed');
    Check(LClient.TryQuit, 'quit');
  finally
    LClient.Free;
  end;
  WaitServerDone(LH);
end;

procedure TestRcptRejectedAll;
var
  LH: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: TSmtpClient;
  LFrom: TMailAddress;
  LTo: TMailAddressArray;
begin
  BeginSteps;
  AddStep('220 mock.example ESMTP');
  AddStep('250-mock.example' + #13#10 + '250 ok');
  AddStep('250 2.1.0 ok');
  AddStep('550 5.1.1 no such user');
  AddStep('550 5.1.1 no such user');
  { CheckRaises 重放一次 SendMail：MAIL 250 + 2×RCPT 550 }
  AddStep('250 2.1.0 ok');
  AddStep('550 5.1.1 no such user');
  AddStep('550 5.1.1 no such user');
  AddStep('221 bye');
  StartMockServer(LH, GStepBuild, LPort);
  LClient := TSmtpClient.Create(MakeConfig(LPort, 2000, 2000));
  try
    Check(LClient.TryConnect, 'connect');
    LFrom := TMailAddress.Parse('a@b.com');
    SetLength(LTo, 2);
    LTo[0] := TMailAddress.Parse('x@y.com');
    LTo[1] := TMailAddress.Parse('w@z.com');
    Check(not LClient.TrySendMail(LFrom, LTo, 'body'), 'all rcpt rejected');
    CheckEqual(550, LClient.LastReply.Code, 'last reject code');
    GSendClient := LClient;
    GFromAddr := LFrom;
    GToAddrs := LTo;
    CheckRaises(ESmtpRejectedError, @RaiseSend, 'all recipients rejected');
    Check(LClient.TryQuit, 'quit');
  finally
    LClient.Free;
  end;
  WaitServerDone(LH);
  Check(Pos('RCPT TO:<x@y.com>' + #13#10, GServer.Transcript) > 0, 'rcpt 1 sent');
  Check(Pos('RCPT TO:<w@z.com>' + #13#10, GServer.Transcript) > 0, 'rcpt 2 sent');
end;

procedure TestDataRejected;
var
  LH: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: TSmtpClient;
  LFrom: TMailAddress;
  LTo: TMailAddressArray;
begin
  BeginSteps;
  AddStep('220 mock.example ESMTP');
  AddStep('250-mock.example' + #13#10 + '250 ok');
  AddStep('250 2.1.0 ok');
  AddStep('250 2.1.5 ok');
  AddStep('554 5.3.4 message size exceeds limit');
  AddStep('221 bye');
  StartMockServer(LH, GStepBuild, LPort);
  LClient := TSmtpClient.Create(MakeConfig(LPort, 2000, 2000));
  try
    Check(LClient.TryConnect, 'connect');
    LFrom := TMailAddress.Parse('a@b.com');
    SetLength(LTo, 1);
    LTo[0] := TMailAddress.Parse('c@d.com');
    Check(not LClient.TrySendMail(LFrom, LTo, 'big body'), 'data rejected');
    CheckEqual(554, LClient.LastReply.Code, 'data reply code');
    Check(LClient.TryQuit, 'quit');
  finally
    LClient.Free;
  end;
  WaitServerDone(LH);
end;

procedure TestSendNoRecipients;
var
  LH: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: TSmtpClient;
  LFrom: TMailAddress;
  LEmpty: TMailAddressArray;
begin
  BeginSteps;
  AddStep('220 mock.example ESMTP');
  AddStep('250-mock.example' + #13#10 + '250 ok');
  AddStep('221 bye');
  StartMockServer(LH, GStepBuild, LPort);
  LClient := TSmtpClient.Create(MakeConfig(LPort, 2000, 2000));
  try
    Check(LClient.TryConnect, 'connect');
    LFrom := TMailAddress.Parse('a@b.com');
    SetLength(LEmpty, 0);
    Check(not LClient.TrySendMail(LFrom, LEmpty, 'x'), 'no recipients rejected');
    Check(Pos('no recipients', LClient.LastError) > 0, 'error explains');
    Check(LClient.TryQuit, 'quit');
  finally
    LClient.Free;
  end;
  WaitServerDone(LH);
end;

procedure TestReadTimeout;
var
  LH: TPlatformThreadHandle;
  LPort: UInt16;
  LClient: TSmtpClient;
begin
  { 服务器延迟 400ms 才回问候；客户端 100ms 读超时 }
  BeginSteps;
  AddStep('220 too late', 400);
  AddStep('250 ok');
  StartMockServer(LH, GStepBuild, LPort);
  LClient := TSmtpClient.Create(MakeConfig(LPort, 100, 2000));
  try
    Check(not LClient.TryConnect, 'connect times out');
    Check(not LClient.Connected, 'not connected');
    Check(Pos('deadline', LClient.LastError) > 0, 'timeout error reported');
  finally
    LClient.Free;
  end;
  WaitServerDone(LH);
end;

function FreePort: UInt16;
var
  L: ITcpListener;
begin
  L := TcpListen('127.0.0.1', 0);
  Result := L.LocalAddr.Port;
  L.Close;
end;

procedure TestConnectRefused;
var
  LPort: UInt16;
  LClient: TSmtpClient;
begin
  LPort := FreePort;   { 端口已关闭 → 连接被拒 }
  LClient := TSmtpClient.Create(MakeConfig(LPort, 2000, 2000));
  try
    Check(not LClient.TryConnect, 'refused connect false');
    GConnectClient := LClient;
    CheckRaises(ENetworkError, @RaiseConnect, 'tcp connect failed');
  finally
    LClient.Free;
  end;
end;

function CancelSenderThread(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  GWorker.Result := GWorker.Client.TrySendMail(GWorker.From, GWorker.ToList,
    GWorker.Data);
  GWorker.LastError := GWorker.Client.LastError;
  InterlockedExchange(GWorker.Done, 1);
end;

procedure TestCancelDuringData;
var
  LH: TPlatformThreadHandle;      { 服务器线程句柄 }
  LW: TPlatformThreadHandle;      { 发送工作线程句柄 }
  LPort: UInt16;
  LClient: TSmtpClient;
  LFrom: TMailAddress;
  LTo: TMailAddressArray;
  LRet: Pointer;
  LStart: UInt64;
begin
  { 服务器在 DATA 后永不回复最终结果 → 客户端 Cancel 唤醒读阻塞 }
  BeginSteps;
  AddStep('220 mock.example ESMTP');
  AddStep('250-mock.example' + #13#10 + '250 ok');
  AddStep('250 2.1.0 ok');
  AddStep('250 2.1.5 ok');
  AddStep('354 end with dot');
  AddStep('', 0, True);       { 吃到 '.' 后不回复 }
  AddStep('221 bye');
  StartMockServer(LH, GStepBuild, LPort);
  LClient := TSmtpClient.Create(MakeConfig(LPort, 15000, 2000));
  try
    Check(LClient.TryConnect, 'connect');
    LFrom := TMailAddress.Parse('a@b.com');
    SetLength(LTo, 1);
    LTo[0] := TMailAddress.Parse('c@d.com');
    GWorker.Client := LClient;
    GWorker.From := LFrom;
    GWorker.ToList := LTo;
    GWorker.Data := 'subject: x' + #13#10 + #13#10 + 'body';
    GWorker.Result := False;
    GWorker.LastError := '';
    InterlockedExchange(GWorker.Done, 0);
    platform_thread_create(LW, @CancelSenderThread, nil);
    platform_thread_sleep_ms(150);
    LClient.Cancel;
    LStart := GetTickCount64;
    while InterlockedCompareExchange(GWorker.Done, 0, 0) = 0 do
    begin
      platform_thread_sleep_ms(5);
      if GetTickCount64 - LStart > 10000 then
      begin
        Check(False, 'cancel send worker timeout');
        Break;
      end;
    end;
    platform_thread_join(LW, LRet);
    Check(not GWorker.Result, 'send canceled');
    Check(Pos('canceled', GWorker.LastError) > 0, 'cancel error reported');
  finally
    LClient.Free;
  end;
  WaitServerDone(LH);
end;

var
  T: TTestSuite;

begin
  T := TTestSuite.Create('nextpas.core.mail.smtp');
  T.Test('BasicSession', @TestBasicSession);
  T.Test('EhloFallsBackToHelo', @TestEhloFallsBackToHelo);
  T.Test('MultiLineReply', @TestMultiLineReply);
  T.Test('StartTlsCapability', @TestStartTlsCapability);
  T.Test('AuthPlain', @TestAuthPlain);
  T.Test('AuthLogin', @TestAuthLogin);
  T.Test('AuthRejected', @TestAuthRejected);
  T.Test('RcptRejectedAll', @TestRcptRejectedAll);
  T.Test('DataRejected', @TestDataRejected);
  T.Test('SendNoRecipients', @TestSendNoRecipients);
  T.Test('ReadTimeout', @TestReadTimeout);
  T.Test('ConnectRefused', @TestConnectRefused);
  T.Test('CancelDuringData', @TestCancelDuringData);
  if not T.Run then
    Halt(1);
end.