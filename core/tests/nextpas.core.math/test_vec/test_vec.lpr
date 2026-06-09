program test_vec;

{$I nextpas.core.settings.inc}

uses
  Math,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.math.scalar,
  nextpas.core.math.vec;

var
  T: TTestRunner;
  Vec2fSink: TVec2f;
  Vec3fSink: TVec3f;
  Vec4fSink: TVec4f;
  Vec2dSink: TVec2d;
  Vec3dSink: TVec3d;
  Vec4dSink: TVec4d;

type
  TSingleBitCast = packed record
    case Integer of
      0: (Value: Single);
      1: (Bits: LongWord);
  end;

  TDoubleBitCast = packed record
    case Integer of
      0: (Value: Double);
      1: (Bits: QWord);
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

procedure CheckScaledNear(const AExpected, AActual, AScale, AEpsilon: Double; const AMessage: string);
begin
  CheckNear(AExpected / AScale, AActual / AScale, AEpsilon, AMessage);
end;

procedure CheckPointerOffset(const ABase, AField: Pointer; const AExpectedOffset: PtrUInt;
  const AMessage: string);
begin
  CheckEqual(Int64(AExpectedOffset), Int64(PtrUInt(AField) - PtrUInt(ABase)), AMessage);
end;

procedure CheckVec2f(const AExpectedX, AExpectedY: Single; const AActual: TVec2f;
  const AMessage: string);
begin
  CheckNear(AExpectedX, AActual.X, 0.000001, AMessage + '.X');
  CheckNear(AExpectedY, AActual.Y, 0.000001, AMessage + '.Y');
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

procedure CheckVec2d(const AExpectedX, AExpectedY: Double; const AActual: TVec2d;
  const AMessage: string);
begin
  CheckNear(AExpectedX, AActual.X, 0.000000000001, AMessage + '.X');
  CheckNear(AExpectedY, AActual.Y, 0.000000000001, AMessage + '.Y');
end;

procedure CheckVec3d(const AExpectedX, AExpectedY, AExpectedZ: Double; const AActual: TVec3d;
  const AMessage: string);
begin
  CheckNear(AExpectedX, AActual.X, 0.000000000001, AMessage + '.X');
  CheckNear(AExpectedY, AActual.Y, 0.000000000001, AMessage + '.Y');
  CheckNear(AExpectedZ, AActual.Z, 0.000000000001, AMessage + '.Z');
end;

procedure CheckVec4d(const AExpectedX, AExpectedY, AExpectedZ, AExpectedW: Double;
  const AActual: TVec4d; const AMessage: string);
begin
  CheckNear(AExpectedX, AActual.X, 0.000000000001, AMessage + '.X');
  CheckNear(AExpectedY, AActual.Y, 0.000000000001, AMessage + '.Y');
  CheckNear(AExpectedZ, AActual.Z, 0.000000000001, AMessage + '.Z');
  CheckNear(AExpectedW, AActual.W, 0.000000000001, AMessage + '.W');
end;

procedure CheckVec2fScalarLerpParity(const AA, AB: TVec2f; const AT: Single;
  const AMessage: string);
var
  LActual: TVec2f;
begin
  LActual := TVec2f.Lerp(AA, AB, AT);
  CheckNear(nextpas.core.math.scalar.Lerp(AA.X, AB.X, AT), LActual.X, 0.0, AMessage + '.X');
  CheckNear(nextpas.core.math.scalar.Lerp(AA.Y, AB.Y, AT), LActual.Y, 0.0, AMessage + '.Y');
end;

procedure CheckVec3fScalarLerpParity(const AA, AB: TVec3f; const AT: Single;
  const AMessage: string);
var
  LActual: TVec3f;
begin
  LActual := TVec3f.Lerp(AA, AB, AT);
  CheckNear(nextpas.core.math.scalar.Lerp(AA.X, AB.X, AT), LActual.X, 0.0, AMessage + '.X');
  CheckNear(nextpas.core.math.scalar.Lerp(AA.Y, AB.Y, AT), LActual.Y, 0.0, AMessage + '.Y');
  CheckNear(nextpas.core.math.scalar.Lerp(AA.Z, AB.Z, AT), LActual.Z, 0.0, AMessage + '.Z');
end;

procedure CheckVec4fScalarLerpParity(const AA, AB: TVec4f; const AT: Single;
  const AMessage: string);
var
  LActual: TVec4f;
begin
  LActual := TVec4f.Lerp(AA, AB, AT);
  CheckNear(nextpas.core.math.scalar.Lerp(AA.X, AB.X, AT), LActual.X, 0.0, AMessage + '.X');
  CheckNear(nextpas.core.math.scalar.Lerp(AA.Y, AB.Y, AT), LActual.Y, 0.0, AMessage + '.Y');
  CheckNear(nextpas.core.math.scalar.Lerp(AA.Z, AB.Z, AT), LActual.Z, 0.0, AMessage + '.Z');
  CheckNear(nextpas.core.math.scalar.Lerp(AA.W, AB.W, AT), LActual.W, 0.0, AMessage + '.W');
end;

procedure CheckVec2dScalarLerpParity(const AA, AB: TVec2d; const AT: Double;
  const AMessage: string);
var
  LActual: TVec2d;
begin
  LActual := TVec2d.Lerp(AA, AB, AT);
  CheckNear(nextpas.core.math.scalar.Lerp(AA.X, AB.X, AT), LActual.X, 0.0, AMessage + '.X');
  CheckNear(nextpas.core.math.scalar.Lerp(AA.Y, AB.Y, AT), LActual.Y, 0.0, AMessage + '.Y');
end;

procedure CheckVec3dScalarLerpParity(const AA, AB: TVec3d; const AT: Double;
  const AMessage: string);
var
  LActual: TVec3d;
begin
  LActual := TVec3d.Lerp(AA, AB, AT);
  CheckNear(nextpas.core.math.scalar.Lerp(AA.X, AB.X, AT), LActual.X, 0.0, AMessage + '.X');
  CheckNear(nextpas.core.math.scalar.Lerp(AA.Y, AB.Y, AT), LActual.Y, 0.0, AMessage + '.Y');
  CheckNear(nextpas.core.math.scalar.Lerp(AA.Z, AB.Z, AT), LActual.Z, 0.0, AMessage + '.Z');
end;

procedure CheckVec4dScalarLerpParity(const AA, AB: TVec4d; const AT: Double;
  const AMessage: string);
var
  LActual: TVec4d;
begin
  LActual := TVec4d.Lerp(AA, AB, AT);
  CheckNear(nextpas.core.math.scalar.Lerp(AA.X, AB.X, AT), LActual.X, 0.0, AMessage + '.X');
  CheckNear(nextpas.core.math.scalar.Lerp(AA.Y, AB.Y, AT), LActual.Y, 0.0, AMessage + '.Y');
  CheckNear(nextpas.core.math.scalar.Lerp(AA.Z, AB.Z, AT), LActual.Z, 0.0, AMessage + '.Z');
  CheckNear(nextpas.core.math.scalar.Lerp(AA.W, AB.W, AT), LActual.W, 0.0, AMessage + '.W');
end;

procedure CheckSingleBits(const AActual: Single; const AExpectedBits: LongWord;
  const AMessage: string);
var
  LValue: TSingleBitCast;
begin
  LValue.Value := AActual;
  CheckEqual(Int64(AExpectedBits), Int64(LValue.Bits), AMessage);
end;

procedure CheckDoubleBits(const AActual: Double; const AExpectedBits: QWord;
  const AMessage: string);
var
  LValue: TDoubleBitCast;
begin
  LValue.Value := AActual;
  Check(LValue.Bits = AExpectedBits, AMessage);
end;

procedure CheckSingleNaNValue(const AActual: Single; const AMessage: string);
var
  LValue: TSingleBitCast;
begin
  LValue.Value := AActual;
  Check(((LValue.Bits and $7F800000) = $7F800000) and
    ((LValue.Bits and $007FFFFF) <> 0), AMessage);
end;

procedure CheckDoubleNaNValue(const AActual: Double; const AMessage: string);
var
  LValue: TDoubleBitCast;
begin
  LValue.Value := AActual;
  Check(((LValue.Bits and $7FF0000000000000) = $7FF0000000000000) and
    ((LValue.Bits and $000FFFFFFFFFFFFF) <> 0), AMessage);
end;

procedure CheckSinglePositiveZero(const AActual: Single; const AMessage: string);
begin
  CheckSingleBits(AActual, 0, AMessage);
end;

procedure CheckDoublePositiveZero(const AActual: Double; const AMessage: string);
begin
  CheckDoubleBits(AActual, 0, AMessage);
end;

procedure CheckSingleNegativeZero(const AActual: Single; const AMessage: string);
begin
  CheckSingleBits(AActual, $80000000, AMessage);
end;

procedure CheckDoubleNegativeZero(const AActual: Double; const AMessage: string);
begin
  CheckDoubleBits(AActual, QWord(1) shl 63, AMessage);
end;

procedure CheckSinglePositiveInfinity(const AActual: Single; const AMessage: string);
begin
  CheckSingleBits(AActual, $7F800000, AMessage);
end;

procedure CheckDoublePositiveInfinity(const AActual: Double; const AMessage: string);
begin
  CheckDoubleBits(AActual, $7FF0000000000000, AMessage);
end;

procedure CheckSingleNegativeInfinity(const AActual: Single; const AMessage: string);
var
  LValue: TSingleBitCast;
begin
  LValue.Value := AActual;
  CheckEqual(Int64($FF800000), Int64(LValue.Bits), AMessage);
end;

procedure CheckSingleFinite(const AActual: Single; const AMessage: string);
var
  LValue: TSingleBitCast;
begin
  LValue.Value := AActual;
  Check((LValue.Bits and $7F800000) <> $7F800000, AMessage);
end;

procedure CheckDoubleNegativeInfinity(const AActual: Double; const AMessage: string);
var
  LValue: TDoubleBitCast;
  LExpected: QWord;
begin
  LValue.Value := AActual;
  LExpected := QWord($80000000);
  LExpected := LExpected shl 32;
  LExpected := LExpected or (QWord($7FF) shl 52);
  Check(LValue.Bits = LExpected, AMessage);
end;

