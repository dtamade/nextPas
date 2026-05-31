{
  OpenSSL KDF (密钥派生函数) API 模块
  支持 PBKDF2、HKDF、TLS1-PRF、scrypt 等密钥派生算法
}
unit nextpas.core.tls.openssl.api.kdf;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.hmac;

const
  // KDF 算法 NID
  EVP_PKEY_CTRL_TLS_MD = $1000;
  EVP_PKEY_CTRL_TLS_SECRET = $1001;
  EVP_PKEY_CTRL_TLS_SEED = $1002;
  EVP_PKEY_CTRL_HKDF_MD = $1003;
  EVP_PKEY_CTRL_HKDF_SALT = $1004;
  EVP_PKEY_CTRL_HKDF_KEY = $1005;
  EVP_PKEY_CTRL_HKDF_INFO = $1006;
  EVP_PKEY_CTRL_HKDF_MODE = $1007;
  EVP_PKEY_CTRL_PASS = $1008;
  EVP_PKEY_CTRL_SCRYPT_SALT = $1009;
  EVP_PKEY_CTRL_SCRYPT_N = $100A;
  EVP_PKEY_CTRL_SCRYPT_R = $100B;
  EVP_PKEY_CTRL_SCRYPT_P = $100C;
  EVP_PKEY_CTRL_SCRYPT_MAXMEM_BYTES = $100D;
  
  // NID for HKDF (needed for EVP_PKEY_CTX_new_id)
  NID_hkdf = 1036;  // OpenSSL NID for HKDF
  
  // HKDF 模式
  EVP_PKEY_HKDEF_MODE_EXTRACT_AND_EXPAND = 0;
  EVP_PKEY_HKDEF_MODE_EXTRACT_ONLY = 1;
  EVP_PKEY_HKDEF_MODE_EXPAND_ONLY = 2;
  
  // PBKDF2 默认参数
  PKCS5_SALT_LEN = 8;
  PKCS5_DEFAULT_ITER = 2048;
  
  // scrypt 默认参数
  SCRYPT_DEFAULT_N = 16384;
  SCRYPT_DEFAULT_R = 8;
  SCRYPT_DEFAULT_P = 1;
  SCRYPT_DEFAULT_MAXMEM = 32 * 1024 * 1024; // 32 MB
  
  // KDF 类型
  KDF_PBKDF2 = 1;
  KDF_SCRYPT = 2;
  KDF_TLS1_PRF = 3;
  KDF_HKDF = 4;
  KDF_SSHKDF = 5;
  KDF_SS_DES = 6;
  KDF_SS_DES3 = 7;
  KDF_X942KDF_ASN1 = 8;
  KDF_X942KDF_CONCAT = 9;
  KDF_X963KDF = 10;

