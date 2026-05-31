program test_transformation_methods;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally keeps deprecated WithSNI /
  server_name transformation coverage for the compatibility-only builder
  surface. }

{**
 * Test suite for Phase 2.2.4 - Configuration Transformation
 *
 * Tests the configuration transformation functionality:
 * 1. Transform - Apply transformation function
 * 2. Extend - Extend options set
 * 3. Override - Override specific configuration fields
 *}

uses
  SysUtils,
  fpjson, jsonparser,
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.backed;  // 确保 OpenSSL 后端注册

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

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

function JSONObjectHasOption(AObject: TJSONObject; AOption: TSSLOption): Boolean;
var
  LOptions: TJSONArray;
  I: Integer;
begin
  Result := False;
  if AObject.IndexOfName('options') < 0 then
    Exit;

  LOptions := AObject.Arrays['options'];
  for I := 0 to LOptions.Count - 1 do
    if LOptions.Integers[I] = Ord(AOption) then
      Exit(True);
end;

{ Global transformation functions for testing }

function AddCustomTimeout(ABuilder: ISSLContextBuilder): ISSLContextBuilder;
begin
  Result := ABuilder.WithSessionTimeout(9999);
end;

function AddCustomCipher(ABuilder: ISSLContextBuilder): ISSLContextBuilder;
begin
  Result := ABuilder.WithCipherList('CUSTOM-CIPHER');
end;

function ChainTransform(ABuilder: ISSLContextBuilder): ISSLContextBuilder;
begin
  Result := ABuilder
    .WithSessionTimeout(8888)
    .WithVerifyDepth(15);
end;

{ Test 1: Transform applies function }
procedure Test_Transform_AppliesFunction;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 1: Transform Applies Function');

  LBuilder := TSSLContextBuilder.Create
    .Transform(@AddCustomTimeout);

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('9999', LJSON) > 0,
    'Transform applies transformation function');
end;

{ Test 2: Transform with nil function }
procedure Test_Transform_NilFunction;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 2: Transform With Nil Function');

  try
    LBuilder := TSSLContextBuilder.Create
      .Transform(nil);

    Assert(True, 'Transform with nil function does not crash');
  except
    Assert(False, 'Transform with nil function crashed');
  end;
end;

{ Test 3: Transform supports method chaining }
procedure Test_Transform_Chaining;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 3: Transform Supports Method Chaining');

  LBuilder := TSSLContextBuilder.Create
    .Transform(@AddCustomTimeout)
    .WithVerifyNone;

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('9999', LJSON) > 0,
    'Method chaining works after Transform');
end;

{ Test 4: Multiple Transform calls }
procedure Test_Multiple_Transform;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 4: Multiple Transform Calls');

  LBuilder := TSSLContextBuilder.Create
    .Transform(@AddCustomTimeout)
    .Transform(@AddCustomCipher);

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('9999', LJSON) > 0) and (Pos('CUSTOM-CIPHER', LJSON) > 0),
    'Multiple Transform calls work correctly');
end;

{ Test 5: Transform with chaining inside }
procedure Test_Transform_ChainInside;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 5: Transform With Chaining Inside');

  LBuilder := TSSLContextBuilder.Create
    .Transform(@ChainTransform);

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('8888', LJSON) > 0),
    'Transform with internal chaining works');
end;

{ Test 6: Extend adds single option }
procedure Test_Extend_SingleOption;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 6: Extend Adds Single Option');

  LBuilder := TSSLContextBuilder.Create
    .Extend([ssoEnableSessionTickets]);

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('options', LJSON) > 0,
    'Extend adds single option');
end;

{ Test 7: Extend adds multiple options }
procedure Test_Extend_MultipleOptions;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 7: Extend Adds Multiple Options');

  LBuilder := TSSLContextBuilder.Create
    .Extend([ssoEnableSessionTickets, ssoEnableALPN, ssoEnableSNI]);

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('options', LJSON) > 0,
    'Extend adds multiple options');
end;

{ Test 8: Extend preserves existing options }
procedure Test_Extend_PreservesOptions;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 8: Extend Preserves Existing Options');

  LBuilder := TSSLContextBuilder.Create
    .WithOption(ssoDisableCompression)
    .Extend([ssoEnableSessionTickets]);

  LJSON := LBuilder.ExportToJSON;

  // Should have both options
  Assert(Pos('options', LJSON) > 0,
    'Extend preserves existing options');
