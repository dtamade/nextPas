{ Ryu algorithm: double to shortest decimal string }
{ Reference: Ulf Adams, "Ryū: Fast Float-to-String Conversion" (PLDI 2018) }

function RyuFloor_log2(const AValue: UInt64): Int32;
var
  LV: UInt64;
begin
  Result := 0;
  LV := AValue;
  while LV >= 2 do
  begin
    LV := LV shr 1;
    Inc(Result);
  end;
end;

function RyuPow10BitsForIndex(const AIdx: Int32): Int32; inline;
begin
  Result := 16 * AIdx + 120;
end;

function RyuMulShift64(const AM: UInt64; const AMul: TPow10Entry;
  const AShift: Int32): UInt64;
var
  LHi0, LLo0, LHi1, LLo1: UInt64;
  LSum: UInt64;
begin
  UMul128(AM, AMul.Lo, LHi0, LLo0);
  UMul128(AM, AMul.Hi, LHi1, LLo1);
  LSum := LHi0 + LLo1;
  if LSum < LHi0 then
    Inc(LHi1);
  Result := (LHi1 shl (64 - AShift)) or (LSum shr (AShift - 64));
end;

type
  TRyuDecimal = record
    Mantissa: UInt64;
    Exponent: Int32;
  end;

function RyuD2D(const AIeee2: UInt64; const AIeeeE2: Int32): TRyuDecimal;
var
  LM2: UInt64;
  LE2: Int32;
  LMm, LMp, LMv: UInt64;
  LQ: Int32;
  LE10: Int32;
  LK: Int32;
  LIdx: Int32;
  LShift: Int32;
  LVr, LVp, LVm: UInt64;
  LVmIsTrailingZeros, LVrIsTrailingZeros: Boolean;
  LLastRemovedDigit: Byte;
  LRemoved: Int32;
  LOutput: UInt64;
begin
  if AIeeeE2 = 0 then
  begin
    LE2 := 1 - DOUBLE_BIAS - DOUBLE_MANTISSA_BITS - 2;
    LM2 := AIeee2;
  end
  else
  begin
    LE2 := AIeeeE2 - DOUBLE_BIAS - DOUBLE_MANTISSA_BITS - 2;
    LM2 := AIeee2 or DOUBLE_HIDDEN_BIT;
  end;

  LMm := 4 * LM2 - (2 - Ord(AIeee2 <> 0) * Ord(AIeeeE2 > 0));
  LMv := 4 * LM2;
  LMp := 4 * LM2 + 2;

  LVmIsTrailingZeros := False;
  LVrIsTrailingZeros := False;

  if LE2 >= 0 then
  begin
    LQ := LE2 - Ord(LE2 > 3) * (LE2 * 78913 div 262144);
    if LQ < 0 then LQ := 0;
    LE10 := LQ;
    LK := 124 + RyuFloor_log2(UInt64(1) shl LQ) - 1;
    LIdx := (LQ + 15) div 16;
    LShift := LIdx * 16 - LQ + 125;

    LVr := RyuMulShift64(LMv, POW10_TABLE[LIdx - POW10_MIN_EXP], LShift);
    LVp := RyuMulShift64(LMp, POW10_TABLE[LIdx - POW10_MIN_EXP], LShift);
    LVm := RyuMulShift64(LMm, POW10_TABLE[LIdx - POW10_MIN_EXP], LShift);
  end
  else
  begin
    LQ := -LE2 - Ord(-LE2 > 1) * ((-LE2) * 732923 div 2097152);
    if LQ < 0 then LQ := 0;
    LE10 := LQ + LE2;
    LK := RyuFloor_log2(UInt64(1) shl LQ) - 125;
    LIdx := (-LE10 + 15) div 16;
    LShift := -LE10 - LIdx * 16 + 125;

    LVr := RyuMulShift64(LMv, POW10_TABLE[LIdx - POW10_MIN_EXP], LShift);
    LVp := RyuMulShift64(LMp, POW10_TABLE[LIdx - POW10_MIN_EXP], LShift);
    LVm := RyuMulShift64(LMm, POW10_TABLE[LIdx - POW10_MIN_EXP], LShift);
  end;

  LLastRemovedDigit := 0;
  LRemoved := 0;

  while LVp div 10 > LVm div 10 do
  begin
    LVmIsTrailingZeros := LVmIsTrailingZeros and ((LVm mod 10) = 0);
    LVrIsTrailingZeros := LVrIsTrailingZeros and (LLastRemovedDigit = 0);
    LLastRemovedDigit := Byte(LVr mod 10);
    LVr := LVr div 10;
    LVp := LVp div 10;
    LVm := LVm div 10;
    Inc(LRemoved);
  end;

  if LVmIsTrailingZeros then
    while (LVm mod 10) = 0 do
    begin
      LVrIsTrailingZeros := LVrIsTrailingZeros and (LLastRemovedDigit = 0);
      LLastRemovedDigit := Byte(LVr mod 10);
      LVr := LVr div 10;
      LVp := LVp div 10;
      LVm := LVm div 10;
      Inc(LRemoved);
    end;

  if LVrIsTrailingZeros and (LLastRemovedDigit = 5) and ((LVr mod 2) = 0) then
    LLastRemovedDigit := 4;

  LOutput := LVr;
  if (LLastRemovedDigit >= 5) or
     ((LVr = LVm) and (not LVmIsTrailingZeros or ((LVr mod 2) <> 0))) then
    Inc(LOutput);

  Result.Mantissa := LOutput;
  Result.Exponent := LE10 + LRemoved;
