program test_freepascal_library;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.freepascal.lib;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

type
  TLogHelper = class
    FLastLevel: TSSLLogLevel;
    FLastMessage: string;
    FCalled: Boolean;
    procedure OnLog(ALevel: TSSLLogLevel; const AMessage: string);
  end;

procedure TLogHelper.OnLog(ALevel: TSSLLogLevel; const AMessage: string);
begin
  FLastLevel := ALevel;
  FLastMessage := AMessage;
  FCalled := True;
end;

procedure TestLifecycle;
var
  LLib: ISSLLibrary;
begin
  WriteLn('TestLifecycle');
  LLib := TFreePascalSSLLibrary.Create;
  Check(not LLib.IsInitialized, 'Not initialized before Initialize');
  Check(LLib.Initialize, 'Initialize returns True');
  Check(LLib.IsInitialized, 'IsInitialized after Initialize');
  LLib.Finalize;
  Check(not LLib.IsInitialized, 'Not initialized after Finalize');
end;

procedure TestIdentity;
var
  LLib: ISSLLibrary;
begin
  WriteLn('TestIdentity');
  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;
  try
    Check(LLib.GetLibraryType = sslFreePascal, 'LibraryType = sslFreePascal');
    Check(LLib.GetVersionString <> '', 'VersionString not empty');
    Check(LLib.GetVersionNumber > 0, 'VersionNumber > 0');
    Check(LLib.GetCompileFlags <> '', 'CompileFlags not empty');
  finally
    LLib.Finalize;
  end;
end;

procedure TestProtocolSupport;
var
  LLib: ISSLLibrary;
begin
  WriteLn('TestProtocolSupport');
  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;
  try
    Check(LLib.IsProtocolSupported(sslProtocolTLS12), 'TLS 1.2 supported');
    Check(LLib.IsProtocolSupported(sslProtocolTLS13), 'TLS 1.3 supported');
    Check(not LLib.IsProtocolSupported(sslProtocolSSL2), 'SSL 2 not supported');
    Check(not LLib.IsProtocolSupported(sslProtocolSSL3), 'SSL 3 not supported');
    Check(not LLib.IsProtocolSupported(sslProtocolDTLS10), 'DTLS 1.0 not supported');
  finally
    LLib.Finalize;
  end;
end;

procedure TestCipherSupport;
var
  LLib: ISSLLibrary;
begin
  WriteLn('TestCipherSupport');
  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;
  try
    Check(LLib.IsCipherSupported('TLS_AES_256_GCM_SHA384'), 'AES-256-GCM supported');
    Check(LLib.IsCipherSupported('TLS_AES_128_GCM_SHA256'), 'AES-128-GCM supported');
    Check(LLib.IsCipherSupported('TLS_CHACHA20_POLY1305_SHA256'), 'ChaCha20 supported');
    Check(not LLib.IsCipherSupported('BOGUS_CIPHER'), 'Bogus cipher not supported');
  finally
    LLib.Finalize;
  end;
end;

procedure TestFeatureSupport;
var
  LLib: ISSLLibrary;
begin
  WriteLn('TestFeatureSupport');
  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;
  try
    Check(LLib.IsFeatureSupported(sslFeatSNI), 'SNI supported');
    Check(LLib.IsFeatureSupported(sslFeatALPN), 'ALPN supported');
    Check(LLib.IsFeatureSupported(sslFeatSessionTickets), 'Session tickets supported');
    Check(LLib.IsFeatureSupported(sslFeatSessionCache), 'Session cache supported');
    Check(LLib.IsFeatureSupported(sslFeatOCSPStapling), 'OCSP stapling supported');
    Check(LLib.IsFeatureSupported(sslFeatCertificateTransparency), 'CT supported');
  finally
    LLib.Finalize;
  end;
end;

procedure TestCapabilities;
var
  LLib: ISSLLibrary;
  LCaps: TSSLBackendCapabilities;
begin
  WriteLn('TestCapabilities');
  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;
  try
    LCaps := LLib.GetCapabilities;
    Check(LCaps.SupportsTLS13, 'Caps: SupportsTLS13');
    Check(LCaps.SupportsECDHE, 'Caps: SupportsECDHE');
    Check(LCaps.SupportsChaChaPoly, 'Caps: SupportsChaChaPoly');
    Check(LCaps.SupportsPEMPrivateKey, 'Caps: SupportsPEMPrivateKey');
    Check(LCaps.MinTLSVersion = sslProtocolTLS12, 'Caps: MinTLS = TLS12');
    Check(LCaps.MaxTLSVersion = sslProtocolTLS13, 'Caps: MaxTLS = TLS13');
    Check(LCaps.BackendType = sslFreePascal, 'Caps: BackendType = sslFreePascal');
    Check(not LCaps.RequiresExternalLibrary, 'Caps: no external library');
    Check(LCaps.HasConstantTimeOperations, 'Caps: constant time ops');
    Check(LCaps.HasSecureMemoryWipe, 'Caps: secure memory wipe');
    Check(LCaps.HasAssemblyOptimization, 'Caps: assembly optimization');
    Check(LCaps.SupportsDERPrivateKey, 'Caps: DER private key');
    Check(LCaps.SupportsPKCS8PrivateKey, 'Caps: PKCS8 private key');
    Check(LCaps.SupportsCustomCipherSuites, 'Caps: custom cipher suites');
    Check(LCaps.SupportsCallbacks, 'Caps: callbacks');
    Check(LCaps.CompatibilityLevel > 0, 'Caps: CompatibilityLevel > 0');
    Check(not LCaps.SupportsDTLS, 'Caps: no DTLS');
    Check(not LCaps.SupportsPKCS12, 'Caps: no PKCS12');
  finally
    LLib.Finalize;
  end;
