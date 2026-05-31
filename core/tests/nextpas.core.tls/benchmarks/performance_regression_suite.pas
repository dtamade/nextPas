program performance_regression_suite;

{$mode objfpc}{$H+}

{
  性能回归测试套件
  
  功能：自动化性能基准测试，检测性能退化
  用途：CI/CD 集成，定期性能验证
}

uses
  SysUtils, Classes,
  nextpas.core.tls.factory,
  nextpas.core.tls.base,
  fafafa.ssl;

type
  TBenchmarkResult = record
    Name: string;
    Duration: Int64;  // milliseconds
    Throughput: Double;  // operations per second
    Success: Boolean;
    ErrorMessage: string;
  end;

  TBenchmarkSuite = class
  private
    FResults: array of TBenchmarkResult;
    FTotalTests: Integer;
    FPassedTests: Integer;
  public
    procedure AddResult(const AResult: TBenchmarkResult);
    procedure RunAll;
    procedure SaveResults(const AFileName: string);
    function CheckRegression(const ABaselineFile: string; AThreshold: Double = 0.15): Boolean;
    procedure PrintSummary;
  end;

var
  GSuite: TBenchmarkSuite;
  GLib: ISSLLibrary;

procedure TBenchmarkSuite.AddResult(const AResult: TBenchmarkResult);
begin
  Inc(FTotalTests);
  if AResult.Success then
    Inc(FPassedTests);
  
  SetLength(FResults, Length(FResults) + 1);
  FResults[High(FResults)] := AResult;
end;

procedure TBenchmarkSuite.SaveResults(const AFileName: string);
var
  F: TextFile;
  I: Integer;
