{******************************************************************************}
{                                                                              }
{  fafafa.ssl - OpenSSL DES Module                                           }
{                                                                              }
{  Copyright (c) 2024 fafafa                                                  }
{                                                                              }
{******************************************************************************}

unit nextpas.core.tls.openssl.api.des;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.base, nextpas.core.tls.base, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.consts, nextpas.core.tls.openssl.loader; const DES_ENCRYPT = 1;
  DES_DECRYPT = 0;
  
  DES_CBC_MODE = 0;
  DES_PCBC_MODE = 1;
  
  DES_KEY_SZ = 8;
  DES_SCHEDULE_SZ = 16;
  
  DES_BLOCK = 8;

type
  DES_LONG = Cardinal;
  PDES_LONG = ^DES_LONG;
  // DES key types
  DES_cblock = array[0..7] of Byte;
  PDES_cblock = ^DES_cblock;
  const_DES_cblock = DES_cblock;
  Pconst_DES_cblock = ^const_DES_cblock;
  
  // DES key schedule
  PDES_key_schedule = ^DES_key_schedule;
  DES_key_schedule = record
    ks: array[0..15] of record
      deslong: array[0..1] of DES_LONG;
    end;
  end;
  
  const_DES_key_schedule = DES_key_schedule;

type
  // DES functions
  TDES_options = function: PAnsiChar; cdecl;
  TDES_ecb3_encrypt = procedure(const input: Pconst_DES_cblock; output: PDES_cblock;
                                ks1: PDES_key_schedule; ks2: PDES_key_schedule;
                                ks3: PDES_key_schedule; enc: Integer); cdecl;
                                 
  TDES_crypt = function(buf: PAnsiChar; salt: PAnsiChar): PAnsiChar; cdecl;
  TDES_fcrypt = function(buf: PAnsiChar; salt: PAnsiChar; ret: PAnsiChar): PAnsiChar; cdecl;
  
  TDES_ecb_encrypt = procedure(const input: Pconst_DES_cblock; output: PDES_cblock;
                                ks: PDES_key_schedule; enc: Integer); cdecl;
                                
  TDES_ncbc_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
                                schedule: PDES_key_schedule; ivec: PDES_cblock; enc: Integer); cdecl;
                                 
  TDES_xcbc_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
                                schedule: PDES_key_schedule; ivec: PDES_cblock;
                                const inw: Pconst_DES_cblock; const outw: Pconst_DES_cblock;
                                enc: Integer); cdecl;
                                 
  TDES_cfb_encrypt = procedure(const in_: PByte; out_: PByte; numbits: Integer;
                                length: LongInt; schedule: PDES_key_schedule;
                                ivec: PDES_cblock; enc: Integer); cdecl;
                                
  TDES_ecb2_encrypt = procedure(const input: Pconst_DES_cblock; output: PDES_cblock;
                                ks1: PDES_key_schedule; ks2: PDES_key_schedule;
                                enc: Integer); cdecl;
                                 
  TDES_ede2_cbc_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
                                    ks1: PDES_key_schedule; ks2: PDES_key_schedule;
                                    ivec: PDES_cblock; enc: Integer); cdecl;
                                     
  TDES_ede2_cfb64_encrypt = procedure(const in_: PByte; out_: PByte; length: LongInt;
                                      ks1: PDES_key_schedule; ks2: PDES_key_schedule;
                                      ivec: PDES_cblock; num: PInteger; enc: Integer); cdecl;
                                       
  TDES_ede2_ofb64_encrypt = procedure(const in_: PByte; out_: PByte; length: LongInt;
                                      ks1: PDES_key_schedule; ks2: PDES_key_schedule;
                                      ivec: PDES_cblock; num: PInteger); cdecl;
                                       
  TDES_ede3_cbc_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
                                    ks1: PDES_key_schedule; ks2: PDES_key_schedule;
                                    ks3: PDES_key_schedule; ivec: PDES_cblock; enc: Integer); cdecl;
                                     
  TDES_ede3_cfb64_encrypt = procedure(const in_: PByte; out_: PByte; length: LongInt;
                                      ks1: PDES_key_schedule; ks2: PDES_key_schedule;
                                      ks3: PDES_key_schedule; ivec: PDES_cblock;
                                      num: PInteger; enc: Integer); cdecl;
                                       
  TDES_ede3_cfb_encrypt = procedure(const in_: PByte; out_: PByte; numbits: Integer;
                                    length: LongInt; ks1: PDES_key_schedule;
                                    ks2: PDES_key_schedule; ks3: PDES_key_schedule;
                                    ivec: PDES_cblock; enc: Integer); cdecl;
                                     
  TDES_ede3_ofb64_encrypt = procedure(const in_: PByte; out_: PByte; length: LongInt;
                                      ks1: PDES_key_schedule; ks2: PDES_key_schedule;
                                      ks3: PDES_key_schedule; ivec: PDES_cblock;
                                      num: PInteger); cdecl;
                                       
  TDES_enc_read = function(fd: Integer; buf: Pointer; len: Integer;
                          sched: PDES_key_schedule; iv: PDES_cblock): Integer; cdecl;
                           
  TDES_enc_write = function(fd: Integer; const buf: Pointer; len: Integer;
                            sched: PDES_key_schedule; iv: PDES_cblock): Integer; cdecl;
                            
  TDES_set_odd_parity = procedure(key: PDES_cblock); cdecl;
  TDES_check_key_parity = function(const key: Pconst_DES_cblock): Integer; cdecl;
  TDES_is_weak_key = function(const key: Pconst_DES_cblock): Integer; cdecl;
  
  TDES_set_key = function(const key: Pconst_DES_cblock; schedule: PDES_key_schedule): Integer; cdecl;
  TDES_key_sched = function(const key: Pconst_DES_cblock; schedule: PDES_key_schedule): Integer; cdecl;
  TDES_set_key_checked = function(const key: Pconst_DES_cblock; schedule: PDES_key_schedule): Integer; cdecl;
  TDES_set_key_unchecked = procedure(const key: Pconst_DES_cblock; schedule: PDES_key_schedule); cdecl;
  
  TDES_string_to_key = procedure(const str: PAnsiChar; key: PDES_cblock); cdecl;
  TDES_string_to_2keys = procedure(const str: PAnsiChar; key1: PDES_cblock; key2: PDES_cblock); cdecl;
  
  TDES_cfb64_encrypt = procedure(const in_: PByte; out_: PByte; length: LongInt;
                                  schedule: PDES_key_schedule; ivec: PDES_cblock;
                                  num: PInteger; enc: Integer); cdecl;
                                  
  TDES_ofb64_encrypt = procedure(const in_: PByte; out_: PByte; length: LongInt;
                                  schedule: PDES_key_schedule; ivec: PDES_cblock;
                                  num: PInteger); cdecl;
                                  
  TDES_pcbc_encrypt = procedure(const input: PByte; output: PByte; length: LongInt;
                                schedule: PDES_key_schedule; ivec: PDES_cblock; enc: Integer); cdecl;
                                 
  TDES_quad_cksum = function(const input: PByte; output: PDES_cblock; length: LongInt;
                            out_count: Integer; seed: PDES_cblock): DES_LONG; cdecl;
                             
  TDES_random_key = function(ret: PDES_cblock): Integer; cdecl;
  
  TDES_encrypt1 = procedure(data: PDES_LONG; ks: PDES_key_schedule; enc: Integer); cdecl;
  TDES_encrypt2 = procedure(data: PDES_LONG; ks: PDES_key_schedule; enc: Integer); cdecl;
  TDES_encrypt3 = procedure(data: PDES_LONG; ks1: PDES_key_schedule;
                          ks2: PDES_key_schedule; ks3: PDES_key_schedule); cdecl;
  TDES_decrypt3 = procedure(data: PDES_LONG; ks1: PDES_key_schedule;
                          ks2: PDES_key_schedule; ks3: PDES_key_schedule); cdecl;

