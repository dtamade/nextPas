program test_async_kqueue_runtime_smoke;

{$I nextpas.core.settings.inc}

{ Host-runtime kqueue smoke when built for real Darwin/FreeBSD.
  On Linux and other hosts: skip (exit 0) — not a failure.
  FORCE_HOST compile path is covered by test_async_kqueue_compile_gate. }

uses
  nextpas.core.io.poller,
  nextpas.core.io.base;

procedure NoopIo(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
end;

{$IF DEFINED(NEXTPAS_MACOS) OR DEFINED(NEXTPAS_FREEBSD)}
var
  LPoller: TPoller;
  LCompletion: TIoCompletion;
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
  WriteLn('kqueue-runtime-smoke=pass truth=host-runtime');
{$ELSE}
  WriteLn('kqueue-runtime-smoke=skip truth=not-darwin-freebsd-host');
{$ENDIF}
end.
