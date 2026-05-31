program test_openssl_loader_ready_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  Dynlibs,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.aes,
  nextpas.core.tls.openssl.api.sha,
  nextpas.core.tls.openssl.api.modes;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Fail(const AMessage: string);
begin
  Inc(GTestsFailed);
  WriteLn('[FAIL] ', AMessage);
end;

procedure Pass(const AMessage: string);
begin
  Inc(GTestsPassed);
  WriteLn('[PASS] ', AMessage);
end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
    Pass(AMessage)
  else
    Fail(AMessage);
end;

procedure CheckEqualsInt(AExpected, AActual: Integer; const AMessage: string);
begin
  Check(AExpected = AActual,
    Format('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
end;

function ModesRequiredReady: Boolean;
begin
  Result := Assigned(GCM128_new) and Assigned(GCM128_free) and
            Assigned(GCM128_setiv) and Assigned(GCM128_aad) and
            Assigned(GCM128_encrypt) and Assigned(GCM128_decrypt) and
            Assigned(GCM128_finish) and Assigned(GCM128_tag) and
            Assigned(CCM128_new) and Assigned(CCM128_free) and
            Assigned(CCM128_init) and Assigned(CCM128_setiv) and
            Assigned(CCM128_aad) and Assigned(CCM128_encrypt) and
            Assigned(CCM128_decrypt) and Assigned(CCM128_tag) and
            Assigned(XTS128_encrypt) and Assigned(XTS128_decrypt) and
            Assigned(OCB128_new) and Assigned(OCB128_free) and
            Assigned(OCB128_init) and Assigned(OCB128_setiv) and
            Assigned(OCB128_aad) and Assigned(OCB128_encrypt) and
            Assigned(OCB128_decrypt) and Assigned(OCB128_finish) and
            Assigned(OCB128_tag) and
            Assigned(AES_wrap_key) and Assigned(AES_unwrap_key);
end;

procedure ResetLoaderState;
begin
  UnloadAESFunctions;
  UnloadSHAFunctions;
  UnloadModesFunctions;
  TOpenSSLLoader.ResetModuleStates;
end;

procedure TestLoadFunctionsFailClosedForMissingRequiredSymbol;
var
  LHandle: TLibHandle;
  LLoadedCount: Integer;
  LPresent: Pointer = nil;
  LMissing: Pointer = nil;
  LMissingSymbol: AnsiString;
  LBindings: array[0..1] of TFunctionBinding;
begin
  WriteLn('[INFO] running loader required-symbol contract');
  ResetLoaderState;

  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
  if LHandle = NilHandle then
  begin
    Fail('Unable to load libcrypto for loader contract test');
    Exit;
  end;

  LMissingSymbol := 'fafafa_required_symbol_that_must_not_exist';

  LBindings[0].Name := 'AES_encrypt';
  LBindings[0].FuncPtr := @LPresent;
  LBindings[0].Required := True;

  LBindings[1].Name := PAnsiChar(LMissingSymbol);
  LBindings[1].FuncPtr := @LMissing;
  LBindings[1].Required := True;

  LLoadedCount := TOpenSSLLoader.LoadFunctions(LHandle, LBindings);

  CheckEqualsInt(-1, LLoadedCount,
    'LoadFunctions fails closed when a required symbol is missing');
  Check(not Assigned(LMissing),
    'LoadFunctions leaves missing required symbol as nil');
end;

procedure TestModesLoadedStateMatchesCriticalSymbolReadiness;
var
  LExpectedReady: Boolean;
  LLoadResult: Boolean;
begin
  WriteLn('[INFO] running modes readiness contract');
  ResetLoaderState;

  LLoadResult := LoadModesFunctions;
  LExpectedReady := ModesRequiredReady;

  Check(LLoadResult = LExpectedReady,
    'Modes load result matches critical symbol readiness');
  Check(TOpenSSLLoader.IsModuleLoaded(osmModes) = LExpectedReady,
    'Modes loaded state matches critical symbol readiness');

  UnloadModesFunctions;
end;

begin
  TestLoadFunctionsFailClosedForMissingRequiredSymbol;
  TestModesLoadedStateMatchesCriticalSymbolReadiness;

  WriteLn;
  WriteLn('Tests Passed: ', GTestsPassed);
  WriteLn('Tests Failed: ', GTestsFailed);

  if GTestsFailed > 0 then
    Halt(1);
end.
