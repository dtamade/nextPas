{
  test_transform.lpr
  Tests for nextpas.core.math.transform
}
program test_transform;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.math.scalar,
  nextpas.core.math.trig,
  nextpas.core.math.vec.base,
  nextpas.core.math.mat.base,
  nextpas.core.math.transform;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure AssertFloatEq(const ATestName: string; const AActual, AExpected, AEpsilon: Single);
begin
  Inc(GTestCount);
  if Abs(AActual - AExpected) <= AEpsilon then
  begin
    Inc(GPassCount);
    WriteLn('  PASS: ', ATestName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('  FAIL: ', ATestName, ' expected=', AExpected:8:4, ' actual=', AActual:8:4);
  end;
end;

procedure AssertFloatEq(const ATestName: string; const AActual, AExpected, AEpsilon: Double);
begin
  Inc(GTestCount);
  if Abs(AActual - AExpected) <= AEpsilon then
  begin
    Inc(GPassCount);
    WriteLn('  PASS: ', ATestName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('  FAIL: ', ATestName, ' expected=', AExpected:8:4, ' actual=', AActual:8:4);
  end;
end;

procedure TestOrtho;
var
  LM: TMat4f;
begin
  WriteLn('TestOrtho');
  // Ortho(-1, 1, -1, 1, 0, 10) - standard centered ortho
  LM := Ortho(-1.0, 1.0, -1.0, 1.0, 0.0, 10.0);

  // X scale = 2/(right-left) = 2/2 = 1
  AssertFloatEq('ortho x scale', LM.Data[0, 0], 1.0, 0.001);
  // Y scale = 2/(top-bottom) = 2/2 = 1
  AssertFloatEq('ortho y scale', LM.Data[1, 1], 1.0, 0.001);
  // Z scale = -2/(far-near) = -2/10 = -0.2
  AssertFloatEq('ortho z scale', LM.Data[2, 2], -0.2, 0.001);
end;

procedure TestPerspective;
var
  LM: TMat4f;
begin
  WriteLn('TestPerspective');
  // Perspective with FOV=90deg, aspect=1, near=0.1, far=100
  LM := Perspective(Single(PI_VALUE / 2.0), 1.0, 0.1, 100.0);

  // For 90deg FOV, tan(45deg)=1, so m[0,0] = 1/(1*1) = 1
  AssertFloatEq('persp x scale', LM.Data[0, 0], 1.0, 0.001);
  // m[1,1] = 1/tan(45deg) = 1
  AssertFloatEq('persp y scale', LM.Data[1, 1], 1.0, 0.001);
  // m[2,3] = -1 (perspective divide)
  AssertFloatEq('persp divide', LM.Data[2, 3], -1.0, 0.001);
end;

procedure TestLookAt;
var
  LM: TMat4f;
begin
  WriteLn('TestLookAt');
  // Camera at (0,0,5) looking at origin
  LM := LookAt(TVec3f.Create(0, 0, 5), TVec3f.Create(0, 0, 0), TVec3f.Create(0, 1, 0));

  // The view matrix transforms world origin to view space
  AssertFloatEq('lookat m00', LM.Data[0, 0], 1.0, 0.001);
  AssertFloatEq('lookat m11', LM.Data[1, 1], 1.0, 0.001);
  // m22 = -LF.Z = -(0) = 0? No, forward=(0,0,-1), so m22 = -(-1) = 1
  AssertFloatEq('lookat m22', LM.Data[2, 2], 1.0, 0.001);
  // Translation Z should be -5 (eye is at z=5, looking at z=0)
  AssertFloatEq('lookat tz', LM.Data[3, 2], -5.0, 0.001);
end;

procedure TestTranslate;
var
  LM: TMat4f;
  LV: TVec4f;
begin
  WriteLn('TestTranslate');
  LM := Translate(TVec3f.Create(10, 20, 30));

  // Check diagonal
  AssertFloatEq('trans m00', LM.Data[0, 0], 1.0, 0.001);
  AssertFloatEq('trans m11', LM.Data[1, 1], 1.0, 0.001);
  AssertFloatEq('trans m22', LM.Data[2, 2], 1.0, 0.001);
  AssertFloatEq('trans m33', LM.Data[3, 3], 1.0, 0.001);

  // Check translation column
  AssertFloatEq('trans tx', LM.Data[3, 0], 10.0, 0.001);
  AssertFloatEq('trans ty', LM.Data[3, 1], 20.0, 0.001);
  AssertFloatEq('trans tz', LM.Data[3, 2], 30.0, 0.001);

  // Transform point
  LV := TVec4f.Create(1, 2, 3, 1);
  // Result = M * v = (1+10, 2+20, 3+30, 1)
  AssertFloatEq('trans apply x', LV.X * LM.Data[0, 0] + LV.Y * LM.Data[0, 1] + LV.Z * LM.Data[0, 2] + LM.Data[3, 0], 11.0, 0.001);
end;

procedure TestScale;
var
  LM: TMat4f;
begin
  WriteLn('TestScale');
  LM := Scale(TVec3f.Create(2, 3, 4));

  AssertFloatEq('scale m00', LM.Data[0, 0], 2.0, 0.001);
  AssertFloatEq('scale m11', LM.Data[1, 1], 3.0, 0.001);
  AssertFloatEq('scale m22', LM.Data[2, 2], 4.0, 0.001);
  AssertFloatEq('scale m33', LM.Data[3, 3], 1.0, 0.001);
  // Off-diagonal should be zero
  AssertFloatEq('scale m01', LM.Data[0, 1], 0.0, 0.001);
end;

procedure TestRotateX;
var
  LM: TMat4f;
begin
  WriteLn('TestRotateX');
  LM := RotateX(Single(HALF_PI));  // 90 degrees

  // Rotating 90deg around X: Y->Z, Z->-Y
  AssertFloatEq('rx m00', LM.Data[0, 0], 1.0, 0.001);
  AssertFloatEq('rx m11', LM.Data[1, 1], 0.0, 0.001);  // cos(90) = 0
  AssertFloatEq('rx m12', LM.Data[1, 2], 1.0, 0.001);   // sin(90) = 1
  AssertFloatEq('rx m21', LM.Data[2, 1], -1.0, 0.001);  // -sin(90) = -1
  AssertFloatEq('rx m22', LM.Data[2, 2], 0.0, 0.001);   // cos(90) = 0
end;

procedure TestRotateY;
var
  LM: TMat4f;
begin
  WriteLn('TestRotateY');
  LM := RotateY(Single(HALF_PI));  // 90 degrees

  // Rotating 90deg around Y: X->-Z, Z->X
  AssertFloatEq('ry m00', LM.Data[0, 0], 0.0, 0.001);   // cos(90) = 0
  AssertFloatEq('ry m02', LM.Data[0, 2], -1.0, 0.001);  // -sin(90) = -1
  AssertFloatEq('ry m11', LM.Data[1, 1], 1.0, 0.001);
  AssertFloatEq('ry m20', LM.Data[2, 0], 1.0, 0.001);   // sin(90) = 1
  AssertFloatEq('ry m22', LM.Data[2, 2], 0.0, 0.001);   // cos(90) = 0
end;

procedure TestRotateZ;
var
  LM: TMat4f;
begin
  WriteLn('TestRotateZ');
  LM := RotateZ(Single(HALF_PI));  // 90 degrees

  // Rotating 90deg around Z: X->Y, Y->-X
  AssertFloatEq('rz m00', LM.Data[0, 0], 0.0, 0.001);   // cos(90) = 0
  AssertFloatEq('rz m01', LM.Data[0, 1], 1.0, 0.001);   // sin(90) = 1
  AssertFloatEq('rz m10', LM.Data[1, 0], -1.0, 0.001);  // -sin(90) = -1
  AssertFloatEq('rz m11', LM.Data[1, 1], 0.0, 0.001);   // cos(90) = 0
  AssertFloatEq('rz m22', LM.Data[2, 2], 1.0, 0.001);
end;

procedure TestCamera2D;
var
  LM: TMat3f;
begin
  WriteLn('TestCamera2D');
  LM := Camera2D(TVec2f.Create(100, 200), 0.0, 2.0);

  // Scale 2x, no rotation, offset (100,200)
  AssertFloatEq('cam2d m00', LM.Data[0, 0], 2.0, 0.001);  // scale
  AssertFloatEq('cam2d m11', LM.Data[1, 1], 2.0, 0.001);  // scale
  AssertFloatEq('cam2d m20', LM.Data[2, 0], -100.0, 0.001); // -offset
  AssertFloatEq('cam2d m21', LM.Data[2, 1], -200.0, 0.001); // -offset
end;

begin
  WriteLn('=== nextpas.core.math.transform tests ===');
  WriteLn;

  TestOrtho;
  TestPerspective;
  TestLookAt;
  TestTranslate;
  TestScale;
  TestRotateX;
  TestRotateY;
  TestRotateZ;
  TestCamera2D;

  WriteLn;
  WriteLn('Tests: ', GTestCount, ' | Pass: ', GPassCount, ' | Fail: ', GFailCount);
  if GFailCount > 0 then
  begin
    WriteLn('*** FAILURES DETECTED ***');
    Halt(1);
  end
  else
    WriteLn('All tests passed!');
end.
