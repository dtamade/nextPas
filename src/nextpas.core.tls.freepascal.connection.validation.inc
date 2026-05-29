procedure TFreePascalConnection.ClearOCSPStaplingState;
begin
  SetLength(FOCSPResponse, 0);
  FOCSPResponseVerified := False;
  FOCSPResponseStatus := 'Not Requested';
end;

procedure TFreePascalConnection.ClearCertificateTransparencyState;
begin
  SetLength(FSignedCertificateTimestampList, 0);
  FSignedCertificateTimestampCount := 0;
  FCertificateTransparencyStatus := 'Not Requested';
  FHasCertificateTransparencyValidationResult := False;
  FCertificateTransparencyPolicySatisfied := False;
  FCertificateTransparencyValidationStatus := 'Not Attempted';
end;

procedure TFreePascalConnection.RefreshCertificateTransparencyValidationState;
var
  LError: string;
  LOptions: TSCTValidationOptions;
  LResults: TSCTValidationResultArray;
begin
  FHasCertificateTransparencyValidationResult := False;
  FCertificateTransparencyPolicySatisfied := False;
  FCertificateTransparencyValidationStatus := 'Not Attempted';

  if Length(FSignedCertificateTimestampList) = 0 then
    Exit;

  LOptions := CreateDefaultValidationOptions;
  LOptions.MinimumSCTCount := 1;
  try
    if not TryCollectSignedCertificateTimestampValidationResults(
      FSignedCertificateTimestampList,
      FPeerCertificate,
      LOptions,
      LResults,
      LError
    ) then
    begin
      FCertificateTransparencyValidationStatus := 'Validation unavailable: ' + LError;
      Exit;
    end;

    FHasCertificateTransparencyValidationResult := True;
    FCertificateTransparencyPolicySatisfied := CheckCertificateTransparencyPolicy(
      LResults,
      LOptions
    );
    FCertificateTransparencyValidationStatus := BuildCertificateTransparencyValidationStatus(
      LResults,
      FCertificateTransparencyPolicySatisfied
    );
  except
    on E: Exception do
      FCertificateTransparencyValidationStatus := 'Validation failed: ' + E.Message;
  end;
end;

procedure TFreePascalConnection.ClearPeerCertificateCache;
begin
  ClearOCSPStaplingState;
  ClearCertificateTransparencyState;
  FPeerCertificate := nil;
  SetLength(FPeerCertificateChain, 0);
end;

function TFreePascalConnection.TryCachePeerCertificatesFromHandshake(
  const AHandshakeMessage: TBytes;
  ACertificateTransparencyRequested: Boolean;
  out AError: string
): Boolean;
var
  LCertificateInfo: TTLS13ServerCertificateInfo;
  LCertificate: ISSLCertificate;
  LEmbeddedSCTList: TBytes;
  LEmbeddedSCTCount: Integer;
  LEmbeddedSCTFound: Boolean;
  LOCSPSCTList: TBytes;
  LOCSPSCTCount: Integer;
  LOCSPSCTFound: Boolean;
  LOCSPSCTError: string;
  I: Integer;
