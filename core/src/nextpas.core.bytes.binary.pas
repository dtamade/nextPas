unit nextpas.core.bytes.binary;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.base;

{ Byte swap }
function SwapUInt16(const AValue: UInt16): UInt16; inline;
function SwapUInt32(const AValue: UInt32): UInt32; inline;
function SwapUInt64(const AValue: UInt64): UInt64; inline;

{ Conditional swap to/from native endian }
function ToEndian16(const AValue: UInt16; const AEndian: TEndianness): UInt16; inline;
function ToEndian32(const AValue: UInt32; const AEndian: TEndianness): UInt32; inline;
function ToEndian64(const AValue: UInt64; const AEndian: TEndianness): UInt64; inline;
function FromEndian16(const AValue: UInt16; const AEndian: TEndianness): UInt16; inline;
function FromEndian32(const AValue: UInt32; const AEndian: TEndianness): UInt32; inline;
function FromEndian64(const AValue: UInt64; const AEndian: TEndianness): UInt64; inline;

{ Read from pointer (unchecked) }
function ReadUInt16LE(const ASrc: PByte): UInt16; inline;
function ReadUInt16BE(const ASrc: PByte): UInt16; inline;
function ReadUInt32LE(const ASrc: PByte): UInt32; inline;
function ReadUInt32BE(const ASrc: PByte): UInt32; inline;
function ReadUInt64LE(const ASrc: PByte): UInt64; inline;
function ReadUInt64BE(const ASrc: PByte): UInt64; inline;

{ Write to pointer (unchecked) }
procedure WriteUInt16LE(const ADst: PByte; const AValue: UInt16); inline;
procedure WriteUInt16BE(const ADst: PByte; const AValue: UInt16); inline;
procedure WriteUInt32LE(const ADst: PByte; const AValue: UInt32); inline;
procedure WriteUInt32BE(const ADst: PByte; const AValue: UInt32); inline;
procedure WriteUInt64LE(const ADst: PByte; const AValue: UInt64); inline;
procedure WriteUInt64BE(const ADst: PByte; const AValue: UInt64); inline;

{ Advancing cursor reads (span shrinks on success) }
function TryReadUInt8(var ASpan: TByteSpan; out AValue: Byte): Boolean; inline;
function TryReadUInt16LE(var ASpan: TByteSpan; out AValue: UInt16): Boolean;
function TryReadUInt16BE(var ASpan: TByteSpan; out AValue: UInt16): Boolean;
function TryReadUInt32LE(var ASpan: TByteSpan; out AValue: UInt32): Boolean;
function TryReadUInt32BE(var ASpan: TByteSpan; out AValue: UInt32): Boolean;
function TryReadUInt64LE(var ASpan: TByteSpan; out AValue: UInt64): Boolean;
function TryReadUInt64BE(var ASpan: TByteSpan; out AValue: UInt64): Boolean;

{ Advancing cursor writes (span shrinks on success) }
function TryWriteUInt8(var ASpan: TByteSpan; const AValue: Byte): Boolean; inline;
function TryWriteUInt16LE(var ASpan: TByteSpan; const AValue: UInt16): Boolean;
function TryWriteUInt16BE(var ASpan: TByteSpan; const AValue: UInt16): Boolean;
function TryWriteUInt32LE(var ASpan: TByteSpan; const AValue: UInt32): Boolean;
function TryWriteUInt32BE(var ASpan: TByteSpan; const AValue: UInt32): Boolean;
function TryWriteUInt64LE(var ASpan: TByteSpan; const AValue: UInt64): Boolean;
function TryWriteUInt64BE(var ASpan: TByteSpan; const AValue: UInt64): Boolean;

implementation

{ Swap }

function SwapUInt16(const AValue: UInt16): UInt16;
begin
  Result := ((AValue shr 8) and $FF) or ((AValue and $FF) shl 8);
end;

function SwapUInt32(const AValue: UInt32): UInt32;
begin
  Result := ((AValue shr 24) and $000000FF) or
            ((AValue shr 8)  and $0000FF00) or
            ((AValue shl 8)  and $00FF0000) or
            ((AValue shl 24) and $FF000000);
end;

function SwapUInt64(const AValue: UInt64): UInt64;
begin
  Result := ((AValue shr 56) and $00000000000000FF) or
            ((AValue shr 40) and $000000000000FF00) or
            ((AValue shr 24) and $0000000000FF0000) or
            ((AValue shr 8)  and $00000000FF000000) or
            ((AValue shl 8)  and $000000FF00000000) or
            ((AValue shl 24) and $0000FF0000000000) or
            ((AValue shl 40) and $00FF000000000000) or
            ((AValue shl 56) and $FF00000000000000);
end;

{ Conditional swap }

function ToEndian16(const AValue: UInt16; const AEndian: TEndianness): UInt16;
begin
  if AEndian = NATIVE_ENDIAN then
    Result := AValue
  else
    Result := SwapUInt16(AValue);
