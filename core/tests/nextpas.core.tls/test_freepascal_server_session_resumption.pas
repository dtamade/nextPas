program test_freepascal_server_session_resumption;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes, DateUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.tls.tls13.aead,
  nextpas.core.tls.crypto.x25519,
  nextpas.core.tls.tls13.finished,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.appschedule,
  nextpas.core.tls.tls13.posthandshake,
  nextpas.core.tls.crypto.hash,
  nextpas.core.tls.freepascal.session;

type
  TOfflineClientMode = (ocmInitial, ocmResumed, ocmResumedBadBinder);

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

procedure AssertEqualsWord(AExpected, AActual: Word; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=0x%.4x actual=0x%.4x)', [AMessage, AExpected, AActual]));
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

procedure AppendHandshakeBytes(var ADest: TBytes; const ASource: TBytes);
var
  LOldLen, LAppendLen: Integer;
begin
  LAppendLen := Length(ASource);
  if LAppendLen = 0 then
    Exit;

  LOldLen := Length(ADest);
  SetLength(ADest, LOldLen + LAppendLen);
  Move(ASource[0], ADest[LOldLen], LAppendLen);
end;

function TryPopHandshakeMessage(var ABuffer: TBytes; out AMessage: TBytes): Boolean;
var
  LMsgLen: Cardinal;
  LTotalLen: Integer;
  LRemainLen: Integer;
  LTemp: TBytes;
begin
  SetLength(AMessage, 0);
  Result := False;

  if Length(ABuffer) < 4 then
    Exit;

  LMsgLen := ReadUInt24(ABuffer, 1);
  if LMsgLen > Cardinal(High(Integer) - 4) then
    Exit;

  LTotalLen := 4 + Integer(LMsgLen);
  if Length(ABuffer) < LTotalLen then
    Exit;

  SetLength(AMessage, LTotalLen);
  Move(ABuffer[0], AMessage[0], LTotalLen);

  LRemainLen := Length(ABuffer) - LTotalLen;
  if LRemainLen > 0 then
  begin
    SetLength(LTemp, LRemainLen);
    Move(ABuffer[LTotalLen], LTemp[0], LRemainLen);
    ABuffer := LTemp;
  end
  else
    SetLength(ABuffer, 0);

  Result := True;
end;

type
  TOfflineTLS13ClientStream = class(TStream)
  private
    FMode: TOfflineClientMode;
    FReadBuffer: TBytes;
    FReadPosition: Int64;
    FWriteStage: Integer;
    FClientPrivateKey: TBytes;
    FClientPublicKey: TBytes;
    FClientHelloHandshake: TBytes;
    FTranscriptData: TBytes;
    FHandshakeSecrets: TTLS13HandshakeSecrets;
    FApplicationSecrets: TTLS13ApplicationSecrets;
    FResumeSession: IFreePascalResumptionSession;
    FResumeBaseSession: ISSLSession;
    FCapturedSession: ISSLSession;
    FNegotiatedCipherSuite: Word;
    FObservedServerSelectedPSK: Boolean;
    FObservedTicketIssued: Boolean;

    procedure Enqueue(const AData: TBytes);
    procedure PrepareClientHello;
    procedure HandleServerHello(const AData: TBytes);
    procedure HandleServerHandshakeFlight(const AData: TBytes);
    procedure HandleServerPostHandshake(const AData: TBytes);
  public
    constructor CreateInitial;
    constructor CreateResumed(const ASession: ISSLSession);
    constructor CreateResumedWithBadBinder(const ASession: ISSLSession);

    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;

    property CapturedSession: ISSLSession read FCapturedSession;
    property ObservedServerSelectedPSK: Boolean read FObservedServerSelectedPSK;
    property ObservedTicketIssued: Boolean read FObservedTicketIssued;
  end;

constructor TOfflineTLS13ClientStream.CreateInitial;
begin
  inherited Create;
  FMode := ocmInitial;
  SetLength(FReadBuffer, 0);
  FReadPosition := 0;
  FWriteStage := 0;
  SetLength(FTranscriptData, 0);
  InitTLS13HandshakeSecrets(FHandshakeSecrets);
  InitTLS13ApplicationSecrets(FApplicationSecrets);
  FResumeSession := nil;
  FCapturedSession := nil;
  FNegotiatedCipherSuite := 0;
  FObservedServerSelectedPSK := False;
  FObservedTicketIssued := False;
  PrepareClientHello;
