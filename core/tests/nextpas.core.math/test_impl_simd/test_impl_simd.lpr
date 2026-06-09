program test_impl_simd;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.math,
  nextpas.core.math.mat,
  nextpas.core.math.quat,
  nextpas.core.math.vec,
  nextpas.core.math.impl.simd;

var
  T: TTestRunner;

type
  TSingleBitCast = packed record
    case Integer of
      0: (Value: Single);
      1: (Bits: LongWord);
  end;

function SingleFromBits(const ABits: LongWord): Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := ABits;
  Result := LValue.Value;
end;

function SingleBits(const AValue: Single): LongWord;
var
  LValue: TSingleBitCast;
begin
  LValue.Value := AValue;
  Result := LValue.Bits;
end;

function SingleNaN: Single;
begin
  Result := SingleFromBits($7FC00000);
end;

function SingleInfinity: Single;
begin
  Result := SingleFromBits($7F800000);
end;

function SingleNegativeZero: Single;
begin
  Result := SingleFromBits($80000000);
end;

procedure CheckNear(const AExpected, AActual, AEpsilon: Double; const AMessage: string);
var
  LDelta: Double;
begin
  LDelta := AExpected - AActual;
  if LDelta < 0.0 then
    LDelta := -LDelta;
  Check(LDelta <= AEpsilon, AMessage);
end;

procedure CheckVec3f(const AExpectedX, AExpectedY, AExpectedZ: Single; const AActual: TVec3f;
  const AMessage: string);
begin
  CheckNear(AExpectedX, AActual.X, 0.000001, AMessage + '.X');
  CheckNear(AExpectedY, AActual.Y, 0.000001, AMessage + '.Y');
  CheckNear(AExpectedZ, AActual.Z, 0.000001, AMessage + '.Z');
end;

procedure CheckVec4f(const AExpectedX, AExpectedY, AExpectedZ, AExpectedW: Single;
  const AActual: TVec4f; const AMessage: string);
begin
  CheckNear(AExpectedX, AActual.X, 0.000001, AMessage + '.X');
  CheckNear(AExpectedY, AActual.Y, 0.000001, AMessage + '.Y');
  CheckNear(AExpectedZ, AActual.Z, 0.000001, AMessage + '.Z');
  CheckNear(AExpectedW, AActual.W, 0.000001, AMessage + '.W');
end;

procedure CheckSingleBits(const AActual: Single; const AExpectedBits: LongWord;
  const AMessage: string);
begin
  CheckEqual(Int64(AExpectedBits), Int64(SingleBits(AActual)), AMessage);
end;

procedure CheckSingleIeeeParity(const AExpected, AActual: Single; const AMessage: string);
begin
  if IsNaN(AExpected) then
    Check(IsNaN(AActual), AMessage + ' NaN parity')
  else
    CheckSingleBits(AActual, SingleBits(AExpected), AMessage);
end;

procedure CheckVec4fIeeeParity(const AExpected, AActual: TVec4f; const AMessage: string);
begin
  CheckSingleIeeeParity(AExpected.X, AActual.X, AMessage + '.X');
  CheckSingleIeeeParity(AExpected.Y, AActual.Y, AMessage + '.Y');
  CheckSingleIeeeParity(AExpected.Z, AActual.Z, AMessage + '.Z');
  CheckSingleIeeeParity(AExpected.W, AActual.W, AMessage + '.W');
end;

procedure CheckVec3fValue(const AExpected, AActual: TVec3f; const AMessage: string);
begin
  CheckVec3f(AExpected.X, AExpected.Y, AExpected.Z, AActual, AMessage);
end;

procedure CheckVec4fValue(const AExpected, AActual: TVec4f; const AMessage: string);
begin
  CheckVec4f(AExpected.X, AExpected.Y, AExpected.Z, AExpected.W, AActual, AMessage);
end;

procedure ExpectArgumentErrorMessage(const AExpectedMessage, AName: string; const AProc: TTestProc);
begin
  try
    AProc;
  except
    on E: EArgumentError do
    begin
      CheckEqual(AExpectedMessage, E.Message, AName + ' message');
      Exit;
    end;
    on E: Exception do
      Fail(AName + ': expected EArgumentError, got ' + E.ClassName);
  end;
  Fail(AName + ': expected EArgumentError');
