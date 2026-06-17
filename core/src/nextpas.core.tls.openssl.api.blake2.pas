{******************************************************************************}
{                                                                              }
{  fafafa.ssl - OpenSSL BLAKE2 Module                                        }
{                                                                              }
{  Copyright (c) 2024 fafafa                                                  }
{                                                                              }
{******************************************************************************}

unit nextpas.core.tls.openssl.api.blake2;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.base, nextpas.core.tls.base, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.consts, nextpas.core.tls.openssl.loader;

const BLAKE2B_BLOCKBYTES = 128;
  BLAKE2B_OUTBYTES = 64;
  BLAKE2B_KEYBYTES = 64;
  BLAKE2B_SALTBYTES = 16;
  BLAKE2B_PERSONALBYTES = 16;
  
  BLAKE2S_BLOCKBYTES = 64;
  BLAKE2S_OUTBYTES = 32;
  BLAKE2S_KEYBYTES = 32;
  BLAKE2S_SALTBYTES = 8;
  BLAKE2S_PERSONALBYTES = 8;

type
  // BLAKE2b parameter block
  PBLAKE2B_PARAM = ^BLAKE2B_PARAM;
  BLAKE2B_PARAM = packed record
    digest_length: Byte;      // 0
    key_length: Byte;         // 1
    fanout: Byte;            // 2
    depth: Byte;             // 3
    leaf_length: Cardinal;   // 4
    node_offset: UInt64;     // 8
    xof_length: UInt64;      // 16
    node_depth: Byte;        // 24
    inner_length: Byte;      // 25
    reserved: array[0..13] of Byte; // 26
    salt: array[0..BLAKE2B_SALTBYTES-1] of Byte; // 40
    personal: array[0..BLAKE2B_PERSONALBYTES-1] of Byte; // 56
  end;

  // BLAKE2s parameter block
  PBLAKE2S_PARAM = ^BLAKE2S_PARAM;
  BLAKE2S_PARAM = packed record
    digest_length: Byte;      // 0
    key_length: Byte;         // 1
    fanout: Byte;            // 2
    depth: Byte;             // 3
    leaf_length: Cardinal;   // 4
    node_offset: UInt64;     // 8
    xof_length: Cardinal;    // 16
    node_depth: Byte;        // 20
    inner_length: Byte;      // 21
    reserved: array[0..1] of Byte; // 22
    salt: array[0..BLAKE2S_SALTBYTES-1] of Byte; // 24
    personal: array[0..BLAKE2S_PERSONALBYTES-1] of Byte; // 32
  end;

  // BLAKE2b state
  PBLAKE2B_CTX = ^BLAKE2B_CTX;
  BLAKE2B_CTX = record
    h: array[0..7] of UInt64;
    t: array[0..1] of UInt64;
    f: array[0..1] of UInt64;
    buf: array[0..BLAKE2B_BLOCKBYTES-1] of Byte;
    buflen: NativeUInt;
    outlen: Byte;
    last_node: Byte;
  end;

  // BLAKE2s state
  PBLAKE2S_CTX = ^BLAKE2S_CTX;
  BLAKE2S_CTX = record
    h: array[0..7] of Cardinal;
    t: array[0..1] of Cardinal;
    f: array[0..1] of Cardinal;
    buf: array[0..BLAKE2S_BLOCKBYTES-1] of Byte;
    buflen: NativeUInt;
    outlen: Byte;
    last_node: Byte;
  end;

