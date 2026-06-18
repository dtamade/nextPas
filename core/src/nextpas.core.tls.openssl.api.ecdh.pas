unit nextpas.core.tls.openssl.api.ecdh;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.base, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.bn, nextpas.core.tls.openssl.api.ec, nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.platform.dl;

const
  { ECDH flags }
  ECDH_FLAG_COFACTOR_ECDH = $01;

type
  { KDF function type - must be defined before ECDH_METHOD }
  TECDH_KDF = function(const in_: Pointer; inlen: size_t; out_: Pointer; outlen: Psize_t): Pointer; cdecl;
  
  { ECDH compute_key function type }
  TECDH_compute_key_method = function(key: PByte; outlen: size_t; const pub_key: PEC_POINT; 
                                      const ecdh: PEC_KEY; KDF: TECDH_KDF): Integer; cdecl;
  
  { ECDH_METHOD structure }
  ECDH_METHOD = record
    name: PAnsiChar;
    compute_key: TECDH_compute_key_method;
    flags: Integer;
    app_data: PAnsiChar;
  end;
  PECDH_METHOD = ^ECDH_METHOD;

  { ECDH function types }
  TECDH_compute_key = function(out_: PByte; outlen: size_t; const pub_key: PEC_POINT; const eckey: PEC_KEY; KDF: TECDH_KDF): Integer; cdecl;
  TECDH_get_default_method = function: PECDH_METHOD; cdecl;
  TECDH_set_default_method = procedure(const meth: PECDH_METHOD); cdecl;
  TECDH_set_method = function(eckey: PEC_KEY; const meth: PECDH_METHOD): Integer; cdecl;
  TECDH_get_ex_data = function(d: PEC_KEY; idx: Integer): Pointer; cdecl;
  TECDH_set_ex_data = function(d: PEC_KEY; idx: Integer; arg: Pointer): Integer; cdecl;
  TECDH_get_ex_new_index = function(argl: clong; argp: Pointer; new_func: Pointer; dup_func: Pointer; free_func: Pointer): Integer; cdecl;
  
  { ECDH KDF functions }
  TECDH_KDF_X9_63 = function(out_: PByte; outlen: size_t; const Z: PByte; Zlen: size_t; const sinfo: PByte; sinfolen: size_t; const md: PEVP_MD): Integer; cdecl;
  
  { EC_KEY method functions for key agreement }
  TEC_KEY_METHOD_get_compute_key = procedure(const meth: PEC_KEY_METHOD; pck: Pointer); cdecl;
  TEC_KEY_METHOD_set_compute_key = procedure(meth: PEC_KEY_METHOD; ckey: Pointer); cdecl;
  
  { EC_KEY functions related to ECDH }
  TEC_KEY_get_flags = function(const key: PEC_KEY): Integer; cdecl;
  TEC_KEY_set_flags = procedure(key: PEC_KEY; flags: Integer); cdecl;
  TEC_KEY_clear_flags = procedure(key: PEC_KEY; flags: Integer); cdecl;

var
  { ECDH functions }
  ECDH_compute_key: TECDH_compute_key;
  ECDH_get_default_method: TECDH_get_default_method;
  ECDH_set_default_method: TECDH_set_default_method;
  ECDH_set_method: TECDH_set_method;
  ECDH_get_ex_data: TECDH_get_ex_data;
  ECDH_set_ex_data: TECDH_set_ex_data;
  ECDH_get_ex_new_index: TECDH_get_ex_new_index;
  
  { ECDH KDF functions }
  ECDH_KDF_X9_63: TECDH_KDF_X9_63;
  
  { EC_KEY method functions }
  EC_KEY_METHOD_get_compute_key: TEC_KEY_METHOD_get_compute_key;
  EC_KEY_METHOD_set_compute_key: TEC_KEY_METHOD_set_compute_key;
  
  { EC_KEY flag functions }
  EC_KEY_get_flags: TEC_KEY_get_flags;
  EC_KEY_set_flags: TEC_KEY_set_flags;
  EC_KEY_clear_flags: TEC_KEY_clear_flags;

function LoadOpenSSLECDH: Boolean;
procedure UnloadOpenSSLECDH;

{ Helper functions for ECDH operations }
function ECDH_ComputeSharedSecret(const APrivateKey: PEC_KEY; const APeerPublicKey: PEC_POINT; 
                                  out ASharedSecret: TBytes): Boolean;
function ECDH_ComputeSharedSecretWithKDF(const APrivateKey: PEC_KEY; const APeerPublicKey: PEC_POINT;
                                          AKDF: TECDH_KDF; out ASharedSecret: TBytes): Boolean;
function ECDH_SetCofactorMode(AKey: PEC_KEY; AUseCofactor: Boolean): Boolean;

implementation


const
  { ECDH function bindings for batch loading }
  ECDH_FUNCTION_COUNT = 13;
  ECDHFunctionBindings: array[0..ECDH_FUNCTION_COUNT - 1] of TFunctionBinding = (
    // ECDH core functions
    (Name: 'ECDH_compute_key';              FuncPtr: @ECDH_compute_key;              Required: False),
    (Name: 'ECDH_get_default_method';       FuncPtr: @ECDH_get_default_method;       Required: False),
    (Name: 'ECDH_set_default_method';       FuncPtr: @ECDH_set_default_method;       Required: False),
    (Name: 'ECDH_set_method';               FuncPtr: @ECDH_set_method;               Required: False),
    (Name: 'ECDH_get_ex_data';              FuncPtr: @ECDH_get_ex_data;              Required: False),
    (Name: 'ECDH_set_ex_data';              FuncPtr: @ECDH_set_ex_data;              Required: False),
    (Name: 'ECDH_get_ex_new_index';         FuncPtr: @ECDH_get_ex_new_index;         Required: False),
    // ECDH KDF functions
    (Name: 'ECDH_KDF_X9_63';                FuncPtr: @ECDH_KDF_X9_63;                Required: False),
    // EC_KEY method functions
    (Name: 'EC_KEY_METHOD_get_compute_key'; FuncPtr: @EC_KEY_METHOD_get_compute_key; Required: False),
    (Name: 'EC_KEY_METHOD_set_compute_key'; FuncPtr: @EC_KEY_METHOD_set_compute_key; Required: False),
    // EC_KEY flag functions
    (Name: 'EC_KEY_get_flags';              FuncPtr: @EC_KEY_get_flags;              Required: False),
    (Name: 'EC_KEY_set_flags';              FuncPtr: @EC_KEY_set_flags;              Required: False),
    (Name: 'EC_KEY_clear_flags';            FuncPtr: @EC_KEY_clear_flags;            Required: False)
  );

