unit nextpas.core.tls.openssl.api.sm;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.core, nextpas.core.tls.openssl.loader; const // SM2 curve NID NID_sm2 = 1172;
  
  // SM3 digest NID
  NID_sm3 = 1143;
  
  // SM4 cipher NIDs
  NID_sm4_ecb = 1133;
  NID_sm4_cbc = 1134;
  NID_sm4_cfb128 = 1137;
  NID_sm4_ofb128 = 1135;
  NID_sm4_ctr = 1139;
  
  // SM2 signature NIDs
  NID_sm2sign = 1204;
  NID_SM2_with_SM3 = 1206;
  
  // Key sizes
  SM2_KEY_SIZE = 32;  // 256 bits
  SM3_DIGEST_LENGTH = 32;  // 256 bits
  SM4_KEY_LENGTH = 16;  // 128 bits
  SM4_BLOCK_SIZE = 16;  // 128 bits

type
  // SM2 context
  PSM2_CTX = ^SM2_CTX;
  SM2_CTX = record end;
  
  // SM3 context
  PSM3_CTX = ^SM3_CTX;
  SM3_CTX = record
    digest: array[0..7] of Cardinal;
    block: array[0..15] of Cardinal;
    num: Cardinal;
    nlow: Cardinal;
    nhigh: Cardinal;
  end;
  
  // SM4 context
  PSM4_CTX = ^SM4_CTX;
  SM4_CTX = record
    rk: array[0..31] of Cardinal;
  end;
  
  // Function pointer types for SM2
  TSM2_sign = function(dtype: TOpenSSL_Int; const dgst: PByte; dgst_len: TOpenSSL_Size;
                      sig: PByte; sig_len: POpenSSL_Size; eckey: PEC_KEY): TOpenSSL_Int; cdecl;
  TSM2_verify = function(dtype: TOpenSSL_Int; const dgst: PByte; dgst_len: TOpenSSL_Size;
                        const sig: PByte; sig_len: TOpenSSL_Size; eckey: PEC_KEY): TOpenSSL_Int; cdecl;
  TSM2_encrypt = function(const eckey: PEC_KEY; const plaintext: PByte; plaintext_len: TOpenSSL_Size;
                          ciphertext: PByte; ciphertext_len: POpenSSL_Size): TOpenSSL_Int; cdecl;
  TSM2_decrypt = function(const eckey: PEC_KEY; const ciphertext: PByte; ciphertext_len: TOpenSSL_Size;
                          plaintext: PByte; plaintext_len: POpenSSL_Size): TOpenSSL_Int; cdecl;
  TSM2_compute_z_digest = function(md: PEVP_MD_CTX; const id: PByte; id_len: TOpenSSL_Size;
                                  const id_md: PEVP_MD; const eckey: PEC_KEY): TOpenSSL_Int; cdecl;
  
  // Function pointer types for SM3
  TSM3_Init = function(c: PSM3_CTX): TOpenSSL_Int; cdecl;
  TSM3_Update = function(c: PSM3_CTX; const data: Pointer; len: TOpenSSL_Size): TOpenSSL_Int; cdecl;
  TSM3_Final = function(md: PByte; c: PSM3_CTX): TOpenSSL_Int; cdecl;
  TSM3 = function(const d: PByte; n: TOpenSSL_Size; md: PByte): PByte; cdecl;
  TSM3_Transform = procedure(c: PSM3_CTX; const data: PByte); cdecl;
  
  // Function pointer types for SM4
  TSM4_set_key = function(const key: PByte; ks: PSM4_CTX): TOpenSSL_Int; cdecl;
  TSM4_encrypt = procedure(const in_data: PByte; out_data: PByte; const ks: PSM4_CTX); cdecl;
  TSM4_decrypt = procedure(const in_data: PByte; out_data: PByte; const ks: PSM4_CTX); cdecl;
  TSM4_ecb_encrypt = procedure(const in_data: PByte; out_data: PByte; const key: PSM4_CTX;
                                const enc: TOpenSSL_Int); cdecl;
  TSM4_cbc_encrypt = procedure(const in_data: PByte; out_data: PByte; length: TOpenSSL_Size;
                                const key: PSM4_CTX; ivec: PByte; const enc: TOpenSSL_Int); cdecl;
  TSM4_cfb128_encrypt = procedure(const in_data: PByte; out_data: PByte; length: TOpenSSL_Size;
                                  const key: PSM4_CTX; ivec: PByte; num: POpenSSL_Int;
                                  const enc: TOpenSSL_Int); cdecl;
  TSM4_ofb128_encrypt = procedure(const in_data: PByte; out_data: PByte; length: TOpenSSL_Size;
                                  const key: PSM4_CTX; ivec: PByte; num: POpenSSL_Int); cdecl;
  TSM4_ctr128_encrypt = procedure(const in_data: PByte; out_data: PByte; length: TOpenSSL_Size;
                                  const key: PSM4_CTX; ivec: PByte; ctr: PByte; num: PCardinal); cdecl;
  
  // EVP interface for SM algorithms
  TEVP_sm2 = function: PEC_KEY_METHOD; cdecl;
  TEVP_sm3 = function: PEVP_MD; cdecl;
  TEVP_sm4_ecb = function: PEVP_CIPHER; cdecl;
  TEVP_sm4_cbc = function: PEVP_CIPHER; cdecl;
  TEVP_sm4_cfb128 = function: PEVP_CIPHER; cdecl;
  TEVP_sm4_ofb128 = function: PEVP_CIPHER; cdecl;
  TEVP_sm4_ctr = function: PEVP_CIPHER; cdecl;

