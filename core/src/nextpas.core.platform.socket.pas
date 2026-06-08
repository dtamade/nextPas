unit nextpas.core.platform.socket;

{$I nextpas.core.settings.inc}

interface

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base;
{$ENDIF}

const
{$IFDEF NEXTPAS_WINDOWS}
  PLATFORM_AF_INET     = 2;
  PLATFORM_AF_INET6    = 23;
  PLATFORM_SOCK_STREAM = 1;
  PLATFORM_SOCK_DGRAM  = 2;
  PLATFORM_IPPROTO_TCP = 6;
  PLATFORM_IPPROTO_UDP = 17;
  PLATFORM_SOL_SOCKET  = $FFFF;
  PLATFORM_SO_REUSEADDR = $0004;
  PLATFORM_SO_REUSEPORT = $0004;
  PLATFORM_SO_KEEPALIVE = $0008;
  PLATFORM_SO_RCVTIMEO = $1006;
  PLATFORM_SO_SNDTIMEO = $1005;
  PLATFORM_TCP_NODELAY  = $0001;
  PLATFORM_SHUT_RD     = 0;
  PLATFORM_SHUT_WR     = 1;
  PLATFORM_SHUT_RDWR   = 2;
{$ELSE}
  PLATFORM_AF_INET     = AF_INET;
  PLATFORM_AF_INET6    = AF_INET6;
  PLATFORM_SOCK_STREAM = SOCK_STREAM;
  PLATFORM_SOCK_DGRAM  = SOCK_DGRAM;
  PLATFORM_IPPROTO_TCP = IPPROTO_TCP;
  PLATFORM_IPPROTO_UDP = IPPROTO_UDP;
  PLATFORM_SOL_SOCKET  = SOL_SOCKET;
  PLATFORM_SO_REUSEADDR = SO_REUSEADDR;
  PLATFORM_SO_REUSEPORT = 15;
  PLATFORM_SO_KEEPALIVE = SO_KEEPALIVE;
  PLATFORM_SO_RCVTIMEO = 20;
  PLATFORM_SO_SNDTIMEO = 21;
  PLATFORM_TCP_NODELAY  = TCP_NODELAY;
  PLATFORM_SHUT_RD     = SHUT_RD;
  PLATFORM_SHUT_WR     = SHUT_WR;
  PLATFORM_SHUT_RDWR   = SHUT_RDWR;
{$ENDIF}

type
  TPlatformSocket = record
  {$IFDEF NEXTPAS_WINDOWS}
    Value: PtrUInt;
  {$ELSE}
    Value: cint;
  {$ENDIF}
  end;

const
  PLATFORM_INVALID_SOCKET: TPlatformSocket = (
  {$IFDEF NEXTPAS_WINDOWS}
    Value: PtrUInt(-1)
  {$ELSE}
    Value: -1
  {$ENDIF}
  );

function platform_socket_create(const ADomain, AType, AProtocol: Int32;
  out ASocket: TPlatformSocket): Int32;
function platform_socket_close(var ASocket: TPlatformSocket): Int32;
function platform_socket_bind(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Int32): Int32;
function platform_socket_listen(const ASocket: TPlatformSocket;
  ABacklog: Int32): Int32;
function platform_socket_accept(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer; out AClient: TPlatformSocket): Int32;
function platform_socket_connect(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Int32): Int32;
function platform_socket_send(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32; out ASent: Int32): Int32;
function platform_socket_recv(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32; out ARecvd: Int32): Int32;
function platform_socket_shutdown(const ASocket: TPlatformSocket;
  AHow: Int32): Int32;
function platform_socket_setsockopt(const ASocket: TPlatformSocket;
  ALevel, AOptName: Int32; AOptVal: Pointer; AOptLen: Int32): Int32;
function platform_socket_sendto(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32;
  AAddr: Pointer; AAddrLen: Int32; out ASent: Int32): Int32;
function platform_socket_recvfrom(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32;
  AAddr: Pointer; AAddrLen: Pointer; out ARecvd: Int32): Int32;
