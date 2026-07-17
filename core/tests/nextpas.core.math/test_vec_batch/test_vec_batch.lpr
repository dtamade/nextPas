program test_vec_batch;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.math;

var
  T: TTestSuite;

procedure CheckNear(const AExpected, AActual, AEpsilon: Double; const AMessage: string);
var
  LDelta: Double;
begin
  LDelta := AExpected - AActual;
  if LDelta < 0.0 then
    LDelta := -LDelta;
  Check(LDelta <= AEpsilon, AMessage);
end;

procedure TestBatchDot;
var
  LLeft2, LRight2: array[0..2] of TVec2f;
  LLeft3, LRight3: array[0..2] of TVec3f;
  LLeft4, LRight4: array[0..2] of TVec4f;
  LResults2: array[0..2] of Single;
  LResults3: array[0..2] of Single;
  LResults4: array[0..2] of Single;
  LCount: SizeInt;
begin
  LLeft2[0] := TVec2f.Create(1.0, 0.0);
  LLeft2[1] := TVec2f.Create(0.0, 1.0);
  LLeft2[2] := TVec2f.Create(1.0, 1.0);
  LRight2[0] := TVec2f.Create(1.0, 0.0);
  LRight2[1] := TVec2f.Create(0.0, 1.0);
  LRight2[2] := TVec2f.Create(1.0, -1.0);

  LCount := BatchDot(LLeft2, LRight2, LResults2);
  Check(LCount = 3, 'BatchDot TVec2f returns correct count');
  CheckNear(1.0, LResults2[0], 0.0, 'BatchDot TVec2f [0]');
  CheckNear(1.0, LResults2[1], 0.0, 'BatchDot TVec2f [1]');
  CheckNear(0.0, LResults2[2], 0.0, 'BatchDot TVec2f [2]');

  LLeft3[0] := TVec3f.Create(1.0, 2.0, 3.0);
  LLeft3[1] := TVec3f.Create(0.0, 0.0, 0.0);
  LLeft3[2] := TVec3f.Create(-1.0, -2.0, -3.0);
  LRight3[0] := TVec3f.Create(4.0, 5.0, 6.0);
  LRight3[1] := TVec3f.Create(1.0, 1.0, 1.0);
  LRight3[2] := TVec3f.Create(1.0, 1.0, 1.0);

  LCount := BatchDot(LLeft3, LRight3, LResults3);
  Check(LCount = 3, 'BatchDot TVec3f returns correct count');
  CheckNear(32.0, LResults3[0], 0.0, 'BatchDot TVec3f [0]');
  CheckNear(0.0, LResults3[1], 0.0, 'BatchDot TVec3f [1]');
  CheckNear(-6.0, LResults3[2], 0.0, 'BatchDot TVec3f [2]');

  LLeft4[0] := TVec4f.Create(1.0, 2.0, 3.0, 4.0);
  LLeft4[1] := TVec4f.Create(0.0, 0.0, 0.0, 0.0);
  LLeft4[2] := TVec4f.Create(1.0, 1.0, 1.0, 1.0);
  LRight4[0] := TVec4f.Create(5.0, 6.0, 7.0, 8.0);
  LRight4[1] := TVec4f.Create(1.0, 1.0, 1.0, 1.0);
  LRight4[2] := TVec4f.Create(-1.0, -1.0, -1.0, -1.0);

  LCount := BatchDot(LLeft4, LRight4, LResults4);
  Check(LCount = 3, 'BatchDot TVec4f returns correct count');
  CheckNear(70.0, LResults4[0], 0.0, 'BatchDot TVec4f [0]');
  CheckNear(0.0, LResults4[1], 0.0, 'BatchDot TVec4f [1]');
  CheckNear(-4.0, LResults4[2], 0.0, 'BatchDot TVec4f [2]');
end;

procedure TestBatchNormalize;
var
  LVectors3: array[0..2] of TVec3f;
  LCount: SizeInt;
