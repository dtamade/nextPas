program test_prediction;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.crt,
  nextpas.core.mem.allocator.prediction;

var
  T: TTestSuite;

procedure TestBasicPredict;
var
  LAlloc: TPredictionAllocator;
  LPred: TPredictionResult;
begin
  LAlloc := TPredictionAllocator.Create(TCrtAllocator.Create);
  try
    { Allocate some blocks of different sizes }
    LAlloc.GetMem(32);
    LAlloc.GetMem(32);
    LAlloc.GetMem(32);
    LAlloc.GetMem(128);

    LPred := LAlloc.Predict(4);
    Check(LPred.Count >= 1, 'prediction has entries');
    Check(LPred.Entries[0].AllocCount = 3, 'top entry has 3 allocs');
    Check(LPred.Entries[0].UsableSize >= 32, 'top entry size >= 32');
  finally
    LAlloc.Free;
  end;
end;

procedure TestPredictTopN;
var
  LAlloc: TPredictionAllocator;
  LPred: TPredictionResult;
begin
  LAlloc := TPredictionAllocator.Create(TCrtAllocator.Create);
  try
    LAlloc.GetMem(32);
    LAlloc.GetMem(256);
    LAlloc.GetMem(1024);

    LPred := LAlloc.Predict(2);
    Check(LPred.Count = 2, 'top-2 has 2 entries');
    { Each size allocated once, order may vary }
    Check(LPred.Entries[0].AllocCount >= 1, 'entry[0] has allocs');
    Check(LPred.Entries[1].AllocCount >= 1, 'entry[1] has allocs');
  finally
    LAlloc.Free;
  end;
end;

procedure TestPreAllocate;
var
  LAlloc: TPredictionAllocator;
begin
  LAlloc := TPredictionAllocator.Create(TCrtAllocator.Create);
  try
    { Generate pattern }
    LAlloc.GetMem(64);
    LAlloc.GetMem(64);
    LAlloc.GetMem(64);
    { Pre-allocate should not crash }
    LAlloc.PreAllocate(2, 4);
    Check(LAlloc.TotalAllocations >= 3, 'total allocs >= 3');
  finally
    LAlloc.Free;
  end;
end;

procedure TestResetStats;
var
  LAlloc: TPredictionAllocator;
  LPred: TPredictionResult;
begin
  LAlloc := TPredictionAllocator.Create(TCrtAllocator.Create);
  try
    LAlloc.GetMem(64);
    LAlloc.GetMem(64);
    Check(LAlloc.TotalAllocations = 2, 'total = 2');
    LAlloc.ResetStats;
    Check(LAlloc.TotalAllocations = 0, 'total = 0 after reset');
    LPred := LAlloc.Predict(4);
    Check(LPred.Count = 0, 'no predictions after reset');
  finally
    LAlloc.Free;
  end;
end;

procedure TestNilHandling;
var
  LAlloc: TPredictionAllocator;
begin
  LAlloc := TPredictionAllocator.Create(TCrtAllocator.Create);
  try
    Check(LAlloc.GetMem(0) = nil, 'GetMem(0) = nil');
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: TPredictionAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TPredictionAllocator.Create(TCrtAllocator.Create);
  try
    LTraits := LAlloc.Traits;
    Check(LTraits.ZeroInitialized, 'ZeroInitialized = True');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFrequencyTracking;
var
  LAlloc: TPredictionAllocator;
  LPred: TPredictionResult;
  LI: Integer;
begin
  LAlloc := TPredictionAllocator.Create(TCrtAllocator.Create);
  try
    { 10x 32B, 5x 128B, 2x 1024B }
    for LI := 0 to 9 do
      LAlloc.GetMem(32);
    for LI := 0 to 4 do
      LAlloc.GetMem(128);
    for LI := 0 to 1 do
      LAlloc.GetMem(1024);

    LPred := LAlloc.Predict(3);
    Check(LPred.Count = 3, '3 predictions');
    Check(LPred.Entries[0].AllocCount = 10, 'top is 10 allocs (32B)');
    Check(LPred.Entries[1].AllocCount = 5, 'second is 5 allocs (128B)');
    Check(LPred.Entries[2].AllocCount = 2, 'third is 2 allocs (1024B)');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_prediction');

  T.Test('basic_predict', @TestBasicPredict);
  T.Test('predict_top_n', @TestPredictTopN);
  T.Test('pre_allocate', @TestPreAllocate);
  T.Test('reset_stats', @TestResetStats);
  T.Test('nil_handling', @TestNilHandling);
  T.Test('traits', @TestTraits);
  T.Test('frequency_tracking', @TestFrequencyTracking);

  T.Run;
  T.Summary;
end.
