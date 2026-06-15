unit nextpas.core.math.vec.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math.scalar;

type
  TVec2f = record
  private
    FData: array[0..1] of Single;
    function GetX: Single; inline;
    procedure SetX(const AValue: Single); inline;
    function GetY: Single; inline;
    procedure SetY(const AValue: Single); inline;
    function GetData(const AIndex: Integer): Single; inline;
    procedure SetData(const AIndex: Integer; const AValue: Single); inline;
  public
    constructor Create(const AX, AY: Single);
    function Length: Single;
    function LengthSqr: Single;
    function Normalize: TVec2f;
    function Dot(const AOther: TVec2f): Single;
    property X: Single read GetX write SetX;
    property Y: Single read GetY write SetY;
    property Data[const AIndex: Integer]: Single read GetData write SetData; default;
  end;

  TVec2d = record
  private
    FData: array[0..1] of Double;
    function GetX: Double; inline;
    procedure SetX(const AValue: Double); inline;
    function GetY: Double; inline;
    procedure SetY(const AValue: Double); inline;
    function GetData(const AIndex: Integer): Double; inline;
    procedure SetData(const AIndex: Integer; const AValue: Double); inline;
  public
    constructor Create(const AX, AY: Double);
    function Length: Double;
    function LengthSqr: Double;
    function Normalize: TVec2d;
    function Dot(const AOther: TVec2d): Double;
    property X: Double read GetX write SetX;
    property Y: Double read GetY write SetY;
    property Data[const AIndex: Integer]: Double read GetData write SetData; default;
  end;

  TVec3f = record
  private
    FData: array[0..2] of Single;
    function GetX: Single; inline;
    procedure SetX(const AValue: Single); inline;
    function GetY: Single; inline;
    procedure SetY(const AValue: Single); inline;
    function GetZ: Single; inline;
    procedure SetZ(const AValue: Single); inline;
    function GetData(const AIndex: Integer): Single; inline;
    procedure SetData(const AIndex: Integer; const AValue: Single); inline;
  public
    constructor Create(const AX, AY, AZ: Single);
    function Length: Single;
    function LengthSqr: Single;
    function Normalize: TVec3f;
    function Dot(const AOther: TVec3f): Single;
    function Cross(const AOther: TVec3f): TVec3f;
    property X: Single read GetX write SetX;
    property Y: Single read GetY write SetY;
    property Z: Single read GetZ write SetZ;
    property Data[const AIndex: Integer]: Single read GetData write SetData; default;
  end;

  TVec3d = record
  private
    FData: array[0..2] of Double;
    function GetX: Double; inline;
    procedure SetX(const AValue: Double); inline;
    function GetY: Double; inline;
    procedure SetY(const AValue: Double); inline;
    function GetZ: Double; inline;
    procedure SetZ(const AValue: Double); inline;
    function GetData(const AIndex: Integer): Double; inline;
    procedure SetData(const AIndex: Integer; const AValue: Double); inline;
  public
    constructor Create(const AX, AY, AZ: Double);
    function Length: Double;
    function LengthSqr: Double;
    function Normalize: TVec3d;
    function Dot(const AOther: TVec3d): Double;
    function Cross(const AOther: TVec3d): TVec3d;
    property X: Double read GetX write SetX;
    property Y: Double read GetY write SetY;
    property Z: Double read GetZ write SetZ;
    property Data[const AIndex: Integer]: Double read GetData write SetData; default;
  end;

  TVec4f = record
  private
    FData: array[0..3] of Single;
    function GetX: Single; inline;
    procedure SetX(const AValue: Single); inline;
    function GetY: Single; inline;
    procedure SetY(const AValue: Single); inline;
    function GetZ: Single; inline;
    procedure SetZ(const AValue: Single); inline;
    function GetW: Single; inline;
    procedure SetW(const AValue: Single); inline;
    function GetData(const AIndex: Integer): Single; inline;
    procedure SetData(const AIndex: Integer; const AValue: Single); inline;
  public
    constructor Create(const AX, AY, AZ, AW: Single);
    function Length: Single;
    function LengthSqr: Single;
    function Normalize: TVec4f;
    function Dot(const AOther: TVec4f): Single;
    property X: Single read GetX write SetX;
    property Y: Single read GetY write SetY;
    property Z: Single read GetZ write SetZ;
    property W: Single read GetW write SetW;
    property Data[const AIndex: Integer]: Single read GetData write SetData; default;
  end;

  TVec4d = record
  private
    FData: array[0..3] of Double;
    function GetX: Double; inline;
    procedure SetX(const AValue: Double); inline;
    function GetY: Double; inline;
    procedure SetY(const AValue: Double); inline;
    function GetZ: Double; inline;
    procedure SetZ(const AValue: Double); inline;
    function GetW: Double; inline;
    procedure SetW(const AValue: Double); inline;
    function GetData(const AIndex: Integer): Double; inline;
    procedure SetData(const AIndex: Integer; const AValue: Double); inline;
  public
    constructor Create(const AX, AY, AZ, AW: Double);
    function Length: Double;
    function LengthSqr: Double;
    function Normalize: TVec4d;
    function Dot(const AOther: TVec4d): Double;
    property X: Double read GetX write SetX;
    property Y: Double read GetY write SetY;
    property Z: Double read GetZ write SetZ;
    property W: Double read GetW write SetW;
    property Data[const AIndex: Integer]: Double read GetData write SetData; default;
  end;

