program test_vec;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.math.vec;

var
  T: TTestRunner;

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

begin
  T := TTestRunner.Create('nextpas.core.math.vec');
  T.Run('TVec2f contracts', @TestVec2fContracts);
  T.Run('TVec2f huge finite length + normalize', @TestVec2fHugeFiniteLengthAndNormalize);
  T.Run('TVec3f contracts', @TestVec3fContracts);
  T.Run('TVec3f huge finite length + normalize', @TestVec3fHugeFiniteLengthAndNormalize);
  T.Run('TVec4f contracts', @TestVec4fContracts);
  T.Run('TVec4f huge finite length + normalize', @TestVec4fHugeFiniteLengthAndNormalize);
  T.Run('double precision vector contracts', @TestDoublePrecisionContracts);
  T.Run('TVec2d huge finite length + normalize', @TestVec2dHugeFiniteLengthAndNormalize);
  T.Run('TVec3d huge finite length + normalize', @TestVec3dHugeFiniteLengthAndNormalize);
  T.Run('TVec4d huge finite length + normalize', @TestVec4dHugeFiniteLengthAndNormalize);
  T.Run('raw vector normalize non-finite inputs fail fast',
    @TestRawVectorNormalizeNonFiniteInputsFailFast);
  T.Summary;
end.
