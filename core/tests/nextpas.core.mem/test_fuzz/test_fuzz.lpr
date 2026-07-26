program test_fuzz;
{ Randomized stress tests for mem subsystem (F-21).
  Fixed seed for reproducibility. Validates no crashes, no leaks, no corruption. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.arena.chunked,
  nextpas.core.mem.pool,
  nextpas.core.mem.pool.slab,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.allocator,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.tracking,
  nextpas.core.mem; { last so procedural GetMem/FreeMem resolve to the facade, not FPC System }

var
  T: TTestSuite;
  LRunPassed: Boolean;

const
  SEED = 12345;
  FUZZ_ITERATIONS = 2000;

{ --- LCG random number generator (deterministic, no external deps) --- }

var
  GRngState: UInt32;

procedure RngSeed(ASeed: UInt32);
begin
  GRngState := ASeed;
end;

function RngNext: UInt32;
begin
  GRngState := GRngState * 1103515245 + 12345;
  Result := GRngState;
end;

function RngRange(AMax: Integer): Integer;
begin
  Result := Integer(RngNext mod UInt32(AMax));
end;

{ --- Fuzz TLocalArena --- }

procedure TestFuzzLocalArena;
var
  LArena: TLocalArena;
  LPtrs: array[0..63] of Pointer;
  LCount: Integer;
  LI, LOp, LIdx, LSize: Integer;
begin
  RngSeed(SEED);
  LArena := TLocalArena.Create(64 * 1024); // 64KB
  try
    LCount := 0;
    for LI := 1 to FUZZ_ITERATIONS do
    begin
      LOp := RngRange(10);
      if (LOp < 7) or (LCount = 0) then
      begin
        { Allocate }
        if LCount < 64 then
        begin
          LSize := RngRange(512) + 1;
          LPtrs[LCount] := LArena.Alloc(SizeUInt(LSize));
          if LPtrs[LCount] <> nil then
          begin
            { Write pattern to detect corruption }
            FillChar(LPtrs[LCount]^, LSize, Byte(LI and $FF));
            Inc(LCount);
          end;
        end;
      end
      else if LOp < 9 then
      begin
        { Reset and start over }
        LArena.Reset;
        LCount := 0;
      end
      else
      begin
        { SaveMark/RestoreToMark }
        if LCount > 0 then
        begin
          LIdx := RngRange(LCount);
          { Restore to a random point — just verify no crash }
          LArena.RestoreToMark(LArena.SaveMark);
        end;
      end;
    end;
    Check(LArena.UsedSize <= LArena.Capacity, 'fuzz: used <= capacity');
    WriteLn('PASS: fuzz TLocalArena (', FUZZ_ITERATIONS, ' iterations, ', LCount, ' live)');
  finally
    LArena.Free;
  end;
end;

{ --- Fuzz TChunkedArena --- }

procedure TestFuzzChunkedArena;
var
  LArena: TChunkedArena;
  LPtrs: array[0..127] of Pointer;
  LCount: Integer;
  LI, LOp, LIdx, LSize: Integer;
  LMark: TArenaMark;
begin
  RngSeed(SEED + 1);
  LArena := TChunkedArena.Create(4096, 256 * 1024); // 4KB initial, 256KB max
  try
    LCount := 0;
    for LI := 1 to FUZZ_ITERATIONS do
    begin
      LOp := RngRange(10);
      if (LOp < 6) or (LCount = 0) then
      begin
        { Allocate }
        if LCount < 128 then
        begin
          LSize := RngRange(1024) + 1;
          LPtrs[LCount] := LArena.Alloc(SizeUInt(LSize));
          if LPtrs[LCount] <> nil then
          begin
            FillChar(LPtrs[LCount]^, LSize, Byte(LI and $FF));
            Inc(LCount);
          end;
        end;
      end
      else if LOp < 8 then
      begin
        { SaveMark }
        LMark := LArena.SaveMark;
        { Allocate some more }
        for LIdx := 0 to RngRange(5) do
        begin
          LSize := RngRange(256) + 1;
          LArena.Alloc(SizeUInt(LSize));
        end;
        { Restore }
        LArena.RestoreToMark(LMark);
      end
      else
      begin
        { Reset }
        LArena.Reset;
        LCount := 0;
      end;
    end;
    Check(LArena.UsedSize <= LArena.Stats.TotalAllocated, 'fuzz chunked: used <= total');
    WriteLn('PASS: fuzz TChunkedArena (', FUZZ_ITERATIONS, ' iterations, segs=',
      LArena.SegmentCount, ')');
  finally
    LArena.Free;
  end;
end;

{ --- Fuzz TLocalBlockPool --- }

procedure TestFuzzBlockPool;
var
  LPool: TLocalBlockPool;
  LPtrs: array[0..255] of Pointer;
  LCount: Integer;
  LI, LOp, LIdx: Integer;
begin
  RngSeed(SEED + 2);
  LPool := TLocalBlockPool.Create(64, 256); // 64-byte blocks, 256 count
  try
    LCount := 0;
    for LI := 1 to FUZZ_ITERATIONS do
    begin
      LOp := RngRange(10);
      if (LOp < 6) or (LCount = 0) then
      begin
        { Acquire }
        if LCount < 256 then
        begin
          LPtrs[LCount] := LPool.Acquire;
          if LPtrs[LCount] <> nil then
          begin
            FillChar(LPtrs[LCount]^, 64, Byte(LI and $FF));
            Inc(LCount);
          end;
        end;
      end
      else if LOp < 9 then
      begin
        { Release random }
        if LCount > 0 then
        begin
          LIdx := RngRange(LCount);
          LPool.Release(LPtrs[LIdx]);
          { Compact array }
          LPtrs[LIdx] := LPtrs[LCount - 1];
          Dec(LCount);
        end;
      end
      else
      begin
        { Reset }
        LPool.Reset;
        LCount := 0;
      end;
    end;
    Check(LPool.InUse = SizeUInt(LCount), 'fuzz blockpool: inuse matches');
    WriteLn('PASS: fuzz TLocalBlockPool (', FUZZ_ITERATIONS, ' iterations, ',
      LCount, ' live)');
  finally
    LPool.Free;
  end;
end;

{ --- Fuzz TSlabPool --- }

procedure TestFuzzSlabPool;
var
  LPool: TSlabPool;
  LPtrs: array[0..511] of Pointer;
  LSizes: array[0..511] of SizeUInt;
  LCount: Integer;
  LI, LOp, LIdx, LSize: Integer;
begin
  RngSeed(SEED + 3);
  LPool := TSlabPool.Create(16 * 1024); // 16KB initial
  try
    LCount := 0;
    for LI := 1 to FUZZ_ITERATIONS do
    begin
      LOp := RngRange(10);
      if (LOp < 6) or (LCount = 0) then
      begin
        { GetMem with random size }
        if LCount < 512 then
        begin
          LSize := RngRange(2048) + 1;
          LPtrs[LCount] := LPool.GetMem(SizeUInt(LSize));
          if LPtrs[LCount] <> nil then
          begin
            LSizes[LCount] := SizeUInt(LSize);
            FillChar(LPtrs[LCount]^, LSize, Byte(LI and $FF));
            Inc(LCount);
          end;
        end;
      end
      else if LOp < 9 then
      begin
        { FreeMem random }
        if LCount > 0 then
        begin
          LIdx := RngRange(LCount);
          LPool.FreeMem(LPtrs[LIdx]);
          LPtrs[LIdx] := LPtrs[LCount - 1];
          LSizes[LIdx] := LSizes[LCount - 1];
          Dec(LCount);
        end;
      end
      else
      begin
        { ReallocMem random }
        if LCount > 0 then
        begin
          LIdx := RngRange(LCount);
          LSize := RngRange(4096) + 1;
          LPtrs[LIdx] := LPool.ReallocMem(LPtrs[LIdx], SizeUInt(LSize));
          if LPtrs[LIdx] <> nil then
            LSizes[LIdx] := SizeUInt(LSize)
          else
          begin
            LPtrs[LIdx] := LPtrs[LCount - 1];
            LSizes[LIdx] := LSizes[LCount - 1];
            Dec(LCount);
          end;
        end;
      end;
    end;
    WriteLn('PASS: fuzz TSlabPool (', FUZZ_ITERATIONS, ' iterations, ',
      LCount, ' live, segs=', LPool.SegmentCount, ')');
  finally
    LPool.Free;
  end;
end;

{ --- Fuzz Growing default heap (content-verified churn) ---
  Unlike the write-only fuzzes above, every live block carries a deterministic
  byte pattern that is fully re-read before free/realloc: catches block overlap,
  TLS-cache cross-wiring and span bitmap bugs, not just crashes. }

procedure FillPattern(APtr: Pointer; ASize: SizeUInt; ATag: Byte);
var
  LB: PByte;
  LI: SizeUInt;
begin
  LB := PByte(APtr);
  for LI := 0 to ASize - 1 do
    LB[LI] := Byte((SizeUInt(ATag) + LI) and $FF);
end;

function PatternIntact(APtr: Pointer; ASize: SizeUInt; ATag: Byte): Boolean;
var
  LB: PByte;
  LI: SizeUInt;
begin
  Result := False;
  LB := PByte(APtr);
  for LI := 0 to ASize - 1 do
    if LB[LI] <> Byte((SizeUInt(ATag) + LI) and $FF) then
      Exit;
  Result := True;
end;

function RngFuzzSize: Integer;
begin
  { Mixed distribution: small classes, mid classes, and >57344 huge path }
  case RngRange(10) of
    0..5: Result := RngRange(256) + 1;
    6..8: Result := RngRange(3840) + 257;
  else
    Result := RngRange(65536) + 4097; { crosses MEM_SIZECLASS_MAX huge path }
  end;
end;

procedure TestFuzzGrowingHeap;
var
  LPtrs: array[0..383] of Pointer;
  LSizes: array[0..383] of SizeUInt;
  LTags: array[0..383] of Byte;
  LCount: Integer;
  LI, LOp, LIdx, LSize: Integer;
  LNewSize, LProbe, LKeep: SizeUInt;
  LNew: Pointer;
begin
  RngSeed(SEED + 7);
  Check(GetMem(0) = nil, 'fuzz growing: GetMem(0) = nil');
  FreeMem(nil); { contract: silent no-op }
  LCount := 0;
  for LI := 1 to FUZZ_ITERATIONS do
  begin
    LOp := RngRange(20);
    if (LOp < 10) or (LCount = 0) then
    begin
      if LCount < 384 then
      begin
        LSize := RngFuzzSize;
        LPtrs[LCount] := GetMem(SizeUInt(LSize));
        if LPtrs[LCount] <> nil then
        begin
          LSizes[LCount] := SizeUInt(LSize);
          LTags[LCount] := Byte(RngNext and $FF);
          FillPattern(LPtrs[LCount], LSizes[LCount], LTags[LCount]);
          Inc(LCount);
        end;
      end;
    end
    else if LOp < 14 then
    begin
      { Sized free (hot path) — verify content first }
      LIdx := RngRange(LCount);
      Check(PatternIntact(LPtrs[LIdx], LSizes[LIdx], LTags[LIdx]),
        'fuzz growing: pattern intact before sized free');
      FreeMem(LPtrs[LIdx], LSizes[LIdx]);
      LPtrs[LIdx] := LPtrs[LCount - 1];
      LSizes[LIdx] := LSizes[LCount - 1];
      LTags[LIdx] := LTags[LCount - 1];
      Dec(LCount);
    end
    else if LOp < 16 then
    begin
      { Unsized free (scan/fallback path) — verify content first }
      LIdx := RngRange(LCount);
      Check(PatternIntact(LPtrs[LIdx], LSizes[LIdx], LTags[LIdx]),
        'fuzz growing: pattern intact before unsized free');
      FreeMem(LPtrs[LIdx]);
      LPtrs[LIdx] := LPtrs[LCount - 1];
      LSizes[LIdx] := LSizes[LCount - 1];
      LTags[LIdx] := LTags[LCount - 1];
      Dec(LCount);
    end
    else if LOp < 18 then
    begin
      { Sized realloc — old content verified, then min(old,new) prefix must survive }
      LIdx := RngRange(LCount);
      Check(PatternIntact(LPtrs[LIdx], LSizes[LIdx], LTags[LIdx]),
        'fuzz growing: pattern intact before realloc');
      LNewSize := SizeUInt(RngFuzzSize);
      LNew := ReallocMem(LPtrs[LIdx], LSizes[LIdx], LNewSize);
      if LNew <> nil then
      begin
        LKeep := LSizes[LIdx];
        if LNewSize < LKeep then
          LKeep := LNewSize;
        Check(PatternIntact(LNew, LKeep, LTags[LIdx]),
          'fuzz growing: realloc preserves min(old,new) prefix');
        LPtrs[LIdx] := LNew;
        LSizes[LIdx] := LNewSize;
        LTags[LIdx] := Byte(RngNext and $FF);
        FillPattern(LPtrs[LIdx], LSizes[LIdx], LTags[LIdx]);
      end
      else
      begin
        { OOM contract: original block untouched — drop it via sized free }
        FreeMem(LPtrs[LIdx], LSizes[LIdx]);
        LPtrs[LIdx] := LPtrs[LCount - 1];
        LSizes[LIdx] := LSizes[LCount - 1];
        LTags[LIdx] := LTags[LCount - 1];
        Dec(LCount);
      end;
    end
    else if LOp = 18 then
    begin
      { TryBlockSize invariant: recovered size >= requested size }
      LIdx := RngRange(LCount);
      if TryBlockSize(LPtrs[LIdx], LProbe) then
        Check(LProbe >= LSizes[LIdx],
          'fuzz growing: TryBlockSize >= requested size');
    end
    else
      DefaultHeap.Scavenge; { force span release/reuse under churn }
  end;
  { Drain: verify + free every survivor }
  for LIdx := 0 to LCount - 1 do
  begin
    Check(PatternIntact(LPtrs[LIdx], LSizes[LIdx], LTags[LIdx]),
      'fuzz growing: pattern intact at drain');
    FreeMem(LPtrs[LIdx], LSizes[LIdx]);
  end;
  DefaultHeap.Scavenge;
  WriteLn('PASS: fuzz Growing heap (', FUZZ_ITERATIONS,
    ' iterations, content-verified)');
end;

{ --- Fuzz Growing realloc chain across size-class boundaries --- }

procedure TestFuzzGrowingReallocChain;
var
  LPtr, LNew: Pointer;
  LSize, LNewSize, LKeep: SizeUInt;
  LTag: Byte;
  LI: Integer;
begin
  RngSeed(SEED + 8);
  LSize := 16;
  LPtr := GetMem(LSize);
  Check(LPtr <> nil, 'fuzz realloc chain: initial alloc');
  LTag := $5A;
  FillPattern(LPtr, LSize, LTag);
  for LI := 1 to 400 do
  begin
    LNewSize := SizeUInt(RngFuzzSize);
    LNew := ReallocMem(LPtr, LSize, LNewSize);
    if LNew = nil then
      Break; { OOM: original still owned, freed below }
    LKeep := LSize;
    if LNewSize < LKeep then
      LKeep := LNewSize;
    Check(PatternIntact(LNew, LKeep, LTag),
      'fuzz realloc chain: prefix preserved step ' + IntToStr(LI));
    LPtr := LNew;
    LSize := LNewSize;
    LTag := Byte((SizeUInt(LTag) + 1) and $FF);
    FillPattern(LPtr, LSize, LTag);
  end;
  FreeMem(LPtr, LSize);
  WriteLn('PASS: fuzz Growing realloc chain (400 steps, prefix-verified)');
end;

{ --- Fuzz IAllocator via TTrackingAllocator (leak detection) --- }

procedure TestFuzzAllocatorLeakCheck;
var
  LTracker: TTrackingAllocator;
  LRtl: IAllocator;
  LPtrs: array[0..255] of Pointer;
  LCount: Integer;
  LI, LOp, LIdx, LSize: Integer;
begin
  RngSeed(SEED + 4);
  LRtl := nextpas.core.mem.allocator.GetRtlAllocator;
  LTracker := TTrackingAllocator.Create(LRtl);
  try
    LCount := 0;
    for LI := 1 to 500 do
    begin
      LOp := RngRange(10);
      if (LOp < 6) or (LCount = 0) then
      begin
        if LCount < 256 then
        begin
          LSize := RngRange(4096) + 1;
          LPtrs[LCount] := LTracker.GetMem(SizeUInt(LSize));
          if LPtrs[LCount] <> nil then
          begin
            FillChar(LPtrs[LCount]^, LSize, Byte(LI and $FF));
            Inc(LCount);
          end;
        end;
      end
      else if LOp < 9 then
      begin
        if LCount > 0 then
        begin
          LIdx := RngRange(LCount);
          LTracker.FreeMem(LPtrs[LIdx]);
          LPtrs[LIdx] := LPtrs[LCount - 1];
          Dec(LCount);
        end;
      end
      else
      begin
        { ReallocMem }
        if LCount > 0 then
        begin
          LIdx := RngRange(LCount);
          LSize := RngRange(8192) + 1;
          LPtrs[LIdx] := LTracker.ReallocMem(LPtrs[LIdx], SizeUInt(LSize));
          if LPtrs[LIdx] = nil then
          begin
            LPtrs[LIdx] := LPtrs[LCount - 1];
            Dec(LCount);
          end;
        end;
      end;
    end;
    { Free all remaining to verify tracker consistency }
    for LIdx := 0 to LCount - 1 do
      LTracker.FreeMem(LPtrs[LIdx]);
    Check(not LTracker.HasLeaks, 'fuzz allocator: no leaks after free-all');
    WriteLn('PASS: fuzz TTrackingAllocator (500 iterations, 0 leaks)');
  finally
    LTracker.Free;
  end;
end;

{ --- Fuzz Arena AllocAligned --- }

procedure TestFuzzArenaAligned;
var
  LArena: TLocalArena;
  LI, LSize, LAlign: Integer;
  LPtr: Pointer;
  LFailCount: Integer;
begin
  RngSeed(SEED + 5);
  LArena := TLocalArena.Create(128 * 1024); // 128KB
  try
    LFailCount := 0;
    for LI := 1 to 1000 do
    begin
      LSize := RngRange(512) + 1;
      LAlign := 1 shl (RngRange(5) + 2); // 4, 8, 16, 32, 64
      LPtr := LArena.AllocAligned(SizeUInt(LSize), SizeUInt(LAlign));
      if LPtr <> nil then
      begin
        Check((PtrUInt(LPtr) and PtrUInt(LAlign - 1)) = 0,
          'fuzz aligned: pointer aligned to ' + IntToStr(LAlign));
        FillChar(LPtr^, LSize, Byte(LI and $FF));
      end
      else
        Inc(LFailCount);
    end;
    WriteLn('PASS: fuzz Arena AllocAligned (1000 allocs, ', LFailCount, ' nil)');
  finally
    LArena.Free;
  end;
end;

{ --- Mixed allocator fuzz: Arena + Pool in same session --- }

procedure TestFuzzMixedAllocators;
var
  LArena: TChunkedArena;
  LPool: TLocalBlockPool;
  LI, LOp: Integer;
  LArenaPtr, LPoolPtr: Pointer;
begin
  RngSeed(SEED + 6);
  LArena := TChunkedArena.Create(8192);
  LPool := TLocalBlockPool.Create(128, 64);
  try
    for LI := 1 to 1000 do
    begin
      LOp := RngRange(4);
      case LOp of
        0: begin
          LArenaPtr := LArena.Alloc(SizeUInt(RngRange(256) + 1));
          if LArenaPtr <> nil then
            FillChar(LArenaPtr^, 64, $AA);
        end;
        1: begin
          LPoolPtr := LPool.Acquire;
          if LPoolPtr <> nil then
            FillChar(LPoolPtr^, 128, $BB);
        end;
        2: LArena.Reset;
        3: LPool.Release(LPool.Acquire); // acquire+immediate release
      end;
    end;
    WriteLn('PASS: fuzz mixed allocators (1000 iterations)');
  finally
    LPool.Free;
    LArena.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.fuzz');
  T.Test('fuzz TLocalArena', @TestFuzzLocalArena);
  T.Test('fuzz TChunkedArena', @TestFuzzChunkedArena);
  T.Test('fuzz TLocalBlockPool', @TestFuzzBlockPool);
  T.Test('fuzz TSlabPool', @TestFuzzSlabPool);
  T.Test('fuzz Growing heap content-verified', @TestFuzzGrowingHeap);
  T.Test('fuzz Growing realloc chain', @TestFuzzGrowingReallocChain);
  T.Test('fuzz allocator leak-check', @TestFuzzAllocatorLeakCheck);
  T.Test('fuzz Arena AllocAligned', @TestFuzzArenaAligned);
  T.Test('fuzz mixed allocators', @TestFuzzMixedAllocators);
  LRunPassed := T.Run;

  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
