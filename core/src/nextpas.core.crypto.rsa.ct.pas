unit nextpas.core.crypto.rsa.ct;

{$mode ObjFPC}{$H+}{$J-}

interface

uses
  SysUtils;

function TryRSACTModExpSign(
  const AEncodedMessage, AModulus, APrivateExponent: TBytes;
  out ASignature: TBytes; out AError: string
): Boolean;

function TryRSACTSignWithCRT(
  const AEncodedMessage, AModulus, APublicExponent: TBytes;
  const AP, AQ, ADP, ADQ, AQInv: TBytes;
  out ASignature: TBytes; out AError: string
): Boolean;

implementation

uses
  nextpas.core.mem.secure;

type
  TCTNat = array of UInt32;

const
  LIMB_BITS = 32;
  LIMB_MASK: UInt64 = $FFFFFFFF;

type
  TCTMontCtx = record
    N: TCTNat;
    RR: TCTNat;
    NPrime: UInt32;
    Limbs: Integer;
  end;

// --- CT primitives ---

procedure CTNatAlloc(out A: TCTNat; ALimbs: Integer);
begin
  SetLength(A, ALimbs);
  if ALimbs > 0 then
    FillChar(A[0], ALimbs * 4, 0);
end;

procedure CTNatCopy(const ASrc: TCTNat; var ADst: TCTNat; ALimbs: Integer);
var I: Integer;
begin
  for I := 0 to ALimbs - 1 do
    ADst[I] := ASrc[I];
end;

procedure CTNatCondCopy(const ASrc: TCTNat; var ADst: TCTNat;
  ALimbs: Integer; ACond: UInt32);
var
  I: Integer;
  LMask: UInt32;
begin
  LMask := UInt32(0) - ACond;
  for I := 0 to ALimbs - 1 do
    ADst[I] := (ASrc[I] and LMask) or (ADst[I] and (not LMask));
end;

function CTNatSub(var A: TCTNat; const B: TCTNat; ALimbs: Integer): UInt32;
var
  I: Integer;
  LW: UInt64;
  LBorrow: UInt64;
begin
  LBorrow := 0;
  for I := 0 to ALimbs - 1 do
  begin
    LW := UInt64(A[I]) - UInt64(B[I]) - LBorrow;
    A[I] := UInt32(LW and LIMB_MASK);
    LBorrow := (LW shr 63) and 1;
  end;
  Result := UInt32(LBorrow);
end;

function CTNatAdd(var A: TCTNat; const B: TCTNat; ALimbs: Integer): UInt32;
var
  I: Integer;
  LW: UInt64;
  LCarry: UInt64;
begin
  LCarry := 0;
  for I := 0 to ALimbs - 1 do
  begin
    LW := UInt64(A[I]) + UInt64(B[I]) + LCarry;
    A[I] := UInt32(LW and LIMB_MASK);
    LCarry := LW shr LIMB_BITS;
  end;
  Result := UInt32(LCarry);
end;

procedure CTNatFromBytes(const ABytes: TBytes; out A: TCTNat; ALimbs: Integer);
var
  I, LByteIdx, LLimbIdx, LShift: Integer;
begin
  CTNatAlloc(A, ALimbs);
  for I := 0 to Length(ABytes) - 1 do
  begin
    LByteIdx := Length(ABytes) - 1 - I;
    LLimbIdx := I div 4;
    LShift := (I mod 4) * 8;
    if LLimbIdx < ALimbs then
      A[LLimbIdx] := A[LLimbIdx] or (UInt32(ABytes[LByteIdx]) shl LShift);
  end;
end;

procedure CTNatToBytes(const A: TCTNat; ALimbs: Integer; out ABytes: TBytes; AByteLen: Integer);
var
  I, LLimbIdx, LShift: Integer;
begin
  SetLength(ABytes, AByteLen);
  FillChar(ABytes[0], AByteLen, 0);
  for I := 0 to AByteLen - 1 do
  begin
    LLimbIdx := I div 4;
    LShift := (I mod 4) * 8;
    if LLimbIdx < ALimbs then
      ABytes[AByteLen - 1 - I] := Byte((A[LLimbIdx] shr LShift) and $FF);
  end;
end;

// --- Montgomery multiply: R = A * B * R^(-1) mod N ---

