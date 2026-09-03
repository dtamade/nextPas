program test_openssl_loader_required_symbol_contract;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.platform.dl,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.aes,
  nextpas.core.tls.openssl.api.sha,
  nextpas.core.tls.openssl.api.modes, nextpas.core.text.format;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Pass(const AMessage: string);
begin
  Inc(GTestsPassed);
  WriteLn('[PASS] ', AMessage);
end;

procedure Fail(const AMessage: string);
begin
  Inc(GTestsFailed);
  WriteLn('[FAIL] ', AMessage);
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
    TextFormat('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
end;

function LoadMismatchedLibrary: TPlatformLibrary;
var
  LPath: string;
begin
  Result := Default(TPlatformLibrary);
  LPath := ParamStr(1);
  if LPath <> '' then
  begin
    platform_dl_open(PAnsiChar(LPath), PLATFORM_DL_LAZY, Result);
    Exit;
  end;

  if platform_dl_open(PAnsiChar('libc.so.6'), PLATFORM_DL_LAZY, Result) <> 0 then
    platform_dl_open(PAnsiChar('libc.so'), PLATFORM_DL_LAZY, Result);
end;

procedure Test_LoadFunctions_FailsClosedWhenRequiredBindingMissing(
  ALibHandle: TPlatformLibrary);
var
  LExistingProc: Pointer;
  LMissingProc: Pointer;
  LBindings: array[0..1] of TFunctionBinding;
  LLoadedCount: Integer;
begin
  WriteLn('=== Required binding must fail closed ===');

  LExistingProc := nil;
  LMissingProc := nil;

  {$IFDEF WINDOWS}
  LBindings[0].Name := 'GetCurrentProcessId';
  {$ELSE}
  LBindings[0].Name := 'printf';
  {$ENDIF}
  LBindings[0].FuncPtr := @LExistingProc;
  LBindings[0].Required := False;

  LBindings[1].Name := 'nextpas_ssl_missing_required_symbol';
  LBindings[1].FuncPtr := @LMissingProc;
  LBindings[1].Required := True;

  LLoadedCount := TOpenSSLLoader.LoadFunctions(ALibHandle, LBindings);

  CheckEqualsInt(-1, LLoadedCount,
    'LoadFunctions reports failure when a required binding is missing');
  Check(not Assigned(LExistingProc),
    'LoadFunctions clears successfully bound optional symbols after required failure');
  Check(not Assigned(LMissingProc),
    'LoadFunctions keeps missing required symbol nil');
end;

procedure Test_AES_ModuleStaysUnloadedWhenRequiredSymbolsMissing(
  ALibHandle: TPlatformLibrary);
begin
  WriteLn('=== AES module should not publish loaded state before required symbols exist ===');

  UnloadAESFunctions;
  TOpenSSLLoader.ResetModuleStates;

  Check(not LoadAESFunctions(ALibHandle),
    'LoadAESFunctions fails on a library without required AES symbols');
  Check(not TOpenSSLLoader.IsModuleLoaded(osmAES),
    'AES module remains unloaded when required symbols are missing');
  Check(not Assigned(AES_set_encrypt_key),
    'AES_set_encrypt_key stays nil after failed AES load');
  Check(not Assigned(AES_encrypt),
    'AES_encrypt stays nil after failed AES load');
end;

procedure Test_SHA_ModuleStaysUnloadedWhenRequiredSymbolsMissing(
  ALibHandle: TPlatformLibrary);
begin
  WriteLn('=== SHA module should not publish loaded state before required symbols exist ===');

  UnloadSHAFunctions;
  TOpenSSLLoader.ResetModuleStates;

  Check(not LoadSHAFunctions(ALibHandle),
    'LoadSHAFunctions fails on a library without required SHA symbols');
  Check(not TOpenSSLLoader.IsModuleLoaded(osmSHA),
    'SHA module remains unloaded when required symbols are missing');
  Check(not Assigned(SHA256_Init),
    'SHA256_Init stays nil after failed SHA load');
  Check(not Assigned(SHA256_Final),
    'SHA256_Final stays nil after failed SHA load');
end;

procedure Test_Modes_ModuleStaysUnloadedWhenRequiredSymbolsMissing;
begin
  WriteLn('=== Modes module should not publish loaded state before required symbols exist ===');

  UnloadModesFunctions;
  TOpenSSLLoader.ResetModuleStates;

  Check(not LoadModesFunctions,
    'LoadModesFunctions fails on a libcrypto without required modes symbols');
  Check(not TOpenSSLLoader.IsModuleLoaded(osmModes),
    'Modes module remains unloaded when required symbols are missing');
end;

var
  LMismatchedHandle: TPlatformLibrary;
begin
  LMismatchedHandle := LoadMismatchedLibrary;
  if LMismatchedHandle.IsInvalid then
  begin
    WriteLn('Failed to load mismatched host library for contract test');
    Halt(1);
  end;

  try
    Test_LoadFunctions_FailsClosedWhenRequiredBindingMissing(LMismatchedHandle);
    Test_AES_ModuleStaysUnloadedWhenRequiredSymbolsMissing(LMismatchedHandle);
    Test_SHA_ModuleStaysUnloadedWhenRequiredSymbolsMissing(LMismatchedHandle);
    Test_Modes_ModuleStaysUnloadedWhenRequiredSymbolsMissing;
  finally
    UnloadAESFunctions;
    UnloadSHAFunctions;
    UnloadModesFunctions;
    TOpenSSLLoader.ResetModuleStates;
  end;

  WriteLn;
  WriteLn('Tests Passed: ', GTestsPassed);
  WriteLn('Tests Failed: ', GTestsFailed);

  if GTestsFailed > 0 then
    Halt(1);
end.
