{ nextpas - test: thread-safe allocator }

{$I nextpas.core.settings.inc}

program test_thread_safe;

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.thread_safe;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBasicAlloc;
var
  LAlloc: TThreadSafeAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TThreadSafeAllocator.Create(DefaultAllocator);
  try
    LPtr1 := LAlloc.GetMem(64);
    Check(LPtr1 <> nil, 'alloc 64B');
    LPtr2 := LAlloc.GetMem(128);
    Check(LPtr2 <> nil, 'alloc 128B');
    Check(LPtr1 <> LPtr2, 'different pointers');
    LAlloc.FreeMem(LPtr1);
    LAlloc.FreeMem(LPtr2);
  finally
    LAlloc.Free;
  end;
end;

procedure TestZeroReturnsNil;
var
  LAlloc: TThreadSafeAllocator;
begin
  LAlloc := TThreadSafeAllocator.Create(DefaultAllocator);
  try
    Check(LAlloc.GetMem(0) = nil, 'zero alloc returns nil');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMem;
var
  LAlloc: TThreadSafeAllocator;
  LPtr: Pointer;
  I: Integer;
  LByte: PByte;
begin
  LAlloc := TThreadSafeAllocator.Create(DefaultAllocator);
  try
    LPtr := LAlloc.AllocMem(64);
    Check(LPtr <> nil, 'allocmem');
    LByte := PByte(LPtr);
    for I := 0 to 63 do
      Check(LByte[I] = 0, 'zero initialized');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestRealloc;
var
  LAlloc: TThreadSafeAllocator;
  LPtr: Pointer;
begin
  LAlloc := TThreadSafeAllocator.Create(DefaultAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'initial alloc');
    LPtr := LAlloc.ReallocMem(LPtr, 256);
    Check(LPtr <> nil, 'realloc');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: TThreadSafeAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TThreadSafeAllocator.Create(DefaultAllocator);
  try
    LTraits := LAlloc.Traits;
    Check(LTraits.ThreadSafe = True, 'thread safe = true');
  finally
    LAlloc.Free;
  end;
end;

procedure TestManyAllocations;
var
  LAlloc: TThreadSafeAllocator;
  LPtrs: array[0..99] of Pointer;
  I: Integer;
begin
  LAlloc := TThreadSafeAllocator.Create(DefaultAllocator);
  try
    for I := 0 to 99 do
    begin
      LPtrs[I] := LAlloc.GetMem(64);
      Check(LPtrs[I] <> nil, 'alloc #' + IntToStr(I));
    end;
    for I := 0 to 99 do
      LAlloc.FreeMem(LPtrs[I]);
  finally
    LAlloc.Free;
  end;
end;

procedure TestInnerAllocator;
var
  LOuter: TThreadSafeAllocator;
  LPtr: Pointer;
begin
  LOuter := TThreadSafeAllocator.Create(DefaultAllocator);
  try
    LPtr := LOuter.GetMem(64);
    Check(LPtr <> nil, 'alloc via thread-safe wrapper');
    LOuter.FreeMem(LPtr);
  finally
    LOuter.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_thread_safe');
  T.Test('basic_alloc', @TestBasicAlloc);
  T.Test('zero_returns_nil', @TestZeroReturnsNil);
  T.Test('alloc_mem', @TestAllocMem);
  T.Test('realloc', @TestRealloc);
  T.Test('traits', @TestTraits);
  T.Test('many_allocations', @TestManyAllocations);
  T.Test('inner_allocator', @TestInnerAllocator);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
