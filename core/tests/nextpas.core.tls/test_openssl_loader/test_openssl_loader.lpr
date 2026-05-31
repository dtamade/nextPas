program test_openssl_loader;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.tls.openssl.loader;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPass);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFail);
  end;
end;

procedure TestLoadLibCrypto;
var
  LHandle: TOpenSSLLibHandle;
begin
  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
  Check('libcrypto loaded', LHandle <> 0);
end;

procedure TestLoadLibSSL;
var
  LHandle: TOpenSSLLibHandle;
begin
  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
  Check('libssl loaded', LHandle <> 0);
end;

procedure TestVersionDetection;
var
  LInfo: TOpenSSLVersionInfo;
begin
  LInfo := TOpenSSLLoader.GetVersionInfo;
  Check('version string not empty', LInfo.VersionString <> '');
  Check('OpenSSL 3.x detected', TOpenSSLLoader.IsOpenSSL3);
  WriteLn('    Version: ', LInfo.VersionString);
end;

procedure TestCoreFunctions;
var
  LHandle: TOpenSSLLibHandle;
  LPtr: Pointer;
begin
  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
  if LHandle = 0 then Exit;

  LPtr := TOpenSSLLoader.GetFunction(LHandle, 'EVP_sha256');
  Check('EVP_sha256 found', LPtr <> nil);

  LPtr := TOpenSSLLoader.GetFunction(LHandle, 'EVP_aes_128_gcm');
  Check('EVP_aes_128_gcm found', LPtr <> nil);

  LPtr := TOpenSSLLoader.GetFunction(LHandle, 'RAND_bytes');
  Check('RAND_bytes found', LPtr <> nil);

  LPtr := TOpenSSLLoader.GetFunction(LHandle, 'EVP_MD_CTX_new');
  Check('EVP_MD_CTX_new found', LPtr <> nil);

  Check('IsFunctionAvailable(EVP_sha256)',
    TOpenSSLLoader.IsFunctionAvailable(LHandle, 'EVP_sha256'));
  Check('IsFunctionAvailable(nonexistent) = false',
    not TOpenSSLLoader.IsFunctionAvailable(LHandle, 'ThisFunctionDoesNotExist_XYZ'));
end;

procedure TestSSLFunctions;
var
  LHandle: TOpenSSLLibHandle;
  LPtr: Pointer;
begin
  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
  if LHandle = 0 then Exit;

  LPtr := TOpenSSLLoader.GetFunction(LHandle, 'SSL_CTX_new');
  Check('SSL_CTX_new found', LPtr <> nil);

  LPtr := TOpenSSLLoader.GetFunction(LHandle, 'TLS_client_method');
  Check('TLS_client_method found', LPtr <> nil);

  LPtr := TOpenSSLLoader.GetFunction(LHandle, 'SSL_new');
  Check('SSL_new found', LPtr <> nil);

  LPtr := TOpenSSLLoader.GetFunction(LHandle, 'SSL_connect');
  Check('SSL_connect found', LPtr <> nil);
end;

procedure TestUnloadReload;
begin
  Check('initially loaded', TOpenSSLLoader.IsLoaded(osslLibCrypto));
  TOpenSSLLoader.UnloadLibraries;
  Check('after unload: not loaded', not TOpenSSLLoader.IsLoaded(osslLibCrypto));

  // Reload
  Check('reload: libcrypto', TOpenSSLLoader.GetLibraryHandle(osslLibCrypto) <> 0);
  Check('reload: is loaded again', TOpenSSLLoader.IsLoaded(osslLibCrypto));
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== OpenSSL Dynamic Loader Tests ===');
  WriteLn;

  TestLoadLibCrypto;
  TestLoadLibSSL;
  TestVersionDetection;
  TestCoreFunctions;
  TestSSLFunctions;
  TestUnloadReload;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));

  TOpenSSLLoader.UnloadLibraries;

  if GFail > 0 then
    Halt(1);
end.
