program test_path;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.fs.util,
  nextpas.core.fs.path,
  nextpas.core.fs.dir,
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

{$I ../../fpc_rtl_uses_scan.inc}

procedure AssertSourceNoBareFpcRtlUses(const ALabel, ASource: string);
var
  LHit: string;
  LOk: Boolean;
  LMsg: string;
begin
  LOk := not FindBareFpcRtlInUses(ASource, LHit);
  LMsg := ALabel + ' — no bare FPC RTL in uses';
  if not LOk then
    LMsg := LMsg + ' (hit: ' + LHit + ')';
  Check(LOk, LMsg);
end;

procedure TestPathOwnedSourcesNoFpcRtl;
begin
  AssertSourceNoBareFpcRtlUses('path src',
    LoadSourceText('src/nextpas.core.path.pas'));
end;

procedure TestPathTestSuiteNoFpcRtl;
begin
  AssertSourceNoBareFpcRtlUses('path test',
    LoadSourceText('tests/nextpas.core.path/test_path/test_path.lpr'));
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
  Check(PathDir('./x') = '.', 'dir ./x keeps relative dot');
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

  PathSplit('./x', LDir, LBase);
  CheckEqual('.', LDir, 'split ./x keeps relative dir');
  CheckEqual('x', LBase, 'split ./x base');

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
  Check(PathIsAbs('/tmp') = True, 'PathIsAbs alias absolute');
  Check(PathIsAbs('rel') = False, 'PathIsAbs alias relative');
  Check(PathIsAbs('/x') = PathIsAbsolute('/x'), 'PathIsAbs equals PathIsAbsolute');
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

procedure TestPathToFromSlash;
begin
  CheckEqual('a/b/c', PathToSlash('a\b\c'), 'ToSlash backslash');
  CheckEqual('a/b', PathToSlash('a/b'), 'ToSlash already slash');
  CheckEqual('', PathToSlash(''), 'ToSlash empty');
  {$IFDEF NEXTPAS_WINDOWS}
  CheckEqual('a\b\c', PathFromSlash('a/b/c'), 'FromSlash windows');
  {$ELSE}
  CheckEqual('a/b/c', PathFromSlash('a/b/c'), 'FromSlash unix identity');
  {$ENDIF}
end;

procedure TestPathSplitList;
var
  L: TStringArray;
begin
  L := PathSplitList('');
  CheckEqual(Int64(0), Int64(Length(L)), 'empty list');
  L := PathSplitList('/bin' + PathListSeparator + '/usr/bin');
  CheckEqual(Int64(2), Int64(Length(L)), 'two entries');
  CheckEqual('/bin', L[0], 'first');
  CheckEqual('/usr/bin', L[1], 'second');
  L := PathSplitList(PathListSeparator + 'a' + PathListSeparator);
  CheckEqual(Int64(3), Int64(Length(L)), 'leading trailing empty');
  CheckEqual('', L[0], 'leading empty');
  CheckEqual('a', L[1], 'middle');
  CheckEqual('', L[2], 'trailing empty');
end;

procedure TestPathVolumeAndStem;
begin
  CheckEqual('', PathVolume('/home/x'), 'unix volume empty');
  CheckEqual('archive.tar', PathFileStem('archive.tar.gz'), 'stem multi ext last only');
  CheckEqual('file', PathFileStem('file.txt'), 'stem simple');
  CheckEqual('file', PathFileStem('file'), 'stem no ext');
  CheckEqual('', PathFileStem(''), 'stem empty');
  CheckEqual('.hidden', PathFileStem('.hidden'), 'stem dotfile no ext strip if no PathExt');
end;

procedure TestPathStripPrefix;
begin
  CheckEqual('b/c', PathStripPrefix('/a/b/c', '/a'), 'strip /a');
  CheckEqual('.', PathStripPrefix('/a', '/a'), 'equal -> dot');
  CheckEqual('', PathStripPrefix('/ab/c', '/a'), 'not a path prefix');
  CheckEqual('x', PathStripPrefix('/a/x', '/a/'), 'prefix with slash');
  CheckEqual('', PathStripPrefix('/other', '/a'), 'no match');
end;

procedure TestPathAbsFollowsSymlink;
var
  LDir, LTarget, LLink, LAbs: string;
