unit nextpas.core.tls.openssl.api.pem;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.base, nextpas.core.fs, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.bio, nextpas.core.tls.openssl.api.evp, nextpas.core.tls.openssl.loader;

type
  // PEM 密码回调函数类型
  Tpem_password_cb = function(buf: PAnsiChar; size: Integer; rwflag: Integer; userdata: Pointer): Integer; cdecl;

  // PEM 函数类型
  type
    // 基础 PEM 读写函数
    TPEM_read_bio = function(bp: PBIO; name: PPAnsiChar; header: PPAnsiChar; 
      data: PPByte; len: PInteger): Integer; cdecl;
    TPEM_read_bio_ex = function(bp: PBIO; name: PPAnsiChar; header: PPAnsiChar; 
      data: PPByte; len: PInteger; flags: Cardinal): Integer; cdecl;
    TPEM_write_bio = function(bp: PBIO; const name: PAnsiChar; const header: PAnsiChar;
      const data: PByte; len: Integer): Integer; cdecl;
    TPEM_bytes_read_bio = function(pdata: PPByte; plen: PInteger; pnm: PPAnsiChar;
      const name: PAnsiChar; bp: PBIO; cb: Tpem_password_cb; u: Pointer): Integer; cdecl;
    TPEM_bytes_read_bio_secmem = function(pdata: PPByte; plen: PInteger; pnm: PPAnsiChar;
      const name: PAnsiChar; bp: PBIO; cb: Tpem_password_cb; u: Pointer): Integer; cdecl;

    // X509 证书 PEM 函数
    TPEM_read_bio_X509 = function(bp: PBIO; x: PPX509; cb: Tpem_password_cb; u: Pointer): PX509; cdecl;
    TPEM_write_bio_X509 = function(bp: PBIO; x: PX509): Integer; cdecl;
    TPEM_read_bio_X509_AUX = function(bp: PBIO; x: PPX509; cb: Tpem_password_cb; u: Pointer): PX509; cdecl;
    TPEM_write_bio_X509_AUX = function(bp: PBIO; x: PX509): Integer; cdecl;
    TPEM_read_bio_X509_REQ = function(bp: PBIO; x: PPX509_REQ; cb: Tpem_password_cb; u: Pointer): PX509_REQ; cdecl;
    TPEM_write_bio_X509_REQ = function(bp: PBIO; x: PX509_REQ): Integer; cdecl;
    TPEM_write_bio_X509_REQ_NEW = function(bp: PBIO; x: PX509_REQ): Integer; cdecl;
    TPEM_read_bio_X509_CRL = function(bp: PBIO; x: PPX509_CRL; cb: Tpem_password_cb; u: Pointer): PX509_CRL; cdecl;
    TPEM_write_bio_X509_CRL = function(bp: PBIO; x: PX509_CRL): Integer; cdecl;

    // 私钥 PEM 函数
    TPEM_read_bio_PrivateKey = function(bp: PBIO; x: PPEVP_PKEY; cb: Tpem_password_cb; u: Pointer): PEVP_PKEY; cdecl;
    TPEM_write_bio_PrivateKey = function(bp: PBIO; x: PEVP_PKEY; const enc: PEVP_CIPHER;
      kstr: PByte; klen: Integer; cb: Tpem_password_cb; u: Pointer): Integer; cdecl;
    TPEM_write_bio_PrivateKey_traditional = function(bp: PBIO; x: PEVP_PKEY; const enc: PEVP_CIPHER;
      kstr: PByte; klen: Integer; cb: Tpem_password_cb; u: Pointer): Integer; cdecl;
    TPEM_write_bio_PKCS8PrivateKey = function(bp: PBIO; x: PEVP_PKEY; const enc: PEVP_CIPHER;
      kstr: PAnsiChar; klen: Integer; cb: Tpem_password_cb; u: Pointer): Integer; cdecl;
    TPEM_write_bio_PKCS8PrivateKey_nid = function(bp: PBIO; x: PEVP_PKEY; nid: Integer;
      kstr: PAnsiChar; klen: Integer; cb: Tpem_password_cb; u: Pointer): Integer; cdecl;

    // 公钥 PEM 函数
    TPEM_read_bio_PUBKEY = function(bp: PBIO; x: PPEVP_PKEY; cb: Tpem_password_cb; u: Pointer): PEVP_PKEY; cdecl;
    TPEM_write_bio_PUBKEY = function(bp: PBIO; x: PEVP_PKEY): Integer; cdecl;

    // RSA 密钥 PEM 函数
    TPEM_read_bio_RSAPrivateKey = function(bp: PBIO; x: PPRSA; cb: Tpem_password_cb; u: Pointer): PRSA; cdecl;
    TPEM_write_bio_RSAPrivateKey = function(bp: PBIO; x: PRSA; const enc: PEVP_CIPHER;
      kstr: PByte; klen: Integer; cb: Tpem_password_cb; u: Pointer): Integer; cdecl;
    TPEM_read_bio_RSAPublicKey = function(bp: PBIO; x: PPRSA; cb: Tpem_password_cb; u: Pointer): PRSA; cdecl;
    TPEM_write_bio_RSAPublicKey = function(bp: PBIO; const x: PRSA): Integer; cdecl;
    TPEM_read_bio_RSA_PUBKEY = function(bp: PBIO; x: PPRSA; cb: Tpem_password_cb; u: Pointer): PRSA; cdecl;
    TPEM_write_bio_RSA_PUBKEY = function(bp: PBIO; x: PRSA): Integer; cdecl;

    // DSA 密钥 PEM 函数
    TPEM_read_bio_DSAPrivateKey = function(bp: PBIO; x: PPDSA; cb: Tpem_password_cb; u: Pointer): PDSA; cdecl;
    TPEM_write_bio_DSAPrivateKey = function(bp: PBIO; x: PDSA; const enc: PEVP_CIPHER;
      kstr: PByte; klen: Integer; cb: Tpem_password_cb; u: Pointer): Integer; cdecl;
    TPEM_read_bio_DSA_PUBKEY = function(bp: PBIO; x: PPDSA; cb: Tpem_password_cb; u: Pointer): PDSA; cdecl;
    TPEM_write_bio_DSA_PUBKEY = function(bp: PBIO; x: PDSA): Integer; cdecl;
    TPEM_read_bio_DSAparams = function(bp: PBIO; x: PPDSA; cb: Tpem_password_cb; u: Pointer): PDSA; cdecl;
    TPEM_write_bio_DSAparams = function(bp: PBIO; const x: PDSA): Integer; cdecl;

    // DH 参数 PEM 函数
    TPEM_read_bio_DHparams = function(bp: PBIO; x: PPDH; cb: Tpem_password_cb; u: Pointer): PDH; cdecl;
    TPEM_write_bio_DHparams = function(bp: PBIO; const x: PDH): Integer; cdecl;
    TPEM_write_bio_DHxparams = function(bp: PBIO; const x: PDH): Integer; cdecl;

    // EC 密钥 PEM 函数
    TPEM_read_bio_ECPrivateKey = function(bp: PBIO; x: PPEC_KEY; cb: Tpem_password_cb; u: Pointer): PEC_KEY; cdecl;
    TPEM_write_bio_ECPrivateKey = function(bp: PBIO; x: PEC_KEY; const enc: PEVP_CIPHER;
      kstr: PByte; klen: Integer; cb: Tpem_password_cb; u: Pointer): Integer; cdecl;
    TPEM_read_bio_EC_PUBKEY = function(bp: PBIO; x: PPEC_KEY; cb: Tpem_password_cb; u: Pointer): PEC_KEY; cdecl;
    TPEM_write_bio_EC_PUBKEY = function(bp: PBIO; x: PEC_KEY): Integer; cdecl;
    TPEM_read_bio_ECPKParameters = function(bp: PBIO; x: PPEC_GROUP; cb: Tpem_password_cb; u: Pointer): PEC_GROUP; cdecl;
    TPEM_write_bio_ECPKParameters = function(bp: PBIO; const x: PEC_GROUP): Integer; cdecl;

    // PKCS7 PEM 函数
    TPEM_read_bio_PKCS7 = function(bp: PBIO; x: PPPKCS7; cb: Tpem_password_cb; u: Pointer): PPKCS7; cdecl;
    TPEM_write_bio_PKCS7 = function(bp: PBIO; x: PPKCS7): Integer; cdecl;
    TPEM_write_bio_PKCS7_stream = function(out_: PBIO; p7: PPKCS7; in_: PBIO; flags: Integer): Integer; cdecl;

    // PKCS8 函数
    TPEM_read_bio_PKCS8 = function(bp: PBIO; x: PPX509_SIG; cb: Tpem_password_cb; u: Pointer): PX509_SIG; cdecl;
    TPEM_write_bio_PKCS8 = function(bp: PBIO; x: PX509_SIG): Integer; cdecl;
    TPEM_read_bio_PKCS8_PRIV_KEY_INFO = function(bp: PBIO; x: PPPKCS8_PRIV_KEY_INFO; 
      cb: Tpem_password_cb; u: Pointer): PPKCS8_PRIV_KEY_INFO; cdecl;
    TPEM_write_bio_PKCS8_PRIV_KEY_INFO = function(bp: PBIO; x: PPKCS8_PRIV_KEY_INFO): Integer; cdecl;

    // Parameters 函数
    TPEM_read_bio_Parameters = function(bp: PBIO; x: PPEVP_PKEY): PEVP_PKEY; cdecl;
    TPEM_write_bio_Parameters = function(bp: PBIO; x: PEVP_PKEY): Integer; cdecl;

    // CMS 函数
    TPEM_read_bio_CMS = function(bp: PBIO; x: PPCMS_ContentInfo; cb: Tpem_password_cb; u: Pointer): PCMS_ContentInfo; cdecl;
    TPEM_write_bio_CMS = function(bp: PBIO; x: PCMS_ContentInfo): Integer; cdecl;
    TPEM_write_bio_CMS_stream = function(out_: PBIO; cms: PCMS_ContentInfo; in_: PBIO; flags: Integer): Integer; cdecl;

    // SSL Session PEM 函数
    TPEM_read_bio_SSL_SESSION = function(bp: PBIO; x: PPSSL_SESSION; cb: Tpem_password_cb; u: Pointer): PSSL_SESSION; cdecl;
    TPEM_write_bio_SSL_SESSION = function(bp: PBIO; x: PSSL_SESSION): Integer; cdecl;

    // 文件版本的 PEM 函数（使用 FILE*）
    TPEM_read_X509 = function(fp: Pointer; x: PPX509; cb: Tpem_password_cb; u: Pointer): PX509; cdecl;
    TPEM_write_X509 = function(fp: Pointer; x: PX509): Integer; cdecl;
    TPEM_read_PrivateKey = function(fp: Pointer; x: PPEVP_PKEY; cb: Tpem_password_cb; u: Pointer): PEVP_PKEY; cdecl;
    TPEM_write_PrivateKey = function(fp: Pointer; x: PEVP_PKEY; const enc: PEVP_CIPHER;
      kstr: PByte; klen: Integer; cb: Tpem_password_cb; u: Pointer): Integer; cdecl;

    // 实用函数
    TPEM_def_callback = function(buf: PAnsiChar; size: Integer; rwflag: Integer; userdata: Pointer): Integer; cdecl;
    TPEM_dek_info = procedure(buf: PAnsiChar; const atype: PAnsiChar; len: Integer; str: PAnsiChar); cdecl;

