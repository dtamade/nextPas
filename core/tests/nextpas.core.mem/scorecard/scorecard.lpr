program scorecard;
{**
 * mem Scorecard SC1–SC5 (STDLIB-QUALITY-PLAN §7)
 *
 * Fixed scenarios for Ready reports. Micro-bench museum numbers go to
 * BENCHMARKS.md; this program is the authoritative local repro for:
 *   SC1 small_64B alloc+free
 *   SC2 mixed sizes (mean + p99 over batch samples)
 *   SC3 cross-thread free (correctness + throughput)
 *   SC4 arena reset+reuse
 *   SC5 long-run scavenge retention (LiveBytes / ReleasedBytes)
 *
 * Baselines: Growing native API, System/glibc, LocalArena.
 *}

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.atomic.core,
  nextpas.core.platform.time,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.growing,
  nextpas.core.mem.arena.local;

const
  { SC1 }
  SC1_ITERS = 200000;
  SC1_WARMUP = 5000;

  { SC2 }
  SC2_BATCHES = 2000;
  SC2_WARMUP_BATCHES = 50;
  SC2_SIZES: array[0..5] of SizeUInt = (16, 64, 256, 512, 1024, 4096);

  { SC3 cross-thread free }
  SC3_BATCH = 64;
  SC3_ROUNDS = 2000;
  SC3_SIZE = 64;

  { SC4 arena }
  SC4_ARENA_CAP = 1024 * 1024;
  SC4_ALLOC_SIZE = 64;
  SC4_CYCLES = 500;
  SC4_ALLOCS_PER_CYCLE = 10000;

  { SC5 long-run retention / scavenge }
  SC5_ROUNDS = 40;
  SC5_BATCH = 256;
  SC5_SIZE = 64;
  SC5_SCAVENGE_EVERY = 4;

type
  TScoreRow = record
    Id: string;
    Subject: string;
    NsPerOp: Int64;
    P99Ns: Int64;      { 0 = not measured }
    MopsX100: Int64;   { Mops/s * 100 for fixed-point print }
    Ops: UInt64;
    Ok: Boolean;
    Note: string;
    { SC5 extras (0 when unused) }
    PeakLive: Int64;
    FinalLive: Int64;
    ReleasedBytes: Int64;
    ReleasedSpans: Int64;
  end;

var
  GRows: array of TScoreRow;
  GRowCount: Integer;
  GFailed: Integer;
  GAlloc: TGrowingAllocator;

procedure AddRow(const AId, ASubject: string; ANsPerOp, AP99Ns, AOps: Int64;
  AOk: Boolean; const ANote: string; APeakLive: Int64 = 0;
  AFinalLive: Int64 = 0; AReleasedBytes: Int64 = 0; AReleasedSpans: Int64 = 0);
var
  LMopsX100: Int64;
begin
  if GRowCount >= Length(GRows) then
    SetLength(GRows, GRowCount + 16);
  GRows[GRowCount].Id := AId;
  GRows[GRowCount].Subject := ASubject;
  GRows[GRowCount].NsPerOp := ANsPerOp;
  GRows[GRowCount].P99Ns := AP99Ns;
  GRows[GRowCount].Ops := AOps;
  GRows[GRowCount].Ok := AOk;
  GRows[GRowCount].Note := ANote;
  GRows[GRowCount].PeakLive := APeakLive;
  GRows[GRowCount].FinalLive := AFinalLive;
  GRows[GRowCount].ReleasedBytes := AReleasedBytes;
  GRows[GRowCount].ReleasedSpans := AReleasedSpans;
  if (ANsPerOp > 0) and (AOps > 0) then
    { Mops/s = 1000 / ns_per_op; store *100 for two decimals }
    LMopsX100 := 100000 div ANsPerOp
  else
    LMopsX100 := 0;
  GRows[GRowCount].MopsX100 := LMopsX100;
  Inc(GRowCount);
  if not AOk then
    Inc(GFailed);
end;

procedure SortInt64Asc(var A: array of Int64; ACount: Integer);
var
  I, J: Integer;
  LTmp: Int64;
begin
  { insertion sort; sample counts are small }
  for I := 1 to ACount - 1 do
  begin
    LTmp := A[I];
    J := I - 1;
    while (J >= 0) and (A[J] > LTmp) do
    begin
      A[J + 1] := A[J];
      Dec(J);
    end;
    A[J + 1] := LTmp;
  end;
end;

function Percentile99(var ASamples: array of Int64; ACount: Integer): Int64;
var
  LIdx: Integer;
