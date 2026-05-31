program benchmark_crypto;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  benchmark_utils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.secure,
  nextpas.core.tls.crypto.utils,
  nextpas.core.tls.encoding,  // Phase 2.3.6: Base64 functions moved here
  fafafa.ssl;

const
  ITERATIONS = 10000;
  DATA_SIZE_1KB = 1024;
  DATA_SIZE_1MB = 1024 * 1024;
  DATA_SIZE_10MB = 10 * 1024 * 1024;

var
  LData1KB, LData1MB, LData10MB: TBytes;
  LBench: TBenchmark;
  I: Integer;
  LHash: TBytes;
  LDerived: TBytes;
  LLib: ISSLLibrary;

procedure BenchmarkSHA256;
begin
  PrintHeader('SHA-256 Hash Performance');
  
  // 1KB
  LBench := TBenchmark.Create('SHA-256 (1 KB x 10000)');
  LBench.SetDataSize(Int64(DATA_SIZE_1KB) * ITERATIONS);
  LBench.Start;
  for I := 1 to ITERATIONS do
    LHash := TCryptoUtils.SHA256(LData1KB);
  LBench.Stop;
  LBench.ReportThroughput;
  LBench.Free;
  
  // 1MB
  LBench := TBenchmark.Create('SHA-256 (1 MB x 100)');
  LBench.SetDataSize(Int64(DATA_SIZE_1MB) * 100);
  LBench.Start;
  for I := 1 to 100 do
    LHash := TCryptoUtils.SHA256(LData1MB);
  LBench.Stop;
  LBench.ReportThroughput;
  LBench.Free;
  
  // 10MB
  LBench := TBenchmark.Create('SHA-256 (10 MB x 10)');
  LBench.SetDataSize(Int64(DATA_SIZE_10MB) * 10);
  LBench.Start;
  for I := 1 to 10 do
    LHash := TCryptoUtils.SHA256(LData10MB);
  LBench.Stop;
  LBench.ReportThroughput;
  LBench.Free;
  
  WriteLn;
end;

procedure BenchmarkSHA512;
begin
  PrintHeader('SHA-512 Hash Performance');
  
  // 1KB
  LBench := TBenchmark.Create('SHA-512 (1 KB x 10000)');
  LBench.SetDataSize(Int64(DATA_SIZE_1KB) * ITERATIONS);
  LBench.Start;
  for I := 1 to ITERATIONS do
    LHash := TCryptoUtils.SHA512(LData1KB);
  LBench.Stop;
  LBench.ReportThroughput;
  LBench.Free;
  
  // 1MB
  LBench := TBenchmark.Create('SHA-512 (1 MB x 100)');
  LBench.SetDataSize(Int64(DATA_SIZE_1MB) * 100);
  LBench.Start;
  for I := 1 to 100 do
    LHash := TCryptoUtils.SHA512(LData1MB);
  LBench.Stop;
  LBench.ReportThroughput;
  LBench.Free;
  
  WriteLn;
end;

procedure BenchmarkHKDF;
const
  HKDF_ITERATIONS = 1000;
var
  LSalt, LInfo: TBytes;
begin
  PrintHeader('HKDF Key Derivation Performance');

  LSalt := TEncoding.UTF8.GetBytes('benchmark-salt');
  LInfo := TEncoding.UTF8.GetBytes('benchmark-info');

  LBench := TBenchmark.Create('HKDF-SHA256 (32 bytes x 1000)');
  LBench.SetIterations(HKDF_ITERATIONS);
  LBench.Start;
  for I := 1 to HKDF_ITERATIONS do
    LDerived := TCryptoUtils.HKDF(LData1KB, LSalt, LInfo, 32, HASH_SHA256);
  LBench.Stop;
  LBench.Report;
  LBench.Free;

  WriteLn;
end;

procedure BenchmarkBase64;
const
  B64_ITERATIONS = 10000;
var
  LEncoded: string;
  LDecoded: TBytes;
begin
  PrintHeader('Base64 Encode/Decode Performance');

  // Encode
  LBench := TBenchmark.Create('Base64 Encode (1 KB x 10000)');
  LBench.SetDataSize(Int64(DATA_SIZE_1KB) * B64_ITERATIONS);
  LBench.Start;
  for I := 1 to B64_ITERATIONS do
    LEncoded := TEncodingUtils.Base64Encode(LData1KB);
  LBench.Stop;
  LBench.ReportThroughput;
  LBench.Free;

  // Decode
  LEncoded := TEncodingUtils.Base64Encode(LData1KB);
  LBench := TBenchmark.Create('Base64 Decode (1 KB x 10000)');
  LBench.SetDataSize(Int64(DATA_SIZE_1KB) * B64_ITERATIONS);
  LBench.Start;
  for I := 1 to B64_ITERATIONS do
    LDecoded := TEncodingUtils.Base64Decode(LEncoded);
  LBench.Stop;
  LBench.ReportThroughput;
  LBench.Free;

  WriteLn;
end;

procedure InitializeTestData;
var
  I: Integer;
begin
  // Generate random test data
  SetLength(LData1KB, DATA_SIZE_1KB);
  SetLength(LData1MB, DATA_SIZE_1MB);
  SetLength(LData10MB, DATA_SIZE_10MB);
  
  for I := 0 to DATA_SIZE_1KB - 1 do
    LData1KB[I] := Byte(Random(256));
    
  for I := 0 to DATA_SIZE_1MB - 1 do
    LData1MB[I] := Byte(Random(256));
    
  for I := 0 to DATA_SIZE_10MB - 1 do
    LData10MB[I] := Byte(Random(256));
end;

begin
  WriteLn('====================================');
  WriteLn('  Crypto Performance Benchmarks');
  WriteLn('====================================');
  WriteLn;
  WriteLn('Platform: ', {$I %FPCTARGETOS%});
  WriteLn('Compiler: FPC ', {$I %FPCVERSION%});
  WriteLn;
  
  // Initialize SSL library
  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  if not LLib.Initialize then
  begin
    WriteLn('ERROR: Failed to initialize OpenSSL library');
    Halt(1);
  end;
  WriteLn('SSL Library: ', LLib.GetVersionString);
  WriteLn;
  
  Randomize;
  InitializeTestData;
  
  BenchmarkSHA256;
  BenchmarkSHA512;
  BenchmarkHKDF;
  BenchmarkBase64;
  
  WriteLn('====================================');
  WriteLn('  Benchmarks Complete');
  WriteLn('====================================');
end.