type
  // BLAKE2b functions
  TBLAKE2b_Init = function(ctx: PBLAKE2B_CTX; outlen: NativeUInt): Integer; cdecl;
  TBLAKE2b_Init_key = function(ctx: PBLAKE2B_CTX; outlen: NativeUInt; 
                              const key: Pointer; keylen: NativeUInt): Integer; cdecl;
  TBLAKE2b_Init_param = function(ctx: PBLAKE2B_CTX; const P: PBLAKE2B_PARAM): Integer; cdecl;
  TBLAKE2b_Update = function(ctx: PBLAKE2B_CTX; const data: Pointer; datalen: NativeUInt): Integer; cdecl;
  TBLAKE2b_Final = function(ctx: PBLAKE2B_CTX; out_: Pointer; outlen: NativeUInt): Integer; cdecl;
  TBLAKE2b = function(out_: Pointer; outlen: NativeUInt; const in_: Pointer; inlen: NativeUInt;
                      const key: Pointer; keylen: NativeUInt): Integer; cdecl;
  
  // BLAKE2s functions
  TBLAKE2s_Init = function(ctx: PBLAKE2S_CTX; outlen: NativeUInt): Integer; cdecl;
  TBLAKE2s_Init_key = function(ctx: PBLAKE2S_CTX; outlen: NativeUInt; 
                              const key: Pointer; keylen: NativeUInt): Integer; cdecl;
  TBLAKE2s_Init_param = function(ctx: PBLAKE2S_CTX; const P: PBLAKE2S_PARAM): Integer; cdecl;
  TBLAKE2s_Update = function(ctx: PBLAKE2S_CTX; const data: Pointer; datalen: NativeUInt): Integer; cdecl;
  TBLAKE2s_Final = function(ctx: PBLAKE2S_CTX; out_: Pointer; outlen: NativeUInt): Integer; cdecl;
  TBLAKE2s = function(out_: Pointer; outlen: NativeUInt; const in_: Pointer; inlen: NativeUInt;
                      const key: Pointer; keylen: NativeUInt): Integer; cdecl;

  // BLAKE2b MAC functions (keyed hash)
  TBLAKE2b_mac_Init = function(ctx: PBLAKE2B_CTX; outlen: NativeUInt; const key: Pointer; keylen: NativeUInt): Integer; cdecl;
  TBLAKE2s_mac_Init = function(ctx: PBLAKE2S_CTX; outlen: NativeUInt; const key: Pointer; keylen: NativeUInt): Integer; cdecl;

var
  // BLAKE2b function pointers
  BLAKE2b_Init: TBLAKE2b_Init = nil;
  BLAKE2b_Init_key: TBLAKE2b_Init_key = nil;
  BLAKE2b_Init_param: TBLAKE2b_Init_param = nil;
  BLAKE2b_Update: TBLAKE2b_Update = nil;
  BLAKE2b_Final: TBLAKE2b_Final = nil;
  BLAKE2b: TBLAKE2b = nil;
  BLAKE2b_mac_Init: TBLAKE2b_mac_Init = nil;
  
  // BLAKE2s function pointers
  BLAKE2s_Init: TBLAKE2s_Init = nil;
  BLAKE2s_Init_key: TBLAKE2s_Init_key = nil;
  BLAKE2s_Init_param: TBLAKE2s_Init_param = nil;
  BLAKE2s_Update: TBLAKE2s_Update = nil;
  BLAKE2s_Final: TBLAKE2s_Final = nil;
  BLAKE2s: TBLAKE2s = nil;
  BLAKE2s_mac_Init: TBLAKE2s_mac_Init = nil;

// Helper functions
function LoadBLAKE2Functions(ALibHandle: TOpenSSLLibHandle): Boolean;
procedure UnloadBLAKE2Functions;

// High-level helper functions
function BLAKE2b256Hash(const Data: TBytes): TBytes;
function BLAKE2b512Hash(const Data: TBytes): TBytes;
function BLAKE2s256Hash(const Data: TBytes): TBytes;
function BLAKE2bMAC(const Data: TBytes; const Key: TBytes; OutLen: Integer): TBytes;
function BLAKE2sMAC(const Data: TBytes; const Key: TBytes; OutLen: Integer): TBytes;

implementation

uses nextpas.core.tls.openssl.api;

