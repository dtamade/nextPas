unit nextpas.core.text.scan;

{$I nextpas.core.settings.inc}
{$IFDEF CPUX86_64}{$asmmode intel}{$ENDIF}

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
function ScanFindSubstring(const AData: PAnsiChar; const ADataLen: SizeUInt;
  const ANeedle: PAnsiChar; const ANeedleLen: SizeUInt): PtrInt;
function ScanFindSubstringCI(const AData: PAnsiChar; const ADataLen: SizeUInt;
  const ANeedle: PAnsiChar; const ANeedleLen: SizeUInt): PtrInt;
function ScanMatchLiteral(const AData: PAnsiChar; const ALen: SizeUInt;
  const AExpected: PAnsiChar; const AExpectedLen: Byte): Boolean; inline;
procedure ViewSkipWhitespace(var AView: TStringView); inline;
function ViewMatchLiteral(var AView: TStringView;
  const AExpected: PAnsiChar; const AExpectedLen: Byte): Boolean; inline;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.simd.base,
  nextpas.core.simd.vec,
  nextpas.core.simd.cpuinfo,
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
  LCh: Byte;

  function ScanDigitsFrom(const AStart: SizeUInt): SizeUInt;
  var
    LDigitPos: SizeUInt;
    LMask: TVecMask;
  begin
    LDigitPos := AStart;
    while LDigitPos + VecWidth <= ALen do
    begin
      LMask := VecCmpRange(@AData[LDigitPos], Ord('0'), Ord('9'));
      if LMask = TVecMask(not TVecMask(0)) then
        Inc(LDigitPos, VecWidth)
      else
      begin
        Inc(LDigitPos, SizeUInt(VecCtz(not LMask and TVecMask(not TVecMask(0)))));
        Break;
      end;
    end;
    if LDigitPos + VecWidth > ALen then
      while (LDigitPos < ALen) and IsDigit(Byte(AData[LDigitPos])) do
        Inc(LDigitPos);
    Result := LDigitPos;
  end;
begin
  LPos := 0;
  if (LPos < ALen) and (AData[LPos] = '-') then
    Inc(LPos);

  if LPos >= ALen then
    Exit(0);

  LCh := Byte(AData[LPos]);
  if LCh = Ord('0') then
    Inc(LPos)
  else if (LCh >= Ord('1')) and (LCh <= Ord('9')) then
    LPos := ScanDigitsFrom(LPos)
  else
    Exit(0);

  if (LPos < ALen) and (AData[LPos] = '.') then
  begin
    if ((LPos + 1) < ALen) and IsDigit(Byte(AData[LPos + 1])) then
    begin
      Inc(LPos);
      LPos := ScanDigitsFrom(LPos);
    end;
  end;

  if LPos < ALen then
  begin
    Result := LPos;
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
      if (LPos >= ALen) or not IsDigit(Byte(AData[LPos])) then
        Exit(Result);
      LPos := ScanDigitsFrom(LPos);
    end;
  end;
  Result := LPos;
end;

function ScanFindSubstring(const AData: PAnsiChar; const ADataLen: SizeUInt;
  const ANeedle: PAnsiChar; const ANeedleLen: SizeUInt): PtrInt;
var
  LFirstByte, LLastByte: Byte;
  LSearchLen: SizeUInt;
  LPos: SizeUInt;
  LMask1, LMask2, LCombined: TVecMask;
  LBit: Int32;
  LCandidate: SizeUInt;
  {$IFDEF CPUX86_64}
  LMask32: UInt32;
  {$ENDIF}
