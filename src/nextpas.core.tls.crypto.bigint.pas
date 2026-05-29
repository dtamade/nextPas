{**
 * Unit: nextpas.core.tls.crypto.bigint
 * Purpose: TLS 1.3 证书签名使用的纯 Pascal 大整数（无外部依赖）
 *
 * 说明：
 * - 仅实现当前 RSA 私钥幂模运算所需最小能力
 * - 使用 16-bit limbs（小端 limb 序）以避免 64-bit 乘加溢出
 * - 模幂采用 Montgomery 乘法 + 平方乘法
 *}

unit nextpas.core.tls.crypto.bigint;

{$mode ObjFPC}{$H+}
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types

interface

uses
  SysUtils;

function TryRSAModExpSignPurePascal(
  const AEncodedMessage: TBytes;
  const AModulus: TBytes;
  const APrivateExponent: TBytes;
  out ASignature: TBytes;
  out AError: string
): Boolean;

function TryBigIntModFromUnsignedBytes(
  const AValue: TBytes;
  const AModulus: TBytes;
  out AResult: TBytes;
  out AError: string
): Boolean;

function TryBigIntModExpFromUnsignedBytes(
  const ABase: TBytes;
  const AExponent: TBytes;
  const AModulus: TBytes;
  out AResult: TBytes;
  out AError: string
): Boolean;

function TryBigIntSubtractModuloFromUnsignedBytes(
  const ALeft: TBytes;
  const ARight: TBytes;
  const AModulus: TBytes;
  out AResult: TBytes;
  out AError: string
): Boolean;

function TryBigIntModMulFromUnsignedBytes(
  const ALeft: TBytes;
  const ARight: TBytes;
  const AModulus: TBytes;
  out AResult: TBytes;
  out AError: string
): Boolean;

function TryBigIntMulFromUnsignedBytes(
  const ALeft: TBytes;
  const ARight: TBytes;
  out AResult: TBytes;
  out AError: string
): Boolean;

function TryBigIntAddFromUnsignedBytes(
  const ALeft: TBytes;
  const ARight: TBytes;
  out AResult: TBytes;
  out AError: string
): Boolean;

function TryBigIntToFixedLengthFromUnsignedBytes(
  const AValue: TBytes;
  ALength: Integer;
  out AResult: TBytes;
  out AError: string
): Boolean;

implementation

type
  TBigNat = array of UInt32;  // little-endian limbs

  TMontgomeryContext = record
    Modulus: TBigNat;
    LimbCount: Integer;
    NPrime: UInt32;
    One: TBigNat;
    RModN: TBigNat;
    R2ModN: TBigNat;
  end;

const
  LIMB_BITS = 32;
  LIMB_BASE: UInt64 = UInt64(1) shl 32;
  LIMB_MASK: UInt64 = UInt64($FFFFFFFF);

  ERR_BIGINT_MODULUS_ZERO = 'E_TLS13_BIGINT_MODULUS_ZERO';
  ERR_BIGINT_OUTPUT_LENGTH_INVALID = 'E_TLS13_BIGINT_OUTPUT_LENGTH_INVALID';
  ERR_BIGINT_OUTPUT_OVERFLOW = 'E_TLS13_BIGINT_OUTPUT_OVERFLOW';

  ERR_BIGINT_RSA_MODULUS_EMPTY = 'E_TLS13_BIGINT_RSA_MODULUS_EMPTY';
  ERR_BIGINT_RSA_MODULUS_ZERO = 'E_TLS13_BIGINT_RSA_MODULUS_ZERO';
  ERR_BIGINT_RSA_MODULUS_ODD_REQUIRED = 'E_TLS13_BIGINT_RSA_MODULUS_ODD_REQUIRED';
  ERR_BIGINT_RSA_PRIVATE_EXPONENT_EMPTY = 'E_TLS13_BIGINT_RSA_PRIVATE_EXPONENT_EMPTY';
  ERR_BIGINT_RSA_PRIVATE_EXPONENT_ZERO = 'E_TLS13_BIGINT_RSA_PRIVATE_EXPONENT_ZERO';
  ERR_BIGINT_RSA_PRIVATE_EXPONENT_TOO_LARGE = 'E_TLS13_BIGINT_RSA_PRIVATE_EXPONENT_TOO_LARGE';
  ERR_BIGINT_RSA_MESSAGE_OUT_OF_RANGE = 'E_TLS13_BIGINT_RSA_MESSAGE_OUT_OF_RANGE';
  ERR_BIGINT_RSA_MESSAGE_NOT_COPRIME = 'E_TLS13_BIGINT_RSA_MESSAGE_NOT_COPRIME';
  ERR_BIGINT_MONTGOMERY_NPRIME_FAILED = 'E_TLS13_BIGINT_MONTGOMERY_NPRIME_FAILED';