begin
  LVectors3[0] := TVec3f.Create(3.0, 0.0, 0.0);
  LVectors3[1] := TVec3f.Create(0.0, 4.0, 0.0);
  LVectors3[2] := TVec3f.Create(0.0, 0.0, 5.0);

  LCount := BatchNormalize(LVectors3);
  Check(LCount = 3, 'BatchNormalize TVec3f returns correct count');
  CheckNear(1.0, LVectors3[0].Length, 0.0, 'BatchNormalize TVec3f [0] length');
  CheckNear(1.0, LVectors3[1].Length, 0.0, 'BatchNormalize TVec3f [1] length');
  CheckNear(1.0, LVectors3[2].Length, 0.0, 'BatchNormalize TVec3f [2] length');
  CheckNear(1.0, LVectors3[0].X, 0.0, 'BatchNormalize TVec3f [0] X');
  CheckNear(1.0, LVectors3[1].Y, 0.0, 'BatchNormalize TVec3f [1] Y');
  CheckNear(1.0, LVectors3[2].Z, 0.0, 'BatchNormalize TVec3f [2] Z');
end;

procedure TestBatchTransform;
var
  LMatrix: TMat4f;
  LSource: array[0..1] of TVec3f;
  LDest: array[0..1] of TVec3f;
  LCount: SizeInt;
begin
  LMatrix := TMat4f.Identity;
  LSource[0] := TVec3f.Create(1.0, 2.0, 3.0);
  LSource[1] := TVec3f.Create(4.0, 5.0, 6.0);

  LCount := BatchTransform(LMatrix, LSource, LDest);
  Check(LCount = 2, 'BatchTransform returns correct count');
  CheckNear(1.0, LDest[0].X, 0.0, 'BatchTransform [0] X');
  CheckNear(2.0, LDest[0].Y, 0.0, 'BatchTransform [0] Y');
  CheckNear(3.0, LDest[0].Z, 0.0, 'BatchTransform [0] Z');
  CheckNear(4.0, LDest[1].X, 0.0, 'BatchTransform [1] X');
  CheckNear(5.0, LDest[1].Y, 0.0, 'BatchTransform [1] Y');
  CheckNear(6.0, LDest[1].Z, 0.0, 'BatchTransform [1] Z');
end;

procedure TestBatchLerp;
var
  LStart, LEnd, LDest: array[0..1] of TVec3f;
  LCount: SizeInt;
begin
  LStart[0] := TVec3f.Create(0.0, 0.0, 0.0);
  LStart[1] := TVec3f.Create(1.0, 1.0, 1.0);
  LEnd[0] := TVec3f.Create(10.0, 10.0, 10.0);
  LEnd[1] := TVec3f.Create(2.0, 2.0, 2.0);

  LCount := BatchLerp(LStart, LEnd, 0.5, LDest);
  Check(LCount = 2, 'BatchLerp returns correct count');
  CheckNear(5.0, LDest[0].X, 0.0, 'BatchLerp [0] X');
  CheckNear(5.0, LDest[0].Y, 0.0, 'BatchLerp [0] Y');
  CheckNear(5.0, LDest[0].Z, 0.0, 'BatchLerp [0] Z');
  CheckNear(1.5, LDest[1].X, 0.0, 'BatchLerp [1] X');
  CheckNear(1.5, LDest[1].Y, 0.0, 'BatchLerp [1] Y');
  CheckNear(1.5, LDest[1].Z, 0.0, 'BatchLerp [1] Z');
end;

procedure TestBatchClamp;
var
  LVectors, LDest: array[0..1] of TVec3f;
  LMin, LMax: TVec3f;
  LCount: SizeInt;
begin
  LVectors[0] := TVec3f.Create(-1.0, 5.0, 0.5);
  LVectors[1] := TVec3f.Create(10.0, -5.0, 2.0);
  LMin := TVec3f.Create(0.0, 0.0, 0.0);
  LMax := TVec3f.Create(5.0, 5.0, 1.0);

  LCount := BatchClamp(LVectors, LMin, LMax, LDest);
  Check(LCount = 2, 'BatchClamp returns correct count');
  CheckNear(0.0, LDest[0].X, 0.0, 'BatchClamp [0] X');
  CheckNear(5.0, LDest[0].Y, 0.0, 'BatchClamp [0] Y');
  CheckNear(0.5, LDest[0].Z, 0.0, 'BatchClamp [0] Z');
  CheckNear(5.0, LDest[1].X, 0.0, 'BatchClamp [1] X');
  CheckNear(0.0, LDest[1].Y, 0.0, 'BatchClamp [1] Y');
  CheckNear(1.0, LDest[1].Z, 0.0, 'BatchClamp [1] Z');
