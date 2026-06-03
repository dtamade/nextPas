program test_net_server;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.net.server,
  nextpas.core.platform.thread,
  nextpas.core.time.base,
  nextpas.core.time.deadline;

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: ITcpServer;
    Handler: ITcpServerHandler;
    Addr: string;
    Port: UInt16;
  end;

  TEchoHandler = class(TInterfacedObject, ITcpServerHandler)
  private
    FCalled: Boolean;
    FSeenRemoteAddr: string;
  public
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
    property Called: Boolean read FCalled;
    property SeenRemoteAddr: string read FSeenRemoteAddr;
  end;

  TDetachHandler = class(TInterfacedObject, ITcpServerHandler)
  private
    FConn: ITcpStream;
  public
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
    property Conn: ITcpStream read FConn;
  end;

var
  T: TTestRunner;

function ServerThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PServerCtx;
begin
  Result := nil;
  LCtx := PServerCtx(AArg);
  try
    LCtx^.Server.ListenAndServe(LCtx^.Addr, LCtx^.Port, LCtx^.Handler);
  finally
    LCtx^.Server := nil;
    LCtx^.Handler := nil;
    Dispose(LCtx);
  end;
end;

function TEchoHandler.ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
var
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
begin
  FCalled := True;
  FSeenRemoteAddr := AConn.RemoteAddr.ToString;
  LN := AConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
  if LN > 0 then
    AConn.Write(LBuf[0], LN);
  Result := TCP_SERVER_CONN_OWNERSHIP_SERVER;
end;

function TDetachHandler.ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
begin
  FConn := AConn;
  Result := TCP_SERVER_CONN_OWNERSHIP_HANDLER;
end;

procedure TestDefaultOptions;
var
  LOptions: TTcpServerOptions;
begin
  LOptions := TTcpServerOptions.Default;
  Check(LOptions.Backend = TCP_SERVER_BACKEND_THREADED,
    'default backend is threaded');
end;

procedure TestThreadedServerEcho;
var
  LHandler: TEchoHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
  LRet: Pointer;
begin
  LHandler := TEchoHandler.Create;
  LServer := NewTcpServer;
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  LClient.Write(PAnsiChar('ping')^, 4);
  LClient.Shutdown;
  LN := LClient.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
  CheckEqual(SizeUInt(4), LN, 'echo size');
  CheckEqual(Byte(Ord('p')), LBuf[0], 'echo first byte');
  Check(LHandler.Called, 'handler called');
  Check(Pos('127.0.0.1', LHandler.SeenRemoteAddr) > 0, 'handler sees remote addr');
  LClient.Close;

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
end;

procedure TestThreadedServerShutdownWithoutClients;
var
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LRet: Pointer;
begin
  LServer := NewTcpServer(TTcpServerOptions.Default);
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := TEchoHandler.Create;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  Check(LServer.IsRunning, 'server started');
  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
  Check(not LServer.IsRunning, 'server stopped after shutdown');
end;

procedure TestThreadedServerDetachKeepsConnectionOpen;
var
  LHandler: TDetachHandler;
  LServer: ITcpServer;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LPort: UInt16;
  LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
  LRet: Pointer;
  LProbe: string;
begin
  LHandler := TDetachHandler.Create;
  LServer := NewTcpServer;
  New(LCtx);
  LCtx^.Server := LServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);

  LWait := 0;
  while (not LServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;

  LPort := LServer.LocalAddr.Port;
  Check(LPort > 0, 'server exposes bound port');

  LClient := TcpConnect('127.0.0.1', LPort);
  try
    LWait := 0;
    while (LHandler.Conn = nil) and (LWait < 200) do
    begin
      platform_thread_sleep_ns(5000000);
      Inc(LWait);
    end;

    Check(LHandler.Conn <> nil, 'handler captured detached connection');
    platform_thread_sleep_ns(100000000);

    LProbe := 'probe';
    LHandler.Conn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(1)));
    LClient.Write(LProbe[1], SizeUInt(Length(LProbe)));
    LN := LHandler.Conn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    CheckEqual(Int64(Length(LProbe)), Int64(LN),
      'detached connection stays readable after handler returns');
    CheckEqual(Byte(Ord('p')), LBuf[0], 'detached connection received probe');

    LHandler.Conn.Shutdown;
    LHandler.Conn.Close;
  finally
    LClient.Close;
  end;

  LServer.Shutdown;
  platform_thread_join(LHandle, LRet);
end;

begin
  T := TTestRunner.Create('nextpas.core.net.server');
  T.Run('Default options', @TestDefaultOptions);
  T.Run('Threaded server echo', @TestThreadedServerEcho);
  T.Run('Threaded server shutdown without clients', @TestThreadedServerShutdownWithoutClients);
  T.Run('Threaded server detach keeps connection open', @TestThreadedServerDetachKeepsConnectionOpen);
  T.Summary;
end.
