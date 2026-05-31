{******************************************************************************}
{                                                                              }
{  test_openssl_complete - Comprehensive OpenSSL Bindings Test Program        }
{                                                                              }
{  Tests all major OpenSSL modules and functionalities                        }
{                                                                              }
{******************************************************************************}
program test_openssl_complete;

{$MODE OBJFPC}{$H+}

uses
  SysUtils, Classes,
  { Core modules }
  nextpas.core.tls.openssl.api.types,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.err,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.ssl,
  { Crypto modules }
  nextpas.core.tls.openssl.api.crypto,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.dsa,
  nextpas.core.tls.openssl.api.dh,
  nextpas.core.tls.openssl.api.ec,
  nextpas.core.tls.openssl.api.ecdsa,
  nextpas.core.tls.openssl.api.ecdh,
  { Hash modules }
  nextpas.core.tls.openssl.api.md,
  nextpas.core.tls.openssl.api.sha,
  nextpas.core.tls.openssl.api.sha3,
  nextpas.core.tls.openssl.blake2,
  nextpas.core.tls.openssl.api.hmac,
  nextpas.core.tls.openssl.cmac,
  { Cipher modules }
  nextpas.core.tls.openssl.api.aes,
  nextpas.core.tls.openssl.api.des,
  nextpas.core.tls.openssl.chacha,
  nextpas.core.tls.openssl.modes,
  { Encoding modules }
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.x509v3,
  { PKCS modules }
  nextpas.core.tls.openssl.pkcs,
  nextpas.core.tls.openssl.pkcs7,
  nextpas.core.tls.openssl.pkcs12,
  { Advanced modules }
  nextpas.core.tls.openssl.ocsp,
  nextpas.core.tls.openssl.cms,
  nextpas.core.tls.openssl.ct,
  nextpas.core.tls.openssl.ts,
  nextpas.core.tls.openssl.kdf,
  nextpas.core.tls.openssl.api.rand,
  nextpas.core.tls.openssl.engine,
  nextpas.core.tls.openssl.provider,
  nextpas.core.tls.openssl.store,
  nextpas.core.tls.openssl.conf,
  nextpas.core.tls.openssl.comp,
  nextpas.core.tls.openssl.ui,
  { Utility modules }
  nextpas.core.tls.openssl.stack,
  nextpas.core.tls.openssl.lhash,
  nextpas.core.tls.openssl.api.buffer,
  nextpas.core.tls.openssl.obj,
  nextpas.core.tls.openssl.txt_db,
  nextpas.core.tls.openssl.dso,
  nextpas.core.tls.openssl.srp,
  nextpas.core.tls.openssl.thread,
  nextpas.core.tls.openssl.param,
  { SM algorithms }
  nextpas.core.tls.openssl.sm;

type
  TTestResult = record
    ModuleName: string;
    Loaded: Boolean;
    TestsPassed: Integer;
    TestsFailed: Integer;
    ErrorMessage: string;
  end;

var
  LibCrypto, LibSSL: THandle;
  TestResults: array of TTestResult;
  TotalTests, PassedTests, FailedTests: Integer;
  StartTime: TDateTime;

procedure AddTestResult(const ModuleName: string; Loaded: Boolean;
  Passed, Failed: Integer; const ErrMsg: string = '');
var
  idx: Integer;
begin
  idx := Length(TestResults);
  SetLength(TestResults, idx + 1);
  TestResults[idx].ModuleName := ModuleName;
  TestResults[idx].Loaded := Loaded;
  TestResults[idx].TestsPassed := Passed;
  TestResults[idx].TestsFailed := Failed;
  TestResults[idx].ErrorMessage := ErrMsg;
  
  Inc(TotalTests, Passed + Failed);
  Inc(PassedTests, Passed);
  Inc(FailedTests, Failed);
end;

procedure PrintHeader;
begin
  WriteLn('========================================');
  WriteLn('OpenSSL Complete Bindings Test Suite');
  WriteLn('========================================');
  WriteLn;