begin
  if ACount <= 0 then
    Exit(0);
  SortInt64Asc(ASamples, ACount);
  LIdx := (ACount * 99) div 100;
  if LIdx >= ACount then
    LIdx := ACount - 1;
  Result := ASamples[LIdx];
end;

{ --- SC1: small_64B alloc+free --- }

procedure RunSC1;
var
  LStart, LEnd: UInt64;
  LPtr: Pointer;
  I: Integer;
  LOps: UInt64;
  LNs: Int64;
  LOk: Boolean;
begin
  WriteLn('SC1 small_64B ...');
  LOk := True;

  { Growing }
  for I := 1 to SC1_WARMUP do
  begin
    LPtr := GAlloc.GetMem(64);
    if LPtr = nil then LOk := False;
    GAlloc.FreeMem(LPtr, 64);
  end;
  LStart := platform_monotonic_ns;
  for I := 1 to SC1_ITERS do
  begin
    LPtr := GAlloc.GetMem(64);
    if LPtr = nil then LOk := False;
    GAlloc.FreeMem(LPtr, 64);
  end;
  LEnd := platform_monotonic_ns;
  LOps := SC1_ITERS;
  if LOps > 0 then
    LNs := Int64((LEnd - LStart) div LOps)
  else
    LNs := 0;
  AddRow('SC1', 'growing', LNs, 0, LOps, LOk, 'alloc+free 64B');

  { System / glibc baseline }
  LOk := True;
  for I := 1 to SC1_WARMUP do
  begin
    System.GetMem(LPtr, 64);
    if LPtr = nil then LOk := False;
    System.FreeMem(LPtr);
  end;
  LStart := platform_monotonic_ns;
  for I := 1 to SC1_ITERS do
  begin
    System.GetMem(LPtr, 64);
    if LPtr = nil then LOk := False;
    System.FreeMem(LPtr);
  end;
  LEnd := platform_monotonic_ns;
  LNs := Int64((LEnd - LStart) div LOps);
  AddRow('SC1', 'system', LNs, 0, LOps, LOk, 'glibc via System.GetMem');

  { Process DefaultHeap (same Growing singleton; proves D1 wiring) }
  LOk := True;
  for I := 1 to SC1_WARMUP do
  begin
    LPtr := DefaultHeap.GetMem(64);
    if LPtr = nil then LOk := False;
    DefaultHeap.FreeMem(LPtr, 64);
  end;
  LStart := platform_monotonic_ns;
  for I := 1 to SC1_ITERS do
  begin
    LPtr := DefaultHeap.GetMem(64);
    if LPtr = nil then LOk := False;
    DefaultHeap.FreeMem(LPtr, 64);
  end;
  LEnd := platform_monotonic_ns;
  LNs := Int64((LEnd - LStart) div LOps);
  AddRow('SC1', 'default_heap', LNs, 0, LOps, LOk, 'DefaultHeap=Growing singleton');
end;

{ --- SC2: mixed sizes, mean + p99 over batches --- }

procedure RunSC2Mixed(const ASubject: string; AUseGrowing: Boolean);
var
  LPtrs: array[0..5] of Pointer;
  LSamples: array of Int64;
  I, J: Integer;
  LStart, LEnd, LBatchStart, LBatchEnd: UInt64;
  LOps: UInt64;
  LNs, LP99: Int64;
  LOk: Boolean;
begin
  WriteLn('SC2 mixed (', ASubject, ') ...');
  LOk := True;
  SetLength(LSamples, SC2_BATCHES);

  { warmup }
  for I := 1 to SC2_WARMUP_BATCHES do
  begin
    for J := 0 to High(SC2_SIZES) do
    begin
      if AUseGrowing then
        LPtrs[J] := GAlloc.GetMem(SC2_SIZES[J])
      else
        System.GetMem(LPtrs[J], SC2_SIZES[J]);
      if LPtrs[J] = nil then LOk := False;
    end;
    for J := High(SC2_SIZES) downto 0 do
      if AUseGrowing then
        GAlloc.FreeMem(LPtrs[J], SC2_SIZES[J])
      else
        System.FreeMem(LPtrs[J]);
  end;

  LStart := platform_monotonic_ns;
  for I := 0 to SC2_BATCHES - 1 do
  begin
    LBatchStart := platform_monotonic_ns;
    for J := 0 to High(SC2_SIZES) do
    begin
      if AUseGrowing then
        LPtrs[J] := GAlloc.GetMem(SC2_SIZES[J])
      else
        System.GetMem(LPtrs[J], SC2_SIZES[J]);
      if LPtrs[J] = nil then LOk := False;
    end;
    for J := High(SC2_SIZES) downto 0 do
      if AUseGrowing then
        GAlloc.FreeMem(LPtrs[J], SC2_SIZES[J])
      else
        System.FreeMem(LPtrs[J]);
    LBatchEnd := platform_monotonic_ns;
    { per-op ns inside this batch (6 alloc+free pairs) }
    LSamples[I] := Int64((LBatchEnd - LBatchStart) div 6);
  end;
  LEnd := platform_monotonic_ns;

  LOps := UInt64(SC2_BATCHES) * 6;
  if LOps > 0 then
    LNs := Int64((LEnd - LStart) div LOps)
  else
    LNs := 0;
  LP99 := Percentile99(LSamples, SC2_BATCHES);
  AddRow('SC2', ASubject, LNs, LP99, LOps, LOk,
    'sizes 16..4K; p99=batch_ns/op');
