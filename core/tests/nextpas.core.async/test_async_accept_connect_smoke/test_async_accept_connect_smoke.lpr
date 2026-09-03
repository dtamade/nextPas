program test_async_accept_connect_smoke;

{$I nextpas.core.settings.inc}

{ Cross-host readiness/completion accept+connect smoke via TAsyncLoop.
  Linux: epoll or io_uring. Darwin/FreeBSD: kqueue. Windows: skip. }

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.async.loop,
  nextpas.core.io.poller,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.dial,
  nextpas.core.net.base;

var
  T: TTestSuite;
  GLoop: TAsyncLoop;
  GDone: Boolean;
  GError: Int32;
  GStream: IAsyncTcpStream;
  GBackend: string;

procedure StopCb(AContext: Pointer);
begin
  GLoop.Stop;
end;

procedure OnDial(AStream: IAsyncTcpStream; AError: Int32; AContext: Pointer);
begin
  GStream := AStream;
  GError := AError;
  GDone := True;
  GLoop.Stop;
end;

procedure AcceptTimeoutCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GStream := nil;
  GError := AResult;
  GDone := True;
  GLoop.Stop;
end;

procedure TestAcceptConnectLoopback;
var
  LListener: IAsyncTcpListener;
  LPort: UInt16;
  LOpts: TAsyncTcpDialOptions;
  LPoller: TPoller;
begin
{$IFDEF NEXTPAS_WINDOWS}
  WriteLn('accept-connect-smoke=skip truth=windows-use-wine-iocp');
  Exit;
{$ENDIF}
  GLoop := TAsyncLoop.Create(32);
  try
    LPoller := TPoller.Create(8);
    try
      case LPoller.Backend of
        pbIoUring: GBackend := 'io_uring';
        pbEpoll: GBackend := 'epoll';
        pbKqueue: GBackend := 'kqueue';
        pbIocp: GBackend := 'iocp';
      else
        GBackend := 'unsupported';
      end;
    finally
      LPoller.Close;
    end;

    GDone := False;
    GError := -1;
    GStream := nil;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 20;
    Check(AsyncTcpDial(GLoop, '127.0.0.1', LPort, LOpts, @OnDial, nil), 'dial submit');
    GLoop.Schedule(TDuration.FromMilliseconds(3000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'dial completed');
    CheckEqual(Int64(0), Int64(GError), 'dial error 0');
    Check(GStream <> nil, 'stream non-nil');
    GStream.Close;
    GStream := nil;
    LListener.Close;
    WriteLn('accept-connect-smoke=pass backend=', GBackend);
  finally
    GLoop.Free;
  end;
end;

procedure TestAcceptTimeoutLoopback;
var
  LListener: IAsyncTcpListener;
begin
{$IFDEF NEXTPAS_WINDOWS}
  WriteLn('accept-timeout-smoke=skip truth=windows-use-wine-iocp');
  Exit;
{$ENDIF}
  { AsyncAcceptTimeout with a short deadline and no client -> timeout callback. }
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GError := -9999;
    GStream := nil;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    Check(LListener.AsyncAcceptTimeout(TDeadline.After(TDuration.FromMilliseconds(80)),
      @AcceptTimeoutCb, nil), 'AsyncAcceptTimeout submit');
    GLoop.Schedule(TDuration.FromMilliseconds(1500), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'accept deadline fired');
    Check(GError < 0, 'accept deadline result < 0');
    LListener.Close;
    WriteLn('accept-timeout-smoke=pass');
  finally
    GLoop.Free;
  end;
end;

begin
  T := TTestSuite.Create('async_accept_connect_smoke');
  T.Test('AcceptConnectLoopback', @TestAcceptConnectLoopback);
  T.Test('AcceptTimeoutLoopback', @TestAcceptTimeoutLoopback);
  if not T.Run then
    Halt(1);
end.
