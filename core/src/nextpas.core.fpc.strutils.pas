unit nextpas.core.fpc.strutils;

{$I nextpas.core.settings.inc}

interface

function PosEx(const SubStr, S: string; Offset: Integer = 1): Integer;
function LeftStr(const S: string; Count: Integer): string;
function RightStr(const S: string; Count: Integer): string;
function MidStr(const S: string; Start, Count: Integer): string;
function DupeString(const S: string; Count: Integer): string;
function ReverseString(const S: string): string;
function StartsStr(const ASubStr, AStr: string): Boolean;
function EndsStr(const ASubStr, AStr: string): Boolean;
function ContainsStr(const AStr, ASubStr: string): Boolean;
function StartsText(const ASubStr, AStr: string): Boolean;
function EndsText(const ASubStr, AStr: string): Boolean;
function ContainsText(const AStr, ASubStr: string): Boolean;
function ReplaceStr(const S, OldPattern, NewPattern: string): string;
function ReplaceText(const S, OldPattern, NewPattern: string): string;
function SplitString(const S, Delimiters: string): specialize TArray<string>;
function IndexStr(const S: string; const Values: array of string): Integer;
function IndexText(const S: string; const Values: array of string): Integer;
function IfThen(ACondition: Boolean; const ATrue: string; const AFalse: string = ''): string; inline;
function StuffString(const S: string; Index, Count: Integer; const SubStr: string): string;
function RandomFrom(const Values: array of string): string;
function NaturalCompareText(const S1, S2: string): Integer;

implementation

uses
  nextpas.core.fpc.sysutils;

function PosEx(const SubStr, S: string; Offset: Integer = 1): Integer;
var
  I, J, LSubLen, LSLen: Integer;
begin
  LSubLen := Length(SubStr);
  LSLen := Length(S);
  if (LSubLen = 0) or (Offset < 1) or (Offset + LSubLen - 1 > LSLen) then
    Exit(0);
  for I := Offset to LSLen - LSubLen + 1 do
  begin
    Result := I;
    for J := 1 to LSubLen do
      if S[I + J - 1] <> SubStr[J] then
      begin
        Result := 0;
        Break;
      end;
    if Result <> 0 then Exit;
  end;
  Result := 0;
end;

function LeftStr(const S: string; Count: Integer): string;
begin
  if Count >= Length(S) then Result := S
  else Result := Copy(S, 1, Count);
end;

function RightStr(const S: string; Count: Integer): string;
begin
  if Count >= Length(S) then Result := S
  else Result := Copy(S, Length(S) - Count + 1, Count);
end;

function MidStr(const S: string; Start, Count: Integer): string;
begin
  Result := Copy(S, Start, Count);
end;

function DupeString(const S: string; Count: Integer): string;
var I: Integer;
begin
  Result := '';
  for I := 1 to Count do
    Result := Result + S;
end;

function ReverseString(const S: string): string;
var I, L: Integer;
begin
  L := Length(S);
  SetLength(Result, L);
  for I := 1 to L do
    Result[I] := S[L - I + 1];
end;

function StartsStr(const ASubStr, AStr: string): Boolean;
var I: Integer;
begin
  if Length(ASubStr) > Length(AStr) then Exit(False);
  for I := 1 to Length(ASubStr) do
    if AStr[I] <> ASubStr[I] then Exit(False);
  Result := True;
end;

function EndsStr(const ASubStr, AStr: string): Boolean;
var I, LOffset: Integer;
begin
  if Length(ASubStr) > Length(AStr) then Exit(False);
  LOffset := Length(AStr) - Length(ASubStr);
  for I := 1 to Length(ASubStr) do
    if AStr[LOffset + I] <> ASubStr[I] then Exit(False);
  Result := True;
end;

function ContainsStr(const AStr, ASubStr: string): Boolean;
begin
  Result := Pos(ASubStr, AStr) > 0;
end;

function StartsText(const ASubStr, AStr: string): Boolean;
begin
  if Length(ASubStr) > Length(AStr) then Exit(False);
  Result := SameText(Copy(AStr, 1, Length(ASubStr)), ASubStr);