begin
  LDir := FsTempDir('', 'pathabs*');
  try
    LTarget := PathJoin(LDir, 'real.txt');
    LLink := PathJoin(LDir, 'link.txt');
    FsWriteFileText(LTarget, 'x');
    FsSymlink(LTarget, LLink);
    LAbs := ExpandFileName(LLink);
    Check(PathIsAbs(LAbs), 'abs is absolute');
    { realpath should land on the real file path, not the link path }
    Check(Pos('link.txt', LAbs) = 0, 'PathAbs resolves through symlink');
    Check(Pos('real.txt', LAbs) > 0, 'PathAbs points at real target name');
  finally
    FsRemoveAll(LDir);
  end;
end;

procedure TestPathCleanGoTable;
begin
  CheckEqual('a/b', PathClean('a/./b'), 'clean a/./b');
  CheckEqual('b', PathClean('a/../b'), 'clean a/../b');
  CheckEqual('a/b', PathClean('a//b'), 'clean a//b');
  CheckEqual('.', PathClean('a/..'), 'clean a/..');
  CheckEqual('.', PathClean('./.'), 'clean ./.');
  CheckEqual('/', PathClean('/a/../'), 'clean /a/../');
  CheckEqual('/a/b', PathClean('/a/./b/'), 'clean /a/./b/');
  CheckEqual('a', PathClean('./a'), 'clean ./a');
end;

procedure TestPathFileStemEdges;
begin
  CheckEqual('.hidden', PathFileStem('.hidden'), 'stem dotfile');
  CheckEqual('a', PathFileStem('a.'), 'stem trailing dot');
  CheckEqual('name', PathFileStem('/x/name.tar'), 'stem with dir');
end;

procedure TestPathRelativeTable;
begin
  CheckEqual('b', PathRelative('/a', '/a/b'), 'rel child');
  CheckEqual('..', PathRelative('/a/b', '/a'), 'rel parent');
  CheckEqual('.', PathRelative('/a', '/a'), 'rel same');
end;

procedure TestPathCleanGoTableExtra;
begin
  CheckEqual('a/b', PathClean('a/b/.'), 'clean a/b/.');
  CheckEqual('a', PathClean('a/b/..'), 'clean a/b/..');
  CheckEqual('..', PathClean('..'), 'clean ..');
  CheckEqual('../..', PathClean('../..'), 'clean ../..');
  CheckEqual('/a', PathClean('/a/'), 'clean /a/');
  CheckEqual('a/b', PathClean('a//b//'), 'clean a//b//');
  CheckEqual('', PathClean(''), 'clean empty string');
end;

procedure TestPathCleanDotsAndSeps;
begin
  CheckEqual('/a/b', PathClean('//a//b//'), 'clean double root seps');
  CheckEqual('b', PathClean('./a/../b'), 'clean ./a/../b');
  CheckEqual('a', PathClean('a/././.'), 'clean a/././.');
  CheckEqual('/', PathClean('/./'), 'clean /./');
  CheckEqual('..', PathClean('a/../..'), 'clean a/../..');
end;

procedure TestPathJoinEdges;
begin
  Checkequal('/a/b', PathJoin('/a', 'b'), 'join abs+rel');
  CheckEqual('/b', PathJoin('/a', '/b'), 'join abs+abs');
  CheckEqual('a/b', PathJoin('a', 'b'), 'join rel+rel');
  CheckEqual('/a', PathJoin('/a', ''), 'join trailing empty');
  CheckEqual('b', PathJoin('', 'b'), 'join leading empty');
end;

procedure TestPathDirBaseExtTable;
begin
  CheckEqual('/a', PathDir('/a/b'), 'dir /a/b');
  CheckEqual('', PathDir('file.txt'), 'dir bare name empty');
  CheckEqual('.', PathDir('./x'), 'dir ./x keeps dot');
  CheckEqual('b', PathBase('/a/b'), 'base /a/b');
  CheckEqual('file.txt', PathBase('file.txt'), 'base bare');
  CheckEqual('.txt', PathExt('file.txt'), 'ext .txt');
  CheckEqual('', PathExt('file'), 'ext none');
  CheckEqual('.gz', PathExt('a.tar.gz'), 'ext last');
end;