begin
  AError := '';
  Result := False;
  ClearPeerCertificateCache;

  if not TryParseTLS13ServerCertificateHandshakeInfo(AHandshakeMessage, LCertificateInfo, AError) then
    Exit;

  FOCSPResponseStatus := 'No OCSP Response';
  if ACertificateTransparencyRequested then
    FCertificateTransparencyStatus := 'No SCT List';

  if LCertificateInfo.HasLeafOCSPStapledResponse then
  begin
    FOCSPResponse := Copy(LCertificateInfo.LeafOCSPStapledResponse);
    FOCSPResponseStatus := 'Received';
  end;

  if LCertificateInfo.HasLeafSignedCertificateTimestampList then
  begin
    FSignedCertificateTimestampList := Copy(LCertificateInfo.LeafSignedCertificateTimestampList);
    FSignedCertificateTimestampCount := LCertificateInfo.LeafSignedCertificateTimestampCount;
    FCertificateTransparencyStatus := Format(
      'Received from TLS extension (%d SCTs)',
      [FSignedCertificateTimestampCount]
    );
  end;

  SetLength(FPeerCertificateChain, Length(LCertificateInfo.Certificates));
  for I := 0 to High(LCertificateInfo.Certificates) do
  begin
    try
      LCertificate := TSSLFactory.CreateCertificate(sslFreePascal);
    except
      on E: Exception do
      begin
        AError := Format('Failed to create peer certificate #%d: %s', [I + 1, E.Message]);
        ClearPeerCertificateCache;
        Exit;
      end;
    end;

    if LCertificate = nil then
    begin
      AError := Format('Failed to create peer certificate #%d', [I + 1]);
      ClearPeerCertificateCache;
      Exit;
    end;

    if not LCertificate.LoadFromDER(LCertificateInfo.Certificates[I]) then
    begin
      AError := Format('Failed to load peer certificate #%d from DER', [I + 1]);
      ClearPeerCertificateCache;
      Exit;
    end;

    FPeerCertificateChain[I] := LCertificate;
  end;

  for I := 0 to High(FPeerCertificateChain) do
  begin
    if FPeerCertificateChain[I] = nil then
      Continue;

    if I < High(FPeerCertificateChain) then
      FPeerCertificateChain[I].SetIssuerCertificate(FPeerCertificateChain[I + 1])
    else
      FPeerCertificateChain[I].SetIssuerCertificate(nil);
  end;

  FPeerCertificate := FPeerCertificateChain[0];

  if ACertificateTransparencyRequested and
    (Length(FSignedCertificateTimestampList) = 0) and
    (FPeerCertificate <> nil) then
  begin
    if not TryLoadEmbeddedSignedCertificateTimestampList(
      FPeerCertificate,
      LEmbeddedSCTList,
      LEmbeddedSCTCount,
      LEmbeddedSCTFound,
      AError
    ) then
    begin
      if Trim(AError) = '' then
        AError := 'Failed to inspect embedded signed_certificate_timestamp';
      ClearPeerCertificateCache;
      Exit;
    end;

    if LEmbeddedSCTFound then
    begin
      FSignedCertificateTimestampList := Copy(LEmbeddedSCTList);
      FSignedCertificateTimestampCount := LEmbeddedSCTCount;
      FCertificateTransparencyStatus := Format(
        'Received from embedded X.509 extension (%d SCTs)',
        [FSignedCertificateTimestampCount]
      );
    end;
  end;

  if ACertificateTransparencyRequested and
    (Length(FSignedCertificateTimestampList) = 0) and
    (Length(FOCSPResponse) > 0) then
  begin
    if not TryLoadOCSPSignedCertificateTimestampList(
      LOCSPSCTList,
      LOCSPSCTCount,
      LOCSPSCTFound,
      LOCSPSCTError
    ) then
    begin
      if Trim(LOCSPSCTError) <> '' then
        FCertificateTransparencyStatus :=
          'OCSP-delivered signed_certificate_timestamp unavailable: ' + LOCSPSCTError;
    end
    else if LOCSPSCTFound then
    begin
      FSignedCertificateTimestampList := Copy(LOCSPSCTList);
      FSignedCertificateTimestampCount := LOCSPSCTCount;
      FCertificateTransparencyStatus := Format(
        'Received from OCSP response (%d SCTs)',
        [FSignedCertificateTimestampCount]
      );
    end;
  end;

  RefreshCertificateTransparencyValidationState;

  Result := True;
end;

function TFreePascalConnection.BuildPeerIntermediateStore: ISSLCertificateStore;
var
  I: Integer;
  LCertificate: ISSLCertificate;
begin
  Result := nil;

  if Length(FPeerCertificateChain) <= 1 then
    Exit;

  try
    Result := TSSLFactory.CreateCertificateStore(sslFreePascal);
  except
    Exit(nil);
  end;

  if Result = nil then
    Exit;

  for I := 1 to High(FPeerCertificateChain) do
  begin
    if FPeerCertificateChain[I] = nil then
      Continue;

    LCertificate := FPeerCertificateChain[I].Clone;
    if LCertificate <> nil then
      Result.AddCertificate(LCertificate);
  end;

  if Result.GetCount = 0 then
    Result := nil;
end;

function TFreePascalConnection.TryResolvePeerIssuerCertificate(
  out AIssuerCertificate: ISSLCertificate;
  out AError: string
): Boolean;
var
  LTrustStoreAccess: IFreePascalContextTrustStore;
  LVerificationStore: ISSLCertificateStore;
  LIssuerSubject: string;