const
  BLAKE2_BINDINGS: array[0..13] of TFunctionBinding = (
    // BLAKE2b functions
    (Name: 'BLAKE2b_Init';     FuncPtr: @BLAKE2b_Init;     Required: False),
    (Name: 'BLAKE2b_Init_key';   FuncPtr: @BLAKE2b_Init_key;   Required: False),
    (Name: 'BLAKE2b_Init_param'; FuncPtr: @BLAKE2b_Init_param; Required: False),
    (Name: 'BLAKE2b_Update';     FuncPtr: @BLAKE2b_Update;     Required: False),
    (Name: 'BLAKE2b_Final';      FuncPtr: @BLAKE2b_Final;      Required: False),
    (Name: 'BLAKE2b';            FuncPtr: @BLAKE2b;            Required: False),
    (Name: 'BLAKE2b_mac_Init';   FuncPtr: @BLAKE2b_mac_Init;   Required: False),
    // BLAKE2s functions
    (Name: 'BLAKE2s_Init';       FuncPtr: @BLAKE2s_Init;       Required: False),
    (Name: 'BLAKE2s_Init_key';   FuncPtr: @BLAKE2s_Init_key;   Required: False),
    (Name: 'BLAKE2s_Init_param'; FuncPtr: @BLAKE2s_Init_param; Required: False),
    (Name: 'BLAKE2s_Update';     FuncPtr: @BLAKE2s_Update;     Required: False),
    (Name: 'BLAKE2s_Final';      FuncPtr: @BLAKE2s_Final;      Required: False),
    (Name: 'BLAKE2s';            FuncPtr: @BLAKE2s;            Required: False),
    (Name: 'BLAKE2s_mac_Init';   FuncPtr: @BLAKE2s_mac_Init;   Required: False)
  );

function BLAKE2ModuleSurfaceReady: Boolean;
begin
  Result := (((Assigned(BLAKE2b_Init) and Assigned(BLAKE2b_Update) and Assigned(BLAKE2b_Final)) or
            Assigned(BLAKE2b)) and
            ((Assigned(BLAKE2s_Init) and Assigned(BLAKE2s_Update) and Assigned(BLAKE2s_Final)) or
            Assigned(BLAKE2s)) and
            ((Assigned(BLAKE2b_Init_key) and Assigned(BLAKE2b_Update) and Assigned(BLAKE2b_Final)) or
            Assigned(BLAKE2b)) and
            ((Assigned(BLAKE2s_Init_key) and Assigned(BLAKE2s_Update) and Assigned(BLAKE2s_Final)) or
            Assigned(BLAKE2s)));
end;

function LoadBLAKE2Functions(ALibHandle: TOpenSSLLibHandle): Boolean;
begin
  Result := False;

  if not LibLoaded(ALibHandle) then Exit;

  // 使用批量加载模式
  TOpenSSLLoader.LoadFunctions(ALibHandle, BLAKE2_BINDINGS);

  Result := BLAKE2ModuleSurfaceReady;
  if not Result then
  begin
    UnloadBLAKE2Functions;
    Exit(False);
  end;

  TOpenSSLLoader.SetModuleLoaded(osmBLAKE2, True);
end;

procedure UnloadBLAKE2Functions;
begin
  // 使用批量清除模式
  TOpenSSLLoader.ClearFunctions(BLAKE2_BINDINGS);

  TOpenSSLLoader.SetModuleLoaded(osmBLAKE2, False);
end;


function BLAKE2b256Hash(const Data: TBytes): TBytes;
var
  ctx: BLAKE2B_CTX;
begin
  Result := nil;
  SetLength(Result, 32);
  if Assigned(BLAKE2b_Init) and Assigned(BLAKE2b_Update) and Assigned(BLAKE2b_Final) then
  begin
    BLAKE2b_Init(@ctx, 32);
    if Length(Data) > 0 then
      BLAKE2b_Update(@ctx, @Data[0], Length(Data));
    BLAKE2b_Final(@ctx, @Result[0], 32);
  end
  else if Assigned(BLAKE2b) then
  begin
    if Length(Data) > 0 then
      BLAKE2b(@Result[0], 32, @Data[0], Length(Data), nil, 0)
    else
      BLAKE2b(@Result[0], 32, nil, 0, nil, 0);
  end
  else
    FillChar(Result[0], 32, 0);
end;

function BLAKE2b512Hash(const Data: TBytes): TBytes;
var
  ctx: BLAKE2B_CTX;
begin
  Result := nil;
  SetLength(Result, BLAKE2B_OUTBYTES);
  if Assigned(BLAKE2b_Init) and Assigned(BLAKE2b_Update) and Assigned(BLAKE2b_Final) then
  begin
    BLAKE2b_Init(@ctx, BLAKE2B_OUTBYTES);
    if Length(Data) > 0 then
      BLAKE2b_Update(@ctx, @Data[0], Length(Data));
    BLAKE2b_Final(@ctx, @Result[0], BLAKE2B_OUTBYTES);
  end
  else if Assigned(BLAKE2b) then
  begin
    if Length(Data) > 0 then
      BLAKE2b(@Result[0], BLAKE2B_OUTBYTES, @Data[0], Length(Data), nil, 0)
    else
      BLAKE2b(@Result[0], BLAKE2B_OUTBYTES, nil, 0, nil, 0);
  end
  else
    FillChar(Result[0], BLAKE2B_OUTBYTES, 0);