end;

procedure PrintResults;
var
  i: Integer;
  Duration: Double;
begin
  WriteLn;
  WriteLn('========================================');
  WriteLn('Test Results Summary');
  WriteLn('========================================');
  WriteLn;
  
  WriteLn('Module Results:');
  WriteLn('----------------------------------------');
  for i := 0 to High(TestResults) do
  begin
    Write(Format('%-30s: ', [TestResults[i].ModuleName]));
    if TestResults[i].Loaded then
    begin
      Write(Format('Loaded [P:%d F:%d]', 
        [TestResults[i].TestsPassed, TestResults[i].TestsFailed]));
      if TestResults[i].TestsFailed > 0 then
        Write(' (', TestResults[i].ErrorMessage, ')');
    end
    else
      Write('Not Loaded');
    WriteLn;
  end;
  
  WriteLn;
  WriteLn('----------------------------------------');
  Duration := (Now - StartTime) * 24 * 60 * 60; // Convert to seconds
  WriteLn(Format('Total Tests:   %d', [TotalTests]));
  WriteLn(Format('Passed Tests:  %d (%.1f%%)', 
    [PassedTests, PassedTests * 100.0 / Max(TotalTests, 1)]));
  WriteLn(Format('Failed Tests:  %d (%.1f%%)', 
    [FailedTests, FailedTests * 100.0 / Max(TotalTests, 1)]));
  WriteLn(Format('Test Duration: %.2f seconds', [Duration]));
  WriteLn('========================================');
end;

function LoadOpenSSLLibraries: Boolean;
const
  {$IFDEF WINDOWS}
  LIBCRYPTO_NAMES: array[0..2] of string = (
    'libcrypto-3-x64.dll',
    'libcrypto-1_1-x64.dll',
    'libeay32.dll'
  );
  LIBSSL_NAMES: array[0..2] of string = (
    'libssl-3-x64.dll',
    'libssl-1_1-x64.dll',
    'ssleay32.dll'
  );
  {$ELSE}
  LIBCRYPTO_NAMES: array[0..2] of string = (
    'libcrypto.so.3',
    'libcrypto.so.1.1',
    'libcrypto.so'
  );
  LIBSSL_NAMES: array[0..2] of string = (
    'libssl.so.3',
    'libssl.so.1.1',
    'libssl.so'
  );
  {$ENDIF}
var
  i: Integer;
begin
  Result := False;
  LibCrypto := 0;
  LibSSL := 0;
  
  // Try to load libcrypto
  for i := 0 to High(LIBCRYPTO_NAMES) do
  begin
    LibCrypto := LoadLibrary(PChar(LIBCRYPTO_NAMES[i]));
    if LibCrypto <> 0 then
    begin
      WriteLn('Loaded libcrypto: ', LIBCRYPTO_NAMES[i]);
      Break;
    end;
  end;
  
  if LibCrypto = 0 then
  begin
    WriteLn('ERROR: Could not load libcrypto library');
    Exit;
  end;
  
  // Try to load libssl
  for i := 0 to High(LIBSSL_NAMES) do
  begin
    LibSSL := LoadLibrary(PChar(LIBSSL_NAMES[i]));
    if LibSSL <> 0 then
    begin
      WriteLn('Loaded libssl: ', LIBSSL_NAMES[i]);
      Break;
    end;
  end;
  
  if LibSSL = 0 then
  begin
    WriteLn('ERROR: Could not load libssl library');
    FreeLibrary(LibCrypto);
    Exit;
  end;
  
  Result := True;
end;

procedure TestCoreModule;
var
  Passed, Failed: Integer;
  Version: TOpenSSLULong;