var
  // 基础 PEM 读写函数
  PEM_read_bio: TPEM_read_bio = nil;
  PEM_read_bio_ex: TPEM_read_bio_ex = nil;
  PEM_write_bio: TPEM_write_bio = nil;
  PEM_bytes_read_bio: TPEM_bytes_read_bio = nil;
  PEM_bytes_read_bio_secmem: TPEM_bytes_read_bio_secmem = nil;

  // X509 证书 PEM 函数
  PEM_read_bio_X509: TPEM_read_bio_X509 = nil;
  PEM_write_bio_X509: TPEM_write_bio_X509 = nil;
  PEM_read_bio_X509_AUX: TPEM_read_bio_X509_AUX = nil;
  PEM_write_bio_X509_AUX: TPEM_write_bio_X509_AUX = nil;
  PEM_read_bio_X509_REQ: TPEM_read_bio_X509_REQ = nil;
  PEM_write_bio_X509_REQ: TPEM_write_bio_X509_REQ = nil;
  PEM_write_bio_X509_REQ_NEW: TPEM_write_bio_X509_REQ_NEW = nil;
  PEM_read_bio_X509_CRL: TPEM_read_bio_X509_CRL = nil;
  PEM_write_bio_X509_CRL: TPEM_write_bio_X509_CRL = nil;

  // 私钥 PEM 函数
  PEM_read_bio_PrivateKey: TPEM_read_bio_PrivateKey = nil;
  PEM_write_bio_PrivateKey: TPEM_write_bio_PrivateKey = nil;
  PEM_write_bio_PrivateKey_traditional: TPEM_write_bio_PrivateKey_traditional = nil;
  PEM_write_bio_PKCS8PrivateKey: TPEM_write_bio_PKCS8PrivateKey = nil;
  PEM_write_bio_PKCS8PrivateKey_nid: TPEM_write_bio_PKCS8PrivateKey_nid = nil;

  // 公钥 PEM 函数
  PEM_read_bio_PUBKEY: TPEM_read_bio_PUBKEY = nil;
  PEM_write_bio_PUBKEY: TPEM_write_bio_PUBKEY = nil;

  // RSA 密钥 PEM 函数
  PEM_read_bio_RSAPrivateKey: TPEM_read_bio_RSAPrivateKey = nil;
  PEM_write_bio_RSAPrivateKey: TPEM_write_bio_RSAPrivateKey = nil;
  PEM_read_bio_RSAPublicKey: TPEM_read_bio_RSAPublicKey = nil;
  PEM_write_bio_RSAPublicKey: TPEM_write_bio_RSAPublicKey = nil;
  PEM_read_bio_RSA_PUBKEY: TPEM_read_bio_RSA_PUBKEY = nil;
  PEM_write_bio_RSA_PUBKEY: TPEM_write_bio_RSA_PUBKEY = nil;

  // DSA 密钥 PEM 函数
  PEM_read_bio_DSAPrivateKey: TPEM_read_bio_DSAPrivateKey = nil;
  PEM_write_bio_DSAPrivateKey: TPEM_write_bio_DSAPrivateKey = nil;
  PEM_read_bio_DSA_PUBKEY: TPEM_read_bio_DSA_PUBKEY = nil;
  PEM_write_bio_DSA_PUBKEY: TPEM_write_bio_DSA_PUBKEY = nil;
  PEM_read_bio_DSAparams: TPEM_read_bio_DSAparams = nil;
  PEM_write_bio_DSAparams: TPEM_write_bio_DSAparams = nil;

  // DH 参数 PEM 函数
  PEM_read_bio_DHparams: TPEM_read_bio_DHparams = nil;
  PEM_write_bio_DHparams: TPEM_write_bio_DHparams = nil;
  PEM_write_bio_DHxparams: TPEM_write_bio_DHxparams = nil;

  // EC 密钥 PEM 函数
  PEM_read_bio_ECPrivateKey: TPEM_read_bio_ECPrivateKey = nil;
  PEM_write_bio_ECPrivateKey: TPEM_write_bio_ECPrivateKey = nil;
  PEM_read_bio_EC_PUBKEY: TPEM_read_bio_EC_PUBKEY = nil;
  PEM_write_bio_EC_PUBKEY: TPEM_write_bio_EC_PUBKEY = nil;
  PEM_read_bio_ECPKParameters: TPEM_read_bio_ECPKParameters = nil;
  PEM_write_bio_ECPKParameters: TPEM_write_bio_ECPKParameters = nil;

  // PKCS7 PEM 函数
  PEM_read_bio_PKCS7: TPEM_read_bio_PKCS7 = nil;
  PEM_write_bio_PKCS7: TPEM_write_bio_PKCS7 = nil;
  PEM_write_bio_PKCS7_stream: TPEM_write_bio_PKCS7_stream = nil;

  // PKCS8 函数
  PEM_read_bio_PKCS8: TPEM_read_bio_PKCS8 = nil;
  PEM_write_bio_PKCS8: TPEM_write_bio_PKCS8 = nil;
  PEM_read_bio_PKCS8_PRIV_KEY_INFO: TPEM_read_bio_PKCS8_PRIV_KEY_INFO = nil;
  PEM_write_bio_PKCS8_PRIV_KEY_INFO: TPEM_write_bio_PKCS8_PRIV_KEY_INFO = nil;

  // Parameters 函数
  PEM_read_bio_Parameters: TPEM_read_bio_Parameters = nil;
  PEM_write_bio_Parameters: TPEM_write_bio_Parameters = nil;

  // CMS 函数
  PEM_read_bio_CMS: TPEM_read_bio_CMS = nil;
  PEM_write_bio_CMS: TPEM_write_bio_CMS = nil;
  PEM_write_bio_CMS_stream: TPEM_write_bio_CMS_stream = nil;

  // SSL Session PEM 函数
  PEM_read_bio_SSL_SESSION: TPEM_read_bio_SSL_SESSION = nil;
  PEM_write_bio_SSL_SESSION: TPEM_write_bio_SSL_SESSION = nil;

  // 文件版本的 PEM 函数
  PEM_read_X509: TPEM_read_X509 = nil;
  PEM_write_X509: TPEM_write_X509 = nil;
  PEM_read_PrivateKey: TPEM_read_PrivateKey = nil;
  PEM_write_PrivateKey: TPEM_write_PrivateKey = nil;

  // 实用函数
  PEM_def_callback: TPEM_def_callback = nil;
  PEM_dek_info: TPEM_dek_info = nil;

