program test_regex_basic;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.regex,
  nextpas.core.regex.base,
  nextpas.core.regex.nfa,
  nextpas.core.regex.dfa,
  nextpas.core.regex.parser,
  nextpas.core.regex.compiler,
  nextpas.core.text.scan;

var
  T: TTestRunner;

function CompileProgram(const APattern: string): TRegexProgram;
var LAst: PAstNode; LNumCaptures: UInt32; LFlags: TRegexFlags;
begin
  LAst := RegexParse(APattern, LNumCaptures, LFlags);
  try
    Result := RegexCompile(LAst, LNumCaptures, LFlags);
  finally
    RegexFreeAst(LAst);
  end;
end;

procedure TestLiteral;
var R: TRegex;
begin
  R := TRegex.Compile('hello');
  Check(R.IsMatch('hello'), 'exact');
  Check(R.IsMatch('say hello world'), 'substring');
  Check(not R.IsMatch('goodbye'), 'miss');
  Check(not R.IsMatch(''), 'empty input');
end;

procedure TestDot;
var R: TRegex;
begin
  R := TRegex.Compile('h.llo');
  Check(R.IsMatch('hello'), 'e');
  Check(R.IsMatch('hallo'), 'a');
  Check(not R.IsMatch('hllo'), 'missing char');
  Check(not R.IsMatch('h' + #10 + 'llo'), 'dot no newline');
end;

procedure TestStar;
var R: TRegex;
begin
  R := TRegex.Compile('ab*c');
  Check(R.IsMatch('ac'), 'zero b');
  Check(R.IsMatch('abc'), 'one b');
  Check(R.IsMatch('abbc'), 'two b');
  Check(R.IsMatch('abbbc'), 'three b');
  Check(not R.IsMatch('adc'), 'wrong char');
end;

procedure TestPlus;
var R: TRegex;
begin
  R := TRegex.Compile('ab+c');
  Check(not R.IsMatch('ac'), 'zero b');
  Check(R.IsMatch('abc'), 'one b');
  Check(R.IsMatch('abbc'), 'two b');
end;

procedure TestQuestion;
var R: TRegex;
begin
  R := TRegex.Compile('colou?r');
  Check(R.IsMatch('color'), 'without u');
  Check(R.IsMatch('colour'), 'with u');
  Check(not R.IsMatch('colouur'), 'two u');
end;

procedure TestAlternation;
var R: TRegex;
begin
  R := TRegex.Compile('cat|dog');
  Check(R.IsMatch('cat'), 'cat');
  Check(R.IsMatch('dog'), 'dog');
  Check(not R.IsMatch('bird'), 'bird');
  R := TRegex.Compile('a|b|c');
  Check(R.IsMatch('a'), 'a');
  Check(R.IsMatch('b'), 'b');
  Check(R.IsMatch('c'), 'c');
  Check(not R.IsMatch('d'), 'd');
end;

procedure TestCharClass;
var R: TRegex;
begin
  R := TRegex.Compile('[abc]');
  Check(R.IsMatch('a'), 'a');
  Check(R.IsMatch('b'), 'b');
  Check(not R.IsMatch('d'), 'd');
  R := TRegex.Compile('[a-z]');
  Check(R.IsMatch('m'), 'range m');
  Check(not R.IsMatch('5'), 'range 5');
  R := TRegex.Compile('[^0-9]');
  Check(R.IsMatch('a'), 'negated a');
  Check(not R.IsMatch('5'), 'negated 5');
end;

procedure TestShorthand;
var R: TRegex; M: TMatch;
begin
  R := TRegex.Compile('\d+');
  Check(R.IsMatch('123'), 'digits');
  Check(not R.IsMatch('abc'), 'no digits');
  M := R.Find('price: 42 dollars');
  Check(M.Found, 'find digits');
  CheckEqual('42', M.Value('price: 42 dollars'), 'find value');

  R := TRegex.Compile('\w+');
  M := R.Find('hello world');
  Check(M.Found, 'word');
  CheckEqual('hello', M.Value('hello world'), 'word value');

  R := TRegex.Compile('\s+');
  Check(R.IsMatch('hello world'), 'has space');
  Check(not R.IsMatch('helloworld'), 'no space');
end;

procedure TestAnchors;
var R: TRegex;
begin
  R := TRegex.Compile('^hello');
  Check(R.IsMatch('hello world'), 'start match');
  Check(not R.IsMatch('say hello'), 'start miss');

  R := TRegex.Compile('world$');
  Check(R.IsMatch('hello world'), 'end match');
  Check(not R.IsMatch('world!'), 'end miss');

  R := TRegex.Compile('^exact$');
  Check(R.IsMatch('exact'), 'full match');
  Check(not R.IsMatch('not exact'), 'full miss');
end;

procedure TestFind;
var R: TRegex; M: TMatch;
begin
  R := TRegex.Compile('world');
  M := R.Find('hello world');
  Check(M.Found, 'found');
  CheckEqual(Int64(6), Int64(M.Start), 'start');
  CheckEqual(Int64(5), Int64(M.Len), 'len');
  CheckEqual('world', M.Value('hello world'), 'value');

  M := R.Find('goodbye');
  Check(not M.Found, 'not found');
end;

procedure TestFindAll;
var R: TRegex; MA: TMatchArray;
begin
  R := TRegex.Compile('\d+');
  MA := R.FindAll('a1 b22 c333');
  CheckEqual(Int64(3), Int64(Length(MA)), 'count');
  CheckEqual('1', MA[0].Value('a1 b22 c333'), 'first');
  CheckEqual('22', MA[1].Value('a1 b22 c333'), 'second');
  CheckEqual('333', MA[2].Value('a1 b22 c333'), 'third');
end;

procedure TestReplace;
var R: TRegex;
begin
  R := TRegex.Compile('\d+');
  CheckEqual('a# b# c#', R.ReplaceAll('a1 b22 c333', '#'), 'replace all');
  CheckEqual('a# b22 c333', R.ReplaceFirst('a1 b22 c333', '#'), 'replace first');
end;

procedure TestSplit;
var R: TRegex; parts: TStringArray;
begin
  R := TRegex.Compile(',\s*');
  parts := R.Split('a, b,c,  d');
  CheckEqual(Int64(4), Int64(Length(parts)), 'split count');
  CheckEqual('a', parts[0], 'split[0]');
  CheckEqual('b', parts[1], 'split[1]');
  CheckEqual('c', parts[2], 'split[2]');
  CheckEqual('d', parts[3], 'split[3]');
end;

procedure TestRepetition;
var R: TRegex;
begin
  R := TRegex.Compile('a{3}');
  Check(R.IsMatch('aaa'), '{3} match');
  Check(not R.IsMatch('aa'), '{3} too few');
  R := TRegex.Compile('a{2,4}');
  Check(not R.IsMatch('a'), '{2,4} one');
  Check(R.IsMatch('aa'), '{2,4} two');
  Check(R.IsMatch('aaa'), '{2,4} three');
  Check(R.IsMatch('aaaa'), '{2,4} four');
end;

procedure TestTryCompile;
var R: TRegex; err: string;
begin
  Check(TRegex.TryCompile('hello', R, err), 'valid');
  Check(not TRegex.TryCompile('(unclosed', R, err), 'invalid');
  Check(err <> '', 'error message');
end;

procedure TestConvenience;
begin
  Check(RegexIsMatch('\d+', 'abc 123'), 'convenience isMatch');
  CheckEqual('42', RegexFind('\d+', 'val=42').Value('val=42'), 'convenience find');
end;

procedure TestNoExponentialBlowup;
var R: TRegex; input: string; i: Integer;
begin
  R := TRegex.Compile('a?a?a?a?a?a?a?a?a?a?aaaaaaaaaa');
  input := '';
  for i := 1 to 10 do input := input + 'a';
  Check(R.IsMatch(input), 'no blowup');
end;

procedure TestCaptureGroups;
var R: TRegex; M: TMatch;
begin
  R := TRegex.Compile('(\d+)-(\d+)');
  M := R.Find('date: 2026-05-31');
  Check(M.Found, 'found');
  CheckEqual('2026-05', M.Value('date: 2026-05-31'), 'full match');
  CheckEqual(Int64(2), Int64(Length(M.Groups)), 'group count');
  CheckEqual('2026', M.Groups[0].Value('date: 2026-05-31'), 'group 0');
  CheckEqual('05', M.Groups[1].Value('date: 2026-05-31'), 'group 1');
end;

procedure TestWordBoundary;
var R: TRegex;
begin
  R := TRegex.Compile('\bword\b');
  Check(R.IsMatch('a word here'), 'word isolated');
  Check(not R.IsMatch('password'), 'inside word');
  Check(not R.IsMatch('wordy'), 'prefix');
  Check(R.IsMatch('word'), 'exact');
  Check(R.IsMatch('word.'), 'before punct');
end;

procedure TestNonCapturingGroup;
var R: TRegex;
begin
  R := TRegex.Compile('(?:ab)+c');
  Check(R.IsMatch('abc'), 'one ab');
  Check(R.IsMatch('ababc'), 'two ab');
  Check(not R.IsMatch('ac'), 'no ab');
end;

procedure TestEdgeCases;
var R: TRegex; M: TMatch;
begin
  R := TRegex.Compile('.*');
  Check(R.IsMatch(''), 'empty input matches .*');
  Check(R.IsMatch('anything'), 'anything matches .*');

  R := TRegex.Compile('');
  Check(R.IsMatch('hello'), 'empty pattern matches');

  R := TRegex.Compile('a');
  M := R.Find('');
  Check(not M.Found, 'no match in empty');
end;

procedure TestEscapes;
var R: TRegex;
begin
  R := TRegex.Compile('\.');
  Check(R.IsMatch('a.b'), 'escaped dot');
  Check(not R.IsMatch('axb'), 'escaped dot miss');

  R := TRegex.Compile('\*');
  Check(R.IsMatch('a*b'), 'escaped star');

  R := TRegex.Compile('\(');
  Check(R.IsMatch('f(x)'), 'escaped paren');
end;

procedure TestStartClassPrefilter;
var R: TRegex; M: TMatch; MA: TMatchArray; longInput: string; i: Integer;
begin
  // Build a long input with target near the end
  SetLength(longInput, 5000);
  for i := 1 to 5000 do longInput[i] := Chr(Ord('a') + (i mod 26));
  Move('99bottles'[1], longInput[4990], 9);

  // \d+ with start class {0-9} should skip all alpha chars
  R := TRegex.Compile('\d+');
  M := R.Find(longInput);
  Check(M.Found, 'digit find in long input');
  CheckEqual('99', M.Value(longInput), 'digit value');

  // Alternation with start class {c,d,b,f}
  R := TRegex.Compile('cat|dog|bird|fish');
  Check(not R.IsMatch('aaaa eeee gggg'), 'alt miss');
  Check(R.IsMatch('I have a cat'), 'alt cat');
  Check(R.IsMatch('I have a dog'), 'alt dog');
  Check(R.IsMatch('I have a bird'), 'alt bird');
  Check(R.IsMatch('I have a fish'), 'alt fish');

  // \w+ start class should match word chars
  R := TRegex.Compile('\w+');
  MA := R.FindAll('  hello  world  ');
  CheckEqual(Int64(2), Int64(Length(MA)), 'word findall count');
  CheckEqual('hello', MA[0].Value('  hello  world  '), 'word first');
  CheckEqual('world', MA[1].Value('  hello  world  '), 'word second');

  // Pattern starting with char class range
  R := TRegex.Compile('[A-Z][a-z]+');
  M := R.Find('hello World');
  Check(M.Found, 'upper+lower find');
  CheckEqual('World', M.Value('hello World'), 'upper+lower value');
end;

procedure TestNamedGroups;
var R: TRegex; M: TMatch; G: TGroup;
begin
  R := TRegex.Compile('(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})');
  M := R.Find('date: 2026-05-31');
  Check(M.Found, 'named found');
  G := R.GroupByName(M, 'year');
  Check(G.Found, 'year found');
  CheckEqual('2026', G.Value('date: 2026-05-31'), 'year value');
  G := R.GroupByName(M, 'month');
  CheckEqual('05', G.Value('date: 2026-05-31'), 'month value');
  G := R.GroupByName(M, 'day');
  CheckEqual('31', G.Value('date: 2026-05-31'), 'day value');
  CheckEqual(Int64(3), Int64(R.NumCaptures), 'num captures');
  CheckEqual(Int64(-1), Int64(R.GroupIndexByName('nonexist')), 'bad name');
end;

procedure TestNegatedShorthand;
var R: TRegex; M: TMatch;
begin
  // \D matches non-digit
  R := TRegex.Compile('\D+');
  Check(R.IsMatch('abc'), '\D matches letters');
  Check(R.IsMatch('!@#'), '\D matches symbols');
  M := R.Find('123abc456');
  Check(M.Found, '\D find');
  CheckEqual('abc', M.Value('123abc456'), '\D value');

  // \W matches non-word
  R := TRegex.Compile('\W+');
  Check(R.IsMatch('hello world'), '\W matches space');
  M := R.Find('hello world');
  Check(M.Found, '\W find');
  CheckEqual(' ', M.Value('hello world'), '\W value');
  Check(not R.IsMatch('helloworld'), '\W no match all word');

  // \S matches non-space
  R := TRegex.Compile('\S+');
  M := R.Find('  hello  ');
  Check(M.Found, '\S find');
  CheckEqual('hello', M.Value('  hello  '), '\S value');
end;

procedure TestFindAt;
var R: TRegex; M: TMatch;
begin
  R := TRegex.Compile('\d+');
  M := R.FindAt('a1 b22 c333', 0);
  Check(M.Found, 'findAt 0 found');
  CheckEqual('1', M.Value('a1 b22 c333'), 'findAt 0 value');

  M := R.FindAt('a1 b22 c333', 3);
  Check(M.Found, 'findAt 3 found');
  CheckEqual('22', M.Value('a1 b22 c333'), 'findAt 3 value');

  M := R.FindAt('a1 b22 c333', 7);
  Check(M.Found, 'findAt 7 found');
  CheckEqual('333', M.Value('a1 b22 c333'), 'findAt 7 value');

  M := R.FindAt('abc', 0);
  Check(not M.Found, 'findAt no match');
end;

procedure TestIsFullMatch;
var R: TRegex;
begin
  R := TRegex.Compile('\d+');
  Check(R.IsFullMatch('12345'), 'full digits');
  Check(not R.IsFullMatch('abc123'), 'partial start');
  Check(not R.IsFullMatch('123abc'), 'partial end');
  Check(not R.IsFullMatch(''), 'empty');

  R := TRegex.Compile('[a-z]+');
  Check(R.IsFullMatch('hello'), 'full alpha');
  Check(not R.IsFullMatch('Hello'), 'has upper');

  R := TRegex.Compile('.*');
  Check(R.IsFullMatch(''), 'dotstar empty');
  Check(R.IsFullMatch('anything'), 'dotstar any');
end;

procedure TestQuoteMeta;
var s: string;
begin
  s := RegexQuoteMeta('hello');
  CheckEqual('hello', s, 'no meta');

  s := RegexQuoteMeta('a.b');
  CheckEqual('a\.b', s, 'dot');

  s := RegexQuoteMeta('a+b*c?');
  CheckEqual('a\+b\*c\?', s, 'quantifiers');

  s := RegexQuoteMeta('(a|b)');
  CheckEqual('\(a\|b\)', s, 'parens pipe');

  s := RegexQuoteMeta('[a-z]');
  CheckEqual('\[a-z\]', s, 'brackets');

  s := RegexQuoteMeta('^start$');
  CheckEqual('\^start\$', s, 'anchors');

  s := RegexQuoteMeta('a{3}');
  CheckEqual('a\{3\}', s, 'braces');

  s := RegexQuoteMeta('a\b');
  CheckEqual('a\\b', s, 'backslash');
end;

procedure TestSplitLimit;
var R: TRegex; parts: TStringArray;
begin
  R := TRegex.Compile(',');
  parts := R.Split('a,b,c,d,e', 2);
  CheckEqual(Int64(3), Int64(Length(parts)), 'limit 2 count');
  CheckEqual('a', parts[0], 'limit[0]');
  CheckEqual('b', parts[1], 'limit[1]');
  CheckEqual('c,d,e', parts[2], 'limit[2] remainder');

  parts := R.Split('a,b,c,d,e', 1);
  CheckEqual(Int64(2), Int64(Length(parts)), 'limit 1 count');
  CheckEqual('a', parts[0], 'limit1[0]');
  CheckEqual('b,c,d,e', parts[1], 'limit1[1] remainder');

  // No limit (default)
  parts := R.Split('a,b,c');
  CheckEqual(Int64(3), Int64(Length(parts)), 'no limit count');

  // Limit larger than matches
  parts := R.Split('a,b', 10);
  CheckEqual(Int64(2), Int64(Length(parts)), 'big limit count');
  CheckEqual('a', parts[0], 'big[0]');
  CheckEqual('b', parts[1], 'big[1]');
end;

function UpperReplace(const AInput: string; const AMatch: TMatch): string;
begin
  Result := UpCase(AMatch.Value(AInput));
end;

function LenReplace(const AInput: string; const AMatch: TMatch): string;
begin
  Result := IntToStr(AMatch.Len);
end;

procedure TestReplaceFunc;
var R: TRegex; s: string;
begin
  R := TRegex.Compile('[a-z]+');
  s := R.ReplaceFirstFunc('hello world', @UpperReplace);
  CheckEqual('HELLO world', s, 'replaceFirst func');

  s := R.ReplaceAllFunc('hello world', @UpperReplace);
  CheckEqual('HELLO WORLD', s, 'replaceAll func');

  R := TRegex.Compile('\w+');
  s := R.ReplaceAllFunc('ab cde f', @LenReplace);
  CheckEqual('2 3 1', s, 'replaceAll len');
end;

procedure TestReplaceExpand;
var R: TRegex; s: string;
begin
  // $0 = full match
  R := TRegex.Compile('\d+');
  s := R.ReplaceAllExpand('a1 b22', '[$0]');
  CheckEqual('a[1] b[22]', s, '$0 expand');

  // $1, $2 = capture groups
  R := TRegex.Compile('(\w+)=(\w+)');
  s := R.ReplaceAllExpand('x=1 y=2', '$2:$1');
  CheckEqual('1:x 2:y', s, '$1 $2 expand');

  // ${name} = named capture
  R := TRegex.Compile('(?P<key>\w+)=(?P<val>\w+)');
  s := R.ReplaceAllExpand('x=1', '${val}->${key}');
  CheckEqual('1->x', s, 'named expand');

  // $$ = literal $
  R := TRegex.Compile('\d+');
  s := R.ReplaceAllExpand('price 42', '$$$0');
  CheckEqual('price $42', s, '$$ literal');
end;

procedure TestZeroRepeat;
var R: TRegex; M: TMatch;
begin
  R := TRegex.Compile('a{0}');
  Check(R.IsMatch(''), '{0} matches empty');
  Check(R.IsMatch('b'), '{0} matches anything');

  R := TRegex.Compile('a{0,2}');
  Check(R.IsMatch(''), '{0,2} zero');
  Check(R.IsMatch('a'), '{0,2} one');
  Check(R.IsMatch('aa'), '{0,2} two');

  R := TRegex.Compile('x(ab){0}y');
  M := R.Find('xy');
  Check(M.Found, '{0} in sequence');
  CheckEqual('xy', M.Value('xy'), '{0} value');
end;

procedure TestAlternationPriority;
var R: TRegex; M: TMatch;
begin
  // POSIX leftmost-longest: among matches at same start, longest wins
  R := TRegex.Compile('a|ab');
  M := R.Find('ab');
  Check(M.Found, 'alt found');
  CheckEqual('ab', M.Value('ab'), 'longest wins at same start');

  R := TRegex.Compile('ab|a');
  M := R.Find('ab');
  Check(M.Found, 'alt2 found');
  CheckEqual('ab', M.Value('ab'), 'longest wins regardless of order');

  // Leftmost always wins over longest at later position
  R := TRegex.Compile('b|ab');
  M := R.Find('ab');
  Check(M.Found, 'leftmost found');
  CheckEqual('ab', M.Value('ab'), 'longest at leftmost start');
end;

procedure TestSplitZero;
var R: TRegex; parts: TStringArray;
begin
  R := TRegex.Compile(',');
  parts := R.Split('a,b,c', 0);
  CheckEqual(Int64(1), Int64(Length(parts)), 'split 0 = no split');
  CheckEqual('a,b,c', parts[0], 'split 0 value');
end;

procedure ExpectTemplateError(const ARegex: TRegex; const ATemplate, ACase: string);
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    ARegex.ReplaceAllExpand('hello', ATemplate);
  except
    on E: ERegexError do
      LRaised := True;
  end;
  Check(LRaised, ACase);
end;

procedure TestMalformedTemplate;
var R: TRegex; s: string;
begin
  R := TRegex.Compile('(\w+)');

  // $ at end of template
  ExpectTemplateError(R, 'x$', '$ at end rejected');

  // ${ without }
  ExpectTemplateError(R, '${broken', '${ without } rejected');

  // ${} empty name
  ExpectTemplateError(R, '${}', '${} empty name rejected');

  // unknown group name
  s := R.ReplaceAllExpand('hello', '${nonexist}');
  CheckEqual('', s, 'unknown group empty');
end;

procedure TestFindAtBoundary;
var R: TRegex; M: TMatch;
begin
  R := TRegex.Compile('\d+');

  // Start beyond input length
  M := R.FindAt('hello123', 999);
  Check(not M.Found, 'beyond length');

  // Start at exact match position
  M := R.FindAt('abc123def', 3);
  Check(M.Found, 'at digit start');
  CheckEqual('123', M.Value('abc123def'), 'at digit value');

  // Start past the match
  M := R.FindAt('abc123def', 6);
  Check(not M.Found, 'past digits');
end;

procedure TestLargeRepeat;
var R: TRegex; input: string; i: Integer;
begin
  // a{100} should compile without stack overflow
  R := TRegex.Compile('a{100}');
  SetLength(input, 100);
  for i := 1 to 100 do input[i] := 'a';
  Check(R.IsMatch(input), 'a{100} match');
  Check(not R.IsMatch('aaa'), 'a{100} too few');
end;

procedure TestMemoryStress;
var R: TRegex; MA: TMatchArray; longInput: string; i: Integer;
begin
  // Many matches on long input — tests slot pool doesn't explode
  SetLength(longInput, 10000);
  for i := 1 to 10000 do
    if i mod 10 = 0 then longInput[i] := ' '
    else longInput[i] := 'a';

  R := TRegex.Compile('a+');
  MA := R.FindAll(longInput);
  Check(Length(MA) = 1000, 'many matches count');

  // Verify no crash with capture-heavy pattern on long input
  R := TRegex.Compile('(a+)( )');
  MA := R.FindAll(longInput);
  Check(Length(MA) > 0, 'capture stress');
end;

procedure TestCompileLimits;
var R: TRegex; err: string; pat: string; i: Integer;
begin
  Check(not TRegex.TryCompile('a{1001}', R, err), 'repeat too large');
  Check(Pos('limit', err) > 0, 'repeat error msg');

  Check(TRegex.TryCompile('a{1000}', R, err), 'repeat at limit');

  pat := '';
  for i := 1 to 201 do pat := pat + '(';
  pat := pat + 'a';
  for i := 1 to 201 do pat := pat + ')';
  Check(not TRegex.TryCompile(pat, R, err), 'nesting too deep');
  Check(Pos('limit', err) > 0, 'nesting error msg');

  pat := '';
  for i := 1 to 200 do pat := pat + '(';
  pat := pat + 'a';
  for i := 1 to 200 do pat := pat + ')';
  Check(TRegex.TryCompile(pat, R, err), 'nesting at limit');
end;

procedure TestMalformedPatterns;
var R: TRegex; err: string;
begin
  // Trailing backslash
  Check(not TRegex.TryCompile('a\', R, err), 'trailing backslash');
  Check(Pos('trailing backslash', err) > 0, 'trailing backslash msg');

  // Unclosed character class
  Check(not TRegex.TryCompile('[abc', R, err), 'unclosed char class');
  Check(Pos('unclosed character class', err) > 0, 'unclosed char class msg');

  Check(not TRegex.TryCompile('[]', R, err), 'empty char class');
  Check(Pos('empty character class', err) > 0, 'empty char class msg');

  Check(not TRegex.TryCompile('[z-a]', R, err), 'invalid char class range');
  Check(Pos('invalid character range', err) > 0, 'invalid char class range msg');

  // Unclosed quantifier
  Check(not TRegex.TryCompile('a{', R, err), 'unclosed quantifier');
  Check(Pos('unclosed quantifier', err) > 0, 'unclosed quantifier msg');

  Check(not TRegex.TryCompile('a{3', R, err), 'unclosed quantifier no }');
  Check(Pos('unclosed quantifier', err) > 0, 'unclosed quantifier no } msg');

  Check(not TRegex.TryCompile('a{}', R, err), 'empty quantifier min');
  Check(Pos('quantifier', err) > 0, 'empty quantifier min msg');

  Check(not TRegex.TryCompile('a{,2}', R, err), 'missing quantifier min');
  Check(Pos('quantifier', err) > 0, 'missing quantifier min msg');

  Check(not TRegex.TryCompile('a{,}', R, err), 'missing quantifier min open max');
  Check(Pos('quantifier', err) > 0, 'missing quantifier min open max msg');

  // min > max in quantifier
  Check(not TRegex.TryCompile('a{3,2}', R, err), 'min > max');
  Check(Pos('min exceeds max', err) > 0, 'min > max msg');

  Check(not TRegex.TryCompile('a{999999999999999999999}', R, err), 'overflowed quantifier min');
  Check((Pos('quantifier', err) > 0) or (Pos('limit', err) > 0), 'overflowed quantifier min msg');

  Check(not TRegex.TryCompile('a{1,999999999999999999999}', R, err), 'overflowed quantifier max');
  Check((Pos('quantifier', err) > 0) or (Pos('limit', err) > 0), 'overflowed quantifier max msg');

  // Unmatched closing paren
  Check(not TRegex.TryCompile(')', R, err), 'unmatched )');
  Check(Pos('unmatched closing parenthesis', err) > 0, 'unmatched ) msg');

  Check(not TRegex.TryCompile('a)', R, err), 'unmatched ) after atom');
  Check(Pos('unmatched closing parenthesis', err) > 0, 'unmatched ) after atom msg');

  // Quantifier at start (no preceding atom)
  Check(not TRegex.TryCompile('*a', R, err), '* at start');
  Check(Pos('quantifier without preceding atom', err) > 0, '* at start msg');

  Check(not TRegex.TryCompile('+a', R, err), '+ at start');
  Check(Pos('quantifier without preceding atom', err) > 0, '+ at start msg');

  Check(not TRegex.TryCompile('?a', R, err), '? at start');
  Check(Pos('quantifier without preceding atom', err) > 0, '? at start msg');

  Check(not TRegex.TryCompile('{3}', R, err), 'range quantifier at start');
  Check(Pos('quantifier', err) > 0, 'range quantifier at start msg');

  Check(not TRegex.TryCompile('a{2}{3}', R, err), 'stacked range quantifier');
  Check(Pos('quantifier', err) > 0, 'stacked range quantifier msg');

  Check(not TRegex.TryCompile('a*{2}', R, err), 'range quantifier after star');
  Check(Pos('quantifier', err) > 0, 'range quantifier after star msg');

  Check(not TRegex.TryCompile('(?Pname>a)', R, err), 'named group missing angle');
  Check(Pos('named group', err) > 0, 'named group missing angle msg');

  Check(not TRegex.TryCompile('(?P<>a)', R, err), 'empty named group');
  Check(Pos('named group', err) > 0, 'empty named group msg');

  // Unicode properties rejected
  Check(not TRegex.TryCompile('\p{L}', R, err), '\p{L}');
  Check(Pos('Unicode properties not supported', err) > 0, '\p{L} msg');

  // Valid patterns still work
  Check(TRegex.TryCompile('a{3,5}', R, err), 'valid quantifier');
  Check(TRegex.TryCompile('[abc]', R, err), 'valid char class');
  Check(TRegex.TryCompile('(a)', R, err), 'valid group');
  Check(TRegex.TryCompile('a\\b', R, err), 'valid escape');
end;

procedure TestCaseInsensitive;
var R: TRegex; M: TMatch; MA: TMatchArray; G: TGroup;
begin
  // Inline (?i) flag - literal matching
  R := TRegex.Compile('(?i)hello');
  Check(R.IsMatch('hello'), 'ci lowercase');
  Check(R.IsMatch('HELLO'), 'ci uppercase');
  Check(R.IsMatch('Hello'), 'ci mixed');
  Check(R.IsMatch('hElLo'), 'ci random case');
  Check(not R.IsMatch('goodbye'), 'ci miss');

  // Compile overload with flags
  R := TRegex.Compile('hello', [rfCaseInsensitive]);
  Check(R.IsMatch('hello'), 'flag lowercase');
  Check(R.IsMatch('HELLO'), 'flag uppercase');
  Check(R.IsMatch('HeLLo'), 'flag mixed');
  Check(not R.IsMatch('world'), 'flag miss');

  // Char class with case-insensitive
  R := TRegex.Compile('(?i)[a-z]+');
  Check(R.IsMatch('abc'), 'ci class lower');
  Check(R.IsMatch('ABC'), 'ci class upper');
  Check(R.IsMatch('AbC'), 'ci class mixed');
  Check(R.IsFullMatch('HELLO'), 'ci class full');

  // Mixed: dot still works
  R := TRegex.Compile('(?i)a.b');
  Check(R.IsMatch('a.b'), 'ci dot lower');
  Check(R.IsMatch('A.B'), 'ci dot upper');
  Check(R.IsMatch('A5B'), 'ci dot digit');
  Check(not R.IsMatch('a' + #10 + 'b'), 'ci dot no newline');

  // FindAll with case-insensitive
  R := TRegex.Compile('(?i)cat');
  MA := R.FindAll('Cat CAT cat cAt');
  CheckEqual(Int64(4), Int64(Length(MA)), 'ci findall count');

  // Named groups still work with (?i)
  R := TRegex.Compile('(?i)(?P<word>[a-z]+)=(?P<num>\d+)');
  M := R.Find('KEY=123');
  Check(M.Found, 'ci named found');
  G := R.GroupByName(M, 'word');
  Check(G.Found, 'ci named word found');
  CheckEqual('KEY', G.Value('KEY=123'), 'ci named word value');
  G := R.GroupByName(M, 'num');
  CheckEqual('123', G.Value('KEY=123'), 'ci named num value');

  // Non-letter characters are not affected
  R := TRegex.Compile('(?i)a1b');
  Check(R.IsMatch('a1b'), 'ci digit unchanged');
  Check(R.IsMatch('A1B'), 'ci digit upper');
  Check(not R.IsMatch('a2b'), 'ci digit wrong');

  // Case-insensitive with anchors
  R := TRegex.Compile('(?i)^hello$');
  Check(R.IsMatch('HELLO'), 'ci anchored upper');
  Check(R.IsMatch('hello'), 'ci anchored lower');
  Check(not R.IsMatch('HELLO!'), 'ci anchored miss');
end;

procedure TestRegexFlagsPublicContract;
var
  R: TRegex;
  M: TMatch;
  MA: TMatchArray;
  LInput: string;
begin
  LInput := 'alpha' + #10 + 'beta';

  R := TRegex.Compile('a.b');
  Check(not R.IsMatch('a' + #10 + 'b'), 'default dot excludes LF');
  R := TRegex.Compile('a.b', [rfDotAll]);
  Check(R.IsMatch('a' + #10 + 'b'), 'rfDotAll lets dot match LF');

  R := TRegex.Compile('^beta');
  Check(not R.IsMatch(LInput), 'default ^ matches only input start');
  R := TRegex.Compile('^beta', [rfMultiLine]);
  M := R.Find(LInput);
  Check(M.Found, 'rfMultiLine ^ finds second line');
  CheckEqual(Int64(6), Int64(M.Start), 'rfMultiLine ^ match start');
  CheckEqual('beta', M.Value(LInput), 'rfMultiLine ^ match value');

  R := TRegex.Compile('alpha$');
  Check(not R.IsMatch(LInput), 'default $ matches only input end');
  R := TRegex.Compile('alpha$', [rfMultiLine]);
  Check(R.IsMatch(LInput), 'rfMultiLine $ matches before LF');

  R := TRegex.Compile('^.', [rfMultiLine]);
  MA := R.FindAll(LInput);
  CheckEqual(Int64(2), Int64(Length(MA)), 'rfMultiLine FindAll line starts');
  CheckEqual('a', MA[0].Value(LInput), 'rfMultiLine first line start');
  CheckEqual('b', MA[1].Value(LInput), 'rfMultiLine second line start');
end;

{ --- Greedy vs Non-Greedy --- }
{ POSIX leftmost-longest: non-greedy affects thread priority but the engine
  still reports the longest match at the leftmost position. }
procedure TestGreedyVsNonGreedy;
var R: TRegex; M: TMatch;
begin
  // a* vs a*? on 'aaa' — POSIX: both match 'aaa' (longest at pos 0)
  R := TRegex.Compile('a*');
  M := R.Find('aaa');
  Check(M.Found, 'a* found');
  CheckEqual('aaa', M.Value('aaa'), 'a* greedy longest');

  R := TRegex.Compile('a*?');
  M := R.Find('aaa');
  Check(M.Found, 'a*? found');
  // POSIX leftmost-longest: even non-greedy picks longest at leftmost
  CheckEqual('aaa', M.Value('aaa'), 'a*? POSIX longest');

  // .+ vs .+? on 'abc'
  R := TRegex.Compile('.+');
  M := R.Find('abc');
  Check(M.Found, '.+ found');
  CheckEqual('abc', M.Value('abc'), '.+ greedy');

  R := TRegex.Compile('.+?');
  M := R.Find('abc');
  Check(M.Found, '.+? found');
  CheckEqual('abc', M.Value('abc'), '.+? POSIX longest');

  // a{2,5} vs a{2,5}? on 'aaaaa'
  R := TRegex.Compile('a{2,5}');
  M := R.Find('aaaaa');
  Check(M.Found, 'a{2,5} found');
  CheckEqual('aaaaa', M.Value('aaaaa'), 'a{2,5} greedy');

  R := TRegex.Compile('a{2,5}?');
  M := R.Find('aaaaa');
  Check(M.Found, 'a{2,5}? found');
  CheckEqual('aaaaa', M.Value('aaaaa'), 'a{2,5}? POSIX longest');

  // Nested captures: (a+)(a+) on 'aaaa' — POSIX leftmost-longest
  R := TRegex.Compile('(a+)(a+)');
  M := R.Find('aaaa');
  Check(M.Found, 'nested greedy found');
  CheckEqual('aaaa', M.Value('aaaa'), 'nested greedy full');
  CheckEqual(Int64(2), Int64(Length(M.Groups)), 'nested greedy groups');

  // Non-greedy with groups: (a+?)(a+) on 'aaaa'
  R := TRegex.Compile('(a+?)(a+)');
  M := R.Find('aaaa');
  Check(M.Found, 'non-greedy group found');
  CheckEqual('aaaa', M.Value('aaaa'), 'non-greedy group full');
  CheckEqual(Int64(2), Int64(Length(M.Groups)), 'non-greedy group count');

  // .* vs .*? on empty string
  R := TRegex.Compile('.*');
  M := R.Find('');
  Check(M.Found, '.* empty found');
  CheckEqual(Int64(0), Int64(M.Len), '.* empty len');

  R := TRegex.Compile('.*?');
  M := R.Find('');
  Check(M.Found, '.*? empty found');
  CheckEqual(Int64(0), Int64(M.Len), '.*? empty len');
end;

{ --- Capture Group Edge Cases --- }
procedure TestCaptureEdgeCases;
var R: TRegex; M: TMatch;
begin
  // Optional group that doesn't match: (a)?(b) on 'b'
  R := TRegex.Compile('(a)?(b)');
  M := R.Find('b');
  Check(M.Found, 'optional group found');
  CheckEqual('b', M.Value('b'), 'optional group value');
  CheckEqual(Int64(2), Int64(Length(M.Groups)), 'optional group count');
  Check(not M.Groups[0].Found, 'optional group 0 not found');
  Check(M.Groups[1].Found, 'optional group 1 found');
  CheckEqual('b', M.Groups[1].Value('b'), 'optional group 1 value');

  // Nested captures: ((a)(b)) on 'ab' — 3 groups
  R := TRegex.Compile('((a)(b))');
  M := R.Find('ab');
  Check(M.Found, 'nested capture found');
  CheckEqual('ab', M.Value('ab'), 'nested capture full');
  CheckEqual(Int64(3), Int64(Length(M.Groups)), 'nested capture count');
  CheckEqual('ab', M.Groups[0].Value('ab'), 'nested group 0');
  CheckEqual('a', M.Groups[1].Value('ab'), 'nested group 1');
  CheckEqual('b', M.Groups[2].Value('ab'), 'nested group 2');

  // Alternation in capture: (a|bb) on 'bb'
  R := TRegex.Compile('(a|bb)');
  M := R.Find('bb');
  Check(M.Found, 'alt capture found');
  CheckEqual('bb', M.Value('bb'), 'alt capture value');
  CheckEqual(Int64(1), Int64(Length(M.Groups)), 'alt capture count');
  CheckEqual('bb', M.Groups[0].Value('bb'), 'alt capture group');

  // Multiple named groups: (?P<x>a)(?P<y>b) on 'ab'
  R := TRegex.Compile('(?P<x>a)(?P<y>b)');
  M := R.Find('ab');
  Check(M.Found, 'multi named found');
  Check(R.GroupByName(M, 'x').Found, 'named x found');
  CheckEqual('a', R.GroupByName(M, 'x').Value('ab'), 'named x value');
  Check(R.GroupByName(M, 'y').Found, 'named y found');
  CheckEqual('b', R.GroupByName(M, 'y').Value('ab'), 'named y value');

  // Group index consistency with named + unnamed mixed
  R := TRegex.Compile('(a)(?P<mid>b)(c)');
  M := R.Find('abc');
  Check(M.Found, 'mixed groups found');
  CheckEqual(Int64(3), Int64(Length(M.Groups)), 'mixed groups count');
  CheckEqual('a', M.Groups[0].Value('abc'), 'mixed group 0');
  CheckEqual('b', M.Groups[1].Value('abc'), 'mixed group 1');
  CheckEqual('c', M.Groups[2].Value('abc'), 'mixed group 2');
  CheckEqual(Int64(1), Int64(R.GroupIndexByName('mid')), 'mixed named index');

  // Empty capture group: ()(b) on 'b'
  R := TRegex.Compile('()(b)');
  M := R.Find('b');
  Check(M.Found, 'empty capture found');
  CheckEqual(Int64(2), Int64(Length(M.Groups)), 'empty capture count');
  CheckEqual(Int64(0), Int64(M.Groups[0].Len), 'empty capture group 0 len');
  Check(M.Groups[1].Found, 'empty capture group 1 found');
  CheckEqual('b', M.Groups[1].Value('b'), 'empty capture group 1 value');
end;

{ --- FindAll Edge Cases --- }
procedure TestFindAllEdgeCases;
var R: TRegex; MA: TMatchArray;
begin
  // Adjacent matches: 'a' on 'aaa' — 3 matches
  R := TRegex.Compile('a');
  MA := R.FindAll('aaa');
  CheckEqual(Int64(3), Int64(Length(MA)), 'adjacent count');
  CheckEqual('a', MA[0].Value('aaa'), 'adjacent 0');
  CheckEqual('a', MA[1].Value('aaa'), 'adjacent 1');
  CheckEqual('a', MA[2].Value('aaa'), 'adjacent 2');

  // Non-overlapping: 'aa' on 'aaaa' — should be 2
  R := TRegex.Compile('aa');
  MA := R.FindAll('aaaa');
  CheckEqual(Int64(2), Int64(Length(MA)), 'non-overlap count');
  CheckEqual(Int64(0), Int64(MA[0].Start), 'non-overlap 0 start');
  CheckEqual(Int64(2), Int64(MA[1].Start), 'non-overlap 1 start');

  // No matches at all
  R := TRegex.Compile('xyz');
  MA := R.FindAll('abc');
  CheckEqual(Int64(0), Int64(Length(MA)), 'no matches');

  // Single char input
  R := TRegex.Compile('a');
  MA := R.FindAll('a');
  CheckEqual(Int64(1), Int64(Length(MA)), 'single char count');

  // Pattern longer than input
  R := TRegex.Compile('abcdef');
  MA := R.FindAll('abc');
  CheckEqual(Int64(0), Int64(Length(MA)), 'pattern longer');

  // Multiple digit groups
  R := TRegex.Compile('\d+');
  MA := R.FindAll('12 34 56');
  CheckEqual(Int64(3), Int64(Length(MA)), 'multi digit count');
  CheckEqual('12', MA[0].Value('12 34 56'), 'multi digit 0');
  CheckEqual('34', MA[1].Value('12 34 56'), 'multi digit 1');
  CheckEqual('56', MA[2].Value('12 34 56'), 'multi digit 2');

  // FindAll with captures
  R := TRegex.Compile('(\w+)=(\d+)');
  MA := R.FindAll('a=1 b=2 c=3');
  CheckEqual(Int64(3), Int64(Length(MA)), 'findall captures count');
  CheckEqual(Int64(2), Int64(Length(MA[0].Groups)), 'findall captures groups');
  CheckEqual('a', MA[0].Groups[0].Value('a=1 b=2 c=3'), 'findall cap 0.0');
  CheckEqual('1', MA[0].Groups[1].Value('a=1 b=2 c=3'), 'findall cap 0.1');
  CheckEqual('b', MA[1].Groups[0].Value('a=1 b=2 c=3'), 'findall cap 1.0');
  CheckEqual('2', MA[1].Groups[1].Value('a=1 b=2 c=3'), 'findall cap 1.1');
end;

{ --- Replace Edge Cases --- }
procedure TestReplaceEdgeCases;
var R: TRegex; s: string;
begin
  // Replace with empty string (deletion)
  R := TRegex.Compile('\d+');
  s := R.ReplaceAll('a1b2c3', '');
  CheckEqual('abc', s, 'replace delete');

  // ReplaceFirst when pattern matches at position 0
  R := TRegex.Compile('\w+');
  s := R.ReplaceFirst('hello world', 'X');
  CheckEqual('X world', s, 'replace first at 0');

  // ReplaceAll with pattern that matches entire input
  // .* matches 'hello' then empty string at end (2 matches, same as Go)
  R := TRegex.Compile('.*');
  s := R.ReplaceAll('hello', 'X');
  CheckEqual('XX', s, 'replace entire input');

  // Replacement contains regex metacharacters (should be literal)
  R := TRegex.Compile('x');
  s := R.ReplaceAll('x', '.*+?()[]{}|^$');
  CheckEqual('.*+?()[]{}|^$', s, 'replace literal metachar');

  // ReplaceAllExpand with $0 on pattern without captures
  R := TRegex.Compile('\d+');
  s := R.ReplaceAllExpand('num=42', '[$0]');
  CheckEqual('num=[42]', s, 'expand $0 no captures');

  // ReplaceAllExpand with out-of-range $9
  R := TRegex.Compile('(a)');
  s := R.ReplaceAllExpand('a', '$9');
  CheckEqual('', s, 'expand $9 out of range');

  // ReplaceAll no match returns input unchanged
  R := TRegex.Compile('xyz');
  s := R.ReplaceAll('hello', 'X');
  CheckEqual('hello', s, 'replace no match');

  // ReplaceFirst no match returns input unchanged
  s := R.ReplaceFirst('hello', 'X');
  CheckEqual('hello', s, 'replace first no match');

  // Multiple replacements with captures
  R := TRegex.Compile('(\w+)=(\w+)');
  s := R.ReplaceAllExpand('a=1 b=2', '$2=$1');
  CheckEqual('1=a 2=b', s, 'expand swap');
end;

{ --- Split Edge Cases --- }
procedure TestSplitEdgeCases;
var R: TRegex; parts: TStringArray;
begin
  // Delimiter at start: ',a,b' split on ','
  R := TRegex.Compile(',');
  parts := R.Split(',a,b');
  CheckEqual(Int64(3), Int64(Length(parts)), 'delim at start count');
  CheckEqual('', parts[0], 'delim at start [0]');
  CheckEqual('a', parts[1], 'delim at start [1]');
  CheckEqual('b', parts[2], 'delim at start [2]');

  // Delimiter at end: 'a,b,' split on ','
  parts := R.Split('a,b,');
  CheckEqual(Int64(3), Int64(Length(parts)), 'delim at end count');
  CheckEqual('a', parts[0], 'delim at end [0]');
  CheckEqual('b', parts[1], 'delim at end [1]');
  CheckEqual('', parts[2], 'delim at end [2]');

  // Consecutive delimiters: 'a,,b' split on ','
  parts := R.Split('a,,b');
  CheckEqual(Int64(3), Int64(Length(parts)), 'consecutive count');
  CheckEqual('a', parts[0], 'consecutive [0]');
  CheckEqual('', parts[1], 'consecutive [1]');
  CheckEqual('b', parts[2], 'consecutive [2]');

  // Pattern doesn't match at all
  R := TRegex.Compile('xyz');
  parts := R.Split('hello world');
  CheckEqual(Int64(1), Int64(Length(parts)), 'no match count');
  CheckEqual('hello world', parts[0], 'no match value');

  // Split with limit=1 (just first split)
  R := TRegex.Compile(',');
  parts := R.Split('a,b,c,d', 1);
  CheckEqual(Int64(2), Int64(Length(parts)), 'limit 1 count');
  CheckEqual('a', parts[0], 'limit 1 [0]');
  CheckEqual('b,c,d', parts[1], 'limit 1 [1]');

  // Split empty input
  R := TRegex.Compile(',');
  parts := R.Split('');
  CheckEqual(Int64(1), Int64(Length(parts)), 'empty input count');
  CheckEqual('', parts[0], 'empty input value');

  // Multi-char delimiter
  R := TRegex.Compile('::');
  parts := R.Split('a::b::c');
  CheckEqual(Int64(3), Int64(Length(parts)), 'multi delim count');
  CheckEqual('a', parts[0], 'multi delim [0]');
  CheckEqual('b', parts[1], 'multi delim [1]');
  CheckEqual('c', parts[2], 'multi delim [2]');
end;

{ --- Char Class Edge Cases --- }
procedure TestCharClassEdgeCases;
var R: TRegex; M: TMatch; err: string;
begin
  // Dash at end: [abc-] — dash is literal
  R := TRegex.Compile('[abc-]');
  Check(R.IsMatch('a'), 'dash end a');
  Check(R.IsMatch('-'), 'dash end -');
  Check(not R.IsMatch('x'), 'dash end miss');

  // Caret not first: [a^b] — ^ is literal
  R := TRegex.Compile('[a^b]');
  Check(R.IsMatch('a'), 'caret literal a');
  Check(R.IsMatch('^'), 'caret literal ^');
  Check(R.IsMatch('b'), 'caret literal b');
  Check(not R.IsMatch('x'), 'caret literal miss');

  // Range with same char: [a-a]
  R := TRegex.Compile('[a-a]');
  Check(R.IsMatch('a'), 'same range match');
  Check(not R.IsMatch('b'), 'same range miss');

  // Multiple ranges: [a-zA-Z0-9]
  R := TRegex.Compile('[a-zA-Z0-9]+');
  Check(R.IsFullMatch('helloWorld123'), 'multi range match');
  Check(not R.IsFullMatch('hello world'), 'multi range space');

  // Negated with range: [^a-z]
  R := TRegex.Compile('[^a-z]');
  Check(R.IsMatch('A'), 'negated range upper');
  Check(R.IsMatch('5'), 'negated range digit');
  Check(not R.IsMatch('a'), 'negated range lower');

  // Special chars in class: [.*+?] — metacharacters are literal inside []
  R := TRegex.Compile('[.*+?]');
  Check(R.IsMatch('.'), 'class dot');
  Check(R.IsMatch('*'), 'class star');
  Check(R.IsMatch('+'), 'class plus');
  Check(R.IsMatch('?'), 'class question');
  Check(not R.IsMatch('a'), 'class meta miss');

  // Escaped chars in class: [\d\s]
  R := TRegex.Compile('[\d\s]+');
  Check(R.IsFullMatch('123 456'), 'class shorthand');
  Check(not R.IsFullMatch('abc'), 'class shorthand miss');

  // Negated shorthand escapes in class: [\D\W\S]
  R := TRegex.Compile('^[\D]$');
  Check(R.IsFullMatch('a'), 'class \D matches non-digit');
  Check(not R.IsFullMatch('5'), 'class \D rejects digit');

  R := TRegex.Compile('^[\W]$');
  Check(R.IsFullMatch(' '), 'class \W matches non-word');
  Check(not R.IsFullMatch('x'), 'class \W rejects word');

  R := TRegex.Compile('^[\S]$');
  Check(R.IsFullMatch('x'), 'class \S matches non-space');
  Check(not R.IsFullMatch(' '), 'class \S rejects space');

  // Pipe in class: [a|b] — | is literal
  R := TRegex.Compile('[a|b]');
  Check(R.IsMatch('a'), 'pipe class a');
  Check(R.IsMatch('|'), 'pipe class |');
  Check(R.IsMatch('b'), 'pipe class b');
end;

{ --- Anchor Edge Cases --- }
procedure TestAnchorEdgeCases;
var R: TRegex; M: TMatch;
begin
  // ^$ on empty string — should match
  R := TRegex.Compile('^$');
  Check(R.IsMatch(''), '^$ empty match');
  Check(not R.IsMatch('a'), '^$ non-empty miss');

  // ^ alone
  R := TRegex.Compile('^');
  Check(R.IsMatch(''), '^ empty');
  Check(R.IsMatch('abc'), '^ any');

  // $ alone
  R := TRegex.Compile('$');
  Check(R.IsMatch(''), '$ empty');
  Check(R.IsMatch('abc'), '$ any');

  // \b at start and end of input
  R := TRegex.Compile('\bfoo\b');
  Check(R.IsMatch('foo'), 'wb exact');
  Check(R.IsMatch('foo bar'), 'wb start');
  Check(R.IsMatch('bar foo'), 'wb end');
  Check(not R.IsMatch('foobar'), 'wb prefix');
  Check(not R.IsMatch('barfoo'), 'wb suffix');

  // \b with non-word chars: \bword\b in "!word!"
  R := TRegex.Compile('\bword\b');
  Check(R.IsMatch('!word!'), 'wb punct');
  Check(R.IsMatch(' word '), 'wb space');
  Check(R.IsMatch('(word)'), 'wb parens');

  // \B (non-word boundary)
  R := TRegex.Compile('\Boo\B');
  Check(R.IsMatch('foobar'), 'nwb inside');
  Check(not R.IsMatch('oo'), 'nwb standalone');
  Check(not R.IsMatch('foo'), 'nwb at end');

  // Anchors with quantifiers
  R := TRegex.Compile('^a+$');
  Check(R.IsMatch('aaa'), 'anchor quant match');
  Check(not R.IsMatch('aab'), 'anchor quant miss');
  Check(not R.IsMatch(''), 'anchor quant empty');
end;

{ --- Escape Edge Cases --- }
procedure TestEscapeEdgeCases;
var R: TRegex; M: TMatch;
begin
  // All metacharacters escaped individually
  R := TRegex.Compile('\.');
  Check(R.IsMatch('.'), 'esc dot');
  Check(not R.IsMatch('a'), 'esc dot miss');

  R := TRegex.Compile('\*');
  Check(R.IsMatch('*'), 'esc star');
  Check(not R.IsMatch('a'), 'esc star miss');

  R := TRegex.Compile('\+');
  Check(R.IsMatch('+'), 'esc plus');

  R := TRegex.Compile('\?');
  Check(R.IsMatch('?'), 'esc question');

  R := TRegex.Compile('\(');
  Check(R.IsMatch('('), 'esc lparen');

  R := TRegex.Compile('\)');
  Check(R.IsMatch(')'), 'esc rparen');

  R := TRegex.Compile('\[');
  Check(R.IsMatch('['), 'esc lbracket');

  R := TRegex.Compile('\]');
  Check(R.IsMatch(']'), 'esc rbracket');

  R := TRegex.Compile('\{');
  Check(R.IsMatch('{'), 'esc lbrace');

  R := TRegex.Compile('\}');
  Check(R.IsMatch('}'), 'esc rbrace');

  R := TRegex.Compile('\|');
  Check(R.IsMatch('|'), 'esc pipe');
  Check(not R.IsMatch('a'), 'esc pipe miss');

  R := TRegex.Compile('\^');
  Check(R.IsMatch('^'), 'esc caret');

  R := TRegex.Compile('\$');
  Check(R.IsMatch('$'), 'esc dollar');

  R := TRegex.Compile('\\');
  Check(R.IsMatch('\'), 'esc backslash');

  // \n \r \t
  R := TRegex.Compile('\n');
  Check(R.IsMatch(#10), 'esc newline');
  Check(not R.IsMatch('n'), 'esc newline not literal');

  R := TRegex.Compile('\r');
  Check(R.IsMatch(#13), 'esc cr');

  R := TRegex.Compile('\t');
  Check(R.IsMatch(#9), 'esc tab');

  // Escaped digit is literal
  R := TRegex.Compile('\1');
  Check(R.IsMatch('1'), 'esc digit literal');
end;

{ --- IsFullMatch Edge Cases --- }
procedure TestIsFullMatchEdgeCases;
var R: TRegex;
begin
  // Empty pattern on empty input — true (empty matches empty fully)
  R := TRegex.Compile('');
  Check(R.IsFullMatch(''), 'empty on empty');
  // Empty pattern on non-empty — false
  Check(not R.IsFullMatch('a'), 'empty on non-empty');

  // .* on anything — true
  R := TRegex.Compile('.*');
  Check(R.IsFullMatch(''), 'dotstar empty');
  Check(R.IsFullMatch('anything goes here'), 'dotstar any');

  // .+ on empty — false
  R := TRegex.Compile('.+');
  Check(not R.IsFullMatch(''), 'dotplus empty');
  Check(R.IsFullMatch('a'), 'dotplus single');
  Check(R.IsFullMatch('abc'), 'dotplus multi');

  // Partial match exists but not full: \d+ on 'abc123'
  R := TRegex.Compile('\d+');
  Check(not R.IsFullMatch('abc123'), 'partial not full');
  Check(R.IsFullMatch('123'), 'digits full');

  // Pattern with anchors: ^hello$ — same as IsFullMatch('hello')
  R := TRegex.Compile('^hello$');
  Check(R.IsFullMatch('hello'), 'anchored full');
  Check(not R.IsFullMatch('hello!'), 'anchored miss');

  // Alternation full match
  R := TRegex.Compile('cat|dog|bird');
  Check(R.IsFullMatch('cat'), 'alt full cat');
  Check(R.IsFullMatch('dog'), 'alt full dog');
  Check(R.IsFullMatch('bird'), 'alt full bird');
  Check(not R.IsFullMatch('cats'), 'alt full miss');

  // Quantifier full match
  R := TRegex.Compile('[a-z]{3,5}');
  Check(R.IsFullMatch('abc'), 'quant full 3');
  Check(R.IsFullMatch('abcde'), 'quant full 5');
  Check(not R.IsFullMatch('ab'), 'quant full too short');
  Check(not R.IsFullMatch('abcdef'), 'quant full too long');
end;

{ --- Case Insensitive Edge Cases --- }
procedure TestCaseInsensitiveEdgeCases;
var R: TRegex; M: TMatch; MA: TMatchArray;
begin
  // (?i) with char class ranges: [a-z] should match A-Z
  R := TRegex.Compile('(?i)[a-z]+');
  Check(R.IsFullMatch('ABC'), 'ci range upper');
  Check(R.IsFullMatch('abc'), 'ci range lower');
  Check(R.IsFullMatch('AbCdEf'), 'ci range mixed');

  // (?i) with negated class: [^a-z] should not match A-Z
  R := TRegex.Compile('(?i)[^a-z]');
  Check(not R.IsMatch('A'), 'ci neg range upper');
  Check(not R.IsMatch('a'), 'ci neg range lower');
  Check(R.IsMatch('1'), 'ci neg range digit');
  Check(R.IsMatch('!'), 'ci neg range punct');

  // (?i) with alternation: (?i)cat|dog — both case-insensitive
  R := TRegex.Compile('(?i)cat|dog');
  Check(R.IsMatch('CAT'), 'ci alt CAT');
  Check(R.IsMatch('DOG'), 'ci alt DOG');
  Check(R.IsMatch('Cat'), 'ci alt Cat');
  Check(R.IsMatch('dOg'), 'ci alt dOg');

  // (?i) with quantifiers: (?i)a{3} matches AAA, aAa, etc.
  R := TRegex.Compile('(?i)a{3}');
  Check(R.IsMatch('aaa'), 'ci quant lower');
  Check(R.IsMatch('AAA'), 'ci quant upper');
  Check(R.IsMatch('aAa'), 'ci quant mixed');
  Check(not R.IsMatch('aa'), 'ci quant too few');

  // Non-letter chars unaffected: (?i)a.b matches a1b, A1B
  R := TRegex.Compile('(?i)a.b');
  Check(R.IsMatch('a1b'), 'ci dot lower');
  Check(R.IsMatch('A1B'), 'ci dot upper');
  Check(R.IsMatch('A.B'), 'ci dot punct');

  // (?i) with named groups
  R := TRegex.Compile('(?i)(?P<word>[a-z]+)');
  M := R.Find('HELLO');
  Check(M.Found, 'ci named found');
  CheckEqual('HELLO', M.Value('HELLO'), 'ci named value');
  Check(R.GroupByName(M, 'word').Found, 'ci named group found');
  CheckEqual('HELLO', R.GroupByName(M, 'word').Value('HELLO'), 'ci named group value');

  // Flag overload: rfCaseInsensitive
  R := TRegex.Compile('[a-z]+', [rfCaseInsensitive]);
  Check(R.IsFullMatch('HELLO'), 'flag ci full');
  Check(R.IsFullMatch('hello'), 'flag ci lower');

  // (?i) with word boundary
  R := TRegex.Compile('(?i)\bhello\b');
  Check(R.IsMatch('HELLO world'), 'ci wb upper');
  Check(R.IsMatch('say Hello!'), 'ci wb mixed');
  Check(not R.IsMatch('HELLOWORLD'), 'ci wb no boundary');
end;

{ --- Performance Regression Tests --- }
procedure TestPerformanceRegression;
var R: TRegex; input: string; i: Integer; pat: string;
begin
  // Pathological: a?^n a^n on n=20 — must complete fast (Thompson guarantee)
  pat := '';
  for i := 1 to 20 do pat := pat + 'a?';
  for i := 1 to 20 do pat := pat + 'a';
  R := TRegex.Compile(pat);
  input := '';
  for i := 1 to 20 do input := input + 'a';
  Check(R.IsMatch(input), 'pathological 20 match');

  // Many alternations: a|b|c|...|z on long input
  pat := 'a';
  for i := Ord('b') to Ord('z') do
    pat := pat + '|' + Chr(i);
  R := TRegex.Compile(pat);
  SetLength(input, 1000);
  for i := 1 to 1000 do input[i] := '0';
  input[999] := 'z';
  Check(R.IsMatch(input), 'many alts match');

  // Long literal on long input
  pat := 'abcdefghijklmnopqrstuvwxyz';
  R := TRegex.Compile(pat);
  SetLength(input, 10000);
  for i := 1 to 10000 do input[i] := 'x';
  Move(pat[1], input[9975], 26);
  Check(R.IsMatch(input), 'long literal match');

  // Many captures: (\d)(\d)(\d)(\d)(\d) on digits
  R := TRegex.Compile('(\d)(\d)(\d)(\d)(\d)');
  input := '12345';
  Check(R.IsMatch(input), 'many captures match');
  CheckEqual(Int64(5), Int64(R.NumCaptures), 'many captures count');

  // Nested groups at depth
  pat := '';
  for i := 1 to 50 do pat := pat + '(';
  pat := pat + 'a';
  for i := 1 to 50 do pat := pat + ')';
  R := TRegex.Compile(pat);
  Check(R.IsMatch('a'), 'deep nesting match');
  CheckEqual(Int64(50), Int64(R.NumCaptures), 'deep nesting captures');
end;

{ --- QuoteMeta Thorough --- }
procedure TestQuoteMetaThorough;
var s: string; R: TRegex;
begin
  // Every single metacharacter individually
  CheckEqual('\.', RegexQuoteMeta('.'), 'qm dot');
  CheckEqual('\+', RegexQuoteMeta('+'), 'qm plus');
  CheckEqual('\*', RegexQuoteMeta('*'), 'qm star');
  CheckEqual('\?', RegexQuoteMeta('?'), 'qm question');
  CheckEqual('\(', RegexQuoteMeta('('), 'qm lparen');
  CheckEqual('\)', RegexQuoteMeta(')'), 'qm rparen');
  CheckEqual('\[', RegexQuoteMeta('['), 'qm lbracket');
  CheckEqual('\]', RegexQuoteMeta(']'), 'qm rbracket');
  CheckEqual('\{', RegexQuoteMeta('{'), 'qm lbrace');
  CheckEqual('\}', RegexQuoteMeta('}'), 'qm rbrace');
  CheckEqual('\|', RegexQuoteMeta('|'), 'qm pipe');
  CheckEqual('\^', RegexQuoteMeta('^'), 'qm caret');
  CheckEqual('\$', RegexQuoteMeta('$'), 'qm dollar');
  CheckEqual('\\', RegexQuoteMeta('\'), 'qm backslash');

  // String with no metacharacters (unchanged)
  CheckEqual('hello', RegexQuoteMeta('hello'), 'qm plain');
  CheckEqual('123', RegexQuoteMeta('123'), 'qm digits');

  // Empty string
  CheckEqual('', RegexQuoteMeta(''), 'qm empty');

  // String that is ALL metacharacters
  s := RegexQuoteMeta('.*+?()[]{}|^$\');
  CheckEqual('\.\*\+\?\(\)\[\]\{\}\|\^\$\\', s, 'qm all meta');

  // QuoteMeta result used in Compile — should match literally
  s := '.*+?()[]{}|^$';
  R := TRegex.Compile(RegexQuoteMeta(s));
  Check(R.IsMatch(s), 'qm compile match');
  Check(not R.IsMatch('anything else'), 'qm compile miss');

  // Mixed content
  s := RegexQuoteMeta('price: $42.00 (USD)');
  R := TRegex.Compile(s);
  Check(R.IsMatch('price: $42.00 (USD)'), 'qm mixed match');
  Check(not R.IsMatch('price: X42Y00 ZUSDZ'), 'qm mixed miss');
end;

{ --- ReplaceFunc Edge Cases --- }
function EmptyReplace(const AInput: string; const AMatch: TMatch): string;
begin
  Result := '';
end;

function StarReplace(const AInput: string; const AMatch: TMatch): string;
var i: SizeInt;
begin
  Result := '';
  for i := 1 to AMatch.Len do
    Result := Result + '*';
end;

function GroupReplace(const AInput: string; const AMatch: TMatch): string;
begin
  if Length(AMatch.Groups) > 0 then
    Result := '[' + AMatch.Groups[0].Value(AInput) + ']'
  else
    Result := '[]';
end;

procedure TestReplaceFuncEdgeCases;
var R: TRegex; s: string;
begin
  // Func that returns empty string (deletion)
  R := TRegex.Compile('\d+');
  s := R.ReplaceAllFunc('a1b2c3', @EmptyReplace);
  CheckEqual('abc', s, 'func empty delete');

  // Func that uses match length (star mask)
  R := TRegex.Compile('\w+');
  s := R.ReplaceAllFunc('hi world', @StarReplace);
  CheckEqual('** *****', s, 'func star mask');

  // Func that accesses groups
  R := TRegex.Compile('(\w+)=\w+');
  s := R.ReplaceAllFunc('x=1 y=2', @GroupReplace);
  CheckEqual('[x] [y]', s, 'func group access');

  // ReplaceFirstFunc when no match (returns input unchanged)
  R := TRegex.Compile('xyz');
  s := R.ReplaceFirstFunc('hello', @EmptyReplace);
  CheckEqual('hello', s, 'func no match');

  // ReplaceAllFunc with many matches
  R := TRegex.Compile('\d');
  s := R.ReplaceAllFunc('1234567890', @StarReplace);
  CheckEqual('**********', s, 'func many matches');

  // ReplaceFirstFunc only replaces first
  R := TRegex.Compile('\d+');
  s := R.ReplaceFirstFunc('a1b2c3', @StarReplace);
  CheckEqual('a*b2c3', s, 'func first only');
end;

procedure ExpectReplaceFuncNilCallbackError(const ACase: string; AUseAll: Boolean);
var
  R: TRegex;
  LRaised: Boolean;
begin
  R := TRegex.Compile('\d+');
  LRaised := False;
  try
    if AUseAll then
      R.ReplaceAllFunc('a1b2', nil)
    else
      R.ReplaceFirstFunc('a1b2', nil);
  except
    on E: ERegexError do
      LRaised := True;
  end;
  Check(LRaised, ACase);
end;

procedure TestReplaceFuncNilCallback;
begin
  ExpectReplaceFuncNilCallbackError('ReplaceFirstFunc nil callback rejected', False);
  ExpectReplaceFuncNilCallbackError('ReplaceAllFunc nil callback rejected', True);
end;

{ === NEW TEST PROCEDURES === }

{ --- 1. TestMultipleCaptures --- }
procedure TestMultipleCaptures;
var R: TRegex; M: TMatch;
begin
  // Pattern with 5+ capture groups
  R := TRegex.Compile('(a)(b)(c)(d)(e)(f)');
  M := R.Find('abcdef');
  Check(M.Found, '6 groups found');
  CheckEqual('abcdef', M.Value('abcdef'), '6 groups full');
  CheckEqual(Int64(6), Int64(Length(M.Groups)), '6 groups count');
  CheckEqual('a', M.Groups[0].Value('abcdef'), '6g group 0');
  CheckEqual('b', M.Groups[1].Value('abcdef'), '6g group 1');
  CheckEqual('c', M.Groups[2].Value('abcdef'), '6g group 2');
  CheckEqual('d', M.Groups[3].Value('abcdef'), '6g group 3');
  CheckEqual('e', M.Groups[4].Value('abcdef'), '6g group 4');
  CheckEqual('f', M.Groups[5].Value('abcdef'), '6g group 5');

  // Captures inside alternation: (a)|(b) on 'b' — group 0 not found, group 1 found
  R := TRegex.Compile('(a)|(b)');
  M := R.Find('b');
  Check(M.Found, 'alt cap found');
  CheckEqual('b', M.Value('b'), 'alt cap value');
  CheckEqual(Int64(2), Int64(Length(M.Groups)), 'alt cap count');
  Check(not M.Groups[0].Found, 'alt cap group 0 not found');
  Check(M.Groups[1].Found, 'alt cap group 1 found');
  CheckEqual('b', M.Groups[1].Value('b'), 'alt cap group 1 value');

  // Captures inside repetition: ((ab)+) on 'ababab'
  // Outer captures full, inner captures last iteration
  R := TRegex.Compile('((ab)+)');
  M := R.Find('ababab');
  Check(M.Found, 'rep cap found');
  CheckEqual('ababab', M.Value('ababab'), 'rep cap full');
  CheckEqual(Int64(2), Int64(Length(M.Groups)), 'rep cap count');
  CheckEqual('ababab', M.Groups[0].Value('ababab'), 'rep cap outer');
  CheckEqual('ab', M.Groups[1].Value('ababab'), 'rep cap inner last');

  // Nested alternation with captures: ((a|b)(c|d)) on 'ad'
  R := TRegex.Compile('((a|b)(c|d))');
  M := R.Find('ad');
  Check(M.Found, 'nested alt found');
  CheckEqual('ad', M.Value('ad'), 'nested alt full');
  CheckEqual(Int64(3), Int64(Length(M.Groups)), 'nested alt count');
  CheckEqual('ad', M.Groups[0].Value('ad'), 'nested alt group 0');
  CheckEqual('a', M.Groups[1].Value('ad'), 'nested alt group 1');
  CheckEqual('d', M.Groups[2].Value('ad'), 'nested alt group 2');

  // Optional captures in sequence: (a)?(b)?(c)? on 'ac'
  R := TRegex.Compile('(a)?(b)?(c)?');
  M := R.Find('ac');
  Check(M.Found, 'opt seq found');
  CheckEqual('ac', M.Value('ac'), 'opt seq full');
  CheckEqual(Int64(3), Int64(Length(M.Groups)), 'opt seq count');
  Check(M.Groups[0].Found, 'opt seq group 0 found');
  CheckEqual('a', M.Groups[0].Value('ac'), 'opt seq group 0 val');
  Check(not M.Groups[1].Found, 'opt seq group 1 not found');
  Check(M.Groups[2].Found, 'opt seq group 2 found');
  CheckEqual('c', M.Groups[2].Value('ac'), 'opt seq group 2 val');
end;

{ --- 2. TestOverlappingPatterns --- }
procedure TestOverlappingPatterns;
var R: TRegex; M: TMatch;
begin
  // a.*a on 'abcabc' — greedy, matches 'abca' (leftmost-longest)
  R := TRegex.Compile('a.*a');
  M := R.Find('abcabc');
  Check(M.Found, 'a.*a found');
  CheckEqual('abca', M.Value('abcabc'), 'a.*a greedy');

  // a.*?a on 'abcabc' — POSIX still matches 'abca' (leftmost-longest)
  R := TRegex.Compile('a.*?a');
  M := R.Find('abcabc');
  Check(M.Found, 'a.*?a found');
  CheckEqual('abca', M.Value('abcabc'), 'a.*?a POSIX longest');

  // (a+)(a+) on 'aaaa' — POSIX: first gets max → (aaa)(a)
  R := TRegex.Compile('(a+)(a+)');
  M := R.Find('aaaa');
  Check(M.Found, '(a+)(a+) found');
  CheckEqual('aaaa', M.Value('aaaa'), '(a+)(a+) full');
  CheckEqual(Int64(2), Int64(Length(M.Groups)), '(a+)(a+) count');
  CheckEqual('aaa', M.Groups[0].Value('aaaa'), '(a+)(a+) first max');
  CheckEqual('a', M.Groups[1].Value('aaaa'), '(a+)(a+) second min');

  // (.*)(.+) on 'hello' — first gets 'hell', second gets 'o'
  R := TRegex.Compile('(.*)(.+)');
  M := R.Find('hello');
  Check(M.Found, '(.*)(.+) found');
  CheckEqual('hello', M.Value('hello'), '(.*)(.+) full');
  CheckEqual('hell', M.Groups[0].Value('hello'), '(.*)(.+) first');
  CheckEqual('o', M.Groups[1].Value('hello'), '(.*)(.+) second');

  // Nested quantifiers: (a+)+ on 'aaa'
  R := TRegex.Compile('(a+)+');
  M := R.Find('aaa');
  Check(M.Found, '(a+)+ found');
  CheckEqual('aaa', M.Value('aaa'), '(a+)+ full');
  CheckEqual(Int64(1), Int64(Length(M.Groups)), '(a+)+ count');
  CheckEqual('aaa', M.Groups[0].Value('aaa'), '(a+)+ inner');
end;

{ --- 3. TestSpecialInputs --- }
procedure TestSpecialInputs;
var R: TRegex; M: TMatch; MA: TMatchArray; input: string; i: Integer;
begin
  // Input with null bytes: 'a\x00b' — engine handles embedded nulls
  R := TRegex.Compile('a.b');
  Check(R.IsMatch('a'#0'b'), 'null byte dot');
  R := TRegex.Compile('a\x00b');
  // \x00 is not a supported escape, so test literal null via char class
  R := TRegex.Compile('a');
  M := R.Find('a'#0'b');
  Check(M.Found, 'null byte find a');
  CheckEqual('a', M.Value('a'#0'b'), 'null byte find a val');

  // Input with high bytes (128-255): binary data
  input := 'x' + Chr(200) + Chr(255) + 'y';
  R := TRegex.Compile('x..y');
  Check(R.IsMatch(input), 'high bytes dot');
  R := TRegex.Compile('x\w');
  Check(not R.IsMatch(input), 'high bytes not word');

  // Very short inputs: single char
  R := TRegex.Compile('a');
  Check(R.IsMatch('a'), 'single char match');
  Check(not R.IsMatch('b'), 'single char miss');
  M := R.Find('a');
  Check(M.Found, 'single char find');
  CheckEqual(Int64(0), Int64(M.Start), 'single char start');
  CheckEqual(Int64(1), Int64(M.Len), 'single char len');

  // Two char input
  R := TRegex.Compile('ab');
  Check(R.IsMatch('ab'), 'two char match');
  Check(not R.IsMatch('a'), 'two char too short');

  // Input that is all the same character
  input := 'aaaaaaa';
  R := TRegex.Compile('a+');
  M := R.Find(input);
  Check(M.Found, 'all same found');
  CheckEqual(input, M.Value(input), 'all same full');

  R := TRegex.Compile('a{3}');
  MA := R.FindAll(input);
  CheckEqual(Int64(2), Int64(Length(MA)), 'all same {3} count');

  // Input with only special regex chars
  input := '.*+?()[]{}|^$';
  R := TRegex.Compile('\W+');
  Check(R.IsFullMatch(input), 'special chars fullmatch');
  R := TRegex.Compile(RegexQuoteMeta(input));
  Check(R.IsMatch(input), 'special chars quoted');
end;

{ --- 4. TestQuantifierBoundaries --- }
procedure TestQuantifierBoundaries;
var R: TRegex; M: TMatch;
begin
  // a{0} on '' and 'a' — matches empty
  R := TRegex.Compile('a{0}');
  Check(R.IsMatch(''), '{0} empty');
  Check(R.IsMatch('a'), '{0} on a');
  M := R.Find('a');
  CheckEqual(Int64(0), Int64(M.Len), '{0} len=0');

  // a{1} on '' — no match
  R := TRegex.Compile('^a{1}$');
  Check(not R.IsMatch(''), '{1} empty no match');
  Check(R.IsMatch('a'), '{1} one a');

  // a{5} on 'aaaa' — no match (too few)
  R := TRegex.Compile('^a{5}$');
  Check(not R.IsMatch('aaaa'), '{5} too few');
  Check(R.IsMatch('aaaaa'), '{5} exact');

  // a{2,2} — same as a{2}
  R := TRegex.Compile('^a{2,2}$');
  Check(not R.IsMatch('a'), '{2,2} one');
  Check(R.IsMatch('aa'), '{2,2} two');
  Check(not R.IsMatch('aaa'), '{2,2} three');

  // a{0,0} — matches empty only
  R := TRegex.Compile('a{0,0}');
  M := R.Find('a');
  Check(M.Found, '{0,0} found');
  CheckEqual(Int64(0), Int64(M.Len), '{0,0} len=0');

  // a{0,1} — same as a?
  R := TRegex.Compile('^a{0,1}$');
  Check(R.IsMatch(''), '{0,1} empty');
  Check(R.IsMatch('a'), '{0,1} one');
  Check(not R.IsMatch('aa'), '{0,1} two');

  // a{1,} — same as a+
  R := TRegex.Compile('^a{1,}$');
  Check(not R.IsMatch(''), '{1,} empty');
  Check(R.IsMatch('a'), '{1,} one');
  Check(R.IsMatch('aaaa'), '{1,} many');

  // a{0,} — same as a*
  R := TRegex.Compile('^a{0,}$');
  Check(R.IsMatch(''), '{0,} empty');
  Check(R.IsMatch('a'), '{0,} one');
  Check(R.IsMatch('aaaa'), '{0,} many');
end;

{ --- 5. TestComplexPatterns --- }
procedure TestComplexPatterns;
var R: TRegex; M: TMatch;
begin
  // Email-like
  R := TRegex.Compile('[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-z]{2,4}');
  Check(R.IsMatch('user@example.com'), 'email match');
  Check(R.IsMatch('a.b@host.org'), 'email dot');
  Check(not R.IsMatch('noatsign'), 'email miss');

  // IP address
  R := TRegex.Compile('\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}');
  Check(R.IsMatch('192.168.1.1'), 'ip match');
  Check(R.IsMatch('10.0.0.255'), 'ip match2');
  Check(not R.IsMatch('192.168.1'), 'ip incomplete');

  // Date: YYYY-MM-DD
  R := TRegex.Compile('\d{4}-\d{2}-\d{2}');
  M := R.Find('today is 2026-05-31 ok');
  Check(M.Found, 'date found');
  CheckEqual('2026-05-31', M.Value('today is 2026-05-31 ok'), 'date value');

  // URL path
  R := TRegex.Compile('/[a-z]+(/[a-z]+)*');
  Check(R.IsMatch('/api/users/list'), 'url path');
  Check(R.IsMatch('/root'), 'url path single');

  // Hex color
  R := TRegex.Compile('#[0-9a-fA-F]{6}');
  Check(R.IsMatch('#FF00AA'), 'hex color upper');
  Check(R.IsMatch('#ff00aa'), 'hex color lower');
  Check(not R.IsMatch('#GG0000'), 'hex color invalid');

  // Quoted string
  R := TRegex.Compile('"[^"]*"');
  M := R.Find('say "hello world" now');
  Check(M.Found, 'quoted found');
  CheckEqual('"hello world"', M.Value('say "hello world" now'), 'quoted value');

  // C identifier
  R := TRegex.Compile('[a-zA-Z_][a-zA-Z0-9_]*');
  M := R.Find('  _myVar123  ');
  Check(M.Found, 'ident found');
  CheckEqual('_myVar123', M.Value('  _myVar123  '), 'ident value');
end;

{ --- 6. TestFindAllProgress --- }
procedure TestFindAllProgress;
var R: TRegex; MA: TMatchArray;
begin
  // Pattern that matches empty at every position: a* on 'bbb'
  R := TRegex.Compile('a*');
  MA := R.FindAll('bbb');
  // Matches empty at pos 0, 1, 2, 3 (after last char)
  CheckEqual(Int64(4), Int64(Length(MA)), 'a* on bbb count');
  CheckEqual(Int64(0), Int64(MA[0].Len), 'a* on bbb [0] len');
  CheckEqual(Int64(1), Int64(MA[1].Start), 'a* on bbb [1] start');

  // FindAll with pattern that matches at position 0 with len=0
  R := TRegex.Compile('');
  MA := R.FindAll('abc');
  // Empty pattern matches at every position: 0, 1, 2, 3
  CheckEqual(Int64(4), Int64(Length(MA)), 'empty on abc count');
  CheckEqual(Int64(0), Int64(MA[0].Start), 'empty [0] start');
  CheckEqual(Int64(3), Int64(MA[3].Start), 'empty [3] start');

  // FindAll on empty input with non-empty pattern
  R := TRegex.Compile('a');
  MA := R.FindAll('');
  CheckEqual(Int64(0), Int64(Length(MA)), 'a on empty count');

  // FindAll on empty input with empty-matching pattern
  R := TRegex.Compile('a*');
  MA := R.FindAll('');
  CheckEqual(Int64(1), Int64(Length(MA)), 'a* on empty count');
  CheckEqual(Int64(0), Int64(MA[0].Start), 'a* on empty start');
  CheckEqual(Int64(0), Int64(MA[0].Len), 'a* on empty len');

  // FindAll with no matches returns empty array
  R := TRegex.Compile('xyz');
  MA := R.FindAll('abc def ghi');
  CheckEqual(Int64(0), Int64(Length(MA)), 'no matches empty');

  // .* on 'hello' — matches 'hello' then empty at end
  R := TRegex.Compile('.*');
  MA := R.FindAll('hello');
  CheckEqual(Int64(2), Int64(Length(MA)), '.* on hello count');
  CheckEqual('hello', MA[0].Value('hello'), '.* on hello [0]');
  CheckEqual(Int64(0), Int64(MA[1].Len), '.* on hello [1] empty');
end;

{ --- 7. TestReplaceAllExpandAdvanced --- }
procedure TestReplaceAllExpandAdvanced;
var R: TRegex; s: string;
begin
  // Multiple $0 in template: '$0-$0' duplicates match
  R := TRegex.Compile('\d+');
  s := R.ReplaceAllExpand('42', '$0-$0');
  CheckEqual('42-42', s, 'double $0');

  // $1 when group didn not participate (optional group)
  R := TRegex.Compile('(a)?(b)');
  s := R.ReplaceAllExpand('b', '[$1][$2]');
  // group 1 not found -> empty, group 2 = 'b'
  CheckEqual('[][b]', s, 'optional group expand');

  // Template with no $ signs (literal replacement)
  R := TRegex.Compile('\d+');
  s := R.ReplaceAllExpand('a1b2', 'X');
  CheckEqual('aXbX', s, 'literal template');

  // Template that is empty string
  R := TRegex.Compile('\d+');
  s := R.ReplaceAllExpand('a1b2', '');
  CheckEqual('ab', s, 'empty template');

  // $10 — should be $1 followed by literal '0' (single digit parsing)
  R := TRegex.Compile('(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)');
  s := R.ReplaceAllExpand('abcdefghij', '$1');
  CheckEqual('a', s, '$1 of 10 groups');
  s := R.ReplaceAllExpand('abcdefghij', '$10');
  // Engine parses $1 then literal '0'
  CheckEqual('a0', s, '$10 is $1 + literal 0');

  // $$ produces literal $
  R := TRegex.Compile('x');
  s := R.ReplaceAllExpand('x', '$$');
  CheckEqual('$', s, '$$ literal dollar');

  // ${name} with valid name
  R := TRegex.Compile('(?P<num>\d+)');
  s := R.ReplaceAllExpand('val=42', '${num}!');
  CheckEqual('val=42!', s, 'named expand');
end;

{ --- 8. TestSplitAdvanced --- }
procedure TestSplitAdvanced;
var R: TRegex; parts: TStringArray;
begin
  // Split with regex that matches empty: split 'abc' on ''
  R := TRegex.Compile('');
  parts := R.Split('abc');
  // Empty pattern matches at every position (0,1,2,3) -> splits into chars + edges
  CheckEqual(Int64(5), Int64(Length(parts)), 'empty split count');
  CheckEqual('', parts[0], 'empty split [0]');
  CheckEqual('a', parts[1], 'empty split [1]');
  CheckEqual('b', parts[2], 'empty split [2]');
  CheckEqual('c', parts[3], 'empty split [3]');
  CheckEqual('', parts[4], 'empty split [4]');

  // Split where every char is a delimiter
  R := TRegex.Compile('.');
  parts := R.Split('abc');
  // 3 matches -> 4 parts: '', '', '', ''
  CheckEqual(Int64(4), Int64(Length(parts)), 'all delim count');
  CheckEqual('', parts[0], 'all delim [0]');
  CheckEqual('', parts[1], 'all delim [1]');
  CheckEqual('', parts[2], 'all delim [2]');
  CheckEqual('', parts[3], 'all delim [3]');

  // Split on pattern that does not exist in input
  R := TRegex.Compile('xyz');
  parts := R.Split('hello world');
  CheckEqual(Int64(1), Int64(Length(parts)), 'no match split count');
  CheckEqual('hello world', parts[0], 'no match split value');

  // Split with multi-char regex delimiter
  R := TRegex.Compile('\s+');
  parts := R.Split('a  b   c');
  CheckEqual(Int64(3), Int64(Length(parts)), 'multi space count');
  CheckEqual('a', parts[0], 'multi space [0]');
  CheckEqual('b', parts[1], 'multi space [1]');
  CheckEqual('c', parts[2], 'multi space [2]');

  // Split with limit = 0 (no split)
  R := TRegex.Compile(',');
  parts := R.Split('a,b,c', 0);
  CheckEqual(Int64(1), Int64(Length(parts)), 'limit 0 count');
  CheckEqual('a,b,c', parts[0], 'limit 0 value');
end;

{ --- 9. TestCaseInsensitiveAdvanced --- }
procedure TestCaseInsensitiveAdvanced;
var R: TRegex; M: TMatch; MA: TMatchArray; s: string;
begin
  // (?i) with word boundary
  R := TRegex.Compile('(?i)\bHello\b');
  Check(R.IsMatch('HELLO world'), 'ci wb upper');
  Check(R.IsMatch('say hello!'), 'ci wb lower');
  Check(not R.IsMatch('HELLOWORLD'), 'ci wb no boundary');

  // (?i) with repetition: (?i)(abc){2} matches 'ABCabc'
  R := TRegex.Compile('(?i)(abc){2}');
  Check(R.IsMatch('ABCabc'), 'ci rep mixed');
  Check(R.IsMatch('abcABC'), 'ci rep mixed2');
  Check(R.IsMatch('ABCABC'), 'ci rep upper');
  Check(not R.IsMatch('abc'), 'ci rep too few');

  // (?i) with alternation
  R := TRegex.Compile('(?i)yes|no');
  Check(R.IsMatch('YES'), 'ci alt YES');
  Check(R.IsMatch('No'), 'ci alt No');
  Check(R.IsMatch('yes'), 'ci alt yes');
  Check(R.IsMatch('NO'), 'ci alt NO');

  // (?i) with FindAll
  R := TRegex.Compile('(?i)cat');
  MA := R.FindAll('Cat CAT cat cAt CaT');
  CheckEqual(Int64(5), Int64(Length(MA)), 'ci findall count');

  // (?i) with ReplaceAll
  R := TRegex.Compile('(?i)hello');
  s := R.ReplaceAll('Hello HELLO hello', 'X');
  CheckEqual('X X X', s, 'ci replace all');

  // (?i) with char class that already has both cases: (?i)[a-zA-Z]
  R := TRegex.Compile('(?i)[a-zA-Z]+');
  Check(R.IsFullMatch('Hello'), 'ci both cases');
  Check(R.IsFullMatch('WORLD'), 'ci both cases upper');

  // Compile flag vs inline: both should work identically
  R := TRegex.Compile('hello', [rfCaseInsensitive]);
  Check(R.IsMatch('HELLO'), 'flag ci');
  R := TRegex.Compile('(?i)hello');
  Check(R.IsMatch('HELLO'), 'inline ci');
end;

{ --- 10. TestBacktrackingImmunity --- }
procedure TestBacktrackingImmunity;
var R: TRegex; input: string; i: Integer;
begin
  // (a|a)*b on 'aaa...ab' (many a's) — must be O(n)
  SetLength(input, 26);
  for i := 1 to 25 do input[i] := 'a';
  input[26] := 'b';
  R := TRegex.Compile('(a|a)*b');
  Check(R.IsMatch(input), '(a|a)*b match');

  // (a?){n}a{n} for n=15 — classic exponential blowup test
  R := TRegex.Compile('a?a?a?a?a?a?a?a?a?a?a?a?a?a?a?aaaaaaaaaaaaaaa');
  SetLength(input, 15);
  for i := 1 to 15 do input[i] := 'a';
  Check(R.IsMatch(input), '(a?){15}a{15} match');

  // .*.*.*.*x on long input without x — must complete fast
  SetLength(input, 200);
  for i := 1 to 200 do input[i] := 'a';
  R := TRegex.Compile('.*.*.*.*x');
  Check(not R.IsMatch(input), '.*.*.*.*x no match');

  // (a+)+b on 'aaa...a' (no b) — must not hang
  SetLength(input, 30);
  for i := 1 to 30 do input[i] := 'a';
  R := TRegex.Compile('(a+)+b');
  Check(not R.IsMatch(input), '(a+)+b no match');

  // Alternation with many branches
  R := TRegex.Compile('a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z');
  SetLength(input, 500);
  for i := 1 to 500 do input[i] := '0';
  input[500] := 'z';
  Check(R.IsMatch(input), 'many alts match');

  // Nested quantifiers: ((a*)*) on long input
  SetLength(input, 100);
  for i := 1 to 100 do input[i] := 'a';
  R := TRegex.Compile('((a*)*)');
  Check(R.IsMatch(input), 'nested quant match');
end;

{ --- 11. TestGroupByNameAdvanced --- }
procedure TestGroupByNameAdvanced;
var R: TRegex; M: TMatch; G: TGroup;
begin
  // Multiple named groups with same pattern structure
  R := TRegex.Compile('(?P<first>\w+)\s+(?P<second>\w+)\s+(?P<third>\w+)');
  M := R.Find('hello world foo');
  Check(M.Found, 'multi named found');
  G := R.GroupByName(M, 'first');
  Check(G.Found, 'first found');
  CheckEqual('hello', G.Value('hello world foo'), 'first value');
  G := R.GroupByName(M, 'second');
  CheckEqual('world', G.Value('hello world foo'), 'second value');
  G := R.GroupByName(M, 'third');
  CheckEqual('foo', G.Value('hello world foo'), 'third value');

  // GroupByName on a match that has no groups
  R := TRegex.Compile('hello');
  M := R.Find('hello');
  Check(M.Found, 'no groups found');
  G := R.GroupByName(M, 'anything');
  Check(not G.Found, 'no groups name miss');

  // GroupByName with empty string name
  R := TRegex.Compile('(?P<x>a)');
  M := R.Find('a');
  G := R.GroupByName(M, '');
  Check(not G.Found, 'empty name not found');

  // GroupIndexByName returns correct indices for multiple names
  R := TRegex.Compile('(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})');
  CheckEqual(Int64(0), Int64(R.GroupIndexByName('year')), 'year index');
  CheckEqual(Int64(1), Int64(R.GroupIndexByName('month')), 'month index');
  CheckEqual(Int64(2), Int64(R.GroupIndexByName('day')), 'day index');
  CheckEqual(Int64(-1), Int64(R.GroupIndexByName('hour')), 'hour index -1');

  // NumCaptures with mixed named and unnamed groups
  R := TRegex.Compile('(a)(?P<mid>b)(c)');
  CheckEqual(Int64(3), Int64(R.NumCaptures), 'mixed num captures');
  CheckEqual(Int64(1), Int64(R.GroupIndexByName('mid')), 'mixed mid index');
  CheckEqual(Int64(-1), Int64(R.GroupIndexByName('a')), 'unnamed not named');
end;

{ --- 12. TestIsMatchVsFind --- }
procedure TestIsMatchVsFind;
var R: TRegex; M: TMatch;
begin
  // IsMatch returns true iff Find returns Found=true
  R := TRegex.Compile('\d+');
  Check(R.IsMatch('abc123') = R.Find('abc123').Found, 'consistency match');
  Check(R.IsMatch('abc') = R.Find('abc').Found, 'consistency miss');

  // IsMatch on patterns with captures (should still work)
  R := TRegex.Compile('(\d+)-(\d+)');
  Check(R.IsMatch('12-34'), 'ismatch with captures');
  Check(not R.IsMatch('abcd'), 'ismatch with captures miss');

  // IsMatch with (?i)
  R := TRegex.Compile('(?i)hello');
  Check(R.IsMatch('HELLO'), 'ismatch ci');
  Check(not R.IsMatch('world'), 'ismatch ci miss');

  // IsMatch on empty pattern
  R := TRegex.Compile('');
  Check(R.IsMatch('anything'), 'ismatch empty pattern');
  Check(R.IsMatch(''), 'ismatch empty both');

  // IsMatch on anchored pattern
  R := TRegex.Compile('^abc$');
  Check(R.IsMatch('abc'), 'ismatch anchored match');
  Check(not R.IsMatch('abcd'), 'ismatch anchored miss');
  M := R.Find('abc');
  Check(M.Found, 'find anchored match');
  M := R.Find('abcd');
  Check(not M.Found, 'find anchored miss');

  // IsMatch with word boundary
  R := TRegex.Compile('\bfoo\b');
  Check(R.IsMatch('foo bar'), 'ismatch wb');
  Check(not R.IsMatch('foobar'), 'ismatch wb miss');
  Check(R.IsMatch('foo bar') = R.Find('foo bar').Found, 'consistency wb');
end;

{ --- 13. TestCompileReuse --- }
procedure TestCompileReuse;
var R: TRegex; M: TMatch; MA: TMatchArray; s: string; i: Integer;
begin
  // Same TRegex used for multiple different inputs
  R := TRegex.Compile('\d+');
  Check(R.IsMatch('abc123'), 'reuse input 1');
  Check(R.IsMatch('456def'), 'reuse input 2');
  Check(not R.IsMatch('nodigits'), 'reuse input 3');
  Check(R.IsMatch('x7y'), 'reuse input 4');

  // Same TRegex used for IsMatch, Find, FindAll, Replace in sequence
  R := TRegex.Compile('\w+');
  Check(R.IsMatch('hello world'), 'reuse op ismatch');
  M := R.Find('hello world');
  Check(M.Found, 'reuse op find');
  CheckEqual('hello', M.Value('hello world'), 'reuse op find val');
  MA := R.FindAll('hello world');
  CheckEqual(Int64(2), Int64(Length(MA)), 'reuse op findall');
  s := R.ReplaceAll('hello world', 'X');
  CheckEqual('X X', s, 'reuse op replace');

  // Compile once, match 100 times
  R := TRegex.Compile('test\d+');
  for i := 1 to 100 do
  begin
    s := 'prefix_test' + IntToStr(i) + '_suffix';
    Check(R.IsMatch(s), 'reuse 100 iter ' + IntToStr(i));
  end;

  // Reuse with captures
  R := TRegex.Compile('(\w+)=(\d+)');
  M := R.Find('x=1');
  Check(M.Found, 'reuse cap 1');
  CheckEqual('x', M.Groups[0].Value('x=1'), 'reuse cap 1 g0');
  CheckEqual('1', M.Groups[1].Value('x=1'), 'reuse cap 1 g1');
  M := R.Find('key=999');
  Check(M.Found, 'reuse cap 2');
  CheckEqual('key', M.Groups[0].Value('key=999'), 'reuse cap 2 g0');
  CheckEqual('999', M.Groups[1].Value('key=999'), 'reuse cap 2 g1');

  // Reuse with split
  R := TRegex.Compile(',');
  MA := R.FindAll('a,b,c');
  CheckEqual(Int64(2), Int64(Length(MA)), 'reuse findall comma');
  s := R.ReplaceAll('a,b,c', ';');
  CheckEqual('a;b;c', s, 'reuse replace comma');
end;

{ === SEMANTIC CONFORMANCE TESTS === }

{ --- 1. TestFindPositions --- }
procedure TestFindPositions;
var R: TRegex; M: TMatch;
begin
  // 'abc' in 'xxxabcyyy' -> Start=3, Len=3
  R := TRegex.Compile('abc');
  M := R.Find('xxxabcyyy');
  Check(M.Found, 'abc found');
  CheckEqual(Int64(3), Int64(M.Start), 'abc start');
  CheckEqual(Int64(3), Int64(M.Len), 'abc len');

  // '\d+' in 'abc123def' -> Start=3, Len=3
  R := TRegex.Compile('\d+');
  M := R.Find('abc123def');
  Check(M.Found, '\d+ found');
  CheckEqual(Int64(3), Int64(M.Start), '\d+ start');
  CheckEqual(Int64(3), Int64(M.Len), '\d+ len');

  // '.*' in 'hello' -> Start=0, Len=5
  R := TRegex.Compile('.*');
  M := R.Find('hello');
  Check(M.Found, '.* found');
  CheckEqual(Int64(0), Int64(M.Start), '.* start');
  CheckEqual(Int64(5), Int64(M.Len), '.* len');

  // 'x' in 'x' -> Start=0, Len=1
  R := TRegex.Compile('x');
  M := R.Find('x');
  Check(M.Found, 'x found');
  CheckEqual(Int64(0), Int64(M.Start), 'x start');
  CheckEqual(Int64(1), Int64(M.Len), 'x len');

  // 'x' in 'yx' -> Start=1, Len=1
  M := R.Find('yx');
  Check(M.Found, 'x in yx found');
  CheckEqual(Int64(1), Int64(M.Start), 'x in yx start');
  CheckEqual(Int64(1), Int64(M.Len), 'x in yx len');

  // '^' in 'abc' -> Start=0, Len=0
  R := TRegex.Compile('^');
  M := R.Find('abc');
  Check(M.Found, '^ found');
  CheckEqual(Int64(0), Int64(M.Start), '^ start');
  CheckEqual(Int64(0), Int64(M.Len), '^ len');

  // '$' in 'abc' -> Start=3, Len=0
  R := TRegex.Compile('$');
  M := R.Find('abc');
  Check(M.Found, '$ found');
  CheckEqual(Int64(3), Int64(M.Start), '$ start');
  CheckEqual(Int64(0), Int64(M.Len), '$ len');

  // '\b' in 'abc' -> Start=0, Len=0
  R := TRegex.Compile('\b');
  M := R.Find('abc');
  Check(M.Found, '\b found');
  CheckEqual(Int64(0), Int64(M.Start), '\b start');
  CheckEqual(Int64(0), Int64(M.Len), '\b len');

  // 'a?' in 'b' -> Start=0, Len=0 (matches empty at start)
  R := TRegex.Compile('a?');
  M := R.Find('b');
  Check(M.Found, 'a? found');
  CheckEqual(Int64(0), Int64(M.Start), 'a? start');
  CheckEqual(Int64(0), Int64(M.Len), 'a? len');
end;

{ --- 2. TestFindAllPositions --- }
procedure TestFindAllPositions;
var R: TRegex; MA: TMatchArray;
begin
  // 'a' in 'abab' -> [{0,1},{2,1}]
  R := TRegex.Compile('a');
  MA := R.FindAll('abab');
  CheckEqual(Int64(2), Int64(Length(MA)), 'a in abab count');
  CheckEqual(Int64(0), Int64(MA[0].Start), 'a[0] start');
  CheckEqual(Int64(1), Int64(MA[0].Len), 'a[0] len');
  CheckEqual(Int64(2), Int64(MA[1].Start), 'a[1] start');
  CheckEqual(Int64(1), Int64(MA[1].Len), 'a[1] len');

  // '\d' in 'a1b2c3' -> [{1,1},{3,1},{5,1}]
  R := TRegex.Compile('\d');
  MA := R.FindAll('a1b2c3');
  CheckEqual(Int64(3), Int64(Length(MA)), '\d count');
  CheckEqual(Int64(1), Int64(MA[0].Start), '\d[0] start');
  CheckEqual(Int64(3), Int64(MA[1].Start), '\d[1] start');
  CheckEqual(Int64(5), Int64(MA[2].Start), '\d[2] start');

  // 'aa' in 'aaaa' -> [{0,2},{2,2}] (non-overlapping)
  R := TRegex.Compile('aa');
  MA := R.FindAll('aaaa');
  CheckEqual(Int64(2), Int64(Length(MA)), 'aa count');
  CheckEqual(Int64(0), Int64(MA[0].Start), 'aa[0] start');
  CheckEqual(Int64(2), Int64(MA[0].Len), 'aa[0] len');
  CheckEqual(Int64(2), Int64(MA[1].Start), 'aa[1] start');
  CheckEqual(Int64(2), Int64(MA[1].Len), 'aa[1] len');

  // '..' in 'abcde' -> [{0,2},{2,2}] (5 chars = 2 matches + 1 leftover)
  R := TRegex.Compile('..');
  MA := R.FindAll('abcde');
  CheckEqual(Int64(2), Int64(Length(MA)), '.. count');
  CheckEqual(Int64(0), Int64(MA[0].Start), '..[0] start');
  CheckEqual(Int64(2), Int64(MA[0].Len), '..[0] len');
  CheckEqual(Int64(2), Int64(MA[1].Start), '..[1] start');
  CheckEqual(Int64(2), Int64(MA[1].Len), '..[1] len');

  // '' in 'ab' -> [{0,0},{1,0},{2,0}] (empty matches at each position)
  R := TRegex.Compile('');
  MA := R.FindAll('ab');
  CheckEqual(Int64(3), Int64(Length(MA)), 'empty count');
  CheckEqual(Int64(0), Int64(MA[0].Start), 'empty[0] start');
  CheckEqual(Int64(0), Int64(MA[0].Len), 'empty[0] len');
  CheckEqual(Int64(1), Int64(MA[1].Start), 'empty[1] start');
  CheckEqual(Int64(2), Int64(MA[2].Start), 'empty[2] start');
end;

{ --- 3. TestCapturePositions --- }
procedure TestCapturePositions;
var R: TRegex; M: TMatch;
begin
  // '(a)(b)(c)' in 'abc' -> Groups[0]={0,1}, Groups[1]={1,1}, Groups[2]={2,1}
  R := TRegex.Compile('(a)(b)(c)');
  M := R.Find('abc');
  Check(M.Found, '(a)(b)(c) found');
  CheckEqual(Int64(3), Int64(Length(M.Groups)), '(a)(b)(c) group count');
  CheckEqual(Int64(0), Int64(M.Groups[0].Start), 'g0 start');
  CheckEqual(Int64(1), Int64(M.Groups[0].Len), 'g0 len');
  CheckEqual(Int64(1), Int64(M.Groups[1].Start), 'g1 start');
  CheckEqual(Int64(1), Int64(M.Groups[1].Len), 'g1 len');
  CheckEqual(Int64(2), Int64(M.Groups[2].Start), 'g2 start');
  CheckEqual(Int64(1), Int64(M.Groups[2].Len), 'g2 len');

  // '(a+)' in 'xaaay' -> Match={1,3}, Groups[0]={1,3}
  R := TRegex.Compile('(a+)');
  M := R.Find('xaaay');
  Check(M.Found, '(a+) found');
  CheckEqual(Int64(1), Int64(M.Start), '(a+) match start');
  CheckEqual(Int64(3), Int64(M.Len), '(a+) match len');
  CheckEqual(Int64(1), Int64(M.Groups[0].Start), '(a+) g0 start');
  CheckEqual(Int64(3), Int64(M.Groups[0].Len), '(a+) g0 len');

  // '(a)?(b)' in 'b' -> Match={0,1}, Groups[0]={-1,0}, Groups[1]={0,1}
  R := TRegex.Compile('(a)?(b)');
  M := R.Find('b');
  Check(M.Found, '(a)?(b) found');
  CheckEqual(Int64(0), Int64(M.Start), '(a)?(b) match start');
  CheckEqual(Int64(1), Int64(M.Len), '(a)?(b) match len');
  Check(not M.Groups[0].Found, '(a)?(b) g0 not found');
  Check(M.Groups[1].Found, '(a)?(b) g1 found');
  CheckEqual(Int64(0), Int64(M.Groups[1].Start), '(a)?(b) g1 start');
  CheckEqual(Int64(1), Int64(M.Groups[1].Len), '(a)?(b) g1 len');

  // '(?:a)(b)' in 'ab' -> only 1 group (non-capturing doesn't count)
  R := TRegex.Compile('(?:a)(b)');
  M := R.Find('ab');
  Check(M.Found, '(?:a)(b) found');
  CheckEqual(Int64(1), Int64(Length(M.Groups)), '(?:a)(b) group count');
  CheckEqual(Int64(1), Int64(M.Groups[0].Start), '(?:a)(b) g0 start');
  CheckEqual(Int64(1), Int64(M.Groups[0].Len), '(?:a)(b) g0 len');

  // '((a+)(b+))' in 'aaabb' -> Groups[0]={0,5}, Groups[1]={0,3}, Groups[2]={3,2}
  R := TRegex.Compile('((a+)(b+))');
  M := R.Find('aaabb');
  Check(M.Found, '((a+)(b+)) found');
  CheckEqual(Int64(3), Int64(Length(M.Groups)), '((a+)(b+)) group count');
  CheckEqual(Int64(0), Int64(M.Groups[0].Start), '((a+)(b+)) g0 start');
  CheckEqual(Int64(5), Int64(M.Groups[0].Len), '((a+)(b+)) g0 len');
  CheckEqual(Int64(0), Int64(M.Groups[1].Start), '((a+)(b+)) g1 start');
  CheckEqual(Int64(3), Int64(M.Groups[1].Len), '((a+)(b+)) g1 len');
  CheckEqual(Int64(3), Int64(M.Groups[2].Start), '((a+)(b+)) g2 start');
  CheckEqual(Int64(2), Int64(M.Groups[2].Len), '((a+)(b+)) g2 len');
end;

{ --- 4. TestReplacePositional --- }
procedure TestReplacePositional;
var R: TRegex;
begin
  // Replace at start: 'abc' -> 'X' in 'abcdef' = 'Xdef'
  R := TRegex.Compile('abc');
  CheckEqual('Xdef', R.ReplaceAll('abcdef', 'X'), 'replace at start');

  // Replace at end: 'def' -> 'X' in 'abcdef' = 'abcX'
  R := TRegex.Compile('def');
  CheckEqual('abcX', R.ReplaceAll('abcdef', 'X'), 'replace at end');

  // Replace in middle: 'cd' -> 'X' in 'abcdef' = 'abXef'
  R := TRegex.Compile('cd');
  CheckEqual('abXef', R.ReplaceAll('abcdef', 'X'), 'replace in middle');

  // Multiple replaces: 'a' -> 'X' in 'ababa' = 'XbXbX'
  R := TRegex.Compile('a');
  CheckEqual('XbXbX', R.ReplaceAll('ababa', 'X'), 'multiple replaces');

  // Replace with longer: 'a' -> 'XYZ' in 'aba' = 'XYZbXYZ'
  CheckEqual('XYZbXYZ', R.ReplaceAll('aba', 'XYZ'), 'replace with longer');

  // Replace with shorter: 'abc' -> 'X' in 'abcabc' = 'XX'
  R := TRegex.Compile('abc');
  CheckEqual('XX', R.ReplaceAll('abcabc', 'X'), 'replace with shorter');

  // ReplaceFirst only first: 'a' -> 'X' in 'aaa' = 'Xaa'
  R := TRegex.Compile('a');
  CheckEqual('Xaa', R.ReplaceFirst('aaa', 'X'), 'replace first only');
end;

{ --- 5. TestSplitPositional --- }
procedure TestSplitPositional;
var R: TRegex; parts: TStringArray;
begin
  // ',' in 'a,b,c' -> ['a','b','c']
  R := TRegex.Compile(',');
  parts := R.Split('a,b,c');
  CheckEqual(Int64(3), Int64(Length(parts)), 'comma split count');
  CheckEqual('a', parts[0], 'comma[0]');
  CheckEqual('b', parts[1], 'comma[1]');
  CheckEqual('c', parts[2], 'comma[2]');

  // ',' in ',a,b,' -> ['','a','b','']
  parts := R.Split(',a,b,');
  CheckEqual(Int64(4), Int64(Length(parts)), 'edge comma count');
  CheckEqual('', parts[0], 'edge[0]');
  CheckEqual('a', parts[1], 'edge[1]');
  CheckEqual('b', parts[2], 'edge[2]');
  CheckEqual('', parts[3], 'edge[3]');

  // '\s+' in '  a  b  ' -> ['','a','b','']
  R := TRegex.Compile('\s+');
  parts := R.Split('  a  b  ');
  CheckEqual(Int64(4), Int64(Length(parts)), 'space split count');
  CheckEqual('', parts[0], 'space[0]');
  CheckEqual('a', parts[1], 'space[1]');
  CheckEqual('b', parts[2], 'space[2]');
  CheckEqual('', parts[3], 'space[3]');

  // ':' in 'no-colon' -> ['no-colon']
  R := TRegex.Compile(':');
  parts := R.Split('no-colon');
  CheckEqual(Int64(1), Int64(Length(parts)), 'no match split count');
  CheckEqual('no-colon', parts[0], 'no match split value');

  // Limit=2: ',' in 'a,b,c,d' -> ['a','b','c,d']
  R := TRegex.Compile(',');
  parts := R.Split('a,b,c,d', 2);
  CheckEqual(Int64(3), Int64(Length(parts)), 'limit 2 count');
  CheckEqual('a', parts[0], 'limit[0]');
  CheckEqual('b', parts[1], 'limit[1]');
  CheckEqual('c,d', parts[2], 'limit[2]');
end;

{ --- 6. TestLongPatterns --- }
procedure TestLongPatterns;
var R: TRegex; M: TMatch; pat, input: string; i: Integer;
begin
  // 50-char literal: must compile and match
  pat := '';
  for i := 1 to 10 do pat := pat + 'abcde';
  input := 'xxx' + pat + 'yyy';
  R := TRegex.Compile(pat);
  M := R.Find(input);
  Check(M.Found, '50-char literal found');
  CheckEqual(Int64(3), Int64(M.Start), '50-char literal start');
  CheckEqual(Int64(50), Int64(M.Len), '50-char literal len');

  // Pattern with 20 alternations: 'a|b|c|...|t'
  pat := 'a';
  for i := Ord('b') to Ord('t') do
    pat := pat + '|' + Chr(i);
  R := TRegex.Compile(pat);
  Check(R.IsMatch('t'), '20 alts match t');
  Check(R.IsMatch('a'), '20 alts match a');
  Check(not R.IsMatch('u'), '20 alts miss u');

  // Pattern with 10 capture groups
  R := TRegex.Compile('(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)');
  M := R.Find('abcdefghij');
  Check(M.Found, '10 groups found');
  CheckEqual(Int64(10), Int64(Length(M.Groups)), '10 groups count');
  CheckEqual('a', M.Groups[0].Value('abcdefghij'), '10g[0]');
  CheckEqual('j', M.Groups[9].Value('abcdefghij'), '10g[9]');

  // Pattern with nested groups 5 deep: (((((a)))))
  R := TRegex.Compile('(((((a)))))');
  M := R.Find('a');
  Check(M.Found, '5 deep found');
  CheckEqual(Int64(5), Int64(Length(M.Groups)), '5 deep count');
  CheckEqual('a', M.Groups[0].Value('a'), '5 deep outer');
  CheckEqual('a', M.Groups[4].Value('a'), '5 deep inner');

  // Pattern with mixed quantifiers: a+b*c?d{2,3}e
  R := TRegex.Compile('a+b*c?d{2,3}e');
  Check(R.IsMatch('aadde'), 'mixed quant 1');
  Check(R.IsMatch('aaabbcddde'), 'mixed quant 2');
  Check(not R.IsMatch('ade'), 'mixed quant miss');
end;

{ --- 7. TestEmptyMatchBehavior --- }
procedure TestEmptyMatchBehavior;
var R: TRegex; M: TMatch; MA: TMatchArray; s: string;
begin
  // Find('') on 'abc' -> Found=true, Start=0, Len=0
  R := TRegex.Compile('');
  M := R.Find('abc');
  Check(M.Found, 'empty find found');
  CheckEqual(Int64(0), Int64(M.Start), 'empty find start');
  CheckEqual(Int64(0), Int64(M.Len), 'empty find len');

  // IsMatch('') on 'abc' -> true
  Check(R.IsMatch('abc'), 'empty ismatch');

  // IsFullMatch('') on '' -> true
  Check(R.IsFullMatch(''), 'empty fullmatch empty');

  // IsFullMatch('') on 'a' -> false
  Check(not R.IsFullMatch('a'), 'empty fullmatch non-empty');

  // FindAll('a*') on 'bbb' -> empty matches between chars
  R := TRegex.Compile('a*');
  MA := R.FindAll('bbb');
  // Matches empty at pos 0, 1, 2, 3
  CheckEqual(Int64(4), Int64(Length(MA)), 'a* on bbb count');
  CheckEqual(Int64(0), Int64(MA[0].Len), 'a* on bbb[0] len');
  CheckEqual(Int64(0), Int64(MA[1].Len), 'a* on bbb[1] len');
  CheckEqual(Int64(0), Int64(MA[2].Len), 'a* on bbb[2] len');
  CheckEqual(Int64(0), Int64(MA[3].Len), 'a* on bbb[3] len');

  // ReplaceAll('a*', 'X') on 'bbb' -> 'XbXbXbX' (insert X at each empty match)
  s := R.ReplaceAll('bbb', 'X');
  CheckEqual('XbXbXbX', s, 'a* replace bbb');

  // Split('') on 'abc' -> splits at each empty match position
  R := TRegex.Compile('');
  s := R.ReplaceAll('abc', '-');
  CheckEqual('-a-b-c-', s, 'empty replace abc');
end;

{ --- 8. TestWordBoundaryDetailed --- }
procedure TestWordBoundaryDetailed;
var R: TRegex; M: TMatch; MA: TMatchArray;
begin
  // \bcat\b in 'the cat sat' -> matches 'cat' at 4
  R := TRegex.Compile('\bcat\b');
  M := R.Find('the cat sat');
  Check(M.Found, '\bcat\b found');
  CheckEqual(Int64(4), Int64(M.Start), '\bcat\b start');
  CheckEqual(Int64(3), Int64(M.Len), '\bcat\b len');

  // \bcat\b in 'concatenate' -> no match
  Check(not R.IsMatch('concatenate'), '\bcat\b in concatenate');

  // \b in 'a' -> matches at 0 (start boundary)
  R := TRegex.Compile('\b');
  M := R.Find('a');
  Check(M.Found, '\b in a found');
  CheckEqual(Int64(0), Int64(M.Start), '\b in a start');
  CheckEqual(Int64(0), Int64(M.Len), '\b in a len');

  // \b FindAll in 'a' -> matches at 0 and 1 (both boundaries)
  MA := R.FindAll('a');
  CheckEqual(Int64(2), Int64(Length(MA)), '\b in a findall count');
  CheckEqual(Int64(0), Int64(MA[0].Start), '\b in a [0]');
  CheckEqual(Int64(1), Int64(MA[1].Start), '\b in a [1]');

  // \B in 'abc' -> matches between a-b and b-c (non-boundaries)
  R := TRegex.Compile('\B');
  MA := R.FindAll('abc');
  CheckEqual(Int64(2), Int64(Length(MA)), '\B in abc count');
  CheckEqual(Int64(1), Int64(MA[0].Start), '\B in abc [0]');
  CheckEqual(Int64(2), Int64(MA[1].Start), '\B in abc [1]');

  // \b\w+\b FindAll in 'hello world 123' -> ['hello','world','123']
  R := TRegex.Compile('\b\w+\b');
  MA := R.FindAll('hello world 123');
  CheckEqual(Int64(3), Int64(Length(MA)), '\b\w+\b count');
  CheckEqual('hello', MA[0].Value('hello world 123'), '\b\w+\b[0]');
  CheckEqual('world', MA[1].Value('hello world 123'), '\b\w+\b[1]');
  CheckEqual('123', MA[2].Value('hello world 123'), '\b\w+\b[2]');

  // \b at start of input with word char
  R := TRegex.Compile('\bfoo');
  Check(R.IsMatch('foo bar'), '\b at input start');

  // \b at end of input with word char
  R := TRegex.Compile('foo\b');
  Check(R.IsMatch('bar foo'), '\b at input end');

  // \B at start of input with non-word char
  R := TRegex.Compile('\B.');
  M := R.Find(' abc');
  Check(M.Found, '\B at non-word start');
  CheckEqual(Int64(0), Int64(M.Start), '\B at non-word start pos');
end;

{ --- 9. TestQuantifierInteraction --- }
procedure TestQuantifierInteraction;
var R: TRegex; M: TMatch;
begin
  // [abc]+ on 'abcdef' -> 'abc'
  R := TRegex.Compile('[abc]+');
  M := R.Find('abcdef');
  Check(M.Found, '[abc]+ found');
  CheckEqual('abc', M.Value('abcdef'), '[abc]+ value');

  // [abc]{2} on 'abcdef' -> 'ab'
  R := TRegex.Compile('[abc]{2}');
  M := R.Find('abcdef');
  Check(M.Found, '[abc]{2} found');
  CheckEqual('ab', M.Value('abcdef'), '[abc]{2} value');

  // (ab)+ on 'ababab' -> 'ababab', group='ab' (last iteration)
  R := TRegex.Compile('(ab)+');
  M := R.Find('ababab');
  Check(M.Found, '(ab)+ found');
  CheckEqual('ababab', M.Value('ababab'), '(ab)+ value');
  CheckEqual(Int64(1), Int64(Length(M.Groups)), '(ab)+ group count');
  CheckEqual('ab', M.Groups[0].Value('ababab'), '(ab)+ group last');

  // (ab){2} on 'ababab' -> 'abab', group='ab'
  R := TRegex.Compile('(ab){2}');
  M := R.Find('ababab');
  Check(M.Found, '(ab){2} found');
  CheckEqual('abab', M.Value('ababab'), '(ab){2} value');
  CheckEqual('ab', M.Groups[0].Value('ababab'), '(ab){2} group');

  // (?:ab)+ on 'ababab' -> 'ababab' (no capture)
  R := TRegex.Compile('(?:ab)+');
  M := R.Find('ababab');
  Check(M.Found, '(?:ab)+ found');
  CheckEqual('ababab', M.Value('ababab'), '(?:ab)+ value');
  CheckEqual(Int64(0), Int64(Length(M.Groups)), '(?:ab)+ no groups');

  // [a-z]+\d+ on 'abc123' -> 'abc123'
  R := TRegex.Compile('[a-z]+\d+');
  M := R.Find('abc123');
  Check(M.Found, '[a-z]+\d+ found');
  CheckEqual('abc123', M.Value('abc123'), '[a-z]+\d+ value');

  // \d+[a-z]+ on '123abc' -> '123abc'
  R := TRegex.Compile('\d+[a-z]+');
  M := R.Find('123abc');
  Check(M.Found, '\d+[a-z]+ found');
  CheckEqual('123abc', M.Value('123abc'), '\d+[a-z]+ value');

  // (a|b)+ on 'abba' -> 'abba', group='a' (last)
  R := TRegex.Compile('(a|b)+');
  M := R.Find('abba');
  Check(M.Found, '(a|b)+ found');
  CheckEqual('abba', M.Value('abba'), '(a|b)+ value');
  CheckEqual('a', M.Groups[0].Value('abba'), '(a|b)+ group last');
end;

{ --- 10. TestAnchoredSearch --- }
procedure TestAnchoredSearch;
var R: TRegex; M: TMatch;
begin
  // ^abc on 'abcdef' -> match at 0
  R := TRegex.Compile('^abc');
  M := R.Find('abcdef');
  Check(M.Found, '^abc found');
  CheckEqual(Int64(0), Int64(M.Start), '^abc start');

  // ^abc on 'xabcdef' -> no match
  Check(not R.IsMatch('xabcdef'), '^abc miss');

  // abc$ on 'xyzabc' -> match at 3
  R := TRegex.Compile('abc$');
  M := R.Find('xyzabc');
  Check(M.Found, 'abc$ found');
  CheckEqual(Int64(3), Int64(M.Start), 'abc$ start');

  // abc$ on 'abcxyz' -> no match
  Check(not R.IsMatch('abcxyz'), 'abc$ miss');

  // ^abc$ on 'abc' -> match
  R := TRegex.Compile('^abc$');
  Check(R.IsMatch('abc'), '^abc$ match');

  // ^abc$ on 'abcx' -> no match
  Check(not R.IsMatch('abcx'), '^abc$ miss');

  // ^$ on '' -> match
  R := TRegex.Compile('^$');
  Check(R.IsMatch(''), '^$ empty match');

  // ^$ on 'a' -> no match
  Check(not R.IsMatch('a'), '^$ non-empty miss');

  // ^.+$ on 'hello' -> match 'hello'
  R := TRegex.Compile('^.+$');
  M := R.Find('hello');
  Check(M.Found, '^.+$ found');
  CheckEqual('hello', M.Value('hello'), '^.+$ value');

  // ^.*$ on '' -> match ''
  R := TRegex.Compile('^.*$');
  M := R.Find('');
  Check(M.Found, '^.*$ empty found');
  CheckEqual(Int64(0), Int64(M.Len), '^.*$ empty len');
end;

{ --- 11. TestDotBehavior --- }
procedure TestDotBehavior;
var R: TRegex; M: TMatch;
begin
  // . matches any char except \n
  R := TRegex.Compile('.');
  Check(R.IsMatch('a'), '. matches a');
  Check(R.IsMatch('Z'), '. matches Z');
  Check(R.IsMatch('5'), '. matches 5');
  Check(R.IsMatch(' '), '. matches space');

  // . on '\n' -> no match
  Check(not R.IsMatch(#10), '. no newline');

  // .+ on 'abc\ndef' -> 'abc' (stops at newline)
  R := TRegex.Compile('.+');
  M := R.Find('abc'#10'def');
  Check(M.Found, '.+ found');
  CheckEqual('abc', M.Value('abc'#10'def'), '.+ stops at newline');

  // .* on '' -> match (empty)
  R := TRegex.Compile('.*');
  M := R.Find('');
  Check(M.Found, '.* empty match');
  CheckEqual(Int64(0), Int64(M.Len), '.* empty len');

  // .. on 'a' -> no match (need 2 chars)
  R := TRegex.Compile('..');
  Check(not R.IsFullMatch('a'), '.. need 2 chars');
  Check(R.IsFullMatch('ab'), '.. two chars ok');

  // .\n. on 'a\nb' -> match
  R := TRegex.Compile('.\n.');
  Check(R.IsMatch('a'#10'b'), '.\n. match');
  Check(not R.IsMatch('a'#10#10), '.\n. second must not be newline');
end;

{ --- 12. TestCharClassRanges --- }
procedure TestCharClassRanges;
var R: TRegex; i: Integer;
begin
  // [0-9] matches all digits
  R := TRegex.Compile('^[0-9]$');
  for i := Ord('0') to Ord('9') do
    Check(R.IsMatch(Chr(i)), '[0-9] ' + Chr(i));
  Check(not R.IsMatch('a'), '[0-9] miss a');

  // [a-f] matches a,b,c,d,e,f only
  R := TRegex.Compile('^[a-f]$');
  Check(R.IsMatch('a'), '[a-f] a');
  Check(R.IsMatch('f'), '[a-f] f');
  Check(not R.IsMatch('g'), '[a-f] miss g');
  Check(not R.IsMatch('A'), '[a-f] miss A');

  // [A-Z] matches uppercase only
  R := TRegex.Compile('^[A-Z]$');
  Check(R.IsMatch('A'), '[A-Z] A');
  Check(R.IsMatch('Z'), '[A-Z] Z');
  Check(not R.IsMatch('a'), '[A-Z] miss a');

  // [a-zA-Z] matches all letters
  R := TRegex.Compile('^[a-zA-Z]$');
  Check(R.IsMatch('a'), '[a-zA-Z] a');
  Check(R.IsMatch('Z'), '[a-zA-Z] Z');
  Check(not R.IsMatch('0'), '[a-zA-Z] miss 0');

  // [0-9a-fA-F] matches hex chars
  R := TRegex.Compile('^[0-9a-fA-F]$');
  Check(R.IsMatch('0'), 'hex 0');
  Check(R.IsMatch('9'), 'hex 9');
  Check(R.IsMatch('a'), 'hex a');
  Check(R.IsMatch('F'), 'hex F');
  Check(not R.IsMatch('g'), 'hex miss g');
  Check(not R.IsMatch('G'), 'hex miss G');

  // [-] matches literal dash
  R := TRegex.Compile('^[-]$');
  Check(R.IsMatch('-'), '[-] dash');
  Check(not R.IsMatch('a'), '[-] miss a');

  // [a-] matches 'a' and '-'
  R := TRegex.Compile('^[a-]$');
  Check(R.IsMatch('a'), '[a-] a');
  Check(R.IsMatch('-'), '[a-] dash');
  Check(not R.IsMatch('b'), '[a-] miss b');

  // [\]] matches literal ] (escaped)
  R := TRegex.Compile('^[\]]$');
  Check(R.IsMatch(']'), '[\]] bracket');
  Check(not R.IsMatch('a'), '[\]] miss a');

  // [^abc] matches anything except a,b,c
  R := TRegex.Compile('^[^abc]$');
  Check(R.IsMatch('d'), '[^abc] d');
  Check(R.IsMatch('z'), '[^abc] z');
  Check(not R.IsMatch('a'), '[^abc] miss a');
  Check(not R.IsMatch('b'), '[^abc] miss b');

  // [^0-9] matches non-digits
  R := TRegex.Compile('^[^0-9]$');
  Check(R.IsMatch('a'), '[^0-9] a');
  Check(not R.IsMatch('5'), '[^0-9] miss 5');
end;

{ --- 13. TestRegexReuse --- }
procedure TestRegexReuse;
var R: TRegex; M: TMatch; MA: TMatchArray; i: Integer; s: string;
begin
  // Compile once, use 1000 times with different inputs
  R := TRegex.Compile('(\d+)-(\w+)');
  for i := 1 to 1000 do
  begin
    s := 'item-' + IntToStr(i) + '-name';
    M := R.Find(s);
    Check(M.Found, 'reuse iter ' + IntToStr(i));
    // verify each call is independent
    CheckEqual(Int64(2), Int64(Length(M.Groups)), 'reuse groups ' + IntToStr(i));
  end;

  // Also test that FindAll doesn't corrupt state for next Find
  MA := R.FindAll('1-a 2-b 3-c');
  CheckEqual(Int64(3), Int64(Length(MA)), 'reuse findall count');
  M := R.Find('99-test');
  Check(M.Found, 'reuse after findall');
  CheckEqual('99', M.Groups[0].Value('99-test'), 'reuse after findall g0');
  CheckEqual('test', M.Groups[1].Value('99-test'), 'reuse after findall g1');

  // Mix IsMatch, Find, FindAll, Replace on same regex
  R := TRegex.Compile('\w+');
  Check(R.IsMatch('hello'), 'reuse mix ismatch');
  M := R.Find('world');
  Check(M.Found, 'reuse mix find');
  CheckEqual('world', M.Value('world'), 'reuse mix find val');
  MA := R.FindAll('a b c');
  CheckEqual(Int64(3), Int64(Length(MA)), 'reuse mix findall');
  s := R.ReplaceAll('x y', 'Z');
  CheckEqual('Z Z', s, 'reuse mix replace');

  // Verify no state leakage: Find after ReplaceAll
  M := R.Find('final');
  Check(M.Found, 'reuse after replace');
  CheckEqual('final', M.Value('final'), 'reuse after replace val');
end;

{ ===== ADVERSARIAL STRESS TESTS ===== }

{ --- ADV 1. TestAdversarialPatterns --- }
procedure TestAdversarialPatterns;
var R: TRegex; M: TMatch; err: string;
begin
  // Empty alternation: (|) — should match empty string
  R := TRegex.Compile('(|)');
  Check(R.IsMatch(''), 'empty alt matches empty');
  Check(R.IsMatch('anything'), 'empty alt matches anything');

  // Nested empty: (())+ — should compile and match empty
  R := TRegex.Compile('(())+');
  Check(R.IsMatch(''), 'nested empty matches');

  // Alternation with empty branch: a| — matches 'a' or empty
  R := TRegex.Compile('a|');
  Check(R.IsMatch('a'), 'a| matches a');
  Check(R.IsMatch('b'), 'a| matches b (empty branch)');

  // Only anchors: ^$ — matches empty string
  R := TRegex.Compile('^$');
  Check(R.IsMatch(''), '^$ matches empty');
  Check(not R.IsMatch('x'), '^$ no match non-empty');

  // Quantifier on anchor: ^+ — our engine allows it (assertion is quantifiable, just redundant)
  R := TRegex.Compile('^+');
  Check(R.IsMatch('hello'), '^+ matches (redundant quantifier on anchor)');
  Check(R.IsMatch(''), '^+ matches empty');

  // Nested quantifiers: (a+)+ — must not hang
  R := TRegex.Compile('(a+)+');
  Check(R.IsMatch('aaa'), '(a+)+ matches');
  Check(not R.IsMatch('bbb'), '(a+)+ no match');

  // Deeply alternated: ((a|b)|c)|d — should work
  R := TRegex.Compile('((a|b)|c)|d');
  Check(R.IsMatch('a'), 'deep alt a');
  Check(R.IsMatch('b'), 'deep alt b');
  Check(R.IsMatch('c'), 'deep alt c');
  Check(R.IsMatch('d'), 'deep alt d');
  Check(not R.IsMatch('e'), 'deep alt miss');

  // Concat of empties: ()()() — matches empty
  R := TRegex.Compile('()()()');
  M := R.Find('hello');
  Check(M.Found, 'concat empties found');
  CheckEqual(Int64(0), Int64(M.Len), 'concat empties len=0');

  // Group containing only anchor: (^)a — should work
  R := TRegex.Compile('(^)a');
  Check(R.IsMatch('abc'), '(^)a matches at start');
  Check(not R.IsMatch('ba'), '(^)a no match mid');

  // Multiple empty alternations: (||) — matches empty
  R := TRegex.Compile('(||)');
  Check(R.IsMatch(''), 'multi empty alt');
  Check(R.IsMatch('x'), 'multi empty alt on x');
end;

{ --- ADV 2. TestBinaryInput --- }
procedure TestBinaryInput;
var input: string; i: Integer; R: TRegex; M: TMatch;
begin
  // Input with all 256 byte values
  SetLength(input, 256);
  for i := 0 to 255 do input[i+1] := Chr(i);

  // \d should find digits at positions 48-57 (0-indexed: 48)
  R := TRegex.Compile('\d+');
  M := R.Find(input);
  Check(M.Found, 'digits in binary');
  CheckEqual(Int64(48), Int64(M.Start), 'digit start');
  CheckEqual(Int64(10), Int64(M.Len), 'digit len');

  // Pattern 'abc' — sequential bytes 97,98,99 exist in the input
  R := TRegex.Compile('abc');
  M := R.Find(input);
  Check(M.Found, 'abc in sequential bytes');
  CheckEqual(Int64(97), Int64(M.Start), 'abc position');

  // Null byte handling: find 'b' past null bytes
  SetLength(input, 5);
  input[1] := 'a'; input[2] := #0; input[3] := 'b'; input[4] := #0; input[5] := 'c';
  R := TRegex.Compile('b');
  M := R.Find(input);
  Check(M.Found, 'find past null');
  CheckEqual(Int64(2), Int64(M.Start), 'past null position');

  // Dot matches null byte (it's not \n)
  R := TRegex.Compile('a.b');
  M := R.Find(input);
  Check(M.Found, 'dot matches null byte');
  CheckEqual(Int64(0), Int64(M.Start), 'dot null start');

  // High bytes (128-255) as input
  SetLength(input, 4);
  input[1] := Chr(200); input[2] := Chr(201); input[3] := Chr(202); input[4] := Chr(203);
  R := TRegex.Compile('...');
  M := R.Find(input);
  Check(M.Found, 'high bytes dot');
  CheckEqual(Int64(3), Int64(M.Len), 'high bytes dot len');
end;

{ --- ADV 3. TestRepeatedCompile --- }
procedure TestRepeatedCompile;
var R: TRegex; i: Integer; pat: string;
begin
  // Compile 500 different patterns — tests parser/compiler memory management
  for i := 1 to 500 do
  begin
    pat := 'pattern' + IntToStr(i) + '\d+';
    R := TRegex.Compile(pat);
    Check(R.IsMatch('pattern' + IntToStr(i) + '99'), 'compile ' + IntToStr(i));
  end;

  // Compile same pattern 500 times
  for i := 1 to 500 do
  begin
    R := TRegex.Compile('(\w+)\s+(\d+)');
    Check(R.IsMatch('hello 42'), 'recompile ' + IntToStr(i));
  end;
end;

{ --- ADV 4. TestMaximalInput --- }
procedure TestMaximalInput;
var R: TRegex; M: TMatch; MA: TMatchArray; bigInput: string; i: Integer;
begin
  // 100KB input
  SetLength(bigInput, 100000);
  for i := 1 to 100000 do bigInput[i] := Chr(Ord('a') + (i mod 26));

  // Literal at the very end
  Move('NEEDLE'[1], bigInput[99995], 6);
  R := TRegex.Compile('NEEDLE');
  M := R.Find(bigInput);
  Check(M.Found, '100KB find');
  CheckEqual(Int64(99994), Int64(M.Start), '100KB position');

  // IsMatch on 100KB
  Check(R.IsMatch(bigInput), '100KB isMatch');

  // Pattern that matches nothing in 100KB — must complete fast
  R := TRegex.Compile('ZZZZZ');
  Check(not R.IsMatch(bigInput), '100KB no match');

  // FindAll with many matches in 100KB
  R := TRegex.Compile('a');
  MA := R.FindAll(bigInput);
  // 'a' appears at positions where (i mod 26) = 1, roughly 100000/26 ~ 3846 times
  Check(Length(MA) > 3000, '100KB many matches');
end;

{ --- ADV 5. TestTryCompileErrors --- }
procedure TestTryCompileErrors;
var R: TRegex; err: string;
begin
  // Each error should have a meaningful message
  TRegex.TryCompile('[abc', R, err);
  Check(Pos('character class', err) > 0, 'unclosed class msg: ' + err);

  TRegex.TryCompile('a{5,3}', R, err);
  Check(Pos('min', err) > 0, 'min>max msg: ' + err);

  TRegex.TryCompile('*abc', R, err);
  Check(Pos('quantifier', err) > 0, 'leading quantifier msg: ' + err);

  TRegex.TryCompile('\p{L}', R, err);
  Check(Pos('Unicode', err) > 0, 'unicode msg: ' + err);

  TRegex.TryCompile('a\', R, err);
  Check(Pos('backslash', err) > 0, 'trailing backslash msg: ' + err);

  TRegex.TryCompile(')', R, err);
  Check(Pos('parenthesis', err) > 0, 'unmatched paren msg: ' + err);

  // Valid patterns should not produce errors
  Check(TRegex.TryCompile('.*', R, err), 'valid .* no error');
  CheckEqual('', err, 'no error text');
end;

{ --- ADV 6. TestFindAllConsistency --- }
procedure TestFindAllConsistency;
var R: TRegex; MA: TMatchArray; M: TMatch; i: Integer; pos: SizeUInt;
    input: string;
begin
  input := 'the cat sat on the mat';
  R := TRegex.Compile('\b\w+\b');
  MA := R.FindAll(input);

  // Manually iterate with FindAt and verify same results
  pos := 0;
  for i := 0 to High(MA) do
  begin
    M := R.FindAt(input, pos);
    Check(M.Found, 'findAt ' + IntToStr(i));
    CheckEqual(Int64(MA[i].Start), Int64(M.Start), 'start ' + IntToStr(i));
    CheckEqual(Int64(MA[i].Len), Int64(M.Len), 'len ' + IntToStr(i));
    if M.Len > 0 then
      pos := SizeUInt(M.Start) + SizeUInt(M.Len)
    else
      pos := SizeUInt(M.Start) + 1;
  end;

  // After all matches, FindAt should return not found
  M := R.FindAt(input, pos);
  Check(not M.Found, 'no more matches');
end;

{ --- ADV 7. TestReplaceExpandConsistency --- }
procedure TestReplaceExpandConsistency;
var R: TRegex; s1: string;
    input: string;
begin
  input := '2026-05-31 and 2025-12-25';
  R := TRegex.Compile('(\d{4})-(\d{2})-(\d{2})');

  // ReplaceAllExpand should produce correct date reformatting
  s1 := R.ReplaceAllExpand(input, '$2/$3/$1');
  CheckEqual('05/31/2026 and 12/25/2025', s1, 'date reformat');

  // Verify with named groups too
  R := TRegex.Compile('(?P<y>\d{4})-(?P<m>\d{2})-(?P<d>\d{2})');
  s1 := R.ReplaceAllExpand(input, '${m}/${d}/${y}');
  CheckEqual('05/31/2026 and 12/25/2025', s1, 'date reformat named');
end;

{ --- ADV 8. TestPatternSyntaxCoverage --- }
procedure TestPatternSyntaxCoverage;
var R: TRegex; M: TMatch;
begin
  // One mega-pattern using many syntax elements:
  // Literal + dot + star + plus + question + alternation + group + class + anchor + shorthand + boundary + repeat + named + non-capturing
  R := TRegex.Compile('^(?P<proto>https?)://(?:www\.)?(?P<domain>[a-z0-9]+(?:\.[a-z]{2,4})+)(?P<path>/\w*)?$');
  M := R.Find('https://www.example.com/page');
  Check(M.Found, 'url pattern');
  CheckEqual('https://www.example.com/page', M.Value('https://www.example.com/page'), 'url full');

  // Verify named groups
  Check(R.GroupByName(M, 'proto').Found, 'proto found');
  CheckEqual('https', R.GroupByName(M, 'proto').Value('https://www.example.com/page'), 'proto value');
  Check(R.GroupByName(M, 'domain').Found, 'domain found');
  CheckEqual('example.com', R.GroupByName(M, 'domain').Value('https://www.example.com/page'), 'domain value');

  // Test without www
  M := R.Find('http://example.org/');
  Check(M.Found, 'url no www');
  CheckEqual('http', R.GroupByName(M, 'proto').Value('http://example.org/'), 'proto http');
  CheckEqual('example.org', R.GroupByName(M, 'domain').Value('http://example.org/'), 'domain org');
end;

{ --- ADV 9. TestIsFullMatchThorough --- }
procedure TestIsFullMatchThorough;
var R: TRegex;
begin
  R := TRegex.Compile('\d{4}-\d{2}-\d{2}');
  Check(R.IsFullMatch('2026-05-31'), 'date full');
  Check(not R.IsFullMatch('2026-05-31 extra'), 'date with extra');
  Check(not R.IsFullMatch('x2026-05-31'), 'date with prefix');
  Check(not R.IsFullMatch('2026-5-31'), 'date short month');

  R := TRegex.Compile('[a-z]+');
  Check(R.IsFullMatch('hello'), 'alpha full');
  Check(not R.IsFullMatch('hello world'), 'alpha with space');
  Check(not R.IsFullMatch('Hello'), 'alpha uppercase');
  Check(not R.IsFullMatch(''), 'alpha empty');

  R := TRegex.Compile('.*');
  Check(R.IsFullMatch(''), '.* empty');
  Check(R.IsFullMatch('anything'), '.* anything');

  R := TRegex.Compile('.+');
  Check(not R.IsFullMatch(''), '.+ empty');
  Check(R.IsFullMatch('x'), '.+ single');

  // Alternation full match
  R := TRegex.Compile('cat|dog|bird');
  Check(R.IsFullMatch('cat'), 'alt cat');
  Check(R.IsFullMatch('dog'), 'alt dog');
  Check(R.IsFullMatch('bird'), 'alt bird');
  Check(not R.IsFullMatch('cats'), 'alt cats');
  Check(not R.IsFullMatch(''), 'alt empty');
end;

{ --- ADV 10. TestGroupInteractionWithReplace --- }
procedure TestGroupInteractionWithReplace;
var R: TRegex; s: string;
begin
  // Swap two groups
  R := TRegex.Compile('(\w+)\s+(\w+)');
  s := R.ReplaceAllExpand('hello world', '$2 $1');
  CheckEqual('world hello', s, 'swap words');

  // Duplicate a group
  R := TRegex.Compile('(\w+)');
  s := R.ReplaceAllExpand('cat', '$1$1');
  CheckEqual('catcat', s, 'duplicate');

  // Named group in replacement
  R := TRegex.Compile('(?P<first>\w+)\s+(?P<last>\w+)');
  s := R.ReplaceAllExpand('John Smith', '${last}, ${first}');
  CheckEqual('Smith, John', s, 'named swap');

  // Group that didn't match — should produce empty
  R := TRegex.Compile('(a)?(b)');
  s := R.ReplaceAllExpand('b', '[$1]$2');
  CheckEqual('[]b', s, 'optional group empty');

  // $0 is the full match
  R := TRegex.Compile('\d+');
  s := R.ReplaceAllExpand('val=42', '($0)');
  CheckEqual('val=(42)', s, '$0 full match');
end;

{ --- ADV 11. TestCaseInsensitiveWithCaptures --- }
procedure TestCaseInsensitiveWithCaptures;
var R: TRegex; M: TMatch; MA: TMatchArray;
begin
  R := TRegex.Compile('(?i)(?P<word>[a-z]+)');
  M := R.Find('HELLO world');
  Check(M.Found, '(?i) named find');
  CheckEqual('HELLO', M.Value('HELLO world'), '(?i) matches uppercase');
  CheckEqual('HELLO', R.GroupByName(M, 'word').Value('HELLO world'), '(?i) group value');

  // FindAll with (?i)
  R := TRegex.Compile('(?i)cat');
  MA := R.FindAll('Cat CAT cat cAt');
  CheckEqual(Int64(4), Int64(Length(MA)), '(?i) findall count');

  // Replace with (?i) — preserves original case in $1
  R := TRegex.Compile('(?i)(hello)');
  CheckEqual('[HELLO] [Hello] [hello]',
    R.ReplaceAllExpand('HELLO Hello hello', '[$1]'),
    '(?i) replace preserves case');
end;

{ --- ADV 12. TestQuoteMetaRoundTrip --- }
procedure TestQuoteMetaRoundTrip;
var R: TRegex; i: Integer; ch: Char; s, q: string;
begin
  // Every printable ASCII byte: QuoteMeta then Compile should match literally
  for i := 32 to 126 do
  begin
    ch := Chr(i);
    s := ch;
    q := RegexQuoteMeta(s);
    R := TRegex.Compile(q);
    Check(R.IsMatch(s), 'roundtrip byte ' + IntToStr(i));
    // Should NOT match a different char (unless pattern is . which is quoted to \.)
    if ch <> 'a' then
      Check(not R.IsFullMatch('a'), 'no false match byte ' + IntToStr(i));
  end;

  // Multi-char strings with all metacharacters
  s := '.*+?()[]{}|^$\';
  q := RegexQuoteMeta(s);
  R := TRegex.Compile(q);
  Check(R.IsMatch(s), 'all metachar roundtrip');
  Check(R.IsFullMatch(s), 'all metachar full');
end;

{ --- ADV 13. TestMemoryLeakOnError --- }
procedure TestMemoryLeakOnError;
var R: TRegex; err: string; i: Integer;
begin
  // Compile 100 invalid patterns — must not leak
  for i := 1 to 100 do
  begin
    TRegex.TryCompile('(((unclosed', R, err);
    TRegex.TryCompile('[unclosed', R, err);
    TRegex.TryCompile('a{9999}', R, err);
    TRegex.TryCompile('\p{L}', R, err);
    TRegex.TryCompile('*invalid', R, err);
  end;
  // If heaptrc shows 0 leaks after this, we're good
  Check(True, '500 error compiles no crash');
end;

{ ===== ENCODING CORRECTNESS TESTS ===== }

{ --- ENC 1. TestUTF8Bytes --- }
procedure TestUTF8Bytes;
var R: TRegex; M: TMatch; MA: TMatchArray;
    utf8_hello: string;
    utf8_cjk: string;
begin
  // 'e-acute' is 2 bytes in UTF-8: $C3 $A9
  // 'Hello' = H + $C3$A9 + l + l + o = 7 bytes
  utf8_hello := 'H' + Chr($C3) + Chr($A9) + 'llo';

  // . matches each BYTE, not each codepoint
  R := TRegex.Compile('...');
  M := R.Find(utf8_hello);
  Check(M.Found, 'dot matches bytes');
  CheckEqual(Int64(3), Int64(M.Len), 'dot 3 bytes');
  // First 3 bytes: H, $C3, $A9

  // \w matches ASCII only — high bytes are NOT word chars
  R := TRegex.Compile('\w+');
  M := R.Find(utf8_hello);
  Check(M.Found, '\w on utf8');
  CheckEqual('H', M.Value(utf8_hello), '\w stops at non-ASCII');

  // Literal ASCII in UTF-8 string — 'llo' starts at byte 3 (H=0, $C3=1, $A9=2, l=3)
  R := TRegex.Compile('llo');
  M := R.Find(utf8_hello);
  Check(M.Found, 'literal in utf8');
  CheckEqual(Int64(3), Int64(M.Start), 'literal position in utf8');

  // FindAll \w+ on mixed UTF-8/ASCII
  // 'cafe-acute' = c + a + f + $C3$A9 = 5 bytes. \w+ matches 'caf' then stops
  R := TRegex.Compile('\w+');
  MA := R.FindAll('caf' + Chr($C3) + Chr($A9) + ' ok');
  // Should find 'caf' and 'ok'
  CheckEqual(Int64(2), Int64(Length(MA)), 'utf8 word split');
  CheckEqual('caf', MA[0].Value('caf' + Chr($C3) + Chr($A9) + ' ok'), 'first word');

  // CJK: U+4E2D = $E4$B8$AD (3 bytes)
  utf8_cjk := Chr($E4) + Chr($B8) + Chr($AD);
  R := TRegex.Compile('...');
  M := R.Find(utf8_cjk);
  Check(M.Found, 'cjk 3 bytes');
  CheckEqual(Int64(3), Int64(M.Len), 'cjk dot len');

  // \d should NOT match CJK bytes
  R := TRegex.Compile('\d');
  Check(not R.IsMatch(utf8_cjk), 'cjk not digit');
end;

{ --- ENC 2. TestLatin1Bytes --- }
procedure TestLatin1Bytes;
var R: TRegex; M: TMatch;
    latin1: string;
begin
  // In Latin-1, n-tilde = $F1, u-umlaut = $FC, sharp-s = $DF
  latin1 := 'espa' + Chr($F1) + 'ol';  // 'espanol' with n-tilde

  // . matches the high byte
  R := TRegex.Compile('espa.ol');
  Check(R.IsMatch(latin1), 'dot matches latin1 high byte');

  // \w does NOT match high bytes (ASCII only)
  R := TRegex.Compile('^\w+$');
  Check(not R.IsFullMatch(latin1), '\w rejects latin1');

  // [a-z] does NOT match high bytes
  R := TRegex.Compile('^[a-z]+$');
  Check(not R.IsFullMatch(latin1), '[a-z] rejects latin1');

  // [^a-zA-Z0-9] matches the n-tilde byte
  R := TRegex.Compile('[^a-zA-Z0-9]');
  M := R.Find(latin1);
  Check(M.Found, 'non-ascii found');
  CheckEqual(Int64(4), Int64(M.Start), 'non-ascii position');

  // Literal high byte in pattern
  R := TRegex.Compile(Chr($F1));
  M := R.Find(latin1);
  Check(M.Found, 'literal high byte');
  CheckEqual(Int64(4), Int64(M.Start), 'high byte position');
end;

{ --- ENC 3. TestControlChars --- }
procedure TestControlChars;
var R: TRegex; M: TMatch; MA: TMatchArray;
    input: string;
begin
  // Tab, CR, LF handling
  input := 'line1' + #9 + 'tab' + #13 + #10 + 'line2';

  // \s matches tab, cr, lf
  R := TRegex.Compile('\s+');
  MA := R.FindAll(input);
  Check(Length(MA) >= 2, 'whitespace in control chars');

  // . does NOT match \n (byte 10) but DOES match \r (byte 13) and \t (byte 9)
  R := TRegex.Compile('.+');
  M := R.Find(input);
  Check(M.Found, 'dot stops at LF');
  // Should match 'line1\ttab\r' (everything up to \n)
  CheckEqual(Int64(10), Int64(M.Len), 'dot len before LF');

  // Null byte (0x00) — . matches it (it's not \n)
  input := 'a' + #0 + 'b';
  R := TRegex.Compile('.+');
  M := R.Find(input);
  Check(M.Found, 'dot matches null');
  CheckEqual(Int64(3), Int64(M.Len), 'dot through null');

  // \s does NOT match null
  R := TRegex.Compile('\s');
  Check(not R.IsMatch(#0), 'null not whitespace');

  // Bell, escape, form feed
  R := TRegex.Compile('.');
  Check(R.IsMatch(#7), 'dot matches bell');
  Check(R.IsMatch(#27), 'dot matches escape');
  Check(R.IsMatch(#12), 'dot matches form feed');
  Check(not R.IsMatch(#10), 'dot rejects LF');
end;

{ --- ENC 4. TestByteExactness --- }
procedure TestByteExactness;
var R: TRegex; M: TMatch;
    input: string;
begin
  // Multi-byte UTF-8 char followed by ASCII
  // u-umlaut in UTF-8: $C3$BC + b + e + r = 5 bytes
  input := Chr($C3) + Chr($BC) + 'ber';

  // Find 'ber' — should be at byte offset 2, not codepoint offset 1
  R := TRegex.Compile('ber');
  M := R.Find(input);
  Check(M.Found, 'find after multibyte');
  CheckEqual(Int64(2), Int64(M.Start), 'byte offset after multibyte');

  // 3-byte UTF-8 + ASCII: euro + 'abc' = $E2$82$AC + a + b + c = 6 bytes
  input := Chr($E2) + Chr($82) + Chr($AC) + 'abc';
  R := TRegex.Compile('abc');
  M := R.Find(input);
  Check(M.Found, 'find after 3-byte');
  CheckEqual(Int64(3), Int64(M.Start), 'byte offset after 3-byte');

  // 4-byte UTF-8 + ASCII: emoji + 'hi' = 4 + 2 = 6 bytes
  // U+1F600 = $F0$9F$98$80
  input := Chr($F0) + Chr($9F) + Chr($98) + Chr($80) + 'hi';
  R := TRegex.Compile('hi');
  M := R.Find(input);
  Check(M.Found, 'find after 4-byte');
  CheckEqual(Int64(4), Int64(M.Start), 'byte offset after 4-byte');

  // Verify Len is in bytes
  R := TRegex.Compile('..');
  M := R.Find(input);
  CheckEqual(Int64(2), Int64(M.Len), 'len is bytes not codepoints');
end;

{ --- ENC 5. TestWordBoundaryWithEncoding --- }
procedure TestWordBoundaryWithEncoding;
var R: TRegex; MA: TMatchArray;
begin
  // \b is ASCII-only: high bytes are non-word chars
  // 'cafe-acute' (UTF-8) = c,a,f,$C3,$A9 — \b sees boundary between 'f' and $C3
  R := TRegex.Compile('\b\w+\b');
  MA := R.FindAll('caf' + Chr($C3) + Chr($A9) + ' world');
  // Should find 'caf' and 'world' (high bytes break the word)
  Check(Length(MA) >= 2, 'word boundary with utf8');
  CheckEqual('caf', MA[0].Value('caf' + Chr($C3) + Chr($A9) + ' world'), 'word before utf8');

  // \b at high byte boundary
  R := TRegex.Compile('\btest\b');
  Check(R.IsMatch(Chr($FF) + 'test' + Chr($FF)), '\b with high bytes');
  Check(R.IsMatch('test'), '\b normal');

  // \B (non-boundary) between ASCII word chars
  R := TRegex.Compile('a\Bb');
  Check(R.IsMatch('ab'), '\B between word chars');
  Check(not R.IsMatch('a b'), '\B not between word and space');
end;

{ --- ENC 6. TestCharClassWithHighBytes --- }
procedure TestCharClassWithHighBytes;
var R: TRegex; i: Integer;
begin
  // [^a-zA-Z0-9\s] should match high bytes
  R := TRegex.Compile('[^a-zA-Z0-9\s]');
  Check(R.IsMatch(Chr($80)), 'class matches $80');
  Check(R.IsMatch(Chr($FF)), 'class matches $FF');
  Check(R.IsMatch(Chr($C3)), 'class matches $C3');
  Check(not R.IsMatch('a'), 'class rejects a');
  Check(not R.IsMatch(' '), 'class rejects space');

  // Negated \w matches high bytes
  R := TRegex.Compile('\W');
  Check(R.IsMatch(Chr($80)), '\W matches high byte');
  Check(R.IsMatch(Chr($FF)), '\W matches $FF');

  // \d does NOT match any high byte
  R := TRegex.Compile('\d');
  for i := 128 to 255 do
    Check(not R.IsMatch(Chr(i)), '\d rejects byte ' + IntToStr(i));

  // Dot matches all high bytes (they are not \n)
  R := TRegex.Compile('^.$');
  for i := 128 to 255 do
    Check(R.IsFullMatch(Chr(i)), 'dot matches byte ' + IntToStr(i));
end;

{ --- ENC 7. TestNewlineHandling --- }
procedure TestNewlineHandling;
var R: TRegex; M: TMatch; MA: TMatchArray;
begin
  // . stops at \n only, not \r
  R := TRegex.Compile('.+');
  M := R.Find('abc' + #13 + #10 + 'def');
  Check(M.Found, 'dot with CRLF');
  CheckEqual(Int64(4), Int64(M.Len), 'dot includes CR');
  // Matches 'abc\r' (4 bytes), stops at \n

  // In single-line mode, ^ matches start of input, $ matches end
  R := TRegex.Compile('^abc$');
  Check(not R.IsMatch('abc' + #10 + 'def'), '^ $ single line');
  Check(R.IsFullMatch('abc'), '^ $ exact');

  // \s matches \r and \n
  R := TRegex.Compile('\s');
  Check(R.IsMatch(#13), '\s matches CR');
  Check(R.IsMatch(#10), '\s matches LF');

  // FindAll .+ splits on \n
  R := TRegex.Compile('.+');
  MA := R.FindAll('line1' + #10 + 'line2' + #10 + 'line3');
  CheckEqual(Int64(3), Int64(Length(MA)), 'dot findall lines');
  CheckEqual('line1', MA[0].Value('line1' + #10 + 'line2' + #10 + 'line3'), 'first line');
end;

{ --- ENC 8. TestMixedEncodingInput --- }
procedure TestMixedEncodingInput;
var R: TRegex; M: TMatch;
    input: string;
begin
  // Log line with UTF-8 username: '2026-05-31 [user-cn] logged in'
  // Chinese chars = $E7$94$A8 + $E6$88$B7 = 6 bytes
  input := '2026-05-31 [' + Chr($E7) + Chr($94) + Chr($A8) + Chr($E6) + Chr($88) + Chr($B7) + '] logged in';

  // Extract date with \d pattern
  R := TRegex.Compile('\d{4}-\d{2}-\d{2}');
  M := R.Find(input);
  Check(M.Found, 'date in mixed');
  CheckEqual('2026-05-31', M.Value(input), 'date value');

  // Extract bracketed content with [^\[\]]+
  R := TRegex.Compile('\[([^\[\]]+)\]');
  M := R.Find(input);
  Check(M.Found, 'bracket in mixed');
  // The bracketed content is the 6 UTF-8 bytes
  CheckEqual(Int64(6), Int64(M.Groups[0].Len), 'bracket content len');

  // Find 'logged in' after UTF-8 content
  R := TRegex.Compile('logged in');
  M := R.Find(input);
  Check(M.Found, 'ascii after utf8');

  // Email with international domain (punycode-like)
  input := 'user@xn--e1afmapc.xn--p1ai';
  R := TRegex.Compile('[a-z0-9.]+@[a-z0-9.-]+');
  M := R.Find(input);
  Check(M.Found, 'email punycode');
  CheckEqual(input, M.Value(input), 'email full');
end;

{ --- ENC 9. TestPatternWithHighBytes --- }
procedure TestPatternWithHighBytes;
var R: TRegex;
begin
  // Literal high byte in pattern
  R := TRegex.Compile(Chr($C3) + Chr($A9));  // e-acute in UTF-8
  Check(R.IsMatch('caf' + Chr($C3) + Chr($A9)), 'literal utf8 in pattern');
  Check(not R.IsMatch('cafe'), 'literal utf8 miss');

  // High byte in char class
  R := TRegex.Compile('[' + Chr($C3) + ']');
  Check(R.IsMatch(Chr($C3)), 'high byte in class');
  Check(not R.IsMatch('a'), 'high byte class miss');

  // Alternation with high bytes
  R := TRegex.Compile('cat|' + Chr($E7) + Chr($8C) + Chr($AB));  // cat|cat-cn
  Check(R.IsMatch('cat'), 'alt ascii');
  Check(R.IsMatch(Chr($E7) + Chr($8C) + Chr($AB)), 'alt utf8');
  Check(not R.IsMatch('dog'), 'alt miss');
end;

{ --- ENC 10. TestOffByOnePositions --- }
procedure TestOffByOnePositions;
var R: TRegex; M: TMatch;
begin
  // Match at position 0
  R := TRegex.Compile('a');
  M := R.Find('abc');
  CheckEqual(Int64(0), Int64(M.Start), 'pos 0');
  CheckEqual(Int64(1), Int64(M.Len), 'len 1');

  // Match at last position
  M := R.Find('xxa');
  CheckEqual(Int64(2), Int64(M.Start), 'last pos');

  // Match entire string
  R := TRegex.Compile('abc');
  M := R.Find('abc');
  CheckEqual(Int64(0), Int64(M.Start), 'full start');
  CheckEqual(Int64(3), Int64(M.Len), 'full len');

  // Single char input
  R := TRegex.Compile('.');
  M := R.Find('x');
  CheckEqual(Int64(0), Int64(M.Start), 'single start');
  CheckEqual(Int64(1), Int64(M.Len), 'single len');

  // Empty match at end ($)
  R := TRegex.Compile('$');
  M := R.Find('abc');
  CheckEqual(Int64(3), Int64(M.Start), '$ position');
  CheckEqual(Int64(0), Int64(M.Len), '$ len');

  // Empty match at start (^)
  R := TRegex.Compile('^');
  M := R.Find('abc');
  CheckEqual(Int64(0), Int64(M.Start), '^ position');
  CheckEqual(Int64(0), Int64(M.Len), '^ len');

  // FindAt at exact boundary
  R := TRegex.Compile('b');
  M := R.FindAt('abc', 1);
  CheckEqual(Int64(1), Int64(M.Start), 'findAt exact');
  M := R.FindAt('abc', 2);
  Check(not M.Found, 'findAt past');
end;

{ --- ENC 11. TestCaseFoldingBoundary --- }
procedure TestCaseFoldingBoundary;
var R: TRegex;
begin
  // (?i) only folds ASCII letters (a-z, A-Z)
  // High bytes should NOT be case-folded
  R := TRegex.Compile('(?i)' + Chr($C3) + Chr($A9));  // e-acute — no uppercase fold
  Check(R.IsMatch(Chr($C3) + Chr($A9)), '(?i) high byte exact');
  Check(not R.IsMatch(Chr($C3) + Chr($89)), '(?i) no high byte fold');
  // $C3$89 would be E-acute in UTF-8, but our engine does not know that

  // (?i) with mixed ASCII and high bytes
  R := TRegex.Compile('(?i)caf' + Chr($C3) + Chr($A9));
  Check(R.IsMatch('CAF' + Chr($C3) + Chr($A9)), '(?i) ascii fold only');
  Check(not R.IsMatch('CAF' + Chr($C3) + Chr($89)), '(?i) no utf8 fold');

  // (?i) at byte 127/128 boundary
  R := TRegex.Compile('(?i)z');  // z=$7A, Z=$5A
  Check(R.IsMatch('z'), '(?i) z');
  Check(R.IsMatch('Z'), '(?i) Z');
  // Byte $7B ('{') should NOT match
  Check(not R.IsMatch('{'), '(?i) z not {');
end;

{ --- ENC 12. TestShorthandWithEncoding --- }
procedure TestShorthandWithEncoding;
var R: TRegex; i: Integer;
begin
  // \d matches ONLY 0-9 (bytes 48-57)
  R := TRegex.Compile('^\d$');
  for i := 0 to 255 do
  begin
    if (i >= 48) and (i <= 57) then
      Check(R.IsFullMatch(Chr(i)), '\d matches ' + IntToStr(i))
    else
      Check(not R.IsFullMatch(Chr(i)), '\d rejects ' + IntToStr(i));
  end;

  // \w matches a-z, A-Z, 0-9, _ (and nothing else)
  R := TRegex.Compile('^\w$');
  for i := 0 to 255 do
  begin
    if ((i >= 97) and (i <= 122)) or   // a-z
       ((i >= 65) and (i <= 90)) or    // A-Z
       ((i >= 48) and (i <= 57)) or    // 0-9
       (i = 95) then                    // _
      Check(R.IsFullMatch(Chr(i)), '\w matches ' + IntToStr(i))
    else
      Check(not R.IsFullMatch(Chr(i)), '\w rejects ' + IntToStr(i));
  end;

  // \s matches space(32), \t(9), \n(10), \r(13), \f(12), \v(11)
  R := TRegex.Compile('^\s$');
  Check(R.IsFullMatch(Chr(32)), '\s space');
  Check(R.IsFullMatch(Chr(9)), '\s tab');
  Check(R.IsFullMatch(Chr(10)), '\s lf');
  Check(R.IsFullMatch(Chr(13)), '\s cr');
  Check(R.IsFullMatch(Chr(12)), '\s ff');
  Check(R.IsFullMatch(Chr(11)), '\s vt');
  Check(not R.IsFullMatch(Chr(0)), '\s not null');
  Check(not R.IsFullMatch(Chr(128)), '\s not $80');
end;

{ --- ENC 13. TestValueExtraction --- }
procedure TestValueExtraction;
var R: TRegex; M: TMatch;
    input: string;
begin
  // Value() uses Copy(AInput, Start+1, Len) — verify with multi-byte
  input := 'xx' + Chr($E4) + Chr($B8) + Chr($AD) + 'yy';  // 'xx' + CJK + 'yy'
  R := TRegex.Compile('...');
  M := R.Find(input);
  // First 3 bytes: 'x', 'x', $E4
  Check(M.Found, 'value extract');
  CheckEqual(Int64(0), Int64(M.Start), 'value start');
  CheckEqual(Int64(3), Int64(M.Len), 'value len');
  // Value should be exactly 3 bytes
  CheckEqual(Int64(3), Int64(Length(M.Value(input))), 'value string len');

  // Capture group value with high bytes
  R := TRegex.Compile('x(..)y');
  M := R.Find(input);
  if M.Found then
  begin
    // Group should capture the 2 bytes between x and y
    Check(M.Groups[0].Found, 'group found');
    CheckEqual(Int64(2), Int64(M.Groups[0].Len), 'group len');
  end;

  // Empty match value
  R := TRegex.Compile('');
  M := R.Find('abc');
  Check(M.Found, 'empty match');
  CheckEqual('', M.Value('abc'), 'empty value');

  // Full match value
  R := TRegex.Compile('.*');
  M := R.Find(input);
  CheckEqual(input, M.Value(input), 'full value');
end;

{ ===== DFA v2 ASSERTION CORRECTNESS TESTS ===== }

procedure TestDfaAssertionCorrectness;
var R: TRegex; MA: TMatchArray;
begin
  // ^hello matches only at start
  R := TRegex.Compile('^hello');
  Check(R.IsMatch('hello world'), 'dfa ^hello start');
  Check(not R.IsMatch('say hello'), 'dfa ^hello miss');
  Check(R.IsMatch('hello'), 'dfa ^hello exact');

  // world$ matches only at end
  R := TRegex.Compile('world$');
  Check(R.IsMatch('hello world'), 'dfa world$ end');
  Check(not R.IsMatch('world!'), 'dfa world$ miss');
  Check(R.IsMatch('world'), 'dfa world$ exact');

  // ^exact$ full match only
  R := TRegex.Compile('^exact$');
  Check(R.IsMatch('exact'), 'dfa ^exact$ match');
  Check(not R.IsMatch('not exact'), 'dfa ^exact$ miss start');
  Check(not R.IsMatch('exact!'), 'dfa ^exact$ miss end');
  Check(not R.IsMatch(''), 'dfa ^exact$ empty');

  // \bword\b word boundaries
  R := TRegex.Compile('\bword\b');
  Check(R.IsMatch('a word here'), 'dfa wb isolated');
  Check(not R.IsMatch('password'), 'dfa wb inside');
  Check(not R.IsMatch('wordy'), 'dfa wb prefix');
  Check(R.IsMatch('word'), 'dfa wb exact');
  Check(R.IsMatch('word.'), 'dfa wb before punct');
  Check(R.IsMatch('!word!'), 'dfa wb punct');
  Check(R.IsMatch(' word '), 'dfa wb space');
  Check(R.IsMatch('(word)'), 'dfa wb parens');

  // \Boo\B non-word boundaries
  R := TRegex.Compile('\Boo\B');
  Check(R.IsMatch('foobar'), 'dfa nwb inside');
  Check(not R.IsMatch('oo'), 'dfa nwb standalone');
  Check(not R.IsMatch('foo'), 'dfa nwb at end');
  Check(not R.IsMatch('oof'), 'dfa nwb at start');

  // ^\d+$ anchored digits
  R := TRegex.Compile('^\d+$');
  Check(R.IsMatch('12345'), 'dfa ^d+$ digits');
  Check(not R.IsMatch('abc'), 'dfa ^d+$ alpha');
  Check(not R.IsMatch('12a'), 'dfa ^d+$ mixed');
  Check(not R.IsMatch(''), 'dfa ^d+$ empty');

  // ^[a-z]+$ on various inputs
  R := TRegex.Compile('^[a-z]+$');
  Check(R.IsMatch('hello'), 'dfa ^az+$ match');
  Check(not R.IsMatch('Hello'), 'dfa ^az+$ upper');
  Check(not R.IsMatch('hello world'), 'dfa ^az+$ space');
  Check(not R.IsMatch(''), 'dfa ^az+$ empty');

  // \b\w+\b FindAll must find all words
  R := TRegex.Compile('\b\w+\b');
  MA := R.FindAll('hello world 123');
  CheckEqual(Int64(3), Int64(Length(MA)), 'dfa bwb findall count');
  CheckEqual('hello', MA[0].Value('hello world 123'), 'dfa bwb word 0');
  CheckEqual('world', MA[1].Value('hello world 123'), 'dfa bwb word 1');
  CheckEqual('123', MA[2].Value('hello world 123'), 'dfa bwb word 2');

  // ^$ on empty string must match
  R := TRegex.Compile('^$');
  Check(R.IsMatch(''), 'dfa ^$ empty match');
  // ^$ on non-empty must NOT match
  Check(not R.IsMatch('a'), 'dfa ^$ non-empty miss');

  // \b at start/end of input
  R := TRegex.Compile('\bfoo\b');
  Check(R.IsMatch('foo'), 'dfa wb start+end');
  Check(R.IsMatch('foo bar'), 'dfa wb at start');
  Check(R.IsMatch('bar foo'), 'dfa wb at end');

  // ^cat|^dog mixing assertions with alternation
  R := TRegex.Compile('^cat|^dog');
  Check(R.IsMatch('cat'), 'dfa ^cat|^dog cat');
  Check(R.IsMatch('dog'), 'dfa ^cat|^dog dog');
  Check(not R.IsMatch('bird'), 'dfa ^cat|^dog miss');
  Check(not R.IsMatch('a cat'), 'dfa ^cat|^dog mid');

  // ^\d+ mixing assertions with quantifiers
  R := TRegex.Compile('^\d+');
  Check(R.IsMatch('123abc'), 'dfa ^d+ start digits');
  Check(not R.IsMatch('abc123'), 'dfa ^d+ no start digit');

  // IsFullMatch with DFA must match NFA results
  R := TRegex.Compile('^[a-z]+$');
  Check(R.IsFullMatch('hello'), 'dfa fullmatch hello');
  Check(not R.IsFullMatch('Hello'), 'dfa fullmatch upper');
  Check(not R.IsFullMatch(''), 'dfa fullmatch empty');

  R := TRegex.Compile('^\d{3}-\d{4}$');
  Check(R.IsFullMatch('123-4567'), 'dfa fullmatch phone');
  Check(not R.IsFullMatch('12-4567'), 'dfa fullmatch phone short');
  Check(not R.IsFullMatch('123-456'), 'dfa fullmatch phone short2');

  // DFA IsFullMatch vs NFA IsFullMatch consistency
  R := TRegex.Compile('\b\w+\b');
  Check(R.IsFullMatch('hello') = NfaIsFullMatch(CompileProgram('\b\w+\b'), PAnsiChar('hello'), 5),
    'dfa vs nfa fullmatch hello');
  Check(R.IsFullMatch('hello world') = NfaIsFullMatch(CompileProgram('\b\w+\b'), PAnsiChar('hello world'), 11),
    'dfa vs nfa fullmatch multi');
end;

procedure TestDfaFindAllCorrectness;
var R: TRegex; MA, NfaMA: TMatchArray; i: Integer; s: string; P: TRegexProgram;
begin
  // \w+ on 'hello world 123' same matches as NFA
  R := TRegex.Compile('\w+');
  P := CompileProgram('\w+');
  s := 'hello world 123';
  MA := R.FindAll(s);
  NfaMA := NfaFindAll(P, PAnsiChar(s), Length(s));
  CheckEqual(Int64(Length(NfaMA)), Int64(Length(MA)), 'dfa findall w+ count');
  for i := 0 to High(MA) do
  begin
    CheckEqual(Int64(NfaMA[i].Start), Int64(MA[i].Start), 'dfa findall w+ start ' + IntToStr(i));
    CheckEqual(Int64(NfaMA[i].Len), Int64(MA[i].Len), 'dfa findall w+ len ' + IntToStr(i));
  end;

  // \d+ on 'a1b22c333' same positions and lengths
  R := TRegex.Compile('\d+');
  P := CompileProgram('\d+');
  s := 'a1b22c333';
  MA := R.FindAll(s);
  NfaMA := NfaFindAll(P, PAnsiChar(s), Length(s));
  CheckEqual(Int64(Length(NfaMA)), Int64(Length(MA)), 'dfa findall d+ count');
  for i := 0 to High(MA) do
  begin
    CheckEqual(Int64(NfaMA[i].Start), Int64(MA[i].Start), 'dfa findall d+ start ' + IntToStr(i));
    CheckEqual(Int64(NfaMA[i].Len), Int64(MA[i].Len), 'dfa findall d+ len ' + IntToStr(i));
  end;

  // [a-z]+ on 'ABC def GHI jkl' same results
  R := TRegex.Compile('[a-z]+');
  P := CompileProgram('[a-z]+');
  s := 'ABC def GHI jkl';
  MA := R.FindAll(s);
  NfaMA := NfaFindAll(P, PAnsiChar(s), Length(s));
  CheckEqual(Int64(Length(NfaMA)), Int64(Length(MA)), 'dfa findall az+ count');
  for i := 0 to High(MA) do
  begin
    CheckEqual(Int64(NfaMA[i].Start), Int64(MA[i].Start), 'dfa findall az+ start ' + IntToStr(i));
    CheckEqual(Int64(NfaMA[i].Len), Int64(MA[i].Len), 'dfa findall az+ len ' + IntToStr(i));
  end;

  // Empty pattern on 'abc'
  R := TRegex.Compile('');
  s := 'abc';
  MA := R.FindAll(s);
  CheckEqual(Int64(4), Int64(Length(MA)), 'dfa findall empty count');
  CheckEqual(Int64(0), Int64(MA[0].Start), 'dfa findall empty pos0');
  CheckEqual(Int64(0), Int64(MA[0].Len), 'dfa findall empty len0');
  CheckEqual(Int64(3), Int64(MA[3].Start), 'dfa findall empty pos3');

  // Pattern matching entire input
  R := TRegex.Compile('hello');
  s := 'hello';
  MA := R.FindAll(s);
  CheckEqual(Int64(1), Int64(Length(MA)), 'dfa findall entire count');
  CheckEqual(Int64(0), Int64(MA[0].Start), 'dfa findall entire start');
  CheckEqual(Int64(5), Int64(MA[0].Len), 'dfa findall entire len');

  // Pattern with no matches
  R := TRegex.Compile('xyz');
  s := 'hello world';
  MA := R.FindAll(s);
  CheckEqual(Int64(0), Int64(Length(MA)), 'dfa findall no match');

  // Adjacent matches
  R := TRegex.Compile('ab');
  s := 'ababab';
  MA := R.FindAll(s);
  CheckEqual(Int64(3), Int64(Length(MA)), 'dfa findall adjacent count');
  CheckEqual(Int64(0), Int64(MA[0].Start), 'dfa findall adjacent 0');
  CheckEqual(Int64(2), Int64(MA[1].Start), 'dfa findall adjacent 1');
  CheckEqual(Int64(4), Int64(MA[2].Start), 'dfa findall adjacent 2');

  // Zero-length matches (pattern that can match empty)
  R := TRegex.Compile('a*');
  P := CompileProgram('a*');
  s := 'bab';
  MA := R.FindAll(s);
  NfaMA := NfaFindAll(P, PAnsiChar(s), Length(s));
  CheckEqual(Int64(Length(NfaMA)), Int64(Length(MA)), 'dfa findall a* count');
  for i := 0 to High(MA) do
  begin
    CheckEqual(Int64(NfaMA[i].Start), Int64(MA[i].Start), 'dfa findall a* start ' + IntToStr(i));
    CheckEqual(Int64(NfaMA[i].Len), Int64(MA[i].Len), 'dfa findall a* len ' + IntToStr(i));
  end;
end;

{ ===== DFA vs NFA CROSS-VALIDATION (50+ pattern/input pairs) ===== }

procedure TestDfaNfaCrossValidation;
type
  TTestCase = record
    Pattern: string;
    Input: string;
  end;
const
  NUM_CASES = 60;
  Cases: array[0..NUM_CASES-1] of TTestCase = (
    { Patterns WITHOUT assertions }
    (Pattern: 'hello'; Input: 'hello world'),
    (Pattern: 'hello'; Input: 'goodbye'),
    (Pattern: 'hello'; Input: ''),
    (Pattern: 'a*'; Input: ''),
    (Pattern: 'a*'; Input: 'aaa'),
    (Pattern: 'a*'; Input: 'bbb'),
    (Pattern: 'a+'; Input: ''),
    (Pattern: 'a+'; Input: 'a'),
    (Pattern: 'a+'; Input: 'b'),
    (Pattern: 'cat|dog'; Input: 'cat'),
    (Pattern: 'cat|dog'; Input: 'dog'),
    (Pattern: 'cat|dog'; Input: 'bird'),
    (Pattern: 'cat|dog'; Input: ''),
    (Pattern: '\d+'; Input: 'abc 123 def'),
    (Pattern: '\d+'; Input: 'no digits'),
    (Pattern: '\d+'; Input: ''),
    (Pattern: '\w+'; Input: 'hello'),
    (Pattern: '\w+'; Input: '   '),
    (Pattern: '[a-z]+'; Input: 'ABC'),
    (Pattern: '[a-z]+'; Input: 'abc'),
    (Pattern: '.'; Input: ''),
    (Pattern: '.'; Input: 'x'),
    (Pattern: 'a{2,4}'; Input: 'a'),
    (Pattern: 'a{2,4}'; Input: 'aa'),
    (Pattern: 'a{2,4}'; Input: 'aaaa'),
    { Patterns WITH assertions - ^ }
    (Pattern: '^hello'; Input: 'hello world'),
    (Pattern: '^hello'; Input: 'say hello'),
    (Pattern: '^hello'; Input: ''),
    (Pattern: '^hello'; Input: 'h'),
    (Pattern: '^'; Input: ''),
    (Pattern: '^'; Input: 'abc'),
    { Patterns WITH assertions - $ }
    (Pattern: 'world$'; Input: 'hello world'),
    (Pattern: 'world$'; Input: 'world!'),
    (Pattern: 'world$'; Input: ''),
    (Pattern: '$'; Input: ''),
    (Pattern: '$'; Input: 'abc'),
    (Pattern: '$'; Input: 'x'),
    { Patterns WITH assertions - ^...$ }
    (Pattern: '^exact$'; Input: 'exact'),
    (Pattern: '^exact$'; Input: 'not exact'),
    (Pattern: '^exact$'; Input: ''),
    (Pattern: '^$'; Input: ''),
    (Pattern: '^$'; Input: 'a'),
    (Pattern: '^a+$'; Input: 'aaa'),
    (Pattern: '^a+$'; Input: 'aab'),
    (Pattern: '^a+$'; Input: ''),
    { Patterns WITH assertions - \b }
    (Pattern: '\bword\b'; Input: 'a word here'),
    (Pattern: '\bword\b'; Input: 'password'),
    (Pattern: '\bword\b'; Input: 'wordy'),
    (Pattern: '\bword\b'; Input: 'word'),
    (Pattern: '\bword\b'; Input: ''),
    (Pattern: '\bfoo\b'; Input: 'foo'),
    (Pattern: '\bfoo\b'; Input: 'foobar'),
    (Pattern: '\bfoo\b'; Input: 'barfoo'),
    { Patterns WITH assertions - \B }
    (Pattern: '\Boo\B'; Input: 'foobar'),
    (Pattern: '\Boo\B'; Input: 'oo'),
    (Pattern: '\Boo\B'; Input: 'foo'),
    (Pattern: '\Boo\B'; Input: ''),
    { Mixed assertions }
    (Pattern: '^\d+$'; Input: '12345'),
    (Pattern: '^\d+$'; Input: 'abc'),
    (Pattern: '\b\w+\b'; Input: 'hello world')
  );
var
  i: Integer;
  P: TRegexProgram;
  LDfa, LNfa: Boolean;
  LLabel: string;
begin
  for i := 0 to NUM_CASES - 1 do
  begin
    P := CompileProgram(Cases[i].Pattern);
    LDfa := DfaIsMatch(P, PAnsiChar(Cases[i].Input), Length(Cases[i].Input));
    LNfa := NfaIsMatch(P, PAnsiChar(Cases[i].Input), Length(Cases[i].Input));
    LLabel := 'xval[' + IntToStr(i) + '] /' + Cases[i].Pattern + '/ on "' + Cases[i].Input + '"';
    Check(LDfa = LNfa, LLabel);
  end;
end;

procedure TestDfaOverflowFallback;
var R: TRegex; M: TMatch; MA: TMatchArray;
    pat: string; i: Integer;
begin
  pat := '';
  for i := 1 to 9 do
    pat := pat + '(?:a|b)';
  R := TRegex.Compile(pat);
  Check(R.IsMatch('aaaaaaaaa'), 'overflow isMatch true');
  Check(R.IsMatch('ababababa'), 'overflow isMatch mixed');
  Check(not R.IsMatch('aaaaaaaac'), 'overflow isMatch false');
  M := R.Find('xxxaaaaaaaaa');
  Check(M.Found, 'overflow find');
  CheckEqual(Int64(9), Int64(M.Len), 'overflow find len');
  Check(R.IsFullMatch('ababababa'), 'overflow fullmatch true');
  Check(not R.IsFullMatch('abababab'), 'overflow fullmatch short');
  MA := R.FindAll('aaaaaaaaa bbbbbbbbb');
  Check(Length(MA) >= 2, 'overflow findall count');

  pat := '';
  for i := 1 to 50 do
  begin
    if i > 1 then pat := pat + '|';
    pat := pat + 'word' + IntToStr(i);
  end;
  R := TRegex.Compile(pat);
  Check(R.IsMatch('word25'), 'overflow alt isMatch');
  Check(not R.IsMatch('xyz'), 'overflow alt miss');
end;

procedure TestScanFindSubstring;
var
  LResult: PtrInt;
  LBigInput: string;
  LLongNeedle: string;
  i: Integer;
begin
  { Basic: find 'hello' in 'say hello world' }
  LResult := ScanFindSubstring(PAnsiChar('say hello world'), 15,
    PAnsiChar('hello'), 5);
  CheckEqual(Int64(4), Int64(LResult), 'basic find hello');

  { Not found: 'xyz' in 'abcdef' }
  LResult := ScanFindSubstring(PAnsiChar('abcdef'), 6,
    PAnsiChar('xyz'), 3);
  CheckEqual(Int64(-1), Int64(LResult), 'not found');

  { At start: 'abc' in 'abcdef' }
  LResult := ScanFindSubstring(PAnsiChar('abcdef'), 6,
    PAnsiChar('abc'), 3);
  CheckEqual(Int64(0), Int64(LResult), 'at start');

  { At middle: 'cd' in 'abcdef' }
  LResult := ScanFindSubstring(PAnsiChar('abcdef'), 6,
    PAnsiChar('cd'), 2);
  CheckEqual(Int64(2), Int64(LResult), 'at middle');

  { At end: 'def' in 'abcdef' }
  LResult := ScanFindSubstring(PAnsiChar('abcdef'), 6,
    PAnsiChar('def'), 3);
  CheckEqual(Int64(3), Int64(LResult), 'at end');

  { Single char at start }
  LResult := ScanFindSubstring(PAnsiChar('xbcdef'), 6,
    PAnsiChar('x'), 1);
  CheckEqual(Int64(0), Int64(LResult), 'single char start');

  { Single char at middle }
  LResult := ScanFindSubstring(PAnsiChar('abcxdef'), 7,
    PAnsiChar('x'), 1);
  CheckEqual(Int64(3), Int64(LResult), 'single char middle');

  { Single char at end }
  LResult := ScanFindSubstring(PAnsiChar('abcdex'), 6,
    PAnsiChar('x'), 1);
  CheckEqual(Int64(5), Int64(LResult), 'single char end');

  { Single char not found }
  LResult := ScanFindSubstring(PAnsiChar('abcdef'), 6,
    PAnsiChar('z'), 1);
  CheckEqual(Int64(-1), Int64(LResult), 'single char miss');

  { Empty needle: '' in 'abc' -> 0 }
  LResult := ScanFindSubstring(PAnsiChar('abc'), 3,
    PAnsiChar(''), 0);
  CheckEqual(Int64(0), Int64(LResult), 'empty needle');

  { Empty needle in empty haystack -> 0 }
  LResult := ScanFindSubstring(PAnsiChar(''), 0,
    PAnsiChar(''), 0);
  CheckEqual(Int64(0), Int64(LResult), 'empty needle empty haystack');

  { Needle longer than haystack }
  LResult := ScanFindSubstring(PAnsiChar('ab'), 2,
    PAnsiChar('abcdef'), 6);
  CheckEqual(Int64(-1), Int64(LResult), 'needle longer');

  { Exact match: needle = haystack }
  LResult := ScanFindSubstring(PAnsiChar('hello'), 5,
    PAnsiChar('hello'), 5);
  CheckEqual(Int64(0), Int64(LResult), 'exact match');

  { Repeated first byte: 'he' in 'hhhhe' (many false positives for 'h') }
  LResult := ScanFindSubstring(PAnsiChar('hhhhe'), 5,
    PAnsiChar('he'), 2);
  CheckEqual(Int64(3), Int64(LResult), 'repeated first byte');

  { Repeated first byte stress: 'ab' in 'aaaaaaaaab' }
  LResult := ScanFindSubstring(PAnsiChar('aaaaaaaaab'), 10,
    PAnsiChar('ab'), 2);
  CheckEqual(Int64(8), Int64(LResult), 'repeated first byte stress');

  { Two-byte filter stress: 'xy' in 'xaxbxcxdxy' }
  LResult := ScanFindSubstring(PAnsiChar('xaxbxcxdxy'), 10,
    PAnsiChar('xy'), 2);
  CheckEqual(Int64(8), Int64(LResult), 'two-byte filter stress');

  { Two-char needle where first=last }
  LResult := ScanFindSubstring(PAnsiChar('aabaa'), 5,
    PAnsiChar('aa'), 2);
  CheckEqual(Int64(0), Int64(LResult), 'two char same');

  { Many partial matches before real match: 'hel' 'hel' 'hel' then 'hello' }
  LResult := ScanFindSubstring(PAnsiChar('helhelhelhello'), 14,
    PAnsiChar('hello'), 5);
  CheckEqual(Int64(9), Int64(LResult), 'partial matches then real');

  { Long needle (20+ chars) }
  LResult := ScanFindSubstring(PAnsiChar('prefix_abcdefghijklmnopqrst_suffix'), 34,
    PAnsiChar('abcdefghijklmnopqrst'), 20);
  CheckEqual(Int64(7), Int64(LResult), 'long needle 20');

  { Very long needle (50+ chars) }
  SetLength(LLongNeedle, 55);
  for i := 1 to 55 do LLongNeedle[i] := Chr(Ord('A') + (i - 1) mod 26);
  SetLength(LBigInput, 200);
  for i := 1 to 200 do LBigInput[i] := 'z';
  Move(LLongNeedle[1], LBigInput[100], 55);
  LResult := ScanFindSubstring(PAnsiChar(LBigInput), 200,
    PAnsiChar(LLongNeedle), 55);
  CheckEqual(Int64(99), Int64(LResult), 'very long needle 55');

  { Very long needle not found }
  for i := 1 to 200 do LBigInput[i] := 'z';
  LResult := ScanFindSubstring(PAnsiChar(LBigInput), 200,
    PAnsiChar(LLongNeedle), 55);
  CheckEqual(Int64(-1), Int64(LResult), 'very long needle miss');

  { Large input (10KB) with needle near end }
  SetLength(LBigInput, 10000);
  for i := 1 to 10000 do LBigInput[i] := 'x';
  Move('hello'[1], LBigInput[9990], 5);
  LResult := ScanFindSubstring(PAnsiChar(LBigInput), 10000,
    PAnsiChar('hello'), 5);
  CheckEqual(Int64(9989), Int64(LResult), 'large input near end');

  { Needle at very start of large input }
  Move('hello'[1], LBigInput[1], 5);
  LResult := ScanFindSubstring(PAnsiChar(LBigInput), 10000,
    PAnsiChar('hello'), 5);
  CheckEqual(Int64(0), Int64(LResult), 'large input at start');

  { Needle at exact last position of large input }
  for i := 1 to 10000 do LBigInput[i] := 'x';
  Move('hello'[1], LBigInput[9996], 5);
  LResult := ScanFindSubstring(PAnsiChar(LBigInput), 10000,
    PAnsiChar('hello'), 5);
  CheckEqual(Int64(9995), Int64(LResult), 'large input at very end');

  { Haystack with many partial matches }
  for i := 1 to 10000 do LBigInput[i] := 'h';
  Move('hello'[1], LBigInput[9000], 5);
  LResult := ScanFindSubstring(PAnsiChar(LBigInput), 10000,
    PAnsiChar('hello'), 5);
  CheckEqual(Int64(8999), Int64(LResult), 'many partial h then hello');
end;

procedure TestFindAllMaxMatches;
var R: TRegex; LMatches: TMatchArray;
begin
  R := TRegex.Compile('\d+');
  LMatches := R.FindAll('a1b2c3d4e5', 3);
  CheckEqual(Int64(3), Int64(Length(LMatches)), 'limit=3 returns 3');
  CheckEqual(Int64(1), Int64(LMatches[0].Start), 'first match pos');
  CheckEqual(Int64(3), Int64(LMatches[1].Start), 'second match pos');
  CheckEqual(Int64(5), Int64(LMatches[2].Start), 'third match pos');
end;

procedure TestFindAllMaxMatchesZero;
var R: TRegex; LMatches: TMatchArray;
begin
  R := TRegex.Compile('\d+');
  LMatches := R.FindAll('a1b2c3', 0);
  CheckEqual(Int64(0), Int64(Length(LMatches)), 'limit=0 returns empty');
end;

procedure TestFindAllMaxMatchesNegative;
var R: TRegex; LMatches: TMatchArray;
begin
  R := TRegex.Compile('\d+');
  LMatches := R.FindAll('a1b2c3d4e5', -1);
  CheckEqual(Int64(5), Int64(Length(LMatches)), 'limit=-1 returns all');
end;

procedure TestFindAllMaxMatchesExceedsTotal;
var R: TRegex; LMatches: TMatchArray;
begin
  R := TRegex.Compile('x');
  LMatches := R.FindAll('axbxc', 100);
  CheckEqual(Int64(2), Int64(Length(LMatches)), 'limit>total returns all');
end;

{ --- Phase 4: Iterator + SubexpNames + Edge Cases --- }

procedure TestFindIter;
var R: TRegex; LIter: TRegexIter; LMatch: TMatch; LCount: Int32; LInput: string;
begin
  LInput := 'abc 123 def 456 ghi 789';
  R := TRegex.Compile('\d+');
  LIter := R.FindIter(LInput);
  LCount := 0;
  while LIter.Next(LMatch) do
  begin
    Inc(LCount);
    case LCount of
      1: Check(LMatch.Value(LInput) = '123', 'iter 1');
      2: Check(LMatch.Value(LInput) = '456', 'iter 2');
      3: Check(LMatch.Value(LInput) = '789', 'iter 3');
    end;
  end;
  CheckEqual(Int64(3), Int64(LCount), 'iter count');
end;

procedure TestFindIterEmpty;
var R: TRegex; LIter: TRegexIter; LMatch: TMatch;
begin
  R := TRegex.Compile('xyz');
  LIter := R.FindIter('no match here');
  Check(not LIter.Next(LMatch), 'iter empty no match');
end;

procedure TestFindIterZeroLen;
var R: TRegex; LIter: TRegexIter; LMatch: TMatch; LCount: Int32;
begin
  R := TRegex.Compile('\b');
  LIter := R.FindIter('ab cd');
  LCount := 0;
  while LIter.Next(LMatch) do
  begin
    Inc(LCount);
    if LCount > 20 then Break;
  end;
  Check(LCount > 0, 'zero-len produces matches');
  Check(LCount <= 20, 'zero-len terminates');
end;

procedure TestFindIterSingle;
var R: TRegex; LIter: TRegexIter; LMatch: TMatch; LCount: Int32;
begin
  R := TRegex.Compile('x');
  LIter := R.FindIter('x');
  LCount := 0;
  while LIter.Next(LMatch) do Inc(LCount);
  CheckEqual(Int64(1), Int64(LCount), 'single char single match');
end;

procedure TestFindIterKeepsProgramSnapshot;
var R: TRegex; LIter: TRegexIter; LMatch: TMatch; LInput: string;
begin
  LInput := 'a1';
  R := TRegex.Compile('\d+');
  LIter := R.FindIter(LInput);
  R := TRegex.Compile('[a-z]+');
  Check(LIter.Next(LMatch), 'iterator still finds original digit match');
  CheckEqual('1', LMatch.Value(LInput), 'iterator keeps original program');
  Check(not LIter.Next(LMatch), 'iterator has one original match');
end;

procedure TestSubexpNames;
var R: TRegex; LNames: TStringArray;
begin
  R := TRegex.Compile('(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})');
  LNames := R.SubexpNames;
  CheckEqual(Int64(3), Int64(Length(LNames)), 'name count');
  Check(LNames[0] = 'year', 'name 0');
  Check(LNames[1] = 'month', 'name 1');
  Check(LNames[2] = 'day', 'name 2');
end;

procedure TestSubexpNamesEmpty;
var R: TRegex; LNames: TStringArray;
begin
  R := TRegex.Compile('\d+');
  LNames := R.SubexpNames;
  CheckEqual(Int64(0), Int64(Length(LNames)), 'no named groups');
end;

procedure TestLongestMatch;
var R: TRegex; M: TMatch;
begin
  R := TRegex.Compile('a|ab|abc');
  M := R.Find('abcdef');
  CheckEqual(Int64(3), Int64(M.Len), 'alternation longest');

  R := TRegex.Compile('a+');
  M := R.Find('aaaa');
  CheckEqual(Int64(4), Int64(M.Len), 'greedy longest');
end;

procedure TestReplaceEdgeCasesP4;
var R: TRegex; LResult: string;
begin
  R := TRegex.Compile('x');
  LResult := R.ReplaceAll('', 'y');
  Check(LResult = '', 'replace empty input');

  LResult := R.ReplaceAll('abc', 'y');
  Check(LResult = 'abc', 'replace no match');

  R := TRegex.Compile('.');
  LResult := R.ReplaceFirst('abc', '');
  Check(LResult = 'bc', 'replace with empty string');
end;

procedure TestSplitEdgeCases2;
var R: TRegex; LParts: TStringArray;
begin
  R := TRegex.Compile(',');
  LParts := R.Split('');
  CheckEqual(Int64(1), Int64(Length(LParts)), 'split empty = 1 part');

  LParts := R.Split(',a,b,');
  Check(Length(LParts) >= 3, 'split leading/trailing sep');

  LParts := R.Split('abc', 1);
  CheckEqual(Int64(1), Int64(Length(LParts)), 'split limit=1');
  Check(LParts[0] = 'abc', 'split limit=1 value');
end;

procedure TestLargeInput;
var R: TRegex; LBig: string; M: TMatch; LI: Integer;
begin
  SetLength(LBig, 100000);
  for LI := 1 to 100000 do LBig[LI] := 'a';
  Move('needle'[1], LBig[99990], 6);
  R := TRegex.Compile('needle');
  M := R.Find(LBig);
  Check(M.Found, 'large input found');
  CheckEqual(Int64(99989), Int64(M.Start), 'large input position');
end;

procedure TestUnicodeBasic;
var R: TRegex; M: TMatch;
begin
  R := TRegex.Compile('...');
  M := R.Find('abc');
  Check(M.Found and (M.Len = 3), 'dot matches ascii');
end;

procedure TestErrorPatterns;
var R: TRegex; LErr: string; LOk: Boolean;
begin
  LOk := TRegex.TryCompile('[', R, LErr);
  Check(not LOk, 'unclosed bracket rejected');
  Check(Length(LErr) > 0, 'error message present');

  LOk := TRegex.TryCompile('*', R, LErr);
  Check(not LOk, 'leading quantifier rejected');

  LOk := TRegex.TryCompile('(?P<name>\d+)', R, LErr);
  Check(LOk, 'valid named group accepted');
end;

procedure TestIterConsistencyWithFindAll;
var R: TRegex; LIter: TRegexIter; LMatch: TMatch;
    LMatches: TMatchArray; LCount, LI: Int32; LInput: string;
begin
  LInput := 'the quick brown fox jumps over the lazy dog';
  R := TRegex.Compile('\w+');
  LMatches := R.FindAll(LInput);
  LIter := R.FindIter(LInput);
  LCount := 0;
  while LIter.Next(LMatch) do
  begin
    if LCount < Length(LMatches) then
    begin
      CheckEqual(Int64(LMatches[LCount].Start), Int64(LMatch.Start), 'iter/findall start ' + IntToStr(LCount));
      CheckEqual(Int64(LMatches[LCount].Len), Int64(LMatch.Len), 'iter/findall len ' + IntToStr(LCount));
    end;
    Inc(LCount);
  end;
  CheckEqual(Int64(Length(LMatches)), Int64(LCount), 'iter/findall count match');
end;

begin
  T := TTestRunner.Create('nextpas.core.regex');
  T.Run('Literal', @TestLiteral);
  T.Run('Dot', @TestDot);
  T.Run('Star', @TestStar);
  T.Run('Plus', @TestPlus);
  T.Run('Question', @TestQuestion);
  T.Run('Alternation', @TestAlternation);
  T.Run('CharClass', @TestCharClass);
  T.Run('Shorthand (\d \w \s)', @TestShorthand);
  T.Run('Anchors (^ $)', @TestAnchors);
  T.Run('Find', @TestFind);
  T.Run('FindAll', @TestFindAll);
  T.Run('Replace', @TestReplace);
  T.Run('Split', @TestSplit);
  T.Run('Repetition {n,m}', @TestRepetition);
  T.Run('TryCompile', @TestTryCompile);
  T.Run('Convenience functions', @TestConvenience);
  T.Run('No exponential blowup', @TestNoExponentialBlowup);
  T.Run('Capture groups', @TestCaptureGroups);
  T.Run('Word boundary (\b)', @TestWordBoundary);
  T.Run('Non-capturing group', @TestNonCapturingGroup);
  T.Run('Edge cases', @TestEdgeCases);
  T.Run('Escapes', @TestEscapes);
  T.Run('StartClass prefilter', @TestStartClassPrefilter);
  T.Run('Named groups', @TestNamedGroups);
  T.Run('Negated shorthand (\D \W \S)', @TestNegatedShorthand);
  T.Run('FindAt', @TestFindAt);
  T.Run('IsFullMatch', @TestIsFullMatch);
  T.Run('QuoteMeta', @TestQuoteMeta);
  T.Run('Split with limit', @TestSplitLimit);
  T.Run('ReplaceFunc', @TestReplaceFunc);
  T.Run('ReplaceExpand', @TestReplaceExpand);
  T.Run('Zero repeat {0}', @TestZeroRepeat);
  T.Run('Alternation priority', @TestAlternationPriority);
  T.Run('Split zero', @TestSplitZero);
  T.Run('Malformed template', @TestMalformedTemplate);
  T.Run('FindAt boundary', @TestFindAtBoundary);
  T.Run('Large repeat {100}', @TestLargeRepeat);
  T.Run('Memory stress', @TestMemoryStress);
  T.Run('Compile limits', @TestCompileLimits);
  T.Run('Malformed patterns', @TestMalformedPatterns);
  T.Run('Case insensitive', @TestCaseInsensitive);
  T.Run('Regex flags public contract', @TestRegexFlagsPublicContract);
  { --- New comprehensive tests --- }
  T.Run('Greedy vs Non-Greedy', @TestGreedyVsNonGreedy);
  T.Run('Capture edge cases', @TestCaptureEdgeCases);
  T.Run('FindAll edge cases', @TestFindAllEdgeCases);
  T.Run('Split edge cases', @TestSplitEdgeCases);
  T.Run('Char class edge cases', @TestCharClassEdgeCases);
  T.Run('Anchor edge cases', @TestAnchorEdgeCases);
  T.Run('Escape edge cases', @TestEscapeEdgeCases);
  T.Run('IsFullMatch edge cases', @TestIsFullMatchEdgeCases);
  T.Run('Case insensitive edge cases', @TestCaseInsensitiveEdgeCases);
  T.Run('Performance regression', @TestPerformanceRegression);
  T.Run('QuoteMeta thorough', @TestQuoteMetaThorough);
  T.Run('ReplaceFunc edge cases', @TestReplaceFuncEdgeCases);
  T.Run('ReplaceFunc nil callback', @TestReplaceFuncNilCallback);
  { --- 13 new test areas --- }
  T.Run('Multiple captures', @TestMultipleCaptures);
  T.Run('Overlapping patterns', @TestOverlappingPatterns);
  T.Run('Special inputs', @TestSpecialInputs);
  T.Run('Quantifier boundaries', @TestQuantifierBoundaries);
  T.Run('Complex patterns', @TestComplexPatterns);
  T.Run('FindAll progress', @TestFindAllProgress);
  T.Run('ReplaceAllExpand advanced', @TestReplaceAllExpandAdvanced);
  T.Run('Split advanced', @TestSplitAdvanced);
  T.Run('Case insensitive advanced', @TestCaseInsensitiveAdvanced);
  T.Run('Backtracking immunity', @TestBacktrackingImmunity);
  T.Run('GroupByName advanced', @TestGroupByNameAdvanced);
  T.Run('IsMatch vs Find', @TestIsMatchVsFind);
  T.Run('Compile reuse', @TestCompileReuse);
  { --- 13 semantic conformance tests --- }
  T.Run('Find positions', @TestFindPositions);
  T.Run('FindAll positions', @TestFindAllPositions);
  T.Run('Capture positions', @TestCapturePositions);
  T.Run('Replace positional', @TestReplacePositional);
  T.Run('Split positional', @TestSplitPositional);
  T.Run('Long patterns', @TestLongPatterns);
  T.Run('Empty match behavior', @TestEmptyMatchBehavior);
  T.Run('Word boundary detailed', @TestWordBoundaryDetailed);
  T.Run('Quantifier interaction', @TestQuantifierInteraction);
  T.Run('Anchored search', @TestAnchoredSearch);
  T.Run('Dot behavior', @TestDotBehavior);
  T.Run('Char class ranges', @TestCharClassRanges);
  T.Run('Regex reuse', @TestRegexReuse);
  { --- 13 adversarial stress tests --- }
  T.Run('ADV: Adversarial patterns', @TestAdversarialPatterns);
  T.Run('ADV: Binary input', @TestBinaryInput);
  T.Run('ADV: Repeated compile', @TestRepeatedCompile);
  T.Run('ADV: Maximal input', @TestMaximalInput);
  T.Run('ADV: TryCompile errors', @TestTryCompileErrors);
  T.Run('ADV: FindAll consistency', @TestFindAllConsistency);
  T.Run('ADV: ReplaceExpand consistency', @TestReplaceExpandConsistency);
  T.Run('ADV: Pattern syntax coverage', @TestPatternSyntaxCoverage);
  T.Run('ADV: IsFullMatch thorough', @TestIsFullMatchThorough);
  T.Run('ADV: Group interaction with replace', @TestGroupInteractionWithReplace);
  T.Run('ADV: Case insensitive with captures', @TestCaseInsensitiveWithCaptures);
  T.Run('ADV: QuoteMeta round trip', @TestQuoteMetaRoundTrip);
  T.Run('ADV: Memory leak on error', @TestMemoryLeakOnError);
  { --- 13 encoding correctness tests --- }
  T.Run('ENC: UTF-8 bytes', @TestUTF8Bytes);
  T.Run('ENC: Latin-1 bytes', @TestLatin1Bytes);
  T.Run('ENC: Control chars', @TestControlChars);
  T.Run('ENC: Byte exactness', @TestByteExactness);
  T.Run('ENC: Word boundary with encoding', @TestWordBoundaryWithEncoding);
  T.Run('ENC: Char class with high bytes', @TestCharClassWithHighBytes);
  T.Run('ENC: Newline handling', @TestNewlineHandling);
  T.Run('ENC: Mixed encoding input', @TestMixedEncodingInput);
  T.Run('ENC: Pattern with high bytes', @TestPatternWithHighBytes);
  T.Run('ENC: Off-by-one positions', @TestOffByOnePositions);
  T.Run('ENC: Case folding boundary', @TestCaseFoldingBoundary);
  T.Run('ENC: Shorthand with encoding', @TestShorthandWithEncoding);
  T.Run('ENC: Value extraction', @TestValueExtraction);
  { --- DFA v2 assertion correctness tests --- }
  T.Run('DFA: Assertion correctness', @TestDfaAssertionCorrectness);
  T.Run('DFA: FindAll correctness', @TestDfaFindAllCorrectness);
  T.Run('DFA: NFA cross-validation', @TestDfaNfaCrossValidation);
  T.Run('DFA: Overflow fallback', @TestDfaOverflowFallback);
  { --- ScanFindSubstring tests --- }
  T.Run('ScanFindSubstring', @TestScanFindSubstring);
  { --- FindAll AMaxMatches tests --- }
  T.Run('FindAll MaxMatches', @TestFindAllMaxMatches);
  T.Run('FindAll MaxMatches=0', @TestFindAllMaxMatchesZero);
  T.Run('FindAll MaxMatches=-1', @TestFindAllMaxMatchesNegative);
  T.Run('FindAll MaxMatches>total', @TestFindAllMaxMatchesExceedsTotal);
  { --- Phase 4 API + Edge Cases --- }
  T.Run('P4: FindIter', @TestFindIter);
  T.Run('P4: FindIter empty', @TestFindIterEmpty);
  T.Run('P4: FindIter zero-len', @TestFindIterZeroLen);
  T.Run('P4: FindIter single', @TestFindIterSingle);
  T.Run('P4: FindIter program snapshot', @TestFindIterKeepsProgramSnapshot);
  T.Run('P4: SubexpNames', @TestSubexpNames);
  T.Run('P4: SubexpNames empty', @TestSubexpNamesEmpty);
  T.Run('P4: Longest match', @TestLongestMatch);
  T.Run('P4: Replace edge cases', @TestReplaceEdgeCasesP4);
  T.Run('P4: Split edge cases', @TestSplitEdgeCases2);
  T.Run('P4: Large input 100KB', @TestLargeInput);
  T.Run('P4: Unicode basic', @TestUnicodeBasic);
  T.Run('P4: Error patterns', @TestErrorPatterns);
  T.Run('P4: Iter/FindAll consistency', @TestIterConsistencyWithFindAll);
  T.Summary;
end.
