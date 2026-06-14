unit nextpas.core.tls.openssl.api.legacy_ciphers;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.tls.openssl.base; type // RC2 types RC2_KEY = packed record data: array[0..63] of Cardinal;
  end;
  PRC2_KEY = ^RC2_KEY;
  
  // RC4 types  
  RC4_KEY = packed record
    x, y: Cardinal;
    data: array[0..255] of Cardinal;
  end;
  PRC4_KEY = ^RC4_KEY;
  
  // RC5 types
  RC5_32_KEY = packed record
    rounds: Cardinal;
    data: array[0..33] of Cardinal;
  end;
  PRC5_32_KEY = ^RC5_32_KEY;
  
  // IDEA types
  IDEA_KEY_SCHEDULE = packed record
    data: array[0..8, 0..5] of Word;
  end;
  PIDEA_KEY_SCHEDULE = ^IDEA_KEY_SCHEDULE;
  
  // CAMELLIA types
  CAMELLIA_KEY = packed record
    rd_key: array[0..67] of Cardinal;
    grand_rounds: Integer;
  end;
  PCAMELLIA_KEY = ^CAMELLIA_KEY;
  
  // BLOWFISH types
  BF_KEY = packed record
    P: array[0..17] of Cardinal;
    S: array[0..3, 0..255] of Cardinal;
  end;
  PBF_KEY = ^BF_KEY;
  
  // CAST5 types
  CAST_KEY = packed record
    data: array[0..31] of Cardinal;
    short_key: Integer;
  end;
  PCAST_KEY = ^CAST_KEY;
  
  // MDC2 types
  MDC2_CTX = packed record
    num: Cardinal;
    data: array[0..7] of Byte;
    h, hh: array[0..7] of Cardinal;
    pad_type: Integer;
  end;
  PMDC2_CTX = ^MDC2_CTX;
  
  // RIPEMD types
  RIPEMD160_CTX = packed record
    A, B, C, D, E: Cardinal;
    Nl, Nh: Cardinal;
    data: array[0..15] of Cardinal;
    num: Cardinal;
  end;
  PRIPEMD160_CTX = ^RIPEMD160_CTX;

const
  // Block sizes
  RC2_BLOCK = 8;
  RC2_KEY_LENGTH = 16;
  RC5_BLOCK = 8;
  IDEA_BLOCK = 8;
  IDEA_KEY_LENGTH = 16;
  CAMELLIA_BLOCK_SIZE = 16;
  CAMELLIA_KEY_LENGTH_128 = 16;
  CAMELLIA_KEY_LENGTH_192 = 24;
  CAMELLIA_KEY_LENGTH_256 = 32;
  BF_BLOCK = 8;
  CAST_BLOCK = 8;
  MDC2_BLOCK = 8;
  MDC2_DIGEST_LENGTH = 16;
  RIPEMD160_DIGEST_LENGTH = 20;
  
  // Encrypt/Decrypt flags
  RC2_ENCRYPT = 1;
  RC2_DECRYPT = 0;
  BF_ENCRYPT = 1;
  BF_DECRYPT = 0;
  CAST_ENCRYPT = 1;
  CAST_DECRYPT = 0;
  CAMELLIA_ENCRYPT = 1;
  CAMELLIA_DECRYPT = 0;