begin
  AIssuerCertificate := nil;
  AError := '';
  Result := False;

  if FPeerCertificate = nil then
  begin
    AError := 'Peer certificate is unavailable';
    Exit;
  end;

  if (Length(FPeerCertificateChain) > 1) and (FPeerCertificateChain[1] <> nil) then
  begin
    AIssuerCertificate := FPeerCertificateChain[1];
    Exit(True);
  end;

  LIssuerSubject := Trim(FPeerCertificate.GetIssuer);
  if LIssuerSubject <> '' then
  begin
    if Supports(FContext, IFreePascalContextTrustStore, LTrustStoreAccess) then
    begin
      LVerificationStore := LTrustStoreAccess.BuildVerificationStore;
      if LVerificationStore <> nil then
      begin
        AIssuerCertificate := LVerificationStore.FindBySubject(LIssuerSubject);
        if AIssuerCertificate <> nil then
          Exit(True);
      end;
    end;
  end;

  if SameText(Trim(FPeerCertificate.GetSubject), LIssuerSubject) then
  begin
    AIssuerCertificate := FPeerCertificate;
    Exit(True);
  end;

  if LIssuerSubject = '' then
    AError := 'Peer certificate issuer subject is empty'
  else
    AError := 'Issuer certificate is unavailable in peer chain and trust store';
end;

function TryLoadX509Certificate(
  ACertificate: ISSLCertificate;
  out AX509Certificate: TX509Certificate;
  out AError: string
): Boolean;
var
  LDER: TBytes;
begin
  AX509Certificate := nil;
  AError := '';
  Result := False;

  if ACertificate = nil then
  begin
    AError := 'Certificate is nil';
    Exit;
  end;

  LDER := ACertificate.SaveToDER;
  if Length(LDER) = 0 then
  begin
    AError := 'Certificate DER is empty';
    Exit;
  end;

  AX509Certificate := TX509Certificate.Create;
  try
    AX509Certificate.LoadFromDER(LDER);
  except
    on E: Exception do
    begin
      AX509Certificate.Free;
      AX509Certificate := nil;
      AError := 'Failed to parse certificate DER: ' + E.Message;
      Exit;
    end;
  end;

  Result := True;
end;

function TryLoadEmbeddedSignedCertificateTimestampList(
  ACertificate: ISSLCertificate;
  out ASignedCertificateTimestampList: TBytes;
  out ASignedCertificateTimestampCount: Integer;
  out AFound: Boolean;
  out AError: string
): Boolean;
var
  LX509Certificate: TX509Certificate;
  LRawValue: TBytes;
  LInnerLen: Integer;
  LLenBytes: Integer;
  I: Integer;
begin
  SetLength(ASignedCertificateTimestampList, 0);
  ASignedCertificateTimestampCount := 0;
  AFound := False;
  AError := '';
  Result := False;

  if not TryLoadX509Certificate(ACertificate, LX509Certificate, AError) then
  begin
    AError := 'Failed to inspect embedded signed_certificate_timestamp: ' + AError;
    Exit;
  end;

  try
    for I := 0 to High(LX509Certificate.Extensions) do
    begin
      if SameText(
        LX509Certificate.Extensions[I].OID,
        X509_EXTENSION_EMBEDDED_SIGNED_CERTIFICATE_TIMESTAMP
      ) then
      begin
        AFound := True;
        LRawValue := Copy(LX509Certificate.Extensions[I].Value);
        Break;
      end;
    end;
  finally
    LX509Certificate.Free;
  end;

  if not AFound then
    Exit(True);

  // RFC 6962: extnValue contains an ASN.1 OCTET STRING wrapping the SCT list
  if (Length(LRawValue) >= 2) and (LRawValue[0] = $04) then
  begin
    if LRawValue[1] < $80 then
    begin
      LInnerLen := LRawValue[1];
      LLenBytes := 1;
    end
    else if (LRawValue[1] = $81) and (Length(LRawValue) >= 3) then
    begin
      LInnerLen := LRawValue[2];
      LLenBytes := 2;
    end
    else if (LRawValue[1] = $82) and (Length(LRawValue) >= 4) then
    begin
      LInnerLen := (Integer(LRawValue[2]) shl 8) or Integer(LRawValue[3]);
      LLenBytes := 3;
    end
    else
    begin
      LInnerLen := 0;
      LLenBytes := 0;
    end;

    if (LLenBytes > 0) and (1 + LLenBytes + LInnerLen = Length(LRawValue)) then
      ASignedCertificateTimestampList := Copy(LRawValue, 1 + LLenBytes, LInnerLen)
    else
      ASignedCertificateTimestampList := Copy(LRawValue);
  end
  else
    ASignedCertificateTimestampList := Copy(LRawValue);

  if not TryParseSignedCertificateTimestampList(
    ASignedCertificateTimestampList,
    ASignedCertificateTimestampCount,
    AError
  ) then
  begin
    AError := 'embedded signed_certificate_timestamp is invalid: ' + AError;
    Exit;
  end;

  Result := True;
