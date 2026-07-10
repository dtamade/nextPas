program test_allocator_crt;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.crt;

var
  T: TTestSuite;
  LRunPassed: Boolean;

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
      Check(Int64(0) = Int64(LPtr[LI]), 'AllocMem should zero initialize each byte');

    LPtr[0] := $4D;
    LPtr := PByte(LAllocator.ReallocMem(LPtr, 64));
    Check(LPtr <> nil, 'ReallocMem should return a pointer');
    Check(Int64($4D) = Int64(LPtr[0]), 'ReallocMem should preserve the existing prefix');
  finally
    LAllocator.FreeMem(LPtr);
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.allocator.crt');
  T.Test('singleton and traits', @TestCrtAllocatorSingletonAndTraits);
  T.Test('AllocMem and ReallocMem', @TestCrtAllocatorAllocMemAndReallocMem);
  LRunPassed := T.Run;

  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
