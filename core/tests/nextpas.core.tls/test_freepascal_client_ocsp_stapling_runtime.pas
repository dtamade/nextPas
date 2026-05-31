program test_freepascal_client_ocsp_stapling_runtime;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  fafafa.ssl,
  nextpas.core.tls.asn1,
  nextpas.core.tls.base,
  nextpas.core.tls.ocsp,
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
  nextpas.core.tls.x509;

type
  TServerMaterial = record
    CertificateBlob: TBytes;
    PrivateKeyBlob: TBytes;
  end;

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

procedure AssertEqualsInt(AExpected, AActual: Int64; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
end;

procedure AssertBytesEqual(const AExpected, AActual: TBytes; const AMessage: string);
var
  I: Integer;
begin
  if Length(AExpected) <> Length(AActual) then
    Fail(Format('%s (expected_len=%d actual_len=%d)', [AMessage, Length(AExpected), Length(AActual)]));

  for I := 0 to High(AExpected) do
    if AExpected[I] <> AActual[I] then
      Fail(Format('%s (first_diff=%d)', [AMessage, I]));
end;

function ContainsTextInsensitive(const AValue, ASubText: string): Boolean;
begin
  Result := Pos(LowerCase(ASubText), LowerCase(AValue)) > 0;
end;

function GetCertificateVerifyResultString(const AConn: ISSLConnection): string;
var
  LCertVerify: ISSLCertificateVerification;
begin
  AssertTrue(Supports(AConn, ISSLCertificateVerification, LCertVerify),
    'Connection should expose certificate verification interface');
  Result := LCertVerify.GetVerifyResultString;
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

function GenerateCASignedServerMaterial(
  const ACommonName: string;
  const ASANs: array of string
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
  LOptions.NotBefore := Now - 1;
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
      raise Exception.Create('GenerateSigned returned False for scripted CA-signed server material');
  finally
    LOptions.SubjectAltNames.Free;
    LOptions.SubjectAltNames := nil;
  end;

  LCombinedPEM := AnsiString(LLeafCertPEM + LineEnding + LCACertPEM);
  Result.CertificateBlob := AnsiStringToBytes(LCombinedPEM);
  Result.PrivateKeyBlob := AnsiStringToBytes(AnsiString(LLeafKeyPEM));
end;

function LoadOCSPFixture(const AFileName: string): TBytes;
begin
  Result := ReadFileBytes(AFileName);
  AssertTrue(Length(Result) > 0, 'OCSP fixture should not be empty: ' + AFileName);
end;

function BuildOCSPResponseForCertificateBlob(
  const ACertificateBlob: TBytes;
  ACertStatus: TOCSPCertStatus
): TBytes;
var
  LCertificates: TTLS13CertificateArray;
  LLeafCertificate: TX509Certificate;
  LIssuerCertificate: TX509Certificate;
  LCertID: TOCSPCertID;
  LBasicWriter: TASN1Writer;
  LOuterWriter: TASN1Writer;
  LNow: TDateTime;
  LError: string;
begin
  Result := nil;
  LError := '';
  if not TryParseCertificateBlob(ACertificateBlob, LCertificates, LError) then
    Fail('Failed to parse certificate blob for OCSP response: ' + LError);
  AssertTrue(Length(LCertificates) >= 2,
    'OCSP response builder requires leaf + issuer certificates in the blob');

  LLeafCertificate := TX509Certificate.Create;
  LIssuerCertificate := TX509Certificate.Create;
  try
    LLeafCertificate.LoadFromDER(LCertificates[0]);
    LIssuerCertificate.LoadFromDER(LCertificates[1]);
    LCertID := TOCSPCertID.Create(LLeafCertificate, LIssuerCertificate);
    LNow := Now;

    LBasicWriter := TASN1Writer.Create;
    try
      LBasicWriter.BeginSequence;
      LBasicWriter.BeginSequence;
      LBasicWriter.BeginContextTag(2);
      LBasicWriter.WriteOctetString(LCertID.IssuerKeyHash);
      LBasicWriter.EndContextTag;
      LBasicWriter.WriteGeneralizedTime(LNow - (1.0 / 24.0));
      LBasicWriter.BeginSequence;
      LBasicWriter.BeginSequence;
      LBasicWriter.WriteRaw(LCertID.Encode);
      case ACertStatus of
        ocspGood:
          LBasicWriter.WriteRaw([$80, $00]);
        ocspUnknown:
          LBasicWriter.WriteRaw([$82, $00]);
        ocspRevoked:
        begin
          LBasicWriter.BeginContextTag(1);
          LBasicWriter.WriteGeneralizedTime(LNow - (2.0 / 24.0));
          LBasicWriter.EndContextTag;
        end;
      end;
      LBasicWriter.WriteGeneralizedTime(LNow - (1.0 / 24.0));
      LBasicWriter.BeginContextTag(0);
      LBasicWriter.WriteGeneralizedTime(LNow + 1.0);
      LBasicWriter.EndContextTag;
      LBasicWriter.EndSequence;
      LBasicWriter.EndSequence;
      LBasicWriter.EndSequence;
      LBasicWriter.BeginSequence;
      LBasicWriter.WriteOID('1.2.840.113549.1.1.11');
      LBasicWriter.WriteNull;
      LBasicWriter.EndSequence;
      LBasicWriter.WriteBitString([]);
      LBasicWriter.EndSequence;

      LOuterWriter := TASN1Writer.Create;
      try
        LOuterWriter.BeginSequence;
        LOuterWriter.WriteRaw([$0A, $01, $00]);
        LOuterWriter.BeginContextTag(0);
        LOuterWriter.BeginSequence;
        LOuterWriter.WriteOID('1.3.6.1.5.5.7.48.1.1');
        LOuterWriter.WriteOctetString(LBasicWriter.GetData);
        LOuterWriter.EndSequence;
        LOuterWriter.EndContextTag;
        LOuterWriter.EndSequence;
        Result := LOuterWriter.GetData;
      finally
        LOuterWriter.Free;
      end;
    finally
      LBasicWriter.Free;
    end;
  finally
    LLeafCertificate.Free;
    LIssuerCertificate.Free;
  end;

  AssertTrue(Length(Result) > 0, 'Generated OCSP response for scripted certificate should not be empty');
end;

function BuildStatusRequestCertificateExtension(const AResponse: TBytes): TBytes;
var
  LBody: TBytes;
begin
  SetLength(LBody, 0);
  AppendByte(LBody, 1);
  AppendUInt24(LBody, Length(AResponse));
  AppendBytes(LBody, AResponse);

  Result := nil;
  AppendUInt16(Result, 5);
  AppendUInt16(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

function TryBuildTLS13ServerCertificateHandshakeWithStapledOCSP(
  const ACertificateBlob: TBytes;
  const AStapledOCSPResponse: TBytes;
  out AHandshake: TBytes;
  out AError: string
): Boolean;
var
  LCertificates: TTLS13CertificateArray;
  LCertificateList: TBytes;
  LEntry: TBytes;
  LBody: TBytes;
  LExtensions: TBytes;
  I: Integer;
  LCertLen: Integer;
begin
  SetLength(AHandshake, 0);
  AError := '';
  Result := False;

  if not TryParseCertificateBlob(ACertificateBlob, LCertificates, AError) then
    Exit;

  SetLength(LCertificateList, 0);
  for I := 0 to High(LCertificates) do
  begin
    LCertLen := Length(LCertificates[I]);
    if (LCertLen <= 0) or (LCertLen > $FFFFFF) then
    begin
      AError := Format('Certificate #%d length is invalid for TLS 1.3: %d', [I + 1, LCertLen]);
      Exit;
    end;

    SetLength(LExtensions, 0);
    if (I = 0) and (Length(AStapledOCSPResponse) > 0) then
      LExtensions := BuildStatusRequestCertificateExtension(AStapledOCSPResponse);

    SetLength(LEntry, 0);
    AppendUInt24(LEntry, LCertLen);
    AppendBytes(LEntry, LCertificates[I]);
    AppendUInt16(LEntry, Length(LExtensions));
    AppendBytes(LEntry, LExtensions);
    AppendBytes(LCertificateList, LEntry);
  end;

  if Length(LCertificateList) > $FFFFFF then
  begin
    AError := 'Certificate list is too large for TLS 1.3';
    Exit;
  end;

  SetLength(LBody, 0);
  AppendByte(LBody, 0);
  AppendUInt24(LBody, Length(LCertificateList));
  AppendBytes(LBody, LCertificateList);

  SetLength(AHandshake, 0);
  AppendByte(AHandshake, TLS_HANDSHAKE_TYPE_CERTIFICATE);
  AppendUInt24(AHandshake, Length(LBody));
  AppendBytes(AHandshake, LBody);

  Result := True;
end;

function ClientHelloHasExtension(const AHandshake: TBytes; AExtensionType: Word): Boolean;
var
  LOffset: Integer;
  LBodyLen: Cardinal;
  LBodyEnd: Integer;
  LSessionIDLen: Integer;
  LCipherSuitesLen: Integer;
  LCompressionLen: Integer;
  LExtensionsLen: Integer;
  LExtensionsEnd: Integer;
  LExtType: Word;
  LExtLen: Word;
begin
  Result := False;

  if (Length(AHandshake) < 4) or (AHandshake[0] <> TLS_HANDSHAKE_TYPE_CLIENT_HELLO) then
    Exit;

  LBodyLen := ReadUInt24(AHandshake, 1);
  LBodyEnd := 4 + Integer(LBodyLen);
  if Length(AHandshake) <> LBodyEnd then
    Exit;

  LOffset := 4 + 2 + 32;
  if LOffset >= LBodyEnd then
    Exit;

  LSessionIDLen := AHandshake[LOffset];
  Inc(LOffset);
  Inc(LOffset, LSessionIDLen);
  if LOffset + 2 > LBodyEnd then
    Exit;

  LCipherSuitesLen := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2 + LCipherSuitesLen);
  if LOffset + 1 > LBodyEnd then
    Exit;

  LCompressionLen := AHandshake[LOffset];
  Inc(LOffset);
  Inc(LOffset, LCompressionLen);
  if LOffset + 2 > LBodyEnd then
    Exit;

  LExtensionsLen := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2);
  LExtensionsEnd := LOffset + LExtensionsLen;
  if LExtensionsEnd <> LBodyEnd then
    Exit;

  while LOffset + 4 <= LExtensionsEnd do
  begin
    LExtType := ReadUInt16(AHandshake, LOffset);
    LExtLen := ReadUInt16(AHandshake, LOffset + 2);
    Inc(LOffset, 4);
    if LOffset + Integer(LExtLen) > LExtensionsEnd then
      Exit(False);
    if LExtType = AExtensionType then
      Exit(True);
    Inc(LOffset, Integer(LExtLen));
  end;
end;

type
  TScriptedOCSPServerStream = class(TStream)
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
    FStapledOCSPResponse: TBytes;
    FObservedStatusRequest: Boolean;

    procedure Enqueue(const AData: TBytes);
    procedure HandleClientHello(const AData: TBytes);
    procedure HandleClientFinished(const AData: TBytes);
  public
    constructor Create(const ACertificateBlob, APrivateKeyBlob, AStapledOCSPResponse: TBytes);

    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;

    property ObservedStatusRequest: Boolean read FObservedStatusRequest;
  end;

constructor TScriptedOCSPServerStream.Create(
  const ACertificateBlob,
  APrivateKeyBlob,
  AStapledOCSPResponse: TBytes
);
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
  FStapledOCSPResponse := Copy(AStapledOCSPResponse, 0, Length(AStapledOCSPResponse));
  FObservedStatusRequest := False;
end;

procedure TScriptedOCSPServerStream.Enqueue(const AData: TBytes);
var
  LOldLen: Integer;
begin
  if Length(AData) = 0 then
    Exit;

  LOldLen := Length(FReadBuffer);
  SetLength(FReadBuffer, LOldLen + Length(AData));
  Move(AData[0], FReadBuffer[LOldLen], Length(AData));
end;

procedure TScriptedOCSPServerStream.HandleClientHello(const AData: TBytes);
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

  FObservedStatusRequest := ClientHelloHasExtension(LHandshake, 5);

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

  if not TryBuildTLS13ServerCertificateHandshakeWithStapledOCSP(
    FCertificateBlob,
    FStapledOCSPResponse,
    LCertificateMessage,
    LError
  ) then
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

procedure TScriptedOCSPServerStream.HandleClientFinished(const AData: TBytes);
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

function TScriptedOCSPServerStream.Read(var Buffer; Count: Longint): Longint;
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

function TScriptedOCSPServerStream.Write(const Buffer; Count: Longint): Longint;
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

function TScriptedOCSPServerStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning: FReadPosition := Offset;
    soCurrent: Inc(FReadPosition, Offset);
    soEnd: FReadPosition := Length(FReadBuffer) + Offset;
  end;
  Result := FReadPosition;
end;

function NewClientContextWithVerifyMode(
  AEnableStapling, ARequireStapling: Boolean;
  const AVerifyMode: TSSLVerifyModes
): ISSLContext;
var
  LOptions: TSSLOptions;
begin
  Result := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  AssertTrue(Result <> nil, 'FreePascal client context should be created');
  Result.SetPreferredVersion(sslProtocolTLS13);
  Result.SetVerifyMode(AVerifyMode);
  Result.LoadCAFile('tests/certificate/test_certs/ca_cert.pem');

  LOptions := Result.GetOptions;
  if AEnableStapling then
    Include(LOptions, ssoEnableOCSPStapling)
  else
    Exclude(LOptions, ssoEnableOCSPStapling);

  if ARequireStapling then
  begin
    Include(LOptions, ssoEnableOCSPStapling);
    Include(LOptions, ssoRequireOCSPStapling);
  end
  else
    Exclude(LOptions, ssoRequireOCSPStapling);

  Result.SetOptions(LOptions);
end;

function NewClientContext(AEnableStapling, ARequireStapling: Boolean): ISSLContext;
begin
  Result := NewClientContextWithVerifyMode(
    AEnableStapling,
    ARequireStapling,
    [sslVerifyPeer]
  );
end;

procedure TestClientHelloRequestsStatusRequestAndEmptySurfaceWhenOptional;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LOCSP: ISSLOCSPStapling;
  LStream: TScriptedOCSPServerStream;
begin
  LMaterial := GenerateCASignedServerMaterial('example.com', ['DNS:example.com']);
  LCtx := NewClientContext(True, False);
  LStream := TScriptedOCSPServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob, nil);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Optional OCSP connection should be created');
    AssertTrue(Supports(LConn, ISSLOCSPStapling, LOCSP), 'Connection should support ISSLOCSPStapling');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn.Connect,
      'Optional OCSP stapling without stapled response should still connect');
    AssertTrue(LStream.ObservedStatusRequest,
      'ClientHello should include status_request when ssoEnableOCSPStapling is enabled');
    AssertTrue(not LOCSP.GetOCSPStaplingEnabled,
      'OCSP stapling should report disabled when no stapled response is present');
    AssertEqualsInt(0, Length(LOCSP.GetOCSPResponse),
      'Missing stapled response should surface empty OCSP response bytes');
    AssertTrue(not LOCSP.IsOCSPResponseVerified,
      'Missing stapled response should not verify');
  finally
    LStream.Free;
  end;
