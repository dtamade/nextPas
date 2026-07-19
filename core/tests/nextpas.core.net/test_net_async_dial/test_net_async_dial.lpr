program test_net_async_dial;

{$I nextpas.core.settings.inc}

uses
  cthreads,
  SysUtils,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.net.base,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.dial,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.async.cancellation;

var
  T: TTestSuite;
  GLoop: TAsyncLoop;
  GDone: Boolean;
  GError: Int32;
  GStream: IAsyncTcpStream;
  GCallCount: Integer;

procedure OnDial(AStream: IAsyncTcpStream; AError: Int32; AContext: Pointer);
begin
  Inc(GCallCount);
  GStream := AStream;
  GError := AError;
  GDone := True;
  GLoop.Stop;
end;

procedure StopCb(AContext: Pointer);
begin
  GLoop.Stop;
end;

procedure TestDialLocalhostSuccess;
var
  LListener: IAsyncTcpListener;
  LOpts: TAsyncTcpDialOptions;
  LPort: UInt16;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := -1;
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 50;
    LOpts.MaxInFlight := 2;
    Check(AsyncTcpDial(GLoop, '127.0.0.1', LPort, LOpts, @OnDial, nil), 'dial submit');
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'dial callback');
    CheckEqual(Int64(1), Int64(GCallCount), 'single callback');
    Check(GStream <> nil, 'stream non-nil');
    CheckEqual(Int64(0), Int64(GError), 'error 0');
    GStream := nil;
    LListener := nil;
  finally
    GLoop.Free;
  end;
end;

procedure TestDialRefused;
var
  LOpts: TAsyncTcpDialOptions;
  LAddrs: array[0..0] of TNetAddress;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := 0;
    LAddrs[0] := TNetAddress.IPv4('127.0.0.1', 0);
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 20;
    Check(AsyncTcpDialAddrs(GLoop, LAddrs, 1, LOpts, @OnDial, nil), 'dial refused submit');
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'dial callback on refuse');
    CheckEqual(Int64(1), Int64(GCallCount), 'single callback');
    Check(GStream = nil, 'stream nil on refuse');
    Check(GError <> 0, 'error non-zero');
  finally
    GLoop.Free;
  end;
end;

procedure TestDialTokenCancel;
var
  LOpts: TAsyncTcpDialOptions;
  LToken: IAsyncCancellationToken;
  LAddrs: array[0..0] of TNetAddress;
begin
  GLoop := TAsyncLoop.Create(32);
  LToken := CreateCancellationToken;
  try
    GDone := False;
    GCallCount := 0;
    GStream := nil;
    GError := 0;
    { Blackhole-ish: connect to TEST-NET that may hang or fail; cancel quickly }
    LAddrs[0] := TNetAddress.IPv4('172.16.0.1', 0);
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.Token := LToken;
    LOpts.ConnectionAttemptDelayMs := 500;
    LOpts.OverallDeadline := TDeadline.After(TDuration.FromMilliseconds(3000));
    Check(AsyncTcpDialAddrs(GLoop, LAddrs, 9, LOpts, @OnDial, nil), 'dial cancel submit');
    LToken.Cancel;
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'cancel completes');
    CheckEqual(Int64(1), Int64(GCallCount), 'single callback');
    Check(GStream = nil, 'nil stream');
    CheckEqual(Int64(-125), Int64(GError), 'ECANCELED');
  finally
    LToken := nil;
    GLoop.Free;
  end;
end;

begin
  T := TTestSuite.Create('net_async_dial');
  T.Test('DialLocalhostSuccess', @TestDialLocalhostSuccess);
  T.Test('DialRefused', @TestDialRefused);
  T.Test('DialTokenCancel', @TestDialTokenCancel);
  if not T.Run then
    Halt(1);
end.
