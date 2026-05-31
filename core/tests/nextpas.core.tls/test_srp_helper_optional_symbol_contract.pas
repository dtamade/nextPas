program test_srp_helper_optional_symbol_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.srp;

var
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;

procedure AssertTrue(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  Inc(TotalTests);
  if ACondition then
  begin
    Inc(PassedTests);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(FailedTests);
    WriteLn('[FAIL] ', AName);
    if ADetail <> '' then
      WriteLn('       ', ADetail);
  end;
end;

procedure MarkSkip(const AName, AReason: string);
begin
  Inc(TotalTests);
  Inc(SkippedTests);
  WriteLn('[SKIP] [capability] ', AName, ' - ', AReason);
end;

procedure TestSRPCreateUserShouldReturnNilWhenOptionalSettersAreUnavailable;
var
  LUser: PSRP_user_pwd;
  LRaised: Boolean;
  LDetail: string;
begin
  WriteLn;
  WriteLn('=== SRPCreateUser optional setter guard ===');

  if not Assigned(SRP_user_pwd_new) or
     not Assigned(SRP_user_pwd_free) or
     not Assigned(SRP_create_verifier_BN) or
     not Assigned(SRP_get_default_gN) then
  begin
    MarkSkip('SRPCreateUser optional setter guard', 'required SRP helper prerequisites unavailable');
    Exit;
  end;

  if Assigned(SRP_user_pwd_set_salt) and Assigned(SRP_user_pwd_set_verifier) then
  begin
    MarkSkip('SRPCreateUser optional setter guard', 'deprecated setter symbols are available on this runtime');
    Exit;
  end;

  LUser := nil;
  LRaised := False;
  LDetail := '';

  try
    LUser := SRPCreateUser('contract-user', 'contract-password', '1024');
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  if LUser <> nil then
    SRP_user_pwd_free(LUser);

  AssertTrue(
    'SRPCreateUser should not raise when deprecated setter symbols are unavailable',
    not LRaised,
    LDetail
  );
  AssertTrue(
    'SRPCreateUser should return nil when deprecated setter symbols are unavailable',
    LUser = nil,
    'expected nil user when SRP_user_pwd_set_salt/set_verifier are unavailable'
  );
end;

begin
  WriteLn('========================================');
  WriteLn('SRP Helper Optional Symbol Contract Test');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('srp helper optional symbol contract', 'OpenSSL core unavailable');
    end
    else if not LoadSRP(GetCryptoLibHandle) then
    begin
      MarkSkip('srp helper optional symbol contract', 'SRP module unavailable on this runtime');
    end
    else
      TestSRPCreateUserShouldReturnNilWhenOptionalSettersAreUnavailable;

    WriteLn;
    WriteLn('========================================');
    WriteLn('Summary');
    WriteLn('========================================');
    WriteLn('Total tests: ', TotalTests);
    WriteLn('Passed: ', PassedTests);
    WriteLn('Failed: ', FailedTests);
    WriteLn('Skipped: ', SkippedTests);

    if FailedTests > 0 then
      Halt(1);
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