// 加载和卸载函数
function LoadOpenSSLPEM(const ACryptoLib: THandle): Boolean;
procedure UnloadOpenSSLPEM;

// 辅助函数
function LoadPrivateKeyFromPEM(const AFileName: string; const APassword: string = ''): PEVP_PKEY;
function LoadPublicKeyFromPEM(const AFileName: string): PEVP_PKEY;
function LoadCertificateFromPEM(const AFileName: string): PX509;
function SavePrivateKeyToPEM(const AFileName: string; AKey: PEVP_PKEY; const APassword: string = ''): Boolean;
function SavePublicKeyToPEM(const AFileName: string; AKey: PEVP_PKEY): Boolean;
function SaveCertificateToPEM(const AFileName: string; ACert: PX509): Boolean;
function LoadPrivateKeyFromMemory(const AData: TBytes; const APassword: string = ''): PEVP_PKEY;
function LoadCertificateFromMemory(const AData: TBytes): PX509;

implementation

{ PEM 函数绑定数组
  runtime storage keeps procvar targets writable across macOS batch-loader runs }
var
  PEM_FUNCTION_BINDINGS: array[0..61] of TFunctionBinding = (
    // 基础 PEM 读写函数
    (Name: 'PEM_read_bio'; FuncPtr: @PEM_read_bio; Required: False),
    (Name: 'PEM_read_bio_ex'; FuncPtr: @PEM_read_bio_ex; Required: False),
    (Name: 'PEM_write_bio'; FuncPtr: @PEM_write_bio; Required: False),
    (Name: 'PEM_bytes_read_bio'; FuncPtr: @PEM_bytes_read_bio; Required: False),
    (Name: 'PEM_bytes_read_bio_secmem'; FuncPtr: @PEM_bytes_read_bio_secmem; Required: False),
    // X509 证书 PEM 函数
    (Name: 'PEM_read_bio_X509'; FuncPtr: @PEM_read_bio_X509; Required: True),
    (Name: 'PEM_write_bio_X509'; FuncPtr: @PEM_write_bio_X509; Required: True),
    (Name: 'PEM_read_bio_X509_AUX'; FuncPtr: @PEM_read_bio_X509_AUX; Required: False),
    (Name: 'PEM_write_bio_X509_AUX'; FuncPtr: @PEM_write_bio_X509_AUX; Required: False),
    (Name: 'PEM_read_bio_X509_REQ'; FuncPtr: @PEM_read_bio_X509_REQ; Required: False),
    (Name: 'PEM_write_bio_X509_REQ'; FuncPtr: @PEM_write_bio_X509_REQ; Required: False),
    (Name: 'PEM_write_bio_X509_REQ_NEW'; FuncPtr: @PEM_write_bio_X509_REQ_NEW; Required: False),
    (Name: 'PEM_read_bio_X509_CRL'; FuncPtr: @PEM_read_bio_X509_CRL; Required: False),
    (Name: 'PEM_write_bio_X509_CRL'; FuncPtr: @PEM_write_bio_X509_CRL; Required: False),
    // 私钥 PEM 函数
    (Name: 'PEM_read_bio_PrivateKey'; FuncPtr: @PEM_read_bio_PrivateKey; Required: False),
    (Name: 'PEM_write_bio_PrivateKey'; FuncPtr: @PEM_write_bio_PrivateKey; Required: False),
    (Name: 'PEM_write_bio_PrivateKey_traditional'; FuncPtr: @PEM_write_bio_PrivateKey_traditional; Required: False),
    (Name: 'PEM_write_bio_PKCS8PrivateKey'; FuncPtr: @PEM_write_bio_PKCS8PrivateKey; Required: False),
    (Name: 'PEM_write_bio_PKCS8PrivateKey_nid'; FuncPtr: @PEM_write_bio_PKCS8PrivateKey_nid; Required: False),
    // 公钥 PEM 函数
    (Name: 'PEM_read_bio_PUBKEY'; FuncPtr: @PEM_read_bio_PUBKEY; Required: False),
    (Name: 'PEM_write_bio_PUBKEY'; FuncPtr: @PEM_write_bio_PUBKEY; Required: False),
    // RSA 密钥 PEM 函数
    (Name: 'PEM_read_bio_RSAPrivateKey'; FuncPtr: @PEM_read_bio_RSAPrivateKey; Required: False),
    (Name: 'PEM_write_bio_RSAPrivateKey'; FuncPtr: @PEM_write_bio_RSAPrivateKey; Required: False),
    (Name: 'PEM_read_bio_RSAPublicKey'; FuncPtr: @PEM_read_bio_RSAPublicKey; Required: False),
    (Name: 'PEM_write_bio_RSAPublicKey'; FuncPtr: @PEM_write_bio_RSAPublicKey; Required: False),
    (Name: 'PEM_read_bio_RSA_PUBKEY'; FuncPtr: @PEM_read_bio_RSA_PUBKEY; Required: False),
    (Name: 'PEM_write_bio_RSA_PUBKEY'; FuncPtr: @PEM_write_bio_RSA_PUBKEY; Required: False),
    // DSA 密钥 PEM 函数
    (Name: 'PEM_read_bio_DSAPrivateKey'; FuncPtr: @PEM_read_bio_DSAPrivateKey; Required: False),
    (Name: 'PEM_write_bio_DSAPrivateKey'; FuncPtr: @PEM_write_bio_DSAPrivateKey; Required: False),
    (Name: 'PEM_read_bio_DSA_PUBKEY'; FuncPtr: @PEM_read_bio_DSA_PUBKEY; Required: False),
    (Name: 'PEM_write_bio_DSA_PUBKEY'; FuncPtr: @PEM_write_bio_DSA_PUBKEY; Required: False),
    (Name: 'PEM_read_bio_DSAparams'; FuncPtr: @PEM_read_bio_DSAparams; Required: False),
    (Name: 'PEM_write_bio_DSAparams'; FuncPtr: @PEM_write_bio_DSAparams; Required: False),
    // DH 参数 PEM 函数
    (Name: 'PEM_read_bio_DHparams'; FuncPtr: @PEM_read_bio_DHparams; Required: False),
    (Name: 'PEM_write_bio_DHparams'; FuncPtr: @PEM_write_bio_DHparams; Required: False),
    (Name: 'PEM_write_bio_DHxparams'; FuncPtr: @PEM_write_bio_DHxparams; Required: False),
    // EC 密钥 PEM 函数
    (Name: 'PEM_read_bio_ECPrivateKey'; FuncPtr: @PEM_read_bio_ECPrivateKey; Required: False),
    (Name: 'PEM_write_bio_ECPrivateKey'; FuncPtr: @PEM_write_bio_ECPrivateKey; Required: False),
    (Name: 'PEM_read_bio_EC_PUBKEY'; FuncPtr: @PEM_read_bio_EC_PUBKEY; Required: False),
    (Name: 'PEM_write_bio_EC_PUBKEY'; FuncPtr: @PEM_write_bio_EC_PUBKEY; Required: False),
    (Name: 'PEM_read_bio_ECPKParameters'; FuncPtr: @PEM_read_bio_ECPKParameters; Required: False),
    (Name: 'PEM_write_bio_ECPKParameters'; FuncPtr: @PEM_write_bio_ECPKParameters; Required: False),
    // PKCS7 PEM 函数
    (Name: 'PEM_read_bio_PKCS7'; FuncPtr: @PEM_read_bio_PKCS7; Required: False),
    (Name: 'PEM_write_bio_PKCS7'; FuncPtr: @PEM_write_bio_PKCS7; Required: False),
    (Name: 'PEM_write_bio_PKCS7_stream'; FuncPtr: @PEM_write_bio_PKCS7_stream; Required: False),
    // PKCS8 函数
    (Name: 'PEM_read_bio_PKCS8'; FuncPtr: @PEM_read_bio_PKCS8; Required: False),
    (Name: 'PEM_write_bio_PKCS8'; FuncPtr: @PEM_write_bio_PKCS8; Required: False),
    (Name: 'PEM_read_bio_PKCS8_PRIV_KEY_INFO'; FuncPtr: @PEM_read_bio_PKCS8_PRIV_KEY_INFO; Required: False),
    (Name: 'PEM_write_bio_PKCS8_PRIV_KEY_INFO'; FuncPtr: @PEM_write_bio_PKCS8_PRIV_KEY_INFO; Required: False),
    // Parameters 函数
    (Name: 'PEM_read_bio_Parameters'; FuncPtr: @PEM_read_bio_Parameters; Required: False),
    (Name: 'PEM_write_bio_Parameters'; FuncPtr: @PEM_write_bio_Parameters; Required: False),
    // CMS 函数
    (Name: 'PEM_read_bio_CMS'; FuncPtr: @PEM_read_bio_CMS; Required: False),
    (Name: 'PEM_write_bio_CMS'; FuncPtr: @PEM_write_bio_CMS; Required: False),
    (Name: 'PEM_write_bio_CMS_stream'; FuncPtr: @PEM_write_bio_CMS_stream; Required: False),
    // SSL Session PEM 函数
    (Name: 'PEM_read_bio_SSL_SESSION'; FuncPtr: @PEM_read_bio_SSL_SESSION; Required: False),
    (Name: 'PEM_write_bio_SSL_SESSION'; FuncPtr: @PEM_write_bio_SSL_SESSION; Required: False),
    // 文件版本的 PEM 函数
    (Name: 'PEM_read_X509'; FuncPtr: @PEM_read_X509; Required: False),
    (Name: 'PEM_write_X509'; FuncPtr: @PEM_write_X509; Required: False),
    (Name: 'PEM_read_PrivateKey'; FuncPtr: @PEM_read_PrivateKey; Required: False),
    (Name: 'PEM_write_PrivateKey'; FuncPtr: @PEM_write_PrivateKey; Required: False),
    // 实用函数
    (Name: 'PEM_def_callback'; FuncPtr: @PEM_def_callback; Required: False),
    (Name: 'PEM_dek_info'; FuncPtr: @PEM_dek_info; Required: False)
  );

