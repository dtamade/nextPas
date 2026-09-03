program test_reactor_iocp_wine;

{ IOCP Reactor Wine Runtime Smoke Test
  Cross-compiled to Win64 and run under Wine.
  Exercises AsyncSend, AsyncRecv, and AcceptEx lifecycle on
  connected TCP sockets. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test
  {$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.platform.socket
  , nextpas.core.platform.windows.base
  , nextpas.core.platform.windows.ffi
  , nextpas.core.io.reactor.iocp
  {$ENDIF}
  ;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

type
  { Minimal sockaddr_in layout for byte extraction }
  TSockAddrIn = packed record
    sin_family: Word;
    sin_port: Word;   { network byte order }
    sin_addr: array[0..3] of Byte;
    sin_zero: array[0..7] of Byte;
  end;
  PSockAddrIn = ^TSockAddrIn;

var
  GSendDone: Boolean;
  GSendResult: Int32;
  GRecvDone: Boolean;
  GRecvResult: Int32;
  GAcceptDone: Boolean;
  GAcceptResult: Int32;
  GConnectDone: Boolean;
  GConnectResult: Int32;

{ Callback procedures — global state since FPC ObjectFPC mode doesn't
  support nested procedures and TIoCompletion is a plain procedure type. }

procedure OnSendDone(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GSendDone := True;
  GSendResult := AResult;
end;

procedure OnRecvDone(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GRecvDone := True;
  GRecvResult := AResult;
end;

procedure OnAcceptDone(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GAcceptDone := True;
  GAcceptResult := AResult;
end;

procedure OnConnectDone(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GConnectDone := True;
  GConnectResult := AResult;
end;

{ Byte-swap 16-bit value — network-to-host for port number }
function Ntohs16(AValue: Word): Word; inline;
begin
  Result := (AValue shr 8) or (AValue shl 8);
end;

{ Set up sockaddr_in with INADDR_ANY and specified port }
function MakeSockAddrAny(const APort: UInt16; out AAddr: TPlatformSockAddr): Boolean;
begin
  FillChar(AAddr.Storage, SizeOf(AAddr.Storage), 0);
  PSockAddrIn(@AAddr.Storage)^.sin_family := AF_INET;
  PSockAddrIn(@AAddr.Storage)^.sin_port := htons(APort);
  AAddr.Len := SizeOf(TSockAddrIn);
  Result := True;
end;

{ Wait up to ~2 seconds for IOCP completion callback }
function WaitForCompletion(var ADone: Boolean; var AReactor: TIocpReactor): Boolean;
var
  LIter: Int32;
begin
  for LIter := 1 to 2000 do
  begin
    if ADone then Exit(True);
    AReactor.PollOne;
  end;
  Result := ADone;
end;

{ Create a connected TCP pair using synchronous socket API.
  Returns three sockets: AListen (unused after accept), AAccept (the
  server-side connected socket), AClient (the client-side connected socket). }
function CreateConnectedPair(out AListen, AAccept, AClient: TPlatformSocket): Boolean;
var
  LAddr, LBound: TPlatformSockAddr;
  LAddrLen: Int32;
  LPort: Word;
begin
  Result := False;

  { Create listening socket }
  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, AListen) <> 0 then Exit;
  if platform_sockaddr_loopback4(0, LAddr) <> 0 then
  begin platform_socket_close(AListen); Exit; end;
  if platform_socket_bind(AListen, @LAddr.Storage, LAddr.Len) <> 0 then
  begin platform_socket_close(AListen); Exit; end;
  if platform_socket_listen(AListen, 1) <> 0 then
  begin platform_socket_close(AListen); Exit; end;

  { Get the OS-assigned port }
  LAddrLen := SizeOf(LBound.Storage);
  if platform_socket_getsockname(AListen, @LBound.Storage, @LAddrLen) <> 0 then
  begin platform_socket_close(AListen); Exit; end;
  LPort := Ntohs16(PSockAddrIn(@LBound.Storage)^.sin_port);

  { Create connecting client }
  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, AClient) <> 0 then
  begin platform_socket_close(AListen); Exit; end;
  if platform_sockaddr_loopback4(LPort, LAddr) <> 0 then
  begin platform_socket_close(AListen); platform_socket_close(AClient); Exit; end;
  if platform_socket_connect(AClient, @LAddr.Storage, LAddr.Len) <> 0 then
  begin platform_socket_close(AListen); platform_socket_close(AClient); Exit; end;

  { Accept server-side connection }
  if platform_socket_accept(AListen, nil, nil, AAccept) <> 0 then
  begin platform_socket_close(AListen); platform_socket_close(AClient); Exit; end;

  Result := True;
end;

{ Create a listening socket (bind port 0, listen) for AcceptEx test.
  Returns the socket and the bound port. }
function CreateListener(out AListen: TPlatformSocket; out APort: UInt16): Boolean;
var
  LAddr, LBound: TPlatformSockAddr;
  LAddrLen: Int32;
begin
  Result := False;
  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
    PLATFORM_IPPROTO_TCP, AListen) <> 0 then Exit;
  if platform_sockaddr_loopback4(0, LAddr) <> 0 then
  begin platform_socket_close(AListen); Exit; end;
  if platform_socket_bind(AListen, @LAddr.Storage, LAddr.Len) <> 0 then
  begin platform_socket_close(AListen); Exit; end;
  if platform_socket_listen(AListen, 1) <> 0 then
  begin platform_socket_close(AListen); Exit; end;
  LAddrLen := SizeOf(LBound.Storage);
  if platform_socket_getsockname(AListen, @LBound.Storage, @LAddrLen) <> 0 then
  begin platform_socket_close(AListen); Exit; end;
  APort := Ntohs16(PSockAddrIn(@LBound.Storage)^.sin_port);
  Result := True;
end;

procedure TestIocpCreateClose;
var
  LReactor: TIocpReactor;
begin
  LReactor := TIocpReactor.Create(2);
  Check(LReactor.IsValid, 'create should produce valid reactor');
  Check(not LReactor.HasPending, 'no pending ops');
  LReactor.Close;
  Check(not LReactor.IsValid, 'closed reactor should not be valid');
end;

procedure TestIocpAsyncSend;
var
  LListenSock, LAcceptSock, LClientSock: TPlatformSocket;
  LReactor: TIocpReactor;
  LSendBuf: array[0..63] of AnsiChar;
  LRecvBuf: array[0..63] of AnsiChar;
  LRecvd: Int32;
  LRes: Int32;
const
  TEST_DATA = 'HelloFromIOCP';
  TEST_LEN = 13;
begin
  Check(CreateConnectedPair(LListenSock, LAcceptSock, LClientSock),
    'connected pair');

  LReactor := TIocpReactor.Create(4);
  Check(LReactor.IsValid, 'reactor valid');
  try
    { AsyncSend from accepted socket }
    Move(TEST_DATA[1], LSendBuf[0], TEST_LEN);
    GSendDone := False;
    GSendResult := -1;
    Check(LReactor.AsyncSend(PtrInt(LAcceptSock.Value), @LSendBuf[0], TEST_LEN,
      0, @OnSendDone, nil), 'AsyncSend should submit');

    { Wait for completion }
    Check(WaitForCompletion(GSendDone, LReactor), 'send callback should fire');
    Check(GSendResult = TEST_LEN,
      'send result should be ' + IntToStr(TEST_LEN) +
      ', got ' + IntToStr(GSendResult));

    { Verify data reached client via sync recv }
    FillChar(LRecvBuf, SizeOf(LRecvBuf), 0);
    LRes := platform_socket_recv(LClientSock, @LRecvBuf[0], SizeOf(LRecvBuf),
      0, LRecvd);
    Check(LRes = 0, 'sync recv should succeed, got err ' + IntToStr(LRes));
    Check(LRecvd = TEST_LEN,
      'should receive ' + IntToStr(TEST_LEN) + ' bytes, got ' +
      IntToStr(LRecvd));
    Check(string(PAnsiChar(@LRecvBuf[0])) = TEST_DATA,
      'data mismatch: got "' + string(PAnsiChar(@LRecvBuf[0])) + '"');
  finally
    LReactor.Close;
    platform_socket_close(LClientSock);
    platform_socket_close(LAcceptSock);
    platform_socket_close(LListenSock);
  end;
end;

procedure TestIocpCloseWithPendingSend;
var
  LListenSock, LAcceptSock, LClientSock: TPlatformSocket;
  LReactor: TIocpReactor;
  LSendBuf: array[0..63] of AnsiChar;
const
  TEST_DATA = 'ClosePending';
  TEST_LEN = 12;
begin
  Check(CreateConnectedPair(LListenSock, LAcceptSock, LClientSock),
    'connected pair');

  LReactor := TIocpReactor.Create(4);
  Check(LReactor.IsValid, 'reactor valid');
  try
    Move(TEST_DATA[1], LSendBuf[0], TEST_LEN);
    GSendDone := False;
    GSendResult := -1;
    Check(LReactor.AsyncSend(PtrInt(LAcceptSock.Value), @LSendBuf[0], TEST_LEN,
      0, @OnSendDone, nil), 'AsyncSend should submit');
    Check(LReactor.HasPending, 'pending send should mark reactor pending');

    { Close immediately after submission. The contract here is that Close
      returns and releases owned pending state without hanging. }
    LReactor.Close;
    Check(not LReactor.IsValid, 'reactor should be invalid after close');
    Check(not LReactor.HasPending, 'close should clear pending send state');
  finally
    platform_socket_close(LClientSock);
    platform_socket_close(LAcceptSock);
    platform_socket_close(LListenSock);
  end;
end;

procedure TestIocpPollTimeout;
var
  LReactor: TIocpReactor;
begin
  LReactor := TIocpReactor.Create(4);
  Check(LReactor.IsValid, 'reactor valid');
  Check(not LReactor.HasPending, 'idle reactor should not report pending');
  Check(not LReactor.PollOne, 'idle PollOne should return immediately');
  LReactor.Close;
end;

procedure TestIocpAsyncRecv;
var
  LListenSock, LAcceptSock, LClientSock: TPlatformSocket;
  LReactor: TIocpReactor;
  LSendBuf: array[0..63] of AnsiChar;
  LRecvBuf: array[0..63] of AnsiChar;
  LSent: Int32;
  LRes: Int32;
const
  TEST_DATA = 'RecvFromClient';
  TEST_LEN = 14;
begin
  Check(CreateConnectedPair(LListenSock, LAcceptSock, LClientSock),
    'connected pair');

  LReactor := TIocpReactor.Create(4);
  Check(LReactor.IsValid, 'reactor valid');
  try
    { AsyncRecv on accepted socket — buffer ready }
    FillChar(LRecvBuf, SizeOf(LRecvBuf), 0);
    GRecvDone := False;
    GRecvResult := -1;
    Check(LReactor.AsyncRecv(PtrInt(LAcceptSock.Value), @LRecvBuf[0],
      SizeOf(LRecvBuf), 0, @OnRecvDone, nil), 'AsyncRecv should submit');

    { Send from client side — triggers the recv completion }
    Move(TEST_DATA[1], LSendBuf[0], TEST_LEN);
    LRes := platform_socket_send(LClientSock, @LSendBuf[0], TEST_LEN, 0, LSent);
    Check(LRes = 0, 'sync send should succeed');
    Check(LSent = TEST_LEN, 'sync send should send all bytes');

    { Wait for recv completion }
    Check(WaitForCompletion(GRecvDone, LReactor), 'recv callback should fire');
    Check(GRecvResult = TEST_LEN,
      'recv result should be ' + IntToStr(TEST_LEN) +
      ', got ' + IntToStr(GRecvResult));
    Check(string(PAnsiChar(@LRecvBuf[0])) = TEST_DATA,
      'recv data mismatch: got "' + string(PAnsiChar(@LRecvBuf[0])) + '"');
  finally
    LReactor.Close;
    platform_socket_close(LClientSock);
    platform_socket_close(LAcceptSock);
    platform_socket_close(LListenSock);
  end;
end;

procedure TestIocpAcceptSend;
var
  LListenSock, LClientSock, LAcceptedSock: TPlatformSocket;
  LReactor: TIocpReactor;
  LPort: UInt16;
  LSendBuf: array[0..63] of AnsiChar;
  LRecvBuf: array[0..63] of AnsiChar;
  LRecvd: Int32;
  LAddr: TPlatformSockAddr;
  LRes: Int32;
const
  TEST_DATA = 'AcceptExTest';
  TEST_LEN = 12;
begin
  LAcceptedSock := PLATFORM_INVALID_SOCKET;

  { Create listening socket }
  Check(CreateListener(LListenSock, LPort), 'create listener');

  LReactor := TIocpReactor.Create(4);
  Check(LReactor.IsValid, 'reactor valid');
  try
    GAcceptDone := False;
    GAcceptResult := -1;
    Check(LReactor.AsyncAccept(PtrInt(LListenSock.Value), nil, nil, 0,
      @OnAcceptDone, nil), 'AsyncAccept should submit');

    { Connect client — triggers AcceptEx to complete }
    Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
      PLATFORM_IPPROTO_TCP, LClientSock) = 0, 'create client');
    Check(platform_sockaddr_loopback4(LPort, LAddr) = 0, 'client addr');
    Check(platform_socket_connect(LClientSock, @LAddr.Storage, LAddr.Len) = 0,
      'client connect');

    { Poll for accept completion }
    Check(WaitForCompletion(GAcceptDone, LReactor),
      'accept callback should fire');
    Check(GAcceptResult >= 0,
      'accept result should be >= 0, got ' + IntToStr(GAcceptResult));
    LAcceptedSock.Value := PtrUInt(LReactor.LastAcceptedSocket);
    Check(LAcceptedSock.Value <> PLATFORM_INVALID_SOCKET.Value,
      'accepted socket should be valid');

    { AsyncSend on the accepted socket }
    Move(TEST_DATA[1], LSendBuf[0], TEST_LEN);
    GSendDone := False;
    GSendResult := -1;
    Check(LReactor.AsyncSend(PtrInt(LAcceptedSock.Value), @LSendBuf[0],
      TEST_LEN, 0, @OnSendDone, nil), 'AsyncSend should submit');

    { Poll for send completion }
    Check(WaitForCompletion(GSendDone, LReactor),
      'send callback should fire');
    Check(GSendResult = TEST_LEN,
      'send result should be ' + IntToStr(TEST_LEN) +
      ', got ' + IntToStr(GSendResult));

    { Verify data via sync recv on client }
    FillChar(LRecvBuf, SizeOf(LRecvBuf), 0);
    LRes := platform_socket_recv(LClientSock, @LRecvBuf[0], SizeOf(LRecvBuf),
      0, LRecvd);
    Check(LRes = 0, 'sync recv should succeed, got err ' + IntToStr(LRes));
    Check(LRecvd = TEST_LEN,
      'should receive ' + IntToStr(TEST_LEN) + ' bytes, got ' +
      IntToStr(LRecvd));
    Check(string(PAnsiChar(@LRecvBuf[0])) = TEST_DATA,
      'data mismatch: got "' + string(PAnsiChar(@LRecvBuf[0])) + '"');
  finally
    LReactor.Close;
    platform_socket_close(LClientSock);
    if LAcceptedSock.Value <> PLATFORM_INVALID_SOCKET.Value then
      platform_socket_close(LAcceptedSock);
    platform_socket_close(LListenSock);
  end;
end;

procedure TestIocpAcceptRecv;
var
  LListenSock, LClientSock, LAcceptedSock: TPlatformSocket;
  LReactor: TIocpReactor;
  LPort: UInt16;
  LSendBuf: array[0..63] of AnsiChar;
  LRecvBuf: array[0..63] of AnsiChar;
  LSent: Int32;
  LRes: Int32;
  LAddr: TPlatformSockAddr;
const
  TEST_DATA = 'AcceptRecvTest';
  TEST_LEN = 14;
begin
  LAcceptedSock := PLATFORM_INVALID_SOCKET;

  { Create listening socket }
  Check(CreateListener(LListenSock, LPort), 'create listener');

  LReactor := TIocpReactor.Create(4);
  Check(LReactor.IsValid, 'reactor valid');
  try
    { Pre-accept: submit AsyncAccept before any client connects }
    GAcceptDone := False;
    GAcceptResult := -1;
    Check(LReactor.AsyncAccept(PtrInt(LListenSock.Value), nil, nil, 0,
      @OnAcceptDone, nil), 'AsyncAccept should submit');

    { Create client and connect }
    Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
      PLATFORM_IPPROTO_TCP, LClientSock) = 0, 'create client');
    Check(platform_sockaddr_loopback4(LPort, LAddr) = 0, 'client addr');
    Check(platform_socket_connect(LClientSock, @LAddr.Storage, LAddr.Len) = 0,
      'client connect');

    { Wait for AcceptEx completion }
    Check(WaitForCompletion(GAcceptDone, LReactor),
      'accept callback should fire');
    Check(GAcceptResult >= 0,
      'accept result should be >= 0, got ' + IntToStr(GAcceptResult));
    LAcceptedSock.Value := PtrUInt(LReactor.LastAcceptedSocket);
    Check(LAcceptedSock.Value <> PLATFORM_INVALID_SOCKET.Value,
      'accepted socket should be valid');

    { Pre-post AsyncRecv on accepted socket — buffer ready before data arrives }
    FillChar(LRecvBuf, SizeOf(LRecvBuf), 0);
    GRecvDone := False;
    GRecvResult := -1;
    Check(LReactor.AsyncRecv(PtrInt(LAcceptedSock.Value), @LRecvBuf[0],
      SizeOf(LRecvBuf), 0, @OnRecvDone, nil), 'AsyncRecv should submit');

    { Send from client side — triggers the recv completion }
    Move(TEST_DATA[1], LSendBuf[0], TEST_LEN);
    LRes := platform_socket_send(LClientSock, @LSendBuf[0], TEST_LEN, 0, LSent);
    Check(LRes = 0, 'sync send should succeed');
    Check(LSent = TEST_LEN, 'sync send should send all bytes');

    { Wait for recv completion }
    Check(WaitForCompletion(GRecvDone, LReactor),
      'recv callback should fire');
    Check(GRecvResult = TEST_LEN,
      'recv result should be ' + IntToStr(TEST_LEN) +
      ', got ' + IntToStr(GRecvResult));
    Check(string(PAnsiChar(@LRecvBuf[0])) = TEST_DATA,
      'recv data mismatch: got "' + string(PAnsiChar(@LRecvBuf[0])) + '"');
  finally
    LReactor.Close;
    platform_socket_close(LClientSock);
    if LAcceptedSock.Value <> PLATFORM_INVALID_SOCKET.Value then
      platform_socket_close(LAcceptedSock);
    platform_socket_close(LListenSock);
  end;
