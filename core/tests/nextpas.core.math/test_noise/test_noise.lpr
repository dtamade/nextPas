program test_noise;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.math.random;

var
  T: TTestRunner;

type
  TDoubleBitCast = packed record
    case Integer of
      0: (Value: Double);
      1: (Bits: QWord);
  end;

procedure CheckNear(const AExpected, AActual, AEpsilon: Double; const AMessage: string);
var
  LDelta: Double;
begin
  LDelta := AExpected - AActual;
  if LDelta < 0.0 then
    LDelta := -LDelta;
  Check(LDelta <= AEpsilon, AMessage);
end;

function DoubleInfinity: Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := $7FF0000000000000;
  Result := LValue.Value;
end;

function DoubleNaN: Double;
var
  LValue: TDoubleBitCast;
begin
  LValue.Bits := $7FF8000000000000;
  Result := LValue.Value;
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

procedure TestZeroSeedUsesDeterministicDefault;
var
  A, B: TNoiseGen;
  Noise1DValue: Double;
  FBM2DValue: Double;
begin
  A := TNoiseGen.Create(0);
  B := TNoiseGen.Create(0);
  try
    Noise1DValue := A.Noise1D(0.25);
    CheckNear(Noise1DValue, B.Noise1D(0.25), 0.0,
      'zero seed uses the same deterministic default Noise1D permutation');

    FBM2DValue := A.FBM2D(0.25, 0.75, 4);
    CheckNear(FBM2DValue, B.FBM2D(0.25, 0.75, 4), 0.0,
      'zero seed uses the same deterministic default FBM2D permutation');

    A.SetSeed(0);
    CheckNear(Noise1DValue, A.Noise1D(0.25), 0.0,
      'SetSeed(0) resets the deterministic default Noise1D permutation');
    CheckNear(FBM2DValue, A.FBM2D(0.25, 0.75, 4), 0.0,
      'SetSeed(0) resets the deterministic default FBM2D permutation');
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
  ErrorMessage: string;