// 密码回调函数
function PasswordCallback(buf: PAnsiChar; size: Integer; rwflag: Integer; userdata: Pointer): Integer; cdecl;
var
  LPasswordAnsi: AnsiString;
  Password: string;
begin
  if userdata <> nil then
  begin
    Password := string(PAnsiChar(userdata));
    if Length(Password) < size then
    begin
      LPasswordAnsi := AnsiString(Password);
      if Length(LPasswordAnsi) > 0 then
        Move(LPasswordAnsi[1], buf^, Length(LPasswordAnsi));
      buf[Length(LPasswordAnsi)] := #0;
      Result := Length(Password);
    end
    else
      Result := 0;
  end
  else
    Result := 0;
end;

function LoadOpenSSLPEM(const ACryptoLib: THandle): Boolean;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmPEM) then
    Exit(True);

  if ACryptoLib = 0 then
    Exit(False);

  // 使用批量加载模式
  TOpenSSLLoader.LoadFunctions(ACryptoLib, PEM_FUNCTION_BINDINGS);

  // The common PEM owner path is certificate/private-key read; do not fail the whole
  // module just because a write-side helper is unavailable on one platform image.
  TOpenSSLLoader.SetModuleLoaded(osmPEM,
    Assigned(PEM_read_bio_X509) and Assigned(PEM_read_bio_PrivateKey));
  Result := TOpenSSLLoader.IsModuleLoaded(osmPEM);
