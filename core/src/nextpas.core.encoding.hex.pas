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
  LI, LJ: Integer;
begin
  if Length(AData) = 0 then
    Exit('');

  SetLength(Result, Length(AData) * 2);
  LJ := 1;

  case ACase of
    hcLower:
      for LI := 0 to High(AData) do
      begin
        Result[LJ]     := HEX_LOWER[AData[LI] shr 4];
        Result[LJ + 1] := HEX_LOWER[AData[LI] and $0F];
        Inc(LJ, 2);
      end;
    hcUpper:
      for LI := 0 to High(AData) do
      begin
        Result[LJ]     := HEX_UPPER[AData[LI] shr 4];
        Result[LJ + 1] := HEX_UPPER[AData[LI] and $0F];
        Inc(LJ, 2);
      end;
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