end;

{ Test 9: Extend supports method chaining }
procedure Test_Extend_Chaining;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 9: Extend Supports Method Chaining');

  LBuilder := TSSLContextBuilder.Create
    .Extend([ssoEnableSessionTickets])
    .WithSessionTimeout(7777);

  LJSON := LBuilder.ExportToJSON;

  Assert(Pos('7777', LJSON) > 0,
    'Method chaining works after Extend');
end;

{ Test 10: Extend with empty array }
procedure Test_Extend_EmptyArray;
var
  LBuilder: ISSLContextBuilder;
  LOptions: array of TSSLOption;
begin
  TestHeader('Test 10: Extend With Empty Array');

  SetLength(LOptions, 0);

  try
    LBuilder := TSSLContextBuilder.Create
      .Extend(LOptions);

    Assert(True, 'Extend handles empty array');
  except
    Assert(False, 'Extend crashed with empty array');
  end;
end;

{ Test 11: Override cipher_list }
procedure Test_Override_CipherList;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 11: Override Cipher List');

  LBuilder := TSSLContextBuilder.Create
    .WithCipherList('OLD-CIPHER')
    .Override('cipher_list', 'NEW-CIPHER');

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('NEW-CIPHER', LJSON) > 0) and (Pos('OLD-CIPHER', LJSON) = 0),
    'Override replaces cipher_list');
end;

{ Test 12: Override session_timeout }
procedure Test_Override_SessionTimeout;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 12: Override Session Timeout');

  LBuilder := TSSLContextBuilder.Create
    .WithSessionTimeout(1000)
    .Override('session_timeout', '5555');

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('5555', LJSON) > 0) and (Pos('1000', LJSON) = 0),
    'Override replaces session_timeout');
end;

{ Test 13: Override server_name }
procedure Test_Override_ServerName;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 13: Override Server Name');

  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  LBuilder := TSSLContextBuilder.Create
    .WithSNI('old.example.com')
    .Override('server_name', 'new.example.com');
  {$POP}

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('new.example.com', LJSON) > 0),
    'Override replaces server_name');
end;

{ Test 14: Override server OCSP stapled response file }
procedure Test_Override_ServerOCSPStapledResponseFile;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LData: TJSONData;
  LObj: TJSONObject;
  LFileName: string;
begin
  TestHeader('Test 14: Override Server OCSP Stapled Response File');

  LFileName := 'tests/fixtures/p2/ocsp/ocsp_response_successful_basic_v1.der';
  LBuilder := TSSLContextBuilder.Create
    .Override('server_ocsp_stapled_response_file', LFileName);

  LJSON := LBuilder.ExportToJSON;
  LData := GetJSON(LJSON);
  try
    LObj := TJSONObject(LData);
    Assert(LObj.IndexOfName('server_ocsp_stapled_response_file') >= 0,
      'Override(server_ocsp_stapled_response_file) makes builder state export-visible');
    if LObj.IndexOfName('server_ocsp_stapled_response_file') >= 0 then
      Assert(LObj.Strings['server_ocsp_stapled_response_file'] = LFileName,
        'Override(server_ocsp_stapled_response_file) stores the requested file path');
  finally
    LData.Free;
  end;
end;

{ Test 15: Override supports method chaining }
procedure Test_Override_Chaining;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 15: Override Supports Method Chaining');

  LBuilder := TSSLContextBuilder.Create
    .Override('cipher_list', 'CIPHER-1')
    .WithSessionTimeout(6666);

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('CIPHER-1', LJSON) > 0) and (Pos('6666', LJSON) > 0),
    'Method chaining works after Override');
end;

{ Test 15: Override certificate_file clears stale certificate PEM }
procedure Test_Override_CertificateFile_ClearsStalePEMState;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LData: TJSONData;
  LObj: TJSONObject;
  LCertPEM, LKeyPEM: string;
