unit nextpas.core.tls.openssl.api.conf;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.core; type // Opaque types PCONF = ^CONF;
  CONF = record end;
  
  PCONF_METHOD = ^CONF_METHOD;
  CONF_METHOD = record end;
  
  PCONF_MODULE = ^CONF_MODULE;
  CONF_MODULE = record end;
  
  PCONF_IMODULE = ^CONF_IMODULE;
  CONF_IMODULE = record end;
  
  PLHASH_NODE = ^LHASH_NODE;
  LHASH_NODE = record end;
  
  // Callback types
  TCONF_init_func = function(md: PCONF_IMODULE; cnf: PCONF): TOpenSSL_Int; cdecl;
  TCONF_finish_func = procedure(md: PCONF_IMODULE); cdecl;
  
  // Function pointer types
  TNCONF_new = function(method: PCONF_METHOD): PCONF; cdecl;
  TNCONF_default = function: PCONF_METHOD; cdecl;
  TNCONF_WIN32 = function: PCONF_METHOD; cdecl;
  TNCONF_free = procedure(conf: PCONF); cdecl;
  TNCONF_free_data = procedure(conf: PCONF); cdecl;
  TNCONF_load = function(conf: PCONF; const filename: PAnsiChar; eline: PLongInt): TOpenSSL_Int; cdecl;
  TNCONF_load_fp = function(conf: PCONF; fp: Pointer; eline: PLongInt): TOpenSSL_Int; cdecl;
  TNCONF_load_bio = function(conf: PCONF; bp: PBIO; eline: PLongInt): TOpenSSL_Int; cdecl;
  TNCONF_get_string = function(conf: PCONF; const group: PAnsiChar; const name: PAnsiChar): PAnsiChar; cdecl;
  TNCONF_get_number_e = function(conf: PCONF; const group: PAnsiChar; const name: PAnsiChar; result: PLongInt): TOpenSSL_Int; cdecl;
  TNCONF_dump_fp = function(conf: PCONF; out_fp: Pointer): TOpenSSL_Int; cdecl;
  TNCONF_dump_bio = function(conf: PCONF; out_bio: PBIO): TOpenSSL_Int; cdecl;
  
  // Module management functions
  TCONF_modules_load = function(const cnf: PCONF; const appname: PAnsiChar; flags: LongWord): TOpenSSL_Int; cdecl;
  TCONF_modules_load_file = function(const filename: PAnsiChar; const appname: PAnsiChar; flags: LongWord): TOpenSSL_Int; cdecl;
  TCONF_modules_free = procedure; cdecl;
  TCONF_modules_finish = procedure; cdecl;
  TCONF_modules_unload = procedure(all: TOpenSSL_Int); cdecl;
  TCONF_module_add = function(const name: PAnsiChar; ifunc: TCONF_init_func; ffunc: TCONF_finish_func): TOpenSSL_Int; cdecl;
  
  // Section operations  
  TNCONF_get_section = function(conf: PCONF; const section: PAnsiChar): PLHASH_NODE; cdecl;
  TNCONF_get_section_names = function(conf: PCONF): PLHASH_NODE; cdecl;
  
  // OpenSSL config functions
  TOPENSSL_config = procedure(const config_name: PAnsiChar); cdecl;
  TOPENSSL_no_config = procedure; cdecl;
  TOPENSSL_load_builtin_modules = procedure; cdecl;
  TOPENSSL_init = procedure; cdecl;
  
  // Callback type for CONF_parse_list
  TCONF_parse_list_cb = function(const elem: PAnsiChar; len: TOpenSSL_Int; usr: Pointer): TOpenSSL_Int; cdecl;
  
  // Error handling
  TCONF_parse_list = function(const list: PAnsiChar; sep: TOpenSSL_Int; nospc: TOpenSSL_Int; 
                              list_cb: TCONF_parse_list_cb;
                              arg: Pointer): TOpenSSL_Int; cdecl;

const
  // Module flags
  CONF_MFLAGS_IGNORE_ERRORS = $1;
  CONF_MFLAGS_IGNORE_RETURN_CODES = $2;
  CONF_MFLAGS_SILENT = $4;
  CONF_MFLAGS_NO_DSO = $8;
  CONF_MFLAGS_IGNORE_MISSING_FILE = $10;
  CONF_MFLAGS_DEFAULT_SECTION = $20;

var
  // Function pointers
  NCONF_new: TNCONF_new = nil;
  NCONF_default: TNCONF_default = nil;
  NCONF_WIN32: TNCONF_WIN32 = nil;
  NCONF_free: TNCONF_free = nil;
  NCONF_free_data: TNCONF_free_data = nil;
  NCONF_load: TNCONF_load = nil;
  NCONF_load_fp: TNCONF_load_fp = nil;
  NCONF_load_bio: TNCONF_load_bio = nil;
  NCONF_get_string: TNCONF_get_string = nil;
  NCONF_get_number_e: TNCONF_get_number_e = nil;
  NCONF_dump_fp: TNCONF_dump_fp = nil;
  NCONF_dump_bio: TNCONF_dump_bio = nil;
  
  CONF_modules_load: TCONF_modules_load = nil;
  CONF_modules_load_file: TCONF_modules_load_file = nil;
  CONF_modules_free: TCONF_modules_free = nil;
  CONF_modules_finish: TCONF_modules_finish = nil;
  CONF_modules_unload: TCONF_modules_unload = nil;
  CONF_module_add: TCONF_module_add = nil;
  
  NCONF_get_section: TNCONF_get_section = nil;
  NCONF_get_section_names: TNCONF_get_section_names = nil;
  
  OPENSSL_config: TOPENSSL_config = nil;
  OPENSSL_no_config: TOPENSSL_no_config = nil;
  OPENSSL_load_builtin_modules: TOPENSSL_load_builtin_modules = nil;
  OPENSSL_init: TOPENSSL_init = nil;
  
  CONF_parse_list: TCONF_parse_list = nil;