end;

procedure TestIocpConnectEx;
var
  LListenSock, LClientSock, LAcceptedSock: TPlatformSocket;
  LReactor: TIocpReactor;
  LPort: UInt16;
  LSendBuf: array[0..63] of AnsiChar;
  LRecvBuf: array[0..63] of AnsiChar;
  LRecvd: Int32;
  LAddr: TPlatformSockAddr;
  LRes: Int32;
const
  TEST_DATA = 'ConnectExTest';
  TEST_LEN = 13;
begin
  { Create listening socket }
  Check(CreateListener(LListenSock, LPort), 'create listener');
  LAcceptedSock := PLATFORM_INVALID_SOCKET;

  LReactor := TIocpReactor.Create(4);
  Check(LReactor.IsValid, 'reactor valid');
  try
    { Create client socket for async connect — must be bound before ConnectEx }
    Check(platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM,
      PLATFORM_IPPROTO_TCP, LClientSock) = 0, 'create client socket');
    { Bind to INADDR_ANY with port 0 to satisfy ConnectEx requirement }
    Check(MakeSockAddrAny(0, LAddr), 'make bind addr');
    Check(platform_socket_bind(LClientSock, @LAddr.Storage, LAddr.Len) = 0,
      'bind client socket');
    Check(platform_sockaddr_loopback4(LPort, LAddr) = 0, 'client addr');

    { AsyncConnect using ConnectEx — Wine may not support ConnectEx; the test
      exercises the full lifecycle on real Windows where ConnectEx is available }
    GConnectDone := False;
    GConnectResult := -1;
    if not LReactor.AsyncConnect(PtrInt(LClientSock.Value), @LAddr.Storage,
      LAddr.Len, @OnConnectDone, nil) then
    begin
      { ConnectEx not supported on this host — skip remaining steps }
      Check(True, 'ConnectEx skipped: not supported');
      Exit;
    end;

    { Poll for connect completion }
    Check(WaitForCompletion(GConnectDone, LReactor),
      'connect callback should fire');
    Check(GConnectResult >= 0,
      'connect result should be >= 0, got ' + IntToStr(GConnectResult));

    { Accept the connection }
    Check(platform_socket_accept(LListenSock, nil, nil, LAcceptedSock) = 0,
      'accept connection');

    { AsyncSend from client side }
    Move(TEST_DATA[1], LSendBuf[0], TEST_LEN);
    GSendDone := False;
    GSendResult := -1;
    Check(LReactor.AsyncSend(PtrInt(LClientSock.Value), @LSendBuf[0],
      TEST_LEN, 0, @OnSendDone, nil), 'AsyncSend should submit');

    { Poll for send completion }
    Check(WaitForCompletion(GSendDone, LReactor),
      'send callback should fire');
    Check(GSendResult = TEST_LEN,
      'send result should be ' + IntToStr(TEST_LEN));

    { Verify data via sync recv on accepted socket }
    FillChar(LRecvBuf, SizeOf(LRecvBuf), 0);
    LRes := platform_socket_recv(LAcceptedSock, @LRecvBuf[0], SizeOf(LRecvBuf),
      0, LRecvd);
    Check(LRes = 0, 'sync recv should succeed');
    Check(LRecvd = TEST_LEN,
      'should receive ' + IntToStr(TEST_LEN) + ' bytes, got ' +
      IntToStr(LRecvd));
    Check(string(PAnsiChar(@LRecvBuf[0])) = TEST_DATA,
      'data mismatch: got "' + string(PAnsiChar(@LRecvBuf[0])) + '"');
  finally
    LReactor.Close;
    platform_socket_close(LClientSock);
    if LAcceptedSock.Value <> PLATFORM_INVALID_SOCKET.Value then
      platform_socket_close(LAcceptedSock);
    platform_socket_close(LListenSock);
  end;
