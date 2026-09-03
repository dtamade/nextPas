program test_async_kqueue_runtime_smoke;

{$I nextpas.core.settings.inc}

{ Host-runtime kqueue smoke when built for real Darwin/FreeBSD.
  Q17: Create/Poll + accept/connect loopback when host is kqueue.
  On Linux and other hosts: skip (exit 0) — not a failure.
  FORCE_HOST compile path is covered by test_async_kqueue_compile_gate. }

uses
  nextpas.core.thread.init,
  nextpas.core.io.poller,
  nextpas.core.io.base,
  nextpas.core.time.base,
  nextpas.core.async.loop,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.dial,
  nextpas.core.net.base;

procedure NoopIo(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
end;

{$IF DEFINED(NEXTPAS_MACOS) OR DEFINED(NEXTPAS_FREEBSD)}
var
  LPoller: TPoller;
  LCompletion: TIoCompletion;
  GLoop: TAsyncLoop;
  GDone: Boolean;
  GError: Int32;
  GStream: IAsyncTcpStream;
  LListener: IAsyncTcpListener;
  LPort: UInt16;
  LOpts: TAsyncTcpDialOptions;

procedure OnDial(AStream: IAsyncTcpStream; AError: Int32; AContext: Pointer);
begin
  GStream := AStream;
  GError := AError;
  GDone := True;
  GLoop.Stop;
end;

procedure StopCb(AContext: Pointer);
begin
  GLoop.Stop;
end;
{$ENDIF}

begin
{$IF DEFINED(NEXTPAS_MACOS) OR DEFINED(NEXTPAS_FREEBSD)}
  LCompletion := @NoopIo;
  if PollerBackendModel(pbKqueue) <> pbmReadiness then
    Halt(2);
  LPoller := TPoller.Create(8);
  if not LPoller.IsValid then
    Halt(3);
  if LPoller.Backend <> pbKqueue then
    Halt(4);
  LPoller.HasPending;
  LPoller.Flush;
  LPoller.Poll;
  LPoller.TryCancelByContext(Pointer(1));
  LPoller.Close;

  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GError := -1;
    GStream := nil;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 20;
    if not AsyncTcpDial(GLoop, '127.0.0.1', LPort, LOpts, @OnDial, nil) then
      Halt(5);
    GLoop.Schedule(TDuration.FromMilliseconds(3000), @StopCb, nil);
    GLoop.Run;
    if not GDone then
      Halt(6);
    if (GError <> 0) or (GStream = nil) then
      Halt(7);
    GStream.Close;
    GStream := nil;
    LListener.Close;
    LListener := nil;
  finally
    GLoop.Free;
  end;

  WriteLn('kqueue-runtime-smoke=pass truth=host-runtime');
  WriteLn('kqueue-accept-connect-smoke=pass');
{$ELSE}
  WriteLn('kqueue-runtime-smoke=skip truth=not-darwin-freebsd-host');
  WriteLn('kqueue-accept-connect-smoke=skip');
{$ENDIF}
end.
