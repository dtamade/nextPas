{******************************************************************************}
{  fafafa.ssl - OpenSSL CMAC EVP Module (OpenSSL 3.x Compatible)             }
{  Copyright (c) 2024 fafafa                                                  }
{******************************************************************************}

unit nextpas.core.tls.openssl.api.cmac.evp;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.evp;

const
  CMAC_MAX_SIZE = 32;

type
  TCMACEVPContext = class
  private
    FMac: PEVP_MAC;
    FCtx: PEVP_MAC_CTX;
    FCipherName: string;
    FUsesFetch: Boolean;
    FInitialized: Boolean;
  public
    constructor Create(const CipherName: string = 'AES-128-CBC');
    destructor Destroy; override;
    
    function Init(const Key: TBytes): Boolean;
    function Update(const Data: Pointer; Len: NativeUInt): Boolean; overload;
    function Update(const Data: TBytes): Boolean; overload;
    function Final(Mac: PByte; var MacLen: NativeUInt): Boolean;
    function FinalBytes: TBytes;
    
    property CipherName: string read FCipherName;
    property Initialized: Boolean read FInitialized;
  end;

function CMAC_AES128_EVP(const Key: TBytes; const Data: TBytes): TBytes;
function CMAC_AES192_EVP(const Key: TBytes; const Data: TBytes): TBytes;
function CMAC_AES256_EVP(const Key: TBytes; const Data: TBytes): TBytes;
function ComputeCMAC_EVP(const CipherName: string; const Key: TBytes; const Data: TBytes): TBytes;
function IsEVPCMACAvailable: Boolean;

implementation

uses
  nextpas.core.tls.openssl.api.core;

type
  TEVP_MAC_fetch = function(ctx: POSSL_LIB_CTX; const algorithm: PAnsiChar; const properties: PAnsiChar): PEVP_MAC; cdecl;
  TEVP_MAC_free = procedure(mac: PEVP_MAC); cdecl;
  TEVP_MAC_CTX_new = function(mac: PEVP_MAC): PEVP_MAC_CTX; cdecl;
  TEVP_MAC_CTX_free = procedure(ctx: PEVP_MAC_CTX); cdecl;
  TEVP_MAC_init = function(ctx: PEVP_MAC_CTX; const key: PByte; keylen: NativeUInt; const params: POSSL_PARAM): Integer; cdecl;
  TEVP_MAC_update = function(ctx: PEVP_MAC_CTX; const data: PByte; datalen: NativeUInt): Integer; cdecl;
  TEVP_MAC_final = function(ctx: PEVP_MAC_CTX; out_mac: PByte; outl: PNativeUInt; outsize: NativeUInt): Integer; cdecl;
  TEVP_MAC_CTX_get_mac_size = function(ctx: PEVP_MAC_CTX): NativeUInt; cdecl;
  TOSSL_PARAM_construct_utf8_string = function(key: PAnsiChar; buf: PAnsiChar; bsize: NativeUInt): OSSL_PARAM; cdecl;
  TOSSL_PARAM_construct_end = function: OSSL_PARAM; cdecl;

var
  EVP_MAC_fetch: TEVP_MAC_fetch = nil;
  EVP_MAC_free: TEVP_MAC_free = nil;
  EVP_MAC_CTX_new: TEVP_MAC_CTX_new = nil;
  EVP_MAC_CTX_free: TEVP_MAC_CTX_free = nil;
  EVP_MAC_init: TEVP_MAC_init = nil;
  EVP_MAC_update: TEVP_MAC_update = nil;
  EVP_MAC_final: TEVP_MAC_final = nil;
  EVP_MAC_CTX_get_mac_size: TEVP_MAC_CTX_get_mac_size = nil;
  OSSL_PARAM_construct_utf8_string: TOSSL_PARAM_construct_utf8_string = nil;
  OSSL_PARAM_construct_end: TOSSL_PARAM_construct_end = nil;

