program test_fs_glob;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.fs.dir,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
  nextpas.core.fs.glob;

var
  T: TTestRunner;
  GTmpDir: string;

{ T1: * matches anything — *.pas matches test.pas }

procedure TestGlob_StarBasic;
begin
  Check(GlobMatch('*.pas', 'test.pas'),
    '*.pas should match test.pas');
end;

{ T2: * does not cross path separator — *.pas does NOT match dir/test.pas }

procedure TestGlob_StarNoCrossSep;
begin
  Check(not GlobMatch('*.pas', 'dir/test.pas'),
    '*.pas must not match dir/test.pas');
end;

{ T3: ? matches single char — ?.txt matches a.txt }

procedure TestGlob_QuestionSingle;
begin
  Check(GlobMatch('?.txt', 'a.txt'),
    '?.txt should match a.txt');
end;

{ T4: ? does not match empty — ?.txt does NOT match .txt }

procedure TestGlob_QuestionNoEmpty;
begin
  Check(not GlobMatch('?.txt', '.txt'),
    '?.txt must not match .txt');
end;

{ T5: [abc] character class — [abc].txt matches a.txt }

procedure TestGlob_CharClass;
begin
  Check(GlobMatch('[abc].txt', 'a.txt'),
    '[abc].txt should match a.txt');
  Check(GlobMatch('[abc].txt', 'b.txt'),
    '[abc].txt should match b.txt');
  Check(not GlobMatch('[abc].txt', 'd.txt'),
    '[abc].txt must not match d.txt');
end;

{ T6: [a-z] range — [a-z].txt matches m.txt }

procedure TestGlob_Range;
begin
  Check(GlobMatch('[a-z].txt', 'm.txt'),
    '[a-z].txt should match m.txt');
  Check(not GlobMatch('[a-z].txt', 'M.txt'),
    '[a-z].txt must not match M.txt');
  Check(not GlobMatch('[a-z].txt', '0.txt'),
    '[a-z].txt must not match 0.txt');
end;

{ T7: [^abc] negation — [^abc].txt does NOT match a.txt }

procedure TestGlob_NegateCaret;
begin
  Check(not GlobMatch('[^abc].txt', 'a.txt'),
    '[^abc].txt must not match a.txt');
  Check(GlobMatch('[^abc].txt', 'd.txt'),
    '[^abc].txt should match d.txt');
end;

{ T8: [!abc] negation — [!abc].txt matches d.txt }

procedure TestGlob_NegateBang;
begin
  Check(GlobMatch('[!abc].txt', 'd.txt'),
    '[!abc].txt should match d.txt');
  Check(not GlobMatch('[!abc].txt', 'a.txt'),
    '[!abc].txt must not match a.txt');
end;

{ T9: ** recursive — **/test.pas matches a/b/test.pas }

procedure TestGlob_DoubleStarRecursive;
begin
  Check(GlobMatch('**/test.pas', 'a/b/test.pas'),
    '**/test.pas should match a/b/test.pas');
  Check(GlobMatch('**/test.pas', 'test.pas'),
    '**/test.pas should match test.pas');
end;

{ T10: ** in pattern — src/**/*.pas matches src/a/b/test.pas }

procedure TestGlob_DoubleStarMiddle;
begin
  Check(GlobMatch('src/**/*.pas', 'src/a/b/test.pas'),
    'src/**/*.pas should match src/a/b/test.pas');
  Check(GlobMatch('src/**/*.pas', 'src/test.pas'),
    'src/**/*.pas should match src/test.pas');
end;

{ T11: ** in middle — a/**/b.txt matches a/x/y/b.txt }

procedure TestGlob_DoubleStarInMiddle;
begin
  Check(GlobMatch('a/**/b.txt', 'a/x/y/b.txt'),
    'a/**/b.txt should match a/x/y/b.txt');
  Check(GlobMatch('a/**/b.txt', 'a/b.txt'),
    'a/**/b.txt should match a/b.txt');
end;

{ T12: Empty pattern — '' only matches '' }

procedure TestGlob_EmptyPattern;
begin
  Check(GlobMatch('', ''),
    'empty pattern should match empty name');
  Check(not GlobMatch('', 'test.pas'),
    'empty pattern must not match test.pas');
end;

{ T13: Exact match — test.pas matches test.pas }

