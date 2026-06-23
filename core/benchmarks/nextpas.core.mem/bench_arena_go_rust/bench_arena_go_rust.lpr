program bench_arena_go_rust;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.arena.chunked,
  nextpas.core.mem.arena.virtual,
  nextpas.core.platform.time;

const
  SMALL_SIZE  = 64;
  BATCH_COUNT = 10000;

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
  while Length(LName) < 50 do
    LName := LName + ' ';
  WriteLn('  ', LName, R.NsPerOp:10:0, ' ns/op  ', R.OpsPerSec:14:0, ' ops/s');
end;

{ ===== Pure allocation throughput (no reset overhead) ===== }

function BenchRTLBatch: TBenchResult;
var
  I, J: Integer;
  T0, T1: Int64;
  Ptrs: array[0..BATCH_COUNT-1] of Pointer;
begin
  Result.Name := 'RTL GetMem+FreeMem 64B x10000';
  T0 := NowNs;
  for I := 0 to 99 do
  begin
    for J := 0 to BATCH_COUNT - 1 do
      GetMem(Ptrs[J], SMALL_SIZE);
    for J := 0 to BATCH_COUNT - 1 do
      FreeMem(Ptrs[J]);
  end;
  T1 := NowNs;
  Result.NsPerOp := Double(T1 - T0) / Double(100 * BATCH_COUNT);
  Result.OpsPerSec := 1e9 / Result.NsPerOp;
end;

function BenchLocalArenaBatch: TBenchResult;
var
  I, J: Integer;
  T0, T1: Int64;
  Arena: TLocalArena;
begin
  Result.Name := 'LocalArena Alloc 64B x10000 (fresh arena)';
  T0 := NowNs;
  for I := 0 to 99 do
  begin
    Arena := TLocalArena.Create(1024 * 1024);
    for J := 0 to BATCH_COUNT - 1 do
      Arena.Alloc(SMALL_SIZE);
    Arena.Free;
  end;
  T1 := NowNs;
  Result.NsPerOp := Double(T1 - T0) / Double(100 * BATCH_COUNT);
  Result.OpsPerSec := 1e9 / Result.NsPerOp;
end;

function BenchChunkedArenaBatch: TBenchResult;
var
  I, J: Integer;
  T0, T1: Int64;
  Arena: TChunkedArena;
begin
  Result.Name := 'ChunkedArena Alloc 64B x10000 (fresh arena)';
  T0 := NowNs;
  for I := 0 to 99 do
  begin
    Arena := TChunkedArena.Create(65536);
    for J := 0 to BATCH_COUNT - 1 do
      Arena.Alloc(SMALL_SIZE);
    Arena.Free;
  end;
  T1 := NowNs;
  Result.NsPerOp := Double(T1 - T0) / Double(100 * BATCH_COUNT);
  Result.OpsPerSec := 1e9 / Result.NsPerOp;
end;

function BenchVirtualArenaBatch: TBenchResult;
var
  I, J: Integer;
  T0, T1: Int64;
  Arena: TVirtualArena;
begin
  Result.Name := 'VirtualArena Alloc 64B x10000 (fresh arena)';
  T0 := NowNs;
  for I := 0 to 99 do
  begin
    TVirtualArena_Init(Arena);
    for J := 0 to BATCH_COUNT - 1 do
      Arena.Alloc(SMALL_SIZE);
    Arena.Release;
  end;
  T1 := NowNs;
  Result.NsPerOp := Double(T1 - T0) / Double(100 * BATCH_COUNT);
  Result.OpsPerSec := 1e9 / Result.NsPerOp;
end;

function BenchVirtualArenaNoPtr: TBenchResult;
var
  I, J: Integer;
  T0, T1: Int64;
  Arena: TVirtualArena;
begin
  Result.Name := 'VirtualArena NoPointer 64B x10000 (fresh arena)';
  T0 := NowNs;
  for I := 0 to 99 do
  begin
    TVirtualArena_Init(Arena);
    for J := 0 to BATCH_COUNT - 1 do
      Arena.AllocNoPointer(SMALL_SIZE);
    Arena.Release;
  end;
  T1 := NowNs;
  Result.NsPerOp := Double(T1 - T0) / Double(100 * BATCH_COUNT);
  Result.OpsPerSec := 1e9 / Result.NsPerOp;
end;

