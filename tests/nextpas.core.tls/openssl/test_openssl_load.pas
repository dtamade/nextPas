program test_openssl_load;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}

uses
  SysUtils, Classes, Windows,
  // OpenSSL 类型和常量
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts,
  // 核心模块
  nextpas.core.tls.openssl.api.err,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.x509,
  // 加密算法模块
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.dsa,
  nextpas.core.tls.openssl.api.dh,
  nextpas.core.tls.openssl.api.ec,
  nextpas.core.tls.openssl.api.ecdsa,
  nextpas.core.tls.openssl.api.ecdh,
  // 哈希算法模块
  nextpas.core.tls.openssl.api.sha,
  nextpas.core.tls.openssl.api.sha3,
  nextpas.core.tls.openssl.api.md,
  nextpas.core.tls.openssl.blake2,
  nextpas.core.tls.openssl.api.hmac,
  // 对称加密模块
  nextpas.core.tls.openssl.api.aes,
  nextpas.core.tls.openssl.api.des,
  nextpas.core.tls.openssl.api.chacha,
  // 证书和编码模块
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.pkcs7,
  nextpas.core.tls.openssl.api.pkcs12,
  nextpas.core.tls.openssl.api.x509v3,
  // 辅助模块
  nextpas.core.tls.openssl.api.rand,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.obj,
  nextpas.core.tls.openssl.api.buffer,
  nextpas.core.tls.openssl.api.stack,
  nextpas.core.tls.openssl.api.lhash,
  // 扩展模块
  nextpas.core.tls.openssl.api.cms,
  nextpas.core.tls.openssl.api.ts,
  nextpas.core.tls.openssl.api.ct,
  nextpas.core.tls.openssl.api.ocsp,
  nextpas.core.tls.openssl.api.kdf,
  nextpas.core.tls.openssl.api.store,
  nextpas.core.tls.openssl.api.provider,
  nextpas.core.tls.openssl.api.conf,
  nextpas.core.tls.openssl.api.ui,
  nextpas.core.tls.openssl.api.engine,
  nextpas.core.tls.openssl.api.comp,
  nextpas.core.tls.openssl.api.modes,
  nextpas.core.tls.openssl.api.cmac.evp,  // Phase 2.2: 使用EVP API替代废弃的cmac.pas
  // 国密算法
  nextpas.core.tls.openssl.api.sm;

type
  TModuleTest = record
    Name: string;
    LoadProc: procedure(ALib: THandle);
    UnloadProc: procedure;
    TestFunc: Pointer;
  end;

var
  LibSSL, LibCrypto: THandle;
  Modules: array of TModuleTest;
  SuccessCount, FailCount: Integer;

procedure AddModule(const AName: string; ALoadProc: procedure(ALib: THandle); 
  AUnloadProc: procedure; ATestFunc: Pointer = nil);
var
  Len: Integer;
begin
  Len := Length(Modules);
  SetLength(Modules, Len + 1);
  with Modules[Len] do
  begin
    Name := AName;
    LoadProc := ALoadProc;
    UnloadProc := AUnloadProc;
    TestFunc := ATestFunc;
  end;
end;

