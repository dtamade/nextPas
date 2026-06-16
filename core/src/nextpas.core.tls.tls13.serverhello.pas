{**
 * Unit: nextpas.core.tls.tls13.serverhello
 * Purpose: TLS 1.3 ServerHello 构建器（纯 Pascal）
 *
 * 当前定位：
 * - 仅构建最小 TLS 1.3 ServerHello（supported_versions + key_share）
 * - 用于 FreePascal 后端服务端握手骨架
 *}

unit nextpas.core.tls.tls13.serverhello;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.base, nextpas.core.tls.tls13.wire;

function BuildTLS13ServerHelloHandshake(
  const ALegacySessionID: TBytes;
  ACipherSuite: Word;
  const AServerKeyShare: TBytes;
  AKeyShareGroup: Word = TLS13_GROUP_X25519
): TBytes;
function BuildTLS13ServerHelloHandshakeWithSelectedPSK(
  const ALegacySessionID: TBytes;
  ACipherSuite: Word;
  const AServerKeyShare: TBytes;
  ASelectedIdentity: Word;
  AKeyShareGroup: Word = TLS13_GROUP_X25519
): TBytes;

function BuildTLS13ServerHelloRecord(
  const ALegacySessionID: TBytes;
  ACipherSuite: Word;
  const AServerKeyShare: TBytes;
  AKeyShareGroup: Word = TLS13_GROUP_X25519
): TBytes;
function BuildTLS13ServerHelloRecordWithSelectedPSK(
  const ALegacySessionID: TBytes;
  ACipherSuite: Word;
  const AServerKeyShare: TBytes;
  ASelectedIdentity: Word;
  AKeyShareGroup: Word = TLS13_GROUP_X25519
): TBytes;

implementation


function BuildExtensionHeader(AType: Word; const AData: TBytes): TBytes;
begin
  Result := nil;
  AppendUInt16(Result, AType);
  AppendUInt16(Result, Word(Length(AData)));
  AppendBytes(Result, AData);
end;

function BuildExtensionSupportedVersions: TBytes;
var
  LData: TBytes;
begin
  SetLength(LData, 0);
  AppendUInt16(LData, TLS13_VERSION);
  Result := BuildExtensionHeader(TLS_EXTENSION_SUPPORTED_VERSIONS, LData);
end;

function BuildExtensionKeyShare(AKeyShareGroup: Word; const AServerKeyShare: TBytes): TBytes;
var
  LData: TBytes;
begin
  if Length(AServerKeyShare) = 0 then
    RaiseInvalidParameter('ServerKeyShare');

  SetLength(LData, 0);
  AppendUInt16(LData, AKeyShareGroup);
  AppendUInt16(LData, Word(Length(AServerKeyShare)));
  AppendBytes(LData, AServerKeyShare);

  Result := BuildExtensionHeader(TLS_EXTENSION_KEY_SHARE, LData);
end;

function BuildExtensionPreSharedKeySelection(ASelectedIdentity: Word): TBytes;
var
  LData: TBytes;
begin
  SetLength(LData, 0);
  AppendUInt16(LData, ASelectedIdentity);
  Result := BuildExtensionHeader(TLS_EXTENSION_PRE_SHARED_KEY, LData);
end;

function BuildTLS13ServerHelloBody(
  const ALegacySessionID: TBytes;
  ACipherSuite: Word;
  const AServerKeyShare: TBytes;
  AKeyShareGroup: Word;
  AIncludeSelectedPSK: Boolean;
  ASelectedIdentity: Word
): TBytes;
var
  LRandom: TBytes;
  LExtensions: TBytes;
  LExtension: TBytes;
begin
  Result := nil;

  if Length(ALegacySessionID) > 32 then
    RaiseInvalidParameter('LegacySessionIDLength');

  case ACipherSuite of
    TLS13_CIPHER_AES_128_GCM_SHA256,
    TLS13_CIPHER_AES_256_GCM_SHA384,
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256:
      ;
  else
    RaiseInvalidParameter('TLS13ServerHelloCipherSuite');
  end;

  LRandom := GenerateSecureRandomBytes(32);

  SetLength(LExtensions, 0);
  LExtension := BuildExtensionSupportedVersions;
  AppendBytes(LExtensions, LExtension);

  LExtension := BuildExtensionKeyShare(AKeyShareGroup, AServerKeyShare);
  AppendBytes(LExtensions, LExtension);

  if AIncludeSelectedPSK then
  begin
    LExtension := BuildExtensionPreSharedKeySelection(ASelectedIdentity);
    AppendBytes(LExtensions, LExtension);
  end;

  Result := nil;
  AppendUInt16(Result, TLS_LEGACY_VERSION);
  AppendBytes(Result, LRandom);
  AppendByte(Result, Byte(Length(ALegacySessionID)));
  AppendBytes(Result, ALegacySessionID);
  AppendUInt16(Result, ACipherSuite);
  AppendByte(Result, 0);
  AppendUInt16(Result, Word(Length(LExtensions)));
  AppendBytes(Result, LExtensions);
end;

function BuildTLS13ServerHelloHandshake(
  const ALegacySessionID: TBytes;
  ACipherSuite: Word;
  const AServerKeyShare: TBytes;
  AKeyShareGroup: Word
): TBytes;
var
  LBody: TBytes;
begin
  Result := nil;
  LBody := BuildTLS13ServerHelloBody(
    ALegacySessionID,
    ACipherSuite,
    AServerKeyShare,
    AKeyShareGroup,
    False,
    0
  );

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_SERVER_HELLO);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

function BuildTLS13ServerHelloHandshakeWithSelectedPSK(
  const ALegacySessionID: TBytes;
  ACipherSuite: Word;
  const AServerKeyShare: TBytes;
  ASelectedIdentity: Word;
  AKeyShareGroup: Word
): TBytes;
var
  LBody: TBytes;
begin
  Result := nil;
  LBody := BuildTLS13ServerHelloBody(
    ALegacySessionID,
    ACipherSuite,
    AServerKeyShare,
    AKeyShareGroup,
    True,
    ASelectedIdentity
  );

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_SERVER_HELLO);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

function BuildTLS13ServerHelloRecord(
  const ALegacySessionID: TBytes;
  ACipherSuite: Word;
  const AServerKeyShare: TBytes;
  AKeyShareGroup: Word
): TBytes;
var
  LHandshake: TBytes;
begin
  LHandshake := BuildTLS13ServerHelloHandshake(
    ALegacySessionID,
    ACipherSuite,
    AServerKeyShare,
    AKeyShareGroup
  );
  Result := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, LHandshake);
end;

function BuildTLS13ServerHelloRecordWithSelectedPSK(
  const ALegacySessionID: TBytes;
  ACipherSuite: Word;
  const AServerKeyShare: TBytes;
  ASelectedIdentity: Word;
  AKeyShareGroup: Word
): TBytes;
var
  LHandshake: TBytes;
begin
  LHandshake := BuildTLS13ServerHelloHandshakeWithSelectedPSK(
    ALegacySessionID,
    ACipherSuite,
    AServerKeyShare,
    ASelectedIdentity,
    AKeyShareGroup
  );
  Result := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, LHandshake);
end;

end.
