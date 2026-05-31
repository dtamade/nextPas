program test_openssl_basic;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.factory,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed;

var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
begin
  WriteLn('========================================');
  WriteLn('OpenSSL Backend Basic Test');
  WriteLn('========================================');
  WriteLn;
  
  // 测试1: 创建OpenSSL库
  WriteLn('[TEST 1] Creating OpenSSL library...');
  Lib := CreateOpenSSLLibrary;
  if Lib <> nil then
    WriteLn('  [✓] Library created')
  else
  begin
    WriteLn('  [✗] Failed to create library');
    Halt(1);
  end;
  
  // 测试2: 初始化
  WriteLn('[TEST 2] Initializing OpenSSL...');
  if Lib.Initialize then
  begin
    WriteLn('  [✓] Initialized successfully');
    WriteLn('  Version: ', Lib.GetVersionString);
    WriteLn('  Type: ', LibraryTypeToString(Lib.GetLibraryType));
  end
  else
  begin
    WriteLn('  [✗] Failed to initialize');
    WriteLn('  Error: ', Lib.GetLastErrorString);
    Halt(1);
  end;
  
  // 测试3: 协议支持
  WriteLn('[TEST 3] Protocol support...');
  WriteLn('  TLS 1.2: ', BoolToStr(Lib.IsProtocolSupported(sslProtocolTLS12), True));
  WriteLn('  TLS 1.3: ', BoolToStr(Lib.IsProtocolSupported(sslProtocolTLS13), True));
  
  // 测试4: 创建Context
  WriteLn('[TEST 4] Creating SSL context...');
  Ctx := Lib.CreateContext(sslCtxClient);
  if Ctx <> nil then
    WriteLn('  [✓] Context created')
  else
  begin
    WriteLn('  [✗] Failed to create context');
    Halt(1);
  end;
  
  // 测试5: 配置Context
  WriteLn('[TEST 5] Configuring context...');
  Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
  Ctx.SetVerifyMode([sslVerifyPeer]);
  WriteLn('  [✓] Context configured');
  
  // 清理
  WriteLn('[TEST 6] Cleanup...');
  Ctx := nil;
  Lib.Finalize;
  Lib := nil;
  WriteLn('  [✓] Cleanup complete');
  
  WriteLn;
  WriteLn('========================================');
  WriteLn('All tests PASSED!');
  WriteLn('========================================');
end.
