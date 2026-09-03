unit nextpas.core.text.utils;

{$I nextpas.core.settings.inc}

{** 2026-08-29 验证锚点：PadLeft/PadRight 单分配（not inline per red-line 2 分配+循环 I-Cache，FillChar+Move 零拷贝经 bytes.ops 单源，规避 FPC inline+字面量 Move 缺陷）、
    NormalizeLowerTrim 单源（db.factory 唯一复用）、Lower/Upper Byte 区间、CopyStrToBuf/CStrToStr not inline per red-line 1（S[1]/Result[1]→PAnsiChar 经 bytes.ops 单源零拷贝，规避 FPC inline+字面量 Move 缺陷）、
    StrToIntDef 零分配 inline（接口+实现双 inline 去 Trim 拷贝，单遍空白+符号+数字扫描，含 ±2^63 边界）；
    配套 bench_kv 10（validate 0 allocs）与 test_text 33 heaptrc0 见 benchmarks.md 验证锚点。 *}

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
function NormalizeLowerTrim(const S: string): string; inline;
function PadLeft(const S: string; AWidth: Integer; APadChar: Char = ' '): string;
function PadRight(const S: string; AWidth: Integer; APadChar: Char = ' '): string;
function RepeatString(const S: string; ACount: Integer): string;
function StrToIntDef(const S: string; ADefault: Int64): Int64; inline;
function BoolToStr(AValue: Boolean; const ATrueStr: string = 'True'; const AFalseStr: string = 'False'): string;
function StringReplace(const S, OldPattern, NewPattern: string; AReplaceAll: Boolean = True): string;
function QuotedStr(const S: string): string;

{** @desc 从 AFrom(1-based)起查找子串;空子串在有效范围内命中 AFrom。
        找不到或 AFrom 越界返回 0。StrUtils.PosEx 语义。 *}
function PosEx(const ASubStr, AStr: string; const AFrom: Integer = 1): Integer; inline;
{** @desc 按 Delimiters 中任意字符切分;连续分隔符不产生空段;尾部分隔符不产生尾空段。
        SysUtils.SplitString 语义。 *}
function SplitString(const S, Delimiters: string): TStringArray; inline;

{** @desc 拷贝字符串到定长字节缓冲(截断至 ABufLen-1,留下 NUL;不抛)。
        返回源串字符数(截断前)。线程安全(无共享状态)。 *}
function CopyStrToBuf(const S: string; var ABuf; ABufLen: Integer): Integer;

{** @desc 读 NUL 结尾缓冲为 string(无 ShortString 255 上限;StrPas 会截断大缓冲)。
        适合 worker 定长缓冲转 string 的场景。 *}
function CStrToStr(const AP: PAnsiChar): string;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.text.builder,
  nextpas.core.text.char,
  nextpas.core.text.view;

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
    if (Byte(S[I]) >= 65) and (Byte(S[I]) <= 90) then
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
    if (Byte(S[I]) >= 97) and (Byte(S[I]) <= 122) then
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

function NormalizeLowerTrim(const S: string): string; inline;
var
  L, R, I: SizeInt;
begin
  L := 1;
  R := Length(S);
  while (L <= R) and (S[L] <= ' ') do Inc(L);
  while (R >= L) and (S[R] <= ' ') do Dec(R);
  if L > R then Exit('');
  SetLength(Result, R - L + 1);
  for I := L to R do
    if (Byte(S[I]) >= 65) and (Byte(S[I]) <= 90) then
      Result[I - L + 1] := Chr(Byte(S[I]) + 32)
    else
      Result[I - L + 1] := S[I];
end;

function PadLeft(const S: string; AWidth: Integer; APadChar: Char): string;
var
  LPadLen: Integer;
