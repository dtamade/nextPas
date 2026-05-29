unit nextpas.core.platform.socket;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.base;

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

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.ffi;

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

{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
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

var
  GWsaData: array[0..99] of Byte;

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
{$ENDIF}

end.