end;

procedure RaiseSimdQuatfRotateNaNVector;
begin
  SimdQuatfRotate(TQuatf.Identity, TVec3f.Create(SingleNaN, 0.0, 0.0));
end;

procedure RaiseSimdQuatfRotateInfiniteVector;
begin
  SimdQuatfRotate(TQuatf.Identity, TVec3f.Create(0.0, SingleInfinity, 0.0));
end;

procedure RaiseSimdQuatfRotateInvalidQuaternionAndVector;
begin
  SimdQuatfRotate(TQuatf.Create(SingleNaN, 0.0, 0.0, 1.0),
    TVec3f.Create(SingleNaN, 0.0, 0.0));
end;

procedure TestVec4fSimdHelpers;
var
  A: TVec4f;
  B: TVec4f;
begin
  A := TVec4f.Create(1.0, 2.0, 3.0, 4.0);
  B := TVec4f.Create(5.0, 6.0, 7.0, 8.0);

  CheckVec4f(6.0, 8.0, 10.0, 12.0, SimdVec4fAdd(A, B), 'SimdVec4fAdd');
  CheckVec4f(-4.0, -4.0, -4.0, -4.0, SimdVec4fSub(A, B), 'SimdVec4fSub');
  CheckVec4f(5.0, 12.0, 21.0, 32.0, SimdVec4fMulComponents(A, B),
    'SimdVec4fMulComponents');
  CheckVec4f(2.5, 5.0, 7.5, 10.0, SimdVec4fScale(A, 2.5), 'SimdVec4fScale');
  CheckNear(70.0, SimdVec4fDot(A, B), 0.000001, 'SimdVec4fDot');
  CheckNear(5.0, SimdVec4fLength(TVec4f.Create(0.0, 0.0, 3.0, 4.0)), 0.000001,
    'SimdVec4fLength');
end;

procedure TestVec3fSimdHelpers;
var
  A: TVec3f;
  B: TVec3f;
begin
  A := TVec3f.Create(1.0, 2.0, 3.0);
  B := TVec3f.Create(4.0, 5.0, 6.0);

  CheckNear(32.0, SimdVec3fDot(A, B), 0.000001, 'SimdVec3fDot');
  CheckVec3f(0.0, 0.0, 1.0, SimdVec3fCross(TVec3f.Create(1.0, 0.0, 0.0),
    TVec3f.Create(0.0, 1.0, 0.0)), 'SimdVec3fCross');
end;

procedure TestMat4fSimdHelpers;
var
  M: TMat4f;
  V: TVec4f;
begin
  M := TMat4f.Create(
    TVec4f.Create(1.0, 2.0, 3.0, 4.0),
    TVec4f.Create(5.0, 6.0, 7.0, 8.0),
    TVec4f.Create(9.0, 10.0, 11.0, 12.0),
    TVec4f.Create(13.0, 14.0, 15.0, 16.0));
  V := TVec4f.Create(0.5, -1.0, 2.0, 1.5);

  CheckVec4f(33.0, 36.0, 39.0, 42.0, SimdMat4fMulVec4f(M, V),
    'SimdMat4fMulVec4f');
end;

procedure TestQuatfSimdHelpers;
var
  Q: TQuatf;
  ScaledQ: TQuatf;
  V: TVec3f;
begin
  Q := TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 1.0), Single(HALF_PI));
  V := TVec3f.Create(1.0, 0.0, 0.0);
  CheckVec3f(0.0, 1.0, 0.0, SimdQuatfRotate(Q, V),
    'SimdQuatfRotate quarter turn');

  ScaledQ := TQuatf.Create(Q.X * 2.0, Q.Y * 2.0, Q.Z * 2.0, Q.W * 2.0);
  CheckVec3f(Q.Rotate(V).X, Q.Rotate(V).Y, Q.Rotate(V).Z, SimdQuatfRotate(ScaledQ, V),
    'SimdQuatfRotate matches public Rotate semantics for non-unit quaternions');
end;