type
  // 前向声明
  PEVP_KDF = ^EVP_KDF;
  PEVP_KDF_CTX = ^EVP_KDF_CTX;
  POSSL_PARAM = ^OSSL_PARAM;
  POSSL_LIB_CTX = ^OSSL_LIB_CTX;
  
  // 不透明结构体
  EVP_KDF = record end;
  EVP_KDF_CTX = record end;
  OSSL_PARAM = record end;
  OSSL_LIB_CTX = record end;
  
  // KDF 参数结构
  TKDF_PBKDF2_PARAMS = record
    Pass: PByte;
    PassLen: Integer;
    Salt: PByte;
    SaltLen: Integer;
    Iter: Integer;
    MD: PEVP_MD;
  end;
  PKDF_PBKDF2_PARAMS = ^TKDF_PBKDF2_PARAMS;
  
  TKDF_SCRYPT_PARAMS = record
    Pass: PByte;
    PassLen: Integer;
    Salt: PByte;
    SaltLen: Integer;
    N: UInt64;
    R: UInt32;
    P: UInt32;
    MaxMem: UInt64;
  end;
  PKDF_SCRYPT_PARAMS = ^TKDF_SCRYPT_PARAMS;
  
  TKDF_HKDF_PARAMS = record
    Mode: Integer;
    MD: PEVP_MD;
    Salt: PByte;
    SaltLen: Integer;
    Key: PByte;
    KeyLen: Integer;
    Info: PByte;
    InfoLen: Integer;
  end;
  PKDF_HKDF_PARAMS = ^TKDF_HKDF_PARAMS;
  
  // 函数指针类型
  
  // PBKDF2 函数
  TPKCS5_PBKDF2_HMAC = function(pass: PAnsiChar; passlen: Integer;
                                salt: PByte; saltlen: Integer;
                                iter: Integer; digest: PEVP_MD;
                                keylen: Integer; outkey: PByte): Integer; cdecl;
  TPKCS5_PBKDF2_HMAC_SHA1 = function(pass: PAnsiChar; passlen: Integer;
                                      salt: PByte; saltlen: Integer;
                                      iter: Integer; keylen: Integer;
                                      outkey: PByte): Integer; cdecl;
  
  // scrypt 函数
  TEVP_PBE_scrypt = function(pass: PAnsiChar; passlen: NativeUInt;
                            salt: PByte; saltlen: NativeUInt;
                            N: UInt64; r: UInt64; p: UInt64;
                            maxmem: UInt64; key: PByte;
                            keylen: NativeUInt): Integer; cdecl;
  
  // HKDF 函数  
  TEVP_PKEY_CTX_hkdf_mode = function(ctx: PEVP_PKEY_CTX; mode: Integer): Integer; cdecl;
  TEVP_PKEY_CTX_set_hkdf_md = function(ctx: PEVP_PKEY_CTX; md: PEVP_MD): Integer; cdecl;
  TEVP_PKEY_CTX_set1_hkdf_salt = function(ctx: PEVP_PKEY_CTX; salt: PByte;
                                          saltlen: Integer): Integer; cdecl;
  TEVP_PKEY_CTX_set1_hkdf_key = function(ctx: PEVP_PKEY_CTX; key: PByte;
                                        keylen: Integer): Integer; cdecl;
  TEVP_PKEY_CTX_add1_hkdf_info = function(ctx: PEVP_PKEY_CTX; info: PByte;
                                          infolen: Integer): Integer; cdecl;
  
  // TLS1 PRF 函数
  TEVP_PKEY_CTX_set_tls1_prf_md = function(ctx: PEVP_PKEY_CTX; md: PEVP_MD): Integer; cdecl;
  TEVP_PKEY_CTX_set1_tls1_prf_secret = function(ctx: PEVP_PKEY_CTX; sec: PByte;
                                                seclen: Integer): Integer; cdecl;
  TEVP_PKEY_CTX_add1_tls1_prf_seed = function(ctx: PEVP_PKEY_CTX; seed: PByte;
                                              seedlen: Integer): Integer; cdecl;
  
  // EVP KDF 函数 (OpenSSL 3.0+)
  TEVP_KDF_fetch = function(libctx: POSSL_LIB_CTX; algorithm: PAnsiChar;
                          properties: PAnsiChar): PEVP_KDF; cdecl;
  TEVP_KDF_free = procedure(kdf: PEVP_KDF); cdecl;
  TEVP_KDF_up_ref = function(kdf: PEVP_KDF): Integer; cdecl;
  TEVP_KDF_CTX_new = function(kdf: PEVP_KDF): PEVP_KDF_CTX; cdecl;
  TEVP_KDF_CTX_free = procedure(ctx: PEVP_KDF_CTX); cdecl;
  TEVP_KDF_CTX_dup = function(ctx: PEVP_KDF_CTX): PEVP_KDF_CTX; cdecl;
  TEVP_KDF_CTX_reset = procedure(ctx: PEVP_KDF_CTX); cdecl;
  TEVP_KDF_CTX_get_kdf_size = function(ctx: PEVP_KDF_CTX): NativeUInt; cdecl;
  TEVP_KDF_derive = function(ctx: PEVP_KDF_CTX; key: PByte; keylen: NativeUInt;
                            params: POSSL_PARAM): Integer; cdecl;
  TEVP_KDF_CTX_set_params = function(ctx: PEVP_KDF_CTX; params: POSSL_PARAM): Integer; cdecl;
  TEVP_KDF_CTX_get_params = function(ctx: PEVP_KDF_CTX; params: POSSL_PARAM): Integer; cdecl;
  TEVP_KDF_gettable_ctx_params = function(kdf: PEVP_KDF): POSSL_PARAM; cdecl;
  TEVP_KDF_settable_ctx_params = function(kdf: PEVP_KDF): POSSL_PARAM; cdecl;
  TEVP_KDF_get0_provider = function(kdf: PEVP_KDF): Pointer; cdecl;
  TEVP_KDF_get0_name = function(kdf: PEVP_KDF): PAnsiChar; cdecl;
  TEVP_KDF_get0_description = function(kdf: PEVP_KDF): PAnsiChar; cdecl;
  TEVP_KDF_is_a = function(kdf: PEVP_KDF; name: PAnsiChar): Integer; cdecl;
  TEVP_KDF_do_all_provided = procedure(libctx: POSSL_LIB_CTX;
                                      fn: Pointer; arg: Pointer); cdecl;
  TEVP_KDF_names_do_all = procedure(kdf: PEVP_KDF; fn: Pointer; data: Pointer); cdecl;
  
  // 旧版 PKCS5 函数
  TEVP_BytesToKey = function(cipher_type: PEVP_CIPHER; md: PEVP_MD;
                            salt: PByte; data: PByte; datal: Integer;
                            count: Integer; key: PByte; iv: PByte): Integer; cdecl;
  TPKCS5_v2_PBE_keyivgen = function(ctx: PEVP_CIPHER_CTX; pass: PAnsiChar;
                                  passlen: Integer; param: PASN1_TYPE;
                                  cipher: PEVP_CIPHER; md: PEVP_MD;
                                  en_de: Integer): Integer; cdecl;
  TPKCS5_v2_PBKDF2_keyivgen = function(ctx: PEVP_CIPHER_CTX; pass: PAnsiChar;
                                      passlen: Integer; param: PASN1_TYPE;
                                      cipher: PEVP_CIPHER; md: PEVP_MD;
                                      en_de: Integer): Integer; cdecl;
  TPKCS5_v2_scrypt_keyivgen = function(ctx: PEVP_CIPHER_CTX; pass: PAnsiChar;
                                      passlen: Integer; param: PASN1_TYPE;
                                      cipher: PEVP_CIPHER; md: PEVP_MD;
                                      en_de: Integer): Integer; cdecl;
  TPKCS5_PBE_keyivgen = function(ctx: PEVP_CIPHER_CTX; pass: PAnsiChar;
                                passlen: Integer; param: PASN1_TYPE;
                                cipher: PEVP_CIPHER; md: PEVP_MD;
                                en_de: Integer): Integer; cdecl;
  TPKCS5_PBE_add = function(): Integer; cdecl;
  
  // 密钥派生辅助函数
  // Note: EVP_KDF_ctrl uses varargs and cannot be directly mapped to Pascal
  TEVP_KDF_vctrl = function(ctx: PEVP_KDF_CTX; cmd: Integer; args: Pointer): Integer; cdecl;
  TEVP_KDF_ctrl_str = function(ctx: PEVP_KDF_CTX; typ: PAnsiChar;
                              value: PAnsiChar): Integer; cdecl;
  TEVP_KDF_size = function(ctx: PEVP_KDF_CTX): NativeUInt; cdecl;

