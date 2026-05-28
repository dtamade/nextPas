program test_platform_fs;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.fs,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.testing;

var
  T: TTestRunner;

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

begin
  T := TTestRunner.Create('nextpas.core.platform.fs');
  T.Run('exists file', @TestExistsFile);
  T.Run('exists non-existent', @TestExistsNot);
  T.Run('is_file', @TestIsFile);
  T.Run('is_dir', @TestIsDir);
  T.Run('file_size', @TestFileSize);
  T.Run('temp_dir', @TestTempDir);
  T.Summary;
end.