procedure CTMontMul(const A, B: TCTNat; var R: TCTNat; const Ctx: TCTMontCtx);
var
  LN, I, J: Integer;
  LT: array of UInt64;
  LAI, LM: UInt32;
  LCarry: UInt64;
  LBorrow: UInt32;
  LTemp: TCTNat;
begin
  LN := Ctx.Limbs;
  SetLength(LT, 2 * LN + 1);
  FillChar(LT[0], Length(LT) * 8, 0);

  for I := 0 to LN - 1 do
  begin
    LAI := A[I];
    LCarry := 0;
    for J := 0 to LN - 1 do
    begin
      LT[I + J] := LT[I + J] + UInt64(LAI) * UInt64(B[J]) + LCarry;
      LCarry := LT[I + J] shr LIMB_BITS;
      LT[I + J] := LT[I + J] and LIMB_MASK;
    end;
    LT[I + LN] := LT[I + LN] + LCarry;
  end;

  for I := 0 to LN - 1 do
  begin
    LM := UInt32((LT[I] * UInt64(Ctx.NPrime)) and LIMB_MASK);
    LCarry := 0;
    for J := 0 to LN - 1 do
    begin
      LT[I + J] := LT[I + J] + UInt64(LM) * UInt64(Ctx.N[J]) + LCarry;
      LCarry := LT[I + J] shr LIMB_BITS;
      LT[I + J] := LT[I + J] and LIMB_MASK;
    end;
    LT[I + LN] := LT[I + LN] + LCarry;
  end;

  // Carry propagation through the upper half
  for I := LN to 2 * LN - 1 do
  begin
    LT[I + 1] := LT[I + 1] + (LT[I] shr LIMB_BITS);
    LT[I] := LT[I] and LIMB_MASK;
  end;

  for I := 0 to LN - 1 do
    R[I] := UInt32(LT[I + LN] and LIMB_MASK);

  // If LT[2*LN] is nonzero, result overflows LN limbs — must subtract N
  // Otherwise, conditionally subtract if R >= N
  CTNatAlloc(LTemp, LN);
  CTNatCopy(R, LTemp, LN);
  LBorrow := CTNatSub(LTemp, Ctx.N, LN);
  // Subtract if: no borrow (R >= N) OR high limb was set
  CTNatCondCopy(LTemp, R, LN, (1 - LBorrow) or UInt32(Ord(LT[2 * LN] <> 0)));
end;

// --- CT fixed-window w=4 modexp ---

procedure CTMontModExp(const ABase: TCTNat; const AExp: TBytes;
  AExpBitLen: Integer; const Ctx: TCTMontCtx; var AResult: TCTNat);
var
  LN, I, J, K, LWindows, LWinBits: Integer;
  LTable: array[0..15] of TCTNat;
  LSelected, LTemp: TCTNat;
  LEqMask: UInt32;
begin
  LN := Ctx.Limbs;

  for I := 0 to 15 do
    CTNatAlloc(LTable[I], LN);
  CTNatAlloc(LSelected, LN);
  CTNatAlloc(LTemp, LN);

  // table[0] = Montgomery(1) = R mod N = MontMul(1, RR)
  CTNatAlloc(LTable[0], LN);
  LTable[0][0] := 1;
  CTMontMul(LTable[0], Ctx.RR, LTemp, Ctx);
  CTNatCopy(LTemp, LTable[0], LN);

  // table[1] = base in Montgomery form = MontMul(base, RR)
  CTMontMul(ABase, Ctx.RR, LTable[1], Ctx);

  // table[i] = table[i-1] * table[1] in Montgomery form
  for I := 2 to 15 do
  begin
    CTMontMul(LTable[I-1], LTable[1], LTemp, Ctx);
    CTNatCopy(LTemp, LTable[I], LN);
  end;

  // Start with accumulator = table[0] = Mont(1)
  CTNatCopy(LTable[0], AResult, LN);

  // Process exponent in 4-bit windows from MSB
  LWindows := (AExpBitLen + 3) div 4;
  for I := LWindows - 1 downto 0 do
  begin
    // Square 4 times
    for K := 0 to 3 do
    begin
      CTMontMul(AResult, AResult, LTemp, Ctx);
      CTNatCopy(LTemp, AResult, LN);
    end;

    // Extract 4-bit window from exponent (big-endian byte array)
    // Window I contains bits [I*4 .. I*4+3], value = bit3*8 + bit2*4 + bit1*2 + bit0
    LWinBits := 0;
    for K := 0 to 3 do
    begin
      J := I * 4 + K;
      if (J < AExpBitLen) and ((J div 8) < Length(AExp)) then
        LWinBits := LWinBits or (Integer((AExp[Length(AExp) - 1 - (J div 8)] shr (J mod 8)) and 1) shl K);
    end;

    // CT table lookup
    FillChar(LSelected[0], LN * 4, 0);
    for J := 0 to 15 do
    begin
      // mask = all-ones if J == LWinBits, else 0
      LEqMask := UInt32(0) - UInt32(Ord(J = LWinBits));
      for K := 0 to LN - 1 do
        LSelected[K] := LSelected[K] or (LTable[J][K] and LEqMask);
    end;

    // Multiply accumulator by selected
    CTMontMul(AResult, LSelected, LTemp, Ctx);
    CTNatCopy(LTemp, AResult, LN);
  end;

  // Convert out of Montgomery form: MontMul(result, 1)
  CTNatAlloc(LTemp, LN);
  LTemp[0] := 1;
  CTNatAlloc(LSelected, LN);
  CTMontMul(AResult, LTemp, LSelected, Ctx);
  CTNatCopy(LSelected, AResult, LN);
