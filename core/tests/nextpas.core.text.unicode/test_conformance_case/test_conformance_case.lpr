program test_conformance_case;
{**
 * UCD 16.0 CaseFolding + SpecialCasing official harness.
 *
 * Fixtures:
 *   ../data/case_folding.txt
 *   ../data/special_casing.txt
 *
 * Scope: CaseFold C/F/S (root); CaseFold T + SpecialCasing tr/az (locale);
 *        SpecialCasing unconditional + Final_Sigma samples.
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

procedure TestCaseFoldingTurkic;
var
  LPath: string;
  LFile: TextFile;
  LLine, LCode, LStatus, LMapField: string;
  LCp: TUnicodeCodepoint;
  LExp: array[0..7] of TUnicodeCodepoint;
  LExpCount: Integer;
  LMap: TCaseFoldMap;
  LLen: Byte;
  LData, LFail: Int64;
  LLineNo: Int64;
  LMaxPrint: Integer;
  LOpts: TCaseOptions;
  LSimple: TUnicodeCodepoint;
begin
  LPath := ResolveFixture('case_folding.txt');
  Check(FileExists(LPath), 'case_folding.txt exists');
  LData := 0;
  LFail := 0;
  LLineNo := 0;
  LMaxPrint := 25;
  LOpts.Locale := clTurkish;

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
      LStatus := NthSemicolonField(LLine, 1);
      LMapField := NthSemicolonField(LLine, 2);
      if LStatus <> 'T' then
        Continue;
      LCp := ParseHexCp(LCode);
      if not ParseHexList(LMapField, LExp, LExpCount) then
        Continue;
      Inc(LData);

      LSimple := CaseFoldSimple(LCp, LOpts);
      if (LExpCount <> 1) or (LSimple <> LExp[0]) then
      begin
        Inc(LFail);
        if LFail <= LMaxPrint then
          WriteLn(Format('FAIL CaseFold T simple L%d U+%s got %x exp %s',
            [LLineNo, LCode, LSimple, LMapField]));
      end;

      LLen := CaseFoldFull(LCp, LMap, LOpts);
      if not CpsEqualMap(LMap, LLen, LExp, LExpCount) then
      begin
        Inc(LFail);
        if LFail <= LMaxPrint then
          WriteLn(Format('FAIL CaseFold T full L%d U+%s exp %s',
            [LLineNo, LCode, LMapField]));
      end;
    end;
  finally
    CloseFile(LFile);
  end;

  WriteLn(Format('CaseFolding T (tr): data=%d fail=%d', [LData, LFail]));
  Check(LFail = 0, 'CaseFolding T fail=0');
  Check(LData = 2, 'CaseFolding T has 2 rows');

  LOpts.Locale := clAzeri;
  CheckEqual(CaseFoldSimple($0049, LOpts), $0131, 'az CaseFold I');
  CheckEqual(CaseFoldSimple($0130, LOpts), $0069, 'az CaseFold İ');
end;

function CondHasTag(const ACond, ATag: string): Boolean;
{ ACond may be "tr", "tr After_I", "az Not_Before_Dot" }
var
  LParts: string;
  I, Start: Integer;
  Tok: string;
begin
  Result := False;
  LParts := Trim(ACond);
  if LParts = '' then
    Exit;
  Start := 1;
  for I := 1 to Length(LParts) + 1 do
  begin
    if (I > Length(LParts)) or (LParts[I] = ' ') then
    begin
      if I > Start then
      begin
        Tok := Copy(LParts, Start, I - Start);
        if Tok = ATag then
          Exit(True);
      end;
      Start := I + 1;
    end;
  end;
end;

function IsTurkicSpecialCond(const ACond: string): Boolean;
begin
  Result := CondHasTag(ACond, 'tr') or CondHasTag(ACond, 'az');
end;

procedure TestSpecialCasingTurkic;
var
  LPath: string;
  LFile: TextFile;
  LLine: string;
  LCode, LLower, LTitle, LUpper, LCond: string;
  LCp: TUnicodeCodepoint;
  LExpL, LExpT, LExpU: array[0..7] of TUnicodeCodepoint;
  LCntL, LCntT, LCntU: Integer;
  LGot, LExpStr, LInput: string;
  LData, LFail: Int64;
  LLineNo: Int64;
  LMaxPrint: Integer;
  LOpts: TCaseOptions;
  LIsTr, LIsAz: Boolean;
begin
  LPath := ResolveFixture('special_casing.txt');
  Check(FileExists(LPath), 'special_casing.txt exists');
  LData := 0;
  LFail := 0;
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
      if not IsTurkicSpecialCond(LCond) then
        Continue;

      { Context-only rows (After_I / Not_Before_Dot) need multi-cp strings }
      if CondHasTag(LCond, 'After_I') or CondHasTag(LCond, 'Not_Before_Dot') then
        Continue;

      LCp := ParseHexCp(LCode);
      if not ParseHexList(LLower, LExpL, LCntL) then Continue;
      if not ParseHexList(LTitle, LExpT, LCntT) then Continue;
      if not ParseHexList(LUpper, LExpU, LCntU) then Continue;
      Inc(LData);

      LIsTr := CondHasTag(LCond, 'tr');
      LIsAz := CondHasTag(LCond, 'az');
      if LIsTr then
        LOpts.Locale := clTurkish
      else if LIsAz then
        LOpts.Locale := clAzeri
      else
        Continue;

      LInput := Utf8OfCp(LCp);

      LGot := UTF8ToLower(LInput, LOpts);
      LExpStr := BuildUtf8(LExpL, LCntL);
      if LGot <> LExpStr then
      begin
        Inc(LFail);
        if LFail <= LMaxPrint then
          WriteLn(Format('FAIL Turkic Special lower L%d U+%s cond=%s',
            [LLineNo, LCode, LCond]));
      end;

      LGot := UTF8ToTitle(LInput, LOpts);
      LExpStr := BuildUtf8(LExpT, LCntT);
      if LGot <> LExpStr then
      begin
        Inc(LFail);
        if LFail <= LMaxPrint then
          WriteLn(Format('FAIL Turkic Special title L%d U+%s cond=%s',
            [LLineNo, LCode, LCond]));
      end;

      LGot := UTF8ToUpper(LInput, LOpts);
      LExpStr := BuildUtf8(LExpU, LCntU);
      if LGot <> LExpStr then
      begin
        Inc(LFail);
        if LFail <= LMaxPrint then
          WriteLn(Format('FAIL Turkic Special upper L%d U+%s cond=%s',
            [LLineNo, LCode, LCond]));
      end;
    end;
  finally
    CloseFile(LFile);
  end;

  WriteLn(Format('SpecialCasing tr/az uncond-locale: data=%d fail=%d', [LData, LFail]));
  Check(LFail = 0, 'SpecialCasing tr/az fail=0');
  Check(LData >= 4, 'SpecialCasing tr/az has data');
end;

procedure TestTurkicContextAndSamples;
var
  LOpts, LRoot: TCaseOptions;
  LIn, LGot, LExp: string;
begin
  LRoot.Locale := clRoot;
  LOpts.Locale := clTurkish;

  { root: I → i ; Turkic: I → ı }
  LIn := Utf8OfCp($0049);
  CheckEqual(UTF8ToLower(LIn, LRoot), Utf8OfCp($0069), 'root lower I');
  CheckEqual(UTF8ToLower(LIn, LOpts), Utf8OfCp($0131), 'tr lower I');

  { root: İ → i+0307 ; Turkic: İ → i }
  LIn := Utf8OfCp($0130);
  LExp := Utf8OfCp($0069) + Utf8OfCp($0307);
  CheckEqual(UTF8ToLower(LIn, LRoot), LExp, 'root lower İ');
  CheckEqual(UTF8ToLower(LIn, LOpts), Utf8OfCp($0069), 'tr lower İ');

  { Turkic: i → İ upper/title }
  LIn := Utf8OfCp($0069);
  CheckEqual(UTF8ToUpper(LIn, LOpts), Utf8OfCp($0130), 'tr upper i');
  CheckEqual(UTF8ToTitle(LIn, LOpts), Utf8OfCp($0130), 'tr title i');
  CheckEqual(UTF8ToUpper(LIn, LRoot), Utf8OfCp($0049), 'root upper i');

  { Turkic: ı → I upper }
  LIn := Utf8OfCp($0131);
  CheckEqual(UTF8ToUpper(LIn, LOpts), Utf8OfCp($0049), 'tr upper ı');

  { After_I: I + 0307 → i (dot removed) }
  LIn := Utf8OfCp($0049) + Utf8OfCp($0307);
  CheckEqual(UTF8ToLower(LIn, LOpts), Utf8OfCp($0069), 'tr After_I I+dot');
  { root keeps i + combining dot from simple maps }
  LGot := UTF8ToLower(LIn, LRoot);
  LExp := Utf8OfCp($0069) + Utf8OfCp($0307);
  CheckEqual(LGot, LExp, 'root lower I+dot');

  { CaseFold string }
  LIn := Utf8OfCp($0049) + Utf8OfCp($0130);
  LExp := Utf8OfCp($0131) + Utf8OfCp($0069);
  CheckEqual(UTF8CaseFold(LIn, LOpts), LExp, 'tr CaseFold Iİ');
  LExp := Utf8OfCp($0069) + Utf8OfCp($0069) + Utf8OfCp($0307);
  CheckEqual(UTF8CaseFold(LIn, LRoot), LExp, 'root CaseFold Iİ');

  LOpts.Locale := clAzeri;
  CheckEqual(UTF8ToLower(Utf8OfCp($0049), LOpts), Utf8OfCp($0131), 'az lower I');
end;


begin
  T := TTestSuite.Create('nextpas.core.text.unicode.conformance_case');
  T.Test('CaseFolding', @TestCaseFolding);
  T.Test('SpecialCasingUnconditional', @TestSpecialCasingUnconditional);
  T.Test('FinalSigma', @TestFinalSigma);
  T.Test('CaseFoldingTurkic', @TestCaseFoldingTurkic);
  T.Test('SpecialCasingTurkic', @TestSpecialCasingTurkic);
  T.Test('TurkicContextAndSamples', @TestTurkicContextAndSamples);
  if not T.Run then
    Halt(1);
end.
