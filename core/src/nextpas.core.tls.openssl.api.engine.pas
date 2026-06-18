unit nextpas.core.tls.openssl.api.engine;

{******************************************************************************}
{                                                                              }
{  fafafa.ssl - OpenSSL ENGINE Module                                         }
{                                                                              }
{  Purpose: OpenSSL ENGINE API bindings for hardware acceleration and         }
{           custom cryptographic implementations                               }
{                                                                              }
{  Note: ENGINE API is deprecated in OpenSSL 3.0 in favor of providers        }
{        This module is provided for backward compatibility                    }
{                                                                              }
{******************************************************************************}

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.base,
  nextpas.core.text.strings,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.platform.dl;

type
  // Engine types
  ENGINE = Pointer;
  PENGINE = ^ENGINE;
  PPENGINE = ^PENGINE;
  ENGINE_CMD_DEFN = Pointer;
  PENGINE_CMD_DEFN = ^ENGINE_CMD_DEFN;

  // UI types (minimal for engine key loading)
  PUI_METHOD = Pointer;

  // EVP PKEY method types
  PEVP_PKEY_METHOD = Pointer;
  PEVP_PKEY_ASN1_METHOD = Pointer;

  // Engine function pointer types
  TENGINE_new = function(): PENGINE; cdecl;
  TENGINE_free = function(e: PENGINE): Integer; cdecl;
  TENGINE_up_ref = function(e: PENGINE): Integer; cdecl;
  TENGINE_by_id = function(const id: PAnsiChar): PENGINE; cdecl;
  TENGINE_add = function(e: PENGINE): Integer; cdecl;
  TENGINE_remove = function(e: PENGINE): Integer; cdecl;
  TENGINE_get_first = function(): PENGINE; cdecl;
  TENGINE_get_last = function(): PENGINE; cdecl;
  TENGINE_get_next = function(e: PENGINE): PENGINE; cdecl;
  TENGINE_get_prev = function(e: PENGINE): PENGINE; cdecl;

  TENGINE_init = function(e: PENGINE): Integer; cdecl;
  TENGINE_finish = function(e: PENGINE): Integer; cdecl;
  TENGINE_load_builtin_engines = procedure(); cdecl;
  TENGINE_cleanup = procedure(); cdecl;

  TENGINE_get_id = function(const e: PENGINE): PAnsiChar; cdecl;
  TENGINE_get_name = function(const e: PENGINE): PAnsiChar; cdecl;
  TENGINE_set_id = function(e: PENGINE; const id: PAnsiChar): Integer; cdecl;
  TENGINE_set_name = function(e: PENGINE; const name: PAnsiChar): Integer; cdecl;

  TENGINE_ctrl = function(e: PENGINE; cmd: Integer; i: Integer; p: Pointer; f: Pointer): Integer; cdecl;
  TENGINE_ctrl_cmd_string = function(e: PENGINE; const cmd_name: PAnsiChar;
    const arg: PAnsiChar; cmd_optional: Integer): Integer; cdecl;

  TENGINE_set_default = function(e: PENGINE; flags: Cardinal): Integer; cdecl;

  TENGINE_load_private_key = function(e: PENGINE; const key_id: PAnsiChar;
    ui_method: PUI_METHOD; callback_data: Pointer): PEVP_PKEY; cdecl;
  TENGINE_load_public_key = function(e: PENGINE; const key_id: PAnsiChar;
    ui_method: PUI_METHOD; callback_data: Pointer): PEVP_PKEY; cdecl;

const
  // Engine method flags
  ENGINE_METHOD_RSA         = $0001;
  ENGINE_METHOD_DSA         = $0002;
  ENGINE_METHOD_DH          = $0004;
  ENGINE_METHOD_RAND        = $0008;
  ENGINE_METHOD_CIPHERS     = $0040;
  ENGINE_METHOD_DIGESTS     = $0080;
  ENGINE_METHOD_PKEY_METHS  = $0200;
  ENGINE_METHOD_PKEY_ASN1_METHS = $0400;
  ENGINE_METHOD_EC          = $0800;
  ENGINE_METHOD_ALL         = $FFFF;
  ENGINE_METHOD_NONE        = $0000;

