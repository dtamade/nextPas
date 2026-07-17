program test_platform_resource_wine;

{$mode objfpc}{$H+}

uses
  nextpas.core.platform.resource,
  nextpas.core.platform.resource.base;

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
  WriteLn('=== platform.resource Wine 测试 ===');
  LPassed := 0;
  LFailed := 0;

  // Test 1: resource limit kind enum values
  WriteLn('Test 1: resource limit kind enum values');
  Check(Ord(prlkCpuTime) = 0, 'prlkCpuTime = 0');
  Check(Ord(prlkFileSize) = 1, 'prlkFileSize = 1');
  Check(Ord(prlkOpenFiles) = 5, 'prlkOpenFiles = 5');
  Check(Ord(prlkProcessCount) = 8, 'prlkProcessCount = 8');

  // Test 2: resource limit record initialization
  WriteLn('Test 2: resource limit record initialization');
  FillChar(LLimit, SizeOf(LLimit), 0);
  Check(LLimit.Current = 0, 'Current = 0');
  Check(LLimit.Maximum = 0, 'Maximum = 0');

  // Test 3: PLATFORM_RESOURCE_LIMIT_INFINITY constant
  WriteLn('Test 3: PLATFORM_RESOURCE_LIMIT_INFINITY constant');
  Check(PLATFORM_RESOURCE_LIMIT_INFINITY = High(UInt64), 'PLATFORM_RESOURCE_LIMIT_INFINITY = High(UInt64)');

  // Test 4: get_limit behavior (Linux: success, Windows: UNSUPPORTED)
  WriteLn('Test 4: get_limit behavior');
  LRet := platform_resource_get_limit(prlkCpuTime, LLimit);
  {$IFDEF NEXTPAS_WINDOWS}
  Check(LRet = PLATFORM_RESOURCE_ERROR_UNSUPPORTED, 'Windows: get_limit returns UNSUPPORTED');
  {$ELSE}
  Check(LRet = 0, 'Linux: get_limit returns success');
  {$ENDIF}

  // Test 5: set_limit behavior (Linux: may succeed, Windows: UNSUPPORTED)
  WriteLn('Test 5: set_limit behavior');
  LLimit.Current := 1024;
  LLimit.Maximum := 2048;
  LRet := platform_resource_set_limit(prlkCpuTime, LLimit);
  {$IFDEF NEXTPAS_WINDOWS}
  Check(LRet = PLATFORM_RESOURCE_ERROR_UNSUPPORTED, 'Windows: set_limit returns UNSUPPORTED');
  {$ELSE}
  // Linux may succeed or fail depending on permissions
  WriteLn('    set_limit returned: ', LRet);
  {$ENDIF}

  // Test 6: get_limit with invalid kind
  WriteLn('Test 6: get_limit with invalid kind');
  LRet := platform_resource_get_limit(TPlatformResourceLimitKind(99), LLimit);
  Check(LRet = PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT, 'get_limit invalid kind returns INVALID_ARGUMENT');

  // Test 7: set_limit with invalid kind
  WriteLn('Test 7: set_limit with invalid kind');
  LRet := platform_resource_set_limit(TPlatformResourceLimitKind(99), LLimit);
  Check(LRet = PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT, 'set_limit invalid kind returns INVALID_ARGUMENT');

  // Test 8: error constants are platform-specific
  WriteLn('Test 8: error constants are platform-specific');
  {$IFDEF NEXTPAS_WINDOWS}
  Check(PLATFORM_RESOURCE_ERROR_UNSUPPORTED = 50, 'Windows UNSUPPORTED = 50');
  Check(PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT = 87, 'Windows INVALID_ARGUMENT = 87');
  {$ENDIF}

  WriteLn;
  WriteLn('=== 结果: ', LPassed, ' passed, ', LFailed, ' failed ===');
  if LFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
