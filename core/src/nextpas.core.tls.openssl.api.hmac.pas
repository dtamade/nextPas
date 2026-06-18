unit nextpas.core.tls.openssl.api.hmac;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.loader,
  nextpas.core.platform.dl;

const
  { HMAC constants }
  HMAC_MAX_MD_CBLOCK = 200;  // Maximum block size for HMAC
  
type
  { HMAC_CTX structure - opaque in OpenSSL 1.1.0+ }
  HMAC_CTX = record
    // Internal structure is opaque
  end;
  PHMAC_CTX = ^HMAC_CTX;
  PPHMAC_CTX = ^PHMAC_CTX;

  { HMAC function types }
  THMAC = function(const evp_md: PEVP_MD; const key: Pointer; key_len: Integer;
                  const d: PByte; n: size_t; md: PByte; md_len: PCardinal): PByte; cdecl;
  THMAC_CTX_new = function: PHMAC_CTX; cdecl;
  THMAC_CTX_reset = function(ctx: PHMAC_CTX): Integer; cdecl;
  THMAC_CTX_free = procedure(ctx: PHMAC_CTX); cdecl;
  THMAC_Init = function(ctx: PHMAC_CTX; const key: Pointer; len: Integer; const md: PEVP_MD): Integer; cdecl;
  THMAC_Init_ex = function(ctx: PHMAC_CTX; const key: Pointer; len: Integer; const md: PEVP_MD; impl: PENGINE): Integer; cdecl;
  THMAC_Update = function(ctx: PHMAC_CTX; const data: Pointer; len: size_t): Integer; cdecl;
  THMAC_Final = function(ctx: PHMAC_CTX; md: PByte; len: PCardinal): Integer; cdecl;
  THMAC_CTX_copy = function(dctx: PHMAC_CTX; sctx: PHMAC_CTX): Integer; cdecl;
  THMAC_CTX_set_flags = procedure(ctx: PHMAC_CTX; flags: Cardinal); cdecl;
  THMAC_CTX_get_md = function(const ctx: PHMAC_CTX): PEVP_MD; cdecl;
  THMAC_size = function(const ctx: PHMAC_CTX): size_t; cdecl;
  
  { Legacy functions for older OpenSSL versions }
  THMAC_CTX_init = procedure(ctx: PHMAC_CTX); cdecl;
  THMAC_CTX_cleanup = procedure(ctx: PHMAC_CTX); cdecl;

var
  { HMAC functions }
  HMAC: THMAC;
  HMAC_CTX_new: THMAC_CTX_new;
  HMAC_CTX_reset: THMAC_CTX_reset;
  HMAC_CTX_free: THMAC_CTX_free;
  HMAC_Init: THMAC_Init;
  HMAC_Init_ex: THMAC_Init_ex;
  HMAC_Update: THMAC_Update;
  HMAC_Final: THMAC_Final;
  HMAC_CTX_copy: THMAC_CTX_copy;
  HMAC_CTX_set_flags: THMAC_CTX_set_flags;
  HMAC_CTX_get_md: THMAC_CTX_get_md;
  HMAC_size: THMAC_size;
  
  { Legacy functions }
  HMAC_CTX_init: THMAC_CTX_init;
  HMAC_CTX_cleanup: THMAC_CTX_cleanup;

function LoadOpenSSLHMAC: Boolean;
procedure UnloadOpenSSLHMAC;

{ Helper functions }
function HMAC_SHA1(const key: Pointer; key_len: Integer; const data: Pointer; data_len: size_t; digest: PByte): PByte;
function HMAC_SHA256(const key: Pointer; key_len: Integer; const data: Pointer; data_len: size_t; digest: PByte): PByte;
function HMAC_SHA512(const key: Pointer; key_len: Integer; const data: Pointer; data_len: size_t; digest: PByte): PByte;

implementation

uses nextpas.core.tls.openssl.api, nextpas.core.tls.openssl.api.core, nextpas.core.tls.openssl.api.evp;

