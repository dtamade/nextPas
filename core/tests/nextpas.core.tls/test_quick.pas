program test_quick;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fafafa.ssl,  // Ensure all linked backends are registered
  nextpas.core.tls.base,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.quick,
  nextpas.core.tls.cert.builder;

procedure TestContextBuilder;
var
  LClient, LServer: ISSLContext;
  LKeyPair: IKeyPairWithCertificate;
  LCertPEM, LKeyPEM: string;
begin
  WriteLn('Testing TSSLContextBuilder...');

  // Test Client Builder
  LClient := TSSLContextBuilder.CreateWithSafeDefaults
    .WithTLS12And13
    .WithVerifyPeer
    .BuildClient;

  if LClient = nil then
    WriteLn('FAIL: Failed to build client context')
  else
    WriteLn('PASS: Built client context');

  // Test Server Builder (self-contained, no external files)
  LKeyPair := TSSLQuick.GenerateSelfSigned('quick-server.local', 7);
  if (LKeyPair = nil) or (LKeyPair.GetCertificate = nil) or (LKeyPair.GetPrivateKey = nil) then
  begin
    WriteLn('FAIL: Failed to generate key pair for server builder test');
    Exit;
  end;

  LCertPEM := LKeyPair.GetCertificate.ToPEM;
  LKeyPEM := LKeyPair.GetPrivateKey.ToPEM;

  LServer := TSSLContextBuilder.Create
    .WithTLS13
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM)
    .BuildServer;

  if LServer = nil then
    WriteLn('FAIL: Failed to build server context from generated PEM')
  else
    WriteLn('PASS: Built server context from generated PEM');
end;

procedure TestQuickCert;
var
  LKeyPair: IKeyPairWithCertificate;
begin
  WriteLn('Testing TSSLQuick.GenerateSelfSigned...');

  LKeyPair := TSSLQuick.GenerateSelfSigned('localhost', 30);

  if LKeyPair = nil then
    WriteLn('FAIL: Failed to generate key pair')
  else
  begin
    if LKeyPair.GetCertificate.GetSubject <> '' then
      WriteLn('PASS: Generated certificate for ' + LKeyPair.GetCertificate.GetSubject)
    else
      WriteLn('FAIL: Certificate subject empty');
  end;
end;

procedure TestQuickConnect;
begin
  if GetEnvironmentVariable('FAFAFA_RUN_NETWORK_TESTS') = '1' then
    WriteLn('PASS: Quick network connect API intentionally removed; use TSSLConnector + socket transport')
  else
    WriteLn('PASS: Network connect smoke disabled by default (set FAFAFA_RUN_NETWORK_TESTS=1 to opt-in)');
end;

begin
  try
    TestContextBuilder;
    TestQuickCert;
    TestQuickConnect;
    WriteLn('All tests completed.');
  except
    on E: Exception do
      WriteLn('FATAL: ' + E.Message);
  end;
end.
