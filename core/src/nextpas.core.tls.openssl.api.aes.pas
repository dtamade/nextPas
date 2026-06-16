{******************************************************************************}
{                                                                              }
{  fafafa.ssl - OpenSSL AES Module                                           }
{                                                                              }
{  Copyright (c) 2024 fafafa                                                  }
{                                                                              }
{******************************************************************************}

unit nextpas.core.tls.openssl.api.aes;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.base, nextpas.core.tls.base, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.consts, nextpas.core.tls.openssl.loader; const AES_MAXNR = 14;
  AES_BLOCK_SIZE = 16;
  
  // AES encryption/decryption mode constants
  C_AES_ENCRYPT = 1;
  C_AES_DECRYPT = 0;

type
  // AES key structure
  PAES_KEY = ^AES_KEY;
  AES_KEY = record
    rd_key: array[0..(4 * (AES_MAXNR + 1))-1] of Cardinal;
    rounds: Integer;
  end;
  
  // AES-GCM context
  Pgcm128_context = ^gcm128_context;
  gcm128_context = record end; // Opaque structure
  
  // AES-XTS context
  Pxts128_context = ^xts128_context;
  xts128_context = record end; // Opaque structure

type
  // AES key setup functions
  TAES_set_encrypt_key = function(const userKey: PByte; const bits: Integer; key: PAES_KEY): Integer; cdecl;
  TAES_set_decrypt_key = function(const userKey: PByte; const bits: Integer; key: PAES_KEY): Integer; cdecl;
  
  // AES ECB mode
  TAES_ecb_encrypt = procedure(const in_: PByte; out_: PByte; const key: PAES_KEY; const enc: Integer); cdecl;
  
  // AES CBC mode
  TAES_cbc_encrypt = procedure(const in_: PByte; out_: PByte; length: NativeUInt; 
                                const key: PAES_KEY; ivec: PByte; const enc: Integer); cdecl;
  
  // AES CFB mode
  TAES_cfb128_encrypt = procedure(const in_: PByte; out_: PByte; length: NativeUInt;
                                  const key: PAES_KEY; ivec: PByte; num: PInteger; const enc: Integer); cdecl;
  TAES_cfb1_encrypt = procedure(const in_: PByte; out_: PByte; length: NativeUInt;
                                const key: PAES_KEY; ivec: PByte; num: PInteger; const enc: Integer); cdecl;
  TAES_cfb8_encrypt = procedure(const in_: PByte; out_: PByte; length: NativeUInt;
                                const key: PAES_KEY; ivec: PByte; num: PInteger; const enc: Integer); cdecl;
  
  // AES OFB mode
  TAES_ofb128_encrypt = procedure(const in_: PByte; out_: PByte; length: NativeUInt;
                                  const key: PAES_KEY; ivec: PByte; num: PInteger); cdecl;
  
  // AES CTR mode
  TAES_ctr128_encrypt = procedure(const in_: PByte; out_: PByte; length: NativeUInt;
                                  const key: PAES_KEY; ivec: PByte; ecount_buf: PByte; 
                                  num: PCardinal); cdecl;
  
  // AES IGE mode
  TAES_ige_encrypt = procedure(const in_: PByte; out_: PByte; length: NativeUInt;
                                const key: PAES_KEY; ivec: PByte; const enc: Integer); cdecl;
  TAES_bi_ige_encrypt = procedure(const in_: PByte; out_: PByte; length: NativeUInt;
                                  const key: PAES_KEY; const key2: PAES_KEY; 
                                  const ivec: PByte; const enc: Integer); cdecl;
  
  // AES Wrap mode
  TAES_wrap_key = function(key: PAES_KEY; const iv: PByte; out_: PByte; 
                          const in_: PByte; inlen: Cardinal): Integer; cdecl;
  TAES_unwrap_key = function(key: PAES_KEY; const iv: PByte; out_: PByte;
                            const in_: PByte; inlen: Cardinal): Integer; cdecl;
  
  // AES hardware acceleration options
  TAES_options = function: PAnsiChar; cdecl;
  
  // Low-level AES functions
  TAES_encrypt = procedure(const in_: PByte; out_: PByte; const key: PAES_KEY); cdecl;
  TAES_decrypt = procedure(const in_: PByte; out_: PByte; const key: PAES_KEY); cdecl;

