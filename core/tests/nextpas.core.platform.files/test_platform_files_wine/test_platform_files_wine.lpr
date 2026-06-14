program test_platform_files_wine;

{ Real Windows runtime evidence only when compiled and run on a Windows host. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files;

var
  T: TTestRunner;

const
  TEST_PATH  = '/tmp/nextpas_wine_file.tmp';
  TEST_DATA  = 'Hello, nextPas platform.files Wine!';
  TEST_DIR   = '/tmp/nextpas_wine_test_dir';
  RENAMED    = '/tmp/nextpas_wine_renamed.tmp';

{$IFDEF NEXTPAS_WINDOWS}

procedure TestOpenCreateClose;
var
  H: TPlatformFileHandle;
begin
  platform_file_unlink(TEST_PATH);
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open create');
  Check(H.Value <> PLATFORM_FILE_INVALID_HANDLE.Value, 'handle valid');
  Check(platform_file_close(H) = 0, 'close');
  Check(H.Value = PLATFORM_FILE_INVALID_HANDLE.Value, 'handle invalidated after close');
  platform_file_unlink(TEST_PATH);
end;

procedure TestWriteReadBack;
var
  H: TPlatformFileHandle;
  LBuf: array[0..127] of AnsiChar;
  LWritten, LRead: PtrUInt;
begin
  platform_file_unlink(TEST_PATH);
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open write');
  Check(platform_file_write(H, @TEST_DATA[1], Length(TEST_DATA), LWritten) = 0, 'write');
  CheckEqual(Int64(Length(TEST_DATA)), Int64(LWritten), 'bytes written');
  platform_file_close(H);
  Check(platform_file_open(TEST_PATH, fomReadOnly, fcmOpenExisting, H) = 0, 'open read');
  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_file_read(H, @LBuf, Length(TEST_DATA), LRead) = 0, 'read');
  CheckEqual(Int64(Length(TEST_DATA)), Int64(LRead), 'bytes read');
  Check(CompareMem(@LBuf, @TEST_DATA[1], Length(TEST_DATA)), 'data matches');
  platform_file_close(H);
  platform_file_unlink(TEST_PATH);
end;

procedure TestOpenExAppend;
var
  H: TPlatformFileHandle;
  LWritten, LRead: PtrUInt;
  LBuf: array[0..63] of AnsiChar;
  LPos: Int64;
const
  PATH = '/tmp/nextpas_wine_append.tmp';
begin
  platform_file_unlink(PATH);
  { Create file via open_ex with create-always, write first chunk. }
  Check(platform_file_open_ex(PATH, fomWriteOnly, fcmCreateAlways, False, False, 420, H) = 0, 'open_ex create');
  Check(platform_file_write(H, PAnsiChar('AAA'), 3, LWritten) = 0, 'write AAA');
  platform_file_close(H);
  { Reopen existing file via open_ex, seek to EOF manually, then write.
    This exercises open_ex with open-existing mode and tests append-logic
    without relying on Wine's FILE_APPEND_DATA atomic-seek behavior. }
  Check(platform_file_open_ex(PATH, fomReadWrite, fcmOpenExisting, False, False, 420, H) = 0, 'open_ex open existing');
  Check(platform_file_seek(H, 0, fsoEnd, LPos) = 0, 'seek to end');
  CheckEqual(Int64(3), LPos, 'EOF position = 3');
  Check(platform_file_write(H, PAnsiChar('BBB'), 3, LWritten) = 0, 'write BBB at EOF');
  platform_file_close(H);
  { Read back and verify combined content. }
  Check(platform_file_open(PATH, fomReadOnly, fcmOpenExisting, H) = 0, 'open read');
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
  platform_file_unlink(PATH);
end;

procedure TestSeekPositions;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LPos: Int64;
begin
  platform_file_unlink(TEST_PATH);
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open');
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
  platform_file_unlink(TEST_PATH);
end;

procedure TestTruncate;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LPos: Int64;
begin
  platform_file_unlink(TEST_PATH);
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  Check(platform_file_write(H, @TEST_DATA[1], 10, LWritten) = 0, 'write 10');
  Check(platform_file_truncate(H, 5) = 0, 'truncate to 5');
  Check(platform_file_seek(H, 0, fsoEnd, LPos) = 0, 'seek end');
  CheckEqual(Int64(5), LPos, 'size after truncate = 5');
  platform_file_close(H);
  platform_file_unlink(TEST_PATH);
end;

procedure TestStatFile;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LStat: TPlatformFileStat;
begin
  platform_file_unlink(TEST_PATH);
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  Check(platform_file_write(H, @TEST_DATA[1], Length(TEST_DATA), LWritten) = 0, 'write');
  platform_file_close(H);
  Check(platform_file_stat(TEST_PATH, LStat) = 0, 'stat');
  CheckEqual(Int64(Length(TEST_DATA)), LStat.Size, 'stat size');
  Check(LStat.FileType = ftRegular, 'stat file type = regular');
  platform_file_unlink(TEST_PATH);
end;

procedure TestStatDirectory;
var
  LStat: TPlatformFileStat;
begin
  { Under Wine /tmp may be a symlink, so create our own directory to test. }
  platform_file_rmdir(TEST_DIR);
  Check(platform_file_mkdir(TEST_DIR, 493) = 0, 'mkdir for stat');
  Check(platform_file_stat(TEST_DIR, LStat) = 0, 'stat directory');
  Check(LStat.FileType = ftDirectory, 'stat directory is ftDirectory');
  Check(platform_file_rmdir(TEST_DIR) = 0, 'rmdir after stat');
end;

procedure TestMkdirRmdir;
begin
  platform_file_rmdir(TEST_DIR);
  Check(platform_file_mkdir(TEST_DIR, 493) = 0, 'mkdir');
  Check(platform_file_rmdir(TEST_DIR) = 0, 'rmdir');
end;

procedure TestUnlink;
var
  H: TPlatformFileHandle;
begin
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'create');
  platform_file_close(H);
  Check(platform_file_unlink(TEST_PATH) = 0, 'unlink');
  Check(platform_file_open(TEST_PATH, fomReadOnly, fcmOpenExisting, H) <> 0, 'file gone after unlink');
