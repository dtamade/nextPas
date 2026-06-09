program test_mat;

{$I nextpas.core.settings.inc}

uses
  Math,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.math.vec,
  nextpas.core.math.mat;

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

procedure CheckPointerOffset(const ABase, AField: Pointer; const AExpectedOffset: PtrUInt;
  const AMessage: string);
begin
  CheckEqual(Int64(AExpectedOffset), Int64(PtrUInt(AField) - PtrUInt(ABase)), AMessage);
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

function SingleNegativeInfinity: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := $FF800000;
  Result := LValue.Value;
end;

function SingleNegativeZero: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := $80000000;
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

function DoubleNegativeInfinity: Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := QWord($FFF0000000000000);
  Result := LValue.Value;
end;

function DoubleNegativeZero: Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := QWord(1) shl 63;
  Result := LValue.Value;
end;

procedure CheckSingleNegativeZero(const AActual: Single; const AMessage: string);
var
  LValue: TSingleBitCast;
begin
  LValue.Value := AActual;
  CheckEqual(Int64($80000000), Int64(LValue.Bits), AMessage);
end;

procedure CheckDoubleNegativeZero(const AActual: Double; const AMessage: string);
var
  LValue: TDoubleBitCast;
begin
  LValue.Value := AActual;
  Check(LValue.Bits = (QWord(1) shl 63), AMessage);
end;

procedure CheckSinglePositiveZero(const AActual: Single; const AMessage: string);
var
  LValue: TSingleBitCast;
begin
  LValue.Value := AActual;
  CheckEqual(Int64(0), Int64(LValue.Bits), AMessage);
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

function DoubleMinPositiveSubnormal: Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := 1;
  Result := LValue.Value;
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

procedure CheckVec3fEqual(const AExpected, AActual: TVec3f; const AMessage: string);
begin
  CheckVec3f(AExpected.X, AExpected.Y, AExpected.Z, AActual, AMessage);
end;

procedure CheckVec4dEqual(const AExpected, AActual: TVec4d; const AMessage: string);
begin
  CheckVec4d(AExpected.X, AExpected.Y, AExpected.Z, AExpected.W, AActual, AMessage);
end;

procedure CheckMat3fIdentity(const AActual: TMat3f; const AMessage: string);
begin
  Check(TMat3f.Equals(TMat3f.Identity, AActual, Single(0.00001)), AMessage);
end;

procedure CheckMat3fZero(const AActual: TMat3f; const AMessage: string);
begin
  Check(TMat3f.Equals(TMat3f.Zero, AActual, Single(0.0)), AMessage);
end;

procedure CheckMat4fIdentity(const AActual: TMat4f; const AMessage: string);
begin
  Check(TMat4f.Equals(TMat4f.Identity, AActual, Single(0.00001)), AMessage);
end;

procedure CheckMat4fZero(const AActual: TMat4f; const AMessage: string);
begin
  Check(TMat4f.Equals(TMat4f.Zero, AActual, Single(0.0)), AMessage);
end;

procedure CheckMat3dIdentity(const AActual: TMat3d; const AMessage: string);
begin
  Check(TMat3d.Equals(TMat3d.Identity, AActual, 0.000000000001), AMessage);
end;

procedure CheckMat3dZero(const AActual: TMat3d; const AMessage: string);
begin
  Check(TMat3d.Equals(TMat3d.Zero, AActual, 0.0), AMessage);
end;

procedure CheckMat4dIdentity(const AActual: TMat4d; const AMessage: string);
begin
  Check(TMat4d.Equals(TMat4d.Identity, AActual, 0.000000000001), AMessage);
end;

procedure CheckMat4dZero(const AActual: TMat4d; const AMessage: string);
begin
  Check(TMat4d.Equals(TMat4d.Zero, AActual, 0.0), AMessage);
end;

procedure ExpectArgumentErrorMessage(const AExpectedMessage, AName: string; const AProc: TTestProc);
begin
  try
    AProc;
  except
    on E: EArgumentError do
    begin
      CheckEqual(AExpectedMessage, E.Message, AName + ': owner-level message');
      Exit;
    end;
    on E: Exception do
      Fail(AName + ': expected EArgumentError, got ' + E.ClassName);
  end;
  Fail(AName + ': expected EArgumentError');
end;

function SampleMat3f: TMat3f;
begin
  Result := TMat3f.Create(
    TVec3f.Create(1.0, 2.0, 3.0),
    TVec3f.Create(0.0, 1.0, 4.0),
    TVec3f.Create(5.0, 6.0, 0.0));
end;

function SampleMat4f: TMat4f;
begin
  Result := TMat4f.Create(
    TVec4f.Create(2.0, 0.0, 0.0, 0.0),
    TVec4f.Create(0.0, 3.0, 0.0, 0.0),
    TVec4f.Create(0.0, 0.0, 4.0, 0.0),
    TVec4f.Create(5.0, 6.0, 7.0, 1.0));
end;

function SampleMat4d: TMat4d;
begin
  Result := TMat4d.Create(
    TVec4d.Create(2.0, 0.0, 0.0, 0.0),
    TVec4d.Create(0.0, 3.0, 0.0, 0.0),
    TVec4d.Create(0.0, 0.0, 4.0, 0.0),
    TVec4d.Create(5.0, 6.0, 7.0, 1.0));
end;

function PivotSwapMat3f: TMat3f;
begin
  Result := TMat3f.Create(
    TVec3f.Create(0.0, 1.0, 0.0),
    TVec3f.Create(1.0, 0.0, 0.0),
    TVec3f.Create(0.0, 0.0, 1.0));
end;

function PivotSwapMat4f: TMat4f;
begin
  Result := TMat4f.Create(
    TVec4f.Create(0.0, 1.0, 0.0, 0.0),
    TVec4f.Create(1.0, 0.0, 0.0, 0.0),
    TVec4f.Create(0.0, 0.0, 1.0, 0.0),
    TVec4f.Create(0.0, 0.0, 0.0, 1.0));
end;

function PivotSwapMat3d: TMat3d;
begin
  Result := TMat3d.Create(
    TVec3d.Create(0.0, 1.0, 0.0),
    TVec3d.Create(1.0, 0.0, 0.0),
    TVec3d.Create(0.0, 0.0, 1.0));
end;

function PivotSwapMat4d: TMat4d;
begin
  Result := TMat4d.Create(
    TVec4d.Create(0.0, 1.0, 0.0, 0.0),
    TVec4d.Create(1.0, 0.0, 0.0, 0.0),
    TVec4d.Create(0.0, 0.0, 1.0, 0.0),
    TVec4d.Create(0.0, 0.0, 0.0, 1.0));
end;

function SentinelMat3f: TMat3f;
begin
  Result := TMat3f.Create(
    TVec3f.Create(-11.0, -12.0, -13.0),
    TVec3f.Create(-21.0, -22.0, -23.0),
    TVec3f.Create(-31.0, -32.0, -33.0));
end;

function SentinelMat4f: TMat4f;
begin
  Result := TMat4f.Create(
    TVec4f.Create(-11.0, -12.0, -13.0, -14.0),
    TVec4f.Create(-21.0, -22.0, -23.0, -24.0),
    TVec4f.Create(-31.0, -32.0, -33.0, -34.0),
    TVec4f.Create(-41.0, -42.0, -43.0, -44.0));
end;

function SentinelMat3d: TMat3d;
begin
  Result := TMat3d.Create(
    TVec3d.Create(-11.0, -12.0, -13.0),
    TVec3d.Create(-21.0, -22.0, -23.0),
    TVec3d.Create(-31.0, -32.0, -33.0));
end;

function SentinelMat4d: TMat4d;
begin
  Result := TMat4d.Create(
    TVec4d.Create(-11.0, -12.0, -13.0, -14.0),
    TVec4d.Create(-21.0, -22.0, -23.0, -24.0),
    TVec4d.Create(-31.0, -32.0, -33.0, -34.0),
    TVec4d.Create(-41.0, -42.0, -43.0, -44.0));