end;

procedure TestBatchEmpty;
var
  LLeft, LRight: array[0..0] of TVec3f;
  LResults: array[0..0] of Single;
  LCount: SizeInt;
begin
  LLeft[0] := TVec3f.Create(1.0, 2.0, 3.0);
  LRight[0] := TVec3f.Create(4.0, 5.0, 6.0);
  LCount := BatchDot(LLeft, LRight, LResults);
  Check(LCount = 1, 'BatchDot single element works');
  CheckNear(32.0, LResults[0], 0.0, 'BatchDot single element value');
end;

procedure TestBatchDotNaN;
var
  LLeft, LRight: array[0..0] of TVec3f;
  LResults: array[0..0] of Single;
  LCount: SizeInt;
begin
  LLeft[0] := TVec3f.Create(1.0, 2.0, 3.0);
  LRight[0] := TVec3f.Create(0.0 / 0.0, 5.0, 6.0);
  LCount := BatchDot(LLeft, LRight, LResults);
  Check(LCount = 1, 'BatchDot NaN returns count 1');
  Check(IsNaN(LResults[0]), 'BatchDot NaN propagates');
end;

procedure TestBatchDotInfinity;
var
  LLeft, LRight: array[0..0] of TVec3f;
  LResults: array[0..0] of Single;
  LCount: SizeInt;
begin
  LLeft[0] := TVec3f.Create(1.0, 2.0, 3.0);
  LRight[0] := TVec3f.Create(1.0 / 0.0, 5.0, 6.0);
  LCount := BatchDot(LLeft, LRight, LResults);
  Check(LCount = 1, 'BatchDot Inf returns count 1');
  Check(LResults[0] > 1e30, 'BatchDot Inf propagates');
end;

procedure TestBatchDotMismatchedLength;
var
  LLeft: array[0..2] of TVec3f;
  LRight: array[0..0] of TVec3f;
  LResults: array[0..2] of Single;
  LCount: SizeInt;
begin
  LLeft[0] := TVec3f.Create(1.0, 0.0, 0.0);
  LLeft[1] := TVec3f.Create(0.0, 1.0, 0.0);
  LLeft[2] := TVec3f.Create(0.0, 0.0, 1.0);
  LRight[0] := TVec3f.Create(1.0, 0.0, 0.0);
  LCount := BatchDot(LLeft, LRight, LResults);
  Check(LCount = 1, 'BatchDot mismatched length returns min');
  CheckNear(1.0, LResults[0], 0.0, 'BatchDot mismatched [0]');
end;

procedure TestBatchNormalizeZero;
var
  LVectors: array[0..0] of TVec3f;
  LCount: SizeInt;
begin
  LVectors[0] := TVec3f.Create(0.0, 0.0, 0.0);
  LCount := BatchNormalize(LVectors);
  Check(LCount = 1, 'BatchNormalize zero vector returns count 1');
  CheckNear(0.0, LVectors[0].Length, 0.0, 'BatchNormalize zero vector stays zero');
end;

procedure TestBatchNormalizeSourceDest;
var
  LSource: array[0..1] of TVec3f;
  LDest: array[0..1] of TVec3f;
  LCount: SizeInt;
begin
  LSource[0] := TVec3f.Create(3.0, 0.0, 0.0);
  LSource[1] := TVec3f.Create(0.0, 4.0, 0.0);
  LCount := BatchNormalize(LSource, LDest);
  Check(LCount = 2, 'BatchNormalize source-dest returns count');
  CheckNear(1.0, LDest[0].Length, 0.0, 'BatchNormalize source-dest [0] length');
  CheckNear(1.0, LDest[1].Length, 0.0, 'BatchNormalize source-dest [1] length');
  CheckNear(3.0, LSource[0].X, 0.0, 'BatchNormalize source unchanged [0]');
end;

procedure TestBatchTransformNaN;
var
  LMatrix: TMat4f;
  LSource: array[0..0] of TVec3f;
  LDest: array[0..0] of TVec3f;
  LCount: SizeInt;
