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

procedure TestFindByte2Long;
var
  Buf: array[0..63] of AnsiChar;
begin
  FillChar(Buf, 64, Ord('a'));
  Buf[50] := ':';
  CheckEqual(Int64(50), Int64(ScanFindByte2(@Buf[0], 64, Ord(':'), Ord(';'))), 'colon at 50');
end;

begin
  T := TTestRunner.Create('nextpas.core.text.scan');
  T.Run('FindByte2', @TestFindByte2);
  T.Run('FindByte3', @TestFindByte3);
  T.Run('FindInRange', @TestFindInRange);
  T.Run('FindNotInRange', @TestFindNotInRange);
  T.Run('SkipWhitespace', @TestSkipWhitespace);
  T.Run('SkipWhitespace long', @TestSkipWhitespaceLong);
  T.Run('JsonNumber', @TestJsonNumber);
  T.Run('MatchLiteral', @TestMatchLiteral);
  T.Run('ViewSkipWhitespace', @TestViewSkipWhitespace);
  T.Run('ViewMatchLiteral', @TestViewMatchLiteral);
  T.Run('FindByte2 long', @TestFindByte2Long);
  T.Summary;
end.
