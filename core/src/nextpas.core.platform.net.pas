unit nextpas.core.platform.net;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.net.base;

function platform_socket_create(AFamily: TPlatformAddressFamily;
  AType: TPlatformSocketType; AProto: TPlatformProtocol;
  out ASock: TPlatformSocket): Int32;
function platform_socket_close(var ASock: TPlatformSocket): Int32;
function platform_socket_bind(const ASock: TPlatformSocket;
  const AAddr: TPlatformSockAddr): Int32;
function platform_socket_listen(const ASock: TPlatformSocket; ABacklog: Int32): Int32;
function platform_socket_accept(const ASock: TPlatformSocket;
  out AClient: TPlatformSocket; out AAddr: TPlatformSockAddr): Int32;
function platform_socket_connect(const ASock: TPlatformSocket;
  const AAddr: TPlatformSockAddr): Int32;
function platform_socket_send(const ASock: TPlatformSocket;
  ABuf: Pointer; ALen: PtrUInt; out ASent: PtrUInt): Int32;
function platform_socket_recv(const ASock: TPlatformSocket;
  ABuf: Pointer; ALen: PtrUInt; out ARecvd: PtrUInt): Int32;
function platform_socket_shutdown(const ASock: TPlatformSocket;
  AHow: TPlatformShutdownHow): Int32;
function platform_socket_setopt_int(const ASock: TPlatformSocket;
  ALevel: Int32; AOptName: Int32; AValue: Int32): Int32;
function platform_socket_fd(const ASock: TPlatformSocket): Int32;

function platform_sockaddr_ipv4(APort: UInt16; AAddr: UInt32;
  out AResult: TPlatformSockAddr): Int32;
function platform_sockaddr_loopback4(APort: UInt16;
  out AResult: TPlatformSockAddr): Int32;