var
  // SM2 functions
  SM2_sign: TSM2_sign = nil;
  SM2_verify: TSM2_verify = nil;
  SM2_encrypt: TSM2_encrypt = nil;
  SM2_decrypt: TSM2_decrypt = nil;
  SM2_compute_z_digest: TSM2_compute_z_digest = nil;
  
  // SM3 functions
  SM3_Init: TSM3_Init = nil;
  SM3_Update: TSM3_Update = nil;
  SM3_Final: TSM3_Final = nil;
  SM3: TSM3 = nil;
  SM3_Transform: TSM3_Transform = nil;
  
  // SM4 functions
  SM4_set_key: TSM4_set_key = nil;
  SM4_encrypt: TSM4_encrypt = nil;
  SM4_decrypt: TSM4_decrypt = nil;
  SM4_ecb_encrypt: TSM4_ecb_encrypt = nil;
  SM4_cbc_encrypt: TSM4_cbc_encrypt = nil;
  SM4_cfb128_encrypt: TSM4_cfb128_encrypt = nil;
  SM4_ofb128_encrypt: TSM4_ofb128_encrypt = nil;
  SM4_ctr128_encrypt: TSM4_ctr128_encrypt = nil;
  
  // EVP interfaces
  EVP_sm2: TEVP_sm2 = nil;
  EVP_sm3: TEVP_sm3 = nil;
  EVP_sm4_ecb: TEVP_sm4_ecb = nil;
  EVP_sm4_cbc: TEVP_sm4_cbc = nil;
  EVP_sm4_cfb128: TEVP_sm4_cfb128 = nil;
  EVP_sm4_ofb128: TEVP_sm4_ofb128 = nil;
  EVP_sm4_ctr: TEVP_sm4_ctr = nil;

// Helper functions
function IsSMAlgorithmsSupported: Boolean;
procedure LoadOpenSSLSM;
procedure UnloadOpenSSLSM;

implementation

function IsSMAlgorithmsSupported: Boolean;
begin
  Result := Assigned(EVP_sm3) and Assigned(EVP_sm4_cbc);
end;

