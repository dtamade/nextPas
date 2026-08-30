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
  SysUtils,
  nextpas.core.net.cancel;

type
  PAsyncNetCancelCtx = ^TAsyncNetCancelCtx;
  TAsyncNetCancelCtx = record
    Net: INetCancelController;
  end;

procedure AsyncNetCancelBridgeFire(AContext: Pointer);
var
  LCtx: PAsyncNetCancelCtx;
begin
  LCtx := PAsyncNetCancelCtx(AContext);
  if LCtx = nil then
    Exit;
  if LCtx^.Net <> nil then
  begin
    LCtx^.Net.Cancel;
    LCtx^.Net := nil;
  end;
  Dispose(LCtx);
end;

function NetCancelFromAsync(
  const AAsync: IAsyncCancellationToken): INetCancelController;
var
  LCtx: PAsyncNetCancelCtx;
begin
  Result := nil;
  if AAsync = nil then
    Exit;

  Result := NewNetCancelToken;
  New(LCtx);
  LCtx^ := Default(TAsyncNetCancelCtx);
  LCtx^.Net := Result;

  { OnCancel fires immediately if already cancelled (and does not retain ctx).
    Otherwise retains ctx until Cancel; Fire disposes ctx. }
  AAsync.OnCancel(@AsyncNetCancelBridgeFire, LCtx);

  if AAsync.IsCancelled and (Result <> nil) then
    Result.Cancel;
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
