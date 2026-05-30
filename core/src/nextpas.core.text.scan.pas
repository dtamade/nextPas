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
  nextpas.core.simd.vec,
  nextpas.core.text.char;

function ScanFindByte(const AData: PAnsiChar; const ALen: SizeUInt;
  const A: Byte): PtrInt;
var
  LPos: SizeUInt;
  LMask: TVecMask;
begin
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    LMask := VecCmpEq(@AData[LPos], A);
    if LMask <> TVecMask(0) then
      Exit(PtrInt(LPos) + VecCtz(LMask));
    Inc(LPos, VecWidth);
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
  LCombined: TVecMask;
begin
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    LCombined := VecCmpEq(@AData[LPos], A) or VecCmpEq(@AData[LPos], B);
    if LCombined <> TVecMask(0) then
      Exit(PtrInt(LPos) + VecCtz(LCombined));
    Inc(LPos, VecWidth);
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
  LCombined: TVecMask;
begin
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    LCombined := VecCmpEq(@AData[LPos], A) or
                 VecCmpEq(@AData[LPos], B) or
                 VecCmpEq(@AData[LPos], C);
    if LCombined <> TVecMask(0) then
      Exit(PtrInt(LPos) + VecCtz(LCombined));
    Inc(LPos, VecWidth);
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
  LMask: TVecMask;
begin
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    LMask := VecCmpRange(@AData[LPos], ALo, AHi);
    if LMask <> TVecMask(0) then
      Exit(PtrInt(LPos) + VecCtz(LMask));
    Inc(LPos, VecWidth);
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
  LMask: TVecMask;
begin
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    LMask := not VecCmpRange(@AData[LPos], ALo, AHi);
    LMask := LMask and TVecMask(not TVecMask(0));
    if LMask <> TVecMask(0) then
      Exit(PtrInt(LPos) + VecCtz(LMask));
    Inc(LPos, VecWidth);
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
  LWsMask: TVecMask;
begin
  LPos := 0;
  while LPos + VecWidth <= ALen do
  begin
    LWsMask := VecCmpGtU(@AData[LPos], $20);
    if LWsMask = TVecMask(0) then
      Inc(LPos, VecWidth)
    else
      Exit(LPos + SizeUInt(VecCtz(LWsMask)));
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
  LMask: TVecMask;
  LCh: Byte;
begin
  LPos := 0;
  if (LPos < ALen) and (AData[LPos] = '-') then
    Inc(LPos);
  while LPos + VecWidth <= ALen do
  begin
    LMask := VecCmpRange(@AData[LPos], Ord('0'), Ord('9'));
    if LMask = TVecMask(not TVecMask(0)) then
      Inc(LPos, VecWidth)
    else
    begin
      LMask := not LMask;
      LMask := LMask and TVecMask(not TVecMask(0));
      Inc(LPos, SizeUInt(VecCtz(LMask)));
      Break;
    end;
  end;
  if LPos + VecWidth > ALen then
    while (LPos < ALen) and IsDigit(Byte(AData[LPos])) do
      Inc(LPos);
  if (LPos < ALen) and (AData[LPos] = '.') then
  begin
    Inc(LPos);
    while LPos + VecWidth <= ALen do
    begin
      LMask := VecCmpRange(@AData[LPos], Ord('0'), Ord('9'));
      if LMask = TVecMask(not TVecMask(0)) then
        Inc(LPos, VecWidth)
      else
      begin
        Inc(LPos, SizeUInt(VecCtz(not LMask and TVecMask(not TVecMask(0)))));
        Break;
      end;
    end;
    if LPos + VecWidth > ALen then
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
      while LPos + VecWidth <= ALen do
      begin
        LMask := VecCmpRange(@AData[LPos], Ord('0'), Ord('9'));
        if LMask = TVecMask(not TVecMask(0)) then
          Inc(LPos, VecWidth)
        else
        begin
          Inc(LPos, SizeUInt(VecCtz(not LMask and TVecMask(not TVecMask(0)))));
          Break;
        end;
      end;
      if LPos + VecWidth > ALen then
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
