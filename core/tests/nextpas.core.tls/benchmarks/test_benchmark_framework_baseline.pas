program test_benchmark_framework_baseline;

{$mode objfpc}{$H+}

uses
  SysUtils,
  benchmark_framework;

var
  GPassed: Integer = 0;
  GFailed: Integer = 0;

procedure Check(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  if ACondition then
  begin
    Inc(GPassed);
    if ADetail = '' then
      WriteLn('[PASS] ', AName)
    else
      WriteLn('[PASS] ', AName, ' - ', ADetail);
  end
  else
  begin
    Inc(GFailed);
    if ADetail = '' then
      WriteLn('[FAIL] ', AName)
    else
      WriteLn('[FAIL] ', AName, ' - ', ADetail);
  end;
end;

procedure DummyBench;
begin
  // intentionally empty workload for framework contract testing
end;

procedure WriteMalformedBaseline(const AFileName: string);
var
  F: TextFile;
begin
  AssignFile(F, AFileName);
  Rewrite(F);
  try
    WriteLn(F, '{');
    WriteLn(F, '  "generated": "test",');
    WriteLn(F, '  "tests": [');
    WriteLn(F, '    {');
    WriteLn(F, '      "name": "dummy"');
    WriteLn(F, '    }');
    WriteLn(F, '  ]');
    WriteLn(F, '}');
  finally
    CloseFile(F);
  end;
end;

var
  B: TBenchmark;
  LGoodFile: string;
  LBadFile: string;
begin
  LGoodFile := 'tmp/benchmark-baseline-good.json';
  LBadFile := 'tmp/benchmark-baseline-bad.json';

  B := TBenchmark.Create;
  try
    B.WarmupIterations := 0;
    B.RegisterTest('dummy', @DummyBench);
    B.Run(3);

    B.SaveBaseline(LGoodFile);
    Check('SaveBaseline writes file', FileExists(LGoodFile), LGoodFile);
    Check('LoadBaseline accepts generated baseline', B.LoadBaseline(LGoodFile));

    Check('LoadBaseline rejects missing file', not B.LoadBaseline('tmp/missing-benchmark-baseline.json'));

    WriteMalformedBaseline(LBadFile);
    Check('LoadBaseline rejects malformed baseline', not B.LoadBaseline(LBadFile));
  finally
    B.Free;
  end;

  WriteLn;
  WriteLn('Summary: passed=', GPassed, ' failed=', GFailed);
  if GFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
