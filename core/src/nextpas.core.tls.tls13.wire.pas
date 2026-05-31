{**
 * Unit: nextpas.core.tls.tls13.wire
 * Purpose: TLS 1.3 线协议编码/解码基础工具
 *
 * 纯 Pascal 实现，不依赖任何外部 TLS 库。
 *}

unit nextpas.core.tls.tls13.wire;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils,
  nextpas.core.tls.errors;

const
  TLS_CONTENT_TYPE_CHANGE_CIPHER_SPEC = 20;
  TLS_CONTENT_TYPE_ALERT = 21;
  TLS_CONTENT_TYPE_HANDSHAKE = 22;
  TLS_CONTENT_TYPE_APPLICATION_DATA = 23;

  TLS_HANDSHAKE_TYPE_CLIENT_HELLO = 1;
  TLS_HANDSHAKE_TYPE_SERVER_HELLO = 2;
  TLS_HANDSHAKE_TYPE_NEW_SESSION_TICKET = 4;
  TLS_HANDSHAKE_TYPE_END_OF_EARLY_DATA = 5;
  TLS_HANDSHAKE_TYPE_ENCRYPTED_EXTENSIONS = 8;
  TLS_HANDSHAKE_TYPE_CERTIFICATE = 11;
  TLS_HANDSHAKE_TYPE_CERTIFICATE_REQUEST = 13;
  TLS_HANDSHAKE_TYPE_CERTIFICATE_VERIFY = 15;
  TLS_HANDSHAKE_TYPE_FINISHED = 20;
  TLS_HANDSHAKE_TYPE_KEY_UPDATE = 24;

  TLS_EXTENSION_SERVER_NAME = $0000;
  TLS_EXTENSION_STATUS_REQUEST = $0005;
  TLS_EXTENSION_SUPPORTED_GROUPS = $000A;
  TLS_EXTENSION_EC_POINT_FORMATS = $000B;
  TLS_EXTENSION_SIGNATURE_ALGORITHMS = $000D;
  TLS_EXTENSION_ALPN = $0010;
  TLS_EXTENSION_SIGNED_CERTIFICATE_TIMESTAMP = $0012;
  TLS_EXTENSION_PADDING = $0015;
  TLS_EXTENSION_ENCRYPT_THEN_MAC = $0016;
  TLS_EXTENSION_EXTENDED_MASTER_SECRET = $0017;
  TLS_EXTENSION_RECORD_SIZE_LIMIT = $001C;
  TLS_EXTENSION_SESSION_TICKET = $0023;
  TLS_EXTENSION_PRE_SHARED_KEY = $0029;
  TLS_EXTENSION_EARLY_DATA = $002A;
  TLS_EXTENSION_SUPPORTED_VERSIONS = $002B;
  TLS_EXTENSION_PSK_KEY_EXCHANGE_MODES = $002D;
  TLS_EXTENSION_KEY_SHARE = $0033;
  TLS_EXTENSION_RENEGOTIATION_INFO = $FF01;

  TLS13_RECORD_SIZE_LIMIT_MIN = 64;
  TLS13_RECORD_SIZE_LIMIT_DEFAULT = 16384;
  TLS13_RECORD_SIZE_LIMIT_MAX = 16385;

  TLS13_VERSION = $0304;
  TLS_LEGACY_VERSION = $0303;

  TLS13_CIPHER_AES_128_GCM_SHA256 = $1301;
  TLS13_CIPHER_AES_256_GCM_SHA384 = $1302;
  TLS13_CIPHER_CHACHA20_POLY1305_SHA256 = $1303;

  TLS13_GROUP_X25519 = $001D;
  TLS13_GROUP_SECP256R1 = $0017;
  TLS13_GROUP_SECP384R1 = $0018;

  TLS13_HRR_RANDOM: array[0..31] of Byte = (
    $CF, $21, $AD, $74, $E5, $9A, $61, $11, $BE, $1D, $8C, $02, $1E, $65, $B8, $91,
    $C2, $A2, $11, $16, $7A, $BB, $8C, $5E, $07, $9E, $09, $E2, $C8, $A8, $33, $9C
  );

  TLS13_SIG_RSA_PKCS1_SHA256 = $0401;
  TLS13_SIG_RSA_PKCS1_SHA384 = $0501;
  TLS13_SIG_RSA_PKCS1_SHA512 = $0601;
  TLS13_SIG_ECDSA_SECP256R1_SHA256 = $0403;
  TLS13_SIG_ECDSA_SECP384R1_SHA384 = $0503;
  TLS13_SIG_ECDSA_SECP521R1_SHA512 = $0603;
  TLS13_SIG_RSA_PSS_RSAE_SHA256 = $0804;
  TLS13_SIG_RSA_PSS_RSAE_SHA384 = $0805;
  TLS13_SIG_RSA_PSS_RSAE_SHA512 = $0806;
  TLS13_SIG_ED25519 = $0807;
  TLS13_SIG_RSA_PSS_PSS_SHA256 = $0809;
  TLS13_SIG_RSA_PSS_PSS_SHA384 = $080A;
  TLS13_SIG_RSA_PSS_PSS_SHA512 = $080B;

  TLS_CERT_STATUS_TYPE_OCSP = 1;

