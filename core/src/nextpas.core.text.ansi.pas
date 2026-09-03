unit nextpas.core.text.ansi;

{$I nextpas.core.settings.inc}

{ FFI 边界 Ansi 互转统一入口。
  替代裸 PAnsiChar(AnsiString(s)) 在托管记录返回场景破坏临时管理的硬边界
  (db 家族实证)，并显式化 Hold 生命周期。 }

interface

{ string -> AnsiString (UTF-8 字节保真，FPC $H+ 下 string 即 UTF-8) }
function StrToAnsi(const S: string): AnsiString; inline;
function AnsiToStr(const A: AnsiString): string; inline;

{ PAnsiChar -> string，nil 安全 (复用 text.conv.AnsiPtrToStr 语义) }
function AnsiPtrToStr(const P: PAnsiChar): string; inline;

{ 为 FFI 调用显式 Hold：Result 指向 Hold 的首字符，Hold 需在调用期间存活 }
function HoldAnsi(const S: string; out Hold: AnsiString): PAnsiChar; inline;
function StrToPAnsi(const S: string; out Hold: AnsiString): PAnsiChar; inline;
{ 零拷贝视图：直接复用 string 的 NUL 终结缓冲，无 StrToAnsi 分配；inline 单源 bytes.ops TByteSpan 视图语义，FFI 同步拷贝故视图生命周期安全 }
function StrToPAnsiView(const S: string): PAnsiChar; inline;

{ 容量与拼接：复用 bytes.ops 几何增长单源，避免逐次 SetLength O(n²)。 }
procedure AnsiSetLogicalLenNoRealloc(var S: AnsiString; const ANewLen: SizeUInt); inline;
procedure StringSetLengthNoRealloc(var S: string; const ANewLen: SizeUInt); inline;
procedure AnsiEnsureCapacity(var ADest: AnsiString; const ARequired: SizeUInt);
procedure StringEnsureCapacity(var ADest: string; const ARequired: SizeUInt);
function StringConcatToAnsi(const A, B: string): AnsiString;
procedure StringConcatToAnsiReuse(var ADest: AnsiString; const A, B: string);
{ ASCII 大写：nil/空安全，单次分配 + SIMD 原地大写（sqlite 声明类型解析等 ASCII 关键字场景）。 }
function AnsiToUpperStr(const AData: PAnsiChar; const ALen: SizeUInt): string;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.simd;

function StrToAnsi(const S: string): AnsiString;
begin
  Result := AnsiString(S);
end;

function AnsiToStr(const A: AnsiString): string;
begin
  Result := string(A);
end;

function AnsiPtrToStr(const P: PAnsiChar): string; inline;
begin
  { perf: inline thin-forward to bytes.ops.AnsiPtrToString single source (zero-copy Move Pointer(Result)^, single SetLength+Move in owner, loop+Move not inline per red-line 2); L1 facade no duplicate Move — single source stays in bytes.ops }
  Result := nextpas.core.bytes.ops.AnsiPtrToString(P);
end;

function HoldAnsi(const S: string; out Hold: AnsiString): PAnsiChar;
begin
  Hold := AnsiString(S);
  Result := PAnsiChar(Hold);
end;

function StrToPAnsi(const S: string; out Hold: AnsiString): PAnsiChar;
begin
  Result := HoldAnsi(S, Hold);
end;

function StrToPAnsiView(const S: string): PAnsiChar;
begin
  if S = '' then Exit(nil);
  Result := PAnsiChar(S);
end;

procedure AnsiSetLogicalLenNoRealloc(var S: AnsiString; const ANewLen: SizeUInt); inline;
var
  PLen: PSizeInt;
begin
  if (S = '') or (Pointer(S) = nil) then Exit;
  if SizeUInt(Length(S)) = ANewLen then Exit;
  PLen := PSizeInt(Pointer(S));
  Dec(PLen);
  PLen^ := SizeInt(ANewLen);
  PByte(PAnsiChar(S) + ANewLen)^ := 0;
end;

procedure StringSetLengthNoRealloc(var S: string; const ANewLen: SizeUInt); inline;
var
  PLen: PSizeInt;
begin
  if (S = '') or (Pointer(S) = nil) then Exit;
  if SizeUInt(Length(S)) = ANewLen then Exit;
  PLen := PSizeInt(Pointer(S));
  Dec(PLen);
  PLen^ := SizeInt(ANewLen);
  PByte(PAnsiChar(S) + ANewLen)^ := 0;
end;

procedure AnsiEnsureCapacity(var ADest: AnsiString; const ARequired: SizeUInt);
var
  LOld, LCap: SizeUInt;
begin
  LOld := SizeUInt(Length(ADest));
  if ARequired <= LOld then
    Exit;
  LCap := nextpas.core.bytes.ops.BytesGrowCapacity(LOld, ARequired);
  SetLength(ADest, LCap);
  if LCap <> ARequired then
    AnsiSetLogicalLenNoRealloc(ADest, ARequired);
end;

procedure StringEnsureCapacity(var ADest: string; const ARequired: SizeUInt);
var
  LOld, LCap: SizeUInt;
begin
  LOld := SizeUInt(Length(ADest));
  if ARequired <= LOld then
    Exit;
  LCap := nextpas.core.bytes.ops.BytesGrowCapacity(LOld, ARequired);
  SetLength(ADest, LCap);
  if LCap <> ARequired then
    StringSetLengthNoRealloc(ADest, ARequired);
end;

function StringConcatToAnsi(const A, B: string): AnsiString;
var
  LLenA, LLenB: SizeUInt;
begin
  LLenA := SizeUInt(Length(A));
  LLenB := SizeUInt(Length(B));
  SetLength(Result, LLenA + LLenB);
  if LLenA > 0 then
    Move(PAnsiChar(A)^, Result[1], LLenA);
  if LLenB > 0 then
    Move(PAnsiChar(B)^, Result[1 + LLenA], LLenB);
end;

procedure StringConcatToAnsiReuse(var ADest: AnsiString; const A, B: string);
var
  LLenA, LLenB, LNeed: SizeUInt;
begin
  LLenA := SizeUInt(Length(A));
  LLenB := SizeUInt(Length(B));
  LNeed := LLenA + LLenB;
  AnsiEnsureCapacity(ADest, LNeed);
  AnsiSetLogicalLenNoRealloc(ADest, LNeed);
  if LLenA > 0 then Move(PAnsiChar(A)^, ADest[1], LLenA);
  if LLenB > 0 then Move(PAnsiChar(B)^, ADest[1 + LLenA], LLenB);
end;

function AnsiToUpperStr(const AData: PAnsiChar; const ALen: SizeUInt): string;
begin
  if (AData = nil) or (ALen = 0) then
    Exit('');
  SetLength(Result, ALen);
  Move(AData^, Result[1], ALen);
  if ALen > 0 then
    ToUpperAscii(@Result[1], ALen);
end;

end.
