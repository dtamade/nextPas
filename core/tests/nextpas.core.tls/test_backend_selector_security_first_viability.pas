program test_backend_selector_security_first_viability;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.backend.selector,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.freepascal.lib;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  PASS: ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

procedure TestHeader(const AName: string);
begin
  WriteLn;
  WriteLn('=== ', AName, ' ===');
end;

function SatisfiesSecurityFirstHardRequirements(
  const ACaps: TSSLBackendCapabilities;
  const AReq: TSSLRequirements
): Boolean;
begin
  Result :=
    (sslProtocolTLS13 in AReq.RequiredProtocols) and
    ACaps.SupportsTLS13 and
    ((AReq.RequiredCiphers * ACaps.SupportedCiphers) = AReq.RequiredCiphers) and
    ((AReq.RequiredHashes * ACaps.SupportedHashes) = AReq.RequiredHashes) and
    ((AReq.RequiredKeyExchanges * ACaps.SupportedKeyExchanges) = AReq.RequiredKeyExchanges);
end;

function FindBestEligibleSecurityScore(
  const AReq: TSSLRequirements;
  out ABestType: TSSLLibraryType;
  out ABestScore: Integer
): Boolean;
var
  LType: TSSLLibraryType;
  LLib: ISSLLibrary;
  LCaps: TSSLBackendCapabilities;
  LScore: Integer;
begin
  Result := False;
  ABestType := sslAutoDetect;
  ABestScore := -1;

  for LType := Low(TSSLLibraryType) to High(TSSLLibraryType) do
  begin
    if LType = sslAutoDetect then
      Continue;
    if not TSSLFactory.IsLibraryAvailable(LType) then
      Continue;

    LLib := TSSLFactory.GetLibrary(LType);
    LCaps := LLib.GetCapabilities;

    if not SatisfiesSecurityFirstHardRequirements(LCaps, AReq) then
      Continue;

    LScore := GetSecurityScore(LCaps);
    if (not Result) or (LScore > ABestScore) then
    begin
      Result := True;
      ABestType := LType;
      ABestScore := LScore;
    end;
  end;
end;

procedure Test_SecurityFirstThreshold_RemainsAttainable;
var
  LRequirements: TSSLRequirements;
  LBestEligibleType: TSSLLibraryType;
  LBestEligibleScore: Integer;
  LSelectedType: TSSLLibraryType;
  LMatchScore: Integer;
begin
  TestHeader('Security-first minimum score stays attainable');

  LRequirements := CreateSecurityFirstRequirements;

  Assert(
    FindBestEligibleSecurityScore(LRequirements, LBestEligibleType, LBestEligibleScore),
    'At least one available backend satisfies security-first hard protocol/algorithm requirements'
  );

  if LBestEligibleScore >= 0 then
  begin
    Assert(
      LRequirements.MinSecurityScore <= LBestEligibleScore,
      'Security-first minimum score does not exceed the best eligible backend security score'
    );

    Assert(
      SelectBestBackend(LRequirements, LSelectedType, LMatchScore),
      'Selector still returns a backend when the security-first hard requirements are satisfiable'
    );
  end;
end;

begin
  try
    Test_SecurityFirstThreshold_RemainsAttainable;

    WriteLn;
    WriteLn('Tests Passed: ', GTestsPassed);
    WriteLn('Tests Failed: ', GTestsFailed);

    if GTestsFailed > 0 then
      Halt(1);

    WriteLn('All tests passed.');
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
