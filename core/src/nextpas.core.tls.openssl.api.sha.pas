{******************************************************************************}
{                                                                              }
{  fafafa.ssl - OpenSSL SHA Module                                           }
{                                                                              }
{  Copyright (c) 2024 fafafa                                                  }
{                                                                              }
{******************************************************************************}

unit nextpas.core.tls.openssl.api.sha;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.base,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.text.conv,
  nextpas.core.tls.openssl.loader;

const
  SHA_DIGEST_LENGTH = 20;
  SHA_LBLOCK = 16;
  SHA_CBLOCK = 64;
  
  SHA224_DIGEST_LENGTH = 28;
  SHA256_DIGEST_LENGTH = 32;
  SHA256_CBLOCK = 64;
  
  SHA384_DIGEST_LENGTH = 48;
  SHA512_DIGEST_LENGTH = 64;
  SHA512_CBLOCK = 128;
  
  SHA512_224_DIGEST_LENGTH = 28;
  SHA512_256_DIGEST_LENGTH = 32;

type
  // SHA-1 context
  PSHA_CTX = ^SHA_CTX;
  SHA_CTX = record
    h0, h1, h2, h3, h4: Cardinal;
    Nl, Nh: Cardinal;
    data: array[0..SHA_LBLOCK-1] of Cardinal;
    num: Cardinal;
  end;
  
  // SHA-256 context
  PSHA256_CTX = ^SHA256_CTX;
  SHA256_CTX = record
    h: array[0..7] of Cardinal;
    Nl, Nh: Cardinal;
    data: array[0..SHA_LBLOCK-1] of Cardinal;
    num: Cardinal;
    md_len: Cardinal;
  end;
  
  // SHA-512 context
  PSHA512_CTX = ^SHA512_CTX;
  SHA512_CTX = record
    h: array[0..7] of UInt64;
    Nl, Nh: UInt64;
    u: record
      case Integer of
        0: (d: array[0..SHA_LBLOCK-1] of UInt64);
        1: (p: array[0..SHA512_CBLOCK-1] of Byte);
    end;
    num: Cardinal;
    md_len: Cardinal;
  end;
  
  // SHA-224 uses SHA256_CTX
  SHA224_CTX = SHA256_CTX;
  PSHA224_CTX = ^SHA224_CTX;
  
  // SHA-384 uses SHA512_CTX
  SHA384_CTX = SHA512_CTX;
  PSHA384_CTX = ^SHA384_CTX;
  
  // SHA-512/224 uses SHA512_CTX
  SHA512_224_CTX = SHA512_CTX;
  PSHA512_224_CTX = ^SHA512_224_CTX;
  
  // SHA-512/256 uses SHA512_CTX
  SHA512_256_CTX = SHA512_CTX;
  PSHA512_256_CTX = ^SHA512_256_CTX;