begin
  LMatrix := TMat4f.Identity;
  LSource[0] := TVec3f.Create(0.0 / 0.0, 2.0, 3.0);
  LCount := BatchTransform(LMatrix, LSource, LDest);
  Check(LCount = 1, 'BatchTransform NaN returns count');
  Check(IsNaN(LDest[0].X), 'BatchTransform NaN propagates X');
end;

procedure TestBatchLerpEndpoints;
var
  LStart, LEnd, LDest: array[0..0] of TVec3f;
  LCount: SizeInt;
begin
  LStart[0] := TVec3f.Create(0.0, 0.0, 0.0);
  LEnd[0] := TVec3f.Create(10.0, 10.0, 10.0);
  LCount := BatchLerp(LStart, LEnd, 0.0, LDest);
  Check(LCount = 1, 'BatchLerp t=0 returns count');
  CheckNear(0.0, LDest[0].X, 0.0, 'BatchLerp t=0 returns start');
  LCount := BatchLerp(LStart, LEnd, 1.0, LDest);
  CheckNear(10.0, LDest[0].X, 0.0, 'BatchLerp t=1 returns end');
end;

procedure TestBatchClampMinMax;
var
  LVectors, LDest: array[0..0] of TVec3f;
  LMin, LMax: TVec3f;
  LCount: SizeInt;
begin
  LVectors[0] := TVec3f.Create(5.0, 5.0, 5.0);
  LMin := TVec3f.Create(5.0, 5.0, 5.0);
  LMax := TVec3f.Create(5.0, 5.0, 5.0);
  LCount := BatchClamp(LVectors, LMin, LMax, LDest);
  Check(LCount = 1, 'BatchClamp equal bounds returns count');
  CheckNear(5.0, LDest[0].X, 0.0, 'BatchClamp equal bounds value');
end;

{ M-V1 Double minimal parity }

procedure TestBatchDotDouble;
var
  LLeft2, LRight2: array[0..2] of TVec2d;
  LLeft3, LRight3: array[0..2] of TVec3d;
  LLeft4, LRight4: array[0..2] of TVec4d;
  LResults2: array[0..2] of Double;
  LResults3: array[0..2] of Double;
  LResults4: array[0..2] of Double;
  LCount: SizeInt;
begin
  LLeft2[0] := TVec2d.Create(1.0, 0.0);
  LLeft2[1] := TVec2d.Create(0.0, 1.0);
  LLeft2[2] := TVec2d.Create(1.0, 1.0);
  LRight2[0] := TVec2d.Create(1.0, 0.0);
  LRight2[1] := TVec2d.Create(0.0, 1.0);
  LRight2[2] := TVec2d.Create(1.0, -1.0);
  LCount := BatchDot(LLeft2, LRight2, LResults2);
  Check(LCount = 3, 'BatchDot TVec2d count');
  CheckNear(1.0, LResults2[0], 0.0, 'BatchDot TVec2d [0]');
  CheckNear(1.0, LResults2[1], 0.0, 'BatchDot TVec2d [1]');
  CheckNear(0.0, LResults2[2], 0.0, 'BatchDot TVec2d [2]');

  LLeft3[0] := TVec3d.Create(1.0, 2.0, 3.0);
  LLeft3[1] := TVec3d.Create(0.0, 0.0, 0.0);
  LLeft3[2] := TVec3d.Create(-1.0, -2.0, -3.0);
  LRight3[0] := TVec3d.Create(4.0, 5.0, 6.0);
  LRight3[1] := TVec3d.Create(1.0, 1.0, 1.0);
  LRight3[2] := TVec3d.Create(1.0, 1.0, 1.0);
  LCount := BatchDot(LLeft3, LRight3, LResults3);
  Check(LCount = 3, 'BatchDot TVec3d count');
  CheckNear(32.0, LResults3[0], 0.0, 'BatchDot TVec3d [0]');
  CheckNear(0.0, LResults3[1], 0.0, 'BatchDot TVec3d [1]');
  CheckNear(-6.0, LResults3[2], 0.0, 'BatchDot TVec3d [2]');

  LLeft4[0] := TVec4d.Create(1.0, 2.0, 3.0, 4.0);
  LLeft4[1] := TVec4d.Create(0.0, 0.0, 0.0, 0.0);
  LLeft4[2] := TVec4d.Create(1.0, 1.0, 1.0, 1.0);
  LRight4[0] := TVec4d.Create(5.0, 6.0, 7.0, 8.0);
  LRight4[1] := TVec4d.Create(1.0, 1.0, 1.0, 1.0);
  LRight4[2] := TVec4d.Create(-1.0, -1.0, -1.0, -1.0);
  LCount := BatchDot(LLeft4, LRight4, LResults4);
  Check(LCount = 3, 'BatchDot TVec4d count');
  CheckNear(70.0, LResults4[0], 0.0, 'BatchDot TVec4d [0]');
  CheckNear(0.0, LResults4[1], 0.0, 'BatchDot TVec4d [1]');
  CheckNear(-4.0, LResults4[2], 0.0, 'BatchDot TVec4d [2]');
