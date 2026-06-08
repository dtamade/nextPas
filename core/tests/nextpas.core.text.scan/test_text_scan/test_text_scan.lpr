program test_text_scan;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.scan,
  nextpas.core.text.view,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestFindByte2;
begin
  CheckEqual(Int64(3), Int64(ScanFindByte2(PAnsiChar('abc:def'), 7, Ord(':'), Ord(';'))), 'colon at 3');
  CheckEqual(Int64(0), Int64(ScanFindByte2(PAnsiChar(':abc'), 4, Ord(':'), Ord(';'))), 'colon at 0');
  CheckEqual(Int64(-1), Int64(ScanFindByte2(PAnsiChar('abcdef'), 6, Ord(':'), Ord(';'))), 'not found');
  CheckEqual(Int64(4), Int64(ScanFindByte2(PAnsiChar('abcd;f'), 6, Ord(':'), Ord(';'))), 'semicolon at 4');
end;

procedure TestFindByte3;
begin
  CheckEqual(Int64(2), Int64(ScanFindByte3(PAnsiChar('ab{cd'), 5, Ord('{'), Ord('}'), Ord('['))), '{ at 2');
  CheckEqual(Int64(3), Int64(ScanFindByte3(PAnsiChar('abc}d'), 5, Ord('{'), Ord('}'), Ord('['))), '} at 3');
  CheckEqual(Int64(-1), Int64(ScanFindByte3(PAnsiChar('abcde'), 5, Ord('{'), Ord('}'), Ord('['))), 'not found');
end;

procedure TestFindInRange;
begin
  CheckEqual(Int64(3), Int64(ScanFindInRange(PAnsiChar('abc5def'), 7, Ord('0'), Ord('9'))), 'digit at 3');
  CheckEqual(Int64(0), Int64(ScanFindInRange(PAnsiChar('9abc'), 4, Ord('0'), Ord('9'))), 'digit at 0');
  CheckEqual(Int64(-1), Int64(ScanFindInRange(PAnsiChar('abcdef'), 6, Ord('0'), Ord('9'))), 'no digit');
end;

procedure TestFindNotInRange;
begin
  CheckEqual(Int64(3), Int64(ScanFindNotInRange(PAnsiChar('123abc'), 6, Ord('0'), Ord('9'))), 'non-digit at 3');
  CheckEqual(Int64(0), Int64(ScanFindNotInRange(PAnsiChar('abc123'), 6, Ord('0'), Ord('9'))), 'non-digit at 0');
  CheckEqual(Int64(-1), Int64(ScanFindNotInRange(PAnsiChar('12345'), 5, Ord('0'), Ord('9'))), 'all digits');
end;

