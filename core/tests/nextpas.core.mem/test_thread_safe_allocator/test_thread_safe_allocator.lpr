program test_thread_safe_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.thread_safe;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBasicAlloc;
var
  LAlloc: TThreadSafeAllocator;
  LPtr: Pointer;
begin
  LAlloc := TThreadSafeAllocator.Create(GetRtlAllocator);
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
  LAlloc: TThreadSafeAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TThreadSafeAllocator.Create(GetRtlAllocator);
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
  LAlloc: TThreadSafeAllocator;
  LPtr, LNewPtr: Pointer;
begin
  LAlloc := TThreadSafeAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(32);
    PByte(LPtr)^ := $FF;

    LNewPtr := LAlloc.ReallocMem(LPtr, 128);
    Check(LNewPtr <> nil, 'realloc ok');
    Check(PByte(LNewPtr)^ = $FF, 'data preserved');
    LAlloc.FreeMem(LNewPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: TThreadSafeAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TThreadSafeAllocator.Create(GetRtlAllocator);
  try
    LTraits := LAlloc.Traits;
    Check(LTraits.ThreadSafe, 'thread-safe');
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleAllocs;
var
  LAlloc: TThreadSafeAllocator;
  LPtrs: array[0..7] of Pointer;
  LIdx: Integer;
begin
  LAlloc := TThreadSafeAllocator.Create(GetRtlAllocator);
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

procedure TestFreeNil;
var
  LAlloc: TThreadSafeAllocator;
begin
  LAlloc := TThreadSafeAllocator.Create(GetRtlAllocator);
  try
    LAlloc.FreeMem(nil);
    Check(True, 'no crash');
  finally
    LAlloc.Free;
  end;
end;

procedure TestDifferentSizes;
var
  LAlloc: TThreadSafeAllocator;
  LPtr: Pointer;
begin
  LAlloc := TThreadSafeAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(1);
    Check(LPtr <> nil, '1 byte');
    LAlloc.FreeMem(LPtr);

    LPtr := LAlloc.GetMem(4096);
    Check(LPtr <> nil, '4KB');
    LAlloc.FreeMem(LPtr);

    LPtr := LAlloc.GetMem(65536);
    Check(LPtr <> nil, '64KB');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_thread_safe_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Realloc', @TestRealloc);
  T.Test('Traits', @TestTraits);
  T.Test('MultipleAllocs', @TestMultipleAllocs);
  T.Test('FreeNil', @TestFreeNil);
  T.Test('DifferentSizes', @TestDifferentSizes);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
