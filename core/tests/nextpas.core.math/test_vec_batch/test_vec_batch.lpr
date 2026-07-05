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

begin
  T := TTestSuite.Create('nextpas.core.math.vec.batch');
  T.Test('BatchDot', @TestBatchDot);
  T.Test('BatchNormalize', @TestBatchNormalize);
  T.Test('BatchTransform', @TestBatchTransform);
  T.Test('BatchLerp', @TestBatchLerp);
  T.Test('BatchClamp', @TestBatchClamp);
  T.Test('BatchEmpty', @TestBatchEmpty);
  if not T.Run then Halt(1);
end.
