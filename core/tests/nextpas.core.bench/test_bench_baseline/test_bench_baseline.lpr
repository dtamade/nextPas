program test_bench_baseline;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.math.scalar,
  nextpas.core.platform.time,
  nextpas.core.id.xid,
  nextpas.core.bench.base,
  nextpas.core.bench.baseline,
  nextpas.core.bench.intf;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Check(ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', ATestName);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ ', ATestName);
  end;
end;

{ Helper functions }

function CreateTestResult(const AName: string; ANsPerOp: Double;
                          ABytesPerOp: Int64 = 0; AAllocsPerOp: Int64 = 0): TBenchResult;
begin
  Result := Default(TBenchResult);
  Result.Name := AName;
  Result.NsPerOp := ANsPerOp;
  Result.BytesPerOp := ABytesPerOp;
  Result.AllocsPerOp := AAllocsPerOp;
end;

function CreateTestBaseline(const AName: string; ANsPerOp: Double;
                           ABytesPerOp: Int64 = 0; AAllocsPerOp: Int64 = 0): TBaselineData;
begin
  Result.Name := AName;
  Result.NsPerOp := ANsPerOp;
  Result.BytesPerOp := ABytesPerOp;
  Result.AllocsPerOp := AAllocsPerOp;
  Result.TimestampNs := UInt64(platform_realtime_ns);
  Result.GitHash := 'abc123';
  Result.CompilerVersion := 'FPC 3.3.1';
  Result.Notes := 'Test baseline';
end;

{ === TBaselineManager Tests === }

procedure Test_Create;
var
  LManager: TBaselineManager;
begin
  WriteLn('Test_Create:');
  LManager := TBaselineManager.Create(1.1);
  Check(True, 'Created successfully');
  Check(Length(LManager.GetAllBaselines) = 0, 'Initial baselines = 0');
end;

procedure Test_AddBaseline;
var
  LManager: TBaselineManager;
  LBaseline: TBaselineData;
begin
  WriteLn('Test_AddBaseline:');
  LManager := TBaselineManager.Create(1.1);

  LBaseline := CreateTestBaseline('Sort', 1000);
  LManager.AddBaseline(LBaseline);

  Check(LManager.HasBaseline('Sort'), 'Has baseline Sort');
  Check(not LManager.HasBaseline('Hash'), 'Does not have baseline Hash');
end;

procedure Test_AddBaselineFromResult;
var
  LManager: TBaselineManager;
  LResult: TBenchResult;
  LBaseline: TBaselineData;
begin
  WriteLn('Test_AddBaselineFromResult:');
  LManager := TBaselineManager.Create(1.1);

  LResult := CreateTestResult('Sort', 1000, 100, 5);
  LManager.AddBaselineFromResult(LResult, 'def456', 'Initial baseline');

  Check(LManager.HasBaseline('Sort'), 'Has baseline Sort');

  LBaseline := LManager.GetBaseline('Sort');
  Check(LBaseline.Name = 'Sort', 'Retrieved baseline name');
  Check(LBaseline.NsPerOp = 1000, 'Retrieved baseline NsPerOp');
end;

procedure Test_GetBaseline;
var
  LManager: TBaselineManager;
  LBaseline: TBaselineData;
begin
  WriteLn('Test_GetBaseline:');
  LManager := TBaselineManager.Create(1.1);

  LBaseline := CreateTestBaseline('Sort', 1000);
  LManager.AddBaseline(LBaseline);

  LBaseline := LManager.GetBaseline('Sort');
  Check(LBaseline.Name = 'Sort', 'Name = Sort');
  Check(LBaseline.NsPerOp = 1000, 'NsPerOp = 1000');
end;

procedure Test_GetBaseline_NotFound;
var
  LManager: TBaselineManager;
  LSuccess: Boolean;
begin
  WriteLn('Test_GetBaseline_NotFound:');
  LManager := TBaselineManager.Create(1.1);

  LSuccess := False;
  try
    LManager.GetBaseline('NonExistent');
  except
    on E: EBenchBaselineNotFound do
      LSuccess := True;
  end;
  Check(LSuccess, 'Raises exception for missing baseline');
end;

procedure Test_RemoveBaseline;
var
  LManager: TBaselineManager;