end;

function EndsText(const ASubStr, AStr: string): Boolean;
begin
  if Length(ASubStr) > Length(AStr) then Exit(False);
  Result := SameText(Copy(AStr, Length(AStr) - Length(ASubStr) + 1, Length(ASubStr)), ASubStr);
end;

function ContainsText(const AStr, ASubStr: string): Boolean;
begin
  Result := Pos(LowerCase(ASubStr), LowerCase(AStr)) > 0;
end;

function ReplaceStr(const S, OldPattern, NewPattern: string): string;
begin
  Result := StringReplace(S, OldPattern, NewPattern, [rfReplaceAll]);
end;

function ReplaceText(const S, OldPattern, NewPattern: string): string;
begin
  Result := StringReplace(S, OldPattern, NewPattern, [rfReplaceAll, rfIgnoreCase]);
end;

function SplitString(const S, Delimiters: string): specialize TArray<string>;
var
  I, LStart, LCount: Integer;
  LIsDelim: Boolean;
begin
  LCount := 0;
  SetLength(Result, 0);
  LStart := 1;
  for I := 1 to Length(S) do
  begin
    LIsDelim := Pos(S[I], Delimiters) > 0;
    if LIsDelim then
    begin
      Inc(LCount);
      SetLength(Result, LCount);
      Result[LCount - 1] := Copy(S, LStart, I - LStart);
      LStart := I + 1;
    end;
  end;
  Inc(LCount);
  SetLength(Result, LCount);
  Result[LCount - 1] := Copy(S, LStart, Length(S) - LStart + 1);
end;

function IndexStr(const S: string; const Values: array of string): Integer;
var I: Integer;
begin
  for I := 0 to High(Values) do
    if Values[I] = S then Exit(I);
  Result := -1;
end;

function IndexText(const S: string; const Values: array of string): Integer;
var I: Integer;
begin
  for I := 0 to High(Values) do
    if SameText(Values[I], S) then Exit(I);
  Result := -1;
end;

function IfThen(ACondition: Boolean; const ATrue: string; const AFalse: string = ''): string;
begin
  if ACondition then Result := ATrue else Result := AFalse;
end;

function StuffString(const S: string; Index, Count: Integer; const SubStr: string): string;
begin
  Result := Copy(S, 1, Index - 1) + SubStr + Copy(S, Index + Count, Length(S));
end;

function RandomFrom(const Values: array of string): string;
begin
  Result := Values[Random(Length(Values))];
end;

function NaturalCompareText(const S1, S2: string): Integer;
var
  I1, I2, L1, L2: Integer;
  C1, C2: Char;
  N1, N2: Int64;

  function ExtractNum(const S: string; var Pos: Integer): Int64;
  begin
    Result := 0;
    while (Pos <= Length(S)) and (S[Pos] >= '0') and (S[Pos] <= '9') do
    begin
      Result := Result * 10 + Ord(S[Pos]) - Ord('0');
      Inc(Pos);
    end;
  end;

begin
  I1 := 1; I2 := 1;
  L1 := Length(S1); L2 := Length(S2);
  while (I1 <= L1) and (I2 <= L2) do
  begin
    C1 := S1[I1]; C2 := S2[I2];
    if (C1 >= '0') and (C1 <= '9') and (C2 >= '0') and (C2 <= '9') then
    begin
      N1 := ExtractNum(S1, I1);
      N2 := ExtractNum(S2, I2);
      if N1 < N2 then Exit(-1);
      if N1 > N2 then Exit(1);
    end
    else
    begin
      if (C1 >= 'A') and (C1 <= 'Z') then C1 := Chr(Ord(C1) + 32);
      if (C2 >= 'A') and (C2 <= 'Z') then C2 := Chr(Ord(C2) + 32);
      if C1 < C2 then Exit(-1);
      if C1 > C2 then Exit(1);
      Inc(I1); Inc(I2);
    end;
  end;
  Result := L1 - L2;
end;

end.
