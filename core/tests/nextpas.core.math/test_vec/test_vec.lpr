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

procedure TestVec2fAdd;
var
  A, B, C: TVec2f;
begin
  A := TVec2f.Create(1.0, 2.0);
  B := TVec2f.Create(3.0, 4.0);
  C := A + B;
  Assert(C.X = 4.0, 'Vec2f Add X');
  Assert(C.Y = 6.0, 'Vec2f Add Y');
end;

procedure TestVec2fSub;
var
  A, B, C: TVec2f;
begin
  A := TVec2f.Create(5.0, 7.0);
  B := TVec2f.Create(2.0, 3.0);
  C := A - B;
  Assert(C.X = 3.0, 'Vec2f Sub X');
  Assert(C.Y = 4.0, 'Vec2f Sub Y');
end;

procedure TestVec2fNegate;
var
  A, B: TVec2f;
begin
  A := TVec2f.Create(1.0, 2.0);
  B := -A;
  Assert(B.X = -1.0, 'Vec2f Negate X');
  Assert(B.Y = -2.0, 'Vec2f Negate Y');
end;

procedure TestVec2fScalarMul;
var
  A, B, C: TVec2f;
begin
  A := TVec2f.Create(2.0, 3.0);
  B := A * 2.0;
  C := 2.0 * A;
  Assert(B.X = 4.0, 'Vec2f ScalarMul vec*scalar X');
  Assert(B.Y = 6.0, 'Vec2f ScalarMul vec*scalar Y');
  Assert(C.X = 4.0, 'Vec2f ScalarMul scalar*vec X');
  Assert(C.Y = 6.0, 'Vec2f ScalarMul scalar*vec Y');
end;

procedure TestVec2fScalarDiv;
var
  A, B: TVec2f;
begin
  A := TVec2f.Create(4.0, 6.0);
  B := A / 2.0;
  Assert(B.X = 2.0, 'Vec2f ScalarDiv X');
  Assert(B.Y = 3.0, 'Vec2f ScalarDiv Y');
end;

procedure TestVec2fEqual;
var
  A, B, C: TVec2f;
begin
  A := TVec2f.Create(1.0, 2.0);
  B := TVec2f.Create(1.0, 2.0);
  C := TVec2f.Create(3.0, 4.0);
  Assert(A = B, 'Vec2f Equal true');
  Assert(not (A = C), 'Vec2f Equal false');
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

procedure TestVec3fAdd;
var
  A, B, C: TVec3f;
begin
  A := TVec3f.Create(1.0, 2.0, 3.0);
  B := TVec3f.Create(4.0, 5.0, 6.0);
  C := A + B;
  Assert(C.X = 5.0, 'Vec3f Add X');
  Assert(C.Y = 7.0, 'Vec3f Add Y');
  Assert(C.Z = 9.0, 'Vec3f Add Z');
end;

procedure TestVec3fNegate;
var
  A, B: TVec3f;
begin
  A := TVec3f.Create(1.0, 2.0, 3.0);
  B := -A;
  Assert(B.X = -1.0, 'Vec3f Negate X');
  Assert(B.Y = -2.0, 'Vec3f Negate Y');
  Assert(B.Z = -3.0, 'Vec3f Negate Z');
end;

procedure TestVec2dCreate;
var
  V: TVec2d;
begin
  V := TVec2d.Create(1.0, 2.0);
  Assert(V.X = 1.0, 'Vec2d X');
  Assert(V.Y = 2.0, 'Vec2d Y');
end;

procedure TestVec2dAdd;
var
  A, B, C: TVec2d;
begin
  A := TVec2d.Create(1.0, 2.0);
  B := TVec2d.Create(3.0, 4.0);
  C := A + B;
  Assert(C.X = 4.0, 'Vec2d Add X');
  Assert(C.Y = 6.0, 'Vec2d Add Y');
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

procedure TestVec4fAdd;
var
  A, B, C: TVec4f;
begin
  A := TVec4f.Create(1.0, 2.0, 3.0, 4.0);
  B := TVec4f.Create(5.0, 6.0, 7.0, 8.0);
  C := A + B;
  Assert(C.X = 6.0, 'Vec4f Add X');
  Assert(C.Y = 8.0, 'Vec4f Add Y');
  Assert(C.Z = 10.0, 'Vec4f Add Z');
  Assert(C.W = 12.0, 'Vec4f Add W');
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

{ Distance tests }

procedure TestDistance2f;
var
  A, B: TVec2f;
begin
  A := TVec2f.Create(0.0, 0.0);
  B := TVec2f.Create(3.0, 4.0);
  Assert(Abs(Distance(A, B) - 5.0) < 0.0001, 'Distance2f 3-4-5');
end;

procedure TestDistance3f;
var
  A, B: TVec3f;
begin
  A := TVec3f.Create(1.0, 2.0, 3.0);
  B := TVec3f.Create(1.0, 2.0, 3.0);
  Assert(Abs(Distance(A, B)) < 0.0001, 'Distance3f same point');
end;

procedure TestDistance4d;
var
  A, B: TVec4d;
begin
  A := TVec4d.Create(0.0, 0.0, 0.0, 0.0);
  B := TVec4d.Create(1.0, 0.0, 0.0, 0.0);
  Assert(Abs(Distance(A, B) - 1.0) < 0.00001, 'Distance4d unit');
