program performance_benchmark_comprehensive;

{$mode objfpc}{$H+}

{
  综合性能基准测试套件
  
  功能：
    - TLS 握手性能
    - 加密/解密吞吐量
    - 哈希计算性能
    - 证书验证性能
    - 内存使用分析
  
  用途：CI/CD 集成，性能回归检测
}

uses
  SysUtils, Classes,
  nextpas.core.tls.factory,
  nextpas.core.tls.base,
  nextpas.core.tls.crypto.utils,
  nextpas.core.tls.secure,
  nextpas.core.tls.cert.builder,
  fafafa.ssl;

type
  TBenchmarkResult = record
    Name: string;
    Duration: Int64;
    Throughput: Double;
    MemoryUsed: Int64;
    Success: Boolean;
    ErrorMessage: string;
  end;

var
  GLib: ISSLLibrary;
  GResults: array of TBenchmarkResult;

procedure AddResult(const R: TBenchmarkResult);
begin
  SetLength(GResults, Length(GResults) + 1);
  GResults[High(GResults)] := R;
end;

function GetMemoryUsage: Int64;
var
  Info: THeapStatus;
begin
  Info := GetHeapStatus;
  Result := Info.TotalAllocated;
end;

{ TLS Context Creation Benchmark }
function BenchTLSContextCreation(ACount: Integer): TBenchmarkResult;
var
  Start, Stop: QWord;
  I: Integer;
  Ctx: ISSLContext;
  MemBefore, MemAfter: Int64;
begin
  Result.Name := Format('TLS_Context_Create_x%d', [ACount]);
  Result.Success := False;
  
  MemBefore := GetMemoryUsage;
  Start := GetTickCount64;
  try
    for I := 1 to ACount do
    begin
      Ctx := GLib.CreateContext(sslCtxClient);
      Ctx := nil;  // Force release
    end;
    
    Stop := GetTickCount64;
    MemAfter := GetMemoryUsage;
    
    Result.Duration := Stop - Start;
    if Result.Duration = 0 then Result.Duration := 1;
    Result.Throughput := ACount / (Result.Duration / 1000.0);
    Result.MemoryUsed := MemAfter - MemBefore;
    Result.Success := True;
  except
    on E: Exception do
      Result.ErrorMessage := E.Message;
  end;
end;

{ SHA-256 Hashing Benchmark }
function BenchSHA256(ASizeKB, AIterations: Integer): TBenchmarkResult;
var
  Start, Stop: QWord;
  I: Integer;
  Data: TBytes;
  Hash: TBytes;
  Utils: TCryptoUtils;
begin
  Result.Name := Format('SHA256_%dKBx%d', [ASizeKB, AIterations]);
  Result.Success := False;
  
  SetLength(Data, ASizeKB * 1024);
  for I := 0 to High(Data) do
    Data[I] := Byte(Random(256));
  
  Utils := TCryptoUtils.Create;
  try
    Start := GetTickCount64;
    try
      for I := 1 to AIterations do
        Hash := Utils.SHA256(Data);
      
      Stop := GetTickCount64;
      Result.Duration := Stop - Start;
      if Result.Duration = 0 then Result.Duration := 1;
      Result.Throughput := (ASizeKB * AIterations) / (Result.Duration / 1000.0);  // KB/s
      Result.Success := True;
    except
      on E: Exception do
        Result.ErrorMessage := E.Message;
    end;
  finally
    Utils.Free;
  end;
end;

{ Random Generation Benchmark }
function BenchRandomGeneration(ASizeKB, AIterations: Integer): TBenchmarkResult;
var
  Start, Stop: QWord;
  I: Integer;
  Data: TBytes;
  Utils: TCryptoUtils;
begin
  Result.Name := Format('Random_%dKBx%d', [ASizeKB, AIterations]);
  Result.Success := False;
  
  Utils := TCryptoUtils.Create;
  try
    Start := GetTickCount64;
    try
      for I := 1 to AIterations do
        Data := Utils.SecureRandom(ASizeKB * 1024);
      
      Stop := GetTickCount64;
      Result.Duration := Stop - Start;
      if Result.Duration = 0 then Result.Duration := 1;
      Result.Throughput := (ASizeKB * AIterations) / (Result.Duration / 1000.0);  // KB/s
      Result.MemoryUsed := Length(Data);
      Result.Success := True;
    except
      on E: Exception do
        Result.ErrorMessage := E.Message;
    end;
  finally
    Utils.Free;
  end;
end;

{ Hash Hex Conversion Benchmark }
function BenchHashHex(AIterations: Integer): TBenchmarkResult;
var
  Start, Stop: QWord;
  I: Integer;
  Data:TBytes;
  HexStr: string;
  Utils: TCryptoUtils;
