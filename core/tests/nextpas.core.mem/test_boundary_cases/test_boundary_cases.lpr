program test_boundary_cases;
{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.mem.allocator.rtl,
  nextpas.core.mem.allocator.guard,
  nextpas.core.mem.allocator.sentinel,
  nextpas.core.mem.allocator.aligned,
  nextpas.core.mem.allocator.cascade,
  nextpas.core.mem.intf,
  nextpas.core.mem.error;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestZeroSizeGetMem;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  LAlloc := GetRtlAllocator;
  LPtr := LAlloc.GetMem(0);
  Check(LPtr = nil, 'GetMem(0) must return nil');
end;

procedure TestZeroSizeAllocMem;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  LAlloc := GetRtlAllocator;
  LPtr := LAlloc.AllocMem(0);
  Check(LPtr = nil, 'AllocMem(0) must return nil');
end;

procedure TestMaxSizeGetMem;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  LAlloc := GetRtlAllocator;
  LPtr := LAlloc.GetMem(High(SizeUInt));
  Check(LPtr = nil, 'GetMem(High(SizeUInt)) must return nil (OOM)');
end;

procedure TestNearMaxSizeGetMem;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  LAlloc := GetRtlAllocator;
  LPtr := LAlloc.GetMem(High(SizeUInt) - 100);
  Check(LPtr = nil, 'GetMem(High(SizeUInt)-100) must return nil (OOM)');
end;

procedure TestNilFreeMem;
var
  LAlloc: IAllocator;
begin
  LAlloc := GetRtlAllocator;
  LAlloc.FreeMem(nil);
  Check(True, 'FreeMem(nil) must be a no-op');
end;

procedure TestReallocNilGetMem;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  LAlloc := GetRtlAllocator;
  LPtr := LAlloc.ReallocMem(nil, 100);
  Check(LPtr <> nil, 'ReallocMem(nil, 100) must behave like GetMem(100)');
  LAlloc.FreeMem(LPtr);
end;

procedure TestReallocZeroFreeMem;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  LAlloc := GetRtlAllocator;
  LPtr := LAlloc.GetMem(64);
  Check(LPtr <> nil, 'Initial GetMem(64) must succeed');
  LPtr := LAlloc.ReallocMem(LPtr, 0);
  Check(LPtr = nil, 'ReallocMem(ptr, 0) must free and return nil');
end;

procedure TestGuardOverflowProtection;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  LAlloc := TGuardAllocator.Create as IAllocator;
  LPtr := LAlloc.GetMem(High(SizeUInt));
  Check(LPtr = nil, 'TGuardAllocator.GetMem(High(SizeUInt)) must return nil');
end;

procedure TestSentinelOverflowProtection;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  LAlloc := TSentinelAllocator.Create(GetRtlAllocator, 0) as IAllocator;
  LPtr := LAlloc.GetMem(High(SizeUInt));
  Check(LPtr = nil, 'TSentinelAllocator.GetMem(High(SizeUInt)) must return nil');
end;

begin
  { FPC default may raise RTE on OOM; contract is nil return. }
  ReturnNilIfGrowHeapFails := True;

  T := TTestSuite.Create('test_boundary_cases');
  T.Test('ZeroSizeGetMem', @TestZeroSizeGetMem);
  T.Test('ZeroSizeAllocMem', @TestZeroSizeAllocMem);
  T.Test('MaxSizeGetMem', @TestMaxSizeGetMem);
  T.Test('NearMaxSizeGetMem', @TestNearMaxSizeGetMem);
  T.Test('NilFreeMem', @TestNilFreeMem);
  T.Test('ReallocNilGetMem', @TestReallocNilGetMem);
  T.Test('ReallocZeroFreeMem', @TestReallocZeroFreeMem);
  T.Test('GuardOverflowProtection', @TestGuardOverflowProtection);
  T.Test('SentinelOverflowProtection', @TestSentinelOverflowProtection);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