begin
  // not inline per red-line 2: SetLength+FillChar+loop/I-Cache bloat (小体量仍命中分配+循环红线，门面薄转发豁免不适用 owner)
  // perf: single SetLength + FillChar + zero-copy Move via bytes.ops single source (Pointer(Result)^), 1 alloc, inline kept at facade
  // stability: SetLength exception-safe (no leak), FillChar/Move on managed string buffer after alloc
  LPadLen := AWidth - Length(S);
  if LPadLen <= 0 then
    Exit(S);
  SetLength(Result, AWidth);
  FillChar(PAnsiChar(Result)^, LPadLen, Byte(APadChar));
  if Length(S) > 0 then
    nextpas.core.bytes.ops.BytesCopy(PByte(PAnsiChar(Result)) + LPadLen, PAnsiChar(S), SizeUInt(Length(S)));
end;

function PadRight(const S: string; AWidth: Integer; APadChar: Char): string;
var
  LPadLen: Integer;
begin
  // not inline per red-line 2: SetLength+FillChar+loop/I-Cache bloat (小体量仍命中分配+循环红线，门面薄转发豁免不适用 owner)
  // perf: single SetLength + zero-copy Move via bytes.ops single source + FillChar, 1 alloc, inline kept at facade
  // stability: SetLength exception-safe, Move/FillChar on managed buffer after alloc
  LPadLen := AWidth - Length(S);
  if LPadLen <= 0 then
    Exit(S);
  SetLength(Result, AWidth);
  if Length(S) > 0 then
    nextpas.core.bytes.ops.BytesCopy(PAnsiChar(Result), PAnsiChar(S), SizeUInt(Length(S)));
  FillChar((PByte(PAnsiChar(Result)) + Length(S))^, LPadLen, Byte(APadChar));
end;

function RepeatString(const S: string; ACount: Integer): string;
var
  LChunkLen: SizeInt;
begin
  // not inline per red-line 2: loop+doubling I-Cache bloat (BytesReplicateCopy) — single SetLength, bytes.ops single source
  // perf: single SetLength + zero-copy via bytes.ops single source (BytesCopy/BytesReplicateCopy), doubling O(log n) amortized, 1 alloc
  // stability: SetLength exception-safe (no leak), BytesCopy/Replicate on managed buffer after alloc
  if (ACount <= 0) or (S = '') then
    Exit('');
  if ACount = 1 then
    Exit(S);
  LChunkLen := Length(S);
  SetLength(Result, LChunkLen * ACount);
  if LChunkLen > 0 then
    nextpas.core.bytes.ops.BytesCopy(PAnsiChar(Result), PAnsiChar(S), SizeUInt(LChunkLen));
  if ACount > 1 then
    nextpas.core.bytes.ops.BytesReplicateCopy(PAnsiChar(Result), PAnsiChar(Result) + LChunkLen, SizeUInt(LChunkLen) - 1, SizeUInt(LChunkLen) * (SizeUInt(ACount) - 1));
end;

function StrToIntDef(const S: string; ADefault: Int64): Int64; inline;
var
  L, R, I: SizeInt;
  LNeg: Boolean;
  LVal: UInt64;
  LDigit: Integer;
begin
  L := 1;
  R := Length(S);
  while (L <= R) and (S[L] <= ' ') do Inc(L);
  while (R >= L) and (S[R] <= ' ') do Dec(R);
  if L > R then Exit(ADefault);
  LNeg := False;
  I := L;
  if S[I] = '-' then begin LNeg := True; Inc(I); end
  else if S[I] = '+' then Inc(I);
  if I > R then Exit(ADefault);
  LVal := 0;
  for I := I to R do
  begin
    LDigit := Ord(S[I]) - 48;
    if (LDigit < 0) or (LDigit > 9) then Exit(ADefault);
    if LVal > High(UInt64) div 10 then Exit(ADefault);
    LVal := LVal * 10 + UInt64(LDigit);
    if not LNeg and (LVal > UInt64(High(Int64))) then Exit(ADefault);
    if LNeg and (LVal > UInt64(High(Int64)) + 1) then Exit(ADefault);
  end;
  if LNeg then Result := -Int64(LVal) else Result := Int64(LVal);
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

