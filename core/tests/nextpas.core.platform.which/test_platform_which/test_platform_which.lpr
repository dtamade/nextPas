program test_platform_which;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.which,
  nextpas.core.platform.fs,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestFindSh;
var
  Buf: array[0..511] of AnsiChar;
  R: Int32;
begin
  R := platform_which('sh', @Buf[0], 512);
  Check(R > 0, 'which sh returns path');
  Check(platform_fs_is_file(@Buf[0]), 'path exists');
end;

procedure TestFindLs;
var
  Buf: array[0..511] of AnsiChar;
  R: Int32;
begin
  R := platform_which('ls', @Buf[0], 512);
  Check(R > 0, 'which ls returns path');
  Check(platform_fs_is_file(@Buf[0]), 'path exists');
end;

procedure TestNotFound;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_which('nonexistent_tool_xyz_999', @Buf[0], 256);
  Check(R = -1, 'not found returns -1');
end;

procedure TestAbsolutePath;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_which('/bin/sh', @Buf[0], 256);
  Check(R > 0, 'absolute path found');
  Check(Buf[0] = '/', 'starts with /');
end;

procedure TestAbsoluteNotExist;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_which('/nonexistent_xyz', @Buf[0], 256);
  Check(R = -1, 'absolute non-existent returns -1');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.which');
  T.Run('find sh', @TestFindSh);
  T.Run('find ls', @TestFindLs);
  T.Run('not found', @TestNotFound);
  T.Run('absolute path', @TestAbsolutePath);
  T.Run('absolute not exist', @TestAbsoluteNotExist);
  T.Summary;
end.
