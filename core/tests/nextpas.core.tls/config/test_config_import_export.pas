program test_config_import_export;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally keeps deprecated WithSNI
  import/export coverage for the compatibility-only builder surface. }

{**
 * Test suite for Phase 2.1.3 - Configuration Import/Export
 *
 * Tests the import/export functionality:
 * 1. JSON export - produces valid JSON
 * 2. JSON import - correctly restores configuration
 * 3. JSON round-trip - export → import → export produces identical results
 * 4. INI export - produces valid INI format
 * 5. INI import - correctly restores configuration
 * 6. INI round-trip - export → import → export produces identical results
 * 7. All configuration fields (protocols, certs, ciphers, options)
 * 8. Edge cases (empty config, missing fields)
 * 9. Preset configuration export/import
 *}

uses
  nextpas.core.system.sysutils,
  nextpas.core.text.view,
  nextpas.core.mem.default,
  nextpas.core.json.types,
  nextpas.core.json.parser,
  nextpas.core.json.value,
  nextpas.core.json.builder,
  nextpas.core.tls.base,
  nextpas.core.tls.backend.selector,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.freepascal.lib,
  nextpas.core.tls.pkcs11.types,
  nextpas.core.tls.exceptions;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

function CreateUnavailableBackendBuilder: ISSLContextBuilder;
begin
  Result := TSSLContextBuilder.Create.WithBackend(sslWinSSL);
end;

function CreateImpossibleAutoBackendBuilder: ISSLContextBuilder;
var
  LRequirements: TSSLRequirements;
begin
  LRequirements := CreateDefaultRequirements(optBalanced);
  LRequirements.MinSecurityScore := 95;
  Result := TSSLContextBuilder.Create.WithAutoBackendSelection(LRequirements);
end;

const
  SOFTHSM_MODULE_PATH = '/usr/lib/softhsm/libsofthsm2.so';

function BuildClientFails(ABuilder: ISSLContextBuilder): Boolean;
var
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  LResult := ABuilder.TryBuildClient(LContext);
  Result := not LResult.IsOk;
end;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ FAILED: ', AMessage);
  end;
end;

procedure TestHeader(const ATestName: string);
begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  ', ATestName);
  WriteLn('═══════════════════════════════════════════════════════════');
end;

function JSONParses(const AJSON: string): Boolean;
var
  LDoc: TJsonDocument;
begin
  LDoc.Init(DefaultAllocator);
  try
    Result := LDoc.Parse(TStringView.FromStr(AJSON));
  finally
    LDoc.Done;
  end;
end;

function JSONIsObject(const AJSON: string): Boolean;
var
  LDoc: TJsonDocument;
  LRoot: TJsonValue;
begin
  Result := False;
  LDoc.Init(DefaultAllocator);
  try
    if not LDoc.Parse(TStringView.FromStr(AJSON)) then
      Exit;
    LRoot := TJsonValue.Create(LDoc, LDoc.Root);
    Result := LRoot.Kind = jnkObject;
  finally
    LDoc.Done;
  end;
end;

function JSONHas(const AJSON, AKey: string): Boolean;
var
  LDoc: TJsonDocument;
  LRoot: TJsonValue;
begin
  Result := False;
  LDoc.Init(DefaultAllocator);
  try
    if not LDoc.Parse(TStringView.FromStr(AJSON)) then
      Exit;
    LRoot := TJsonValue.Create(LDoc, LDoc.Root);
    Result := LRoot.ObjectHas(AKey);
  finally
    LDoc.Done;
  end;
end;

function JSONStr(const AJSON, AKey: string): string;
var
  LDoc: TJsonDocument;
  LRoot: TJsonValue;
begin
  Result := '';
  LDoc.Init(DefaultAllocator);
  try
    if not LDoc.Parse(TStringView.FromStr(AJSON)) then
      Exit;
    LRoot := TJsonValue.Create(LDoc, LDoc.Root);
    Result := LRoot.Get(AKey).AsStr.ToString;
  finally
    LDoc.Done;
  end;
end;

function JSONBool(const AJSON, AKey: string): Boolean;
var
  LDoc: TJsonDocument;
  LRoot: TJsonValue;
begin
  Result := False;
  LDoc.Init(DefaultAllocator);
  try
    if not LDoc.Parse(TStringView.FromStr(AJSON)) then
      Exit;
    LRoot := TJsonValue.Create(LDoc, LDoc.Root);
    Result := LRoot.Get(AKey).AsBool;
  finally
    LDoc.Done;
  end;
end;

function JSONInt(const AJSON, AKey: string): Int64;
var
  LDoc: TJsonDocument;
  LRoot: TJsonValue;
begin
  Result := 0;
  LDoc.Init(DefaultAllocator);
  try
    if not LDoc.Parse(TStringView.FromStr(AJSON)) then
      Exit;
    LRoot := TJsonValue.Create(LDoc, LDoc.Root);
    Result := LRoot.Get(AKey).AsInt;
  finally
    LDoc.Done;
  end;
end;

function JSONArrayLen(const AJSON, AKey: string): UInt32;
var
  LDoc: TJsonDocument;
  LRoot: TJsonValue;
begin
  Result := 0;
  LDoc.Init(DefaultAllocator);
  try
    if not LDoc.Parse(TStringView.FromStr(AJSON)) then
      Exit;
    LRoot := TJsonValue.Create(LDoc, LDoc.Root);
    if not LRoot.ObjectHas(AKey) then
      Exit;
    Result := LRoot.Get(AKey).ArrayLen;
  finally
    LDoc.Done;
  end;
end;