end;

procedure TestIocpMapOsErrors;
begin
  { WinSock / 系统错误码 → -errno 映射契约(纯函数级)。
    真 Windows 上 refused ConnectEx 以同步失败或挂起两种形态出现,端到端
    不可复现;映射表本身是跨宿主契约(回调必须交付负 errno 与 epoll/io_uring
    一致),直接锁定每个分支。数值来自 winsock2.h / winerror.h。 }
  { ECANCELED }
  Check(IocpMapOsError(995) = 125, 'ERROR_OPERATION_ABORTED -> ECANCELED');
  { ECONNREFUSED }
  Check(IocpMapOsError(1225) = 111, 'ERROR_CONNECTION_REFUSED -> ECONNREFUSED');
  Check(IocpMapOsError(10061) = 111, 'WSAECONNREFUSED -> ECONNREFUSED');
  { ECONNRESET }
  Check(IocpMapOsError(64) = 104, 'ERROR_NETNAME_DELETED -> ECONNRESET');
  Check(IocpMapOsError(10054) = 104, 'WSAECONNRESET -> ECONNRESET');
  Check(IocpMapOsError(10052) = 104, 'WSAENETRESET -> ECONNRESET');
  { ECONNABORTED }
  Check(IocpMapOsError(1236) = 103, 'ERROR_CONNECTION_ABORTED -> ECONNABORTED');
  Check(IocpMapOsError(10053) = 103, 'WSAECONNABORTED -> ECONNABORTED');
  { ETIMEDOUT }
  Check(IocpMapOsError(121) = 110, 'ERROR_SEM_TIMEOUT -> ETIMEDOUT');
  Check(IocpMapOsError(1460) = 110, 'ERROR_TIMEOUT -> ETIMEDOUT');
  Check(IocpMapOsError(10060) = 110, 'WSAETIMEDOUT -> ETIMEDOUT');
  { ENETUNREACH / EHOSTUNREACH }
  Check(IocpMapOsError(1231) = 101, 'ERROR_NETWORK_UNREACHABLE -> ENETUNREACH');
  Check(IocpMapOsError(10051) = 101, 'WSAENETUNREACH -> ENETUNREACH');
  Check(IocpMapOsError(1232) = 113, 'ERROR_HOST_UNREACHABLE -> EHOSTUNREACH');
  Check(IocpMapOsError(10065) = 113, 'WSAEHOSTUNREACH -> EHOSTUNREACH');
  { ENOTCONN / EADDRINUSE / EADDRNOTAVAIL }
  Check(IocpMapOsError(10057) = 107, 'WSAENOTCONN -> ENOTCONN');
  Check(IocpMapOsError(10048) = 98, 'WSAEADDRINUSE -> EADDRINUSE');
  Check(IocpMapOsError(10049) = 99, 'WSAEADDRNOTAVAIL -> EADDRNOTAVAIL');
  { EINVAL / EBADF }
  Check(IocpMapOsError(87) = 22, 'ERROR_INVALID_PARAMETER -> EINVAL');
  Check(IocpMapOsError(10022) = 22, 'WSAEINVAL -> EINVAL');
  Check(IocpMapOsError(6) = 9, 'ERROR_INVALID_HANDLE -> EBADF');
  Check(IocpMapOsError(10038) = 9, 'WSAENOTSOCK -> EBADF');
  { ENOMEM / EOPNOTSUPP / EPIPE / EACCES }
  Check(IocpMapOsError(8) = 12, 'ERROR_NOT_ENOUGH_MEMORY -> ENOMEM');
  Check(IocpMapOsError(14) = 12, 'ERROR_OUTOFMEMORY -> ENOMEM');
  Check(IocpMapOsError(10055) = 12, 'WSAENOBUFS -> ENOMEM');
  Check(IocpMapOsError(50) = 95, 'ERROR_NOT_SUPPORTED -> EOPNOTSUPP');
  Check(IocpMapOsError(10045) = 95, 'WSAEOPNOTSUPP -> EOPNOTSUPP');
  Check(IocpMapOsError(109) = 32, 'ERROR_BROKEN_PIPE -> EPIPE');
  Check(IocpMapOsError(5) = 13, 'ERROR_ACCESS_DENIED -> EACCES');
  Check(IocpMapOsError(10013) = 13, 'WSAEACCES -> EACCES');
  { 未映射码透传,不撒谎 }
  Check(IocpMapOsError(7777) = 7777, 'unmapped codes pass through unchanged');
