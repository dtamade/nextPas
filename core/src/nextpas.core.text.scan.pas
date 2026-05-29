unit nextpas.core.text.scan;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.view;

function ScanFindByte(const AData: PAnsiChar; const ALen: SizeUInt;
  const A: Byte): PtrInt;
function ScanFindByte2(const AData: PAnsiChar; const ALen: SizeUInt;
  const A, B: Byte): PtrInt;
function ScanFindByte3(const AData: PAnsiChar; const ALen: SizeUInt;
  const A, B, C: Byte): PtrInt;
function ScanFindInRange(const AData: PAnsiChar; const ALen: SizeUInt;
  const ALo, AHi: Byte): PtrInt;
function ScanFindNotInRange(const AData: PAnsiChar; const ALen: SizeUInt;
  const ALo, AHi: Byte): PtrInt;
function ScanSkipWhitespace(const AData: PAnsiChar; const ALen: SizeUInt): SizeUInt;
function ScanJsonNumber(const AData: PAnsiChar; const ALen: SizeUInt): SizeUInt;
function ScanMatchLiteral(const AData: PAnsiChar; const ALen: SizeUInt;
  const AExpected: PAnsiChar; const AExpectedLen: Byte): Boolean; inline;
procedure ViewSkipWhitespace(var AView: TStringView); inline;
function ViewMatchLiteral(var AView: TStringView;
  const AExpected: PAnsiChar; const AExpectedLen: Byte): Boolean; inline;

implementation

uses
  nextpas.core.simd.base,
  nextpas.core.simd.vec16,
{$IFDEF HAS_AVX2}
  nextpas.core.simd.vec32,
{$ENDIF}
  nextpas.core.text.char;

function ScanFindByte(const AData: PAnsiChar; const ALen: SizeUInt;
  const A: Byte): PtrInt;
var
  LPos: SizeUInt;
  LMask16: TMask16;
{$IFDEF HAS_AVX2}
  LMask32: TMask32;
{$ENDIF}
begin
  LPos := 0;
{$IFDEF HAS_AVX2}
  while LPos + 32 <= ALen do
  begin
    LMask32 := Vec32CmpEq(@AData[LPos], A);
    if LMask32 <> MASK32_NONE_SET then
      Exit(PtrInt(LPos) + Vec32Ctz(LMask32));
    Inc(LPos, 32);
  end;
{$ENDIF}
  while LPos + 16 <= ALen do
  begin
    LMask16 := Vec16CmpEq(@AData[LPos], A);
    if LMask16 <> MASK16_NONE_SET then
      Exit(PtrInt(LPos) + Vec16Ctz(LMask16));
    Inc(LPos, 16);
  end;
  while LPos < ALen do
  begin
    if Byte(AData[LPos]) = A then
      Exit(PtrInt(LPos));
    Inc(LPos);
  end;
  Result := -1;
end;

function ScanFindByte2(const AData: PAnsiChar; const ALen: SizeUInt;
  const A, B: Byte): PtrInt;
var
  LPos: SizeUInt;
  LCombined16: TMask16;
{$IFDEF HAS_AVX2}
  LCombined32: TMask32;
{$ENDIF}
begin
  LPos := 0;
{$IFDEF HAS_AVX2}
  while LPos + 32 <= ALen do
  begin
    LCombined32 := Vec32CmpEq(@AData[LPos], A) or Vec32CmpEq(@AData[LPos], B);
    if LCombined32 <> MASK32_NONE_SET then
      Exit(PtrInt(LPos) + Vec32Ctz(LCombined32));
    Inc(LPos, 32);
  end;
{$ENDIF}
  while LPos + 16 <= ALen do
  begin
    LCombined16 := Vec16CmpEq(@AData[LPos], A) or Vec16CmpEq(@AData[LPos], B);
    if LCombined16 <> MASK16_NONE_SET then
      Exit(PtrInt(LPos) + Vec16Ctz(LCombined16));
    Inc(LPos, 16);
  end;
  while LPos < ALen do
  begin
    if (Byte(AData[LPos]) = A) or (Byte(AData[LPos]) = B) then
      Exit(PtrInt(LPos));
    Inc(LPos);
  end;
  Result := -1;
end;

function ScanFindByte3(const AData: PAnsiChar; const ALen: SizeUInt;
  const A, B, C: Byte): PtrInt;
var
  LPos: SizeUInt;
  LCombined: TMask16;
begin
  LPos := 0;
  while LPos + 16 <= ALen do
  begin
    LCombined := Vec16CmpEq(@AData[LPos], A) or
                 Vec16CmpEq(@AData[LPos], B) or
                 Vec16CmpEq(@AData[LPos], C);
    if LCombined <> MASK16_NONE_SET then
      Exit(PtrInt(LPos) + Vec16Ctz(LCombined));
    Inc(LPos, 16);
  end;
  while LPos < ALen do
  begin
    if (Byte(AData[LPos]) = A) or (Byte(AData[LPos]) = B) or
       (Byte(AData[LPos]) = C) then
      Exit(PtrInt(LPos));
    Inc(LPos);
  end;
  Result := -1;
end;

function ScanFindInRange(const AData: PAnsiChar; const ALen: SizeUInt;
  const ALo, AHi: Byte): PtrInt;
var
  LPos: SizeUInt;
  LMask: TMask16;
