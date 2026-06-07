program test_random;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.math.scalar,
  nextpas.core.math.vec,
  nextpas.core.math.random;

type
  TWeight2 = array[0..1] of Single;
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

function PreviousSingleValue(const AValue: Single): Single;
var
  LValue: TSingleBitCast;
begin
  LValue.Value := AValue;
  if LValue.Bits = 0 then
    LValue.Bits := $80000001
  else if (LValue.Bits and $80000000) = 0 then
    Dec(LValue.Bits)
  else
    Inc(LValue.Bits);
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
    CheckEqual(Int64(1644187685), Int64(A.NextInt), 'seeded sequence first NextInt');
    CheckEqual(Int64(1644187685), Int64(B.NextInt), 'same seed matches first NextInt');
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

procedure TestZeroSeedUsesDeterministicDefault;
var
  A, B: TRandomGen;
  FirstInt: Integer;
  FirstDouble: Double;
begin
  A := TRandomGen.Create(0);
  B := TRandomGen.Create(0);
  try
    FirstInt := A.NextInt;
    CheckEqual(Int64(FirstInt), Int64(B.NextInt),
      'zero seed uses the same deterministic default NextInt sequence');

    FirstDouble := A.NextDouble;
    CheckNear(FirstDouble, B.NextDouble, 0.0,
      'zero seed uses the same deterministic default NextDouble sequence');

    A.SetSeed(0);
    CheckEqual(Int64(FirstInt), Int64(A.NextInt),
      'SetSeed(0) resets the deterministic default NextInt sequence');
    CheckNear(FirstDouble, A.NextDouble, 0.0,
      'SetSeed(0) resets the deterministic default NextDouble sequence');
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

procedure TestStateForcedHalfOpenBoundaries;
const
  MAX_NEXT_FLOAT: Double = 16777215.0 / 16777216.0;
  MAX_NEXT_DOUBLE: Double = 9007199254740991.0 / 9007199254740992.0;
var
  Rng: TRandomGen;
  ZeroState: TRandomState;
  MaxState: TRandomState;
begin
  ZeroState.S0 := 0;
  ZeroState.S1 := 0;
  MaxState.S0 := High(UInt64);
  MaxState.S1 := 0;

  Rng := TRandomGen.Create(42);
  try
    Rng.State := ZeroState;
    CheckEqual(Int64(Low(Integer)), Int64(Rng.NextInt),
      'NextInt zero state returns exact signed lower bound');

    Rng.State := MaxState;
    CheckEqual(Int64(High(Integer)), Int64(Rng.NextInt),
      'NextInt max state returns exact signed upper bound');

    Rng.State := ZeroState;
    CheckNear(0.0, Rng.NextFloat, 0.0, 'NextFloat zero state returns exact lower bound');

    Rng.State := MaxState;
    CheckNear(MAX_NEXT_FLOAT, Rng.NextFloat, 0.0,
      'NextFloat max state returns the exact last representable sample');
    Rng.State := MaxState;
    Check(Rng.NextFloat < 1.0, 'NextFloat max state stays below 1');

    Rng.State := ZeroState;
    CheckNear(0.0, Rng.NextDouble, 0.0, 'NextDouble zero state returns exact lower bound');

    Rng.State := MaxState;
    CheckNear(MAX_NEXT_DOUBLE, Rng.NextDouble, 0.0,
      'NextDouble max state returns the exact last representable sample');
    Rng.State := MaxState;
    Check(Rng.NextDouble < 1.0, 'NextDouble max state stays below 1');

    Rng.State := ZeroState;
    CheckNear(2.5, Rng.NextFloatRange(2.5, 3.5), 0.0,
      'NextFloatRange zero state returns exact lower bound');

    Rng.State := MaxState;
    CheckNear(PreviousSingleValue(3.5), Rng.NextFloatRange(2.5, 3.5), 0.0,
      'NextFloatRange max state fail-closes to the predecessor of upper bound');
    Rng.State := MaxState;
    Check(Rng.NextFloatRange(2.5, 3.5) < 3.5,
      'NextFloatRange max state stays below upper bound');
  finally
    Rng.Free;
  end;
end;

procedure TestIntegerRangesRejectModuloBiasTailStates;
var
  Rng: TRandomGen;
  MaxState: TRandomState;