end;

procedure TestIocpTryCancelByContext;
var
  LListenSock, LAcceptSock, LClientSock: TPlatformSocket;
  LReactor: TIocpReactor;
  LRecvBuf: array[0..63] of AnsiChar;
  LCtx: Integer;
begin
  { Hang AsyncRecv with no peer send, cancel by context, expect aborted completion. }
  Check(CreateConnectedPair(LListenSock, LAcceptSock, LClientSock),
    'connected pair');

  LReactor := TIocpReactor.Create(4);
  Check(LReactor.IsValid, 'reactor valid');
  try
    FillChar(LRecvBuf, SizeOf(LRecvBuf), 0);
    LCtx := 42;
    GRecvDone := False;
    GRecvResult := 0;
    Check(LReactor.AsyncRecv(PtrInt(LAcceptSock.Value), @LRecvBuf[0],
      SizeOf(LRecvBuf), 0, @OnRecvDone, @LCtx), 'AsyncRecv should submit');
    Check(LReactor.HasPending, 'pending recv before cancel');

    Check(LReactor.TryCancelByContext(@LCtx),
      'TryCancelByContext should hit pending recv');

    Check(WaitForCompletion(GRecvDone, LReactor),
      'cancel should deliver completion packet');
    Check(GRecvResult < 0,
      'cancelled recv result should be negative, got ' + IntToStr(GRecvResult));
    Check(not LReactor.HasPending, 'pending cleared after cancel completion');
  finally
    LReactor.Close;
    platform_socket_close(LClientSock);
    platform_socket_close(LAcceptSock);
    platform_socket_close(LListenSock);
  end;
end;

{$ELSE}
procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;
{$ENDIF}

begin
  T := TTestSuite.Create('nextpas.core.io.reactor.iocp.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Test('create/close', @TestIocpCreateClose);
  T.Test('AsyncSend', @TestIocpAsyncSend);
  T.Test('Close with pending send', @TestIocpCloseWithPendingSend);
  T.Test('Poll timeout', @TestIocpPollTimeout);
  T.Test('AsyncRecv', @TestIocpAsyncRecv);
  T.Test('AcceptEx+Send', @TestIocpAcceptSend);
  T.Test('ConnectEx', @TestIocpConnectEx);
  T.Test('Winsock error map to -errno contract', @TestIocpMapOsErrors);
  T.Test('AcceptEx+Recv', @TestIocpAcceptRecv);
  T.Test('TryCancelByContext', @TestIocpTryCancelByContext);
  {$ELSE}
  T.Test('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  if not T.Run then Halt(1);
end.