end;

procedure UnloadOpenSSLPEM;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmPEM) then
    Exit;

  // 使用批量清理模式
  TOpenSSLLoader.ClearFunctions(PEM_FUNCTION_BINDINGS);

  TOpenSSLLoader.SetModuleLoaded(osmPEM, False);
end;

// 辅助函数实现
function LoadPrivateKeyFromPEM(const AFileName: string; const APassword: string): PEVP_PKEY;
var
  Bio: PBIO;
  Pwd: PAnsiChar;
begin
  Result := nil;
  if not TOpenSSLLoader.IsModuleLoaded(osmPEM) or
    not nextpas.core.fs.Exists(AFileName) or
    not Assigned(BIO_new_file) or
    not Assigned(PEM_read_bio_PrivateKey) or
    not Assigned(BIO_free) then
    Exit;

  Bio := BIO_new_file(PAnsiChar(AnsiString(AFileName)), 'r');
  if Bio = nil then
    Exit;

  try
    if APassword <> '' then
      Pwd := PAnsiChar(AnsiString(APassword))
    else
      Pwd := nil;

    Result := PEM_read_bio_PrivateKey(Bio, nil, @PasswordCallback, Pwd);
  finally
    BIO_free(Bio);
  end;
end;

function LoadPublicKeyFromPEM(const AFileName: string): PEVP_PKEY;
var
  Bio: PBIO;