end;

constructor TOfflineTLS13ClientStream.CreateResumed(const ASession: ISSLSession);
begin
  CreateInitial;
  FMode := ocmResumed;
  FResumeBaseSession := ASession;
  if not Supports(ASession, IFreePascalResumptionSession, FResumeSession) then
    raise Exception.Create('Resumed test requires FreePascal resumption session');
  PrepareClientHello;
end;

constructor TOfflineTLS13ClientStream.CreateResumedWithBadBinder(const ASession: ISSLSession);
begin
  CreateInitial;
  FMode := ocmResumedBadBinder;
  FResumeBaseSession := ASession;
  if not Supports(ASession, IFreePascalResumptionSession, FResumeSession) then
    raise Exception.Create('Resumed test requires FreePascal resumption session');
  PrepareClientHello;
end;

procedure TOfflineTLS13ClientStream.Enqueue(const AData: TBytes);
var
  LOldLen: Integer;
begin
  if Length(AData) = 0 then
    Exit;

  LOldLen := Length(FReadBuffer);
  SetLength(FReadBuffer, LOldLen + Length(AData));
  Move(AData[0], FReadBuffer[LOldLen], Length(AData));
end;

procedure TOfflineTLS13ClientStream.PrepareClientHello;
var
  LPskOffer: TTLS13ClientHelloPSKOffer;
  LPartialHandshake: TBytes;
  LSessionAgeMs: Int64;
  LClientHelloRecord: TBytes;
  LError: string;
begin
  SetLength(FReadBuffer, 0);
  FReadPosition := 0;
  SetLength(FTranscriptData, 0);
  FCapturedSession := nil;
  FObservedServerSelectedPSK := False;
  FObservedTicketIssued := False;

  GenerateX25519KeyPair(FClientPrivateKey, FClientPublicKey);

  if FMode in [ocmResumed, ocmResumedBadBinder] then
  begin
    FillChar(LPskOffer, SizeOf(LPskOffer), 0);
    LSessionAgeMs := MilliSecondsBetween(Now, FResumeBaseSession.GetCreationTime);
    if LSessionAgeMs < 0 then
      LSessionAgeMs := 0;

    LPskOffer.Valid := True;
    LPskOffer.Identity := FResumeSession.GetTicket;
    LPskOffer.ObfuscatedTicketAge :=
      Cardinal((QWord(LSessionAgeMs) + QWord(FResumeSession.GetTicketAgeAdd)) and $FFFFFFFF);
    FClientHelloHandshake := BuildTLS13ClientHelloHandshakeWithComputedPSKBinder(
      'localhost',
      '',
      FClientPublicKey,
      FResumeSession.GetCipherSuite,
      LPskOffer.Identity,
      LPskOffer.ObfuscatedTicketAge,
      FResumeSession.GetResumptionPSK,
      LPartialHandshake
    );
    if FMode = ocmResumedBadBinder then
    begin
      if not TryBuildTLS13ClientHelloPSKBinderTranscript(FClientHelloHandshake, LPartialHandshake, LError) then
        raise Exception.Create('Failed to rebuild PSK binder transcript for tampered-binder test: ' + LError);
      LPskOffer.Binder := TLS13ComputePSKBinderForCipherSuite(
        FResumeSession.GetCipherSuite,
        FResumeSession.GetResumptionPSK,
        LPartialHandshake
      );
      if Length(LPskOffer.Binder) = 0 then
        raise Exception.Create('Failed to derive binder for tampered-binder test');
      LPskOffer.Binder[0] := LPskOffer.Binder[0] xor $FF;
      FClientHelloHandshake := BuildTLS13ClientHelloHandshakeWithPSK(
        'localhost',
        '',
        FClientPublicKey,
        LPskOffer,
        LPartialHandshake
      );
    end;
  end
  else
    FClientHelloHandshake := BuildTLS13ClientHelloHandshake('localhost', '', FClientPublicKey);

  LClientHelloRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, FClientHelloHandshake);
  Enqueue(LClientHelloRecord);
end;

procedure TOfflineTLS13ClientStream.HandleServerHello(const AData: TBytes);
var
  LHandshake: TBytes;
  LInfo: TTLS13ServerHelloInfo;
  LSharedSecret: TBytes;
  LError: string;
