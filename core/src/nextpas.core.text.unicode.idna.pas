unit nextpas.core.text.unicode.idna;

{**
 * UTS #46 IDNA — Nontransitional profile with IdnaMappingTable (P3-1).
 * Pipeline: Map (UTS#46 table) · NFC · LDH/Punycode · length checks.
 * UseSTD3ASCIIRules = True (disallowed_STD3_* → disallowed).
 * Transitional processing is out of scope.
 *
 * Errors: TIDNAErrorKind is the structured code; string overloads map via
 * IDNAErrorKindName for legacy call sites.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types;

const
  IDNA_ACE_PREFIX = 'xn--';

type
  { Stable IDNA failure codes. Success = idnaOk. }
  TIDNAErrorKind = (
    idnaOk = 0,
    idnaEmptyDomain,
    idnaEmptyLabel,
    idnaInvalidDomain,
    idnaInvalidAsciiLabel,
    idnaNfcFailed,
    idnaPunycodeEncodeFailed,
    idnaPunycodeDecodeFailed,
    idnaEmptyAceBody,
    idnaAceLabelTooLong,
    idnaDomainTooLong,
    idnaDisallowed,
    idnaInvalidUtf8
  );

  { IdnaMappingTable status (UTS#46). }
  TIDNAMapStatus = (
    idmsValid = 0,
    idmsMapped = 1,
    idmsIgnored = 2,
    idmsDeviation = 3,
    idmsDisallowed = 4,
    idmsDisallowedSTD3Valid = 5,
    idmsDisallowedSTD3Mapped = 6
  );

function IDNAErrorKindName(const AKind: TIDNAErrorKind): string;

{ Lookup mapping status for one codepoint. Map codepoints in AMap[0..AMapLen-1]. }
function GetIdnaMapStatus(const ACp: TUnicodeCodepoint;
  out AMap: array of TUnicodeCodepoint; out AMapLen: Byte): TIDNAMapStatus;

{ Apply UTS#46 Map step to a UTF-8 string (Nontransitional + STD3). }
function ApplyIdnaMap(const AText: string; out AKind: TIDNAErrorKind): string;

{ ToASCII / ToUnicode with structured kind. On failure Result='' and AKind<>idnaOk. }
function IDNAToASCII(const ADomain: string; out AKind: TIDNAErrorKind): string; overload;
function IDNAToUnicode(const ADomain: string; out AKind: TIDNAErrorKind): string; overload;

{ String error form (legacy). AError = IDNAErrorKindName(kind). }
function IDNAToASCII(const ADomain: string; out AError: string): string; overload;
function IDNAToUnicode(const ADomain: string; out AError: string): string; overload;

{ Convenience: empty error ignored. }
function IDNAToASCII(const ADomain: string): string; overload;
function IDNAToUnicode(const ADomain: string): string; overload;

implementation

uses
  nextpas.core.text.unicode.normalize,
  nextpas.core.text.unicode.punycode,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode.utils;

{$I nextpas.core.text.unicode.idna_mapping.inc}

function IDNAErrorKindName(const AKind: TIDNAErrorKind): string;
begin
  case AKind of
    idnaOk: Result := '';
    idnaEmptyDomain: Result := 'empty domain';
    idnaEmptyLabel: Result := 'empty label';
    idnaInvalidDomain: Result := 'invalid domain';
    idnaInvalidAsciiLabel: Result := 'invalid ASCII label';
    idnaNfcFailed: Result := 'NFC failed';
    idnaPunycodeEncodeFailed: Result := 'punycode encode failed';
    idnaPunycodeDecodeFailed: Result := 'punycode decode failed';
    idnaEmptyAceBody: Result := 'empty ACE body';
    idnaAceLabelTooLong: Result := 'ACE label too long';
    idnaDomainTooLong: Result := 'domain too long';
    idnaDisallowed: Result := 'disallowed code point';
    idnaInvalidUtf8: Result := 'invalid UTF-8';
  else
    Result := 'unknown IDNA error';
  end;
end;

function FindIdnaMapRange(const ACp: TUnicodeCodepoint): Integer;
var
  LLo, LHi, LMid: Integer;
begin
  LLo := 0;
  LHi := IDNA_MAP_RANGES_COUNT - 1;
  while LLo <= LHi do
  begin
    LMid := LLo + ((LHi - LLo) shr 1);
    if ACp < IDNA_MAP_RANGES[LMid].Lo then
      LHi := LMid - 1
    else if ACp > IDNA_MAP_RANGES[LMid].Hi then
      LLo := LMid + 1
    else
      Exit(LMid);
  end;
  Result := -1;
end;

function GetIdnaMapStatus(const ACp: TUnicodeCodepoint;
  out AMap: array of TUnicodeCodepoint; out AMapLen: Byte): TIDNAMapStatus;
var
  LIdx, I: Integer;
  LOff: UInt32;
begin
  AMapLen := 0;
  LIdx := FindIdnaMapRange(ACp);
  if LIdx < 0 then
    Exit(idmsDisallowed);
  Result := TIDNAMapStatus(IDNA_MAP_RANGES[LIdx].Status);
  AMapLen := IDNA_MAP_RANGES[LIdx].MapLen;
  if AMapLen = 0 then
    Exit;
  LOff := IDNA_MAP_RANGES[LIdx].MapOff;
  if AMapLen > Length(AMap) then
    AMapLen := Byte(Length(AMap));
  for I := 0 to Integer(AMapLen) - 1 do
    AMap[I] := IDNA_MAP_POOL[LOff + UInt32(I)];
end;

function AppendUtf8Cp(var ADst: string; const ACp: TUnicodeCodepoint): Boolean;
var
  LBuf: array[0..3] of Byte;
  LLen, LOld: Integer;
  I: Integer;
begin
  LLen := Integer(UTF8Encode(ACp, @LBuf[0]));
  if LLen = 0 then
    Exit(False);
  LOld := Length(ADst);
  SetLength(ADst, LOld + LLen);
  for I := 0 to LLen - 1 do
    ADst[LOld + 1 + I] := AnsiChar(LBuf[I]);
  Result := True;
end;

function ApplyIdnaMap(const AText: string; out AKind: TIDNAErrorKind): string;
var
  LPos, LLen: SizeUInt;
  LDec: TUTF8DecodeResult;
  LStatus: TIDNAMapStatus;
  LMap: array[0..31] of TUnicodeCodepoint;
  LMapLen: Byte;
  I: Integer;
  LCp: TUnicodeCodepoint;
begin
  AKind := idnaOk;
  Result := '';
  if AText = '' then
    Exit;
  LPos := 0;
  LLen := SizeUInt(Length(AText));
  while LPos < LLen do
  begin
    LDec := UTF8Decode(@PByte(PAnsiChar(AText))[LPos], LLen - LPos);
    if LDec.ByteLen = 0 then
    begin
      AKind := idnaInvalidUtf8;
      Result := '';
      Exit;
    end;
    LCp := LDec.CodePoint;
    LStatus := GetIdnaMapStatus(LCp, LMap, LMapLen);
    case LStatus of
      idmsValid:
        if not AppendUtf8Cp(Result, LCp) then
        begin
          AKind := idnaInvalidUtf8;
          Result := '';
          Exit;
        end;
      idmsIgnored:
        { drop };
      idmsMapped, idmsDeviation:
        begin
          { Nontransitional: use mapping (empty mapping ⇒ drop, e.g. ZWJ). }
          for I := 0 to Integer(LMapLen) - 1 do
            if not AppendUtf8Cp(Result, LMap[I]) then
            begin
              AKind := idnaInvalidUtf8;
              Result := '';
              Exit;
            end;
        end;
      idmsDisallowedSTD3Valid, idmsDisallowedSTD3Mapped:
        begin
          { UseSTD3ASCIIRules = True → treat as disallowed. }
          AKind := idnaDisallowed;
          Result := '';
          Exit;
        end;
    else
      { idmsDisallowed or unknown }
      begin
        AKind := idnaDisallowed;
        Result := '';
        Exit;
      end;
    end;
    Inc(LPos, LDec.ByteLen);
  end;
end;

function IsAsciiLabel(const ALabel: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to Length(ALabel) do
    if Ord(ALabel[I]) >= $80 then
      Exit(False);
  Result := True;
end;

function IsLDHLabel(const ALabel: string): Boolean;
var
  I: Integer;
  C: Char;
begin
  if (ALabel = '') or (Length(ALabel) > 63) then
    Exit(False);
  if (ALabel[1] = '-') or (ALabel[Length(ALabel)] = '-') then
    Exit(False);
  for I := 1 to Length(ALabel) do
  begin
    C := ALabel[I];
    if not (C in ['A'..'Z', 'a'..'z', '0'..'9', '-']) then
      Exit(False);
  end;
  Result := True;
end;

function LowerAscii(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if Result[I] in ['A'..'Z'] then
      Result[I] := Chr(Ord(Result[I]) + 32);
end;

function ProcessLabelToASCII(const ALabel: string; out AKind: TIDNAErrorKind): string;
var
  LMapped, LNorm, LPuny: string;
begin
  AKind := idnaOk;
  Result := '';
  if ALabel = '' then
  begin
    AKind := idnaEmptyLabel;
    Exit;
  end;
  LMapped := ApplyIdnaMap(ALabel, AKind);
  if AKind <> idnaOk then
    Exit;
  if LMapped = '' then
  begin
    { Entire label ignored (e.g. only soft hyphens) → empty label }
    AKind := idnaEmptyLabel;
    Exit;
  end;
  LNorm := NFC(LMapped);
  if LNorm = '' then
  begin
    AKind := idnaNfcFailed;
    Exit;
  end;
  if IsAsciiLabel(LNorm) then
  begin
    Result := LowerAscii(LNorm);
    if not IsLDHLabel(Result) then
    begin
      AKind := idnaInvalidAsciiLabel;
      Result := '';
    end;
    Exit;
  end;
  LPuny := PunycodeEncode(LNorm);
  if LPuny = '' then
  begin
    AKind := idnaPunycodeEncodeFailed;
    Exit;
  end;
  Result := IDNA_ACE_PREFIX + LowerAscii(LPuny);
  if Length(Result) > 63 then
  begin
    AKind := idnaAceLabelTooLong;
    Result := '';
  end;
end;

function ProcessLabelToUnicode(const ALabel: string; out AKind: TIDNAErrorKind): string;
var
  LMapped, LLower, LBody, LDecoded, LNorm: string;
begin
  AKind := idnaOk;
  Result := '';
  if ALabel = '' then
  begin
    AKind := idnaEmptyLabel;
    Exit;
  end;
  LMapped := ApplyIdnaMap(ALabel, AKind);
  if AKind <> idnaOk then
    Exit;
  if LMapped = '' then
  begin
    AKind := idnaEmptyLabel;
    Exit;
  end;
  LLower := LowerAscii(LMapped);
  if (Length(LLower) >= 4) and (Copy(LLower, 1, 4) = IDNA_ACE_PREFIX) then
  begin
    LBody := Copy(LLower, 5, Length(LLower));
    if LBody = '' then
    begin
      AKind := idnaEmptyAceBody;
      Exit;
    end;
    LDecoded := PunycodeDecode(LBody);
    if LDecoded = '' then
    begin
      AKind := idnaPunycodeDecodeFailed;
      Exit;
    end;
    Result := NFC(LDecoded);
    if Result = '' then
      AKind := idnaNfcFailed;
    Exit;
  end;
  LNorm := NFC(LMapped);
  if LNorm = '' then
  begin
    AKind := idnaNfcFailed;
    Exit;
  end;
  if IsAsciiLabel(LNorm) then
  begin
    if not IsLDHLabel(LowerAscii(LNorm)) then
    begin
      AKind := idnaInvalidAsciiLabel;
      Exit;
    end;
    Result := LowerAscii(LNorm);
    Exit;
  end;
  Result := LNorm;
end;

function SplitDomain(const ADomain: string; out ALabels: array of string;
  out ACount: Integer): Boolean;
var
  I, Start: Integer;
begin
  ACount := 0;
  Result := True;
  if ADomain = '' then
    Exit(False);
  Start := 1;
  for I := 1 to Length(ADomain) + 1 do
  begin
    if (I > Length(ADomain)) or (ADomain[I] = '.') then
    begin
      if I = Start then
      begin
        if I <= Length(ADomain) then
          Exit(False);
        Break;
      end;
      if ACount >= Length(ALabels) then
        Exit(False);
      ALabels[ACount] := Copy(ADomain, Start, I - Start);
      Inc(ACount);
      Start := I + 1;
    end;
  end;
  Result := ACount > 0;
end;

function JoinLabels(const ALabels: array of string; const ACount: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to ACount - 1 do
  begin
    if I > 0 then
      Result := Result + '.';
    Result := Result + ALabels[I];
  end;
end;

function IDNAToASCII(const ADomain: string; out AKind: TIDNAErrorKind): string;
var
  LLabels: array[0..127] of string;
  LOut: array[0..127] of string;
  LCount, I: Integer;
  LTotal: Integer;
begin
  AKind := idnaOk;
  Result := '';
  if ADomain = '' then
  begin
    AKind := idnaEmptyDomain;
    Exit;
  end;
  if not SplitDomain(ADomain, LLabels, LCount) then
  begin
    AKind := idnaInvalidDomain;
    Exit;
  end;
  LTotal := 0;
  for I := 0 to LCount - 1 do
  begin
    LOut[I] := ProcessLabelToASCII(LLabels[I], AKind);
    if AKind <> idnaOk then
    begin
      Result := '';
      Exit;
    end;
    Inc(LTotal, Length(LOut[I]));
    if I > 0 then
      Inc(LTotal);
  end;
  if LTotal > 253 then
  begin
    AKind := idnaDomainTooLong;
    Exit;
  end;
  Result := JoinLabels(LOut, LCount);
end;

function IDNAToUnicode(const ADomain: string; out AKind: TIDNAErrorKind): string;
var
  LLabels: array[0..127] of string;
  LOut: array[0..127] of string;
  LCount, I: Integer;
begin
  AKind := idnaOk;
  Result := '';
  if ADomain = '' then
  begin
    AKind := idnaEmptyDomain;
    Exit;
  end;
  if not SplitDomain(ADomain, LLabels, LCount) then
  begin
    AKind := idnaInvalidDomain;
    Exit;
  end;
  for I := 0 to LCount - 1 do
  begin
    LOut[I] := ProcessLabelToUnicode(LLabels[I], AKind);
    if AKind <> idnaOk then
    begin
      Result := '';
      Exit;
    end;
  end;
  Result := JoinLabels(LOut, LCount);
end;

function IDNAToASCII(const ADomain: string; out AError: string): string;
var
  LKind: TIDNAErrorKind;
begin
  Result := IDNAToASCII(ADomain, LKind);
  AError := IDNAErrorKindName(LKind);
end;

function IDNAToUnicode(const ADomain: string; out AError: string): string;
var
  LKind: TIDNAErrorKind;
begin
  Result := IDNAToUnicode(ADomain, LKind);
  AError := IDNAErrorKindName(LKind);
end;

function IDNAToASCII(const ADomain: string): string;
var
  LKind: TIDNAErrorKind;
begin
  Result := IDNAToASCII(ADomain, LKind);
end;

function IDNAToUnicode(const ADomain: string): string;
var
  LKind: TIDNAErrorKind;
begin
  Result := IDNAToUnicode(ADomain, LKind);
end;

end.
