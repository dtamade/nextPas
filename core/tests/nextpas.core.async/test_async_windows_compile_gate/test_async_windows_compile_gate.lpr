program test_async_windows_compile_gate;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.async,
  nextpas.core.time.base,
  nextpas.core.time.deadline;

procedure NoopIoCompletion(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
end;

procedure NoopAsyncCallback(AContext: Pointer);
begin
end;

procedure TouchAsyncFacade;
var
  LLoop: TAsyncLoop;
  LCompletion: TIoCompletion;
  LCallback: TAsyncCallback;
  LDeadline: TDeadline;
  LHandle: TAsyncTimerHandle;
begin
  { source-contract and forced-compile only; not windows runtime evidence }
  LCompletion := @NoopIoCompletion;
  LCallback := @NoopAsyncCallback;
  LLoop := TAsyncLoop.Create(8);
  LDeadline := TDeadline.After(TDuration.FromMilliseconds(1));
  LHandle := LLoop.AsyncSleep(TDuration.Zero, LCallback, nil);
  LHandle.IsValid;
  LLoop.AsyncRead(0, nil, 0, 0, LCompletion, nil);
  LLoop.AsyncWrite(0, nil, 0, 0, LCompletion, nil);
  LLoop.AsyncReadTimeout(0, nil, 0, 0, LDeadline, LCompletion, nil);
  LLoop.AsyncWriteTimeout(0, nil, 0, 0, LDeadline, LCompletion, nil);
  LLoop.AsyncAccept(0, nil, nil, 0, LCompletion, nil);
  LLoop.AsyncRecv(0, nil, 0, 0, LCompletion, nil);
  LLoop.AsyncSend(0, nil, 0, 0, LCompletion, nil);
  LLoop.Poll;
  LLoop.RunOnce;
  LLoop.Stop;
  LLoop.Close;
end;

begin
  TouchAsyncFacade;
end.
