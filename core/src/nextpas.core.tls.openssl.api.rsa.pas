unit nextpas.core.tls.openssl.api.rsa;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.bn, nextpas.core.tls.openssl.api.core;

const
  { RSA Padding modes }
  RSA_PKCS1_PADDING          = 1;
  RSA_SSLV23_PADDING         = 2;
  RSA_NO_PADDING             = 3;
  RSA_PKCS1_OAEP_PADDING     = 4;
  RSA_X931_PADDING           = 5;
  RSA_PKCS1_PSS_PADDING      = 6;
  RSA_PKCS1_WITH_TLS_PADDING = 7;
  
  { RSA Padding sizes }
  RSA_PKCS1_PADDING_SIZE     = 11;
  RSA_PKCS1_OAEP_PADDING_SIZE = 42;
  
  { RSA flags }
  RSA_FLAG_CACHE_PUBLIC      = $0002;
  RSA_FLAG_CACHE_PRIVATE     = $0004;
  RSA_FLAG_BLINDING          = $0008;
  RSA_FLAG_THREAD_SAFE       = $0010;
  RSA_FLAG_EXT_PKEY          = $0020;
  RSA_FLAG_NO_BLINDING       = $0080;
  RSA_FLAG_NO_CONSTTIME      = $0100;
  
  { RSA method flags }
  RSA_METHOD_FLAG_NO_CHECK   = $0001;
  
  { RSA Key Types }
  RSA_F4                     = $10001;
  RSA_3                      = 3;
  
  { RSA PSS constants }
  RSA_PSS_SALTLEN_DIGEST     = -1;
  RSA_PSS_SALTLEN_MAX_SIGN   = -2;
  RSA_PSS_SALTLEN_MAX        = -3;
  RSA_PSS_SALTLEN_AUTO       = -2;

