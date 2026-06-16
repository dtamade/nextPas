unit nextpasstrutils_tests;

interface

uses
  nextpastest;

procedure TestLowerCase;
procedure TestUpperCase;
procedure TestTrim;
procedure TestTrimLeft;
procedure TestTrimRight;
procedure TestPos;
procedure TestStringReplace;
procedure TestContains;
procedure TestStartsWith;
procedure TestEndsWith;
procedure TestSplit;
procedure TestJoin;
procedure TestCompareText;
procedure TestSameText;
procedure TestPadLeft;
procedure TestPadRight;

implementation

uses
  nextpasstrutils;

procedure TestLowerCase;
begin
  AssertEquals('LowerCase(HELLO)', 'hello', LowerCase('HELLO'));
  AssertEquals('LowerCase(Hello)', 'hello', LowerCase('Hello'));
  AssertEquals('LowerCase(hello)', 'hello', LowerCase('hello'));
  AssertEquals('LowerCase(123)', '123', LowerCase('123'));
  AssertEquals('LowerCase(empty)', '', LowerCase(''));
end;

procedure TestUpperCase;
begin
  AssertEquals('UpperCase(hello)', 'HELLO', UpperCase('hello'));
  AssertEquals('UpperCase(Hello)', 'HELLO', UpperCase('Hello'));
  AssertEquals('UpperCase(HELLO)', 'HELLO', UpperCase('HELLO'));
  AssertEquals('UpperCase(123)', '123', UpperCase('123'));
  AssertEquals('UpperCase(empty)', '', UpperCase(''));
end;

