program test_zeroed_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.zeroed;

var
  T: TTestSuite;

procedure TestGetMemZeroed;
var
  LAlloc: TZeroedAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TZeroedAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(256);
    Check(LPtr <> nil, 'allocated');
    for LIdx := 0 to 255 do
      CheckEqual(PByte(LPtr)[LIdx], Byte(0), 'zero at ' + IntToStr(LIdx));
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TZeroedAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TZeroedAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.AllocMem(128);
    Check(LPtr <> nil, 'allocated');
    for LIdx := 0 to 127 do
      CheckEqual(PByte(LPtr)[LIdx], Byte(0), 'zero at ' + IntToStr(LIdx));
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestSmallAlloc;
var
  LAlloc: TZeroedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TZeroedAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(1);
    Check(LPtr <> nil, 'small alloc');
    CheckEqual(PByte(LPtr)^, Byte(0), 'small zeroed');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestLargeAlloc;
var
  LAlloc: TZeroedAllocator;
  LPtr: Pointer;
  LIdx: Integer;
  LSize: SizeUInt;
begin
  LAlloc := TZeroedAllocator.Create(GetRtlAllocator);
  try
    LSize := 65536;
    LPtr := LAlloc.GetMem(LSize);
    Check(LPtr <> nil, 'large alloc');
    for LIdx := 0 to 255 do
      CheckEqual(PByte(LPtr)[LIdx], Byte(0), 'start zero');
    for LIdx := LSize - 256 to LSize - 1 do
      CheckEqual(PByte(LPtr)[LIdx], Byte(0), 'end zero');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocZeroed;
var
  LAlloc: TZeroedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TZeroedAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(32);
    Check(LPtr <> nil, 'initial');
    FillChar(LPtr^, 32, $FF);

    // ReallocMem preserves old data (standard realloc semantics).
    // The zeroed contract applies to GetMem/AllocMem, not ReallocMem.
    LPtr := LAlloc.ReallocMem(LPtr, 64);
    Check(LPtr <> nil, 'reallocated');
    CheckEqual(PByte(LPtr)^, Byte($FF), 'realloc preserves old data');

    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestNilSafe;
var
  LAlloc: TZeroedAllocator;
begin
  LAlloc := TZeroedAllocator.Create(GetRtlAllocator);
  try
    LAlloc.FreeMem(nil);
    Check(True, 'nil free safe');
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleAllocs;
var
  LAlloc: TZeroedAllocator;
  LPtrs: array[0..9] of Pointer;
  LIdx, LByte: Integer;
begin
  LAlloc := TZeroedAllocator.Create(GetRtlAllocator);
  try
    for LIdx := 0 to 9 do
    begin
      LPtrs[LIdx] := LAlloc.GetMem(64);
      Check(LPtrs[LIdx] <> nil, 'alloc ' + IntToStr(LIdx));
    end;

    for LIdx := 0 to 9 do
      for LByte := 0 to 63 do
        CheckEqual(PByte(LPtrs[LIdx])[LByte], Byte(0), 'zero ' + IntToStr(LIdx));

    for LIdx := 0 to 9 do
      LAlloc.FreeMem(LPtrs[LIdx]);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_zeroed_allocator');
  T.Test('GetMemZeroed', @TestGetMemZeroed);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('SmallAlloc', @TestSmallAlloc);
  T.Test('LargeAlloc', @TestLargeAlloc);
  T.Test('ReallocZeroed', @TestReallocZeroed);
  T.Test('NilSafe', @TestNilSafe);
  T.Test('MultipleAllocs', @TestMultipleAllocs);
  T.Run;
  T.Summary;
end.