begin
  if ANeedleLen = 0 then
    Exit(0);
  if ANeedleLen = 1 then
    Exit(ScanFindByte(AData, ADataLen, Byte(ANeedle[0])));
  if ANeedleLen > ADataLen then
    Exit(-1);

  LFirstByte := Byte(ANeedle[0]);
  LLastByte := Byte(ANeedle[ANeedleLen - 1]);
  LSearchLen := ADataLen - ANeedleLen + 1;

  {$IFDEF CPUX86_64}
  if HasAVX2 then
  begin
    LPos := 0;
    while LPos + 32 <= LSearchLen do
    begin
      asm
        movzx eax, byte [LFirstByte]
        vmovd xmm0, eax
        vpbroadcastb ymm0, xmm0
        movzx eax, byte [LLastByte]
        vmovd xmm1, eax
        vpbroadcastb ymm1, xmm1

        mov rcx, [AData]
        add rcx, [LPos]
        vpcmpeqb ymm2, ymm0, ymmword [rcx]

        mov rax, [ANeedleLen]
        dec rax
        add rcx, rax
        vpcmpeqb ymm3, ymm1, ymmword [rcx]

        vpand ymm2, ymm2, ymm3
        vpmovmskb eax, ymm2
        mov [LMask32], eax
      end;
      while LMask32 <> 0 do
      begin
        asm
          bsf eax, [LMask32]
          mov [LBit], eax
        end;
        LCandidate := LPos + SizeUInt(LBit);
        if LCandidate < LSearchLen then
        begin
          if CompareMem(@AData[LCandidate + 1], @ANeedle[1], ANeedleLen - 2) then
          begin
            asm vzeroupper end;
            Exit(PtrInt(LCandidate));
          end;
        end;
        LMask32 := LMask32 and (LMask32 - 1);
      end;
      Inc(LPos, 32);
    end;
    asm vzeroupper end;
    // Fall through to SSE2/scalar for remaining bytes
  end;
  {$ENDIF}

  LPos := 0;
  while LPos + VecWidth <= LSearchLen do
  begin
    LMask1 := VecCmpEq(@AData[LPos], LFirstByte);
    LMask2 := VecCmpEq(@AData[LPos + ANeedleLen - 1], LLastByte);
    LCombined := LMask1 and LMask2;
    while LCombined <> TVecMask(0) do
    begin
      LBit := VecCtz(LCombined);
      LCandidate := LPos + SizeUInt(LBit);
      if LCandidate < LSearchLen then
      begin
        if CompareMem(@AData[LCandidate + 1], @ANeedle[1], ANeedleLen - 2) then
          Exit(PtrInt(LCandidate));
      end;
      LCombined := LCombined and (LCombined - 1);
    end;
    Inc(LPos, VecWidth);
  end;

  { Scalar tail }
  while LPos < LSearchLen do
  begin
    if (Byte(AData[LPos]) = LFirstByte) and
       (Byte(AData[LPos + ANeedleLen - 1]) = LLastByte) then
    begin
      if CompareMem(@AData[LPos + 1], @ANeedle[1], ANeedleLen - 2) then
        Exit(PtrInt(LPos));
    end;
    Inc(LPos);
  end;
  Result := -1;
end;

function CIMatch(const AData, ANeedle: PAnsiChar; ALen: SizeUInt): Boolean; inline;
var K: SizeUInt; LCh: Byte;
begin
  for K := 0 to ALen - 1 do
  begin
    LCh := Byte(AData[K]);
    if (LCh >= Ord('A')) and (LCh <= Ord('Z')) then LCh := LCh + 32;
    if LCh <> Byte(ANeedle[K]) then Exit(False);
  end;
  Result := True;
end;

function ScanFindSubstringCI(const AData: PAnsiChar; const ADataLen: SizeUInt;
  const ANeedle: PAnsiChar; const ANeedleLen: SizeUInt): PtrInt;
var
  LFirstLo, LFirstHi, LLastLo, LLastHi: Byte;
  LSearchLen: SizeUInt;
  LPos: SizeUInt;
  LMask1, LMask2, LCombined: TVecMask;
  LBit: Int32;
  LCandidate: SizeUInt;
begin
  if ANeedleLen = 0 then Exit(0);
  if ANeedleLen > ADataLen then Exit(-1);

  LFirstLo := Byte(ANeedle[0]);
  LFirstHi := LFirstLo;
  if (LFirstLo >= Ord('a')) and (LFirstLo <= Ord('z')) then LFirstHi := LFirstLo - 32;
  LLastLo := Byte(ANeedle[ANeedleLen - 1]);
  LLastHi := LLastLo;
  if (LLastLo >= Ord('a')) and (LLastLo <= Ord('z')) then LLastHi := LLastLo - 32;
  LSearchLen := ADataLen - ANeedleLen + 1;

  LPos := 0;
  while LPos + VecWidth <= LSearchLen do
  begin
    LMask1 := VecCmpEq(@AData[LPos], LFirstLo) or VecCmpEq(@AData[LPos], LFirstHi);
    LMask2 := VecCmpEq(@AData[LPos + ANeedleLen - 1], LLastLo) or
              VecCmpEq(@AData[LPos + ANeedleLen - 1], LLastHi);
    LCombined := LMask1 and LMask2;
    while LCombined <> TVecMask(0) do
    begin
      LBit := VecCtz(LCombined);
      LCandidate := LPos + SizeUInt(LBit);
      if LCandidate < LSearchLen then
        if CIMatch(@AData[LCandidate], ANeedle, ANeedleLen) then
          Exit(PtrInt(LCandidate));
      LCombined := LCombined and (LCombined - 1);
    end;
    Inc(LPos, VecWidth);
  end;

  while LPos < LSearchLen do
  begin
    if CIMatch(@AData[LPos], ANeedle, ANeedleLen) then
      Exit(PtrInt(LPos));
    Inc(LPos);
  end;
  Result := -1;
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