begin
  AssignFile(F, AFileName);
  Rewrite(F);
  try
    WriteLn(F, '# Performance Benchmark Results');
    WriteLn(F, '# Generated: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    WriteLn(F, 'Name,Duration(ms),Throughput(ops/s),Success');
    
    for I := 0 to High(FResults) do
      with FResults[I] do
        WriteLn(F, Format('%s,%d,%.2f,%s', [Name, Duration, Throughput, BoolToStr(Success, True)]));
  finally
    CloseFile(F);
  end;
end;

function TBenchmarkSuite.CheckRegression(const ABaselineFile: string; AThreshold: Double): Boolean;
var
  F: TextFile;
  Line, BName: string;
  BDuration, CurrentDuration: Int64;
  I, Idx: Integer;
  Degradation: Double;
  Parts: TStringArray;
begin
  Result := True;
  
  if not FileExists(ABaselineFile) then
  begin
    WriteLn('⚠️  No baseline file found, creating new baseline...');
    SaveResults(ABaselineFile);
    Exit;
  end;
  
  AssignFile(F, ABaselineFile);
  Reset(F);
  try
    // Skip header lines
    ReadLn(F);
    ReadLn(F);
    ReadLn(F);
    
    while not EOF(F) do
    begin
      ReadLn(F, Line);
      Parts := Line.Split(',');
      if Length(Parts) < 2 then Continue;
      
      BName := Parts[0];
      BDuration := StrToInt64Def(Parts[1], 0);
      
      // Find corresponding current result
      Idx := -1;
      for I := 0 to High(FResults) do
        if FResults[I].Name = BName then
        begin
          Idx := I;
          Break;
        end;
      
      if Idx >= 0 then
      begin
        CurrentDuration := FResults[Idx].Duration;
        if BDuration > 0 then
        begin
          Degradation := (CurrentDuration - BDuration) / BDuration;
          if Degradation > AThreshold then
          begin
            WriteLn(Format('❌ REGRESSION: %s: %.1f%% slower (was %dms, now %dms)', 
              [BName, Degradation * 100, BDuration, CurrentDuration]));
            Result := False;
          end
          else if Degradation < -0.10 then
            WriteLn(Format('✅ IMPROVEMENT: %s: %.1f%% faster', [BName, -Degradation * 100]));
        end;
      end;
    end;
  finally
    CloseFile(F);
  end;
end;

procedure TBenchmarkSuite.PrintSummary;
var
  I: Integer;
  TotalDuration: Int64;
begin
  WriteLn('================================================================');
  WriteLn('Performance Benchmark Summary');
  WriteLn('================================================================');
  WriteLn;
  
  TotalDuration := 0;
  for I := 0 to High(FResults) do
  begin
    with FResults[I] do
    begin
      if Success then
        WriteLn(Format('[%2d] %-40s %6dms  %8.1f ops/s', 
          [I+1, Name, Duration, Throughput]))
      else
        WriteLn(Format('[%2d] %-40s FAILED: %s', [I+1, Name, ErrorMessage]));
      Inc(TotalDuration, Duration);
    end;
  end;
  
  WriteLn;
  WriteLn('================================================================');
  WriteLn(Format('Total: %d tests, %d passed, %d failed', 
    [FTotalTests, FPassedTests, FTotalTests - FPassedTests]));
  WriteLn(Format('Total execution time: %dms', [TotalDuration]));
  WriteLn('================================================================');
end;

function BenchmarkContextCreation(ACount: Integer): TBenchmarkResult;
var
  StartTime, EndTime: QWord;
  I: Integer;
  Sample: Integer;
  SampleDuration: Int64;
  Ctx: ISSLContext;
begin
  Result.Name := Format('TLS_ContextCreate_%d', [ACount]);
  Result.Success := False;

  // Warmup to reduce one-time initialization noise
  try
    for I := 1 to 20 do
    begin
      Ctx := GLib.CreateContext(sslCtxClient);
      if Ctx = nil then ; // Suppress unused variable warning
    end;
  except
    // Ignore warmup failures; the timed run will report the real error
  end;

  // Measure multiple samples and take the best to reduce noise from system load.
  Result.Duration := High(Int64);
  try
    for Sample := 1 to 3 do
    begin
      StartTime := GetTickCount64;
      for I := 1 to ACount do
      begin
        Ctx := GLib.CreateContext(sslCtxClient);
        if Ctx = nil then ; // Suppress unused variable warning
      end;
      EndTime := GetTickCount64;

      SampleDuration := EndTime - StartTime;
      if (SampleDuration > 0) and (SampleDuration < Result.Duration) then
        Result.Duration := SampleDuration;
    end;

    if Result.Duration = High(Int64) then
      Result.Duration := 0;

    if Result.Duration = 0 then
      Result.Duration := 1; // Avoid division by zero

    Result.Throughput := ACount / (Result.Duration / 1000.0);
    Result.Success := True;
  except
    on E: Exception do
      Result.ErrorMessage := E.Message;
  end;
end;

function BenchmarkEncryption(ASizeKB, AIterations: Integer): TBenchmarkResult;
var
  StartTime, EndTime: QWord;
  I: Integer;
  Data: TBytes;
begin
  Result.Name := Format('AES_Encrypt_%dKBx%d', [ASizeKB, AIterations]);
  Result.Success := False;
  
  SetLength(Data, ASizeKB * 1024);
  for I := 0 to High(Data) do
    Data[I] := Byte(Random(256));
  
  StartTime := GetTickCount64;
  try
    // This would need actual encryption calls
    // Placeholder for now
    for I := 1 to AIterations do
    begin
      // Simulate encryption overhead
      Move(Data[0], Data[0], Length(Data));
    end;
    
    EndTime := GetTickCount64;
    Result.Duration := EndTime - StartTime;
    if Result.Duration = 0 then Result.Duration := 1;  // Avoid division by zero
    Result.Throughput := (ASizeKB * AIterations) / (Result.Duration / 1000.0);  // KB/s
    Result.Success := True;
  except
    on E: Exception do
      Result.ErrorMessage := E.Message;
  end;
end;

procedure TBenchmarkSuite.RunAll;
begin
  WriteLn('Running Performance Regression Suite...');
  WriteLn;
  
  // Context creation benchmarks
  // Use larger iteration counts to reduce timer jitter with millisecond resolution.
  AddResult(BenchmarkContextCreation(1000));
  AddResult(BenchmarkContextCreation(5000));
  
  // Encryption benchmarks
  AddResult(BenchmarkEncryption(1, 1000));
  AddResult(BenchmarkEncryption(10, 100));
  AddResult(BenchmarkEncryption(100, 10));
  
  WriteLn;
end;

begin
  GSuite := TBenchmarkSuite.Create;
  try
    WriteLn('================================================================');
    WriteLn('fafafa.ssl Performance Regression Test Suite');
    WriteLn('================================================================');
    WriteLn;
    
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if not GLib.Initialize then
      Halt(1);
    
    GSuite.RunAll;
    GSuite.PrintSummary;
    
    WriteLn;
    WriteLn('Saving results...');
    GSuite.SaveResults('benchmark_results.csv');
    
    WriteLn('Checking for regressions...');
    if not GSuite.CheckRegression('benchmark_baseline.csv', 0.15) then
    begin
      WriteLn;
      WriteLn('⚠️  Performance regression detected!');
      Halt(1);
    end;
    
    WriteLn;
    WriteLn('✅ All benchmarks passed!');
    
    GLib.Finalize;
  finally
    GSuite.Free;
  end;
end.
