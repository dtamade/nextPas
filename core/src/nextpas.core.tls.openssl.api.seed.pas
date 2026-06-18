unit nextpas.core.tls.openssl.api.seed;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.base, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.loader,
  nextpas.core.platform.dl;

type
  // SEED types
  SEED_KEY_SCHEDULE = packed record
    ks: array[0..31] of Cardinal;
  end;
  PSEED_KEY_SCHEDULE = ^SEED_KEY_SCHEDULE;
  
  // SEED function types
  TSEED_set_key = procedure(const key: PByte; ks: PSEED_KEY_SCHEDULE); cdecl;
  TSEED_encrypt_func = procedure(const input: PByte; output: PByte; 
    const ks: PSEED_KEY_SCHEDULE); cdecl;
  TSEED_decrypt_func = procedure(const input: PByte; output: PByte; 
    const ks: PSEED_KEY_SCHEDULE); cdecl;
  TSEED_ecb_encrypt = procedure(const input: PByte; output: PByte;
    const ks: PSEED_KEY_SCHEDULE; enc: Integer); cdecl;
  TSEED_cbc_encrypt = procedure(const input: PByte; output: PByte; length: NativeUInt;
    const ks: PSEED_KEY_SCHEDULE; ivec: PByte; enc: Integer); cdecl;
  TSEED_cfb128_encrypt = procedure(const input: PByte; output: PByte; length: NativeUInt;
    const ks: PSEED_KEY_SCHEDULE; ivec: PByte; num: PInteger; enc: Integer); cdecl;
  TSEED_ofb128_encrypt = procedure(const input: PByte; output: PByte; length: NativeUInt;
    const ks: PSEED_KEY_SCHEDULE; ivec: PByte; num: PInteger); cdecl;
  TEVP_seed_cipher = function(): PEVP_CIPHER; cdecl;

const
  // SEED block size and key size
  SEED_BLOCK_SIZE = 16;
  SEED_KEY_LENGTH = 16;
  
  // SEED modes
  SEED_ENCRYPT = 1;
  SEED_DECRYPT = 0;

var
  // SEED function pointers
  SEED_set_key: TSEED_set_key = nil;
  SEED_encrypt_func: TSEED_encrypt_func = nil;
  SEED_decrypt_func: TSEED_decrypt_func = nil;
  SEED_ecb_encrypt: TSEED_ecb_encrypt = nil;
  SEED_cbc_encrypt: TSEED_cbc_encrypt = nil;
  SEED_cfb128_encrypt: TSEED_cfb128_encrypt = nil;
  SEED_ofb128_encrypt: TSEED_ofb128_encrypt = nil;
  
  // EVP SEED function pointers
  EVP_seed_ecb: TEVP_seed_cipher = nil;
  EVP_seed_cbc: TEVP_seed_cipher = nil;
  EVP_seed_cfb: TEVP_seed_cipher = nil;
  EVP_seed_cfb128: TEVP_seed_cipher = nil;
  EVP_seed_ofb: TEVP_seed_cipher = nil;
  EVP_seed_ofb128: TEVP_seed_cipher = nil;

procedure LoadSEEDFunctions(AHandle: TPlatformLibrary);
procedure UnloadSEEDFunctions;

// Helper functions
function SEEDEncryptBlock(const Key, Input: TBytes): TBytes;
function SEEDDecryptBlock(const Key, Input: TBytes): TBytes;
function SEEDEncryptCBC(const Key, IV, Input: TBytes): TBytes;
function SEEDDecryptCBC(const Key, IV, Input: TBytes): TBytes;

implementation

