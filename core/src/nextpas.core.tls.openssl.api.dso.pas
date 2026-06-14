{******************************************************************************}
{                                                                              }
{  nextpas.core.tls.openssl.api.dso - OpenSSL DSO Module Pascal Binding                 }
{                                                                              }
{  Copyright (c) 2024 fafafa                                                  }
{                                                                              }
{******************************************************************************}
unit nextpas.core.tls.openssl.api.dso;

{$mode ObjFPC}{$H+}

interface

uses Classes, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.consts, nextpas.core.tls.openssl.loader;

type
  { DSO types }
  DSO = record end;
  PDSO = ^DSO;
  
  DSO_METHOD = record end;
  PDSO_METHOD = ^DSO_METHOD;
  
  { DSO flags }
const
  DSO_FLAG_NO_NAME_TRANSLATION = $01;
  DSO_FLAG_NAME_TRANSLATION_EXT_ONLY = $02;
  DSO_FLAG_UPCASE_SYMBOL = $10;
  DSO_FLAG_GLOBAL_SYMBOLS = $20;
  
  { DSO control commands }
  DSO_CTRL_GET_FLAGS = 1;
  DSO_CTRL_SET_FLAGS = 2;
  DSO_CTRL_OR_FLAGS = 3;

type  
  { DSO callback types }
  TDSO_name_converter_func = function(dso: PDSO; const from: PChar): PChar; cdecl;
  TDSO_merger_func = function(dso: PDSO; const filespec1, filespec2: PChar): PChar; cdecl;
  
  { Function pointers for dynamic loading }
  TDSONew = function: PDSO; cdecl;
  TDSOFree = function(dso: PDSO): TOpenSSLInt; cdecl;
  TDSOUpRef = function(dso: PDSO): TOpenSSLInt; cdecl;
  TDSOLoad = function(dso: PDSO; const filename: PChar; meth: PDSO_METHOD; flags: TOpenSSLInt): PDSO; cdecl;
  TDSOBind = function(dso: PDSO; const symname: PChar): Pointer; cdecl;
  TDSOUnbind = function(dso: PDSO; const symname: PChar): TOpenSSLInt; cdecl;
  TDSOCtrl = function(dso: PDSO; cmd: TOpenSSLInt; larg: TOpenSSLLong; parg: Pointer): TOpenSSLLong; cdecl;
  TDSOGetFilename = function(dso: PDSO): PChar; cdecl;
  TDSOSetFilename = function(dso: PDSO; const filename: PChar): TOpenSSLInt; cdecl;
  TDSOConvertFilename = function(dso: PDSO; const filename: PChar): PChar; cdecl;
  TDSOGetLoadedFilename = function(dso: PDSO): PChar; cdecl;
  TDSOSetDefaultMethod = function(meth: PDSO_METHOD): PDSO_METHOD; cdecl;
  TDSOGetDefaultMethod = function: PDSO_METHOD; cdecl;
  TDSOGetMethod = function(dso: PDSO): PDSO_METHOD; cdecl;
  TDSOSetMethod = function(dso: PDSO; meth: PDSO_METHOD): PDSO_METHOD; cdecl;
  TDSONewMethod = function: PDSO_METHOD; cdecl;
  TDSOFreeMethod = procedure(meth: PDSO_METHOD); cdecl;
  TDSOPathcheck = function(const path: PChar): TOpenSSLInt; cdecl;
  TDSODlfcn = function: PDSO_METHOD; cdecl;
  TDSOWin32 = function: PDSO_METHOD; cdecl;
  TDSOVms = function: PDSO_METHOD; cdecl;
  
var
  { Function variables }
  DSO_new: TDSONew = nil;
  DSO_free: TDSOFree = nil;
  DSO_up_ref: TDSOUpRef = nil;
  DSO_load: TDSOLoad = nil;
  DSO_bind_var: TDSOBind = nil;
  DSO_bind_func: TDSOBind = nil;
  DSO_unbind_var: TDSOUnbind = nil;
  DSO_unbind_func: TDSOUnbind = nil;
  DSO_ctrl: TDSOCtrl = nil;
  DSO_get_filename: TDSOGetFilename = nil;
  DSO_set_filename: TDSOSetFilename = nil;
  DSO_convert_filename: TDSOConvertFilename = nil;
  DSO_get_loaded_filename: TDSOGetLoadedFilename = nil;
  DSO_set_default_method: TDSOSetDefaultMethod = nil;
  DSO_get_default_method: TDSOGetDefaultMethod = nil;
  DSO_get_method: TDSOGetMethod = nil;
  DSO_set_method: TDSOSetMethod = nil;
  DSO_new_method: TDSONewMethod = nil;
  DSO_free_method: TDSOFreeMethod = nil;
  DSO_pathbyaddr: TDSOPathcheck = nil;
  DSO_dlfcn: TDSODlfcn = nil;
  DSO_METHOD_win32: TDSOWin32 = nil;
  DSO_METHOD_vms: TDSOVms = nil;

{ Load/Unload functions }
function LoadDSO(const ALibCrypto: THandle): Boolean;
procedure UnloadDSO;

{ Helper functions }
function DSOLoadLibrary(const LibraryPath: string): PDSO;
function DSOGetSymbol(dso: PDSO; const SymbolName: string): Pointer;
procedure DSOFreeLibrary(dso: PDSO);
function DSOGetFlags(dso: PDSO): TOpenSSLInt;
function DSOSetFlags(dso: PDSO; Flags: TOpenSSLInt): Boolean;

