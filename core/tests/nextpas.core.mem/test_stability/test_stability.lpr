program test_stability;
{$mode ObjFPC}{$H+}

uses
  cthreads,
  SysUtils,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.sizeclass,
  nextpas.core.mem.span,
  nextpas.core.mem.cache.thread,
  nextpas.core.mem.allocator.growing;

var
  T: TTestSuite;

{ ── SpanFree double-free detection ── }

procedure TestSpanDoubleFreeDetection;
var
  LSpan: TSpan;
  LMem: array[0..4095] of Byte;
  LPtr1, LPtr2: Pointer;
begin
  SpanInit(LSpan, @LMem[0], 64, 16);
  { Allocate one slot. }
  LPtr1 := SpanAlloc(LSpan);
  Check(LPtr1 <> nil, 'alloc succeeds');
  Check(LSpan.FFreeCount = 15, 'free count = 15 after alloc');
  { Free it — should succeed. }
  Check(SpanFree(LSpan, LPtr1), 'first free succeeds');
  Check(LSpan.FFreeCount = 16, 'free count = 16 after free');
  { Double-free — should fail (return False). }
  Check(not SpanFree(LSpan, LPtr1), 'double-free detected');
  Check(LSpan.FFreeCount = 16, 'free count unchanged after double-free');
  { Allocate again — should get the same slot back (no corruption). }
  LPtr2 := SpanAlloc(LSpan);
  Check(LPtr2 = LPtr1, 're-alloc returns same slot');
  SpanFree(LSpan, LPtr2);
  WriteLn('PASS: span double-free detection');
end;

{ ── SpanFree out-of-range detection ── }

procedure TestSpanOutOfRangeFree;
var
  LSpan: TSpan;
  LMem: array[0..4095] of Byte;
  LPtr: Pointer;
