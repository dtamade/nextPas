unit nextpas.core.tls.tls12.server;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.tls12.ciphersuite,
  nextpas.core.tls.x509;

type
  TSSLSNICallback = function(const AHostname: string; out ACertDER, AKeyDER: TBytes): Boolean;
  TTLS12ServerSessionLookup = function(const ASessionID: TBytes;
    out AMasterSecret: TBytes; out ACipherSuite: Word): Boolean of object;

  TTLS12ServerConfig = record
    Certificate: TX509Certificate;
    CertificateDER: TBytes;
    PrivateKeyDER: TBytes;
    ServerName: string;
    SupportEMS: Boolean;
    ALPNProtocols: array of string;
    RequestClientCert: Boolean;
    SNICallback: TSSLSNICallback;
    CipherSuites: TTLS12CipherSuiteList;
    SessionID: TBytes;
    SessionCacheEnabled: Boolean;
    SessionLookup: TTLS12ServerSessionLookup;
  end;

  TTLS12ServerState = record
    ClientRandom: TBytes;
    ServerRandom: TBytes;
    MasterSecret: TBytes;
    ClientWriteKey: TBytes;
    ServerWriteKey: TBytes;
    ClientWriteIV: TBytes;
    ServerWriteIV: TBytes;
    CipherSuite: Word;
    ProtocolVersion: TSSLProtocolVersion;
    ClientSeqNum: UInt64;
    ServerSeqNum: UInt64;
    HasEMS: Boolean;
    NegotiatedGroup: Word;
    ALPNProtocol: string;
    ClientCertificateDER: TBytes;
    SessionID: TBytes;
    Resumed: Boolean;
  end;

function TryTLS12ServerHandshake(
  AStream: TStream;
  const AConfig: TTLS12ServerConfig;
  out AState: TTLS12ServerState;
  out AError: string
): Boolean;

implementation

uses
  nextpas.core.tls.tls12.wire,
  nextpas.core.tls.tls12.io,
  nextpas.core.tls.tls12.parser,
  nextpas.core.tls.tls12.recordcrypto,
  nextpas.core.tls.tls12.chacha20record,
  nextpas.core.tls.crypto.tls12record,
  nextpas.core.tls.tls12.handshakecrypto,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.ecdsa,
  nextpas.core.tls.tls13.servercertverify,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.constant_time,
  nextpas.core.tls.memutils,
  nextpas.core.tls.random;

function ParseALPNFromExtension(const AData: TBytes; AOffset, ALen: Integer;
  const ASupported: array of string): string;
var
  LEnd, LProtoLen, J: Integer;
  LProto: string;
begin
  Result := '';
  LEnd := AOffset + ALen;
  Inc(AOffset, 2);
  while AOffset < LEnd do
  begin
    LProtoLen := AData[AOffset];
    Inc(AOffset);
    if AOffset + LProtoLen > LEnd then Break;
    SetString(LProto, PAnsiChar(@AData[AOffset]), LProtoLen);
    for J := 0 to High(ASupported) do
      if ASupported[J] = LProto then
        Exit(LProto);
    Inc(AOffset, LProtoLen);
  end;
end;

function CipherSuiteAuthMatches(AID: Word; AIsECDSA: Boolean): Boolean;
var
  LInfo: TTLS12CipherSuiteInfo;
begin
  if not TLS12GetCipherSuiteInfo(AID, LInfo) then
    Exit(False);

  if AIsECDSA then
    Result := LInfo.AuthType = atECDSA
  else
    Result := LInfo.AuthType = atRSA;
end;

function ClientOffersCipherSuite(const AClientSuites: array of Word; AID: Word): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(AClientSuites) do
    if AClientSuites[I] = AID then
      Exit(True);
end;

function SelectCipherSuite(
  const AClientSuites: array of Word;
  const AConfiguredSuites: array of Word;
  AIsECDSA: Boolean
): Word;
var
  I: Integer;
  LSupported: array[0..7] of Word;
  LSupportedCount, J: Integer;
begin
  Result := 0;

  if Length(AConfiguredSuites) > 0 then
  begin
    for J := 0 to High(AConfiguredSuites) do
      if CipherSuiteAuthMatches(AConfiguredSuites[J], AIsECDSA) and
        ClientOffersCipherSuite(AClientSuites, AConfiguredSuites[J]) then
        Exit(AConfiguredSuites[J]);
    Exit;
  end;

  // Server preference order: ChaCha20 > GCM-256 > GCM-128 > CBC
  if AIsECDSA then
  begin
    LSupported[0] := TLS12_CIPHER_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256;
    LSupported[1] := TLS12_CIPHER_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384;
    LSupported[2] := TLS12_CIPHER_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256;
    LSupportedCount := 3;
  end
  else
  begin
    LSupported[0] := TLS12_CIPHER_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256;
    LSupported[1] := TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_GCM_SHA384;
    LSupported[2] := TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_GCM_SHA256;
    LSupported[3] := TLS12_CIPHER_ECDHE_RSA_WITH_AES_256_CBC_SHA384;
    LSupported[4] := TLS12_CIPHER_ECDHE_RSA_WITH_AES_128_CBC_SHA256;
    LSupportedCount := 5;
  end;

  // Server preference: iterate our list, check if client offers it
  for J := 0 to LSupportedCount - 1 do
    for I := 0 to High(AClientSuites) do
      if AClientSuites[I] = LSupported[J] then
        Exit(LSupported[J]);
end;