begin
  Result := nil;
  if not TOpenSSLLoader.IsModuleLoaded(osmPEM) or
    not nextpas.core.fs.Exists(AFileName) or
    not Assigned(BIO_new_file) or
    not Assigned(PEM_read_bio_PUBKEY) or
    not Assigned(BIO_free) then
    Exit;

  Bio := BIO_new_file(PAnsiChar(AnsiString(AFileName)), 'r');
  if Bio = nil then
    Exit;

  try
    Result := PEM_read_bio_PUBKEY(Bio, nil, nil, nil);
  finally
    BIO_free(Bio);
  end;
end;

function LoadCertificateFromPEM(const AFileName: string): PX509;
var
  Bio: PBIO;
begin
  Result := nil;
  if not TOpenSSLLoader.IsModuleLoaded(osmPEM) or
    not nextpas.core.fs.Exists(AFileName) or
    not Assigned(BIO_new_file) or
    not Assigned(PEM_read_bio_X509) or
    not Assigned(BIO_free) then
    Exit;

  Bio := BIO_new_file(PAnsiChar(AnsiString(AFileName)), 'r');
  if Bio = nil then
    Exit;

  try
    Result := PEM_read_bio_X509(Bio, nil, nil, nil);
  finally
    BIO_free(Bio);
  end;
