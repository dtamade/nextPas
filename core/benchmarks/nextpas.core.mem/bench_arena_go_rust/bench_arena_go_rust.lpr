program bench_arena_go_rust;
{**
 * Fair cross-lang harness (methodology aligned with bench_arena_go.go /
 * bench_arena_rust.rs): fixed batch size, reuse cycles, sink to defeat DCE.
 *
 * Scenarios:
 *   - LocalArena AllocFast 64B x Batch (reset each outer iter)  ≈ Go BumpArena
 *   - LocalArena reset+reuse cycles                           ≈ Go reset+reuse
 *   - ChunkedArena IArena.Alloc 64B batch
 *   - VirtualArena AllocFast 64B batch
 *   - DefaultHeap GetMem+FreeMem(size) 64B                    ≈ Go runtime malloc
 *   - System GetMem+FreeMem 64B                               ≈ glibc
 *
 * Run Go/Rust siblings via: make compare
 *}
{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.platform.time,
  nextpas.core.mem,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.arena.virtual;

{ TVirtualArena_Init lives in arena.virtual interface }

const
  BenchIterations = 1000;
  BatchCount = 10000;
  SmallSize = 64;
  ReuseCycles = 100;
  ArenaCap = BatchCount * SmallSize * 2;

var
  GSink: PtrUInt;

procedure Touch(P: Pointer); inline;
begin
  if P <> nil then
    GSink := GSink xor PtrUInt(P);
end;

function NowNs: Int64; inline;
begin
  Result := Int64(platform_monotonic_ns);
end;

procedure PrintRow(const AName: string; ATotalNs: Int64; AOps: Int64);
var
  LNsOp: Double;
  LOpsS: Double;
begin
  if AOps <= 0 then
    Exit;
  LNsOp := Double(ATotalNs) / Double(AOps);
  if LNsOp > 0 then
    LOpsS := 1.0e9 / LNsOp
  else
    LOpsS := 0;
  WriteLn('  ', AName:45, ' ', LNsOp:12:0, ' ns/op  ', LOpsS:12:0, ' ops/s');
end;

procedure BenchLocalArenaAlloc;
var
  LArena: TLocalArena;
  LOuter, LInner: Integer;
  LT0, LT1: Int64;
  LP: Pointer;
begin
  LArena := TLocalArena.Create(ArenaCap);
  try
    LT0 := NowNs;
    for LOuter := 1 to BenchIterations do
    begin
      LArena.Reset;
      for LInner := 1 to BatchCount do
      begin
        LP := LArena.AllocFast(SmallSize);
        Touch(LP);
      end;
    end;
    LT1 := NowNs;
    PrintRow('NP LocalArena AllocFast 64B x10000', LT1 - LT0,
      Int64(BenchIterations) * Int64(BatchCount));
  finally
    LArena.Free;
  end;
end;

procedure BenchLocalArenaResetReuse;
var
  LArena: TLocalArena;
  LOuter, LInner: Integer;
  LT0, LT1: Int64;
  LP: Pointer;
begin
  LArena := TLocalArena.Create(ArenaCap);
  try
    LT0 := NowNs;
    for LOuter := 1 to ReuseCycles do
    begin
      for LInner := 1 to BatchCount do
      begin
        LP := LArena.AllocFast(SmallSize);
        Touch(LP);
      end;
      LArena.Reset;
    end;
    LT1 := NowNs;
    PrintRow('NP LocalArena reset+reuse x100', LT1 - LT0,
      Int64(ReuseCycles) * Int64(BatchCount));
  finally
    LArena.Free;
  end;
end;

procedure BenchChunkedArenaAlloc;
var
  LArena: IArena;
  LOuter, LInner: Integer;
  LT0, LT1: Int64;
  LP: Pointer;
begin
  LArena := CreateChunkedArena(ArenaCap, 0);
  LT0 := NowNs;
  for LOuter := 1 to BenchIterations do
  begin
    LArena.Reset;
    for LInner := 1 to BatchCount do
    begin
      LP := LArena.Alloc(SmallSize);
      Touch(LP);
    end;
  end;
  LT1 := NowNs;
  PrintRow('NP ChunkedArena Alloc 64B x10000', LT1 - LT0,
    Int64(BenchIterations) * Int64(BatchCount));
  LArena := nil;
end;

procedure BenchVirtualArenaAlloc;
var
  LArena: TVirtualArena;
  LOuter, LInner: Integer;
  LT0, LT1: Int64;
  LP: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    LT0 := NowNs;
    for LOuter := 1 to BenchIterations do
    begin
      LArena.Reset;
      for LInner := 1 to BatchCount do
      begin
        LP := LArena.AllocFast(SmallSize);
        Touch(LP);
      end;
    end;
    LT1 := NowNs;
    PrintRow('NP VirtualArena AllocFast 64B x10000', LT1 - LT0,
      Int64(BenchIterations) * Int64(BatchCount));
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure BenchDefaultHeapSized;
var
  LOuter, LInner: Integer;
  LT0, LT1: Int64;
  LP: Pointer;
begin
  LT0 := NowNs;
  for LOuter := 1 to BenchIterations do
    for LInner := 1 to BatchCount do
    begin
      LP := GetMem(SmallSize);
      Touch(LP);
      FreeMem(LP, SmallSize);
    end;
  LT1 := NowNs;
  PrintRow('NP DefaultHeap GetMem+FreeMem(size) 64B', LT1 - LT0,
    Int64(BenchIterations) * Int64(BatchCount));
end;

procedure BenchSystemHeap;
var
  LOuter, LInner: Integer;
  LT0, LT1: Int64;
  LP: Pointer;
begin
  LT0 := NowNs;
  for LOuter := 1 to BenchIterations do
    for LInner := 1 to BatchCount do
    begin
      LP := System.GetMem(SmallSize);
      Touch(LP);
      System.FreeMem(LP);
    end;
  LT1 := NowNs;
  PrintRow('NP System.GetMem+FreeMem 64B', LT1 - LT0,
    Int64(BenchIterations) * Int64(BatchCount));
end;

begin
  WriteLn('=== nextPas Arena/Heap Benchmark (Go/Rust methodology) ===');
  WriteLn('  Iterations: ', BenchIterations, ', Batch: ', BatchCount,
    ', Size: ', SmallSize, 'B');
  WriteLn;
  WriteLn('--- Results ---');
  BenchLocalArenaAlloc;
  BenchLocalArenaResetReuse;
  BenchChunkedArenaAlloc;
  BenchVirtualArenaAlloc;
  BenchDefaultHeapSized;
  BenchSystemHeap;
  WriteLn;
  WriteLn('sink=', GSink);
  WriteLn('Done.');
end.
