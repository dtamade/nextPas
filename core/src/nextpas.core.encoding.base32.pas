unit nextpas.core.encoding.base32;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.encoding.base;

function Base32Encode(const AData: TBytes): string;
function Base32Decode(const AEncoded: string): TBytes;

implementation

const
  BASE32_ALPHABET: array[0..31] of Char =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

var
  DECODE_TABLE: array[0..127] of ShortInt;

procedure InitDecodeTable;
var
  LI: Integer;
begin
  for LI := 0 to 127 do
    DECODE_TABLE[LI] := -1;
  for LI := 0 to 31 do
    DECODE_TABLE[Ord(BASE32_ALPHABET[LI])] := ShortInt(LI);
end;

function Base32Encode(const AData: TBytes): string;
var
  LLen, LOutLen, LI, LJ: Integer;
  LQuintet: UInt64;
begin
  LLen := Length(AData);
  if LLen = 0 then
    Exit('');

  LOutLen := ((LLen + 4) div 5) * 8;
  SetLength(Result, LOutLen);
  LJ := 1;
  LI := 0;

  while LI + 4 < LLen do
  begin
    LQuintet := (UInt64(AData[LI]) shl 32) or (UInt64(AData[LI + 1]) shl 24)
      or (UInt64(AData[LI + 2]) shl 16) or (UInt64(AData[LI + 3]) shl 8)
      or UInt64(AData[LI + 4]);
    Result[LJ]     := BASE32_ALPHABET[(LQuintet shr 35) and $1F];
    Result[LJ + 1] := BASE32_ALPHABET[(LQuintet shr 30) and $1F];
    Result[LJ + 2] := BASE32_ALPHABET[(LQuintet shr 25) and $1F];
    Result[LJ + 3] := BASE32_ALPHABET[(LQuintet shr 20) and $1F];
    Result[LJ + 4] := BASE32_ALPHABET[(LQuintet shr 15) and $1F];
    Result[LJ + 5] := BASE32_ALPHABET[(LQuintet shr 10) and $1F];
    Result[LJ + 6] := BASE32_ALPHABET[(LQuintet shr 5) and $1F];
    Result[LJ + 7] := BASE32_ALPHABET[LQuintet and $1F];
    Inc(LI, 5);
    Inc(LJ, 8);
  end;

  case LLen - LI of
    1:
    begin
      Result[LJ]     := BASE32_ALPHABET[AData[LI] shr 3];
      Result[LJ + 1] := BASE32_ALPHABET[(AData[LI] and $07) shl 2];
      Result[LJ + 2] := '=';
      Result[LJ + 3] := '=';
      Result[LJ + 4] := '=';
      Result[LJ + 5] := '=';
      Result[LJ + 6] := '=';
      Result[LJ + 7] := '=';
    end;
    2:
    begin
      Result[LJ]     := BASE32_ALPHABET[AData[LI] shr 3];
      Result[LJ + 1] := BASE32_ALPHABET[((AData[LI] and $07) shl 2)
        or (AData[LI + 1] shr 6)];
      Result[LJ + 2] := BASE32_ALPHABET[(AData[LI + 1] shr 1) and $1F];
      Result[LJ + 3] := BASE32_ALPHABET[(AData[LI + 1] and $01) shl 4];
      Result[LJ + 4] := '=';
      Result[LJ + 5] := '=';
      Result[LJ + 6] := '=';
      Result[LJ + 7] := '=';
    end;
    3:
    begin
      Result[LJ]     := BASE32_ALPHABET[AData[LI] shr 3];
      Result[LJ + 1] := BASE32_ALPHABET[((AData[LI] and $07) shl 2)
        or (AData[LI + 1] shr 6)];
      Result[LJ + 2] := BASE32_ALPHABET[(AData[LI + 1] shr 1) and $1F];
      Result[LJ + 3] := BASE32_ALPHABET[((AData[LI + 1] and $01) shl 4)
        or (AData[LI + 2] shr 4)];
      Result[LJ + 4] := BASE32_ALPHABET[(AData[LI + 2] and $0F) shl 1];
      Result[LJ + 5] := '=';
      Result[LJ + 6] := '=';
      Result[LJ + 7] := '=';
    end;
    4:
    begin
      Result[LJ]     := BASE32_ALPHABET[AData[LI] shr 3];
      Result[LJ + 1] := BASE32_ALPHABET[((AData[LI] and $07) shl 2)
        or (AData[LI + 1] shr 6)];
      Result[LJ + 2] := BASE32_ALPHABET[(AData[LI + 1] shr 1) and $1F];
      Result[LJ + 3] := BASE32_ALPHABET[((AData[LI + 1] and $01) shl 4)
        or (AData[LI + 2] shr 4)];
      Result[LJ + 4] := BASE32_ALPHABET[((AData[LI + 2] and $0F) shl 1)
        or (AData[LI + 3] shr 7)];
      Result[LJ + 5] := BASE32_ALPHABET[(AData[LI + 3] shr 2) and $1F];
      Result[LJ + 6] := BASE32_ALPHABET[(AData[LI + 3] and $03) shl 3];
      Result[LJ + 7] := '=';
    end;
  end;