end;

procedure RaiseTMat3fSingularInverse;
var
  M: TMat3f;
begin
  M := TMat3f.Create(
    TVec3f.Create(1.0, 2.0, 3.0),
    TVec3f.Create(2.0, 4.0, 6.0),
    TVec3f.Create(3.0, 6.0, 9.0));
  M.Inverse;
end;

procedure RaiseTMat4fSingularInverse;
var
  M: TMat4f;
begin
  M := TMat4f.Zero;
  M.Inverse;
end;

procedure RaiseTMat3fNearSingularInverse;
var
  M: TMat3f;
begin
  M := TMat3f.Create(
    TVec3f.Create(0.0000001, 0.0, 0.0),
    TVec3f.Create(0.0, 1.0, 0.0),
    TVec3f.Create(0.0, 0.0, 1.0));
  M.Inverse;
end;

procedure RaiseTMat3fThresholdInverse;
var
  M: TMat3f;
begin
  M := TMat3f.Create(
    TVec3f.Create(0.000001, 0.0, 0.0),
    TVec3f.Create(0.0, 1.0, 0.0),
    TVec3f.Create(0.0, 0.0, 1.0));
  M.Inverse;
end;

procedure RaiseTMat4fNearSingularInverse;
var
  M: TMat4f;
begin
  M := TMat4f.Create(
    TVec4f.Create(0.0000001, 0.0, 0.0, 0.0),
    TVec4f.Create(0.0, 1.0, 0.0, 0.0),
    TVec4f.Create(0.0, 0.0, 1.0, 0.0),
    TVec4f.Create(0.0, 0.0, 0.0, 1.0));
  M.Inverse;
end;

procedure RaiseTMat4fThresholdInverse;
var
  M: TMat4f;
begin
  M := TMat4f.Create(
    TVec4f.Create(0.000001, 0.0, 0.0, 0.0),
    TVec4f.Create(0.0, 1.0, 0.0, 0.0),
    TVec4f.Create(0.0, 0.0, 1.0, 0.0),
    TVec4f.Create(0.0, 0.0, 0.0, 1.0));
  M.Inverse;
end;

procedure RaiseTMat3dNearSingularInverse;
var
  M: TMat3d;
begin
  M := TMat3d.Create(
    TVec3d.Create(0.0000000000001, 0.0, 0.0),
    TVec3d.Create(0.0, 1.0, 0.0),
    TVec3d.Create(0.0, 0.0, 1.0));
  M.Inverse;
end;

procedure RaiseTMat3dThresholdInverse;
var
  M: TMat3d;
begin
  M := TMat3d.Create(
    TVec3d.Create(0.000000000001, 0.0, 0.0),
    TVec3d.Create(0.0, 1.0, 0.0),
    TVec3d.Create(0.0, 0.0, 1.0));
  M.Inverse;
end;

procedure RaiseTMat3dSingularInverse;
var
  M: TMat3d;
begin
  M := TMat3d.Create(
    TVec3d.Create(1.0, 2.0, 3.0),
    TVec3d.Create(2.0, 4.0, 6.0),
    TVec3d.Create(3.0, 6.0, 9.0));
  M.Inverse;
end;

procedure RaiseTMat4dNearSingularInverse;
var
  M: TMat4d;
begin
  M := TMat4d.Create(
    TVec4d.Create(0.0000000000001, 0.0, 0.0, 0.0),
    TVec4d.Create(0.0, 1.0, 0.0, 0.0),
    TVec4d.Create(0.0, 0.0, 1.0, 0.0),
    TVec4d.Create(0.0, 0.0, 0.0, 1.0));
  M.Inverse;
end;

procedure RaiseTMat4dThresholdInverse;
var
  M: TMat4d;
begin
  M := TMat4d.Create(
    TVec4d.Create(0.000000000001, 0.0, 0.0, 0.0),
    TVec4d.Create(0.0, 1.0, 0.0, 0.0),
    TVec4d.Create(0.0, 0.0, 1.0, 0.0),
    TVec4d.Create(0.0, 0.0, 0.0, 1.0));
  M.Inverse;
end;

procedure RaiseTMat4dSingularInverse;
var
  M: TMat4d;
begin
  M := TMat4d.Zero;
  M.Inverse;
end;

procedure RaiseTMat3fNonFiniteInverse;
var
  M: TMat3f;
begin
  M := TMat3f.Create(
    TVec3f.Create(SingleNaN, 0.0, 0.0),
    TVec3f.Create(0.0, 1.0, 0.0),
    TVec3f.Create(0.0, 0.0, 1.0));
  M.Inverse;
end;

procedure RaiseTMat4fNonFiniteInverse;
var
  M: TMat4f;
begin
  M := TMat4f.Create(
    TVec4f.Create(SingleInfinity, 0.0, 0.0, 0.0),
    TVec4f.Create(0.0, 1.0, 0.0, 0.0),
    TVec4f.Create(0.0, 0.0, 1.0, 0.0),
    TVec4f.Create(0.0, 0.0, 0.0, 1.0));
  M.Inverse;
end;

procedure RaiseTMat3dNonFiniteInverse;
var
  M: TMat3d;
begin
  M := TMat3d.Create(
    TVec3d.Create(DoubleNaN, 0.0, 0.0),
    TVec3d.Create(0.0, 1.0, 0.0),
    TVec3d.Create(0.0, 0.0, 1.0));
  M.Inverse;
end;

procedure RaiseTMat4dNonFiniteInverse;
var
  M: TMat4d;
begin
  M := TMat4d.Create(
    TVec4d.Create(DoubleInfinity, 0.0, 0.0, 0.0),
    TVec4d.Create(0.0, 1.0, 0.0, 0.0),
    TVec4d.Create(0.0, 0.0, 1.0, 0.0),
    TVec4d.Create(0.0, 0.0, 0.0, 1.0));
  M.Inverse;
end;

procedure TestSinglePrecisionInverseFailCloseContracts;
var
  Singular3: TMat3f;
  NearSingular3: TMat3f;
  ThresholdPivot3: TMat3f;
  NaN3: TMat3f;
  Infinity3: TMat3f;
  Inverse3: TMat3f;
  NearSingular4: TMat4f;
  ThresholdPivot4: TMat4f;
  NaN4: TMat4f;
  Infinity4: TMat4f;
  Inverse4: TMat4f;
