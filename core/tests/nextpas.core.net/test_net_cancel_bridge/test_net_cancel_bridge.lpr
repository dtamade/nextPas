program test_net_cancel_bridge;

{$I nextpas.core.settings.inc}

uses nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.async.cancellation,
  nextpas.core.net.intf,
  nextpas.core.net.cancel,
  nextpas.core.net.async.cancel,
  nextpas.core.net.async.tcp,
  nextpas.core.net.tcp,
  nextpas.core.net,
  nextpas.core.async.loop,
  nextpas.core.exception,
  nextpas.core.platform.thread,
  nextpas.core.time.cpu;

var
  T: TTestSuite;
  GAsyncToken: IAsyncCancellationToken;
  GThreadHandle: TPlatformThreadHandle;

procedure TestAsyncCancelPropagatesToNet;
var
  LAsync: IAsyncCancellationToken;
  LNet: INetCancelController;
begin
  LAsync := CreateCancellationToken;
  LNet := NetCancelFromAsync(LAsync);
  Check(LNet <> nil, 'net from async');
  Check(not LNet.IsCanceled, 'not canceled yet');
  LAsync.Cancel;
  Check(LNet.IsCanceled, 'async cancel propagates to net');
end;

procedure TestAlreadyCancelledBindsNetCanceled;
var
  LAsync: IAsyncCancellationToken;
  LNet: INetCancelController;
begin
  LAsync := CreateCancellationToken;
  LAsync.Cancel;
  LNet := NetCancelFromAsync(LAsync);
  Check(LNet <> nil, 'net non-nil');
  Check(LNet.IsCanceled, 'already cancelled async → net canceled');
end;

procedure TestWaitableWakePresentOnUnix;
var
  LAsync: IAsyncCancellationToken;
  LNet: INetCancelController;
  LWait: INetCancelWaitable;
begin
  LAsync := CreateCancellationToken;
  LNet := NetCancelFromAsync(LAsync);
  Check(LNet.QueryInterface(INetCancelWaitable, LWait) = 0, 'waitable QI');
  Check(LWait.WakeHandle <> 0, 'wake handle on Linux');
  LAsync.Cancel; { free bridge ctx }
end;

procedure TestNilAsyncReturnsNil;
begin
  Check(NetCancelFromAsync(nil) = nil, 'nil async → nil net');
end;

function StreamCancelThread(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  platform_thread_sleep_ns(30000000); { 30ms }
  if GAsyncToken <> nil then
    GAsyncToken.Cancel;
end;

procedure TestStreamBindAsyncCancelRead;
var
  LListener: ITcpListener;
  LClient: ITcpStream;
  LBuf: array[0..31] of Byte;
  LGot: Boolean;
  LRet: Pointer;
  LWait: INetCancelWaitable;
  LNet: INetCancelController;
begin
  GAsyncToken := CreateCancellationToken;
  LNet := NetCancelFromAsync(GAsyncToken);
  Check(LNet.QueryInterface(INetCancelWaitable, LWait) = 0, 'stream test waitable');
  if LWait.WakeHandle = 0 then
  begin
    GAsyncToken := nil;
    Exit;
  end;

  LListener := TcpListen('127.0.0.1', 0);
  LClient := TcpConnect('127.0.0.1', LListener.LocalAddr.Port);
  TcpStreamBindAsyncCancel(LClient, GAsyncToken);
  platform_thread_create(GThreadHandle, @StreamCancelThread, nil);
  LGot := False;
  try
    LClient.Read(LBuf[0], 32);
  except
    on E: ECancelledError do
      LGot := True;
  end;
  platform_thread_join(GThreadHandle, LRet);
  Check(LGot, 'bind async cancel raises ECancelledError on read');
  LClient.Close;
  LListener.Close;
  GAsyncToken := nil;
end;

procedure TestAsyncTcpStreamBindCancelToken;
var
  LLoop: TAsyncLoop;
  LListener: IAsyncTcpListener;
  LClient: IAsyncTcpStream;
  LAsync: IAsyncCancellationToken;
  LNet: INetCancelController;
  LWait: INetCancelWaitable;
begin
  LLoop := TAsyncLoop.Create(16);
  try
    LListener := AsyncTcpListen(LLoop, '127.0.0.1', 0);
    LClient := AsyncTcpConnect(LLoop, '127.0.0.1', LListener.LocalAddr.Port);
    LAsync := CreateCancellationToken;
    LClient.BindCancelToken(LAsync);
    LNet := NetCancelFromAsync(LAsync);
    { Bind already installed a bridge; second bridge also works on same async. }
    Check(LNet <> nil, 'second bridge ok');
    LAsync.Cancel;
    Check(LNet.IsCanceled, 'async cancel after BindCancelToken');
    LClient.Close;
    LListener.Close;
  finally
    LLoop.Free;
  end;
end;

begin
  T := TTestSuite.Create('net_cancel_bridge');
  T.Test('AsyncCancelPropagatesToNet', @TestAsyncCancelPropagatesToNet);
  T.Test('AlreadyCancelledBindsNetCanceled', @TestAlreadyCancelledBindsNetCanceled);
  T.Test('WaitableWakePresentOnUnix', @TestWaitableWakePresentOnUnix);
  T.Test('NilAsyncReturnsNil', @TestNilAsyncReturnsNil);
  T.Test('StreamBindAsyncCancelRead', @TestStreamBindAsyncCancelRead);
  T.Test('AsyncTcpStreamBindCancelToken', @TestAsyncTcpStreamBindCancelToken);
  if not T.Run then
    Halt(1);
end.
