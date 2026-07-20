program test_platform_watch_wine;

{ Wine / Windows host smoke for platform.watch.
  Batch-15 S1: create / add / close on real directory handles.
  Poll remains PLATFORM_ERR_UNSUPPORTED until S2 (ReadDirectoryChangesW). }

{$mode objfpc}{$H+}

uses
  nextpas.core.platform.watch,
  nextpas.core.platform.error,
  nextpas.core.platform.files,
  nextpas.core.platform.fs;

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
  LTmp: array[0..511] of AnsiChar;
  LDir: array[0..575] of AnsiChar;
  LTmpLen: Int32;
  LDirPath: AnsiString;
begin
  WriteLn('=== platform.watch wine-runtime-smoke ===');
  WriteLn('truth=wine-runtime-smoke; not real Windows runtime ready');
  WriteLn('S1: create/add/close; poll still UNSUPPORTED (S2 later).');
  LPassed := 0;
  LFailed := 0;

  WriteLn('Test 1: watch_create succeeds (no OS resource yet)');
  LRet := platform_watch_create(LWatcher);
  Check(LRet = 0, 'watch_create returns 0');
  Check(LWatcher.IsInvalid, 'watcher invalid before add');

  WriteLn('Test 2: watch_add nil path → INVALID');
  LRet := platform_watch_add(LWatcher, nil);
  Check(LRet = PLATFORM_ERR_INVALID, 'watch_add nil → PLATFORM_ERR_INVALID');

  WriteLn('Test 3: watch_add missing path → error');
  LRet := platform_watch_add(LWatcher, 'C:\nextpas_watch_missing_dir_xyz');
  Check(LRet <> 0, 'watch_add missing path fails');
  Check(LWatcher.IsInvalid, 'still invalid after failed add');

  WriteLn('Test 4: watch_add valid temp dir');
  LTmpLen := platform_fs_temp_dir(@LTmp[0], SizeOf(LTmp));
  Check(LTmpLen > 0, 'temp_dir length > 0');
  if LTmpLen > 0 then
  begin
    LDirPath := Copy(LTmp, 1, LTmpLen);
    if (Length(LDirPath) > 0) and (LDirPath[Length(LDirPath)] <> '\') and
       (LDirPath[Length(LDirPath)] <> '/') then
      LDirPath := LDirPath + '\';
    LDirPath := LDirPath + 'nxp_watch_s1';
    FillChar(LDir, SizeOf(LDir), 0);
    if Length(LDirPath) < SizeOf(LDir) then
      Move(LDirPath[1], LDir[0], Length(LDirPath));
    { mkdir may already exist from prior run }
    platform_file_mkdir(@LDir[0], $1FF);
    LRet := platform_watch_add(LWatcher, @LDir[0]);
    Check(LRet = 0, 'watch_add valid dir returns 0');
    Check(LWatcher.IsValid, 'watcher valid after add');
  end;

  WriteLn('Test 5: second watch_add → NOSPC (v1 single-dir)');
  if LWatcher.IsValid then
  begin
    LRet := platform_watch_add(LWatcher, @LDir[0]);
    Check(LRet = PLATFORM_ERR_NOSPC, 'second add returns PLATFORM_ERR_NOSPC');
  end;

  WriteLn('Test 6: watch_poll still UNSUPPORTED (S2)');
  LRet := platform_watch_poll(LWatcher, LEvent, 10);
  Check(LRet = PLATFORM_ERR_UNSUPPORTED,
    'watch_poll returns PLATFORM_ERR_UNSUPPORTED');

  WriteLn('Test 7: watch_close succeeds and is idempotent');
  LRet := platform_watch_close(LWatcher);
  Check(LRet = 0, 'watch_close returns 0');
  Check(LWatcher.IsInvalid, 'watcher invalid after close');
  LRet := platform_watch_close(LWatcher);
  Check(LRet = 0, 'watch_close idempotent');

  { best-effort cleanup }
  if LDir[0] <> #0 then
    platform_file_rmdir(@LDir[0]);

  WriteLn;
  WriteLn('=== 结果: ', LPassed, ' passed, ', LFailed, ' failed ===');
  if LFailed > 0 then
    Halt(1);
end.
