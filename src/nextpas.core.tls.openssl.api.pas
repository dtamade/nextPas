unit nextpas.core.tls.openssl.api;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.openssl.loader;

const
  {$IFDEF MSWINDOWS}
  OPENSSL_LIB = 'libssl-3-x64.dll';
  CRYPTO_LIB = 'libcrypto-3-x64.dll';
  {$ELSE}
  OPENSSL_LIB = 'libssl.so';
  CRYPTO_LIB = 'libcrypto.so';
  {$ENDIF}
  
  // SSL_ctrl 命令
  SSL_CTRL_SET_TLSEXT_HOSTNAME = 55;
  TLSEXT_NAMETYPE_host_name = 0;
  SSL_CTRL_SET_MSG_CALLBACK = 15;
  SSL_CTRL_SET_MSG_CALLBACK_ARG = 16;
  SSL_CTRL_SET_TLSEXT_DEBUG_CB = 56;
  SSL_CTRL_SET_TLSEXT_DEBUG_ARG = 57;
  SSL_CTRL_SET_TLSEXT_STATUS_REQ_CB = 63;
  SSL_CTRL_SET_TLSEXT_STATUS_REQ_CB_ARG = 64;
  SSL_CTRL_SET_TLSEXT_STATUS_REQ_TYPE = 65;
  SSL_CTRL_GET_TLSEXT_STATUS_REQ_IDS = 66;
  SSL_CTRL_SET_TLSEXT_STATUS_REQ_IDS = 67;
  SSL_CTRL_GET_TLSEXT_STATUS_REQ_OCSP_RESP = 70;
  SSL_CTRL_SET_TLSEXT_STATUS_REQ_OCSP_RESP = 71;
  
  // SSL Session Cache 模式
  SSL_SESS_CACHE_OFF = $0000;
  SSL_SESS_CACHE_CLIENT = $0001;
  SSL_SESS_CACHE_SERVER = $0002;
  SSL_SESS_CACHE_BOTH = (SSL_SESS_CACHE_CLIENT or SSL_SESS_CACHE_SERVER);
  SSL_SESS_CACHE_NO_AUTO_CLEAR = $0080;
  SSL_SESS_CACHE_NO_INTERNAL_LOOKUP = $0100;
  SSL_SESS_CACHE_NO_INTERNAL_STORE = $0200;
  SSL_SESS_CACHE_NO_INTERNAL = (SSL_SESS_CACHE_NO_INTERNAL_LOOKUP or SSL_SESS_CACHE_NO_INTERNAL_STORE);

  // SSL/TLS 版本常量
  TLS1_VERSION = $0301;
  TLS1_1_VERSION = $0302;
  TLS1_2_VERSION = $0303;
  TLS1_3_VERSION = $0304;
  
  // SSL 文件类型
  SSL_FILETYPE_PEM = 1;
  SSL_FILETYPE_ASN1 = 2;
  
  // SSL 验证模式
  SSL_VERIFY_NONE = $00;
  SSL_VERIFY_PEER = $01;
  SSL_VERIFY_FAIL_IF_NO_PEER_CERT = $02;
  SSL_VERIFY_CLIENT_ONCE = $04;
  SSL_VERIFY_POST_HANDSHAKE = $08;
  
  // SSL 选项
  SSL_OP_LEGACY_SERVER_CONNECT = $00000004;
  SSL_OP_NO_SSLv2 = $00000000;  // SSLv2 已被移除
  SSL_OP_NO_SSLv3 = $00020000;
  SSL_OP_NO_TLSv1 = $00040000;
  SSL_OP_NO_TLSv1_2 = $00100000;
  SSL_OP_NO_TLSv1_1 = $00200000;
  SSL_OP_NO_TLSv1_3 = $00400000;
  SSL_OP_NO_DTLSv1 = $00800000;
  SSL_OP_NO_DTLSv1_2 = $01000000;
  SSL_OP_NO_COMPRESSION = $00020000;
  SSL_OP_NO_TICKET = $00004000;
  SSL_OP_ENABLE_MIDDLEBOX_COMPAT = $00100000;
  
  // SSL 错误代码
  SSL_ERROR_NONE = 0;
  SSL_ERROR_SSL = 1;
  SSL_ERROR_WANT_READ = 2;
  SSL_ERROR_WANT_WRITE = 3;
  SSL_ERROR_WANT_X509_LOOKUP = 4;
  SSL_ERROR_SYSCALL = 5;
  SSL_ERROR_ZERO_RETURN = 6;
  SSL_ERROR_WANT_CONNECT = 7;
  SSL_ERROR_WANT_ACCEPT = 8;
  SSL_ERROR_WANT_ASYNC = 9;
  SSL_ERROR_WANT_ASYNC_JOB = 10;
  SSL_ERROR_WANT_CLIENT_HELLO_CB = 11;
  
  // X509 验证结果
  X509_V_OK = 0;
  X509_V_ERR_UNSPECIFIED = 1;
  X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT = 2;
  X509_V_ERR_UNABLE_TO_GET_CRL = 3;
  X509_V_ERR_UNABLE_TO_DECRYPT_CERT_SIGNATURE = 4;
  X509_V_ERR_UNABLE_TO_DECRYPT_CRL_SIGNATURE = 5;
  X509_V_ERR_UNABLE_TO_DECODE_ISSUER_PUBLIC_KEY = 6;
  X509_V_ERR_CERT_SIGNATURE_FAILURE = 7;
  X509_V_ERR_CRL_SIGNATURE_FAILURE = 8;
  X509_V_ERR_CERT_NOT_YET_VALID = 9;
  X509_V_ERR_CERT_HAS_EXPIRED = 10;
  X509_V_ERR_CRL_NOT_YET_VALID = 11;
  X509_V_ERR_CRL_HAS_EXPIRED = 12;
  X509_V_ERR_ERROR_IN_CERT_NOT_BEFORE_FIELD = 13;
  X509_V_ERR_ERROR_IN_CERT_NOT_AFTER_FIELD = 14;
  X509_V_ERR_ERROR_IN_CRL_LAST_UPDATE_FIELD = 15;
  X509_V_ERR_ERROR_IN_CRL_NEXT_UPDATE_FIELD = 16;
  X509_V_ERR_OUT_OF_MEM = 17;
  X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT = 18;
  X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN = 19;
  X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY = 20;
  X509_V_ERR_UNABLE_TO_VERIFY_LEAF_SIGNATURE = 21;
  X509_V_ERR_CERT_CHAIN_TOO_LONG = 22;
  X509_V_ERR_CERT_REVOKED = 23;
  X509_V_ERR_INVALID_CA = 24;
  X509_V_ERR_PATH_LENGTH_EXCEEDED = 25;
  X509_V_ERR_INVALID_PURPOSE = 26;
  X509_V_ERR_CERT_UNTRUSTED = 27;
  X509_V_ERR_CERT_REJECTED = 28;
  
  // BIO 类型
  BIO_NOCLOSE = 0;
  BIO_CLOSE = 1;
  
  // EVP 常量
  EVP_MAX_MD_SIZE = 64;  // 最大摘要大小
  EVP_MAX_KEY_LENGTH = 64;  // 最大密钥长度
  EVP_MAX_IV_LENGTH = 16;  // 最大 IV 长度
  EVP_MAX_BLOCK_LENGTH = 32;  // 最大块大小
  
  // EVP 密码模式
  EVP_CIPH_STREAM_CIPHER = $0;
  EVP_CIPH_ECB_MODE = $1;
  EVP_CIPH_CBC_MODE = $2;
  EVP_CIPH_CFB_MODE = $3;
  EVP_CIPH_OFB_MODE = $4;
  EVP_CIPH_CTR_MODE = $5;
  EVP_CIPH_GCM_MODE = $6;
  EVP_CIPH_CCM_MODE = $7;
  EVP_CIPH_XTS_MODE = $10001;
  EVP_CIPH_WRAP_MODE = $10002;
  EVP_CIPH_OCB_MODE = $10003;
  EVP_CIPH_MODE = $F0007;
  
  // EVP 密码标志
  EVP_CIPH_VARIABLE_LENGTH = $8;
  EVP_CIPH_CUSTOM_IV = $10;
  EVP_CIPH_ALWAYS_CALL_INIT = $20;
  EVP_CIPH_CTRL_INIT = $40;
  EVP_CIPH_CUSTOM_KEY_LENGTH = $80;
  EVP_CIPH_NO_PADDING = $100;
  EVP_CIPH_RAND_KEY = $200;
  EVP_CIPH_CUSTOM_COPY = $400;
  EVP_CIPH_FLAG_DEFAULT_ASN1 = $1000;
  EVP_CIPH_FLAG_LENGTH_BITS = $2000;
  EVP_CIPH_FLAG_FIPS = $4000;
  EVP_CIPH_FLAG_NON_FIPS_ALLOW = $8000;
  
  // EVP 控制命令
  EVP_CTRL_INIT = $0;
  EVP_CTRL_SET_KEY_LENGTH = $1;
  EVP_CTRL_GET_RC2_KEY_BITS = $2;
  EVP_CTRL_SET_RC2_KEY_BITS = $3;
  EVP_CTRL_GET_RC5_ROUNDS = $4;
  EVP_CTRL_SET_RC5_ROUNDS = $5;
  EVP_CTRL_RAND_KEY = $6;
  EVP_CTRL_PBE_PRF_NID = $7;
  EVP_CTRL_COPY = $8;
  EVP_CTRL_AEAD_SET_IVLEN = $9;
  EVP_CTRL_AEAD_GET_TAG = $10;
  EVP_CTRL_AEAD_SET_TAG = $11;
  EVP_CTRL_AEAD_SET_IV_FIXED = $12;
  EVP_CTRL_GCM_SET_IVLEN = EVP_CTRL_AEAD_SET_IVLEN;
  EVP_CTRL_GCM_GET_TAG = EVP_CTRL_AEAD_GET_TAG;
  EVP_CTRL_GCM_SET_TAG = EVP_CTRL_AEAD_SET_TAG;
  EVP_CTRL_GCM_SET_IV_FIXED = EVP_CTRL_AEAD_SET_IV_FIXED;
  EVP_CTRL_GCM_IV_GEN = $13;
  EVP_CTRL_CCM_SET_IVLEN = EVP_CTRL_AEAD_SET_IVLEN;
  EVP_CTRL_CCM_GET_TAG = EVP_CTRL_AEAD_GET_TAG;
  EVP_CTRL_CCM_SET_TAG = EVP_CTRL_AEAD_SET_TAG;
  EVP_CTRL_CCM_SET_IV_FIXED = EVP_CTRL_AEAD_SET_IV_FIXED;
  EVP_CTRL_CCM_SET_L = $14;
  EVP_CTRL_CCM_SET_MSGLEN = $15;
  
  // RSA 加密填充模式
  RSA_PKCS1_PADDING = 1;
  RSA_SSLV23_PADDING = 2;
  RSA_NO_PADDING = 3;
  RSA_PKCS1_OAEP_PADDING = 4;
  RSA_X931_PADDING = 5;
  RSA_PKCS1_PSS_PADDING = 6;
  RSA_PKCS1_WITH_TLS_PADDING = 7;
  
  // RSA 密钥大小
  RSA_MIN_MODULUS_BITS = 512;
  RSA_MAX_MODULUS_BITS = 16384;
  RSA_MAX_MODULUS_LEN = (RSA_MAX_MODULUS_BITS div 8);
  RSA_MAX_PUBEXP_BITS = 64;
  
  // DSA 参数
  DSA_FLAG_CACHE_MONT_P = $01;
  DSA_FLAG_NO_EXP_CONSTTIME = $02;
  DSA_FLAG_FIPS_METHOD = $0400;
  DSA_FLAG_NON_FIPS_ALLOW = $0800;
  DSA_FLAG_FIPS_CHECKED = $1000;
  
  // DH 参数
  DH_GENERATOR_2 = 2;
  DH_GENERATOR_5 = 5;
  DH_CHECK_P_NOT_PRIME = $01;
  DH_CHECK_P_NOT_SAFE_PRIME = $02;
  DH_UNABLE_TO_CHECK_GENERATOR = $04;
  DH_NOT_SUITABLE_GENERATOR = $08;
  DH_CHECK_Q_NOT_PRIME = $10;
  DH_CHECK_INVALID_Q_VALUE = $20;
  DH_CHECK_INVALID_J_VALUE = $40;
  
  // EC 曲线
  OPENSSL_EC_NAMED_CURVE = $001;
  EC_PKEY_NO_PARAMETERS = $001;
  EC_PKEY_NO_PUBKEY = $002;
  EC_FLAG_NON_FIPS_ALLOW = $1;
  EC_FLAG_FIPS_CHECKED = $2;
  
  // PKCS7 标志
  PKCS7_TEXT = $1;
  PKCS7_NOCERTS = $2;
  PKCS7_NOSIGS = $4;
  PKCS7_NOCHAIN = $8;
  PKCS7_NOINTERN = $10;
  PKCS7_NOVERIFY = $20;
  PKCS7_DETACHED = $40;
  PKCS7_BINARY = $80;
  PKCS7_NOATTR = $100;
  PKCS7_NOSMIMECAP = $200;
  PKCS7_NOOLDMIMETYPE = $400;
  PKCS7_CRLFEOL = $800;
  PKCS7_STREAM = $1000;
  PKCS7_NOCRL = $2000;
  PKCS7_PARTIAL = $4000;
  PKCS7_REUSE_DIGEST = $8000;
  PKCS7_NO_DUAL_CONTENT = $10000;
  
  // PKCS12 常量
  PKCS12_KEY_ID = 1;
  PKCS12_IV_ID = 2;
  PKCS12_MAC_ID = 3;
  
  // ASN1 类型
  V_ASN1_UNIVERSAL = $00;
  V_ASN1_APPLICATION = $40;
  V_ASN1_CONTEXT_SPECIFIC = $80;
  V_ASN1_PRIVATE = $c0;
  V_ASN1_CONSTRUCTED = $20;
  V_ASN1_PRIMITIVE_TAG = $1f;
  V_ASN1_PRIMATIVE_TAG = V_ASN1_PRIMITIVE_TAG;
  
  V_ASN1_EOC = 0;
  V_ASN1_BOOLEAN = 1;
  V_ASN1_INTEGER = 2;
  V_ASN1_BIT_STRING = 3;
  V_ASN1_OCTET_STRING = 4;
  V_ASN1_NULL = 5;
  V_ASN1_OBJECT = 6;
  V_ASN1_OBJECT_DESCRIPTOR = 7;
  V_ASN1_EXTERNAL = 8;
  V_ASN1_REAL = 9;
  V_ASN1_ENUMERATED = 10;
  V_ASN1_UTF8STRING = 12;
  V_ASN1_SEQUENCE = 16;
  V_ASN1_SET = 17;
  V_ASN1_NUMERICSTRING = 18;
  V_ASN1_PRINTABLESTRING = 19;
  V_ASN1_T61STRING = 20;
  V_ASN1_TELETEXSTRING = 20;
  V_ASN1_VIDEOTEXSTRING = 21;
  V_ASN1_IA5STRING = 22;
  V_ASN1_UTCTIME = 23;
  V_ASN1_GENERALIZEDTIME = 24;
  V_ASN1_GRAPHICSTRING = 25;
  V_ASN1_ISO64STRING = 26;
  V_ASN1_VISIBLESTRING = 26;
  V_ASN1_GENERALSTRING = 27;
  V_ASN1_UNIVERSALSTRING = 28;
  V_ASN1_BMPSTRING = 30;
  
  // MBSTRING types for X509_NAME_add_entry_by_txt
  MBSTRING_FLAG = $1000;
  MBSTRING_UTF8 = (MBSTRING_FLAG or 1);
  MBSTRING_ASC = (MBSTRING_FLAG or 2);
  MBSTRING_BMP = (MBSTRING_FLAG or 3);
  MBSTRING_UNIV = (MBSTRING_FLAG or 4);

