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
  LLen, LI, LJ, LPad, LOutLen: Integer;
  LVal: ShortInt;
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

  LAccum := 0;
  LBits := 0;
  LJ := 0;

  for LI := 1 to LLen do
  begin
    if AEncoded[LI] = '=' then
      Break;
    if Ord(AEncoded[LI]) > 127 then
      raise EConvertError.CreateFmt('Invalid base64 character: %s', [AEncoded[LI]]);
    LVal := ATable[Ord(AEncoded[LI])];
    if LVal < 0 then
      raise EConvertError.CreateFmt('Invalid base64 character: %s', [AEncoded[LI]]);
    LAccum := (LAccum shl 6) or UInt32(LVal);
    Inc(LBits, 6);
    if LBits >= 8 then
    begin
      Dec(LBits, 8);
      if LJ < LOutLen then
      begin
        Result[LJ] := Byte((LAccum shr LBits) and $FF);
        Inc(LJ);
      end;
    end;
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