begin
  Singular3 := TMat3f.Create(
    TVec3f.Create(1.0, 2.0, 3.0),
    TVec3f.Create(2.0, 4.0, 6.0),
    TVec3f.Create(3.0, 6.0, 9.0));
  NearSingular3 := TMat3f.Create(
    TVec3f.Create(0.0000001, 0.0, 0.0),
    TVec3f.Create(0.0, 1.0, 0.0),
    TVec3f.Create(0.0, 0.0, 1.0));
  ThresholdPivot3 := TMat3f.Create(
    TVec3f.Create(0.000001, 0.0, 0.0),
    TVec3f.Create(0.0, 1.0, 0.0),
    TVec3f.Create(0.0, 0.0, 1.0));
  NaN3 := TMat3f.Create(
    TVec3f.Create(SingleNaN, 0.0, 0.0),
    TVec3f.Create(0.0, 1.0, 0.0),
    TVec3f.Create(0.0, 0.0, 1.0));
  Infinity3 := TMat3f.Create(
    TVec3f.Create(SingleInfinity, 0.0, 0.0),
    TVec3f.Create(0.0, 1.0, 0.0),
    TVec3f.Create(0.0, 0.0, 1.0));
  NearSingular4 := TMat4f.Create(
    TVec4f.Create(0.0000001, 0.0, 0.0, 0.0),
    TVec4f.Create(0.0, 1.0, 0.0, 0.0),
    TVec4f.Create(0.0, 0.0, 1.0, 0.0),
    TVec4f.Create(0.0, 0.0, 0.0, 1.0));
  ThresholdPivot4 := TMat4f.Create(
    TVec4f.Create(0.000001, 0.0, 0.0, 0.0),
    TVec4f.Create(0.0, 1.0, 0.0, 0.0),
    TVec4f.Create(0.0, 0.0, 1.0, 0.0),
    TVec4f.Create(0.0, 0.0, 0.0, 1.0));
  NaN4 := TMat4f.Create(
    TVec4f.Create(SingleNaN, 0.0, 0.0, 0.0),
    TVec4f.Create(0.0, 1.0, 0.0, 0.0),
    TVec4f.Create(0.0, 0.0, 1.0, 0.0),
    TVec4f.Create(0.0, 0.0, 0.0, 1.0));
  Infinity4 := TMat4f.Create(
    TVec4f.Create(SingleInfinity, 0.0, 0.0, 0.0),
    TVec4f.Create(0.0, 1.0, 0.0, 0.0),
    TVec4f.Create(0.0, 0.0, 1.0, 0.0),
    TVec4f.Create(0.0, 0.0, 0.0, 1.0));

  Check(not Singular3.TryInverse(Inverse3), 'TMat3f TryInverse rejects singular matrix');
  CheckMat3fZero(Inverse3, 'TMat3f TryInverse zeroes out result for singular matrix');
  ExpectArgumentErrorMessage('TMat3f.Inverse: matrix is singular', 'TMat3f singular inverse',
    @RaiseTMat3fSingularInverse);
  Check(not NearSingular3.TryInverse(Inverse3), 'TMat3f TryInverse rejects near-singular matrix');
  CheckMat3fZero(Inverse3, 'TMat3f TryInverse zeroes near-singular result');
  ExpectArgumentErrorMessage('TMat3f.Inverse: matrix is singular',
    'TMat3f near-singular inverse', @RaiseTMat3fNearSingularInverse);
  Check(not ThresholdPivot3.TryInverse(Inverse3), 'TMat3f TryInverse rejects exact epsilon pivot');
  CheckMat3fZero(Inverse3, 'TMat3f TryInverse zeroes exact epsilon pivot result');
  ExpectArgumentErrorMessage('TMat3f.Inverse: matrix is singular',
    'TMat3f exact epsilon pivot inverse', @RaiseTMat3fThresholdInverse);
  Check(not NaN3.TryInverse(Inverse3), 'TMat3f TryInverse rejects NaN matrix');
  CheckMat3fZero(Inverse3, 'TMat3f TryInverse zeroes NaN result');
  Check(not Infinity3.TryInverse(Inverse3), 'TMat3f TryInverse rejects Inf matrix');
  CheckMat3fZero(Inverse3, 'TMat3f TryInverse zeroes Inf result');
  ExpectArgumentErrorMessage('TMat3f.Inverse: matrix is singular',
    'TMat3f non-finite inverse', @RaiseTMat3fNonFiniteInverse);

  Check(not TMat4f.Zero.TryInverse(Inverse4), 'TMat4f TryInverse rejects singular matrix');
  CheckMat4fZero(Inverse4, 'TMat4f TryInverse zeroes out result for singular matrix');
  ExpectArgumentErrorMessage('TMat4f.Inverse: matrix is singular', 'TMat4f singular inverse',
    @RaiseTMat4fSingularInverse);
  Check(not NearSingular4.TryInverse(Inverse4), 'TMat4f TryInverse rejects near-singular matrix');
  CheckMat4fZero(Inverse4, 'TMat4f TryInverse zeroes near-singular result');
  ExpectArgumentErrorMessage('TMat4f.Inverse: matrix is singular',
    'TMat4f near-singular inverse', @RaiseTMat4fNearSingularInverse);
  Check(not ThresholdPivot4.TryInverse(Inverse4), 'TMat4f TryInverse rejects exact epsilon pivot');
  CheckMat4fZero(Inverse4, 'TMat4f TryInverse zeroes exact epsilon pivot result');
  ExpectArgumentErrorMessage('TMat4f.Inverse: matrix is singular',
    'TMat4f exact epsilon pivot inverse', @RaiseTMat4fThresholdInverse);
  Check(not NaN4.TryInverse(Inverse4), 'TMat4f TryInverse rejects NaN matrix');
  CheckMat4fZero(Inverse4, 'TMat4f TryInverse zeroes NaN result');
  Check(not Infinity4.TryInverse(Inverse4), 'TMat4f TryInverse rejects Inf matrix');
  CheckMat4fZero(Inverse4, 'TMat4f TryInverse zeroes Inf result');
  ExpectArgumentErrorMessage('TMat4f.Inverse: matrix is singular',
    'TMat4f non-finite inverse', @RaiseTMat4fNonFiniteInverse);
end;

procedure TestDoublePrecisionInverseFailCloseContracts;
var
  Inverse3: TMat3d;
  Inverse4: TMat4d;
  NearSingular3: TMat3d;
  ThresholdPivot3: TMat3d;
  NaN3: TMat3d;
  Infinity3: TMat3d;
  NearSingular4: TMat4d;
  ThresholdPivot4: TMat4d;
  NaN4: TMat4d;
  Infinity4: TMat4d;
