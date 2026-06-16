unit nextpas.core.tls.tls12.client;

{$mode objfpc}{$H+}{$J-}

interface

uses
  nextpas.core.exception, nextpas.core.text.conv, nextpas.core.base,
  nextpas.core.base.utils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.tls12.ciphersuite,
  nextpas.core.tls.x509;

type
  TTLS12ClientState = record
    ClientRandom: TBytes;
    ServerRandom: TBytes;
    MasterSecret: TBytes;
    ClientWriteKey: TBytes;
    ServerWriteKey: TBytes;
    ClientWriteIV: TBytes;
    ServerWriteIV: TBytes;
    ClientWriteMACKey: TBytes;
    ServerWriteMACKey: TBytes;
    CipherSuite: Word;
    ServerName: string;
    SessionID: TBytes;
    SessionTicket: TBytes;
    PeerCertificate: TX509Certificate;
    PeerCertificatesDER: array of TBytes;
    HandshakeHash: TBytes;
    ProtocolVersion: TSSLProtocolVersion;
    ClientSeqNum: UInt64;
    ServerSeqNum: UInt64;
    HasEMS: Boolean;
    ALPNProtocol: string;
    Resumed: Boolean;
    SecureRenegotiationSupported: Boolean;
    ClientVerifyData: TBytes;
    ServerVerifyData: TBytes;
    ClientCertRequested: Boolean;
  end;

  TTLS12SessionCache = record
    SessionID: TBytes;
    MasterSecret: TBytes;
    CipherSuite: Word;
    ServerName: string;
  end;

function TryTLS12ClientHandshake(
  AStream: TStream;
  const AServerName: string;
  const AALPNProtocols: array of string;
  const ACipherSuites: TTLS12CipherSuiteList;
  out AState: TTLS12ClientState;
  out AError: string
): Boolean; overload;

function TryTLS12ClientHandshake(
  AStream: TStream;
  const AServerName: string;
  const AALPNProtocols: array of string;
  out AState: TTLS12ClientState;
  out AError: string
): Boolean; overload;

function TryTLS12ClientHandshakeFromFallback(
  AStream: TStream;
  const AClientHelloHandshake: TBytes;
  const AClientRandom: TBytes;
  const AServerName: string;
  out AState: TTLS12ClientState;
  out AError: string
): Boolean;

function TryTLS12ClientHandshakeWithResume(
  AStream: TStream;
  const AServerName: string;
  const AALPNProtocols: array of string;
  const ACachedSession: TTLS12SessionCache;
  out AState: TTLS12ClientState;
  out AError: string
): Boolean; overload;

function TryTLS12ClientHandshakeWithResume(
  AStream: TStream;
  const AServerName: string;
  const AALPNProtocols: array of string;
  const ACipherSuites: TTLS12CipherSuiteList;
  const ACachedSession: TTLS12SessionCache;
  out AState: TTLS12ClientState;
  out AError: string
): Boolean; overload;

implementation

uses
  nextpas.core.tls.tls12.wire,
  nextpas.core.tls.tls12.io,
  nextpas.core.tls.tls12.clienthello,
  nextpas.core.tls.tls12.parser,
  nextpas.core.tls.tls12.recordcrypto,
  nextpas.core.crypto.tls12record,
  nextpas.core.tls.tls12.chacha20record,
  nextpas.core.tls.tls12.handshakecrypto,
  nextpas.core.crypto.x25519,
  nextpas.core.tls.tls13.servercertverify,
  nextpas.core.crypto.ecdsa,
  nextpas.core.crypto.hash,
  nextpas.core.crypto.constant_time,
  nextpas.core.tls.random;

function TLS12ClientFullHandshakeAfterServerHello(
  AStream: TStream;
  var ATranscript: TBytes;
  var AState: TTLS12ClientState;
  const AServerName: string;
  out AError: string
): Boolean; forward;

function TryP256ECDHE(const APrivateKey, APeerPublicPoint: TBytes;
  out APublicKey, ASharedSecret: TBytes; out AError: string): Boolean;
var
  LMyPoint, LPeerPoint, LSharedPoint: TECPoint;
  LMyX, LMyY, LSharedX: TBytes;
begin
  Result := False;
  SetLength(APublicKey, 0);
  SetLength(ASharedSecret, 0);

  if not TryP256ScalarMultBase(APrivateKey, LMyPoint, AError) then
  begin
    AError := 'P-256 public key generation failed: ' + AError;
    Exit;
  end;

  // Encode our public key as uncompressed point (04 || X || Y) with
  // fixed-length coordinates (StripLeadingZeroBytes can shorten X/Y).
  if not TryToFixedLength32(LMyPoint.X, LMyX, AError) then Exit;
  if not TryToFixedLength32(LMyPoint.Y, LMyY, AError) then Exit;
  SetLength(APublicKey, 65);
  APublicKey[0] := $04;
  Move(LMyX[0], APublicKey[1], 32);
  Move(LMyY[0], APublicKey[33], 32);

  // Decode and validate peer's public point: reject off-curve / out-of-range
  // / infinity points before scalar mult (invalid-curve attack defense).
  if not TryParseP256PublicPoint(APeerPublicPoint, LPeerPoint, AError) then
  begin
    AError := 'P-256 peer public key rejected: ' + AError;
    Exit;
  end;

  if not TryP256ScalarMult(APrivateKey, LPeerPoint, LSharedPoint, AError) then
  begin
    AError := 'P-256 shared secret computation failed: ' + AError;
    Exit;
  end;

  if LSharedPoint.IsInfinity then
  begin
    AError := 'P-256 shared secret is point at infinity';
    Exit;
  end;

  // Shared secret is the X coordinate, normalized to fixed 32 bytes.
  if not TryToFixedLength32(LSharedPoint.X, LSharedX, AError) then Exit;
  ASharedSecret := LSharedX;
  Result := True;
end;

function AlertDescription(ACode: Byte): string;
begin
  case ACode of
    TLS12_ALERT_CLOSE_NOTIFY: Result := 'close_notify';
    TLS12_ALERT_UNEXPECTED_MESSAGE: Result := 'unexpected_message';
    TLS12_ALERT_BAD_RECORD_MAC: Result := 'bad_record_mac';
    TLS12_ALERT_HANDSHAKE_FAILURE: Result := 'handshake_failure';
    TLS12_ALERT_BAD_CERTIFICATE: Result := 'bad_certificate';
    TLS12_ALERT_CERTIFICATE_EXPIRED: Result := 'certificate_expired';
    TLS12_ALERT_CERTIFICATE_UNKNOWN: Result := 'certificate_unknown';
    TLS12_ALERT_ILLEGAL_PARAMETER: Result := 'illegal_parameter';
    TLS12_ALERT_UNKNOWN_CA: Result := 'unknown_ca';
    TLS12_ALERT_DECODE_ERROR: Result := 'decode_error';
    TLS12_ALERT_DECRYPT_ERROR: Result := 'decrypt_error';
    TLS12_ALERT_PROTOCOL_VERSION: Result := 'protocol_version';
    TLS12_ALERT_INTERNAL_ERROR: Result := 'internal_error';
  else
    Result := Format('unknown(%d)', [ACode]);
  end;
end;