type
  TTLSRecordHeader = record
    ContentType: Byte;
    LegacyVersion: Word;
    Length: Word;
  end;

procedure AppendByte(var ADest: TBytes; AValue: Byte);
procedure AppendBytes(var ADest: TBytes; const AData: TBytes);
procedure AppendUInt16(var ADest: TBytes; AValue: Word);
procedure AppendUInt24(var ADest: TBytes; AValue: Cardinal);

function ReadUInt16(const AData: TBytes; AOffset: Integer): Word;
function ReadUInt24(const AData: TBytes; AOffset: Integer): Cardinal;

function BuildTLSPlaintext(AContentType: Byte; const APayload: TBytes): TBytes;
function ParseTLSRecordHeader(const AData: TBytes; out AHeader: TTLSRecordHeader): Boolean;

function TLS13CipherSuiteToString(ACipherSuite: Word): string;
function TLS13SignatureSchemeToString(ASignatureScheme: Word): string;

implementation

procedure AppendByte(var ADest: TBytes; AValue: Byte);
var
  LLen: Integer;
begin
  LLen := Length(ADest);
  SetLength(ADest, LLen + 1);
  ADest[LLen] := AValue;
end;

procedure AppendBytes(var ADest: TBytes; const AData: TBytes);
var
  LLen, LAppendLen: Integer;
begin
  LAppendLen := Length(AData);
  if LAppendLen = 0 then
    Exit;

  LLen := Length(ADest);
  SetLength(ADest, LLen + LAppendLen);
  Move(AData[0], ADest[LLen], LAppendLen);
end;

procedure AppendUInt16(var ADest: TBytes; AValue: Word);
begin
  AppendByte(ADest, Byte(AValue shr 8));
  AppendByte(ADest, Byte(AValue and $FF));
end;

procedure AppendUInt24(var ADest: TBytes; AValue: Cardinal);
begin
  AppendByte(ADest, Byte((AValue shr 16) and $FF));
  AppendByte(ADest, Byte((AValue shr 8) and $FF));
  AppendByte(ADest, Byte(AValue and $FF));
end;

function ReadUInt16(const AData: TBytes; AOffset: Integer): Word;
begin
  if (AOffset < 0) or (AOffset + 1 >= Length(AData)) then
    RaiseInvalidParameter('ReadUInt16Offset');

  Result := (Word(AData[AOffset]) shl 8) or Word(AData[AOffset + 1]);
end;

