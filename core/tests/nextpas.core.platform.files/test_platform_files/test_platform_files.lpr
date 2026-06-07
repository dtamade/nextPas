program test_platform_files;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.platform.posix.ffi,
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

procedure TestSymlink;
var
  H: TPlatformFileHandle;
  LStat: TPlatformFileStat;
  LWritten: PtrUInt;
begin
  platform_file_open('/tmp/nextpas_test_symlink_target.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('sym'), 3, LWritten);
  platform_file_close(H);
  // Create symlink via posix.ffi
  nextpas.core.platform.posix.ffi.symlink('/tmp/nextpas_test_symlink_target.txt',
    '/tmp/nextpas_test_symlink_link.txt');
  Check(platform_file_stat('/tmp/nextpas_test_symlink_link.txt', LStat) = 0, 'stat symlink');
  Check(LStat.Size = 3, 'size through symlink = 3');
  platform_file_unlink('/tmp/nextpas_test_symlink_link.txt');
  platform_file_unlink('/tmp/nextpas_test_symlink_target.txt');
end;

procedure TestPermissionError;
var
  H: TPlatformFileHandle;
  R: Int32;
begin
  R := platform_file_open('/root/.bashrc_nonexistent_xyz', fomReadOnly, fcmOpenExisting, H);
  Check(R <> 0, 'open in /root fails');
end;

procedure TestCreateExclusive;
var
  H1, H2: TPlatformFileHandle;
  LWritten: PtrUInt;
  R: Int32;
begin
  platform_file_open('/tmp/nextpas_test_excl.txt', fomWriteOnly, fcmCreateAlways, H1);
  platform_file_write(H1, PAnsiChar('x'), 1, LWritten);
  platform_file_close(H1);
  R := platform_file_open('/tmp/nextpas_test_excl.txt', fomWriteOnly, fcmCreateNew, H2);
  Check(R <> 0, 'create exclusive on existing file fails');
  platform_file_unlink('/tmp/nextpas_test_excl.txt');
end;

procedure TestLockExclusive;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
begin
  Check(platform_file_open('/tmp/nextpas_lock_test.tmp', fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  platform_file_write(H, PAnsiChar('data'), 4, LWritten);
  Check(platform_file_lock(H, True) = 0, 'lock exclusive');
  Check(platform_file_unlock(H) = 0, 'unlock');
  Check(platform_file_lock(H, False) = 0, 'lock shared');
  Check(platform_file_unlock(H) = 0, 'unlock shared');
  platform_file_close(H);
  platform_file_unlink('/tmp/nextpas_lock_test.tmp');
end;

procedure TestTrylockConflict;
var
  H1, H2: TPlatformFileHandle;
  LWritten: PtrUInt;
  R: Int32;
begin
  Check(platform_file_open('/tmp/nextpas_trylock.tmp', fomReadWrite, fcmCreateAlways, H1) = 0, 'open 1');
  platform_file_write(H1, PAnsiChar('x'), 1, LWritten);
  Check(platform_file_lock(H1, True) = 0, 'lock exclusive');
  Check(platform_file_open('/tmp/nextpas_trylock.tmp', fomReadOnly, fcmOpenExisting, H2) = 0, 'open 2');
  R := platform_file_trylock(H2, True);
  Check(R <> 0, 'trylock on locked file fails');
  platform_file_unlock(H1);
  Check(platform_file_trylock(H2, True) = 0, 'trylock after unlock succeeds');
  platform_file_unlock(H2);
  platform_file_close(H2);
  platform_file_close(H1);
  platform_file_unlink('/tmp/nextpas_trylock.tmp');
end;

procedure TestSymlinkReadlink;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LBuf: array[0..1023] of AnsiChar;
  LLen: Int32;
const
  TARGET = '/tmp/nextpas_readlink_target.txt';
  LINK = '/tmp/nextpas_readlink_link.txt';
begin
  platform_file_unlink(LINK);
  platform_file_unlink(TARGET);
  platform_file_open(TARGET, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('abc'), 3, LWritten);
  platform_file_close(H);
  Check(platform_file_symlink(TARGET, LINK) = 0, 'symlink create');
  Check(platform_file_readlink(LINK, @LBuf[0], SizeOf(LBuf), LLen) = 0, 'readlink');
  Check(LLen = Length(TARGET), 'readlink len');
  LBuf[LLen] := #0;
  Check(LBuf[0] = '/', 'readlink starts with /');
  Check(CompareMem(@LBuf[0], @TARGET[1], LLen), 'readlink content matches target');
  platform_file_unlink(LINK);
  platform_file_unlink(TARGET);
end;

procedure TestSymlinkReadlinkSmallBufferReturnsRequiredLength;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LBuf: array[0..3] of AnsiChar;
  LLen: Int32;
const
  TARGET = '/tmp/nextpas_readlink_small_target.txt';
  LINK = '/tmp/nextpas_readlink_small_link.txt';
begin
  platform_file_unlink(LINK);
  platform_file_unlink(TARGET);
  platform_file_open(TARGET, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('abc'), 3, LWritten);
  platform_file_close(H);
  Check(platform_file_symlink(TARGET, LINK) = 0, 'small readlink symlink create');
  FillChar(LBuf, SizeOf(LBuf), Ord('?'));
  Check(platform_file_readlink(LINK, @LBuf[0], SizeOf(LBuf), LLen) = 0,
    'small readlink succeeds');
  Check(LLen = Length(TARGET), 'small readlink returns required target length');
  Check(LBuf[0] = '/', 'small readlink preserves first byte');
  Check(LBuf[SizeOf(LBuf) - 1] = #0, 'small readlink is NUL terminated');
  platform_file_unlink(LINK);
  platform_file_unlink(TARGET);
end;

procedure TestOpenEx;
var
  H: TPlatformFileHandle;
  LWritten, LRead: PtrUInt;
  LBuf: array[0..31] of AnsiChar;
  LPos: Int64;
const
  PATH = '/tmp/nextpas_test_open_ex.txt';
begin
  platform_file_unlink(PATH);
  Check(platform_file_open_ex(PATH, fomWriteOnly, fcmCreateAlways, True, False, 420, H) = 0, 'open_ex append');
  platform_file_write(H, PAnsiChar('AAA'), 3, LWritten);
  platform_file_close(H);
  Check(platform_file_open_ex(PATH, fomWriteOnly, fcmOpenExisting, True, False, 420, H) = 0, 'open_ex append 2');
  platform_file_write(H, PAnsiChar('BBB'), 3, LWritten);
  platform_file_close(H);
  Check(platform_file_open(PATH, fomReadOnly, fcmOpenExisting, H) = 0, 'open read');
  FillChar(LBuf, SizeOf(LBuf), 0);
  platform_file_read(H, @LBuf[0], 6, LRead);
  platform_file_close(H);
  Check(LRead = 6, 'read 6 bytes');
  Check(LBuf[0] = 'A', 'first write preserved');
  Check(LBuf[3] = 'B', 'append worked');
  platform_file_unlink(PATH);
end;

procedure TestPreadPwrite;
var
  H: TPlatformFileHandle;
  LWritten, LRead: PtrUInt;
  LBuf: array[0..31] of AnsiChar;
  LPos: Int64;
const
  PATH = '/tmp/nextpas_test_pread.txt';
begin
  platform_file_unlink(PATH);
  Check(platform_file_open(PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  platform_file_write(H, PAnsiChar('ABCDEFGH'), 8, LWritten);
  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_file_pread(H, @LBuf[0], 3, 2, LRead) = 0, 'pread');
  Check(LRead = 3, 'pread 3 bytes');
  Check(LBuf[0] = 'C', 'pread offset correct');
  Check(LBuf[2] = 'E', 'pread end correct');
  Check(platform_file_pwrite(H, PAnsiChar('XY'), 2, 4, LWritten) = 0, 'pwrite');
  Check(LWritten = 2, 'pwrite 2 bytes');
  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_file_pread(H, @LBuf[0], 8, 0, LRead) = 0, 'pread full');
  Check(LBuf[4] = 'X', 'pwrite at offset 4');
  Check(LBuf[5] = 'Y', 'pwrite at offset 5');
  Check(LBuf[0] = 'A', 'original data preserved');
  platform_file_seek(H, 0, fsoCurrent, LPos);
  Check(LPos = 8, 'file position unchanged by pread/pwrite');
  platform_file_close(H);
  platform_file_unlink(PATH);
end;

procedure TestFstat;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LStat: TPlatformFileStat;
const
  PATH = '/tmp/nextpas_test_fstat.txt';
begin
  platform_file_unlink(PATH);
  Check(platform_file_open(PATH, fomReadWrite, fcmCreateAlways, H) = 0, 'open');
  platform_file_write(H, PAnsiChar('hello'), 5, LWritten);
  Check(platform_file_fstat(H, LStat) = 0, 'fstat');
  Check(LStat.Size = 5, 'fstat size = 5');
  Check(LStat.FileType = ftRegular, 'fstat type = regular');
  platform_file_close(H);
  platform_file_unlink(PATH);
end;

procedure TestChmod;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LStat: TPlatformFileStat;
const
  PATH = '/tmp/nextpas_test_chmod.txt';
begin
  platform_file_unlink(PATH);
  Check(platform_file_open(PATH, fomWriteOnly, fcmCreateAlways, H) = 0, 'open');
  platform_file_write(H, PAnsiChar('x'), 1, LWritten);
  platform_file_close(H);
  Check(platform_file_chmod(PATH, 292) = 0, 'chmod 0444');
  Check(platform_file_stat(PATH, LStat) = 0, 'stat after chmod');
  Check((LStat.Mode and 511) = 292, 'mode = 0444');
  Check(platform_file_chmod(PATH, 420) = 0, 'chmod 0644 restore');
  platform_file_unlink(PATH);
end;

procedure TestTruncatePath;
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LStat: TPlatformFileStat;
const
  PATH = '/tmp/nextpas_test_truncpath.txt';
begin
  platform_file_unlink(PATH);
  Check(platform_file_open(PATH, fomWriteOnly, fcmCreateAlways, H) = 0, 'open');
  platform_file_write(H, PAnsiChar('0123456789'), 10, LWritten);
  platform_file_close(H);
  Check(platform_file_truncate_path(PATH, 4) = 0, 'truncate_path to 4');
  Check(platform_file_stat(PATH, LStat) = 0, 'stat');
  Check(LStat.Size = 4, 'size = 4 after truncate_path');
  platform_file_unlink(PATH);
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
  T.Run('symlink stat', @TestSymlink);
  T.Run('permission error', @TestPermissionError);
  T.Run('create exclusive', @TestCreateExclusive);
  T.Run('file lock exclusive', @TestLockExclusive);
  T.Run('file trylock conflict', @TestTrylockConflict);
  T.Run('symlink/readlink', @TestSymlinkReadlink);
  T.Run('symlink/readlink small buffer',
    @TestSymlinkReadlinkSmallBufferReturnsRequiredLength);
  T.Run('open_ex append', @TestOpenEx);
  T.Run('pread/pwrite', @TestPreadPwrite);
  T.Run('fstat', @TestFstat);
  T.Run('chmod', @TestChmod);
  T.Run('truncate_path', @TestTruncatePath);
  T.Summary;
end.
  T.Summary;
end.