function platform_socket_getsockname(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer): Int32;
function platform_socket_getpeername(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer): Int32;
function platform_socket_resolve_ipv4(const AHost: PAnsiChar; out AAddr: UInt32): Int32;
function platform_socket_set_nonblocking(const ASocket: TPlatformSocket;
  const ANonBlock: Boolean): Int32;
function platform_socket_set_timeout(const ASocket: TPlatformSocket;
  const AOptName: Int32; const AMs: UInt32): Int32;
function platform_socket_error_would_block(const AError: Int32): Boolean;
function platform_socket_error_timed_out(const AError: Int32): Boolean;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.ffi,
  {$IFDEF NEXTPAS_LINUX}nextpas.core.platform.linux.base{$ENDIF}
  {$IFDEF NEXTPAS_DARWIN}nextpas.core.platform.darwin.base{$ENDIF}
  {$IFDEF NEXTPAS_FREEBSD}nextpas.core.platform.freebsd.base{$ENDIF}
  ;

function platform_socket_create(const ADomain, AType, AProtocol: Int32;
  out ASocket: TPlatformSocket): Int32;
begin
  ASocket.Value := socket(ADomain, AType, AProtocol);
  if ASocket.Value < 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_socket_close(var ASocket: TPlatformSocket): Int32;
begin
  if ASocket.Value < 0 then
    Exit(0);
  if close(ASocket.Value) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
  ASocket.Value := -1;
end;

function platform_socket_bind(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Int32): Int32;
begin
  if bind(ASocket.Value, AAddr, socklen_t(AAddrLen)) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_socket_listen(const ASocket: TPlatformSocket;
  ABacklog: Int32): Int32;
begin
  if listen(ASocket.Value, ABacklog) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_socket_accept(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer; out AClient: TPlatformSocket): Int32;
begin
  AClient.Value := accept(ASocket.Value, AAddr, AAddrLen);
  if AClient.Value < 0 then
    Result := platform_get_errno
  else
    Result := 0;
end;

function platform_socket_connect(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Int32): Int32;
begin
  if connect(ASocket.Value, AAddr, socklen_t(AAddrLen)) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_socket_send(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32; out ASent: Int32): Int32;
var
  LResult: ssize_t;
begin
  LResult := send(ASocket.Value, ABuf, size_t(ALen), AFlags);
  if LResult < 0 then
  begin
    ASent := 0;
    Result := platform_get_errno;
  end
  else
  begin
    ASent := Int32(LResult);
    Result := 0;
  end;
end;

function platform_socket_recv(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32; out ARecvd: Int32): Int32;
var
  LResult: ssize_t;
begin
  LResult := recv(ASocket.Value, ABuf, size_t(ALen), AFlags);
  if LResult < 0 then
  begin
    ARecvd := 0;
    Result := platform_get_errno;
  end
  else
  begin
    ARecvd := Int32(LResult);
    Result := 0;
  end;
end;

function platform_socket_shutdown(const ASocket: TPlatformSocket;
  AHow: Int32): Int32;
begin
  if nextpas.core.platform.posix.ffi.shutdown(ASocket.Value, AHow) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_socket_setsockopt(const ASocket: TPlatformSocket;
  ALevel, AOptName: Int32; AOptVal: Pointer; AOptLen: Int32): Int32;
begin
  if setsockopt(ASocket.Value, ALevel, AOptName, AOptVal, socklen_t(AOptLen)) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_socket_sendto(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32;
  AAddr: Pointer; AAddrLen: Int32; out ASent: Int32): Int32;
var
  LResult: ssize_t;
begin
  LResult := sendto(ASocket.Value, ABuf, size_t(ALen), AFlags, AAddr, socklen_t(AAddrLen));
  if LResult < 0 then
  begin
    ASent := 0;
    Result := platform_get_errno;
  end
  else
  begin
    ASent := Int32(LResult);
    Result := 0;
  end;
end;

function platform_socket_recvfrom(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32;
  AAddr: Pointer; AAddrLen: Pointer; out ARecvd: Int32): Int32;
var
  LResult: ssize_t;
