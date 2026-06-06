program test_random;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.math.vec,
  nextpas.core.math.random;

type
  TWeight3 = array[0..2] of Single;
  TInt5 = array[0..4] of Integer;
  TSingleBitCast = packed record
    case Integer of
      0: (Value: Single);
      1: (Bits: LongWord);
  end;

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

procedure CheckArray5(const AExpected0, AExpected1, AExpected2, AExpected3, AExpected4: Integer;
  const AActual: TInt5; const AMessage: string);
begin
  CheckEqual(Int64(AExpected0), Int64(AActual[0]), AMessage + '[0]');
  CheckEqual(Int64(AExpected1), Int64(AActual[1]), AMessage + '[1]');
  CheckEqual(Int64(AExpected2), Int64(AActual[2]), AMessage + '[2]');
  CheckEqual(Int64(AExpected3), Int64(AActual[3]), AMessage + '[3]');
  CheckEqual(Int64(AExpected4), Int64(AActual[4]), AMessage + '[4]');
end;

function SingleNaN: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := $7FC00000;
  Result := LValue.Value;
end;

function SingleInfinity: Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Bits := $7F800000;
  Result := LValue.Value;
end;

procedure TestSeedDeterminism;
var
  A, B: TRandomGen;
  SavedState: TRandomState;
  FirstFromSaved: Integer;
begin
  A := TRandomGen.Create(123456789);
  B := TRandomGen.Create(123456789);
  try
    CheckEqual(Int64(702724636), Int64(A.NextInt), 'seeded sequence first NextInt');
    CheckEqual(Int64(702724636), Int64(B.NextInt), 'same seed matches first NextInt');
    CheckNear(0.7581309528642696, A.NextDouble, 0.000000000000001,
      'seeded sequence second NextDouble');
    CheckNear(0.7581309528642696, B.NextDouble, 0.000000000000001,
      'same seed matches second NextDouble');

    SavedState := A.State;
    FirstFromSaved := A.NextInt;
    A.State := SavedState;
    CheckEqual(Int64(FirstFromSaved), Int64(A.NextInt), 'state restore is deterministic');
  finally
    B.Free;
    A.Free;
  end;
end;

procedure TestRangeBoundaries;
var
  Rng: TRandomGen;
  I: Integer;
  IntValue: Integer;
  FloatValue: Single;
begin
  Rng := TRandomGen.Create(42);
  try
    CheckEqual(Int64(1540949677), Int64(Rng.NextIntRange(Low(Integer), High(Integer))),
      'full integer range keeps signed bounds');
    CheckEqual(Int64(5), Int64(Rng.NextIntRange(5, 5)), 'equal integer range returns bound');
    CheckNear(2.5, Rng.NextFloatRange(2.5, 2.5), 0.0, 'equal float range returns bound');

    for I := 0 to 127 do
    begin
      IntValue := Rng.NextIntRange(-3, 3);
      Check((IntValue >= -3) and (IntValue <= 3), 'integer range is inclusive');
      FloatValue := Rng.NextFloatRange(-2.0, 2.0);
      Check((FloatValue >= -2.0) and (FloatValue < 2.0), 'float range is half-open');
    end;
  finally
    Rng.Free;
  end;
end;

procedure TestInvalidRangesFailFast;
var
  Rng: TRandomGen;
  Caught: Boolean;
begin
  Rng := TRandomGen.Create(7);
  try
    Caught := False;
    try
      Rng.NextIntRange(10, 1);
    except
      on E: EArgumentError do
        Caught := True;
    end;
    Check(Caught, 'NextIntRange rejects Min > Max');

    Caught := False;
    try
      Rng.NextFloatRange(3.0, 2.0);
    except
      on E: EArgumentError do
        Caught := True;
    end;
    Check(Caught, 'NextFloatRange rejects Min > Max');
  finally
    Rng.Free;
  end;
end;

procedure TestProbabilityDiceWeightedAndShuffle;
var
  Rng: TRandomGen;
  Weights: TWeight3;
  Values: TInt5;
  Total: Integer;
  Caught: Boolean;
