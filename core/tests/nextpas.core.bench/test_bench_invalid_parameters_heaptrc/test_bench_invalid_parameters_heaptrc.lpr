program test_bench_invalid_parameters_heaptrc;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  nextpas.core.exception,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.test;

procedure ExpectSetMinDurationRaised;
var
  LRaised: Boolean;
  LCorrectType: Boolean;
  LSuite: IBenchSuite;
begin
  LRaised := False;
  LCorrectType := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.SetMinDuration(TDuration.FromNanoseconds(0));
    except
      on E: EBenchInvalidParam do
      begin
        LRaised := True;
        LCorrectType := True;
      end;
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;

  if not LRaised then
  begin
    WriteLn('MISSING_EXCEPTION=SetMinDuration');
    Halt(2);
  end;
  if not LCorrectType then
  begin
    WriteLn('WRONG_EXCEPTION_TYPE=SetMinDuration (expected EBenchInvalidParam)');
    Halt(102);
  end;
end;

procedure ExpectSetMaxIterationsRaised;
var
  LRaised: Boolean;
  LCorrectType: Boolean;
  LSuite: IBenchSuite;
begin
  LRaised := False;
  LCorrectType := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.SetMaxIterations(0);
    except
      on E: EBenchInvalidParam do
      begin
        LRaised := True;
        LCorrectType := True;
      end;
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;

  if not LRaised then
  begin
    WriteLn('MISSING_EXCEPTION=SetMaxIterations');
    Halt(3);
  end;
  if not LCorrectType then
  begin
    WriteLn('WRONG_EXCEPTION_TYPE=SetMaxIterations (expected EBenchInvalidParam)');
    Halt(103);
  end;
end;

procedure ExpectSetMinSamplesRaised;
var
  LRaised: Boolean;
  LCorrectType: Boolean;
  LSuite: IBenchSuite;
begin
  LRaised := False;
  LCorrectType := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.SetMinSamples(0);
    except
      on E: EBenchInvalidParam do
      begin
        LRaised := True;
        LCorrectType := True;
      end;
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;

  if not LRaised then
  begin
    WriteLn('MISSING_EXCEPTION=SetMinSamples');
    Halt(4);
  end;
  if not LCorrectType then
  begin
    WriteLn('WRONG_EXCEPTION_TYPE=SetMinSamples (expected EBenchInvalidParam)');
    Halt(104);
  end;
end;

procedure ExpectAddParallelRaised;
var
  LRaised: Boolean;
  LCorrectType: Boolean;
  LSuite: IBenchSuite;
begin
  LRaised := False;
  LCorrectType := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.AddParallel('BadParallel', nil, 0);
    except
      on E: EBenchInvalidParam do
      begin
        LRaised := True;
        LCorrectType := True;
      end;
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;

  if not LRaised then
  begin
    WriteLn('MISSING_EXCEPTION=AddParallel');
    Halt(5);
  end;
  if not LCorrectType then
  begin
    WriteLn('WRONG_EXCEPTION_TYPE=AddParallel (expected EBenchInvalidParam)');
    Halt(105);
  end;
end;

procedure ExpectSetWarmupItersRaised;
var
  LRaised: Boolean;
  LCorrectType: Boolean;
  LSuite: IBenchSuite;
begin
  LRaised := False;
  LCorrectType := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.SetWarmupIters(-1);
    except
      on E: EBenchInvalidParam do
      begin
        LRaised := True;
        LCorrectType := True;
      end;
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;

  if not LRaised then
  begin
    WriteLn('MISSING_EXCEPTION=SetWarmupIters');
    Halt(6);
  end;
  if not LCorrectType then
  begin
    WriteLn('WRONG_EXCEPTION_TYPE=SetWarmupIters (expected EBenchInvalidParam)');
    Halt(106);
  end;
end;

procedure ExpectAddNilFuncRaised;
var
  LRaised: Boolean;
  LCorrectType: Boolean;
  LSuite: IBenchSuite;