procedure CheckDoubleFinite(const AActual: Double; const AMessage: string);
var
  LValue: TDoubleBitCast;
begin
  LValue.Value := AActual;
  Check((LValue.Bits and $7FF0000000000000) <> $7FF0000000000000, AMessage);
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

function SingleNaN: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := $7FC00000;
  Result := LValue.Value;
end;

function SingleInfinity: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := $7F800000;
  Result := LValue.Value;
end;

function SingleFromBits(const ABits: LongWord): Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := ABits;
  Result := LValue.Value;
end;

function SingleMaxFinite: Single;
begin
  Result := SingleFromBits($7F7FFFFF);
end;

function SingleMinPositiveSubnormal: Single;
begin
  Result := SingleFromBits($00000001);
end;

function SingleNegativeZero: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := $80000000;
  Result := LValue.Value;
end;

function SingleNegativeInfinity: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := $FF800000;
  Result := LValue.Value;
end;

function DoubleNaN: Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := $7FF8000000000000;
  Result := LValue.Value;
end;

function DoubleInfinity: Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := $7FF0000000000000;
  Result := LValue.Value;
end;

function DoubleFromBits(const ABits: QWord): Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := ABits;
  Result := LValue.Value;
end;

function DoubleMaxFinite: Double;
begin
  Result := DoubleFromBits($7FEFFFFFFFFFFFFF);
end;

function DoubleMinPositiveSubnormal: Double;
begin
  Result := DoubleFromBits(1);
end;

function DoubleNegativeZero: Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := QWord(1) shl 63;
  Result := LValue.Value;
end;

function DoubleNegativeInfinity: Double;
var
  LValue: TDoubleBitCast;
  LSignBit: QWord;
  LExponentBits: QWord;
begin
  LSignBit := 1;
  LSignBit := LSignBit shl 63;
  LExponentBits := $7FF;
  LExponentBits := LExponentBits shl 52;
  LValue.Bits := LSignBit or LExponentBits;
  Result := LValue.Value;
end;

procedure TouchVectorSinks;
begin
  if (Vec2fSink.X + Vec3fSink.X + Vec4fSink.X +
    Vec2dSink.X + Vec3dSink.X + Vec4dSink.X) = -1.0 then
    Fail('vector sink sentinel');
end;

procedure RaiseVec2fNormalizeNaN;
begin
  TVec2f.Create(SingleNaN, 1.0).Normalize;
end;

procedure RaiseVec3fNormalizeInfinity;
begin
  TVec3f.Create(1.0, SingleInfinity, 0.0).Normalize;
end;

procedure RaiseVec4fNormalizeNaN;
begin
  TVec4f.Create(1.0, 0.0, SingleNaN, 0.0).Normalize;
end;

procedure RaiseVec4fNormalizeInfinityW;
begin
  TVec4f.Create(1.0, 0.0, 0.0, SingleInfinity).Normalize;
end;

procedure RaiseVec2dNormalizeInfinity;
begin
  TVec2d.Create(DoubleInfinity, 1.0).Normalize;
end;

procedure RaiseVec3dNormalizeNaN;
begin
  TVec3d.Create(1.0, DoubleNaN, 0.0).Normalize;
end;

procedure RaiseVec4dNormalizeInfinity;
begin
  TVec4d.Create(1.0, 0.0, DoubleInfinity, 0.0).Normalize;
end;

procedure RaiseVec4dNormalizeNaNW;
begin
  TVec4d.Create(1.0, 0.0, 0.0, DoubleNaN).Normalize;
end;

procedure RaiseVec2fScalarDivideZero;
begin
  Vec2fSink := TVec2f.Create(1.0, 2.0) / Single(0.0);
end;

procedure RaiseVec2fScalarDivideNegativeZero;
begin
  Vec2fSink := TVec2f.Create(1.0, 2.0) / SingleNegativeZero;
end;

procedure RaiseVec3fScalarDivideNaN;
begin
  Vec3fSink := TVec3f.Create(1.0, 2.0, 3.0) / SingleNaN;
end;

procedure RaiseVec4fScalarDivideInfinity;
begin
  Vec4fSink := TVec4f.Create(1.0, 2.0, 3.0, 4.0) / SingleInfinity;
end;

procedure RaiseVec2dScalarDivideZero;
begin
  Vec2dSink := TVec2d.Create(1.0, 2.0) / 0.0;
end;

procedure RaiseVec3dScalarDivideNaN;
begin
  Vec3dSink := TVec3d.Create(1.0, 2.0, 3.0) / DoubleNaN;
end;

procedure RaiseVec4dScalarDivideInfinity;
begin
  Vec4dSink := TVec4d.Create(1.0, 2.0, 3.0, 4.0) / DoubleInfinity;
end;

procedure RaiseVec4dScalarDivideNegativeInfinity;
begin
  Vec4dSink := TVec4d.Create(1.0, 2.0, 3.0, 4.0) / DoubleNegativeInfinity;
end;

procedure RaiseVec2fDivComponentsZero;
begin
  Vec2fSink := TVec2f.DivComponents(TVec2f.Create(1.0, 2.0), TVec2f.Create(1.0, 0.0));
end;

procedure RaiseVec3fDivComponentsNaN;
begin
  Vec3fSink := TVec3f.DivComponents(TVec3f.Create(1.0, 2.0, 3.0),
    TVec3f.Create(1.0, SingleNaN, 1.0));
end;

procedure RaiseVec4fDivComponentsInfinity;
begin
  Vec4fSink := TVec4f.DivComponents(TVec4f.Create(1.0, 2.0, 3.0, 4.0),
    TVec4f.Create(1.0, 1.0, SingleInfinity, 1.0));
end;

procedure RaiseVec4fDivComponentsNegativeInfinity;
begin
  Vec4fSink := TVec4f.DivComponents(TVec4f.Create(1.0, 2.0, 3.0, 4.0),
    TVec4f.Create(1.0, 1.0, 1.0, SingleNegativeInfinity));
end;

procedure RaiseVec2dDivComponentsZero;
begin
  Vec2dSink := TVec2d.DivComponents(TVec2d.Create(1.0, 2.0), TVec2d.Create(0.0, 1.0));
end;

procedure RaiseVec2dDivComponentsNegativeZero;
begin
  Vec2dSink := TVec2d.DivComponents(TVec2d.Create(1.0, 2.0),
    TVec2d.Create(1.0, DoubleNegativeZero));
end;

procedure RaiseVec3dDivComponentsNaN;
begin
  Vec3dSink := TVec3d.DivComponents(TVec3d.Create(1.0, 2.0, 3.0),
    TVec3d.Create(1.0, 1.0, DoubleNaN));
end;

procedure RaiseVec4dDivComponentsInfinity;
begin
  Vec4dSink := TVec4d.DivComponents(TVec4d.Create(1.0, 2.0, 3.0, 4.0),
    TVec4d.Create(DoubleInfinity, 1.0, 1.0, 1.0));
end;

procedure TestVec2fContracts;
var
  A: TVec2f;
  B: TVec2f;
begin
  A := TVec2f.Create(3.0, 4.0);
  B := TVec2f.Create(1.0, 2.0);

  CheckEqual(Int64(SizeOf(Single) * 2), Int64(SizeOf(TVec2f)), 'TVec2f is compact value type');
  CheckNear(3.0, A.Data[0], 0.0, 'TVec2f Data[0]');
  CheckNear(4.0, A.Data[1], 0.0, 'TVec2f Data[1]');
  CheckVec2f(0.0, 0.0, TVec2f.Zero, 'TVec2f.Zero');
  CheckVec2f(4.0, 6.0, A + B, 'TVec2f add');
  CheckVec2f(2.0, 2.0, A - B, 'TVec2f subtract');
  CheckVec2f(-3.0, -4.0, -A, 'TVec2f unary minus');
  CheckVec2f(6.0, 8.0, A * Single(2.0), 'TVec2f scalar multiply right');
  CheckVec2f(6.0, 8.0, Single(2.0) * A, 'TVec2f scalar multiply left');
  CheckVec2f(1.5, 2.0, A / Single(2.0), 'TVec2f scalar divide');
  CheckVec2f(3.0, 8.0, TVec2f.MulComponents(A, B), 'TVec2f component multiply');
  CheckVec2f(3.0, 2.0, TVec2f.DivComponents(A, B), 'TVec2f component divide');
  CheckNear(11.0, TVec2f.Dot(A, B), 0.000001, 'TVec2f dot');
  CheckNear(25.0, A.LengthSqr, 0.000001, 'TVec2f length squared');
  CheckNear(5.0, A.Length, 0.000001, 'TVec2f length');
  CheckVec2f(0.6, 0.8, A.Normalize, 'TVec2f normalize');
  CheckVec2f(0.0, 0.0, TVec2f.Zero.Normalize, 'TVec2f zero normalize');
  CheckVec2f(2.0, 3.0, TVec2f.Lerp(B, A, Single(0.5)), 'TVec2f lerp');
  Check(TVec2f.Equals(A, TVec2f.Create(3.0000001, 4.0000001), Single(0.000001)),
    'TVec2f equals epsilon');
  Check(not TVec2f.Equals(A, B, Single(0.000001)), 'TVec2f not equals');
  Check(not TVec2f.Equals(A, A, Single(-0.000001)), 'TVec2f Equals rejects negative epsilon');
end;

procedure TestVec3fContracts;
var
  A: TVec3f;
  B: TVec3f;