function TLS12ClientFullHandshakeAfterServerHello(
  AStream: TStream;
  var ATranscript: TBytes;
  var AState: TTLS12ClientState;
  const AServerName: string;
  out AError: string
): Boolean;
var
  LCertBody, LSKEBody, LFullMsg: TBytes;
  LHandshakeType: Byte;
  LCertMsg: TTLS12CertificateMessage;
  LSKE: TTLS12ServerKeyExchange;
  LTranscriptReader: TTLS12HandshakeReader;
  LPrivateKey, LSharedSecret, LPreMasterSecret: TBytes;
  LPublicKey: TBytes;
  LClientKeyExchange, LChangeCipherSpec, LFinished: TBytes;
  LEmptyCert: TBytes;
  LEncFinished, LDecFinished: TBytes;
  LEncError, LDecError, LAlertDesc: string;
  LKeyBlock: TTLS12KeyBlock;
  LExpectedFinished, LServerFinished: TBytes;
  LContentType: Byte;
  LData: TBytes;
  LSKESignedData: TBytes;
  LSKEParamsLen: Integer;
  LUseSHA384: Boolean;
  LIsCBC: Boolean;
  LIsChaCha: Boolean;
  LSuiteInfo: TTLS12CipherSuiteInfo;
  LKeyLen: Integer;
  LIVLen: Integer;
  LMACKeyLen: Integer;
  LBodyLen: Integer;
  I: Integer;
