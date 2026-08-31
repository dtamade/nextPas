unit nextpas.core.net.async.cancel;
{**
 * Bridge IAsyncCancellationToken → INetCancelToken for blocking TCP wake.
 * Recommended user entry: async token (dial/combinators). Net token is plumbing
 * for poll+socketpair cancel on blocking Read/Write.
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
  nextpas.core.system,
  nextpas.core.net.cancel;

type
  PAsyncNetCancelCtx = ^TAsyncNetCancelCtx;
  TAsyncNetCancelCtx = record
    Net: INetCancelController;
    Gateway: Pointer;
  end;

  TAsyncNetCancelGateway = class(TInterfacedObject,
    INetCancelToken, INetCancelController, INetCancelWaitable)
  private
    FInner: INetCancelController;
    FAsync: IAsyncCancellationToken;
    FCtx: PAsyncNetCancelCtx;
    FLinked: Boolean;
  public
    constructor Create(const AAsync: IAsyncCancellationToken);
    destructor Destroy; override;
    function IsCanceled: Boolean;
    procedure Cancel;
    function WakeHandle: PtrUInt;
    procedure DrainWake;
  end;

procedure AsyncNetCancelBridgeFire(AContext: Pointer);
var
  LCtx: PAsyncNetCancelCtx;
  LGw: TAsyncNetCancelGateway;
begin
  LCtx := PAsyncNetCancelCtx(AContext);
  if LCtx = nil then
    Exit;
  LGw := nil;
  try
    LGw := TAsyncNetCancelGateway(LCtx^.Gateway);
  except
    LGw := nil;
  end;
  try
    if LCtx^.Net <> nil then
      try
        LCtx^.Net.Cancel;
      except
      end;
    try
      LCtx^.Net := nil;
    except
    end;
  except
  end;
  if LGw <> nil then
  try
    LGw.FCtx := nil;
    LGw.FLinked := False;
  except
  end;
  try
    LCtx^.Gateway := nil;
  except
  end;
  Dispose(LCtx);
end;

constructor TAsyncNetCancelGateway.Create(
  const AAsync: IAsyncCancellationToken);
var
  LInner: INetCancelController;
  LCtx: PAsyncNetCancelCtx;
begin
  inherited Create;
  FAsync := AAsync;
  LInner := NewNetCancelToken;
  FInner := LInner;
  New(LCtx);
  LCtx^ := Default(TAsyncNetCancelCtx);
  LCtx^.Net := FInner;
  LCtx^.Gateway := Self;
  FCtx := LCtx;
  FLinked := False;
  try
    FAsync.OnCancel(@AsyncNetCancelBridgeFire, FCtx);
    FLinked := True;
    if FCtx = nil then
      FLinked := False;
  except
    FLinked := False;
  end;
  if FAsync.IsCancelled then
    try
      Cancel;
    except
    end;
end;

destructor TAsyncNetCancelGateway.Destroy;
begin
  if FLinked and (FAsync <> nil) and (FCtx <> nil) then
    try
      FAsync.RemoveOnCancel(@AsyncNetCancelBridgeFire, FCtx);
    except
    end;
  if FCtx <> nil then
  try
    try
      FCtx^.Net := nil;
    except
    end;
    try
      FCtx^.Gateway := nil;
    except
    end;
    Dispose(FCtx);
  except
  end;
  FCtx := nil;
  FLinked := False;
  FAsync := nil;
  FInner := nil;
  inherited Destroy;
end;

function TAsyncNetCancelGateway.IsCanceled: Boolean;
begin
  if FInner <> nil then
    try
      Result := FInner.IsCanceled;
    except
      Result := False;
    end
  else
    Result := False;
end;

procedure TAsyncNetCancelGateway.Cancel;
begin
  if FInner <> nil then
    try
      FInner.Cancel;
    except
    end;
end;

function TAsyncNetCancelGateway.WakeHandle: PtrUInt;
var
  LW: INetCancelWaitable;
begin
  Result := 0;
  if FInner = nil then
    Exit;
  try
    if nextpas.core.system.Supports(FInner, INetCancelWaitable, LW) then
      Result := LW.WakeHandle;
  except
    Result := 0;
  end;
end;

procedure TAsyncNetCancelGateway.DrainWake;
var
  LW: INetCancelWaitable;
begin
  if FInner = nil then
    Exit;
  try
    if nextpas.core.system.Supports(FInner, INetCancelWaitable, LW) then
      LW.DrainWake;
  except
  end;
end;

function NetCancelFromAsync(
  const AAsync: IAsyncCancellationToken): INetCancelController;
begin
  Result := nil;
  if AAsync = nil then
    Exit;
  Result := TAsyncNetCancelGateway.Create(AAsync);
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
