program test_callback;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem.intf,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.callback;

function MyGetMem(ASize: SizeUInt): Pointer;
begin
  Result := DefaultAllocator.GetMem(ASize);
end;

function MyAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := DefaultAllocator.AllocMem(ASize);
end;

function MyReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  Result := DefaultAllocator.ReallocMem(APtr, ASize);
end;

procedure MyFreeMem(APtr: Pointer);
begin
  DefaultAllocator.FreeMem(APtr);
end;

var
  T: TTestSuite;

{ --- 基础生命周期 Basic lifecycle --- }

procedure TestCreateDestroy;
var
  LAlloc: TCallbackAllocator;
begin
  LAlloc := TCallbackAllocator.Init(@MyGetMem, @MyAllocMem, @MyReallocMem, @MyFreeMem);
  try
    Check(LAlloc <> nil, 'created');
  finally
    LAlloc.Free;
  end;
end;

procedure TestGetMem;
var
  LAlloc: TCallbackAllocator;
  LP: Pointer;
begin
  LAlloc := TCallbackAllocator.Init(@MyGetMem, @MyAllocMem, @MyReallocMem, @MyFreeMem);
  try
    LP := LAlloc.GetMem(64);
    Check(LP <> nil, 'GetMem returned pointer');
    LAlloc.FreeMem(LP);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMem;
var
  LAlloc: TCallbackAllocator;
  LP: Pointer;
begin
  LAlloc := TCallbackAllocator.Init(@MyGetMem, @MyAllocMem, @MyReallocMem, @MyFreeMem);
  try
    LP := LAlloc.AllocMem(64);
    Check(LP <> nil, 'AllocMem returned pointer');
    LAlloc.FreeMem(LP);
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocMem;
var
  LAlloc: TCallbackAllocator;
  LP: Pointer;
begin
  LAlloc := TCallbackAllocator.Init(@MyGetMem, @MyAllocMem, @MyReallocMem, @MyFreeMem);
  try
    LP := LAlloc.GetMem(32);
    LP := LAlloc.ReallocMem(LP, 64);
    Check(LP <> nil, 'ReallocMem returned pointer');
    LAlloc.FreeMem(LP);
  finally
    LAlloc.Free;
  end;
end;

procedure TestGetMemZeroReturnsNil;
var
  LAlloc: TCallbackAllocator;
begin
  LAlloc := TCallbackAllocator.Init(@MyGetMem, @MyAllocMem, @MyReallocMem, @MyFreeMem);
  try
    Check(LAlloc.GetMem(0) = nil, 'GetMem(0) returns nil');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFreeMemNilNoOp;
var
  LAlloc: TCallbackAllocator;
begin
  LAlloc := TCallbackAllocator.Init(@MyGetMem, @MyAllocMem, @MyReallocMem, @MyFreeMem);
  try
    LAlloc.FreeMem(nil);
    Check(True, 'FreeMem(nil) did not crash');
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
    Check(LTraits.SupportsRealloc = True, 'supports realloc');
  finally
    LAlloc.Free;
  end;
end;

{ --- 注册 Register --- }

begin
  T := TTestSuite.Create('test_callback');
  T.Test('create_destroy', @TestCreateDestroy);
  T.Test('getmem', @TestGetMem);
  T.Test('allocmem', @TestAllocMem);
  T.Test('reallocmem', @TestReallocMem);
  T.Test('getmem_zero_returns_nil', @TestGetMemZeroReturnsNil);
  T.Test('freemem_nil_noop', @TestFreeMemNilNoOp);
  T.Test('traits', @TestTraits);
  T.Run;
  T.Summary;
end.
