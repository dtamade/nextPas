{$mode objfpc}
unit nextpasstrutils;

interface

type
  TReplaceFlags = set of (rfReplaceAll, rfIgnoreCase);
  TStringArray = array of String;

function LowerCase(const S: String): String;
function UpperCase(const S: String): String;
function Trim(const S: String): String;
function TrimLeft(const S: String): String;
function TrimRight(const S: String): String;
function Pos(const SubStr, S: String): Integer;
function StringReplace(const S, OldPattern, NewPattern: String; Flags: TReplaceFlags): String;
function Contains(const S, SubStr: String): Boolean;
function StartsWith(const S, Prefix: String): Boolean;
function EndsWith(const S, Suffix: String): Boolean;
function Split(const S, Delimiter: String): TStringArray;
function Join(const Parts: TStringArray; const Delimiter: String): String;
function CompareText(const S1, S2: String): Integer;
function SameText(const S1, S2: String): Boolean;
function PadLeft(const S: String; Width: Integer; Ch: Char): String;
function PadRight(const S: String; Width: Integer; Ch: Char): String;

implementation

function LowerCase(const S: String): String;
var
  i: Integer;
  ch: Char;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    ch := S[i];
    if (ch >= 'A') and (ch <= 'Z') then
      Result := Result + Char(Ord(ch) + 32)
    else
      Result := Result + ch;
  end;
end;

function UpperCase(const S: String): String;
var
  i: Integer;
  ch: Char;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    ch := S[i];
    if (ch >= 'a') and (ch <= 'z') then
      Result := Result + Char(Ord(ch) - 32)
    else
      Result := Result + ch;
  end;
end;

function TrimLeft(const S: String): String;
var
  start: Integer;