begin
  A := TVec3f.Create(1.0, 2.0, 3.0);
  B := TVec3f.Create(4.0, 5.0, 6.0);

  CheckEqual(Int64(SizeOf(Single) * 3), Int64(SizeOf(TVec3f)), 'TVec3f is compact value type');
  CheckNear(3.0, A.Data[2], 0.0, 'TVec3f Data[2]');
  CheckVec3f(0.0, 0.0, 0.0, TVec3f.Zero, 'TVec3f.Zero');
  CheckVec3f(5.0, 7.0, 9.0, A + B, 'TVec3f add');
  CheckVec3f(-3.0, -3.0, -3.0, A - B, 'TVec3f subtract');
  CheckVec3f(-1.0, -2.0, -3.0, -A, 'TVec3f unary minus');
  CheckVec3f(2.0, 4.0, 6.0, A * Single(2.0), 'TVec3f scalar multiply right');
  CheckVec3f(2.0, 4.0, 6.0, Single(2.0) * A, 'TVec3f scalar multiply left');
  CheckVec3f(0.5, 1.0, 1.5, A / Single(2.0), 'TVec3f scalar divide');
  CheckVec3f(4.0, 10.0, 18.0, TVec3f.MulComponents(A, B), 'TVec3f component multiply');
  CheckVec3f(4.0, 2.5, 2.0, TVec3f.DivComponents(B, A), 'TVec3f component divide');
  CheckNear(32.0, TVec3f.Dot(A, B), 0.000001, 'TVec3f dot');
  CheckVec3f(0.0, 0.0, 1.0, TVec3f.Cross(TVec3f.Create(1.0, 0.0, 0.0),
    TVec3f.Create(0.0, 1.0, 0.0)), 'TVec3f cross');
  CheckNear(14.0, A.LengthSqr, 0.000001, 'TVec3f length squared');
  CheckNear(1.0, TVec3f.Create(0.0, 3.0, 4.0).Normalize.Length, 0.000001,
    'TVec3f normalized length');
  CheckVec3f(0.0, 0.0, 0.0, TVec3f.Zero.Normalize, 'TVec3f zero normalize');
  CheckVec3f(2.5, 3.5, 4.5, TVec3f.Lerp(A, B, Single(0.5)), 'TVec3f lerp');
  Check(TVec3f.Equals(A, TVec3f.Create(1.0000001, 2.0000001, 3.0000001), Single(0.000001)),
    'TVec3f equals epsilon');
  Check(not TVec3f.Equals(A, A, Single(-0.000001)), 'TVec3f Equals rejects negative epsilon');
end;

procedure TestVec3fHugeFiniteLengthAndNormalize;
var
  V: TVec3f;
  N: TVec3f;
begin
  V := TVec3f.Create(Single(3.0e20), Single(4.0e20), 0.0);
  CheckNear(5.0e20, V.Length, 5.0e14, 'TVec3f huge finite length stays finite');
  N := V.Normalize;
  CheckVec3f(0.6, 0.8, 0.0, N, 'TVec3f huge finite normalize preserves direction');
  CheckNear(1.0, N.Length, 0.000001, 'TVec3f huge finite normalize preserves unit length');
end;

procedure TestVectorMaxFiniteNormalize;
var
  N2f: TVec2f;
  N3f: TVec3f;
  N4f: TVec4f;
  N2d: TVec2d;
  N3d: TVec3d;
  N4d: TVec4d;
begin
  N2f := TVec2f.Create(SingleMaxFinite, -SingleMaxFinite).Normalize;
  CheckVec2f(0.70710677, -0.70710677, N2f,
    'TVec2f max finite normalize preserves signed direction');
  CheckNear(1.0, N2f.Length, 0.000001,
    'TVec2f max finite normalize preserves unit length');

  N3f := TVec3f.Create(SingleMaxFinite, SingleMaxFinite, 0.0).Normalize;
  CheckVec3f(0.70710677, 0.70710677, 0.0, N3f,
    'TVec3f max finite normalize preserves direction');
  CheckNear(1.0, N3f.Length, 0.000001,
    'TVec3f max finite normalize preserves unit length');

  N4f := TVec4f.Create(SingleMaxFinite, -SingleMaxFinite,
    SingleMaxFinite, -SingleMaxFinite).Normalize;
  CheckVec4f(0.5, -0.5, 0.5, -0.5, N4f,
    'TVec4f max finite normalize preserves signed direction');
  CheckNear(1.0, N4f.Length, 0.000001,
    'TVec4f max finite normalize preserves unit length');

  N2d := TVec2d.Create(DoubleMaxFinite, -DoubleMaxFinite).Normalize;
  CheckVec2d(0.7071067811865475, -0.7071067811865475, N2d,
    'TVec2d max finite normalize preserves signed direction');
  CheckNear(1.0, N2d.Length, 0.000000000001,
    'TVec2d max finite normalize preserves unit length');

  N3d := TVec3d.Create(DoubleMaxFinite, DoubleMaxFinite, 0.0).Normalize;
  CheckVec3d(0.7071067811865475, 0.7071067811865475, 0.0, N3d,
    'TVec3d max finite normalize preserves direction');
  CheckNear(1.0, N3d.Length, 0.000000000001,
    'TVec3d max finite normalize preserves unit length');

  N4d := TVec4d.Create(DoubleMaxFinite, -DoubleMaxFinite,
    DoubleMaxFinite, -DoubleMaxFinite).Normalize;
  CheckVec4d(0.5, -0.5, 0.5, -0.5, N4d,
    'TVec4d max finite normalize preserves signed direction');
  CheckNear(1.0, N4d.Length, 0.000000000001,
    'TVec4d max finite normalize preserves unit length');
end;

procedure TestVec2fHugeFiniteLengthAndNormalize;
var
  V: TVec2f;
  N: TVec2f;
begin
  V := TVec2f.Create(Single(3.0e20), Single(4.0e20));
  CheckNear(5.0e20, V.Length, 5.0e14, 'TVec2f huge finite length stays finite');
  N := V.Normalize;
  CheckVec2f(0.6, 0.8, N, 'TVec2f huge finite normalize preserves direction');
  CheckNear(1.0, N.Length, 0.000001, 'TVec2f huge finite normalize preserves unit length');
end;

procedure TestVec4fContracts;
var
  A: TVec4f;
  B: TVec4f;
begin
  A := TVec4f.Create(1.0, 2.0, 3.0, 4.0);
  B := TVec4f.Create(5.0, 6.0, 7.0, 8.0);

  CheckEqual(Int64(SizeOf(Single) * 4), Int64(SizeOf(TVec4f)), 'TVec4f is compact value type');
  CheckNear(4.0, A.Data[3], 0.0, 'TVec4f Data[3]');
  CheckVec4f(0.0, 0.0, 0.0, 0.0, TVec4f.Zero, 'TVec4f.Zero');
  CheckVec4f(6.0, 8.0, 10.0, 12.0, A + B, 'TVec4f add');
  CheckVec4f(-4.0, -4.0, -4.0, -4.0, A - B, 'TVec4f subtract');
  CheckVec4f(-1.0, -2.0, -3.0, -4.0, -A, 'TVec4f unary minus');
  CheckVec4f(2.0, 4.0, 6.0, 8.0, A * Single(2.0), 'TVec4f scalar multiply right');
  CheckVec4f(2.0, 4.0, 6.0, 8.0, Single(2.0) * A, 'TVec4f scalar multiply left');
  CheckVec4f(0.5, 1.0, 1.5, 2.0, A / Single(2.0), 'TVec4f scalar divide');
  CheckVec4f(5.0, 12.0, 21.0, 32.0, TVec4f.MulComponents(A, B), 'TVec4f component multiply');
  CheckVec4f(5.0, 3.0, 7.0 / 3.0, 2.0, TVec4f.DivComponents(B, A), 'TVec4f component divide');
  CheckNear(70.0, TVec4f.Dot(A, B), 0.000001, 'TVec4f dot');
  CheckNear(30.0, A.LengthSqr, 0.000001, 'TVec4f length squared');
  CheckNear(1.0, TVec4f.Create(0.0, 0.0, 3.0, 4.0).Normalize.Length, 0.000001,
    'TVec4f normalized length');
  CheckVec4f(0.0, 0.0, 0.0, 0.0, TVec4f.Zero.Normalize, 'TVec4f zero normalize');
  CheckVec4f(3.0, 4.0, 5.0, 6.0, TVec4f.Lerp(A, B, Single(0.5)), 'TVec4f lerp');
  Check(TVec4f.Equals(A, TVec4f.Create(1.0000001, 2.0000001, 3.0000001, 4.0000001),
    Single(0.000001)), 'TVec4f equals epsilon');
  Check(not TVec4f.Equals(A, A, Single(-0.000001)), 'TVec4f Equals rejects negative epsilon');
end;

procedure TestVec4fHugeFiniteLengthAndNormalize;
var
  V: TVec4f;
  N: TVec4f;
begin
  V := TVec4f.Create(Single(3.0e20), Single(4.0e20), 0.0, 0.0);
  CheckNear(5.0e20, V.Length, 5.0e14, 'TVec4f huge finite length stays finite');
  N := V.Normalize;
  CheckVec4f(0.6, 0.8, 0.0, 0.0, N,
    'TVec4f huge finite normalize preserves direction');
  CheckNear(1.0, N.Length, 0.000001, 'TVec4f huge finite normalize preserves unit length');
end;

procedure TestDoublePrecisionContracts;
var
  V2: TVec2d;
  V3: TVec3d;
  V4: TVec4d;
