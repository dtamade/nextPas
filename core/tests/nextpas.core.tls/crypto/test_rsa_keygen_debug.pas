program test_rsa_keygen_debug;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.bn;

var
  RSA: PRSA;
  BN: PBIGNUM;
  PKey: PEVP_PKEY;

begin
  WriteLn('Testing RSA Key Generation Step by Step');
  WriteLn('========================================');
  WriteLn;
  
  // Load modules
  WriteLn('1. Loading OpenSSL core...');
  LoadOpenSSLCore();
  WriteLn('   Done. Version: ', GetOpenSSLVersionString);
  
  WriteLn('2. Loading EVP module...');
  LoadEVP(GetCryptoLibHandle);
  WriteLn('   Done.');
  
  WriteLn('3. Loading RSA module...');
  LoadOpenSSLRSA();
  WriteLn('   Done.');
  
  WriteLn('4. Loading BN module...');
  LoadOpenSSLBN();
  WriteLn('   Done.');
  WriteLn;
  
  // Test EVP_PKEY_new
  WriteLn('5. Testing EVP_PKEY_new...');
  WriteLn('   Function assigned: ', Assigned(EVP_PKEY_new));
  PKey := EVP_PKEY_new();
  WriteLn('   Result: ', PKey <> nil);
  if PKey = nil then
  begin
    WriteLn('   FAILED: EVP_PKEY_new returned nil');
    Halt(1);
  end;
  WriteLn('   SUCCESS');
  WriteLn;
  
  // Test RSA_new
  WriteLn('6. Testing RSA_new...');
  WriteLn('   Function assigned: ', Assigned(RSA_new));
  RSA := RSA_new();
  WriteLn('   Result: ', RSA <> nil);
  if RSA = nil then
  begin
    WriteLn('   FAILED: RSA_new returned nil');
    EVP_PKEY_free(PKey);
    Halt(1);
  end;
  WriteLn('   SUCCESS');
  WriteLn;
  
  // Test BN_new
  WriteLn('7. Testing BN_new...');
  WriteLn('   Function assigned: ', Assigned(BN_new));
  BN := BN_new();
  WriteLn('   Result: ', BN <> nil);
  if BN = nil then
  begin
    WriteLn('   FAILED: BN_new returned nil');
    RSA_free(RSA);
    EVP_PKEY_free(PKey);
    Halt(1);
  end;
  WriteLn('   SUCCESS');
  WriteLn;
  
  // Test BN_set_word
  WriteLn('8. Testing BN_set_word with RSA_F4 (65537)...');
  WriteLn('   Function assigned: ', Assigned(BN_set_word));
  WriteLn('   RSA_F4 value: ', RSA_F4);
  BN_set_word(BN, RSA_F4);
  WriteLn('   SUCCESS');
  WriteLn;
  
  // Test RSA_generate_key_ex
  WriteLn('9. Testing RSA_generate_key_ex (512-bit for speed)...');
  WriteLn('   Function assigned: ', Assigned(RSA_generate_key_ex));
  WriteLn('   Generating key... (this may take a few seconds)');
  
  if RSA_generate_key_ex(RSA, 512, BN, nil) = 1 then
  begin
    WriteLn('   SUCCESS: Key generated');
  end
  else
  begin
    WriteLn('   FAILED: RSA_generate_key_ex returned error');
    BN_free(BN);
    RSA_free(RSA);
    EVP_PKEY_free(PKey);
    Halt(1);
  end;
  WriteLn;
  
  BN_free(BN);
  
  // Test EVP_PKEY_assign
  WriteLn('10. Testing EVP_PKEY_assign...');
  WriteLn('    Function assigned: ', Assigned(EVP_PKEY_assign));
  WriteLn('    EVP_PKEY_RSA value: ', EVP_PKEY_RSA);
  
  if EVP_PKEY_assign(PKey, EVP_PKEY_RSA, RSA) = 1 then
  begin
    WriteLn('    SUCCESS: RSA key assigned to EVP_PKEY');
  end
  else
  begin
    WriteLn('    FAILED: EVP_PKEY_assign returned error');
    RSA_free(RSA);
    EVP_PKEY_free(PKey);
    Halt(1);
  end;
  WriteLn;
  
  // Cleanup
  WriteLn('11. Cleaning up...');
  EVP_PKEY_free(PKey);
  WriteLn('    Done.');
  WriteLn;
  
  WriteLn('========================================');
  WriteLn('ALL TESTS PASSED!');
  WriteLn('RSA key generation is working correctly.');
  WriteLn('========================================');
end.
