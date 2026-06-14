{**
 * Unit: nextpas.core.tls.tls13.clienthello.parser
 * Purpose: TLS 1.3 ClientHello 解析器（纯 Pascal）
 *
 * 说明：
 * - 只解析单个 Handshake message（含 4 字节握手头）
 * - 当前聚焦 TLS 1.3 协商关键字段：versions / cipher_suites / key_share / signature_algorithms
 * - key_share 优先选择 X25519；若无 X25519 则保留首个条目用于上层报错
 *}

unit nextpas.core.tls.tls13.clienthello.parser;

{$mode ObjFPC}{$H+}

interface

uses SysUtils, nextpas.core.base, nextpas.core.tls.tls13.wire;

type
  TTLS13WordArray = array of Word;
  TTLS13ALPNProtocolArray = array of AnsiString;

  TTLS13ClientHelloInfo = record
    Valid: Boolean;
    LegacyVersion: Word;
    Random: TBytes;
    LegacySessionID: TBytes;
    CipherSuites: TTLS13WordArray;
    SupportedVersions: TTLS13WordArray;
    SignatureAlgorithms: TTLS13WordArray;
    ALPNProtocols: TTLS13ALPNProtocolArray;
    HasSupportedVersions: Boolean;
    HasSignatureAlgorithms: Boolean;
    HasKeyShare: Boolean;
    HasEarlyData: Boolean;
    HasRecordSizeLimit: Boolean;
    RecordSizeLimit: Word;
    KeyShareGroup: Word;
    KeyShareLength: Word;
    PeerKeyShare: TBytes;
    HasPreSharedKey: Boolean;
    PSKIdentityCount: Integer;
    FirstPSKIdentity: TBytes;
    FirstPSKObfuscatedTicketAge: Cardinal;
    FirstPSKBinder: TBytes;
  end;

function TryParseTLS13ClientHelloFromHandshake(
  const AHandshake: TBytes;
  out AInfo: TTLS13ClientHelloInfo;
  out AError: string
): Boolean;
function TryBuildTLS13ClientHelloPSKBinderTranscript(
  const AHandshake: TBytes;
  out APartialHandshake: TBytes;
  out AError: string
): Boolean;

function TLS13ClientHelloSupportsVersion(const AInfo: TTLS13ClientHelloInfo; AVersion: Word): Boolean;
function TLS13ClientHelloOffersCipherSuite(const AInfo: TTLS13ClientHelloInfo; ACipherSuite: Word): Boolean;
function TLS13ClientHelloOffersSignatureScheme(const AInfo: TTLS13ClientHelloInfo; ASignatureScheme: Word): Boolean;
function TLS13ClientHelloOffersALPNProtocol(const AInfo: TTLS13ClientHelloInfo; const AALPNProtocol: string): Boolean;

implementation

procedure InitClientHelloInfo(out AInfo: TTLS13ClientHelloInfo);
begin
  FillChar(AInfo, SizeOf(AInfo), 0);
  SetLength(AInfo.Random, 0);
  SetLength(AInfo.LegacySessionID, 0);
  SetLength(AInfo.CipherSuites, 0);
  SetLength(AInfo.SupportedVersions, 0);
  SetLength(AInfo.SignatureAlgorithms, 0);
  SetLength(AInfo.ALPNProtocols, 0);
  SetLength(AInfo.PeerKeyShare, 0);
  SetLength(AInfo.FirstPSKIdentity, 0);
  SetLength(AInfo.FirstPSKBinder, 0);
  AInfo.RecordSizeLimit := TLS13_RECORD_SIZE_LIMIT_DEFAULT;
end;

function ReadUInt32BE(const AData: TBytes; AOffset: Integer): Cardinal;
begin
  if (AOffset < 0) or (AOffset + 3 >= Length(AData)) then
    raise Exception.Create('Invalid uint32 offset');

  Result :=
    (Cardinal(AData[AOffset]) shl 24) or
    (Cardinal(AData[AOffset + 1]) shl 16) or
    (Cardinal(AData[AOffset + 2]) shl 8) or
    Cardinal(AData[AOffset + 3]);
