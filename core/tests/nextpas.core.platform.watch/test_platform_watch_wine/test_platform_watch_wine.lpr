program test_platform_watch_wine;

{ Windows host / Wine smoke for platform.watch.
  - Under Wine: create/delete/multi may soft-residual.
  - Real Windows (GHA windows-latest): create + delete are hard asserts. }

{$mode objfpc}{$H+}

uses
  nextpas.core.platform.watch,
  nextpas.core.platform.error,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.platform.fs,
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;

var
  LPassed, LFailed: Int32;
  LUnderWine: Boolean;

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

function RunningUnderWine: Boolean;
var
  LNtdll: HMODULE;
  LProc: FARPROC;
begin
  LNtdll := GetModuleHandleW(PWideChar(UnicodeString('ntdll.dll')));
  if (LNtdll = nil) or (LNtdll = HMODULE(PtrInt(-1))) then
    Exit(False);
  LProc := GetProcAddress(LNtdll, 'wine_get_version');
  Result := LProc <> nil;
end;

procedure MaybeSoftEvent(AGot: Boolean; const AName: string; AAllowSoft: Boolean);
begin
  if AGot then
    Check(True, AName)
  else if AAllowSoft then
  begin
    WriteLn('  ~ ', AName, ' residual under Wine (soft)');
    Inc(LPassed);
  end
  else
    Check(False, AName + ' (hard on real Windows)');
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
  LUnderWine := RunningUnderWine;
  WriteLn('=== platform.watch windows smoke ===');
  if LUnderWine then
  begin
    WriteLn('host=wine; truth=wine-runtime-smoke; create/delete may soft');
  end
  else
  begin
    WriteLn('host=real-windows; create+delete hard asserts');
  end;
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
    Check(LRet > 0, 'watch_add valid dir returns positive wd');
    Check(LWatcher.IsValid, 'watcher valid');
  end;

  WriteLn('Test 3: poll timeout → 0');
  if LWatcher.IsValid then
    Check(platform_watch_poll(LWatcher, LEvent, 20) = 0, 'timeout returns 0');

  WriteLn('Test 4: create file → event');
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
    MaybeSoftEvent((LRet > 0) and (LEvent.Created or LEvent.Modified),
      'create event', LUnderWine);
  end;

  WriteLn('Test 5: delete event');
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
    MaybeSoftEvent(LGotDelete, 'delete event', LUnderWine);
  end;

  WriteLn('Test 6: multi create → two polls');
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
    MaybeSoftEvent(LGotMulti, 'multi-event second poll', LUnderWine);
  end;

  WriteLn('Test 7: multi-dir second path + remove + close');
  if LWatcher.IsValid and (LDirPath <> '') then
  begin
    { Second add of same dir uses another slot (wd > 0). }
    LRet := platform_watch_add(LWatcher, @LDir[0]);
    Check(LRet > 0, 'second add returns positive wd');
    if LRet > 0 then
      Check(platform_watch_remove(LWatcher, LRet) = 0, 'remove second wd');
  end;
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
