program test_freepascal_client_certificateverify_runtime;

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

const
  TEST_TLS13_SIG_RSA_PSS_RSAE_SHA384 = $0805;

type
  TScriptedCertificateVerifyMode = (
    cvmValid,
    cvmTamperedSignature,
    cvmMismatchedScheme
  );

procedure Fail(const AMessage: string);
begin
  WriteLn('FAIL: ', AMessage);
  Halt(1);
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
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
  Result := nil;
  SetLength(Result, Length(LCombined));
  if Length(LCombined) > 0 then
    Move(LCombined[1], Result[0], Length(LCombined));
end;

function TamperSignatureBytes(const ASignature: TBytes): TBytes;
begin
  Result := Copy(ASignature);
  if Length(Result) = 0 then
    Exit;
  Result[High(Result)] := Result[High(Result)] xor $01;
end;

type
  TScriptedCertificateVerifyServerStream = class(TStream)
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
    FMode: TScriptedCertificateVerifyMode;
    FForcedSignatureScheme: Word;
    FExpectedSelectedSignatureScheme: Word;

    procedure Enqueue(const AData: TBytes);
    procedure HandleClientHello(const AData: TBytes);
    procedure HandleClientFinished(const AData: TBytes);
  public
    constructor Create(
      AMode: TScriptedCertificateVerifyMode;
      ACipherSuite: Word;
      AForcedSignatureScheme: Word = 0;
      AExpectedSelectedSignatureScheme: Word = 0
    );

    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

constructor TScriptedCertificateVerifyServerStream.Create(
  AMode: TScriptedCertificateVerifyMode;
  ACipherSuite: Word;
  AForcedSignatureScheme: Word;
  AExpectedSelectedSignatureScheme: Word
);
begin
  inherited Create;
  FCipherSuite := ACipherSuite;
  SetLength(FReadBuffer, 0);
  FReadPosition := 0;
  FWriteStage := 0;
  SetLength(FTranscriptData, 0);
  InitTLS13HandshakeSecrets(FHandshakeSecrets);
  FCertificateBlob := BuildCertificateBlob;
  FPrivateKeyBlob := ReadFileBytes('tests/certificate/test_certs/signer_key.pem');
  FMode := AMode;
  FForcedSignatureScheme := AForcedSignatureScheme;
  FExpectedSelectedSignatureScheme := AExpectedSelectedSignatureScheme;
end;

procedure TScriptedCertificateVerifyServerStream.Enqueue(const AData: TBytes);
var
  LOldLen: Integer;
begin
  if Length(AData) = 0 then
    Exit;

  LOldLen := Length(FReadBuffer);
  SetLength(FReadBuffer, LOldLen + Length(AData));
  Move(AData[0], FReadBuffer[LOldLen], Length(AData));
end;

