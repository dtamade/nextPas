program test_conformance_case;
{**
 * UCD 16.0 CaseFolding + SpecialCasing official harness.
 *
 * Fixtures:
 *   ../data/case_folding.txt
 *   ../data/special_casing.txt
 *
 * Scope: CaseFold C/F/S (skip T); SpecialCasing unconditional + Final_Sigma samples.
 *}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode;

var
  T: TTestSuite;

{$I ../test_helpers.inc}


function NthSemicolonField(const ALine: string; const AIndex: Integer): string;
{ 0-based field between semicolons }
var
  I, Start, Field: Integer;
begin
  Result := '';
  Start := 1;
  Field := 0;
  for I := 1 to Length(ALine) + 1 do
  begin
    if (I > Length(ALine)) or (ALine[I] = ';') then
    begin
      if Field = AIndex then
      begin
        Result := Trim(Copy(ALine, Start, I - Start));
        Exit;
      end;
      Inc(Field);
      Start := I + 1;
    end;
  end;
end;

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

function ParseHexCp(const AHex: string): TUnicodeCodepoint;
var
  I, D: Integer;
  V: UInt32;
begin
  V := 0;
  for I := 1 to Length(AHex) do
  begin
    D := ParseHexDigit(AHex[I]);
    if D < 0 then
      Exit(0);
    V := (V shl 4) or UInt32(D);
  end;
  Result := V;
end;

function BuildUtf8(const ACps: array of TUnicodeCodepoint; const ACount: Integer): string;
var
  I, J, LPos: Integer;
  LBuf: array[0..3] of Byte;
  LLen: Byte;
begin
  LPos := 0;
  SetLength(Result, ACount * 4 + 4);
  for I := 0 to ACount - 1 do
  begin
    LLen := UTF8Encode(ACps[I], @LBuf[0]);
    if LLen = 0 then
      Continue;
    if LPos + LLen > Length(Result) then
      SetLength(Result, (LPos + LLen) * 2);
    for J := 0 to Integer(LLen) - 1 do
      Result[LPos + J + 1] := Chr(LBuf[J]);
    Inc(LPos, LLen);
  end;
  SetLength(Result, LPos);
end;

function ParseHexList(const AField: string; out ACps: array of TUnicodeCodepoint; out ACount: Integer): Boolean;
var
  LStart, I: Integer;
  LTok: string;
begin
  ACount := 0;
  Result := True;
  if Trim(AField) = '' then
    Exit;
  LStart := 1;
  for I := 1 to Length(AField) + 1 do
  begin
    if (I > Length(AField)) or (AField[I] = ' ') then
    begin
      if I > LStart then
      begin
        LTok := Copy(AField, LStart, I - LStart);
        if ACount >= Length(ACps) then
          Exit(False);
        ACps[ACount] := ParseHexCp(LTok);
        Inc(ACount);
      end;
      LStart := I + 1;
    end;
  end;
end;

function CpsEqualMap(const AMap: TCaseFoldMap; const ALen: Byte;
  const AExp: array of TUnicodeCodepoint; const AExpCount: Integer): Boolean;
var
  I: Integer;
begin
  if Integer(ALen) <> AExpCount then
    Exit(False);
  for I := 0 to AExpCount - 1 do
    if AMap[I] <> AExp[I] then
      Exit(False);
  Result := True;
end;

procedure TestCaseFolding;
var
  LPath: string;
  LFile: TextFile;
  LLine, LCode, LStatus, LMapField: string;
  LCp: TUnicodeCodepoint;
  LExp: array[0..7] of TUnicodeCodepoint;
  LExpCount: Integer;
  LMap: TCaseFoldMap;
  LLen: Byte;
  LData, LFail, LSkipT: Int64;
  LLineNo: Int64;
  LSimple: TUnicodeCodepoint;
  LMaxPrint: Integer;