end;

function TLS13ClientHelloSupportsVersion(const AInfo: TTLS13ClientHelloInfo; AVersion: Word): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AInfo.SupportedVersions) do
    if AInfo.SupportedVersions[I] = AVersion then
      Exit(True);
  Result := False;
end;

function TLS13ClientHelloOffersCipherSuite(const AInfo: TTLS13ClientHelloInfo; ACipherSuite: Word): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AInfo.CipherSuites) do
    if AInfo.CipherSuites[I] = ACipherSuite then
      Exit(True);
  Result := False;
end;

function TLS13ClientHelloOffersSignatureScheme(const AInfo: TTLS13ClientHelloInfo; ASignatureScheme: Word): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AInfo.SignatureAlgorithms) do
    if AInfo.SignatureAlgorithms[I] = ASignatureScheme then
      Exit(True);
  Result := False;
end;

function TLS13ClientHelloOffersALPNProtocol(const AInfo: TTLS13ClientHelloInfo; const AALPNProtocol: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AInfo.ALPNProtocols) do
    if string(AInfo.ALPNProtocols[I]) = AALPNProtocol then
      Exit(True);

  Result := False;
end;

procedure ParseALPNProtocolsExtension(
  const AHandshake: TBytes;
  ADataOffset, ADataLength: Integer;
  var AInfo: TTLS13ClientHelloInfo;
  out AError: string
);
var
  LListLength: Integer;
  LOffset: Integer;
  LEndPos: Integer;
  LProtocolLength: Integer;
  LProtocolCount: Integer;
begin
  AError := '';

  if ADataLength < 2 then
  begin
    AError := 'ALPN extension is too short';
    Exit;
  end;

  if Length(AInfo.ALPNProtocols) > 0 then
  begin
    AError := 'ALPN extension must not appear more than once';
    Exit;
  end;

  LListLength := ReadUInt16(AHandshake, ADataOffset);
  if LListLength <> ADataLength - 2 then
  begin
    AError := 'ALPN protocol_name_list length mismatch';
    Exit;
  end;

  LOffset := ADataOffset + 2;
  LEndPos := LOffset + LListLength;
  LProtocolCount := 0;

  while LOffset < LEndPos do
  begin
    if LOffset + 1 > LEndPos then
    begin
      AError := 'ALPN protocol name is missing length';
      Exit;
    end;

    LProtocolLength := AHandshake[LOffset];
    Inc(LOffset);

    if LProtocolLength = 0 then
    begin
      AError := 'ALPN protocol name must not be empty';
      Exit;
    end;

    if LOffset + LProtocolLength > LEndPos then
    begin
      AError := 'ALPN protocol name exceeds extension boundary';
      Exit;
    end;

    SetLength(AInfo.ALPNProtocols, LProtocolCount + 1);
    SetLength(AInfo.ALPNProtocols[LProtocolCount], LProtocolLength);
    if LProtocolLength > 0 then
      Move(AHandshake[LOffset], AInfo.ALPNProtocols[LProtocolCount][1], LProtocolLength);
    Inc(LProtocolCount);
    Inc(LOffset, LProtocolLength);
  end;

  if LOffset <> LEndPos then
  begin
    AError := 'ALPN protocol_name_list has trailing bytes';
    Exit;
  end;

  if LProtocolCount = 0 then
  begin
    AError := 'ALPN protocol_name_list must not be empty';
    Exit;
  end;
end;

procedure ParseSupportedVersionsExtension(
  const AHandshake: TBytes;
  ADataOffset, ADataLength: Integer;
  var AInfo: TTLS13ClientHelloInfo;
  out AError: string
);
var
  LListLength: Integer;
  LOffset: Integer;
  LCount: Integer;
  I: Integer;