type
  // SHA-1 functions
  TSHA1_Init = function(c: PSHA_CTX): Integer; cdecl;
  TSHA1_Update = function(c: PSHA_CTX; const data: Pointer; len: NativeUInt): Integer; cdecl;
  TSHA1_Final = function(md: PByte; c: PSHA_CTX): Integer; cdecl;
  TSHA1 = function(const d: PByte; n: NativeUInt; md: PByte): PByte; cdecl;
  TSHA1_Transform = procedure(c: PSHA_CTX; const data: PByte); cdecl;
  
  // SHA-224 functions
  TSHA224_Init = function(c: PSHA256_CTX): Integer; cdecl;
  TSHA224_Update = function(c: PSHA256_CTX; const data: Pointer; len: NativeUInt): Integer; cdecl;
  TSHA224_Final = function(md: PByte; c: PSHA256_CTX): Integer; cdecl;
  TSHA224 = function(const d: PByte; n: NativeUInt; md: PByte): PByte; cdecl;
  
  // SHA-256 functions
  TSHA256_Init = function(c: PSHA256_CTX): Integer; cdecl;
  TSHA256_Update = function(c: PSHA256_CTX; const data: Pointer; len: NativeUInt): Integer; cdecl;
  TSHA256_Final = function(md: PByte; c: PSHA256_CTX): Integer; cdecl;
  TSHA256 = function(const d: PByte; n: NativeUInt; md: PByte): PByte; cdecl;
  TSHA256_Transform = procedure(c: PSHA256_CTX; const data: PByte); cdecl;
  
  // SHA-384 functions
  TSHA384_Init = function(c: PSHA512_CTX): Integer; cdecl;
  TSHA384_Update = function(c: PSHA512_CTX; const data: Pointer; len: NativeUInt): Integer; cdecl;
  TSHA384_Final = function(md: PByte; c: PSHA512_CTX): Integer; cdecl;
  TSHA384 = function(const d: PByte; n: NativeUInt; md: PByte): PByte; cdecl;
  
  // SHA-512 functions
  TSHA512_Init = function(c: PSHA512_CTX): Integer; cdecl;
  TSHA512_Update = function(c: PSHA512_CTX; const data: Pointer; len: NativeUInt): Integer; cdecl;
  TSHA512_Final = function(md: PByte; c: PSHA512_CTX): Integer; cdecl;
  TSHA512 = function(const d: PByte; n: NativeUInt; md: PByte): PByte; cdecl;
  TSHA512_Transform = procedure(c: PSHA512_CTX; const data: PByte); cdecl;
  
  // SHA-512/224 functions
  TSHA512_224_Init = function(c: PSHA512_CTX): Integer; cdecl;
  TSHA512_224_Update = function(c: PSHA512_CTX; const data: Pointer; len: NativeUInt): Integer; cdecl;
  TSHA512_224_Final = function(md: PByte; c: PSHA512_CTX): Integer; cdecl;
  TSHA512_224 = function(const d: PByte; n: NativeUInt; md: PByte): PByte; cdecl;
  
  // SHA-512/256 functions
  TSHA512_256_Init = function(c: PSHA512_CTX): Integer; cdecl;
  TSHA512_256_Update = function(c: PSHA512_CTX; const data: Pointer; len: NativeUInt): Integer; cdecl;
  TSHA512_256_Final = function(md: PByte; c: PSHA512_CTX): Integer; cdecl;
  TSHA512_256 = function(const d: PByte; n: NativeUInt; md: PByte): PByte; cdecl;

var
  // SHA-1 function pointers
  SHA1_Init: TSHA1_Init = nil;
  SHA1_Update: TSHA1_Update = nil;
  SHA1_Final: TSHA1_Final = nil;
  SHA1: TSHA1 = nil;
  SHA1_Transform: TSHA1_Transform = nil;
  
  // SHA-224 function pointers
  SHA224_Init: TSHA224_Init = nil;
  SHA224_Update: TSHA224_Update = nil;
  SHA224_Final: TSHA224_Final = nil;
  SHA224: TSHA224 = nil;
  
  // SHA-256 function pointers
  SHA256_Init: TSHA256_Init = nil;
  SHA256_Update: TSHA256_Update = nil;
  SHA256_Final: TSHA256_Final = nil;
  SHA256: TSHA256 = nil;
  SHA256_Transform: TSHA256_Transform = nil;
  
  // SHA-384 function pointers
  SHA384_Init: TSHA384_Init = nil;
  SHA384_Update: TSHA384_Update = nil;
  SHA384_Final: TSHA384_Final = nil;
  SHA384: TSHA384 = nil;
  
  // SHA-512 function pointers
  SHA512_Init: TSHA512_Init = nil;
  SHA512_Update: TSHA512_Update = nil;
  SHA512_Final: TSHA512_Final = nil;
  SHA512: TSHA512 = nil;
  SHA512_Transform: TSHA512_Transform = nil;
  
  // SHA-512/224 function pointers
  SHA512_224_Init: TSHA512_224_Init = nil;
  SHA512_224_Update: TSHA512_224_Update = nil;
  SHA512_224_Final: TSHA512_224_Final = nil;
  SHA512_224: TSHA512_224 = nil;
  
  // SHA-512/256 function pointers
  SHA512_256_Init: TSHA512_256_Init = nil;
  SHA512_256_Update: TSHA512_256_Update = nil;
  SHA512_256_Final: TSHA512_256_Final = nil;
  SHA512_256: TSHA512_256 = nil;

// Helper functions
function LoadSHAFunctions(ALibHandle: TOpenSSLLibHandle): Boolean;
procedure UnloadSHAFunctions;

