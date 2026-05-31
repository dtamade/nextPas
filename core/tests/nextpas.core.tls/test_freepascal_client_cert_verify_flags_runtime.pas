program test_freepascal_client_cert_verify_flags_runtime;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.tls13.serverhello,
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.tls.tls13.aead,
  nextpas.core.tls.crypto.x25519,
  nextpas.core.tls.tls13.finished,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.servercertificate,
  nextpas.core.tls.tls13.servercertverify,
  nextpas.core.tls.crypto.hash,
  nextpas.core.tls.freepascal.context.material;

type
  TServerMaterial = record
    CertificateBlob: TBytes;
    PrivateKeyBlob: TBytes;
  end;

const
  REVOCATION_TEST_SERIAL = 1001;

procedure Fail(const AMessage: string);
begin
  WriteLn('❌ ', AMessage);
  Halt(1);
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

procedure AssertEqualsInt(AExpected, AActual: Int64; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
end;

function HashTranscriptForSuite(ACipherSuite: Word; const ATranscriptData: TBytes): TBytes;
begin
  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(SHA256(ATranscriptData));
  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(SHA384(ATranscriptData));
  Result := nil;
end;

function BuildEncryptedExtensionsMessage: TBytes;
var
  LBody: TBytes;
begin
  SetLength(LBody, 0);
  AppendUInt16(LBody, 0);

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_ENCRYPTED_EXTENSIONS);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

function BuildFinishedMessage(
  ACipherSuite: Word;
  const AServerHandshakeTrafficSecret: TBytes;
  const ATranscriptData: TBytes
): TBytes;
var
  LVerifyData: TBytes;
begin
  LVerifyData := TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(
    ACipherSuite,
    AServerHandshakeTrafficSecret,
    HashTranscriptForSuite(ACipherSuite, ATranscriptData)
  );

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_FINISHED);
  AppendUInt24(Result, Length(LVerifyData));
  AppendBytes(Result, LVerifyData);
end;

function ReadFileBytes(const AFileName: string): TBytes;
var
  LStream: TFileStream;
begin
  Result := nil;
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(Result[0], LStream.Size);
  finally
    LStream.Free;
  end;
end;

function BytesToAnsiString(const AData: TBytes): AnsiString;
begin
  SetLength(Result, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], Result[1], Length(AData));
end;

function AnsiStringToBytes(const AValue: AnsiString): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], Length(AValue));
end;

function ContainsTextInsensitive(const AValue, ASubText: string): Boolean;
begin
  Result := Pos(LowerCase(ASubText), LowerCase(AValue)) > 0;
end;

function GetCertificateVerifyResult(const AConn: ISSLConnection): Integer;
var
  LCertVerify: ISSLCertificateVerification;
begin
  AssertTrue(Supports(AConn, ISSLCertificateVerification, LCertVerify),
    'Connection should expose certificate verification interface');
  Result := LCertVerify.GetVerifyResult;
end;

function GetCertificateVerifyResultString(const AConn: ISSLConnection): string;
var
  LCertVerify: ISSLCertificateVerification;
begin
  AssertTrue(Supports(AConn, ISSLCertificateVerification, LCertVerify),
    'Connection should expose certificate verification interface');
  Result := LCertVerify.GetVerifyResultString;
end;

function GenerateServerMaterial(
  const ACommonName: string;
  const ASANs: array of string;
  AExpired: Boolean;
  ASerialNumber: Int64 = 0
): TServerMaterial;
var
  LOptions: TCertGenOptions;
  LCACertPEM: string;
  LCAKeyPEM: string;
  LLeafCertPEM: string;
  LLeafKeyPEM: string;
  LCombinedPEM: AnsiString;
  I: Integer;
