program test_quat;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.math.quat.base,
  nextpas.core.math.quat,
  nextpas.core.math.vec.base,
  nextpas.core.math.mat.base;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACond: Boolean);
begin
  if ACond then begin Inc(GPass); WriteLn('  PASS: ', AName); end
  else begin Inc(GFail); WriteLn('  FAIL: ', AName); end;
end;

procedure CheckFloat(const AName: string; AExpected, AActual, AEps: Double);
var
  LDelta: Double;
begin
  LDelta := AExpected - AActual;
  if LDelta < 0 then LDelta := -LDelta;
  Check(AName, LDelta < AEps);
end;

procedure TestQuatfCreateAndIdentity;
var
  Q: TQuatf;
begin
  WriteLn('--- Quatf Create and Identity ---');
  Q := Quatf(1, 2, 3, 4);
  Check('Quatf Create X', Q.X = 1.0);
  Check('Quatf Create Y', Q.Y = 2.0);
  Check('Quatf Create Z', Q.Z = 3.0);
  Check('Quatf Create W', Q.W = 4.0);

  Q := QuatfIdentity;
  Check('Quatf Identity X', Q.X = 0.0);
  Check('Quatf Identity Y', Q.Y = 0.0);
  Check('Quatf Identity Z', Q.Z = 0.0);
  Check('Quatf Identity W', Q.W = 1.0);
end;

procedure TestQuatfNormalize;
var
  Q: TQuatf;
begin
  WriteLn('--- Quatf Normalize ---');
  Q := Quatf(2, 0, 0, 0).Normalize;
  CheckFloat('Quatf Normalize length', 1.0, Q.Length, 1e-6);
  Check('Quatf Normalize X', Q.X = 1.0);
  Check('Quatf Normalize W', Q.W = 0.0);
end;

procedure TestQuatfConjugate;
var
  Q: TQuatf;
begin
  WriteLn('--- Quatf Conjugate ---');
  Q := Quatf(1, 2, 3, 4).Conjugate;
  Check('Quatf Conjugate X', Q.X = -1.0);
  Check('Quatf Conjugate Y', Q.Y = -2.0);
  Check('Quatf Conjugate Z', Q.Z = -3.0);
  Check('Quatf Conjugate W', Q.W = 4.0);
end;

procedure TestQuatfFromAxisAngle;
var
  Q: TQuatf;
begin
  WriteLn('--- Quatf FromAxisAngle ---');
  // 90 degrees around Z axis
  Q := TQuatf.FromAxisAngle(TVec3f.Create(0, 0, 1), 90.0 * 3.14159265 / 180.0);
  Q := Q.Normalize;
  CheckFloat('Quatf AxisAngle Z90 W', 0.7071068, Q.W, 1e-5);
  CheckFloat('Quatf AxisAngle Z90 Z', 0.7071068, Q.Z, 1e-5);
end;

procedure TestQuatfRotateVec;
var
  Q: TQuatf;
  V: TVec3f;
begin
  WriteLn('--- Quatf RotateVec ---');
  // 90 degrees around Z axis: (1,0,0) -> (0,1,0)
  Q := TQuatf.FromAxisAngle(TVec3f.Create(0, 0, 1), 90.0 * 3.14159265 / 180.0);
  Q := Q.Normalize;
  V := Q.RotateVec(TVec3f.Create(1, 0, 0));
  CheckFloat('Quatf RotateVec X->Y: X', 0.0, V.X, 1e-5);
  CheckFloat('Quatf RotateVec X->Y: Y', 1.0, V.Y, 1e-5);
  CheckFloat('Quatf RotateVec X->Y: Z', 0.0, V.Z, 1e-5);
end;

procedure TestQuatfToMat4;
var
  Q: TQuatf;
  M: TMat4f;
begin
  WriteLn('--- Quatf ToMat4f ---');
  Q := QuatfIdentity;
  M := Q.ToMat4f;
  Check('Quatf Identity->Mat4 [0,0]', M[0,0] = 1.0);
  Check('Quatf Identity->Mat4 [1,1]', M[1,1] = 1.0);
  Check('Quatf Identity->Mat4 [3,3]', M[3,3] = 1.0);
  Check('Quatf Identity->Mat4 [0,1]', M[0,1] = 0.0);
end;

procedure TestQuatdCreateAndIdentity;
var
  Q: TQuatd;
begin
  WriteLn('--- Quatd Create and Identity ---');
  Q := QuatdIdentity;
  Check('Quatd Identity X', Q.X = 0.0);
  Check('Quatd Identity Y', Q.Y = 0.0);
  Check('Quatd Identity Z', Q.Z = 0.0);
  Check('Quatd Identity W', Q.W = 1.0);
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== nextpas.core.math.quat tests ===');
  WriteLn;

  TestQuatfCreateAndIdentity;
  TestQuatfNormalize;
  TestQuatfConjugate;
  TestQuatfFromAxisAngle;
  TestQuatfRotateVec;
  TestQuatfToMat4;
  TestQuatdCreateAndIdentity;

  WriteLn;
  WriteLn('=== Results: ', GPass, ' passed, ', GFail, ' failed ===');
  if GFail > 0 then Halt(1);
end.