type
  { RSA_METHOD structure }
  RSA_METHOD = record
    name: PAnsiChar;
    rsa_pub_enc: function(flen: Integer; const from: PByte; &to: PByte; rsa: PRSA; padding: Integer): Integer; cdecl;
    rsa_pub_dec: function(flen: Integer; const from: PByte; &to: PByte; rsa: PRSA; padding: Integer): Integer; cdecl;
    rsa_priv_enc: function(flen: Integer; const from: PByte; &to: PByte; rsa: PRSA; padding: Integer): Integer; cdecl;
    rsa_priv_dec: function(flen: Integer; const from: PByte; &to: PByte; rsa: PRSA; padding: Integer): Integer; cdecl;
    rsa_mod_exp: function(r0: PBIGNUM; const i: PBIGNUM; rsa: PRSA; ctx: PBN_CTX): Integer; cdecl;
    bn_mod_exp: function(r: PBIGNUM; const a: PBIGNUM; const p: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX; m_ctx: PBN_MONT_CTX): Integer; cdecl;
    init: function(rsa: PRSA): Integer; cdecl;
    finish: function(rsa: PRSA): Integer; cdecl;
    flags: Integer;
    app_data: PAnsiChar;
    rsa_sign: function(&type: Integer; const m: PByte; m_length: Cardinal; sigret: PByte; siglen: PCardinal; const rsa: PRSA): Integer; cdecl;
    rsa_verify: function(dtype: Integer; const m: PByte; m_length: Cardinal; const sigbuf: PByte; siglen: Cardinal; const rsa: PRSA): Integer; cdecl;
    rsa_keygen: function(rsa: PRSA; bits: Integer; e: PBIGNUM; cb: PBN_GENCB): Integer; cdecl;
    rsa_multi_prime_keygen: function(rsa: PRSA; bits: Integer; primes: Integer; e: PBIGNUM; cb: PBN_GENCB): Integer; cdecl;
  end;
  PRSA_METHOD = ^RSA_METHOD;

  { RSA function types }
  TRSA_new = function: PRSA; cdecl;
  TRSA_new_method = function(engine: PENGINE): PRSA; cdecl;
  TRSA_free = procedure(rsa: PRSA); cdecl;
  TRSA_up_ref = function(rsa: PRSA): Integer; cdecl;
  TRSA_bits = function(const rsa: PRSA): Integer; cdecl;
  TRSA_size = function(const rsa: PRSA): Integer; cdecl;
  TRSA_security_bits = function(const rsa: PRSA): Integer; cdecl;
  
  { RSA key manipulation }
  TRSA_set0_key = function(r: PRSA; n: PBIGNUM; e: PBIGNUM; d: PBIGNUM): Integer; cdecl;
  TRSA_set0_factors = function(r: PRSA; p: PBIGNUM; q: PBIGNUM): Integer; cdecl;
  TRSA_set0_crt_params = function(r: PRSA; dmp1: PBIGNUM; dmq1: PBIGNUM; iqmp: PBIGNUM): Integer; cdecl;
  TRSA_set0_multi_prime_params = function(r: PRSA; primes: PPBIGNUM; exps: PPBIGNUM; coeffs: PPBIGNUM; pnum: Integer): Integer; cdecl;
  TRSA_get0_key = procedure(const r: PRSA; const n: PPBIGNUM; const e: PPBIGNUM; const d: PPBIGNUM); cdecl;
  TRSA_get0_factors = procedure(const r: PRSA; const p: PPBIGNUM; const q: PPBIGNUM); cdecl;
  TRSA_get0_crt_params = procedure(const r: PRSA; const dmp1: PPBIGNUM; const dmq1: PPBIGNUM; const iqmp: PPBIGNUM); cdecl;
  TRSA_get0_multi_prime_factors = procedure(const r: PRSA; const primes: PPPBIGNUM); cdecl;
  TRSA_get0_multi_prime_crt_params = procedure(const r: PRSA; const exps: PPPBIGNUM; const coeffs: PPPBIGNUM); cdecl;
  TRSA_get0_n = function(const r: PRSA): PBIGNUM; cdecl;
  TRSA_get0_e = function(const r: PRSA): PBIGNUM; cdecl;
  TRSA_get0_d = function(const r: PRSA): PBIGNUM; cdecl;
  TRSA_get0_p = function(const r: PRSA): PBIGNUM; cdecl;
  TRSA_get0_q = function(const r: PRSA): PBIGNUM; cdecl;
  TRSA_get0_dmp1 = function(const r: PRSA): PBIGNUM; cdecl;
  TRSA_get0_dmq1 = function(const r: PRSA): PBIGNUM; cdecl;
  TRSA_get0_iqmp = function(const r: PRSA): PBIGNUM; cdecl;
  TRSA_get0_pss_params = function(const r: PRSA): Pointer; cdecl;
  TRSA_clear_flags = procedure(r: PRSA; flags: Integer); cdecl;
  TRSA_test_flags = function(const r: PRSA; flags: Integer): Integer; cdecl;
  TRSA_set_flags = procedure(r: PRSA; flags: Integer); cdecl;
  TRSA_get_version = function(r: PRSA): Integer; cdecl;
  TRSA_get0_engine = function(const r: PRSA): PENGINE; cdecl;
  
  { RSA key generation }
  TRSA_generate_key = function(bits: Integer; e: BN_ULONG; callback: Pointer; cb_arg: Pointer): PRSA; cdecl;
  TRSA_generate_key_ex = function(rsa: PRSA; bits: Integer; e: PBIGNUM; cb: PBN_GENCB): Integer; cdecl;
  TRSA_generate_multi_prime_key = function(rsa: PRSA; bits: Integer; primes: Integer; e: PBIGNUM; cb: PBN_GENCB): Integer; cdecl;
  TRSA_X931_derive_ex = function(rsa: PRSA; p1: PBIGNUM; p2: PBIGNUM; q1: PBIGNUM; q2: PBIGNUM;
                                  const Xp1: PBIGNUM; const Xp2: PBIGNUM; const Xp: PBIGNUM;
                                  const Xq1: PBIGNUM; const Xq2: PBIGNUM; const Xq: PBIGNUM;
                                  const e: PBIGNUM; cb: PBN_GENCB): Integer; cdecl;
  TRSA_X931_generate_key_ex = function(rsa: PRSA; bits: Integer; const e: PBIGNUM; cb: PBN_GENCB): Integer; cdecl;
  
  { RSA encryption/decryption }
  TRSA_public_encrypt = function(flen: Integer; const from: PByte; &to: PByte; rsa: PRSA; padding: Integer): Integer; cdecl;
  TRSA_private_encrypt = function(flen: Integer; const from: PByte; &to: PByte; rsa: PRSA; padding: Integer): Integer; cdecl;
  TRSA_public_decrypt = function(flen: Integer; const from: PByte; &to: PByte; rsa: PRSA; padding: Integer): Integer; cdecl;
  TRSA_private_decrypt = function(flen: Integer; const from: PByte; &to: PByte; rsa: PRSA; padding: Integer): Integer; cdecl;
  
  { RSA signing/verification }
  TRSA_sign = function(&type: Integer; const m: PByte; m_length: Cardinal; sigret: PByte; siglen: PCardinal; rsa: PRSA): Integer; cdecl;
  TRSA_verify = function(&type: Integer; const m: PByte; m_length: Cardinal; const sigbuf: PByte; siglen: Cardinal; rsa: PRSA): Integer; cdecl;
  TRSA_sign_ASN1_OCTET_STRING = function(&type: Integer; const m: PByte; m_length: Cardinal; sigret: PByte; siglen: PCardinal; rsa: PRSA): Integer; cdecl;
  TRSA_verify_ASN1_OCTET_STRING = function(&type: Integer; const m: PByte; m_length: Cardinal; const sigbuf: PByte; siglen: Cardinal; rsa: PRSA): Integer; cdecl;
  
  { RSA PSS functions }
  TRSA_padding_add_PKCS1_PSS = function(rsa: PRSA; EM: PByte; const mHash: PByte; const Hash: PEVP_MD; sLen: Integer): Integer; cdecl;
  TRSA_verify_PKCS1_PSS = function(rsa: PRSA; const mHash: PByte; const Hash: PEVP_MD; const EM: PByte; sLen: Integer): Integer; cdecl;
  TRSA_padding_add_PKCS1_PSS_mgf1 = function(rsa: PRSA; EM: PByte; const mHash: PByte; const Hash: PEVP_MD; const mgf1Hash: PEVP_MD; sLen: Integer): Integer; cdecl;
  TRSA_verify_PKCS1_PSS_mgf1 = function(rsa: PRSA; const mHash: PByte; const Hash: PEVP_MD; const mgf1Hash: PEVP_MD; const EM: PByte; sLen: Integer): Integer; cdecl;
  TRSA_pss_params_create = function(sigmd: PEVP_MD; mgf1md: PEVP_MD; saltlen: Integer): Pointer; cdecl;
  TRSA_pss_params_30_set_digest = function(rsa_pss_params: Pointer; md: PEVP_MD): Integer; cdecl;
  TRSA_pss_params_30_set_mgf1_md = function(rsa_pss_params: Pointer; mgf1md: PEVP_MD): Integer; cdecl;
  TRSA_pss_params_30_set_saltlen = function(rsa_pss_params: Pointer; saltlen: Integer): Integer; cdecl;
  
  { RSA padding functions }
  TRSA_padding_add_PKCS1_type_1 = function(&to: PByte; tlen: Integer; const f: PByte; fl: Integer): Integer; cdecl;
  TRSA_padding_check_PKCS1_type_1 = function(&to: PByte; tlen: Integer; const f: PByte; fl: Integer; rsa_len: Integer): Integer; cdecl;
  TRSA_padding_add_PKCS1_type_2 = function(&to: PByte; tlen: Integer; const f: PByte; fl: Integer): Integer; cdecl;
  TRSA_padding_check_PKCS1_type_2 = function(&to: PByte; tlen: Integer; const f: PByte; fl: Integer; rsa_len: Integer): Integer; cdecl;
  TRSA_padding_add_PKCS1_OAEP = function(&to: PByte; tlen: Integer; const f: PByte; fl: Integer; const p: PByte; pl: Integer): Integer; cdecl;
  TRSA_padding_check_PKCS1_OAEP = function(&to: PByte; tlen: Integer; const f: PByte; fl: Integer; rsa_len: Integer; const p: PByte; pl: Integer): Integer; cdecl;
  TRSA_padding_add_PKCS1_OAEP_mgf1 = function(&to: PByte; tlen: Integer; const from: PByte; flen: Integer; const param: PByte; plen: Integer; const md: PEVP_MD; const mgf1md: PEVP_MD): Integer; cdecl;
  TRSA_padding_check_PKCS1_OAEP_mgf1 = function(&to: PByte; tlen: Integer; const from: PByte; flen: Integer; num: Integer; const param: PByte; plen: Integer; const md: PEVP_MD; const mgf1md: PEVP_MD): Integer; cdecl;
  TRSA_padding_add_SSLv23 = function(&to: PByte; tlen: Integer; const f: PByte; fl: Integer): Integer; cdecl;
  TRSA_padding_check_SSLv23 = function(&to: PByte; tlen: Integer; const f: PByte; fl: Integer; rsa_len: Integer): Integer; cdecl;
  TRSA_padding_add_none = function(&to: PByte; tlen: Integer; const f: PByte; fl: Integer): Integer; cdecl;
  TRSA_padding_check_none = function(&to: PByte; tlen: Integer; const f: PByte; fl: Integer; rsa_len: Integer): Integer; cdecl;
  TRSA_padding_add_X931 = function(&to: PByte; tlen: Integer; const f: PByte; fl: Integer): Integer; cdecl;
  TRSA_padding_check_X931 = function(&to: PByte; tlen: Integer; const f: PByte; fl: Integer; rsa_len: Integer): Integer; cdecl;
  
  { RSA utility functions }
  TRSA_check_key = function(const rsa: PRSA): Integer; cdecl;
  TRSA_check_key_ex = function(const rsa: PRSA; cb: PBN_GENCB): Integer; cdecl;
  TRSA_print = function(bp: PBIO; const rsa: PRSA; offset: Integer): Integer; cdecl;
  TRSA_print_fp = function(fp: Pointer; const rsa: PRSA; offset: Integer): Integer; cdecl;
  TRSA_blinding_on = function(rsa: PRSA; ctx: PBN_CTX): Integer; cdecl;
  TRSA_blinding_off = procedure(rsa: PRSA); cdecl;
  TRSA_setup_blinding = function(rsa: PRSA; ctx: PBN_CTX): PBN_BLINDING; cdecl;
  
  { RSA method functions }
  TRSA_meth_new = function(const name: PAnsiChar; flags: Integer): PRSA_METHOD; cdecl;
  TRSA_meth_free = procedure(meth: PRSA_METHOD); cdecl;
  TRSA_meth_dup = function(const meth: PRSA_METHOD): PRSA_METHOD; cdecl;
  TRSA_meth_get0_name = function(const meth: PRSA_METHOD): PAnsiChar; cdecl;
  TRSA_meth_set1_name = function(meth: PRSA_METHOD; const name: PAnsiChar): Integer; cdecl;
  TRSA_meth_get_flags = function(const meth: PRSA_METHOD): Integer; cdecl;
  TRSA_meth_set_flags = function(meth: PRSA_METHOD; flags: Integer): Integer; cdecl;
  TRSA_meth_get0_app_data = function(const meth: PRSA_METHOD): Pointer; cdecl;
  TRSA_meth_set0_app_data = function(meth: PRSA_METHOD; app_data: Pointer): Integer; cdecl;
  TRSA_get_default_method = function: PRSA_METHOD; cdecl;
  TRSA_get_method = function(const rsa: PRSA): PRSA_METHOD; cdecl;
  TRSA_set_default_method = procedure(const meth: PRSA_METHOD); cdecl;
  TRSA_set_method = function(rsa: PRSA; const meth: PRSA_METHOD): Integer; cdecl;
  TRSA_PKCS1_OpenSSL = function: PRSA_METHOD; cdecl;
  TRSA_null_method = function: PRSA_METHOD; cdecl;
  
  { RSA ASN1 functions }
  TRSAPublicKey_dup = function(const rsa: PRSA): PRSA; cdecl;
  TRSAPrivateKey_dup = function(const rsa: PRSA): PRSA; cdecl;
  Ti2d_RSAPublicKey = function(const a: PRSA; pp: PPByte): Integer; cdecl;
  Td2i_RSAPublicKey = function(a: PPRSA; const pp: PPByte; length: clong): PRSA; cdecl;
  Ti2d_RSAPrivateKey = function(const a: PRSA; pp: PPByte): Integer; cdecl;
  Td2i_RSAPrivateKey = function(a: PPRSA; const pp: PPByte; length: clong): PRSA; cdecl;
  Ti2d_RSA_PUBKEY = function(const a: PRSA; pp: PPByte): Integer; cdecl;
  Td2i_RSA_PUBKEY = function(a: PPRSA; const pp: PPByte; length: clong): PRSA; cdecl;
  Ti2d_RSA_PUBKEY_bio = function(bp: PBIO; const rsa: PRSA): Integer; cdecl;
  Td2i_RSA_PUBKEY_bio = function(bp: PBIO; rsa: PPRSA): PRSA; cdecl;
  Ti2d_RSA_PUBKEY_fp = function(fp: Pointer; const rsa: PRSA): Integer; cdecl;
  Td2i_RSA_PUBKEY_fp = function(fp: Pointer; rsa: PPRSA): PRSA; cdecl;