end;

{ Lerp tests }

procedure TestLerp2f;
var
  A, B, C: TVec2f;
begin
  A := TVec2f.Create(0.0, 0.0);
  B := TVec2f.Create(10.0, 20.0);
  C := Lerp(A, B, 0.5);
  Assert(Abs(C.X - 5.0) < 0.0001, 'Lerp2f X midpoint');
  Assert(Abs(C.Y - 10.0) < 0.0001, 'Lerp2f Y midpoint');
  C := Lerp(A, B, 0.0);
  Assert(Abs(C.X) < 0.0001, 'Lerp2f t=0');
  C := Lerp(A, B, 1.0);
  Assert(Abs(C.X - 10.0) < 0.0001, 'Lerp2f t=1');
end;

procedure TestLerp3d;
var
  A, B, C: TVec3d;
begin
  A := TVec3d.Create(0.0, 0.0, 0.0);
  B := TVec3d.Create(1.0, 1.0, 1.0);
  C := Lerp(A, B, 0.25);
  Assert(Abs(C.X - 0.25) < 0.00001, 'Lerp3d X');
  Assert(Abs(C.Y - 0.25) < 0.00001, 'Lerp3d Y');
  Assert(Abs(C.Z - 0.25) < 0.00001, 'Lerp3d Z');
end;

{ Reflect tests }

procedure TestReflect3f;
var
  LIncident, LNormal, LResult: TVec3f;
begin
  LIncident := TVec3f.Create(1.0, -1.0, 0.0);
  LNormal := TVec3f.Create(0.0, 1.0, 0.0);
  LResult := Reflect(LIncident, LNormal);
  Assert(Abs(LResult.X - 1.0) < 0.0001, 'Reflect3f X');
  Assert(Abs(LResult.Y - 1.0) < 0.0001, 'Reflect3f Y');
  Assert(Abs(LResult.Z) < 0.0001, 'Reflect3f Z');
end;

procedure TestReflect2d;
var
  LIncident, LNormal, LResult: TVec2d;
begin
  LIncident := TVec2d.Create(1.0, -1.0);
  LNormal := TVec2d.Create(0.0, 1.0);
  LResult := Reflect(LIncident, LNormal);
  Assert(Abs(LResult.X - 1.0) < 0.00001, 'Reflect2d X');
  Assert(Abs(LResult.Y - 1.0) < 0.00001, 'Reflect2d Y');
end;

{ Project tests }

procedure TestProject3f;
var
  A, B, LResult: TVec3f;
begin
  A := TVec3f.Create(3.0, 4.0, 0.0);
  B := TVec3f.Create(1.0, 0.0, 0.0);
  LResult := Project(A, B);
  Assert(Abs(LResult.X - 3.0) < 0.0001, 'Project3f X');
  Assert(Abs(LResult.Y) < 0.0001, 'Project3f Y');
  Assert(Abs(LResult.Z) < 0.0001, 'Project3f Z');
end;

procedure TestProject4f;
var
  A, B, LResult: TVec4f;
begin
  A := TVec4f.Create(1.0, 2.0, 0.0, 0.0);
  B := TVec4f.Create(1.0, 1.0, 0.0, 0.0);
  LResult := Project(A, B);
  Assert(Abs(LResult.X - 1.5) < 0.0001, 'Project4f X');
  Assert(Abs(LResult.Y - 1.5) < 0.0001, 'Project4f Y');
end;

{ AngleBetween tests }

procedure TestAngleBetween2f;
var
  A, B: TVec2f;
  LAngle: Single;
begin
  A := TVec2f.Create(1.0, 0.0);
  B := TVec2f.Create(0.0, 1.0);
  LAngle := AngleBetween(A, B);
  Assert(Abs(LAngle - 1.5708) < 0.01, 'AngleBetween2f 90deg');
end;

procedure TestAngleBetween3f;
var
  A, B: TVec3f;
  LAngle: Single;
begin
  A := TVec3f.Create(1.0, 0.0, 0.0);
  B := TVec3f.Create(1.0, 0.0, 0.0);
  LAngle := AngleBetween(A, B);
  Assert(Abs(LAngle) < 0.0001, 'AngleBetween3f same dir');
end;

begin
  TestVec2fCreate;
  TestVec2fZero;
  TestVec2fLength;
  TestVec2fNormalize;
  TestVec2fDot;
  TestVec2fAdd;
  TestVec2fSub;
  TestVec2fNegate;
  TestVec2fScalarMul;
  TestVec2fScalarDiv;
  TestVec2fEqual;
  TestVec3fCross;
  TestVec3fAdd;
  TestVec3fNegate;
  TestVec2dCreate;
  TestVec2dAdd;
  TestVec4fCreate;
  TestVec4fAdd;
  TestVecFreeConstructor;
  TestVecZeroFreeFunctions;
  TestVecDefaultProperty;
  TestDistance2f;
  TestDistance3f;
  TestDistance4d;
  TestLerp2f;
  TestLerp3d;
  TestReflect3f;
  TestReflect2d;
  TestProject3f;
  TestProject4f;
  TestAngleBetween2f;
  TestAngleBetween3f;
  WriteLn('All vec tests passed.');
end.
