unit nextpas.core.tls.openssl.api.aria;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.loader; type // ARIA types ARIA_KEY = packed record rd_key: array[0..16, 0..3] of Cardinal;
    rounds: Integer;
  end;
  PARIA_KEY = ^ARIA_KEY;

const
  // ARIA block size and key sizes
  ARIA_BLOCK_SIZE = 16;
  ARIA_KEY_LENGTH_128 = 16;
  ARIA_KEY_LENGTH_192 = 24;
  ARIA_KEY_LENGTH_256 = 32;
  
  // ARIA key sizes in bits
  ARIA_KEY_BITS_128 = 128;
  ARIA_KEY_BITS_192 = 192;
  ARIA_KEY_BITS_256 = 256;
  
  // ARIA modes
  ARIA_ENCRYPT = 1;
  ARIA_DECRYPT = 0;

type
  // ARIA function types
  TARIA_set_encrypt_key = function(const userKey: PByte; const bits: Integer; 
    key: PARIA_KEY): Integer; cdecl;
  TARIA_set_decrypt_key = function(const userKey: PByte; const bits: Integer; 
    key: PARIA_KEY): Integer; cdecl;
  TARIA_encrypt_func = procedure(const input: PByte; output: PByte; 
    const key: PARIA_KEY); cdecl;
  TARIA_decrypt_func = procedure(const input: PByte; output: PByte; 
    const key: PARIA_KEY); cdecl;
  TARIA_ecb_encrypt = procedure(const input: PByte; output: PByte;
    const key: PARIA_KEY; const enc: Integer); cdecl;
  TARIA_cbc_encrypt = procedure(const input: PByte; output: PByte; length: NativeUInt;
    const key: PARIA_KEY; ivec: PByte; const enc: Integer); cdecl;
  TARIA_cfb128_encrypt = procedure(const input: PByte; output: PByte; length: NativeUInt;
    const key: PARIA_KEY; ivec: PByte; num: PInteger; const enc: Integer); cdecl;
  TARIA_cfb_encrypt = procedure(const input: PByte; output: PByte; length: NativeUInt;
    const key: PARIA_KEY; ivec: PByte; num: PInteger; const enc: Integer); cdecl;
  TARIA_ofb128_encrypt = procedure(const input: PByte; output: PByte; length: NativeUInt;
    const key: PARIA_KEY; ivec: PByte; num: PInteger); cdecl;
  TARIA_ctr128_encrypt = procedure(const input: PByte; output: PByte; length: NativeUInt;
    const key: PARIA_KEY; ivec: PByte; ecount_buf: PByte; num: PCardinal); cdecl;
  TEVP_aria_cipher = function(): PEVP_CIPHER; cdecl;

