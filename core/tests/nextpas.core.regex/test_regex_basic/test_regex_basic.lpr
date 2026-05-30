program test_regex_basic;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.regex;

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
  T.Summary;
end.
