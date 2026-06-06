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

procedure ExpectArgumentError(const AName: string; const AProc: TTestProc);
begin
  try
    AProc;
  except
    on E: EArgumentError do
      Exit;
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

procedure TestMat3fContracts;
var
  M: TMat3f;
  Scale: TMat3f;
  Singular: TMat3f;
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

  CheckEqual(Int64(SizeOf(Single) * 9), Int64(SizeOf(TMat3f)), 'TMat3f is compact value type');
  CheckNear(5.0, M.Data[2, 0], 0.0, 'TMat3f Data[column,row]');
  CheckNear(6.0, M[2, 1], 0.0, 'TMat3f default Items[column,row]');
  CheckVec3f(1.0, 2.0, 3.0, M.Columns[0], 'TMat3f column property');
  CheckVec3f(2.0, 1.0, 6.0, M.Rows[1], 'TMat3f row property');
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
  Check(not Singular.TryInverse(Inverse), 'TMat3f TryInverse rejects singular matrix');
  CheckMat3fZero(Inverse, 'TMat3f TryInverse zeroes out result for singular matrix');
  ExpectArgumentError('TMat3f singular inverse', @RaiseTMat3fSingularInverse);
  Check(TMat3f.Equals(M, M + TMat3f.Zero, Single(0.0)), 'TMat3f equals exact');
  Check(TMat3f.Equals(M, M * Single(1.0), Single(0.000001)), 'TMat3f equals epsilon');
  Check(TMat3f.Equals(M, Single(1.0) * M, Single(0.000001)), 'TMat3f scalar multiply left');
  Check(TMat3f.Equals(TMat3f.Zero - M, -M, Single(0.000001)), 'TMat3f unary minus and subtract');
end;

procedure TestMat4fContracts;
var
  M: TMat4f;
  Scale: TMat4f;
  Inverse: TMat4f;
begin
  M := SampleMat4f;
  Scale := TMat4f.Create(
    TVec4f.Create(2.0, 0.0, 0.0, 0.0),
    TVec4f.Create(0.0, 2.0, 0.0, 0.0),
    TVec4f.Create(0.0, 0.0, 2.0, 0.0),
    TVec4f.Create(0.0, 0.0, 0.0, 1.0));

  CheckEqual(Int64(SizeOf(Single) * 16), Int64(SizeOf(TMat4f)), 'TMat4f is compact value type');
  CheckNear(5.0, M.Data[3, 0], 0.0, 'TMat4f translation column X');
  CheckNear(7.0, M.Columns[3].Z, 0.0, 'TMat4f column property');
  CheckVec4f(0.0, 3.0, 0.0, 6.0, M.Rows[1], 'TMat4f row property');
  CheckVec4f(7.0, 12.0, 19.0, 1.0, M * TVec4f.Create(1.0, 2.0, 3.0, 1.0),
    'TMat4f matrix vector multiply');
  CheckVec4f(9.0, 18.0, 31.0, 1.0, (M * Scale) * TVec4f.Create(1.0, 2.0, 3.0, 1.0),
    'TMat4f matrix matrix multiply');
  CheckNear(7.0, M.Transpose[2, 3], 0.000001, 'TMat4f transpose');
  CheckNear(24.0, M.Determinant, 0.000001, 'TMat4f determinant');
  CheckNear(0.0000001, TMat4f.Create(
    TVec4f.Create(0.0000001, 0.0, 0.0, 0.0),
    TVec4f.Create(0.0, 1.0, 0.0, 0.0),
    TVec4f.Create(0.0, 0.0, 1.0, 0.0),
    TVec4f.Create(0.0, 0.0, 0.0, 1.0)).Determinant, 0.000000000001,
    'TMat4f determinant preserves small nonzero pivot');
  Check(M.TryInverse(Inverse), 'TMat4f TryInverse succeeds');
  CheckMat4fIdentity(M * Inverse, 'TMat4f inverse product');
  Check(not TMat4f.Zero.TryInverse(Inverse), 'TMat4f TryInverse rejects singular matrix');
  CheckMat4fZero(Inverse, 'TMat4f TryInverse zeroes out result for singular matrix');
  ExpectArgumentError('TMat4f singular inverse', @RaiseTMat4fSingularInverse);
  Check(TMat4f.Equals(M, M + TMat4f.Zero, Single(0.0)), 'TMat4f equals exact');
  Check(TMat4f.Equals(M, M * Single(1.0), Single(0.000001)), 'TMat4f scalar multiply right');
  Check(TMat4f.Equals(M, Single(1.0) * M, Single(0.000001)), 'TMat4f scalar multiply left');
  Check(TMat4f.Equals(TMat4f.Zero - M, -M, Single(0.000001)), 'TMat4f unary minus and subtract');
end;

procedure TestDoublePrecisionContracts;
var
  M3: TMat3d;
  M4: TMat4d;
  Inverse3: TMat3d;
  Inverse4: TMat4d;
begin
  M3 := TMat3d.Create(
    TVec3d.Create(1.0, 2.0, 3.0),
    TVec3d.Create(0.0, 1.0, 4.0),
    TVec3d.Create(5.0, 6.0, 0.0));
  CheckEqual(Int64(SizeOf(Double) * 9), Int64(SizeOf(TMat3d)), 'TMat3d is compact value type');
  CheckNear(5.0, M3[2, 0], 0.0, 'TMat3d default Items[column,row]');
  CheckNear(1.0, M3.Determinant, 0.000000000001, 'TMat3d determinant');
  Check(M3.TryInverse(Inverse3), 'TMat3d TryInverse succeeds');
  CheckMat3dIdentity(M3 * Inverse3, 'TMat3d inverse product');
  Check(not TMat3d.Zero.TryInverse(Inverse3), 'TMat3d TryInverse rejects singular matrix');
  CheckMat3dZero(Inverse3, 'TMat3d TryInverse zeroes out result for singular matrix');

  M4 := TMat4d.Create(
    TVec4d.Create(2.0, 0.0, 0.0, 0.0),
    TVec4d.Create(0.0, 3.0, 0.0, 0.0),
    TVec4d.Create(0.0, 0.0, 4.0, 0.0),
    TVec4d.Create(5.0, 6.0, 7.0, 1.0));
  CheckEqual(Int64(SizeOf(Double) * 16), Int64(SizeOf(TMat4d)), 'TMat4d is compact value type');
  CheckNear(24.0, M4.Determinant, 0.000000000001, 'TMat4d determinant');
  CheckNear(0.0000000000001, TMat4d.Create(
    TVec4d.Create(0.0000000000001, 0.0, 0.0, 0.0),
    TVec4d.Create(0.0, 1.0, 0.0, 0.0),
    TVec4d.Create(0.0, 0.0, 1.0, 0.0),
    TVec4d.Create(0.0, 0.0, 0.0, 1.0)).Determinant, 0.000000000000000001,
    'TMat4d determinant preserves small nonzero pivot');
  Check(M4.TryInverse(Inverse4), 'TMat4d TryInverse succeeds');
  CheckMat4dIdentity(M4 * Inverse4, 'TMat4d inverse product');
  Check(not TMat4d.Zero.TryInverse(Inverse4), 'TMat4d TryInverse rejects singular matrix');
  CheckMat4dZero(Inverse4, 'TMat4d TryInverse zeroes out result for singular matrix');
end;

begin
  T := TTestRunner.Create('nextpas.core.math.mat');
  T.Run('TMat3f contracts', @TestMat3fContracts);
  T.Run('TMat4f contracts', @TestMat4fContracts);
  T.Run('double precision matrix contracts', @TestDoublePrecisionContracts);
  T.Summary;
end.