end;

function TFreePascalConnection.TryBuildPeerOCSPCertificatePair(
  out ALeafCertificate, AIssuerCertificate: TX509Certificate;
  out AError: string
): Boolean;
var
  LIssuer: ISSLCertificate;
begin
  ALeafCertificate := nil;
  AIssuerCertificate := nil;
  AError := '';
  Result := False;

  if FPeerCertificate = nil then
  begin
    AError := 'Peer certificate is unavailable';
    Exit;
  end;

  if not TryLoadX509Certificate(FPeerCertificate, ALeafCertificate, AError) then
    Exit;

  if not TryResolvePeerIssuerCertificate(LIssuer, AError) then
  begin
    ALeafCertificate.Free;
    ALeafCertificate := nil;
    Exit;
  end;

  if not TryLoadX509Certificate(LIssuer, AIssuerCertificate, AError) then
  begin
    ALeafCertificate.Free;
    ALeafCertificate := nil;
    Exit;
  end;

  Result := True;
end;

function TFreePascalConnection.TryLoadOCSPSignedCertificateTimestampList(
  out ASignedCertificateTimestampList: TBytes;
  out ASignedCertificateTimestampCount: Integer;
  out AFound: Boolean;
  out AError: string
): Boolean;
var
  LOCSPResponse: TOCSPResponse;
  LLeafCertificate: TX509Certificate;
  LIssuerCertificate: TX509Certificate;
  LCertID: TOCSPCertID;
begin
  SetLength(ASignedCertificateTimestampList, 0);
  ASignedCertificateTimestampCount := 0;
  AFound := False;
  AError := '';
  Result := False;

  if Length(FOCSPResponse) = 0 then
    Exit(True);

  LOCSPResponse := TOCSPResponse.Create;
  try
    try
      LOCSPResponse.LoadFromDER(FOCSPResponse);
    except
      on E: Exception do
      begin
        AError := 'Failed to parse OCSP response: ' + E.Message;
        Exit;
      end;
    end;

    if LOCSPResponse.ResponseStatus <> ocsprsSuccessful then
    begin
      AError := 'OCSP response status: ' +
        OCSPResponseStatusToString(LOCSPResponse.ResponseStatus);
      Exit;
    end;

    if not TryBuildPeerOCSPCertificatePair(LLeafCertificate, LIssuerCertificate, AError) then
      Exit;

    try
      LCertID := TOCSPCertID.Create(LLeafCertificate, LIssuerCertificate);
      AFound := LOCSPResponse.TryGetSignedCertificateTimestampList(
        LCertID,
        ASignedCertificateTimestampList,
        ASignedCertificateTimestampCount
      );
      Result := True;
    finally
      LLeafCertificate.Free;
      LIssuerCertificate.Free;
    end;
  finally
    LOCSPResponse.Free;
  end;
end;

function TFreePascalConnection.ValidateClientPeerCertificateTrust: Boolean;
var
  LVerifyMode: TSSLVerifyModes;
  LVerifyFlags: TSSLCertVerifyFlags;
  LOptions: TChainVerifyOptions;
  LTrustStoreAccess: IFreePascalContextTrustStore;
  LRevocationMaterialAccess: IFreePascalContextRevocationMaterial;
  LVerifyCallbackAccess: IFreePascalContextVerifyCallback;
  LVerifyCallback: TSSLVerifyCallback;
  LTrustedStore: ISSLCertificateStore;
  LIntermediateStore: ISSLCertificateStore;
  LCRLStore: TStringList;
  LVerifier: ISSLCertificateChainVerifier;
  LVerifyResult: TChainVerifyResult;
  LErrorCode: TSSLErrorCode;
  LErrorMessage: string;