procedure TestPathIsAbsRelTable;
begin
  Check(PathIsAbsolute('/'), 'abs root');
  Check(PathIsAbsolute('/a'), 'abs /a');
  Check(not PathIsAbsolute('a'), 'not abs a');
  Check(not PathIsAbsolute(''), 'not abs empty');
  Check(PathIsRelative('a/b'), 'rel a/b');
  Check(not PathIsRelative('/a'), 'not rel /a');
end;

procedure TestPathChangeWithoutExtTable;
begin
  CheckEqual('a.md', PathChangeExt('a.txt', '.md'), 'change ext');
  CheckEqual('a', PathWithoutExt('a.txt'), 'without ext');
  CheckEqual('a.tar', PathWithoutExt('a.tar.gz'), 'without last ext');
  CheckEqual('.hidden', PathWithoutExt('.hidden'), 'without on dotfile');
end;

procedure TestPathStripPrefixExtra;
begin
  CheckEqual('', PathStripPrefix('/a', '/b'), 'strip mismatch');
  CheckEqual('c', PathStripPrefix('/a/b/c', '/a/b'), 'strip nested');
  CheckEqual('', PathStripPrefix('', '/a'), 'strip empty path');
  CheckEqual('/a/b', PathStripPrefix('/a/b', ''), 'strip empty prefix');
end;

procedure TestPathSplitListEdges;
var
  L: TStringArray;
begin
  L := PathSplitList('only');
  CheckEqual(Int64(1), Int64(Length(L)), 'split one');
  CheckEqual('only', L[0], 'split only');
  L := PathSplitList(PathListSeparator);
  CheckEqual(Int64(2), Int64(Length(L)), 'split single sep');
  CheckEqual('', L[0], 'split sep lead empty');
  CheckEqual('', L[1], 'split sep trail empty');
end;

procedure TestPathVolumeStemExtra;
begin
  CheckEqual('', PathVolume('C:relative'), 'unix volume of windows-like');
  CheckEqual('', PathVolume(''), 'volume empty');
  CheckEqual('file', PathFileStem('dir/file.txt'), 'stem with dir');
  CheckEqual('a', PathFileStem('a.'), 'stem trailing dot again');
  CheckEqual('.bashrc', PathFileStem('.bashrc'), 'stem bashrc');
end;

procedure TestPathMatchTableExtra;
begin
  Check(PathMatch('*.pas', 'a.pas'), 'match *.pas');
  Check(not PathMatch('*.pas', 'a.pp'), 'no match *.pas');
  Check(PathMatch('a?c', 'abc'), 'match a?c');
  Check(not PathMatch('a?c', 'ac'), 'no match a?c short');
  Check(PathMatch('[ab]', 'a'), 'match class');
  Check(not PathMatch('[ab]', 'c'), 'no match class');
end;

procedure TestPathToSlashExtra;
begin
  CheckEqual('a/b/c', PathToSlash('a/b/c'), 'to slash already');
  CheckEqual('', PathToSlash(''), 'to slash empty');
  CheckEqual('x', PathToSlash('x'), 'to slash single');
end;

procedure TestPathListSeparatorConst;
begin
  Check(PathListSeparator <> '', 'list sep non-empty');
  {$IFDEF NEXTPAS_WINDOWS}
  CheckEqual(';', PathListSeparator, 'windows PATH sep');
  {$ELSE}
  Checkequal(':', PathListSeparator, 'unix PATH sep');
  {$ENDIF}
end;

procedure TestPathCleanGoTableR19;
begin
  CheckEqual('a/b/c', PathClean('a/b/c'), 'r19 clean plain');
  CheckEqual('a/b', PathClean('a//b'), 'r19 clean dbl');
  CheckEqual('a/b', PathClean('a/./b'), 'r19 clean dot');
  CheckEqual('b', PathClean('a/../b'), 'r19 clean up');
  CheckEqual('.', PathClean('a/b/../..'), 'r19 clean to dot');
  CheckEqual('/', PathClean('/a/..'), 'r19 clean root');
  CheckEqual('/a', PathClean('/a/.'), 'r19 clean /a/.');
  CheckEqual('..', PathClean('..'), 'r19 clean ..');
  CheckEqual('../a', PathClean('../a'), 'r19 clean ../a');
  CheckEqual('a', PathClean('./a/'), 'r19 clean ./a/');
  CheckEqual('/a/b', PathClean('//a//b//'), 'r19 clean multi root');
  CheckEqual('.', PathClean('.'), 'r19 clean .');
  CheckEqual('', PathClean(''), 'r19 clean empty');
  CheckEqual('a/b', PathClean('a/b/.'), 'r19 clean trail dot');
  CheckEqual('a', PathClean('a/b/..'), 'r19 clean trail up');
