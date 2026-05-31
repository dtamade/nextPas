program test_freepascal_client_chain_trust_runtime;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib,
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
  nextpas.core.tls.crypto.hash;

type
  TServerMaterial = record
    CertificateBlob: TBytes;
    PrivateKeyBlob: TBytes;
  end;

  TTrustConfigKind = (
    tcNone,
    tcCAFile,
    tcCAPath,
    tcStore
  );

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

function GenerateSelfSignedServerMaterial(
  const ACommonName: string;
  const ASANs: array of string
): TServerMaterial;
var
  LOptions: TCertGenOptions;
  LCertPEM: string;
  LKeyPEM: string;
  I: Integer;
begin
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

    if not TCertificateUtils.GenerateSelfSigned(LOptions, LCertPEM, LKeyPEM) then
      raise Exception.Create('GenerateSelfSigned returned False for scripted self-signed server material');
  finally
    LOptions.SubjectAltNames.Free;
    LOptions.SubjectAltNames := nil;
  end;

  Result.CertificateBlob := AnsiStringToBytes(AnsiString(LCertPEM));
  Result.PrivateKeyBlob := AnsiStringToBytes(AnsiString(LKeyPEM));
end;

procedure WriteBytesToFile(const AFileName: string; const AData: TBytes);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    if Length(AData) > 0 then
      LStream.WriteBuffer(AData[0], Length(AData));
  finally
    LStream.Free;
  end;
end;

function EnsureCAPathFixture: string;
begin
  Result := 'tmp/freepascal_client_chain_trust_runtime_ca';
  ForceDirectories(Result);
  WriteBytesToFile(
    IncludeTrailingPathDelimiter(Result) + 'ca_cert.pem',
    ReadFileBytes('tests/certificate/test_certs/ca_cert.pem')
  );
end;

type
  TScriptedChainTrustServerStream = class(TStream)
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

constructor TScriptedChainTrustServerStream.Create(const ACertificateBlob, APrivateKeyBlob: TBytes);
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

procedure TScriptedChainTrustServerStream.Enqueue(const AData: TBytes);
var
  LOldLen: Integer;
begin
  if Length(AData) = 0 then
    Exit;

  LOldLen := Length(FReadBuffer);
  SetLength(FReadBuffer, LOldLen + Length(AData));
  Move(AData[0], FReadBuffer[LOldLen], Length(AData));
end;

procedure TScriptedChainTrustServerStream.HandleClientHello(const AData: TBytes);
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

procedure TScriptedChainTrustServerStream.HandleClientFinished(const AData: TBytes);
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

function TScriptedChainTrustServerStream.Read(var Buffer; Count: Longint): Longint;
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

function TScriptedChainTrustServerStream.Write(const Buffer; Count: Longint): Longint;
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

function TScriptedChainTrustServerStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
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
end;

function CreateInitializedFreePascalLibrary: ISSLLibrary;
begin
  Result := CreateFreePascalSSLLibrary;
  AssertTrue(Result <> nil, 'CreateFreePascalSSLLibrary should not return nil');
  AssertTrue(Result.Initialize,
    'FreePascal library should initialize for direct-library trust-loading runtime');
end;

procedure ConfigureClientTrustConfig(
  var AConfig: TSSLConfig;
  AKind: TTrustConfigKind;
  const ACAPath: string
);
begin
  AConfig.LibraryType := sslFreePascal;
  AConfig.ContextType := sslCtxClient;
  AConfig.ProtocolVersions := [sslProtocolTLS13];
  AConfig.PreferredVersion := sslProtocolTLS13;
  AConfig.VerifyMode := [sslVerifyPeer];
  AConfig.CAFile := '';
  AConfig.CAPath := '';
  AConfig.UseSystemRoots := False;

  case AKind of
    tcCAFile:
      AConfig.CAFile := 'tests/certificate/test_certs/ca_cert.pem';
    tcCAPath:
      AConfig.CAPath := ACAPath;
  else
    raise Exception.Create('ConfigureClientTrustConfig only supports CAFile or CAPath trust kinds');
  end;