function TryTLS12ServerHandshake(
  AStream: TStream;
  const AConfig: TTLS12ServerConfig;
  out AState: TTLS12ServerState;
  out AError: string
): Boolean;
var
  LContentType: Byte;
  LData, LClientHelloFull: TBytes;
  LTranscript: TBytes;
  LPos, LCipherSuiteLen, LCompLen, I: Integer;
  LClientSuites: array of Word;
  LServerHello, LCertMsg, LSKE, LSHD: TBytes;
  LServerHelloBody, LCertBody, LSKEBody: TBytes;
  LPrivateKey, LPublicKey: TBytes;
  LClientCKE, LClientCCS, LClientFinished: TBytes;
  LDecFinished: TBytes;
  LDecError: string;
  LKeyBlock: TTLS12KeyBlock;
  LExpectedFinished, LChangeCipherSpec, LFinished: TBytes;
  LEncFinished: TBytes;
  LEncError: string;
  LSKESignature, LSKESignedData: TBytes;
  LUseSHA384: Boolean;
  LSuiteInfo: TTLS12CipherSuiteInfo;
  LKeyLen: Integer;
  LIVLen: Integer;
  LHandshakeType: Byte;
  LBodyLen: Integer;
  LClientPubKey: TBytes;
  LSharedSecret: TBytes;
  LClientCert: TX509Certificate;
  LECPoint: TECPoint;
  LSNIHost: string;
  LSNICert, LSNIKey: TBytes;
  LUseSNICert: Boolean;
  LEffectiveCertDER: TBytes;
  LEffectiveKeyDER: TBytes;
  LEffectiveIsECDSA: Boolean;
  LClientSessionID: TBytes;
  LSessionIDLen: Integer;
  LServerSessionID: TBytes;
  LCachedMasterSecret: TBytes;
  LCachedCipherSuite: Word;
  LIsResumed: Boolean;