type
  // RC2 function types
  TRC2_set_key = procedure(key: PRC2_KEY; len: Integer; const data: PByte; bits: Integer); cdecl;
  TRC2_ecb_encrypt = procedure(const input: PByte; output: PByte; key: PRC2_KEY; enc: Integer); cdecl;
  TRC2_cbc_encrypt = procedure(const input: PByte; output: PByte; length: LongInt; 
    ks: PRC2_KEY; ivec: PByte; enc: Integer); cdecl;
  TRC2_cfb64_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PRC2_KEY; ivec: PByte; num: PInteger; enc: Integer); cdecl;
  TRC2_ofb64_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PRC2_KEY; ivec: PByte; num: PInteger); cdecl;
    
  // RC4 function types
  TRC4_set_key = procedure(key: PRC4_KEY; len: Integer; const data: PByte); cdecl;
  TRC4 = procedure(key: PRC4_KEY; len: NativeUInt; const input: PByte; output: PByte); cdecl;
  TRC4_options = function(): PAnsiChar; cdecl;
  
  // RC5 function types
  TRC5_32_set_key = procedure(key: PRC5_32_KEY; len: Integer; const data: PByte; rounds: Integer); cdecl;
  TRC5_32_ecb_encrypt = procedure(const input: PByte; output: PByte; key: PRC5_32_KEY; enc: Integer); cdecl;
  TRC5_32_cbc_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
    ks: PRC5_32_KEY; ivec: PByte; enc: Integer); cdecl;
  TRC5_32_cfb64_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PRC5_32_KEY; ivec: PByte; num: PInteger; enc: Integer); cdecl;
  TRC5_32_ofb64_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PRC5_32_KEY; ivec: PByte; num: PInteger); cdecl;
    
  // IDEA function types
  TIDEA_set_encrypt_key = procedure(const key: PByte; ks: PIDEA_KEY_SCHEDULE); cdecl;
  TIDEA_set_decrypt_key = procedure(ek: PIDEA_KEY_SCHEDULE; dk: PIDEA_KEY_SCHEDULE); cdecl;
  TIDEA_ecb_encrypt = procedure(const input: PByte; output: PByte; ks: PIDEA_KEY_SCHEDULE); cdecl;
  TIDEA_cbc_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
    ks: PIDEA_KEY_SCHEDULE; ivec: PByte; enc: Integer); cdecl;
  TIDEA_cfb64_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
    ks: PIDEA_KEY_SCHEDULE; ivec: PByte; num: PInteger; enc: Integer); cdecl;
  TIDEA_ofb64_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
    ks: PIDEA_KEY_SCHEDULE; ivec: PByte; num: PInteger); cdecl;
  
  // Function pointer types for Camellia
  TCamellia_set_key = function(const userKey: PByte; const bits: Integer;
    key: PCAMELLIA_KEY): Integer; cdecl;
  TCamellia_encrypt_func = procedure(const input: PByte; output: PByte;
    const key: PCAMELLIA_KEY); cdecl;
  TCamellia_decrypt_func = procedure(const input: PByte; output: PByte;
    const key: PCAMELLIA_KEY); cdecl;
  TCamellia_ecb_encrypt = procedure(const input: PByte; output: PByte;
    const key: PCAMELLIA_KEY; const enc: Integer); cdecl;
  TCamellia_cbc_encrypt = procedure(const input: PByte; output: PByte; length: NativeUInt;
    const key: PCAMELLIA_KEY; ivec: PByte; const enc: Integer); cdecl;
  TCamellia_cfb_encrypt = procedure(const input: PByte; output: PByte; length: NativeUInt;
    const key: PCAMELLIA_KEY; ivec: PByte; num: PInteger; const enc: Integer); cdecl;
  TCamellia_ofb_encrypt = procedure(const input: PByte; output: PByte; length: NativeUInt;
    const key: PCAMELLIA_KEY; ivec: PByte; num: PInteger); cdecl;
  TCamellia_ctr_encrypt = procedure(const input: PByte; output: PByte; length: NativeUInt;
    const key: PCAMELLIA_KEY; ivec: PByte; ecount_buf: PByte; num: PCardinal); cdecl;
    
  // BLOWFISH function types
  TBF_set_key = procedure(key: PBF_KEY; len: Integer; const data: PByte); cdecl;
  TBF_encrypt = procedure(data: PCardinal; const key: PBF_KEY); cdecl;
  TBF_decrypt = procedure(data: PCardinal; const key: PBF_KEY); cdecl;
  TBF_ecb_encrypt = procedure(const input: PByte; output: PByte; key: PBF_KEY; enc: Integer); cdecl;
  TBF_cbc_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PBF_KEY; ivec: PByte; enc: Integer); cdecl;
  TBF_cfb64_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PBF_KEY; ivec: PByte; num: PInteger; enc: Integer); cdecl;
  TBF_ofb64_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PBF_KEY; ivec: PByte; num: PInteger); cdecl;
    
  // CAST5 function types
  TCAST_set_key = procedure(key: PCAST_KEY; len: Integer; const data: PByte); cdecl;
  TCAST_ecb_encrypt = procedure(const input: PByte; output: PByte; key: PCAST_KEY; enc: Integer); cdecl;
  TCAST_encrypt = procedure(data: PCardinal; const key: PCAST_KEY); cdecl;
  TCAST_decrypt = procedure(data: PCardinal; const key: PCAST_KEY); cdecl;
  TCAST_cbc_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
    ks: PCAST_KEY; ivec: PByte; enc: Integer); cdecl;
  TCAST_cfb64_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PCAST_KEY; ivec: PByte; num: PInteger; enc: Integer); cdecl;
  TCAST_ofb64_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PCAST_KEY; ivec: PByte; num: PInteger); cdecl;
    
  // MDC2 function types
  TMDC2_Init = function(c: PMDC2_CTX): Integer; cdecl;
  TMDC2_Update = function(c: PMDC2_CTX; const data: Pointer; len: NativeUInt): Integer; cdecl;
  TMDC2_Final = function(md: PByte; c: PMDC2_CTX): Integer; cdecl;
  TMDC2 = function(const d: PByte; n: NativeUInt; md: PByte): PByte; cdecl;
  
  // RIPEMD function types
  TRIPEMD160_Init = function(c: PRIPEMD160_CTX): Integer; cdecl;
  TRIPEMD160_Update = function(c: PRIPEMD160_CTX; const data: Pointer; len: NativeUInt): Integer; cdecl;
  TRIPEMD160_Final = function(md: PByte; c: PRIPEMD160_CTX): Integer; cdecl;
  TRIPEMD160 = function(const d: PByte; n: NativeUInt; md: PByte): PByte; cdecl;
  TRIPEMD160_Transform = procedure(c: PRIPEMD160_CTX; const data: PByte); cdecl;
  
  // EVP function types
  TEVP_CIPHER = function(): PEVP_CIPHER; cdecl;
  TEVP_MD = function(): PEVP_MD; cdecl;

