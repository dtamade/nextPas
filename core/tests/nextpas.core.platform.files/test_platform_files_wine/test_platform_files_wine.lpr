program test_platform_files_wine;

{ Real Windows runtime evidence only when compiled and run on a Windows host. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.fs,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files;

var
  T: TTestRunner;
  TmpPrefix: array[0..255] of AnsiChar;
  TestPath: AnsiString;
  TestDir: AnsiString;
  RenamedPath: AnsiString;
  AppendPath: AnsiString;
  DirEnum: AnsiString;
  DirEnumFileA: AnsiString;
  DirEnumFileB: AnsiString;
  DirEnumFileC: AnsiString;
  MissingPath: AnsiString;

const
  TEST_DATA = 'Hello, nextPas platform.files Wine!';

{$IFDEF NEXTPAS_WINDOWS}

function TempPath(const AName: AnsiString): AnsiString;
var
  LPrefix: AnsiString;
  LLast: AnsiChar;
begin
  LPrefix := AnsiString(PAnsiChar(@TmpPrefix[0]));
  Check(Length(LPrefix) > 0, 'temp dir prefix initialized');
  LLast := LPrefix[Length(LPrefix)];
  if (LLast <> '\') and (LLast <> '/') then
    LPrefix := LPrefix + '\';
  Result := LPrefix + AName;
end;

procedure InitTempPaths;
begin
  TestPath := TempPath('nxp_files_nextpas_wine_file.tmp');
  TestDir := TempPath('nxp_files_nextpas_wine_test_dir');
  RenamedPath := TempPath('nxp_files_nextpas_wine_renamed.tmp');
  AppendPath := TempPath('nxp_files_nextpas_wine_append.tmp');
  DirEnum := TempPath('nxp_files_nextpas_wine_dir_enum');
  DirEnumFileA := TempPath('nxp_files_nextpas_wine_dir_enum\a.txt');
  DirEnumFileB := TempPath('nxp_files_nextpas_wine_dir_enum\b.txt');
  DirEnumFileC := TempPath('nxp_files_nextpas_wine_dir_enum\c.txt');
  MissingPath := TempPath('nxp_files_nextpas_wine_nonexistent_xyz');
end;

procedure TestOpenCreateClose;
var
  H: TPlatformFileHandle;
begin
  platform_file_unlink(PAnsiChar(TestPath));
  Check(platform_file_open(PAnsiChar(TestPath), fomReadWrite, fcmCreateAlways, H) = 0, 'open create');
  Check(H.Value <> PLATFORM_FILE_INVALID_HANDLE.Value, 'handle valid');
  Check(platform_file_close(H) = 0, 'close');
  Check(H.Value = PLATFORM_FILE_INVALID_HANDLE.Value, 'handle invalidated after close');
  platform_file_unlink(PAnsiChar(TestPath));
end;

procedure TestWriteReadBack;
var
  H: TPlatformFileHandle;
  LBuf: array[0..127] of AnsiChar;
  LWritten, LRead: PtrUInt;
begin
  platform_file_unlink(PAnsiChar(TestPath));
  Check(platform_file_open(PAnsiChar(TestPath), fomReadWrite, fcmCreateAlways, H) = 0, 'open write');
  Check(platform_file_write(H, @TEST_DATA[1], Length(TEST_DATA), LWritten) = 0, 'write');
  CheckEqual(Int64(Length(TEST_DATA)), Int64(LWritten), 'bytes written');
  platform_file_close(H);
  Check(platform_file_open(PAnsiChar(TestPath), fomReadOnly, fcmOpenExisting, H) = 0, 'open read');
  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_file_read(H, @LBuf, Length(TEST_DATA), LRead) = 0, 'read');
  CheckEqual(Int64(Length(TEST_DATA)), Int64(LRead), 'bytes read');
  Check(CompareMem(@LBuf, @TEST_DATA[1], Length(TEST_DATA)), 'data matches');
  platform_file_close(H);
  platform_file_unlink(PAnsiChar(TestPath));
end;

procedure TestOpenExAppend;
var
  H: TPlatformFileHandle;
  LWritten, LRead: PtrUInt;
  LBuf: array[0..63] of AnsiChar;
  LPos: Int64;
begin
  platform_file_unlink(PAnsiChar(AppendPath));
  { Create file via open_ex with create-always, write first chunk. }
  Check(platform_file_open_ex(PAnsiChar(AppendPath), fomWriteOnly, fcmCreateAlways,
    False, False, 420, H) = 0, 'open_ex create');
  Check(platform_file_write(H, PAnsiChar('AAA'), 3, LWritten) = 0, 'write AAA');
  platform_file_close(H);
  { Reopen existing file via open_ex, seek to EOF manually, then write.
    This exercises open_ex with open-existing mode and tests append-logic
    without relying on Wine's FILE_APPEND_DATA atomic-seek behavior. }
  Check(platform_file_open_ex(PAnsiChar(AppendPath), fomReadWrite, fcmOpenExisting,
    False, False, 420, H) = 0, 'open_ex open existing');
  Check(platform_file_seek(H, 0, fsoEnd, LPos) = 0, 'seek to end');
  CheckEqual(Int64(3), LPos, 'EOF position = 3');
  Check(platform_file_write(H, PAnsiChar('BBB'), 3, LWritten) = 0, 'write BBB at EOF');
  platform_file_close(H);
  { Read back and verify combined content. }
  Check(platform_file_open(PAnsiChar(AppendPath), fomReadOnly, fcmOpenExisting, H) = 0, 'open read');
  FillChar(LBuf, SizeOf(LBuf), 0);
  platform_file_read(H, @LBuf[0], 6, LRead);
  platform_file_close(H);
  Check(LRead = 6, 'read 6 bytes');
  Check(LBuf[0] = 'A', 'first write preserved');
  Check(LBuf[1] = 'A', 'second char');
  Check(LBuf[2] = 'A', 'third char');
  Check(LBuf[3] = 'B', 'append B');
  Check(LBuf[4] = 'B', 'append B');
  Check(LBuf[5] = 'B', 'append B');
  platform_file_unlink(PAnsiChar(AppendPath));
end;

procedure TestSeekPositions;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LPos: Int64;
begin
  platform_file_unlink(PAnsiChar(TestPath));
  Check(platform_file_open(PAnsiChar(TestPath), fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  Check(platform_file_write(H, @TEST_DATA[1], 10, LWritten) = 0, 'write 10 bytes');
  Check(platform_file_seek(H, 0, fsoBegin, LPos) = 0, 'seek begin');
  CheckEqual(Int64(0), LPos, 'pos at begin');
  Check(platform_file_seek(H, 0, fsoEnd, LPos) = 0, 'seek end');
  CheckEqual(Int64(10), LPos, 'pos at end');
  Check(platform_file_seek(H, 5, fsoBegin, LPos) = 0, 'seek begin+5');
  CheckEqual(Int64(5), LPos, 'pos at 5');
  Check(platform_file_seek(H, 0, fsoCurrent, LPos) = 0, 'seek current');
  CheckEqual(Int64(5), LPos, 'pos still at 5');
  platform_file_close(H);
  platform_file_unlink(PAnsiChar(TestPath));
end;

procedure TestTruncate;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LPos: Int64;
begin
  platform_file_unlink(PAnsiChar(TestPath));
  Check(platform_file_open(PAnsiChar(TestPath), fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  Check(platform_file_write(H, @TEST_DATA[1], 10, LWritten) = 0, 'write 10');
  Check(platform_file_truncate(H, 5) = 0, 'truncate to 5');
  Check(platform_file_seek(H, 0, fsoEnd, LPos) = 0, 'seek end');
  CheckEqual(Int64(5), LPos, 'size after truncate = 5');
  platform_file_close(H);
  platform_file_unlink(PAnsiChar(TestPath));
end;

procedure TestStatFile;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LStat: TPlatformFileStat;
begin
  platform_file_unlink(PAnsiChar(TestPath));
  Check(platform_file_open(PAnsiChar(TestPath), fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  Check(platform_file_write(H, @TEST_DATA[1], Length(TEST_DATA), LWritten) = 0, 'write');
  platform_file_close(H);
  Check(platform_file_stat(PAnsiChar(TestPath), LStat) = 0, 'stat');
  CheckEqual(Int64(Length(TEST_DATA)), LStat.Size, 'stat size');
  Check(LStat.FileType = ftRegular, 'stat file type = regular');
  platform_file_unlink(PAnsiChar(TestPath));
end;

procedure TestStatDirectory;
var
  LStat: TPlatformFileStat;
begin
  platform_file_rmdir(PAnsiChar(TestDir));
  Check(platform_file_mkdir(PAnsiChar(TestDir), 493) = 0, 'mkdir for stat');
  Check(platform_file_stat(PAnsiChar(TestDir), LStat) = 0, 'stat directory');
  Check(LStat.FileType = ftDirectory, 'stat directory is ftDirectory');
  Check(platform_file_rmdir(PAnsiChar(TestDir)) = 0, 'rmdir after stat');
end;

procedure TestMkdirRmdir;
begin
  platform_file_rmdir(PAnsiChar(TestDir));
  Check(platform_file_mkdir(PAnsiChar(TestDir), 493) = 0, 'mkdir');
  Check(platform_file_rmdir(PAnsiChar(TestDir)) = 0, 'rmdir');
end;

procedure TestUnlink;
var
  H: TPlatformFileHandle;
begin
  Check(platform_file_open(PAnsiChar(TestPath), fomReadWrite, fcmCreateAlways, H) = 0, 'create');
  platform_file_close(H);
  Check(platform_file_unlink(PAnsiChar(TestPath)) = 0, 'unlink');
  Check(platform_file_open(PAnsiChar(TestPath), fomReadOnly, fcmOpenExisting, H) <> 0, 'file gone after unlink');
end;

procedure TestRename;
var
  H: TPlatformFileHandle;
  LWritten, LRead: PtrUInt;
  LBuf: array[0..63] of AnsiChar;
begin
  platform_file_unlink(PAnsiChar(TestPath));
  platform_file_unlink(PAnsiChar(RenamedPath));
  Check(platform_file_open(PAnsiChar(TestPath), fomReadWrite, fcmCreateAlways, H) = 0, 'create');
  Check(platform_file_write(H, @TEST_DATA[1], 5, LWritten) = 0, 'write 5');
  platform_file_close(H);
  Check(platform_file_rename(PAnsiChar(TestPath), PAnsiChar(RenamedPath)) = 0, 'rename');
  Check(platform_file_open(PAnsiChar(TestPath), fomReadOnly, fcmOpenExisting, H) <> 0, 'old path gone');
  Check(platform_file_open(PAnsiChar(RenamedPath), fomReadOnly, fcmOpenExisting, H) = 0, 'new path exists');
  FillChar(LBuf, SizeOf(LBuf), 0);
  platform_file_read(H, @LBuf[0], 5, LRead);
  Check(LRead = 5, 'read 5 from renamed');
  Check(CompareMem(@LBuf, @TEST_DATA[1], 5), 'renamed data matches');
  platform_file_close(H);
  platform_file_unlink(PAnsiChar(RenamedPath));
end;

procedure TestDirEnumeration;
var
  H: TPlatformFileHandle;
  DH: TPlatformDirHandle;
  Entry: TPlatformDirEntry;
  LWritten: PtrUInt;
  LCount: Int32;
  LRc: Int32;
begin
  platform_file_unlink(PAnsiChar(DirEnumFileA));
  platform_file_unlink(PAnsiChar(DirEnumFileB));
  platform_file_unlink(PAnsiChar(DirEnumFileC));
  platform_file_rmdir(PAnsiChar(DirEnum));
  Check(platform_file_mkdir(PAnsiChar(DirEnum), 493) = 0, 'mkdir');
  Check(platform_file_open(PAnsiChar(DirEnumFileA), fomWriteOnly, fcmCreateAlways, H) = 0, 'create a');
  platform_file_write(H, @TEST_DATA[1], 1, LWritten);
  platform_file_close(H);
  Check(platform_file_open(PAnsiChar(DirEnumFileB), fomWriteOnly, fcmCreateAlways, H) = 0, 'create b');
  platform_file_write(H, @TEST_DATA[1], 1, LWritten);
  platform_file_close(H);
  Check(platform_file_open(PAnsiChar(DirEnumFileC), fomWriteOnly, fcmCreateAlways, H) = 0, 'create c');
  platform_file_write(H, @TEST_DATA[1], 1, LWritten);
  platform_file_close(H);
  Check(platform_dir_open(PAnsiChar(DirEnum), DH) = 0, 'dir_open');
  LCount := 0;
  repeat
    LRc := platform_dir_read(DH, Entry);
    if LRc = 0 then
      Inc(LCount);
  until LRc <> 0;
  Check(LRc = 1, 'dir_read returns 1 at end');
  CheckEqual(Int64(3), Int64(LCount), 'found 3 entries');
  Check(platform_dir_close(DH) = 0, 'dir_close');
  platform_file_unlink(PAnsiChar(DirEnumFileA));
  platform_file_unlink(PAnsiChar(DirEnumFileB));
  platform_file_unlink(PAnsiChar(DirEnumFileC));
  platform_file_rmdir(PAnsiChar(DirEnum));
end;

procedure TestOpenNonExistent;
var
  H: TPlatformFileHandle;
begin
  Check(platform_file_open(PAnsiChar(MissingPath), fomReadOnly, fcmOpenExisting, H) <> 0,
    'open non-existent returns error');
end;

procedure TestFstat;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LStat: TPlatformFileStat;
begin
  platform_file_unlink(PAnsiChar(TestPath));
  Check(platform_file_open(PAnsiChar(TestPath), fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  Check(platform_file_write(H, @TEST_DATA[1], 7, LWritten) = 0, 'write 7');
  Check(platform_file_fstat(H, LStat) = 0, 'fstat');
  CheckEqual(Int64(7), LStat.Size, 'fstat size = 7');
  Check(LStat.FileType = ftRegular, 'fstat type = regular');
  platform_file_close(H);
  platform_file_unlink(PAnsiChar(TestPath));
end;

procedure TestSync;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
begin
  platform_file_unlink(PAnsiChar(TestPath));
  Check(platform_file_open(PAnsiChar(TestPath), fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  Check(platform_file_write(H, @TEST_DATA[1], 3, LWritten) = 0, 'write');
  Check(platform_file_sync(H) = 0, 'sync');
  platform_file_close(H);
  platform_file_unlink(PAnsiChar(TestPath));
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.platform.files.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  Check(platform_fs_temp_dir(@TmpPrefix[0], SizeOf(TmpPrefix)) > 0, 'temp dir init');
  InitTempPaths;
  T.Run('open/create/close', @TestOpenCreateClose);
  T.Run('write + read back', @TestWriteReadBack);
  T.Run('open_ex append', @TestOpenExAppend);
  T.Run('seek positions', @TestSeekPositions);
  T.Run('truncate', @TestTruncate);
  T.Run('stat file', @TestStatFile);
  T.Run('stat directory', @TestStatDirectory);
  T.Run('mkdir/rmdir', @TestMkdirRmdir);
  T.Run('unlink', @TestUnlink);
  T.Run('rename', @TestRename);
  T.Run('dir enumeration', @TestDirEnumeration);
  T.Run('open non-existent', @TestOpenNonExistent);
  T.Run('fstat', @TestFstat);
  T.Run('sync', @TestSync);
  {$ELSE}
  T.Run('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  T.Summary;
end.