procedure TestGlob_ExactMatch;
begin
  Check(GlobMatch('test.pas', 'test.pas'),
    'test.pas should match test.pas');
  Check(not GlobMatch('test.pas', 'other.pas'),
    'test.pas must not match other.pas');
end;

{ T14: Case sensitive — *.PAS does NOT match test.pas }

procedure TestGlob_CaseSensitive;
begin
  Check(not GlobMatch('*.PAS', 'test.pas'),
    '*.PAS must not match test.pas (case sensitive)');
  Check(GlobMatch('*.PAS', 'test.PAS'),
    '*.PAS should match test.PAS');
end;

{ T15: Multiple * — *.* matches test.pas }

procedure TestGlob_MultipleStars;
begin
  Check(GlobMatch('*.*', 'test.pas'),
    '*.* should match test.pas');
  Check(GlobMatch('*.*', 'a.b.c'),
    '*.* should match a.b.c');
  Check(not GlobMatch('*.*', 'noext'),
    '*.* must not match noext');
end;

{ T16: ** vs * distinction }

procedure TestGlob_DoubleStarVsSingle;
begin
  { ** matches across directory separators }
  Check(GlobMatch('**', 'a/b/c'),
    '** should match a/b/c');
  { * does not cross separators }
  Check(not GlobMatch('*', 'a/b/c'),
    '* must not match a/b/c');
  Check(GlobMatch('*', 'abc'),
    '* should match abc');
end;

{ T17: Literal brackets — test[1].txt should match literal with no meta chars }

procedure TestGlob_LiteralBrackets;
begin
  { a character class with only digits }
  Check(GlobMatch('test[1].txt', 'test1.txt'),
    'test[1].txt should match test1.txt');
  Check(not GlobMatch('test[1].txt', 'test2.txt'),
    'test[1].txt must not match test2.txt');
end;

{ T18: Empty character class — [] matches nothing }

procedure TestGlob_EmptyCharClass;
begin
  Check(not GlobMatch('[].txt', 'a.txt'),
    '[].txt must not match a.txt');
end;

{ T19: Path matching — src/*/test.pas matches src/a/test.pas }

procedure TestGlob_PathWildcard;
begin
  Check(GlobMatch('src/*/test.pas', 'src/a/test.pas'),
    'src/*/test.pas should match src/a/test.pas');
  Check(not GlobMatch('src/*/test.pas', 'src/a/b/test.pas'),
    'src/*/test.pas must not match src/a/b/test.pas');
end;

{ T20: * matches empty string }

procedure TestGlob_StarMatchesEmpty;
begin
  Check(GlobMatch('*', ''),
    '* should match empty string');
  Check(GlobMatch('*.pas', '.pas'),
    '*.pas should match .pas (star matches empty)');
end;

{ T21: ? with path separator }