end;

function ToEndian32(const AValue: UInt32; const AEndian: TEndianness): UInt32;
begin
  if AEndian = NATIVE_ENDIAN then
    Result := AValue
  else
    Result := SwapUInt32(AValue);
end;

function ToEndian64(const AValue: UInt64; const AEndian: TEndianness): UInt64;
begin
  if AEndian = NATIVE_ENDIAN then
    Result := AValue
  else
    Result := SwapUInt64(AValue);
end;

function FromEndian16(const AValue: UInt16; const AEndian: TEndianness): UInt16;
begin
  Result := ToEndian16(AValue, AEndian);
end;

function FromEndian32(const AValue: UInt32; const AEndian: TEndianness): UInt32;
begin
  Result := ToEndian32(AValue, AEndian);
end;

function FromEndian64(const AValue: UInt64; const AEndian: TEndianness): UInt64;
begin
  Result := ToEndian64(AValue, AEndian);
end;

{ Read from pointer }

function ReadUInt16LE(const ASrc: PByte): UInt16;
begin
  Result := UInt16(ASrc[0]) or (UInt16(ASrc[1]) shl 8);
end;

function ReadUInt16BE(const ASrc: PByte): UInt16;
begin
  Result := (UInt16(ASrc[0]) shl 8) or UInt16(ASrc[1]);
end;

function ReadUInt32LE(const ASrc: PByte): UInt32;
begin
  Result := UInt32(ASrc[0]) or (UInt32(ASrc[1]) shl 8) or
            (UInt32(ASrc[2]) shl 16) or (UInt32(ASrc[3]) shl 24);
end;

function ReadUInt32BE(const ASrc: PByte): UInt32;
begin
  Result := (UInt32(ASrc[0]) shl 24) or (UInt32(ASrc[1]) shl 16) or
            (UInt32(ASrc[2]) shl 8) or UInt32(ASrc[3]);
end;

function ReadUInt64LE(const ASrc: PByte): UInt64;
begin
  Result := UInt64(ASrc[0]) or (UInt64(ASrc[1]) shl 8) or
            (UInt64(ASrc[2]) shl 16) or (UInt64(ASrc[3]) shl 24) or
            (UInt64(ASrc[4]) shl 32) or (UInt64(ASrc[5]) shl 40) or
            (UInt64(ASrc[6]) shl 48) or (UInt64(ASrc[7]) shl 56);
end;

function ReadUInt64BE(const ASrc: PByte): UInt64;
begin
  Result := (UInt64(ASrc[0]) shl 56) or (UInt64(ASrc[1]) shl 48) or
            (UInt64(ASrc[2]) shl 40) or (UInt64(ASrc[3]) shl 32) or
            (UInt64(ASrc[4]) shl 24) or (UInt64(ASrc[5]) shl 16) or
            (UInt64(ASrc[6]) shl 8) or UInt64(ASrc[7]);
end;

{ Write to pointer }

procedure WriteUInt16LE(const ADst: PByte; const AValue: UInt16);
begin
  ADst[0] := Byte(AValue);
  ADst[1] := Byte(AValue shr 8);
end;

procedure WriteUInt16BE(const ADst: PByte; const AValue: UInt16);
begin
  ADst[0] := Byte(AValue shr 8);
  ADst[1] := Byte(AValue);
end;

procedure WriteUInt32LE(const ADst: PByte; const AValue: UInt32);
begin
  ADst[0] := Byte(AValue);
  ADst[1] := Byte(AValue shr 8);
  ADst[2] := Byte(AValue shr 16);
  ADst[3] := Byte(AValue shr 24);
end;

procedure WriteUInt32BE(const ADst: PByte; const AValue: UInt32);
begin
  ADst[0] := Byte(AValue shr 24);
  ADst[1] := Byte(AValue shr 16);
  ADst[2] := Byte(AValue shr 8);
  ADst[3] := Byte(AValue);
end;

procedure WriteUInt64LE(const ADst: PByte; const AValue: UInt64);
begin
  ADst[0] := Byte(AValue);
  ADst[1] := Byte(AValue shr 8);
  ADst[2] := Byte(AValue shr 16);
  ADst[3] := Byte(AValue shr 24);
  ADst[4] := Byte(AValue shr 32);
  ADst[5] := Byte(AValue shr 40);
  ADst[6] := Byte(AValue shr 48);
  ADst[7] := Byte(AValue shr 56);
end;

procedure WriteUInt64BE(const ADst: PByte; const AValue: UInt64);
begin
  ADst[0] := Byte(AValue shr 56);
  ADst[1] := Byte(AValue shr 48);
  ADst[2] := Byte(AValue shr 40);
  ADst[3] := Byte(AValue shr 32);
  ADst[4] := Byte(AValue shr 24);
  ADst[5] := Byte(AValue shr 16);
  ADst[6] := Byte(AValue shr 8);
  ADst[7] := Byte(AValue);