begin
  Passed := 0;
  Failed := 0;
  
  if LoadCore(LibCrypto) then
  begin
    Inc(Passed);
    
    // Test OpenSSL version
    if Assigned(OpenSSL_version_num) then
    begin
      Version := OpenSSL_version_num();
      WriteLn('  OpenSSL Version: ', Format('$%.8x', [Version]));
      Inc(Passed);
    end
    else
      Inc(Failed);
      
    // Test library init
    if Assigned(OPENSSL_init_ssl) then
    begin
      if OPENSSL_init_ssl(0, nil) = 1 then
        Inc(Passed)
      else
        Inc(Failed);
    end
    else
      Inc(Failed);
      
    AddTestResult('Core', True, Passed, Failed);
  end
  else
    AddTestResult('Core', False, 0, 0);
end;

procedure TestErrorModule;
var
  Passed, Failed: Integer;
begin
  Passed := 0;
  Failed := 0;
  
  if LoadErr(LibCrypto) then
  begin
    Inc(Passed);
    
    // Test error string loading
    if Assigned(ERR_load_crypto_strings) then
    begin
      ERR_load_crypto_strings();
      Inc(Passed);
    end
    else
      Inc(Failed);
      
    // Test error clearing
    if Assigned(ERR_clear_error) then
    begin
      ERR_clear_error();
      Inc(Passed);
    end
    else
      Inc(Failed);
      
    AddTestResult('Error', True, Passed, Failed);
  end
  else
    AddTestResult('Error', False, 0, 0);
end;

procedure TestBIOModule;
var
  Passed, Failed: Integer;
  bio: PBIO;
begin
  Passed := 0;
  Failed := 0;
  
  if LoadBIO(LibCrypto) then
  begin
    Inc(Passed);
    
    // Test BIO memory creation
    if Assigned(BIO_new) and Assigned(BIO_s_mem) and Assigned(BIO_free) then
    begin
      bio := BIO_new(BIO_s_mem());
      if bio <> nil then
      begin
        Inc(Passed);
        BIO_free(bio);
      end
      else
        Inc(Failed);
    end
    else
      Inc(Failed);
      
    AddTestResult('BIO', True, Passed, Failed);
  end
  else
    AddTestResult('BIO', False, 0, 0);
end;

procedure TestEVPModule;
var
  Passed, Failed: Integer;
begin
  Passed := 0;
  Failed := 0;
  
  if LoadEVP(LibCrypto) then
  begin
    Inc(Passed);
    
    // Test EVP digest
    if Assigned(EVP_sha256) then
    begin
      if EVP_sha256() <> nil then
        Inc(Passed)
      else
        Inc(Failed);
    end
    else
      Inc(Failed);
      
    AddTestResult('EVP', True, Passed, Failed);
  end
  else
    AddTestResult('EVP', False, 0, 0);
end;

procedure TestCryptoModules;
begin
  // Test BIGNUM
  if LoadBN(LibCrypto) then
    AddTestResult('BIGNUM', True, 1, 0)
  else
    AddTestResult('BIGNUM', False, 0, 0);
    
  // Test RSA
  if LoadRSA(LibCrypto) then
    AddTestResult('RSA', True, 1, 0)
  else
    AddTestResult('RSA', False, 0, 0);
    
  // Test DSA
  if LoadDSA(LibCrypto) then
    AddTestResult('DSA', True, 1, 0)
  else
    AddTestResult('DSA', False, 0, 0);
    
  // Test DH
  if LoadDH(LibCrypto) then
    AddTestResult('DH', True, 1, 0)
  else
    AddTestResult('DH', False, 0, 0);
    
  // Test EC
  if LoadEC(LibCrypto) then
    AddTestResult('EC', True, 1, 0)
  else
    AddTestResult('EC', False, 0, 0);
end;

