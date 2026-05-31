{**
 * Unit: nextpas.core.tls.mbedtls.base
 * Purpose: MbedTLS 后端基础类型和常量定义
 *
 * P3-9: MbedTLS 后端框架 - 最小子集实现
 *
 * MbedTLS 特点：
 * - 模块化设计（ssl/x509/pk/entropy/ctr_drbg）
 * - 显式上下文管理
 * - 嵌入式友好，许可证友好（Apache 2.0）
 * - 需要手动管理熵源和随机数生成器
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-01-09
 *}

unit nextpas.core.tls.mbedtls.base;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.base;

const
  { MbedTLS 库文件名 - 分为三个库 }
  {$IFDEF WINDOWS}
  MBEDTLS_LIB_NAME = 'mbedtls.dll';
  MBEDCRYPTO_LIB_NAME = 'mbedcrypto.dll';
  MBEDX509_LIB_NAME = 'mbedx509.dll';
  {$ENDIF}
  {$IFDEF LINUX}
  MBEDTLS_LIB_NAME = 'libmbedtls.so';
  MBEDCRYPTO_LIB_NAME = 'libmbedcrypto.so';
  MBEDX509_LIB_NAME = 'libmbedx509.so';
  {$ENDIF}
  {$IFDEF DARWIN}
  MBEDTLS_LIB_NAME = 'libmbedtls.dylib';
  MBEDCRYPTO_LIB_NAME = 'libmbedcrypto.dylib';
  MBEDX509_LIB_NAME = 'libmbedx509.dylib';
  {$ENDIF}

  { MbedTLS 版本要求 }
  MBEDTLS_MIN_VERSION = $03000000;  // 3.0.0 minimum for TLS 1.3

  { SSL 端点类型 }
  MBEDTLS_SSL_IS_CLIENT = 0;
  MBEDTLS_SSL_IS_SERVER = 1;

  { SSL 传输类型 }
  MBEDTLS_SSL_TRANSPORT_STREAM = 0;
  MBEDTLS_SSL_TRANSPORT_DATAGRAM = 1;

  { SSL 配置预设 }
  MBEDTLS_SSL_PRESET_DEFAULT = 0;
  MBEDTLS_SSL_PRESET_SUITEB = 2;

  { 验证模式 }
  MBEDTLS_SSL_VERIFY_NONE = 0;
  MBEDTLS_SSL_VERIFY_OPTIONAL = 1;
  MBEDTLS_SSL_VERIFY_REQUIRED = 2;

  { 协议版本 }
  MBEDTLS_SSL_VERSION_TLS1_2 = $0303;
  MBEDTLS_SSL_VERSION_TLS1_3 = $0304;

  { 错误码 - SSL 层 (0x7000 - 0x7FFF) }
  MBEDTLS_ERR_SSL_WANT_READ = -$6900;
  MBEDTLS_ERR_SSL_WANT_WRITE = -$6880;
  MBEDTLS_ERR_SSL_TIMEOUT = -$6800;
  MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY = -$7880;
  MBEDTLS_ERR_SSL_CONN_EOF = -$7280;
  MBEDTLS_ERR_SSL_HANDSHAKE_FAILURE = -$7900;
  MBEDTLS_ERR_SSL_BAD_PROTOCOL_VERSION = -$6E80;
  MBEDTLS_ERR_SSL_ALLOC_FAILED = -$7F00;
  MBEDTLS_ERR_SSL_FEATURE_UNAVAILABLE = -$7080;

  { 错误码 - X509 层 (0x2000 - 0x2FFF) }
  MBEDTLS_ERR_X509_CERT_VERIFY_FAILED = -$2700;
  MBEDTLS_ERR_X509_CERT_UNKNOWN_FORMAT = -$2180;
  MBEDTLS_ERR_X509_BAD_INPUT_DATA = -$2800;

  { 错误码 - PK 层 }
  MBEDTLS_ERR_PK_KEY_INVALID_FORMAT = -$3D00;
  MBEDTLS_ERR_PK_FILE_IO_ERROR = -$3E00;

  { 消息摘要类型 - MbedTLS 3.x 值 }
  MBEDTLS_MD_NONE = 0;
  MBEDTLS_MD_MD5 = 3;
  MBEDTLS_MD_RIPEMD160 = 4;
  MBEDTLS_MD_SHA1 = 5;
  MBEDTLS_MD_SHA224 = 8;
  MBEDTLS_MD_SHA256 = 9;
  MBEDTLS_MD_SHA384 = 10;
  MBEDTLS_MD_SHA512 = 11;
  { SHA3 系列 - MbedTLS 3.x }
  MBEDTLS_MD_SHA3_224 = 16;
  MBEDTLS_MD_SHA3_256 = 17;
  MBEDTLS_MD_SHA3_384 = 18;
  MBEDTLS_MD_SHA3_512 = 19;

  { Ciphersuite flags }
  MBEDTLS_CIPHERSUITE_SHORT_TAG = $02;
