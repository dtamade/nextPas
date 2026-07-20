unit nextpas.core.text.unicode.idna;

{**
 * UTS #46 IDNA — pragmatic Nontransitional profile for domain labels.
 * Pipeline: split labels · NFC · LDH/Punycode · length checks.
 * Full IdnaMappingTable transitional mapping is out of scope (documented).
 *}

{$I nextpas.core.settings.inc}

interface

const
  IDNA_ACE_PREFIX = 'xn--';

{ ToASCII / ToUnicode. On failure Result='' and AError is set. }
function IDNAToASCII(const ADomain: string; out AError: string): string;
function IDNAToUnicode(const ADomain: string; out AError: string): string;

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

function ProcessLabelToASCII(const ALabel: string; out AError: string): string;
var
  LNorm, LPuny: string;
begin
  AError := '';
  Result := '';
  if ALabel = '' then
  begin
    AError := 'empty label';
    Exit;
  end;
  if IsAsciiLabel(ALabel) then
  begin
    Result := LowerAscii(ALabel);
    if not IsLDHLabel(Result) then
    begin
      AError := 'invalid ASCII label';
      Result := '';
    end;
    Exit;
  end;
  LNorm := NFC(ALabel);
  if LNorm = '' then
  begin
    AError := 'NFC failed';
    Exit;
  end;
  LPuny := PunycodeEncode(LNorm);
  if LPuny = '' then
  begin
    AError := 'punycode encode failed';
    Exit;
  end;
  Result := IDNA_ACE_PREFIX + LowerAscii(LPuny);
  if Length(Result) > 63 then
  begin
    AError := 'ACE label too long';
    Result := '';
  end;
end;

function ProcessLabelToUnicode(const ALabel: string; out AError: string): string;
var
  LLower, LBody, LDecoded: string;
begin
  AError := '';
  Result := '';
  if ALabel = '' then
  begin
    AError := 'empty label';
    Exit;
  end;
  LLower := LowerAscii(ALabel);
  if (Length(LLower) >= 4) and (Copy(LLower, 1, 4) = IDNA_ACE_PREFIX) then
  begin
    LBody := Copy(LLower, 5, Length(LLower));
    if LBody = '' then
    begin
      AError := 'empty ACE body';
      Exit;
    end;
    LDecoded := PunycodeDecode(LBody);
    if LDecoded = '' then
    begin
      AError := 'punycode decode failed';
      Exit;
    end;
    Result := NFC(LDecoded);
    if Result = '' then
      AError := 'NFC failed after decode';
    Exit;
  end;
  if not IsAsciiLabel(LLower) then
  begin
    { Already Unicode label }
    Result := NFC(LLower);
    Exit;
  end;
  if not IsLDHLabel(LLower) then
  begin
    AError := 'invalid ASCII label';
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

function IDNAToASCII(const ADomain: string; out AError: string): string;
var
  LLabels: array[0..127] of string;
  LOut: array[0..127] of string;
  LCount, I: Integer;
  LTotal: Integer;
begin
  AError := '';
  Result := '';
  if not SplitDomain(ADomain, LLabels, LCount) then
  begin
    AError := 'invalid domain';
    Exit;
  end;
  LTotal := 0;
  for I := 0 to LCount - 1 do
  begin
    LOut[I] := ProcessLabelToASCII(LLabels[I], AError);
    if AError <> '' then
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
    AError := 'domain too long';
    Exit;
  end;
  Result := JoinLabels(LOut, LCount);
end;

function IDNAToUnicode(const ADomain: string; out AError: string): string;
var
  LLabels: array[0..127] of string;
  LOut: array[0..127] of string;
  LCount, I: Integer;
begin
  AError := '';
  Result := '';
  if not SplitDomain(ADomain, LLabels, LCount) then
  begin
    AError := 'invalid domain';
    Exit;
  end;
  for I := 0 to LCount - 1 do
  begin
    LOut[I] := ProcessLabelToUnicode(LLabels[I], AError);
    if AError <> '' then
    begin
      Result := '';
      Exit;
    end;
  end;
  Result := JoinLabels(LOut, LCount);
end;

function IDNAToASCII(const ADomain: string): string;
var
  E: string;
begin
  Result := IDNAToASCII(ADomain, E);
end;

function IDNAToUnicode(const ADomain: string): string;
var
  E: string;
begin
  Result := IDNAToUnicode(ADomain, E);
end;

end.
