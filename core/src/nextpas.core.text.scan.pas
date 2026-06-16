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
function ScanIsJsonNumberToken(const AData: PAnsiChar; const ALen: SizeUInt): Boolean;
function ScanJsonNumberHasIncompleteExponent(const AData: PAnsiChar;
  const ALen: SizeUInt): Boolean;
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
    LWsMask := VecCmpEq(@AData[LPos], Ord(' ')) or
               VecCmpEq(@AData[LPos], 9) or
               VecCmpEq(@AData[LPos], 10) or
               VecCmpEq(@AData[LPos], 13);
    if LWsMask = TVecMask(not TVecMask(0)) then
      Inc(LPos, VecWidth)
    else
      Exit(LPos + SizeUInt(VecCtz(not LWsMask and TVecMask(not TVecMask(0)))));
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

function ScanIsJsonNumberToken(const AData: PAnsiChar; const ALen: SizeUInt): Boolean;
var
  LPos: SizeUInt;
begin
  if ALen = 0 then
    Exit(False);

  LPos := 0;
  if AData[LPos] = '-' then
  begin
    Inc(LPos);
    if LPos >= ALen then
      Exit(False);
  end;

  if AData[LPos] = '0' then
  begin
    Inc(LPos);
    if (LPos < ALen) and IsDigit(Byte(AData[LPos])) then
      Exit(False);
  end
  else
  begin
    if not IsDigit(Byte(AData[LPos])) then
      Exit(False);
    while (LPos < ALen) and IsDigit(Byte(AData[LPos])) do
      Inc(LPos);
  end;

  if (LPos < ALen) and (AData[LPos] = '.') then
  begin
    Inc(LPos);
    if (LPos >= ALen) or not IsDigit(Byte(AData[LPos])) then
      Exit(False);
    while (LPos < ALen) and IsDigit(Byte(AData[LPos])) do
      Inc(LPos);
  end;

  if (LPos < ALen) and
     ((AData[LPos] = 'e') or (AData[LPos] = 'E')) then
  begin
    Inc(LPos);
    if (LPos < ALen) and
       ((AData[LPos] = '+') or (AData[LPos] = '-')) then
      Inc(LPos);
    if (LPos >= ALen) or not IsDigit(Byte(AData[LPos])) then
      Exit(False);
    while (LPos < ALen) and IsDigit(Byte(AData[LPos])) do
      Inc(LPos);
  end;

  Result := LPos = ALen;
end;

function ScanJsonNumberHasIncompleteExponent(const AData: PAnsiChar;
  const ALen: SizeUInt): Boolean;
var
  LPos: SizeUInt;
begin
  if ALen = 0 then
    Exit(False);
  LPos := ALen;
  if (AData[LPos - 1] = '+') or (AData[LPos - 1] = '-') then
  begin
    if LPos < 2 then
      Exit(False);
    Dec(LPos);
  end;
  Result := (LPos > 0) and
    ((AData[LPos - 1] = 'e') or (AData[LPos - 1] = 'E'));
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

function ASCIIToLower(const ACh: Byte): Byte; inline;
begin
  Result := ACh;
  if (Result >= Ord('A')) and (Result <= Ord('Z')) then
    Inc(Result, 32);
end;

function ASCIIToUpper(const ACh: Byte): Byte; inline;
begin
  Result := ACh;
  if (Result >= Ord('a')) and (Result <= Ord('z')) then
    Dec(Result, 32);
end;

function CIMatch(const AData, ANeedle: PAnsiChar; ALen: SizeUInt): Boolean; inline;
var K: SizeUInt;
begin
  for K := 0 to ALen - 1 do
  begin
    if ASCIIToLower(Byte(AData[K])) <> ASCIIToLower(Byte(ANeedle[K])) then
      Exit(False);
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

  LFirstLo := ASCIIToLower(Byte(ANeedle[0]));
  LFirstHi := ASCIIToUpper(Byte(ANeedle[0]));
  LLastLo := ASCIIToLower(Byte(ANeedle[ANeedleLen - 1]));
  LLastHi := ASCIIToUpper(Byte(ANeedle[ANeedleLen - 1]));
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
  I: SizeUInt;
begin
  if AExpectedLen = 0 then
    Exit(True);
  if ALen < AExpectedLen then
    Exit(False);
  I := 0;
  while I < AExpectedLen do
  begin
    if AData[I] <> AExpected[I] then
      Exit(False);
    Inc(I);
  end;
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