begin
  NearSingular3 := TMat3d.Create(
    TVec3d.Create(0.0000000000001, 0.0, 0.0),
    TVec3d.Create(0.0, 1.0, 0.0),
    TVec3d.Create(0.0, 0.0, 1.0));
  ThresholdPivot3 := TMat3d.Create(
    TVec3d.Create(0.000000000001, 0.0, 0.0),
    TVec3d.Create(0.0, 1.0, 0.0),
    TVec3d.Create(0.0, 0.0, 1.0));
  NaN3 := TMat3d.Create(
    TVec3d.Create(DoubleNaN, 0.0, 0.0),
    TVec3d.Create(0.0, 1.0, 0.0),
    TVec3d.Create(0.0, 0.0, 1.0));
  Infinity3 := TMat3d.Create(
    TVec3d.Create(DoubleInfinity, 0.0, 0.0),
    TVec3d.Create(0.0, 1.0, 0.0),
    TVec3d.Create(0.0, 0.0, 1.0));
  NearSingular4 := TMat4d.Create(
    TVec4d.Create(0.0000000000001, 0.0, 0.0, 0.0),
    TVec4d.Create(0.0, 1.0, 0.0, 0.0),
    TVec4d.Create(0.0, 0.0, 1.0, 0.0),
    TVec4d.Create(0.0, 0.0, 0.0, 1.0));
  ThresholdPivot4 := TMat4d.Create(
    TVec4d.Create(0.000000000001, 0.0, 0.0, 0.0),
    TVec4d.Create(0.0, 1.0, 0.0, 0.0),
    TVec4d.Create(0.0, 0.0, 1.0, 0.0),
    TVec4d.Create(0.0, 0.0, 0.0, 1.0));
  NaN4 := TMat4d.Create(
    TVec4d.Create(DoubleNaN, 0.0, 0.0, 0.0),
    TVec4d.Create(0.0, 1.0, 0.0, 0.0),
    TVec4d.Create(0.0, 0.0, 1.0, 0.0),
    TVec4d.Create(0.0, 0.0, 0.0, 1.0));
  Infinity4 := TMat4d.Create(
    TVec4d.Create(DoubleInfinity, 0.0, 0.0, 0.0),
    TVec4d.Create(0.0, 1.0, 0.0, 0.0),
    TVec4d.Create(0.0, 0.0, 1.0, 0.0),
    TVec4d.Create(0.0, 0.0, 0.0, 1.0));

  Check(not TMat3d.Zero.TryInverse(Inverse3), 'TMat3d TryInverse rejects singular matrix');
  CheckMat3dZero(Inverse3, 'TMat3d TryInverse zeroes out result for singular matrix');
  ExpectArgumentErrorMessage('TMat3d.Inverse: matrix is singular', 'TMat3d singular inverse',
    @RaiseTMat3dSingularInverse);
  Check(not NearSingular3.TryInverse(Inverse3), 'TMat3d TryInverse rejects near-singular matrix');
  CheckMat3dZero(Inverse3, 'TMat3d TryInverse zeroes near-singular result');
  ExpectArgumentErrorMessage('TMat3d.Inverse: matrix is singular',
    'TMat3d near-singular inverse', @RaiseTMat3dNearSingularInverse);
  Check(not ThresholdPivot3.TryInverse(Inverse3), 'TMat3d TryInverse rejects exact epsilon pivot');
  CheckMat3dZero(Inverse3, 'TMat3d TryInverse zeroes exact epsilon pivot result');
  ExpectArgumentErrorMessage('TMat3d.Inverse: matrix is singular',
    'TMat3d exact epsilon pivot inverse', @RaiseTMat3dThresholdInverse);
  Check(not NaN3.TryInverse(Inverse3), 'TMat3d TryInverse rejects NaN matrix');
  CheckMat3dZero(Inverse3, 'TMat3d TryInverse zeroes NaN result');
  Check(not Infinity3.TryInverse(Inverse3), 'TMat3d TryInverse rejects Inf matrix');
  CheckMat3dZero(Inverse3, 'TMat3d TryInverse zeroes Inf result');
  ExpectArgumentErrorMessage('TMat3d.Inverse: matrix is singular',
    'TMat3d non-finite inverse', @RaiseTMat3dNonFiniteInverse);

  Check(not TMat4d.Zero.TryInverse(Inverse4), 'TMat4d TryInverse rejects singular matrix');
  CheckMat4dZero(Inverse4, 'TMat4d TryInverse zeroes out result for singular matrix');
  ExpectArgumentErrorMessage('TMat4d.Inverse: matrix is singular', 'TMat4d singular inverse',
    @RaiseTMat4dSingularInverse);
  Check(not NearSingular4.TryInverse(Inverse4), 'TMat4d TryInverse rejects near-singular matrix');
  CheckMat4dZero(Inverse4, 'TMat4d TryInverse zeroes near-singular result');
  ExpectArgumentErrorMessage('TMat4d.Inverse: matrix is singular',
    'TMat4d near-singular inverse', @RaiseTMat4dNearSingularInverse);
  Check(not ThresholdPivot4.TryInverse(Inverse4), 'TMat4d TryInverse rejects exact epsilon pivot');
  CheckMat4dZero(Inverse4, 'TMat4d TryInverse zeroes exact epsilon pivot result');
  ExpectArgumentErrorMessage('TMat4d.Inverse: matrix is singular',
    'TMat4d exact epsilon pivot inverse', @RaiseTMat4dThresholdInverse);
  Check(not NaN4.TryInverse(Inverse4), 'TMat4d TryInverse rejects NaN matrix');
  CheckMat4dZero(Inverse4, 'TMat4d TryInverse zeroes NaN result');
  Check(not Infinity4.TryInverse(Inverse4), 'TMat4d TryInverse rejects Inf matrix');
  CheckMat4dZero(Inverse4, 'TMat4d TryInverse zeroes Inf result');
  ExpectArgumentErrorMessage('TMat4d.Inverse: matrix is singular',
    'TMat4d non-finite inverse', @RaiseTMat4dNonFiniteInverse);
end;

procedure TestSinglePrecisionInverseOverwritesOutParameter;
var
  M3: TMat3f;
  M4: TMat4f;
  Inverse3FromSentinel: TMat3f;
  Inverse3FromIdentity: TMat3f;
  Inverse4FromSentinel: TMat4f;
  Inverse4FromIdentity: TMat4f;
begin
  M3 := SampleMat3f;
  Inverse3FromSentinel := SentinelMat3f;
  Inverse3FromIdentity := TMat3f.Identity;
  Check(M3.TryInverse(Inverse3FromSentinel), 'TMat3f TryInverse succeeds after sentinel prefill');
  Check(M3.TryInverse(Inverse3FromIdentity), 'TMat3f TryInverse succeeds after identity prefill');
  CheckMat3fIdentity(M3 * Inverse3FromSentinel, 'TMat3f TryInverse overwrites sentinel output');
  CheckMat3fIdentity(M3 * Inverse3FromIdentity, 'TMat3f TryInverse overwrites identity output');
  Check(TMat3f.Equals(Inverse3FromSentinel, Inverse3FromIdentity, Single(0.000001)),
    'TMat3f TryInverse result does not depend on previous output contents');
  Check(not TMat3f.Equals(SentinelMat3f, Inverse3FromSentinel, Single(0.0)),
    'TMat3f TryInverse replaces previous output contents');

  M4 := SampleMat4f;
  Inverse4FromSentinel := SentinelMat4f;
  Inverse4FromIdentity := TMat4f.Identity;
  Check(M4.TryInverse(Inverse4FromSentinel), 'TMat4f TryInverse succeeds after sentinel prefill');
  Check(M4.TryInverse(Inverse4FromIdentity), 'TMat4f TryInverse succeeds after identity prefill');
  CheckMat4fIdentity(M4 * Inverse4FromSentinel, 'TMat4f TryInverse overwrites sentinel output');
  CheckMat4fIdentity(M4 * Inverse4FromIdentity, 'TMat4f TryInverse overwrites identity output');
  Check(TMat4f.Equals(Inverse4FromSentinel, Inverse4FromIdentity, Single(0.000001)),
    'TMat4f TryInverse result does not depend on previous output contents');
  Check(not TMat4f.Equals(SentinelMat4f, Inverse4FromSentinel, Single(0.0)),
    'TMat4f TryInverse replaces previous output contents');
end;

procedure TestDoublePrecisionInverseOverwritesOutParameter;
var
  M3: TMat3d;
  M4: TMat4d;
  Inverse3FromSentinel: TMat3d;
  Inverse3FromIdentity: TMat3d;
  Inverse4FromSentinel: TMat4d;
  Inverse4FromIdentity: TMat4d;
begin
  M3 := TMat3d.Create(
    TVec3d.Create(1.0, 2.0, 3.0),
    TVec3d.Create(0.0, 1.0, 4.0),
    TVec3d.Create(5.0, 6.0, 0.0));
  Inverse3FromSentinel := SentinelMat3d;
  Inverse3FromIdentity := TMat3d.Identity;
  Check(M3.TryInverse(Inverse3FromSentinel), 'TMat3d TryInverse succeeds after sentinel prefill');
  Check(M3.TryInverse(Inverse3FromIdentity), 'TMat3d TryInverse succeeds after identity prefill');
  CheckMat3dIdentity(M3 * Inverse3FromSentinel, 'TMat3d TryInverse overwrites sentinel output');
  CheckMat3dIdentity(M3 * Inverse3FromIdentity, 'TMat3d TryInverse overwrites identity output');
  Check(TMat3d.Equals(Inverse3FromSentinel, Inverse3FromIdentity, 0.000000000001),
    'TMat3d TryInverse result does not depend on previous output contents');
  Check(not TMat3d.Equals(SentinelMat3d, Inverse3FromSentinel, 0.0),
    'TMat3d TryInverse replaces previous output contents');

  M4 := SampleMat4d;
  Inverse4FromSentinel := SentinelMat4d;
  Inverse4FromIdentity := TMat4d.Identity;
  Check(M4.TryInverse(Inverse4FromSentinel), 'TMat4d TryInverse succeeds after sentinel prefill');
  Check(M4.TryInverse(Inverse4FromIdentity), 'TMat4d TryInverse succeeds after identity prefill');
  CheckMat4dIdentity(M4 * Inverse4FromSentinel, 'TMat4d TryInverse overwrites sentinel output');
  CheckMat4dIdentity(M4 * Inverse4FromIdentity, 'TMat4d TryInverse overwrites identity output');
  Check(TMat4d.Equals(Inverse4FromSentinel, Inverse4FromIdentity, 0.000000000001),
    'TMat4d TryInverse result does not depend on previous output contents');
  Check(not TMat4d.Equals(SentinelMat4d, Inverse4FromSentinel, 0.0),
    'TMat4d TryInverse replaces previous output contents');