end;

function CreateFactoryOneShotTrustContext(
  AKind: TTrustConfigKind;
  const ACAPath: string
): ISSLContext;
var
  LConfig: TSSLConfig;
begin
  LConfig := CreateDefaultConfig(sslCtxClient);
  ConfigureClientTrustConfig(LConfig, AKind, ACAPath);
  Result := TSSLFactory.CreateContext(LConfig);
  AssertTrue(Result <> nil, 'Factory one-shot trust context should be created');
  Result.SetCertVerifyFlags([sslCertVerifyDefault]);
end;

function CreateFactoryDefaultConfigTrustContext(
  AKind: TTrustConfigKind;
  const ACAPath: string
): ISSLContext;
var
  LLib: ISSLLibrary;
  LOriginalConfig: TSSLConfig;
  LConfig: TSSLConfig;
begin
  LLib := TSSLFactory.GetLibraryInstance(sslFreePascal);
  AssertTrue(LLib <> nil, 'Factory FreePascal library instance should be created');
  LOriginalConfig := LLib.GetDefaultConfig;
  LConfig := LOriginalConfig;
  ConfigureClientTrustConfig(LConfig, AKind, ACAPath);
  LLib.SetDefaultConfig(LConfig);
  try
    Result := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
    AssertTrue(Result <> nil, 'Factory default-config trust context should be created');
    Result.SetCertVerifyFlags([sslCertVerifyDefault]);
  finally
    LLib.SetDefaultConfig(LOriginalConfig);
  end;
end;

procedure ApplyTrustConfig(ALCtx: ISSLContext; AKind: TTrustConfigKind; const ACAPath: string);
var
  LStore: ISSLCertificateStore;
begin
  case AKind of
    tcNone:
      Exit;
    tcCAFile:
      ALCtx.LoadCAFile('tests/certificate/test_certs/ca_cert.pem');
    tcCAPath:
      ALCtx.LoadCAPath(ACAPath);
    tcStore:
      begin
        LStore := TSSLFactory.CreateCertificateStore(sslFreePascal);
        AssertTrue(LStore <> nil, 'FreePascal certificate store should be created');
        AssertTrue(
          LStore.LoadFromFile('tests/certificate/test_certs/ca_cert.pem'),
          'Certificate store should load CA file for trust runtime test'
        );
        ALCtx.SetCertificateStore(LStore);
      end;
  end;
end;

procedure AssertCASignedHandshakePassesWithContext(
  ALCtx: ISSLContext;
  const ALabel: string
);
var
  LMaterial: TServerMaterial;
  LConn: ISSLConnection;
  LStream: TScriptedChainTrustServerStream;
begin
  LMaterial := GenerateCASignedServerMaterial('example.com', ['DNS:example.com']);
  LStream := TScriptedChainTrustServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob);
  try
    LConn := ALCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, ALabel + ' should create a connection');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn.Connect,
      ALabel + ' should allow scripted CA-signed certificate to connect');
    AssertEqualsInt(0, GetCertificateVerifyResult(LConn),
      ALabel + ' should surface verify success');
    AssertTrue(
      SameText(GetCertificateVerifyResultString(LConn), 'OK'),
      ALabel + ' should surface verify OK string'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestVerifyResultDoesNotPretendSuccessBeforeHandshake;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TMemoryStream;
begin
  LCtx := NewClientContext([sslCertVerifyDefault]);
  LStream := TMemoryStream.Create;
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Fresh FreePascal connection should be created');
    AssertEqualsInt(-1, GetCertificateVerifyResult(LConn),
      'Fresh connection must not report verify success before handshake');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'not verified'),
      'Fresh connection should surface not-verified diagnostic before handshake'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestCASignedCertificateFailsWithoutTrust;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedChainTrustServerStream;
