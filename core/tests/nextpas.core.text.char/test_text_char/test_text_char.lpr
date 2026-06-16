program test_text_char;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.char,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestIsDigit;
var
  I: Integer;
begin
  for I := Ord('0') to Ord('9') do
    Check(IsDigit(I), 'digit ' + Chr(I));
  Check(not IsDigit(Ord('a')), 'a not digit');
  Check(not IsDigit(Ord(' ')), 'space not digit');
  Check(not IsDigit(0), 'NUL not digit');
end;

procedure TestIsAlpha;
begin
  Check(IsAlpha(Ord('A')), 'A');
  Check(IsAlpha(Ord('Z')), 'Z');
  Check(IsAlpha(Ord('a')), 'a');
  Check(IsAlpha(Ord('z')), 'z');
  Check(not IsAlpha(Ord('0')), '0 not alpha');
  Check(not IsAlpha(Ord('_')), '_ not alpha');
end;

procedure TestIsUpper;
begin
  Check(IsUpper(Ord('A')), 'A upper');
  Check(IsUpper(Ord('Z')), 'Z upper');
  Check(not IsUpper(Ord('a')), 'a not upper');
  Check(not IsUpper(Ord('0')), '0 not upper');
  Check(not IsUpper(128), 'high byte not upper');
end;

procedure TestIsLower;
begin
  Check(IsLower(Ord('a')), 'a lower');
  Check(IsLower(Ord('z')), 'z lower');
  Check(not IsLower(Ord('A')), 'A not lower');
  Check(not IsLower(Ord('0')), '0 not lower');
  Check(not IsLower(255), 'high byte not lower');
end;

procedure TestIsAscii;
begin
  Check(IsAscii(0), 'NUL is ASCII');
  Check(IsAscii(127), 'DEL is ASCII');
  Check(not IsAscii(128), '0x80 is not ASCII');
  Check(not IsAscii(255), '0xFF is not ASCII');
end;

procedure TestIsHexDigit;
begin
  Check(IsHexDigit(Ord('0')), '0');
  Check(IsHexDigit(Ord('9')), '9');
  Check(IsHexDigit(Ord('a')), 'a');
  Check(IsHexDigit(Ord('f')), 'f');
  Check(IsHexDigit(Ord('A')), 'A');
  Check(IsHexDigit(Ord('F')), 'F');
  Check(not IsHexDigit(Ord('g')), 'g not hex');
  Check(not IsHexDigit(Ord('G')), 'G not hex');
end;

procedure TestIsWhitespace;
begin
  Check(IsWhitespace(Ord(' ')), 'space');
  Check(IsWhitespace(9), 'tab');
  Check(IsWhitespace(10), 'LF');
  Check(IsWhitespace(13), 'CR');
  Check(not IsWhitespace(Ord('x')), 'x not ws');
  Check(not IsWhitespace(0), 'NUL not ws');
end;

procedure TestIsControl;
begin
  Check(IsControl(0), 'NUL');
  Check(IsControl(31), 'US');
  Check(IsControl(127), 'DEL');
  Check(not IsControl(32), 'space not control');
  Check(not IsControl(Ord('A')), 'A not control');
end;

procedure TestIsJsonSpecial;
begin
  Check(IsJsonSpecial(Ord('"')), 'quote');
  Check(IsJsonSpecial(Ord('\')), 'backslash');
  Check(IsJsonSpecial(0), 'NUL (control)');
  Check(IsJsonSpecial(10), 'LF (control)');
  Check(not IsJsonSpecial(Ord('a')), 'a not special');
  Check(not IsJsonSpecial(Ord(' ')), 'space not special');
end;

procedure TestHexDigitValue;
begin
  CheckEqual(Int64(0), Int64(HexDigitValue(Ord('0'))), '0');
  CheckEqual(Int64(9), Int64(HexDigitValue(Ord('9'))), '9');
  CheckEqual(Int64(10), Int64(HexDigitValue(Ord('a'))), 'a');
  CheckEqual(Int64(15), Int64(HexDigitValue(Ord('f'))), 'f');
  CheckEqual(Int64(10), Int64(HexDigitValue(Ord('A'))), 'A');
  CheckEqual(Int64(15), Int64(HexDigitValue(Ord('F'))), 'F');
  CheckEqual(Int64(-1), Int64(HexDigitValue(Ord('g'))), 'g invalid');
  CheckEqual(Int64(-1), Int64(HexDigitValue(Ord(' '))), 'space invalid');
end;

procedure TestToLowerUpper;
begin
  CheckEqual(Int64(Ord('a')), Int64(ToLower(Ord('A'))), 'A->a');
  CheckEqual(Int64(Ord('z')), Int64(ToLower(Ord('Z'))), 'Z->z');
  CheckEqual(Int64(Ord('0')), Int64(ToLower(Ord('0'))), '0 unchanged');
  CheckEqual(Int64(Ord('A')), Int64(ToUpper(Ord('a'))), 'a->A');
  CheckEqual(Int64(Ord('Z')), Int64(ToUpper(Ord('z'))), 'z->Z');
  CheckEqual(Int64(Ord('5')), Int64(ToUpper(Ord('5'))), '5 unchanged');
end;

procedure TestIsAlphaNum;
begin
  Check(IsAlphaNum(Ord('a')), 'a');
  Check(IsAlphaNum(Ord('Z')), 'Z');
  Check(IsAlphaNum(Ord('5')), '5');
  Check(not IsAlphaNum(Ord('_')), '_ not alphanum');
  Check(not IsAlphaNum(Ord(' ')), 'space not alphanum');
end;

procedure TestTableCompleteness;
var
  I: Integer;
begin
  for I := 0 to 31 do
    Check(IsControl(I), 'control 0x' + HexStr(I, 2));
  for I := 128 to 255 do
    Check(CharClass(I) = 0, 'high byte 0x' + HexStr(I, 2) + ' has no class');
end;

begin
  T := TTestRunner.Create('nextpas.core.text.char');
  T.Run('IsDigit', @TestIsDigit);
  T.Run('IsAlpha', @TestIsAlpha);
  T.Run('IsUpper', @TestIsUpper);
  T.Run('IsLower', @TestIsLower);
  T.Run('IsAscii', @TestIsAscii);
  T.Run('IsHexDigit', @TestIsHexDigit);
  T.Run('IsWhitespace', @TestIsWhitespace);
  T.Run('IsControl', @TestIsControl);
  T.Run('IsJsonSpecial', @TestIsJsonSpecial);
  T.Run('HexDigitValue', @TestHexDigitValue);
  T.Run('ToLower/ToUpper', @TestToLowerUpper);
  T.Run('IsAlphaNum', @TestIsAlphaNum);
  T.Run('table completeness', @TestTableCompleteness);
  T.Summary;
end.