begin
  LCACertPEM := string(BytesToAnsiString(ReadFileBytes('tests/certificate/test_certs/ca_cert.pem')));
  LCAKeyPEM := string(BytesToAnsiString(ReadFileBytes('tests/certificate/test_certs/ca_key.pem')));

  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.CommonName := ACommonName;
  LOptions.Organization := 'fafafa.ssl-tests';
  LOptions.ValidDays := 30;
  LOptions.NotBefore := Now - 2;
  if ASerialNumber > 0 then
    LOptions.SerialNumber := ASerialNumber;
  if AExpired then
    LOptions.NotAfter := Now - 1
  else
    LOptions.NotAfter := Now + 30;
  LOptions.SubjectAltNames := TStringList.Create;
  try
    for I := Low(ASANs) to High(ASANs) do
      LOptions.SubjectAltNames.Add(ASANs[I]);

    if not TCertificateUtils.GenerateSigned(
      LOptions,
      LCACertPEM,
      LCAKeyPEM,
      LLeafCertPEM,
      LLeafKeyPEM
    ) then
      raise Exception.Create('GenerateSigned returned False for scripted server material');
  finally
    LOptions.SubjectAltNames.Free;
    LOptions.SubjectAltNames := nil;
  end;

  LCombinedPEM := AnsiString(LLeafCertPEM + LineEnding + LCACertPEM);
  Result.CertificateBlob := AnsiStringToBytes(LCombinedPEM);
  Result.PrivateKeyBlob := AnsiStringToBytes(AnsiString(LLeafKeyPEM));
end;

type
  TScriptedVerifyFlagsServerStream = class(TStream)
  private
    FCipherSuite: Word;
    FReadBuffer: TBytes;
    FReadPosition: Int64;
    FWriteStage: Integer;
    FTranscriptData: TBytes;
    FServerPrivateKey: TBytes;
    FServerPublicKey: TBytes;
    FHandshakeSecrets: TTLS13HandshakeSecrets;
    FCertificateBlob: TBytes;
    FPrivateKeyBlob: TBytes;

    procedure Enqueue(const AData: TBytes);
    procedure HandleClientHello(const AData: TBytes);
    procedure HandleClientFinished(const AData: TBytes);
  public
    constructor Create(const ACertificateBlob, APrivateKeyBlob: TBytes);

    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

constructor TScriptedVerifyFlagsServerStream.Create(const ACertificateBlob, APrivateKeyBlob: TBytes);
begin
  inherited Create;
  FCipherSuite := TLS13_CIPHER_CHACHA20_POLY1305_SHA256;
  SetLength(FReadBuffer, 0);
  FReadPosition := 0;
  FWriteStage := 0;
  SetLength(FTranscriptData, 0);
  InitTLS13HandshakeSecrets(FHandshakeSecrets);
  FCertificateBlob := Copy(ACertificateBlob, 0, Length(ACertificateBlob));
  FPrivateKeyBlob := Copy(APrivateKeyBlob, 0, Length(APrivateKeyBlob));
end;

procedure TScriptedVerifyFlagsServerStream.Enqueue(const AData: TBytes);
var
  LOldLen: Integer;
begin
  if Length(AData) = 0 then
    Exit;

  LOldLen := Length(FReadBuffer);
  SetLength(FReadBuffer, LOldLen + Length(AData));
  Move(AData[0], FReadBuffer[LOldLen], Length(AData));
end;

procedure TScriptedVerifyFlagsServerStream.HandleClientHello(const AData: TBytes);
var
  LHandshake: TBytes;
  LInfo: TTLS13ClientHelloInfo;
  LServerHello: TBytes;
  LServerHelloRecord: TBytes;
  LEncryptedExtensions: TBytes;
  LCertificateMessage: TBytes;
  LCertificateVerifyMessage: TBytes;
  LServerFinished: TBytes;
  LFlight: TBytes;
  LInnerPlaintext: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
  LSharedSecret: TBytes;
  LError: string;
  LSignatureScheme: Word;
  LTranscriptHash: TBytes;
  LCertVerifyInput: TBytes;
  LCertVerifySignature: TBytes;