begin
  Noise := TNoiseGen.Create(1);
  try
    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM1D(0.25, 0);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM rejects non-positive octaves');
    CheckEqual('TNoiseGen.FBM1D: AOctaves must be positive', ErrorMessage,
      'FBM1D reports owner-level positive-contract message for octaves');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM2D(0.25, 0.75, 0);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM2D rejects non-positive octaves');
    CheckEqual('TNoiseGen.FBM2D: AOctaves must be positive', ErrorMessage,
      'FBM2D reports owner-level positive-contract message for octaves');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM2D(0.25, 0.75, 3, 0.0, 0.5);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM rejects non-positive lacunarity');
    CheckEqual('TNoiseGen.FBM2D: ALacunarity must be positive', ErrorMessage,
      'FBM2D reports owner-level positive-contract message for zero lacunarity');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM3D(0.25, 0.75, 1.25, 3, 2.0, 0.0);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM rejects non-positive gain');
    CheckEqual('TNoiseGen.FBM3D: AGain must be positive', ErrorMessage,
      'FBM3D reports owner-level positive-contract message for zero gain');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM3D(0.25, 0.75, 1.25, 0);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM3D rejects non-positive octaves');
    CheckEqual('TNoiseGen.FBM3D: AOctaves must be positive', ErrorMessage,
      'FBM3D reports owner-level positive-contract message for octaves');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM2D(0.25, 0.75, 3, DoubleInfinity, 0.5);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM rejects infinite lacunarity');
    CheckEqual('TNoiseGen.FBM2D: ALacunarity must be positive', ErrorMessage,
      'FBM2D reports owner-level positive-contract message for infinite lacunarity');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM3D(0.25, 0.75, 1.25, 3, 0.0, 0.5);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM3D rejects non-positive lacunarity');
    CheckEqual('TNoiseGen.FBM3D: ALacunarity must be positive', ErrorMessage,
      'FBM3D reports owner-level positive-contract message for zero lacunarity');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM3D(0.25, 0.75, 1.25, 3, 2.0, DoubleInfinity);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM rejects infinite gain');
    CheckEqual('TNoiseGen.FBM3D: AGain must be positive', ErrorMessage,
      'FBM3D reports owner-level positive-contract message for infinite gain');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM1D(0.25, 3, -2.0, 0.5);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM1D rejects negative lacunarity');
    CheckEqual('TNoiseGen.FBM1D: ALacunarity must be positive', ErrorMessage,
      'FBM1D reports owner-level positive-contract message for negative lacunarity');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM2D(0.25, 0.75, 3, DoubleNaN, 0.5);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM2D rejects NaN lacunarity');
    CheckEqual('TNoiseGen.FBM2D: ALacunarity must be positive', ErrorMessage,
      'FBM2D reports owner-level positive-contract message for NaN lacunarity');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM1D(0.25, 3, 2.0, -0.5);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM1D rejects negative gain');
    CheckEqual('TNoiseGen.FBM1D: AGain must be positive', ErrorMessage,
      'FBM1D reports owner-level positive-contract message for negative gain');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM3D(0.25, 0.75, 1.25, 3, 2.0, DoubleNaN);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM3D rejects NaN gain');
    CheckEqual('TNoiseGen.FBM3D: AGain must be positive', ErrorMessage,
      'FBM3D reports owner-level positive-contract message for NaN gain');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM2D(0.25, 0.75, 3, 2.0, 0.0);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM2D rejects non-positive gain');
    CheckEqual('TNoiseGen.FBM2D: AGain must be positive', ErrorMessage,
      'FBM2D reports owner-level positive-contract message for zero gain');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.Noise1D(DoubleNaN);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'Noise1D rejects NaN coordinate');
    CheckEqual('TNoiseGen.Noise1D: AX must be finite', ErrorMessage,
      'Noise1D reports public finite-contract message for NaN');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.Noise1D(DoubleInfinity);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'Noise1D rejects infinite coordinate');
    CheckEqual('TNoiseGen.Noise1D: AX must be finite', ErrorMessage,
      'Noise1D reports public finite-contract message for infinity');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.Noise2D(DoubleNaN, 0.75);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'Noise2D rejects NaN X coordinate');
    CheckEqual('TNoiseGen.Noise2D: AX must be finite', ErrorMessage,
      'Noise2D reports public finite-contract message for X');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.Noise2D(0.25, DoubleInfinity);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'Noise2D rejects infinite Y coordinate');
    CheckEqual('TNoiseGen.Noise2D: AY must be finite', ErrorMessage,
      'Noise2D reports public finite-contract message for Y');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.Noise3D(DoubleNaN, 0.75, 1.25);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'Noise3D rejects NaN X coordinate');
    CheckEqual('TNoiseGen.Noise3D: AX must be finite', ErrorMessage,
      'Noise3D reports public finite-contract message for X');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.Noise3D(0.25, DoubleInfinity, 1.25);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'Noise3D rejects infinite Y coordinate');
    CheckEqual('TNoiseGen.Noise3D: AY must be finite', ErrorMessage,
      'Noise3D reports public finite-contract message for Y');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.Noise3D(0.25, 0.75, DoubleNaN);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'Noise3D rejects NaN Z coordinate');
    CheckEqual('TNoiseGen.Noise3D: AZ must be finite', ErrorMessage,
      'Noise3D reports public finite-contract message for Z');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM1D(DoubleInfinity, 3);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM1D rejects infinite coordinate');
    CheckEqual('TNoiseGen.FBM1D: AX must be finite', ErrorMessage,
      'FBM1D reports public finite-contract message for coordinate');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM2D(DoubleNaN, 0.75, 3);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM2D rejects NaN X coordinate');
    CheckEqual('TNoiseGen.FBM2D: AX must be finite', ErrorMessage,
      'FBM2D reports public finite-contract message for X');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM2D(0.25, DoubleInfinity, 3);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM2D rejects infinite Y coordinate');
    CheckEqual('TNoiseGen.FBM2D: AY must be finite', ErrorMessage,
      'FBM2D reports public finite-contract message for Y');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM3D(DoubleNaN, 0.75, 1.25, 3);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM3D rejects NaN X coordinate');
    CheckEqual('TNoiseGen.FBM3D: AX must be finite', ErrorMessage,
      'FBM3D reports public finite-contract message for X');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM3D(0.25, DoubleInfinity, 1.25, 3);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM3D rejects infinite Y coordinate');
    CheckEqual('TNoiseGen.FBM3D: AY must be finite', ErrorMessage,
      'FBM3D reports public finite-contract message for Y');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM3D(0.25, 0.75, DoubleNaN, 3);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM3D rejects NaN Z coordinate');
    CheckEqual('TNoiseGen.FBM3D: AZ must be finite', ErrorMessage,
      'FBM3D reports public finite-contract message for Z');
  finally
    Noise.Free;
  end;
end;

