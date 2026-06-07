program test_mat;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.math.vec,
  nextpas.core.math.mat;

var
  T: TTestRunner;

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

procedure RaiseTMat4dSingularInverse;
var
  M: TMat4d;
begin
  M := TMat4d.Zero;
  M.Inverse;
end;

procedure TestMat3fContracts;
var
  M: TMat3f;
  Scale: TMat3f;
  Singular: TMat3f;
  NearSingular: TMat3f;
  PivotSwap: TMat3f;
  Inverse: TMat3f;
begin
  M := SampleMat3f;
  Scale := TMat3f.Create(
    TVec3f.Create(2.0, 0.0, 0.0),
    TVec3f.Create(0.0, 3.0, 0.0),
    TVec3f.Create(0.0, 0.0, 4.0));
  Singular := TMat3f.Create(
    TVec3f.Create(1.0, 2.0, 3.0),
    TVec3f.Create(2.0, 4.0, 6.0),
    TVec3f.Create(3.0, 6.0, 9.0));
  NearSingular := TMat3f.Create(
    TVec3f.Create(0.0000001, 0.0, 0.0),
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
  Check(not Singular.TryInverse(Inverse), 'TMat3f TryInverse rejects singular matrix');
  CheckMat3fZero(Inverse, 'TMat3f TryInverse zeroes out result for singular matrix');
  ExpectArgumentErrorMessage('TMat3f.Inverse: matrix is singular', 'TMat3f singular inverse',
    @RaiseTMat3fSingularInverse);
  CheckNear(0.0000001, NearSingular.Determinant, 0.000000000001,
    'TMat3f determinant preserves small nonzero pivot');
  Check(not NearSingular.TryInverse(Inverse), 'TMat3f TryInverse rejects near-singular matrix');
  CheckMat3fZero(Inverse, 'TMat3f TryInverse zeroes near-singular result');
  ExpectArgumentErrorMessage('TMat3f.Inverse: matrix is singular',
    'TMat3f near-singular inverse', @RaiseTMat3fNearSingularInverse);
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
  Check(not TMat4f.Zero.TryInverse(Inverse), 'TMat4f TryInverse rejects singular matrix');
  CheckMat4fZero(Inverse, 'TMat4f TryInverse zeroes out result for singular matrix');
  ExpectArgumentErrorMessage('TMat4f.Inverse: matrix is singular', 'TMat4f singular inverse',
    @RaiseTMat4fSingularInverse);
  Check(not NearSingular.TryInverse(Inverse), 'TMat4f TryInverse rejects near-singular matrix');
  CheckMat4fZero(Inverse, 'TMat4f TryInverse zeroes near-singular result');
  ExpectArgumentErrorMessage('TMat4f.Inverse: matrix is singular',
    'TMat4f near-singular inverse', @RaiseTMat4fNearSingularInverse);
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
  Check(not TMat3d.Zero.TryInverse(Inverse3), 'TMat3d TryInverse rejects singular matrix');
  CheckMat3dZero(Inverse3, 'TMat3d TryInverse zeroes out result for singular matrix');
  ExpectArgumentErrorMessage('TMat3d.Inverse: matrix is singular', 'TMat3d singular inverse',
    @RaiseTMat3dSingularInverse);
  CheckNear(0.0000000000001, NearSingular3.Determinant, 0.000000000000000001,
    'TMat3d determinant preserves small nonzero pivot');
  Check(not NearSingular3.TryInverse(Inverse3), 'TMat3d TryInverse rejects near-singular matrix');
  CheckMat3dZero(Inverse3, 'TMat3d TryInverse zeroes near-singular result');
  ExpectArgumentErrorMessage('TMat3d.Inverse: matrix is singular',
    'TMat3d near-singular inverse', @RaiseTMat3dNearSingularInverse);
  Check(not TMat3d.Equals(M3, M3, -0.000000000001), 'TMat3d equals rejects negative epsilon');

  M4 := TMat4d.Create(
    TVec4d.Create(2.0, 0.0, 0.0, 0.0),
    TVec4d.Create(0.0, 3.0, 0.0, 0.0),
    TVec4d.Create(0.0, 0.0, 4.0, 0.0),
    TVec4d.Create(5.0, 6.0, 7.0, 1.0));
  NearSingular4 := TMat4d.Create(
    TVec4d.Create(0.0000000000001, 0.0, 0.0, 0.0),
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
  M4 := TMat4d.Create(
    TVec4d.Create(2.0, 0.0, 0.0, 0.0),
    TVec4d.Create(0.0, 3.0, 0.0, 0.0),
    TVec4d.Create(0.0, 0.0, 4.0, 0.0),
    TVec4d.Create(5.0, 6.0, 7.0, 1.0));
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
  Check(not TMat4d.Zero.TryInverse(Inverse4), 'TMat4d TryInverse rejects singular matrix');
  CheckMat4dZero(Inverse4, 'TMat4d TryInverse zeroes out result for singular matrix');
  ExpectArgumentErrorMessage('TMat4d.Inverse: matrix is singular', 'TMat4d singular inverse',
    @RaiseTMat4dSingularInverse);
  Check(not NearSingular4.TryInverse(Inverse4), 'TMat4d TryInverse rejects near-singular matrix');
  CheckMat4dZero(Inverse4, 'TMat4d TryInverse zeroes near-singular result');
  ExpectArgumentErrorMessage('TMat4d.Inverse: matrix is singular',
    'TMat4d near-singular inverse', @RaiseTMat4dNearSingularInverse);
  Check(not TMat4d.Equals(M4, M4, -0.000000000001), 'TMat4d equals rejects negative epsilon');
end;

begin
  T := TTestRunner.Create('nextpas.core.math.mat');
  T.Run('TMat3f contracts', @TestMat3fContracts);
  T.Run('TMat4f contracts', @TestMat4fContracts);
  T.Run('double precision matrix contracts', @TestDoublePrecisionContracts);
  T.Summary;
end.
