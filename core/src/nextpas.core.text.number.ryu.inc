{ Ryu algorithm: double to shortest decimal string }
{ Strict port of Ulf Adams' reference implementation (ryu/d2s.c) }
{ https://github.com/ulfjack/ryu }

type
  TRyuDecimal = record
    Mantissa: UInt64;
    Exponent: Int32;
  end;

function RyuLog10Pow2(const AE: Int32): Int32; inline;
begin
  Result := (AE * 78913) shr 18;
end;

function RyuLog10Pow5(const AE: Int32): Int32; inline;
begin
  Result := (AE * 732923) shr 20;
end;

function RyuLog2Pow5(const AE: Int32): Int32; inline;
begin
  Result := (AE * 1217359) shr 19;
end;

function RyuPow5Factor(AValue: UInt64): Int32;
begin
  Result := 0;
  while True do
  begin
    if AValue = 0 then Exit(0);
    if (AValue mod 5) <> 0 then Exit;
    AValue := AValue div 5;
    Inc(Result);
  end;
end;

function RyuMultipleOfPow5(const AValue: UInt64; const AP: Int32): Boolean; inline;
begin
  Result := RyuPow5Factor(AValue) >= AP;
end;

function RyuMultipleOfPow2(const AValue: UInt64; const AP: Int32): Boolean; inline;
begin
  Result := (AValue and ((UInt64(1) shl AP) - 1)) = 0;
end;

function RyuMulShiftAll64(const AM: UInt64; const AMul: TPow10Entry;
  const AShift: Int32; out AVp, AVm: UInt64; const AMmShift: Int32): UInt64;
var
  LHi0, LLo0, LHi1, LLo1: UInt64;
  LMid, LHi: UInt64;
begin
  UMul128(AM * 4, AMul.Hi, LHi1, LLo1);
  UMul128(AM * 4, AMul.Lo, LHi0, LLo0);
  LMid := LHi0 + LLo1;
  LHi := LHi1 + Ord(LMid < LHi0);

  Result := (LHi shl (64 - (AShift - 64))) or (LMid shr (AShift - 64));

  UMul128((AM * 4 + 2), AMul.Hi, LHi1, LLo1);
  UMul128((AM * 4 + 2), AMul.Lo, LHi0, LLo0);
  LMid := LHi0 + LLo1;
  LHi := LHi1 + Ord(LMid < LHi0);
  AVp := (LHi shl (64 - (AShift - 64))) or (LMid shr (AShift - 64));

  UMul128((AM * 4 - 1 - AMmShift), AMul.Hi, LHi1, LLo1);
  UMul128((AM * 4 - 1 - AMmShift), AMul.Lo, LHi0, LLo0);
  LMid := LHi0 + LLo1;
  LHi := LHi1 + Ord(LMid < LHi0);
  AVm := (LHi shl (64 - (AShift - 64))) or (LMid shr (AShift - 64));
end;

function RyuD2D(const AIeeeM2: UInt64; const AIeeeE2: Int32): TRyuDecimal;
var
  LM2: UInt64;
  LE2: Int32;
  LMmShift: Int32;
  LVr, LVp, LVm: UInt64;
  LE10: Int32;
  LQ: Int32;
  LK, LI, LJ: Int32;
  LVmIsTrailingZeros, LVrIsTrailingZeros: Boolean;
  LLastRemovedDigit: Byte;
  LRemoved: Int32;
  LOutput: UInt64;
begin
  if AIeeeE2 = 0 then
  begin
    LE2 := 1 - DOUBLE_BIAS - DOUBLE_MANTISSA_BITS - 2;
    LM2 := AIeeeM2;
  end
  else
  begin
    LE2 := AIeeeE2 - DOUBLE_BIAS - DOUBLE_MANTISSA_BITS - 2;
    LM2 := AIeeeM2 or DOUBLE_HIDDEN_BIT;
  end;

  LMmShift := Ord((AIeeeM2 <> 0) or (AIeeeE2 <= 1));

  LVmIsTrailingZeros := False;
  LVrIsTrailingZeros := False;

  if LE2 >= 0 then
  begin
    LQ := RyuLog10Pow2(LE2);
    if LQ > 21 then LQ := 21;
    LE10 := LQ;
    LK := 122 + RyuLog2Pow5(LQ) - 1;
    LI := -LE2 + LQ + LK;
    LVr := RyuMulShiftAll64(LM2, POW10_TABLE[LQ - POW10_MIN_EXP], LI, LVp, LVm, LMmShift);

    if LQ <= 21 then
    begin
      if (LM2 mod 5) = 0 then
        LVrIsTrailingZeros := RyuMultipleOfPow5(LM2, LQ)
      else
        LVmIsTrailingZeros := RyuMultipleOfPow5(LM2 - 1 - LMmShift, LQ);
    end;
  end
  else
  begin
    LQ := RyuLog10Pow5(-LE2);
    if LQ > 1 then Dec(LQ);
    if LQ < 0 then LQ := 0;
    LE10 := LQ + LE2;
    LI := -LE2 - LQ;
    LK := RyuLog2Pow5(LI) - 122;
    LJ := LQ - LK;
    LVr := RyuMulShiftAll64(LM2, POW10_TABLE[LI - POW10_MIN_EXP], LJ + 122, LVp, LVm, LMmShift);

    if LQ <= 1 then
    begin
      LVrIsTrailingZeros := True;
      if LMmShift = 1 then
        LVmIsTrailingZeros := True
      else
        Dec(LVp);
    end
    else if LQ < 63 then
      LVrIsTrailingZeros := RyuMultipleOfPow2(LM2, LQ);
  end;

  LLastRemovedDigit := 0;
  LRemoved := 0;

  if LVmIsTrailingZeros or LVrIsTrailingZeros then
  begin
    while True do
    begin
      if LVp div 10 <= LVm div 10 then Break;
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
    LOutput := LVr + Ord((LVr = LVm) and ((not LVmIsTrailingZeros) or ((LVr mod 2) <> 0)));
    if LLastRemovedDigit >= 5 then
      Inc(LOutput);
  end
  else
  begin
    while LVp div 10 > LVm div 10 do
    begin
      LLastRemovedDigit := Byte(LVr mod 10);
      LVr := LVr div 10;
      LVp := LVp div 10;
      LVm := LVm div 10;
      Inc(LRemoved);
    end;
    LOutput := LVr + Ord(LLastRemovedDigit >= 5);
  end;

  Result.Mantissa := LOutput;
  Result.Exponent := LE10 + LRemoved;
end;

function FloatToBuffer(const AValue: Double; const ADst: PAnsiChar): Int32;
var
  LBits: UInt64 absolute AValue;
  LSign: Boolean;
  LIeeeE2: Int32;
  LIeeeM2: UInt64;
  LDec: TRyuDecimal;
  LPos: Int32;
  LMant: UInt64;
  LDigits: array[0..19] of AnsiChar;
  LDigitCount: Int32;
  LDecPt: Int32;
  I: Int32;
begin
  LSign := (LBits and DOUBLE_SIGN_MASK) <> 0;

  if DoubleIsNaN(AValue) then
  begin
    Move('NaN', ADst^, 3);
    Exit(3);
  end;
  if DoubleIsInf(AValue) then
  begin
    if LSign then begin Move('-Infinity', ADst^, 9); Exit(9); end;
    Move('Infinity', ADst^, 8);
    Exit(8);
  end;
  if DoubleIsZero(AValue) then
  begin
    if LSign then begin ADst[0] := '-'; ADst[1] := '0'; Exit(2); end;
    ADst[0] := '0';
    Exit(1);
  end;

  LIeeeE2 := Int32((LBits shr 52) and $7FF);
  LIeeeM2 := LBits and DOUBLE_MANTISSA_MASK;
  LDec := RyuD2D(LIeeeM2, LIeeeE2);

  LMant := LDec.Mantissa;
  LDigitCount := 0;
  while LMant > 0 do
  begin
    LDigits[LDigitCount] := AnsiChar(Ord('0') + LMant mod 10);
    LMant := LMant div 10;
    Inc(LDigitCount);
  end;

  LDecPt := LDec.Exponent + LDigitCount;
  LPos := 0;

  if LSign then
  begin
    ADst[LPos] := '-';
    Inc(LPos);
  end;

  if (LDecPt >= 1) and (LDecPt <= 17) and (LDec.Exponent >= 0) then
  begin
    for I := LDigitCount - 1 downto 0 do
    begin
      ADst[LPos] := LDigits[I];
      Inc(LPos);
    end;
    for I := 1 to LDec.Exponent do
    begin
      ADst[LPos] := '0';
      Inc(LPos);
    end;
  end
  else if (LDecPt >= 1) and (LDecPt <= LDigitCount) then
  begin
    for I := LDigitCount - 1 downto 0 do
    begin
      if I = LDigitCount - 1 - LDecPt then
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
    LDecPt := LDecPt - 1;
    if LDecPt < 0 then
    begin
      ADst[LPos] := '-';
      Inc(LPos);
      LDecPt := -LDecPt;
    end
    else
    begin
      ADst[LPos] := '+';
      Inc(LPos);
    end;
    if LDecPt >= 100 then
    begin
      ADst[LPos] := AnsiChar(Ord('0') + LDecPt div 100);
      Inc(LPos);
      LDecPt := LDecPt mod 100;
      ADst[LPos] := AnsiChar(Ord('0') + LDecPt div 10);
      Inc(LPos);
      ADst[LPos] := AnsiChar(Ord('0') + LDecPt mod 10);
      Inc(LPos);
    end
    else if LDecPt >= 10 then
    begin
      ADst[LPos] := AnsiChar(Ord('0') + LDecPt div 10);
      Inc(LPos);
      ADst[LPos] := AnsiChar(Ord('0') + LDecPt mod 10);
      Inc(LPos);
    end
    else
    begin
      ADst[LPos] := AnsiChar(Ord('0') + LDecPt);
      Inc(LPos);
    end;
  end;

  Result := LPos;
end;
