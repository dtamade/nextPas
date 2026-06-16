unit nextpas.core.math.quat.base;

{$I nextpas.core.settings.inc}

interface

uses
  Math,
  nextpas.core.math.scalar,
  nextpas.core.math.vec.base,
  nextpas.core.math.mat.base;

type
{ TQuatf - single-precision quaternion (x, y, z, w) }
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
    {** Create a quaternion from x, y, z, w components }
    constructor Create(const AX, AY, AZ, AW: Single);
    {** Create a quaternion from an axis and rotation angle in radians }
    constructor FromAxisAngle(const AAxis: TVec3f; const AAngle: Single);
    {** Construct a quaternion from a 3x3 rotation matrix using Shepperd's method }
    class function FromRotationMatrix(const AM: TMat3f): TQuatf; static;
    {** Return a unit quaternion; identity if degenerate }
    function Normalize: TQuatf; inline;
    {** Return the conjugate (negated imaginary, same real) }
    function Conjugate: TQuatf; inline;
    {** Return the Euclidean length of the quaternion }
    function Length: Single; inline;
    {** Return the dot product with another quaternion }
    function Dot(constref AOther: TQuatf): Single; inline;
    {** Spherical linear interpolation to ATarget at parameter AT in [0,1]; takes the shortest path }
    function Slerp(const ATarget: TQuatf; const AT: Single): TQuatf;
    {** Normalized linear interpolation to ATarget at parameter AT in [0,1]; faster but non-uniform angular speed }
    function Nlerp(const ATarget: TQuatf; const AT: Single): TQuatf;
    {** Convert to a 4x4 rotation matrix }
    function ToMat4f: TMat4f; inline;
    {** Convert to a 4x4 rotation matrix (alias of ToMat4f) }
    function ToRotationMatrix: TMat4f; inline;
    {** Convert to a 3x3 rotation matrix }
    function ToRotationMatrix3: TMat3f;
    {** Rotate a 3D vector by this quaternion (assumes unit quaternion) }
    function RotateVec(const AV: TVec3f): TVec3f;
    property X: Single read GetX write SetX;
    property Y: Single read GetY write SetY;
    property Z: Single read GetZ write SetZ;
    property W: Single read GetW write SetW;
  end;

{ TQuatd - double-precision quaternion (x, y, z, w) }
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
    {** Create a quaternion from x, y, z, w components }
    constructor Create(const AX, AY, AZ, AW: Double);
    {** Create a quaternion from an axis and rotation angle in radians }
    constructor FromAxisAngle(const AAxis: TVec3d; const AAngle: Double);
    {** Construct a quaternion from a 3x3 rotation matrix using Shepperd's method }
    class function FromRotationMatrix(const AM: TMat3d): TQuatd; static;
    {** Return a unit quaternion; identity if degenerate }
    function Normalize: TQuatd; inline;
    {** Return the conjugate (negated imaginary, same real) }
    function Conjugate: TQuatd; inline;
    {** Return the Euclidean length of the quaternion }
    function Length: Double; inline;
    {** Return the dot product with another quaternion }
    function Dot(constref AOther: TQuatd): Double; inline;
    {** Spherical linear interpolation to ATarget at parameter AT in [0,1]; takes the shortest path }
    function Slerp(const ATarget: TQuatd; const AT: Double): TQuatd;
    {** Normalized linear interpolation to ATarget at parameter AT in [0,1]; faster but non-uniform angular speed }
    function Nlerp(const ATarget: TQuatd; const AT: Double): TQuatd;
    {** Convert to a 4x4 rotation matrix }
    function ToMat4d: TMat4d; inline;
    {** Convert to a 4x4 rotation matrix (alias of ToMat4d) }
    function ToRotationMatrix: TMat4d; inline;
    {** Convert to a 3x3 rotation matrix }
    function ToRotationMatrix3: TMat3d;
    {** Rotate a 3D vector by this quaternion (assumes unit quaternion) }
    function RotateVec(const AV: TVec3d): TVec3d;
    property X: Double read GetX write SetX;
    property Y: Double read GetY write SetY;
    property Z: Double read GetZ write SetZ;
    property W: Double read GetW write SetW;
  end;

{ Quaternion multiply operators }

{** Multiply two single-precision quaternions (compose rotations): result = A * B }
operator * (constref A, B: TQuatf): TQuatf;
{** Multiply two double-precision quaternions (compose rotations): result = A * B }
operator * (constref A, B: TQuatd): TQuatd;

{ Identity quaternion constructors }

{** Return the single-precision identity quaternion (0, 0, 0, 1) }
function QuatfIdentity: TQuatf; inline;
{** Return the double-precision identity quaternion (0, 0, 0, 1) }
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

class function TQuatf.FromRotationMatrix(const AM: TMat3f): TQuatf;
var
  LTrace: Single;
  LS: Single;
  LInvS: Single;
begin
  LTrace := AM[0, 0] + AM[1, 1] + AM[2, 2];
  if LTrace > 0 then
  begin
    LS := Sqrt(LTrace + 1.0) * 2.0;
    LInvS := 1.0 / LS;
    Result.FW := 0.25 * LS;
    Result.FX := (AM[2, 1] - AM[1, 2]) * LInvS;
    Result.FY := (AM[0, 2] - AM[2, 0]) * LInvS;
    Result.FZ := (AM[1, 0] - AM[0, 1]) * LInvS;
  end
  else if (AM[0, 0] > AM[1, 1]) and (AM[0, 0] > AM[2, 2]) then
  begin
    LS := Sqrt(1.0 + AM[0, 0] - AM[1, 1] - AM[2, 2]) * 2.0;
    LInvS := 1.0 / LS;
    Result.FW := (AM[2, 1] - AM[1, 2]) * LInvS;
    Result.FX := 0.25 * LS;
    Result.FY := (AM[0, 1] + AM[1, 0]) * LInvS;
    Result.FZ := (AM[0, 2] + AM[2, 0]) * LInvS;
  end
  else if AM[1, 1] > AM[2, 2] then
  begin
    LS := Sqrt(1.0 + AM[1, 1] - AM[0, 0] - AM[2, 2]) * 2.0;
    LInvS := 1.0 / LS;
    Result.FW := (AM[0, 2] - AM[2, 0]) * LInvS;
    Result.FX := (AM[0, 1] + AM[1, 0]) * LInvS;
    Result.FY := 0.25 * LS;
    Result.FZ := (AM[1, 2] + AM[2, 1]) * LInvS;
  end
  else
  begin
    LS := Sqrt(1.0 + AM[2, 2] - AM[0, 0] - AM[1, 1]) * 2.0;
    LInvS := 1.0 / LS;
    Result.FW := (AM[1, 0] - AM[0, 1]) * LInvS;
    Result.FX := (AM[0, 2] + AM[2, 0]) * LInvS;
    Result.FY := (AM[1, 2] + AM[2, 1]) * LInvS;
    Result.FZ := 0.25 * LS;
  end;
  Result := Result.Normalize;
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

function TQuatf.ToRotationMatrix: TMat4f;
begin
  Result := ToMat4f;
end;

function TQuatf.ToRotationMatrix3: TMat3f;
var
  LXX, LYY, LZZ, LXY, LXZ, LYZ, LWX, LWY, LWZ: Single;
begin
  LXX := FX * FX; LYY := FY * FY; LZZ := FZ * FZ;
  LXY := FX * FY; LXZ := FX * FZ; LYZ := FY * FZ;
  LWX := FW * FX; LWY := FW * FY; LWZ := FW * FZ;
  Result := TMat3f.Create(
    1 - 2 * (LYY + LZZ), 2 * (LXY - LWZ), 2 * (LXZ + LWY),
    2 * (LXY + LWZ), 1 - 2 * (LXX + LZZ), 2 * (LYZ - LWX),
    2 * (LXZ - LWY), 2 * (LYZ + LWX), 1 - 2 * (LXX + LYY)
  );
end;

function TQuatf.Slerp(const ATarget: TQuatf; const AT: Single): TQuatf;
var
  LDotProduct: Single;
  LTheta: Single;
  LSinTheta: Single;
  LFactorA: Single;
  LFactorB: Single;
  LTarget: TQuatf;
begin
  LDotProduct := Dot(ATarget);
  LTarget := ATarget;
  // Take the shortest path
  if LDotProduct < 0 then
  begin
    LDotProduct := -LDotProduct;
    LTarget := TQuatf.Create(-ATarget.FX, -ATarget.FY, -ATarget.FZ, -ATarget.FW);
  end;
  // Fall back to Nlerp for very small angles
  if LDotProduct > 0.9995 then
    Exit(Nlerp(LTarget, AT));
  LTheta := ArcCos(LDotProduct);
  LSinTheta := Sin(LTheta);
  LFactorA := Sin((1.0 - AT) * LTheta) / LSinTheta;
  LFactorB := Sin(AT * LTheta) / LSinTheta;
  Result := TQuatf.Create(
    FX * LFactorA + LTarget.FX * LFactorB,
    FY * LFactorA + LTarget.FY * LFactorB,
    FZ * LFactorA + LTarget.FZ * LFactorB,
    FW * LFactorA + LTarget.FW * LFactorB
  );
end;

function TQuatf.Nlerp(const ATarget: TQuatf; const AT: Single): TQuatf;
var
  LInvT: Single;
begin
  LInvT := 1.0 - AT;
  Result := TQuatf.Create(
    FX * LInvT + ATarget.FX * AT,
    FY * LInvT + ATarget.FY * AT,
    FZ * LInvT + ATarget.FZ * AT,
    FW * LInvT + ATarget.FW * AT
  );
  Result := Result.Normalize;
end;

function TQuatf.RotateVec(const AV: TVec3f): TVec3f;
begin
  // q * v * q^-1
  // For unit quaternion, q^-1 = conjugate
  Result := TVec3f.Create(
    (1 - 2 * (FY * FY + FZ * FZ)) * AV.X + 2 * (FX * FY - FW * FZ) * AV.Y + 2 * (FX * FZ + FW * FY) * AV.Z,
    2 * (FX * FY + FW * FZ) * AV.X + (1 - 2 * (FX * FX + FZ * FZ)) * AV.Y + 2 * (FY * FZ - FW * FX) * AV.Z,
    2 * (FX * FZ - FW * FY) * AV.X + 2 * (FY * FZ + FW * FX) * AV.Y + (1 - 2 * (FX * FX + FY * FY)) * AV.Z
  );
end;

operator * (constref A, B: TQuatf): TQuatf;
begin
  Result.FX := A.FW * B.FX + A.FX * B.FW + A.FY * B.FZ - A.FZ * B.FY;
  Result.FY := A.FW * B.FY - A.FX * B.FZ + A.FY * B.FW + A.FZ * B.FX;
  Result.FZ := A.FW * B.FZ + A.FX * B.FY - A.FY * B.FX + A.FZ * B.FW;
  Result.FW := A.FW * B.FW - A.FX * B.FX - A.FY * B.FY - A.FZ * B.FZ;
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

class function TQuatd.FromRotationMatrix(const AM: TMat3d): TQuatd;
var
  LTrace: Double;
  LS: Double;
  LInvS: Double;
begin
  LTrace := AM[0, 0] + AM[1, 1] + AM[2, 2];
  if LTrace > 0 then
  begin
    LS := Sqrt(LTrace + 1.0) * 2.0;
    LInvS := 1.0 / LS;
    Result.FW := 0.25 * LS;
    Result.FX := (AM[2, 1] - AM[1, 2]) * LInvS;
    Result.FY := (AM[0, 2] - AM[2, 0]) * LInvS;
    Result.FZ := (AM[1, 0] - AM[0, 1]) * LInvS;
  end
  else if (AM[0, 0] > AM[1, 1]) and (AM[0, 0] > AM[2, 2]) then
  begin
    LS := Sqrt(1.0 + AM[0, 0] - AM[1, 1] - AM[2, 2]) * 2.0;
    LInvS := 1.0 / LS;
    Result.FW := (AM[2, 1] - AM[1, 2]) * LInvS;
    Result.FX := 0.25 * LS;
    Result.FY := (AM[0, 1] + AM[1, 0]) * LInvS;
    Result.FZ := (AM[0, 2] + AM[2, 0]) * LInvS;
  end
  else if AM[1, 1] > AM[2, 2] then
  begin
    LS := Sqrt(1.0 + AM[1, 1] - AM[0, 0] - AM[2, 2]) * 2.0;
    LInvS := 1.0 / LS;
    Result.FW := (AM[0, 2] - AM[2, 0]) * LInvS;
    Result.FX := (AM[0, 1] + AM[1, 0]) * LInvS;
    Result.FY := 0.25 * LS;
    Result.FZ := (AM[1, 2] + AM[2, 1]) * LInvS;
  end
  else
  begin
    LS := Sqrt(1.0 + AM[2, 2] - AM[0, 0] - AM[1, 1]) * 2.0;
    LInvS := 1.0 / LS;
    Result.FW := (AM[1, 0] - AM[0, 1]) * LInvS;
    Result.FX := (AM[0, 2] + AM[2, 0]) * LInvS;
    Result.FY := (AM[1, 2] + AM[2, 1]) * LInvS;
    Result.FZ := 0.25 * LS;
  end;
  Result := Result.Normalize;
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

function TQuatd.ToRotationMatrix: TMat4d;
begin
  Result := ToMat4d;
end;

function TQuatd.ToRotationMatrix3: TMat3d;
var
  LXX, LYY, LZZ, LXY, LXZ, LYZ, LWX, LWY, LWZ: Double;
begin
  LXX := FX * FX; LYY := FY * FY; LZZ := FZ * FZ;
  LXY := FX * FY; LXZ := FX * FZ; LYZ := FY * FZ;
  LWX := FW * FX; LWY := FW * FY; LWZ := FW * FZ;
  Result := TMat3d.Create(
    1 - 2 * (LYY + LZZ), 2 * (LXY - LWZ), 2 * (LXZ + LWY),
    2 * (LXY + LWZ), 1 - 2 * (LXX + LZZ), 2 * (LYZ - LWX),
    2 * (LXZ - LWY), 2 * (LYZ + LWX), 1 - 2 * (LXX + LYY)
  );
end;

function TQuatd.Slerp(const ATarget: TQuatd; const AT: Double): TQuatd;
var
  LDotProduct: Double;
  LTheta: Double;
  LSinTheta: Double;
  LFactorA: Double;
  LFactorB: Double;
  LTarget: TQuatd;
begin
  LDotProduct := Dot(ATarget);
  LTarget := ATarget;
  // Take the shortest path
  if LDotProduct < 0 then
  begin
    LDotProduct := -LDotProduct;
    LTarget := TQuatd.Create(-ATarget.FX, -ATarget.FY, -ATarget.FZ, -ATarget.FW);
  end;
  // Fall back to Nlerp for very small angles
  if LDotProduct > 0.9995 then
    Exit(Nlerp(LTarget, AT));
  LTheta := ArcCos(LDotProduct);
  LSinTheta := Sin(LTheta);
  LFactorA := Sin((1.0 - AT) * LTheta) / LSinTheta;
  LFactorB := Sin(AT * LTheta) / LSinTheta;
  Result := TQuatd.Create(
    FX * LFactorA + LTarget.FX * LFactorB,
    FY * LFactorA + LTarget.FY * LFactorB,
    FZ * LFactorA + LTarget.FZ * LFactorB,
    FW * LFactorA + LTarget.FW * LFactorB
  );
end;

function TQuatd.Nlerp(const ATarget: TQuatd; const AT: Double): TQuatd;
var
  LInvT: Double;
begin
  LInvT := 1.0 - AT;
  Result := TQuatd.Create(
    FX * LInvT + ATarget.FX * AT,
    FY * LInvT + ATarget.FY * AT,
    FZ * LInvT + ATarget.FZ * AT,
    FW * LInvT + ATarget.FW * AT
  );
  Result := Result.Normalize;
end;

function TQuatd.RotateVec(const AV: TVec3d): TVec3d;
begin
  // q * v * q^-1
  // For unit quaternion, q^-1 = conjugate
  Result := TVec3d.Create(
    (1 - 2 * (FY * FY + FZ * FZ)) * AV.X + 2 * (FX * FY - FW * FZ) * AV.Y + 2 * (FX * FZ + FW * FY) * AV.Z,
    2 * (FX * FY + FW * FZ) * AV.X + (1 - 2 * (FX * FX + FZ * FZ)) * AV.Y + 2 * (FY * FZ - FW * FX) * AV.Z,
    2 * (FX * FZ - FW * FY) * AV.X + 2 * (FY * FZ + FW * FX) * AV.Y + (1 - 2 * (FX * FX + FY * FY)) * AV.Z
  );
end;

operator * (constref A, B: TQuatd): TQuatd;
begin
  Result.FX := A.FW * B.FX + A.FX * B.FW + A.FY * B.FZ - A.FZ * B.FY;
  Result.FY := A.FW * B.FY - A.FX * B.FZ + A.FY * B.FW + A.FZ * B.FX;
  Result.FZ := A.FW * B.FZ + A.FX * B.FY - A.FY * B.FX + A.FZ * B.FW;
  Result.FW := A.FW * B.FW - A.FX * B.FX - A.FY * B.FY - A.FZ * B.FZ;
end;

end.
