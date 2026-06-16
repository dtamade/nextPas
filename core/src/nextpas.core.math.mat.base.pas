unit nextpas.core.math.mat.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.scalar,
  nextpas.core.math.vec.base,
  nextpas.core.math.impl.simd;

type
{ TMat3f - 3x3 single-precision matrix (row-major) }
  TMat3f = record
  private
    FData: array[0..2, 0..2] of Single;
    function GetElement(ARow, ACol: Integer): Single; inline;
    procedure SetElement(ARow, ACol: Integer; AValue: Single); inline;
  public
    {** Create a 3x3 matrix from 9 row-major elements }
    constructor Create(const A00, A01, A02, A10, A11, A12, A20, A21, A22: Single);
    {** Return the determinant of the matrix }
    function Determinant: Single; inline;
    {** Return the transposed matrix }
    function Transpose: TMat3f; inline;
    {** Return the inverse matrix; zero matrix if singular }
    function Inverse: TMat3f; inline;
    {** Try to compute the inverse; returns false if singular (determinant near zero) }
    function TryInverse(out AResult: TMat3f): Boolean;
    {** Element-wise linear interpolation: self + (AOther - self) * AT }
    function Lerp(const AOther: TMat3f; const AT: Single): TMat3f;
    {** Return true if all elements differ by no more than AEpsilon }
    function Equals(const AOther: TMat3f; const AEpsilon: Single): Boolean;
    {** Return true if all elements are bit-for-bit identical }
    function PerfectlyEquals(const AOther: TMat3f): Boolean;
    property Data[ARow, ACol: Integer]: Single read GetElement write SetElement; default;
  end;

{ TMat3d - 3x3 double-precision matrix (row-major) }
  TMat3d = record
  private
    FData: array[0..2, 0..2] of Double;
    function GetElement(ARow, ACol: Integer): Double; inline;
    procedure SetElement(ARow, ACol: Integer; AValue: Double); inline;
  public
    {** Create a 3x3 matrix from 9 row-major elements }
    constructor Create(const A00, A01, A02, A10, A11, A12, A20, A21, A22: Double);
    {** Return the determinant of the matrix }
    function Determinant: Double; inline;
    {** Return the transposed matrix }
    function Transpose: TMat3d; inline;
    {** Return the inverse matrix; zero matrix if singular }
    function Inverse: TMat3d; inline;
    {** Try to compute the inverse; returns false if singular (determinant near zero) }
    function TryInverse(out AResult: TMat3d): Boolean;
    {** Element-wise linear interpolation: self + (AOther - self) * AT }
    function Lerp(const AOther: TMat3d; const AT: Double): TMat3d;
    {** Return true if all elements differ by no more than AEpsilon }
    function Equals(const AOther: TMat3d; const AEpsilon: Double): Boolean;
    {** Return true if all elements are bit-for-bit identical }
    function PerfectlyEquals(const AOther: TMat3d): Boolean;
    property Data[ARow, ACol: Integer]: Double read GetElement write SetElement; default;
  end;

{ TMat4f - 4x4 single-precision matrix (row-major) }
  TMat4f = record
  private
    FData: array[0..3, 0..3] of Single;
    function GetElement(ARow, ACol: Integer): Single; inline;
    procedure SetElement(ARow, ACol: Integer; AValue: Single); inline;
  public
    {** Create a 4x4 matrix from 16 row-major elements }
    constructor Create(const A00, A01, A02, A03, A10, A11, A12, A13, A20, A21, A22, A23, A30, A31, A32, A33: Single);
    {** Return the determinant of the matrix }
    function Determinant: Single; inline;
    {** Return the transposed matrix }
    function Transpose: TMat4f; inline;
    {** Return the inverse matrix; zero matrix if singular }
    function Inverse: TMat4f; inline;
    {** Try to compute the inverse; returns false if singular (determinant near zero) }
    function TryInverse(out AResult: TMat4f): Boolean;
    {** Transform a 3D point (w=1), applying full matrix including translation }
    function MultPoint(const AV: TVec3f): TVec3f;
    {** Transform a 3D direction (w=0), excluding translation }
    function MultDirection(const AV: TVec3f): TVec3f;
    {** Element-wise linear interpolation: self + (AOther - self) * AT }
    function Lerp(const AOther: TMat4f; const AT: Single): TMat4f;
    {** Return true if all elements differ by no more than AEpsilon }
    function Equals(const AOther: TMat4f; const AEpsilon: Single): Boolean;
    {** Return true if all elements are bit-for-bit identical }
    function PerfectlyEquals(const AOther: TMat4f): Boolean;
    property Data[ARow, ACol: Integer]: Single read GetElement write SetElement; default;
  end;

