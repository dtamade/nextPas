unit nextpas.core.text.char;

{$I nextpas.core.settings.inc}

interface

type
  TCharClass = Byte;

const
  ccDigit       = TCharClass($01);
  ccAlpha       = TCharClass($02);
  ccHexDigit    = TCharClass($04);
  ccWhitespace  = TCharClass($08);
  ccControl     = TCharClass($10);
  ccJsonSpecial = TCharClass($20);
  ccUpper       = TCharClass($40);
  ccLower       = TCharClass($80);

function CharClass(const ACh: Byte): TCharClass; inline;
function IsDigit(const ACh: Byte): Boolean; inline;
function IsAlpha(const ACh: Byte): Boolean; inline;
function IsAlphaNum(const ACh: Byte): Boolean; inline;
function IsUpper(const ACh: Byte): Boolean; inline;
function IsLower(const ACh: Byte): Boolean; inline;
function IsHexDigit(const ACh: Byte): Boolean; inline;
function IsWhitespace(const ACh: Byte): Boolean; inline;
function IsControl(const ACh: Byte): Boolean; inline;
function IsJsonSpecial(const ACh: Byte): Boolean; inline;
function IsAscii(const ACh: Byte): Boolean; inline;
function HexDigitValue(const ACh: Byte): Int32; inline;
function ToLower(const ACh: Byte): Byte; inline;
function ToUpper(const ACh: Byte): Byte; inline;

implementation

