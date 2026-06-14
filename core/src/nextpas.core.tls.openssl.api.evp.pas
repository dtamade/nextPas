{******************************************************************************}
{                                                                              }
{  fafafa.ssl - OpenSSL EVP Module                                           }
{                                                                              }
{  Copyright (c) 2024 fafafa                                                  }
{                                                                              }
{******************************************************************************}

unit nextpas.core.tls.openssl.api.evp;

{$mode ObjFPC}{$H+}

interface

uses Classes, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.loader;

type
  // EVP structures
  PEVP_MD = ^EVP_MD;
  EVP_MD = record end;
  
  PEVP_MD_CTX = ^EVP_MD_CTX;
  EVP_MD_CTX = record end;
  
  PEVP_CIPHER = ^EVP_CIPHER;
  EVP_CIPHER = record end;
  
  PEVP_CIPHER_CTX = ^EVP_CIPHER_CTX;
  EVP_CIPHER_CTX = record end;
  
  PEVP_PKEY = ^EVP_PKEY;
  EVP_PKEY = record end;
  
  PEVP_PKEY_CTX = ^EVP_PKEY_CTX;
  EVP_PKEY_CTX = record end;
  
  PEVP_MAC = ^EVP_MAC;
  EVP_MAC = record end;
  
  PEVP_MAC_CTX = ^EVP_MAC_CTX;
  EVP_MAC_CTX = record end;
  
  PEVP_KDF = ^EVP_KDF;
  EVP_KDF = record end;
  
  PEVP_KDF_CTX = ^EVP_KDF_CTX;
  EVP_KDF_CTX = record end;
  
  PEVP_KEYMGMT = ^EVP_KEYMGMT;
  EVP_KEYMGMT = record end;
  
  PEVP_SIGNATURE = ^EVP_SIGNATURE;
  EVP_SIGNATURE = record end;
  
  PEVP_ASYM_CIPHER = ^EVP_ASYM_CIPHER;
  EVP_ASYM_CIPHER = record end;
  
  PEVP_KEM = ^EVP_KEM;
  EVP_KEM = record end;
  
  PEVP_KEYEXCH = ^EVP_KEYEXCH;
  EVP_KEYEXCH = record end;
  
  PEVP_RAND = ^EVP_RAND;
  EVP_RAND = record end;
  
  PEVP_RAND_CTX = ^EVP_RAND_CTX;
  EVP_RAND_CTX = record end;

  // OSSL_PARAM for OpenSSL 3.0+
  POSSL_PARAM = ^OSSL_PARAM;
  OSSL_PARAM = record
    key: PAnsiChar;
    data_type: Byte;
    data: Pointer;
    data_size: NativeUInt;
    return_size: NativeUInt;
  end;
  
  POSSL_PARAM_BLD = ^OSSL_PARAM_BLD;
  OSSL_PARAM_BLD = record end;

const
  // EVP cipher modes
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
  EVP_CIPH_SIV_MODE = $10004;
  EVP_CIPH_MODE = $F0007;
  
  // EVP cipher flags
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
  EVP_CIPH_FLAG_CUSTOM_CIPHER = $100000;
  EVP_CIPH_FLAG_AEAD_CIPHER = $200000;
  EVP_CIPH_FLAG_TLS1_1_MULTIBLOCK = $400000;
  EVP_CIPH_FLAG_PIPELINE = $800000;
  EVP_CIPH_FLAG_CIPHER_WITH_MAC = $1000000;
  
  // EVP control commands
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
  
  // PKEY types
  EVP_PKEY_NONE = 0;
  EVP_PKEY_RSA = 6;
  EVP_PKEY_RSA2 = 19;
  EVP_PKEY_RSA_PSS = 912;
  EVP_PKEY_DSA = 116;
  EVP_PKEY_DSA1 = 66;
  EVP_PKEY_DSA2 = 67;
  EVP_PKEY_DSA3 = 68;
  EVP_PKEY_DSA4 = 69;
  EVP_PKEY_DH = 28;
  EVP_PKEY_DHX = 920;
  EVP_PKEY_EC = 408;
  EVP_PKEY_SM2 = 1172;
  EVP_PKEY_HMAC = 855;
  EVP_PKEY_CMAC = 894;
  EVP_PKEY_SCRYPT = 973;
  EVP_PKEY_TLS1_PRF = 1021;
  EVP_PKEY_HKDF = 1036;
  EVP_PKEY_POLY1305 = 1061;
  EVP_PKEY_SIPHASH = 1062;
  EVP_PKEY_X25519 = 1034;
  EVP_PKEY_ED25519 = 1087;
  EVP_PKEY_X448 = 1035;
  EVP_PKEY_ED448 = 1088;
  
  // EVP digest constants
  EVP_MAX_MD_SIZE = 64;  // Maximum digest size (SHA-512)
  EVP_MAX_KEY_LENGTH = 64;
  EVP_MAX_IV_LENGTH = 16;
  EVP_MAX_BLOCK_LENGTH = 32;
  
  // PKEY control commands
  EVP_PKEY_CTRL_MD = 1;
  EVP_PKEY_CTRL_PEER_KEY = 2;
  EVP_PKEY_CTRL_PKCS7_ENCRYPT = 3;
  EVP_PKEY_CTRL_PKCS7_DECRYPT = 4;
  EVP_PKEY_CTRL_PKCS7_SIGN = 5;
  EVP_PKEY_CTRL_SET_MAC_KEY = 6;
  EVP_PKEY_CTRL_DIGESTINIT = 7;
  EVP_PKEY_CTRL_SET_IV = 8;
  EVP_PKEY_CTRL_CMS_ENCRYPT = 9;
  EVP_PKEY_CTRL_CMS_DECRYPT = 10;
  EVP_PKEY_CTRL_CMS_SIGN = 11;
  EVP_PKEY_CTRL_CIPHER = 12;
  EVP_PKEY_CTRL_GET_MD = 13;
  EVP_PKEY_CTRL_SET_DIGEST_SIZE = 14;
  
  // RSA specific control commands
  EVP_PKEY_CTRL_RSA_PADDING = $1001;
  EVP_PKEY_CTRL_RSA_PSS_SALTLEN = $1002;
  EVP_PKEY_CTRL_RSA_KEYGEN_BITS = $1003;
  EVP_PKEY_CTRL_RSA_KEYGEN_PUBEXP = $1004;
  EVP_PKEY_CTRL_RSA_MGF1_MD = $1005;
  EVP_PKEY_CTRL_GET_RSA_PADDING = $1006;
  EVP_PKEY_CTRL_GET_RSA_PSS_SALTLEN = $1007;
  EVP_PKEY_CTRL_GET_RSA_MGF1_MD = $1008;
  EVP_PKEY_CTRL_RSA_OAEP_MD = $1009;
  EVP_PKEY_CTRL_RSA_OAEP_LABEL = $100A;
  EVP_PKEY_CTRL_GET_RSA_OAEP_MD = $100B;
  EVP_PKEY_CTRL_GET_RSA_OAEP_LABEL = $100C;
  
  // PKEY operations
  EVP_PKEY_OP_UNDEFINED = 0;
  EVP_PKEY_OP_PARAMGEN = (1 shl 1);
  EVP_PKEY_OP_KEYGEN = (1 shl 2);
  EVP_PKEY_OP_FROMDATA = (1 shl 3);
  EVP_PKEY_OP_SIGN = (1 shl 4);
  EVP_PKEY_OP_VERIFY = (1 shl 5);
  EVP_PKEY_OP_VERIFYRECOVER = (1 shl 6);
  EVP_PKEY_OP_SIGNCTX = (1 shl 7);
  EVP_PKEY_OP_VERIFYCTX = (1 shl 8);
  EVP_PKEY_OP_ENCRYPT = (1 shl 9);
  EVP_PKEY_OP_DECRYPT = (1 shl 10);
  EVP_PKEY_OP_DERIVE = (1 shl 11);
  EVP_PKEY_OP_ENCAPSULATE = (1 shl 12);
  EVP_PKEY_OP_DECAPSULATE = (1 shl 13);