begin
  V2 := TVec2d.Create(3.0, 4.0);
  CheckEqual(Int64(SizeOf(Double) * 2), Int64(SizeOf(TVec2d)), 'TVec2d is compact value type');
  CheckVec2d(3.0, 4.0, V2, 'TVec2d.Create');
  CheckNear(3.0, V2.Data[0], 0.0, 'TVec2d Data[0]');
  CheckNear(4.0, V2.Data[1], 0.0, 'TVec2d Data[1]');
  CheckVec2d(0.0, 0.0, TVec2d.Zero, 'TVec2d.Zero');
  CheckVec2d(4.0, 6.0, V2 + TVec2d.Create(1.0, 2.0), 'TVec2d add');
  CheckVec2d(2.0, 2.0, V2 - TVec2d.Create(1.0, 2.0), 'TVec2d subtract');
  CheckVec2d(-3.0, -4.0, -V2, 'TVec2d unary minus');
  CheckVec2d(6.0, 8.0, V2 * 2.0, 'TVec2d scalar multiply right');
  CheckVec2d(6.0, 8.0, 2.0 * V2, 'TVec2d scalar multiply left');
  CheckVec2d(1.5, 2.0, V2 / 2.0, 'TVec2d scalar divide');
  CheckVec2d(3.0, 8.0, TVec2d.MulComponents(V2, TVec2d.Create(1.0, 2.0)),
    'TVec2d component multiply');
  CheckVec2d(3.0, 2.0, TVec2d.DivComponents(V2, TVec2d.Create(1.0, 2.0)),
    'TVec2d component divide');
  CheckNear(11.0, TVec2d.Dot(V2, TVec2d.Create(1.0, 2.0)), 0.000000000001, 'TVec2d dot');
  CheckNear(25.0, V2.LengthSqr, 0.000000000001, 'TVec2d length squared');
  CheckNear(5.0, V2.Length, 0.000000000001, 'TVec2d length');
  CheckVec2d(0.6, 0.8, V2.Normalize, 'TVec2d normalize');
  CheckVec2d(0.0, 0.0, TVec2d.Zero.Normalize, 'TVec2d zero normalize');
  CheckVec2d(2.0, 3.0, TVec2d.Lerp(TVec2d.Create(1.0, 2.0), V2, 0.5), 'TVec2d lerp');
  Check(TVec2d.Equals(V2, TVec2d.Create(3.0000000000001, 4.0000000000001), 0.000000000001),
    'TVec2d equals epsilon');
  Check(not TVec2d.Equals(V2, V2, -0.000000000001), 'TVec2d Equals rejects negative epsilon');

  V3 := TVec3d.Create(1.0, 2.0, 3.0);
  CheckEqual(Int64(SizeOf(Double) * 3), Int64(SizeOf(TVec3d)), 'TVec3d is compact value type');
  CheckVec3d(1.0, 2.0, 3.0, V3, 'TVec3d.Create');
  CheckNear(3.0, V3.Data[2], 0.0, 'TVec3d Data[2]');
  CheckVec3d(0.0, 0.0, 0.0, TVec3d.Zero, 'TVec3d.Zero');
  CheckVec3d(5.0, 7.0, 9.0, V3 + TVec3d.Create(4.0, 5.0, 6.0), 'TVec3d add');
  CheckVec3d(-3.0, -3.0, -3.0, V3 - TVec3d.Create(4.0, 5.0, 6.0), 'TVec3d subtract');
  CheckVec3d(-1.0, -2.0, -3.0, -V3, 'TVec3d unary minus');
  CheckVec3d(2.0, 4.0, 6.0, V3 * 2.0, 'TVec3d scalar multiply');
  CheckVec3d(2.0, 4.0, 6.0, 2.0 * V3, 'TVec3d scalar multiply left');
  CheckVec3d(0.5, 1.0, 1.5, V3 / 2.0, 'TVec3d scalar divide');
  CheckVec3d(1.0, 0.5, Double(1.0) / Double(3.0),
    TVec3d.DivComponents(TVec3d.Create(1.0, 1.0, 1.0), V3),
    'TVec3d component divide');
  CheckVec3d(4.0, 10.0, 18.0, TVec3d.MulComponents(V3, TVec3d.Create(4.0, 5.0, 6.0)),
    'TVec3d component multiply');
  CheckNear(32.0, TVec3d.Dot(V3, TVec3d.Create(4.0, 5.0, 6.0)), 0.000000000001,
    'TVec3d dot');
  CheckVec3d(0.0, 0.0, 1.0, TVec3d.Cross(TVec3d.Create(1.0, 0.0, 0.0),
    TVec3d.Create(0.0, 1.0, 0.0)), 'TVec3d cross');
  CheckNear(14.0, V3.LengthSqr, 0.000000000001, 'TVec3d length squared');
  CheckNear(3.7416573867739413, V3.Length, 0.000000000001, 'TVec3d length');
  CheckNear(1.0, TVec3d.Create(0.0, 3.0, 4.0).Normalize.Length, 0.000000000001,
    'TVec3d normalized length');
  CheckVec3d(0.0, 0.0, 0.0, TVec3d.Zero.Normalize, 'TVec3d zero normalize');
  CheckVec3d(2.5, 3.5, 4.5, TVec3d.Lerp(V3, TVec3d.Create(4.0, 5.0, 6.0), 0.5),
    'TVec3d lerp');
  Check(TVec3d.Equals(V3, TVec3d.Create(1.0000000000001, 2.0000000000001, 3.0000000000001),
    0.000000000001), 'TVec3d equals epsilon');
  Check(not TVec3d.Equals(V3, V3, -0.000000000001), 'TVec3d Equals rejects negative epsilon');

  V4 := TVec4d.Create(1.0, 2.0, 3.0, 4.0);
  CheckEqual(Int64(SizeOf(Double) * 4), Int64(SizeOf(TVec4d)), 'TVec4d is compact value type');
  CheckVec4d(1.0, 2.0, 3.0, 4.0, V4, 'TVec4d.Create');
  CheckNear(4.0, V4.Data[3], 0.0, 'TVec4d Data[3]');
  CheckVec4d(0.0, 0.0, 0.0, 0.0, TVec4d.Zero, 'TVec4d.Zero');
  CheckVec4d(6.0, 8.0, 10.0, 12.0, V4 + TVec4d.Create(5.0, 6.0, 7.0, 8.0), 'TVec4d add');
  CheckVec4d(-4.0, -4.0, -4.0, -4.0, V4 - TVec4d.Create(5.0, 6.0, 7.0, 8.0), 'TVec4d subtract');
  CheckVec4d(-1.0, -2.0, -3.0, -4.0, -V4, 'TVec4d unary minus');
  CheckVec4d(2.0, 4.0, 6.0, 8.0, V4 * 2.0, 'TVec4d scalar multiply');
  CheckVec4d(2.0, 4.0, 6.0, 8.0, 2.0 * V4, 'TVec4d scalar multiply left');
  CheckVec4d(0.5, 1.0, 1.5, 2.0, V4 / 2.0, 'TVec4d scalar divide');
  CheckVec4d(1.0, 0.5, Double(1.0) / Double(3.0), 0.25,
    TVec4d.DivComponents(TVec4d.Create(1.0, 1.0, 1.0, 1.0), V4),
    'TVec4d component divide');
  CheckVec4d(5.0, 12.0, 21.0, 32.0, TVec4d.MulComponents(V4, TVec4d.Create(5.0, 6.0, 7.0, 8.0)),
    'TVec4d component multiply');
  CheckNear(70.0, TVec4d.Dot(V4, TVec4d.Create(5.0, 6.0, 7.0, 8.0)), 0.000000000001,
    'TVec4d dot');
  CheckNear(30.0, V4.LengthSqr, 0.000000000001, 'TVec4d length squared');
  CheckNear(5.4772255750516612, V4.Length, 0.000000000001, 'TVec4d length');
  CheckNear(1.0, TVec4d.Create(0.0, 0.0, 3.0, 4.0).Normalize.Length, 0.000000000001,
    'TVec4d normalized length');
  CheckVec4d(0.0, 0.0, 0.0, 0.0, TVec4d.Zero.Normalize, 'TVec4d zero normalize');
  CheckVec4d(3.0, 4.0, 5.0, 6.0, TVec4d.Lerp(V4, TVec4d.Create(5.0, 6.0, 7.0, 8.0), 0.5),
    'TVec4d lerp');
  Check(TVec4d.Equals(V4, TVec4d.Create(1.0000000000001, 2.0000000000001, 3.0000000000001,
    4.0000000000001), 0.000000000001), 'TVec4d equals epsilon');
  Check(not TVec4d.Equals(V4, V4, -0.000000000001), 'TVec4d Equals rejects negative epsilon');
end;

procedure TestVec3dHugeFiniteLengthAndNormalize;
var
  V: TVec3d;
  N: TVec3d;
begin
  V := TVec3d.Create(3.0e200, 4.0e200, 0.0);
  CheckNear(5.0e200, V.Length, 5.0e188, 'TVec3d huge finite length stays finite');
  N := V.Normalize;
  CheckVec3d(0.6, 0.8, 0.0, N, 'TVec3d huge finite normalize preserves direction');
  CheckNear(1.0, N.Length, 0.000000000001, 'TVec3d huge finite normalize preserves unit length');
end;

procedure TestVec2dHugeFiniteLengthAndNormalize;
var
  V: TVec2d;
  N: TVec2d;
begin
  V := TVec2d.Create(3.0e200, 4.0e200);
  CheckNear(5.0e200, V.Length, 5.0e188, 'TVec2d huge finite length stays finite');
  N := V.Normalize;
  CheckVec2d(0.6, 0.8, N, 'TVec2d huge finite normalize preserves direction');
  CheckNear(1.0, N.Length, 0.000000000001, 'TVec2d huge finite normalize preserves unit length');
end;

procedure TestVec4dHugeFiniteLengthAndNormalize;
var
  V: TVec4d;
  N: TVec4d;
begin
  V := TVec4d.Create(3.0e200, 4.0e200, 0.0, 0.0);
  CheckNear(5.0e200, V.Length, 5.0e188, 'TVec4d huge finite length stays finite');
  N := V.Normalize;
  CheckVec4d(0.6, 0.8, 0.0, 0.0, N,
    'TVec4d huge finite normalize preserves direction');
  CheckNear(1.0, N.Length, 0.000000000001, 'TVec4d huge finite normalize preserves unit length');
end;

procedure TestVectorLengthSqrHugeFiniteOverflowContract;
var
  LSingleVec4Boundary: Single;
  LSingleVec4AboveBoundary: Single;
  LDoubleVec4Boundary: Double;
  LDoubleVec4AboveBoundary: Double;