const
  Vec2fZero: TVec2f = (FData: (0, 0));
  Vec2dZero: TVec2d = (FData: (0, 0));
  Vec3fZero: TVec3f = (FData: (0, 0, 0));
  Vec3dZero: TVec3d = (FData: (0, 0, 0));
  Vec4fZero: TVec4f = (FData: (0, 0, 0, 0));
  Vec4dZero: TVec4d = (FData: (0, 0, 0, 0));

implementation

uses
  Math;

{ TVec2f }

constructor TVec2f.Create(const AX, AY: Single);
begin
  FData[0] := AX;
  FData[1] := AY;
end;

function TVec2f.GetX: Single; begin Result := FData[0]; end;
procedure TVec2f.SetX(const AValue: Single); begin FData[0] := AValue; end;
function TVec2f.GetY: Single; begin Result := FData[1]; end;
procedure TVec2f.SetY(const AValue: Single); begin FData[1] := AValue; end;
function TVec2f.GetData(const AIndex: Integer): Single; begin Result := FData[AIndex]; end;
procedure TVec2f.SetData(const AIndex: Integer; const AValue: Single); begin FData[AIndex] := AValue; end;

function TVec2f.Length: Single;
begin
  Result := Sqrt(LengthSqr);
end;

function TVec2f.LengthSqr: Single;
begin
  Result := FData[0] * FData[0] + FData[1] * FData[1];
end;

function TVec2f.Normalize: TVec2f;
var
  LLen: Single;
begin
  LLen := Length;
  if LLen > 0 then
  begin
    Result.FData[0] := FData[0] / LLen;
    Result.FData[1] := FData[1] / LLen;
  end
  else
    Result := Vec2fZero;
end;

function TVec2f.Dot(const AOther: TVec2f): Single;
begin
  Result := FData[0] * AOther.FData[0] + FData[1] * AOther.FData[1];
end;

{ TVec2d }

constructor TVec2d.Create(const AX, AY: Double);
begin
  FData[0] := AX;
  FData[1] := AY;
end;

function TVec2d.GetX: Double; begin Result := FData[0]; end;
procedure TVec2d.SetX(const AValue: Double); begin FData[0] := AValue; end;
function TVec2d.GetY: Double; begin Result := FData[1]; end;
procedure TVec2d.SetY(const AValue: Double); begin FData[1] := AValue; end;
function TVec2d.GetData(const AIndex: Integer): Double; begin Result := FData[AIndex]; end;
procedure TVec2d.SetData(const AIndex: Integer; const AValue: Double); begin FData[AIndex] := AValue; end;

function TVec2d.Length: Double;
begin
  Result := Sqrt(LengthSqr);
end;

function TVec2d.LengthSqr: Double;
begin
  Result := FData[0] * FData[0] + FData[1] * FData[1];
end;

function TVec2d.Normalize: TVec2d;
var
  LLen: Double;
begin
  LLen := Length;
  if LLen > 0 then
  begin
    Result.FData[0] := FData[0] / LLen;
    Result.FData[1] := FData[1] / LLen;
  end
  else
    Result := Vec2dZero;
end;

