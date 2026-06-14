{******************************************************************************}
{                                                                              }
{  fafafa.ssl - OpenSSL SHA3 EVP Module (OpenSSL 3.x Compatible)             }
{                                                                              }
{  Copyright (c) 2024 fafafa                                                  }
{                                                                              }
{  This module provides SHA3 functionality using the EVP API, which is       }
{  compatible with both OpenSSL 1.1.1 and 3.x.                               }
{                                                                              }
{******************************************************************************}

unit nextpas.core.tls.openssl.api.sha3.evp;

{$mode ObjFPC}{$H+}

interface

uses Classes, nextpas.core.tls.base, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.evp;

const
  SHA3_224_DIGEST_LENGTH = 28;
  SHA3_256_DIGEST_LENGTH = 32;
  SHA3_384_DIGEST_LENGTH = 48;
  SHA3_512_DIGEST_LENGTH = 64;
  
  SHAKE128_DIGEST_LENGTH = 16;
  SHAKE256_DIGEST_LENGTH = 32;

type
  // EVP-based SHA3 context wrapper
  TSHA3EVPContext = class
  private
    FCtx: PEVP_MD_CTX;
    FMD: PEVP_MD;
    FAlgorithm: string;
    FIsXOF: Boolean; // Extended Output Function (for SHAKE)
    FUsesFetch: Boolean; // True if using EVP_MD_fetch
  public
    constructor Create(const Algorithm: string; IsXOF: Boolean = False);
    destructor Destroy; override;
    
    function Init: Boolean;
    function Update(const Data: Pointer; Len: NativeUInt): Boolean;
    function Final(Digest: PByte; var DigestLen: Cardinal): Boolean;
    function FinalXOF(OutputLen: NativeUInt; Output: PByte): Boolean;
    
    property IsXOF: Boolean read FIsXOF;
  end;

// High-level helper functions
function SHA3_224Hash_EVP(const Data: TBytes): TBytes;
function SHA3_256Hash_EVP(const Data: TBytes): TBytes;
function SHA3_384Hash_EVP(const Data: TBytes): TBytes;
function SHA3_512Hash_EVP(const Data: TBytes): TBytes;
function SHAKE128Hash_EVP(const Data: TBytes; OutLen: Integer): TBytes;
function SHAKE256Hash_EVP(const Data: TBytes; OutLen: Integer): TBytes;

// Check if EVP-based SHA3 is available
function IsEVPSHA3Available: Boolean;

implementation

uses nextpas.core.tls.openssl.api;

{ TSHA3EVPContext }

constructor TSHA3EVPContext.Create(const Algorithm: string; IsXOF: Boolean);
begin
  inherited Create;
  FAlgorithm := Algorithm;
  FIsXOF := IsXOF;
  FCtx := nil;
  FMD := nil;
  FUsesFetch := False;
end;

destructor TSHA3EVPContext.Destroy;
begin
  if Assigned(FCtx) then
  begin
    if Assigned(EVP_MD_CTX_free) then
      EVP_MD_CTX_free(FCtx);
    FCtx := nil;
  end;
  
  // Free the MD object if it was fetched
  if FUsesFetch and Assigned(FMD) and Assigned(EVP_MD_free) then
  begin
    EVP_MD_free(FMD);
    FMD := nil;
  end;
  
  inherited;
end;

function TSHA3EVPContext.Init: Boolean;
var
  AlgName: AnsiString;
begin
  Result := False;
  
  // Check if EVP functions are loaded
  if not Assigned(EVP_MD_CTX_new) or not Assigned(EVP_DigestInit_ex) then
    Exit;
  
  // Create context
  FCtx := EVP_MD_CTX_new();
  if FCtx = nil then
    Exit;
  
  // Try to get the algorithm using EVP_MD_fetch (OpenSSL 3.x)
  if Assigned(EVP_MD_fetch) then
  begin
    AlgName := AnsiString(FAlgorithm);
    FMD := EVP_MD_fetch(nil, PAnsiChar(AlgName), nil);
    if FMD <> nil then
      FUsesFetch := True;
  end;
  
  // If fetch failed or not available, try using EVP_get_digestbyname (1.1.1)
  if FMD = nil then
  begin
    if Assigned(EVP_get_digestbyname) then
    begin
      AlgName := AnsiString(FAlgorithm);
      FMD := EVP_get_digestbyname(PAnsiChar(AlgName));
      FUsesFetch := False;
    end;
  end;
  
  if FMD = nil then
    Exit;
  
  // Initialize digest
  Result := EVP_DigestInit_ex(FCtx, FMD, nil) = 1;
end;

function TSHA3EVPContext.Update(const Data: Pointer; Len: NativeUInt): Boolean;
begin
  Result := False;
  
  if (FCtx = nil) or not Assigned(EVP_DigestUpdate) then
    Exit;
  
  if (Data = nil) or (Len = 0) then
    Exit(True); // Empty update is valid
  
  Result := EVP_DigestUpdate(FCtx, Data, Len) = 1;
end;

function TSHA3EVPContext.Final(Digest: PByte; var DigestLen: Cardinal): Boolean;
begin
  Result := False;
  
  if (FCtx = nil) or not Assigned(EVP_DigestFinal_ex) then
    Exit;
  
  if Digest = nil then
    Exit;
  
  Result := EVP_DigestFinal_ex(FCtx, Digest, @DigestLen) = 1;
end;

function TSHA3EVPContext.FinalXOF(OutputLen: NativeUInt; Output: PByte): Boolean;
begin
  Result := False;
  
  if not FIsXOF then
    Exit; // Not an XOF algorithm
  
  if (FCtx = nil) or not Assigned(EVP_DigestFinalXOF) then
    Exit;
  
  if Output = nil then
    Exit;
  
  Result := EVP_DigestFinalXOF(FCtx, Output, OutputLen) = 1;