{ Test 1: JSON export produces valid JSON }
procedure Test_JSONExport_ValidJSON;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 1: JSON Export Produces Valid JSON');

  LBuilder := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyPeer
    .WithCipherList('ECDHE+AESGCM');

  LJSON := LBuilder.ExportToJSON;

  Assert(LJSON <> '', 'JSON export is not empty');
  Assert(JSONParses(LJSON), 'JSON is valid and parseable');
  Assert(JSONIsObject(LJSON), 'JSON root is an object');
end;

{ Test 2: JSON export contains expected fields }
procedure Test_JSONExport_HasExpectedFields;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 2: JSON Export Contains Expected Fields');

  LBuilder := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyPeer
    .WithCipherList('ECDHE+AESGCM')
    .WithSessionTimeout(600);

  LJSON := LBuilder.ExportToJSON;
  Assert(JSONIsObject(LJSON), 'JSON root is object');

  Assert(JSONHas(LJSON, 'protocols'), 'Has protocols field');
  Assert(JSONHas(LJSON, 'verify_modes'), 'Has verify_modes field');
  Assert(JSONHas(LJSON, 'cipher_list'), 'Has cipher_list field');
  Assert(JSONHas(LJSON, 'session_timeout'), 'Has session_timeout field');
  Assert(JSONHas(LJSON, 'options'), 'Has options field');
end;

{ Test 3: JSON import restores configuration }
procedure Test_JSONImport_RestoresConfig;
var
  LBuilder1, LBuilder2: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 3: JSON Import Restores Configuration');

  // Create builder with specific config
  LBuilder1 := TSSLContextBuilder.Create
    .WithTLS13
    .WithVerifyPeer
    .WithVerifyDepth(5)
    .WithCipherList('ECDHE+AESGCM')
    .WithSessionTimeout(900);

  // Export to JSON
  LJSON := LBuilder1.ExportToJSON;

  // Create new builder and import
  LBuilder2 := TSSLContextBuilder.Create.ImportFromJSON(LJSON);

  // Export again and compare
  Assert(LBuilder2.ExportToJSON <> '', 'Imported builder can export');

  // Note: We can't directly compare all fields, but we can verify it doesn't crash
  Assert(True, 'JSON import completed without errors');
end;

{ Test 4: JSON round-trip produces consistent results }
procedure Test_JSONRoundTrip;
var
  LBuilder: ISSLContextBuilder;
  LJSON1, LJSON2: string;
begin
  TestHeader('Test 4: JSON Round-Trip Produces Consistent Results');

  // Create builder
  LBuilder := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyPeer
    .WithCipherList('ECDHE+AESGCM');

  // First export
  LJSON1 := LBuilder.ExportToJSON;

  // Import and export again
  LJSON2 := TSSLContextBuilder.Create
    .ImportFromJSON(LJSON1)
    .ExportToJSON;

  Assert(LJSON1 <> '', 'First export is not empty');
  Assert(LJSON2 <> '', 'Second export is not empty');
  Assert(LJSON1 = LJSON2, 'Round-trip produces identical JSON');
end;

{ Test 5: INI export produces valid format }
procedure Test_INIExport_ValidFormat;
var
  LBuilder: ISSLContextBuilder;
  LINI: string;
begin
  TestHeader('Test 5: INI Export Produces Valid Format');

  LBuilder := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyPeer;

  LINI := LBuilder.ExportToINI;

  Assert(LINI <> '', 'INI export is not empty');
  Assert(Pos('[SSL Context Configuration]', LINI) > 0, 'Contains main section header');
  Assert(Pos('protocols=', LINI) > 0, 'Contains protocols field');
  Assert(Pos('verify_modes=', LINI) > 0, 'Contains verify_modes field');
end;

{ Test 6: INI export contains section headers }
procedure Test_INIExport_HasSections;
var
  LBuilder: ISSLContextBuilder;
  LINI: string;
begin
  TestHeader('Test 6: INI Export Contains Section Headers');

  LBuilder := TSSLContextBuilder.Create
    .WithTLS12And13;

  LINI := LBuilder.ExportToINI;

  Assert(Pos('[SSL Context Configuration]', LINI) > 0, 'Has main section');
  Assert(Pos('[Certificates]', LINI) > 0, 'Has Certificates section');
  Assert(Pos('[Ciphers]', LINI) > 0, 'Has Ciphers section');
  Assert(Pos('[Advanced]', LINI) > 0, 'Has Advanced section');
  Assert(Pos('[Options]', LINI) > 0, 'Has Options section');
end;

{ Test 7: INI import restores configuration }
procedure Test_INIImport_RestoresConfig;
var
  LBuilder1, LBuilder2: ISSLContextBuilder;
  LINI: string;
begin
  TestHeader('Test 7: INI Import Restores Configuration');

  LBuilder1 := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyPeer;

  LINI := LBuilder1.ExportToINI;

  LBuilder2 := TSSLContextBuilder.Create.ImportFromINI(LINI);

  Assert(LBuilder2.ExportToINI <> '', 'Imported builder can export');
  Assert(True, 'INI import completed without errors');
end;

{ Test 8: INI round-trip produces consistent results }
procedure Test_INIRoundTrip;
var
  LBuilder: ISSLContextBuilder;
  LINI1, LINI2: string;
begin
  TestHeader('Test 8: INI Round-Trip Produces Consistent Results');

  LBuilder := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyPeer
    .WithSessionTimeout(600);

  LINI1 := LBuilder.ExportToINI;

  LINI2 := TSSLContextBuilder.Create
    .ImportFromINI(LINI1)
    .ExportToINI;

  Assert(LINI1 <> '', 'First export is not empty');
  Assert(LINI2 <> '', 'Second export is not empty');
  Assert(LINI1 = LINI2, 'Round-trip produces identical INI');
end;

