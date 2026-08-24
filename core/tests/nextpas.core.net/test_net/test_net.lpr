program test_net;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  Classes,
  SysUtils,
  StrUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.platform.socket,
  nextpas.core.net.udp,
  nextpas.core.net.resolve,
  nextpas.core.net,
  nextpas.core.platform.thread;

var
  T: TTestSuite;

const
  NONBLOCKING_WAIT_SPINS = 200;
  NONBLOCKING_WAIT_NS = 1000000;

function ReadTextFile(const APath: string): string;
var
  LText: TStringList;
begin
  LText := TStringList.Create;
  try
    LText.LoadFromFile(APath);
    Result := LowerCase(LText.Text);
  finally
    LText.Free;
  end;
end;

function ExtractSourceRange(const ASource, AStartNeedle, AEndNeedle,
  AMessage: string): string;
var
  LStart: SizeInt;
  LEnd: SizeInt;
begin
  LStart := Pos(AStartNeedle, ASource);
  Check(LStart > 0, AMessage + ' start marker');
  LEnd := PosEx(AEndNeedle, ASource, LStart + Length(AStartNeedle));
  Check(LEnd > LStart, AMessage + ' end marker');
  Result := Copy(ASource, LStart, LEnd - LStart);
end;

procedure CheckSourceContains(const ASource, ANeedle, AMessage: string);
begin
  Check(Pos(ANeedle, ASource) > 0, AMessage);
end;

procedure TestTcpStreamWriteZeroProgressSourceContract;
var
  LSource: string;
  LBody: string;
begin
  LSource := ReadTextFile('../../../src/nextpas.core.net.tcp.pas');
  LBody := ExtractSourceRange(LSource, 'function ttcpstream.write',
    'procedure ttcpstream.close', 'TTcpStream.Write implementation');
  Check(Pos('if lsent = 0 then' + LineEnding + '      break;', LBody) = 0,
    'blocking Write must not silently short-write on zero progress');
  CheckSourceContains(LBody, 'if lsent = 0 then',
    'blocking Write keeps an explicit zero-progress guard');
  CheckSourceContains(LBody, 'tcp write failed (zero progress)',
    'blocking Write raises a dedicated zero-progress error');
end;

procedure TestTcpStreamEintrRetrySourceContract;
var
  LSource: string;
  LRead: string;
  LWrite: string;
  LAccept: string;
begin
  LSource := ReadTextFile('../../../src/nextpas.core.net.tcp.pas');
  LRead := ExtractSourceRange(LSource, 'function ttcpstream.read',
    'function ttcpstream.write', 'TTcpStream.Read implementation');
  LWrite := ExtractSourceRange(LSource, 'function ttcpstream.write',
    'procedure ttcpstream.close', 'TTcpStream.Write implementation');
  LAccept := ExtractSourceRange(LSource, 'function ttcplistener.accept',
    'function ttcplistener.localaddr', 'TTcpListener.Accept implementation');
  CheckSourceContains(LRead, 'platform_socket_error_interrupted',
    'Read retries EINTR instead of raising tcp read failed');
  CheckSourceContains(LWrite, 'platform_socket_error_interrupted',
    'Write retries EINTR instead of raising tcp write failed');
  CheckSourceContains(LAccept, 'platform_socket_error_interrupted',
    'Accept retries EINTR instead of raising tcp accept failed');
  Check(Pos('tcp read failed', LRead) > 0,
    'Read still raises hard errors after interrupt retry');
end;

{ TCP echo test — uses port 0 (OS assigns) }

var
  GEchoPort: UInt16 = 0;
  GListenerReady: Int32 = 0;
  GUnixPath: string = '';

function TcpEchoServer(AArg: Pointer): Pointer; cdecl;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LTotal: SizeUInt;
begin
  Result := nil;
  LListener := TcpListen('127.0.0.1', 0);
  GEchoPort := LListener.LocalAddr.Port;
  InterlockedExchange(GListenerReady, 1);
  LClient := LListener.Accept;
  LTotal := 0;
  repeat
    LN := LClient.Read(LBuf[LTotal], SizeOf(LBuf) - LTotal);
    if LN = 0 then Break;
    Inc(LTotal, LN);
  until False;
  if LTotal > 0 then
    LClient.Write(LBuf[0], LTotal);
  LClient.Close;
  LListener.Close;
end;

procedure TestTcpEcho;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LClient: ITcpStream;
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
begin
  GListenerReady := 0;
  platform_thread_create(LHandle, @TcpEchoServer, nil);
  while InterlockedCompareExchange(GListenerReady, 0, 0) = 0 do
    platform_thread_sleep_ns(1000000);
  LClient := TcpConnect('127.0.0.1', GEchoPort);
  LClient.Write(PAnsiChar('hello')^, 5);
  LClient.Shutdown;
  LN := LClient.Read(LBuf[0], 256);
  CheckEqual(SizeUInt(5), LN, 'echo 5 bytes');
  CheckEqual(Byte(Ord('h')), LBuf[0], 'first byte');
  CheckEqual(Byte(Ord('o')), LBuf[4], 'last byte');
  LClient.Close;
  platform_thread_join(LHandle, LRetVal);
end;

procedure TestTcpLargeData;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LClient: ITcpStream;
  LBuf: array[0..1023] of Byte;
  LTotal: SizeUInt;
  LN: SizeUInt;