begin
  WriteLn('Test_RemoveBaseline:');
  LManager := TBaselineManager.Create(1.1);

  LManager.AddBaseline(CreateTestBaseline('Sort', 1000));
  LManager.AddBaseline(CreateTestBaseline('Hash', 2000));

  Check(LManager.HasBaseline('Sort'), 'Has baseline Sort');
  Check(LManager.HasBaseline('Hash'), 'Has baseline Hash');

  LManager.RemoveBaseline('Sort');

  Check(not LManager.HasBaseline('Sort'), 'Baseline Sort removed');
  Check(LManager.HasBaseline('Hash'), 'Baseline Hash still exists');
end;

procedure Test_ClearBaselines;
var
  LManager: TBaselineManager;
begin
  WriteLn('Test_ClearBaselines:');
  LManager := TBaselineManager.Create(1.1);

  LManager.AddBaseline(CreateTestBaseline('Sort', 1000));
  LManager.AddBaseline(CreateTestBaseline('Hash', 2000));

  Check(Length(LManager.GetAllBaselines) = 2, 'Has 2 baselines');

  LManager.ClearBaselines;

  Check(Length(LManager.GetAllBaselines) = 0, 'Baselines cleared');
end;

procedure Test_CompareWithBaseline_NoRegression;
var
  LManager: TBaselineManager;
  LResult: TBenchResult;
  LComparison: TBaselineComparison;
begin
  WriteLn('Test_CompareWithBaseline_NoRegression:');
  LManager := TBaselineManager.Create(1.1);

  LManager.AddBaseline(CreateTestBaseline('Sort', 1000));

  // Current is 5% slower (1050 vs 1000)
  LResult := CreateTestResult('Sort', 1050);
  LComparison := LManager.CompareWithBaseline(LResult);

  Check(LComparison.Ratio > 1, 'Ratio > 1');
  Check(not LComparison.IsRegression, 'Not a regression');
  Check(not LComparison.IsImprovement, 'Not an improvement');
  Check(Abs(LComparison.PercentChange - 5) < 0.1, 'PercentChange ≈ 5%');
end;

procedure Test_CompareWithBaseline_Regression;
var
  LManager: TBaselineManager;
  LResult: TBenchResult;
  LComparison: TBaselineComparison;
begin
  WriteLn('Test_CompareWithBaseline_Regression:');
  LManager := TBaselineManager.Create(1.1);

  LManager.AddBaseline(CreateTestBaseline('Sort', 1000));

  // Current is 20% slower (1200 vs 1000)
  LResult := CreateTestResult('Sort', 1200);
  LComparison := LManager.CompareWithBaseline(LResult);

  Check(LComparison.Ratio > 1.1, 'Ratio > 1.1');
  Check(LComparison.IsRegression, 'Is a regression');
  Check(not LComparison.IsImprovement, 'Not an improvement');
  Check(Abs(LComparison.PercentChange - 20) < 0.1, 'PercentChange ≈ 20%');
end;

procedure Test_CompareWithBaseline_Improvement;
var
  LManager: TBaselineManager;
  LResult: TBenchResult;
  LComparison: TBaselineComparison;
begin
  WriteLn('Test_CompareWithBaseline_Improvement:');
  LManager := TBaselineManager.Create(1.1);

  LManager.AddBaseline(CreateTestBaseline('Sort', 1000));

  // Current is 20% faster (800 vs 1000)
  LResult := CreateTestResult('Sort', 800);
  LComparison := LManager.CompareWithBaseline(LResult);

  Check(LComparison.Ratio < 1, 'Ratio < 1');
  Check(not LComparison.IsRegression, 'Not a regression');
  Check(LComparison.IsImprovement, 'Is an improvement');
  Check(Abs(LComparison.PercentChange - (-20)) < 0.1, 'PercentChange ≈ -20%');
end;

procedure Test_CompareAllWithBaselines;
var
  LManager: TBaselineManager;
  LResults: TBenchResultArray;
  LComparisons: TBaselineComparisonArray;
begin
  WriteLn('Test_CompareAllWithBaselines:');
  LManager := TBaselineManager.Create(1.1);

  LManager.AddBaseline(CreateTestBaseline('Sort', 1000));
  LManager.AddBaseline(CreateTestBaseline('Hash', 2000));

  SetLength(LResults, 2);
  LResults[0] := CreateTestResult('Sort', 1050); // 5% slower
  LResults[1] := CreateTestResult('Hash', 1800); // 10% faster

  LComparisons := LManager.CompareAllWithBaselines(LResults);

  Check(Length(LComparisons) = 2, 'Found 2 comparisons');
  Check(LComparisons[0].Baseline.Name = 'Sort', 'First comparison is Sort');
  Check(LComparisons[1].Baseline.Name = 'Hash', 'Second comparison is Hash');