end;

procedure TestOptionalStapledResponseSurfacesRawBytes;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LOCSP: ISSLOCSPStapling;
  LStream: TScriptedOCSPServerStream;
  LFixture: TBytes;
begin
  LMaterial := GenerateCASignedServerMaterial('example.com', ['DNS:example.com']);
  LFixture := LoadOCSPFixture('tests/fixtures/p2/ocsp/ocsp_response_successful_basic_v1.der');
  LCtx := NewClientContext(True, False);
  LStream := TScriptedOCSPServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob, LFixture);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Optional stapled-response connection should be created');
    AssertTrue(Supports(LConn, ISSLOCSPStapling, LOCSP), 'Connection should support ISSLOCSPStapling');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn.Connect,
      'Optional stapled response should not fail the handshake');
    AssertTrue(LStream.ObservedStatusRequest,
      'ClientHello should include status_request when stapled response is expected');
    AssertTrue(LOCSP.GetOCSPStaplingEnabled,
      'Present stapled response should surface OCSP stapling as enabled');
    AssertBytesEqual(LFixture, LOCSP.GetOCSPResponse,
      'Stapled OCSP response bytes should be surfaced back to the caller');
    AssertTrue(not LOCSP.IsOCSPResponseVerified,
      'Successful/basic fixture without full verification context should not verify');
    AssertTrue(Trim(LOCSP.GetOCSPResponseStatus) <> '',
      'Stapled OCSP response should expose a non-empty status string');
  finally
    LStream.Free;
  end;