begin
  GListenerReady := 0;
  platform_thread_create(LHandle, @TcpEchoServer, nil);
  while InterlockedCompareExchange(GListenerReady, 0, 0) = 0 do
    platform_thread_sleep_ns(1000000);
  LClient := TcpConnect('127.0.0.1', GEchoPort);
  FillChar(LBuf[0], 1024, $AA);
  LClient.Write(LBuf[0], 1024);
  LClient.Shutdown;
  LTotal := 0;
  while LTotal < 1024 do
  begin
    LN := LClient.Read(LBuf[LTotal], 1024 - LTotal);
    if LN = 0 then Break;
    Inc(LTotal, LN);
  end;
  CheckEqual(SizeUInt(1024), LTotal, '1KB echo');
  CheckEqual(Byte($AA), LBuf[0]);
  CheckEqual(Byte($AA), LBuf[1023]);
  LClient.Close;
  platform_thread_join(LHandle, LRetVal);
end;

{ UDP test }

procedure TestUdpSendRecv;
var
  LS: IUdpSocket;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
  LFrom: TNetAddress;
  LPort: UInt16;
begin
  LS := UdpBind('127.0.0.1', 0);
  LPort := LS.LocalAddr.Port;
  LS.SendTo(PAnsiChar('ping')^, 4, TNetAddress.Create('127.0.0.1', LPort));
  LN := LS.RecvFrom(LBuf[0], 32, LFrom);
  CheckEqual(SizeUInt(4), LN, 'udp recv 4');
  CheckEqual(Byte(Ord('p')), LBuf[0]);
  LS.Close;
end;

procedure TestUdpPostCloseGuards;
var
  LS: IUdpSocket;
  LBuf: array[0..31] of Byte;
  LFrom: TNetAddress;
  LRaised: Boolean;
begin
  LS := UdpBind('127.0.0.1', 0);
  LS.Close;

  LRaised := False;
  try
    LS.SendTo(PAnsiChar('x')^, 1, TNetAddress.Create('127.0.0.1', LS.LocalAddr.Port));
  except
    on E: ENetworkError do
      LRaised := Pos('after close', E.Message) > 0;
  end;
  Check(LRaised, 'udp sendto after close raises closed-state ENetworkError');

  LRaised := False;
  try
    LS.RecvFrom(LBuf[0], SizeOf(LBuf), LFrom);
  except
    on E: ENetworkError do
      LRaised := Pos('after close', E.Message) > 0;
  end;
  Check(LRaised, 'udp recvfrom after close raises closed-state ENetworkError');

  LS.Close;
end;

{ Resolve test }

procedure TestResolve;
var
  LA: TNetAddress;
begin
  LA := Resolve('localhost');
  CheckEqual('127.0.0.1', LA.IP, 'localhost resolves');
  LA := Resolve('127.0.0.1');
  CheckEqual('127.0.0.1', LA.IP, 'IPv4 literal passthrough');
end;

procedure TestResolveDNS;
var
  LA: TNetAddress;
  LGot: Boolean;
begin
  LGot := False;
  try
    LA := Resolve('dns.google');
    Check(Length(LA.IP) > 0, 'dns.google resolved');
    Check(Pos('.', LA.IP) > 0, 'looks like IPv4');
    LGot := True;
  except
    on E: ENetworkError do
      LGot := True;
  end;
  Check(LGot, 'DNS resolve did not crash');
end;

{ Address test }

procedure TestNetAddress;
var
  LA: TNetAddress;
begin
  LA := TNetAddress.Create('192.168.1.1', 8080);
  CheckEqual('192.168.1.1:8080', LA.ToString, 'ipv4 toString');
  Check(not LA.IsIPv6, 'not ipv6');
  LA := TNetAddress.IPv6('::1', 443);
  CheckEqual('[::1]:443', LA.ToString, 'ipv6 toString');
  Check(LA.IsIPv6, 'is ipv6');
  LA := TNetAddress.IPv4('10.0.0.1', 0).WithPort(443);
  CheckEqual(Int64(443), Int64(LA.Port), 'WithPort keeps IP');
  CheckEqual('10.0.0.1', LA.IP, 'WithPort IP unchanged');
end;

procedure TestHostIsIpLiteral;
var
  LNet: UInt32;
begin
  CheckEqual('::1', StripHostBrackets('[::1]'), 'strip v6 brackets');
  CheckEqual('127.0.0.1', StripHostBrackets('127.0.0.1'), 'strip v4 unchanged');
  Check(IsIPv4Literal('127.0.0.1'), 'v4 literal');
  Check(IsIPv4Literal('255.255.255.255'), 'v4 max octet');
  Check(not IsIPv4Literal('1.2.3'), 'incomplete v4');
  Check(not IsIPv4Literal('1.2.3.4.5'), 'extra v4 octet');
  Check(not IsIPv4Literal('256.1.1.1'), 'v4 octet overflow');
  Check(not IsIPv4Literal('1..2.3'), 'empty v4 octet');
  Check(not IsIPv4Literal('1.2.3.04'), 'v4 leading zero');
  Check(IsIPv4Literal('0.0.0.0'), 'v4 zero octet');
  Check(not IsIPv4Literal('localhost'), 'localhost is not v4');
  Check(IsIPv6Literal('::1'), 'v6 literal');
  Check(IsIPv6Literal('[2001:db8::1]'), 'bracket v6');
  Check(not IsIPv6Literal('127.0.0.1'), 'v4 is not v6');
  Check(HostIsIpLiteral('127.0.0.1'), 'host v4');
  Check(HostIsIpLiteral('::1'), 'host v6');
  Check(HostIsIpLiteral('[::1]'), 'host bracket v6');
  Check(not HostIsIpLiteral('localhost'), 'localhost is name');
  Check(not HostIsIpLiteral('hy.example.com'), 'domain is name');
  Check(TryParseIPv4('8.8.8.8', LNet), 'TryParseIPv4 ok');
  Check(not TryParseIPv4('8.8.8', LNet), 'TryParseIPv4 incomplete');
  Check(not IsIPv6Literal('not-a-host:443'), 'colon hostname is not v6');