function TVec2d.Dot(const AOther: TVec2d): Double;
begin
  Result := FData[0] * AOther.FData[0] + FData[1] * AOther.FData[1];
end;

{ TVec3f }

constructor TVec3f.Create(const AX, AY, AZ: Single);
begin
  FData[0] := AX;
  FData[1] := AY;
  FData[2] := AZ;
end;

function TVec3f.GetX: Single; begin Result := FData[0]; end;
procedure TVec3f.SetX(const AValue: Single); begin FData[0] := AValue; end;
function TVec3f.GetY: Single; begin Result := FData[1]; end;
procedure TVec3f.SetY(const AValue: Single); begin FData[1] := AValue; end;
function TVec3f.GetZ: Single; begin Result := FData[2]; end;
procedure TVec3f.SetZ(const AValue: Single); begin FData[2] := AValue; end;
function TVec3f.GetData(const AIndex: Integer): Single; begin Result := FData[AIndex]; end;
procedure TVec3f.SetData(const AIndex: Integer; const AValue: Single); begin FData[AIndex] := AValue; end;

function TVec3f.Length: Single;
begin
  Result := Sqrt(LengthSqr);
end;

function TVec3f.LengthSqr: Single;
begin
  Result := FData[0] * FData[0] + FData[1] * FData[1] + FData[2] * FData[2];
end;

function TVec3f.Normalize: TVec3f;
var
  LLen: Single;
begin
  LLen := Length;
  if LLen > 0 then
  begin
    Result.FData[0] := FData[0] / LLen;
    Result.FData[1] := FData[1] / LLen;
    Result.FData[2] := FData[2] / LLen;
  end
  else
    Result := Vec3fZero;
end;

function TVec3f.Dot(const AOther: TVec3f): Single;
begin
  Result := FData[0] * AOther.FData[0] + FData[1] * AOther.FData[1] + FData[2] * AOther.FData[2];
end;

function TVec3f.Cross(const AOther: TVec3f): TVec3f;
begin
  Result.FData[0] := FData[1] * AOther.FData[2] - FData[2] * AOther.FData[1];
  Result.FData[1] := FData[2] * AOther.FData[0] - FData[0] * AOther.FData[2];
  Result.FData[2] := FData[0] * AOther.FData[1] - FData[1] * AOther.FData[0];
end;

{ TVec3d }

constructor TVec3d.Create(const AX, AY, AZ: Double);
begin
  FData[0] := AX;
  FData[1] := AY;
  FData[2] := AZ;
end;

function TVec3d.GetX: Double; begin Result := FData[0]; end;
procedure TVec3d.SetX(const AValue: Double); begin FData[0] := AValue; end;
function TVec3d.GetY: Double; begin Result := FData[1]; end;
procedure TVec3d.SetY(const AValue: Double); begin FData[1] := AValue; end;
function TVec3d.GetZ: Double; begin Result := FData[2]; end;
procedure TVec3d.SetZ(const AValue: Double); begin FData[2] := AValue; end;
function TVec3d.GetData(const AIndex: Integer): Double; begin Result := FData[AIndex]; end;
procedure TVec3d.SetData(const AIndex: Integer; const AValue: Double); begin FData[AIndex] := AValue; end;

function TVec3d.Length: Double;
begin
  Result := Sqrt(LengthSqr);
end;

function TVec3d.LengthSqr: Double;
begin
  Result := FData[0] * FData[0] + FData[1] * FData[1] + FData[2] * FData[2];
end;

function TVec3d.Normalize: TVec3d;
var
  LLen: Double;
begin
  LLen := Length;
  if LLen > 0 then
  begin
    Result.FData[0] := FData[0] / LLen;
    Result.FData[1] := FData[1] / LLen;
    Result.FData[2] := FData[2] / LLen;
  end
  else
    Result := Vec3dZero;
end;

function TVec3d.Dot(const AOther: TVec3d): Double;
begin
  Result := FData[0] * AOther.FData[0] + FData[1] * AOther.FData[1] + FData[2] * AOther.FData[2];
end;

function TVec3d.Cross(const AOther: TVec3d): TVec3d;
begin
  Result.FData[0] := FData[1] * AOther.FData[2] - FData[2] * AOther.FData[1];
  Result.FData[1] := FData[2] * AOther.FData[0] - FData[0] * AOther.FData[2];
  Result.FData[2] := FData[0] * AOther.FData[1] - FData[1] * AOther.FData[0];