const
  { CMAC EVP function bindings for batch loading }
  CMAC_EVP_BINDINGS: array[0..9] of TFunctionBinding = (
    (Name: 'EVP_MAC_fetch';                  FuncPtr: @EVP_MAC_fetch;                  Required: True),
    (Name: 'EVP_MAC_free';                   FuncPtr: @EVP_MAC_free;                   Required: False),
    (Name: 'EVP_MAC_CTX_new';                FuncPtr: @EVP_MAC_CTX_new;                Required: True),
    (Name: 'EVP_MAC_CTX_free';               FuncPtr: @EVP_MAC_CTX_free;               Required: False),
    (Name: 'EVP_MAC_init';                   FuncPtr: @EVP_MAC_init;                   Required: True),
    (Name: 'EVP_MAC_update';                 FuncPtr: @EVP_MAC_update;                 Required: True),
    (Name: 'EVP_MAC_final';                  FuncPtr: @EVP_MAC_final;                  Required: True),
    (Name: 'EVP_MAC_CTX_get_mac_size';       FuncPtr: @EVP_MAC_CTX_get_mac_size;       Required: False),
    (Name: 'OSSL_PARAM_construct_utf8_string'; FuncPtr: @OSSL_PARAM_construct_utf8_string; Required: False),
    (Name: 'OSSL_PARAM_construct_end';       FuncPtr: @OSSL_PARAM_construct_end;       Required: False)
  );

procedure LoadFunctions;
var
  LLib: TLibHandle;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmCMAC) then Exit;

  // Use the crypto library handle from core module
  LLib := GetCryptoLibHandle;
  if LLib = NilHandle then
  begin
    // Try to load core first
    LoadOpenSSLCore;
    LLib := GetCryptoLibHandle;
  end;

  if LLib = NilHandle then Exit;

  // Load CMAC EVP functions using batch loading
  TOpenSSLLoader.LoadFunctions(LLib, CMAC_EVP_BINDINGS);

  TOpenSSLLoader.SetModuleLoaded(osmCMAC, Assigned(EVP_MAC_fetch) and Assigned(EVP_MAC_CTX_new));
end;

procedure UnloadFunctions;
begin
  TOpenSSLLoader.ClearFunctions(CMAC_EVP_BINDINGS);
  TOpenSSLLoader.SetModuleLoaded(osmCMAC, False);
end;

{ TCMACEVPContext }

constructor TCMACEVPContext.Create(const CipherName: string);
begin
  inherited Create;
  FCipherName := CipherName;
  FMac := nil;
  FCtx := nil;
  FUsesFetch := False;
  FInitialized := False;
  LoadFunctions;
end;

destructor TCMACEVPContext.Destroy;
begin
  if Assigned(FCtx) and Assigned(EVP_MAC_CTX_free) then
  begin
    EVP_MAC_CTX_free(FCtx);
    FCtx := nil;
  end;
  if FUsesFetch and Assigned(FMac) and Assigned(EVP_MAC_free) then
  begin
    EVP_MAC_free(FMac);
    FMac := nil;
  end;
  inherited;
end;

function TCMACEVPContext.Init(const Key: TBytes): Boolean;
var
  AlgName: AnsiString;
  CipherNameAnsi: AnsiString;
  params: array[0..1] of OSSL_PARAM;
