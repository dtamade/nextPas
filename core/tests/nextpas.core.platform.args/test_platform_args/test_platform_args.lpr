program test_platform_args;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.args,
  nextpas.core.platform.fs,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestCount;
begin
  Check(platform_args_count >= 0, 'count >= 0');
end;

procedure TestGetArg0;
var
  Buf: array[0..511] of AnsiChar;
  R: Int32;
begin
  R := platform_args_get(0, @Buf[0], 512);
  Check(R > 0, 'arg0 has length > 0');
  Check(Buf[0] <> #0, 'arg0 not empty');
end;

procedure TestGetInvalid;
var
  Buf: array[0..63] of AnsiChar;
begin
  Check(platform_args_get(-1, @Buf[0], 64) = -1, 'index -1 returns -1');
  Check(platform_args_get(9999, @Buf[0], 64) = -1, 'index 9999 returns -1');
end;

procedure TestExePath;
var
  Buf: array[0..511] of AnsiChar;
  R: Int32;
begin
  R := platform_args_exe_path(@Buf[0], 512);
  Check(R > 0, 'exe_path has length > 0');
  Check(platform_fs_exists(@Buf[0]), 'exe_path exists on disk');
end;

procedure TestNilBuf;
begin
  Check(platform_args_get(0, nil, 0) = -1, 'nil buf returns -1');
  Check(platform_args_exe_path(nil, 0) = -1, 'nil buf exe returns -1');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.args');
  T.Run('count', @TestCount);
  T.Run('get arg0', @TestGetArg0);
  T.Run('get invalid index', @TestGetInvalid);
  T.Run('exe path', @TestExePath);
  T.Run('nil buffer', @TestNilBuf);
  T.Summary;
end.
