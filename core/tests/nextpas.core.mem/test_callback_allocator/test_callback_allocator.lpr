program test_callback_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.callback;

var
  T: TTestSuite;
  LRunPassed: Boolean;
  GCallCount: Integer;

function MyGetMem(ASize: SizeUInt): Pointer;
begin
  Inc(GCallCount);
  Result := GetMem(ASize);
end;

function MyAllocMem(ASize: SizeUInt): Pointer;
begin
  Inc(GCallCount);
  Result := AllocMem(ASize);
end;

function MyReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  Inc(GCallCount);
  Result := ReallocMem(APtr, ASize);
end;

procedure MyFreeMem(APtr: Pointer);
begin
  Inc(GCallCount);
  FreeMem(APtr);
end;

procedure TestBasicAlloc;
var
  LAlloc: TCallbackAllocator;
  LPtr: Pointer;
begin
  GCallCount := 0;
  LAlloc := TCallbackAllocator.Init(@MyGetMem, @MyAllocMem, @MyReallocMem, @MyFreeMem);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    Check(GCallCount >= 1, 'callback called');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TCallbackAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TCallbackAllocator.Init(@MyGetMem, @MyAllocMem, @MyReallocMem, @MyFreeMem);
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
  LAlloc: TCallbackAllocator;
  LPtr, LNewPtr: Pointer;
begin
  LAlloc := TCallbackAllocator.Init(@MyGetMem, @MyAllocMem, @MyReallocMem, @MyFreeMem);
  try
    LPtr := LAlloc.GetMem(32);
    PByte(LPtr)^ := $AA;

    LNewPtr := LAlloc.ReallocMem(LPtr, 128);
    Check(LNewPtr <> nil, 'realloc ok');
    Check(PByte(LNewPtr)^ = $AA, 'data preserved');
    LAlloc.FreeMem(LNewPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: TCallbackAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TCallbackAllocator.Init(@MyGetMem, @MyAllocMem, @MyReallocMem, @MyFreeMem);
  try
    LTraits := LAlloc.Traits;
    Check(not LTraits.ThreadSafe, 'not thread-safe by default');
  finally
    LAlloc.Free;
  end;
end;

procedure TestCreateFunction;
var
  LAlloc: TCallbackAllocator;
  LPtr: Pointer;
begin
  LAlloc := CreateCallbackAllocator(@MyGetMem, @MyAllocMem, @MyReallocMem, @MyFreeMem);
  try
    LPtr := LAlloc.GetMem(32);
    Check(LPtr <> nil, 'allocated via factory');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleAllocs;
var
  LAlloc: TCallbackAllocator;
  LPtrs: array[0..3] of Pointer;
  LIdx: Integer;
begin
  GCallCount := 0;
  LAlloc := TCallbackAllocator.Init(@MyGetMem, @MyAllocMem, @MyReallocMem, @MyFreeMem);
  try
    for LIdx := 0 to 3 do
    begin
      LPtrs[LIdx] := LAlloc.GetMem(32);
      Check(LPtrs[LIdx] <> nil, 'alloc ' + IntToStr(LIdx));
    end;
    Check(GCallCount >= 4, '4 callbacks');

    for LIdx := 0 to 3 do
      LAlloc.FreeMem(LPtrs[LIdx]);
    Check(GCallCount >= 8, '8 callbacks total');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFreeNil;
var
  LAlloc: TCallbackAllocator;
begin
  GCallCount := 0;
  LAlloc := TCallbackAllocator.Init(@MyGetMem, @MyAllocMem, @MyReallocMem, @MyFreeMem);
  try
    LAlloc.FreeMem(nil);
    Check(True, 'no crash');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_callback_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Realloc', @TestRealloc);
  T.Test('Traits', @TestTraits);
  T.Test('CreateFunction', @TestCreateFunction);
  T.Test('MultipleAllocs', @TestMultipleAllocs);
  T.Test('FreeNil', @TestFreeNil);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
