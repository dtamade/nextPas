program test_lockfree_reservoirsampling;

{$mode objfpc}{$H+}

uses
  nextpas.core.fs,
  nextpas.core.lockfree.reservoirsampling,
  nextpas.core.test;

type
  TIntReservoir = specialize TReservoirSampler<Int64>;

procedure TestBasicAdd;
var
  RS: TIntReservoir;
begin
  RS := TIntReservoir.Create(10);
  try
    Check(not RS.IsClosed, 'Should not be closed');
    Check(RS.Add(42) = rsAdded, 'Should add');
    CheckEqual(Int64(1), RS.GetCount, 'Count');
    CheckEqual(Int32(1), RS.GetSampleSize, 'Sample size');
  finally
    RS.Free;
  end;
end;

procedure TestFillReservoir;
var
  RS: TIntReservoir;
  I: Integer;
  LSample: array of Int64;
begin
  RS := TIntReservoir.Create(5);
  try
    for I := 1 to 5 do
      Check(RS.Add(Int64(I)) = rsAdded, 'Should add');

    CheckEqual(Int64(5), RS.GetCount, 'Count');
    CheckEqual(Int32(5), RS.GetSampleSize, 'Sample size');

    { All 5 should be in the reservoir }
    RS.GetSample(LSample);
    Check(Length(LSample) = 5, 'Sample length');
  finally
    RS.Free;
  end;
end;

procedure TestOverflow;
var
  RS: TIntReservoir;
  I: Integer;
  LResult: TReservoirResult;
begin
  RS := TIntReservoir.Create(5);
  try
    for I := 1 to 5 do
      RS.Add(Int64(I));
    { 6th item: should either replace or skip }
    LResult := RS.Add(6);
    Check((LResult = rsReplaced) or (LResult = rsSkipped), 'Should replace or skip');
    CheckEqual(Int64(6), RS.GetCount, 'Count should be 6');
    CheckEqual(Int32(5), RS.GetSampleSize, 'Sample size still 5');
  finally
    RS.Free;
  end;
end;

procedure TestClose;
var
  RS: TIntReservoir;
begin
  RS := TIntReservoir.Create(10);
  try
    RS.Add(1);
    RS.Close;
    Check(RS.IsClosed, 'Should be closed');
    Check(RS.Add(2) = rsClosed, 'Should not add after close');
  finally
    RS.Free;
  end;
end;

procedure TestClear;
var
  RS: TIntReservoir;
begin
  RS := TIntReservoir.Create(10);
  try
    RS.Add(1);
    RS.Add(2);
    CheckEqual(Int64(2), RS.GetCount, 'Before clear');

    RS.Clear;
    CheckEqual(Int64(0), RS.GetCount, 'After clear');
    CheckEqual(Int32(0), RS.GetSampleSize, 'Sample size after clear');
  finally
    RS.Free;
  end;
end;

procedure TestRecreatedSamplersUseDistinctStreams;
var
  LFirst: TIntReservoir;
  LSecond: TIntReservoir;
  LFirstSample: array of Int64;
  LSecondSample: array of Int64;
  LI: Integer;
  LIdentical: Boolean;
begin
  LFirst := TIntReservoir.Create(16);
  try
    for LI := 1 to 256 do
      LFirst.Add(LI);
    LFirst.GetSample(LFirstSample);
  finally
    LFirst.Free;
  end;

  LSecond := TIntReservoir.Create(16);
  try
    for LI := 1 to 256 do
      LSecond.Add(LI);
    LSecond.GetSample(LSecondSample);
  finally
    LSecond.Free;
  end;

  LIdentical := Length(LFirstSample) = Length(LSecondSample);
  if LIdentical then
    for LI := 0 to High(LFirstSample) do
      if LFirstSample[LI] <> LSecondSample[LI] then
      begin
        LIdentical := False;
        Break;
      end;
  Check(not LIdentical, 'Recreated samplers must not repeat the same PRNG stream');
end;

procedure TestReservoirUsesUnbiasedUInt64Draws;
var
  LSource: string;
begin
  LSource := ReadFileText('../../../src/nextpas.core.lockfree.reservoirsampling.pas');
    Check(Pos('function NextRandom: UInt64', LSource) > 0,
      'Reservoir PRNG must expose all 64 random bits');
    Check(Pos('function NextRandomBounded', LSource) > 0,
      'Reservoir must use rejection sampling for bounded draws');
    Check(Pos('mod UInt32(LIdx + 1)', LSource) = 0,
      'Reservoir stream bound must not narrow at 2^32');
end;

begin
  WriteLn('=== test_lockfree_reservoirsampling ===');
  WriteLn;

  TestBasicAdd;
  WriteLn('  + Basic add');

  TestFillReservoir;
  WriteLn('  + Fill reservoir');

  TestOverflow;
  WriteLn('  + Overflow (replace/skip)');

  TestClose;
  WriteLn('  + Close semantics');

  TestClear;
  WriteLn('  + Clear');

  TestRecreatedSamplersUseDistinctStreams;
  WriteLn('  + Recreated sampler seed diversity');

  TestReservoirUsesUnbiasedUInt64Draws;
  WriteLn('  + Unbiased UInt64 bounded draws');

  WriteLn;
  WriteLn('All reservoir sampling tests passed!');
end.
