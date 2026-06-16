unit nextpas.core.hash.util;

{$mode objfpc}{$H+}

interface

function DigestOutputSize(ADigestSize, ADstSize: SizeUInt): SizeUInt;
function DigestToHex(const ABuf; ALen: SizeUInt): string;
procedure HashRequireBuffer(const ABuf; ASize: SizeUInt; const AContext: string);
procedure HashRequireTotalLength(ACurrentLen: UInt64; ACount: SizeUInt; const AContext: string);
procedure WriteDigestByte(ADst: PByte; ADstSize, AIndex: SizeUInt; AValue: Byte); inline;

implementation

uses
  nextpas.core.errors;

const
  HASH_MAX_TOTAL_BYTES = High(UInt64) div 8;

function DigestOutputSize(ADigestSize, ADstSize: SizeUInt): SizeUInt;
begin
  Result := ADstSize;
  if Result > ADigestSize then
    Result := ADigestSize;
end;

procedure WriteDigestByte(ADst: PByte; ADstSize, AIndex: SizeUInt; AValue: Byte);
begin
  if AIndex < ADstSize then
    ADst[AIndex] := AValue;
end;

procedure HashRequireBuffer(const ABuf; ASize: SizeUInt; const AContext: string);
begin
  if (ASize > 0) and (@ABuf = nil) then
    raise EArgumentError.Create(AContext + ': nil buffer with nonzero size');
end;

procedure HashRequireTotalLength(ACurrentLen: UInt64; ACount: SizeUInt; const AContext: string);
begin
  if UInt64(ACount) > HASH_MAX_TOTAL_BYTES then
    raise EArgumentError.Create(AContext + ': total length exceeds 64-bit bit count');
  if ACurrentLen > (HASH_MAX_TOTAL_BYTES - UInt64(ACount)) then
    raise EArgumentError.Create(AContext + ': total length exceeds 64-bit bit count');
end;

function DigestToHex(const ABuf; ALen: SizeUInt): string;
var
  I: SizeUInt;
  P: PByte;
const
  HEX_CHARS: array[0..15] of Char = '0123456789abcdef';
begin
  if ALen = 0 then
  begin
    Result := '';
    Exit;
  end;
  if ALen > (High(SizeInt) div 2) then
    raise EArgumentError.Create('DigestToHex: length exceeds maximum string size');
  HashRequireBuffer(ABuf, ALen, 'DigestToHex');
  SetLength(Result, ALen * 2);
  P := @ABuf;
  for I := 0 to ALen - 1 do
  begin
    Result[I * 2 + 1] := HEX_CHARS[P[I] shr 4];
    Result[I * 2 + 2] := HEX_CHARS[P[I] and $0F];
  end;
end;

end.
