program test_fs_glob;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.fs.glob;

var
  T: TTestRunner;

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

begin
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

  T.Summary;
end.
