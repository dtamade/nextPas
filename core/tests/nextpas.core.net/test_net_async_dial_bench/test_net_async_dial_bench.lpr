program test_net_async_dial_bench;

{$I nextpas.core.settings.inc}

{ Localhost dial throughput microbench (HE path).
  metric=dial_ops_per_s — sequential AsyncTcpDialAddrs (one Run per dial).
  metric=dial_concurrent_ops_per_s — single Run, W in-flight DialAddrs.
  Accept queue is drained with nonblocking TryAccept so backlog does not fill.
  truth=localhost-*; not public DNS HE matrix. }

uses nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.time.cpu,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.async.tcp,
  nextpas.core.net.async.dial,
  nextpas.core.async.loop, nextpas.core.base.utils, nextpas.core.text.conv;

const
  DIAL_SEQ_COUNT = 200;
  DIAL_CONC_COUNT = 400;
  DIAL_CONC_INFLIGHT = 8;

var
  T: TTestSuite;
  GLoop: TAsyncLoop;
  GStream: IAsyncTcpStream;
  GOk: Integer;
  GListener: IAsyncTcpListener;
  GConcOk: Integer;
  GConcFail: Integer;
  GConcDone: Integer;
  GConcTarget: Integer;
  GConcInflight: Integer;
  GConcMaxInflight: Integer;
  GConcOpts: TAsyncTcpDialOptions;
  GConcAddrs: array[0..0] of TNetAddress;

procedure DrainAccepts(const AListener: IAsyncTcpListener);
var
  LConn: ITcpStream;
  LRes: TTcpAcceptResult;
  LRuntime: ITcpListenerRuntime;
begin
  if AListener = nil then
    Exit;
  if not Supports(AListener, ITcpListenerRuntime, LRuntime) then
    Exit;
  repeat
    LRes := LRuntime.TryAccept(LConn);
    if LRes = tarAccepted then
    begin
      if LConn <> nil then
        LConn.Close;
      LConn := nil;
    end;
  until LRes <> tarAccepted;
end;

procedure MakeListenerNonBlocking(const AListener: IAsyncTcpListener);
var
  LSock: ITcpSocketRuntime;
begin
  if Supports(AListener, ITcpSocketRuntime, LSock) then
    LSock.SetBlocking(False);
end;

procedure StopCb(AContext: Pointer);
begin
  GLoop.Stop;
end;

procedure OnDialSeq(AStream: IAsyncTcpStream; AError: Int32; AContext: Pointer);
begin
  GStream := AStream;
  if (AError = 0) and (AStream <> nil) then
    Inc(GOk);
  DrainAccepts(GListener);
  GLoop.Stop;
end;

function BenchDialOpsPerSec: Double;
var
  LPort: UInt16;
  LOpts: TAsyncTcpDialOptions;
  LAddrs: array[0..0] of TNetAddress;
  LI: Integer;
  LStart, LElapsed: UInt64;
begin
  GOk := 0;
  GLoop := TAsyncLoop.Create(64);
  try
    GListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    MakeListenerNonBlocking(GListener);
    LPort := GListener.LocalAddr.Port;
    LAddrs[0] := TNetAddress.IPv4('127.0.0.1', LPort);
    LOpts := DefaultAsyncTcpDialOptions;
    LOpts.ConnectionAttemptDelayMs := 0;
    LOpts.MaxInFlight := 1;
    LStart := GetTickCount64;
    for LI := 1 to DIAL_SEQ_COUNT do
    begin
      GStream := nil;
      if not AsyncTcpDialAddrs(GLoop, LAddrs, 0, LOpts, @OnDialSeq, nil) then
        Continue;
      { Safety timeout each Run; prior Stop leaves timers but dial completes first. }
      GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
      GLoop.Run;
      if GStream <> nil then
      begin
        GStream.Close;
        GStream := nil;
      end;
      DrainAccepts(GListener);
    end;
    LElapsed := GetTickCount64 - LStart;
    if LElapsed = 0 then
      LElapsed := 1;
    Result := (GOk * 1000.0) / LElapsed;
    GListener.Close;
    GListener := nil;
  finally
    GLoop.Free;
  end;