procedure TestSimdHelpersMatchPublicMathSemantics;
var
  A4: TVec4f;
  B4: TVec4f;
  V4: TVec4f;
  A3: TVec3f;
  B3: TVec3f;
  V3: TVec3f;
  M: TMat4f;
  Q: TQuatf;
  ScaledQ: TQuatf;
  NegativeQ: TQuatf;
  ZeroQ: TQuatf;
begin
  A4 := TVec4f.Create(-3.5, 0.0, 2.25, 8.0);
  B4 := TVec4f.Create(1.25, -4.0, 0.5, -2.0);
  CheckVec4fValue(A4 + B4, SimdVec4fAdd(A4, B4), 'SimdVec4fAdd public parity');
  CheckVec4fValue(A4 - B4, SimdVec4fSub(A4, B4), 'SimdVec4fSub public parity');
  CheckVec4fValue(TVec4f.MulComponents(A4, B4), SimdVec4fMulComponents(A4, B4),
    'SimdVec4fMulComponents public parity');
  CheckVec4fValue(A4 * Single(-1.75), SimdVec4fScale(A4, -1.75),
    'SimdVec4fScale public parity');
  CheckNear(TVec4f.Dot(A4, B4), SimdVec4fDot(A4, B4), 0.000001,
    'SimdVec4fDot public parity');
  CheckNear(A4.Length, SimdVec4fLength(A4), 0.000001, 'SimdVec4fLength public parity');
  V4 := TVec4f.Create(10000000000000000000.0, -10000000000000000000.0, 0.0, 0.0);
  CheckNear(V4.Length, SimdVec4fLength(V4), 10000000000000.0,
    'SimdVec4fLength large finite public parity');

  A3 := TVec3f.Create(-2.0, 5.0, 0.25);
  B3 := TVec3f.Create(4.5, -1.5, 3.0);
  CheckNear(TVec3f.Dot(A3, B3), SimdVec3fDot(A3, B3), 0.000001,
    'SimdVec3fDot public parity');
  CheckVec3fValue(TVec3f.Cross(A3, B3), SimdVec3fCross(A3, B3),
    'SimdVec3fCross public parity');
  CheckVec3fValue(TVec3f.Cross(A3, A3), SimdVec3fCross(A3, A3),
    'SimdVec3fCross parallel public parity');
  CheckVec3fValue(TVec3f.Cross(TVec3f.Create(0.0, 0.0, 0.0), B3),
    SimdVec3fCross(TVec3f.Create(0.0, 0.0, 0.0), B3),
    'SimdVec3fCross zero public parity');

  V4 := TVec4f.Create(0.5, -1.0, 2.0, 1.5);
  CheckVec4fValue(TMat4f.Identity * V4, SimdMat4fMulVec4f(TMat4f.Identity, V4),
    'SimdMat4fMulVec4f identity public parity');
  M := TMat4f.Create(
    TVec4f.Create(1.0, 2.0, 3.0, 4.0),
    TVec4f.Create(-5.0, 6.5, -7.0, 8.0),
    TVec4f.Create(9.25, -10.0, 11.0, -12.0),
    TVec4f.Create(13.0, 14.0, -15.0, 16.0));
  CheckVec4fValue(M * V4, SimdMat4fMulVec4f(M, V4),
    'SimdMat4fMulVec4f column-major public parity');

  V3 := TVec3f.Create(1.25, -0.5, 2.0);
  Q := TQuatf.FromAxisAngle(TVec3f.Create(1.0, 2.0, -3.0), 0.75);
  ScaledQ := TQuatf.Create(Q.X * 3.0, Q.Y * 3.0, Q.Z * 3.0, Q.W * 3.0);
  NegativeQ := TQuatf.Create(-Q.X, -Q.Y, -Q.Z, -Q.W);
  ZeroQ := TQuatf.Create(0.0, 0.0, 0.0, 0.0);
  CheckVec3fValue(Q.Rotate(V3), SimdQuatfRotate(Q, V3),
    'SimdQuatfRotate arbitrary axis public parity');
  CheckVec3fValue(ScaledQ.Rotate(V3), SimdQuatfRotate(ScaledQ, V3),
    'SimdQuatfRotate scaled quaternion public parity');
  CheckVec3fValue(NegativeQ.Rotate(V3), SimdQuatfRotate(NegativeQ, V3),
    'SimdQuatfRotate negative equivalent public parity');
  CheckVec3fValue(ZeroQ.Rotate(V3), SimdQuatfRotate(ZeroQ, V3),
    'SimdQuatfRotate zero quaternion public parity');
