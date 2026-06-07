program test_platform_fs;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  nextpas.core.platform.fs,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure AssignPlatformHandle(var AHandle: TPlatformFileHandle; const AFd: Int32);
begin
{$IFDEF NEXTPAS_WINDOWS}
  AHandle.Value := Pointer(PtrUInt(AFd));
{$ELSE}
  AHandle.Value := AFd;
{$ENDIF}
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LLines: TStringList;
begin
  Check(FileExists(ARelativePath), 'source file exists: ' + ARelativePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(ARelativePath);
    Result := LLines.Text;
  finally
    LLines.Free;
  end;
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) = 0, AMessage + ': ' + AToken);
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
const
  DATA = 'atomic write test';
  PATH = '/tmp/nextpas_atomic_test.dat';
begin
  platform_file_unlink(PATH);
  Check(platform_fs_write_atomic(PATH, PAnsiChar(DATA), 17) = 0, 'write_atomic ok');
  Check(platform_fs_is_file(PATH), 'file exists');
  Check(platform_fs_file_size(PATH, Size) = 0, 'stat');
  Check(Size = 17, 'size = 17');
  platform_file_open(PATH, fomReadOnly, fcmOpenExisting, H);
  platform_file_read(H, @LBuf[0], 17, LRead);
  platform_file_close(H);
  Check(LRead = 17, 'read 17 bytes');
  LBuf[17] := #0;
  Check(LBuf[0] = 'a', 'content[0]');
  Check(not platform_fs_exists(PAnsiChar(PATH + '.tmp')), 'tmp cleaned up');
  platform_file_unlink(PATH);
end;

procedure TestFileIoContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('../../../src/nextpas.core.platform.fs.pas');
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
  CheckContains(LSource, 'function platform_fs_read_all',
    'platform.fs must centralize full-read retry');
  CheckContains(LSource, 'PLATFORM_FS_SHORT_READ_ERROR',
    'short reads must map to a non-zero platform error');
  CheckContains(LSource, 'if LChunk = 0 then',
    'full-read helper must reject zero-progress reads');
  CheckContains(LSource, 'Inc(ABytesRead, LChunk)',
    'full-read helper must advance after positive short reads');
  CheckContains(LSource, 'LR := platform_fs_read_all(LH, AData, PtrUInt(LSize), LRead)',
    'read_file must read the full stat-sized payload');
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

begin
  T := TTestRunner.Create('nextpas.core.platform.fs');
  T.Run('exists file', @TestExistsFile);
  T.Run('exists non-existent', @TestExistsNot);
  T.Run('is_file', @TestIsFile);
  T.Run('is_dir', @TestIsDir);
  T.Run('file_size', @TestFileSize);
  T.Run('temp_dir', @TestTempDir);
  T.Run('mktemp', @TestMktemp);
  T.Run('mktemp unique', @TestMktempUnique);
  T.Run('mkdir_p', @TestMkdirP);
  T.Run('copy_file', @TestCopyFile);
  T.Run('write_atomic', @TestWriteAtomic);
  T.Run('file I/O contract', @TestFileIoContract);
  T.Summary;
end.