var
  // ARIA key setup functions
  ARIA_set_encrypt_key: TARIA_set_encrypt_key = nil;
  ARIA_set_decrypt_key: TARIA_set_decrypt_key = nil;
  
  // ARIA core functions
  ARIA_encrypt_func: TARIA_encrypt_func = nil;
  ARIA_decrypt_func: TARIA_decrypt_func = nil;
  
  // ARIA ECB mode
  ARIA_ecb_encrypt: TARIA_ecb_encrypt = nil;
  
  // ARIA CBC mode
  ARIA_cbc_encrypt: TARIA_cbc_encrypt = nil;
  
  // ARIA CFB mode
  ARIA_cfb128_encrypt: TARIA_cfb128_encrypt = nil;
  ARIA_cfb1_encrypt: TARIA_cfb_encrypt = nil;
  ARIA_cfb8_encrypt: TARIA_cfb_encrypt = nil;
  
  // ARIA OFB mode
  ARIA_ofb128_encrypt: TARIA_ofb128_encrypt = nil;
    
  // ARIA CTR mode
  ARIA_ctr128_encrypt: TARIA_ctr128_encrypt = nil;
    
  // EVP ARIA functions
  EVP_aria_128_ecb: TEVP_aria_cipher = nil;
  EVP_aria_128_cbc: TEVP_aria_cipher = nil;
  EVP_aria_128_cfb: TEVP_aria_cipher = nil;
  EVP_aria_128_cfb1: TEVP_aria_cipher = nil;
  EVP_aria_128_cfb8: TEVP_aria_cipher = nil;
  EVP_aria_128_cfb128: TEVP_aria_cipher = nil;
  EVP_aria_128_ctr: TEVP_aria_cipher = nil;
  EVP_aria_128_ofb: TEVP_aria_cipher = nil;
  EVP_aria_128_gcm: TEVP_aria_cipher = nil;
  EVP_aria_128_ccm: TEVP_aria_cipher = nil;
  
  EVP_aria_192_ecb: TEVP_aria_cipher = nil;
  EVP_aria_192_cbc: TEVP_aria_cipher = nil;
  EVP_aria_192_cfb: TEVP_aria_cipher = nil;
  EVP_aria_192_cfb1: TEVP_aria_cipher = nil;
  EVP_aria_192_cfb8: TEVP_aria_cipher = nil;
  EVP_aria_192_cfb128: TEVP_aria_cipher = nil;
  EVP_aria_192_ctr: TEVP_aria_cipher = nil;
  EVP_aria_192_ofb: TEVP_aria_cipher = nil;
  EVP_aria_192_gcm: TEVP_aria_cipher = nil;
  EVP_aria_192_ccm: TEVP_aria_cipher = nil;
  
  EVP_aria_256_ecb: TEVP_aria_cipher = nil;
  EVP_aria_256_cbc: TEVP_aria_cipher = nil;
  EVP_aria_256_cfb: TEVP_aria_cipher = nil;
  EVP_aria_256_cfb1: TEVP_aria_cipher = nil;
  EVP_aria_256_cfb8: TEVP_aria_cipher = nil;
  EVP_aria_256_cfb128: TEVP_aria_cipher = nil;
  EVP_aria_256_ctr: TEVP_aria_cipher = nil;
  EVP_aria_256_ofb: TEVP_aria_cipher = nil;
  EVP_aria_256_gcm: TEVP_aria_cipher = nil;
  EVP_aria_256_ccm: TEVP_aria_cipher = nil;

procedure LoadARIAFunctions(AHandle: TPlatformLibrary);
procedure UnloadARIAFunctions;

// Helper functions
function ARIAEncryptBlock(const Key: TBytes; KeyBits: Integer; const Input: TBytes): TBytes;
function ARIADecryptBlock(const Key: TBytes; KeyBits: Integer; const Input: TBytes): TBytes;
function ARIAEncryptCBC(const Key: TBytes; KeyBits: Integer; const IV, Input: TBytes): TBytes;
function ARIADecryptCBC(const Key: TBytes; KeyBits: Integer; const IV, Input: TBytes): TBytes;

implementation

