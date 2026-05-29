program test_quick_all;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.quick,
  nextpas.core.tls.factory,
  nextpas.core.tls.cert.builder,
  fafafa.ssl;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('❌ FAIL: ', AMessage);
    // Halt(1); // Don't halt immediately, let's see more output if possible, or halt to fail fast.
    // Use Halt to match previous behavior but we need more info before calling check.
    Halt(1);
  end;
  WriteLn('✅ PASS: ', AMessage);
end;

procedure CheckStr(const AActual, AExpected, AMessage: string);
begin
  if AActual <> AExpected then
  begin
    WriteLn('❌ FAIL: ', AMessage);
    WriteLn('   Expected: ', AExpected);
    WriteLn('   Actual:   ', AActual);
    Halt(1);
  end;
  WriteLn('✅ PASS: ', AMessage);
end;

procedure TestSelfSigned;
var
  KP: IKeyPairWithCertificate;
  Cert: ICertificate;
begin
  WriteLn('--- Testing GenerateSelfSigned ---');
  KP := TSSLQuick.GenerateSelfSigned('quick.local', 30);
  Check(KP <> nil, 'KeyPair generated');
  
  Cert := KP.GetCertificate;
  Check(Cert <> nil, 'Certificate exists');
  // Check strict match is fragile due to defaults. Check CN presence.
  // Actual: C=US, ST=California, L=San Francisco, O=fafafa.ssl, OU=Development, CN=quick.local
  Check(Pos('CN=quick.local', Cert.GetSubject) > 0, 'Subject contains CN=quick.local');
  Check(not Cert.IsExpired, 'Certificate valid (not expired)');
  Check(Cert.GetIssuer = Cert.GetSubject, 'Issuer is Subject (Self-signed)');
end;

procedure TestServerCert;
var
  KP: IKeyPairWithCertificate;
  Cert: ICertificate;
  SANs: TStringArray;
  I: Integer;
  FoundApi, FoundDb: Boolean;
begin
  WriteLn('--- Testing GenerateServerCert with SANs ---');
  KP := TSSLQuick.GenerateServerCert('server.local', ['api.server.local', 'db.server.local']);
  Check(KP <> nil, 'KeyPair generated');
  
  Cert := KP.GetCertificate;
  Check(Cert <> nil, 'Certificate exists');
  Check(Pos('CN=server.local', Cert.GetSubject) > 0, 'Subject contains CN=server.local');
  
  SANs := Cert.GetSubjectAltNames;
  WriteLn('   Debug: SAN Count = ', Length(SANs));
  if Length(SANs) > 0 then
    WriteLn('   Debug: First SAN = ', SANs[0]);
    
  Check(Length(SANs) >= 2, 'SANs present');
  
  FoundApi := False;
  FoundDb := False;
  for I := Low(SANs) to High(SANs) do
  begin
    if Pos('api.server.local', SANs[I]) > 0 then FoundApi := True;
    if Pos('db.server.local', SANs[I]) > 0 then FoundDb := True;
  end;
  
  Check(FoundApi, 'SAN api.server.local found');
  Check(FoundDb, 'SAN db.server.local found');
end;

procedure TestCACert;
var
  KP: IKeyPairWithCertificate;
  Cert: ICertificate;
begin
  WriteLn('--- Testing GenerateCACert ---');
  KP := TSSLQuick.GenerateCACert('My Quick CA', 'Quick Corp');
  Check(KP <> nil, 'KeyPair generated');
  
  Cert := KP.GetCertificate;
  Check(Cert <> nil, 'Certificate exists');
  Check(Pos('O=Quick Corp', Cert.GetSubject) > 0, 'Subject contains Org');
  
  Check(Cert.IsCA, 'Basic Constraints CA=TRUE');
end;

procedure TestFileGeneration;
var
  CertPath, KeyPath: string;
begin
  WriteLn('--- Testing GenerateCertFiles ---');
  CertPath := 'temp_quick.crt';
  KeyPath := 'temp_quick.key';
  
  if FileExists(CertPath) then DeleteFile(CertPath);
  if FileExists(KeyPath) then DeleteFile(KeyPath);
  
  try
    Check(TSSLQuick.GenerateCertFiles('file.local', CertPath, KeyPath), 'GenerateCertFiles returned True');
    Check(FileExists(CertPath), 'Cert file created');
    Check(FileExists(KeyPath), 'Key file created');
    
    // Verify file content (basic check)
    // CreateCertificate returns ISSLCertificate, which is compatible here for checking LoadFromFile
    Check(TSSLFactory.CreateCertificate.LoadFromFile(CertPath), 'Cert file valid loadable');
    
  finally
    if FileExists(CertPath) then DeleteFile(CertPath);
    if FileExists(KeyPath) then DeleteFile(KeyPath);
  end;
end;

begin
  WriteLn('╔═══════════════════════════════════════════╗');
  WriteLn('║  TSSLQuick Comprehensive Tests            ║');
  WriteLn('╚═══════════════════════════════════════════╝');
  WriteLn;
  
  try
    TestSelfSigned;
    WriteLn;
    TestServerCert;
    WriteLn;
    TestCACert;
    WriteLn;
    TestFileGeneration;
    
    WriteLn;
    WriteLn('All Quick API Tests Passed Successfully!');
  except
    on E: Exception do
    begin
      WriteLn('❌ Unhandled Exception: ', E.Message);
      Halt(1);
    end;
  end;
end.