var
  // PBKDF2 函数
  PKCS5_PBKDF2_HMAC: TPKCS5_PBKDF2_HMAC;
  PKCS5_PBKDF2_HMAC_SHA1: TPKCS5_PBKDF2_HMAC_SHA1;
  
  // scrypt 函数
  EVP_PBE_scrypt: TEVP_PBE_scrypt;
  
  // HKDF 函数
  EVP_PKEY_CTX_hkdf_mode: TEVP_PKEY_CTX_hkdf_mode;
  EVP_PKEY_CTX_set_hkdf_md: TEVP_PKEY_CTX_set_hkdf_md;
  EVP_PKEY_CTX_set1_hkdf_salt: TEVP_PKEY_CTX_set1_hkdf_salt;
  EVP_PKEY_CTX_set1_hkdf_key: TEVP_PKEY_CTX_set1_hkdf_key;
  EVP_PKEY_CTX_add1_hkdf_info: TEVP_PKEY_CTX_add1_hkdf_info;
  
  // TLS1 PRF 函数
  EVP_PKEY_CTX_set_tls1_prf_md: TEVP_PKEY_CTX_set_tls1_prf_md;
  EVP_PKEY_CTX_set1_tls1_prf_secret: TEVP_PKEY_CTX_set1_tls1_prf_secret;
  EVP_PKEY_CTX_add1_tls1_prf_seed: TEVP_PKEY_CTX_add1_tls1_prf_seed;
  
  // EVP KDF 函数 (OpenSSL 3.0+)
  EVP_KDF_fetch: TEVP_KDF_fetch;
  EVP_KDF_free: TEVP_KDF_free;
  EVP_KDF_up_ref: TEVP_KDF_up_ref;
  EVP_KDF_CTX_new: TEVP_KDF_CTX_new;
  EVP_KDF_CTX_free: TEVP_KDF_CTX_free;
  EVP_KDF_CTX_dup: TEVP_KDF_CTX_dup;
  EVP_KDF_CTX_reset: TEVP_KDF_CTX_reset;
  EVP_KDF_CTX_get_kdf_size: TEVP_KDF_CTX_get_kdf_size;
  EVP_KDF_derive: TEVP_KDF_derive;
  EVP_KDF_CTX_set_params: TEVP_KDF_CTX_set_params;
  EVP_KDF_CTX_get_params: TEVP_KDF_CTX_get_params;
  EVP_KDF_gettable_ctx_params: TEVP_KDF_gettable_ctx_params;
  EVP_KDF_settable_ctx_params: TEVP_KDF_settable_ctx_params;
  EVP_KDF_get0_provider: TEVP_KDF_get0_provider;
  EVP_KDF_get0_name: TEVP_KDF_get0_name;
  EVP_KDF_get0_description: TEVP_KDF_get0_description;
  EVP_KDF_is_a: TEVP_KDF_is_a;
  EVP_KDF_do_all_provided: TEVP_KDF_do_all_provided;
  EVP_KDF_names_do_all: TEVP_KDF_names_do_all;
  
  // 旧版 PKCS5 函数
  EVP_BytesToKey: TEVP_BytesToKey;
  PKCS5_v2_PBE_keyivgen: TPKCS5_v2_PBE_keyivgen;
  PKCS5_v2_PBKDF2_keyivgen: TPKCS5_v2_PBKDF2_keyivgen;
  PKCS5_v2_scrypt_keyivgen: TPKCS5_v2_scrypt_keyivgen;
  PKCS5_PBE_keyivgen: TPKCS5_PBE_keyivgen;
  PKCS5_PBE_add: TPKCS5_PBE_add;
  
  // 密钥派生辅助函数
  EVP_KDF_vctrl: TEVP_KDF_vctrl;
  EVP_KDF_ctrl_str: TEVP_KDF_ctrl_str;
  EVP_KDF_size: TEVP_KDF_size;