function platform_htons(AHost: UInt16): UInt16; inline;
function platform_htonl(AHost: UInt32): UInt32; inline;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi
{$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  , nextpas.core.platform.darwin.base
{$ENDIF}
{$IFDEF NEXTPAS_FREEBSD}
  , nextpas.core.platform.freebsd.base
{$ENDIF}
  ;
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;
{$ENDIF}

function platform_htons(AHost: UInt16): UInt16; inline;
begin
  Result := ((AHost and $FF) shl 8) or ((AHost shr 8) and $FF);
end;

function platform_htonl(AHost: UInt32): UInt32; inline;
begin
  Result := ((AHost and $FF) shl 24) or
            ((AHost and $FF00) shl 8) or
            ((AHost shr 8) and $FF00) or
            ((AHost shr 24) and $FF);
end;

{$IFDEF NEXTPAS_UNIX}
function MapFamily(AF: TPlatformAddressFamily): Int32;
begin
  case AF of
    afInet4: Result := AF_INET;
    afInet6: Result := AF_INET6;
    afUnix:  Result := AF_UNIX;
  end;
end;

function MapSockType(ST: TPlatformSocketType): Int32;
begin
  case ST of
    stStream: Result := SOCK_STREAM;
    stDgram:  Result := SOCK_DGRAM;
  end;
end;

function MapProtocol(P: TPlatformProtocol): Int32;
begin
  case P of
    spTCP:     Result := IPPROTO_TCP;
    spUDP:     Result := IPPROTO_UDP;
    spDefault: Result := 0;
  end;
end;

function platform_socket_create(AFamily: TPlatformAddressFamily;
  AType: TPlatformSocketType; AProto: TPlatformProtocol;
  out ASock: TPlatformSocket): Int32;
begin
  ASock.Value := socket(MapFamily(AFamily), MapSockType(AType), MapProtocol(AProto));
  if ASock.Value < 0 then
    Result := -1
  else
    Result := 0;
end;

function platform_socket_close(var ASock: TPlatformSocket): Int32;
begin
  if ASock.Value < 0 then
    Exit(-1);
  if close(ASock.Value) = 0 then
    Result := 0
  else
    Result := -1;
  ASock.Value := -1;
end;

function platform_socket_bind(const ASock: TPlatformSocket;
  const AAddr: TPlatformSockAddr): Int32;
begin
  if bind(ASock.Value, @AAddr.Storage, socklen_t(AAddr.Len)) = 0 then
    Result := 0
  else
    Result := -1;
end;

function platform_socket_listen(const ASock: TPlatformSocket; ABacklog: Int32): Int32;
begin
  if listen(ASock.Value, ABacklog) = 0 then
    Result := 0
  else
    Result := -1;
end;

function platform_socket_accept(const ASock: TPlatformSocket;
  out AClient: TPlatformSocket; out AAddr: TPlatformSockAddr): Int32;
var
  LLen: socklen_t;
begin
  FillChar(AAddr, SizeOf(AAddr), 0);
  LLen := SizeOf(AAddr.Storage);
  AClient.Value := accept(ASock.Value, @AAddr.Storage, @LLen);
  if AClient.Value < 0 then
    Result := -1
  else
  begin
    AAddr.Len := Int32(LLen);
    Result := 0;
  end;
end;

function platform_socket_connect(const ASock: TPlatformSocket;
  const AAddr: TPlatformSockAddr): Int32;
begin
  if connect(ASock.Value, @AAddr.Storage, socklen_t(AAddr.Len)) = 0 then
    Result := 0
  else
    Result := -1;
end;

function platform_socket_send(const ASock: TPlatformSocket;
  ABuf: Pointer; ALen: PtrUInt; out ASent: PtrUInt): Int32;
var
  LResult: ssize_t;
begin
  LResult := send(ASock.Value, ABuf, ALen, 0);
  if LResult < 0 then
  begin
    ASent := 0;
    Result := -1;
  end
  else
  begin
    ASent := PtrUInt(LResult);
    Result := 0;
  end;
end;

function platform_socket_recv(const ASock: TPlatformSocket;
  ABuf: Pointer; ALen: PtrUInt; out ARecvd: PtrUInt): Int32;
var
  LResult: ssize_t;
begin
  LResult := recv(ASock.Value, ABuf, ALen, 0);
  if LResult < 0 then
  begin
    ARecvd := 0;
    Result := -1;
  end
  else
  begin
    ARecvd := PtrUInt(LResult);
    Result := 0;
  end;
end;

function platform_socket_shutdown(const ASock: TPlatformSocket;
  AHow: TPlatformShutdownHow): Int32;
var
  LHow: Int32;
begin
  case AHow of
    shRead:  LHow := SHUT_RD;
    shWrite: LHow := SHUT_WR;
    shBoth:  LHow := SHUT_RDWR;
  end;
  if shutdown(ASock.Value, LHow) = 0 then
    Result := 0
  else
    Result := -1;
end;

function platform_socket_setopt_int(const ASock: TPlatformSocket;
  ALevel: Int32; AOptName: Int32; AValue: Int32): Int32;
begin
  if setsockopt(ASock.Value, ALevel, AOptName, @AValue, SizeOf(AValue)) = 0 then
    Result := 0
  else
    Result := -1;
end;

function platform_socket_fd(const ASock: TPlatformSocket): Int32;
begin
  Result := ASock.Value;
end;

function platform_sockaddr_ipv4(APort: UInt16; AAddr: UInt32;
  out AResult: TPlatformSockAddr): Int32;
var
  LAddr: ^sockaddr_in;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  LAddr := @AResult.Storage;
  LAddr^.sin_family := AF_INET;
  LAddr^.sin_port := platform_htons(APort);
  LAddr^.sin_addr.s_addr := AAddr;
  AResult.Len := SizeOf(sockaddr_in);
  Result := 0;
end;

function platform_sockaddr_loopback4(APort: UInt16;
  out AResult: TPlatformSockAddr): Int32;
var
  LAddr: ^sockaddr_in;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  LAddr := @AResult.Storage;
  LAddr^.sin_family := AF_INET;
  LAddr^.sin_port := platform_htons(APort);
  LAddr^.sin_addr.s_addr := platform_htonl($7F000001); // 127.0.0.1
  AResult.Len := SizeOf(sockaddr_in);
  Result := 0;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
function platform_socket_create(AFamily: TPlatformAddressFamily; AType: TPlatformSocketType; AProto: TPlatformProtocol; out ASock: TPlatformSocket): Int32;
begin ASock.Value := TSocket(not PtrUInt(0)); Result := -1; end;
function platform_socket_close(var ASock: TPlatformSocket): Int32;
begin Result := -1; end;
function platform_socket_bind(const ASock: TPlatformSocket; const AAddr: TPlatformSockAddr): Int32;
begin Result := -1; end;
function platform_socket_listen(const ASock: TPlatformSocket; ABacklog: Int32): Int32;
begin Result := -1; end;
function platform_socket_accept(const ASock: TPlatformSocket; out AClient: TPlatformSocket; out AAddr: TPlatformSockAddr): Int32;
begin FillChar(AClient, SizeOf(AClient), 0); FillChar(AAddr, SizeOf(AAddr), 0); Result := -1; end;
function platform_socket_connect(const ASock: TPlatformSocket; const AAddr: TPlatformSockAddr): Int32;
begin Result := -1; end;
function platform_socket_send(const ASock: TPlatformSocket; ABuf: Pointer; ALen: PtrUInt; out ASent: PtrUInt): Int32;
begin ASent := 0; Result := -1; end;
function platform_socket_recv(const ASock: TPlatformSocket; ABuf: Pointer; ALen: PtrUInt; out ARecvd: PtrUInt): Int32;
begin ARecvd := 0; Result := -1; end;
function platform_socket_shutdown(const ASock: TPlatformSocket; AHow: TPlatformShutdownHow): Int32;
begin Result := -1; end;
function platform_socket_setopt_int(const ASock: TPlatformSocket; ALevel: Int32; AOptName: Int32; AValue: Int32): Int32;
begin Result := -1; end;
function platform_socket_fd(const ASock: TPlatformSocket): Int32;
begin Result := -1; end;
function platform_sockaddr_ipv4(APort: UInt16; AAddr: UInt32; out AResult: TPlatformSockAddr): Int32;
begin FillChar(AResult, SizeOf(AResult), 0); Result := -1; end;
function platform_sockaddr_loopback4(APort: UInt16; out AResult: TPlatformSockAddr): Int32;
begin FillChar(AResult, SizeOf(AResult), 0); Result := -1; end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_socket_create(AFamily: TPlatformAddressFamily; AType: TPlatformSocketType; AProto: TPlatformProtocol; out ASock: TPlatformSocket): Int32;
begin FillChar(ASock, SizeOf(ASock), 0); Result := -1; end;
function platform_socket_close(var ASock: TPlatformSocket): Int32;
begin Result := -1; end;
function platform_socket_bind(const ASock: TPlatformSocket; const AAddr: TPlatformSockAddr): Int32;
begin Result := -1; end;
function platform_socket_listen(const ASock: TPlatformSocket; ABacklog: Int32): Int32;
begin Result := -1; end;
function platform_socket_accept(const ASock: TPlatformSocket; out AClient: TPlatformSocket; out AAddr: TPlatformSockAddr): Int32;
begin FillChar(AClient, SizeOf(AClient), 0); FillChar(AAddr, SizeOf(AAddr), 0); Result := -1; end;
function platform_socket_connect(const ASock: TPlatformSocket; const AAddr: TPlatformSockAddr): Int32;
begin Result := -1; end;
function platform_socket_send(const ASock: TPlatformSocket; ABuf: Pointer; ALen: PtrUInt; out ASent: PtrUInt): Int32;
begin ASent := 0; Result := -1; end;
function platform_socket_recv(const ASock: TPlatformSocket; ABuf: Pointer; ALen: PtrUInt; out ARecvd: PtrUInt): Int32;
begin ARecvd := 0; Result := -1; end;
function platform_socket_shutdown(const ASock: TPlatformSocket; AHow: TPlatformShutdownHow): Int32;
begin Result := -1; end;
function platform_socket_setopt_int(const ASock: TPlatformSocket; ALevel: Int32; AOptName: Int32; AValue: Int32): Int32;
begin Result := -1; end;
function platform_socket_fd(const ASock: TPlatformSocket): Int32;
begin Result := -1; end;
function platform_sockaddr_ipv4(APort: UInt16; AAddr: UInt32; out AResult: TPlatformSockAddr): Int32;
begin FillChar(AResult, SizeOf(AResult), 0); Result := -1; end;
function platform_sockaddr_loopback4(APort: UInt16; out AResult: TPlatformSockAddr): Int32;
begin FillChar(AResult, SizeOf(AResult), 0); Result := -1; end;
{$ENDIF}

end.