end;

procedure Test_HasRegression;
var
  LManager: TBaselineManager;
  LResults: TBenchResultArray;
begin
  WriteLn('Test_HasRegression:');
  LManager := TBaselineManager.Create(1.1);

  LManager.AddBaseline(CreateTestBaseline('Sort', 1000));
  LManager.AddBaseline(CreateTestBaseline('Hash', 2000));

  // No regression
  SetLength(LResults, 2);
  LResults[0] := CreateTestResult('Sort', 1050); // 5% slower
  LResults[1] := CreateTestResult('Hash', 1800); // 10% faster
  Check(not LManager.HasRegression(LResults), 'No regression detected');

  // With regression
  LResults[1] := CreateTestResult('Hash', 2500); // 25% slower
  Check(LManager.HasRegression(LResults), 'Regression detected');
end;

procedure Test_GetAllBaselines;
var
  LManager: TBaselineManager;
  LBaselines: TBaselineArray;
begin
  WriteLn('Test_GetAllBaselines:');
  LManager := TBaselineManager.Create(1.1);

  LManager.AddBaseline(CreateTestBaseline('Sort', 1000));
  LManager.AddBaseline(CreateTestBaseline('Hash', 2000));
  LManager.AddBaseline(CreateTestBaseline('Parse', 3000));

  LBaselines := LManager.GetAllBaselines;
  Check(Length(LBaselines) = 3, 'Found 3 baselines');
end;

procedure Test_GetAllBaselines_Empty;
var
  LManager: TBaselineManager;
  LBaselines: TBaselineArray;
begin
  WriteLn('Test_GetAllBaselines_Empty:');
  LManager := TBaselineManager.Create(1.1);
  LBaselines := LManager.GetAllBaselines;
  Check(Length(LBaselines) = 0, 'GetAllBaselines_Empty: length should be 0');
end;

procedure Test_UpdateBaseline;
var
  LManager: TBaselineManager;
  LBaseline: TBaselineData;
begin
  WriteLn('Test_UpdateBaseline:');
  LManager := TBaselineManager.Create(1.1);

  LManager.AddBaseline(CreateTestBaseline('Sort', 1000));
  Check(LManager.GetBaseline('Sort').NsPerOp = 1000, 'Initial NsPerOp = 1000');

  LBaseline := CreateTestBaseline('Sort', 1200);
  LManager.AddBaseline(LBaseline);
  Check(LManager.GetBaseline('Sort').NsPerOp = 1200, 'Updated NsPerOp = 1200');
end;

procedure Test_CustomThreshold;
var
  LManager: TBaselineManager;
  LResult: TBenchResult;
  LComparison: TBaselineComparison;
begin
  WriteLn('Test_CustomThreshold:');
  // Use 20% threshold
  LManager := TBaselineManager.Create(1.2);

  LManager.AddBaseline(CreateTestBaseline('Sort', 1000));

  // 15% slower - not a regression with 20% threshold
  LResult := CreateTestResult('Sort', 1150);
  LComparison := LManager.CompareWithBaseline(LResult);
  Check(not LComparison.IsRegression, '15% slower is not regression with 20% threshold');

  // 25% slower - is a regression
  LResult := CreateTestResult('Sort', 1250);
  LComparison := LManager.CompareWithBaseline(LResult);
  Check(LComparison.IsRegression, '25% slower is regression with 20% threshold');
end;

procedure Test_JSON;
var
  LManager: TBaselineManager;
  LJSON: string;
begin
  WriteLn('Test_JSON:');
  LManager := TBaselineManager.Create(1.1);

  LManager.AddBaseline(CreateTestBaseline('Sort', 1000));
  LManager.AddBaseline(CreateTestBaseline('Hash', 2000));

  LJSON := LManager.ToJSON;
  Check(Pos('Sort', LJSON) > 0, 'JSON contains Sort');
  Check(Pos('Hash', LJSON) > 0, 'JSON contains Hash');
  Check(Pos('1000', LJSON) > 0, 'JSON contains 1000');
  Check(Pos('2000', LJSON) > 0, 'JSON contains 2000');