uses nextpas.core.tls.openssl.api.utils; procedure LoadARIAFunctions(AHandle: TPlatformLibrary);
begin
  if not LibLoaded(AHandle) then Exit;
  
  // Key setup functions
  ARIA_set_encrypt_key := TARIA_set_encrypt_key(GetProcSymbol(AHandle, 'ARIA_set_encrypt_key'));
  ARIA_set_decrypt_key := TARIA_set_decrypt_key(GetProcSymbol(AHandle, 'ARIA_set_decrypt_key'));
  
  // Core functions
  ARIA_encrypt_func := TARIA_encrypt_func(GetProcSymbol(AHandle, 'ARIA_encrypt'));
  ARIA_decrypt_func := TARIA_decrypt_func(GetProcSymbol(AHandle, 'ARIA_decrypt'));
  
  // Mode functions
  ARIA_ecb_encrypt := TARIA_ecb_encrypt(GetProcSymbol(AHandle, 'ARIA_ecb_encrypt'));
  ARIA_cbc_encrypt := TARIA_cbc_encrypt(GetProcSymbol(AHandle, 'ARIA_cbc_encrypt'));
  ARIA_cfb128_encrypt := TARIA_cfb128_encrypt(GetProcSymbol(AHandle, 'ARIA_cfb128_encrypt'));
  ARIA_cfb1_encrypt := TARIA_cfb_encrypt(GetProcSymbol(AHandle, 'ARIA_cfb1_encrypt'));
  ARIA_cfb8_encrypt := TARIA_cfb_encrypt(GetProcSymbol(AHandle, 'ARIA_cfb8_encrypt'));
  ARIA_ofb128_encrypt := TARIA_ofb128_encrypt(GetProcSymbol(AHandle, 'ARIA_ofb128_encrypt'));
  ARIA_ctr128_encrypt := TARIA_ctr128_encrypt(GetProcSymbol(AHandle, 'ARIA_ctr128_encrypt'));
  
  // EVP functions - 128 bit
  EVP_aria_128_ecb := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_128_ecb'));
  EVP_aria_128_cbc := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_128_cbc'));
  EVP_aria_128_cfb := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_128_cfb'));
  EVP_aria_128_cfb1 := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_128_cfb1'));
  EVP_aria_128_cfb8 := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_128_cfb8'));
  EVP_aria_128_cfb128 := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_128_cfb128'));
  EVP_aria_128_ctr := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_128_ctr'));
  EVP_aria_128_ofb := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_128_ofb'));
  EVP_aria_128_gcm := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_128_gcm'));
  EVP_aria_128_ccm := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_128_ccm'));
  
  // EVP functions - 192 bit
  EVP_aria_192_ecb := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_192_ecb'));
  EVP_aria_192_cbc := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_192_cbc'));
  EVP_aria_192_cfb := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_192_cfb'));
  EVP_aria_192_cfb1 := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_192_cfb1'));
  EVP_aria_192_cfb8 := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_192_cfb8'));
  EVP_aria_192_cfb128 := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_192_cfb128'));
  EVP_aria_192_ctr := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_192_ctr'));
  EVP_aria_192_ofb := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_192_ofb'));
  EVP_aria_192_gcm := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_192_gcm'));
  EVP_aria_192_ccm := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_192_ccm'));
  
  // EVP functions - 256 bit
  EVP_aria_256_ecb := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_256_ecb'));
  EVP_aria_256_cbc := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_256_cbc'));
  EVP_aria_256_cfb := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_256_cfb'));
  EVP_aria_256_cfb1 := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_256_cfb1'));
  EVP_aria_256_cfb8 := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_256_cfb8'));
  EVP_aria_256_cfb128 := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_256_cfb128'));
  EVP_aria_256_ctr := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_256_ctr'));
  EVP_aria_256_ofb := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_256_ofb'));
  EVP_aria_256_gcm := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_256_gcm'));
  EVP_aria_256_ccm := TEVP_aria_cipher(GetProcSymbol(AHandle, 'EVP_aria_256_ccm'));
end;

procedure UnloadARIAFunctions;
begin
  ARIA_set_encrypt_key := nil;
  ARIA_set_decrypt_key := nil;
  ARIA_encrypt_func := nil;
  ARIA_decrypt_func := nil;
  ARIA_ecb_encrypt := nil;
  ARIA_cbc_encrypt := nil;
  ARIA_cfb128_encrypt := nil;
  ARIA_cfb1_encrypt := nil;
  ARIA_cfb8_encrypt := nil;
  ARIA_ofb128_encrypt := nil;
  ARIA_ctr128_encrypt := nil;
  
  EVP_aria_128_ecb := nil;
  EVP_aria_128_cbc := nil;
  EVP_aria_128_cfb := nil;
  EVP_aria_128_cfb1 := nil;
  EVP_aria_128_cfb8 := nil;
  EVP_aria_128_cfb128 := nil;
  EVP_aria_128_ctr := nil;
  EVP_aria_128_ofb := nil;
  EVP_aria_128_gcm := nil;
  EVP_aria_128_ccm := nil;
  
  EVP_aria_192_ecb := nil;
  EVP_aria_192_cbc := nil;
  EVP_aria_192_cfb := nil;
  EVP_aria_192_cfb1 := nil;
  EVP_aria_192_cfb8 := nil;
  EVP_aria_192_cfb128 := nil;
  EVP_aria_192_ctr := nil;
  EVP_aria_192_ofb := nil;
  EVP_aria_192_gcm := nil;
  EVP_aria_192_ccm := nil;
  
  EVP_aria_256_ecb := nil;
  EVP_aria_256_cbc := nil;
  EVP_aria_256_cfb := nil;
  EVP_aria_256_cfb1 := nil;
  EVP_aria_256_cfb8 := nil;
  EVP_aria_256_cfb128 := nil;
  EVP_aria_256_ctr := nil;
  EVP_aria_256_ofb := nil;
  EVP_aria_256_gcm := nil;
  EVP_aria_256_ccm := nil;