procedure LoadKDFFunctions;
procedure UnloadKDFFunctions;

// 辅助函数
function DeriveKeyPBKDF2(const Password: string; const Salt: TBytes;
                        Iterations: Integer; KeyLen: Integer;
                        MD: PEVP_MD = nil): TBytes;
function DeriveKeyScrypt(const Password: string; const Salt: TBytes;
                        N: UInt64 = SCRYPT_DEFAULT_N; R: UInt32 = SCRYPT_DEFAULT_R;
                        P: UInt32 = SCRYPT_DEFAULT_P; KeyLen: Integer = 32;
                        MaxMem: UInt64 = SCRYPT_DEFAULT_MAXMEM): TBytes;
function DeriveKeyHKDF(const Key: TBytes; const Salt: TBytes; const Info: TBytes;
                      KeyLen: Integer; MD: PEVP_MD = nil): TBytes;
function GenerateSalt(Len: Integer = PKCS5_SALT_LEN): TBytes;

implementation

uses
  nextpas.core.tls.openssl.api.rand,
  nextpas.core.tls.openssl.loader;

procedure LoadKDFFunctions;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmKDF) then Exit;
  if GetCryptoLibHandle = 0 then Exit;
  
  // PBKDF2 函数
  PKCS5_PBKDF2_HMAC := TPKCS5_PBKDF2_HMAC(GetCryptoProcAddress('PKCS5_PBKDF2_HMAC'));
  PKCS5_PBKDF2_HMAC_SHA1 := TPKCS5_PBKDF2_HMAC_SHA1(GetCryptoProcAddress('PKCS5_PBKDF2_HMAC_SHA1'));
  
  // scrypt 函数
  EVP_PBE_scrypt := TEVP_PBE_scrypt(GetCryptoProcAddress('EVP_PBE_scrypt'));
  
  // HKDF 函数
  EVP_PKEY_CTX_hkdf_mode := TEVP_PKEY_CTX_hkdf_mode(GetCryptoProcAddress('EVP_PKEY_CTX_hkdf_mode'));
  EVP_PKEY_CTX_set_hkdf_md := TEVP_PKEY_CTX_set_hkdf_md(GetCryptoProcAddress('EVP_PKEY_CTX_set_hkdf_md'));
  EVP_PKEY_CTX_set1_hkdf_salt := TEVP_PKEY_CTX_set1_hkdf_salt(GetCryptoProcAddress('EVP_PKEY_CTX_set1_hkdf_salt'));
  EVP_PKEY_CTX_set1_hkdf_key := TEVP_PKEY_CTX_set1_hkdf_key(GetCryptoProcAddress('EVP_PKEY_CTX_set1_hkdf_key'));
  EVP_PKEY_CTX_add1_hkdf_info := TEVP_PKEY_CTX_add1_hkdf_info(GetCryptoProcAddress('EVP_PKEY_CTX_add1_hkdf_info'));
  
  // TLS1 PRF 函数
  EVP_PKEY_CTX_set_tls1_prf_md := TEVP_PKEY_CTX_set_tls1_prf_md(GetCryptoProcAddress('EVP_PKEY_CTX_set_tls1_prf_md'));
  EVP_PKEY_CTX_set1_tls1_prf_secret := TEVP_PKEY_CTX_set1_tls1_prf_secret(GetCryptoProcAddress('EVP_PKEY_CTX_set1_tls1_prf_secret'));
  EVP_PKEY_CTX_add1_tls1_prf_seed := TEVP_PKEY_CTX_add1_tls1_prf_seed(GetCryptoProcAddress('EVP_PKEY_CTX_add1_tls1_prf_seed'));
  
  // EVP KDF 函数 (OpenSSL 3.0+)
  EVP_KDF_fetch := TEVP_KDF_fetch(GetCryptoProcAddress('EVP_KDF_fetch'));
  EVP_KDF_free := TEVP_KDF_free(GetCryptoProcAddress('EVP_KDF_free'));
  EVP_KDF_CTX_new := TEVP_KDF_CTX_new(GetCryptoProcAddress('EVP_KDF_CTX_new'));
  EVP_KDF_CTX_free := TEVP_KDF_CTX_free(GetCryptoProcAddress('EVP_KDF_CTX_free'));
  EVP_KDF_CTX_reset := TEVP_KDF_CTX_reset(GetCryptoProcAddress('EVP_KDF_CTX_reset'));
  EVP_KDF_derive := TEVP_KDF_derive(GetCryptoProcAddress('EVP_KDF_derive'));
  EVP_KDF_CTX_set_params := TEVP_KDF_CTX_set_params(GetCryptoProcAddress('EVP_KDF_CTX_set_params'));
  EVP_KDF_CTX_get_kdf_size := TEVP_KDF_CTX_get_kdf_size(GetCryptoProcAddress('EVP_KDF_CTX_get_kdf_size'));
  
  // 旧版 PKCS5 函数
  EVP_BytesToKey := TEVP_BytesToKey(GetCryptoProcAddress('EVP_BytesToKey'));
  PKCS5_v2_PBE_keyivgen := TPKCS5_v2_PBE_keyivgen(GetCryptoProcAddress('PKCS5_v2_PBE_keyivgen'));
  PKCS5_v2_PBKDF2_keyivgen := TPKCS5_v2_PBKDF2_keyivgen(GetCryptoProcAddress('PKCS5_v2_PBKDF2_keyivgen'));
  PKCS5_v2_scrypt_keyivgen := TPKCS5_v2_scrypt_keyivgen(GetCryptoProcAddress('PKCS5_v2_scrypt_keyivgen'));
  PKCS5_PBE_keyivgen := TPKCS5_PBE_keyivgen(GetCryptoProcAddress('PKCS5_PBE_keyivgen'));
  PKCS5_PBE_add := TPKCS5_PBE_add(GetCryptoProcAddress('PKCS5_PBE_add'));

  TOpenSSLLoader.SetModuleLoaded(osmKDF, True);