begin
  if not TryExtractHandshakePayloadFromRecord(AData, LHandshake) then
    raise Exception.Create('Failed to extract ServerHello handshake payload');
  if not TryParseServerHelloFromHandshake(LHandshake, LInfo) then
    raise Exception.Create('Failed to parse ServerHello');
  if not LInfo.Valid then
    raise Exception.Create('Parsed ServerHello should be valid');
  if not LInfo.HasKeyShare then
    raise Exception.Create('ServerHello missing key_share');

  FNegotiatedCipherSuite := LInfo.SelectedCipherSuite;
  if FMode = ocmResumed then
  begin
    FObservedServerSelectedPSK := LInfo.HasPreSharedKey;
    if not FObservedServerSelectedPSK then
      raise Exception.Create('Resumed ServerHello missing pre_shared_key');
    AssertEqualsWord(0, LInfo.SelectedPSKIdentity,
      'Resumed ServerHello should select identity 0');
  end
  else if LInfo.HasPreSharedKey then
    raise Exception.Create('Initial full handshake should not select pre_shared_key');

  LSharedSecret := X25519ComputeSharedSecret(FClientPrivateKey, LInfo.PeerKeyShare);
  SetLength(FTranscriptData, Length(FClientHelloHandshake) + Length(LHandshake));
  Move(FClientHelloHandshake[0], FTranscriptData[0], Length(FClientHelloHandshake));
  Move(LHandshake[0], FTranscriptData[Length(FClientHelloHandshake)], Length(LHandshake));

  if FMode = ocmResumed then
  begin
    if not TryDeriveTLS13HandshakeSecretsWithPSK(
      FNegotiatedCipherSuite,
      LSharedSecret,
      FTranscriptData,
      FResumeSession.GetResumptionPSK,
      FHandshakeSecrets,
      LError
    ) then
      raise Exception.Create('Failed to derive resumed handshake secrets: ' + LError);
  end
  else
  begin
    if not TryDeriveTLS13HandshakeSecrets(
      FNegotiatedCipherSuite,
      LSharedSecret,
      FTranscriptData,
      FHandshakeSecrets,
      LError
    ) then
      raise Exception.Create('Failed to derive initial handshake secrets: ' + LError);
  end;
end;

procedure TOfflineTLS13ClientStream.HandleServerHandshakeFlight(const AData: TBytes);
var
  LHeader: TTLSRecordHeader;
  LPayload: TBytes;
  LPlaintext: TBytes;
  LInnerFragment: TBytes;
  LInnerContentType: Byte;
  LError: string;
  LBuffer: TBytes;
  LMessage: TBytes;
  LType: Byte;
  LVerifyData: TBytes;
  LTranscriptHash: TBytes;
  LClientFinished: TBytes;
  LInnerPlaintext: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
  LSawFinished: Boolean;
  LSawCertificate: Boolean;
  LSawCertificateVerify: Boolean;