function MakeBigIntError(const ACode, AMessage: string): string;
begin
  if ACode <> '' then
    Result := ACode + ': ' + AMessage
  else
    Result := AMessage;
end;

function BigNatBitLength(const AValue: TBigNat): Integer; forward;
function BigNatGetBit(const AValue: TBigNat; ABitIndex: Integer): Boolean; forward;

procedure NormalizeBigNat(var AValue: TBigNat);
var
  LLen: Integer;
begin
  LLen := Length(AValue);
  while (LLen > 0) and (AValue[LLen - 1] = 0) do
    Dec(LLen);

  if LLen <> Length(AValue) then
    SetLength(AValue, LLen);
end;

function BigNatFromWord(AValue: UInt32): TBigNat;
begin
  if AValue = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(Result, 1);
  Result[0] := AValue;
end;

function BigNatIsZero(const AValue: TBigNat): Boolean;
begin
  Result := Length(AValue) = 0;
end;

function BigNatIsOdd(const AValue: TBigNat): Boolean;
begin
  Result := (Length(AValue) > 0) and ((AValue[0] and 1) = 1);
end;

function BigNatIsOne(const AValue: TBigNat): Boolean;
begin
  Result := (Length(AValue) = 1) and (AValue[0] = 1);
end;

function BigNatCompare(const ALeft, ARight: TBigNat): Integer;
var
  I: Integer;
begin
  if Length(ALeft) < Length(ARight) then
    Exit(-1);
  if Length(ALeft) > Length(ARight) then
    Exit(1);

  for I := Length(ALeft) - 1 downto 0 do
  begin
    if ALeft[I] < ARight[I] then
      Exit(-1);
    if ALeft[I] > ARight[I] then
      Exit(1);
  end;

  Result := 0;
end;

function BigNatSubtract(const ALeft, ARight: TBigNat): TBigNat;
var
  I: Integer;
  LBorrow: UInt64;
  LA, LB: UInt64;
  LDiff: UInt64;
begin
  SetLength(Result, Length(ALeft));
  LBorrow := 0;

  for I := 0 to Length(ALeft) - 1 do
  begin
    LA := ALeft[I];
    if I < Length(ARight) then
      LB := ARight[I]
    else
      LB := 0;

    if LA >= LB + LBorrow then
    begin
      LDiff := LA - LB - LBorrow;
      LBorrow := 0;
    end
    else
    begin
      LDiff := LA + LIMB_BASE - LB - LBorrow;
      LBorrow := 1;
    end;

    Result[I] := UInt32(LDiff and LIMB_MASK);
  end;

  NormalizeBigNat(Result);
end;

function BigNatAdd(const ALeft, ARight: TBigNat): TBigNat;
var
  I: Integer;
  LLen: Integer;
  LSum: UInt64;
  LCarry: UInt64;
  LA, LB: UInt64;
begin
  if Length(ALeft) > Length(ARight) then
    LLen := Length(ALeft)
  else
    LLen := Length(ARight);

  SetLength(Result, LLen);

  LCarry := 0;
  for I := 0 to LLen - 1 do
  begin
    if I < Length(ALeft) then
      LA := ALeft[I]
    else
      LA := 0;

    if I < Length(ARight) then
      LB := ARight[I]
    else
      LB := 0;

    LSum := LA + LB + LCarry;
    Result[I] := UInt32(LSum and LIMB_MASK);
    LCarry := LSum shr LIMB_BITS;
  end;

  if LCarry <> 0 then
  begin
    SetLength(Result, LLen + 1);
    Result[LLen] := UInt32(LCarry and LIMB_MASK);
  end;

  NormalizeBigNat(Result);
end;

procedure BigNatAddWord(var AValue: TBigNat; AWord: UInt32);
var
  I: Integer;
  LCarry: UInt64;
  LSum: UInt64;
begin
  if AWord = 0 then
    Exit;

  if Length(AValue) = 0 then
    AValue := BigNatFromWord(AWord)
  else
  begin
    LCarry := AWord;
    I := 0;
    while (LCarry <> 0) and (I < Length(AValue)) do
    begin
      LSum := UInt32(AValue[I]) + LCarry;
      AValue[I] := UInt32(LSum and LIMB_MASK);
      LCarry := LSum shr LIMB_BITS;
      Inc(I);
    end;

    if LCarry <> 0 then
    begin
      SetLength(AValue, Length(AValue) + 1);
      AValue[High(AValue)] := UInt32(LCarry and LIMB_MASK);
    end;
  end;

  NormalizeBigNat(AValue);
