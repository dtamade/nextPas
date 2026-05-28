program test_platform_path;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.path,
  nextpas.core.testing;

var
  T: TTestRunner;

function BufEq(const ABuf: PAnsiChar; const AExpect: PAnsiChar): Boolean;
var
  I: Int32;
begin
  I := 0;
  while (ABuf[I] <> #0) and (AExpect[I] <> #0) do
  begin
    if ABuf[I] <> AExpect[I] then Exit(False);
    Inc(I);
  end;
  Result := (ABuf[I] = #0) and (AExpect[I] = #0);
end;

procedure TestJoinBasic;
var
  Buf: array[0..255] of AnsiChar;
begin
  platform_path_join('src', 'file.pas', @Buf[0], 256);
  Check(BufEq(@Buf[0], 'src/file.pas'), 'join src + file.pas');
end;

procedure TestJoinTrailingSep;
var
  Buf: array[0..255] of AnsiChar;
begin
  platform_path_join('src/', 'file.pas', @Buf[0], 256);
  Check(BufEq(@Buf[0], 'src/file.pas'), 'join src/ + file.pas');
end;

procedure TestDirname;
var
  Buf: array[0..255] of AnsiChar;
begin
  platform_path_dirname('/home/user/file.pas', @Buf[0], 256);
  Check(BufEq(@Buf[0], '/home/user'), 'dirname /home/user/file.pas');
end;

procedure TestDirnameNoDir;
var
  Buf: array[0..255] of AnsiChar;
begin
  platform_path_dirname('file.pas', @Buf[0], 256);
  Check(BufEq(@Buf[0], ''), 'dirname file.pas = empty');
end;

procedure TestBasename;
var
  Buf: array[0..255] of AnsiChar;
begin
  platform_path_basename('/home/user/file.pas', @Buf[0], 256);
  Check(BufEq(@Buf[0], 'file.pas'), 'basename');
end;

procedure TestExtension;
var
  Buf: array[0..255] of AnsiChar;
begin
  platform_path_extension('file.pas', @Buf[0], 256);
  Check(BufEq(@Buf[0], '.pas'), 'ext .pas');
end;

procedure TestExtensionNone;
var
  Buf: array[0..255] of AnsiChar;
begin
  platform_path_extension('Makefile', @Buf[0], 256);
  Check(BufEq(@Buf[0], ''), 'no extension');
end;

procedure TestChangeExt;
var
  Buf: array[0..255] of AnsiChar;
begin
  platform_path_change_ext('file.pas', '.o', @Buf[0], 256);
  Check(BufEq(@Buf[0], 'file.o'), 'change ext .pas -> .o');
end;

procedure TestIsAbsolute;
begin
  Check(platform_path_is_absolute('/usr/bin'), '/usr/bin is absolute');
  Check(not platform_path_is_absolute('src/file'), 'src/file is relative');
  Check(not platform_path_is_absolute(''), 'empty is relative');
end;

procedure TestNormalize;
var
  Buf: array[0..255] of AnsiChar;
begin
  platform_path_normalize('src/../lib/./file.pas', @Buf[0], 256);
  Check(BufEq(@Buf[0], 'lib/file.pas'), 'normalize src/../lib/./file.pas');
  platform_path_normalize('/a/b/../c', @Buf[0], 256);
  Check(BufEq(@Buf[0], '/a/c'), 'normalize /a/b/../c');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.path');
  T.Run('join basic', @TestJoinBasic);
  T.Run('join trailing sep', @TestJoinTrailingSep);
  T.Run('dirname', @TestDirname);
  T.Run('dirname no dir', @TestDirnameNoDir);
  T.Run('basename', @TestBasename);
  T.Run('extension', @TestExtension);
  T.Run('extension none', @TestExtensionNone);
  T.Run('change ext', @TestChangeExt);
  T.Run('is_absolute', @TestIsAbsolute);
  T.Run('normalize', @TestNormalize);
  T.Summary;
end.