const
  { HMAC function bindings for batch loading }
  HMAC_BINDINGS: array[0..13] of TFunctionBinding = (
    (Name: 'HMAC';              FuncPtr: @HMAC;              Required: True),
    (Name: 'HMAC_CTX_new';      FuncPtr: @HMAC_CTX_new;      Required: False),
    (Name: 'HMAC_CTX_reset';    FuncPtr: @HMAC_CTX_reset;    Required: False),
    (Name: 'HMAC_CTX_free';     FuncPtr: @HMAC_CTX_free;     Required: False),
    (Name: 'HMAC_Init';         FuncPtr: @HMAC_Init;         Required: False),
    (Name: 'HMAC_Init_ex';      FuncPtr: @HMAC_Init_ex;      Required: False),
    (Name: 'HMAC_Update';       FuncPtr: @HMAC_Update;       Required: False),
    (Name: 'HMAC_Final';        FuncPtr: @HMAC_Final;        Required: False),
    (Name: 'HMAC_CTX_copy';     FuncPtr: @HMAC_CTX_copy;     Required: False),
    (Name: 'HMAC_CTX_set_flags'; FuncPtr: @HMAC_CTX_set_flags; Required: False),
    (Name: 'HMAC_CTX_get_md';   FuncPtr: @HMAC_CTX_get_md;   Required: False),
    (Name: 'HMAC_size';         FuncPtr: @HMAC_size;         Required: False),
    { Legacy functions (may not exist in newer versions) }
    (Name: 'HMAC_CTX_init';     FuncPtr: @HMAC_CTX_init;     Required: False),
    (Name: 'HMAC_CTX_cleanup';  FuncPtr: @HMAC_CTX_cleanup;  Required: False)
  );

function LoadOpenSSLHMAC: Boolean;
var
  LLib: TPlatformLibrary;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmHMAC) then
    Exit(True);

  // Use the crypto library handle from core module
  LLib := GetCryptoLibHandle;
  if not LibLoaded(LLib) then
  begin
    // Try to load core first
    LoadOpenSSLCore;
    LLib := GetCryptoLibHandle;
  end;

  if not LibLoaded(LLib) then
    Exit(False);

  // Ensure EVP module is loaded (needed for digest algorithms)
  if not TOpenSSLLoader.IsModuleLoaded(osmEVP) then
    LoadEVP(LLib);

  // Load HMAC functions using batch loading
  TOpenSSLLoader.LoadFunctions(LLib, HMAC_BINDINGS);

  TOpenSSLLoader.SetModuleLoaded(osmHMAC, Assigned(HMAC));
  Result := TOpenSSLLoader.IsModuleLoaded(osmHMAC);
end;

procedure UnloadOpenSSLHMAC;
begin
  TOpenSSLLoader.ClearFunctions(HMAC_BINDINGS);
  TOpenSSLLoader.SetModuleLoaded(osmHMAC, False);
end;


{ Helper functions }

function HMAC_SHA1(const key: Pointer; key_len: Integer; const data: Pointer; data_len: size_t; digest: PByte): PByte;
begin
  Result := nil;
  if Assigned(HMAC) and Assigned(EVP_sha1) then
    Result := HMAC(EVP_sha1(), key, key_len, data, data_len, digest, nil);
end;

function HMAC_SHA256(const key: Pointer; key_len: Integer; const data: Pointer; data_len: size_t; digest: PByte): PByte;
begin
  Result := nil;
  if Assigned(HMAC) and Assigned(EVP_sha256) then
    Result := HMAC(EVP_sha256(), key, key_len, data, data_len, digest, nil);
end;

function HMAC_SHA512(const key: Pointer; key_len: Integer; const data: Pointer; data_len: size_t; digest: PByte): PByte;
begin
  Result := nil;
  if Assigned(HMAC) and Assigned(EVP_sha512) then
    Result := HMAC(EVP_sha512(), key, key_len, data, data_len, digest, nil);
end;

end.