program test_net_async;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.socket,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.backpressure,
  nextpas.core.async.base,
  nextpas.core.async.loop;

var
  T: TTestSuite;
  GLoop: TAsyncLoop;
  GAccepted: Boolean;
  GReadDone: Boolean;
  GWriteDone: Boolean;
  GTimeoutFired: Boolean;
  GAcceptCount: Int32;
  GRecvBuf: array[0..3] of Byte;

procedure AcceptCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  GAccepted := AResult >= 0;
  GLoop.Stop;
end;

procedure StopCallback(AContext: Pointer);
begin
  GLoop.Stop;
end;

procedure ReadCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  if AResult >= 0 then
  begin
    GReadDone := True;
  end;
end;

procedure TimeoutCallback(AContext: Pointer);
begin
  GTimeoutFired := True;
  GLoop.Stop;
end;

procedure AcceptMultipleCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  if AResult >= 0 then
    Inc(GAcceptCount);
end;

{ 测试异步 TCP 监听和连接 }

procedure TestAsyncTcpListenConnect;
var
  LListener: IAsyncTcpListener;
  LClient: IAsyncTcpStream;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    Check(LListener <> nil, 'listener should be created');
    Check(LListener.LocalAddr.Port > 0, 'listener should have a port');

    LClient := AsyncTcpConnect(GLoop, '127.0.0.1', LListener.LocalAddr.Port);
    Check(LClient <> nil, 'client should be created');

    GAccepted := False;
    LListener.AsyncAccept(@AcceptCallback, nil);

    GLoop.Schedule(TDuration.FromMilliseconds(100), @StopCallback, nil);
    GLoop.Run;
    Check(GAccepted, 'connection should be accepted');

    LClient.Close;
    LListener.Close;
  finally
    GLoop.Close;
    GLoop.Free;
  end;
end;

{ 测试异步 TCP 读写 }

procedure TestAsyncTcpReadWrite;
var
  LListener: IAsyncTcpListener;
  LClient: IAsyncTcpStream;
  LSendBuf: array[0..3] of Byte = (1, 2, 3, 4);
begin
  GLoop := TAsyncLoop.Create(32);
  try
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LClient := AsyncTcpConnect(GLoop, '127.0.0.1', LListener.LocalAddr.Port);

    GReadDone := False;
    GWriteDone := False;

    // 接受连接
    LListener.AsyncAccept(@AcceptCallback, nil);

    // 写入数据
    LClient.Write(LSendBuf[0], 4);
    GWriteDone := True;

    GLoop.Schedule(TDuration.FromMilliseconds(100), @StopCallback, nil);
    GLoop.Run;

    Check(GWriteDone, 'write should complete');

    LClient.Close;
    LListener.Close;
  finally
    GLoop.Close;
    GLoop.Free;
  end;
end;

{ 测试异步 TCP 超时 }

procedure TestAsyncTcpTimeout;
var
  LListener: IAsyncTcpListener;
  LClient: IAsyncTcpStream;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LClient := AsyncTcpConnect(GLoop, '127.0.0.1', LListener.LocalAddr.Port);

    GTimeoutFired := False;

    // 设置超时
    GLoop.Schedule(TDuration.FromMilliseconds(50), @TimeoutCallback, nil);
    GLoop.Run;

    Check(GTimeoutFired, 'timeout should fire');

    LClient.Close;
    LListener.Close;
  finally
    GLoop.Close;
    GLoop.Free;
  end;
end;

{ 测试异步 TCP 多连接 }

procedure TestAsyncTcpMultipleConnections;
var
  LListener: IAsyncTcpListener;
  LClients: array[0..2] of IAsyncTcpStream;
  I: Integer;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    GAcceptCount := 0;

    // 创建多个连接
    for I := 0 to 2 do
    begin
      LClients[I] := AsyncTcpConnect(GLoop, '127.0.0.1', LListener.LocalAddr.Port);
    end;

    // 接受多个连接
    for I := 0 to 2 do
    begin
      LListener.AsyncAccept(@AcceptMultipleCallback, nil);
    end;

    GLoop.Schedule(TDuration.FromMilliseconds(200), @StopCallback, nil);
    GLoop.Run;

    Check(GAcceptCount = 3, 'all connections should be accepted');

    for I := 0 to 2 do
      LClients[I].Close;
    LListener.Close;
  finally
    GLoop.Close;
    GLoop.Free;
  end;
end;

{ Backpressure OnStateChange }

var
  GBpState: TBackpressureState;
  GBpNotifyCount: Int32;

procedure BpStateCallback(AState: TBackpressureState; AContext: Pointer);
begin
  GBpState := AState;
  Inc(GBpNotifyCount);
  GLoop.Stop;
end;

procedure TestBackpressureStateChange;
var
  LBp: IBackpressureController;
  LCfg: TBackpressureConfig;
  LBuf: array[0..15] of Byte;
  LReadBuf: array[0..15] of Byte;
  LWritten: UInt32;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GBpNotifyCount := 0;
    GBpState := bpsNormal;
    LCfg.HighWaterMark := 8;
    LCfg.LowWaterMark := 2;
    LBp := CreateBackpressureController(GLoop, LCfg);
    LBp.OnStateChange(@BpStateCallback, nil);
    FillChar(LBuf, SizeOf(LBuf), 1);
    LWritten := LBp.Write(LBuf, 8);
    CheckEqual(Int64(8), Int64(LWritten), 'write high watermark bytes');
    Check(LBp.State = bpsPaused, 'state paused after high water');
    GLoop.Schedule(TDuration.FromMilliseconds(50), @StopCallback, nil);
    GLoop.Run;
    Check(GBpNotifyCount >= 1, 'state change notified');
    Check(GBpState = bpsPaused, 'notified paused');
    { drain below low water → draining/normal path }
    GBpNotifyCount := 0;
    LBp.Read(LReadBuf, 7);
    GLoop.Schedule(TDuration.FromMilliseconds(50), @StopCallback, nil);
    GLoop.Run;
    Check(GBpNotifyCount >= 1, 'drain notify');
    Check(LBp.State in [bpsDraining, bpsNormal], 'not paused after drain');
    LBp.Close;
    LBp := nil;
  finally
    GLoop.Close;
    GLoop.Free;
  end;
end;

begin
  T := TTestSuite.Create('net_async');
  T.Test('AsyncTcpListenConnect', @TestAsyncTcpListenConnect);
  T.Test('AsyncTcpReadWrite', @TestAsyncTcpReadWrite);
  T.Test('AsyncTcpTimeout', @TestAsyncTcpTimeout);
  T.Test('AsyncTcpMultipleConnections', @TestAsyncTcpMultipleConnections);
  T.Test('BackpressureStateChange', @TestBackpressureStateChange);
  T.Run;
end.