procedure TestNoiseLargePeriodicCoordinatesStayStable;
const
  LARGE_SHIFT_X: Double = 5120000000.0;
  LARGE_SHIFT_Y: Double = -7680000000.0;
  LARGE_SHIFT_Z: Double = 10240000000.0;
var
  Noise: TNoiseGen;
  BaseValue: Double;
  ShiftedValue: Double;
begin
  Noise := TNoiseGen.Create(2468);
  try
    BaseValue := Noise.Noise1D(0.25);
    ShiftedValue := Noise.Noise1D(0.25 + LARGE_SHIFT_X);
    CheckNear(BaseValue, ShiftedValue, 0.0,
      'Noise1D stays stable across large 256-periodic X shifts');
    CheckNear(Noise.Noise2D(0.25, 0.75),
      Noise.Noise2D(0.25 + LARGE_SHIFT_X, 0.75 + LARGE_SHIFT_Y), 0.0,
      'Noise2D stays stable across large 256-periodic XY shifts');
    CheckNear(Noise.Noise3D(0.25, 0.75, 1.25),
      Noise.Noise3D(0.25 + LARGE_SHIFT_X, 0.75 + LARGE_SHIFT_Y, 1.25 + LARGE_SHIFT_Z), 0.0,
      'Noise3D stays stable across large 256-periodic XYZ shifts');
    CheckNear(Noise.FBM1D(0.25, 4), Noise.FBM1D(0.25 + LARGE_SHIFT_X, 4), 0.0,
      'FBM1D stays stable across large 256-periodic X shifts');
    CheckNear(Noise.FBM2D(0.25, 0.75, 4),
      Noise.FBM2D(0.25 + LARGE_SHIFT_X, 0.75 + LARGE_SHIFT_Y, 4), 0.0,
      'FBM2D stays stable across large 256-periodic XY shifts');
    CheckNear(Noise.FBM3D(0.25, 0.75, 1.25, 4),
      Noise.FBM3D(0.25 + LARGE_SHIFT_X, 0.75 + LARGE_SHIFT_Y, 1.25 + LARGE_SHIFT_Z, 4), 0.0,
      'FBM3D stays stable across large 256-periodic XYZ shifts');
  finally
    Noise.Free;
  end;
end;

procedure TestNoiseHugeFiniteLatticeCoordinatesStayStable;
const
  HUGE_X: Double = 1.0e300;
  HUGE_Y: Double = -1.0e300;
  HUGE_Z: Double = 1.0e300;
var
  Noise: TNoiseGen;
begin
  Noise := TNoiseGen.Create(2468);
  try
    CheckNear(0.0, Noise.Noise1D(HUGE_X), 0.0,
      'Noise1D keeps huge finite lattice coordinates stable');
    CheckNear(0.0, Noise.Noise2D(HUGE_X, HUGE_Y), 0.0,
      'Noise2D keeps huge finite lattice coordinates stable');
    CheckNear(0.0, Noise.Noise3D(HUGE_X, HUGE_Y, HUGE_Z), 0.0,
      'Noise3D keeps huge finite lattice coordinates stable');
    CheckNear(0.0, Noise.FBM1D(HUGE_X, 4), 0.0,
      'FBM1D keeps huge finite lattice coordinates stable');
    CheckNear(0.0, Noise.FBM2D(HUGE_X, HUGE_Y, 4), 0.0,
      'FBM2D keeps huge finite lattice coordinates stable');
    CheckNear(0.0, Noise.FBM3D(HUGE_X, HUGE_Y, HUGE_Z, 4), 0.0,
      'FBM3D keeps huge finite lattice coordinates stable');
  finally
    Noise.Free;
  end;
end;

procedure TestFBMRejectsNonFiniteOctaveCoordinates;
var
  Noise: TNoiseGen;
  Caught: Boolean;
  ErrorMessage: string;