type
  { MbedTLS 不透明指针类型 }
  Pmbedtls_ssl_context = Pointer;
  Pmbedtls_ssl_config = Pointer;
  Pmbedtls_ssl_session = Pointer;
  Pmbedtls_x509_crl = Pointer;
  Pmbedtls_pk_context = Pointer;
  Pmbedtls_entropy_context = Pointer;
  Pmbedtls_ctr_drbg_context = Pointer;
  Pmbedtls_ssl_ciphersuite_info = ^Tmbedtls_ssl_ciphersuite_info;

  {$PUSH}
  {$PACKRECORDS C}
  { MbedTLS ciphersuite descriptor fields that are stable and needed for
    connection-info truth derivation. }
  Tmbedtls_ssl_ciphersuite_info = record
    id: Integer;
    name: PAnsiChar;
    cipher: Byte;
    mac: Byte;
    key_exchange: Byte;
    flags: Byte;
    min_tls_version: Word;
    max_tls_version: Word;
  end;
  {$POP}

  { MbedTLS x509_buf 结构 - 用于访问原始证书数据 }
  Tmbedtls_x509_buf = record
    tag: Integer;       // ASN1 tag
    len: NativeUInt;    // ASN1 length
    p: PByte;           // ASN1 data pointer
  end;
  Pmbedtls_x509_buf = ^Tmbedtls_x509_buf;

  { MbedTLS x509_crt 结构的前几个字段 - 用于访问 raw DER 数据 }
  Tmbedtls_x509_crt_partial = record
    own_buffer: Integer;  // 是否拥有缓冲区
    raw: Tmbedtls_x509_buf;  // 原始 DER 数据
    // 后续字段省略，我们只需要 raw
  end;
  Pmbedtls_x509_crt = ^Tmbedtls_x509_crt_partial;

  { MbedTLS 后端状态 }
  TMbedTLSBackendState = (
    mbsNotLoaded,      // 库未加载
    mbsLoaded,         // 库已加载
    mbsInitialized,    // 已初始化（熵源和RNG就绪）
    mbsError           // 错误状态
  );

  { MbedTLS 能力检测结果 }
  TMbedTLSCapabilities = record
    HasTLS12: Boolean;
    HasTLS13: Boolean;
    HasALPN: Boolean;
    HasSNI: Boolean;
    HasSessionTickets: Boolean;
    HasECDHE: Boolean;
    HasChaCha20: Boolean;
    HasAESNI: Boolean;
    VersionString: string;
    VersionNumber: Cardinal;
  end;

{ 工具函数 }
function MbedTLSErrorToSSLError(AMbedTLSError: Integer): TSSLErrorCode;
function SSLProtocolToMbedTLS(AProtocol: TSSLProtocolVersion): Integer;
function MbedTLSProtocolToSSL(AMbedTLSProtocol: Integer): TSSLProtocolVersion;

implementation

function MbedTLSErrorToSSLError(AMbedTLSError: Integer): TSSLErrorCode;
begin
  if AMbedTLSError = 0 then
    Exit(sslErrNone);

  case AMbedTLSError of
    MBEDTLS_ERR_SSL_WANT_READ: Result := sslErrWantRead;
    MBEDTLS_ERR_SSL_WANT_WRITE: Result := sslErrWantWrite;
    MBEDTLS_ERR_SSL_TIMEOUT: Result := sslErrTimeout;
    MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY: Result := sslErrNone;  // 正常关闭
    MBEDTLS_ERR_SSL_CONN_EOF: Result := sslErrConnection;
    MBEDTLS_ERR_SSL_HANDSHAKE_FAILURE: Result := sslErrHandshake;
    MBEDTLS_ERR_SSL_BAD_PROTOCOL_VERSION: Result := sslErrProtocol;
    MBEDTLS_ERR_SSL_ALLOC_FAILED: Result := sslErrMemory;
    MBEDTLS_ERR_X509_CERT_VERIFY_FAILED: Result := sslErrCertificate;
    MBEDTLS_ERR_X509_CERT_UNKNOWN_FORMAT: Result := sslErrInvalidFormat;
    MBEDTLS_ERR_PK_KEY_INVALID_FORMAT: Result := sslErrInvalidFormat;
    MBEDTLS_ERR_PK_FILE_IO_ERROR: Result := sslErrIO;
  else
    Result := sslErrGeneral;
  end;
end;

function SSLProtocolToMbedTLS(AProtocol: TSSLProtocolVersion): Integer;
begin
  case AProtocol of
    sslProtocolTLS12: Result := MBEDTLS_SSL_VERSION_TLS1_2;
    sslProtocolTLS13: Result := MBEDTLS_SSL_VERSION_TLS1_3;
  else
    Result := MBEDTLS_SSL_VERSION_TLS1_2;  // 默认 TLS 1.2
  end;
end;

function MbedTLSProtocolToSSL(AMbedTLSProtocol: Integer): TSSLProtocolVersion;
begin
  case AMbedTLSProtocol of
    MBEDTLS_SSL_VERSION_TLS1_2: Result := sslProtocolTLS12;
    MBEDTLS_SSL_VERSION_TLS1_3: Result := sslProtocolTLS13;
  else
    Result := sslProtocolTLS12;  // 默认
  end;
end;

end.