var
  // RC2 functions
  RC2_set_key: procedure(key: PRC2_KEY; len: Integer; const data: PByte; bits: Integer); cdecl = nil;
  RC2_ecb_encrypt: procedure(const input: PByte; output: PByte; key: PRC2_KEY; enc: Integer); cdecl = nil;
  RC2_cbc_encrypt: procedure(const input: PByte; output: PByte; length: LongInt; 
    ks: PRC2_KEY; ivec: PByte; enc: Integer); cdecl = nil;
  RC2_cfb64_encrypt: procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PRC2_KEY; ivec: PByte; num: PInteger; enc: Integer); cdecl = nil;
  RC2_ofb64_encrypt: procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PRC2_KEY; ivec: PByte; num: PInteger); cdecl = nil;
    
  // RC4 functions
  RC4_set_key: procedure(key: PRC4_KEY; len: Integer; const data: PByte); cdecl = nil;
  RC4: procedure(key: PRC4_KEY; len: NativeUInt; const input: PByte; output: PByte); cdecl = nil;
  RC4_options: function(): PAnsiChar; cdecl = nil;
  
  // RC5 functions
  RC5_32_set_key: procedure(key: PRC5_32_KEY; len: Integer; const data: PByte; rounds: Integer); cdecl = nil;
  RC5_32_ecb_encrypt: procedure(const input: PByte; output: PByte; key: PRC5_32_KEY; enc: Integer); cdecl = nil;
  RC5_32_cbc_encrypt: procedure(const input: PByte; output: PByte; length: LongInt;
    ks: PRC5_32_KEY; ivec: PByte; enc: Integer); cdecl = nil;
  RC5_32_cfb64_encrypt: procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PRC5_32_KEY; ivec: PByte; num: PInteger; enc: Integer); cdecl = nil;
  RC5_32_ofb64_encrypt: procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PRC5_32_KEY; ivec: PByte; num: PInteger); cdecl = nil;
    
  // IDEA functions
  IDEA_set_encrypt_key: procedure(const key: PByte; ks: PIDEA_KEY_SCHEDULE); cdecl = nil;
  IDEA_set_decrypt_key: procedure(ek: PIDEA_KEY_SCHEDULE; dk: PIDEA_KEY_SCHEDULE); cdecl = nil;
  IDEA_ecb_encrypt: procedure(const input: PByte; output: PByte; ks: PIDEA_KEY_SCHEDULE); cdecl = nil;
  IDEA_cbc_encrypt: procedure(const input: PByte; output: PByte; length: LongInt;
    ks: PIDEA_KEY_SCHEDULE; ivec: PByte; enc: Integer); cdecl = nil;
  IDEA_cfb64_encrypt: procedure(const input: PByte; output: PByte; length: LongInt;
    ks: PIDEA_KEY_SCHEDULE; ivec: PByte; num: PInteger; enc: Integer); cdecl = nil;
  IDEA_ofb64_encrypt: procedure(const input: PByte; output: PByte; length: LongInt;
    ks: PIDEA_KEY_SCHEDULE; ivec: PByte; num: PInteger); cdecl = nil;
    
  // CAMELLIA functions
  Camellia_set_key: TCamellia_set_key = nil;
  Camellia_encrypt_func: TCamellia_encrypt_func = nil;
  Camellia_decrypt_func: TCamellia_decrypt_func = nil;
  Camellia_ecb_encrypt: TCamellia_ecb_encrypt = nil;
  Camellia_cbc_encrypt: TCamellia_cbc_encrypt = nil;
  Camellia_cfb128_encrypt: TCamellia_cfb_encrypt = nil;
  Camellia_cfb1_encrypt: TCamellia_cfb_encrypt = nil;
  Camellia_cfb8_encrypt: TCamellia_cfb_encrypt = nil;
  Camellia_ofb128_encrypt: TCamellia_ofb_encrypt = nil;
  Camellia_ctr128_encrypt: TCamellia_ctr_encrypt = nil;
    
  // BLOWFISH functions
  BF_set_key: procedure(key: PBF_KEY; len: Integer; const data: PByte); cdecl = nil;
  BF_encrypt_func: procedure(data: PCardinal; const key: PBF_KEY); cdecl = nil;
  BF_decrypt_func: procedure(data: PCardinal; const key: PBF_KEY); cdecl = nil;
  BF_ecb_encrypt: procedure(const input: PByte; output: PByte; key: PBF_KEY; enc: Integer); cdecl = nil;
  BF_cbc_encrypt: procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PBF_KEY; ivec: PByte; enc: Integer); cdecl = nil;
  BF_cfb64_encrypt: procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PBF_KEY; ivec: PByte; num: PInteger; enc: Integer); cdecl = nil;
  BF_ofb64_encrypt: procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PBF_KEY; ivec: PByte; num: PInteger); cdecl = nil;
    
  // CAST5 functions
  CAST_set_key: procedure(key: PCAST_KEY; len: Integer; const data: PByte); cdecl = nil;
  CAST_ecb_encrypt: procedure(const input: PByte; output: PByte; key: PCAST_KEY; enc: Integer); cdecl = nil;
  CAST_encrypt_func: procedure(data: PCardinal; const key: PCAST_KEY); cdecl = nil;
  CAST_decrypt_func: procedure(data: PCardinal; const key: PCAST_KEY); cdecl = nil;
  CAST_cbc_encrypt: procedure(const input: PByte; output: PByte; length: LongInt;
    ks: PCAST_KEY; ivec: PByte; enc: Integer); cdecl = nil;
  CAST_cfb64_encrypt: procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PCAST_KEY; ivec: PByte; num: PInteger; enc: Integer); cdecl = nil;
  CAST_ofb64_encrypt: procedure(const input: PByte; output: PByte; length: LongInt;
    schedule: PCAST_KEY; ivec: PByte; num: PInteger); cdecl = nil;
    
  // MDC2 functions
  MDC2_Init: function(c: PMDC2_CTX): Integer; cdecl = nil;
  MDC2_Update: function(c: PMDC2_CTX; const data: Pointer; len: NativeUInt): Integer; cdecl = nil;
  MDC2_Final: function(md: PByte; c: PMDC2_CTX): Integer; cdecl = nil;
  MDC2: function(const d: PByte; n: NativeUInt; md: PByte): PByte; cdecl = nil;
  
  // RIPEMD functions
  RIPEMD160_Init: function(c: PRIPEMD160_CTX): Integer; cdecl = nil;
  RIPEMD160_Update: function(c: PRIPEMD160_CTX; const data: Pointer; len: NativeUInt): Integer; cdecl = nil;
  RIPEMD160_Final: function(md: PByte; c: PRIPEMD160_CTX): Integer; cdecl = nil;
  RIPEMD160: function(const d: PByte; n: NativeUInt; md: PByte): PByte; cdecl = nil;
  RIPEMD160_Transform: procedure(c: PRIPEMD160_CTX; const data: PByte); cdecl = nil;
  
  // EVP functions for legacy ciphers
  EVP_rc2_ecb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_rc2_cbc: function(): PEVP_CIPHER; cdecl = nil;
  EVP_rc2_40_cbc: function(): PEVP_CIPHER; cdecl = nil;
  EVP_rc2_64_cbc: function(): PEVP_CIPHER; cdecl = nil;
  EVP_rc2_cfb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_rc2_cfb64: function(): PEVP_CIPHER; cdecl = nil;
  EVP_rc2_ofb: function(): PEVP_CIPHER; cdecl = nil;
  
  EVP_rc4: function(): PEVP_CIPHER; cdecl = nil;
  EVP_rc4_40: function(): PEVP_CIPHER; cdecl = nil;
  EVP_rc4_hmac_md5: function(): PEVP_CIPHER; cdecl = nil;
  
  EVP_rc5_32_12_16_ecb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_rc5_32_12_16_cbc: function(): PEVP_CIPHER; cdecl = nil;
  EVP_rc5_32_12_16_cfb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_rc5_32_12_16_cfb64: function(): PEVP_CIPHER; cdecl = nil;
  EVP_rc5_32_12_16_ofb: function(): PEVP_CIPHER; cdecl = nil;
  
  EVP_idea_ecb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_idea_cbc: function(): PEVP_CIPHER; cdecl = nil;
  EVP_idea_cfb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_idea_cfb64: function(): PEVP_CIPHER; cdecl = nil;
  EVP_idea_ofb: function(): PEVP_CIPHER; cdecl = nil;
  
  EVP_camellia_128_ecb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_128_cbc: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_128_cfb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_128_cfb1: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_128_cfb8: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_128_cfb128: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_128_ofb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_128_ctr: function(): PEVP_CIPHER; cdecl = nil;
  
  EVP_camellia_192_ecb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_192_cbc: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_192_cfb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_192_cfb1: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_192_cfb8: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_192_cfb128: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_192_ofb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_192_ctr: function(): PEVP_CIPHER; cdecl = nil;
  
  EVP_camellia_256_ecb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_256_cbc: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_256_cfb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_256_cfb1: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_256_cfb8: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_256_cfb128: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_256_ofb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_camellia_256_ctr: function(): PEVP_CIPHER; cdecl = nil;
  
  EVP_bf_ecb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_bf_cbc: function(): PEVP_CIPHER; cdecl = nil;
  EVP_bf_cfb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_bf_cfb64: function(): PEVP_CIPHER; cdecl = nil;
  EVP_bf_ofb: function(): PEVP_CIPHER; cdecl = nil;
  
  EVP_cast5_ecb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_cast5_cbc: function(): PEVP_CIPHER; cdecl = nil;
  EVP_cast5_cfb: function(): PEVP_CIPHER; cdecl = nil;
  EVP_cast5_cfb64: function(): PEVP_CIPHER; cdecl = nil;
  EVP_cast5_ofb: function(): PEVP_CIPHER; cdecl = nil;
  
  EVP_mdc2: function(): PEVP_MD; cdecl = nil;
  EVP_ripemd160: function(): PEVP_MD; cdecl = nil;