type
  // OpenSSL 句柄类型
  PSSL = Pointer;
  PSSL_CTX = Pointer;
  PSSL_METHOD = Pointer;
  PX509 = Pointer;
  PX509_STORE = Pointer;
  PX509_STORE_CTX = Pointer;
  PEVP_PKEY = Pointer;
  PBIO = Pointer;
  PBIO_METHOD = Pointer;
  PX509_NAME = Pointer;
  PASN1_STRING = Pointer;
  PASN1_TIME = Pointer;
  PSSL_SESSION = Pointer;
  PSSL_CIPHER = Pointer;
  PEVP_MD = Pointer;
  PEVP_MD_CTX = Pointer;
  PEVP_CIPHER = Pointer;
  PEVP_CIPHER_CTX = Pointer;
  PENGINE = Pointer;
  PRSA = Pointer;
  PDSA = Pointer;
  PDH = Pointer;
  PEC_KEY = Pointer;
  PEC_GROUP = Pointer;
  PEC_POINT = Pointer;
  PBIGNUM = Pointer;
  PBN_CTX = Pointer;
  PBN_MONT_CTX = Pointer;
  PBN_RECP_CTX = Pointer;
  PBN_GENCB = Pointer;
  PPKCS7 = Pointer;
  PPKCS7_SIGNER_INFO = Pointer;
  PPKCS7_RECIP_INFO = Pointer;
  PPKCS12 = Pointer;
  PASN1_OBJECT = Pointer;
  PASN1_INTEGER = Pointer;
  PASN1_BIT_STRING = Pointer;
  PASN1_OCTET_STRING = Pointer;
  PASN1_UTCTIME = Pointer;
  PASN1_GENERALIZEDTIME = Pointer;
  PASN1_TYPE = Pointer;
  PX509_EXTENSION = Pointer;
  PX509_EXTENSIONS = Pointer;
  PX509_ATTRIBUTE = Pointer;
  PX509_REQ = Pointer;
  PX509_CRL = Pointer;
  PX509_REVOKED = Pointer;
  PX509_ALGOR = Pointer;
  PX509_PUBKEY = Pointer;
  PX509V3_CTX = Pointer;
  POCSP_REQUEST = Pointer;
  POCSP_RESPONSE = Pointer;
  POCSP_BASICRESP = Pointer;
  PTS_REQ = Pointer;
  PTS_RESP = Pointer;
  PTS_STATUS_INFO = Pointer;
  PTS_TST_INFO = Pointer;
  PCONF = Pointer;
  PCONF_VALUE = Pointer;
  PLHASH = Pointer;
  POSSL_PROVIDER = Pointer;
  POSSL_LIB_CTX = Pointer;
  POSSL_PARAM = Pointer;
  POSSL_PARAM_BLD = Pointer;
  
  // 回调函数类型
  TSSLVerifyCallback = function(preverify_ok: Integer; ctx: PX509_STORE_CTX): Integer; cdecl;
  TSSLPSKClientCallback = function(ssl: PSSL; const hint: PAnsiChar; 
    identity: PAnsiChar; max_identity_len: Cardinal;
    psk: PByte; max_psk_len: Cardinal): Cardinal; cdecl;
  TSSLPSKServerCallback = function(ssl: PSSL; const identity: PAnsiChar;
    psk: PByte; max_psk_len: Cardinal): Cardinal; cdecl;
  
  // ALPN 回调
  TALPNSelectCallback = function(ssl: PSSL; out selected: PAnsiChar;
    out selected_len: Byte; const client: PByte; client_len: Cardinal;
    arg: Pointer): Integer; cdecl;
    
  // 其他回调函数类型
  TSSLInfoCallback = procedure(ssl: PSSL; where: Integer; ret: Integer); cdecl;
  TSSLMsgCallback = procedure(write_p: Integer; version: Integer; content_type: Integer;
    const buf: Pointer; len: Cardinal; ssl: PSSL; arg: Pointer); cdecl;
  TPasswordCallback = function(buf: PAnsiChar; size: Integer; rwflag: Integer; userdata: Pointer): Integer; cdecl;
  TSSLSessionCallback = function(ssl: PSSL; sess: PSSL_SESSION): Integer; cdecl;
  TSSLSessionNewCallback = function(ssl: PSSL; sess: PSSL_SESSION): Integer; cdecl;
  TSSLSessionRemoveCallback = procedure(ctx: PSSL_CTX; sess: PSSL_SESSION); cdecl;

