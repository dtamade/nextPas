unit nextpas.core.net.async.udp;
{**
 * Async UDP (IPv4) over TAsyncLoop — Go UDPConn / Tokio UdpSocket subset.
 * SendTo/RecvFrom use poller datagram ops (epoll/kqueue; io_uring sidecar epoll).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.time.deadline,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.async.cancellation;

type
  TAsyncUdpRecvCallback = procedure(AResult: Int32; ABytes: Int32;
    const AFrom: TNetAddress; AContext: Pointer);
  TAsyncUdpSendCallback = procedure(AResult: Int32; ABytes: Int32;
    AContext: Pointer);

  IAsyncUdpSocket = interface
    ['{D1E2F3A4-B5C6-7890-ABCD-400000000020}']
    function LocalAddr: TNetAddress;
    procedure Close;
    procedure BindCancelToken(const AToken: IAsyncCancellationToken);
    function AsyncSendTo(ABuf: Pointer; ALen: UInt32; const AAddr: TNetAddress;
      ACallback: TAsyncUdpSendCallback; AContext: Pointer = nil): Boolean;
    function AsyncRecvFrom(ABuf: Pointer; ALen: UInt32;
      ACallback: TAsyncUdpRecvCallback; AContext: Pointer = nil): Boolean;
    function AsyncSendToTimeout(ABuf: Pointer; ALen: UInt32; const AAddr: TNetAddress;
      const ADeadline: TDeadline; ACallback: TAsyncUdpSendCallback;
      AContext: Pointer = nil): Boolean;
    function AsyncRecvFromTimeout(ABuf: Pointer; ALen: UInt32;
      const ADeadline: TDeadline; ACallback: TAsyncUdpRecvCallback;
      AContext: Pointer = nil): Boolean;
  end;

function AsyncUdpBind(const ALoop: TAsyncLoop; const AAddr: string;
  APort: UInt16): IAsyncUdpSocket;

implementation

uses
  nextpas.core.errors,
  nextpas.core.platform.socket,
  nextpas.core.platform.socket.base,
  nextpas.core.net.udp,
  nextpas.core.net.async.cancel;

type
  PUdpSendOp = ^TUdpSendOp;
  TUdpSendOp = record
    UserCb: TAsyncUdpSendCallback;
    UserCtx: Pointer;
    Sa: TPlatformSockAddr;
  end;

  PUdpRecvOp = ^TUdpRecvOp;
  TUdpRecvOp = record
    UserCb: TAsyncUdpRecvCallback;
    UserCtx: Pointer;
    Sa: TPlatformSockAddr;
    SaLen: Int32;
  end;

  TAsyncUdpSocket = class(TInterfacedObject, IAsyncUdpSocket)
  private
    FSock: IUdpSocket;
    FRuntime: IUdpSocketRuntime;
    FLoop: TAsyncLoop;
    function Fd: PtrInt;
  public
    constructor Create(const ASock: IUdpSocket; const ALoop: TAsyncLoop);
    function LocalAddr: TNetAddress;
    procedure Close;
    procedure BindCancelToken(const AToken: IAsyncCancellationToken);
    function AsyncSendTo(ABuf: Pointer; ALen: UInt32; const AAddr: TNetAddress;
      ACallback: TAsyncUdpSendCallback; AContext: Pointer): Boolean;
    function AsyncRecvFrom(ABuf: Pointer; ALen: UInt32;
      ACallback: TAsyncUdpRecvCallback; AContext: Pointer): Boolean;
    function AsyncSendToTimeout(ABuf: Pointer; ALen: UInt32; const AAddr: TNetAddress;
      const ADeadline: TDeadline; ACallback: TAsyncUdpSendCallback;
      AContext: Pointer): Boolean;
    function AsyncRecvFromTimeout(ABuf: Pointer; ALen: UInt32;
      const ADeadline: TDeadline; ACallback: TAsyncUdpRecvCallback;
      AContext: Pointer): Boolean;
  end;

procedure UdpSendIoComplete(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LOp: PUdpSendOp;
  LCb: TAsyncUdpSendCallback;
  LCtx: Pointer;
  LBytes: Int32;
begin
  LOp := PUdpSendOp(AContext);
  if LOp = nil then
    Exit;
  LCb := LOp^.UserCb;
  LCtx := LOp^.UserCtx;
  if AResult >= 0 then
    LBytes := AResult
  else
    LBytes := 0;
  Dispose(LOp);
  if Assigned(LCb) then
    LCb(AResult, LBytes, LCtx);
end;

procedure UdpRecvIoComplete(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LOp: PUdpRecvOp;
  LCb: TAsyncUdpRecvCallback;
  LCtx: Pointer;
  LFrom: TNetAddress;
  LIP: UInt32;
  LPort: UInt16;
  LBytes: Int32;
begin
  LOp := PUdpRecvOp(AContext);
  if LOp = nil then
    Exit;
  LCb := LOp^.UserCb;
  LCtx := LOp^.UserCtx;
  LFrom := Default(TNetAddress);
  LBytes := 0;
  if AResult >= 0 then
  begin
    LBytes := AResult;
    LOp^.Sa.Len := LOp^.SaLen;
    platform_sockaddr_ipv4_extract(LOp^.Sa, LIP, LPort);
    { extract 给网络序；to_string 期望主机序 }
    LFrom.IP := platform_ipv4_to_string(platform_ntohl(LIP));
    LFrom.Port := LPort;
    LFrom.IsIPv6 := False;
  end;
  Dispose(LOp);
  if Assigned(LCb) then
    LCb(AResult, LBytes, LFrom, LCtx);
end;

constructor TAsyncUdpSocket.Create(const ASock: IUdpSocket; const ALoop: TAsyncLoop);
begin
  inherited Create;
  FSock := ASock;
  FLoop := ALoop;
  if ((ASock) = nil) or ((ASock).QueryInterface(IUdpSocketRuntime, FRuntime) <> 0) then
    raise EInvalidOperationError.Create('async udp: socket lacks runtime handle');
end;

function TAsyncUdpSocket.Fd: PtrInt;
begin
  Result := PtrInt(FRuntime.NativeSocketHandle);
end;

function TAsyncUdpSocket.LocalAddr: TNetAddress;
begin
  Result := FSock.LocalAddr;
end;

procedure TAsyncUdpSocket.Close;
begin
  FSock.Close;
end;

procedure TAsyncUdpSocket.BindCancelToken(const AToken: IAsyncCancellationToken);
begin
  { UDP has no blocking cancel path on IUdpSocket yet; reserved for future
    sync RecvFrom cancel. Token kept via no-op bind for API symmetry. }
  if AToken = nil then
    Exit;
end;

function TAsyncUdpSocket.AsyncSendTo(ABuf: Pointer; ALen: UInt32;
  const AAddr: TNetAddress; ACallback: TAsyncUdpSendCallback;
  AContext: Pointer): Boolean;
var
  LOp: PUdpSendOp;
begin
  Result := False;
  if (FLoop = nil) or (not FLoop.IsValid) or (not Assigned(ACallback)) then
    Exit;
  if AAddr.IsIPv6 then
    Exit;
  New(LOp);
  LOp^ := Default(TUdpSendOp);
  LOp^.UserCb := ACallback;
  LOp^.UserCtx := AContext;
  if nextpas.core.platform.socket.platform_sockaddr_ipv4(AAddr.Port,
    platform_ipv4_parse(AAddr.IP), LOp^.Sa) <> 0 then
  begin
    Dispose(LOp);
    Exit;
  end;
  Result := FLoop.AsyncSendTo(Fd, ABuf, ALen, 0, @LOp^.Sa.Storage[0],
    UInt32(LOp^.Sa.Len), @UdpSendIoComplete, LOp);
  if not Result then
    Dispose(LOp);
end;

function TAsyncUdpSocket.AsyncRecvFrom(ABuf: Pointer; ALen: UInt32;
  ACallback: TAsyncUdpRecvCallback; AContext: Pointer): Boolean;
var
  LOp: PUdpRecvOp;
begin
  Result := False;
  if (FLoop = nil) or (not FLoop.IsValid) or (not Assigned(ACallback)) then
    Exit;
  New(LOp);
  LOp^ := Default(TUdpRecvOp);
  LOp^.UserCb := ACallback;
  LOp^.UserCtx := AContext;
  LOp^.Sa.Clear;
  LOp^.SaLen := SizeOf(LOp^.Sa.Storage);
  Result := FLoop.AsyncRecvFrom(Fd, ABuf, ALen, 0, @LOp^.Sa.Storage[0],
    @LOp^.SaLen, @UdpRecvIoComplete, LOp);
  if not Result then
    Dispose(LOp);
end;

function TAsyncUdpSocket.AsyncSendToTimeout(ABuf: Pointer; ALen: UInt32;
  const AAddr: TNetAddress; const ADeadline: TDeadline;
  ACallback: TAsyncUdpSendCallback; AContext: Pointer): Boolean;
var
  LOp: PUdpSendOp;
begin
  Result := False;
  if (FLoop = nil) or (not FLoop.IsValid) or (not Assigned(ACallback)) then
    Exit;
  if AAddr.IsIPv6 then
    Exit;
  if ADeadline.IsInfinite then
    Exit(AsyncSendTo(ABuf, ALen, AAddr, ACallback, AContext));
  New(LOp);
  LOp^ := Default(TUdpSendOp);
  LOp^.UserCb := ACallback;
  LOp^.UserCtx := AContext;
  if nextpas.core.platform.socket.platform_sockaddr_ipv4(AAddr.Port,
    platform_ipv4_parse(AAddr.IP), LOp^.Sa) <> 0 then
  begin
    Dispose(LOp);
    Exit;
  end;
  Result := FLoop.AsyncSendToTimeout(Fd, ABuf, ALen, 0, @LOp^.Sa.Storage[0],
    UInt32(LOp^.Sa.Len), ADeadline, @UdpSendIoComplete, LOp);
  if not Result then
    Dispose(LOp);
end;

function TAsyncUdpSocket.AsyncRecvFromTimeout(ABuf: Pointer; ALen: UInt32;
  const ADeadline: TDeadline; ACallback: TAsyncUdpRecvCallback;
  AContext: Pointer): Boolean;
var
  LOp: PUdpRecvOp;
begin
  Result := False;
  if (FLoop = nil) or (not FLoop.IsValid) or (not Assigned(ACallback)) then
    Exit;
  if ADeadline.IsInfinite then
    Exit(AsyncRecvFrom(ABuf, ALen, ACallback, AContext));
  New(LOp);
  LOp^ := Default(TUdpRecvOp);
  LOp^.UserCb := ACallback;
  LOp^.UserCtx := AContext;
  LOp^.Sa.Clear;
  LOp^.SaLen := SizeOf(LOp^.Sa.Storage);
  Result := FLoop.AsyncRecvFromTimeout(Fd, ABuf, ALen, 0, @LOp^.Sa.Storage[0],
    @LOp^.SaLen, ADeadline, @UdpRecvIoComplete, LOp);
  if not Result then
    Dispose(LOp);
end;

function AsyncUdpBind(const ALoop: TAsyncLoop; const AAddr: string;
  APort: UInt16): IAsyncUdpSocket;
var
  LSock: IUdpSocket;
begin
  if (ALoop = nil) or (not ALoop.IsValid) then
    raise EInvalidOperationError.Create('async udp: invalid loop');
  LSock := NetUdpBind(AAddr, APort);
  Result := TAsyncUdpSocket.Create(LSock, ALoop);
end;

end.
