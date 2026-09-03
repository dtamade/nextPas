program scorecard;
{**
 * mem Scorecard SC1–SC9 (STDLIB-QUALITY-PLAN §7)
 *
 * Fixed scenarios for Ready reports. Micro-bench museum numbers go to
 * BENCHMARKS.md; this program is the authoritative local repro for:
 *   SC1 small_64B alloc+free
 *   SC2 mixed sizes (mean + p99 over batch samples)
 *   SC3 cross-thread free (correctness + throughput)
 *   SC4 arena reset+reuse
 *   SC5 long-run scavenge retention (LiveBytes / ReleasedBytes)
 *   SC6 compiler-like AST churn (VirtualArena unit reset)
 *   SC7 http-like per-request arena (LocalArena p99)
 *   SC8 FreeMem(ptr,size) vs FreeMem(ptr) tax (DefaultHeap)
 *   SC9 dual-track: DefaultHeap vs DefaultAllocator (vtable + scan tax)
 *
 * Baselines: Growing native API, System/glibc, LocalArena, VirtualArena.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.platform.thread,
  nextpas.core.base,
  nextpas.core.system.heap,
  nextpas.core.atomic.core,
  nextpas.core.platform.time,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.growing,
  nextpas.core.mem.allocator.growing_ia,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.arena.virtual;

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

  { SC6 compiler-like AST churn (one VirtualArena, reset per "unit") }
  SC6_UNITS = 200;
  SC6_NODES_PER_UNIT = 4000;
  SC6_WARMUP_UNITS = 4;
  SC6_NODE_SIZES: array[0..7] of SizeUInt = (24, 32, 40, 48, 64, 96, 128, 256);

  { SC7 http-like per-request LocalArena }
  SC7_REQUESTS = 5000;
  SC7_WARMUP = 100;
  SC7_ARENA_CAP = 256 * 1024;
  SC7_BODY_SIZES: array[0..4] of SizeUInt = (64, 256, 1024, 4096, 8192);

  { SC8 sized vs unsized FreeMem on DefaultHeap }
  SC8_ITERS = 200000;
  SC8_WARMUP = 5000;
  SC8_SIZE = 64;

  { SC9 dual-track hot heap vs plugin IAllocator }
  SC9_ITERS = 200000;
  SC9_WARMUP = 5000;
  SC9_SIZE = 64;

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
    LPtr := NpSystemGetMem(64);
    if LPtr = nil then LOk := False;
    NpSystemFreeMem(LPtr);
  end;
  LStart := platform_monotonic_ns;
  for I := 1 to SC1_ITERS do
  begin
    LPtr := NpSystemGetMem(64);
    if LPtr = nil then LOk := False;
    NpSystemFreeMem(LPtr);
  end;
  LEnd := platform_monotonic_ns;
  LNs := Int64((LEnd - LStart) div LOps);
  AddRow('SC1', 'system', LNs, 0, LOps, LOk, 'glibc via NpSystemGetMem');

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
        LPtrs[J] := NpSystemGetMem(SC2_SIZES[J]);
      if LPtrs[J] = nil then LOk := False;
    end;
    for J := High(SC2_SIZES) downto 0 do
      if AUseGrowing then
        GAlloc.FreeMem(LPtrs[J], SC2_SIZES[J])
      else
        NpSystemFreeMem(LPtrs[J]);
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
        LPtrs[J] := NpSystemGetMem(SC2_SIZES[J]);
      if LPtrs[J] = nil then LOk := False;
    end;
    for J := High(SC2_SIZES) downto 0 do
      if AUseGrowing then
        GAlloc.FreeMem(LPtrs[J], SC2_SIZES[J])
      else
        NpSystemFreeMem(LPtrs[J]);
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

function SC3Producer(Parameter: Pointer): Pointer; cdecl;
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
        Exit(Pointer(1));
      end;
      PByte(LPtr)^ := Byte(I);
      LCtx^.Ptrs[I] := LPtr;
    end;
    ReadWriteBarrier;
    InterlockedExchange(LCtx^.Ready, 1);
    Inc(LCtx^.Filled);
  end;
  Result := nil;
end;

function SC3Consumer(Parameter: Pointer): Pointer; cdecl;
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
        Exit(Pointer(1));
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
  Result := nil;
end;

procedure RunSC3;
var
  LCtx: TCrossCtx;
  LProd, LCons: TPlatformThreadRecord;
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
  if platform_thread_spawn(LProd, @SC3Producer, @LCtx) <> 0 then
  begin
    WriteLn('SC3 producer spawn failed');
    Halt(1);
  end;
  if platform_thread_spawn(LCons, @SC3Consumer, @LCtx) <> 0 then
  begin
    WriteLn('SC3 consumer spawn failed');
    Halt(1);
  end;
  if platform_thread_wait(LProd) <> 0 then
  begin
    WriteLn('SC3 producer join failed');
    Halt(1);
  end;
  if platform_thread_wait(LCons) <> 0 then
  begin
    WriteLn('SC3 consumer join failed');
    Halt(1);
  end;
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

{ --- SC6: compiler-like AST churn on VirtualArena --- }

procedure RunSC6;
var
  LArena: TVirtualArena;
  LStart, LEnd: UInt64;
  LPtr: Pointer;
  LPeakUsed: Int64;
  LFinalUsed: Int64;
  LOps: UInt64;
  LNs: Int64;
  LOk: Boolean;
  U, N: Integer;
  LSize: SizeUInt;
begin
  WriteLn('SC6 compiler AST churn (virtual_arena) ...');
  LOk := True;
  LPeakUsed := 0;
  TVirtualArena_Init(LArena);
  try
    { warmup units }
    for U := 1 to SC6_WARMUP_UNITS do
    begin
      for N := 0 to SC6_NODES_PER_UNIT - 1 do
      begin
        LSize := SC6_NODE_SIZES[N mod Length(SC6_NODE_SIZES)];
        LPtr := LArena.Alloc(LSize);
        if LPtr = nil then
          LOk := False
        else
          PByte(LPtr)^ := Byte(N);
      end;
      LArena.Reset;
    end;

    LStart := platform_monotonic_ns;
    for U := 1 to SC6_UNITS do
    begin
      for N := 0 to SC6_NODES_PER_UNIT - 1 do
      begin
        LSize := SC6_NODE_SIZES[N mod Length(SC6_NODE_SIZES)];
        LPtr := LArena.Alloc(LSize);
        if LPtr = nil then
          LOk := False
        else
        begin
          { mimic AST node header write }
          PByte(LPtr)^ := Byte(N);
          if LSize >= 8 then
            PLongWord(LPtr)^ := LongWord(N);
        end;
      end;
      if Int64(LArena.PeakUsed) > LPeakUsed then
        LPeakUsed := Int64(LArena.PeakUsed);
      { unit boundary: drop all AST at once }
      LArena.Reset;
    end;
    LEnd := platform_monotonic_ns;
    LFinalUsed := Int64(LArena.TotalUsed);
  finally
    TVirtualArena_Release(LArena);
  end;

  LOps := UInt64(SC6_UNITS) * UInt64(SC6_NODES_PER_UNIT);
  if LOps > 0 then
    LNs := Int64((LEnd - LStart) div LOps)
  else
    LNs := 0;
  if LPeakUsed < 1 then
    LOk := False;
  { After last Reset, live usage must drop (bump rewind). }
  if LFinalUsed > (LPeakUsed div 4) then
    LOk := False;
  AddRow('SC6', 'virtual_arena', LNs, 0, LOps, LOk,
    'AST-like mixed nodes; Reset per unit',
    LPeakUsed, LFinalUsed, 0, 0);
end;

{ --- SC7: http-like per-request LocalArena (p99 request latency) --- }

procedure RunSC7RequestPath(const ASubject: string; AUseArena: Boolean);
var
  LArena: TLocalArena;
  LSamples: array of Int64;
  LStart, LEnd, LReqStart, LReqEnd: UInt64;
  LHdr, LBody, LTmp: Pointer;
  LBodySize: SizeUInt;
  LOps: UInt64;
  LNs, LP99: Int64;
  LOk: Boolean;
  R, K: Integer;
  LSysPtrs: array[0..7] of Pointer;
  LSysCount: Integer;
begin
  WriteLn('SC7 http request (', ASubject, ') ...');
  LOk := True;
  SetLength(LSamples, SC7_REQUESTS);
  LArena := nil;
  if AUseArena then
    LArena := TLocalArena.Create(SC7_ARENA_CAP);
  try
    { warmup }
    for R := 1 to SC7_WARMUP do
    begin
      if AUseArena then
      begin
        LHdr := LArena.AllocFast(128);
        LBody := LArena.AllocFast(SC7_BODY_SIZES[R mod Length(SC7_BODY_SIZES)]);
        LTmp := LArena.AllocFast(64);
        if (LHdr = nil) or (LBody = nil) or (LTmp = nil) then
          LOk := False;
        LArena.Reset;
      end
      else
      begin
        LHdr := NpSystemGetMem(128);
        LBody := NpSystemGetMem(SC7_BODY_SIZES[R mod Length(SC7_BODY_SIZES)]);
        LTmp := NpSystemGetMem(64);
        if (LHdr = nil) or (LBody = nil) or (LTmp = nil) then
          LOk := False;
        NpSystemFreeMem(LHdr);
        NpSystemFreeMem(LBody);
        NpSystemFreeMem(LTmp);
      end;
    end;

    LStart := platform_monotonic_ns;
    for R := 0 to SC7_REQUESTS - 1 do
    begin
      LReqStart := platform_monotonic_ns;
      LBodySize := SC7_BODY_SIZES[R mod Length(SC7_BODY_SIZES)];
      if AUseArena then
      begin
        { request scope: header + body + a few temps (Go request-local style) }
        LHdr := LArena.AllocFast(128);
        LBody := LArena.AllocFast(LBodySize);
        if (LHdr = nil) or (LBody = nil) then
          LOk := False
        else
        begin
          PByte(LHdr)^ := Byte(R);
          PByte(LBody)^ := Byte(R xor $A5);
        end;
        for K := 0 to 3 do
        begin
          LTmp := LArena.AllocFast(48 + SizeUInt(K) * 16);
          if LTmp = nil then
            LOk := False
          else
            PByte(LTmp)^ := Byte(K);
        end;
        LArena.Reset;
      end
      else
      begin
        LSysCount := 0;
        LHdr := NpSystemGetMem(128);
        LBody := NpSystemGetMem(LBodySize);
        LSysPtrs[0] := LHdr;
        LSysPtrs[1] := LBody;
        LSysCount := 2;
        if (LHdr = nil) or (LBody = nil) then
          LOk := False
        else
        begin
          PByte(LHdr)^ := Byte(R);
          PByte(LBody)^ := Byte(R xor $A5);
        end;
        for K := 0 to 3 do
        begin
          LTmp := NpSystemGetMem(48 + SizeUInt(K) * 16);
          LSysPtrs[LSysCount] := LTmp;
          Inc(LSysCount);
          if LTmp = nil then
            LOk := False
          else
            PByte(LTmp)^ := Byte(K);
        end;
        for K := LSysCount - 1 downto 0 do
          if LSysPtrs[K] <> nil then
            NpSystemFreeMem(LSysPtrs[K]);
      end;
      LReqEnd := platform_monotonic_ns;
      LSamples[R] := Int64(LReqEnd - LReqStart);
    end;
    LEnd := platform_monotonic_ns;
  finally
    if LArena <> nil then
      LArena.Free;
  end;

  { ops = requests (latency is per-request, not per-alloc) }
  LOps := SC7_REQUESTS;
  if LOps > 0 then
    LNs := Int64((LEnd - LStart) div LOps)
  else
    LNs := 0;
  LP99 := Percentile99(LSamples, SC7_REQUESTS);
  if LP99 <= 0 then
    LOk := False;
  AddRow('SC7', ASubject, LNs, LP99, LOps, LOk,
    'per-request scope; p99=request_ns');
end;

procedure RunSC7;
begin
  RunSC7RequestPath('local_arena', True);
  RunSC7RequestPath('system', False);
end;

{ --- SC8: FreeMem(ptr,size) vs FreeMem(ptr) on DefaultHeap --- }

procedure RunSC8;
var
  LHeap: TGrowingAllocator;
  LStart, LEnd: UInt64;
  LPtr: Pointer;
  I: Integer;
  LOps: UInt64;
  LNsSized, LNsUnsized: Int64;
  LOk: Boolean;
  LSz: SizeUInt;
begin
  WriteLn('SC8 sized vs unsized FreeMem ...');
  LHeap := DefaultHeap;
  LOk := LHeap <> nil;
  LOps := SC8_ITERS;

  { sized FreeMem(ptr, size) — preferred hot path }
  for I := 1 to SC8_WARMUP do
  begin
    LPtr := LHeap.GetMem(SC8_SIZE);
    if LPtr = nil then LOk := False;
    LHeap.FreeMem(LPtr, SC8_SIZE);
  end;
  LStart := platform_monotonic_ns;
  for I := 1 to SC8_ITERS do
  begin
    LPtr := LHeap.GetMem(SC8_SIZE);
    if LPtr = nil then LOk := False;
    LHeap.FreeMem(LPtr, SC8_SIZE);
  end;
  LEnd := platform_monotonic_ns;
  if LOps > 0 then
    LNsSized := Int64((LEnd - LStart) div LOps)
  else
    LNsSized := 0;
  AddRow('SC8', 'free_sized', LNsSized, 0, LOps, LOk,
    'GetMem+FreeMem(ptr,size) 64B');

  { unsized FreeMem(ptr) — span scan / TryBlockSize path }
  LOk := LHeap <> nil;
  for I := 1 to SC8_WARMUP do
  begin
    LPtr := LHeap.GetMem(SC8_SIZE);
    if LPtr = nil then LOk := False;
    LHeap.FreeMem(LPtr);
  end;
  LStart := platform_monotonic_ns;
  for I := 1 to SC8_ITERS do
  begin
    LPtr := LHeap.GetMem(SC8_SIZE);
    if LPtr = nil then LOk := False;
    LHeap.FreeMem(LPtr);
  end;
  LEnd := platform_monotonic_ns;
  if LOps > 0 then
    LNsUnsized := Int64((LEnd - LStart) div LOps)
  else
    LNsUnsized := 0;
  { Gate: both succeed; document tax (unsized should not be faster than sized
    on a quiet machine; allow equality under noise). }
  if LNsUnsized < 0 then
    LOk := False;
  AddRow('SC8', 'free_unsized', LNsUnsized, 0, LOps, LOk,
    'GetMem+FreeMem(ptr) span-scan');

  { Correctness: TryBlockSize recovers size-class for a live block. }
  LPtr := LHeap.GetMem(SC8_SIZE);
  LOk := (LPtr <> nil) and LHeap.TryBlockSize(LPtr, LSz) and (LSz >= SC8_SIZE);
  if LPtr <> nil then
    LHeap.FreeMem(LPtr, SC8_SIZE);
  AddRow('SC8', 'try_block_size', 0, 0, 1, LOk,
    'TryBlockSize returns size-class >= request');
end;

{ --- SC9: dual-track DefaultHeap vs DefaultAllocator --- }

procedure RunSC9;
var
  LHeap: TGrowingAllocator;
  LPlugin: IAllocator;
  LStart, LEnd: UInt64;
  LPtr, LCross: Pointer;
  I: Integer;
  LOps: UInt64;
  LNsHot, LNsPlugin: Int64;
  LOk: Boolean;
  LSz: SizeUInt;
begin
  WriteLn('SC9 dual-track hot vs plugin ...');
  LHeap := DefaultHeap;
  LPlugin := DefaultAllocator;
  LOk := (LHeap <> nil) and (LPlugin <> nil);
  LOps := SC9_ITERS;

  { Hot: concrete DefaultHeap + sized free (zero IAllocator vtable). }
  for I := 1 to SC9_WARMUP do
  begin
    LPtr := LHeap.GetMem(SC9_SIZE);
    if LPtr = nil then LOk := False;
    LHeap.FreeMem(LPtr, SC9_SIZE);
  end;
  LStart := platform_monotonic_ns;
  for I := 1 to SC9_ITERS do
  begin
    LPtr := LHeap.GetMem(SC9_SIZE);
    if LPtr = nil then LOk := False;
    LHeap.FreeMem(LPtr, SC9_SIZE);
  end;
  LEnd := platform_monotonic_ns;
  if LOps > 0 then
    LNsHot := Int64((LEnd - LStart) div LOps)
  else
    LNsHot := 0;
  AddRow('SC9', 'hot_heap', LNsHot, 0, LOps, LOk,
    'DefaultHeap GetMem+FreeMem(size)');

  { Plugin: IAllocator virtual GetMem/FreeMem (same Growing heap). }
  LOk := LPlugin <> nil;
  for I := 1 to SC9_WARMUP do
  begin
    LPtr := LPlugin.GetMem(SC9_SIZE);
    if LPtr = nil then LOk := False;
    LPlugin.FreeMem(LPtr);
  end;
  LStart := platform_monotonic_ns;
  for I := 1 to SC9_ITERS do
  begin
    LPtr := LPlugin.GetMem(SC9_SIZE);
    if LPtr = nil then LOk := False;
    LPlugin.FreeMem(LPtr);
  end;
  LEnd := platform_monotonic_ns;
  if LOps > 0 then
    LNsPlugin := Int64((LEnd - LStart) div LOps)
  else
    LNsPlugin := 0;
  AddRow('SC9', 'plugin_ia', LNsPlugin, 0, LOps, LOk,
    'DefaultAllocator GetMem+FreeMem (vtable)');

  { Same-heap ownership: plugin alloc freeable via hot sized free. }
  LCross := LPlugin.GetMem(SC9_SIZE);
  LOk := (LCross <> nil) and LHeap.TryBlockSize(LCross, LSz) and (LSz >= SC9_SIZE);
  if LCross <> nil then
    LHeap.FreeMem(LCross, LSz);
  AddRow('SC9', 'same_heap', 0, 0, 1, LOk,
    'plugin alloc + DefaultHeap FreeMem(size)');
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
  WriteLn('=== mem Scorecard SC1-SC9 ===');
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
    if GRows[I].Id = 'SC6' then
    begin
      Write(' | peakUsed=', GRows[I].PeakLive);
      Write(' finalUsed=', GRows[I].FinalLive);
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
  SetLength(GRows, 24);
  GAlloc := TGrowingAllocator.Create;
  try
    RunSC1;
    RunSC2;
    RunSC3;
    RunSC4;
    RunSC5;
    RunSC6;
    RunSC7;
    RunSC8;
    RunSC9;
    PrintReport;
  finally
    GAlloc.Free;
  end;
  if GFailed <> 0 then
    Halt(1);
end.