end;

function BigNatMultiply(const ALeft, ARight: TBigNat): TBigNat;
var
  I, J, K: Integer;
  LUV: UInt64;
  LCarry: UInt64;
begin
  if BigNatIsZero(ALeft) or BigNatIsZero(ARight) then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(Result, Length(ALeft) + Length(ARight));
  FillChar(Result[0], Length(Result) * SizeOf(UInt32), 0);

  for I := 0 to Length(ALeft) - 1 do
  begin
    LCarry := 0;
    for J := 0 to Length(ARight) - 1 do
    begin
      LUV := UInt64(ALeft[I]) * UInt64(ARight[J]) + UInt64(Result[I + J]) + LCarry;
      Result[I + J] := UInt32(LUV and LIMB_MASK);
      LCarry := LUV shr LIMB_BITS;
    end;

    K := I + Length(ARight);
    while LCarry <> 0 do
    begin
      LUV := UInt64(Result[K]) + LCarry;
      Result[K] := UInt32(LUV and LIMB_MASK);
      LCarry := LUV shr LIMB_BITS;
      Inc(K);
    end;
  end;

  NormalizeBigNat(Result);
end;

procedure BigNatSubtractInPlace(var ALeft: TBigNat; const ARight: TBigNat);
var
  I: Integer;
  LBorrow: UInt64;
  LA, LB: UInt64;
  LDiff: UInt64;
begin
  LBorrow := 0;

  for I := 0 to Length(ALeft) - 1 do
  begin
    LA := ALeft[I];
    if I < Length(ARight) then
      LB := ARight[I]
    else
      LB := 0;

    if LA >= LB + LBorrow then
    begin
      LDiff := LA - LB - LBorrow;
      LBorrow := 0;
    end
    else
    begin
      LDiff := LA + LIMB_BASE - LB - LBorrow;
      LBorrow := 1;
    end;

    ALeft[I] := UInt32(LDiff and LIMB_MASK);
  end;

  NormalizeBigNat(ALeft);
end;

procedure BigNatDoubleInPlace(var AValue: TBigNat);
var
  I: Integer;
  LSum: UInt64;
  LCarry: UInt64;
begin
  if Length(AValue) = 0 then
    Exit;

  LCarry := 0;
  for I := 0 to Length(AValue) - 1 do
  begin
    LSum := (UInt64(AValue[I]) shl 1) + LCarry;
    AValue[I] := UInt32(LSum and LIMB_MASK);
    LCarry := LSum shr LIMB_BITS;
  end;

  if LCarry <> 0 then
  begin
    SetLength(AValue, Length(AValue) + 1);
    AValue[High(AValue)] := UInt32(LCarry and LIMB_MASK);
  end;
end;

procedure BigNatDoubleMod(var AValue: TBigNat; const AModulus: TBigNat);
begin
  BigNatDoubleInPlace(AValue);
  if BigNatCompare(AValue, AModulus) >= 0 then
    BigNatSubtractInPlace(AValue, AModulus);
end;

function BigNatMod(const AValue, AModulus: TBigNat): TBigNat;
var
  I: Integer;
begin
  if BigNatIsZero(AModulus) then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  if BigNatCompare(AValue, AModulus) < 0 then
  begin
    Result := Copy(AValue, 0, Length(AValue));
    Exit;
  end;

  Result := BigNatFromWord(0);
  for I := BigNatBitLength(AValue) - 1 downto 0 do
  begin
    BigNatDoubleMod(Result, AModulus);
    if BigNatGetBit(AValue, I) then
    begin
      BigNatAddWord(Result, 1);
      if BigNatCompare(Result, AModulus) >= 0 then
        BigNatSubtractInPlace(Result, AModulus);
    end;
  end;

  NormalizeBigNat(Result);
end;

function BigNatBitLength(const AValue: TBigNat): Integer;
var
  LTop: UInt32;
begin
  if Length(AValue) = 0 then
    Exit(0);

  LTop := AValue[Length(AValue) - 1];
  Result := (Length(AValue) - 1) * LIMB_BITS;
  while LTop <> 0 do
  begin
    Inc(Result);
    LTop := LTop shr 1;
  end;
end;