end;

procedure TestRequiredStaplingFailsWithoutResponse;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedOCSPServerStream;
begin
  LMaterial := GenerateCASignedServerMaterial('example.com', ['DNS:example.com']);
  LCtx := NewClientContext(True, True);
  LStream := TScriptedOCSPServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob, nil);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Required-stapling connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'Required stapling should fail-closed when server omits stapled OCSP response');
    AssertTrue(LStream.ObservedStatusRequest,
      'Required stapling path should still request status_request');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'ocsp') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'stapling'),
      'Required stapling failure should mention OCSP/stapling'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestRequiredStaplingFailsWhenFixtureDoesNotVerify;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedOCSPServerStream;
  LFixture: TBytes;
begin
  LMaterial := GenerateCASignedServerMaterial('example.com', ['DNS:example.com']);
  LFixture := LoadOCSPFixture('tests/fixtures/p2/ocsp/ocsp_response_successful_basic_v1.der');
  LCtx := NewClientContext(True, True);
  LStream := TScriptedOCSPServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob, LFixture);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Required stapled-response connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'Required stapling should fail-closed when stapled response is not accepted by the bounded verifier');
    AssertTrue(LStream.ObservedStatusRequest,
      'Required stapling path should request status_request before failure');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'ocsp') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'stapling'),
      'Unaccepted stapled response failure should mention OCSP/stapling'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestOptionalStapledGoodStatusWithoutCryptographicProofStaysUnverified;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LOCSP: ISSLOCSPStapling;
  LStream: TScriptedOCSPServerStream;
  LFixture: TBytes;
  LStatus: string;