end;

procedure TestBatchNormalizeDouble;
var
  LVectors3: array[0..2] of TVec3d;
  LSource, LDest: array[0..1] of TVec3d;
  LCount: SizeInt;
begin
  LVectors3[0] := TVec3d.Create(3.0, 0.0, 0.0);
  LVectors3[1] := TVec3d.Create(0.0, 4.0, 0.0);
  LVectors3[2] := TVec3d.Create(0.0, 0.0, 5.0);
  LCount := BatchNormalize(LVectors3);
  Check(LCount = 3, 'BatchNormalize TVec3d count');
  CheckNear(1.0, LVectors3[0].Length, 1e-15, 'BatchNormalize TVec3d [0] len');
  CheckNear(1.0, LVectors3[1].Length, 1e-15, 'BatchNormalize TVec3d [1] len');
  CheckNear(1.0, LVectors3[2].Length, 1e-15, 'BatchNormalize TVec3d [2] len');

  LSource[0] := TVec3d.Create(3.0, 0.0, 0.0);
  LSource[1] := TVec3d.Create(0.0, 4.0, 0.0);
  LCount := BatchNormalize(LSource, LDest);
  Check(LCount = 2, 'BatchNormalize TVec3d src-dst count');
  CheckNear(1.0, LDest[0].Length, 1e-15, 'BatchNormalize TVec3d src-dst [0]');
  CheckNear(3.0, LSource[0].X, 0.0, 'BatchNormalize TVec3d source unchanged');
end;

procedure TestBatchTransformDouble;
var
  LMatrix: TMat4d;
  LSource, LDest: array[0..1] of TVec3d;
  LMat3: TMat3d;
  LSrc2, LDst2: array[0..0] of TVec2d;
  LCount: SizeInt;
begin
  LMatrix := TMat4d.Identity;
  LSource[0] := TVec3d.Create(1.0, 2.0, 3.0);
  LSource[1] := TVec3d.Create(4.0, 5.0, 6.0);
  LCount := BatchTransform(LMatrix, LSource, LDest);
  Check(LCount = 2, 'BatchTransform TVec3d count');
  CheckNear(1.0, LDest[0].X, 0.0, 'BatchTransform TVec3d [0] X');
  CheckNear(6.0, LDest[1].Z, 0.0, 'BatchTransform TVec3d [1] Z');

  LMat3 := TMat3d.Identity;
  LSrc2[0] := TVec2d.Create(2.0, 3.0);
  LCount := BatchTransform(LMat3, LSrc2, LDst2);
  Check(LCount = 1, 'BatchTransform TVec2d count');
  CheckNear(2.0, LDst2[0].X, 0.0, 'BatchTransform TVec2d X');
  CheckNear(3.0, LDst2[0].Y, 0.0, 'BatchTransform TVec2d Y');
end;

procedure TestBatchLerpDouble;
var
  LStart, LEnd, LDest: array[0..1] of TVec3d;
  LCount: SizeInt;
