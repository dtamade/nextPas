program test_platform_args_wine;

{$mode objfpc}{$H+}

uses
  nextpas.core.platform.args,
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
  LCount, LRet: Int32;
  LBuf: array[0..255] of AnsiChar;
begin
  WriteLn('=== platform.args Wine 测试 ===');
  LPassed := 0;
  LFailed := 0;

  // Test 1: args_count returns valid count
  WriteLn('Test 1: args_count returns valid count');
  LCount := platform_args_count;
  Check(LCount >= 0, 'args_count >= 0');
  WriteLn('    args_count = ', LCount);

  // Test 2: args_get with index 0 (program name)
  WriteLn('Test 2: args_get with index 0 (program name)');
  LRet := platform_args_get(0, @LBuf[0], Length(LBuf));
  Check(LRet > 0, 'args_get(0) returns > 0');
  if LRet > 0 then
    WriteLn('    program name: ', LBuf);

  // Test 3: args_get with invalid index
  WriteLn('Test 3: args_get with invalid index');
  LRet := platform_args_get(-1, @LBuf[0], Length(LBuf));
  Check(LRet = PLATFORM_ERR_INVALID, 'args_get(-1) returns INVALID');

  // Test 4: args_get with nil buffer
  WriteLn('Test 4: args_get with nil buffer');
  LRet := platform_args_get(0, nil, 0);
  Check(LRet = PLATFORM_ERR_INVALID, 'args_get(nil) returns INVALID');

  // Test 5: args_get with small buffer
  WriteLn('Test 5: args_get with small buffer');
  LRet := platform_args_get(0, @LBuf[0], 1);
  // Should return required length or truncate
  WriteLn('    args_get with small buffer returned: ', LRet);

  // Test 6: exe_path returns valid path
  WriteLn('Test 6: exe_path returns valid path');
  LRet := platform_args_exe_path(@LBuf[0], Length(LBuf));
  Check(LRet > 0, 'exe_path returns > 0');
  if LRet > 0 then
    WriteLn('    exe_path: ', LBuf);

  // Test 7: exe_path with nil buffer
  WriteLn('Test 7: exe_path with nil buffer');
  LRet := platform_args_exe_path(nil, 0);
  Check(LRet = PLATFORM_ERR_INVALID, 'exe_path(nil) returns INVALID');

  // Test 8: exe_path with small buffer
  WriteLn('Test 8: exe_path with small buffer');
  LRet := platform_args_exe_path(@LBuf[0], 1);
  // Should return required length or truncate
  WriteLn('    exe_path with small buffer returned: ', LRet);

  WriteLn;
  WriteLn('=== 结果: ', LPassed, ' passed, ', LFailed, ' failed ===');
  if LFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