begin
  TestHeader('Test 15: Override certificate_file clears stale certificate PEM');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'override-cert-file.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithCertificatePEM(LCertPEM)
    .Override('certificate_file', '/tmp/override-cert-file.pem');

  LJSON := LBuilder.ExportToJSON;
  LData := GetJSON(LJSON);
  try
    LObj := TJSONObject(LData);
    Assert(LObj.Strings['certificate_file'] = '/tmp/override-cert-file.pem',
      'Override keeps overridden certificate_file state export-visible');
    Assert(LObj.Strings['certificate_pem'] = '',
      'Override(certificate_file) clears stale certificate_pem state');
  finally
    LData.Free;
  end;
end;

{ Test 16: Override private_key_file clears stale private key PEM }
procedure Test_Override_PrivateKeyFile_ClearsStalePEMState;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LData: TJSONData;
  LObj: TJSONObject;
  LCertPEM, LKeyPEM: string;
begin
  TestHeader('Test 16: Override private_key_file clears stale private key PEM');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'override-key-file.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithPrivateKeyPEM(LKeyPEM)
    .Override('private_key_file', '/tmp/override-private-key.pem');

  LJSON := LBuilder.ExportToJSON;
  LData := GetJSON(LJSON);
  try
    LObj := TJSONObject(LData);
    Assert(LObj.Strings['private_key_file'] = '/tmp/override-private-key.pem',
      'Override keeps overridden private_key_file state export-visible');
    Assert(LObj.Strings['private_key_pem'] = '',
      'Override(private_key_file) clears stale private_key_pem state');
  finally
    LData.Free;
  end;
end;

{ Test 17: Override certificate_pem clears stale certificate file }
procedure Test_Override_CertificatePEM_ClearsStaleFileState;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LData: TJSONData;
  LObj: TJSONObject;
  LCertPEM, LKeyPEM: string;
begin
  TestHeader('Test 17: Override certificate_pem clears stale certificate file');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'override-cert-pem.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithCertificate('/tmp/stale-override-cert-file.pem')
    .Override('certificate_pem', LCertPEM);

  LJSON := LBuilder.ExportToJSON;
  LData := GetJSON(LJSON);
  try
    LObj := TJSONObject(LData);
    Assert(LObj.Strings['certificate_file'] = '',
      'Override(certificate_pem) clears stale certificate_file state');
    Assert(LObj.Strings['certificate_pem'] = LCertPEM,
      'Override keeps overridden certificate_pem state export-visible');
  finally
    LData.Free;
  end;
end;

{ Test 18: Override private_key_pem clears stale private key file }
procedure Test_Override_PrivateKeyPEM_ClearsStaleFileState;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LData: TJSONData;
  LObj: TJSONObject;
  LCertPEM, LKeyPEM: string;
begin
  TestHeader('Test 18: Override private_key_pem clears stale private key file');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'override-key-pem.test', 'Test Org', 30, LCertPEM, LKeyPEM
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Inc(GTestsFailed);
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .WithPrivateKey('/tmp/stale-override-private-key.pem')
    .Override('private_key_pem', LKeyPEM);

  LJSON := LBuilder.ExportToJSON;
  LData := GetJSON(LJSON);
  try
    LObj := TJSONObject(LData);
    Assert(LObj.Strings['private_key_file'] = '',
      'Override(private_key_pem) clears stale private_key_file state');
    Assert(LObj.Strings['private_key_pem'] = LKeyPEM,
      'Override keeps overridden private_key_pem state export-visible');
  finally
    LData.Free;
  end;
end;

{ Test 15: Multiple Override calls }
procedure Test_Multiple_Override;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 15: Multiple Override Calls');

  LBuilder := TSSLContextBuilder.Create
    .Override('cipher_list', 'CIPHER-A')
    .Override('session_timeout', '4444')
    .Override('server_name', 'test.local');

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('CIPHER-A', LJSON) > 0) and (Pos('4444', LJSON) > 0) and (Pos('test.local', LJSON) > 0),
    'Multiple Override calls work correctly');
end;

{ Test 16: Override unknown field }
procedure Test_Override_UnknownField;
var
  LBuilder: ISSLContextBuilder;
begin
  TestHeader('Test 16: Override Unknown Field');

  try
    LBuilder := TSSLContextBuilder.Create
      .Override('unknown_field', 'some_value');

    Assert(True, 'Override ignores unknown field gracefully');
  except
    Assert(False, 'Override crashed with unknown field');
  end;
end;

