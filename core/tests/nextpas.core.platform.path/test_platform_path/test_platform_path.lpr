program test_platform_path;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.path,
  nextpas.core.test;

var
  T: TTestSuite;

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

procedure TestJoin3;
var
  Buf: array[0..255] of AnsiChar;
begin
  platform_path_join3('build', 'units', 'system.ppu', @Buf[0], 256);
  Check(BufEq(@Buf[0], 'build/units/system.ppu'), 'join3 basic');
  platform_path_join3('/opt', 'fpc', 'bin', @Buf[0], 256);
  Check(BufEq(@Buf[0], '/opt/fpc/bin'), 'join3 absolute');
end;

procedure TestIsRoot;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Check(platform_path_is_root('C:\'), 'C:\ is root');
  Check(platform_path_is_root('C:/'), 'C:/ is root');
  Check(platform_path_is_root('\\server\share'), 'UNC share is root');
  Check(platform_path_is_root('\\?\C:\'), 'extended drive root is root');
  Check(not platform_path_is_root('C:\tmp'), 'C:\tmp is not root');
  Check(not platform_path_is_root('\\server\share\dir'), 'UNC child is not root');
{$ELSE}
  Check(platform_path_is_root('/'), '/ is root');
  Check(platform_path_is_root('///'), '/// is root');
  Check(not platform_path_is_root('/tmp'), '/tmp is not root');
  Check(not platform_path_is_root('.'), '. is not root');
{$ENDIF}
  Check(not platform_path_is_root(''), 'empty is not root');
end;

procedure TestEnsureSep;
var
  Buf: array[0..255] of AnsiChar;
begin
{$IFDEF NEXTPAS_WINDOWS}
  platform_path_ensure_sep('C:\tmp', @Buf[0], 256);
  Check(BufEq(@Buf[0], 'C:\tmp\'), 'ensure_sep adds backslash');
  platform_path_ensure_sep('C:\tmp\', @Buf[0], 256);
  Check(BufEq(@Buf[0], 'C:\tmp\'), 'ensure_sep no double backslash');
{$ELSE}
  platform_path_ensure_sep('/tmp', @Buf[0], 256);
  Check(BufEq(@Buf[0], '/tmp/'), 'ensure_sep adds slash');
  platform_path_ensure_sep('/tmp/', @Buf[0], 256);
  Check(BufEq(@Buf[0], '/tmp/'), 'ensure_sep no double slash');
{$ENDIF}
end;

procedure TestTrimSep;
var
  Buf: array[0..255] of AnsiChar;
begin
{$IFDEF NEXTPAS_WINDOWS}
  platform_path_trim_sep('C:\tmp\', @Buf[0], 256);
  Check(BufEq(@Buf[0], 'C:\tmp'), 'trim_sep removes trailing backslash');
  platform_path_trim_sep('C:\tmp', @Buf[0], 256);
  Check(BufEq(@Buf[0], 'C:\tmp'), 'trim_sep no-op without trailing');
  platform_path_trim_sep('C:\', @Buf[0], 256);
  Check(BufEq(@Buf[0], 'C:\'), 'trim_sep preserves root');
{$ELSE}
  platform_path_trim_sep('/tmp/', @Buf[0], 256);
  Check(BufEq(@Buf[0], '/tmp'), 'trim_sep removes trailing slash');
  platform_path_trim_sep('/tmp', @Buf[0], 256);
  Check(BufEq(@Buf[0], '/tmp'), 'trim_sep no-op without trailing');
  platform_path_trim_sep('/', @Buf[0], 256);
  Check(BufEq(@Buf[0], '/'), 'trim_sep preserves root');
{$ENDIF}
end;

procedure TestSameFileName;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Check(platform_path_same_file_name('Foo.txt', 'foo.txt'), 'case insensitive on Windows');
  Check(platform_path_same_file_name('foo.txt', 'foo.txt'), 'same name');
  Check(not platform_path_same_file_name('foo.txt', 'bar.txt'), 'different name');
{$ELSE}
  Check(platform_path_same_file_name('foo.txt', 'foo.txt'), 'same name');
  Check(not platform_path_same_file_name('foo.txt', 'Foo.txt'), 'case sensitive on POSIX');
  Check(not platform_path_same_file_name('foo.txt', 'bar.txt'), 'different name');
{$ENDIF}
end;

procedure TestRelative;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
{$IFDEF NEXTPAS_WINDOWS}
  R := platform_path_relative('C:\tmp\a', 'C:\tmp\b', @Buf[0], 256);
  if R > 0 then
    Check(BufEq(@Buf[0], '..\b') or BufEq(@Buf[0], 'b'), 'relative C:\tmp\a -> C:\tmp\b');
{$ELSE}
  R := platform_path_relative('/tmp/a', '/tmp/b', @Buf[0], 256);
  if R > 0 then
    Check(BufEq(@Buf[0], '../b') or BufEq(@Buf[0], 'b'), 'relative /tmp/a -> /tmp/b');
{$ENDIF}
end;

procedure TestJoinNilBase;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_path_join(nil, 'file.pas', @Buf[0], 256);
  Check(R <> 0, 'nil base returns error');
end;

procedure TestJoinNilChild;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_path_join('/tmp', nil, @Buf[0], 256);
  Check(R <> 0, 'nil child returns error');
end;

procedure TestDirnameNilPath;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_path_dirname(nil, @Buf[0], 256);
  Check(R >= 0, 'nil dirname does not crash');
end;

procedure TestBasenameNilPath;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_path_basename(nil, @Buf[0], 256);
  Check(R >= 0, 'nil basename does not crash');
end;

procedure TestNormalizeEmpty;
var
  Buf: array[0..255] of AnsiChar;
begin
  platform_path_normalize('', @Buf[0], 256);
  Check(BufEq(@Buf[0], ''), 'normalize empty = empty');
end;

procedure TestSmallBufferTruncation;
var
  Buf: array[0..3] of AnsiChar;
  R: Int32;
begin
  FillChar(Buf, SizeOf(Buf), Ord('?'));
  R := platform_path_join('/usr', 'bin', @Buf[0], 4);
  Check(R >= 0, 'small buffer returns non-negative');
  Check(Buf[3] = #0, 'small buffer null terminated');
end;

procedure TestJoinEmptyChild;
var
  Buf: array[0..255] of AnsiChar;
begin
  platform_path_join('/tmp', '', @Buf[0], 256);
  Check(BufEq(@Buf[0], '/tmp'), 'empty child returns base');
end;

procedure TestExtensionPtrPtr;
var
  P: PAnsiChar;
  L: Int32;
begin
  platform_path_extension_ptr(nil, P, L);
  Check(L = 0, 'nil extension_ptr len = 0');
  Check(P = nil, 'nil extension_ptr ptr = nil');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.path');
  T.Test('join basic', @TestJoinBasic);
  T.Test('join trailing sep', @TestJoinTrailingSep);
  T.Test('dirname', @TestDirname);
  T.Test('dirname no dir', @TestDirnameNoDir);
  T.Test('basename', @TestBasename);
  T.Test('extension', @TestExtension);
  T.Test('extension none', @TestExtensionNone);
  T.Test('change ext', @TestChangeExt);
  T.Test('is_absolute', @TestIsAbsolute);
  T.Test('normalize', @TestNormalize);
  T.Test('basename_ptr zero-copy', @TestBasenamePtr);
  T.Test('extension_ptr zero-copy', @TestExtensionPtr);
  T.Test('join absolute child', @TestJoinAbsoluteChild);
  T.Test('normalize relative ..', @TestNormalizeRelativeDotDot);
  T.Test('dirname root', @TestDirnameRoot);
  T.Test('resolve absolute', @TestResolveAbsolute);
  T.Test('resolve relative', @TestResolveRelative);
  T.Test('resolve non-existent', @TestResolveNonExistent);
  T.Test('join3', @TestJoin3);
  T.Test('is_root', @TestIsRoot);
  T.Test('ensure_sep', @TestEnsureSep);
  T.Test('trim_sep', @TestTrimSep);
  T.Test('same_file_name', @TestSameFileName);
  T.Test('relative', @TestRelative);
  T.Test('join nil base', @TestJoinNilBase);
  T.Test('join nil child', @TestJoinNilChild);
  T.Test('dirname nil path', @TestDirnameNilPath);
  T.Test('basename nil path', @TestBasenameNilPath);
  T.Test('normalize empty', @TestNormalizeEmpty);
  T.Test('small buffer truncation', @TestSmallBufferTruncation);
  T.Test('join empty child', @TestJoinEmptyChild);
  T.Test('extension_ptr nil path', @TestExtensionPtrPtr);
  if not T.Run then Halt(1);
end.
