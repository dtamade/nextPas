program bench_new_components;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.intf,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.arena.thread,
  nextpas.core.mem.pool.sizeclass,
  nextpas.core.mem.allocator.fallback,
  nextpas.core.mem.allocator,
  nextpas.core.platform.time;

const
  ITERS = 1000000;
  SMALL_SIZE = 64;

type
  TBenchResult = record
    Name: string;
    NsPerOp: Double;
    OpsPerSec: Double;
  end;

function NowNs: Int64;
begin
  Result := platform_monotonic_ns;
end;

procedure PrintResult(const R: TBenchResult);
var
  LName: string;
begin
  LName := R.Name;
  while Length(LName) < 55 do
    LName := LName + ' ';
  WriteLn('  ', LName, R.NsPerOp:10:1, ' ns/op  ', R.OpsPerSec:14:0, ' ops/s');
end;

function RunBench(const AName: string; AIters: Int64; AElapsedNs: Int64): TBenchResult;
begin
  Result.Name := AName;
  Result.NsPerOp := AElapsedNs / AIters;
  Result.OpsPerSec := AIters / (AElapsedNs / 1e9);
  PrintResult(Result);
end;

{ --- TLocalArena baseline --- }

procedure BenchLocalArena;
var
  LArena: TLocalArena;
  I: Int64;
  T0: Int64;
  LP: Pointer;
begin
  LArena := TLocalArena.Create(4 * 1024 * 1024);
  try
    T0 := NowNs;
    for I := 1 to ITERS do
    begin
      LP := LArena.Alloc(SMALL_SIZE);
      PByte(LP)^ := 1;
      if I mod 10000 = 0 then
        LArena.Reset;
    end;
    RunBench('TLocalArena.Alloc (64B, reset/10K)', ITERS, NowNs - T0);
  finally
    LArena.Free;
  end;
end;

{ --- TThreadArena --- }

procedure BenchThreadArena;
var
  LMgr: TThreadArenaManager;
  LConfig: TThreadArenaConfig;
  LT: TThreadArena;
  I: Int64;
  T0: Int64;
  LP: Pointer;
begin
  LConfig := DefaultThreadArenaConfig;
  LConfig.ArenaCapacity := 4 * 1024 * 1024;
  LMgr := TThreadArenaManager.Create(LConfig);
  try
    LT := TThreadArena.Create(LMgr.Get);
    T0 := NowNs;
    for I := 1 to ITERS do
    begin
      LP := LT.Alloc(SMALL_SIZE);
      PByte(LP)^ := 1;
      if I mod 10000 = 0 then
        LT.Reset;
    end;
    RunBench('TThreadArena.Alloc (64B, reset/10K)', ITERS, NowNs - T0);
    LT.DrainTLS(LMgr);
  finally
    LMgr.Free;
  end;
end;

{ --- TSizeClassPool --- }

procedure BenchSizeClassPool;
var
  LPool: TSizeClassPool;
  I: Int64;
  T0: Int64;
  LP: Pointer;
  Ptrs: array[0..999] of Pointer;
  J: Integer;
begin
  LPool := TSizeClassPool.Create;
  try
    // Warm up
    for J := 0 to 999 do
      Ptrs[J] := LPool.Alloc(SMALL_SIZE);
    for J := 0 to 999 do
      LPool.Release(Ptrs[J], SMALL_SIZE);

    T0 := NowNs;
    for I := 1 to ITERS do
    begin
      LP := LPool.Alloc(SMALL_SIZE);
      PByte(LP)^ := 1;
      LPool.Release(LP, SMALL_SIZE);
    end;
    RunBench('TSizeClassPool Alloc+Release (64B)', ITERS, NowNs - T0);
  finally
    LPool.Free;
  end;
end;

{ --- TSizeClassPool batch --- }

procedure BenchSizeClassPoolBatch;
var
  LPool: TSizeClassPool;
  I: Int64;
  T0: Int64;
  Ptrs: array[0..99] of Pointer;
  J: Integer;
begin
  LPool := TSizeClassPool.Create;
  try
    T0 := NowNs;
    for I := 1 to ITERS div 100 do
    begin
      for J := 0 to 99 do
        Ptrs[J] := LPool.Alloc(SMALL_SIZE);
      for J := 0 to 99 do
        LPool.Release(Ptrs[J], SMALL_SIZE);
    end;
    RunBench('TSizeClassPool batch-100 Alloc+Release (64B)', ITERS, NowNs - T0);
  finally
    LPool.Free;
  end;
end;

{ --- TFallbackAllocator --- }

procedure BenchFallbackAllocator;
var
  LPrimary: TAllocator;
  LFallback: TAllocator;
  LFb: TFallbackAllocator;
  I: Int64;
  T0: Int64;
  LP: Pointer;
begin
  LPrimary := TAllocator.Create;
  LFallback := TAllocator.Create;
  LFb := TFallbackAllocator.Create(LPrimary, LFallback);
  try
    T0 := NowNs;
    for I := 1 to ITERS do
    begin
      LP := LFb.GetMem(SMALL_SIZE);
      PByte(LP)^ := 1;
      LFb.FreeMem(LP);
    end;
    RunBench('TFallbackAllocator.GetMem+FreeMem (64B)', ITERS, NowNs - T0);
  finally
    LFb.Free;
    LFallback.Free;
    LPrimary.Free;
  end;
end;

{ --- IAllocator baseline (direct) --- }

procedure BenchDirectAllocator;
var
  LAlloc: TAllocator;
  I: Int64;
  T0: Int64;
  LP: Pointer;
begin
  LAlloc := TAllocator.Create;
  try
    T0 := NowNs;
    for I := 1 to ITERS do
    begin
      LP := LAlloc.GetMem(SMALL_SIZE);
      PByte(LP)^ := 1;
      LAlloc.FreeMem(LP);
    end;
    RunBench('IAllocator.GetMem+FreeMem direct (64B)', ITERS, NowNs - T0);
  finally
    LAlloc.Free;
  end;
end;

{ --- GetMem/FreeMem RTL baseline --- }

procedure BenchRTLGetMem;
var
  I: Int64;
  T0: Int64;
  LP: Pointer;
begin
  T0 := NowNs;
  for I := 1 to ITERS do
  begin
    LP := System.GetMem(SMALL_SIZE);
    PByte(LP)^ := 1;
    System.FreeMem(LP);
  end;
  RunBench('System.GetMem+FreeMem (64B)', ITERS, NowNs - T0);
end;

begin
  WriteLn;
  WriteLn('=== nextpas.core.mem new components benchmark ===');
  WriteLn('  Iterations: ', ITERS, '  Size: ', SMALL_SIZE, ' bytes');
  WriteLn;

  WriteLn('--- Baseline ---');
  BenchRTLGetMem;
  BenchDirectAllocator;

  WriteLn;
  WriteLn('--- Arena ---');
  BenchLocalArena;
  BenchThreadArena;

  WriteLn;
  WriteLn('--- SizeClass Pool ---');
  BenchSizeClassPool;
  BenchSizeClassPoolBatch;

  WriteLn;
  WriteLn('--- Fallback Allocator ---');
  BenchFallbackAllocator;

  WriteLn;
  WriteLn('Done.');
end.
