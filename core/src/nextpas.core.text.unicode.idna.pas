unit nextpas.core.text.unicode.idna;

{**
 * UTS #46 IDNA (rev 33 / Unicode 16.0) — Nontransitional profile.
 *
 * Processing (§4): Map(full string) → NFC → Break('.') → Convert/Validate.
 * Validity Criteria (§4.1): NFC · CheckHyphens · no leading combining mark ·
 * per-codepoint status ∈ valid/deviation · ContextJ (RFC 5892 App A) ·
 * CheckBidi (RFC 5893 §2, when the domain is a Bidi domain name).
 *
 * Profile flags (fixed): UseSTD3ASCIIRules=True (enforced in validity per
 * 16.0), CheckHyphens/CheckBidi/CheckJoiners=True, Transitional=False,
 * IgnoreInvalidPunycode=False, VerifyDnsLength=True (ToASCII only; the empty
 * root label "a.b." is therefore a ToASCII error, but valid for ToUnicode).
 *
 * Deviation codepoints (ß, ς, ZWJ, ZWNJ) are kept as-is (Nontransitional).
 * ACE ("xn--") labels are Punycode-decoded and re-validated in both
 * directions; ToASCII re-encodes from the validated Unicode form.
 *
 * Error model: first error wins; Result = '' and AKind <> idnaOk (no
 * best-effort partial output). String overloads map via IDNAErrorKindName.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types;

const
  IDNA_ACE_PREFIX = 'xn--';

type
  { Stable IDNA failure codes. Success = idnaOk. Only append new members. }
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
    idnaInvalidUtf8,
    idnaNotNfc,
    idnaCheckHyphens,
    idnaLeadingCombiningMark,
    idnaInvalidAceLabel,
    idnaContextJ,
    idnaCheckBidi,
    idnaDisallowedSTD3
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

{ Apply UTS#46 §4 Map step to a UTF-8 string (Nontransitional).
  ignored → dropped; mapped/disallowed_STD3_mapped → mapping applied;
  valid/deviation/disallowed/disallowed_STD3_valid → kept unchanged
  (disallowed codepoints are rejected later by the validity criteria). }
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
  nextpas.core.text.unicode.props,
  nextpas.core.text.unicode.punycode,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode.utils;

{$I nextpas.core.text.unicode.idna_mapping.inc}

const
  UNICODE_ZWNJ = $200C;
  UNICODE_ZWJ = $200D;

type
  TCpArray = array of TUnicodeCodepoint;
  TLabelArray = array of string;

function IDNAErrorKindName(const AKind: TIDNAErrorKind): string;
begin
  Result := ''; { 防御非法强转 }
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
    idnaNotNfc: Result := 'label not NFC';
    idnaCheckHyphens: Result := 'CheckHyphens violation';
    idnaLeadingCombiningMark: Result := 'label begins with combining mark';
    idnaInvalidAceLabel: Result := 'invalid ACE label';
    idnaContextJ: Result := 'ContextJ violation';
    idnaCheckBidi: Result := 'CheckBidi violation';
    idnaDisallowedSTD3: Result := 'STD3 disallowed ASCII code point';
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
      idmsIgnored:
        { drop };
      idmsMapped, idmsDisallowedSTD3Mapped:
        for I := 0 to Integer(LMapLen) - 1 do
          if not AppendUtf8Cp(Result, LMap[I]) then
          begin
            AKind := idnaInvalidUtf8;
            Result := '';
            Exit;
          end;
    else
      { valid / deviation / disallowed / disallowed_STD3_valid: keep as-is.
        Disallowed codepoints are rejected by the validity criteria. }
      if not AppendUtf8Cp(Result, LCp) then
      begin
        AKind := idnaInvalidUtf8;
        Result := '';
        Exit;
      end;
    end;
    Inc(LPos, LDec.ByteLen);
  end;
end;

function DecodeCps(const S: string; out ACps: TCpArray): Boolean;
var
  LPos, LLen: SizeUInt;
  LDec: TUTF8DecodeResult;
  LCount: SizeInt;
begin
  SetLength(ACps, Length(S));
  LCount := 0;
  LPos := 0;
  LLen := SizeUInt(Length(S));
  while LPos < LLen do
  begin
    LDec := UTF8Decode(@PByte(PAnsiChar(S))[LPos], LLen - LPos);
    if LDec.ByteLen = 0 then
      Exit(False);
    ACps[LCount] := LDec.CodePoint;
    Inc(LCount);
    Inc(LPos, LDec.ByteLen);
  end;
  SetLength(ACps, LCount);
  Result := True;
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

function StartsWithAcePrefix(const ALabel: string): Boolean;
begin
  Result := (Length(ALabel) >= 4) and (ALabel[1] = 'x') and (ALabel[2] = 'n')
    and (ALabel[3] = '-') and (ALabel[4] = '-');
end;

{ UseSTD3ASCIIRules (tr46 rev 33): since 16.0 the STD3 restriction is a
  validity rule, not a table status — ASCII must be [-a-z0-9]. }
function IsStd3Ascii(const ACp: TUnicodeCodepoint): Boolean; inline;
begin
  Result := ((ACp >= Ord('a')) and (ACp <= Ord('z')))
    or ((ACp >= Ord('0')) and (ACp <= Ord('9')))
    or (ACp = Ord('-'));
end;

{ ContextJ — RFC 5892 Appendix A.1 (ZWNJ) / A.2 (ZWJ). Virama ccc = 9. }
function CheckContextJ(const ACps: TCpArray; const AIdx: SizeInt): Boolean;
var
  J: SizeInt;
  LJt: TJoiningType;
begin
  if (AIdx > 0) and (GetCanonicalCombiningClass(ACps[AIdx - 1]) = 9) then
    Exit(True);
  if ACps[AIdx] = UNICODE_ZWJ then
    Exit(False);
  (* ZWNJ: (Joining_Type:{L,D})(T)* ZWNJ (T)*(Joining_Type:{R,D}) *)
  J := AIdx - 1;
  while (J >= 0) and (GetJoiningType(ACps[J]) = jtTransparent) do
    Dec(J);
  if J < 0 then
    Exit(False);
  LJt := GetJoiningType(ACps[J]);
  if not (LJt in [jtLeftJoining, jtDualJoining]) then
    Exit(False);
  J := AIdx + 1;
  while (J <= High(ACps)) and (GetJoiningType(ACps[J]) = jtTransparent) do
    Inc(J);
  if J > High(ACps) then
    Exit(False);
  LJt := GetJoiningType(ACps[J]);
  Result := LJt in [jtRightJoining, jtDualJoining];
end;

{ UTS#46 §4.1 Validity Criteria for one Unicode label (Nontransitional,
  UseSTD3ASCIIRules=True, CheckHyphens=True, CheckJoiners=True).
  CheckBidi is domain-level and handled separately. }
