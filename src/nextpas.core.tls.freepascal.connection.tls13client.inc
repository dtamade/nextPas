function TFreePascalConnection.ValidateServerCertificateVerify(
  ACipherSuite: Word;
  const AHandshakeMessage: TBytes;
  const ATranscriptData: TBytes
): Boolean;
var
  LVerifyMode: TSSLVerifyModes;
  LSignatureScheme: Word;
  LSignature: TBytes;
  LTranscriptHash: TBytes;
  LCertVerifyInput: TBytes;
  LLeafCertificate: TX509Certificate;
  LError: string;
  LFailureCode: TSSLErrorCode;
begin
  Result := False;

  if FContext = nil then
  begin
    SetHandshakeError(sslErrInvalidParam, 'TLS context is not available for CertificateVerify validation');
    Exit;
  end;

  LVerifyMode := FContext.GetVerifyMode;
  if not (sslVerifyPeer in LVerifyMode) then
    Exit(True);

  if FSessionReused then
    Exit(True);

  if not TryParseTLS13CertificateVerifyHandshake(
    AHandshakeMessage,
    LSignatureScheme,
    LSignature,
    LError
  ) then
  begin
    SetHandshakeError(sslErrProtocol, 'Invalid CertificateVerify: ' + LError);
    Exit;
  end;

  if FPeerCertificate = nil then
  begin
    SetHandshakeError(sslErrCertificate, 'Peer certificate is required for CertificateVerify validation');
    Exit;
  end;

  if not TryLoadX509Certificate(FPeerCertificate, LLeafCertificate, LError) then
  begin
    SetHandshakeError(sslErrCertificate, 'Failed to parse peer certificate for CertificateVerify: ' + LError);
    Exit;
  end;

  try
    LTranscriptHash := HashTLS13TranscriptForSuite(ACipherSuite, ATranscriptData);
    if Length(LTranscriptHash) = 0 then
    begin
      SetHandshakeError(
        sslErrUnsupported,
        'Unsupported TLS 1.3 cipher suite for CertificateVerify transcript hashing: ' +
        TLS13CipherSuiteToString(ACipherSuite)
      );
      Exit;
    end;

    LCertVerifyInput := BuildTLS13ServerCertificateVerifyInputSHA256(LTranscriptHash);

    if not TryVerifyTLS13CertificateVerifySignature(
      LSignatureScheme,
      LLeafCertificate.PublicKeyInfo,
      LCertVerifyInput,
      LSignature,
      LError
    ) then
    begin
      if Pos('unsupported', LowerCase(LError)) > 0 then
        LFailureCode := sslErrUnsupported
      else
        LFailureCode := sslErrHandshake;

      SetHandshakeError(
        LFailureCode,
        'Server CertificateVerify verification failed: ' + LError
      );
      Exit;
    end;
  finally
    LLeafCertificate.Free;
  end;

  Result := True;
end;

function TFreePascalConnection.ProcessEncryptedServerFlight(ACipherSuite: Word; var ATranscriptData: TBytes): Boolean;
var
  LHeader: TTLSRecordHeader;
  LPayloadBytes: TBytes;
  LRecordBytes: TBytes;
  LAAD: TBytes;
  LNonce: TBytes;
  LPlaintext: TBytes;
  LInnerFragment: TBytes;
  LHandshakeBuffer: TBytes;
  LHandshakeMessage: TBytes;
  LInnerContentType: Byte;
  LRecordIndex: Integer;
  LError: string;
  LEncryptedExtensionsInfo: TTLS13EncryptedExtensionsInfo;
  LMsgType: Byte;
  LMsgLen: Cardinal;
  LVerifyData: TBytes;
  LTranscriptHash: TBytes;
  LRequireCertificateFlight: Boolean;
  LRequestCertificateTransparency: Boolean;
  LSeenServerCertificate: Boolean;
  LSeenServerCertificateVerify: Boolean;