end;

procedure TestTryParseIPv6;
var
  B: TBytes;
  LRaw: array[0..15] of Byte;

  function Hex16(const A: TBytes): string;
  var
    I: Integer;
  begin
    Result := '';
    for I := 0 to High(A) do
      Result := Result + IntToHex(A[I], 2);
  end;

begin
  Check(TryParseIPv6('::1', B), '::1');
  CheckEqual('00000000000000000000000000000001', Hex16(B), '::1 bytes');
  Check(TryParseIPv6('[::1]', B), 'bracket ::1');
  CheckEqual('00000000000000000000000000000001', Hex16(B), 'bracket bytes');
  Check(TryParseIPv6('::', B), 'all zeros');
  CheckEqual('00000000000000000000000000000000', Hex16(B), ':: bytes');
  Check(TryParseIPv6('1::', B), 'headonly');
  CheckEqual('00010000000000000000000000000000', Hex16(B), '1:: bytes');
  Check(TryParseIPv6('1::2', B), 'zip');
  CheckEqual('00010000000000000000000000000002', Hex16(B), '1::2 bytes');
  Check(TryParseIPv6('fe80::1', B), 'fe80');
  CheckEqual('FE800000000000000000000000000001', Hex16(B), 'fe80 bytes');
  Check(TryParseIPv6('FE80::1', B) and TryParseIPv6('fe80::1', B), 'case');
  Check(TryParseIPv6('1:2:3:4:5:6:7:8', B), 'fullform');
  CheckEqual('00010002000300040005000600070008', Hex16(B), 'fullform bytes');
  Check(TryParseIPv6('2001:db8::1', B), 'doc');
  CheckEqual('20010DB8000000000000000000000001', Hex16(B), 'doc bytes');
  Check(TryParseIPv6('::ffff:192.168.1.1', B), 'v4mapped');
  CheckEqual('00000000000000000000FFFFC0A80101', Hex16(B), 'v4mapped bytes');
  Check(TryParseIPv6('1:2:3:4:5:6:1.2.3.4', B), 'v4mix');
  CheckEqual('00010002000300040005000601020304', Hex16(B), 'v4mix bytes');
  Check(not TryParseIPv6('fe80::1%eth0', B), 'zone rejected');
  Check(not TryParseIPv6('1:2:3:4:5:6:7:8:9', B), '9 groups');
  Check(not TryParseIPv6('1::2::3', B), 'double zip');
  Check(not TryParseIPv6('1:::2', B), 'triple colon');
  Check(not TryParseIPv6(':1::2', B), 'leading single colon');
  Check(not TryParseIPv6('1::2:', B), 'trailing single colon');
  Check(not TryParseIPv6('12345::1', B), '5 hex digits');
  Check(not TryParseIPv6('g::1', B), 'bad digit');
  Check(not TryParseIPv6('127.0.0.1', B), 'v4 is not v6');
  Check(not TryParseIPv6('', B), 'empty');
  FillChar(LRaw[0], 16, $FF);
  Check(TryParseIPv6('::1', @LRaw[0]), 'PByte ::1');
  CheckEqual(Int64(1), Int64(LRaw[15]), 'PByte ::1 last octet');
  CheckEqual(Int64(0), Int64(LRaw[0]), 'PByte ::1 first octet');
end;

procedure TestSplitHostPort;
var
  LHost: string;
  LPort: UInt16;
begin
  Check(SplitHostPort('[2001:db8::2]:9443', 0, LHost, LPort), 'bracket v6');
  CheckEqual('2001:db8::2', LHost, 'bracket v6 host');
  CheckEqual(Int64(9443), Int64(LPort), 'bracket v6 port');
  Check(SplitHostPort('[::1]', 1080, LHost, LPort), 'v6 default port');
  CheckEqual('::1', LHost, 'v6 default host');
  CheckEqual(Int64(1080), Int64(LPort), 'v6 default port value');
  Check(SplitHostPort('example.org', 443, LHost, LPort), 'host default');
  CheckEqual('example.org', LHost, 'host default name');
  CheckEqual(Int64(443), Int64(LPort), 'host default port');
  Check(SplitHostPort('example.org', 0, LHost, LPort), 'missing port probe');
  CheckEqual(Int64(0), Int64(LPort), 'missing port is 0');
  Check(not SplitHostPort('example.org', LHost, LPort), 'required port rejects missing');
  Check(SplitHostPort('example.org:8080', 443, LHost, LPort), 'explicit overrides default');
  CheckEqual(Int64(8080), Int64(LPort), 'explicit port');
  Check(not SplitHostPort('::1:80', 0, LHost, LPort), 'bare v6 rejected');
  Check(not SplitHostPort('example.org:0', 0, LHost, LPort), 'port 0 rejected');
  Check(not SplitHostPort('example.org:65536', 0, LHost, LPort), 'port overflow');
  Check(not SplitHostPort('example.org:abc', 0, LHost, LPort), 'port junk');
  Check(not SplitHostPort(':80', 80, LHost, LPort), 'empty host');
  Check(not SplitHostPort('', 80, LHost, LPort), 'empty text');
  CheckEqual('[::1]:443', JoinHostPort('::1', 443), 'join v6');
  CheckEqual('[::1]:443', JoinHostPort('[::1]', 443), 'join already bracketed');
  CheckEqual('example.org:443', JoinHostPort('example.org', 443), 'join domain');
end;

