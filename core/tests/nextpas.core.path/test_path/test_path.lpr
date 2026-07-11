program test_path;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.fs.util,
  nextpas.core.fs.path,
  nextpas.core.path;

var
  T: TTestSuite;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
begin
  LSourcePath := FsPathAbs('../../../' + ARelativePath);
  Check(FsExists(LSourcePath), 'source exists: ' + ARelativePath);
  Result := FsReadFileText(LSourcePath);
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

procedure TestPathIsRelative;
begin
  Check(PathIsRelative('relative/path') = True, 'relative');
  Check(PathIsRelative('/home/user') = False, 'absolute');
  Check(PathIsRelative('') = True, 'empty is relative');
  Check(PathIsRelative('.') = True, 'dot is relative');
  Check(PathIsRelative('..') = True, 'dotdot is relative');
end;

procedure TestPathNormalize;
begin
  Check(PathNormalize('/home/user/../docs') = '/home/docs', 'normalize ..');
  Check(PathNormalize('/home/./user') = '/home/user', 'normalize .');
  Check(PathNormalize('') = '', 'normalize empty');
end;

procedure TestPathNormalizeEdgeCases;
begin
  { Multiple consecutive slashes }
  Check(PathNormalize('//home///user') = '/home/user', 'normalize multiple slashes');
  { Trailing slash removed (except root) }
  Check(PathNormalize('/home/user/') = '/home/user', 'normalize trailing slash');
  Check(PathNormalize('/') = '/', 'normalize root preserved');
  { .. at root — cannot go above root }
  Check(PathNormalize('/..') = '/', 'normalize .. at root');
  Check(PathNormalize('/../..') = '/', 'normalize ../.. at root');
  { . at various positions }
  Check(PathNormalize('./foo') = 'foo', 'normalize leading dot');
  Check(PathNormalize('foo/.') = 'foo', 'normalize trailing dot');
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

procedure TestPathMatchStar;
begin
  Check(PathMatch('*.txt', 'hello.txt'), '*.txt matches hello.txt');
  Check(not PathMatch('*.txt', 'hello.log'), '*.txt does not match hello.log');
  Check(PathMatch('*', 'anything'), '* matches anything');
  Check(not PathMatch('*', 'path/thing'), '* does not match path/thing');
  Check(PathMatch('*.pas', 'test.pas'), '*.pas matches test.pas');
end;

procedure TestPathMatchQuestion;
begin
  Check(PathMatch('?.txt', 'a.txt'), '? matches single char');
  Check(not PathMatch('?.txt', 'ab.txt'), '? does not match two chars');
  Check(not PathMatch('?.txt', '.txt'), '? does not match empty');
  Check(PathMatch('foo?.log', 'foo1.log'), 'foo? matches foo1');
  Check(not PathMatch('foo?.log', 'foo12.log'), 'foo? does not match foo12');
end;

procedure TestPathMatchCharClass;
begin
  Check(PathMatch('[abc]', 'a'), '[abc] matches a');
  Check(PathMatch('[abc]', 'b'), '[abc] matches b');
  Check(not PathMatch('[abc]', 'd'), '[abc] does not match d');
  Check(PathMatch('[a-z]', 'm'), '[a-z] matches m');
  Check(not PathMatch('[a-z]', 'M'), '[a-z] does not match M');
  Check(PathMatch('[!abc]', 'd'), '[!abc] matches d');
  Check(not PathMatch('[!abc]', 'a'), '[!abc] does not match a');
end;

procedure TestPathMatchEscape;
begin
  Check(PathMatch('\*.txt', '*.txt'), 'escaped star matches literally');
  Check(not PathMatch('\*.txt', 'hello.txt'), 'escaped star does not wildcard');
end;

procedure TestPathMatchCombined;
begin
  Check(PathMatch('test_[0-9].pas', 'test_5.pas'), 'combined pattern matches');
  Check(not PathMatch('test_[0-9].pas', 'test_ab.pas'), 'combined pattern rejects');
  Check(PathMatch('**', 'anything'), 'double star matches anything');
end;

