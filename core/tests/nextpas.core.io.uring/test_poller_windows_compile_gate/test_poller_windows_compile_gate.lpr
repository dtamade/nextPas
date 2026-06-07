program test_poller_windows_compile_gate;

{ Source-contract and forced-compile only; not Windows runtime evidence. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.async.loop,
  nextpas.core.io.poller,
  nextpas.core.time.base,
  nextpas.core.time.deadline
  {$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.io.reactor.iocp
  {$ENDIF}
  ;

procedure NoopIoCompletion(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
end;

procedure TouchIocpReactorFileSurface;
{$IFDEF NEXTPAS_WINDOWS}
var
  LIocp: TIocpReactor;
begin
  LIocp := TIocpReactor.Create(8);
  LIocp.IsValid;
  LIocp.AsyncRead(0, nil, 0, 0, @NoopIoCompletion, nil);
  LIocp.AsyncWrite(0, nil, 0, 0, @NoopIoCompletion, nil);
  LIocp.Flush;
  LIocp.Poll;
  LIocp.PollOne;
  LIocp.Stop;
  LIocp.Close;
end;
{$ELSE}
begin
end;
{$ENDIF}

procedure TouchPollerFileSurface;
var
  LPoller: TPoller;
begin
  LPoller := TPoller.Create(8);
  LPoller.Backend;
  LPoller.IsValid;
  LPoller.AsyncRead(0, nil, 0, 0, @NoopIoCompletion, nil);
  LPoller.AsyncWrite(0, nil, 0, 0, @NoopIoCompletion, nil);
  LPoller.Flush;
  LPoller.Poll;
  LPoller.PollOne;
  LPoller.Stop;
  LPoller.Close;
end;

procedure TouchPollerUnsupportedSurface;
var
  LPoller: TPoller;
begin
  LPoller := TPoller.Create(8);
  LPoller.AsyncAccept(0, nil, nil, 0, nil, nil);
  LPoller.AsyncConnect(0, nil, 0, nil, nil);
  LPoller.AsyncSend(0, nil, 0, 0, nil, nil);
  LPoller.AsyncRecv(0, nil, 0, 0, nil, nil);
  LPoller.AsyncClose(0, nil, nil);
  LPoller.Close;
end;

procedure TouchAsyncLoopFileSurface;
var
  LLoop: TAsyncLoop;
begin
  LLoop := TAsyncLoop.Create(8);
  LLoop.IsValid;
  LLoop.AsyncRead(0, nil, 0, 0, @NoopIoCompletion, nil);
  LLoop.AsyncWrite(0, nil, 0, 0, @NoopIoCompletion, nil);
  LLoop.Poll;
  LLoop.RunOnce;
  LLoop.Close;
end;

procedure TouchAsyncLoopUnsupportedSurface;
var
  LLoop: TAsyncLoop;
begin
  LLoop := TAsyncLoop.Create(8);
  LLoop.AsyncAccept(0, nil, nil, 0, @NoopIoCompletion, nil);
  LLoop.AsyncRecv(0, nil, 0, 0, @NoopIoCompletion, nil);
  LLoop.AsyncSend(0, nil, 0, 0, @NoopIoCompletion, nil);
  LLoop.Close;
end;

procedure TouchAsyncLoopFileTimeouts;
var
  LLoop: TAsyncLoop;
  LDeadline: TDeadline;
begin
  LLoop := TAsyncLoop.Create(8);
  LDeadline := TDeadline.After(TDuration.FromMilliseconds(1));
  LLoop.IsValid;
  LLoop.AsyncReadTimeout(0, nil, 0, 0, LDeadline, nil, nil);
  LLoop.AsyncWriteTimeout(0, nil, 0, 0, LDeadline, nil, nil);
  LLoop.Close;
end;

procedure TouchAsyncLoopUnsupportedTimeouts;
var
  LLoop: TAsyncLoop;
  LDeadline: TDeadline;
begin
  LLoop := TAsyncLoop.Create(8);
  LDeadline := TDeadline.After(TDuration.FromMilliseconds(1));
  LLoop.AsyncRecvTimeout(0, nil, 0, 0, LDeadline, nil, nil);
  LLoop.AsyncSendTimeout(0, nil, 0, 0, LDeadline, nil, nil);
  LLoop.Stop;
  LLoop.Close;
end;

procedure TouchCompileGate;
begin
  TouchIocpReactorFileSurface;
  TouchPollerFileSurface;
  TouchPollerUnsupportedSurface;
  TouchAsyncLoopFileSurface;
  TouchAsyncLoopUnsupportedSurface;
  TouchAsyncLoopFileTimeouts;
  TouchAsyncLoopUnsupportedTimeouts;
end;

begin
  TouchCompileGate;
end.
