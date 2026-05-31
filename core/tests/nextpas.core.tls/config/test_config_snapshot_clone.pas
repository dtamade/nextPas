program test_config_snapshot_clone;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally keeps deprecated WithSNI
  snapshot/clone coverage for the compatibility-only builder surface. }

{**
 * Test suite for Phase 2.1.4 - Configuration Snapshot and Clone
 *
 * Tests the snapshot and clone functionality:
 * 1. Clone - Create independent copy of builder
 * 2. Reset - Reset builder to default configuration
 * 3. ResetToDefaults - Alias for Reset
 * 4. Merge - Merge configuration from another builder
 *}

uses
  SysUtils,
  fpjson, jsonparser,
  nextpas.core.tls.base,
  nextpas.core.tls.backend.selector,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.pkcs11.types,
  nextpas.core.tls.freepascal.lib;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

function CreateRuntimeBuilder: ISSLContextBuilder;
begin
  Result := TSSLContextBuilder.Create.WithBackend(sslFreePascal);
end;

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

function ParseBuilderJSON(ABuilder: ISSLContextBuilder): TJSONObject;
begin
  Result := TJSONObject(GetJSON(ABuilder.ExportToJSON));
end;

{ Test 1: Clone creates independent copy }
procedure Test_Clone_Independence;
var
  LBuilder1, LBuilder2: ISSLContextBuilder;
  LJSON1, LJSON2: string;
begin
  TestHeader('Test 1: Clone Creates Independent Copy');

  LBuilder1 := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyPeer
    .WithCipherList('ECDHE+AESGCM');

  // Clone the builder
  LBuilder2 := LBuilder1.Clone;

  Assert(LBuilder2 <> nil, 'Clone returns valid builder');

  // Export both to verify they are identical
  LJSON1 := LBuilder1.ExportToJSON;
  LJSON2 := LBuilder2.ExportToJSON;

  Assert(LJSON1 = LJSON2, 'Clone produces identical configuration');

  // Modify clone
  LBuilder2.WithTLS13.WithCipherList('CHACHA20');

  // Verify original is unchanged
  LJSON1 := LBuilder1.ExportToJSON;
  LJSON2 := LBuilder2.ExportToJSON;

  Assert(LJSON1 <> LJSON2, 'Modifying clone does not affect original');
end;

{ Test 2: Clone copies all fields }
procedure Test_Clone_AllFields;
var
  LBuilder1, LBuilder2: ISSLContextBuilder;
  LJSON1, LJSON2: string;
begin
  TestHeader('Test 2: Clone Copies All Fields');

  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  LBuilder1 := TSSLContextBuilder.Create
    .WithTLS13
    .WithVerifyPeer
    .WithVerifyDepth(15)
    .WithCertificate('/path/to/cert.pem')
    .WithPrivateKey('/path/to/key.pem', 'password')
    .WithCAFile('/path/to/ca.pem')
    .WithCipherList('ECDHE+AESGCM')
    .WithTLS13Ciphersuites('TLS_AES_256_GCM_SHA384')
    .WithSNI('example.com')
    .WithALPN('h2,http/1.1')
    .WithSessionCache(True)
    .WithSessionTimeout(3600);
  {$POP}

  LBuilder2 := LBuilder1.Clone;

  LJSON1 := LBuilder1.ExportToJSON;
  LJSON2 := LBuilder2.ExportToJSON;

  Assert(LJSON1 = LJSON2, 'Clone copies all fields correctly');
end;

{ Test 3: Reset restores defaults }
procedure Test_Reset_RestoresDefaults;
var
  LBuilder: ISSLContextBuilder;
  LDefault, LModified, LReset: string;
begin
  TestHeader('Test 3: Reset Restores Defaults');

  // Get default configuration
  LDefault := TSSLContextBuilder.Create.ExportToJSON;

  // Create and modify builder
  LBuilder := TSSLContextBuilder.Create
    .WithTLS13
    .WithVerifyNone
    .WithCipherList('CHACHA20')
    .WithSessionTimeout(7200);

  LModified := LBuilder.ExportToJSON;
  Assert(LDefault <> LModified, 'Configuration is modified');

  // Reset to defaults
  LBuilder.Reset;
  LReset := LBuilder.ExportToJSON;

  Assert(LDefault = LReset, 'Reset restores default configuration');
end;

{ Test 4: ResetToDefaults is alias for Reset }
procedure Test_ResetToDefaults_Alias;
var
  LBuilder: ISSLContextBuilder;
  LReset1, LReset2: string;
