unit nextpas.core.net.tcp;
{**
 * @desc TCP 实现：TTcpStream（带 deadline 超时）+ TTcpListener。
 *       SO_REUSEADDR 默认启用，支持 SetNoDelay/SetKeepAlive。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.net.intf;

function NetTcpListen(const AAddr: string; const APort: UInt16): ITcpListener;
function NetTcpConnect(const AAddr: string; const APort: UInt16): ITcpStream;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.io.intf,
  nextpas.core.errors,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.socket,
  nextpas.core.net.resolve;

type
  TTcpStream = class(TInterfacedObject, IReader, IWriter, IReadWriteCloser, ITcpStream,
    ITcpSocketRuntime,
    ITcpStreamRuntime)
  private
    FSocket: TPlatformSocket;
    FLocal: TNetAddress;
    FRemote: TNetAddress;
    FClosed: Boolean;
    FReadDeadline: TDeadline;
    FWriteDeadline: TDeadline;
    FLastReadTimeoutMs: UInt32;
    FLastWriteTimeoutMs: UInt32;
    procedure EnsureOpen(const AOperation: string);
    procedure ApplyReadTimeout;
    procedure ApplyWriteTimeout;
  public
    constructor Create(const ASocket: TPlatformSocket;
      const ALocal, ARemote: TNetAddress);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
    function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
    function TryRead(var ABuf; const ACount: SizeUInt;
      out ARead: SizeUInt): TTcpStreamIOResult;
    function TryWrite(const ABuf; const ACount: SizeUInt;
      out AWritten: SizeUInt): TTcpStreamIOResult;
  end;

  TTcpListener = class(TInterfacedObject, ITcpListener, ITcpSocketRuntime,
    ITcpListenerRuntime)
  private
    FSocket: TPlatformSocket;
    FLocal: TNetAddress;
    FClosed: Boolean;
    procedure EnsureOpen(const AOperation: string);
  public
    constructor Create(const ASocket: TPlatformSocket; const ALocal: TNetAddress);
    destructor Destroy; override;
    function Accept: ITcpStream;
    function LocalAddr: TNetAddress;
    procedure Close;
    function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
    function TryAccept(out AConn: ITcpStream): TTcpAcceptResult;
  end;

function Htons(AVal: UInt16): UInt16; inline;
begin
  Result := platform_htons(AVal);
end;

function Ntohs(AVal: UInt16): UInt16; inline;
begin
  Result := platform_htons(AVal);
end;

procedure FillSockAddr(const AAddr: TNetAddress; out ASa: sockaddr_in; out ALen: Int32);
begin
  if platform_sockaddr_from_ipv4(AAddr.IP, AAddr.Port, ASa, ALen) <> 0 then
  begin
    FillChar(ASa, SizeOf(ASa), 0);
    ALen := 0;
  end;
end;

function AddrFromSockAddr(const ASa: sockaddr_in): TNetAddress;
begin
  platform_sockaddr_to_ipv4(ASa, Result.IP, Result.Port);
  Result.IsIPv6 := False;
end;

{ TTcpStream }

constructor TTcpStream.Create(const ASocket: TPlatformSocket;
  const ALocal, ARemote: TNetAddress);
begin
  inherited Create;
  FSocket := ASocket;
  FLocal := ALocal;
  FRemote := ARemote;
  FClosed := False;
  FReadDeadline := TDeadline.Infinite;
  FWriteDeadline := TDeadline.Infinite;
  FLastReadTimeoutMs := 0;
  FLastWriteTimeoutMs := 0;
end;

destructor TTcpStream.Destroy;
begin
  if not FClosed then
    platform_socket_close(FSocket);
  inherited;
end;

procedure TTcpStream.EnsureOpen(const AOperation: string);
begin
  if FClosed then
    raise ENetworkError.Create('tcp stream ' + AOperation + ' after close');
end;

function TTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRecvd: Int32;
  LResult: Int32;
begin
  EnsureOpen('read');
  if ACount = 0 then Exit(0);
  ApplyReadTimeout;
  LResult := platform_socket_recv(FSocket, @ABuf, Int32(ACount), 0, LRecvd);
  if LResult <> 0 then
  begin
    if (not FReadDeadline.IsInfinite) and
       platform_socket_error_would_block(LResult) then
      raise ETimeoutError.Create('read deadline exceeded');
    raise ENetworkError.Create('tcp read failed (' + IntToStr(LResult) + ')');
  end;
  Result := SizeUInt(LRecvd);
end;

function TTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LSent: Int32;
  LResult: Int32;
  LPtr: PByte;
  LRemaining: SizeUInt;
begin
  EnsureOpen('write');
  if ACount = 0 then Exit(0);
  ApplyWriteTimeout;
  LPtr := @ABuf;
  LRemaining := ACount;
  Result := 0;
  while LRemaining > 0 do
  begin
    LResult := platform_socket_send(FSocket, LPtr, Int32(LRemaining), 0, LSent);
    if LResult <> 0 then
    begin
      if (not FWriteDeadline.IsInfinite) and
         platform_socket_error_would_block(LResult) then
        raise ETimeoutError.Create('write deadline exceeded');
      raise ENetworkError.Create('tcp write failed (' + IntToStr(LResult) + ')');
    end;
    if LSent = 0 then
      raise ENetworkError.Create('tcp write failed (zero progress)');
    Inc(LPtr, LSent);
    Dec(LRemaining, SizeUInt(LSent));
    Inc(Result, SizeUInt(LSent));
    if (LRemaining > 0) and (not FWriteDeadline.IsInfinite) then
      ApplyWriteTimeout;
  end;
end;

procedure TTcpStream.Close;
begin
  if not FClosed then
  begin
    FClosed := True;
    platform_socket_close(FSocket);
    FSocket := PLATFORM_INVALID_SOCKET;
  end;
end;

function TTcpStream.LocalAddr: TNetAddress;
begin
  Result := FLocal;
end;

function TTcpStream.RemoteAddr: TNetAddress;
begin
  Result := FRemote;
end;

procedure TTcpStream.Shutdown;
begin
  EnsureOpen('shutdown');
  platform_socket_shutdown(FSocket, PLATFORM_SHUT_WR);
end;

procedure TTcpStream.SetNoDelay(const AValue: Boolean);
var
  LVal: Int32;
begin
  EnsureOpen('set nodelay');
  if AValue then LVal := 1 else LVal := 0;
  platform_socket_setsockopt(FSocket, PLATFORM_IPPROTO_TCP, PLATFORM_TCP_NODELAY, @LVal, SizeOf(LVal));
end;

procedure TTcpStream.SetKeepAlive(const AValue: Boolean);
var
  LVal: Int32;
begin
  EnsureOpen('set keepalive');
  if AValue then LVal := 1 else LVal := 0;
  platform_socket_setsockopt(FSocket, PLATFORM_SOL_SOCKET, PLATFORM_SO_KEEPALIVE, @LVal, SizeOf(LVal));
end;

procedure TTcpStream.SetReadDeadline(const ADeadline: TDeadline);
begin
  FReadDeadline := ADeadline;
end;

procedure TTcpStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
  FWriteDeadline := ADeadline;
end;

function TTcpStream.NativeSocketHandle: PtrUInt;
begin
  EnsureOpen('native handle');
  Result := PtrUInt(FSocket.Value);
end;

procedure TTcpStream.SetBlocking(const ABlocking: Boolean);
begin
  EnsureOpen('set blocking');
  if platform_socket_set_nonblocking(FSocket, not ABlocking) <> 0 then
    raise ENetworkError.Create('tcp set blocking failed');
end;

function TTcpStream.TryRead(var ABuf; const ACount: SizeUInt;
  out ARead: SizeUInt): TTcpStreamIOResult;
var
  LRecvd: Int32;
  LResult: Int32;
begin
  ARead := 0;
  if FClosed then
    Exit(tsiorClosed);
  if ACount = 0 then
    Exit(tsiorOk);
  if FReadDeadline.IsExpired then
    Exit(tsiorTimeout);

  LResult := platform_socket_recv(FSocket, @ABuf, Int32(ACount), 0, LRecvd);
  if LResult = 0 then
  begin
    ARead := SizeUInt(LRecvd);
    if LRecvd = 0 then
      Exit(tsiorClosed);
    Exit(tsiorOk);
  end;
  if platform_socket_error_would_block(LResult) then
    Exit(tsiorWouldBlock);
  raise ENetworkError.Create('tcp read failed (' + IntToStr(LResult) + ')');
end;

function TTcpStream.TryWrite(const ABuf; const ACount: SizeUInt;
  out AWritten: SizeUInt): TTcpStreamIOResult;
var
  LSent: Int32;
  LResult: Int32;
begin
  AWritten := 0;
  if FClosed then
    Exit(tsiorClosed);
  if ACount = 0 then
    Exit(tsiorOk);
  if FWriteDeadline.IsExpired then
    Exit(tsiorTimeout);

  LResult := platform_socket_send(FSocket, @ABuf, Int32(ACount), 0, LSent);
  if LResult = 0 then
  begin
    AWritten := SizeUInt(LSent);
    if LSent = 0 then
      Exit(tsiorClosed);
    Exit(tsiorOk);
  end;
  if platform_socket_error_would_block(LResult) then
    Exit(tsiorWouldBlock);
  raise ENetworkError.Create('tcp write failed (' + IntToStr(LResult) + ')');
end;

procedure TTcpStream.ApplyReadTimeout;
var
  LMs: UInt32;
  LRemaining: TDuration;
begin
  if FReadDeadline.IsInfinite then
  begin
    if FLastReadTimeoutMs <> 0 then
    begin
      platform_socket_set_timeout(FSocket, PLATFORM_SO_RCVTIMEO, 0);
      FLastReadTimeoutMs := 0;
    end;
    Exit;
  end;
  if FReadDeadline.IsExpired then
    raise ETimeoutError.Create('read deadline exceeded');
  LRemaining := FReadDeadline.Remaining;
  LMs := UInt32(LRemaining.AsMilliseconds);
  if LMs = 0 then LMs := 1;
  if LMs <> FLastReadTimeoutMs then
  begin
    platform_socket_set_timeout(FSocket, PLATFORM_SO_RCVTIMEO, LMs);
    FLastReadTimeoutMs := LMs;
  end;
end;

procedure TTcpStream.ApplyWriteTimeout;
var
  LMs: UInt32;
  LRemaining: TDuration;
begin
  if FWriteDeadline.IsInfinite then
  begin
    if FLastWriteTimeoutMs <> 0 then
    begin
      platform_socket_set_timeout(FSocket, PLATFORM_SO_SNDTIMEO, 0);
      FLastWriteTimeoutMs := 0;
    end;
    Exit;
  end;
  if FWriteDeadline.IsExpired then
    raise ETimeoutError.Create('write deadline exceeded');
  LRemaining := FWriteDeadline.Remaining;
  LMs := UInt32(LRemaining.AsMilliseconds);
  if LMs = 0 then LMs := 1;
  if LMs <> FLastWriteTimeoutMs then
  begin
    platform_socket_set_timeout(FSocket, PLATFORM_SO_SNDTIMEO, LMs);
    FLastWriteTimeoutMs := LMs;
  end;
end;

{ TTcpListener }

constructor TTcpListener.Create(const ASocket: TPlatformSocket; const ALocal: TNetAddress);
begin
  inherited Create;
  FSocket := ASocket;
  FLocal := ALocal;
  FClosed := False;
end;

destructor TTcpListener.Destroy;
begin
  if not FClosed then
    platform_socket_close(FSocket);
  inherited;
end;

procedure TTcpListener.EnsureOpen(const AOperation: string);
begin
  if FClosed then
    raise ENetworkError.Create('tcp listener ' + AOperation + ' after close');
end;

function TTcpListener.Accept: ITcpStream;
var
  LClient: TPlatformSocket;
  LAddr, LLocalAddr: sockaddr_in;
  LAddrLen: socklen_t;
  LResult: Int32;
  LLocal: TNetAddress;
begin
  EnsureOpen('accept');
  LAddrLen := SizeOf(LAddr);
  LResult := platform_socket_accept(FSocket, @LAddr, @LAddrLen, LClient);
  if LResult <> 0 then
    raise ENetworkError.Create('tcp accept failed (' + IntToStr(LResult) + ')');
  LAddrLen := SizeOf(LLocalAddr);
  if platform_socket_getsockname(LClient, @LLocalAddr, @LAddrLen) = 0 then
    LLocal := AddrFromSockAddr(LLocalAddr)
  else
    LLocal := FLocal;
  Result := TTcpStream.Create(LClient, LLocal, AddrFromSockAddr(LAddr));
end;

function TTcpListener.LocalAddr: TNetAddress;
begin
  Result := FLocal;
end;

procedure TTcpListener.Close;
begin
  if not FClosed then
  begin
    FClosed := True;
    platform_socket_close(FSocket);
    FSocket := PLATFORM_INVALID_SOCKET;
  end;
end;

function TTcpListener.NativeSocketHandle: PtrUInt;
begin
  EnsureOpen('native handle');
  Result := PtrUInt(FSocket.Value);
end;

procedure TTcpListener.SetBlocking(const ABlocking: Boolean);
begin
  EnsureOpen('set blocking');
  if platform_socket_set_nonblocking(FSocket, not ABlocking) <> 0 then
    raise ENetworkError.Create('tcp listener set blocking failed');
end;

function TTcpListener.TryAccept(out AConn: ITcpStream): TTcpAcceptResult;
var
  LClient: TPlatformSocket;
  LAddr, LLocalAddr: sockaddr_in;
  LAddrLen: socklen_t;
  LResult: Int32;
  LLocal: TNetAddress;
begin
  AConn := nil;
  EnsureOpen('try accept');
  LAddrLen := SizeOf(LAddr);
  LResult := platform_socket_accept(FSocket, @LAddr, @LAddrLen, LClient);
  if LResult = 0 then
  begin
    LAddrLen := SizeOf(LLocalAddr);
    if platform_socket_getsockname(LClient, @LLocalAddr, @LAddrLen) = 0 then
      LLocal := AddrFromSockAddr(LLocalAddr)
    else
      LLocal := FLocal;
    AConn := TTcpStream.Create(LClient, LLocal, AddrFromSockAddr(LAddr));
    Exit(tarAccepted);
  end;
  if platform_socket_error_would_block(LResult) then
    Exit(tarWouldBlock);
  raise ENetworkError.Create('tcp accept failed (' + IntToStr(LResult) + ')');
end;

{ Factory functions }

function NetTcpListen(const AAddr: string; const APort: UInt16): ITcpListener;
var
  LSock: TPlatformSocket;
  LSa: sockaddr_in;
  LSaLen: Int32;
  LOne: Int32;
  LResult: Int32;
  LLocal: TNetAddress;
begin
  LLocal := TNetAddress.Create(AAddr, APort);
  LResult := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0, LSock);
  if LResult <> 0 then
    raise ENetworkError.Create('tcp listen: socket create failed (' + IntToStr(LResult) + ')');
  LOne := 1;
  platform_socket_setsockopt(LSock, PLATFORM_SOL_SOCKET, PLATFORM_SO_REUSEADDR, @LOne, SizeOf(LOne));
  FillSockAddr(LLocal, LSa, LSaLen);
  LResult := platform_socket_bind(LSock, @LSa, LSaLen);
  if LResult <> 0 then
  begin
    platform_socket_close(LSock);
    raise ENetworkError.Create('tcp listen: bind failed (' + IntToStr(LResult) + ')');
  end;
  LResult := platform_socket_listen(LSock, NET_DEFAULT_BACKLOG);
  if LResult <> 0 then
  begin
    platform_socket_close(LSock);
    raise ENetworkError.Create('tcp listen: listen failed (' + IntToStr(LResult) + ')');
  end;
  { Get actual bound address (important when port=0) }
  LSaLen := SizeOf(LSa);
  if platform_socket_getsockname(LSock, @LSa, @LSaLen) = 0 then
    LLocal := AddrFromSockAddr(LSa);
  Result := TTcpListener.Create(LSock, LLocal);
end;

function NetTcpConnect(const AAddr: string; const APort: UInt16): ITcpStream;
var
  LSock: TPlatformSocket;
  LSa: sockaddr_in;
  LSaLen: Int32;
  LResult: Int32;
  LRemote, LResolved: TNetAddress;
begin
  LResolved := NetResolve(AAddr);
  LRemote := TNetAddress.Create(LResolved.IP, APort);
  LResult := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0, LSock);
  if LResult <> 0 then
    raise ENetworkError.Create('tcp connect: socket create failed (' + IntToStr(LResult) + ')');
  FillSockAddr(LRemote, LSa, LSaLen);
  LResult := platform_socket_connect(LSock, @LSa, LSaLen);
  if LResult <> 0 then
  begin
    platform_socket_close(LSock);
    raise ENetworkError.Create('tcp connect failed (' + IntToStr(LResult) + ')');
  end;
  LSaLen := SizeOf(LSa);
  if platform_socket_getsockname(LSock, @LSa, @LSaLen) = 0 then
    Result := TTcpStream.Create(LSock, AddrFromSockAddr(LSa), LRemote)
  else
    Result := TTcpStream.Create(LSock, TNetAddress.Any(0), LRemote);
end;

end.