{ TMat4d - 4x4 double-precision matrix (row-major) }
  TMat4d = record
  private
    FData: array[0..3, 0..3] of Double;
    function GetElement(ARow, ACol: Integer): Double; inline;
    procedure SetElement(ARow, ACol: Integer; AValue: Double); inline;
  public
    {** Create a 4x4 matrix from 16 row-major elements }
    constructor Create(const A00, A01, A02, A03, A10, A11, A12, A13, A20, A21, A22, A23, A30, A31, A32, A33: Double);
    {** Return the determinant of the matrix }
    function Determinant: Double; inline;
    {** Return the transposed matrix }
    function Transpose: TMat4d; inline;
    {** Return the inverse matrix; zero matrix if singular }
    function Inverse: TMat4d; inline;
    {** Try to compute the inverse; returns false if singular (determinant near zero) }
    function TryInverse(out AResult: TMat4d): Boolean;
    {** Transform a 3D point (w=1), applying full matrix including translation }
    function MultPoint(const AV: TVec3f): TVec3f;
    {** Transform a 3D direction (w=0), excluding translation }
    function MultDirection(const AV: TVec3f): TVec3f;
    {** Element-wise linear interpolation: self + (AOther - self) * AT }
    function Lerp(const AOther: TMat4d; const AT: Double): TMat4d;
    {** Return true if all elements differ by no more than AEpsilon }
    function Equals(const AOther: TMat4d; const AEpsilon: Double): Boolean;
    {** Return true if all elements are bit-for-bit identical }
    function PerfectlyEquals(const AOther: TMat4d): Boolean;
    property Data[ARow, ACol: Integer]: Double read GetElement write SetElement; default;
  end;

{ Identity and zero matrix constructors }

{** Return a 3x3 single-precision identity matrix }
function Mat3fIdentity: TMat3f; inline;
{** Return a 3x3 double-precision identity matrix }
function Mat3dIdentity: TMat3d; inline;
{** Return a 4x4 single-precision identity matrix }
function Mat4fIdentity: TMat4f; inline;
{** Return a 4x4 double-precision identity matrix }
function Mat4dIdentity: TMat4d; inline;
{** Return a 3x3 single-precision zero matrix }
function Mat3fZero: TMat3f; inline;
{** Return a 3x3 double-precision zero matrix }
function Mat3dZero: TMat3d; inline;
{** Return a 4x4 single-precision zero matrix }
function Mat4fZero: TMat4f; inline;
{** Return a 4x4 double-precision zero matrix }
function Mat4dZero: TMat4d; inline;

{ Matrix multiply operators }

{** Multiply two 4x4 single-precision matrices (SIMD-accelerated) }
operator * (constref A, B: TMat4f): TMat4f;
{** Multiply two 4x4 double-precision matrices }
operator * (constref A, B: TMat4d): TMat4d;
{** Multiply two 3x3 single-precision matrices }
operator * (constref A, B: TMat3f): TMat3f;
{** Multiply two 3x3 double-precision matrices }
operator * (constref A, B: TMat3d): TMat3d;

{ Matrix-vector multiply }

{** Multiply a 4x4 single-precision matrix by a 4D vector (SIMD-accelerated) }
function Mat4fMulVec(const AM: TMat4f; const AV: TVec4f): TVec4f;
{** Multiply a 4x4 double-precision matrix by a 4D vector }
function Mat4dMulVec(const AM: TMat4d; const AV: TVec4d): TVec4d;

implementation

{ Helper functions }

function Mat3fIdentity: TMat3f;
begin
  Result := TMat3f.Create(1, 0, 0, 0, 1, 0, 0, 0, 1);
end;

function Mat3dIdentity: TMat3d;
begin
  Result := TMat3d.Create(1, 0, 0, 0, 1, 0, 0, 0, 1);
end;