procedure TestPathMatchEdgeCases;
begin
  Check(PathMatch('', ''), 'empty matches empty');
  Check(not PathMatch('', 'x'), 'empty does not match non-empty');
  Check(not PathMatch('x', ''), 'non-empty does not match empty');
  Check(PathMatch('abc', 'abc'), 'literal matches literal');
  Check(not PathMatch('abc', 'abcd'), 'literal does not match longer');
end;

procedure TestPathJoinN;
begin
  Check(PathJoinN(['/home', 'user', 'docs', 'file.txt']) = '/home/user/docs/file.txt',
    'joinN 4 parts');
  Check(PathJoinN(['/a']) = '/a', 'joinN 1 part');
  Check(PathJoinN(['', 'b']) = 'b', 'joinN empty + part');
  Check(PathJoinN(['/a', '', 'c']) = '/a/c', 'joinN middle empty');
  Check(PathJoinN(['/a', 'b', 'c', 'd', 'e']) = '/a/b/c/d/e',
    'joinN 5 parts');
end;

procedure TestPathClean;
begin
  Check(PathClean('/home/user/../user/./docs') = '/home/user/docs',
    'clean resolves dot-dot');
  Check(PathClean('/a//b///c') = '/a/b/c', 'clean removes duplicate seps');
  Check(PathClean('') = '', 'clean empty');
  Check(PathClean('.') = '.', 'clean dot');
  Check(PathClean('/') = '/', 'clean root');
  Check(PathClean('/../..') = '/', 'clean above root');
end;

begin
  T := TTestSuite.Create('nextpas.core.path');
  T.Test('PathJoin', @TestPathJoin);
  T.Test('PathJoin long result', @TestPathJoinLongResult);
  T.Test('PathJoin3', @TestPathJoin3);
  T.Test('PathJoin3 long intermediate', @TestPathJoin3LongIntermediate);
  T.Test('PathDir', @TestPathDir);
  T.Test('PathDir long result', @TestPathDirLongResult);
  T.Test('PathBase', @TestPathBase);
  T.Test('PathSplit', @TestPathSplit);
  T.Test('PathBase long result', @TestPathBaseLongResult);
  T.Test('PathExt', @TestPathExt);
  T.Test('PathExt long result', @TestPathExtLongResult);
  T.Test('PathChangeExt', @TestPathChangeExt);
  T.Test('PathChangeExt long result', @TestPathChangeExtLongResult);
  T.Test('PathIsAbsolute', @TestPathIsAbsolute);
  T.Test('PathIsRelative', @TestPathIsRelative);
  T.Test('PathNormalize', @TestPathNormalize);
  T.Test('PathNormalizeEdgeCases', @TestPathNormalizeEdgeCases);
  T.Test('PathNormalize long result', @TestPathNormalizeLongResult);
  T.Test('PathRelative', @TestPathRelative);
  T.Test('PathRelative long result', @TestPathRelativeLongResult);
  T.Test('PathHasExt', @TestPathHasExt);
  T.Test('PathWithoutExt', @TestPathWithoutExt);
  T.Test('SysUtils compat', @TestSysUtilsCompat);
  T.Test('ExtractFilePath source contract', @TestExtractFilePathSourceContract);
  T.Test('PathJoin fallback source contract', @TestPathJoinFallbackSourceContract);
  T.Test('Path delegates platform root contract', @TestPathDelegatesPlatformRootContract);
  T.Test('PathMatch star', @TestPathMatchStar);
  T.Test('PathMatch question', @TestPathMatchQuestion);
  T.Test('PathMatch char class', @TestPathMatchCharClass);
  T.Test('PathMatch escape', @TestPathMatchEscape);
  T.Test('PathMatch combined', @TestPathMatchCombined);
  T.Test('PathMatch edge cases', @TestPathMatchEdgeCases);
  T.Test('PathJoinN', @TestPathJoinN);
  T.Test('PathClean', @TestPathClean);
{$IFDEF NEXTPAS_WINDOWS}
  T.Test('Windows root wrapper contract', @TestWindowsRootWrapperContract);
{$ENDIF}
  if not T.Run then Halt(1);
end.