var
  // Engine management functions
  ENGINE_new: TENGINE_new = nil;
  ENGINE_free: TENGINE_free = nil;
  ENGINE_up_ref: TENGINE_up_ref = nil;
  ENGINE_by_id: TENGINE_by_id = nil;
  ENGINE_add: TENGINE_add = nil;
  ENGINE_remove: TENGINE_remove = nil;
  ENGINE_get_first: TENGINE_get_first = nil;
  ENGINE_get_last: TENGINE_get_last = nil;
  ENGINE_get_next: TENGINE_get_next = nil;
  ENGINE_get_prev: TENGINE_get_prev = nil;

  // Engine lifecycle
  ENGINE_init: TENGINE_init = nil;
  ENGINE_finish: TENGINE_finish = nil;
  ENGINE_load_builtin_engines: TENGINE_load_builtin_engines = nil;
  ENGINE_cleanup: TENGINE_cleanup = nil;

  // Engine info
  ENGINE_get_id: TENGINE_get_id = nil;
  ENGINE_get_name: TENGINE_get_name = nil;
  ENGINE_set_id: TENGINE_set_id = nil;
  ENGINE_set_name: TENGINE_set_name = nil;

  // Engine control
  ENGINE_ctrl: TENGINE_ctrl = nil;
  ENGINE_ctrl_cmd_string: TENGINE_ctrl_cmd_string = nil;

  // Engine defaults
  ENGINE_set_default: TENGINE_set_default = nil;

  // Engine key loading
  ENGINE_load_private_key: TENGINE_load_private_key = nil;
  ENGINE_load_public_key: TENGINE_load_public_key = nil;

// Module loading functions
function LoadOpenSSLEngine(const ACryptoLib: TPlatformLibrary): Boolean;
procedure UnloadOpenSSLEngine;

// Helper functions
function InitializeEngine(const AEngineID: string): PENGINE;
function LoadEnginePrivateKey(AEngine: PENGINE; const AKeyID: string): PEVP_PKEY;
function LoadEnginePublicKey(AEngine: PENGINE; const AKeyID: string): PEVP_PKEY;
function SetEngineAsDefault(AEngine: PENGINE; AFlags: Cardinal = ENGINE_METHOD_ALL): Boolean;
function ListAvailableEngines: TStringArray;

implementation

const
  EngineFunctionBindings: array[0..21] of TFunctionBinding = (
    (Name: 'ENGINE_new'; FuncPtr: @ENGINE_new; Required: False),
    (Name: 'ENGINE_free'; FuncPtr: @ENGINE_free; Required: False),
    (Name: 'ENGINE_up_ref'; FuncPtr: @ENGINE_up_ref; Required: False),
    (Name: 'ENGINE_by_id'; FuncPtr: @ENGINE_by_id; Required: False),
    (Name: 'ENGINE_add'; FuncPtr: @ENGINE_add; Required: False),
    (Name: 'ENGINE_remove'; FuncPtr: @ENGINE_remove; Required: False),
    (Name: 'ENGINE_get_first'; FuncPtr: @ENGINE_get_first; Required: False),
    (Name: 'ENGINE_get_last'; FuncPtr: @ENGINE_get_last; Required: False),
    (Name: 'ENGINE_get_next'; FuncPtr: @ENGINE_get_next; Required: False),
    (Name: 'ENGINE_get_prev'; FuncPtr: @ENGINE_get_prev; Required: False),
    (Name: 'ENGINE_init'; FuncPtr: @ENGINE_init; Required: False),
    (Name: 'ENGINE_finish'; FuncPtr: @ENGINE_finish; Required: False),
    (Name: 'ENGINE_load_builtin_engines'; FuncPtr: @ENGINE_load_builtin_engines; Required: False),
    (Name: 'ENGINE_get_id'; FuncPtr: @ENGINE_get_id; Required: False),
    (Name: 'ENGINE_get_name'; FuncPtr: @ENGINE_get_name; Required: False),
    (Name: 'ENGINE_set_id'; FuncPtr: @ENGINE_set_id; Required: False),
    (Name: 'ENGINE_set_name'; FuncPtr: @ENGINE_set_name; Required: False),
    (Name: 'ENGINE_ctrl'; FuncPtr: @ENGINE_ctrl; Required: False),
    (Name: 'ENGINE_ctrl_cmd_string'; FuncPtr: @ENGINE_ctrl_cmd_string; Required: False),
    (Name: 'ENGINE_set_default'; FuncPtr: @ENGINE_set_default; Required: False),
    (Name: 'ENGINE_load_private_key'; FuncPtr: @ENGINE_load_private_key; Required: False),
    (Name: 'ENGINE_load_public_key'; FuncPtr: @ENGINE_load_public_key; Required: False)
  );