begin
  LSingleVec4Boundary := SingleFromBits($5EFFFFFF);
  LSingleVec4AboveBoundary := SingleFromBits($5F000000);
  LDoubleVec4Boundary := DoubleFromBits($5FDFFFFFFFFFFFFF);
  LDoubleVec4AboveBoundary := DoubleFromBits($5FE0000000000000);

  CheckScaledNear(2.0e38, TVec2f.Create(Single(1.0e19), Single(1.0e19)).LengthSqr,
    1.0e38, 0.000001, 'TVec2f below overflow LengthSqr remains finite');
  CheckScaledNear(2.0e38, TVec3f.Create(Single(1.0e19), Single(1.0e19), 0.0).LengthSqr,
    1.0e38, 0.000001, 'TVec3f below overflow LengthSqr remains finite');
  CheckScaledNear(2.0e38, TVec4f.Create(Single(1.0e19), Single(1.0e19), 0.0, 0.0).LengthSqr,
    1.0e38, 0.000001, 'TVec4f below overflow LengthSqr remains finite');
  CheckScaledNear(1.62e308, TVec2d.Create(9.0e153, 9.0e153).LengthSqr,
    1.0e308, 0.000000000001, 'TVec2d below overflow LengthSqr remains finite');
  CheckScaledNear(1.62e308, TVec3d.Create(9.0e153, 9.0e153, 0.0).LengthSqr,
    1.0e308, 0.000000000001, 'TVec3d below overflow LengthSqr remains finite');
  CheckScaledNear(1.62e308, TVec4d.Create(9.0e153, 9.0e153, 0.0, 0.0).LengthSqr,
    1.0e308, 0.000000000001, 'TVec4d below overflow LengthSqr remains finite');
  CheckSingleBits(TVec4f.Create(LSingleVec4Boundary, LSingleVec4Boundary,
    LSingleVec4Boundary, LSingleVec4Boundary).LengthSqr,
    $7F7FFFFE,
    'TVec4f exact finite LengthSqr boundary stays finite');
  CheckDoubleBits(TVec4d.Create(LDoubleVec4Boundary, LDoubleVec4Boundary,
    LDoubleVec4Boundary, LDoubleVec4Boundary).LengthSqr,
    $7FEFFFFFFFFFFFFE,
    'TVec4d exact finite LengthSqr boundary stays finite');
  CheckSinglePositiveInfinity(TVec4f.Create(LSingleVec4AboveBoundary, LSingleVec4AboveBoundary,
    LSingleVec4AboveBoundary, LSingleVec4AboveBoundary).LengthSqr,
    'TVec4f first overflowing LengthSqr boundary saturates to +Inf');
  CheckDoublePositiveInfinity(TVec4d.Create(LDoubleVec4AboveBoundary, LDoubleVec4AboveBoundary,
    LDoubleVec4AboveBoundary, LDoubleVec4AboveBoundary).LengthSqr,
    'TVec4d first overflowing LengthSqr boundary saturates to +Inf');
  CheckSinglePositiveInfinity(TVec2f.Create(Single(3.0e20), Single(4.0e20)).LengthSqr,
    'TVec2f huge finite LengthSqr saturates to +Inf');
  CheckSinglePositiveInfinity(TVec3f.Create(Single(3.0e20), Single(4.0e20), 0.0).LengthSqr,
    'TVec3f huge finite LengthSqr saturates to +Inf');
  CheckSinglePositiveInfinity(TVec4f.Create(Single(3.0e20), Single(4.0e20), 0.0, 0.0).LengthSqr,
    'TVec4f huge finite LengthSqr saturates to +Inf');
  CheckDoublePositiveInfinity(TVec2d.Create(3.0e200, 4.0e200).LengthSqr,
    'TVec2d huge finite LengthSqr saturates to +Inf');
  CheckDoublePositiveInfinity(TVec3d.Create(3.0e200, 4.0e200, 0.0).LengthSqr,
    'TVec3d huge finite LengthSqr saturates to +Inf');
  CheckDoublePositiveInfinity(TVec4d.Create(3.0e200, 4.0e200, 0.0, 0.0).LengthSqr,
    'TVec4d huge finite LengthSqr saturates to +Inf');
end;

procedure TestVectorHugeFiniteDotContract;
begin
  CheckSinglePositiveInfinity(TVec2f.Dot(
    TVec2f.Create(Single(3.0e20), Single(4.0e20)),
    TVec2f.Create(Single(3.0e20), Single(4.0e20))),
    'TVec2f huge finite Dot positive overflow returns +Inf');
  CheckSingleNegativeInfinity(TVec3f.Dot(
    TVec3f.Create(Single(3.0e20), Single(4.0e20), 0.0),
    TVec3f.Create(Single(-3.0e20), Single(-4.0e20), 0.0)),
    'TVec3f huge finite Dot negative overflow returns -Inf');
  CheckNear(0.0, TVec4f.Dot(
    TVec4f.Create(Single(3.0e20), Single(4.0e20), Single(-3.0e20), Single(-4.0e20)),
    TVec4f.Create(Single(3.0e20), Single(4.0e20), Single(3.0e20), Single(4.0e20))),
    0.0, 'TVec4f huge finite Dot cancellation stays finite zero');

  CheckDoublePositiveInfinity(TVec2d.Dot(
    TVec2d.Create(3.0e200, 4.0e200),
    TVec2d.Create(3.0e200, 4.0e200)),
    'TVec2d huge finite Dot positive overflow returns +Inf');
  CheckDoubleNegativeInfinity(TVec3d.Dot(
    TVec3d.Create(3.0e200, 4.0e200, 0.0),
    TVec3d.Create(-3.0e200, -4.0e200, 0.0)),
    'TVec3d huge finite Dot negative overflow returns -Inf');
  CheckNear(0.0, TVec4d.Dot(
    TVec4d.Create(3.0e200, 4.0e200, -3.0e200, -4.0e200),
    TVec4d.Create(3.0e200, 4.0e200, 3.0e200, 4.0e200)),
    0.0, 'TVec4d huge finite Dot cancellation stays finite zero');
  CheckNear(0.0, TVec2d.Dot(
    TVec2d.Create(1.0e-300, -1.0e-300),
    TVec2d.Create(1.0e-300, 1.0e-300)),
    0.0, 'TVec2d tiny finite Dot underflow stays finite zero');
end;

procedure TestVectorHugeFiniteCrossCancellationContract;
var
  A3f: TVec3f;
  B3f: TVec3f;
  C3f: TVec3f;
  Expected3fY: Double;
  Expected3fZ: Double;
  A3d: TVec3d;
  B3d: TVec3d;
  C3d: TVec3d;
  Expected3dY: Double;
  Expected3dZ: Double;
begin
  A3f := TVec3f.Create(Single(2.0e19), Single(2.0e19), 0.0);
  B3f := TVec3f.Create(A3f.X, Single(2.00002e19), 0.0);
  C3f := TVec3f.Cross(A3f, B3f);
  Expected3fZ := Double(A3f.X) * (Double(B3f.Y) - Double(A3f.Y));
  CheckNear(0.0, C3f.X, 0.0, 'TVec3f huge finite Cross cancellation X');
  CheckNear(0.0, C3f.Y, 0.0, 'TVec3f huge finite Cross cancellation Y');
  CheckSingleFinite(C3f.Z, 'TVec3f huge finite Cross cancellation Z stays finite');
  CheckScaledNear(Expected3fZ, C3f.Z, Expected3fZ, 0.00001,
    'TVec3f huge finite Cross cancellation preserves finite Z');

  A3f := TVec3f.Create(Single(2.0e19), 0.0, Single(2.0e19));
  B3f := TVec3f.Create(Single(2.00002e19), 0.0, A3f.Z);
  C3f := TVec3f.Cross(A3f, B3f);
  Expected3fY := Double(A3f.Z) * (Double(B3f.X) - Double(A3f.X));
  CheckNear(0.0, C3f.X, 0.0, 'TVec3f huge finite Cross cancellation Y-axis X');
  CheckSingleFinite(C3f.Y, 'TVec3f huge finite Cross cancellation Y stays finite');
  CheckNear(0.0, C3f.Z, 0.0, 'TVec3f huge finite Cross cancellation Y-axis Z');
  CheckScaledNear(Expected3fY, C3f.Y, Expected3fY, 0.00001,
    'TVec3f huge finite Cross cancellation preserves finite Y');

  A3d := TVec3d.Create(1.5e154, 1.25e154, 0.0);
  B3d := TVec3d.Create(A3d.X, A3d.Y * (1.0 + 1.0e-15), 0.0);
  C3d := TVec3d.Cross(A3d, B3d);
  Expected3dZ := A3d.X * (B3d.Y - A3d.Y);
  CheckNear(0.0, C3d.X, 0.0, 'TVec3d huge finite Cross cancellation X');
  CheckNear(0.0, C3d.Y, 0.0, 'TVec3d huge finite Cross cancellation Y');
  CheckDoubleFinite(C3d.Z, 'TVec3d huge finite Cross cancellation Z stays finite');
  CheckScaledNear(Expected3dZ, C3d.Z, Expected3dZ, 0.000000000001,
    'TVec3d huge finite Cross cancellation preserves finite Z');

  A3d := TVec3d.Create(1.25e154, 0.0, 1.5e154);
  B3d := TVec3d.Create(A3d.X * (1.0 + 1.0e-15), 0.0, A3d.Z);
  C3d := TVec3d.Cross(A3d, B3d);
  Expected3dY := A3d.Z * (B3d.X - A3d.X);
  CheckNear(0.0, C3d.X, 0.0, 'TVec3d huge finite Cross cancellation Y-axis X');
  CheckDoubleFinite(C3d.Y, 'TVec3d huge finite Cross cancellation Y stays finite');
  CheckNear(0.0, C3d.Z, 0.0, 'TVec3d huge finite Cross cancellation Y-axis Z');
  CheckScaledNear(Expected3dY, C3d.Y, Expected3dY, 0.000000000001,
    'TVec3d huge finite Cross cancellation preserves finite Y-axis');
end;

procedure TestVectorHugeFiniteCrossOutOfRangeSignedInfinityContract;
var
  A3f: TVec3f;
  B3f: TVec3f;
  C3f: TVec3f;
  A3d: TVec3d;
  B3d: TVec3d;
  C3d: TVec3d;
begin
  A3f := TVec3f.Create(0.0, Single(3.0e20), 0.0);
  B3f := TVec3f.Create(0.0, 0.0, Single(3.0e20));
  C3f := TVec3f.Cross(A3f, B3f);
  CheckSinglePositiveInfinity(C3f.X,
    'TVec3f huge finite Cross true positive out-of-range returns +Inf');

  B3f := TVec3f.Create(0.0, 0.0, Single(-3.0e20));
  C3f := TVec3f.Cross(A3f, B3f);
  CheckSingleNegativeInfinity(C3f.X,
    'TVec3f huge finite Cross true negative out-of-range returns -Inf');

  A3d := TVec3d.Create(0.0, 3.0e200, 0.0);
  B3d := TVec3d.Create(0.0, 0.0, 3.0e200);
  C3d := TVec3d.Cross(A3d, B3d);
  CheckDoublePositiveInfinity(C3d.X,
    'TVec3d huge finite Cross true positive out-of-range returns +Inf');

  B3d := TVec3d.Create(0.0, 0.0, -3.0e200);
  C3d := TVec3d.Cross(A3d, B3d);
  CheckDoubleNegativeInfinity(C3d.X,
    'TVec3d huge finite Cross true negative out-of-range returns -Inf');

  A3f := TVec3f.Create(Single(3.0e20), 0.0, 0.0);
  B3f := TVec3f.Create(0.0, Single(-3.0e20), 0.0);
  C3f := TVec3f.Cross(A3f, B3f);
  CheckSingleNegativeInfinity(C3f.Z,
    'TVec3f huge finite Cross true negative out-of-range Z returns -Inf');

  A3d := TVec3d.Create(3.0e200, 0.0, 0.0);
  B3d := TVec3d.Create(0.0, -3.0e200, 0.0);
  C3d := TVec3d.Cross(A3d, B3d);
  CheckDoubleNegativeInfinity(C3d.Z,
    'TVec3d huge finite Cross true negative out-of-range Z returns -Inf');