begin
  AError := '';

  if ADataLength < 1 then
  begin
    AError := 'supported_versions extension is too short';
    Exit;
  end;

  LListLength := AHandshake[ADataOffset];
  if LListLength + 1 <> ADataLength then
  begin
    AError := 'supported_versions length mismatch';
    Exit;
  end;

  if (LListLength and 1) <> 0 then
  begin
    AError := 'supported_versions vector length must be even';
    Exit;
  end;

  LCount := LListLength div 2;
  SetLength(AInfo.SupportedVersions, LCount);
  LOffset := ADataOffset + 1;
  for I := 0 to LCount - 1 do
  begin
    AInfo.SupportedVersions[I] := ReadUInt16(AHandshake, LOffset);
    Inc(LOffset, 2);
  end;

  AInfo.HasSupportedVersions := True;
end;

procedure ParseSignatureAlgorithmsExtension(
  const AHandshake: TBytes;
  ADataOffset, ADataLength: Integer;
  var AInfo: TTLS13ClientHelloInfo;
  out AError: string
);
var
  LListLength: Integer;
  LOffset: Integer;
  LCount: Integer;
  I: Integer;
begin
  AError := '';

  if ADataLength < 2 then
  begin
    AError := 'signature_algorithms extension is too short';
    Exit;
  end;

  LListLength := ReadUInt16(AHandshake, ADataOffset);
  if LListLength <> ADataLength - 2 then
  begin
    AError := 'signature_algorithms length mismatch';
    Exit;
  end;

  if (LListLength < 2) or ((LListLength and 1) <> 0) then
  begin
    AError := 'signature_algorithms vector length is invalid';
    Exit;
  end;

  LCount := LListLength div 2;
  SetLength(AInfo.SignatureAlgorithms, LCount);
  LOffset := ADataOffset + 2;
  for I := 0 to LCount - 1 do
  begin
    AInfo.SignatureAlgorithms[I] := ReadUInt16(AHandshake, LOffset);
    Inc(LOffset, 2);
  end;

  AInfo.HasSignatureAlgorithms := True;
end;

procedure ParseKeyShareExtension(
  const AHandshake: TBytes;
  ADataOffset, ADataLength: Integer;
  var AInfo: TTLS13ClientHelloInfo;
  out AError: string
);
var
  LClientSharesLength: Integer;
  LOffset: Integer;
  LEndPos: Integer;
  LGroup: Word;
  LKeyLen: Word;
  LFoundAny: Boolean;
  LFoundX25519: Boolean;
begin
  AError := '';

  if ADataLength < 2 then
  begin
    AError := 'key_share extension is too short';
    Exit;
  end;

  LClientSharesLength := ReadUInt16(AHandshake, ADataOffset);
  if LClientSharesLength <> ADataLength - 2 then
  begin
    AError := 'key_share client_shares length mismatch';
    Exit;
  end;

  LOffset := ADataOffset + 2;
  LEndPos := LOffset + LClientSharesLength;
  LFoundAny := False;
  LFoundX25519 := False;

  while LOffset + 4 <= LEndPos do
  begin
    LGroup := ReadUInt16(AHandshake, LOffset);
    LKeyLen := ReadUInt16(AHandshake, LOffset + 2);
    Inc(LOffset, 4);

    if LOffset + Integer(LKeyLen) > LEndPos then
    begin
      AError := 'key_share entry exceeds extension boundary';
      Exit;
    end;

    if not LFoundAny then
    begin
      AInfo.KeyShareGroup := LGroup;
      AInfo.KeyShareLength := LKeyLen;
      SetLength(AInfo.PeerKeyShare, Integer(LKeyLen));
      if LKeyLen > 0 then
        Move(AHandshake[LOffset], AInfo.PeerKeyShare[0], Integer(LKeyLen));
      LFoundAny := True;
    end;

    if (LGroup = TLS13_GROUP_X25519) and (not LFoundX25519) then
    begin
      AInfo.KeyShareGroup := LGroup;
      AInfo.KeyShareLength := LKeyLen;
      SetLength(AInfo.PeerKeyShare, Integer(LKeyLen));
      if LKeyLen > 0 then
        Move(AHandshake[LOffset], AInfo.PeerKeyShare[0], Integer(LKeyLen));
      LFoundX25519 := True;
    end;

    Inc(LOffset, Integer(LKeyLen));
  end;

  if LOffset <> LEndPos then
  begin
    AError := 'key_share extension has trailing bytes';
    Exit;
  end;

  AInfo.HasKeyShare := LFoundAny;