procedure InitializeModules;
begin
  // 核心模块
  AddModule('ERR (错误处理)', @LoadErrModule, @UnloadErrModule, @ERR_get_error);
  AddModule('BIO (I/O抽象)', @LoadBIOModule, @UnloadBIOModule, @BIO_new);
  AddModule('SSL/TLS', @LoadSSLModule, @UnloadSSLModule, @SSL_new);
  AddModule('EVP (加密接口)', @LoadEVPModule, @UnloadEVPModule, @EVP_MD_CTX_new);
  AddModule('X509 (证书)', @LoadX509Module, @UnloadX509Module, @X509_new);
  
  // 公钥算法
  AddModule('RSA', @LoadRSAModule, @UnloadRSAModule, @RSA_new);
  AddModule('DSA', @LoadDSAModule, @UnloadDSAModule, @DSA_new);
  AddModule('DH (Diffie-Hellman)', @LoadDHModule, @UnloadDHModule, @DH_new);
  AddModule('EC (椭圆曲线)', @LoadECModule, @UnloadECModule, @EC_KEY_new);
  AddModule('ECDSA', @LoadECDSAModule, @UnloadECDSAModule, @ECDSA_sign);
  AddModule('ECDH', @LoadECDHModule, @UnloadECDHModule, nil);
  
  // 哈希算法
  AddModule('SHA', @LoadSHAModule, @UnloadSHAModule, @SHA1);
  AddModule('SHA3', @LoadSHA3Module, @UnloadSHA3Module, @SHA3_256);
  AddModule('MD (MD5/MD4)', @LoadMDModule, @UnloadMDModule, @MD5);
  AddModule('BLAKE2', @LoadBLAKE2Module, @UnloadBLAKE2Module, @BLAKE2b256);
  AddModule('HMAC', @LoadHMACModule, @UnloadHMACModule, @HMAC);
  
  // 对称加密
  AddModule('AES', @LoadAESModule, @UnloadAESModule, @AES_encrypt);
  AddModule('DES', @LoadDESModule, @UnloadDESModule, @DES_ecb_encrypt);
  AddModule('ChaCha20-Poly1305', @LoadChaChaModule, @UnloadChaChaModule, @ChaCha20_Encrypt);
  
  // 证书格式
  AddModule('PEM', @LoadPEMModule, @UnloadPEMModule, @PEM_read_bio_X509);
  AddModule('ASN.1', @LoadASN1Module, @UnloadASN1Module, @ASN1_STRING_new);
  AddModule('PKCS7', @LoadPKCS7Module, @UnloadPKCS7Module, @PKCS7_new);
  AddModule('PKCS12', @LoadPKCS12Module, @UnloadPKCS12Module, @PKCS12_new);
  AddModule('X509v3 (扩展)', @LoadX509V3Module, @UnloadX509V3Module, @X509V3_EXT_conf);
  
  // 辅助功能
  AddModule('RAND (随机数)', @LoadRandModule, @UnloadRandModule, @RAND_bytes);
  AddModule('BN (大数)', @LoadBNModule, @UnloadBNModule, @BN_new);
  AddModule('OBJ (对象标识符)', @LoadOBJModule, @UnloadOBJModule, @OBJ_nid2obj);
  AddModule('BUFFER', @LoadBufferModule, @UnloadBufferModule, @BUF_MEM_new);
  AddModule('STACK', @LoadStackModule, @UnloadStackModule, @OPENSSL_sk_new);
  AddModule('LHASH', @LoadLHashModule, @UnloadLHashModule, @OPENSSL_LH_new);
  
  // 高级功能
  AddModule('CMS (加密消息)', @LoadCMSModule, @UnloadCMSModule, @CMS_ContentInfo_new);
  AddModule('TS (时间戳)', @LoadTSModule, @UnloadTSModule, @TS_REQ_new);
  AddModule('CT (证书透明)', @LoadCTModule, @UnloadCTModule, @SCT_new);
  AddModule('OCSP', @LoadOCSPModule, @UnloadOCSPModule, @OCSP_REQUEST_new);
  AddModule('KDF (密钥派生)', @LoadKDFModule, @UnloadKDFModule, @PBKDF2);
  AddModule('STORE', @LoadStoreModule, @UnloadStoreModule, @OSSL_STORE_open);
  AddModule('PROVIDER (3.0+)', @LoadProviderModule, @UnloadProviderModule, @OSSL_PROVIDER_load);
  AddModule('CONF (配置)', @LoadCONFModule, @UnloadCONFModule, @NCONF_new);
  AddModule('UI (用户接口)', @LoadUIModule, @UnloadUIModule, @UI_new);
  AddModule('ENGINE', @LoadEngineModule, @UnloadEngineModule, @ENGINE_new);
  AddModule('COMP (压缩)', @LoadCompModule, @UnloadCompModule, @COMP_CTX_new);
  AddModule('MODES (加密模式)', @LoadModesModule, @UnloadModesModule, @CRYPTO_gcm128_new);
  AddModule('CMAC', @LoadCMACModule, @UnloadCMACModule, @CMAC_CTX_new);
  AddModule('SM (国密)', @LoadSMModule, @UnloadSMModule, @SM3);
end;

procedure TestModule(const Module: TModuleTest);
begin
  Write(Format('  %-30s: ', [Module.Name]));
  
  try
    // 加载模块
    Module.LoadProc(LibCrypto);
    
    // 检查关键函数是否加载成功
    if Assigned(Module.TestFunc) and not Assigned(Module.TestFunc^) then
    begin
      WriteLn('[失败] - 函数未加载');
      Inc(FailCount);
      Exit;
    end;
    
    WriteLn('[成功]');
    Inc(SuccessCount);
  except
    on E: Exception do
    begin
      WriteLn('[失败] - ', E.Message);
      Inc(FailCount);
    end;
  end;
