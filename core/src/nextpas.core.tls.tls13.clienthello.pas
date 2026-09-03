{**
 * Unit: nextpas.core.tls.tls13.clienthello
 * Purpose: TLS 1.3 ClientHello 构建器（纯 Pascal）
 *}

unit nextpas.core.tls.tls13.clienthello;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.text.conv,
  nextpas.core.base,
  
  nextpas.core.tls.base;

type
  TTLS13CipherSuiteList = array of Word;

  TTLS13ClientHelloPSKOffer = record
    Valid: Boolean;
    AllowEarlyData: Boolean;
    Identity: TBytes;
    ObfuscatedTicketAge: Cardinal;
    Binder: TBytes;
  end;

function BuildTLS13ClientHelloHandshake(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  AIncludeStatusRequest: Boolean = False;
  AIncludeSignedCertificateTimestamp: Boolean = False
): TBytes;

function BuildTLS13ClientHelloRecord(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  AIncludeStatusRequest: Boolean = False;
  AIncludeSignedCertificateTimestamp: Boolean = False
): TBytes;

function BuildTLS13ClientHelloHandshakeWithPSK(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  const APSKOffer: TTLS13ClientHelloPSKOffer;
  out APartialHandshake: TBytes;
  AIncludeStatusRequest: Boolean = False;
  AIncludeSignedCertificateTimestamp: Boolean = False
): TBytes;

function BuildTLS13ClientHelloHandshakeWithComputedPSKBinder(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  ACipherSuite: Word;
  const APSKIdentity: TBytes;
  AObfuscatedTicketAge: Cardinal;
  const AResumptionPSK: TBytes;
  out APartialHandshake: TBytes;
  AAllowEarlyData: Boolean = False;
  AIncludeStatusRequest: Boolean = False;
  AIncludeSignedCertificateTimestamp: Boolean = False
): TBytes;

function BuildTLS13ClientHelloRecordWithPSK(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  const APSKOffer: TTLS13ClientHelloPSKOffer;
  out APartialHandshake: TBytes;
  AIncludeStatusRequest: Boolean = False;
  AIncludeSignedCertificateTimestamp: Boolean = False
): TBytes;

function BuildTLS13ClientHelloHandshakeWithCiphers(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  const ACipherSuites: TTLS13CipherSuiteList;
  AIncludeStatusRequest: Boolean = False;
  AIncludeSignedCertificateTimestamp: Boolean = False;
    { QUIC-TLS（RFC 9001 §4.2）：QUIC 模式禁报 <TLS1.3 版本——Go 栈
      （crypto/tls quic.go）见 supported_versions 含旧版即发
      protocol_version alert 关连；经典 TLS 路径保持双版本缺省 }
  AQuic13Only: Boolean = False
): TBytes;

function BuildTLS13ClientHelloHandshakeWithComputedPSKBinderAndCiphers(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  ACipherSuite: Word;
  const APSKIdentity: TBytes;
  AObfuscatedTicketAge: Cardinal;
  const AResumptionPSK: TBytes;
  const ACipherSuites: TTLS13CipherSuiteList;
  out APartialHandshake: TBytes;
  AAllowEarlyData: Boolean = False;
  AIncludeStatusRequest: Boolean = False;
  AIncludeSignedCertificateTimestamp: Boolean = False
): TBytes;

function BuildExtensionRecordSizeLimit(ALimit: Word): TBytes;
function ParseTLS13CipherSuiteString(const ACipherSuiteStr: string): TTLS13CipherSuiteList;
function PatchClientHelloKeyShare(const AOriginalCH: TBytes; const ANewKeyShare: TBytes; ANewGroup: Word): TBytes;

implementation

uses
  nextpas.core.tls.errors,
  nextpas.core.tls.random,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.wire,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.builder;

type
  TALPNProtocolArray = array of AnsiString;

procedure AppendUInt32(var ADest: TBytes; AValue: Cardinal);
begin
  AppendByte(ADest, Byte((AValue shr 24) and $FF));
  AppendByte(ADest, Byte((AValue shr 16) and $FF));
  AppendByte(ADest, Byte((AValue shr 8) and $FF));
  AppendByte(ADest, Byte(AValue and $FF));
end;

procedure AppendDefaultTLS13CipherSuites(var ADest: TBytes);
begin
  // TLS 1.3 cipher suites
  AppendUInt16(ADest, TLS13_CIPHER_AES_256_GCM_SHA384);
  AppendUInt16(ADest, TLS13_CIPHER_CHACHA20_POLY1305_SHA256);
  AppendUInt16(ADest, TLS13_CIPHER_AES_128_GCM_SHA256);
  // TLS 1.2 cipher suites (for version fallback)
  AppendUInt16(ADest, $C02F); // ECDHE-RSA-AES128-GCM-SHA256
  AppendUInt16(ADest, $C030); // ECDHE-RSA-AES256-GCM-SHA384
  AppendUInt16(ADest, $CCA8); // ECDHE-RSA-CHACHA20-POLY1305
  AppendUInt16(ADest, $C02B); // ECDHE-ECDSA-AES128-GCM-SHA256
  AppendUInt16(ADest, $C02C); // ECDHE-ECDSA-AES256-GCM-SHA384
end;

procedure AppendTLS13CipherSuites(var ADest: TBytes; const ACipherSuites: TTLS13CipherSuiteList);
var
  I: Integer;
begin
  for I := 0 to High(ACipherSuites) do
    AppendUInt16(ADest, ACipherSuites[I]);
end;

function BytesFromAnsi(const AValue: AnsiString): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    nextpas.core.bytes.ops.BytesCopy(@Result[0], @AValue[1], SizeUInt(Length(AValue))); // perf: inline single Move via bytes.ops.BytesCopy single source (zero-copy, INV-5)
end;

