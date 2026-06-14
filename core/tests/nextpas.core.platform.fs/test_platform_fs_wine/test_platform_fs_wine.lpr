program test_platform_fs_wine;

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
  ExistsFilePath: AnsiString;
  MissingPath: AnsiString;
  IsFilePath: AnsiString;
  SizePath: AnsiString;
  MkdirBase: AnsiString;
  CopySrcPath: AnsiString;
  CopyDstPath: AnsiString;
  AtomicPath: AnsiString;
  ReadPath: AnsiString;

{$IFDEF NEXTPAS_WINDOWS}

procedure AssignPlatformHandle(var AHandle: TPlatformFileHandle; const AFd: Int32);
begin
{$IFDEF NEXTPAS_WINDOWS}
  AHandle.Value := Pointer(PtrUInt(AFd));
{$ELSE}
  AHandle.Value := AFd;
{$ENDIF}
end;

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
  ExistsFilePath := TempPath('nxp_fs_exists.txt');
  MissingPath := TempPath('nxp_fs_nonexistent_xyz_999');
  IsFilePath := TempPath('nxp_fs_isfile.txt');
  SizePath := TempPath('nxp_fs_size.txt');
  MkdirBase := TempPath('nxp_fs_mkp');
  CopySrcPath := TempPath('nxp_copy_src.txt');
  CopyDstPath := TempPath('nxp_copy_dst.txt');
  AtomicPath := TempPath('nxp_fs_atomic_test.dat');
  ReadPath := TempPath('nxp_fs_read.txt');
end;

{ 1. File exists — create a file and verify it exists }
procedure TestExistsFile;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
begin
  platform_file_open(PAnsiChar(ExistsFilePath), fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('hi'), 2, W);
  platform_file_close(H);
  Check(platform_fs_exists(PAnsiChar(ExistsFilePath)), 'file exists');
  platform_file_unlink(PAnsiChar(ExistsFilePath));
end;

{ 2. File does not exist }
procedure TestExistsNot;
begin
  Check(not platform_fs_exists(PAnsiChar(MissingPath)), 'non-existent');
end;

{ 3. is_file / is_dir — regular file }
procedure TestIsFile;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
begin
  platform_file_open(PAnsiChar(IsFilePath), fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('x'), 1, W);
  platform_file_close(H);
  Check(platform_fs_is_file(PAnsiChar(IsFilePath)), 'is file');
  Check(not platform_fs_is_dir(PAnsiChar(IsFilePath)), 'not dir');
  platform_file_unlink(PAnsiChar(IsFilePath));
end;

{ 4. is_dir — directory detection (use Wine-native temp dir) }
procedure TestIsDir;
begin
  Check(platform_fs_is_dir(@TmpPrefix[0]), 'temp dir is_dir');
  Check(not platform_fs_is_file(@TmpPrefix[0]), 'temp dir not is_file');
end;

{ 5. File size }
procedure TestFileSize;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
  Size: Int64;
begin
  platform_file_open(PAnsiChar(SizePath), fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('hello'), 5, W);
  platform_file_close(H);
  Check(platform_fs_file_size(PAnsiChar(SizePath), Size) = 0, 'stat ok');
  Check(Size = 5, 'size = 5');
  platform_file_unlink(PAnsiChar(SizePath));
end;

{ 6. Temp directory }
procedure TestTempDir;
begin
  Check(platform_fs_is_dir(@TmpPrefix[0]), 'temp dir exists');
end;

{ 7. Mktemp — create temporary file }
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

{ 8. Mkdir_p — recursive directory creation under temp_dir }
procedure TestMkdirP;
var
  Deep, A, AB, ABC: AnsiString;