var
  { RSA functions }
  RSA_new: TRSA_new;
  RSA_new_method: TRSA_new_method;
  RSA_free: TRSA_free;
  RSA_up_ref: TRSA_up_ref;
  RSA_bits: TRSA_bits;
  RSA_size: TRSA_size;
  RSA_security_bits: TRSA_security_bits;
  
  { RSA key manipulation }
  RSA_set0_key: TRSA_set0_key;
  RSA_set0_factors: TRSA_set0_factors;
  RSA_set0_crt_params: TRSA_set0_crt_params;
  RSA_set0_multi_prime_params: TRSA_set0_multi_prime_params;
  RSA_get0_key: TRSA_get0_key;
  RSA_get0_factors: TRSA_get0_factors;
  RSA_get0_crt_params: TRSA_get0_crt_params;
  RSA_get0_multi_prime_factors: TRSA_get0_multi_prime_factors;
  RSA_get0_multi_prime_crt_params: TRSA_get0_multi_prime_crt_params;
  RSA_get0_n: TRSA_get0_n;
  RSA_get0_e: TRSA_get0_e;
  RSA_get0_d: TRSA_get0_d;
  RSA_get0_p: TRSA_get0_p;
  RSA_get0_q: TRSA_get0_q;
  RSA_get0_dmp1: TRSA_get0_dmp1;
  RSA_get0_dmq1: TRSA_get0_dmq1;
  RSA_get0_iqmp: TRSA_get0_iqmp;
  RSA_get0_pss_params: TRSA_get0_pss_params;
  RSA_clear_flags: TRSA_clear_flags;
  RSA_test_flags: TRSA_test_flags;
  RSA_set_flags: TRSA_set_flags;
  RSA_get_version: TRSA_get_version;
  RSA_get0_engine: TRSA_get0_engine;
  
  { RSA key generation }
  RSA_generate_key: TRSA_generate_key;
  RSA_generate_key_ex: TRSA_generate_key_ex;
  RSA_generate_multi_prime_key: TRSA_generate_multi_prime_key;
  RSA_X931_derive_ex: TRSA_X931_derive_ex;
  RSA_X931_generate_key_ex: TRSA_X931_generate_key_ex;
  
  { RSA encryption/decryption }
  RSA_public_encrypt: TRSA_public_encrypt;
  RSA_private_encrypt: TRSA_private_encrypt;
  RSA_public_decrypt: TRSA_public_decrypt;
  RSA_private_decrypt: TRSA_private_decrypt;
  
  { RSA signing/verification }
  RSA_sign: TRSA_sign;
  RSA_verify: TRSA_verify;
  RSA_sign_ASN1_OCTET_STRING: TRSA_sign_ASN1_OCTET_STRING;
  RSA_verify_ASN1_OCTET_STRING: TRSA_verify_ASN1_OCTET_STRING;
  
  { RSA PSS functions }
  RSA_padding_add_PKCS1_PSS: TRSA_padding_add_PKCS1_PSS;
  RSA_verify_PKCS1_PSS: TRSA_verify_PKCS1_PSS;
  RSA_padding_add_PKCS1_PSS_mgf1: TRSA_padding_add_PKCS1_PSS_mgf1;
  RSA_verify_PKCS1_PSS_mgf1: TRSA_verify_PKCS1_PSS_mgf1;
  RSA_pss_params_create: TRSA_pss_params_create;
  RSA_pss_params_30_set_digest: TRSA_pss_params_30_set_digest;
  RSA_pss_params_30_set_mgf1_md: TRSA_pss_params_30_set_mgf1_md;
  RSA_pss_params_30_set_saltlen: TRSA_pss_params_30_set_saltlen;
  
  { RSA padding functions }
  RSA_padding_add_PKCS1_type_1: TRSA_padding_add_PKCS1_type_1;
  RSA_padding_check_PKCS1_type_1: TRSA_padding_check_PKCS1_type_1;
  RSA_padding_add_PKCS1_type_2: TRSA_padding_add_PKCS1_type_2;
  RSA_padding_check_PKCS1_type_2: TRSA_padding_check_PKCS1_type_2;
  RSA_padding_add_PKCS1_OAEP: TRSA_padding_add_PKCS1_OAEP;
  RSA_padding_check_PKCS1_OAEP: TRSA_padding_check_PKCS1_OAEP;
  RSA_padding_add_PKCS1_OAEP_mgf1: TRSA_padding_add_PKCS1_OAEP_mgf1;
  RSA_padding_check_PKCS1_OAEP_mgf1: TRSA_padding_check_PKCS1_OAEP_mgf1;
  RSA_padding_add_SSLv23: TRSA_padding_add_SSLv23;
  RSA_padding_check_SSLv23: TRSA_padding_check_SSLv23;
  RSA_padding_add_none: TRSA_padding_add_none;
  RSA_padding_check_none: TRSA_padding_check_none;
  RSA_padding_add_X931: TRSA_padding_add_X931;
  RSA_padding_check_X931: TRSA_padding_check_X931;
  
  { RSA utility functions }
  RSA_check_key: TRSA_check_key;
  RSA_check_key_ex: TRSA_check_key_ex;
  RSA_print: TRSA_print;
  RSA_print_fp: TRSA_print_fp;
  RSA_blinding_on: TRSA_blinding_on;
  RSA_blinding_off: TRSA_blinding_off;
  RSA_setup_blinding: TRSA_setup_blinding;
  
  { RSA method functions }
  RSA_meth_new: TRSA_meth_new;
  RSA_meth_free: TRSA_meth_free;
  RSA_meth_dup: TRSA_meth_dup;
  RSA_meth_get0_name: TRSA_meth_get0_name;
  RSA_meth_set1_name: TRSA_meth_set1_name;
  RSA_meth_get_flags: TRSA_meth_get_flags;
  RSA_meth_set_flags: TRSA_meth_set_flags;
  RSA_meth_get0_app_data: TRSA_meth_get0_app_data;
  RSA_meth_set0_app_data: TRSA_meth_set0_app_data;
  RSA_get_default_method: TRSA_get_default_method;
  RSA_get_method: TRSA_get_method;
  RSA_set_default_method: TRSA_set_default_method;
  RSA_set_method: TRSA_set_method;
  RSA_PKCS1_OpenSSL: TRSA_PKCS1_OpenSSL;
  RSA_null_method: TRSA_null_method;
  
  { RSA ASN1 functions }
  RSAPublicKey_dup: TRSAPublicKey_dup;
  RSAPrivateKey_dup: TRSAPrivateKey_dup;
  i2d_RSAPublicKey: Ti2d_RSAPublicKey;
  d2i_RSAPublicKey: Td2i_RSAPublicKey;
  i2d_RSAPrivateKey: Ti2d_RSAPrivateKey;
  d2i_RSAPrivateKey: Td2i_RSAPrivateKey;
  i2d_RSA_PUBKEY: Ti2d_RSA_PUBKEY;
  d2i_RSA_PUBKEY: Td2i_RSA_PUBKEY;
  i2d_RSA_PUBKEY_bio: Ti2d_RSA_PUBKEY_bio;
  d2i_RSA_PUBKEY_bio: Td2i_RSA_PUBKEY_bio;
  i2d_RSA_PUBKEY_fp: Ti2d_RSA_PUBKEY_fp;
  d2i_RSA_PUBKEY_fp: Td2i_RSA_PUBKEY_fp;