procedure TScriptedCertificateVerifyServerStream.HandleClientHello(const AData: TBytes);
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
  LHandshakeScheme: Word;
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

  if not TrySelectTLS13ServerCertificateVerifySchemeForKeyTypeAndCipherSuite(
    LInfo,
    'RSA',
    FCipherSuite,
    LSignatureScheme,
    LError
  ) then
    raise Exception.Create('Failed to select CertificateVerify scheme: ' + LError);

  if (FExpectedSelectedSignatureScheme <> 0) and
     (LSignatureScheme <> FExpectedSelectedSignatureScheme) then
    raise Exception.CreateFmt(
      'Selected CertificateVerify scheme mismatch (expected=0x%.4x actual=0x%.4x)',
      [FExpectedSelectedSignatureScheme, LSignatureScheme]
    );

  if FForcedSignatureScheme <> 0 then
    LSignatureScheme := FForcedSignatureScheme;

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

  LHandshakeScheme := LSignatureScheme;
  case FMode of
    cvmValid:
      begin
      end;
    cvmTamperedSignature:
      LCertVerifySignature := TamperSignatureBytes(LCertVerifySignature);
    cvmMismatchedScheme:
      LHandshakeScheme := TLS13_SIG_ECDSA_SECP256R1_SHA256;
  end;

  LCertificateVerifyMessage := BuildTLS13CertificateVerifyHandshake(
    LHandshakeScheme,
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

procedure TScriptedCertificateVerifyServerStream.HandleClientFinished(const AData: TBytes);
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

function TScriptedCertificateVerifyServerStream.Read(var Buffer; Count: Longint): Longint;
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

function TScriptedCertificateVerifyServerStream.Write(const Buffer; Count: Longint): Longint;
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

function TScriptedCertificateVerifyServerStream.Seek(
  const Offset: Int64;
  Origin: TSeekOrigin
): Int64;
begin
  case Origin of
    soBeginning: FReadPosition := Offset;
    soCurrent: Inc(FReadPosition, Offset);
    soEnd: FReadPosition := Length(FReadBuffer) + Offset;
  end;
  Result := FReadPosition;
end;

procedure ExpectHandshakeResultForCipherSuite(
  AMode: TScriptedCertificateVerifyMode;
  ACipherSuite: Word;
  AForcedSignatureScheme: Word;
  AExpectedSelectedSignatureScheme: Word;
  AShouldConnect: Boolean;
  const ALabel: string
);
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedCertificateVerifyServerStream;
  LConnected: Boolean;
  LError: TSSLErrorCode;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(LCtx <> nil, ALabel + ': client context should be created');
  LCtx.SetPreferredVersion(sslProtocolTLS13);
  LCtx.SetVerifyMode([sslVerifyPeer]);
  LCtx.SetCertVerifyFlags([sslCertVerifyIgnoreHostname]);
  LCtx.LoadCAFile('tests/certificate/test_certs/ca_cert.pem');

  LStream := TScriptedCertificateVerifyServerStream.Create(
    AMode,
    ACipherSuite,
    AForcedSignatureScheme,
    AExpectedSelectedSignatureScheme
  );
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, ALabel + ': connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    LConnected := LConn.Connect;
    if AShouldConnect then
      AssertTrue(LConnected, ALabel + ': handshake should succeed')
    else
    begin
      AssertTrue(not LConnected, ALabel + ': handshake should fail');
      LError := LConn.GetError(-1);
      AssertTrue(
        (LError = sslErrHandshake) or
        (LError = sslErrProtocol) or
        (LError = sslErrUnsupported),
        ALabel + ': failure should map to handshake/protocol/unsupported error'
      );
    end;
  finally
    LStream.Free;
  end;
end;

procedure TestValidCertificateVerifySucceeds;
begin
  ExpectHandshakeResultForCipherSuite(cvmValid, TLS13_CIPHER_CHACHA20_POLY1305_SHA256, 0, 0, True,
    'Valid RSA CertificateVerify should pass');
end;

procedure TestTamperedCertificateVerifyFails;
begin
  ExpectHandshakeResultForCipherSuite(cvmTamperedSignature, TLS13_CIPHER_CHACHA20_POLY1305_SHA256, 0, 0, False,
    'Tampered RSA CertificateVerify should fail');
end;

procedure TestMismatchedCertificateVerifySchemeFails;
begin
  ExpectHandshakeResultForCipherSuite(cvmMismatchedScheme, TLS13_CIPHER_CHACHA20_POLY1305_SHA256, 0, 0, False,
    'CertificateVerify scheme mismatch should fail');
end;

procedure TestValidCertificateVerifySucceedsForSHA384Suite;
begin
  ExpectHandshakeResultForCipherSuite(cvmValid, TLS13_CIPHER_AES_256_GCM_SHA384, 0, 0, True,
    'Valid RSA CertificateVerify should pass on AES256/SHA384 suite');
end;

procedure TestValidCertificateVerifySucceedsForRSASHA384Scheme;
begin
  ExpectHandshakeResultForCipherSuite(
    cvmValid,
    TLS13_CIPHER_AES_256_GCM_SHA384,
    TEST_TLS13_SIG_RSA_PSS_RSAE_SHA384,
    0,
    True,
    'Valid RSA SHA384 CertificateVerify should pass on AES256/SHA384 suite'
  );
end;

procedure TestValidCertificateVerifyNegotiatesRSASHA384SchemeForSHA384Suite;
begin
  ExpectHandshakeResultForCipherSuite(
    cvmValid,
    TLS13_CIPHER_AES_256_GCM_SHA384,
    0,
    TEST_TLS13_SIG_RSA_PSS_RSAE_SHA384,
    True,
    'Default AES256/SHA384 path should negotiate RSA SHA384 CertificateVerify'
  );
end;

begin
  WriteLn('Testing FreePascal client CertificateVerify runtime...');

  TestValidCertificateVerifySucceeds;
  TestValidCertificateVerifySucceedsForSHA384Suite;
  TestValidCertificateVerifySucceedsForRSASHA384Scheme;
  TestValidCertificateVerifyNegotiatesRSASHA384SchemeForSHA384Suite;
  TestTamperedCertificateVerifyFails;
  TestMismatchedCertificateVerifySchemeFails;

  WriteLn('PASS: FreePascal client CertificateVerify runtime checks passed');
end.
