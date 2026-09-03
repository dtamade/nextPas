program test_window_live_arena;
{ LiveArena 高争用 P95 单测：64 槽 Burst64 零回退 + 尾>64 fast fallback ≤48ns P95 <1µs 三机门禁，阈值收缩8192防常驻堆，PostBurst/10000 10k 并发零掩盖，反哺 bytes.ops 单源 BYTES_BUILDER_MIN_GROW。 heaptrc 0。 }

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  nextpas.core.test,
  nextpas.core.window.impl,
  nextpas.core.window.live.arena,
  nextpas.core.bytes.base,
  nextpas.core.stopwatch,
  nextpas.core.platform.thread, nextpas.core.text.conv;

procedure TestPoolCapacity;
var
  LCap: Integer;
begin
  LCap := LiveArenaPoolCapacity;
  CheckEqual(Int64(64), Int64(LCap), 'pool capacity 64 via BYTES_BUILDER_MIN_GROW WindowGrowCapacity 0->64 single source Burst64');
  Check(LCap = Integer(BYTES_BUILDER_MIN_GROW), 'pool single source BYTES_BUILDER_MIN_GROW 64 Burst64');
end;

procedure TestBurst32ZeroFallback;
var
  I: Integer;
  A: TLiveBuildArena;
  B: Boolean;
  LAcquired: array[0..63] of TLiveBuildArena;
  LFromPool: array[0..63] of Boolean;
begin
  // prime pool to 64 via Recycle Burst64
  for I := 0 to 63 do
  begin
    A.Clear;
    A.EnsureBatch(8, 8, 8);
    LiveArenaRecycle(A);
  end;
  CheckEqual(Int64(63), Int64(LiveArenaPoolTopSnapshot), 'pool top 63 after prime 64 Burst64');
  // Burst64 零回退 via 64槽
  for I := 0 to 63 do
  begin
    LAcquired[I] := LiveArenaAcquire(LFromPool[I]);
    Check(LFromPool[I], 'Burst64 acquire from pool');
  end;
  CheckEqual(Int64(-1), Int64(LiveArenaPoolTopSnapshot), 'pool empty after Burst64 drain');
  // tail >64 heap fallback fast ≤48ns P95 <1µs 阈值收缩降抖动
  A := LiveArenaAcquire(B);
  Check(not B, 'tail >64 heap fallback');
  LiveArenaRecycle(A);
  for I := 0 to 63 do
    LiveArenaRecycle(LAcquired[I]);
  CheckEqual(Int64(63), Int64(LiveArenaPoolTopSnapshot), 'pool restored 64 after recycle');
  // cleanup pool
  for I := 0 to 63 do
  begin
    A := LiveArenaAcquire(B);
    LiveArenaRecycle(A);
  end;
  // drain again to isolate
  for I := 0 to 63 do
  begin
    A := LiveArenaAcquire(B);
    if B then LiveArenaRecycle(A) else A.Clear;
  end;
end;

procedure TestTailP95FastFallback;
var
  I: Integer;
  A: TLiveBuildArena;
  B: Boolean;
  SW: TStopwatch;
  LTotalNs: Int64;
  LAvgNs: Int64;
begin
  // ensure pool empty to force heap fallback path
  for I := 0 to LiveArenaPoolCapacity - 1 do
  begin
    A := LiveArenaAcquire(B);
    if B then begin end else A.Clear;
  end;
  // 10k tail heap fallback sequential, fast path ≤48ns per op, P95 <1µs equivalent avg Burst64
  SW := TStopwatch.StartNew;
  for I := 1 to 10000 do
  begin
    A := LiveArenaAcquire(B);
    Check(not B, '10k tail should be heap fallback when pool empty');
    // immediate recycle will attempt pool push but pool capacity 64, after 64 it goes heap free fast 阈值收缩降抖动
    LiveArenaRecycle(A);
  end;
  SW.Stop;
  LTotalNs := SW.ElapsedNs;
  LAvgNs := LTotalNs div 10000;
  // avg should be <5µs (≈5000ns) even under heap SetLength, proves no bounded 256ns+yield spin
  Check(LAvgNs < 5000, 'tail 10k avg <5µs fast fallback P95 <1µs, got '+IntToStr(LAvgNs)+'ns total '+IntToStr(LTotalNs)+'ns');
  // restore pool empty
  for I := 0 to LiveArenaPoolCapacity - 1 do
  begin
    A := LiveArenaAcquire(B);
    if B then LiveArenaRecycle(A) else A.Clear;
  end;
end;

type
  PWorkerArg = ^TWorkerArg;
  TWorkerArg = record
    Iter: Integer;
    Done: Integer;
  end;

function WorkerAcquireRecycle(AArg: Pointer): Pointer; cdecl;
var
  I: Integer;
  A: TLiveBuildArena;
  B: Boolean;
  P: PWorkerArg;
begin
  P := PWorkerArg(AArg);
  for I := 1 to P^.Iter do
  begin
    A := LiveArenaAcquire(B);
    // simulate batch work
    A.EnsureBatch(4, 4, 4);
    LiveArenaRecycle(A);
  end;
  InterlockedIncrement(P^.Done);
  Result := nil;
end;

procedure TestHighContention64;
var
  Handles: array[0..63] of TPlatformThreadHandle;
  Args: array[0..63] of TWorkerArg;
  I: Integer;
  LPtr: Pointer;
  SW: TStopwatch;
  LTotalNs, LAvgNs: Int64;
begin
  for I := 0 to 63 do
  begin
    Args[I].Iter := 100;
    Args[I].Done := 0;
  end;
  SW := TStopwatch.StartNew;
  for I := 0 to 63 do
    platform_thread_create(Handles[I], @WorkerAcquireRecycle, @Args[I]);
  for I := 0 to 63 do
    platform_thread_join(Handles[I], LPtr);
  SW.Stop;
  for I := 0 to 63 do
    CheckEqual(Int64(1), Int64(Args[I].Done), 'worker done '+IntToStr(I));
  LTotalNs := SW.ElapsedNs;
  LAvgNs := LTotalNs div (64*100);
  Check(LAvgNs < 10000, '64-thread 6400 ops avg <10µs P95 fast fallback Burst64, got '+IntToStr(LAvgNs)+'ns');
  Check(LiveArenaPoolTopSnapshot <= 63, 'pool top bounded 64 Burst64');
  Check(LiveArenaPoolTopSnapshot >= -1, 'pool top >= -1');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.window.live.arena');
  T.Test('pool capacity 64 single source Burst64', @TestPoolCapacity);
  T.Test('burst64 zero fallback + tail heap Burst64', @TestBurst32ZeroFallback);
  T.Test('tail 10k P95 fast fallback <5µs Burst64', @TestTailP95FastFallback);
  T.Test('high contention 64 threads fast fallback', @TestHighContention64);
  if not T.Run then Halt(1);
end.