end;

procedure RunSC2;
begin
  RunSC2Mixed('growing', True);
  RunSC2Mixed('system', False);
end;

{ --- SC3: cross-thread free --- }

type
  PCrossCtx = ^TCrossCtx;
  TCrossCtx = record
    Alloc: TGrowingAllocator;
    Ptrs: array[0..SC3_BATCH - 1] of Pointer;
    Ready: LongInt;   { 0 idle, 1 filled by producer, 2 freed by consumer }
    Stop: LongInt;
    Error: LongInt;
    Filled: UInt64;
    Freed: UInt64;
  end;

function SC3Producer(Parameter: Pointer): PtrInt;
var
  LCtx: PCrossCtx;
  I: Integer;
  LPtr: Pointer;
begin
  LCtx := PCrossCtx(Parameter);
  while InterlockedCompareExchange(LCtx^.Stop, 0, 0) = 0 do
  begin
    { wait for free slot }
    while (InterlockedCompareExchange(LCtx^.Ready, 0, 0) <> 0) and
          (InterlockedCompareExchange(LCtx^.Stop, 0, 0) = 0) do
      ; { spin }
    if InterlockedCompareExchange(LCtx^.Stop, 0, 0) <> 0 then
      Break;
    for I := 0 to SC3_BATCH - 1 do
    begin
      LPtr := LCtx^.Alloc.GetMem(SC3_SIZE);
      if LPtr = nil then
      begin
        InterlockedExchange(LCtx^.Error, 1);
        InterlockedExchange(LCtx^.Stop, 1);
        Exit(1);
      end;
      PByte(LPtr)^ := Byte(I);
      LCtx^.Ptrs[I] := LPtr;
    end;
    ReadWriteBarrier;
    InterlockedExchange(LCtx^.Ready, 1);
    Inc(LCtx^.Filled);
  end;
  Result := 0;
end;

function SC3Consumer(Parameter: Pointer): PtrInt;
var
  LCtx: PCrossCtx;
  I: Integer;
  LPtr: Pointer;
begin
  LCtx := PCrossCtx(Parameter);
  while InterlockedCompareExchange(LCtx^.Stop, 0, 0) = 0 do
  begin
    while (InterlockedCompareExchange(LCtx^.Ready, 0, 0) <> 1) and
          (InterlockedCompareExchange(LCtx^.Stop, 0, 0) = 0) do
      ; { spin }
    if InterlockedCompareExchange(LCtx^.Stop, 0, 0) <> 0 then
      Break;
    ReadWriteBarrier;
    for I := 0 to SC3_BATCH - 1 do
    begin
      LPtr := LCtx^.Ptrs[I];
      if (LPtr = nil) or (PByte(LPtr)^ <> Byte(I)) then
      begin
        InterlockedExchange(LCtx^.Error, 1);
        InterlockedExchange(LCtx^.Stop, 1);
        Exit(1);
      end;
      LCtx^.Alloc.FreeMem(LPtr, SC3_SIZE);
      LCtx^.Ptrs[I] := nil;
    end;
    Inc(LCtx^.Freed);
    ReadWriteBarrier;
    InterlockedExchange(LCtx^.Ready, 0);
    if LCtx^.Freed >= SC3_ROUNDS then
      InterlockedExchange(LCtx^.Stop, 1);
  end;
  Result := 0;
end;