end;

function SavePrivateKeyToPEM(const AFileName: string; AKey: PEVP_PKEY; const APassword: string): Boolean;
var
  Bio: PBIO;
  Enc: PEVP_CIPHER;
  Pwd: PAnsiChar;
begin
  Result := False;
  if not TOpenSSLLoader.IsModuleLoaded(osmPEM) or
    (AKey = nil) or
    not Assigned(BIO_new_file) or
    not Assigned(PEM_write_bio_PrivateKey) or
    not Assigned(BIO_free) then
    Exit;

  Bio := BIO_new_file(PAnsiChar(AnsiString(AFileName)), 'w');
  if Bio = nil then
    Exit;

  try
    if APassword <> '' then
    begin
      if not Assigned(EVP_aes_256_cbc) then
        Exit;
      Enc := EVP_aes_256_cbc();
      Pwd := PAnsiChar(AnsiString(APassword));
    end
    else
    begin
      Enc := nil;
      Pwd := nil;
    end;

    Result := PEM_write_bio_PrivateKey(Bio, AKey, Enc, PByte(Pwd), 
      Length(APassword), @PasswordCallback, Pwd) = 1;
  finally
    BIO_free(Bio);
  end;
end;

function SavePublicKeyToPEM(const AFileName: string; AKey: PEVP_PKEY): Boolean;
var
  Bio: PBIO;