type
  // Digest functions
  TEVP_MD_CTX_new = function: PEVP_MD_CTX; cdecl;
  TEVP_MD_CTX_free = procedure(ctx: PEVP_MD_CTX); cdecl;
  TEVP_MD_CTX_reset = function(ctx: PEVP_MD_CTX): Integer; cdecl;
  TEVP_MD_CTX_copy = function(out_: PEVP_MD_CTX; const in_: PEVP_MD_CTX): Integer; cdecl;
  TEVP_MD_CTX_copy_ex = function(out_: PEVP_MD_CTX; const in_: PEVP_MD_CTX): Integer; cdecl;
  
  TEVP_DigestInit = function(ctx: PEVP_MD_CTX; const type_: PEVP_MD): Integer; cdecl;
  TEVP_DigestInit_ex = function(ctx: PEVP_MD_CTX; const type_: PEVP_MD; impl: PENGINE): Integer; cdecl;
  TEVP_DigestInit_ex2 = function(ctx: PEVP_MD_CTX; const type_: PEVP_MD; const params: POSSL_PARAM): Integer; cdecl;
  TEVP_DigestUpdate = function(ctx: PEVP_MD_CTX; const d: Pointer; cnt: NativeUInt): Integer; cdecl;
  TEVP_DigestFinal = function(ctx: PEVP_MD_CTX; md: PByte; var s: Cardinal): Integer; cdecl;
  TEVP_DigestFinal_ex = function(ctx: PEVP_MD_CTX; md: PByte; var s: Cardinal): Integer; cdecl;
  TEVP_DigestFinalXOF = function(ctx: PEVP_MD_CTX; md: PByte; len: NativeUInt): Integer; cdecl;
  TEVP_Digest = function(const data: Pointer; count: NativeUInt; md: PByte; var size: Cardinal; const type_: PEVP_MD; impl: PENGINE): Integer; cdecl;
  
  TEVP_MD_CTX_get0_md = function(const ctx: PEVP_MD_CTX): PEVP_MD; cdecl;
  TEVP_MD_CTX_get1_md = function(ctx: PEVP_MD_CTX): PEVP_MD; cdecl;
  TEVP_MD_CTX_set_flags = procedure(ctx: PEVP_MD_CTX; flags: Integer); cdecl;
  TEVP_MD_CTX_clear_flags = procedure(ctx: PEVP_MD_CTX; flags: Integer); cdecl;
  TEVP_MD_CTX_test_flags = function(const ctx: PEVP_MD_CTX; flags: Integer): Integer; cdecl;
  TEVP_MD_CTX_get_size = function(const ctx: PEVP_MD_CTX): Integer; cdecl;
  TEVP_MD_CTX_get_block_size = function(const ctx: PEVP_MD_CTX): Integer; cdecl;
  TEVP_MD_CTX_get0_md_data = function(const ctx: PEVP_MD_CTX): Pointer; cdecl;
  
  // MD algorithms
  TEVP_md_null = function: PEVP_MD; cdecl;
  TEVP_md4 = function: PEVP_MD; cdecl;
  TEVP_md5 = function: PEVP_MD; cdecl;
  TEVP_md5_sha1 = function: PEVP_MD; cdecl;
  TEVP_blake2b512 = function: PEVP_MD; cdecl;
  TEVP_blake2s256 = function: PEVP_MD; cdecl;
  TEVP_sha1 = function: PEVP_MD; cdecl;
  TEVP_sha224 = function: PEVP_MD; cdecl;
  TEVP_sha256 = function: PEVP_MD; cdecl;
  TEVP_sha384 = function: PEVP_MD; cdecl;
  TEVP_sha512 = function: PEVP_MD; cdecl;
  TEVP_sha512_224 = function: PEVP_MD; cdecl;
  TEVP_sha512_256 = function: PEVP_MD; cdecl;
  TEVP_sha3_224 = function: PEVP_MD; cdecl;
  TEVP_sha3_256 = function: PEVP_MD; cdecl;
  TEVP_sha3_384 = function: PEVP_MD; cdecl;
  TEVP_sha3_512 = function: PEVP_MD; cdecl;
  TEVP_shake128 = function: PEVP_MD; cdecl;
  TEVP_shake256 = function: PEVP_MD; cdecl;
  TEVP_sm3 = function: PEVP_MD; cdecl;
  TEVP_ripemd160 = function: PEVP_MD; cdecl;
  TEVP_whirlpool = function: PEVP_MD; cdecl;
  
  TEVP_get_digestbyname = function(const name: PAnsiChar): PEVP_MD; cdecl;
  TEVP_get_digestbynid = function(nid: Integer): PEVP_MD; cdecl;
  TEVP_MD_get_size = function(const md: PEVP_MD): Integer; cdecl;
  TEVP_MD_get_block_size = function(const md: PEVP_MD): Integer; cdecl;
  TEVP_MD_get_flags = function(const md: PEVP_MD): LongWord; cdecl;
  TEVP_MD_get_type = function(const md: PEVP_MD): Integer; cdecl;
  
  // OpenSSL 3.x EVP_MD fetch API
  TEVP_MD_fetch = function(ctx: POSSL_LIB_CTX; const algorithm: PAnsiChar; const properties: PAnsiChar): PEVP_MD; cdecl;
  TEVP_MD_free = procedure(md: PEVP_MD); cdecl;
  
  // Cipher functions
  TEVP_CIPHER_CTX_new = function: PEVP_CIPHER_CTX; cdecl;
  TEVP_CIPHER_CTX_free = procedure(ctx: PEVP_CIPHER_CTX); cdecl;
  TEVP_CIPHER_CTX_reset = function(ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  TEVP_CIPHER_CTX_copy = function(out_: PEVP_CIPHER_CTX; const in_: PEVP_CIPHER_CTX): Integer; cdecl;
  
  TEVP_CipherInit = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; const key: PByte; const iv: PByte; enc: Integer): Integer; cdecl;
  TEVP_CipherInit_ex = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; impl: PENGINE; const key: PByte; const iv: PByte; enc: Integer): Integer; cdecl;
  TEVP_CipherInit_ex2 = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; const key: PByte; const iv: PByte; enc: Integer; const params: POSSL_PARAM): Integer; cdecl;
  TEVP_CipherUpdate = function(ctx: PEVP_CIPHER_CTX; out_: PByte; var outl: Integer; const in_: PByte; inl: Integer): Integer; cdecl;
  TEVP_CipherFinal = function(ctx: PEVP_CIPHER_CTX; outm: PByte; var outl: Integer): Integer; cdecl;
  TEVP_CipherFinal_ex = function(ctx: PEVP_CIPHER_CTX; outm: PByte; var outl: Integer): Integer; cdecl;
  TEVP_Cipher = function(ctx: PEVP_CIPHER_CTX; out_: PByte; const in_: PByte; inl: Cardinal): Integer; cdecl;
  
  TEVP_EncryptInit = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; const key: PByte; const iv: PByte): Integer; cdecl;
  TEVP_EncryptInit_ex = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; impl: PENGINE; const key: PByte; const iv: PByte): Integer; cdecl;
  TEVP_EncryptInit_ex2 = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; const key: PByte; const iv: PByte; const params: POSSL_PARAM): Integer; cdecl;
  TEVP_EncryptUpdate = function(ctx: PEVP_CIPHER_CTX; out_: PByte; var outl: Integer; const in_: PByte; inl: Integer): Integer; cdecl;
  TEVP_EncryptFinal = function(ctx: PEVP_CIPHER_CTX; out_: PByte; var outl: Integer): Integer; cdecl;
  TEVP_EncryptFinal_ex = function(ctx: PEVP_CIPHER_CTX; out_: PByte; var outl: Integer): Integer; cdecl;
  
  TEVP_DecryptInit = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; const key: PByte; const iv: PByte): Integer; cdecl;
  TEVP_DecryptInit_ex = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; impl: PENGINE; const key: PByte; const iv: PByte): Integer; cdecl;
  TEVP_DecryptInit_ex2 = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; const key: PByte; const iv: PByte; const params: POSSL_PARAM): Integer; cdecl;
  TEVP_DecryptUpdate = function(ctx: PEVP_CIPHER_CTX; out_: PByte; var outl: Integer; const in_: PByte; inl: Integer): Integer; cdecl;
  TEVP_DecryptFinal = function(ctx: PEVP_CIPHER_CTX; outm: PByte; var outl: Integer): Integer; cdecl;
  TEVP_DecryptFinal_ex = function(ctx: PEVP_CIPHER_CTX; outm: PByte; var outl: Integer): Integer; cdecl;
  
  TEVP_CIPHER_CTX_ctrl = function(ctx: PEVP_CIPHER_CTX; type_: Integer; arg: Integer; ptr: Pointer): Integer; cdecl;
  TEVP_CIPHER_CTX_set_key_length = function(ctx: PEVP_CIPHER_CTX; keylen: Integer): Integer; cdecl;
  TEVP_CIPHER_CTX_set_padding = function(ctx: PEVP_CIPHER_CTX; padding: Integer): Integer; cdecl;
  TEVP_CIPHER_CTX_get_cipher = function(const ctx: PEVP_CIPHER_CTX): PEVP_CIPHER; cdecl;
  TEVP_CIPHER_CTX_get_key_length = function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  TEVP_CIPHER_CTX_get_iv_length = function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  TEVP_CIPHER_CTX_get_tag_length = function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  TEVP_CIPHER_CTX_get_block_size = function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  TEVP_CIPHER_CTX_get_mode = function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  TEVP_CIPHER_CTX_get_type = function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  TEVP_CIPHER_CTX_get_nid = function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;

  // OpenSSL 3.x EVP_CIPHER fetch API
  TEVP_CIPHER_fetch = function(ctx: POSSL_LIB_CTX; const algorithm: PAnsiChar; const properties: PAnsiChar): PEVP_CIPHER; cdecl;
  TEVP_CIPHER_free = procedure(cipher: PEVP_CIPHER); cdecl;

  // Cipher algorithms
  TEVP_enc_null = function: PEVP_CIPHER; cdecl;
  TEVP_des_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3 = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_des_cfb64 = function: PEVP_CIPHER; cdecl;
  TEVP_des_cfb1 = function: PEVP_CIPHER; cdecl;
  TEVP_des_cfb8 = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede_cfb64 = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3_cfb64 = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3_cfb1 = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3_cfb8 = function: PEVP_CIPHER; cdecl;
  TEVP_des_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_des_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_desx_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3_wrap = function: PEVP_CIPHER; cdecl;
  
  TEVP_rc4 = function: PEVP_CIPHER; cdecl;
  TEVP_rc4_40 = function: PEVP_CIPHER; cdecl;
  TEVP_rc4_hmac_md5 = function: PEVP_CIPHER; cdecl;
  
  TEVP_idea_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_idea_cfb64 = function: PEVP_CIPHER; cdecl;
  TEVP_idea_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_idea_cbc = function: PEVP_CIPHER; cdecl;
  
  TEVP_rc2_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_rc2_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_rc2_40_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_rc2_64_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_rc2_cfb64 = function: PEVP_CIPHER; cdecl;
  TEVP_rc2_ofb = function: PEVP_CIPHER; cdecl;
  
  TEVP_bf_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_bf_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_bf_cfb64 = function: PEVP_CIPHER; cdecl;
  TEVP_bf_ofb = function: PEVP_CIPHER; cdecl;
  
  TEVP_cast5_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_cast5_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_cast5_cfb64 = function: PEVP_CIPHER; cdecl;
  TEVP_cast5_ofb = function: PEVP_CIPHER; cdecl;
  
  TEVP_aes_128_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_aes_128_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_aes_128_cfb1 = function: PEVP_CIPHER; cdecl;
  TEVP_aes_128_cfb8 = function: PEVP_CIPHER; cdecl;
  TEVP_aes_128_cfb128 = function: PEVP_CIPHER; cdecl;
  TEVP_aes_128_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_aes_128_ctr = function: PEVP_CIPHER; cdecl;
  TEVP_aes_128_ccm = function: PEVP_CIPHER; cdecl;
  TEVP_aes_128_gcm = function: PEVP_CIPHER; cdecl;
  TEVP_aes_128_xts = function: PEVP_CIPHER; cdecl;
  TEVP_aes_128_wrap = function: PEVP_CIPHER; cdecl;
  TEVP_aes_128_wrap_pad = function: PEVP_CIPHER; cdecl;
  TEVP_aes_128_ocb = function: PEVP_CIPHER; cdecl;
  
  TEVP_aes_192_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_aes_192_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_aes_192_cfb1 = function: PEVP_CIPHER; cdecl;
  TEVP_aes_192_cfb8 = function: PEVP_CIPHER; cdecl;
  TEVP_aes_192_cfb128 = function: PEVP_CIPHER; cdecl;
  TEVP_aes_192_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_aes_192_ctr = function: PEVP_CIPHER; cdecl;
  TEVP_aes_192_ccm = function: PEVP_CIPHER; cdecl;
  TEVP_aes_192_gcm = function: PEVP_CIPHER; cdecl;
  TEVP_aes_192_wrap = function: PEVP_CIPHER; cdecl;
  TEVP_aes_192_wrap_pad = function: PEVP_CIPHER; cdecl;
  TEVP_aes_192_ocb = function: PEVP_CIPHER; cdecl;
  
  TEVP_aes_256_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_aes_256_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_aes_256_cfb1 = function: PEVP_CIPHER; cdecl;
  TEVP_aes_256_cfb8 = function: PEVP_CIPHER; cdecl;
  TEVP_aes_256_cfb128 = function: PEVP_CIPHER; cdecl;
  TEVP_aes_256_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_aes_256_ctr = function: PEVP_CIPHER; cdecl;
  TEVP_aes_256_ccm = function: PEVP_CIPHER; cdecl;
  TEVP_aes_256_gcm = function: PEVP_CIPHER; cdecl;
  TEVP_aes_256_xts = function: PEVP_CIPHER; cdecl;
  TEVP_aes_256_wrap = function: PEVP_CIPHER; cdecl;
  TEVP_aes_256_wrap_pad = function: PEVP_CIPHER; cdecl;
  TEVP_aes_256_ocb = function: PEVP_CIPHER; cdecl;
  
  TEVP_camellia_128_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_128_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_128_cfb1 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_128_cfb8 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_128_cfb128 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_128_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_128_ctr = function: PEVP_CIPHER; cdecl;
  
  TEVP_camellia_192_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_192_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_192_cfb1 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_192_cfb8 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_192_cfb128 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_192_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_192_ctr = function: PEVP_CIPHER; cdecl;
  
  TEVP_camellia_256_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_256_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_256_cfb1 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_256_cfb8 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_256_cfb128 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_256_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_256_ctr = function: PEVP_CIPHER; cdecl;
  
  TEVP_chacha20 = function: PEVP_CIPHER; cdecl;
  TEVP_chacha20_poly1305 = function: PEVP_CIPHER; cdecl;
  
  TEVP_sm4_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_sm4_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_sm4_cfb128 = function: PEVP_CIPHER; cdecl;
  TEVP_sm4_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_sm4_ctr = function: PEVP_CIPHER; cdecl;
  
  TEVP_get_cipherbyname = function(const name: PAnsiChar): PEVP_CIPHER; cdecl;
  TEVP_get_cipherbynid = function(nid: Integer): PEVP_CIPHER; cdecl;
  TEVP_CIPHER_get_key_length = function(const cipher: PEVP_CIPHER): Integer; cdecl;
  TEVP_CIPHER_get_iv_length = function(const cipher: PEVP_CIPHER): Integer; cdecl;
  TEVP_CIPHER_get_block_size = function(const cipher: PEVP_CIPHER): Integer; cdecl;
  TEVP_CIPHER_get_mode = function(const cipher: PEVP_CIPHER): Integer; cdecl;
  TEVP_CIPHER_get_type = function(const cipher: PEVP_CIPHER): Integer; cdecl;
  TEVP_CIPHER_get_nid = function(const cipher: PEVP_CIPHER): Integer; cdecl;
  
  // PKEY functions
  TEVP_PKEY_new = function: PEVP_PKEY; cdecl;
  TEVP_PKEY_new_raw_private_key = function(type_: Integer; e: PENGINE; const priv: PByte; len: NativeUInt): PEVP_PKEY; cdecl;
  TEVP_PKEY_new_raw_public_key = function(type_: Integer; e: PENGINE; const pub: PByte; len: NativeUInt): PEVP_PKEY; cdecl;
  TEVP_PKEY_new_CMAC_key = function(e: PENGINE; const priv: PByte; len: NativeUInt; const cipher: PEVP_CIPHER): PEVP_PKEY; cdecl;
  TEVP_PKEY_new_mac_key = function(type_: Integer; e: PENGINE; const key: PByte; keylen: Integer): PEVP_PKEY; cdecl;
  TEVP_PKEY_up_ref = function(pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_free = procedure(pkey: PEVP_PKEY); cdecl;
  
  TEVP_PKEY_get_raw_private_key = function(const pkey: PEVP_PKEY; priv: PByte; var len: NativeUInt): Integer; cdecl;
  TEVP_PKEY_get_raw_public_key = function(const pkey: PEVP_PKEY; pub: PByte; var len: NativeUInt): Integer; cdecl;
  
  TEVP_PKEY_assign = function(pkey: PEVP_PKEY; type_: Integer; key: Pointer): Integer; cdecl;
  TEVP_PKEY_set1_RSA = function(pkey: PEVP_PKEY; key: PRSA): Integer; cdecl;
  TEVP_PKEY_set1_DSA = function(pkey: PEVP_PKEY; key: PDSA): Integer; cdecl;
  TEVP_PKEY_set1_DH = function(pkey: PEVP_PKEY; key: PDH): Integer; cdecl;
  TEVP_PKEY_set1_EC_KEY = function(pkey: PEVP_PKEY; key: PEC_KEY): Integer; cdecl;
  
  TEVP_PKEY_get0_RSA = function(pkey: PEVP_PKEY): PRSA; cdecl;
  TEVP_PKEY_get0_DSA = function(pkey: PEVP_PKEY): PDSA; cdecl;
  TEVP_PKEY_get0_DH = function(pkey: PEVP_PKEY): PDH; cdecl;
  TEVP_PKEY_get0_EC_KEY = function(pkey: PEVP_PKEY): PEC_KEY; cdecl;
  
  TEVP_PKEY_get1_RSA = function(pkey: PEVP_PKEY): PRSA; cdecl;
  TEVP_PKEY_get1_DSA = function(pkey: PEVP_PKEY): PDSA; cdecl;
  TEVP_PKEY_get1_DH = function(pkey: PEVP_PKEY): PDH; cdecl;
  TEVP_PKEY_get1_EC_KEY = function(pkey: PEVP_PKEY): PEC_KEY; cdecl;
  
  TEVP_PKEY_get_id = function(const pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_get_base_id = function(const pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_get_bits = function(const pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_get_security_bits = function(const pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_get_size = function(const pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_can_sign = function(const pkey: PEVP_PKEY): Integer; cdecl;
  
  TEVP_PKEY_missing_parameters = function(const pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_copy_parameters = function(to_: PEVP_PKEY; const from: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_parameters_eq = function(const a: PEVP_PKEY; const b: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_eq = function(const a: PEVP_PKEY; const b: PEVP_PKEY): Integer; cdecl;
  
  // PKEY encoding/decoding functions
  Ti2d_PUBKEY = function(a: PEVP_PKEY; pp: PPByte): Integer; cdecl;
  Ti2d_PUBKEY_bio = function(bp: PBIO; pkey: PEVP_PKEY): Integer; cdecl;
  Ti2d_PUBKEY_fp = function(fp: Pointer; pkey: PEVP_PKEY): Integer; cdecl;
  Td2i_PUBKEY = function(a: PPEVP_PKEY; pp: PPByte; length: Integer): PEVP_PKEY; cdecl;
  Td2i_PUBKEY_bio = function(bp: PBIO; a: PPEVP_PKEY): PEVP_PKEY; cdecl;
  Td2i_PUBKEY_fp = function(fp: Pointer; a: PPEVP_PKEY): PEVP_PKEY; cdecl;
  
  TEVP_PKEY_CTX_new = function(pkey: PEVP_PKEY; e: PENGINE): PEVP_PKEY_CTX; cdecl;
  TEVP_PKEY_CTX_new_id = function(id: Integer; e: PENGINE): PEVP_PKEY_CTX; cdecl;
  TEVP_PKEY_CTX_new_from_name = function(libctx: POSSL_LIB_CTX; const name: PAnsiChar; const propquery: PAnsiChar): PEVP_PKEY_CTX; cdecl;
  TEVP_PKEY_CTX_new_from_pkey = function(libctx: POSSL_LIB_CTX; pkey: PEVP_PKEY; const propquery: PAnsiChar): PEVP_PKEY_CTX; cdecl;
  TEVP_PKEY_CTX_dup = function(ctx: PEVP_PKEY_CTX): PEVP_PKEY_CTX; cdecl;
  TEVP_PKEY_CTX_free = procedure(ctx: PEVP_PKEY_CTX); cdecl;
  
  TEVP_PKEY_CTX_ctrl = function(ctx: PEVP_PKEY_CTX; keytype: Integer; optype: Integer; cmd: Integer; p1: Integer; p2: Pointer): Integer; cdecl;
  TEVP_PKEY_CTX_ctrl_str = function(ctx: PEVP_PKEY_CTX; const type_: PAnsiChar; const value: PAnsiChar): Integer; cdecl;
  TEVP_PKEY_CTX_ctrl_uint64 = function(ctx: PEVP_PKEY_CTX; keytype: Integer; optype: Integer; cmd: Integer; value: UInt64): Integer; cdecl;
  
  TEVP_PKEY_CTX_set_cb = procedure(ctx: PEVP_PKEY_CTX; cb: Pointer); cdecl;
  TEVP_PKEY_CTX_get_cb = function(ctx: PEVP_PKEY_CTX): Pointer; cdecl;
  TEVP_PKEY_CTX_get_keygen_info = function(ctx: PEVP_PKEY_CTX; idx: Integer): Integer; cdecl;
  TEVP_PKEY_CTX_set_app_data = procedure(ctx: PEVP_PKEY_CTX; data: Pointer); cdecl;
  TEVP_PKEY_CTX_get_app_data = function(ctx: PEVP_PKEY_CTX): Pointer; cdecl;
  
  TEVP_PKEY_CTX_get_operation = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_CTX_set0_keygen_info = procedure(ctx: PEVP_PKEY_CTX; dat: PInteger; datlen: Integer); cdecl;
  TEVP_PKEY_CTX_get0_pkey = function(ctx: PEVP_PKEY_CTX): PEVP_PKEY; cdecl;
  TEVP_PKEY_CTX_get0_peerkey = function(ctx: PEVP_PKEY_CTX): PEVP_PKEY; cdecl;
  
  TEVP_PKEY_paramgen_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_paramgen = function(ctx: PEVP_PKEY_CTX; var ppkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_keygen_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_keygen = function(ctx: PEVP_PKEY_CTX; var ppkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_generate = function(ctx: PEVP_PKEY_CTX; var ppkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_check = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_public_check = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_public_check_quick = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_private_check = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_pairwise_check = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  
  TEVP_PKEY_sign_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_sign = function(ctx: PEVP_PKEY_CTX; sig: PByte; var siglen: NativeUInt; const tbs: PByte; tbslen: NativeUInt): Integer; cdecl;
  TEVP_PKEY_verify_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_verify = function(ctx: PEVP_PKEY_CTX; const sig: PByte; siglen: NativeUInt; const tbs: PByte; tbslen: NativeUInt): Integer; cdecl;
  TEVP_PKEY_verify_recover_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_verify_recover = function(ctx: PEVP_PKEY_CTX; rout: PByte; var routlen: NativeUInt; const sig: PByte; siglen: NativeUInt): Integer; cdecl;
  
  TEVP_PKEY_encrypt_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_encrypt = function(ctx: PEVP_PKEY_CTX; out_: PByte; var outlen: NativeUInt; const in_: PByte; inlen: NativeUInt): Integer; cdecl;
  TEVP_PKEY_decrypt_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_decrypt = function(ctx: PEVP_PKEY_CTX; out_: PByte; var outlen: NativeUInt; const in_: PByte; inlen: NativeUInt): Integer; cdecl;
  
  TEVP_PKEY_derive_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_derive_set_peer = function(ctx: PEVP_PKEY_CTX; peer: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_derive = function(ctx: PEVP_PKEY_CTX; key: PByte; var keylen: NativeUInt): Integer; cdecl;
  
  TEVP_PKEY_encapsulate_init = function(ctx: PEVP_PKEY_CTX; const params: POSSL_PARAM): Integer; cdecl;
  TEVP_PKEY_encapsulate = function(ctx: PEVP_PKEY_CTX; wrappedkey: PByte; var wrappedkeylen: NativeUInt; 
                                  genkey: PByte; var genkeylen: NativeUInt): Integer; cdecl;
  TEVP_PKEY_decapsulate_init = function(ctx: PEVP_PKEY_CTX; const params: POSSL_PARAM): Integer; cdecl;
  TEVP_PKEY_decapsulate = function(ctx: PEVP_PKEY_CTX; unwrapped: PByte; var unwrappedlen: NativeUInt;
                                    const wrapped: PByte; wrappedlen: NativeUInt): Integer; cdecl;
  
  // MAC functions
  TEVP_MAC_fetch = function(libctx: POSSL_LIB_CTX; const algorithm: PAnsiChar; const properties: PAnsiChar): PEVP_MAC; cdecl;
  TEVP_MAC_up_ref = function(mac: PEVP_MAC): Integer; cdecl;
  TEVP_MAC_free = procedure(mac: PEVP_MAC); cdecl;
  TEVP_MAC_CTX_new = function(mac: PEVP_MAC): PEVP_MAC_CTX; cdecl;
  TEVP_MAC_CTX_free = procedure(ctx: PEVP_MAC_CTX); cdecl;
  TEVP_MAC_CTX_dup = function(const src: PEVP_MAC_CTX): PEVP_MAC_CTX; cdecl;
  TEVP_MAC_CTX_get0_mac = function(ctx: PEVP_MAC_CTX): PEVP_MAC; cdecl;
  TEVP_MAC_CTX_get_mac_size = function(ctx: PEVP_MAC_CTX): NativeUInt; cdecl;
  TEVP_MAC_CTX_get_block_size = function(ctx: PEVP_MAC_CTX): NativeUInt; cdecl;
  TEVP_MAC_init = function(ctx: PEVP_MAC_CTX; const key: PByte; keylen: NativeUInt; const params: POSSL_PARAM): Integer; cdecl;
  TEVP_MAC_update = function(ctx: PEVP_MAC_CTX; const data: PByte; datalen: NativeUInt): Integer; cdecl;
  TEVP_MAC_final = function(ctx: PEVP_MAC_CTX; out_: PByte; var outl: NativeUInt; outsize: NativeUInt): Integer; cdecl;
  TEVP_MAC_finalXOF = function(ctx: PEVP_MAC_CTX; out_: PByte; outsize: NativeUInt): Integer; cdecl;
  
  // KDF functions
  TEVP_KDF_fetch = function(libctx: POSSL_LIB_CTX; const algorithm: PAnsiChar; const properties: PAnsiChar): PEVP_KDF; cdecl;
  TEVP_KDF_up_ref = function(kdf: PEVP_KDF): Integer; cdecl;
  TEVP_KDF_free = procedure(kdf: PEVP_KDF); cdecl;
  TEVP_KDF_CTX_new = function(kdf: PEVP_KDF): PEVP_KDF_CTX; cdecl;
  TEVP_KDF_CTX_free = procedure(ctx: PEVP_KDF_CTX); cdecl;
  TEVP_KDF_CTX_dup = function(const src: PEVP_KDF_CTX): PEVP_KDF_CTX; cdecl;
  TEVP_KDF_CTX_get_kdf = function(ctx: PEVP_KDF_CTX): PEVP_KDF; cdecl;
  TEVP_KDF_CTX_reset = procedure(ctx: PEVP_KDF_CTX); cdecl;
  TEVP_KDF_derive = function(ctx: PEVP_KDF_CTX; key: PByte; keylen: NativeUInt; const params: POSSL_PARAM): Integer; cdecl;
  
  // RAND functions
  TEVP_RAND_fetch = function(libctx: POSSL_LIB_CTX; const algorithm: PAnsiChar; const properties: PAnsiChar): PEVP_RAND; cdecl;
  TEVP_RAND_up_ref = function(rand: PEVP_RAND): Integer; cdecl;
  TEVP_RAND_free = procedure(rand: PEVP_RAND); cdecl;
  TEVP_RAND_CTX_new = function(rand: PEVP_RAND; parent: PEVP_RAND_CTX): PEVP_RAND_CTX; cdecl;
  TEVP_RAND_CTX_free = procedure(ctx: PEVP_RAND_CTX); cdecl;
  TEVP_RAND_CTX_get0_rand = function(ctx: PEVP_RAND_CTX): PEVP_RAND; cdecl;
  TEVP_RAND_instantiate = function(ctx: PEVP_RAND_CTX; strength: Cardinal; prediction_resistance: Integer;
                                  const addin: PByte; addin_len: NativeUInt; const params: POSSL_PARAM): Integer; cdecl;
  TEVP_RAND_uninstantiate = function(ctx: PEVP_RAND_CTX): Integer; cdecl;
  TEVP_RAND_generate = function(ctx: PEVP_RAND_CTX; out_: PByte; outlen: NativeUInt; strength: Cardinal;
                                prediction_resistance: Integer; const addin: PByte; addin_len: NativeUInt): Integer; cdecl;
  TEVP_RAND_reseed = function(ctx: PEVP_RAND_CTX; prediction_resistance: Integer; 
                              const ent: PByte; ent_len: NativeUInt; const addin: PByte; addin_len: NativeUInt): Integer; cdecl;
  TEVP_RAND_nonce = function(ctx: PEVP_RAND_CTX; out_: PByte; var outlen: NativeUInt): Integer; cdecl;
  TEVP_RAND_enable_locking = function(ctx: PEVP_RAND_CTX): Integer; cdecl;
  TEVP_RAND_verify_zeroization = function(ctx: PEVP_RAND_CTX): Integer; cdecl;
  
  // Signing/Verification functions
  TEVP_SignInit = function(ctx: PEVP_MD_CTX; const type_: PEVP_MD): Integer; cdecl;
  TEVP_SignInit_ex = function(ctx: PEVP_MD_CTX; const type_: PEVP_MD; impl: PENGINE): Integer; cdecl;
  TEVP_SignUpdate = function(ctx: PEVP_MD_CTX; const d: Pointer; cnt: Cardinal): Integer; cdecl;
  TEVP_SignFinal = function(ctx: PEVP_MD_CTX; md: PByte; var s: Cardinal; pkey: PEVP_PKEY): Integer; cdecl;
  
  TEVP_VerifyInit = function(ctx: PEVP_MD_CTX; const type_: PEVP_MD): Integer; cdecl;
  TEVP_VerifyInit_ex = function(ctx: PEVP_MD_CTX; const type_: PEVP_MD; impl: PENGINE): Integer; cdecl;
  TEVP_VerifyUpdate = function(ctx: PEVP_MD_CTX; const d: Pointer; cnt: Cardinal): Integer; cdecl;
  TEVP_VerifyFinal = function(ctx: PEVP_MD_CTX; const sigbuf: PByte; siglen: Cardinal; pkey: PEVP_PKEY): Integer; cdecl;
  
  TEVP_DigestSignInit = function(ctx: PEVP_MD_CTX; pctx: PPEVP_PKEY_CTX; const type_: PEVP_MD; e: PENGINE; pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_DigestSignUpdate = function(ctx: PEVP_MD_CTX; const data: Pointer; dsize: NativeUInt): Integer; cdecl;
  TEVP_DigestSignFinal = function(ctx: PEVP_MD_CTX; sigret: PByte; var siglen: NativeUInt): Integer; cdecl;
  TEVP_DigestSign = function(ctx: PEVP_MD_CTX; sigret: PByte; var siglen: NativeUInt; 
                              const tbs: PByte; tbslen: NativeUInt): Integer; cdecl;
  
  TEVP_DigestVerifyInit = function(ctx: PEVP_MD_CTX; pctx: PPEVP_PKEY_CTX; const type_: PEVP_MD; e: PENGINE; pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_DigestVerifyUpdate = function(ctx: PEVP_MD_CTX; const data: Pointer; dsize: NativeUInt): Integer; cdecl;
  TEVP_DigestVerifyFinal = function(ctx: PEVP_MD_CTX; const sig: PByte; siglen: NativeUInt): Integer; cdecl;
  TEVP_DigestVerify = function(ctx: PEVP_MD_CTX; const sigret: PByte; siglen: NativeUInt; 
                                const tbs: PByte; tbslen: NativeUInt): Integer; cdecl;
  
  // Encode/Decode functions
  TEVP_EncodeInit = procedure(ctx: PEVP_ENCODE_CTX); cdecl;
  TEVP_EncodeUpdate = function(ctx: PEVP_ENCODE_CTX; out_: PByte; var outl: Integer; 
                              const in_: PByte; inl: Integer): Integer; cdecl;
  TEVP_EncodeFinal = procedure(ctx: PEVP_ENCODE_CTX; out_: PByte; var outl: Integer); cdecl;
  TEVP_EncodeBlock = function(t: PByte; const f: PByte; n: Integer): Integer; cdecl;
  
  TEVP_DecodeInit = procedure(ctx: PEVP_ENCODE_CTX); cdecl;
  TEVP_DecodeUpdate = function(ctx: PEVP_ENCODE_CTX; out_: PByte; var outl: Integer; 
                              const in_: PByte; inl: Integer): Integer; cdecl;
  TEVP_DecodeFinal = function(ctx: PEVP_ENCODE_CTX; out_: PByte; var outl: Integer): Integer; cdecl;
  TEVP_DecodeBlock = function(t: PByte; const f: PByte; n: Integer): Integer; cdecl;
  
  TEVP_ENCODE_CTX_new = function: PEVP_ENCODE_CTX; cdecl;
  TEVP_ENCODE_CTX_free = procedure(ctx: PEVP_ENCODE_CTX); cdecl;
  TEVP_ENCODE_CTX_copy = function(dctx: PEVP_ENCODE_CTX; const sctx: PEVP_ENCODE_CTX): Integer; cdecl;
  TEVP_ENCODE_CTX_num = function(ctx: PEVP_ENCODE_CTX): Integer; cdecl;
  
  // OSSL_PARAM functions
  TOSSL_PARAM_construct_int = function(key: PAnsiChar; buf: PInteger): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_uint = function(key: PAnsiChar; buf: PCardinal): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_long = function(key: PAnsiChar; buf: PLongInt): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_ulong = function(key: PAnsiChar; buf: PLongWord): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_int32 = function(key: PAnsiChar; buf: PInt32): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_uint32 = function(key: PAnsiChar; buf: PUInt32): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_int64 = function(key: PAnsiChar; buf: PInt64): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_uint64 = function(key: PAnsiChar; buf: PUInt64): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_size_t = function(key: PAnsiChar; buf: PNativeUInt): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_time_t = function(key: PAnsiChar; buf: PInt64): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_BN = function(key: PAnsiChar; buf: PByte; bsize: NativeUInt): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_double = function(key: PAnsiChar; buf: PDouble): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_utf8_string = function(key: PAnsiChar; buf: PAnsiChar; bsize: NativeUInt): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_utf8_ptr = function(key: PAnsiChar; var buf: PAnsiChar; bsize: NativeUInt): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_octet_string = function(key: PAnsiChar; buf: Pointer; bsize: NativeUInt): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_octet_ptr = function(key: PAnsiChar; var buf: Pointer; bsize: NativeUInt): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_end = function: OSSL_PARAM; cdecl;
  
  TOSSL_PARAM_get_int = function(const p: POSSL_PARAM; val: PInteger): Integer; cdecl;
  TOSSL_PARAM_get_uint = function(const p: POSSL_PARAM; val: PCardinal): Integer; cdecl;
  TOSSL_PARAM_get_long = function(const p: POSSL_PARAM; val: PLongInt): Integer; cdecl;
  TOSSL_PARAM_get_ulong = function(const p: POSSL_PARAM; val: PLongWord): Integer; cdecl;
  TOSSL_PARAM_get_int32 = function(const p: POSSL_PARAM; val: PInt32): Integer; cdecl;
  TOSSL_PARAM_get_uint32 = function(const p: POSSL_PARAM; val: PUInt32): Integer; cdecl;
  TOSSL_PARAM_get_int64 = function(const p: POSSL_PARAM; val: PInt64): Integer; cdecl;
  TOSSL_PARAM_get_uint64 = function(const p: POSSL_PARAM; val: PUInt64): Integer; cdecl;
  TOSSL_PARAM_get_size_t = function(const p: POSSL_PARAM; val: PNativeUInt): Integer; cdecl;
  TOSSL_PARAM_get_time_t = function(const p: POSSL_PARAM; val: PInt64): Integer; cdecl;
  TOSSL_PARAM_get_BN = function(const p: POSSL_PARAM; var val: PBIGNUM): Integer; cdecl;
  TOSSL_PARAM_get_double = function(const p: POSSL_PARAM; val: PDouble): Integer; cdecl;
  TOSSL_PARAM_get_utf8_string = function(const p: POSSL_PARAM; var val: PAnsiChar; max_len: NativeUInt): Integer; cdecl;
  TOSSL_PARAM_get_octet_string = function(const p: POSSL_PARAM; var val: Pointer; max_len: NativeUInt; var used_len: NativeUInt): Integer; cdecl;
  TOSSL_PARAM_get_utf8_ptr = function(const p: POSSL_PARAM; var val: PAnsiChar): Integer; cdecl;
  TOSSL_PARAM_get_octet_ptr = function(const p: POSSL_PARAM; var val: Pointer; var used_len: NativeUInt): Integer; cdecl;
  
  TOSSL_PARAM_set_int = function(p: POSSL_PARAM; val: Integer): Integer; cdecl;
  TOSSL_PARAM_set_uint = function(p: POSSL_PARAM; val: Cardinal): Integer; cdecl;
  TOSSL_PARAM_set_long = function(p: POSSL_PARAM; val: LongInt): Integer; cdecl;
  TOSSL_PARAM_set_ulong = function(p: POSSL_PARAM; val: LongWord): Integer; cdecl;
  TOSSL_PARAM_set_int32 = function(p: POSSL_PARAM; val: Int32): Integer; cdecl;
  TOSSL_PARAM_set_uint32 = function(p: POSSL_PARAM; val: UInt32): Integer; cdecl;
  TOSSL_PARAM_set_int64 = function(p: POSSL_PARAM; val: Int64): Integer; cdecl;
  TOSSL_PARAM_set_uint64 = function(p: POSSL_PARAM; val: UInt64): Integer; cdecl;
  TOSSL_PARAM_set_size_t = function(p: POSSL_PARAM; val: NativeUInt): Integer; cdecl;
  TOSSL_PARAM_set_time_t = function(p: POSSL_PARAM; val: Int64): Integer; cdecl;
  TOSSL_PARAM_set_BN = function(p: POSSL_PARAM; const val: PBIGNUM): Integer; cdecl;
  TOSSL_PARAM_set_double = function(p: POSSL_PARAM; val: Double): Integer; cdecl;
  TOSSL_PARAM_set_utf8_string = function(p: POSSL_PARAM; const val: PAnsiChar): Integer; cdecl;
  TOSSL_PARAM_set_octet_string = function(p: POSSL_PARAM; const val: Pointer; vallen: NativeUInt): Integer; cdecl;
  TOSSL_PARAM_set_utf8_ptr = function(p: POSSL_PARAM; const val: PAnsiChar): Integer; cdecl;
  TOSSL_PARAM_set_octet_ptr = function(p: POSSL_PARAM; const val: Pointer; used_len: NativeUInt): Integer; cdecl;
  
  TOSSL_PARAM_BLD_new = function: POSSL_PARAM_BLD; cdecl;
  TOSSL_PARAM_BLD_free = procedure(bld: POSSL_PARAM_BLD); cdecl;
  TOSSL_PARAM_BLD_to_param = function(bld: POSSL_PARAM_BLD): POSSL_PARAM; cdecl;
  
  TOSSL_PARAM_BLD_push_int = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; num: Integer): Integer; cdecl;
  TOSSL_PARAM_BLD_push_uint = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; num: Cardinal): Integer; cdecl;
  TOSSL_PARAM_BLD_push_long = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; num: LongInt): Integer; cdecl;
  TOSSL_PARAM_BLD_push_ulong = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; num: LongWord): Integer; cdecl;
  TOSSL_PARAM_BLD_push_int32 = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; num: Int32): Integer; cdecl;
  TOSSL_PARAM_BLD_push_uint32 = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; num: UInt32): Integer; cdecl;
  TOSSL_PARAM_BLD_push_int64 = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; num: Int64): Integer; cdecl;
  TOSSL_PARAM_BLD_push_uint64 = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; num: UInt64): Integer; cdecl;
  TOSSL_PARAM_BLD_push_size_t = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; num: NativeUInt): Integer; cdecl;
  TOSSL_PARAM_BLD_push_time_t = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; num: Int64): Integer; cdecl;
  TOSSL_PARAM_BLD_push_double = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; num: Double): Integer; cdecl;
  TOSSL_PARAM_BLD_push_BN = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; const bn: PBIGNUM): Integer; cdecl;
  TOSSL_PARAM_BLD_push_BN_pad = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; const bn: PBIGNUM; sz: NativeUInt): Integer; cdecl;
  TOSSL_PARAM_BLD_push_utf8_string = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; const buf: PAnsiChar; bsize: NativeUInt): Integer; cdecl;
  TOSSL_PARAM_BLD_push_utf8_ptr = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; buf: PAnsiChar; bsize: NativeUInt): Integer; cdecl;
  TOSSL_PARAM_BLD_push_octet_string = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; const buf: Pointer; bsize: NativeUInt): Integer; cdecl;
  TOSSL_PARAM_BLD_push_octet_ptr = function(bld: POSSL_PARAM_BLD; const key: PAnsiChar; buf: Pointer; bsize: NativeUInt): Integer; cdecl;

