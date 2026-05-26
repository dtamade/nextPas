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

  // Allocate
  LPtr := LAlloc.Allocate(1024);
  Assert(LPtr <> nil, 'Allocate should return non-nil');

  // Write and read
  LIntPtr := PInteger(LPtr);
  LIntPtr^ := 42;
  Assert(LIntPtr^ = 42, 'Should read back written value');

  // Reallocate
  LPtr := LAlloc.Reallocate(LPtr, 2048);
  Assert(LPtr <> nil, 'Reallocate should return non-nil');
  LIntPtr := PInteger(LPtr);
  Assert(LIntPtr^ = 42, 'Value should survive reallocation');

  // Deallocate
  LAlloc.Deallocate(LPtr);

  // Singleton behavior
  Assert(DefaultAllocator = LAlloc, 'DefaultAllocator should be singleton');

  WriteLn('PASS: all mem tests passed');
end.
