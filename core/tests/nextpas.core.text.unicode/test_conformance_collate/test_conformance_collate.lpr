program test_conformance_collate;
{**
 * UCA 16.0 CollationTest official conformance harness.
 *
 * Fixtures: ../data/CollationTest_NON_IGNORABLE.txt
 *           ../data/CollationTest_SHIFTED.txt
 *
 * Each line must be >= previous line under UCA strength=identical.
 *}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode.collate,
  nextpas.core.text.unicode;

var
  T: TTestSuite;

{$I ../test_helpers.inc}

function ResolveFixture(const AName: string): string;
begin
  if FileExists('../data/' + AName) then
    Exit('../data/' + AName);
  if FileExists('core/tests/nextpas.core.text.unicode/data/' + AName) then
    Exit('core/tests/nextpas.core.text.unicode/data/' + AName);
  Result := '../data/' + AName;
end;

function ParseHexDigit(const ACh: Char): Integer;
begin
  case ACh of
    '0'..'9': Result := Ord(ACh) - Ord('0');
    'a'..'f': Result := Ord(ACh) - Ord('a') + 10;
    'A'..'F': Result := Ord(ACh) - Ord('A') + 10;
  else
    Result := -1;
  end;
end;

function ParseHexCodepoint(const AHex: string): TUnicodeCodepoint;
var
  I: Integer;
  LDigit: Integer;
  LValue: UInt32;
begin
  LValue := 0;
  for I := 1 to Length(AHex) do
  begin
    LDigit := ParseHexDigit(AHex[I]);
    if LDigit < 0 then
      Exit(0);
    LValue := (LValue shl 4) or UInt32(LDigit);
  end;
  Result := LValue;
end;

function BuildUtf8FromLine(const AField: string; out AHasSurrogate: Boolean): string;
var
  LStart, I, J: Integer;
  LToken: string;
  LCp: TUnicodeCodepoint;
  LBuf: array[0..7] of Byte;
  LLen: Integer;
  LOut: string;
  LPos: Integer;
begin
  AHasSurrogate := False;
  LOut := '';
  LPos := 0;
  SetLength(LOut, Length(AField) * 4 + 8);
  if AField = '' then
    Exit('');
  LStart := 1;
  for I := 1 to Length(AField) + 1 do
  begin
    if (I > Length(AField)) or (AField[I] = ' ') or (AField[I] = #9) then
    begin
      if I > LStart then
      begin
        LToken := Copy(AField, LStart, I - LStart);
        LCp := ParseHexCodepoint(LToken);
        if (LCp >= $D800) and (LCp <= $DFFF) then
          AHasSurrogate := True;
        LLen := UTF8Encode(LCp, @LBuf[0]);
        if LLen > 0 then
        begin
          if LPos + LLen > Length(LOut) then
            SetLength(LOut, (LPos + LLen) * 2);
          for J := 0 to LLen - 1 do
            LOut[LPos + J + 1] := Chr(LBuf[J]);
          Inc(LPos, LLen);
        end
        else if LCp = 0 then
        begin
          // U+0000 as single NUL byte (UTF-8)
          if LPos + 1 > Length(LOut) then
            SetLength(LOut, LPos + 8);
          LOut[LPos + 1] := #0;
          Inc(LPos);
        end;
      end;
      LStart := I + 1;
    end;
  end;
  SetLength(LOut, LPos);
  Result := LOut;
end;

function ExtractCpField(const ALine: string): string;
var
  P: Integer;
begin
  P := Pos(';', ALine);
  if P > 0 then
    Result := Trim(Copy(ALine, 1, P - 1))
  else
    Result := Trim(ALine);
end;

procedure RunCollationFile(const APath: string; const AVariable: TCollationVariableWeighting;
  const ALabel: string);
var
  LFile: TextFile;
  LLine: string;
  LField, LPrevField: string;
  LPrev, LCur: string;
  LHasPrev: Boolean;
  LHasSurr: Boolean;
  LCollator: IUnicodeCollator;
  LOpts: TCollationOptions;
  LData, LFail, LSkip: Int64;
  LLineNo: Int64;
  LCmp: Integer;
  LMaxFailPrint: Integer;
begin
  LOpts := UCACollationOptions(AVariable);
  LCollator := UnicodeCollatorWithOptions(LOpts);
  LData := 0;
  LFail := 0;
  LSkip := 0;
  LLineNo := 0;
  LHasPrev := False;
  LPrev := '';
  LPrevField := '';
  LMaxFailPrint := 40;

  AssignFile(LFile, APath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Inc(LLineNo);
      if (LLine = '') or (LLine[1] = '#') then
        Continue;
      LField := ExtractCpField(LLine);
      if LField = '' then
        Continue;
      LCur := BuildUtf8FromLine(LField, LHasSurr);
      if LHasSurr then
      begin
        Inc(LSkip);
        Continue;
      end;
      Inc(LData);
      if LHasPrev then
      begin
        LCmp := LCollator.Compare(LPrev, LCur);
        if LCmp > 0 then
        begin
          Inc(LFail);
          if LFail <= LMaxFailPrint then
            WriteLn(Format('FAIL %s L%d cmp=%d prev=[%s] cur=[%s]',
              [ALabel, LLineNo, LCmp, LPrevField, LField]));
        end;
      end;
      LPrev := LCur;
      LPrevField := LField;
      LHasPrev := True;
    end;
  finally
    CloseFile(LFile);
  end;

  WriteLn(Format('%s: data=%d fail=%d skip=%d', [ALabel, LData, LFail, LSkip]));
  Check(LFail = 0, ALabel + ' fail=0');
  Check(LData > 1000, ALabel + ' has data');
end;

procedure TestNonIgnorable;
var
  LPath: string;
begin
  LPath := ResolveFixture('CollationTest_NON_IGNORABLE.txt');
  Check(FileExists(LPath), 'NON_IGNORABLE fixture exists: ' + LPath);
  RunCollationFile(LPath, cvwNonIgnorable, 'NON_IGNORABLE');
end;

procedure TestShifted;
var
  LPath: string;
begin
  LPath := ResolveFixture('CollationTest_SHIFTED.txt');
  Check(FileExists(LPath), 'SHIFTED fixture exists: ' + LPath);
  RunCollationFile(LPath, cvwShifted, 'SHIFTED');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.conformance_collate');
  T.Test('NonIgnorable', @TestNonIgnorable);
  T.Test('Shifted', @TestShifted);
  if not T.Run then
    Halt(1);
end.