var
  // Function pointers
  AES_set_encrypt_key: TAES_set_encrypt_key = nil;
  AES_set_decrypt_key: TAES_set_decrypt_key = nil;
  AES_ecb_encrypt: TAES_ecb_encrypt = nil;
  AES_cbc_encrypt: TAES_cbc_encrypt = nil;
  AES_cfb128_encrypt: TAES_cfb128_encrypt = nil;
  AES_cfb1_encrypt: TAES_cfb1_encrypt = nil;
  AES_cfb8_encrypt: TAES_cfb8_encrypt = nil;
  AES_ofb128_encrypt: TAES_ofb128_encrypt = nil;
  AES_ctr128_encrypt: TAES_ctr128_encrypt = nil;
  AES_ige_encrypt: TAES_ige_encrypt = nil;
  AES_bi_ige_encrypt: TAES_bi_ige_encrypt = nil;
  AES_wrap_key: TAES_wrap_key = nil;
  AES_unwrap_key: TAES_unwrap_key = nil;
  AES_options: TAES_options = nil;
  AES_encrypt: TAES_encrypt = nil;
  AES_decrypt: TAES_decrypt = nil;

// Helper functions
function LoadAESFunctions(ALibHandle: TOpenSSLLibHandle): Boolean;
procedure UnloadAESFunctions;

// High-level helper functions
function AESEncryptECB(const Data: TBytes; const Key: TBytes): TBytes;
function AESDecryptECB(const Data: TBytes; const Key: TBytes): TBytes;
function AESEncryptCBC(const Data: TBytes; const Key: TBytes; const IV: TBytes): TBytes;
function AESDecryptCBC(const Data: TBytes; const Key: TBytes; const IV: TBytes): TBytes;
function AESEncryptCTR(const Data: TBytes; const Key: TBytes; const IV: TBytes): TBytes;
function AESDecryptCTR(const Data: TBytes; const Key: TBytes; const IV: TBytes): TBytes;

implementation


var
  AESFunctionBindings: array[0..AES_FUNCTION_COUNT-1] of TFunctionBinding = (
    (Name: 'AES_set_encrypt_key'; FuncPtr: @AES_set_encrypt_key; Required: True),
    (Name: 'AES_set_decrypt_key'; FuncPtr: @AES_set_decrypt_key; Required: True),
    (Name: 'AES_ecb_encrypt';     FuncPtr: @AES_ecb_encrypt;     Required: True),
    (Name: 'AES_cbc_encrypt';     FuncPtr: @AES_cbc_encrypt;     Required: True),
    (Name: 'AES_cfb128_encrypt';  FuncPtr: @AES_cfb128_encrypt;  Required: False),
    (Name: 'AES_cfb1_encrypt';    FuncPtr: @AES_cfb1_encrypt;    Required: False),
    (Name: 'AES_cfb8_encrypt';    FuncPtr: @AES_cfb8_encrypt;    Required: False),
    (Name: 'AES_ofb128_encrypt';  FuncPtr: @AES_ofb128_encrypt;  Required: False),
    (Name: 'AES_ctr128_encrypt';  FuncPtr: @AES_ctr128_encrypt;  Required: True),
    (Name: 'AES_ige_encrypt';     FuncPtr: @AES_ige_encrypt;     Required: False),
    (Name: 'AES_bi_ige_encrypt';  FuncPtr: @AES_bi_ige_encrypt;  Required: False),
    (Name: 'AES_wrap_key';        FuncPtr: @AES_wrap_key;        Required: False),
    (Name: 'AES_unwrap_key';      FuncPtr: @AES_unwrap_key;      Required: False),
    (Name: 'AES_options';         FuncPtr: @AES_options;         Required: False),
    (Name: 'AES_encrypt';         FuncPtr: @AES_encrypt;         Required: True),
    (Name: 'AES_decrypt';         FuncPtr: @AES_decrypt;         Required: True)
  );