procedure TestTrim;
begin
  AssertEquals('Trim(  hello  )', 'hello', Trim('  hello  '));
  AssertEquals('Trim(hello)', 'hello', Trim('hello'));
  AssertEquals('Trim(  )', '', Trim('   '));
  AssertEquals('Trim(empty)', '', Trim(''));
  AssertEquals('Trim(tabs)', 'hello', Trim(#9'hello'#9));
end;

procedure TestTrimLeft;
begin
  AssertEquals('TrimLeft(  hello)', 'hello', TrimLeft('  hello'));
  AssertEquals('TrimLeft(hello)', 'hello', TrimLeft('hello'));
end;

procedure TestTrimRight;
begin
  AssertEquals('TrimRight(hello  )', 'hello', TrimRight('hello  '));
  AssertEquals('TrimRight(hello)', 'hello', TrimRight('hello'));
end;

procedure TestPos;
begin
  AssertEquals('Pos(ll,hello)', 3, Pos('ll', 'hello'));
  AssertEquals('Pos(he,hello)', 1, Pos('he', 'hello'));
  AssertEquals('Pos(xx,hello)', 0, Pos('xx', 'hello'));
  AssertEquals('Pos(empty,hello)', 1, Pos('', 'hello'));
  AssertEquals('Pos(long,hi)', 0, Pos('hello', 'hi'));
end;

procedure TestStringReplace;
begin
  // single replace
  AssertEquals('Replace(ll,xx) once', 'hexxo', StringReplace('hello', 'll', 'xx', []));
  // replace all
  AssertEquals('Replace(l,x) all', 'hexxo', StringReplace('hello', 'l', 'x', [rfReplaceAll]));
  // case insensitive
  AssertEquals('Replace(HE,xx) ignore case', 'xxxxllo', StringReplace('HElloHEllo', 'he', 'xx', [rfReplaceAll, rfIgnoreCase]));
  // no match
  AssertEquals('Replace no match', 'hello', StringReplace('hello', 'zz', 'xx', [rfReplaceAll]));
  // empty pattern
  AssertEquals('Replace empty pattern', 'hello', StringReplace('hello', '', 'xx', []));
end;

procedure TestContains;
begin
  AssertTrue('Contains(ll,hello)', Contains('hello', 'll'));
  AssertTrue('Contains(he,hello)', Contains('hello', 'he'));
  AssertTrue('Contains(xx,hello)', not Contains('hello', 'xx'));
  AssertTrue('Contains(empty,hello)', Contains('hello', ''));
end;

procedure TestStartsWith;
begin
  AssertTrue('StartsWith(hel,hello)', StartsWith('hello', 'hel'));
  AssertTrue('StartsWith(hello,hello)', StartsWith('hello', 'hello'));
  AssertTrue('StartsWith(xxx,hello)', not StartsWith('hello', 'xxx'));
  AssertTrue('StartsWith(long,hi)', not StartsWith('hi', 'hello'));
end;

procedure TestEndsWith;
begin
  AssertTrue('EndsWith(llo,hello)', EndsWith('hello', 'llo'));
  AssertTrue('EndsWith(hello,hello)', EndsWith('hello', 'hello'));
  AssertTrue('EndsWith(xxx,hello)', not EndsWith('hello', 'xxx'));
  AssertTrue('EndsWith(long,hi)', not EndsWith('hi', 'hello'));
end;

procedure TestSplit;
var
  parts: array of String;
begin
  parts := Split('a,b,c', ',');
  AssertEquals('Split count', 3, Length(parts));
  AssertEquals('Split[0]', 'a', parts[0]);
  AssertEquals('Split[1]', 'b', parts[1]);
  AssertEquals('Split[2]', 'c', parts[2]);
  // single element
  parts := Split('hello', ',');
  AssertEquals('Split single', 1, Length(parts));
  AssertEquals('Split single[0]', 'hello', parts[0]);
  // empty string
  parts := Split('', ',');
  AssertEquals('Split empty', 0, Length(parts));
end;

procedure TestJoin;
var
  parts: array of String;
begin
  SetLength(parts, 3);
  parts[0] := 'a';
  parts[1] := 'b';
  parts[2] := 'c';
  AssertEquals('Join(,)', 'a,b,c', Join(parts, ','));
  AssertEquals('Join(-)', 'a-b-c', Join(parts, '-'));
  // empty array
  SetLength(parts, 0);
  AssertEquals('Join empty', '', Join(parts, ','));
end;

procedure TestCompareText;
begin
  AssertEquals('CompareText(same)', 0, CompareText('hello', 'HELLO'));
  AssertEquals('CompareText(diff)', 0, CompareText('abc', 'ABC'));
  AssertTrue('CompareText(less)', CompareText('abc', 'xyz') < 0);
  AssertTrue('CompareText(greater)', CompareText('xyz', 'abc') > 0);
end;

procedure TestSameText;
begin
  AssertTrue('SameText(same)', SameText('hello', 'HELLO'));
  AssertTrue('SameText(diff)', not SameText('hello', 'world'));
end;

procedure TestPadLeft;
begin
  AssertEquals('PadLeft(hi,5,-)', '---hi', PadLeft('hi', 5, '-'));
  AssertEquals('PadLeft(hello,3,-)', 'hello', PadLeft('hello', 3, '-'));
end;

procedure TestPadRight;
begin
  AssertEquals('PadRight(hi,5,-)', 'hi---', PadRight('hi', 5, '-'));
  AssertEquals('PadRight(hello,3,-)', 'hello', PadRight('hello', 3, '-'));
end;

procedure RegisterTests;
begin
  RegisterTest(@TestLowerCase, 'TestLowerCase');
  RegisterTest(@TestUpperCase, 'TestUpperCase');
  RegisterTest(@TestTrim, 'TestTrim');
  RegisterTest(@TestTrimLeft, 'TestTrimLeft');
  RegisterTest(@TestTrimRight, 'TestTrimRight');
  RegisterTest(@TestPos, 'TestPos');
  RegisterTest(@TestStringReplace, 'TestStringReplace');
  RegisterTest(@TestContains, 'TestContains');
  RegisterTest(@TestStartsWith, 'TestStartsWith');
  RegisterTest(@TestEndsWith, 'TestEndsWith');
  RegisterTest(@TestSplit, 'TestSplit');
  RegisterTest(@TestJoin, 'TestJoin');
  RegisterTest(@TestCompareText, 'TestCompareText');
  RegisterTest(@TestSameText, 'TestSameText');
  RegisterTest(@TestPadLeft, 'TestPadLeft');
  RegisterTest(@TestPadRight, 'TestPadRight');
end;

initialization
  RegisterTests;

end.
