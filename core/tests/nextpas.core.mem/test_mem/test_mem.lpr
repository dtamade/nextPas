program test_mem;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem;

var
  LAlloc: IAllocator;
  LPtr: Pointer;
  LIntPtr: PInteger;
begin
  WriteLn('=== nextpas.core.mem tests ===');

  LAlloc := DefaultAllocator;
  Assert(LAlloc <> nil, 'DefaultAllocator should not be nil');

  LPtr := LAlloc.GetMem(16);
  Assert(LPtr <> nil, 'facade IAllocator should expose GetMem');
  LAlloc.FreeMem(LPtr);

  Assert(LAlloc.MemSize(nil) = 0, 'MemSize(nil) should return 0');

  // GetMem
  LPtr := LAlloc.GetMem(1024);
  Assert(LPtr <> nil, 'GetMem should return non-nil');

  // Write and read
  LIntPtr := PInteger(LPtr);
  LIntPtr^ := 42;
  Assert(LIntPtr^ = 42, 'Should read back written value');

  // ReallocMem
  LPtr := LAlloc.ReallocMem(LPtr, 2048);
  Assert(LPtr <> nil, 'ReallocMem should return non-nil');
  LIntPtr := PInteger(LPtr);
  Assert(LIntPtr^ = 42, 'Value should survive reallocation');

  // FreeMem
  LAlloc.FreeMem(LPtr);

  // Singleton behavior
  Assert(DefaultAllocator = LAlloc, 'DefaultAllocator should be singleton');

  WriteLn('PASS: all mem tests passed');
end.