end;

procedure ConcMaybeStart; forward;

procedure OnDialConc(AStream: IAsyncTcpStream; AError: Int32; AContext: Pointer);
begin
  if GConcInflight > 0 then
    Dec(GConcInflight);
  Inc(GConcDone);
  if (AError = 0) and (AStream <> nil) then
  begin
    Inc(GConcOk);
    AStream.Close;
  end
  else
    Inc(GConcFail);
  DrainAccepts(GListener);
  if GConcDone >= GConcTarget then
    GLoop.Stop
  else
    ConcMaybeStart;
end;

procedure ConcMaybeStart;
begin
  while (GConcInflight < GConcMaxInflight) and
        (GConcDone + GConcInflight < GConcTarget) do
  begin
    if AsyncTcpDialAddrs(GLoop, GConcAddrs, 0, GConcOpts, @OnDialConc, nil) then
      Inc(GConcInflight)
    else
    begin
      Inc(GConcFail);
      Inc(GConcDone);
      if GConcDone >= GConcTarget then
      begin
        GLoop.Stop;
        Exit;
      end;
    end;
  end;
end;

function BenchDialConcurrentOpsPerSec: Double;
var
  LStart, LElapsed: UInt64;
  LPort: UInt16;
begin
  GConcOk := 0;
  GConcFail := 0;
  GConcDone := 0;
  GConcInflight := 0;
  GConcTarget := DIAL_CONC_COUNT;
  GConcMaxInflight := DIAL_CONC_INFLIGHT;
  GLoop := TAsyncLoop.Create(128);
  try
    GListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    MakeListenerNonBlocking(GListener);
    LPort := GListener.LocalAddr.Port;
    GConcAddrs[0] := TNetAddress.IPv4('127.0.0.1', LPort);
    GConcOpts := DefaultAsyncTcpDialOptions;
    GConcOpts.ConnectionAttemptDelayMs := 0;
    GConcOpts.MaxInFlight := 1;
    LStart := GetTickCount64;
    ConcMaybeStart;
    GLoop.Schedule(TDuration.FromMilliseconds(15000), @StopCb, nil);
    GLoop.Run;
    DrainAccepts(GListener);
    LElapsed := GetTickCount64 - LStart;
    if LElapsed = 0 then
      LElapsed := 1;
    Result := (GConcOk * 1000.0) / LElapsed;
    GListener.Close;
    GListener := nil;
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
  WriteLn('metric=dial_ops_ok value=', GOk);
  WriteLn('truth=localhost-sequential-dial; not-public-dns-he-matrix');
  Check(GOk > 0, 'sequential ok > 0');
  Check(LOps > 0, 'dial throughput > 0');
end;

procedure TestDialConcurrentThroughput;
var
  LOps: Double;
begin
  LOps := BenchDialConcurrentOpsPerSec;
  WriteLn('metric=dial_concurrent_ops_per_s value=', FormatFloat('0.0', LOps));
  WriteLn('metric=dial_concurrent_inflight value=', DIAL_CONC_INFLIGHT);
  WriteLn('metric=dial_concurrent_ok value=', GConcOk);
  WriteLn('metric=dial_concurrent_fail value=', GConcFail);
  WriteLn('truth=localhost-concurrent-dial; single-loop; not-public-dns');
  Check(GConcOk > 0, 'concurrent ok > 0');
  Check(GConcFail = 0, 'concurrent fail = 0');
  Check(GConcOk = DIAL_CONC_COUNT, 'concurrent all ok');
  Check(LOps > 0, 'concurrent ops > 0');
end;

begin
  T := TTestSuite.Create('net_async_dial_bench');
  T.Test('DialThroughput', @TestDialThroughput);
  T.Test('DialConcurrentThroughput', @TestDialConcurrentThroughput);
  if not T.Run then
    Halt(1);
end.