end;

procedure TestSimdDotLengthStableEdgeParity;
var
  HugeLength4: TVec4f;
  HugeDot4A: TVec4f;
  HugeDot4B: TVec4f;
  HugeDot3A: TVec3f;
  HugeDot3B: TVec3f;
  HugeCrossA: TVec3f;
  HugeCrossB: TVec3f;
  ExpectedCross: TVec3f;
  ActualCross: TVec3f;
begin
  HugeLength4 := TVec4f.Create(Single(3.0e20), Single(4.0e20), 0.0, 0.0);
  CheckNear(HugeLength4.Length, SimdVec4fLength(HugeLength4), 1.0e14,
    'SimdVec4fLength huge finite stable public parity');

  HugeDot4A := TVec4f.Create(Single(3.0e20), Single(3.0e20), 0.0, 0.0);
  HugeDot4B := TVec4f.Create(Single(3.0e20), Single(-3.0e20), 0.0, 0.0);
  CheckNear(TVec4f.Dot(HugeDot4A, HugeDot4B), SimdVec4fDot(HugeDot4A, HugeDot4B),
    0.0, 'SimdVec4fDot cancelling huge finite stable public parity');

  HugeDot3A := TVec3f.Create(Single(3.0e20), Single(3.0e20), 1.0);
  HugeDot3B := TVec3f.Create(Single(3.0e20), Single(-3.0e20), 0.0);
  CheckNear(TVec3f.Dot(HugeDot3A, HugeDot3B), SimdVec3fDot(HugeDot3A, HugeDot3B),
    0.0, 'SimdVec3fDot cancelling huge finite stable public parity');

  HugeCrossA := TVec3f.Create(Single(2.0e19), Single(2.0e19), 0.0);
  HugeCrossB := TVec3f.Create(HugeCrossA.X, Single(2.00002e19), 0.0);
  ExpectedCross := TVec3f.Cross(HugeCrossA, HugeCrossB);
  ActualCross := SimdVec3fCross(HugeCrossA, HugeCrossB);
  Check((not IsNaN(ActualCross.Z)) and (not IsInfinite(ActualCross.Z)),
    'SimdVec3fCross cancelling huge finite stable public parity stays finite');
  CheckNear(ExpectedCross.Z, ActualCross.Z, Abs(ExpectedCross.Z) * 0.00001,
    'SimdVec3fCross cancelling huge finite stable public parity');

  HugeCrossA := TVec3f.Create(0.0, Single(3.0e20), 0.0);
  HugeCrossB := TVec3f.Create(0.0, 0.0, Single(3.0e20));
  ActualCross := SimdVec3fCross(HugeCrossA, HugeCrossB);
  CheckSingleBits(ActualCross.X, $7F800000,
    'SimdVec3fCross signed infinity public parity positive X');

  HugeCrossB := TVec3f.Create(0.0, 0.0, Single(-3.0e20));
  ActualCross := SimdVec3fCross(HugeCrossA, HugeCrossB);
  CheckSingleBits(ActualCross.X, $FF800000,
    'SimdVec3fCross signed infinity public parity negative X');

  HugeCrossA := TVec3f.Create(0.0, 0.0, Single(3.0e20));
  HugeCrossB := TVec3f.Create(Single(3.0e20), 0.0, 0.0);
  ActualCross := SimdVec3fCross(HugeCrossA, HugeCrossB);
  CheckSingleBits(ActualCross.Y, $7F800000,
    'SimdVec3fCross signed infinity public parity positive Y');

  HugeCrossB := TVec3f.Create(Single(-3.0e20), 0.0, 0.0);
  ActualCross := SimdVec3fCross(HugeCrossA, HugeCrossB);
  CheckSingleBits(ActualCross.Y, $FF800000,
    'SimdVec3fCross signed infinity public parity negative Y');

  HugeCrossA := TVec3f.Create(Single(3.0e20), 0.0, 0.0);
  HugeCrossB := TVec3f.Create(0.0, Single(3.0e20), 0.0);
  ActualCross := SimdVec3fCross(HugeCrossA, HugeCrossB);
  CheckSingleBits(ActualCross.Z, $7F800000,
    'SimdVec3fCross signed infinity public parity positive Z');

  HugeCrossB := TVec3f.Create(0.0, Single(-3.0e20), 0.0);
  ActualCross := SimdVec3fCross(HugeCrossA, HugeCrossB);
  CheckSingleBits(ActualCross.Z, $FF800000,
    'SimdVec3fCross signed infinity public parity negative Z');