end;

procedure TestVectorDataAliasesWriteThrough;
var
  V2f: TVec2f;
  V3f: TVec3f;
  V4f: TVec4f;
  V2d: TVec2d;
  V3d: TVec3d;
  V4d: TVec4d;
begin
  V2f := TVec2f.Zero;
  V2f.Data[0] := 1.25;
  V2f.Data[1] := -2.5;
  CheckVec2f(1.25, -2.5, V2f, 'TVec2f Data write-through');

  V3f := TVec3f.Zero;
  V3f.Data[0] := 1.25;
  V3f.Data[1] := -2.5;
  V3f.Data[2] := 3.75;
  CheckVec3f(1.25, -2.5, 3.75, V3f, 'TVec3f Data write-through');

  V4f := TVec4f.Zero;
  V4f.Data[0] := 1.25;
  V4f.Data[1] := -2.5;
  V4f.Data[2] := 3.75;
  V4f.Data[3] := -4.5;
  CheckVec4f(1.25, -2.5, 3.75, -4.5, V4f, 'TVec4f Data write-through');

  V2d := TVec2d.Zero;
  V2d.Data[0] := 1.25;
  V2d.Data[1] := -2.5;
  CheckVec2d(1.25, -2.5, V2d, 'TVec2d Data write-through');

  V3d := TVec3d.Zero;
  V3d.Data[0] := 1.25;
  V3d.Data[1] := -2.5;
  V3d.Data[2] := 3.75;
  CheckVec3d(1.25, -2.5, 3.75, V3d, 'TVec3d Data write-through');

  V4d := TVec4d.Zero;
  V4d.Data[0] := 1.25;
  V4d.Data[1] := -2.5;
  V4d.Data[2] := 3.75;
  V4d.Data[3] := -4.5;
  CheckVec4d(1.25, -2.5, 3.75, -4.5, V4d, 'TVec4d Data write-through');
end;

procedure TestVectorDataAliasOffsets;
var
  V2f: TVec2f;
  V3f: TVec3f;
  V4f: TVec4f;
  V2d: TVec2d;
  V3d: TVec3d;
  V4d: TVec4d;
begin
  CheckPointerOffset(@V2f, @V2f.X, 0, 'TVec2f X starts at record base');
  CheckPointerOffset(@V2f, @V2f.Y, PtrUInt(SizeOf(Single)), 'TVec2f Y packed offset');
  CheckPointerOffset(@V2f, @V2f.Data[0], 0, 'TVec2f Data[0] aliases X offset');
  CheckPointerOffset(@V2f, @V2f.Data[1], PtrUInt(SizeOf(Single)),
    'TVec2f Data[1] aliases Y offset');

  CheckPointerOffset(@V3f, @V3f.X, 0, 'TVec3f X starts at record base');
  CheckPointerOffset(@V3f, @V3f.Y, PtrUInt(SizeOf(Single)), 'TVec3f Y packed offset');
  CheckPointerOffset(@V3f, @V3f.Z, PtrUInt(2 * SizeOf(Single)), 'TVec3f Z packed offset');
  CheckPointerOffset(@V3f, @V3f.Data[0], 0, 'TVec3f Data[0] aliases X offset');
  CheckPointerOffset(@V3f, @V3f.Data[1], PtrUInt(SizeOf(Single)),
    'TVec3f Data[1] aliases Y offset');
  CheckPointerOffset(@V3f, @V3f.Data[2], PtrUInt(2 * SizeOf(Single)),
    'TVec3f Data[2] aliases Z offset');

  CheckPointerOffset(@V4f, @V4f.X, 0, 'TVec4f X starts at record base');
  CheckPointerOffset(@V4f, @V4f.Y, PtrUInt(SizeOf(Single)), 'TVec4f Y packed offset');
  CheckPointerOffset(@V4f, @V4f.Z, PtrUInt(2 * SizeOf(Single)), 'TVec4f Z packed offset');
  CheckPointerOffset(@V4f, @V4f.W, PtrUInt(3 * SizeOf(Single)), 'TVec4f W packed offset');
  CheckPointerOffset(@V4f, @V4f.Data[0], 0, 'TVec4f Data[0] aliases X offset');
  CheckPointerOffset(@V4f, @V4f.Data[1], PtrUInt(SizeOf(Single)),
    'TVec4f Data[1] aliases Y offset');
  CheckPointerOffset(@V4f, @V4f.Data[2], PtrUInt(2 * SizeOf(Single)),
    'TVec4f Data[2] aliases Z offset');
  CheckPointerOffset(@V4f, @V4f.Data[3], PtrUInt(3 * SizeOf(Single)),
    'TVec4f Data[3] aliases W offset');

  CheckPointerOffset(@V2d, @V2d.X, 0, 'TVec2d X starts at record base');
  CheckPointerOffset(@V2d, @V2d.Y, PtrUInt(SizeOf(Double)), 'TVec2d Y packed offset');
  CheckPointerOffset(@V2d, @V2d.Data[0], 0, 'TVec2d Data[0] aliases X offset');
  CheckPointerOffset(@V2d, @V2d.Data[1], PtrUInt(SizeOf(Double)),
    'TVec2d Data[1] aliases Y offset');

  CheckPointerOffset(@V3d, @V3d.X, 0, 'TVec3d X starts at record base');
  CheckPointerOffset(@V3d, @V3d.Y, PtrUInt(SizeOf(Double)), 'TVec3d Y packed offset');
  CheckPointerOffset(@V3d, @V3d.Z, PtrUInt(2 * SizeOf(Double)), 'TVec3d Z packed offset');
  CheckPointerOffset(@V3d, @V3d.Data[0], 0, 'TVec3d Data[0] aliases X offset');
  CheckPointerOffset(@V3d, @V3d.Data[1], PtrUInt(SizeOf(Double)),
    'TVec3d Data[1] aliases Y offset');
  CheckPointerOffset(@V3d, @V3d.Data[2], PtrUInt(2 * SizeOf(Double)),
    'TVec3d Data[2] aliases Z offset');

  CheckPointerOffset(@V4d, @V4d.X, 0, 'TVec4d X starts at record base');
  CheckPointerOffset(@V4d, @V4d.Y, PtrUInt(SizeOf(Double)), 'TVec4d Y packed offset');
  CheckPointerOffset(@V4d, @V4d.Z, PtrUInt(2 * SizeOf(Double)), 'TVec4d Z packed offset');
  CheckPointerOffset(@V4d, @V4d.W, PtrUInt(3 * SizeOf(Double)), 'TVec4d W packed offset');
  CheckPointerOffset(@V4d, @V4d.Data[0], 0, 'TVec4d Data[0] aliases X offset');
  CheckPointerOffset(@V4d, @V4d.Data[1], PtrUInt(SizeOf(Double)),
    'TVec4d Data[1] aliases Y offset');
  CheckPointerOffset(@V4d, @V4d.Data[2], PtrUInt(2 * SizeOf(Double)),
    'TVec4d Data[2] aliases Z offset');
  CheckPointerOffset(@V4d, @V4d.Data[3], PtrUInt(3 * SizeOf(Double)),
    'TVec4d Data offsets match packed named fields');
end;

procedure TestVectorDataAliasesPreserveSignedZeroBits;
var
  V2f: TVec2f;
  V3f: TVec3f;
  V2d: TVec2d;
  V4d: TVec4d;
begin
  V2f := TVec2f.Zero;
  V2f.Data[0] := SingleNegativeZero;
  CheckSingleNegativeZero(V2f.X, 'TVec2f Data[0] preserves negative-zero bits');

  V3f := TVec3f.Zero;
  V3f.Y := SingleNegativeZero;
  CheckSingleNegativeZero(V3f.Data[1],
    'TVec3f named field preserves negative-zero bits in Data[1]');

  V2d := TVec2d.Zero;
  V2d.X := DoubleNegativeZero;
  CheckDoubleNegativeZero(V2d.Data[0],
    'TVec2d named field preserves negative-zero bits in Data[0]');

  V4d := TVec4d.Zero;
  V4d.Data[3] := DoubleNegativeZero;
  CheckDoubleNegativeZero(V4d.W, 'TVec4d Data[3] preserves negative-zero bits');
end;

procedure TestVectorMeasureNonFiniteContracts;
var
  C3d: TVec3d;
  SavedMask: TFPUExceptionMask;
begin
  SavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow,
    exUnderflow, exPrecision]);
  try
    CheckSingleNaNValue(TVec2f.Create(SingleNaN, 1.0).Length,
      'TVec2f Length NaN component returns NaN');
    CheckSinglePositiveInfinity(TVec3f.Create(1.0, SingleInfinity, 2.0).Length,
      'TVec3f Length infinite component returns +Inf');
    CheckDoublePositiveInfinity(TVec4d.Create(1.0, DoubleInfinity, 2.0, 3.0).LengthSqr,
      'TVec4d LengthSqr infinite component returns +Inf');

    CheckSingleNaNValue(TVec2f.Dot(TVec2f.Create(0.0, 1.0),
      TVec2f.Create(SingleInfinity, 2.0)),
      'TVec2f Dot zero times infinity returns NaN');
    CheckDoublePositiveInfinity(TVec3d.Dot(TVec3d.Create(DoubleInfinity, 2.0, 0.0),
      TVec3d.Create(1.0, 3.0, 0.0)),
      'TVec3d Dot infinite component returns +Inf');

    C3d := TVec3d.Cross(TVec3d.Create(0.0, 1.0, 0.0),
      TVec3d.Create(0.0, 0.0, DoubleInfinity));
    CheckDoublePositiveInfinity(C3d.X,
      'TVec3d Cross raw non-finite fallback returns +Inf component');
    CheckDoubleNaNValue(C3d.Y,
      'TVec3d Cross raw non-finite fallback returns NaN component');
  finally
    SetExceptionMask(SavedMask);
  end;
