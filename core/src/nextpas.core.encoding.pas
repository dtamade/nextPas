unit nextpas.core.encoding;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.encoding.base,
  nextpas.core.encoding.base64,
  nextpas.core.encoding.hex,
  nextpas.core.encoding.varint,
  nextpas.core.encoding.url;

type
  TBase64Variant = nextpas.core.encoding.base.TBase64Variant;
  THexCase = nextpas.core.encoding.base.THexCase;

function Base64Encode(const AData: TBytes): string; inline;
function Base64Decode(const AEncoded: string): TBytes; inline;
function Base64UrlEncode(const AData: TBytes): string; inline;
function Base64UrlDecode(const AEncoded: string): TBytes; inline;

function HexEncode(const AData: TBytes; const ACase: THexCase = hcLower): string; inline;
function HexDecode(const AHex: string): TBytes; inline;

function VarintEncode(const AValue: UInt64): TBytes; inline;
function VarintDecode(const AData: TBytes; out ABytesRead: Integer): UInt64; inline;
function SignedVarintEncode(const AValue: Int64): TBytes; inline;
function SignedVarintDecode(const AData: TBytes; out ABytesRead: Integer): Int64; inline;

function UrlEncode(const AValue: string): string; inline;
function UrlDecode(const AEncoded: string): string; inline;

implementation

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

end.
