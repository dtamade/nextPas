program test_freepascal_client_peer_certificate_surface;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
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
  nextpas.core.tls.crypto.hash;

// INTENTIONAL_CORE_SURFACE: this backend proof file intentionally keeps direct
// core GetPeerCertificateChain coverage as runtime proof. Generic
// ISSLCertificateVerification owner-path guidance is frozen elsewhere.
{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}

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

function BytesEqual(const ALeft, ARight: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);

  Result := True;
  for I := 0 to High(ALeft) do
    if ALeft[I] <> ARight[I] then
      Exit(False);
end;

function HashTranscriptForSuite(ACipherSuite: Word; const ATranscriptData: TBytes): TBytes;
begin
  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(SHA256(ATranscriptData));
  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(SHA384(ATranscriptData));
  SetLength(Result, 0);
end;

function BuildEncryptedExtensionsMessage: TBytes;
var
  LBody: TBytes;
begin
  SetLength(LBody, 0);
  AppendUInt16(LBody, 0);

  SetLength(Result, 0);
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

  SetLength(Result, 0);
  AppendByte(Result, TLS_HANDSHAKE_TYPE_FINISHED);
  AppendUInt24(Result, Length(LVerifyData));
  AppendBytes(Result, LVerifyData);
end;

function ReadFileBytes(const AFileName: string): TBytes;
var
  LStream: TFileStream;
begin
  SetLength(Result, 0);
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(Result[0], LStream.Size);
  finally
    LStream.Free;
  end;
end;

function BytesToString(const AData: TBytes): AnsiString;
begin
  SetLength(Result, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], Result[1], Length(AData));
end;

function BuildCertificateBlob: TBytes;
var
  LLeafPEM: TBytes;
  LIssuerPEM: TBytes;
  LCombined: AnsiString;
begin
  LLeafPEM := ReadFileBytes('tests/certificate/test_certs/signer_cert.pem');
  LIssuerPEM := ReadFileBytes('tests/certificate/test_certs/ca_cert.pem');
  LCombined := BytesToString(LLeafPEM) + LineEnding + BytesToString(LIssuerPEM);
  SetLength(Result, Length(LCombined));
  if Length(LCombined) > 0 then
    Move(LCombined[1], Result[0], Length(LCombined));
end;

type
  TScriptedPeerCertificateServerStream = class(TStream)
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
    constructor Create;

    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

constructor TScriptedPeerCertificateServerStream.Create;
begin
  inherited Create;
  FCipherSuite := TLS13_CIPHER_CHACHA20_POLY1305_SHA256;
  SetLength(FReadBuffer, 0);
  FReadPosition := 0;
  FWriteStage := 0;
  SetLength(FTranscriptData, 0);
  InitTLS13HandshakeSecrets(FHandshakeSecrets);
  FCertificateBlob := BuildCertificateBlob;
  FPrivateKeyBlob := ReadFileBytes('tests/certificate/test_certs/signer_key.pem');
end;

procedure TScriptedPeerCertificateServerStream.Enqueue(const AData: TBytes);
var
  LOldLen: Integer;
begin
  if Length(AData) = 0 then
    Exit;

  LOldLen := Length(FReadBuffer);
  SetLength(FReadBuffer, LOldLen + Length(AData));
  Move(AData[0], FReadBuffer[LOldLen], Length(AData));
end;

procedure TScriptedPeerCertificateServerStream.HandleClientHello(const AData: TBytes);
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

procedure TScriptedPeerCertificateServerStream.HandleClientFinished(const AData: TBytes);
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

function TScriptedPeerCertificateServerStream.Read(var Buffer; Count: Longint): Longint;
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

function TScriptedPeerCertificateServerStream.Write(const Buffer; Count: Longint): Longint;
var
  LData: TBytes;
begin
  SetLength(LData, Count);
  if Count > 0 then
    Move(Buffer, LData[0], Count);

  case FWriteStage of
    0: HandleClientHello(LData);
    1: HandleClientFinished(LData);
  end;

  Result := Count;
end;

function TScriptedPeerCertificateServerStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning: FReadPosition := Offset;
    soCurrent: Inc(FReadPosition, Offset);
    soEnd: FReadPosition := Length(FReadBuffer) + Offset;
  end;
  Result := FReadPosition;
