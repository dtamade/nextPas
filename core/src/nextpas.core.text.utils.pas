unit nextpas.core.text.utils;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

function Trim(const S: string): string; inline;
function TrimLeft(const S: string): string; inline;
function TrimRight(const S: string): string; inline;
function IsEmpty(const S: string): Boolean; inline;
function IsBlank(const S: string): Boolean; inline;
{** @note ASCII-only. For Unicode-aware conversion use UTF8ToUpper/UTF8ToLower from text.unicode. *}
function LowerCase(const S: string): string; inline;
{** @note ASCII-only. For Unicode-aware conversion use UTF8ToUpper/UTF8ToLower from text.unicode. *}
function UpperCase(const S: string): string; inline;
function PadLeft(const S: string; AWidth: Integer; APadChar: Char = ' '): string;
function PadRight(const S: string; AWidth: Integer; APadChar: Char = ' '): string;
function RepeatString(const S: string; ACount: Integer): string;
function StrToIntDef(const S: string; ADefault: Int64): Int64;
function BoolToStr(AValue: Boolean; const ATrueStr: string = 'True'; const AFalseStr: string = 'False'): string;
function StringReplace(const S, OldPattern, NewPattern: string; AReplaceAll: Boolean = True): string;
function QuotedStr(const S: string): string;

{** @desc 从 AFrom(1-based)起查找子串;空子串在有效范围内命中 AFrom。
        找不到或 AFrom 越界返回 0。StrUtils.PosEx 语义。 *}
function PosEx(const ASubStr, AStr: string; const AFrom: Integer = 1): Integer;
{** @desc 按 Delimiters 中任意字符切分;连续分隔符不产生空段;尾部分隔符不产生尾空段。
        SysUtils.SplitString 语义。 *}
function SplitString(const S, Delimiters: string): TStringArray;

{** @desc 拷贝字符串到定长字节缓冲(截断至 ABufLen-1,留下 NUL;不抛)。
        返回源串字符数(截断前)。线程安全(无共享状态)。 *}
function CopyStrToBuf(const S: string; var ABuf; ABufLen: Integer): Integer;

{** @desc 读 NUL 结尾缓冲为 string(无 ShortString 255 上限;StrPas 会截断大缓冲)。
        适合 worker 定长缓冲转 string 的场景。 *}
function CStrToStr(const AP: PAnsiChar): string;

implementation

uses
  nextpas.core.text.builder,
  nextpas.core.text.char;

function Trim(const S: string): string; inline;
var
  L, R: SizeInt;
begin
  L := 1;
  R := Length(S);
  while (L <= R) and (S[L] <= ' ') do Inc(L);
  while (R >= L) and (S[R] <= ' ') do Dec(R);
  if L > R then
    Exit('');
  if (L = 1) and (R = Length(S)) then
    Exit(S);
  Result := Copy(S, L, R - L + 1);
end;

function TrimLeft(const S: string): string; inline;
var
  L: SizeInt;
begin
  L := 1;
  while (L <= Length(S)) and (S[L] <= ' ') do Inc(L);
  if L = 1 then
    Exit(S);
  Result := Copy(S, L, Length(S) - L + 1);
end;

function TrimRight(const S: string): string; inline;
var
  R: SizeInt;
begin
  R := Length(S);
  while (R >= 1) and (S[R] <= ' ') do Dec(R);
  if R = Length(S) then
    Exit(S);
  Result := Copy(S, 1, R);
end;

function IsEmpty(const S: string): Boolean; inline;
begin
  Result := Length(S) = 0;
end;

function IsBlank(const S: string): Boolean; inline;
var
  I: SizeInt;
begin
  for I := 1 to Length(S) do
    if S[I] > ' ' then
      Exit(False);
  Result := True;
end;

function LowerCase(const S: string): string; inline;
var
  I: SizeInt;
  LNeeds: Boolean;
begin
  LNeeds := False;
  for I := 1 to Length(S) do
    if S[I] in ['A'..'Z'] then
    begin
      LNeeds := True;
      Break;
    end;
  if not LNeeds then
    Exit(S);
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I] := Chr(ToLower(Byte(S[I])));
end;

function UpperCase(const S: string): string; inline;
var
  I: SizeInt;
  LNeeds: Boolean;
begin
  LNeeds := False;
  for I := 1 to Length(S) do
    if S[I] in ['a'..'z'] then
    begin
      LNeeds := True;
      Break;
    end;
  if not LNeeds then
    Exit(S);
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I] := Chr(ToUpper(Byte(S[I])));
end;

function PadLeft(const S: string; AWidth: Integer; APadChar: Char): string;
var
  LPadLen: Integer;
begin
  LPadLen := AWidth - Length(S);
  if LPadLen <= 0 then
    Exit(S);
  Result := StringOfChar(APadChar, LPadLen) + S;
end;