function LoadAESFunctions(ALibHandle: TOpenSSLLibHandle): Boolean;
begin
  Result := False;

  if ALibHandle = 0 then Exit;

  if TOpenSSLLoader.LoadFunctions(ALibHandle, AESFunctionBindings) < 0 then
  begin
    TOpenSSLLoader.SetModuleLoaded(osmAES, False);
    Exit(False);
  end;

  TOpenSSLLoader.SetModuleLoaded(osmAES, True);
  Result := True;
end;

procedure UnloadAESFunctions;
begin
  TOpenSSLLoader.ClearFunctions(AESFunctionBindings);
  TOpenSSLLoader.SetModuleLoaded(osmAES, False);
end;


function GetAESKeyBits(const Key: TBytes): Integer;
begin
  case Length(Key) of
    16: Result := 128;
    24: Result := 192;
    32: Result := 256;
  else
    Result := 0;
  end;
end;

function AESEncryptECB(const Data: TBytes; const Key: TBytes): TBytes;
var
  aesKey: AES_KEY;
  i, blocks: Integer;
  inblock, outblock: array[0..AES_BLOCK_SIZE-1] of Byte;
  bits: Integer;
begin
  Result := nil;
  bits := GetAESKeyBits(Key);
  if (bits = 0) or not Assigned(AES_set_encrypt_key) or not Assigned(AES_ecb_encrypt) then Exit;
  
  if AES_set_encrypt_key(@Key[0], bits, @aesKey) <> 0 then Exit;
  
  blocks := (Length(Data) + AES_BLOCK_SIZE - 1) div AES_BLOCK_SIZE;
  SetLength(Result, blocks * AES_BLOCK_SIZE);
  
  for i := 0 to blocks - 1 do
  begin
    FillChar(inblock, AES_BLOCK_SIZE, 0);
    if i * AES_BLOCK_SIZE + AES_BLOCK_SIZE <= Length(Data) then
      Move(Data[i * AES_BLOCK_SIZE], inblock[0], AES_BLOCK_SIZE)
    else
      Move(Data[i * AES_BLOCK_SIZE], inblock[0], Length(Data) - i * AES_BLOCK_SIZE);
    
    AES_ecb_encrypt(@inblock[0], @outblock[0], @aesKey, C_AES_ENCRYPT);
    Move(outblock[0], Result[i * AES_BLOCK_SIZE], AES_BLOCK_SIZE);
  end;
end;

function AESDecryptECB(const Data: TBytes; const Key: TBytes): TBytes;
var
  aesKey: AES_KEY;
  i, blocks: Integer;
  inblock, outblock: array[0..AES_BLOCK_SIZE-1] of Byte;
  bits: Integer;
begin
  Result := nil;
  bits := GetAESKeyBits(Key);
  if (bits = 0) or (Length(Data) mod AES_BLOCK_SIZE <> 0) or
    not Assigned(AES_set_decrypt_key) or not Assigned(AES_ecb_encrypt) then Exit;
  
  if AES_set_decrypt_key(@Key[0], bits, @aesKey) <> 0 then Exit;
  
  blocks := Length(Data) div AES_BLOCK_SIZE;
  SetLength(Result, blocks * AES_BLOCK_SIZE);
  
  for i := 0 to blocks - 1 do
  begin
    Move(Data[i * AES_BLOCK_SIZE], inblock[0], AES_BLOCK_SIZE);
    AES_ecb_encrypt(@inblock[0], @outblock[0], @aesKey, C_AES_DECRYPT);
    Move(outblock[0], Result[i * AES_BLOCK_SIZE], AES_BLOCK_SIZE);
  end;
end;

