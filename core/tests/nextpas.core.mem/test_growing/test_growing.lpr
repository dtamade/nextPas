program test_growing;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem.intf,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator.growing;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- 基础生命周期 Basic lifecycle --- }

procedure TestCreateDestroy;
var
  LAlloc: TGrowingAllocator;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    Check(LAlloc <> nil, 'created');
  finally
    LAlloc.Free;
  end;
end;

procedure TestGetMem;
var
  LAlloc: TGrowingAllocator;
  LP: Pointer;
begin
  LAlloc := TGrowingAllocator.Create;
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
  LAlloc: TGrowingAllocator;
  LP: Pointer;
begin
  LAlloc := TGrowingAllocator.Create;
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
  LAlloc: TGrowingAllocator;
  LP: Pointer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LP := LAlloc.GetMem(32);
    LP := LAlloc.ReallocMem(LP, 32, 64);
    Check(LP <> nil, 'ReallocMem returned pointer');
    LAlloc.FreeMem(LP);
  finally
    LAlloc.Free;
  end;
end;

procedure TestGetMemZeroReturnsNil;
var
  LAlloc: TGrowingAllocator;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    Check(LAlloc.GetMem(0) = nil, 'GetMem(0) returns nil');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFreeMemNilNoOp;
var
  LAlloc: TGrowingAllocator;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LAlloc.FreeMem(nil);
    Check(True, 'FreeMem(nil) did not crash');
  finally
    LAlloc.Free;
  end;
end;

{ --- 注册 Register --- }

begin
  T := TTestSuite.Create('test_growing');
  T.Test('create_destroy', @TestCreateDestroy);
  T.Test('getmem', @TestGetMem);
  T.Test('allocmem', @TestAllocMem);
  T.Test('reallocmem', @TestReallocMem);
  T.Test('getmem_zero_returns_nil', @TestGetMemZeroReturnsNil);
  T.Test('freemem_nil_noop', @TestFreeMemNilNoOp);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