end;

procedure ParsePreSharedKeyExtension(
  const AHandshake: TBytes;
  ADataOffset, ADataLength: Integer;
  var AInfo: TTLS13ClientHelloInfo;
  out AError: string
);
var
  LOffset: Integer;
  LIdentitiesLen: Integer;
  LIdentitiesEnd: Integer;
  LIdentityLen: Integer;
  LBindersLen: Integer;
  LBindersEnd: Integer;
  LBinderLen: Integer;
  LIdentityCount: Integer;
  LBinderCount: Integer;
begin
  AError := '';
  if ADataLength < 4 then
  begin
    AError := 'pre_shared_key extension is too short';
    Exit;
  end;

  LOffset := ADataOffset;
  LIdentitiesLen := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2);
  LIdentitiesEnd := LOffset + LIdentitiesLen;
  if LIdentitiesEnd + 2 > ADataOffset + ADataLength then
  begin
    AError := 'pre_shared_key identities length exceeds extension';
    Exit;
  end;

  LIdentityCount := 0;
  while LOffset < LIdentitiesEnd do
  begin
    if LOffset + 2 > LIdentitiesEnd then
    begin
      AError := 'pre_shared_key identity is missing length';
      Exit;
    end;

    LIdentityLen := ReadUInt16(AHandshake, LOffset);
    Inc(LOffset, 2);
    if LOffset + LIdentityLen + 4 > LIdentitiesEnd then
    begin
      AError := 'pre_shared_key identity exceeds identities vector';
      Exit;
    end;

    if LIdentityCount = 0 then
    begin
      SetLength(AInfo.FirstPSKIdentity, LIdentityLen);
      if LIdentityLen > 0 then
        Move(AHandshake[LOffset], AInfo.FirstPSKIdentity[0], LIdentityLen);
      AInfo.FirstPSKObfuscatedTicketAge := ReadUInt32BE(AHandshake, LOffset + LIdentityLen);
    end;

    Inc(LOffset, LIdentityLen + 4);
    Inc(LIdentityCount);
  end;

  if LOffset <> LIdentitiesEnd then
  begin
    AError := 'pre_shared_key identities vector has trailing bytes';
    Exit;
  end;

  if LIdentityCount = 0 then
  begin
    AError := 'pre_shared_key identities vector must not be empty';
    Exit;
  end;

  LBindersLen := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2);
  LBindersEnd := LOffset + LBindersLen;
  if LBindersEnd <> ADataOffset + ADataLength then
  begin
    AError := 'pre_shared_key binders length mismatch';
    Exit;
  end;

  LBinderCount := 0;
  while LOffset < LBindersEnd do
  begin
    if LOffset + 1 > LBindersEnd then
    begin
      AError := 'pre_shared_key binder is missing length';
      Exit;
    end;

    LBinderLen := AHandshake[LOffset];
    Inc(LOffset);
    if LOffset + LBinderLen > LBindersEnd then
    begin
      AError := 'pre_shared_key binder exceeds binders vector';
      Exit;
    end;

    if LBinderCount = 0 then
    begin
      SetLength(AInfo.FirstPSKBinder, LBinderLen);
      if LBinderLen > 0 then
        Move(AHandshake[LOffset], AInfo.FirstPSKBinder[0], LBinderLen);
    end;

    Inc(LOffset, LBinderLen);
    Inc(LBinderCount);
  end;

  if LBinderCount = 0 then
  begin
    AError := 'pre_shared_key binders vector must not be empty';
    Exit;
  end;

  if LIdentityCount <> LBinderCount then
  begin
    AError := 'pre_shared_key identities/binders count mismatch';
    Exit;
  end;

  AInfo.HasPreSharedKey := LIdentityCount > 0;
  AInfo.PSKIdentityCount := LIdentityCount;