end;

procedure TestPathRelGoTableR19;
begin
  CheckEqual('b', PathRelative('/a', '/a/b'), 'r19 rel child');
  CheckEqual('b/c', PathRelative('/a', '/a/b/c'), 'r19 rel deep');
  CheckEqual('..', PathRelative('/a/b', '/a'), 'r19 rel parent');
  CheckEqual('../c', PathRelative('/a/b', '/a/c'), 'r19 rel sibling');
  CheckEqual('.', PathRelative('/a/b', '/a/b'), 'r19 rel same');
  CheckEqual('..', PathRelative('/a/b/c', '/a/b'), 'r19 rel up1');
end;

procedure TestPathJoinAbsChildR19;
begin
  CheckEqual('/b', PathJoin('/a', '/b'), 'r19 join abs child');
  CheckEqual('/a/b', PathJoin('/a', 'b'), 'r19 join rel child');
  CheckEqual('b', PathJoin('', 'b'), 'r19 join empty base');
  CheckEqual('/a', PathJoin('/a', ''), 'r19 join empty child');
end;

procedure TestPathMatchR19;
begin
  Check(PathMatch('*', 'x'), 'r19 match star');
  Check(PathMatch('*.txt', 'a.txt'), 'r19 match ext');
  Check(not PathMatch('*.txt', 'a.pas'), 'r19 match no ext');
  Check(PathMatch('a?b', 'axb'), 'r19 match q');
  Check(not PathMatch('a?b', 'ab'), 'r19 match q short');
  Check(PathMatch('[xyz]', 'y'), 'r19 match class');
  Check(not PathMatch('[xyz]', 'a'), 'r19 match class no');
end;

procedure TestPathExtStemR19;
begin
  CheckEqual('.pas', PathExt('u.pas'), 'r19 ext');
  CheckEqual('', PathExt('Makefile'), 'r19 ext none');
  CheckEqual('.gz', PathExt('x.tar.gz'), 'r19 ext last');
  CheckEqual('u', PathFileStem('u.pas'), 'r19 stem');
  CheckEqual('x.tar', PathFileStem('x.tar.gz'), 'r19 stem multi');
  CheckEqual('.gitignore', PathFileStem('.gitignore'), 'r19 stem gitignore');
end;

procedure TestPathStripSplitR19;
var
  L: TStringArray;
begin
  CheckEqual('c', PathStripPrefix('/a/b/c', '/a/b'), 'r19 strip');
  CheckEqual('.', PathStripPrefix('/a', '/a'), 'r19 strip eq');
  CheckEqual('', PathStripPrefix('/x', '/a'), 'r19 strip miss');
  L := PathSplitList('a' + PathListSeparator + 'b');
  CheckEqual(Int64(2), Int64(Length(L)), 'r19 split2');
  CheckEqual('a', L[0], 'r19 split a');
  CheckEqual('b', L[1], 'r19 split b');
end;

procedure TestPathIsAbsR19;
begin
  Check(PathIsAbsolute('/'), 'r19 abs /');
  Check(PathIsAbsolute('/tmp'), 'r19 abs /tmp');
  Check(not PathIsAbsolute('tmp'), 'r19 not abs');
  Check(PathIsRelative('tmp'), 'r19 rel tmp');
  Check(not PathIsRelative('/tmp'), 'r19 not rel');
end;

procedure TestPathDirBaseR19;
begin
  CheckEqual('/a', PathDir('/a/b'), 'r19 dir');
  CheckEqual('', PathDir('b'), 'r19 dir bare');
  CheckEqual('.', PathDir('./b'), 'r19 dir dot');
  CheckEqual('b', PathBase('/a/b'), 'r19 base');
  CheckEqual('b', PathBase('b'), 'r19 base bare');
