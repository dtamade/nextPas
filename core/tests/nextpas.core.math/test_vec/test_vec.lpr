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

{ Cross2D tests }

procedure TestCross2Df;
var
  A, B: TVec2f;
begin
  A := TVec2f.Create(1.0, 0.0);
  B := TVec2f.Create(0.0, 1.0);
  Assert(Abs(A.Cross2D(B) - 1.0) < 0.0001, 'Cross2Df positive');
  Assert(Abs(B.Cross2D(A) - (-1.0)) < 0.0001, 'Cross2Df negative');
end;

procedure TestCross2Dd;
var
  A, B: TVec2d;
begin
  A := TVec2d.Create(2.0, 0.0);
  B := TVec2d.Create(0.0, 3.0);
  Assert(Abs(A.Cross2D(B) - 6.0) < 0.00001, 'Cross2Dd 2x3');
end;

{ AdjustToLength tests }

procedure TestAdjustToLength2f;
var
  V, R: TVec2f;
begin
  V := TVec2f.Create(3.0, 4.0);
  R := V.AdjustToLength(10.0);
  Assert(Abs(R.Length - 10.0) < 0.0001, 'AdjustToLength2f length');
end;

procedure TestAdjustToLength3f;
var
  V, R: TVec3f;
begin
  V := TVec3f.Create(1.0, 0.0, 0.0);
  R := V.AdjustToLength(5.0);
  Assert(Abs(R.X - 5.0) < 0.0001, 'AdjustToLength3f X');
  Assert(Abs(R.Y) < 0.0001, 'AdjustToLength3f Y');
  Assert(Abs(R.Z) < 0.0001, 'AdjustToLength3f Z');
end;

procedure TestAdjustToLength4d;
var
  V, R: TVec4d;
begin
  V := TVec4d.Create(0.0, 0.0, 0.0, 0.0);
  R := V.AdjustToLength(5.0);
  Assert(R.PerfectlyEquals(Vec4dZero), 'AdjustToLength4d zero stays zero');
end;

{ Max tests }

procedure TestMaxVec2f;
var
  A, B, C: TVec2f;
begin
  A := TVec2f.Create(1.0, 5.0);
  B := TVec2f.Create(3.0, 2.0);
  C := A.Max(B);
  Assert(C.X = 3.0, 'MaxVec2f X');
  Assert(C.Y = 5.0, 'MaxVec2f Y');
end;

procedure TestMaxVec3f;
var
  A, B, C: TVec3f;
begin
  A := TVec3f.Create(-1.0, 5.0, 0.0);
  B := TVec3f.Create(3.0, 2.0, 7.0);
  C := A.Max(B);
  Assert(C.X = 3.0, 'MaxVec3f X');
  Assert(C.Y = 5.0, 'MaxVec3f Y');
  Assert(C.Z = 7.0, 'MaxVec3f Z');
end;

procedure TestMaxVec4f;
var
  A, B, C: TVec4f;
begin
  A := TVec4f.Create(1.0, 5.0, -3.0, 8.0);
  B := TVec4f.Create(3.0, 2.0, 7.0, 4.0);
  C := A.Max(B);
  Assert(C.X = 3.0, 'MaxVec4f X');
  Assert(C.Y = 5.0, 'MaxVec4f Y');
  Assert(C.Z = 7.0, 'MaxVec4f Z');
  Assert(C.W = 8.0, 'MaxVec4f W');
end;

{ Min tests }

procedure TestMinVec2d;
var
  A, B, C: TVec2d;
begin
  A := TVec2d.Create(1.0, 5.0);
  B := TVec2d.Create(3.0, 2.0);
  C := A.Min(B);
  Assert(C.X = 1.0, 'MinVec2d X');
  Assert(C.Y = 2.0, 'MinVec2d Y');
end;

procedure TestMinVec3d;
var
  A, B, C: TVec3d;
begin
  A := TVec3d.Create(-1.0, 5.0, 0.0);
  B := TVec3d.Create(3.0, 2.0, 7.0);
  C := A.Min(B);
  Assert(C.X = -1.0, 'MinVec3d X');
  Assert(C.Y = 2.0, 'MinVec3d Y');
  Assert(C.Z = 0.0, 'MinVec3d Z');