begin
  Rng := TRandomGen.Create(98765);
  try
    CheckEqual(False, Rng.NextBool(-1.0), 'negative probability clamps to false');
    CheckEqual(False, Rng.NextBool(0.0), 'zero probability returns false');
    CheckEqual(True, Rng.NextBool(1.0), 'one probability returns true');
    CheckEqual(True, Rng.NextBool(2.0), 'probability above one clamps to true');

    CheckEqual(Int64(0), Int64(Rng.Roll(0)), 'Roll with zero sides returns zero');
    CheckEqual(Int64(0), Int64(Rng.Roll(-6)), 'Roll with negative sides returns zero');
    CheckEqual(Int64(0), Int64(Rng.RollMultiple(0, 6)), 'zero dice returns zero');
    CheckEqual(Int64(0), Int64(Rng.RollMultiple(3, 0)), 'zero-sided dice returns zero');
    Total := Rng.RollMultiple(3, 6);
    Check((Total >= 3) and (Total <= 18), 'RollMultiple stays within dice bounds');

    Weights[0] := 0.0;
    Weights[1] := 1.0;
    Weights[2] := 0.0;
    CheckEqual(Int64(1), Int64(Rng.WeightedChoice(Weights)), 'single positive weight is selected');

    Caught := False;
    try
      Rng.WeightedChoice([]);
    except
      on E: EArgumentError do
        Caught := True;
    end;
    Check(Caught, 'WeightedChoice rejects an empty list');

    Weights[0] := 0.0;
    Weights[1] := -1.0;
    Weights[2] := 1.0;
    Caught := False;
    try
      Rng.WeightedChoice(Weights);
    except
      on E: EArgumentError do
        Caught := True;
    end;
    Check(Caught, 'WeightedChoice rejects negative weights');
  finally
    Rng.Free;
  end;

  Rng := TRandomGen.Create(98765);
  try
    Values[0] := 1;
    Values[1] := 2;
    Values[2] := 3;
    Values[3] := 4;
    Values[4] := 5;
    Rng.Shuffle(Values);
    CheckArray5(2, 1, 5, 4, 3, Values, 'Shuffle is deterministic for a seed');
  finally
    Rng.Free;
  end;
end;

procedure TestGaussianAndCircleVectors;
var
  Rng: TRandomGen;
  V: TVec2f;
begin
  Rng := TRandomGen.Create(123456789);
  try
    CheckNear(0.07632880659408693, Rng.NextGaussian, 0.000001,
      'NextGaussian is deterministic for a seed');
  finally
    Rng.Free;
  end;

  Rng := TRandomGen.Create(123456789);
  try
    V := Rng.NextVec2InCircle;
    Check(V.Length <= 1.0, 'NextVec2InCircle stays inside the unit circle');
    CheckNear(-0.40613178, V.X, 0.000001, 'NextVec2InCircle deterministic X');
    CheckNear(0.7701869, V.Y, 0.000001, 'NextVec2InCircle deterministic Y');

    V := Rng.NextVec2OnCircle;
    CheckNear(1.0, V.Length, 0.000001, 'NextVec2OnCircle stays on the unit circle');
    CheckNear(0.9906606, V.X, 0.000001, 'NextVec2OnCircle deterministic X');
    CheckNear(-0.1363510, V.Y, 0.000001, 'NextVec2OnCircle deterministic Y');
  finally
    Rng.Free;
  end;
end;

procedure TestNonFiniteParameterValidation;
var
  Rng: TRandomGen;
  Weights: TWeight3;
  Caught: Boolean;
begin
  Rng := TRandomGen.Create(123);
  try
    Caught := False;
    try
      Rng.NextFloatRange(SingleNaN, 1.0);
    except
      on E: EArgumentError do
        Caught := True;
    end;
    Check(Caught, 'NextFloatRange rejects NaN bounds');

    Caught := False;
    try
      Rng.NextFloatRange(-1.0, SingleInfinity);
    except
      on E: EArgumentError do
        Caught := True;
    end;
    Check(Caught, 'NextFloatRange rejects infinite bounds');

    Weights[0] := 1.0;
    Weights[1] := SingleNaN;
    Weights[2] := 2.0;
    Caught := False;
    try
      Rng.WeightedChoice(Weights);
    except
      on E: EArgumentError do
        Caught := True;
    end;
    Check(Caught, 'WeightedChoice rejects NaN weights');

    Weights[0] := 1.0;
    Weights[1] := SingleInfinity;
    Weights[2] := 2.0;
    Caught := False;
    try
      Rng.WeightedChoice(Weights);
    except
      on E: EArgumentError do
        Caught := True;
    end;
    Check(Caught, 'WeightedChoice rejects infinite weights');
  finally
    Rng.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.math.random');
  T.Run('seed determinism', @TestSeedDeterminism);
  T.Run('range boundaries', @TestRangeBoundaries);
  T.Run('invalid ranges fail fast', @TestInvalidRangesFailFast);
  T.Run('probability dice weighted choice and shuffle', @TestProbabilityDiceWeightedAndShuffle);
  T.Run('gaussian and circle vectors', @TestGaussianAndCircleVectors);
  T.Run('non-finite parameter validation', @TestNonFiniteParameterValidation);
  T.Summary;
end.
