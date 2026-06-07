program test_poller_windows_compile_gate;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.async.loop,
  nextpas.core.io.poller,
  nextpas.core.time.deadline
  {$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.io.reactor.iocp
  {$ENDIF}
  ;

procedure TouchPoller;
var
  LPoller: TPoller;
begin
  LPoller := TPoller.Create(8);
  LPoller.Backend;
  LPoller.IsValid;
  LPoller.AsyncRead(0, nil, 0, 0, nil, nil);
  LPoller.AsyncWrite(0, nil, 0, 0, nil, nil);
  LPoller.AsyncAccept(0, nil, nil, 0, nil, nil);
  LPoller.AsyncConnect(0, nil, 0, nil, nil);
  LPoller.AsyncSend(0, nil, 0, 0, nil, nil);
  LPoller.AsyncRecv(0, nil, 0, 0, nil, nil);
  LPoller.AsyncClose(0, nil, nil);
  LPoller.Flush;
  LPoller.Poll;
  LPoller.PollOne;
  LPoller.Stop;
  LPoller.Close;
end;

procedure TouchAsyncLoopTimeouts;
var
  LLoop: TAsyncLoop;
  LDeadline: TDeadline;
begin
  LLoop := TAsyncLoop.Create(8);
  LDeadline := TDeadline.Infinite;
  LLoop.IsValid;
  LLoop.AsyncReadTimeout(0, nil, 0, 0, LDeadline, nil, nil);
  LLoop.AsyncWriteTimeout(0, nil, 0, 0, LDeadline, nil, nil);
  LLoop.AsyncRecvTimeout(0, nil, 0, 0, LDeadline, nil, nil);
  LLoop.AsyncSendTimeout(0, nil, 0, 0, LDeadline, nil, nil);
  LLoop.Stop;
  LLoop.Close;
end;

begin
  TouchPoller;
  TouchAsyncLoopTimeouts;
end.
