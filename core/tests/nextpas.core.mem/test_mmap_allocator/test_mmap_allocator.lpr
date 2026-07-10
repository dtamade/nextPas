program test_mmap_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.mmap;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBasicAlloc;
var
  LAlloc: TMemoryMapAllocator;
  LPtr: Pointer;
begin
  LAlloc := TMemoryMapAllocator.CreateAnonymous(1024 * 1024);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleAlloc;
var
  LAlloc: TMemoryMapAllocator;
  LPtrs: array[0..3] of Pointer;
  LIdx: Integer;
begin
  LAlloc := TMemoryMapAllocator.CreateAnonymous(1024 * 1024);
  try
    for LIdx := 0 to 3 do
    begin
      LPtrs[LIdx] := LAlloc.GetMem(64);
      Check(LPtrs[LIdx] <> nil, 'alloc ' + IntToStr(LIdx));
    end;
    for LIdx := 0 to 3 do
      LAlloc.FreeMem(LPtrs[LIdx]);
    Check(True, 'all freed');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TMemoryMapAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TMemoryMapAllocator.CreateAnonymous(1024 * 1024);
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
  LAlloc: TMemoryMapAllocator;
  LPtr, LNewPtr: Pointer;
begin
  LAlloc := TMemoryMapAllocator.CreateAnonymous(1024 * 1024);
  try
    LPtr := LAlloc.GetMem(32);
    PByte(LPtr)^ := $EE;

    LNewPtr := LAlloc.ReallocMem(LPtr, 128);
    Check(LNewPtr <> nil, 'realloc ok');
    Check(PByte(LNewPtr)^ = $EE, 'data preserved');
    LAlloc.FreeMem(LNewPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestReservationSize;
var
  LAlloc: TMemoryMapAllocator;
begin
  LAlloc := TMemoryMapAllocator.CreateAnonymous(2 * 1024 * 1024);
  try
    Check(LAlloc.ReservationSize = 2 * 1024 * 1024, 'reservation size');
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: TMemoryMapAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TMemoryMapAllocator.CreateAnonymous(1024 * 1024);
  try
    LTraits := LAlloc.Traits;
    Check(LTraits.ZeroInitialized, 'zero-init');
    Check(LTraits.ThreadSafe, 'thread-safe');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFactoryFunction;
var
  LInner: IAllocator;
  LPtr: Pointer;
begin
  LInner := CreateAnonymousMemoryMapAllocator(1024 * 1024);
  LPtr := LInner.GetMem(64);
  Check(LPtr <> nil, 'factory alloc');
  LInner.FreeMem(LPtr);
end;

begin
  T := TTestSuite.Create('test_mmap_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('MultipleAlloc', @TestMultipleAlloc);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Realloc', @TestRealloc);
  T.Test('ReservationSize', @TestReservationSize);
  T.Test('Traits', @TestTraits);
  T.Test('FactoryFunction', @TestFactoryFunction);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