end;

procedure UnloadKDFFunctions;
begin
  // 重置所有函数指针
  PKCS5_PBKDF2_HMAC := nil;
  PKCS5_PBKDF2_HMAC_SHA1 := nil;
  EVP_PBE_scrypt := nil;
  EVP_PKEY_CTX_hkdf_mode := nil;
  EVP_PKEY_CTX_set_hkdf_md := nil;
  EVP_PKEY_CTX_set1_hkdf_salt := nil;
  EVP_PKEY_CTX_set1_hkdf_key := nil;
  EVP_PKEY_CTX_add1_hkdf_info := nil;
  EVP_PKEY_CTX_set_tls1_prf_md := nil;
  EVP_PKEY_CTX_set1_tls1_prf_secret := nil;
  EVP_PKEY_CTX_add1_tls1_prf_seed := nil;
  EVP_KDF_fetch := nil;
  EVP_KDF_free := nil;
  EVP_KDF_CTX_new := nil;
  EVP_KDF_CTX_free := nil;
  EVP_KDF_CTX_reset := nil;
  EVP_KDF_derive := nil;
  EVP_BytesToKey := nil;

  TOpenSSLLoader.SetModuleLoaded(osmKDF, False);
end;

function DeriveKeyPBKDF2(const Password: string; const Salt: TBytes;
                        Iterations: Integer; KeyLen: Integer;
                        MD: PEVP_MD): TBytes;