begin
  LResult := recvfrom(ASocket.Value, ABuf, size_t(ALen), AFlags, AAddr, AAddrLen);
  if LResult < 0 then
  begin
    ARecvd := 0;
    Result := platform_get_errno;
  end
  else
  begin
    ARecvd := Int32(LResult);
    Result := 0;
  end;
end;

function platform_socket_getsockname(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer): Int32;
begin
  if getsockname(ASocket.Value, AAddr, AAddrLen) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_socket_getpeername(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer): Int32;
begin
  if getpeername(ASocket.Value, AAddr, AAddrLen) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_socket_resolve_ipv4(const AHost: PAnsiChar; out AAddr: UInt32): Int32;
var
  LHints: addrinfo;
  LRes: PAddrInfo;
  LSa: ^sockaddr_in;
begin
  AAddr := 0;
  FillChar(LHints, SizeOf(LHints), 0);
  LHints.ai_family := AF_INET;
  LHints.ai_socktype := SOCK_STREAM;
  LRes := nil;
  Result := getaddrinfo(AHost, nil, @LHints, @LRes);
  if (Result <> 0) or (LRes = nil) then
  begin
    if Result = 0 then Result := -1;
    Exit;
  end;
  LSa := Pointer(LRes^.ai_addr);
  AAddr := LSa^.sin_addr.s_addr;
  freeaddrinfo(LRes);
  Result := 0;
end;

function platform_socket_set_nonblocking(const ASocket: TPlatformSocket;
  const ANonBlock: Boolean): Int32;
var
  LFlags: PtrInt;
begin
  LFlags := fcntl(TPlatformFileDescriptor(ASocket.Value), F_GETFL, 0);
  if LFlags < 0 then Exit(platform_get_errno);
  if ANonBlock then
    LFlags := LFlags or O_NONBLOCK
  else
    LFlags := LFlags and (not O_NONBLOCK);
  if fcntl(TPlatformFileDescriptor(ASocket.Value), F_SETFL, LFlags) < 0 then
    Exit(platform_get_errno);
  Result := 0;
end;

function platform_socket_set_timeout(const ASocket: TPlatformSocket;
  const AOptName: Int32; const AMs: UInt32): Int32;
var
  LTv: timeval;
begin
  LTv.tv_sec := AMs div 1000;
  LTv.tv_usec := (AMs mod 1000) * 1000;
  Result := platform_socket_setsockopt(ASocket, PLATFORM_SOL_SOCKET, AOptName,
    @LTv, SizeOf(LTv));
end;

function platform_socket_error_would_block(const AError: Int32): Boolean;
begin
  Result := (AError = ESysEAGAIN) or (AError = ESysEWOULDBLOCK);
end;

function platform_socket_error_timed_out(const AError: Int32): Boolean;
begin
  Result := AError = ESysETIMEDOUT;
end;

