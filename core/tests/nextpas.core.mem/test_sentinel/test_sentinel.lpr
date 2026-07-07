program test_sentinel;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.crt,
  nextpas.core.mem.allocator.sentinel;

var
  T: TTestSuite;

{ ── Basic alloc/free ── }

procedure TestGetMem;
var
  LAlloc: TSentinelAllocator;
  LPtr: Pointer;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 0);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'GetMem(64) returns non-nil');
    FillChar(LPtr^, 64, $AA);
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TSentinelAllocator;
  LPtr: PByte;
  LI: Int32;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 0);
  try
    LPtr := PByte(LAlloc.AllocMem(128));
    Check(LPtr <> nil, 'AllocMem(128)');
    for LI := 0 to 127 do
      Check(LPtr[LI] = 0, 'byte[' + IntToStr(LI) + '] = 0');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocPreservesData;
var
  LAlloc: TSentinelAllocator;
  LPtr, LNew: PByte;
  LI: Int32;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 0);
  try
    LPtr := PByte(LAlloc.GetMem(64));
    for LI := 0 to 63 do
      LPtr[LI] := Byte(LI);
    LNew := PByte(LAlloc.ReallocMem(LPtr, 256));
    Check(LNew <> nil, 'ReallocMem(256)');
    for LI := 0 to 63 do
      Check(LNew[LI] = Byte(LI), 'data[' + IntToStr(LI) + '] preserved');
    LAlloc.FreeMem(LNew);
  finally
    LAlloc.Free;
  end;
end;

procedure TestNilHandling;
var
  LAlloc: TSentinelAllocator;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 0);
  try
    Check(LAlloc.GetMem(0) = nil, 'GetMem(0) = nil');
    LAlloc.FreeMem(nil);
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: TSentinelAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 0);
  try
    LTraits := LAlloc.Traits;
    Check(not LTraits.ThreadSafe, 'ThreadSafe = False');
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleAllocs;
var
  LAlloc: TSentinelAllocator;
  LPtrs: array[0..49] of Pointer;
  LI: Int32;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 0);
  try
    for LI := 0 to 49 do
    begin
      LPtrs[LI] := LAlloc.GetMem(16 + SizeUInt(LI * 5));
      Check(LPtrs[LI] <> nil, 'alloc ' + IntToStr(LI));
      FillChar(LPtrs[LI]^, 16 + SizeUInt(LI * 5), Byte(LI));
    end;
    for LI := 0 to 49 do
      LAlloc.FreeMem(LPtrs[LI]);
  finally
    LAlloc.Free;
  end;
end;

{ ── Double-free detection ── }

procedure TestDoubleFreeDetection;
var
  LAlloc: TSentinelAllocator;
  LPtr: Pointer;
  LRaised: Boolean;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 0);
  try
    LPtr := LAlloc.GetMem(64);
    LAlloc.FreeMem(LPtr);
    LRaised := False;
    try
      LAlloc.FreeMem(LPtr);
    except
      on E: EAllocError do
        LRaised := True;
    end;
    Check(LRaised, 'double free raises EAllocError');
  finally
    LAlloc.Free;
  end;
end;

procedure TestDoubleFreeWithQuarantine;
var
  LAlloc: TSentinelAllocator;
  LPtr: Pointer;
  LRaised: Boolean;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 64);
  try
    LPtr := LAlloc.GetMem(64);
    LAlloc.FreeMem(LPtr);
    { Sentinel cleared immediately, so second free catches it }
    LRaised := False;
    try
      LAlloc.FreeMem(LPtr);
    except
      on E: EAllocError do
        LRaised := True;
    end;
    Check(LRaised, 'double free with quarantine raises EAllocError');
  finally
    LAlloc.Free;
  end;
end;

{ ── Buffer overflow detection ── }

procedure TestBufferOverflowDetection;
var
  LAlloc: TSentinelAllocator;
  LPtr: PByte;
  LRaised: Boolean;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 0);
  try
    LPtr := PByte(LAlloc.GetMem(64));
    { Write past the end — corrupts post-sentinel }
    LPtr[64] := $FF;
    LRaised := False;
    try
      LAlloc.FreeMem(LPtr);
    except
      on E: EAllocError do
        LRaised := True;
    end;
    Check(LRaised, 'buffer overflow detected on free');
  finally
    LAlloc.Free;
  end;
end;

{ ── Wild pointer free ── }

procedure TestFreeWildPointer;
var
  LAlloc: TSentinelAllocator;
  LRaised: Boolean;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 0);
  try
    LRaised := False;
    try
      LAlloc.FreeMem(Pointer($DEADBEEF));
    except
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised, 'free wild pointer raises');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFreeStackPointer;
var
  LAlloc: TSentinelAllocator;
  LRaised: Boolean;
  LStackVar: array[0..63] of Byte;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 0);
  try
    FillChar(LStackVar, SizeOf(LStackVar), 0);
    LRaised := False;
    try
      LAlloc.FreeMem(@LStackVar[0]);
    except
      on E: EAllocError do
        LRaised := True;
    end;
    Check(LRaised, 'free stack pointer raises EAllocError');
  finally
    LAlloc.Free;
  end;
end;

{ ── Quarantine behavior ── }