procedure RunSC3;
var
  LCtx: TCrossCtx;
  LProd, LCons: TThreadID;
  LStart, LEnd: UInt64;
  LOps: UInt64;
  LNs: Int64;
  LOk: Boolean;
  I: Integer;
begin
  WriteLn('SC3 cross-thread free ...');
  FillChar(LCtx, SizeOf(LCtx), 0);
  LCtx.Alloc := GAlloc;
  LCtx.Ready := 0;
  LCtx.Stop := 0;
  LCtx.Error := 0;
  LCtx.Filled := 0;
  LCtx.Freed := 0;
  for I := 0 to SC3_BATCH - 1 do
    LCtx.Ptrs[I] := nil;

  LStart := platform_monotonic_ns;
  LProd := BeginThread(@SC3Producer, @LCtx);
  LCons := BeginThread(@SC3Consumer, @LCtx);
  WaitForThreadTerminate(LProd, 0);
  WaitForThreadTerminate(LCons, 0);
  LEnd := platform_monotonic_ns;

  LOps := LCtx.Freed * SC3_BATCH;
  LOk := (LCtx.Error = 0) and (LCtx.Freed >= SC3_ROUNDS) and (LOps > 0);
  if LOps > 0 then
    LNs := Int64((LEnd - LStart) div LOps)
  else
    LNs := 0;
  AddRow('SC3', 'growing', LNs, 0, LOps, LOk,
    'producer alloc / consumer free 64B');
end;

{ --- SC4: arena reset+reuse --- }

procedure RunSC4;
var
  LArena: TLocalArena;
  LStart, LEnd: UInt64;
  LPtr: Pointer;
  C, I: Integer;
  LOps: UInt64;
  LNs: Int64;
  LOk: Boolean;
  LPerCycle: Integer;
begin
  WriteLn('SC4 arena reset+reuse ...');
  LOk := True;
  LArena := TLocalArena.Create(SC4_ARENA_CAP);
  try
    LPerCycle := SC4_ALLOCS_PER_CYCLE;
    if UInt64(LPerCycle) * SC4_ALLOC_SIZE > SC4_ARENA_CAP then
      LPerCycle := Integer(SC4_ARENA_CAP div SC4_ALLOC_SIZE) - 1;
    if LPerCycle < 1 then
      LPerCycle := 1;

    { warmup — hot path AllocFast (matches Go bump / Rust bumpalo style) }
    for I := 1 to LPerCycle do
    begin
      LPtr := LArena.AllocFast(SC4_ALLOC_SIZE);
      if LPtr = nil then LOk := False;
    end;
    LArena.Reset;

    LStart := platform_monotonic_ns;
    for C := 1 to SC4_CYCLES do
    begin
      for I := 1 to LPerCycle do
      begin
        LPtr := LArena.AllocFast(SC4_ALLOC_SIZE);
        if LPtr = nil then LOk := False;
      end;
      LArena.Reset;
    end;
    LEnd := platform_monotonic_ns;

    LOps := UInt64(SC4_CYCLES) * UInt64(LPerCycle);
    if LOps > 0 then
      LNs := Int64((LEnd - LStart) div LOps)
    else
      LNs := 0;
    AddRow('SC4', 'local_arena', LNs, 0, LOps, LOk,
      'reset+reuse 64B AllocFast');
  finally
    LArena.Free;
  end;
end;

{ --- SC5: long-run retention / scavenge (GetHeapStats, portable) --- }

procedure RunSC5;
var
  LAlloc: TGrowingAllocator;
  LPtrs: array of Pointer;
  LBefore, LStats: TGrowingHeapStats;
  LStart, LEnd: UInt64;
  LPeakLive, LFinalLive: Int64;
  LReleasedBytes, LReleasedSpans: Int64;
  LOps: UInt64;
  LNs: Int64;
  LOk: Boolean;
  R, I: Integer;
  LNote: string;