function ValidateULabel(const ALabel: string; out AKind: TIDNAErrorKind): Boolean;
var
  LCps: TCpArray;
  LMap: array[0..0] of TUnicodeCodepoint;
  LMapLen: Byte;
  LStatus: TIDNAMapStatus;
  I: SizeInt;
begin
  Result := False;
  if not DecodeCps(ALabel, LCps) then
  begin
    AKind := idnaInvalidUtf8;
    Exit;
  end;
  if not IsNormalizedNFC(ALabel) then
  begin
    AKind := idnaNotNfc;
    Exit;
  end;
  if (Length(LCps) >= 4) and (LCps[2] = Ord('-')) and (LCps[3] = Ord('-')) then
  begin
    AKind := idnaCheckHyphens;
    Exit;
  end;
  if (LCps[0] = Ord('-')) or (LCps[High(LCps)] = Ord('-')) then
  begin
    AKind := idnaCheckHyphens;
    Exit;
  end;
  if IsMark(LCps[0]) then
  begin
    AKind := idnaLeadingCombiningMark;
    Exit;
  end;
  for I := 0 to High(LCps) do
  begin
    LStatus := GetIdnaMapStatus(LCps[I], LMap, LMapLen);
    if not (LStatus in [idmsValid, idmsDeviation]) then
    begin
      AKind := idnaDisallowed;
      Exit;
    end;
    if (LCps[I] < $80) and (not IsStd3Ascii(LCps[I])) then
    begin
      AKind := idnaDisallowedSTD3;
      Exit;
    end;
    if ((LCps[I] = UNICODE_ZWNJ) or (LCps[I] = UNICODE_ZWJ))
      and (not CheckContextJ(LCps, I)) then
    begin
      AKind := idnaContextJ;
      Exit;
    end;
  end;
  AKind := idnaOk;
  Result := True;
end;

