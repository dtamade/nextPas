{******************************************************************************}
{                                                                              }
{  fafafa.ssl - OpenSSL MD (Message Digest) Module                           }
{                                                                              }
{  Copyright (c) 2024 fafafa                                                  }
{                                                                              }
{******************************************************************************}

unit nextpas.core.tls.openssl.api.md;

{$mode ObjFPC}{$H+}

interface

uses SysUtils, nextpas.core.tls.base, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.consts, nextpas.core.tls.openssl.loader;

const
  MD4_DIGEST_LENGTH = 16;
  MD4_CBLOCK = 64;
  MD4_LBLOCK = 16;
  
  MD5_DIGEST_LENGTH = 16;
  MD5_CBLOCK = 64;
  MD5_LBLOCK = 16;
  
  MDC2_BLOCK = 8;
  MDC2_DIGEST_LENGTH = 16;
  
  RIPEMD160_DIGEST_LENGTH = 20;
  RIPEMD160_CBLOCK = 64;
  RIPEMD160_LBLOCK = 16;

type
  // DES types needed for MDC2
  DES_cblock = array[0..7] of Byte;
  // MD4 context
  PMD4_CTX = ^MD4_CTX;
  MD4_CTX = record
    A, B, C, D: Cardinal;
    Nl, Nh: Cardinal;
    data: array[0..MD4_LBLOCK-1] of Cardinal;
    num: Cardinal;
  end;
  
  // MD5 context
  PMD5_CTX = ^MD5_CTX;
  MD5_CTX = record
    A, B, C, D: Cardinal;
    Nl, Nh: Cardinal;
    data: array[0..MD5_LBLOCK-1] of Cardinal;
    num: Cardinal;
  end;
  
  // MDC2 context
  PMDC2_CTX = ^MDC2_CTX;
  MDC2_CTX = record
    num: Cardinal;
    data: array[0..MDC2_BLOCK-1] of Byte;
    h: DES_cblock;
    hh: DES_cblock;
    pad_type: Integer;
  end;
  
  // RIPEMD160 context
  PRIPEMD160_CTX = ^RIPEMD160_CTX;
  RIPEMD160_CTX = record
    A, B, C, D, E: Cardinal;
    Nl, Nh: Cardinal;
    data: array[0..RIPEMD160_LBLOCK-1] of Cardinal;
    num: Cardinal;
  end;

type
  // MD4 functions
  TMD4_Init = function(c: PMD4_CTX): Integer; cdecl;
  TMD4_Update = function(c: PMD4_CTX; const data: Pointer; len: NativeUInt): Integer; cdecl;
  TMD4_Final = function(md: PByte; c: PMD4_CTX): Integer; cdecl;
  TMD4 = function(const d: PByte; n: NativeUInt; md: PByte): PByte; cdecl;
  TMD4_Transform = procedure(c: PMD4_CTX; const b: PByte); cdecl;
  
  // MD5 functions
  TMD5_Init = function(c: PMD5_CTX): Integer; cdecl;
  TMD5_Update = function(c: PMD5_CTX; const data: Pointer; len: NativeUInt): Integer; cdecl;
  TMD5_Final = function(md: PByte; c: PMD5_CTX): Integer; cdecl;
  TMD5 = function(const d: PByte; n: NativeUInt; md: PByte): PByte; cdecl;
  TMD5_Transform = procedure(c: PMD5_CTX; const b: PByte); cdecl;
  
  // MDC2 functions
  TMDC2_Init = function(c: PMDC2_CTX): Integer; cdecl;
  TMDC2_Update = function(c: PMDC2_CTX; const data: Pointer; len: NativeUInt): Integer; cdecl;
  TMDC2_Final = function(md: PByte; c: PMDC2_CTX): Integer; cdecl;
  TMDC2 = function(const d: PByte; n: NativeUInt; md: PByte): PByte; cdecl;
  
  // RIPEMD160 functions
  TRIPEMD160_Init = function(c: PRIPEMD160_CTX): Integer; cdecl;
  TRIPEMD160_Update = function(c: PRIPEMD160_CTX; const data: Pointer; len: NativeUInt): Integer; cdecl;
  TRIPEMD160_Final = function(md: PByte; c: PRIPEMD160_CTX): Integer; cdecl;
  TRIPEMD160 = function(const d: PByte; n: NativeUInt; md: PByte): PByte; cdecl;
  TRIPEMD160_Transform = procedure(c: PRIPEMD160_CTX; const b: PByte); cdecl;