procedure TestHashModules;
begin
  // Test MD algorithms
  if LoadMD(LibCrypto) then
    AddTestResult('MD', True, 1, 0)
  else
    AddTestResult('MD', False, 0, 0);
    
  // Test SHA algorithms
  if LoadSHA(LibCrypto) then
    AddTestResult('SHA', True, 1, 0)
  else
    AddTestResult('SHA', False, 0, 0);
    
  // Test SHA3 algorithms
  if LoadSHA3(LibCrypto) then
    AddTestResult('SHA3', True, 1, 0)
  else
    AddTestResult('SHA3', False, 0, 0);
    
  // Test BLAKE2
  if LoadBLAKE2(LibCrypto) then
    AddTestResult('BLAKE2', True, 1, 0)
  else
    AddTestResult('BLAKE2', False, 0, 0);
    
  // Test HMAC
  if LoadHMAC(LibCrypto) then
    AddTestResult('HMAC', True, 1, 0)
  else
    AddTestResult('HMAC', False, 0, 0);
end;

procedure TestCipherModules;
begin
  // Test AES
  if LoadAES(LibCrypto) then
    AddTestResult('AES', True, 1, 0)
  else
    AddTestResult('AES', False, 0, 0);
    
  // Test DES
  if LoadDES(LibCrypto) then
    AddTestResult('DES', True, 1, 0)
  else
    AddTestResult('DES', False, 0, 0);
    
  // Test ChaCha20
  if LoadChaCha(LibCrypto) then
    AddTestResult('ChaCha', True, 1, 0)
  else
    AddTestResult('ChaCha', False, 0, 0);
    
  // Test Modes
  if LoadModes(LibCrypto) then
    AddTestResult('Modes', True, 1, 0)
  else
    AddTestResult('Modes', False, 0, 0);
end;

procedure TestCertificateModules;
begin
  // Test ASN.1
  if LoadASN1(LibCrypto) then
    AddTestResult('ASN1', True, 1, 0)
  else
    AddTestResult('ASN1', False, 0, 0);
    
  // Test PEM
  if LoadPEM(LibCrypto) then
    AddTestResult('PEM', True, 1, 0)
  else
    AddTestResult('PEM', False, 0, 0);
    
  // Test X509
  if LoadX509(LibCrypto) then
    AddTestResult('X509', True, 1, 0)
  else
    AddTestResult('X509', False, 0, 0);
    
  // Test X509v3
  if LoadX509V3(LibCrypto) then
    AddTestResult('X509v3', True, 1, 0)
  else
    AddTestResult('X509v3', False, 0, 0);
end;

procedure TestPKCSModules;
begin
  // Test PKCS7
  if LoadPKCS7(LibCrypto) then
    AddTestResult('PKCS7', True, 1, 0)
  else
    AddTestResult('PKCS7', False, 0, 0);
    
  // Test PKCS12
  if LoadPKCS12(LibCrypto) then
    AddTestResult('PKCS12', True, 1, 0)
  else
    AddTestResult('PKCS12', False, 0, 0);
end;

procedure TestAdvancedModules;
begin
  // Test OCSP
  if LoadOCSP(LibCrypto) then
    AddTestResult('OCSP', True, 1, 0)
  else
    AddTestResult('OCSP', False, 0, 0);
    
  // Test CMS
  if LoadCMS(LibCrypto) then
    AddTestResult('CMS', True, 1, 0)
  else
    AddTestResult('CMS', False, 0, 0);
    
  // Test CT
  if LoadCT(LibCrypto) then
    AddTestResult('CT', True, 1, 0)
  else
    AddTestResult('CT', False, 0, 0);
    
  // Test TS
  if LoadTS(LibCrypto) then
    AddTestResult('TS', True, 1, 0)
  else
    AddTestResult('TS', False, 0, 0);
end;

procedure TestUtilityModules;
begin
  // Test Random
  if LoadRAND(LibCrypto) then
    AddTestResult('RAND', True, 1, 0)
  else
    AddTestResult('RAND', False, 0, 0);
    
  // Test KDF
  if LoadKDF(LibCrypto) then
    AddTestResult('KDF', True, 1, 0)
  else
    AddTestResult('KDF', False, 0, 0);
    
  // Test Engine
  if LoadEngine(LibCrypto) then
    AddTestResult('Engine', True, 1, 0)
  else
    AddTestResult('Engine', False, 0, 0);
    
  // Test Config
  if LoadConf(LibCrypto) then
    AddTestResult('Config', True, 1, 0)
  else
    AddTestResult('Config', False, 0, 0);