begin
  LStart[0] := TVec3d.Create(0.0, 0.0, 0.0);
  LStart[1] := TVec3d.Create(1.0, 1.0, 1.0);
  LEnd[0] := TVec3d.Create(10.0, 10.0, 10.0);
  LEnd[1] := TVec3d.Create(2.0, 2.0, 2.0);
  LCount := BatchLerp(LStart, LEnd, 0.5, LDest);
  Check(LCount = 2, 'BatchLerp TVec3d count');
  CheckNear(5.0, LDest[0].X, 0.0, 'BatchLerp TVec3d [0] X');
  CheckNear(1.5, LDest[1].Y, 0.0, 'BatchLerp TVec3d [1] Y');
end;

procedure TestBatchClampDouble;
var
  LVectors, LDest: array[0..1] of TVec3d;
  LMin, LMax: TVec3d;
  LCount: SizeInt;
begin
  LVectors[0] := TVec3d.Create(-1.0, 5.0, 0.5);
  LVectors[1] := TVec3d.Create(10.0, -5.0, 2.0);
  LMin := TVec3d.Create(0.0, 0.0, 0.0);
  LMax := TVec3d.Create(5.0, 5.0, 1.0);
  LCount := BatchClamp(LVectors, LMin, LMax, LDest);
  Check(LCount = 2, 'BatchClamp TVec3d count');
  CheckNear(0.0, LDest[0].X, 0.0, 'BatchClamp TVec3d [0] X');
  CheckNear(5.0, LDest[0].Y, 0.0, 'BatchClamp TVec3d [0] Y');
  CheckNear(0.5, LDest[0].Z, 0.0, 'BatchClamp TVec3d [0] Z');
  CheckNear(5.0, LDest[1].X, 0.0, 'BatchClamp TVec3d [1] X');
  CheckNear(0.0, LDest[1].Y, 0.0, 'BatchClamp TVec3d [1] Y');
  CheckNear(1.0, LDest[1].Z, 0.0, 'BatchClamp TVec3d [1] Z');
end;

procedure TestBatchDotDoubleMismatched;
var
  LLeft: array[0..2] of TVec3d;
  LRight: array[0..0] of TVec3d;
  LResults: array[0..2] of Double;
  LCount: SizeInt;
begin
  LLeft[0] := TVec3d.Create(1.0, 0.0, 0.0);
  LLeft[1] := TVec3d.Create(0.0, 1.0, 0.0);
  LLeft[2] := TVec3d.Create(0.0, 0.0, 1.0);
  LRight[0] := TVec3d.Create(1.0, 0.0, 0.0);
  LCount := BatchDot(LLeft, LRight, LResults);
  Check(LCount = 1, 'BatchDot TVec3d mismatched returns min');
  CheckNear(1.0, LResults[0], 0.0, 'BatchDot TVec3d mismatched value');
end;

begin
  T := TTestSuite.Create('nextpas.core.math.vec.batch');
  T.Test('BatchDot', @TestBatchDot);
  T.Test('BatchNormalize', @TestBatchNormalize);
  T.Test('BatchTransform', @TestBatchTransform);
  T.Test('BatchLerp', @TestBatchLerp);
  T.Test('BatchClamp', @TestBatchClamp);
  T.Test('BatchEmpty', @TestBatchEmpty);
  T.Test('BatchDot NaN propagation', @TestBatchDotNaN);
  T.Test('BatchDot Infinity propagation', @TestBatchDotInfinity);
  T.Test('BatchDot mismatched length', @TestBatchDotMismatchedLength);
  T.Test('BatchNormalize zero vector', @TestBatchNormalizeZero);
  T.Test('BatchNormalize source-dest', @TestBatchNormalizeSourceDest);
  T.Test('BatchTransform NaN propagation', @TestBatchTransformNaN);
  T.Test('BatchLerp endpoints', @TestBatchLerpEndpoints);
  T.Test('BatchClamp equal bounds', @TestBatchClampMinMax);
  T.Test('BatchDot Double', @TestBatchDotDouble);
  T.Test('BatchNormalize Double', @TestBatchNormalizeDouble);
  T.Test('BatchTransform Double', @TestBatchTransformDouble);
  T.Test('BatchLerp Double', @TestBatchLerpDouble);
  T.Test('BatchClamp Double', @TestBatchClampDouble);
  T.Test('BatchDot Double mismatched length', @TestBatchDotDoubleMismatched);
  if not T.Run then Halt(1);
end.