begin
  if not TryExtractHandshakePayloadFromRecord(AData, LHandshake) then
    raise Exception.Create('Failed to extract ClientHello from record');
  if not TryParseTLS13ClientHelloFromHandshake(LHandshake, LInfo, LError) then
    raise Exception.Create('Failed to parse ClientHello: ' + LError);
  if not LInfo.HasKeyShare then
    raise Exception.Create('ClientHello missing key_share');

  GenerateX25519KeyPair(FServerPrivateKey, FServerPublicKey);
  LSharedSecret := X25519ComputeSharedSecret(FServerPrivateKey, LInfo.PeerKeyShare);

  LServerHello := BuildTLS13ServerHelloHandshake(
    LInfo.LegacySessionID,
    FCipherSuite,
    FServerPublicKey
  );
  LServerHelloRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, LServerHello);
  Enqueue(LServerHelloRecord);

  SetLength(FTranscriptData, Length(LHandshake) + Length(LServerHello));
  Move(LHandshake[0], FTranscriptData[0], Length(LHandshake));
  Move(LServerHello[0], FTranscriptData[Length(LHandshake)], Length(LServerHello));

  if not TryDeriveTLS13HandshakeSecrets(
    FCipherSuite,
    LSharedSecret,
    FTranscriptData,
    FHandshakeSecrets,
    LError
  ) then
    raise Exception.Create('Failed to derive handshake secrets: ' + LError);

  LEncryptedExtensions := BuildEncryptedExtensionsMessage;
  AppendBytes(FTranscriptData, LEncryptedExtensions);

  if not TryBuildTLS13ServerCertificateHandshake(FCertificateBlob, LCertificateMessage, LError) then
    raise Exception.Create('Failed to build TLS 1.3 Certificate message: ' + LError);
  AppendBytes(FTranscriptData, LCertificateMessage);

  if not TrySelectTLS13ServerCertificateVerifySchemeForKeyType(
    LInfo,
    'RSA',
    LSignatureScheme,
    LError
  ) then
    raise Exception.Create('Failed to select CertificateVerify scheme: ' + LError);

  LTranscriptHash := HashTranscriptForSuite(FCipherSuite, FTranscriptData);
  LCertVerifyInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);
  if not TryBuildTLS13CertificateVerifySignature(
    LSignatureScheme,
    FPrivateKeyBlob,
    LCertVerifyInput,
    LCertVerifySignature,
    LError
  ) then
    raise Exception.Create('Failed to sign CertificateVerify: ' + LError);

  LCertificateVerifyMessage := BuildTLS13CertificateVerifyHandshake(
    LSignatureScheme,
    LCertVerifySignature
  );
  AppendBytes(FTranscriptData, LCertificateVerifyMessage);

  LServerFinished := BuildFinishedMessage(
    FCipherSuite,
    FHandshakeSecrets.ServerHandshakeTrafficSecret,
    FTranscriptData
  );

  SetLength(LFlight, 0);
  AppendBytes(LFlight, LEncryptedExtensions);
  AppendBytes(LFlight, LCertificateMessage);
  AppendBytes(LFlight, LCertificateVerifyMessage);
  AppendBytes(LFlight, LServerFinished);
  LInnerPlaintext := BuildTLS13InnerPlaintext(LFlight, TLS_CONTENT_TYPE_HANDSHAKE);

  if not TryTLS13AEADEncrypt(
    FCipherSuite,
    FHandshakeSecrets.ServerHandshakeKey,
    BuildTLS13RecordNonce(FHandshakeSecrets.ServerHandshakeIV, 0),
    BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(FCipherSuite))),
    LInnerPlaintext,
    LEncrypted,
    LError
  ) then
    raise Exception.Create('Failed to encrypt server handshake flight: ' + LError);

  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
  Enqueue(LRecord);
  AppendBytes(FTranscriptData, LServerFinished);
  FWriteStage := 1;
