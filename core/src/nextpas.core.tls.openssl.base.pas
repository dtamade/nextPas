unit nextpas.core.tls.openssl.base;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, ctypes;

type
  // Basic C types mapping
  time_t = clong;
  Ptime_t = ^time_t;
  off_t = Int64;
  size_t = NativeUInt;
  Psize_t = ^size_t;
  ssize_t = NativeInt;
  
  // C tm structure for time handling
  TM = record
    tm_sec: cint;    // seconds after the minute [0-60]
    tm_min: cint;    // minutes after the hour [0-59]
    tm_hour: cint;   // hours since midnight [0-23]
    tm_mday: cint;   // day of the month [1-31]
    tm_mon: cint;    // months since January [0-11]
    tm_year: cint;   // years since 1900
    tm_wday: cint;   // days since Sunday [0-6]
    tm_yday: cint;   // days since January 1 [0-365]
    tm_isdst: cint;  // Daylight Saving Time flag
  end;
  PTM = ^TM;
  
  // OpenSSL version info
  POPENSSL_VERSION_NUMBER = ^OPENSSL_VERSION_NUMBER;
  OPENSSL_VERSION_NUMBER = LongWord;
  
  // OpenSSL basic integer types
  TOpenSSL_Int = cint;
  POpenSSL_Int = ^TOpenSSL_Int;
  TOpenSSL_UInt = cuint;
  POpenSSL_UInt = ^TOpenSSL_UInt;
  TOpenSSL_Long = clong;
  POpenSSL_Long = ^TOpenSSL_Long;
  TOpenSSL_ULong = culong;
  POpenSSL_ULong = ^TOpenSSL_ULong;
  TOpenSSL_Size = size_t;
  POpenSSL_Size = ^TOpenSSL_Size;
  
  // Type aliases without underscores for compatibility
  OpenSSLInt = TOpenSSL_Int;
  POpenSSLInt = POpenSSL_Int;
  TOpenSSLInt = TOpenSSL_Int;
  OpenSSLUInt = TOpenSSL_UInt;
  POpenSSLUInt = POpenSSL_UInt;
  TOpenSSLUInt = TOpenSSL_UInt;
  OpenSSLLong = TOpenSSL_Long;
  POpenSSLLong = POpenSSL_Long;
  TOpenSSLLong = TOpenSSL_Long;
  OpenSSLULong = TOpenSSL_ULong;
  POpenSSLULong = POpenSSL_ULong;
  TOpenSSLULong = TOpenSSL_ULong;
  OpenSSLSizeT = TOpenSSL_Size;
  POpenSSLSizeT = POpenSSL_Size;
  TOpenSSLSizeT = TOpenSSL_Size;
  
  // Basic OpenSSL types
  OPENSSL_CTX = Pointer;
  POPENSSL_CTX = ^OPENSSL_CTX;
  
  PBIO = Pointer;
  PPBIO = ^PBIO;
  PBIO_METHOD = Pointer;
  
  PSSL = Pointer;
  PPSSL = ^PSSL;
  PSSL_CTX = Pointer;
  PPSSL_CTX = ^PSSL_CTX;
  PSSL_METHOD = Pointer;
  PSSL_CIPHER = Pointer;
  PPSSL_CIPHER = ^PSSL_CIPHER;
  PSSL_SESSION = Pointer;
  PPSSL_SESSION = ^PSSL_SESSION;
  
  // X509 Certificate types
  PX509 = Pointer;
  PPX509 = ^PX509;
  PX509_NAME = Pointer;
  PPX509_NAME = ^PX509_NAME;
  PX509_NAME_ENTRY = Pointer;
  PPX509_NAME_ENTRY = ^PX509_NAME_ENTRY;
  PX509_EXTENSION = Pointer;
  PPX509_EXTENSION = ^PX509_EXTENSION;
  PX509_REQ = Pointer;
  PPX509_REQ = ^PX509_REQ;
  PX509_CRL = Pointer;
  PPX509_CRL = ^PX509_CRL;
  PX509_SIG = Pointer;
  PPX509_SIG = ^PX509_SIG;
  PX509_STORE = Pointer;
  PPX509_STORE = ^PX509_STORE;
  PX509_STORE_CTX = Pointer;
  PPX509_STORE_CTX = ^PX509_STORE_CTX;
  PX509_OBJECT = Pointer;
  PX509_LOOKUP = Pointer;
  PX509_LOOKUP_METHOD = Pointer;
  PX509_VERIFY_PARAM = Pointer;
  PPX509_VERIFY_PARAM = ^PX509_VERIFY_PARAM;
  PX509_ALGOR = Pointer;
  PPX509_ALGOR = ^PX509_ALGOR;
  
  // Stack types
  OPENSSL_STACK = record end;  // Generic stack structure
  POPENSSL_STACK = ^OPENSSL_STACK;
  PPOPENSSL_STACK = ^POPENSSL_STACK;
  
  PSTACK_OF_X509 = Pointer;
  PPSTACK_OF_X509 = ^PSTACK_OF_X509;
  PSTACK_OF_X509_NAME = Pointer;
  PSTACK_OF_X509_EXTENSION = Pointer;
  PPSTACK_OF_X509_EXTENSION = ^PSTACK_OF_X509_EXTENSION;
  PSTACK_OF_X509_CRL = Pointer;
  PSTACK_OF_SSL_CIPHER = Pointer;
  PPSTACK_OF_SSL_CIPHER = ^PSTACK_OF_SSL_CIPHER;
  PSTACK_OF_GENERAL_NAME = Pointer;
  PSTACK_OF_DIST_POINT = Pointer;
  
  // EVP types
  PEVP_MD = Pointer;
  PPEVP_MD = ^PEVP_MD;
  PEVP_MD_CTX = Pointer;
  PPEVP_MD_CTX = ^PEVP_MD_CTX;
  PEVP_CIPHER = Pointer;
  PPEVP_CIPHER = ^PEVP_CIPHER;
  PEVP_CIPHER_CTX = Pointer;
  PPEVP_CIPHER_CTX = ^PEVP_CIPHER_CTX;
  PEVP_PKEY = Pointer;
  PPEVP_PKEY = ^PEVP_PKEY;
  PEVP_PKEY_CTX = Pointer;
  PPEVP_PKEY_CTX = ^PEVP_PKEY_CTX;
  PEVP_ENCODE_CTX = Pointer;  // Base64 encoding context
  PPEVP_ENCODE_CTX = ^PEVP_ENCODE_CTX;
  
  // HMAC types
  PHMAC_CTX = Pointer;
  PPHMAC_CTX = ^PHMAC_CTX;
  
  // Big Number types
  PBIGNUM = Pointer;
  PPBIGNUM = ^PBIGNUM;
  PPPBIGNUM = ^PPBIGNUM;
  PBN_CTX = Pointer;
  PBN_MONT_CTX = Pointer;
  PPBN_MONT_CTX = ^PBN_MONT_CTX;
  PBN_BLINDING = Pointer;
  PBN_RECP_CTX = Pointer;
  PBN_GENCB = Pointer;
  
  // RSA types
  PRSA = Pointer;
  PPRSA = ^PRSA;
  PRSA_METHOD = Pointer;
  
  // DSA types
  PDSA = Pointer;
  PPDSA = ^PDSA;
  PDSA_METHOD = Pointer;
  PDSA_SIG = Pointer;
  PPDSA_SIG = ^PDSA_SIG;
  
  // DH types
  PDH = Pointer;
  PPDH = ^PDH;
  PDH_METHOD = Pointer;
  
  // EC types
  PEC_KEY = Pointer;
  PPEC_KEY = ^PEC_KEY;
  PEC_GROUP = Pointer;
  PPEC_GROUP = ^PEC_GROUP;
  PEC_POINT = Pointer;
  PPEC_POINT = ^PEC_POINT;
  PEC_METHOD = Pointer;
  PEC_KEY_METHOD = Pointer;
  PPEC_KEY_METHOD = ^PEC_KEY_METHOD;
  PECDSA_SIG = Pointer;
  PPECDSA_SIG = ^PECDSA_SIG;
  PECDH_METHOD = Pointer;
  
  // ASN1 types
  PASN1_OBJECT = Pointer;
  PPASN1_OBJECT = ^PASN1_OBJECT;
  PASN1_STRING = Pointer;
  PPASN1_STRING = ^PASN1_STRING;
  PASN1_BIT_STRING = PASN1_STRING;
  PPASN1_BIT_STRING = ^PASN1_BIT_STRING;
  PASN1_OCTET_STRING = PASN1_STRING;
  PPASN1_OCTET_STRING = ^PASN1_OCTET_STRING;
  PASN1_INTEGER = PASN1_STRING;
  PPASN1_INTEGER = ^PASN1_INTEGER;
  PASN1_ENUMERATED = PASN1_STRING;
  PASN1_PRINTABLESTRING = PASN1_STRING;
  PASN1_T61STRING = PASN1_STRING;
  PASN1_IA5STRING = PASN1_STRING;
  PASN1_GENERALSTRING = PASN1_STRING;
  PASN1_UNIVERSALSTRING = PASN1_STRING;
  PASN1_BMPSTRING = PASN1_STRING;
  PASN1_UTF8STRING = PASN1_STRING;
  PASN1_TIME = PASN1_STRING;
  PPASN1_TIME = ^PASN1_TIME;
  PASN1_GENERALIZEDTIME = PASN1_STRING;
  PASN1_UTCTIME = PASN1_STRING;
  PASN1_TYPE = Pointer;
  PPASN1_TYPE = ^PASN1_TYPE;
  PASN1_VALUE = Pointer;
  
  // PKCS types
  PPKCS7 = Pointer;
  PPPKCS7 = ^PPKCS7;
  PPKCS7_SIGNER_INFO = Pointer;
  PPKCS7_RECIP_INFO = Pointer;
  PPKCS8_PRIV_KEY_INFO = Pointer;
  PPPKCS8_PRIV_KEY_INFO = ^PPKCS8_PRIV_KEY_INFO;
  PPKCS12 = Pointer;
  PPPKCS12 = ^PPKCS12;
  
  // Engine types
  PENGINE = Pointer;
  PPENGINE = ^PENGINE;
  
  // UI types
  PUI = Pointer;
  PUI_METHOD = Pointer;
  
  // CONF types
  PCONF = Pointer;
  PCONF_METHOD = Pointer;
  
  // OpenSSL 3.0+ Library Context
  POSSL_LIB_CTX = Pointer;
  PPOSSL_LIB_CTX = ^POSSL_LIB_CTX;
  
  // CRYPTO types
  PCRYPTO_EX_DATA = Pointer;
  
  // Random types
  PRAND_METHOD = Pointer;
  
  // Error types
  PERR_STATE = Pointer;
  
  // Thread types
  TCRYPTO_THREADID = Pointer;
  PCRYPTO_THREADID = ^TCRYPTO_THREADID;
  
  // GENERAL_NAME type
  PGENERAL_NAME = Pointer;
  PPGENERAL_NAME = ^PGENERAL_NAME;
  PGENERAL_NAMES = PSTACK_OF_GENERAL_NAME;
  
  // DIST_POINT type  
  PDIST_POINT = Pointer;
  PPDIST_POINT = ^PDIST_POINT;
  
  // Authority Key Identifier
  PAUTHORITY_KEYID = Pointer;
  
  // Basic Constraints
  PBASIC_CONSTRAINTS = Pointer;
  
  // Extended Key Usage
  PEXTENDED_KEY_USAGE = PSTACK_OF_X509_EXTENSION;
  
  // CMS types
  PCMS_ContentInfo = Pointer;
  PPCMS_ContentInfo = ^PCMS_ContentInfo;
  PCMS_SignerInfo = Pointer;
  PCMS_RecipientInfo = Pointer;
  
  // OCSP types
  POCSP_REQUEST = Pointer;
  PPOCSP_REQUEST = ^POCSP_REQUEST;
  POCSP_RESPONSE = Pointer;
  PPOCSP_RESPONSE = ^POCSP_RESPONSE;
  POCSP_BASICRESP = Pointer;
  PPOCSP_BASICRESP = ^POCSP_BASICRESP;
  POCSP_CERTID = Pointer;
  PPOCSP_CERTID = ^POCSP_CERTID;
  
  // Callback function types
  Tpem_password_cb = function(buf: PAnsiChar; size: Integer; rwflag: Integer; userdata: Pointer): Integer; cdecl;
  Ppem_password_cb = ^Tpem_password_cb;
  
  TSSL_verify_cb = function(preverify_ok: Integer; ctx: PX509_STORE_CTX): Integer; cdecl;
  PSSL_verify_cb = ^TSSL_verify_cb;
  
  TSSL_CTX_keylog_cb_func = procedure(ssl: PSSL; const line: PAnsiChar); cdecl;
  
  TClient_cert_cb = function(ssl: PSSL; x509: PPX509; pkey: PPEVP_PKEY): Integer; cdecl;
  
  TSSL_psk_client_cb_func = function(ssl: PSSL; const hint: PAnsiChar; 
    identity: PAnsiChar; max_identity_len: Cardinal;
    psk: PByte; max_psk_len: Cardinal): Cardinal; cdecl;
    
  TSSL_psk_server_cb_func = function(ssl: PSSL; const identity: PAnsiChar;
    psk: PByte; max_psk_len: Cardinal): Cardinal; cdecl;
    
  TInfo_cb = procedure(ssl: PSSL; where: Integer; ret: Integer); cdecl;
  
  TSSL_custom_ext_add_cb_ex = function(ssl: PSSL; ext_type: Cardinal;
    context: Cardinal; const &out: PPByte; outlen: Psize_t;
    x: PX509; chainidx: size_t; al: PInteger; add_arg: Pointer): Integer; cdecl;
    
  TSSL_custom_ext_free_cb_ex = procedure(ssl: PSSL; ext_type: Cardinal;
    context: Cardinal; const &out: PByte; add_arg: Pointer); cdecl;
    
  TSSL_custom_ext_parse_cb_ex = function(ssl: PSSL; ext_type: Cardinal;
    context: Cardinal; const &in: PByte; inlen: size_t;
    x: PX509; chainidx: size_t; al: PInteger; parse_arg: Pointer): Integer; cdecl;
    
  TSSL_CTX_alpn_select_cb_func = function(ssl: PSSL; const &out: PPByte; 
    outlen: PByte; const &in: PByte; inlen: Cardinal; arg: Pointer): Integer; cdecl;
    
  TSSL_CTX_npn_advertised_cb_func = function(ssl: PSSL; const &out: PPByte;
    outlen: PCardinal; arg: Pointer): Integer; cdecl;
    
  TSSL_CTX_npn_select_cb_func = function(ssl: PSSL; &out: PPByte;
    outlen: PByte; const &in: PByte; inlen: Cardinal; arg: Pointer): Integer; cdecl;
    
  TNew_session_cb = function(ssl: PSSL; session: PSSL_SESSION): Integer; cdecl;
  TRemove_session_cb = procedure(ctx: PSSL_CTX; session: PSSL_SESSION); cdecl;
  TGet_session_cb = function(ssl: PSSL; const data: PByte; len: Integer; copy: PInteger): PSSL_SESSION; cdecl;
  
  TCRYPTO_EX_new = function(parent: Pointer; ptr: Pointer; ad: PCRYPTO_EX_DATA;
    idx: Integer; argl: clong; argp: Pointer): Integer; cdecl;
  TCRYPTO_EX_free = procedure(parent: Pointer; ptr: Pointer; ad: PCRYPTO_EX_DATA;
    idx: Integer; argl: clong; argp: Pointer); cdecl;
  TCRYPTO_EX_dup = function(to_d: PCRYPTO_EX_DATA; const from_d: PCRYPTO_EX_DATA;
    from_dd: PPPointer; idx: Integer; argl: clong; argp: Pointer): Integer; cdecl;
    
  // BIO callback
  TBIO_info_cb = function(b: PBIO; state: Integer; res: Integer): clong; cdecl;
  PBIO_info_cb = ^TBIO_info_cb;
  PPBIO_info_cb = ^PBIO_info_cb;
  
  TBIO_callback_fn = function(b: PBIO; oper: Integer; const argp: PAnsiChar;
    argi: Integer; argl: clong; ret: clong): clong; cdecl;
  TBIO_callback_fn_ex = function(b: PBIO; oper: Integer; const argp: PAnsiChar;
    len: size_t; argi: Integer; argl: clong; ret: Integer; processed: Psize_t): clong; cdecl;
    
  // EVP callbacks
  TEVP_PKEY_gen_cb = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  PEVP_PKEY_gen_cb = ^TEVP_PKEY_gen_cb;
  
  TEVP_CIPHER_CTX_ctrl_cb = function(ctx: PEVP_CIPHER_CTX; type_: Integer;
    arg: Integer; ptr: Pointer): Integer; cdecl;
    
  // ENGINE callbacks
  TENGINE_GEN_INT_FUNC = function(e: PENGINE): Integer; cdecl;
  TENGINE_CTRL_FUNC = function(e: PENGINE; cmd: Integer; i: clong;
    p: Pointer; f: Pointer): Integer; cdecl;
  TENGINE_LOAD_KEY_FUNC = function(e: PENGINE; const key_id: PAnsiChar;
    ui_method: PUI_METHOD; callback_data: Pointer): PEVP_PKEY; cdecl;
  TENGINE_SSL_CLIENT_CERT_FUNC = function(e: PENGINE; ssl: PSSL;
    ca_dn: PSTACK_OF_X509_NAME; pcert: PPX509; ppkey: PPEVP_PKEY;
    pother: PPSTACK_OF_X509; ui_method: PUI_METHOD; callback_data: Pointer): Integer; cdecl;
    
  // ASN1 callbacks
  TASN1_ex_d2i = function(pval: PPointer; const &in: PPByte; len: clong;
    const it: Pointer; tag: Integer; aclass: Integer; opt: AnsiChar; ctx: Pointer): Integer; cdecl;
  TASN1_ex_i2d = function(pval: PPointer; &out: PPByte; const it: Pointer;
    tag: Integer; aclass: Integer): Integer; cdecl;
  TASN1_ex_new_func = function(pval: PPointer; const it: Pointer): Integer; cdecl;
  TASN1_ex_free_func = procedure(pval: PPointer; const it: Pointer); cdecl;
  TASN1_ex_print_func = function(&out: PBIO; pval: PPointer; indent: Integer;
    const pctx: Pointer): Integer; cdecl;
    
  // X509 callbacks
  TX509_STORE_CTX_verify_cb = function(ctx: PX509_STORE_CTX; arg: Pointer): Integer; cdecl;
  TX509_STORE_CTX_verify_fn = function(ctx: PX509_STORE_CTX): Integer; cdecl;
  TX509_STORE_CTX_get_issuer_fn = function(issuer: PPX509; ctx: PX509_STORE_CTX;
    x: PX509): Integer; cdecl;
  TX509_STORE_CTX_check_issued_fn = function(ctx: PX509_STORE_CTX;
    x: PX509; issuer: PX509): Integer; cdecl;
  TX509_STORE_CTX_check_revocation_fn = function(ctx: PX509_STORE_CTX): Integer; cdecl;
  TX509_STORE_CTX_get_crl_fn = function(ctx: PX509_STORE_CTX; crl: PPX509_CRL;
    x: PX509): Integer; cdecl;
  TX509_STORE_CTX_check_crl_fn = function(ctx: PX509_STORE_CTX; crl: PX509_CRL): Integer; cdecl;
  TX509_STORE_CTX_cert_crl_fn = function(ctx: PX509_STORE_CTX; crl: PX509_CRL;
    x: PX509): Integer; cdecl;
  TX509_STORE_CTX_check_policy_fn = function(ctx: PX509_STORE_CTX): Integer; cdecl;
  TX509_STORE_CTX_lookup_certs_fn = function(ctx: PX509_STORE_CTX; nm: PX509_NAME): PSTACK_OF_X509; cdecl;
  TX509_STORE_CTX_lookup_crls_fn = function(ctx: PX509_STORE_CTX; nm: PX509_NAME): PSTACK_OF_X509_CRL; cdecl;
  TX509_STORE_CTX_cleanup_fn = function(ctx: PX509_STORE_CTX): Integer; cdecl;
  
  // UI callbacks
  TUI_string_reader = function(ui: PUI; uis: Pointer): Integer; cdecl;
  TUI_string_writer = function(ui: PUI; uis: Pointer): Integer; cdecl;
  TUI_string_closer = function(ui: PUI): Integer; cdecl;
  
  // Thread callbacks
  TCRYPTO_THREADID_set_numeric_func = procedure(id: PCRYPTO_THREADID; val: LongWord); cdecl;
  TCRYPTO_THREADID_set_pointer_func = procedure(id: PCRYPTO_THREADID; ptr: Pointer); cdecl;
  TCRYPTO_THREADID_hash_func = function(const id: PCRYPTO_THREADID): LongWord; cdecl;
  TCRYPTO_THREADID_cmp_func = function(const a, b: PCRYPTO_THREADID): Integer; cdecl;
  
  // Lock callbacks
  TCRYPTO_lock_func = procedure(mode: Integer; n: Integer; const &file: PAnsiChar; line: Integer); cdecl;
  TCRYPTO_dynlock_create_func = function(const &file: PAnsiChar; line: Integer): Pointer; cdecl;
  TCRYPTO_dynlock_lock_func = procedure(mode: Integer; l: Pointer; const &file: PAnsiChar; line: Integer); cdecl;
  TCRYPTO_dynlock_destroy_func = procedure(l: Pointer; const &file: PAnsiChar; line: Integer); cdecl;
  
  // Memory callbacks
  TCRYPTO_malloc_func = function(num: size_t; const &file: PAnsiChar; line: Integer): Pointer; cdecl;
  TCRYPTO_realloc_func = function(addr: Pointer; num: size_t; const &file: PAnsiChar; line: Integer): Pointer; cdecl;
  TCRYPTO_free_func = procedure(addr: Pointer; const &file: PAnsiChar; line: Integer); cdecl;

implementation

end.
