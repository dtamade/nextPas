program test_bench_invalid_parameters_heaptrc;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  nextpas.core.exception,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.test;

{ === Suite Config Validation === }

procedure Test_SetMinDuration_Zero;
var
  LSuite: IBenchSuite;
  LRaised: Boolean;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('X');
  try
    LSuite.SetMinDuration(TDuration.FromNanoseconds(0));
  except
    on E: EBenchInvalidParam do LRaised := True;
  end;
  Check(LRaised, 'SetMinDuration(0) should raise EBenchInvalidParam');
  LSuite := nil;
end;

procedure Test_SetMaxIterations_Zero;
var
  LSuite: IBenchSuite;
  LRaised: Boolean;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('X');
  try
    LSuite.SetMaxIterations(0);
  except
    on E: EBenchInvalidParam do LRaised := True;
  end;
  Check(LRaised, 'SetMaxIterations(0) should raise EBenchInvalidParam');
  LSuite := nil;
end;

procedure Test_SetMinSamples_Zero;
var
  LSuite: IBenchSuite;
  LRaised: Boolean;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('X');
  try
    LSuite.SetMinSamples(0);
  except
    on E: EBenchInvalidParam do LRaised := True;
  end;
  Check(LRaised, 'SetMinSamples(0) should raise EBenchInvalidParam');
  LSuite := nil;
end;

procedure Test_SetWarmupIters_Negative;
var
  LSuite: IBenchSuite;
  LRaised: Boolean;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('X');
  try
    LSuite.SetWarmupIters(-1);
  except
    on E: EBenchInvalidParam do LRaised := True;
  end;
  Check(LRaised, 'SetWarmupIters(-1) should raise EBenchInvalidParam');
  LSuite := nil;
end;

procedure Test_SetTimeout_NegativeMs;
var
  LSuite: IBenchSuite;
  LRaised: Boolean;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('X');
  try
    LSuite.SetTimeout(-100);
  except
    on E: EBenchInvalidParam do LRaised := True;
  end;
  Check(LRaised, 'SetTimeout(-100) should raise EBenchInvalidParam');
  LSuite := nil;
end;

procedure Test_SetTimeout_NegativeDuration;
var
  LSuite: IBenchSuite;
  LRaised: Boolean;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('X');
  try
    LSuite.SetTimeout(TDuration.FromMilliseconds(-500));
  except
    on E: EBenchInvalidParam do LRaised := True;
  end;
  Check(LRaised, 'SetTimeout(TDuration<0) should raise EBenchInvalidParam');
  LSuite := nil;
end;

{ === Nil Function Guards === }

procedure Test_Add_Nil;
var
  LSuite: IBenchSuite;
  LRaised: Boolean;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('X');
  try
    LSuite.Add('NilFunc', nil);
  except
    on E: EBenchInvalidParam do LRaised := True;
  end;
  Check(LRaised, 'Add(nil) should raise EBenchInvalidParam');
  LSuite := nil;
end;

procedure Test_AddSimple_Nil;
var
  LSuite: IBenchSuite;
  LRaised: Boolean;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('X');
  try
    LSuite.AddSimple('NilSimple', nil);
  except
    on E: EBenchInvalidParam do LRaised := True;
  end;
  Check(LRaised, 'AddSimple(nil) should raise EBenchInvalidParam');
  LSuite := nil;
end;

procedure Test_AddLoop_Nil;
var
  LSuite: IBenchSuite;
  LRaised: Boolean;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('X');
  try
    LSuite.AddLoop('NilLoop', nil);
  except
    on E: EBenchInvalidParam do LRaised := True;
  end;
  Check(LRaised, 'AddLoop(nil) should raise EBenchInvalidParam');
  LSuite := nil;
end;

procedure Test_AddRange_Nil;
var
  LSuite: IBenchSuite;
  LRaised: Boolean;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('X');
  try
    LSuite.AddRange('NilRange', nil, [1, 2, 3]);
  except
    on E: EBenchInvalidParam do LRaised := True;
  end;
  Check(LRaised, 'AddRange(nil) should raise EBenchInvalidParam');
  LSuite := nil;
end;

procedure Test_AddParallel_Nil;
var
  LSuite: IBenchSuite;
  LRaised: Boolean;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('X');
  try
    LSuite.AddParallel('BadParallel', nil, 0);
  except
    on E: EBenchInvalidParam do LRaised := True;
  end;
  Check(LRaised, 'AddParallel(nil,0) should raise EBenchInvalidParam');
  LSuite := nil;
end;

{ === Not-Found Guards === }

procedure Test_RemoveByName_NotFound;
var
  LSuite: IBenchSuite;
  LRaised: Boolean;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('X');
  try
    LSuite.RemoveByName('NonExistent');
  except
    on E: EBenchInvalidParam do LRaised := True;
  end;
  Check(LRaised, 'RemoveByName(NonExistent) should raise EBenchInvalidParam');
  LSuite := nil;
end;

procedure Test_SetEntryCollectRawSamples_NotFound;
var
  LSuite: IBenchSuite;
  LRaised: Boolean;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('X');
  try
    LSuite.SetEntryCollectRawSamples('NonExistent', True);
  except
    on E: EBenchInvalidParam do LRaised := True;
  end;
  Check(LRaised, 'SetEntryCollectRawSamples(NonExistent) should raise EBenchInvalidParam');
  LSuite := nil;
