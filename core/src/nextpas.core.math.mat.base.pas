unit nextpas.core.math.mat.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.scalar,
  nextpas.core.math.vec.base;

type
  TMat3f = record
  private
    FData: array[0..2, 0..2] of Single;
    function GetElement(ARow, ACol: Integer): Single; inline;
    procedure SetElement(ARow, ACol: Integer; AValue: Single); inline;
  public
    constructor Create(const A00, A01, A02, A10, A11, A12, A20, A21, A22: Single);
    function Determinant: Single; inline;
    function Transpose: TMat3f; inline;
    function Inverse: TMat3f; inline;
    property Data[ARow, ACol: Integer]: Single read GetElement write SetElement; default;
  end;

  TMat3d = record
  private
    FData: array[0..2, 0..2] of Double;
    function GetElement(ARow, ACol: Integer): Double; inline;
    procedure SetElement(ARow, ACol: Integer; AValue: Double); inline;
  public
    constructor Create(const A00, A01, A02, A10, A11, A12, A20, A21, A22: Double);
    function Determinant: Double; inline;
    function Transpose: TMat3d; inline;
    function Inverse: TMat3d; inline;
    property Data[ARow, ACol: Integer]: Double read GetElement write SetElement; default;
  end;

  TMat4f = record
  private
    FData: array[0..3, 0..3] of Single;
    function GetElement(ARow, ACol: Integer): Single; inline;
    procedure SetElement(ARow, ACol: Integer; AValue: Single); inline;
  public
    constructor Create(const A00, A01, A02, A03, A10, A11, A12, A13, A20, A21, A22, A23, A30, A31, A32, A33: Single);
    function Determinant: Single; inline;
    function Transpose: TMat4f; inline;
    function Inverse: TMat4f; inline;
    property Data[ARow, ACol: Integer]: Single read GetElement write SetElement; default;
  end;

  TMat4d = record
  private
    FData: array[0..3, 0..3] of Double;
    function GetElement(ARow, ACol: Integer): Double; inline;
    procedure SetElement(ARow, ACol: Integer; AValue: Double); inline;
  public
    constructor Create(const A00, A01, A02, A03, A10, A11, A12, A13, A20, A21, A22, A23, A30, A31, A32, A33: Double);
    function Determinant: Double; inline;
    function Transpose: TMat4d; inline;
    function Inverse: TMat4d; inline;
    property Data[ARow, ACol: Integer]: Double read GetElement write SetElement; default;
  end;

function Mat3fIdentity: TMat3f; inline;
function Mat3dIdentity: TMat3d; inline;
function Mat4fIdentity: TMat4f; inline;
function Mat4dIdentity: TMat4d; inline;
function Mat3fZero: TMat3f; inline;
function Mat3dZero: TMat3d; inline;
function Mat4fZero: TMat4f; inline;
function Mat4dZero: TMat4d; inline;

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

end.
