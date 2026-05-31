program test_pkcs11_uri_pin_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  Classes,
  nextpas.core.tls.pkcs11.types,
  nextpas.core.tls.pkcs11.uri,
  nextpas.core.tls.pkcs11.pin,
  nextpas.core.tls.pkcs11.engine,
  nextpas.core.tls.pkcs11.api;

type
  TCallbackProvider = class
  public
    function ProvideValid(const ATokenLabel: string; out APIN: string): Boolean;
    function ProvideEmpty(const ATokenLabel: string; out APIN: string): Boolean;
  end;

function TCallbackProvider.ProvideValid(const ATokenLabel: string; out APIN: string): Boolean;
begin
  APIN := '1234';
  Result := True;
end;

function TCallbackProvider.ProvideEmpty(const ATokenLabel: string; out APIN: string): Boolean;
begin
  APIN := '';
  Result := True;
end;

procedure Fail(const AMessage: string);
begin
  WriteLn('❌ ', AMessage);
  Halt(1);
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

procedure AssertEqualInt(AExpected, AActual: Int64; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
end;

procedure AssertEqualStr(const AExpected, AActual, AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected="%s" actual="%s")', [AMessage, AExpected, AActual]));
end;

procedure TestConfigFromURIObjectIDConversion;
var
  LURI: TPKCS11URI;
  LConfig: TPKCS11Config;
begin
  WriteLn('--- Test: PKCS11 URI object id -> config key bytes');

  LURI := TPKCS11URIParser.Parse(
    'pkcs11:token=TestToken;object=TestKey;id=0102AB?module-path=/tmp/pkcs11.so');
  LConfig := TPKCS11ConfigFromURI(LURI);

  AssertEqualInt(3, Length(LConfig.KeyID),
    'Object ID hex should be converted into key bytes');
  if Length(LConfig.KeyID) = 3 then
  begin
    AssertEqualInt($01, LConfig.KeyID[0], 'KeyID[0] should match first byte');
    AssertEqualInt($02, LConfig.KeyID[1], 'KeyID[1] should match second byte');
    AssertEqualInt($AB, LConfig.KeyID[2], 'KeyID[2] should match third byte');
  end;

  WriteLn('✅ Object ID conversion contract verified');
end;

procedure TestURIGetPINFromFileSource;
var
  LURI: TPKCS11URI;
  LPINFile: string;
  LPIN: string;
  LFileStream: TFileStream;
  LData: AnsiString;
begin
  WriteLn('--- Test: PKCS11 URI pin-source=file');

  Randomize;
  LPINFile := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'pkcs11_pin_contract_' + IntToStr(Random(1000000)) + '.txt';

  LData := ' 2468 ' + LineEnding;
  LFileStream := TFileStream.Create(LPINFile, fmCreate);
  try
    LFileStream.WriteBuffer(Pointer(LData)^, Length(LData));
  finally
    LFileStream.Free;
  end;

  FillChar(LURI, SizeOf(LURI), 0);
  LURI.PINSource := 'file:' + LPINFile;

  try
    LPIN := LURI.GetPIN;
    AssertEqualStr('2468', LPIN,
      'PIN source file should be resolved and trimmed');
  finally
    DeleteFile(LPINFile);
  end;

  WriteLn('✅ PIN source file contract verified');
end;

procedure TestPINManagerRejectsEmptyCallbackPIN;
var
  LProvider: TCallbackProvider;
  LPIN: string;
begin
  WriteLn('--- Test: PIN callback must not return empty PIN');

  LProvider := TCallbackProvider.Create;
  try
    try
      LPIN := TPKCS11PINManager.GetPIN(pmCallback, '', @LProvider.ProvideEmpty, 'TestToken');
      Fail('Empty callback PIN must be rejected, got: "' + LPIN + '"');
    except
      on E: EPKCS11Exception do
      begin
        AssertEqualInt(CKR_PIN_INVALID, E.ReturnValue,
          'Empty callback PIN should raise CKR_PIN_INVALID');
      end;
    end;

    LPIN := TPKCS11PINManager.GetPIN(pmCallback, '', @LProvider.ProvideValid, 'TestToken');
    AssertEqualStr('1234', LPIN, 'Valid callback PIN should be accepted');
  finally
    LProvider.Free;
  end;

  WriteLn('✅ Callback PIN contract verified');
end;

procedure TestConfigInteractivePINUnsupported;
var
  LConfig: TPKCS11Config;
  LMessage: string;
begin
  WriteLn('--- Test: Config interactive PIN path should be explicit unsupported');

  LConfig := TPKCS11ConfigDefault;
  LConfig.PINMethod := pmInteractive;

  try
    LConfig.GetPIN;
    Fail('Interactive PIN path should raise EPKCS11Exception');
  except
    on E: EPKCS11Exception do
    begin
      AssertEqualInt(CKR_FUNCTION_NOT_SUPPORTED, E.ReturnValue,
        'Interactive PIN path should raise CKR_FUNCTION_NOT_SUPPORTED');
      LMessage := LowerCase(E.Message);
      AssertTrue(Pos('unsupported', LMessage) > 0,
        'Interactive PIN error message should include unsupported');
      AssertTrue(Pos('not implemented', LMessage) = 0,
        'Interactive PIN error message should not include not implemented');
    end;
    on E: Exception do
      Fail('Interactive PIN path should raise EPKCS11Exception, got: ' + E.Message);
  end;

  WriteLn('✅ Interactive PIN unsupported semantics verified');
end;

procedure TestPINManagerInteractiveUnsupportedContract;
var
  LMessage: string;
begin
  WriteLn('--- Test: PIN manager interactive path should be deterministic unsupported');

  try
    TPKCS11PINManager.GetPIN(pmInteractive, '', nil, 'TestToken');
    Fail('PIN manager interactive path should raise EPKCS11Exception');
  except
    on E: EPKCS11Exception do
    begin
      AssertEqualInt(CKR_FUNCTION_NOT_SUPPORTED, E.ReturnValue,
        'PIN manager interactive path should raise CKR_FUNCTION_NOT_SUPPORTED');
      LMessage := LowerCase(E.Message);
      AssertTrue(Pos('unsupported', LMessage) > 0,
        'PIN manager interactive error message should include unsupported');
      AssertTrue(Pos('not implemented', LMessage) = 0,
        'PIN manager interactive error message should not include not implemented');
    end;
    on E: Exception do
      Fail('PIN manager interactive path should raise EPKCS11Exception, got: ' + E.Message);
  end;

  WriteLn('✅ PIN manager interactive unsupported contract verified');
end;

procedure TestEngineCertificateLoadUnsupportedContract;
var
  LBackend: TEngineBackend;
  LConfig: TPKCS11Config;
  LModulePath: string;
  LFileStream: TFileStream;
  LMessage: string;
begin
  WriteLn('--- Test: ENGINE certificate loading should be explicit unsupported');

  Randomize;
  LModulePath := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'pkcs11_engine_dummy_module_' + IntToStr(Random(1000000)) + '.so';

  LFileStream := TFileStream.Create(LModulePath, fmCreate);
  try
    // keep file existing for ValidateConfig
  finally
    LFileStream.Free;
  end;

  LBackend := TEngineBackend.Create;
  try
    LConfig := TPKCS11ConfigDefault;
    LConfig.ModulePath := LModulePath;
    LConfig.TokenLabel := 'TestToken';
    LConfig.KeyLabel := 'TestKey';
    LConfig.LoginRequired := False;

    try
      LBackend.LoadCertificate(LConfig);
      Fail('ENGINE certificate loading should raise unsupported semantics');
    except
      on E: EPKCS11Exception do
      begin
        AssertEqualInt(CKR_FUNCTION_NOT_SUPPORTED, E.ReturnValue,
          'ENGINE certificate load should raise CKR_FUNCTION_NOT_SUPPORTED');
        LMessage := LowerCase(E.Message);
        AssertTrue(Pos('unsupported', LMessage) > 0,
          'ENGINE certificate load message should include unsupported');
        AssertTrue(Pos('not yet implemented', LMessage) = 0,
          'ENGINE certificate load message should not include not yet implemented');
      end;
      on E: Exception do
        Fail('ENGINE certificate load should raise EPKCS11Exception, got: ' + E.Message);
    end;
  finally
    LBackend.Free;
    DeleteFile(LModulePath);
  end;

  WriteLn('✅ ENGINE certificate unsupported contract verified');
end;

procedure TestInvalidObjectIDStructuredError;
var
  LURI: TPKCS11URI;
  LMessage: string;
begin
  WriteLn('--- Test: Invalid object id should raise structured PKCS11 error');

  LURI := TPKCS11URIParser.Parse('pkcs11:token=TestToken;object=TestKey;id=01GG?module-path=/tmp/pkcs11.so');

  try
    TPKCS11ConfigFromURI(LURI);
    Fail('Invalid object id should raise EPKCS11Exception');
  except
    on E: EPKCS11Exception do
    begin
      AssertEqualInt(CKR_ARGUMENTS_BAD, E.ReturnValue,
        'Invalid object id should map to CKR_ARGUMENTS_BAD');
      LMessage := LowerCase(E.Message);
      AssertTrue(Pos('object id', LMessage) > 0,
        'Invalid object id message should mention object id');
    end;
    on E: Exception do
      Fail('Invalid object id should raise EPKCS11Exception, got: ' + E.Message);
  end;

  WriteLn('✅ Invalid object id structured error verified');
end;

procedure TestInvalidPINSourceStructuredError;
var
  LURI: TPKCS11URI;
  LMessage: string;
begin
  WriteLn('--- Test: Invalid pin-source scheme should raise structured PKCS11 error');

  FillChar(LURI, SizeOf(LURI), 0);
  LURI.PINSource := 'prompt:token-ui';

  try
    LURI.GetPIN;
    Fail('Unsupported pin-source scheme should raise EPKCS11Exception');
  except
    on E: EPKCS11Exception do
    begin
      AssertEqualInt(CKR_ARGUMENTS_BAD, E.ReturnValue,
        'Unsupported pin-source scheme should map to CKR_ARGUMENTS_BAD');
      LMessage := LowerCase(E.Message);
      AssertTrue(Pos('unsupported', LMessage) > 0,
        'Unsupported pin-source message should include unsupported');
    end;
    on E: Exception do
      Fail('Unsupported pin-source should raise EPKCS11Exception, got: ' + E.Message);
  end;

  WriteLn('✅ Invalid pin-source structured error verified');
end;

begin
  WriteLn('PKCS11 URI/PIN contract tests');
  WriteLn('============================');

  TestConfigFromURIObjectIDConversion;
  TestURIGetPINFromFileSource;
  TestPINManagerRejectsEmptyCallbackPIN;
  TestConfigInteractivePINUnsupported;
  TestPINManagerInteractiveUnsupportedContract;
  TestEngineCertificateLoadUnsupportedContract;
  TestInvalidObjectIDStructuredError;
  TestInvalidPINSourceStructuredError;

  WriteLn('============================');
  WriteLn('✅ All PKCS11 URI/PIN contract tests passed');
end.