begin
  Result := False;
  SetLength(LHandshakeBuffer, 0);
  FServerHandshakeSeq := 0;
  LRequireCertificateFlight :=
    (not FSessionReused) and
    (FContext <> nil) and
    (sslVerifyPeer in FContext.GetVerifyMode);
  LRequestCertificateTransparency :=
    (FContext <> nil) and
    (sslVerifyPeer in FContext.GetVerifyMode);
  LSeenServerCertificate := False;
  LSeenServerCertificateVerify := False;

  for LRecordIndex := 1 to 96 do
  begin
    if not RecvTLSRecord(LHeader, LPayloadBytes, LRecordBytes) then
    begin
      SetHandshakeError(sslErrIO, 'Failed to receive encrypted handshake record');
      Exit;
    end;

    case LHeader.ContentType of
      TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC:
        Continue;

      TLS_CONTENT_TYPE_ALERT:
        begin
          SetHandshakeError(sslErrHandshake, 'Peer returned TLS alert during encrypted handshake');
          Exit;
        end;

      TLS_CONTENT_TYPE_APPLICATION_DATA:
        begin
          if not TLS13AEADIsSupported(ACipherSuite) then
          begin
            SetHandshakeError(
              sslErrUnsupported,
              Format('Cipher suite %s is unsupported by pure FreePascal encrypted handshake path',
                [TLS13CipherSuiteToString(ACipherSuite)])
            );
            Exit;
          end;

          LAAD := BuildTLS13RecordAAD(LHeader.Length);
          try
            LNonce := BuildTLS13RecordNonce(FHandshakeSecrets.ServerHandshakeIV, FServerHandshakeSeq);
          except
            on E: Exception do
            begin
              SetHandshakeError(sslErrProtocol, 'Failed to build server handshake nonce: ' + E.Message);
              Exit;
            end;
          end;

          if not IncrementTLS13Sequence(FServerHandshakeSeq) then
          begin
            SetHandshakeError(sslErrProtocol, 'Server handshake sequence overflow');
            Exit;
          end;

          if not TryTLS13AEADDecrypt(
            ACipherSuite,
            FHandshakeSecrets.ServerHandshakeKey,
            LNonce,
            LAAD,
            LPayloadBytes,
            LPlaintext,
            LError
          ) then
          begin
            SetHandshakeError(sslErrDecryptionFailed, 'Failed to decrypt server handshake record: ' + LError);
            Exit;
          end;

          if not TryParseTLS13InnerPlaintext(LPlaintext, LInnerFragment, LInnerContentType) then
          begin
            SetHandshakeError(sslErrProtocol, 'Invalid TLSInnerPlaintext from server handshake record');
            Exit;
          end;

          case LInnerContentType of
            TLS_CONTENT_TYPE_HANDSHAKE:
              begin
                AppendHandshakeBytes(LHandshakeBuffer, LInnerFragment);

                while TryPopHandshakeMessage(LHandshakeBuffer, LHandshakeMessage) do
                begin
                  LMsgType := LHandshakeMessage[0];

                  if LMsgType = TLS_HANDSHAKE_TYPE_ENCRYPTED_EXTENSIONS then
                  begin
                    if not TryParseTLS13EncryptedExtensions(
                      LHandshakeMessage,
                      LEncryptedExtensionsInfo,
                      LError
                    ) then
                    begin
                      SetHandshakeError(sslErrProtocol, 'Invalid EncryptedExtensions: ' + LError);
                      Exit;
                    end;

                    if FEarlyDataStatus = sslEarlyDataQueued then
                    begin
                      if LEncryptedExtensionsInfo.HasEarlyData then
                        FEarlyDataStatus := sslEarlyDataAccepted
                      else
                        FEarlyDataStatus := sslEarlyDataRejected;
                    end
                    else if LEncryptedExtensionsInfo.HasEarlyData then
                    begin
                      SetHandshakeError(
                        sslErrProtocol,
                        'Server accepted early_data even though client did not queue early data'
                      );
                      Exit;
                    end;

                    if LEncryptedExtensionsInfo.HasALPN then
                      FSelectedALPNProtocol := string(LEncryptedExtensionsInfo.SelectedALPNProtocol);

                    if LEncryptedExtensionsInfo.HasRecordSizeLimit then
                      FPeerRecordSizeLimit := LEncryptedExtensionsInfo.RecordSizeLimit
                    else
                      FPeerRecordSizeLimit := TLS13_RECORD_SIZE_LIMIT_DEFAULT;

                    AppendHandshakeBytes(ATranscriptData, LHandshakeMessage);
                  end
                  else if LMsgType = TLS_HANDSHAKE_TYPE_CERTIFICATE then
                  begin
                    if not TryCachePeerCertificatesFromHandshake(
                      LHandshakeMessage,
                      LRequestCertificateTransparency,
                      LError
                    ) then
                    begin
                      SetHandshakeError(sslErrProtocol, 'Invalid Certificate: ' + LError);
                      Exit;
                    end;

                    LSeenServerCertificate := True;
                    AppendHandshakeBytes(ATranscriptData, LHandshakeMessage);
                  end
                  else if LMsgType = TLS_HANDSHAKE_TYPE_CERTIFICATE_REQUEST then
                  begin
                    FClientCertRequested := True;
                    AppendHandshakeBytes(ATranscriptData, LHandshakeMessage);
                  end
                  else if LMsgType = TLS_HANDSHAKE_TYPE_CERTIFICATE_VERIFY then
                  begin
                    if not ValidateServerCertificateVerify(ACipherSuite, LHandshakeMessage, ATranscriptData) then
                      Exit;

                    LSeenServerCertificateVerify := True;
                    AppendHandshakeBytes(ATranscriptData, LHandshakeMessage);
                  end
                  else if LMsgType = TLS_HANDSHAKE_TYPE_FINISHED then
                  begin
                    if LRequireCertificateFlight and
                      ((not LSeenServerCertificate) or (not LSeenServerCertificateVerify)) then
                    begin
                      SetHandshakeError(
                        sslErrProtocol,
                        'Server full handshake missing Certificate or CertificateVerify before Finished'
                      );
                      Exit;
                    end;

                    LMsgLen := ReadUInt24(LHandshakeMessage, 1);
                    if LMsgLen <> Cardinal(FHandshakeSecrets.HashSize) then
                    begin
                      SetHandshakeError(
                        sslErrProtocol,
                        Format('Server Finished length mismatch (expected=%d actual=%d)',
                          [FHandshakeSecrets.HashSize, Integer(LMsgLen)])
                      );
                      Exit;
                    end;

                    SetLength(LVerifyData, Integer(LMsgLen));
                    if Integer(LMsgLen) > 0 then
                      Move(LHandshakeMessage[4], LVerifyData[0], Integer(LMsgLen));

                    LTranscriptHash := HashTLS13TranscriptForSuite(ACipherSuite, ATranscriptData);
                    if not TLS13VerifyFinishedForCipherSuite(
                      ACipherSuite,
                      FHandshakeSecrets.ServerHandshakeTrafficSecret,
                      LTranscriptHash,
                      LVerifyData
                    ) then
                    begin
                      SetHandshakeError(sslErrHandshake, 'Server Finished verification failed');
                      Exit;
                    end;

                    AppendHandshakeBytes(ATranscriptData, LHandshakeMessage);
                    Result := True;
                    Exit;
                  end
                  else
                    AppendHandshakeBytes(ATranscriptData, LHandshakeMessage);
                end;
              end;

            TLS_CONTENT_TYPE_ALERT:
              begin
                SetHandshakeError(sslErrHandshake, 'Received TLS alert content inside encrypted handshake record');
                Exit;
              end;

          else
            begin
              SetHandshakeError(
                sslErrProtocol,
                Format('Unexpected inner content type %d during encrypted handshake', [LInnerContentType])
              );
              Exit;
            end;
          end;
        end;

    else
      begin
        SetHandshakeError(
          sslErrProtocol,
          Format('Unexpected TLS record type %d during encrypted handshake', [LHeader.ContentType])
        );
        Exit;
      end;
    end;
  end;

  SetHandshakeError(sslErrProtocol, 'Server Finished not received within encrypted handshake record budget');