begin
  if not ParseTLSRecordHeader(AData, LHeader) then
    raise Exception.Create('Failed to parse encrypted server handshake header');
  if Length(AData) < 5 + LHeader.Length then
    raise Exception.Create('Encrypted server handshake record is truncated');

  SetLength(LPayload, LHeader.Length);
  if LHeader.Length > 0 then
    Move(AData[5], LPayload[0], LHeader.Length);

  if not TryTLS13AEADDecrypt(
    FNegotiatedCipherSuite,
    FHandshakeSecrets.ServerHandshakeKey,
    BuildTLS13RecordNonce(FHandshakeSecrets.ServerHandshakeIV, 0),
    BuildTLS13RecordAAD(LHeader.Length),
    LPayload,
    LPlaintext,
    LError
  ) then
    raise Exception.Create('Failed to decrypt server handshake flight: ' + LError);

  if not TryParseTLS13InnerPlaintext(LPlaintext, LInnerFragment, LInnerContentType) then
    raise Exception.Create('Invalid TLSInnerPlaintext in server handshake flight');
  if LInnerContentType <> TLS_CONTENT_TYPE_HANDSHAKE then
    raise Exception.Create('Server handshake flight should carry handshake content');

  LBuffer := LInnerFragment;
  LSawFinished := False;
  LSawCertificate := False;
  LSawCertificateVerify := False;
  while TryPopHandshakeMessage(LBuffer, LMessage) do
  begin
    LType := LMessage[0];
    case LType of
      TLS_HANDSHAKE_TYPE_CERTIFICATE:
        LSawCertificate := True;
      TLS_HANDSHAKE_TYPE_CERTIFICATE_VERIFY:
        LSawCertificateVerify := True;
    end;

    if LType = TLS_HANDSHAKE_TYPE_FINISHED then
    begin
      SetLength(LVerifyData, Length(LMessage) - 4);
      if Length(LVerifyData) > 0 then
        Move(LMessage[4], LVerifyData[0], Length(LVerifyData));

      LTranscriptHash := HashTranscriptForSuite(FNegotiatedCipherSuite, FTranscriptData);
      if not TLS13VerifyFinishedForCipherSuite(
        FNegotiatedCipherSuite,
        FHandshakeSecrets.ServerHandshakeTrafficSecret,
        LTranscriptHash,
        LVerifyData
      ) then
        raise Exception.Create('Server Finished verification failed in scripted client');

      AppendHandshakeBytes(FTranscriptData, LMessage);
      LSawFinished := True;
    end
    else
      AppendHandshakeBytes(FTranscriptData, LMessage);
  end;

  if not LSawFinished then
    raise Exception.Create('Server handshake flight should include Finished');

  if FMode = ocmInitial then
  begin
    if not LSawCertificate then
      raise Exception.Create('Initial server handshake should include Certificate');
    if not LSawCertificateVerify then
      raise Exception.Create('Initial server handshake should include CertificateVerify');
  end
  else
  begin
    if LSawCertificate then
      raise Exception.Create('Resumed server handshake must not include Certificate');
    if LSawCertificateVerify then
      raise Exception.Create('Resumed server handshake must not include CertificateVerify');
  end;

  LVerifyData := TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(
    FNegotiatedCipherSuite,
    FHandshakeSecrets.ClientHandshakeTrafficSecret,
    HashTranscriptForSuite(FNegotiatedCipherSuite, FTranscriptData)
  );

  SetLength(LClientFinished, 0);
  AppendByte(LClientFinished, TLS_HANDSHAKE_TYPE_FINISHED);
  AppendUInt24(LClientFinished, Length(LVerifyData));
  AppendBytes(LClientFinished, LVerifyData);

  LInnerPlaintext := BuildTLS13InnerPlaintext(LClientFinished, TLS_CONTENT_TYPE_HANDSHAKE);
  if not TryTLS13AEADEncrypt(
    FNegotiatedCipherSuite,
    FHandshakeSecrets.ClientHandshakeKey,
    BuildTLS13RecordNonce(FHandshakeSecrets.ClientHandshakeIV, 0),
    BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(FNegotiatedCipherSuite))),
    LInnerPlaintext,
    LEncrypted,
    LError
  ) then
    raise Exception.Create('Failed to encrypt scripted client Finished: ' + LError);

  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
  Enqueue(LRecord);

  { Derive application secrets BEFORE appending Client Finished to transcript
    because RFC 8446 requires Transcript-Hash(CH..SF) only. }
  if not TryDeriveTLS13ApplicationSecrets(
    FNegotiatedCipherSuite,
    FHandshakeSecrets.HandshakeSecret,
    FTranscriptData,
    FApplicationSecrets,
    LError
  ) then
    raise Exception.Create('Failed to derive scripted client application secrets: ' + LError);

  AppendHandshakeBytes(FTranscriptData, LClientFinished);

  { RFC 8446 Section 7.1: resumption_master_secret uses Hash(CH..CF) }
  FApplicationSecrets.ResumptionTranscriptHash := HashTranscriptForSuite(
    FNegotiatedCipherSuite, FTranscriptData
  );
end;

procedure TOfflineTLS13ClientStream.HandleServerPostHandshake(const AData: TBytes);
var
  LHeader: TTLSRecordHeader;
  LPayload: TBytes;
  LPlaintext: TBytes;
  LInnerFragment: TBytes;
  LInnerContentType: Byte;
  LError: string;
  LTicket: TTLS13NewSessionTicket;
  LResumptionPSK: TBytes;
  LSession: TFreePascalSession;