function LoadOpenSSLECDH: Boolean;
var
  LLib: TPlatformLibrary;
  LLoaded: Boolean;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmECDH) then
    Exit(True);

  // Use the crypto library handle from core module
  LLib := GetCryptoLibHandle;
  if not LibLoaded(LLib) then
  begin
    LoadOpenSSLCore;
    LLib := GetCryptoLibHandle;
  end;

  if not LibLoaded(LLib) then
    Exit(False);

  // Batch load all ECDH functions
  TOpenSSLLoader.LoadFunctions(LLib, ECDHFunctionBindings);

  // Check if critical functions are loaded
  // Note: In OpenSSL 1.1.0+, ECDH_compute_key might not exist as a separate function
  // The functionality is integrated into EC_KEY operations
  LLoaded := Assigned(ECDH_compute_key) or
    (Assigned(EC_KEY_get_flags) and Assigned(EC_KEY_set_flags));
  TOpenSSLLoader.SetModuleLoaded(osmECDH, LLoaded);
  Result := LLoaded;
end;

procedure UnloadOpenSSLECDH;
begin
  // Clear all ECDH function pointers using batch clear
  TOpenSSLLoader.ClearFunctions(ECDHFunctionBindings);
  TOpenSSLLoader.SetModuleLoaded(osmECDH, False);
end;


{ Helper functions }

function ECDH_ComputeSharedSecret(const APrivateKey: PEC_KEY; const APeerPublicKey: PEC_POINT; 
                                  out ASharedSecret: TBytes): Boolean;
var
  LFieldSize: Integer;
  LOutLen: Integer;
  LGroup: PEC_GROUP;
begin
  Result := False;
  if not Assigned(ECDH_compute_key) then
    Exit;
    
  if not Assigned(APrivateKey) or not Assigned(APeerPublicKey) then
    Exit;
    
  // Get the EC group from the private key
  LGroup := EC_KEY_get0_group(APrivateKey);
  if not Assigned(LGroup) then
    Exit;
    
  // Calculate the field size
  LFieldSize := EC_GROUP_get_degree(LGroup);
  if LFieldSize <= 0 then
    Exit;
    
  LFieldSize := (LFieldSize + 7) div 8;
  
  // Allocate buffer for shared secret
  SetLength(ASharedSecret, LFieldSize);
  
  // Compute the shared secret
  LOutLen := ECDH_compute_key(@ASharedSecret[0], LFieldSize, APeerPublicKey, APrivateKey, nil);
  if LOutLen > 0 then
  begin
    SetLength(ASharedSecret, LOutLen);
    Result := True;
  end
  else
    SetLength(ASharedSecret, 0);
end;

function ECDH_ComputeSharedSecretWithKDF(const APrivateKey: PEC_KEY; const APeerPublicKey: PEC_POINT;
                                          AKDF: TECDH_KDF; out ASharedSecret: TBytes): Boolean;
var
  LFieldSize: Integer;
  LOutLen: Integer;
  LGroup: PEC_GROUP;
begin
  Result := False;
  if not Assigned(ECDH_compute_key) then
    Exit;
    
  if not Assigned(APrivateKey) or not Assigned(APeerPublicKey) or not Assigned(AKDF) then
    Exit;
    
  // Get the EC group from the private key
  LGroup := EC_KEY_get0_group(APrivateKey);
  if not Assigned(LGroup) then
    Exit;
    
  // Calculate the field size
  LFieldSize := EC_GROUP_get_degree(LGroup);
  if LFieldSize <= 0 then
    Exit;
    
  LFieldSize := (LFieldSize + 7) div 8;
  
  // Allocate buffer for shared secret
  SetLength(ASharedSecret, LFieldSize);
  
  // Compute the shared secret with KDF
  LOutLen := ECDH_compute_key(@ASharedSecret[0], LFieldSize, APeerPublicKey, APrivateKey, AKDF);
  if LOutLen > 0 then
  begin
    SetLength(ASharedSecret, LOutLen);
    Result := True;
  end
  else
    SetLength(ASharedSecret, 0);
end;

function ECDH_SetCofactorMode(AKey: PEC_KEY; AUseCofactor: Boolean): Boolean;
var
  LFlags: Integer;
begin
  Result := False;
  if not Assigned(EC_KEY_get_flags) or not Assigned(EC_KEY_set_flags) or 
    not Assigned(EC_KEY_clear_flags) then
    Exit;
    
  if not Assigned(AKey) then
    Exit;
    
  if AUseCofactor then
  begin
    LFlags := EC_KEY_get_flags(AKey);
    EC_KEY_set_flags(AKey, LFlags or ECDH_FLAG_COFACTOR_ECDH);
  end
  else
  begin
    EC_KEY_clear_flags(AKey, ECDH_FLAG_COFACTOR_ECDH);
  end;
  
  Result := True;
end;

end.
