unit nextpas.core.text.compare;

{$I nextpas.core.settings.inc}

interface

function TextCompare(const A, B: string): Integer;
function TextCompareI(const A, B: string): Integer;
function TextEqual(const A, B: string): Boolean; inline;
function TextEqualI(const A, B: string): Boolean; inline;
function TextEqualCanonical(const A, B: string): Boolean;
function TextEqualCaseFold(const A, B: string): Boolean;
function TextStartsWith(const AStr, APrefix: string): Boolean;
function TextStartsWithI(const AStr, APrefix: string): Boolean;
function TextEndsWith(const AStr, ASuffix: string): Boolean;
function TextEndsWithI(const AStr, ASuffix: string): Boolean;
function TextContains(const AStr, ASub: string): Boolean;
function TextContainsI(const AStr, ASub: string): Boolean;

implementation

uses
  nextpas.core.text.char,
  nextpas.core.text.unicode.&case,
  nextpas.core.text.unicode.normalize,
  nextpas.core.text.unicode.utils;

function TextCompareAsciiI(const A, B: string): Integer;
var
  I, LenA, LenB, MinLen: SizeInt;
  CA, CB: Byte;
begin
  LenA := Length(A);
  LenB := Length(B);
  if LenA < LenB then MinLen := LenA else MinLen := LenB;
  for I := 1 to MinLen do
  begin
    CA := ToLower(Byte(A[I]));
    CB := ToLower(Byte(B[I]));
    if CA < CB then Exit(-1);
    if CA > CB then Exit(1);
  end;
  if LenA < LenB then Result := -1
  else if LenA > LenB then Result := 1
  else Result := 0;
end;

function IsAsciiPair(const A, B: string): Boolean; inline;
begin
  Result := IsAsciiString(A) and IsAsciiString(B);
end;

function PrefixEqualsAsciiI(const AStr, APrefix: string): Boolean;
var
  I: SizeInt;
begin
  if Length(APrefix) > Length(AStr) then
    Exit(False);
  for I := 1 to Length(APrefix) do
    if ToLower(Byte(AStr[I])) <> ToLower(Byte(APrefix[I])) then
      Exit(False);
  Result := True;
end;

function SuffixEqualsAsciiI(const AStr, ASuffix: string): Boolean;
var
  I, Offset: SizeInt;
begin
  if Length(ASuffix) > Length(AStr) then
    Exit(False);
  Offset := Length(AStr) - Length(ASuffix);
  for I := 1 to Length(ASuffix) do
    if ToLower(Byte(AStr[Offset + I])) <> ToLower(Byte(ASuffix[I])) then
      Exit(False);
  Result := True;
end;

function ContainsAsciiI(const AStr, ASub: string): Boolean;
var
  I, J, LenStr, LenSub: SizeInt;
  LFoldedSub: string;
  Match: Boolean;
begin
  LenStr := Length(AStr);
  LenSub := Length(ASub);
  if LenSub = 0 then
    Exit(True);
  if LenSub > LenStr then
    Exit(False);
  SetLength(LFoldedSub, LenSub);
  for J := 1 to LenSub do
    LFoldedSub[J] := AnsiChar(ToLower(Byte(ASub[J])));
  for I := 1 to LenStr - LenSub + 1 do
  begin
    Match := True;
    for J := 1 to LenSub do
      if ToLower(Byte(AStr[I + J - 1])) <> Byte(LFoldedSub[J]) then
      begin
        Match := False;
        Break;
      end;
    if Match then
      Exit(True);
  end;
  Result := False;
end;

function TextCompare(const A, B: string): Integer;
var
  I, LenA, LenB, MinLen: SizeInt;
begin
  LenA := Length(A);
  LenB := Length(B);
  if LenA < LenB then MinLen := LenA else MinLen := LenB;
  for I := 1 to MinLen do
  begin
    if Byte(A[I]) < Byte(B[I]) then Exit(-1);
    if Byte(A[I]) > Byte(B[I]) then Exit(1);
  end;
  if LenA < LenB then Result := -1
  else if LenA > LenB then Result := 1
  else Result := 0;
end;

function TextCompareI(const A, B: string): Integer;
begin
  if A = B then
    Exit(0);

  if IsAsciiPair(A, B) then
    Exit(TextCompareAsciiI(A, B));

  Result := TextCompare(UTF8CaseFoldSimple(A), UTF8CaseFoldSimple(B));
end;

function TextEqual(const A, B: string): Boolean;
begin
  Result := A = B;
end;

function TextEqualI(const A, B: string): Boolean;
begin
  if A = B then
    Exit(True);

  if IsAsciiPair(A, B) then
    Exit(TextCompareAsciiI(A, B) = 0);

  Result := UTF8CaseFoldSimple(A) = UTF8CaseFoldSimple(B);
end;

function TextEqualCanonical(const A, B: string): Boolean;
begin
  if A = B then
    Exit(True);

  if IsAsciiPair(A, B) then
    Exit(False);

  Result := NFC(A) = NFC(B);
end;

function TextEqualCaseFold(const A, B: string): Boolean;
begin
  if A = B then
    Exit(True);

  if IsAsciiPair(A, B) then
    Exit(TextCompareAsciiI(A, B) = 0);

  Result := UTF8CaseFold(NFD(A)) = UTF8CaseFold(NFD(B));
end;

function TextStartsWith(const AStr, APrefix: string): Boolean;
var I: SizeInt;
begin
  if Length(APrefix) > Length(AStr) then Exit(False);
  for I := 1 to Length(APrefix) do
    if AStr[I] <> APrefix[I] then Exit(False);
  Result := True;
end;

function TextStartsWithI(const AStr, APrefix: string): Boolean;
var
  LFoldedStr: string;
  LFoldedPrefix: string;
begin
  if IsAsciiPair(AStr, APrefix) then
    Exit(PrefixEqualsAsciiI(AStr, APrefix));

  LFoldedStr := UTF8CaseFoldSimple(AStr);
  LFoldedPrefix := UTF8CaseFoldSimple(APrefix);
  Result := TextStartsWith(LFoldedStr, LFoldedPrefix);
end;

function TextEndsWith(const AStr, ASuffix: string): Boolean;
var I, Offset: SizeInt;
begin
  if Length(ASuffix) > Length(AStr) then Exit(False);
  Offset := Length(AStr) - Length(ASuffix);
  for I := 1 to Length(ASuffix) do
    if AStr[Offset + I] <> ASuffix[I] then Exit(False);
  Result := True;
end;

function TextEndsWithI(const AStr, ASuffix: string): Boolean;
var
  LFoldedStr: string;
  LFoldedSuffix: string;
begin
  if IsAsciiPair(AStr, ASuffix) then
    Exit(SuffixEqualsAsciiI(AStr, ASuffix));

  LFoldedStr := UTF8CaseFoldSimple(AStr);
  LFoldedSuffix := UTF8CaseFoldSimple(ASuffix);
  Result := TextEndsWith(LFoldedStr, LFoldedSuffix);
end;

function TextContains(const AStr, ASub: string): Boolean;
begin
  if ASub = '' then
    Exit(True);
  Result := Pos(ASub, AStr) > 0;
end;

function TextContainsI(const AStr, ASub: string): Boolean;
var
  LFoldedStr: string;
  LFoldedSub: string;
begin
  if IsAsciiPair(AStr, ASub) then
    Exit(ContainsAsciiI(AStr, ASub));

  LFoldedStr := UTF8CaseFoldSimple(AStr);
  LFoldedSub := UTF8CaseFoldSimple(ASub);
  Result := TextContains(LFoldedStr, LFoldedSub);
end;

end.