procedure TestBuildConnectSockAddrCompressedIPv6;
var
  LSa: TPlatformSockAddr;
  LA: TNetAddress;
begin
  LA := TNetAddress.IPv6('::1', 443);
  Check(NetBuildConnectSockAddr(LA, LSa), 'compressed ::1 sockaddr');
  LA := TNetAddress.IPv6('2001:db8::1', 80);
  Check(NetBuildConnectSockAddr(LA, LSa), 'compressed db8 sockaddr');
  LA := TNetAddress.IPv6('fe80::1', 22);
  Check(NetBuildConnectSockAddr(LA, LSa), 'link-local sockaddr');
  LA := TNetAddress.IPv6('not-an-ip', 80);
  Check(not NetBuildConnectSockAddr(LA, LSa), 'invalid v6 rejected');
end;

{ 非法 host 不能静默绑 0.0.0.0：platform_ipv4_parse 解析失败返回 0（与合法
  0.0.0.0 无法区分），若透传会把服务暴露到全网卡——必须显式报错。
  空串保留既有契约（等价 0.0.0.0，见 net.server 的 empty-addr 用例）。 }
procedure TestTcpListenInvalidHost;
var
  LListener: ITcpListener;
  LGot: Boolean;
begin
  LGot := False;
  try
    TcpListen('not-an-ip', 0);
  except
    on EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'invalid listen host raises EArgumentError');

  LListener := TcpListen('0.0.0.0', 0);
  LListener.Close;
end;

{ bind 失败（端口被占）的错误消息应含可读 errno 文本：反哺要求
  platform_error_message 附加 strerror（如 'Address already in use'），
  而不是只给裸数字 'bind failed (98)'——运维无法直接看出原因。 }
procedure TestTcpListenBindErrorMessage;
var
  LListener: ITcpListener;
  LPort: UInt16;
  LMsg: string;
  LGot: Boolean;
begin
  LListener := TcpListen('127.0.0.1', 0);
  LPort := LListener.LocalAddr.Port;
  LGot := False;
  try
    TcpListen('127.0.0.1', LPort);
  except
    on E: ENetworkError do
    begin
      LMsg := E.Message;
      LGot := True;
    end;
  end;
  Check(LGot, 'occupied port raises ENetworkError');
  Check(Pos('bind failed', LMsg) > 0, 'message contains bind failed marker');
  Check(Pos('Address already in use', LMsg) > 0,
    'bind error message carries readable errno text, got: ' + LMsg);
  LListener.Close;
end;

{ Error test }

procedure TestConnectRefused;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    TcpConnect('127.0.0.1', 1);
  except
    on E: ENetworkError do
      LGot := True;
  end;
  Check(LGot, 'connection refused raises');
end;

procedure TestConnectTimeout;
var
  LListener: ITcpListener;
  LFillers: array of ITcpStream;
  LConn: ITcpStream;
  LGot: Boolean;
  LPort: UInt16;
  I: Integer;
  LFilled: Boolean;
begin
  { Fill the listen backlog so a subsequent connect blocks, then assert dial
    timeout. External blackhole IPs are unreliable under transparent proxies.
    小 backlog(4)显式指定: 默认 backlog 已提升到 4096(万级连接压测反哺),
    256 个填充连接在 4096 队列下不再触发超时。 }
  LListener := TcpListen('127.0.0.1', 0, 4);
  LPort := LListener.LocalAddr.Port;
  SetLength(LFillers, 0);
  LFilled := False;
  for I := 1 to 32 do
  begin
    try
      LConn := TcpConnect('127.0.0.1', LPort, 100);
      SetLength(LFillers, Length(LFillers) + 1);
      LFillers[High(LFillers)] := LConn;
    except
      on E: ETimeoutError do
      begin
        LFilled := True;
        Break;
      end;
      on E: ENetworkError do
      begin
        LFilled := True;
        Break;
      end;
    end;
  end;
  Check(LFilled or (Length(LFillers) > 0),
    'backlog fill made progress for connect-timeout setup');
  LGot := False;
  try
    TcpConnect('127.0.0.1', LPort, 200);
  except
    on E: ETimeoutError do
      LGot := True;
  end;
  Check(LGot, 'timed TcpConnect raises ETimeoutError when peer does not accept');
  for I := 0 to High(LFillers) do
    if LFillers[I] <> nil then
      LFillers[I].Close;
  LListener.Close;
end;

type
  TTestNetCancelToken = class(TInterfacedObject, INetCancelToken)
  private
    FCanceled: Boolean;
  public
    function IsCanceled: Boolean;
    procedure Cancel;
  end;

function TTestNetCancelToken.IsCanceled: Boolean;
begin
  Result := FCanceled;
end;

procedure TTestNetCancelToken.Cancel;
begin
  FCanceled := True;
end;

var
  GCancelPort: UInt16 = 0;
  GCancelReady: Int32 = 0;
  GCancelToken: TTestNetCancelToken = nil;