end;

function BLAKE2s256Hash(const Data: TBytes): TBytes;
var
  ctx: BLAKE2S_CTX;
begin
  Result := nil;
  SetLength(Result, BLAKE2S_OUTBYTES);
  if Assigned(BLAKE2s_Init) and Assigned(BLAKE2s_Update) and Assigned(BLAKE2s_Final) then
  begin
    BLAKE2s_Init(@ctx, BLAKE2S_OUTBYTES);
    if Length(Data) > 0 then
      BLAKE2s_Update(@ctx, @Data[0], Length(Data));
    BLAKE2s_Final(@ctx, @Result[0], BLAKE2S_OUTBYTES);
  end
  else if Assigned(BLAKE2s) then
  begin
    if Length(Data) > 0 then
      BLAKE2s(@Result[0], BLAKE2S_OUTBYTES, @Data[0], Length(Data), nil, 0)
    else
      BLAKE2s(@Result[0], BLAKE2S_OUTBYTES, nil, 0, nil, 0);
  end
  else
    FillChar(Result[0], BLAKE2S_OUTBYTES, 0);
end;

function BLAKE2bMAC(const Data: TBytes; const Key: TBytes; OutLen: Integer): TBytes;
var
  ctx: BLAKE2B_CTX;
begin
  Result := nil;
  if OutLen > BLAKE2B_OUTBYTES then
    OutLen := BLAKE2B_OUTBYTES;
  
  SetLength(Result, OutLen);
  if Assigned(BLAKE2b_Init_key) and Assigned(BLAKE2b_Update) and Assigned(BLAKE2b_Final) then
  begin
    if Length(Key) > 0 then
      BLAKE2b_Init_key(@ctx, OutLen, @Key[0], Length(Key))
    else
      BLAKE2b_Init(@ctx, OutLen);
    
    if Length(Data) > 0 then
      BLAKE2b_Update(@ctx, @Data[0], Length(Data));
    BLAKE2b_Final(@ctx, @Result[0], OutLen);
  end
  else if Assigned(BLAKE2b) then
  begin
    if (Length(Data) > 0) and (Length(Key) > 0) then
      BLAKE2b(@Result[0], OutLen, @Data[0], Length(Data), @Key[0], Length(Key))
    else if Length(Data) > 0 then
      BLAKE2b(@Result[0], OutLen, @Data[0], Length(Data), nil, 0)
    else
      BLAKE2b(@Result[0], OutLen, nil, 0, nil, 0);
  end
  else
    FillChar(Result[0], OutLen, 0);
end;

function BLAKE2sMAC(const Data: TBytes; const Key: TBytes; OutLen: Integer): TBytes;
var
  ctx: BLAKE2S_CTX;
begin
  Result := nil;
  if OutLen > BLAKE2S_OUTBYTES then
    OutLen := BLAKE2S_OUTBYTES;
  
  SetLength(Result, OutLen);
  if Assigned(BLAKE2s_Init_key) and Assigned(BLAKE2s_Update) and Assigned(BLAKE2s_Final) then
  begin
    if Length(Key) > 0 then
      BLAKE2s_Init_key(@ctx, OutLen, @Key[0], Length(Key))
    else
      BLAKE2s_Init(@ctx, OutLen);
    
    if Length(Data) > 0 then
      BLAKE2s_Update(@ctx, @Data[0], Length(Data));
    BLAKE2s_Final(@ctx, @Result[0], OutLen);
  end
  else if Assigned(BLAKE2s) then
  begin
    if (Length(Data) > 0) and (Length(Key) > 0) then
      BLAKE2s(@Result[0], OutLen, @Data[0], Length(Data), @Key[0], Length(Key))
    else if Length(Data) > 0 then
      BLAKE2s(@Result[0], OutLen, @Data[0], Length(Data), nil, 0)
    else
      BLAKE2s(@Result[0], OutLen, nil, 0, nil, 0);
  end
  else
    FillChar(Result[0], OutLen, 0);
end;

end.
