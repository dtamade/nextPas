program test_platform_watch_wine;

{$mode objfpc}{$H+}

uses
  nextpas.core.platform.watch,
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
begin
  WriteLn('=== platform.watch wine-runtime-smoke ===');
  WriteLn('truth=wine-runtime-smoke; not real Windows runtime ready');
  WriteLn('Windows L0 watch is intentionally PLATFORM_ERR_UNSUPPORTED');
  WriteLn('(no ReadDirectoryChanges implementation yet).');
  LPassed := 0;
  LFailed := 0;

  WriteLn('Test 1: watch_create → UNSUPPORTED');
  LRet := platform_watch_create(LWatcher);
  Check(LRet = PLATFORM_ERR_UNSUPPORTED,
    'watch_create returns PLATFORM_ERR_UNSUPPORTED');
  Check(LWatcher.IsInvalid, 'watcher invalid after create fail');

  WriteLn('Test 2: watch_add → UNSUPPORTED');
  LRet := platform_watch_add(LWatcher, 'C:\temp');
  Check(LRet = PLATFORM_ERR_UNSUPPORTED,
    'watch_add returns PLATFORM_ERR_UNSUPPORTED');

  WriteLn('Test 3: watch_poll → UNSUPPORTED');
  LRet := platform_watch_poll(LWatcher, LEvent, 10);
  Check(LRet = PLATFORM_ERR_UNSUPPORTED,
    'watch_poll returns PLATFORM_ERR_UNSUPPORTED');

  WriteLn('Test 4: watch_close → UNSUPPORTED');
  LRet := platform_watch_close(LWatcher);
  Check(LRet = PLATFORM_ERR_UNSUPPORTED,
    'watch_close returns PLATFORM_ERR_UNSUPPORTED');

  WriteLn('Test 5: nil path still UNSUPPORTED on Windows stub');
  LRet := platform_watch_add(LWatcher, nil);
  Check(LRet = PLATFORM_ERR_UNSUPPORTED,
    'watch_add nil path returns PLATFORM_ERR_UNSUPPORTED on Win stub');

  WriteLn;
  WriteLn('=== 结果: ', LPassed, ' passed, ', LFailed, ' failed ===');
  if LFailed > 0 then
    Halt(1);
end.