function BigNatGetBit(const AValue: TBigNat; ABitIndex: Integer): Boolean;
var
  LLimbIndex: Integer;
  LBitOffset: Integer;
begin
  if ABitIndex < 0 then
    Exit(False);

  LLimbIndex := ABitIndex div LIMB_BITS;
  if LLimbIndex >= Length(AValue) then
    Exit(False);

  LBitOffset := ABitIndex mod LIMB_BITS;
  Result := ((AValue[LLimbIndex] shr LBitOffset) and 1) = 1;
end;

function BigNatFromUnsignedBytes(const ABytes: TBytes): TBigNat;
var
  LLimbCount: Integer;
  LByteIndex: Integer;
  LLimbIndex: Integer;
  LWord: UInt64;
  LShift: Integer;
begin
  if Length(ABytes) = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  LLimbCount := (Length(ABytes) + 3) div 4;
  SetLength(Result, LLimbCount);
  FillChar(Result[0], LLimbCount * SizeOf(UInt32), 0);

  LByteIndex := Length(ABytes) - 1;
  LLimbIndex := 0;
  LWord := 0;
  LShift := 0;

  while LByteIndex >= 0 do
  begin
    LWord := LWord or (UInt32(ABytes[LByteIndex]) shl LShift);
    Dec(LByteIndex);
    Inc(LShift, 8);

    if LShift = LIMB_BITS then
    begin
      Result[LLimbIndex] := UInt32(LWord and LIMB_MASK);
      Inc(LLimbIndex);
      LWord := 0;
      LShift := 0;
    end;
  end;

  if LShift <> 0 then
    Result[LLimbIndex] := UInt32(LWord and LIMB_MASK);

  NormalizeBigNat(Result);
end;

function TryBigNatToFixedLengthBytes(
  const AValue: TBigNat;
  ALength: Integer;
  out ABytes: TBytes;
  out AError: string
): Boolean;
var
  LByteIndex: Integer;
  LLimbIndex: Integer;
  LShift: Integer;
  LBitLen: Integer;
begin
  AError := '';
  SetLength(ABytes, 0);
  Result := False;

  if ALength <= 0 then
  begin
    AError := MakeBigIntError(ERR_BIGINT_OUTPUT_LENGTH_INVALID, 'RSA output length is invalid');
    Exit;
  end;

  LBitLen := BigNatBitLength(AValue);
  if LBitLen > ALength * 8 then
  begin
    AError := MakeBigIntError(ERR_BIGINT_OUTPUT_OVERFLOW, 'RSA output does not fit target length');
    Exit;
  end;

  SetLength(ABytes, ALength);
  FillChar(ABytes[0], ALength, 0);

  for LByteIndex := 0 to ALength - 1 do
  begin
    LLimbIndex := LByteIndex div 4;
    LShift := (LByteIndex mod 4) * 8;

    if LLimbIndex < Length(AValue) then
      ABytes[ALength - 1 - LByteIndex] := Byte((AValue[LLimbIndex] shr LShift) and $FF)
    else
      ABytes[ALength - 1 - LByteIndex] := 0;
  end;

  Result := True;
end;

function BigNatToUnsignedBytes(const AValue: TBigNat): TBytes;
var
  LByteLen: Integer;
  LByteIndex: Integer;
  LLimbIndex: Integer;
  LShift: Integer;
begin
  if BigNatIsZero(AValue) then
  begin
    SetLength(Result, 1);
    Result[0] := 0;
    Exit;
  end;

  LByteLen := (BigNatBitLength(AValue) + 7) div 8;
  SetLength(Result, LByteLen);

  for LByteIndex := 0 to LByteLen - 1 do
  begin
    LLimbIndex := LByteIndex div 4;
    LShift := (LByteIndex mod 4) * 8;
    Result[LByteLen - 1 - LByteIndex] := Byte((AValue[LLimbIndex] shr LShift) and $FF);
  end;
end;

function TryComputeMontgomeryNPrime(AN0: UInt32; out ANPrime: UInt32): Boolean;
var
  LInv: UInt64;
  LFactor: UInt64;
  LTmp: UInt64;
  I: Integer;
begin
  ANPrime := 0;
  Result := False;

  if (AN0 and 1) = 0 then
    Exit;

  LInv := 1;
  for I := 0 to 4 do
  begin
    LFactor := (UInt64(AN0) * LInv) and LIMB_MASK;
    LTmp := (LIMB_BASE + 2 - LFactor) and LIMB_MASK;
    LInv := (LInv * LTmp) and LIMB_MASK;
  end;

  ANPrime := UInt32((LIMB_BASE - LInv) and LIMB_MASK);
  Result := True;
