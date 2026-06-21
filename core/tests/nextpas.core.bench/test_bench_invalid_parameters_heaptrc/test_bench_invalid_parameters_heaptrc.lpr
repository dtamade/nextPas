program test_bench_invalid_parameters_heaptrc;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  {$ifdef unix}
  cthreads,
  {$endif}
  SysUtils,
  nextpas.core.bench,
  nextpas.core.time.base;

procedure ExpectSetMinDurationRaised;
var
  LRaised: Boolean;
  LSuite: IBenchSuite;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.SetMinDuration(TDuration.FromNanoseconds(0));
    except
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
end;

procedure ExpectSetMaxIterationsRaised;
var
  LRaised: Boolean;
  LSuite: IBenchSuite;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.SetMaxIterations(0);
    except
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
end;

procedure ExpectSetMinSamplesRaised;
var
  LRaised: Boolean;
  LSuite: IBenchSuite;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.SetMinSamples(0);
    except
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
end;

procedure ExpectAddParallelRaised;
var
  LRaised: Boolean;
  LSuite: IBenchSuite;
begin
  LRaised := False;
  LSuite := TBenchSuite.Create('Invalid');
  try
    try
      LSuite.AddParallel('BadParallel', nil, 0);
    except
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
end;

begin
  ExpectSetMinDurationRaised;
  ExpectSetMaxIterationsRaised;
  ExpectSetMinSamplesRaised;
  ExpectAddParallelRaised;

  WriteLn('INVALID_PARAMETERS_OK');
end.