end;

procedure Test_JSON_RoundTripPreservesNotesAndInvariantLocale;
var
  LManager: TBaselineManager;
  LLoaded: TBaselineManager;
  LBaseline: TBaselineData;
  LJSON: string;
begin
  WriteLn('Test_JSON_RoundTripPreservesNotesAndInvariantLocale:');

  LManager := TBaselineManager.Create(1.1);
  LBaseline := CreateTestBaseline('RoundTrip', 1000.5, 64, 2);
  LBaseline.Notes := 'line1' + LineEnding + 'line2 "quoted"';
  LManager.AddBaseline(LBaseline);

  LJSON := LManager.ToJSON;
  Check(Pos('"nsPerOp":1000.5', LJSON) > 0, 'JSON keeps invariant decimal separator');
  Check(Pos('line1\nline2 \"quoted\"', LJSON) > 0, 'JSON escapes multiline notes');

  LLoaded := TBaselineManager.Create(1.1);
  LLoaded.LoadFromJSON(LJSON);
  LBaseline := LLoaded.GetBaseline('RoundTrip');

  Check(LBaseline.NsPerOp > 1000.0, 'Round-trip keeps NsPerOp');
  Check(LBaseline.BytesPerOp = 64, 'Round-trip keeps BytesPerOp');
  Check(LBaseline.AllocsPerOp = 2, 'Round-trip keeps AllocsPerOp');
  Check(LBaseline.Notes = 'line1' + LineEnding + 'line2 "quoted"',
    'Round-trip keeps multiline notes');
end;

procedure Test_FileRoundTrip;
var
  LManager1, LManager2: TBaselineManager;
  LPath: string;
  LB: TBaselineData;
begin
  WriteLn('Test_FileRoundTrip:');
  LPath := '/tmp/nextpas_bench_test_' + XidNew + '.json';
  LManager1 := TBaselineManager.Create;
  LB := Default(TBaselineData);
  LB.Name := 'TestBench';
  LB.NsPerOp := 123.456;
  LB.Notes := 'round-trip test';
  LManager1.AddBaseline(LB);

  LManager1.SaveToFile(LPath);
  LManager2 := TBaselineManager.Create;
  LManager2.LoadFromFile(LPath);

  Check(LManager2.HasBaseline('TestBench'), 'FileRoundTrip: baseline exists after load');
  Check(Abs(LManager2.GetBaseline('TestBench').NsPerOp - 123.456) < 0.001, 'FileRoundTrip: NsPerOp matches');
  Check(LManager2.GetBaseline('TestBench').Notes = 'round-trip test', 'FileRoundTrip: Notes matches');

  Remove(LPath);
end;

procedure Test_LoadFromJSON_Errors;
var
  LManager: TBaselineManager;
  LFailed: Boolean;
begin
  WriteLn('Test_LoadFromJSON_Errors:');
  LManager := TBaselineManager.Create;

  // invalid JSON
  LFailed := False;
  try
    LManager.LoadFromJSON('not json at all');
  except
    LFailed := True;
  end;
  Check(LFailed, 'LoadFromJSON_Errors: invalid JSON raises exception');

  // empty JSON - should not crash
  LManager.LoadFromJSON('');
  Check(not LManager.HasBaseline('anything'), 'LoadFromJSON_Errors: empty string yields empty');

  // missing baselines key
  LManager.LoadFromJSON('{"other": 123}');
  Check(not LManager.HasBaseline('anything'), 'LoadFromJSON_Errors: missing baselines key yields empty');

  // baselines is not array
  LManager.LoadFromJSON('{"baselines": "not array"}');
  Check(not LManager.HasBaseline('anything'), 'LoadFromJSON_Errors: non-array baselines yields empty');
end;

{ === TG-14: LoadFromFile File Not Found Test === }

procedure Test_LoadFromFile_NotFound;
var
  LManager: TBaselineManager;
  LRaised: Boolean;
begin
  WriteLn('Test_LoadFromFile_NotFound:');
  LManager := TBaselineManager.Create;
  LRaised := False;

  try
    LManager.LoadFromFile('/tmp/nonexistent_bench_baseline_file_12345.json');
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'LoadFromFile raises exception for non-existent file');
  Check(not LManager.HasBaseline('anything'), 'No baselines loaded after failed LoadFromFile');
end;

{ === TG-13: CompareAllWithBaselines comparison field verification === }