begin
  AError := '';
  Result := False;
  AState.ServerName := AServerName;
  AState.Resumed := False;

  if not TLS12GetCipherSuiteInfo(AState.CipherSuite, LSuiteInfo) then
  begin
    AError := Format('Unsupported cipher suite: 0x%s', [IntToHex(AState.CipherSuite, 4)]);
    Exit;
  end;
  LUseSHA384 := LSuiteInfo.PRFHash = phSHA384;
  LIsCBC := LSuiteInfo.RecordMode = rmCBC;
  LIsChaCha := LSuiteInfo.RecordMode = rmChaCha20Poly1305;
  LKeyLen := LSuiteInfo.KeyLen;
  LIVLen := LSuiteInfo.IVLen;
  LMACKeyLen := LSuiteInfo.MACKeyLen;

  if not AState.HasEMS then
  begin
    AError := 'Server does not support Extended Master Secret (required)';
    Exit;
  end;

  LTranscriptReader := TTLS12HandshakeReader.Create(AStream);
  try
    if not LTranscriptReader.ReadMessage(LHandshakeType, LCertBody, LFullMsg, LAlertDesc) then
    begin
      if LAlertDesc <> '' then
        AError := 'Certificate: ' + LAlertDesc
      else
        AError := 'Failed to read Certificate';
      Exit;
    end;
    if LHandshakeType <> TLS12_HANDSHAKE_CERTIFICATE then
    begin
      AError := Format('Expected Certificate, got type %d', [LHandshakeType]);
      Exit;
    end;

    TLS12AppendTranscript(ATranscript, LFullMsg);

    if not TryParseTLS12Certificate(LCertBody, 0, LCertMsg, AError) then
      Exit;

    if Length(LCertMsg.Certificates) = 0 then
    begin
      AError := 'Server sent empty certificate chain';
      Exit;
    end;

    AState.PeerCertificatesDER := LCertMsg.Certificates;
    AState.PeerCertificate := TX509Certificate.Create;
    AState.PeerCertificate.LoadFromDER(LCertMsg.Certificates[0]);

    if not LTranscriptReader.ReadMessage(LHandshakeType, LSKEBody, LFullMsg, LAlertDesc) then
    begin
      if LAlertDesc <> '' then
        AError := 'ServerKeyExchange: ' + LAlertDesc
      else
        AError := 'Failed to read ServerKeyExchange';
      Exit;
    end;
    if LHandshakeType <> TLS12_HANDSHAKE_SERVER_KEY_EXCHANGE then
    begin
      AError := Format('Expected ServerKeyExchange, got type %d', [LHandshakeType]);
      Exit;
    end;

    TLS12AppendTranscript(ATranscript, LFullMsg);

    if not TryParseTLS12ServerKeyExchange(LSKEBody, 0, LSKE, AError) then
      Exit;

    if (LSKE.NamedCurve <> TLS12_GROUP_X25519) and (LSKE.NamedCurve <> TLS12_GROUP_SECP256R1) then
    begin
      AError := Format('Unsupported named curve: %d', [LSKE.NamedCurve]);
      Exit;
    end;

    LSKEParamsLen := 1 + 2 + 1 + Length(LSKE.PublicKey);
    SetLength(LSKESignedData, 64 + LSKEParamsLen);
    Move(AState.ClientRandom[0], LSKESignedData[0], 32);
    Move(AState.ServerRandom[0], LSKESignedData[32], 32);
    LSKESignedData[64] := LSKE.CurveType;
    LSKESignedData[65] := Byte(LSKE.NamedCurve shr 8);
    LSKESignedData[66] := Byte(LSKE.NamedCurve);
    LSKESignedData[67] := Byte(Length(LSKE.PublicKey));
    Move(LSKE.PublicKey[0], LSKESignedData[68], Length(LSKE.PublicKey));

    case LSKE.SignatureScheme of
      $0401:
        begin
          if not TryVerifyRSAPKCS1v15SignatureSHA256(
            LSKESignedData, LSKE.Signature,
            AState.PeerCertificate.PublicKeyInfo.RSAModulus,
            AState.PeerCertificate.PublicKeyInfo.RSAExponent, AError) then
          begin
            AError := 'SKE signature verification failed (SHA256): ' + AError;
            Exit;
          end;
        end;
      $0501:
        begin
          if not TryVerifyRSAPKCS1v15SignatureSHA384(
            LSKESignedData, LSKE.Signature,
            AState.PeerCertificate.PublicKeyInfo.RSAModulus,
            AState.PeerCertificate.PublicKeyInfo.RSAExponent, AError) then
          begin
            AError := 'SKE signature verification failed (SHA384): ' + AError;
            Exit;
          end;
        end;
      $0403:
        begin
          if not TryECDSAVerifyP256SHA256(
            SHA256(LSKESignedData),
            AState.PeerCertificate.PublicKeyInfo.ECPoint,
            LSKE.Signature, AError) then
          begin
            AError := 'SKE signature verification failed (ECDSA-P256): ' + AError;
            Exit;
          end;
        end;
    else
      AError := Format('Unsupported SKE signature scheme: 0x%s', [IntToHex(LSKE.SignatureScheme, 4)]);
      Exit;
    end;

    if not LTranscriptReader.ReadMessage(LHandshakeType, LData, LFullMsg, LAlertDesc) then
    begin
      if LAlertDesc <> '' then
        AError := 'After SKE: ' + LAlertDesc
      else
        AError := 'Failed to read message after ServerKeyExchange';
      Exit;
    end;

    if LHandshakeType = TLS12_HANDSHAKE_CERTIFICATE_REQUEST then
    begin
      TLS12AppendTranscript(ATranscript, LFullMsg);
      AState.ClientCertRequested := True;
      if not LTranscriptReader.ReadMessage(LHandshakeType, LData, LFullMsg, LAlertDesc) then
      begin
        AError := 'Failed to read ServerHelloDone after CertificateRequest';
        Exit;
      end;
    end;

    if LHandshakeType <> TLS12_HANDSHAKE_SERVER_HELLO_DONE then
    begin
      AError := Format('Expected ServerHelloDone, got type %d', [LHandshakeType]);
      Exit;
    end;

    TLS12AppendTranscript(ATranscript, LFullMsg);

    if AState.ClientCertRequested then
    begin
      SetLength(LEmptyCert, 7);
      LEmptyCert[0] := TLS12_HANDSHAKE_CERTIFICATE;
      LEmptyCert[1] := 0; LEmptyCert[2] := 0; LEmptyCert[3] := 3;
      LEmptyCert[4] := 0; LEmptyCert[5] := 0; LEmptyCert[6] := 0;
      TLS12AppendTranscript(ATranscript, LEmptyCert);
    end;

    SetLength(LPrivateKey, 32);
    SecureRandomBytes(@LPrivateKey[0], 32);

    if LSKE.NamedCurve = TLS12_GROUP_X25519 then
    begin
      try
        LPublicKey := X25519PublicKeyFromPrivate(LPrivateKey);
        LSharedSecret := X25519ComputeSharedSecret(LPrivateKey, LSKE.PublicKey);
      except
        on E: Exception do
        begin
          AError := 'X25519 key exchange failed: ' + E.Message;
          if Length(LPrivateKey) > 0 then
            FillChar(LPrivateKey[0], Length(LPrivateKey), 0);
          Exit;
        end;
      end;
    end
    else
    begin
      if not TryP256ECDHE(LPrivateKey, LSKE.PublicKey, LPublicKey, LSharedSecret, AError) then
      begin
        if Length(LPrivateKey) > 0 then
          FillChar(LPrivateKey[0], Length(LPrivateKey), 0);
        Exit;
      end;
    end;
    if Length(LPrivateKey) > 0 then
      FillChar(LPrivateKey[0], Length(LPrivateKey), 0);

    if Length(LSharedSecret) = 0 then
    begin
      AError := 'ECDHE shared secret computation failed';
      Exit;
    end;

    LPreMasterSecret := LSharedSecret;

    SetLength(LClientKeyExchange, 4 + 1 + Length(LPublicKey));
    LClientKeyExchange[0] := TLS12_HANDSHAKE_CLIENT_KEY_EXCHANGE;
    LClientKeyExchange[1] := 0;
    LClientKeyExchange[2] := 0;
    LClientKeyExchange[3] := Byte(1 + Length(LPublicKey));
    LClientKeyExchange[4] := Byte(Length(LPublicKey));
    Move(LPublicKey[0], LClientKeyExchange[5], Length(LPublicKey));

    TLS12AppendTranscript(ATranscript, LClientKeyExchange);

    if LUseSHA384 then
    begin
      AState.HandshakeHash := SHA384(ATranscript);
      AState.MasterSecret := TLS12ComputeMasterSecret_EMS_SHA384(LPreMasterSecret, AState.HandshakeHash);
      LKeyBlock := TLS12DeriveKeyBlockFull_SHA384(
        AState.MasterSecret, AState.ServerRandom, AState.ClientRandom, LMACKeyLen, LKeyLen, LIVLen);
    end
    else
    begin
      AState.HandshakeHash := SHA256(ATranscript);
      AState.MasterSecret := TLS12ComputeMasterSecret_EMS_SHA256(LPreMasterSecret, AState.HandshakeHash);
      LKeyBlock := TLS12DeriveKeyBlockFull_SHA256(
        AState.MasterSecret, AState.ServerRandom, AState.ClientRandom, LMACKeyLen, LKeyLen, LIVLen);
    end;
    AState.ClientWriteKey := LKeyBlock.ClientWriteKey;
    AState.ServerWriteKey := LKeyBlock.ServerWriteKey;
    AState.ClientWriteIV := LKeyBlock.ClientWriteIV;
    AState.ServerWriteIV := LKeyBlock.ServerWriteIV;
    AState.ClientWriteMACKey := LKeyBlock.ClientWriteMACKey;
    AState.ServerWriteMACKey := LKeyBlock.ServerWriteMACKey;
    if Length(LPreMasterSecret) > 0 then
      FillChar(LPreMasterSecret[0], Length(LPreMasterSecret), 0);

    if AState.ClientCertRequested then
    begin
      if not TLS12SendRecord(AStream, TLS12_CONTENT_HANDSHAKE, LEmptyCert) then
      begin
        AError := 'Failed to send empty Certificate';
        Exit;
      end;
    end;

    if not TLS12SendRecord(AStream, TLS12_CONTENT_HANDSHAKE, LClientKeyExchange) then
    begin
      AError := 'Failed to send ClientKeyExchange';
      Exit;
    end;

    SetLength(LChangeCipherSpec, 1);
    LChangeCipherSpec[0] := 1;
    if not TLS12SendRecord(AStream, TLS12_CONTENT_CHANGE_CIPHER_SPEC, LChangeCipherSpec) then
    begin
      AError := 'Failed to send ChangeCipherSpec';
      Exit;
    end;

    if LUseSHA384 then
    begin
      AState.HandshakeHash := SHA384(ATranscript);
      LExpectedFinished := TLS12ComputeFinished_SHA384(AState.MasterSecret, AState.HandshakeHash, True);
    end
    else
    begin
      AState.HandshakeHash := SHA256(ATranscript);
      LExpectedFinished := TLS12ComputeFinished_SHA256(AState.MasterSecret, AState.HandshakeHash, True);
    end;
    AState.ClientVerifyData := Copy(LExpectedFinished);

    SetLength(LFinished, 4 + 12);
    LFinished[0] := TLS12_HANDSHAKE_FINISHED;
    LFinished[1] := 0;
    LFinished[2] := 0;
    LFinished[3] := 12;
    Move(LExpectedFinished[0], LFinished[4], 12);

    if LIsCBC then
    begin
      if LUseSHA384 then
      begin
        if not TLS12CBCEncrypt_SHA384(AState.ClientWriteKey, LKeyBlock.ClientWriteMACKey,
          AState.ClientSeqNum, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
        begin
          AError := 'Failed to encrypt Finished (CBC): ' + LEncError;
          Exit;
        end;
      end
      else
      begin
        if not TLS12CBCEncrypt_SHA256(AState.ClientWriteKey, LKeyBlock.ClientWriteMACKey,
          AState.ClientSeqNum, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
        begin
          AError := 'Failed to encrypt Finished (CBC): ' + LEncError;
          Exit;
        end;
      end;
    end
    else if LIsChaCha then
    begin
      if not TLS12ChaCha20Poly1305EncryptRecord(AState.ClientWriteKey, AState.ClientWriteIV,
        AState.ClientSeqNum, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
      begin
        AError := 'Failed to encrypt Finished (ChaCha20): ' + LEncError;
        Exit;
      end;
    end
    else
    begin
      if not TLS12GCMEncryptRecord(AState.ClientWriteKey, AState.ClientWriteIV,
        AState.ClientSeqNum, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
      begin
        AError := 'Failed to encrypt Finished: ' + LEncError;
        Exit;
      end;
    end;
    Inc(AState.ClientSeqNum);

    if not TLS12SendRecord(AStream, TLS12_CONTENT_HANDSHAKE, LEncFinished) then
    begin
      AError := 'Failed to send encrypted Finished';
      Exit;
    end;

    if not TLS12ReadRecord(AStream, LContentType, LData) then
    begin
      AError := 'Failed to read server response after client Finished';
      Exit;
    end;

    TLS12AppendTranscript(ATranscript, LFinished);

    if LContentType = TLS12_CONTENT_HANDSHAKE then
    begin
      if (Length(LData) >= 10) and (LData[0] = TLS12_HANDSHAKE_NEW_SESSION_TICKET) then
      begin
        LBodyLen := (Integer(LData[1]) shl 16) or (Integer(LData[2]) shl 8) or Integer(LData[3]);
        if 4 + LBodyLen <= Length(LData) then
        begin
          I := (Integer(LData[8]) shl 8) or Integer(LData[9]);
          if 10 + I <= Length(LData) then
          begin
            SetLength(AState.SessionTicket, I);
            Move(LData[10], AState.SessionTicket[0], I);
          end;
          TLS12AppendTranscript(ATranscript, Copy(LData, 0, 4 + LBodyLen));
        end;
      end;

      if not TLS12ReadRecord(AStream, LContentType, LData) then
      begin
        AError := 'Failed to read server ChangeCipherSpec';
        Exit;
      end;
    end;

    if LContentType <> TLS12_CONTENT_CHANGE_CIPHER_SPEC then
    begin
      AError := 'Expected ChangeCipherSpec from server';
      Exit;
    end;

    if not TLS12ReadRecord(AStream, LContentType, LData) then
    begin
      AError := 'Failed to read server Finished';
      Exit;
    end;

    if LIsCBC then
    begin
      if LUseSHA384 then
      begin
        if not TLS12CBCDecrypt_SHA384(AState.ServerWriteKey, LKeyBlock.ServerWriteMACKey,
          AState.ServerSeqNum, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
        begin
          AError := 'Server Finished decryption failed (CBC): ' + LDecError;
          Exit;
        end;
      end
      else
      begin
        if not TLS12CBCDecrypt_SHA256(AState.ServerWriteKey, LKeyBlock.ServerWriteMACKey,
          AState.ServerSeqNum, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
        begin
          AError := 'Server Finished decryption failed (CBC): ' + LDecError;
          Exit;
        end;
      end;
    end
    else if LIsChaCha then
    begin
      if not TLS12ChaCha20Poly1305DecryptRecord(AState.ServerWriteKey, AState.ServerWriteIV,
        AState.ServerSeqNum, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
      begin
        AError := 'Server Finished decryption failed (ChaCha20): ' + LDecError;
        Exit;
      end;
    end
    else
    begin
      if not TLS12GCMDecryptRecord(AState.ServerWriteKey, AState.ServerWriteIV,
        AState.ServerSeqNum, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
      begin
        AError := 'Server Finished decryption failed: ' + LDecError;
        Exit;
      end;
    end;
    Inc(AState.ServerSeqNum);

    if LUseSHA384 then
    begin
      AState.HandshakeHash := SHA384(ATranscript);
      LServerFinished := TLS12ComputeFinished_SHA384(AState.MasterSecret, AState.HandshakeHash, False);
    end
    else
    begin
      AState.HandshakeHash := SHA256(ATranscript);
      LServerFinished := TLS12ComputeFinished_SHA256(AState.MasterSecret, AState.HandshakeHash, False);
    end;

    if (Length(LDecFinished) < 16) or
      (TConstantTime.CompareBuffer(@LDecFinished[4], @LServerFinished[0], 12) <> 1) then
    begin
      AError := 'Server Finished verify_data mismatch';
      Exit;
    end;
    AState.ServerVerifyData := Copy(LServerFinished);

    AState.ProtocolVersion := sslProtocolTLS12;
    Result := True;
  finally
    LTranscriptReader.Free;
  end;
end;

function TryTLS12ClientHandshake(
  AStream: TStream;
  const AServerName: string;
  const AALPNProtocols: array of string;
  const ACipherSuites: TTLS12CipherSuiteList;
  out AState: TTLS12ClientState;
  out AError: string
): Boolean;
var
  LOptions: TTLS12ClientHelloOptions;
  LClientHello, LServerHelloBody: TBytes;
  LFullMsg: TBytes;
  LHandshakeType: Byte;
  LServerHello: TTLS12ServerHello;
  LTranscript: TBytes;
  LAlertDesc: string;
  LReader: TTLS12HandshakeReader;
  I: Integer;
begin
  AError := '';
  Result := False;
  FillChar(AState, SizeOf(AState), 0);

  SetLength(AState.ClientRandom, 32);
  SecureRandomBytes(@AState.ClientRandom[0], 32);

  LOptions.ServerName := AServerName;
  LOptions.SupportEMS := True;
  SetLength(LOptions.ALPNProtocols, Length(AALPNProtocols));
  for I := 0 to High(AALPNProtocols) do
    LOptions.ALPNProtocols[I] := AALPNProtocols[I];
  LOptions.CipherSuites := Copy(ACipherSuites, 0, Length(ACipherSuites));

  LClientHello := BuildTLS12ClientHello(LOptions, AState.ClientRandom);

  SetLength(LTranscript, 0);
  TLS12AppendTranscript(LTranscript, LClientHello);

  if not TLS12SendRecord(AStream, TLS12_CONTENT_HANDSHAKE, LClientHello) then
  begin
    AError := 'Failed to send ClientHello';
    Exit;
  end;

  LReader := TTLS12HandshakeReader.Create(AStream);
  try

  if not LReader.ReadMessage(LHandshakeType, LServerHelloBody, LFullMsg, LAlertDesc) then
  begin
    if LAlertDesc <> '' then
      AError := 'ServerHello: ' + LAlertDesc
    else
      AError := 'Failed to read ServerHello';
    Exit;
  end;
  if LHandshakeType <> TLS12_HANDSHAKE_SERVER_HELLO then
  begin
    AError := Format('Expected ServerHello, got type %d', [LHandshakeType]);
    Exit;
  end;

  if not TryParseTLS12ServerHello(LServerHelloBody, 0, LServerHello, AError) then
    Exit;

  AState.ServerRandom := LServerHello.ServerRandom;
  AState.CipherSuite := LServerHello.CipherSuite;
  AState.HasEMS := LServerHello.HasEMS;
  AState.ALPNProtocol := LServerHello.ALPNProtocol;
  AState.SessionID := LServerHello.SessionID;
  AState.ServerName := AServerName;
  AState.SecureRenegotiationSupported := LServerHello.HasRenegotiationInfo;

  if LServerHello.HasRenegotiationInfo and
    (Length(LServerHello.RenegotiatedConnection) <> 0) then
  begin
    AError := 'Initial ServerHello renegotiation_info must be empty';
    Exit;
  end;

  TLS12AppendTranscript(LTranscript, LFullMsg);
  FreeAndNil(LReader);
  Result := TLS12ClientFullHandshakeAfterServerHello(
    AStream,
    LTranscript,
    AState,
    AServerName,
    AError
  );
  finally
    LReader.Free;
  end;
end;

function TryTLS12ClientHandshake(
  AStream: TStream;
  const AServerName: string;
  const AALPNProtocols: array of string;
  out AState: TTLS12ClientState;
  out AError: string
): Boolean;
var
  LDefaultCipherSuites: TTLS12CipherSuiteList;
begin
  SetLength(LDefaultCipherSuites, 0);
  Result := TryTLS12ClientHandshake(
    AStream,
    AServerName,
    AALPNProtocols,
    LDefaultCipherSuites,
    AState,
    AError
  );
end;

function TryTLS12ClientHandshakeWithResume(
  AStream: TStream;
  const AServerName: string;
  const AALPNProtocols: array of string;
  const ACipherSuites: TTLS12CipherSuiteList;
  const ACachedSession: TTLS12SessionCache;
  out AState: TTLS12ClientState;
  out AError: string
): Boolean;
var
  LOptions: TTLS12ClientHelloOptions;
  LClientHello, LServerHelloBody, LFullMsg: TBytes;
  LHandshakeType: Byte;
  LServerHello: TTLS12ServerHello;
  LTranscript: TBytes;
  LUseSHA384: Boolean;
  LKeyLen: Integer;
  LKeyBlock: TTLS12KeyBlock;
  LExpectedFinished, LServerFinished: TBytes;
  LChangeCipherSpec, LFinished, LEncFinished, LDecFinished: TBytes;
  LEncError, LDecError, LAlertDesc: string;
  LContentType: Byte;
  LData: TBytes;
  LIsResume: Boolean;
  LReader: TTLS12HandshakeReader;
  LSuiteInfo: TTLS12CipherSuiteInfo;
  I: Integer;
begin
  AError := '';
  Result := False;
  FillChar(AState, SizeOf(AState), 0);

  // If no cached session, delegate to full handshake
  if Length(ACachedSession.SessionID) = 0 then
  begin
    Result := TryTLS12ClientHandshake(
      AStream,
      AServerName,
      AALPNProtocols,
      ACipherSuites,
      AState,
      AError
    );
    Exit;
  end;

  SetLength(AState.ClientRandom, 32);
  SecureRandomBytes(@AState.ClientRandom[0], 32);

  LOptions.ServerName := AServerName;
  LOptions.SupportEMS := True;
  LOptions.SessionID := ACachedSession.SessionID;
  SetLength(LOptions.ALPNProtocols, Length(AALPNProtocols));
  for I := 0 to High(AALPNProtocols) do
    LOptions.ALPNProtocols[I] := AALPNProtocols[I];
  LOptions.CipherSuites := Copy(ACipherSuites, 0, Length(ACipherSuites));

  LClientHello := BuildTLS12ClientHello(LOptions, AState.ClientRandom);
  SetLength(LTranscript, 0);
  TLS12AppendTranscript(LTranscript, LClientHello);

  if not TLS12SendRecord(AStream, TLS12_CONTENT_HANDSHAKE, LClientHello) then
  begin AError := 'Failed to send ClientHello'; Exit; end;

  LReader := TTLS12HandshakeReader.Create(AStream);
  try

  if not LReader.ReadMessage(LHandshakeType, LServerHelloBody, LFullMsg, LAlertDesc) then
  begin
    if LAlertDesc <> '' then AError := 'ServerHello: ' + LAlertDesc
    else AError := 'Failed to read ServerHello';
    Exit;
  end;
  if LHandshakeType <> TLS12_HANDSHAKE_SERVER_HELLO then
  begin AError := Format('Expected ServerHello, got type %d', [LHandshakeType]); Exit; end;

  if not TryParseTLS12ServerHello(LServerHelloBody, 0, LServerHello, AError) then Exit;

  AState.ServerRandom := LServerHello.ServerRandom;
  AState.CipherSuite := LServerHello.CipherSuite;
  AState.HasEMS := LServerHello.HasEMS;
  AState.ALPNProtocol := LServerHello.ALPNProtocol;
  AState.SessionID := LServerHello.SessionID;
  AState.ServerName := AServerName;
  AState.SecureRenegotiationSupported := LServerHello.HasRenegotiationInfo;

  if LServerHello.HasRenegotiationInfo and
    (Length(LServerHello.RenegotiatedConnection) <> 0) then
  begin
    AError := 'Initial ServerHello renegotiation_info must be empty';
    Exit;
  end;

  TLS12AppendTranscript(LTranscript, LFullMsg);

  // Check if server accepted resumption
  LIsResume := (Length(LServerHello.SessionID) > 0) and
    (Length(LServerHello.SessionID) = Length(ACachedSession.SessionID)) and
    CompareMem(@LServerHello.SessionID[0], @ACachedSession.SessionID[0], Length(ACachedSession.SessionID));

  if not LIsResume then
  begin
    AState.SessionID := LServerHello.SessionID;
    AState.Resumed := False;
    FreeAndNil(LReader);
    Result := TLS12ClientFullHandshakeAfterServerHello(
      AStream,
      LTranscript,
      AState,
      AServerName,
      AError
    );
    Exit;
  end;

  // Abbreviated handshake: derive keys from cached master secret
  AState.MasterSecret := ACachedSession.MasterSecret;

  if not TLS12GetCipherSuiteInfo(AState.CipherSuite, LSuiteInfo) then
  begin
    AError := Format('Unsupported cipher suite for resumption: 0x%s', [IntToHex(AState.CipherSuite, 4)]);
    Exit;
  end;
  LUseSHA384 := LSuiteInfo.PRFHash = phSHA384;
  LKeyLen := LSuiteInfo.KeyLen;

  if LUseSHA384 then
    LKeyBlock := TLS12DeriveKeyBlock_SHA384(AState.MasterSecret, AState.ServerRandom, AState.ClientRandom, LKeyLen, LSuiteInfo.IVLen)
  else
    LKeyBlock := TLS12DeriveKeyBlock_SHA256(AState.MasterSecret, AState.ServerRandom, AState.ClientRandom, LKeyLen, LSuiteInfo.IVLen);

  AState.ClientWriteKey := LKeyBlock.ClientWriteKey;
  AState.ServerWriteKey := LKeyBlock.ServerWriteKey;
  AState.ClientWriteIV := LKeyBlock.ClientWriteIV;
  AState.ServerWriteIV := LKeyBlock.ServerWriteIV;

  // Server sends CCS + Finished first in abbreviated handshake
  if not TLS12ReadRecord(AStream, LContentType, LData) then
  begin AError := 'Failed to read server ChangeCipherSpec'; Exit; end;
  if LContentType <> TLS12_CONTENT_CHANGE_CIPHER_SPEC then
  begin AError := 'Expected ChangeCipherSpec from server'; Exit; end;

  if not TLS12ReadRecord(AStream, LContentType, LData) then
  begin AError := 'Failed to read server Finished'; Exit; end;

  case LSuiteInfo.RecordMode of
    rmChaCha20Poly1305:
      if not TLS12ChaCha20Poly1305DecryptRecord(AState.ServerWriteKey, AState.ServerWriteIV,
        AState.ServerSeqNum, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
      begin AError := 'Server Finished decryption failed: ' + LDecError; Exit; end;
    rmCBC:
      if LUseSHA384 then
      begin
        if not TLS12CBCDecrypt_SHA384(AState.ServerWriteKey, LKeyBlock.ServerWriteMACKey,
          AState.ServerSeqNum, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
        begin AError := 'Server Finished decryption failed: ' + LDecError; Exit; end;
      end
      else
      begin
        if not TLS12CBCDecrypt_SHA256(AState.ServerWriteKey, LKeyBlock.ServerWriteMACKey,
          AState.ServerSeqNum, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
        begin AError := 'Server Finished decryption failed: ' + LDecError; Exit; end;
      end;
  else
    if not TLS12GCMDecryptRecord(AState.ServerWriteKey, AState.ServerWriteIV,
      AState.ServerSeqNum, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
    begin AError := 'Server Finished decryption failed: ' + LDecError; Exit; end;
  end;
  Inc(AState.ServerSeqNum);

  // Verify server Finished
  if LUseSHA384 then
    LServerFinished := TLS12ComputeFinished_SHA384(AState.MasterSecret, SHA384(LTranscript), False)
  else
    LServerFinished := TLS12ComputeFinished_SHA256(AState.MasterSecret, SHA256(LTranscript), False);

  if (Length(LDecFinished) < 16) or (TConstantTime.CompareBuffer(@LDecFinished[4], @LServerFinished[0], 12) <> 1) then
  begin AError := 'Server Finished verify_data mismatch (resumption)'; Exit; end;
  AState.ServerVerifyData := Copy(LServerFinished);

  // Add server Finished to transcript
  TLS12AppendTranscript(LTranscript, Copy(LDecFinished, 0, 16));

  // Client sends CCS + Finished
  SetLength(LChangeCipherSpec, 1);
  LChangeCipherSpec[0] := 1;
  if not TLS12SendRecord(AStream, TLS12_CONTENT_CHANGE_CIPHER_SPEC, LChangeCipherSpec) then
  begin AError := 'Failed to send ChangeCipherSpec'; Exit; end;

  if LUseSHA384 then
    LExpectedFinished := TLS12ComputeFinished_SHA384(AState.MasterSecret, SHA384(LTranscript), True)
  else
    LExpectedFinished := TLS12ComputeFinished_SHA256(AState.MasterSecret, SHA256(LTranscript), True);
  AState.ClientVerifyData := Copy(LExpectedFinished);

  SetLength(LFinished, 16);
  LFinished[0] := TLS12_HANDSHAKE_FINISHED;
  LFinished[1] := 0; LFinished[2] := 0; LFinished[3] := 12;
  Move(LExpectedFinished[0], LFinished[4], 12);

  case LSuiteInfo.RecordMode of
    rmChaCha20Poly1305:
      if not TLS12ChaCha20Poly1305EncryptRecord(AState.ClientWriteKey, AState.ClientWriteIV,
        AState.ClientSeqNum, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
      begin AError := 'Failed to encrypt client Finished: ' + LEncError; Exit; end;
    rmCBC:
      if LUseSHA384 then
      begin
        if not TLS12CBCEncrypt_SHA384(AState.ClientWriteKey, LKeyBlock.ClientWriteMACKey,
          AState.ClientSeqNum, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
        begin AError := 'Failed to encrypt client Finished: ' + LEncError; Exit; end;
      end
      else
      begin
        if not TLS12CBCEncrypt_SHA256(AState.ClientWriteKey, LKeyBlock.ClientWriteMACKey,
          AState.ClientSeqNum, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
        begin AError := 'Failed to encrypt client Finished: ' + LEncError; Exit; end;
      end;
  else
    if not TLS12GCMEncryptRecord(AState.ClientWriteKey, AState.ClientWriteIV,
      AState.ClientSeqNum, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
    begin AError := 'Failed to encrypt client Finished: ' + LEncError; Exit; end;
  end;
  Inc(AState.ClientSeqNum);

  if not TLS12SendRecord(AStream, TLS12_CONTENT_HANDSHAKE, LEncFinished) then
  begin AError := 'Failed to send client Finished'; Exit; end;

  AState.ProtocolVersion := sslProtocolTLS12;
  AState.Resumed := True;
  Result := True;
  finally
    LReader.Free;
  end;
end;

function TryTLS12ClientHandshakeWithResume(
  AStream: TStream;
  const AServerName: string;
  const AALPNProtocols: array of string;
  const ACachedSession: TTLS12SessionCache;
  out AState: TTLS12ClientState;
  out AError: string
): Boolean;
var
  LDefaultCipherSuites: TTLS12CipherSuiteList;
begin
  SetLength(LDefaultCipherSuites, 0);
  Result := TryTLS12ClientHandshakeWithResume(
    AStream,
    AServerName,
    AALPNProtocols,
    LDefaultCipherSuites,
    ACachedSession,
    AState,
    AError
  );
end;

function TryTLS12ClientHandshakeFromFallback(
  AStream: TStream;
  const AClientHelloHandshake: TBytes;
  const AClientRandom: TBytes;
  const AServerName: string;
  out AState: TTLS12ClientState;
  out AError: string
): Boolean;
var
  LServerHelloBody, LCertBody, LSKEBody: TBytes;
  LFullMsg: TBytes;
  LHandshakeType: Byte;
  LServerHello: TTLS12ServerHello;
  LCertMsg: TTLS12CertificateMessage;
  LSKE: TTLS12ServerKeyExchange;
  LTranscript: TBytes;
  LPrivateKey, LSharedSecret, LPreMasterSecret: TBytes;
  LPublicKey: TBytes;
  LClientKeyExchange, LChangeCipherSpec, LFinished: TBytes;
  LEncFinished, LDecFinished: TBytes;
  LEncError, LDecError: string;
  LKeyBlock: TTLS12KeyBlock;
  LExpectedFinished, LServerFinished: TBytes;
  LContentType: Byte;
  LData: TBytes;
  LSKESignedData: TBytes;
  LSKEParamsLen: Integer;
  LUseSHA384: Boolean;
  LIsCBC: Boolean;
  LIsChaCha: Boolean;
  LSuiteInfo: TTLS12CipherSuiteInfo;
  LKeyLen, LIVLen, LMACKeyLen: Integer;
  LAlertDesc: string;
  LReader: TTLS12HandshakeReader;
begin
  AError := '';
  Result := False;
  FillChar(AState, SizeOf(AState), 0);

  if Length(AClientRandom) <> 32 then
  begin
    AError := 'ClientRandom must be 32 bytes';
    Exit;
  end;

  AState.ClientRandom := Copy(AClientRandom);
  AState.ServerName := AServerName;

  SetLength(LTranscript, 0);
  TLS12AppendTranscript(LTranscript, AClientHelloHandshake);

  LReader := TTLS12HandshakeReader.Create(AStream);
  try
    if not LReader.ReadMessage(LHandshakeType, LServerHelloBody, LFullMsg, LAlertDesc) then
    begin
      if LAlertDesc <> '' then
        AError := 'ServerHello: ' + LAlertDesc
      else
        AError := 'Failed to read ServerHello (fallback)';
      Exit;
    end;
    if LHandshakeType <> TLS12_HANDSHAKE_SERVER_HELLO then
    begin
      AError := Format('Expected ServerHello, got type %d', [LHandshakeType]);
      Exit;
    end;

    if not TryParseTLS12ServerHello(LServerHelloBody, 0, LServerHello, AError) then
      Exit;

    AState.ServerRandom := LServerHello.ServerRandom;
    AState.CipherSuite := LServerHello.CipherSuite;
    AState.HasEMS := LServerHello.HasEMS;
    AState.ALPNProtocol := LServerHello.ALPNProtocol;
    AState.SessionID := LServerHello.SessionID;
    AState.SecureRenegotiationSupported := LServerHello.HasRenegotiationInfo;

    if LServerHello.HasRenegotiationInfo and
      (Length(LServerHello.RenegotiatedConnection) <> 0) then
    begin
      AError := 'Initial ServerHello renegotiation_info must be empty';
      Exit;
    end;

    if not TLS12GetCipherSuiteInfo(AState.CipherSuite, LSuiteInfo) then
    begin
      AError := Format('Unsupported cipher suite: 0x%s', [IntToHex(AState.CipherSuite, 4)]);
      Exit;
    end;
    LUseSHA384 := LSuiteInfo.PRFHash = phSHA384;
    LIsCBC := LSuiteInfo.RecordMode = rmCBC;
    LIsChaCha := LSuiteInfo.RecordMode = rmChaCha20Poly1305;
    LKeyLen := LSuiteInfo.KeyLen;
    LIVLen := LSuiteInfo.IVLen;
    LMACKeyLen := LSuiteInfo.MACKeyLen;

    if not AState.HasEMS then
    begin
      AError := 'Server does not support Extended Master Secret (required for fallback)';
      Exit;
    end;

    TLS12AppendTranscript(LTranscript, LFullMsg);

    // Read Certificate
    if not LReader.ReadMessage(LHandshakeType, LCertBody, LFullMsg, LAlertDesc) then
    begin
      AError := 'Failed to read Certificate (fallback)';
      Exit;
    end;
    if LHandshakeType <> TLS12_HANDSHAKE_CERTIFICATE then
    begin
      AError := Format('Expected Certificate, got type %d', [LHandshakeType]);
      Exit;
    end;
    TLS12AppendTranscript(LTranscript, LFullMsg);

    if not TryParseTLS12Certificate(LCertBody, 0, LCertMsg, AError) then
      Exit;
    if Length(LCertMsg.Certificates) = 0 then
    begin
      AError := 'Server sent empty certificate chain';
      Exit;
    end;
    AState.PeerCertificatesDER := LCertMsg.Certificates;
    AState.PeerCertificate := TX509Certificate.Create;
    AState.PeerCertificate.LoadFromDER(LCertMsg.Certificates[0]);

    // Read ServerKeyExchange
    if not LReader.ReadMessage(LHandshakeType, LSKEBody, LFullMsg, LAlertDesc) then
    begin
      AError := 'Failed to read ServerKeyExchange (fallback)';
      Exit;
    end;
    if LHandshakeType <> TLS12_HANDSHAKE_SERVER_KEY_EXCHANGE then
    begin
      AError := Format('Expected ServerKeyExchange, got type %d', [LHandshakeType]);
      Exit;
    end;
    TLS12AppendTranscript(LTranscript, LFullMsg);

    if not TryParseTLS12ServerKeyExchange(LSKEBody, 0, LSKE, AError) then
      Exit;
    if (LSKE.NamedCurve <> TLS12_GROUP_X25519) and (LSKE.NamedCurve <> TLS12_GROUP_SECP256R1) then
    begin
      AError := Format('Unsupported named curve: %d', [LSKE.NamedCurve]);
      Exit;
    end;

    // Verify SKE signature
    LSKEParamsLen := 1 + 2 + 1 + Length(LSKE.PublicKey);
    SetLength(LSKESignedData, 64 + LSKEParamsLen);
    Move(AState.ClientRandom[0], LSKESignedData[0], 32);
    Move(AState.ServerRandom[0], LSKESignedData[32], 32);
    LSKESignedData[64] := LSKE.CurveType;
    LSKESignedData[65] := Byte(LSKE.NamedCurve shr 8);
    LSKESignedData[66] := Byte(LSKE.NamedCurve);
    LSKESignedData[67] := Byte(Length(LSKE.PublicKey));
    Move(LSKE.PublicKey[0], LSKESignedData[68], Length(LSKE.PublicKey));

    case LSKE.SignatureScheme of
      $0401:
        if not TryVerifyRSAPKCS1v15SignatureSHA256(LSKESignedData, LSKE.Signature,
          AState.PeerCertificate.PublicKeyInfo.RSAModulus,
          AState.PeerCertificate.PublicKeyInfo.RSAExponent, AError) then
        begin
          AError := 'SKE signature failed (SHA256): ' + AError;
          Exit;
        end;
      $0501:
        if not TryVerifyRSAPKCS1v15SignatureSHA384(LSKESignedData, LSKE.Signature,
          AState.PeerCertificate.PublicKeyInfo.RSAModulus,
          AState.PeerCertificate.PublicKeyInfo.RSAExponent, AError) then
        begin
          AError := 'SKE signature failed (SHA384): ' + AError;
          Exit;
        end;
      $0403:
        if not TryECDSAVerifyP256SHA256(SHA256(LSKESignedData),
          AState.PeerCertificate.PublicKeyInfo.ECPoint, LSKE.Signature, AError) then
        begin
          AError := 'SKE signature failed (ECDSA-P256): ' + AError;
          Exit;
        end;
      $0804, $0809:
        if not TryVerifyRSAPSSSignatureSHA256(LSKESignedData, LSKE.Signature,
          AState.PeerCertificate.PublicKeyInfo.RSAModulus,
          AState.PeerCertificate.PublicKeyInfo.RSAExponent, AError) then
        begin
          AError := 'SKE signature failed (RSA-PSS-SHA256): ' + AError;
          Exit;
        end;
      $0805, $080A:
        if not TryVerifyRSAPSSSignatureSHA384(LSKESignedData, LSKE.Signature,
          AState.PeerCertificate.PublicKeyInfo.RSAModulus,
          AState.PeerCertificate.PublicKeyInfo.RSAExponent, AError) then
        begin
          AError := 'SKE signature failed (RSA-PSS-SHA384): ' + AError;
          Exit;
        end;
    else
      AError := Format('Unsupported SKE signature scheme: 0x%s', [IntToHex(LSKE.SignatureScheme, 4)]);
      Exit;
    end;

    // Read ServerHelloDone
    if not LReader.ReadMessage(LHandshakeType, LData, LFullMsg, LAlertDesc) then
    begin
      AError := 'Failed to read ServerHelloDone (fallback)';
      Exit;
    end;
    if LHandshakeType <> TLS12_HANDSHAKE_SERVER_HELLO_DONE then
    begin
      AError := Format('Expected ServerHelloDone, got type %d', [LHandshakeType]);
      Exit;
    end;
    TLS12AppendTranscript(LTranscript, LFullMsg);

    // ECDHE key exchange
    SetLength(LPrivateKey, 32);
    SecureRandomBytes(@LPrivateKey[0], 32);
    if LSKE.NamedCurve = TLS12_GROUP_X25519 then
    begin
      try
        LPublicKey := X25519PublicKeyFromPrivate(LPrivateKey);
        LSharedSecret := X25519ComputeSharedSecret(LPrivateKey, LSKE.PublicKey);
      except
        on E: Exception do
        begin
          AError := 'X25519 key exchange failed: ' + E.Message;
          FillChar(LPrivateKey[0], 32, 0);
          Exit;
        end;
      end;
    end
    else
    begin
      if not TryP256ECDHE(LPrivateKey, LSKE.PublicKey, LPublicKey, LSharedSecret, AError) then
      begin
        FillChar(LPrivateKey[0], 32, 0);
        Exit;
      end;
    end;
    FillChar(LPrivateKey[0], 32, 0);
    LPreMasterSecret := LSharedSecret;

    // ClientKeyExchange
    SetLength(LClientKeyExchange, 4 + 1 + Length(LPublicKey));
    LClientKeyExchange[0] := TLS12_HANDSHAKE_CLIENT_KEY_EXCHANGE;
    LClientKeyExchange[1] := 0;
    LClientKeyExchange[2] := 0;
    LClientKeyExchange[3] := Byte(1 + Length(LPublicKey));
    LClientKeyExchange[4] := Byte(Length(LPublicKey));
    Move(LPublicKey[0], LClientKeyExchange[5], Length(LPublicKey));
    TLS12AppendTranscript(LTranscript, LClientKeyExchange);

    // Derive keys (EMS)
    if LUseSHA384 then
    begin
      AState.HandshakeHash := SHA384(LTranscript);
      AState.MasterSecret := TLS12ComputeMasterSecret_EMS_SHA384(LPreMasterSecret, AState.HandshakeHash);
      LKeyBlock := TLS12DeriveKeyBlockFull_SHA384(AState.MasterSecret, AState.ServerRandom, AState.ClientRandom, LMACKeyLen, LKeyLen, LIVLen);
    end
    else
    begin
      AState.HandshakeHash := SHA256(LTranscript);
      AState.MasterSecret := TLS12ComputeMasterSecret_EMS_SHA256(LPreMasterSecret, AState.HandshakeHash);
      LKeyBlock := TLS12DeriveKeyBlockFull_SHA256(AState.MasterSecret, AState.ServerRandom, AState.ClientRandom, LMACKeyLen, LKeyLen, LIVLen);
    end;
    AState.ClientWriteKey := LKeyBlock.ClientWriteKey;
    AState.ServerWriteKey := LKeyBlock.ServerWriteKey;
    AState.ClientWriteIV := LKeyBlock.ClientWriteIV;
    AState.ServerWriteIV := LKeyBlock.ServerWriteIV;
    AState.ClientWriteMACKey := LKeyBlock.ClientWriteMACKey;
    AState.ServerWriteMACKey := LKeyBlock.ServerWriteMACKey;
    if Length(LPreMasterSecret) > 0 then
      FillChar(LPreMasterSecret[0], Length(LPreMasterSecret), 0);

    // Send ClientKeyExchange + ChangeCipherSpec + Finished
    if not TLS12SendRecord(AStream, TLS12_CONTENT_HANDSHAKE, LClientKeyExchange) then
    begin
      AError := 'Failed to send ClientKeyExchange (fallback)';
      Exit;
    end;

    SetLength(LChangeCipherSpec, 1);
    LChangeCipherSpec[0] := 1;
    if not TLS12SendRecord(AStream, TLS12_CONTENT_CHANGE_CIPHER_SPEC, LChangeCipherSpec) then
    begin
      AError := 'Failed to send ChangeCipherSpec (fallback)';
      Exit;
    end;

    // Compute and send client Finished
    if LUseSHA384 then
      LExpectedFinished := TLS12ComputeFinished_SHA384(AState.MasterSecret, SHA384(LTranscript), True)
    else
      LExpectedFinished := TLS12ComputeFinished_SHA256(AState.MasterSecret, SHA256(LTranscript), True);
    AState.ClientVerifyData := Copy(LExpectedFinished);

    SetLength(LFinished, 4 + 12);
    LFinished[0] := TLS12_HANDSHAKE_FINISHED;
    LFinished[1] := 0; LFinished[2] := 0; LFinished[3] := 12;
    Move(LExpectedFinished[0], LFinished[4], 12);

    // Encrypt client Finished
    if LIsCBC then
    begin
      if LUseSHA384 then
      begin
        if not TLS12CBCEncrypt_SHA384(AState.ClientWriteKey, LKeyBlock.ClientWriteMACKey,
          AState.ClientSeqNum, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
        begin AError := 'Encrypt Finished failed (CBC-384): ' + LEncError; Exit; end;
      end
      else
      begin
        if not TLS12CBCEncrypt_SHA256(AState.ClientWriteKey, LKeyBlock.ClientWriteMACKey,
          AState.ClientSeqNum, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
        begin AError := 'Encrypt Finished failed (CBC-256): ' + LEncError; Exit; end;
      end;
    end
    else if LIsChaCha then
    begin
      if not TLS12ChaCha20Poly1305EncryptRecord(AState.ClientWriteKey, AState.ClientWriteIV,
        AState.ClientSeqNum, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
      begin AError := 'Encrypt Finished failed (ChaCha20): ' + LEncError; Exit; end;
    end
    else
    begin
      if not TLS12GCMEncryptRecord(AState.ClientWriteKey, AState.ClientWriteIV,
        AState.ClientSeqNum, TLS12_CONTENT_HANDSHAKE, LFinished, LEncFinished, LEncError) then
      begin AError := 'Encrypt Finished failed (GCM): ' + LEncError; Exit; end;
    end;
    Inc(AState.ClientSeqNum);

    if not TLS12SendRecord(AStream, TLS12_CONTENT_HANDSHAKE, LEncFinished) then
    begin
      AError := 'Failed to send encrypted Finished (fallback)';
      Exit;
    end;

    TLS12AppendTranscript(LTranscript, LFinished);

    // Read server response (may be NewSessionTicket or ChangeCipherSpec)
    if not TLS12ReadRecord(AStream, LContentType, LData) then
    begin
      AError := 'Failed to read server response after client Finished (fallback)';
      Exit;
    end;

    // Handle optional NewSessionTicket (RFC 5077)
    if LContentType = TLS12_CONTENT_HANDSHAKE then
    begin
      TLS12AppendTranscript(LTranscript, LData);
      if not TLS12ReadRecord(AStream, LContentType, LData) then
      begin
        AError := 'Failed to read server ChangeCipherSpec (fallback)';
        Exit;
      end;
    end;

    if LContentType <> TLS12_CONTENT_CHANGE_CIPHER_SPEC then
    begin
      AError := Format('Expected ChangeCipherSpec, got content type %d', [LContentType]);
      Exit;
    end;

    // Read server Finished
    if not TLS12ReadRecord(AStream, LContentType, LData) then
    begin
      AError := 'Failed to read server Finished (fallback)';
      Exit;
    end;

    // Decrypt server Finished
    if LIsCBC then
    begin
      if LUseSHA384 then
      begin
        if not TLS12CBCDecrypt_SHA384(AState.ServerWriteKey, LKeyBlock.ServerWriteMACKey,
          AState.ServerSeqNum, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
        begin AError := 'Decrypt server Finished failed (CBC-384): ' + LDecError; Exit; end;
      end
      else
      begin
        if not TLS12CBCDecrypt_SHA256(AState.ServerWriteKey, LKeyBlock.ServerWriteMACKey,
          AState.ServerSeqNum, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
        begin AError := 'Decrypt server Finished failed (CBC-256): ' + LDecError; Exit; end;
      end;
    end
    else if LIsChaCha then
    begin
      if not TLS12ChaCha20Poly1305DecryptRecord(AState.ServerWriteKey, AState.ServerWriteIV,
        AState.ServerSeqNum, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
      begin AError := 'Decrypt server Finished failed (ChaCha20): ' + LDecError; Exit; end;
    end
    else
    begin
      if not TLS12GCMDecryptRecord(AState.ServerWriteKey, AState.ServerWriteIV,
        AState.ServerSeqNum, TLS12_CONTENT_HANDSHAKE, LData, LDecFinished, LDecError) then
      begin AError := 'Decrypt server Finished failed (GCM): ' + LDecError; Exit; end;
    end;
    Inc(AState.ServerSeqNum);

    // Verify server Finished
    if LUseSHA384 then
      LExpectedFinished := TLS12ComputeFinished_SHA384(AState.MasterSecret, SHA384(LTranscript), False)
    else
      LExpectedFinished := TLS12ComputeFinished_SHA256(AState.MasterSecret, SHA256(LTranscript), False);

    if (Length(LDecFinished) < 16) or
      (TConstantTime.CompareBuffer(@LDecFinished[4], @LExpectedFinished[0], 12) <> 1) then
    begin
      AError := 'Server Finished verify_data mismatch (fallback)';
      Exit;
    end;
    AState.ServerVerifyData := Copy(LExpectedFinished);

    Result := True;
  finally
    LReader.Free;
  end;
end;

end.