begin
  WriteLn('SC5 long-run scavenge ...');
  LOk := True;
  LPeakLive := 0;
  SetLength(LPtrs, SC5_BATCH);
  { TLS refill/flush is wired to the global DefaultGrowingAllocator. }
  LAlloc := DefaultGrowingAllocator;
  if LAlloc = nil then
  begin
    AddRow('SC5', 'growing', 0, 0, 0, False, 'DefaultGrowingAllocator nil');
    Exit;
  end;
  LAlloc.GetHeapStats(LBefore);
  LStart := platform_monotonic_ns;
  for R := 1 to SC5_ROUNDS do
  begin
    for I := 0 to SC5_BATCH - 1 do
    begin
      LPtrs[I] := LAlloc.GetMem(SC5_SIZE);
      if LPtrs[I] = nil then
        LOk := False
      else
        PByte(LPtrs[I])^ := Byte(I);
    end;
    for I := 0 to SC5_BATCH - 1 do
    begin
      if LPtrs[I] <> nil then
      begin
        if PByte(LPtrs[I])^ <> Byte(I) then
          LOk := False;
        LAlloc.FreeMem(LPtrs[I], SC5_SIZE);
        LPtrs[I] := nil;
      end;
    end;
    LAlloc.GetHeapStats(LStats);
    if Int64(LStats.LiveBytes) > LPeakLive then
      LPeakLive := Int64(LStats.LiveBytes);
    if (R mod SC5_SCAVENGE_EVERY) = 0 then
      LAlloc.Scavenge;
  end;
  { Final force scavenge drains remaining idle spans. }
  LAlloc.Scavenge;
  LEnd := platform_monotonic_ns;
  LAlloc.GetHeapStats(LStats);
  LFinalLive := Int64(LStats.LiveBytes);
  LReleasedBytes := Int64(LStats.ReleasedBytes) - Int64(LBefore.ReleasedBytes);
  LReleasedSpans := Int64(LStats.ReleasedSpans) - Int64(LBefore.ReleasedSpans);
  LOps := UInt64(SC5_ROUNDS) * UInt64(SC5_BATCH);
  if LOps > 0 then
    LNs := Int64((LEnd - LStart) div LOps)
  else
    LNs := 0;
  { Pass: no corruption, this run released something, peak was positive. }
  if LReleasedSpans < 1 then
    LOk := False;
  if LReleasedBytes < 1 then
    LOk := False;
  if LPeakLive < 1 then
    LOk := False;
  if LFinalLive > LPeakLive then
    LOk := False;
  LNote := 'delta Released* + peak/final LiveBytes (GetHeapStats)';
  AddRow('SC5', 'growing', LNs, 0, LOps, LOk, LNote,
    LPeakLive, LFinalLive, LReleasedBytes, LReleasedSpans);
end;

{ --- report --- }

procedure WriteMops(AMopsX100: Int64);
var
  LWhole, LFrac: Int64;
begin
  LWhole := AMopsX100 div 100;
  LFrac := AMopsX100 mod 100;
  if LFrac < 0 then
    LFrac := -LFrac;
  Write(LWhole:5, '.');
  if LFrac < 10 then
    Write('0');
  Write(LFrac);
end;

procedure PrintReport;
var
  I: Integer;
  LStatus: string;
begin
  WriteLn;
  WriteLn('=== mem Scorecard SC1-SC5 ===');
  WriteLn('id   subject        ns/op    p99     Mops/s    ops        status  note');
  WriteLn('---- -------------- -------- ------- --------- ---------- ------- ----');
  for I := 0 to GRowCount - 1 do
  begin
    if GRows[I].Ok then
      LStatus := 'PASS'
    else
      LStatus := 'FAIL';
    Write(GRows[I].Id:4, '  ');
    Write(GRows[I].Subject:14, '  ');
    Write(GRows[I].NsPerOp:8, '  ');
    if GRows[I].P99Ns > 0 then
      Write(GRows[I].P99Ns:7, '  ')
    else
      Write('      -  ');
    WriteMops(GRows[I].MopsX100);
    Write('  ');
    Write(GRows[I].Ops:10, '  ');
    Write(LStatus:7, '  ');
    Write(GRows[I].Note);
    if GRows[I].Id = 'SC5' then
    begin
      Write(' | peak=', GRows[I].PeakLive);
      Write(' final=', GRows[I].FinalLive);
      Write(' releasedB=', GRows[I].ReleasedBytes);
      Write(' releasedSpans=', GRows[I].ReleasedSpans);
    end;
    WriteLn;
  end;
  WriteLn;
  if GFailed = 0 then
    WriteLn('SCORECARD: ALL PASS (', GRowCount, ' rows)')
  else
    WriteLn('SCORECARD: FAILED rows=', GFailed);
end;

begin
  GRowCount := 0;
  GFailed := 0;
  SetLength(GRows, 16);
  GAlloc := TGrowingAllocator.Create;
  try
    RunSC1;
    RunSC2;
    RunSC3;
    RunSC4;
    RunSC5;
    PrintReport;
  finally
    GAlloc.Free;
  end;
  if GFailed <> 0 then
    Halt(1);
end.