var
  // MD Context functions
  EVP_MD_CTX_new: TEVP_MD_CTX_new = nil;
  EVP_MD_CTX_free: TEVP_MD_CTX_free = nil;
  EVP_MD_CTX_reset: TEVP_MD_CTX_reset = nil;
  
  // Digest functions
  EVP_DigestInit_ex: TEVP_DigestInit_ex = nil;
  EVP_DigestUpdate: TEVP_DigestUpdate = nil;
  EVP_DigestFinal_ex: TEVP_DigestFinal_ex = nil;
  EVP_DigestFinalXOF: TEVP_DigestFinalXOF = nil;
  EVP_Digest: TEVP_Digest = nil;
  
  // MD info functions
  EVP_MD_get_size: TEVP_MD_get_size = nil;
  EVP_MD_get_block_size: TEVP_MD_get_block_size = nil;
  
  // MD algorithms
  EVP_md5: TEVP_md5 = nil;
  EVP_sha1: TEVP_sha1 = nil;
  EVP_sha256: TEVP_sha256 = nil;
  EVP_sha384: TEVP_sha384 = nil;
  EVP_sha512: TEVP_sha512 = nil;
  EVP_blake2b512: TEVP_blake2b512 = nil;
  EVP_blake2s256: TEVP_blake2s256 = nil;
  EVP_get_digestbyname: TEVP_get_digestbyname = nil;
  EVP_get_digestbynid: TEVP_get_digestbynid = nil;
  
  // OpenSSL 3.x EVP_MD fetch API
  EVP_MD_fetch: TEVP_MD_fetch = nil;
  EVP_MD_free: TEVP_MD_free = nil;
  
  // Cipher Context functions
  EVP_CIPHER_CTX_new: TEVP_CIPHER_CTX_new = nil;
  EVP_CIPHER_CTX_free: TEVP_CIPHER_CTX_free = nil;
  EVP_CIPHER_CTX_reset: TEVP_CIPHER_CTX_reset = nil;
  
  // Encryption functions
  EVP_EncryptInit_ex: TEVP_EncryptInit_ex = nil;
  EVP_EncryptUpdate: TEVP_EncryptUpdate = nil;
  EVP_EncryptFinal_ex: TEVP_EncryptFinal_ex = nil;
  
  // Generic Cipher functions
  EVP_CipherInit_ex: TEVP_CipherInit_ex = nil;
  EVP_CipherUpdate: TEVP_CipherUpdate = nil;
  EVP_CipherFinal_ex: TEVP_CipherFinal_ex = nil;
  
  // Decryption functions
  EVP_DecryptInit_ex: TEVP_DecryptInit_ex = nil;
  EVP_DecryptUpdate: TEVP_DecryptUpdate = nil;
  EVP_DecryptFinal_ex: TEVP_DecryptFinal_ex = nil;
  
  // Cipher info functions
  EVP_CIPHER_get_key_length: TEVP_CIPHER_get_key_length = nil;
  EVP_CIPHER_get_iv_length: TEVP_CIPHER_get_iv_length = nil;
  EVP_CIPHER_get_block_size: TEVP_CIPHER_get_block_size = nil;
  
  // Cipher control functions
  EVP_CIPHER_CTX_ctrl: TEVP_CIPHER_CTX_ctrl = nil;
  EVP_CIPHER_CTX_set_key_length: TEVP_CIPHER_CTX_set_key_length = nil;
  EVP_CIPHER_CTX_set_padding: TEVP_CIPHER_CTX_set_padding = nil;
  
  // Cipher algorithms
  EVP_aes_128_cbc: TEVP_aes_128_cbc = nil;
  EVP_aes_128_gcm: TEVP_aes_128_gcm = nil;
  EVP_aes_192_gcm: TEVP_aes_192_gcm = nil;
  EVP_aes_256_cbc: TEVP_aes_256_cbc = nil;
  EVP_aes_256_gcm: TEVP_aes_256_gcm = nil;
  EVP_aes_128_ccm: TEVP_aes_128_ccm = nil;
  EVP_aes_192_ccm: TEVP_aes_192_ccm = nil;
  EVP_aes_256_ccm: TEVP_aes_256_ccm = nil;
  EVP_aes_128_xts: TEVP_aes_128_xts = nil;
  EVP_aes_256_xts: TEVP_aes_256_xts = nil;
  EVP_aes_128_ocb: TEVP_aes_128_ocb = nil;
  EVP_aes_192_ocb: TEVP_aes_192_ocb = nil;
  EVP_aes_256_ocb: TEVP_aes_256_ocb = nil;
  EVP_chacha20: TEVP_chacha20 = nil;
  EVP_chacha20_poly1305: TEVP_chacha20_poly1305 = nil;
  
  // Camellia cipher algorithms
  EVP_camellia_128_ecb: TEVP_camellia_128_ecb = nil;
  EVP_camellia_128_cbc: TEVP_camellia_128_cbc = nil;
  EVP_camellia_256_ecb: TEVP_camellia_256_ecb = nil;
  EVP_camellia_256_cbc: TEVP_camellia_256_cbc = nil;
  
  EVP_get_cipherbyname: TEVP_get_cipherbyname = nil;

  // OpenSSL 3.x EVP_CIPHER fetch API
  EVP_CIPHER_fetch: TEVP_CIPHER_fetch = nil;
  EVP_CIPHER_free: TEVP_CIPHER_free = nil;

  // PKEY functions
  EVP_PKEY_new: TEVP_PKEY_new = nil;
  EVP_PKEY_new_mac_key: TEVP_PKEY_new_mac_key = nil;
  EVP_PKEY_free: TEVP_PKEY_free = nil;
  EVP_PKEY_up_ref: TEVP_PKEY_up_ref = nil;
  EVP_PKEY_assign: TEVP_PKEY_assign = nil;
  EVP_PKEY_set1_RSA: TEVP_PKEY_set1_RSA = nil;
  EVP_PKEY_set1_EC_KEY: TEVP_PKEY_set1_EC_KEY = nil;
  EVP_PKEY_get_id: TEVP_PKEY_get_id = nil;
  EVP_PKEY_id: TEVP_PKEY_get_id = nil;  // Alias for compatibility
  EVP_PKEY_get_bits: TEVP_PKEY_get_bits = nil;
  EVP_PKEY_get_size: TEVP_PKEY_get_size = nil;
  EVP_PKEY_get_raw_private_key: TEVP_PKEY_get_raw_private_key = nil;
  EVP_PKEY_get_raw_public_key: TEVP_PKEY_get_raw_public_key = nil;
  
  // PKEY encoding/decoding functions
  i2d_PUBKEY: Ti2d_PUBKEY = nil;
  i2d_PUBKEY_bio: Ti2d_PUBKEY_bio = nil;
  i2d_PUBKEY_fp: Ti2d_PUBKEY_fp = nil;
  d2i_PUBKEY: Td2i_PUBKEY = nil;
  d2i_PUBKEY_bio: Td2i_PUBKEY_bio = nil;
  d2i_PUBKEY_fp: Td2i_PUBKEY_fp = nil;
  
  // PKEY context functions
  EVP_PKEY_CTX_new: TEVP_PKEY_CTX_new = nil;
  EVP_PKEY_CTX_new_id: TEVP_PKEY_CTX_new_id = nil;
  EVP_PKEY_CTX_free: TEVP_PKEY_CTX_free = nil;
  EVP_PKEY_CTX_ctrl: TEVP_PKEY_CTX_ctrl = nil;
  
  // PKEY key generation
  EVP_PKEY_keygen_init: TEVP_PKEY_keygen_init = nil;
  EVP_PKEY_keygen: TEVP_PKEY_keygen = nil;
  
  // PKEY signing
  EVP_PKEY_sign_init: TEVP_PKEY_sign_init = nil;
  EVP_PKEY_sign: TEVP_PKEY_sign = nil;
  EVP_PKEY_verify_init: TEVP_PKEY_verify_init = nil;
  EVP_PKEY_verify: TEVP_PKEY_verify = nil;

  // PKEY encryption/decryption
  EVP_PKEY_encrypt_init: TEVP_PKEY_encrypt_init = nil;
  EVP_PKEY_encrypt: TEVP_PKEY_encrypt = nil;
  EVP_PKEY_decrypt_init: TEVP_PKEY_decrypt_init = nil;
  EVP_PKEY_decrypt: TEVP_PKEY_decrypt = nil;

  // Digest signing/verification
  EVP_DigestSignInit: TEVP_DigestSignInit = nil;
  EVP_DigestSignUpdate: TEVP_DigestSignUpdate = nil;
  EVP_DigestSignFinal: TEVP_DigestSignFinal = nil;
  EVP_DigestVerifyInit: TEVP_DigestVerifyInit = nil;
  EVP_DigestVerifyUpdate: TEVP_DigestVerifyUpdate = nil;
  EVP_DigestVerifyFinal: TEVP_DigestVerifyFinal = nil;