procedure TestQuarantineDelayedRelease;
var
  LAlloc: TSentinelAllocator;
  LPtr: Pointer;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 16);
  try
    LPtr := LAlloc.GetMem(64);
    LAlloc.FreeMem(LPtr);
    Check(LAlloc.QuarantineCount = 1, 'quarantine count = 1 after free');
    LAlloc.DrainQuarantine;
    Check(LAlloc.QuarantineCount = 0, 'quarantine count = 0 after drain');
  finally
    LAlloc.Free;
  end;
end;

procedure TestQuarantineRingBufferOverflow;
var
  LAlloc: TSentinelAllocator;
  LPtrs: array[0..31] of Pointer;
  LI: Int32;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 8);
  try
    for LI := 0 to 31 do
    begin
      LPtrs[LI] := LAlloc.GetMem(32);
      Check(LPtrs[LI] <> nil, 'alloc ' + IntToStr(LI));
    end;
    for LI := 0 to 31 do
      LAlloc.FreeMem(LPtrs[LI]);
    Check(LAlloc.QuarantineCount = 8, 'quarantine capped at 8');
    LAlloc.DrainQuarantine;
  finally
    LAlloc.Free;
  end;
end;

procedure TestNoQuarantine;
var
  LAlloc: TSentinelAllocator;
  LPtr: Pointer;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 0);
  try
    LPtr := LAlloc.GetMem(64);
    LAlloc.FreeMem(LPtr);
    Check(LAlloc.QuarantineCount = 0, 'no quarantine = 0');
  finally
    LAlloc.Free;
  end;
end;

procedure TestDrainQuarantineMultiple;
var
  LAlloc: TSentinelAllocator;
  LPtrs: array[0..9] of Pointer;
  LI: Int32;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 32);
  try
    for LI := 0 to 9 do
    begin
      LPtrs[LI] := LAlloc.GetMem(48);
      Check(LPtrs[LI] <> nil, 'alloc ' + IntToStr(LI));
    end;
    for LI := 0 to 9 do
      LAlloc.FreeMem(LPtrs[LI]);
    Check(LAlloc.QuarantineCount = 10, 'quarantine = 10');
    LAlloc.DrainQuarantine;
    Check(LAlloc.QuarantineCount = 0, 'after drain = 0');
  finally
    LAlloc.Free;
  end;
end;

{ ── Realloc with sentinel ── }

procedure TestReallocNil;
var
  LAlloc: TSentinelAllocator;
  LPtr: Pointer;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 0);
  try
    LPtr := LAlloc.ReallocMem(nil, 128);
    Check(LPtr <> nil, 'ReallocMem(nil, 128)');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocShrink;
var
  LAlloc: TSentinelAllocator;
  LPtr, LNew: PByte;
  LI: Int32;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 0);
  try
    LPtr := PByte(LAlloc.GetMem(256));
    for LI := 0 to 255 do
      LPtr[LI] := Byte(LI);
    LNew := PByte(LAlloc.ReallocMem(LPtr, 64));
    Check(LNew <> nil, 'ReallocMem shrink to 64');
    for LI := 0 to 63 do
      Check(LNew[LI] = Byte(LI), 'shrunk data[' + IntToStr(LI) + ']');
    LAlloc.FreeMem(LNew);
  finally
    LAlloc.Free;
  end;
end;

{ ── Drain on destroy ── }

procedure TestDrainOnDestroy;
var
  LAlloc: TSentinelAllocator;
  LPtr: Pointer;
begin
  LAlloc := TSentinelAllocator.Create(TCrtAllocator.Create, 16);
  try
    LPtr := LAlloc.GetMem(64);
    LAlloc.FreeMem(LPtr);
    Check(LAlloc.QuarantineCount = 1, 'quarantine = 1');
    { Destroy should drain }
    LAlloc.Free;
    LAlloc := nil;
  finally
    if LAlloc <> nil then
      LAlloc.Free;
  end;
end;

{ ── Main ── }

begin
  T := TTestSuite.Create('test_sentinel');

  T.Test('get_mem', @TestGetMem);
  T.Test('alloc_mem_zeroed', @TestAllocMemZeroed);
  T.Test('realloc_preserves_data', @TestReallocPreservesData);
  T.Test('nil_handling', @TestNilHandling);
  T.Test('traits', @TestTraits);
  T.Test('multiple_allocs', @TestMultipleAllocs);
  T.Test('double_free_detection', @TestDoubleFreeDetection);
  T.Test('double_free_with_quarantine', @TestDoubleFreeWithQuarantine);
  T.Test('buffer_overflow_detection', @TestBufferOverflowDetection);
  T.Test('free_wild_pointer', @TestFreeWildPointer);
  T.Test('free_stack_pointer', @TestFreeStackPointer);
  T.Test('quarantine_delayed_release', @TestQuarantineDelayedRelease);
  T.Test('quarantine_ring_overflow', @TestQuarantineRingBufferOverflow);
  T.Test('no_quarantine', @TestNoQuarantine);
  T.Test('drain_quarantine_multiple', @TestDrainQuarantineMultiple);
  T.Test('realloc_nil', @TestReallocNil);
  T.Test('realloc_shrink', @TestReallocShrink);
  T.Test('drain_on_destroy', @TestDrainOnDestroy);

  T.Run;
  T.Summary;
end.