function CancelSignalThread(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  platform_thread_sleep_ns(80000000); { 80ms }
  if GCancelToken <> nil then
    GCancelToken.Cancel;
end;

procedure TestReadCancelToken;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LGot: Boolean;
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LToken: INetCancelToken;
begin
  LListener := TcpListen('127.0.0.1', 0);
  GCancelPort := LListener.LocalAddr.Port;
  LClient := TcpConnect('127.0.0.1', GCancelPort);
  GCancelToken := TTestNetCancelToken.Create;
  LToken := GCancelToken;
  LClient.SetCancelToken(LToken);
  platform_thread_create(LHandle, @CancelSignalThread, nil);
  LGot := False;
  try
    LClient.Read(LBuf[0], 32);
  except
    on E: ECancelledError do
      LGot := True;
  end;
  platform_thread_join(LHandle, LRetVal);
  Check(LGot, 'read with cancel token raises ECancelledError');
  LClient.Close;
  LListener.Close;
  GCancelToken := nil;
end;

{ Wave X2: waitable cancel must wake blocked Read far faster than old 50ms slices. }
var
  GWakeCancel: INetCancelController = nil;

function WakeCancelSignalThread(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  platform_thread_sleep_ns(20000000); { 20ms hold then cancel }
  if GWakeCancel <> nil then
    GWakeCancel.Cancel;
end;

procedure TestReadCancelWakeSLA;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LGot: Boolean;
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LToken: INetCancelController;
  LWaitable: INetCancelWaitable;
  LStart: QWord;
  LElapsedMs: QWord;
begin
  LToken := NewNetCancelToken;
  Check(LToken.QueryInterface(INetCancelWaitable, LWaitable) = 0,
    'NewNetCancelToken is waitable');
  if LWaitable.WakeHandle = 0 then
  begin
    { Windows residual: socketpair may be unsupported; skip SLA. }
    Exit;
  end;

  LListener := TcpListen('127.0.0.1', 0);
  LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  GWakeCancel := LToken;
  LClient.SetCancelToken(LToken);
  platform_thread_create(LHandle, @WakeCancelSignalThread, nil);
  LGot := False;
  LStart := GetTickCount64;
  try
    LClient.Read(LBuf[0], 32);
  except
    on E: ECancelledError do
      LGot := True;
  end;
  LElapsedMs := GetTickCount64 - LStart;
  platform_thread_join(LHandle, LRetVal);
  Check(LGot, 'waitable cancel raises ECancelledError');
  { 20ms sleep + wake; old slice model needed ~50ms after cancel → ~70ms+.
    Bound total wait under 45ms so we prove sub-slice wake. }
  Check(LElapsedMs < 45, 'waitable cancel wake SLA ms=' + IntToStr(LElapsedMs));
  LClient.Close;
  LListener.Close;
  GWakeCancel := nil;
end;

{ ITcpStream as IReader/IWriter }

var
  GIoPort: UInt16 = 0;
  GIoReady: Int32 = 0;

function IoEchoServer(AArg: Pointer): Pointer; cdecl;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
begin
  Result := nil;
  LListener := TcpListen('127.0.0.1', 0);
  GIoPort := LListener.LocalAddr.Port;
  InterlockedExchange(GIoReady, 1);
  LClient := LListener.Accept;
  LN := (LClient as IReader).Read(LBuf[0], 256);
  if LN > 0 then
    (LClient as IWriter).Write(LBuf[0], LN);
  LClient.Close;
  LListener.Close;
end;

procedure TestIoIntegration;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LClient: ITcpStream;
  LReader: IReader;
  LWriter: IWriter;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
begin
  GIoReady := 0;
  platform_thread_create(LHandle, @IoEchoServer, nil);
  while InterlockedCompareExchange(GIoReady, 0, 0) = 0 do
    platform_thread_sleep_ns(1000000);
  LClient := TcpConnect('127.0.0.1', GIoPort);
  LWriter := LClient as IWriter;
  LReader := LClient as IReader;
  LWriter.Write(PAnsiChar('io')^, 2);
  LN := LReader.Read(LBuf[0], 32);
  CheckEqual(SizeUInt(2), LN, 'io echo');
  CheckEqual(Byte(Ord('i')), LBuf[0]);
  LClient.Close;
  platform_thread_join(LHandle, LRetVal);
end;

procedure TestReadDeadline;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LGot: Boolean;
begin
  LListener := TcpListen('127.0.0.1', 0);
  LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  LClient.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(50)));
  LGot := False;
  try
    LClient.Read(LBuf[0], 32);
  except
    on ETimeoutError do LGot := True;
  end;
  Check(LGot, 'read deadline triggers timeout');
  LClient.Close;
  LListener.Close;
end;

procedure TestExpiredDeadline;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LGot: Boolean;
begin
  LListener := TcpListen('127.0.0.1', 0);
  LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  LClient.SetReadDeadline(TDeadline.Expired);
  LGot := False;
  try
    LClient.Read(LBuf[0], 32);
  except
    on ETimeoutError do LGot := True;
  end;
  Check(LGot, 'expired deadline raises immediately');
  LClient.Close;
  LListener.Close;
end;

procedure TestInfiniteDeadline;
var
  LListener: ITcpListener;
  LServer, LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
begin
  LListener := TcpListen('127.0.0.1', 0);
  LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  LServer := LListener.Accept;
  LClient.SetReadDeadline(TDeadline.Infinite);
  LServer.Write(PAnsiChar('hi')^, 2);
  LN := LClient.Read(LBuf[0], 32);
  CheckEqual(SizeUInt(2), LN, 'infinite deadline reads normally');
  LClient.Close;
  LServer.Close;
  LListener.Close;
end;

procedure TestSetNoDelay;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
begin
  LListener := TcpListen('127.0.0.1', 0);
  LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  LClient.SetNoDelay(True);
  LClient.SetNoDelay(False);
  LClient.Close;
  LListener.Close;
end;

procedure TestSetKeepAlive;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
begin
  LListener := TcpListen('127.0.0.1', 0);
  LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  LClient.SetKeepAlive(True);
  LClient.SetKeepAlive(False);
  LClient.Close;
  LListener.Close;
end;

procedure TestTcpListenerSupportsRuntimeSocketControl;
var
  LListener: ITcpListener;
  LRuntime: ITcpSocketRuntime;
