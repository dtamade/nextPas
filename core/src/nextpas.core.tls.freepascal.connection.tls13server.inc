function TFreePascalConnection.DoAccept: Boolean;
var
  LHeader: TTLSRecordHeader;
  LPayloadBytes: TBytes;
  LRecordBytes: TBytes;
  LHandshakePayload: TBytes;
  LHandshakeBuffer: TBytes;
  LHandshakeMessage: TBytes;
  LInnerPlaintext: TBytes;
  LInnerFragment: TBytes;
  LInnerContentType: Byte;
  LAAD: TBytes;
  LNonce: TBytes;
  LPlaintext: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
  LClientHello: TTLS13ClientHelloInfo;
  LParseError: string;
  LRecordIndex: Integer;
  LSelectedCipherSuite: Word;
  LClientHelloHandshake: TBytes;
  LServerHelloHandshake: TBytes;
  LServerHelloRecord: TBytes;
  LTranscriptData: TBytes;
  LKeyScheduleError: string;
  LError: string;
  LEncryptedExtensionsMessage: TBytes;
  LFinishedMessage: TBytes;
  LServerFlightMessages: TBytes;
  LTranscriptHash: TBytes;
  LVerifyData: TBytes;
  LMsgType: Byte;
  LMsgLen: Cardinal;
  LClientFinishedReceived: Boolean;
  LAlertLevel: Byte;
  LAlertDescription: Byte;
  LContextMaterial: IFreePascalContextMaterial;
  LContextCipherSuites: IFreePascalContextCipherSuites;
  LStaplingMaterial: IFreePascalContextServerStaplingMaterial;
  LEarlyDataContext: ISSLEarlyDataContext;
  LResumptionCache: IFreePascalResumptionCache;
  LEarlyDataReplayAccess: IFreePascalEarlyDataReplayLedgerAccess;
  LEarlyDataReplayLedger: IFreePascalEarlyDataReplayLedger;
  LCertificateBlob: TBytes;
  LPrivateKeyBlob: TBytes;
  LServerStapledOCSPResponse: TBytes;
  LLeafCertificateDER: TBytes;
  LCertificateMessage: TBytes;
  LCertificateVerifyMessage: TBytes;
  LCachedSession: ISSLSession;
  LCachedResumption: IFreePascalResumptionSession;
  LSignatureScheme: Word;
  LSignatureSchemeError: string;
  LLeafCertificate: TX509Certificate;
  LLeafKeyType: string;
  LCertVerifyInput: TBytes;
  LCertVerifySignature: TBytes;
  LSignatureLength: Integer;
  LResumedHandshake: Boolean;
  LEarlyDataOffered: Boolean;
  LEarlyDataAccepted: Boolean;
  LEarlyDataEndObserved: Boolean;
  LBinderTranscript: TBytes;
  LExpectedBinder: TBytes;
  LTicketNonce: TBytes;
  LTicket: TBytes;
  LTicketExtensions: TBytes;
  LTicketHandshake: TBytes;
  LTicketAgeAddBytes: TBytes;
  LTicketAgeAdd: Cardinal;
  LTicketLifetime: Cardinal;
  LIssuedMaxEarlyDataSize: Cardinal;
  LIssuedSession: TFreePascalSession;
  LEarlyDataBuffer: TBytes;
  LClientRequestedOCSPStapling: Boolean;
  LServerCipherSuites: TFreePascalCipherSuiteList;