end;

{ High-level helper functions }

function SHA3_224Hash_EVP(const Data: TBytes): TBytes;
var
  ctx: TSHA3EVPContext;
  len: Cardinal;
begin
  Result := nil;
  SetLength(Result, SHA3_224_DIGEST_LENGTH);
  
  ctx := TSHA3EVPContext.Create('SHA3-224', False);
  try
    if ctx.Init then
    begin
      if Length(Data) > 0 then
        ctx.Update(@Data[0], Length(Data));
      
      len := SHA3_224_DIGEST_LENGTH;
      if not ctx.Final(@Result[0], len) then
        FillChar(Result[0], SHA3_224_DIGEST_LENGTH, 0);
    end
    else
      FillChar(Result[0], SHA3_224_DIGEST_LENGTH, 0);
  finally
    ctx.Free;
  end;
end;

function SHA3_256Hash_EVP(const Data: TBytes): TBytes;
var
  ctx: TSHA3EVPContext;
  len: Cardinal;
begin
  Result := nil;
  SetLength(Result, SHA3_256_DIGEST_LENGTH);
  
  ctx := TSHA3EVPContext.Create('SHA3-256', False);
  try
    if ctx.Init then
    begin
      if Length(Data) > 0 then
        ctx.Update(@Data[0], Length(Data));
      
      len := SHA3_256_DIGEST_LENGTH;
      if not ctx.Final(@Result[0], len) then
        FillChar(Result[0], SHA3_256_DIGEST_LENGTH, 0);
    end
    else
      FillChar(Result[0], SHA3_256_DIGEST_LENGTH, 0);
  finally
    ctx.Free;
  end;
end;

function SHA3_384Hash_EVP(const Data: TBytes): TBytes;
var
  ctx: TSHA3EVPContext;
  len: Cardinal;
begin
  Result := nil;
  SetLength(Result, SHA3_384_DIGEST_LENGTH);
  
  ctx := TSHA3EVPContext.Create('SHA3-384', False);
  try
    if ctx.Init then
    begin
      if Length(Data) > 0 then
        ctx.Update(@Data[0], Length(Data));
      
      len := SHA3_384_DIGEST_LENGTH;
      if not ctx.Final(@Result[0], len) then
        FillChar(Result[0], SHA3_384_DIGEST_LENGTH, 0);
    end
    else
      FillChar(Result[0], SHA3_384_DIGEST_LENGTH, 0);
  finally
    ctx.Free;
  end;
end;

function SHA3_512Hash_EVP(const Data: TBytes): TBytes;
var
  ctx: TSHA3EVPContext;
  len: Cardinal;
begin
  Result := nil;
  SetLength(Result, SHA3_512_DIGEST_LENGTH);
  
  ctx := TSHA3EVPContext.Create('SHA3-512', False);
  try
    if ctx.Init then
    begin
      if Length(Data) > 0 then
        ctx.Update(@Data[0], Length(Data));
      
      len := SHA3_512_DIGEST_LENGTH;
      if not ctx.Final(@Result[0], len) then
        FillChar(Result[0], SHA3_512_DIGEST_LENGTH, 0);
    end
    else
      FillChar(Result[0], SHA3_512_DIGEST_LENGTH, 0);
  finally
    ctx.Free;
  end;
end;

function SHAKE128Hash_EVP(const Data: TBytes; OutLen: Integer): TBytes;
var
  ctx: TSHA3EVPContext;
begin
  Result := nil;
  SetLength(Result, OutLen);
  
  ctx := TSHA3EVPContext.Create('SHAKE128', True);
  try
    if ctx.Init then
    begin
      if Length(Data) > 0 then
        ctx.Update(@Data[0], Length(Data));
      
      if not ctx.FinalXOF(OutLen, @Result[0]) then
        FillChar(Result[0], OutLen, 0);
    end
    else
      FillChar(Result[0], OutLen, 0);
  finally
    ctx.Free;
  end;
end;

function SHAKE256Hash_EVP(const Data: TBytes; OutLen: Integer): TBytes;
var
  ctx: TSHA3EVPContext;
begin
  Result := nil;
  SetLength(Result, OutLen);
  
  ctx := TSHA3EVPContext.Create('SHAKE256', True);
  try
    if ctx.Init then
    begin
      if Length(Data) > 0 then
        ctx.Update(@Data[0], Length(Data));
      
      if not ctx.FinalXOF(OutLen, @Result[0]) then
        FillChar(Result[0], OutLen, 0);
    end
    else
      FillChar(Result[0], OutLen, 0);
  finally
    ctx.Free;
  end;
end;

function IsEVPSHA3Available: Boolean;
var
  md: PEVP_MD;
  AlgName: AnsiString;
begin
  Result := False;
  
  // Check if EVP functions are loaded
  if not Assigned(EVP_MD_CTX_new) or not Assigned(EVP_DigestInit_ex) then
    Exit;
  
  // Try EVP_MD_fetch first (OpenSSL 3.x)
  if Assigned(EVP_MD_fetch) and Assigned(EVP_MD_free) then
  begin
    AlgName := 'SHA3-256';
    md := EVP_MD_fetch(nil, PAnsiChar(AlgName), nil);
    if md <> nil then
    begin
      EVP_MD_free(md);
      Exit(True);
    end;
  end;
  
  // Try EVP_get_digestbyname (OpenSSL 1.1.1)
  if Assigned(EVP_get_digestbyname) then
  begin
    AlgName := 'SHA3-256';
    md := EVP_get_digestbyname(PAnsiChar(AlgName));
    Result := md <> nil;
  end;
end;

end.