const
  CharClassTable: array[0..255] of TCharClass = (
    {00} ccControl or ccJsonSpecial, ccControl or ccJsonSpecial,
    {02} ccControl or ccJsonSpecial, ccControl or ccJsonSpecial,
    {04} ccControl or ccJsonSpecial, ccControl or ccJsonSpecial,
    {06} ccControl or ccJsonSpecial, ccControl or ccJsonSpecial,
    {08} ccControl or ccJsonSpecial, ccControl or ccJsonSpecial or ccWhitespace,
    {0A} ccControl or ccJsonSpecial or ccWhitespace, ccControl or ccJsonSpecial,
    {0C} ccControl or ccJsonSpecial, ccControl or ccJsonSpecial or ccWhitespace,
    {0E} ccControl or ccJsonSpecial, ccControl or ccJsonSpecial,
    {10} ccControl or ccJsonSpecial, ccControl or ccJsonSpecial,
    {12} ccControl or ccJsonSpecial, ccControl or ccJsonSpecial,
    {14} ccControl or ccJsonSpecial, ccControl or ccJsonSpecial,
    {16} ccControl or ccJsonSpecial, ccControl or ccJsonSpecial,
    {18} ccControl or ccJsonSpecial, ccControl or ccJsonSpecial,
    {1A} ccControl or ccJsonSpecial, ccControl or ccJsonSpecial,
    {1C} ccControl or ccJsonSpecial, ccControl or ccJsonSpecial,
    {1E} ccControl or ccJsonSpecial, ccControl or ccJsonSpecial,
    {20} ccWhitespace,
    {21} 0, {22 "} ccJsonSpecial, {23} 0, {24} 0, {25} 0, {26} 0, {27} 0,
    {28} 0, {29} 0, {2A} 0, {2B} 0, {2C} 0, {2D} 0, {2E} 0, {2F} 0,
    {30} ccDigit or ccHexDigit, {31} ccDigit or ccHexDigit,
    {32} ccDigit or ccHexDigit, {33} ccDigit or ccHexDigit,
    {34} ccDigit or ccHexDigit, {35} ccDigit or ccHexDigit,
    {36} ccDigit or ccHexDigit, {37} ccDigit or ccHexDigit,
    {38} ccDigit or ccHexDigit, {39} ccDigit or ccHexDigit,
    {3A} 0, {3B} 0, {3C} 0, {3D} 0, {3E} 0, {3F} 0,
    {40} 0,
    {41} ccAlpha or ccUpper or ccHexDigit, {42} ccAlpha or ccUpper or ccHexDigit,
    {43} ccAlpha or ccUpper or ccHexDigit, {44} ccAlpha or ccUpper or ccHexDigit,
    {45} ccAlpha or ccUpper or ccHexDigit, {46} ccAlpha or ccUpper or ccHexDigit,
    {47} ccAlpha or ccUpper, {48} ccAlpha or ccUpper,
    {49} ccAlpha or ccUpper, {4A} ccAlpha or ccUpper,
    {4B} ccAlpha or ccUpper, {4C} ccAlpha or ccUpper,
    {4D} ccAlpha or ccUpper, {4E} ccAlpha or ccUpper,
    {4F} ccAlpha or ccUpper, {50} ccAlpha or ccUpper,
    {51} ccAlpha or ccUpper, {52} ccAlpha or ccUpper,
    {53} ccAlpha or ccUpper, {54} ccAlpha or ccUpper,
    {55} ccAlpha or ccUpper, {56} ccAlpha or ccUpper,
    {57} ccAlpha or ccUpper, {58} ccAlpha or ccUpper,
    {59} ccAlpha or ccUpper, {5A} ccAlpha or ccUpper,
    {5B} 0, {5C \} ccJsonSpecial, {5D} 0, {5E} 0, {5F} 0, {60} 0,
    {61} ccAlpha or ccLower or ccHexDigit, {62} ccAlpha or ccLower or ccHexDigit,
    {63} ccAlpha or ccLower or ccHexDigit, {64} ccAlpha or ccLower or ccHexDigit,
    {65} ccAlpha or ccLower or ccHexDigit, {66} ccAlpha or ccLower or ccHexDigit,
    {67} ccAlpha or ccLower, {68} ccAlpha or ccLower,
    {69} ccAlpha or ccLower, {6A} ccAlpha or ccLower,
    {6B} ccAlpha or ccLower, {6C} ccAlpha or ccLower,
    {6D} ccAlpha or ccLower, {6E} ccAlpha or ccLower,
    {6F} ccAlpha or ccLower, {70} ccAlpha or ccLower,
    {71} ccAlpha or ccLower, {72} ccAlpha or ccLower,
    {73} ccAlpha or ccLower, {74} ccAlpha or ccLower,
    {75} ccAlpha or ccLower, {76} ccAlpha or ccLower,
    {77} ccAlpha or ccLower, {78} ccAlpha or ccLower,
    {79} ccAlpha or ccLower, {7A} ccAlpha or ccLower,
    {7B} 0, {7C} 0, {7D} 0, {7E} 0, {7F} ccControl,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
  );

function CharClass(const ACh: Byte): TCharClass;
begin
  Result := CharClassTable[ACh];
end;

function IsDigit(const ACh: Byte): Boolean;
begin
  Result := (CharClassTable[ACh] and ccDigit) <> 0;
end;

function IsAlpha(const ACh: Byte): Boolean;
begin
  Result := (CharClassTable[ACh] and ccAlpha) <> 0;
end;

function IsAlphaNum(const ACh: Byte): Boolean;
begin
  Result := (CharClassTable[ACh] and (ccAlpha or ccDigit)) <> 0;
end;

function IsUpper(const ACh: Byte): Boolean;
begin
  Result := (CharClassTable[ACh] and ccUpper) <> 0;
end;

function IsLower(const ACh: Byte): Boolean;
begin
  Result := (CharClassTable[ACh] and ccLower) <> 0;
end;

function IsHexDigit(const ACh: Byte): Boolean;
begin
  Result := (CharClassTable[ACh] and ccHexDigit) <> 0;
end;

function IsWhitespace(const ACh: Byte): Boolean;
begin
  Result := (CharClassTable[ACh] and ccWhitespace) <> 0;
end;

function IsControl(const ACh: Byte): Boolean;
begin
  Result := (CharClassTable[ACh] and ccControl) <> 0;
end;

function IsJsonSpecial(const ACh: Byte): Boolean;
begin
  Result := (CharClassTable[ACh] and ccJsonSpecial) <> 0;
end;

function IsAscii(const ACh: Byte): Boolean;
begin
  Result := ACh < 128;
end;

function HexDigitValue(const ACh: Byte): Int32;
begin
  case ACh of
    Ord('0')..Ord('9'): Result := ACh - Ord('0');
    Ord('A')..Ord('F'): Result := ACh - Ord('A') + 10;
    Ord('a')..Ord('f'): Result := ACh - Ord('a') + 10;
  else
    Result := -1;
  end;
end;

function ToLower(const ACh: Byte): Byte;
begin
  if (CharClassTable[ACh] and ccUpper) <> 0 then
    Result := ACh or $20
  else
    Result := ACh;
end;

function ToUpper(const ACh: Byte): Byte;
begin
  if (CharClassTable[ACh] and ccLower) <> 0 then
    Result := ACh and not Byte($20)
  else
    Result := ACh;
end;

end.
