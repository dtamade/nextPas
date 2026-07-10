program test_crt;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem.intf,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator.crt;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- 基础生命周期 Basic lifecycle --- }

procedure TestCreateDestroy;
var
  LAlloc: TCrtAllocator;
begin
  LAlloc := TCrtAllocator.Create;
  try
    Check(LAlloc <> nil, 'created');
  finally
    LAlloc.Free;
  end;
end;

procedure TestGetMem;
var
  LAlloc: TCrtAllocator;
  LP: Pointer;
begin
  LAlloc := TCrtAllocator.Create;
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
  LAlloc: TCrtAllocator;
  LP: Pointer;
begin
  LAlloc := TCrtAllocator.Create;
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
  LAlloc: TCrtAllocator;
  LP: Pointer;
begin
  LAlloc := TCrtAllocator.Create;
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
  LAlloc: TCrtAllocator;
begin
  LAlloc := TCrtAllocator.Create;
  try
    Check(LAlloc.GetMem(0) = nil, 'GetMem(0) returns nil');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFreeMemNilNoOp;
var
  LAlloc: TCrtAllocator;
begin
  LAlloc := TCrtAllocator.Create;
  try
    LAlloc.FreeMem(nil);
    Check(True, 'FreeMem(nil) did not crash');
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: TCrtAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TCrtAllocator.Create;
  try
    LTraits := LAlloc.Traits;
    Check(not LTraits.SupportsRealloc, 'does not support realloc');
  finally
    LAlloc.Free;
  end;
end;

{ --- 注册 Register --- }

begin
  T := TTestSuite.Create('test_crt');
  T.Test('create_destroy', @TestCreateDestroy);
  T.Test('getmem', @TestGetMem);
  T.Test('allocmem', @TestAllocMem);
  T.Test('reallocmem', @TestReallocMem);
  T.Test('getmem_zero_returns_nil', @TestGetMemZeroReturnsNil);
  T.Test('freemem_nil_noop', @TestFreeMemNilNoOp);
  T.Test('traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