var
  // DES function pointers
  DES_options: TDES_options = nil;
  DES_ecb3_encrypt: TDES_ecb3_encrypt = nil;
  DES_crypt: TDES_crypt = nil;
  DES_fcrypt: TDES_fcrypt = nil;
  DES_ecb_encrypt: TDES_ecb_encrypt = nil;
  DES_ncbc_encrypt: TDES_ncbc_encrypt = nil;
  DES_xcbc_encrypt: TDES_xcbc_encrypt = nil;
  DES_cfb_encrypt: TDES_cfb_encrypt = nil;
  DES_ecb2_encrypt: TDES_ecb2_encrypt = nil;
  DES_ede2_cbc_encrypt: TDES_ede2_cbc_encrypt = nil;
  DES_ede2_cfb64_encrypt: TDES_ede2_cfb64_encrypt = nil;
  DES_ede2_ofb64_encrypt: TDES_ede2_ofb64_encrypt = nil;
  DES_ede3_cbc_encrypt: TDES_ede3_cbc_encrypt = nil;
  DES_ede3_cfb64_encrypt: TDES_ede3_cfb64_encrypt = nil;
  DES_ede3_cfb_encrypt: TDES_ede3_cfb_encrypt = nil;
  DES_ede3_ofb64_encrypt: TDES_ede3_ofb64_encrypt = nil;
  DES_enc_read: TDES_enc_read = nil;
  DES_enc_write: TDES_enc_write = nil;
  DES_set_odd_parity: TDES_set_odd_parity = nil;
  DES_check_key_parity: TDES_check_key_parity = nil;
  DES_is_weak_key: TDES_is_weak_key = nil;
  DES_set_key: TDES_set_key = nil;
  DES_key_sched: TDES_key_sched = nil;
  DES_set_key_checked: TDES_set_key_checked = nil;
  DES_set_key_unchecked: TDES_set_key_unchecked = nil;
  DES_string_to_key: TDES_string_to_key = nil;
  DES_string_to_2keys: TDES_string_to_2keys = nil;
  DES_cfb64_encrypt: TDES_cfb64_encrypt = nil;
  DES_ofb64_encrypt: TDES_ofb64_encrypt = nil;
  DES_pcbc_encrypt: TDES_pcbc_encrypt = nil;
  DES_quad_cksum: TDES_quad_cksum = nil;
  DES_random_key: TDES_random_key = nil;
  DES_encrypt1: TDES_encrypt1 = nil;
  DES_encrypt2: TDES_encrypt2 = nil;
  DES_encrypt3: TDES_encrypt3 = nil;
  DES_decrypt3: TDES_decrypt3 = nil;