{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;

function platform_socket_create(const ADomain, AType, AProtocol: Int32;
  out ASocket: TPlatformSocket): Int32;
begin
  ASocket.Value := PtrUInt(winsock_socket(ADomain, AType, AProtocol));
  if ASocket.Value = PtrUInt(-1) then
    Result := WSAGetLastError
  else
    Result := 0;
end;

function platform_socket_close(var ASocket: TPlatformSocket): Int32;
begin
  if ASocket.Value = PtrUInt(-1) then Exit(0);
  if closesocket(TSocket(ASocket.Value)) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
  ASocket.Value := PtrUInt(-1);
end;

function platform_socket_bind(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Int32): Int32;
begin
  if winsock_bind(TSocket(ASocket.Value), AAddr, AAddrLen) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_listen(const ASocket: TPlatformSocket;
  ABacklog: Int32): Int32;
begin
  if winsock_listen(TSocket(ASocket.Value), ABacklog) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_accept(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer; out AClient: TPlatformSocket): Int32;
var
  LS: TSocket;
begin
  LS := winsock_accept(TSocket(ASocket.Value), AAddr, AAddrLen);
  if LS = TSocket(-1) then
  begin
    AClient.Value := PtrUInt(-1);
    Result := WSAGetLastError;
  end
  else
  begin
    AClient.Value := PtrUInt(LS);
    Result := 0;
  end;
end;

function platform_socket_connect(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Int32): Int32;
begin
  if winsock_connect(TSocket(ASocket.Value), AAddr, AAddrLen) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_send(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32; out ASent: Int32): Int32;
var
  LResult: LongInt;
begin
  LResult := winsock_send(TSocket(ASocket.Value), ABuf, ALen, AFlags);
  if LResult < 0 then
  begin
    ASent := 0;
    Result := WSAGetLastError;
  end
  else
  begin
    ASent := LResult;
    Result := 0;
  end;
end;

function platform_socket_recv(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32; out ARecvd: Int32): Int32;
var
  LResult: LongInt;
begin
  LResult := winsock_recv(TSocket(ASocket.Value), ABuf, ALen, AFlags);
  if LResult < 0 then
  begin
    ARecvd := 0;
    Result := WSAGetLastError;
  end
  else
  begin
    ARecvd := LResult;
    Result := 0;
  end;
end;

function platform_socket_shutdown(const ASocket: TPlatformSocket;
  AHow: Int32): Int32;
begin
  if winsock_shutdown(TSocket(ASocket.Value), AHow) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_setsockopt(const ASocket: TPlatformSocket;
  ALevel, AOptName: Int32; AOptVal: Pointer; AOptLen: Int32): Int32;
begin
  if winsock_setsockopt(TSocket(ASocket.Value), ALevel, AOptName, AOptVal, AOptLen) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_getsockname(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer): Int32;
begin
  if winsock_getsockname(TSocket(ASocket.Value), AAddr, AAddrLen) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_getpeername(const ASocket: TPlatformSocket;
  AAddr: Pointer; AAddrLen: Pointer): Int32;
begin
  if winsock_getpeername(TSocket(ASocket.Value), AAddr, AAddrLen) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_sendto(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32;
  AAddr: Pointer; AAddrLen: Int32; out ASent: Int32): Int32;
var
  LResult: LongInt;
begin
  LResult := winsock_sendto(TSocket(ASocket.Value), ABuf, ALen, AFlags, AAddr, AAddrLen);
  if LResult < 0 then
  begin
    ASent := 0;
    Result := WSAGetLastError;
  end
  else
  begin
    ASent := LResult;
    Result := 0;
  end;
end;

function platform_socket_recvfrom(const ASocket: TPlatformSocket;
  ABuf: Pointer; ALen: Int32; AFlags: Int32;
  AAddr: Pointer; AAddrLen: Pointer; out ARecvd: Int32): Int32;
var
  LResult: LongInt;
begin
  LResult := winsock_recvfrom(TSocket(ASocket.Value), ABuf, ALen, AFlags, AAddr, AAddrLen);
  if LResult < 0 then
  begin
    ARecvd := 0;
    Result := WSAGetLastError;
  end
  else
  begin
    ARecvd := LResult;
    Result := 0;
  end;
end;

function platform_socket_resolve_ipv4(const AHost: PAnsiChar; out AAddr: UInt32): Int32;
type
  TWinAddrInfo = record
    ai_flags: Int32;
    ai_family: Int32;
    ai_socktype: Int32;
    ai_protocol: Int32;
    ai_addrlen: PtrUInt;
    ai_canonname: PAnsiChar;
    ai_addr: Pointer;
    ai_next: Pointer;
  end;
  PWinAddrInfo = ^TWinAddrInfo;
  TWinSockAddrIn = packed record
    sin_family: Word;
    sin_port: Word;
    sin_addr: UInt32;
    sin_zero: array[0..7] of Byte;
  end;
  PWinSockAddrIn = ^TWinSockAddrIn;
var
  LHints: TWinAddrInfo;
  LRes: PWinAddrInfo;
begin
  AAddr := 0;
  FillChar(LHints, SizeOf(LHints), 0);
  LHints.ai_family := 2; { AF_INET }
  LHints.ai_socktype := 1; { SOCK_STREAM }
  LRes := nil;
  Result := winsock_getaddrinfo(AHost, nil, @LHints, @LRes);
  if (Result <> 0) or (LRes = nil) then
  begin
    if Result = 0 then Result := -1;
    Exit;
  end;
  if LRes^.ai_addr <> nil then
    AAddr := PWinSockAddrIn(LRes^.ai_addr)^.sin_addr;
  winsock_freeaddrinfo(LRes);
  Result := 0;
end;

function platform_socket_set_nonblocking(const ASocket: TPlatformSocket;
  const ANonBlock: Boolean): Int32;
var
  LMode: DWORD;
begin
  if ANonBlock then
    LMode := 1
  else
    LMode := 0;
  if ioctlsocket(TSocket(ASocket.Value), FIONBIO, @LMode) = 0 then
    Result := 0
  else
    Result := WSAGetLastError;
end;

function platform_socket_set_timeout(const ASocket: TPlatformSocket;
  const AOptName: Int32; const AMs: UInt32): Int32;
var
  LMs: Int32;
begin
  LMs := Int32(AMs);
  Result := platform_socket_setsockopt(ASocket, PLATFORM_SOL_SOCKET, AOptName,
    @LMs, SizeOf(LMs));
end;

function platform_socket_error_would_block(const AError: Int32): Boolean;
begin
  Result := AError = WSAEWOULDBLOCK;
end;

function platform_socket_error_timed_out(const AError: Int32): Boolean;
begin
  Result := AError = WSAETIMEDOUT;
end;

var
  GWsaData: array[0..511] of Byte;

initialization
  WSAStartup($0202, @GWsaData);

finalization
  WSACleanup;

{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_socket_create(const ADomain, AType, AProtocol: Int32; out ASocket: TPlatformSocket): Int32; begin Result := -1; end;
function platform_socket_close(var ASocket: TPlatformSocket): Int32; begin Result := -1; end;
function platform_socket_bind(const ASocket: TPlatformSocket; AAddr: Pointer; AAddrLen: Int32): Int32; begin Result := -1; end;
function platform_socket_listen(const ASocket: TPlatformSocket; ABacklog: Int32): Int32; begin Result := -1; end;
function platform_socket_accept(const ASocket: TPlatformSocket; AAddr: Pointer; AAddrLen: Pointer; out AClient: TPlatformSocket): Int32; begin Result := -1; end;
function platform_socket_connect(const ASocket: TPlatformSocket; AAddr: Pointer; AAddrLen: Int32): Int32; begin Result := -1; end;
function platform_socket_send(const ASocket: TPlatformSocket; ABuf: Pointer; ALen: Int32; AFlags: Int32; out ASent: Int32): Int32; begin ASent := 0; Result := -1; end;
function platform_socket_recv(const ASocket: TPlatformSocket; ABuf: Pointer; ALen: Int32; AFlags: Int32; out ARecvd: Int32): Int32; begin ARecvd := 0; Result := -1; end;
function platform_socket_shutdown(const ASocket: TPlatformSocket; AHow: Int32): Int32; begin Result := -1; end;
function platform_socket_setsockopt(const ASocket: TPlatformSocket; ALevel, AOptName: Int32; AOptVal: Pointer; AOptLen: Int32): Int32; begin Result := -1; end;
function platform_socket_getsockname(const ASocket: TPlatformSocket; AAddr: Pointer; AAddrLen: Pointer): Int32; begin Result := -1; end;
function platform_socket_getpeername(const ASocket: TPlatformSocket; AAddr: Pointer; AAddrLen: Pointer): Int32; begin Result := -1; end;
function platform_socket_resolve_ipv4(const AHost: PAnsiChar; out AAddr: UInt32): Int32; begin AAddr := 0; Result := -1; end;
function platform_socket_set_nonblocking(const ASocket: TPlatformSocket; const ANonBlock: Boolean): Int32; begin Result := -1; end;
function platform_socket_set_timeout(const ASocket: TPlatformSocket; const AOptName: Int32; const AMs: UInt32): Int32; begin Result := -1; end;
function platform_socket_error_would_block(const AError: Int32): Boolean; begin Result := False; end;
function platform_socket_error_timed_out(const AError: Int32): Boolean; begin Result := False; end;
{$ENDIF}

end.