end;


procedure TestPathCleanR19Extra;
begin
  CheckEqual('x/y', PathClean('x//y//'), 'r19e1');
  CheckEqual('x', PathClean('x/./.'), 'r19e2');
  CheckEqual('.', PathClean('x/..'), 'r19e3');
  CheckEqual('/x', PathClean('/x/'), 'r19e4');
  CheckEqual('..', PathClean('a/../..'), 'r19e5');
  CheckEqual('../..', PathClean('a/../../..'), 'r19e6');
  CheckEqual('a/b/c', PathClean('a/b/./c'), 'r19e7');
  CheckEqual('a/c', PathClean('a/b/../c'), 'r19e8');
  CheckEqual('/c', PathClean('/a/b/../../c'), 'r19e9');
  CheckEqual('a', PathClean('a/'), 'r19e10');
end;

procedure TestPathJoinR19Extra;
begin
  CheckEqual('/a/b/c', PathJoin3('/a', 'b', 'c'), 'r19j1');
  CheckEqual('/a/b', PathJoin('/a/', 'b'), 'r19j2');
  CheckEqual('a/b', PathJoin('a/', 'b'), 'r19j3');
  CheckEqual('/b', PathJoin('a', '/b'), 'r19j4');
  CheckEqual('', PathJoin('', ''), 'r19j5');
end;

procedure TestPathMatchR19Extra;
begin
  Check(PathMatch('**', 'a') or PathMatch('*', 'a'), 'r19m1');
  Check(PathMatch('file.pas', 'file.pas'), 'r19m2');
  Check(not PathMatch('file.pas', 'file.pp'), 'r19m3');
  Check(PathMatch('f*', 'file'), 'r19m4');
  Check(PathMatch('*le', 'file'), 'r19m5');
  Check(PathMatch('????', 'abcd'), 'r19m6');
  Check(not PathMatch('???', 'abcd'), 'r19m7');
end;

