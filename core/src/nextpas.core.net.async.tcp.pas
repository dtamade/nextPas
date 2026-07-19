unit nextpas.core.net.async.tcp;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base, nextpas.core.time.deadline,
  nextpas.core.io.intf,
  nextpas.core.net.base, nextpas.core.net.intf,
  nextpas.core.async.base, nextpas.core.async.loop;

type
  { 异步 TCP 流，集成事件循环 }
  IAsyncTcpStream = interface(ITcpStream)
    ['{D1E2F3A4-B5C6-7890-ABCD-400000000001}']
    { 异步读取 }
    function AsyncRead(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncReadRef(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletionRef; AContext: Pointer = nil): Boolean;

    { 异步写入 }
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

implementation

uses
  nextpas.core.errors,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  {$IFDEF NEXTPAS_LINUX}
  nextpas.core.platform.linux.ffi,
  {$ENDIF}
  nextpas.core.platform.socket,
  nextpas.core.net.tcp;

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
  Result := FLoop.AsyncWrite(LFd, ABuf, ALen, 0, ACallback, AContext);
end;

function TAsyncTcpStream.AsyncWriteRef(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
var
  LFd: PtrInt;
begin
  LFd := PtrInt(NativeSocketHandle);
  Result := FLoop.AsyncWrite(LFd, ABuf, ALen, 0, @IoCompletionRefWrapper,
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
  Result := FLoop.AsyncWriteTimeout(LFd, ABuf, ALen, 0, ADeadline, ACallback, AContext);
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

function TAsyncTcpListener.TryAccept(out AConn: ITcpStream): TTcpAcceptResult;
begin
  Result := (FListener as ITcpListenerRuntime).TryAccept(AConn);
end;

function TAsyncTcpListener.AsyncAccept(ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
var
  LFd: PtrInt;
  LSa: sockaddr;
  LSaLen: Int32;
  LRes: Int32;
begin
  LFd := PtrInt(NativeSocketHandle);
  FillChar(LSa, SizeOf(LSa), 0);
  LSaLen := SizeOf(LSa);
  { 先尝试同步 accept，解决边沿触发 epoll 的已有连接问题 }
  LRes := accept4(cint(LFd), @LSa, @LSaLen, 0);
  if LRes >= 0 then
  begin
    { 已有连接等待，直接触发回调 }
    if Assigned(ACallback) then
      ACallback(0, LRes, AContext);
    Result := True;
    Exit;
  end;
  { 没有等待的连接，使用异步 accept }
  FillChar(LSa, SizeOf(LSa), 0);
  LSaLen := SizeOf(LSa);
  Result := FLoop.AsyncAccept(LFd, @LSa, @LSaLen, 0, ACallback, AContext);
end;

function TAsyncTcpListener.AsyncAcceptRef(ACallback: TIoCompletionRef;
  AContext: Pointer): Boolean;
var
  LFd: PtrInt;
  LSa: sockaddr;
  LSaLen: Int32;
  LRes: Int32;
begin
  LFd := PtrInt(NativeSocketHandle);
  FillChar(LSa, SizeOf(LSa), 0);
  LSaLen := SizeOf(LSa);
  { 先尝试同步 accept }
  LRes := accept4(cint(LFd), @LSa, @LSaLen, 0);
  if LRes >= 0 then
  begin
    if Assigned(ACallback) then
      ACallback(0, LRes, AContext);
    Result := True;
    Exit;
  end;
  FillChar(LSa, SizeOf(LSa), 0);
  LSaLen := SizeOf(LSa);
  Result := FLoop.AsyncAccept(LFd, @LSa, @LSaLen, 0, @IoCompletionRefWrapper,
    WrapIoCompletionRef(ACallback, AContext));
end;

function TAsyncTcpListener.AsyncAcceptTimeout(const ADeadline: TDeadline;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LFd: PtrInt;
  LSa: sockaddr;
  LSaLen: Int32;
  LRes: Int32;
begin
  LFd := PtrInt(NativeSocketHandle);
  FillChar(LSa, SizeOf(LSa), 0);
  LSaLen := SizeOf(LSa);
  LRes := accept4(cint(LFd), @LSa, @LSaLen, 0);
  if LRes >= 0 then
  begin
    if Assigned(ACallback) then
      ACallback(0, LRes, AContext);
    Result := True;
    Exit;
  end;
  FillChar(LSa, SizeOf(LSa), 0);
  LSaLen := SizeOf(LSa);
  Result := FLoop.AsyncAccept(LFd, @LSa, @LSaLen, 0, ACallback, AContext);
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
  LStream := NetTcpConnect(AAddr, APort);
  Result := TAsyncTcpStream.Create(LStream, ALoop) as IAsyncTcpStream;
end;

end.