end;

{ TVec4f }

constructor TVec4f.Create(const AX, AY, AZ, AW: Single);
begin
  FData[0] := AX;
  FData[1] := AY;
  FData[2] := AZ;
  FData[3] := AW;
end;

function TVec4f.GetX: Single; begin Result := FData[0]; end;
procedure TVec4f.SetX(const AValue: Single); begin FData[0] := AValue; end;
function TVec4f.GetY: Single; begin Result := FData[1]; end;
procedure TVec4f.SetY(const AValue: Single); begin FData[1] := AValue; end;
function TVec4f.GetZ: Single; begin Result := FData[2]; end;
procedure TVec4f.SetZ(const AValue: Single); begin FData[2] := AValue; end;
function TVec4f.GetW: Single; begin Result := FData[3]; end;
procedure TVec4f.SetW(const AValue: Single); begin FData[3] := AValue; end;
function TVec4f.GetData(const AIndex: Integer): Single; begin Result := FData[AIndex]; end;
procedure TVec4f.SetData(const AIndex: Integer; const AValue: Single); begin FData[AIndex] := AValue; end;

function TVec4f.Length: Single;
begin
  Result := Sqrt(LengthSqr);
end;

function TVec4f.LengthSqr: Single;
begin
  Result := FData[0] * FData[0] + FData[1] * FData[1] + FData[2] * FData[2] + FData[3] * FData[3];
end;

function TVec4f.Normalize: TVec4f;
var
  LLen: Single;
begin
  LLen := Length;
  if LLen > 0 then
  begin
    Result.FData[0] := FData[0] / LLen;
    Result.FData[1] := FData[1] / LLen;
    Result.FData[2] := FData[2] / LLen;
    Result.FData[3] := FData[3] / LLen;
  end
  else
    Result := Vec4fZero;
end;

function TVec4f.Dot(const AOther: TVec4f): Single;
begin
  Result := FData[0] * AOther.FData[0] + FData[1] * AOther.FData[1]
          + FData[2] * AOther.FData[2] + FData[3] * AOther.FData[3];
end;

{ TVec4d }

constructor TVec4d.Create(const AX, AY, AZ, AW: Double);
begin
  FData[0] := AX;
  FData[1] := AY;
  FData[2] := AZ;
  FData[3] := AW;
end;

function TVec4d.GetX: Double; begin Result := FData[0]; end;
procedure TVec4d.SetX(const AValue: Double); begin FData[0] := AValue; end;
function TVec4d.GetY: Double; begin Result := FData[1]; end;
procedure TVec4d.SetY(const AValue: Double); begin FData[1] := AValue; end;
function TVec4d.GetZ: Double; begin Result := FData[2]; end;
procedure TVec4d.SetZ(const AValue: Double); begin FData[2] := AValue; end;
function TVec4d.GetW: Double; begin Result := FData[3]; end;
procedure TVec4d.SetW(const AValue: Double); begin FData[3] := AValue; end;
function TVec4d.GetData(const AIndex: Integer): Double; begin Result := FData[AIndex]; end;
procedure TVec4d.SetData(const AIndex: Integer; const AValue: Double); begin FData[AIndex] := AValue; end;

function TVec4d.Length: Double;
begin
  Result := Sqrt(LengthSqr);
end;

function TVec4d.LengthSqr: Double;
begin
  Result := FData[0] * FData[0] + FData[1] * FData[1] + FData[2] * FData[2] + FData[3] * FData[3];
end;

function TVec4d.Normalize: TVec4d;
var
  LLen: Double;
begin
  LLen := Length;
  if LLen > 0 then
  begin
    Result.FData[0] := FData[0] / LLen;
    Result.FData[1] := FData[1] / LLen;
    Result.FData[2] := FData[2] / LLen;
    Result.FData[3] := FData[3] / LLen;
  end
  else
    Result := Vec4dZero;
end;

function TVec4d.Dot(const AOther: TVec4d): Double;
begin
  Result := FData[0] * AOther.FData[0] + FData[1] * AOther.FData[1]
          + FData[2] * AOther.FData[2] + FData[3] * AOther.FData[3];
end;

end.