function BenchVirtualArenaUnsafeReuse: TBenchResult;
var
  I, J: Integer;
  T0, T1: Int64;
  Arena: TVirtualArena;
begin
  Result.Name := 'VirtualArena AllocUnsafe 64B reset+reuse';
  TVirtualArena_Init(Arena);
  { Warm up: first cycle triggers commit }
  for J := 0 to BATCH_COUNT - 1 do
    Arena.Alloc(SMALL_SIZE);
  Arena.Reset;
  T0 := NowNs;
  for I := 0 to 99 do
  begin
    for J := 0 to BATCH_COUNT - 1 do
      Arena.AllocUnsafe(SMALL_SIZE);
    Arena.Reset;
  end;
  T1 := NowNs;
  Result.NsPerOp := Double(T1 - T0) / Double(100 * BATCH_COUNT);
  Result.OpsPerSec := 1e9 / Result.NsPerOp;
  Arena.Release;
end;

{ ===== Reset+Reuse cycle cost ===== }

function BenchLocalArenaReuse: TBenchResult;
var
  I, J: Integer;
  T0, T1: Int64;
  Arena: TLocalArena;
begin
  Result.Name := 'LocalArena reset+reuse 100 cycles x10000';
  Arena := TLocalArena.Create(1024 * 1024);
  T0 := NowNs;
  for I := 0 to 99 do
  begin
    for J := 0 to BATCH_COUNT - 1 do
      Arena.Alloc(SMALL_SIZE);
    Arena.Reset;
  end;
  T1 := NowNs;
  Result.NsPerOp := Double(T1 - T0) / Double(100 * BATCH_COUNT);
  Result.OpsPerSec := 1e9 / Result.NsPerOp;
  Arena.Free;
end;

function BenchChunkedArenaReuse: TBenchResult;
var
  I, J: Integer;
  T0, T1: Int64;
  Arena: TChunkedArena;
begin
  Result.Name := 'ChunkedArena reset+reuse 100 cycles x10000';
  Arena := TChunkedArena.Create(65536);
  T0 := NowNs;
  for I := 0 to 99 do
  begin
    for J := 0 to BATCH_COUNT - 1 do
      Arena.Alloc(SMALL_SIZE);
    Arena.Reset;
  end;
  T1 := NowNs;
  Result.NsPerOp := Double(T1 - T0) / Double(100 * BATCH_COUNT);
  Result.OpsPerSec := 1e9 / Result.NsPerOp;
  Arena.Free;
end;

function BenchVirtualArenaReuse: TBenchResult;
var
  I, J: Integer;
  T0, T1: Int64;
  Arena: TVirtualArena;
begin
  Result.Name := 'VirtualArena reset+reuse 100 cycles x10000';
  TVirtualArena_Init(Arena);
  T0 := NowNs;
  for I := 0 to 99 do
  begin
    for J := 0 to BATCH_COUNT - 1 do
      Arena.Alloc(SMALL_SIZE);
    Arena.Reset;
  end;
  T1 := NowNs;
  Result.NsPerOp := Double(T1 - T0) / Double(100 * BATCH_COUNT);
  Result.OpsPerSec := 1e9 / Result.NsPerOp;
  Arena.Release;
end;

var
  Results: array[0..9] of TBenchResult;
  R: TBenchResult;
  I: Integer;

begin
  WriteLn('=== nextpas.core.mem Arena Benchmark ===');
  WriteLn('  Batch: ', BATCH_COUNT, ', Size: ', SMALL_SIZE, 'B');
  WriteLn;
  WriteLn('--- Pure allocation throughput ---');
  Results[0] := BenchRTLBatch;
  Results[1] := BenchLocalArenaBatch;
  Results[2] := BenchChunkedArenaBatch;
  Results[3] := BenchVirtualArenaBatch;
  Results[4] := BenchVirtualArenaNoPtr;
  for I := 0 to 4 do
    PrintResult(Results[I]);

  WriteLn;
  WriteLn('--- Reset+Reuse cycles ---');
  Results[5] := BenchLocalArenaReuse;
  Results[6] := BenchChunkedArenaReuse;
  Results[7] := BenchVirtualArenaReuse;
  Results[8] := BenchVirtualArenaUnsafeReuse;
  for I := 5 to 8 do
    PrintResult(Results[I]);

  WriteLn;
  WriteLn('Done.');
end.
