program test_path;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  nextpas.core.testing,
  nextpas.core.path;

var
  T: TTestRunner;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
  LLines: TStringList;
begin
  LSourcePath := ExpandFileName('../../../' + ARelativePath);
  Check(FileExists(LSourcePath), 'source exists: ' + ARelativePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LSourcePath);
    Result := LLines.Text;
  finally
    LLines.Free;
  end;
end;

function ExtractFunctionBody(const ASource, AStartToken, ANextToken: string): string;
var
  LStart, LNext: Integer;
begin
  Result := '';
  LStart := Pos(AStartToken, ASource);
  if LStart = 0 then
    Exit;
  LNext := Pos(ANextToken, Copy(ASource, LStart + Length(AStartToken),
    Length(ASource)));
  if LNext = 0 then
    Exit(Copy(ASource, LStart, Length(ASource)));
  Result := Copy(ASource, LStart, Length(AStartToken) + LNext - 1);
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage);
end;

procedure CheckAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) = 0, AMessage);
end;

procedure TestPathJoin;
begin
  Check(PathJoin('/home', 'user') = '/home/user', 'join basic');
  Check(PathJoin('/home/', 'user') = '/home/user', 'join trailing sep');
  Check(PathJoin('', 'file.txt') = 'file.txt', 'join empty base');
  Check(PathJoin('/dir', '') = '/dir', 'join empty child');
  Check(PathJoin('', '') = '', 'join both empty');
end;

procedure TestPathJoinLongResult;
var
  LBase: string;
  LChild: string;
  LExpected: string;
  LResult: string;
begin
  LBase := '/' + StringOfChar('a', 4090);
  LChild := StringOfChar('b', 128);
  LExpected := LBase + '/' + LChild;
  LResult := PathJoin(LBase, LChild);
  CheckEqual(Int64(Length(LExpected)), Int64(Length(LResult)), 'long join preserves length');
  CheckEqual(LExpected, LResult, 'long join preserves content');
end;

procedure TestPathJoin3;
begin
  Check(PathJoin3('/home', 'user', 'docs') = '/home/user/docs', 'join3 basic');
end;

procedure TestPathJoin3LongIntermediate;
var
  LFirst: string;
  LExpected: string;
begin
  LFirst := '/' + StringOfChar('j', 4090);
  LExpected := LFirst + '/child/file.txt';
  CheckEqual(LExpected, PathJoin3(LFirst, 'child', 'file.txt'), 'long join3 preserves content');
end;

procedure TestPathDir;
begin
  Check(PathDir('/home/user/file.txt') = '/home/user', 'dir with file');
  Check(PathDir('file.txt') = '', 'dir no path');
  Check(PathDir('/home/user/') = '/home/user', 'dir trailing sep');
  Check(PathDir('') = '', 'dir empty');
end;

procedure TestPathDirLongResult;
var
  LDir: string;
  LPath: string;
begin
  LDir := '/' + StringOfChar('d', 4090);
  LPath := LDir + '/file.txt';
  CheckEqual(LDir, PathDir(LPath), 'long dir preserves content');
end;

procedure TestPathBase;
begin
  Check(PathBase('/home/user/file.txt') = 'file.txt', 'base with path');
  Check(PathBase('file.txt') = 'file.txt', 'base no path');
  Check(PathBase('/home/user/') = 'user', 'base trailing sep = last component');
  Check(PathBase('') = '', 'base empty');
end;

procedure TestPathSplit;
var
  LDir: string;
  LBase: string;
begin
  PathSplit('/home/user/file.txt', LDir, LBase);
  CheckEqual('/home/user', LDir, 'split dir with file');
  CheckEqual('file.txt', LBase, 'split base with file');

  PathSplit('file.txt', LDir, LBase);
  CheckEqual('', LDir, 'split no path dir');
  CheckEqual('file.txt', LBase, 'split no path base');

  PathSplit('/home/user/', LDir, LBase);
  CheckEqual('/home/user', LDir, 'split trailing sep dir');
  CheckEqual('user', LBase, 'split trailing sep base');

  PathSplit('', LDir, LBase);
  CheckEqual('', LDir, 'split empty dir');
  CheckEqual('', LBase, 'split empty base');
end;

procedure TestPathBaseLongResult;
var
  LBase: string;
  LPath: string;
