program test_registry;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.registry,
  nextpas.core.mem.error;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestSingleton;
var
  LR1, LR2: TAllocatorRegistry;
begin
  LR1 := TAllocatorRegistry.Instance;
  LR2 := TAllocatorRegistry.Instance;
  Check(LR1 = LR2, 'Instance should return same object');
end;

procedure TestRegisterAndGet;
var
  LR: TAllocatorRegistry;
  LAlloc: IAllocator;
begin
  LR := TAllocatorRegistry.Instance;
  LR.Register('test_alloc', DefaultAllocator);
  Check(LR.Contains('test_alloc'), 'should contain test_alloc');
  Check(LR.TryGet('test_alloc', LAlloc), 'TryGet should succeed');
  Check(LAlloc <> nil, 'allocator should not be nil');
  LR.Unregister('test_alloc');
end;

procedure TestGetNotFound;
var
  LR: TAllocatorRegistry;
  LAlloc: IAllocator;
  LRaised: Boolean;
begin
  LR := TAllocatorRegistry.Instance;
  LRaised := False;
  try
    LAlloc := LR.Get('nonexistent');
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'should raise for nonexistent');
end;

procedure TestTryGetNotFound;
var
  LR: TAllocatorRegistry;
  LAlloc: IAllocator;
begin
  LR := TAllocatorRegistry.Instance;
  Check(not LR.TryGet('nonexistent', LAlloc), 'TryGet should return False');
  Check(LAlloc = nil, 'allocator should be nil');
end;

procedure TestUnregister;
var
  LR: TAllocatorRegistry;
begin
  LR := TAllocatorRegistry.Instance;
  LR.Register('temp_alloc', DefaultAllocator);
  Check(LR.Contains('temp_alloc'), 'should contain before unregister');
  LR.Unregister('temp_alloc');
  Check(not LR.Contains('temp_alloc'), 'should not contain after unregister');
end;

procedure TestOverwrite;
var
  LR: TAllocatorRegistry;
  LAlloc1, LAlloc2: IAllocator;
begin
  LR := TAllocatorRegistry.Instance;
  LR.Register('overwrite_alloc', DefaultAllocator);
  LR.TryGet('overwrite_alloc', LAlloc1);
  LR.Register('overwrite_alloc', DefaultAllocator); { overwrite }
  LR.TryGet('overwrite_alloc', LAlloc2);
  Check(LAlloc1 = LAlloc2, 'should be same after overwrite');
  LR.Unregister('overwrite_alloc');
end;

procedure TestCount;
var
  LR: TAllocatorRegistry;
  LBefore: SizeUInt;
begin
  LR := TAllocatorRegistry.Instance;
  LBefore := LR.Count;
  LR.Register('count_test', DefaultAllocator);
  Check(LR.Count = LBefore + 1, 'count should increase');
  LR.Unregister('count_test');
  Check(LR.Count = LBefore, 'count should decrease');
end;

procedure TestEmptyNameRaises;
var
  LR: TAllocatorRegistry;
  LRaised: Boolean;
begin
  LR := TAllocatorRegistry.Instance;
  LRaised := False;
  try
    LR.Register('', DefaultAllocator);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'should raise for empty name');
end;

procedure TestNilAllocatorRaises;
var
  LR: TAllocatorRegistry;
  LRaised: Boolean;
begin
  LR := TAllocatorRegistry.Instance;
  LRaised := False;
  try
    LR.Register('nil_test', nil);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'should raise for nil allocator');
end;

begin
  T := TTestSuite.Create('test_registry');
  T.Test('singleton', @TestSingleton);
  T.Test('register_and_get', @TestRegisterAndGet);
  T.Test('get_not_found', @TestGetNotFound);
  T.Test('try_get_not_found', @TestTryGetNotFound);
  T.Test('unregister', @TestUnregister);
  T.Test('overwrite', @TestOverwrite);
  T.Test('count', @TestCount);
  T.Test('empty_name_raises', @TestEmptyNameRaises);
  T.Test('nil_allocator_raises', @TestNilAllocatorRaises);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
  TAllocatorRegistry.ReleaseInstance;
end.