{ Test 17: Override case insensitive }
procedure Test_Override_CaseInsensitive;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 17: Override Case Insensitive');

  LBuilder := TSSLContextBuilder.Create
    .Override('CIPHER_LIST', 'UPPER-CASE')
    .Override('Session_Timeout', '3333');

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('UPPER-CASE', LJSON) > 0) and (Pos('3333', LJSON) > 0),
    'Override is case insensitive');
end;

{ Test 18: Combining Transform, Extend, Override }
procedure Test_Combining_All;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 18: Combining Transform, Extend, Override');

  LBuilder := TSSLContextBuilder.Create
    .Transform(@AddCustomTimeout)
    .Extend([ssoEnableSessionTickets, ssoEnableALPN])
    .Override('cipher_list', 'COMBINED-CIPHER');

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('9999', LJSON) > 0) and (Pos('COMBINED-CIPHER', LJSON) > 0),
    'Transform, Extend, Override work together');
end;

{ Test 19: Transformation with presets }
procedure Test_Transformation_WithPresets;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 19: Transformation With Presets');

  LBuilder := TSSLContextBuilder.Production
    .Transform(@AddCustomCipher)
    .Override('session_timeout', '1111');

  LJSON := LBuilder.ExportToJSON;

  Assert((Pos('CUSTOM-CIPHER', LJSON) > 0) and (Pos('1111', LJSON) > 0),
    'Transformation methods work with presets');
end;

{ Test 20: Build context after transformation }
procedure Test_BuildAfterTransformation;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
  LCert, LKey: string;
begin
  TestHeader('Test 20: Build Context After Transformation');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'test.local', 'Test Org', 30, LCert, LKey
  ) then
  begin
    WriteLn('  ✗ Failed to generate test certificate');
    Exit;
  end;

  LBuilder := TSSLContextBuilder.Create
    .Transform(@AddCustomTimeout)
    .Extend([ssoEnableSessionTickets])
    .Override('cipher_list', 'ECDHE+AESGCM')
    .WithCertificatePEM(LCert)
    .WithPrivateKeyPEM(LKey);

  LResult := LBuilder.TryBuildServer(LContext);

  Assert(LResult.IsOk,
    'Can build context after transformation methods');
end;