procedure Test_CompareAllWithBaselines_Fields;
var
  LManager: TBaselineManager;
  LResults: TBenchResultArray;
  LComparisons: TBaselineComparisonArray;
begin
  WriteLn('Test_CompareAllWithBaselines_Fields:');
  LManager := TBaselineManager.Create(1.1);

  LManager.AddBaseline(CreateTestBaseline('Sort', 1000));
  LManager.AddBaseline(CreateTestBaseline('Hash', 2000));
  LManager.AddBaseline(CreateTestBaseline('Fast', 500));

  SetLength(LResults, 3);
  LResults[0] := CreateTestResult('Sort', 1200);  // 20% slower => regression
  LResults[1] := CreateTestResult('Hash', 1800);   // 10% faster => improvement
  LResults[2] := CreateTestResult('Fast', 510);    // 2% slower => no regression, no improvement

  LComparisons := LManager.CompareAllWithBaselines(LResults);

  Check(Length(LComparisons) = 3, 'TG-13: Found 3 comparisons');

  // Sort: 1200 / 1000 = 1.2, regression (> 1.1)
  Check(Abs(LComparisons[0].Ratio - 1.2) < 0.001, 'Sort Ratio = 1.2');
  Check(LComparisons[0].IsRegression, 'Sort IsRegression = true');
  Check(not LComparisons[0].IsImprovement, 'Sort IsImprovement = false');
  Check(Abs(LComparisons[0].PercentChange - 20.0) < 0.1, 'Sort PercentChange = 20%');

  // Hash: 1800 / 2000 = 0.9, improvement (< 1/1.1 = 0.909...)
  Check(Abs(LComparisons[1].Ratio - 0.9) < 0.001, 'Hash Ratio = 0.9');
  Check(not LComparisons[1].IsRegression, 'Hash IsRegression = false');
  Check(LComparisons[1].IsImprovement, 'Hash IsImprovement = true');
  Check(Abs(LComparisons[1].PercentChange - (-10.0)) < 0.1, 'Hash PercentChange = -10%');

  // Fast: 510 / 500 = 1.02, no regression, no improvement
  Check(Abs(LComparisons[2].Ratio - 1.02) < 0.001, 'Fast Ratio = 1.02');
  Check(not LComparisons[2].IsRegression, 'Fast IsRegression = false');
  Check(not LComparisons[2].IsImprovement, 'Fast IsImprovement = false');
  Check(Abs(LComparisons[2].PercentChange - 2.0) < 0.1, 'Fast PercentChange = 2%');
end;

{ === Run All Tests === }

procedure RunAllTests;
begin
  WriteLn('=== TBaselineManager Tests ===');
  Test_Create;
  Test_AddBaseline;
  Test_AddBaselineFromResult;
  Test_GetBaseline;
  Test_GetBaseline_NotFound;
  Test_RemoveBaseline;
  Test_ClearBaselines;
  Test_CompareWithBaseline_NoRegression;
  Test_CompareWithBaseline_Regression;
  Test_CompareWithBaseline_Improvement;
  Test_CompareAllWithBaselines;
  Test_HasRegression;
  Test_GetAllBaselines;
  Test_GetAllBaselines_Empty;
  Test_UpdateBaseline;
  Test_CustomThreshold;
  Test_JSON;
  Test_JSON_RoundTripPreservesNotesAndInvariantLocale;
  Test_FileRoundTrip;
  Test_LoadFromJSON_Errors;
  WriteLn('');
  WriteLn('=== LoadFromFile Error Tests (TG-14) ===');
  Test_LoadFromFile_NotFound;
  WriteLn('');
  WriteLn('=== CompareAllWithBaselines Field Verification (TG-13) ===');
  Test_CompareAllWithBaselines_Fields;
end;

begin
  WriteLn('=== nextpas.core.bench.baseline Test Suite ===');
  WriteLn('');

  RunAllTests;

  WriteLn('');
  WriteLn('=== Test Summary ===');
  WriteLn('Total: ', GTestsPassed + GTestsFailed);
  WriteLn('Passed: ', GTestsPassed);
  WriteLn('Failed: ', GTestsFailed);

  if GTestsFailed > 0 then
  begin
    WriteLn('');
    WriteLn('*** FAILED ***');
    Halt(1);
  end
  else
  begin
    WriteLn('');
    WriteLn('✓ All tests passed!');
  end;
end.