end;

procedure TestRename;
var
  H: TPlatformFileHandle;
  LWritten, LRead: PtrUInt;
  LBuf: array[0..63] of AnsiChar;
begin
  platform_file_unlink(TEST_PATH);
  platform_file_unlink(RENAMED);
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'create');
  Check(platform_file_write(H, @TEST_DATA[1], 5, LWritten) = 0, 'write 5');
  platform_file_close(H);
  Check(platform_file_rename(TEST_PATH, RENAMED) = 0, 'rename');
  Check(platform_file_open(TEST_PATH, fomReadOnly, fcmOpenExisting, H) <> 0, 'old path gone');
  Check(platform_file_open(RENAMED, fomReadOnly, fcmOpenExisting, H) = 0, 'new path exists');
  FillChar(LBuf, SizeOf(LBuf), 0);
  platform_file_read(H, @LBuf[0], 5, LRead);
  Check(LRead = 5, 'read 5 from renamed');
  Check(CompareMem(@LBuf, @TEST_DATA[1], 5), 'renamed data matches');
  platform_file_close(H);
  platform_file_unlink(RENAMED);
end;

procedure TestDirEnumeration;
const
  DIR_ENUM = '/tmp/nextpas_wine_dir_enum';
  FILE_A   = '/tmp/nextpas_wine_dir_enum/a.txt';
  FILE_B   = '/tmp/nextpas_wine_dir_enum/b.txt';
  FILE_C   = '/tmp/nextpas_wine_dir_enum/c.txt';
var
  H: TPlatformFileHandle;
  DH: TPlatformDirHandle;
  Entry: TPlatformDirEntry;
  LWritten: PtrUInt;
  LCount: Int32;
  LRc: Int32;
begin
  platform_file_unlink(FILE_A);
  platform_file_unlink(FILE_B);
  platform_file_unlink(FILE_C);
  platform_file_rmdir(DIR_ENUM);
  Check(platform_file_mkdir(DIR_ENUM, 493) = 0, 'mkdir');
  Check(platform_file_open(FILE_A, fomWriteOnly, fcmCreateAlways, H) = 0, 'create a');
  platform_file_write(H, @TEST_DATA[1], 1, LWritten);
  platform_file_close(H);
  Check(platform_file_open(FILE_B, fomWriteOnly, fcmCreateAlways, H) = 0, 'create b');
  platform_file_write(H, @TEST_DATA[1], 1, LWritten);
  platform_file_close(H);
  Check(platform_file_open(FILE_C, fomWriteOnly, fcmCreateAlways, H) = 0, 'create c');
  platform_file_write(H, @TEST_DATA[1], 1, LWritten);
  platform_file_close(H);
  Check(platform_dir_open(DIR_ENUM, DH) = 0, 'dir_open');
  LCount := 0;
  repeat
    LRc := platform_dir_read(DH, Entry);
    if LRc = 0 then
      Inc(LCount);
  until LRc <> 0;
  Check(LRc = 1, 'dir_read returns 1 at end');
  CheckEqual(Int64(3), Int64(LCount), 'found 3 entries');
  Check(platform_dir_close(DH) = 0, 'dir_close');
  platform_file_unlink(FILE_A);
  platform_file_unlink(FILE_B);
  platform_file_unlink(FILE_C);
  platform_file_rmdir(DIR_ENUM);
end;

procedure TestOpenNonExistent;
var
  H: TPlatformFileHandle;
begin
  Check(platform_file_open('/tmp/nextpas_wine_nonexistent_xyz', fomReadOnly, fcmOpenExisting, H) <> 0, 'open non-existent returns error');
end;

procedure TestFstat;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LStat: TPlatformFileStat;
begin
  platform_file_unlink(TEST_PATH);
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  Check(platform_file_write(H, @TEST_DATA[1], 7, LWritten) = 0, 'write 7');
  Check(platform_file_fstat(H, LStat) = 0, 'fstat');
  CheckEqual(Int64(7), LStat.Size, 'fstat size = 7');
  Check(LStat.FileType = ftRegular, 'fstat type = regular');
  platform_file_close(H);
  platform_file_unlink(TEST_PATH);
end;

procedure TestSync;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
begin
  platform_file_unlink(TEST_PATH);
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  Check(platform_file_write(H, @TEST_DATA[1], 3, LWritten) = 0, 'write');
  Check(platform_file_sync(H) = 0, 'sync');
  platform_file_close(H);
  platform_file_unlink(TEST_PATH);
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