procedure TestSkipWhitespace;
begin
  CheckEqual(Int64(3), Int64(ScanSkipWhitespace(PAnsiChar('   abc'), 6)), 'spaces');
  CheckEqual(Int64(4), Int64(ScanSkipWhitespace(PAnsiChar(#9#10#13' x'), 5)), 'mixed ws');
  CheckEqual(Int64(0), Int64(ScanSkipWhitespace(PAnsiChar('abc'), 3)), 'no ws');
  CheckEqual(Int64(5), Int64(ScanSkipWhitespace(PAnsiChar('     '), 5)), 'all ws');
end;

procedure TestSkipWhitespaceLong;
var
  Buf: array[0..63] of AnsiChar;
begin
  FillChar(Buf, 64, Ord(' '));
  Buf[32] := 'x';
  CheckEqual(Int64(32), Int64(ScanSkipWhitespace(@Buf[0], 64)), '32 spaces then x');
  FillChar(Buf, 64, Ord(' '));
  CheckEqual(Int64(64), Int64(ScanSkipWhitespace(@Buf[0], 64)), 'all 64 spaces');
end;

procedure TestSkipWhitespaceRejectsControlBytes;
var
  Buf: array[0..63] of AnsiChar;
begin
  FillChar(Buf, 64, Ord(' '));
  Buf[20] := #0;
  Buf[21] := 'x';
  CheckEqual(Int64(20), Int64(ScanSkipWhitespace(@Buf[0], 64)), 'NUL is not whitespace');

  FillChar(Buf, 64, Ord(' '));
  Buf[24] := #1;
  Buf[25] := 'x';
  CheckEqual(Int64(24), Int64(ScanSkipWhitespace(@Buf[0], 64)), 'SOH is not whitespace');

  FillChar(Buf, 64, Ord(' '));
  Buf[28] := #11;
  Buf[29] := 'x';
  CheckEqual(Int64(28), Int64(ScanSkipWhitespace(@Buf[0], 64)), 'VT is not whitespace');
end;

procedure TestJsonNumber;
begin
  CheckEqual(Int64(3), Int64(ScanJsonNumber(PAnsiChar('123abc'), 6)), 'integer');
  CheckEqual(Int64(4), Int64(ScanJsonNumber(PAnsiChar('-123x'), 5)), 'negative');
  CheckEqual(Int64(5), Int64(ScanJsonNumber(PAnsiChar('12.34,'), 6)), 'decimal');
  CheckEqual(Int64(5), Int64(ScanJsonNumber(PAnsiChar('1e100x'), 6)), 'exponent');
  CheckEqual(Int64(6), Int64(ScanJsonNumber(PAnsiChar('1.2e+3}'), 7)), 'full float');
  CheckEqual(Int64(7), Int64(ScanJsonNumber(PAnsiChar('-1.5E-2]'), 8)), 'negative float');
  CheckEqual(Int64(1), Int64(ScanJsonNumber(PAnsiChar('0,'), 2)), 'zero');
end;

procedure TestJsonNumberInvalidBoundaries;
begin
  CheckEqual(Int64(0), Int64(ScanJsonNumber(PAnsiChar('-'), 1)), 'bare minus is not a number');
  CheckEqual(Int64(0), Int64(ScanJsonNumber(PAnsiChar('-x'), 2)), 'minus without digit is not a number');
  CheckEqual(Int64(0), Int64(ScanJsonNumber(PAnsiChar('1.'), 2)), 'fraction requires digit');
  CheckEqual(Int64(0), Int64(ScanJsonNumber(PAnsiChar('1.e2'), 4)), 'fraction rejects missing digit');
  CheckEqual(Int64(0), Int64(ScanJsonNumber(PAnsiChar('1e+'), 3)), 'exponent requires digit');
  CheckEqual(Int64(0), Int64(ScanJsonNumber(PAnsiChar('01'), 2)), 'leading zero rejects next digit');
end;

procedure TestMatchLiteral;
begin
  Check(ScanMatchLiteral(PAnsiChar('true'), 4, PAnsiChar('true'), 4), 'true');
  Check(ScanMatchLiteral(PAnsiChar('false'), 5, PAnsiChar('false'), 5), 'false');
  Check(ScanMatchLiteral(PAnsiChar('null'), 4, PAnsiChar('null'), 4), 'null');
  Check(not ScanMatchLiteral(PAnsiChar('tru'), 3, PAnsiChar('true'), 4), 'too short');
  Check(not ScanMatchLiteral(PAnsiChar('True'), 4, PAnsiChar('true'), 4), 'case sensitive');
end;

procedure TestViewSkipWhitespace;
var
  V: TStringView;
begin
  V := TStringView.Create(PAnsiChar('  hello'), 7);
  ViewSkipWhitespace(V);
  CheckEqual(Int64(5), Int64(V.Len), 'len after skip');
  Check(V.Data[0] = 'h', 'first non-ws');
end;

procedure TestViewMatchLiteral;
var
  V: TStringView;
begin
  V := TStringView.Create(PAnsiChar('true,rest'), 9);
  Check(ViewMatchLiteral(V, PAnsiChar('true'), 4), 'match true');
  CheckEqual(Int64(5), Int64(V.Len), 'advanced past true');
  Check(V.Data[0] = ',', 'next is comma');
end;

procedure TestFindByte;
begin
  CheckEqual(Int64(5), Int64(ScanFindByte(PAnsiChar('hello:world'), 11, Ord(':'))), 'colon at 5');
  CheckEqual(Int64(0), Int64(ScanFindByte(PAnsiChar(':abc'), 4, Ord(':'))), 'colon at 0');
  CheckEqual(Int64(-1), Int64(ScanFindByte(PAnsiChar('abcdef'), 6, Ord(':'))), 'not found');
end;

procedure TestFindByte2Long;
var
  Buf: array[0..63] of AnsiChar;
begin
  FillChar(Buf, 64, Ord('a'));
  Buf[50] := ':';
  CheckEqual(Int64(50), Int64(ScanFindByte2(@Buf[0], 64, Ord(':'), Ord(';'))), 'colon at 50');
end;

procedure TestFindSubstringCIFoldsNeedleCase;
var
  LHighBytes, LHighNeedle: array[0..1] of AnsiChar;
begin
  CheckEqual(Int64(1),
    Int64(ScanFindSubstringCI(PAnsiChar('abcDEF'), 6, PAnsiChar('BCD'), 3)),
    'uppercase needle should match lowercase haystack');
  CheckEqual(Int64(1),
    Int64(ScanFindSubstringCI(PAnsiChar('ABCDEF'), 6, PAnsiChar('bCd'), 3)),
    'mixed-case needle should match uppercase haystack');
  CheckEqual(Int64(0),
    Int64(ScanFindSubstringCI(PAnsiChar('A'), 1, PAnsiChar('a'), 1)),
    'one-character ASCII needle should fold');
  CheckEqual(Int64(-1),
    Int64(ScanFindSubstringCI(PAnsiChar('['), 1, PAnsiChar('{'), 1)),
    'punctuation bytes should not fold');

  LHighBytes[0] := AnsiChar(Chr($C0));
  LHighBytes[1] := AnsiChar(Chr($00));
  LHighNeedle[0] := AnsiChar(Chr($E0));
  LHighNeedle[1] := AnsiChar(Chr($00));
  CheckEqual(Int64(-1),
    Int64(ScanFindSubstringCI(@LHighBytes[0], 1, @LHighNeedle[0], 1)),
    'high bytes should not fold');
end;

begin
  T := TTestRunner.Create('nextpas.core.text.scan');
  T.Run('FindByte', @TestFindByte);
  T.Run('FindByte2', @TestFindByte2);
  T.Run('FindByte3', @TestFindByte3);
  T.Run('FindInRange', @TestFindInRange);
  T.Run('FindNotInRange', @TestFindNotInRange);
  T.Run('SkipWhitespace', @TestSkipWhitespace);
  T.Run('SkipWhitespace long', @TestSkipWhitespaceLong);
  T.Run('SkipWhitespace rejects control bytes', @TestSkipWhitespaceRejectsControlBytes);
  T.Run('JsonNumber', @TestJsonNumber);
  T.Run('JsonNumber invalid boundaries', @TestJsonNumberInvalidBoundaries);
  T.Run('MatchLiteral', @TestMatchLiteral);
  T.Run('ViewSkipWhitespace', @TestViewSkipWhitespace);
  T.Run('ViewMatchLiteral', @TestViewMatchLiteral);
  T.Run('FindByte2 long', @TestFindByte2Long);
  T.Run('FindSubstringCI folds needle case', @TestFindSubstringCIFoldsNeedleCase);
  T.Summary;
end.