// High-level helper functions
function SHA1Hash(const Data: TBytes): TBytes;
function SHA256Hash(const Data: TBytes): TBytes;
function SHA384Hash(const Data: TBytes): TBytes;
function SHA512Hash(const Data: TBytes): TBytes;
function SHA1HashString(const S: string): string;
function SHA256HashString(const S: string): string;
function SHA384HashString(const S: string): string;
function SHA512HashString(const S: string): string;

implementation

uses nextpas.core.tls.openssl.api;

const
  { SHA 函数绑定数组 - 用于批量加载 }
  SHA_FUNCTION_BINDINGS: array[0..29] of TFunctionBinding = (
    // SHA-1 functions
    (Name: 'SHA1_Init';       FuncPtr: @SHA1_Init;       Required: True),
    (Name: 'SHA1_Update';     FuncPtr: @SHA1_Update;     Required: True),
    (Name: 'SHA1_Final';      FuncPtr: @SHA1_Final;      Required: True),
    (Name: 'SHA1';            FuncPtr: @SHA1;            Required: False),
    (Name: 'SHA1_Transform';  FuncPtr: @SHA1_Transform;  Required: False),
    // SHA-224 functions
    (Name: 'SHA224_Init';     FuncPtr: @SHA224_Init;     Required: False),
    (Name: 'SHA224_Update';   FuncPtr: @SHA224_Update;   Required: False),
    (Name: 'SHA224_Final';    FuncPtr: @SHA224_Final;    Required: False),
    (Name: 'SHA224';          FuncPtr: @SHA224;          Required: True),
    // SHA-256 functions
    (Name: 'SHA256_Init';     FuncPtr: @SHA256_Init;     Required: True),
    (Name: 'SHA256_Update';   FuncPtr: @SHA256_Update;   Required: True),
    (Name: 'SHA256_Final';    FuncPtr: @SHA256_Final;    Required: True),
    (Name: 'SHA256';          FuncPtr: @SHA256;          Required: False),
    (Name: 'SHA256_Transform'; FuncPtr: @SHA256_Transform; Required: False),
    // SHA-384 functions
    (Name: 'SHA384_Init';     FuncPtr: @SHA384_Init;     Required: True),
    (Name: 'SHA384_Update';   FuncPtr: @SHA384_Update;   Required: True),
    (Name: 'SHA384_Final';    FuncPtr: @SHA384_Final;    Required: True),
    (Name: 'SHA384';          FuncPtr: @SHA384;          Required: False),
    // SHA-512 functions
    (Name: 'SHA512_Init';     FuncPtr: @SHA512_Init;     Required: True),
    (Name: 'SHA512_Update';   FuncPtr: @SHA512_Update;   Required: True),
    (Name: 'SHA512_Final';    FuncPtr: @SHA512_Final;    Required: True),
    (Name: 'SHA512';          FuncPtr: @SHA512;          Required: False),
    (Name: 'SHA512_Transform'; FuncPtr: @SHA512_Transform; Required: False),
    // SHA-512/224 functions
    (Name: 'SHA512_224_Init';   FuncPtr: @SHA512_224_Init;   Required: False),
    (Name: 'SHA512_224_Update'; FuncPtr: @SHA512_224_Update; Required: False),
    (Name: 'SHA512_224_Final';  FuncPtr: @SHA512_224_Final;  Required: False),
    (Name: 'SHA512_224';        FuncPtr: @SHA512_224;        Required: False),
    // SHA-512/256 functions
    (Name: 'SHA512_256_Init';   FuncPtr: @SHA512_256_Init;   Required: False),
    (Name: 'SHA512_256_Update'; FuncPtr: @SHA512_256_Update; Required: False),
    (Name: 'SHA512_256_Final';  FuncPtr: @SHA512_256_Final;  Required: False)
  );

function LoadSHAFunctions(ALibHandle: TOpenSSLLibHandle): Boolean;
begin
  Result := False;

  if ALibHandle = 0 then Exit;

  // 使用批量加载模式
  if TOpenSSLLoader.LoadFunctions(ALibHandle, SHA_FUNCTION_BINDINGS) < 0 then
  begin
    TOpenSSLLoader.SetModuleLoaded(osmSHA, False);
    Exit(False);
  end;

  TOpenSSLLoader.SetModuleLoaded(osmSHA, True);
  Result := True;