{ RFC 5893 §2 rules 1–6 for one label. Assumes ALabelCps non-empty. }
function CheckBidiLabel(const ACps: TCpArray): Boolean;
const
  LTR_ALLOWED = [bcL, bcEN, bcES, bcCS, bcET, bcON, bcBN, bcNSM];
  RTL_ALLOWED = [bcR, bcAL, bcAN, bcEN, bcES, bcCS, bcET, bcON, bcBN, bcNSM];
var
  LFirst, LBc: TBidiClass;
  LRtl: Boolean;
  LHasEN, LHasAN: Boolean;
  I: SizeInt;
begin
  Result := False;
  LFirst := GetBidiClass(ACps[0]);
  case LFirst of
    bcL: LRtl := False;
    bcR, bcAL: LRtl := True;
  else
    Exit; { rule 1 }
  end;
  LHasEN := False;
  LHasAN := False;
  for I := 0 to High(ACps) do
  begin
    LBc := GetBidiClass(ACps[I]);
    if LRtl then
    begin
      if not (LBc in RTL_ALLOWED) then
        Exit; { rule 2 }
      if LBc = bcEN then
        LHasEN := True
      else if LBc = bcAN then
        LHasAN := True;
    end
    else if not (LBc in LTR_ALLOWED) then
      Exit; { rule 5 }
  end;
  if LRtl and LHasEN and LHasAN then
    Exit; { rule 4 }
  I := High(ACps);
  while (I > 0) and (GetBidiClass(ACps[I]) = bcNSM) do
    Dec(I);
  LBc := GetBidiClass(ACps[I]);
  if LRtl then
  begin
    if not (LBc in [bcR, bcAL, bcEN, bcAN]) then
      Exit; { rule 3 }
  end
  else if not (LBc in [bcL, bcEN]) then
    Exit; { rule 6 }
  Result := True;
end;

{ CheckBidi: RFC 5893 applies to every label iff the domain is a Bidi
  domain name (any label contains an R, AL, or AN codepoint). }
function CheckBidiDomain(const ALabels: TLabelArray;
  out AKind: TIDNAErrorKind): Boolean;
var
  LCpsPerLabel: array of TCpArray;
  LBidiDomain: Boolean;
  I: SizeInt;
  J: SizeInt;
begin
  Result := False;
  AKind := idnaOk;
  SetLength(LCpsPerLabel, Length(ALabels));
  LBidiDomain := False;
  for I := 0 to High(ALabels) do
  begin
    if not DecodeCps(ALabels[I], LCpsPerLabel[I]) then
    begin
      AKind := idnaInvalidUtf8;
      Exit;
    end;
    for J := 0 to High(LCpsPerLabel[I]) do
      if GetBidiClass(LCpsPerLabel[I][J]) in [bcR, bcAL, bcAN] then
      begin
        LBidiDomain := True;
        Break;
      end;
  end;
  if LBidiDomain then
    for I := 0 to High(LCpsPerLabel) do
      if (Length(LCpsPerLabel[I]) > 0) and (not CheckBidiLabel(LCpsPerLabel[I])) then
      begin
        AKind := idnaCheckBidi;
        Exit;
      end;
  Result := True;
end;

{ Split at U+002E. Always emits empty labels ("a..b" → 'a','','b';
  "a.b." → 'a','b',''). }
procedure SplitLabels(const ADomain: string; out ALabels: TLabelArray);
var
  I, LStart, LCount: SizeInt;
begin
  LCount := 1;
  for I := 1 to Length(ADomain) do
    if ADomain[I] = '.' then
      Inc(LCount);
  SetLength(ALabels, LCount);
  LCount := 0;
  LStart := 1;
  for I := 1 to Length(ADomain) + 1 do
    if (I > Length(ADomain)) or (ADomain[I] = '.') then
    begin
      ALabels[LCount] := Copy(ADomain, LStart, I - LStart);
      Inc(LCount);
      LStart := I + 1;
    end;
end;

{ UTS#46 §4 Processing: Map → NFC → Break → Convert/Validate (+ CheckBidi).
  On success ALabels holds the Unicode form of every non-root label and
  ARootDot tells whether the input carried a trailing empty root label. }
function ProcessDomain(const ADomain: string; out ALabels: TLabelArray;
  out ARootDot: Boolean; out AKind: TIDNAErrorKind): Boolean;
var
  LMapped, LNorm, LBody, LDecoded: string;
  LRaw: TLabelArray;
  LBuf: TCpArray;
  LCount: SizeInt;
  I, J: SizeInt;