procedure LoadLegacyCiphersFunctions(AHandle: TLibHandle);
procedure UnloadLegacyCiphersFunctions;

implementation

uses nextpas.core.tls.openssl.api.utils; procedure LoadLegacyCiphersFunctions(AHandle: TLibHandle);
begin
  if AHandle = 0 then Exit;
  
  // RC2 functions
  RC2_set_key := TRC2_set_key(GetProcedureAddress(AHandle, 'RC2_set_key'));
  RC2_ecb_encrypt := TRC2_ecb_encrypt(GetProcedureAddress(AHandle, 'RC2_ecb_encrypt'));
  RC2_cbc_encrypt := TRC2_cbc_encrypt(GetProcedureAddress(AHandle, 'RC2_cbc_encrypt'));
  RC2_cfb64_encrypt := TRC2_cfb64_encrypt(GetProcedureAddress(AHandle, 'RC2_cfb64_encrypt'));
  RC2_ofb64_encrypt := TRC2_ofb64_encrypt(GetProcedureAddress(AHandle, 'RC2_ofb64_encrypt'));
  
  // RC4 functions
  RC4_set_key := TRC4_set_key(GetProcedureAddress(AHandle, 'RC4_set_key'));
  RC4 := TRC4(GetProcedureAddress(AHandle, 'RC4'));
  RC4_options := TRC4_options(GetProcedureAddress(AHandle, 'RC4_options'));
  
  // RC5 functions
  RC5_32_set_key := TRC5_32_set_key(GetProcedureAddress(AHandle, 'RC5_32_set_key'));
  RC5_32_ecb_encrypt := TRC5_32_ecb_encrypt(GetProcedureAddress(AHandle, 'RC5_32_ecb_encrypt'));
  RC5_32_cbc_encrypt := TRC5_32_cbc_encrypt(GetProcedureAddress(AHandle, 'RC5_32_cbc_encrypt'));
  RC5_32_cfb64_encrypt := TRC5_32_cfb64_encrypt(GetProcedureAddress(AHandle, 'RC5_32_cfb64_encrypt'));
  RC5_32_ofb64_encrypt := TRC5_32_ofb64_encrypt(GetProcedureAddress(AHandle, 'RC5_32_ofb64_encrypt'));
  
  // IDEA functions
  IDEA_set_encrypt_key := TIDEA_set_encrypt_key(GetProcedureAddress(AHandle, 'IDEA_set_encrypt_key'));
  IDEA_set_decrypt_key := TIDEA_set_decrypt_key(GetProcedureAddress(AHandle, 'IDEA_set_decrypt_key'));
  IDEA_ecb_encrypt := TIDEA_ecb_encrypt(GetProcedureAddress(AHandle, 'IDEA_ecb_encrypt'));
  IDEA_cbc_encrypt := TIDEA_cbc_encrypt(GetProcedureAddress(AHandle, 'IDEA_cbc_encrypt'));
  IDEA_cfb64_encrypt := TIDEA_cfb64_encrypt(GetProcedureAddress(AHandle, 'IDEA_cfb64_encrypt'));
  IDEA_ofb64_encrypt := TIDEA_ofb64_encrypt(GetProcedureAddress(AHandle, 'IDEA_ofb64_encrypt'));
  
  // CAMELLIA functions
  Camellia_set_key := TCamellia_set_key(GetProcedureAddress(AHandle, 'Camellia_set_key'));
  Camellia_encrypt_func := TCamellia_encrypt_func(GetProcedureAddress(AHandle, 'Camellia_encrypt'));
  Camellia_decrypt_func := TCamellia_decrypt_func(GetProcedureAddress(AHandle, 'Camellia_decrypt'));
  Camellia_ecb_encrypt := TCamellia_ecb_encrypt(GetProcedureAddress(AHandle, 'Camellia_ecb_encrypt'));
  Camellia_cbc_encrypt := TCamellia_cbc_encrypt(GetProcedureAddress(AHandle, 'Camellia_cbc_encrypt'));
  Camellia_cfb128_encrypt := TCamellia_cfb_encrypt(GetProcedureAddress(AHandle, 'Camellia_cfb128_encrypt'));
  Camellia_cfb1_encrypt := TCamellia_cfb_encrypt(GetProcedureAddress(AHandle, 'Camellia_cfb1_encrypt'));
  Camellia_cfb8_encrypt := TCamellia_cfb_encrypt(GetProcedureAddress(AHandle, 'Camellia_cfb8_encrypt'));
  Camellia_ofb128_encrypt := TCamellia_ofb_encrypt(GetProcedureAddress(AHandle, 'Camellia_ofb128_encrypt'));
  Camellia_ctr128_encrypt := TCamellia_ctr_encrypt(GetProcedureAddress(AHandle, 'Camellia_ctr128_encrypt'));
  
  // BLOWFISH functions
  BF_set_key := TBF_set_key(GetProcedureAddress(AHandle, 'BF_set_key'));
  BF_encrypt_func := TBF_encrypt(GetProcedureAddress(AHandle, 'BF_encrypt'));
  BF_decrypt_func := TBF_decrypt(GetProcedureAddress(AHandle, 'BF_decrypt'));
  BF_ecb_encrypt := TBF_ecb_encrypt(GetProcedureAddress(AHandle, 'BF_ecb_encrypt'));
  BF_cbc_encrypt := TBF_cbc_encrypt(GetProcedureAddress(AHandle, 'BF_cbc_encrypt'));
  BF_cfb64_encrypt := TBF_cfb64_encrypt(GetProcedureAddress(AHandle, 'BF_cfb64_encrypt'));
  BF_ofb64_encrypt := TBF_ofb64_encrypt(GetProcedureAddress(AHandle, 'BF_ofb64_encrypt'));
  
  // CAST5 functions
  CAST_set_key := TCAST_set_key(GetProcedureAddress(AHandle, 'CAST_set_key'));
  CAST_ecb_encrypt := TCAST_ecb_encrypt(GetProcedureAddress(AHandle, 'CAST_ecb_encrypt'));
  CAST_encrypt_func := TCAST_encrypt(GetProcedureAddress(AHandle, 'CAST_encrypt'));
  CAST_decrypt_func := TCAST_decrypt(GetProcedureAddress(AHandle, 'CAST_decrypt'));
  CAST_cbc_encrypt := TCAST_cbc_encrypt(GetProcedureAddress(AHandle, 'CAST_cbc_encrypt'));
  CAST_cfb64_encrypt := TCAST_cfb64_encrypt(GetProcedureAddress(AHandle, 'CAST_cfb64_encrypt'));
  CAST_ofb64_encrypt := TCAST_ofb64_encrypt(GetProcedureAddress(AHandle, 'CAST_ofb64_encrypt'));
  
  // MDC2 functions
  MDC2_Init := TMDC2_Init(GetProcedureAddress(AHandle, 'MDC2_Init'));
  MDC2_Update := TMDC2_Update(GetProcedureAddress(AHandle, 'MDC2_Update'));
  MDC2_Final := TMDC2_Final(GetProcedureAddress(AHandle, 'MDC2_Final'));
  MDC2 := TMDC2(GetProcedureAddress(AHandle, 'MDC2'));
  
  // RIPEMD functions
  RIPEMD160_Init := TRIPEMD160_Init(GetProcedureAddress(AHandle, 'RIPEMD160_Init'));
  RIPEMD160_Update := TRIPEMD160_Update(GetProcedureAddress(AHandle, 'RIPEMD160_Update'));
  RIPEMD160_Final := TRIPEMD160_Final(GetProcedureAddress(AHandle, 'RIPEMD160_Final'));
  RIPEMD160 := TRIPEMD160(GetProcedureAddress(AHandle, 'RIPEMD160'));
  RIPEMD160_Transform := TRIPEMD160_Transform(GetProcedureAddress(AHandle, 'RIPEMD160_Transform'));
  
  // Load EVP functions
  EVP_rc2_ecb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_rc2_ecb'));
  EVP_rc2_cbc := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_rc2_cbc'));
  EVP_rc2_40_cbc := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_rc2_40_cbc'));
  EVP_rc2_64_cbc := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_rc2_64_cbc'));
  EVP_rc2_cfb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_rc2_cfb'));
  EVP_rc2_cfb64 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_rc2_cfb64'));
  EVP_rc2_ofb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_rc2_ofb'));
  
  EVP_rc4 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_rc4'));
  EVP_rc4_40 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_rc4_40'));
  EVP_rc4_hmac_md5 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_rc4_hmac_md5'));
  
  EVP_rc5_32_12_16_ecb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_rc5_32_12_16_ecb'));
  EVP_rc5_32_12_16_cbc := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_rc5_32_12_16_cbc'));
  EVP_rc5_32_12_16_cfb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_rc5_32_12_16_cfb'));
  EVP_rc5_32_12_16_cfb64 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_rc5_32_12_16_cfb64'));
  EVP_rc5_32_12_16_ofb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_rc5_32_12_16_ofb'));
  
  EVP_idea_ecb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_idea_ecb'));
  EVP_idea_cbc := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_idea_cbc'));
  EVP_idea_cfb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_idea_cfb'));
  EVP_idea_cfb64 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_idea_cfb64'));
  EVP_idea_ofb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_idea_ofb'));
  
  EVP_camellia_128_ecb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_128_ecb'));
  EVP_camellia_128_cbc := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_128_cbc'));
  EVP_camellia_128_cfb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_128_cfb'));
  EVP_camellia_128_cfb1 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_128_cfb1'));
  EVP_camellia_128_cfb8 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_128_cfb8'));
  EVP_camellia_128_cfb128 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_128_cfb128'));
  EVP_camellia_128_ofb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_128_ofb'));
  EVP_camellia_128_ctr := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_128_ctr'));
  
  EVP_camellia_192_ecb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_192_ecb'));
  EVP_camellia_192_cbc := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_192_cbc'));
  EVP_camellia_192_cfb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_192_cfb'));
  EVP_camellia_192_cfb1 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_192_cfb1'));
  EVP_camellia_192_cfb8 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_192_cfb8'));
  EVP_camellia_192_cfb128 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_192_cfb128'));
  EVP_camellia_192_ofb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_192_ofb'));
  EVP_camellia_192_ctr := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_192_ctr'));
  
  EVP_camellia_256_ecb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_256_ecb'));
  EVP_camellia_256_cbc := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_256_cbc'));
  EVP_camellia_256_cfb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_256_cfb'));
  EVP_camellia_256_cfb1 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_256_cfb1'));
  EVP_camellia_256_cfb8 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_256_cfb8'));
  EVP_camellia_256_cfb128 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_256_cfb128'));
  EVP_camellia_256_ofb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_256_ofb'));
  EVP_camellia_256_ctr := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_camellia_256_ctr'));
  
  EVP_bf_ecb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_bf_ecb'));
  EVP_bf_cbc := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_bf_cbc'));
  EVP_bf_cfb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_bf_cfb'));
  EVP_bf_cfb64 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_bf_cfb64'));
  EVP_bf_ofb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_bf_ofb'));
  
  EVP_cast5_ecb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_cast5_ecb'));
  EVP_cast5_cbc := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_cast5_cbc'));
  EVP_cast5_cfb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_cast5_cfb'));
  EVP_cast5_cfb64 := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_cast5_cfb64'));
  EVP_cast5_ofb := TEVP_CIPHER(GetProcedureAddress(AHandle, 'EVP_cast5_ofb'));
  
  EVP_mdc2 := TEVP_MD(GetProcedureAddress(AHandle, 'EVP_mdc2'));
  EVP_ripemd160 := TEVP_MD(GetProcedureAddress(AHandle, 'EVP_ripemd160'));