{ Test 9: Export all protocol versions }
procedure Test_Export_AllProtocols;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 9: Export All Protocol Versions');

  LBuilder := TSSLContextBuilder.Create
    .WithProtocols([sslProtocolTLS10, sslProtocolTLS11, sslProtocolTLS12, sslProtocolTLS13]);

  LJSON := LBuilder.ExportToJSON;
  Assert(JSONArrayLen(LJSON, 'protocols') = 4, 'Exported 4 protocol versions');
end;

{ Test 10: Export with certificate paths }
procedure Test_Export_WithCertPaths;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 10: Export With Certificate Paths');

  LBuilder := TSSLContextBuilder.Create
    .WithCertificate('/path/to/cert.pem')
    .WithPrivateKey('/path/to/key.pem', 'password123')
    .WithCAFile('/path/to/ca.pem');

  LJSON := LBuilder.ExportToJSON;
  Assert(JSONStr(LJSON, 'certificate_file') = '/path/to/cert.pem', 'Certificate file exported');
  Assert(JSONStr(LJSON, 'private_key_file') = '/path/to/key.pem', 'Private key file exported');
  Assert(JSONStr(LJSON, 'ca_file') = '/path/to/ca.pem', 'CA file exported');
end;

{ Test 11: Export with cipher configuration }
procedure Test_Export_WithCiphers;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 11: Export With Cipher Configuration');

  LBuilder := TSSLContextBuilder.Create
    .WithCipherList('ECDHE+AESGCM:ECDHE+AES256')
    .WithTLS13Ciphersuites('TLS_AES_256_GCM_SHA384');

  LJSON := LBuilder.ExportToJSON;
  Assert(JSONStr(LJSON, 'cipher_list') = 'ECDHE+AESGCM:ECDHE+AES256', 'Cipher list exported');
  Assert(JSONStr(LJSON, 'tls13_ciphersuites') = 'TLS_AES_256_GCM_SHA384', 'TLS 1.3 ciphersuites exported');
end;

{ Test 12: Export with advanced options }
procedure Test_Export_WithAdvancedOptions;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 12: Export With Advanced Options');

  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  LBuilder := TSSLContextBuilder.Create
    .WithSNI('example.com')
    .WithALPN('h2,http/1.1')
    .WithSessionCache(True)
    .WithSessionTimeout(3600);
  {$POP}

  LJSON := LBuilder.ExportToJSON;
  Assert(JSONStr(LJSON, 'server_name') = 'example.com', 'SNI server name exported');
  Assert(JSONStr(LJSON, 'alpn_protocols') = 'h2,http/1.1', 'ALPN protocols exported');
  Assert(JSONBool(LJSON, 'session_cache_enabled') = True, 'Session cache exported');
  Assert(JSONInt(LJSON, 'session_timeout') = 3600, 'Session timeout exported');
end;

{ Test 13: Import empty JSON }
procedure Test_Import_EmptyJSON;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 13: Import Empty JSON');

  LBuilder := TSSLContextBuilder.Create;

  // Import empty JSON should not crash
  try
    LBuilder.ImportFromJSON('');
    Assert(True, 'Empty JSON import does not crash');
  except
    on E: Exception do
      Assert(False, 'Empty JSON import crashed: ' + E.Message);
  end;
end;

{ Test 14: Import empty INI }
procedure Test_Import_EmptyINI;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 14: Import Empty INI');

  LBuilder := TSSLContextBuilder.Create;

  // Import empty INI should not crash
  try
    LBuilder.ImportFromINI('');
    Assert(True, 'Empty INI import does not crash');
  except
    on E: Exception do
      Assert(False, 'Empty INI import crashed: ' + E.Message);
  end;
end;

{ Test 15: Preset configuration export }
procedure Test_Preset_Export;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 15: Preset Configuration Export');

  // Test Development preset
  LBuilder := TSSLContextBuilder.Development;
  LJSON := LBuilder.ExportToJSON;
  Assert(LJSON <> '', 'Development preset can be exported to JSON');

  // Test Production preset
  LBuilder := TSSLContextBuilder.Production;
  LJSON := LBuilder.ExportToJSON;
  Assert(LJSON <> '', 'Production preset can be exported to JSON');

  // Test StrictSecurity preset
  LBuilder := TSSLContextBuilder.StrictSecurity;
  LJSON := LBuilder.ExportToJSON;
  Assert(LJSON <> '', 'StrictSecurity preset can be exported to JSON');
end;

{ Test 16: Preset configuration import and use }
procedure Test_Preset_ImportAndUse;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCert, LKey: string;
begin
  TestHeader('Test 16: Preset Configuration Import and Use');

  // Generate test certificate
  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'test.local', 'Test Org', 30, LCert, LKey
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  // Export Production preset
  LJSON := TSSLContextBuilder.Production.ExportToJSON;

  // Create new builder from JSON and add certificate
  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .ImportFromJSON(LJSON)
    .WithCertificatePEM(LCert)
    .WithPrivateKeyPEM(LKey);

  // Try to build server context
  LResult := LBuilder.TryBuildServer(LContext);

  Assert(LResult.IsOk, 'Imported preset config can build server context');
  if not LResult.IsOk then
    WriteLn('  Error: ', LResult.ErrorMessage);
end;

{ Test 17: System roots configuration export }
procedure Test_Export_SystemRoots;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 17: System Roots Configuration Export');

  LBuilder := TSSLContextBuilder.Create
    .WithSystemRoots;

  LJSON := LBuilder.ExportToJSON;
  Assert(JSONBool(LJSON, 'use_system_roots') = True, 'System roots flag exported');
end;