end;

function TryInitMontgomeryContext(
  const AModulus: TBigNat;
  out ACtx: TMontgomeryContext;
  out AError: string
): Boolean;
var
  LSteps: Integer;
  I: Integer;
begin
  FillChar(ACtx, SizeOf(ACtx), 0);
  AError := '';
  Result := False;

  if BigNatIsZero(AModulus) then
  begin
    AError := MakeBigIntError(ERR_BIGINT_RSA_MODULUS_ZERO, 'RSA modulus is zero');
    Exit;
  end;

  if not BigNatIsOdd(AModulus) then
  begin
    AError := MakeBigIntError(ERR_BIGINT_RSA_MODULUS_ODD_REQUIRED, 'RSA modulus must be odd');
    Exit;
  end;

  ACtx.Modulus := Copy(AModulus, 0, Length(AModulus));
  ACtx.LimbCount := Length(ACtx.Modulus);
  ACtx.One := BigNatFromWord(1);

  if not TryComputeMontgomeryNPrime(ACtx.Modulus[0], ACtx.NPrime) then
  begin
    AError := MakeBigIntError(ERR_BIGINT_MONTGOMERY_NPRIME_FAILED, 'Failed to compute Montgomery parameter n''');
    Exit;
  end;

  ACtx.RModN := BigNatFromWord(1);
  LSteps := ACtx.LimbCount * LIMB_BITS;

  for I := 1 to LSteps do
    BigNatDoubleMod(ACtx.RModN, ACtx.Modulus);

  ACtx.R2ModN := Copy(ACtx.RModN, 0, Length(ACtx.RModN));
  for I := 1 to LSteps do
    BigNatDoubleMod(ACtx.R2ModN, ACtx.Modulus);

  Result := True;
end;

procedure MontgomeryMultiplyInto(
  const ACtx: TMontgomeryContext;
  const ALeft, ARight: TBigNat;
  var AResult: TBigNat;
  var AScratch: TBigNat
);
var
  LN: Integer;
  I, J, K: Integer;
  LAI, LBJ, LM: UInt32;
  LUV: UInt64;
  LCarry: UInt64;
begin
  LN := ACtx.LimbCount;

  if Length(AScratch) <> (2 * LN + 2) then
    SetLength(AScratch, 2 * LN + 2);
  FillChar(AScratch[0], Length(AScratch) * SizeOf(UInt32), 0);

  for I := 0 to LN - 1 do
  begin
    if I < Length(ALeft) then
      LAI := ALeft[I]
    else
      LAI := 0;

    LCarry := 0;
    for J := 0 to LN - 1 do
    begin
      if J < Length(ARight) then
        LBJ := ARight[J]
      else
        LBJ := 0;

      LUV := UInt64(LAI) * UInt64(LBJ) + UInt64(AScratch[I + J]) + LCarry;
      AScratch[I + J] := UInt32(LUV and LIMB_MASK);
      LCarry := LUV shr LIMB_BITS;
    end;

    K := I + LN;
    while LCarry <> 0 do
    begin
      LUV := UInt64(AScratch[K]) + LCarry;
      AScratch[K] := UInt32(LUV and LIMB_MASK);
      LCarry := LUV shr LIMB_BITS;
      Inc(K);
    end;
  end;

  for I := 0 to LN - 1 do
  begin
    LM := UInt32((UInt64(AScratch[I]) * UInt64(ACtx.NPrime)) and LIMB_MASK);

    LCarry := 0;
    for J := 0 to LN - 1 do
    begin
      LUV := UInt64(LM) * UInt64(ACtx.Modulus[J]) + UInt64(AScratch[I + J]) + LCarry;
      AScratch[I + J] := UInt32(LUV and LIMB_MASK);
      LCarry := LUV shr LIMB_BITS;
    end;

    K := I + LN;
    while LCarry <> 0 do
    begin
      LUV := UInt64(AScratch[K]) + LCarry;
      AScratch[K] := UInt32(LUV and LIMB_MASK);
      LCarry := LUV shr LIMB_BITS;
      Inc(K);
    end;
  end;

  if Length(AResult) <> (LN + 1) then
    SetLength(AResult, LN + 1);
  for I := 0 to LN do
    AResult[I] := AScratch[I + LN];

  NormalizeBigNat(AResult);
  if BigNatCompare(AResult, ACtx.Modulus) >= 0 then
    BigNatSubtractInPlace(AResult, ACtx.Modulus);
end;