var
  // SSL 库初始化和清理
  OPENSSL_init_ssl: function(opts: UInt64; settings: Pointer): Integer; cdecl;
  OPENSSL_cleanup: procedure; cdecl;
  
  // SSL_CTX 函数
  SSL_CTX_new: function(meth: PSSL_METHOD): PSSL_CTX; cdecl;
  SSL_CTX_free: procedure(ctx: PSSL_CTX); cdecl;
  SSL_CTX_set_options: function(ctx: PSSL_CTX; options: LongWord): LongWord; cdecl;
  SSL_CTX_clear_options: function(ctx: PSSL_CTX; options: LongWord): LongWord; cdecl;
  SSL_CTX_get_options: function(ctx: PSSL_CTX): LongWord; cdecl;
  SSL_CTX_set_verify: procedure(ctx: PSSL_CTX; mode: Integer; verify_callback: TSSLVerifyCallback); cdecl;
  SSL_CTX_set_verify_depth: procedure(ctx: PSSL_CTX; depth: Integer); cdecl;
  SSL_CTX_set_default_verify_paths: function(ctx: PSSL_CTX): Integer; cdecl;
  SSL_CTX_load_verify_locations: function(ctx: PSSL_CTX; const CAfile: PAnsiChar; const CApath: PAnsiChar): Integer; cdecl;
  SSL_CTX_use_certificate_file: function(ctx: PSSL_CTX; const file_: PAnsiChar; type_: Integer): Integer; cdecl;
  SSL_CTX_use_certificate_chain_file: function(ctx: PSSL_CTX; const file_: PAnsiChar): Integer; cdecl;
  SSL_CTX_use_PrivateKey_file: function(ctx: PSSL_CTX; const file_: PAnsiChar; type_: Integer): Integer; cdecl;
  SSL_CTX_check_private_key: function(ctx: PSSL_CTX): Integer; cdecl;
  SSL_CTX_set_cipher_list: function(ctx: PSSL_CTX; const str: PAnsiChar): Integer; cdecl;
  SSL_CTX_set_ciphersuites: function(ctx: PSSL_CTX; const str: PAnsiChar): Integer; cdecl;
  SSL_CTX_set_min_proto_version: function(ctx: PSSL_CTX; version: Integer): Integer; cdecl;
  SSL_CTX_set_max_proto_version: function(ctx: PSSL_CTX; version: Integer): Integer; cdecl;
  SSL_CTX_get_cert_store: function(ctx: PSSL_CTX): PX509_STORE; cdecl;
  SSL_CTX_set_alpn_protos: function(ctx: PSSL_CTX; const protos: PByte; protos_len: Cardinal): Integer; cdecl;
  SSL_CTX_set_alpn_select_cb: procedure(ctx: PSSL_CTX; cb: TALPNSelectCallback; arg: Pointer); cdecl;
  SSL_CTX_set_psk_client_callback: procedure(ctx: PSSL_CTX; callback: TSSLPSKClientCallback); cdecl;
  SSL_CTX_set_psk_server_callback: procedure(ctx: PSSL_CTX; callback: TSSLPSKServerCallback); cdecl;
  SSL_CTX_set_info_callback: procedure(ctx: PSSL_CTX; callback: TSSLInfoCallback); cdecl;
  SSL_CTX_get_info_callback: function(ctx: PSSL_CTX): TSSLInfoCallback; cdecl;
  SSL_CTX_set_msg_callback: procedure(ctx: PSSL_CTX; callback: TSSLMsgCallback); cdecl;
  SSL_CTX_set_default_passwd_cb: procedure(ctx: PSSL_CTX; callback: TPasswordCallback); cdecl;
  SSL_CTX_set_default_passwd_cb_userdata: procedure(ctx: PSSL_CTX; userdata: Pointer); cdecl;
  SSL_CTX_set_session_id_context: function(ctx: PSSL_CTX; const sid_ctx: PByte; sid_ctx_len: Cardinal): Integer; cdecl;
  SSL_CTX_set_session_cache_mode: function(ctx: PSSL_CTX; mode: Integer): Integer; cdecl;
  SSL_CTX_get_session_cache_mode: function(ctx: PSSL_CTX): Integer; cdecl;
  SSL_CTX_set_timeout: function(ctx: PSSL_CTX; t: LongInt): LongInt; cdecl;
  SSL_CTX_get_timeout: function(ctx: PSSL_CTX): LongInt; cdecl;
  SSL_CTX_sess_set_new_cb: procedure(ctx: PSSL_CTX; callback: TSSLSessionNewCallback); cdecl;
  SSL_CTX_sess_set_remove_cb: procedure(ctx: PSSL_CTX; callback: TSSLSessionRemoveCallback); cdecl;
  SSL_CTX_sess_set_get_cb: procedure(ctx: PSSL_CTX; callback: TSSLSessionCallback); cdecl;
  
  // SSL 函数
  SSL_new: function(ctx: PSSL_CTX): PSSL; cdecl;
  SSL_free: procedure(ssl: PSSL); cdecl;
  SSL_set_fd: function(ssl: PSSL; fd: Integer): Integer; cdecl;
  SSL_set_bio: procedure(ssl: PSSL; rbio: PBIO; wbio: PBIO); cdecl;
  SSL_get_rbio: function(ssl: PSSL): PBIO; cdecl;
  SSL_get_wbio: function(ssl: PSSL): PBIO; cdecl;
  SSL_set_connect_state: procedure(ssl: PSSL); cdecl;
  SSL_set_accept_state: procedure(ssl: PSSL); cdecl;
  SSL_connect: function(ssl: PSSL): Integer; cdecl;
  SSL_accept: function(ssl: PSSL): Integer; cdecl;
  SSL_do_handshake: function(ssl: PSSL): Integer; cdecl;
  SSL_read: function(ssl: PSSL; buf: Pointer; num: Integer): Integer; cdecl;
  SSL_write: function(ssl: PSSL; const buf: Pointer; num: Integer): Integer; cdecl;
  SSL_pending: function(const ssl: PSSL): Integer; cdecl;
  SSL_shutdown: function(ssl: PSSL): Integer; cdecl;
  SSL_get_error: function(const ssl: PSSL; ret: Integer): Integer; cdecl;
  SSL_get_peer_certificate: function(const ssl: PSSL): PX509; cdecl;
  SSL_get_peer_cert_chain: function(const ssl: PSSL): Pointer; cdecl; // STACK_OF(X509)
  SSL_get_verify_result: function(const ssl: PSSL): LongInt; cdecl;
  SSL_ctrl: function(ssl: PSSL; cmd: Integer; larg: LongInt; parg: Pointer): LongInt; cdecl;
  SSL_get_servername: function(const ssl: PSSL; const type_: Integer): PAnsiChar; cdecl;
  SSL_get_servername_type: function(const ssl: PSSL): Integer; cdecl;
  SSL_get_version: function(const ssl: PSSL): PAnsiChar; cdecl;
  SSL_get_current_cipher: function(const ssl: PSSL): Pointer; cdecl; // SSL_CIPHER
  SSL_is_init_finished: function(const ssl: PSSL): Integer; cdecl;
  SSL_in_init: function(const ssl: PSSL): Integer; cdecl;
  SSL_in_before: function(const ssl: PSSL): Integer; cdecl;
  SSL_is_server: function(const ssl: PSSL): Integer; cdecl;
  SSL_set_info_callback: procedure(ssl: PSSL; callback: TSSLInfoCallback); cdecl;
  SSL_get_info_callback: function(ssl: PSSL): TSSLInfoCallback; cdecl;
  SSL_set_msg_callback: procedure(ssl: PSSL; cb: TSSLMsgCallback); cdecl;
  SSL_set_msg_callback_arg: procedure(ssl: PSSL; arg: Pointer); cdecl;
  SSL_session_reused: function(ssl: PSSL): Integer; cdecl;
  SSL_get_session: function(const ssl: PSSL): PSSL_SESSION; cdecl;
  SSL_set_session: function(ssl: PSSL; session: PSSL_SESSION): Integer; cdecl;
  SSL_get_SSL_CTX: function(const ssl: PSSL): PSSL_CTX; cdecl;
  SSL_set_SSL_CTX: function(ssl: PSSL; ctx: PSSL_CTX): PSSL_CTX; cdecl;
  SSL_set_verify: procedure(ssl: PSSL; mode: Integer; verify_callback: TSSLVerifyCallback); cdecl;
  SSL_set_verify_depth: procedure(ssl: PSSL; depth: Integer); cdecl;
  SSL_get_verify_mode: function(const ssl: PSSL): Integer; cdecl;
  SSL_get_verify_depth: function(const ssl: PSSL): Integer; cdecl;
  SSL_get_verify_callback: function(const ssl: PSSL): TSSLVerifyCallback; cdecl;
  
  // SSL_METHOD 函数
  TLS_method: function: PSSL_METHOD; cdecl;
  TLS_server_method: function: PSSL_METHOD; cdecl;
  TLS_client_method: function: PSSL_METHOD; cdecl;
  SSLv23_method: function: PSSL_METHOD; cdecl;
  SSLv23_server_method: function: PSSL_METHOD; cdecl;
  SSLv23_client_method: function: PSSL_METHOD; cdecl;
  
  // BIO 函数
  BIO_new: function(type_: PBIO_METHOD): PBIO; cdecl;
  BIO_free: function(a: PBIO): Integer; cdecl;
  BIO_read: function(b: PBIO; data: Pointer; dlen: Integer): Integer; cdecl;
  BIO_write: function(b: PBIO; const data: Pointer; dlen: Integer): Integer; cdecl;
  BIO_ctrl: function(bp: PBIO; cmd: Integer; larg: LongInt; parg: Pointer): LongInt; cdecl;
  BIO_ctrl_pending: function(b: PBIO): LongWord; cdecl;
  BIO_ctrl_wpending: function(b: PBIO): LongWord; cdecl;
  BIO_new_socket: function(sock: Integer; close_flag: Integer): PBIO; cdecl;
  BIO_new_connect: function(const host_port: PAnsiChar): PBIO; cdecl;
  BIO_new_mem_buf: function(const buf: Pointer; len: Integer): PBIO; cdecl;
  BIO_s_mem: function: PBIO_METHOD; cdecl;
  BIO_s_connect: function: PBIO_METHOD; cdecl;
  BIO_s_socket: function: PBIO_METHOD; cdecl;
  BIO_push: function(b: PBIO; append: PBIO): PBIO; cdecl;
  BIO_pop: function(b: PBIO): PBIO; cdecl;
  BIO_flush: function(b: PBIO): Integer; cdecl;
  BIO_get_retry_BIO: function(bio: PBIO; reason: PInteger): PBIO; cdecl;
  BIO_get_retry_reason: function(bio: PBIO): Integer; cdecl;
  BIO_should_retry: function(b: PBIO): Integer; cdecl;
  BIO_should_read: function(b: PBIO): Integer; cdecl;
  BIO_should_write: function(b: PBIO): Integer; cdecl;
  BIO_should_io_special: function(b: PBIO): Integer; cdecl;
  BIO_retry_type: function(b: PBIO): Integer; cdecl;
  BIO_get_fd: function(b: PBIO; c: PInteger): Integer; cdecl;
  BIO_set_fd: function(b: PBIO; fd: Integer; c: Integer): Integer; cdecl;
  BIO_get_close: function(b: PBIO): Integer; cdecl;
  BIO_set_close: function(b: PBIO; flag: Integer): Integer; cdecl;
  
  // X509 证书函数
  X509_free: procedure(a: PX509); cdecl;
  X509_dup: function(x509: PX509): PX509; cdecl;
  X509_get_subject_name: function(a: PX509): PX509_NAME; cdecl;
  X509_get_issuer_name: function(a: PX509): PX509_NAME; cdecl;
  X509_NAME_oneline: function(a: PX509_NAME; buf: PAnsiChar; size: Integer): PAnsiChar; cdecl;
  X509_NAME_print_ex: function(out_: PBIO; nm: PX509_NAME; indent: Integer; flags: LongWord): Integer; cdecl;
  X509_get_serialNumber: function(x: PX509): PASN1_STRING; cdecl;
  X509_get0_notBefore: function(const x: PX509): PASN1_TIME; cdecl;
  X509_get0_notAfter: function(const x: PX509): PASN1_TIME; cdecl;
  X509_get_pubkey: function(x: PX509): PEVP_PKEY; cdecl;
  X509_get_version: function(const x: PX509): LongInt; cdecl;
  X509_get_signature_nid: function(const x: PX509): Integer; cdecl;
  X509_verify_cert_error_string: function(n: LongInt): PAnsiChar; cdecl;
  X509_STORE_new: function: PX509_STORE; cdecl;
  X509_STORE_free: procedure(store: PX509_STORE); cdecl;
  X509_STORE_add_cert: function(ctx: PX509_STORE; x: PX509): Integer; cdecl;
  X509_STORE_set_flags: function(ctx: PX509_STORE; flags: LongWord): Integer; cdecl;
  
  // EVP_PKEY 函数
  EVP_PKEY_free: procedure(pkey: PEVP_PKEY); cdecl;
  EVP_PKEY_bits: function(const pkey: PEVP_PKEY): Integer; cdecl;
  EVP_PKEY_id: function(const pkey: PEVP_PKEY): Integer; cdecl;
  
  // 错误处理函数
  ERR_get_error: function: LongWord; cdecl;
  ERR_peek_error: function: LongWord; cdecl;
  ERR_error_string: function(e: LongWord; buf: PAnsiChar): PAnsiChar; cdecl;
  ERR_error_string_n: procedure(e: LongWord; buf: PAnsiChar; len: LongWord); cdecl;
  ERR_clear_error: procedure; cdecl;
  ERR_print_errors_fp: procedure(fp: Pointer); cdecl;
  
  // Crypto 函数
  CRYPTO_num_locks: function: Integer; cdecl;
  CRYPTO_set_locking_callback: procedure(func: Pointer); cdecl;
  CRYPTO_set_id_callback: procedure(func: Pointer); cdecl;
  OPENSSL_version_num: function: LongWord; cdecl;
  OPENSSL_version: function(type_: Integer): PAnsiChar; cdecl;
  
  // SSL_SESSION 函数
  SSL_SESSION_new: function: PSSL_SESSION; cdecl;
  SSL_SESSION_free: procedure(sess: PSSL_SESSION); cdecl;
  SSL_SESSION_up_ref: function(sess: PSSL_SESSION): Integer; cdecl;
  SSL_SESSION_get_id: function(const sess: PSSL_SESSION; len: PCardinal): PByte; cdecl;
  SSL_SESSION_get_time: function(const sess: PSSL_SESSION): LongInt; cdecl;
  SSL_SESSION_set_time: function(sess: PSSL_SESSION; t: LongInt): LongInt; cdecl;
  SSL_SESSION_get_timeout: function(const sess: PSSL_SESSION): LongInt; cdecl;
  SSL_SESSION_set_timeout: function(sess: PSSL_SESSION; t: LongInt): LongInt; cdecl;
  SSL_SESSION_has_ticket: function(const sess: PSSL_SESSION): Integer; cdecl;
  SSL_SESSION_get_ticket_lifetime_hint: function(const sess: PSSL_SESSION): LongWord; cdecl;
  
  // SSL_CIPHER 函数
  SSL_CIPHER_get_name: function(const c: PSSL_CIPHER): PAnsiChar; cdecl;
  SSL_CIPHER_get_bits: function(const c: PSSL_CIPHER; alg_bits: PInteger): Integer; cdecl;
  SSL_CIPHER_get_version: function(const c: PSSL_CIPHER): PAnsiChar; cdecl;
  SSL_CIPHER_description: function(const c: PSSL_CIPHER; buf: PAnsiChar; size: Integer): PAnsiChar; cdecl;
  SSL_CIPHER_get_id: function(const c: PSSL_CIPHER): LongWord; cdecl;
  
  // EVP 摘要函数
  EVP_MD_CTX_new: function: PEVP_MD_CTX; cdecl;
  EVP_MD_CTX_free: procedure(ctx: PEVP_MD_CTX); cdecl;
  EVP_MD_CTX_reset: function(ctx: PEVP_MD_CTX): Integer; cdecl;
  EVP_MD_CTX_copy: function(out_: PEVP_MD_CTX; const in_: PEVP_MD_CTX): Integer; cdecl;
  EVP_MD_CTX_copy_ex: function(out_: PEVP_MD_CTX; const in_: PEVP_MD_CTX): Integer; cdecl;
  EVP_DigestInit: function(ctx: PEVP_MD_CTX; const type_: PEVP_MD): Integer; cdecl;
  EVP_DigestInit_ex: function(ctx: PEVP_MD_CTX; const type_: PEVP_MD; impl: PENGINE): Integer; cdecl;
  EVP_DigestUpdate: function(ctx: PEVP_MD_CTX; const d: Pointer; cnt: Cardinal): Integer; cdecl;
  EVP_DigestFinal: function(ctx: PEVP_MD_CTX; md: PByte; s: PCardinal): Integer; cdecl;
  EVP_DigestFinal_ex: function(ctx: PEVP_MD_CTX; md: PByte; s: PCardinal): Integer; cdecl;
  EVP_Digest: function(const data: Pointer; count: Cardinal; md: PByte; size: PCardinal; const type_: PEVP_MD; impl: PENGINE): Integer; cdecl;
  EVP_MD_size: function(const md: PEVP_MD): Integer; cdecl;
  EVP_MD_block_size: function(const md: PEVP_MD): Integer; cdecl;
  EVP_MD_flags: function(const md: PEVP_MD): LongWord; cdecl;
  EVP_MD_type: function(const md: PEVP_MD): Integer; cdecl;
  EVP_MD_CTX_md: function(const ctx: PEVP_MD_CTX): PEVP_MD; cdecl;
  EVP_MD_CTX_size: function(const ctx: PEVP_MD_CTX): Integer; cdecl;
  EVP_MD_CTX_block_size: function(const ctx: PEVP_MD_CTX): Integer; cdecl;
  EVP_MD_CTX_type: function(const ctx: PEVP_MD_CTX): Integer; cdecl;
  EVP_get_digestbyname: function(const name: PAnsiChar): PEVP_MD; cdecl;
  EVP_get_digestbynid: function(nid: Integer): PEVP_MD; cdecl;
  EVP_get_digestbyobj: function(const o: PASN1_OBJECT): PEVP_MD; cdecl;
  
  // 特定摘要算法
  EVP_md_null: function: PEVP_MD; cdecl;
  EVP_md5: function: PEVP_MD; cdecl;
  EVP_md5_sha1: function: PEVP_MD; cdecl;
  EVP_sha1: function: PEVP_MD; cdecl;
  EVP_sha224: function: PEVP_MD; cdecl;
  EVP_sha256: function: PEVP_MD; cdecl;
  EVP_sha384: function: PEVP_MD; cdecl;
  EVP_sha512: function: PEVP_MD; cdecl;
  EVP_sha512_224: function: PEVP_MD; cdecl;
  EVP_sha512_256: function: PEVP_MD; cdecl;
  EVP_sha3_224: function: PEVP_MD; cdecl;
  EVP_sha3_256: function: PEVP_MD; cdecl;
  EVP_sha3_384: function: PEVP_MD; cdecl;
  EVP_sha3_512: function: PEVP_MD; cdecl;
  EVP_shake128: function: PEVP_MD; cdecl;
  EVP_shake256: function: PEVP_MD; cdecl;
  EVP_ripemd160: function: PEVP_MD; cdecl;
  EVP_whirlpool: function: PEVP_MD; cdecl;
  EVP_blake2b512: function: PEVP_MD; cdecl;
  EVP_blake2s256: function: PEVP_MD; cdecl;
  
  // EVP 密码函数
  EVP_CIPHER_CTX_new: function: PEVP_CIPHER_CTX; cdecl;
  EVP_CIPHER_CTX_free: procedure(ctx: PEVP_CIPHER_CTX); cdecl;
  EVP_CIPHER_CTX_reset: function(ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  EVP_CIPHER_CTX_copy: function(out_: PEVP_CIPHER_CTX; const in_: PEVP_CIPHER_CTX): Integer; cdecl;
  EVP_EncryptInit: function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; const key: PByte; const iv: PByte): Integer; cdecl;
  EVP_EncryptInit_ex: function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; impl: PENGINE; const key: PByte; const iv: PByte): Integer; cdecl;
  EVP_EncryptUpdate: function(ctx: PEVP_CIPHER_CTX; out_: PByte; outl: PInteger; const in_: PByte; inl: Integer): Integer; cdecl;
  EVP_EncryptFinal: function(ctx: PEVP_CIPHER_CTX; out_: PByte; outl: PInteger): Integer; cdecl;
  EVP_EncryptFinal_ex: function(ctx: PEVP_CIPHER_CTX; out_: PByte; outl: PInteger): Integer; cdecl;
  EVP_DecryptInit: function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; const key: PByte; const iv: PByte): Integer; cdecl;
  EVP_DecryptInit_ex: function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; impl: PENGINE; const key: PByte; const iv: PByte): Integer; cdecl;
  EVP_DecryptUpdate: function(ctx: PEVP_CIPHER_CTX; out_: PByte; outl: PInteger; const in_: PByte; inl: Integer): Integer; cdecl;
  EVP_DecryptFinal: function(ctx: PEVP_CIPHER_CTX; outm: PByte; outl: PInteger): Integer; cdecl;
  EVP_DecryptFinal_ex: function(ctx: PEVP_CIPHER_CTX; outm: PByte; outl: PInteger): Integer; cdecl;
  EVP_CipherInit: function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; const key: PByte; const iv: PByte; enc: Integer): Integer; cdecl;
  EVP_CipherInit_ex: function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; impl: PENGINE; const key: PByte; const iv: PByte; enc: Integer): Integer; cdecl;
  EVP_CipherUpdate: function(ctx: PEVP_CIPHER_CTX; out_: PByte; outl: PInteger; const in_: PByte; inl: Integer): Integer; cdecl;
  EVP_CipherFinal: function(ctx: PEVP_CIPHER_CTX; outm: PByte; outl: PInteger): Integer; cdecl;
  EVP_CipherFinal_ex: function(ctx: PEVP_CIPHER_CTX; outm: PByte; outl: PInteger): Integer; cdecl;
  EVP_CIPHER_CTX_ctrl: function(ctx: PEVP_CIPHER_CTX; type_: Integer; arg: Integer; ptr: Pointer): Integer; cdecl;
  EVP_CIPHER_CTX_set_key_length: function(ctx: PEVP_CIPHER_CTX; keylen: Integer): Integer; cdecl;
  EVP_CIPHER_CTX_set_padding: function(ctx: PEVP_CIPHER_CTX; pad: Integer): Integer; cdecl;
  EVP_CIPHER_CTX_key_length: function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  EVP_CIPHER_CTX_iv_length: function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  EVP_CIPHER_CTX_block_size: function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  EVP_CIPHER_CTX_cipher: function(const ctx: PEVP_CIPHER_CTX): PEVP_CIPHER; cdecl;
  EVP_CIPHER_key_length: function(const cipher: PEVP_CIPHER): Integer; cdecl;
  EVP_CIPHER_iv_length: function(const cipher: PEVP_CIPHER): Integer; cdecl;
  EVP_CIPHER_block_size: function(const cipher: PEVP_CIPHER): Integer; cdecl;
  EVP_CIPHER_flags: function(const cipher: PEVP_CIPHER): LongWord; cdecl;
  EVP_CIPHER_mode: function(const cipher: PEVP_CIPHER): Integer; cdecl;
  EVP_CIPHER_type: function(const cipher: PEVP_CIPHER): Integer; cdecl;
  EVP_CIPHER_nid: function(const cipher: PEVP_CIPHER): Integer; cdecl;
  EVP_get_cipherbyname: function(const name: PAnsiChar): PEVP_CIPHER; cdecl;
  EVP_get_cipherbynid: function(nid: Integer): PEVP_CIPHER; cdecl;
  EVP_get_cipherbyobj: function(const o: PASN1_OBJECT): PEVP_CIPHER; cdecl;
  
  // 特定密码算法
  EVP_enc_null: function: PEVP_CIPHER; cdecl;
  EVP_des_ecb: function: PEVP_CIPHER; cdecl;
  EVP_des_ede: function: PEVP_CIPHER; cdecl;
  EVP_des_ede3: function: PEVP_CIPHER; cdecl;
  EVP_des_ede_ecb: function: PEVP_CIPHER; cdecl;
  EVP_des_ede3_ecb: function: PEVP_CIPHER; cdecl;
  EVP_des_cfb64: function: PEVP_CIPHER; cdecl;
  EVP_des_cfb1: function: PEVP_CIPHER; cdecl;
  EVP_des_cfb8: function: PEVP_CIPHER; cdecl;
  EVP_des_ede_cfb64: function: PEVP_CIPHER; cdecl;
  EVP_des_ede3_cfb64: function: PEVP_CIPHER; cdecl;
  EVP_des_ede3_cfb1: function: PEVP_CIPHER; cdecl;
  EVP_des_ede3_cfb8: function: PEVP_CIPHER; cdecl;
  EVP_des_ofb: function: PEVP_CIPHER; cdecl;
  EVP_des_ede_ofb: function: PEVP_CIPHER; cdecl;
  EVP_des_ede3_ofb: function: PEVP_CIPHER; cdecl;
  EVP_des_cbc: function: PEVP_CIPHER; cdecl;
  EVP_des_ede_cbc: function: PEVP_CIPHER; cdecl;
  EVP_des_ede3_cbc: function: PEVP_CIPHER; cdecl;
  EVP_desx_cbc: function: PEVP_CIPHER; cdecl;
  EVP_des_ede3_wrap: function: PEVP_CIPHER; cdecl;
  EVP_rc4: function: PEVP_CIPHER; cdecl;
  EVP_rc4_40: function: PEVP_CIPHER; cdecl;
  EVP_rc4_hmac_md5: function: PEVP_CIPHER; cdecl;
  EVP_rc2_ecb: function: PEVP_CIPHER; cdecl;
  EVP_rc2_cbc: function: PEVP_CIPHER; cdecl;
  EVP_rc2_40_cbc: function: PEVP_CIPHER; cdecl;
  EVP_rc2_64_cbc: function: PEVP_CIPHER; cdecl;
  EVP_rc2_cfb64: function: PEVP_CIPHER; cdecl;
  EVP_rc2_ofb: function: PEVP_CIPHER; cdecl;
  EVP_bf_ecb: function: PEVP_CIPHER; cdecl;
  EVP_bf_cbc: function: PEVP_CIPHER; cdecl;
  EVP_bf_cfb64: function: PEVP_CIPHER; cdecl;
  EVP_bf_ofb: function: PEVP_CIPHER; cdecl;
  EVP_cast5_ecb: function: PEVP_CIPHER; cdecl;
  EVP_cast5_cbc: function: PEVP_CIPHER; cdecl;
  EVP_cast5_cfb64: function: PEVP_CIPHER; cdecl;
  EVP_cast5_ofb: function: PEVP_CIPHER; cdecl;
  EVP_aes_128_ecb: function: PEVP_CIPHER; cdecl;
  EVP_aes_128_cbc: function: PEVP_CIPHER; cdecl;
  EVP_aes_128_cfb1: function: PEVP_CIPHER; cdecl;
  EVP_aes_128_cfb8: function: PEVP_CIPHER; cdecl;
  EVP_aes_128_cfb128: function: PEVP_CIPHER; cdecl;
  EVP_aes_128_ofb: function: PEVP_CIPHER; cdecl;
  EVP_aes_128_ctr: function: PEVP_CIPHER; cdecl;
  EVP_aes_128_ccm: function: PEVP_CIPHER; cdecl;
  EVP_aes_128_gcm: function: PEVP_CIPHER; cdecl;
  EVP_aes_128_xts: function: PEVP_CIPHER; cdecl;
  EVP_aes_128_wrap: function: PEVP_CIPHER; cdecl;
  EVP_aes_128_wrap_pad: function: PEVP_CIPHER; cdecl;
  EVP_aes_128_ocb: function: PEVP_CIPHER; cdecl;
  EVP_aes_192_ecb: function: PEVP_CIPHER; cdecl;
  EVP_aes_192_cbc: function: PEVP_CIPHER; cdecl;
  EVP_aes_192_cfb1: function: PEVP_CIPHER; cdecl;
  EVP_aes_192_cfb8: function: PEVP_CIPHER; cdecl;
  EVP_aes_192_cfb128: function: PEVP_CIPHER; cdecl;
  EVP_aes_192_ofb: function: PEVP_CIPHER; cdecl;
  EVP_aes_192_ctr: function: PEVP_CIPHER; cdecl;
  EVP_aes_192_ccm: function: PEVP_CIPHER; cdecl;
  EVP_aes_192_gcm: function: PEVP_CIPHER; cdecl;
  EVP_aes_192_wrap: function: PEVP_CIPHER; cdecl;
  EVP_aes_192_wrap_pad: function: PEVP_CIPHER; cdecl;
  EVP_aes_192_ocb: function: PEVP_CIPHER; cdecl;
  EVP_aes_256_ecb: function: PEVP_CIPHER; cdecl;
  EVP_aes_256_cbc: function: PEVP_CIPHER; cdecl;
  EVP_aes_256_cfb1: function: PEVP_CIPHER; cdecl;
  EVP_aes_256_cfb8: function: PEVP_CIPHER; cdecl;
  EVP_aes_256_cfb128: function: PEVP_CIPHER; cdecl;
  EVP_aes_256_ofb: function: PEVP_CIPHER; cdecl;
  EVP_aes_256_ctr: function: PEVP_CIPHER; cdecl;
  EVP_aes_256_ccm: function: PEVP_CIPHER; cdecl;
  EVP_aes_256_gcm: function: PEVP_CIPHER; cdecl;
  EVP_aes_256_xts: function: PEVP_CIPHER; cdecl;
  EVP_aes_256_wrap: function: PEVP_CIPHER; cdecl;
  EVP_aes_256_wrap_pad: function: PEVP_CIPHER; cdecl;
  EVP_aes_256_ocb: function: PEVP_CIPHER; cdecl;
  EVP_aes_128_cbc_hmac_sha1: function: PEVP_CIPHER; cdecl;
  EVP_aes_256_cbc_hmac_sha1: function: PEVP_CIPHER; cdecl;
  EVP_aes_128_cbc_hmac_sha256: function: PEVP_CIPHER; cdecl;
  EVP_aes_256_cbc_hmac_sha256: function: PEVP_CIPHER; cdecl;
  EVP_aria_128_ecb: function: PEVP_CIPHER; cdecl;
  EVP_aria_128_cbc: function: PEVP_CIPHER; cdecl;
  EVP_aria_128_cfb1: function: PEVP_CIPHER; cdecl;
  EVP_aria_128_cfb8: function: PEVP_CIPHER; cdecl;
  EVP_aria_128_cfb128: function: PEVP_CIPHER; cdecl;
  EVP_aria_128_ctr: function: PEVP_CIPHER; cdecl;
  EVP_aria_128_ofb: function: PEVP_CIPHER; cdecl;
  EVP_aria_128_gcm: function: PEVP_CIPHER; cdecl;
  EVP_aria_128_ccm: function: PEVP_CIPHER; cdecl;
  EVP_aria_192_ecb: function: PEVP_CIPHER; cdecl;
  EVP_aria_192_cbc: function: PEVP_CIPHER; cdecl;
  EVP_aria_192_cfb1: function: PEVP_CIPHER; cdecl;
  EVP_aria_192_cfb8: function: PEVP_CIPHER; cdecl;
  EVP_aria_192_cfb128: function: PEVP_CIPHER; cdecl;
  EVP_aria_192_ctr: function: PEVP_CIPHER; cdecl;
  EVP_aria_192_ofb: function: PEVP_CIPHER; cdecl;
  EVP_aria_192_gcm: function: PEVP_CIPHER; cdecl;
  EVP_aria_192_ccm: function: PEVP_CIPHER; cdecl;
  EVP_aria_256_ecb: function: PEVP_CIPHER; cdecl;
  EVP_aria_256_cbc: function: PEVP_CIPHER; cdecl;
  EVP_aria_256_cfb1: function: PEVP_CIPHER; cdecl;
  EVP_aria_256_cfb8: function: PEVP_CIPHER; cdecl;
  EVP_aria_256_cfb128: function: PEVP_CIPHER; cdecl;
  EVP_aria_256_ctr: function: PEVP_CIPHER; cdecl;
  EVP_aria_256_ofb: function: PEVP_CIPHER; cdecl;
  EVP_aria_256_gcm: function: PEVP_CIPHER; cdecl;
  EVP_aria_256_ccm: function: PEVP_CIPHER; cdecl;
  EVP_camellia_128_ecb: function: PEVP_CIPHER; cdecl;
  EVP_camellia_128_cbc: function: PEVP_CIPHER; cdecl;
  EVP_camellia_128_cfb1: function: PEVP_CIPHER; cdecl;
  EVP_camellia_128_cfb8: function: PEVP_CIPHER; cdecl;
  EVP_camellia_128_cfb128: function: PEVP_CIPHER; cdecl;
  EVP_camellia_128_ofb: function: PEVP_CIPHER; cdecl;
  EVP_camellia_128_ctr: function: PEVP_CIPHER; cdecl;
  EVP_camellia_192_ecb: function: PEVP_CIPHER; cdecl;
  EVP_camellia_192_cbc: function: PEVP_CIPHER; cdecl;
  EVP_camellia_192_cfb1: function: PEVP_CIPHER; cdecl;
  EVP_camellia_192_cfb8: function: PEVP_CIPHER; cdecl;
  EVP_camellia_192_cfb128: function: PEVP_CIPHER; cdecl;
  EVP_camellia_192_ofb: function: PEVP_CIPHER; cdecl;
  EVP_camellia_192_ctr: function: PEVP_CIPHER; cdecl;
  EVP_camellia_256_ecb: function: PEVP_CIPHER; cdecl;
  EVP_camellia_256_cbc: function: PEVP_CIPHER; cdecl;
  EVP_camellia_256_cfb1: function: PEVP_CIPHER; cdecl;
  EVP_camellia_256_cfb8: function: PEVP_CIPHER; cdecl;
  EVP_camellia_256_cfb128: function: PEVP_CIPHER; cdecl;
  EVP_camellia_256_ofb: function: PEVP_CIPHER; cdecl;
  EVP_camellia_256_ctr: function: PEVP_CIPHER; cdecl;
  EVP_chacha20: function: PEVP_CIPHER; cdecl;
  EVP_chacha20_poly1305: function: PEVP_CIPHER; cdecl;