end;

{ Advancing cursor reads }

function TryReadUInt8(var ASpan: TByteSpan; out AValue: Byte): Boolean;
begin
  if ASpan.Len < 1 then
    Exit(False);
  AValue := ASpan.Data[0];
  ASpan.Data := ASpan.Data + 1;
  Dec(ASpan.Len);
  Result := True;
end;

function TryReadUInt16LE(var ASpan: TByteSpan; out AValue: UInt16): Boolean;
begin
  if ASpan.Len < 2 then
    Exit(False);
  AValue := ReadUInt16LE(ASpan.Data);
  ASpan.Data := ASpan.Data + 2;
  Dec(ASpan.Len, 2);
  Result := True;
end;

function TryReadUInt16BE(var ASpan: TByteSpan; out AValue: UInt16): Boolean;
begin
  if ASpan.Len < 2 then
    Exit(False);
  AValue := ReadUInt16BE(ASpan.Data);
  ASpan.Data := ASpan.Data + 2;
  Dec(ASpan.Len, 2);
  Result := True;
end;

function TryReadUInt32LE(var ASpan: TByteSpan; out AValue: UInt32): Boolean;
begin
  if ASpan.Len < 4 then
    Exit(False);
  AValue := ReadUInt32LE(ASpan.Data);
  ASpan.Data := ASpan.Data + 4;
  Dec(ASpan.Len, 4);
  Result := True;
end;

function TryReadUInt32BE(var ASpan: TByteSpan; out AValue: UInt32): Boolean;
begin
  if ASpan.Len < 4 then
    Exit(False);
  AValue := ReadUInt32BE(ASpan.Data);
  ASpan.Data := ASpan.Data + 4;
  Dec(ASpan.Len, 4);
  Result := True;
end;

function TryReadUInt64LE(var ASpan: TByteSpan; out AValue: UInt64): Boolean;
begin
  if ASpan.Len < 8 then
    Exit(False);
  AValue := ReadUInt64LE(ASpan.Data);
  ASpan.Data := ASpan.Data + 8;
  Dec(ASpan.Len, 8);
  Result := True;
end;

function TryReadUInt64BE(var ASpan: TByteSpan; out AValue: UInt64): Boolean;
begin
  if ASpan.Len < 8 then
    Exit(False);
  AValue := ReadUInt64BE(ASpan.Data);
  ASpan.Data := ASpan.Data + 8;
  Dec(ASpan.Len, 8);
  Result := True;
end;

{ Advancing cursor writes }

function TryWriteUInt8(var ASpan: TByteSpan; const AValue: Byte): Boolean;
begin
  if ASpan.Len < 1 then
    Exit(False);
  ASpan.Data[0] := AValue;
  ASpan.Data := ASpan.Data + 1;
  Dec(ASpan.Len);
  Result := True;
end;

function TryWriteUInt16LE(var ASpan: TByteSpan; const AValue: UInt16): Boolean;
begin
  if ASpan.Len < 2 then
    Exit(False);
  WriteUInt16LE(ASpan.Data, AValue);
  ASpan.Data := ASpan.Data + 2;
  Dec(ASpan.Len, 2);
  Result := True;
end;

function TryWriteUInt16BE(var ASpan: TByteSpan; const AValue: UInt16): Boolean;
begin
  if ASpan.Len < 2 then
    Exit(False);
  WriteUInt16BE(ASpan.Data, AValue);
  ASpan.Data := ASpan.Data + 2;
  Dec(ASpan.Len, 2);
  Result := True;
end;

function TryWriteUInt32LE(var ASpan: TByteSpan; const AValue: UInt32): Boolean;
begin
  if ASpan.Len < 4 then
    Exit(False);
  WriteUInt32LE(ASpan.Data, AValue);
  ASpan.Data := ASpan.Data + 4;
  Dec(ASpan.Len, 4);
  Result := True;
end;

function TryWriteUInt32BE(var ASpan: TByteSpan; const AValue: UInt32): Boolean;
begin
  if ASpan.Len < 4 then
    Exit(False);
  WriteUInt32BE(ASpan.Data, AValue);
  ASpan.Data := ASpan.Data + 4;
  Dec(ASpan.Len, 4);
  Result := True;
end;

function TryWriteUInt64LE(var ASpan: TByteSpan; const AValue: UInt64): Boolean;
begin
  if ASpan.Len < 8 then
    Exit(False);
  WriteUInt64LE(ASpan.Data, AValue);
  ASpan.Data := ASpan.Data + 8;
  Dec(ASpan.Len, 8);
  Result := True;
end;

function TryWriteUInt64BE(var ASpan: TByteSpan; const AValue: UInt64): Boolean;
begin
  if ASpan.Len < 8 then
    Exit(False);
  WriteUInt64BE(ASpan.Data, AValue);
  ASpan.Data := ASpan.Data + 8;
  Dec(ASpan.Len, 8);
  Result := True;
end;

end.