end;

procedure ParseEarlyDataExtension(
  ADataLength: Integer;
  var AInfo: TTLS13ClientHelloInfo;
  out AError: string
);
begin
  AError := '';
  if ADataLength <> 0 then
  begin
    AError := 'early_data extension must be empty in ClientHello';
    Exit;
  end;

  AInfo.HasEarlyData := True;
end;

procedure ParseRecordSizeLimitExtension(
  const AHandshake: TBytes;
  ADataOffset, ADataLength: Integer;
  var AInfo: TTLS13ClientHelloInfo;
  out AError: string
);
begin
  AError := '';

  if AInfo.HasRecordSizeLimit then
  begin
    AError := 'record_size_limit extension must not appear more than once';
    Exit;
  end;

  if ADataLength <> 2 then
  begin
    AError := 'record_size_limit extension must be 2 bytes';
    Exit;
  end;

  AInfo.RecordSizeLimit := ReadUInt16(AHandshake, ADataOffset);
  if AInfo.RecordSizeLimit < TLS13_RECORD_SIZE_LIMIT_MIN then
  begin
    AError := 'record_size_limit value is below RFC minimum';
    Exit;
  end;

  AInfo.HasRecordSizeLimit := True;
end;

function TryParseTLS13ClientHelloFromHandshake(
  const AHandshake: TBytes;
  out AInfo: TTLS13ClientHelloInfo;
  out AError: string
): Boolean;
var
  LOffset: Integer;
  LBodyLength: Cardinal;
  LBodyEnd: Integer;
  LSessionIdLen: Integer;
  LCipherSuitesLength: Integer;
  LCipherCount: Integer;
  LCompressionMethodsLength: Integer;
  LExtensionsLength: Integer;
  LExtensionsEnd: Integer;
  LExtType: Word;
  LExtLen: Word;
  LExtDataOffset: Integer;
  I: Integer;
  LExtError: string;
  LFoundPreSharedKeyExtension: Boolean;