end;

procedure TestSimdVec4fLaneIeeeParity;
var
  A: TVec4f;
  B: TVec4f;
begin
  A := TVec4f.Create(SingleNegativeZero, Single(0.0), SingleInfinity, SingleNaN);
  B := TVec4f.Create(SingleNegativeZero, Single(0.0), Single(1.0), Single(1.0));
  CheckVec4fIeeeParity(A + B, SimdVec4fAdd(A, B),
    'SimdVec4fAdd lane IEEE parity');

  A := TVec4f.Create(SingleNegativeZero, Single(0.0), SingleInfinity, SingleNaN);
  B := TVec4f.Create(Single(0.0), SingleNegativeZero, Single(1.0), Single(1.0));
  CheckVec4fIeeeParity(A - B, SimdVec4fSub(A, B),
    'SimdVec4fSub lane IEEE parity');

  A := TVec4f.Create(SingleNegativeZero, Single(0.0), SingleInfinity, SingleNaN);
  B := TVec4f.Create(Single(2.0), Single(-3.0), Single(-2.0), Single(1.0));
  CheckVec4fIeeeParity(TVec4f.MulComponents(A, B), SimdVec4fMulComponents(A, B),
    'SimdVec4fMulComponents lane IEEE parity');

  A := TVec4f.Create(SingleNegativeZero, Single(0.0), SingleInfinity, SingleNaN);
  CheckVec4fIeeeParity(A * Single(-2.0), SimdVec4fScale(A, Single(-2.0)),
    'SimdVec4fScale lane IEEE parity');
end;

procedure TestSimdVec4fReductionIeeeParity;
var
  A: TVec4f;
  B: TVec4f;
begin
  A := TVec4f.Create(SingleNegativeZero, Single(0.0), SingleNegativeZero, Single(0.0));
  B := TVec4f.Create(Single(1.0), Single(-1.0), Single(2.0), Single(-2.0));
  CheckSingleIeeeParity(TVec4f.Dot(A, B), SimdVec4fDot(A, B),
    'SimdVec4fDot signed-zero reduction IEEE parity');
  CheckSingleIeeeParity(A.Length, SimdVec4fLength(A),
    'SimdVec4fLength signed-zero reduction IEEE parity');

  A := TVec4f.Create(SingleInfinity, Single(3.0), Single(4.0), Single(0.0));
  B := TVec4f.Create(Single(2.0), Single(0.0), Single(0.0), Single(0.0));
  CheckSingleIeeeParity(TVec4f.Dot(A, B), SimdVec4fDot(A, B),
    'SimdVec4fDot infinity reduction IEEE parity');
  CheckSingleIeeeParity(A.Length, SimdVec4fLength(A),
    'SimdVec4fLength infinity reduction IEEE parity');

  A := TVec4f.Create(SingleNaN, Single(3.0), Single(4.0), Single(0.0));
  B := TVec4f.Create(Single(2.0), Single(0.0), Single(0.0), Single(0.0));
  CheckSingleIeeeParity(TVec4f.Dot(A, B), SimdVec4fDot(A, B),
    'SimdVec4fDot NaN reduction IEEE parity');
  CheckSingleIeeeParity(A.Length, SimdVec4fLength(A),
    'SimdVec4fLength NaN reduction IEEE parity');
end;

procedure TestSimdMat4fMulVec4fIeeeParity;
var
  M: TMat4f;
  V: TVec4f;
