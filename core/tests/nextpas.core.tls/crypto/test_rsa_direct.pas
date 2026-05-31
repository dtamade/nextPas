program test_rsa_direct;

{$mode objfpc}{$H+}

{
  直接测试RSA生成 - 最小化调试
}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.evp;

var
  LKey: PRSA;
  LExp: PBIGNUM;
  LPKey: PEVP_PKEY;
begin
  WriteLn('Testing RSA Generation Directly');
  WriteLn('================================');
  WriteLn;
  
  try
    // 加载OpenSSL
    WriteLn('[1] Loading OpenSSL Core...');
    LoadOpenSSLCore();
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      WriteLn('  ✗ Failed to load OpenS SSL');
      Halt(1);
    end;
    WriteLn('  ✓ Core loaded');
    
    // 加载RSA
    WriteLn('[2] Loading RSA module...');
    if not LoadOpenSSLRSA() then
    begin
      WriteLn('  ✗ Failed to load RSA module');
      Halt(1);
    end;
    WriteLn('  ✓ RSA module loaded');
    
    // 加载BN
    WriteLn('[3] Loading BN module...');
    if not LoadOpenSSLBN() then
    begin
      WriteLn('  ✗ Failed to load BN module');
      Halt(1);
    end;
    WriteLn('  ✓ BN module loaded');
    
    // 检查函数指针
    WriteLn('[4] Checking function pointers...');
    WriteLn('  RSA_new: ', Assigned(RSA_new));
    WriteLn('  RSA_free: ', Assigned(RSA_free));
    WriteLn('  RSA_generate_key_ex: ', Assigned(RSA_generate_key_ex));
    WriteLn('  BN_new: ', Assigned(BN_new));
    WriteLn('  BN_set_word: ', Assigned(BN_set_word));
    WriteLn('  BN_free: ', Assigned(BN_free));
    WriteLn('  EVP_PKEY_new: ', Assigned(EVP_PKEY_new));
    WriteLn('  EVP_PKEY_assign: ', Assigned(EVP_PKEY_assign));
    WriteLn;
    
    if not Assigned(RSA_new) then
    begin
      WriteLn('  ✗ RSA_new not loaded!');
      Halt(1);
    end;
    
    // 创建RSA
    WriteLn('[5] Creating RSA key...');
    LKey := RSA_new();
    if LKey = nil then
    begin
      WriteLn('  ✗ RSA_new returned nil');
      Halt(1);
    end;
    WriteLn('  ✓ RSA_new succeeded: ', PtrUInt(LKey));
    
    // 创建BIGNUM
    WriteLn('[6] Creating BIGNUM for exponent...');
    LExp := BN_new();
    if LExp = nil then
    begin
      WriteLn('  ✗ BN_new returned nil');
      RSA_free(LKey);
      Halt(1);
    end;
    WriteLn('  ✓ BN_new succeeded: ', PtrUInt(LExp));
    
    // 设置指数
    WriteLn('[7] Setting exponent to 65537...');
    BN_set_word(LExp, RSA_F4);
    WriteLn('  ✓ Exponent set');
    
    // 生成密钥
    WriteLn('[8] Generating 2048-bit RSA key...');
    if RSA_generate_key_ex(LKey, 2048, LExp, nil) <> 1 then
    begin
      WriteLn('  ✗ RSA_generate_key_ex failed');
      BN_free(LExp);
      RSA_free(LKey);
      Halt(1);
    end;
    WriteLn('  ✓ Key generation succeeded!');
    
    // 清理
    WriteLn('[9] Cleaning up...');
   BN_free(LExp);
    RSA_free(LKey);
    WriteLn('  ✓ Cleanup done');
    
    WriteLn;
    WriteLn('================================');
    WriteLn('✓ ALL TESTS PASSED!');
    WriteLn('================================');
    
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('================================');
      WriteLn('✗ EXCEPTION: ', E.ClassName, ': ',  E.Message);
      WriteLn('================================');
      Halt(1);
    end;
  end;
end.