begin
  MaxState.S0 := High(UInt64);
  MaxState.S1 := 0;

  Rng := TRandomGen.Create(42);
  try
    Rng.State := MaxState;
    CheckEqual(Int64(9), Int64(Rng.NextIntRange(0, 9)),
      'NextIntRange rejects modulo-bias tail sample for 10-value span');

    Rng.State := MaxState;
    CheckEqual(Int64(3), Int64(Rng.NextIntRange(-3, 3)),
      'NextIntRange rejects modulo-bias tail sample for signed 7-value span');

    Rng.State := MaxState;
    CheckEqual(Int64(6), Int64(Rng.Roll(6)),
      'Roll rejects modulo-bias tail sample through NextIntRange');
  finally
    Rng.Free;
  end;
end;

procedure TestLargeFiniteFloatRangeStaysFiniteAndBounded;
const
  LARGE_MIN: Single = -3.0e38;
  LARGE_MAX: Single = 3.0e38;
var
  Rng: TRandomGen;
  I: Integer;
  FloatValue: Single;
begin
  Rng := TRandomGen.Create(42);
  try
    for I := 1 to 8 do
    begin
      FloatValue := Rng.NextFloatRange(LARGE_MIN, LARGE_MAX);
      Check((FloatValue >= LARGE_MIN) and (FloatValue <= LARGE_MAX),
        'large finite float range stays finite and bounded');
    end;
  finally
    Rng.Free;
  end;
end;

procedure TestWeightedChoiceLargeFiniteWeightsStayScaleInvariant;
const
  SMALL_WEIGHTS: TWeight2 = (3.0, 1.0);
  LARGE_WEIGHTS: TWeight2 = (3.0e38, 1.0e38);
var
  SmallRng: TRandomGen;
  LargeRng: TRandomGen;
  I: Integer;
begin
  SmallRng := TRandomGen.Create(2468);
  LargeRng := TRandomGen.Create(2468);
  try
    for I := 1 to 8 do
      CheckEqual(Int64(SmallRng.WeightedChoice(SMALL_WEIGHTS)),
        Int64(LargeRng.WeightedChoice(LARGE_WEIGHTS)),
        'WeightedChoice stays scale-invariant for large finite weights');
  finally
    LargeRng.Free;
    SmallRng.Free;
  end;
end;

procedure TestWeightedChoiceRejectsAllZeroWeights;
var
  Rng: TRandomGen;
  Weights: TWeight3;
  Caught: Boolean;
  ErrorMessage: string;
begin
  Rng := TRandomGen.Create(1);
  try
    Weights[0] := 0.0;
    Weights[1] := 0.0;
    Weights[2] := 0.0;
    Caught := False;
    ErrorMessage := '';
    try
      Rng.WeightedChoice(Weights);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'WeightedChoice rejects all-zero weights');
    CheckEqual('TRandomGen.WeightedChoice: at least one weight must be positive', ErrorMessage,
      'WeightedChoice reports owner-level all-zero weight message');
  finally
    Rng.Free;
  end;
end;

procedure TestWeightedChoiceZeroPickSkipsZeroWeightPrefixes;
var
  Rng: TRandomGen;
  Weights: TWeight3;
  ZeroPickState: TRandomState;
begin
  ZeroPickState.S0 := 0;
  ZeroPickState.S1 := 0;

  Rng := TRandomGen.Create(1);
  try
    Rng.State := ZeroPickState;
    Weights[0] := 0.0;
    Weights[1] := 0.0;
    Weights[2] := 1.0;
    CheckEqual(Int64(2), Int64(Rng.WeightedChoice(Weights)),
      'WeightedChoice pick=0 skips zero-weight prefixes');
  finally
    Rng.Free;
  end;
end;

procedure TestWeightedChoiceMaxPickKeepsTailWeightReachable;
var
  Rng: TRandomGen;
  Weights: TWeight2;
  MaxPickState: TRandomState;
begin
  MaxPickState.S0 := High(UInt64);
  MaxPickState.S1 := 0;

  Rng := TRandomGen.Create(1);
  try
    Rng.State := MaxPickState;
    Weights[0] := 16777216.0;
    Weights[1] := 1.0;
    CheckEqual(Int64(1), Int64(Rng.WeightedChoice(Weights)),
      'WeightedChoice max pick keeps a tiny positive tail weight reachable');
  finally
    Rng.Free;
  end;
end;

procedure TestInvalidRangesFailFast;
var
  Rng: TRandomGen;
  Caught: Boolean;
  ErrorMessage: string;
