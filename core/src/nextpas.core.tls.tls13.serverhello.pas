{**
 * Unit: nextpas.core.tls.tls13.serverhello
 * Purpose: TLS 1.3 ServerHello 构建器（纯 Pascal）
 *
 * 当前定位：
 * - 仅构建最小 TLS 1.3 ServerHello（supported_versions + key_share）
 * - 用于 FreePascal 后端服务端握手骨架
}

unit nextpas.core.tls.tls13.serverhello;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.tls.tls13.wire;

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

uses
  nextpas.core.bytes.base,
  nextpas.core.bytes.builder,
  nextpas.core.tls.errors,
  nextpas.core.tls.random;

function BuildExtensionHeader(AType: Word; const AData: TBytes): TBytes;
var
  LBuilder: IBytesBuilder;
begin
  // perf: IBytesBuilder geometric 0→64→2× single source via bytes.ops.capacity (INV-5), zero-copy BytesCopy, inline AppendUInt16BE single Move
  LBuilder := CreateBytesBuilder(4 + Length(AData));
  LBuilder.AppendUInt16BE(AType);
  LBuilder.AppendUInt16BE(Word(Length(AData)));
  if Length(AData) > 0 then
    LBuilder.AppendSpan(TByteSpan.FromBytes(AData));
  Result := LBuilder.ToBytes;
end;

function BuildExtensionSupportedVersions: TBytes;
var
  LBuilder: IBytesBuilder;
  LData: TBytes;
begin
  // perf: small single alloc via builder, inline AppendUInt16BE zero-copy
  LBuilder := CreateBytesBuilder(2);
  LBuilder.AppendUInt16BE(TLS13_VERSION);
  LData := LBuilder.ToBytes;
  Result := BuildExtensionHeader(TLS_EXTENSION_SUPPORTED_VERSIONS, LData);
end;

function BuildExtensionKeyShare(AKeyShareGroup: Word; const AServerKeyShare: TBytes): TBytes;
var
  LBuilder: IBytesBuilder;
  LData: TBytes;
begin
  if Length(AServerKeyShare) = 0 then
    RaiseInvalidParameter('ServerKeyShare');

  // perf: IBytesBuilder single alloc geometric, zero-copy BytesCopy, inline AppendUInt16BE
  LBuilder := CreateBytesBuilder(4 + Length(AServerKeyShare));
  LBuilder.AppendUInt16BE(AKeyShareGroup);
  LBuilder.AppendUInt16BE(Word(Length(AServerKeyShare)));
  if Length(AServerKeyShare) > 0 then
    LBuilder.AppendSpan(TByteSpan.FromBytes(AServerKeyShare));
  LData := LBuilder.ToBytes;
  Result := BuildExtensionHeader(TLS_EXTENSION_KEY_SHARE, LData);
end;

function BuildExtensionPreSharedKeySelection(ASelectedIdentity: Word): TBytes;
var
  LBuilder: IBytesBuilder;
  LData: TBytes;
