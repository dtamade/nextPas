program test_sampling;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.sampling,
  nextpas.core.mem.error;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestCreateAndDestroy;
var
  LSampling: TSamplingAllocator;
begin
  LSampling := TSamplingAllocator.Create(DefaultAllocator, 100);
  try
    Check(LSampling.Inner <> nil, 'Inner should not be nil');
    Check(LSampling.SampleRate = 100, 'sample rate should be 100');
    Check(LSampling.TotalAllocs = 0, 'total allocs should be 0');
    Check(LSampling.SampleCount = 0, 'sample count should be 0');
  finally
    LSampling.Free;
  end;
end;

procedure TestDefaultSampleRate;
var
  LSampling: TSamplingAllocator;
begin
  LSampling := TSamplingAllocator.Create(DefaultAllocator);
  try
    Check(LSampling.SampleRate = 1000, 'default sample rate should be 1000');
  finally
    LSampling.Free;
  end;
end;

procedure TestSampling;
var
  LSampling: TSamplingAllocator;
  LPtrs: array[0..24] of Pointer;
  LI: Integer;
begin
  LSampling := TSamplingAllocator.Create(DefaultAllocator, 10);
  try
    for LI := 0 to 24 do
      LPtrs[LI] := LSampling.GetMem(64);

    Check(LSampling.TotalAllocs = 25, 'total allocs should be 25');
    Check(LSampling.SampleCount = 2, 'sample count should be 2 (at 10 and 20)');

    for LI := 24 downto 0 do
      LSampling.FreeMem(LPtrs[LI]);
  finally
    LSampling.Free;
  end;
end;

procedure TestSampleContent;
var
  LSampling: TSamplingAllocator;
  LPtrs: array[0..4] of Pointer;
  LSample: TSampleEntry;
  LI: Integer;
begin
  LSampling := TSamplingAllocator.Create(DefaultAllocator, 5);
  try
    for LI := 0 to 4 do
      LPtrs[LI] := LSampling.GetMem(128 * (LI + 1));

    Check(LSampling.SampleCount = 1, 'should have 1 sample');
    LSample := LSampling.GetSample(0);
    Check(LSample.Size = 640, 'sample size should be 640 (128*5)');
    Check(LSample.SequenceNum = 5, 'sequence num should be 5');

    for LI := 4 downto 0 do
      LSampling.FreeMem(LPtrs[LI]);
  finally
    LSampling.Free;
  end;
end;

procedure TestResetStats;
var
  LSampling: TSamplingAllocator;
begin
  LSampling := TSamplingAllocator.Create(DefaultAllocator, 10);
  try
    LSampling.GetMem(100);
    LSampling.GetMem(200);
    Check(LSampling.TotalAllocs = 2, 'should have 2 allocs');

    LSampling.ResetStats;
    Check(LSampling.TotalAllocs = 0, 'should be 0 after reset');
    Check(LSampling.SampleCount = 0, 'samples should be 0 after reset');
  finally
    LSampling.Free;
  end;
end;

procedure TestGetSampleOutOfRange;
var
  LSampling: TSamplingAllocator;
  LRaised: Boolean;
begin
  LSampling := TSamplingAllocator.Create(DefaultAllocator, 10);
  try
    LRaised := False;
    try
      LSampling.GetSample(0);
    except
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised, 'should raise for out of range');
  finally
    LSampling.Free;
  end;
end;

procedure TestTraits;
var
  LSampling: TSamplingAllocator;
  LTraits: TAllocatorTraits;
begin
  LSampling := TSamplingAllocator.Create(DefaultAllocator);
  try
    LTraits := LSampling.Traits;
    Check(LTraits.SupportsRealloc, 'should support realloc');
  finally
    LSampling.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_sampling');
  T.Test('create_and_destroy', @TestCreateAndDestroy);
  T.Test('default_sample_rate', @TestDefaultSampleRate);
  T.Test('sampling', @TestSampling);
  T.Test('sample_content', @TestSampleContent);
  T.Test('reset_stats', @TestResetStats);
  T.Test('get_sample_out_of_range', @TestGetSampleOutOfRange);
  T.Test('traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
