unit nextpas.core.math.quat.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.scalar,
  nextpas.core.math.vec.base,
  nextpas.core.math.mat.base;

type
  TQuatf = record
  private
    FX, FY, FZ, FW: Single;
    function GetX: Single; inline;
    procedure SetX(const AValue: Single); inline;
    function GetY: Single; inline;
    procedure SetY(const AValue: Single); inline;
    function GetZ: Single; inline;
    procedure SetZ(const AValue: Single); inline;
    function GetW: Single; inline;
    procedure SetW(const AValue: Single); inline;
  public
    constructor Create(const AX, AY, AZ, AW: Single);
    constructor FromAxisAngle(const AAxis: TVec3f; const AAngle: Single);
    function Normalize: TQuatf; inline;
    function Conjugate: TQuatf; inline;
    function Length: Single; inline;
    function Dot(constref AOther: TQuatf): Single; inline;
    function ToMat4f: TMat4f; inline;
    function RotateVec(const AV: TVec3f): TVec3f; inline;
    property X: Single read GetX write SetX;
    property Y: Single read GetY write SetY;
    property Z: Single read GetZ write SetZ;
    property W: Single read GetW write SetW;
  end;

  TQuatd = record
  private
    FX, FY, FZ, FW: Double;
    function GetX: Double; inline;
    procedure SetX(const AValue: Double); inline;
    function GetY: Double; inline;
    procedure SetY(const AValue: Double); inline;
    function GetZ: Double; inline;
    procedure SetZ(const AValue: Double); inline;
    function GetW: Double; inline;
    procedure SetW(const AValue: Double); inline;
  public
    constructor Create(const AX, AY, AZ, AW: Double);
    constructor FromAxisAngle(const AAxis: TVec3d; const AAngle: Double);
    function Normalize: TQuatd; inline;
    function Conjugate: TQuatd; inline;
    function Length: Double; inline;
    function Dot(constref AOther: TQuatd): Double; inline;
    function ToMat4d: TMat4d; inline;
    function RotateVec(const AV: TVec3d): TVec3d; inline;
    property X: Double read GetX write SetX;
    property Y: Double read GetY write SetY;
    property Z: Double read GetZ write SetZ;
    property W: Double read GetW write SetW;
  end;

function QuatfIdentity: TQuatf; inline;
function QuatdIdentity: TQuatd; inline;

implementation

function QuatfIdentity: TQuatf;
begin
  Result := TQuatf.Create(0, 0, 0, 1);
end;

function QuatdIdentity: TQuatd;
begin
  Result := TQuatd.Create(0, 0, 0, 1);
end;

{ TQuatf }

constructor TQuatf.Create(const AX, AY, AZ, AW: Single);
begin
  FX := AX; FY := AY; FZ := AZ; FW := AW;
end;

constructor TQuatf.FromAxisAngle(const AAxis: TVec3f; const AAngle: Single);
var
  LHalfAngle: Single;
  LS: Single;
  LLen: Single;
begin
  LHalfAngle := AAngle * 0.5;
  LS := Sin(LHalfAngle);
  LLen := AAxis.Length;
  if LLen < 1e-10 then
    Create(0, 0, 0, 1)
  else
  begin
    FX := AAxis.X / LLen * LS;
    FY := AAxis.Y / LLen * LS;
    FZ := AAxis.Z / LLen * LS;
    FW := Cos(LHalfAngle);
  end;
end;

function TQuatf.GetX: Single;
begin
  Result := FX;
end;

procedure TQuatf.SetX(const AValue: Single);
begin
  FX := AValue;
end;

function TQuatf.GetY: Single;
begin
  Result := FY;
end;

procedure TQuatf.SetY(const AValue: Single);
begin
  FY := AValue;
end;

function TQuatf.GetZ: Single;
begin
  Result := FZ;
end;

procedure TQuatf.SetZ(const AValue: Single);
begin
  FZ := AValue;
end;

function TQuatf.GetW: Single;
begin
  Result := FW;
end;

procedure TQuatf.SetW(const AValue: Single);
begin
  FW := AValue;
end;

function TQuatf.Normalize: TQuatf;
var
  LLen: Single;
begin
  LLen := Length;
  if LLen < 1e-10 then
    Exit(QuatfIdentity);
  Result := Create(FX / LLen, FY / LLen, FZ / LLen, FW / LLen);
end;

function TQuatf.Conjugate: TQuatf;
begin
  Result := Create(-FX, -FY, -FZ, FW);
end;

function TQuatf.Length: Single;
begin
  Result := Sqrt(FX * FX + FY * FY + FZ * FZ + FW * FW);
end;

function TQuatf.Dot(constref AOther: TQuatf): Single;
begin
  Result := FX * AOther.FX + FY * AOther.FY + FZ * AOther.FZ + FW * AOther.FW;
end;

function TQuatf.ToMat4f: TMat4f;
var
  LXX, LYY, LZZ, LXY, LXZ, LYZ, LWX, LWY, LWZ: Single;
begin
  LXX := FX * FX; LYY := FY * FY; LZZ := FZ * FZ;
  LXY := FX * FY; LXZ := FX * FZ; LYZ := FY * FZ;
  LWX := FW * FX; LWY := FW * FY; LWZ := FW * FZ;
  Result := TMat4f.Create(
    1 - 2 * (LYY + LZZ), 2 * (LXY - LWZ), 2 * (LXZ + LWY), 0,
    2 * (LXY + LWZ), 1 - 2 * (LXX + LZZ), 2 * (LYZ - LWX), 0,
    2 * (LXZ - LWY), 2 * (LYZ + LWX), 1 - 2 * (LXX + LYY), 0,
    0, 0, 0, 1
  );