begin
  LListener := TcpListen('127.0.0.1', 0);
  try
    Check(Supports(LListener, ITcpSocketRuntime, LRuntime),
      'listener exposes runtime socket control');
    Check(LRuntime.NativeSocketHandle <> 0, 'listener native handle available');
    LRuntime.SetBlocking(False);
    LRuntime.SetBlocking(True);
  finally
    LListener.Close;
  end;
end;

procedure TestTcpStreamSupportsRuntimeSocketControl;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LAccepted: ITcpStream;
  LClientRuntime: ITcpSocketRuntime;
  LAcceptedRuntime: ITcpSocketRuntime;
begin
  LListener := TcpListen('127.0.0.1', 0);
  try
    LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
    try
      LAccepted := LListener.Accept;
      try
        Check(Supports(LClient, ITcpSocketRuntime, LClientRuntime),
          'client stream exposes runtime socket control');
        Check(Supports(LAccepted, ITcpSocketRuntime, LAcceptedRuntime),
          'accepted stream exposes runtime socket control');
        Check(LClientRuntime.NativeSocketHandle <> 0,
          'client stream native handle available');
        Check(LAcceptedRuntime.NativeSocketHandle <> 0,
          'accepted stream native handle available');
        LClientRuntime.SetBlocking(False);
        LClientRuntime.SetBlocking(True);
        LAcceptedRuntime.SetBlocking(False);
        LAcceptedRuntime.SetBlocking(True);
      finally
        LAccepted.Close;
      end;
    finally
      LClient.Close;
    end;
  finally
    LListener.Close;
  end;
end;

function WaitForAcceptedConnection(
  const ARuntime: nextpas.core.net.ITcpListenerRuntime): ITcpStream;
var
  LSpin: Integer;
  LResult: nextpas.core.net.TTcpAcceptResult;
begin
  Result := nil;
  for LSpin := 1 to NONBLOCKING_WAIT_SPINS do
  begin
    LResult := ARuntime.TryAccept(Result);
    if LResult = tarAccepted then
      Exit;
    CheckEqual(Int64(Ord(tarWouldBlock)), Int64(Ord(LResult)),
      'listener try-accept only reports would-block before connect');
    platform_thread_sleep_ns(NONBLOCKING_WAIT_NS);
  end;
  Fail('listener try-accept did not observe incoming connection');
end;

function WaitForRuntimeRead(
  const ARuntime: nextpas.core.net.ITcpStreamRuntime; var ABuf;
  const ACount: SizeUInt; out ARead: SizeUInt): nextpas.core.net.TTcpStreamIOResult;
var
  LSpin: Integer;
begin
  ARead := 0;
  for LSpin := 1 to NONBLOCKING_WAIT_SPINS do
  begin
    Result := ARuntime.TryRead(ABuf, ACount, ARead);
    if Result <> tsiorWouldBlock then
      Exit;
    platform_thread_sleep_ns(NONBLOCKING_WAIT_NS);
  end;
  Fail('stream try-read did not observe readable bytes');
end;

procedure TestTcpListenerRuntimeTryAccept;
var
  LListener: ITcpListener;
  LRuntime: nextpas.core.net.ITcpListenerRuntime;
  LClient: ITcpStream;
  LAccepted: ITcpStream;
  LResult: nextpas.core.net.TTcpAcceptResult;
begin
  LListener := TcpListen('127.0.0.1', 0);
  try
    Check(Supports(LListener, ITcpListenerRuntime, LRuntime),
      'listener exposes nonblocking runtime accept');
    LRuntime.SetBlocking(False);

    LAccepted := nil;
    LResult := LRuntime.TryAccept(LAccepted);
    CheckEqual(Int64(Ord(tarWouldBlock)), Int64(Ord(LResult)),
      'empty nonblocking listener would block');
    Check(LAccepted = nil, 'no connection returned on would-block');

    LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
    try
      LAccepted := WaitForAcceptedConnection(LRuntime);
      Check(LAccepted <> nil, 'accepted connection returned');
      LAccepted.Close;
    finally
      LClient.Close;
    end;
  finally
    LListener.Close;
  end;
end;

procedure TestTcpStreamRuntimeTryReadAndTryWrite;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LAccepted: ITcpStream;
  LRuntime: nextpas.core.net.ITcpStreamRuntime;
  LBuf: array[0..31] of Byte;
  LRead: SizeUInt;
  LWritten: SizeUInt;
  LResult: nextpas.core.net.TTcpStreamIOResult;
  LN: SizeUInt;
begin
  LListener := TcpListen('127.0.0.1', 0);
  try
    LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
    try
      LAccepted := LListener.Accept;
      try
        Check(Supports(LAccepted, ITcpStreamRuntime, LRuntime),
          'accepted stream exposes nonblocking runtime I/O');
        LRuntime.SetBlocking(False);

        LRead := 0;
        LResult := LRuntime.TryRead(LBuf[0], SizeOf(LBuf), LRead);
        CheckEqual(Int64(Ord(tsiorWouldBlock)), Int64(Ord(LResult)),
          'empty nonblocking stream read would block');
        CheckEqual(Int64(0), Int64(LRead), 'would-block read reports zero bytes');

        LClient.Write(PAnsiChar('ping')^, 4);
        LResult := WaitForRuntimeRead(LRuntime, LBuf[0], SizeOf(LBuf), LRead);
        CheckEqual(Int64(Ord(tsiorOk)), Int64(Ord(LResult)),
          'nonblocking read returns ok once peer writes');
        CheckEqual(Int64(4), Int64(LRead), 'runtime read byte count');
        CheckEqual(Int64(Ord('p')), Int64(LBuf[0]), 'runtime read first byte');
        CheckEqual(Int64(Ord('g')), Int64(LBuf[3]), 'runtime read last byte');

        LWritten := 0;
        LResult := LRuntime.TryWrite(PAnsiChar('pong')^, 4, LWritten);
        CheckEqual(Int64(Ord(tsiorOk)), Int64(Ord(LResult)),
          'runtime write returns ok');
        CheckEqual(Int64(4), Int64(LWritten), 'runtime write byte count');

        LN := LClient.Read(LBuf[0], SizeOf(LBuf));
        CheckEqual(Int64(4), Int64(LN), 'client reads runtime-written bytes');
        CheckEqual(Int64(Ord('p')), Int64(LBuf[0]), 'runtime write first byte');
        CheckEqual(Int64(Ord('g')), Int64(LBuf[3]), 'runtime write last byte');
      finally
        LAccepted.Close;
      end;
    finally
      LClient.Close;
    end;
  finally
    LListener.Close;
  end;
