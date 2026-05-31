program benchmark_openssl;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core;

var
  StartTime, EndTime: TDateTime;
  ElapsedMS: Int64;
  I: Integer;

procedure PrintResult(const TestName: string; ElapsedMS: Int64);
begin
  WriteLn(Format('%-30s %6d ms', [TestName, ElapsedMS]));
end;

begin
  WriteLn('========================================');
  WriteLn('fafafa.ssl 性能基准测试');
  WriteLn('========================================');
  WriteLn;
  
  // 加载OpenSSL
  Write('加载OpenSSL...');
  try
    LoadOpenSSLCore;
    WriteLn(' ✓');
  except
    on E: Exception do
    begin
      WriteLn(' ✗');
      WriteLn('错误: ', E.Message);
      Halt(1);
    end;
  end;
  
  WriteLn('OpenSSL版本: ', GetOpenSSLVersionString);
  WriteLn;
  
  WriteLn('=== 基础性能测试 ===');
  WriteLn;
  
  // 测试1: 库加载性能
  Write('测试库加载/卸载...');
  StartTime := Now;
  for I := 1 to 100 do
  begin
    UnloadOpenSSLCore;
    LoadOpenSSLCore;
  end;
  EndTime := Now;
  ElapsedMS := MilliSecondsBetween(EndTime, StartTime);
  WriteLn(' ✓');
  PrintResult('  100次加载/卸载', ElapsedMS);
  WriteLn;
  
  WriteLn('========================================');
  WriteLn('测试完成');
  WriteLn('========================================');
  WriteLn;
  WriteLn('说明:');
  WriteLn('- 这是一个基础性能基准测试');
  WriteLn('- 更复杂的性能测试需要完整的EVP API绑定');
  WriteLn('- 建议使用OpenSSL自带的`openssl speed`命令进行详细性能测试');
  WriteLn;
  WriteLn('运行OpenSSL原生性能测试:');
  WriteLn('  openssl speed sha256');
  WriteLn('  openssl speed aes-256-cbc');
  WriteLn('  openssl speed rsa2048');
end.

