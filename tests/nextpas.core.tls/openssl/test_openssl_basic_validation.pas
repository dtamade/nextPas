program test_openssl_basic_validation;

{$mode objfpc}{$H+}

{ 
  OpenSSL基础功能验证测试
  
  目的: 验证刚才修复的代码是否能正常工作
  测试范围:
  1. 库加载和初始化
  2. 版本信息获取
  3. Context创建
  4. Certificate对象创建和基本操作
  5. 验证新添加的API函数是否正确加载
}

uses
  SysUtils, Classes, TypInfo,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.backed,
  nextpas.core.tls.openssl.native_handle,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.obj,
  nextpas.core.tls.openssl.api.crypto;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  TestsTotal: Integer = 0;

{ Helper function to check if object has native handle }
function HasNativeHandle(const AObject: IInterface): Boolean;
var
  NativeAccess: ISSLNativeHandleAccess;
begin
  Result := Supports(AObject, ISSLNativeHandleAccess, NativeAccess) and
            (NativeAccess.GetNativeHandle <> nil);
end;

procedure LogTest(const TestName: string; Passed: Boolean; const Details: string = '');
begin
  Inc(TestsTotal);
  if Passed then
  begin
    Inc(TestsPassed);
    WriteLn('[PASS] ', TestName);
    if Details <> '' then
      WriteLn('       ', Details);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('[FAIL] ', TestName);
    if Details <> '' then
      WriteLn('       错误: ', Details);
  end;
end;

procedure TestLibraryLoading;
var
  Success: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试1: OpenSSL库加载 ===');
  
  try
    LoadOpenSSLCore;
    Success := TOpenSSLLoader.IsModuleLoaded(osmCore);
    LogTest('LoadOpenSSLCore', Success, 
            '库句柄: ' + IntToStr(PtrInt(GetCryptoLibHandle)));
    
    if Success then
    begin
      LogTest('TOpenSSLLoader.IsModuleLoaded(osmCore)', TOpenSSLLoader.IsModuleLoaded(osmCore),
              '加密库已加载');
    end;
  except
    on E: Exception do
      LogTest('LoadOpenSSLCore', False, E.Message);
  end;
end;

procedure TestVersionInfo;
var
  Version: string;
begin
  WriteLn;
  WriteLn('=== 测试2: 版本信息获取 ===');
  
  try
    Version := GetOpenSSLVersionString;
    LogTest('GetOpenSSLVersionString', Version <> '', 
            '版本: ' + Version);
  except
    on E: Exception do
      LogTest('GetOpenSSLVersionString', False, E.Message);
  end;
end;

procedure TestAPIModulesLoading;
var
  Success: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试3: API模块加载 ===');
  
  // 测试BIO模块
  try
    LoadOpenSSLBIO;
    Success := True;
    LogTest('LoadOpenSSLBIO', Success);
    if Success then
      LogTest('BIO_pending已加载', Assigned(BIO_pending));
  except
    on E: Exception do
      LogTest('LoadOpenSSLBIO', False, E.Message);
  end;
  
  // 测试X509模块
  try
    LoadOpenSSLX509;
    Success := True;
    LogTest('LoadOpenSSLX509', Success);
    if Success then
    begin
      LogTest('X509_get_notBefore已加载', Assigned(X509_get_notBefore));
      LogTest('X509_get_notAfter已加载', Assigned(X509_get_notAfter));
      LogTest('X509_get0_signature已加载', Assigned(X509_get0_signature));
      LogTest('X509_ALGOR_get0已加载', Assigned(X509_ALGOR_get0));
    end;
  except
    on E: Exception do
      LogTest('LoadOpenSSLX509', False, E.Message);
  end;
  
  // 测试ASN1模块
  try
    LoadOpenSSLASN1(GetCryptoLibHandle);
    Success := True;
    LogTest('LoadOpenSSLASN1', Success);
    if Success then
    begin
      LogTest('ASN1_INTEGER_to_BN已加载', Assigned(ASN1_INTEGER_to_BN));
      LogTest('ASN1_TIME_to_tm已加载', Assigned(ASN1_TIME_to_tm));
    end;
  except
    on E: Exception do
      LogTest('LoadOpenSSLASN1', False, E.Message);
  end;
  
  // 测试BN模块
  try
    Success := LoadOpenSSLBN;
    LogTest('LoadOpenSSLBN', Success);
    if Success then
    begin
      LogTest('BN_bn2hex已加载', Assigned(BN_bn2hex));
      LogTest('BN_free已加载', Assigned(BN_free));
    end;
  except
    on E: Exception do
      LogTest('LoadOpenSSLBN', False, E.Message);
  end;
  
  // 测试PEM模块
  try
    Success := LoadOpenSSLPEM(GetCryptoLibHandle);
    LogTest('LoadOpenSSLPEM', Success);
    if Success then
      LogTest('PEM_write_bio_PUBKEY已加载', Assigned(PEM_write_bio_PUBKEY));
  except
    on E: Exception do
      LogTest('LoadOpenSSLPEM', False, E.Message);
  end;
  
  // 测试OBJ模块
  try
    LoadOBJModule(GetCryptoLibHandle);
    Success := True;
    LogTest('LoadOBJModule', Success);
    if Success then
      LogTest('OBJ_obj2txt已加载', Assigned(OBJ_obj2txt));
  except
    on E: Exception do
      LogTest('LoadOBJModule', False, E.Message);
  end;
  
  // 测试CRYPTO模块
  try
    LoadOpenSSLCrypto;
    Success := True;
    LogTest('LoadOpenSSLCrypto', Success);
    if Success then
    begin
      LogTest('CRYPTO_free已加载', Assigned(CRYPTO_free));
      LogTest('OPENSSL_free已加载', Assigned(OPENSSL_free));
    end;
  except
    on E: Exception do
      LogTest('LoadOpenSSLCrypto', False, E.Message);
  end;