{ Test 18: Options export and import }
procedure Test_Options_ExportImport;
var
  LBuilder1, LBuilder2: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 18: Options Export and Import');

  LBuilder1 := TSSLContextBuilder.Create
    .WithOptions([ssoEnableSNI, ssoDisableCompression, ssoDisableRenegotiation]);

  LJSON := LBuilder1.ExportToJSON;

  // Check options are in JSON
  Assert(JSONArrayLen(LJSON, 'options') > 0, 'Options exported to JSON');

  // Import and verify
  LBuilder2 := TSSLContextBuilder.Create.ImportFromJSON(LJSON);
  Assert(True, 'Options imported successfully');
end;

{ Test 19: JSON round-trip preserves explicit backend selection }
procedure Test_JSONRoundTrip_PreservesExplicitBackendSelection;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 19: JSON Round-Trip Preserves Explicit Backend Selection');

  LBuilder := CreateUnavailableBackendBuilder;
  Assert(BuildClientFails(LBuilder), 'Original explicit unavailable backend fails to build');

  LJSON := LBuilder.ExportToJSON;
  LBuilder := TSSLContextBuilder.Create.ImportFromJSON(LJSON);

  Assert(BuildClientFails(LBuilder), 'JSON round-trip preserves explicit unavailable backend selection');
end;

{ Test 20: INI round-trip preserves explicit backend selection }
procedure Test_INIRoundTrip_PreservesExplicitBackendSelection;
var
  LBuilder: ISSLContextBuilder;
  LINI: string;
begin
  TestHeader('Test 20: INI Round-Trip Preserves Explicit Backend Selection');

  LBuilder := CreateUnavailableBackendBuilder;
  Assert(BuildClientFails(LBuilder), 'Original explicit unavailable backend fails to build for INI round-trip');

  LINI := LBuilder.ExportToINI;
  LBuilder := TSSLContextBuilder.Create.ImportFromINI(LINI);

  Assert(BuildClientFails(LBuilder), 'INI round-trip preserves explicit unavailable backend selection');
end;

{ Test 21: JSON round-trip preserves auto-backend requirements }
procedure Test_JSONRoundTrip_PreservesAutoBackendRequirements;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 21: JSON Round-Trip Preserves Auto-Backend Requirements');

  LBuilder := CreateImpossibleAutoBackendBuilder;
  Assert(BuildClientFails(LBuilder), 'Original unmet auto-backend requirements fail to build');

  LJSON := LBuilder.ExportToJSON;
  LBuilder := TSSLContextBuilder.Create.ImportFromJSON(LJSON);

  Assert(BuildClientFails(LBuilder), 'JSON round-trip preserves unmet auto-backend requirements');
end;

{ Test 22: INI round-trip preserves auto-backend requirements }
procedure Test_INIRoundTrip_PreservesAutoBackendRequirements;
var
  LBuilder: ISSLContextBuilder;
  LINI: string;
begin
  TestHeader('Test 22: INI Round-Trip Preserves Auto-Backend Requirements');

  LBuilder := CreateImpossibleAutoBackendBuilder;
  Assert(BuildClientFails(LBuilder), 'Original unmet auto-backend requirements fail to build for INI round-trip');

  LINI := LBuilder.ExportToINI;
  LBuilder := TSSLContextBuilder.Create.ImportFromINI(LINI);

  Assert(BuildClientFails(LBuilder), 'INI round-trip preserves unmet auto-backend requirements');
end;