end;

procedure TestPeerCertificateIsExposedAfterFullHandshake;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedPeerCertificateServerStream;
  LPeerCert: ISSLCertificate;
  LIssuerFromPeerCert: ISSLCertificate;
  LChain: TSSLCertificateArray;
  LExpectedLeaf: ISSLCertificate;
  LExpectedIssuer: ISSLCertificate;
begin
  LExpectedLeaf := TSSLFactory.CreateCertificate(sslFreePascal);
  AssertTrue(LExpectedLeaf <> nil, 'Expected leaf fixture certificate should be created');
  AssertTrue(
    LExpectedLeaf.LoadFromFile('tests/certificate/test_certs/signer_cert.pem'),
    'Expected leaf fixture certificate should load'
  );

  LExpectedIssuer := TSSLFactory.CreateCertificate(sslFreePascal);
  AssertTrue(LExpectedIssuer <> nil, 'Expected issuer fixture certificate should be created');
  AssertTrue(
    LExpectedIssuer.LoadFromFile('tests/certificate/test_certs/ca_cert.pem'),
    'Expected issuer fixture certificate should load'
  );

  LCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LCtx <> nil, 'FreePascal client context should be created');
  LCtx.SetPreferredVersion(sslProtocolTLS13);
  LCtx.SetVerifyMode([]);

  LStream := TScriptedPeerCertificateServerStream.Create;
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Peer-certificate connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn.Connect,
      'Full handshake with Certificate flight should succeed');

    LPeerCert := LConn.GetPeerCertificate;
    AssertTrue(LPeerCert <> nil,
      'Successful full handshake should expose peer leaf certificate');
    AssertTrue(
      SameText(LPeerCert.GetFingerprintSHA256, LExpectedLeaf.GetFingerprintSHA256),
      'Peer leaf certificate fingerprint should match the scripted server leaf fixture'
    );
    AssertTrue(
      SameText(LPeerCert.GetSubject, LExpectedLeaf.GetSubject),
      'Peer leaf certificate subject should match the scripted server leaf fixture'
    );
    LIssuerFromPeerCert := LPeerCert.GetIssuerCertificate;
    AssertTrue(LIssuerFromPeerCert <> nil,
      'Peer leaf certificate should preserve issuer link');
    AssertTrue(
      (LIssuerFromPeerCert <> nil) and
      SameText(LIssuerFromPeerCert.GetFingerprintSHA256, LExpectedIssuer.GetFingerprintSHA256),
      'Peer leaf certificate issuer link should match the scripted issuer fixture'
    );

    LChain := LConn.GetPeerCertificateChain;
    AssertEqualsInt(2, Length(LChain),
      'Successful full handshake should expose the scripted peer certificate chain');
    AssertTrue(LChain[0] <> nil, 'Peer chain leaf entry should not be nil');
    AssertTrue(LChain[1] <> nil, 'Peer chain issuer entry should not be nil');
    AssertTrue(
      SameText(LChain[0].GetFingerprintSHA256, LExpectedLeaf.GetFingerprintSHA256),
      'Peer chain leaf entry should match the scripted server leaf fixture'
    );
    AssertTrue(
      SameText(LChain[1].GetFingerprintSHA256, LExpectedIssuer.GetFingerprintSHA256),
      'Peer chain issuer entry should match the scripted issuer fixture'
    );
    AssertTrue(LChain[0].GetIssuerCertificate <> nil,
      'Peer chain leaf entry should preserve issuer link');
    AssertTrue(
      (LChain[0].GetIssuerCertificate <> nil) and
      SameText(LChain[0].GetIssuerCertificate.GetFingerprintSHA256, LExpectedIssuer.GetFingerprintSHA256),
      'Peer chain leaf issuer link should match the scripted issuer fixture'
    );
  finally
    LStream.Free;
  end;
end;

begin
  WriteLn('Testing FreePascal client peer certificate surface...');

  TestPeerCertificateIsExposedAfterFullHandshake;

  WriteLn('✅ FreePascal client peer-certificate surface checks passed');
end.