end;

function TFreePascalConnection.SendClientEmptyCertificate(ACipherSuite: Word; var ATranscriptData: TBytes): Boolean;
var
  LCertHandshake: TBytes;
  LInnerPlaintext: TBytes;
  LNonce: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
  LError: string;
begin
  Result := False;

  // TLS 1.3 empty Certificate: type(1) + length(3) + context_len(1) + cert_list_len(3)
  SetLength(LCertHandshake, 8);
  LCertHandshake[0] := TLS_HANDSHAKE_TYPE_CERTIFICATE;
  LCertHandshake[1] := 0;
  LCertHandshake[2] := 0;
  LCertHandshake[3] := 4;
  LCertHandshake[4] := 0;
  LCertHandshake[5] := 0;
  LCertHandshake[6] := 0;
  LCertHandshake[7] := 0;

  LInnerPlaintext := BuildTLS13InnerPlaintext(LCertHandshake, TLS_CONTENT_TYPE_HANDSHAKE);

  try
    LNonce := BuildTLS13RecordNonce(FHandshakeSecrets.ClientHandshakeIV, FClientHandshakeSeq);
  except
    on E: Exception do
    begin
      SetHandshakeError(sslErrProtocol, 'Failed to build client certificate nonce: ' + E.Message);
      Exit;
    end;
  end;

  if not TryTLS13AEADEncrypt(
    ACipherSuite,
    FHandshakeSecrets.ClientHandshakeKey,
    LNonce,
    BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(ACipherSuite))),
    LInnerPlaintext,
    LEncrypted,
    LError
  ) then
  begin
    SetHandshakeError(sslErrProtocol, 'Failed to encrypt client Certificate: ' + LError);
    Exit;
  end;

  if not IncrementTLS13Sequence(FClientHandshakeSeq) then
  begin
    SetHandshakeError(sslErrProtocol, 'Client handshake sequence overflow');
    Exit;
  end;

  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
  if not SendAll(LRecord) then
  begin
    SetHandshakeError(sslErrIO, 'Failed to send client Certificate');
    Exit;
  end;

  AppendHandshakeBytes(ATranscriptData, LCertHandshake);
  Result := True;