end;

{ === TBenchRunner Guards === }

procedure Test_RunOne_Nil;
var
  LRunner: TBenchRunner;
  LRaised: Boolean;
begin
  LRaised := False;
  LRunner := TBenchRunner.Create;
  try
    try
      LRunner.RunOne('NilFunc', nil);
    except
      on E: EBenchInvalidParam do LRaised := True;
    end;
  finally
    LRunner.Free;
  end;
  Check(LRaised, 'RunOne(nil) should raise EBenchInvalidParam');
end;

{ === Suite Name Validation === }

procedure Test_Create_EmptyName;
var
  LSuite: IBenchSuite;
  LRaised: Boolean;
begin
  LRaised := False;
  LSuite := nil;
  try
    LSuite := TBenchSuite.Create('');
  except
    on E: EBenchInvalidParam do LRaised := True;
  end;
  Check(LRaised, 'Create(empty name) should raise EBenchInvalidParam');
  LSuite := nil;
end;

{ === F-10: TryRemoveByName === }

procedure BenchFast(const ACtx: IBenchContext);
begin
end;

procedure Test_TryRemoveByName_Found;
var
  LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('TryRemove')
    .Add('A', @BenchFast)
    .Add('B', @BenchFast);
  Check(LSuite.TryRemoveByName('A'), 'TryRemoveByName(A) should return True');
  LSuite := nil;
end;

procedure Test_TryRemoveByName_NotFound;
var
  LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('TryRemove')
    .Add('A', @BenchFast);
  Check(not LSuite.TryRemoveByName('NonExistent'), 'TryRemoveByName(NonExistent) should return False');
  LSuite := nil;
end;

{ === F-10: TryLoadBaseline === }

procedure Test_TryLoadBaseline_FileNotFound;
var
  LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('TryLoad');
  Check(not LSuite.TryLoadBaseline('/nonexistent/path/baseline.json'),
    'TryLoadBaseline(nonexistent) should return False');
  LSuite := nil;
end;

{ === Post-Run Guard === }

procedure Test_GuardNotRun;
var
  LSuite: IBenchSuite;
  LRaised: Boolean;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('Guard')
    .SetMinDuration(TDuration.FromMilliseconds(1))
    .SetMaxIterations(10)
    .SetMinSamples(1)
    .SetWarmupIters(0);
  LSuite.Add('Fast', @BenchFast);
  LSuite.Run;

  try
    LSuite.Add('New', @BenchFast);
  except
    on E: EBenchError do
      LRaised := True;
  end;
  Check(LRaised, 'Adding entry after Run should raise EBenchError');
  LSuite := nil;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.bench.invalid_parameters.heaptrc');

  { Suite Config Validation (6) }
  T.Test('SetMinDuration(0) raises EBenchInvalidParam', @Test_SetMinDuration_Zero);
  T.Test('SetMaxIterations(0) raises EBenchInvalidParam', @Test_SetMaxIterations_Zero);
  T.Test('SetMinSamples(0) raises EBenchInvalidParam', @Test_SetMinSamples_Zero);
  T.Test('SetWarmupIters(-1) raises EBenchInvalidParam', @Test_SetWarmupIters_Negative);
  T.Test('SetTimeout(-100) raises EBenchInvalidParam', @Test_SetTimeout_NegativeMs);
  T.Test('SetTimeout(TDuration<0) raises EBenchInvalidParam', @Test_SetTimeout_NegativeDuration);

  { Nil Function Guards (5) }
  T.Test('Add(nil) raises EBenchInvalidParam', @Test_Add_Nil);
  T.Test('AddSimple(nil) raises EBenchInvalidParam', @Test_AddSimple_Nil);
  T.Test('AddLoop(nil) raises EBenchInvalidParam', @Test_AddLoop_Nil);
  T.Test('AddRange(nil) raises EBenchInvalidParam', @Test_AddRange_Nil);
  T.Test('AddParallel(nil,0) raises EBenchInvalidParam', @Test_AddParallel_Nil);

  { Not-Found Guards (2) }
  T.Test('RemoveByName(NonExistent) raises EBenchInvalidParam', @Test_RemoveByName_NotFound);
  T.Test('SetEntryCollectRawSamples(NonExistent) raises EBenchInvalidParam', @Test_SetEntryCollectRawSamples_NotFound);

  { TBenchRunner Guards (1) }
  T.Test('RunOne(nil) raises EBenchInvalidParam', @Test_RunOne_Nil);

  { Suite Name Validation (1) }
  T.Test('Create(empty name) raises EBenchInvalidParam', @Test_Create_EmptyName);

  { F-10: TryRemoveByName (2) }
  T.Test('TryRemoveByName found', @Test_TryRemoveByName_Found);
  T.Test('TryRemoveByName not found', @Test_TryRemoveByName_NotFound);

  { F-10: TryLoadBaseline (1) }
  T.Test('TryLoadBaseline file not found', @Test_TryLoadBaseline_FileNotFound);

  { Post-Run Guard (1) }
  T.Test('GuardNotRun prevents mutation', @Test_GuardNotRun);

  T.Run;
  T.Summary;
end.
