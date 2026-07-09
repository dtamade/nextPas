program test_leak_check;

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
  nextpas.core.mem.allocator.leak_check;

var
  T: TTestSuite;

{ --- 基础生命周期 Basic lifecycle --- }

procedure TestRunTestWithLeakCheck(AAllocator: IAllocator);
begin
  { Do nothing }
end;

procedure TestRunTestWithLeakCheckAlloc(AAllocator: IAllocator);
var
  LP: Pointer;
begin
  LP := AAllocator.GetMem(64);
  AAllocator.FreeMem(LP);
end;

procedure TestLeakCheckNoLeaks;
var
  LResult: TLeakCheckResult;
begin
  LResult := RunTestWithLeakCheck(@TestRunTestWithLeakCheck);
  Check(not LResult.HasLeaks, 'no leaks');
end;

procedure TestLeakCheckWithAllocFree;
var
  LResult: TLeakCheckResult;
begin
  LResult := RunTestWithLeakCheck(@TestRunTestWithLeakCheckAlloc);
  Check(not LResult.HasLeaks, 'no leaks with alloc/free');
end;

{ --- 注册 Register --- }

begin
  T := TTestSuite.Create('test_leak_check');
  T.Test('leak_check_no_leaks', @TestLeakCheckNoLeaks);
  T.Test('leak_check_with_alloc_free', @TestLeakCheckWithAllocFree);
  T.Run;
  T.Summary;
end.