function ReadUInt24(const AData: TBytes; AOffset: Integer): Cardinal;
begin
  if (AOffset < 0) or (AOffset + 2 >= Length(AData)) then
    RaiseInvalidParameter('ReadUInt24Offset');

  Result :=
    (Cardinal(AData[AOffset]) shl 16) or
    (Cardinal(AData[AOffset + 1]) shl 8) or
    Cardinal(AData[AOffset + 2]);
end;

function BuildTLSPlaintext(AContentType: Byte; const APayload: TBytes): TBytes;
var
  LLen: Integer;
begin
  LLen := Length(APayload);
  if LLen > High(Word) then
    RaiseInvalidParameter('TLSPlaintextPayloadLength');

  Result := nil;
  SetLength(Result, 5 + LLen);
  Result[0] := AContentType;
  Result[1] := Byte(TLS_LEGACY_VERSION shr 8);
  Result[2] := Byte(TLS_LEGACY_VERSION and $FF);
  Result[3] := Byte((LLen shr 8) and $FF);
  Result[4] := Byte(LLen and $FF);

  if LLen > 0 then
    Move(APayload[0], Result[5], LLen);
end;

function ParseTLSRecordHeader(const AData: TBytes; out AHeader: TTLSRecordHeader): Boolean;
begin
  FillChar(AHeader, SizeOf(AHeader), 0);
  Result := False;

  if Length(AData) < 5 then
    Exit;

  AHeader.ContentType := AData[0];
  AHeader.LegacyVersion := ReadUInt16(AData, 1);
  AHeader.Length := ReadUInt16(AData, 3);

  Result := True;
end;

function TLS13CipherSuiteToString(ACipherSuite: Word): string;
begin
  case ACipherSuite of
    TLS13_CIPHER_AES_128_GCM_SHA256:
      Result := 'TLS_AES_128_GCM_SHA256';
    TLS13_CIPHER_AES_256_GCM_SHA384:
      Result := 'TLS_AES_256_GCM_SHA384';
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256:
      Result := 'TLS_CHACHA20_POLY1305_SHA256';
  else
    Result := Format('0x%.4x', [ACipherSuite]);
  end;
end;

function TLS13SignatureSchemeToString(ASignatureScheme: Word): string;
begin
  case ASignatureScheme of
    TLS13_SIG_RSA_PKCS1_SHA256:
      Result := 'rsa_pkcs1_sha256';
    TLS13_SIG_RSA_PKCS1_SHA384:
      Result := 'rsa_pkcs1_sha384';
    TLS13_SIG_RSA_PKCS1_SHA512:
      Result := 'rsa_pkcs1_sha512';
    TLS13_SIG_ECDSA_SECP256R1_SHA256:
      Result := 'ecdsa_secp256r1_sha256';
    TLS13_SIG_ECDSA_SECP384R1_SHA384:
      Result := 'ecdsa_secp384r1_sha384';
    TLS13_SIG_ECDSA_SECP521R1_SHA512:
      Result := 'ecdsa_secp521r1_sha512';
    TLS13_SIG_RSA_PSS_RSAE_SHA256:
      Result := 'rsa_pss_rsae_sha256';
    TLS13_SIG_RSA_PSS_RSAE_SHA384:
      Result := 'rsa_pss_rsae_sha384';
    TLS13_SIG_RSA_PSS_RSAE_SHA512:
      Result := 'rsa_pss_rsae_sha512';
    TLS13_SIG_ED25519:
      Result := 'ed25519';
    TLS13_SIG_RSA_PSS_PSS_SHA256:
      Result := 'rsa_pss_pss_sha256';
    TLS13_SIG_RSA_PSS_PSS_SHA384:
      Result := 'rsa_pss_pss_sha384';
    TLS13_SIG_RSA_PSS_PSS_SHA512:
      Result := 'rsa_pss_pss_sha512';
  else
    Result := Format('0x%.4x', [ASignatureScheme]);
  end;
end;

end.
