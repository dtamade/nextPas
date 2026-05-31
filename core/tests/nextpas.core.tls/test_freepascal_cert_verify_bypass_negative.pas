program test_freepascal_cert_verify_bypass_negative;

{$mode ObjFPC}{$H+}

{ Negative-path tests proving the certificate-verification bypass is closed.

  The attack: forge a leaf whose issuer DN equals a trusted root's subject DN
  (public info), self-signed with the attacker's own key. A DN-only "verify"
  must NOT accept it — only a real cryptographic signature check should pass.

  We model this by generating TWO roots that share the same subject DN but
  have different keys: the REAL root (trusted) and an EVIL root (attacker).
  The leaf is signed by the EVIL key. FindBySubject will locate the REAL root
  by DN, but the leaf's signature only verifies against the EVIL key. }

uses
  SysUtils, Classes,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib,
  nextpas.core.tls.certchain;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPass);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFail);
  end;
end;

// Fixtures are pre-generated PEM files (see tests/certs/bypass/). Loading from
// disk — instead of generating at runtime via the OpenSSL-backed cert utils —
// keeps this test free of OpenSSL global-init leaks, matching the convention
// of the other zero-leak unit tests.
const
  FIXTURE_DIR = 'tests/certs/bypass/';

var
  GRealRootCertPEM: string;
  GForgedLeafCertPEM: string;
  GHonestLeafCertPEM: string;

function ReadTextFile(const APath: string): string;
var
  LStream: TFileStream;
  LBytes: TBytes;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    SetLength(LBytes, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(LBytes[0], LStream.Size);
    SetLength(Result, Length(LBytes));
    if Length(LBytes) > 0 then
      Move(LBytes[0], Result[1], Length(LBytes));
  finally
    LStream.Free;
  end;
end;

procedure LoadFixtures;
begin
  GRealRootCertPEM := ReadTextFile(FIXTURE_DIR + 'real_root.crt');
  GForgedLeafCertPEM := ReadTextFile(FIXTURE_DIR + 'forged_leaf.crt');
  GHonestLeafCertPEM := ReadTextFile(FIXTURE_DIR + 'honest_leaf.crt');
end;

function LoadCert(ALib: ISSLLibrary; const APEM: string): ISSLCertificate;
begin
  Result := ALib.CreateCertificate;
  if (Result = nil) or (not Result.LoadFromPEM(APEM)) then
    raise Exception.Create('Failed to load certificate from PEM');
end;
// Test 1+3: FreePascal store API must reject the forged leaf even though
// FindBySubject locates a same-DN trusted root.
procedure TestStoreAPIRejectsForgedLeaf(LLib: ISSLLibrary);
var
  LRealRoot, LForgedLeaf, LHonestLeaf: ISSLCertificate;
  LStore: ISSLCertificateStore;
begin
  WriteLn('--- Test: FreePascal store API rejects forged leaf ---');
  LRealRoot := LoadCert(LLib, GRealRootCertPEM);
  LForgedLeaf := LoadCert(LLib, GForgedLeafCertPEM);
  LHonestLeaf := LoadCert(LLib, GHonestLeafCertPEM);

  LStore := LLib.CreateCertificateStore;
  LStore.AddCertificate(LRealRoot);

  // Sanity: store CAN find an issuer by DN (discovery still works).
  Check('Store finds same-DN issuer by subject (discovery intact)',
    LStore.FindBySubject(LForgedLeaf.GetIssuer) <> nil);

  // Core: forged leaf must be rejected by every verification entry point.
  Check('Store.VerifyCertificate rejects forged leaf',
    not LStore.VerifyCertificate(LForgedLeaf));
  Check('Cert.Verify(store) rejects forged leaf',
    not LForgedLeaf.Verify(LStore));

  // Positive control: honestly-signed leaf must still verify.
  Check('Store.VerifyCertificate accepts honest leaf',
    LStore.VerifyCertificate(LHonestLeaf));
end;

// Test 2: ChainVerifier (trusted + intermediate store) must reject forged leaf.
procedure TestChainVerifierRejectsForgedLeaf(LLib: ISSLLibrary);
var
  LRealRoot, LForgedLeaf, LHonestLeaf: ISSLCertificate;
  LTrusted, LInter: ISSLCertificateStore;
  LVerifier: ISSLCertificateChainVerifier;
  LChain: TSSLCertificateArray;
  LResult: TChainVerifyResult;
begin
  WriteLn('--- Test: ChainVerifier rejects forged leaf ---');
  LRealRoot := LoadCert(LLib, GRealRootCertPEM);
  LForgedLeaf := LoadCert(LLib, GForgedLeafCertPEM);
  LHonestLeaf := LoadCert(LLib, GHonestLeafCertPEM);

  LTrusted := LLib.CreateCertificateStore;
  LTrusted.AddCertificate(LRealRoot);

  LVerifier := TSSLCertificateChainVerifier.Create;
  LVerifier.SetTrustedStore(LTrusted);

  // BuildChain may succeed (DN-based discovery), but VerifyChain must fail.
  if LVerifier.BuildChain(LForgedLeaf, LChain) then
  begin
    LResult := LVerifier.VerifyChain(LChain);
    Check('VerifyChain rejects forged-leaf chain (built via DN)',
      not LResult.IsValid);
  end
  else
    Check('Forged leaf rejected at BuildChain stage', True);

  // Intermediate-store variant: put real root only in intermediate store.
  LInter := LLib.CreateCertificateStore;
  LInter.AddCertificate(LRealRoot);
  LVerifier := TSSLCertificateChainVerifier.Create;
  LVerifier.SetIntermediateStore(LInter);
  if LVerifier.BuildChain(LForgedLeaf, LChain) then
  begin
    LResult := LVerifier.VerifyChain(LChain);
    Check('VerifyChain (intermediate store) rejects forged leaf',
      not LResult.IsValid);
  end
  else
    Check('Forged leaf rejected at BuildChain (intermediate store)', True);

  // Positive control: honest chain must validate.
  LTrusted := LLib.CreateCertificateStore;
  LTrusted.AddCertificate(LRealRoot);
  LVerifier := TSSLCertificateChainVerifier.Create;
  LVerifier.SetTrustedStore(LTrusted);
  if LVerifier.BuildChain(LHonestLeaf, LChain) then
  begin
    LResult := LVerifier.VerifyChain(LChain);
    Check('VerifyChain accepts honest chain (positive control)',
      LResult.IsValid);
  end
  else
    Check('Honest chain built successfully', False);
end;

var
  GLib: ISSLLibrary;
begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== Certificate Verification Bypass Negative Tests ===');
  GLib := TFreePascalSSLLibrary.Create;
  GLib.Initialize;
  try
    LoadFixtures;
    TestStoreAPIRejectsForgedLeaf(GLib);
    TestChainVerifierRejectsForgedLeaf(GLib);
  except
    on E: Exception do
    begin
      WriteLn('  [FAIL] Unhandled exception: ', E.ClassName, ': ', E.Message);
      Inc(GFail);
    end;
  end;
  GLib.Finalize;
  GLib := nil;
  // Release global PEM strings before program exit so heaptrc sees them freed.
  GRealRootCertPEM := '';
  GForgedLeafCertPEM := '';
  GHonestLeafCertPEM := '';
  WriteLn;
  WriteLn('Results: ', GPass, ' passed, ', GFail, ' failed');
  if GFail > 0 then Halt(1);
end.
