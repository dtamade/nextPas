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
  platform_path_extension('.gitignore', @Buf[0], 256);
  Check(BufEq(@Buf[0], ''), '.gitignore has no extension');
  platform_path_extension('.hidden', @Buf[0], 256);
  Check(BufEq(@Buf[0], ''), '.hidden has no extension');
  platform_path_extension('/path/.config', @Buf[0], 256);
  Check(BufEq(@Buf[0], ''), '/path/.config has no extension');
  platform_path_extension('.bashrc.bak', @Buf[0], 256);
  Check(BufEq(@Buf[0], '.bak'), '.bashrc.bak ext is .bak');
end;

procedure TestChangeExt;
var
  Buf: array[0..255] of AnsiChar;
begin
  platform_path_change_ext('file.pas', '.o', @Buf[0], 256);
  Check(BufEq(@Buf[0], 'file.o'), 'change ext .pas -> .o');
  platform_path_change_ext('.gitignore', '.bak', @Buf[0], 256);
  Check(BufEq(@Buf[0], '.gitignore.bak'), '.gitignore -> .gitignore.bak');
  platform_path_change_ext('.bashrc.bak', '.old', @Buf[0], 256);
  Check(BufEq(@Buf[0], '.bashrc.old'), '.bashrc.bak -> .bashrc.old');
  platform_path_change_ext('noext', '.txt', @Buf[0], 256);
  Check(BufEq(@Buf[0], 'noext.txt'), 'noext -> noext.txt');
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

procedure TestBasenamePtr;
var
  P: PAnsiChar;
  L: Int32;
begin
  platform_path_basename_ptr('/home/user/file.pas', P, L);
  Check(L = 8, 'basename_ptr len = 8');
  Check(P[0] = 'f', 'basename_ptr[0] = f');
  Check(P[7] = 's', 'basename_ptr[7] = s');
end;

procedure TestExtensionPtr;
var
  P: PAnsiChar;
  L: Int32;
begin
  platform_path_extension_ptr('file.pas', P, L);
  Check(L = 4, 'ext_ptr len = 4');
  Check(P[0] = '.', 'ext_ptr[0] = .');
  Check(P[1] = 'p', 'ext_ptr[1] = p');
  platform_path_extension_ptr('Makefile', P, L);
  Check(L = 0, 'no ext ptr len = 0');
  Check(P = nil, 'no ext ptr = nil');
end;

procedure TestJoinAbsoluteChild;
var
  Buf: array[0..255] of AnsiChar;
begin
  platform_path_join('/home/user', '/etc/passwd', @Buf[0], 256);
  Check(BufEq(@Buf[0], '/etc/passwd'), 'absolute child replaces base');
end;

procedure TestNormalizeRelativeDotDot;
var
  Buf: array[0..255] of AnsiChar;
begin
  platform_path_normalize('../../file.pas', @Buf[0], 256);
  Check(BufEq(@Buf[0], '../../file.pas'), 'relative .. preserved');
  platform_path_normalize('.', @Buf[0], 256);
  Check(BufEq(@Buf[0], '.'), 'single dot = .');
end;

procedure TestDirnameRoot;
var
  Buf: array[0..255] of AnsiChar;
begin
  platform_path_dirname('/', @Buf[0], 256);
  Check(BufEq(@Buf[0], '/'), 'dirname / = /');
end;

procedure TestResolveAbsolute;
var
  Buf: array[0..511] of AnsiChar;
  R: Int32;
begin
  R := platform_path_resolve('/tmp', @Buf[0], 512);
  Check(R > 0, 'resolve /tmp');
  Check(Buf[0] = '/', 'absolute');
end;

procedure TestResolveRelative;
var
  Buf: array[0..511] of AnsiChar;
  R: Int32;
begin
  R := platform_path_resolve('.', @Buf[0], 512);
  Check(R > 0, 'resolve .');
  Check(Buf[0] = '/', 'result is absolute');
end;

procedure TestResolveNonExistent;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_path_resolve('/nonexistent_xyz_path_999', @Buf[0], 256);
  Check(R = -1, 'non-existent returns -1');
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
  T.Run('basename_ptr zero-copy', @TestBasenamePtr);
  T.Run('extension_ptr zero-copy', @TestExtensionPtr);
  T.Run('join absolute child', @TestJoinAbsoluteChild);
  T.Run('normalize relative ..', @TestNormalizeRelativeDotDot);
  T.Run('dirname root', @TestDirnameRoot);
  T.Run('resolve absolute', @TestResolveAbsolute);
  T.Run('resolve relative', @TestResolveRelative);
  T.Run('resolve non-existent', @TestResolveNonExistent);
  T.Summary;
end.