// Public load/unload functions
function LoadEVP(ALibHandle: THandle): Boolean;
procedure UnloadEVP;

// High-level helper functions
function EVP_MD_size(const md: PEVP_MD): Integer;
function EVP_MD_block_size(const md: PEVP_MD): Integer;
function EVP_CIPHER_key_length(const cipher: PEVP_CIPHER): Integer;
function EVP_CIPHER_iv_length(const cipher: PEVP_CIPHER): Integer;
function EVP_CIPHER_block_size(const cipher: PEVP_CIPHER): Integer;

// RSA PKEY context helper functions (OpenSSL macro equivalents)
function EVP_PKEY_CTX_set_rsa_keygen_bits(ctx: PEVP_PKEY_CTX; bits: Integer): Integer;
function EVP_PKEY_CTX_set_rsa_padding(ctx: PEVP_PKEY_CTX; pad: Integer): Integer;

implementation

uses nextpas.core.tls.openssl.api;

// Runtime storage avoids platform-specific regressions in const procvar binding tables.
var
  EVP_BINDINGS: array[0..98] of TFunctionBinding = (
    // MD Context functions
    (Name: 'EVP_MD_CTX_new'; FuncPtr: @EVP_MD_CTX_new; Required: True),
    (Name: 'EVP_MD_CTX_free'; FuncPtr: @EVP_MD_CTX_free; Required: True),
    (Name: 'EVP_MD_CTX_reset'; FuncPtr: @EVP_MD_CTX_reset; Required: False),
    // Digest functions
    (Name: 'EVP_DigestInit_ex'; FuncPtr: @EVP_DigestInit_ex; Required: True),
    (Name: 'EVP_DigestUpdate'; FuncPtr: @EVP_DigestUpdate; Required: True),
    (Name: 'EVP_DigestFinal_ex'; FuncPtr: @EVP_DigestFinal_ex; Required: True),
    (Name: 'EVP_DigestFinalXOF'; FuncPtr: @EVP_DigestFinalXOF; Required: False),
    (Name: 'EVP_Digest'; FuncPtr: @EVP_Digest; Required: False),
    // MD info functions
    (Name: 'EVP_MD_get_size'; FuncPtr: @EVP_MD_get_size; Required: False),
    (Name: 'EVP_MD_get_block_size'; FuncPtr: @EVP_MD_get_block_size; Required: False),
    // MD algorithms
    (Name: 'EVP_md5'; FuncPtr: @EVP_md5; Required: False),
    (Name: 'EVP_sha1'; FuncPtr: @EVP_sha1; Required: False),
    (Name: 'EVP_sha256'; FuncPtr: @EVP_sha256; Required: False),
    (Name: 'EVP_sha384'; FuncPtr: @EVP_sha384; Required: False),
    (Name: 'EVP_sha512'; FuncPtr: @EVP_sha512; Required: False),
    (Name: 'EVP_blake2b512'; FuncPtr: @EVP_blake2b512; Required: False),
    (Name: 'EVP_blake2s256'; FuncPtr: @EVP_blake2s256; Required: False),
    (Name: 'EVP_get_digestbyname'; FuncPtr: @EVP_get_digestbyname; Required: False),
    (Name: 'EVP_get_digestbynid'; FuncPtr: @EVP_get_digestbynid; Required: False),
    // OpenSSL 3.x EVP_MD fetch API
    (Name: 'EVP_MD_fetch'; FuncPtr: @EVP_MD_fetch; Required: False),
    (Name: 'EVP_MD_free'; FuncPtr: @EVP_MD_free; Required: False),
    // Cipher Context functions
    (Name: 'EVP_CIPHER_CTX_new'; FuncPtr: @EVP_CIPHER_CTX_new; Required: True),
    (Name: 'EVP_CIPHER_CTX_free'; FuncPtr: @EVP_CIPHER_CTX_free; Required: True),
    (Name: 'EVP_CIPHER_CTX_reset'; FuncPtr: @EVP_CIPHER_CTX_reset; Required: False),
    // Encryption functions
    (Name: 'EVP_EncryptInit_ex'; FuncPtr: @EVP_EncryptInit_ex; Required: False),
    (Name: 'EVP_EncryptUpdate'; FuncPtr: @EVP_EncryptUpdate; Required: False),
    (Name: 'EVP_EncryptFinal_ex'; FuncPtr: @EVP_EncryptFinal_ex; Required: False),
    // Generic Cipher functions
    (Name: 'EVP_CipherInit_ex'; FuncPtr: @EVP_CipherInit_ex; Required: False),
    (Name: 'EVP_CipherUpdate'; FuncPtr: @EVP_CipherUpdate; Required: False),
    (Name: 'EVP_CipherFinal_ex'; FuncPtr: @EVP_CipherFinal_ex; Required: False),
    // Decryption functions
    (Name: 'EVP_DecryptInit_ex'; FuncPtr: @EVP_DecryptInit_ex; Required: False),
    (Name: 'EVP_DecryptUpdate'; FuncPtr: @EVP_DecryptUpdate; Required: False),
    (Name: 'EVP_DecryptFinal_ex'; FuncPtr: @EVP_DecryptFinal_ex; Required: False),
    // Cipher info functions
    (Name: 'EVP_CIPHER_get_key_length'; FuncPtr: @EVP_CIPHER_get_key_length; Required: False),
    (Name: 'EVP_CIPHER_get_iv_length'; FuncPtr: @EVP_CIPHER_get_iv_length; Required: False),
    (Name: 'EVP_CIPHER_get_block_size'; FuncPtr: @EVP_CIPHER_get_block_size; Required: False),
    // Cipher control functions
    (Name: 'EVP_CIPHER_CTX_ctrl'; FuncPtr: @EVP_CIPHER_CTX_ctrl; Required: False),
    (Name: 'EVP_CIPHER_CTX_set_key_length'; FuncPtr: @EVP_CIPHER_CTX_set_key_length; Required: False),
    (Name: 'EVP_CIPHER_CTX_set_padding'; FuncPtr: @EVP_CIPHER_CTX_set_padding; Required: False),
    // Cipher algorithms - AES
    (Name: 'EVP_aes_128_cbc'; FuncPtr: @EVP_aes_128_cbc; Required: False),
    (Name: 'EVP_aes_128_gcm'; FuncPtr: @EVP_aes_128_gcm; Required: False),
    (Name: 'EVP_aes_192_gcm'; FuncPtr: @EVP_aes_192_gcm; Required: False),
    (Name: 'EVP_aes_256_cbc'; FuncPtr: @EVP_aes_256_cbc; Required: False),
    (Name: 'EVP_aes_256_gcm'; FuncPtr: @EVP_aes_256_gcm; Required: False),
    (Name: 'EVP_aes_128_ccm'; FuncPtr: @EVP_aes_128_ccm; Required: False),
    (Name: 'EVP_aes_192_ccm'; FuncPtr: @EVP_aes_192_ccm; Required: False),
    (Name: 'EVP_aes_256_ccm'; FuncPtr: @EVP_aes_256_ccm; Required: False),
    (Name: 'EVP_aes_128_xts'; FuncPtr: @EVP_aes_128_xts; Required: False),
    (Name: 'EVP_aes_256_xts'; FuncPtr: @EVP_aes_256_xts; Required: False),
    (Name: 'EVP_aes_128_ocb'; FuncPtr: @EVP_aes_128_ocb; Required: False),
    (Name: 'EVP_aes_192_ocb'; FuncPtr: @EVP_aes_192_ocb; Required: False),
    (Name: 'EVP_aes_256_ocb'; FuncPtr: @EVP_aes_256_ocb; Required: False),
    // Cipher algorithms - ChaCha
    (Name: 'EVP_chacha20'; FuncPtr: @EVP_chacha20; Required: False),
    (Name: 'EVP_chacha20_poly1305'; FuncPtr: @EVP_chacha20_poly1305; Required: False),
    // Cipher algorithms - Camellia
    (Name: 'EVP_camellia_128_ecb'; FuncPtr: @EVP_camellia_128_ecb; Required: False),
    (Name: 'EVP_camellia_128_cbc'; FuncPtr: @EVP_camellia_128_cbc; Required: False),
    (Name: 'EVP_camellia_256_ecb'; FuncPtr: @EVP_camellia_256_ecb; Required: False),
    (Name: 'EVP_camellia_256_cbc'; FuncPtr: @EVP_camellia_256_cbc; Required: False),
    (Name: 'EVP_get_cipherbyname'; FuncPtr: @EVP_get_cipherbyname; Required: False),
    // OpenSSL 3.x EVP_CIPHER fetch API
    (Name: 'EVP_CIPHER_fetch'; FuncPtr: @EVP_CIPHER_fetch; Required: False),
    (Name: 'EVP_CIPHER_free'; FuncPtr: @EVP_CIPHER_free; Required: False),
    // PKEY functions
    (Name: 'EVP_PKEY_new'; FuncPtr: @EVP_PKEY_new; Required: False),
    (Name: 'EVP_PKEY_new_mac_key'; FuncPtr: @EVP_PKEY_new_mac_key; Required: False),
    (Name: 'EVP_PKEY_free'; FuncPtr: @EVP_PKEY_free; Required: False),
    (Name: 'EVP_PKEY_up_ref'; FuncPtr: @EVP_PKEY_up_ref; Required: False),
    (Name: 'EVP_PKEY_assign'; FuncPtr: @EVP_PKEY_assign; Required: False),
    (Name: 'EVP_PKEY_set1_RSA'; FuncPtr: @EVP_PKEY_set1_RSA; Required: False),
    (Name: 'EVP_PKEY_set1_EC_KEY'; FuncPtr: @EVP_PKEY_set1_EC_KEY; Required: False),
    (Name: 'EVP_PKEY_get_id'; FuncPtr: @EVP_PKEY_get_id; Required: False),
    (Name: 'EVP_PKEY_get_bits'; FuncPtr: @EVP_PKEY_get_bits; Required: False),
    (Name: 'EVP_PKEY_get_size'; FuncPtr: @EVP_PKEY_get_size; Required: False),
    (Name: 'EVP_PKEY_get_raw_private_key'; FuncPtr: @EVP_PKEY_get_raw_private_key; Required: False),
    (Name: 'EVP_PKEY_get_raw_public_key'; FuncPtr: @EVP_PKEY_get_raw_public_key; Required: False),
    // PKEY encoding/decoding functions
    (Name: 'i2d_PUBKEY'; FuncPtr: @i2d_PUBKEY; Required: False),
    (Name: 'i2d_PUBKEY_bio'; FuncPtr: @i2d_PUBKEY_bio; Required: False),
    (Name: 'i2d_PUBKEY_fp'; FuncPtr: @i2d_PUBKEY_fp; Required: False),
    (Name: 'd2i_PUBKEY'; FuncPtr: @d2i_PUBKEY; Required: False),
    (Name: 'd2i_PUBKEY_bio'; FuncPtr: @d2i_PUBKEY_bio; Required: False),
    (Name: 'd2i_PUBKEY_fp'; FuncPtr: @d2i_PUBKEY_fp; Required: False),
    // PKEY context functions
    (Name: 'EVP_PKEY_CTX_new'; FuncPtr: @EVP_PKEY_CTX_new; Required: False),
    (Name: 'EVP_PKEY_CTX_new_id'; FuncPtr: @EVP_PKEY_CTX_new_id; Required: False),
    (Name: 'EVP_PKEY_CTX_free'; FuncPtr: @EVP_PKEY_CTX_free; Required: False),
    (Name: 'EVP_PKEY_CTX_ctrl'; FuncPtr: @EVP_PKEY_CTX_ctrl; Required: False),
    // PKEY key generation
    (Name: 'EVP_PKEY_keygen_init'; FuncPtr: @EVP_PKEY_keygen_init; Required: False),
    (Name: 'EVP_PKEY_keygen'; FuncPtr: @EVP_PKEY_keygen; Required: False),
    // PKEY signing
    (Name: 'EVP_PKEY_sign_init'; FuncPtr: @EVP_PKEY_sign_init; Required: False),
    (Name: 'EVP_PKEY_sign'; FuncPtr: @EVP_PKEY_sign; Required: False),
    (Name: 'EVP_PKEY_verify_init'; FuncPtr: @EVP_PKEY_verify_init; Required: False),
    (Name: 'EVP_PKEY_verify'; FuncPtr: @EVP_PKEY_verify; Required: False),
    // PKEY encryption/decryption
    (Name: 'EVP_PKEY_encrypt_init'; FuncPtr: @EVP_PKEY_encrypt_init; Required: False),
    (Name: 'EVP_PKEY_encrypt'; FuncPtr: @EVP_PKEY_encrypt; Required: False),
    (Name: 'EVP_PKEY_decrypt_init'; FuncPtr: @EVP_PKEY_decrypt_init; Required: False),
    (Name: 'EVP_PKEY_decrypt'; FuncPtr: @EVP_PKEY_decrypt; Required: False),
    // Digest signing/verification
    (Name: 'EVP_DigestSignInit'; FuncPtr: @EVP_DigestSignInit; Required: False),
    (Name: 'EVP_DigestSignUpdate'; FuncPtr: @EVP_DigestSignUpdate; Required: False),
    (Name: 'EVP_DigestSignFinal'; FuncPtr: @EVP_DigestSignFinal; Required: False),
    (Name: 'EVP_DigestVerifyInit'; FuncPtr: @EVP_DigestVerifyInit; Required: False),
    (Name: 'EVP_DigestVerifyUpdate'; FuncPtr: @EVP_DigestVerifyUpdate; Required: False),
    (Name: 'EVP_DigestVerifyFinal'; FuncPtr: @EVP_DigestVerifyFinal; Required: False)
  );

