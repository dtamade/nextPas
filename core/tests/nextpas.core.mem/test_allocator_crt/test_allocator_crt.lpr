program test_allocator_crt;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.crt;

var
  T: TTestRunner;

procedure TestCrtAllocatorSingletonAndTraits;
var
  LFirst: IAllocator;
  LSecond: IAllocator;
  LTraits: TAllocatorTraits;
begin
  LFirst := GetCrtAllocator;
  LSecond := GetCrtAllocator;

  Check(LFirst <> nil, 'CRT allocator should exist');
  Check(LFirst = LSecond, 'CRT allocator should be a singleton');

  LTraits := LFirst.Traits;
  Check(LTraits.ThreadSafe, 'CRT allocator should report thread-safe traits');
  Check(LTraits.ZeroInitialized, 'CRT allocator AllocMem should report zero initialization');
  CheckEqual(False, LTraits.SupportsAligned, 'CRT allocator should report fallback aligned alloc');
  CheckEqual(False, LTraits.HasMemSize, 'CRT allocator should not expose MemSize');
end;

procedure TestCrtAllocatorAllocMemAndReallocMem;
var
  LAllocator: IAllocator;
  LPtr: PByte;
  LI: Integer;
begin
  LAllocator := GetCrtAllocator;
  LPtr := PByte(LAllocator.AllocMem(32));
  try
    Check(LPtr <> nil, 'AllocMem should return a pointer');
    for LI := 0 to 31 do
      CheckEqual(Int64(0), Int64(LPtr[LI]), 'AllocMem should zero initialize each byte');

    LPtr[0] := $4D;
    LPtr := PByte(LAllocator.ReallocMem(LPtr, 64));
    Check(LPtr <> nil, 'ReallocMem should return a pointer');
    CheckEqual(Int64($4D), Int64(LPtr[0]), 'ReallocMem should preserve the existing prefix');
  finally
    LAllocator.FreeMem(LPtr);
  end;
end;

procedure TestCrtAllocatorAlignedFallback;
var
  LAllocator: IAllocator;
  LPtr: Pointer;
begin
  LAllocator := GetCrtAllocator;
  LPtr := LAllocator.AllocAligned(96, 32);
  try
    Check(LPtr <> nil, 'AllocAligned should return a pointer');
    CheckEqual(Int64(0), Int64(PtrUInt(LPtr) mod 32), 'AllocAligned should honor the requested alignment');
  finally
    LAllocator.FreeAligned(LPtr);
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.allocator.crt');
  T.Run('singleton and traits', @TestCrtAllocatorSingletonAndTraits);
  T.Run('AllocMem and ReallocMem', @TestCrtAllocatorAllocMemAndReallocMem);
  T.Run('aligned fallback', @TestCrtAllocatorAlignedFallback);
  T.Summary;
end.