// Helper functions
function LoadDESFunctions(ALibHandle: TOpenSSLLibHandle): Boolean;
procedure UnloadDESFunctions;

// High-level helper functions
function DESEncrypt(const Data: TBytes; const Key: TBytes): TBytes;
function DESDecrypt(const Data: TBytes; const Key: TBytes): TBytes;
function DES3Encrypt(const Data: TBytes; const Key1, Key2, Key3: TBytes): TBytes;
function DES3Decrypt(const Data: TBytes; const Key1, Key2, Key3: TBytes): TBytes;

implementation

    (Name: 'DES_ecb3_encrypt';      FuncPtr: @DES_ecb3_encrypt;      Required: False),
    (Name: 'DES_crypt';             FuncPtr: @DES_crypt;             Required: False),
    (Name: 'DES_fcrypt';            FuncPtr: @DES_fcrypt;            Required: False),
    (Name: 'DES_ecb_encrypt';       FuncPtr: @DES_ecb_encrypt;       Required: False),
    (Name: 'DES_ncbc_encrypt';      FuncPtr: @DES_ncbc_encrypt;      Required: False),
    (Name: 'DES_xcbc_encrypt';      FuncPtr: @DES_xcbc_encrypt;      Required: False),
    (Name: 'DES_cfb_encrypt';       FuncPtr: @DES_cfb_encrypt;       Required: False),
    (Name: 'DES_ecb2_encrypt';      FuncPtr: @DES_ecb2_encrypt;      Required: False),
    (Name: 'DES_ede2_cbc_encrypt';  FuncPtr: @DES_ede2_cbc_encrypt;  Required: False),
    (Name: 'DES_ede2_cfb64_encrypt'; FuncPtr: @DES_ede2_cfb64_encrypt; Required: False),
    (Name: 'DES_ede2_ofb64_encrypt'; FuncPtr: @DES_ede2_ofb64_encrypt; Required: False),
    (Name: 'DES_ede3_cbc_encrypt';  FuncPtr: @DES_ede3_cbc_encrypt;  Required: False),
    (Name: 'DES_ede3_cfb64_encrypt'; FuncPtr: @DES_ede3_cfb64_encrypt; Required: False),
    (Name: 'DES_ede3_cfb_encrypt';  FuncPtr: @DES_ede3_cfb_encrypt;  Required: False),
    (Name: 'DES_ede3_ofb64_encrypt'; FuncPtr: @DES_ede3_ofb64_encrypt; Required: False),
    (Name: 'DES_enc_read';          FuncPtr: @DES_enc_read;          Required: False),
    (Name: 'DES_enc_write';         FuncPtr: @DES_enc_write;         Required: False),
    (Name: 'DES_set_odd_parity';    FuncPtr: @DES_set_odd_parity;    Required: False),
    (Name: 'DES_check_key_parity';  FuncPtr: @DES_check_key_parity;  Required: False),
    (Name: 'DES_is_weak_key';       FuncPtr: @DES_is_weak_key;       Required: False),
    (Name: 'DES_set_key';           FuncPtr: @DES_set_key;           Required: False),
    (Name: 'DES_key_sched';         FuncPtr: @DES_key_sched;         Required: False),
    (Name: 'DES_set_key_checked';   FuncPtr: @DES_set_key_checked;   Required: False),
    (Name: 'DES_set_key_unchecked'; FuncPtr: @DES_set_key_unchecked; Required: False),
    (Name: 'DES_string_to_key';     FuncPtr: @DES_string_to_key;     Required: False),
    (Name: 'DES_string_to_2keys';   FuncPtr: @DES_string_to_2keys;   Required: False),
    (Name: 'DES_cfb64_encrypt';     FuncPtr: @DES_cfb64_encrypt;     Required: False),
    (Name: 'DES_ofb64_encrypt';     FuncPtr: @DES_ofb64_encrypt;     Required: False),
    (Name: 'DES_pcbc_encrypt';      FuncPtr: @DES_pcbc_encrypt;      Required: False),
    (Name: 'DES_quad_cksum';        FuncPtr: @DES_quad_cksum;        Required: False),
    (Name: 'DES_random_key';        FuncPtr: @DES_random_key;        Required: False),
    (Name: 'DES_encrypt1';          FuncPtr: @DES_encrypt1;          Required: False),
    (Name: 'DES_encrypt2';          FuncPtr: @DES_encrypt2;          Required: False),
    (Name: 'DES_encrypt3';          FuncPtr: @DES_encrypt3;          Required: False),
    (Name: 'DES_decrypt3';          FuncPtr: @DES_decrypt3;          Required: False)
  );

