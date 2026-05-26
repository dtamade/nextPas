unit nextpas.core.encoding.varint;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils;

function VarintEncode(const AValue: UInt64): TBytes;
function VarintDecode(const AData: TBytes; out ABytesRead: Integer): UInt64;
function SignedVarintEncode(const AValue: Int64): TBytes;
function SignedVarintDecode(const AData: TBytes; out ABytesRead: Integer): Int64;

implementation

function VarintEncode(const AValue: UInt64): TBytes;
var
  LBuf: array[0..9] of Byte;
  LCount: Integer;
  LVal: UInt64;
begin
  Result := nil;
  LVal := AValue;
  LCount := 0;
  repeat
    LBuf[LCount] := Byte(LVal and $7F);
    LVal := LVal shr 7;
    if LVal <> 0 then
      LBuf[LCount] := LBuf[LCount] or $80;
    Inc(LCount);
  until LVal = 0;

  SetLength(Result, LCount);
  Move(LBuf[0], Result[0], LCount);
end;

function VarintDecode(const AData: TBytes; out ABytesRead: Integer): UInt64;
var
  LShift: Integer;
  LByte: Byte;
begin
  Result := 0;
  LShift := 0;
  ABytesRead := 0;

  if Length(AData) = 0 then
    raise EConvertError.Create('Empty varint data');

  repeat
    if ABytesRead >= Length(AData) then
      raise EConvertError.Create('Truncated varint');
    LByte := AData[ABytesRead];
    Result := Result or (UInt64(LByte and $7F) shl LShift);
    Inc(ABytesRead);
    Inc(LShift, 7);
  until (LByte and $80) = 0;
end;

function ZigZagEncode(const AValue: Int64): UInt64; inline;
begin
  Result := UInt64((AValue shl 1) xor SarInt64(AValue, 63));
end;

function ZigZagDecode(const AValue: UInt64): Int64; inline;
begin
  Result := Int64(AValue shr 1) xor (-(Int64(AValue and 1)));
end;

function SignedVarintEncode(const AValue: Int64): TBytes;
begin
  Result := VarintEncode(ZigZagEncode(AValue));
end;

function SignedVarintDecode(const AData: TBytes; out ABytesRead: Integer): Int64;
begin
  Result := ZigZagDecode(VarintDecode(AData, ABytesRead));
end;

end.