begin
  LMaterial := GenerateCASignedServerMaterial('example.com', ['DNS:example.com']);
  LFixture := BuildOCSPResponseForCertificateBlob(LMaterial.CertificateBlob, ocspGood);
  LCtx := NewClientContext(True, False);
  LStream := TScriptedOCSPServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob, LFixture);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Optional good-status stapled-response connection should be created');
    AssertTrue(Supports(LConn, ISSLOCSPStapling, LOCSP), 'Connection should support ISSLOCSPStapling');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn.Connect,
      'Optional stapled response should keep the handshake alive even when cryptographic verification fails');
    AssertTrue(LStream.ObservedStatusRequest,
      'Optional good-status stapled-response path should request status_request');
    AssertTrue(LOCSP.GetOCSPStaplingEnabled,
      'Present stapled response should surface OCSP stapling as enabled');
    AssertBytesEqual(LFixture, LOCSP.GetOCSPResponse,
      'Good-status stapled response bytes should be surfaced back to the caller');
    AssertTrue(not LOCSP.IsOCSPResponseVerified,
      'Good-status stapled response without cryptographic proof must not be marked as verified');
    LStatus := Trim(LOCSP.GetOCSPResponseStatus);
    AssertTrue(LStatus <> '', 'Cryptographic stapling failure should surface a non-empty status string');
    AssertTrue(not SameText(LStatus, 'Verified'),
      'Good-status stapled response without cryptographic proof must not surface as plain Verified');
    AssertTrue(
      ContainsTextInsensitive(LStatus, 'verification') or
      ContainsTextInsensitive(LStatus, 'signature') or
      ContainsTextInsensitive(LStatus, 'responder') or
      ContainsTextInsensitive(LStatus, 'ocsp'),
      'Cryptographic stapling failure should be reflected in the surfaced OCSP status'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestRequiredStaplingFailsWhenGoodStatusStapledResponseLacksCryptographicProof;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedOCSPServerStream;
  LFixture: TBytes;
begin
  LMaterial := GenerateCASignedServerMaterial('example.com', ['DNS:example.com']);
  LFixture := BuildOCSPResponseForCertificateBlob(LMaterial.CertificateBlob, ocspGood);
  LCtx := NewClientContext(True, True);
  LStream := TScriptedOCSPServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob, LFixture);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Required good-status stapled-response connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'Required stapling should fail-closed when a good-status stapled response lacks cryptographic proof');
    AssertTrue(LStream.ObservedStatusRequest,
      'Required good-status stapled-response path should request status_request before failure');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'ocsp') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'stapling') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'signature') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'verification'),
      'Cryptographic stapling failure should mention OCSP/stapling/signature/verification'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestOptionalStapledResponseWithUnknownCertStatusSurfacesFailure;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LOCSP: ISSLOCSPStapling;
  LStream: TScriptedOCSPServerStream;
  LFixture: TBytes;
  LStatus: string;