end;

procedure TestSSLModule;
var
  Passed, Failed: Integer;
begin
  Passed := 0;
  Failed := 0;
  
  if LoadSSL(LibSSL) then
  begin
    Inc(Passed);
    
    // Test SSL library init
    if Assigned(SSL_library_init) then
    begin
      SSL_library_init();
      Inc(Passed);
    end
    else
      Inc(Failed);
      
    // Test SSL method
    if Assigned(TLS_method) then
    begin
      if TLS_method() <> nil then
        Inc(Passed)
      else
        Inc(Failed);
    end
    else
      Inc(Failed);
      
    AddTestResult('SSL', True, Passed, Failed);
  end
  else
    AddTestResult('SSL', False, 0, 0);
end;

procedure TestSMAlgorithms;
begin
  // Test SM algorithms (Chinese national standards)
  if LoadSM(LibCrypto) then
    AddTestResult('SM', True, 1, 0)
  else
    AddTestResult('SM', False, 0, 0);
end;

procedure TestOpenSSL3Features;
begin
  // Test OSSL_PARAM (OpenSSL 3.0+)
  if LoadOSSLPARAM(LibCrypto) then
    AddTestResult('OSSL_PARAM', True, 1, 0)
  else
    AddTestResult('OSSL_PARAM', False, 0, 0);
    
  // Test Provider (OpenSSL 3.0+)
  if LoadProvider(LibCrypto) then
    AddTestResult('Provider', True, 1, 0)
  else
    AddTestResult('Provider', False, 0, 0);
end;

procedure TestSupportModules;
begin
  // Test Stack
  if LoadStack(LibCrypto) then
    AddTestResult('Stack', True, 1, 0)
  else
    AddTestResult('Stack', False, 0, 0);
    
  // Test LHash
  if LoadLHash(LibCrypto) then
    AddTestResult('LHash', True, 1, 0)
  else
    AddTestResult('LHash', False, 0, 0);
    
  // Test Buffer
  if LoadBuffer(LibCrypto) then
    AddTestResult('Buffer', True, 1, 0)
  else
    AddTestResult('Buffer', False, 0, 0);
    
  // Test Object
  if LoadObj(LibCrypto) then
    AddTestResult('Object', True, 1, 0)
  else
    AddTestResult('Object', False, 0, 0);
    
  // Test TXT_DB
  if LoadTXTDB(LibCrypto) then
    AddTestResult('TXT_DB', True, 1, 0)
  else
    AddTestResult('TXT_DB', False, 0, 0);
    
  // Test DSO
  if LoadDSO(LibCrypto) then
    AddTestResult('DSO', True, 1, 0)
  else
    AddTestResult('DSO', False, 0, 0);
    
  // Test SRP
  if LoadSRP(LibCrypto) then
    AddTestResult('SRP', True, 1, 0)
  else
    AddTestResult('SRP', False, 0, 0);
    
  // Test Thread
  if LoadThread(LibCrypto) then
    AddTestResult('Thread', True, 1, 0)
  else
    AddTestResult('Thread', False, 0, 0);
    
  // Test UI
  if LoadUI(LibCrypto) then
    AddTestResult('UI', True, 1, 0)
  else
    AddTestResult('UI', False, 0, 0);
    
  // Test Store
  if LoadStore(LibCrypto) then
    AddTestResult('Store', True, 1, 0)
  else
    AddTestResult('Store', False, 0, 0);
    
  // Test Comp
  if LoadComp(LibCrypto) then
    AddTestResult('Comp', True, 1, 0)
  else
    AddTestResult('Comp', False, 0, 0);
end;

