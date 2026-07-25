unit nextpas.core.http.impl.cancel.adapter;
{**
 * @desc Shared IHttpCancelToken → INetCancelToken bridge (+ waitable forward).
 *       Mechanical dedupe from h1.client / h2.client / websocket.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.intf,
  nextpas.core.http.base;

type
  { Bridge IHttpCancelToken → INetCancelToken; forward waitable when present. }
  THttpNetCancelAdapter = class(TInterfacedObject, INetCancelToken, INetCancelWaitable)
  private
    FToken: IHttpCancelToken;
    FWaitable: INetCancelWaitable;
  public
    constructor Create(const AToken: IHttpCancelToken);
    function IsCanceled: Boolean;
    function WakeHandle: PtrUInt;
    procedure DrainWake;
  end;

{ Apply AToken to AConn. Nil clears. Prefer native INetCancelToken; else adapt. }
procedure ApplyHttpCancelToken(const AConn: ITcpStream;
  const AToken: IHttpCancelToken);

implementation

constructor THttpNetCancelAdapter.Create(const AToken: IHttpCancelToken);
begin
  inherited Create;
  FToken := AToken;
  FWaitable := nil;
  if (AToken <> nil) and
     (AToken.QueryInterface(INetCancelWaitable, FWaitable) <> 0) then
    FWaitable := nil;
end;

function THttpNetCancelAdapter.IsCanceled: Boolean;
begin
  Result := (FToken <> nil) and FToken.IsCanceled;
end;

function THttpNetCancelAdapter.WakeHandle: PtrUInt;
begin
  if FWaitable <> nil then
    Result := FWaitable.WakeHandle
  else
    Result := 0;
end;

procedure THttpNetCancelAdapter.DrainWake;
begin
  if FWaitable <> nil then
    FWaitable.DrainWake;
end;

procedure ApplyHttpCancelToken(const AConn: ITcpStream;
  const AToken: IHttpCancelToken);
var
  LNet: INetCancelToken;
begin
  if AConn = nil then
    Exit;
  if AToken = nil then
    AConn.SetCancelToken(nil)
  else if AToken.QueryInterface(INetCancelToken, LNet) = 0 then
    AConn.SetCancelToken(LNet)
  else
    AConn.SetCancelToken(THttpNetCancelAdapter.Create(AToken));
end;

end.