end;

procedure TestMinVec4d;
var
  A, B, C: TVec4d;
begin
  A := TVec4d.Create(1.0, 5.0, -3.0, 8.0);
  B := TVec4d.Create(3.0, 2.0, 7.0, 4.0);
  C := A.Min(B);
  Assert(C.X = 1.0, 'MinVec4d X');
  Assert(C.Y = 2.0, 'MinVec4d Y');
  Assert(C.Z = -3.0, 'MinVec4d Z');
  Assert(C.W = 4.0, 'MinVec4d W');
end;

{ Abs tests }

procedure TestAbsVec2f;
var
  V, R: TVec2f;
begin
  V := TVec2f.Create(-1.0, 3.0);
  R := V.Abs;
  Assert(R.X = 1.0, 'AbsVec2f X');
  Assert(R.Y = 3.0, 'AbsVec2f Y');
end;

procedure TestAbsVec3d;
var
  V, R: TVec3d;
begin
  V := TVec3d.Create(-1.0, -2.0, 3.0);
  R := V.Abs;
  Assert(R.X = 1.0, 'AbsVec3d X');
  Assert(R.Y = 2.0, 'AbsVec3d Y');
  Assert(R.Z = 3.0, 'AbsVec3d Z');
end;

procedure TestAbsVec4f;
var
  V, R: TVec4f;
begin
  V := TVec4f.Create(-1.0, 2.0, -3.0, 4.0);
  R := V.Abs;
  Assert(R.X = 1.0, 'AbsVec4f X');
  Assert(R.Y = 2.0, 'AbsVec4f Y');
  Assert(R.Z = 3.0, 'AbsVec4f Z');
  Assert(R.W = 4.0, 'AbsVec4f W');
end;

{ IsZero tests }

procedure TestIsZeroVec2f;
var
  V: TVec2f;
begin
  V := Vec2fZero;
  Assert(V.IsZero, 'IsZero2f zero');
  V := TVec2f.Create(0.0, 0.001);
  Assert(not V.IsZero, 'IsZero2f non-zero');
end;

procedure TestIsZeroVec3f;
var
  V: TVec3f;
begin
  V := Vec3fZero;
  Assert(V.IsZero, 'IsZero3f zero');
  V := TVec3f.Create(0.0, 0.0, 1.0);
  Assert(not V.IsZero, 'IsZero3f non-zero');
end;

procedure TestIsZeroVec4d;
var
  V: TVec4d;
begin
  V := Vec4dZero;
  Assert(V.IsZero, 'IsZero4d zero');
  V := TVec4d.Create(0.0, 0.0, 0.0, 0.001);
  Assert(not V.IsZero, 'IsZero4d non-zero');
end;

{ Equals tests }

procedure TestEqualsVec2f;
var
  A, B: TVec2f;
begin
  A := TVec2f.Create(1.0, 2.0);
  B := TVec2f.Create(1.0001, 2.0001);
  Assert(A.Equals(B, 0.001), 'Equals2f within epsilon');
  Assert(not A.Equals(B, 0.00001), 'Equals2f outside epsilon');
end;

procedure TestEqualsVec3d;
var
  A, B: TVec3d;
begin
  A := TVec3d.Create(1.0, 2.0, 3.0);
  B := TVec3d.Create(1.0, 2.0, 3.0);
  Assert(A.Equals(B, 0.0), 'Equals3d exact zero epsilon');
  B := TVec3d.Create(1.0, 2.0, 3.001);
  Assert(not A.Equals(B, 0.0001), 'Equals3d outside epsilon');
end;

procedure TestEqualsVec4f;
var
  A, B: TVec4f;
begin
  A := TVec4f.Create(1.0, 2.0, 3.0, 4.0);
  B := TVec4f.Create(1.0, 2.0, 3.0, 4.0);
  Assert(A.Equals(B, 0.0001), 'Equals4f identical');
end;

{ PerfectlyEquals tests }

procedure TestPerfectlyEqualsVec2f;
var
  A, B: TVec2f;