var
  // MD4 function pointers
  MD4_Init: TMD4_Init = nil;
  MD4_Update: TMD4_Update = nil;
  MD4_Final: TMD4_Final = nil;
  MD4: TMD4 = nil;
  MD4_Transform: TMD4_Transform = nil;
  
  // MD5 function pointers
  MD5_Init: TMD5_Init = nil;
  MD5_Update: TMD5_Update = nil;
  MD5_Final: TMD5_Final = nil;
  MD5: TMD5 = nil;
  MD5_Transform: TMD5_Transform = nil;
  
  // MDC2 function pointers
  MDC2_Init: TMDC2_Init = nil;
  MDC2_Update: TMDC2_Update = nil;
  MDC2_Final: TMDC2_Final = nil;
  MDC2: TMDC2 = nil;
  
  // RIPEMD160 function pointers
  RIPEMD160_Init: TRIPEMD160_Init = nil;
  RIPEMD160_Update: TRIPEMD160_Update = nil;
  RIPEMD160_Final: TRIPEMD160_Final = nil;
  RIPEMD160: TRIPEMD160 = nil;
  RIPEMD160_Transform: TRIPEMD160_Transform = nil;

// Helper functions
function LoadMDFunctions(ALibHandle: TOpenSSLLibHandle): Boolean;
procedure UnloadMDFunctions;

// High-level helper functions
function MD4Hash(const Data: TBytes): TBytes;
function MD5Hash(const Data: TBytes): TBytes;
function MDC2Hash(const Data: TBytes): TBytes;
function RIPEMD160Hash(const Data: TBytes): TBytes;
function MD4HashString(const S: string): string;
function MD5HashString(const S: string): string;
function MDC2HashString(const S: string): string;
function RIPEMD160HashString(const S: string): string;

implementation

uses nextpas.core.tls.openssl.api;

const
  { Function bindings for batch loading }
  MDBindings: array[0..18] of TFunctionBinding = (
    // MD4 functions
    (Name: 'MD4_Init';      FuncPtr: @MD4_Init;      Required: False),
    (Name: 'MD4_Update';    FuncPtr: @MD4_Update;    Required: False),
    (Name: 'MD4_Final';     FuncPtr: @MD4_Final;     Required: False),
    (Name: 'MD4';           FuncPtr: @MD4;           Required: False),
    (Name: 'MD4_Transform'; FuncPtr: @MD4_Transform; Required: False),
    // MD5 functions
    (Name: 'MD5_Init';      FuncPtr: @MD5_Init;      Required: False),
    (Name: 'MD5_Update';    FuncPtr: @MD5_Update;    Required: False),
    (Name: 'MD5_Final';     FuncPtr: @MD5_Final;     Required: False),
    (Name: 'MD5';           FuncPtr: @MD5;           Required: False),
    (Name: 'MD5_Transform'; FuncPtr: @MD5_Transform; Required: False),
    // MDC2 functions
    (Name: 'MDC2_Init';     FuncPtr: @MDC2_Init;     Required: False),
    (Name: 'MDC2_Update';   FuncPtr: @MDC2_Update;   Required: False),
    (Name: 'MDC2_Final';    FuncPtr: @MDC2_Final;    Required: False),
    (Name: 'MDC2';          FuncPtr: @MDC2;          Required: False),
    // RIPEMD160 functions
    (Name: 'RIPEMD160_Init';      FuncPtr: @RIPEMD160_Init;      Required: False),
    (Name: 'RIPEMD160_Update';    FuncPtr: @RIPEMD160_Update;    Required: False),
    (Name: 'RIPEMD160_Final';     FuncPtr: @RIPEMD160_Final;     Required: False),
    (Name: 'RIPEMD160';           FuncPtr: @RIPEMD160;           Required: False),
    (Name: 'RIPEMD160_Transform'; FuncPtr: @RIPEMD160_Transform; Required: False)
  );