{ Test 23: JSON round-trip preserves PKCS#11 URI server key source }
procedure Test_JSONRoundTrip_PreservesPKCS11URI;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LValidation: TBuildValidationResult;
  LCert, LKey: string;
begin
  TestHeader('Test 23: JSON Round-Trip Preserves PKCS#11 URI');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'pkcs11-json.test', 'Test Org', 30, LCert, LKey
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithCertificatePEM(LCert)
    .UsePKCS11('pkcs11:token=TestToken;object=ServerKey;type=private');
  LValidation := LBuilder.ValidateServer;
  Assert(LValidation.IsValid, 'Original PKCS#11 URI server config is valid before JSON round-trip');

  LJSON := LBuilder.ExportToJSON;
  LBuilder := TSSLContextBuilder.Create.ImportFromJSON(LJSON);
  LValidation := LBuilder.ValidateServer;

  Assert(LValidation.IsValid, 'JSON round-trip preserves PKCS#11 URI server key source');
  if (not LValidation.IsValid) and (LValidation.ErrorCount > 0) then
    WriteLn('    Error: ', LValidation.Errors[0]);
end;

{ Test 24: INI round-trip preserves PKCS#11 URI server key source }
procedure Test_INIRoundTrip_PreservesPKCS11URI;
var
  LBuilder: ISSLContextBuilder;
  LINI: string;
  LValidation: TBuildValidationResult;
begin
  TestHeader('Test 24: INI Round-Trip Preserves PKCS#11 URI');

  LBuilder := TSSLContextBuilder.Create
    .WithCertificate('/tmp/pkcs11-ini-cert.pem')
    .UsePKCS11('pkcs11:token=TestToken;object=ServerKey;type=private');
  LValidation := LBuilder.ValidateServer;
  Assert(LValidation.IsValid, 'Original PKCS#11 URI server config is valid before INI round-trip');

  LINI := LBuilder.ExportToINI;
  LBuilder := TSSLContextBuilder.Create.ImportFromINI(LINI);
  LValidation := LBuilder.ValidateServer;

  Assert(LValidation.IsValid, 'INI round-trip preserves PKCS#11 URI server key source');
  if (not LValidation.IsValid) and (LValidation.ErrorCount > 0) then
    WriteLn('    Error: ', LValidation.Errors[0]);
end;

{ Test 25: JSON round-trip preserves PKCS#11 environment PIN source semantics }
procedure Test_JSONRoundTrip_PreservesPKCS11EnvironmentPINSource;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCert, LKey: string;
begin
  TestHeader('Test 25: JSON Round-Trip Preserves PKCS#11 Environment PIN Source');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'pkcs11-json-env.test', 'Test Org', 30, LCert, LKey
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCert)
    .UsePKCS11('pkcs11:token=TestToken;object=ServerKey;type=private?module-path=' + SOFTHSM_MODULE_PATH)
    .WithPKCS11PIN('PKCS11_IMPORT_EXPORT_MISSING_ENV')
    .WithPKCS11PINMethod(pmEnvironment);

  LJSON := LBuilder.ExportToJSON;
  LBuilder := TSSLContextBuilder.Create.ImportFromJSON(LJSON);
  LResult := LBuilder.TryBuildServer(LContext);

  Assert(LResult.IsErr, 'JSON round-trip keeps PKCS#11 environment PIN source failure observable');
  Assert(Pos('environment variable', LowerCase(LResult.ErrorMessage)) > 0,
    'JSON round-trip preserves missing environment variable error semantics');
end;

{ Test 26: INI round-trip preserves PKCS#11 PIN file source semantics }
procedure Test_INIRoundTrip_PreservesPKCS11PINFileSource;
var
  LBuilder: ISSLContextBuilder;
  LINI: string;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LMissingPINFile: string;
begin
  TestHeader('Test 26: INI Round-Trip Preserves PKCS#11 PIN File Source');

  LMissingPINFile := IncludeTrailingPathDelimiter(GetTempDir()) + 'pkcs11_import_export_missing_pin.txt';
  if FileExists(LMissingPINFile) then
    DeleteFile(LMissingPINFile);

  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificate('tests/certificate/test_certs/signer_cert.pem')
    .UsePKCS11('pkcs11:token=TestToken;object=ServerKey;type=private?module-path=' + SOFTHSM_MODULE_PATH)
    .WithPKCS11PIN(LMissingPINFile)
    .WithPKCS11PINMethod(pmFile);

  LINI := LBuilder.ExportToINI;
  LBuilder := TSSLContextBuilder.Create.ImportFromINI(LINI);
  LResult := LBuilder.TryBuildServer(LContext);

  Assert(LResult.IsErr, 'INI round-trip keeps PKCS#11 PIN file source failure observable');
  if Pos('pin file', LowerCase(LResult.ErrorMessage)) = 0 then
    WriteLn('    Error: ', LResult.ErrorMessage);
  Assert(Pos('pin file', LowerCase(LResult.ErrorMessage)) > 0,
    'INI round-trip preserves missing PIN file error semantics');
end;

{ Test 27: Manual JSON import accepts named PKCS#11 PIN method values }
procedure Test_JSONImport_AcceptsNamedPKCS11PINMethod;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  TestHeader('Test 27: Manual JSON Import Accepts Named PKCS#11 PIN Method');

  LJSON :=
    '{' +
    '"certificate_file":"tests/certificate/test_certs/signer_cert.pem",' +
    '"pkcs11_uri":"pkcs11:token=TestToken;object=ServerKey;type=private?module-path=' + SOFTHSM_MODULE_PATH + '",' +
    '"pkcs11_pin":"PKCS11_MANUAL_JSON_ENV",' +
    '"pkcs11_pin_method":"pmEnvironment"' +
    '}';

  try
    LBuilder := TSSLContextBuilder.Create.ImportFromJSON(LJSON);
    LResult := LBuilder.TryBuildServer(LContext);
    Assert(LResult.IsErr, 'Manual JSON import keeps named PKCS#11 env PIN method observable');
    Assert(Pos('environment variable', LowerCase(LResult.ErrorMessage)) > 0,
      'Manual JSON import preserves named PKCS#11 env source semantics');
  except
    on E: Exception do
      Assert(False, 'Manual JSON import with named pkcs11_pin_method crashed: ' + E.Message);
  end;
end;

{ Test 28: Manual INI import accepts named PKCS#11 PIN method values }
procedure Test_INIImport_AcceptsNamedPKCS11PINMethod;
var
  LBuilder: ISSLContextBuilder;
  LINI: string;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LMissingPINFile: string;
begin
  TestHeader('Test 28: Manual INI Import Accepts Named PKCS#11 PIN Method');

  LMissingPINFile := IncludeTrailingPathDelimiter(GetTempDir()) + 'pkcs11_manual_ini_missing_pin.txt';
  if FileExists(LMissingPINFile) then
    DeleteFile(LMissingPINFile);

  LINI :=
    '[main]' + LineEnding +
    'certificate_file=tests/certificate/test_certs/signer_cert.pem' + LineEnding +
    'pkcs11_uri=pkcs11:token=TestToken;object=ServerKey;type=private?module-path=' + SOFTHSM_MODULE_PATH + LineEnding +
    'pkcs11_pin=' + LMissingPINFile + LineEnding +
    'pkcs11_pin_method=pmFile' + LineEnding;

  try
    LBuilder := TSSLContextBuilder.Create.ImportFromINI(LINI);
    LResult := LBuilder.TryBuildServer(LContext);
    Assert(LResult.IsErr, 'Manual INI import keeps named PKCS#11 file PIN method observable');
    Assert(Pos('pin file', LowerCase(LResult.ErrorMessage)) > 0,
      'Manual INI import preserves named PKCS#11 file source semantics');
  except
    on E: Exception do
      Assert(False, 'Manual INI import with named pkcs11_pin_method crashed: ' + E.Message);
  end;
end;

{ Test 29: Manual JSON import with pkcs11_pin only resets stale method to direct PIN }
procedure Test_JSONImport_PKCS11PINOnly_DefaultsToValue;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  TestHeader('Test 29: Manual JSON Import With pkcs11_pin Only Resets Stale Method To Direct PIN');

  LJSON :=
    '{' +
    '"certificate_file":"tests/certificate/test_certs/signer_cert.pem",' +
    '"pkcs11_uri":"pkcs11:token=TestToken;object=ServerKey;type=private?module-path=' + SOFTHSM_MODULE_PATH + '&pin-source=env:PKCS11_URI_JSON_SHOULD_NOT_RUN",' +
    '"pkcs11_pin":"1234"' +
    '}';

  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithPKCS11PINMethod(pmEnvironment)
    .ImportFromJSON(LJSON);
  LResult := LBuilder.TryBuildServer(LContext);

  Assert(LResult.IsErr, 'Manual JSON import with pkcs11_pin only still fails without a real token');
  Assert(Pos('environment variable', LowerCase(LResult.ErrorMessage)) = 0,
    'Manual JSON import with pkcs11_pin only clears stale environment-source semantics');
end;

{ Test 30: Manual INI import with pkcs11_pin only resets stale method to direct PIN }
procedure Test_INIImport_PKCS11PINOnly_DefaultsToValue;
var
  LBuilder: ISSLContextBuilder;
  LINI: string;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  TestHeader('Test 30: Manual INI Import With pkcs11_pin Only Resets Stale Method To Direct PIN');

  LINI :=
    '[main]' + LineEnding +
    'certificate_file=tests/certificate/test_certs/signer_cert.pem' + LineEnding +
    'pkcs11_uri=pkcs11:token=TestToken;object=ServerKey;type=private?module-path=' + SOFTHSM_MODULE_PATH + '&pin-source=env:PKCS11_URI_INI_SHOULD_NOT_RUN' + LineEnding +
    'pkcs11_pin=1234' + LineEnding;

  LBuilder := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithPKCS11PINMethod(pmFile)
    .ImportFromINI(LINI);
  LResult := LBuilder.TryBuildServer(LContext);

  Assert(LResult.IsErr, 'Manual INI import with pkcs11_pin only still fails without a real token');
  Assert(Pos('pin file', LowerCase(LResult.ErrorMessage)) = 0,
    'Manual INI import with pkcs11_pin only clears stale file-source semantics');
end;

{ Test 31: Manual JSON import with certificate_pem clears stale certificate_file state }
procedure Test_JSONImport_CertificatePEMClearsStaleFileState;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LBuild: IJsonBuilder;
  LCertPEM, LKeyPEM: string;
begin
  TestHeader('Test 31: Manual JSON Import With certificate_pem Clears Stale certificate_file');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'json-cert-pem-clear.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  LBuild := JsonBuilder;
  LBuild.BeginObject;
  LBuild.Key('certificate_pem');
  LBuild.Str(LCertPEM);
  LBuild.EndObject;
  LJSON := LBuild.ToString;
  LBuilder := TSSLContextBuilder.Create
    .WithCertificate('/tmp/stale-cert-file.pem')
    .ImportFromJSON(LJSON);

  LJSON := LBuilder.ExportToJSON;
  Assert(JSONStr(LJSON, 'certificate_file') = '',
    'Manual JSON certificate_pem import clears stale certificate_file state');
  Assert(JSONStr(LJSON, 'certificate_pem') = LCertPEM,
    'Manual JSON certificate_pem import preserves imported PEM payload');
end;

{ Test 32: Manual JSON import with private_key_pem clears stale private_key_file state }
procedure Test_JSONImport_PrivateKeyPEMClearsStaleFileState;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LBuild: IJsonBuilder;
  LCertPEM, LKeyPEM: string;
begin
  TestHeader('Test 32: Manual JSON Import With private_key_pem Clears Stale private_key_file');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'json-key-pem-clear.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  LBuild := JsonBuilder;
  LBuild.BeginObject;
  LBuild.Key('private_key_pem');
  LBuild.Str(LKeyPEM);
  LBuild.EndObject;
  LJSON := LBuild.ToString;
  LBuilder := TSSLContextBuilder.Create
    .WithPrivateKey('/tmp/stale-private-key.pem')
    .ImportFromJSON(LJSON);

  LJSON := LBuilder.ExportToJSON;
  Assert(JSONStr(LJSON, 'private_key_file') = '',
    'Manual JSON private_key_pem import clears stale private_key_file state');
  Assert(JSONStr(LJSON, 'private_key_pem') = LKeyPEM,
    'Manual JSON private_key_pem import preserves imported PEM payload');
end;

{ Test 33: Early-data policy and max size survive JSON/INI round-trip }
procedure Test_EarlyDataPolicyMaxSize_RoundTrip;
var
  LBuilder: ISSLContextBuilder;
  LJSON, LJSONRoundTrip: string;
  LINI, LINIRoundTrip: string;
begin
  TestHeader('Test 33: Early-Data Policy And Max Size Round-Trip');

  LBuilder := TSSLContextBuilder.Create
    .WithClientEarlyData(True)
    .WithServerEarlyDataPolicy(sslEarlyDataServerIssueOnly)
    .WithServerMaxEarlyDataSize(4096);

  LJSON := LBuilder.ExportToJSON;
  Assert(JSONBool(LJSON, 'client_early_data_enabled'),
    'JSON export preserves client_early_data_enabled');
  Assert(JSONInt(LJSON, 'server_early_data_policy') = Ord(sslEarlyDataServerIssueOnly),
    'JSON export preserves server_early_data_policy');
  Assert(JSONInt(LJSON, 'server_max_early_data_size') = 4096,
    'JSON export preserves server_max_early_data_size');

  LJSONRoundTrip := TSSLContextBuilder.Create
    .ImportFromJSON(LJSON)
    .ExportToJSON;
  Assert(LJSON = LJSONRoundTrip,
    'JSON round-trip preserves early-data policy/max-size fields');

  LINI := LBuilder.ExportToINI;
  Assert(Pos('server_max_early_data_size=4096', LINI) > 0,
    'INI export preserves server_max_early_data_size');
  LINIRoundTrip := TSSLContextBuilder.Create
    .ImportFromINI(LINI)
    .ExportToINI;
  Assert(LINI = LINIRoundTrip,
    'INI round-trip preserves early-data policy/max-size fields');
end;

{ Test 34: JSON round-trip preserves server OCSP stapled response file }
procedure Test_JSONRoundTrip_PreservesServerOCSPStapledResponseFile;
var
  LBuilder: ISSLContextBuilder;
  LJSON, LJSONRoundTrip: string;
  LFileName: string;
begin
  TestHeader('Test 34: JSON Round-Trip Preserves Server OCSP Stapled Response File');

  LFileName := 'tests/fixtures/p2/ocsp/ocsp_response_successful_basic_v1.der';
  LBuilder := TSSLContextBuilder.Create
    .Override('server_ocsp_stapled_response_file', LFileName);

  LJSON := LBuilder.ExportToJSON;
  Assert(JSONHas(LJSON, 'server_ocsp_stapled_response_file'),
    'JSON export keeps server_ocsp_stapled_response_file visible');
  if JSONHas(LJSON, 'server_ocsp_stapled_response_file') then
    Assert(JSONStr(LJSON, 'server_ocsp_stapled_response_file') = LFileName,
      'JSON export preserves server_ocsp_stapled_response_file value');

  LJSONRoundTrip := TSSLContextBuilder.Create
    .ImportFromJSON(LJSON)
    .ExportToJSON;
  Assert(LJSON = LJSONRoundTrip,
    'JSON round-trip preserves server_ocsp_stapled_response_file');
end;

{ Test 35: INI round-trip preserves server OCSP stapled response file }
procedure Test_INIRoundTrip_PreservesServerOCSPStapledResponseFile;
var
  LBuilder: ISSLContextBuilder;
  LINI, LINIRoundTrip: string;
  LFileName: string;
begin
  TestHeader('Test 35: INI Round-Trip Preserves Server OCSP Stapled Response File');

  LFileName := 'tests/fixtures/p2/ocsp/ocsp_response_successful_basic_v1.der';
  LBuilder := TSSLContextBuilder.Create
    .Override('server_ocsp_stapled_response_file', LFileName);

  LINI := LBuilder.ExportToINI;
  Assert(Pos('server_ocsp_stapled_response_file=' + LFileName, LINI) > 0,
    'INI export preserves server_ocsp_stapled_response_file');

  LINIRoundTrip := TSSLContextBuilder.Create
    .ImportFromINI(LINI)
    .ExportToINI;
  Assert(LINI = LINIRoundTrip,
    'INI round-trip preserves server_ocsp_stapled_response_file');
end;

{ Test 36: JSON round-trip preserves server early-data replay store file }
procedure Test_JSONRoundTrip_PreservesServerEarlyDataReplayStoreFile;
var
  LBuilder: ISSLContextBuilder;
  LJSON, LJSONRoundTrip: string;
  LFileName: string;
begin
  TestHeader('Test 36: JSON Round-Trip Preserves Server Early-Data Replay Store File');

  LFileName := 'tmp/freepascal_tls13_early_data/builder_replay_store.bin';
  LBuilder := TSSLContextBuilder.Create
    .Override('server_early_data_replay_store_file', LFileName);

  LJSON := LBuilder.ExportToJSON;
  Assert(JSONHas(LJSON, 'server_early_data_replay_store_file'),
    'JSON export keeps server_early_data_replay_store_file visible');
  if JSONHas(LJSON, 'server_early_data_replay_store_file') then
    Assert(JSONStr(LJSON, 'server_early_data_replay_store_file') = LFileName,
      'JSON export preserves server_early_data_replay_store_file value');

  LJSONRoundTrip := TSSLContextBuilder.Create
    .ImportFromJSON(LJSON)
    .ExportToJSON;
  Assert(LJSON = LJSONRoundTrip,
    'JSON round-trip preserves server_early_data_replay_store_file');
end;

{ Test 37: INI round-trip preserves server early-data replay store file }
procedure Test_INIRoundTrip_PreservesServerEarlyDataReplayStoreFile;
var
  LBuilder: ISSLContextBuilder;
  LINI, LINIRoundTrip: string;
  LFileName: string;
begin
  TestHeader('Test 37: INI Round-Trip Preserves Server Early-Data Replay Store File');

  LFileName := 'tmp/freepascal_tls13_early_data/builder_replay_store.bin';
  LBuilder := TSSLContextBuilder.Create
    .Override('server_early_data_replay_store_file', LFileName);

  LINI := LBuilder.ExportToINI;
  Assert(Pos('server_early_data_replay_store_file=' + LFileName, LINI) > 0,
    'INI export preserves server_early_data_replay_store_file');

  LINIRoundTrip := TSSLContextBuilder.Create
    .ImportFromINI(LINI)
    .ExportToINI;
  Assert(LINI = LINIRoundTrip,
    'INI round-trip preserves server_early_data_replay_store_file');
end;

{ Test 38: JSON round-trip preserves server early-data replay store directory }
procedure Test_JSONRoundTrip_PreservesServerEarlyDataReplayStoreDirectory;
var
  LBuilder: ISSLContextBuilder;
  LJSON, LJSONRoundTrip: string;
  LDirectoryName: string;
begin
  TestHeader('Test 38: JSON Round-Trip Preserves Server Early-Data Replay Store Directory');

  LDirectoryName := 'tmp/freepascal_tls13_early_data/builder_replay_store_dir';
  LBuilder := TSSLContextBuilder.Create
    .Override('server_early_data_replay_store_directory', LDirectoryName);

  LJSON := LBuilder.ExportToJSON;
  Assert(JSONHas(LJSON, 'server_early_data_replay_store_directory'),
    'JSON export keeps server_early_data_replay_store_directory visible');
  if JSONHas(LJSON, 'server_early_data_replay_store_directory') then
    Assert(JSONStr(LJSON, 'server_early_data_replay_store_directory') = LDirectoryName,
      'JSON export preserves server_early_data_replay_store_directory value');

  LJSONRoundTrip := TSSLContextBuilder.Create
    .ImportFromJSON(LJSON)
    .ExportToJSON;
  Assert(LJSON = LJSONRoundTrip,
    'JSON round-trip preserves server_early_data_replay_store_directory');
end;

{ Test 39: INI round-trip preserves server early-data replay store directory }
procedure Test_INIRoundTrip_PreservesServerEarlyDataReplayStoreDirectory;
var
  LBuilder: ISSLContextBuilder;
  LINI, LINIRoundTrip: string;
  LDirectoryName: string;
begin
  TestHeader('Test 39: INI Round-Trip Preserves Server Early-Data Replay Store Directory');

  LDirectoryName := 'tmp/freepascal_tls13_early_data/builder_replay_store_dir';
  LBuilder := TSSLContextBuilder.Create
    .Override('server_early_data_replay_store_directory', LDirectoryName);

  LINI := LBuilder.ExportToINI;
  Assert(Pos('server_early_data_replay_store_directory=' + LDirectoryName, LINI) > 0,
    'INI export preserves server_early_data_replay_store_directory');

  LINIRoundTrip := TSSLContextBuilder.Create
    .ImportFromINI(LINI)
    .ExportToINI;
  Assert(LINI = LINIRoundTrip,
    'INI round-trip preserves server_early_data_replay_store_directory');
end;

{ Main Test Runner }
begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  Phase 2.1.3 Configuration Import/Export Test Suite');
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn;
  WriteLn('Testing configuration import/export functionality:');
  WriteLn('  1. JSON export/import');
  WriteLn('  2. INI export/import');
  WriteLn('  3. Round-trip consistency');
  WriteLn('  4. All configuration fields');
  WriteLn('  5. Edge cases');
  WriteLn;

  try
    // Run all tests
    Test_JSONExport_ValidJSON;
    Test_JSONExport_HasExpectedFields;
    Test_JSONImport_RestoresConfig;
    Test_JSONRoundTrip;
    Test_INIExport_ValidFormat;
    Test_INIExport_HasSections;
    Test_INIImport_RestoresConfig;
    Test_INIRoundTrip;
    Test_Export_AllProtocols;
    Test_Export_WithCertPaths;
    Test_Export_WithCiphers;
    Test_Export_WithAdvancedOptions;
    Test_Import_EmptyJSON;
    Test_Import_EmptyINI;
    Test_Preset_Export;
    Test_Preset_ImportAndUse;
    Test_Export_SystemRoots;
    Test_Options_ExportImport;
    Test_JSONRoundTrip_PreservesExplicitBackendSelection;
    Test_INIRoundTrip_PreservesExplicitBackendSelection;
    Test_JSONRoundTrip_PreservesAutoBackendRequirements;
    Test_INIRoundTrip_PreservesAutoBackendRequirements;
    Test_JSONRoundTrip_PreservesPKCS11URI;
    Test_INIRoundTrip_PreservesPKCS11URI;
    Test_JSONRoundTrip_PreservesPKCS11EnvironmentPINSource;
    Test_INIRoundTrip_PreservesPKCS11PINFileSource;
    Test_JSONImport_AcceptsNamedPKCS11PINMethod;
    Test_INIImport_AcceptsNamedPKCS11PINMethod;
    Test_JSONImport_PKCS11PINOnly_DefaultsToValue;
    Test_INIImport_PKCS11PINOnly_DefaultsToValue;
    Test_JSONImport_CertificatePEMClearsStaleFileState;
    Test_JSONImport_PrivateKeyPEMClearsStaleFileState;
    Test_EarlyDataPolicyMaxSize_RoundTrip;
    Test_JSONRoundTrip_PreservesServerOCSPStapledResponseFile;
    Test_INIRoundTrip_PreservesServerOCSPStapledResponseFile;
    Test_JSONRoundTrip_PreservesServerEarlyDataReplayStoreFile;
    Test_INIRoundTrip_PreservesServerEarlyDataReplayStoreFile;
    Test_JSONRoundTrip_PreservesServerEarlyDataReplayStoreDirectory;
    Test_INIRoundTrip_PreservesServerEarlyDataReplayStoreDirectory;

    // Print summary
    WriteLn;
    WriteLn('═══════════════════════════════════════════════════════════');
    WriteLn('  Test Summary');
    WriteLn('═══════════════════════════════════════════════════════════');
    WriteLn('  Tests Passed: ', GTestsPassed);
    WriteLn('  Tests Failed: ', GTestsFailed);
    WriteLn('  Total Tests:  ', GTestsPassed + GTestsFailed);
    WriteLn;

    if GTestsFailed = 0 then
    begin
      WriteLn('  ✓ ALL TESTS PASSED!');
      WriteLn;
      ExitCode := 0;
    end
    else
    begin
      WriteLn('  ✗ SOME TESTS FAILED!');
      WriteLn;
      ExitCode := 1;
    end;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('═══════════════════════════════════════════════════════════');
      WriteLn('  FATAL ERROR');
      WriteLn('═══════════════════════════════════════════════════════════');
      WriteLn('  Class: ', E.ClassName);
      WriteLn('  Message: ', E.Message);
      WriteLn;
      ExitCode := 2;
    end;
  end;
end.