begin
  // perf: IBytesBuilder single alloc, inline AppendUInt16BE
  LBuilder := CreateBytesBuilder(2);
  LBuilder.AppendUInt16BE(ASelectedIdentity);
  LData := LBuilder.ToBytes;
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
  LExtBuilder: IBytesBuilder;
  LBodyBuilder: IBytesBuilder;
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

  // perf: IBytesBuilder geometric 0→64→2× single source via bytes.ops.capacity (INV-5), avoid O(n²) BytesAppend SetLength+Move per call; single Grow + ToBytes copy, zero-copy BytesCopy, inline Append*
  LExtBuilder := CreateBytesBuilder(64 + Length(AServerKeyShare));
  LExtension := BuildExtensionSupportedVersions;
  if Length(LExtension) > 0 then
    LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExtension));

  LExtension := BuildExtensionKeyShare(AKeyShareGroup, AServerKeyShare);
  if Length(LExtension) > 0 then
    LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExtension));

  if AIncludeSelectedPSK then
  begin
    LExtension := BuildExtensionPreSharedKeySelection(ASelectedIdentity);
    if Length(LExtension) > 0 then
      LExtBuilder.AppendSpan(TByteSpan.FromBytes(LExtension));
  end;
  LExtensions := LExtBuilder.ToBytes;

  // perf: final body via builder preallocated instead of repeated BytesAppend O(n²); zero-copy span, single ToBytes
  LBodyBuilder := CreateBytesBuilder(2 + Length(LRandom) + 1 + Length(ALegacySessionID) + 2 + 1 + 2 + Length(LExtensions));
  LBodyBuilder.AppendUInt16BE(TLS_LEGACY_VERSION);
  if Length(LRandom) > 0 then
    LBodyBuilder.AppendSpan(TByteSpan.FromBytes(LRandom));
  LBodyBuilder.AppendByte(Byte(Length(ALegacySessionID)));
  if Length(ALegacySessionID) > 0 then
    LBodyBuilder.AppendSpan(TByteSpan.FromBytes(ALegacySessionID));
  LBodyBuilder.AppendUInt16BE(ACipherSuite);
  { legacy_compression_method：单字节恒 0。向量式 legacy_compression_methods
    只存在于 ClientHello（RFC 8446 §4.1.2）；ServerHello 无长度前缀
    （§4.1.3），多写一字节会使对端按 ext_len=0 解析而报 bad length。 }
  LBodyBuilder.AppendByte(0);
  LBodyBuilder.AppendUInt16BE(Word(Length(LExtensions)));
  if Length(LExtensions) > 0 then
    LBodyBuilder.AppendSpan(TByteSpan.FromBytes(LExtensions));
  Result := LBodyBuilder.ToBytes;
end;

function BuildTLS13ServerHelloHandshake(
  const ALegacySessionID: TBytes;
  ACipherSuite: Word;
  const AServerKeyShare: TBytes;
  AKeyShareGroup: Word
): TBytes;
var
  LBody: TBytes;
  LBuilder: IBytesBuilder;
begin
  LBody := BuildTLS13ServerHelloBody(
    ALegacySessionID,
    ACipherSuite,
    AServerKeyShare,
    AKeyShareGroup,
    False,
    0
  );

  // perf: IBytesBuilder single alloc geometric 0→64→2×, zero-copy BytesCopy, inline AppendByte
  LBuilder := CreateBytesBuilder(4 + Length(LBody));
  LBuilder.AppendByte(TLS_HANDSHAKE_TYPE_SERVER_HELLO);
  LBuilder.AppendByte(Byte(Length(LBody) shr 16));
  LBuilder.AppendByte(Byte(Length(LBody) shr 8));
  LBuilder.AppendByte(Byte(Length(LBody)));
  if Length(LBody) > 0 then
    LBuilder.AppendSpan(TByteSpan.FromBytes(LBody));
  Result := LBuilder.ToBytes;
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
  LBuilder: IBytesBuilder;
begin
  LBody := BuildTLS13ServerHelloBody(
    ALegacySessionID,
    ACipherSuite,
    AServerKeyShare,
    AKeyShareGroup,
    True,
    ASelectedIdentity
  );

  // perf: IBytesBuilder single alloc geometric 0→64→2×, zero-copy BytesCopy, inline AppendByte
  LBuilder := CreateBytesBuilder(4 + Length(LBody));
  LBuilder.AppendByte(TLS_HANDSHAKE_TYPE_SERVER_HELLO);
  LBuilder.AppendByte(Byte(Length(LBody) shr 16));
  LBuilder.AppendByte(Byte(Length(LBody) shr 8));
  LBuilder.AppendByte(Byte(Length(LBody)));
  if Length(LBody) > 0 then
    LBuilder.AppendSpan(TByteSpan.FromBytes(LBody));
  Result := LBuilder.ToBytes;
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
