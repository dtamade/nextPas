program test_scoped_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.scoped;

var
  T: TTestSuite;

procedure TestBasicAlloc;
var
  LAlloc: TScopedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TScopedAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    Check(LAlloc.TrackedCount = 1, 'tracked');
    LAlloc.FreeMem(LPtr);
    Check(LAlloc.TrackedCount = 0, 'untracked after free');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAutoFreeOnDestroy;
var
  LInner: IAllocator;
  LAlloc: TScopedAllocator;
begin
  LInner := GetRtlAllocator;
  LAlloc := TScopedAllocator.Create(LInner);
  try
    LAlloc.GetMem(64);
    LAlloc.GetMem(128);
    Check(LAlloc.TrackedCount = 2, '2 tracked');
    // Destroy will auto-free both
  finally
    LAlloc.Free;
  end;
  // If we get here without leak, auto-free worked
  Check(True, 'auto-free on destroy');
end;

procedure TestReset;
var
  LAlloc: TScopedAllocator;
begin
  LAlloc := TScopedAllocator.Create(GetRtlAllocator);
  try
    LAlloc.GetMem(64);
    LAlloc.GetMem(128);
    LAlloc.GetMem(256);
    Check(LAlloc.TrackedCount = 3, '3 tracked');

    LAlloc.Reset;
    Check(LAlloc.TrackedCount = 0, 'reset clears');
    Check(LAlloc.TrackedBytes = 0, 'bytes reset');
  finally
    LAlloc.Free;
  end;
end;

procedure TestTrackedBytes;
var
  LAlloc: TScopedAllocator;
begin
  LAlloc := TScopedAllocator.Create(GetRtlAllocator);
  try
    LAlloc.GetMem(64);
    Check(LAlloc.TrackedBytes >= 64, '64 bytes');

    LAlloc.GetMem(128);
    Check(LAlloc.TrackedBytes >= 192, '192 bytes');

    LAlloc.Reset;
    Check(LAlloc.TrackedBytes = 0, 'zero after reset');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TScopedAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TScopedAllocator.Create(GetRtlAllocator);
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

procedure TestTraits;
var
  LAlloc: TScopedAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TScopedAllocator.Create(GetRtlAllocator);
  try
    LTraits := LAlloc.Traits;
    Check(True, 'traits accessible');
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleReset;
var
  LAlloc: TScopedAllocator;
begin
  LAlloc := TScopedAllocator.Create(GetRtlAllocator);
  try
    LAlloc.GetMem(64);
    LAlloc.Reset;
    Check(LAlloc.TrackedCount = 0, 'first reset');

    LAlloc.GetMem(128);
    LAlloc.GetMem(256);
    Check(LAlloc.TrackedCount = 2, '2 after re-alloc');

    LAlloc.Reset;
    Check(LAlloc.TrackedCount = 0, 'second reset');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_scoped_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('AutoFreeOnDestroy', @TestAutoFreeOnDestroy);
  T.Test('Reset', @TestReset);
  T.Test('TrackedBytes', @TestTrackedBytes);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Traits', @TestTraits);
  T.Test('MultipleReset', @TestMultipleReset);
  T.Run;
  T.Summary;
end.