begin
  A := TVec2f.Create(1.0, 2.0);
  B := TVec2f.Create(1.0, 2.0);
  Assert(A.PerfectlyEquals(B), 'PerfectlyEquals2f true');
  B := TVec2f.Create(1.0, 2.0001);
  Assert(not A.PerfectlyEquals(B), 'PerfectlyEquals2f false');
end;

procedure TestPerfectlyEqualsVec3d;
var
  A, B: TVec3d;
begin
  A := TVec3d.Create(1.0, 2.0, 3.0);
  B := TVec3d.Create(1.0, 2.0, 3.0);
  Assert(A.PerfectlyEquals(B), 'PerfectlyEquals3d true');
end;

procedure TestPerfectlyEqualsVec4f;
var
  A, B: TVec4f;
begin
  A := TVec4f.Create(1.0, 2.0, 3.0, 4.0);
  B := TVec4f.Create(1.0, 2.0, 3.0, 4.0);
  Assert(A.PerfectlyEquals(B), 'PerfectlyEquals4f true');
  B := TVec4f.Create(1.0, 2.0, 3.0, 4.0001);
  Assert(not A.PerfectlyEquals(B), 'PerfectlyEquals4f false');
end;

{ ToPosition tests }

procedure TestToPositionVec4f;
var
  V: TVec4f;
  R: TVec3f;
begin
  V := TVec4f.Create(2.0, 4.0, 6.0, 2.0);
  R := V.ToPosition;
  Assert(Abs(R.X - 1.0) < 0.0001, 'ToPosition4f X');
  Assert(Abs(R.Y - 2.0) < 0.0001, 'ToPosition4f Y');
  Assert(Abs(R.Z - 3.0) < 0.0001, 'ToPosition4f Z');
end;

procedure TestToPositionVec4d;
var
  V: TVec4d;
  R: TVec3d;
begin
  V := TVec4d.Create(4.0, 8.0, 12.0, 4.0);
  R := V.ToPosition;
  Assert(Abs(R.X - 1.0) < 0.00001, 'ToPosition4d X');
  Assert(Abs(R.Y - 2.0) < 0.00001, 'ToPosition4d Y');
  Assert(Abs(R.Z - 3.0) < 0.00001, 'ToPosition4d Z');
end;

{ Average tests }

procedure TestAverageVec3f;
var
  A, B, C: TVec3f;
begin
  A := TVec3f.Create(0.0, 0.0, 0.0);
  B := TVec3f.Create(2.0, 4.0, 6.0);
  C := A.Average(B);
  Assert(Abs(C.X - 1.0) < 0.0001, 'Average3f X');
  Assert(Abs(C.Y - 2.0) < 0.0001, 'Average3f Y');
  Assert(Abs(C.Z - 3.0) < 0.0001, 'Average3f Z');
end;

procedure TestAverageVec3d;
var
  A, B, C: TVec3d;
begin
  A := TVec3d.Create(1.0, 1.0, 1.0);
  B := TVec3d.Create(3.0, 3.0, 3.0);
  C := A.Average(B);
  Assert(Abs(C.X - 2.0) < 0.00001, 'Average3d X');
  Assert(Abs(C.Y - 2.0) < 0.00001, 'Average3d Y');
  Assert(Abs(C.Z - 2.0) < 0.00001, 'Average3d Z');
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
  TestCross2Df;
  TestCross2Dd;
  TestAdjustToLength2f;
  TestAdjustToLength3f;
  TestAdjustToLength4d;
  TestMaxVec2f;
  TestMaxVec3f;
  TestMaxVec4f;
  TestMinVec2d;
  TestMinVec3d;
  TestMinVec4d;
  TestAbsVec2f;
  TestAbsVec3d;
  TestAbsVec4f;
  TestIsZeroVec2f;
  TestIsZeroVec3f;
  TestIsZeroVec4d;
  TestEqualsVec2f;
  TestEqualsVec3d;
  TestEqualsVec4f;
  TestPerfectlyEqualsVec2f;
  TestPerfectlyEqualsVec3d;
  TestPerfectlyEqualsVec4f;
  TestToPositionVec4f;
  TestToPositionVec4d;
  TestAverageVec3f;
  TestAverageVec3d;
  WriteLn('All vec tests passed.');
end.
