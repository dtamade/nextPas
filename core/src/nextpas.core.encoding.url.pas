unit nextpas.core.encoding.url;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors;

function UrlEncode(const AValue: string): string;
function UrlDecode(const AEncoded: string): string;
{ RFC 3986 严格 percent-decode：仅解码 %xx 转义，'+' 保持字面。
  区别于 UrlDecode 的 form/query 语义（'+' → 空格）。 }
function PercentDecode(const AEncoded: string): string;

implementation

uses
  nextpas.core.text.utf8;

function IsUnreserved(const ACh: Byte): Boolean; inline;
begin
  case Chr(ACh) of
    'A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~':
      Result := True;
  else
    Result := False;
  end;
end;

const
  HEX_CHARS: array[0..15] of Char = '0123456789ABCDEF';

function UrlEncode(const AValue: string): string;
var
  LI, LJ, LLen: Integer;
  LByte: Byte;
begin
  LLen := Length(AValue);
  if LLen = 0 then
    Exit('');

  SetLength(Result, LLen * 3);
  LJ := 1;

  for LI := 1 to LLen do
  begin
    LByte := Ord(AValue[LI]);
    if IsUnreserved(LByte) then
    begin
      Result[LJ] := AValue[LI];
      Inc(LJ);
    end
    else
    begin
      Result[LJ]     := '%';
      Result[LJ + 1] := HEX_CHARS[LByte shr 4];
      Result[LJ + 2] := HEX_CHARS[LByte and $0F];
      Inc(LJ, 3);
    end;
  end;

  SetLength(Result, LJ - 1);
end;

function HexVal(const ACh: Char): Byte; inline;
begin
  case ACh of
    '0'..'9': Result := Ord(ACh) - Ord('0');
    'a'..'f': Result := Ord(ACh) - Ord('a') + 10;
    'A'..'F': Result := Ord(ACh) - Ord('A') + 10;
  else
    raise EConvertError.CreateFmt('Invalid percent-encoding hex: %s', [ACh]);
  end;
end;

function UrlDecode(const AEncoded: string): string;
var
  LI, LJ, LLen: Integer;
begin
  LLen := Length(AEncoded);
  if LLen = 0 then
    Exit('');

  SetLength(Result, LLen);
  LI := 1;
  LJ := 1;

  while LI <= LLen do
  begin
    if AEncoded[LI] = '%' then
    begin
      if LI + 2 > LLen then
        raise EConvertError.Create('UrlDecode: truncated percent-encoding');
      Result[LJ] := Chr((HexVal(AEncoded[LI + 1]) shl 4) or HexVal(AEncoded[LI + 2]));
      Inc(LI, 3);
    end
    else if AEncoded[LI] = '+' then
    begin
      Result[LJ] := ' ';
      Inc(LI);
    end
    else
    begin
      Result[LJ] := AEncoded[LI];
      Inc(LI);
    end;
    Inc(LJ);
  end;

  SetLength(Result, LJ - 1);
  if (Length(Result) > 0) and
     (not UTF8IsValid(PByte(PAnsiChar(Result)), Length(Result))) then
    raise EConvertError.Create('UrlDecode: invalid UTF-8');
end;

{ RFC 3986 §2.1 percent-encoded octets。与 UrlDecode 的三处差异：
  1. '+' 保持字面（path 中 '+' 是 sub-delim，非空格；form 语义只适用 query）；
  2. 截断/非法 '%' 序列原样保留，不抛异常（畸形 path 应得 404 而非 500）；
  3. 不做 UTF-8 校验（URI path 是字节序列，解码结果由上层按需校验）。 }
function PercentDecode(const AEncoded: string): string;
var
  LI, LJ, LLen: Integer;
begin
  LLen := Length(AEncoded);
  if LLen = 0 then
    Exit('');

  SetLength(Result, LLen);
  LI := 1;
  LJ := 1;

  while LI <= LLen do
  begin
    if (AEncoded[LI] = '%') and (LI + 2 <= LLen) and
       (AEncoded[LI + 1] in ['0'..'9', 'a'..'f', 'A'..'F']) and
       (AEncoded[LI + 2] in ['0'..'9', 'a'..'f', 'A'..'F']) then
    begin
      Result[LJ] := Chr((HexVal(AEncoded[LI + 1]) shl 4) or
        HexVal(AEncoded[LI + 2]));
      Inc(LI, 3);
    end
    else
    begin
      Result[LJ] := AEncoded[LI];
      Inc(LI);
    end;
    Inc(LJ);
  end;

  SetLength(Result, LJ - 1);
end;

end.
