program test_arena_group;

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
  nextpas.core.mem.allocator.arena_group;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- 基础生命周期 Basic lifecycle --- }

procedure TestCreateDestroy;
var
  LAlloc: TArenaGroupAllocator;
begin
  LAlloc := TArenaGroupAllocator.Create(DefaultAllocator);
  try
    Check(LAlloc <> nil, 'created');
  finally
    LAlloc.Free;
  end;
end;

procedure TestGetMem;
var
  LAlloc: TArenaGroupAllocator;
  LP: Pointer;
begin
  LAlloc := TArenaGroupAllocator.Create(DefaultAllocator);
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
  LAlloc: TArenaGroupAllocator;
  LP: Pointer;
begin
  LAlloc := TArenaGroupAllocator.Create(DefaultAllocator);
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
  LAlloc: TArenaGroupAllocator;
  LP: Pointer;
begin
  LAlloc := TArenaGroupAllocator.Create(DefaultAllocator);
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
  LAlloc: TArenaGroupAllocator;
begin
  LAlloc := TArenaGroupAllocator.Create(DefaultAllocator);
  try
    Check(LAlloc.GetMem(0) = nil, 'GetMem(0) returns nil');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFreeMemNilNoOp;
var
  LAlloc: TArenaGroupAllocator;
begin
  LAlloc := TArenaGroupAllocator.Create(DefaultAllocator);
  try
    LAlloc.FreeMem(nil);
    Check(True, 'FreeMem(nil) did not crash');
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: TArenaGroupAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TArenaGroupAllocator.Create(DefaultAllocator);
  try
    LTraits := LAlloc.Traits;
    Check(not LTraits.SupportsRealloc, 'does not support realloc');
  finally
    LAlloc.Free;
  end;
end;

{ --- 注册 Register --- }

begin
  T := TTestSuite.Create('test_arena_group');
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