function LoadDESFunctions(ALibHandle: TOpenSSLLibHandle): Boolean;
begin
  Result := False;

  if ALibHandle = 0 then Exit;

  TOpenSSLLoader.LoadFunctions(ALibHandle, DES_FUNCTION_BINDINGS);
  TOpenSSLLoader.SetModuleLoaded(osmDES, True);
  Result := True;
end;

procedure UnloadDESFunctions;
begin
  TOpenSSLLoader.ClearFunctions(DES_FUNCTION_BINDINGS);
  TOpenSSLLoader.SetModuleLoaded(osmDES, False);
end;


function DESEncrypt(const Data: TBytes; const Key: TBytes): TBytes;
var
  ks: DES_key_schedule;
  cblock: DES_cblock;
  outblock: DES_cblock;
  i, blocks: Integer;
begin
  Result := nil;
  if (Length(Key) < 8) or not Assigned(DES_set_key_unchecked) or 
    not Assigned(DES_ecb_encrypt) then Exit;
  
  Move(Key[0], cblock[0], 8);
  DES_set_key_unchecked(@cblock, @ks);
  
  blocks := (Length(Data) + 7) div 8;
  SetLength(Result, blocks * 8);
  
  for i := 0 to blocks - 1 do
  begin
    FillChar(cblock, 8, 0);
    if i * 8 + 8 <= Length(Data) then
      Move(Data[i * 8], cblock[0], 8)
    else
      Move(Data[i * 8], cblock[0], Length(Data) - i * 8);
    
    DES_ecb_encrypt(@cblock, @outblock, @ks, DES_ENCRYPT);
    Move(outblock[0], Result[i * 8], 8);
  end;
