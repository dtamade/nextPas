{**
 * Unit: nextpas.core.tls.tls13.clienthello
 * Purpose: TLS 1.3 ClientHello 构建器（纯 Pascal）
 *}

unit nextpas.core.tls.tls13.clienthello;

{$mode ObjFPC}{$H+}

interface

uses
  
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
  AIncludeSignedCertificateTimestamp: Boolean = False
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
  nextpas.core.tls.tls13.wire;

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
    Move(AValue[1], Result[0], Length(AValue));
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
begin
  Result := nil;
  LCount := 0;
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
      SetLength(Result, LCount + 1);
      Result[LCount] := AnsiString(LValue);
      Inc(LCount);
    end;

    LStart := I + 1;
  end;
end;

function BuildExtensionHeader(AType: Word; const AData: TBytes): TBytes;
begin
  Result := nil;
  AppendUInt16(Result, AType);
  AppendUInt16(Result, Word(Length(AData)));
  AppendBytes(Result, AData);
end;

function BuildExtensionServerName(const AServerName: string): TBytes;
var
  LHostBytes: TBytes;
  LListData: TBytes;
begin
  if AServerName = '' then
  begin
    Result := nil;
    Exit;
  end;

  LHostBytes := BytesFromAnsi(AnsiString(AServerName));
  SetLength(LListData, 0);
  AppendByte(LListData, 0); // host_name
  AppendUInt16(LListData, Word(Length(LHostBytes)));
  AppendBytes(LListData, LHostBytes);

  Result := nil;
  AppendUInt16(Result, Word(Length(LListData)));
  AppendBytes(Result, LListData);

  Result := BuildExtensionHeader(TLS_EXTENSION_SERVER_NAME, Result);
end;

function BuildExtensionALPN(const AALPNProtocols: string): TBytes;
var
  LProtocols: TALPNProtocolArray;
  LListData, LProtoBytes: TBytes;
  I: Integer;
begin
  LProtocols := ParseALPNList(AALPNProtocols);
  if Length(LProtocols) = 0 then
  begin
    Result := nil;
    Exit;
  end;

  SetLength(LListData, 0);
  for I := 0 to High(LProtocols) do
  begin
    LProtoBytes := BytesFromAnsi(LProtocols[I]);
    if Length(LProtoBytes) > 255 then
      RaiseInvalidParameter('ALPNProtocolLength');

    AppendByte(LListData, Byte(Length(LProtoBytes)));
    AppendBytes(LListData, LProtoBytes);
  end;

  Result := nil;
  AppendUInt16(Result, Word(Length(LListData)));
  AppendBytes(Result, LListData);

  Result := BuildExtensionHeader(TLS_EXTENSION_ALPN, Result);
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
  LEntry, LData: TBytes;
  LGroup: Word;
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

  SetLength(LEntry, 0);
  AppendUInt16(LEntry, LGroup);
  AppendUInt16(LEntry, Word(Length(AKeyShare)));
  AppendBytes(LEntry, AKeyShare);

  SetLength(LData, 0);
  AppendUInt16(LData, Word(Length(LEntry)));
  AppendBytes(LData, LEntry);

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
  LIdentityEntry: TBytes;
  LIdentities: TBytes;
  LBinders: TBytes;
  LData: TBytes;