function LoadEVP(ALibHandle: THandle): Boolean;
begin
  Result := False;

  if ALibHandle = 0 then Exit;
  if TOpenSSLLoader.IsModuleLoaded(osmEVP) then Exit(True);

  // Batch load all EVP functions
  TOpenSSLLoader.LoadFunctions(ALibHandle, EVP_BINDINGS);

  // Set EVP_PKEY_id alias
  EVP_PKEY_id := EVP_PKEY_get_id;

  // Fallback for GCM ciphers using EVP_CIPHER_fetch if direct load fails
  if not Assigned(EVP_aes_128_gcm) and Assigned(EVP_CIPHER_fetch) then
    EVP_aes_128_gcm := TEVP_aes_128_gcm(EVP_CIPHER_fetch(nil, 'AES-128-GCM', nil));
  if not Assigned(EVP_aes_192_gcm) and Assigned(EVP_CIPHER_fetch) then
    EVP_aes_192_gcm := TEVP_aes_192_gcm(EVP_CIPHER_fetch(nil, 'AES-192-GCM', nil));
  if not Assigned(EVP_aes_256_gcm) and Assigned(EVP_CIPHER_fetch) then
    EVP_aes_256_gcm := TEVP_aes_256_gcm(EVP_CIPHER_fetch(nil, 'AES-256-GCM', nil));

  TOpenSSLLoader.SetModuleLoaded(osmEVP, Assigned(EVP_MD_CTX_new) and Assigned(EVP_CIPHER_CTX_new));
  Result := TOpenSSLLoader.IsModuleLoaded(osmEVP);
