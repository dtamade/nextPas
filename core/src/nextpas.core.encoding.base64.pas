unit nextpas.core.encoding.base64;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.encoding.base;

function Base64Encode(const AData: TBytes): string;
function Base64Decode(const AEncoded: string): TBytes;
function Base64UrlEncode(const AData: TBytes): string;
function Base64UrlDecode(const AEncoded: string): TBytes;

implementation

const
  STANDARD_ALPHABET: array[0..63] of Char =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  URLSAFE_ALPHABET: array[0..63] of Char =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

var
  DECODE_TABLE: array[0..127] of ShortInt;
  DECODE_TABLE_URL: array[0..127] of ShortInt;

procedure InitDecodeTables;
var
  LI: Integer;
begin
  for LI := 0 to 127 do
  begin
    DECODE_TABLE[LI] := -1;
    DECODE_TABLE_URL[LI] := -1;
  end;
  for LI := 0 to 63 do
  begin
    DECODE_TABLE[Ord(STANDARD_ALPHABET[LI])] := ShortInt(LI);
    DECODE_TABLE_URL[Ord(URLSAFE_ALPHABET[LI])] := ShortInt(LI);
  end;
end;

function DoEncode(const AData: TBytes; const AAlphabet: array of Char; APad: Boolean): string;
var
  LLen, LOutLen, LI, LJ: Integer;
  LTriple: UInt32;
begin
  LLen := Length(AData);
  if LLen = 0 then
    Exit('');

  LOutLen := ((LLen + 2) div 3) * 4;
  SetLength(Result, LOutLen);
  LJ := 1;
  LI := 0;

  while LI + 2 < LLen do
  begin
    LTriple := (UInt32(AData[LI]) shl 16) or (UInt32(AData[LI + 1]) shl 8) or UInt32(AData[LI + 2]);
    Result[LJ]     := AAlphabet[(LTriple shr 18) and $3F];
    Result[LJ + 1] := AAlphabet[(LTriple shr 12) and $3F];
    Result[LJ + 2] := AAlphabet[(LTriple shr 6) and $3F];
    Result[LJ + 3] := AAlphabet[LTriple and $3F];
    Inc(LI, 3);
    Inc(LJ, 4);
  end;

  case LLen - LI of
    1:
    begin
      LTriple := UInt32(AData[LI]) shl 16;
      Result[LJ]     := AAlphabet[(LTriple shr 18) and $3F];
      Result[LJ + 1] := AAlphabet[(LTriple shr 12) and $3F];
      if APad then
      begin
        Result[LJ + 2] := '=';
        Result[LJ + 3] := '=';
      end
      else
        SetLength(Result, LJ + 1);
    end;
    2:
    begin
      LTriple := (UInt32(AData[LI]) shl 16) or (UInt32(AData[LI + 1]) shl 8);
      Result[LJ]     := AAlphabet[(LTriple shr 18) and $3F];
      Result[LJ + 1] := AAlphabet[(LTriple shr 12) and $3F];
      Result[LJ + 2] := AAlphabet[(LTriple shr 6) and $3F];
      if APad then
        Result[LJ + 3] := '='
      else
        SetLength(Result, LJ + 2);
    end;
  end;
end;

function DoDecode(const AEncoded: string; const ATable: array of ShortInt): TBytes;
var
  LLen, LPad, LOutLen, LJ: Integer;
  LP: PByte;
  LD: PByte;
  LA, LB, LC, LE: ShortInt;
  LI: Integer;
  LAccum: UInt32;
  LBits: Integer;
begin
  Result := nil;
  LLen := Length(AEncoded);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  LPad := 0;
  if (LLen >= 1) and (AEncoded[LLen] = '=') then Inc(LPad);
  if (LLen >= 2) and (AEncoded[LLen - 1] = '=') then Inc(LPad);

  LOutLen := (LLen * 3) div 4 - LPad;
  SetLength(Result, LOutLen);

  LP := PByte(@AEncoded[1]);
  LD := @Result[0];
  LJ := 0;
  LI := 0;

  while LI + 4 <= LLen - LPad do
  begin
    LA := ATable[LP[LI]];
    LB := ATable[LP[LI+1]];
    LC := ATable[LP[LI+2]];
    LE := ATable[LP[LI+3]];
    if (LA or LB or LC or LE) < 0 then
      raise EConvertError.Create('Invalid base64 character');
    LD[LJ]   := Byte((LA shl 2) or (LB shr 4));
    LD[LJ+1] := Byte(((LB and $0F) shl 4) or (LC shr 2));
    LD[LJ+2] := Byte(((LC and $03) shl 6) or LE);
    Inc(LJ, 3);
    Inc(LI, 4);
  end;

  // Handle remaining (with padding)
  LAccum := 0;
  LBits := 0;
  while LI < LLen do
  begin
    if AEncoded[LI + 1] = '=' then Break;
    if LP[LI] > 127 then
      raise EConvertError.Create('Invalid base64 character');
    LA := ATable[LP[LI]];
    if LA < 0 then
      raise EConvertError.Create('Invalid base64 character');
    LAccum := (LAccum shl 6) or UInt32(LA);
    Inc(LBits, 6);
    if LBits >= 8 then
    begin
      Dec(LBits, 8);
      if LJ < LOutLen then
      begin
        LD[LJ] := Byte((LAccum shr LBits) and $FF);
        Inc(LJ);
      end;
    end;
    Inc(LI);
  end;
end;

function Base64Encode(const AData: TBytes): string;
begin
  Result := DoEncode(AData, STANDARD_ALPHABET, True);
end;

function Base64Decode(const AEncoded: string): TBytes;
begin
  Result := DoDecode(AEncoded, DECODE_TABLE);
end;

function Base64UrlEncode(const AData: TBytes): string;
begin
  Result := DoEncode(AData, URLSAFE_ALPHABET, False);
end;

function Base64UrlDecode(const AEncoded: string): TBytes;
begin
  Result := DoDecode(AEncoded, DECODE_TABLE_URL);
end;

initialization
  InitDecodeTables;

end.