implementation

uses nextpas.core.tls.openssl.api.utils;

const
  { DSO function bindings for batch loading }
  DSO_BINDINGS: array[0..22] of TFunctionBinding = (
    { Basic functions }
    (Name: 'DSO_new';               FuncPtr: @DSO_new;               Required: True),
    (Name: 'DSO_free';              FuncPtr: @DSO_free;              Required: True),
    (Name: 'DSO_up_ref';            FuncPtr: @DSO_up_ref;            Required: False),
    (Name: 'DSO_load';              FuncPtr: @DSO_load;              Required: False),
    { Binding functions }
    (Name: 'DSO_bind_var';          FuncPtr: @DSO_bind_var;          Required: False),
    (Name: 'DSO_bind_func';         FuncPtr: @DSO_bind_func;         Required: False),
    (Name: 'DSO_unbind_var';        FuncPtr: @DSO_unbind_var;        Required: False),
    (Name: 'DSO_unbind_func';       FuncPtr: @DSO_unbind_func;       Required: False),
    { Control and info functions }
    (Name: 'DSO_ctrl';              FuncPtr: @DSO_ctrl;              Required: False),
    (Name: 'DSO_get_filename';      FuncPtr: @DSO_get_filename;      Required: False),
    (Name: 'DSO_set_filename';      FuncPtr: @DSO_set_filename;      Required: False),
    (Name: 'DSO_convert_filename';  FuncPtr: @DSO_convert_filename;  Required: False),
    (Name: 'DSO_get_loaded_filename'; FuncPtr: @DSO_get_loaded_filename; Required: False),
    { Method functions }
    (Name: 'DSO_set_default_method'; FuncPtr: @DSO_set_default_method; Required: False),
    (Name: 'DSO_get_default_method'; FuncPtr: @DSO_get_default_method; Required: False),
    (Name: 'DSO_get_method';        FuncPtr: @DSO_get_method;        Required: False),
    (Name: 'DSO_set_method';        FuncPtr: @DSO_set_method;        Required: False),
    (Name: 'DSO_new_method';        FuncPtr: @DSO_new_method;        Required: False),
    (Name: 'DSO_METHOD_free';       FuncPtr: @DSO_free_method;       Required: False),
    { Platform specific functions }
    (Name: 'DSO_pathbyaddr';        FuncPtr: @DSO_pathbyaddr;        Required: False),
    (Name: 'DSO_METHOD_dlfcn';      FuncPtr: @DSO_dlfcn;             Required: False),
    (Name: 'DSO_METHOD_win32';      FuncPtr: @DSO_METHOD_win32;      Required: False),
    (Name: 'DSO_METHOD_vms';        FuncPtr: @DSO_METHOD_vms;        Required: False)
  );

function LoadDSO(const ALibCrypto: THandle): Boolean;
begin
  Result := False;
  if TOpenSSLLoader.IsModuleLoaded(osmDSO) then Exit(True);
  if ALibCrypto = 0 then Exit;

  { Batch load all DSO functions }
  TOpenSSLLoader.LoadFunctions(ALibCrypto, DSO_BINDINGS);

  Result := Assigned(DSO_new) and Assigned(DSO_free);
  TOpenSSLLoader.SetModuleLoaded(osmDSO, Result);
end;

procedure UnloadDSO;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmDSO) then Exit;

  { Clear all function pointers }
  TOpenSSLLoader.ClearFunctions(DSO_BINDINGS);

  TOpenSSLLoader.SetModuleLoaded(osmDSO, False);
end;

{ Helper functions }

function DSOLoadLibrary(const LibraryPath: string): PDSO;
var
  Method: PDSO_METHOD;
begin
  Result := nil;
  if not Assigned(DSO_new) or not Assigned(DSO_load) then Exit;
  
  Result := DSO_new();
  if Result = nil then Exit;
  
  Method := nil;
  if Assigned(DSO_get_default_method) then
    Method := DSO_get_default_method();
    
  if DSO_load(Result, PChar(LibraryPath), Method, 0) = nil then
  begin
    if Assigned(DSO_free) then
      DSO_free(Result);
    Result := nil;
  end;
end;

function DSOGetSymbol(dso: PDSO; const SymbolName: string): Pointer;
begin
  Result := nil;
  if (dso = nil) or not Assigned(DSO_bind_func) then Exit;
  
  Result := DSO_bind_func(dso, PChar(SymbolName));
end;

procedure DSOFreeLibrary(dso: PDSO);
begin
  if (dso <> nil) and Assigned(DSO_free) then
    DSO_free(dso);
end;

function DSOGetFlags(dso: PDSO): TOpenSSLInt;
begin
  Result := 0;
  if (dso <> nil) and Assigned(DSO_ctrl) then
    Result := DSO_ctrl(dso, DSO_CTRL_GET_FLAGS, 0, nil);
end;

function DSOSetFlags(dso: PDSO; Flags: TOpenSSLInt): Boolean;
begin
  Result := False;
  if (dso <> nil) and Assigned(DSO_ctrl) then
    Result := DSO_ctrl(dso, DSO_CTRL_SET_FLAGS, Flags, nil) > 0;
end;

initialization

finalization
  UnloadDSO;

end.