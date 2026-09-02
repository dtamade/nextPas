unit nextpas.core.text.wildmatch;

{$I nextpas.core.settings.inc}

{ Facade: pure re-export for L0 wildmatch.
  base <- match <- facade. }

interface

uses
  nextpas.core.base,
  nextpas.core.text.wildmatch.base,
  nextpas.core.text.wildmatch.match;

function WildMatch(const APattern, AValue: string): Boolean; inline; overload;
function WildMatch(APattern: PAnsiChar; APatternLen: SizeUInt; AValue: PAnsiChar; AValueLen: SizeUInt): Boolean; inline; overload;
function TextWildMatch(const APattern, AValue: string): Boolean; inline;

implementation

function WildMatch(const APattern, AValue: string): Boolean; inline;
begin
  Result := nextpas.core.text.wildmatch.match.WildMatch(APattern, AValue);
end;

function WildMatch(APattern: PAnsiChar; APatternLen: SizeUInt; AValue: PAnsiChar; AValueLen: SizeUInt): Boolean; inline;
begin
  Result := nextpas.core.text.wildmatch.match.WildMatch(APattern, APatternLen, AValue, AValueLen);
end;

function TextWildMatch(const APattern, AValue: string): Boolean; inline;
begin
  Result := nextpas.core.text.wildmatch.match.TextWildMatch(APattern, AValue);
end;

end.
