unit nextpas.core.hash.util;

{$mode objfpc}{$H+}

interface

function DigestToHex(const ABuf; ALen: SizeUInt): string;

implementation

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
  SetLength(Result, ALen * 2);
  P := @ABuf;
  for I := 0 to ALen - 1 do
  begin
    Result[I * 2 + 1] := HEX_CHARS[P[I] shr 4];
    Result[I * 2 + 2] := HEX_CHARS[P[I] and $0F];
  end;
end;

end.
