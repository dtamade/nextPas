program test_tsslcontextconfig_surface;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fafafa.ssl;

procedure AssertTrue(const AName: string; AValue: Boolean);
begin
  if AValue then
    WriteLn('  [PASS] ', AName)
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Halt(1);
  end;
end;

procedure Test_DefaultBaseline;
var
  LClientConfig: TSSLContextConfig;
  LServerConfig: TSSLContextConfig;
begin
  LClientConfig := CreateDefaultContextConfig(sslCtxClient);
  AssertTrue('default context config uses auto-detect backend',
    LClientConfig.LibraryType = sslAutoDetect);
  AssertTrue('client default context type is preserved',
    LClientConfig.ContextType = sslCtxClient);
  AssertTrue('client default keeps TLS 1.2 enabled',
    sslProtocolTLS12 in LClientConfig.ProtocolVersions);
  AssertTrue('client default keeps TLS 1.3 enabled',
    sslProtocolTLS13 in LClientConfig.ProtocolVersions);
  AssertTrue('client default verifies peers',
    LClientConfig.VerifyMode = [sslVerifyPeer]);
  AssertTrue('client default keeps session cache size baseline',
    LClientConfig.SessionCacheSize = SSL_DEFAULT_SESSION_CACHE_SIZE);
  AssertTrue('client default keeps session timeout baseline',
    LClientConfig.SessionTimeout = SSL_DEFAULT_SESSION_TIMEOUT);
  AssertTrue('client default keeps session-ticket option enabled',
    ssoEnableSessionTickets in LClientConfig.Options);

  LServerConfig := CreateDefaultContextConfig(sslCtxServer);
  AssertTrue('server default context type is preserved',
    LServerConfig.ContextType = sslCtxServer);
  AssertTrue('server default keeps no-verify baseline',
    LServerConfig.VerifyMode = []);
end;

procedure Test_ProjectionDropsMixedScopeFields;
var
  LLegacyConfig: TSSLConfig;
  LContextConfig: TSSLContextConfig;
  LProjectedConfig: TSSLConfig;
begin
  LLegacyConfig := CreateDefaultConfig(sslCtxClient);
  LLegacyConfig.LibraryType := sslFreePascal;
  LLegacyConfig.BufferSize := 12345;
  LLegacyConfig.HandshakeTimeout := 42;
  LLegacyConfig.ServerName := 'legacy.example';
  LLegacyConfig.LogLevel := sslLogTrace;
  LLegacyConfig.ALPNProtocols := 'h2,http/1.1';
  Include(LLegacyConfig.Options, ssoDisableCompression);
  LLegacyConfig.EnableCompression := True;
  Exclude(LLegacyConfig.Options, ssoEnableSessionTickets);
  LLegacyConfig.EnableSessionTickets := True;
  Include(LLegacyConfig.Options, ssoEnableOCSPStapling);
  LLegacyConfig.EnableOCSPStapling := False;

  LContextConfig := ContextConfigFromSSLConfig(LLegacyConfig);
  LProjectedConfig := SSLConfigFromContextConfig(LContextConfig);

  AssertTrue('context projection keeps backend selection',
    LProjectedConfig.LibraryType = sslFreePascal);
  AssertTrue('context projection keeps ALPN defaults',
    LProjectedConfig.ALPNProtocols = 'h2,http/1.1');
  AssertTrue('context projection drops BufferSize',
    LProjectedConfig.BufferSize = 0);
  AssertTrue('context projection drops HandshakeTimeout',
    LProjectedConfig.HandshakeTimeout = 0);
  AssertTrue('context projection drops deprecated ServerName',
    LProjectedConfig.ServerName = '');
  AssertTrue('context projection drops library-scoped LogLevel',
    LProjectedConfig.LogLevel = sslLogError);
  AssertTrue('context projection preserves compression legacy precedence',
    not (ssoDisableCompression in LContextConfig.Options));
  AssertTrue('context projection preserves session-ticket legacy precedence',
    ssoEnableSessionTickets in LContextConfig.Options);
  AssertTrue('context projection preserves OCSP legacy precedence',
    not (ssoEnableOCSPStapling in LContextConfig.Options));
end;

procedure Test_FactoryCreateContextAcceptsContextConfig;
var
  LConfig: TSSLContextConfig;
  LContext: ISSLContext;
begin
  LConfig := CreateDefaultContextConfig(sslCtxClient);
  LConfig.LibraryType := sslFreePascal;
  LConfig.ProtocolVersions := [sslProtocolTLS13];
  LConfig.PreferredVersion := sslProtocolTLS13;
  LConfig.SessionCacheSize := 9;
  LConfig.SessionTimeout := 120;
  LConfig.ALPNProtocols := 'h2';

  LContext := TSSLFactory.CreateContext(LConfig);
  AssertTrue('factory accepts context-safe config',
    LContext <> nil);
  AssertTrue('factory applies context-safe protocol versions',
    LContext.GetProtocolVersions = [sslProtocolTLS13]);
  AssertTrue('factory applies context-safe preferred version',
    LContext.GetPreferredVersion = sslProtocolTLS13);
  AssertTrue('factory applies context-safe session cache size',
    LContext.GetSessionCacheSize = 9);
  AssertTrue('factory applies context-safe session timeout',
    LContext.GetSessionTimeout = 120);
  AssertTrue('factory applies context-safe ALPN defaults',
    LContext.GetALPNProtocols = 'h2');
end;

procedure Test_FactoryCreateContextPreservesContextSafeOptionTruth;
var
  LConfig: TSSLContextConfig;
  LContext: ISSLContext;
begin
  LConfig := CreateDefaultContextConfig(sslCtxClient);
  LConfig.LibraryType := sslFreePascal;
  LConfig.SessionCacheSize := 9;
  Exclude(LConfig.Options, ssoEnableSessionCache);

  LContext := TSSLFactory.CreateContext(LConfig);
  AssertTrue('factory preserves context-safe disabled session cache mode',
    not LContext.GetSessionCacheMode);
  AssertTrue('factory preserves context-safe disabled session cache option',
    not (ssoEnableSessionCache in LContext.GetOptions));
end;

begin
  WriteLn('========================================');
  WriteLn('  fafafa.ssl TSSLContextConfig 测试');
  WriteLn('========================================');

  Test_DefaultBaseline;
  Test_ProjectionDropsMixedScopeFields;
  Test_FactoryCreateContextAcceptsContextConfig;
  Test_FactoryCreateContextPreservesContextSafeOptionTruth;

  WriteLn('所有测试通过！');
end.