end;

function Base32Decode(const AEncoded: string): TBytes;
var
  LLen, LPad, LChars, LOutLen, LJ, LI: Integer;
  LP: PByte;
  LD: PByte;
  LC: array[0..7] of ShortInt;
begin
  Result := nil;
  LLen := Length(AEncoded);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  LPad := 0;
  while (LLen - LPad >= 1) and (AEncoded[LLen - LPad] = '=') do
    Inc(LPad);
  LChars := LLen - LPad;

  if LPad > 0 then
  begin
    if (LLen mod 8) <> 0 then
      raise EConvertError.Create('Invalid base32 padding');
    case LPad of
      1, 3, 4, 6: ;
    else
      raise EConvertError.Create('Invalid base32 padding');
    end;
  end;

  case LChars mod 8 of
    0, 2, 4, 5, 7: ;
  else
    raise EConvertError.Create('Invalid base32 length');
  end;

  for LI := 1 to LChars do
    if AEncoded[LI] = '=' then
      raise EConvertError.Create('Invalid base32 padding');

  LOutLen := (LChars * 5) div 8;
  SetLength(Result, LOutLen);

  LP := PByte(@AEncoded[1]);
  LD := @Result[0];
  LJ := 0;
  LI := 0;

  while LI + 8 <= LChars do
  begin
    if (LP[LI] or LP[LI + 1] or LP[LI + 2] or LP[LI + 3]
      or LP[LI + 4] or LP[LI + 5] or LP[LI + 6] or LP[LI + 7]) > 127 then
      raise EConvertError.Create('Invalid base32 character');
    LC[0] := DECODE_TABLE[LP[LI]];
    LC[1] := DECODE_TABLE[LP[LI + 1]];
    LC[2] := DECODE_TABLE[LP[LI + 2]];
    LC[3] := DECODE_TABLE[LP[LI + 3]];
    LC[4] := DECODE_TABLE[LP[LI + 4]];
    LC[5] := DECODE_TABLE[LP[LI + 5]];
    LC[6] := DECODE_TABLE[LP[LI + 6]];
    LC[7] := DECODE_TABLE[LP[LI + 7]];
    if (LC[0] or LC[1] or LC[2] or LC[3] or LC[4] or LC[5] or LC[6] or LC[7]) < 0 then
      raise EConvertError.Create('Invalid base32 character');
    LD[LJ]     := Byte((LC[0] shl 3) or (LC[1] shr 2));
    LD[LJ + 1] := Byte(((LC[1] and $03) shl 6) or (LC[2] shl 1) or (LC[3] shr 4));
    LD[LJ + 2] := Byte(((LC[3] and $0F) shl 4) or (LC[4] shr 1));
    LD[LJ + 3] := Byte(((LC[4] and $01) shl 7) or (LC[5] shl 2) or (LC[6] shr 3));
    LD[LJ + 4] := Byte(((LC[6] and $07) shl 5) or LC[7]);
    Inc(LJ, 5);
    Inc(LI, 8);
  end;

  case LChars - LI of
    2:
    begin
      if (LP[LI] or LP[LI + 1]) > 127 then
        raise EConvertError.Create('Invalid base32 character');
      LC[0] := DECODE_TABLE[LP[LI]];
      LC[1] := DECODE_TABLE[LP[LI + 1]];
      if (LC[0] or LC[1]) < 0 then
        raise EConvertError.Create('Invalid base32 character');
      if (LC[1] and $03) <> 0 then
        raise EConvertError.Create('Invalid base32 padding bits');
      LD[LJ] := Byte((LC[0] shl 3) or (LC[1] shr 2));
    end;
    4:
    begin
      if (LP[LI] or LP[LI + 1] or LP[LI + 2] or LP[LI + 3]) > 127 then
        raise EConvertError.Create('Invalid base32 character');
      LC[0] := DECODE_TABLE[LP[LI]];
      LC[1] := DECODE_TABLE[LP[LI + 1]];
      LC[2] := DECODE_TABLE[LP[LI + 2]];
      LC[3] := DECODE_TABLE[LP[LI + 3]];
      if (LC[0] or LC[1] or LC[2] or LC[3]) < 0 then
        raise EConvertError.Create('Invalid base32 character');
      if (LC[3] and $0F) <> 0 then
        raise EConvertError.Create('Invalid base32 padding bits');
      LD[LJ]     := Byte((LC[0] shl 3) or (LC[1] shr 2));
      LD[LJ + 1] := Byte(((LC[1] and $03) shl 6) or (LC[2] shl 1) or (LC[3] shr 4));
    end;
    5:
    begin
      if (LP[LI] or LP[LI + 1] or LP[LI + 2] or LP[LI + 3] or LP[LI + 4]) > 127 then
        raise EConvertError.Create('Invalid base32 character');
      LC[0] := DECODE_TABLE[LP[LI]];
      LC[1] := DECODE_TABLE[LP[LI + 1]];
      LC[2] := DECODE_TABLE[LP[LI + 2]];
      LC[3] := DECODE_TABLE[LP[LI + 3]];
      LC[4] := DECODE_TABLE[LP[LI + 4]];
      if (LC[0] or LC[1] or LC[2] or LC[3] or LC[4]) < 0 then
        raise EConvertError.Create('Invalid base32 character');
      if (LC[4] and $01) <> 0 then
        raise EConvertError.Create('Invalid base32 padding bits');
      LD[LJ]     := Byte((LC[0] shl 3) or (LC[1] shr 2));
      LD[LJ + 1] := Byte(((LC[1] and $03) shl 6) or (LC[2] shl 1) or (LC[3] shr 4));
      LD[LJ + 2] := Byte(((LC[3] and $0F) shl 4) or (LC[4] shr 1));
    end;
    7:
    begin
      if (LP[LI] or LP[LI + 1] or LP[LI + 2] or LP[LI + 3]
        or LP[LI + 4] or LP[LI + 5] or LP[LI + 6]) > 127 then
        raise EConvertError.Create('Invalid base32 character');
      LC[0] := DECODE_TABLE[LP[LI]];
      LC[1] := DECODE_TABLE[LP[LI + 1]];
      LC[2] := DECODE_TABLE[LP[LI + 2]];
      LC[3] := DECODE_TABLE[LP[LI + 3]];
      LC[4] := DECODE_TABLE[LP[LI + 4]];
      LC[5] := DECODE_TABLE[LP[LI + 5]];
      LC[6] := DECODE_TABLE[LP[LI + 6]];
      if (LC[0] or LC[1] or LC[2] or LC[3] or LC[4] or LC[5] or LC[6]) < 0 then
        raise EConvertError.Create('Invalid base32 character');
      if (LC[6] and $07) <> 0 then
        raise EConvertError.Create('Invalid base32 padding bits');
      LD[LJ]     := Byte((LC[0] shl 3) or (LC[1] shr 2));
      LD[LJ + 1] := Byte(((LC[1] and $03) shl 6) or (LC[2] shl 1) or (LC[3] shr 4));
      LD[LJ + 2] := Byte(((LC[3] and $0F) shl 4) or (LC[4] shr 1));
      LD[LJ + 3] := Byte(((LC[4] and $01) shl 7) or (LC[5] shl 2) or (LC[6] shr 3));
    end;
  end;
end;

initialization
  InitDecodeTable;

end.