// 库加载和初始化函数
function LoadOpenSSLLibrary: Boolean;
procedure UnloadOpenSSLLibrary;
function GetOpenSSLVersion: string;
function GetOpenSSLErrorString: string;
function GetCryptoLibHandle: TLibHandle;
function GetSSLLibHandle: TLibHandle;

// Helper functions for module loading compatibility (for RAND, EVP, etc.)
function GetCryptoProcAddress(const ProcName: string): Pointer;

// 辅助函数
function SSL_set_tlsext_host_name(ssl: PSSL; const name: PAnsiChar): Integer;

implementation

function LoadOpenSSLLibrary: Boolean;
var
  LCryptoHandle, LSSLHandle: TLibHandle;

  procedure LoadFunc(AHandle: TLibHandle; const AName: string; var AFunc);
  var
    P: Pointer;
  begin
    P := TOpenSSLLoader.GetFunction(AHandle, AName);
    if P = nil then
      raise ESSLInitializationException.CreateFmt('Failed to load function: %s', [AName]);
    Pointer(AFunc) := P;
  end;

  procedure TryLoadFunc(AHandle: TLibHandle; const AName: string; var AFunc);
  var
    P: Pointer;
  begin
    P := TOpenSSLLoader.GetFunction(AHandle, AName);
    if P <> nil then
      Pointer(AFunc) := P;
  end;