procedure TestGlob_QuestionNoCrossSep;
begin
  Check(not GlobMatch('?', '/'),
    '? must not match /');
  Check(not GlobMatch('?', '\'),
    '? must not match \');
end;

{ T22: Mixed patterns — a?b*[0-9].txt }

procedure TestGlob_MixedPattern;
begin
  Check(GlobMatch('a?b*[0-9].txt', 'aXbHello5.txt'),
    'a?b*[0-9].txt should match aXbHello5.txt');
  Check(not GlobMatch('a?b*[0-9].txt', 'abHello5.txt'),
    'a?b*[0-9].txt must not match abHello5.txt (? needs a char)');
  Check(not GlobMatch('a?b*[0-9].txt', 'aXbHelloX.txt'),
    'a?b*[0-9].txt must not match aXbHelloX.txt ([0-9] needs digit)');
end;

{ T23: Character class negation with range — [^a-z] }

procedure TestGlob_NegateRange;
begin
  Check(not GlobMatch('[^a-z]', 'a'),
    '[^a-z] must not match a');
  Check(GlobMatch('[^a-z]', '0'),
    '[^a-z] should match 0');
  Check(GlobMatch('[^a-z]', 'A'),
    '[^a-z] should match A');
end;

{ T24: **/ with trailing separator }

procedure TestGlob_DoubleStarTrailingSep;
begin
  Check(GlobMatch('**/b.txt', 'a/b.txt'),
    '**/b.txt should match a/b.txt');
  Check(GlobMatch('**/b.txt', 'a/c/b.txt'),
    '**/b.txt should match a/c/b.txt');
end;

{ T25: Pattern with only ** }

procedure TestGlob_OnlyDoubleStar;
begin
  Check(GlobMatch('**', ''),
    '** should match empty');
  Check(GlobMatch('**', 'a'),
    '** should match a');
  Check(GlobMatch('**', 'a/b/c'),
    '** should match a/b/c');
end;

{ === FsGlob file system tests === }

procedure SetupTmpDir;
begin
  GTmpDir := '/tmp/nextpas_fs_glob_test_' + IntToStr(GetProcessID);
  FsMkdirAll(GTmpDir);
end;

procedure CleanupTmpDir;
begin
  FsRemoveAll(GTmpDir);
end;

{ FG1: FsGlob matches all .txt files }

procedure TestFsGlob_TxtFiles;
var
  LResults: TStringArray;
begin
  FsMkdir(GTmpDir + '/fg1');
  FsWriteFile(GTmpDir + '/fg1/a.txt', TBytes.Create(1));
  FsWriteFile(GTmpDir + '/fg1/b.txt', TBytes.Create(2));
  FsWriteFile(GTmpDir + '/fg1/c.pas', TBytes.Create(3));

  LResults := FsGlob(GTmpDir + '/fg1', '*.txt');
  CheckEqual(Int64(2), Int64(Length(LResults)),
    '*.txt should match 2 files');
  Check(LResults[0] <> '', 'result[0] not empty');
  Check(LResults[1] <> '', 'result[1] not empty');
end;

{ FG2: FsGlob recursive **/*.pas }

procedure TestFsGlob_RecursivePas;
var
  LResults: TStringArray;
begin
  FsMkdirAll(GTmpDir + '/fg2/sub/deep');
  FsWriteFile(GTmpDir + '/fg2/top.pas', TBytes.Create(1));
  FsWriteFile(GTmpDir + '/fg2/sub/mid.pas', TBytes.Create(2));
  FsWriteFile(GTmpDir + '/fg2/sub/deep/deep.pas', TBytes.Create(3));
  FsWriteFile(GTmpDir + '/fg2/sub/deep/data.txt', TBytes.Create(4));

  LResults := FsGlob(GTmpDir + '/fg2', '**/*.pas');
  CheckEqual(Int64(3), Int64(Length(LResults)),
    '**/*.pas should match 3 .pas files recursively');
end;

{ FG3: FsGlob wildcard in path middle }

procedure TestFsGlob_PathMiddleWildcard;
var
  LResults: TStringArray;
begin
  FsMkdirAll(GTmpDir + '/fg3/a');
  FsMkdirAll(GTmpDir + '/fg3/b');
  FsWriteFile(GTmpDir + '/fg3/a/data.txt', TBytes.Create(1));
  FsWriteFile(GTmpDir + '/fg3/b/data.txt', TBytes.Create(2));
  FsWriteFile(GTmpDir + '/fg3/b/other.pas', TBytes.Create(3));

  LResults := FsGlob(GTmpDir + '/fg3', '*/data.txt');
  CheckEqual(Int64(2), Int64(Length(LResults)),
    '*/data.txt should match data.txt in each subdir');
end;

{ FG4: FsGlob empty directory returns empty }

procedure TestFsGlob_EmptyDir;
var
  LResults: TStringArray;
begin
  FsMkdir(GTmpDir + '/fg4');

  LResults := FsGlob(GTmpDir + '/fg4', '*.txt');
  CheckEqual(Int64(0), Int64(Length(LResults)),
    'empty dir should return empty array');
end;

{ FG5: FsGlob no match returns empty }

procedure TestFsGlob_NoMatch;
var
  LResults: TStringArray;
begin
  FsMkdir(GTmpDir + '/fg5');
  FsWriteFile(GTmpDir + '/fg5/readme.md', TBytes.Create(1));

  LResults := FsGlob(GTmpDir + '/fg5', '*.xyz');
  CheckEqual(Int64(0), Int64(Length(LResults)),
    'no match should return empty array');
end;

{ FG6: FsGlob results are sorted }

procedure TestFsGlob_Sorted;
var
  LResults: TStringArray;
  LI: Integer;
begin
  FsMkdir(GTmpDir + '/fg6');
  FsWriteFile(GTmpDir + '/fg6/z.txt', TBytes.Create(1));
  FsWriteFile(GTmpDir + '/fg6/a.txt', TBytes.Create(2));
  FsWriteFile(GTmpDir + '/fg6/m.txt', TBytes.Create(3));

  LResults := FsGlob(GTmpDir + '/fg6', '*.txt');
  CheckEqual(Int64(3), Int64(Length(LResults)),
    '*.txt should match 3 files');
  for LI := 1 to High(LResults) do
    Check(LResults[LI - 1] <= LResults[LI],
      'results must be sorted: ' + LResults[LI-1] + ' <= ' + LResults[LI]);
end;

begin
  SetupTmpDir;
  try
    T := TTestRunner.Create('nextpas.core.fs.glob');

    T.Run('StarBasic: *.pas matches test.pas',
      @TestGlob_StarBasic);
    T.Run('StarNoCrossSep: *.pas does not match dir/test.pas',
      @TestGlob_StarNoCrossSep);
    T.Run('QuestionSingle: ?.txt matches a.txt',
      @TestGlob_QuestionSingle);
    T.Run('QuestionNoEmpty: ?.txt does not match .txt',
      @TestGlob_QuestionNoEmpty);
    T.Run('CharClass: [abc].txt matches a/b/c, not d',
      @TestGlob_CharClass);
    T.Run('Range: [a-z].txt matches m.txt',
      @TestGlob_Range);
    T.Run('NegateCaret: [^abc].txt negation',
      @TestGlob_NegateCaret);
    T.Run('NegateBang: [!abc].txt negation',
      @TestGlob_NegateBang);
    T.Run('DoubleStarRecursive: **/test.pas matches deep paths',
      @TestGlob_DoubleStarRecursive);
    T.Run('DoubleStarMiddle: src/**/*.pas matches recursive .pas',
      @TestGlob_DoubleStarMiddle);
    T.Run('DoubleStarInMiddle: a/**/b.txt matches a/x/y/b.txt',
      @TestGlob_DoubleStarInMiddle);
    T.Run('EmptyPattern: empty only matches empty',
      @TestGlob_EmptyPattern);
    T.Run('ExactMatch: test.pas matches test.pas',
      @TestGlob_ExactMatch);
    T.Run('CaseSensitive: *.PAS does not match test.pas',
      @TestGlob_CaseSensitive);
    T.Run('MultipleStars: *.* matches test.pas',
      @TestGlob_MultipleStars);
    T.Run('DoubleStarVsSingle: ** crosses separators, * does not',
      @TestGlob_DoubleStarVsSingle);
    T.Run('LiteralBrackets: test[1].txt matches literal',
      @TestGlob_LiteralBrackets);
    T.Run('EmptyCharClass: [] matches nothing',
      @TestGlob_EmptyCharClass);
    T.Run('PathWildcard: src/*/test.pas path matching',
      @TestGlob_PathWildcard);
    T.Run('StarMatchesEmpty: * matches empty string',
      @TestGlob_StarMatchesEmpty);
    T.Run('QuestionNoCrossSep: ? does not match separator',
      @TestGlob_QuestionNoCrossSep);
    T.Run('MixedPattern: a?b*[0-9].txt compound pattern',
      @TestGlob_MixedPattern);
    T.Run('NegateRange: [^a-z] negation with range',
      @TestGlob_NegateRange);
    T.Run('DoubleStarTrailingSep: **/b.txt matching',
      @TestGlob_DoubleStarTrailingSep);
    T.Run('OnlyDoubleStar: ** matches everything',
      @TestGlob_OnlyDoubleStar);

    T.Run('FsGlob_TxtFiles: *.txt matches all .txt files',
      @TestFsGlob_TxtFiles);
    T.Run('FsGlob_RecursivePas: **/*.pas recursive match',
      @TestFsGlob_RecursivePas);
    T.Run('FsGlob_PathMiddleWildcard: */data.txt path match',
      @TestFsGlob_PathMiddleWildcard);
    T.Run('FsGlob_EmptyDir: empty directory returns empty',
      @TestFsGlob_EmptyDir);
    T.Run('FsGlob_NoMatch: no match returns empty',
      @TestFsGlob_NoMatch);
    T.Run('FsGlob_Sorted: results are sorted',
      @TestFsGlob_Sorted);

    T.Summary;
  finally
    CleanupTmpDir;
  end;
end.