begin
  Result := False;

  if FContext = nil then
  begin
    SetHandshakeError(sslErrInvalidParam, 'TLS context is not available for peer certificate trust verification');
    Exit;
  end;

  LVerifyMode := FContext.GetVerifyMode;
  if not (sslVerifyPeer in LVerifyMode) then
    Exit(True);

  if FSessionReused then
    Exit(True);

  if FPeerCertificate = nil then
  begin
    SetHandshakeError(sslErrCertificate, 'Peer certificate is required for client trust verification');
    Exit;
  end;

  if not Supports(FContext, IFreePascalContextTrustStore, LTrustStoreAccess) then
  begin
    SetHandshakeError(sslErrUnsupported, 'FreePascal context does not expose trust-store access for client verification');
    Exit;
  end;

  LTrustedStore := LTrustStoreAccess.BuildVerificationStore;
  LIntermediateStore := BuildPeerIntermediateStore;
  LCRLStore := nil;
  if Supports(FContext, IFreePascalContextRevocationMaterial, LRevocationMaterialAccess) then
    LCRLStore := LRevocationMaterialAccess.BuildCRLStore;
  LVerifyFlags := FContext.GetCertVerifyFlags;

  LOptions := [cvoCheckSignature, cvoCheckCAConstraints];
  if sslCertVerifyAllowSelfSigned in LVerifyFlags then
    Include(LOptions, cvoAllowSelfSigned);
  if sslCertVerifyStrictChain in LVerifyFlags then
  begin
    Include(LOptions, cvoCheckKeyUsage);
    Include(LOptions, cvoCheckExtKeyUsage);
  end;
  if (sslCertVerifyCheckRevocation in LVerifyFlags) or
    (sslCertVerifyCheckCRL in LVerifyFlags) then
    Include(LOptions, cvoCheckRevocation);

  LVerifier := TSSLCertificateChainVerifier.Create;
  try
    LVerifier.SetOptions(LOptions);
    if LTrustedStore <> nil then
      LVerifier.SetTrustedStore(LTrustedStore);
    if LIntermediateStore <> nil then
      LVerifier.SetIntermediateStore(LIntermediateStore);
    if LCRLStore <> nil then
      LVerifier.SetCRLStore(LCRLStore);

    LVerifyResult := LVerifier.VerifyCertificate(FPeerCertificate);
  finally
    LVerifier := nil;
    if LCRLStore <> nil then
      LCRLStore.Free;
  end;

  try
    if not LVerifyResult.IsValid then
    begin
      LErrorMessage := Trim(LVerifyResult.ErrorMessage);
      if LErrorMessage = '' then
        LErrorMessage := 'Peer certificate is not trusted';
      if LVerifyResult.RevocationStatus = 1 then
        LErrorCode := sslErrCertificateRevoked
      else
        LErrorCode := sslErrCertificateUntrusted;

      if Supports(FContext, IFreePascalContextVerifyCallback, LVerifyCallbackAccess) then
      begin
        LVerifyCallback := LVerifyCallbackAccess.GetVerifyCallback;
        if Assigned(LVerifyCallback) then
        begin
          try
            if LVerifyCallback(FPeerCertificate.GetInfo, Ord(LErrorCode), LErrorMessage) then
            begin
              Result := ValidateCertificatePinIfEnabled;
              Exit;
            end;
          except
            on E: Exception do
            begin
              SetHandshakeError(
                sslErrCertificate,
                'Peer certificate verify callback failed: ' + E.Message
              );
              Exit;
            end;
          end;
        end;
      end;

      SetHandshakeError(
        LErrorCode,
        'Peer certificate trust verification failed: ' + LErrorMessage
      );
      Exit;
    end;
  finally
    if Assigned(LVerifyResult.Warnings) then
      LVerifyResult.Warnings.Free;
  end;

  if not ValidateCertificatePinIfEnabled then
    Exit;

  Result := True;
end;

function TFreePascalConnection.ValidateCertificatePinIfEnabled: Boolean;
var
  LPinValidator: IFreePascalContextPinValidation;
  LFingerprintHex: string;
  LFingerprint: TBytes;
  I: Integer;
