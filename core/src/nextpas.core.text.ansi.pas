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

implementation

function StrToAnsi(const S: string): AnsiString;
begin
  Result := AnsiString(S);
end;

function AnsiToStr(const A: AnsiString): string;
begin
  Result := string(A);
end;

function AnsiPtrToStr(const P: PAnsiChar): string;
var
  LP: PAnsiChar;
  LLen: Integer;
begin
  Result := '';
  if P = nil then Exit;
  LP := P;
  while LP^ <> #0 do Inc(LP);
  LLen := Integer(LP - P);
  if LLen = 0 then Exit;
  SetLength(Result, LLen);
  Move(P^, Result[1], SizeUInt(LLen));
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

end.
