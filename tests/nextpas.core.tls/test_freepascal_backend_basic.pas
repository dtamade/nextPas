program test_freepascal_backend_basic;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  fafafa.ssl,
  nextpas.core.tls.factory,
  nextpas.core.tls.base;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('❌ ', AMessage);
    Halt(1);
  end;
end;

function ArrayContains(const AValues: TSSLStringArray; const AExpected: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(AValues) do
    if SameText(AValues[I], AExpected) then
      Exit(True);
end;

function BuildLooseDNQueryVariant(const AValue: string): string;
begin
  Result := Trim(AValue);
  Result := StringReplace(Result, ',', ' , ', [rfReplaceAll]);
  Result := StringReplace(Result, '=', ' = ', [rfReplaceAll]);
  Result := '  ' + LowerCase(Result) + '  ';
end;

var
  LAvailable: Boolean;
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LCaps: TSSLBackendCapabilities;
  LCert: ISSLCertificate;
  LKUCert: ISSLCertificate;
  LInvalidCert: ISSLCertificate;
  LHostCert: ISSLCertificate;
  LWildcardCert: ISSLCertificate;
  LLoopLeaf: ISSLCertificate;
  LChainIssuer: ISSLCertificate;
  LChain: TSSLCertificateArray;
  LInvalidStream: TStringStream;
  LValidDER: TBytes;
  LTruncatedDER: TBytes;
  LValidPEM: string;
  LWrongTypePEM: string;
  LKeyUsage: TSSLStringArray;
  LExtKeyUsage: TSSLStringArray;
  LStore: ISSLCertificateStore;
  LFilterStore: ISSLCertificateStore;
  LScanDir: string;
  LScanTxtPath: string;
  LScanPemPath: string;
  LConn: ISSLConnection;
  LStream: TMemoryStream;
  LBuf: array[0..7] of Byte;
  LRead: Integer;
  LWritten: Integer;
  LTLS12ClientCtx: ISSLContext;
  LTLS12ServerCtx: ISSLContext;
  LTLS12ClientConn: ISSLConnection;
  LTLS12ServerConn: ISSLConnection;
  LClientStream: TMemoryStream;
  LServerStream: TMemoryStream;
  LVerifyText: string;
  LSubjectVariant: string;
  LIssuerVariant: string;
  LSerialCompact: string;
  LSerialVariant: string;
  LFingerprintVariant: string;
  LCharIndex: Integer;
begin
  WriteLn('Testing FreePascal backend registration and creation...');

  LAvailable := TSSLFactory.IsLibraryAvailable(sslFreePascal);
  AssertTrue(LAvailable, 'sslFreePascal should be available');

  LLib := TSSLFactory.GetLibrary(sslFreePascal);
  AssertTrue(LLib <> nil, 'GetLibrary(sslFreePascal) should return library instance');
  AssertTrue(LLib.GetLibraryType = sslFreePascal, 'Library type mismatch');
  LVerifyText := LowerCase(LLib.GetVersionString);
  AssertTrue(Pos('freepascal', LVerifyText) > 0,
    'FreePascal backend version string should mention FreePascal');
  AssertTrue(Pos('skeleton', LVerifyText) = 0,
    'FreePascal backend version string should not expose skeleton placeholder');

  LCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LCtx <> nil, 'CreateContext should return context');
  AssertTrue(LCtx.GetContextType = sslCtxClient, 'Context type mismatch');

  LCert := LLib.CreateCertificate;
  AssertTrue(LCert <> nil, 'CreateCertificate should return certificate instance');
  AssertTrue(
    LCert.LoadFromFile('tests/certificate/test_certs/signer_cert.pem'),
    'FreePascal certificate should load PEM file'
  );
  AssertTrue(LCert.GetFingerprintSHA256 <> '',
    'Loaded certificate should expose SHA256 fingerprint');
  AssertTrue(LCert.GetPublicKey <> '',
    'Loaded certificate should expose non-empty public key info');
  AssertTrue(LCert.GetExtension('2.5.29.14') <> '',
    'Loaded certificate should expose Subject Key Identifier extension');

  LInvalidCert := LLib.CreateCertificate;
  AssertTrue(LInvalidCert <> nil, 'CreateCertificate should return invalid input check certificate instance');
  LInvalidStream := TStringStream.Create('not-a-certificate');
  try
    AssertTrue(not LInvalidCert.LoadFromStream(LInvalidStream),
      'FreePascal certificate should reject invalid stream data');
  finally
    LInvalidStream.Free;
  end;

  LValidDER := LCert.SaveToDER;
  AssertTrue(Length(LValidDER) > 16,
    'Loaded certificate should export DER bytes for truncated-input contract');
  SetLength(LTruncatedDER, Length(LValidDER) - 8);
  Move(LValidDER[0], LTruncatedDER[0], Length(LTruncatedDER));
  AssertTrue(not LInvalidCert.LoadFromDER(LTruncatedDER),
    'FreePascal certificate should reject truncated DER payload');

  LValidPEM := LCert.SaveToPEM;
  AssertTrue(LValidPEM <> '',
    'Loaded certificate should export PEM for invalid block-type contract');
  LWrongTypePEM := StringReplace(LValidPEM, '-----BEGIN CERTIFICATE-----',
    '-----BEGIN PUBLIC KEY-----', [rfReplaceAll]);
  LWrongTypePEM := StringReplace(LWrongTypePEM, '-----END CERTIFICATE-----',
    '-----END PUBLIC KEY-----', [rfReplaceAll]);
  AssertTrue(not LInvalidCert.LoadFromPEM(LWrongTypePEM),
    'FreePascal certificate should reject PEM payload without CERTIFICATE block type');

  LScanDir := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'fafafa_fp_store_scan_' + IntToStr(Int64(GetTickCount64));
  AssertTrue(ForceDirectories(LScanDir),
    'Temporary directory for LoadFromPath filtering contract should be created');

  LScanTxtPath := IncludeTrailingPathDelimiter(LScanDir) + 'renamed_cert.txt';
  with TStringList.Create do
  try
    Text := LValidPEM;
    SaveToFile(LScanTxtPath);
  finally
    Free;
  end;

  LFilterStore := LLib.CreateCertificateStore;
  AssertTrue(LFilterStore <> nil,
    'CreateCertificateStore should return instance for path filtering contract');
  AssertTrue(not LFilterStore.LoadFromPath(LScanDir),
    'LoadFromPath should ignore non-certificate extension files');
  AssertTrue(LFilterStore.GetCount = 0,
    'LoadFromPath should keep store empty when directory only contains non-certificate extension files');

  LScanPemPath := IncludeTrailingPathDelimiter(LScanDir) + 'renamed_cert.pem';
  with TStringList.Create do
  try
    Text := LValidPEM;
    SaveToFile(LScanPemPath);
  finally
    Free;
  end;

  LFilterStore := LLib.CreateCertificateStore;
  AssertTrue(LFilterStore <> nil,
    'CreateCertificateStore should return instance for positive path filtering contract');
  AssertTrue(LFilterStore.LoadFromPath(LScanDir),
    'LoadFromPath should load certificate files with PEM extension');
  AssertTrue(LFilterStore.GetCount = 1,
    'LoadFromPath should only load certificate files from mixed directory');

  DeleteFile(LScanTxtPath);
  DeleteFile(LScanPemPath);
  RemoveDir(LScanDir);

  LHostCert := LLib.CreateCertificate;
  AssertTrue(LHostCert <> nil, 'CreateCertificate should return SAN-vs-CN contract certificate instance');
  AssertTrue(
    LHostCert.LoadFromFile('tests/certificate/test_certs/san_cn_conflict_cert.pem'),
    'FreePascal certificate should load SAN/CN conflict fixture PEM file'
  );
  AssertTrue(not LHostCert.VerifyHostname('cn-only.example.com'),
    'Hostname verification should prioritize SAN over CN when SAN is present');
  AssertTrue(LHostCert.VerifyHostname('alt.example.com'),
    'Hostname verification should match SAN DNS entry');

  LWildcardCert := LLib.CreateCertificate;
  AssertTrue(LWildcardCert <> nil, 'CreateCertificate should return wildcard contract certificate instance');
  AssertTrue(
    LWildcardCert.LoadFromFile('tests/certificate/test_certs/san_wildcard_cert.pem'),
    'FreePascal certificate should load wildcard SAN fixture PEM file'
  );
  AssertTrue(LWildcardCert.VerifyHostname('api.example.com'),
    'Hostname verification should match single-label wildcard SAN');
  AssertTrue(not LWildcardCert.VerifyHostname('deep.api.example.com'),
    'Hostname verification wildcard should not match multi-label subdomain');

  LKUCert := LLib.CreateCertificate;
  AssertTrue(LKUCert <> nil, 'CreateCertificate should return KU/EKU fixture certificate instance');
  AssertTrue(
    LKUCert.LoadFromFile('tests/certificate/test_certs/keyusage_cert.pem'),
    'FreePascal certificate should load KU/EKU fixture PEM file'
  );

  LKeyUsage := LKUCert.GetKeyUsage;
  AssertTrue(Length(LKeyUsage) > 0,
    'KU fixture should expose non-empty key usage list');
  AssertTrue(ArrayContains(LKeyUsage, 'digitalSignature'),
    'KU fixture should include digitalSignature usage');
  AssertTrue(ArrayContains(LKeyUsage, 'keyEncipherment'),
    'KU fixture should include keyEncipherment usage');

  LExtKeyUsage := LKUCert.GetExtendedKeyUsage;
  AssertTrue(Length(LExtKeyUsage) > 0,
    'KU fixture should expose non-empty extended key usage list');
  AssertTrue(ArrayContains(LExtKeyUsage, 'serverAuth'),
    'KU fixture should include serverAuth extended usage');
  AssertTrue(ArrayContains(LExtKeyUsage, 'clientAuth'),
    'KU fixture should include clientAuth extended usage');

  LStore := LLib.CreateCertificateStore;
  AssertTrue(LStore <> nil, 'CreateCertificateStore should return store instance');
  AssertTrue(LStore.GetCount = 0, 'New certificate store should be empty');
  AssertTrue(LStore.AddCertificate(LCert), 'Certificate store should accept first certificate');
  AssertTrue(not LStore.AddCertificate(LCert), 'Certificate store should reject duplicate certificate references');
  AssertTrue(LStore.Contains(LCert.Clone),
    'Certificate store should treat cloned certificate with same fingerprint as contained');
  AssertTrue(not LStore.AddCertificate(LCert.Clone),
    'Certificate store should reject duplicate certificate fingerprints across cloned instances');
  AssertTrue(LStore.GetCount = 1, 'Certificate store count should be 1 after add');
  AssertTrue(LStore.GetCertificate(0) <> nil, 'Certificate store should return certificate by index');
  AssertTrue(LStore.FindByFingerprint(LCert.GetFingerprintSHA256) <> nil,
    'Certificate store should find certificate by fingerprint');
  LSerialCompact := StringReplace(StringReplace(UpperCase(LCert.GetFingerprintSHA256), ':', '', [rfReplaceAll]),
    ' ', '', [rfReplaceAll]);
  AssertTrue(LSerialCompact <> '',
    'Loaded certificate should expose fingerprint for normalized fingerprint query contract');
  LFingerprintVariant := '';
  for LCharIndex := 1 to Length(LSerialCompact) do
  begin
    if (LCharIndex > 1) and (((LCharIndex - 1) mod 2) = 0) then
      LFingerprintVariant := LFingerprintVariant + ':';
    LFingerprintVariant := LFingerprintVariant + LowerCase(LSerialCompact[LCharIndex]);
  end;
  LFingerprintVariant := '  ' + LFingerprintVariant + '  ';
  AssertTrue(LStore.FindByFingerprint(LFingerprintVariant) <> nil,
    'Certificate store should find certificate by normalized fingerprint query');

  LSubjectVariant := BuildLooseDNQueryVariant('CN=Test Signer,O=Test Org');
  AssertTrue(LStore.FindBySubject(LSubjectVariant) <> nil,
    'Certificate store should find certificate by normalized subject fragment query');
  AssertTrue(LStore.FindBySubject('') = nil,
    'Certificate store should return nil for empty subject query');

  LIssuerVariant := BuildLooseDNQueryVariant('CN=Test CA,O=Test CA');
  AssertTrue(LStore.FindByIssuer(LIssuerVariant) <> nil,
    'Certificate store should find certificate by normalized issuer fragment query');
  AssertTrue(LStore.FindByIssuer('') = nil,
    'Certificate store should return nil for empty issuer query');

  LSerialCompact := StringReplace(StringReplace(UpperCase(LCert.GetSerialNumber), ':', '', [rfReplaceAll]),
    ' ', '', [rfReplaceAll]);
  AssertTrue(LSerialCompact <> '',
    'Loaded certificate should expose serial for normalized serial query contract');
  LSerialVariant := '';
  for LCharIndex := 1 to Length(LSerialCompact) do
  begin
    if (LCharIndex > 1) and (((LCharIndex - 1) mod 2) = 0) then
      LSerialVariant := LSerialVariant + ':';
    LSerialVariant := LSerialVariant + LowerCase(LSerialCompact[LCharIndex]);
  end;
  LSerialVariant := '  ' + LSerialVariant + '  ';
  AssertTrue(LStore.FindBySerialNumber(LSerialVariant) <> nil,
    'Certificate store should find certificate by normalized serial query');

  AssertTrue(LStore.RemoveCertificate(LCert.Clone),
    'Certificate store should remove cloned certificate by matching fingerprint');
  AssertTrue(LStore.GetCount = 0,
    'Certificate store should be empty after removing cloned certificate match');
  AssertTrue(LStore.AddCertificate(LCert),
    'Certificate store should allow re-adding certificate after clone-based removal');

  LLoopLeaf := LCert.Clone;
  LChainIssuer := LLib.CreateCertificate;
  AssertTrue(LLoopLeaf <> nil, 'Leaf certificate clone should be created for chain issuer-link contract');
  AssertTrue(LChainIssuer <> nil, 'Issuer certificate should be created for chain issuer-link contract');
  AssertTrue(LChainIssuer.LoadFromFile('tests/certificate/test_certs/ca_cert.pem'),
    'Issuer fixture should load for chain issuer-link contract');
  LLoopLeaf.SetIssuerCertificate(LChainIssuer);
  LChain := LStore.BuildCertificateChain(LLoopLeaf);
  AssertTrue(Length(LChain) = 2,
    'BuildCertificateChain should follow explicit issuer-link when store lacks issuer certificate');
  AssertTrue(LChain[1] <> nil,
    'BuildCertificateChain should append issuer certificate from explicit issuer-link');
  AssertTrue(LChain[1].GetFingerprintSHA256 = LChainIssuer.GetFingerprintSHA256,
    'BuildCertificateChain should preserve explicit issuer certificate truth');

  if DirectoryExists('/etc/ssl/certs') then
    AssertTrue(LStore.LoadSystemStore,
      'LoadSystemStore should load certificates when Linux system store directory exists');

  LCaps := LLib.GetCapabilities;
  if DirectoryExists('/etc/ssl/certs') then
    AssertTrue(LCaps.SupportsSystemCertStore,
      'FreePascal capabilities should advertise system cert store support when Linux system store directory exists');
  AssertTrue(IsKeyExchangeSupported(LCaps, sslKexECDHE_RSA),
    'FreePascal backend should advertise ECDHE_RSA');
  AssertTrue(IsKeyExchangeSupported(LCaps, sslKexECDHE_ECDSA),
    'FreePascal backend should advertise ECDHE_ECDSA once pure ECDSA signer is available');
  AssertTrue(not LCaps.RequiresExternalLibrary,
    'FreePascal backend should not require external TLS library');
  AssertTrue(Pos('ECDSA', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop listing supported CertificateVerify algorithms as remaining issues');
  AssertTrue(Pos('PSK/RESUMPTION REMAIN IN PROGRESS', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop claiming PSK/resumption is entirely pending');
  AssertTrue(Pos('SERVER-SIDE RESUMPTION/PSK', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop listing server-side resumption/PSK once the server path closes');
  AssertTrue(Pos('RESUMPTION', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop listing implemented session-resumption details');
  AssertTrue(Pos('PSK', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop listing implemented PSK details');
  AssertTrue(Pos('0-RTT', UpperCase(LCaps.KnownIssues)) > 0,
    'FreePascal capability KnownIssues should still mention 0-RTT for experimental/support caveats');
  AssertTrue(LCaps.ZeroRTTSupport = sslSupportExperimental,
    'FreePascal capabilities should report experimental 0-RTT support once public early-data transport closes');
  AssertTrue(LCaps.EarlyDataSupport = sslSupportExperimental,
    'FreePascal capabilities should report experimental early-data support once public transport closes');
  AssertTrue(Pos('ANTI-REPLAY', UpperCase(LCaps.KnownIssues)) > 0,
    'FreePascal capability KnownIssues should mention conservative anti-replay limitations for experimental 0-RTT');
  AssertTrue(LCaps.SupportsCertificateTransparency,
    'FreePascal capabilities should advertise certificate-transparency support once client runtime surface is implemented');
  AssertTrue(LCaps.CertTransparencySupport = sslSupportExperimental,
    'FreePascal certificate-transparency support level should be experimental while remaining gaps are still bounded');
  AssertTrue(LLib.IsFeatureSupported(sslFeatCertificateTransparency),
    'FreePascal IsFeatureSupported should acknowledge certificate-transparency runtime support');
  AssertTrue(LCaps.SupportsOCSPStapling,
    'FreePascal capabilities should advertise OCSP stapling support once client runtime surface is implemented');
  AssertTrue(LCaps.OCSPStaplingSupport = sslSupportExperimental,
    'FreePascal OCSP stapling support level should be experimental while broader revocation gaps remain bounded');
  AssertTrue(LLib.IsFeatureSupported(sslFeatOCSPStapling),
    'FreePascal IsFeatureSupported should acknowledge OCSP stapling runtime support');
  AssertTrue(Pos('OCSP', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop listing OCSP as a remaining gap once server stapling closes');
  AssertTrue(Pos('SERVER-SIDE', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop listing server-side stapling as a remaining gap');
  AssertTrue(Pos('STAPLING', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop listing stapling issuance as a remaining gap');
  AssertTrue(Pos('ISSUANCE', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop listing issuance gaps once public closeout lands');
  AssertTrue(Pos('REVOCATION EVIDENCE MATERIAL', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop claiming revocation evidence material plumbing is still pending');
  AssertTrue(Pos('CRL-BACKED', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop listing CRL-backed client validation material as a remaining gap');
  AssertTrue(Pos('CERTIFICATE VALIDATION', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop using generic certificate-validation gap wording once client-side parity closes');
  AssertTrue(Pos('REMAINING GAPS INCLUDE OCSP STAPLING', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop listing OCSP stapling as a blanket remaining gap');
  AssertTrue(Pos('ONLINE OCSP FETCH PARITY', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop claiming online OCSP fetch parity is still missing');
  AssertTrue(Pos('OCSP STAPLING VALIDATION HARDENING', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop claiming OCSP stapling validation hardening is still pending');
  AssertTrue(Pos('BROADER OCSP VALIDATION HARDENING', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop claiming broader OCSP validation hardening is still pending once Batch 4 closes');
  AssertTrue(Pos('REMAINING GAPS INCLUDE OCSP STAPLING, CERTIFICATE TRANSPARENCY', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop listing OCSP stapling and Certificate Transparency as blanket remaining gaps');
  AssertTrue(Pos('OCSP-DELIVERED', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop claiming OCSP-delivered CT source parity is still missing');
  AssertTrue(Pos('TRANSPARENCY', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop mentioning Certificate Transparency once Batch 2 closes');
  AssertTrue(Pos('BROADER CERTIFICATE VALIDATION HARDENING', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should stop claiming broader certificate validation hardening is still pending once Batch 5 closes');
  AssertTrue(Pos('SHA384', UpperCase(LCaps.KnownIssues)) = 0,
    'FreePascal capability KnownIssues should no longer claim SHA384 Finished is pending');
  AssertTrue(LLib.IsCipherSupported('TLS_AES_256_GCM_SHA384'),
    'FreePascal IsCipherSupported should accept TLS_AES_256_GCM_SHA384 after SHA384 parity closes');
  AssertTrue(IsCipherSupported(LCaps, sslCipherAES256GCM),
    'FreePascal capability SupportedCiphers should advertise AES256GCM after SHA384 parity closes');

  LStream := TMemoryStream.Create;
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'CreateConnection(TStream) should return connection');

    FillChar(LBuf, SizeOf(LBuf), 0);

    LRead := LConn.Read(LBuf, SizeOf(LBuf));
    AssertTrue(LRead = -1, 'Read before handshake should fail');
    AssertTrue(LConn.GetError(-1) = sslErrProtocol,
      'Read before handshake should report protocol precondition error');

    LWritten := LConn.Write(LBuf, SizeOf(LBuf));
    AssertTrue(LWritten = -1, 'Write before handshake should fail');
    AssertTrue(LConn.GetError(-1) = sslErrProtocol,
      'Write before handshake should report protocol precondition error');

    AssertTrue(not LConn.Renegotiate,
      'Renegotiate before handshake should fail');
    AssertTrue(LConn.GetError(-1) = sslErrProtocol,
      'Renegotiate before handshake should report protocol precondition error');
  finally
    LStream.Free;
  end;

  LTLS12ClientCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LTLS12ClientCtx <> nil, 'TLS1.2 client context should be created');
  LTLS12ClientCtx.SetPreferredVersion(sslProtocolTLS12);

  LClientStream := TMemoryStream.Create;
  try
    LTLS12ClientConn := LTLS12ClientCtx.CreateConnection(LClientStream);
    AssertTrue(LTLS12ClientConn <> nil, 'TLS1.2 client connection should be created');
    AssertTrue(not LTLS12ClientConn.Connect, 'TLS1.2 client connect to empty stream should fail');
    AssertTrue(
      LTLS12ClientConn.GetError(-1) <> sslErrNone,
      'TLS1.2 client connect failure to empty stream should report an error');
  finally
    LTLS12ClientConn := nil;
    LClientStream.Free;
  end;

  LTLS12ServerCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LTLS12ServerCtx <> nil, 'TLS1.2 server context should be created');
  LTLS12ServerCtx.SetPreferredVersion(sslProtocolTLS12);

  LServerStream := TMemoryStream.Create;
  try
    LTLS12ServerConn := LTLS12ServerCtx.CreateConnection(LServerStream);
    AssertTrue(LTLS12ServerConn <> nil, 'TLS1.2 server connection should be created');
    AssertTrue(not LTLS12ServerConn.Accept, 'TLS1.2 server accept to empty stream should fail');
    AssertTrue(
      LTLS12ServerConn.GetError(-1) <> sslErrNone,
      'TLS1.2 server accept failure to empty stream should report an error');
  finally
    LTLS12ServerConn := nil;
    LServerStream.Free;
  end;

  WriteLn('✅ FreePascal backend basic checks passed');
end.