begin
  Result := False;

  if TOpenSSLLoader.IsModuleLoaded(osmCore) then
  begin
    Result := True;
    Exit;
  end;

  // Phase 3.3 P0+ - 使用统一的动态库加载器（替换 ~30 行重复代码）
  LCryptoHandle := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
  if LCryptoHandle = 0 then
    raise ESSLInitializationException.Create('Failed to load crypto library');

  LSSLHandle := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
  if LSSLHandle = 0 then
    raise ESSLInitializationException.Create('Failed to load SSL library');
  
  try
    // 加载 SSL 库函数
    LoadFunc(LSSLHandle, 'OPENSSL_init_ssl', OPENSSL_init_ssl);
    LoadFunc(LCryptoHandle, 'OPENSSL_cleanup', OPENSSL_cleanup);
    
    // SSL_CTX 函数
    LoadFunc(LSSLHandle, 'SSL_CTX_new', SSL_CTX_new);
    LoadFunc(LSSLHandle, 'SSL_CTX_free', SSL_CTX_free);
    LoadFunc(LSSLHandle, 'SSL_CTX_set_options', SSL_CTX_set_options);
    LoadFunc(LSSLHandle, 'SSL_CTX_clear_options', SSL_CTX_clear_options);
    LoadFunc(LSSLHandle, 'SSL_CTX_get_options', SSL_CTX_get_options);
    LoadFunc(LSSLHandle, 'SSL_CTX_set_verify', SSL_CTX_set_verify);
    LoadFunc(LSSLHandle, 'SSL_CTX_set_verify_depth', SSL_CTX_set_verify_depth);
    LoadFunc(LSSLHandle, 'SSL_CTX_set_default_verify_paths', SSL_CTX_set_default_verify_paths);
    LoadFunc(LSSLHandle, 'SSL_CTX_load_verify_locations', SSL_CTX_load_verify_locations);
    LoadFunc(LSSLHandle, 'SSL_CTX_use_certificate_file', SSL_CTX_use_certificate_file);
    LoadFunc(LSSLHandle, 'SSL_CTX_use_certificate_chain_file', SSL_CTX_use_certificate_chain_file);
    LoadFunc(LSSLHandle, 'SSL_CTX_use_PrivateKey_file', SSL_CTX_use_PrivateKey_file);
    LoadFunc(LSSLHandle, 'SSL_CTX_check_private_key', SSL_CTX_check_private_key);
    LoadFunc(LSSLHandle, 'SSL_CTX_set_cipher_list', SSL_CTX_set_cipher_list);
    TryLoadFunc(LSSLHandle, 'SSL_CTX_set_ciphersuites', SSL_CTX_set_ciphersuites);
    TryLoadFunc(LSSLHandle, 'SSL_CTX_set_min_proto_version', SSL_CTX_set_min_proto_version);
    TryLoadFunc(LSSLHandle, 'SSL_CTX_set_max_proto_version', SSL_CTX_set_max_proto_version);
    LoadFunc(LSSLHandle, 'SSL_CTX_get_cert_store', SSL_CTX_get_cert_store);
    LoadFunc(LSSLHandle, 'SSL_CTX_set_alpn_protos', SSL_CTX_set_alpn_protos);
    LoadFunc(LSSLHandle, 'SSL_CTX_set_alpn_select_cb', SSL_CTX_set_alpn_select_cb);
    LoadFunc(LSSLHandle, 'SSL_CTX_set_psk_client_callback', SSL_CTX_set_psk_client_callback);
    LoadFunc(LSSLHandle, 'SSL_CTX_set_psk_server_callback', SSL_CTX_set_psk_server_callback);
    // 加载新增的 SSL_CTX 函数
    TryLoadFunc(LSSLHandle, 'SSL_CTX_set_info_callback', SSL_CTX_set_info_callback);
    TryLoadFunc(LSSLHandle, 'SSL_CTX_get_info_callback', SSL_CTX_get_info_callback);
    TryLoadFunc(LSSLHandle, 'SSL_CTX_set_msg_callback', SSL_CTX_set_msg_callback);
    TryLoadFunc(LSSLHandle, 'SSL_CTX_set_default_passwd_cb', SSL_CTX_set_default_passwd_cb);
    TryLoadFunc(LSSLHandle, 'SSL_CTX_set_default_passwd_cb_userdata', SSL_CTX_set_default_passwd_cb_userdata);
    TryLoadFunc(LSSLHandle, 'SSL_CTX_set_session_id_context', SSL_CTX_set_session_id_context);
    TryLoadFunc(LSSLHandle, 'SSL_CTX_set_session_cache_mode', SSL_CTX_set_session_cache_mode);
    TryLoadFunc(LSSLHandle, 'SSL_CTX_get_session_cache_mode', SSL_CTX_get_session_cache_mode);
    TryLoadFunc(LSSLHandle, 'SSL_CTX_set_timeout', SSL_CTX_set_timeout);
    TryLoadFunc(LSSLHandle, 'SSL_CTX_get_timeout', SSL_CTX_get_timeout);
    TryLoadFunc(LSSLHandle, 'SSL_CTX_sess_set_new_cb', SSL_CTX_sess_set_new_cb);
    TryLoadFunc(LSSLHandle, 'SSL_CTX_sess_set_remove_cb', SSL_CTX_sess_set_remove_cb);
    TryLoadFunc(LSSLHandle, 'SSL_CTX_sess_set_get_cb', SSL_CTX_sess_set_get_cb);
    
    // SSL 函数
    LoadFunc(LSSLHandle, 'SSL_new', SSL_new);
    LoadFunc(LSSLHandle, 'SSL_free', SSL_free);
    LoadFunc(LSSLHandle, 'SSL_set_fd', SSL_set_fd);
    LoadFunc(LSSLHandle, 'SSL_set_bio', SSL_set_bio);
    LoadFunc(LSSLHandle, 'SSL_get_rbio', SSL_get_rbio);
    LoadFunc(LSSLHandle, 'SSL_get_wbio', SSL_get_wbio);
    LoadFunc(LSSLHandle, 'SSL_set_connect_state', SSL_set_connect_state);
    LoadFunc(LSSLHandle, 'SSL_set_accept_state', SSL_set_accept_state);
    LoadFunc(LSSLHandle, 'SSL_connect', SSL_connect);
    LoadFunc(LSSLHandle, 'SSL_accept', SSL_accept);
    LoadFunc(LSSLHandle, 'SSL_do_handshake', SSL_do_handshake);
    LoadFunc(LSSLHandle, 'SSL_read', SSL_read);
    LoadFunc(LSSLHandle, 'SSL_write', SSL_write);
    LoadFunc(LSSLHandle, 'SSL_pending', SSL_pending);
    LoadFunc(LSSLHandle, 'SSL_shutdown', SSL_shutdown);
    LoadFunc(LSSLHandle, 'SSL_get_error', SSL_get_error);
    // SSL_get_peer_certificate 在 OpenSSL 3.0 中改名为 SSL_get1_peer_certificate
    TryLoadFunc(LSSLHandle, 'SSL_get_peer_certificate', SSL_get_peer_certificate);
    TryLoadFunc(LSSLHandle, 'SSL_get1_peer_certificate', SSL_get_peer_certificate);
    TryLoadFunc(LSSLHandle, 'SSL_get_peer_cert_chain', SSL_get_peer_cert_chain);
    LoadFunc(LSSLHandle, 'SSL_get_verify_result', SSL_get_verify_result);
    LoadFunc(LSSLHandle, 'SSL_ctrl', SSL_ctrl);
    LoadFunc(LSSLHandle, 'SSL_get_servername', SSL_get_servername);
    LoadFunc(LSSLHandle, 'SSL_get_servername_type', SSL_get_servername_type);
    LoadFunc(LSSLHandle, 'SSL_get_version', SSL_get_version);
    LoadFunc(LSSLHandle, 'SSL_get_current_cipher', SSL_get_current_cipher);
    LoadFunc(LSSLHandle, 'SSL_is_init_finished', SSL_is_init_finished);
    LoadFunc(LSSLHandle, 'SSL_in_init', SSL_in_init);
    LoadFunc(LSSLHandle, 'SSL_in_before', SSL_in_before);
    LoadFunc(LSSLHandle, 'SSL_is_server', SSL_is_server);
    // 加载新增的 SSL 函数
    TryLoadFunc(LSSLHandle, 'SSL_set_info_callback', SSL_set_info_callback);
    TryLoadFunc(LSSLHandle, 'SSL_get_info_callback', SSL_get_info_callback);
    TryLoadFunc(LSSLHandle, 'SSL_set_msg_callback', SSL_set_msg_callback);
    TryLoadFunc(LSSLHandle, 'SSL_set_msg_callback_arg', SSL_set_msg_callback_arg);
    TryLoadFunc(LSSLHandle, 'SSL_session_reused', SSL_session_reused);
    TryLoadFunc(LSSLHandle, 'SSL_get_session', SSL_get_session);
    TryLoadFunc(LSSLHandle, 'SSL_set_session', SSL_set_session);
    TryLoadFunc(LSSLHandle, 'SSL_get_SSL_CTX', SSL_get_SSL_CTX);
    TryLoadFunc(LSSLHandle, 'SSL_set_SSL_CTX', SSL_set_SSL_CTX);
    TryLoadFunc(LSSLHandle, 'SSL_set_verify', SSL_set_verify);
    TryLoadFunc(LSSLHandle, 'SSL_set_verify_depth', SSL_set_verify_depth);
    TryLoadFunc(LSSLHandle, 'SSL_get_verify_mode', SSL_get_verify_mode);
    TryLoadFunc(LSSLHandle, 'SSL_get_verify_depth', SSL_get_verify_depth);
    TryLoadFunc(LSSLHandle, 'SSL_get_verify_callback', SSL_get_verify_callback);
    
    // SSL_METHOD 函数
    LoadFunc(LSSLHandle, 'TLS_method', TLS_method);
    LoadFunc(LSSLHandle, 'TLS_server_method', TLS_server_method);
    LoadFunc(LSSLHandle, 'TLS_client_method', TLS_client_method);
    // SSLv23_* 方法在 OpenSSL 3.0 中已被 TLS_* 方法替代
    try
      LoadFunc(LSSLHandle, 'SSLv23_method', SSLv23_method);
      LoadFunc(LSSLHandle, 'SSLv23_server_method', SSLv23_server_method);
      LoadFunc(LSSLHandle, 'SSLv23_client_method', SSLv23_client_method);
    except
      // 如果失败，使用 TLS_* 方法作为替代
      SSLv23_method := TLS_method;
      SSLv23_server_method := TLS_server_method;
      SSLv23_client_method := TLS_client_method;
    end;
    
    // BIO 函数
    LoadFunc(LCryptoHandle, 'BIO_new', BIO_new);
    LoadFunc(LCryptoHandle, 'BIO_free', BIO_free);
    LoadFunc(LCryptoHandle, 'BIO_read', BIO_read);
    LoadFunc(LCryptoHandle, 'BIO_write', BIO_write);
    LoadFunc(LCryptoHandle, 'BIO_ctrl', BIO_ctrl);
    LoadFunc(LCryptoHandle, 'BIO_ctrl_pending', BIO_ctrl_pending);
    LoadFunc(LCryptoHandle, 'BIO_ctrl_wpending', BIO_ctrl_wpending);
    LoadFunc(LCryptoHandle, 'BIO_new_socket', BIO_new_socket);
    LoadFunc(LCryptoHandle, 'BIO_new_connect', BIO_new_connect);
    LoadFunc(LCryptoHandle, 'BIO_new_mem_buf', BIO_new_mem_buf);
    LoadFunc(LCryptoHandle, 'BIO_s_mem', BIO_s_mem);
    LoadFunc(LCryptoHandle, 'BIO_s_connect', BIO_s_connect);
    LoadFunc(LCryptoHandle, 'BIO_s_socket', BIO_s_socket);
    // 加载新增的 BIO 函数
    TryLoadFunc(LCryptoHandle, 'BIO_push', BIO_push);
    TryLoadFunc(LCryptoHandle, 'BIO_pop', BIO_pop);
    TryLoadFunc(LCryptoHandle, 'BIO_flush', BIO_flush);
    TryLoadFunc(LCryptoHandle, 'BIO_get_retry_BIO', BIO_get_retry_BIO);
    TryLoadFunc(LCryptoHandle, 'BIO_get_retry_reason', BIO_get_retry_reason);
    TryLoadFunc(LCryptoHandle, 'BIO_should_retry', BIO_should_retry);
    TryLoadFunc(LCryptoHandle, 'BIO_should_read', BIO_should_read);
    TryLoadFunc(LCryptoHandle, 'BIO_should_write', BIO_should_write);
    TryLoadFunc(LCryptoHandle, 'BIO_should_io_special', BIO_should_io_special);
    TryLoadFunc(LCryptoHandle, 'BIO_retry_type', BIO_retry_type);
    TryLoadFunc(LCryptoHandle, 'BIO_get_fd', BIO_get_fd);
    TryLoadFunc(LCryptoHandle, 'BIO_set_fd', BIO_set_fd);
    TryLoadFunc(LCryptoHandle, 'BIO_get_close', BIO_get_close);
    TryLoadFunc(LCryptoHandle, 'BIO_set_close', BIO_set_close);
    
    // X509 证书函数
    LoadFunc(LCryptoHandle, 'X509_free', X509_free);
    LoadFunc(LCryptoHandle, 'X509_dup', X509_dup);
    LoadFunc(LCryptoHandle, 'X509_get_subject_name', X509_get_subject_name);
    LoadFunc(LCryptoHandle, 'X509_get_issuer_name', X509_get_issuer_name);
    LoadFunc(LCryptoHandle, 'X509_NAME_oneline', X509_NAME_oneline);
    LoadFunc(LCryptoHandle, 'X509_NAME_print_ex', X509_NAME_print_ex);
    LoadFunc(LCryptoHandle, 'X509_get_serialNumber', X509_get_serialNumber);
    LoadFunc(LCryptoHandle, 'X509_get0_notBefore', X509_get0_notBefore);
    LoadFunc(LCryptoHandle, 'X509_get0_notAfter', X509_get0_notAfter);
    LoadFunc(LCryptoHandle, 'X509_get_pubkey', X509_get_pubkey);
    LoadFunc(LCryptoHandle, 'X509_get_version', X509_get_version);
    LoadFunc(LCryptoHandle, 'X509_get_signature_nid', X509_get_signature_nid);
    LoadFunc(LCryptoHandle, 'X509_verify_cert_error_string', X509_verify_cert_error_string);
    LoadFunc(LCryptoHandle, 'X509_STORE_new', X509_STORE_new);
    LoadFunc(LCryptoHandle, 'X509_STORE_free', X509_STORE_free);
    LoadFunc(LCryptoHandle, 'X509_STORE_add_cert', X509_STORE_add_cert);
    LoadFunc(LCryptoHandle, 'X509_STORE_set_flags', X509_STORE_set_flags);
    
    // EVP_PKEY 函数
    TryLoadFunc(LCryptoHandle, 'EVP_PKEY_free', EVP_PKEY_free);
    TryLoadFunc(LCryptoHandle, 'EVP_PKEY_bits', EVP_PKEY_bits);
    TryLoadFunc(LCryptoHandle, 'EVP_PKEY_id', EVP_PKEY_id);
    
    // EVP 摘要函数
    TryLoadFunc(LCryptoHandle, 'EVP_MD_CTX_new', EVP_MD_CTX_new);
    TryLoadFunc(LCryptoHandle, 'EVP_MD_CTX_free', EVP_MD_CTX_free);
    TryLoadFunc(LCryptoHandle, 'EVP_MD_CTX_reset', EVP_MD_CTX_reset);
    TryLoadFunc(LCryptoHandle, 'EVP_DigestInit_ex', EVP_DigestInit_ex);
    TryLoadFunc(LCryptoHandle, 'EVP_DigestUpdate', EVP_DigestUpdate);
    TryLoadFunc(LCryptoHandle, 'EVP_DigestFinal_ex', EVP_DigestFinal_ex);
    TryLoadFunc(LCryptoHandle, 'EVP_get_digestbyname', EVP_get_digestbyname);
    TryLoadFunc(LCryptoHandle, 'EVP_md5', EVP_md5);
    TryLoadFunc(LCryptoHandle, 'EVP_sha1', EVP_sha1);
    TryLoadFunc(LCryptoHandle, 'EVP_sha224', EVP_sha224);
    TryLoadFunc(LCryptoHandle, 'EVP_sha256', EVP_sha256);
    TryLoadFunc(LCryptoHandle, 'EVP_sha384', EVP_sha384);
    TryLoadFunc(LCryptoHandle, 'EVP_sha512', EVP_sha512);
    TryLoadFunc(LCryptoHandle, 'EVP_sha512_224', EVP_sha512_224);
    TryLoadFunc(LCryptoHandle, 'EVP_sha512_256', EVP_sha512_256);
    TryLoadFunc(LCryptoHandle, 'EVP_ripemd160', EVP_ripemd160);
    
    // EVP 密码函数 - 核心操作
    TryLoadFunc(LCryptoHandle, 'EVP_CIPHER_CTX_new', EVP_CIPHER_CTX_new);
    TryLoadFunc(LCryptoHandle, 'EVP_CIPHER_CTX_free', EVP_CIPHER_CTX_free);
    TryLoadFunc(LCryptoHandle, 'EVP_CIPHER_CTX_reset', EVP_CIPHER_CTX_reset);
    TryLoadFunc(LCryptoHandle, 'EVP_CIPHER_CTX_ctrl', EVP_CIPHER_CTX_ctrl);
    TryLoadFunc(LCryptoHandle, 'EVP_EncryptInit_ex', EVP_EncryptInit_ex);
    TryLoadFunc(LCryptoHandle, 'EVP_EncryptUpdate', EVP_EncryptUpdate);
    TryLoadFunc(LCryptoHandle, 'EVP_EncryptFinal_ex', EVP_EncryptFinal_ex);
    TryLoadFunc(LCryptoHandle, 'EVP_DecryptInit_ex', EVP_DecryptInit_ex);
    TryLoadFunc(LCryptoHandle, 'EVP_DecryptUpdate', EVP_DecryptUpdate);
    TryLoadFunc(LCryptoHandle, 'EVP_DecryptFinal_ex', EVP_DecryptFinal_ex);
    TryLoadFunc(LCryptoHandle, 'EVP_CipherInit_ex', EVP_CipherInit_ex);
    TryLoadFunc(LCryptoHandle, 'EVP_CipherUpdate', EVP_CipherUpdate);
    TryLoadFunc(LCryptoHandle, 'EVP_CipherFinal_ex', EVP_CipherFinal_ex);
    
    // EVP 密码算法 - AES
    TryLoadFunc(LCryptoHandle, 'EVP_aes_128_ecb', EVP_aes_128_ecb);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_128_cbc', EVP_aes_128_cbc);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_128_cfb128', EVP_aes_128_cfb128);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_128_ofb', EVP_aes_128_ofb);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_128_ctr', EVP_aes_128_ctr);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_128_gcm', EVP_aes_128_gcm);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_128_ccm', EVP_aes_128_ccm);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_128_xts', EVP_aes_128_xts);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_192_ecb', EVP_aes_192_ecb);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_192_cbc', EVP_aes_192_cbc);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_192_cfb128', EVP_aes_192_cfb128);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_192_ofb', EVP_aes_192_ofb);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_192_ctr', EVP_aes_192_ctr);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_192_gcm', EVP_aes_192_gcm);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_192_ccm', EVP_aes_192_ccm);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_256_ecb', EVP_aes_256_ecb);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_256_cbc', EVP_aes_256_cbc);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_256_cfb128', EVP_aes_256_cfb128);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_256_ofb', EVP_aes_256_ofb);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_256_ctr', EVP_aes_256_ctr);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_256_gcm', EVP_aes_256_gcm);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_256_ccm', EVP_aes_256_ccm);
    TryLoadFunc(LCryptoHandle, 'EVP_aes_256_xts', EVP_aes_256_xts);
    
    // EVP 密码算法 - ChaCha20
    TryLoadFunc(LCryptoHandle, 'EVP_chacha20', EVP_chacha20);
    TryLoadFunc(LCryptoHandle, 'EVP_chacha20_poly1305', EVP_chacha20_poly1305);
    
    // 错误处理函数
    LoadFunc(LCryptoHandle, 'ERR_get_error', ERR_get_error);
    LoadFunc(LCryptoHandle, 'ERR_peek_error', ERR_peek_error);
    LoadFunc(LCryptoHandle, 'ERR_error_string', ERR_error_string);
    LoadFunc(LCryptoHandle, 'ERR_error_string_n', ERR_error_string_n);
    LoadFunc(LCryptoHandle, 'ERR_clear_error', ERR_clear_error);
    LoadFunc(LCryptoHandle, 'ERR_print_errors_fp', ERR_print_errors_fp);
    
    // Crypto 函数 - 旧版本线程锁函数（OpenSSL 1.1.0+ 已移除）
    TryLoadFunc(LCryptoHandle, 'CRYPTO_num_locks', CRYPTO_num_locks);
    TryLoadFunc(LCryptoHandle, 'CRYPTO_set_locking_callback', CRYPTO_set_locking_callback);
    TryLoadFunc(LCryptoHandle, 'CRYPTO_set_id_callback', CRYPTO_set_id_callback);
    // OPENSSL_version_num
    TryLoadFunc(LCryptoHandle, 'OPENSSL_version_num', OPENSSL_version_num);
    TryLoadFunc(LCryptoHandle, 'OpenSSL_version_num', OPENSSL_version_num);
    // OPENSSL_version
    TryLoadFunc(LCryptoHandle, 'OPENSSL_version', OPENSSL_version);
    TryLoadFunc(LCryptoHandle, 'OpenSSL_version', OPENSSL_version);
    
    // SSL_SESSION 函数
    TryLoadFunc(LSSLHandle, 'SSL_SESSION_new', SSL_SESSION_new);
    TryLoadFunc(LSSLHandle, 'SSL_SESSION_free', SSL_SESSION_free);
    TryLoadFunc(LSSLHandle, 'SSL_SESSION_up_ref', SSL_SESSION_up_ref);
    TryLoadFunc(LSSLHandle, 'SSL_SESSION_get_id', SSL_SESSION_get_id);
    TryLoadFunc(LSSLHandle, 'SSL_SESSION_get_time', SSL_SESSION_get_time);
    TryLoadFunc(LSSLHandle, 'SSL_SESSION_set_time', SSL_SESSION_set_time);
    TryLoadFunc(LSSLHandle, 'SSL_SESSION_get_timeout', SSL_SESSION_get_timeout);
    TryLoadFunc(LSSLHandle, 'SSL_SESSION_set_timeout', SSL_SESSION_set_timeout);
    TryLoadFunc(LSSLHandle, 'SSL_SESSION_has_ticket', SSL_SESSION_has_ticket);
    TryLoadFunc(LSSLHandle, 'SSL_SESSION_get_ticket_lifetime_hint', SSL_SESSION_get_ticket_lifetime_hint);
    
    // SSL_CIPHER 函数
    TryLoadFunc(LSSLHandle, 'SSL_CIPHER_get_name', SSL_CIPHER_get_name);
    TryLoadFunc(LSSLHandle, 'SSL_CIPHER_get_bits', SSL_CIPHER_get_bits);
    TryLoadFunc(LSSLHandle, 'SSL_CIPHER_get_version', SSL_CIPHER_get_version);
    TryLoadFunc(LSSLHandle, 'SSL_CIPHER_description', SSL_CIPHER_description);
    TryLoadFunc(LSSLHandle, 'SSL_CIPHER_get_id', SSL_CIPHER_get_id);
    
    // 初始化 OpenSSL
    if Assigned(OPENSSL_init_ssl) then
      OPENSSL_init_ssl(0, nil);

    TOpenSSLLoader.SetModuleLoaded(osmCore, True);
    Result := True;
    
  except
    on E: Exception do
    begin
      UnloadOpenSSLLibrary;
      raise;
    end;
  end;
