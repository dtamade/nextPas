program test_net_async_pool;

{$I nextpas.core.settings.inc}

uses nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.async.pool,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.dial,
  nextpas.core.async.loop;

var
  T: TTestSuite;
  GLoop: TAsyncLoop;
  GDone: Boolean;
  GStream: ITcpStream;
  GError: Int32;
  GCalls: Integer;

procedure StopCb(AContext: Pointer);
begin
  GLoop.Stop;
end;

procedure OnAcquire(AStream: ITcpStream; AError: Int32; AContext: Pointer);
begin
  Inc(GCalls);
  GStream := AStream;
  GError := AError;
  GDone := True;
  GLoop.Stop;
end;

procedure TestAcquireAsyncDial;
var
  LPool: IConnectionPool;
  LListener: IAsyncTcpListener;
  LPort: UInt16;
  LCfg: TConnectionPoolConfig;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCalls := 0;
    GStream := nil;
    GError := -1;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LCfg := TConnectionPoolConfig.Default;
    LCfg.ConnectTimeout := TDuration.FromSeconds(2);
    LPool := CreateConnectionPool(GLoop, LCfg);
    Check(LPool.AcquireAsync('127.0.0.1', LPort, @OnAcquire, nil), 'submit');
    GLoop.Schedule(TDuration.FromMilliseconds(3000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'callback');
    CheckEqual(Int64(1), Int64(GCalls), 'once');
    Check(GStream <> nil, 'stream');
    CheckEqual(Int64(0), Int64(GError), 'ok');
    LPool.Release(GStream);
    CheckEqual(Int64(1), Int64(LPool.IdleCount), 'idle after release');
    GStream := nil;
    LListener := nil;
    LPool.Close;
  finally
    GLoop.Free;
  end;
end;

procedure TestAcquireAsyncReuseIdle;
var
  LPool: IConnectionPool;
  LListener: IAsyncTcpListener;
  LPort: UInt16;
  LFirst: ITcpStream;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCalls := 0;
    GStream := nil;
    GError := -1;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LPool := CreateConnectionPool(GLoop);
    Check(LPool.AcquireAsync('127.0.0.1', LPort, @OnAcquire, nil), 'first submit');
    GLoop.Schedule(TDuration.FromMilliseconds(3000), @StopCb, nil);
    GLoop.Run;
    Check(GStream <> nil, 'first stream');
    LFirst := GStream;
    LPool.Release(GStream);
    GStream := nil;
    GDone := False;
    GCalls := 0;
    Check(LPool.AcquireAsync('127.0.0.1', LPort, @OnAcquire, nil), 'second submit');
    GLoop.Schedule(TDuration.FromMilliseconds(1000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'idle callback');
    Check(GStream <> nil, 'reused stream');
    CheckEqual(Int64(0), Int64(GError), 'reuse ok');
    { Same connection object preferred when idle hit }
    Check(GStream = LFirst, 'idle reuse same stream');
    LPool.Discard(GStream);
    GStream := nil;
    LFirst := nil;
    LListener := nil;
    LPool.Close;
  finally
    GLoop.Free;
  end;
end;

procedure TestAcquireAsyncMaxConnections;
var
  LPool: IConnectionPool;
  LCfg: TConnectionPoolConfig;
begin
  GLoop := TAsyncLoop.Create(16);
  try
    GDone := False;
    GCalls := 0;
    GStream := nil;
    GError := 0;
    LCfg := TConnectionPoolConfig.Default;
    LCfg.MaxConnections := 0; { will treat as 0 max → immediate fail after idle miss }
    { MaxConnections 0: after idle miss, FActiveCount(0) >= 0 → fail }
    LPool := CreateConnectionPool(GLoop, LCfg);
    Check(LPool.AcquireAsync('127.0.0.1', 1, @OnAcquire, nil), 'max submit');
    GLoop.Schedule(TDuration.FromMilliseconds(500), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'max callback');
    Check(GStream = nil, 'no stream');
    Check(GError <> 0, 'error');
    LPool.Close;
  finally
    GLoop.Free;
  end;
end;

procedure TestAcquireAsyncExDialOptions;
var
  LPool: IConnectionPool;
  LListener: IAsyncTcpListener;
  LPort: UInt16;
  LCfg: TConnectionPoolConfig;
  LOpts: TAsyncTcpDialOptions;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCalls := 0;
    GStream := nil;
    GError := -1;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LCfg := TConnectionPoolConfig.Default;
    LCfg.ConnectTimeout := TDuration.FromSeconds(2);
    LPool := CreateConnectionPool(GLoop, LCfg);
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 0;
    LOpts.MaxInFlight := 1;
    LOpts.NoDelay := True;
    LOpts.KeepAlive := True;
    LOpts.LocalAddr := TNetAddress.IPv4('127.0.0.1', 0);
    Check(LPool.AcquireAsyncEx('127.0.0.1', LPort, LOpts, @OnAcquire, nil),
      'ex submit');
    GLoop.Schedule(TDuration.FromMilliseconds(3000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'ex callback');
    CheckEqual(Int64(0), Int64(GError), 'ex ok');
    Check(GStream <> nil, 'ex stream');
    CheckEqual(GStream.LocalAddr.IP, '127.0.0.1', 'ex local bind');
    LPool.Discard(GStream);
    GStream := nil;
    LListener.Close;
    LPool.Close;
  finally
    GLoop.Free;
  end;
end;

begin
  T := TTestSuite.Create('net_async_pool');
  T.Test('AcquireAsyncDial', @TestAcquireAsyncDial);
  T.Test('AcquireAsyncReuseIdle', @TestAcquireAsyncReuseIdle);
  T.Test('AcquireAsyncMaxConnections', @TestAcquireAsyncMaxConnections);
  T.Test('AcquireAsyncExDialOptions', @TestAcquireAsyncExDialOptions);
  if not T.Run then
    Halt(1);
end.
