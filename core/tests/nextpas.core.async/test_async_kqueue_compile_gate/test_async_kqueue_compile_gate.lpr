program test_async_kqueue_compile_gate;

{$I nextpas.core.settings.inc}

{ Forced-compile only: proves TPoller + TKqueueReactor compile under
  NEXTPAS_FORCE_HOST_DARWIN. Not host-runtime evidence.
  FreeBSD FORCE_HOST currently blocked by platform.thread pthread_timedjoin_np typing. }

uses
  nextpas.core.io.poller,
  nextpas.core.io.base;

procedure NoopIo(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
end;

procedure TouchKqueuePath;
var
  LPoller: TPoller;
  LCompletion: TIoCompletion;
begin
  LCompletion := @NoopIo;
  if PollerBackendModel(pbKqueue) <> pbmReadiness then
    Halt(2);
  if PollerSupportsPositionedFileIO(pbKqueue) then
    Halt(3);
  LPoller := TPoller.Create(8);
  if LPoller.IsValid then
  begin
    if LPoller.Backend <> pbKqueue then
      Halt(4);
    LPoller.AsyncRead(0, nil, 0, -1, LCompletion, nil);
    LPoller.AsyncWrite(0, nil, 0, -1, LCompletion, nil);
    LPoller.AsyncRecv(0, nil, 0, 0, LCompletion, nil);
    LPoller.AsyncSend(0, nil, 0, 0, LCompletion, nil);
    LPoller.TryCancelByContext(Pointer(1));
    LPoller.HasPending;
    LPoller.Flush;
    LPoller.Poll;
    LPoller.Close;
  end;
end;

begin
  TouchKqueuePath;
end.