var
  PassAnsi: AnsiString;
  OutKey: TBytes;
begin
  Result := nil;  // Initialize result
  SetLength(Result, 0);
  
  if not Assigned(PKCS5_PBKDF2_HMAC) then Exit;
  if KeyLen <= 0 then Exit;
  
  PassAnsi := AnsiString(Password);
  SetLength(OutKey, KeyLen);
  
  // 如果没有指定摘要算法，使用 SHA-256
  if MD = nil then
  begin
    if Assigned(EVP_sha256) then
      MD := EVP_sha256();
  end;
  
  if MD = nil then
  begin
    // 如果还是没有，尝试使用 SHA1
    if Assigned(PKCS5_PBKDF2_HMAC_SHA1) then
    begin
      if PKCS5_PBKDF2_HMAC_SHA1(PAnsiChar(PassAnsi), Length(PassAnsi),
                                @Salt[0], Length(Salt),
                                Iterations, KeyLen, @OutKey[0]) = 1 then
        Result := OutKey;
      Exit;
    end;
  end;
  
  // 使用指定的摘要算法
  if PKCS5_PBKDF2_HMAC(PAnsiChar(PassAnsi), Length(PassAnsi),
                      @Salt[0], Length(Salt),
                      Iterations, MD, KeyLen, @OutKey[0]) = 1 then
    Result := OutKey;
end;

function DeriveKeyScrypt(const Password: string; const Salt: TBytes;
                        N: UInt64; R: UInt32; P: UInt32; KeyLen: Integer;
                        MaxMem: UInt64): TBytes;
var
  PassAnsi: AnsiString;
  OutKey: TBytes;
begin
  Result := nil;  // Initialize result
  SetLength(Result, 0);
  
  if not Assigned(EVP_PBE_scrypt) then Exit;
  if KeyLen <= 0 then Exit;
  
  PassAnsi := AnsiString(Password);
  SetLength(OutKey, KeyLen);
  
  if EVP_PBE_scrypt(PAnsiChar(PassAnsi), Length(PassAnsi),
                    @Salt[0], Length(Salt),
                    N, R, P, MaxMem,
                    @OutKey[0], KeyLen) = 1 then
    Result := OutKey;
end;