begin
  Result := False;
  FSelectedALPNProtocol := '';
  SetLength(FHandshakeSharedSecret, 0);
  InitTLS13EarlyDataSecrets(FEarlyDataSecrets);
  ClearTLS13HandshakeSecrets(FHandshakeSecrets);
  SetLength(FServerFinishedKey, 0);
  SetLength(FClientFinishedKey, 0);
  FEarlyDataSeq := 0;
  FServerHandshakeSeq := 0;
  FClientHandshakeSeq := 0;
  FPeerRecordSizeLimit := TLS13_RECORD_SIZE_LIMIT_DEFAULT;

  ClearTLS13ApplicationSecrets(FApplicationSecrets);
  FClientApplicationSeq := 0;
  FServerApplicationSeq := 0;
  SetLength(FApplicationReadBuffer, 0);
  SetLength(FPostHandshakeBuffer, 0);
  FSessionTicketCount := 0;
  InitTLS13NewSessionTicket(FLastSessionTicket);
  FIsServerMode := False;
  FCurrentSession := nil;
  FSessionReused := False;
  FEarlyDataStatus := sslEarlyDataNone;
  FEarlyDataLimit := 0;
  SetLength(FEarlyDataPayload, 0);
  SetLength(LEarlyDataBuffer, 0);
  SetLength(LServerStapledOCSPResponse, 0);
  LClientRequestedOCSPStapling := False;
  LLeafKeyType := '';

  if (FProtocolVersion <> sslProtocolTLS13) and (FProtocolVersion <> sslProtocolTLS12) then
  begin
    MarkUnsupported('Accept requires TLS 1.2 or TLS 1.3');
    Exit;
  end;

  SetLength(LHandshakeBuffer, 0);
  SetLength(LClientHelloHandshake, 0);
  for LRecordIndex := 1 to 8 do
  begin
    if not RecvTLSRecord(LHeader, LPayloadBytes, LRecordBytes) then
    begin
      SetHandshakeError(sslErrIO, 'Failed to receive TLS record while waiting for ClientHello');
      Exit;
    end;

    case LHeader.ContentType of
      TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC:
        Continue;

      TLS_CONTENT_TYPE_ALERT:
        begin
          SetHandshakeError(sslErrHandshake, 'Peer sent TLS alert before ClientHello');
          Exit;
        end;

      TLS_CONTENT_TYPE_HANDSHAKE:
        begin
          if not TryExtractHandshakePayloadFromRecord(LRecordBytes, LHandshakePayload) then
          begin
            SetHandshakeError(sslErrProtocol, 'Peer handshake record format is invalid');
            Exit;
          end;

          AppendHandshakeBytes(LHandshakeBuffer, LHandshakePayload);

          while TryPopHandshakeMessage(LHandshakeBuffer, LHandshakeMessage) do
          begin
            if Length(LHandshakeMessage) < 4 then
            begin
              SetHandshakeError(sslErrProtocol, 'Malformed handshake message before ClientHello');
              Exit;
            end;

            if LHandshakeMessage[0] <> TLS_HANDSHAKE_TYPE_CLIENT_HELLO then
            begin
              SetHandshakeError(
                sslErrProtocol,
                Format('Expected ClientHello, got handshake type %d', [LHandshakeMessage[0]])
              );
              Exit;
            end;

            if not TryParseTLS13ClientHelloFromHandshake(LHandshakeMessage, LClientHello, LParseError) then
            begin
              SetHandshakeError(sslErrProtocol, 'Invalid ClientHello: ' + LParseError);
              Exit;
            end;

            LClientHelloHandshake := LHandshakeMessage;
            if LClientHello.HasRecordSizeLimit then
              FPeerRecordSizeLimit := LClientHello.RecordSizeLimit
            else
              FPeerRecordSizeLimit := TLS13_RECORD_SIZE_LIMIT_DEFAULT;
            LClientRequestedOCSPStapling := ClientHelloHasExtension(
              LClientHelloHandshake,
              TLS_EXTENSION_STATUS_REQUEST
            );
            Break;
          end;

          if Length(LClientHelloHandshake) > 0 then
            Break;
        end;

    else
      begin
        SetHandshakeError(
          sslErrProtocol,
          Format('Unexpected TLS record type %d before ClientHello', [LHeader.ContentType])
        );
        Exit;
      end;
    end;
  end;

  if Length(LClientHelloHandshake) = 0 then
  begin
    SetHandshakeError(sslErrProtocol, 'ClientHello not received in expected handshake records');
    Exit;
  end;

  if (not LClientHello.HasSupportedVersions) or
     (not TLS13ClientHelloSupportsVersion(LClientHello, TLS13_VERSION)) then
  begin
    // Client doesn't support TLS 1.3 — fall back to TLS 1.2
    Result := DoAcceptTLS12Fallback(LRecordBytes);
    Exit;
  end;

  LResumedHandshake := False;
  LEarlyDataOffered := False;
  LEarlyDataAccepted := False;
  LEarlyDataEndObserved := True;
  LSelectedCipherSuite := 0;
  LCachedSession := nil;
  LCachedResumption := nil;
  if LClientHello.HasPreSharedKey and
    Supports(FContext, IFreePascalResumptionCache, LResumptionCache) then
  begin
    if not TryBuildTLS13ClientHelloPSKBinderTranscript(LClientHelloHandshake, LBinderTranscript, LParseError) then
    begin
      SetHandshakeError(sslErrProtocol, 'Failed to rebuild ClientHello PSK binder transcript: ' + LParseError);
      Exit;
    end;

    if LResumptionCache.TryGetResumptionSession(LClientHello.FirstPSKIdentity, LCachedSession) and
      Supports(LCachedSession, IFreePascalResumptionSession, LCachedResumption) and
      TLS13ClientHelloOffersCipherSuite(LClientHello, LCachedResumption.GetCipherSuite) then
    begin
      LExpectedBinder := TLS13ComputePSKBinderForCipherSuite(
        LCachedResumption.GetCipherSuite,
        LCachedResumption.GetResumptionPSK,
        LBinderTranscript
      );
      if not BytesEqual(LExpectedBinder, LClientHello.FirstPSKBinder) then
      begin
        SetHandshakeError(sslErrHandshake, 'ClientHello PSK binder verification failed');
        Exit;
      end;

      LSelectedCipherSuite := LCachedResumption.GetCipherSuite;
      LResumedHandshake := True;

      if LClientHello.HasEarlyData then
      begin
        if not TryDeriveTLS13ClientEarlyDataSecrets(
          LCachedResumption.GetCipherSuite,
          LCachedResumption.GetResumptionPSK,
          LClientHelloHandshake,
          FEarlyDataSecrets,
          LKeyScheduleError
        ) then
        begin
          SetHandshakeError(
            sslErrUnsupported,
            'TLS 1.3 server early-data key schedule derivation failed: ' + LKeyScheduleError
          );
          Exit;
        end;

        LEarlyDataOffered := True;
        FEarlyDataLimit := LCachedResumption.GetMaxEarlyDataSize;
        FEarlyDataStatus := sslEarlyDataRejected;
        LEarlyDataEndObserved := False;
        LEarlyDataReplayLedger := nil;

        if Supports(FContext, IFreePascalEarlyDataReplayLedgerAccess, LEarlyDataReplayAccess) then
          LEarlyDataReplayLedger := LEarlyDataReplayAccess.GetEarlyDataReplayLedger;
        if (LEarlyDataReplayLedger = nil) and
          Supports(FContext, IFreePascalEarlyDataReplayLedger, LEarlyDataReplayLedger) then;

        if (FEarlyDataLimit > 0) and
          Supports(FContext, ISSLEarlyDataContext, LEarlyDataContext) and
          (LEarlyDataContext.GetServerEarlyDataPolicy = sslEarlyDataServerAccept) and
          (LEarlyDataReplayLedger <> nil) and
          LEarlyDataReplayLedger.TryAcquireEarlyDataSession(LCachedSession) then
        begin
          LEarlyDataAccepted := True;
          FEarlyDataStatus := sslEarlyDataAccepted;
        end;
      end;
    end;
  end;

  if not LResumedHandshake then
  begin
    if Supports(FContext, IFreePascalContextCipherSuites, LContextCipherSuites) then
      LServerCipherSuites := LContextCipherSuites.GetConfiguredCipherSuites13
    else
      SetLength(LServerCipherSuites, 0);

    if Length(LServerCipherSuites) > 0 then
    begin
      { Select first server-preferred cipher that client also offers }
      for LRecordIndex := 0 to High(LServerCipherSuites) do
        if TLS13ClientHelloOffersCipherSuite(LClientHello, LServerCipherSuites[LRecordIndex]) then
        begin
          LSelectedCipherSuite := LServerCipherSuites[LRecordIndex];
          Break;
        end;
    end
    else
    begin
      { Default preference order }
      if TLS13ClientHelloOffersCipherSuite(LClientHello, TLS13_CIPHER_AES_256_GCM_SHA384) then
        LSelectedCipherSuite := TLS13_CIPHER_AES_256_GCM_SHA384
      else if TLS13ClientHelloOffersCipherSuite(LClientHello, TLS13_CIPHER_CHACHA20_POLY1305_SHA256) then
        LSelectedCipherSuite := TLS13_CIPHER_CHACHA20_POLY1305_SHA256
      else if TLS13ClientHelloOffersCipherSuite(LClientHello, TLS13_CIPHER_AES_128_GCM_SHA256) then
        LSelectedCipherSuite := TLS13_CIPHER_AES_128_GCM_SHA256;
    end;
  end;

  if LSelectedCipherSuite = 0 then
  begin
    SetHandshakeError(
      sslErrUnsupported,
      'No supported TLS 1.3 cipher suite intersection (requires TLS_AES_256_GCM_SHA384 or TLS_CHACHA20_POLY1305_SHA256 or TLS_AES_128_GCM_SHA256 for current pure FreePascal path)'
    );
    Exit;
  end;

  FProtocolVersion := sslProtocolTLS13;
  FCipherName := TLS13CipherSuiteToString(LSelectedCipherSuite);
  FSelectedALPNProtocol := SelectALPNProtocol(LClientHello, FALPNProtocols);

  if not LResumedHandshake then
  begin
    if not Supports(FContext, IFreePascalContextMaterial, LContextMaterial) then
    begin
      SetHandshakeError(sslErrUnsupported, 'FreePascal context does not expose certificate material interface');
      Exit;
    end;

    if not LContextMaterial.HasCertificateMaterial then
    begin
      SetHandshakeError(sslErrInvalidParam, 'Server context requires certificate material (LoadCertificate)');
      Exit;
    end;

    if not LContextMaterial.HasPrivateKeyMaterial then
    begin
      SetHandshakeError(sslErrInvalidParam, 'Server context requires private key material (LoadPrivateKey)');
      Exit;
    end;

    LCertificateBlob := LContextMaterial.GetCertificateMaterial;
    LPrivateKeyBlob := LContextMaterial.GetPrivateKeyMaterial;

    if LClientRequestedOCSPStapling and
      Supports(FContext, IFreePascalContextServerStaplingMaterial, LStaplingMaterial) and
      LStaplingMaterial.HasServerStapledOCSPResponse then
      LServerStapledOCSPResponse := LStaplingMaterial.GetServerStapledOCSPResponse;

    if not TryBuildTLS13ServerCertificateHandshakeWithStapledOCSP(
      LCertificateBlob,
      LServerStapledOCSPResponse,
      LCertificateMessage,
      LError
    ) then
    begin
      SetHandshakeError(sslErrInvalidParam, 'Failed to build TLS 1.3 Certificate message: ' + LError);
      Exit;
    end;

    if not TryExtractLeafCertificateDERFromBlob(LCertificateBlob, LLeafCertificateDER, LError) then
    begin
      SetHandshakeError(sslErrInvalidParam, 'Failed to extract leaf certificate for CertificateVerify metadata: ' + LError);
      Exit;
    end;
  end;
  if not LClientHello.HasKeyShare then
  begin
    SetHandshakeError(sslErrProtocol, 'ClientHello missing key_share extension');
    Exit;
  end;

  case LClientHello.KeyShareGroup of
    TLS13_GROUP_X25519:
      begin
        if Length(LClientHello.PeerKeyShare) <> 32 then
        begin
          SetHandshakeError(sslErrProtocol, 'Invalid X25519 key_share length from client');
          Exit;
        end;
        try
          FX25519PrivateKey := GenerateX25519PrivateKey;
          FX25519PublicKey := X25519PublicKeyFromPrivate(FX25519PrivateKey);
          FHandshakeSharedSecret := X25519ComputeSharedSecret(FX25519PrivateKey, LClientHello.PeerKeyShare);
        except
          on E: Exception do
          begin
            SetHandshakeError(sslErrHandshake, 'X25519 key exchange failed: ' + E.Message);
            Exit;
          end;
        end;
      end;
    TLS13_GROUP_SECP256R1:
      begin
        if Length(LClientHello.PeerKeyShare) <> 65 then
        begin
          SetHandshakeError(sslErrProtocol, 'Invalid P-256 key_share length from client');
          Exit;
        end;
        if not TryP256ECDHEServerKeyExchange(
          LClientHello.PeerKeyShare, FX25519PublicKey, FHandshakeSharedSecret, LError
        ) then
        begin
          SetHandshakeError(sslErrHandshake, 'P-256 key exchange failed: ' + LError);
          Exit;
        end;
      end;
    TLS13_GROUP_SECP384R1:
      begin
        if Length(LClientHello.PeerKeyShare) <> 97 then
        begin
          SetHandshakeError(sslErrProtocol, 'Invalid P-384 key_share length from client');
          Exit;
        end;
        if not TryP384ECDHEServerKeyExchange(
          LClientHello.PeerKeyShare, FX25519PublicKey, FHandshakeSharedSecret, LError
        ) then
        begin
          SetHandshakeError(sslErrHandshake, 'P-384 key exchange failed: ' + LError);
          Exit;
        end;
      end;
  else
    SetHandshakeError(sslErrUnsupported, Format(
      'Unsupported key_share group 0x%.4x from client', [LClientHello.KeyShareGroup]));
    Exit;
  end;

  try
    if LResumedHandshake then
      LServerHelloHandshake := BuildTLS13ServerHelloHandshakeWithSelectedPSK(
        LClientHello.LegacySessionID,
        LSelectedCipherSuite,
        FX25519PublicKey,
        0,
        LClientHello.KeyShareGroup
      )
    else
      LServerHelloHandshake := BuildTLS13ServerHelloHandshake(
        LClientHello.LegacySessionID,
        LSelectedCipherSuite,
        FX25519PublicKey,
        LClientHello.KeyShareGroup
      );
  except
    on E: Exception do
    begin
      SetHandshakeError(sslErrProtocol, 'Failed to build ServerHello: ' + E.Message);
      Exit;
    end;
  end;

  LServerHelloRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, LServerHelloHandshake);
  if not SendAll(LServerHelloRecord) then
  begin
    SetHandshakeError(sslErrIO, 'Failed to send ServerHello');
    Exit;
  end;

  SetLength(LTranscriptData, Length(LClientHelloHandshake) + Length(LServerHelloHandshake));
  if Length(LClientHelloHandshake) > 0 then
    Move(LClientHelloHandshake[0], LTranscriptData[0], Length(LClientHelloHandshake));
  if Length(LServerHelloHandshake) > 0 then
    Move(LServerHelloHandshake[0], LTranscriptData[Length(LClientHelloHandshake)], Length(LServerHelloHandshake));

  if LResumedHandshake then
  begin
    if not TryDeriveTLS13HandshakeSecretsWithPSK(
      LSelectedCipherSuite,
      FHandshakeSharedSecret,
      LTranscriptData,
      LCachedResumption.GetResumptionPSK,
      FHandshakeSecrets,
      LKeyScheduleError
    ) then
    begin
      SetHandshakeError(sslErrUnsupported, 'TLS 1.3 server PSK handshake key schedule derivation failed: ' + LKeyScheduleError);
      Exit;
    end;
    FSessionReused := True;
  end
  else if not TryDeriveTLS13HandshakeSecrets(
    LSelectedCipherSuite,
    FHandshakeSharedSecret,
    LTranscriptData,
    FHandshakeSecrets,
    LKeyScheduleError
  ) then
  begin
    SetHandshakeError(sslErrUnsupported, 'TLS 1.3 server handshake key schedule derivation failed: ' + LKeyScheduleError);
    Exit;
  end;

  try
    FServerFinishedKey := TLS13FinishedKeyForCipherSuite(
      LSelectedCipherSuite,
      FHandshakeSecrets.ServerHandshakeTrafficSecret
    );
    FClientFinishedKey := TLS13FinishedKeyForCipherSuite(
      LSelectedCipherSuite,
      FHandshakeSecrets.ClientHandshakeTrafficSecret
    );
  except
    on E: Exception do
    begin
      SetHandshakeError(sslErrHandshake, 'TLS 1.3 server finished-key derivation failed: ' + E.Message);
      Exit;
    end;
  end;

  if not TLS13AEADIsSupported(LSelectedCipherSuite) then
  begin
    SetHandshakeError(
      sslErrUnsupported,
      Format('Cipher suite %s is unsupported by pure FreePascal server handshake path',
        [TLS13CipherSuiteToString(LSelectedCipherSuite)])
    );
    Exit;
  end;

  LEncryptedExtensionsMessage := BuildTLS13EncryptedExtensionsHandshake(
    LEarlyDataAccepted,
    FSelectedALPNProtocol,
    FLocalRecordSizeLimit
  );

  SetLength(LServerFlightMessages, 0);
  AppendHandshakeBytes(LServerFlightMessages, LEncryptedExtensionsMessage);
  AppendHandshakeBytes(LTranscriptData, LEncryptedExtensionsMessage);

  if not LResumedHandshake then
  begin
    AppendHandshakeBytes(LServerFlightMessages, LCertificateMessage);
    AppendHandshakeBytes(LTranscriptData, LCertificateMessage);

    LLeafCertificate := TX509Certificate.Create;
    try
      try
        LLeafCertificate.LoadFromDER(LLeafCertificateDER);
      except
        on E: Exception do
        begin
          SetHandshakeError(sslErrInvalidParam, 'Failed to parse leaf certificate DER: ' + E.Message);
          Exit;
        end;
      end;

      if SameText(LLeafCertificate.PublicKeyInfo.KeyType, 'RSA') then
      begin
        LLeafKeyType := 'RSA';
        LSignatureLength := (LLeafCertificate.PublicKeyInfo.KeySize + 7) div 8;
        if LSignatureLength <= 0 then
          LSignatureLength := Length(LLeafCertificate.PublicKeyInfo.RSAModulus);
      end
      else if SameText(LLeafCertificate.PublicKeyInfo.KeyType, 'ECDSA') then
      begin
        LLeafKeyType := 'ECDSA';
        LSignatureLength := 72
      end
      else
        LSignatureLength := 0;
    finally
      LLeafCertificate.Free;
    end;

    if LSignatureLength <= 0 then
    begin
      SetHandshakeError(sslErrUnsupported, 'Unsupported leaf certificate key type for TLS 1.3 CertificateVerify');
      Exit;
    end;

    if not TrySelectTLS13ServerCertificateVerifySchemeForKeyTypeAndCipherSuite(
      LClientHello,
      LLeafKeyType,
      LSelectedCipherSuite,
      LSignatureScheme,
      LSignatureSchemeError
    ) then
    begin
      SetHandshakeError(sslErrUnsupported, LSignatureSchemeError);
      Exit;
    end;

    if Length(LPrivateKeyBlob) = 0 then
    begin
      SetHandshakeError(sslErrInvalidParam, 'Server private key material is empty');
      Exit;
    end;

    LTranscriptHash := HashTLS13TranscriptForSuite(LSelectedCipherSuite, LTranscriptData);
    if Length(LTranscriptHash) = 0 then
    begin
      SetHandshakeError(
        sslErrUnsupported,
        'Unsupported TLS 1.3 cipher suite for server CertificateVerify transcript hashing: ' +
        TLS13CipherSuiteToString(LSelectedCipherSuite)
      );
      Exit;
    end;

    LCertVerifyInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

    case LSignatureScheme of
      TLS13_SIG_RSA_PSS_RSAE_SHA256,
      TLS13_SIG_RSA_PSS_PSS_SHA256,
      TLS13_SIG_RSA_PKCS1_SHA256,
      TLS13_SIG_RSA_PSS_RSAE_SHA384,
      TLS13_SIG_RSA_PSS_PSS_SHA384,
      TLS13_SIG_RSA_PKCS1_SHA384,
      TLS13_SIG_ECDSA_SECP256R1_SHA256:
        begin
          if not TryBuildTLS13CertificateVerifySignature(
            LSignatureScheme,
            LPrivateKeyBlob,
            LCertVerifyInput,
            LCertVerifySignature,
            LError
          ) then
          begin
            SetHandshakeError(sslErrUnsupported, 'CertificateVerify signer failed: ' + LError);
            Exit;
          end;

          if SameText(LLeafKeyType, 'RSA') then
          begin
            if Length(LCertVerifySignature) <> LSignatureLength then
            begin
              SetHandshakeError(
                sslErrHandshake,
                Format('CertificateVerify signature length mismatch (expected=%d actual=%d)',
                  [LSignatureLength, Length(LCertVerifySignature)])
              );
              Exit;
            end;
          end
          else if SameText(LLeafKeyType, 'ECDSA') then
          begin
            if (Length(LCertVerifySignature) <= 0) or
              (Length(LCertVerifySignature) > LSignatureLength) or
              (LCertVerifySignature[0] <> $30) then
            begin
              SetHandshakeError(
                sslErrHandshake,
                Format('ECDSA CertificateVerify signature is invalid DER length (max=%d actual=%d)',
                  [LSignatureLength, Length(LCertVerifySignature)])
              );
              Exit;
            end;
          end;
        end;

    else
      begin
        SetHandshakeError(
          sslErrUnsupported,
          Format('Unsupported CertificateVerify scheme selected: %s',
            [TLS13SignatureSchemeToString(LSignatureScheme)])
        );
        Exit;
      end;
    end;

    LCertificateVerifyMessage := BuildTLS13CertificateVerifyHandshake(
      LSignatureScheme,
      LCertVerifySignature
    );

    AppendHandshakeBytes(LServerFlightMessages, LCertificateVerifyMessage);
    AppendHandshakeBytes(LTranscriptData, LCertificateVerifyMessage);
  end;

  LTranscriptHash := HashTLS13TranscriptForSuite(LSelectedCipherSuite, LTranscriptData);
  LVerifyData := TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(
    LSelectedCipherSuite,
    FHandshakeSecrets.ServerHandshakeTrafficSecret,
    LTranscriptHash
  );

  SetLength(LFinishedMessage, 0);
  AppendByte(LFinishedMessage, TLS_HANDSHAKE_TYPE_FINISHED);
  AppendUInt24(LFinishedMessage, Length(LVerifyData));
  AppendBytes(LFinishedMessage, LVerifyData);

  AppendHandshakeBytes(LServerFlightMessages, LFinishedMessage);
  AppendHandshakeBytes(LTranscriptData, LFinishedMessage);

  LInnerPlaintext := BuildTLS13InnerPlaintext(LServerFlightMessages, TLS_CONTENT_TYPE_HANDSHAKE);
  try
    LNonce := BuildTLS13RecordNonce(FHandshakeSecrets.ServerHandshakeIV, FServerHandshakeSeq);
  except
    on E: Exception do
    begin
      SetHandshakeError(sslErrProtocol, 'Failed to build server handshake nonce: ' + E.Message);
      Exit;
    end;
  end;

  LAAD := BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(LSelectedCipherSuite)));
  if not TryTLS13AEADEncrypt(
    LSelectedCipherSuite,
    FHandshakeSecrets.ServerHandshakeKey,
    LNonce,
    LAAD,
    LInnerPlaintext,
    LEncrypted,
    LError
  ) then
  begin
    SetHandshakeError(sslErrEncryptionFailed, 'Failed to encrypt server handshake flight: ' + LError);
    Exit;
  end;

  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
  if not SendAll(LRecord) then
  begin
    SetHandshakeError(sslErrIO, 'Failed to send encrypted server handshake flight');
    Exit;
  end;

  if not IncrementTLS13Sequence(FServerHandshakeSeq) then
  begin
    SetHandshakeError(sslErrProtocol, 'Server handshake sequence overflow');
    Exit;
  end;


  { Derive application secrets BEFORE receiving Client Finished because
    RFC 8446 Section 7.1 requires Transcript-Hash(CH..SF) — the
    transcript must NOT include Client Finished. }
  if not TryDeriveTLS13ApplicationSecrets(
    LSelectedCipherSuite,
    FHandshakeSecrets.HandshakeSecret,
    LTranscriptData,
    FApplicationSecrets,
    LKeyScheduleError
  ) then
  begin
    SetHandshakeError(sslErrUnsupported, 'TLS 1.3 application key schedule derivation failed: ' + LKeyScheduleError);
    Exit;
  end;
  SetLength(LHandshakeBuffer, 0);
  LClientFinishedReceived := False;

  for LRecordIndex := 1 to 64 do
  begin
    if not RecvTLSRecord(LHeader, LPayloadBytes, LRecordBytes) then
    begin
      SetHandshakeError(sslErrIO, 'Failed to receive encrypted client Finished record');
      Exit;
    end;

    case LHeader.ContentType of
      TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC:
        Continue;

      TLS_CONTENT_TYPE_ALERT:
        begin
          SetHandshakeError(sslErrHandshake, 'Peer returned TLS alert before client Finished');
          Exit;
        end;

      TLS_CONTENT_TYPE_APPLICATION_DATA:
        begin
          LAAD := BuildTLS13RecordAAD(LHeader.Length);

          if LEarlyDataOffered and FEarlyDataSecrets.Valid then
          begin
            try
              LNonce := BuildTLS13RecordNonce(FEarlyDataSecrets.ClientEarlyIV, FEarlyDataSeq);
            except
              on E: Exception do
              begin
                SetHandshakeError(sslErrProtocol, 'Failed to build client early-data nonce: ' + E.Message);
                Exit;
              end;
            end;

            if TryTLS13AEADDecrypt(
              LSelectedCipherSuite,
              FEarlyDataSecrets.ClientEarlyKey,
              LNonce,
              LAAD,
              LPayloadBytes,
              LPlaintext,
              LError
            ) then
            begin
              if not TryParseTLS13InnerPlaintext(LPlaintext, LInnerFragment, LInnerContentType) then
              begin
                SetHandshakeError(sslErrProtocol, 'Invalid TLSInnerPlaintext in client early-data record');
                Exit;
              end;

              if LInnerContentType <> TLS_CONTENT_TYPE_APPLICATION_DATA then
              begin
                SetHandshakeError(
                  sslErrProtocol,
                  Format('Unexpected inner content type %d in client early-data record', [LInnerContentType])
                );
                Exit;
              end;

              if LEarlyDataAccepted then
              begin
                if Cardinal(Length(LEarlyDataBuffer) + Length(LInnerFragment)) > FEarlyDataLimit then
                begin
                  LEarlyDataAccepted := False;
                  FEarlyDataStatus := sslEarlyDataRejected;
                  SetLength(LEarlyDataBuffer, 0);
                end
                else
                  AppendHandshakeBytes(LEarlyDataBuffer, LInnerFragment);
              end;

              if not IncrementTLS13Sequence(FEarlyDataSeq) then
              begin
                SetHandshakeError(sslErrProtocol, 'Client early-data sequence overflow');
                Exit;
              end;

              Continue;
            end;
          end;

          try
            LNonce := BuildTLS13RecordNonce(FHandshakeSecrets.ClientHandshakeIV, FClientHandshakeSeq);
          except
            on E: Exception do
            begin
              SetHandshakeError(sslErrProtocol, 'Failed to build client handshake nonce: ' + E.Message);
              Exit;
            end;
          end;

          if not IncrementTLS13Sequence(FClientHandshakeSeq) then
          begin
            SetHandshakeError(sslErrProtocol, 'Client handshake sequence overflow');
            Exit;
          end;

          if not TryTLS13AEADDecrypt(
            LSelectedCipherSuite,
            FHandshakeSecrets.ClientHandshakeKey,
            LNonce,
            LAAD,
            LPayloadBytes,
            LPlaintext,
            LError
          ) then
          begin
            SetHandshakeError(sslErrDecryptionFailed, 'Failed to decrypt client handshake record: ' + LError);
            Exit;
          end;

          if not TryParseTLS13InnerPlaintext(LPlaintext, LInnerFragment, LInnerContentType) then
          begin
            SetHandshakeError(sslErrProtocol, 'Invalid TLSInnerPlaintext in client handshake record');
            Exit;
          end;

          case LInnerContentType of
            TLS_CONTENT_TYPE_HANDSHAKE:
              begin
                AppendHandshakeBytes(LHandshakeBuffer, LInnerFragment);

                while TryPopHandshakeMessage(LHandshakeBuffer, LHandshakeMessage) do
                begin
                  if Length(LHandshakeMessage) < 4 then
                  begin
                    SetHandshakeError(sslErrProtocol, 'Malformed client handshake message');
                    Exit;
                  end;

                  LMsgType := LHandshakeMessage[0];
                  if LMsgType = TLS_HANDSHAKE_TYPE_END_OF_EARLY_DATA then
                  begin
                    if not LEarlyDataAccepted then
                    begin
                      SetHandshakeError(sslErrProtocol, 'Server reject path must not receive EndOfEarlyData');
                      Exit;
                    end;

                    LEarlyDataEndObserved := True;
                    AppendHandshakeBytes(LTranscriptData, LHandshakeMessage);
                  end
                  else if LMsgType = TLS_HANDSHAKE_TYPE_FINISHED then
                  begin
                    if LEarlyDataAccepted and (not LEarlyDataEndObserved) then
                    begin
                      SetHandshakeError(
                        sslErrProtocol,
                        'Accepted early-data path must send EndOfEarlyData before Finished'
                      );
                      Exit;
                    end;

                    LMsgLen := ReadUInt24(LHandshakeMessage, 1);
                    if LMsgLen <> Cardinal(FHandshakeSecrets.HashSize) then
                    begin
                      SetHandshakeError(
                        sslErrProtocol,
                        Format('Client Finished length mismatch (expected=%d actual=%d)',
                          [FHandshakeSecrets.HashSize, Integer(LMsgLen)])
                      );
                      Exit;
                    end;

                    SetLength(LVerifyData, Integer(LMsgLen));
                    if Integer(LMsgLen) > 0 then
                      Move(LHandshakeMessage[4], LVerifyData[0], Integer(LMsgLen));

                    LTranscriptHash := HashTLS13TranscriptForSuite(LSelectedCipherSuite, LTranscriptData);
                    if not TLS13VerifyFinishedForCipherSuite(
                      LSelectedCipherSuite,
                      FHandshakeSecrets.ClientHandshakeTrafficSecret,
                      LTranscriptHash,
                      LVerifyData
                    ) then
                    begin
                      SetHandshakeError(sslErrHandshake, 'Client Finished verification failed');
                      Exit;
                    end;

                    AppendHandshakeBytes(LTranscriptData, LHandshakeMessage);
                    LClientFinishedReceived := True;
                    Break;
                  end
                  else
                    AppendHandshakeBytes(LTranscriptData, LHandshakeMessage);
                end;

                if LClientFinishedReceived then
                  Break;
              end;

            TLS_CONTENT_TYPE_ALERT:
              begin
                if Length(LInnerFragment) >= 2 then
                begin
                  LAlertLevel := LInnerFragment[0];
                  LAlertDescription := LInnerFragment[1];
                  SetHandshakeError(
                    sslErrHandshake,
                    Format('Peer sent encrypted alert before client Finished (level=%d description=%d)',
                      [LAlertLevel, LAlertDescription])
                  );
                end
                else
                  SetHandshakeError(sslErrHandshake, 'Peer sent malformed encrypted alert before client Finished');
                Exit;
              end;

          else
            begin
              SetHandshakeError(
                sslErrProtocol,
                Format('Unexpected inner content type %d before client Finished', [LInnerContentType])
              );
              Exit;
            end;
          end;
        end;

    else
      begin
        SetHandshakeError(
          sslErrProtocol,
          Format('Unexpected TLS record type %d while waiting for client Finished', [LHeader.ContentType])
        );
        Exit;
      end;
    end;

    if LClientFinishedReceived then
      Break;
  end;

  if not LClientFinishedReceived then
  begin
    SetHandshakeError(sslErrProtocol, 'Client Finished not received within encrypted handshake record budget');
    Exit;
  end;


  { RFC 8446 Section 7.1: resumption_master_secret uses Hash(CH..CF) }
  FApplicationSecrets.ResumptionTranscriptHash := HashTLS13TranscriptForSuite(
    LSelectedCipherSuite, LTranscriptData
  );

  FClientApplicationSeq := 0;
  FServerApplicationSeq := 0;
  SetLength(FPostHandshakeBuffer, 0);
  FApplicationReadBuffer := Copy(LEarlyDataBuffer);

  FProtocolVersion := sslProtocolTLS13;
  FCipherName := TLS13CipherSuiteToString(LSelectedCipherSuite);
  FIsServerMode := True;
  if LResumedHandshake and (LCachedSession <> nil) then
    FCurrentSession := LCachedSession.Clone
  else if Supports(FContext, IFreePascalResumptionCache, LResumptionCache) and
          LResumptionCache.CanIssueSessionTickets then
  begin
    LTicketLifetime := Cardinal(FContext.GetSessionTimeout);
    LTicketNonce := GenerateSecureRandomBytes(8);
    LTicket := GenerateSecureRandomBytes(32);
    LTicketAgeAddBytes := GenerateSecureRandomBytes(4);
    LTicketAgeAdd :=
      (Cardinal(LTicketAgeAddBytes[0]) shl 24) or
      (Cardinal(LTicketAgeAddBytes[1]) shl 16) or
      (Cardinal(LTicketAgeAddBytes[2]) shl 8) or
      Cardinal(LTicketAgeAddBytes[3]);

    LVerifyData := TLS13DeriveResumptionPSKFromTranscriptHash(
      FApplicationSecrets.CipherSuite,
      FApplicationSecrets.MasterSecret,
      FApplicationSecrets.ResumptionTranscriptHash,
      LTicketNonce
    );
    if Length(LVerifyData) <> FApplicationSecrets.HashSize then
    begin
      SetHandshakeError(sslErrHandshake, 'Failed to derive server resumption PSK for NewSessionTicket');
      Exit;
    end;

    LIssuedMaxEarlyDataSize := 0;
    if Supports(FContext, ISSLEarlyDataContext, LEarlyDataContext) then
      case LEarlyDataContext.GetServerEarlyDataPolicy of
        sslEarlyDataServerReject:
          LIssuedMaxEarlyDataSize := 0;
        sslEarlyDataServerAccept,
        sslEarlyDataServerIssueOnly:
          LIssuedMaxEarlyDataSize := LEarlyDataContext.GetServerMaxEarlyDataSize;
      end;

    LIssuedSession := TFreePascalSession.Create;
    LIssuedSession.ConfigureResumption(
      FApplicationSecrets.CipherSuite,
      TLS13CipherSuiteToString(FApplicationSecrets.CipherSuite),
      LTicketNonce,
      LTicket,
      LVerifyData,
      LTicketLifetime,
      LTicketAgeAdd,
      Now,
      FContext.GetSessionTimeout,
      LIssuedMaxEarlyDataSize
    );
    LResumptionCache.StoreResumptionSession(LIssuedSession);
    FCurrentSession := LIssuedSession.Clone;

    SetLength(LTicketExtensions, 0);
    if LIssuedMaxEarlyDataSize > 0 then
    begin
      AppendUInt16(LTicketExtensions, TLS_EXTENSION_EARLY_DATA);
      AppendUInt16(LTicketExtensions, 4);
      AppendByte(LTicketExtensions, Byte((LIssuedMaxEarlyDataSize shr 24) and $FF));
      AppendByte(LTicketExtensions, Byte((LIssuedMaxEarlyDataSize shr 16) and $FF));
      AppendByte(LTicketExtensions, Byte((LIssuedMaxEarlyDataSize shr 8) and $FF));
      AppendByte(LTicketExtensions, Byte(LIssuedMaxEarlyDataSize and $FF));
    end;
    LTicketHandshake := BuildTLS13NewSessionTicketHandshake(
      LTicketLifetime,
      LTicketAgeAdd,
      LTicketNonce,
      LTicket,
      LTicketExtensions
    );
    LInnerPlaintext := BuildTLS13InnerPlaintext(LTicketHandshake, TLS_CONTENT_TYPE_HANDSHAKE);

    try
      LNonce := BuildTLS13RecordNonce(FApplicationSecrets.ServerApplicationIV, FServerApplicationSeq);
    except
      on E: Exception do
      begin
        SetHandshakeError(sslErrProtocol, 'Failed to build server post-handshake nonce: ' + E.Message);
        Exit;
      end;
    end;

    LAAD := BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(LSelectedCipherSuite)));
    if not TryTLS13AEADEncrypt(
      LSelectedCipherSuite,
      FApplicationSecrets.ServerApplicationKey,
      LNonce,
      LAAD,
      LInnerPlaintext,
      LEncrypted,
      LError
    ) then
    begin
      SetHandshakeError(sslErrEncryptionFailed, 'Failed to encrypt NewSessionTicket: ' + LError);
      Exit;
    end;

    LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
    if not SendAll(LRecord) then
    begin
      SetHandshakeError(sslErrIO, 'Failed to send NewSessionTicket');
      Exit;
    end;
    if not IncrementTLS13Sequence(FServerApplicationSeq) then
    begin
      SetHandshakeError(sslErrProtocol, 'Server application sequence overflow after NewSessionTicket');
      Exit;
    end;

    InitTLS13NewSessionTicket(FLastSessionTicket);
    FLastSessionTicket.Valid := True;
    FLastSessionTicket.TicketLifetime := LTicketLifetime;
    FLastSessionTicket.TicketAgeAdd := LTicketAgeAdd;
    FLastSessionTicket.TicketNonce := Copy(LTicketNonce);
    FLastSessionTicket.Ticket := Copy(LTicket);
    FLastSessionTicket.Extensions := Copy(LTicketExtensions);
    Inc(FSessionTicketCount);
  end;

  SecureZeroBytes(LPrivateKeyBlob);
  Result := True;
end;
