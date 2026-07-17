unit nextpas.core.net.cancel;
{**
 * @desc Cooperative cancel tokens for blocking TCP IO.
 *       Waitable tokens use a socketpair wake so poll can interrupt reads/writes
 *       without SO_*TIMEO slice polling (Unix). Windows falls back to probe-only
 *       when socketpair is unavailable.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.intf;

function NewNetCancelToken: INetCancelController;

implementation

uses
  nextpas.core.platform.socket;

type
  TNetCancelToken = class(TInterfacedObject, INetCancelToken, INetCancelController,
    INetCancelWaitable)
  private
    FCanceled: Boolean;
    FHasWake: Boolean;
    FWakeRead: TPlatformSocket;
    FWakeWrite: TPlatformSocket;
    procedure SignalWake;
  public
    constructor Create;
    destructor Destroy; override;
    function IsCanceled: Boolean;
    procedure Cancel;
    function WakeHandle: PtrUInt;
    procedure DrainWake;
  end;

constructor TNetCancelToken.Create;
var
  LRc: Int32;
begin
  inherited Create;
  FCanceled := False;
  FHasWake := False;
  FWakeRead := PLATFORM_INVALID_SOCKET;
  FWakeWrite := PLATFORM_INVALID_SOCKET;
  { AF_UNIX=1 on Linux/macOS/FreeBSD/Windows winsock headers. }
  LRc := platform_socket_pair(1, PLATFORM_SOCK_STREAM, 0, FWakeRead, FWakeWrite);
  FHasWake := LRc = 0;
  if not FHasWake then
  begin
    FWakeRead := PLATFORM_INVALID_SOCKET;
    FWakeWrite := PLATFORM_INVALID_SOCKET;
  end
  else
  begin
    { Nonblocking so DrainWake never stalls on empty pipe. }
    platform_socket_set_nonblocking(FWakeRead, True);
    platform_socket_set_nonblocking(FWakeWrite, True);
  end;
end;

destructor TNetCancelToken.Destroy;
begin
  if FHasWake then
  begin
    platform_socket_close(FWakeRead);
    platform_socket_close(FWakeWrite);
    FHasWake := False;
  end;
  inherited;
end;

function TNetCancelToken.IsCanceled: Boolean;
begin
  Result := FCanceled;
end;

procedure TNetCancelToken.SignalWake;
var
  LByte: Byte;
  LSent: Int32;
begin
  if not FHasWake then
    Exit;
  LByte := 1;
  platform_socket_send(FWakeWrite, @LByte, 1, 0, LSent);
end;

procedure TNetCancelToken.Cancel;
begin
  if FCanceled then
    Exit;
  FCanceled := True;
  SignalWake;
end;

function TNetCancelToken.WakeHandle: PtrUInt;
begin
  if FHasWake then
    Result := PtrUInt(FWakeRead.Value)
  else
    Result := 0;
end;

procedure TNetCancelToken.DrainWake;
var
  LBuf: array[0..63] of Byte;
  LRecvd: Int32;
begin
  if not FHasWake then
    Exit;
  while platform_socket_recv(FWakeRead, @LBuf[0], SizeOf(LBuf), 0, LRecvd) = 0 do
  begin
    if LRecvd <= 0 then
      Break;
  end;
end;

function NewNetCancelToken: INetCancelController;
begin
  Result := TNetCancelToken.Create;
end;

end.
