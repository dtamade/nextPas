{ 128-bit multiplication and IEEE 754 double utilities }

procedure UMul128(const A, B: UInt64; out AHi, ALo: UInt64);
var
  A0, A1, B0, B1: UInt64;
  P00, P01, P10, P11: UInt64;
  M0, M1: UInt64;
begin
  A0 := A and $FFFFFFFF;
  A1 := A shr 32;
  B0 := B and $FFFFFFFF;
  B1 := B shr 32;
  P00 := A0 * B0;
  P01 := A0 * B1;
  P10 := A1 * B0;
  P11 := A1 * B1;
  M0 := P01 + (P00 shr 32);
  M1 := P10 + (M0 and $FFFFFFFF);
  AHi := P11 + (M0 shr 32) + (M1 shr 32);
  ALo := ((M1 and $FFFFFFFF) shl 32) or (P00 and $FFFFFFFF);
end;

function UMul128Hi(const A, B: UInt64): UInt64;
var
  LLo: UInt64;
begin
  UMul128(A, B, Result, LLo);
end;

const
  DOUBLE_MANTISSA_BITS = 52;
  DOUBLE_EXPONENT_BITS = 11;
  DOUBLE_BIAS = 1023;
  DOUBLE_MANTISSA_MASK = UInt64((UInt64(1) shl 52) - 1);
  DOUBLE_EXPONENT_MASK = UInt64($7FF);
  DOUBLE_SIGN_MASK = UInt64(1) shl 63;
  DOUBLE_HIDDEN_BIT = UInt64(1) shl 52;

procedure DoubleUnpack(const AValue: Double; out ASign: Boolean;
  out AExp: Int32; out AMant: UInt64); inline;
var
  LBits: UInt64 absolute AValue;
begin
  ASign := (LBits and DOUBLE_SIGN_MASK) <> 0;
  AExp := Int32((LBits shr DOUBLE_MANTISSA_BITS) and DOUBLE_EXPONENT_MASK);
  AMant := LBits and DOUBLE_MANTISSA_MASK;
end;

function DoublePack(const ASign: Boolean; const AExp: Int32;
  const AMant: UInt64): Double; inline;
var
  LBits: UInt64;
  LResult: Double absolute LBits;
begin
  LBits := AMant and DOUBLE_MANTISSA_MASK;
  LBits := LBits or (UInt64(AExp and $7FF) shl DOUBLE_MANTISSA_BITS);
  if ASign then
    LBits := LBits or DOUBLE_SIGN_MASK;
  Result := LResult;
end;

function DoubleIsNaN(const AValue: Double): Boolean; inline;
var
  LBits: UInt64 absolute AValue;
begin
  Result := ((LBits shr 52) and $7FF = $7FF) and ((LBits and DOUBLE_MANTISSA_MASK) <> 0);
end;

function DoubleIsInf(const AValue: Double): Boolean; inline;
var
  LBits: UInt64 absolute AValue;
begin
  Result := ((LBits shr 52) and $7FF = $7FF) and ((LBits and DOUBLE_MANTISSA_MASK) = 0);
end;

function DoubleIsZero(const AValue: Double): Boolean; inline;
var
  LBits: UInt64 absolute AValue;
begin
  Result := (LBits and not DOUBLE_SIGN_MASK) = 0;
end;
