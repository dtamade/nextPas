program test_noise;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.math.random;

var
  T: TTestRunner;

procedure CheckNear(const AExpected, AActual, AEpsilon: Double; const AMessage: string);
var
  LDelta: Double;
begin
  LDelta := AExpected - AActual;
  if LDelta < 0.0 then
    LDelta := -LDelta;
  Check(LDelta <= AEpsilon, AMessage);
end;

procedure TestNoiseRepeatability;
var
  A, B: TNoiseGen;
begin
  A := TNoiseGen.Create(2468);
  B := TNoiseGen.Create(2468);
  try
    CheckNear(A.Noise1D(0.25), B.Noise1D(0.25), 0.0, 'same seed repeats Noise1D');
    CheckNear(A.Noise2D(0.25, 0.75), B.Noise2D(0.25, 0.75), 0.0, 'same seed repeats Noise2D');
    CheckNear(A.Noise3D(0.25, 0.75, 1.25), B.Noise3D(0.25, 0.75, 1.25), 0.0,
      'same seed repeats Noise3D');

    A.SetSeed(13579);
    B.SetSeed(13579);
    CheckNear(A.Noise2D(-3.5, 8.25), B.Noise2D(-3.5, 8.25), 0.0,
      'SetSeed resets deterministic permutation');
  finally
    B.Free;
    A.Free;
  end;
end;

procedure TestNoiseReferenceVectors;
var
  Noise: TNoiseGen;
begin
  Noise := TNoiseGen.Create(2468);
  try
    CheckNear(0.146484375, Noise.Noise1D(0.25), 0.000000000001, 'Noise1D reference vector');
    CheckNear(0.5410423278808594, Noise.Noise2D(0.25, 0.75), 0.000000000001,
      'Noise2D reference vector');
    CheckNear(0.1360609084367752, Noise.Noise3D(0.25, 0.75, 1.25), 0.000000000001,
      'Noise3D reference vector');
    CheckNear(0.146484375, Noise.FBM1D(0.25, 4), 0.000000000001, 'FBM1D reference vector');
    CheckNear(0.5410423278808594, Noise.FBM2D(0.25, 0.75, 4), 0.000000000001,
      'FBM2D reference vector');
    CheckNear(0.07356090843677521, Noise.FBM3D(0.25, 0.75, 1.25, 4), 0.000000000001,
      'FBM3D reference vector');
  finally
    Noise.Free;
  end;
end;

procedure TestNoiseInvalidInputs;
var
  Noise: TNoiseGen;
  Caught: Boolean;
begin
  Noise := TNoiseGen.Create(1);
  try
    Caught := False;
    try
      Noise.FBM1D(0.25, 0);
    except
      on E: EArgumentError do
        Caught := True;
    end;
    Check(Caught, 'FBM rejects non-positive octaves');

    Caught := False;
    try
      Noise.FBM2D(0.25, 0.75, 3, 0.0, 0.5);
    except
      on E: EArgumentError do
        Caught := True;
    end;
    Check(Caught, 'FBM rejects non-positive lacunarity');

    Caught := False;
    try
      Noise.FBM3D(0.25, 0.75, 1.25, 3, 2.0, 0.0);
    except
      on E: EArgumentError do
        Caught := True;
    end;
    Check(Caught, 'FBM rejects non-positive gain');
  finally
    Noise.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.math.noise');
  T.Run('noise repeatability', @TestNoiseRepeatability);
  T.Run('noise reference vectors', @TestNoiseReferenceVectors);
  T.Run('noise invalid inputs', @TestNoiseInvalidInputs);
  T.Summary;
end.