end;

function DESDecrypt(const Data: TBytes; const Key: TBytes): TBytes;
var
  ks: DES_key_schedule;
  cblock: DES_cblock;
  outblock: DES_cblock;
  i, blocks: Integer;
begin
  Result := nil;
  if (Length(Key) < 8) or (Length(Data) mod 8 <> 0) or 
    not Assigned(DES_set_key_unchecked) or not Assigned(DES_ecb_encrypt) then Exit;
  
  Move(Key[0], cblock[0], 8);
  DES_set_key_unchecked(@cblock, @ks);
  
  blocks := Length(Data) div 8;
  SetLength(Result, blocks * 8);
  
  for i := 0 to blocks - 1 do
  begin
    Move(Data[i * 8], cblock[0], 8);
    DES_ecb_encrypt(@cblock, @outblock, @ks, DES_DECRYPT);
    Move(outblock[0], Result[i * 8], 8);
  end;
end;

function DES3Encrypt(const Data: TBytes; const Key1, Key2, Key3: TBytes): TBytes;
var
  ks1, ks2, ks3: DES_key_schedule;
  cblock1, cblock2, cblock3: DES_cblock;
  inblock, outblock: DES_cblock;
  i, blocks: Integer;
begin
  Result := nil;
  if (Length(Key1) < 8) or (Length(Key2) < 8) or (Length(Key3) < 8) or
    not Assigned(DES_set_key_unchecked) or not Assigned(DES_ecb3_encrypt) then Exit;
  
  Move(Key1[0], cblock1[0], 8);
  Move(Key2[0], cblock2[0], 8);
  Move(Key3[0], cblock3[0], 8);
  
  DES_set_key_unchecked(@cblock1, @ks1);
  DES_set_key_unchecked(@cblock2, @ks2);
  DES_set_key_unchecked(@cblock3, @ks3);
  
  blocks := (Length(Data) + 7) div 8;
  SetLength(Result, blocks * 8);
  
  for i := 0 to blocks - 1 do
  begin
    FillChar(inblock, 8, 0);
    if i * 8 + 8 <= Length(Data) then
      Move(Data[i * 8], inblock[0], 8)
    else
      Move(Data[i * 8], inblock[0], Length(Data) - i * 8);
    
    DES_ecb3_encrypt(@inblock, @outblock, @ks1, @ks2, @ks3, DES_ENCRYPT);
    Move(outblock[0], Result[i * 8], 8);
  end;
end;

function DES3Decrypt(const Data: TBytes; const Key1, Key2, Key3: TBytes): TBytes;
var
  ks1, ks2, ks3: DES_key_schedule;
  cblock1, cblock2, cblock3: DES_cblock;
  inblock, outblock: DES_cblock;
  i, blocks: Integer;
begin
  Result := nil;
  if (Length(Key1) < 8) or (Length(Key2) < 8) or (Length(Key3) < 8) or
    (Length(Data) mod 8 <> 0) or not Assigned(DES_set_key_unchecked) or 
    not Assigned(DES_ecb3_encrypt) then Exit;
  
  Move(Key1[0], cblock1[0], 8);
  Move(Key2[0], cblock2[0], 8);
  Move(Key3[0], cblock3[0], 8);
  
  DES_set_key_unchecked(@cblock1, @ks1);
  DES_set_key_unchecked(@cblock2, @ks2);
  DES_set_key_unchecked(@cblock3, @ks3);
  
  blocks := Length(Data) div 8;
  SetLength(Result, blocks * 8);
  
  for i := 0 to blocks - 1 do
  begin
    Move(Data[i * 8], inblock[0], 8);
    DES_ecb3_encrypt(@inblock, @outblock, @ks1, @ks2, @ks3, DES_DECRYPT);
    Move(outblock[0], Result[i * 8], 8);
  end;
end;

end.