function MontgomeryMultiply(
  const ACtx: TMontgomeryContext;
  const ALeft, ARight: TBigNat
): TBigNat;
var
  LScratch: TBigNat;
begin
  SetLength(Result, 0);
  SetLength(LScratch, 0);
  MontgomeryMultiplyInto(ACtx, ALeft, ARight, Result, LScratch);
end;

function BigNatModExpMontgomery(
  const ABase, AExponent: TBigNat;
  const ACtx: TMontgomeryContext
): TBigNat;
var
  LAccumulator: TBigNat;
  LBaseMont: TBigNat;
  LNext: TBigNat;
  LTmp: TBigNat;
  LScratch: TBigNat;
  LBitLength: Integer;
  I: Integer;
begin
  LAccumulator := Copy(ACtx.RModN, 0, Length(ACtx.RModN));
  SetLength(LBaseMont, 0);
  SetLength(LNext, 0);
  SetLength(LScratch, 0);

  MontgomeryMultiplyInto(ACtx, ABase, ACtx.R2ModN, LBaseMont, LScratch);

  LBitLength := BigNatBitLength(AExponent);
  for I := LBitLength - 1 downto 0 do
  begin
    MontgomeryMultiplyInto(ACtx, LAccumulator, LAccumulator, LNext, LScratch);
    LTmp := LAccumulator;
    LAccumulator := LNext;
    LNext := LTmp;

    if BigNatGetBit(AExponent, I) then
    begin
      MontgomeryMultiplyInto(ACtx, LAccumulator, LBaseMont, LNext, LScratch);
      LTmp := LAccumulator;
      LAccumulator := LNext;
      LNext := LTmp;
    end;
  end;

  SetLength(Result, 0);
  MontgomeryMultiplyInto(ACtx, LAccumulator, ACtx.One, Result, LScratch);
end;

function BigNatModMultiplyClassic(
  const ALeft, ARight, AModulus: TBigNat
): TBigNat;
begin
  Result := BigNatMultiply(BigNatMod(ALeft, AModulus), BigNatMod(ARight, AModulus));
  Result := BigNatMod(Result, AModulus);
end;

function BigNatModExpClassic(
  const ABase, AExponent, AModulus: TBigNat
): TBigNat;
var
  LAccumulator: TBigNat;
  LBaseReduced: TBigNat;
  LBitLength: Integer;
  I: Integer;
begin
  LAccumulator := BigNatMod(BigNatFromWord(1), AModulus);
  LBaseReduced := BigNatMod(ABase, AModulus);

  LBitLength := BigNatBitLength(AExponent);
  for I := LBitLength - 1 downto 0 do
  begin
    LAccumulator := BigNatMod(BigNatMultiply(LAccumulator, LAccumulator), AModulus);
    if BigNatGetBit(AExponent, I) then
      LAccumulator := BigNatMod(BigNatMultiply(LAccumulator, LBaseReduced), AModulus);
  end;

  Result := LAccumulator;
end;

function BigNatGCD(const ALeft, ARight: TBigNat): TBigNat;
var
  LA: TBigNat;
  LB: TBigNat;
  LTmp: TBigNat;
begin
  LA := Copy(ALeft, 0, Length(ALeft));
  LB := Copy(ARight, 0, Length(ARight));
  NormalizeBigNat(LA);
  NormalizeBigNat(LB);

  while not BigNatIsZero(LB) do
  begin
    LTmp := BigNatMod(LA, LB);
    LA := LB;
    LB := LTmp;
  end;

  Result := LA;
end;

function TryRSAModExpSignPurePascal(
  const AEncodedMessage: TBytes;
  const AModulus: TBytes;
  const APrivateExponent: TBytes;
  out ASignature: TBytes;
  out AError: string
): Boolean;
var
  LMessage: TBigNat;
  LModulus: TBigNat;
  LExponent: TBigNat;
  LSignatureNat: TBigNat;
  LMontCtx: TMontgomeryContext;
  LGCD: TBigNat;
  LModulusBitLen: Integer;
  LExponentBitLen: Integer;
