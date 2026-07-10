program test_foundation;

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
  nextpas.core.mem.allocator.foundation;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- 基础生命周期 Basic lifecycle --- }

procedure TestGetRtlAllocator;
var
  LAlloc: IAllocator;
begin
  LAlloc := GetRtlAllocator;
  Check(LAlloc <> nil, 'GetRtlAllocator returned non-nil');
end;

procedure TestGetMem;
var
  LAlloc: IAllocator;
  LP: Pointer;
begin
  LAlloc := GetRtlAllocator;
  LP := LAlloc.GetMem(64);
  Check(LP <> nil, 'GetMem returned pointer');
  LAlloc.FreeMem(LP);
end;

procedure TestAllocMem;
var
  LAlloc: IAllocator;
  LP: Pointer;
begin
  LAlloc := GetRtlAllocator;
  LP := LAlloc.AllocMem(64);
  Check(LP <> nil, 'AllocMem returned pointer');
  LAlloc.FreeMem(LP);
end;

procedure TestReallocMem;
var
  LAlloc: IAllocator;
  LP: Pointer;
begin
  LAlloc := GetRtlAllocator;
  LP := LAlloc.GetMem(32);
  LP := LAlloc.ReallocMem(LP, 64);
  Check(LP <> nil, 'ReallocMem returned pointer');
  LAlloc.FreeMem(LP);
end;

procedure TestGetMemZeroReturnsNil;
var
  LAlloc: IAllocator;
begin
  LAlloc := GetRtlAllocator;
  Check(LAlloc.GetMem(0) <> nil, 'GetMem(0) returns non-nil from RTL');
end;

procedure TestFreeMemNilNoOp;
var
  LAlloc: IAllocator;
begin
  LAlloc := GetRtlAllocator;
  LAlloc.FreeMem(nil);
  Check(True, 'FreeMem(nil) did not crash');
end;

procedure TestTraits;
var
  LAlloc: IAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := GetRtlAllocator;
  LTraits := LAlloc.Traits;
  Check(LTraits.SupportsRealloc = True, 'supports realloc');
end;

{ --- 注册 Register --- }

begin
  T := TTestSuite.Create('test_foundation');
  T.Test('get_rtl_allocator', @TestGetRtlAllocator);
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