begin
  Rng := TRandomGen.Create(7);
  try
    Caught := False;
    ErrorMessage := '';
    try
      Rng.NextIntRange(10, 1);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'NextIntRange rejects Min > Max');
    CheckEqual('TRandomGen.NextIntRange: AMin must be <= AMax', ErrorMessage,
      'NextIntRange reports owner-level reversed-range message');

    Caught := False;
    ErrorMessage := '';
    try
      Rng.NextFloatRange(3.0, 2.0);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'NextFloatRange rejects Min > Max');
    CheckEqual('TRandomGen.NextFloatRange: AMin must be <= AMax', ErrorMessage,
      'NextFloatRange reports owner-level reversed-range message');
  finally
    Rng.Free;
  end;
end;

procedure TestRollMultipleRejectsOverflowingTotal;
var
  Rng: TRandomGen;
  Caught: Boolean;
  ErrorClass: string;
  ErrorMessage: string;
begin
  Rng := TRandomGen.Create(2);
  try
    Caught := False;
    ErrorClass := '';
    ErrorMessage := '';
    try
      Rng.RollMultiple(2, High(Integer));
    except
      on E: Exception do
      begin
        ErrorClass := E.ClassName;
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'RollMultiple rejects overflowing total range');
    CheckEqual('EArgumentError', ErrorClass,
      'RollMultiple maps overflowing total range into the public owner-level exception');
    CheckEqual('TRandomGen.RollMultiple: ADice * ASides must fit Integer', ErrorMessage,
      'RollMultiple reports owner-level total-range message');
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
  ErrorMessage: string;
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
    CheckEqual(Int64(0), Int64(Rng.RollMultiple(-3, 6)), 'negative dice returns zero');
    CheckEqual(Int64(0), Int64(Rng.RollMultiple(3, 0)), 'zero-sided dice returns zero');
    CheckEqual(Int64(0), Int64(Rng.RollMultiple(3, -6)), 'negative-sided dice returns zero');
    Total := Rng.RollMultiple(3, 6);
    Check((Total >= 3) and (Total <= 18), 'RollMultiple stays within dice bounds');

    Weights[0] := 0.0;
    Weights[1] := 1.0;
    Weights[2] := 0.0;
    CheckEqual(Int64(1), Int64(Rng.WeightedChoice(Weights)), 'single positive weight is selected');

    Caught := False;
    ErrorMessage := '';
    try
      Rng.WeightedChoice([]);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'WeightedChoice rejects an empty list');
    CheckEqual('TRandomGen.WeightedChoice: weights must not be empty', ErrorMessage,
      'WeightedChoice reports owner-level empty-list message');

    Weights[0] := 0.0;
    Weights[1] := -1.0;
    Weights[2] := 1.0;
    Caught := False;
    ErrorMessage := '';
    try
      Rng.WeightedChoice(Weights);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'WeightedChoice rejects negative weights');
    CheckEqual('TRandomGen.WeightedChoice: weights must be non-negative', ErrorMessage,
      'WeightedChoice reports owner-level negative-weight message');
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

procedure TestGaussianClampKeepsZeroStateFinite;
var
  Rng: TRandomGen;
  ZeroState: TRandomState;
  GaussianValue: Single;
begin
  ZeroState.S0 := 0;
  ZeroState.S1 := 0;

  Rng := TRandomGen.Create(1);
  try
    Rng.State := ZeroState;
    GaussianValue := Rng.NextGaussian;
    Check(not nextpas.core.math.scalar.IsNaN(GaussianValue),
      'NextGaussian zero-state clamp avoids NaN');
    Check(not nextpas.core.math.scalar.IsInfinite(GaussianValue),
      'NextGaussian zero-state clamp avoids infinity');
    CheckNear(6.7861404, GaussianValue, 0.000001,
      'NextGaussian zero-state clamp keeps deterministic finite fallback');
  finally
    Rng.Free;
  end;
end;

procedure TestNonFiniteParameterValidation;
var
  Rng: TRandomGen;
  Weights: TWeight3;
  Caught: Boolean;
  ErrorMessage: string;
