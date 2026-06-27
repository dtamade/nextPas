program test_growing_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.sizeclass,
  nextpas.core.mem.allocator.growing;

var
  T: TTestSuite;

procedure TestSmallAlloc;
var
  LAlloc: TGrowingAllocator;
  LPtr: Pointer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'small alloc 64B returns non-nil');
    LAlloc.FreeMem(LPtr, 64);
    WriteLn('PASS: small alloc');
  finally
    LAlloc.Free;
  end;
end;

procedure TestLargeAlloc;
var
  LAlloc: TGrowingAllocator;
  LPtr: Pointer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LPtr := LAlloc.GetMem(128 * 1024);
    Check(LPtr <> nil, 'large alloc 128KB returns non-nil');
    LAlloc.FreeMem(LPtr, 128 * 1024);
    WriteLn('PASS: large alloc');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMem;
var
  LAlloc: TGrowingAllocator;
  LPtr: PByte;
  I: Integer;
  LZero: Boolean;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LPtr := PByte(LAlloc.AllocMem(256));
    Check(LPtr <> nil, 'AllocMem returns non-nil');
    LZero := True;
    for I := 0 to 255 do
    begin
      if LPtr[I] <> 0 then
      begin
        LZero := False;
        Break;
      end;
    end;
    Check(LZero, 'AllocMem is zeroed');
    LAlloc.FreeMem(LPtr, 256);
    WriteLn('PASS: alloc mem zeroed');
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleSizes;
var
  LAlloc: TGrowingAllocator;
  LPtrs: array[0..9] of Pointer;
  LSizes: array[0..9] of SizeUInt;
  I: Integer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LSizes[0] := 16;
    LSizes[1] := 32;
    LSizes[2] := 64;
    LSizes[3] := 128;
    LSizes[4] := 256;
    LSizes[5] := 512;
    LSizes[6] := 1024;
    LSizes[7] := 4096;
    LSizes[8] := 16384;
    LSizes[9] := 131072;
    for I := 0 to 9 do
    begin
      LPtrs[I] := LAlloc.GetMem(LSizes[I]);
      Check(LPtrs[I] <> nil, 'alloc ' + IntToStr(LSizes[I]) + 'B');
    end;
    { All should be distinct. }
    for I := 0 to 8 do
      Check(LPtrs[I] <> LPtrs[I + 1], 'distinct ' + IntToStr(I));
    for I := 0 to 9 do
      LAlloc.FreeMem(LPtrs[I], LSIZES[I]);
    WriteLn('PASS: multiple sizes');
  finally
    LAlloc.Free;
  end;
end;

procedure TestCacheHit;
var
  LAlloc: TGrowingAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LPtr1 := LAlloc.GetMem(64);
    LAlloc.FreeMem(LPtr1, 64);
    { Second alloc of same size should return same block (cache hit). }
    LPtr2 := LAlloc.GetMem(64);
    Check(LPtr2 = LPtr1, 'cache hit: same block returned');
    LAlloc.FreeMem(LPtr2, 64);
    WriteLn('PASS: cache hit');
  finally
    LAlloc.Free;
  end;
end;

procedure TestZeroSize;
var
  LAlloc: TGrowingAllocator;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    Check(LAlloc.GetMem(0) = nil, 'zero size returns nil');
    WriteLn('PASS: zero size');
  finally
    LAlloc.Free;
  end;
end;

procedure TestDefaultAllocator;
var
  LPtr: Pointer;
begin
  LPtr := DefaultGrowingAllocator.GetMem(128);
  Check(LPtr <> nil, 'default allocator works');
  DefaultGrowingAllocator.FreeMem(LPtr, 128);
  WriteLn('PASS: default allocator');
end;

procedure CleanupDefaultAllocator;
begin
  ResetDefaultGrowingAllocator;
end;

{ --- Main --- }

begin
  T := TTestSuite.Create('growing_allocator');

  T.Test('small_alloc', @TestSmallAlloc);
  T.Test('large_alloc', @TestLargeAlloc);
  T.Test('alloc_mem_zeroed', @TestAllocMem);
  T.Test('multiple_sizes', @TestMultipleSizes);
  T.Test('cache_hit', @TestCacheHit);
  T.Test('zero_size', @TestZeroSize);
  T.Test('default_allocator', @TestDefaultAllocator);

  T.Run;
  T.Summary;
  CleanupDefaultAllocator;
end.
