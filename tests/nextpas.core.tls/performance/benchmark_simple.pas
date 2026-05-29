program benchmark_simple;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils,
  nextpas.core.tls.factory,
  nextpas.core.tls.utils,
  fafafa.ssl;

const
  ITERATIONS = 10000;
  TEST_DATA = 'The quick brown fox jumps over the lazy dog';

var
  I: Integer;
  StartTime, EndTime: TDateTime;
  ElapsedMS: Int64;
  Hash: string;
  Lib: ISSLLibrary;

procedure PrintResult(const TestName: string; Iterations: Integer; ElapsedMS: Int64);
var
  OpsPerSec: Double;
  AvgTimeUS: Double;
begin
  if ElapsedMS > 0 then
  begin
    OpsPerSec := (Iterations / ElapsedMS) * 1000;
    AvgTimeUS := (ElapsedMS * 1000.0) / Iterations;
  end
  else
  begin
    OpsPerSec := 0;
    AvgTimeUS := 0;
  end;
  
  WriteLn(Format('%-25s %8d ops in %6d ms | %10.2f ops/sec | %8.2f µs/op', 
    [TestName, Iterations, ElapsedMS, OpsPerSec, AvgTimeUS]));
end;

begin
  WriteLn('========================================');
  WriteLn('fafafa.ssl 性能基准测试');
  WriteLn('========================================');
  WriteLn;
  
  // 检测SSL库
  Lib := GetLibraryInstance(DetectBestLibrary);
  if not Lib.Initialize then
  begin
    WriteLn('错误: 无法初始化SSL库');
    Halt(1);
  end;
  
  WriteLn('SSL库: ', Lib.GetVersionString);
  WriteLn('测试数据: "', TEST_DATA, '"');
  WriteLn('迭代次数: ', ITERATIONS);
  WriteLn;
  
  WriteLn('=== 哈希算法基准 ===');
  WriteLn;
  
  // SHA-256基准测试
  Write('测试 SHA-256...');
  StartTime := Now;
  for I := 1 to ITERATIONS do
    Hash := SHA256Hash(TEST_DATA);
  EndTime := Now;
  ElapsedMS := MilliSecondsBetween(EndTime, StartTime);
  WriteLn(' ✓');
  PrintResult('  SHA-256', ITERATIONS, ElapsedMS);
  WriteLn('  示例输出: ', Copy(Hash, 1, 32), '...');
  WriteLn;
  
  // SHA-1基准测试
  Write('测试 SHA-1...');
  StartTime := Now;
  for I := 1 to ITERATIONS do
    Hash := SHA1Hash(TEST_DATA);
  EndTime := Now;
  ElapsedMS := MilliSecondsBetween(EndTime, StartTime);
  WriteLn(' ✓');
  PrintResult('  SHA-1', ITERATIONS, ElapsedMS);
  WriteLn('  示例输出: ', Hash);
  WriteLn;
  
  // MD5基准测试
  Write('测试 MD5...');
  StartTime := Now;
  for I := 1 to ITERATIONS do
    Hash := MD5Hash(TEST_DATA);
  EndTime := Now;
  ElapsedMS := MilliSecondsBetween(EndTime, StartTime);
  WriteLn(' ✓');
  PrintResult('  MD5', ITERATIONS, ElapsedMS);
  WriteLn('  示例输出: ', Hash);
  WriteLn;
  
  WriteLn('========================================');
  WriteLn('测试完成');
  WriteLn('========================================');
  
  // 性能总结
  WriteLn;
  WriteLn('性能总结:');
  WriteLn('- 所有哈希函数性能良好');
  WriteLn('- SHA-256: 企业级加密哈希');
  WriteLn('- SHA-1: 快速但不推荐用于安全');
  WriteLn('- MD5: 仅用于校验，不用于安全');
end.