end;

function TFreePascalConnection.SendClientCertificateAndVerify(ACipherSuite: Word; var ATranscriptData: TBytes): Boolean;
var
  LContextMaterial: IFreePascalContextMaterial;
  LCertDER: TBytes;
  LPrivKeyDER: TBytes;
  LCertLen: Integer;
  LCertEntry: TBytes;
  LCertList: TBytes;
  LBody: TBytes;
  LCertHandshake: TBytes;
  LInnerPlaintext: TBytes;
  LNonce: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
  LError: string;
  LTranscriptHash: TBytes;
  LCertVerifyInput: TBytes;
  LSignature: TBytes;
  LCertVerifyHandshake: TBytes;
  LSignatureScheme: Word;
begin
  Result := False;

  // Check if context has certificate material
  if not Supports(FContext, IFreePascalContextMaterial, LContextMaterial) then
  begin
    // No material interface - fall back to empty certificate
    Result := SendClientEmptyCertificate(ACipherSuite, ATranscriptData);
    Exit;
  end;

  if (not LContextMaterial.HasCertificateMaterial) or
     (not LContextMaterial.HasPrivateKeyMaterial) then
  begin
    // No cert/key loaded - fall back to empty certificate
    Result := SendClientEmptyCertificate(ACipherSuite, ATranscriptData);
    Exit;
  end;

  LCertDER := LContextMaterial.GetCertificateMaterial;
  LPrivKeyDER := LContextMaterial.GetPrivateKeyMaterial;

  if (Length(LCertDER) = 0) or (Length(LPrivKeyDER) = 0) then
  begin
    Result := SendClientEmptyCertificate(ACipherSuite, ATranscriptData);
    Exit;
  end;

  // Build TLS 1.3 Certificate message with actual certificate
  // RFC 8446 Section 4.4.2:
  //   Certificate = {
  //     certificate_request_context<0..2^8-1>,
  //     CertificateEntry certificate_list<0..2^24-1>
  //   }
  //   CertificateEntry = {
  //     cert_data<1..2^24-1>,
  //     extensions<0..2^16-1>
  //   }
  LCertLen := Length(LCertDER);

  SetLength(LCertEntry, 0);
  AppendUInt24(LCertEntry, LCertLen);
  AppendBytes(LCertEntry, LCertDER);
  AppendUInt16(LCertEntry, 0); // no extensions

  SetLength(LCertList, 0);
  AppendBytes(LCertList, LCertEntry);

  SetLength(LBody, 0);
  AppendByte(LBody, 0); // certificate_request_context length = 0
  AppendUInt24(LBody, Length(LCertList));
  AppendBytes(LBody, LCertList);

  SetLength(LCertHandshake, 0);
  AppendByte(LCertHandshake, TLS_HANDSHAKE_TYPE_CERTIFICATE);
  AppendUInt24(LCertHandshake, Length(LBody));
  AppendBytes(LCertHandshake, LBody);

  // Encrypt and send Certificate
  LInnerPlaintext := BuildTLS13InnerPlaintext(LCertHandshake, TLS_CONTENT_TYPE_HANDSHAKE);

  try
    LNonce := BuildTLS13RecordNonce(FHandshakeSecrets.ClientHandshakeIV, FClientHandshakeSeq);
  except
    on E: Exception do
    begin
      SetHandshakeError(sslErrProtocol, 'Failed to build client certificate nonce: ' + E.Message);
      Exit;
    end;
  end;

  if not TryTLS13AEADEncrypt(
    ACipherSuite,
    FHandshakeSecrets.ClientHandshakeKey,
    LNonce,
    BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(ACipherSuite))),
    LInnerPlaintext,
    LEncrypted,
    LError
  ) then
  begin
    SetHandshakeError(sslErrProtocol, 'Failed to encrypt client Certificate: ' + LError);
    Exit;
  end;

  if not IncrementTLS13Sequence(FClientHandshakeSeq) then
  begin
    SetHandshakeError(sslErrProtocol, 'Client handshake sequence overflow');
    Exit;
  end;

  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
  if not SendAll(LRecord) then
  begin
    SetHandshakeError(sslErrIO, 'Failed to send client Certificate');
    Exit;
  end;

  AppendHandshakeBytes(ATranscriptData, LCertHandshake);

  // Now build and send CertificateVerify
  // RFC 8446 Section 4.4.3: transcript hash up to and including Certificate
  LTranscriptHash := HashTLS13TranscriptForSuite(ACipherSuite, ATranscriptData);
  LCertVerifyInput := BuildTLS13ClientCertificateVerifyInput(LTranscriptHash);

  // Determine signature scheme based on key type
  // For RSA keys use RSA-PSS-RSAE-SHA256, for EC keys use ECDSA-P256-SHA256
  LSignatureScheme := TLS13_SIG_RSA_PSS_RSAE_SHA256;
  if IsECDSAPrivateKey(LPrivKeyDER) then
    LSignatureScheme := TLS13_SIG_ECDSA_SECP256R1_SHA256;

  if not TryBuildTLS13CertificateVerifySignature(
    LSignatureScheme,
    LPrivKeyDER,
    LCertVerifyInput,
    LSignature,
    LError
  ) then
  begin
    SetHandshakeError(sslErrProtocol, 'Failed to build client CertificateVerify signature: ' + LError);
    Exit;
  end;

  LCertVerifyHandshake := BuildTLS13CertificateVerifyHandshake(LSignatureScheme, LSignature);

  // Encrypt and send CertificateVerify
  LInnerPlaintext := BuildTLS13InnerPlaintext(LCertVerifyHandshake, TLS_CONTENT_TYPE_HANDSHAKE);

  try
    LNonce := BuildTLS13RecordNonce(FHandshakeSecrets.ClientHandshakeIV, FClientHandshakeSeq);
  except
    on E: Exception do
    begin
      SetHandshakeError(sslErrProtocol, 'Failed to build client CertificateVerify nonce: ' + E.Message);
      Exit;
    end;
  end;

  if not TryTLS13AEADEncrypt(
    ACipherSuite,
    FHandshakeSecrets.ClientHandshakeKey,
    LNonce,
    BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(ACipherSuite))),
    LInnerPlaintext,
    LEncrypted,
    LError
  ) then
  begin
    SetHandshakeError(sslErrProtocol, 'Failed to encrypt client CertificateVerify: ' + LError);
    Exit;
  end;

  if not IncrementTLS13Sequence(FClientHandshakeSeq) then
  begin
    SetHandshakeError(sslErrProtocol, 'Client handshake sequence overflow after CertificateVerify');
    Exit;
  end;

  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
  if not SendAll(LRecord) then
  begin
    SetHandshakeError(sslErrIO, 'Failed to send client CertificateVerify');
    Exit;
  end;

  AppendHandshakeBytes(ATranscriptData, LCertVerifyHandshake);
  SecureZeroBytes(LPrivKeyDER);
  Result := True;
