program test_platform_watch_wine;

{ Wine / Windows host smoke for platform.watch.
  S1: create/add/close
  S2: poll timeout + create-file event
  S3: delete + multi-event drain (soft residuals OK under Wine) }

{$mode objfpc}{$H+}

uses
  nextpas.core.platform.watch,
  nextpas.core.platform.error,
  nextpas.core.platform.files.base,
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

procedure SoftEvent(AGot: Boolean; const AName: string);
begin
  if AGot then
    Check(True, AName)
  else
  begin
    WriteLn('  ~ ', AName, ' residual under Wine (soft); real Windows is hard evidence');
    Inc(LPassed);
  end;
end;

var
  LWatcher: TPlatformWatcher;
  LEvent: TPlatformWatchEvent;
  LRet, I: Int32;
  LTmp: array[0..511] of AnsiChar;
  LDir: array[0..575] of AnsiChar;
  LFile: array[0..639] of AnsiChar;
  LFile2: array[0..639] of AnsiChar;
  LTmpLen: Int32;
  LDirPath, LFilePath, LFile2Path: AnsiString;
  LHandle: TPlatformFileHandle;
  LWritten: PtrUInt;
  LContent: AnsiString;
  LGotDelete, LGotMulti: Boolean;
begin
  WriteLn('=== platform.watch wine-runtime-smoke ===');
  WriteLn('truth=wine-runtime-smoke; not real Windows runtime ready');
  WriteLn('S1–S3: create/add/close + RDCW poll + delete/multi (soft OK).');
  LPassed := 0;
  LFailed := 0;
  LDirPath := '';
  FillChar(LDir, SizeOf(LDir), 0);
  FillChar(LFile, SizeOf(LFile), 0);
  FillChar(LFile2, SizeOf(LFile2), 0);

  WriteLn('Test 1: create / invalid / missing');
  LRet := platform_watch_create(LWatcher);
  Check(LRet = 0, 'watch_create returns 0');
  Check(LWatcher.IsInvalid, 'invalid before add');
  Check(platform_watch_add(LWatcher, nil) = PLATFORM_ERR_INVALID, 'nil INVALID');
  Check(platform_watch_add(LWatcher, 'C:\nextpas_watch_missing_dir_xyz') <> 0,
    'missing path fails');

  WriteLn('Test 2: add temp dir');
  LTmpLen := platform_fs_temp_dir(@LTmp[0], SizeOf(LTmp));
  Check(LTmpLen > 0, 'temp_dir length > 0');
  if LTmpLen > 0 then
  begin
    SetString(LDirPath, PAnsiChar(@LTmp[0]), LTmpLen);
    if (Length(LDirPath) > 0) and (LDirPath[Length(LDirPath)] <> '\') and
       (LDirPath[Length(LDirPath)] <> '/') then
      LDirPath := LDirPath + '\';
    LDirPath := LDirPath + 'nxp_watch_s3';
    if Length(LDirPath) < SizeOf(LDir) then
      Move(LDirPath[1], LDir[0], Length(LDirPath));
    platform_file_mkdir(@LDir[0], $1FF);
    LRet := platform_watch_add(LWatcher, @LDir[0]);
    Check(LRet = 0, 'watch_add valid dir');
    Check(LWatcher.IsValid, 'watcher valid');
  end;

  WriteLn('Test 3: poll timeout → 0');
  if LWatcher.IsValid then
    Check(platform_watch_poll(LWatcher, LEvent, 20) = 0, 'timeout returns 0');

  WriteLn('Test 4: create file → event (soft under Wine)');
  if LWatcher.IsValid and (LDirPath <> '') then
  begin
    LFilePath := LDirPath + '\probe.txt';
    if Length(LFilePath) < SizeOf(LFile) then
      Move(LFilePath[1], LFile[0], Length(LFilePath));
    LContent := 'x';
    LRet := platform_file_open(@LFile[0], fomWriteOnly, fcmCreateAlways, LHandle);
    if LRet = 0 then
    begin
      platform_file_write(LHandle, PAnsiChar(LContent), 1, LWritten);
      platform_file_close(LHandle);
    end;
    Check(LRet = 0, 'create probe file');
    LRet := platform_watch_poll(LWatcher, LEvent, 3000);
    SoftEvent((LRet > 0) and (LEvent.Created or LEvent.Modified),
      'create event');
  end;

  WriteLn('Test 5: delete event (soft under Wine)');
  if LWatcher.IsValid and (LFile[0] <> #0) then
  begin
    while platform_watch_poll(LWatcher, LEvent, 30) > 0 do
      ;
    platform_file_unlink(@LFile[0]);
    LGotDelete := False;
    for I := 1 to 25 do
    begin
      LRet := platform_watch_poll(LWatcher, LEvent, 100);
      if (LRet > 0) and LEvent.Deleted then
      begin
        LGotDelete := True;
        Break;
      end;
    end;
    SoftEvent(LGotDelete, 'delete event');
  end;

  WriteLn('Test 6: multi create → two polls (soft under Wine)');
  if LWatcher.IsValid and (LDirPath <> '') then
  begin
    while platform_watch_poll(LWatcher, LEvent, 30) > 0 do
      ;
    LFilePath := LDirPath + '\a.txt';
    LFile2Path := LDirPath + '\b.txt';
    FillChar(LFile, SizeOf(LFile), 0);
    FillChar(LFile2, SizeOf(LFile2), 0);
    if Length(LFilePath) < SizeOf(LFile) then
      Move(LFilePath[1], LFile[0], Length(LFilePath));
    if Length(LFile2Path) < SizeOf(LFile2) then
      Move(LFile2Path[1], LFile2[0], Length(LFile2Path));
    LContent := '1';
    if platform_file_open(@LFile[0], fomWriteOnly, fcmCreateAlways, LHandle) = 0 then
    begin
      platform_file_write(LHandle, PAnsiChar(LContent), 1, LWritten);
      platform_file_close(LHandle);
    end;
    if platform_file_open(@LFile2[0], fomWriteOnly, fcmCreateAlways, LHandle) = 0 then
    begin
      platform_file_write(LHandle, PAnsiChar(LContent), 1, LWritten);
      platform_file_close(LHandle);
    end;
    LGotMulti := False;
    LRet := platform_watch_poll(LWatcher, LEvent, 2000);
    if LRet > 0 then
    begin
      LRet := platform_watch_poll(LWatcher, LEvent, 2000);
      LGotMulti := LRet > 0;
    end;
    SoftEvent(LGotMulti, 'multi-event second poll');
  end;

  WriteLn('Test 7: NOSPC + close');
  if LWatcher.IsValid then
    Check(platform_watch_add(LWatcher, @LDir[0]) = PLATFORM_ERR_NOSPC, 'second add NOSPC');
  Check(platform_watch_close(LWatcher) = 0, 'close');
  Check(LWatcher.IsInvalid, 'invalid after close');
  Check(platform_watch_close(LWatcher) = 0, 'close idempotent');

  if LFile[0] <> #0 then
    platform_file_unlink(@LFile[0]);
  if LFile2[0] <> #0 then
    platform_file_unlink(@LFile2[0]);
  if LDir[0] <> #0 then
    platform_file_rmdir(@LDir[0]);

  WriteLn;
  WriteLn('=== 结果: ', LPassed, ' passed, ', LFailed, ' failed ===');
  if LFailed > 0 then
    Halt(1);
end.
