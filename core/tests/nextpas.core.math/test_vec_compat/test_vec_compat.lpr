program test_vec_compat;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.math.vec.compat,
  nextpas.core.math.vec.base,
  nextpas.core.math.vec,
  nextpas.core.math.mat.base,
  nextpas.core.math.quat.base,
  nextpas.core.test;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('vec_compat');

  LSuite.Test('TVector2 alias', procedure
  var LV: TVector2;
  begin
    LV := Vector2(1.0, 2.0);
    CheckTrue(Abs(LV.X - 1.0) < 1e-6);
    CheckTrue(Abs(LV.Y - 2.0) < 1e-6);
  end);

  LSuite.Test('TVector3 alias', procedure
  var LV: TVector3;
  begin
    LV := Vector3(1.0, 2.0, 3.0);
    CheckTrue(Abs(LV.X - 1.0) < 1e-6);
    CheckTrue(Abs(LV.Y - 2.0) < 1e-6);
    CheckTrue(Abs(LV.Z - 3.0) < 1e-6);
  end);

  LSuite.Test('TVector3 from Vec2', procedure
  var LV2: TVector2; LV3: TVector3;
  begin
    LV2 := Vector2(10.0, 20.0);
    LV3 := Vector3(LV2, 30.0);
    CheckTrue(Abs(LV3.X - 10.0) < 1e-6);
    CheckTrue(Abs(LV3.Y - 20.0) < 1e-6);
    CheckTrue(Abs(LV3.Z - 30.0) < 1e-6);
  end);

  LSuite.Test('TVector4 alias', procedure
  var LV: TVector4;
  begin
    LV := Vector4(1.0, 2.0, 3.0, 4.0);
    CheckTrue(Abs(LV.X - 1.0) < 1e-6);
    CheckTrue(Abs(LV.Y - 2.0) < 1e-6);
    CheckTrue(Abs(LV.Z - 3.0) < 1e-6);
    CheckTrue(Abs(LV.W - 4.0) < 1e-6);
  end);

  LSuite.Test('TVector4 from Vec3', procedure
  var LV3: TVector3; LV4: TVector4;
  begin
    LV3 := Vector3(1.0, 2.0, 3.0);
    LV4 := Vector4(LV3, 4.0);
    CheckTrue(Abs(LV4.X - 1.0) < 1e-6);
    CheckTrue(Abs(LV4.Y - 2.0) < 1e-6);
    CheckTrue(Abs(LV4.Z - 3.0) < 1e-6);
    CheckTrue(Abs(LV4.W - 4.0) < 1e-6);
  end);

  LSuite.Test('TVector4 from Vec2', procedure
  var LV2: TVector2; LV4: TVector4;
  begin
    LV2 := Vector2(10.0, 20.0);
    LV4 := Vector4(LV2, 30.0, 40.0);
    CheckTrue(Abs(LV4.X - 10.0) < 1e-6);
    CheckTrue(Abs(LV4.Y - 20.0) < 1e-6);
    CheckTrue(Abs(LV4.Z - 30.0) < 1e-6);
    CheckTrue(Abs(LV4.W - 40.0) < 1e-6);
  end);

  LSuite.Test('TVector2Double alias', procedure
  var LV: TVector2Double;
  begin
    LV := TVec2d.Create(1.5, 2.5);
    CheckTrue(Abs(LV.X - 1.5) < 1e-12);
    CheckTrue(Abs(LV.Y - 2.5) < 1e-12);
  end);

  LSuite.Test('TVector3Double alias', procedure
  var LV: TVector3Double;
  begin
    LV := TVec3d.Create(1.5, 2.5, 3.5);
    CheckTrue(Abs(LV.X - 1.5) < 1e-12);
    CheckTrue(Abs(LV.Y - 2.5) < 1e-12);
    CheckTrue(Abs(LV.Z - 3.5) < 1e-12);
  end);

  LSuite.Test('matrix aliases', procedure
  var LM3: TMatrix3; LM4: TMatrix4; LM3d: TMatrix3Double; LM4d: TMatrix4Double;
  begin
    LM3 := TMat3f.Create(1, 0, 0, 0, 1, 0, 0, 0, 1);
    CheckTrue(Abs(LM3.Data[0, 0] - 1.0) < 1e-6);
    LM4 := TMat4f.Create(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
    CheckTrue(Abs(LM4.Data[0, 0] - 1.0) < 1e-6);
    LM3d := TMat3d.Create(1, 0, 0, 0, 1, 0, 0, 0, 1);
    CheckTrue(Abs(LM3d.Data[0, 0] - 1.0) < 1e-12);
    LM4d := TMat4d.Create(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
    CheckTrue(Abs(LM4d.Data[0, 0] - 1.0) < 1e-12);
  end);

  LSuite.Test('TQuaternion alias', procedure
  var LQ: TQuaternion;
  begin
    LQ := TQuatf.Create(0.0, 0.0, 0.0, 1.0);
    CheckTrue(Abs(LQ.X) < 1e-6);
    CheckTrue(Abs(LQ.Y) < 1e-6);
    CheckTrue(Abs(LQ.Z) < 1e-6);
    CheckTrue(Abs(LQ.W - 1.0) < 1e-6);
  end);

  LSuite.Test('TQuaternionDouble alias', procedure
  var LQ: TQuaternionDouble;
  begin
    LQ := TQuatd.Create(0.0, 0.0, 0.0, 1.0);
    CheckTrue(Abs(LQ.X) < 1e-12);
    CheckTrue(Abs(LQ.W - 1.0) < 1e-12);
  end);

  LSuite.Test('interop with nextpas methods', procedure
  var LV: TVector3; LLen: Single;
  begin
    LV := Vector3(3.0, 4.0, 0.0);
    LLen := LV.Length;
    CheckTrue(Abs(LLen - 5.0) < 1e-6);
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.math.vec.compat');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
