unit nextpas.core.encoding.hex;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.encoding.base;

function HexEncode(const AData: TBytes; const ACase: THexCase = hcLower): string;
function HexDecode(const AHex: string): TBytes;

implementation

const
  HEX_LOWER: array[0..15] of Char = '0123456789abcdef';
  HEX_UPPER: array[0..15] of Char = '0123456789ABCDEF';

var
  HEX_DECODE_TABLE: array[0..255] of ShortInt;
  HexDecodeTableInitialized: Boolean = False;

procedure InitHexDecodeTable;
var i: Integer;
begin
  if HexDecodeTableInitialized then Exit;
  FillChar(HEX_DECODE_TABLE, SizeOf(HEX_DECODE_TABLE), -1);
  for i := 0 to 9 do
  begin
    HEX_DECODE_TABLE[Ord('0') + i] := i;
  end;
  for i := 0 to 5 do
  begin
    HEX_DECODE_TABLE[Ord('a') + i] := 10 + i;
    HEX_DECODE_TABLE[Ord('A') + i] := 10 + i;
  end;
  HexDecodeTableInitialized := True;
end;

function HexEncode(const AData: TBytes; const ACase: THexCase): string;
var
  LI, LJ, LLen: Integer;
  LP: PByte;
  LD: PChar;
  LTable: PChar;
begin
  LLen := Length(AData);
  if LLen = 0 then
    Exit('');

  SetLength(Result, LLen * 2);
  LP := @AData[0];
  LD := @Result[1];

  case ACase of
    hcLower: LTable := @HEX_LOWER[0];
    hcUpper: LTable := @HEX_UPPER[0];
  end;

  LI := 0;
  while LI + 4 <= LLen do
  begin
    LD[0] := LTable[LP[LI] shr 4];
    LD[1] := LTable[LP[LI] and $0F];
    LD[2] := LTable[LP[LI+1] shr 4];
    LD[3] := LTable[LP[LI+1] and $0F];
    LD[4] := LTable[LP[LI+2] shr 4];
    LD[5] := LTable[LP[LI+2] and $0F];
    LD[6] := LTable[LP[LI+3] shr 4];
    LD[7] := LTable[LP[LI+3] and $0F];
    Inc(LI, 4);
    Inc(LD, 8);
  end;
  while LI < LLen do
  begin
    LD[0] := LTable[LP[LI] shr 4];
    LD[1] := LTable[LP[LI] and $0F];
    Inc(LI);
    Inc(LD, 2);
  end;
end;

function HexCharToNibble(const ACh: Char): Byte; inline;
begin
  case ACh of
    '0'..'9': Result := Ord(ACh) - Ord('0');
    'a'..'f': Result := Ord(ACh) - Ord('a') + 10;
    'A'..'F': Result := Ord(ACh) - Ord('A') + 10;
  else
    raise EConvertError.CreateFmt('Invalid hex character: %s', [ACh]);
  end;
end;

function HexDecode(const AHex: string): TBytes;
var
  LLen, LI: Integer;
  LP: PByte;
  LD: PByte;
  LHi, LLo: ShortInt;
begin
  Result := nil;
  LLen := Length(AHex);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  if (LLen mod 2) <> 0 then
    raise EConvertError.Create('Hex string must have even length');

  InitHexDecodeTable;
  SetLength(Result, LLen div 2);
  LP := PByte(@AHex[1]);
  LD := @Result[0];

  LI := 0;
  while LI + 8 <= LLen do
  begin
    LHi := HEX_DECODE_TABLE[LP[LI]]; LLo := HEX_DECODE_TABLE[LP[LI+1]];
    if (LHi or LLo) < 0 then raise EConvertError.Create('Invalid hex character');
    LD^ := Byte(LHi shl 4) or Byte(LLo); Inc(LD);

    LHi := HEX_DECODE_TABLE[LP[LI+2]]; LLo := HEX_DECODE_TABLE[LP[LI+3]];
    if (LHi or LLo) < 0 then raise EConvertError.Create('Invalid hex character');
    LD^ := Byte(LHi shl 4) or Byte(LLo); Inc(LD);

    LHi := HEX_DECODE_TABLE[LP[LI+4]]; LLo := HEX_DECODE_TABLE[LP[LI+5]];
    if (LHi or LLo) < 0 then raise EConvertError.Create('Invalid hex character');
    LD^ := Byte(LHi shl 4) or Byte(LLo); Inc(LD);

    LHi := HEX_DECODE_TABLE[LP[LI+6]]; LLo := HEX_DECODE_TABLE[LP[LI+7]];
    if (LHi or LLo) < 0 then raise EConvertError.Create('Invalid hex character');
    LD^ := Byte(LHi shl 4) or Byte(LLo); Inc(LD);

    Inc(LI, 8);
  end;
  while LI + 2 <= LLen do
  begin
    LHi := HEX_DECODE_TABLE[LP[LI]]; LLo := HEX_DECODE_TABLE[LP[LI+1]];
    if (LHi or LLo) < 0 then raise EConvertError.Create('Invalid hex character');
    LD^ := Byte(LHi shl 4) or Byte(LLo); Inc(LD);
    Inc(LI, 2);
  end;
end;

end.
