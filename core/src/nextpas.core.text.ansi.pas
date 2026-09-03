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

implementation

uses
  nextpas.core.bytes.ops;

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

end.