end;

procedure UnloadEVP;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmEVP) then Exit;

  // Batch clear all EVP functions
  TOpenSSLLoader.ClearFunctions(EVP_BINDINGS);

  // Clear alias
  EVP_PKEY_id := nil;

  TOpenSSLLoader.SetModuleLoaded(osmEVP, False);
end;


function EVP_MD_size(const md: PEVP_MD): Integer;
begin
  if Assigned(EVP_MD_get_size) then
    Result := EVP_MD_get_size(md)
  else
    Result := -1;
end;

function EVP_MD_block_size(const md: PEVP_MD): Integer;
begin
  if Assigned(EVP_MD_get_block_size) then
    Result := EVP_MD_get_block_size(md)
  else
    Result := -1;
end;

function EVP_CIPHER_key_length(const cipher: PEVP_CIPHER): Integer;
begin
  if Assigned(EVP_CIPHER_get_key_length) then
    Result := EVP_CIPHER_get_key_length(cipher)
  else
    Result := -1;
end;

function EVP_CIPHER_iv_length(const cipher: PEVP_CIPHER): Integer;
begin
  if Assigned(EVP_CIPHER_get_iv_length) then
    Result := EVP_CIPHER_get_iv_length(cipher)
  else
    Result := -1;
end;

function EVP_CIPHER_block_size(const cipher: PEVP_CIPHER): Integer;
begin
  if Assigned(EVP_CIPHER_get_block_size) then
    Result := EVP_CIPHER_get_block_size(cipher)
  else
    Result := -1;