function LoadMDFunctions(ALibHandle: TOpenSSLLibHandle): Boolean;
begin
  Result := False;
  if ALibHandle = 0 then Exit;

  TOpenSSLLoader.LoadFunctions(ALibHandle, MDBindings);
  TOpenSSLLoader.SetModuleLoaded(osmMD, True);
  Result := True;
end;

procedure UnloadMDFunctions;
begin
  TOpenSSLLoader.ClearFunctions(MDBindings);
  TOpenSSLLoader.SetModuleLoaded(osmMD, False);
end;


// Helper function implementations
function MD4Hash(const Data: TBytes): TBytes;
var
  ctx: MD4_CTX;
begin
  Result := nil;
  SetLength(Result, MD4_DIGEST_LENGTH);
  if Assigned(MD4_Init) and Assigned(MD4_Update) and Assigned(MD4_Final) then
  begin
    MD4_Init(@ctx);
    if Length(Data) > 0 then
      MD4_Update(@ctx, @Data[0], Length(Data));
    MD4_Final(@Result[0], @ctx);
  end
  else
    FillChar(Result[0], MD4_DIGEST_LENGTH, 0);
end;

function MD5Hash(const Data: TBytes): TBytes;
var
  ctx: MD5_CTX;
begin
  Result := nil;
  SetLength(Result, MD5_DIGEST_LENGTH);
  if Assigned(MD5_Init) and Assigned(MD5_Update) and Assigned(MD5_Final) then
  begin
    MD5_Init(@ctx);
    if Length(Data) > 0 then
      MD5_Update(@ctx, @Data[0], Length(Data));
    MD5_Final(@Result[0], @ctx);
  end
  else
    FillChar(Result[0], MD5_DIGEST_LENGTH, 0);
end;

function MDC2Hash(const Data: TBytes): TBytes;
var
  ctx: MDC2_CTX;
begin
  Result := nil;
  SetLength(Result, MDC2_DIGEST_LENGTH);
  if Assigned(MDC2_Init) and Assigned(MDC2_Update) and Assigned(MDC2_Final) then
  begin
    MDC2_Init(@ctx);
    if Length(Data) > 0 then
      MDC2_Update(@ctx, @Data[0], Length(Data));
    MDC2_Final(@Result[0], @ctx);
  end
  else
    FillChar(Result[0], MDC2_DIGEST_LENGTH, 0);
end;

function RIPEMD160Hash(const Data: TBytes): TBytes;
var
  ctx: RIPEMD160_CTX;
begin
  Result := nil;
  SetLength(Result, RIPEMD160_DIGEST_LENGTH);
  if Assigned(RIPEMD160_Init) and Assigned(RIPEMD160_Update) and Assigned(RIPEMD160_Final) then
  begin
    RIPEMD160_Init(@ctx);
    if Length(Data) > 0 then
      RIPEMD160_Update(@ctx, @Data[0], Length(Data));
    RIPEMD160_Final(@Result[0], @ctx);
  end
  else
    FillChar(Result[0], RIPEMD160_DIGEST_LENGTH, 0);
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

function MD4HashString(const S: string): string;
var
  Data: TBytes;
begin
  Data := nextpas.core.text.conv.StringToUTF8Bytes(S));
  Result := BytesToHex(MD4Hash(Data));
end;

function MD5HashString(const S: string): string;
var
  Data: TBytes;
begin
  Data := nextpas.core.text.conv.StringToUTF8Bytes(S));
  Result := BytesToHex(MD5Hash(Data));
end;

function MDC2HashString(const S: string): string;
var
  Data: TBytes;
begin
  Data := nextpas.core.text.conv.StringToUTF8Bytes(S));
  Result := BytesToHex(MDC2Hash(Data));
end;

function RIPEMD160HashString(const S: string): string;
var
  Data: TBytes;
begin
  Data := nextpas.core.text.conv.StringToUTF8Bytes(S));
  Result := BytesToHex(RIPEMD160Hash(Data));
end;

end.