begin
  SetLength(ASignature, 0);
  AError := '';
  Result := False;

  if Length(AModulus) = 0 then
  begin
    AError := MakeBigIntError(ERR_BIGINT_RSA_MODULUS_EMPTY, 'RSA modulus is empty');
    Exit;
  end;

  if Length(APrivateExponent) = 0 then
  begin
    AError := MakeBigIntError(ERR_BIGINT_RSA_PRIVATE_EXPONENT_EMPTY, 'RSA private exponent is empty');
    Exit;
  end;

  LMessage := BigNatFromUnsignedBytes(AEncodedMessage);
  LModulus := BigNatFromUnsignedBytes(AModulus);
  LExponent := BigNatFromUnsignedBytes(APrivateExponent);

  if BigNatIsZero(LModulus) then
  begin
    AError := MakeBigIntError(ERR_BIGINT_RSA_MODULUS_ZERO, 'RSA modulus is zero');
    Exit;
  end;

  if BigNatIsZero(LExponent) then
  begin
    AError := MakeBigIntError(ERR_BIGINT_RSA_PRIVATE_EXPONENT_ZERO, 'RSA private exponent is zero');
    Exit;
  end;

  LModulusBitLen := BigNatBitLength(LModulus);
  LExponentBitLen := BigNatBitLength(LExponent);
  if LExponentBitLen > LModulusBitLen * 2 then
  begin
    AError := MakeBigIntError(ERR_BIGINT_RSA_PRIVATE_EXPONENT_TOO_LARGE, 'RSA private exponent is unreasonably large');
    Exit;
  end;

  if BigNatCompare(LMessage, LModulus) >= 0 then
  begin
    AError := MakeBigIntError(ERR_BIGINT_RSA_MESSAGE_OUT_OF_RANGE, 'Encoded message representative is not less than RSA modulus');
    Exit;
  end;

  LGCD := BigNatGCD(LMessage, LModulus);
  if not BigNatIsOne(LGCD) then
  begin
    AError := MakeBigIntError(ERR_BIGINT_RSA_MESSAGE_NOT_COPRIME, 'Encoded message representative is not coprime to RSA modulus');
    Exit;
  end;

  if not TryInitMontgomeryContext(LModulus, LMontCtx, AError) then
    Exit;

  LSignatureNat := BigNatModExpMontgomery(LMessage, LExponent, LMontCtx);
  if not TryBigNatToFixedLengthBytes(LSignatureNat, Length(AModulus), ASignature, AError) then
    Exit;

  Result := True;
end;

function TryBigIntModFromUnsignedBytes(
  const AValue: TBytes;
  const AModulus: TBytes;
  out AResult: TBytes;
  out AError: string
): Boolean;
var
  LValue: TBigNat;
  LModulus: TBigNat;
  LReduced: TBigNat;
begin
  SetLength(AResult, 0);
  AError := '';
  Result := False;

  LValue := BigNatFromUnsignedBytes(AValue);
  LModulus := BigNatFromUnsignedBytes(AModulus);

  if BigNatIsZero(LModulus) then
  begin
    AError := MakeBigIntError(ERR_BIGINT_MODULUS_ZERO, 'Modulus is zero');
    Exit;
  end;

  LReduced := BigNatMod(LValue, LModulus);
  AResult := BigNatToUnsignedBytes(LReduced);
  Result := True;
end;

function TryBigIntModExpFromUnsignedBytes(
  const ABase: TBytes;
  const AExponent: TBytes;
  const AModulus: TBytes;
  out AResult: TBytes;
  out AError: string
): Boolean;
var
  LBase: TBigNat;
  LExponent: TBigNat;
  LModulus: TBigNat;
  LReducedBase: TBigNat;
  LCtx: TMontgomeryContext;
  LOut: TBigNat;
begin
  SetLength(AResult, 0);
  AError := '';
  Result := False;

  LBase := BigNatFromUnsignedBytes(ABase);
  LExponent := BigNatFromUnsignedBytes(AExponent);
  LModulus := BigNatFromUnsignedBytes(AModulus);

  if BigNatIsZero(LModulus) then
  begin
    AError := MakeBigIntError(ERR_BIGINT_MODULUS_ZERO, 'Modulus is zero');
    Exit;
  end;

  if BigNatIsZero(LExponent) then
  begin
    AResult := BigNatToUnsignedBytes(BigNatMod(BigNatFromWord(1), LModulus));
    Result := True;
    Exit;
  end;

  LReducedBase := BigNatMod(LBase, LModulus);

  if BigNatIsOdd(LModulus) and TryInitMontgomeryContext(LModulus, LCtx, AError) then
    LOut := BigNatModExpMontgomery(LReducedBase, LExponent, LCtx)
  else
  begin
    AError := '';
    LOut := BigNatModExpClassic(LReducedBase, LExponent, LModulus);
  end;

  AResult := BigNatToUnsignedBytes(LOut);
  Result := True;
end;