end;

procedure UnloadLegacyCiphersFunctions;
begin
  // RC2
  RC2_set_key := nil;
  RC2_ecb_encrypt := nil;
  RC2_cbc_encrypt := nil;
  RC2_cfb64_encrypt := nil;
  RC2_ofb64_encrypt := nil;
  
  // RC4
  RC4_set_key := nil;
  RC4 := nil;
  RC4_options := nil;
  
  // RC5
  RC5_32_set_key := nil;
  RC5_32_ecb_encrypt := nil;
  RC5_32_cbc_encrypt := nil;
  RC5_32_cfb64_encrypt := nil;
  RC5_32_ofb64_encrypt := nil;
  
  // IDEA
  IDEA_set_encrypt_key := nil;
  IDEA_set_decrypt_key := nil;
  IDEA_ecb_encrypt := nil;
  IDEA_cbc_encrypt := nil;
  IDEA_cfb64_encrypt := nil;
  IDEA_ofb64_encrypt := nil;
  
  // CAMELLIA
  Camellia_set_key := nil;
  Camellia_encrypt_func := nil;
  Camellia_decrypt_func := nil;
  Camellia_ecb_encrypt := nil;
  Camellia_cbc_encrypt := nil;
  Camellia_cfb128_encrypt := nil;
  Camellia_cfb1_encrypt := nil;
  Camellia_cfb8_encrypt := nil;
  Camellia_ofb128_encrypt := nil;
  Camellia_ctr128_encrypt := nil;
  
  // BLOWFISH
  BF_set_key := nil;
  BF_encrypt_func := nil;
  BF_decrypt_func := nil;
  BF_ecb_encrypt := nil;
  BF_cbc_encrypt := nil;
  BF_cfb64_encrypt := nil;
  BF_ofb64_encrypt := nil;
  
  // CAST5
  CAST_set_key := nil;
  CAST_ecb_encrypt := nil;
  CAST_encrypt_func := nil;
  CAST_decrypt_func := nil;
  CAST_cbc_encrypt := nil;
  CAST_cfb64_encrypt := nil;
  CAST_ofb64_encrypt := nil;
  
  // MDC2
  MDC2_Init := nil;
  MDC2_Update := nil;
  MDC2_Final := nil;
  MDC2 := nil;
  
  // RIPEMD
  RIPEMD160_Init := nil;
  RIPEMD160_Update := nil;
  RIPEMD160_Final := nil;
  RIPEMD160 := nil;
  RIPEMD160_Transform := nil;
  
  // EVP functions
  EVP_rc2_ecb := nil;
  EVP_rc2_cbc := nil;
  EVP_rc2_40_cbc := nil;
  EVP_rc2_64_cbc := nil;
  EVP_rc2_cfb := nil;
  EVP_rc2_cfb64 := nil;
  EVP_rc2_ofb := nil;
  
  EVP_rc4 := nil;
  EVP_rc4_40 := nil;
  EVP_rc4_hmac_md5 := nil;
  
  EVP_rc5_32_12_16_ecb := nil;
  EVP_rc5_32_12_16_cbc := nil;
  EVP_rc5_32_12_16_cfb := nil;
  EVP_rc5_32_12_16_cfb64 := nil;
  EVP_rc5_32_12_16_ofb := nil;
  
  EVP_idea_ecb := nil;
  EVP_idea_cbc := nil;
  EVP_idea_cfb := nil;
  EVP_idea_cfb64 := nil;
  EVP_idea_ofb := nil;
  
  EVP_camellia_128_ecb := nil;
  EVP_camellia_128_cbc := nil;
  EVP_camellia_128_cfb := nil;
  EVP_camellia_128_cfb1 := nil;
  EVP_camellia_128_cfb8 := nil;
  EVP_camellia_128_cfb128 := nil;
  EVP_camellia_128_ofb := nil;
  EVP_camellia_128_ctr := nil;
  
  EVP_camellia_192_ecb := nil;
  EVP_camellia_192_cbc := nil;
  EVP_camellia_192_cfb := nil;
  EVP_camellia_192_cfb1 := nil;
  EVP_camellia_192_cfb8 := nil;
  EVP_camellia_192_cfb128 := nil;
  EVP_camellia_192_ofb := nil;
  EVP_camellia_192_ctr := nil;
  
  EVP_camellia_256_ecb := nil;
  EVP_camellia_256_cbc := nil;
  EVP_camellia_256_cfb := nil;
  EVP_camellia_256_cfb1 := nil;
  EVP_camellia_256_cfb8 := nil;
  EVP_camellia_256_cfb128 := nil;
  EVP_camellia_256_ofb := nil;
  EVP_camellia_256_ctr := nil;
  
  EVP_bf_ecb := nil;
  EVP_bf_cbc := nil;
  EVP_bf_cfb := nil;
  EVP_bf_cfb64 := nil;
  EVP_bf_ofb := nil;
  
  EVP_cast5_ecb := nil;
  EVP_cast5_cbc := nil;
  EVP_cast5_cfb := nil;
  EVP_cast5_cfb64 := nil;
  EVP_cast5_ofb := nil;
  
  EVP_mdc2 := nil;
  EVP_ripemd160 := nil;
end;

end.