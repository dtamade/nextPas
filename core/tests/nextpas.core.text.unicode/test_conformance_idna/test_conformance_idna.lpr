program test_conformance_idna;
{**
 * UTS #46 IdnaTestV2 official conformance harness (Unicode 16.0).
 *
 * Fixture: ../data/idna_test_v2.txt (IdnaTestV2.txt, 2024-07-03)
 *
 * Row format (7 ';'-separated columns, '#' starts a comment):
 *   source; toUnicode; toUnicodeStatus; toAsciiN; toAsciiNStatus; toAsciiT; toAsciiTStatus
 * Blank value column inherits: toUnicode←source, toAsciiN←toUnicode.
 * Blank status column inherits: toUnicodeStatus←[], toAsciiNStatus←toUnicodeStatus.
 * '""' means the empty string. \uXXXX escapes with surrogate-pair combining.
 *
 * Profile under test is Nontransitional with every flag enabled
 * (UseSTD3ASCIIRules, CheckHyphens, CheckBidi, CheckJoiners, VerifyDnsLength),
 * so ALL status codes count as expected errors — none are filtered.
 * Columns 6-7 (transitional) are ignored. Binary conformance:
 *   status non-empty → kind <> idnaOk; status empty → kind = idnaOk + exact match.
 * Rows whose fields contain unpaired surrogates cannot be represented in
 * UTF-8 and are skipped (permitted by the file header for implementations
 * that cannot work with ill-formed strings).
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.text,
  nextpas.core.test,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode.base,
  nextpas.core.text.unicode;

var
  T: TTestSuite;

{$I ../test_helpers.inc}

function TrimWs(const S: string): string;
var
  A, B: SizeInt;
begin
  A := 1;
  B := Length(S);
  while (A <= B) and (S[A] in [' ', #9]) do
    Inc(A);
  while (B >= A) and (S[B] in [' ', #9]) do
    Dec(B);
  Result := Copy(S, A, B - A + 1);
end;

{ \uXXXX unescape with surrogate-pair combining.
  False = ill-formed field (unpaired surrogate / bad escape). }
function UnescapeField(const AField: string; out AValue: string): Boolean;
var
  I: SizeInt;
  LCp, LLo: UInt32;

  function ReadHex4(const APos: SizeInt; out AOut: UInt32): Boolean;
  var
    J, D: Integer;
  begin
    AOut := 0;
    Result := False;
    if APos + 3 > Length(AField) then
      Exit;
    for J := 0 to 3 do
    begin
      case AField[APos + J] of
        '0'..'9': D := Ord(AField[APos + J]) - Ord('0');
        'a'..'f': D := Ord(AField[APos + J]) - Ord('a') + 10;
        'A'..'F': D := Ord(AField[APos + J]) - Ord('A') + 10;
      else
        Exit;
      end;
      AOut := (AOut shl 4) or UInt32(D);
    end;
    Result := True;
  end;

  function AppendCp(const ACpVal: UInt32): Boolean;
  var
    LBuf: array[0..3] of Byte;
    LLen, LOld, K: Integer;
  begin
    LLen := Integer(UTF8Encode(ACpVal, @LBuf[0]));
    if LLen = 0 then
      Exit(False);
    LOld := Length(AValue);
    SetLength(AValue, LOld + LLen);
    for K := 0 to LLen - 1 do
      AValue[LOld + 1 + K] := AnsiChar(LBuf[K]);
    Result := True;
  end;

begin
  Result := False;
  AValue := '';
  I := 1;
  while I <= Length(AField) do
  begin
    if (AField[I] = '\') and (I < Length(AField)) and (AField[I + 1] = 'u') then
    begin
      if not ReadHex4(I + 2, LCp) then
        Exit;
      Inc(I, 6);
      if (LCp >= $D800) and (LCp <= $DBFF) then
      begin
        if (I + 5 <= Length(AField)) and (AField[I] = '\') and (AField[I + 1] = 'u')
          and ReadHex4(I + 2, LLo) and (LLo >= $DC00) and (LLo <= $DFFF) then
        begin
          LCp := $10000 + ((LCp - $D800) shl 10) + (LLo - $DC00);
          Inc(I, 6);
        end
        else
          Exit; { unpaired high surrogate }
      end
      else if (LCp >= $DC00) and (LCp <= $DFFF) then
        Exit; { lone low surrogate }
      if not AppendCp(LCp) then
        Exit;
    end
    else
    begin
      AValue := AValue + AField[I];
      Inc(I);
    end;
  end;
  Result := True;
end;

{ Value column: blank inherits, '""' is the empty string, else unescape. }
function ResolveValue(const AField, AInherited: string; out AValue: string): Boolean;
begin
  if AField = '' then
  begin
    AValue := AInherited;
    Exit(True);
  end;
  if AField = '""' then
  begin
    AValue := '';
    Exit(True);
  end;
  Result := UnescapeField(AField, AValue);
end;

function StatusHasError(const AStatus: string): Boolean;
begin
  Result := (AStatus <> '') and (AStatus <> '[]');
end;

procedure TestIdnaConformance;
const
  MAX_REPORT = 40;
var
  LPath, LLine: string;
  LFile: Text;
  LLineNo, LChecked, LSkipped, LFailed: Integer;
  LFields: array[0..6] of string;
  LFieldIdx: Integer;
  LStart, LHash, I: SizeInt;
  LSrc, LToU, LToA, LStatU, LStatA: string;
  LErrU, LErrA: Boolean;
  R: string;
  K: TIDNAErrorKind;

  procedure ReportFail(const AOp, AExpect, AGot: string);
  begin
    Inc(LFailed);
    if LFailed <= MAX_REPORT then
      WriteLn('  line ', LLineNo, ' [', AOp, '] src="', LSrc,
        '" expect=', AExpect, ' got=', AGot);
  end;

begin
  LPath := ResolveUnicodeFixture('idna_test_v2.txt');
  Check(FileExists(LPath), 'fixture exists: ' + LPath);

  Assign(LFile, LPath);
  Reset(LFile);
  LLineNo := 0;
  LChecked := 0;
  LSkipped := 0;
  LFailed := 0;
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Inc(LLineNo);
      LHash := Pos('#', LLine);
      if LHash > 0 then
        LLine := Copy(LLine, 1, LHash - 1);
      if TrimWs(LLine) = '' then
        Continue;

      LFieldIdx := 0;
      LStart := 1;
      for I := 1 to Length(LLine) + 1 do
        if (I > Length(LLine)) or (LLine[I] = ';') then
        begin
          Check(LFieldIdx <= 6, TextFormat('too many fields line %d', [LLineNo]));
          LFields[LFieldIdx] := TrimWs(Copy(LLine, LStart, I - LStart));
          Inc(LFieldIdx);
          LStart := I + 1;
        end;
      CheckEqual(Int64(7), Int64(LFieldIdx), TextFormat('need 7 fields line %d', [LLineNo]));

      if not (ResolveValue(LFields[0], '', LSrc)
        and ResolveValue(LFields[1], LSrc, LToU)
        and ResolveValue(LFields[3], LToU, LToA)) then
      begin
        Inc(LSkipped); { ill-formed (unpaired surrogate) — permitted skip }
        Continue;
      end;
      LStatU := LFields[2];
      LStatA := LFields[4];
      if LStatA = '' then
        LStatA := LStatU;
      LErrU := StatusHasError(LStatU);
      LErrA := StatusHasError(LStatA);

      R := IDNAToUnicode(LSrc, K);
      if LErrU then
      begin
        if K = idnaOk then
          ReportFail('toUnicode', 'error ' + LStatU, 'ok "' + R + '"');
      end
      else if K <> idnaOk then
        ReportFail('toUnicode', '"' + LToU + '"', IDNAErrorKindName(K))
      else if R <> LToU then
        ReportFail('toUnicode', '"' + LToU + '"', '"' + R + '"');

      R := IDNAToASCII(LSrc, K);
      if LErrA then
      begin
        if K = idnaOk then
          ReportFail('toAsciiN', 'error ' + LStatA, 'ok "' + R + '"');
      end
      else if K <> idnaOk then
        ReportFail('toAsciiN', '"' + LToA + '"', IDNAErrorKindName(K))
      else if R <> LToA then
        ReportFail('toAsciiN', '"' + LToA + '"', '"' + R + '"');

      Inc(LChecked);
    end;
  finally
    Close(LFile);
  end;

  WriteLn('  IdnaTestV2: ', LChecked, ' rows checked, ', LSkipped,
    ' skipped (ill-formed), ', LFailed, ' failed');
  Check(LSkipped <= 4, TextFormat('unexpected skip count %d', [LSkipped]));
  Check(LChecked >= 6300, TextFormat('expected ~6389 rows, got %d', [LChecked]));
  CheckEqual(Int64(0), Int64(LFailed), 'IdnaTestV2 conformance failures');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.conformance.idna');
  T.Test('IdnaTestV2.txt full suite', @TestIdnaConformance);
  if not T.Run then
    Halt(1);
end.
