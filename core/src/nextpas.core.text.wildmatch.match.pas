unit nextpas.core.text.wildmatch.match;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.wildmatch.base;

{ Double-pointer backtrack: '*' matches any sequence, '?' matches single char.
  L0: only base/System, zero-copy via PAnsiChar+Len, inline hot path. }

function WildMatch(const APattern, AValue: string): Boolean; inline; overload;
function WildMatch(APattern: PAnsiChar; APatternLen: SizeUInt; AValue: PAnsiChar; AValueLen: SizeUInt): Boolean; inline; overload;
function TextWildMatch(const APattern, AValue: string): Boolean; inline;

implementation

function WildMatch(APattern: PAnsiChar; APatternLen: SizeUInt; AValue: PAnsiChar; AValueLen: SizeUInt): Boolean; inline;
var
  P, V, StarP, StarV: SizeInt;
begin
  { empty vs empty: true; empty pattern vs non-empty: false }
  if (APatternLen = 0) then
    Exit(AValueLen = 0);
  if (AValueLen = 0) then
  begin
    { value empty: pattern must be all '*' }
    for P := 0 to SizeInt(APatternLen) - 1 do
      if APattern[P] <> '*' then
        Exit(False);
    Exit(True);
  end;
  { both non-empty: ensure pointers non-nil; caller passes nil for len=0 already handled }
  P := 0;
  V := 0;
  StarP := -1;
  StarV := 0;
  while V < SizeInt(AValueLen) do
  begin
    if (P < SizeInt(APatternLen)) and ((APattern[P] = '?') or (APattern[P] = AValue[V])) then
    begin
      Inc(P);
      Inc(V);
    end
    else if (P < SizeInt(APatternLen)) and (APattern[P] = '*') then
    begin
      StarP := P;
      StarV := V;
      Inc(P);
    end
    else if StarP >= 0 then
    begin
      P := StarP + 1;
      Inc(StarV);
      V := StarV;
    end
    else
      Exit(False);
  end;
  while (P < SizeInt(APatternLen)) and (APattern[P] = '*') do
    Inc(P);
  Result := P >= SizeInt(APatternLen);
end;

function WildMatch(const APattern, AValue: string): Boolean; inline;
var
  LP: PAnsiChar;
  LV: PAnsiChar;
begin
  if APattern = '' then
    Exit(AValue = '');
  if AValue = '' then
  begin
    { delegate to pointer version for all-'*' check }
    Result := WildMatch(PAnsiChar(APattern), SizeUInt(Length(APattern)), nil, 0);
    Exit;
  end;
  LP := PAnsiChar(APattern);
  LV := PAnsiChar(AValue);
  Result := WildMatch(LP, SizeUInt(Length(APattern)), LV, SizeUInt(Length(AValue)));
end;

function TextWildMatch(const APattern, AValue: string): Boolean; inline;
begin
  Result := WildMatch(APattern, AValue);
end;

end.