end;

procedure LoadOpenSSLLibraries;
const
  LIBSSL_NAME = 'libssl-1_1-x64.dll';
  LIBCRYPTO_NAME = 'libcrypto-1_1-x64.dll';
  LIBSSL_NAME_3 = 'libssl-3-x64.dll';
  LIBCRYPTO_NAME_3 = 'libcrypto-3-x64.dll';
begin
  // 尝试加载 OpenSSL 3.0
  LibSSL := LoadLibrary(LIBSSL_NAME_3);
  LibCrypto := LoadLibrary(LIBCRYPTO_NAME_3);
  
  // 如果失败，尝试加载 OpenSSL 1.1
  if (LibSSL = 0) or (LibCrypto = 0) then
  begin
    if LibSSL <> 0 then FreeLibrary(LibSSL);
    if LibCrypto <> 0 then FreeLibrary(LibCrypto);
    
    LibSSL := LoadLibrary(LIBSSL_NAME);
    LibCrypto := LoadLibrary(LIBCRYPTO_NAME);
  end;
  
  if (LibSSL = 0) or (LibCrypto = 0) then
  begin
    WriteLn('错误: 无法加载 OpenSSL 库');
    WriteLn('请确保 OpenSSL DLL 文件在系统路径中');
    Halt(1);
  end;
end;

procedure PrintTestResults;
var
  Total: Integer;
  SuccessRate: Double;
begin
  Total := SuccessCount + FailCount;
  if Total > 0 then
    SuccessRate := (SuccessCount / Total) * 100
  else
    SuccessRate := 0;
    
  WriteLn;
  WriteLn('========================================');
  WriteLn('           测试结果汇总');
  WriteLn('========================================');
  WriteLn(Format('  总模块数: %d', [Total]));
  WriteLn(Format('  成功加载: %d', [SuccessCount]));
  WriteLn(Format('  加载失败: %d', [FailCount]));
  WriteLn(Format('  成功率:   %.1f%%', [SuccessRate]));
  WriteLn('========================================');
  
  if FailCount > 0 then
    WriteLn('注意: 某些模块可能需要特定版本的 OpenSSL');
end;

procedure GetOpenSSLVersion;
var
  Version: LongWord;
  VersionStr: PAnsiChar;
begin
  if Assigned(OpenSSL_version_num) then
  begin
    Version := OpenSSL_version_num();
    WriteLn(Format('OpenSSL 版本号: 0x%x', [Version]));
  end;
  
  if Assigned(OpenSSL_version) then
  begin
    VersionStr := OpenSSL_version(OPENSSL_VERSION);
    if Assigned(VersionStr) then
      WriteLn('OpenSSL 版本: ', string(VersionStr));
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('     OpenSSL Pascal 绑定模块加载测试');
  WriteLn('========================================');
  WriteLn;
  
  SuccessCount := 0;
  FailCount := 0;
  
  // 加载 OpenSSL 库
  WriteLn('1. 加载 OpenSSL 动态库...');
  LoadOpenSSLLibraries;
  WriteLn('   OpenSSL 库加载成功');
  WriteLn;
  
  // 初始化模块列表
  InitializeModules;
  
  // 加载版本信息模块
  WriteLn('2. 获取 OpenSSL 版本信息...');
  LoadErrModule(LibCrypto);  // ERR 模块包含版本函数
  GetOpenSSLVersion;
  WriteLn;
  
  // 测试所有模块
  WriteLn('3. 测试模块加载...');
  WriteLn('----------------------------------------');
  
  for var Module in Modules do
    TestModule(Module);
  
  // 打印测试结果
  PrintTestResults;
  
  // 清理
  WriteLn;
  WriteLn('4. 清理资源...');
  for var Module in Modules do
    Module.UnloadProc;
  
  if LibSSL <> 0 then FreeLibrary(LibSSL);
  if LibCrypto <> 0 then FreeLibrary(LibCrypto);
  
  WriteLn('   清理完成');
  WriteLn;
  WriteLn('测试结束. 按 Enter 退出...');
  ReadLn;
end.