begin
  LMaterial := GenerateCASignedServerMaterial('example.com', ['DNS:example.com']);
  LCtx := NewClientContext([sslCertVerifyDefault]);
  LStream := TScriptedChainTrustServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Untrusted CA-signed connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'CA-signed certificate should fail when no trust material is configured');
    AssertEqualsInt(Ord(sslErrCertificateUntrusted), GetCertificateVerifyResult(LConn),
      'Untrusted CA-signed certificate should surface sslErrCertificateUntrusted');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'trust') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'untrusted'),
      'Untrusted CA-signed certificate should mention trust failure'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestCASignedCertificatePassesWithCAFile;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedChainTrustServerStream;
begin
  LMaterial := GenerateCASignedServerMaterial('example.com', ['DNS:example.com']);
  LCtx := NewClientContext([sslCertVerifyDefault]);
  ApplyTrustConfig(LCtx, tcCAFile, '');
  LStream := TScriptedChainTrustServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'CA-file connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn.Connect,
      'Configured CA file should allow scripted CA-signed certificate to connect');
    AssertEqualsInt(0, GetCertificateVerifyResult(LConn),
      'Trusted scripted handshake should surface verify success');
    AssertTrue(
      SameText(GetCertificateVerifyResultString(LConn), 'OK'),
      'Trusted scripted handshake should surface verify OK string'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestCASignedCertificatePassesWithCAPath(const ACAPath: string);
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedChainTrustServerStream;
begin
  LMaterial := GenerateCASignedServerMaterial('example.com', ['DNS:example.com']);
  LCtx := NewClientContext([sslCertVerifyDefault]);
  ApplyTrustConfig(LCtx, tcCAPath, ACAPath);
  LStream := TScriptedChainTrustServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'CA-path connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn.Connect,
      'Configured CA path should allow scripted CA-signed certificate to connect');
  finally
    LStream.Free;
  end;
end;

procedure TestCASignedCertificatePassesWithCertificateStore;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedChainTrustServerStream;
begin
  LMaterial := GenerateCASignedServerMaterial('example.com', ['DNS:example.com']);
  LCtx := NewClientContext([sslCertVerifyDefault]);
  ApplyTrustConfig(LCtx, tcStore, '');
  LStream := TScriptedChainTrustServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Certificate-store connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn.Connect,
      'Configured certificate store should allow scripted CA-signed certificate to connect');
  finally
    LStream.Free;
  end;
end;

procedure TestFactoryOneShotConfigPassesWithCAPath(const ACAPath: string);
var
  LCtx: ISSLContext;
begin
  LCtx := CreateFactoryOneShotTrustContext(tcCAPath, ACAPath);
  AssertCASignedHandshakePassesWithContext(LCtx,
    'Factory one-shot CAPath trust config');
end;

procedure TestFactoryDefaultConfigPassesWithCAFile;
var
  LCtx: ISSLContext;
begin
  LCtx := CreateFactoryDefaultConfigTrustContext(tcCAFile, '');
  AssertCASignedHandshakePassesWithContext(LCtx,
    'Factory default-config CAFile trust config');
end;

procedure TestFactoryDefaultConfigPassesWithCAPath(const ACAPath: string);
var
  LCtx: ISSLContext;
begin
  LCtx := CreateFactoryDefaultConfigTrustContext(tcCAPath, ACAPath);
  AssertCASignedHandshakePassesWithContext(LCtx,
    'Factory default-config CAPath trust config');
end;

procedure TestDirectLibraryDefaultConfigPassesWithCAFile;
var
  LLib: ISSLLibrary;
  LOriginalConfig: TSSLConfig;
  LConfig: TSSLConfig;
  LCtx: ISSLContext;
begin
  LLib := CreateInitializedFreePascalLibrary;
  try
    LOriginalConfig := LLib.GetDefaultConfig;
    LConfig := LOriginalConfig;
    ConfigureClientTrustConfig(LConfig, tcCAFile, '');
    LLib.SetDefaultConfig(LConfig);

    LCtx := LLib.CreateContext(sslCtxClient);
    AssertTrue(LCtx <> nil, 'Direct-library CAFile trust context should be created');
    LCtx.SetCertVerifyFlags([sslCertVerifyDefault]);
    AssertCASignedHandshakePassesWithContext(LCtx,
      'Direct-library default-config CAFile trust config');
  finally
    LLib.SetDefaultConfig(LOriginalConfig);
    LLib.Finalize;
  end;
