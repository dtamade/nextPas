unit nextpas.core.tls.openssl.api.crypto;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.tls.openssl.base;

type
  { Memory Management }
  TCRYPTO_free = procedure(ptr: Pointer; const fname: PAnsiChar; line: Integer); cdecl;
  TOPENSSL_free = procedure(ptr: Pointer); cdecl;  // Simplified version for OpenSSL 3.x
  TCRYPTO_malloc = function(num: size_t; const fname: PAnsiChar; line: Integer): Pointer; cdecl;
  TCRYPTO_realloc = function(addr: Pointer; num: size_t; const fname: PAnsiChar; line: Integer): Pointer; cdecl;
  
  { EVP Digest Functions }
  TEVP_MD_CTX_new = function: PEVP_MD_CTX; cdecl;
  TEVP_MD_CTX_free = procedure(ctx: PEVP_MD_CTX); cdecl;
  TEVP_MD_CTX_create = function: PEVP_MD_CTX; cdecl;  // Deprecated, use EVP_MD_CTX_new
  TEVP_MD_CTX_destroy = procedure(ctx: PEVP_MD_CTX); cdecl;  // Deprecated, use EVP_MD_CTX_free
  TEVP_MD_CTX_copy = function(&out: PEVP_MD_CTX; const &in: PEVP_MD_CTX): Integer; cdecl;
  TEVP_MD_CTX_copy_ex = function(&out: PEVP_MD_CTX; const &in: PEVP_MD_CTX): Integer; cdecl;
  TEVP_MD_CTX_reset = function(ctx: PEVP_MD_CTX): Integer; cdecl;
  TEVP_MD_CTX_ctrl = function(ctx: PEVP_MD_CTX; cmd: Integer; p1: Integer; p2: Pointer): Integer; cdecl;
  TEVP_MD_CTX_set_flags = procedure(ctx: PEVP_MD_CTX; flags: Integer); cdecl;
  TEVP_MD_CTX_clear_flags = procedure(ctx: PEVP_MD_CTX; flags: Integer); cdecl;
  TEVP_MD_CTX_test_flags = function(const ctx: PEVP_MD_CTX; flags: Integer): Integer; cdecl;
  
  TEVP_DigestInit = function(ctx: PEVP_MD_CTX; const &type: PEVP_MD): Integer; cdecl;
  TEVP_DigestInit_ex = function(ctx: PEVP_MD_CTX; const &type: PEVP_MD; impl: PENGINE): Integer; cdecl;
  TEVP_DigestInit_ex2 = function(ctx: PEVP_MD_CTX; const &type: PEVP_MD; const params: Pointer): Integer; cdecl;
  TEVP_DigestUpdate = function(ctx: PEVP_MD_CTX; const d: Pointer; cnt: size_t): Integer; cdecl;
  TEVP_DigestFinal = function(ctx: PEVP_MD_CTX; md: PByte; s: PCardinal): Integer; cdecl;
  TEVP_DigestFinal_ex = function(ctx: PEVP_MD_CTX; md: PByte; s: PCardinal): Integer; cdecl;
  TEVP_DigestFinalXOF = function(ctx: PEVP_MD_CTX; md: PByte; len: size_t): Integer; cdecl;
  TEVP_Digest = function(const data: Pointer; count: size_t; md: PByte; size: PCardinal; const &type: PEVP_MD; impl: PENGINE): Integer; cdecl;
  
  TEVP_MD_CTX_md = function(const ctx: PEVP_MD_CTX): PEVP_MD; cdecl;
  TEVP_MD_CTX_get0_md = function(const ctx: PEVP_MD_CTX): PEVP_MD; cdecl;
  TEVP_MD_CTX_get1_md = function(ctx: PEVP_MD_CTX): PEVP_MD; cdecl;
  TEVP_MD_CTX_get_size = function(const ctx: PEVP_MD_CTX): Integer; cdecl;
  TEVP_MD_CTX_get_block_size = function(const ctx: PEVP_MD_CTX): Integer; cdecl;
  TEVP_MD_CTX_get_type = function(const ctx: PEVP_MD_CTX): Integer; cdecl;
  TEVP_MD_CTX_get_md_data = function(const ctx: PEVP_MD_CTX): Pointer; cdecl;
  TEVP_MD_CTX_update_fn = function(ctx: PEVP_MD_CTX): Pointer; cdecl;
  TEVP_MD_CTX_set_update_fn = procedure(ctx: PEVP_MD_CTX; update: Pointer); cdecl;
  
  TEVP_MD_get_size = function(const md: PEVP_MD): Integer; cdecl;
  TEVP_MD_get_block_size = function(const md: PEVP_MD): Integer; cdecl;
  TEVP_MD_get_type = function(const md: PEVP_MD): Integer; cdecl;
  TEVP_MD_get_pkey_type = function(const md: PEVP_MD): Integer; cdecl;
  TEVP_MD_get_flags = function(const md: PEVP_MD): LongWord; cdecl;
  TEVP_MD_nid = function(const md: PEVP_MD): Integer; cdecl;
  TEVP_MD_name = function(const md: PEVP_MD): PAnsiChar; cdecl;
  TEVP_MD_get0_name = function(const md: PEVP_MD): PAnsiChar; cdecl;
  TEVP_MD_get0_description = function(const md: PEVP_MD): PAnsiChar; cdecl;
  TEVP_MD_is_a = function(const md: PEVP_MD; const name: PAnsiChar): Integer; cdecl;
  TEVP_MD_names_do_all = procedure(const md: PEVP_MD; fn: Pointer; data: Pointer); cdecl;
  TEVP_MD_get0_provider = function(const md: PEVP_MD): Pointer; cdecl;
  
  { EVP Digest Algorithms }
  TEVP_md_null = function: PEVP_MD; cdecl;
  TEVP_md2 = function: PEVP_MD; cdecl;
  TEVP_md4 = function: PEVP_MD; cdecl;
  TEVP_md5 = function: PEVP_MD; cdecl;
  TEVP_md5_sha1 = function: PEVP_MD; cdecl;
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
  TEVP_mdc2 = function: PEVP_MD; cdecl;
  TEVP_ripemd160 = function: PEVP_MD; cdecl;
  TEVP_whirlpool = function: PEVP_MD; cdecl;
  TEVP_blake2b512 = function: PEVP_MD; cdecl;
  TEVP_blake2s256 = function: PEVP_MD; cdecl;
  TEVP_sm3 = function: PEVP_MD; cdecl;
  TEVP_MD_fetch = function(ctx: Pointer; const algorithm: PAnsiChar; const properties: PAnsiChar): PEVP_MD; cdecl;
  TEVP_MD_free = procedure(md: PEVP_MD); cdecl;
  TEVP_MD_up_ref = function(md: PEVP_MD): Integer; cdecl;
  
  TEVP_get_digestbyname = function(const name: PAnsiChar): PEVP_MD; cdecl;
  TEVP_get_digestbynid = function(n: Integer): PEVP_MD; cdecl;
  TEVP_get_digestbyobj = function(const o: PASN1_OBJECT): PEVP_MD; cdecl;
  TEVP_MD_do_all = procedure(fn: Pointer; arg: Pointer); cdecl;
  TEVP_MD_do_all_sorted = procedure(fn: Pointer; arg: Pointer); cdecl;
  
  { EVP Cipher Functions }
  TEVP_CIPHER_CTX_new = function: PEVP_CIPHER_CTX; cdecl;
  TEVP_CIPHER_CTX_free = procedure(ctx: PEVP_CIPHER_CTX); cdecl;
  TEVP_CIPHER_CTX_reset = function(ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  TEVP_CIPHER_CTX_copy = function(&out: PEVP_CIPHER_CTX; const &in: PEVP_CIPHER_CTX): Integer; cdecl;
  TEVP_CIPHER_CTX_ctrl = function(ctx: PEVP_CIPHER_CTX; &type: Integer; arg: Integer; ptr: Pointer): Integer; cdecl;
  TEVP_CIPHER_CTX_set_padding = function(ctx: PEVP_CIPHER_CTX; pad: Integer): Integer; cdecl;
  TEVP_CIPHER_CTX_set_key_length = function(ctx: PEVP_CIPHER_CTX; keylen: Integer): Integer; cdecl;
  TEVP_CIPHER_CTX_set_num = procedure(ctx: PEVP_CIPHER_CTX; num: Integer); cdecl;
  TEVP_CIPHER_CTX_rand_key = function(ctx: PEVP_CIPHER_CTX; key: PByte): Integer; cdecl;
  
  TEVP_EncryptInit = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; const key: PByte; const iv: PByte): Integer; cdecl;
  TEVP_EncryptInit_ex = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; impl: PENGINE; const key: PByte; const iv: PByte): Integer; cdecl;
  TEVP_EncryptInit_ex2 = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; const key: PByte; const iv: PByte; const params: Pointer): Integer; cdecl;
  TEVP_EncryptUpdate = function(ctx: PEVP_CIPHER_CTX; &out: PByte; outl: PInteger; const &in: PByte; inl: Integer): Integer; cdecl;
  TEVP_EncryptFinal = function(ctx: PEVP_CIPHER_CTX; &out: PByte; outl: PInteger): Integer; cdecl;
  TEVP_EncryptFinal_ex = function(ctx: PEVP_CIPHER_CTX; &out: PByte; outl: PInteger): Integer; cdecl;
  
  TEVP_DecryptInit = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; const key: PByte; const iv: PByte): Integer; cdecl;
  TEVP_DecryptInit_ex = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; impl: PENGINE; const key: PByte; const iv: PByte): Integer; cdecl;
  TEVP_DecryptInit_ex2 = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; const key: PByte; const iv: PByte; const params: Pointer): Integer; cdecl;
  TEVP_DecryptUpdate = function(ctx: PEVP_CIPHER_CTX; &out: PByte; outl: PInteger; const &in: PByte; inl: Integer): Integer; cdecl;
  TEVP_DecryptFinal = function(ctx: PEVP_CIPHER_CTX; outm: PByte; outl: PInteger): Integer; cdecl;
  TEVP_DecryptFinal_ex = function(ctx: PEVP_CIPHER_CTX; outm: PByte; outl: PInteger): Integer; cdecl;
  
  TEVP_CipherInit = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; const key: PByte; const iv: PByte; enc: Integer): Integer; cdecl;
  TEVP_CipherInit_ex = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; impl: PENGINE; const key: PByte; const iv: PByte; enc: Integer): Integer; cdecl;
  TEVP_CipherInit_ex2 = function(ctx: PEVP_CIPHER_CTX; const cipher: PEVP_CIPHER; const key: PByte; const iv: PByte; enc: Integer; const params: Pointer): Integer; cdecl;
  TEVP_CipherUpdate = function(ctx: PEVP_CIPHER_CTX; &out: PByte; outl: PInteger; const &in: PByte; inl: Integer): Integer; cdecl;
  TEVP_CipherFinal = function(ctx: PEVP_CIPHER_CTX; outm: PByte; outl: PInteger): Integer; cdecl;
  TEVP_CipherFinal_ex = function(ctx: PEVP_CIPHER_CTX; outm: PByte; outl: PInteger): Integer; cdecl;
  TEVP_Cipher = function(ctx: PEVP_CIPHER_CTX; &out: PByte; const &in: PByte; inl: Cardinal): Integer; cdecl;
  
  TEVP_CIPHER_CTX_cipher = function(const ctx: PEVP_CIPHER_CTX): PEVP_CIPHER; cdecl;
  TEVP_CIPHER_CTX_get0_cipher = function(const ctx: PEVP_CIPHER_CTX): PEVP_CIPHER; cdecl;
  TEVP_CIPHER_CTX_get1_cipher = function(ctx: PEVP_CIPHER_CTX): PEVP_CIPHER; cdecl;
  TEVP_CIPHER_CTX_get_nid = function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  TEVP_CIPHER_CTX_get_block_size = function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  TEVP_CIPHER_CTX_get_key_length = function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  TEVP_CIPHER_CTX_get_iv_length = function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  TEVP_CIPHER_CTX_get_tag_length = function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  TEVP_CIPHER_CTX_get_app_data = function(const ctx: PEVP_CIPHER_CTX): Pointer; cdecl;
  TEVP_CIPHER_CTX_set_app_data = procedure(ctx: PEVP_CIPHER_CTX; data: Pointer); cdecl;
  TEVP_CIPHER_CTX_get_cipher_data = function(const ctx: PEVP_CIPHER_CTX): Pointer; cdecl;
  TEVP_CIPHER_CTX_get_num = function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  TEVP_CIPHER_CTX_is_encrypting = function(const ctx: PEVP_CIPHER_CTX): Integer; cdecl;
  
  TEVP_CIPHER_get_nid = function(const cipher: PEVP_CIPHER): Integer; cdecl;
  TEVP_CIPHER_get_block_size = function(const cipher: PEVP_CIPHER): Integer; cdecl;
  TEVP_CIPHER_get_key_length = function(const cipher: PEVP_CIPHER): Integer; cdecl;
  TEVP_CIPHER_get_iv_length = function(const cipher: PEVP_CIPHER): Integer; cdecl;
  TEVP_CIPHER_get_flags = function(const cipher: PEVP_CIPHER): LongWord; cdecl;
  TEVP_CIPHER_get_mode = function(const cipher: PEVP_CIPHER): LongWord; cdecl;
  TEVP_CIPHER_get_type = function(const cipher: PEVP_CIPHER): Integer; cdecl;
  TEVP_CIPHER_nid = function(const cipher: PEVP_CIPHER): Integer; cdecl;
  TEVP_CIPHER_name = function(const cipher: PEVP_CIPHER): PAnsiChar; cdecl;
  TEVP_CIPHER_get0_name = function(const cipher: PEVP_CIPHER): PAnsiChar; cdecl;
  TEVP_CIPHER_get0_description = function(const cipher: PEVP_CIPHER): PAnsiChar; cdecl;
  TEVP_CIPHER_is_a = function(const cipher: PEVP_CIPHER; const name: PAnsiChar): Integer; cdecl;
  TEVP_CIPHER_names_do_all = procedure(const cipher: PEVP_CIPHER; fn: Pointer; data: Pointer); cdecl;
  TEVP_CIPHER_get0_provider = function(const cipher: PEVP_CIPHER): Pointer; cdecl;
  
  { EVP Cipher Algorithms }
  TEVP_enc_null = function: PEVP_CIPHER; cdecl;
  TEVP_des_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_des_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_des_cfb = function: PEVP_CIPHER; cdecl;
  TEVP_des_cfb1 = function: PEVP_CIPHER; cdecl;
  TEVP_des_cfb8 = function: PEVP_CIPHER; cdecl;
  TEVP_des_cfb64 = function: PEVP_CIPHER; cdecl;
  TEVP_des_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede_cfb = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede_cfb64 = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3 = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3_cfb = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3_cfb1 = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3_cfb8 = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3_cfb64 = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_des_ede3_wrap = function: PEVP_CIPHER; cdecl;
  TEVP_desx_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_rc4 = function: PEVP_CIPHER; cdecl;
  TEVP_rc4_40 = function: PEVP_CIPHER; cdecl;
  TEVP_rc4_hmac_md5 = function: PEVP_CIPHER; cdecl;
  TEVP_idea_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_idea_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_idea_cfb = function: PEVP_CIPHER; cdecl;
  TEVP_idea_cfb64 = function: PEVP_CIPHER; cdecl;
  TEVP_idea_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_rc2_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_rc2_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_rc2_40_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_rc2_64_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_rc2_cfb = function: PEVP_CIPHER; cdecl;
  TEVP_rc2_cfb64 = function: PEVP_CIPHER; cdecl;
  TEVP_rc2_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_bf_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_bf_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_bf_cfb = function: PEVP_CIPHER; cdecl;
  TEVP_bf_cfb64 = function: PEVP_CIPHER; cdecl;
  TEVP_bf_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_cast5_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_cast5_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_cast5_cfb = function: PEVP_CIPHER; cdecl;
  TEVP_cast5_cfb64 = function: PEVP_CIPHER; cdecl;
  TEVP_cast5_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_rc5_32_12_16_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_rc5_32_12_16_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_rc5_32_12_16_cfb = function: PEVP_CIPHER; cdecl;
  TEVP_rc5_32_12_16_cfb64 = function: PEVP_CIPHER; cdecl;
  TEVP_rc5_32_12_16_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_aes_128_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_aes_128_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_aes_128_cfb = function: PEVP_CIPHER; cdecl;
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
  TEVP_aes_192_cfb = function: PEVP_CIPHER; cdecl;
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
  TEVP_aes_256_cfb = function: PEVP_CIPHER; cdecl;
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
  TEVP_camellia_128_cfb = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_128_cfb1 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_128_cfb8 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_128_cfb128 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_128_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_128_ctr = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_192_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_192_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_192_cfb = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_192_cfb1 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_192_cfb8 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_192_cfb128 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_192_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_192_ctr = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_256_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_256_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_256_cfb = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_256_cfb1 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_256_cfb8 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_256_cfb128 = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_256_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_camellia_256_ctr = function: PEVP_CIPHER; cdecl;
  TEVP_chacha20 = function: PEVP_CIPHER; cdecl;
  TEVP_chacha20_poly1305 = function: PEVP_CIPHER; cdecl;
  TEVP_seed_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_seed_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_seed_cfb = function: PEVP_CIPHER; cdecl;
  TEVP_seed_cfb128 = function: PEVP_CIPHER; cdecl;
  TEVP_seed_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_sm4_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_sm4_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_sm4_cfb = function: PEVP_CIPHER; cdecl;
  TEVP_sm4_cfb128 = function: PEVP_CIPHER; cdecl;
  TEVP_sm4_ofb = function: PEVP_CIPHER; cdecl;
  TEVP_sm4_ctr = function: PEVP_CIPHER; cdecl;
  
  TEVP_CIPHER_fetch = function(ctx: Pointer; const algorithm: PAnsiChar; const properties: PAnsiChar): PEVP_CIPHER; cdecl;
  TEVP_CIPHER_free = procedure(cipher: PEVP_CIPHER); cdecl;
  TEVP_CIPHER_up_ref = function(cipher: PEVP_CIPHER): Integer; cdecl;
  
  TEVP_get_cipherbyname = function(const name: PAnsiChar): PEVP_CIPHER; cdecl;
  TEVP_get_cipherbynid = function(n: Integer): PEVP_CIPHER; cdecl;
  TEVP_get_cipherbyobj = function(const o: PASN1_OBJECT): PEVP_CIPHER; cdecl;
  TEVP_CIPHER_do_all = procedure(fn: Pointer; arg: Pointer); cdecl;
  TEVP_CIPHER_do_all_sorted = procedure(fn: Pointer; arg: Pointer); cdecl;
  
  { EVP Key Functions }
  TEVP_PKEY_new = function: PEVP_PKEY; cdecl;
  TEVP_PKEY_free = procedure(pkey: PEVP_PKEY); cdecl;
  TEVP_PKEY_up_ref = function(pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_dup = function(pkey: PEVP_PKEY): PEVP_PKEY; cdecl;
  TEVP_PKEY_copy_parameters = function(&to: PEVP_PKEY; const from: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_missing_parameters = function(const pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_save_parameters = function(pkey: PEVP_PKEY; mode: Integer): Integer; cdecl;
  TEVP_PKEY_parameters_eq = function(const a: PEVP_PKEY; const b: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_eq = function(const a: PEVP_PKEY; const b: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_cmp_parameters = function(const a: PEVP_PKEY; const b: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_cmp = function(const a: PEVP_PKEY; const b: PEVP_PKEY): Integer; cdecl;
  
  TEVP_PKEY_get_base_id = function(const pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_get_bits = function(const pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_get_security_bits = function(const pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_get_size = function(const pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_can_sign = function(const pkey: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_set_type = function(pkey: PEVP_PKEY; &type: Integer): Integer; cdecl;
  TEVP_PKEY_set_type_str = function(pkey: PEVP_PKEY; const str: PAnsiChar; len: Integer): Integer; cdecl;
  TEVP_PKEY_set1_engine = function(pkey: PEVP_PKEY; e: PENGINE): Integer; cdecl;
  TEVP_PKEY_get0_engine = function(const pkey: PEVP_PKEY): PENGINE; cdecl;
  TEVP_PKEY_assign = function(pkey: PEVP_PKEY; &type: Integer; key: Pointer): Integer; cdecl;
  TEVP_PKEY_get0 = function(const pkey: PEVP_PKEY): Pointer; cdecl;
  TEVP_PKEY_get0_hmac = function(const pkey: PEVP_PKEY; len: Psize_t): PByte; cdecl;
  TEVP_PKEY_get0_poly1305 = function(const pkey: PEVP_PKEY; len: Psize_t): PByte; cdecl;
  TEVP_PKEY_get0_siphash = function(const pkey: PEVP_PKEY; len: Psize_t): PByte; cdecl;
  
  TEVP_PKEY_set1_RSA = function(pkey: PEVP_PKEY; key: PRSA): Integer; cdecl;
  TEVP_PKEY_get0_RSA = function(const pkey: PEVP_PKEY): PRSA; cdecl;
  TEVP_PKEY_get1_RSA = function(pkey: PEVP_PKEY): PRSA; cdecl;
  TEVP_PKEY_set1_DSA = function(pkey: PEVP_PKEY; key: PDSA): Integer; cdecl;
  TEVP_PKEY_get0_DSA = function(const pkey: PEVP_PKEY): PDSA; cdecl;
  TEVP_PKEY_get1_DSA = function(pkey: PEVP_PKEY): PDSA; cdecl;
  TEVP_PKEY_set1_DH = function(pkey: PEVP_PKEY; key: PDH): Integer; cdecl;
  TEVP_PKEY_get0_DH = function(const pkey: PEVP_PKEY): PDH; cdecl;
  TEVP_PKEY_get1_DH = function(pkey: PEVP_PKEY): PDH; cdecl;
  TEVP_PKEY_set1_EC_KEY = function(pkey: PEVP_PKEY; key: PEC_KEY): Integer; cdecl;
  TEVP_PKEY_get0_EC_KEY = function(const pkey: PEVP_PKEY): PEC_KEY; cdecl;
  TEVP_PKEY_get1_EC_KEY = function(pkey: PEVP_PKEY): PEC_KEY; cdecl;
  
  TEVP_PKEY_new_raw_private_key = function(&type: Integer; e: PENGINE; const priv: PByte; len: size_t): PEVP_PKEY; cdecl;
  TEVP_PKEY_new_raw_private_key_ex = function(libctx: Pointer; const keytype: PAnsiChar; const propq: PAnsiChar; const priv: PByte; len: size_t): PEVP_PKEY; cdecl;
  TEVP_PKEY_new_raw_public_key = function(&type: Integer; e: PENGINE; const pub: PByte; len: size_t): PEVP_PKEY; cdecl;
  TEVP_PKEY_new_raw_public_key_ex = function(libctx: Pointer; const keytype: PAnsiChar; const propq: PAnsiChar; const pub: PByte; len: size_t): PEVP_PKEY; cdecl;
  TEVP_PKEY_get_raw_private_key = function(const pkey: PEVP_PKEY; priv: PByte; len: Psize_t): Integer; cdecl;
  TEVP_PKEY_get_raw_public_key = function(const pkey: PEVP_PKEY; pub: PByte; len: Psize_t): Integer; cdecl;
  
  TEVP_PKEY_new_CMAC_key = function(e: PENGINE; const priv: PByte; len: size_t; const cipher: PEVP_CIPHER): PEVP_PKEY; cdecl;
  TEVP_PKEY_new_mac_key = function(&type: Integer; e: PENGINE; const key: PByte; keylen: Integer): PEVP_PKEY; cdecl;
  
  { EVP Key Context Functions }
  TEVP_PKEY_CTX_new = function(pkey: PEVP_PKEY; e: PENGINE): PEVP_PKEY_CTX; cdecl;
  TEVP_PKEY_CTX_new_id = function(id: Integer; e: PENGINE): PEVP_PKEY_CTX; cdecl;
  TEVP_PKEY_CTX_new_from_name = function(libctx: Pointer; const name: PAnsiChar; const propquery: PAnsiChar): PEVP_PKEY_CTX; cdecl;
  TEVP_PKEY_CTX_new_from_pkey = function(libctx: Pointer; pkey: PEVP_PKEY; const propquery: PAnsiChar): PEVP_PKEY_CTX; cdecl;
  TEVP_PKEY_CTX_dup = function(const ctx: PEVP_PKEY_CTX): PEVP_PKEY_CTX; cdecl;
  TEVP_PKEY_CTX_free = procedure(ctx: PEVP_PKEY_CTX); cdecl;
  TEVP_PKEY_CTX_is_a = function(ctx: PEVP_PKEY_CTX; const keytype: PAnsiChar): Integer; cdecl;
  
  TEVP_PKEY_CTX_get0_pkey = function(ctx: PEVP_PKEY_CTX): PEVP_PKEY; cdecl;
  TEVP_PKEY_CTX_get0_peerkey = function(ctx: PEVP_PKEY_CTX): PEVP_PKEY; cdecl;
  TEVP_PKEY_CTX_set_app_data = procedure(ctx: PEVP_PKEY_CTX; data: Pointer); cdecl;
  TEVP_PKEY_CTX_get_app_data = function(ctx: PEVP_PKEY_CTX): Pointer; cdecl;
  TEVP_PKEY_CTX_get_operation = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_CTX_set0_keygen_info = procedure(ctx: PEVP_PKEY_CTX; dat: PInteger; datlen: Integer); cdecl;
  TEVP_PKEY_CTX_get_keygen_info = function(ctx: PEVP_PKEY_CTX; idx: Integer): Integer; cdecl;
  TEVP_PKEY_CTX_set_data = procedure(ctx: PEVP_PKEY_CTX; data: Pointer); cdecl;
  TEVP_PKEY_CTX_get_data = function(const ctx: PEVP_PKEY_CTX): Pointer; cdecl;
  
  TEVP_PKEY_CTX_ctrl = function(ctx: PEVP_PKEY_CTX; keytype: Integer; optype: Integer; cmd: Integer; p1: Integer; p2: Pointer): Integer; cdecl;
  TEVP_PKEY_CTX_ctrl_str = function(ctx: PEVP_PKEY_CTX; const &type: PAnsiChar; const value: PAnsiChar): Integer; cdecl;
  TEVP_PKEY_CTX_ctrl_uint64 = function(ctx: PEVP_PKEY_CTX; keytype: Integer; optype: Integer; cmd: Integer; value: UInt64): Integer; cdecl;
  TEVP_PKEY_CTX_set_signature_md = function(ctx: PEVP_PKEY_CTX; const md: PEVP_MD): Integer; cdecl;
  TEVP_PKEY_CTX_get_signature_md = function(ctx: PEVP_PKEY_CTX; const md: PPEVP_MD): Integer; cdecl;
  TEVP_PKEY_CTX_set_mac_key = function(ctx: PEVP_PKEY_CTX; const key: PByte; keylen: Integer): Integer; cdecl;
  
  { EVP Signing Functions }
  TEVP_PKEY_sign_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_sign = function(ctx: PEVP_PKEY_CTX; sig: PByte; siglen: Psize_t; const tbs: PByte; tbslen: size_t): Integer; cdecl;
  TEVP_PKEY_verify_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_verify = function(ctx: PEVP_PKEY_CTX; const sig: PByte; siglen: size_t; const tbs: PByte; tbslen: size_t): Integer; cdecl;
  TEVP_PKEY_verify_recover_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_verify_recover = function(ctx: PEVP_PKEY_CTX; rout: PByte; routlen: Psize_t; const sig: PByte; siglen: size_t): Integer; cdecl;
  
  { EVP Encryption Functions }
  TEVP_PKEY_encrypt_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_encrypt = function(ctx: PEVP_PKEY_CTX; &out: PByte; outlen: Psize_t; const &in: PByte; inlen: size_t): Integer; cdecl;
  TEVP_PKEY_decrypt_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_decrypt = function(ctx: PEVP_PKEY_CTX; &out: PByte; outlen: Psize_t; const &in: PByte; inlen: size_t): Integer; cdecl;
  
  { EVP Key Derivation Functions }
  TEVP_PKEY_derive_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_derive_set_peer = function(ctx: PEVP_PKEY_CTX; peer: PEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_derive = function(ctx: PEVP_PKEY_CTX; key: PByte; keylen: Psize_t): Integer; cdecl;
  
  { EVP Key Generation Functions }
  TEVP_PKEY_keygen_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_keygen = function(ctx: PEVP_PKEY_CTX; ppkey: PPEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_paramgen_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_paramgen = function(ctx: PEVP_PKEY_CTX; ppkey: PPEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_check = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_public_check = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_private_check = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_pairwise_check = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_generate = function(ctx: PEVP_PKEY_CTX; ppkey: PPEVP_PKEY): Integer; cdecl;
  TEVP_PKEY_fromdata_init = function(ctx: PEVP_PKEY_CTX): Integer; cdecl;
  TEVP_PKEY_fromdata = function(ctx: PEVP_PKEY_CTX; ppkey: PPEVP_PKEY; selection: Integer; params: Pointer): Integer; cdecl;
  TEVP_PKEY_todata = function(const pkey: PEVP_PKEY; selection: Integer; params: PPointer): Integer; cdecl;
  TEVP_PKEY_export = function(const pkey: PEVP_PKEY; selection: Integer; export_cb: Pointer; export_cbarg: Pointer): Integer; cdecl;
  
  { HMAC Functions }
  THMAC_CTX_new = function: PHMAC_CTX; cdecl;
  THMAC_CTX_free = procedure(ctx: PHMAC_CTX); cdecl;
  THMAC_CTX_reset = function(ctx: PHMAC_CTX): Integer; cdecl;
  THMAC_CTX_copy = function(dctx: PHMAC_CTX; sctx: PHMAC_CTX): Integer; cdecl;
  THMAC_CTX_set_flags = procedure(ctx: PHMAC_CTX; flags: LongWord); cdecl;
  THMAC_CTX_get_md = function(const ctx: PHMAC_CTX): PEVP_MD; cdecl;
  THMAC = function(const evp_md: PEVP_MD; const key: Pointer; key_len: Integer; const data: PByte; data_len: size_t; md: PByte; md_len: PCardinal): PByte; cdecl;
  THMAC_Init = function(ctx: PHMAC_CTX; const key: Pointer; len: Integer; const md: PEVP_MD): Integer; cdecl;
  THMAC_Init_ex = function(ctx: PHMAC_CTX; const key: Pointer; len: Integer; const md: PEVP_MD; impl: PENGINE): Integer; cdecl;
  THMAC_Update = function(ctx: PHMAC_CTX; const data: PByte; len: size_t): Integer; cdecl;
  THMAC_Final = function(ctx: PHMAC_CTX; md: PByte; len: PCardinal): Integer; cdecl;
  THMAC_size = function(const ctx: PHMAC_CTX): size_t; cdecl;
  
  { CMAC Functions }
  TCMAC_CTX_new = function: Pointer; cdecl;
  TCMAC_CTX_free = procedure(ctx: Pointer); cdecl;
  TCMAC_CTX_copy = function(&out: Pointer; const &in: Pointer): Integer; cdecl;
  TCMAC_CTX_get0_cipher_ctx = function(ctx: Pointer): PEVP_CIPHER_CTX; cdecl;
  TCMAC_Init = function(ctx: Pointer; const key: Pointer; keylen: size_t; const cipher: PEVP_CIPHER; impl: PENGINE): Integer; cdecl;
  TCMAC_Update = function(ctx: Pointer; const data: Pointer; dlen: size_t): Integer; cdecl;
  TCMAC_Final = function(ctx: Pointer; &out: PByte; poutlen: Psize_t): Integer; cdecl;
  TCMAC_resume = function(ctx: Pointer): Integer; cdecl;
  
  { PBKDF2 Functions }
  TPKCS5_PBKDF2_HMAC = function(const pass: PAnsiChar; passlen: Integer; const salt: PByte; saltlen: Integer; iter: Integer; const digest: PEVP_MD; keylen: Integer; &out: PByte): Integer; cdecl;
  TPKCS5_PBKDF2_HMAC_SHA1 = function(const pass: PAnsiChar; passlen: Integer; const salt: PByte; saltlen: Integer; iter: Integer; keylen: Integer; &out: PByte): Integer; cdecl;
  TEVP_PBE_scrypt = function(const pass: PAnsiChar; passlen: size_t; const salt: PByte; saltlen: size_t; N: UInt64; r: UInt64; p: UInt64; maxmem: UInt64; key: PByte; keylen: size_t): Integer; cdecl;
  
  { KDF Functions }
  TEVP_KDF_fetch = function(libctx: Pointer; const algorithm: PAnsiChar; const properties: PAnsiChar): Pointer; cdecl;
  TEVP_KDF_free = procedure(kdf: Pointer); cdecl;
  TEVP_KDF_up_ref = function(kdf: Pointer): Integer; cdecl;
  TEVP_KDF_CTX_new = function(kdf: Pointer): Pointer; cdecl;
  TEVP_KDF_CTX_free = procedure(ctx: Pointer); cdecl;
  TEVP_KDF_CTX_dup = function(const src: Pointer): Pointer; cdecl;
  TEVP_KDF_CTX_reset = procedure(ctx: Pointer); cdecl;
  TEVP_KDF_CTX_get_kdf_size = function(ctx: Pointer): size_t; cdecl;
  TEVP_KDF_derive = function(ctx: Pointer; key: PByte; keylen: size_t; const params: Pointer): Integer; cdecl;
  TEVP_KDF_get0_name = function(const kdf: Pointer): PAnsiChar; cdecl;
  TEVP_KDF_get0_description = function(const kdf: Pointer): PAnsiChar; cdecl;
  TEVP_KDF_is_a = function(const kdf: Pointer; const name: PAnsiChar): Integer; cdecl;
  TEVP_KDF_get0_provider = function(const kdf: Pointer): Pointer; cdecl;
  TEVP_KDF_CTX_get_kdf = function(ctx: Pointer): Pointer; cdecl;
  TEVP_KDF_CTX_set_params = function(ctx: Pointer; const params: Pointer): Integer; cdecl;
  TEVP_KDF_CTX_get_params = function(ctx: Pointer; params: Pointer): Integer; cdecl;
  TEVP_KDF_CTX_gettable_params = function(ctx: Pointer): Pointer; cdecl;
  TEVP_KDF_CTX_settable_params = function(ctx: Pointer): Pointer; cdecl;
  TEVP_KDF_do_all_provided = procedure(libctx: Pointer; fn: Pointer; arg: Pointer); cdecl;
  TEVP_KDF_names_do_all = procedure(const kdf: Pointer; fn: Pointer; data: Pointer); cdecl;
  TEVP_KDF_gettable_params = function(const kdf: Pointer): Pointer; cdecl;
  TEVP_KDF_gettable_ctx_params = function(const kdf: Pointer): Pointer; cdecl;
  TEVP_KDF_settable_ctx_params = function(const kdf: Pointer): Pointer; cdecl;
  
  { MAC Functions }
  TEVP_MAC_fetch = function(libctx: Pointer; const algorithm: PAnsiChar; const properties: PAnsiChar): Pointer; cdecl;
  TEVP_MAC_up_ref = function(mac: Pointer): Integer; cdecl;
  TEVP_MAC_free = procedure(mac: Pointer); cdecl;
  TEVP_MAC_is_a = function(const mac: Pointer; const name: PAnsiChar): Integer; cdecl;
  TEVP_MAC_get0_name = function(const mac: Pointer): PAnsiChar; cdecl;
  TEVP_MAC_names_do_all = procedure(const mac: Pointer; fn: Pointer; data: Pointer); cdecl;
  TEVP_MAC_get0_description = function(const mac: Pointer): PAnsiChar; cdecl;
  TEVP_MAC_get0_provider = function(const mac: Pointer): Pointer; cdecl;
  TEVP_MAC_get_params = function(mac: Pointer; params: Pointer): Integer; cdecl;
  TEVP_MAC_CTX_new = function(mac: Pointer): Pointer; cdecl;
  TEVP_MAC_CTX_free = procedure(ctx: Pointer); cdecl;
  TEVP_MAC_CTX_dup = function(const src: Pointer): Pointer; cdecl;
  TEVP_MAC_CTX_get0_mac = function(ctx: Pointer): Pointer; cdecl;
  TEVP_MAC_CTX_get_params = function(ctx: Pointer; params: Pointer): Integer; cdecl;
  TEVP_MAC_CTX_set_params = function(ctx: Pointer; const params: Pointer): Integer; cdecl;
  TEVP_MAC_CTX_get_mac_size = function(ctx: Pointer): size_t; cdecl;
  TEVP_MAC_CTX_get_block_size = function(ctx: Pointer): size_t; cdecl;
  TEVP_MAC_init = function(ctx: Pointer; const key: PByte; keylen: size_t; const params: Pointer): Integer; cdecl;
  TEVP_MAC_update = function(ctx: Pointer; const data: PByte; datalen: size_t): Integer; cdecl;
  TEVP_MAC_final = function(ctx: Pointer; &out: PByte; outl: Psize_t; outsize: size_t): Integer; cdecl;
  TEVP_MAC_finalXOF = function(ctx: Pointer; &out: PByte; outsize: size_t): Integer; cdecl;
  TEVP_MAC_gettable_params = function(const mac: Pointer): Pointer; cdecl;
  TEVP_MAC_gettable_ctx_params = function(const mac: Pointer): Pointer; cdecl;
  TEVP_MAC_settable_ctx_params = function(const mac: Pointer): Pointer; cdecl;
  TEVP_MAC_CTX_gettable_params = function(ctx: Pointer): Pointer; cdecl;
  TEVP_MAC_CTX_settable_params = function(ctx: Pointer): Pointer; cdecl;
  TEVP_MAC_do_all_provided = procedure(libctx: Pointer; fn: Pointer; arg: Pointer); cdecl;

var
  // Function pointers will be dynamically loaded
  // This is a partial list - complete implementation would include all functions
  CRYPTO_free: TCRYPTO_free;
  OPENSSL_free: TOPENSSL_free;
  
  { Dynamic Library Loading }
  
procedure LoadOpenSSLCrypto;
procedure UnloadOpenSSLCrypto;

implementation

uses nextpas.core.tls.openssl.api.core, nextpas.core.tls.openssl.loader,
  nextpas.core.platform.dl;

const
  { Crypto function bindings for batch loading }
  CRYPTO_BINDINGS: array[0..1] of TFunctionBinding = (
    (Name: 'CRYPTO_free';   FuncPtr: @CRYPTO_free;   Required: False),
    (Name: 'OPENSSL_free';  FuncPtr: @OPENSSL_free;  Required: False)
  );

procedure OpenSSLFreeFallback(ptr: Pointer); cdecl;
begin
  if Assigned(CRYPTO_free) then
    CRYPTO_free(ptr, nil, 0);
end;

procedure LoadOpenSSLCrypto;
var
  LLib: TPlatformLibrary;
begin
  // Use the crypto library handle from core module
  LLib := GetCryptoLibHandle;
  if not LibLoaded(LLib) then
  begin
    // Try to load core first
    LoadOpenSSLCore;
    LLib := GetCryptoLibHandle;
  end;

  if not LibLoaded(LLib) then
    Exit;

  // Load crypto functions using batch loading
  TOpenSSLLoader.LoadFunctions(LLib, CRYPTO_BINDINGS);

  // Compatibility fallback: some OpenSSL builds may not export OPENSSL_free
  if (not Assigned(OPENSSL_free)) and Assigned(CRYPTO_free) then
    OPENSSL_free := @OpenSSLFreeFallback;
end;

procedure UnloadOpenSSLCrypto;
begin
  // Clear all function pointers using batch unloading
  TOpenSSLLoader.ClearFunctions(CRYPTO_BINDINGS);
end;

end.