end;

// --- Init Montgomery context ---

function ComputeNPrime(N0: UInt32): UInt32;
var
  LInv: UInt64;
  I: Integer;
begin
  LInv := 1;
  for I := 0 to 4 do
    LInv := (LInv * (2 - UInt64(N0) * LInv)) and LIMB_MASK;
  Result := UInt32((UInt64(0) - LInv) and LIMB_MASK);
end;

function TryInitCTMontCtx(const AModBytes: TBytes; out Ctx: TCTMontCtx;
  out AError: string): Boolean;
var
  LLimbs, I: Integer;
  LOne, LR: TCTNat;
  LBorrow: UInt32;
begin
  AError := '';
  Result := False;

  LLimbs := (Length(AModBytes) + 3) div 4;
  if LLimbs = 0 then
  begin
    AError := 'RSA CT: modulus is empty';
    Exit;
  end;

  Ctx.Limbs := LLimbs;
  CTNatFromBytes(AModBytes, Ctx.N, LLimbs);

  if (Ctx.N[0] and 1) = 0 then
  begin
    AError := 'RSA CT: modulus must be odd';
    Exit;
  end;

  Ctx.NPrime := ComputeNPrime(Ctx.N[0]);

  // Compute R^2 mod N by repeated doubling
  // R = 2^(Limbs*32), so R mod N = R - N * floor(R/N)
  // Easier: start with 1, double Limbs*32*2 times, reduce each time
  // Compute R^2 mod N by repeated doubling (use LLimbs+1 to handle overflow)
  CTNatAlloc(Ctx.RR, LLimbs + 1);
  CTNatAlloc(LOne, LLimbs + 1);
  CTNatAlloc(LR, LLimbs + 1);
  // Extend N to LLimbs+1 for subtraction
  CTNatCopy(Ctx.N, LR, LLimbs);
  LR[LLimbs] := 0;
  Ctx.RR[0] := 1;
  for I := 0 to LLimbs * LIMB_BITS * 2 - 1 do
  begin
    CTNatCopy(Ctx.RR, LOne, LLimbs + 1);
    CTNatAdd(Ctx.RR, LOne, LLimbs + 1);
    CTNatCopy(Ctx.RR, LOne, LLimbs + 1);
    LBorrow := CTNatSub(LOne, LR, LLimbs + 1);
    CTNatCondCopy(LOne, Ctx.RR, LLimbs + 1, 1 - LBorrow);
  end;
  SetLength(Ctx.RR, LLimbs);

  Result := True;
end;

// --- Public API ---

function TryRSACTModExpSign(
  const AEncodedMessage, AModulus, APrivateExponent: TBytes;
  out ASignature: TBytes; out AError: string
): Boolean;
var
  LCtx: TCTMontCtx;
  LMsg, LResult: TCTNat;
  LExpBitLen: Integer;
begin
  SetLength(ASignature, 0);
  AError := '';
  Result := False;

  if Length(AModulus) = 0 then begin AError := 'RSA CT: empty modulus'; Exit; end;
  if Length(APrivateExponent) = 0 then begin AError := 'RSA CT: empty exponent'; Exit; end;

  if not TryInitCTMontCtx(AModulus, LCtx, AError) then
    Exit;

  CTNatFromBytes(AEncodedMessage, LMsg, LCtx.Limbs);
  CTNatAlloc(LResult, LCtx.Limbs);

  // Use modulus bit length as fixed iteration count (not actual exponent length)
  LExpBitLen := Length(AModulus) * 8;

  CTMontModExp(LMsg, APrivateExponent, LExpBitLen, LCtx, LResult);
  CTNatToBytes(LResult, LCtx.Limbs, ASignature, Length(AModulus));
  Result := True;