function TryBigIntSubtractModuloFromUnsignedBytes(
  const ALeft: TBytes;
  const ARight: TBytes;
  const AModulus: TBytes;
  out AResult: TBytes;
  out AError: string
): Boolean;
var
  LLeft: TBigNat;
  LRight: TBigNat;
  LModulus: TBigNat;
  LRes: TBigNat;
begin
  SetLength(AResult, 0);
  AError := '';
  Result := False;

  LLeft := BigNatFromUnsignedBytes(ALeft);
  LRight := BigNatFromUnsignedBytes(ARight);
  LModulus := BigNatFromUnsignedBytes(AModulus);

  if BigNatIsZero(LModulus) then
  begin
    AError := MakeBigIntError(ERR_BIGINT_MODULUS_ZERO, 'Modulus is zero');
    Exit;
  end;

  LLeft := BigNatMod(LLeft, LModulus);
  LRight := BigNatMod(LRight, LModulus);

  if BigNatCompare(LLeft, LRight) >= 0 then
    LRes := BigNatSubtract(LLeft, LRight)
  else
    LRes := BigNatSubtract(LModulus, BigNatSubtract(LRight, LLeft));

  AResult := BigNatToUnsignedBytes(LRes);
  Result := True;
end;

function TryBigIntModMulFromUnsignedBytes(
  const ALeft: TBytes;
  const ARight: TBytes;
  const AModulus: TBytes;
  out AResult: TBytes;
  out AError: string
): Boolean;
var
  LLeft: TBigNat;
  LRight: TBigNat;
  LModulus: TBigNat;
  LCtx: TMontgomeryContext;
  LLeftMont: TBigNat;
  LRightMont: TBigNat;
  LProdMont: TBigNat;
  LRes: TBigNat;
begin
  SetLength(AResult, 0);
  AError := '';
  Result := False;

  LLeft := BigNatFromUnsignedBytes(ALeft);
  LRight := BigNatFromUnsignedBytes(ARight);
  LModulus := BigNatFromUnsignedBytes(AModulus);

  if BigNatIsZero(LModulus) then
  begin
    AError := MakeBigIntError(ERR_BIGINT_MODULUS_ZERO, 'Modulus is zero');
    Exit;
  end;

  LLeft := BigNatMod(LLeft, LModulus);
  LRight := BigNatMod(LRight, LModulus);

  if BigNatIsOdd(LModulus) and TryInitMontgomeryContext(LModulus, LCtx, AError) then
  begin
    LLeftMont := MontgomeryMultiply(LCtx, LLeft, LCtx.R2ModN);
    LRightMont := MontgomeryMultiply(LCtx, LRight, LCtx.R2ModN);
    LProdMont := MontgomeryMultiply(LCtx, LLeftMont, LRightMont);
    LRes := MontgomeryMultiply(LCtx, LProdMont, LCtx.One);
  end
  else
  begin
    AError := '';
    LRes := BigNatModMultiplyClassic(LLeft, LRight, LModulus);
  end;

  AResult := BigNatToUnsignedBytes(LRes);
  Result := True;
end;

function TryBigIntMulFromUnsignedBytes(
  const ALeft: TBytes;
  const ARight: TBytes;
  out AResult: TBytes;
  out AError: string
): Boolean;
var
  LLeft: TBigNat;
  LRight: TBigNat;
begin
  SetLength(AResult, 0);
  AError := '';
  Result := False;

  LLeft := BigNatFromUnsignedBytes(ALeft);
  LRight := BigNatFromUnsignedBytes(ARight);
  AResult := BigNatToUnsignedBytes(BigNatMultiply(LLeft, LRight));
  Result := True;
end;

function TryBigIntAddFromUnsignedBytes(
  const ALeft: TBytes;
  const ARight: TBytes;
  out AResult: TBytes;
  out AError: string
): Boolean;
var
  LLeft: TBigNat;
  LRight: TBigNat;
begin
  SetLength(AResult, 0);
  AError := '';
  Result := False;

  LLeft := BigNatFromUnsignedBytes(ALeft);
  LRight := BigNatFromUnsignedBytes(ARight);
  AResult := BigNatToUnsignedBytes(BigNatAdd(LLeft, LRight));
  Result := True;
end;

function TryBigIntToFixedLengthFromUnsignedBytes(
  const AValue: TBytes;
  ALength: Integer;
  out AResult: TBytes;
  out AError: string
): Boolean;
var
  LValue: TBigNat;
begin
  LValue := BigNatFromUnsignedBytes(AValue);
  Result := TryBigNatToFixedLengthBytes(LValue, ALength, AResult, AError);
end;

end.