begin
  if not ParseTLSRecordHeader(AData, LHeader) then
    raise Exception.Create('Failed to parse server post-handshake header');
  if Length(AData) < 5 + LHeader.Length then
    raise Exception.Create('Server post-handshake record is truncated');

  SetLength(LPayload, LHeader.Length);
  if LHeader.Length > 0 then
    Move(AData[5], LPayload[0], LHeader.Length);

  if not TryTLS13AEADDecrypt(
    FNegotiatedCipherSuite,
    FApplicationSecrets.ServerApplicationKey,
    BuildTLS13RecordNonce(FApplicationSecrets.ServerApplicationIV, 0),
    BuildTLS13RecordAAD(LHeader.Length),
    LPayload,
    LPlaintext,
    LError
  ) then
    raise Exception.Create('Failed to decrypt server post-handshake record: ' + LError);

  if not TryParseTLS13InnerPlaintext(LPlaintext, LInnerFragment, LInnerContentType) then
    raise Exception.Create('Invalid TLSInnerPlaintext in server post-handshake record');
  if LInnerContentType <> TLS_CONTENT_TYPE_HANDSHAKE then
    raise Exception.Create('Server post-handshake record should carry handshake content');

  if not TryParseTLS13NewSessionTicket(LInnerFragment, LTicket, LError) then
    raise Exception.Create('Failed to parse NewSessionTicket from server: ' + LError);

  LResumptionPSK := TLS13DeriveResumptionPSKFromTranscriptHash(
    FApplicationSecrets.CipherSuite,
    FApplicationSecrets.MasterSecret,
    FApplicationSecrets.ResumptionTranscriptHash,
    LTicket.TicketNonce
  );

  LSession := TFreePascalSession.Create;
  LSession.ConfigureResumption(
    FApplicationSecrets.CipherSuite,
    TLS13CipherSuiteToString(FApplicationSecrets.CipherSuite),
    LTicket.TicketNonce,
    LTicket.Ticket,
    LResumptionPSK,
    LTicket.TicketLifetime,
    LTicket.TicketAgeAdd,
    Now,
    Integer(LTicket.TicketLifetime)
  );
  FCapturedSession := LSession;
  FObservedTicketIssued := True;
end;

function TOfflineTLS13ClientStream.Read(var Buffer; Count: Longint): Longint;
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

function TOfflineTLS13ClientStream.Write(const Buffer; Count: Longint): Longint;
var
  LData: TBytes;
  LOffset, LRecLen: Integer;
  LRecord: TBytes;
begin
  SetLength(LData, Count);
  if Count > 0 then
    Move(Buffer, LData[0], Count);

  LOffset := 0;
  while LOffset + 5 <= Length(LData) do
  begin
    LRecLen := (Integer(LData[LOffset + 3]) shl 8) or Integer(LData[LOffset + 4]);
    if (LData[LOffset] = $14) or (LData[LOffset] = $15) then
    begin
      Inc(LOffset, 5 + LRecLen);
      Continue;
    end;
    LRecord := Copy(LData, LOffset, 5 + LRecLen);
    case FWriteStage of
      0:
        begin
          HandleServerHello(LRecord);
          FWriteStage := 1;
        end;
      1:
        begin
          HandleServerHandshakeFlight(LRecord);
          FWriteStage := 2;
        end;
    else
      HandleServerPostHandshake(LRecord);
    end;
    Inc(LOffset, 5 + LRecLen);
  end;

  Result := Count;
end;

function TOfflineTLS13ClientStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning: FReadPosition := Offset;
    soCurrent: Inc(FReadPosition, Offset);
    soEnd: FReadPosition := Length(FReadBuffer) + Offset;
  end;
  Result := FReadPosition;
end;

