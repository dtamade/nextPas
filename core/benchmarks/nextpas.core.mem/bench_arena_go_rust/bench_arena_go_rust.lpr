program bench_arena_go_rust;
{**
 * Cross-lang + DefaultHeap truth harness.
 *
 * Section A — Arena (aligned with bench_arena_go.go / bench_arena_rust.rs):
 *   batch AllocFast / Reset  (P3 bump parity)
 *
 * Section B — Heap (aligned with scorecard SC1 RELEASE methodology):
 *   flat 200k alloc+free 64B, warmup 5k
 *   DefaultHeap direct / process GetMem facade / System
 *
 * Do NOT cross-compare Section A batch shape with Section B flat loops.
 * Authoritative Ready numbers: scorecard RELEASE=1.
 *}
{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.platform.time,
  nextpas.core.mem,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.growing,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.arena.virtual;

const
  { Section A — Go/Rust arena methodology }
  BenchIterations = 1000;
  BatchCount = 10000;
  SmallSize = 64;
  ReuseCycles = 100;
  ArenaCap = BatchCount * SmallSize * 2;

  { Section B — scorecard SC1 }
  SC1_ITERS = 200000;
  SC1_WARMUP = 5000;

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
  WriteLn('  ', AName:48, ' ', LNsOp:12:0, ' ns/op  ', LOpsS:12:0, ' ops/s');
end;

{ --- Section A: Arena --- }

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
    PrintRow('A LocalArena AllocFast 64B x10000', LT1 - LT0,
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
    PrintRow('A LocalArena reset+reuse x100', LT1 - LT0,
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
  PrintRow('A ChunkedArena Alloc 64B x10000', LT1 - LT0,
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
    PrintRow('A VirtualArena AllocFast 64B x10000', LT1 - LT0,
      Int64(BenchIterations) * Int64(BatchCount));
  finally
    TVirtualArena_Release(LArena);
  end;
end;

{ --- Section B: Heap = SC1 flat loop --- }

procedure BenchHeapSC1(const AName: string; AUseDefaultHeap: Boolean;
  AUseFacade: Boolean);
var
  LHeap: TGrowingAllocator;
  I: Integer;
  LT0, LT1: Int64;
  LP: Pointer;
begin
  LHeap := DefaultHeap;

  { warmup }
  for I := 1 to SC1_WARMUP do
  begin
    if AUseFacade then
    begin
      LP := GetMem(SmallSize);
      FreeMem(LP, SmallSize);
    end
    else if AUseDefaultHeap then
    begin
      LP := LHeap.GetMem(SmallSize);
      LHeap.FreeMem(LP, SmallSize);
    end
    else
    begin
      System.GetMem(LP, SmallSize);
      System.FreeMem(LP);
    end;
  end;

  LT0 := NowNs;
  for I := 1 to SC1_ITERS do
  begin
    if AUseFacade then
    begin
      LP := GetMem(SmallSize);
      Touch(LP);
      FreeMem(LP, SmallSize);
    end
    else if AUseDefaultHeap then
    begin
      LP := LHeap.GetMem(SmallSize);
      Touch(LP);
      LHeap.FreeMem(LP, SmallSize);
    end
    else
    begin
      System.GetMem(LP, SmallSize);
      Touch(LP);
      System.FreeMem(LP);
    end;
  end;
  LT1 := NowNs;
  PrintRow(AName, LT1 - LT0, SC1_ITERS);
end;

begin
  WriteLn('=== nextPas Arena + Heap (Go/Rust + SC1) ===');
  WriteLn('  A: arena batch=', BatchCount, ' outer=', BenchIterations,
    ' size=', SmallSize, 'B (Go/Rust methodology)');
  WriteLn('  B: heap flat iters=', SC1_ITERS, ' warmup=', SC1_WARMUP,
    ' size=', SmallSize, 'B (scorecard SC1 methodology)');
  WriteLn;

  WriteLn('--- A Arena (vs Go Bump / Rust Bump; not vs malloc) ---');
  BenchLocalArenaAlloc;
  BenchLocalArenaResetReuse;
  BenchChunkedArenaAlloc;
  BenchVirtualArenaAlloc;

  WriteLn;
  WriteLn('--- B Heap SC1 flat alloc+free (authoritative vs system) ---');
  BenchHeapSC1('B DefaultHeap direct sized 64B', True, False);
  BenchHeapSC1('B process GetMem facade sized 64B', False, True);
  BenchHeapSC1('B System.GetMem+FreeMem 64B', False, False);

  WriteLn;
  WriteLn('sink=', GSink);
  WriteLn('Done. Heap Ready numbers: make -C .../scorecard test RELEASE=1');
end.