end;

procedure TestDefaultConfig;
var
  LLib: ISSLLibrary;
  LCfg: TSSLConfig;
begin
  WriteLn('TestDefaultConfig');
  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;
  try
    LCfg := LLib.GetDefaultConfig;
    Check(LCfg.LibraryType = sslFreePascal, 'DefaultConfig: LibraryType');
    LCfg.ServerName := 'test.example.com';
    LCfg.HandshakeTimeout := 5000;
    LLib.SetDefaultConfig(LCfg);
    LCfg := LLib.GetDefaultConfig;
    Check(LCfg.ServerName = 'test.example.com', 'DefaultConfig: ServerName roundtrip');
    Check(LCfg.HandshakeTimeout = 5000, 'DefaultConfig: HandshakeTimeout roundtrip');
  finally
    LLib.Finalize;
  end;
end;

procedure TestErrorState;
var
  LLib: ISSLLibrary;
begin
  WriteLn('TestErrorState');
  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;
  try
    Check(LLib.GetLastError = 0, 'No error initially');
    Check(LLib.GetLastErrorString = '', 'No error string initially');
    LLib.ClearError;
    Check(LLib.GetLastError = 0, 'Still no error after ClearError');
  finally
    LLib.Finalize;
  end;
end;

procedure TestStatistics;
var
  LLib: ISSLLibrary;
  LStats: TSSLStatistics;
begin
  WriteLn('TestStatistics');
  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;
  try
    LStats := LLib.GetStatistics;
    Check(LStats.ConnectionsTotal = 0, 'Stats: ConnectionsTotal = 0');
    Check(LStats.HandshakesSuccessful = 0, 'Stats: HandshakesSuccessful = 0');
    Check(LStats.BytesSent = 0, 'Stats: BytesSent = 0');
    LLib.ResetStatistics;
    LStats := LLib.GetStatistics;
    Check(LStats.ConnectionsTotal = 0, 'Stats: still 0 after reset');
  finally
    LLib.Finalize;
  end;
end;

procedure TestLogCallback;
var
  LLib: ISSLLibrary;
  LHelper: TLogHelper;
  LCfg: TSSLConfig;
begin
  WriteLn('TestLogCallback');
  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;
  LHelper := TLogHelper.Create;
  try
    LCfg := LLib.GetDefaultConfig;
    LCfg.LogLevel := sslLogTrace;
    LLib.SetDefaultConfig(LCfg);

    LHelper.FCalled := False;
    LLib.SetLogCallback(@LHelper.OnLog);
    LLib.Log(sslLogInfo, 'test message');
    Check(LHelper.FCalled, 'Log callback was called');
    Check(LHelper.FLastLevel = sslLogInfo, 'Log level = sslLogInfo');
    Check(Pos('test message', LHelper.FLastMessage) > 0, 'Log message contains text');
    LLib.SetLogCallback(nil);
    LHelper.FCalled := False;
    LLib.Log(sslLogError, 'should not arrive');
    Check(not LHelper.FCalled, 'No callback after SetLogCallback(nil)');
  finally
    LHelper.Free;
    LLib.Finalize;
  end;
end;

procedure TestFactoryMethods;
var
  LLib: ISSLLibrary;
  LCtxClient, LCtxServer: ISSLContext;
  LCert: ISSLCertificate;
  LStore: ISSLCertificateStore;
begin
  WriteLn('TestFactoryMethods');
  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;
  try
    LCtxClient := LLib.CreateContext(sslCtxClient);
    Check(LCtxClient <> nil, 'CreateContext(Client) not nil');
    Check(LCtxClient.GetContextType = sslCtxClient, 'Context type = Client');

    LCtxServer := LLib.CreateContext(sslCtxServer);
    Check(LCtxServer <> nil, 'CreateContext(Server) not nil');
    Check(LCtxServer.GetContextType = sslCtxServer, 'Context type = Server');

    LCert := LLib.CreateCertificate;
    Check(LCert <> nil, 'CreateCertificate not nil');

    LStore := LLib.CreateCertificateStore;
    Check(LStore <> nil, 'CreateCertificateStore not nil');
    Check(LStore.GetCount = 0, 'New store is empty');
  finally
    LLib.Finalize;
  end;
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestLifecycle;
  TestIdentity;
  TestProtocolSupport;
  TestCipherSupport;
  TestFeatureSupport;
  TestCapabilities;
  TestDefaultConfig;
  TestErrorState;
  TestStatistics;
  TestLogCallback;
  TestFactoryMethods;

  WriteLn;
  WriteLn('ISSLLibrary test suite: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
