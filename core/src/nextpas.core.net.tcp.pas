unit nextpas.core.net.tcp;
{**
 * @desc TCP 实现：TTcpStream（带 deadline 超时）+ TTcpListener。
 *       SO_REUSEADDR 默认启用，支持 SetNoDelay/SetKeepAlive。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.platform.socket;

function NetTcpListen(const AAddr: string; const APort: UInt16;
  const ABacklog: Int32 = NET_DEFAULT_BACKLOG): ITcpListener;
function NetTcpConnect(const AAddr: string; const APort: UInt16): ITcpStream;
{ AF_UNIX 域 socket 监听/连接（Unix 平台；Windows 抛 ENetworkError unsupported）。
  UnixListen 在 APath 上建监听 socket（bind 前 unlink 旧文件，bind 后 chmod 0600）。 }
function NetUnixListen(const APath: string): ITcpListener;
function NetUnixConnect(const APath: string): ITcpStream;
{ ATimeoutMs > 0 bounds the OS connect() wait (nonblocking connect + poll).
  ATimeoutMs <= 0 keeps unbounded blocking connect (legacy). }
function NetTcpConnect(const AAddr: string; const APort: UInt16;
  const ATimeoutMs: Int64): ITcpStream;
{ Adopt an already-connected socket into ITcpStream (for AsyncTcpDial). }
function NetTcpStreamFromConnectedSocket(const ASock: TPlatformSocket;
  const ARemote: TNetAddress): ITcpStream;
{ Build sockaddr for connect from TNetAddress (IPv4/IPv6). }
function NetBuildConnectSockAddr(const ARemote: TNetAddress;
  out ASa: TPlatformSockAddr): Boolean;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.io.intf,
  nextpas.core.errors,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.socket.base,
  nextpas.core.platform.error,
  nextpas.core.net.resolve,
  nextpas.core.fs;

type
  TTcpStream = class(TInterfacedObject, IReader, IWriter, IReadWriteCloser, ITcpStream,
    ITcpSocketRuntime,
    ITcpStreamRuntime,
    ITcpPeerProbe)
  private
    FSocket: TPlatformSocket;
    FLocal: TNetAddress;
    FRemote: TNetAddress;
    FClosed: Boolean;
    FReadDeadline: TDeadline;
    FWriteDeadline: TDeadline;
    FLastReadTimeoutMs: UInt32;
    FLastWriteTimeoutMs: UInt32;
    FCancelToken: INetCancelToken;
    FCancelWaitable: INetCancelWaitable;
    procedure EnsureOpen(const AOperation: string);
    procedure ThrowIfCanceled;
    procedure ApplyReadTimeout;
    procedure ApplyWriteTimeout;
    function CancelWakeHandle: PtrUInt;
    function DeadlineTimeoutMs(const ADeadline: TDeadline): Int32;
    { 0=timeout/retry, 1=ready, raises on cancel/deadline/error. }
    function WaitIO(const AEvents: Int32; const ADeadline: TDeadline;
      const AOpName: string): Int32;
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
    procedure SetCancelToken(const AToken: INetCancelToken);
    function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
    function TryRead(var ABuf; const ACount: SizeUInt;
      out ARead: SizeUInt): TTcpStreamIOResult;
    function TryWrite(const ABuf; const ACount: SizeUInt;
      out AWritten: SizeUInt): TTcpStreamIOResult;
    { ITcpPeerProbe：非破坏性对端存活探测（平台层 peek 封装）。 }
    function PeerAlive: Boolean;
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

procedure FillSockAddr(const AAddr: TNetAddress; out ASa: TPlatformSockAddr);
begin
  if nextpas.core.platform.socket.platform_sockaddr_ipv4(AAddr.Port,
    platform_ipv4_parse(AAddr.IP), ASa) <> 0 then
  begin
    FillChar(ASa, SizeOf(ASa), 0);
    ASa.Len := 0;
  end;
end;

function AddrFromSockAddr(const ASa: TPlatformSockAddr): TNetAddress;
var
  LIP: UInt32;
  LPort: UInt16;
begin
  { AF_UNIX（Linux/macOS/FreeBSD 均为 1，native-endian ushort）：
    无 IP/端口，返回空地址（调用方不得据此做网络路由）。 }
  if (ASa.Len >= 2) and (ASa.Storage[0] = 1) and (ASa.Storage[1] = 0) then
  begin
    Result.IP := '';
    Result.Port := 0;
    Result.IsIPv6 := False;
    Exit;
  end;
  platform_sockaddr_ipv4_extract(ASa, LIP, LPort);
  { Storage holds network-order s_addr; ipv4_to_string expects host-order word. }
  Result.IP := platform_ipv4_to_string(platform_ntohl(LIP));
  Result.Port := LPort;
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
  { 默认禁 Nagle：请求-回复型 TCP(SMTP/HTTP/测试回环) 下 Nagle 与 delayed ACK
    交互会产生 ~40ms 停顿(见 mailServer888 连接级压测实测);
    UDS 等非 TCP socket 上该 sockopt 不适用, 错误被忽略无害。 }
  SetNoDelay(True);
end;

destructor TTcpStream.Destroy;
begin
  if not FClosed then
    platform_socket_close(FSocket);
  inherited;
end;

const
  { Fallback slice when cancel token is probe-only (no WakeHandle). }
  NET_IO_CANCEL_SLICE_MS = 10;
  { poll 路径单次 send() 上限（256KB）：poll 拥有阻塞与 deadline，send 用
    MSG_DONTWAIT 非阻塞发送——若一次 send 整个剩余块（如 16MB 大帧），
    阻塞式 send 会在内核里等整个消息入队，SO_SNDTIMEO 已被 poll 路径清除、
    deadline 无法打断（G3 反哺：写超时对慢客户端失效）。 }
  NET_TCP_WRITE_CHUNK = 262144;

procedure TTcpStream.EnsureOpen(const AOperation: string);
begin
  if FClosed then
    raise ENetworkError.Create('tcp stream ' + AOperation + ' after close');
end;

procedure TTcpStream.ThrowIfCanceled;
begin
  if (FCancelToken <> nil) and FCancelToken.IsCanceled then
    raise ECancelledError.Create('tcp operation canceled');
end;

function TTcpStream.CancelWakeHandle: PtrUInt;
begin
  if FCancelWaitable <> nil then
    Result := FCancelWaitable.WakeHandle
  else
    Result := 0;
end;

function TTcpStream.DeadlineTimeoutMs(const ADeadline: TDeadline): Int32;
var
  LMs: Int64;
begin
  if ADeadline.IsInfinite then
    Exit(-1);
  if ADeadline.IsExpired then
    Exit(0);
  LMs := ADeadline.Remaining.AsMilliseconds;
  if LMs < 0 then
    LMs := 0;
  if LMs > High(Int32) then
    LMs := High(Int32);
  Result := Int32(LMs);
end;

function TTcpStream.WaitIO(const AEvents: Int32; const ADeadline: TDeadline;
  const AOpName: string): Int32;
var
  LWake: PtrUInt;
  LWakeSock: TPlatformSocket;
  LRc, LRevents: Int32;
  LTimeout: Int32;
begin
  ThrowIfCanceled;
  LWake := CancelWakeHandle;
  if LWake <> 0 then
  begin
    { Poll owns the wait; clear SO_*TIMEO so recv/send do not re-slice. }
    if FLastReadTimeoutMs <> 0 then
    begin
      platform_socket_set_timeout(FSocket, PLATFORM_SO_RCVTIMEO, 0);
      FLastReadTimeoutMs := 0;
    end;
    if FLastWriteTimeoutMs <> 0 then
    begin
      platform_socket_set_timeout(FSocket, PLATFORM_SO_SNDTIMEO, 0);
      FLastWriteTimeoutMs := 0;
    end;
    LTimeout := DeadlineTimeoutMs(ADeadline);
{$IFDEF NEXTPAS_WINDOWS}
    LWakeSock.Value := LWake;
{$ELSE}
    LWakeSock.Value := Int32(LWake);
{$ENDIF}
    LRc := platform_socket_poll_or_wake(FSocket, AEvents, LWakeSock, LTimeout, LRevents);
    if LRc < 0 then
      raise ENetworkError.Create('tcp ' + AOpName + ' poll failed (' +
        IntToStr(LRc) + ')');
    if LRc = 2 then
    begin
      if FCancelWaitable <> nil then
        FCancelWaitable.DrainWake;
      ThrowIfCanceled;
      Exit(0);
    end;
    if LRc = 0 then
    begin
      ThrowIfCanceled;
      if not ADeadline.IsInfinite then
      begin
        if ADeadline.IsExpired then
          raise ETimeoutError.Create(AOpName + ' deadline exceeded');
        Exit(0);
      end;
      Exit(0);
    end;
    Exit(1);
  end;

  if AEvents = PLATFORM_POLL_IN then
    ApplyReadTimeout
  else
    ApplyWriteTimeout;
  Result := 1;
end;

function TTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRecvd: Int32;
  LResult: Int32;
  LWait: Int32;
begin
  Result := 0;
  EnsureOpen('read');
  if ACount = 0 then Exit(0);
  while True do
  begin
    ThrowIfCanceled;
    LWait := WaitIO(PLATFORM_POLL_IN, FReadDeadline, 'read');
    if LWait = 0 then
    begin
      { Wake without cancel, or slice/deadline retry path. }
      if (CancelWakeHandle = 0) and (FCancelToken = nil) and
         (not FReadDeadline.IsInfinite) and FReadDeadline.IsExpired then
        raise ETimeoutError.Create('read deadline exceeded');
      Continue;
    end;
    LResult := platform_socket_recv(FSocket, @ABuf, Int32(ACount), 0, LRecvd);
    if LResult = 0 then
      Exit(SizeUInt(LRecvd));
    if platform_socket_error_would_block(LResult) or
       platform_socket_error_timed_out(LResult) then
    begin
      ThrowIfCanceled;
      if not FReadDeadline.IsInfinite then
      begin
        if FReadDeadline.IsExpired then
          raise ETimeoutError.Create('read deadline exceeded');
        { Short cancel slice or spurious readiness — retry. }
        if FCancelToken <> nil then
          Continue;
        raise ETimeoutError.Create('read deadline exceeded');
      end;
      if FCancelToken <> nil then
        Continue;
    end;
    raise ENetworkError.Create('tcp read failed (' + IntToStr(LResult) + ')');
  end;
end;

function TTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LSent: Int32;
  LResult: Int32;
  LPtr: PByte;
  LRemaining: SizeUInt;
  LWait: Int32;
  LFlags: Int32;
  LChunk: Int32;
begin
  EnsureOpen('write');
  if ACount = 0 then Exit(0);
  LPtr := @ABuf;
  LRemaining := ACount;
  Result := 0;
  { poll 路径（有 waitable cancel token）：send 用 MSG_DONTWAIT，阻塞与
    deadline 全部由 poll 拥有——否则单次巨型阻塞 send() 会在内核里停住
    越过写 deadline（G3：慢客户端填满发送缓冲时写超时不生效）。
    非 poll 路径维持阻塞 send + SO_SNDTIMEO 切片语义。
    Windows（无 MSG_DONTWAIT）维持旧行为：阻塞 send 受块大小切片约束。 }
  LFlags := PLATFORM_MSG_NOSIGNAL;
  if CancelWakeHandle <> 0 then
    LFlags := LFlags or PLATFORM_MSG_DONTWAIT;
  while LRemaining > 0 do
  begin
    ThrowIfCanceled;
    LWait := WaitIO(PLATFORM_POLL_OUT, FWriteDeadline, 'write');
    if LWait = 0 then
      Continue;
    LChunk := Int32(LRemaining);
    if LChunk > NET_TCP_WRITE_CHUNK then
      LChunk := NET_TCP_WRITE_CHUNK;
    LResult := platform_socket_send(FSocket, LPtr, LChunk, LFlags, LSent);
    if LResult <> 0 then
    begin
      if platform_socket_error_would_block(LResult) or
         platform_socket_error_timed_out(LResult) then
      begin
        ThrowIfCanceled;
        if not FWriteDeadline.IsInfinite then
        begin
          if FWriteDeadline.IsExpired then
            raise ETimeoutError.Create('write deadline exceeded');
          if FCancelToken <> nil then
            Continue;
          raise ETimeoutError.Create('write deadline exceeded');
        end;
        if FCancelToken <> nil then
          Continue;
      end;
      raise ENetworkError.Create('tcp write failed (' + IntToStr(LResult) + ')');
    end;
    if LSent = 0 then
      raise ENetworkError.Create('tcp write failed (zero progress)');
    Inc(LPtr, LSent);
    Dec(LRemaining, SizeUInt(LSent));
    Inc(Result, SizeUInt(LSent));
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

procedure TTcpStream.SetCancelToken(const AToken: INetCancelToken);
begin
  FCancelToken := AToken;
  FCancelWaitable := nil;
  if (AToken <> nil) and
     (AToken.QueryInterface(INetCancelWaitable, FCancelWaitable) <> 0) then
    FCancelWaitable := nil;
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

  { MSG_NOSIGNAL：对端断连（RST）时 send 返回 EPIPE 而非 SIGPIPE 杀进程
    （F-7：WS 广播写已断开连接曾致进程 141 死亡）。 }
  LResult := platform_socket_send(FSocket, @ABuf, Int32(ACount), PLATFORM_MSG_NOSIGNAL, LSent);
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

function TTcpStream.PeerAlive: Boolean;
begin
  if FClosed then
    Exit(False);
  Result := platform_socket_peer_alive(FSocket);
end;

procedure TTcpStream.ApplyReadTimeout;
var
  LMs: UInt32;
  LRemaining: TDuration;
begin
  if FReadDeadline.IsInfinite then
  begin
    if FCancelToken <> nil then
    begin
      LMs := NET_IO_CANCEL_SLICE_MS;
      if LMs <> FLastReadTimeoutMs then
      begin
        platform_socket_set_timeout(FSocket, PLATFORM_SO_RCVTIMEO, LMs);
        FLastReadTimeoutMs := LMs;
      end;
      Exit;
    end;
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
  if (FCancelToken <> nil) and (LMs > NET_IO_CANCEL_SLICE_MS) then
    LMs := NET_IO_CANCEL_SLICE_MS;
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
    if FCancelToken <> nil then
    begin
      LMs := NET_IO_CANCEL_SLICE_MS;
      if LMs <> FLastWriteTimeoutMs then
      begin
        platform_socket_set_timeout(FSocket, PLATFORM_SO_SNDTIMEO, LMs);
        FLastWriteTimeoutMs := LMs;
      end;
      Exit;
    end;
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
  if (FCancelToken <> nil) and (LMs > NET_IO_CANCEL_SLICE_MS) then
    LMs := NET_IO_CANCEL_SLICE_MS;
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
  LAddr, LLocalAddr: TPlatformSockAddr;
  LAddrLen: Int32;
  LResult: Int32;
  LLocal: TNetAddress;
begin
  EnsureOpen('accept');
  LAddr.Clear;
  LAddrLen := SizeOf(LAddr.Storage);
  LResult := platform_socket_accept(FSocket, @LAddr.Storage[0], @LAddrLen, LClient);
  if LResult <> 0 then
    raise ENetworkError.Create('tcp accept failed (' + IntToStr(LResult) + ')');
  LAddr.Len := UInt32(LAddrLen);
  LLocalAddr.Clear;
  LAddrLen := SizeOf(LLocalAddr.Storage);
  if platform_socket_getsockname(LClient, @LLocalAddr.Storage[0], @LAddrLen) = 0 then
  begin
    LLocalAddr.Len := UInt32(LAddrLen);
    LLocal := AddrFromSockAddr(LLocalAddr);
  end
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
  LAddr, LLocalAddr: TPlatformSockAddr;
  LAddrLen: Int32;
  LResult: Int32;
  LLocal: TNetAddress;
begin
  AConn := nil;
  EnsureOpen('try accept');
  LAddr.Clear;
  LAddrLen := SizeOf(LAddr.Storage);
  LResult := platform_socket_accept(FSocket, @LAddr.Storage[0], @LAddrLen, LClient);
  if LResult = 0 then
  begin
    LAddr.Len := UInt32(LAddrLen);
    LLocalAddr.Clear;
    LAddrLen := SizeOf(LLocalAddr.Storage);
    if platform_socket_getsockname(LClient, @LLocalAddr.Storage[0], @LAddrLen) = 0 then
    begin
      LLocalAddr.Len := UInt32(LAddrLen);
      LLocal := AddrFromSockAddr(LLocalAddr);
    end
    else
      LLocal := FLocal;
    AConn := TTcpStream.Create(LClient, LLocal, AddrFromSockAddr(LAddr));
    Exit(tarAccepted);
  end;
  if platform_socket_error_would_block(LResult) then
    Exit(tarWouldBlock);
  { EMFILE/ENFILE: process or system fd table full. Treat as temporary
    backpressure (same as would-block for readiness loops) so one bad accept
    does not tear down the epoll server. Threaded Accept still raises. }
  if platform_socket_error_resource_limit(LResult) then
    Exit(tarWouldBlock);
  raise ENetworkError.Create('tcp accept failed (' + IntToStr(LResult) + ')');
end;

{ Factory functions }

{ 构造 bind 失败错误消息：保留 errno 数字，附加可读文本（core
  platform_error_message，POSIX= strerror；如 EADDRINUSE → 'Address already
  in use'），避免运维只看到裸数字。 }
function TcpListenBindError(const ACode: Int32): string;
var
  LBuf: array[0..255] of AnsiChar;
  LMsg: string;
begin
  Result := 'tcp listen: bind failed (' + IntToStr(ACode) + ')';
  if platform_error_message(ACode, @LBuf[0], SizeOf(LBuf)) > 0 then
    Result := Result + ': ' + string(PAnsiChar(@LBuf[0]));
end;

function NetTcpListen(const AAddr: string; const APort: UInt16;
  const ABacklog: Int32): ITcpListener;
var
  LSock: TPlatformSocket;
  LSa: TPlatformSockAddr;
  LSaLen: Int32;
  LOne: Int32;
  LResult: Int32;
  LLocal: TNetAddress;
begin
  { 非空 host 必须是合法 IPv4 字面量：platform_ipv4_parse 解析失败返回 0
    （与合法 "0.0.0.0" 无法区分），透传会把服务意外暴露到全网卡。
    空串保留既有契约（等价 0.0.0.0 绑全网卡，见 test_net_server 的
    empty-addr 用例）；要显式绑全网卡请传 "0.0.0.0"。 }
  if AAddr <> '' then
  begin
    try
      NetResolveIPv4(AAddr);
    except
      on EConvertError do
        raise EArgumentError.Create('tcp listen: invalid host: ' + AAddr);
      on EArgumentError do
        raise EArgumentError.Create('tcp listen: invalid host: ' + AAddr);
    end;
  end;
  LLocal := TNetAddress.Create(AAddr, APort);
  LResult := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0, LSock);
  if LResult <> 0 then
    raise ENetworkError.Create('tcp listen: socket create failed (' + IntToStr(LResult) + ')');
  LOne := 1;
  platform_socket_setsockopt(LSock, PLATFORM_SOL_SOCKET, PLATFORM_SO_REUSEADDR, @LOne, SizeOf(LOne));
  FillSockAddr(LLocal, LSa);
  LResult := platform_socket_bind(LSock, @LSa.Storage[0], Int32(LSa.Len));
  if LResult <> 0 then
  begin
    platform_socket_close(LSock);
    raise ENetworkError.Create(TcpListenBindError(LResult));
  end;
  LResult := platform_socket_listen(LSock, ABacklog);
  if LResult <> 0 then
  begin
    platform_socket_close(LSock);
    raise ENetworkError.Create('tcp listen: listen failed (' + IntToStr(LResult) + ')');
  end;
  { Get actual bound address (important when port=0) }
  LSa.Clear;
  LSaLen := SizeOf(LSa.Storage);
  if platform_socket_getsockname(LSock, @LSa.Storage[0], @LSaLen) = 0 then
  begin
    LSa.Len := UInt32(LSaLen);
    LLocal := AddrFromSockAddr(LSa);
  end;
  Result := TTcpListener.Create(LSock, LLocal);
end;

function NetTcpConnect(const AAddr: string; const APort: UInt16): ITcpStream;
begin
  Result := NetTcpConnect(AAddr, APort, 0);
end;

{ Parse FormatIPv6Addr-style "xxxx:xxxx:..." (8 groups of 4 hex) into 16 bytes. }
function ParseIPv6HexGroups(const AIP: string; ABytes: PByte): Boolean;
var
  LGroup, LNibble, LPos, LVal: Integer;
  LC: Char;
begin
  Result := False;
  if ABytes = nil then
    Exit;
  FillChar(ABytes^, 16, 0);
  LPos := 1;
  for LGroup := 0 to 7 do
  begin
    if LGroup > 0 then
    begin
      if (LPos > Length(AIP)) or (AIP[LPos] <> ':') then
        Exit;
      Inc(LPos);
    end;
    LVal := 0;
    for LNibble := 0 to 3 do
    begin
      if LPos > Length(AIP) then
        Exit;
      LC := AIP[LPos];
      Inc(LPos);
      if LC in ['0'..'9'] then
        LVal := (LVal shl 4) or (Ord(LC) - Ord('0'))
      else if LC in ['a'..'f'] then
        LVal := (LVal shl 4) or (Ord(LC) - Ord('a') + 10)
      else if LC in ['A'..'F'] then
        LVal := (LVal shl 4) or (Ord(LC) - Ord('A') + 10)
      else
        Exit;
    end;
    ABytes[LGroup * 2] := Byte((LVal shr 8) and $FF);
    ABytes[LGroup * 2 + 1] := Byte(LVal and $FF);
  end;
  Result := LPos > Length(AIP);
end;

function BuildConnectSockAddr(const ARemote: TNetAddress;
  out ASa: TPlatformSockAddr): Boolean;
var
  LBytes: array[0..15] of Byte;
  LIP: UInt32;
begin
  Result := False;
  FillChar(ASa, SizeOf(ASa), 0);
  if ARemote.IsIPv6 then
  begin
    if not ParseIPv6HexGroups(ARemote.IP, @LBytes[0]) then
      Exit;
    Result := platform_sockaddr_ipv6(ARemote.Port, @LBytes[0], 0, ASa) = 0;
  end
  else
  begin
    LIP := platform_ipv4_parse(ARemote.IP);
    Result := nextpas.core.platform.socket.platform_sockaddr_ipv4(ARemote.Port, LIP, ASa) = 0;
  end;
end;

function NetBuildConnectSockAddr(const ARemote: TNetAddress;
  out ASa: TPlatformSockAddr): Boolean;
begin
  Result := BuildConnectSockAddr(ARemote, ASa);
end;

function NetTcpStreamFromConnectedSocket(const ASock: TPlatformSocket;
  const ARemote: TNetAddress): ITcpStream;
var
  LLocal: TNetAddress;
  LSa: TPlatformSockAddr;
  LSaLen: Int32;
begin
  { Best-effort restore blocking for stream I/O defaults. }
  platform_socket_set_nonblocking(ASock, False);
  LLocal := TNetAddress.Any(0);
  if not ARemote.IsIPv6 then
  begin
    LSa.Clear;
    LSaLen := SizeOf(LSa.Storage);
    if platform_socket_getsockname(ASock, @LSa.Storage[0], @LSaLen) = 0 then
    begin
      LSa.Len := UInt32(LSaLen);
      LLocal := AddrFromSockAddr(LSa);
    end;
  end;
  Result := TTcpStream.Create(ASock, LLocal, ARemote);
end;

function NetTcpConnectOne(const ARemote: TNetAddress;
  const ATimeoutMs: Int64): ITcpStream;
var
  LSock: TPlatformSocket;
  LSa: TPlatformSockAddr;
  LResult: Int32;
  LPoll: Int32;
  LRevents: Int32;
  LSockErr: Int32;
  LTimed: Boolean;
  LDomain: Int32;
  LLocal: TNetAddress;
  LLocalSa: TPlatformSockAddr;
  LLocalSaLen: Int32;
begin
  if not BuildConnectSockAddr(ARemote, LSa) then
    raise ENetworkError.Create('tcp connect: invalid address ' + ARemote.IP);

  if ARemote.IsIPv6 then
    LDomain := PLATFORM_AF_INET6
  else
    LDomain := PLATFORM_AF_INET;

  LResult := platform_socket_create(LDomain, PLATFORM_SOCK_STREAM, 0, LSock);
  if LResult <> 0 then
    raise ENetworkError.Create('tcp connect: socket create failed (' + IntToStr(LResult) + ')');

  LTimed := ATimeoutMs > 0;
  if LTimed then
  begin
    if platform_socket_set_nonblocking(LSock, True) <> 0 then
    begin
      platform_socket_close(LSock);
      raise ENetworkError.Create('tcp connect: set nonblocking failed');
    end;
  end;

  LResult := platform_socket_connect(LSock, @LSa.Storage[0], LSa.Len);
  if LTimed then
  begin
    if (LResult <> 0) and (not platform_socket_error_in_progress(LResult)) then
    begin
      platform_socket_close(LSock);
      raise ENetworkError.Create('tcp connect failed (' + IntToStr(LResult) + ')');
    end;
    if LResult <> 0 then
    begin
      LPoll := platform_socket_poll(LSock, PLATFORM_POLL_OUT,
        Int32(ATimeoutMs), LRevents);
      if LPoll = 0 then
      begin
        platform_socket_close(LSock);
        raise ETimeoutError.Create('tcp connect deadline exceeded');
      end;
      if LPoll < 0 then
      begin
        platform_socket_close(LSock);
        raise ENetworkError.Create('tcp connect poll failed (' +
          IntToStr(-LPoll) + ')');
      end;
      LSockErr := 0;
      if platform_socket_get_error(LSock, LSockErr) <> 0 then
      begin
        platform_socket_close(LSock);
        raise ENetworkError.Create('tcp connect: get SO_ERROR failed');
      end;
      if LSockErr <> 0 then
      begin
        platform_socket_close(LSock);
        raise ENetworkError.Create('tcp connect failed (' +
          IntToStr(LSockErr) + ')');
      end;
    end;
    if platform_socket_set_nonblocking(LSock, False) <> 0 then
    begin
      platform_socket_close(LSock);
      raise ENetworkError.Create('tcp connect: restore blocking failed');
    end;
  end
  else if LResult <> 0 then
  begin
    platform_socket_close(LSock);
    raise ENetworkError.Create('tcp connect failed (' + IntToStr(LResult) + ')');
  end;

  LLocal := TNetAddress.Any(0);
  if not ARemote.IsIPv6 then
  begin
    LLocalSa.Clear;
    LLocalSaLen := SizeOf(LLocalSa.Storage);
    if platform_socket_getsockname(LSock, @LLocalSa.Storage[0], @LLocalSaLen) = 0 then
    begin
      LLocalSa.Len := UInt32(LLocalSaLen);
      LLocal := AddrFromSockAddr(LLocalSa);
    end;
  end;
  Result := TTcpStream.Create(LSock, LLocal, ARemote);
end;

function NetTcpConnect(const AAddr: string; const APort: UInt16;
  const ATimeoutMs: Int64): ITcpStream;
var
  LList: specialize TArray<TNetAddress>;
  LI: Integer;
  LRemote: TNetAddress;
  LLastMsg: string;
  LLastTimeout: Boolean;
begin
  { HE-lite: sequential multi-A / dual-stack dial (not concurrent RFC8305). }
  LList := NetResolveAll(AAddr);
  if Length(LList) = 0 then
    raise ENetworkError.Create('tcp connect: no addresses for ' + AAddr);

  LLastMsg := 'tcp connect failed';
  LLastTimeout := False;
  for LI := 0 to High(LList) do
  begin
    LRemote := LList[LI];
    LRemote.Port := APort;
    try
      Result := NetTcpConnectOne(LRemote, ATimeoutMs);
      Exit;
    except
      on E: ETimeoutError do
      begin
        LLastTimeout := True;
        LLastMsg := E.Message;
      end;
      on E: Exception do
      begin
        LLastTimeout := False;
        LLastMsg := E.Message;
      end;
    end;
  end;
  if LLastTimeout then
    raise ETimeoutError.Create(LLastMsg)
  else
    raise ENetworkError.Create(LLastMsg);
end;

{ AF_UNIX 平台常量（sockaddr family，native-endian）：Linux/macOS/FreeBSD = 1 }
const
  NET_AF_UNIX = 1;

{ sockaddr_un → TPlatformSockAddr.Storage：family（2B native LE）+ sun_path。
  sun_path 以 NUL 终止，长度取完整 sockaddr_un 语义（2 + pathlen + 1）。 }
procedure FillUnixSockAddr(const APath: string; out ASa: TPlatformSockAddr);
var
  LFamily: UInt16;
  LPathLen: Integer;
begin
  ASa.Clear;
  LFamily := NET_AF_UNIX;
  LPathLen := Length(APath);
  if LPathLen > 107 then
    raise EArgumentError.Create('unix socket path too long: ' + APath);
  Move(LFamily, ASa.Storage[0], 2);
  if LPathLen > 0 then
    Move(APath[1], ASa.Storage[2], LPathLen);
  ASa.Storage[2 + LPathLen] := 0;
  ASa.Len := 2 + LPathLen + 1;
end;

function NetUnixListen(const APath: string): ITcpListener;
var
  LSock: TPlatformSocket;
  LSa: TPlatformSockAddr;
  LResult: Int32;
begin
  {$IFDEF NEXTPAS_WINDOWS}
  raise ENetworkError.Create('unix socket listen: unsupported on this platform');
  {$ELSE}
  if APath = '' then
    raise EArgumentError.Create('unix socket listen: empty path');
  FillUnixSockAddr(APath, LSa);
  LResult := platform_socket_create(NET_AF_UNIX, PLATFORM_SOCK_STREAM, 0, LSock);
  if LResult <> 0 then
    raise ENetworkError.Create('unix socket listen: socket create failed (' + IntToStr(LResult) + ')');
  try
    { 清理上一次残留的 socket 文件（无 listener 存活时安全）。 }
    nextpas.core.fs.Remove(APath);
    LResult := platform_socket_bind(LSock, @LSa.Storage[0], LSa.Len);
    if LResult <> 0 then
      raise ENetworkError.Create('unix socket listen: bind failed (' + IntToStr(LResult) + ')');
    { 权限即认证：仅同用户可连（对齐 codex/grok UDS 控制面）。 }
    nextpas.core.fs.Chmod(APath, TFilePermission($180));   { 0600 }
    LResult := platform_socket_listen(LSock, NET_DEFAULT_BACKLOG);
    if LResult <> 0 then
      raise ENetworkError.Create('unix socket listen: listen failed (' + IntToStr(LResult) + ')');
    Result := TTcpListener.Create(LSock, TNetAddress.Create('', 0));
  except
    platform_socket_close(LSock);
    raise;
  end;
  {$ENDIF}
end;

function NetUnixConnect(const APath: string): ITcpStream;
var
  LSock: TPlatformSocket;
  LSa: TPlatformSockAddr;
  LResult: Int32;
begin
  {$IFDEF NEXTPAS_WINDOWS}
  raise ENetworkError.Create('unix socket connect: unsupported on this platform');
  {$ELSE}
  if APath = '' then
    raise EArgumentError.Create('unix socket connect: empty path');
  FillUnixSockAddr(APath, LSa);
  LResult := platform_socket_create(NET_AF_UNIX, PLATFORM_SOCK_STREAM, 0, LSock);
  if LResult <> 0 then
    raise ENetworkError.Create('unix socket connect: socket create failed (' + IntToStr(LResult) + ')');
  LResult := platform_socket_connect(LSock, @LSa.Storage[0], LSa.Len);
  if LResult <> 0 then
  begin
    platform_socket_close(LSock);
    raise ENetworkError.Create('unix socket connect failed (' + IntToStr(LResult) + ')');
  end;
  Result := TTcpStream.Create(LSock, TNetAddress.Create('', 0), TNetAddress.Create('', 0));
  {$ENDIF}
end;

end.