end;

procedure TestTcpStreamPostCloseRuntimeGuards;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LAccepted: ITcpStream;
  LRuntime: nextpas.core.net.ITcpStreamRuntime;
  LBuf: array[0..7] of Byte;
  LRead: SizeUInt;
  LWritten: SizeUInt;
  LResult: nextpas.core.net.TTcpStreamIOResult;
  LRaised: Boolean;
begin
  LListener := TcpListen('127.0.0.1', 0);
  try
    LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
    LAccepted := LListener.Accept;
    try
      Check(Supports(LClient, ITcpStreamRuntime, LRuntime),
        'client stream exposes runtime I/O before close');
      LClient.Close;

      LRaised := False;
      try
        LClient.Read(LBuf[0], 0);
      except
        on ENetworkError do
          LRaised := True;
      end;
      Check(LRaised, 'zero-length read after stream close raises ENetworkError');

      LRaised := False;
      try
        LClient.Write(PAnsiChar('')^, 0);
      except
        on ENetworkError do
          LRaised := True;
      end;
      Check(LRaised, 'zero-length write after stream close raises ENetworkError');

      LRead := 123;
      LResult := LRuntime.TryRead(LBuf[0], SizeOf(LBuf), LRead);
      CheckEqual(Int64(Ord(tsiorClosed)), Int64(Ord(LResult)),
        'runtime try-read reports closed after stream close');
      CheckEqual(Int64(0), Int64(LRead),
        'runtime try-read reports zero bytes after stream close');

      LRead := 123;
      LResult := LRuntime.TryRead(LBuf[0], 0, LRead);
      CheckEqual(Int64(Ord(tsiorClosed)), Int64(Ord(LResult)),
        'runtime zero-length try-read reports closed after stream close');
      CheckEqual(Int64(0), Int64(LRead),
        'runtime zero-length try-read reports zero bytes after stream close');

      LWritten := 123;
      LResult := LRuntime.TryWrite(PAnsiChar('x')^, 1, LWritten);
      CheckEqual(Int64(Ord(tsiorClosed)), Int64(Ord(LResult)),
        'runtime try-write reports closed after stream close');
      CheckEqual(Int64(0), Int64(LWritten),
        'runtime try-write reports zero bytes after stream close');

      LWritten := 123;
      LResult := LRuntime.TryWrite(PAnsiChar('')^, 0, LWritten);
      CheckEqual(Int64(Ord(tsiorClosed)), Int64(Ord(LResult)),
        'runtime zero-length try-write reports closed after stream close');
      CheckEqual(Int64(0), Int64(LWritten),
        'runtime zero-length try-write reports zero bytes after stream close');

      LRaised := False;
      try
        LClient.Shutdown;
      except
        on ENetworkError do
          LRaised := True;
      end;
      Check(LRaised, 'shutdown after stream close raises ENetworkError');

      LRaised := False;
      try
        LClient.SetNoDelay(True);
      except
        on ENetworkError do
          LRaised := True;
      end;
      Check(LRaised, 'SetNoDelay after stream close raises ENetworkError');

      LRaised := False;
      try
        LClient.SetKeepAlive(True);
      except
        on ENetworkError do
          LRaised := True;
      end;
      Check(LRaised, 'SetKeepAlive after stream close raises ENetworkError');

      LClient.Close;
    finally
      LAccepted.Close;
      LClient.Close;
    end;
  finally
    LListener.Close;
  end;
end;

procedure TestTcpListenerPostCloseRuntimeGuards;
var
  LListener: ITcpListener;
  LRuntime: nextpas.core.net.ITcpListenerRuntime;
  LAccepted: ITcpStream;
  LRaised: Boolean;
begin
  LListener := TcpListen('127.0.0.1', 0);
  Check(Supports(LListener, ITcpListenerRuntime, LRuntime),
    'listener exposes runtime accept before close');
  LListener.Close;

  LRaised := False;
  try
    LListener.Accept;
  except
    on ENetworkError do
      LRaised := True;
  end;
  Check(LRaised, 'accept after listener close raises ENetworkError');

  LRaised := False;
  try
    LRuntime.NativeSocketHandle;
  except
    on ENetworkError do
      LRaised := True;
  end;
  Check(LRaised, 'native handle after listener close raises ENetworkError');

  LRaised := False;
  try
    LRuntime.SetBlocking(False);
  except
    on ENetworkError do
      LRaised := True;
  end;
  Check(LRaised, 'set blocking after listener close raises ENetworkError');

  LAccepted := nil;
  LRaised := False;
  try
    LRuntime.TryAccept(LAccepted);
  except
    on ENetworkError do
      LRaised := True;
  end;
  Check(LRaised, 'try-accept after listener close raises ENetworkError');
  Check(LAccepted = nil, 'try-accept after listener close does not return conn');

  LListener.Close;