begin
  Noise := TNoiseGen.Create(2468);
  try
    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM1D(1.0e308, 2);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM1D rejects non-finite octave coordinates');
    CheckEqual('TNoiseGen.FBM1D: octave AX must be finite', ErrorMessage,
      'FBM1D reports owner-level octave finite-contract message');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM2D(1.0e308, 0.75, 2);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM2D rejects non-finite octave AX coordinates');
    CheckEqual('TNoiseGen.FBM2D: octave AX must be finite', ErrorMessage,
      'FBM2D reports owner-level octave AX finite-contract message');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM2D(0.25, 1.0e308, 2);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM2D rejects non-finite octave coordinates');
    CheckEqual('TNoiseGen.FBM2D: octave AY must be finite', ErrorMessage,
      'FBM2D reports owner-level octave finite-contract message');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM3D(1.0e308, 0.75, 1.25, 2);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM3D rejects non-finite octave AX coordinates');
    CheckEqual('TNoiseGen.FBM3D: octave AX must be finite', ErrorMessage,
      'FBM3D reports owner-level octave AX finite-contract message');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM3D(0.25, 1.0e308, 1.25, 2);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM3D rejects non-finite octave AY coordinates');
    CheckEqual('TNoiseGen.FBM3D: octave AY must be finite', ErrorMessage,
      'FBM3D reports owner-level octave AY finite-contract message');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM3D(0.25, 0.75, 1.0e308, 2);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM3D rejects non-finite octave coordinates');
    CheckEqual('TNoiseGen.FBM3D: octave AZ must be finite', ErrorMessage,
      'FBM3D reports owner-level octave finite-contract message');
  finally
    Noise.Free;
  end;
end;

procedure TestFBMRejectsNonFiniteOctaveAmplitude;
var
  Noise: TNoiseGen;
  Caught: Boolean;
  ErrorMessage: string;
begin
  Noise := TNoiseGen.Create(2468);
  try
    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM1D(0.25, 3, 2.0, 1.0e308);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM1D rejects non-finite octave amplitude');
    CheckEqual('TNoiseGen.FBM1D: octave amplitude must be finite', ErrorMessage,
      'FBM1D reports owner-level octave amplitude message');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM2D(0.25, 0.75, 3, 2.0, 1.0e308);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM2D rejects non-finite octave amplitude');
    CheckEqual('TNoiseGen.FBM2D: octave amplitude must be finite', ErrorMessage,
      'FBM2D reports owner-level octave amplitude message');

    Caught := False;
    ErrorMessage := '';
    try
      Noise.FBM3D(0.25, 0.75, 1.25, 3, 2.0, 1.0e308);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM3D rejects non-finite octave amplitude');
    CheckEqual('TNoiseGen.FBM3D: octave amplitude must be finite', ErrorMessage,
      'FBM3D reports owner-level octave amplitude message');
  finally
    Noise.Free;
  end;
end;

procedure TestFBMRejectsNonFiniteAccumulatedResult;
const
  OVERFLOWING_FBM_OCTAVES = 7448;
  OVERFLOWING_FBM_LACUNARITY = 1.0;
  OVERFLOWING_FBM_GAIN = 1.1;
var
  Noise: TNoiseGen;
  Caught: Boolean;
  ErrorClass: string;
  ErrorMessage: string;
begin
  Noise := TNoiseGen.Create(2468);
  try
    Caught := False;
    ErrorClass := '';
    ErrorMessage := '';
    try
      Noise.FBM1D(0.25, OVERFLOWING_FBM_OCTAVES, OVERFLOWING_FBM_LACUNARITY, OVERFLOWING_FBM_GAIN);
    except
      on E: Exception do
      begin
        ErrorClass := E.ClassName;
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM1D rejects non-finite accumulated result');
    CheckEqual('EArgumentError', ErrorClass,
      'FBM1D maps accumulated-result overflow into the public owner-level exception');
    CheckEqual('TNoiseGen.FBM1D: accumulated result must be finite', ErrorMessage,
      'FBM1D reports owner-level accumulated-result message');

    Caught := False;
    ErrorClass := '';
    ErrorMessage := '';
    try
      Noise.FBM2D(0.25, 0.75, OVERFLOWING_FBM_OCTAVES, OVERFLOWING_FBM_LACUNARITY,
        OVERFLOWING_FBM_GAIN);
    except
      on E: Exception do
      begin
        ErrorClass := E.ClassName;
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM2D rejects non-finite accumulated result');
    CheckEqual('EArgumentError', ErrorClass,
      'FBM2D maps accumulated-result overflow into the public owner-level exception');
    CheckEqual('TNoiseGen.FBM2D: accumulated result must be finite', ErrorMessage,
      'FBM2D reports owner-level accumulated-result message');

    Caught := False;
    ErrorClass := '';
    ErrorMessage := '';
    try
      Noise.FBM3D(0.25, 0.75, 1.25, OVERFLOWING_FBM_OCTAVES, OVERFLOWING_FBM_LACUNARITY,
        OVERFLOWING_FBM_GAIN);
    except
      on E: Exception do
      begin
        ErrorClass := E.ClassName;
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'FBM3D rejects non-finite accumulated result');
    CheckEqual('EArgumentError', ErrorClass,
      'FBM3D maps accumulated-result overflow into the public owner-level exception');
    CheckEqual('TNoiseGen.FBM3D: accumulated result must be finite', ErrorMessage,
      'FBM3D reports owner-level accumulated-result message');
  finally
    Noise.Free;
  end;
