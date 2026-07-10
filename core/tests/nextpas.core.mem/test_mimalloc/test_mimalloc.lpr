program test_mimalloc;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem.intf,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator.mimalloc;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- 基础生命周期 Basic lifecycle --- }

procedure TestTryGetMimallocAllocator;
var
  LAlloc: IAllocator;
  LAvailable: Boolean;
begin
  LAvailable := TryGetMimallocAllocator(LAlloc);
  if LAvailable then
    Check(LAlloc <> nil, 'mimalloc available')
  else
    Check(LAlloc = nil, 'mimalloc not available');
end;

procedure TestGetMem;
var
  LAlloc: IAllocator;
  LP: Pointer;
begin
  if not TryGetMimallocAllocator(LAlloc) then
    Exit;
  LP := LAlloc.GetMem(64);
  Check(LP <> nil, 'GetMem returned pointer');
  LAlloc.FreeMem(LP);
end;

procedure TestAllocMem;
var
  LAlloc: IAllocator;
  LP: Pointer;
begin
  if not TryGetMimallocAllocator(LAlloc) then
    Exit;
  LP := LAlloc.AllocMem(64);
  Check(LP <> nil, 'AllocMem returned pointer');
  LAlloc.FreeMem(LP);
end;

procedure TestReallocMem;
var
  LAlloc: IAllocator;
  LP: Pointer;
begin
  if not TryGetMimallocAllocator(LAlloc) then
    Exit;
  LP := LAlloc.GetMem(32);
  LP := LAlloc.ReallocMem(LP, 64);
  Check(LP <> nil, 'ReallocMem returned pointer');
  LAlloc.FreeMem(LP);
end;

procedure TestFreeMemNilNoOp;
var
  LAlloc: IAllocator;
begin
  if not TryGetMimallocAllocator(LAlloc) then
    Exit;
  LAlloc.FreeMem(nil);
  Check(True, 'FreeMem(nil) did not crash');
end;

procedure TestTraits;
var
  LAlloc: IAllocator;
  LTraits: TAllocatorTraits;
begin
  if not TryGetMimallocAllocator(LAlloc) then
    Exit;
  LTraits := LAlloc.Traits;
  Check(LTraits.SupportsRealloc = True, 'supports realloc');
end;

{ --- 注册 Register --- }

begin
  T := TTestSuite.Create('test_mimalloc');
  T.Test('try_get_mimalloc_allocator', @TestTryGetMimallocAllocator);
  T.Test('getmem', @TestGetMem);
  T.Test('allocmem', @TestAllocMem);
  T.Test('reallocmem', @TestReallocMem);
  T.Test('freemem_nil_noop', @TestFreeMemNilNoOp);
  T.Test('traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