begin
  LRaised := False;
  LCorrectType := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.Add('NilFunc', nil);
    except
      on E: EBenchInvalidParam do
      begin
        LRaised := True;
        LCorrectType := True;
      end;
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;

  if not LRaised then
  begin
    WriteLn('MISSING_EXCEPTION=Add(nil)');
    Halt(7);
  end;
  if not LCorrectType then
  begin
    WriteLn('WRONG_EXCEPTION_TYPE=Add(nil) (expected EBenchInvalidParam)');
    Halt(107);
  end;
end;

procedure ExpectAddLoopNilFuncRaised;
var
  LRaised: Boolean;
  LCorrectType: Boolean;
  LSuite: IBenchSuite;
begin
  LRaised := False;
  LCorrectType := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.AddLoop('NilLoop', nil);
    except
      on E: EBenchInvalidParam do
      begin
        LRaised := True;
        LCorrectType := True;
      end;
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;

  if not LRaised then
  begin
    WriteLn('MISSING_EXCEPTION=AddLoop(nil)');
    Halt(8);
  end;
  if not LCorrectType then
  begin
    WriteLn('WRONG_EXCEPTION_TYPE=AddLoop(nil) (expected EBenchInvalidParam)');
    Halt(108);
  end;
end;

procedure ExpectAddRangeNilFuncRaised;
var
  LRaised: Boolean;
  LCorrectType: Boolean;
  LSuite: IBenchSuite;
begin
  LRaised := False;
  LCorrectType := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.AddRange('NilRange', nil, [1, 2, 3]);
    except
      on E: EBenchInvalidParam do
      begin
        LRaised := True;
        LCorrectType := True;
      end;
      on E: Exception do
        LRaised := True;
    end;
  finally
    LSuite := nil;
  end;

  if not LRaised then
  begin
    WriteLn('MISSING_EXCEPTION=AddRange(nil)');
    Halt(9);
  end;
  if not LCorrectType then
  begin
    WriteLn('WRONG_EXCEPTION_TYPE=AddRange(nil) (expected EBenchInvalidParam)');
    Halt(109);
  end;
end;

procedure ExpectRunOneNilFuncRaised;
var
  LRaised: Boolean;
  LCorrectType: Boolean;
  LRunner: TBenchRunner;
begin
  LRaised := False;
  LCorrectType := False;
  LRunner := TBenchRunner.Create;
  try
    try
      LRunner.RunOne('NilFunc', nil);
    except
      on E: EBenchInvalidParam do
      begin
        LRaised := True;
        LCorrectType := True;
      end;
      on E: Exception do
        LRaised := True;
    end;
  finally
    LRunner.Free;
  end;

  if not LRaised then
  begin
    WriteLn('MISSING_EXCEPTION=RunOne(nil)');
    Halt(10);
  end;
  if not LCorrectType then
  begin
    WriteLn('WRONG_EXCEPTION_TYPE=RunOne(nil) (expected EBenchInvalidParam)');
    Halt(110);
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.bench.invalid_parameters.heaptrc');
  T.Test('SetMinDuration(0) raises EBenchInvalidParam', @ExpectSetMinDurationRaised);
  T.Test('SetMaxIterations(0) raises EBenchInvalidParam', @ExpectSetMaxIterationsRaised);
  T.Test('SetMinSamples(0) raises EBenchInvalidParam', @ExpectSetMinSamplesRaised);
  T.Test('AddParallel(nil,0) raises EBenchInvalidParam', @ExpectAddParallelRaised);
  T.Test('SetWarmupIters(-1) raises EBenchInvalidParam', @ExpectSetWarmupItersRaised);
  T.Test('Add(nil) raises EBenchInvalidParam', @ExpectAddNilFuncRaised);
  T.Test('AddLoop(nil) raises EBenchInvalidParam', @ExpectAddLoopNilFuncRaised);
  T.Test('AddRange(nil) raises EBenchInvalidParam', @ExpectAddRangeNilFuncRaised);
  T.Test('RunOne(nil) raises EBenchInvalidParam', @ExpectRunOneNilFuncRaised);
  T.Run;
  T.Summary;

  WriteLn('INVALID_PARAMETERS_OK');
  WriteLn('ALL_EXCEPTION_TYPES_VERIFIED');
end.