begin
  LBase := StringOfChar('b', 4100);
  LPath := '/tmp/' + LBase;
  CheckEqual(LBase, PathBase(LPath), 'long base preserves content');
end;

procedure TestPathExt;
begin
  Check(PathExt('/home/file.txt') = '.txt', 'ext basic');
  Check(PathExt('archive.tar.gz') = '.gz', 'ext double');
  Check(PathExt('/tmp/file.txt/') = '.txt', 'ext ignores trailing sep');
  Check(PathExt('noext') = '', 'ext none');
  Check(PathExt('.hidden') = '', 'ext dotfile');
  Check(PathExt('') = '', 'ext empty');
end;

procedure TestPathExtLongResult;
var
  LExt: string;
  LPath: string;
begin
  LExt := '.' + StringOfChar('x', 4096);
  LPath := 'file' + LExt;
  CheckEqual(LExt, PathExt(LPath), 'long extension preserves content');
end;

procedure TestPathChangeExt;
begin
  Check(PathChangeExt('/home/file.txt', '.md') = '/home/file.md', 'change ext');
  Check(PathChangeExt('file.txt', '.pas') = 'file.pas', 'change ext no path');
  Check(PathChangeExt('noext', '.txt') = 'noext.txt', 'add ext');
  Check(PathChangeExt('/tmp/file.txt/', '.md') = '/tmp/file.md',
    'change ext ignores trailing sep');
  Check(PathChangeExt('/tmp/noext/', '.txt') = '/tmp/noext.txt',
    'change ext adds before trailing sep');
end;

procedure TestPathChangeExtLongResult;
var
  LPath: string;
  LExpected: string;
begin
  LPath := StringOfChar('c', 4096) + '.txt';
  LExpected := StringOfChar('c', 4096) + '.pas';
  CheckEqual(LExpected, PathChangeExt(LPath, '.pas'), 'long change ext preserves content');
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

procedure TestPathNormalizeLongResult;
var
  LSegment: string;
  LPath: string;
  LExpected: string;
begin
  LSegment := StringOfChar('n', 4096);
  LPath := '/root/./' + LSegment + '/../' + LSegment + '/file.txt';
  LExpected := '/root/' + LSegment + '/file.txt';
  CheckEqual(LExpected, PathNormalize(LPath), 'long normalize preserves content');
end;

procedure TestPathRelative;
begin
  CheckEqual('c/d', PathRelative('/a/b', '/a/b/c/d'),
    'relative descendant');
  CheckEqual('../../d/e', PathRelative('/a/b/c', '/a/d/e'),
    'relative sibling branch');
  CheckEqual('.', PathRelative('/a/b', '/a/b'), 'relative same path');
  CheckEqual('c', PathRelative('a/b', 'a/b/c'), 'relative paths supported');
end;

procedure TestPathRelativeLongResult;
var
  LSegment: string;
  LExpected: string;
begin
  LSegment := StringOfChar('r', 4096);
  LExpected := '../target/' + LSegment + '/file.txt';
  CheckEqual(LExpected, PathRelative('/root/base',
    '/root/target/' + LSegment + '/file.txt'), 'long relative preserves content');
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

procedure TestExtractFilePathSourceContract;
var
  LSource, LImpl, LBody: string;
  LImplPos: Integer;
begin
  LSource := LoadSourceText('src/nextpas.core.path.pas');
  LImplPos := Pos('implementation', LSource);
  Check(LImplPos > 0, 'path unit has implementation section');
  LImpl := Copy(LSource, LImplPos, Length(LSource));
  LBody := ExtractFunctionBody(LImpl,
    'function ExtractFilePath(const AFileName: string): string;',
    'function ExtractFileName');

  CheckContains(LBody, 'PLATFORM_PATH_SEP',
    'ExtractFilePath appends platform separator');
  CheckAbsent(LBody, 'Result := LDir + ''/''',
    'ExtractFilePath does not hard-code Unix separator');
end;

procedure TestPathJoinFallbackSourceContract;
var
  LSource, LImpl, LBody: string;
  LImplPos: Integer;