function DeriveKeyHKDF(const Key: TBytes; const Salt: TBytes; const Info: TBytes;
                      KeyLen: Integer; MD: PEVP_MD): TBytes;
var
  PRK: array[0..EVP_MAX_MD_SIZE-1] of Byte;
  PRKLen: Cardinal;
  OKM: TBytes;
  N, I, Offset: Integer;
  T: TBytes;
  Counter: Byte;
  HMACResult: PByte;
  HMACLen: Cardinal;
  MDSize: Integer;
  OutKey: TBytes;
  KeyPtr, SaltPtr, TPtr: PByte;
begin
  Result := nil;  // Initialize result
  SetLength(Result, 0);
  
  if KeyLen <= 0 then
    Exit;
  
  if Length(Key) = 0 then
    Exit;
  
  // Use SHA-256 as default if not specified
  if MD = nil then
  begin
    if Assigned(EVP_sha256) then
      MD := EVP_sha256()
    else
      Exit;
  end;
  
  // Manual HKDF implementation using HMAC (RFC 5869)
  // This works across all OpenSSL versions
  if not Assigned(HMAC) then
    Exit;
  
  MDSize := EVP_MD_size(MD);
  if MDSize <= 0 then
    Exit;
  
  // HKDF-Extract: PRK = HMAC-Hash(salt, IKM)
  PRKLen := 0;
  KeyPtr := @Key[0];
  
  if Length(Salt) > 0 then
  begin
    SaltPtr := @Salt[0];
    HMACResult := HMAC(MD, SaltPtr, Length(Salt), KeyPtr, Length(Key), @PRK[0], @PRKLen);
  end
  else
  begin
    // If salt is not provided, use a string of HashLen zeros
    SetLength(T, MDSize);
    FillChar(T[0], MDSize, 0);
    HMACResult := HMAC(MD, @T[0], MDSize, KeyPtr, Length(Key), @PRK[0], @PRKLen);
  end;
  
  if (HMACResult = nil) or (PRKLen = 0) then
    Exit;
  
  // HKDF-Expand: OKM = T(1) | T(2) | ... | T(N)
  // T(0) = empty string
  // T(i) = HMAC-Hash(PRK, T(i-1) | info | 0x<i>)
  N := (KeyLen + MDSize - 1) div MDSize;  // Ceiling division
  SetLength(OKM, 0);
  SetLength(T, 0);
  
  for I := 1 to N do
  begin
    Counter := I;
    
    // Build input: T(i-1) | info | counter
    Offset := Length(T);
    SetLength(T, Offset + Length(Info) + 1);
    if Length(Info) > 0 then
      Move(Info[0], T[Offset], Length(Info));
    T[Length(T) - 1] := Counter;
    
    // Compute HMAC
    HMACLen := 0;
    SetLength(OutKey, MDSize);
    TPtr := @T[0];
    HMACResult := HMAC(MD, @PRK[0], PRKLen, TPtr, Length(T), @OutKey[0], @HMACLen);
    
    if (HMACResult = nil) or (HMACLen = 0) then
    begin
      SetLength(Result, 0);
      Exit;
    end;
    
    // T = HMAC result for next iteration
    SetLength(T, HMACLen);
    Move(OutKey[0], T[0], HMACLen);
    
    // Append to OKM
    Offset := Length(OKM);
    SetLength(OKM, Offset + HMACLen);
    Move(OutKey[0], OKM[Offset], HMACLen);
  end;
  
  // Return first KeyLen bytes
  SetLength(Result, KeyLen);
  Move(OKM[0], Result[0], KeyLen);
end;

function GenerateSalt(Len: Integer): TBytes;
var
  I: Integer;
begin
  Result := nil;  // Initialize result
  SetLength(Result, Len);
  
  // 使用 RAND 模块生成随机盐
  if Assigned(RAND_bytes) then
  begin
    if RAND_bytes(@Result[0], Len) <> 1 then
      SetLength(Result, 0);
  end
  else
  begin
    // 后备方案：使用系统随机数
    Randomize;
    for I := 0 to Len - 1 do
      Result[I] := Random(256);
  end;
end;

initialization
  
finalization
  UnloadKDFFunctions;
  
end.