end;

procedure TestMat3fContracts;
var
  M: TMat3f;
  Scale: TMat3f;
  NearSingular: TMat3f;
  ThresholdPivot: TMat3f;
  PivotSwap: TMat3f;
  Inverse: TMat3f;
begin
  M := SampleMat3f;
  Scale := TMat3f.Create(
    TVec3f.Create(2.0, 0.0, 0.0),
    TVec3f.Create(0.0, 3.0, 0.0),
    TVec3f.Create(0.0, 0.0, 4.0));
  NearSingular := TMat3f.Create(
    TVec3f.Create(0.0000001, 0.0, 0.0),
    TVec3f.Create(0.0, 1.0, 0.0),
    TVec3f.Create(0.0, 0.0, 1.0));
  ThresholdPivot := TMat3f.Create(
    TVec3f.Create(0.000001, 0.0, 0.0),
    TVec3f.Create(0.0, 1.0, 0.0),
    TVec3f.Create(0.0, 0.0, 1.0));
  PivotSwap := PivotSwapMat3f;

  CheckEqual(Int64(SizeOf(Single) * 9), Int64(SizeOf(TMat3f)), 'TMat3f is compact value type');
  CheckNear(5.0, M.Data[2, 0], 0.0, 'TMat3f Data[column,row]');
  CheckNear(6.0, M[2, 1], 0.0, 'TMat3f default Items[column,row]');
  CheckVec3f(1.0, 2.0, 3.0, M.Columns[0], 'TMat3f column property');
  CheckVec3f(2.0, 1.0, 6.0, M.Rows[1], 'TMat3f row property');
  M := TMat3f.Zero;
  M.Rows[1] := TVec3f.Create(10.0, 20.0, 30.0);
  CheckNear(10.0, M[0, 1], 0.0, 'TMat3f row setter writes column 0');
  CheckNear(20.0, M[1, 1], 0.0, 'TMat3f row setter writes column 1');
  CheckNear(30.0, M[2, 1], 0.0, 'TMat3f row setter writes column 2');
  M.Columns[2] := TVec3f.Create(40.0, 50.0, 60.0);
  CheckVec3f(40.0, 50.0, 60.0, M.Columns[2], 'TMat3f column setter writes column view');
  CheckVec3f(10.0, 20.0, 50.0, M.Rows[1], 'TMat3f column setter updates overlapping row view');
  M := SampleMat3f;
  CheckNear(1.0, TMat3f.Identity[0, 0], 0.0, 'TMat3f identity diagonal');
  CheckNear(0.0, TMat3f.Identity[2, 1], 0.0, 'TMat3f identity off diagonal');
  CheckNear(0.0, TMat3f.Zero[1, 1], 0.0, 'TMat3f zero');
  CheckVec3f(16.0, 22.0, 11.0, M * TVec3f.Create(1.0, 2.0, 3.0), 'TMat3f matrix vector multiply');
  CheckVec3f(62.0, 82.0, 30.0, (M * Scale) * TVec3f.Create(1.0, 2.0, 3.0),
    'TMat3f matrix matrix multiply');
  CheckNear(6.0, M.Transpose[1, 2], 0.000001, 'TMat3f transpose');
  CheckNear(1.0, M.Determinant, 0.000001, 'TMat3f determinant');
  Check(M.TryInverse(Inverse), 'TMat3f TryInverse succeeds');
  CheckMat3fIdentity(M * Inverse, 'TMat3f inverse product');
  CheckNear(-1.0, PivotSwap.Determinant, 0.0, 'TMat3f pivot-swap determinant');
  Check(PivotSwap.TryInverse(Inverse), 'TMat3f TryInverse succeeds through pivot row swap');
  Check(TMat3f.Equals(PivotSwap, Inverse, Single(0.000001)),
    'TMat3f pivot-swap inverse stays on the same permutation matrix');
  CheckMat3fIdentity(PivotSwap * Inverse, 'TMat3f pivot-swap inverse product');
  CheckNear(0.0000001, NearSingular.Determinant, 0.000000000001,
    'TMat3f determinant preserves small nonzero pivot');
  CheckNear(0.000001, ThresholdPivot.Determinant, 0.000000000001,
    'TMat3f determinant preserves exact inverse epsilon pivot');
  Check(TMat3f.Equals(M, M + TMat3f.Zero, Single(0.0)), 'TMat3f equals exact');
  Check(not TMat3f.Equals(M, M, Single(-0.000001)), 'TMat3f equals rejects negative epsilon');
  Check(TMat3f.Equals(M, M * Single(1.0), Single(0.000001)), 'TMat3f equals epsilon');
  Check(TMat3f.Equals(M, Single(1.0) * M, Single(0.000001)), 'TMat3f scalar multiply left');
  Check(TMat3f.Equals(TMat3f.Zero - M, -M, Single(0.000001)), 'TMat3f unary minus and subtract');
end;

procedure TestMat4fContracts;
var
  M: TMat4f;
  Scale: TMat4f;
  NearSingular: TMat4f;
  ThresholdPivot: TMat4f;
  PivotSwap: TMat4f;
  Inverse: TMat4f;
begin
  M := SampleMat4f;
  Scale := TMat4f.Create(
    TVec4f.Create(2.0, 0.0, 0.0, 0.0),
    TVec4f.Create(0.0, 2.0, 0.0, 0.0),
    TVec4f.Create(0.0, 0.0, 2.0, 0.0),
    TVec4f.Create(0.0, 0.0, 0.0, 1.0));
  NearSingular := TMat4f.Create(
    TVec4f.Create(0.0000001, 0.0, 0.0, 0.0),
    TVec4f.Create(0.0, 1.0, 0.0, 0.0),
    TVec4f.Create(0.0, 0.0, 1.0, 0.0),
    TVec4f.Create(0.0, 0.0, 0.0, 1.0));
  ThresholdPivot := TMat4f.Create(
    TVec4f.Create(0.000001, 0.0, 0.0, 0.0),
    TVec4f.Create(0.0, 1.0, 0.0, 0.0),
    TVec4f.Create(0.0, 0.0, 1.0, 0.0),
    TVec4f.Create(0.0, 0.0, 0.0, 1.0));
  PivotSwap := PivotSwapMat4f;

  CheckEqual(Int64(SizeOf(Single) * 16), Int64(SizeOf(TMat4f)), 'TMat4f is compact value type');
  CheckNear(5.0, M.Data[3, 0], 0.0, 'TMat4f translation column X');
  CheckNear(7.0, M.Columns[3].Z, 0.0, 'TMat4f column property');
  CheckVec4f(0.0, 3.0, 0.0, 6.0, M.Rows[1], 'TMat4f row property');
  M := TMat4f.Zero;
  M.Rows[2] := TVec4f.Create(11.0, 22.0, 33.0, 44.0);
  CheckNear(11.0, M[0, 2], 0.0, 'TMat4f row setter writes column 0');
  CheckNear(22.0, M[1, 2], 0.0, 'TMat4f row setter writes column 1');
  CheckNear(33.0, M[2, 2], 0.0, 'TMat4f row setter writes column 2');
  CheckNear(44.0, M[3, 2], 0.0, 'TMat4f row setter writes column 3');
  M.Columns[1] := TVec4f.Create(12.0, 24.0, 48.0, 96.0);
  CheckVec4f(12.0, 24.0, 48.0, 96.0, M.Columns[1], 'TMat4f column setter writes column view');
  CheckVec4f(0.0, 24.0, 0.0, 0.0, M.Rows[1], 'TMat4f column setter updates row 1 overlap');
  CheckVec4f(11.0, 48.0, 33.0, 44.0, M.Rows[2], 'TMat4f column setter updates row 2 overlap');
  M := SampleMat4f;
  CheckVec4f(7.0, 12.0, 19.0, 1.0, M * TVec4f.Create(1.0, 2.0, 3.0, 1.0),
    'TMat4f matrix vector multiply');
  CheckVec4f(9.0, 18.0, 31.0, 1.0, (M * Scale) * TVec4f.Create(1.0, 2.0, 3.0, 1.0),
    'TMat4f matrix matrix multiply');
  CheckNear(7.0, M.Transpose[2, 3], 0.000001, 'TMat4f transpose');
  CheckNear(24.0, M.Determinant, 0.000001, 'TMat4f determinant');
  CheckNear(0.0000001, NearSingular.Determinant, 0.000000000001,
    'TMat4f determinant preserves small nonzero pivot');
  Check(M.TryInverse(Inverse), 'TMat4f TryInverse succeeds');
  CheckMat4fIdentity(M * Inverse, 'TMat4f inverse product');
  CheckNear(-1.0, PivotSwap.Determinant, 0.0, 'TMat4f pivot-swap determinant flips sign');
  Check(PivotSwap.TryInverse(Inverse), 'TMat4f TryInverse succeeds through pivot row swap');
  Check(TMat4f.Equals(PivotSwap, Inverse, Single(0.000001)),
    'TMat4f pivot-swap inverse stays on the same permutation matrix');
  CheckMat4fIdentity(PivotSwap * Inverse, 'TMat4f pivot-swap inverse product');
  CheckNear(0.000001, ThresholdPivot.Determinant, 0.000000000001,
    'TMat4f determinant preserves exact inverse epsilon pivot');
  Check(TMat4f.Equals(M, M + TMat4f.Zero, Single(0.0)), 'TMat4f equals exact');
  Check(not TMat4f.Equals(M, M, Single(-0.000001)), 'TMat4f equals rejects negative epsilon');
  Check(TMat4f.Equals(M, M * Single(1.0), Single(0.000001)), 'TMat4f scalar multiply right');
  Check(TMat4f.Equals(M, Single(1.0) * M, Single(0.000001)), 'TMat4f scalar multiply left');
  Check(TMat4f.Equals(TMat4f.Zero - M, -M, Single(0.000001)), 'TMat4f unary minus and subtract');