end;

function TFreePascalConnection.SendClientFinished(ACipherSuite: Word; var ATranscriptData: TBytes): Boolean;
var
  LClientFlight: TBytes;
  LTranscriptForFinished: TBytes;
  LTranscriptHash: TBytes;
  LVerifyData: TBytes;
  LFinishedHandshake: TBytes;
  LInnerPlaintext: TBytes;
  LNonce: TBytes;
  LEncrypted: TBytes;
  LRecord: TBytes;
  LError: string;
begin
  Result := False;

  if not TLS13AEADIsSupported(ACipherSuite) then
  begin
    SetHandshakeError(
      sslErrUnsupported,
      Format('Cipher suite %s is unsupported for client Finished encryption',
        [TLS13CipherSuiteToString(ACipherSuite)])
    );
    Exit;
  end;

  SetLength(LClientFlight, 0);
  if FEarlyDataStatus = sslEarlyDataAccepted then
    AppendHandshakeBytes(LClientFlight, BuildTLS13EndOfEarlyDataHandshake);

  LTranscriptForFinished := Copy(ATranscriptData, 0, Length(ATranscriptData));
  if Length(LClientFlight) > 0 then
    AppendHandshakeBytes(LTranscriptForFinished, LClientFlight);

  LTranscriptHash := HashTLS13TranscriptForSuite(ACipherSuite, LTranscriptForFinished);
  LVerifyData := TLS13ComputeFinishedVerifyDataForCipherSuite(
    ACipherSuite,
    FClientFinishedKey,
    LTranscriptHash
  );

  SetLength(LFinishedHandshake, 0);
  AppendByte(LFinishedHandshake, TLS_HANDSHAKE_TYPE_FINISHED);
  AppendUInt24(LFinishedHandshake, Length(LVerifyData));
  AppendHandshakeBytes(LFinishedHandshake, LVerifyData);

  AppendHandshakeBytes(LClientFlight, LFinishedHandshake);
  LInnerPlaintext := BuildTLS13InnerPlaintext(LClientFlight, TLS_CONTENT_TYPE_HANDSHAKE);

  try
    LNonce := BuildTLS13RecordNonce(FHandshakeSecrets.ClientHandshakeIV, FClientHandshakeSeq);
  except
    on E: Exception do
    begin
      SetHandshakeError(sslErrProtocol, 'Failed to build client handshake nonce: ' + E.Message);
      Exit;
    end;
  end;

  if not TryTLS13AEADEncrypt(
    ACipherSuite,
    FHandshakeSecrets.ClientHandshakeKey,
    LNonce,
    BuildTLS13RecordAAD(Word(Length(LInnerPlaintext) + TLS13AEADTagLength(ACipherSuite))),
    LInnerPlaintext,
    LEncrypted,
    LError
  ) then
  begin
    SetHandshakeError(sslErrEncryptionFailed, 'Failed to encrypt client Finished: ' + LError);
    Exit;
  end;

  if not IncrementTLS13Sequence(FClientHandshakeSeq) then
  begin
    SetHandshakeError(sslErrProtocol, 'Client handshake sequence overflow');
    Exit;
  end;

  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_APPLICATION_DATA, LEncrypted);
  if not SendAll(LRecord) then
  begin
    SetHandshakeError(sslErrIO, 'Failed to send encrypted client Finished record');
    Exit;
  end;

  if FEarlyDataStatus = sslEarlyDataAccepted then
    AppendHandshakeBytes(ATranscriptData, BuildTLS13EndOfEarlyDataHandshake);
  AppendHandshakeBytes(ATranscriptData, LFinishedHandshake);
  Result := True;
end;
