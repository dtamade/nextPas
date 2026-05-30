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
  LLen, LI, LJ: Integer;
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

  SetLength(Result, LLen div 2);
  LJ := 0;
  LI := 1;
  while LI < LLen do
  begin
    Result[LJ] := (HexCharToNibble(AHex[LI]) shl 4) or HexCharToNibble(AHex[LI + 1]);
    Inc(LI, 2);
    Inc(LJ);
  end;
end;

end.