begin
  Result := False;
  ARootDot := False;
  SetLength(ALabels, 0);
  if ADomain = '' then
  begin
    AKind := idnaEmptyDomain;
    Exit;
  end;
  LMapped := ApplyIdnaMap(ADomain, AKind);
  if AKind <> idnaOk then
    Exit;
  LNorm := NFC(LMapped);
  if (LNorm = '') and (LMapped <> '') then
  begin
    AKind := idnaNfcFailed;
    Exit;
  end;
  SplitLabels(LNorm, LRaw);
  if (Length(LRaw) > 1) and (LRaw[High(LRaw)] = '') then
  begin
    ARootDot := True;
    SetLength(LRaw, Length(LRaw) - 1);
  end;
  for I := 0 to High(LRaw) do
    if LRaw[I] = '' then
    begin
      if Length(LRaw) = 1 then
        AKind := idnaEmptyDomain
      else
        AKind := idnaEmptyLabel;
      Exit;
    end;
  SetLength(ALabels, Length(LRaw));
  for I := 0 to High(LRaw) do
  begin
    if StartsWithAcePrefix(LRaw[I]) then
    begin
      if not IsAsciiLabel(LRaw[I]) then
      begin
        AKind := idnaInvalidAceLabel;
        Exit;
      end;
      LBody := Copy(LRaw[I], 5, Length(LRaw[I]));
      if LBody = '' then
      begin
        AKind := idnaEmptyAceBody;
        Exit;
      end;
      SetLength(LBuf, Length(LBody));
      if not PunycodeDecodeToCodepoints(LBody, LBuf, LCount) then
      begin
        AKind := idnaPunycodeDecodeFailed;
        Exit;
      end;
      LDecoded := '';
      for J := 0 to LCount - 1 do
        if not AppendUtf8Cp(LDecoded, LBuf[J]) then
        begin
          AKind := idnaPunycodeDecodeFailed;
          Exit;
        end;
      { Decoded ACE must be a real U-label: non-empty and not all-ASCII. }
      if (LDecoded = '') or IsAsciiLabel(LDecoded) then
      begin
        AKind := idnaInvalidAceLabel;
        Exit;
      end;
      if not ValidateULabel(LDecoded, AKind) then
        Exit;
      ALabels[I] := LDecoded;
    end
    else
    begin
      if not ValidateULabel(LRaw[I], AKind) then
        Exit;
      ALabels[I] := LRaw[I];
    end;
  end;
  if not CheckBidiDomain(ALabels, AKind) then
    Exit;
  AKind := idnaOk;
  Result := True;
end;

function JoinLabels(const ALabels: TLabelArray; const ARootDot: Boolean): string;
var
  I: SizeInt;
begin
  Result := '';
  for I := 0 to High(ALabels) do
  begin
    if I > 0 then
      Result := Result + '.';
    Result := Result + ALabels[I];
  end;
  if ARootDot then
    Result := Result + '.';
end;

function IDNAToASCII(const ADomain: string; out AKind: TIDNAErrorKind): string;
var
  LLabels: TLabelArray;
  LOut: TLabelArray;
  LRootDot: Boolean;
  LPuny: string;
  LTotal: SizeInt;
  I: SizeInt;
begin
  Result := '';
  if not ProcessDomain(ADomain, LLabels, LRootDot, AKind) then
    Exit;
  { VerifyDnsLength=True: the empty root label is disallowed. }
  if LRootDot then
  begin
    AKind := idnaEmptyLabel;
    Exit;
  end;
  SetLength(LOut, Length(LLabels));
  LTotal := 0;
  for I := 0 to High(LLabels) do
  begin
    if IsAsciiLabel(LLabels[I]) then
      LOut[I] := LLabels[I]
    else
    begin
      LPuny := PunycodeEncode(LLabels[I]);
      if LPuny = '' then
      begin
        AKind := idnaPunycodeEncodeFailed;
        Exit;
      end;
      LOut[I] := IDNA_ACE_PREFIX + LPuny;
    end;
    if Length(LOut[I]) > 63 then
    begin
      AKind := idnaAceLabelTooLong;
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
  Result := JoinLabels(LOut, False);
end;

function IDNAToUnicode(const ADomain: string; out AKind: TIDNAErrorKind): string;
var
  LLabels: TLabelArray;
  LRootDot: Boolean;
begin
  Result := '';
  if not ProcessDomain(ADomain, LLabels, LRootDot, AKind) then
    Exit;
  Result := JoinLabels(LLabels, LRootDot);
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