begin
  Result := False;
  if not TOpenSSLLoader.IsModuleLoaded(osmPEM) or
    (AKey = nil) or
    not Assigned(BIO_new_file) or
    not Assigned(PEM_write_bio_PUBKEY) or
    not Assigned(BIO_free) then
    Exit;

  Bio := BIO_new_file(PAnsiChar(AnsiString(AFileName)), 'w');
  if Bio = nil then
    Exit;

  try
    Result := PEM_write_bio_PUBKEY(Bio, AKey) = 1;
  finally
    BIO_free(Bio);
  end;
end;

function SaveCertificateToPEM(const AFileName: string; ACert: PX509): Boolean;
var
  Bio: PBIO;
begin
  Result := False;
  if not TOpenSSLLoader.IsModuleLoaded(osmPEM) or
    (ACert = nil) or
    not Assigned(BIO_new_file) or
    not Assigned(PEM_write_bio_X509) or
    not Assigned(BIO_free) then
    Exit;

  Bio := BIO_new_file(PAnsiChar(AnsiString(AFileName)), 'w');
  if Bio = nil then
    Exit;

  try
    Result := PEM_write_bio_X509(Bio, ACert) = 1;
  finally
    BIO_free(Bio);
  end;
end;

function LoadPrivateKeyFromMemory(const AData: TBytes; const APassword: string): PEVP_PKEY;
var
  Bio: PBIO;
  Pwd: PAnsiChar;
begin
  Result := nil;
  if not TOpenSSLLoader.IsModuleLoaded(osmPEM) or
    (Length(AData) = 0) or
    not Assigned(BIO_new_mem_buf) or
    not Assigned(PEM_read_bio_PrivateKey) or
    not Assigned(BIO_free) then
    Exit;

  Bio := BIO_new_mem_buf(@AData[0], Length(AData));
  if Bio = nil then
    Exit;

  try
    if APassword <> '' then
      Pwd := PAnsiChar(AnsiString(APassword))
    else
      Pwd := nil;

    Result := PEM_read_bio_PrivateKey(Bio, nil, @PasswordCallback, Pwd);
  finally
    BIO_free(Bio);
  end;
end;

function LoadCertificateFromMemory(const AData: TBytes): PX509;
var
  Bio: PBIO;
begin
  Result := nil;
  if not TOpenSSLLoader.IsModuleLoaded(osmPEM) or
    (Length(AData) = 0) or
    not Assigned(BIO_new_mem_buf) or
    not Assigned(PEM_read_bio_X509) or
    not Assigned(BIO_free) then
    Exit;

  Bio := BIO_new_mem_buf(@AData[0], Length(AData));
  if Bio = nil then
    Exit;

  try
    Result := PEM_read_bio_X509(Bio, nil, nil, nil);
  finally
    BIO_free(Bio);
  end;
end;

end.