begin
  Rng := TRandomGen.Create(123);
  try
    Caught := False;
    ErrorMessage := '';
    try
      Rng.NextFloatRange(SingleNaN, 1.0);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'NextFloatRange rejects NaN bounds');
    CheckEqual('TRandomGen.NextFloatRange: AMin must be finite', ErrorMessage,
      'NextFloatRange reports owner-level finite-contract message for NaN min');

    Caught := False;
    ErrorMessage := '';
    try
      Rng.NextFloatRange(-1.0, SingleInfinity);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'NextFloatRange rejects infinite bounds');
    CheckEqual('TRandomGen.NextFloatRange: AMax must be finite', ErrorMessage,
      'NextFloatRange reports owner-level finite-contract message for infinite max');

    Weights[0] := 1.0;
    Weights[1] := SingleNaN;
    Weights[2] := 2.0;
    Caught := False;
    ErrorMessage := '';
    try
      Rng.WeightedChoice(Weights);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'WeightedChoice rejects NaN weights');
    CheckEqual('TRandomGen.WeightedChoice: weights must be finite', ErrorMessage,
      'WeightedChoice reports owner-level finite-contract message for NaN weight');

    Weights[0] := 1.0;
    Weights[1] := SingleInfinity;
    Weights[2] := 2.0;
    Caught := False;
    ErrorMessage := '';
    try
      Rng.WeightedChoice(Weights);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'WeightedChoice rejects infinite weights');
    CheckEqual('TRandomGen.WeightedChoice: weights must be finite', ErrorMessage,
      'WeightedChoice reports owner-level finite-contract message for infinite weight');
  finally
    Rng.Free;
  end;
end;

procedure TestNextBoolRejectsNonFiniteProbability;
var
  Rng: TRandomGen;
  Caught: Boolean;
  ErrorMessage: string;
begin
  Rng := TRandomGen.Create(123);
  try
    Caught := False;
    ErrorMessage := '';
    try
      Rng.NextBool(SingleNaN);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'NextBool rejects NaN probability');
    CheckEqual('TRandomGen.NextBool: AProbability must be finite', ErrorMessage,
      'NextBool reports public finite-contract message for NaN');

    Caught := False;
    ErrorMessage := '';
    try
      Rng.NextBool(SingleInfinity);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'NextBool rejects positive infinite probability');
    CheckEqual('TRandomGen.NextBool: AProbability must be finite', ErrorMessage,
      'NextBool reports public finite-contract message for positive infinity');

    Caught := False;
    ErrorMessage := '';
    try
      Rng.NextBool(-SingleInfinity);
    except
      on E: EArgumentError do
      begin
        ErrorMessage := E.Message;
        Caught := True;
      end;
    end;
    Check(Caught, 'NextBool rejects negative infinite probability');
    CheckEqual('TRandomGen.NextBool: AProbability must be finite', ErrorMessage,
      'NextBool reports public finite-contract message for negative infinity');
  finally
    Rng.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.math.random');
  T.Run('seed determinism', @TestSeedDeterminism);
  T.Run('zero seed uses deterministic default', @TestZeroSeedUsesDeterministicDefault);
  T.Run('range boundaries', @TestRangeBoundaries);
  T.Run('state-forced half-open boundaries', @TestStateForcedHalfOpenBoundaries);
  T.Run('integer ranges reject modulo-bias tail states', @TestIntegerRangesRejectModuloBiasTailStates);
  T.Run('large finite float range stays finite and bounded',
    @TestLargeFiniteFloatRangeStaysFiniteAndBounded);
  T.Run('WeightedChoice large finite weights stay scale-invariant',
    @TestWeightedChoiceLargeFiniteWeightsStayScaleInvariant);
  T.Run('WeightedChoice rejects all-zero weights', @TestWeightedChoiceRejectsAllZeroWeights);
  T.Run('WeightedChoice zero-pick skips zero-weight prefixes',
    @TestWeightedChoiceZeroPickSkipsZeroWeightPrefixes);
  T.Run('WeightedChoice max pick keeps tail weight reachable',
    @TestWeightedChoiceMaxPickKeepsTailWeightReachable);
  T.Run('invalid ranges fail fast', @TestInvalidRangesFailFast);
  T.Run('RollMultiple rejects overflowing total', @TestRollMultipleRejectsOverflowingTotal);
  T.Run('probability dice weighted choice and shuffle', @TestProbabilityDiceWeightedAndShuffle);
  T.Run('gaussian and circle vectors', @TestGaussianAndCircleVectors);
  T.Run('Gaussian zero-state clamp stays finite', @TestGaussianClampKeepsZeroStateFinite);
  T.Run('non-finite parameter validation', @TestNonFiniteParameterValidation);
  T.Run('NextBool rejects non-finite probability', @TestNextBoolRejectsNonFiniteProbability);
  T.Summary;
end.
