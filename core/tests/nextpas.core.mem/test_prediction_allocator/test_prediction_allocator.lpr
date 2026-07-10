program test_prediction_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.prediction;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBasicAlloc;
var
  LAlloc: TPredictionAllocator;
  LPtr: Pointer;
begin
  LAlloc := TPredictionAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestTrackAllocations;
var
  LAlloc: TPredictionAllocator;
begin
  LAlloc := TPredictionAllocator.Create(GetRtlAllocator);
  try
    LAlloc.GetMem(64);
    LAlloc.GetMem(64);
    LAlloc.GetMem(128);

    Check(LAlloc.TotalAllocations >= 3, 'tracked 3');
  finally
    LAlloc.Free;
  end;
end;

procedure TestPredict;
var
  LAlloc: TPredictionAllocator;
  LPred: TPredictionResult;
begin
  LAlloc := TPredictionAllocator.Create(GetRtlAllocator);
  try
    // Alloc size 64 many times to make it hot
    LAlloc.GetMem(64);
    LAlloc.GetMem(64);
    LAlloc.GetMem(64);
    LAlloc.GetMem(128);

    LPred := LAlloc.Predict(4);
    Check(LPred.Count >= 1, 'has predictions');
    // Most frequent should be 64
    Check(LPred.Entries[0].AllocCount >= 3, 'top has 3+');
  finally
    LAlloc.Free;
  end;
end;

procedure TestPreAllocate;
var
  LAlloc: TPredictionAllocator;
begin
  LAlloc := TPredictionAllocator.Create(GetRtlAllocator);
  try
    // Build pattern
    LAlloc.GetMem(64);
    LAlloc.GetMem(64);
    LAlloc.GetMem(128);

    // Pre-allocate should not crash
    LAlloc.PreAllocate(2, 4);
    Check(True, 'pre-allocate ok');
  finally
    LAlloc.Free;
  end;
end;

procedure TestResetStats;
var
  LAlloc: TPredictionAllocator;
begin
  LAlloc := TPredictionAllocator.Create(GetRtlAllocator);
  try
    LAlloc.GetMem(64);
    LAlloc.GetMem(128);
    Check(LAlloc.TotalAllocations >= 2, 'before reset');

    LAlloc.ResetStats;
    Check(LAlloc.TotalAllocations = 0, 'after reset');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TPredictionAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TPredictionAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.AllocMem(64);
    Check(LPtr <> nil, 'allocated');
    for LIdx := 0 to 63 do
      CheckEqual(PByte(LPtr)[LIdx], Byte(0), 'zeroed');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: TPredictionAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TPredictionAllocator.Create(GetRtlAllocator);
  try
    LTraits := LAlloc.Traits;
    Check(True, 'traits accessible');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_prediction_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('TrackAllocations', @TestTrackAllocations);
  T.Test('Predict', @TestPredict);
  T.Test('PreAllocate', @TestPreAllocate);
  T.Test('ResetStats', @TestResetStats);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