begin
  SpanInit(LSpan, @LMem[0], 64, 16);
  { Free a pointer outside the span's range. }
  LPtr := Pointer(PByte(@LMem[0]) + 4096);
  Check(not SpanFree(LSpan, LPtr), 'out-of-range free rejected');
  Check(LSpan.FFreeCount = 16, 'free count unchanged');
  { Free a pointer before the span's range. }
  LPtr := Pointer(PByte(@LMem[0]) - 64);
  Check(not SpanFree(LSpan, LPtr), 'before-range free rejected');
  WriteLn('PASS: span out-of-range free detection');
end;

{ ── SpanFree: all slots cycle ── }

procedure TestSpanAllSlotsCycle;
var
  LSpan: TSpan;
  LMem: array[0..8191] of Byte;
  LPtrs: array[0..63] of Pointer;
  I: Integer;
begin
  SpanInit(LSpan, @LMem[0], 128, 64);
  { Allocate all 64 slots. }
  for I := 0 to 63 do
  begin
    LPtrs[I] := SpanAlloc(LSpan);
    Check(LPtrs[I] <> nil, 'slot ' + IntToStr(I) + ' alloc');
  end;
  Check(LSpan.FFreeCount = 0, 'all slots used');
  Check(SpanAlloc(LSpan) = nil, 'no more slots');
  { Free all 64 slots. }
  for I := 0 to 63 do
    Check(SpanFree(LSpan, LPtrs[I]), 'slot ' + IntToStr(I) + ' free');
  Check(LSpan.FFreeCount = 64, 'all slots free');
  { Allocate all again — verify no corruption. }
  for I := 0 to 63 do
  begin
    LPtrs[I] := SpanAlloc(LSpan);
    Check(LPtrs[I] <> nil, 're-alloc slot ' + IntToStr(I));
  end;
  for I := 0 to 63 do
    SpanFree(LSpan, LPtrs[I]);
  WriteLn('PASS: span all 64 slots cycle');
end;

{ ── Growing allocator edge-case sizes ── }

procedure TestEdgeCaseSizes;
var
  LAlloc: TGrowingAllocator;
  LSizes: array[0..13] of SizeUInt;
  LPtrs: array[0..13] of Pointer;
  I: Integer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LSizes[0] := 1;
    LSizes[1] := 15;
    LSizes[2] := 16;
    LSizes[3] := 17;
    LSizes[4] := 255;
    LSizes[5] := 256;
    LSizes[6] := 257;
    LSizes[7] := 1023;
    LSizes[8] := 1024;
    LSizes[9] := 1025;
    LSizes[10] := 4096;
    LSizes[11] := 16384;
    LSizes[12] := MEM_SIZECLASS_MAX;
    LSizes[13] := MEM_SIZECLASS_MAX + 1;
    for I := 0 to 13 do
    begin
      LPtrs[I] := LAlloc.GetMem(LSizes[I]);
      Check(LPtrs[I] <> nil, 'alloc size ' + IntToStr(LSizes[I]));
      { Touch first and last byte. }
      PByte(LPtrs[I])^ := Byte(I);
      PByte(LPtrs[I])[LSizes[I] - 1] := Byte(I);
    end;
    { All distinct. }
    for I := 0 to 12 do
      Check(LPtrs[I] <> LPtrs[I + 1], 'distinct ' + IntToStr(I));
    for I := 0 to 13 do
      LAlloc.FreeMem(LPtrs[I], LSizes[I]);
    WriteLn('PASS: edge case sizes (1 to ' + IntToStr(MEM_SIZECLASS_MAX + 1) + ')');
  finally
    LAlloc.Free;
  end;
end;

{ ── ReallocMem literal constant correctness ── }

procedure TestReallocLiteralConstants;
var
  LAlloc: TGrowingAllocator;
  LPtr, LPtr2: PByte;
  I: Integer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    { Same class via literal constants — must be zero-copy. }
    LPtr := PByte(LAlloc.GetMem(50));
    for I := 0 to 49 do
      LPtr[I] := Byte(I);
    LPtr2 := PByte(LAlloc.ReallocMem(LPtr, 50, 60));
    Check(LPtr2 = LPtr, 'literal 50->60 zero-copy');
    for I := 0 to 49 do
      Check(LPtr2[I] = Byte(I), 'data preserved after 50->60');
    LAlloc.FreeMem(LPtr2, 60);

    { Same size via literal — must be zero-copy. }
    LPtr := PByte(LAlloc.GetMem(100));
    LPtr2 := PByte(LAlloc.ReallocMem(LPtr, 100, 100));
    Check(LPtr2 = LPtr, 'literal 100->100 zero-copy');
    LAlloc.FreeMem(LPtr2, 100);

    { Cross-band — must copy. }
    LPtr := PByte(LAlloc.GetMem(64));
    for I := 0 to 63 do
      LPtr[I] := Byte(I + 1);
    LPtr2 := PByte(LAlloc.ReallocMem(LPtr, 64, 2048));
    Check(LPtr2 <> nil, 'cross-band realloc non-nil');
    for I := 0 to 63 do
      Check(LPtr2[I] = Byte(I + 1), 'cross-band data preserved');
    LAlloc.FreeMem(LPtr2, 2048);

    WriteLn('PASS: realloc literal constants');
  finally
    LAlloc.Free;
  end;
end;

{ ── Stress: alloc/free 100K cycles ── }

procedure TestStressAllocFree;
var
  LAlloc: TGrowingAllocator;
  LPtrs: array[0..255] of Pointer;
  LSize: SizeUInt;
  I, J: Integer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    for I := 0 to 99999 do
    begin
      LSize := SizeUInt((I mod 7) + 1) * 16;
      for J := 0 to 255 do
      begin
        LPtrs[J] := LAlloc.GetMem(LSize);
        if LPtrs[J] = nil then
          Check(False, 'nil at iter ' + IntToStr(I) + ' slot ' + IntToStr(J));
        PByte(LPtrs[J])^ := Byte(I + J);
      end;
      for J := 0 to 255 do
        LAlloc.FreeMem(LPtrs[J], LSize);
    end;
    WriteLn('PASS: stress 100K x 256 alloc/free cycles');
  finally
    LAlloc.Free;
  end;
end;

{ ── Stress: mixed-size alloc/free ── }

procedure TestStressMixedSizes;
var
  LAlloc: TGrowingAllocator;
  LSizes: array[0..7] of SizeUInt = (16, 48, 128, 300, 800, 2048, 8192, 32768);
  LPtrs: array[0..63] of Pointer;
  I, J, K: Integer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    for I := 0 to 49999 do
    begin
      K := I mod 8;
      for J := 0 to 63 do
      begin
        LPtrs[J] := LAlloc.GetMem(LSizes[K]);
        Check(LPtrs[J] <> nil, 'mixed alloc');
        FillChar(LPtrs[J]^, LSizes[K], Byte(I));
      end;
      for J := 0 to 63 do
        LAlloc.FreeMem(LPtrs[J], LSizes[K]);
    end;
    WriteLn('PASS: stress 50K x 64 mixed-size alloc/free');
  finally
    LAlloc.Free;
  end;
end;

{ ── Stress: BatchGetMem/BatchFreeMem ── }

procedure TestStressBatch;
var
  LAlloc: TGrowingAllocator;
  LPtrs: array[0..127] of Pointer;
  LCount: Word;
  I: Integer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    for I := 0 to 9999 do
    begin
      LCount := LAlloc.BatchGetMem(128, 128, @LPtrs[0]);
      Check(LCount = 128, 'batch got 128');
      LAlloc.BatchFreeMem(128, 128, @LPtrs[0]);
    end;
    WriteLn('PASS: stress 10K x 128 batch alloc/free');
  finally
    LAlloc.Free;
  end;
end;

{ ── Stress: MixedBatch ── }

procedure TestStressMixedBatch;
var
  LAlloc: TGrowingAllocator;
  LSizes: array[0..7] of SizeUInt = (16, 32, 64, 128, 256, 512, 1024, 2048);
  LPtrs: array[0..7] of Pointer;
  I: Integer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    for I := 0 to 99999 do
    begin
      LAlloc.MixedBatch(@LSizes[0], 8, @LPtrs[0]);
      { All should be non-nil. }
      Check(LPtrs[0] <> nil, 'mixed batch[0]');
    end;
    WriteLn('PASS: stress 100K MixedBatch(8 sizes)');
  finally
    LAlloc.Free;
  end;
end;

{ ── Thread exit cleanup: verify no crash on thread exit ── }

type
  PThreadExitData = ^TThreadExitData;
  TThreadExitData = record
    Alloc: TGrowingAllocator;
    Done: Boolean;
  end;

function ThreadExitWorker(Parameter: Pointer): PtrInt;
var
  LData: PThreadExitData;
  LPtrs: array[0..63] of Pointer;
  I: Integer;
begin
  LData := PThreadExitData(Parameter);
  { Allocate and free within this thread to populate TLS cache. }
  for I := 0 to 63 do
    LPtrs[I] := LData^.Alloc.GetMem(64);
  for I := 0 to 63 do
    LData^.Alloc.FreeMem(LPtrs[I], 64);
  { Now allocate again but DON'T free — these stay in TLS cache. }
  for I := 0 to 63 do
    LPtrs[I] := LData^.Alloc.GetMem(64);
  { Thread exits here. The pthread destructor should flush the TLS cache.
    If the destructor is missing, these blocks leak. }
  LData^.Done := True;
  Result := 0;
end;

procedure TestThreadExitCleanup;
var
  LAlloc: TGrowingAllocator;
  LData: TThreadExitData;
  LThread: TThreadID;
begin
  LAlloc := DefaultGrowingAllocator;
  LData.Alloc := LAlloc;
  LData.Done := False;
  LThread := BeginThread(@ThreadExitWorker, @LData);
  WaitForThreadTerminate(LThread, 0);
  Check(LData.Done, 'thread completed');
  WriteLn('PASS: thread exit cleanup (pthread destructor ran)');
end;

{ ── Concurrent stress: 8 threads mixed alloc/free ── }

const
  CONC_OPS = 5000;
  CONC_THREADS = 8;

type
  PConcData = ^TConcData;
  TConcData = record
    Alloc: TGrowingAllocator;
    TID: Integer;
    Done: Boolean;
    ErrorMsg: string;
  end;

function ConcWorker(Parameter: Pointer): PtrInt;
var
  LData: PConcData;
  LSizes: array[0..5] of SizeUInt;
  LPtrs: array[0..63] of Pointer;
  LI, LJ, LK: Integer;
  LSize: SizeUInt;
begin
  LData := PConcData(Parameter);
  LSizes[0] := 16; LSizes[1] := 64; LSizes[2] := 256;
  LSizes[3] := 1024; LSizes[4] := 4096; LSizes[5] := 16384;
  try
    for LI := 0 to CONC_OPS - 1 do
    begin
      LK := (LI + LData^.TID) mod 6;
      LSize := LSizes[LK];
      for LJ := 0 to 63 do
      begin
        LPtrs[LJ] := LData^.Alloc.GetMem(LSize);
        if LPtrs[LJ] = nil then
        begin
          LData^.ErrorMsg := 'nil at op ' + IntToStr(LI);
          LData^.Done := True;
          Exit(1);
        end;
        FillChar(LPtrs[LJ]^, LSize, Byte(LI + LJ));
      end;
      for LJ := 0 to 63 do
        LData^.Alloc.FreeMem(LPtrs[LJ], LSize);
    end;
    LData^.Done := True;
    Result := 0;
  except
    on E: Exception do
    begin
      LData^.ErrorMsg := E.Message;
      LData^.Done := True;
      Result := 1;
    end;
  end;
end;

procedure TestConcurrentStress;
var
  LWorkers: array[0..CONC_THREADS - 1] of TConcData;
  LThreads: array[0..CONC_THREADS - 1] of TThreadID;
  LAllocator: TGrowingAllocator;
  LI: Integer;
  LAllDone: Boolean;
begin
  LAllocator := DefaultGrowingAllocator;
  for LI := 0 to CONC_THREADS - 1 do
  begin
    LWorkers[LI].Alloc := LAllocator;
    LWorkers[LI].TID := LI;
    LWorkers[LI].Done := False;
    LWorkers[LI].ErrorMsg := '';
  end;
  for LI := 0 to CONC_THREADS - 1 do
    LThreads[LI] := BeginThread(@ConcWorker, @LWorkers[LI]);
  repeat
    LAllDone := True;
    for LI := 0 to CONC_THREADS - 1 do
      if not LWorkers[LI].Done then begin LAllDone := False; Break; end;
    if not LAllDone then Sleep(1);
  until LAllDone;
  for LI := 0 to CONC_THREADS - 1 do
    WaitForThreadTerminate(LThreads[LI], 0);
  for LI := 0 to CONC_THREADS - 1 do
    Check(LWorkers[LI].ErrorMsg = '', 'thread ' + IntToStr(LI) + ': ' + LWorkers[LI].ErrorMsg);
  WriteLn('PASS: concurrent stress 8T x ' + IntToStr(CONC_OPS) + ' ops x mixed sizes');
end;

{ ── AllocMem zero-init all sizes ── }

procedure TestAllocMemZeroedAllSizes;
var
  LAlloc: TGrowingAllocator;
  LSizes: array[0..5] of SizeUInt = (16, 128, 512, 2048, 8192, 65536);
  LPtr: PByte;
  I, J: Integer;
  LZero: Boolean;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    for I := 0 to 5 do
    begin
      LPtr := PByte(LAlloc.AllocMem(LSizes[I]));
      Check(LPtr <> nil, 'AllocMem(' + IntToStr(LSizes[I]) + ')');
      LZero := True;
      for J := 0 to Integer(LSizes[I]) - 1 do
        if LPtr[J] <> 0 then begin LZero := False; Break; end;
      Check(LZero, 'zeroed ' + IntToStr(LSizes[I]));
      LAlloc.FreeMem(LPtr, LSizes[I]);
    end;
    WriteLn('PASS: AllocMem zero-init all sizes');
  finally
    LAlloc.Free;
  end;
end;

{ ── Main ── }

begin
  T := TTestSuite.Create('stability');

  T.Test('span_double_free', @TestSpanDoubleFreeDetection);
  T.Test('span_out_of_range', @TestSpanOutOfRangeFree);
  T.Test('span_all_slots_cycle', @TestSpanAllSlotsCycle);
  T.Test('edge_case_sizes', @TestEdgeCaseSizes);
  T.Test('realloc_literal_constants', @TestReallocLiteralConstants);
  T.Test('stress_alloc_free', @TestStressAllocFree);
  T.Test('stress_mixed_sizes', @TestStressMixedSizes);
  T.Test('stress_batch', @TestStressBatch);
  T.Test('stress_mixed_batch', @TestStressMixedBatch);
  T.Test('thread_exit_cleanup', @TestThreadExitCleanup);
  T.Test('concurrent_stress', @TestConcurrentStress);
  T.Test('allocmem_zeroed_all', @TestAllocMemZeroedAllSizes);

  T.Run;
  T.Summary;
end.