procedure TestFreePascalServerIssuesTicketAndAcceptsResumedPSK;
var
  LCtx: ISSLContext;
  LConn1: ISSLConnection;
  LConn2: ISSLConnection;
  LResumption1: ISSLSessionResumption;
  LResumption2: ISSLSessionResumption;
  LStream1: TOfflineTLS13ClientStream;
  LStream2: TOfflineTLS13ClientStream;
  LSession: ISSLSession;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil, 'FreePascal server context should be created');
  LCtx.SetPreferredVersion(sslProtocolTLS13);
  LCtx.SetSessionCacheMode(True);
  LCtx.SetSessionTimeout(7200);
  LCtx.SetSessionCacheSize(8);
  LCtx.LoadCertificate('tests/certificate/test_certs/signer_cert.pem');
  LCtx.LoadPrivateKey('tests/certificate/test_certs/signer_key.pem');

  LStream1 := TOfflineTLS13ClientStream.CreateInitial;
  try
    LConn1 := LCtx.CreateConnection(LStream1);
    AssertTrue(LConn1 <> nil, 'Initial server connection should be created');
    AssertTrue(Supports(LConn1, ISSLSessionResumption, LResumption1),
      'Initial server connection should expose ISSLSessionResumption');
    AssertTrue(LConn1.Accept, 'Initial server accept should succeed');
    AssertTrue(not LResumption1.IsSessionReused, 'Initial server accept must not report session reuse');
    AssertTrue(LStream1.ObservedTicketIssued, 'Initial server accept should issue a NewSessionTicket');
    LSession := LStream1.CapturedSession;
    AssertTrue(LSession <> nil, 'Initial server accept should yield a resumable client-captured session');
    AssertTrue(LSession.IsResumable, 'Client-captured session should be resumable');
  finally
    LStream1.Free;
  end;

  LStream2 := TOfflineTLS13ClientStream.CreateResumed(LSession);
  try
    LConn2 := LCtx.CreateConnection(LStream2);
    AssertTrue(LConn2 <> nil, 'Resumed server connection should be created');
    AssertTrue(Supports(LConn2, ISSLSessionResumption, LResumption2),
      'Resumed server connection should expose ISSLSessionResumption');
    AssertTrue(LConn2.Accept, 'Resumed server accept should succeed');
    AssertTrue(LResumption2.IsSessionReused, 'Resumed server accept should report session reuse');
    AssertTrue(LStream2.ObservedServerSelectedPSK,
      'Resumed server accept should emit pre_shared_key(selected_identity=0) in ServerHello');
  finally
    LStream2.Free;
  end;
end;

procedure TestFreePascalServerRejectsInvalidResumptionBinder;
var
  LCtx: ISSLContext;
  LConn1: ISSLConnection;
  LConn2: ISSLConnection;
  LResumption1: ISSLSessionResumption;
  LResumption2: ISSLSessionResumption;
  LStream1: TOfflineTLS13ClientStream;
  LStream2: TOfflineTLS13ClientStream;
  LSession: ISSLSession;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  AssertTrue(LCtx <> nil, 'FreePascal server context should be created');
  LCtx.SetPreferredVersion(sslProtocolTLS13);
  LCtx.SetSessionCacheMode(True);
  LCtx.SetSessionTimeout(7200);
  LCtx.SetSessionCacheSize(8);
  LCtx.LoadCertificate('tests/certificate/test_certs/signer_cert.pem');
  LCtx.LoadPrivateKey('tests/certificate/test_certs/signer_key.pem');

  LStream1 := TOfflineTLS13ClientStream.CreateInitial;
  try
    LConn1 := LCtx.CreateConnection(LStream1);
    AssertTrue(LConn1 <> nil, 'Initial server connection should be created');
    AssertTrue(Supports(LConn1, ISSLSessionResumption, LResumption1),
      'Initial server connection should expose ISSLSessionResumption');
    AssertTrue(LConn1.Accept, 'Initial server accept should succeed');
    LSession := LStream1.CapturedSession;
    AssertTrue(LSession <> nil, 'Initial server accept should yield a resumable client-captured session');
  finally
    LStream1.Free;
  end;

  LStream2 := TOfflineTLS13ClientStream.CreateResumedWithBadBinder(LSession);
  try
    LConn2 := LCtx.CreateConnection(LStream2);
    AssertTrue(LConn2 <> nil, 'Tampered-binder server connection should be created');
    AssertTrue(Supports(LConn2, ISSLSessionResumption, LResumption2),
      'Tampered-binder server connection should expose ISSLSessionResumption');
    AssertTrue(not LConn2.Accept, 'Server accept with tampered PSK binder should fail closed');
    AssertTrue(not LResumption2.IsSessionReused, 'Failed PSK accept must not report session reuse');
    AssertTrue(LConn2.GetError(-1) = sslErrHandshake,
      'Tampered PSK binder should surface handshake error');
  finally
    LStream2.Free;
  end;
end;

begin
  WriteLn('Testing FreePascal server session resumption contract...');

  TestFreePascalServerIssuesTicketAndAcceptsResumedPSK;
  TestFreePascalServerRejectsInvalidResumptionBinder;

  WriteLn('✅ FreePascal server session resumption checks passed');
end.