begin
  LPos := 0;
  while LPos + 16 <= ALen do
  begin
    LMask := Vec16CmpRange(@AData[LPos], ALo, AHi);
    if LMask <> MASK16_NONE_SET then
      Exit(PtrInt(LPos) + Vec16Ctz(LMask));
    Inc(LPos, 16);
  end;
  while LPos < ALen do
  begin
    if (Byte(AData[LPos]) >= ALo) and (Byte(AData[LPos]) <= AHi) then
      Exit(PtrInt(LPos));
    Inc(LPos);
  end;
  Result := -1;
end;

function ScanFindNotInRange(const AData: PAnsiChar; const ALen: SizeUInt;
  const ALo, AHi: Byte): PtrInt;
var
  LPos: SizeUInt;
  LMask: TMask16;
begin
  LPos := 0;
  while LPos + 16 <= ALen do
  begin
    LMask := not Vec16CmpRange(@AData[LPos], ALo, AHi);
    LMask := LMask and MASK16_ALL_SET;
    if LMask <> MASK16_NONE_SET then
      Exit(PtrInt(LPos) + Vec16Ctz(LMask));
    Inc(LPos, 16);
  end;
  while LPos < ALen do
  begin
    if (Byte(AData[LPos]) < ALo) or (Byte(AData[LPos]) > AHi) then
      Exit(PtrInt(LPos));
    Inc(LPos);
  end;
  Result := -1;
end;

function ScanSkipWhitespace(const AData: PAnsiChar; const ALen: SizeUInt): SizeUInt;
var
  LPos: SizeUInt;
  LWsMask16: TMask16;
{$IFDEF HAS_AVX2}
  LWsMask32: TMask32;
{$ENDIF}
begin
  LPos := 0;
{$IFDEF HAS_AVX2}
  while LPos + 32 <= ALen do
  begin
    LWsMask32 := Vec32CmpEq(@AData[LPos], $20) or Vec32CmpEq(@AData[LPos], $09) or
                 Vec32CmpEq(@AData[LPos], $0A) or Vec32CmpEq(@AData[LPos], $0D);
    if LWsMask32 = MASK32_ALL_SET then
      Inc(LPos, 32)
    else
    begin
      LWsMask32 := (not LWsMask32) and MASK32_ALL_SET;
      Exit(LPos + SizeUInt(Vec32Ctz(LWsMask32)));
    end;
  end;
{$ENDIF}
  while LPos + 16 <= ALen do
  begin
    LWsMask16 := Vec16CmpEq(@AData[LPos], $20) or Vec16CmpEq(@AData[LPos], $09) or
                 Vec16CmpEq(@AData[LPos], $0A) or Vec16CmpEq(@AData[LPos], $0D);
    if LWsMask16 = MASK16_ALL_SET then
      Inc(LPos, 16)
    else
    begin
      LWsMask16 := (not LWsMask16) and MASK16_ALL_SET;
      Exit(LPos + SizeUInt(Vec16Ctz(LWsMask16)));
    end;
  end;
  while LPos < ALen do
  begin
    if not IsWhitespace(Byte(AData[LPos])) then
      Exit(LPos);
    Inc(LPos);
  end;
  Result := LPos;
end;

function ScanJsonNumber(const AData: PAnsiChar; const ALen: SizeUInt): SizeUInt;
var
  LPos: SizeUInt;
  LMask: TMask16;
  LCh: Byte;
begin
  LPos := 0;
  if (LPos < ALen) and (AData[LPos] = '-') then
    Inc(LPos);
  while LPos + 16 <= ALen do
  begin
    LMask := Vec16CmpRange(@AData[LPos], Ord('0'), Ord('9'));
    if LMask = MASK16_ALL_SET then
      Inc(LPos, 16)
    else
    begin
      LMask := not LMask;
      LMask := LMask and MASK16_ALL_SET;
      Inc(LPos, SizeUInt(Vec16Ctz(LMask)));
      Break;
    end;
  end;
  if LPos + 16 > ALen then
    while (LPos < ALen) and IsDigit(Byte(AData[LPos])) do
      Inc(LPos);
  if (LPos < ALen) and (AData[LPos] = '.') then
  begin
    Inc(LPos);
    while (LPos < ALen) and IsDigit(Byte(AData[LPos])) do
      Inc(LPos);
  end;
  if LPos < ALen then
  begin
    LCh := Byte(AData[LPos]);
    if (LCh = Ord('e')) or (LCh = Ord('E')) then
    begin
      Inc(LPos);
      if LPos < ALen then
      begin
        LCh := Byte(AData[LPos]);
        if (LCh = Ord('+')) or (LCh = Ord('-')) then
          Inc(LPos);
      end;
      while (LPos < ALen) and IsDigit(Byte(AData[LPos])) do
        Inc(LPos);
    end;
  end;
  Result := LPos;
end;

function ScanMatchLiteral(const AData: PAnsiChar; const ALen: SizeUInt;
  const AExpected: PAnsiChar; const AExpectedLen: Byte): Boolean;
var
  I: Byte;
begin
  if ALen < AExpectedLen then
    Exit(False);
  for I := 0 to AExpectedLen - 1 do
    if AData[I] <> AExpected[I] then
      Exit(False);
  Result := True;
end;

procedure ViewSkipWhitespace(var AView: TStringView);
var
  LSkipped: SizeUInt;
begin
  LSkipped := ScanSkipWhitespace(AView.Data, AView.Len);
  if LSkipped > 0 then
    AView.Advance(LSkipped);
end;

function ViewMatchLiteral(var AView: TStringView;
  const AExpected: PAnsiChar; const AExpectedLen: Byte): Boolean;
begin
  Result := ScanMatchLiteral(AView.Data, AView.Len, AExpected, AExpectedLen);
  if Result then
    AView.Advance(AExpectedLen);
end;

end.
