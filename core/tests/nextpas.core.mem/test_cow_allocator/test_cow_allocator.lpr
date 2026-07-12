program test_cow_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.cow;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBasicAlloc;
var
  LAlloc: TCowAllocator;
  LPtr: Pointer;
begin
  LAlloc := TCowAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestShare;
var
  LAlloc: TCowAllocator;
  LPtr, LShared: Pointer;
begin
  LAlloc := TCowAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'original allocated');

    // Write pattern
    PByte(LPtr)^ := $AB;

    LShared := LAlloc.Share(LPtr);
    Check(LShared <> nil, 'shared created');
    // Shared should point to same data initially
    Check(PByte(LShared)^ = $AB, 'shared sees same data');

    LAlloc.FreeMem(LShared);
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestWriteNotify;
var
  LAlloc: TCowAllocator;
  LPtr, LShared, LWritable: Pointer;
begin
  LAlloc := TCowAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    PByte(LPtr)^ := $AB;

    LShared := LAlloc.Share(LPtr);
    Check(LAlloc.IsShared(LShared), 'is shared');

    // WriteNotify should copy the data
    LWritable := LAlloc.WriteNotify(LShared);
    Check(LWritable <> nil, 'writable returned');
    Check(PByte(LWritable)^ = $AB, 'data copied');
    Check(not LAlloc.IsShared(LWritable), 'no longer shared after copy');

    LAlloc.FreeMem(LShared);
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestIsShared;
var
  LAlloc: TCowAllocator;
  LPtr: Pointer;
begin
  LAlloc := TCowAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    Check(not LAlloc.IsShared(LPtr), 'new alloc not shared');

    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TCowAllocator;
  LPtr, LShared, LCopy: Pointer;
  LStats: TCowStats;
begin
  LAlloc := TCowAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    LShared := LAlloc.Share(LPtr);
    LCopy := LAlloc.WriteNotify(LShared);

    LStats := LAlloc.GetStats;
    Check(LStats.TotalAllocs >= 1, 'total allocs');
    Check(LStats.SharedAllocs >= 1, 'shared allocs');
    Check(LStats.CopiedOnWrite >= 1, 'cow copies');
    Check(LStats.ActiveRefs >= 2, 'active refs');

    LAlloc.FreeMem(LCopy);
    LAlloc.FreeMem(LShared);
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TCowAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TCowAllocator.Create(GetRtlAllocator);
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
  LAlloc: TCowAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TCowAllocator.Create(GetRtlAllocator);
  try
    LTraits := LAlloc.Traits;
    Check(not LTraits.ZeroInitialized, 'not zero-init');
    Check(not LTraits.ThreadSafe, 'not thread-safe');
    Check(LTraits.SupportsRealloc, 'supports realloc');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_cow_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('Share', @TestShare);
  T.Test('WriteNotify', @TestWriteNotify);
  T.Test('IsShared', @TestIsShared);
  T.Test('Stats', @TestStats);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