begin
  LMaterial := GenerateCASignedServerMaterial('example.com', ['DNS:example.com']);
  LFixture := BuildOCSPResponseForCertificateBlob(LMaterial.CertificateBlob, ocspUnknown);
  LCtx := NewClientContext(True, False);
  LStream := TScriptedOCSPServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob, LFixture);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Optional unknown-status stapled-response connection should be created');
    AssertTrue(Supports(LConn, ISSLOCSPStapling, LOCSP), 'Connection should support ISSLOCSPStapling');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn.Connect,
      'Optional stapled response with unknown cert status should still connect');
    AssertTrue(LStream.ObservedStatusRequest,
      'Optional unknown-status stapled-response path should request status_request');
    AssertTrue(LOCSP.GetOCSPStaplingEnabled,
      'Present stapled response should still surface OCSP stapling as enabled');
    AssertBytesEqual(LFixture, LOCSP.GetOCSPResponse,
      'Unknown-status stapled response bytes should be surfaced back to the caller');
    AssertTrue(not LOCSP.IsOCSPResponseVerified,
      'Unknown cert status must not be marked as verified');
    LStatus := Trim(LOCSP.GetOCSPResponseStatus);
    AssertTrue(LStatus <> '', 'Unknown cert status should surface a non-empty status string');
    AssertTrue(not SameText(LStatus, 'Verified'),
      'Unknown cert status must not surface as plain Verified');
    AssertTrue(
      ContainsTextInsensitive(LStatus, 'unknown') or
      ContainsTextInsensitive(LStatus, 'verification failed'),
      'Unknown cert status should be reflected in the surfaced OCSP status'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestRequiredStaplingFailsWhenStapledResponseCertStatusIsUnknown;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedOCSPServerStream;
  LFixture: TBytes;
begin
  LMaterial := GenerateCASignedServerMaterial('example.com', ['DNS:example.com']);
  LFixture := BuildOCSPResponseForCertificateBlob(LMaterial.CertificateBlob, ocspUnknown);
  LCtx := NewClientContext(True, True);
  LStream := TScriptedOCSPServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob, LFixture);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Required unknown-status stapled-response connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'Required stapling should fail-closed when stapled response cert status is unknown');
    AssertTrue(LStream.ObservedStatusRequest,
      'Required unknown-status stapled-response path should request status_request before failure');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'ocsp') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'stapling') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'unknown'),
      'Unknown cert-status failure should mention OCSP/stapling/unknown'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestRequiredStaplingIsIgnoredWhenVerifyPeerDisabled;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LOCSP: ISSLOCSPStapling;
  LStream: TScriptedOCSPServerStream;
