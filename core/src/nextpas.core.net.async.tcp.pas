unit nextpas.core.net.async.tcp;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base, nextpas.core.time.deadline,
  nextpas.core.io.intf,
  nextpas.core.net.base, nextpas.core.net.intf,
  nextpas.core.async.base, nextpas.core.async.loop,
  nextpas.core.async.cancellation;

type
  { 异步 TCP 流，集成事件循环 }
  IAsyncTcpStream = interface(ITcpStream)
    ['{D1E2F3A4-B5C6-7890-ABCD-400000000001}']
    { 异步读取 }
    function AsyncRead(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncReadRef(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletionRef; AContext: Pointer = nil): Boolean;

    { 异步写入。不拷贝：ABuf 须保持有效直到回调。短写回调 AResult 为
      本次实际送达（可能 < ALen），不自动续发；一 op 一回调。 }
    function AsyncWrite(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWriteRef(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletionRef; AContext: Pointer = nil): Boolean;

    { 带超时的异步读取 }
    function AsyncReadTimeout(ABuf: Pointer; ALen: UInt32;
      const ADeadline: TDeadline; ACallback: TIoCompletion;
      AContext: Pointer = nil): Boolean;

    { 带超时的异步写入 }
    function AsyncWriteTimeout(ABuf: Pointer; ALen: UInt32;
      const ADeadline: TDeadline; ACallback: TIoCompletion;
      AContext: Pointer = nil): Boolean;

    { Bind IAsyncCancellationToken via NetCancelFromAsync (blocking-IO wake). }
    procedure BindCancelToken(const AToken: IAsyncCancellationToken);
  end;

  { 异步 TCP 监听器 }
  IAsyncTcpListener = interface(ITcpListener)
    ['{D1E2F3A4-B5C6-7890-ABCD-400000000002}']
    { 异步接受连接 }
    function AsyncAccept(ACallback: TIoCompletion;
      AContext: Pointer = nil): Boolean;
    function AsyncAcceptRef(ACallback: TIoCompletionRef;
      AContext: Pointer = nil): Boolean;

    { 带超时的异步接受 }
    function AsyncAcceptTimeout(const ADeadline: TDeadline;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
  end;

{ 创建异步 TCP 监听器 }
function AsyncTcpListen(const ALoop: TAsyncLoop;
  const AAddr: string; const APort: UInt16): IAsyncTcpListener;

{ 创建异步 TCP 连接 }
function AsyncTcpConnect(const ALoop: TAsyncLoop;
  const AAddr: string; const APort: UInt16): IAsyncTcpStream;
{ Wrap an existing connected ITcpStream for async I/O on ALoop. }
function AsyncTcpStreamAdopt(const ALoop: TAsyncLoop;
  const AStream: ITcpStream): IAsyncTcpStream;

implementation

uses
  nextpas.core.errors,
  nextpas.core.platform.socket,
  nextpas.core.platform.socket.base,
  nextpas.core.net.tcp,
  nextpas.core.net.async.cancel;

type
  TAsyncTcpStream = class(TInterfacedObject, IReader, IWriter, IReadWriteCloser,
    ITcpStream, ITcpSocketRuntime, ITcpStreamRuntime, IAsyncTcpStream)
  private
    FStream: ITcpStream;
    FLoop: TAsyncLoop;
  public
    constructor Create(const AStream: ITcpStream; const ALoop: TAsyncLoop);
    destructor Destroy; override;

    { IReader }
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;

    { IWriter }
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;

    { IReadWriteCloser }
    procedure Close;

    { ITcpStream }
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
    procedure SetCancelToken(const AToken: INetCancelToken);
    procedure BindCancelToken(const AToken: IAsyncCancellationToken);

    { ITcpSocketRuntime }
    function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);

    { ITcpStreamRuntime }
    function TryRead(var ABuf; const ACount: SizeUInt;
      out ARead: SizeUInt): TTcpStreamIOResult;
    function TryWrite(const ABuf; const ACount: SizeUInt;
      out AWritten: SizeUInt): TTcpStreamIOResult;

    { IAsyncTcpStream }
    function AsyncRead(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncReadRef(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletionRef; AContext: Pointer = nil): Boolean;
    function AsyncWrite(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWriteRef(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletionRef; AContext: Pointer = nil): Boolean;
    function AsyncReadTimeout(ABuf: Pointer; ALen: UInt32;
      const ADeadline: TDeadline; ACallback: TIoCompletion;
      AContext: Pointer = nil): Boolean;
    function AsyncWriteTimeout(ABuf: Pointer; ALen: UInt32;
      const ADeadline: TDeadline; ACallback: TIoCompletion;
      AContext: Pointer = nil): Boolean;
  end;

  TAsyncTcpListener = class(TInterfacedObject, ITcpListener, ITcpSocketRuntime,
    ITcpListenerRuntime, IAsyncTcpListener)
  private
    FListener: ITcpListener;
    FLoop: TAsyncLoop;
    { accept 地址缓冲（监听器字段而非栈局部）：异步 accept op 延迟执行
      accept4，向 Addr/AddrLen 写客户端地址——若指向已返回的栈局部即
      悬垂写，破坏事件循环栈（对端地址写入调用方帧，间歇性连接失败）。
      监听器生命周期覆盖 op 生命周期；EPOLLONESHOT 串行化保证同监听器
      上一次 accept op 完成后才重 arm 复用同一缓冲，无并发写。 }
    FSa: array[0..127] of Byte;
    FSaLen: Int32;
    { 同步 try accept 前确保 listener 非阻塞：NetTcpListen 创建的 listener
      默认阻塞模式，无连接时阻塞 accept 会卡死事件循环线程。返回 False
      表示设置失败（此时调用方应放弃本次 accept 而非继续）。 }
    function EnsureNonBlockingListen: Boolean;
    { 三 accept 重载的唯一实现：同步 try-accept 快路径 + 异步回退（带超时
      时经 loop AsyncAcceptTimeout 挂取消语义，否则原样注册）。 }
    function AcceptImpl(const ADeadline: TDeadline; AHasDeadline: Boolean;
      ACallback: TIoCompletion; AContext: Pointer): Boolean;
  public
    constructor Create(const AListener: ITcpListener; const ALoop: TAsyncLoop);
    destructor Destroy; override;

    { ITcpListener }
    function Accept: ITcpStream;
    function LocalAddr: TNetAddress;
    procedure Close;

    { ITcpSocketRuntime }
    function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);

    { ITcpListenerRuntime }
    function TryAccept(out AConn: ITcpStream): TTcpAcceptResult;

    { IAsyncTcpListener }
    function AsyncAccept(ACallback: TIoCompletion;
      AContext: Pointer = nil): Boolean;
    function AsyncAcceptRef(ACallback: TIoCompletionRef;
      AContext: Pointer = nil): Boolean;
    function AsyncAcceptTimeout(const ADeadline: TDeadline;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
  end;

{ TAsyncTcpStream }

constructor TAsyncTcpStream.Create(const AStream: ITcpStream; const ALoop: TAsyncLoop);
begin
  inherited Create;
  FStream := AStream;
  FLoop := ALoop;
end;

destructor TAsyncTcpStream.Destroy;
begin
  FStream := nil;
  inherited;
end;

function TAsyncTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FStream.Read(ABuf, ACount);
end;

function TAsyncTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := FStream.Write(ABuf, ACount);
end;

procedure TAsyncTcpStream.Close;
begin
  FStream.Close;
end;

function TAsyncTcpStream.LocalAddr: TNetAddress;
begin
  Result := FStream.LocalAddr;
end;

function TAsyncTcpStream.RemoteAddr: TNetAddress;
begin
  Result := FStream.RemoteAddr;
end;

procedure TAsyncTcpStream.Shutdown;
begin
  FStream.Shutdown;
end;

procedure TAsyncTcpStream.SetNoDelay(const AValue: Boolean);
begin
  FStream.SetNoDelay(AValue);
end;

procedure TAsyncTcpStream.SetKeepAlive(const AValue: Boolean);
begin
  FStream.SetKeepAlive(AValue);
end;

procedure TAsyncTcpStream.SetReadDeadline(const ADeadline: TDeadline);
begin
  FStream.SetReadDeadline(ADeadline);
end;

procedure TAsyncTcpStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
  FStream.SetWriteDeadline(ADeadline);
end;

procedure TAsyncTcpStream.SetCancelToken(const AToken: INetCancelToken);
begin
  FStream.SetCancelToken(AToken);
end;

procedure TAsyncTcpStream.BindCancelToken(const AToken: IAsyncCancellationToken);
begin
  TcpStreamBindAsyncCancel(FStream, AToken);
end;

function TAsyncTcpStream.NativeSocketHandle: PtrUInt;
begin
  Result := (FStream as ITcpSocketRuntime).NativeSocketHandle;
end;

procedure TAsyncTcpStream.SetBlocking(const ABlocking: Boolean);
begin
  (FStream as ITcpSocketRuntime).SetBlocking(ABlocking);
end;

function TAsyncTcpStream.TryRead(var ABuf; const ACount: SizeUInt;
  out ARead: SizeUInt): TTcpStreamIOResult;
begin
  Result := (FStream as ITcpStreamRuntime).TryRead(ABuf, ACount, ARead);
end;

function TAsyncTcpStream.TryWrite(const ABuf; const ACount: SizeUInt;
  out AWritten: SizeUInt): TTcpStreamIOResult;
begin
  Result := (FStream as ITcpStreamRuntime).TryWrite(ABuf, ACount, AWritten);
end;

function TAsyncTcpStream.AsyncRead(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LFd: PtrInt;
begin
  LFd := PtrInt(NativeSocketHandle);
  Result := FLoop.AsyncRecv(LFd, ABuf, ALen, 0, ACallback, AContext);
end;

function TAsyncTcpStream.AsyncReadRef(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
var
  LFd: PtrInt;
begin
  LFd := PtrInt(NativeSocketHandle);
  Result := FLoop.AsyncRecvRef(LFd, ABuf, ALen, 0, ACallback, AContext);
end;

function TAsyncTcpStream.AsyncWrite(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LFd: PtrInt;
begin
  LFd := PtrInt(NativeSocketHandle);
  Result := FLoop.AsyncSend(LFd, ABuf, ALen, 0, ACallback, AContext);
end;

function TAsyncTcpStream.AsyncWriteRef(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
var
  LFd: PtrInt;
begin
  LFd := PtrInt(NativeSocketHandle);
  Result := FLoop.AsyncSend(LFd, ABuf, ALen, 0, @IoCompletionRefWrapper,
    WrapIoCompletionRef(ACallback, AContext));
end;

function TAsyncTcpStream.AsyncReadTimeout(ABuf: Pointer; ALen: UInt32;
  const ADeadline: TDeadline; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
var
  LFd: PtrInt;
begin
  LFd := PtrInt(NativeSocketHandle);
  Result := FLoop.AsyncRecvTimeout(LFd, ABuf, ALen, 0, ADeadline, ACallback, AContext);
end;

function TAsyncTcpStream.AsyncWriteTimeout(ABuf: Pointer; ALen: UInt32;
  const ADeadline: TDeadline; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
var
  LFd: PtrInt;
begin
  LFd := PtrInt(NativeSocketHandle);
  Result := FLoop.AsyncSendTimeout(LFd, ABuf, ALen, 0, ADeadline, ACallback, AContext);
end;

{ TAsyncTcpListener }

constructor TAsyncTcpListener.Create(const AListener: ITcpListener; const ALoop: TAsyncLoop);
begin
  inherited Create;
  FListener := AListener;
  FLoop := ALoop;
end;

destructor TAsyncTcpListener.Destroy;
begin
  FListener := nil;
  inherited;
end;

function TAsyncTcpListener.Accept: ITcpStream;
begin
  Result := FListener.Accept;
end;

function TAsyncTcpListener.LocalAddr: TNetAddress;
begin
  Result := FListener.LocalAddr;
end;

procedure TAsyncTcpListener.Close;
begin
  FListener.Close;
end;

function TAsyncTcpListener.NativeSocketHandle: PtrUInt;
begin
  Result := (FListener as ITcpSocketRuntime).NativeSocketHandle;
end;

procedure TAsyncTcpListener.SetBlocking(const ABlocking: Boolean);
begin
  (FListener as ITcpSocketRuntime).SetBlocking(ABlocking);
end;

function TAsyncTcpListener.EnsureNonBlockingListen: Boolean;
begin
  { SetBlocking(False) 委托到底层 platform_socket_set_nonblocking；失败抛
    异常（fd 已关等极端情形），此处吞掉并返回 False，不冒泡进事件循环。 }
  try
    SetBlocking(False);
    Result := True;
  except
    Result := False;
  end;
end;

function TAsyncTcpListener.TryAccept(out AConn: ITcpStream): TTcpAcceptResult;
begin
  Result := (FListener as ITcpListenerRuntime).TryAccept(AConn);
end;

function TAsyncTcpListener.AcceptImpl(const ADeadline: TDeadline; AHasDeadline: Boolean;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LFd: PtrInt;
  LListen: TPlatformSocket;
  LClient: TPlatformSocket;
  LRes: Int32;
begin
  { 确保 listener 非阻塞：NetTcpListen 创建的 listener 默认阻塞模式，
    无连接时阻塞 accept 会卡死事件循环线程（reactor 注册路径才设非阻塞，
    快路径必须先设；Windows 下 winsock accept 同样适用）。 }
  if not EnsureNonBlockingListen then
    Exit(False);
  LFd := PtrInt(NativeSocketHandle);
  FillChar(FSa, SizeOf(FSa), 0);
  FSaLen := SizeOf(FSa);
  LListen.Value := {$IFDEF NEXTPAS_WINDOWS}PtrUInt(LFd){$ELSE}Int32(LFd){$ENDIF};
  { 同步 accept 优先：边沿触发 epoll/kqueue 上已有连接；可移植（非 accept4）。 }
  LRes := platform_socket_accept(LListen, @FSa, @FSaLen, LClient);
  if LRes = 0 then
  begin
    if Assigned(ACallback) then
      ACallback(0, Int32(LClient.Value), AContext);
    Exit(True);
  end;
  FillChar(FSa, SizeOf(FSa), 0);
  FSaLen := SizeOf(FSa);
  if AHasDeadline then
    Result := FLoop.AsyncAcceptTimeout(LFd, @FSa, @FSaLen, 0, ADeadline,
      ACallback, AContext)
  else
    Result := FLoop.AsyncAccept(LFd, @FSa, @FSaLen, 0, ACallback, AContext);
end;

function TAsyncTcpListener.AsyncAccept(ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
begin
  Result := AcceptImpl(TDeadline.Infinite, False, ACallback, AContext);
end;

function TAsyncTcpListener.AsyncAcceptRef(ACallback: TIoCompletionRef;
  AContext: Pointer): Boolean;
var
  LCtx: Pointer;
begin
  LCtx := WrapIoCompletionRef(ACallback, AContext);
  Result := AcceptImpl(TDeadline.Infinite, False, @IoCompletionRefWrapper, LCtx);
  if not Result then
    Dispose(PIoCompletionRefCtx(LCtx));
end;

function TAsyncTcpListener.AsyncAcceptTimeout(const ADeadline: TDeadline;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := AcceptImpl(ADeadline, True, ACallback, AContext);
end;

{ 工厂函数 }

function AsyncTcpListen(const ALoop: TAsyncLoop;
  const AAddr: string; const APort: UInt16): IAsyncTcpListener;
var
  LListener: ITcpListener;
begin
  LListener := NetTcpListen(AAddr, APort);
  Result := TAsyncTcpListener.Create(LListener, ALoop) as IAsyncTcpListener;
end;

function AsyncTcpConnect(const ALoop: TAsyncLoop;
  const AAddr: string; const APort: UInt16): IAsyncTcpStream;
var
  LStream: ITcpStream;
begin
  { NetTcpConnect uses NetResolveAll + sequential multi-A / dual-stack try (HE-lite). }
  LStream := NetTcpConnect(AAddr, APort);
  Result := TAsyncTcpStream.Create(LStream, ALoop) as IAsyncTcpStream;
end;

function AsyncTcpStreamAdopt(const ALoop: TAsyncLoop;
  const AStream: ITcpStream): IAsyncTcpStream;
begin
  if (ALoop = nil) or (AStream = nil) then
    raise EInvalidOperationError.Create('AsyncTcpStreamAdopt: nil loop or stream');
  Result := TAsyncTcpStream.Create(AStream, ALoop) as IAsyncTcpStream;
end;

end.
