program test_platform_fs;

{$I nextpas.core.settings.inc}

uses

  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.text.conv,
  nextpas.core.platform.fs,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.platform.error,
  nextpas.core.test;

var
  T: TTestSuite;

procedure AssignPlatformHandle(var AHandle: TPlatformFileHandle; const AFd: Int32);
begin
{$IFDEF NEXTPAS_WINDOWS}
  AHandle.Value := Pointer(PtrUInt(AFd));
{$ELSE}
  AHandle.Value := AFd;
{$ENDIF}
end;

function LoadSourceText(const ARelativePath: string): string;
begin
  Check(FileExists(ARelativePath), 'source file exists: ' + ARelativePath);
  Result := FsReadFileText(ARelativePath);
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) = 0, AMessage + ': ' + AToken);
end;

function SourceSlice(const ASource, AStartToken, AEndToken: string): string;
var
  LStart, LEnd: SizeInt;
begin
  LStart := Pos(AStartToken, ASource);
  Check(LStart > 0, 'source slice start exists: ' + AStartToken);
  LEnd := Pos(AEndToken, Copy(ASource, LStart + Length(AStartToken),
    Length(ASource)));
  Check(LEnd > 0, 'source slice end exists: ' + AEndToken);
  Result := Copy(ASource, LStart, Length(AStartToken) + LEnd - 1);
end;

