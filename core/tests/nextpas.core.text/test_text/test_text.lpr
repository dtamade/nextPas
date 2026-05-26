program test_text;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.text;

var
  T: TTestRunner;

procedure TestTrim;
begin
  CheckEqual('hello', TextTrim('  hello  '), 'both sides');
  CheckEqual('hello', TextTrim('hello'), 'no whitespace');
  CheckEqual('', TextTrim('   '), 'all whitespace');
  CheckEqual('', TextTrim(''), 'empty');
end;

procedure TestTrimLeft;
begin
  CheckEqual('hello  ', TextTrimLeft('  hello  '), 'left only');
  CheckEqual('', TextTrimLeft(''), 'empty');
end;

procedure TestTrimRight;
begin
  CheckEqual('  hello', TextTrimRight('  hello  '), 'right only');
  CheckEqual('', TextTrimRight(''), 'empty');
end;

procedure TestStartsWith;
begin
  Check(TextStartsWith('hello world', 'hello'), 'prefix match');
  Check(not TextStartsWith('hello world', 'world'), 'no prefix');
  Check(TextStartsWith('hello', ''), 'empty prefix');
  Check(not TextStartsWith('', 'x'), 'empty value');
end;

procedure TestEndsWith;
begin
  Check(TextEndsWith('hello world', 'world'), 'suffix match');
  Check(not TextEndsWith('hello world', 'hello'), 'no suffix');
  Check(TextEndsWith('hello', ''), 'empty suffix');
end;

procedure TestContains;
begin
  Check(TextContains('hello world', 'lo wo'), 'substring');
  Check(not TextContains('hello', 'xyz'), 'not found');
  Check(TextContains('hello', ''), 'empty substr');
end;

procedure TestSplit;
var
  LParts: TStringArray;
begin
  LParts := TextSplit('a,b,c', ',');
  CheckEqual(Int64(3), Int64(Length(LParts)), 'count');
  CheckEqual('a', LParts[0], 'part 0');
  CheckEqual('b', LParts[1], 'part 1');
  CheckEqual('c', LParts[2], 'part 2');

  LParts := TextSplit('hello', ',');
  CheckEqual(Int64(1), Int64(Length(LParts)), 'no delimiter');
  CheckEqual('hello', LParts[0], 'whole string');

  LParts := TextSplit('a::b::c', '::');
  CheckEqual(Int64(3), Int64(Length(LParts)), 'multi-char delim');
  CheckEqual('b', LParts[1], 'multi-char part');

  LParts := TextSplit(',a,', ',');
  CheckEqual(Int64(3), Int64(Length(LParts)), 'leading/trailing delim');
  CheckEqual('', LParts[0], 'empty first');
  CheckEqual('', LParts[2], 'empty last');
end;

procedure TestJoin;
var
  LParts: TStringArray;
begin
  SetLength(LParts, 3);
  LParts[0] := 'a';
  LParts[1] := 'b';
  LParts[2] := 'c';
  CheckEqual('a,b,c', TextJoin(LParts, ','), 'basic join');
  CheckEqual('a--b--c', TextJoin(LParts, '--'), 'multi-char sep');

  SetLength(LParts, 0);
  CheckEqual('', TextJoin(LParts, ','), 'empty array');
end;

procedure TestReplace;
begin
  CheckEqual('hXllo', TextReplace('hello', 'e', 'X'), 'first only');
  CheckEqual('hello', TextReplace('hello', 'z', 'X'), 'not found');
  CheckEqual('hello', TextReplace('hello', '', 'X'), 'empty old');
end;

procedure TestReplaceAll;
begin
  CheckEqual('hXllo', TextReplaceAll('hello', 'e', 'X'), 'single match');
  CheckEqual('XbXbX', TextReplaceAll('ababa', 'a', 'X'), 'multiple');
  CheckEqual('hello', TextReplaceAll('hello', 'z', 'X'), 'not found');
  CheckEqual('hllo', TextReplaceAll('hello', 'e', ''), 'replace with empty');
end;

procedure TestToUpper;
begin
  CheckEqual('HELLO', TextToUpper('hello'), 'lower to upper');
  CheckEqual('HELLO123', TextToUpper('Hello123'), 'mixed');
  CheckEqual('', TextToUpper(''), 'empty');
end;

procedure TestToLower;
begin
  CheckEqual('hello', TextToLower('HELLO'), 'upper to lower');
  CheckEqual('hello123', TextToLower('Hello123'), 'mixed');
  CheckEqual('', TextToLower(''), 'empty');
end;

