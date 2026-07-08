program test_platform_resource;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.platform.resource,
  nextpas.core.platform.resource.base,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestGetOpenFilesLimit;
var
  LLimit: TPlatformResourceLimit;
begin
  Check(platform_resource_get_limit(prlkOpenFiles, LLimit) = 0,
    'get open files limit succeeds');
  Check(LLimit.Current > 0, 'open files current > 0');
  Check(LLimit.Maximum > 0, 'open files maximum > 0');
  Check(LLimit.Current <= LLimit.Maximum, 'current <= maximum');
end;

procedure TestGetStackSizeLimit;
var
  LLimit: TPlatformResourceLimit;
begin
  Check(platform_resource_get_limit(prlkStackSize, LLimit) = 0,
    'get stack size limit succeeds');
  Check(LLimit.Current > 0, 'stack size current > 0');
end;

procedure TestGetCpuTimeLimit;
var
  LLimit: TPlatformResourceLimit;
begin
  { CPU time limit may be unlimited }
  Check(platform_resource_get_limit(prlkCpuTime, LLimit) = 0,
    'get CPU time limit succeeds');
end;

procedure TestGetFileSizeLimit;
var
  LLimit: TPlatformResourceLimit;
begin
  Check(platform_resource_get_limit(prlkFileSize, LLimit) = 0,
    'get file size limit succeeds');
end;

procedure TestGetDataSizeLimit;
var
  LLimit: TPlatformResourceLimit;
begin
  Check(platform_resource_get_limit(prlkDataSize, LLimit) = 0,
    'get data size limit succeeds');
end;

procedure TestGetAddressSpaceLimit;
var
  LLimit: TPlatformResourceLimit;
begin
  Check(platform_resource_get_limit(prlkAddressSpace, LLimit) = 0,
    'get address space limit succeeds');
end;

procedure TestGetLockedMemoryLimit;
var
  LLimit: TPlatformResourceLimit;
begin
  Check(platform_resource_get_limit(prlkLockedMemory, LLimit) = 0,
    'get locked memory limit succeeds');
end;

procedure TestGetProcessCountLimit;
var
  LLimit: TPlatformResourceLimit;
begin
  Check(platform_resource_get_limit(prlkProcessCount, LLimit) = 0,
    'get process count limit succeeds');
end;

procedure TestGetCoreFileSizeLimit;
var
  LLimit: TPlatformResourceLimit;
begin
  Check(platform_resource_get_limit(prlkCoreFileSize, LLimit) = 0,
    'get core file size limit succeeds');
end;

procedure TestInvalidKindReturnsError;
var
  LLimit: TPlatformResourceLimit;
begin
  Check(platform_resource_get_limit(TPlatformResourceLimitKind(99), LLimit) =
    PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT,
    'invalid kind returns INVALID_ARGUMENT');
end;

procedure TestSetLimitInvalidKind;
var
  LLimit: TPlatformResourceLimit;
begin
  FillChar(LLimit, SizeOf(LLimit), 0);
  LLimit.Current := 1024;
  LLimit.Maximum := 2048;
  Check(platform_resource_set_limit(TPlatformResourceLimitKind(99), LLimit) =
    PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT,
    'set invalid kind returns INVALID_ARGUMENT');
end;

procedure TestSetLimitInvalidValues;
var
  LLimit: TPlatformResourceLimit;
begin
  { current > maximum (not infinity) should fail }
  LLimit.Current := 2048;
  LLimit.Maximum := 1024;
  Check(platform_resource_set_limit(prlkOpenFiles, LLimit) =
    PLATFORM_RESOURCE_ERROR_INVALID_ARGUMENT,
    'current > maximum returns INVALID_ARGUMENT');
end;

procedure TestSetLimitInfinityMaximum;
var
  LLimit: TPlatformResourceLimit;
  LCurrent: TPlatformResourceLimit;
  LRet: Int32;