function PadRight(const S: string; AWidth: Integer; APadChar: Char): string;
var
  LPadLen: Integer;
begin
  LPadLen := AWidth - Length(S);
  if LPadLen <= 0 then
    Exit(S);
  Result := S + StringOfChar(APadChar, LPadLen);
end;

function RepeatString(const S: string; ACount: Integer): string;
var
  I: Integer;
  LChunkLen: SizeInt;
  LPos: SizeInt;
begin
  if (ACount <= 0) or (S = '') then
    Exit('');
  if ACount = 1 then
    Exit(S);

  LChunkLen := Length(S);
  SetLength(Result, LChunkLen * ACount);
  LPos := 1;
  for I := 1 to ACount do
  begin
    Move(S[1], Result[LPos], LChunkLen);
    Inc(LPos, LChunkLen);
  end;
end;

function StrToIntDef(const S: string; ADefault: Int64): Int64;
var
  LCode: Integer;
  LTrimmed: string;
begin
  LTrimmed := Trim(S);
  Val(LTrimmed, Result, LCode);
  if LCode <> 0 then
    Result := ADefault;
end;

function BoolToStr(AValue: Boolean; const ATrueStr: string; const AFalseStr: string): string;
begin
  if AValue then Result := ATrueStr else Result := AFalseStr;
end;

function StringReplace(const S, OldPattern, NewPattern: string; AReplaceAll: Boolean = True): string;
var
  LBuilder: TStringBuilder;
  P, Start: SizeInt;
  LReserve: SizeUInt;
begin
  if OldPattern = '' then
    Exit(S);

  Start := 1;
  LReserve := SizeUInt(Length(S));
  if Length(NewPattern) > Length(OldPattern) then
    Inc(LReserve, SizeUInt(Length(NewPattern) - Length(OldPattern)));
  LBuilder.Init(LReserve);
  try
    repeat
      P := Pos(OldPattern, S, Start);
      if P = 0 then
      begin
        if Start <= Length(S) then
          LBuilder.AppendBytes(@S[Start], Length(S) - Start + 1);
        Break;
      end;
      if P > Start then
        LBuilder.AppendBytes(@S[Start], P - Start);
      LBuilder.AppendStr(NewPattern);
      Start := P + Length(OldPattern);
      if not AReplaceAll then
      begin
        if Start <= Length(S) then
          LBuilder.AppendBytes(@S[Start], Length(S) - Start + 1);
        Break;
      end;
    until False;
    Result := LBuilder.ToString;
  finally
    LBuilder.Done;
  end;
end;

function QuotedStr(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''''') + '''';
end;

function PosEx(const ASubStr, AStr: string; const AFrom: Integer): Integer;
var
  LI, LJ, LSubLen, LStrLen: Integer;
begin
  LSubLen := Length(ASubStr);
  LStrLen := Length(AStr);
  Result := 0;
  if AFrom < 1 then
    Exit;
  if LSubLen = 0 then
  begin
    if AFrom <= LStrLen + 1 then
      Result := AFrom;
    Exit;
  end;
  if AFrom > LStrLen - LSubLen + 1 then
    Exit;
  for LI := AFrom to LStrLen - LSubLen + 1 do
  begin
    LJ := 1;
    while (LJ <= LSubLen) and (AStr[LI + LJ - 1] = ASubStr[LJ]) do
      Inc(LJ);
    if LJ > LSubLen then
      Exit(LI);
  end;
end;

function SplitString(const S, Delimiters: string): TStringArray;
var
  I, Start, Count: Integer;
begin
  { 连续分隔符不产生空段:SysUtils.SplitString 语义,行拆分等场景依赖 }
  Result := Nil;
  SetLength(Result, 0);
  Count := 0;
  Start := 1;
  for I := 1 to Length(S) do
    if System.Pos(S[I], Delimiters) > 0 then
    begin
      if I > Start then
      begin
        Inc(Count);
        SetLength(Result, Count);
        Result[Count - 1] := System.Copy(S, Start, I - Start);
      end;
      Start := I + 1;
    end;
  if Start <= Length(S) then
  begin
    Inc(Count);
    SetLength(Result, Count);
    Result[Count - 1] := System.Copy(S, Start, Length(S) - Start + 1);
  end;
end;

function CopyStrToBuf(const S: string; var ABuf; ABufLen: Integer): Integer;
var
  P: PAnsiChar;
  N, I: Integer;
begin
  P := @ABuf;
  if ABufLen > 0 then
    FillChar(P^, ABufLen, 0);
  Result := Length(S);
  N := Result;
  if N >= ABufLen then N := ABufLen - 1;
  if N > 0 then
    for I := 1 to N do
      P[I - 1] := S[I];
end;

function CStrToStr(const AP: PAnsiChar): string;
var
  N: SizeInt;
begin
  N := StrLen(AP);
  SetLength(Result, N);
  if N > 0 then
    Move(AP^, Result[1], N);
end;

end.