end;

procedure TestDoublePrecisionContracts;
var
  M3: TMat3d;
  M4: TMat4d;
  NearSingular3: TMat3d;
  NearSingular4: TMat4d;
  ThresholdPivot3: TMat3d;
  ThresholdPivot4: TMat4d;
  PivotSwap3: TMat3d;
  PivotSwap4: TMat4d;
  Inverse3: TMat3d;
  Inverse4: TMat4d;
begin
  M3 := TMat3d.Create(
    TVec3d.Create(1.0, 2.0, 3.0),
    TVec3d.Create(0.0, 1.0, 4.0),
    TVec3d.Create(5.0, 6.0, 0.0));
  NearSingular3 := TMat3d.Create(
    TVec3d.Create(0.0000000000001, 0.0, 0.0),
    TVec3d.Create(0.0, 1.0, 0.0),
    TVec3d.Create(0.0, 0.0, 1.0));
  ThresholdPivot3 := TMat3d.Create(
    TVec3d.Create(0.000000000001, 0.0, 0.0),
    TVec3d.Create(0.0, 1.0, 0.0),
    TVec3d.Create(0.0, 0.0, 1.0));
  PivotSwap3 := PivotSwapMat3d;
  CheckEqual(Int64(SizeOf(Double) * 9), Int64(SizeOf(TMat3d)), 'TMat3d is compact value type');
  CheckNear(5.0, M3[2, 0], 0.0, 'TMat3d default Items[column,row]');
  M3 := TMat3d.Zero;
  M3.Rows[0] := TVec3d.Create(1.5, 2.5, 3.5);
  CheckNear(1.5, M3[0, 0], 0.0, 'TMat3d row setter writes column 0');
  CheckNear(2.5, M3[1, 0], 0.0, 'TMat3d row setter writes column 1');
  CheckNear(3.5, M3[2, 0], 0.0, 'TMat3d row setter writes column 2');
  M3.Columns[1] := TVec3d.Create(4.5, 5.5, 6.5);
  CheckVec3d(4.5, 5.5, 6.5, M3.Columns[1], 'TMat3d column setter writes column view');
  CheckVec3d(1.5, 4.5, 3.5, M3.Rows[0], 'TMat3d column setter updates overlapping row view');
  M3 := TMat3d.Create(
    TVec3d.Create(1.0, 2.0, 3.0),
    TVec3d.Create(0.0, 1.0, 4.0),
    TVec3d.Create(5.0, 6.0, 0.0));
  CheckNear(1.0, M3.Determinant, 0.000000000001, 'TMat3d determinant');
  Check(M3.TryInverse(Inverse3), 'TMat3d TryInverse succeeds');
  CheckMat3dIdentity(M3 * Inverse3, 'TMat3d inverse product');
  CheckNear(-1.0, PivotSwap3.Determinant, 0.0, 'TMat3d pivot-swap determinant');
  Check(PivotSwap3.TryInverse(Inverse3), 'TMat3d TryInverse succeeds through pivot row swap');
  Check(TMat3d.Equals(PivotSwap3, Inverse3, 0.000000000001),
    'TMat3d pivot-swap inverse stays on the same permutation matrix');
  CheckMat3dIdentity(PivotSwap3 * Inverse3, 'TMat3d pivot-swap inverse product');
  CheckNear(0.0000000000001, NearSingular3.Determinant, 0.000000000000000001,
    'TMat3d determinant preserves small nonzero pivot');
  CheckNear(0.000000000001, ThresholdPivot3.Determinant, 0.000000000000000001,
    'TMat3d determinant preserves exact inverse epsilon pivot');
  Check(not TMat3d.Equals(M3, M3, -0.000000000001), 'TMat3d equals rejects negative epsilon');

  M4 := SampleMat4d;
  NearSingular4 := TMat4d.Create(
    TVec4d.Create(0.0000000000001, 0.0, 0.0, 0.0),
    TVec4d.Create(0.0, 1.0, 0.0, 0.0),
    TVec4d.Create(0.0, 0.0, 1.0, 0.0),
    TVec4d.Create(0.0, 0.0, 0.0, 1.0));
  ThresholdPivot4 := TMat4d.Create(
    TVec4d.Create(0.000000000001, 0.0, 0.0, 0.0),
    TVec4d.Create(0.0, 1.0, 0.0, 0.0),
    TVec4d.Create(0.0, 0.0, 1.0, 0.0),
    TVec4d.Create(0.0, 0.0, 0.0, 1.0));
  PivotSwap4 := PivotSwapMat4d;
  CheckEqual(Int64(SizeOf(Double) * 16), Int64(SizeOf(TMat4d)), 'TMat4d is compact value type');
  M4 := TMat4d.Zero;
  M4.Rows[3] := TVec4d.Create(7.5, 8.5, 9.5, 10.5);
  CheckNear(7.5, M4[0, 3], 0.0, 'TMat4d row setter writes column 0');
  CheckNear(8.5, M4[1, 3], 0.0, 'TMat4d row setter writes column 1');
  CheckNear(9.5, M4[2, 3], 0.0, 'TMat4d row setter writes column 2');
  CheckNear(10.5, M4[3, 3], 0.0, 'TMat4d row setter writes column 3');
  M4.Columns[0] := TVec4d.Create(11.5, 12.5, 13.5, 14.5);
  CheckVec4d(11.5, 12.5, 13.5, 14.5, M4.Columns[0], 'TMat4d column setter writes column view');
  CheckVec4d(14.5, 8.5, 9.5, 10.5, M4.Rows[3], 'TMat4d column setter updates overlapping row view');
  M4 := SampleMat4d;
  CheckNear(24.0, M4.Determinant, 0.000000000001, 'TMat4d determinant');
  CheckNear(0.0000000000001, NearSingular4.Determinant, 0.000000000000000001,
    'TMat4d determinant preserves small nonzero pivot');
  Check(M4.TryInverse(Inverse4), 'TMat4d TryInverse succeeds');
  CheckMat4dIdentity(M4 * Inverse4, 'TMat4d inverse product');
  CheckNear(-1.0, PivotSwap4.Determinant, 0.0, 'TMat4d pivot-swap determinant flips sign');
  Check(PivotSwap4.TryInverse(Inverse4), 'TMat4d TryInverse succeeds through pivot row swap');
  Check(TMat4d.Equals(PivotSwap4, Inverse4, 0.000000000001),
    'TMat4d pivot-swap inverse stays on the same permutation matrix');
  CheckMat4dIdentity(PivotSwap4 * Inverse4, 'TMat4d pivot-swap inverse product');
  CheckNear(0.000000000001, ThresholdPivot4.Determinant, 0.000000000000000001,
    'TMat4d determinant preserves exact inverse epsilon pivot');
  Check(not TMat4d.Equals(M4, M4, -0.000000000001), 'TMat4d equals rejects negative epsilon');
