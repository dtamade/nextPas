program test_vec;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.math.vec,
  nextpas.core.math.vec.base;

procedure TestVec2fCreate;
var
  V: TVec2f;
begin
  V := TVec2f.Create(1.0, 2.0);
  Assert(V.X = 1.0, 'Vec2f X');
  Assert(V.Y = 2.0, 'Vec2f Y');
end;

procedure TestVec2fZero;
var
  V: TVec2f;
begin
  V := Vec2fZero;
  Assert(V.X = 0.0, 'Vec2fZero X');
  Assert(V.Y = 0.0, 'Vec2fZero Y');
end;

procedure TestVec2fLength;
var
  V: TVec2f;
  LLen: Single;
begin
  V := TVec2f.Create(3.0, 4.0);
  LLen := V.Length;
  Assert(Abs(LLen - 5.0) < 0.0001, 'Vec2f Length');
end;

procedure TestVec2fNormalize;
var
  V: TVec2f;
begin
  V := TVec2f.Create(3.0, 4.0);
  V := V.Normalize;
  Assert(Abs(V.Length - 1.0) < 0.0001, 'Vec2f Normalize length');
end;

procedure TestVec2fDot;
var
  A, B: TVec2f;
  LDot: Single;
begin
  A := TVec2f.Create(1.0, 0.0);
  B := TVec2f.Create(0.0, 1.0);
  LDot := A.Dot(B);
  Assert(LDot = 0.0, 'Vec2f Dot orthogonal');
end;

procedure TestVec3fCross;
var
  A, B, C: TVec3f;
begin
  A := TVec3f.Create(1.0, 0.0, 0.0);
  B := TVec3f.Create(0.0, 1.0, 0.0);
  C := A.Cross(B);
  Assert(C.X = 0.0, 'Vec3f Cross X');
  Assert(C.Y = 0.0, 'Vec3f Cross Y');
  Assert(C.Z = 1.0, 'Vec3f Cross Z');
end;

procedure TestVec2dCreate;
var
  V: TVec2d;
begin
  V := TVec2d.Create(1.0, 2.0);
  Assert(V.X = 1.0, 'Vec2d X');
  Assert(V.Y = 2.0, 'Vec2d Y');
end;

procedure TestVec4fCreate;
var
  V: TVec4f;
begin
  V := TVec4f.Create(1.0, 2.0, 3.0, 4.0);
  Assert(V.X = 1.0, 'Vec4f X');
  Assert(V.Y = 2.0, 'Vec4f Y');
  Assert(V.Z = 3.0, 'Vec4f Z');
  Assert(V.W = 4.0, 'Vec4f W');
end;

procedure TestVecFreeConstructor;
var
  V: TVec2f;
begin
  V := Vec2f(1.0, 2.0);
  Assert(V.X = 1.0, 'Vec2f() X');
  Assert(V.Y = 2.0, 'Vec2f() Y');
end;

procedure TestVecZeroFreeFunctions;
var
  V2f: TVec2f;
  V3d: TVec3d;
begin
  V2f := Vec2fZero;
  Assert((V2f.X = 0.0) and (V2f.Y = 0.0), 'Vec2fZero fn');
  V3d := Vec3dZero;
  Assert((V3d.X = 0.0) and (V3d.Y = 0.0) and (V3d.Z = 0.0), 'Vec3dZero fn');
end;

procedure TestVecDefaultProperty;
var
  V: TVec2f;
begin
  V := TVec2f.Create(5.0, 10.0);
  Assert(V[0] = 5.0, 'Vec2f Data[0]');
  Assert(V[1] = 10.0, 'Vec2f Data[1]');
end;

begin
  TestVec2fCreate;
  TestVec2fZero;
  TestVec2fLength;
  TestVec2fNormalize;
  TestVec2fDot;
  TestVec3fCross;
  TestVec2dCreate;
  TestVec4fCreate;
  TestVecFreeConstructor;
  TestVecZeroFreeFunctions;
  TestVecDefaultProperty;
  WriteLn('All vec tests passed.');
end.