procedure TestExistsFile;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
begin
  platform_file_open('/tmp/nextpas_fs_test.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('hi'), 2, W);
  platform_file_close(H);
  Check(platform_fs_exists('/tmp/nextpas_fs_test.txt'), 'file exists');
  platform_file_unlink('/tmp/nextpas_fs_test.txt');
end;

procedure TestExistsNot;
begin
  Check(not platform_fs_exists('/tmp/nextpas_nonexistent_xyz_999'), 'non-existent');
end;

procedure TestIsFile;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
begin
  platform_file_open('/tmp/nextpas_fs_isfile.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('x'), 1, W);
  platform_file_close(H);
  Check(platform_fs_is_file('/tmp/nextpas_fs_isfile.txt'), 'is file');
  Check(not platform_fs_is_dir('/tmp/nextpas_fs_isfile.txt'), 'not dir');
  platform_file_unlink('/tmp/nextpas_fs_isfile.txt');
end;

procedure TestIsDir;
begin
  Check(platform_fs_is_dir('/tmp'), '/tmp is dir');
  Check(not platform_fs_is_file('/tmp'), '/tmp not file');
end;

procedure TestFileSize;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
  Size: Int64;
begin
  platform_file_open('/tmp/nextpas_fs_size.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('hello'), 5, W);
  platform_file_close(H);
  Check(platform_fs_file_size('/tmp/nextpas_fs_size.txt', Size) = 0, 'stat ok');
  Check(Size = 5, 'size = 5');
  platform_file_unlink('/tmp/nextpas_fs_size.txt');
end;

procedure TestTempDir;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_fs_temp_dir(@Buf[0], 256);
  Check(R > 0, 'temp_dir returns length > 0');
  Check(Buf[0] = '/', 'starts with /');
  Check(platform_fs_is_dir(@Buf[0]), 'temp dir exists');
end;

procedure TestMktemp;
var
  Path: array[0..511] of AnsiChar;
  Fd: Int32;
  R: Int32;
  H: TPlatformFileHandle;
begin
  Fd := -1;
  R := platform_fs_mktemp('nxp_', '.s', @Path[0], 512, Fd);
  Check(R = 0, 'mktemp succeeds');
  Check(Fd >= 0, 'fd is valid');
  Check(platform_fs_exists(@Path[0]), 'temp file exists');
  AssignPlatformHandle(H, Fd);
  platform_file_close(H);
  platform_file_unlink(@Path[0]);
end;

procedure TestMktempUnique;
var
  Path1, Path2: array[0..511] of AnsiChar;
  Fd1, Fd2: Int32;
  I: Int32;
  Same: Boolean;
  H: TPlatformFileHandle;
begin
  Fd1 := -1; Fd2 := -1;
  Check(platform_fs_mktemp('u_', '', @Path1[0], 512, Fd1) = 0, 'mktemp 1');
  Check(platform_fs_mktemp('u_', '', @Path2[0], 512, Fd2) = 0, 'mktemp 2');
  Same := True;
  I := 0;
  while (Path1[I] <> #0) and (Path2[I] <> #0) do
  begin
    if Path1[I] <> Path2[I] then begin Same := False; Break; end;
    Inc(I);
  end;
  if Path1[I] <> Path2[I] then Same := False;
  Check(not Same, 'paths are unique');
  AssignPlatformHandle(H, Fd1); platform_file_close(H);
  AssignPlatformHandle(H, Fd2); platform_file_close(H);
  platform_file_unlink(@Path1[0]);
  platform_file_unlink(@Path2[0]);
end;

procedure TestMkdirP;
const
  DEEP = '/tmp/nextpas_test_mkdir_p/a/b/c';
begin
  platform_file_rmdir('/tmp/nextpas_test_mkdir_p/a/b/c');
  platform_file_rmdir('/tmp/nextpas_test_mkdir_p/a/b');
  platform_file_rmdir('/tmp/nextpas_test_mkdir_p/a');
  platform_file_rmdir('/tmp/nextpas_test_mkdir_p');
  Check(platform_fs_mkdir_p(DEEP, 493) = 0, 'mkdir_p succeeds');
  Check(platform_fs_is_dir(DEEP), 'deep dir exists');
  Check(platform_fs_mkdir_p(DEEP, 493) = 0, 'mkdir_p idempotent');
  platform_file_rmdir('/tmp/nextpas_test_mkdir_p/a/b/c');
  platform_file_rmdir('/tmp/nextpas_test_mkdir_p/a/b');
  platform_file_rmdir('/tmp/nextpas_test_mkdir_p/a');
  platform_file_rmdir('/tmp/nextpas_test_mkdir_p');
end;

procedure TestCopyFile;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
  Size: Int64;
begin
  platform_file_open('/tmp/nextpas_copy_src.txt', fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('hello copy'), 10, W);
  platform_file_close(H);
  Check(platform_fs_copy_file('/tmp/nextpas_copy_src.txt', '/tmp/nextpas_copy_dst.txt') = 0, 'copy ok');
  Check(platform_fs_is_file('/tmp/nextpas_copy_dst.txt'), 'dst exists');
  Check(platform_fs_file_size('/tmp/nextpas_copy_dst.txt', Size) = 0, 'stat dst');
  Check(Size = 10, 'dst size = 10');
  platform_file_unlink('/tmp/nextpas_copy_src.txt');
  platform_file_unlink('/tmp/nextpas_copy_dst.txt');
end;

procedure TestWriteAtomic;
var
  Size: Int64;
  H: TPlatformFileHandle;
  LBuf: array[0..31] of AnsiChar;
  LRead: PtrUInt;
  LStat: TPlatformFileStat;
const
  DATA = 'atomic write test';
  PATH = '/tmp/nextpas_atomic_test.dat';
begin
  platform_file_unlink(PATH);
  { APerm 在临时文件创建时即生效：文件从出生就是 0600，不存在
    「0666&umask 落盘 → rename → 事后 chmod」的组/其他可读窗口。 }
  Check(platform_fs_write_atomic(PATH, PAnsiChar(DATA), 17, $180) = 0,
    'write_atomic ok');
  Check(platform_fs_is_file(PATH), 'file exists');
  Check(platform_fs_file_size(PATH, Size) = 0, 'stat');
  Check(Size = 17, 'size = 17');
  Check(platform_file_stat(PATH, LStat) = 0, 'stat perms');
  Check(LStat.Mode and $1FF = $180, 'mode = 0600 from birth');
  platform_file_open(PATH, fomReadOnly, fcmOpenExisting, H);
  platform_file_read(H, @LBuf[0], 17, LRead);
  platform_file_close(H);
  Check(LRead = 17, 'read 17 bytes');
  LBuf[17] := #0;
  Check(LBuf[0] = 'a', 'content[0]');
  Check(not platform_fs_exists(PAnsiChar(PATH + '.tmp')), 'tmp cleaned up');
  platform_file_unlink(PATH);
end;

procedure TestReadFileInto;
var
  H: TPlatformFileHandle;
  W, Len: PtrUInt;
  Buf: array[0..31] of AnsiChar;
const
  PATH = '/tmp/nextpas_read_into_test.dat';
  DATA = 'read me now';
begin
  platform_file_unlink(PATH);
  platform_file_open(PATH, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar(DATA), 11, W);
  platform_file_close(H);

  FillChar(Buf, SizeOf(Buf), 0);
  Len := 0;
  Check(platform_fs_read_file_into(PATH, @Buf[0], SizeOf(Buf), Len) = 0,
    'read_file_into ok');
  Check(Len = 11, 'read_file_into len');
  Check(Buf[0] = 'r', 'read_file_into first byte');
  Check(Buf[10] = 'w', 'read_file_into last byte');

  platform_file_unlink(PATH);
end;

procedure TestReadFile;
const
  PATH = '/tmp/nextpas_read_file_test.dat';
  DATA = 'hello dynamic read';
var
  H: TPlatformFileHandle;
  W: PtrUInt;
  LData: Pointer;
  LLen: PtrUInt;
begin
  platform_file_unlink(PATH);
  platform_file_open(PATH, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar(DATA), 18, W);
  platform_file_close(H);

  LData := nil;
  LLen := 0;
  Check(platform_fs_read_file(PATH, LData, LLen) = 0, 'read_file ok');
  Check(LData <> nil, 'data not nil');
  Check(LLen = 18, 'len = 18');
  Check(PAnsiChar(LData)[0] = 'h', 'first byte');
  Check(PAnsiChar(LData)[17] = 'd', 'last byte');
  platform_fs_free_buf(LData);

  platform_file_unlink(PATH);
end;

procedure TestReadFileNonExistent;
var
  LData: Pointer;
  LLen: PtrUInt;
begin
  LData := nil;
  LLen := 0;
  Check(platform_fs_read_file('/tmp/nextpas_nonexistent_xyz_read', LData, LLen) <> 0,
    'read non-existent fails');
  Check(LData = nil, 'data remains nil on failure');
end;

procedure TestIsExecutable;
begin
  Check(platform_fs_is_executable('/bin/sh'), '/bin/sh is executable');
  Check(not platform_fs_is_executable('/etc/hostname'), '/etc/hostname not executable');
  Check(not platform_fs_is_executable('/tmp/nextpas_nonexistent_xyz_exec'), 'non-existent not executable');
end;

procedure TestFileIoContract;
var
  LSource: string;
  LAtomicSource: string;
  LCopySource: string;
  LTotalInitPos: SizeInt;
  LFStatPos: SizeInt;
begin
  LSource := LoadSourceText('../../../src/nextpas.core.platform.fs.pas');
  LAtomicSource := SourceSlice(LSource,
    'function platform_fs_write_atomic',
    'function platform_fs_mktemp');
  LCopySource := SourceSlice(LSource,
    '{ Linux: try sendfile for zero-copy transfer }',
    '{ Non-Linux: standard read/write loop }');
  LTotalInitPos := Pos('LTotal := 0;', LCopySource);
  LFStatPos := Pos('LHasSourceSize := platform_file_fstat(LSrcH, LStat) = 0;',
    LCopySource);
  Check(LTotalInitPos > 0,
    'copy_file must initialize the Linux byte total');
  Check(LFStatPos > 0,
    'copy_file Linux fast path must retain its fstat guard');
  Check(LTotalInitPos < LFStatPos,
    'copy_file must initialize the byte total before fstat can fail');
  CheckContains(LCopySource, 'if LHasSourceSize then',
    'copy_file must guard every source-size-dependent path');
  CheckAbsent(LCopySource, 'until LTotal >= LStat.Size',
    'copy_file must not read unknown source size after fstat failure');
  CheckContains(LSource, 'function platform_fs_write_all',
    'platform.fs must centralize full-write retry');
  CheckContains(LSource, 'PLATFORM_FS_SHORT_WRITE_ERROR',
    'short writes must map to a non-zero platform error');
  CheckContains(LSource, 'if LWritten = 0 then',
    'full-write helper must reject zero-progress writes');
  CheckContains(LSource, 'Inc(LTotal, LWritten)',
    'full-write helper must advance after positive short writes');
  CheckContains(LSource, 'LR := platform_fs_write_all(LDstH, @LBuf[0], LRead)',
    'copy_file must write each read chunk fully');
  CheckContains(LSource, 'LCloseR := platform_file_close(LDstH)',
    'copy_file must check destination close failure');
  CheckContains(LSource, 'LCloseR := platform_file_close(LSrcH)',
    'copy_file must check source close failure');
  CheckContains(LSource, 'if (LR = 0) and (LCloseR <> 0) then',
    'copy_file must report close failure when copy body succeeds');
  CheckContains(LSource, 'LR := platform_fs_write_all(LH, AData, ALen)',
    'write_atomic must write the full payload');
  CheckContains(LSource, 'LR := platform_file_sync(LH)',
    'write_atomic must check sync failure');
  CheckContains(LSource, 'LR := platform_file_close(LH)',
    'write_atomic must check close failure');
  CheckContains(LAtomicSource, 'MAX_ATOMIC_TEMP_ATTEMPTS',
    'write_atomic must bound temp-name collision retries');
  CheckContains(LAtomicSource, 'if platform_random_bytes(@LRand[0], 6) <> 0 then',
    'write_atomic must fail closed when random source fails');
  CheckContains(LAtomicSource, 'fcmCreateNew',
    'write_atomic must exclusively create temp files');
  CheckContains(LSource, 'function platform_fs_read_all',
    'platform.fs must centralize full-read retry');
  CheckContains(LSource, 'PLATFORM_FS_SHORT_READ_ERROR',
    'short reads must map to a non-zero platform error');
  CheckContains(LSource, 'if LChunk = 0 then',
    'full-read helper must reject zero-progress reads');
  CheckContains(LSource, 'Inc(ABytesRead, LChunk)',
    'full-read helper must advance after positive short reads');
  CheckContains(LSource, 'ABuf: Pointer; ABufCapacity: PtrUInt; out ALen: PtrUInt',
    'read_file_into exposes caller-owned buffer contract');
  CheckContains(LSource, 'PLATFORM_FS_SHORT_READ_ERROR',
    'read_file_into rejects undersized caller buffer');
  CheckContains(LSource, 'ALen := LTotal',
    'read_file_into returns actual bytes read');
  CheckContains(LSource, 'platform_fs_read_until_eof',
    'read_file must use TOCTOU-safe dynamic read');
  CheckContains(LSource, 'LCloseR := platform_file_close(LH)',
    'read_file must check close failure');
  CheckContains(LSource, 'if (LR = 0) and (LCloseR <> 0) then',
    'read_file must report close failure when read succeeds');
  CheckAbsent(LSource, 'until (LR <> 0) or (LWritten < LRead)',
    'copy_file must not report success after a short write exit');
  CheckAbsent(LSource, 'platform_file_close(LDstH);' + LineEnding +
    '  platform_file_close(LSrcH);' + LineEnding +
    '  Result := LR;',
    'copy_file must not ignore close failures');
  CheckAbsent(LSource, 'if (LR <> 0) or (LWritten <> ALen) then',
    'write_atomic must not depend on one write call for full payload');
  CheckAbsent(LSource, 'platform_file_sync(LH);' + LineEnding +
    '  platform_file_close(LH);',
    'write_atomic must not ignore sync or close failures');
  CheckAbsent(LSource, 'LR := platform_fs_read_all(LH, AData, PtrUInt(LSize), LRead);' + LineEnding +
    '  platform_file_close(LH);',
    'read_file must not ignore close failure after full read');
end;

procedure TestMktempHandle;
var
  LPath: array[0..255] of AnsiChar;
  LHandle: TPlatformFileHandle;
  LWritten: PtrUInt;
  R: Int32;
begin
  FillChar(LPath, SizeOf(LPath), 0);
  R := platform_fs_mktemp_handle('npfstest_', '.tmp', @LPath[0], 256, LHandle);
  Check(R = 0, 'mktemp_handle returns success');
  Check(LPath[0] <> #0, 'path is filled');
  Check(platform_fs_is_file(@LPath[0]), 'temp file exists');
  { Write to handle to verify it's valid }
  Check(platform_file_write(LHandle, @R, SizeOf(R), LWritten) = 0, 'write to handle');
  Check(LWritten = SizeOf(R), 'wrote correct bytes');
  Check(platform_file_close(LHandle) = 0, 'close handle');
  platform_file_unlink(@LPath[0]);
end;

procedure TestMoveFile;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
  Size: Int64;
const
  SRC = '/tmp/nextpas_move_src.txt';
  DST = '/tmp/nextpas_move_dst.txt';
begin
  platform_file_unlink(SRC);
  platform_file_unlink(DST);
  platform_file_open(SRC, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('move me'), 7, W);
  platform_file_close(H);
  Check(platform_fs_move_file(SRC, DST) = 0, 'move_file succeeds');
  Check(platform_fs_is_file(DST), 'dst exists');
  Check(not platform_fs_exists(SRC), 'src removed');
  Check(platform_fs_file_size(DST, Size) = 0, 'stat dst');
  Check(Size = 7, 'dst size = 7');
  platform_file_unlink(DST);
end;

procedure TestRemoveFile;
const
  PATH = '/tmp/nextpas_remove_test.txt';
var
  H: TPlatformFileHandle;
  W: PtrUInt;
begin
  platform_file_unlink(PATH);
  platform_file_open(PATH, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('bye'), 3, W);
  platform_file_close(H);
  Check(platform_fs_is_file(PATH), 'file exists before remove');
  Check(platform_fs_remove_file(PATH) = 0, 'remove_file succeeds');
  Check(not platform_fs_exists(PATH), 'file removed');
end;

procedure TestRemoveFileNonExistent;
begin
  Check(platform_fs_remove_file('/tmp/nextpas_nonexistent_rm_xyz') <> 0,
    'remove non-existent fails');
end;

procedure TestCopyNonExistent;
begin
  Check(platform_fs_copy_file('/tmp/nextpas_nonexistent_src_xyz',
    '/tmp/nextpas_nonexistent_dst_xyz') <> 0,
    'copy non-existent fails');
end;

procedure TestMoveNonExistent;
begin
  Check(platform_fs_move_file('/tmp/nextpas_nonexistent_mv_src_xyz',
    '/tmp/nextpas_nonexistent_mv_dst_xyz') <> 0,
    'move non-existent fails');
end;

procedure TestRemoveDir;
const
  DIR = '/tmp/nextpas_test_rmdir';
begin
  platform_fs_mkdir_p(DIR, $1FF); { 0777 }
  Check(platform_fs_is_dir(DIR), 'dir created');
  Check(platform_fs_remove_dir(DIR) = 0, 'remove_dir succeeds');
  Check(not platform_fs_exists(DIR), 'dir removed');
end;

procedure TestRemoveDirNonExistent;
begin
  Check(platform_fs_remove_dir('/tmp/nextpas_nonexistent_rmdir_xyz') <> 0,
    'remove non-existent dir fails');
end;

procedure TestRename;
const
  SRC = '/tmp/nextpas_test_rename_src';
  DST = '/tmp/nextpas_test_rename_dst';
  DATA = 'rename test data';
var
  H: TPlatformFileHandle;
  LWritten: PtrUInt;
  LSize: Int64;
begin
  { Create source file }
  platform_file_open(SRC, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar(DATA), Length(DATA), LWritten);
  platform_file_close(H);
  Check(platform_fs_exists(SRC), 'src exists before rename');
  { Rename }
  Check(platform_fs_rename(SRC, DST) = 0, 'rename succeeds');
  Check(not platform_fs_exists(SRC), 'src gone after rename');
  Check(platform_fs_exists(DST), 'dst exists after rename');
  Check(platform_fs_file_size(DST, LSize) = 0, 'get dst size');
  Check(LSize = Length(DATA), 'dst size matches');
  { Cleanup }
  platform_file_unlink(DST);
end;

procedure TestRenameNonExistent;
begin
  Check(platform_fs_rename('/tmp/nextpas_nonexistent_rename_xyz',
    '/tmp/nextpas_rename_dst_xyz') <> 0,
    'rename non-existent fails');
end;

procedure TestIsSymlink;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
const
  TARGET = '/tmp/nextpas_fs_symlink_target.txt';
  LINK = '/tmp/nextpas_fs_symlink_link';
begin
  platform_file_unlink(LINK);
  platform_file_unlink(TARGET);
  platform_file_open(TARGET, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('link target'), 12, W);
  platform_file_close(H);
  Check(platform_file_symlink(TARGET, LINK) = 0, 'symlink created');
  Check(platform_fs_is_symlink(LINK), 'is_symlink true');
  Check(not platform_fs_is_symlink(TARGET), 'is_symlink false for regular');
  Check(not platform_fs_is_symlink('/tmp/nextpas_nonexistent_xyz_sl'), 'is_symlink false for nonexistent');
  Check(not platform_fs_is_symlink(nil), 'is_symlink nil false');
  platform_file_unlink(LINK);
  platform_file_unlink(TARGET);
end;

procedure TestReadlink;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
  Buf: array[0..511] of AnsiChar;
  R: Int32;
const
  TARGET = '/tmp/nextpas_fs_rl_target.txt';
  LINK = '/tmp/nextpas_fs_rl_link';
begin
  platform_file_unlink(LINK);
  platform_file_unlink(TARGET);
  platform_file_open(TARGET, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('rl target'), 9, W);
  platform_file_close(H);
  platform_file_symlink(TARGET, LINK);
  FillChar(Buf, SizeOf(Buf), 0);
  R := platform_fs_readlink(LINK, @Buf[0], SizeOf(Buf));
  Check(R > 0, 'readlink returns positive length');
  Check(Platform_fs_readlink(LINK, @Buf[0], SizeOf(Buf)) >= 0, 'readlink ok');
  platform_file_unlink(LINK);
  platform_file_unlink(TARGET);
end;

procedure TestReadlinkNilBuffer;
var
  R: Int32;
begin
  R := platform_fs_readlink('/tmp/nextpas_nonexistent_xyz_rl', nil, 256);
  Check(R = PLATFORM_ERR_INVALID, 'readlink nil buffer returns INVALID');
end;

procedure TestChmod;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
  LStat: TPlatformFileStat;
const
  PATH = '/tmp/nextpas_fs_chmod_test.txt';
begin
  platform_file_unlink(PATH);
  platform_file_open(PATH, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('chmod'), 5, W);
  platform_file_close(H);
  Check(platform_fs_chmod(PATH, $1A4) = 0, 'chmod to 0644');
  Check(platform_file_stat(PATH, LStat) = 0, 'stat after chmod');
  platform_file_unlink(PATH);
end;

procedure TestChmodNonExistent;
begin
  Check(platform_fs_chmod('/tmp/nextpas_nonexistent_chmod_xyz', $1A4) <> 0,
    'chmod non-existent fails');
end;

procedure TestTruncate;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
  LSize: Int64;
const
  PATH = '/tmp/nextpas_fs_truncate_test.txt';
begin
  platform_file_unlink(PATH);
  platform_file_open(PATH, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('hello truncate'), 14, W);
  platform_file_close(H);
  Check(platform_fs_truncate(PATH, 5) = 0, 'truncate to 5');
  Check(platform_fs_file_size(PATH, LSize) = 0, 'stat after truncate');
  Check(LSize = 5, 'size = 5 after truncate');
  platform_file_unlink(PATH);
end;

procedure TestTruncateNonExistent;
begin
  Check(platform_fs_truncate('/tmp/nextpas_nonexistent_trunc_xyz', 0) <> 0,
    'truncate non-existent fails');
end;

procedure TestSync;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
  R: Int32;
const
  PATH = '/tmp/nextpas_fs_sync_test.txt';
begin
  platform_file_unlink(PATH);
  platform_file_open(PATH, fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('sync me'), 7, W);
  R := platform_fs_sync(H);
  Check(R = 0, 'sync returns 0 on valid handle');
  platform_file_close(H);
  platform_file_unlink(PATH);
end;

procedure TestExistsNilPath;
begin
  Check(not platform_fs_exists(nil), 'exists nil returns false');
end;

procedure TestIsFileNilPath;
begin
  Check(not platform_fs_is_file(nil), 'is_file nil returns false');
end;

procedure TestIsDirNilPath;
begin
  Check(not platform_fs_is_dir(nil), 'is_dir nil returns false');
end;

procedure TestTempDirNotNil;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_fs_temp_dir(@Buf[0], 256);
  Check(R > 0, 'temp_dir returns length > 0');
  Check(Buf[0] <> #0, 'temp_dir not empty');
end;

procedure TestFileSizeNonExistent;
var
  LSize: Int64;
begin
  Check(platform_fs_file_size('/tmp/nextpas_nonexistent_size_xyz', LSize) <> 0,
    'file_size non-existent returns error');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.fs');
  T.Test('exists file', @TestExistsFile);
  T.Test('exists non-existent', @TestExistsNot);
  T.Test('is_file', @TestIsFile);
  T.Test('is_dir', @TestIsDir);
  T.Test('file_size', @TestFileSize);
  T.Test('temp_dir', @TestTempDir);
  T.Test('mktemp', @TestMktemp);
  T.Test('mktemp unique', @TestMktempUnique);
  T.Test('mkdir_p', @TestMkdirP);
  T.Test('copy_file', @TestCopyFile);
  T.Test('move_file', @TestMoveFile);
  T.Test('remove_file', @TestRemoveFile);
  T.Test('remove_file non-existent', @TestRemoveFileNonExistent);
  T.Test('copy non-existent', @TestCopyNonExistent);
  T.Test('move non-existent', @TestMoveNonExistent);
  T.Test('remove_dir', @TestRemoveDir);
  T.Test('remove_dir non-existent', @TestRemoveDirNonExistent);
  T.Test('rename', @TestRename);
  T.Test('rename non-existent', @TestRenameNonExistent);
  T.Test('write_atomic', @TestWriteAtomic);
  T.Test('read_file_into', @TestReadFileInto);
  T.Test('read_file_dynamic', @TestReadFile);
  T.Test('read_file non-existent', @TestReadFileNonExistent);
  T.Test('is_executable', @TestIsExecutable);
  T.Test('file I/O contract', @TestFileIoContract);
  T.Test('mktemp_handle creates file', @TestMktempHandle);
  T.Test('exists nil path', @TestExistsNilPath);
  T.Test('is_file nil path', @TestIsFileNilPath);
  T.Test('is_dir nil path', @TestIsDirNilPath);
  T.Test('temp_dir returns valid path', @TestTempDirNotNil);
  T.Test('file_size non-existent', @TestFileSizeNonExistent);
  T.Test('is_symlink', @TestIsSymlink);
  T.Test('readlink', @TestReadlink);
  T.Test('readlink nil buffer', @TestReadlinkNilBuffer);
  T.Test('chmod', @TestChmod);
  T.Test('chmod non-existent', @TestChmodNonExistent);
  T.Test('truncate', @TestTruncate);
  T.Test('truncate non-existent', @TestTruncateNonExistent);
  T.Test('sync', @TestSync);
  if not T.Run then Halt(1);
end.