procedure TestPathVolumeListR19Extra;
begin
  CheckEqual('', PathVolume('/x'), 'r19v1');
  Check(PathListSeparator <> #0, 'r19v2');
  CheckEqual('a/b', PathToSlash('a/b'), 'r19v3');
  CheckEqual('', PathToSlash(''), 'r19v4');
  CheckEqual('stem', PathFileStem('stem.ext'), 'r19v5');
  CheckEqual('stem', PathWithoutExt('stem.ext'), 'r19v6');
  CheckEqual('stem.md', PathChangeExt('stem.ext', '.md'), 'r19v7');
end;

{ R22 hardening: Clean/Rel/Dir edges beyond R19 tables }
procedure TestPathCleanRelR22;
begin
  CheckEqual('', PathClean(''), 'r22 clean empty stays empty');
  CheckEqual('/', PathClean('/../..'), 'r22 clean above root');
  CheckEqual('/a', PathClean('/a/.'), 'r22 clean /a/.');
  CheckEqual('b', PathRelative('/a', '/a/b'), 'r22 rel child');
  CheckEqual('.', PathRelative('/a/b', '/a/b'), 'r22 rel same');
  CheckEqual('', PathStripPrefix('/x', '/y'), 'r22 strip non-prefix');
  CheckEqual('.', PathStripPrefix('/a', '/a'), 'r22 strip equal');
  CheckEqual('', PathDir('bare.txt'), 'r22 PathDir bare');
  CheckEqual('.', PathDir('./x'), 'r22 PathDir ./x');
end;

{ R31: Go filepath-style edge table (host-linux). }
procedure TestPathCleanJoinMatchR31;
begin
  CheckEqual('a/c', PathClean('a/b/../c'), 'r31 clean a/b/../c');
  CheckEqual('/c', PathClean('/a/b/../../c'), 'r31 clean abs up');
  CheckEqual('c', PathClean('a/b/../../c'), 'r31 clean rel up');
  CheckEqual('.', PathClean('a/b/../..'), 'r31 clean to dot');
  CheckEqual('a/b/c', PathJoin(PathJoin('a', 'b'), 'c'), 'r31 join nested');
  CheckEqual('/b', PathJoin('a', '/b'), 'r31 join abs child');
  CheckEqual('a', PathJoin('a', ''), 'r31 join empty child');
  Check(PathMatch('*.go', 'x.go'), 'r31 match *.go');
  Check(not PathMatch('*.go', 'x/y.go'), 'r31 * does not cross slash');
  Check(PathMatch('a?c', 'abc'), 'r31 match a?c');
  Check(not PathMatch('a?c', 'ac'), 'r31 ? needs one');
  Check(PathMatch('[a-c]', 'b'), 'r31 class range');
  Check(not PathMatch('[a-c]', 'd'), 'r31 class miss');
  Check(PathMatch('*.*', 'a.b'), 'r31 *.*');
  CheckEqual('../c/d', PathRelative('/a/b', '/a/c/d'), 'r31 rel sibling deep');
  CheckEqual('../../x', PathRelative('/a/b/c', '/a/x'), 'r31 rel up2');
  CheckEqual('sub', PathStripPrefix('/tmp/sub', '/tmp/'), 'r31 strip prefix slash');
  CheckEqual('a/b', PathToSlash('a\b'), 'r31 ToSlash single');
  CheckEqual('a/b/c', PathFromSlash('a/b/c'), 'r31 FromSlash unix');
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
  T.Test('PathClean Go table', @TestPathCleanGoTable);
  T.Test('PathFileStem edges', @TestPathFileStemEdges);
  T.Test('PathRelative table', @TestPathRelativeTable);
  T.Test('PathClean Go table extra', @TestPathCleanGoTableExtra);
  T.Test('PathClean dots and seps', @TestPathCleanDotsAndSeps);
  T.Test('PathJoin edges', @TestPathJoinEdges);
  T.Test('PathDir Base Ext table', @TestPathDirBaseExtTable);
  T.Test('PathIsAbs Rel table', @TestPathIsAbsRelTable);
  T.Test('PathChange WithoutExt table', @TestPathChangeWithoutExtTable);
  T.Test('PathStripPrefix extra', @TestPathStripPrefixExtra);
  T.Test('PathSplitList edges', @TestPathSplitListEdges);
  T.Test('PathVolume Stem extra', @TestPathVolumeStemExtra);
  T.Test('PathMatch table extra', @TestPathMatchTableExtra);
  T.Test('PathToSlash extra', @TestPathToSlashExtra);
  T.Test('PathListSeparator const', @TestPathListSeparatorConst);
  T.Test('PathToSlash/FromSlash', @TestPathToFromSlash);
  T.Test('PathSplitList', @TestPathSplitList);
  T.Test('PathVolume/FileStem', @TestPathVolumeAndStem);
  T.Test('PathStripPrefix', @TestPathStripPrefix);
  T.Test('PathAbs follows symlink', @TestPathAbsFollowsSymlink);
  T.Test('path owned sources no bare FPC RTL uses', @TestPathOwnedSourcesNoFpcRtl);
  T.Test('path test suite no bare FPC RTL uses', @TestPathTestSuiteNoFpcRtl);
{$IFDEF NEXTPAS_WINDOWS}
  T.Test('Windows root wrapper contract', @TestWindowsRootWrapperContract);
{$ENDIF}
  T.Test('PathClean Go table R19', @TestPathCleanGoTableR19);
  T.Test('PathRel Go table R19', @TestPathRelGoTableR19);
  T.Test('PathJoin abs child R19', @TestPathJoinAbsChildR19);
  T.Test('PathMatch R19', @TestPathMatchR19);
  T.Test('PathExt Stem R19', @TestPathExtStemR19);
  T.Test('PathStrip Split R19', @TestPathStripSplitR19);
  T.Test('PathIsAbs R19', @TestPathIsAbsR19);
  T.Test('PathDir Base R19', @TestPathDirBaseR19);
  T.Test('PathClean R19 extra', @TestPathCleanR19Extra);
  T.Test('PathJoin R19 extra', @TestPathJoinR19Extra);
  T.Test('PathMatch R19 extra', @TestPathMatchR19Extra);
  T.Test('PathVolume List R19 extra', @TestPathVolumeListR19Extra);
  T.Test('PathClean Rel R22', @TestPathCleanRelR22);
  T.Test('PathClean Join Match R31', @TestPathCleanJoinMatchR31);
  if not T.Run then Halt(1);
end.
