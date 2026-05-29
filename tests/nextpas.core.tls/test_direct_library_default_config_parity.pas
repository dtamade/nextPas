program test_direct_library_default_config_parity;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally covers the direct-library
  default-config projection of the remaining option-bridge booleans so the
  compatibility default surface stays explicit. }

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  PASS: ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

procedure TestHeader(const AName: string);
begin
  WriteLn;
  WriteLn('=== ', AName, ' ===');
end;

function CreateInitializedFreePascalLibrary: ISSLLibrary;
begin
  Result := CreateFreePascalSSLLibrary;
  if Result = nil then
    raise Exception.Create('CreateFreePascalSSLLibrary returned nil');

  if not Result.Initialize then
    raise Exception.Create('FreePascal library failed to initialize for direct-library default-config parity test');
end;

procedure Test_ClientContextReflectsLibraryDefaultConfig;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  Ctx: ISSLContext;
begin
  TestHeader('FreePascal direct-library client context reflects default config');

  Lib := CreateInitializedFreePascalLibrary;
  try
    OriginalConfig := Lib.GetDefaultConfig;
    DefaultConfig := OriginalConfig;
    DefaultConfig.ProtocolVersions := [sslProtocolTLS13];
    DefaultConfig.PreferredVersion := sslProtocolTLS13;
    DefaultConfig.VerifyMode := [sslVerifyPeer, sslVerifyFailIfNoPeerCert];
    DefaultConfig.VerifyDepth := 2;
    DefaultConfig.CipherList := SSL_DEFAULT_CIPHER_LIST;
    DefaultConfig.CipherSuites := SSL_DEFAULT_TLS13_CIPHERSUITES;
    DefaultConfig.SessionCacheSize := 17;
    DefaultConfig.SessionTimeout := 240;
    DefaultConfig.ALPNProtocols := 'h2,http/1.1';
    DefaultConfig.EnableSessionTickets := False;
    Lib.SetDefaultConfig(DefaultConfig);

    Ctx := Lib.CreateContext(sslCtxClient);

    Assert(Ctx.GetProtocolVersions = [sslProtocolTLS13],
      'direct-library client context applies ProtocolVersions from default config');
    Assert(Ctx.GetPreferredVersion = sslProtocolTLS13,
      'direct-library client context applies PreferredVersion from default config');
    Assert(Ctx.GetVerifyMode = [sslVerifyPeer, sslVerifyFailIfNoPeerCert],
      'direct-library client context applies VerifyMode from default config');
    Assert(Ctx.GetVerifyDepth = 2,
      'direct-library client context applies VerifyDepth from default config');
    Assert(Ctx.GetCipherList = SSL_DEFAULT_CIPHER_LIST,
      'direct-library client context keeps shipped CipherList baseline on unpublished custom-cipher backends');
    Assert(Ctx.GetCipherSuites = SSL_DEFAULT_TLS13_CIPHERSUITES,
      'direct-library client context keeps shipped CipherSuites baseline on unpublished custom-cipher backends');
    Assert(Ctx.GetSessionCacheSize = 17,
      'direct-library client context applies SessionCacheSize from default config');
    Assert(Ctx.GetSessionTimeout = 240,
      'direct-library client context applies SessionTimeout from default config');
    Assert(Ctx.GetALPNProtocols = 'h2,http/1.1',
      'direct-library client context applies ALPNProtocols from default config');
    Assert(not (ssoEnableSessionTickets in Ctx.GetOptions),
      'direct-library client context reflects normalized option-bridge defaults');
  finally
    Lib.SetDefaultConfig(OriginalConfig);
    Lib.Finalize;
  end;
end;

procedure Test_ServerContextKeepsVerifyPeerWithSystemRootsDefaultConfig;
var
  Lib: ISSLLibrary;
  OriginalConfig: TSSLConfig;
  DefaultConfig: TSSLConfig;
  Ctx: ISSLContext;
begin
  TestHeader('FreePascal direct-library server context keeps verify-peer with UseSystemRoots');

  Lib := CreateInitializedFreePascalLibrary;
  try
    OriginalConfig := Lib.GetDefaultConfig;
    DefaultConfig := OriginalConfig;
    DefaultConfig.VerifyMode := [sslVerifyPeer];
    DefaultConfig.UseSystemRoots := True;
    Lib.SetDefaultConfig(DefaultConfig);

    Ctx := Lib.CreateContext(sslCtxServer);

    Assert(Ctx.GetVerifyMode = [sslVerifyPeer],
      'direct-library server context keeps VerifyMode when UseSystemRoots is enabled');
  finally
    Lib.SetDefaultConfig(OriginalConfig);
    Lib.Finalize;
  end;
end;

begin
  try
    Test_ClientContextReflectsLibraryDefaultConfig;
    Test_ServerContextKeepsVerifyPeerWithSystemRootsDefaultConfig;

    WriteLn;
    WriteLn('Tests Passed: ', GTestsPassed);
    WriteLn('Tests Failed: ', GTestsFailed);

    if GTestsFailed > 0 then
      Halt(1);

    WriteLn('All tests passed.');
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