end;

procedure TScriptedVerifyFlagsServerStream.HandleClientFinished(const AData: TBytes);
var
  LHeader: TTLSRecordHeader;
  LPayload: TBytes;
  LPlaintext: TBytes;
  LInnerFragment: TBytes;
  LInnerContentType: Byte;
  LError: string;
  LVerifyData: TBytes;
begin
  if not ParseTLSRecordHeader(AData, LHeader) then
    raise Exception.Create('Failed to parse client Finished record');
  if Length(AData) < 5 + LHeader.Length then
    raise Exception.Create('Client Finished record payload is truncated');
  SetLength(LPayload, LHeader.Length);
  if LHeader.Length > 0 then
    Move(AData[5], LPayload[0], LHeader.Length);

  if not TryTLS13AEADDecrypt(
    FCipherSuite,
    FHandshakeSecrets.ClientHandshakeKey,
    BuildTLS13RecordNonce(FHandshakeSecrets.ClientHandshakeIV, 0),
    BuildTLS13RecordAAD(LHeader.Length),
    LPayload,
    LPlaintext,
    LError
  ) then
    raise Exception.Create('Failed to decrypt client Finished: ' + LError);

  if not TryParseTLS13InnerPlaintext(LPlaintext, LInnerFragment, LInnerContentType) then
    raise Exception.Create('Invalid TLSInnerPlaintext for client Finished');
  if LInnerContentType <> TLS_CONTENT_TYPE_HANDSHAKE then
    raise Exception.Create('Client Finished record carried wrong inner content type');
  if (Length(LInnerFragment) < 4) or (LInnerFragment[0] <> TLS_HANDSHAKE_TYPE_FINISHED) then
    raise Exception.Create('Client Finished handshake missing');

  SetLength(LVerifyData, Length(LInnerFragment) - 4);
  if Length(LVerifyData) > 0 then
    Move(LInnerFragment[4], LVerifyData[0], Length(LVerifyData));
  if not TLS13VerifyFinishedForCipherSuite(
    FCipherSuite,
    FHandshakeSecrets.ClientHandshakeTrafficSecret,
    HashTranscriptForSuite(FCipherSuite, FTranscriptData),
    LVerifyData
  ) then
    raise Exception.Create('Client Finished verification failed in scripted server');

  FWriteStage := 2;
end;

function TScriptedVerifyFlagsServerStream.Read(var Buffer; Count: Longint): Longint;
var
  LAvailable: Int64;
begin
  if Count <= 0 then
    Exit(0);

  LAvailable := Length(FReadBuffer) - FReadPosition;
  if LAvailable <= 0 then
    Exit(0);

  if Count > LAvailable then
    Result := Longint(LAvailable)
  else
    Result := Count;

  Move(FReadBuffer[Integer(FReadPosition)], Buffer, Result);
  Inc(FReadPosition, Result);
end;

function TScriptedVerifyFlagsServerStream.Write(const Buffer; Count: Longint): Longint;
var
  LData: TBytes;
  LOffset, LRecLen: Integer;
begin
  SetLength(LData, Count);
  if Count > 0 then
    Move(Buffer, LData[0], Count);

  case FWriteStage of
    0: HandleClientHello(LData);
    1:
      begin
        LOffset := 0;
        while LOffset + 5 <= Length(LData) do
        begin
          LRecLen := (Integer(LData[LOffset + 3]) shl 8) or Integer(LData[LOffset + 4]);
          if LData[LOffset] = $17 then
          begin
            HandleClientFinished(Copy(LData, LOffset, 5 + LRecLen));
            Break;
          end;
          Inc(LOffset, 5 + LRecLen);
        end;
      end;
  end;

  Result := Count;
end;

function TScriptedVerifyFlagsServerStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning: FReadPosition := Offset;
    soCurrent: Inc(FReadPosition, Offset);
    soEnd: FReadPosition := Length(FReadBuffer) + Offset;
  end;
  Result := FReadPosition;