function LoadOpenSSLRSA: Boolean;
procedure UnloadOpenSSLRSA;

implementation

function LoadOpenSSLRSA: Boolean;
var
  LLib: TPlatformLibrary;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmRSA) then
    Exit(True);

  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    Exit(False);

  LLib := GetCryptoLibHandle;
  if not LibLoaded(LLib) then
    Exit(False);

  // Load RSA functions
  RSA_new := TRSA_new(GetCryptoProcAddress('RSA_new'));
  RSA_free := TRSA_free(GetCryptoProcAddress('RSA_free'));
  RSA_up_ref := TRSA_up_ref(GetCryptoProcAddress('RSA_up_ref'));
  RSA_bits := TRSA_bits(GetCryptoProcAddress('RSA_bits'));
  RSA_size := TRSA_size(GetCryptoProcAddress('RSA_size'));
  RSA_security_bits := TRSA_security_bits(GetCryptoProcAddress('RSA_security_bits'));

  // Key generation
  RSA_generate_key_ex := TRSA_generate_key_ex(GetCryptoProcAddress('RSA_generate_key_ex'));

  // Encryption/Decryption
  RSA_public_encrypt := TRSA_public_encrypt(GetCryptoProcAddress('RSA_public_encrypt'));
  RSA_private_encrypt := TRSA_private_encrypt(GetCryptoProcAddress('RSA_private_encrypt'));
  RSA_public_decrypt := TRSA_public_decrypt(GetCryptoProcAddress('RSA_public_decrypt'));
  RSA_private_decrypt := TRSA_private_decrypt(GetCryptoProcAddress('RSA_private_decrypt'));

  // Sign/Verify
  RSA_sign := TRSA_sign(GetCryptoProcAddress('RSA_sign'));
  RSA_verify := TRSA_verify(GetCryptoProcAddress('RSA_verify'));

  // Key manipulation
  RSA_set0_key := TRSA_set0_key(GetCryptoProcAddress('RSA_set0_key'));
  RSA_set0_factors := TRSA_set0_factors(GetCryptoProcAddress('RSA_set0_factors'));
  RSA_set0_crt_params := TRSA_set0_crt_params(GetCryptoProcAddress('RSA_set0_crt_params'));
  RSA_get0_key := TRSA_get0_key(GetCryptoProcAddress('RSA_get0_key'));
  RSA_get0_factors := TRSA_get0_factors(GetCryptoProcAddress('RSA_get0_factors'));
  RSA_get0_crt_params := TRSA_get0_crt_params(GetCryptoProcAddress('RSA_get0_crt_params'));

  // Individual parameter accessors (OpenSSL 1.1.0+)
  RSA_get0_n := TRSA_get0_n(GetCryptoProcAddress('RSA_get0_n'));
  RSA_get0_e := TRSA_get0_e(GetCryptoProcAddress('RSA_get0_e'));
  RSA_get0_d := TRSA_get0_d(GetCryptoProcAddress('RSA_get0_d'));
  RSA_get0_p := TRSA_get0_p(GetCryptoProcAddress('RSA_get0_p'));
  RSA_get0_q := TRSA_get0_q(GetCryptoProcAddress('RSA_get0_q'));
  RSA_get0_dmp1 := TRSA_get0_dmp1(GetCryptoProcAddress('RSA_get0_dmp1'));
  RSA_get0_dmq1 := TRSA_get0_dmq1(GetCryptoProcAddress('RSA_get0_dmq1'));
  RSA_get0_iqmp := TRSA_get0_iqmp(GetCryptoProcAddress('RSA_get0_iqmp'));

  // Utility functions
  RSA_check_key := TRSA_check_key(GetCryptoProcAddress('RSA_check_key'));
  RSA_check_key_ex := TRSA_check_key_ex(GetCryptoProcAddress('RSA_check_key_ex'));

  // ASN.1 DER helpers
  RSAPublicKey_dup := TRSAPublicKey_dup(GetCryptoProcAddress('RSAPublicKey_dup'));
  RSAPrivateKey_dup := TRSAPrivateKey_dup(GetCryptoProcAddress('RSAPrivateKey_dup'));
  i2d_RSAPublicKey := Ti2d_RSAPublicKey(GetCryptoProcAddress('i2d_RSAPublicKey'));
  d2i_RSAPublicKey := Td2i_RSAPublicKey(GetCryptoProcAddress('d2i_RSAPublicKey'));
  i2d_RSAPrivateKey := Ti2d_RSAPrivateKey(GetCryptoProcAddress('i2d_RSAPrivateKey'));
  d2i_RSAPrivateKey := Td2i_RSAPrivateKey(GetCryptoProcAddress('d2i_RSAPrivateKey'));
  i2d_RSA_PUBKEY := Ti2d_RSA_PUBKEY(GetCryptoProcAddress('i2d_RSA_PUBKEY'));
  d2i_RSA_PUBKEY := Td2i_RSA_PUBKEY(GetCryptoProcAddress('d2i_RSA_PUBKEY'));
  i2d_RSA_PUBKEY_bio := Ti2d_RSA_PUBKEY_bio(GetCryptoProcAddress('i2d_RSA_PUBKEY_bio'));
  d2i_RSA_PUBKEY_bio := Td2i_RSA_PUBKEY_bio(GetCryptoProcAddress('d2i_RSA_PUBKEY_bio'));
  i2d_RSA_PUBKEY_fp := Ti2d_RSA_PUBKEY_fp(GetCryptoProcAddress('i2d_RSA_PUBKEY_fp'));
  d2i_RSA_PUBKEY_fp := Td2i_RSA_PUBKEY_fp(GetCryptoProcAddress('d2i_RSA_PUBKEY_fp'));

  Result := Assigned(RSA_new) and Assigned(RSA_free);
  TOpenSSLLoader.SetModuleLoaded(osmRSA, Result);