begin
  A := MkdirBase;
  AB := A + '\a';
  ABC := AB + '\b';
  Deep := ABC + '\c';
  { cleanup any leftovers, deepest first }
  platform_file_rmdir(PAnsiChar(Deep));
  platform_file_rmdir(PAnsiChar(ABC));
  platform_file_rmdir(PAnsiChar(AB));
  platform_file_rmdir(PAnsiChar(A));
  Check(platform_fs_mkdir_p(PAnsiChar(Deep), 493) = 0, 'mkdir_p succeeds');
  Check(platform_fs_is_dir(PAnsiChar(Deep)), 'deep dir exists');
  Check(platform_fs_mkdir_p(PAnsiChar(Deep), 493) = 0, 'mkdir_p idempotent');
  platform_file_rmdir(PAnsiChar(Deep));
  platform_file_rmdir(PAnsiChar(ABC));
  platform_file_rmdir(PAnsiChar(AB));
  platform_file_rmdir(PAnsiChar(A));
end;

{ 9. Copy file }
procedure TestCopyFile;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
  Size: Int64;
begin
  platform_file_open(PAnsiChar(CopySrcPath), fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('hello copy'), 10, W);
  platform_file_close(H);
  Check(platform_fs_copy_file(PAnsiChar(CopySrcPath), PAnsiChar(CopyDstPath)) = 0, 'copy ok');
  Check(platform_fs_is_file(PAnsiChar(CopyDstPath)), 'dst exists');
  Check(platform_fs_file_size(PAnsiChar(CopyDstPath), Size) = 0, 'stat dst');
  Check(Size = 10, 'dst size = 10');
  platform_file_unlink(PAnsiChar(CopySrcPath));
  platform_file_unlink(PAnsiChar(CopyDstPath));
end;

{ 10. Write atomic }
procedure TestWriteAtomic;
var
  Size: Int64;
  H: TPlatformFileHandle;
  LBuf: array[0..31] of AnsiChar;
  LRead: PtrUInt;
const
  DATA = 'atomic write test';
begin
  platform_file_unlink(PAnsiChar(AtomicPath));
  Check(platform_fs_write_atomic(PAnsiChar(AtomicPath), PAnsiChar(DATA), 17) = 0, 'write_atomic ok');
  Check(platform_fs_is_file(PAnsiChar(AtomicPath)), 'file exists');
  Check(platform_fs_file_size(PAnsiChar(AtomicPath), Size) = 0, 'stat');
  Check(Size = 17, 'size = 17');
  platform_file_open(PAnsiChar(AtomicPath), fomReadOnly, fcmOpenExisting, H);
  platform_file_read(H, @LBuf[0], 17, LRead);
  platform_file_close(H);
  Check(LRead = 17, 'read 17 bytes');
  LBuf[17] := #0;
  Check(LBuf[0] = 'a', 'content[0]');
  Check(not platform_fs_exists(PAnsiChar(AtomicPath + '.tmp')), 'tmp cleaned up');
  platform_file_unlink(PAnsiChar(AtomicPath));
end;

{ 11. Read file + free buf }
procedure TestReadFile;
var
  H: TPlatformFileHandle;
  W: PtrUInt;
  Data: Pointer;
  Len: PtrUInt;
begin
  platform_file_open(PAnsiChar(ReadPath), fomWriteOnly, fcmCreateAlways, H);
  platform_file_write(H, PAnsiChar('read me now'), 12, W);
  platform_file_close(H);
  Check(platform_fs_read_file(PAnsiChar(ReadPath), Data, Len) = 0, 'read_file ok');
  Check(Len = 12, 'len = 12');
  Check(PAnsiChar(Data)[0] = 'r', 'content starts with r');
  platform_fs_free_buf(Data);
  platform_file_unlink(PAnsiChar(ReadPath));
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.platform.fs.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  Check(platform_fs_temp_dir(@TmpPrefix[0], SizeOf(TmpPrefix)) > 0, 'temp dir init');
  InitTempPaths;
  T.Run('exists file', @TestExistsFile);
  T.Run('exists non-existent', @TestExistsNot);
  T.Run('is_file', @TestIsFile);
  T.Run('is_dir', @TestIsDir);
  T.Run('file_size', @TestFileSize);
  T.Run('temp_dir', @TestTempDir);
  T.Run('mktemp', @TestMktemp);
  T.Run('mkdir_p', @TestMkdirP);
  T.Run('copy_file', @TestCopyFile);
  T.Run('write_atomic', @TestWriteAtomic);
  T.Run('read_file + free_buf', @TestReadFile);
  {$ELSE}
  T.Run('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  T.Summary;
end.