begin
  InitClientHelloInfo(AInfo);
  AError := '';
  Result := False;
  LFoundPreSharedKeyExtension := False;

  if Length(AHandshake) < 4 then
  begin
    AError := 'Handshake message is too short';
    Exit;
  end;

  if AHandshake[0] <> TLS_HANDSHAKE_TYPE_CLIENT_HELLO then
  begin
    AError := 'Handshake message is not ClientHello';
    Exit;
  end;

  LBodyLength := ReadUInt24(AHandshake, 1);
  if LBodyLength > Cardinal(High(Integer) - 4) then
  begin
    AError := 'ClientHello length is too large';
    Exit;
  end;

  LBodyEnd := 4 + Integer(LBodyLength);
  if Length(AHandshake) <> LBodyEnd then
  begin
    AError := 'ClientHello body length mismatch';
    Exit;
  end;

  LOffset := 4;

  if LOffset + 2 > LBodyEnd then
  begin
    AError := 'Missing legacy_version';
    Exit;
  end;
  AInfo.LegacyVersion := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2);

  if LOffset + 32 > LBodyEnd then
  begin
    AError := 'Missing random bytes';
    Exit;
  end;
  SetLength(AInfo.Random, 32);
  Move(AHandshake[LOffset], AInfo.Random[0], 32);
  Inc(LOffset, 32);

  if LOffset + 1 > LBodyEnd then
  begin
    AError := 'Missing legacy_session_id length';
    Exit;
  end;
  LSessionIdLen := AHandshake[LOffset];
  Inc(LOffset);
  if LOffset + LSessionIdLen > LBodyEnd then
  begin
    AError := 'legacy_session_id exceeds ClientHello body';
    Exit;
  end;
  SetLength(AInfo.LegacySessionID, LSessionIdLen);
  if LSessionIdLen > 0 then
    Move(AHandshake[LOffset], AInfo.LegacySessionID[0], LSessionIdLen);
  Inc(LOffset, LSessionIdLen);

  if LOffset + 2 > LBodyEnd then
  begin
    AError := 'Missing cipher_suites length';
    Exit;
  end;
  LCipherSuitesLength := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2);
  if (LCipherSuitesLength < 2) or ((LCipherSuitesLength and 1) <> 0) then
  begin
    AError := 'cipher_suites length is invalid';
    Exit;
  end;
  if LOffset + LCipherSuitesLength > LBodyEnd then
  begin
    AError := 'cipher_suites exceeds ClientHello body';
    Exit;
  end;
  LCipherCount := LCipherSuitesLength div 2;
  SetLength(AInfo.CipherSuites, LCipherCount);
  for I := 0 to LCipherCount - 1 do
  begin
    AInfo.CipherSuites[I] := ReadUInt16(AHandshake, LOffset);
    Inc(LOffset, 2);
  end;

  if LOffset + 1 > LBodyEnd then
  begin
    AError := 'Missing legacy_compression_methods length';
    Exit;
  end;
  LCompressionMethodsLength := AHandshake[LOffset];
  Inc(LOffset);
  if LOffset + LCompressionMethodsLength > LBodyEnd then
  begin
    AError := 'legacy_compression_methods exceeds ClientHello body';
    Exit;
  end;
  Inc(LOffset, LCompressionMethodsLength);

  if LOffset + 2 > LBodyEnd then
  begin
    AError := 'Missing extensions length';
    Exit;
  end;
  LExtensionsLength := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2);
  LExtensionsEnd := LOffset + LExtensionsLength;
  if LExtensionsEnd <> LBodyEnd then
  begin
    AError := 'extensions length mismatch';
    Exit;
  end;

  while LOffset + 4 <= LExtensionsEnd do
  begin
    LExtType := ReadUInt16(AHandshake, LOffset);
    LExtLen := ReadUInt16(AHandshake, LOffset + 2);
    Inc(LOffset, 4);

    if LFoundPreSharedKeyExtension then
    begin
      AError := 'pre_shared_key must be the last ClientHello extension';
      Exit;
    end;

    if LOffset + Integer(LExtLen) > LExtensionsEnd then
    begin
      AError := 'Extension length exceeds extension block';
      Exit;
    end;

    LExtDataOffset := LOffset;

    case LExtType of
      TLS_EXTENSION_SUPPORTED_VERSIONS:
        begin
          ParseSupportedVersionsExtension(AHandshake, LExtDataOffset, LExtLen, AInfo, LExtError);
          if LExtError <> '' then
          begin
            AError := LExtError;
            Exit;
          end;
        end;

      TLS_EXTENSION_SIGNATURE_ALGORITHMS:
        begin
          ParseSignatureAlgorithmsExtension(AHandshake, LExtDataOffset, LExtLen, AInfo, LExtError);
          if LExtError <> '' then
          begin
            AError := LExtError;
            Exit;
          end;
        end;

      TLS_EXTENSION_ALPN:
        begin
          ParseALPNProtocolsExtension(AHandshake, LExtDataOffset, LExtLen, AInfo, LExtError);
          if LExtError <> '' then
          begin
            AError := LExtError;
            Exit;
          end;
        end;

      TLS_EXTENSION_KEY_SHARE:
        begin
          ParseKeyShareExtension(AHandshake, LExtDataOffset, LExtLen, AInfo, LExtError);
          if LExtError <> '' then
          begin
            AError := LExtError;
            Exit;
          end;
        end;

      TLS_EXTENSION_RECORD_SIZE_LIMIT:
        begin
          ParseRecordSizeLimitExtension(AHandshake, LExtDataOffset, LExtLen, AInfo, LExtError);
          if LExtError <> '' then
          begin
            AError := LExtError;
            Exit;
          end;
        end;

      TLS_EXTENSION_PRE_SHARED_KEY:
        begin
          ParsePreSharedKeyExtension(AHandshake, LExtDataOffset, LExtLen, AInfo, LExtError);
          if LExtError <> '' then
          begin
            AError := LExtError;
            Exit;
          end;
          LFoundPreSharedKeyExtension := True;
        end;

      TLS_EXTENSION_EARLY_DATA:
        begin
          ParseEarlyDataExtension(LExtLen, AInfo, LExtError);
          if LExtError <> '' then
          begin
            AError := LExtError;
            Exit;
          end;
        end;
    end;

    Inc(LOffset, Integer(LExtLen));
  end;

  if LOffset <> LExtensionsEnd then
  begin
    AError := 'Extension block has trailing bytes';
    Exit;
  end;

  if AInfo.HasEarlyData and (not AInfo.HasPreSharedKey) then
  begin
    AError := 'early_data requires pre_shared_key in ClientHello';
    Exit;
  end;

  AInfo.Valid := True;
  Result := True;