begin
  if not APSKOffer.Valid then
  begin
    Result := nil;
    Exit;
  end;

  SetLength(LIdentityEntry, 0);
  AppendUInt16(LIdentityEntry, Word(Length(APSKOffer.Identity)));
  AppendBytes(LIdentityEntry, APSKOffer.Identity);
  AppendUInt32(LIdentityEntry, APSKOffer.ObfuscatedTicketAge);

  SetLength(LIdentities, 0);
  AppendUInt16(LIdentities, Word(Length(LIdentityEntry)));
  AppendBytes(LIdentities, LIdentityEntry);

  SetLength(LBinders, 0);
  AppendByte(LBinders, Byte(Length(ABinder)));
  AppendBytes(LBinders, ABinder);
  LData := nil;
  SetLength(LData, 0);
  AppendUInt16(LData, Word(Length(LBinders)));
  AppendBytes(LData, LBinders);

  Result := nil;
  AppendBytes(Result, LIdentities);
  AppendBytes(Result, LData);

  Result := BuildExtensionHeader(TLS_EXTENSION_PRE_SHARED_KEY, Result);
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
begin
  LRandom := GenerateSecureRandomBytes(32);
  LSessionId := GenerateSecureRandomBytes(32);

  SetLength(LCipherSuites, 0);
  AppendDefaultTLS13CipherSuites(LCipherSuites);

  SetLength(LCompressionMethods, 0);
  AppendByte(LCompressionMethods, 1);
  AppendByte(LCompressionMethods, 0);

  SetLength(LExtensions, 0);

  // Extension order matches common browser fingerprints for CDN compatibility
  LExt := BuildExtensionServerName(AServerName);
  AppendBytes(LExtensions, LExt);

  // extended_master_secret (RFC 7627)
  AppendUInt16(LExtensions, TLS_EXTENSION_EXTENDED_MASTER_SECRET);
  AppendUInt16(LExtensions, 0);

  // renegotiation_info: empty (RFC 5746)
  AppendUInt16(LExtensions, TLS_EXTENSION_RENEGOTIATION_INFO);
  AppendUInt16(LExtensions, 1);
  AppendByte(LExtensions, 0);

  LExt := BuildExtensionSupportedGroups;
  AppendBytes(LExtensions, LExt);

  // ec_point_formats: uncompressed only
  AppendUInt16(LExtensions, TLS_EXTENSION_EC_POINT_FORMATS);
  AppendUInt16(LExtensions, 2);
  AppendByte(LExtensions, 1);
  AppendByte(LExtensions, 0);

  // session_ticket (empty = willing to receive)
  LExt := BuildExtensionSessionTicket;
  AppendBytes(LExtensions, LExt);

  LExt := BuildExtensionALPN(AALPNProtocols);
  AppendBytes(LExtensions, LExt);

  if AIncludeStatusRequest then
  begin
    LExt := BuildExtensionStatusRequest;
    AppendBytes(LExtensions, LExt);
  end;

  if AIncludeSignedCertificateTimestamp then
  begin
    LExt := BuildExtensionSignedCertificateTimestamp;
    AppendBytes(LExtensions, LExt);
  end;

  LExt := BuildExtensionSignatureAlgorithms;
  AppendBytes(LExtensions, LExt);

  LExt := BuildExtensionRecordSizeLimit(TLS13_RECORD_SIZE_LIMIT_DEFAULT);
  AppendBytes(LExtensions, LExt);

  LExt := BuildExtensionSupportedVersions;
  AppendBytes(LExtensions, LExt);

  LExt := BuildExtensionPSKKeyExchangeModes;
  AppendBytes(LExtensions, LExt);

  LExt := BuildExtensionKeyShare(AKeyShare);
  AppendBytes(LExtensions, LExt);

  // Calculate total ClientHello size to determine padding need
  // header(4) + version(2) + random(32) + session_id_len(1) + session_id(32) +
  // cipher_suites_len(2) + cipher_suites + comp_len + extensions_len(2) + extensions
  LBodyLen := 2 + 32 + 1 + 32 + 2 + Length(LCipherSuites) + Length(LCompressionMethods) + 2 + Length(LExtensions);
  if LBodyLen + 4 < 512 then
  begin
    LExt := BuildExtensionPadding(512, LBodyLen + 4);
    AppendBytes(LExtensions, LExt);
  end;

  Result := nil;
  AppendUInt16(Result, TLS_LEGACY_VERSION);
  AppendBytes(Result, LRandom);
  AppendByte(Result, Byte(Length(LSessionId)));
  AppendBytes(Result, LSessionId);
  AppendUInt16(Result, Word(Length(LCipherSuites)));
  AppendBytes(Result, LCipherSuites);
  AppendBytes(Result, LCompressionMethods);
  AppendUInt16(Result, Word(Length(LExtensions)));
  AppendBytes(Result, LExtensions);
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
begin
  SetLength(LCipherSuites, 0);
  AppendDefaultTLS13CipherSuites(LCipherSuites);

  SetLength(LCompressionMethods, 0);
  AppendByte(LCompressionMethods, 1);
  AppendByte(LCompressionMethods, 0);

  SetLength(LBaseExtensions, 0);

  LExt := BuildExtensionServerName(AServerName);
  AppendBytes(LBaseExtensions, LExt);

  // extended_master_secret (RFC 7627)
  AppendUInt16(LBaseExtensions, TLS_EXTENSION_EXTENDED_MASTER_SECRET);
  AppendUInt16(LBaseExtensions, 0);

  // renegotiation_info: empty (RFC 5746)
  AppendUInt16(LBaseExtensions, TLS_EXTENSION_RENEGOTIATION_INFO);
  AppendUInt16(LBaseExtensions, 1);
  AppendByte(LBaseExtensions, 0);

  LExt := BuildExtensionSupportedGroups;
  AppendBytes(LBaseExtensions, LExt);

  // ec_point_formats: uncompressed only
  AppendUInt16(LBaseExtensions, TLS_EXTENSION_EC_POINT_FORMATS);
  AppendUInt16(LBaseExtensions, 2);
  AppendByte(LBaseExtensions, 1);
  AppendByte(LBaseExtensions, 0);

  // session_ticket
  LExt := BuildExtensionSessionTicket;
  AppendBytes(LBaseExtensions, LExt);

  LExt := BuildExtensionALPN(AALPNProtocols);
  AppendBytes(LBaseExtensions, LExt);

  if AIncludeStatusRequest then
  begin
    LExt := BuildExtensionStatusRequest;
    AppendBytes(LBaseExtensions, LExt);
  end;

  if AIncludeSignedCertificateTimestamp then
  begin
    LExt := BuildExtensionSignedCertificateTimestamp;
    AppendBytes(LBaseExtensions, LExt);
  end;

  LExt := BuildExtensionSignatureAlgorithms;
  AppendBytes(LBaseExtensions, LExt);

  LExt := BuildExtensionRecordSizeLimit(TLS13_RECORD_SIZE_LIMIT_DEFAULT);
  AppendBytes(LBaseExtensions, LExt);

  LExt := BuildExtensionSupportedVersions;
  AppendBytes(LBaseExtensions, LExt);

  LExt := BuildExtensionPSKKeyExchangeModes;
  AppendBytes(LBaseExtensions, LExt);

  LExt := BuildExtensionKeyShare(AKeyShare);
  AppendBytes(LBaseExtensions, LExt);

  if APSKOffer.Valid and APSKOffer.AllowEarlyData then
  begin
    LExt := BuildExtensionEarlyData;
    AppendBytes(LBaseExtensions, LExt);
  end;

  SetLength(APartialBody, 0);
  AppendUInt16(APartialBody, TLS_LEGACY_VERSION);
  AppendBytes(APartialBody, ARandom);
  AppendByte(APartialBody, Byte(Length(ASessionId)));
  AppendBytes(APartialBody, ASessionId);
  AppendUInt16(APartialBody, Word(Length(LCipherSuites)));
  AppendBytes(APartialBody, LCipherSuites);
  AppendBytes(APartialBody, LCompressionMethods);

  if APSKOffer.Valid then
  begin
    SetLength(LZeroBinder, Length(APSKOffer.Binder));
    if Length(LZeroBinder) > 0 then
      FillChar(LZeroBinder[0], Length(LZeroBinder), 0);
    LPartialPSKExtension := BuildExtensionPreSharedKey(APSKOffer, LZeroBinder);
    LFinalPSKExtension := BuildExtensionPreSharedKey(APSKOffer, APSKOffer.Binder);

    AppendUInt16(APartialBody, Word(Length(LBaseExtensions) + Length(LPartialPSKExtension)));
    AppendBytes(APartialBody, LBaseExtensions);
    AppendBytes(APartialBody, LPartialPSKExtension);

    Result := nil;
    AppendUInt16(Result, TLS_LEGACY_VERSION);
    AppendBytes(Result, ARandom);
    AppendByte(Result, Byte(Length(ASessionId)));
    AppendBytes(Result, ASessionId);
    AppendUInt16(Result, Word(Length(LCipherSuites)));
    AppendBytes(Result, LCipherSuites);
    AppendBytes(Result, LCompressionMethods);
    AppendUInt16(Result, Word(Length(LBaseExtensions) + Length(LFinalPSKExtension)));
    AppendBytes(Result, LBaseExtensions);
    AppendBytes(Result, LFinalPSKExtension);
    Exit;
  end;

  AppendUInt16(APartialBody, Word(Length(LBaseExtensions)));
  AppendBytes(APartialBody, LBaseExtensions);
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
begin
  LBody := BuildTLS13ClientHelloBody(
    AServerName,
    AALPNProtocols,
    AKeyShare,
    AIncludeStatusRequest,
    AIncludeSignedCertificateTimestamp
  );

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
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

  SetLength(APartialHandshake, 0);
  AppendByte(APartialHandshake, TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  AppendUInt24(APartialHandshake, Length(LPartialBody));
  AppendBytes(APartialHandshake, LPartialBody);

  { RFC 8446 Section 4.2.11.2: truncate partial handshake to exclude binders
    (binders_length field + binder entries). OpenSSL hashes up to but NOT
    including the 2-byte binders_length field. }
  if APSKOffer.Valid and (Length(APSKOffer.Binder) > 0) then
    SetLength(APartialHandshake, Length(APartialHandshake) - (2 + 1 + Length(APSKOffer.Binder)));

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
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

  SetLength(APartialHandshake, 0);
  AppendByte(APartialHandshake, TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  AppendUInt24(APartialHandshake, Length(LPartialBody));
  AppendBytes(APartialHandshake, LPartialBody);


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

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
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
  AIncludeSignedCertificateTimestamp: Boolean
): TBytes;
var
  LRandom, LSessionId: TBytes;
  LCipherSuites: TBytes;
  LCompressionMethods: TBytes;
  LExtensions: TBytes;
  LExt: TBytes;
  LBodyLen: Integer;
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

  SetLength(LExtensions, 0);

  LExt := BuildExtensionServerName(AServerName);
  AppendBytes(LExtensions, LExt);

  // extended_master_secret (RFC 7627)
  AppendUInt16(LExtensions, TLS_EXTENSION_EXTENDED_MASTER_SECRET);
  AppendUInt16(LExtensions, 0);

  // renegotiation_info: empty (RFC 5746)
  AppendUInt16(LExtensions, TLS_EXTENSION_RENEGOTIATION_INFO);
  AppendUInt16(LExtensions, 1);
  AppendByte(LExtensions, 0);

  LExt := BuildExtensionSupportedGroups;
  AppendBytes(LExtensions, LExt);

  // ec_point_formats: uncompressed only
  AppendUInt16(LExtensions, TLS_EXTENSION_EC_POINT_FORMATS);
  AppendUInt16(LExtensions, 2);
  AppendByte(LExtensions, 1);
  AppendByte(LExtensions, 0);

  // session_ticket (empty = willing to receive)
  LExt := BuildExtensionSessionTicket;
  AppendBytes(LExtensions, LExt);

  LExt := BuildExtensionALPN(AALPNProtocols);
  AppendBytes(LExtensions, LExt);

  if AIncludeStatusRequest then
  begin
    LExt := BuildExtensionStatusRequest;
    AppendBytes(LExtensions, LExt);
  end;

  if AIncludeSignedCertificateTimestamp then
  begin
    LExt := BuildExtensionSignedCertificateTimestamp;
    AppendBytes(LExtensions, LExt);
  end;

  LExt := BuildExtensionSignatureAlgorithms;
  AppendBytes(LExtensions, LExt);

  LExt := BuildExtensionRecordSizeLimit(TLS13_RECORD_SIZE_LIMIT_DEFAULT);
  AppendBytes(LExtensions, LExt);

  LExt := BuildExtensionSupportedVersions;
  AppendBytes(LExtensions, LExt);

  LExt := BuildExtensionPSKKeyExchangeModes;
  AppendBytes(LExtensions, LExt);

  LExt := BuildExtensionKeyShare(AKeyShare);
  AppendBytes(LExtensions, LExt);

  LBodyLen := 2 + 32 + 1 + 32 + 2 + Length(LCipherSuites) + Length(LCompressionMethods) + 2 + Length(LExtensions);
  if LBodyLen + 4 < 512 then
  begin
    LExt := BuildExtensionPadding(512, LBodyLen + 4);
    AppendBytes(LExtensions, LExt);
  end;

  Result := nil;
  AppendUInt16(Result, TLS_LEGACY_VERSION);
  AppendBytes(Result, LRandom);
  AppendByte(Result, Byte(Length(LSessionId)));
  AppendBytes(Result, LSessionId);
  AppendUInt16(Result, Word(Length(LCipherSuites)));
  AppendBytes(Result, LCipherSuites);
  AppendBytes(Result, LCompressionMethods);
  AppendUInt16(Result, Word(Length(LExtensions)));
  AppendBytes(Result, LExtensions);
end;

function BuildTLS13ClientHelloHandshakeWithCiphers(
  const AServerName: string;
  const AALPNProtocols: string;
  const AKeyShare: TBytes;
  const ACipherSuites: TTLS13CipherSuiteList;
  AIncludeStatusRequest: Boolean;
  AIncludeSignedCertificateTimestamp: Boolean
): TBytes;
var
  LBody: TBytes;
begin
  LBody := BuildTLS13ClientHelloBodyWithCiphers(
    AServerName,
    AALPNProtocols,
    AKeyShare,
    ACipherSuites,
    AIncludeStatusRequest,
    AIncludeSignedCertificateTimestamp
  );

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
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
begin
  SetLength(LCipherSuites, 0);
  if Length(ACipherSuites) > 0 then
    AppendTLS13CipherSuites(LCipherSuites, ACipherSuites)
  else
    AppendDefaultTLS13CipherSuites(LCipherSuites);

  SetLength(LCompressionMethods, 0);
  AppendByte(LCompressionMethods, 1);
  AppendByte(LCompressionMethods, 0);

  SetLength(LBaseExtensions, 0);

  LExt := BuildExtensionServerName(AServerName);
  AppendBytes(LBaseExtensions, LExt);

  // extended_master_secret (RFC 7627)
  AppendUInt16(LBaseExtensions, TLS_EXTENSION_EXTENDED_MASTER_SECRET);
  AppendUInt16(LBaseExtensions, 0);

  // renegotiation_info: empty (RFC 5746)
  AppendUInt16(LBaseExtensions, TLS_EXTENSION_RENEGOTIATION_INFO);
  AppendUInt16(LBaseExtensions, 1);
  AppendByte(LBaseExtensions, 0);

  LExt := BuildExtensionSupportedGroups;
  AppendBytes(LBaseExtensions, LExt);

  // ec_point_formats: uncompressed only
  AppendUInt16(LBaseExtensions, TLS_EXTENSION_EC_POINT_FORMATS);
  AppendUInt16(LBaseExtensions, 2);
  AppendByte(LBaseExtensions, 1);
  AppendByte(LBaseExtensions, 0);

  // session_ticket
  LExt := BuildExtensionSessionTicket;
  AppendBytes(LBaseExtensions, LExt);

  LExt := BuildExtensionALPN(AALPNProtocols);
  AppendBytes(LBaseExtensions, LExt);

  if AIncludeStatusRequest then
  begin
    LExt := BuildExtensionStatusRequest;
    AppendBytes(LBaseExtensions, LExt);
  end;

  if AIncludeSignedCertificateTimestamp then
  begin
    LExt := BuildExtensionSignedCertificateTimestamp;
    AppendBytes(LBaseExtensions, LExt);
  end;

  LExt := BuildExtensionSignatureAlgorithms;
  AppendBytes(LBaseExtensions, LExt);

  LExt := BuildExtensionRecordSizeLimit(TLS13_RECORD_SIZE_LIMIT_DEFAULT);
  AppendBytes(LBaseExtensions, LExt);

  LExt := BuildExtensionSupportedVersions;
  AppendBytes(LBaseExtensions, LExt);

  LExt := BuildExtensionPSKKeyExchangeModes;
  AppendBytes(LBaseExtensions, LExt);

  LExt := BuildExtensionKeyShare(AKeyShare);
  AppendBytes(LBaseExtensions, LExt);

  if APSKOffer.Valid and APSKOffer.AllowEarlyData then
  begin
    LExt := BuildExtensionEarlyData;
    AppendBytes(LBaseExtensions, LExt);
  end;

  SetLength(APartialBody, 0);
  AppendUInt16(APartialBody, TLS_LEGACY_VERSION);
  AppendBytes(APartialBody, ARandom);
  AppendByte(APartialBody, Byte(Length(ASessionId)));
  AppendBytes(APartialBody, ASessionId);
  AppendUInt16(APartialBody, Word(Length(LCipherSuites)));
  AppendBytes(APartialBody, LCipherSuites);
  AppendBytes(APartialBody, LCompressionMethods);

  if APSKOffer.Valid then
  begin
    SetLength(LZeroBinder, Length(APSKOffer.Binder));
    if Length(LZeroBinder) > 0 then
      FillChar(LZeroBinder[0], Length(LZeroBinder), 0);
    LPartialPSKExtension := BuildExtensionPreSharedKey(APSKOffer, LZeroBinder);
    LFinalPSKExtension := BuildExtensionPreSharedKey(APSKOffer, APSKOffer.Binder);

    AppendUInt16(APartialBody, Word(Length(LBaseExtensions) + Length(LPartialPSKExtension)));
    AppendBytes(APartialBody, LBaseExtensions);
    AppendBytes(APartialBody, LPartialPSKExtension);

    Result := nil;
    AppendUInt16(Result, TLS_LEGACY_VERSION);
    AppendBytes(Result, ARandom);
    AppendByte(Result, Byte(Length(ASessionId)));
    AppendBytes(Result, ASessionId);
    AppendUInt16(Result, Word(Length(LCipherSuites)));
    AppendBytes(Result, LCipherSuites);
    AppendBytes(Result, LCompressionMethods);
    AppendUInt16(Result, Word(Length(LBaseExtensions) + Length(LFinalPSKExtension)));
    AppendBytes(Result, LBaseExtensions);
    AppendBytes(Result, LFinalPSKExtension);
    Exit;
  end;

  AppendUInt16(APartialBody, Word(Length(LBaseExtensions)));
  AppendBytes(APartialBody, LBaseExtensions);
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

  SetLength(APartialHandshake, 0);
  AppendByte(APartialHandshake, TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  AppendUInt24(APartialHandshake, Length(LPartialBody));
  AppendBytes(APartialHandshake, LPartialBody);

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

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
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
      // Found key_share. Build replacement.
      // key_share_entry: group(2) + key_length(2) + key
      SetLength(LNewExtEntry, 0);
      AppendUInt16(LNewExtEntry, ANewGroup);
      AppendUInt16(LNewExtEntry, Word(Length(ANewKeyShare)));
      AppendBytes(LNewExtEntry, ANewKeyShare);

      // Full extension: type(2) + length(2) + client_shares_length(2) + entry
      SetLength(LNewExt, 0);
      AppendUInt16(LNewExt, $0033);
      AppendUInt16(LNewExt, Word(Length(LNewExtEntry) + 2));
      AppendUInt16(LNewExt, Word(Length(LNewExtEntry)));
      AppendBytes(LNewExt, LNewExtEntry);

      // Splice: before + new_ext + after
      LBefore := Copy(AOriginalCH, 0, LPos);
      LAfter := Copy(AOriginalCH, LPos + 4 + LExtLen, Length(AOriginalCH) - (LPos + 4 + LExtLen));

      SetLength(Result, Length(LBefore) + Length(LNewExt) + Length(LAfter));
      Move(LBefore[0], Result[0], Length(LBefore));
      Move(LNewExt[0], Result[Length(LBefore)], Length(LNewExt));
      Move(LAfter[0], Result[Length(LBefore) + Length(LNewExt)], Length(LAfter));

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