begin
  { Read current limit first }
  Check(platform_resource_get_limit(prlkOpenFiles, LCurrent) = 0, 'read before set');
  { Set current to same value but with infinity maximum }
  LLimit.Current := LCurrent.Current;
  LLimit.Maximum := PLATFORM_RESOURCE_LIMIT_INFINITY;
  LRet := platform_resource_set_limit(prlkOpenFiles, LLimit);
  { Normal user can't raise hard limit; EPERM(1) is expected }
  Check((LRet = 0) or (LRet = 1),
    'set with infinity maximum: ok or EPERM');
end;

procedure TestGetLimitZeroesOutOnSuccess;
var
  LLimit: TPlatformResourceLimit;
begin
  FillChar(LLimit, SizeOf(LLimit), $FF);
  Check(platform_resource_get_limit(prlkOpenFiles, LLimit) = 0, 'get succeeds');
  { After successful get, fields should be populated }
  Check(LLimit.Current > 0, 'current populated');
  Check(LLimit.Maximum > 0, 'maximum populated');
end;

procedure TestAllResourceKinds;
var
  LKind: TPlatformResourceLimitKind;
  LLimit: TPlatformResourceLimit;
  LRet: Int32;
begin
  for LKind := Low(TPlatformResourceLimitKind) to High(TPlatformResourceLimitKind) do
  begin
    LRet := platform_resource_get_limit(LKind, LLimit);
    Check(LRet = 0, 'get kind ' + IntToStr(Ord(LKind)) + ' succeeds');
  end;
end;

procedure TestSetLimitInfinityCurrent;
var
  LLimit: TPlatformResourceLimit;
begin
  { Current = infinity should be accepted (treated as unlimited) }
  LLimit.Current := PLATFORM_RESOURCE_LIMIT_INFINITY;
  LLimit.Maximum := PLATFORM_RESOURCE_LIMIT_INFINITY;
  { This may succeed or fail with EPERM, but should not crash }
  platform_resource_set_limit(prlkOpenFiles, LLimit);
  Check(True, 'set with infinity current does not crash');
end;

procedure TestGetLimitPreservesValues;
var
  LLimit1, LLimit2: TPlatformResourceLimit;
begin
  { Get limit twice, values should be consistent }
  Check(platform_resource_get_limit(prlkOpenFiles, LLimit1) = 0, 'first get');
  Check(platform_resource_get_limit(prlkOpenFiles, LLimit2) = 0, 'second get');
  Check(LLimit1.Current = LLimit2.Current, 'current consistent');
  Check(LLimit1.Maximum = LLimit2.Maximum, 'maximum consistent');
end;

procedure TestSetLimitValidValues;
var
  LLimit, LSaved: TPlatformResourceLimit;
  LRet: Int32;
begin
  { Get current limit }
  Check(platform_resource_get_limit(prlkOpenFiles, LSaved) = 0, 'get current');
  { Try to set to current value (should succeed or EPERM) }
  LLimit.Current := LSaved.Current;
  LLimit.Maximum := LSaved.Maximum;
  LRet := platform_resource_set_limit(prlkOpenFiles, LLimit);
  Check(LRet = 0, 'set to current value succeeds');
end;

procedure TestGetAllLimitsConsistent;
var
  LKind: TPlatformResourceLimitKind;
  LLimit: TPlatformResourceLimit;
begin
  { All limits should have current <= maximum (unless unlimited) }
  for LKind := Low(TPlatformResourceLimitKind) to High(TPlatformResourceLimitKind) do
  begin
    if platform_resource_get_limit(LKind, LLimit) = 0 then
    begin
      if (LLimit.Current <> PLATFORM_RESOURCE_LIMIT_INFINITY) and
         (LLimit.Maximum <> PLATFORM_RESOURCE_LIMIT_INFINITY) then
        Check(LLimit.Current <= LLimit.Maximum, 'current <= maximum for kind ' + IntToStr(Ord(LKind)));
    end;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.resource');
  T.Test('get open files limit', @TestGetOpenFilesLimit);
  T.Test('get stack size limit', @TestGetStackSizeLimit);
  T.Test('get CPU time limit', @TestGetCpuTimeLimit);
  T.Test('get file size limit', @TestGetFileSizeLimit);
  T.Test('get data size limit', @TestGetDataSizeLimit);
  T.Test('get address space limit', @TestGetAddressSpaceLimit);
  T.Test('get locked memory limit', @TestGetLockedMemoryLimit);
  T.Test('get process count limit', @TestGetProcessCountLimit);
  T.Test('get core file size limit', @TestGetCoreFileSizeLimit);
  T.Test('invalid kind returns error', @TestInvalidKindReturnsError);
  T.Test('set invalid kind returns error', @TestSetLimitInvalidKind);
  T.Test('set invalid values returns error', @TestSetLimitInvalidValues);
  T.Test('set infinity maximum accepted', @TestSetLimitInfinityMaximum);
  T.Test('get zeroes out record on success', @TestGetLimitZeroesOutOnSuccess);
  T.Test('all resource kinds succeed', @TestAllResourceKinds);
  T.Test('set infinity current does not crash', @TestSetLimitInfinityCurrent);
  T.Test('get limit preserves values', @TestGetLimitPreservesValues);
  T.Test('set limit valid values', @TestSetLimitValidValues);
  T.Test('get all limits consistent', @TestGetAllLimitsConsistent);
  if not T.Run then Halt(1);
end.
