unit nextpas.core.text.utf8;

{$I nextpas.core.settings.inc}

interface

type
  TUTF8DecodeResult = record
    CodePoint: UInt32;
    ByteLen: Byte;
  end;

  TUTF8Iterator = record
  private
    FData: PByte;
    FLen: SizeUInt;
    FPos: SizeUInt;
  public
    procedure Init(const AData: PByte; const ALen: SizeUInt);
    function Next(out ACodePoint: UInt32): Boolean;
    function HasNext: Boolean; inline;
    function Position: SizeUInt; inline;
    function Remaining: SizeUInt; inline;
  end;

function UTF8IsValid(const AData: PByte; const ALen: SizeUInt): Boolean;
function UTF8Decode(const AData: PByte; const ALen: SizeUInt): TUTF8DecodeResult;
function UTF8Encode(const ACodePoint: UInt32; const ADst: PByte): Byte;
function UTF8CodePointCount(const AData: PByte; const ALen: SizeUInt): SizeUInt;
function UTF8ByteLength(const ALeadByte: Byte): Byte; inline;

implementation

uses
  nextpas.core.simd.api.v2;

function UTF8ByteLength(const ALeadByte: Byte): Byte;
begin
  if ALeadByte < $80 then
    Result := 1
  else if (ALeadByte and $E0) = $C0 then
    Result := 2
  else if (ALeadByte and $F0) = $E0 then
    Result := 3
  else if (ALeadByte and $F8) = $F0 then
    Result := 4
  else
    Result := 1;
end;

function UTF8Decode(const AData: PByte; const ALen: SizeUInt): TUTF8DecodeResult;
var
  B: Byte;
begin
  Result.CodePoint := 0;
  Result.ByteLen := 0;
  if ALen = 0 then
    Exit;
  B := AData[0];
  if B < $80 then
  begin
    Result.CodePoint := B;
    Result.ByteLen := 1;
  end
  else if (B and $E0) = $C0 then
  begin
    if ALen < 2 then Exit;
    if (AData[1] and $C0) <> $80 then Exit;
    Result.CodePoint := (UInt32(B and $1F) shl 6) or
                        (UInt32(AData[1]) and $3F);
    if Result.CodePoint < $80 then begin Result.ByteLen := 0; Exit; end;
    Result.ByteLen := 2;
  end
  else if (B and $F0) = $E0 then
  begin
    if ALen < 3 then Exit;
    if ((AData[1] and $C0) <> $80) or ((AData[2] and $C0) <> $80) then Exit;
    Result.CodePoint := (UInt32(B and $0F) shl 12) or
                        ((UInt32(AData[1]) and $3F) shl 6) or
                        (UInt32(AData[2]) and $3F);
    if Result.CodePoint < $800 then begin Result.ByteLen := 0; Exit; end;
    if (Result.CodePoint >= $D800) and (Result.CodePoint <= $DFFF) then
      begin Result.ByteLen := 0; Exit; end;
    Result.ByteLen := 3;
  end
  else if (B and $F8) = $F0 then
  begin
    if ALen < 4 then Exit;
    if ((AData[1] and $C0) <> $80) or ((AData[2] and $C0) <> $80) or
       ((AData[3] and $C0) <> $80) then Exit;
    Result.CodePoint := (UInt32(B and $07) shl 18) or
                        ((UInt32(AData[1]) and $3F) shl 12) or
                        ((UInt32(AData[2]) and $3F) shl 6) or
                        (UInt32(AData[3]) and $3F);
    if Result.CodePoint < $10000 then begin Result.ByteLen := 0; Exit; end;
    if Result.CodePoint > $10FFFF then begin Result.ByteLen := 0; Exit; end;
    Result.ByteLen := 4;
  end;
end;

function UTF8Encode(const ACodePoint: UInt32; const ADst: PByte): Byte;
begin
  if ACodePoint < $80 then
  begin
    ADst[0] := Byte(ACodePoint);
    Result := 1;
  end
  else if ACodePoint < $800 then
  begin
    ADst[0] := Byte($C0 or (ACodePoint shr 6));
    ADst[1] := Byte($80 or (ACodePoint and $3F));
    Result := 2;
  end
  else if ACodePoint < $10000 then
  begin
    if (ACodePoint >= $D800) and (ACodePoint <= $DFFF) then
      begin Result := 0; Exit; end;
    ADst[0] := Byte($E0 or (ACodePoint shr 12));
    ADst[1] := Byte($80 or ((ACodePoint shr 6) and $3F));
    ADst[2] := Byte($80 or (ACodePoint and $3F));
    Result := 3;
  end
  else if ACodePoint <= $10FFFF then
  begin
    ADst[0] := Byte($F0 or (ACodePoint shr 18));
    ADst[1] := Byte($80 or ((ACodePoint shr 12) and $3F));
    ADst[2] := Byte($80 or ((ACodePoint shr 6) and $3F));
    ADst[3] := Byte($80 or (ACodePoint and $3F));
    Result := 4;
  end
  else
    Result := 0;
end;

function UTF8IsValid(const AData: PByte; const ALen: SizeUInt): Boolean;
begin
  if ALen = 0 then
    Exit(True);
  Result := nextpas.core.simd.api.v2.Utf8Validate(AData, ALen);
end;

function UTF8CodePointCount(const AData: PByte; const ALen: SizeUInt): SizeUInt;
var
  I: SizeUInt;
begin
  Result := 0;
  for I := 0 to ALen - 1 do
    if (AData[I] and $C0) <> $80 then
      Inc(Result);
end;

procedure TUTF8Iterator.Init(const AData: PByte; const ALen: SizeUInt);
begin
  FData := AData;
  FLen := ALen;
  FPos := 0;
end;

function TUTF8Iterator.HasNext: Boolean;
begin
  Result := FPos < FLen;
end;

function TUTF8Iterator.Position: SizeUInt;
begin
  Result := FPos;
end;

function TUTF8Iterator.Remaining: SizeUInt;
begin
  Result := FLen - FPos;
end;

function TUTF8Iterator.Next(out ACodePoint: UInt32): Boolean;
var
  LDec: TUTF8DecodeResult;
begin
  if FPos >= FLen then
  begin
    ACodePoint := 0;
    Exit(False);
  end;
  LDec := UTF8Decode(@FData[FPos], FLen - FPos);
  if LDec.ByteLen = 0 then
  begin
    ACodePoint := $FFFD;
    Inc(FPos);
  end
  else
  begin
    ACodePoint := LDec.CodePoint;
    Inc(FPos, LDec.ByteLen);
  end;
  Result := True;
end;

end.
