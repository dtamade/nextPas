program test_openssl_blake2_ready_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  Dynlibs,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.blake2;

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

procedure ResetLoaderState;
begin
  UnloadBLAKE2Functions;
  TOpenSSLLoader.ResetModuleStates;
end;

function BLAKE2HashReady: Boolean;
begin
  Result := (((Assigned(BLAKE2b_Init) and Assigned(BLAKE2b_Update) and Assigned(BLAKE2b_Final)) or
             Assigned(BLAKE2b)) and
             ((Assigned(BLAKE2s_Init) and Assigned(BLAKE2s_Update) and Assigned(BLAKE2s_Final)) or
             Assigned(BLAKE2s)));
end;

function BLAKE2MACReady: Boolean;
begin
  Result := (((Assigned(BLAKE2b_Init_key) and Assigned(BLAKE2b_Update) and Assigned(BLAKE2b_Final)) or
             Assigned(BLAKE2b)) and
             ((Assigned(BLAKE2s_Init_key) and Assigned(BLAKE2s_Update) and Assigned(BLAKE2s_Final)) or
             Assigned(BLAKE2s)));
end;

function BLAKE2ModuleReady: Boolean;
begin
  Result := BLAKE2HashReady and BLAKE2MACReady;
end;

procedure TestBLAKE2LoadedStateMatchesHelperReadiness;
var
  LHandle: TLibHandle;
  LLoadResult: Boolean;
  LExpectedReady: Boolean;
begin
  ResetLoaderState;

  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
  if LHandle = NilHandle then
  begin
    Fail('Unable to load libcrypto for BLAKE2 contract test');
    Exit;
  end;

  LLoadResult := LoadBLAKE2Functions(LHandle);
  LExpectedReady := BLAKE2ModuleReady;

  Check(LLoadResult = LExpectedReady,
    'BLAKE2 load result matches hash/MAC helper readiness');
  Check(TOpenSSLLoader.IsModuleLoaded(osmBLAKE2) = LExpectedReady,
    'BLAKE2 loaded state matches hash/MAC helper readiness');

  UnloadBLAKE2Functions;
end;

begin
  TestBLAKE2LoadedStateMatchesHelperReadiness;

  WriteLn;
  WriteLn('Tests Passed: ', GTestsPassed);
  WriteLn('Tests Failed: ', GTestsFailed);

  if GTestsFailed > 0 then
    Halt(1);
end.