end;

function ARIAEncryptBlock(const Key: TBytes; KeyBits: Integer; const Input: TBytes): TBytes;
var
  key_struct: ARIA_KEY;
begin
  Result := nil;
  SetLength(Result, ARIA_BLOCK_SIZE);
  if (Length(Input) <> ARIA_BLOCK_SIZE) then
    Exit;
    
  if Assigned(ARIA_set_encrypt_key) and Assigned(ARIA_encrypt_func) then
  begin
    if ARIA_set_encrypt_key(@Key[0], KeyBits, @key_struct) = 0 then
      ARIA_encrypt_func(@Input[0], @Result[0], @key_struct);
  end;
end;

function ARIADecryptBlock(const Key: TBytes; KeyBits: Integer; const Input: TBytes): TBytes;
var
  key_struct: ARIA_KEY;
begin
  Result := nil;
  SetLength(Result, ARIA_BLOCK_SIZE);
  if (Length(Input) <> ARIA_BLOCK_SIZE) then
    Exit;
    
  if Assigned(ARIA_set_decrypt_key) and Assigned(ARIA_decrypt_func) then
  begin
    if ARIA_set_decrypt_key(@Key[0], KeyBits, @key_struct) = 0 then
      ARIA_decrypt_func(@Input[0], @Result[0], @key_struct);
  end;
end;

function ARIAEncryptCBC(const Key: TBytes; KeyBits: Integer; const IV, Input: TBytes): TBytes;
var
  key_struct: ARIA_KEY;
  IVCopy: array[0..ARIA_BLOCK_SIZE-1] of Byte;
begin
  Result := nil;
  if Length(IV) <> ARIA_BLOCK_SIZE then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  
  SetLength(Result, Length(Input));
  Move(IV[0], IVCopy[0], ARIA_BLOCK_SIZE);
  
  if Assigned(ARIA_set_encrypt_key) and Assigned(ARIA_cbc_encrypt) then
  begin
    if ARIA_set_encrypt_key(@Key[0], KeyBits, @key_struct) = 0 then
      ARIA_cbc_encrypt(@Input[0], @Result[0], Length(Input), @key_struct, @IVCopy[0], ARIA_ENCRYPT);
  end;
end;

function ARIADecryptCBC(const Key: TBytes; KeyBits: Integer; const IV, Input: TBytes): TBytes;
var
  key_struct: ARIA_KEY;
  IVCopy: array[0..ARIA_BLOCK_SIZE-1] of Byte;
begin
  Result := nil;
  if Length(IV) <> ARIA_BLOCK_SIZE then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  
  SetLength(Result, Length(Input));
  Move(IV[0], IVCopy[0], ARIA_BLOCK_SIZE);
  
  if Assigned(ARIA_set_decrypt_key) and Assigned(ARIA_cbc_encrypt) then
  begin
    if ARIA_set_decrypt_key(@Key[0], KeyBits, @key_struct) = 0 then
      ARIA_cbc_encrypt(@Input[0], @Result[0], Length(Input), @key_struct, @IVCopy[0], ARIA_DECRYPT);
  end;
end;

end.