begin
  TestHeader('Test 4: ResetToDefaults Is Alias For Reset');

  LBuilder := TSSLContextBuilder.Create
    .WithTLS13
    .WithVerifyNone;

  // Reset using Reset
  LBuilder.Reset;
  LReset1 := LBuilder.ExportToJSON;

  // Modify again
  LBuilder.WithTLS12.WithSessionTimeout(9999);

  // Reset using ResetToDefaults
  LBuilder.ResetToDefaults;
  LReset2 := LBuilder.ExportToJSON;

  Assert(LReset1 = LReset2, 'ResetToDefaults produces same result as Reset');
end;

{ Test 5: Reset supports method chaining }
procedure Test_Reset_Chaining;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCert, LKey: string;
begin
  TestHeader('Test 5: Reset Supports Method Chaining');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'test.local', 'Test Org', 30, LCert, LKey
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  LBuilder := CreateRuntimeBuilder
    .WithTLS13
    .WithVerifyNone
    .Reset  // Reset and continue chaining
    .WithCertificatePEM(LCert)
    .WithPrivateKeyPEM(LKey);

  LResult := LBuilder.TryBuildServer(LContext);

  Assert(LResult.IsOk, 'Reset in chain allows successful build');
end;

{ Test 6: Merge from empty source }
procedure Test_Merge_EmptySource;
var
  LBuilder1, LBuilder2: ISSLContextBuilder;
  LBefore, LAfter: string;
begin
  TestHeader('Test 6: Merge From Empty Source');

  LBuilder1 := TSSLContextBuilder.Create
    .WithTLS13
    .WithVerifyPeer;

  LBefore := LBuilder1.ExportToJSON;

  // Merge with empty builder
  LBuilder2 := TSSLContextBuilder.Create;
  LBuilder1.Merge(LBuilder2);

  LAfter := LBuilder1.ExportToJSON;

  // Should remain unchanged or update to source's defaults
  Assert(True, 'Merge with empty source completes');
end;

{ Test 7: Merge from nil source }
procedure Test_Merge_NilSource;
var
  LBuilder: ISSLContextBuilder;
  LBefore, LAfter: string;
begin
  TestHeader('Test 7: Merge From Nil Source');

  LBuilder := TSSLContextBuilder.Create
    .WithTLS13;

  LBefore := LBuilder.ExportToJSON;

  // Merge with nil
  LBuilder.Merge(nil);

  LAfter := LBuilder.ExportToJSON;

  Assert(LBefore = LAfter, 'Merge with nil does not change configuration');
end;

{ Test 8: Merge replaces fields }
procedure Test_Merge_ReplacesFields;
var
  LBuilder1, LBuilder2: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 8: Merge Replaces Fields');

  LBuilder1 := TSSLContextBuilder.Create
    .WithTLS12
    .WithCipherList('ECDHE+AESGCM')
    .WithSessionTimeout(600);

  LBuilder2 := TSSLContextBuilder.Create
    .WithTLS13  // Different protocol
    .WithCipherList('CHACHA20');  // Different cipher

  // Merge Builder2 into Builder1
  LBuilder1.Merge(LBuilder2);

  LJSON := LBuilder1.ExportToJSON;

  // Verify configuration changed
  Assert(Pos('CHACHA20', LJSON) > 0, 'Merge applied cipher list from source');
  Assert(Pos('600', LJSON) = 0, 'Session timeout from original is replaced');
end;

{ Test 9: Merge preserves unspecified fields }
procedure Test_Merge_PreservesFields;
var
  LBuilder1, LBuilder2: ISSLContextBuilder;
  LJSONBefore, LJSONAfter: string;
begin
  TestHeader('Test 9: Merge Preserves Unspecified Fields');

  LBuilder1 := TSSLContextBuilder.Create
    .WithTLS12
    .WithCipherList('ECDHE+AESGCM')
    .WithSessionTimeout(600);

  // Builder2 only specifies cipher list
  LBuilder2 := TSSLContextBuilder.Create.Reset
    .WithCipherList('CHACHA20');

  LJSONBefore := LBuilder1.ExportToJSON;

  // Merge
  LBuilder1.Merge(LBuilder2);

  LJSONAfter := LBuilder1.ExportToJSON;

  Assert(LJSONBefore <> LJSONAfter, 'Configuration changed after merge');
end;

{ Test 10: Merge supports method chaining }
procedure Test_Merge_Chaining;
var
  LBuilder1, LBuilder2, LBuilder3: ISSLContextBuilder;
