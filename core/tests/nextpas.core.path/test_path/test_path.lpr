program test_path;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.path;

var
  T: TTestRunner;

procedure TestPathJoin;
begin
  Check(PathJoin('/home', 'user') = '/home/user', 'join basic');
  Check(PathJoin('/home/', 'user') = '/home/user', 'join trailing sep');
  Check(PathJoin('', 'file.txt') = 'file.txt', 'join empty base');
  Check(PathJoin('/dir', '') = '/dir', 'join empty child');
  Check(PathJoin('', '') = '', 'join both empty');
end;

procedure TestPathJoin3;
begin
  Check(PathJoin3('/home', 'user', 'docs') = '/home/user/docs', 'join3 basic');
end;

procedure TestPathDir;
begin
  Check(PathDir('/home/user/file.txt') = '/home/user', 'dir with file');
  Check(PathDir('file.txt') = '', 'dir no path');
  Check(PathDir('/home/user/') = '/home/user', 'dir trailing sep');
  Check(PathDir('') = '', 'dir empty');
end;

procedure TestPathBase;
begin
  Check(PathBase('/home/user/file.txt') = 'file.txt', 'base with path');
  Check(PathBase('file.txt') = 'file.txt', 'base no path');
  Check(PathBase('/home/user/') = 'user', 'base trailing sep = last component');
  Check(PathBase('') = '', 'base empty');
end;

procedure TestPathExt;
begin
  Check(PathExt('/home/file.txt') = '.txt', 'ext basic');
  Check(PathExt('archive.tar.gz') = '.gz', 'ext double');
  Check(PathExt('noext') = '', 'ext none');
  Check(PathExt('.hidden') = '', 'ext dotfile');
  Check(PathExt('') = '', 'ext empty');
end;

procedure TestPathChangeExt;
begin
  Check(PathChangeExt('/home/file.txt', '.md') = '/home/file.md', 'change ext');
  Check(PathChangeExt('file.txt', '.pas') = 'file.pas', 'change ext no path');
  Check(PathChangeExt('noext', '.txt') = 'noext.txt', 'add ext');
end;

procedure TestPathIsAbsolute;
begin
  Check(PathIsAbsolute('/home/user') = True, 'absolute unix');
  Check(PathIsAbsolute('relative/path') = False, 'relative');
  Check(PathIsAbsolute('') = False, 'empty');
end;

procedure TestPathNormalize;
begin
  Check(PathNormalize('/home/user/../docs') = '/home/docs', 'normalize ..');
  Check(PathNormalize('/home/./user') = '/home/user', 'normalize .');
  Check(PathNormalize('') = '', 'normalize empty');
end;

procedure TestPathHasExt;
begin
  Check(PathHasExt('file.txt') = True, 'has ext');
  Check(PathHasExt('noext') = False, 'no ext');
end;

procedure TestPathWithoutExt;
begin
  Check(PathWithoutExt('file.txt') = 'file', 'without ext');
  Check(PathWithoutExt('/dir/file.pas') = '/dir/file', 'without ext path');
end;

procedure TestSysUtilsCompat;
begin
  Check(ExtractFilePath('/home/user/file.txt') = '/home/user/', 'ExtractFilePath');
  Check(ExtractFileName('/home/user/file.txt') = 'file.txt', 'ExtractFileName');
  Check(ExtractFileExt('/home/user/file.txt') = '.txt', 'ExtractFileExt');
  Check(ChangeFileExt('/home/file.txt', '.md') = '/home/file.md', 'ChangeFileExt');
  Check(ExtractFilePath('file.txt') = '', 'ExtractFilePath no dir');
end;

begin
  T := TTestRunner.Create('nextpas.core.path');
  T.Run('PathJoin', @TestPathJoin);
  T.Run('PathJoin3', @TestPathJoin3);
  T.Run('PathDir', @TestPathDir);
  T.Run('PathBase', @TestPathBase);
  T.Run('PathExt', @TestPathExt);
  T.Run('PathChangeExt', @TestPathChangeExt);
  T.Run('PathIsAbsolute', @TestPathIsAbsolute);
  T.Run('PathNormalize', @TestPathNormalize);
  T.Run('PathHasExt', @TestPathHasExt);
  T.Run('PathWithoutExt', @TestPathWithoutExt);
  T.Run('SysUtils compat', @TestSysUtilsCompat);
  T.Summary;
end.
