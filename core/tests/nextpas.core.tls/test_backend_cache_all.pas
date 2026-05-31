program test_backend_cache_all;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory;

procedure TestBackendCache(ABackendType: TSSLLibraryType; const ABackendName: string);
var
  Lib: ISSLLibrary;
  Caps1, Caps2: TSSLBackendCapabilities;
  i: Integer;
  StartTime: QWord;
  FirstCallTime, CachedCallTime: QWord;
begin
  WriteLn('==============================================');
  WriteLn('测试 ', ABackendName, ' 后端缓存');
  WriteLn('==============================================');
  WriteLn;

  // 创建库实例
  try
    Lib := TSSLFactory.GetLibrary(ABackendType);
  except
    on E: Exception do
    begin
      WriteLn('⚠ ', ABackendName, ' 后端不可用: ', E.Message);
      WriteLn;
      Exit;
    end;
  end;

  // 初始化
  if not Lib.Initialize then
  begin
    WriteLn('✗ ', ABackendName, ' 初始化失败');
    WriteLn;
    Exit;
  end;

  WriteLn('✓ ', ABackendName, ' 已初始化');
  WriteLn('  版本: ', Lib.GetVersionString);
  WriteLn;

  // 测试首次调用
  WriteLn('首次调用 GetCapabilities（应生成）...');
  StartTime := GetTickCount64;
  Caps1 := Lib.GetCapabilities;
  FirstCallTime := GetTickCount64 - StartTime;
  WriteLn('  耗时: ', FirstCallTime, ' ms');
  WriteLn('  后端类型: ', Ord(Caps1.BackendType));
  WriteLn('  支持 TLS 1.3: ', Caps1.SupportsTLS13);
  WriteLn('  支持 ALPN: ', Caps1.SupportsALPN);
  WriteLn;

  // 测试缓存调用性能
  WriteLn('测试缓存性能（10000 次调用）...');
  StartTime := GetTickCount64;
  for i := 1 to 10000 do
  begin
    Caps2 := Lib.GetCapabilities;
  end;
  CachedCallTime := GetTickCount64 - StartTime;

  WriteLn('  总耗时: ', CachedCallTime, ' ms');
  WriteLn('  平均每次: ', (CachedCallTime / 10000):0:6, ' ms');
  if CachedCallTime > 0 then
    WriteLn('  吞吐量: ', (10000 div CachedCallTime), 'K ops/s')
  else
    WriteLn('  吞吐量: >10M ops/s');
  WriteLn;

  // 验证缓存内容一致性
  WriteLn('验证缓存内容一致性...');
  if Caps2.BackendType = Caps1.BackendType then
    WriteLn('  ✓ Backend Type 一致')
  else
    WriteLn('  ✗ Backend Type 不一致');

  if Caps2.SupportsTLS13 = Caps1.SupportsTLS13 then
    WriteLn('  ✓ TLS 1.3 支持一致')
  else
    WriteLn('  ✗ TLS 1.3 支持不一致');

  if Caps2.SupportsALPN = Caps1.SupportsALPN then
    WriteLn('  ✓ ALPN 支持一致')
  else
    WriteLn('  ✗ ALPN 支持不一致');
  WriteLn;

  // 测试缓存失效
  WriteLn('测试缓存失效（Finalize 后）...');
  Lib.Finalize;

  if not Lib.Initialize then
  begin
    WriteLn('✗ 重新初始化失败');
  end
  else
  begin
    WriteLn('  ✓ 重新初始化成功');
    Caps2 := Lib.GetCapabilities;
    WriteLn('  ✓ 可以获取新的能力矩阵');

    if Caps2.BackendType = Caps1.BackendType then
      WriteLn('  ✓ 内容正确（BackendType 匹配）')
    else
      WriteLn('  ✗ 内容不正确');
  end;
  WriteLn;

  Lib.Finalize;
  WriteLn('✓ ', ABackendName, ' 后端缓存测试完成');
  WriteLn;
end;

var
  i: Integer;
  BackendList: array[0..3] of record
    BackendType: TSSLLibraryType;
    Name: string;
  end;

begin
  WriteLn;
  WriteLn('fafafa.ssl - 多后端缓存测试');
  WriteLn('==============================================');
  WriteLn('测试 OpenSSL, WolfSSL, MbedTLS, WinSSL 后端');
  WriteLn('==============================================');
  WriteLn;

  // 准备后端列表
  BackendList[0].BackendType := sslOpenSSL;
  BackendList[0].Name := 'OpenSSL';

  BackendList[1].BackendType := sslWolfSSL;
  BackendList[1].Name := 'WolfSSL';

  BackendList[2].BackendType := sslMbedTLS;
  BackendList[2].Name := 'MbedTLS';

  BackendList[3].BackendType := sslWinSSL;
  BackendList[3].Name := 'WinSSL';

  // 测试每个后端
  for i := 0 to High(BackendList) do
  begin
    TestBackendCache(BackendList[i].BackendType, BackendList[i].Name);
  end;

  WriteLn('==============================================');
  WriteLn('所有后端缓存测试完成！');
  WriteLn('==============================================');
end.
