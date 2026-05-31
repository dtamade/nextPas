program test_regex_basic;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.regex,
  nextpas.core.regex.base;

var
  T: TTestRunner;

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

procedure TestMalformedTemplate;
var R: TRegex; s: string;
begin
  R := TRegex.Compile('(\w+)');

  // $ at end of template
  s := R.ReplaceAllExpand('hello', 'x$');
  CheckEqual('x$', s, '$ at end preserved');

  // ${ without }
  s := R.ReplaceAllExpand('hello', '${broken');
  CheckEqual('${broken', s, '${ without } preserved');

  // ${} empty name
  s := R.ReplaceAllExpand('hello', '${}');
  CheckEqual('', s, '${} empty name');

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

  // Unclosed quantifier
  Check(not TRegex.TryCompile('a{', R, err), 'unclosed quantifier');
  Check(Pos('unclosed quantifier', err) > 0, 'unclosed quantifier msg');

  Check(not TRegex.TryCompile('a{3', R, err), 'unclosed quantifier no }');
  Check(Pos('unclosed quantifier', err) > 0, 'unclosed quantifier no } msg');

  // min > max in quantifier
  Check(not TRegex.TryCompile('a{3,2}', R, err), 'min > max');
  Check(Pos('min exceeds max', err) > 0, 'min > max msg');

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
  T.Summary;
end.