function Mat4fIdentity: TMat4f;
begin
  Result := TMat4f.Create(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
end;

function Mat4dIdentity: TMat4d;
begin
  Result := TMat4d.Create(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
end;

function Mat3fZero: TMat3f;
begin
  Result := TMat3f.Create(0, 0, 0, 0, 0, 0, 0, 0, 0);
end;

function Mat3dZero: TMat3d;
begin
  Result := TMat3d.Create(0, 0, 0, 0, 0, 0, 0, 0, 0);
end;

function Mat4fZero: TMat4f;
begin
  Result := TMat4f.Create(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
end;

function Mat4dZero: TMat4d;
begin
  Result := TMat4d.Create(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
end;

{ TMat3f }

constructor TMat3f.Create(const A00, A01, A02, A10, A11, A12, A20, A21, A22: Single);
begin
  FData[0,0] := A00; FData[0,1] := A01; FData[0,2] := A02;
  FData[1,0] := A10; FData[1,1] := A11; FData[1,2] := A12;
  FData[2,0] := A20; FData[2,1] := A21; FData[2,2] := A22;
end;

function TMat3f.GetElement(ARow, ACol: Integer): Single;
begin
  Result := FData[ARow, ACol];
end;

procedure TMat3f.SetElement(ARow, ACol: Integer; AValue: Single);
begin
  FData[ARow, ACol] := AValue;
end;

function TMat3f.Determinant: Single;
begin
  Result := FData[0,0] * (FData[1,1] * FData[2,2] - FData[1,2] * FData[2,1])
          - FData[0,1] * (FData[1,0] * FData[2,2] - FData[1,2] * FData[2,0])
          + FData[0,2] * (FData[1,0] * FData[2,1] - FData[1,1] * FData[2,0]);
end;

function TMat3f.Transpose: TMat3f;
begin
  Result := Create(
    FData[0,0], FData[1,0], FData[2,0],
    FData[0,1], FData[1,1], FData[2,1],
    FData[0,2], FData[1,2], FData[2,2]
  );
end;

function TMat3f.Inverse: TMat3f;
var
  LDet: Single;
begin
  LDet := Determinant;
  if Abs(LDet) < 1e-10 then
    Exit(Mat3fZero);
  LDet := 1.0 / LDet;
  Result := Create(
    (FData[1,1] * FData[2,2] - FData[1,2] * FData[2,1]) * LDet,
    (FData[0,2] * FData[2,1] - FData[0,1] * FData[2,2]) * LDet,
    (FData[0,1] * FData[1,2] - FData[0,2] * FData[1,1]) * LDet,
    (FData[1,2] * FData[2,0] - FData[1,0] * FData[2,2]) * LDet,
    (FData[0,0] * FData[2,2] - FData[0,2] * FData[2,0]) * LDet,
    (FData[0,2] * FData[1,0] - FData[0,0] * FData[1,2]) * LDet,
    (FData[1,0] * FData[2,1] - FData[1,1] * FData[2,0]) * LDet,
    (FData[0,1] * FData[2,0] - FData[0,0] * FData[2,1]) * LDet,
    (FData[0,0] * FData[1,1] - FData[0,1] * FData[1,0]) * LDet
  );
end;

function TMat3f.TryInverse(out AResult: TMat3f): Boolean;
begin
  if Abs(Determinant) < 1e-10 then
  begin
    AResult := Mat3fZero;
    Exit(False);
  end;
  AResult := Inverse;
  Result := True;
end;

function TMat3f.Lerp(const AOther: TMat3f; const AT: Single): TMat3f;
var
  LRow, LCol: Integer;
begin
  for LRow := 0 to 2 do
    for LCol := 0 to 2 do
      Result.FData[LRow, LCol] := FData[LRow, LCol] + (AOther.FData[LRow, LCol] - FData[LRow, LCol]) * AT;
end;

function TMat3f.Equals(const AOther: TMat3f; const AEpsilon: Single): Boolean;
var
  LRow, LCol: Integer;
begin
  for LRow := 0 to 2 do
    for LCol := 0 to 2 do
      if Abs(FData[LRow, LCol] - AOther.FData[LRow, LCol]) > AEpsilon then
        Exit(False);
  Result := True;
end;

function TMat3f.PerfectlyEquals(const AOther: TMat3f): Boolean;
var
  LRow, LCol: Integer;
begin
  for LRow := 0 to 2 do
    for LCol := 0 to 2 do
      if FData[LRow, LCol] <> AOther.FData[LRow, LCol] then
        Exit(False);
  Result := True;
end;

{ TMat3d }

constructor TMat3d.Create(const A00, A01, A02, A10, A11, A12, A20, A21, A22: Double);
begin
  FData[0,0] := A00; FData[0,1] := A01; FData[0,2] := A02;
  FData[1,0] := A10; FData[1,1] := A11; FData[1,2] := A12;
  FData[2,0] := A20; FData[2,1] := A21; FData[2,2] := A22;
end;

function TMat3d.GetElement(ARow, ACol: Integer): Double;
begin
  Result := FData[ARow, ACol];
end;

procedure TMat3d.SetElement(ARow, ACol: Integer; AValue: Double);
begin
  FData[ARow, ACol] := AValue;
end;

function TMat3d.Determinant: Double;
begin
  Result := FData[0,0] * (FData[1,1] * FData[2,2] - FData[1,2] * FData[2,1])
          - FData[0,1] * (FData[1,0] * FData[2,2] - FData[1,2] * FData[2,0])
          + FData[0,2] * (FData[1,0] * FData[2,1] - FData[1,1] * FData[2,0]);
end;

function TMat3d.Transpose: TMat3d;
begin
  Result := Create(
    FData[0,0], FData[1,0], FData[2,0],
    FData[0,1], FData[1,1], FData[2,1],
    FData[0,2], FData[1,2], FData[2,2]
  );
end;

function TMat3d.Inverse: TMat3d;
var
  LDet: Double;
begin
  LDet := Determinant;
  if Abs(LDet) < 1e-10 then
    Exit(Mat3dZero);
  LDet := 1.0 / LDet;
  Result := Create(
    (FData[1,1] * FData[2,2] - FData[1,2] * FData[2,1]) * LDet,
    (FData[0,2] * FData[2,1] - FData[0,1] * FData[2,2]) * LDet,
    (FData[0,1] * FData[1,2] - FData[0,2] * FData[1,1]) * LDet,
    (FData[1,2] * FData[2,0] - FData[1,0] * FData[2,2]) * LDet,
    (FData[0,0] * FData[2,2] - FData[0,2] * FData[2,0]) * LDet,
    (FData[0,2] * FData[1,0] - FData[0,0] * FData[1,2]) * LDet,
    (FData[1,0] * FData[2,1] - FData[1,1] * FData[2,0]) * LDet,
    (FData[0,1] * FData[2,0] - FData[0,0] * FData[2,1]) * LDet,
    (FData[0,0] * FData[1,1] - FData[0,1] * FData[1,0]) * LDet
  );
end;

function TMat3d.TryInverse(out AResult: TMat3d): Boolean;
begin
  if Abs(Determinant) < 1e-10 then
  begin
    AResult := Mat3dZero;
    Exit(False);
  end;
  AResult := Inverse;
  Result := True;
end;

function TMat3d.Lerp(const AOther: TMat3d; const AT: Double): TMat3d;
var
  LRow, LCol: Integer;
begin
  for LRow := 0 to 2 do
    for LCol := 0 to 2 do
      Result.FData[LRow, LCol] := FData[LRow, LCol] + (AOther.FData[LRow, LCol] - FData[LRow, LCol]) * AT;
end;

function TMat3d.Equals(const AOther: TMat3d; const AEpsilon: Double): Boolean;
var
  LRow, LCol: Integer;
begin
  for LRow := 0 to 2 do
    for LCol := 0 to 2 do
      if Abs(FData[LRow, LCol] - AOther.FData[LRow, LCol]) > AEpsilon then
        Exit(False);
  Result := True;
end;

function TMat3d.PerfectlyEquals(const AOther: TMat3d): Boolean;
var
  LRow, LCol: Integer;
begin
  for LRow := 0 to 2 do
    for LCol := 0 to 2 do
      if FData[LRow, LCol] <> AOther.FData[LRow, LCol] then
        Exit(False);
  Result := True;
end;

{ TMat4f }

constructor TMat4f.Create(const A00, A01, A02, A03, A10, A11, A12, A13, A20, A21, A22, A23, A30, A31, A32, A33: Single);
begin
  FData[0,0] := A00; FData[0,1] := A01; FData[0,2] := A02; FData[0,3] := A03;
  FData[1,0] := A10; FData[1,1] := A11; FData[1,2] := A12; FData[1,3] := A13;
  FData[2,0] := A20; FData[2,1] := A21; FData[2,2] := A22; FData[2,3] := A23;
  FData[3,0] := A30; FData[3,1] := A31; FData[3,2] := A32; FData[3,3] := A33;
end;

function TMat4f.GetElement(ARow, ACol: Integer): Single;
begin
  Result := FData[ARow, ACol];
end;

procedure TMat4f.SetElement(ARow, ACol: Integer; AValue: Single);
begin
  FData[ARow, ACol] := AValue;
end;

function TMat4f.Determinant: Single;
var
  S0, S1, S2, S3, S4, S5: Single;
  C0, C1, C2, C3, C4, C5: Single;
begin
  S0 := FData[0,0] * FData[1,1] - FData[1,0] * FData[0,1];
  S1 := FData[0,0] * FData[1,2] - FData[1,0] * FData[0,2];
  S2 := FData[0,0] * FData[1,3] - FData[1,0] * FData[0,3];
  S3 := FData[0,1] * FData[1,2] - FData[1,1] * FData[0,2];
  S4 := FData[0,1] * FData[1,3] - FData[1,1] * FData[0,3];
  S5 := FData[0,2] * FData[1,3] - FData[1,2] * FData[0,3];
  C5 := FData[2,2] * FData[3,3] - FData[3,2] * FData[2,3];
  C4 := FData[2,1] * FData[3,3] - FData[3,1] * FData[2,3];
  C3 := FData[2,1] * FData[3,2] - FData[3,1] * FData[2,2];
  C2 := FData[2,0] * FData[3,3] - FData[3,0] * FData[2,3];
  C1 := FData[2,0] * FData[3,2] - FData[3,0] * FData[2,2];
  C0 := FData[2,0] * FData[3,1] - FData[3,0] * FData[2,1];
  Result := S0 * C5 - S1 * C4 + S2 * C3 + S3 * C2 - S4 * C1 + S5 * C0;
end;

function TMat4f.Transpose: TMat4f;
begin
  Result := Create(
    FData[0,0], FData[1,0], FData[2,0], FData[3,0],
    FData[0,1], FData[1,1], FData[2,1], FData[3,1],
    FData[0,2], FData[1,2], FData[2,2], FData[3,2],
    FData[0,3], FData[1,3], FData[2,3], FData[3,3]
  );
end;

function TMat4f.Inverse: TMat4f;
var
  S0, S1, S2, S3, S4, S5: Single;
  C0, C1, C2, C3, C4, C5: Single;
  LDet: Single;
begin
  S0 := FData[0,0] * FData[1,1] - FData[1,0] * FData[0,1];
  S1 := FData[0,0] * FData[1,2] - FData[1,0] * FData[0,2];
  S2 := FData[0,0] * FData[1,3] - FData[1,0] * FData[0,3];
  S3 := FData[0,1] * FData[1,2] - FData[1,1] * FData[0,2];
  S4 := FData[0,1] * FData[1,3] - FData[1,1] * FData[0,3];
  S5 := FData[0,2] * FData[1,3] - FData[1,2] * FData[0,3];
  C5 := FData[2,2] * FData[3,3] - FData[3,2] * FData[2,3];
  C4 := FData[2,1] * FData[3,3] - FData[3,1] * FData[2,3];
  C3 := FData[2,1] * FData[3,2] - FData[3,1] * FData[2,2];
  C2 := FData[2,0] * FData[3,3] - FData[3,0] * FData[2,3];
  C1 := FData[2,0] * FData[3,2] - FData[3,0] * FData[2,2];
  C0 := FData[2,0] * FData[3,1] - FData[3,0] * FData[2,1];
  LDet := S0 * C5 - S1 * C4 + S2 * C3 + S3 * C2 - S4 * C1 + S5 * C0;
  if Abs(LDet) < 1e-10 then
    Exit(Mat4fZero);
  LDet := 1.0 / LDet;
  Result.FData[0,0] := (FData[1,1] * C5 - FData[1,2] * C4 + FData[1,3] * C3) * LDet;
  Result.FData[0,1] := (-FData[0,1] * C5 + FData[0,2] * C4 - FData[0,3] * C3) * LDet;
  Result.FData[0,2] := (FData[3,1] * S5 - FData[3,2] * S4 + FData[3,3] * S3) * LDet;
  Result.FData[0,3] := (-FData[2,1] * S5 + FData[2,2] * S4 - FData[2,3] * S3) * LDet;
  Result.FData[1,0] := (-FData[1,0] * C5 + FData[1,2] * C2 - FData[1,3] * C1) * LDet;
  Result.FData[1,1] := (FData[0,0] * C5 - FData[0,2] * C2 + FData[0,3] * C1) * LDet;
  Result.FData[1,2] := (-FData[3,0] * S5 + FData[3,2] * S2 - FData[3,3] * S1) * LDet;
  Result.FData[1,3] := (FData[2,0] * S5 - FData[2,2] * S2 + FData[2,3] * S1) * LDet;
  Result.FData[2,0] := (FData[1,0] * C4 - FData[1,1] * C2 + FData[1,3] * C0) * LDet;
  Result.FData[2,1] := (-FData[0,0] * C4 + FData[0,1] * C2 - FData[0,3] * C0) * LDet;
  Result.FData[2,2] := (FData[3,0] * S4 - FData[3,1] * S2 + FData[3,3] * S0) * LDet;
  Result.FData[2,3] := (-FData[2,0] * S4 + FData[2,1] * S2 - FData[2,3] * S0) * LDet;
  Result.FData[3,0] := (-FData[1,0] * C3 + FData[1,1] * C1 - FData[1,2] * C0) * LDet;
  Result.FData[3,1] := (FData[0,0] * C3 - FData[0,1] * C1 + FData[0,2] * C0) * LDet;
  Result.FData[3,2] := (-FData[3,0] * S3 + FData[3,1] * S1 - FData[3,2] * S0) * LDet;
  Result.FData[3,3] := (FData[2,0] * S3 - FData[2,1] * S1 + FData[2,2] * S0) * LDet;
end;

function TMat4f.TryInverse(out AResult: TMat4f): Boolean;
begin
  if Abs(Determinant) < 1e-10 then
  begin
    AResult := Mat4fZero;
    Exit(False);
  end;
  AResult := Inverse;
  Result := True;
end;

function TMat4f.MultPoint(const AV: TVec3f): TVec3f;
begin
  Result := TVec3f.Create(
    FData[0,0] * AV.X + FData[0,1] * AV.Y + FData[0,2] * AV.Z + FData[0,3],
    FData[1,0] * AV.X + FData[1,1] * AV.Y + FData[1,2] * AV.Z + FData[1,3],
    FData[2,0] * AV.X + FData[2,1] * AV.Y + FData[2,2] * AV.Z + FData[2,3]
  );
end;

function TMat4f.MultDirection(const AV: TVec3f): TVec3f;
begin
  Result := TVec3f.Create(
    FData[0,0] * AV.X + FData[0,1] * AV.Y + FData[0,2] * AV.Z,
    FData[1,0] * AV.X + FData[1,1] * AV.Y + FData[1,2] * AV.Z,
    FData[2,0] * AV.X + FData[2,1] * AV.Y + FData[2,2] * AV.Z
  );
end;

function TMat4f.Lerp(const AOther: TMat4f; const AT: Single): TMat4f;
var
  LRow, LCol: Integer;
begin
  for LRow := 0 to 3 do
    for LCol := 0 to 3 do
      Result.FData[LRow, LCol] := FData[LRow, LCol] + (AOther.FData[LRow, LCol] - FData[LRow, LCol]) * AT;
end;

function TMat4f.Equals(const AOther: TMat4f; const AEpsilon: Single): Boolean;
var
  LRow, LCol: Integer;
begin
  for LRow := 0 to 3 do
    for LCol := 0 to 3 do
      if Abs(FData[LRow, LCol] - AOther.FData[LRow, LCol]) > AEpsilon then
        Exit(False);
  Result := True;
end;

function TMat4f.PerfectlyEquals(const AOther: TMat4f): Boolean;
var
  LRow, LCol: Integer;
begin
  for LRow := 0 to 3 do
    for LCol := 0 to 3 do
      if FData[LRow, LCol] <> AOther.FData[LRow, LCol] then
        Exit(False);
  Result := True;
end;

{ TMat4d }

constructor TMat4d.Create(const A00, A01, A02, A03, A10, A11, A12, A13, A20, A21, A22, A23, A30, A31, A32, A33: Double);
begin
  FData[0,0] := A00; FData[0,1] := A01; FData[0,2] := A02; FData[0,3] := A03;
  FData[1,0] := A10; FData[1,1] := A11; FData[1,2] := A12; FData[1,3] := A13;
  FData[2,0] := A20; FData[2,1] := A21; FData[2,2] := A22; FData[2,3] := A23;
  FData[3,0] := A30; FData[3,1] := A31; FData[3,2] := A32; FData[3,3] := A33;
end;

function TMat4d.GetElement(ARow, ACol: Integer): Double;
begin
  Result := FData[ARow, ACol];
end;

procedure TMat4d.SetElement(ARow, ACol: Integer; AValue: Double);
begin
  FData[ARow, ACol] := AValue;
end;

function TMat4d.Determinant: Double;
var
  S0, S1, S2, S3, S4, S5: Double;
  C0, C1, C2, C3, C4, C5: Double;
begin
  S0 := FData[0,0] * FData[1,1] - FData[1,0] * FData[0,1];
  S1 := FData[0,0] * FData[1,2] - FData[1,0] * FData[0,2];
  S2 := FData[0,0] * FData[1,3] - FData[1,0] * FData[0,3];
  S3 := FData[0,1] * FData[1,2] - FData[1,1] * FData[0,2];
  S4 := FData[0,1] * FData[1,3] - FData[1,1] * FData[0,3];
  S5 := FData[0,2] * FData[1,3] - FData[1,2] * FData[0,3];
  C5 := FData[2,2] * FData[3,3] - FData[3,2] * FData[2,3];
  C4 := FData[2,1] * FData[3,3] - FData[3,1] * FData[2,3];
  C3 := FData[2,1] * FData[3,2] - FData[3,1] * FData[2,2];
  C2 := FData[2,0] * FData[3,3] - FData[3,0] * FData[2,3];
  C1 := FData[2,0] * FData[3,2] - FData[3,0] * FData[2,2];
  C0 := FData[2,0] * FData[3,1] - FData[3,0] * FData[2,1];
  Result := S0 * C5 - S1 * C4 + S2 * C3 + S3 * C2 - S4 * C1 + S5 * C0;
end;

function TMat4d.Transpose: TMat4d;
begin
  Result := Create(
    FData[0,0], FData[1,0], FData[2,0], FData[3,0],
    FData[0,1], FData[1,1], FData[2,1], FData[3,1],
    FData[0,2], FData[1,2], FData[2,2], FData[3,2],
    FData[0,3], FData[1,3], FData[2,3], FData[3,3]
  );
end;

function TMat4d.Inverse: TMat4d;
var
  S0, S1, S2, S3, S4, S5: Double;
  C0, C1, C2, C3, C4, C5: Double;
  LDet: Double;
begin
  S0 := FData[0,0] * FData[1,1] - FData[1,0] * FData[0,1];
  S1 := FData[0,0] * FData[1,2] - FData[1,0] * FData[0,2];
  S2 := FData[0,0] * FData[1,3] - FData[1,0] * FData[0,3];
  S3 := FData[0,1] * FData[1,2] - FData[1,1] * FData[0,2];
  S4 := FData[0,1] * FData[1,3] - FData[1,1] * FData[0,3];
  S5 := FData[0,2] * FData[1,3] - FData[1,2] * FData[0,3];
  C5 := FData[2,2] * FData[3,3] - FData[3,2] * FData[2,3];
  C4 := FData[2,1] * FData[3,3] - FData[3,1] * FData[2,3];
  C3 := FData[2,1] * FData[3,2] - FData[3,1] * FData[2,2];
  C2 := FData[2,0] * FData[3,3] - FData[3,0] * FData[2,3];
  C1 := FData[2,0] * FData[3,2] - FData[3,0] * FData[2,2];
  C0 := FData[2,0] * FData[3,1] - FData[3,0] * FData[2,1];
  LDet := S0 * C5 - S1 * C4 + S2 * C3 + S3 * C2 - S4 * C1 + S5 * C0;
  if Abs(LDet) < 1e-10 then
    Exit(Mat4dZero);
  LDet := 1.0 / LDet;
  Result.FData[0,0] := (FData[1,1] * C5 - FData[1,2] * C4 + FData[1,3] * C3) * LDet;
  Result.FData[0,1] := (-FData[0,1] * C5 + FData[0,2] * C4 - FData[0,3] * C3) * LDet;
  Result.FData[0,2] := (FData[3,1] * S5 - FData[3,2] * S4 + FData[3,3] * S3) * LDet;
  Result.FData[0,3] := (-FData[2,1] * S5 + FData[2,2] * S4 - FData[2,3] * S3) * LDet;
  Result.FData[1,0] := (-FData[1,0] * C5 + FData[1,2] * C2 - FData[1,3] * C1) * LDet;
  Result.FData[1,1] := (FData[0,0] * C5 - FData[0,2] * C2 + FData[0,3] * C1) * LDet;
  Result.FData[1,2] := (-FData[3,0] * S5 + FData[3,2] * S2 - FData[3,3] * S1) * LDet;
  Result.FData[1,3] := (FData[2,0] * S5 - FData[2,2] * S2 + FData[2,3] * S1) * LDet;
  Result.FData[2,0] := (FData[1,0] * C4 - FData[1,1] * C2 + FData[1,3] * C0) * LDet;
  Result.FData[2,1] := (-FData[0,0] * C4 + FData[0,1] * C2 - FData[0,3] * C0) * LDet;
  Result.FData[2,2] := (FData[3,0] * S4 - FData[3,1] * S2 + FData[3,3] * S0) * LDet;
  Result.FData[2,3] := (-FData[2,0] * S4 + FData[2,1] * S2 - FData[2,3] * S0) * LDet;
  Result.FData[3,0] := (-FData[1,0] * C3 + FData[1,1] * C1 - FData[1,2] * C0) * LDet;
  Result.FData[3,1] := (FData[0,0] * C3 - FData[0,1] * C1 + FData[0,2] * C0) * LDet;
  Result.FData[3,2] := (-FData[3,0] * S3 + FData[3,1] * S1 - FData[3,2] * S0) * LDet;
  Result.FData[3,3] := (FData[2,0] * S3 - FData[2,1] * S1 + FData[2,2] * S0) * LDet;
end;

function TMat4d.TryInverse(out AResult: TMat4d): Boolean;
begin
  if Abs(Determinant) < 1e-10 then
  begin
    AResult := Mat4dZero;
    Exit(False);
  end;
  AResult := Inverse;
  Result := True;
end;

function TMat4d.MultPoint(const AV: TVec3f): TVec3f;
begin
  Result := TVec3f.Create(
    FData[0,0] * AV.X + FData[0,1] * AV.Y + FData[0,2] * AV.Z + FData[0,3],
    FData[1,0] * AV.X + FData[1,1] * AV.Y + FData[1,2] * AV.Z + FData[1,3],
    FData[2,0] * AV.X + FData[2,1] * AV.Y + FData[2,2] * AV.Z + FData[2,3]
  );
end;

function TMat4d.MultDirection(const AV: TVec3f): TVec3f;
begin
  Result := TVec3f.Create(
    FData[0,0] * AV.X + FData[0,1] * AV.Y + FData[0,2] * AV.Z,
    FData[1,0] * AV.X + FData[1,1] * AV.Y + FData[1,2] * AV.Z,
    FData[2,0] * AV.X + FData[2,1] * AV.Y + FData[2,2] * AV.Z
  );
end;

function TMat4d.Lerp(const AOther: TMat4d; const AT: Double): TMat4d;
var
  LRow, LCol: Integer;
begin
  for LRow := 0 to 3 do
    for LCol := 0 to 3 do
      Result.FData[LRow, LCol] := FData[LRow, LCol] + (AOther.FData[LRow, LCol] - FData[LRow, LCol]) * AT;
end;

function TMat4d.Equals(const AOther: TMat4d; const AEpsilon: Double): Boolean;
var
  LRow, LCol: Integer;
begin
  for LRow := 0 to 3 do
    for LCol := 0 to 3 do
      if Abs(FData[LRow, LCol] - AOther.FData[LRow, LCol]) > AEpsilon then
        Exit(False);
  Result := True;
end;

function TMat4d.PerfectlyEquals(const AOther: TMat4d): Boolean;
var
  LRow, LCol: Integer;
begin
  for LRow := 0 to 3 do
    for LCol := 0 to 3 do
      if FData[LRow, LCol] <> AOther.FData[LRow, LCol] then
        Exit(False);
  Result := True;
end;

{ === Matrix multiply operators === }

operator * (constref A, B: TMat4f): TMat4f;
begin
  SimdMat4fMul(@A.FData[0, 0], @B.FData[0, 0], @Result.FData[0, 0]);
end;

operator * (constref A, B: TMat4d): TMat4d;
var
  LRow, LCol, LK: Integer;
begin
  for LRow := 0 to 3 do
    for LCol := 0 to 3 do
    begin
      Result.FData[LRow, LCol] := 0;
      for LK := 0 to 3 do
        Result.FData[LRow, LCol] := Result.FData[LRow, LCol]
          + A.FData[LRow, LK] * B.FData[LK, LCol];
    end;
end;

operator * (constref A, B: TMat3f): TMat3f;
var
  LRow, LCol, LK: Integer;
begin
  for LRow := 0 to 2 do
    for LCol := 0 to 2 do
    begin
      Result.FData[LRow, LCol] := 0;
      for LK := 0 to 2 do
        Result.FData[LRow, LCol] := Result.FData[LRow, LCol]
          + A.FData[LRow, LK] * B.FData[LK, LCol];
    end;
end;

operator * (constref A, B: TMat3d): TMat3d;
var
  LRow, LCol, LK: Integer;
begin
  for LRow := 0 to 2 do
    for LCol := 0 to 2 do
    begin
      Result.FData[LRow, LCol] := 0;
      for LK := 0 to 2 do
        Result.FData[LRow, LCol] := Result.FData[LRow, LCol]
          + A.FData[LRow, LK] * B.FData[LK, LCol];
    end;
end;

{ === Matrix-vector multiply === }

function Mat4fMulVec(const AM: TMat4f; const AV: TVec4f): TVec4f;
var
  LOX, LOY, LOZ, LOW: Single;
begin
  SimdMat4fMulVec4f(@AM.FData[0, 0], AV.X, AV.Y, AV.Z, AV.W, LOX, LOY, LOZ, LOW);
  Result := TVec4f.Create(LOX, LOY, LOZ, LOW);
end;

function Mat4dMulVec(const AM: TMat4d; const AV: TVec4d): TVec4d;
begin
  Result := TVec4d.Create(
    AM.FData[0, 0] * AV.X + AM.FData[0, 1] * AV.Y + AM.FData[0, 2] * AV.Z + AM.FData[0, 3] * AV.W,
    AM.FData[1, 0] * AV.X + AM.FData[1, 1] * AV.Y + AM.FData[1, 2] * AV.Z + AM.FData[1, 3] * AV.W,
    AM.FData[2, 0] * AV.X + AM.FData[2, 1] * AV.Y + AM.FData[2, 2] * AV.Z + AM.FData[2, 3] * AV.W,
    AM.FData[3, 0] * AV.X + AM.FData[3, 1] * AV.Y + AM.FData[3, 2] * AV.Z + AM.FData[3, 3] * AV.W);
end;

end.