end;

function TQuatf.RotateVec(const AV: TVec3f): TVec3f;
var
  LQv: TQuatf;
  LQc: TQuatf;
begin
  LQv := Create(AV.X, AV.Y, AV.Z, 0);
  LQc := Conjugate;
  // q * v * q^-1
  // For unit quaternion, q^-1 = conjugate
  Result := TVec3f.Create(
    (1 - 2 * (FY * FY + FZ * FZ)) * AV.X + 2 * (FX * FY - FW * FZ) * AV.Y + 2 * (FX * FZ + FW * FY) * AV.Z,
    2 * (FX * FY + FW * FZ) * AV.X + (1 - 2 * (FX * FX + FZ * FZ)) * AV.Y + 2 * (FY * FZ - FW * FX) * AV.Z,
    2 * (FX * FZ - FW * FY) * AV.X + 2 * (FY * FZ + FW * FX) * AV.Y + (1 - 2 * (FX * FX + FY * FY)) * AV.Z
  );
end;

{ TQuatd }

constructor TQuatd.Create(const AX, AY, AZ, AW: Double);
begin
  FX := AX; FY := AY; FZ := AZ; FW := AW;
end;

constructor TQuatd.FromAxisAngle(const AAxis: TVec3d; const AAngle: Double);
var
  LHalfAngle: Double;
  LS: Double;
  LLen: Double;
begin
  LHalfAngle := AAngle * 0.5;
  LS := Sin(LHalfAngle);
  LLen := AAxis.Length;
  if LLen < 1e-10 then
    Create(0, 0, 0, 1)
  else
  begin
    FX := AAxis.X / LLen * LS;
    FY := AAxis.Y / LLen * LS;
    FZ := AAxis.Z / LLen * LS;
    FW := Cos(LHalfAngle);
  end;
end;

function TQuatd.GetX: Double;
begin
  Result := FX;
end;

procedure TQuatd.SetX(const AValue: Double);
begin
  FX := AValue;
end;

function TQuatd.GetY: Double;
begin
  Result := FY;
end;

procedure TQuatd.SetY(const AValue: Double);
begin
  FY := AValue;
end;

function TQuatd.GetZ: Double;
begin
  Result := FZ;
end;

procedure TQuatd.SetZ(const AValue: Double);
begin
  FZ := AValue;
end;

function TQuatd.GetW: Double;
begin
  Result := FW;
end;

procedure TQuatd.SetW(const AValue: Double);
begin
  FW := AValue;
end;

function TQuatd.Normalize: TQuatd;
var
  LLen: Double;
begin
  LLen := Length;
  if LLen < 1e-10 then
    Exit(QuatdIdentity);
  Result := Create(FX / LLen, FY / LLen, FZ / LLen, FW / LLen);
end;

function TQuatd.Conjugate: TQuatd;
begin
  Result := Create(-FX, -FY, -FZ, FW);
end;

function TQuatd.Length: Double;
begin
  Result := Sqrt(FX * FX + FY * FY + FZ * FZ + FW * FW);
end;

function TQuatd.Dot(constref AOther: TQuatd): Double;
begin
  Result := FX * AOther.FX + FY * AOther.FY + FZ * AOther.FZ + FW * AOther.FW;
end;

function TQuatd.ToMat4d: TMat4d;
var
  LXX, LYY, LZZ, LXY, LXZ, LYZ, LWX, LWY, LWZ: Double;
begin
  LXX := FX * FX; LYY := FY * FY; LZZ := FZ * FZ;
  LXY := FX * FY; LXZ := FX * FZ; LYZ := FY * FZ;
  LWX := FW * FX; LWY := FW * FY; LWZ := FW * FZ;
  Result := TMat4d.Create(
    1 - 2 * (LYY + LZZ), 2 * (LXY - LWZ), 2 * (LXZ + LWY), 0,
    2 * (LXY + LWZ), 1 - 2 * (LXX + LZZ), 2 * (LYZ - LWX), 0,
    2 * (LXZ - LWY), 2 * (LYZ + LWX), 1 - 2 * (LXX + LYY), 0,
    0, 0, 0, 1
  );
end;

function TQuatd.RotateVec(const AV: TVec3d): TVec3d;
var
  LQv: TQuatd;
  LQc: TQuatd;
begin
  LQv := Create(AV.X, AV.Y, AV.Z, 0);
  LQc := Conjugate;
  // q * v * q^-1
  // For unit quaternion, q^-1 = conjugate
  Result := TVec3d.Create(
    (1 - 2 * (FY * FY + FZ * FZ)) * AV.X + 2 * (FX * FY - FW * FZ) * AV.Y + 2 * (FX * FZ + FW * FY) * AV.Z,
    2 * (FX * FY + FW * FZ) * AV.X + (1 - 2 * (FX * FX + FZ * FZ)) * AV.Y + 2 * (FY * FZ - FW * FX) * AV.Z,
    2 * (FX * FZ - FW * FY) * AV.X + 2 * (FY * FZ + FW * FX) * AV.Y + (1 - 2 * (FX * FX + FY * FY)) * AV.Z
  );
end;

end.