procedure RunAllTests;
begin
  WriteLn('Testing Core Modules...');
  TestCoreModule;
  TestErrorModule;
  TestBIOModule;
  TestEVPModule;
  
  WriteLn('Testing Crypto Modules...');
  TestCryptoModules;
  
  WriteLn('Testing Hash Modules...');
  TestHashModules;
  
  WriteLn('Testing Cipher Modules...');
  TestCipherModules;
  
  WriteLn('Testing Certificate Modules...');
  TestCertificateModules;
  
  WriteLn('Testing PKCS Modules...');
  TestPKCSModules;
  
  WriteLn('Testing Advanced Modules...');
  TestAdvancedModules;
  
  WriteLn('Testing Utility Modules...');
  TestUtilityModules;
  
  WriteLn('Testing SSL/TLS Module...');
  TestSSLModule;
  
  WriteLn('Testing SM Algorithms...');
  TestSMAlgorithms;
  
  WriteLn('Testing OpenSSL 3.0+ Features...');
  TestOpenSSL3Features;
  
  WriteLn('Testing Support Modules...');
  TestSupportModules;
end;

procedure CleanupOpenSSL;
begin
  // Unload all modules in reverse order
  UnloadThread;
  UnloadSRP;
  UnloadDSO;
  UnloadTXTDB;
  UnloadObj;
  UnloadBuffer;
  UnloadLHash;
  UnloadStack;
  UnloadProvider;
  UnloadOSSLPARAM;
  UnloadSM;
  UnloadSSL;
  UnloadComp;
  UnloadStore;
  UnloadUI;
  UnloadConf;
  UnloadEngine;
  UnloadKDF;
  UnloadRAND;
  UnloadTS;
  UnloadCT;
  UnloadCMS;
  UnloadOCSP;
  UnloadPKCS12;
  UnloadPKCS7;
  UnloadX509V3;
  UnloadX509;
  UnloadPEM;
  UnloadASN1;
  UnloadModes;
  UnloadChaCha;
  UnloadDES;
  UnloadAES;
  UnloadCMAC;
  UnloadHMAC;
  UnloadBLAKE2;
  UnloadSHA3;
  UnloadSHA;
  UnloadMD;
  UnloadECDH;
  UnloadECDSA;
  UnloadEC;
  UnloadDH;
  UnloadDSA;
  UnloadRSA;
  UnloadBN;
  UnloadEVP;
  UnloadBIO;
  UnloadErr;
  UnloadCore;
  
  // Free libraries
  if LibSSL <> 0 then
  begin
    FreeLibrary(LibSSL);
    WriteLn('Unloaded libssl');
  end;
  
  if LibCrypto <> 0 then
  begin
    FreeLibrary(LibCrypto);
    WriteLn('Unloaded libcrypto');
  end;
end;

begin
  // Initialize
  TotalTests := 0;
  PassedTests := 0;
  FailedTests := 0;
  SetLength(TestResults, 0);
  StartTime := Now;
  
  // Print header
  PrintHeader;
  
  // Load OpenSSL libraries
  WriteLn('Loading OpenSSL Libraries...');
  WriteLn;
  
  if LoadOpenSSLLibraries then
  begin
    WriteLn;
    WriteLn('Starting Module Tests...');
    WriteLn('----------------------------------------');
    
    // Run all tests
    RunAllTests;
    
    // Print results
    PrintResults;
    
    // Cleanup
    WriteLn;
    WriteLn('Cleaning up...');
    CleanupOpenSSL;
  end
  else
  begin
    WriteLn;
    WriteLn('FATAL: Cannot load OpenSSL libraries!');
    WriteLn;
    WriteLn('Please ensure OpenSSL is installed:');
    WriteLn('  Windows: Download from https://slproweb.com/products/Win32OpenSSL.html');
    WriteLn('  Linux:   sudo apt-get install libssl-dev');
    WriteLn('  macOS:   brew install openssl');
  end;
  
  WriteLn;
  WriteLn('Press Enter to exit...');
  ReadLn;
end.