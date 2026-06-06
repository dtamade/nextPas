program math_overview;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.math;

type
  TWeight3 = array[0..2] of Single;

procedure Fail(const AMessage: string);
begin
  WriteLn('math-overview-status=fail');
  WriteLn('error=', AMessage);
  Halt(1);
end;

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

procedure PrintScaled(const AName: string; const AValue: Double);
begin
  WriteLn(AName, '=', Round(AValue * 1000.0));
end;

var
  LDirection: TVec3f;
  LRight: TVec3f;
  LRotated: TVec3f;
  LModel: TMat4f;
  LView: TMat4f;
  LProjection: TMat4f;
  LClip: TVec4f;
  LRotation: TQuatf;
  LRng: TRandomGen;
  LNoise: TNoiseGen;
  LWeights: TWeight3;
  LNextInt: Integer;
  LChoice: Integer;

begin
  WriteLn('math-overview=ready');

  LDirection := TVec3f.Create(3.0, 4.0, 0.0).Normalize;
  LRight := TVec3f.Cross(TVec3f.Create(0.0, 0.0, 1.0), LDirection).Normalize;
  Require(TVec3f.Equals(TVec3f.Create(0.6, 0.8, 0.0), LDirection, Single(0.00001)),
    'normalized direction mismatch');
  PrintScaled('direction-length-x1000', LDirection.Length);
  PrintScaled('right-dot-direction-x1000', TVec3f.Dot(LRight, LDirection));

  LRotation := TQuatf.FromAxisAngle(TVec3f.Create(0.0, 0.0, 1.0), Single(HALF_PI));
  LRotated := LRotation.Rotate(TVec3f.Create(1.0, 0.0, 0.0));
  Require(TVec3f.Equals(TVec3f.Create(0.0, 1.0, 0.0), LRotated, Single(0.00001)),
    'quaternion quarter-turn mismatch');
  PrintScaled('quat-rotated-y-x1000', LRotated.Y);

  LModel := Translate(Single(1.0), Single(2.0), Single(-3.0)) *
    RotateZ(Single(HALF_PI)) * Scale(Single(2.0), Single(2.0), Single(2.0));
  LClip := LModel * TVec4f.Create(1.0, 0.0, 0.0, 1.0);
  Require(TVec4f.Equals(TVec4f.Create(1.0, 4.0, -3.0, 1.0), LClip, Single(0.00001)),
    'model transform mismatch');
  PrintScaled('model-point-y-x1000', LClip.Y);

  LView := LookAt(TVec3f.Create(0.0, 0.0, 5.0), TVec3f.Zero,
    TVec3f.Create(0.0, 1.0, 0.0));
  LProjection := Perspective(Single(HALF_PI), Single(1.0), Single(1.0), Single(11.0));
  LClip := LProjection * LView * TVec4f.Create(0.0, 0.0, 0.0, 1.0);
  PrintScaled('view-projection-w-x1000', LClip.W);
  PrintScaled('ease-mid-x1000', EaseInOutQuad(0.5));

  LRng := TRandomGen.Create(123456789);
  LNoise := TNoiseGen.Create(2468);
  try
    LNextInt := LRng.NextInt;
    Require(LNextInt = 702724636, 'rng seed mismatch');
    WriteLn('rng-next-int=', LNextInt);

    LWeights[0] := 0.0;
    LWeights[1] := 1.0;
    LWeights[2] := 0.0;
    LChoice := LRng.WeightedChoice(LWeights);
    Require(LChoice = 1, 'weighted choice mismatch');
    WriteLn('weighted-choice=', LChoice);

    PrintScaled('noise-025-x1000', LNoise.Noise1D(0.25));
  finally
    LNoise.Free;
    LRng.Free;
  end;

  WriteLn('math-overview-status=pass');
end.