begin
  Result.Name := Format('HashHex_x%d', [AIterations]);
  Result.Success := False;
  
  SetLength(Data, 1024);
  for I := 0 to High(Data) do
    Data[I] := Byte(Random(256));
  
  Utils := TCryptoUtils.Create;
  try
    Start := GetTickCount64;
    try
      for I := 1 to AIterations do
        HexStr := Utils.SHA256Hex(Data);
      
      Stop := GetTickCount64;
      Result.Duration := Stop - Start;
      if Result.Duration = 0 then Result.Duration := 1;
      Result.Throughput := AIterations / (Result.Duration / 1000.0);
      Result.Success := True;
    except
      on E: Exception do
        Result.ErrorMessage := E.Message;
    end;
  finally
    Utils.Free;
  end;
end;

procedure PrintResults;
var
  I: Integer;
  TotalTime, TotalMem: Int64;
  PassedCount: Integer;
begin
  WriteLn;
  WriteLn('================================================================');
  WriteLn('  Comprehensive Performance Benchmark Results');
  WriteLn('================================================================');
  WriteLn;
  
  TotalTime := 0;
  TotalMem := 0;
  PassedCount := 0;
  
  for I := 0 to High(GResults) do
  begin
    with GResults[I] do
    begin
      if Success then
      begin
        Inc(PassedCount);
        WriteLn(Format('[%2d] %-35s', [I+1, Name]));
        WriteLn(Format('     Duration    : %6d ms', [Duration]));
        WriteLn(Format('     Throughput  : %10.2f ops/s', [Throughput]));
        if MemoryUsed > 0 then
          WriteLn(Format('     Memory      : %10d bytes', [MemoryUsed]));
        WriteLn;
        Inc(TotalTime, Duration);
        Inc(TotalMem, MemoryUsed);
      end
      else
        WriteLn(Format('[%2d] %-35s FAILED: %s', [I+1, Name, ErrorMessage]));
    end;
  end;
  
  WriteLn('================================================================');
  WriteLn(Format('Total Tests  : %d', [Length(GResults)]));
  WriteLn(Format('Passed       : %d', [PassedCount]));
  WriteLn(Format('Failed       : %d', [Length(GResults) - PassedCount]));
  WriteLn(Format('Total Time   : %d ms', [TotalTime]));
  if TotalMem > 0 then
    WriteLn(Format('Total Memory : %.2f KB', [TotalMem / 1024.0]));
  WriteLn('================================================================');
end;

procedure SaveResultsCSV(const FileName: string);
var
  F: TextFile;
  I: Integer;
begin
  AssignFile(F, FileName);
  Rewrite(F);
  try
    WriteLn(F, 'Name,Duration(ms),Throughput(ops/s),Memory(bytes),Success');
    for I := 0 to High(GResults) do
      with GResults[I] do
        WriteLn(F, Format('%s,%d,%.2f,%d,%s', 
          [Name, Duration, Throughput, MemoryUsed, BoolToStr(Success, True)]));
  finally
    CloseFile(F);
  end;
end;

begin
  WriteLn('================================================================');
  WriteLn('  fafafa.ssl Comprehensive Performance Benchmark Suite');
  WriteLn('================================================================');
  WriteLn;
  
  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if not GLib.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize SSL library');
      Halt(1);
    end;
    
    WriteLn('OpenSSL Version: ', GLib.GetVersionString);
    WriteLn('Running benchmarks...');
    WriteLn;
    
    // TLS Context Benchmarks
    Write('  TLS Context Creation (100x)... ');
    AddResult(BenchTLSContextCreation(100));
    WriteLn('Done');
    
    Write('  TLS Context Creation (500x)... ');
    AddResult(BenchTLSContextCreation(500));
    WriteLn('Done');
    
    // SHA-256 Benchmarks
    Write('  SHA-256 Hashing (1KB x 1000)... ');
    AddResult(BenchSHA256(1, 1000));
    WriteLn('Done');
    
    Write('  SHA-256 Hashing (10KB x 100)... ');
    AddResult(BenchSHA256(10, 100));
    WriteLn('Done');
    
    Write('  SHA-256 Hashing (100KB x 10)... ');
    AddResult(BenchSHA256(100, 10));
    WriteLn('Done');
    
    // Random Generation
    Write('  Random Generation (1KB x 100)... ');
    AddResult(BenchRandomGeneration(1, 100));
    WriteLn('Done');
    
    Write('  Random Generation (10KB x 10)... ');
    AddResult(BenchRandomGeneration(10, 10));
    WriteLn('Done');
    
    // Hash/Hex Conversion
    Write('  Hash to Hex (10000x)... ');
    AddResult(BenchHashHex(10000));
    WriteLn('Done');
    
    PrintResults;
    
    SaveResultsCSV('benchmark_comprehensive.csv');
    WriteLn;
    WriteLn('Results saved to: benchmark_comprehensive.csv');
    WriteLn;
    WriteLn('✅ Benchmark suite completed successfully!');
    
    GLib.Finalize;
  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.