begin
  M := TMat4f.Create(
    TVec4f.Create(Single(1.25), Single(-2.0), Single(3.5), Single(-4.0)),
    TVec4f.Create(Single(-5.0), Single(6.25), Single(-7.0), Single(8.5)),
    TVec4f.Create(Single(9.0), Single(-10.5), Single(11.25), Single(-12.0)),
    TVec4f.Create(Single(13.5), Single(14.0), Single(-15.25), Single(16.0)));
  V := TVec4f.Create(Single(0.5), Single(-1.25), Single(2.0), Single(-0.75));
  CheckVec4fValue(M * V, SimdMat4fMulVec4f(M, V),
    'SimdMat4fMulVec4f finite public parity');

  M := TMat4f.Create(
    TVec4f.Create(Single(1.0), Single(-2.0), Single(3.0), Single(-4.0)),
    TVec4f.Create(Single(-1.0), Single(2.0), Single(-3.0), Single(4.0)),
    TVec4f.Create(Single(2.0), Single(3.0), Single(-4.0), Single(-5.0)),
    TVec4f.Create(Single(-2.0), Single(-3.0), Single(4.0), Single(5.0)));
  V := TVec4f.Create(SingleNegativeZero, Single(0.0), SingleNegativeZero, Single(0.0));
  CheckVec4fIeeeParity(M * V, SimdMat4fMulVec4f(M, V),
    'SimdMat4fMulVec4f signed-zero IEEE parity');

  M := TMat4f.Create(
    TVec4f.Create(Single(2.0), Single(-2.0), Single(0.5), Single(-0.5)),
    TVec4f.Create(Single(1.0), Single(1.0), Single(1.0), Single(1.0)),
    TVec4f.Create(Single(-1.0), Single(2.0), Single(-3.0), Single(4.0)),
    TVec4f.Create(Single(0.25), Single(-0.25), Single(0.5), Single(-0.5)));
  V := TVec4f.Create(SingleInfinity, Single(2.0), Single(3.0), Single(4.0));
  CheckVec4fIeeeParity(M * V, SimdMat4fMulVec4f(M, V),
    'SimdMat4fMulVec4f infinity IEEE parity');

  V := TVec4f.Create(SingleNaN, Single(2.0), Single(3.0), Single(4.0));
  CheckVec4fIeeeParity(M * V, SimdMat4fMulVec4f(M, V),
    'SimdMat4fMulVec4f NaN IEEE parity');
end;

procedure TestSimdQuatfRotateInvalidVectorPublicParity;
begin
  ExpectArgumentErrorMessage('TQuatf.Rotate: AVector must be finite',
    'SimdQuatfRotate NaN vector public error parity', @RaiseSimdQuatfRotateNaNVector);
  ExpectArgumentErrorMessage('TQuatf.Rotate: AVector must be finite',
    'SimdQuatfRotate infinite vector public error parity',
    @RaiseSimdQuatfRotateInfiniteVector);
  ExpectArgumentErrorMessage('TQuatf.Rotate: quaternion must be finite',
    'SimdQuatfRotate invalid quaternion priority public error parity',
    @RaiseSimdQuatfRotateInvalidQuaternionAndVector);
end;

begin
  T := TTestRunner.Create('nextpas.core.math.impl.simd');
  T.Run('vec4f simd helpers', @TestVec4fSimdHelpers);
  T.Run('vec3f simd helpers', @TestVec3fSimdHelpers);
  T.Run('mat4f simd helpers', @TestMat4fSimdHelpers);
  T.Run('quatf simd helpers', @TestQuatfSimdHelpers);
  T.Run('simd helpers match public math semantics', @TestSimdHelpersMatchPublicMathSemantics);
  T.Run('simd dot length stable edge parity', @TestSimdDotLengthStableEdgeParity);
  T.Run('simd vec4f lane IEEE parity', @TestSimdVec4fLaneIeeeParity);
  T.Run('simd vec4f reduction IEEE parity', @TestSimdVec4fReductionIeeeParity);
  T.Run('simd mat4f mul vec4f IEEE parity', @TestSimdMat4fMulVec4fIeeeParity);
  T.Run('simd quat rotate invalid vector public error parity',
    @TestSimdQuatfRotateInvalidVectorPublicParity);
  T.Summary;
end.