end;

procedure TestDirectLibraryDefaultConfigPassesWithCAPath(const ACAPath: string);
var
  LLib: ISSLLibrary;
  LOriginalConfig: TSSLConfig;
  LConfig: TSSLConfig;
  LCtx: ISSLContext;
begin
  LLib := CreateInitializedFreePascalLibrary;
  try
    LOriginalConfig := LLib.GetDefaultConfig;
    LConfig := LOriginalConfig;
    ConfigureClientTrustConfig(LConfig, tcCAPath, ACAPath);
    LLib.SetDefaultConfig(LConfig);

    LCtx := LLib.CreateContext(sslCtxClient);
    AssertTrue(LCtx <> nil, 'Direct-library CAPath trust context should be created');
    LCtx.SetCertVerifyFlags([sslCertVerifyDefault]);
    AssertCASignedHandshakePassesWithContext(LCtx,
      'Direct-library default-config CAPath trust config');
  finally
    LLib.SetDefaultConfig(LOriginalConfig);
    LLib.Finalize;
  end;
end;

procedure TestSelfSignedCertificateFailsWithoutAllowFlag;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedChainTrustServerStream;
begin
  LMaterial := GenerateSelfSignedServerMaterial('example.com', ['DNS:example.com']);
  LCtx := NewClientContext([sslCertVerifyDefault]);
  LStream := TScriptedChainTrustServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Self-signed connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(not LConn.Connect,
      'Self-signed certificate should fail when allow-self-signed flag is absent');
    AssertEqualsInt(Ord(sslErrCertificateUntrusted), GetCertificateVerifyResult(LConn),
      'Untrusted self-signed certificate should surface sslErrCertificateUntrusted');
    AssertTrue(
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'trust') or
      ContainsTextInsensitive(GetCertificateVerifyResultString(LConn), 'untrusted'),
      'Self-signed failure should mention trust'
    );
  finally
    LStream.Free;
  end;
end;

procedure TestSelfSignedCertificatePassesWhenAllowed;
var
  LMaterial: TServerMaterial;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TScriptedChainTrustServerStream;
begin
  LMaterial := GenerateSelfSignedServerMaterial('example.com', ['DNS:example.com']);
  LCtx := NewClientContext([sslCertVerifyAllowSelfSigned]);
  LStream := TScriptedChainTrustServerStream.Create(LMaterial.CertificateBlob, LMaterial.PrivateKeyBlob);
  try
    LConn := LCtx.CreateConnection(LStream);
    AssertTrue(LConn <> nil, 'Allow-self-signed connection should be created');
    (LConn as ISSLClientConnection).SetServerName('example.com');

    AssertTrue(LConn.Connect,
      'Allow-self-signed flag should allow scripted self-signed certificate to connect');
  finally
    LStream.Free;
  end;
end;

var
  LCAPath: string;
begin
  WriteLn('Testing FreePascal client chain trust runtime parity...');

  LCAPath := EnsureCAPathFixture;

  TestVerifyResultDoesNotPretendSuccessBeforeHandshake;
  TestCASignedCertificateFailsWithoutTrust;
  TestCASignedCertificatePassesWithCAFile;
  TestCASignedCertificatePassesWithCAPath(LCAPath);
  TestCASignedCertificatePassesWithCertificateStore;
  TestFactoryOneShotConfigPassesWithCAPath(LCAPath);
  TestFactoryDefaultConfigPassesWithCAFile;
  TestFactoryDefaultConfigPassesWithCAPath(LCAPath);
  TestDirectLibraryDefaultConfigPassesWithCAFile;
  TestDirectLibraryDefaultConfigPassesWithCAPath(LCAPath);
  TestSelfSignedCertificateFailsWithoutAllowFlag;
  TestSelfSignedCertificatePassesWhenAllowed;

  WriteLn('✅ FreePascal client chain trust runtime checks passed');
end.