begin
  Result := True;
  if FContext = nil then
    Exit;
  if not FContext.GetCertificatePinningEnabled then
    Exit;
  if not Supports(FContext, IFreePascalContextPinValidation, LPinValidator) then
    Exit;
  if FPeerCertificate = nil then
  begin
    SetHandshakeError(sslErrCertificate, 'Certificate pinning enabled but no peer certificate available');
    Result := False;
    Exit;
  end;
  LFingerprintHex := FPeerCertificate.GetFingerprintSHA256;
  SetLength(LFingerprint, Length(LFingerprintHex) div 2);
  for I := 0 to High(LFingerprint) do
    LFingerprint[I] := StrToInt('$' + Copy(LFingerprintHex, I * 2 + 1, 2));
  if not LPinValidator.ValidateCertificatePin(LFingerprint) then
  begin
    SetHandshakeError(sslErrCertificate, 'Certificate pinning validation failed: peer certificate does not match any configured pin');
    Result := False;
  end;
end;

function TFreePascalConnection.ValidateClientPeerCertificateFlags: Boolean;
var
  LVerifyMode: TSSLVerifyModes;
  LVerifyFlags: TSSLCertVerifyFlags;
  LNormalizedHost: string;
begin
  Result := False;

  if FContext = nil then
  begin
    SetHandshakeError(sslErrInvalidParam, 'TLS context is not available for peer certificate verification');
    Exit;
  end;

  LVerifyMode := FContext.GetVerifyMode;
  if not (sslVerifyPeer in LVerifyMode) then
    Exit(True);

  if FSessionReused then
  begin
    { PSK resumption: skip certificate chain verification but still verify
      that the current connection server name matches the name bound to the
      resumed session. This prevents cross-host session ticket misuse. }
    LVerifyFlags := FContext.GetCertVerifyFlags;
    if not (sslCertVerifyIgnoreHostname in LVerifyFlags) then
    begin
      LNormalizedHost := NormalizeHostForVerify(FServerName);
      if LNormalizedHost = '' then
      begin
        SetHandshakeError(sslErrHostnameMismatch,
          'Resumed session hostname verification requires a non-empty server name');
        Exit;
      end;
      if not SameText(NormalizeHostForVerify(FSessionBoundServerName), LNormalizedHost) then
      begin
        SetHandshakeError(sslErrHostnameMismatch,
          Format('Resumed session was bound to "%s" but current connection targets "%s"',
            [FSessionBoundServerName, FServerName]));
        Exit;
      end;
    end;
    Exit(True);
  end;

  if FPeerCertificate = nil then
  begin
    SetHandshakeError(sslErrCertificate, 'Peer certificate is required for client verification');
    Exit;
  end;

  LVerifyFlags := FContext.GetCertVerifyFlags;
  if not (sslCertVerifyIgnoreHostname in LVerifyFlags) then
  begin
    LNormalizedHost := NormalizeHostForVerify(FServerName);
    if LNormalizedHost = '' then
    begin
      SetHandshakeError(sslErrHostnameMismatch,
        'Peer certificate hostname verification requires a non-empty server name');
      Exit;
    end;

    if not FPeerCertificate.VerifyHostname(LNormalizedHost) then
    begin
      SetHandshakeError(sslErrHostnameMismatch,
        Format('Peer certificate hostname mismatch for "%s"', [LNormalizedHost]));
      Exit;
    end;
  end;

  if not (sslCertVerifyIgnoreExpiry in LVerifyFlags) and FPeerCertificate.IsExpired then
  begin
    SetHandshakeError(sslErrCertificateExpired, 'Peer certificate is expired');
    Exit;
  end;

  Result := True;
end;

function TFreePascalConnection.ValidateClientOCSPStapling: Boolean;
var
  LVerifyMode: TSSLVerifyModes;
  LOptions: TSSLOptions;
  LStaplingConfig: TOCSPStaplingConfig;
  LStaplingClient: TOCSPStaplingClient;
  LStaplingResult: TOCSPStaplingResult;
  LLeafCertificate: TX509Certificate;
  LIssuerCertificate: TX509Certificate;
  LError: string;
  LEnabled: Boolean;
  LRequired: Boolean;
