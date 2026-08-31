unit nextpas.core.net.async.cancel;
{**
 * Bridge IAsyncCancellationToken → INetCancelToken for blocking TCP wake.
 * Recommended user entry: async token (dial/combinators). Net token is plumbing
 * for poll+socketpair cancel on blocking Read/Write.
 * Lifetime: returned bridge owns the waitable Net token and removes the
 * OnCancel registration on destruction to avoid UAF/leak when never cancelled.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.intf,
  nextpas.core.async.cancellation;

{ Create a waitable net cancel controller linked to AAsync.
  Async.Cancel (or already-cancelled) propagates to Net.Cancel.
  Returns nil if AAsync is nil. }
function NetCancelFromAsync(
  const AAsync: IAsyncCancellationToken): INetCancelController;

{ Bind async cancel onto any ITcpStream (incl. IAsyncTcpStream). }
procedure TcpStreamBindAsyncCancel(const AStream: ITcpStream;
  const AToken: IAsyncCancellationToken);

implementation

uses
  SysUtils,
  nextpas.core.net.cancel;

type
  TAsyncNetCancelBridge = class(TInterfacedObject, INetCancelToken, INetCancelController, INetCancelWaitable)
  private
    FInner: INetCancelController;
    FWaitable: INetCancelWaitable;
    FAsync: IAsyncCancellationToken;
  public
    constructor Create(AInner: INetCancelController; AAsync: IAsyncCancellationToken);
    destructor Destroy; override;
    function IsCanceled: Boolean;
    procedure Cancel;
    function WakeHandle: PtrUInt;
    procedure DrainWake;
  end;

procedure AsyncNetCancelBridgeFire(AContext: Pointer); forward;

{ TAsyncNetCancelBridge }

constructor TAsyncNetCancelBridge.Create(AInner: INetCancelController;
  AAsync: IAsyncCancellationToken);
begin
  inherited Create;
  FInner := AInner;
  FAsync := AAsync;
  FWaitable := nil;
  if (FInner <> nil) and (FInner.QueryInterface(INetCancelWaitable, FWaitable) <> 0) then
    FWaitable := nil;
end;

destructor TAsyncNetCancelBridge.Destroy;
begin
  if FAsync <> nil then
  begin
    try
      FAsync.RemoveOnCancel(@AsyncNetCancelBridgeFire, Pointer(Self));
    except
    end;
  end;
  FWaitable := nil;
  FInner := nil;
  FAsync := nil;
  inherited Destroy;
end;

function TAsyncNetCancelBridge.IsCanceled: Boolean;
begin
  Result := (FInner <> nil) and FInner.IsCanceled;
end;

procedure TAsyncNetCancelBridge.Cancel;
begin
  if FInner <> nil then
    FInner.Cancel;
end;

function TAsyncNetCancelBridge.WakeHandle: PtrUInt;
begin
  if FWaitable <> nil then
    Result := FWaitable.WakeHandle
  else
    Result := 0;
end;

procedure TAsyncNetCancelBridge.DrainWake;
begin
  if FWaitable <> nil then
    FWaitable.DrainWake;
end;

procedure AsyncNetCancelBridgeFire(AContext: Pointer);
var
  LBridge: TAsyncNetCancelBridge;
begin
  LBridge := TAsyncNetCancelBridge(AContext);
  if LBridge = nil then
    Exit;
  if LBridge.FInner <> nil then
    LBridge.FInner.Cancel;
end;

function NetCancelFromAsync(
  const AAsync: IAsyncCancellationToken): INetCancelController;
var
  LInner: INetCancelController;
  LBridge: TAsyncNetCancelBridge;
begin
  Result := nil;
  if AAsync = nil then
    Exit;
  LInner := NewNetCancelToken;
  LBridge := TAsyncNetCancelBridge.Create(LInner, AAsync);
  Result := LBridge;
  AAsync.OnCancel(@AsyncNetCancelBridgeFire, Pointer(LBridge));
  if AAsync.IsCancelled then
    LInner.Cancel;
end;

procedure TcpStreamBindAsyncCancel(const AStream: ITcpStream;
  const AToken: IAsyncCancellationToken);
begin
  if AStream = nil then
    Exit;
  if AToken = nil then
    AStream.SetCancelToken(nil)
  else
    AStream.SetCancelToken(NetCancelFromAsync(AToken));
end;

end.