end;

procedure TestVectorSignedZeroContracts;
var
  N2f: TVec2f;
  N4d: TVec4d;
  C3f: TVec3f;
begin
  N2f := TVec2f.Create(SingleNegativeZero, SingleNegativeZero).Normalize;
  CheckSinglePositiveZero(N2f.X, 'TVec2f negative-zero Normalize returns positive zero');
  CheckSinglePositiveZero(N2f.Y, 'TVec2f negative-zero Normalize returns positive zero Y');
  N4d := TVec4d.Create(DoubleNegativeZero, DoubleNegativeZero,
    DoubleNegativeZero, DoubleNegativeZero).Normalize;
  CheckDoublePositiveZero(N4d.X, 'TVec4d negative-zero Normalize returns positive zero X');
  CheckDoublePositiveZero(N4d.Y, 'TVec4d negative-zero Normalize returns positive zero Y');
  CheckDoublePositiveZero(N4d.Z, 'TVec4d negative-zero Normalize returns positive zero Z');
  CheckDoublePositiveZero(N4d.W, 'TVec4d negative-zero Normalize returns positive zero W');

  CheckDoublePositiveZero(TVec4d.Create(DoubleNegativeZero, 0.0, 0.0, 0.0).Length,
    'TVec4d zero Length returns +0');
  CheckSinglePositiveZero(TVec3f.Create(SingleNegativeZero, 0.0, 0.0).LengthSqr,
    'TVec3f zero LengthSqr returns +0');
  CheckDoublePositiveZero(TVec4d.Dot(TVec4d.Create(1.0, -1.0, 0.0, 0.0),
    TVec4d.Create(1.0, 1.0, 0.0, 0.0)),
    'TVec4d exact zero Dot returns +0');

  C3f := TVec3f.Cross(TVec3f.Create(1.0, 0.0, 0.0),
    TVec3f.Create(2.0, 0.0, 0.0));
  CheckSinglePositiveZero(C3f.X, 'TVec3f collinear Cross returns +0 components X');
  CheckSinglePositiveZero(C3f.Y, 'TVec3f collinear Cross returns +0 components Y');
  CheckSinglePositiveZero(C3f.Z, 'TVec3f collinear Cross returns +0 components Z');

  Check(TVec2f.Equals(TVec2f.Create(SingleNegativeZero, 0.0),
    TVec2f.Create(0.0, SingleNegativeZero), Single(0.0)),
    'TVec2f Equals treats signed zero as equal');
end;

procedure TestVectorMinSubnormalLengthAndNormalizeContracts;
var
  MinSingle: Single;
  MinDouble: Double;
  N2f: TVec2f;
  N3f: TVec3f;
  N4f: TVec4f;
  N2d: TVec2d;
  N3d: TVec3d;
  N4d: TVec4d;
  SavedMask: TFPUExceptionMask;
begin
  MinSingle := SingleMinPositiveSubnormal;
  MinDouble := DoubleMinPositiveSubnormal;
  SavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow,
    exUnderflow, exPrecision]);
  try
    CheckSingleBits(TVec2f.Create(MinSingle, 0.0).Length, $00000001,
      'TVec2f min subnormal axis Length preserves subnormal');
    CheckSingleBits(TVec3f.Create(0.0, -MinSingle, 0.0).Length, $00000001,
      'TVec3f negative min subnormal axis Length returns positive subnormal');
    CheckSingleBits(TVec4f.Create(0.0, 0.0, 0.0, MinSingle).Length, $00000001,
      'TVec4f min subnormal W axis Length preserves subnormal');

    N2f := TVec2f.Create(MinSingle, 0.0).Normalize;
    CheckVec2f(1.0, 0.0, N2f, 'TVec2f min subnormal axis Normalize returns +X');
    N3f := TVec3f.Create(0.0, -MinSingle, 0.0).Normalize;
    CheckVec3f(0.0, -1.0, 0.0, N3f,
      'TVec3f negative min subnormal axis Normalize preserves sign');
    N4f := TVec4f.Create(0.0, 0.0, 0.0, MinSingle).Normalize;
    CheckVec4f(0.0, 0.0, 0.0, 1.0, N4f,
      'TVec4f min subnormal W axis Normalize returns +W');

    CheckDoubleBits(TVec2d.Create(MinDouble, 0.0).Length, 1,
      'TVec2d min subnormal axis Length preserves subnormal');
    CheckDoubleBits(TVec3d.Create(0.0, -MinDouble, 0.0).Length, 1,
      'TVec3d negative min subnormal axis Length returns positive subnormal');
    CheckDoubleBits(TVec4d.Create(0.0, 0.0, 0.0, MinDouble).Length, 1,
      'TVec4d min subnormal W axis Length preserves subnormal');

    N2d := TVec2d.Create(MinDouble, 0.0).Normalize;
    CheckVec2d(1.0, 0.0, N2d, 'TVec2d min subnormal axis Normalize returns +X');
    N3d := TVec3d.Create(0.0, -MinDouble, 0.0).Normalize;
    CheckVec3d(0.0, -1.0, 0.0, N3d,
      'TVec3d negative min subnormal axis Normalize preserves sign');
    N4d := TVec4d.Create(0.0, 0.0, 0.0, MinDouble).Normalize;
    CheckVec4d(0.0, 0.0, 0.0, 1.0, N4d,
      'TVec4d min subnormal W axis Normalize returns +W');
  finally
    SetExceptionMask(SavedMask);
  end;
end;

procedure TestVectorLerpScalarParityContracts;
var
  A2f: TVec2f;
  B2f: TVec2f;
  A3f: TVec3f;
  B3f: TVec3f;
  A4f: TVec4f;
  B4f: TVec4f;
  A2d: TVec2d;
  B2d: TVec2d;
  A3d: TVec3d;
  B3d: TVec3d;
  A4d: TVec4d;
  B4d: TVec4d;
begin
  A2f := TVec2f.Create(Single(-2.0), Single(4.0));
  B2f := TVec2f.Create(Single(6.0), Single(-8.0));
  CheckVec2fScalarLerpParity(A2f, B2f, Single(0.0), 'TVec2f Lerp scalar parity t=0');
  CheckVec2fScalarLerpParity(A2f, B2f, Single(0.25), 'TVec2f Lerp scalar parity t=0.25');
  CheckVec2fScalarLerpParity(A2f, B2f, Single(1.0), 'TVec2f Lerp scalar parity t=1');

  A3f := TVec3f.Create(Single(1.0), Single(-3.0), Single(5.0));
  B3f := TVec3f.Create(Single(9.0), Single(7.0), Single(-1.0));
  CheckVec3fScalarLerpParity(A3f, B3f, Single(0.0), 'TVec3f Lerp scalar parity t=0');
  CheckVec3fScalarLerpParity(A3f, B3f, Single(0.5), 'TVec3f Lerp scalar parity t=0.5');
  CheckVec3fScalarLerpParity(A3f, B3f, Single(1.0), 'TVec3f Lerp scalar parity t=1');

  A4f := TVec4f.Create(Single(-4.0), Single(2.0), Single(8.0), Single(-10.0));
  B4f := TVec4f.Create(Single(12.0), Single(-6.0), Single(0.0), Single(14.0));
  CheckVec4fScalarLerpParity(A4f, B4f, Single(0.0), 'TVec4f Lerp scalar parity t=0');
  CheckVec4fScalarLerpParity(A4f, B4f, Single(0.75), 'TVec4f Lerp scalar parity t=0.75');
  CheckVec4fScalarLerpParity(A4f, B4f, Single(1.0), 'TVec4f Lerp scalar parity t=1');

  A2d := TVec2d.Create(-2.0, 4.0);
  B2d := TVec2d.Create(6.0, -8.0);
  CheckVec2dScalarLerpParity(A2d, B2d, 0.0, 'TVec2d Lerp scalar parity t=0');
  CheckVec2dScalarLerpParity(A2d, B2d, 0.25, 'TVec2d Lerp scalar parity t=0.25');
  CheckVec2dScalarLerpParity(A2d, B2d, 1.0, 'TVec2d Lerp scalar parity t=1');

  A3d := TVec3d.Create(1.0, -3.0, 5.0);
  B3d := TVec3d.Create(9.0, 7.0, -1.0);
  CheckVec3dScalarLerpParity(A3d, B3d, 0.0, 'TVec3d Lerp scalar parity t=0');
  CheckVec3dScalarLerpParity(A3d, B3d, 0.5, 'TVec3d Lerp scalar parity t=0.5');
  CheckVec3dScalarLerpParity(A3d, B3d, 1.0, 'TVec3d Lerp scalar parity t=1');

  A4d := TVec4d.Create(-4.0, 2.0, 8.0, -10.0);
  B4d := TVec4d.Create(12.0, -6.0, 0.0, 14.0);
  CheckVec4dScalarLerpParity(A4d, B4d, 0.0, 'TVec4d Lerp scalar parity t=0');
  CheckVec4dScalarLerpParity(A4d, B4d, 0.75, 'TVec4d Lerp scalar parity t=0.75');
  CheckVec4dScalarLerpParity(A4d, B4d, 1.0, 'TVec4d Lerp scalar parity t=1');
end;