procedure TestPadLeft;
begin
  CheckEqual('   hi', TextPadLeft('hi', 5), 'pad spaces');
  CheckEqual('000hi', TextPadLeft('hi', 5, '0'), 'pad zeros');
  CheckEqual('hello', TextPadLeft('hello', 3), 'no pad needed');
end;

procedure TestPadRight;
begin
  CheckEqual('hi   ', TextPadRight('hi', 5), 'pad spaces');
  CheckEqual('hi000', TextPadRight('hi', 5, '0'), 'pad zeros');
  CheckEqual('hello', TextPadRight('hello', 3), 'no pad needed');
end;

procedure TestRepeat;
begin
  CheckEqual('abcabcabc', TextRepeat('abc', 3), 'repeat 3');
  CheckEqual('', TextRepeat('abc', 0), 'repeat 0');
  CheckEqual('x', TextRepeat('x', 1), 'repeat 1');
end;

procedure TestIndexOf;
begin
  CheckEqual(Int64(0), Int64(TextIndexOf('hello', 'h')), 'first char');
  CheckEqual(Int64(4), Int64(TextIndexOf('hello', 'o')), 'last char');
  CheckEqual(Int64(-1), Int64(TextIndexOf('hello', 'z')), 'not found');
  CheckEqual(Int64(2), Int64(TextIndexOf('hello', 'llo')), 'substring');
end;

procedure TestLastIndexOf;
begin
  CheckEqual(Int64(3), Int64(TextLastIndexOf('abcabc', 'abc')), 'last occurrence');
  CheckEqual(Int64(0), Int64(TextLastIndexOf('abcdef', 'abc')), 'only occurrence');
  CheckEqual(Int64(-1), Int64(TextLastIndexOf('hello', 'xyz')), 'not found');
end;

procedure TestIsEmpty;
begin
  Check(TextIsEmpty(''), 'empty');
  Check(not TextIsEmpty(' '), 'space not empty');
  Check(not TextIsEmpty('x'), 'char not empty');
end;

procedure TestIsBlank;
begin
  Check(TextIsBlank(''), 'empty is blank');
  Check(TextIsBlank('   '), 'spaces are blank');
  Check(TextIsBlank(#9#10#13), 'whitespace is blank');
  Check(not TextIsBlank(' x '), 'has content');
end;

procedure TestUTF8Length;
begin
  CheckEqual(Int64(5), Int64(TextUTF8Length('hello')), 'ASCII');
  CheckEqual(Int64(2), Int64(TextUTF8Length(#$C3#$A9#$C3#$A8)), '2-byte chars');
  CheckEqual(Int64(1), Int64(TextUTF8Length(#$E4#$B8#$AD)), '3-byte CJK');
  CheckEqual(Int64(1), Int64(TextUTF8Length(#$F0#$9F#$98#$80)), '4-byte emoji');
  CheckEqual(Int64(0), Int64(TextUTF8Length('')), 'empty');
end;

procedure TestUTF8CodePointAt;
begin
  CheckEqual(Int64(Ord('h')), Int64(TextUTF8CodePointAt('hello', 0)), 'ASCII index 0');
  CheckEqual(Int64(Ord('o')), Int64(TextUTF8CodePointAt('hello', 4)), 'ASCII index 4');
  CheckEqual(Int64($4E2D), Int64(TextUTF8CodePointAt(#$E4#$B8#$AD, 0)), 'CJK U+4E2D');
  CheckEqual(Int64($1F600), Int64(TextUTF8CodePointAt(#$F0#$9F#$98#$80, 0)), 'emoji U+1F600');
end;

begin
  T := TTestRunner.Create('nextpas.core.text');
  T.Run('Trim', @TestTrim);
  T.Run('TrimLeft', @TestTrimLeft);
  T.Run('TrimRight', @TestTrimRight);
  T.Run('StartsWith', @TestStartsWith);
  T.Run('EndsWith', @TestEndsWith);
  T.Run('Contains', @TestContains);
  T.Run('Split', @TestSplit);
  T.Run('Join', @TestJoin);
  T.Run('Replace', @TestReplace);
  T.Run('ReplaceAll', @TestReplaceAll);
  T.Run('ToUpper', @TestToUpper);
  T.Run('ToLower', @TestToLower);
  T.Run('PadLeft', @TestPadLeft);
  T.Run('PadRight', @TestPadRight);
  T.Run('Repeat', @TestRepeat);
  T.Run('IndexOf', @TestIndexOf);
  T.Run('LastIndexOf', @TestLastIndexOf);
  T.Run('IsEmpty', @TestIsEmpty);
  T.Run('IsBlank', @TestIsBlank);
  T.Run('UTF8Length', @TestUTF8Length);
  T.Run('UTF8CodePointAt', @TestUTF8CodePointAt);
  T.Summary;
end.
