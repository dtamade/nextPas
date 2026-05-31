unit nextpas.core.text.utils;

{$I nextpas.core.settings.inc}

interface

function Trim(const S: string): string;
function TrimLeft(const S: string): string;
function TrimRight(const S: string): string;
function UpperCase(const S: string): string;
function StrToIntDef(const S: string; ADefault: Int64): Int64;
function BoolToStr(AValue: Boolean; const ATrueStr: string = 'True'; const AFalseStr: string = 'False'): string;
function StringReplace(const S, OldPattern, NewPattern: string; AReplaceAll: Boolean = True): string;
function QuotedStr(const S: string): string;

implementation

uses
  nextpas.core.text.char,
  nextpas.core.text.conv;

function Trim(const S: string): string;
var
  L, R: SizeInt;
begin
  L := 1;
  R := Length(S);
  while (L <= R) and (S[L] <= ' ') do Inc(L);
  while (R >= L) and (S[R] <= ' ') do Dec(R);
  Result := Copy(S, L, R - L + 1);
end;

function TrimLeft(const S: string): string;
var
  L: SizeInt;
begin
  L := 1;
  while (L <= Length(S)) and (S[L] <= ' ') do Inc(L);
  Result := Copy(S, L, Length(S) - L + 1);
end;

function TrimRight(const S: string): string;
var
  R: SizeInt;
begin
  R := Length(S);
  while (R >= 1) and (S[R] <= ' ') do Dec(R);
  Result := Copy(S, 1, R);
end;

function UpperCase(const S: string): string;
var
  I: SizeInt;
begin
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I] := Chr(ToUpper(Byte(S[I])));
end;

function StrToIntDef(const S: string; ADefault: Int64): Int64;
var
  V: Int64;
begin
  if TryStrToInt(S, V) then
    Result := V
  else
    Result := ADefault;
end;

function BoolToStr(AValue: Boolean; const ATrueStr: string; const AFalseStr: string): string;
begin
  if AValue then Result := ATrueStr else Result := AFalseStr;
end;

function StringReplace(const S, OldPattern, NewPattern: string; AReplaceAll: Boolean = True): string;
var
  P, Start: SizeInt;
begin
  Result := '';
  Start := 1;
  repeat
    P := Pos(OldPattern, S, Start);
    if P = 0 then
    begin
      Result := Result + Copy(S, Start, Length(S) - Start + 1);
      Break;
    end;
    Result := Result + Copy(S, Start, P - Start) + NewPattern;
    Start := P + Length(OldPattern);
    if not AReplaceAll then
    begin
      Result := Result + Copy(S, Start, Length(S) - Start + 1);
      Break;
    end;
  until False;
end;

function QuotedStr(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''''') + '''';
end;

end.