procedure LoadOpenSSLSM;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    Exit;
    
  // SM2 functions
  SM2_sign := TSM2_sign(GetCryptoProcAddress('SM2_sign'));
  SM2_verify := TSM2_verify(GetCryptoProcAddress('SM2_verify'));
  SM2_encrypt := TSM2_encrypt(GetCryptoProcAddress('SM2_encrypt'));
  SM2_decrypt := TSM2_decrypt(GetCryptoProcAddress('SM2_decrypt'));
  SM2_compute_z_digest := TSM2_compute_z_digest(GetCryptoProcAddress('SM2_compute_z_digest'));
  
  // SM3 functions
  SM3_Init := TSM3_Init(GetCryptoProcAddress('SM3_Init'));
  SM3_Update := TSM3_Update(GetCryptoProcAddress('SM3_Update'));
  SM3_Final := TSM3_Final(GetCryptoProcAddress('SM3_Final'));
  SM3 := TSM3(GetCryptoProcAddress('SM3'));
  SM3_Transform := TSM3_Transform(GetCryptoProcAddress('SM3_Transform'));
  
  // SM4 functions
  SM4_set_key := TSM4_set_key(GetCryptoProcAddress('SM4_set_key'));
  SM4_encrypt := TSM4_encrypt(GetCryptoProcAddress('SM4_encrypt'));
  SM4_decrypt := TSM4_decrypt(GetCryptoProcAddress('SM4_decrypt'));
  SM4_ecb_encrypt := TSM4_ecb_encrypt(GetCryptoProcAddress('SM4_ecb_encrypt'));
  SM4_cbc_encrypt := TSM4_cbc_encrypt(GetCryptoProcAddress('SM4_cbc_encrypt'));
  SM4_cfb128_encrypt := TSM4_cfb128_encrypt(GetCryptoProcAddress('SM4_cfb128_encrypt'));
  SM4_ofb128_encrypt := TSM4_ofb128_encrypt(GetCryptoProcAddress('SM4_ofb128_encrypt'));
  SM4_ctr128_encrypt := TSM4_ctr128_encrypt(GetCryptoProcAddress('SM4_ctr128_encrypt'));
  
  // EVP interfaces - these are the most commonly available
  EVP_sm2 := TEVP_sm2(GetCryptoProcAddress('EVP_sm2'));
  EVP_sm3 := TEVP_sm3(GetCryptoProcAddress('EVP_sm3'));
  EVP_sm4_ecb := TEVP_sm4_ecb(GetCryptoProcAddress('EVP_sm4_ecb'));
  EVP_sm4_cbc := TEVP_sm4_cbc(GetCryptoProcAddress('EVP_sm4_cbc'));
  EVP_sm4_cfb128 := TEVP_sm4_cfb128(GetCryptoProcAddress('EVP_sm4_cfb128'));
  EVP_sm4_ofb128 := TEVP_sm4_ofb128(GetCryptoProcAddress('EVP_sm4_ofb128'));
  EVP_sm4_ctr := TEVP_sm4_ctr(GetCryptoProcAddress('EVP_sm4_ctr'));
end;

procedure UnloadOpenSSLSM;
begin
  // SM2 functions
  SM2_sign := nil;
  SM2_verify := nil;
  SM2_encrypt := nil;
  SM2_decrypt := nil;
  SM2_compute_z_digest := nil;
  
  // SM3 functions
  SM3_Init := nil;
  SM3_Update := nil;
  SM3_Final := nil;
  SM3 := nil;
  SM3_Transform := nil;
  
  // SM4 functions
  SM4_set_key := nil;
  SM4_encrypt := nil;
  SM4_decrypt := nil;
  SM4_ecb_encrypt := nil;
  SM4_cbc_encrypt := nil;
  SM4_cfb128_encrypt := nil;
  SM4_ofb128_encrypt := nil;
  SM4_ctr128_encrypt := nil;
  
  // EVP interfaces
  EVP_sm2 := nil;
  EVP_sm3 := nil;
  EVP_sm4_ecb := nil;
  EVP_sm4_cbc := nil;
  EVP_sm4_cfb128 := nil;
  EVP_sm4_ofb128 := nil;
  EVP_sm4_ctr := nil;
end;

initialization

finalization
  UnloadOpenSSLSM;

end.