end;

procedure TestMatrixIndexedAliasesWriteThrough;
var
  M3f: TMat3f;
  M4f: TMat4f;
  M3d: TMat3d;
  M4d: TMat4d;
begin
  M3f := TMat3f.Zero;
  M3f[2, 1] := 12.5;
  CheckNear(12.5, M3f.Data[2, 1], 0.0, 'TMat3f Items setter writes Data alias');
  M3f.Data[0, 2] := -3.25;
  CheckNear(-3.25, M3f[0, 2], 0.0, 'TMat3f Data write visible through Items');
  CheckVec3f(0.0, 0.0, 12.5, M3f.Rows[1], 'TMat3f indexed write updates row view');
  CheckVec3f(0.0, 0.0, -3.25, M3f.Columns[0], 'TMat3f Data write updates column view');

  M4f := TMat4f.Zero;
  M4f[3, 2] := 44.25;
  CheckNear(44.25, M4f.Data[3, 2], 0.0, 'TMat4f Items setter writes Data alias');
  M4f.Data[1, 3] := -18.5;
  CheckNear(-18.5, M4f[1, 3], 0.0, 'TMat4f Data write visible through Items');
  CheckVec4f(0.0, 0.0, 0.0, 44.25, M4f.Rows[2], 'TMat4f indexed write updates row view');
  CheckVec4f(0.0, 0.0, 0.0, -18.5, M4f.Columns[1], 'TMat4f Data write updates column view');

  M3d := TMat3d.Zero;
  M3d[1, 2] := 123.125;
  CheckNear(123.125, M3d.Data[1, 2], 0.0, 'TMat3d Items setter writes Data alias');
  M3d.Data[2, 0] := -456.25;
  CheckNear(-456.25, M3d[2, 0], 0.0, 'TMat3d Data write visible through Items');
  CheckVec3d(0.0, 0.0, -456.25, M3d.Rows[0], 'TMat3d Data write updates row view');
  CheckVec3d(0.0, 0.0, 123.125, M3d.Columns[1], 'TMat3d indexed write updates column view');

  M4d := TMat4d.Zero;
  M4d[0, 3] := 1000.5;
  CheckNear(1000.5, M4d.Data[0, 3], 0.0, 'TMat4d Items setter writes Data alias');
  M4d.Data[2, 1] := -2000.75;
  CheckNear(-2000.75, M4d[2, 1], 0.0, 'TMat4d Data write visible through Items');
  CheckVec4d(1000.5, 0.0, 0.0, 0.0, M4d.Rows[3], 'TMat4d indexed write updates row view');
  CheckVec4d(0.0, -2000.75, 0.0, 0.0, M4d.Columns[2], 'TMat4d Data write updates column view');
end;

procedure TestMatrixIndexedAliasesPreserveSignedZeroBits;
var
  M3f: TMat3f;
  M4f: TMat4f;
  M3d: TMat3d;
  M4d: TMat4d;
begin
  M3f := TMat3f.Zero;
  M3f.Rows[1] := TVec3f.Create(0.0, SingleNegativeZero, 0.0);
  CheckSingleNegativeZero(M3f.Columns[1].Y,
    'TMat3f row setter preserves negative-zero bits through Columns');

  M4f := TMat4f.Zero;
  M4f.Columns[2] := TVec4f.Create(0.0, 0.0, SingleNegativeZero, 0.0);
  CheckSingleNegativeZero(M4f.Rows[2].Z,
    'TMat4f column setter preserves negative-zero bits through Rows');

  M3d := TMat3d.Zero;
  M3d[0, 2] := DoubleNegativeZero;
  CheckDoubleNegativeZero(M3d.Data[0, 2],
    'TMat3d Items setter preserves negative-zero bits through Data');

  M4d := TMat4d.Zero;
  M4d.Data[3, 1] := DoubleNegativeZero;
  CheckDoubleNegativeZero(M4d[3, 1],
    'TMat4d Data[3,1] preserves negative-zero bits through Items');
end;

procedure TestMatrixDataLayoutOffsets;
var
  M3f: TMat3f;
  M4f: TMat4f;
  M3d: TMat3d;
  M4d: TMat4d;
begin
  CheckPointerOffset(@M3f, @M3f.Data[0, 0], 0, 'TMat3f Data[0,0] starts at record base');
  CheckPointerOffset(@M3f, @M3f.Data[0, 1], PtrUInt(SizeOf(Single)),
    'TMat3f rows are contiguous inside a column');
  CheckPointerOffset(@M3f, @M3f.Data[1, 0], PtrUInt(3 * SizeOf(Single)),
    'TMat3f columns are contiguous column-major blocks');
  CheckPointerOffset(@M3f, @M3f.Data[2, 1], PtrUInt((2 * 3 + 1) * SizeOf(Single)),
    'TMat3f Data[column,row] offset is column-major');

  CheckPointerOffset(@M4f, @M4f.Data[0, 0], 0, 'TMat4f Data[0,0] starts at record base');
  CheckPointerOffset(@M4f, @M4f.Data[1, 0], PtrUInt(4 * SizeOf(Single)),
    'TMat4f columns are contiguous column-major blocks');
  CheckPointerOffset(@M4f, @M4f.Data[3, 2], PtrUInt((3 * 4 + 2) * SizeOf(Single)),
    'TMat4f Data[column,row] offset is column-major');

  CheckPointerOffset(@M3d, @M3d.Data[0, 0], 0, 'TMat3d Data[0,0] starts at record base');
  CheckPointerOffset(@M3d, @M3d.Data[1, 0], PtrUInt(3 * SizeOf(Double)),
    'TMat3d columns are contiguous column-major blocks');
  CheckPointerOffset(@M3d, @M3d.Data[2, 2], PtrUInt((2 * 3 + 2) * SizeOf(Double)),
    'TMat3d Data[column,row] offset is column-major');

  CheckPointerOffset(@M4d, @M4d.Data[0, 0], 0, 'TMat4d Data[0,0] starts at record base');
  CheckPointerOffset(@M4d, @M4d.Data[2, 1], PtrUInt((2 * 4 + 1) * SizeOf(Double)),
    'TMat4d Data[column,row] offset is column-major');
  CheckPointerOffset(@M4d, @M4d.Data[3, 3], PtrUInt((3 * 4 + 3) * SizeOf(Double)),
    'TMat4d Data[column,row] offset is column-major');
end;

procedure TestMatrixMultiplicationOrderContracts;
var
  A3f: TMat3f;
  B3f: TMat3f;
  A4d: TMat4d;
  B4d: TMat4d;
  V3f: TVec3f;
  V4d: TVec4d;
  AB3f: TMat3f;
  BA3f: TMat3f;
  AB4d: TMat4d;
  BA4d: TMat4d;