end;

function FloatToBuffer(const AValue: Double; const ADst: PAnsiChar): Int32;
var
  LBits: UInt64 absolute AValue;
  LSign: Boolean;
  LIeeeE2: Int32;
  LIeeeM2: UInt64;
  LDecimal: TRyuDecimal;
  LBuf: array[0..24] of AnsiChar;
  LPos, LLen, LDecExp, I: Int32;
  LMant: UInt64;
  LDigits: array[0..19] of AnsiChar;
  LDigitCount: Int32;
begin
  LSign := (LBits and DOUBLE_SIGN_MASK) <> 0;

  if DoubleIsNaN(AValue) then
  begin
    Move('NaN', ADst^, 3);
    Exit(3);
  end;
  if DoubleIsInf(AValue) then
  begin
    if LSign then
    begin
      Move('-Infinity', ADst^, 9);
      Exit(9);
    end;
    Move('Infinity', ADst^, 8);
    Exit(8);
  end;
  if DoubleIsZero(AValue) then
  begin
    if LSign then
    begin
      ADst[0] := '-'; ADst[1] := '0';
      Exit(2);
    end;
    ADst[0] := '0';
    Exit(1);
  end;

  LIeeeE2 := Int32((LBits shr 52) and $7FF);
  LIeeeM2 := LBits and DOUBLE_MANTISSA_MASK;

  LDecimal := RyuD2D(LIeeeM2, LIeeeE2);

  LMant := LDecimal.Mantissa;
  LDigitCount := 0;
  while LMant > 0 do
  begin
    LDigits[LDigitCount] := AnsiChar(Ord('0') + LMant mod 10);
    LMant := LMant div 10;
    Inc(LDigitCount);
  end;

  LDecExp := LDecimal.Exponent + LDigitCount - 1;
  LPos := 0;

  if LSign then
  begin
    ADst[LPos] := '-';
    Inc(LPos);
  end;

  if (LDecExp >= 0) and (LDecExp < 17) and (LDecimal.Exponent >= 0) then
  begin
    for I := LDigitCount - 1 downto 0 do
    begin
      ADst[LPos] := LDigits[I];
      Inc(LPos);
    end;
    for I := 1 to LDecimal.Exponent do
    begin
      ADst[LPos] := '0';
      Inc(LPos);
    end;
  end
  else if (LDecExp >= 0) and (LDecExp < LDigitCount - 1) then
  begin
    for I := LDigitCount - 1 downto 0 do
    begin
      if I = LDigitCount - 2 - LDecExp then
      begin
        ADst[LPos] := '.';
        Inc(LPos);
      end;
      ADst[LPos] := LDigits[I];
      Inc(LPos);
    end;
  end
  else
  begin
    ADst[LPos] := LDigits[LDigitCount - 1];
    Inc(LPos);
    if LDigitCount > 1 then
    begin
      ADst[LPos] := '.';
      Inc(LPos);
      for I := LDigitCount - 2 downto 0 do
      begin
        ADst[LPos] := LDigits[I];
        Inc(LPos);
      end;
    end;
    ADst[LPos] := 'e';
    Inc(LPos);
    if LDecExp < 0 then
    begin
      ADst[LPos] := '-';
      Inc(LPos);
      LDecExp := -LDecExp;
    end
    else
    begin
      ADst[LPos] := '+';
      Inc(LPos);
    end;
    if LDecExp >= 100 then
    begin
      ADst[LPos] := AnsiChar(Ord('0') + LDecExp div 100);
      Inc(LPos);
      LDecExp := LDecExp mod 100;
    end;
    if LDecExp >= 10 then
    begin
      ADst[LPos] := AnsiChar(Ord('0') + LDecExp div 10);
      Inc(LPos);
    end;
    ADst[LPos] := AnsiChar(Ord('0') + LDecExp mod 10);
    Inc(LPos);
  end;

  Result := LPos;
end;