end;

procedure UnloadOpenSSLRSA;
begin
  RSA_new := nil;
  RSA_free := nil;
  RSA_up_ref := nil;
  RSA_bits := nil;
  RSA_size := nil;
  RSA_security_bits := nil;
  RSA_generate_key_ex := nil;
  RSA_public_encrypt := nil;
  RSA_private_encrypt := nil;
  RSA_public_decrypt := nil;
  RSA_private_decrypt := nil;
  RSA_sign := nil;
  RSA_verify := nil;

  // Key manipulation
  RSA_set0_key := nil;
  RSA_set0_factors := nil;
  RSA_set0_crt_params := nil;
  RSA_get0_key := nil;
  RSA_get0_factors := nil;
  RSA_get0_crt_params := nil;

  // Individual parameter accessors
  RSA_get0_n := nil;
  RSA_get0_e := nil;
  RSA_get0_d := nil;
  RSA_get0_p := nil;
  RSA_get0_q := nil;
  RSA_get0_dmp1 := nil;
  RSA_get0_dmq1 := nil;
  RSA_get0_iqmp := nil;

  // Utility functions
  RSA_check_key := nil;
  RSA_check_key_ex := nil;

  // ASN.1 DER helpers
  RSAPublicKey_dup := nil;
  RSAPrivateKey_dup := nil;
  i2d_RSAPublicKey := nil;
  d2i_RSAPublicKey := nil;
  i2d_RSAPrivateKey := nil;
  d2i_RSAPrivateKey := nil;
  i2d_RSA_PUBKEY := nil;
  d2i_RSA_PUBKEY := nil;
  i2d_RSA_PUBKEY_bio := nil;
  d2i_RSA_PUBKEY_bio := nil;
  i2d_RSA_PUBKEY_fp := nil;
  d2i_RSA_PUBKEY_fp := nil;

  TOpenSSLLoader.SetModuleLoaded(osmRSA, False);
end;


end.