begin
  A3f := TMat3f.Create(
    TVec3f.Create(1.0, 2.0, 0.0),
    TVec3f.Create(0.0, 1.0, 3.0),
    TVec3f.Create(4.0, 0.0, 1.0));
  B3f := TMat3f.Create(
    TVec3f.Create(2.0, 0.0, 1.0),
    TVec3f.Create(1.0, 3.0, 0.0),
    TVec3f.Create(0.0, 2.0, 1.0));
  V3f := TVec3f.Create(1.0, -2.0, 3.0);
  AB3f := A3f * B3f;
  BA3f := B3f * A3f;
  CheckVec3fEqual(AB3f * V3f, A3f * (B3f * V3f),
    'TMat3f multiplication order is column-vector associative');
  Check(not TMat3f.Equals(AB3f, BA3f, Single(0.0)), 'TMat3f multiplication is non-commutative');

  A4d := TMat4d.Create(
    TVec4d.Create(1.0, 2.0, 0.0, 0.0),
    TVec4d.Create(0.0, 1.0, 3.0, 0.0),
    TVec4d.Create(4.0, 0.0, 1.0, 5.0),
    TVec4d.Create(0.0, 6.0, 0.0, 1.0));
  B4d := TMat4d.Create(
    TVec4d.Create(2.0, 0.0, 1.0, 0.0),
    TVec4d.Create(1.0, 3.0, 0.0, 2.0),
    TVec4d.Create(0.0, 2.0, 1.0, 0.0),
    TVec4d.Create(3.0, 0.0, 4.0, 1.0));
  V4d := TVec4d.Create(1.0, -2.0, 3.0, 1.0);
  AB4d := A4d * B4d;
  BA4d := B4d * A4d;
  CheckVec4dEqual(AB4d * V4d, A4d * (B4d * V4d),
    'TMat4d multiplication order is column-vector associative');
  Check(not TMat4d.Equals(AB4d, BA4d, 0.0), 'TMat4d multiplication is non-commutative');
end;

procedure TestMatrixEqualsNonFiniteComparisonContracts;
var
  M3f: TMat3f;
  M4f: TMat4f;
  M3d: TMat3d;
  M4d: TMat4d;
begin
  M3f := TMat3f.Identity;
  M3f[0, 0] := SingleNaN;
  Check(not TMat3f.Equals(M3f, M3f, Single(0.0)), 'TMat3f Equals rejects NaN elements');
  M3f[0, 0] := SingleInfinity;
  Check(TMat3f.Equals(M3f, M3f, Single(0.0)), 'TMat3f Equals accepts matching infinity');
  Check(not TMat3f.Equals(TMat3f.Identity, TMat3f.Identity, SingleNaN),
    'TMat3f Equals rejects NaN epsilon');

  M4f := TMat4f.Identity;
  M4f[1, 1] := SingleInfinity;
  Check(not TMat4f.Equals(M4f, TMat4f.Identity, Single(0.0)),
    'TMat4f Equals rejects finite vs infinity');
  M4f[1, 1] := SingleNegativeInfinity;
  Check(not TMat4f.Equals(TMat4f.Identity, TMat4f.Identity, SingleNegativeInfinity),
    'TMat4f Equals rejects negative infinite epsilon');

  M3d := TMat3d.Identity;
  M3d[0, 0] := DoubleNaN;
  Check(not TMat3d.Equals(M3d, M3d, 0.0), 'TMat3d Equals rejects NaN elements');
  M3d[0, 0] := DoubleNegativeInfinity;
  Check(TMat3d.Equals(M3d, M3d, 0.0), 'TMat3d Equals accepts matching infinity');
  Check(not TMat3d.Equals(TMat3d.Identity, TMat3d.Identity, DoubleNaN),
    'TMat3d Equals rejects NaN epsilon');

  M4d := TMat4d.Identity;
  M4d[2, 2] := DoubleInfinity;
  Check(not TMat4d.Equals(M4d, TMat4d.Identity, 0.0),
    'TMat4d Equals rejects finite vs infinity');
  M4d[2, 2] := DoubleNegativeInfinity;
  Check(not TMat4d.Equals(TMat4d.Identity, TMat4d.Identity, DoubleNegativeInfinity),
    'TMat4d Equals rejects negative infinite epsilon');
end;

procedure TestMatrixArithmeticSpecialValueContracts;
var
  M3f: TMat3f;
  M4f: TMat4f;
  M3d: TMat3d;
  M4d: TMat4d;
  Inverse3d: TMat3d;
  Product4f: TVec4f;
  Determinant3d: Double;
  SavedMask: TFPUExceptionMask;
begin
  SavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow,
    exUnderflow, exPrecision]);
  try
    M3f := TMat3f.Identity;
    M3f[0, 1] := SingleNegativeZero;
    CheckSingleNegativeZero(M3f.Transpose[1, 0],
      'TMat3f Transpose preserves negative-zero bits');

    M3f := TMat3f.Zero;
    M3f[0, 0] := SingleNegativeZero;
    M3f[1, 1] := 0.0;
    M3f := -M3f;
    CheckSinglePositiveZero(M3f[0, 0],
      'TMat3f unary minus negative zero returns positive zero');
    CheckSingleNegativeZero(M3f[1, 1],
      'TMat3f unary minus positive zero returns negative zero');

    M4d := TMat4d.Identity;
    M4d[2, 0] := DoubleInfinity;
    M4d := M4d * 0.0;
    CheckDoubleNaNValue(M4d[2, 0],
      'TMat4d scalar multiply zero times infinity returns NaN');

    M4f := TMat4f.Zero;
    Product4f := M4f * TVec4f.Create(SingleInfinity, 0.0, 0.0, 0.0);
    CheckSingleNaNValue(Product4f.X,
      'TMat4f vector multiply zero times infinity returns NaN');

    M3d := TMat3d.Create(
      TVec3d.Create(DoubleMinPositiveSubnormal, 0.0, 0.0),
      TVec3d.Create(0.0, 1.0, 0.0),
      TVec3d.Create(0.0, 0.0, 1.0));
    Determinant3d := M3d.Determinant;
    Check(Determinant3d > 0.0, 'TMat3d min-subnormal determinant is positive');

    Inverse3d := SentinelMat3d;
    Check(not M3d.TryInverse(Inverse3d),
      'TMat3d min-subnormal determinant is positive but TryInverse fail-closes');
    CheckMat3dZero(Inverse3d, 'TMat3d min-subnormal TryInverse zeroes output');
  finally
    SetExceptionMask(SavedMask);
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.math.mat');
  T.Run('TMat3f contracts', @TestMat3fContracts);
  T.Run('TMat4f contracts', @TestMat4fContracts);
  T.Run('double precision matrix contracts', @TestDoublePrecisionContracts);
  T.Run('matrix indexed aliases write through', @TestMatrixIndexedAliasesWriteThrough);
  T.Run('matrix indexed aliases preserve signed-zero bits',
    @TestMatrixIndexedAliasesPreserveSignedZeroBits);
  T.Run('matrix Data layout ABI offsets', @TestMatrixDataLayoutOffsets);
  T.Run('matrix multiplication order contracts', @TestMatrixMultiplicationOrderContracts);
  T.Run('single precision inverse fail-close contracts',
    @TestSinglePrecisionInverseFailCloseContracts);
  T.Run('double precision inverse fail-close contracts',
    @TestDoublePrecisionInverseFailCloseContracts);
  T.Run('single precision inverse overwrites out parameter',
    @TestSinglePrecisionInverseOverwritesOutParameter);
  T.Run('double precision inverse overwrites out parameter',
    @TestDoublePrecisionInverseOverwritesOutParameter);
  T.Run('matrix Equals non-finite comparison contracts',
    @TestMatrixEqualsNonFiniteComparisonContracts);
  T.Run('matrix arithmetic special-value contracts',
    @TestMatrixArithmeticSpecialValueContracts);
  T.Summary;
end.
