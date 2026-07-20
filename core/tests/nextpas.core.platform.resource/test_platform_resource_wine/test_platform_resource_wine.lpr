program test_platform_resource_wine;

{$mode objfpc}{$H+}

uses
  nextpas.core.platform.resource,
  nextpas.core.platform.resource.base,
  nextpas.core.platform.error;

var
  LPassed, LFailed: Int32;

procedure Check(ACond: Boolean; const AName: string);
begin
  if ACond then
  begin
    Inc(LPassed);
    WriteLn('  ✓ ', AName);
  end
  else
  begin
    Inc(LFailed);
    WriteLn('  ✗ ', AName);
  end;
end;

var
  LRet: Int32;
  LLimit: TPlatformResourceLimit;
begin
  WriteLn('=== platform.resource wine-runtime-smoke ===');
  WriteLn('truth=wine-runtime-smoke; not real Windows runtime ready');
  LPassed := 0;
  LFailed := 0;

  WriteLn('Test 1: enum ordinals');
  Check(Ord(prlkCpuTime) = 0, 'prlkCpuTime = 0');
  Check(Ord(prlkFileSize) = 1, 'prlkFileSize = 1');
  Check(Ord(prlkOpenFiles) = 5, 'prlkOpenFiles = 5');
  Check(Ord(prlkProcessCount) = 8, 'prlkProcessCount = 8');

  WriteLn('Test 2: limit record zero-init');
  FillChar(LLimit, SizeOf(LLimit), 0);
  Check(LLimit.Current = 0, 'Current = 0');
  Check(LLimit.Maximum = 0, 'Maximum = 0');

  WriteLn('Test 3: infinity constant');
  Check(PLATFORM_RESOURCE_LIMIT_INFINITY = High(UInt64),
    'PLATFORM_RESOURCE_LIMIT_INFINITY = High(UInt64)');

  WriteLn('Test 4: get_limit on Windows host path');
  LRet := platform_resource_get_limit(prlkCpuTime, LLimit);
  Check(LRet = PLATFORM_ERR_UNSUPPORTED,
    'Windows get_limit returns PLATFORM_ERR_UNSUPPORTED');

  WriteLn('Test 5: set_limit on Windows host path');
  LLimit.Current := 1024;
  LLimit.Maximum := 2048;
  LRet := platform_resource_set_limit(prlkCpuTime, LLimit);
  Check(LRet = PLATFORM_ERR_UNSUPPORTED,
    'Windows set_limit returns PLATFORM_ERR_UNSUPPORTED');

  WriteLn('Test 6: get_limit invalid kind');
  LRet := platform_resource_get_limit(TPlatformResourceLimitKind(99), LLimit);
  Check(LRet = PLATFORM_ERR_INVALID,
    'get_limit invalid kind returns PLATFORM_ERR_INVALID');

  WriteLn('Test 7: set_limit invalid kind');
  LRet := platform_resource_set_limit(TPlatformResourceLimitKind(99), LLimit);
  Check(LRet = PLATFORM_ERR_INVALID,
    'set_limit invalid kind returns PLATFORM_ERR_INVALID');

  WriteLn('Test 8: set_limit invalid values (current > max)');
  LLimit.Current := 4096;
  LLimit.Maximum := 1024;
  LRet := platform_resource_set_limit(prlkCpuTime, LLimit);
  Check(LRet = PLATFORM_ERR_INVALID,
    'set_limit current>max returns PLATFORM_ERR_INVALID');

  WriteLn;
  WriteLn('=== 结果: ', LPassed, ' passed, ', LFailed, ' failed ===');
  if LFailed > 0 then
    Halt(1);
end.