end;

function TryRSACTSignWithCRT(
  const AEncodedMessage, AModulus, APublicExponent: TBytes;
  const AP, AQ, ADP, ADQ, AQInv: TBytes;
  out ASignature: TBytes; out AError: string
): Boolean;
var
  LCtxP, LCtxQ, LCtxN: TCTMontCtx;
  LMsgP, LMsgQ, LM1, LM2: TCTNat;
  LH, LTemp, LSig, LQNat, LVerify: TCTNat;
  LNLimbs, LPLimbs, LQLimbs: Integer;
  I: Integer;
  LCarry: UInt64;
  LBorrow: UInt32;
  LExpBitLenP, LExpBitLenQ: Integer;
  LMsgNat, LExpNat, LResultNat: TCTNat;
begin
  SetLength(ASignature, 0);
  AError := '';
  Result := False;

  if (Length(AP) = 0) or (Length(AQ) = 0) then
  begin
    AError := 'RSA CT CRT: empty p or q';
    Exit;
  end;

  if not TryInitCTMontCtx(AP, LCtxP, AError) then Exit;
  if not TryInitCTMontCtx(AQ, LCtxQ, AError) then Exit;
  if not TryInitCTMontCtx(AModulus, LCtxN, AError) then Exit;

  LPLimbs := LCtxP.Limbs;
  LQLimbs := LCtxQ.Limbs;
  LNLimbs := LCtxN.Limbs;

  // msg mod p
  CTNatFromBytes(AEncodedMessage, LMsgP, LPLimbs);
  CTNatAlloc(LTemp, LPLimbs);
  CTNatCopy(LMsgP, LTemp, LPLimbs);
  LBorrow := CTNatSub(LTemp, LCtxP.N, LPLimbs);
  CTNatCondCopy(LTemp, LMsgP, LPLimbs, 1 - LBorrow);

  // msg mod q
  CTNatFromBytes(AEncodedMessage, LMsgQ, LQLimbs);
  CTNatAlloc(LTemp, LQLimbs);
  CTNatCopy(LMsgQ, LTemp, LQLimbs);
  LBorrow := CTNatSub(LTemp, LCtxQ.N, LQLimbs);
  CTNatCondCopy(LTemp, LMsgQ, LQLimbs, 1 - LBorrow);

  // m1 = msg^dP mod p
  CTNatAlloc(LM1, LPLimbs);
  LExpBitLenP := Length(AP) * 8;
  CTMontModExp(LMsgP, ADP, LExpBitLenP, LCtxP, LM1);

  // m2 = msg^dQ mod q
  CTNatAlloc(LM2, LQLimbs);
  LExpBitLenQ := Length(AQ) * 8;
  CTMontModExp(LMsgQ, ADQ, LExpBitLenQ, LCtxQ, LM2);

  // h = qInv * (m1 - m2) mod p
  // First: compute (m1 - m2) mod p in p-sized limbs
  CTNatAlloc(LH, LPLimbs);
  CTNatCopy(LM1, LH, LPLimbs);
  // Extend m2 to p-limbs for subtraction
  CTNatAlloc(LTemp, LPLimbs);
  for I := 0 to LQLimbs - 1 do
    if I < LPLimbs then LTemp[I] := LM2[I];
  LBorrow := CTNatSub(LH, LTemp, LPLimbs);
  // If borrow, add p
  CTNatAlloc(LTemp, LPLimbs);
  CTNatCopy(LCtxP.N, LTemp, LPLimbs);
  CTNatCondCopy(LTemp, LH, LPLimbs, 0);
  // Actually need conditional add:
  CTNatAlloc(LTemp, LPLimbs);
  CTNatCopy(LH, LTemp, LPLimbs);
  CTNatAdd(LTemp, LCtxP.N, LPLimbs);
  CTNatCondCopy(LTemp, LH, LPLimbs, LBorrow);

  // h = h * qInv mod p (using Montgomery)
  CTNatAlloc(LTemp, LPLimbs);
  CTNatFromBytes(AQInv, LTemp, LPLimbs);
  // Reduce qInv mod p
  CTNatAlloc(LMsgP, LPLimbs);
  CTNatCopy(LTemp, LMsgP, LPLimbs);
  // Mont multiply: need both in Mont form
  // h_mont = MontMul(h, RR) then result = MontMul(h_mont, qInv_mont)
  // Simpler: result = MontMul(MontMul(h, RR), MontMul(qInv, RR)) then MontMul(result, 1)
  // Even simpler: MontMul(h, qInv) gives h*qInv*R^-1, then MontMul(that, RR) gives h*qInv*R
  // No — just do: tmp = MontMul(h, RR) to get h in Mont form,
  //               tmp2 = MontMul(qInv, RR) to get qInv in Mont form,
  //               result = MontMul(tmp, tmp2) to get h*qInv in Mont form,
  //               final = MontMul(result, 1) to get h*qInv mod p
  // Actually the simplest correct approach:
  // MontMul(a, b) = a*b*R^-1 mod N
  // So MontMul(h, MontMul(qInv, RR)) = MontMul(h, qInv*R) = h*qInv*R*R^-1 = h*qInv mod p
  CTNatAlloc(LMsgP, LPLimbs);
  CTMontMul(LTemp, LCtxP.RR, LMsgP, LCtxP); // qInv in Mont form
  CTMontMul(LH, LMsgP, LTemp, LCtxP); // h * qInv_mont * R^-1 = h * qInv mod p
  CTNatCopy(LTemp, LH, LPLimbs);

  // sig = m2 + h * q
  // Work in N-sized limbs
  CTNatAlloc(LSig, LNLimbs);
  // Copy m2 into sig (zero-extended)
  for I := 0 to LQLimbs - 1 do
    if I < LNLimbs then LSig[I] := LM2[I];

  // Compute h * q and add to sig
  CTNatFromBytes(AQ, LQNat, LNLimbs);
  // Schoolbook multiply h (pLimbs) * q (nLimbs) — we only need nLimbs of result
  for I := 0 to LPLimbs - 1 do
  begin
    LCarry := 0;
    for LBorrow := 0 to LNLimbs - 1 do
    begin
      if Integer(LBorrow) < LNLimbs then
      begin
        if (I + Integer(LBorrow)) < LNLimbs then
        begin
          LCarry := LCarry + UInt64(LSig[I + Integer(LBorrow)]) + UInt64(LH[I]) * UInt64(LQNat[Integer(LBorrow)]);
          LSig[I + Integer(LBorrow)] := UInt32(LCarry and LIMB_MASK);
          LCarry := LCarry shr LIMB_BITS;
        end;
      end;
    end;
  end;

  // Reduce sig mod N (conditional subtract)
  CTNatAlloc(LTemp, LNLimbs);
  CTNatCopy(LSig, LTemp, LNLimbs);
  LBorrow := CTNatSub(LTemp, LCtxN.N, LNLimbs);
  CTNatCondCopy(LTemp, LSig, LNLimbs, 1 - LBorrow);

  // Verify: sig^e mod n == msg (fault protection)
  if Length(APublicExponent) > 0 then
  begin
    CTNatAlloc(LVerify, LNLimbs);
    CTMontModExp(LSig, APublicExponent, Length(APublicExponent) * 8, LCtxN, LVerify);
    CTNatFromBytes(AEncodedMessage, LTemp, LNLimbs);
    // Compare
    LBorrow := 0;
    for I := 0 to LNLimbs - 1 do
      LBorrow := LBorrow or (LVerify[I] xor LTemp[I]);
    if LBorrow <> 0 then
    begin
      AError := 'RSA CT CRT: verify-after-sign failed (possible fault)';
      Exit;
    end;
  end;

  CTNatToBytes(LSig, LNLimbs, ASignature, Length(AModulus));
  Result := True;

  if Length(LM1) > 0 then SecureZeroMemory(@LM1[0], Length(LM1) * SizeOf(UInt32));
  if Length(LM2) > 0 then SecureZeroMemory(@LM2[0], Length(LM2) * SizeOf(UInt32));
  if Length(LH) > 0 then SecureZeroMemory(@LH[0], Length(LH) * SizeOf(UInt32));
  if Length(LTemp) > 0 then SecureZeroMemory(@LTemp[0], Length(LTemp) * SizeOf(UInt32));
end;

end.