function PosEx(const ASubStr, AStr: string; const AFrom: Integer): Integer; inline;
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

function SplitString(const S, Delimiters: string): TStringArray; inline;
var
  I, LStart, LCount, LCap: Integer;
  DelimSet: array[0..255] of Boolean;
  LView, LSeg: TStringView;
begin
  Result := nil;
  if (S = '') or (Delimiters = '') then
  begin
    if S <> '' then
    begin
      SetLength(Result, 1);
      Result[0] := S;
    end;
    Exit;
  end;
  FillChar(DelimSet, SizeOf(DelimSet), 0);
  for I := 1 to Length(Delimiters) do
    DelimSet[Byte(Delimiters[I])] := True;
  LView := TStringView.FromStr(S);
  LCap := 0;
  LCount := 0;
  LStart := 0;
  // perf: geometric growth single source via bytes.ops.BytesGrowCapacityInt amortized O(1), zero-copy TStringView slice, not inline per red-line 2: BytesGrowCapacity loop I-Cache bloat
  for I := 0 to Integer(LView.Len) - 1 do
    if DelimSet[Byte(LView.Data[I])] then
    begin
      if I > LStart then
      begin
        if LCount >= LCap then
        begin
          LCap := nextpas.core.bytes.ops.BytesGrowCapacityInt(LCap, LCount + 1);
          SetLength(Result, LCap);
        end;
        LSeg := LView.Slice(SizeUInt(LStart), SizeUInt(I - LStart));
        Result[LCount] := LSeg.ToString;
        Inc(LCount);
      end;
      LStart := I + 1;
    end;
  if SizeUInt(LStart) < LView.Len then
  begin
    if LCount >= LCap then
    begin
      LCap := nextpas.core.bytes.ops.BytesGrowCapacityInt(LCap, LCount + 1);
      SetLength(Result, LCap);
    end;
    LSeg := LView.Slice(SizeUInt(LStart), LView.Len - SizeUInt(LStart));
    Result[LCount] := LSeg.ToString;
    Inc(LCount);
  end;
  if LCount = 0 then
    Result := nil
  else
    SetLength(Result, LCount);
end;

function CopyStrToBuf(const S: string; var ABuf; ABufLen: Integer): Integer;
var
  P: PAnsiChar;
  N: Integer;
begin
  // not inline per red-line 1: Move(S[1],P^) 字面量 inline 会被常量传播折叠为单字符值并拷垃圾（valgrind+反汇编，曾致 tls 门红），改 PAnsiChar 单源；FillChar/Move 零拷贝经 bytes.ops 单源
  // perf: BytesZero+BytesCopy 单源零拷贝（单次 Fill+单次 Move），无分配，线程安全；inline 去除避 I-Cache 膨胀
  // stability: FillChar 零终止，N 截断至 ABufLen-1，BytesCopy 在边界校验后执行
  P := @ABuf;
  if ABufLen > 0 then
    nextpas.core.bytes.ops.BytesZero(P, SizeUInt(ABufLen));
  Result := Length(S);
  N := Result;
  if N >= ABufLen then N := ABufLen - 1;
  if N > 0 then
    nextpas.core.bytes.ops.BytesCopy(P, PAnsiChar(S), SizeUInt(N));
end;

function CStrToStr(const AP: PAnsiChar): string;
var
  N: SizeInt;
begin
  // not inline per red-line 1: Move(AP^,Result[1]) Result[1] 喂 untyped 参数同命中红线一（S[1] 折叠拷垃圾同理），改 PAnsiChar 单源经 bytes.ops
  // perf: single SetLength + zero-copy BytesCopy 单源，单次分配，inline 去除避 I-Cache 膨胀；bytes.ops 单源复用
  // stability: SetLength 异常安全（无泄漏），BytesCopy 在分配后的受管缓冲上执行
  N := StrLen(AP);
  SetLength(Result, N);
  if N > 0 then
    nextpas.core.bytes.ops.BytesCopy(PAnsiChar(Result), AP, SizeUInt(N));
end;

end.