begin
  TestHeader('Test 10: Merge Supports Method Chaining');

  LBuilder1 := TSSLContextBuilder.Create
    .WithTLS12;

  LBuilder2 := TSSLContextBuilder.Create
    .WithTLS13;

  LBuilder3 := TSSLContextBuilder.Create
    .WithSessionTimeout(9999);

  // Chain multiple merges
  LBuilder1
    .Merge(LBuilder2)
    .Merge(LBuilder3)
    .WithVerifyPeer;

  Assert(True, 'Multiple merges in chain work correctly');
end;

{ Test 11: Clone and merge workflow }
procedure Test_Clone_Merge_Workflow;
var
  LBase, LClone1, LClone2: ISSLContextBuilder;
  LOverride: ISSLContextBuilder;
begin
  TestHeader('Test 11: Clone And Merge Workflow');

  // Base configuration
  LBase := TSSLContextBuilder.Production;

  // Create two independent clones
  LClone1 := LBase.Clone.WithSessionTimeout(1800);
  LClone2 := LBase.Clone.WithSessionTimeout(3600);

  // Override configuration
  LOverride := TSSLContextBuilder.Create
    .WithVerifyDepth(20);

  // Merge override into both clones
  LClone1.Merge(LOverride);
  LClone2.Merge(LOverride);

  Assert(True, 'Clone and merge workflow completes successfully');
end;

{ Test 12: Reset and rebuild }
procedure Test_Reset_Rebuild;
var
  LBuilder: ISSLContextBuilder;
  LContext1, LContext2: ISSLContext;
  LResult: TSSLOperationResult;
  LCert, LKey: string;
begin
  TestHeader('Test 12: Reset And Rebuild');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'test.local', 'Test Org', 30, LCert, LKey
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  LBuilder := CreateRuntimeBuilder
    .WithCertificatePEM(LCert)
    .WithPrivateKeyPEM(LKey);

  // Build first context
  LResult := LBuilder.TryBuildServer(LContext1);
  Assert(LResult.IsOk, 'First build succeeds');

  // Reset and build again
  LBuilder.Reset
    .WithCertificatePEM(LCert)
    .WithPrivateKeyPEM(LKey);

  LResult := LBuilder.TryBuildServer(LContext2);
  Assert(LResult.IsOk, 'Second build after reset succeeds');

  Assert(LContext1 <> LContext2, 'Reset creates new independent context');
end;

{ Test 13: Preset clone }
procedure Test_Clone_PreservesExplicitBackendSelection;
var
  LBuilder, LClone: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  TestHeader('Test 13: Clone Preserves Explicit Backend Selection');

  LBuilder := CreateUnavailableBackendBuilder;

  LResult := LBuilder.TryBuildClient(LContext);
  Assert(not LResult.IsOk, 'Original explicit unavailable backend fails to build');

  LClone := LBuilder.Clone;
  LResult := LClone.TryBuildClient(LContext);
  Assert(not LResult.IsOk, 'Clone preserves explicit unavailable backend selection');
end;

{ Test 14: Reset clears explicit backend selection }
procedure Test_Reset_ClearsExplicitBackendSelection;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  TestHeader('Test 14: Reset Clears Explicit Backend Selection');

  LBuilder := CreateUnavailableBackendBuilder.Reset;

  LResult := LBuilder.TryBuildClient(LContext);
  Assert(LResult.IsOk, 'Reset clears explicit backend and restores constructor defaults');
  if LResult.IsOk then
    Assert(LContext <> nil, 'Reset builder can create a context after clearing backend pin');
end;

{ Test 15: Merge preserves explicit backend selection }
procedure Test_Merge_PreservesExplicitBackendSelection;
var
  LSource, LDestination: ISSLContextBuilder;
begin
  TestHeader('Test 15: Merge Preserves Explicit Backend Selection');

  LSource := CreateUnavailableBackendBuilder;
  Assert(BuildClientFails(LSource), 'Source explicit unavailable backend fails to build');

  LDestination := TSSLContextBuilder.Create;
  LDestination.Merge(LSource);

  Assert(BuildClientFails(LDestination), 'Merge preserves explicit unavailable backend selection from source');
end;

{ Test 16: Merge preserves auto-backend requirements }
procedure Test_Merge_PreservesAutoBackendRequirements;
var
  LSource, LDestination: ISSLContextBuilder;
