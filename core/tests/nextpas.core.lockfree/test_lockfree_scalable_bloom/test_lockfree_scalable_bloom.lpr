program test_lockfree_scalable_bloom;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.scalable_bloom,
  nextpas.core.test;

type
  TIntSBF = specialize TScalableBloomFilter<Int64>;

procedure TestSBFBasic;
var
  LBF: TIntSBF;
begin
  LBF := TIntSBF.Create(1000, 0.01);
  try
    LBF.Add(1);
    LBF.Add(2);
    LBF.Add(3);

    Check(LBF.Contains(1), 'Should contain 1');
    Check(LBF.Contains(2), 'Should contain 2');
    Check(LBF.Contains(3), 'Should contain 3');
    Check(not LBF.Contains(999), 'Should not contain 999');
  finally
    LBF.Free;
  end;
end;

procedure TestSBFLayerCount;
var
  LBF: TIntSBF;
  LI: Integer;
begin
  LBF := TIntSBF.Create(100, 0.01);
  try
    CheckEqual(1, LBF.GetLayerCount);

    for LI := 1 to 150 do
      LBF.Add(LI);

    Check(LBF.GetLayerCount >= 1, 'Should have at least 1 layer');
  finally
    LBF.Free;
  end;
end;

procedure TestSBFTotalCount;
var
  LBF: TIntSBF;
begin
  LBF := TIntSBF.Create(1000, 0.01);
  try
    CheckEqual(Int64(0), LBF.GetTotalCount);

    LBF.Add(1);
    CheckEqual(Int64(1), LBF.GetTotalCount);

    LBF.Add(2);
    CheckEqual(Int64(2), LBF.GetTotalCount);
  finally
    LBF.Free;
  end;
end;

procedure TestSBFFalsePositiveRate;
var
  LBF: TIntSBF;
  LI: Integer;
  LFPR: Double;
begin
  LBF := TIntSBF.Create(10000, 0.01);
  try
    for LI := 1 to 1000 do
      LBF.Add(LI);

    for LI := 1 to 1000 do
      Check(LBF.Contains(LI), 'Should contain added item');

    LFPR := LBF.GetEstimatedFPR;
    Check(LFPR > 0, 'FPR should be > 0');
    Check(LFPR < 1, 'FPR should be < 1');
  finally
    LBF.Free;
  end;
end;

procedure TestSBFFalsePositiveEstimateComposesAcrossLayers;
var
  LBF: TIntSBF;
  LBeforeGrowth: Double;
  LAfterGrowth: Double;
  LI: Integer;
begin
  LBF := TIntSBF.Create(10, 0.1);
  try
    for LI := 1 to 10 do
      LBF.Add(LI);
    LBeforeGrowth := LBF.GetEstimatedFPR;

    LBF.Add(11);
    Check(LBF.GetLayerCount = 2, 'Adding past capacity creates a second layer');
    LAfterGrowth := LBF.GetEstimatedFPR;
    Check(LAfterGrowth >= LBeforeGrowth,
      'Union false-positive probability must not decrease when a layer is added');
    Check(LAfterGrowth <= 0.1,
      'Geometric layer allocation must stay within the requested FPR bound');
  finally
    LBF.Free;
  end;
end;

procedure TestSBFClose;
var
  LBF: TIntSBF;
begin
  LBF := TIntSBF.Create(1000, 0.01);
  try
    LBF.Add(1);
    LBF.Close;
    Check(LBF.IsClosed, 'Should be closed');

    LBF.Add(2);
    Check(not LBF.Contains(2), 'Should not contain 2 after close');
  finally
    LBF.Free;
  end;
end;

procedure TestSBFNoFalseNegative;
var
  LBF: TIntSBF;
  LI: Integer;
begin
  LBF := TIntSBF.Create(1000, 0.01);
  try
    for LI := 1 to 500 do
      LBF.Add(LI * 7);

    for LI := 1 to 500 do
      Check(LBF.Contains(LI * 7), 'Should contain added item');
  finally
    LBF.Free;
  end;
end;

procedure TestSBFGrowth;
var
  LBF: TIntSBF;
  LI: Integer;
begin
  LBF := TIntSBF.Create(50, 0.1);
  try
    for LI := 1 to 200 do
      LBF.Add(LI);

    Check(LBF.GetLayerCount > 1, 'Should have grown beyond 1 layer');

    for LI := 1 to 200 do
      Check(LBF.Contains(LI), 'Should still contain item after growth');
  finally
    LBF.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_scalable_bloom ===');
  WriteLn;

  TestSBFBasic;
  WriteLn('  + Basic operations');

  TestSBFLayerCount;
  WriteLn('  + Layer count');

  TestSBFTotalCount;
  WriteLn('  + Total count');

  TestSBFFalsePositiveRate;
  WriteLn('  + False positive rate');

  TestSBFFalsePositiveEstimateComposesAcrossLayers;
  WriteLn('  + Layer FPR composition');

  TestSBFClose;
  WriteLn('  + Close semantics');

  TestSBFNoFalseNegative;
  WriteLn('  + No false negatives');

  TestSBFGrowth;
  WriteLn('  + Growth');

  WriteLn;
  WriteLn('All scalable bloom filter tests passed!');
end.