end;

{ Unix socket echo：UnixListen → UnixConnect → 写 → Shutdown → 读回
  （AF_UNIX 域，Linux/macOS/FreeBSD；Windows 上 expect unsupported 跳过） }
function UnixEchoServer(AArg: Pointer): Pointer; cdecl;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN, LTotal: SizeUInt;
begin
  Result := nil;
  try
    LListener := UnixListen(GUnixPath);
    InterlockedExchange(GListenerReady, 1);
    LClient := LListener.Accept;
    LTotal := 0;
    repeat
      LN := LClient.Read(LBuf[LTotal], SizeOf(LBuf) - LTotal);
      if LN = 0 then Break;
      Inc(LTotal, LN);
    until False;
    if LTotal > 0 then
      LClient.Write(LBuf[0], LTotal);
    LClient.Close;
    LListener.Close;
  except
    InterlockedExchange(GListenerReady, -1);
  end;
end;

procedure TestUnixSocketEcho;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LClient: ITcpStream;
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
begin
  {$IFDEF NEXTPAS_WINDOWS}
  Exit;   { Unix socket 在 Windows 不支持；留 TCP 覆盖 }
  {$ENDIF}
  GUnixPath := '/tmp/code888_net_unix_' + IntToStr(GetProcessID) + '.sock';
  GListenerReady := 0;
  platform_thread_create(LHandle, @UnixEchoServer, nil);
  while InterlockedCompareExchange(GListenerReady, 0, 0) = 0 do
    platform_thread_sleep_ns(1000000);
  if GListenerReady < 0 then
  begin
    platform_thread_join(LHandle, LRetVal);
    Exit;
  end;
  LClient := UnixConnect(GUnixPath);
  LClient.Write(PAnsiChar('hello')^, 5);
  LClient.Shutdown;
  LN := LClient.Read(LBuf[0], 256);
  CheckEqual(SizeUInt(5), LN, 'unix echo 5 bytes');
  CheckEqual(Byte(Ord('h')), LBuf[0], 'unix first byte');
  LClient.Close;
  platform_thread_join(LHandle, LRetVal);
end;

{ 关闭后同路径可再监听（bind 前 unlink 旧 socket 文件） }
procedure TestUnixListenReusePath;
var
  L1, L2: ITcpListener;
begin
  {$IFDEF NEXTPAS_WINDOWS}
  Exit;
  {$ENDIF}
  GUnixPath := '/tmp/code888_net_unix_reuse_' + IntToStr(GetProcessID) + '.sock';
  L1 := UnixListen(GUnixPath);
  L1.Close;
  L2 := UnixListen(GUnixPath);
  L2.Close;
  CheckTrue(True, 'unix listen path reusable after close');
end;

begin
  T := TTestSuite.Create('nextpas.core.net');
  T.Test('TCP stream write zero-progress source contract',
    @TestTcpStreamWriteZeroProgressSourceContract);
  T.Test('TCP stream EINTR retry source contract',
    @TestTcpStreamEintrRetrySourceContract);
  T.Test('TCP echo', @TestTcpEcho);
  T.Test('TCP large data', @TestTcpLargeData);
  T.Test('UDP send/recv', @TestUdpSendRecv);
  T.Test('UDP post-close guards', @TestUdpPostCloseGuards);
  T.Test('Resolve', @TestResolve);
  T.Test('Resolve DNS', @TestResolveDNS);
  T.Test('NetAddress', @TestNetAddress);
  T.Test('Host IP literal helpers', @TestHostIsIpLiteral);
  T.Test('TryParseIPv6 RFC 4291', @TestTryParseIPv6);
  T.Test('SplitHostPort / JoinHostPort', @TestSplitHostPort);
  T.Test('Connect sockaddr accepts compressed IPv6',
    @TestBuildConnectSockAddrCompressedIPv6);
  T.Test('TCP listen invalid host', @TestTcpListenInvalidHost);
  T.Test('TCP listen bind error message', @TestTcpListenBindErrorMessage);
  T.Test('Connect refused', @TestConnectRefused);
  T.Test('Connect timeout', @TestConnectTimeout);
  T.Test('Read cancel token', @TestReadCancelToken);
  T.Test('Read cancel waitable wake SLA', @TestReadCancelWakeSLA);
  T.Test('IO integration', @TestIoIntegration);
  T.Test('Read deadline', @TestReadDeadline);
  T.Test('Expired deadline', @TestExpiredDeadline);
  T.Test('Infinite deadline', @TestInfiniteDeadline);
  T.Test('SetNoDelay', @TestSetNoDelay);
  T.Test('SetKeepAlive', @TestSetKeepAlive);
  T.Test('TCP listener exposes runtime socket control',
    @TestTcpListenerSupportsRuntimeSocketControl);
  T.Test('TCP stream exposes runtime socket control',
    @TestTcpStreamSupportsRuntimeSocketControl);
  T.Test('TCP listener try-accept reports would-block and accept',
    @TestTcpListenerRuntimeTryAccept);
  T.Test('TCP stream try-read and try-write support nonblocking runtime I/O',
    @TestTcpStreamRuntimeTryReadAndTryWrite);
  T.Test('TCP stream post-close runtime guards',
    @TestTcpStreamPostCloseRuntimeGuards);
  T.Test('TCP listener post-close runtime guards',
    @TestTcpListenerPostCloseRuntimeGuards);
  T.Test('Unix socket echo', @TestUnixSocketEcho);
  T.Test('Unix socket path reuse after close', @TestUnixListenReusePath);
  if not T.Run then Halt(1);
end.