// Helper functions
function NCONF_get_number(conf: PCONF; const group: PAnsiChar; const name: PAnsiChar): LongInt;

procedure LoadOpenSSLConf;
procedure UnloadOpenSSLConf;

implementation

uses nextpas.core.tls.openssl.loader; function NCONF_get_number(conf: PCONF; const group: PAnsiChar; const name: PAnsiChar): LongInt;
var
  status: TOpenSSL_Int;
  num: LongInt;
begin
  Result := 0;
  if Assigned(NCONF_get_number_e) then
  begin
    status := NCONF_get_number_e(conf, group, name, @num);
    if status > 0 then
      Result := num;
  end;
end;

procedure LoadOpenSSLConf;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    Exit;
    
  // Core config functions
  NCONF_new := TNCONF_new(GetCryptoProcAddress('NCONF_new'));
  NCONF_default := TNCONF_default(GetCryptoProcAddress('NCONF_default'));
  NCONF_WIN32 := TNCONF_WIN32(GetCryptoProcAddress('NCONF_WIN32'));
  NCONF_free := TNCONF_free(GetCryptoProcAddress('NCONF_free'));
  NCONF_free_data := TNCONF_free_data(GetCryptoProcAddress('NCONF_free_data'));
  NCONF_load := TNCONF_load(GetCryptoProcAddress('NCONF_load'));
  NCONF_load_fp := TNCONF_load_fp(GetCryptoProcAddress('NCONF_load_fp'));
  NCONF_load_bio := TNCONF_load_bio(GetCryptoProcAddress('NCONF_load_bio'));
  NCONF_get_string := TNCONF_get_string(GetCryptoProcAddress('NCONF_get_string'));
  NCONF_get_number_e := TNCONF_get_number_e(GetCryptoProcAddress('NCONF_get_number_e'));
  NCONF_dump_fp := TNCONF_dump_fp(GetCryptoProcAddress('NCONF_dump_fp'));
  NCONF_dump_bio := TNCONF_dump_bio(GetCryptoProcAddress('NCONF_dump_bio'));
  
  // Module management
  CONF_modules_load := TCONF_modules_load(GetCryptoProcAddress('CONF_modules_load'));
  CONF_modules_load_file := TCONF_modules_load_file(GetCryptoProcAddress('CONF_modules_load_file'));
  CONF_modules_free := TCONF_modules_free(GetCryptoProcAddress('CONF_modules_free'));
  CONF_modules_finish := TCONF_modules_finish(GetCryptoProcAddress('CONF_modules_finish'));
  CONF_modules_unload := TCONF_modules_unload(GetCryptoProcAddress('CONF_modules_unload'));
  CONF_module_add := TCONF_module_add(GetCryptoProcAddress('CONF_module_add'));
  
  // Section operations
  NCONF_get_section := TNCONF_get_section(GetCryptoProcAddress('NCONF_get_section'));
  NCONF_get_section_names := TNCONF_get_section_names(GetCryptoProcAddress('NCONF_get_section_names'));
  
  // OpenSSL initialization
  OPENSSL_config := TOPENSSL_config(GetCryptoProcAddress('OPENSSL_config'));
  OPENSSL_no_config := TOPENSSL_no_config(GetCryptoProcAddress('OPENSSL_no_config'));
  OPENSSL_load_builtin_modules := TOPENSSL_load_builtin_modules(GetCryptoProcAddress('OPENSSL_load_builtin_modules'));
  OPENSSL_init := TOPENSSL_init(GetCryptoProcAddress('OPENSSL_init'));
  
  // List parsing
  CONF_parse_list := TCONF_parse_list(GetCryptoProcAddress('CONF_parse_list'));
end;

procedure UnloadOpenSSLConf;
begin
  NCONF_new := nil;
  NCONF_default := nil;
  NCONF_WIN32 := nil;
  NCONF_free := nil;
  NCONF_free_data := nil;
  NCONF_load := nil;
  NCONF_load_fp := nil;
  NCONF_load_bio := nil;
  NCONF_get_string := nil;
  NCONF_get_number_e := nil;
  NCONF_dump_fp := nil;
  NCONF_dump_bio := nil;
  
  CONF_modules_load := nil;
  CONF_modules_load_file := nil;
  CONF_modules_free := nil;
  CONF_modules_finish := nil;
  CONF_modules_unload := nil;
  CONF_module_add := nil;
  
  NCONF_get_section := nil;
  NCONF_get_section_names := nil;
  
  OPENSSL_config := nil;
  OPENSSL_no_config := nil;
  OPENSSL_load_builtin_modules := nil;
  OPENSSL_init := nil;
  
  CONF_parse_list := nil;
end;

initialization

finalization
  UnloadOpenSSLConf;

end.