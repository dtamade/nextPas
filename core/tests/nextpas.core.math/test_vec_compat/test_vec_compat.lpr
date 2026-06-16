program test_vec_compat;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.math.vec.compat,
  nextpas.core.math.vec.base,
  nextpas.core.math.vec,
  nextpas.core.math.mat.base,
  nextpas.core.math.quat.base;

{ Type compatibility tests — verify aliases resolve to correct types }

procedure TestVector2Alias;
var
  LV: TVector2;
begin
  LV := Vector2(1.0, 2.0);
  Assert(LV.X = 1.0, 'TVector2 alias X');
  Assert(LV.Y = 2.0, 'TVector2 alias Y');
end;

procedure TestVector3Alias;
var
  LV: TVector3;
begin
  LV := Vector3(1.0, 2.0, 3.0);
  Assert(LV.X = 1.0, 'TVector3 alias X');
  Assert(LV.Y = 2.0, 'TVector3 alias Y');
  Assert(LV.Z = 3.0, 'TVector3 alias Z');
end;

procedure TestVector3FromVec2;
var
  LV2: TVector2;
  LV3: TVector3;
begin
  LV2 := Vector2(10.0, 20.0);
  LV3 := Vector3(LV2, 30.0);
  Assert(LV3.X = 10.0, 'TVector3 from Vec2 X');
  Assert(LV3.Y = 20.0, 'TVector3 from Vec2 Y');
  Assert(LV3.Z = 30.0, 'TVector3 from Vec2 Z');
end;

procedure TestVector4Alias;
var
  LV: TVector4;
begin
  LV := Vector4(1.0, 2.0, 3.0, 4.0);
  Assert(LV.X = 1.0, 'TVector4 alias X');
  Assert(LV.Y = 2.0, 'TVector4 alias Y');
  Assert(LV.Z = 3.0, 'TVector4 alias Z');
  Assert(LV.W = 4.0, 'TVector4 alias W');
end;

procedure TestVector4FromVec3;
var
  LV3: TVector3;
  LV4: TVector4;
begin
  LV3 := Vector3(1.0, 2.0, 3.0);
  LV4 := Vector4(LV3, 4.0);
  Assert(LV4.X = 1.0, 'TVector4 from Vec3 X');
  Assert(LV4.Y = 2.0, 'TVector4 from Vec3 Y');
  Assert(LV4.Z = 3.0, 'TVector4 from Vec3 Z');
  Assert(LV4.W = 4.0, 'TVector4 from Vec3 W');
end;

procedure TestVector4FromVec2;
var
  LV2: TVector2;
  LV4: TVector4;
begin
  LV2 := Vector2(10.0, 20.0);
  LV4 := Vector4(LV2, 30.0, 40.0);
  Assert(LV4.X = 10.0, 'TVector4 from Vec2 X');
  Assert(LV4.Y = 20.0, 'TVector4 from Vec2 Y');
  Assert(LV4.Z = 30.0, 'TVector4 from Vec2 Z');
  Assert(LV4.W = 40.0, 'TVector4 from Vec2 W');
end;

{ Double-precision alias tests }

procedure TestVector2DoubleAlias;
var
  LV: TVector2Double;
begin
  LV := TVec2d.Create(1.5, 2.5);
  Assert(LV.X = 1.5, 'TVector2Double alias X');
  Assert(LV.Y = 2.5, 'TVector2Double alias Y');
end;

procedure TestVector3DoubleAlias;
var
  LV: TVector3Double;
begin
  LV := TVec3d.Create(1.5, 2.5, 3.5);
  Assert(LV.X = 1.5, 'TVector3Double alias X');
  Assert(LV.Y = 2.5, 'TVector3Double alias Y');
  Assert(LV.Z = 3.5, 'TVector3Double alias Z');
end;

{ Matrix alias tests — compile-time check only (types must resolve) }

procedure TestMatrixAliases;
var
  LM3: TMatrix3;
  LM4: TMatrix4;
  LM3d: TMatrix3Double;
  LM4d: TMatrix4Double;
begin
  LM3 := TMat3f.Create(1, 0, 0, 0, 1, 0, 0, 0, 1);
  Assert(LM3.Data[0, 0] = 1.0, 'TMatrix3 alias identity');

  LM4 := TMat4f.Create(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
  Assert(LM4.Data[0, 0] = 1.0, 'TMatrix4 alias identity');

  LM3d := TMat3d.Create(1, 0, 0, 0, 1, 0, 0, 0, 1);
  Assert(LM3d.Data[0, 0] = 1.0, 'TMatrix3Double alias identity');

  LM4d := TMat4d.Create(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
  Assert(LM4d.Data[0, 0] = 1.0, 'TMatrix4Double alias identity');
end;

{ Quaternion alias test }

procedure TestQuaternionAlias;
var
  LQ: TQuaternion;
begin
  LQ := TQuatf.Create(0.0, 0.0, 0.0, 1.0);
  Assert(LQ.X = 0.0, 'TQuaternion alias X');
  Assert(LQ.Y = 0.0, 'TQuaternion alias Y');
  Assert(LQ.Z = 0.0, 'TQuaternion alias Z');
  Assert(LQ.W = 1.0, 'TQuaternion alias W');
end;

procedure TestQuaternionDoubleAlias;
var
  LQ: TQuaternionDouble;
begin
  LQ := TQuatd.Create(0.0, 0.0, 0.0, 1.0);
  Assert(LQ.X = 0.0, 'TQuaternionDouble alias X');
  Assert(LQ.W = 1.0, 'TQuaternionDouble alias W');
end;

{ Interop test — pass compat types to nextpas functions }

procedure TestInteropWithNextpas;
var
  LV: TVector3;
  LLen: Single;
begin
  LV := Vector3(3.0, 4.0, 0.0);
  LLen := LV.Length;
  Assert(Abs(LLen - 5.0) < 1e-6, 'TVector3 interop Length');
end;

begin
  WriteLn('--- nextpas.core.math.vec.compat ---');

  TestVector2Alias;
  WriteLn('  PASS: TVector2 alias');

  TestVector3Alias;
  WriteLn('  PASS: TVector3 alias');

  TestVector3FromVec2;
  WriteLn('  PASS: TVector3 from Vec2');

  TestVector4Alias;
  WriteLn('  PASS: TVector4 alias');

  TestVector4FromVec3;
  WriteLn('  PASS: TVector4 from Vec3');

  TestVector4FromVec2;
  WriteLn('  PASS: TVector4 from Vec2');

  TestVector2DoubleAlias;
  WriteLn('  PASS: TVector2Double alias');

  TestVector3DoubleAlias;
  WriteLn('  PASS: TVector3Double alias');

  TestMatrixAliases;
  WriteLn('  PASS: TMatrix3/4 aliases');

  TestQuaternionAlias;
  WriteLn('  PASS: TQuaternion alias');

  TestQuaternionDoubleAlias;
  WriteLn('  PASS: TQuaternionDouble alias');

  TestInteropWithNextpas;
  WriteLn('  PASS: interop with nextpas methods');

  WriteLn('--- nextpas.core.math.vec.compat: 12 total, 12 passed, 0 failed ---');
end.
