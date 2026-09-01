unit nextpas.core.encoding;
{**
 * @desc 编解码门面：Base64、Base32、Hex、URL 编码、Varint。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.encoding.base,
  nextpas.core.encoding.base32,
  nextpas.core.encoding.base64,
  nextpas.core.encoding.gbk,
  nextpas.core.encoding.hex,
  nextpas.core.encoding.varint,
  nextpas.core.encoding.msgpack,
  nextpas.core.encoding.url;

type
  TBase64Variant = nextpas.core.encoding.base.TBase64Variant;
  THexCase = nextpas.core.encoding.base.THexCase;
  TMsgPackValue = nextpas.core.encoding.msgpack.TMsgPackValue;
  TMsgPackKind = nextpas.core.encoding.msgpack.TMsgPackKind;

function Base32Encode(const AData: TBytes): string; inline;
function Base32Decode(const AEncoded: string): TBytes; inline;

function Base64Encode(const AData: TBytes): string; inline;
function Base64Decode(const AEncoded: string): TBytes; inline;
function Base64UrlEncode(const AData: TBytes): string; inline;
function Base64UrlDecode(const AEncoded: string): TBytes; inline;

function HexEncode(const AData: TBytes; const ACase: THexCase = hcLower): string; inline;
function HexDecode(const AHex: string): TBytes; inline;
function UuidHexToBytes(const AUUIDHex: string): TBytes; inline;

function VarintEncode(const AValue: UInt64): TBytes; inline;
function VarintDecode(const AData: TBytes; out ABytesRead: Integer): UInt64; inline;
function SignedVarintEncode(const AValue: Int64): TBytes; inline;
function SignedVarintDecode(const AData: TBytes; out ABytesRead: Integer): Int64; inline;

function UrlEncode(const AValue: string): string; inline;
function UrlDecode(const AEncoded: string): string; inline;
{ RFC 3986 严格 percent-decode（path 语义：'+' 保持字面、非法 '%' 宽容保留） }
function PercentDecode(const AEncoded: string): string; inline;

{ 试探解包：若 AInput 去空白后呈合法 Base64（≥8、非 mod1、仅 B64 字符、'=' 仅尾部 1..2 个）则解码为 UTF-8，否则原样返回（proxy888 MaybeBase64Unwrap 反哺）。 }
function Base64MaybeUnwrap(const AInput: string): string;
function IsMaybeBase64(const AInput: string): Boolean;

{ GBK (CP936) 双字节 → UTF-8；非法序列整体返回空串（调用方回退） }
function GbkToUtf8(const AStr: string): string; inline;

implementation

uses
  nextpas.core.text.utf8;

function IsMaybeBase64(const AInput: string): Boolean;
var
  LStripped: string;
  LI, LEq: Integer;
begin
  LStripped := '';
  for LI := 1 to Length(AInput) do
    if (AInput[LI] <> ' ') and (AInput[LI] <> #9) and
       (AInput[LI] <> #10) and (AInput[LI] <> #13) and (AInput[LI] <> #0) then
      LStripped := LStripped + AInput[LI];
  if Length(LStripped) < 8 then
    Exit(False);
  if (Length(LStripped) mod 4) = 1 then
    Exit(False);
  LEq := 0;
  for LI := 1 to Length(LStripped) do
    case LStripped[LI] of
      'A'..'Z', 'a'..'z', '0'..'9', '+', '/': ;
      '=': Inc(LEq);
    else
      Exit(False);
    end;
  if (LEq > 2) then
    Exit(False);
  if (LEq > 0) then
    for LI := 1 to Length(LStripped) - LEq do
      if LStripped[LI] = '=' then
        Exit(False);
  Result := True;
end;

function Base64MaybeUnwrap(const AInput: string): string;
var
  LStripped: string;
  LI, LEq: Integer;
  LByte: TBytes;
begin
  Result := AInput;
  LStripped := '';
  for LI := 1 to Length(AInput) do
    if (AInput[LI] <> ' ') and (AInput[LI] <> #9) and
       (AInput[LI] <> #10) and (AInput[LI] <> #13) and (AInput[LI] <> #0) then
      LStripped := LStripped + AInput[LI];
  if Length(LStripped) < 8 then
    Exit;
  if (Length(LStripped) mod 4) = 1 then
    Exit;
  LEq := 0;
  for LI := 1 to Length(LStripped) do
    case LStripped[LI] of
      'A'..'Z', 'a'..'z', '0'..'9', '+', '/': ;
      '=': Inc(LEq);
    else
      Exit;
    end;
  if (LEq > 2) then
    Exit;
  if (LEq > 0) then
    for LI := 1 to Length(LStripped) - LEq do
      if LStripped[LI] = '=' then
        Exit;
  { LEq=0 也视为可能（无 padding 的 B64），按标准库能力探测；失败回退原串 }
  try
    LByte := Base64Decode(LStripped);
  except
    Exit;
  end;
  if Length(LByte) = 0 then
    Exit;
  Result := BytesToUTF8(LByte);
end;

function Base32Encode(const AData: TBytes): string;
begin
  Result := nextpas.core.encoding.base32.Base32Encode(AData);
end;

function Base32Decode(const AEncoded: string): TBytes;
begin
  Result := nextpas.core.encoding.base32.Base32Decode(AEncoded);
end;

function Base64Encode(const AData: TBytes): string;
begin
  Result := nextpas.core.encoding.base64.Base64Encode(AData);
end;

function Base64Decode(const AEncoded: string): TBytes;
begin
  Result := nextpas.core.encoding.base64.Base64Decode(AEncoded);
end;

function Base64UrlEncode(const AData: TBytes): string;
begin
  Result := nextpas.core.encoding.base64.Base64UrlEncode(AData);
end;

function Base64UrlDecode(const AEncoded: string): TBytes;
begin
  Result := nextpas.core.encoding.base64.Base64UrlDecode(AEncoded);
end;

function HexEncode(const AData: TBytes; const ACase: THexCase): string;
begin
  Result := nextpas.core.encoding.hex.HexEncode(AData, ACase);
end;

function HexDecode(const AHex: string): TBytes;
begin
  Result := nextpas.core.encoding.hex.HexDecode(AHex);
end;

function UuidHexToBytes(const AUUIDHex: string): TBytes;
begin
  Result := nextpas.core.encoding.hex.UuidHexToBytes(AUUIDHex);
end;

function VarintEncode(const AValue: UInt64): TBytes;
begin
  Result := nextpas.core.encoding.varint.VarintEncode(AValue);
end;

function VarintDecode(const AData: TBytes; out ABytesRead: Integer): UInt64;
begin
  Result := nextpas.core.encoding.varint.VarintDecode(AData, ABytesRead);
end;

function SignedVarintEncode(const AValue: Int64): TBytes;
begin
  Result := nextpas.core.encoding.varint.SignedVarintEncode(AValue);
end;

function SignedVarintDecode(const AData: TBytes; out ABytesRead: Integer): Int64;
begin
  Result := nextpas.core.encoding.varint.SignedVarintDecode(AData, ABytesRead);
end;

function UrlEncode(const AValue: string): string;
begin
  Result := nextpas.core.encoding.url.UrlEncode(AValue);
end;

function UrlDecode(const AEncoded: string): string;
begin
  Result := nextpas.core.encoding.url.UrlDecode(AEncoded);
end;

function PercentDecode(const AEncoded: string): string;
begin
  Result := nextpas.core.encoding.url.PercentDecode(AEncoded);
end;

function GbkToUtf8(const AStr: string): string;
begin
  Result := nextpas.core.encoding.gbk.GbkToUtf8(AStr);
end;

end.
