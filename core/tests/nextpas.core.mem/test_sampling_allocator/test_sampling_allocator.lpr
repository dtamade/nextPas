program test_sampling_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.sampling;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBasicAlloc;
var
  LAlloc: TSamplingAllocator;
  LPtr: Pointer;
begin
  LAlloc := TSamplingAllocator.Create(GetRtlAllocator, 100);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestSampleRate;
var
  LAlloc: TSamplingAllocator;
begin
  LAlloc := TSamplingAllocator.Create(GetRtlAllocator, 500);
  try
    Check(LAlloc.SampleRate = 500, 'rate set');
  finally
    LAlloc.Free;
  end;
end;

procedure TestSampling;
var
  LAlloc: TSamplingAllocator;
  LIdx: Integer;
begin
  // Sample every 10th allocation
  LAlloc := TSamplingAllocator.Create(GetRtlAllocator, 10);
  try
    for LIdx := 0 to 24 do
      LAlloc.GetMem(32);

    Check(LAlloc.TotalAllocs >= 25, '25 allocs');
    Check(LAlloc.SampleCount >= 2, '2+ samples');
  finally
    LAlloc.Free;
  end;
end;

procedure TestGetSample;
var
  LAlloc: TSamplingAllocator;
  LSample: TSampleEntry;
  LIdx: Integer;
begin
  LAlloc := TSamplingAllocator.Create(GetRtlAllocator, 5);
  try
    for LIdx := 0 to 9 do
      LAlloc.GetMem(64);

    Check(LAlloc.SampleCount >= 2, 'has samples');
    LSample := LAlloc.GetSample(0);
    Check(LSample.Size = 64, 'sample size');
    Check(LSample.SequenceNum > 0, 'sequence num');
  finally
    LAlloc.Free;
  end;
end;

procedure TestResetStats;
var
  LAlloc: TSamplingAllocator;
begin
  LAlloc := TSamplingAllocator.Create(GetRtlAllocator, 10);
  try
    LAlloc.GetMem(32);
    LAlloc.GetMem(32);
    Check(LAlloc.TotalAllocs >= 2, 'before reset');

    LAlloc.ResetStats;
    Check(LAlloc.TotalAllocs = 0, 'after reset');
    Check(LAlloc.SampleCount = 0, 'samples reset');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TSamplingAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TSamplingAllocator.Create(GetRtlAllocator, 100);
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
  LAlloc: TSamplingAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TSamplingAllocator.Create(GetRtlAllocator, 100);
  try
    LTraits := LAlloc.Traits;
    Check(not LTraits.ThreadSafe, 'not thread-safe');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_sampling_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('SampleRate', @TestSampleRate);
  T.Test('Sampling', @TestSampling);
  T.Test('GetSample', @TestGetSample);
  T.Test('ResetStats', @TestResetStats);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