end;

procedure UnloadSHAFunctions;
begin
  // 使用批量清除模式
  TOpenSSLLoader.ClearFunctions(SHA_FUNCTION_BINDINGS);

  TOpenSSLLoader.SetModuleLoaded(osmSHA, False);
end;


// Helper function implementations
function SHA1Hash(const Data: TBytes): TBytes;
var
  ctx: SHA_CTX;
begin
  Result := nil;
  SetLength(Result, SHA_DIGEST_LENGTH);
  if Assigned(SHA1_Init) and Assigned(SHA1_Update) and Assigned(SHA1_Final) then
  begin
    SHA1_Init(@ctx);
    if Length(Data) > 0 then
      SHA1_Update(@ctx, @Data[0], Length(Data));
    SHA1_Final(@Result[0], @ctx);
  end
  else
    FillChar(Result[0], SHA_DIGEST_LENGTH, 0);
end;

function SHA256Hash(const Data: TBytes): TBytes;
var
  ctx: SHA256_CTX;
begin
  Result := nil;
  SetLength(Result, SHA256_DIGEST_LENGTH);
  if Assigned(SHA256_Init) and Assigned(SHA256_Update) and Assigned(SHA256_Final) then
  begin
    SHA256_Init(@ctx);
    if Length(Data) > 0 then
      SHA256_Update(@ctx, @Data[0], Length(Data));
    SHA256_Final(@Result[0], @ctx);
  end
  else
    FillChar(Result[0], SHA256_DIGEST_LENGTH, 0);
end;

function SHA384Hash(const Data: TBytes): TBytes;
var
  ctx: SHA512_CTX;
begin
  Result := nil;
  SetLength(Result, SHA384_DIGEST_LENGTH);
  if Assigned(SHA384_Init) and Assigned(SHA384_Update) and Assigned(SHA384_Final) then
  begin
    SHA384_Init(@ctx);
    if Length(Data) > 0 then
      SHA384_Update(@ctx, @Data[0], Length(Data));
    SHA384_Final(@Result[0], @ctx);
  end
  else
    FillChar(Result[0], SHA384_DIGEST_LENGTH, 0);
end;

function SHA512Hash(const Data: TBytes): TBytes;
var
  ctx: SHA512_CTX;
begin
  Result := nil;
  SetLength(Result, SHA512_DIGEST_LENGTH);
  if Assigned(SHA512_Init) and Assigned(SHA512_Update) and Assigned(SHA512_Final) then
  begin
    SHA512_Init(@ctx);
    if Length(Data) > 0 then
      SHA512_Update(@ctx, @Data[0], Length(Data));
    SHA512_Final(@Result[0], @ctx);
  end
  else
    FillChar(Result[0], SHA512_DIGEST_LENGTH, 0);
end;

function BytesToHex(const Bytes: TBytes): string;
const
  HexChars: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, Length(Bytes) * 2);
  for I := 0 to High(Bytes) do
  begin
    Result[I * 2 + 1] := HexChars[Bytes[I] shr 4];
    Result[I * 2 + 2] := HexChars[Bytes[I] and $0F];
  end;
end;

function SHA1HashString(const S: string): string;
var
  Data: TBytes;
begin
  Data := nextpas.core.text.conv.StringToUTF8Bytes(S);
  Result := BytesToHex(SHA1Hash(Data));
end;

function SHA256HashString(const S: string): string;
var
  Data: TBytes;
begin
  Data := nextpas.core.text.conv.StringToUTF8Bytes(S);
  Result := BytesToHex(SHA256Hash(Data));
end;

function SHA384HashString(const S: string): string;
var
  Data: TBytes;
begin
  Data := nextpas.core.text.conv.StringToUTF8Bytes(S);
  Result := BytesToHex(SHA384Hash(Data));
end;

function SHA512HashString(const S: string): string;
var
  Data: TBytes;
begin
  Data := nextpas.core.text.conv.StringToUTF8Bytes(S);
  Result := BytesToHex(SHA512Hash(Data));
end;

end.