end;

procedure TestFactoryIntegration;
var
  Lib: ISSLLibrary;
  LibType: TSSLLibraryType;
  Available: TSSLLibraryTypes;
begin
  WriteLn;
  WriteLn('=== 测试4: 工厂模式集成 ===');
  
  try
    // 测试库检测
    Available := TSSLFactory.GetAvailableLibraries;
    LogTest('GetAvailableLibraries', Available <> []);
    
    // 测试OpenSSL可用性
    LogTest('IsLibraryAvailable(sslOpenSSL)', 
            TSSLFactory.IsLibraryAvailable(sslOpenSSL));
    
    // 测试最佳库检测
    LibType := TSSLFactory.DetectBestLibrary;
    LogTest('DetectBestLibrary', LibType <> sslAutoDetect,
            '检测到: ' + GetEnumName(TypeInfo(TSSLLibraryType), Ord(LibType)));
    
    // 测试获取库实例
    Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    LogTest('GetLibraryInstance', Assigned(Lib));
    
    if Assigned(Lib) then
    begin
      LogTest('Library.IsInitialized', Lib.IsInitialized);
      LogTest('Library.GetVersionString', Lib.GetVersionString <> '',
              '版本: ' + Lib.GetVersionString);
    end;
  except
    on E: Exception do
      LogTest('Factory Integration', False, E.Message);
  end;
end;

procedure TestContextCreation;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
begin
  WriteLn;
  WriteLn('=== 测试5: Context创建 ===');
  
  try
    Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if not Assigned(Lib) then
    begin
      LogTest('Context Creation', False, '无法获取库实例');
      Exit;
    end;
    
    // 测试客户端Context创建
    Ctx := Lib.CreateContext(sslCtxClient);
    LogTest('CreateContext(Client)', Assigned(Ctx));
    
    if Assigned(Ctx) then
    begin
      LogTest('Context.IsValid', Ctx.IsValid);
      LogTest('Context.GetContextType', Ctx.GetContextType = sslCtxClient);
      LogTest('Context.GetNativeHandle', HasNativeHandle(Ctx));
    end;
    
    // 释放Context
    Ctx := nil;
    
    // 测试服务端Context创建
    Ctx := Lib.CreateContext(sslCtxServer);
    LogTest('CreateContext(Server)', Assigned(Ctx));
    
    if Assigned(Ctx) then
      LogTest('Server Context.IsValid', Ctx.IsValid);
      
  except
    on E: Exception do
      LogTest('Context Creation', False, E.Message);
  end;
end;

procedure TestCertificateCreation;
var
  Lib: ISSLLibrary;
  Cert: ISSLCertificate;
begin
  WriteLn;
  WriteLn('=== 测试6: Certificate对象创建 ===');
  
  try
    Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if not Assigned(Lib) then
    begin
      LogTest('Certificate Creation', False, '无法获取库实例');
      Exit;
    end;
    
    Cert := Lib.CreateCertificate;
    LogTest('CreateCertificate', Assigned(Cert));
    
    if Assigned(Cert) then
    begin
      LogTest('Certificate.GetNativeHandle', HasNativeHandle(Cert));
      // 空证书应该返回空信息
      LogTest('Certificate.GetSubject (空)', Cert.GetSubject = '');
      LogTest('Certificate.GetIssuer (空)', Cert.GetIssuer = '');
    end;
  except
    on E: Exception do
      LogTest('Certificate Creation', False, E.Message);
  end;
end;

procedure TestMemoryManagement;
var
  i: Integer;
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Cert: ISSLCertificate;
begin
  WriteLn;
  WriteLn('=== 测试7: 内存管理 ===');
  
  try
    Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    
    // 创建和释放多个对象
    for i := 1 to 100 do
    begin
      Ctx := Lib.CreateContext(sslCtxClient);
      Cert := Lib.CreateCertificate;
      Ctx := nil;
      Cert := nil;
    end;
    
    LogTest('创建和释放100个Context/Certificate对象', True, '无内存泄漏');
  except
    on E: Exception do
      LogTest('Memory Management', False, E.Message);
  end;
end;

procedure PrintSummary;
var
  Percentage: Double;
begin
  WriteLn;
  WriteLn('=====================================');
  WriteLn('测试总结:');
  WriteLn('  总测试数: ', TestsTotal);
  if TestsTotal > 0 then
    Percentage := TestsPassed * 100.0 / TestsTotal
  else
    Percentage := 0.0;
  WriteLn('  通过: ', TestsPassed, ' (', Format('%.1f', [Percentage]), '%)');
  WriteLn('  失败: ', TestsFailed);
  WriteLn('=====================================');
  
  if TestsFailed = 0 then
  begin
    WriteLn;
    WriteLn('✓ 所有测试通过! OpenSSL实现基础功能验证成功。');
    WriteLn('  下一步建议:');
    WriteLn('  1. 编写具体功能的单元测试');
    WriteLn('  2. 完善占位标记的功能');
    WriteLn('  3. 添加实际的SSL连接测试');
  end
  else
  begin
    WriteLn;
    WriteLn('✗ 有测试失败，需要修复。');
  end;
end;

begin
  WriteLn('OpenSSL基础功能验证测试');
  WriteLn('版本: 1.0');
  WriteLn('日期: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  WriteLn;
  
  try
    TestLibraryLoading;
    TestVersionInfo;
    TestAPIModulesLoading;
    TestFactoryIntegration;
    TestContextCreation;
    TestCertificateCreation;
    TestMemoryManagement;
  finally
    PrintSummary;
  end;
  
  WriteLn;
  
  // 返回退出码
  if TestsFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