end;

function EVP_PKEY_CTX_set_rsa_keygen_bits(ctx: PEVP_PKEY_CTX; bits: Integer): Integer;
begin
  // Equivalent to OpenSSL macro:
  // EVP_PKEY_CTX_ctrl(ctx, EVP_PKEY_RSA, EVP_PKEY_OP_KEYGEN, EVP_PKEY_CTRL_RSA_KEYGEN_BITS, bits, NULL)
  if Assigned(EVP_PKEY_CTX_ctrl) then
    Result := EVP_PKEY_CTX_ctrl(ctx, EVP_PKEY_RSA, EVP_PKEY_OP_KEYGEN, EVP_PKEY_CTRL_RSA_KEYGEN_BITS, bits, nil)
  else
    Result := -1;
end;

function EVP_PKEY_CTX_set_rsa_padding(ctx: PEVP_PKEY_CTX; pad: Integer): Integer;
begin
  // Equivalent to OpenSSL macro:
  // EVP_PKEY_CTX_ctrl(ctx, EVP_PKEY_RSA, -1, EVP_PKEY_CTRL_RSA_PADDING, pad, NULL)
  if Assigned(EVP_PKEY_CTX_ctrl) then
    Result := EVP_PKEY_CTX_ctrl(ctx, EVP_PKEY_RSA, -1, EVP_PKEY_CTRL_RSA_PADDING, pad, nil)
  else
    Result := -1;
end;

end.