end;

function NewClientContext(const AVerifyFlags: TSSLCertVerifyFlags): ISSLContext;
begin
  Result := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(Result <> nil, 'FreePascal client context should be created');
  Result.SetPreferredVersion(sslProtocolTLS13);
  Result.SetVerifyMode([sslVerifyPeer]);
  Result.SetCertVerifyFlags(AVerifyFlags);
  Result.LoadCAFile('tests/certificate/test_certs/ca_cert.pem');
end;

function RequireRevocationMaterialSupport(AContext: ISSLContext): IFreePascalContextRevocationMaterial;
begin
  if not Supports(AContext, IFreePascalContextRevocationMaterial, Result) then
    Fail('FreePascal context should expose revocation material support');
end;

procedure TestHostnameMismatchFailsWithoutIgnoreFlag;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedVerifyFlagsServerStream;
begin
  LMaterial := GenerateServerMaterial(
    'cn-only.example.com',
    ['DNS:alt.example.com'],
    False
  );

  LCtx := NewClientContext([sslCertVerifyDefault]);
  LStream := TScriptedVerifyFlagsServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Hostname mismatch connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'Hostname mismatch should fail when ignore-hostname flag is absent');
    AssertEqualsInt(Ord(sslErrHostnameMismatch), GetCertificateVerifyResult(LConn),
      'Hostname mismatch should surface sslErrHostnameMismatch');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'hostname'),
      'Hostname mismatch should mention hostname in verify-result string'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestHostnameMismatchCanBeIgnored;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedVerifyFlagsServerStream;
begin
  LMaterial := GenerateServerMaterial(
    'cn-only.example.com',
    ['DNS:alt.example.com'],
    False
  );

  LCtx := NewClientContext([sslCertVerifyIgnoreHostname]);
  LStream := TScriptedVerifyFlagsServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Ignore-hostname connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn.Connect,
      'Ignore-hostname flag should allow scripted mismatch certificate to connect');
  finally
    LStream.Free;
  end;
end;

procedure TestExpiredCertificateFailsWithoutIgnoreFlag;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedVerifyFlagsServerStream;
begin
  LMaterial := GenerateServerMaterial(
    'example.com',
    ['DNS:example.com'],
    True
  );

  LCtx := NewClientContext([sslCertVerifyDefault]);
  LStream := TScriptedVerifyFlagsServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Expired-certificate connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'Expired certificate should fail when ignore-expiry flag is absent');
    AssertEqualsInt(Ord(sslErrCertificateExpired), GetCertificateVerifyResult(LConn),
      'Expired certificate should surface sslErrCertificateExpired');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'expired'),
      'Expired certificate should mention expiry in verify-result string'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestExpiredCertificateCanBeIgnored;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedVerifyFlagsServerStream;
begin
  LMaterial := GenerateServerMaterial(
    'example.com',
    ['DNS:example.com'],
    True
  );

  LCtx := NewClientContext([sslCertVerifyIgnoreExpiry]);
  LStream := TScriptedVerifyFlagsServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Ignore-expiry connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn.Connect,
      'Ignore-expiry flag should allow scripted expired certificate to connect');
  finally
    LStream.Free;
  end;
end;

procedure TestStrictChainFailsWhenLeafLacksServerAuthExtendedKeyUsage;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedVerifyFlagsServerStream;
begin
  LMaterial := GenerateServerMaterial(
    'example.com',
    ['DNS:example.com'],
    False
  );

  LCtx := NewClientContext([sslCertVerifyStrictChain]);
  LStream := TScriptedVerifyFlagsServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Strict-chain connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'Strict-chain flag should fail when the leaf certificate lacks serverAuth EKU');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'strict') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'serverauth') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'extended key usage'),
      'Strict-chain failure should mention strict-chain or serverAuth extended key usage'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestRevocationCheckFailsClosedWhenRevocationStatusIsUnavailable;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedVerifyFlagsServerStream;
begin
  LMaterial := GenerateServerMaterial(
    'example.com',
    ['DNS:example.com'],
    False
  );

  LCtx := NewClientContext([sslCertVerifyCheckRevocation]);
  LStream := TScriptedVerifyFlagsServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Revocation-check connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'Revocation-check flag should fail-closed when revocation status is unavailable');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'revocation') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'unavailable'),
      'Revocation-check failure should mention revocation status unavailability'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestCRLCheckFailsClosedWhenCRLStatusIsUnavailable;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedVerifyFlagsServerStream;
begin
  LMaterial := GenerateServerMaterial(
    'example.com',
    ['DNS:example.com'],
    False
  );

  LCtx := NewClientContext([sslCertVerifyCheckCRL]);
  LStream := TScriptedVerifyFlagsServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'CRL-check connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'CRL-check flag should fail-closed when CRL status is unavailable');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'crl') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'revocation'),
      'CRL-check failure should mention CRL or revocation'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestRevocationMaterialAllowsNonRevokedCertificate;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedVerifyFlagsServerStream;
  LRevocationMaterial: IFreePascalContextRevocationMaterial;
begin
  LMaterial := GenerateServerMaterial(
    'example.com',
    ['DNS:example.com'],
    False,
    REVOCATION_TEST_SERIAL
  );

  LCtx := NewClientContext([sslCertVerifyCheckRevocation]);
  LRevocationMaterial := RequireRevocationMaterialSupport(LCtx);
  LRevocationMaterial.AddCRLFile('tests/certificate/test_certs/revocation_nonmatching_crl.pem');
  LStream := TScriptedVerifyFlagsServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Revocation-material connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn.Connect,
      'Revocation-check flag should allow the connection when caller-provided CRL material does not revoke the peer cert');
  finally
    LStream.Free;
  end;
end;

procedure TestCRLMaterialFailsClosedWhenCertificateIsRevoked;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedVerifyFlagsServerStream;
  LRevocationMaterial: IFreePascalContextRevocationMaterial;
begin
  LMaterial := GenerateServerMaterial(
    'example.com',
    ['DNS:example.com'],
    False,
    REVOCATION_TEST_SERIAL
  );

  LCtx := NewClientContext([sslCertVerifyCheckCRL]);
  LRevocationMaterial := RequireRevocationMaterialSupport(LCtx);
  LRevocationMaterial.AddCRLFile('tests/certificate/test_certs/revocation_revoked_crl.pem');
  LStream := TScriptedVerifyFlagsServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'CRL-material connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'CRL-check flag should fail-closed when caller-provided CRL material revokes the peer cert');
    AssertEqualsInt(Ord(sslErrCertificateRevoked), GetCertificateVerifyResult(LConn),
      'Revoked CRL material should surface sslErrCertificateRevoked');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'revoked') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'crl'),
      'Revoked CRL material failure should mention revoked or CRL'
    );
  finally
    LStream.Free;
  end;
end;

begin
  WriteLn('Testing FreePascal client cert verify flags runtime parity...');

  TestHostnameMismatchFailsWithoutIgnoreFlag;
  TestHostnameMismatchCanBeIgnored;
  TestExpiredCertificateFailsWithoutIgnoreFlag;
  TestExpiredCertificateCanBeIgnored;
  TestStrictChainFailsWhenLeafLacksServerAuthExtendedKeyUsage;
  TestRevocationCheckFailsClosedWhenRevocationStatusIsUnavailable;
  TestCRLCheckFailsClosedWhenCRLStatusIsUnavailable;
  TestRevocationMaterialAllowsNonRevokedCertificate;
  TestCRLMaterialFailsClosedWhenCertificateIsRevoked;

  WriteLn('✅ FreePascal client cert verify flags runtime checks passed');
end.