uses nextpas.core.tls.openssl.api.utils; procedure LoadSEEDFunctions(AHandle: TPlatformLibrary);
begin
  if not LibLoaded(AHandle) then Exit;
  
  // Core SEED functions
  SEED_set_key := TSEED_set_key(GetProcSymbol(AHandle, 'SEED_set_key'));
  SEED_encrypt_func := TSEED_encrypt_func(GetProcSymbol(AHandle, 'SEED_encrypt'));
  SEED_decrypt_func := TSEED_decrypt_func(GetProcSymbol(AHandle, 'SEED_decrypt'));
  
  // SEED mode functions
  SEED_ecb_encrypt := TSEED_ecb_encrypt(GetProcSymbol(AHandle, 'SEED_ecb_encrypt'));
  SEED_cbc_encrypt := TSEED_cbc_encrypt(GetProcSymbol(AHandle, 'SEED_cbc_encrypt'));
  SEED_cfb128_encrypt := TSEED_cfb128_encrypt(GetProcSymbol(AHandle, 'SEED_cfb128_encrypt'));
  SEED_ofb128_encrypt := TSEED_ofb128_encrypt(GetProcSymbol(AHandle, 'SEED_ofb128_encrypt'));
  
  // EVP SEED functions
  EVP_seed_ecb := TEVP_seed_cipher(GetProcSymbol(AHandle, 'EVP_seed_ecb'));
  EVP_seed_cbc := TEVP_seed_cipher(GetProcSymbol(AHandle, 'EVP_seed_cbc'));
  EVP_seed_cfb := TEVP_seed_cipher(GetProcSymbol(AHandle, 'EVP_seed_cfb'));
  EVP_seed_cfb128 := TEVP_seed_cipher(GetProcSymbol(AHandle, 'EVP_seed_cfb128'));
  EVP_seed_ofb := TEVP_seed_cipher(GetProcSymbol(AHandle, 'EVP_seed_ofb'));
  EVP_seed_ofb128 := TEVP_seed_cipher(GetProcSymbol(AHandle, 'EVP_seed_ofb128'));
end;

procedure UnloadSEEDFunctions;
begin
  SEED_set_key := nil;
  SEED_encrypt_func := nil;
  SEED_decrypt_func := nil;
  SEED_ecb_encrypt := nil;
  SEED_cbc_encrypt := nil;
  SEED_cfb128_encrypt := nil;
  SEED_ofb128_encrypt := nil;
  EVP_seed_ecb := nil;
  EVP_seed_cbc := nil;
  EVP_seed_cfb := nil;
  EVP_seed_cfb128 := nil;
  EVP_seed_ofb := nil;
  EVP_seed_ofb128 := nil;
end;

function SEEDEncryptBlock(const Key, Input: TBytes): TBytes;
var
  ks: SEED_KEY_SCHEDULE;
begin
  Result := nil;
  SetLength(Result, SEED_BLOCK_SIZE);
  if (Length(Key) <> SEED_KEY_LENGTH) or (Length(Input) <> SEED_BLOCK_SIZE) then
    Exit;
    
  if Assigned(SEED_set_key) and Assigned(SEED_encrypt_func) then
  begin
    SEED_set_key(@Key[0], @ks);
    SEED_encrypt_func(@Input[0], @Result[0], @ks);
  end;
end;

function SEEDDecryptBlock(const Key, Input: TBytes): TBytes;
var
  ks: SEED_KEY_SCHEDULE;
begin
  Result := nil;
  SetLength(Result, SEED_BLOCK_SIZE);
  if (Length(Key) <> SEED_KEY_LENGTH) or (Length(Input) <> SEED_BLOCK_SIZE) then
    Exit;
    
  if Assigned(SEED_set_key) and Assigned(SEED_decrypt_func) then
  begin
    SEED_set_key(@Key[0], @ks);
    SEED_decrypt_func(@Input[0], @Result[0], @ks);
  end;
end;

function SEEDEncryptCBC(const Key, IV, Input: TBytes): TBytes;
var
  ks: SEED_KEY_SCHEDULE;
  IVCopy: array[0..SEED_BLOCK_SIZE-1] of Byte;
begin
  Result := nil;
  if (Length(Key) <> SEED_KEY_LENGTH) or (Length(IV) <> SEED_BLOCK_SIZE) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  
  SetLength(Result, Length(Input));
  Move(IV[0], IVCopy[0], SEED_BLOCK_SIZE);
  
  if Assigned(SEED_set_key) and Assigned(SEED_cbc_encrypt) then
  begin
    SEED_set_key(@Key[0], @ks);
    SEED_cbc_encrypt(@Input[0], @Result[0], Length(Input), @ks, @IVCopy[0], SEED_ENCRYPT);
  end;
end;

function SEEDDecryptCBC(const Key, IV, Input: TBytes): TBytes;
var
  ks: SEED_KEY_SCHEDULE;
  IVCopy: array[0..SEED_BLOCK_SIZE-1] of Byte;
begin
  Result := nil;
  if (Length(Key) <> SEED_KEY_LENGTH) or (Length(IV) <> SEED_BLOCK_SIZE) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  
  SetLength(Result, Length(Input));
  Move(IV[0], IVCopy[0], SEED_BLOCK_SIZE);
  
  if Assigned(SEED_set_key) and Assigned(SEED_cbc_encrypt) then
  begin
    SEED_set_key(@Key[0], @ks);
    SEED_cbc_encrypt(@Input[0], @Result[0], Length(Input), @ks, @IVCopy[0], SEED_DECRYPT);
  end;
end;

end.