end;

procedure UnloadOpenSSLLibrary;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmCore) then
  begin
    if Assigned(OPENSSL_cleanup) then
      OPENSSL_cleanup;
  end;

  // 注意: 库卸载由 TOpenSSLLoader 自动处理（在 finalization 部分）
  TOpenSSLLoader.SetModuleLoaded(osmCore, False);
end;


function GetOpenSSLVersion: string;
var
  VerNum: LongWord;
  VerStr: PAnsiChar;
begin
  Result := '';
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    Exit;
    
  if Assigned(OPENSSL_version_num) then
  begin
    VerNum := LongWord(OPENSSL_version_num());
    Result := Format('%d.%d.%d', [
      (VerNum shr 28) and $F,
      (VerNum shr 20) and $FF,
      (VerNum shr 12) and $FF
    ]);
  end;
  
  if Assigned(OPENSSL_version) then
  begin
    VerStr := OPENSSL_version(0);
    if VerStr <> nil then
      Result := Result + ' (' + string(VerStr) + ')';
  end;
end;

function GetOpenSSLErrorString: string;
var
  ErrCode: LongWord;
  Buffer: array[0..255] of AnsiChar;
begin
  Result := '';
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    Exit;
    
  if Assigned(ERR_get_error) and Assigned(ERR_error_string_n) then
  begin
    ErrCode := LongWord(ERR_get_error());
    if ErrCode <> 0 then
    begin
      ERR_error_string_n(ErrCode, @Buffer[0], SizeOf(Buffer));
      Result := string(Buffer);
    end;
  end;
end;

function SSL_set_tlsext_host_name(ssl: PSSL; const name: PAnsiChar): Integer;
begin
  // SSL_set_tlsext_host_name 是一个宏，实际调用 SSL_ctrl
  if Assigned(SSL_ctrl) then
    Result := SSL_ctrl(ssl, SSL_CTRL_SET_TLSEXT_HOSTNAME, TLSEXT_NAMETYPE_host_name, Pointer(name))
  else
    Result := 0;
end;

function GetCryptoLibHandle: TLibHandle;
begin
  Result := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
end;

function GetSSLLibHandle: TLibHandle;
begin
  Result := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
end;

function GetCryptoProcAddress(const ProcName: string): Pointer;
var
  LHandle: TLibHandle;
begin
  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
  Result := TOpenSSLLoader.GetFunction(LHandle, ProcName);
end;

initialization

finalization
  UnloadOpenSSLLibrary;

end.