begin
  LPath := ResolveFixture('case_folding.txt');
  Check(FileExists(LPath), 'case_folding.txt exists');
  LData := 0;
  LFail := 0;
  LSkipT := 0;
  LLineNo := 0;
  LMaxPrint := 25;

  AssignFile(LFile, LPath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Inc(LLineNo);
      if (LLine = '') or (LLine[1] = '#') then
        Continue;
      { code; status; mapping; }
      LCode := NthSemicolonField(LLine, 0);
      LStatus := NthSemicolonField(LLine, 1);
      LMapField := NthSemicolonField(LLine, 2);
      if (LCode = '') or (LStatus = '') then
        Continue;
      if LStatus = 'T' then
      begin
        Inc(LSkipT);
        Continue;
      end;
      if (LStatus <> 'C') and (LStatus <> 'F') and (LStatus <> 'S') then
        Continue;

      LCp := ParseHexCp(LCode);
      if not ParseHexList(LMapField, LExp, LExpCount) then
        Continue;
      Inc(LData);

      if (LStatus = 'C') or (LStatus = 'S') then
      begin
        LSimple := CaseFoldSimple(LCp);
        if (LExpCount <> 1) or (LSimple <> LExp[0]) then
        begin
          Inc(LFail);
          if LFail <= LMaxPrint then
            WriteLn(Format('FAIL CaseFold S/C L%d U+%s simple got %x exp %s',
              [LLineNo, LCode, LSimple, LMapField]));
        end;
      end;

      if (LStatus = 'C') or (LStatus = 'F') then
      begin
        LLen := CaseFoldFull(LCp, LMap);
        if not CpsEqualMap(LMap, LLen, LExp, LExpCount) then
        begin
          Inc(LFail);
          if LFail <= LMaxPrint then
            WriteLn(Format('FAIL CaseFold F/C L%d U+%s full mismatch exp %s',
              [LLineNo, LCode, LMapField]));
        end;
      end;
    end;
  finally
    CloseFile(LFile);
  end;

  WriteLn(Format('CaseFolding: data=%d fail=%d skipT=%d', [LData, LFail, LSkipT]));
  Check(LFail = 0, 'CaseFolding fail=0');
  Check(LData > 1000, 'CaseFolding has data');
end;

function Utf8OfCp(const ACp: TUnicodeCodepoint): string;
var
  A: array[0..0] of TUnicodeCodepoint;
begin
  A[0] := ACp;
  Result := BuildUtf8(A, 1);
end;

procedure TestSpecialCasingUnconditional;
var
  LPath: string;
  LFile: TextFile;
  LLine: string;
  LCode, LLower, LTitle, LUpper, LCond: string;
  LCp: TUnicodeCodepoint;
  LExpL, LExpT, LExpU: array[0..7] of TUnicodeCodepoint;
  LCntL, LCntT, LCntU: Integer;
  LGot: string;
  LExpStr: string;
  LData, LFail, LSkipCond: Int64;
  LLineNo: Int64;
  LMaxPrint: Integer;
begin
  LPath := ResolveFixture('special_casing.txt');
  Check(FileExists(LPath), 'special_casing.txt exists');
  LData := 0;
  LFail := 0;
  LSkipCond := 0;
  LLineNo := 0;
  LMaxPrint := 25;

  AssignFile(LFile, LPath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Inc(LLineNo);
      if (LLine = '') or (LLine[1] = '#') then
        Continue;
      LCode := NthSemicolonField(LLine, 0);
      LLower := NthSemicolonField(LLine, 1);
      LTitle := NthSemicolonField(LLine, 2);
      LUpper := NthSemicolonField(LLine, 3);
      LCond := NthSemicolonField(LLine, 4);
      if Pos('#', LCond) > 0 then
        LCond := Trim(Copy(LCond, 1, Pos('#', LCond) - 1));
      if LCode = '' then
        Continue;
      if LCond <> '' then
      begin
        Inc(LSkipCond);
        Continue;
      end;

      LCp := ParseHexCp(LCode);
      if not ParseHexList(LLower, LExpL, LCntL) then Continue;
      if not ParseHexList(LTitle, LExpT, LCntT) then Continue;
      if not ParseHexList(LUpper, LExpU, LCntU) then Continue;
      Inc(LData);

      LGot := UTF8ToLower(Utf8OfCp(LCp));
      LExpStr := BuildUtf8(LExpL, LCntL);
      if LGot <> LExpStr then
      begin
        Inc(LFail);
        if LFail <= LMaxPrint then
          WriteLn(Format('FAIL Special lower L%d U+%s', [LLineNo, LCode]));
      end;

      LGot := UTF8ToTitle(Utf8OfCp(LCp));
      LExpStr := BuildUtf8(LExpT, LCntT);
      if LGot <> LExpStr then
      begin
        Inc(LFail);
        if LFail <= LMaxPrint then
          WriteLn(Format('FAIL Special title L%d U+%s', [LLineNo, LCode]));
      end;

      LGot := UTF8ToUpper(Utf8OfCp(LCp));
      LExpStr := BuildUtf8(LExpU, LCntU);
      if LGot <> LExpStr then
      begin
        Inc(LFail);
        if LFail <= LMaxPrint then
          WriteLn(Format('FAIL Special upper L%d U+%s', [LLineNo, LCode]));
      end;
    end;
  finally
    CloseFile(LFile);
  end;

  WriteLn(Format('SpecialCasing uncond: data=%d fail=%d skipCond=%d', [LData, LFail, LSkipCond]));
  Check(LFail = 0, 'SpecialCasing unconditional fail=0');
  Check(LData > 50, 'SpecialCasing has unconditional data');
end;

procedure TestFinalSigma;
var
  LSigma, LFinal, LMedial: string;
begin
  { ΑΣ → ασ (final at end) }
  LSigma := UTF8ToLower(Utf8OfCp($0391) + Utf8OfCp($03A3));
  LFinal := Utf8OfCp($03B1) + Utf8OfCp($03C2);
  CheckEqual(LSigma, LFinal, 'ΑΣ lower ends with final sigma');

  { ΑΣ. → ασ. (final before non-cased) }
  LSigma := UTF8ToLower(Utf8OfCp($0391) + Utf8OfCp($03A3) + '.');
  LFinal := Utf8OfCp($03B1) + Utf8OfCp($03C2) + '.';
  CheckEqual(LSigma, LFinal, 'ΑΣ. lower final sigma before period');

  { ΑΣΑ → ασα (not final — cased after) }
  LSigma := UTF8ToLower(Utf8OfCp($0391) + Utf8OfCp($03A3) + Utf8OfCp($0391));
  LMedial := Utf8OfCp($03B1) + Utf8OfCp($03C3) + Utf8OfCp($03B1);
  CheckEqual(LSigma, LMedial, 'ΑΣΑ lower medial sigma');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.conformance_case');
  T.Test('CaseFolding', @TestCaseFolding);
  T.Test('SpecialCasingUnconditional', @TestSpecialCasingUnconditional);
  T.Test('FinalSigma', @TestFinalSigma);
  if not T.Run then
    Halt(1);
end.
