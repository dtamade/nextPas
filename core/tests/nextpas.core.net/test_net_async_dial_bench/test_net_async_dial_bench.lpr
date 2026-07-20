program test_net_async_dial_bench;

{$I nextpas.core.settings.inc}

{ Localhost dial throughput microbench (HE path).
  metric=dial_ops_per_s — sequential AsyncTcpDial to a local listener.
  truth=same-host-order-of-magnitude; not public DNS / HE dual-stack race. }

uses
  cthreads,
  SysUtils,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.time.cpu,
  nextpas.core.net.base,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.dial,
  nextpas.core.async.loop;

var
  T: TTestSuite;
  GLoop: TAsyncLoop;
  GDone: Boolean;
  GError: Int32;
  GStream: IAsyncTcpStream;
  GOk: Integer;

procedure OnDial(AStream: IAsyncTcpStream; AError: Int32; AContext: Pointer);
begin
  GStream := AStream;
  GError := AError;
  if (AError = 0) and (AStream <> nil) then
    Inc(GOk);
  GDone := True;
  GLoop.Stop;
end;

procedure StopCb(AContext: Pointer);
begin
  GLoop.Stop;
end;

function BenchDialOpsPerSec: Double;
var
  LListener: IAsyncTcpListener;
  LPort: UInt16;
  LOpts: TAsyncTcpDialOptions;
  LI, LCount: Integer;
  LStart, LElapsed: UInt64;
begin
  LCount := 200;
  GOk := 0;
  GLoop := TAsyncLoop.Create(64);
  try
    LListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    LPort := LListener.LocalAddr.Port;
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 0;
    LOpts.MaxInFlight := 1;
    LOpts.ResolutionDelayMs := 0;
    LStart := GetTickCount64;
    for LI := 1 to LCount do
    begin
      GDone := False;
      GError := -1;
      GStream := nil;
      if not AsyncTcpDial(GLoop, '127.0.0.1', LPort, LOpts, @OnDial, nil) then
        Continue;
      GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
      GLoop.Run;
      if GStream <> nil then
      begin
        GStream.Close;
        GStream := nil;
      end;
    end;
    LElapsed := GetTickCount64 - LStart;
    if LElapsed = 0 then
      LElapsed := 1;
    Result := (GOk * 1000.0) / LElapsed;
    LListener.Close;
  finally
    GLoop.Free;
  end;
end;

procedure TestDialThroughput;
var
  LOps: Double;
begin
  LOps := BenchDialOpsPerSec;
  WriteLn('metric=dial_ops_per_s value=', FormatFloat('0.0', LOps));
  WriteLn('truth=localhost-sequential-dial; not-public-dns-he-matrix');
  Check(LOps > 0, 'dial throughput > 0');
end;

begin
  T := TTestSuite.Create('net_async_dial_bench');
  T.Test('DialThroughput', @TestDialThroughput);
  if not T.Run then
    Halt(1);
end.