begin
  Result := False;
  if not Assigned(EVP_MAC_fetch) or not Assigned(EVP_MAC_CTX_new) then Exit;
  
  AlgName := 'CMAC';
  FMac := EVP_MAC_fetch(nil, PAnsiChar(AlgName), nil);
  if FMac = nil then Exit;
  FUsesFetch := True;
  
  FCtx := EVP_MAC_CTX_new(FMac);
  if FCtx = nil then Exit;
  
  if Assigned(OSSL_PARAM_construct_utf8_string) and Assigned(OSSL_PARAM_construct_end) then
  begin
    CipherNameAnsi := AnsiString(FCipherName);
    params[0] := OSSL_PARAM_construct_utf8_string('cipher', PAnsiChar(CipherNameAnsi), 0);
    params[1] := OSSL_PARAM_construct_end();
    if Length(Key) > 0 then
      Result := EVP_MAC_init(FCtx, @Key[0], Length(Key), @params[0]) = 1
    else
      Result := EVP_MAC_init(FCtx, nil, 0, @params[0]) = 1;
  end
  else
  begin
    if Length(Key) > 0 then
      Result := EVP_MAC_init(FCtx, @Key[0], Length(Key), nil) = 1
    else
      Result := EVP_MAC_init(FCtx, nil, 0, nil) = 1;
  end;
  FInitialized := Result;
end;

function TCMACEVPContext.Update(const Data: Pointer; Len: NativeUInt): Boolean;
begin
  Result := False;
  if not FInitialized or (FCtx = nil) or not Assigned(EVP_MAC_update) then Exit;
  if (Data = nil) or (Len = 0) then Exit(True);
  Result := EVP_MAC_update(FCtx, Data, Len) = 1;
end;

function TCMACEVPContext.Update(const Data: TBytes): Boolean;
begin
  if Length(Data) = 0 then Exit(True);
  Result := Update(@Data[0], Length(Data));
end;

function TCMACEVPContext.Final(Mac: PByte; var MacLen: NativeUInt): Boolean;
begin
  Result := False;
  if not FInitialized or (FCtx = nil) or not Assigned(EVP_MAC_final) then Exit;
  if Mac = nil then Exit;
  Result := EVP_MAC_final(FCtx, Mac, @MacLen, MacLen) = 1;
end;

function TCMACEVPContext.FinalBytes: TBytes;
var
  mac_size: NativeUInt;
begin
  Result := nil;
  if Assigned(EVP_MAC_CTX_get_mac_size) and (FCtx <> nil) then
    mac_size := EVP_MAC_CTX_get_mac_size(FCtx)
  else
    mac_size := CMAC_MAX_SIZE;
  SetLength(Result, mac_size);
  if not Final(@Result[0], mac_size) then
    SetLength(Result, 0)
  else
    SetLength(Result, mac_size);
end;

function CMAC_AES128_EVP(const Key: TBytes; const Data: TBytes): TBytes;
begin
  Result := ComputeCMAC_EVP('AES-128-CBC', Key, Data);
end;

function CMAC_AES192_EVP(const Key: TBytes; const Data: TBytes): TBytes;
begin
  Result := ComputeCMAC_EVP('AES-192-CBC', Key, Data);
end;

function CMAC_AES256_EVP(const Key: TBytes; const Data: TBytes): TBytes;
begin
  Result := ComputeCMAC_EVP('AES-256-CBC', Key, Data);
end;

function ComputeCMAC_EVP(const CipherName: string; const Key: TBytes; const Data: TBytes): TBytes;
var
  ctx: TCMACEVPContext;
begin
  Result := nil;
  ctx := TCMACEVPContext.Create(CipherName);
  try
    if not ctx.Init(Key) then Exit;
    if Length(Data) > 0 then
      if not ctx.Update(@Data[0], Length(Data)) then Exit;
    Result := ctx.FinalBytes;
  finally
    ctx.Free;
  end;
end;

function IsEVPCMACAvailable: Boolean;
var
  mac: PEVP_MAC;
  AlgName: AnsiString;
begin
  Result := False;
  LoadFunctions;
  if not Assigned(EVP_MAC_fetch) then Exit;
  AlgName := 'CMAC';
  mac := EVP_MAC_fetch(nil, PAnsiChar(AlgName), nil);
  if mac <> nil then
  begin
    if Assigned(EVP_MAC_free) then EVP_MAC_free(mac);
    Result := True;
  end;
end;

initialization
  LoadFunctions;

finalization
  UnloadFunctions;

end.
