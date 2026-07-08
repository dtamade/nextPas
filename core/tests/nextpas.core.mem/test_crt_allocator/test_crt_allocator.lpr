program test_crt_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.crt;

var
  T: TTestSuite;

procedure TestBasicAlloc;
var
  LAlloc: TCrtAllocator;
  LPtr: Pointer;
begin
  LAlloc := TCrtAllocator.Create;
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TCrtAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TCrtAllocator.Create;
  try
    LPtr := LAlloc.AllocMem(64);
    Check(LPtr <> nil, 'allocated');
    for LIdx := 0 to 63 do
      CheckEqual(PByte(LPtr)[LIdx], Byte(0), 'zeroed');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestRealloc;
var
  LAlloc: TCrtAllocator;
  LPtr, LNewPtr: Pointer;
begin
  LAlloc := TCrtAllocator.Create;
  try
    LPtr := LAlloc.GetMem(32);
    PByte(LPtr)^ := $CC;

    LNewPtr := LAlloc.ReallocMem(LPtr, 128);
    Check(LNewPtr <> nil, 'realloc ok');
    Check(PByte(LNewPtr)^ = $CC, 'data preserved');
    LAlloc.FreeMem(LNewPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: TCrtAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TCrtAllocator.Create;
  try
    LTraits := LAlloc.Traits;
    Check(LTraits.ZeroInitialized, 'zero-init');
  finally
    LAlloc.Free;
  end;
end;

procedure TestGetCrtAllocator;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  LAlloc := GetCrtAllocator;
  LPtr := LAlloc.GetMem(64);
  Check(LPtr <> nil, 'factory alloc');
  LAlloc.FreeMem(LPtr);
end;

procedure TestMultipleAllocs;
var
  LAlloc: TCrtAllocator;
  LPtrs: array[0..7] of Pointer;
  LIdx: Integer;
begin
  LAlloc := TCrtAllocator.Create;
  try
    for LIdx := 0 to 7 do
    begin
      LPtrs[LIdx] := LAlloc.GetMem(32);
      Check(LPtrs[LIdx] <> nil, 'alloc ' + IntToStr(LIdx));
    end;
    for LIdx := 0 to 7 do
      LAlloc.FreeMem(LPtrs[LIdx]);
    Check(True, 'all freed');
  finally
    LAlloc.Free;
  end;
end;

procedure TestLargeAlloc;
var
  LAlloc: TCrtAllocator;
  LPtr: Pointer;
begin
  LAlloc := TCrtAllocator.Create;
  try
    LPtr := LAlloc.GetMem(1024 * 1024);
    Check(LPtr <> nil, '1MB alloc');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_crt_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Realloc', @TestRealloc);
  T.Test('Traits', @TestTraits);
  T.Test('GetCrtAllocator', @TestGetCrtAllocator);
  T.Test('MultipleAllocs', @TestMultipleAllocs);
  T.Test('LargeAlloc', @TestLargeAlloc);
  T.Run;
  T.Summary;
end.
