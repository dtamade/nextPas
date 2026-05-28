program test_platform_files;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.testing;

var
  T: TTestRunner;

const
  TEST_PATH = '/tmp/nextpas_test_platform_file.tmp';
  TEST_DATA = 'Hello, nextPas platform.files!';

procedure TestOpenCreateClose;
var
  H: TPlatformFileHandle;
begin
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open create');
  Check(H.Value >= 0, 'handle valid');
  Check(platform_file_close(H) = 0, 'close');
  Check(H.Value < 0, 'handle invalidated after close');
end;

procedure TestWriteReadBack;
var
  H: TPlatformFileHandle;
  LBuf: array[0..127] of AnsiChar;
  LWritten, LRead: PtrUInt;
  LPos: Int64;
begin
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  Check(platform_file_write(H, @TEST_DATA[1], Length(TEST_DATA), LWritten) = 0, 'write');
  CheckEqual(Int64(Length(TEST_DATA)), Int64(LWritten), 'bytes written');
  Check(platform_file_seek(H, 0, fsoBegin, LPos) = 0, 'seek begin');
  CheckEqual(Int64(0), LPos, 'position after seek');
  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_file_read(H, @LBuf, Length(TEST_DATA), LRead) = 0, 'read');
  CheckEqual(Int64(Length(TEST_DATA)), Int64(LRead), 'bytes read');
  Check(CompareMem(@LBuf, @TEST_DATA[1], Length(TEST_DATA)), 'data matches');
  Check(platform_file_close(H) = 0, 'close');
end;

procedure TestTruncate;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LPos: Int64;
begin
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  Check(platform_file_write(H, @TEST_DATA[1], Length(TEST_DATA), LWritten) = 0, 'write');
  Check(platform_file_truncate(H, 5) = 0, 'truncate to 5');
  Check(platform_file_seek(H, 0, fsoEnd, LPos) = 0, 'seek end');
  CheckEqual(Int64(5), LPos, 'size after truncate');
  Check(platform_file_close(H) = 0, 'close');
end;

procedure TestSync;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
begin
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  Check(platform_file_write(H, @TEST_DATA[1], Length(TEST_DATA), LWritten) = 0, 'write');
  Check(platform_file_sync(H) = 0, 'sync');
  Check(platform_file_close(H) = 0, 'close');
end;

procedure TestOpenNonExistent;
var
  H: TPlatformFileHandle;
begin
  Check(platform_file_open('/tmp/nextpas_nonexistent_xyz_abc', fomReadOnly, fcmOpenExisting, H) <> 0, 'open non-existent returns error');
end;

procedure TestMkdirRmdir;
const
  DIR_PATH = '/tmp/nextpas_test_dir_xyz';
begin
  platform_file_rmdir(DIR_PATH);
  Check(platform_file_mkdir(DIR_PATH, 493) = 0, 'mkdir');
  Check(platform_file_rmdir(DIR_PATH) = 0, 'rmdir');
end;

procedure TestStat;
var
  H: TPlatformFileHandle;
  LStat: TPlatformFileStat;
  LWritten: PtrUInt;
begin
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'create file');
  Check(platform_file_write(H, @TEST_DATA[1], Length(TEST_DATA), LWritten) = 0, 'write');
  Check(platform_file_close(H) = 0, 'close');
  Check(platform_file_stat(TEST_PATH, LStat) = 0, 'stat');
  CheckEqual(Int64(Length(TEST_DATA)), LStat.Size, 'stat size');
  Check(LStat.FileType = ftRegular, 'stat file type = regular');
end;

procedure TestStatDirectory;
var
  LStat: TPlatformFileStat;
begin
  Check(platform_file_stat('/tmp', LStat) = 0, 'stat /tmp');
  Check(LStat.FileType = ftDirectory, 'stat /tmp is directory');
end;

procedure TestRenameUnlink;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
const
  RENAMED_PATH = '/tmp/nextpas_test_renamed.tmp';
begin
  Check(platform_file_open(TEST_PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'create');
  Check(platform_file_write(H, @TEST_DATA[1], 5, LWritten) = 0, 'write');
  Check(platform_file_close(H) = 0, 'close');
  Check(platform_file_rename(TEST_PATH, RENAMED_PATH) = 0, 'rename');
  Check(platform_file_open(TEST_PATH, fomReadOnly, fcmOpenExisting, H) <> 0, 'old path gone');
  Check(platform_file_unlink(RENAMED_PATH) = 0, 'unlink renamed');
end;

procedure TestGetcwdChdir;
var
  LBuf: array[0..4095] of AnsiChar;
  LOrig: array[0..4095] of AnsiChar;
begin
  Check(platform_file_getcwd(@LOrig, SizeOf(LOrig)) <> nil, 'getcwd');
  Check(platform_file_chdir('/tmp') = 0, 'chdir /tmp');
  Check(platform_file_getcwd(@LBuf, SizeOf(LBuf)) <> nil, 'getcwd after chdir');
  Check(platform_file_chdir(@LOrig) = 0, 'restore cwd');
end;

procedure TestDirEnumeration;
const
  DIR_PATH = '/tmp/nextpas_test_dir_enum';
  FILE_A = '/tmp/nextpas_test_dir_enum/aaa.txt';
  FILE_B = '/tmp/nextpas_test_dir_enum/bbb.txt';
  FILE_C = '/tmp/nextpas_test_dir_enum/ccc.txt';
var
  H: TPlatformFileHandle;
  DH: TPlatformDirHandle;
  Entry: TPlatformDirEntry;
  LWritten: PtrUInt;
  LCount: Int32;
  LRc: Int32;
begin
  platform_file_rmdir(DIR_PATH);
  platform_file_unlink(FILE_A);
  platform_file_unlink(FILE_B);
  platform_file_unlink(FILE_C);
  Check(platform_file_mkdir(DIR_PATH, 493) = 0, 'mkdir');
  Check(platform_file_open(FILE_A, fomWriteOnly, fcmCreateAlways, H) = 0, 'create a');
  platform_file_write(H, @TEST_DATA[1], 1, LWritten);
  platform_file_close(H);
  Check(platform_file_open(FILE_B, fomWriteOnly, fcmCreateAlways, H) = 0, 'create b');
  platform_file_write(H, @TEST_DATA[1], 1, LWritten);
  platform_file_close(H);
  Check(platform_file_open(FILE_C, fomWriteOnly, fcmCreateAlways, H) = 0, 'create c');
  platform_file_write(H, @TEST_DATA[1], 1, LWritten);
  platform_file_close(H);

  Check(platform_dir_open(DIR_PATH, DH) = 0, 'dir_open');
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
  platform_file_rmdir(DIR_PATH);
end;

procedure Cleanup;
begin
  DeleteFile(TEST_PATH);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.files');
  T.Run('open/create/close', @TestOpenCreateClose);
  T.Run('write + read back', @TestWriteReadBack);
  T.Run('truncate', @TestTruncate);
  T.Run('sync', @TestSync);
  T.Run('open non-existent', @TestOpenNonExistent);
  T.Run('mkdir/rmdir', @TestMkdirRmdir);
  T.Run('stat file', @TestStat);
  T.Run('stat directory', @TestStatDirectory);
  T.Run('rename/unlink', @TestRenameUnlink);
  T.Run('getcwd/chdir', @TestGetcwdChdir);
  T.Run('dir enumeration', @TestDirEnumeration);
  T.Summary;
end.