procedure TestRawVectorNormalizeNonFiniteInputsFailFast;
begin
  ExpectArgumentErrorMessage('TVec2f.Normalize: vector must be finite',
    'TVec2f Normalize NaN vector', @RaiseVec2fNormalizeNaN);
  ExpectArgumentErrorMessage('TVec3f.Normalize: vector must be finite',
    'TVec3f Normalize infinite vector', @RaiseVec3fNormalizeInfinity);
  ExpectArgumentErrorMessage('TVec4f.Normalize: vector must be finite',
    'TVec4f Normalize NaN vector', @RaiseVec4fNormalizeNaN);
  ExpectArgumentErrorMessage('TVec4f.Normalize: vector must be finite',
    'TVec4f Normalize infinite W component', @RaiseVec4fNormalizeInfinityW);
  ExpectArgumentErrorMessage('TVec2d.Normalize: vector must be finite',
    'TVec2d Normalize infinite vector', @RaiseVec2dNormalizeInfinity);
  ExpectArgumentErrorMessage('TVec3d.Normalize: vector must be finite',
    'TVec3d Normalize NaN vector', @RaiseVec3dNormalizeNaN);
  ExpectArgumentErrorMessage('TVec4d.Normalize: vector must be finite',
    'TVec4d Normalize infinite vector', @RaiseVec4dNormalizeInfinity);
  ExpectArgumentErrorMessage('TVec4d.Normalize: vector must be finite',
    'TVec4d Normalize NaN W component', @RaiseVec4dNormalizeNaNW);
end;

procedure TestVectorDivisionInvalidDivisorsFailFast;
begin
  ExpectArgumentErrorMessage('TVec2f./: scalar divisor must be finite and non-zero',
    'TVec2f scalar divide zero', @RaiseVec2fScalarDivideZero);
  ExpectArgumentErrorMessage('TVec2f./: scalar divisor must be finite and non-zero',
    'TVec2f scalar divide negative zero', @RaiseVec2fScalarDivideNegativeZero);
  ExpectArgumentErrorMessage('TVec3f./: scalar divisor must be finite and non-zero',
    'TVec3f scalar divide NaN', @RaiseVec3fScalarDivideNaN);
  ExpectArgumentErrorMessage('TVec4f./: scalar divisor must be finite and non-zero',
    'TVec4f scalar divide infinity', @RaiseVec4fScalarDivideInfinity);
  ExpectArgumentErrorMessage('TVec2d./: scalar divisor must be finite and non-zero',
    'TVec2d scalar divide zero', @RaiseVec2dScalarDivideZero);
  ExpectArgumentErrorMessage('TVec3d./: scalar divisor must be finite and non-zero',
    'TVec3d scalar divide NaN', @RaiseVec3dScalarDivideNaN);
  ExpectArgumentErrorMessage('TVec4d./: scalar divisor must be finite and non-zero',
    'TVec4d scalar divide infinity', @RaiseVec4dScalarDivideInfinity);
  ExpectArgumentErrorMessage('TVec4d./: scalar divisor must be finite and non-zero',
    'TVec4d scalar divide negative infinity', @RaiseVec4dScalarDivideNegativeInfinity);

  ExpectArgumentErrorMessage('TVec2f.DivComponents: divisor vector must be finite and non-zero',
    'TVec2f component divide zero', @RaiseVec2fDivComponentsZero);
  ExpectArgumentErrorMessage('TVec3f.DivComponents: divisor vector must be finite and non-zero',
    'TVec3f component divide NaN', @RaiseVec3fDivComponentsNaN);
  ExpectArgumentErrorMessage('TVec4f.DivComponents: divisor vector must be finite and non-zero',
    'TVec4f component divide infinity', @RaiseVec4fDivComponentsInfinity);
  ExpectArgumentErrorMessage('TVec4f.DivComponents: divisor vector must be finite and non-zero',
    'TVec4f component divide negative infinity', @RaiseVec4fDivComponentsNegativeInfinity);
  ExpectArgumentErrorMessage('TVec2d.DivComponents: divisor vector must be finite and non-zero',
    'TVec2d component divide zero', @RaiseVec2dDivComponentsZero);
  ExpectArgumentErrorMessage('TVec2d.DivComponents: divisor vector must be finite and non-zero',
    'TVec2d component divide negative zero', @RaiseVec2dDivComponentsNegativeZero);
  ExpectArgumentErrorMessage('TVec3d.DivComponents: divisor vector must be finite and non-zero',
    'TVec3d component divide NaN', @RaiseVec3dDivComponentsNaN);
  ExpectArgumentErrorMessage('TVec4d.DivComponents: divisor vector must be finite and non-zero',
    'TVec4d component divide infinity', @RaiseVec4dDivComponentsInfinity);
end;

procedure TestVectorEqualsNonFiniteComparisonContracts;
begin
  Check(not TVec2f.Equals(TVec2f.Create(SingleNaN, 1.0), TVec2f.Create(SingleNaN, 1.0),
    Single(0.0)), 'TVec2f Equals rejects NaN components');
  Check(TVec2f.Equals(TVec2f.Create(SingleInfinity, 1.0), TVec2f.Create(SingleInfinity, 1.0),
    Single(0.0)), 'TVec2f Equals accepts matching positive infinity');
  Check(not TVec2f.Equals(TVec2f.Create(SingleInfinity, 1.0),
    TVec2f.Create(SingleNegativeInfinity, 1.0), Single(0.0)),
    'TVec2f Equals rejects opposite infinities');
  Check(not TVec2f.Equals(TVec2f.Create(1.0, 2.0), TVec2f.Create(1.0, 2.0),
    SingleNaN), 'TVec2f Equals rejects NaN epsilon');

  Check(not TVec3f.Equals(TVec3f.Create(1.0, SingleInfinity, 3.0),
    TVec3f.Create(1.0, 2.0, 3.0), Single(0.0)),
    'TVec3f Equals rejects finite vs infinity');
  Check(not TVec3f.Equals(TVec3f.Create(1.0, 2.0, 3.0),
    TVec3f.Create(1.0, 2.0, 3.0), SingleInfinity),
    'TVec3f Equals rejects infinite epsilon');
  Check(not TVec4f.Equals(TVec4f.Create(1.0, 2.0, 3.0, 4.0),
    TVec4f.Create(1.0, 2.0, 3.0, 4.0), SingleNegativeInfinity),
    'TVec4f Equals rejects negative infinite epsilon');

  Check(not TVec2d.Equals(TVec2d.Create(DoubleNaN, 1.0), TVec2d.Create(DoubleNaN, 1.0),
    0.0), 'TVec2d Equals rejects NaN components');
  Check(TVec2d.Equals(TVec2d.Create(DoubleNegativeInfinity, 1.0),
    TVec2d.Create(DoubleNegativeInfinity, 1.0), 0.0),
    'TVec2d Equals accepts matching negative infinity');
  Check(not TVec2d.Equals(TVec2d.Create(DoubleInfinity, 1.0),
    TVec2d.Create(DoubleNegativeInfinity, 1.0), 0.0),
    'TVec2d Equals rejects opposite infinities');
  Check(not TVec2d.Equals(TVec2d.Create(1.0, 2.0), TVec2d.Create(1.0, 2.0),
    DoubleNaN), 'TVec2d Equals rejects NaN epsilon');

  Check(not TVec3d.Equals(TVec3d.Create(1.0, DoubleInfinity, 3.0),
    TVec3d.Create(1.0, 2.0, 3.0), 0.0),
    'TVec3d Equals rejects finite vs infinity');
  Check(not TVec3d.Equals(TVec3d.Create(1.0, 2.0, 3.0),
    TVec3d.Create(1.0, 2.0, 3.0), DoubleInfinity),
    'TVec3d Equals rejects infinite epsilon');
  Check(not TVec4d.Equals(TVec4d.Create(1.0, 2.0, 3.0, 4.0),
    TVec4d.Create(1.0, 2.0, 3.0, 4.0), DoubleNegativeInfinity),
    'TVec4d Equals rejects negative infinite epsilon');
end;

begin
  T := TTestRunner.Create('nextpas.core.math.vec');
  T.Run('TVec2f contracts', @TestVec2fContracts);
  T.Run('TVec2f huge finite length + normalize', @TestVec2fHugeFiniteLengthAndNormalize);
  T.Run('TVec3f contracts', @TestVec3fContracts);
  T.Run('TVec3f huge finite length + normalize', @TestVec3fHugeFiniteLengthAndNormalize);
  T.Run('vector max finite normalize contract', @TestVectorMaxFiniteNormalize);
  T.Run('TVec4f contracts', @TestVec4fContracts);
  T.Run('TVec4f huge finite length + normalize', @TestVec4fHugeFiniteLengthAndNormalize);
  T.Run('double precision vector contracts', @TestDoublePrecisionContracts);
  T.Run('TVec2d huge finite length + normalize', @TestVec2dHugeFiniteLengthAndNormalize);
  T.Run('TVec3d huge finite length + normalize', @TestVec3dHugeFiniteLengthAndNormalize);
  T.Run('TVec4d huge finite length + normalize', @TestVec4dHugeFiniteLengthAndNormalize);
  T.Run('vector huge finite LengthSqr overflow contract',
    @TestVectorLengthSqrHugeFiniteOverflowContract);
  T.Run('vector huge finite Dot contract', @TestVectorHugeFiniteDotContract);
  T.Run('vector huge finite Cross cancellation contract',
    @TestVectorHugeFiniteCrossCancellationContract);
  T.Run('vector huge finite Cross out-of-range signed infinity contract',
    @TestVectorHugeFiniteCrossOutOfRangeSignedInfinityContract);
  T.Run('vector Data aliases write through', @TestVectorDataAliasesWriteThrough);
  T.Run('vector Data alias ABI offsets', @TestVectorDataAliasOffsets);
  T.Run('vector Data aliases preserve signed-zero bits',
    @TestVectorDataAliasesPreserveSignedZeroBits);
  T.Run('vector measure non-finite contracts',
    @TestVectorMeasureNonFiniteContracts);
  T.Run('vector signed-zero contracts',
    @TestVectorSignedZeroContracts);
  T.Run('vector min subnormal length and normalize contracts',
    @TestVectorMinSubnormalLengthAndNormalizeContracts);
  T.Run('vector Lerp scalar parity contracts',
    @TestVectorLerpScalarParityContracts);
  T.Run('raw vector normalize non-finite inputs fail fast',
    @TestRawVectorNormalizeNonFiniteInputsFailFast);
  T.Run('vector division invalid divisors fail fast',
    @TestVectorDivisionInvalidDivisorsFailFast);
  T.Run('vector Equals non-finite comparison contracts',
    @TestVectorEqualsNonFiniteComparisonContracts);
  TouchVectorSinks;
  T.Summary;
end.