end;

function TryBuildTLS13ClientHelloPSKBinderTranscript(
  const AHandshake: TBytes;
  out APartialHandshake: TBytes;
  out AError: string
): Boolean;
var
  LOffset: Integer;
  LBodyLength: Cardinal;
  LBodyEnd: Integer;
  LSessionIdLen: Integer;
  LCipherSuitesLength: Integer;
  LCompressionMethodsLength: Integer;
  LExtensionsLength: Integer;
  LExtensionsEnd: Integer;
  LExtType: Word;
  LExtLen: Word;
  LExtDataOffset: Integer;
  LIdentitiesLen: Integer;
  LIdentitiesEnd: Integer;
  LBindersLen: Integer;
  LBindersEnd: Integer;
  LBinderOffset: Integer;
  LBinderLen: Integer;
  LFoundPSK: Boolean;
begin
  SetLength(APartialHandshake, 0);
  AError := '';
  Result := False;

  if Length(AHandshake) < 4 then
  begin
    AError := 'Handshake message is too short';
    Exit;
  end;

  if AHandshake[0] <> TLS_HANDSHAKE_TYPE_CLIENT_HELLO then
  begin
    AError := 'Handshake message is not ClientHello';
    Exit;
  end;

  LBodyLength := ReadUInt24(AHandshake, 1);
  if LBodyLength > Cardinal(High(Integer) - 4) then
  begin
    AError := 'ClientHello length is too large';
    Exit;
  end;

  LBodyEnd := 4 + Integer(LBodyLength);
  if Length(AHandshake) <> LBodyEnd then
  begin
    AError := 'ClientHello body length mismatch';
    Exit;
  end;

  LOffset := 4 + 2 + 32;
  if LOffset + 1 > LBodyEnd then
  begin
    AError := 'Missing legacy_session_id length';
    Exit;
  end;

  LSessionIdLen := AHandshake[LOffset];
  Inc(LOffset);
  if LOffset + LSessionIdLen > LBodyEnd then
  begin
    AError := 'legacy_session_id exceeds ClientHello body';
    Exit;
  end;
  Inc(LOffset, LSessionIdLen);

  if LOffset + 2 > LBodyEnd then
  begin
    AError := 'Missing cipher_suites length';
    Exit;
  end;
  LCipherSuitesLength := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2);
  if (LCipherSuitesLength < 2) or ((LCipherSuitesLength and 1) <> 0) then
  begin
    AError := 'cipher_suites length is invalid';
    Exit;
  end;
  if LOffset + LCipherSuitesLength > LBodyEnd then
  begin
    AError := 'cipher_suites exceeds ClientHello body';
    Exit;
  end;
  Inc(LOffset, LCipherSuitesLength);

  if LOffset + 1 > LBodyEnd then
  begin
    AError := 'Missing legacy_compression_methods length';
    Exit;
  end;
  LCompressionMethodsLength := AHandshake[LOffset];
  Inc(LOffset);
  if LOffset + LCompressionMethodsLength > LBodyEnd then
  begin
    AError := 'legacy_compression_methods exceeds ClientHello body';
    Exit;
  end;
  Inc(LOffset, LCompressionMethodsLength);

  if LOffset + 2 > LBodyEnd then
  begin
    AError := 'Missing extensions length';
    Exit;
  end;
  LExtensionsLength := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2);
  LExtensionsEnd := LOffset + LExtensionsLength;
  if LExtensionsEnd <> LBodyEnd then
  begin
    AError := 'extensions length mismatch';
    Exit;
  end;

  APartialHandshake := Copy(AHandshake);
  LFoundPSK := False;
  while LOffset + 4 <= LExtensionsEnd do
  begin
    LExtType := ReadUInt16(AHandshake, LOffset);
    LExtLen := ReadUInt16(AHandshake, LOffset + 2);
    Inc(LOffset, 4);

    if LOffset + Integer(LExtLen) > LExtensionsEnd then
    begin
      AError := 'Extension length exceeds extension block';
      Exit;
    end;

    LExtDataOffset := LOffset;
    if LExtType = TLS_EXTENSION_PRE_SHARED_KEY then
    begin
      if LOffset + Integer(LExtLen) <> LExtensionsEnd then
      begin
        AError := 'pre_shared_key must be the last ClientHello extension';
        Exit;
      end;

      if LExtLen < 4 then
      begin
        AError := 'pre_shared_key extension is too short';
        Exit;
      end;

      LIdentitiesLen := ReadUInt16(AHandshake, LExtDataOffset);
      LIdentitiesEnd := LExtDataOffset + 2 + LIdentitiesLen;
      if LIdentitiesEnd + 2 > LExtDataOffset + Integer(LExtLen) then
      begin
        AError := 'pre_shared_key identities length exceeds extension';
        Exit;
      end;
      if LIdentitiesLen = 0 then
      begin
        AError := 'pre_shared_key identities vector must not be empty';
        Exit;
      end;

      LBinderOffset := LIdentitiesEnd;
      LBindersLen := ReadUInt16(AHandshake, LBinderOffset);
      Inc(LBinderOffset, 2);
      LBindersEnd := LBinderOffset + LBindersLen;
      if LBindersEnd <> LExtDataOffset + Integer(LExtLen) then
      begin
        AError := 'pre_shared_key binders length mismatch';
        Exit;
      end;
      if LBindersLen = 0 then
      begin
        AError := 'pre_shared_key binders vector must not be empty';
        Exit;
      end;
      { RFC 8446 Section 4.2.11.2: partial transcript includes up to and
        including the binders list length but not the binder entries }
      while LBinderOffset < LBindersEnd do
      begin
        if LBinderOffset + 1 > LBindersEnd then
        begin
          AError := 'pre_shared_key binder is missing length';
          Exit;
        end;

        LBinderLen := AHandshake[LBinderOffset];
        Inc(LBinderOffset);
        if LBinderOffset + LBinderLen > LBindersEnd then
        begin
          AError := 'pre_shared_key binder exceeds binders vector';
          Exit;
        end;

        Inc(LBinderOffset, LBinderLen);
      end;

      { Truncate to exclude binders (binders_length + binder entries).
        OpenSSL hashes up to but NOT including the 2-byte binders_length. }
      SetLength(APartialHandshake, LIdentitiesEnd);

      LFoundPSK := True;
      Break;
    end;

    Inc(LOffset, Integer(LExtLen));
  end;

  if not LFoundPSK then
  begin
    AError := 'ClientHello does not contain pre_shared_key';
    SetLength(APartialHandshake, 0);
    Exit;
  end;

  Result := True;
end;

end.