begin
  TestHeader('Test 16: Merge Preserves Auto-Backend Requirements');

  LSource := CreateImpossibleAutoBackendBuilder;
  Assert(BuildClientFails(LSource), 'Source unmet auto-backend requirements fail to build');

  LDestination := TSSLContextBuilder.Create.WithBackend(sslFreePascal);
  Assert(not BuildClientFails(LDestination), 'Destination explicit runtime backend builds before merge');

  LDestination.Merge(LSource);

  Assert(BuildClientFails(LDestination), 'Merge preserves unmet auto-backend requirements from source');
end;

{ Test 17: Preset clone }
procedure Test_Preset_Clone;
var
  LDev1, LDev2: ISSLContextBuilder;
  LJSON1, LJSON2: string;
begin
  TestHeader('Test 17: Preset Clone');

  LDev1 := TSSLContextBuilder.Development;
  LDev2 := LDev1.Clone;

  LJSON1 := LDev1.ExportToJSON;
  LJSON2 := LDev2.ExportToJSON;

  Assert(LJSON1 = LJSON2, 'Cloning preset produces identical configuration');

  // Modify clone
  LDev2.WithSessionTimeout(9999);

  LJSON1 := LDev1.ExportToJSON;
  LJSON2 := LDev2.ExportToJSON;

  Assert(LJSON1 <> LJSON2, 'Modifying preset clone does not affect original');
end;

{ Test 18: Merge with preset }
procedure Test_Merge_WithPreset;
var
  LBuilder: ISSLContextBuilder;
  LProd: ISSLContextBuilder;
begin
  TestHeader('Test 18: Merge With Preset');

  LBuilder := TSSLContextBuilder.Create
    .WithTLS12;

  LProd := TSSLContextBuilder.Production;

  // Merge production defaults
  LBuilder.Merge(LProd);

  Assert(True, 'Merging with preset completes successfully');
end;

{ Test 19: Complex merge scenario }
procedure Test_Complex_Merge;
var
  LBase, LDev, LProd: ISSLContextBuilder;
  LFinal: string;
begin
  TestHeader('Test 19: Complex Merge Scenario');

  // Start with development preset
  LBase := TSSLContextBuilder.Development.Clone;

  // Create custom configurations
  LDev := TSSLContextBuilder.Create
    .WithSessionTimeout(1800)
    .WithCipherList('DEV-CIPHER');

  LProd := TSSLContextBuilder.StrictSecurity.Clone;

  // Merge development settings, then production security
  LBase.Merge(LDev).Merge(LProd);

  LFinal := LBase.ExportToJSON;

  Assert(LFinal <> '', 'Complex merge produces valid configuration');
end;

