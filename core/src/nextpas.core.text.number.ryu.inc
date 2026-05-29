{ Schubfach algorithm: double to shortest decimal string }
{ Port of yyjson's f64_bin_to_dec (Raffaello Giulietti, 2022) }

type
  TRyuDecimal = record
    Mantissa: UInt64;
    Exponent: Int32;
  end;

function RoundToOdd(const AHi, ALo, ACp: UInt64): UInt64;
var
  LXHi, LXLo, LYHi, LYLo: UInt64;
begin
  UMul128(ACp, ALo, LXHi, LXLo);
  UMul128(ACp, AHi, LYHi, LYLo);
  Inc(LYLo, LXHi);
  if LYLo < LXHi then
    Inc(LYHi);
  Result := LYHi or Ord(LYLo > 1);
end;

function SchubfachD2D(const ASigRaw: UInt64; const AExpRaw: UInt32;
  const ASigBin: UInt64; const AExpBin: Int32): TRyuDecimal;
var
  LIsEven, LRegularSpacing, LUInside, LWInside, LRoundUp: Boolean;
  LCbl, LCb, LCbr: UInt64;
  LK, LH, LExp10: Int32;
  LPow10Hi, LPow10Lo: UInt64;
  LVbl, LVb, LVbr: UInt64;
  LLower, LUpper, LMid: UInt64;
  LS, LSp: UInt64;
  LIdx: Int32;
begin
  LIsEven := (ASigBin and 1) = 0;
  LRegularSpacing := (ASigRaw = 0) and (AExpRaw > 1);

  LCbl := 4 * ASigBin - 2 + Ord(LRegularSpacing);
  LCb := 4 * ASigBin;
  LCbr := 4 * ASigBin + 2;

  LK := Int32((Int64(AExpBin) * 315653 - Ord(LRegularSpacing) * 131237) shr 20);
  LExp10 := -LK;
  LH := AExpBin + ((LExp10 * 217707) shr 16) + 1;

  LIdx := LExp10 - POW10_MIN_EXP;
  LPow10Hi := POW10_TABLE[LIdx].Hi;
  LPow10Lo := POW10_TABLE[LIdx].Lo;
  if (LExp10 < -55) or (LExp10 > 55) then
    Inc(LPow10Lo);

  LVbl := RoundToOdd(LPow10Hi, LPow10Lo, LCbl shl LH);
  LVb := RoundToOdd(LPow10Hi, LPow10Lo, LCb shl LH);
  LVbr := RoundToOdd(LPow10Hi, LPow10Lo, LCbr shl LH);

  LLower := LVbl + Ord(not LIsEven);
  LUpper := LVbr - Ord(not LIsEven);

  LS := LVb div 4;
  if LS >= 10 then
  begin
    LSp := LS div 10;
    LUInside := LLower <= 40 * LSp;
    LWInside := LUpper >= 40 * LSp + 40;
    if LUInside <> LWInside then
    begin
      Result.Mantissa := LSp + Ord(LWInside);
      Result.Exponent := LK + 1;
      Exit;
    end;
  end;

  LUInside := LLower <= 4 * LS;
  LWInside := LUpper >= 4 * LS + 4;

  LMid := 4 * LS + 2;
  LRoundUp := (LVb > LMid) or ((LVb = LMid) and ((LS and 1) <> 0));

  if LUInside <> LWInside then
    Result.Mantissa := LS + Ord(LWInside)
  else
    Result.Mantissa := LS + Ord(LRoundUp);
  Result.Exponent := LK;
end;

function FloatToBuffer(const AValue: Double; const ADst: PAnsiChar): Int32;
var
  LBits: UInt64 absolute AValue;
  LSign: Boolean;
  LExpRaw: UInt32;
  LSigRaw, LSigBin: UInt64;
  LExpBin: Int32;
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

  LSigRaw := LBits and DOUBLE_MANTISSA_MASK;
  LExpRaw := UInt32((LBits shr 52) and $7FF);

  if LExpRaw = 0 then
  begin
    LSigBin := LSigRaw;
    LExpBin := 1 - 1023 - 52;
  end
  else
  begin
    LSigBin := LSigRaw or DOUBLE_HIDDEN_BIT;
    LExpBin := Int32(LExpRaw) - 1023 - 52;
  end;

  LDec := SchubfachD2D(LSigRaw, LExpRaw, LSigBin, LExpBin);

  LMant := LDec.Mantissa;
  while (LMant > 0) and ((LMant mod 10) = 0) do
  begin
    LMant := LMant div 10;
    Inc(LDec.Exponent);
  end;

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
  else if (LDecPt >= 1) and (LDecPt < LDigitCount) then
  begin
    for I := LDigitCount - 1 downto 0 do
    begin
      if (LDigitCount - 1 - I) = LDecPt then
      begin
        ADst[LPos] := '.';
        Inc(LPos);
      end;
      ADst[LPos] := LDigits[I];
      Inc(LPos);
    end;
  end
  else if (LDecPt >= -3) and (LDecPt <= 0) then
  begin
    ADst[LPos] := '0'; Inc(LPos);
    ADst[LPos] := '.'; Inc(LPos);
    for I := 1 to -LDecPt do
    begin
      ADst[LPos] := '0';
      Inc(LPos);
    end;
    for I := LDigitCount - 1 downto 0 do
    begin
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