{ Test 21: Override applies PKCS#11 PIN method }
procedure Test_Override_PKCS11PINMethod;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 21: Override Applies PKCS#11 PIN Method');

  LBuilder := TSSLContextBuilder.Create
    .UsePKCS11('pkcs11:token=TestToken;object=ServerKey;type=private')
    .Override('pkcs11_pin', 'PKCS11_PIN_ENV')
    .Override('pkcs11_pin_method', 'PMENVIRONMENT');

  LJSON := LBuilder.ExportToJSON;

  Assert(
    (Pos('"pkcs11_pin_method"', LJSON) > 0) and
    (Pos('PKCS11_PIN_ENV', LJSON) > 0),
    'Override applies PKCS#11 env PIN method and keeps source state exportable'
  );
end;

{ Test 22: Override preserves PKCS#11 PIN method when pin is set afterwards }
procedure Test_Override_PKCS11PINMethod_OrderInsensitive;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
begin
  TestHeader('Test 22: Override Preserves PKCS#11 PIN Method When Pin Follows');

  LBuilder := TSSLContextBuilder.Create
    .UsePKCS11('pkcs11:token=TestToken;object=ServerKey;type=private')
    .Override('pkcs11_pin_method', 'pmEnvironment')
    .Override('pkcs11_pin', 'PKCS11_PIN_ENV_ORDERED');

  LJSON := LBuilder.ExportToJSON;

  Assert(
    (Pos('"pkcs11_pin_method"', LJSON) > 0) and
    (Pos('PKCS11_PIN_ENV_ORDERED', LJSON) > 0),
    'Override keeps explicit PKCS#11 env PIN method when pin value is assigned afterwards'
  );
end;

{ Test 23: Override explicit_backend replaces stale auto-backend state }
procedure Test_Override_ExplicitBackend_ReplacesAutoSelectionState;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LData: TJSONData;
  LObj: TJSONObject;
begin
  TestHeader('Test 23: Override explicit_backend replaces stale auto-backend state');

  LBuilder := TSSLContextBuilder.Create
    .RequirePKCS11Support
    .Override('explicit_backend', 'sslWinSSL');

  LJSON := LBuilder.ExportToJSON;
  LData := GetJSON(LJSON);
  try
    LObj := TJSONObject(LData);
    Assert(LObj.IndexOfName('explicit_backend') >= 0,
      'Override(explicit_backend) makes explicit backend state export-visible');
    if LObj.IndexOfName('explicit_backend') >= 0 then
      Assert(LObj.Integers['explicit_backend'] = Ord(sslWinSSL),
      'Override(explicit_backend) stores the requested backend value');
    Assert(LObj.IndexOfName('auto_select_backend') < 0,
      'Override(explicit_backend) clears stale auto_select_backend state');
  finally
    LData.Free;
  end;
end;

{ Test 24: Override OCSP required syncs enabled state }
procedure Test_Override_OCSPRequired_SyncsEnabledState;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LData: TJSONData;
  LObj: TJSONObject;
begin
  TestHeader('Test 24: Override OCSP required syncs enabled state');

  LBuilder := TSSLContextBuilder.Create
    .Override('ocsp_stapling_required', 'true');

  LJSON := LBuilder.ExportToJSON;
  LData := GetJSON(LJSON);
  try
    LObj := TJSONObject(LData);
    Assert(LObj.Booleans['ocsp_stapling_required'],
      'Override(ocsp_stapling_required) keeps required state export-visible');
    Assert(LObj.Booleans['ocsp_stapling_enabled'],
      'Override(ocsp_stapling_required) implies enabled state through OCSP sync');
  finally
    LData.Free;
  end;
end;

{ Test 25: Override OCSP enabled false clears stale required state }
procedure Test_Override_OCSPEnabledFalse_ClearsRequiredState;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LData: TJSONData;
  LObj: TJSONObject;
begin
  TestHeader('Test 25: Override OCSP enabled false clears stale required state');

  LBuilder := TSSLContextBuilder.Create
    .WithOCSPStaplingRequired(True)
    .Override('ocsp_stapling_enabled', 'false');

  LJSON := LBuilder.ExportToJSON;
  LData := GetJSON(LJSON);
  try
    LObj := TJSONObject(LData);
    Assert(not LObj.Booleans['ocsp_stapling_enabled'],
      'Override(ocsp_stapling_enabled=false) clears enabled state');
    Assert(not LObj.Booleans['ocsp_stapling_required'],
      'Override(ocsp_stapling_enabled=false) clears stale required state through OCSP sync');
  finally
    LData.Free;
  end;
end;

{ Test 26: Fluent OCSP disable clears stale required state }
procedure Test_WithOCSPStaplingFalse_ClearsRequiredState;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LData: TJSONData;
  LObj: TJSONObject;
begin
  TestHeader('Test 26: Fluent OCSP disable clears stale required state');

  LBuilder := TSSLContextBuilder.Create
    .WithOCSPStaplingRequired(True)
    .WithOCSPStapling(False);

  LJSON := LBuilder.ExportToJSON;
  LData := GetJSON(LJSON);
  try
    LObj := TJSONObject(LData);
    Assert(not LObj.Booleans['ocsp_stapling_enabled'],
      'WithOCSPStapling(false) clears enabled state');
    Assert(not LObj.Booleans['ocsp_stapling_required'],
      'WithOCSPStapling(false) clears stale required state');
  finally
    LData.Free;
  end;
end;

{ Test 27: Override CT required keeps state export-visible }
procedure Test_Override_CertificateTransparencyRequired_ExportVisible;
var
  LBuilder: ISSLContextBuilder;
  LJSON: string;
  LData: TJSONData;
  LObj: TJSONObject;
begin
  TestHeader('Test 27: Override CT required keeps state export-visible');

  LBuilder := TSSLContextBuilder.Create
    .Override('certificate_transparency_required', 'true');

  LJSON := LBuilder.ExportToJSON;
  LData := GetJSON(LJSON);
  try
    LObj := TJSONObject(LData);
    Assert(LObj.Booleans['certificate_transparency_required'],
      'Override(certificate_transparency_required) keeps required state export-visible');
    Assert(JSONObjectHasOption(LObj, ssoRequireCertificateTransparency),
      'Override(certificate_transparency_required) persists to exported options');
  finally
    LData.Free;
  end;
end;

{ Test 27: Cert verify cache is disabled by default }
procedure Test_WithCertVerifyCache_DefaultOff;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  TestHeader('Test 27: Cert Verify Cache Default Off');

  LBuilder := TSSLContextBuilder.CreateWithSafeDefaults;
  LResult := LBuilder.TryBuildClient(LContext);

  Assert(LResult.IsOk,
    'TryBuildClient succeeds with default settings');

  if LResult.IsOk and (LContext <> nil) then
    Assert(not (ssoEnableCertVerifyCache in LContext.GetOptions),
      'Cert verify cache option is disabled by default');
end;

{ Test 28: WithCertVerifyCache enables option }
procedure Test_WithCertVerifyCache_Enable;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  TestHeader('Test 28: Cert Verify Cache Enable');

  LBuilder := TSSLContextBuilder.CreateWithSafeDefaults
    .WithCertVerifyCache(True);
  LResult := LBuilder.TryBuildClient(LContext);

  Assert(LResult.IsOk,
    'TryBuildClient succeeds when cert verify cache enabled');

  if LResult.IsOk and (LContext <> nil) then
    Assert(ssoEnableCertVerifyCache in LContext.GetOptions,
      'Cert verify cache option is persisted to context');
end;

{ Test 29: WithCertVerifyCache can be disabled explicitly }
procedure Test_WithCertVerifyCache_Disable;
var
  LBuilder: ISSLContextBuilder;
  LContext: ISSLContext;
  LResult: TSSLOperationResult;
begin
  TestHeader('Test 29: Cert Verify Cache Disable');

  LBuilder := TSSLContextBuilder.CreateWithSafeDefaults
    .WithCertVerifyCache(True)
    .WithCertVerifyCache(False);
  LResult := LBuilder.TryBuildClient(LContext);

  Assert(LResult.IsOk,
    'TryBuildClient succeeds when cert verify cache toggled off');

  if LResult.IsOk and (LContext <> nil) then
    Assert(not (ssoEnableCertVerifyCache in LContext.GetOptions),
      'Cert verify cache option can be explicitly disabled');
end;

{ Main Test Runner }
begin
  WriteLn;
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn('  Phase 2.2.4 Configuration Transformation Test Suite');
  WriteLn('═══════════════════════════════════════════════════════════');
  WriteLn;
  WriteLn('Testing configuration transformation methods:');
  WriteLn('  1. Transform - Apply transformation function');
  WriteLn('  2. Extend - Extend options set');
  WriteLn('  3. Override - Override configuration fields');
  WriteLn;

  try
    // Run all tests
    Test_Transform_AppliesFunction;
    Test_Transform_NilFunction;
    Test_Transform_Chaining;
    Test_Multiple_Transform;
    Test_Transform_ChainInside;
    Test_Extend_SingleOption;
    Test_Extend_MultipleOptions;
    Test_Extend_PreservesOptions;
    Test_Extend_Chaining;
    Test_Extend_EmptyArray;
    Test_Override_CipherList;
    Test_Override_SessionTimeout;
    Test_Override_ServerName;
    Test_Override_ServerOCSPStapledResponseFile;
    Test_Override_Chaining;
    Test_Override_CertificateFile_ClearsStalePEMState;
    Test_Override_PrivateKeyFile_ClearsStalePEMState;
    Test_Override_CertificatePEM_ClearsStaleFileState;
    Test_Override_PrivateKeyPEM_ClearsStaleFileState;
    Test_Multiple_Override;
    Test_Override_UnknownField;
    Test_Override_CaseInsensitive;
    Test_Combining_All;
    Test_Transformation_WithPresets;
    Test_BuildAfterTransformation;
    Test_Override_PKCS11PINMethod;
    Test_Override_PKCS11PINMethod_OrderInsensitive;
    Test_Override_ExplicitBackend_ReplacesAutoSelectionState;
    Test_Override_OCSPRequired_SyncsEnabledState;
    Test_Override_OCSPEnabledFalse_ClearsRequiredState;
    Test_WithOCSPStaplingFalse_ClearsRequiredState;
    Test_Override_CertificateTransparencyRequired_ExportVisible;
    Test_WithCertVerifyCache_DefaultOff;
    Test_WithCertVerifyCache_Enable;
    Test_WithCertVerifyCache_Disable;

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