begin
  Result := False;

  if FContext = nil then
  begin
    SetHandshakeError(sslErrInvalidParam, 'TLS context is not available for OCSP stapling validation');
    Exit;
  end;

  LOptions := FContext.GetOptions;
  LRequired := ssoRequireOCSPStapling in LOptions;
  LEnabled := LRequired or (ssoEnableOCSPStapling in LOptions);
  if not LEnabled then
    Exit(True);

  LVerifyMode := FContext.GetVerifyMode;
  if not (sslVerifyPeer in LVerifyMode) then
    Exit(True);

  if FSessionReused then
    Exit(True);

  if Length(FOCSPResponse) = 0 then
  begin
    FOCSPResponseVerified := False;
    FOCSPResponseStatus := 'No OCSP Response';
    if LRequired then
    begin
      SetHandshakeError(sslErrCertificate, 'Required OCSP stapling response was not provided by the server');
      Exit;
    end;
    Exit(True);
  end;

  if not TryBuildPeerOCSPCertificatePair(LLeafCertificate, LIssuerCertificate, LError) then
  begin
    FOCSPResponseVerified := False;
    FOCSPResponseStatus := 'Verification Failed: ' + LError;
    if LRequired then
    begin
      SetHandshakeError(sslErrCertificate, 'Required OCSP stapling verification context is unavailable: ' + LError);
      Exit;
    end;
    Exit(True);
  end;

  LStaplingConfig := TOCSPStaplingConfig.Default;
  LStaplingConfig.EnableClientRequest := True;
  LStaplingConfig.RequireStapling := LRequired;
  LStaplingConfig.UseCache := False;
  LStaplingClient := TOCSPStaplingClient.Create(LStaplingConfig);
  try
    LStaplingResult := LStaplingClient.ProcessStapledResponse(
      FOCSPResponse,
      LLeafCertificate,
      LIssuerCertificate
    );
    FOCSPResponseVerified := LStaplingResult.IsValid;
    FOCSPResponseStatus := OCSPStaplingStateToString(
      LStaplingResult.Status,
      LStaplingResult.ErrorMessage
    );

    if not LStaplingClient.ValidateStaplingRequirement(True) then
    begin
      if LRequired then
      begin
        SetHandshakeError(
          sslErrCertificate,
          'Required OCSP stapling validation failed: ' + FOCSPResponseStatus
        );
        Exit;
      end;
    end;
  finally
    LStaplingClient.Free;
    LLeafCertificate.Free;
    LIssuerCertificate.Free;
  end;

  Result := True;
end;

function TFreePascalConnection.ValidateClientOnlineOCSP: Boolean;
var
  LVerifyMode: TSSLVerifyModes;
  LVerifyFlags: TSSLCertVerifyFlags;
begin
  Result := False;

  if FContext = nil then
  begin
    SetHandshakeError(sslErrInvalidParam, 'TLS context is not available for online OCSP verification');
    Exit;
  end;

  LVerifyMode := FContext.GetVerifyMode;
  if not (sslVerifyPeer in LVerifyMode) then
    Exit(True);

  if FSessionReused then
    Exit(True);

  LVerifyFlags := FContext.GetCertVerifyFlags;
  if not (sslCertVerifyCheckOCSP in LVerifyFlags) then
    Exit(True);

  SetHandshakeError(sslErrUnsupported,
    'Pure Pascal online OCSP verification not yet implemented');
end;

function TFreePascalConnection.ValidateClientCertificateTransparency: Boolean;
var
  LVerifyMode: TSSLVerifyModes;
  LStatus: string;
begin
  Result := False;

  if FContext = nil then
  begin
    SetHandshakeError(sslErrInvalidParam, 'TLS context is not available for certificate transparency validation');
    Exit;
  end;

  LVerifyMode := FContext.GetVerifyMode;
  if not (sslVerifyPeer in LVerifyMode) then
    Exit(True);

  if FSessionReused then
    Exit(True);

  if not (ssoRequireCertificateTransparency in FContext.GetOptions) then
    Exit(True);

  if Length(FSignedCertificateTimestampList) = 0 then
  begin
    SetHandshakeError(
      sslErrCertificate,
      'Required certificate transparency SCT list was not provided by the server'
    );
    Exit;
  end;

  if not FHasCertificateTransparencyValidationResult then
  begin
    LStatus := Trim(FCertificateTransparencyValidationStatus);
    if LStatus = '' then
      LStatus := 'No validation result';
    SetHandshakeError(
      sslErrCertificate,
      'Required certificate transparency validation is unavailable: ' + LStatus
    );
    Exit;
  end;

  if not FCertificateTransparencyPolicySatisfied then
  begin
    LStatus := Trim(FCertificateTransparencyValidationStatus);
    if LStatus = '' then
      LStatus := 'Policy not satisfied';
    SetHandshakeError(
      sslErrCertificate,
      'Required certificate transparency policy failed: ' + LStatus
    );
    Exit;
  end;

  Result := True;
end;