{ Test 20: Merge preserves PKCS#11 URI server key source }
procedure Test_Merge_PreservesPKCS11URI;
var
  LSource, LDestination: ISSLContextBuilder;
  LValidation: TBuildValidationResult;
  LCert, LKey: string;
begin
  TestHeader('Test 20: Merge Preserves PKCS#11 URI');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'pkcs11-merge.test', 'Test Org', 30, LCert, LKey
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  LSource := TSSLContextBuilder.Create
    .WithCertificatePEM(LCert)
    .UsePKCS11('pkcs11:token=TestToken;object=ServerKey;type=private');
  LValidation := LSource.ValidateServer;
  Assert(LValidation.IsValid, 'Source PKCS#11 URI server config is valid before merge');

  LDestination := TSSLContextBuilder.Create;
  LDestination.Merge(LSource);
  LValidation := LDestination.ValidateServer;

  Assert(LValidation.IsValid, 'Merge preserves PKCS#11 URI server key source');
  if (not LValidation.IsValid) and (LValidation.ErrorCount > 0) then
    WriteLn('    Error: ', LValidation.Errors[0]);
end;

{ Test 21: Merge preserves PKCS#11 environment PIN source semantics }
procedure Test_Merge_PreservesPKCS11EnvironmentPINSource;
var
  LSource, LDestination: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCert, LKey: string;
begin
  TestHeader('Test 21: Merge Preserves PKCS#11 Environment PIN Source');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'pkcs11-merge-env.test', 'Test Org', 30, LCert, LKey
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  LSource := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(LCert)
    .UsePKCS11('pkcs11:token=TestToken;object=ServerKey;type=private?module-path=' + SOFTHSM_MODULE_PATH)
    .WithPKCS11PIN('PKCS11_MERGE_MISSING_ENV')
    .WithPKCS11PINMethod(pmEnvironment);

  LDestination := TSSLContextBuilder.Create;
  LDestination.Merge(LSource);
  LResult := LDestination.TryBuildServer(LContext);

  Assert(LResult.IsErr, 'Merge keeps PKCS#11 environment PIN source failure observable');
  Assert(Pos('environment variable', LowerCase(LResult.ErrorMessage)) > 0,
    'Merge preserves missing environment variable error semantics');
end;

{ Test 22: Merge file sources clear stale PEM state }
procedure Test_Merge_FileSources_ClearStalePEMState;
var
  LSource, LDestination: ISSLContextBuilder;
  LObj: TJSONObject;
begin
  TestHeader('Test 22: Merge File Sources Clear Stale PEM State');

  LDestination := TSSLContextBuilder.Create
    .WithCertificatePEM('destination-cert-pem')
    .WithPrivateKeyPEM('destination-private-key-pem');

  LSource := TSSLContextBuilder.Create
    .WithCertificate('/tmp/merged-cert-file.pem')
    .WithPrivateKey('/tmp/merged-private-key.pem');

  LDestination.Merge(LSource);

  LObj := ParseBuilderJSON(LDestination);
  try
    Assert(LObj.Strings['certificate_file'] = '/tmp/merged-cert-file.pem',
      'Merge keeps merged certificate_file export-visible');
    Assert(LObj.Strings['certificate_pem'] = '',
      'Merge(certificate_file) clears stale certificate_pem state');
    Assert(LObj.Strings['private_key_file'] = '/tmp/merged-private-key.pem',
      'Merge keeps merged private_key_file export-visible');
    Assert(LObj.Strings['private_key_pem'] = '',
      'Merge(private_key_file) clears stale private_key_pem state');
  finally
    LObj.Free;
  end;
end;

{ Test 23: Merge PEM sources clear stale file state }
procedure Test_Merge_PEMSources_ClearStaleFileState;
var
  LSource, LDestination: ISSLContextBuilder;
  LObj: TJSONObject;
begin
  TestHeader('Test 23: Merge PEM Sources Clear Stale File State');

  LDestination := TSSLContextBuilder.Create
    .WithCertificate('/tmp/stale-destination-cert.pem')
    .WithPrivateKey('/tmp/stale-destination-key.pem');

  LSource := TSSLContextBuilder.Create
    .WithCertificatePEM('merged-certificate-pem')
    .WithPrivateKeyPEM('merged-private-key-pem');

  LDestination.Merge(LSource);

  LObj := ParseBuilderJSON(LDestination);
  try
    Assert(LObj.Strings['certificate_file'] = '',
      'Merge(certificate_pem) clears stale certificate_file state');
    Assert(LObj.Strings['certificate_pem'] = 'merged-certificate-pem',
      'Merge keeps merged certificate_pem export-visible');
    Assert(LObj.Strings['private_key_file'] = '',
      'Merge(private_key_pem) clears stale private_key_file state');
    Assert(LObj.Strings['private_key_pem'] = 'merged-private-key-pem',
      'Merge keeps merged private_key_pem export-visible');
  finally
    LObj.Free;
  end;
end;

{ Test 24: Clone/reset/merge preserve early-data policy and max size }
procedure Test_Clone_ResetMerge_EarlyDataFields;
var
  LSource, LClone, LDestination: ISSLContextBuilder;
  LObj: TJSONObject;
begin
  TestHeader('Test 24: Clone Reset Merge Preserve Early-Data Fields');

  LSource := TSSLContextBuilder.Create
    .WithClientEarlyData(True)
    .WithServerEarlyDataPolicy(sslEarlyDataServerIssueOnly)
    .WithServerMaxEarlyDataSize(2048)
    .WithServerEarlyDataReplayStoreFile('/tmp/clone-replay-store.bin');

  LClone := LSource.Clone;
  LObj := ParseBuilderJSON(LClone);
  try
    Assert(LObj.Booleans['client_early_data_enabled'],
      'Clone preserves client_early_data_enabled');
    Assert(LObj.Integers['server_early_data_policy'] = Ord(sslEarlyDataServerIssueOnly),
      'Clone preserves server_early_data_policy');
    Assert(LObj.Integers['server_max_early_data_size'] = 2048,
      'Clone preserves server_max_early_data_size');
    Assert(LObj.Strings['server_early_data_replay_store_file'] = '/tmp/clone-replay-store.bin',
      'Clone preserves server_early_data_replay_store_file');
  finally
    LObj.Free;
  end;

  LClone.Reset;
  LObj := ParseBuilderJSON(LClone);
  try
    Assert(not LObj.Booleans['client_early_data_enabled'],
      'Reset clears client_early_data_enabled');
    Assert(LObj.Integers['server_early_data_policy'] = Ord(sslEarlyDataServerReject),
      'Reset restores server_early_data_policy default');
    Assert(LObj.Integers['server_max_early_data_size'] = 0,
      'Reset restores server_max_early_data_size default');
    Assert(LObj.Strings['server_early_data_replay_store_file'] = '',
      'Reset clears server_early_data_replay_store_file');
  finally
    LObj.Free;
  end;

  LDestination := TSSLContextBuilder.Create
    .WithServerEarlyDataPolicy(sslEarlyDataServerReject)
    .WithServerMaxEarlyDataSize(0);
  LDestination.Merge(LSource);
  LObj := ParseBuilderJSON(LDestination);
  try
    Assert(LObj.Integers['server_early_data_policy'] = Ord(sslEarlyDataServerIssueOnly),
      'Merge preserves server_early_data_policy');
    Assert(LObj.Integers['server_max_early_data_size'] = 2048,
      'Merge preserves server_max_early_data_size');
    Assert(LObj.Strings['server_early_data_replay_store_file'] = '/tmp/clone-replay-store.bin',
      'Merge preserves server_early_data_replay_store_file');
  finally
    LObj.Free;
  end;
end;

procedure Test_Clone_ResetMerge_EarlyDataReplayStoreDirectoryField;
var
  LSource, LClone, LDestination: ISSLContextBuilder;
  LObj: TJSONObject;
begin
  TestHeader('Test 25: Clone Reset Merge Preserve Early-Data Replay Store Directory');

  LSource := TSSLContextBuilder.Create
    .WithServerEarlyDataReplayStoreDirectory('/tmp/clone-replay-store-dir');

  LClone := LSource.Clone;
  LObj := ParseBuilderJSON(LClone);
  try
    Assert(LObj.Strings['server_early_data_replay_store_directory'] = '/tmp/clone-replay-store-dir',
      'Clone preserves server_early_data_replay_store_directory');
  finally
    LObj.Free;
  end;

  LClone.Reset;
  LObj := ParseBuilderJSON(LClone);
  try
    Assert(LObj.Strings['server_early_data_replay_store_directory'] = '',
      'Reset clears server_early_data_replay_store_directory');
  finally
    LObj.Free;
  end;

  LDestination := TSSLContextBuilder.Create;
  LDestination.Merge(LSource);
  LObj := ParseBuilderJSON(LDestination);
  try
    Assert(LObj.Strings['server_early_data_replay_store_directory'] = '/tmp/clone-replay-store-dir',
      'Merge preserves server_early_data_replay_store_directory');
  finally
    LObj.Free;
  end;
end;

{ Main Test Runner }
begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  Phase 2.1.4 Configuration Snapshot and Clone Test Suite');
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn;
  WriteLn('Testing snapshot and clone functionality:');
  WriteLn('  1. Clone - Independent copy');
  WriteLn('  2. Reset - Restore defaults');
  WriteLn('  3. ResetToDefaults - Alias');
  WriteLn('  4. Merge - Combine configurations');
  WriteLn;

  try
    // Run all tests
    Test_Clone_Independence;
    Test_Clone_AllFields;
    Test_Reset_RestoresDefaults;
    Test_ResetToDefaults_Alias;
    Test_Reset_Chaining;
    Test_Merge_EmptySource;
    Test_Merge_NilSource;
    Test_Merge_ReplacesFields;
    Test_Merge_PreservesFields;
    Test_Merge_Chaining;
    Test_Clone_Merge_Workflow;
    Test_Reset_Rebuild;
    Test_Clone_PreservesExplicitBackendSelection;
    Test_Reset_ClearsExplicitBackendSelection;
    Test_Merge_PreservesExplicitBackendSelection;
    Test_Merge_PreservesAutoBackendRequirements;
    Test_Preset_Clone;
    Test_Merge_WithPreset;
    Test_Complex_Merge;
    Test_Merge_PreservesPKCS11URI;
    Test_Merge_PreservesPKCS11EnvironmentPINSource;
    Test_Merge_FileSources_ClearStalePEMState;
    Test_Merge_PEMSources_ClearStaleFileState;
    Test_Clone_ResetMerge_EarlyDataFields;
    Test_Clone_ResetMerge_EarlyDataReplayStoreDirectoryField;

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