begin
  LSource := LoadSourceText('src/nextpas.core.path.pas');
  LImplPos := Pos('implementation', LSource);
  Check(LImplPos > 0, 'path unit has implementation section');
  LImpl := Copy(LSource, LImplPos, Length(LSource));
  LBody := ExtractFunctionBody(LImpl,
    'function PathJoin(const ABase, AChild: string): string;',
    'function PathJoin3');

  CheckContains(LBody, 'FsPathJoin',
    'PathJoin delegates to FsPathJoin');
  CheckAbsent(LBody, 'platform_path_join',
    'PathJoin does not call platform_path_join directly');
end;

procedure TestPathDelegatesPlatformRootContract;
var
  LSource, LImpl: string;
  LImplPos: Integer;
begin
  LSource := LoadSourceText('src/nextpas.core.path.pas');
  LImplPos := Pos('implementation', LSource);
  Check(LImplPos > 0, 'path unit has implementation section');
  LImpl := Copy(LSource, LImplPos, Length(LSource));

  CheckContains(LImpl, 'FsPathJoin',
    'PathJoin delegates to fs.path');
  CheckContains(LImpl, 'FsPathDir',
    'PathDir delegates to fs.path');
  CheckContains(LImpl, 'FsPathIsAbs',
    'PathIsAbsolute delegates to fs.path');
  CheckContains(LImpl, 'FsPathClean',
    'PathNormalize delegates to fs.path');
end;

{$IFDEF NEXTPAS_WINDOWS}
procedure TestWindowsRootWrapperContract;
begin
  Check(PathIsAbsolute('C:\tools'), 'drive absolute is absolute');
  Check(PathIsAbsolute('\\server\share'), 'UNC share is absolute');
  Check(not PathIsAbsolute('C:tools'), 'drive-relative path is not absolute');
  Check(not PathIsAbsolute('\tools'), 'rooted-relative path is not absolute');
  Check(PathDir('C:\tools') = 'C:\', 'PathDir keeps drive root');
  Check(PathDir('\\server\share\file.txt') = '\\server\share',
    'PathDir keeps UNC share root');
  Check(PathNormalize('C:\tools\..\bin') = 'C:\bin',
    'PathNormalize keeps drive root');
  Check(PathNormalize('C:tools\..\bin') = 'C:bin',
    'PathNormalize keeps drive-relative volume');
  Check(PathNormalize('\tools\..\bin') = '\bin',
    'PathNormalize keeps rooted-relative root');
  Check(PathJoin('C:\base', '\child') = 'C:\base\child',
    'PathJoin does not treat rooted-relative child as absolute');
end;
{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.path');
  T.Run('PathJoin', @TestPathJoin);
  T.Run('PathJoin long result', @TestPathJoinLongResult);
  T.Run('PathJoin3', @TestPathJoin3);
  T.Run('PathJoin3 long intermediate', @TestPathJoin3LongIntermediate);
  T.Run('PathDir', @TestPathDir);
  T.Run('PathDir long result', @TestPathDirLongResult);
  T.Run('PathBase', @TestPathBase);
  T.Run('PathSplit', @TestPathSplit);
  T.Run('PathBase long result', @TestPathBaseLongResult);
  T.Run('PathExt', @TestPathExt);
  T.Run('PathExt long result', @TestPathExtLongResult);
  T.Run('PathChangeExt', @TestPathChangeExt);
  T.Run('PathChangeExt long result', @TestPathChangeExtLongResult);
  T.Run('PathIsAbsolute', @TestPathIsAbsolute);
  T.Run('PathNormalize', @TestPathNormalize);
  T.Run('PathNormalize long result', @TestPathNormalizeLongResult);
  T.Run('PathRelative', @TestPathRelative);
  T.Run('PathRelative long result', @TestPathRelativeLongResult);
  T.Run('PathHasExt', @TestPathHasExt);
  T.Run('PathWithoutExt', @TestPathWithoutExt);
  T.Run('SysUtils compat', @TestSysUtilsCompat);
  T.Run('ExtractFilePath source contract', @TestExtractFilePathSourceContract);
  T.Run('PathJoin fallback source contract', @TestPathJoinFallbackSourceContract);
  T.Run('Path delegates platform root contract', @TestPathDelegatesPlatformRootContract);
{$IFDEF NEXTPAS_WINDOWS}
  T.Run('Windows root wrapper contract', @TestWindowsRootWrapperContract);
{$ENDIF}
  T.Summary;
end.