begin
  LMaterial := GenerateCASignedServerMaterial('example.com', ['DNS:example.com']);
  LCtx := NewClientContextWithVerifyMode(True, True, []);
  LStream := TScriptedOCSPServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob, nil);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Verify-none required-stapling connection should be created');
    AssertTrue(Supports(LConn, ISSLOCSPStapling, LOCSP), 'Connection should support ISSLOCSPStapling');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn.Connect,
      'Required OCSP stapling should not fail-closed when verify-peer is disabled');
    AssertTrue(LStream.ObservedStatusRequest,
      'Verify-none required-stapling path should preserve current status_request trigger');
    AssertEqualsInt(0, Length(LOCSP.GetOCSPResponse),
      'Verify-none required-stapling path should still surface empty OCSP response bytes');
    AssertTrue(not LOCSP.IsOCSPResponseVerified,
      'Verify-none required-stapling path should not mark missing OCSP response as verified');
  finally
    LStream.Free;
  end;
end;

begin
  WriteLn('Testing FreePascal client OCSP stapling runtime parity...');

  TestClientHelloRequestsStatusRequestAndEmptySurfaceWhenOptional;
  TestOptionalStapledResponseSurfacesRawBytes;
  TestRequiredStaplingFailsWithoutResponse;
  TestRequiredStaplingFailsWhenFixtureDoesNotVerify;
  TestOptionalStapledGoodStatusWithoutCryptographicProofStaysUnverified;
  TestRequiredStaplingFailsWhenGoodStatusStapledResponseLacksCryptographicProof;
  TestOptionalStapledResponseWithUnknownCertStatusSurfacesFailure;
  TestRequiredStaplingFailsWhenStapledResponseCertStatusIsUnknown;
  TestRequiredStaplingIsIgnoredWhenVerifyPeerDisabled;

  WriteLn('PASS: FreePascal client OCSP stapling runtime checks passed');
end.
