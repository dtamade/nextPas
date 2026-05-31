program test_openssl_chain_issuer_selection;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.openssl.cert.builder,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.stack,
  nextpas.core.tls.openssl.x509.chain,
  fafafa.ssl;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('❌ FAIL: ', AMessage);
    Halt(1);
  end;
  WriteLn('✅ PASS: ', AMessage);
end;

function MustGetX509(const ACert: ICertificate): PX509;
var
  {$PUSH}
  {$WARN SYMBOL_DEPRECATED OFF}
  LEx: ICertificateEx;
  {$POP}
begin
  {$PUSH}
  {$WARN SYMBOL_DEPRECATED OFF}
  // ICertificateEx is deprecated but required for OpenSSL-specific testing
  if not Supports(ACert, ICertificateEx, LEx) then
  begin
    WriteLn('❌ FAIL: Certificate does not support ICertificateEx');
    Halt(1);
  end;

  Result := PX509(LEx.GetX509Handle);
  {$POP}
  if Result = nil then
  begin
    WriteLn('❌ FAIL: X509 handle is nil');
    Halt(1);
  end;
end;

function NewChain: PSTACK_OF_X509;
begin
  if not LoadStackFunctions then
  begin
    WriteLn('❌ FAIL: LoadStackFunctions failed');
    Halt(1);
  end;

  Result := PSTACK_OF_X509(CreateStack);
  if Result = nil then
  begin
    WriteLn('❌ FAIL: CreateStack returned nil');
    Halt(1);
  end;
end;

procedure FreeChain(AChain: PSTACK_OF_X509);
begin
  if AChain <> nil then
    FreeStack(POPENSSL_STACK(AChain));
end;

procedure PushCert(AChain: PSTACK_OF_X509; AX509: PX509);
begin
  if (AChain = nil) or (AX509 = nil) then
  begin
    WriteLn('❌ FAIL: PushCert got nil input');
    Halt(1);
  end;

  if not PushToStack(POPENSSL_STACK(AChain), AX509) then
  begin
    WriteLn('❌ FAIL: PushToStack failed');
    Halt(1);
  end;
end;

procedure Run;
var
  LLib: ISSLLibrary;
  LRootKP, LInterKP, LLeafKP: IKeyPairWithCertificate;
  LRootX509, LInterX509, LLeafX509: PX509;
  LChain: PSTACK_OF_X509;
  LIssuer: PX509;
begin
  // Ensure OpenSSL backend is initialized.
  LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  Check(LLib.Initialize, 'OpenSSL library initialized');

  // Build a small hierarchy: Root CA -> Intermediate CA -> Leaf.
  LRootKP := TCertificateBuilder.Create
    .WithCommonName('Root CA')
    .WithOrganization('Test Org')
    .ValidFor(3650)
    .WithRSAKey(2048)
    .AsCA
    .SelfSigned;

  LInterKP := TCertificateBuilder.Create
    .WithCommonName('Intermediate CA')
    .WithOrganization('Test Org')
    .ValidFor(3650)
    .WithRSAKey(2048)
    .AsCA
    .SignedBy(LRootKP.Certificate, LRootKP.PrivateKey);

  LLeafKP := TCertificateBuilder.Create
    .WithCommonName('leaf.test')
    .ValidFor(30)
    .WithRSAKey(2048)
    .AsServerCert
    .SignedBy(LInterKP.Certificate, LInterKP.PrivateKey);

  LRootX509 := MustGetX509(LRootKP.Certificate);
  LInterX509 := MustGetX509(LInterKP.Certificate);
  LLeafX509 := MustGetX509(LLeafKP.Certificate);

  // Case 1: [leaf, intermediate, root]
  LChain := NewChain;
  try
    PushCert(LChain, LLeafX509);
    PushCert(LChain, LInterX509);
    PushCert(LChain, LRootX509);

    LIssuer := FindIssuerX509InChain(LLeafX509, LChain);
    Check(LIssuer = LInterX509, 'issuer from [leaf, intermediate, root] = intermediate');
  finally
    FreeChain(LChain);
  end;

  // Case 2: [intermediate, root] (leaf omitted)
  LChain := NewChain;
  try
    PushCert(LChain, LInterX509);
    PushCert(LChain, LRootX509);

    LIssuer := FindIssuerX509InChain(LLeafX509, LChain);
    Check(LIssuer = LInterX509, 'issuer from [intermediate, root] = intermediate');
  finally
    FreeChain(LChain);
  end;

  // Case 3: [root] only (should not match leaf issuer)
  LChain := NewChain;
  try
    PushCert(LChain, LRootX509);

    LIssuer := FindIssuerX509InChain(LLeafX509, LChain);
    Check(LIssuer = nil, 'issuer from [root] is nil when leaf issuer is intermediate');
  finally
    FreeChain(LChain);
  end;

  // Case 4: self-signed leaf in chain should not select itself as issuer
  LChain := NewChain;
  try
    PushCert(LChain, LRootX509);

    LIssuer := FindIssuerX509InChain(LRootX509, LChain);
    Check(LIssuer = nil, 'self-signed leaf does not pick itself as issuer');
  finally
    FreeChain(LChain);
  end;
end;

begin
  try
    Run;
    WriteLn('All issuer selection tests passed.');
  except
    on E: Exception do
    begin
      WriteLn('❌ Unhandled exception: ', E.Message);
      Halt(1);
    end;
  end;
end.