end;

procedure TestNoisePrecisionCeilingFollowsStoredDoubleValue;
const
  SUBUNIT_PRECISION_CEILING: Double = 4503599627370496.0; // 2^52
  SUBUNIT_DELTA: Double = 0.25;
var
  Noise: TNoiseGen;
  LargeX: Double;
  LargeY: Double;
  LargeZ: Double;
begin
  LargeX := SUBUNIT_PRECISION_CEILING;
  LargeY := -SUBUNIT_PRECISION_CEILING;
  LargeZ := SUBUNIT_PRECISION_CEILING;

  CheckEqual(Int64(1), Int64(Ord(LargeX + SUBUNIT_DELTA = LargeX)),
    'Double precision ceiling swallows sub-unit X deltas');
  CheckEqual(Int64(1), Int64(Ord(LargeY + SUBUNIT_DELTA = LargeY)),
    'Double precision ceiling swallows sub-unit Y deltas');
  CheckEqual(Int64(1), Int64(Ord(LargeZ + SUBUNIT_DELTA = LargeZ)),
    'Double precision ceiling swallows sub-unit Z deltas');

  Noise := TNoiseGen.Create(2468);
  try
    CheckNear(Noise.Noise1D(LargeX), Noise.Noise1D(LargeX + SUBUNIT_DELTA), 0.0,
      'Noise1D follows the stored Double value past the sub-unit precision ceiling');
    CheckNear(Noise.Noise2D(LargeX, LargeY),
      Noise.Noise2D(LargeX + SUBUNIT_DELTA, LargeY + SUBUNIT_DELTA), 0.0,
      'Noise2D follows the stored Double value past the sub-unit precision ceiling');
    CheckNear(Noise.Noise3D(LargeX, LargeY, LargeZ),
      Noise.Noise3D(LargeX + SUBUNIT_DELTA, LargeY + SUBUNIT_DELTA, LargeZ + SUBUNIT_DELTA), 0.0,
      'Noise3D follows the stored Double value past the sub-unit precision ceiling');
    CheckNear(Noise.FBM1D(LargeX, 4), Noise.FBM1D(LargeX + SUBUNIT_DELTA, 4), 0.0,
      'FBM1D follows the stored Double value past the sub-unit precision ceiling');
    CheckNear(Noise.FBM2D(LargeX, LargeY, 4),
      Noise.FBM2D(LargeX + SUBUNIT_DELTA, LargeY + SUBUNIT_DELTA, 4), 0.0,
      'FBM2D follows the stored Double value past the sub-unit precision ceiling');
    CheckNear(Noise.FBM3D(LargeX, LargeY, LargeZ, 4),
      Noise.FBM3D(LargeX + SUBUNIT_DELTA, LargeY + SUBUNIT_DELTA, LargeZ + SUBUNIT_DELTA, 4), 0.0,
      'FBM3D follows the stored Double value past the sub-unit precision ceiling');
  finally
    Noise.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.math.noise');
  T.Run('noise repeatability', @TestNoiseRepeatability);
  T.Run('zero seed uses deterministic default', @TestZeroSeedUsesDeterministicDefault);
  T.Run('noise reference vectors', @TestNoiseReferenceVectors);
  T.Run('noise invalid inputs', @TestNoiseInvalidInputs);
  T.Run('large periodic coordinates stay stable', @TestNoiseLargePeriodicCoordinatesStayStable);
  T.Run('huge finite lattice coordinates stay stable', @TestNoiseHugeFiniteLatticeCoordinatesStayStable);
  T.Run('FBM rejects non-finite octave coordinates', @TestFBMRejectsNonFiniteOctaveCoordinates);
  T.Run('FBM rejects non-finite octave amplitude', @TestFBMRejectsNonFiniteOctaveAmplitude);
  T.Run('FBM rejects non-finite accumulated result', @TestFBMRejectsNonFiniteAccumulatedResult);
  T.Run('precision ceiling follows stored Double value', @TestNoisePrecisionCeilingFollowsStoredDoubleValue);
  T.Summary;
end.