function IsAsciiWhitespace(AChar: Char): Boolean;
begin
  Result := (AChar = ' ') or (AChar = #9) or (AChar = #10) or (AChar = #13);
end;

function ParseALPNList(const AALPNProtocols: string): TALPNProtocolArray;
var
  I: Integer;
  LStart, LStop: Integer;
  LValue: string;
  LCount: Integer;
  LCap: Integer;
begin
  Result := nil;
  LCount := 0;
  LCap := 0;
  LStart := 1;

  for I := 1 to Length(AALPNProtocols) + 1 do
  begin
    if (I <= Length(AALPNProtocols)) and (AALPNProtocols[I] <> ',') then
      Continue;

    LStop := I - 1;
    while (LStart <= LStop) and IsAsciiWhitespace(AALPNProtocols[LStart]) do
      Inc(LStart);
    while (LStop >= LStart) and IsAsciiWhitespace(AALPNProtocols[LStop]) do
      Dec(LStop);

    if LStop >= LStart then
    begin
      LValue := Copy(AALPNProtocols, LStart, LStop - LStart + 1);
      // perf: geometric via bytes.ops.BytesGrowCapacityInt single source amortized O(1) (BYTES_BUILDER_MIN_GROW 0→64→2×), zero-copy string assign; not inline per red-line 2; stability: SetLength exception-safe, final shrink releases slack
      if LCount >= LCap then
      begin
        LCap := nextpas.core.bytes.ops.BytesGrowCapacityInt(LCap, LCount + 1);
        SetLength(Result, LCap);
      end;
      Result[LCount] := AnsiString(LValue);
      Inc(LCount);
    end;

    LStart := I + 1;
  end;
  if LCount <> LCap then
    SetLength(Result, LCount);
end;

function BuildExtensionHeader(AType: Word; const AData: TBytes): TBytes;
var
  LBuilder: IBytesBuilder;
begin
  // perf: single alloc via IBytesBuilder geometric 0→64→2× (bytes.ops.capacity single source); zero-copy BytesCopy; inline AppendUInt16BE
  LBuilder := CreateBytesBuilder(4 + Length(AData));
  LBuilder.AppendUInt16BE(AType);
  LBuilder.AppendUInt16BE(Word(Length(AData)));
  if Length(AData) > 0 then
    LBuilder.AppendSpan(TByteSpan.FromBytes(AData));
  Result := LBuilder.ToBytes;
end;

function BuildExtensionServerName(const AServerName: string): TBytes;
var
  LHostBytes: TBytes;
  LBuilder: IBytesBuilder;
  LListData: TBytes;
begin
  if AServerName = '' then
  begin
    Result := nil;
    Exit;
  end;

  LHostBytes := BytesFromAnsi(AnsiString(AServerName));
  // perf: IBytesBuilder geometric single alloc, zero-copy BytesCopy, inline Append* (bytes.ops single source)
  LBuilder := CreateBytesBuilder(1 + 2 + Length(LHostBytes));
  LBuilder.AppendByte(0); // host_name
  LBuilder.AppendUInt16BE(Word(Length(LHostBytes)));
  if Length(LHostBytes) > 0 then
    LBuilder.AppendSpan(TByteSpan.FromBytes(LHostBytes));
  LListData := LBuilder.ToBytes;

  LBuilder := CreateBytesBuilder(2 + Length(LListData));
  LBuilder.AppendUInt16BE(Word(Length(LListData)));
  LBuilder.AppendSpan(TByteSpan.FromBytes(LListData));
  Result := BuildExtensionHeader(TLS_EXTENSION_SERVER_NAME, LBuilder.ToBytes);
end;

function BuildExtensionALPN(const AALPNProtocols: string): TBytes;
var
  LProtocols: TALPNProtocolArray;
  LProtoBytes: TBytes;
  I: Integer;
  LBuilder: IBytesBuilder;
  LListData: TBytes;
begin
  LProtocols := ParseALPNList(AALPNProtocols);
  if Length(LProtocols) = 0 then
  begin
    Result := nil;
    Exit;
  end;

  // perf: looped append MUST use IBytesBuilder geometric 0→64→2× single alloc (bytes.ops:50 O(n²) gate); zero-copy BytesCopy; inline AppendByte
  LBuilder := CreateBytesBuilder(64);
  for I := 0 to High(LProtocols) do
  begin
    LProtoBytes := BytesFromAnsi(LProtocols[I]);
    if Length(LProtoBytes) > 255 then
      RaiseInvalidParameter('ALPNProtocolLength');

    LBuilder.AppendByte(Byte(Length(LProtoBytes)));
    if Length(LProtoBytes) > 0 then
      LBuilder.AppendSpan(TByteSpan.FromBytes(LProtoBytes));
  end;
  LListData := LBuilder.ToBytes;

  LBuilder := CreateBytesBuilder(2 + Length(LListData));
  LBuilder.AppendUInt16BE(Word(Length(LListData)));
  LBuilder.AppendSpan(TByteSpan.FromBytes(LListData));
  Result := BuildExtensionHeader(TLS_EXTENSION_ALPN, LBuilder.ToBytes);
end;

function BuildExtensionSupportedVersions: TBytes;
var
  LData: TBytes;
begin
  SetLength(LData, 0);
  AppendByte(LData, 4); // 长度 = 4 (2 versions)
  AppendUInt16(LData, TLS13_VERSION);    // TLS 1.3
  AppendUInt16(LData, TLS_LEGACY_VERSION); // TLS 1.2
  Result := BuildExtensionHeader(TLS_EXTENSION_SUPPORTED_VERSIONS, LData);
end;

{ QUIC 模式：只报 TLS1.3（RFC 9001 §4.2——QUIC 握手报旧版本即违约，
  Go 栈实测见旧版直接 protocol_version alert 关连） }
function BuildExtensionSupportedVersionsQuic: TBytes;
var
  LData: TBytes;
begin
  SetLength(LData, 0);
  AppendByte(LData, 2); // 长度 = 2 (1 version)
  AppendUInt16(LData, TLS13_VERSION);    // TLS 1.3
  Result := BuildExtensionHeader(TLS_EXTENSION_SUPPORTED_VERSIONS, LData);
end;

function BuildExtensionStatusRequest: TBytes;
var
  LData: TBytes;
begin
  SetLength(LData, 0);
  AppendByte(LData, TLS_CERT_STATUS_TYPE_OCSP);
  AppendUInt16(LData, 0);
  AppendUInt16(LData, 0);
  Result := BuildExtensionHeader(TLS_EXTENSION_STATUS_REQUEST, LData);
end;

function BuildExtensionSignedCertificateTimestamp: TBytes;
var
  LData: TBytes;
begin
  SetLength(LData, 0);
  Result := BuildExtensionHeader(TLS_EXTENSION_SIGNED_CERTIFICATE_TIMESTAMP, LData);
end;

function BuildExtensionSupportedGroups: TBytes;
var
  LData: TBytes;
begin
  SetLength(LData, 0);
  AppendUInt16(LData, 8); // 4 groups
  AppendUInt16(LData, TLS13_GROUP_X25519);
  AppendUInt16(LData, TLS13_GROUP_SECP256R1);
  AppendUInt16(LData, TLS13_GROUP_SECP384R1);
  AppendUInt16(LData, $0019); // secp521r1
  Result := BuildExtensionHeader(TLS_EXTENSION_SUPPORTED_GROUPS, LData);
end;

function BuildExtensionSignatureAlgorithms: TBytes;
var
  LData: TBytes;
begin
  SetLength(LData, 0);
  AppendUInt16(LData, 24); // 12 algorithms * 2 bytes
  AppendUInt16(LData, TLS13_SIG_ECDSA_SECP256R1_SHA256);
  AppendUInt16(LData, TLS13_SIG_ECDSA_SECP384R1_SHA384);
  AppendUInt16(LData, TLS13_SIG_ECDSA_SECP521R1_SHA512);
  AppendUInt16(LData, TLS13_SIG_ED25519);
  AppendUInt16(LData, TLS13_SIG_RSA_PSS_RSAE_SHA256);
  AppendUInt16(LData, TLS13_SIG_RSA_PSS_RSAE_SHA384);
  AppendUInt16(LData, TLS13_SIG_RSA_PSS_RSAE_SHA512);
  AppendUInt16(LData, TLS13_SIG_RSA_PSS_PSS_SHA256);
  AppendUInt16(LData, TLS13_SIG_RSA_PSS_PSS_SHA384);
  AppendUInt16(LData, TLS13_SIG_RSA_PSS_PSS_SHA512);
  AppendUInt16(LData, TLS13_SIG_RSA_PKCS1_SHA256);
  AppendUInt16(LData, TLS13_SIG_RSA_PKCS1_SHA384);
  Result := BuildExtensionHeader(TLS_EXTENSION_SIGNATURE_ALGORITHMS, LData);
end;

function BuildExtensionPSKKeyExchangeModes: TBytes;
var
  LData: TBytes;
begin
  SetLength(LData, 0);
  AppendByte(LData, 1);
  AppendByte(LData, 1); // psk_dhe_ke
  Result := BuildExtensionHeader(TLS_EXTENSION_PSK_KEY_EXCHANGE_MODES, LData);
end;

function BuildExtensionRecordSizeLimit(ALimit: Word): TBytes;
var
  LData: TBytes;
begin
  if (ALimit < TLS13_RECORD_SIZE_LIMIT_MIN) or (ALimit > TLS13_RECORD_SIZE_LIMIT_MAX) then
    RaiseInvalidParameter('TLS13RecordSizeLimit');

  SetLength(LData, 0);
  AppendUInt16(LData, ALimit);
  Result := BuildExtensionHeader(TLS_EXTENSION_RECORD_SIZE_LIMIT, LData);
end;

function BuildExtensionKeyShare(const AKeyShare: TBytes; AGroup: Word = 0): TBytes;
var
  LGroup: Word;
  LBuilder: IBytesBuilder;
  LEntry, LData: TBytes;
begin
  if Length(AKeyShare) = 0 then
    RaiseInvalidParameter('TLS13KeyShare');

  if AGroup <> 0 then
    LGroup := AGroup
  else if Length(AKeyShare) = 97 then
    LGroup := TLS13_GROUP_SECP384R1
  else if Length(AKeyShare) = 65 then
    LGroup := TLS13_GROUP_SECP256R1
  else
    LGroup := TLS13_GROUP_X25519;

  // perf: IBytesBuilder single alloc geometric, zero-copy BytesCopy, inline AppendUInt16BE
  LBuilder := CreateBytesBuilder(4 + Length(AKeyShare));
  LBuilder.AppendUInt16BE(LGroup);
  LBuilder.AppendUInt16BE(Word(Length(AKeyShare)));
  LBuilder.AppendSpan(TByteSpan.FromBytes(AKeyShare));
  LEntry := LBuilder.ToBytes;

  LBuilder := CreateBytesBuilder(2 + Length(LEntry));
  LBuilder.AppendUInt16BE(Word(Length(LEntry)));
  LBuilder.AppendSpan(TByteSpan.FromBytes(LEntry));
  LData := LBuilder.ToBytes;

  Result := BuildExtensionHeader(TLS_EXTENSION_KEY_SHARE, LData);
end;

function BuildExtensionEarlyData: TBytes;
var
  LData: TBytes;
begin
  SetLength(LData, 0);
  Result := BuildExtensionHeader(TLS_EXTENSION_EARLY_DATA, LData);
end;

function BuildExtensionSessionTicket: TBytes;
var
  LData: TBytes;
begin
  SetLength(LData, 0);
  Result := BuildExtensionHeader(TLS_EXTENSION_SESSION_TICKET, LData);
end;

function BuildExtensionPadding(ATargetLength: Integer; ACurrentLength: Integer): TBytes;
var
  LPadLen: Integer;
  LData: TBytes;
begin
  Result := nil;
  LPadLen := ATargetLength - ACurrentLength - 4;
  if LPadLen <= 0 then
    Exit;
  SetLength(LData, LPadLen);
  if LPadLen > 0 then
    FillChar(LData[0], LPadLen, 0);
  Result := BuildExtensionHeader(TLS_EXTENSION_PADDING, LData);
end;

function BuildExtensionPreSharedKey(
  const APSKOffer: TTLS13ClientHelloPSKOffer;
  const ABinder: TBytes
): TBytes;
var
  LBuilder: IBytesBuilder;
  LIdentityEntry, LIdentities, LBinders, LData: TBytes;
begin
  if not APSKOffer.Valid then
  begin
    Result := nil;
    Exit;
  end;

  // perf: IBytesBuilder geometric single alloc, zero-copy BytesCopy, inline Append*
  LBuilder := CreateBytesBuilder(2 + Length(APSKOffer.Identity) + 4);
  LBuilder.AppendUInt16BE(Word(Length(APSKOffer.Identity)));
  if Length(APSKOffer.Identity) > 0 then
    LBuilder.AppendSpan(TByteSpan.FromBytes(APSKOffer.Identity));
  LBuilder.AppendUInt32BE(APSKOffer.ObfuscatedTicketAge);
  LIdentityEntry := LBuilder.ToBytes;

  LBuilder := CreateBytesBuilder(2 + Length(LIdentityEntry));
  LBuilder.AppendUInt16BE(Word(Length(LIdentityEntry)));
  LBuilder.AppendSpan(TByteSpan.FromBytes(LIdentityEntry));
  LIdentities := LBuilder.ToBytes;

  LBuilder := CreateBytesBuilder(1 + Length(ABinder));
  LBuilder.AppendByte(Byte(Length(ABinder)));
  if Length(ABinder) > 0 then
    LBuilder.AppendSpan(TByteSpan.FromBytes(ABinder));
  LBinders := LBuilder.ToBytes;

  LBuilder := CreateBytesBuilder(2 + Length(LBinders));
  LBuilder.AppendUInt16BE(Word(Length(LBinders)));
  LBuilder.AppendSpan(TByteSpan.FromBytes(LBinders));
  LData := LBuilder.ToBytes;

  LBuilder := CreateBytesBuilder(Length(LIdentities) + Length(LData));
  LBuilder.AppendSpan(TByteSpan.FromBytes(LIdentities));
  LBuilder.AppendSpan(TByteSpan.FromBytes(LData));
  Result := BuildExtensionHeader(TLS_EXTENSION_PRE_SHARED_KEY, LBuilder.ToBytes);
end;

function BuildTLS13ClientHelloBody(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  AIncludeStatusRequest: Boolean;
  AIncludeSignedCertificateTimestamp: Boolean
): TBytes;
var
  LRandom, LSessionId: TBytes;
  LCipherSuites: TBytes;
  LCompressionMethods: TBytes;
  LExtensions: TBytes;
  LExt: TBytes;
  LBodyLen: Integer;
  LExtBuilder: IBytesBuilder;
  LBodyBuilder: IBytesBuilder;
begin
  LRandom := GenerateSecureRandomBytes(32);
  LSessionId := GenerateSecureRandomBytes(32);

  SetLength(LCipherSuites, 0);
  AppendDefaultTLS13CipherSuites(LCipherSuites);

  SetLength(LCompressionMethods, 0);
  AppendByte(LCompressionMethods, 1);
  AppendByte(LCompressionMethods, 0);

  // perf: use IBytesBuilder to avoid O(n²) BytesAppend realloc in extension loop;
  // single Grow preallocation and one ToBytes copy. See BytesBuilder.Grow/ToBytes.
  LExtBuilder := CreateBytesBuilder(512);

  // Extension order matches common browser fingerprints for CDN compatibility
  LExt := BuildExtensionServerName(AServerName);
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  // extended_master_secret (RFC 7627)
  LExtBuilder.AppendUInt16BE(TLS_EXTENSION_EXTENDED_MASTER_SECRET);
  LExtBuilder.AppendUInt16BE(0);

  // renegotiation_info: empty (RFC 5746)
  LExtBuilder.AppendUInt16BE(TLS_EXTENSION_RENEGOTIATION_INFO);
  LExtBuilder.AppendUInt16BE(1);
  LExtBuilder.AppendByte(0);

  LExt := BuildExtensionSupportedGroups;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  // ec_point_formats: uncompressed only
  LExtBuilder.AppendUInt16BE(TLS_EXTENSION_EC_POINT_FORMATS);
  LExtBuilder.AppendUInt16BE(2);
  LExtBuilder.AppendByte(1);
  LExtBuilder.AppendByte(0);

  // session_ticket (empty = willing to receive)
  LExt := BuildExtensionSessionTicket;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  LExt := BuildExtensionALPN(AALPNProtocols);
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  if AIncludeStatusRequest then
  begin
    LExt := BuildExtensionStatusRequest;
    if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  end;

  if AIncludeSignedCertificateTimestamp then
  begin
    LExt := BuildExtensionSignedCertificateTimestamp;
    if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  end;

  LExt := BuildExtensionSignatureAlgorithms;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  LExt := BuildExtensionRecordSizeLimit(TLS13_RECORD_SIZE_LIMIT_DEFAULT);
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  LExt := BuildExtensionSupportedVersions;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  LExt := BuildExtensionPSKKeyExchangeModes;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  LExt := BuildExtensionKeyShare(AKeyShare);
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  LExtensions := LExtBuilder.ToBytes;

  // Calculate total ClientHello size to determine padding need
  // header(4) + version(2) + random(32) + session_id_len(1) + session_id(32) +
  // cipher_suites_len(2) + cipher_suites + comp_len + extensions_len(2) + extensions
  LBodyLen := 2 + 32 + 1 + 32 + 2 + Length(LCipherSuites) + Length(LCompressionMethods) + 2 + Length(LExtensions);
  if LBodyLen + 4 < 512 then
  begin
    LExt := BuildExtensionPadding(512, LBodyLen + 4);
    if Length(LExt) > 0 then
    begin
      // re-append padding via builder to keep single allocation path
      LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
      LExtensions := LExtBuilder.ToBytes;
    end;
  end;

  // perf: final body also via builder (preallocated) instead of repeated BytesAppend O(n²)
  LBodyBuilder := CreateBytesBuilder(LBodyLen + 32);
  LBodyBuilder.AppendUInt16BE(TLS_LEGACY_VERSION);
  LBodyBuilder.AppendSpan(TByteSpan.FromBytes(LRandom));
  LBodyBuilder.AppendByte(Byte(Length(LSessionId)));
  LBodyBuilder.AppendSpan(TByteSpan.FromBytes(LSessionId));
  LBodyBuilder.AppendUInt16BE(Word(Length(LCipherSuites)));
  LBodyBuilder.AppendSpan(TByteSpan.FromBytes(LCipherSuites));
  LBodyBuilder.AppendSpan(TByteSpan.FromBytes(LCompressionMethods));
  LBodyBuilder.AppendUInt16BE(Word(Length(LExtensions)));
  LBodyBuilder.AppendSpan(TByteSpan.FromBytes(LExtensions));
  Result := LBodyBuilder.ToBytes;
end;

function BuildTLS13ClientHelloBodyWithPSKCore(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  const APSKOffer: TTLS13ClientHelloPSKOffer;
  const ARandom: TBytes;
  const ASessionId: TBytes;
  out APartialBody: TBytes;
  AIncludeStatusRequest: Boolean;
  AIncludeSignedCertificateTimestamp: Boolean
): TBytes;
var
  LCipherSuites: TBytes;
  LCompressionMethods: TBytes;
  LBaseExtensions: TBytes;
  LExt: TBytes;
  LZeroBinder: TBytes;
  LPartialPSKExtension: TBytes;
  LFinalPSKExtension: TBytes;
  LExtBuilder: IBytesBuilder;
  LPartialBuilder: IBytesBuilder;
  LFinalBuilder: IBytesBuilder;
begin
  SetLength(LCipherSuites, 0);
  AppendDefaultTLS13CipherSuites(LCipherSuites);

  SetLength(LCompressionMethods, 0);
  AppendByte(LCompressionMethods, 1);
  AppendByte(LCompressionMethods, 0);

  // perf: use IBytesBuilder to avoid O(n²) BytesAppend realloc in extension loop;
  // single Grow preallocation and one ToBytes copy. See BytesBuilder.Grow/ToBytes.
  LExtBuilder := CreateBytesBuilder(512);
  LExt := BuildExtensionServerName(AServerName);
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  // extended_master_secret (RFC 7627)
  LExtBuilder.AppendUInt16BE(TLS_EXTENSION_EXTENDED_MASTER_SECRET);
  LExtBuilder.AppendUInt16BE(0);
  // renegotiation_info: empty (RFC 5746)
  LExtBuilder.AppendUInt16BE(TLS_EXTENSION_RENEGOTIATION_INFO);
  LExtBuilder.AppendUInt16BE(1);
  LExtBuilder.AppendByte(0);
  LExt := BuildExtensionSupportedGroups;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  // ec_point_formats: uncompressed only
  LExtBuilder.AppendUInt16BE(TLS_EXTENSION_EC_POINT_FORMATS);
  LExtBuilder.AppendUInt16BE(2);
  LExtBuilder.AppendByte(1);
  LExtBuilder.AppendByte(0);
  // session_ticket
  LExt := BuildExtensionSessionTicket;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  LExt := BuildExtensionALPN(AALPNProtocols);
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  if AIncludeStatusRequest then
  begin
    LExt := BuildExtensionStatusRequest;
    if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  end;
  if AIncludeSignedCertificateTimestamp then
  begin
    LExt := BuildExtensionSignedCertificateTimestamp;
    if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  end;
  LExt := BuildExtensionSignatureAlgorithms;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  LExt := BuildExtensionRecordSizeLimit(TLS13_RECORD_SIZE_LIMIT_DEFAULT);
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  LExt := BuildExtensionSupportedVersions;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  LExt := BuildExtensionPSKKeyExchangeModes;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  LExt := BuildExtensionKeyShare(AKeyShare);
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  if APSKOffer.Valid and APSKOffer.AllowEarlyData then
  begin
    LExt := BuildExtensionEarlyData;
    if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  end;
  LBaseExtensions := LExtBuilder.ToBytes;

  // perf: partial/final body also via builder (preallocated) instead of repeated BytesAppend O(n²);
  // zero-copy WrittenSpan via ToBytes single allocation. IBytesBuilder is refcounted interface, no manual free needed.
  if APSKOffer.Valid then
  begin
    SetLength(LZeroBinder, Length(APSKOffer.Binder));
    if Length(LZeroBinder) > 0 then
      FillChar(LZeroBinder[0], Length(LZeroBinder), 0);
    LPartialPSKExtension := BuildExtensionPreSharedKey(APSKOffer, LZeroBinder);
    LFinalPSKExtension := BuildExtensionPreSharedKey(APSKOffer, APSKOffer.Binder);

    LPartialBuilder := CreateBytesBuilder(2 + Length(ARandom) + 1 + Length(ASessionId) + 2 + Length(LCipherSuites) + Length(LCompressionMethods) + 2 + Length(LBaseExtensions) + Length(LPartialPSKExtension));
    LPartialBuilder.AppendUInt16BE(TLS_LEGACY_VERSION);
    LPartialBuilder.AppendSpan(TByteSpan.FromBytes(ARandom));
    LPartialBuilder.AppendByte(Byte(Length(ASessionId)));
    LPartialBuilder.AppendSpan(TByteSpan.FromBytes(ASessionId));
    LPartialBuilder.AppendUInt16BE(Word(Length(LCipherSuites)));
    LPartialBuilder.AppendSpan(TByteSpan.FromBytes(LCipherSuites));
    LPartialBuilder.AppendSpan(TByteSpan.FromBytes(LCompressionMethods));
    LPartialBuilder.AppendUInt16BE(Word(Length(LBaseExtensions) + Length(LPartialPSKExtension)));
    LPartialBuilder.AppendSpan(TByteSpan.FromBytes(LBaseExtensions));
    LPartialBuilder.AppendSpan(TByteSpan.FromBytes(LPartialPSKExtension));
    APartialBody := LPartialBuilder.ToBytes;

    LFinalBuilder := CreateBytesBuilder(LPartialBuilder.Length + (Length(LFinalPSKExtension) - Length(LPartialPSKExtension)) + 8);
    LFinalBuilder.AppendUInt16BE(TLS_LEGACY_VERSION);
    LFinalBuilder.AppendSpan(TByteSpan.FromBytes(ARandom));
    LFinalBuilder.AppendByte(Byte(Length(ASessionId)));
    LFinalBuilder.AppendSpan(TByteSpan.FromBytes(ASessionId));
    LFinalBuilder.AppendUInt16BE(Word(Length(LCipherSuites)));
    LFinalBuilder.AppendSpan(TByteSpan.FromBytes(LCipherSuites));
    LFinalBuilder.AppendSpan(TByteSpan.FromBytes(LCompressionMethods));
    LFinalBuilder.AppendUInt16BE(Word(Length(LBaseExtensions) + Length(LFinalPSKExtension)));
    LFinalBuilder.AppendSpan(TByteSpan.FromBytes(LBaseExtensions));
    LFinalBuilder.AppendSpan(TByteSpan.FromBytes(LFinalPSKExtension));
    Result := LFinalBuilder.ToBytes;
    Exit;
  end;

  LPartialBuilder := CreateBytesBuilder(2 + Length(ARandom) + 1 + Length(ASessionId) + 2 + Length(LCipherSuites) + Length(LCompressionMethods) + 2 + Length(LBaseExtensions));
  LPartialBuilder.AppendUInt16BE(TLS_LEGACY_VERSION);
  LPartialBuilder.AppendSpan(TByteSpan.FromBytes(ARandom));
  LPartialBuilder.AppendByte(Byte(Length(ASessionId)));
  LPartialBuilder.AppendSpan(TByteSpan.FromBytes(ASessionId));
  LPartialBuilder.AppendUInt16BE(Word(Length(LCipherSuites)));
  LPartialBuilder.AppendSpan(TByteSpan.FromBytes(LCipherSuites));
  LPartialBuilder.AppendSpan(TByteSpan.FromBytes(LCompressionMethods));
  LPartialBuilder.AppendUInt16BE(Word(Length(LBaseExtensions)));
  LPartialBuilder.AppendSpan(TByteSpan.FromBytes(LBaseExtensions));
  APartialBody := LPartialBuilder.ToBytes;
  Result := Copy(APartialBody);
end;

function BuildTLS13ClientHelloBodyWithPSK(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  const APSKOffer: TTLS13ClientHelloPSKOffer;
  out APartialBody: TBytes;
  AIncludeStatusRequest: Boolean;
  AIncludeSignedCertificateTimestamp: Boolean
): TBytes;
var
  LRandom: TBytes;
  LSessionId: TBytes;
begin
  LRandom := GenerateSecureRandomBytes(32);
  LSessionId := GenerateSecureRandomBytes(32);
  Result := BuildTLS13ClientHelloBodyWithPSKCore(
    AServerName,
    AALPNProtocols,
    AKeyShare,
    APSKOffer,
    LRandom,
    LSessionId,
    APartialBody,
    AIncludeStatusRequest,
    AIncludeSignedCertificateTimestamp
  );
end;

function BuildTLS13ClientHelloHandshake(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  AIncludeStatusRequest: Boolean;
  AIncludeSignedCertificateTimestamp: Boolean
): TBytes;
var
  LBody: TBytes;
  LBuilder: IBytesBuilder;
begin
  LBody := BuildTLS13ClientHelloBody(
    AServerName,
    AALPNProtocols,
    AKeyShare,
    AIncludeStatusRequest,
    AIncludeSignedCertificateTimestamp
  );

  // perf: handshake via IBytesBuilder single alloc geometric 0→64→2×; zero-copy BytesCopy single source; inline AppendByte
  LBuilder := CreateBytesBuilder(4 + Length(LBody));
  LBuilder.AppendByte(TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  LBuilder.AppendByte(Byte(Length(LBody) shr 16));
  LBuilder.AppendByte(Byte(Length(LBody) shr 8));
  LBuilder.AppendByte(Byte(Length(LBody)));
  if Length(LBody) > 0 then
    LBuilder.AppendSpan(TByteSpan.FromBytes(LBody));
  Result := LBuilder.ToBytes;
end;

function BuildTLS13ClientHelloRecord(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  AIncludeStatusRequest: Boolean;
  AIncludeSignedCertificateTimestamp: Boolean
): TBytes;
var
  LHandshake: TBytes;
begin
  LHandshake := BuildTLS13ClientHelloHandshake(
    AServerName,
    AALPNProtocols,
    AKeyShare,
    AIncludeStatusRequest,
    AIncludeSignedCertificateTimestamp
  );
  Result := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, LHandshake);
end;

function BuildTLS13ClientHelloHandshakeWithPSK(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  const APSKOffer: TTLS13ClientHelloPSKOffer;
  out APartialHandshake: TBytes;
  AIncludeStatusRequest: Boolean;
  AIncludeSignedCertificateTimestamp: Boolean
): TBytes;
var
  LBody: TBytes;
  LPartialBody: TBytes;
  LBuilder: IBytesBuilder;
begin
  LBody := BuildTLS13ClientHelloBodyWithPSK(
    AServerName,
    AALPNProtocols,
    AKeyShare,
    APSKOffer,
    LPartialBody,
    AIncludeStatusRequest,
    AIncludeSignedCertificateTimestamp
  );

  // perf: handshake via IBytesBuilder single alloc geometric; zero-copy BytesCopy; inline AppendByte
  LBuilder := CreateBytesBuilder(4 + Length(LPartialBody));
  LBuilder.AppendByte(TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  LBuilder.AppendByte(Byte(Length(LPartialBody) shr 16));
  LBuilder.AppendByte(Byte(Length(LPartialBody) shr 8));
  LBuilder.AppendByte(Byte(Length(LPartialBody)));
  if Length(LPartialBody) > 0 then
    LBuilder.AppendSpan(TByteSpan.FromBytes(LPartialBody));
  APartialHandshake := LBuilder.ToBytes;

  { RFC 8446 Section 4.2.11.2: truncate partial handshake to exclude binders
    (binders_length field + binder entries). OpenSSL hashes up to but NOT
    including the 2-byte binders_length field. }
  if APSKOffer.Valid and (Length(APSKOffer.Binder) > 0) then
    SetLength(APartialHandshake, Length(APartialHandshake) - (2 + 1 + Length(APSKOffer.Binder)));

  LBuilder := CreateBytesBuilder(4 + Length(LBody));
  LBuilder.AppendByte(TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  LBuilder.AppendByte(Byte(Length(LBody) shr 16));
  LBuilder.AppendByte(Byte(Length(LBody) shr 8));
  LBuilder.AppendByte(Byte(Length(LBody)));
  if Length(LBody) > 0 then
    LBuilder.AppendSpan(TByteSpan.FromBytes(LBody));
  Result := LBuilder.ToBytes;
end;

function BuildTLS13ClientHelloHandshakeWithComputedPSKBinder(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  ACipherSuite: Word;
  const APSKIdentity: TBytes;
  AObfuscatedTicketAge: Cardinal;
  const AResumptionPSK: TBytes;
  out APartialHandshake: TBytes;
  AAllowEarlyData: Boolean;
  AIncludeStatusRequest: Boolean;
  AIncludeSignedCertificateTimestamp: Boolean
): TBytes;
var
  LOffer: TTLS13ClientHelloPSKOffer;
  LPartialBody: TBytes;
  LBody: TBytes;
  LRandom: TBytes;
  LSessionId: TBytes;
  LBuilder: IBytesBuilder;
begin
  FillChar(LOffer, SizeOf(LOffer), 0);
  LOffer.Valid := True;
  LOffer.Identity := Copy(APSKIdentity);
  LOffer.ObfuscatedTicketAge := AObfuscatedTicketAge;
  LOffer.AllowEarlyData := AAllowEarlyData;
  SetLength(LOffer.Binder, Length(AResumptionPSK));
  if Length(LOffer.Binder) > 0 then
    FillChar(LOffer.Binder[0], Length(LOffer.Binder), 0);

  LRandom := GenerateSecureRandomBytes(32);
  LSessionId := GenerateSecureRandomBytes(32);
  LBody := BuildTLS13ClientHelloBodyWithPSKCore(
    AServerName,
    AALPNProtocols,
    AKeyShare,
    LOffer,
    LRandom,
    LSessionId,
    LPartialBody,
    AIncludeStatusRequest,
    AIncludeSignedCertificateTimestamp
  );

  // perf: handshake via IBytesBuilder single alloc geometric; zero-copy
  LBuilder := CreateBytesBuilder(4 + Length(LPartialBody));
  LBuilder.AppendByte(TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  LBuilder.AppendByte(Byte(Length(LPartialBody) shr 16));
  LBuilder.AppendByte(Byte(Length(LPartialBody) shr 8));
  LBuilder.AppendByte(Byte(Length(LPartialBody)));
  if Length(LPartialBody) > 0 then
    LBuilder.AppendSpan(TByteSpan.FromBytes(LPartialBody));
  APartialHandshake := LBuilder.ToBytes;

  { RFC 8446 Section 4.2.11.2: truncate partial handshake to exclude binders
    (binders_length field + binder entries). OpenSSL hashes up to but NOT
    including the 2-byte binders_length field. }
  SetLength(APartialHandshake, Length(APartialHandshake) - (2 + 1 + Length(AResumptionPSK)));
  LOffer.Binder := TLS13ComputePSKBinderForCipherSuite(
    ACipherSuite,
    AResumptionPSK,
    APartialHandshake
  );
  LBody := BuildTLS13ClientHelloBodyWithPSKCore(
    AServerName,
    AALPNProtocols,
    AKeyShare,
    LOffer,
    LRandom,
    LSessionId,
    LPartialBody,
    AIncludeStatusRequest,
    AIncludeSignedCertificateTimestamp
  );

  LBuilder := CreateBytesBuilder(4 + Length(LBody));
  LBuilder.AppendByte(TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  LBuilder.AppendByte(Byte(Length(LBody) shr 16));
  LBuilder.AppendByte(Byte(Length(LBody) shr 8));
  LBuilder.AppendByte(Byte(Length(LBody)));
  if Length(LBody) > 0 then
    LBuilder.AppendSpan(TByteSpan.FromBytes(LBody));
  Result := LBuilder.ToBytes;
end;

function BuildTLS13ClientHelloRecordWithPSK(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  const APSKOffer: TTLS13ClientHelloPSKOffer;
  out APartialHandshake: TBytes;
  AIncludeStatusRequest: Boolean;
  AIncludeSignedCertificateTimestamp: Boolean
): TBytes;
var
  LHandshake: TBytes;
begin
  LHandshake := BuildTLS13ClientHelloHandshakeWithPSK(
    AServerName,
    AALPNProtocols,
    AKeyShare,
    APSKOffer,
    APartialHandshake,
    AIncludeStatusRequest,
    AIncludeSignedCertificateTimestamp
  );
  Result := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, LHandshake);
end;


function BuildTLS13ClientHelloBodyWithCiphers(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  const ACipherSuites: TTLS13CipherSuiteList;
  AIncludeStatusRequest: Boolean;
  AIncludeSignedCertificateTimestamp: Boolean;
  AQuic13Only: Boolean
): TBytes;
var
  LRandom, LSessionId: TBytes;
  LCipherSuites: TBytes;
  LCompressionMethods: TBytes;
  LExtensions: TBytes;
  LExt: TBytes;
  LBodyLen: Integer;
  LExtBuilder: IBytesBuilder;
  LBodyBuilder: IBytesBuilder;
begin
  LRandom := GenerateSecureRandomBytes(32);
  LSessionId := GenerateSecureRandomBytes(32);

  SetLength(LCipherSuites, 0);
  if Length(ACipherSuites) > 0 then
    AppendTLS13CipherSuites(LCipherSuites, ACipherSuites)
  else
    AppendDefaultTLS13CipherSuites(LCipherSuites);

  SetLength(LCompressionMethods, 0);
  AppendByte(LCompressionMethods, 1);
  AppendByte(LCompressionMethods, 0);

  // perf: use IBytesBuilder geometric 0→64→2× to avoid O(n²) BytesAppend realloc in extension loop; single Grow + ToBytes copy. bytes.ops:50
  LExtBuilder := CreateBytesBuilder(512);

  LExt := BuildExtensionServerName(AServerName);
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  // extended_master_secret (RFC 7627)
  LExtBuilder.AppendUInt16BE(TLS_EXTENSION_EXTENDED_MASTER_SECRET);
  LExtBuilder.AppendUInt16BE(0);

  // renegotiation_info: empty (RFC 5746)
  LExtBuilder.AppendUInt16BE(TLS_EXTENSION_RENEGOTIATION_INFO);
  LExtBuilder.AppendUInt16BE(1);
  LExtBuilder.AppendByte(0);

  LExt := BuildExtensionSupportedGroups;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  // ec_point_formats: uncompressed only
  LExtBuilder.AppendUInt16BE(TLS_EXTENSION_EC_POINT_FORMATS);
  LExtBuilder.AppendUInt16BE(2);
  LExtBuilder.AppendByte(1);
  LExtBuilder.AppendByte(0);

  // session_ticket (empty = willing to receive)
  LExt := BuildExtensionSessionTicket;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  LExt := BuildExtensionALPN(AALPNProtocols);
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  if AIncludeStatusRequest then
  begin
    LExt := BuildExtensionStatusRequest;
    if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  end;

  if AIncludeSignedCertificateTimestamp then
  begin
    LExt := BuildExtensionSignedCertificateTimestamp;
    if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  end;

  LExt := BuildExtensionSignatureAlgorithms;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  LExt := BuildExtensionRecordSizeLimit(TLS13_RECORD_SIZE_LIMIT_DEFAULT);
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  if AQuic13Only then
    LExt := BuildExtensionSupportedVersionsQuic
  else
    LExt := BuildExtensionSupportedVersions;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  LExt := BuildExtensionPSKKeyExchangeModes;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  LExt := BuildExtensionKeyShare(AKeyShare);
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));

  LExtensions := LExtBuilder.ToBytes;

  LBodyLen := 2 + 32 + 1 + 32 + 2 + Length(LCipherSuites) + Length(LCompressionMethods) + 2 + Length(LExtensions);
  if LBodyLen + 4 < 512 then
  begin
    LExt := BuildExtensionPadding(512, LBodyLen + 4);
    if Length(LExt) > 0 then
    begin
      LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
      LExtensions := LExtBuilder.ToBytes;
    end;
  end;

  // perf: final body also via builder preallocated instead of repeated BytesAppend O(n²); zero-copy span, single ToBytes
  LBodyBuilder := CreateBytesBuilder(LBodyLen + 32);
  LBodyBuilder.AppendUInt16BE(TLS_LEGACY_VERSION);
  LBodyBuilder.AppendSpan(TByteSpan.FromBytes(LRandom));
  LBodyBuilder.AppendByte(Byte(Length(LSessionId)));
  LBodyBuilder.AppendSpan(TByteSpan.FromBytes(LSessionId));
  LBodyBuilder.AppendUInt16BE(Word(Length(LCipherSuites)));
  LBodyBuilder.AppendSpan(TByteSpan.FromBytes(LCipherSuites));
  LBodyBuilder.AppendSpan(TByteSpan.FromBytes(LCompressionMethods));
  LBodyBuilder.AppendUInt16BE(Word(Length(LExtensions)));
  LBodyBuilder.AppendSpan(TByteSpan.FromBytes(LExtensions));
  Result := LBodyBuilder.ToBytes;
end;

function BuildTLS13ClientHelloHandshakeWithCiphers(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  const ACipherSuites: TTLS13CipherSuiteList;
  AIncludeStatusRequest: Boolean;
  AIncludeSignedCertificateTimestamp: Boolean;
  AQuic13Only: Boolean
): TBytes;
var
  LBody: TBytes;
  LBuilder: IBytesBuilder;
begin
  LBody := BuildTLS13ClientHelloBodyWithCiphers(
    AServerName,
    AALPNProtocols,
    AKeyShare,
    ACipherSuites,
    AIncludeStatusRequest,
    AIncludeSignedCertificateTimestamp,
    AQuic13Only
  );

  // perf: single alloc via IBytesBuilder; zero-copy
  LBuilder := CreateBytesBuilder(4 + Length(LBody));
  LBuilder.AppendByte(TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  LBuilder.AppendByte(Byte(Length(LBody) shr 16));
  LBuilder.AppendByte(Byte(Length(LBody) shr 8));
  LBuilder.AppendByte(Byte(Length(LBody)));
  if Length(LBody) > 0 then
    LBuilder.AppendSpan(TByteSpan.FromBytes(LBody));
  Result := LBuilder.ToBytes;
end;

function BuildTLS13ClientHelloBodyWithPSKCoreAndCiphers(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  const APSKOffer: TTLS13ClientHelloPSKOffer;
  const ARandom: TBytes;
  const ASessionId: TBytes;
  const ACipherSuites: TTLS13CipherSuiteList;
  out APartialBody: TBytes;
  AIncludeStatusRequest: Boolean;
  AIncludeSignedCertificateTimestamp: Boolean
): TBytes;
var
  LCipherSuites: TBytes;
  LCompressionMethods: TBytes;
  LBaseExtensions: TBytes;
  LExt: TBytes;
  LZeroBinder: TBytes;
  LPartialPSKExtension: TBytes;
  LFinalPSKExtension: TBytes;
  LExtBuilder: IBytesBuilder;
  LPartialBuilder: IBytesBuilder;
  LFinalBuilder: IBytesBuilder;
begin
  SetLength(LCipherSuites, 0);
  if Length(ACipherSuites) > 0 then
    AppendTLS13CipherSuites(LCipherSuites, ACipherSuites)
  else
    AppendDefaultTLS13CipherSuites(LCipherSuites);

  SetLength(LCompressionMethods, 0);
  AppendByte(LCompressionMethods, 1);
  AppendByte(LCompressionMethods, 0);

  // perf: use IBytesBuilder to avoid O(n²) BytesAppend realloc in extension loop;
  // single Grow preallocation and one ToBytes copy. See BytesBuilder.Grow/ToBytes.
  LExtBuilder := CreateBytesBuilder(512);
  LExt := BuildExtensionServerName(AServerName);
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  LExtBuilder.AppendUInt16BE(TLS_EXTENSION_EXTENDED_MASTER_SECRET);
  LExtBuilder.AppendUInt16BE(0);
  LExtBuilder.AppendUInt16BE(TLS_EXTENSION_RENEGOTIATION_INFO);
  LExtBuilder.AppendUInt16BE(1);
  LExtBuilder.AppendByte(0);
  LExt := BuildExtensionSupportedGroups;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  LExtBuilder.AppendUInt16BE(TLS_EXTENSION_EC_POINT_FORMATS);
  LExtBuilder.AppendUInt16BE(2);
  LExtBuilder.AppendByte(1);
  LExtBuilder.AppendByte(0);
  LExt := BuildExtensionSessionTicket;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  LExt := BuildExtensionALPN(AALPNProtocols);
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  if AIncludeStatusRequest then
  begin
    LExt := BuildExtensionStatusRequest;
    if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  end;
  if AIncludeSignedCertificateTimestamp then
  begin
    LExt := BuildExtensionSignedCertificateTimestamp;
    if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  end;
  LExt := BuildExtensionSignatureAlgorithms;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  LExt := BuildExtensionRecordSizeLimit(TLS13_RECORD_SIZE_LIMIT_DEFAULT);
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  LExt := BuildExtensionSupportedVersions;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  LExt := BuildExtensionPSKKeyExchangeModes;
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  LExt := BuildExtensionKeyShare(AKeyShare);
  if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  if APSKOffer.Valid and APSKOffer.AllowEarlyData then
  begin
    LExt := BuildExtensionEarlyData;
    if Length(LExt) > 0 then LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExt));
  end;
  LBaseExtensions := LExtBuilder.ToBytes;

  // perf: partial/final body also via builder (preallocated) instead of repeated BytesAppend O(n²);
  // zero-copy WrittenSpan via ToBytes single allocation. IBytesBuilder is refcounted, no manual free.
  if APSKOffer.Valid then
  begin
    SetLength(LZeroBinder, Length(APSKOffer.Binder));
    if Length(LZeroBinder) > 0 then
      FillChar(LZeroBinder[0], Length(LZeroBinder), 0);
    LPartialPSKExtension := BuildExtensionPreSharedKey(APSKOffer, LZeroBinder);
    LFinalPSKExtension := BuildExtensionPreSharedKey(APSKOffer, APSKOffer.Binder);

    LPartialBuilder := CreateBytesBuilder(2 + Length(ARandom) + 1 + Length(ASessionId) + 2 + Length(LCipherSuites) + Length(LCompressionMethods) + 2 + Length(LBaseExtensions) + Length(LPartialPSKExtension));
    LPartialBuilder.AppendUInt16BE(TLS_LEGACY_VERSION);
    LPartialBuilder.AppendSpan(TByteSpan.FromBytes(ARandom));
    LPartialBuilder.AppendByte(Byte(Length(ASessionId)));
    LPartialBuilder.AppendSpan(TByteSpan.FromBytes(ASessionId));
    LPartialBuilder.AppendUInt16BE(Word(Length(LCipherSuites)));
    LPartialBuilder.AppendSpan(TByteSpan.FromBytes(LCipherSuites));
    LPartialBuilder.AppendSpan(TByteSpan.FromBytes(LCompressionMethods));
    LPartialBuilder.AppendUInt16BE(Word(Length(LBaseExtensions) + Length(LPartialPSKExtension)));
    LPartialBuilder.AppendSpan(TByteSpan.FromBytes(LBaseExtensions));
    LPartialBuilder.AppendSpan(TByteSpan.FromBytes(LPartialPSKExtension));
    APartialBody := LPartialBuilder.ToBytes;

    LFinalBuilder := CreateBytesBuilder(LPartialBuilder.Length + (Length(LFinalPSKExtension) - Length(LPartialPSKExtension)) + 8);
    LFinalBuilder.AppendUInt16BE(TLS_LEGACY_VERSION);
    LFinalBuilder.AppendSpan(TByteSpan.FromBytes(ARandom));
    LFinalBuilder.AppendByte(Byte(Length(ASessionId)));
    LFinalBuilder.AppendSpan(TByteSpan.FromBytes(ASessionId));
    LFinalBuilder.AppendUInt16BE(Word(Length(LCipherSuites)));
    LFinalBuilder.AppendSpan(TByteSpan.FromBytes(LCipherSuites));
    LFinalBuilder.AppendSpan(TByteSpan.FromBytes(LCompressionMethods));
    LFinalBuilder.AppendUInt16BE(Word(Length(LBaseExtensions) + Length(LFinalPSKExtension)));
    LFinalBuilder.AppendSpan(TByteSpan.FromBytes(LBaseExtensions));
    LFinalBuilder.AppendSpan(TByteSpan.FromBytes(LFinalPSKExtension));
    Result := LFinalBuilder.ToBytes;
    Exit;
  end;

  LPartialBuilder := CreateBytesBuilder(2 + Length(ARandom) + 1 + Length(ASessionId) + 2 + Length(LCipherSuites) + Length(LCompressionMethods) + 2 + Length(LBaseExtensions));
  LPartialBuilder.AppendUInt16BE(TLS_LEGACY_VERSION);
  LPartialBuilder.AppendSpan(TByteSpan.FromBytes(ARandom));
  LPartialBuilder.AppendByte(Byte(Length(ASessionId)));
  LPartialBuilder.AppendSpan(TByteSpan.FromBytes(ASessionId));
  LPartialBuilder.AppendUInt16BE(Word(Length(LCipherSuites)));
  LPartialBuilder.AppendSpan(TByteSpan.FromBytes(LCipherSuites));
  LPartialBuilder.AppendSpan(TByteSpan.FromBytes(LCompressionMethods));
  LPartialBuilder.AppendUInt16BE(Word(Length(LBaseExtensions)));
  LPartialBuilder.AppendSpan(TByteSpan.FromBytes(LBaseExtensions));
  APartialBody := LPartialBuilder.ToBytes;
  Result := Copy(APartialBody);
end;

function BuildTLS13ClientHelloHandshakeWithComputedPSKBinderAndCiphers(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  ACipherSuite: Word;
  const APSKIdentity: TBytes;
  AObfuscatedTicketAge: Cardinal;
  const AResumptionPSK: TBytes;
  const ACipherSuites: TTLS13CipherSuiteList;
  out APartialHandshake: TBytes;
  AAllowEarlyData: Boolean;
  AIncludeStatusRequest: Boolean;
  AIncludeSignedCertificateTimestamp: Boolean
): TBytes;
var
  LOffer: TTLS13ClientHelloPSKOffer;
  LPartialBody: TBytes;
  LBody: TBytes;
  LRandom: TBytes;
  LSessionId: TBytes;
  LBuilder: IBytesBuilder;
begin
  FillChar(LOffer, SizeOf(LOffer), 0);
  LOffer.Valid := True;
  LOffer.Identity := Copy(APSKIdentity);
  LOffer.ObfuscatedTicketAge := AObfuscatedTicketAge;
  LOffer.AllowEarlyData := AAllowEarlyData;
  SetLength(LOffer.Binder, Length(AResumptionPSK));
  if Length(LOffer.Binder) > 0 then
    FillChar(LOffer.Binder[0], Length(LOffer.Binder), 0);

  LRandom := GenerateSecureRandomBytes(32);
  LSessionId := GenerateSecureRandomBytes(32);
  LBody := BuildTLS13ClientHelloBodyWithPSKCoreAndCiphers(
    AServerName,
    AALPNProtocols,
    AKeyShare,
    LOffer,
    LRandom,
    LSessionId,
    ACipherSuites,
    LPartialBody,
    AIncludeStatusRequest,
    AIncludeSignedCertificateTimestamp
  );

  // perf: handshake via IBytesBuilder single alloc; zero-copy
  LBuilder := CreateBytesBuilder(4 + Length(LPartialBody));
  LBuilder.AppendByte(TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  LBuilder.AppendByte(Byte(Length(LPartialBody) shr 16));
  LBuilder.AppendByte(Byte(Length(LPartialBody) shr 8));
  LBuilder.AppendByte(Byte(Length(LPartialBody)));
  if Length(LPartialBody) > 0 then
    LBuilder.AppendSpan(TByteSpan.FromBytes(LPartialBody));
  APartialHandshake := LBuilder.ToBytes;

  { RFC 8446 Section 4.2.11.2: truncate partial handshake to exclude binders
    (binders_length field + binder entries). OpenSSL hashes up to but NOT
    including the 2-byte binders_length field. }
  SetLength(APartialHandshake, Length(APartialHandshake) - (2 + 1 + Length(AResumptionPSK)));

  LOffer.Binder := TLS13ComputePSKBinderForCipherSuite(
    ACipherSuite,
    AResumptionPSK,
    APartialHandshake
  );
  LBody := BuildTLS13ClientHelloBodyWithPSKCoreAndCiphers(
    AServerName,
    AALPNProtocols,
    AKeyShare,
    LOffer,
    LRandom,
    LSessionId,
    ACipherSuites,
    LPartialBody,
    AIncludeStatusRequest,
    AIncludeSignedCertificateTimestamp
  );

  LBuilder := CreateBytesBuilder(4 + Length(LBody));
  LBuilder.AppendByte(TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  LBuilder.AppendByte(Byte(Length(LBody) shr 16));
  LBuilder.AppendByte(Byte(Length(LBody) shr 8));
  LBuilder.AppendByte(Byte(Length(LBody)));
  if Length(LBody) > 0 then
    LBuilder.AppendSpan(TByteSpan.FromBytes(LBody));
  Result := LBuilder.ToBytes;
end;

function ParseTLS13CipherSuiteString(const ACipherSuiteStr: string): TTLS13CipherSuiteList;
var
  I: Integer;
  LStart, LStop: Integer;
  LValue: string;
  LCount: Integer;
  LUpper: string;
begin
  Result := nil;
  LCount := 0;
  LStart := 1;

  for I := 1 to Length(ACipherSuiteStr) + 1 do
  begin
    if (I <= Length(ACipherSuiteStr)) and (ACipherSuiteStr[I] <> ':') then
      Continue;

    LStop := I - 1;
    while (LStart <= LStop) and ((ACipherSuiteStr[LStart] = ' ') or (ACipherSuiteStr[LStart] = #9)) do
      Inc(LStart);
    while (LStop >= LStart) and ((ACipherSuiteStr[LStop] = ' ') or (ACipherSuiteStr[LStop] = #9)) do
      Dec(LStop);

    if LStop >= LStart then
    begin
      LValue := Copy(ACipherSuiteStr, LStart, LStop - LStart + 1);
      LUpper := UpperCase(LValue);

      if (LUpper = 'TLS_AES_256_GCM_SHA384') or (LUpper = 'AES_256_GCM_SHA384') then
      begin
        SetLength(Result, LCount + 1);
        Result[LCount] := TLS13_CIPHER_AES_256_GCM_SHA384;
        Inc(LCount);
      end
      else if (LUpper = 'TLS_CHACHA20_POLY1305_SHA256') or (LUpper = 'CHACHA20_POLY1305_SHA256') then
      begin
        SetLength(Result, LCount + 1);
        Result[LCount] := TLS13_CIPHER_CHACHA20_POLY1305_SHA256;
        Inc(LCount);
      end
      else if (LUpper = 'TLS_AES_128_GCM_SHA256') or (LUpper = 'AES_128_GCM_SHA256') then
      begin
        SetLength(Result, LCount + 1);
        Result[LCount] := TLS13_CIPHER_AES_128_GCM_SHA256;
        Inc(LCount);
      end;
    end;

    LStart := I + 1;
  end;
end;

function PatchClientHelloKeyShare(const AOriginalCH: TBytes; const ANewKeyShare: TBytes; ANewGroup: Word): TBytes;
var
  LPos, LExtStart, LExtLen, LExtType, LExtListLen: Integer;
  LSessionIdLen, LCipherLen, LCompLen: Integer;
  LNewExt, LBefore, LAfter: TBytes;
  LNewExtEntry: TBytes;
  LBuilder: IBytesBuilder;
begin
  Result := Copy(AOriginalCH);
  if Length(AOriginalCH) < 44 then Exit;

  // Skip handshake header (4) + version (2) + random (32) = 38
  LPos := 38;
  // session_id
  if LPos >= Length(AOriginalCH) then Exit;
  LSessionIdLen := AOriginalCH[LPos];
  Inc(LPos, 1 + LSessionIdLen);
  // cipher_suites
  if LPos + 2 > Length(AOriginalCH) then Exit;
  LCipherLen := (Integer(AOriginalCH[LPos]) shl 8) or Integer(AOriginalCH[LPos+1]);
  Inc(LPos, 2 + LCipherLen);
  // compression_methods
  if LPos >= Length(AOriginalCH) then Exit;
  LCompLen := AOriginalCH[LPos];
  Inc(LPos, 1 + LCompLen);
  // extensions_length
  if LPos + 2 > Length(AOriginalCH) then Exit;
  LExtListLen := (Integer(AOriginalCH[LPos]) shl 8) or Integer(AOriginalCH[LPos+1]);
  LExtStart := LPos + 2;

  // Scan extensions to find key_share (0x0033)
  LPos := LExtStart;
  while LPos + 4 <= LExtStart + LExtListLen do
  begin
    LExtType := (Integer(AOriginalCH[LPos]) shl 8) or Integer(AOriginalCH[LPos+1]);
    LExtLen := (Integer(AOriginalCH[LPos+2]) shl 8) or Integer(AOriginalCH[LPos+3]);

    if LExtType = $0033 then
    begin
      // Found key_share. Build replacement. perf: IBytesBuilder single alloc geometric; zero-copy BytesCopy; inline AppendUInt16BE
      LBuilder := CreateBytesBuilder(4 + Length(ANewKeyShare));
      LBuilder.AppendUInt16BE(ANewGroup);
      LBuilder.AppendUInt16BE(Word(Length(ANewKeyShare)));
      if Length(ANewKeyShare) > 0 then
        LBuilder.AppendSpan(TByteSpan.FromBytes(ANewKeyShare));
      LNewExtEntry := LBuilder.ToBytes;

      // Full extension: type(2) + length(2) + client_shares_length(2) + entry
      LBuilder := CreateBytesBuilder(6 + Length(LNewExtEntry));
      LBuilder.AppendUInt16BE($0033);
      LBuilder.AppendUInt16BE(Word(Length(LNewExtEntry) + 2));
      LBuilder.AppendUInt16BE(Word(Length(LNewExtEntry)));
      if Length(LNewExtEntry) > 0 then
        LBuilder.AppendSpan(TByteSpan.FromBytes(LNewExtEntry));
      LNewExt := LBuilder.ToBytes;

      // Splice: before + new_ext + after — perf: single SetLength + BytesCopy zero-copy single source (bytes.ops)
      LBefore := Copy(AOriginalCH, 0, LPos);
      LAfter := Copy(AOriginalCH, LPos + 4 + LExtLen, Length(AOriginalCH) - (LPos + 4 + LExtLen));

      SetLength(Result, Length(LBefore) + Length(LNewExt) + Length(LAfter));
      if Length(LBefore) > 0 then
        nextpas.core.bytes.ops.BytesCopy(@Result[0], @LBefore[0], SizeUInt(Length(LBefore)));
      if Length(LNewExt) > 0 then
        nextpas.core.bytes.ops.BytesCopy(@Result[Length(LBefore)], @LNewExt[0], SizeUInt(Length(LNewExt)));
      if Length(LAfter) > 0 then
        nextpas.core.bytes.ops.BytesCopy(@Result[Length(LBefore) + Length(LNewExt)], @LAfter[0], SizeUInt(Length(LAfter)));

      // Update extensions_length
      LExtListLen := LExtListLen - (4 + LExtLen) + Length(LNewExt);
      Result[LExtStart - 2] := Byte(LExtListLen shr 8);
      Result[LExtStart - 1] := Byte(LExtListLen);

      // Update handshake length (bytes 1-3)
      LPos := Length(Result) - 4;
      Result[1] := Byte(LPos shr 16);
      Result[2] := Byte(LPos shr 8);
      Result[3] := Byte(LPos);

      Exit;
    end;

    Inc(LPos, 4 + LExtLen);
  end;
end;

end.
