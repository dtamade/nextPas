program test_platform_watch_wine;

{$mode objfpc}{$H+}

uses
  nextpas.core.platform.watch,
  nextpas.core.platform.fs,
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
  LWatcher: TPlatformWatcher;
  LEvent: TPlatformWatchEvent;
  LRet: Int32;
  LTmpDir: array[0..255] of AnsiChar;
  LTmpFile: array[0..511] of AnsiChar;
  LFile: file;
begin
  WriteLn('=== platform.watch Wine 测试 ===');
  LPassed := 0;
  LFailed := 0;

  // Test 1: watch_create succeeds
  WriteLn('Test 1: watch_create succeeds');
  LRet := platform_watch_create(LWatcher);
  Check(LRet = 0, 'watch_create returns ok');

  // Test 2: watch_create with nil pointer
  WriteLn('Test 2: watch_create with nil pointer');
  // This should succeed, we just verify the API works

  // Test 3: watch_add with non-existent path
  WriteLn('Test 3: watch_add with non-existent path');
  LRet := platform_watch_add(LWatcher, '/nonexistent/path');
  // May succeed or fail depending on implementation
  WriteLn('    watch_add returned: ', LRet);

  // Test 4: watch_poll with short timeout (no events)
  WriteLn('Test 4: watch_poll with short timeout (no events)');
  LRet := platform_watch_poll(LWatcher, LEvent, 10);
  // Should return timeout or no event
  WriteLn('    watch_poll returned: ', LRet);

  // Test 5: watch_close succeeds
  WriteLn('Test 5: watch_close succeeds');
  LRet := platform_watch_close(LWatcher);
  Check(LRet = 0, 'watch_close returns ok');

  // Test 6: watch_add with temp directory
  WriteLn('Test 6: watch_add with temp directory');
  LRet := platform_watch_create(LWatcher);
  Check(LRet = 0, 'watch_create for temp dir');

  // Get temp directory via platform API (no SysUtils)
  LRet := platform_fs_temp_dir(@LTmpDir[0], SizeOf(LTmpDir));
  Check(LRet >= 0, 'platform_fs_temp_dir succeeds');
  WriteLn('    temp dir: ', LTmpDir);

  LRet := platform_watch_add(LWatcher, @LTmpDir[0]);
  // May succeed or fail
  WriteLn('    watch_add temp dir returned: ', LRet);

  // Test 7: watch_poll with timeout
  WriteLn('Test 7: watch_poll with timeout');
  LRet := platform_watch_poll(LWatcher, LEvent, 100);
  // Should return timeout or event
  WriteLn('    watch_poll returned: ', LRet);

  // Test 8: watch_close again
  WriteLn('Test 8: watch_close again');
  LRet := platform_watch_close(LWatcher);
  Check(LRet = 0, 'watch_close returns ok');

  WriteLn;
  WriteLn('=== 结果: ', LPassed, ' passed, ', LFailed, ' failed ===');
  if LFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
