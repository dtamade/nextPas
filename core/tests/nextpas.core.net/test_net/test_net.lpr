program test_net;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes,
  SysUtils,
  StrUtils,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.net.udp,
  nextpas.core.net.resolve,
  nextpas.core.net,
  nextpas.core.platform.thread;

var
  T: TTestRunner;

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
    'function ttcpstream.seek', 'TTcpStream.Write implementation');
  Check(Pos('if lsent = 0 then' + LineEnding + '      break;', LBody) = 0,
    'blocking Write must not silently short-write on zero progress');
  CheckSourceContains(LBody, 'if lsent = 0 then',
    'blocking Write keeps an explicit zero-progress guard');
  CheckSourceContains(LBody, 'tcp write failed (zero progress)',
    'blocking Write raises a dedicated zero-progress error');
end;

{ TCP echo test — uses port 0 (OS assigns) }

var
  GEchoPort: UInt16 = 0;
  GListenerReady: Int32 = 0;

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
    on ENetworkError do LGot := True;
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
    on ENetworkError do LGot := True;
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

begin
  T := TTestRunner.Create('nextpas.core.net');
  T.Run('TCP stream write zero-progress source contract',
    @TestTcpStreamWriteZeroProgressSourceContract);
  T.Run('TCP echo', @TestTcpEcho);
  T.Run('TCP large data', @TestTcpLargeData);
  T.Run('UDP send/recv', @TestUdpSendRecv);
  T.Run('UDP post-close guards', @TestUdpPostCloseGuards);
  T.Run('Resolve', @TestResolve);
  T.Run('Resolve DNS', @TestResolveDNS);
  T.Run('NetAddress', @TestNetAddress);
  T.Run('Connect refused', @TestConnectRefused);
  T.Run('IO integration', @TestIoIntegration);
  T.Run('Read deadline', @TestReadDeadline);
  T.Run('Expired deadline', @TestExpiredDeadline);
  T.Run('Infinite deadline', @TestInfiniteDeadline);
  T.Run('SetNoDelay', @TestSetNoDelay);
  T.Run('SetKeepAlive', @TestSetKeepAlive);
  T.Run('TCP listener exposes runtime socket control',
    @TestTcpListenerSupportsRuntimeSocketControl);
  T.Run('TCP stream exposes runtime socket control',
    @TestTcpStreamSupportsRuntimeSocketControl);
  T.Run('TCP listener try-accept reports would-block and accept',
    @TestTcpListenerRuntimeTryAccept);
  T.Run('TCP stream try-read and try-write support nonblocking runtime I/O',
    @TestTcpStreamRuntimeTryReadAndTryWrite);
  T.Run('TCP stream post-close runtime guards',
    @TestTcpStreamPostCloseRuntimeGuards);
  T.Summary;
end.