begin
  AError := '';
  Result := False;
  LUseSNICert := False;
  LSNIHost := '';
  FillChar(AState, SizeOf(AState), 0);

  // 1. Read ClientHello handshake message, allowing TLS record fragmentation.
  if not TLS12ReadHandshakeMessage(AStream, LHandshakeType, LData, LClientHelloFull, AError) then
  begin
    if AError = '' then
      AError := 'Failed to read ClientHello handshake message'
    else
      AError := 'Failed to read ClientHello handshake message: ' + AError;
    Exit;
  end;
  if LHandshakeType <> TLS12_HANDSHAKE_CLIENT_HELLO then
  begin
    AError := 'Expected ClientHello handshake message';
    Exit;
  end;

  SetLength(LTranscript, 0);
  TLS12AppendTranscript(LTranscript, LClientHelloFull);

  // Parse ClientHello minimally: skip version(2) + random(32) + session_id
  LPos := 0;
  if LPos + 34 > Length(LData) then
  begin
    AError := 'ClientHello too short';
    Exit;
  end;
  Inc(LPos, 2); // version

  SetLength(AState.ClientRandom, 32);
  Move(LData[LPos], AState.ClientRandom[0], 32);
  Inc(LPos, 32);

  // Parse session ID
  if LPos >= Length(LData) then begin AError := 'ClientHello truncated'; Exit; end;
  LSessionIDLen := LData[LPos];
  Inc(LPos);
  if LPos + LSessionIDLen > Length(LData) then begin AError := 'ClientHello session ID truncated'; Exit; end;
  if LSessionIDLen > 0 then
    LClientSessionID := Copy(LData, LPos, LSessionIDLen)
  else
    SetLength(LClientSessionID, 0);
  Inc(LPos, LSessionIDLen);

  // Parse cipher suites
  if LPos + 2 > Length(LData) then begin AError := 'ClientHello cipher suites truncated'; Exit; end;
  LCipherSuiteLen := (Integer(LData[LPos]) shl 8) or Integer(LData[LPos + 1]);
  Inc(LPos, 2);
  if LPos + LCipherSuiteLen > Length(LData) then begin AError := 'ClientHello cipher suites truncated'; Exit; end;

  SetLength(LClientSuites, LCipherSuiteLen div 2);
  for I := 0 to (LCipherSuiteLen div 2) - 1 do
    LClientSuites[I] := (Word(LData[LPos + I*2]) shl 8) or Word(LData[LPos + I*2 + 1]);
  Inc(LPos, LCipherSuiteLen);

  // Skip compression
  if LPos >= Length(LData) then begin AError := 'ClientHello compression truncated'; Exit; end;
  LCompLen := LData[LPos];
  Inc(LPos, 1 + LCompLen);

  // Parse extensions for ALPN and EMS
  AState.HasEMS := False;
  AState.ALPNProtocol := '';
  if LPos + 2 <= Length(LData) then
  begin
    LBodyLen := (Integer(LData[LPos]) shl 8) or Integer(LData[LPos + 1]);
    Inc(LPos, 2);
    LCompLen := LPos + LBodyLen; // end of extensions
    while LPos + 4 <= LCompLen do
    begin
      I := (Integer(LData[LPos]) shl 8) or Integer(LData[LPos + 1]); // ext type
      LCipherSuiteLen := (Integer(LData[LPos + 2]) shl 8) or Integer(LData[LPos + 3]); // ext data len
      Inc(LPos, 4);
      if LPos + LCipherSuiteLen > LCompLen then Break;

      if I = TLS12_EXT_EXTENDED_MASTER_SECRET then
        AState.HasEMS := AConfig.SupportEMS
      else if (I = TLS12_EXT_ALPN) and (LCipherSuiteLen >= 4) and (Length(AConfig.ALPNProtocols) > 0) then
        AState.ALPNProtocol := ParseALPNFromExtension(LData, LPos, LCipherSuiteLen, AConfig.ALPNProtocols)
      else if (I = 0) and (LCipherSuiteLen >= 5) and Assigned(AConfig.SNICallback) then
      begin
        // SNI extension: parse hostname and invoke callback
        if (LPos + 5 <= Length(LData)) and (LData[LPos + 2] = 0) then
        begin
          LBodyLen := (Integer(LData[LPos + 3]) shl 8) or Integer(LData[LPos + 4]);
          if (LBodyLen > 0) and (LPos + 5 + LBodyLen <= Length(LData)) then
          begin
            SetLength(LSNIHost, LBodyLen);
            Move(LData[LPos + 5], LSNIHost[1], LBodyLen);
            if AConfig.SNICallback(LSNIHost, LSNICert, LSNIKey) then
            begin
              LUseSNICert := True;
            end;
          end;
        end;
      end;

      Inc(LPos, LCipherSuiteLen);
    end;
  end;

  // RFC 7627: EMS only if BOTH client requested AND server supports it

  // === Session Resumption Check ===
  LIsResumed := False;
  if (Length(LClientSessionID) > 0) and Assigned(AConfig.SessionLookup) then
  begin
    if AConfig.SessionLookup(LClientSessionID, LCachedMasterSecret, LCachedCipherSuite) then
    begin
      if ClientOffersCipherSuite(LClientSuites, LCachedCipherSuite) and
         TLS12GetCipherSuiteInfo(LCachedCipherSuite, LSuiteInfo) then
        LIsResumed := True;
    end;
  end;

  if LIsResumed then
  begin
    // === Abbreviated Handshake (RFC 5246 §7.3) ===
    AState.CipherSuite := LCachedCipherSuite;
    AState.MasterSecret := LCachedMasterSecret;
    AState.SessionID := LClientSessionID;
    AState.Resumed := True;
    LUseSHA384 := LSuiteInfo.PRFHash = phSHA384;
    LKeyLen := LSuiteInfo.KeyLen;
    LIVLen := LSuiteInfo.IVLen;

    SetLength(AState.ServerRandom, 32);
    SecureRandomBytes(@AState.ServerRandom[0], 32);

    // Build ServerHello echoing client's session ID
    SetLength(LServerHelloBody, 0);
    SetLength(LServerHelloBody, 38 + Length(LClientSessionID));
    LServerHelloBody[0] := 3; LServerHelloBody[1] := 3;
    Move(AState.ServerRandom[0], LServerHelloBody[2], 32);
    LServerHelloBody[34] := Byte(Length(LClientSessionID));
    Move(LClientSessionID[0], LServerHelloBody[35], Length(LClientSessionID));
    LServerHelloBody[35 + Length(LClientSessionID)] := Byte(AState.CipherSuite shr 8);
    LServerHelloBody[36 + Length(LClientSessionID)] := Byte(AState.CipherSuite);
    LServerHelloBody[37 + Length(LClientSessionID)] := 0;

    // Extensions: renegotiation_info + EMS
    I := Length(LServerHelloBody);
    LBodyLen := 5;
    if AState.HasEMS then Inc(LBodyLen, 4);
    SetLength(LServerHelloBody, I + 2 + LBodyLen);
    LServerHelloBody[I] := Byte(LBodyLen shr 8);
    LServerHelloBody[I+1] := Byte(LBodyLen);
    Inc(I, 2);
    LServerHelloBody[I] := $FF; LServerHelloBody[I+1] := $01;
    LServerHelloBody[I+2] := 0; LServerHelloBody[I+3] := 1;
    LServerHelloBody[I+4] := 0;
    Inc(I, 5);
    if AState.HasEMS then
    begin
      LServerHelloBody[I] := 0; LServerHelloBody[I+1] := $17;
      LServerHelloBody[I+2] := 0; LServerHelloBody[I+3] := 0;
    end;

    // Wrap as handshake and send
    SetLength(LServerHello, 4 + Length(LServerHelloBody));
    LServerHello[0] := TLS12_HANDSHAKE_SERVER_HELLO;
    LServerHello[1] := Byte(Length(LServerHelloBody) shr 16);
    LServerHello[2] := Byte(Length(LServerHelloBody) shr 8);
    LServerHello[3] := Byte(Length(LServerHelloBody));
    Move(LServerHelloBody[0], LServerHello[4], Length(LServerHelloBody));
    TLS12AppendTranscript(LTranscript, LServerHello);
    TLS12SendRecord(AStream, TLS12_CONTENT_HANDSHAKE, LServerHello);

    // Derive record keys from cached master secret + new randoms
    if LUseSHA384 then
      LKeyBlock := TLS12DeriveKeyBlock_SHA384(AState.MasterSecret,
        AState.ServerRandom, AState.ClientRandom, LKeyLen, LIVLen)
    else
      LKeyBlock := TLS12DeriveKeyBlock_SHA256(AState.MasterSecret,
        AState.ServerRandom, AState.ClientRandom, LKeyLen, LIVLen);
    AState.ClientWriteKey := LKeyBlock.ClientWriteKey;
    AState.ServerWriteKey := LKeyBlock.ServerWriteKey;
    AState.ClientWriteIV := LKeyBlock.ClientWriteIV;
    AState.ServerWriteIV := LKeyBlock.ServerWriteIV;

    // Server sends CCS first in abbreviated handshake
    SetLength(LChangeCipherSpec, 1);
    LChangeCipherSpec[0] := 1;
    TLS12SendRecord(AStream, TLS12_CONTENT_CHANGE_CIPHER_SPEC, LChangeCipherSpec);

    // Server Finished
    if LUseSHA384 then
      LExpectedFinished := TLS12ComputeFinished_SHA384(AState.MasterSecret, SHA384(LTranscript), False)
    else
      LExpectedFinished := TLS12ComputeFinished_SHA256(AState.MasterSecret, SHA256(LTranscript), False);

    SetLength(LFinished, 16);
    LFinished[0] := TLS12_HANDSHAKE_FINISHED;
    LFinished[1] := 0; LFinished[2] := 0; LFinished[3] := 12;
    Move(LExpectedFinished[0], LFinished[4], 12);
    TLS12AppendTranscript(LTranscript, LFinished);

    case LSuiteInfo.RecordMode of
      rmChaCha20Poly1305:
        if not TLS12ChaCha20Poly1305EncryptRecord(AState.ServerWriteKey, AState.ServerWriteIV,
          0, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
        begin AError := 'Abbreviated: encrypt server Finished failed: ' + LEncError; Exit; end;
      rmCBC:
        if LUseSHA384 then
        begin
          if not TLS12CBCEncrypt_SHA384(AState.ServerWriteKey, LKeyBlock.ServerWriteMACKey,
            0, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
          begin AError := 'Abbreviated: encrypt server Finished failed: ' + LEncError; Exit; end;
        end
        else
        begin
          if not TLS12CBCEncrypt_SHA256(AState.ServerWriteKey, LKeyBlock.ServerWriteMACKey,
            0, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
          begin AError := 'Abbreviated: encrypt server Finished failed: ' + LEncError; Exit; end;
        end;
    else
      if not TLS12GCMEncryptRecord(AState.ServerWriteKey, AState.ServerWriteIV,
        0, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
      begin AError := 'Abbreviated: encrypt server Finished failed: ' + LEncError; Exit; end;
    end;
    TLS12SendRecord(AStream, TLS12_CONTENT_HANDSHAKE, LEncFinished);
    AState.ServerSeqNum := 1;

    // Read client CCS
    if not TLS12ReadRecord(AStream, LContentType, LData) then
    begin AError := 'Abbreviated: failed to read client CCS'; Exit; end;
    if LContentType <> TLS12_CONTENT_CHANGE_CIPHER_SPEC then
    begin AError := 'Abbreviated: expected client CCS'; Exit; end;

    // Read client Finished (encrypted)
    if not TLS12ReadRecord(AStream, LContentType, LData) then
    begin AError := 'Abbreviated: failed to read client Finished'; Exit; end;

    case LSuiteInfo.RecordMode of
      rmChaCha20Poly1305:
        if not TLS12ChaCha20Poly1305DecryptRecord(AState.ClientWriteKey, AState.ClientWriteIV,
          0, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
        begin AError := 'Abbreviated: decrypt client Finished failed: ' + LDecError; Exit; end;
      rmCBC:
        if LUseSHA384 then
        begin
          if not TLS12CBCDecrypt_SHA384(AState.ClientWriteKey, LKeyBlock.ClientWriteMACKey,
            0, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
          begin AError := 'Abbreviated: decrypt client Finished failed: ' + LDecError; Exit; end;
        end
        else
        begin
          if not TLS12CBCDecrypt_SHA256(AState.ClientWriteKey, LKeyBlock.ClientWriteMACKey,
            0, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
          begin AError := 'Abbreviated: decrypt client Finished failed: ' + LDecError; Exit; end;
        end;
    else
      if not TLS12GCMDecryptRecord(AState.ClientWriteKey, AState.ClientWriteIV,
        0, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
      begin AError := 'Abbreviated: decrypt client Finished failed: ' + LDecError; Exit; end;
    end;

    // Verify client Finished
    if LUseSHA384 then
      LExpectedFinished := TLS12ComputeFinished_SHA384(AState.MasterSecret, SHA384(LTranscript), True)
    else
      LExpectedFinished := TLS12ComputeFinished_SHA256(AState.MasterSecret, SHA256(LTranscript), True);

    if (Length(LDecFinished) < 16) or
       (TConstantTime.CompareBuffer(@LDecFinished[4], @LExpectedFinished[0], 12) <> 1) then
    begin
      AError := 'Abbreviated: client Finished verify_data mismatch';
      Exit;
    end;

    AState.ClientSeqNum := 1;
    AState.ProtocolVersion := sslProtocolTLS12;
    Result := True;
    Exit;
  end;

  // === Full Handshake (existing path) ===
  // AState.HasEMS is already set correctly above (True only if client sent the extension AND config allows)

  // Apply SNI certificate override
  if LUseSNICert and (Length(LSNICert) > 0) and (Length(LSNIKey) > 0) then
  begin
    LEffectiveCertDER := LSNICert;
    LEffectiveKeyDER := LSNIKey;
    LEffectiveIsECDSA := False; // Default; could parse cert to determine
  end
  else
  begin
    LEffectiveCertDER := AConfig.CertificateDER;
    LEffectiveKeyDER := AConfig.PrivateKeyDER;
    LEffectiveIsECDSA := (AConfig.Certificate.PublicKeyInfo.KeyType = 'ECDSA');
  end;

  // Select cipher suite
  AState.CipherSuite := SelectCipherSuite(
    LClientSuites,
    AConfig.CipherSuites,
    LEffectiveIsECDSA
  );
  if AState.CipherSuite = 0 then
  begin
    AError := 'No common cipher suite';
    Exit;
  end;

  if not TLS12GetCipherSuiteInfo(AState.CipherSuite, LSuiteInfo) then
  begin
    AError := 'Internal: unsupported cipher suite selected';
    Exit;
  end;
  LUseSHA384 := LSuiteInfo.PRFHash = phSHA384;
  LKeyLen := LSuiteInfo.KeyLen;
  LIVLen := LSuiteInfo.IVLen;

  // AState.HasEMS is set by extension parsing above (RFC 7627: both sides must agree)
  AState.NegotiatedGroup := TLS12_GROUP_X25519;

  // 2. Generate ServerRandom
  SetLength(AState.ServerRandom, 32);
  SecureRandomBytes(@AState.ServerRandom[0], 32);

  // 3. Generate session ID for resumption
  if AConfig.SessionCacheEnabled then
  begin
    SetLength(LServerSessionID, 32);
    SecureRandomBytes(@LServerSessionID[0], 32);
  end
  else
    SetLength(LServerSessionID, 0);
  AState.SessionID := LServerSessionID;
  AState.Resumed := False;

  // 4. Build and send ServerHello
  SetLength(LServerHelloBody, 0);
  SetLength(LServerHelloBody, 38 + Length(LServerSessionID));
  LServerHelloBody[0] := 3; LServerHelloBody[1] := 3; // TLS 1.2
  Move(AState.ServerRandom[0], LServerHelloBody[2], 32);
  LServerHelloBody[34] := Byte(Length(LServerSessionID));
  if Length(LServerSessionID) > 0 then
    Move(LServerSessionID[0], LServerHelloBody[35], Length(LServerSessionID));
  LServerHelloBody[35 + Length(LServerSessionID)] := Byte(AState.CipherSuite shr 8);
  LServerHelloBody[36 + Length(LServerSessionID)] := Byte(AState.CipherSuite);
  LServerHelloBody[37 + Length(LServerSessionID)] := 0; // no compression

  // Build extensions dynamically
  I := Length(LServerHelloBody);
  LBodyLen := 5; // renegotiation_info always present
  if AState.HasEMS then Inc(LBodyLen, 4);
  if AState.ALPNProtocol <> '' then Inc(LBodyLen, 4 + 2 + 1 + Length(AState.ALPNProtocol));

  SetLength(LServerHelloBody, I + 2 + LBodyLen);
  LServerHelloBody[I] := Byte(LBodyLen shr 8);
  LServerHelloBody[I+1] := Byte(LBodyLen);
  Inc(I, 2);

  // renegotiation_info (0xFF01)
  LServerHelloBody[I] := $FF; LServerHelloBody[I+1] := $01;
  LServerHelloBody[I+2] := 0; LServerHelloBody[I+3] := 1;
  LServerHelloBody[I+4] := 0;
  Inc(I, 5);

  // EMS (0x0017)
  if AState.HasEMS then
  begin
    LServerHelloBody[I] := 0; LServerHelloBody[I+1] := 23;
    LServerHelloBody[I+2] := 0; LServerHelloBody[I+3] := 0;
    Inc(I, 4);
  end;

  // ALPN (0x0010)
  if AState.ALPNProtocol <> '' then
  begin
    LCompLen := Length(AState.ALPNProtocol);
    LServerHelloBody[I] := 0; LServerHelloBody[I+1] := 16; // ALPN ext type
    LServerHelloBody[I+2] := Byte((LCompLen + 3) shr 8);
    LServerHelloBody[I+3] := Byte(LCompLen + 3); // ext data len
    LServerHelloBody[I+4] := Byte((LCompLen + 1) shr 8);
    LServerHelloBody[I+5] := Byte(LCompLen + 1); // protocol list len
    LServerHelloBody[I+6] := Byte(LCompLen); // protocol len
    Move(AState.ALPNProtocol[1], LServerHelloBody[I+7], LCompLen);
  end;

  LServerHello := TLS12BuildHandshakeHeader(TLS12_HANDSHAKE_SERVER_HELLO, Length(LServerHelloBody));
  SetLength(LServerHello, Length(LServerHello) + Length(LServerHelloBody));
  Move(LServerHelloBody[0], LServerHello[4], Length(LServerHelloBody));

  if not TLS12SendRecord(AStream, TLS12_CONTENT_HANDSHAKE, LServerHello) then
  begin AError := 'Failed to send ServerHello'; Exit; end;
  TLS12AppendTranscript(LTranscript, LServerHello);

  // 4. Send Certificate
  SetLength(LCertBody, 3 + 3 + Length(LEffectiveCertDER));
  I := Length(LEffectiveCertDER);
  // Total certs length
  LCertBody[0] := Byte((I + 3) shr 16);
  LCertBody[1] := Byte((I + 3) shr 8);
  LCertBody[2] := Byte(I + 3);
  // Single cert length
  LCertBody[3] := Byte(I shr 16);
  LCertBody[4] := Byte(I shr 8);
  LCertBody[5] := Byte(I);
  Move(LEffectiveCertDER[0], LCertBody[6], I);

  LCertMsg := TLS12BuildHandshakeHeader(TLS12_HANDSHAKE_CERTIFICATE, Length(LCertBody));
  SetLength(LCertMsg, Length(LCertMsg) + Length(LCertBody));
  Move(LCertBody[0], LCertMsg[4], Length(LCertBody));

  if not TLS12SendRecord(AStream, TLS12_CONTENT_HANDSHAKE, LCertMsg) then
  begin AError := 'Failed to send Certificate'; Exit; end;
  TLS12AppendTranscript(LTranscript, LCertMsg);

  // 5. Generate ECDHE keypair and send ServerKeyExchange
  SetLength(LPrivateKey, 32);
  SecureRandomBytes(@LPrivateKey[0], 32);
  LPublicKey := X25519PublicKeyFromPrivate(LPrivateKey);

  // SKE params: curve_type(1) + named_curve(2) + pubkey_len(1) + pubkey(32)
  SetLength(LSKEBody, 36);
  LSKEBody[0] := 3; // named_curve
  LSKEBody[1] := Byte(TLS12_GROUP_X25519 shr 8);
  LSKEBody[2] := Byte(TLS12_GROUP_X25519);
  LSKEBody[3] := 32;
  Move(LPublicKey[0], LSKEBody[4], 32);

  // Sign: client_random + server_random + SKE_params
  SetLength(LSKESignedData, 64 + Length(LSKEBody));
  Move(AState.ClientRandom[0], LSKESignedData[0], 32);
  Move(AState.ServerRandom[0], LSKESignedData[32], 32);
  Move(LSKEBody[0], LSKESignedData[64], Length(LSKEBody));

  // Select signature scheme based on certificate key type
  if AConfig.Certificate.PublicKeyInfo.KeyType = 'ECDSA' then
    LCipherSuiteLen := $0403 // ecdsa_secp256r1_sha256
  else if LUseSHA384 then
    LCipherSuiteLen := $0501 // rsa_pkcs1_sha384
  else
    LCipherSuiteLen := $0401; // rsa_pkcs1_sha256

  if not TryBuildTLS13CertificateVerifySignature(Word(LCipherSuiteLen), LEffectiveKeyDER,
    LSKESignedData, LSKESignature, AError) then
  begin
    AError := 'SKE signature failed: ' + AError;
    Exit;
  end;

  // Append signature to SKE body: sig_scheme(2) + sig_len(2) + signature
  I := Length(LSKEBody);
  SetLength(LSKEBody, I + 4 + Length(LSKESignature));
  LSKEBody[I] := Byte(LCipherSuiteLen shr 8);
  LSKEBody[I+1] := Byte(LCipherSuiteLen);
  LSKEBody[I+2] := Byte(Length(LSKESignature) shr 8);
  LSKEBody[I+3] := Byte(Length(LSKESignature));
  Move(LSKESignature[0], LSKEBody[I+4], Length(LSKESignature));

  LSKE := TLS12BuildHandshakeHeader(TLS12_HANDSHAKE_SERVER_KEY_EXCHANGE, Length(LSKEBody));
  SetLength(LSKE, Length(LSKE) + Length(LSKEBody));
  Move(LSKEBody[0], LSKE[4], Length(LSKEBody));

  if not TLS12SendRecord(AStream, TLS12_CONTENT_HANDSHAKE, LSKE) then
  begin AError := 'Failed to send ServerKeyExchange'; Exit; end;
  TLS12AppendTranscript(LTranscript, LSKE);

  // 5b. Send CertificateRequest if mTLS enabled
  if AConfig.RequestClientCert then
  begin
    // CertificateRequest: cert_types(2) + sig_algs(8) + CA_names(2=empty)
    SetLength(LSKEBody, 12);
    LSKEBody[0] := 1; // 1 certificate type
    LSKEBody[1] := 1; // rsa_sign
    LSKEBody[2] := 0; LSKEBody[3] := 4; // sig_algs length = 4
    LSKEBody[4] := $04; LSKEBody[5] := $01; // rsa_pkcs1_sha256
    LSKEBody[6] := $04; LSKEBody[7] := $03; // ecdsa_secp256r1_sha256
    LSKEBody[8] := 0; LSKEBody[9] := 0; // CA distinguished names length = 0
    // Note: actual length is 10 bytes
    SetLength(LSKEBody, 10);

    LData := TLS12BuildHandshakeHeader(TLS12_HANDSHAKE_CERTIFICATE_REQUEST, Length(LSKEBody));
    SetLength(LData, Length(LData) + Length(LSKEBody));
    Move(LSKEBody[0], LData[4], Length(LSKEBody));

    if not TLS12SendRecord(AStream, TLS12_CONTENT_HANDSHAKE, LData) then
    begin AError := 'Failed to send CertificateRequest'; Exit; end;
    TLS12AppendTranscript(LTranscript, LData);
  end;

  // 6. Send ServerHelloDone
  LSHD := TLS12BuildHandshakeHeader(TLS12_HANDSHAKE_SERVER_HELLO_DONE, 0);
  if not TLS12SendRecord(AStream, TLS12_CONTENT_HANDSHAKE, LSHD) then
  begin AError := 'Failed to send ServerHelloDone'; Exit; end;
  TLS12AppendTranscript(LTranscript, LSHD);

  // 7. Read client Certificate (if mTLS) then ClientKeyExchange
  if not TLS12ReadRecord(AStream, LContentType, LData) then
  begin AError := 'Failed to read client message'; Exit; end;
  if (LContentType <> TLS12_CONTENT_HANDSHAKE) or (Length(LData) < 4) then
  begin AError := 'Invalid handshake record from client'; Exit; end;

  // If mTLS, first message should be Certificate
  if AConfig.RequestClientCert and (LData[0] = TLS12_HANDSHAKE_CERTIFICATE) then
  begin
    TLS12AppendTranscript(LTranscript, Copy(LData));
    LBodyLen := (Integer(LData[1]) shl 16) or (Integer(LData[2]) shl 8) or Integer(LData[3]);
    // Extract first client cert DER if present
    if LBodyLen > 6 then
    begin
      I := (Integer(LData[7]) shl 16) or (Integer(LData[8]) shl 8) or Integer(LData[9]);
      if 10 + I <= Length(LData) then
      begin
        SetLength(AState.ClientCertificateDER, I);
        Move(LData[10], AState.ClientCertificateDER[0], I);
      end;
    end;

    // Read next message (should be CKE)
    if not TLS12ReadRecord(AStream, LContentType, LData) then
    begin AError := 'Failed to read ClientKeyExchange'; Exit; end;
    if (LContentType <> TLS12_CONTENT_HANDSHAKE) or (Length(LData) < 5) then
    begin AError := 'Invalid ClientKeyExchange record'; Exit; end;
  end;

  if LData[0] <> TLS12_HANDSHAKE_CLIENT_KEY_EXCHANGE then
  begin AError := 'Expected ClientKeyExchange message'; Exit; end;

  LClientCKE := Copy(LData);
  TLS12AppendTranscript(LTranscript, LClientCKE);

  // Extract client public key
  LBodyLen := (Integer(LData[1]) shl 16) or (Integer(LData[2]) shl 8) or Integer(LData[3]);
  if 4 + LBodyLen > Length(LData) then
  begin AError := 'ClientKeyExchange truncated'; Exit; end;
  I := LData[4]; // public key length
  if 5 + I > Length(LData) then
  begin AError := 'ClientKeyExchange public key truncated'; Exit; end;
  SetLength(LClientPubKey, I);
  Move(LData[5], LClientPubKey[0], I);

  // Compute shared secret
  LSharedSecret := X25519ComputeSharedSecret(LPrivateKey, LClientPubKey);
  FillChar(LPrivateKey[0], 32, 0);
  if Length(LSharedSecret) = 0 then
  begin AError := 'Shared secret computation failed'; Exit; end;

  // Compute master secret
  if LUseSHA384 then
  begin
    if AState.HasEMS then
      AState.MasterSecret := TLS12ComputeMasterSecret_EMS_SHA384(LSharedSecret, SHA384(LTranscript))
    else
      AState.MasterSecret := TLS12ComputeMasterSecret_SHA384(LSharedSecret, AState.ClientRandom, AState.ServerRandom);
    LKeyBlock := TLS12DeriveKeyBlock_SHA384(AState.MasterSecret, AState.ServerRandom, AState.ClientRandom, LKeyLen, LIVLen);
  end
  else
  begin
    if AState.HasEMS then
      AState.MasterSecret := TLS12ComputeMasterSecret_EMS_SHA256(LSharedSecret, SHA256(LTranscript))
    else
      AState.MasterSecret := TLS12ComputeMasterSecret_SHA256(LSharedSecret, AState.ClientRandom, AState.ServerRandom);
    LKeyBlock := TLS12DeriveKeyBlock_SHA256(AState.MasterSecret, AState.ServerRandom, AState.ClientRandom, LKeyLen, LIVLen);
  end;
  FillChar(LSharedSecret[0], Length(LSharedSecret), 0);

  AState.ClientWriteKey := LKeyBlock.ClientWriteKey;
  AState.ServerWriteKey := LKeyBlock.ServerWriteKey;
  AState.ClientWriteIV := LKeyBlock.ClientWriteIV;
  AState.ServerWriteIV := LKeyBlock.ServerWriteIV;

  // 8. Read CertificateVerify (if mTLS and client sent a certificate)
  if AConfig.RequestClientCert and (Length(AState.ClientCertificateDER) > 0) then
  begin
    if not TLS12ReadRecord(AStream, LContentType, LData) then
    begin AError := 'Failed to read client CertificateVerify'; Exit; end;
    if (LContentType <> TLS12_CONTENT_HANDSHAKE) or (Length(LData) < 8) then
    begin AError := 'Invalid CertificateVerify record'; Exit; end;
    if LData[0] <> TLS12_HANDSHAKE_CERTIFICATE_VERIFY then
    begin AError := 'Expected CertificateVerify message'; Exit; end;

    // Verify client signature over transcript hash
    LBodyLen := (Integer(LData[1]) shl 16) or (Integer(LData[2]) shl 8) or Integer(LData[3]);
    if 4 + LBodyLen > Length(LData) then
    begin AError := 'CertificateVerify truncated'; Exit; end;

    // Parse: sig_scheme(2) + sig_len(2) + signature
    I := (Integer(LData[4]) shl 8) or Integer(LData[5]); // signature scheme
    LCipherSuiteLen := (Integer(LData[6]) shl 8) or Integer(LData[7]); // sig length
    if 8 + LCipherSuiteLen > Length(LData) then
    begin AError := 'CertificateVerify signature truncated'; Exit; end;

    SetLength(LSKESignature, LCipherSuiteLen);
    Move(LData[8], LSKESignature[0], LCipherSuiteLen);

    // Compute transcript hash (everything before CertificateVerify)
    LSKESignedData := SHA256(LTranscript);

    // Verify based on scheme
    LClientCert := TX509Certificate.Create;
      try
        LClientCert.LoadFromDER(AState.ClientCertificateDER);
        case I of
          $0401: // rsa_pkcs1_sha256
            begin
              if not TryVerifyRSAPKCS1v15SignatureSHA256(
                LSKESignedData, LSKESignature,
                LClientCert.PublicKeyInfo.RSAModulus,
                LClientCert.PublicKeyInfo.RSAExponent, LDecError) then
              begin AError := 'Client CertificateVerify failed: ' + LDecError; Exit; end;
            end;
          $0403: // ecdsa_secp256r1_sha256
            begin
              if not TryECDSAVerifyP256SHA256(
                LSKESignedData,
                LClientCert.PublicKeyInfo.ECPoint,
                LSKESignature, LDecError) then
              begin AError := 'Client CertificateVerify failed (ECDSA): ' + LDecError; Exit; end;
            end;
        else
          AError := Format('Unsupported CertificateVerify scheme: 0x%s', [IntToHex(I, 4)]);
          Exit;
        end;
      finally
        LClientCert.Free;
      end;

    // Add to transcript after verification
    TLS12AppendTranscript(LTranscript, Copy(LData, 0, 4 + LBodyLen));
  end;

  // 9. Read ChangeCipherSpec
  if not TLS12ReadRecord(AStream, LContentType, LData) then
  begin AError := 'Failed to read client ChangeCipherSpec'; Exit; end;
  if LContentType <> TLS12_CONTENT_CHANGE_CIPHER_SPEC then
  begin AError := 'Expected ChangeCipherSpec from client'; Exit; end;

  // 9. Read encrypted client Finished
  if not TLS12ReadRecord(AStream, LContentType, LData) then
  begin AError := 'Failed to read client Finished'; Exit; end;

  case LSuiteInfo.RecordMode of
    rmChaCha20Poly1305:
      begin
        if not TLS12ChaCha20Poly1305DecryptRecord(AState.ClientWriteKey, AState.ClientWriteIV,
          AState.ClientSeqNum, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
        begin AError := 'Client Finished decryption failed: ' + LDecError; Exit; end;
      end;
    rmCBC:
      begin
        if LSuiteInfo.PRFHash = phSHA384 then
        begin
          if not TLS12CBCDecrypt_SHA384(AState.ClientWriteKey, LKeyBlock.ClientWriteMACKey,
            AState.ClientSeqNum, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
          begin AError := 'Client Finished decryption failed: ' + LDecError; Exit; end;
        end
        else
        begin
          if not TLS12CBCDecrypt_SHA256(AState.ClientWriteKey, LKeyBlock.ClientWriteMACKey,
            AState.ClientSeqNum, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
          begin AError := 'Client Finished decryption failed: ' + LDecError; Exit; end;
        end;
      end;
  else // rmGCM
    if not TLS12GCMDecryptRecord(AState.ClientWriteKey, AState.ClientWriteIV,
      AState.ClientSeqNum, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
    begin AError := 'Client Finished decryption failed: ' + LDecError; Exit; end;
  end;
  Inc(AState.ClientSeqNum);

  // Verify client Finished
  if LUseSHA384 then
    LExpectedFinished := TLS12ComputeFinished_SHA384(AState.MasterSecret, SHA384(LTranscript), True)
  else
    LExpectedFinished := TLS12ComputeFinished_SHA256(AState.MasterSecret, SHA256(LTranscript), True);

  if (Length(LDecFinished) < 16) or (TConstantTime.CompareBuffer(@LDecFinished[4], @LExpectedFinished[0], 12) <> 1) then
  begin
    AError := 'Client Finished verify_data mismatch';
    Exit;
  end;

  // Add client Finished to transcript
  SetLength(LClientFinished, 16);
  Move(LDecFinished[0], LClientFinished[0], 16);
  TLS12AppendTranscript(LTranscript, LClientFinished);

  // 10. Send ChangeCipherSpec
  SetLength(LChangeCipherSpec, 1);
  LChangeCipherSpec[0] := 1;
  if not TLS12SendRecord(AStream, TLS12_CONTENT_CHANGE_CIPHER_SPEC, LChangeCipherSpec) then
  begin AError := 'Failed to send ChangeCipherSpec'; Exit; end;

  // 11. Send encrypted server Finished
  if LUseSHA384 then
    LExpectedFinished := TLS12ComputeFinished_SHA384(AState.MasterSecret, SHA384(LTranscript), False)
  else
    LExpectedFinished := TLS12ComputeFinished_SHA256(AState.MasterSecret, SHA256(LTranscript), False);

  SetLength(LFinished, 16);
  LFinished[0] := TLS12_HANDSHAKE_FINISHED;
  LFinished[1] := 0; LFinished[2] := 0; LFinished[3] := 12;
  Move(LExpectedFinished[0], LFinished[4], 12);

  case LSuiteInfo.RecordMode of
    rmChaCha20Poly1305:
      begin
        if not TLS12ChaCha20Poly1305EncryptRecord(AState.ServerWriteKey, AState.ServerWriteIV,
          AState.ServerSeqNum, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
        begin AError := 'Failed to encrypt server Finished: ' + LEncError; Exit; end;
      end;
    rmCBC:
      begin
        if LSuiteInfo.PRFHash = phSHA384 then
        begin
          if not TLS12CBCEncrypt_SHA384(AState.ServerWriteKey, LKeyBlock.ServerWriteMACKey,
            AState.ServerSeqNum, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
          begin AError := 'Failed to encrypt server Finished: ' + LEncError; Exit; end;
        end
        else
        begin
          if not TLS12CBCEncrypt_SHA256(AState.ServerWriteKey, LKeyBlock.ServerWriteMACKey,
            AState.ServerSeqNum, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
          begin AError := 'Failed to encrypt server Finished: ' + LEncError; Exit; end;
        end;
      end;
  else // rmGCM
    if not TLS12GCMEncryptRecord(AState.ServerWriteKey, AState.ServerWriteIV,
      AState.ServerSeqNum, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
    begin AError := 'Failed to encrypt server Finished: ' + LEncError; Exit; end;
  end;
  Inc(AState.ServerSeqNum);

  if not TLS12SendRecord(AStream, TLS12_CONTENT_HANDSHAKE, LEncFinished) then
  begin AError := 'Failed to send server Finished'; Exit; end;

  AState.ProtocolVersion := sslProtocolTLS12;
  SecureZeroBytes(LEffectiveKeyDER);
  Result := True;
end;

end.
