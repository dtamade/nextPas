program test_direct_cache;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.wolfssl.lib,
  nextpas.core.tls.mbedtls.lib;

procedure TestCache(Lib: ISSLLibrary; const Name: string);
var
  Caps1, Caps2: TSSLBackendCapabilities;
  i: Integer;
  StartTime: QWord;
  CachedTime: QWord;
begin
  WriteLn('==============================================');
  WriteLn('测试 ', Name, ' 后端缓存');
  WriteLn('==============================================');

  if not Lib.Initialize then
  begin
    WriteLn('✗ 初始化失败');
    WriteLn;
    Exit;
  end;

  WriteLn('✓ 已初始化');
  WriteLn('  版本: ', Lib.GetVersionString);

  // 首次调用
  WriteLn('首次调用 GetCapabilities...');
  Caps1 := Lib.GetCapabilities;
  WriteLn('  Backend: ', Ord(Caps1.BackendType));
  WriteLn('  TLS 1.3: ', Caps1.SupportsTLS13);

  // 测试缓存性能
  WriteLn('测试缓存（10000次）...');
  StartTime := GetTickCount64;
  for i := 1 to 10000 do
    Caps2 := Lib.GetCapabilities;
  CachedTime := GetTickCount64 - StartTime;

  WriteLn('  耗时: ', CachedTime, ' ms');
  if CachedTime > 0 then
    WriteLn('  吞吐量: ', (10000 div CachedTime), 'K ops/s')
  else
    WriteLn('  吞吐量: >10M ops/s');

  // 验证一致性
  if (Caps2.BackendType = Caps1.BackendType) and
     (Caps2.SupportsTLS13 = Caps1.SupportsTLS13) then
    WriteLn('  ✓ 缓存内容正确')
  else
    WriteLn('  ✗ 缓存内容不一致');

  // 测试失效
  WriteLn('测试缓存失效...');
  Lib.Finalize;
  if Lib.Initialize then
  begin
    Caps2 := Lib.GetCapabilities;
    if Caps2.BackendType = Caps1.BackendType then
      WriteLn('  ✓ 缓存已重建')
    else
      WriteLn('  ✗ 缓存重建失败');
  end;

  Lib.Finalize;
  WriteLn('✓ 测试完成');
  WriteLn;
end;

var
  OpenSSLLib: ISSLLibrary;
  WolfSSLLib: ISSLLibrary;
  MbedTLSLib: ISSLLibrary;
begin
  WriteLn;
  WriteLn('fafafa.ssl - 直接后端缓存测试');
  WriteLn('==============================================');
  WriteLn;

  // 测试 OpenSSL
  try
    OpenSSLLib := CreateOpenSSLLibrary;
    TestCache(OpenSSLLib, 'OpenSSL');
  except
    on E: Exception do
      WriteLn('OpenSSL 不可用: ', E.Message, #10);
  end;

  // 测试 WolfSSL
  try
    WolfSSLLib := CreateWolfSSLLibrary;
    TestCache(WolfSSLLib, 'WolfSSL');
  except
    on E: Exception do
      WriteLn('WolfSSL 不可用: ', E.Message, #10);
  end;

  // 测试 MbedTLS
  try
    MbedTLSLib := CreateMbedTLSLibrary;
    TestCache(MbedTLSLib, 'MbedTLS');
  except
    on E: Exception do
      WriteLn('MbedTLS 不可用: ', E.Message, #10);
  end;

  WriteLn('==============================================');
  WriteLn('所有测试完成！');
  WriteLn('==============================================');
end.
