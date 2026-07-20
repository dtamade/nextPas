unit nextpas.core.text.unicode.idna;

{**
 * UTS #46 IDNA — pragmatic Nontransitional profile for domain labels.
 * Pipeline: split labels · NFC · LDH/Punycode · length checks.
 * Full IdnaMappingTable transitional mapping is out of scope (documented).
 *
 * Errors: TIDNAErrorKind is the structured code; string overloads map via
 * IDNAErrorKindName for legacy call sites.
 *}

{$I nextpas.core.settings.inc}

interface

const
  IDNA_ACE_PREFIX = 'xn--';

type
  { Stable IDNA failure codes (P3-0). Success = idnaOk. }
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
    idnaDomainTooLong
  );

function IDNAErrorKindName(const AKind: TIDNAErrorKind): string;

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
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode.normalize,
  nextpas.core.text.unicode.punycode,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode.utils;

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
  else
    Result := 'unknown IDNA error';
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
  LNorm, LPuny: string;
begin
  AKind := idnaOk;
  Result := '';
  if ALabel = '' then
  begin
    AKind := idnaEmptyLabel;
    Exit;
  end;
  if IsAsciiLabel(ALabel) then
  begin
    Result := LowerAscii(ALabel);
    if not IsLDHLabel(Result) then
    begin
      AKind := idnaInvalidAsciiLabel;
      Result := '';
    end;
    Exit;
  end;
  LNorm := NFC(ALabel);
  if LNorm = '' then
  begin
    AKind := idnaNfcFailed;
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
  LLower, LBody, LDecoded: string;
begin
  AKind := idnaOk;
  Result := '';
  if ALabel = '' then
  begin
    AKind := idnaEmptyLabel;
    Exit;
  end;
  LLower := LowerAscii(ALabel);
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
  if not IsAsciiLabel(LLower) then
  begin
    { Already Unicode label }
    Result := NFC(LLower);
    if Result = '' then
      AKind := idnaNfcFailed;
    Exit;
  end;
  if not IsLDHLabel(LLower) then
  begin
    AKind := idnaInvalidAsciiLabel;
    Exit;
  end;
  Result := LLower;
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
        { empty label: allow trailing dot only as final }
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
      Inc(LTotal); { dot }
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
