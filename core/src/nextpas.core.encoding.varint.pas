unit nextpas.core.encoding.varint;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.bytes.base;

function VarintEncode(const AValue: UInt64): TBytes;
function VarintDecode(const AData: TBytes; out ABytesRead: Integer): UInt64;
function SignedVarintEncode(const AValue: Int64): TBytes;
function SignedVarintDecode(const AData: TBytes; out ABytesRead: Integer): Int64;
{ single source varint peek for pack/delta chains — inline zero-copy TByteSpan/TBytes, no alloc, no exception on truncated/overflow }
function TryVarintDecode(const AData: TBytes; var APos: SizeInt; out AValue: UInt64): Boolean; inline; overload;
function TryVarintDecode(var ASpan: TByteSpan; out AValue: UInt64): Boolean; inline; overload;

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

function VarintMinValueForLength(const ALength: Integer): UInt64; inline;
begin
  if ALength <= 1 then
    Exit(0);
  Result := UInt64(1) shl ((ALength - 1) * 7);
end;

function VarintDecode(const AData: TBytes; out ABytesRead: Integer): UInt64;
var
  LShift: Integer;
  LByte: Byte;
  LBytesRead: Integer;
begin
  Result := 0;
  LShift := 0;
  ABytesRead := 0;
  LBytesRead := 0;

  if Length(AData) = 0 then
    raise EConvertError.Create('Empty varint data');

  repeat
    if LBytesRead >= Length(AData) then
      raise EConvertError.Create('Truncated varint');
    if LShift >= 64 then
      raise EConvertError.Create('Varint overflow (>10 bytes)');
    LByte := AData[LBytesRead];
    if (LShift = 63) and ((LByte and $7E) <> 0) then
      raise EConvertError.Create('Varint overflow (10th byte > 1)');
    Result := Result or (UInt64(LByte and $7F) shl LShift);
    Inc(LBytesRead);
    Inc(LShift, 7);
  until (LByte and $80) = 0;

  if Result < VarintMinValueForLength(LBytesRead) then
    raise EConvertError.Create('Non-canonical varint encoding');
  ABytesRead := LBytesRead;
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

function TryVarintDecode(const AData: TBytes; var APos: SizeInt; out AValue: UInt64): Boolean; inline;
var
  LShift: Integer;
  LByte: Byte;
begin
  AValue := 0;
  LShift := 0;
  Result := False;
  if (APos < 0) or (APos >= Length(AData)) then
    Exit;
  repeat
    if APos >= Length(AData) then
      Exit;
    if LShift >= 64 then
      Exit;
    LByte := AData[APos];
    Inc(APos);
    if (LShift = 63) and ((LByte and $7E) <> 0) then
      Exit;
    AValue := AValue or (UInt64(LByte and $7F) shl LShift);
    Inc(LShift, 7);
  until (LByte and $80) = 0;
  Result := True;
end;

function TryVarintDecode(var ASpan: TByteSpan; out AValue: UInt64): Boolean; inline;
var
  LShift: Integer;
  LByte: Byte;
  LPos: SizeUInt;
begin
  AValue := 0;
  LShift := 0;
  LPos := 0;
  Result := False;
  if ASpan.Len = 0 then
    Exit;
  repeat
    if LPos >= ASpan.Len then
      Exit;
    if LShift >= 64 then
      Exit;
    LByte := ASpan.Data[LPos];
    Inc(LPos);
    if (LShift = 63) and ((LByte and $7E) <> 0) then
      Exit;
    AValue := AValue or (UInt64(LByte and $7F) shl LShift);
    Inc(LShift, 7);
  until (LByte and $80) = 0;
  { zero-copy advance: single pointer bump, no Move, inline }
  Inc(ASpan.Data, LPos);
  Dec(ASpan.Len, LPos);
  Result := True;
end;

end.