begin
  start := 1;
  while (start <= Length(S)) and ((S[start] = ' ') or (S[start] = #9)) do
    Inc(start);
  if start > Length(S) then
    Exit('');
  Result := '';
  while start <= Length(S) do
  begin
    Result := Result + S[start];
    Inc(start);
  end;
end;

function TrimRight(const S: String): String;
var
  cend: Integer;
  i: Integer;
begin
  cend := Length(S);
  while (cend >= 1) and ((S[cend] = ' ') or (S[cend] = #9)) do
    Dec(cend);
  if cend < 1 then
    Exit('');
  Result := '';
  for i := 1 to cend do
    Result := Result + S[i];
end;

function Trim(const S: String): String;
var
  tmp: String;
begin
  tmp := TrimLeft(S);
  Result := TrimRight(tmp);
end;

function Pos(const SubStr, S: String): Integer;
var
  i, j, sLen, subLen: Integer;
  found: Boolean;
begin
  sLen := Length(S);
  subLen := Length(SubStr);
  if subLen = 0 then
    Exit(1);
  if subLen > sLen then
    Exit(0);
  for i := 1 to sLen - subLen + 1 do
  begin
    found := True;
    for j := 1 to subLen do
    begin
      if S[i + j - 1] <> SubStr[j] then
      begin
        found := False;
        break;
      end;
    end;
    if found then
      Exit(i);
  end;
  Result := 0;
end;

function CharEqualIgnoreCase(a, b: Char): Boolean;
begin
  if (a >= 'A') and (a <= 'Z') then
    a := Char(Ord(a) + 32);
  if (b >= 'A') and (b <= 'Z') then
    b := Char(Ord(b) + 32);
  Result := a = b;
end;

function StringReplace(const S, OldPattern, NewPattern: String; Flags: TReplaceFlags): String;
var
  i, sLen, patLen: Integer;
  matched: Boolean;
  j: Integer;
begin
  sLen := Length(S);
  patLen := Length(OldPattern);
  if (patLen = 0) or (patLen > sLen) then
    Exit(S);
  Result := '';
  i := 1;
  while i <= sLen do
  begin
    if i + patLen - 1 > sLen then
      matched := False
    else if rfIgnoreCase in Flags then
    begin
      matched := True;
      for j := 1 to patLen do
      begin
        if not CharEqualIgnoreCase(S[i + j - 1], OldPattern[j]) then
        begin
          matched := False;
          break;
        end;
      end;
    end
    else
    begin
      matched := True;
      for j := 1 to patLen do
      begin
        if S[i + j - 1] <> OldPattern[j] then
        begin
          matched := False;
          break;
        end;
      end;
    end;
    if matched then
    begin
      Result := Result + NewPattern;
      i := i + patLen;
      if not (rfReplaceAll in Flags) then
      begin
        while i <= sLen do
        begin
          Result := Result + S[i];
          Inc(i);
        end;
        Exit;
      end;
    end
    else
    begin
      Result := Result + S[i];
      Inc(i);
    end;
  end;
end;

function Contains(const S, SubStr: String): Boolean;
begin
  Result := Pos(SubStr, S) > 0;
end;

function StartsWith(const S, Prefix: String): Boolean;
var
  i: Integer;
begin
  if Length(Prefix) > Length(S) then
    Exit(False);
  for i := 1 to Length(Prefix) do
  begin
    if S[i] <> Prefix[i] then
      Exit(False);
  end;
  Result := True;
end;

function EndsWith(const S, Suffix: String): Boolean;
var
  offset: Integer;
  i: Integer;
begin
  if Length(Suffix) > Length(S) then
    Exit(False);
  offset := Length(S) - Length(Suffix);
  for i := 1 to Length(Suffix) do
  begin
    if S[offset + i] <> Suffix[i] then
      Exit(False);
  end;
  Result := True;
end;

function Split(const S, Delimiter: String): TStringArray;
var
  count, i, j, partStart, sLen, dLen: Integer;
  matched: Boolean;
  partEnd: Integer;
  k: Integer;
begin
  sLen := Length(S);
  dLen := Length(Delimiter);
  if sLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  if dLen = 0 then
  begin
    SetLength(Result, 1);
    Result[0] := S;
    Exit;
  end;
  count := 1;
  i := 1;
  while i <= sLen - dLen + 1 do
  begin
    matched := True;
    for j := 1 to dLen do
    begin
      if S[i + j - 1] <> Delimiter[j] then
      begin
        matched := False;
        break;
      end;
    end;
    if matched then
    begin
      Inc(count);
      i := i + dLen;
    end
    else
      Inc(i);
  end;
  SetLength(Result, count);
  partStart := 1;
  i := 1;
  k := 0;
  while i <= sLen do
  begin
    if (i <= sLen - dLen + 1) and (dLen > 0) then
    begin
      matched := True;
      for j := 1 to dLen do
      begin
        if S[i + j - 1] <> Delimiter[j] then
        begin
          matched := False;
          break;
        end;
      end;
    end
    else
      matched := False;
    if matched then
    begin
      Result[k] := '';
      partEnd := i - 1;
      if partEnd >= partStart then
      begin
        for j := partStart to partEnd do
          Result[k] := Result[k] + S[j];
      end;
      Inc(k);
      i := i + dLen;
      partStart := i;
    end
    else
      Inc(i);
  end;
  if partStart <= sLen then
  begin
    Result[k] := '';
    for j := partStart to sLen do
      Result[k] := Result[k] + S[j];
  end
  else if k < count then
    Result[k] := '';
end;

function Join(const Parts: TStringArray; const Delimiter: String): String;
var
  i: Integer;
begin
  Result := '';
  if Length(Parts) = 0 then
    Exit;
  Result := Parts[0];
  for i := 1 to Length(Parts) - 1 do
    Result := Result + Delimiter + Parts[i];
end;

function CompareText(const S1, S2: String): Integer;
var
  len1, len2, i: Integer;
  c1, c2: Char;
begin
  len1 := Length(S1);
  len2 := Length(S2);
  i := 1;
  while (i <= len1) and (i <= len2) do
  begin
    c1 := S1[i];
    c2 := S2[i];
    if (c1 >= 'A') and (c1 <= 'Z') then
      c1 := Char(Ord(c1) + 32);
    if (c2 >= 'A') and (c2 <= 'Z') then
      c2 := Char(Ord(c2) + 32);
    if c1 <> c2 then
    begin
      if Ord(c1) < Ord(c2) then
        Exit(-1)
      else
        Exit(1);
    end;
    Inc(i);
  end;
  if len1 < len2 then
    Exit(-1);
  if len1 > len2 then
    Exit(1);
  Result := 0;
end;

function SameText(const S1, S2: String): Boolean;
begin
  Result := CompareText(S1, S2) = 0;
end;

function PadLeft(const S: String; Width: Integer; Ch: Char): String;
var
  padCount, i: Integer;
begin
  if Length(S) >= Width then
    Exit(S);
  padCount := Width - Length(S);
  Result := '';
  for i := 1 to padCount do
    Result := Result + Ch;
  Result := Result + S;
end;

function PadRight(const S: String; Width: Integer; Ch: Char): String;
var
  padCount, i: Integer;
begin
  if Length(S) >= Width then
    Exit(S);
  padCount := Width - Length(S);
  Result := S;
  for i := 1 to padCount do
    Result := Result + Ch;
end;

end.