function AESEncryptCBC(const Data: TBytes; const Key: TBytes; const IV: TBytes): TBytes;
var
  aesKey: AES_KEY;
  ivec: array[0..AES_BLOCK_SIZE-1] of Byte;
  bits, padLen: Integer;
begin
  Result := nil;
  bits := GetAESKeyBits(Key);
  if (bits = 0) or (Length(IV) <> AES_BLOCK_SIZE) or 
    not Assigned(AES_set_encrypt_key) or not Assigned(AES_cbc_encrypt) then Exit;
  
  if AES_set_encrypt_key(@Key[0], bits, @aesKey) <> 0 then Exit;
  
  // Add PKCS7 padding
  padLen := AES_BLOCK_SIZE - (Length(Data) mod AES_BLOCK_SIZE);
  SetLength(Result, Length(Data) + padLen);
  if Length(Data) > 0 then
    Move(Data[0], Result[0], Length(Data));
  FillChar(Result[Length(Data)], padLen, padLen);
  
  Move(IV[0], ivec[0], AES_BLOCK_SIZE);
  AES_cbc_encrypt(@Result[0], @Result[0], Length(Result), @aesKey, @ivec[0], C_AES_ENCRYPT);
end;

function AESDecryptCBC(const Data: TBytes; const Key: TBytes; const IV: TBytes): TBytes;
var
  aesKey: AES_KEY;
  ivec: array[0..AES_BLOCK_SIZE-1] of Byte;
  bits, padLen: Integer;
begin
  Result := nil;
  bits := GetAESKeyBits(Key);
  if (bits = 0) or (Length(IV) <> AES_BLOCK_SIZE) or (Length(Data) mod AES_BLOCK_SIZE <> 0) or
    not Assigned(AES_set_decrypt_key) or not Assigned(AES_cbc_encrypt) then Exit;
  
  if AES_set_decrypt_key(@Key[0], bits, @aesKey) <> 0 then Exit;
  
  SetLength(Result, Length(Data));
  Move(Data[0], Result[0], Length(Data));
  Move(IV[0], ivec[0], AES_BLOCK_SIZE);
  
  AES_cbc_encrypt(@Result[0], @Result[0], Length(Result), @aesKey, @ivec[0], C_AES_DECRYPT);
  
  // Remove PKCS7 padding
  if Length(Result) > 0 then
  begin
    padLen := Result[Length(Result) - 1];
    if (padLen > 0) and (padLen <= AES_BLOCK_SIZE) then
      SetLength(Result, Length(Result) - padLen);
  end;
end;

function AESEncryptCTR(const Data: TBytes; const Key: TBytes; const IV: TBytes): TBytes;
var
  aesKey: AES_KEY;
  ivec: array[0..AES_BLOCK_SIZE-1] of Byte;
  ecount: array[0..AES_BLOCK_SIZE-1] of Byte;
  num: Cardinal;
  bits: Integer;
begin
  Result := nil;
  bits := GetAESKeyBits(Key);
  if (bits = 0) or (Length(IV) <> AES_BLOCK_SIZE) or 
    not Assigned(AES_set_encrypt_key) or not Assigned(AES_ctr128_encrypt) then Exit;
  
  if AES_set_encrypt_key(@Key[0], bits, @aesKey) <> 0 then Exit;
  
  SetLength(Result, Length(Data));
  if Length(Data) > 0 then
    Move(Data[0], Result[0], Length(Data));
  
  Move(IV[0], ivec[0], AES_BLOCK_SIZE);
  FillChar(ecount, AES_BLOCK_SIZE, 0);
  num := 0;
  
  AES_ctr128_encrypt(@Result[0], @Result[0], Length(Result), @aesKey, @ivec[0], @ecount[0], @num);
end;

function AESDecryptCTR(const Data: TBytes; const Key: TBytes; const IV: TBytes): TBytes;
begin
  // CTR mode decryption is the same as encryption
  Result := AESEncryptCTR(Data, Key, IV);
end;

end.