function LoadOpenSSLEngine(const ACryptoLib: TPlatformLibrary): Boolean;
begin
  Result := False;
  if not LibLoaded(ACryptoLib) then
    Exit;

  if TOpenSSLLoader.IsModuleLoaded(osmEngine) then
    Exit(True);

  TOpenSSLLoader.LoadFunctions(ACryptoLib, EngineFunctionBindings);

  // Engine API is optional (deprecated in OpenSSL 3.0)
  Result := Assigned(ENGINE_by_id);
  TOpenSSLLoader.SetModuleLoaded(osmEngine, Result);
end;

procedure UnloadOpenSSLEngine;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmEngine) then
    Exit;

  TOpenSSLLoader.ClearFunctions(EngineFunctionBindings);
  TOpenSSLLoader.SetModuleLoaded(osmEngine, False);
end;


function InitializeEngine(const AEngineID: string): PENGINE;
begin
  Result := nil;
  if not TOpenSSLLoader.IsModuleLoaded(osmEngine) then
    Exit;

  // Load builtin engines
  if Assigned(ENGINE_load_builtin_engines) then
    ENGINE_load_builtin_engines();

  // Get engine
  if Assigned(ENGINE_by_id) then
    Result := ENGINE_by_id(PAnsiChar(AnsiString(AEngineID)));

  if Result = nil then
    Exit;

  // Initialize engine
  if Assigned(ENGINE_init) and (ENGINE_init(Result) = 0) then
  begin
    if Assigned(ENGINE_free) then
      ENGINE_free(Result);
    Result := nil;
  end;
end;

function LoadEnginePrivateKey(AEngine: PENGINE; const AKeyID: string): PEVP_PKEY;
begin
  Result := nil;
  if not TOpenSSLLoader.IsModuleLoaded(osmEngine) or (AEngine = nil) then
    Exit;

  if Assigned(ENGINE_load_private_key) then
    Result := ENGINE_load_private_key(AEngine, PAnsiChar(AnsiString(AKeyID)), nil, nil);
end;

function LoadEnginePublicKey(AEngine: PENGINE; const AKeyID: string): PEVP_PKEY;
begin
  Result := nil;
  if not TOpenSSLLoader.IsModuleLoaded(osmEngine) or (AEngine = nil) then
    Exit;

  if Assigned(ENGINE_load_public_key) then
    Result := ENGINE_load_public_key(AEngine, PAnsiChar(AnsiString(AKeyID)), nil, nil);
end;

function SetEngineAsDefault(AEngine: PENGINE; AFlags: Cardinal): Boolean;
begin
  Result := False;
  if not TOpenSSLLoader.IsModuleLoaded(osmEngine) or (AEngine = nil) then
    Exit;

  if Assigned(ENGINE_set_default) then
    Result := ENGINE_set_default(AEngine, AFlags) <> 0;
end;

function ListAvailableEngines: TStringArray;
var
  Eng: PENGINE;
  LId: PAnsiChar;
begin
  Result := nil;
  if not TOpenSSLLoader.IsModuleLoaded(osmEngine) then
    Exit;

  // Load builtin engines
  if Assigned(ENGINE_load_builtin_engines) then
    ENGINE_load_builtin_engines();

  // Enumerate all engines
  if Assigned(ENGINE_get_first) and Assigned(ENGINE_get_next) and Assigned(ENGINE_get_id) then
  begin
    Eng := ENGINE_get_first();
    while Eng <> nil do
    begin
      LId := ENGINE_get_id(Eng);
      if LId <> nil then
        StringsAppend(Result, string(LId));
      Eng := ENGINE_get_next(Eng);
    end;
  end;
end;

end.
