program test_bench_invalid_parameters_heaptrc;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  nextpas.core.exception,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.time.base;

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

begin
  ExpectSetMinDurationRaised;
  ExpectSetMaxIterationsRaised;
  ExpectSetMinSamplesRaised;
  ExpectAddParallelRaised;
  ExpectSetWarmupItersRaised;

  WriteLn('INVALID_PARAMETERS_OK');
  WriteLn('ALL_EXCEPTION_TYPES_VERIFIED');
end.
