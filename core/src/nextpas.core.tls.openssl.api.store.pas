{
  OpenSSL STORE (存储) API 模块
  提供证书、密钥和其他对象的统一存储接口
}
unit nextpas.core.tls.openssl.api.store;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.tls.openssl.api, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.x509, nextpas.core.tls.openssl.api.evp, nextpas.core.tls.openssl.api.ui;

const
  // STORE 对象类型
  OSSL_STORE_INFO_NAME = 1;
  OSSL_STORE_INFO_PARAMS = 2;
  OSSL_STORE_INFO_PUBKEY = 3;
  OSSL_STORE_INFO_PKEY = 4;
  OSSL_STORE_INFO_CERT = 5;
  OSSL_STORE_INFO_CRL = 6;
  
  // STORE 搜索类型
  OSSL_STORE_SEARCH_BY_NAME = 1;
  OSSL_STORE_SEARCH_BY_ISSUER_SERIAL = 2;
  OSSL_STORE_SEARCH_BY_KEY_FINGERPRINT = 3;
  OSSL_STORE_SEARCH_BY_ALIAS = 4;
  
  // STORE 控制命令
  OSSL_STORE_C_USE_SECMEM = 1;
  OSSL_STORE_C_MLOCK = 2;
  OSSL_STORE_C_POST_PROCESS = 3;
  OSSL_STORE_C_INFO_TYPES = 4;
  OSSL_STORE_C_CUSTOM_START = 100;
  
  // STORE 标志
  OSSL_STORE_FLAG_ALIAS = $01;
  
  // STORE 错误码
  OSSL_STORE_R_AMBIGUOUS_CONTENT_TYPE = 100;
  OSSL_STORE_R_BAD_PASSWORD_READ = 101;
  OSSL_STORE_R_ERROR_VERIFYING_PKCS12_MAC = 102;
  OSSL_STORE_R_FINGERPRINT_SIZE_DOES_NOT_MATCH_DIGEST = 103;
  OSSL_STORE_R_INVALID_SCHEME = 104;
  OSSL_STORE_R_IS_NOT_A = 105;
  OSSL_STORE_R_LOADER_INCOMPLETE = 106;
  OSSL_STORE_R_LOADING_STARTED = 107;
  OSSL_STORE_R_NOT_A_CERTIFICATE = 108;
  OSSL_STORE_R_NOT_A_CRL = 109;
  OSSL_STORE_R_NOT_A_NAME = 110;
  OSSL_STORE_R_NOT_A_PRIVATE_KEY = 111;
  OSSL_STORE_R_NOT_A_PUBLIC_KEY = 112;
  OSSL_STORE_R_NOT_PARAMETERS = 113;
  OSSL_STORE_R_NO_LOADERS_FOUND = 114;
  OSSL_STORE_R_PASSPHRASE_CALLBACK_ERROR = 115;
  OSSL_STORE_R_PATH_MUST_BE_ABSOLUTE = 116;
  OSSL_STORE_R_SEARCH_ONLY_SUPPORTED_FOR_DIRECTORIES = 117;
  OSSL_STORE_R_UI_PROCESS_INTERRUPTED_OR_CANCELLED = 118;
  OSSL_STORE_R_UNREGISTERED_SCHEME = 119;
  OSSL_STORE_R_UNSUPPORTED_CONTENT_TYPE = 120;
  OSSL_STORE_R_UNSUPPORTED_OPERATION = 121;
  OSSL_STORE_R_UNSUPPORTED_SEARCH_TYPE = 122;
  OSSL_STORE_R_URI_AUTHORITY_UNSUPPORTED = 123;

type
  // 前向声明
  POSSL_STORE_CTX = ^OSSL_STORE_CTX;
  POSSL_STORE_INFO = ^OSSL_STORE_INFO;
  POSSL_STORE_SEARCH = ^OSSL_STORE_SEARCH;
  POSSL_STORE_LOADER = ^OSSL_STORE_LOADER;
  POSSL_STORE_LOADER_CTX = ^OSSL_STORE_LOADER_CTX;
  
  // 不透明结构体
  OSSL_STORE_CTX = record end;
  OSSL_STORE_INFO = record end;
  OSSL_STORE_SEARCH = record end;
  OSSL_STORE_LOADER = record end;
  OSSL_STORE_LOADER_CTX = record end;
  
  // 回调函数类型
  TOSSL_STORE_post_process_info_fn = function(store_info: POSSL_STORE_INFO;
                                              ui_method: PUI_METHOD;
                                              ui_data: Pointer): Integer; cdecl;
  Tpem_password_cb = function(buf: PAnsiChar; size: Integer; rwflag: Integer;
                              userdata: Pointer): Integer; cdecl;
  
  // STORE 加载器函数类型
  TOSSL_STORE_open_fn = function(loader: POSSL_STORE_LOADER;
                                uri: PAnsiChar; ui_method: PUI_METHOD;
                                ui_data: Pointer): POSSL_STORE_LOADER_CTX; cdecl;
  TOSSL_STORE_open_ex_fn = function(loader: POSSL_STORE_LOADER;
                                    uri: PAnsiChar; libctx: Pointer;
                                    propq: PAnsiChar; ui_method: PUI_METHOD;
                                    ui_data: Pointer): POSSL_STORE_LOADER_CTX; cdecl;
  TOSSL_STORE_attach_fn = function(loader: POSSL_STORE_LOADER; bio: PBIO;
                                  libctx: Pointer; propq: PAnsiChar;
                                  ui_method: PUI_METHOD;
                                  ui_data: Pointer): POSSL_STORE_LOADER_CTX; cdecl;
  TOSSL_STORE_ctrl_fn = function(ctx: POSSL_STORE_LOADER_CTX; cmd: Integer;
                                args: Pointer): Integer; cdecl;
  TOSSL_STORE_expect_fn = function(ctx: POSSL_STORE_LOADER_CTX;
                                  expected: Integer): Integer; cdecl;
  TOSSL_STORE_find_fn = function(ctx: POSSL_STORE_LOADER_CTX;
                                search: POSSL_STORE_SEARCH): Integer; cdecl;
  TOSSL_STORE_load_fn = function(ctx: POSSL_STORE_LOADER_CTX;
                                ui_method: PUI_METHOD;
                                ui_data: Pointer): POSSL_STORE_INFO; cdecl;
  TOSSL_STORE_eof_fn = function(ctx: POSSL_STORE_LOADER_CTX): Integer; cdecl;
  TOSSL_STORE_error_fn = function(ctx: POSSL_STORE_LOADER_CTX): Integer; cdecl;
  TOSSL_STORE_close_fn = function(ctx: POSSL_STORE_LOADER_CTX): Integer; cdecl;
  
  // 函数指针类型
  
  // OSSL_STORE_CTX 函数
  TOSSL_STORE_open = function(uri: PAnsiChar; ui_method: PUI_METHOD;
                            ui_data: Pointer; post_process: TOSSL_STORE_post_process_info_fn;
                            post_process_data: Pointer): POSSL_STORE_CTX; cdecl;
  TOSSL_STORE_open_ex = function(uri: PAnsiChar; libctx: Pointer;
                                propq: PAnsiChar; ui_method: PUI_METHOD;
                                ui_data: Pointer; params: Pointer;
                                post_process: TOSSL_STORE_post_process_info_fn;
                                post_process_data: Pointer): POSSL_STORE_CTX; cdecl;
  TOSSL_STORE_attach = function(bio: PBIO; scheme: PAnsiChar; libctx: Pointer;
                              propq: PAnsiChar; ui_method: PUI_METHOD;
                              ui_data: Pointer; params: Pointer;
                              post_process: TOSSL_STORE_post_process_info_fn;
                              post_process_data: Pointer): POSSL_STORE_CTX; cdecl;
  TOSSL_STORE_ctrl = function(ctx: POSSL_STORE_CTX; cmd: Integer): Integer; cdecl; varargs;
  TOSSL_STORE_vctrl = function(ctx: POSSL_STORE_CTX; cmd: Integer; args: Pointer): Integer; cdecl;
  TOSSL_STORE_load = function(ctx: POSSL_STORE_CTX): POSSL_STORE_INFO; cdecl;
  TOSSL_STORE_eof = function(ctx: POSSL_STORE_CTX): Integer; cdecl;
  TOSSL_STORE_error = function(ctx: POSSL_STORE_CTX): Integer; cdecl;
  TOSSL_STORE_close = function(ctx: POSSL_STORE_CTX): Integer; cdecl;
  
  // OSSL_STORE 期望函数
  TOSSL_STORE_expect = function(ctx: POSSL_STORE_CTX; expected_type: Integer): Integer; cdecl;
  TOSSL_STORE_supports_search = function(ctx: POSSL_STORE_CTX; search_type: Integer): Integer; cdecl;
  TOSSL_STORE_find = function(ctx: POSSL_STORE_CTX; search: POSSL_STORE_SEARCH): Integer; cdecl;
  
  // OSSL_STORE_INFO 函数
  TOSSL_STORE_INFO_get_type = function(info: POSSL_STORE_INFO): Integer; cdecl;
  TOSSL_STORE_INFO_get0_NAME = function(info: POSSL_STORE_INFO): PAnsiChar; cdecl;
  TOSSL_STORE_INFO_get0_NAME_description = function(info: POSSL_STORE_INFO): PAnsiChar; cdecl;
  TOSSL_STORE_INFO_get0_PARAMS = function(info: POSSL_STORE_INFO): PEVP_PKEY; cdecl;
  TOSSL_STORE_INFO_get0_PUBKEY = function(info: POSSL_STORE_INFO): PEVP_PKEY; cdecl;
  TOSSL_STORE_INFO_get0_PKEY = function(info: POSSL_STORE_INFO): PEVP_PKEY; cdecl;
  TOSSL_STORE_INFO_get0_CERT = function(info: POSSL_STORE_INFO): PX509; cdecl;
  TOSSL_STORE_INFO_get0_CRL = function(info: POSSL_STORE_INFO): PX509_CRL; cdecl;
  TOSSL_STORE_INFO_get1_NAME = function(info: POSSL_STORE_INFO): PAnsiChar; cdecl;
  TOSSL_STORE_INFO_get1_NAME_description = function(info: POSSL_STORE_INFO): PAnsiChar; cdecl;
  TOSSL_STORE_INFO_get1_PARAMS = function(info: POSSL_STORE_INFO): PEVP_PKEY; cdecl;
  TOSSL_STORE_INFO_get1_PUBKEY = function(info: POSSL_STORE_INFO): PEVP_PKEY; cdecl;
  TOSSL_STORE_INFO_get1_PKEY = function(info: POSSL_STORE_INFO): PEVP_PKEY; cdecl;
  TOSSL_STORE_INFO_get1_CERT = function(info: POSSL_STORE_INFO): PX509; cdecl;
  TOSSL_STORE_INFO_get1_CRL = function(info: POSSL_STORE_INFO): PX509_CRL; cdecl;
  TOSSL_STORE_INFO_type_string = function(typ: Integer): PAnsiChar; cdecl;
  TOSSL_STORE_INFO_free = procedure(info: POSSL_STORE_INFO); cdecl;
  
  // OSSL_STORE_INFO 创建函数
  TOSSL_STORE_INFO_new_NAME = function(name: PAnsiChar): POSSL_STORE_INFO; cdecl;
  TOSSL_STORE_INFO_set0_NAME_description = function(info: POSSL_STORE_INFO;
                                                    desc: PAnsiChar): Integer; cdecl;
  TOSSL_STORE_INFO_new_PARAMS = function(params: PEVP_PKEY): POSSL_STORE_INFO; cdecl;
  TOSSL_STORE_INFO_new_PUBKEY = function(pubkey: PEVP_PKEY): POSSL_STORE_INFO; cdecl;
  TOSSL_STORE_INFO_new_PKEY = function(pkey: PEVP_PKEY): POSSL_STORE_INFO; cdecl;
  TOSSL_STORE_INFO_new_CERT = function(cert: PX509): POSSL_STORE_INFO; cdecl;
  TOSSL_STORE_INFO_new_CRL = function(crl: PX509_CRL): POSSL_STORE_INFO; cdecl;
  
  // OSSL_STORE_SEARCH 函数
  TOSSL_STORE_SEARCH_free = procedure(search: POSSL_STORE_SEARCH); cdecl;
  TOSSL_STORE_SEARCH_get_type = function(search: POSSL_STORE_SEARCH): Integer; cdecl;
  TOSSL_STORE_SEARCH_get0_name = function(search: POSSL_STORE_SEARCH): PX509_NAME; cdecl;
  TOSSL_STORE_SEARCH_get0_serial = function(search: POSSL_STORE_SEARCH): PASN1_INTEGER; cdecl;
  TOSSL_STORE_SEARCH_get0_bytes = function(search: POSSL_STORE_SEARCH; len: PNativeUInt): PByte; cdecl;
  TOSSL_STORE_SEARCH_get0_string = function(search: POSSL_STORE_SEARCH): PAnsiChar; cdecl;
  TOSSL_STORE_SEARCH_get0_digest = function(search: POSSL_STORE_SEARCH): PEVP_MD; cdecl;
  
  // OSSL_STORE_SEARCH 创建函数
  TOSSL_STORE_SEARCH_by_name = function(name: PX509_NAME): POSSL_STORE_SEARCH; cdecl;
  TOSSL_STORE_SEARCH_by_issuer_serial = function(name: PX509_NAME;
                                                serial: PASN1_INTEGER): POSSL_STORE_SEARCH; cdecl;
  TOSSL_STORE_SEARCH_by_key_fingerprint = function(digest: PEVP_MD; bytes: PByte;
                                                  len: NativeUInt): POSSL_STORE_SEARCH; cdecl;
  TOSSL_STORE_SEARCH_by_alias = function(alias: PAnsiChar): POSSL_STORE_SEARCH; cdecl;
  
  // OSSL_STORE_LOADER 函数
  TOSSL_STORE_LOADER_new = function(e: PENGINE; scheme: PAnsiChar): POSSL_STORE_LOADER; cdecl;
  TOSSL_STORE_LOADER_get0_engine = function(loader: POSSL_STORE_LOADER): PENGINE; cdecl;
  TOSSL_STORE_LOADER_get0_scheme = function(loader: POSSL_STORE_LOADER): PAnsiChar; cdecl;
  TOSSL_STORE_LOADER_set_open = function(loader: POSSL_STORE_LOADER;
                                        open_function: TOSSL_STORE_open_fn): Integer; cdecl;
  TOSSL_STORE_LOADER_set_open_ex = function(loader: POSSL_STORE_LOADER;
                                            open_ex_function: TOSSL_STORE_open_ex_fn): Integer; cdecl;
  TOSSL_STORE_LOADER_set_attach = function(loader: POSSL_STORE_LOADER;
                                          attach_function: TOSSL_STORE_attach_fn): Integer; cdecl;
  TOSSL_STORE_LOADER_set_ctrl = function(loader: POSSL_STORE_LOADER;
                                        ctrl_function: TOSSL_STORE_ctrl_fn): Integer; cdecl;
  TOSSL_STORE_LOADER_set_expect = function(loader: POSSL_STORE_LOADER;
                                          expect_function: TOSSL_STORE_expect_fn): Integer; cdecl;
  TOSSL_STORE_LOADER_set_find = function(loader: POSSL_STORE_LOADER;
                                        find_function: TOSSL_STORE_find_fn): Integer; cdecl;
  TOSSL_STORE_LOADER_set_load = function(loader: POSSL_STORE_LOADER;
                                        load_function: TOSSL_STORE_load_fn): Integer; cdecl;
  TOSSL_STORE_LOADER_set_eof = function(loader: POSSL_STORE_LOADER;
                                        eof_function: TOSSL_STORE_eof_fn): Integer; cdecl;
  TOSSL_STORE_LOADER_set_error = function(loader: POSSL_STORE_LOADER;
                                          error_function: TOSSL_STORE_error_fn): Integer; cdecl;
  TOSSL_STORE_LOADER_set_close = function(loader: POSSL_STORE_LOADER;
                                          close_function: TOSSL_STORE_close_fn): Integer; cdecl;
  TOSSL_STORE_LOADER_free = procedure(loader: POSSL_STORE_LOADER); cdecl;
  TOSSL_STORE_register_loader = function(loader: POSSL_STORE_LOADER): Integer; cdecl;
  TOSSL_STORE_unregister_loader = function(scheme: PAnsiChar): POSSL_STORE_LOADER; cdecl;
  TOSSL_STORE_do_all_loaders = procedure(do_function: Pointer; do_arg: Pointer); cdecl;

var
  // OSSL_STORE_CTX 函数
  OSSL_STORE_open: TOSSL_STORE_open;
  OSSL_STORE_open_ex: TOSSL_STORE_open_ex;
  OSSL_STORE_attach: TOSSL_STORE_attach;
  OSSL_STORE_ctrl: TOSSL_STORE_ctrl;
  OSSL_STORE_vctrl: TOSSL_STORE_vctrl;
  OSSL_STORE_load: TOSSL_STORE_load;
  OSSL_STORE_eof: TOSSL_STORE_eof;
  OSSL_STORE_error: TOSSL_STORE_error;
  OSSL_STORE_close: TOSSL_STORE_close;
  
  // OSSL_STORE 期望函数
  OSSL_STORE_expect: TOSSL_STORE_expect;
  OSSL_STORE_supports_search: TOSSL_STORE_supports_search;
  OSSL_STORE_find: TOSSL_STORE_find;
  
  // OSSL_STORE_INFO 函数
  OSSL_STORE_INFO_get_type: TOSSL_STORE_INFO_get_type;
  OSSL_STORE_INFO_get0_NAME: TOSSL_STORE_INFO_get0_NAME;
  OSSL_STORE_INFO_get0_NAME_description: TOSSL_STORE_INFO_get0_NAME_description;
  OSSL_STORE_INFO_get0_PARAMS: TOSSL_STORE_INFO_get0_PARAMS;
  OSSL_STORE_INFO_get0_PUBKEY: TOSSL_STORE_INFO_get0_PUBKEY;
  OSSL_STORE_INFO_get0_PKEY: TOSSL_STORE_INFO_get0_PKEY;
  OSSL_STORE_INFO_get0_CERT: TOSSL_STORE_INFO_get0_CERT;
  OSSL_STORE_INFO_get0_CRL: TOSSL_STORE_INFO_get0_CRL;
  OSSL_STORE_INFO_get1_NAME: TOSSL_STORE_INFO_get1_NAME;
  OSSL_STORE_INFO_get1_NAME_description: TOSSL_STORE_INFO_get1_NAME_description;
  OSSL_STORE_INFO_get1_PARAMS: TOSSL_STORE_INFO_get1_PARAMS;
  OSSL_STORE_INFO_get1_PUBKEY: TOSSL_STORE_INFO_get1_PUBKEY;
  OSSL_STORE_INFO_get1_PKEY: TOSSL_STORE_INFO_get1_PKEY;
  OSSL_STORE_INFO_get1_CERT: TOSSL_STORE_INFO_get1_CERT;
  OSSL_STORE_INFO_get1_CRL: TOSSL_STORE_INFO_get1_CRL;
  OSSL_STORE_INFO_type_string: TOSSL_STORE_INFO_type_string;
  OSSL_STORE_INFO_free: TOSSL_STORE_INFO_free;
  
  // OSSL_STORE_INFO 创建函数
  OSSL_STORE_INFO_new_NAME: TOSSL_STORE_INFO_new_NAME;
  OSSL_STORE_INFO_set0_NAME_description: TOSSL_STORE_INFO_set0_NAME_description;
  OSSL_STORE_INFO_new_PARAMS: TOSSL_STORE_INFO_new_PARAMS;
  OSSL_STORE_INFO_new_PUBKEY: TOSSL_STORE_INFO_new_PUBKEY;
  OSSL_STORE_INFO_new_PKEY: TOSSL_STORE_INFO_new_PKEY;
  OSSL_STORE_INFO_new_CERT: TOSSL_STORE_INFO_new_CERT;
  OSSL_STORE_INFO_new_CRL: TOSSL_STORE_INFO_new_CRL;
  
  // OSSL_STORE_SEARCH 函数
  OSSL_STORE_SEARCH_free: TOSSL_STORE_SEARCH_free;
  OSSL_STORE_SEARCH_get_type: TOSSL_STORE_SEARCH_get_type;
  OSSL_STORE_SEARCH_get0_name: TOSSL_STORE_SEARCH_get0_name;
  OSSL_STORE_SEARCH_get0_serial: TOSSL_STORE_SEARCH_get0_serial;
  OSSL_STORE_SEARCH_get0_bytes: TOSSL_STORE_SEARCH_get0_bytes;
  OSSL_STORE_SEARCH_get0_string: TOSSL_STORE_SEARCH_get0_string;
  OSSL_STORE_SEARCH_get0_digest: TOSSL_STORE_SEARCH_get0_digest;
  
  // OSSL_STORE_SEARCH 创建函数
  OSSL_STORE_SEARCH_by_name_func: TOSSL_STORE_SEARCH_by_name;
  OSSL_STORE_SEARCH_by_issuer_serial_func: TOSSL_STORE_SEARCH_by_issuer_serial;
  OSSL_STORE_SEARCH_by_key_fingerprint_func: TOSSL_STORE_SEARCH_by_key_fingerprint;
  OSSL_STORE_SEARCH_by_alias_func: TOSSL_STORE_SEARCH_by_alias;
  
  // OSSL_STORE_LOADER 函数
  OSSL_STORE_LOADER_new: TOSSL_STORE_LOADER_new;
  OSSL_STORE_LOADER_get0_engine: TOSSL_STORE_LOADER_get0_engine;
  OSSL_STORE_LOADER_get0_scheme: TOSSL_STORE_LOADER_get0_scheme;
  OSSL_STORE_LOADER_set_open: TOSSL_STORE_LOADER_set_open;
  OSSL_STORE_LOADER_set_open_ex: TOSSL_STORE_LOADER_set_open_ex;
  OSSL_STORE_LOADER_set_attach: TOSSL_STORE_LOADER_set_attach;
  OSSL_STORE_LOADER_set_ctrl: TOSSL_STORE_LOADER_set_ctrl;
  OSSL_STORE_LOADER_set_expect: TOSSL_STORE_LOADER_set_expect;
  OSSL_STORE_LOADER_set_find: TOSSL_STORE_LOADER_set_find;
  OSSL_STORE_LOADER_set_load: TOSSL_STORE_LOADER_set_load;
  OSSL_STORE_LOADER_set_eof: TOSSL_STORE_LOADER_set_eof;
  OSSL_STORE_LOADER_set_error: TOSSL_STORE_LOADER_set_error;
  OSSL_STORE_LOADER_set_close: TOSSL_STORE_LOADER_set_close;
  OSSL_STORE_LOADER_free: TOSSL_STORE_LOADER_free;
  OSSL_STORE_register_loader: TOSSL_STORE_register_loader;
  OSSL_STORE_unregister_loader: TOSSL_STORE_unregister_loader;
  OSSL_STORE_do_all_loaders: TOSSL_STORE_do_all_loaders;

procedure LoadSTOREFunctions;
procedure UnloadSTOREFunctions;

// 辅助函数
function LoadCertificateFromStore(const URI: string; const Password: string = ''): PX509;
function LoadPrivateKeyFromStore(const URI: string; const Password: string = ''): PEVP_PKEY;
function LoadCertificateChainFromStore(const URI: string): TX509Array;
function SearchCertificateByAlias(const URI: string; const Alias: string): PX509;
function StoreObjectTypeToString(ObjType: Integer): string;

implementation

uses nextpas.core.tls.openssl.api.core, nextpas.core.tls.openssl.loader;

procedure LoadSTOREFunctions;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then Exit;
  
  // OSSL_STORE_CTX 函数
  OSSL_STORE_open := TOSSL_STORE_open(GetCryptoProcAddress('OSSL_STORE_open'));
  OSSL_STORE_open_ex := TOSSL_STORE_open_ex(GetCryptoProcAddress('OSSL_STORE_open_ex'));
  OSSL_STORE_attach := TOSSL_STORE_attach(GetCryptoProcAddress('OSSL_STORE_attach'));
  OSSL_STORE_ctrl := TOSSL_STORE_ctrl(GetCryptoProcAddress('OSSL_STORE_ctrl'));
  OSSL_STORE_vctrl := TOSSL_STORE_vctrl(GetCryptoProcAddress('OSSL_STORE_vctrl'));
  OSSL_STORE_load := TOSSL_STORE_load(GetCryptoProcAddress('OSSL_STORE_load'));
  OSSL_STORE_eof := TOSSL_STORE_eof(GetCryptoProcAddress('OSSL_STORE_eof'));
  OSSL_STORE_error := TOSSL_STORE_error(GetCryptoProcAddress('OSSL_STORE_error'));
  OSSL_STORE_close := TOSSL_STORE_close(GetCryptoProcAddress('OSSL_STORE_close'));
  
  // OSSL_STORE 期望函数
  OSSL_STORE_expect := TOSSL_STORE_expect(GetCryptoProcAddress('OSSL_STORE_expect'));
  OSSL_STORE_supports_search := TOSSL_STORE_supports_search(GetCryptoProcAddress('OSSL_STORE_supports_search'));
  OSSL_STORE_find := TOSSL_STORE_find(GetCryptoProcAddress('OSSL_STORE_find'));
  
  // OSSL_STORE_INFO 函数
  OSSL_STORE_INFO_get_type := TOSSL_STORE_INFO_get_type(GetCryptoProcAddress('OSSL_STORE_INFO_get_type'));
  OSSL_STORE_INFO_get0_NAME := TOSSL_STORE_INFO_get0_NAME(GetCryptoProcAddress('OSSL_STORE_INFO_get0_NAME'));
  OSSL_STORE_INFO_get0_NAME_description := TOSSL_STORE_INFO_get0_NAME_description(GetCryptoProcAddress('OSSL_STORE_INFO_get0_NAME_description'));
  OSSL_STORE_INFO_get0_PARAMS := TOSSL_STORE_INFO_get0_PARAMS(GetCryptoProcAddress('OSSL_STORE_INFO_get0_PARAMS'));
  OSSL_STORE_INFO_get0_PUBKEY := TOSSL_STORE_INFO_get0_PUBKEY(GetCryptoProcAddress('OSSL_STORE_INFO_get0_PUBKEY'));
  OSSL_STORE_INFO_get0_PKEY := TOSSL_STORE_INFO_get0_PKEY(GetCryptoProcAddress('OSSL_STORE_INFO_get0_PKEY'));
  OSSL_STORE_INFO_get0_CERT := TOSSL_STORE_INFO_get0_CERT(GetCryptoProcAddress('OSSL_STORE_INFO_get0_CERT'));
  OSSL_STORE_INFO_get0_CRL := TOSSL_STORE_INFO_get0_CRL(GetCryptoProcAddress('OSSL_STORE_INFO_get0_CRL'));
  OSSL_STORE_INFO_get1_NAME := TOSSL_STORE_INFO_get1_NAME(GetCryptoProcAddress('OSSL_STORE_INFO_get1_NAME'));
  OSSL_STORE_INFO_get1_NAME_description := TOSSL_STORE_INFO_get1_NAME_description(GetCryptoProcAddress('OSSL_STORE_INFO_get1_NAME_description'));
  OSSL_STORE_INFO_get1_PARAMS := TOSSL_STORE_INFO_get1_PARAMS(GetCryptoProcAddress('OSSL_STORE_INFO_get1_PARAMS'));
  OSSL_STORE_INFO_get1_PUBKEY := TOSSL_STORE_INFO_get1_PUBKEY(GetCryptoProcAddress('OSSL_STORE_INFO_get1_PUBKEY'));
  OSSL_STORE_INFO_get1_PKEY := TOSSL_STORE_INFO_get1_PKEY(GetCryptoProcAddress('OSSL_STORE_INFO_get1_PKEY'));
  OSSL_STORE_INFO_get1_CERT := TOSSL_STORE_INFO_get1_CERT(GetCryptoProcAddress('OSSL_STORE_INFO_get1_CERT'));
  OSSL_STORE_INFO_get1_CRL := TOSSL_STORE_INFO_get1_CRL(GetCryptoProcAddress('OSSL_STORE_INFO_get1_CRL'));
  OSSL_STORE_INFO_type_string := TOSSL_STORE_INFO_type_string(GetCryptoProcAddress('OSSL_STORE_INFO_type_string'));
  OSSL_STORE_INFO_free := TOSSL_STORE_INFO_free(GetCryptoProcAddress('OSSL_STORE_INFO_free'));
  
  // OSSL_STORE_INFO 创建函数
  OSSL_STORE_INFO_new_NAME := TOSSL_STORE_INFO_new_NAME(GetCryptoProcAddress('OSSL_STORE_INFO_new_NAME'));
  OSSL_STORE_INFO_set0_NAME_description := TOSSL_STORE_INFO_set0_NAME_description(GetCryptoProcAddress('OSSL_STORE_INFO_set0_NAME_description'));
  OSSL_STORE_INFO_new_PARAMS := TOSSL_STORE_INFO_new_PARAMS(GetCryptoProcAddress('OSSL_STORE_INFO_new_PARAMS'));
  OSSL_STORE_INFO_new_PUBKEY := TOSSL_STORE_INFO_new_PUBKEY(GetCryptoProcAddress('OSSL_STORE_INFO_new_PUBKEY'));
  OSSL_STORE_INFO_new_PKEY := TOSSL_STORE_INFO_new_PKEY(GetCryptoProcAddress('OSSL_STORE_INFO_new_PKEY'));
  OSSL_STORE_INFO_new_CERT := TOSSL_STORE_INFO_new_CERT(GetCryptoProcAddress('OSSL_STORE_INFO_new_CERT'));
  OSSL_STORE_INFO_new_CRL := TOSSL_STORE_INFO_new_CRL(GetCryptoProcAddress('OSSL_STORE_INFO_new_CRL'));
  
  // OSSL_STORE_SEARCH 函数
  OSSL_STORE_SEARCH_free := TOSSL_STORE_SEARCH_free(GetCryptoProcAddress('OSSL_STORE_SEARCH_free'));
  OSSL_STORE_SEARCH_get_type := TOSSL_STORE_SEARCH_get_type(GetCryptoProcAddress('OSSL_STORE_SEARCH_get_type'));
  OSSL_STORE_SEARCH_get0_name := TOSSL_STORE_SEARCH_get0_name(GetCryptoProcAddress('OSSL_STORE_SEARCH_get0_name'));
  OSSL_STORE_SEARCH_get0_serial := TOSSL_STORE_SEARCH_get0_serial(GetCryptoProcAddress('OSSL_STORE_SEARCH_get0_serial'));
  OSSL_STORE_SEARCH_get0_bytes := TOSSL_STORE_SEARCH_get0_bytes(GetCryptoProcAddress('OSSL_STORE_SEARCH_get0_bytes'));
  OSSL_STORE_SEARCH_get0_string := TOSSL_STORE_SEARCH_get0_string(GetCryptoProcAddress('OSSL_STORE_SEARCH_get0_string'));
  OSSL_STORE_SEARCH_get0_digest := TOSSL_STORE_SEARCH_get0_digest(GetCryptoProcAddress('OSSL_STORE_SEARCH_get0_digest'));
  
  // OSSL_STORE_SEARCH 创建函数
  OSSL_STORE_SEARCH_by_name_func := TOSSL_STORE_SEARCH_by_name(GetCryptoProcAddress('OSSL_STORE_SEARCH_by_name'));
  OSSL_STORE_SEARCH_by_issuer_serial_func := TOSSL_STORE_SEARCH_by_issuer_serial(GetCryptoProcAddress('OSSL_STORE_SEARCH_by_issuer_serial'));
  OSSL_STORE_SEARCH_by_key_fingerprint_func := TOSSL_STORE_SEARCH_by_key_fingerprint(GetCryptoProcAddress('OSSL_STORE_SEARCH_by_key_fingerprint'));
  OSSL_STORE_SEARCH_by_alias_func := TOSSL_STORE_SEARCH_by_alias(GetCryptoProcAddress('OSSL_STORE_SEARCH_by_alias'));
  
  // OSSL_STORE_LOADER 函数
  OSSL_STORE_LOADER_new := TOSSL_STORE_LOADER_new(GetCryptoProcAddress('OSSL_STORE_LOADER_new'));
  OSSL_STORE_LOADER_free := TOSSL_STORE_LOADER_free(GetCryptoProcAddress('OSSL_STORE_LOADER_free'));
  OSSL_STORE_LOADER_set_open := TOSSL_STORE_LOADER_set_open(GetCryptoProcAddress('OSSL_STORE_LOADER_set_open'));
  OSSL_STORE_LOADER_set_open_ex := TOSSL_STORE_LOADER_set_open_ex(GetCryptoProcAddress('OSSL_STORE_LOADER_set_open_ex'));
  OSSL_STORE_register_loader := TOSSL_STORE_register_loader(GetCryptoProcAddress('OSSL_STORE_register_loader'));
  OSSL_STORE_unregister_loader := TOSSL_STORE_unregister_loader(GetCryptoProcAddress('OSSL_STORE_unregister_loader'));
end;

procedure UnloadSTOREFunctions;
begin
  // 重置所有函数指针
  OSSL_STORE_open := nil;
  OSSL_STORE_open_ex := nil;
  OSSL_STORE_attach := nil;
  OSSL_STORE_ctrl := nil;
  OSSL_STORE_load := nil;
  OSSL_STORE_eof := nil;
  OSSL_STORE_error := nil;
  OSSL_STORE_close := nil;
  OSSL_STORE_expect := nil;
  OSSL_STORE_find := nil;
  OSSL_STORE_INFO_get_type := nil;
  OSSL_STORE_INFO_get0_CERT := nil;
  OSSL_STORE_INFO_get0_PKEY := nil;
  OSSL_STORE_INFO_free := nil;
  OSSL_STORE_SEARCH_free := nil;
  OSSL_STORE_SEARCH_by_alias_func := nil;
  OSSL_STORE_LOADER_new := nil;
  OSSL_STORE_LOADER_free := nil;
end;

function LoadCertificateFromStore(const URI: string; const Password: string): PX509;
var
  URIAnsi: AnsiString;
  StoreCtx: POSSL_STORE_CTX;
  StoreInfo: POSSL_STORE_INFO;
  InfoType: Integer;
  UIMethod: PUI_METHOD;
  
  function PasswordCallback(buf: PAnsiChar; size: Integer; rwflag: Integer;
                          userdata: Pointer): Integer; cdecl;
  var
    Pass: PAnsiChar;
    Len: Integer;
  begin
    Pass := PAnsiChar(userdata);
    if Pass = nil then
    begin
      Result := 0;
      Exit;
    end;
    
    Len := StrLen(Pass);
    if Len > size - 1 then
      Len := size - 1;
    
    Move(Pass^, buf^, Len);
    buf[Len] := #0;
    Result := Len;
  end;
  
begin
  Result := nil;
  
  if not Assigned(OSSL_STORE_open) or not Assigned(OSSL_STORE_load) or
    not Assigned(OSSL_STORE_eof) or not Assigned(OSSL_STORE_close) then
    Exit;
  
  URIAnsi := AnsiString(URI);
  
  // 创建 UI 方法（用于密码回调）
  UIMethod := nil;
  if Password <> '' then
  begin
    // Note: UI_METHOD creation requires additional API bindings.
    // For now, password-protected stores must be loaded separately.
    // This is a low-priority enhancement for GUI applications.
  end;
  
  // 打开存储
  StoreCtx := OSSL_STORE_open(PAnsiChar(URIAnsi), UIMethod, nil, nil, nil);
  if StoreCtx = nil then Exit;
  
  try
    // 期望证书类型
    if Assigned(OSSL_STORE_expect) then
      OSSL_STORE_expect(StoreCtx, OSSL_STORE_INFO_CERT);
    
    // 加载对象直到找到证书或到达末尾
    while OSSL_STORE_eof(StoreCtx) = 0 do
    begin
      StoreInfo := OSSL_STORE_load(StoreCtx);
      if StoreInfo = nil then Continue;
      
      try
        if Assigned(OSSL_STORE_INFO_get_type) then
        begin
          InfoType := OSSL_STORE_INFO_get_type(StoreInfo);
          if InfoType = OSSL_STORE_INFO_CERT then
          begin
            if Assigned(OSSL_STORE_INFO_get1_CERT) then
            begin
              Result := OSSL_STORE_INFO_get1_CERT(StoreInfo);
              if Result <> nil then
                Break;
            end;
          end;
        end;
      finally
        if Assigned(OSSL_STORE_INFO_free) then
          OSSL_STORE_INFO_free(StoreInfo);
      end;
    end;
    
  finally
    OSSL_STORE_close(StoreCtx);
  end;
end;

function LoadPrivateKeyFromStore(const URI: string; const Password: string): PEVP_PKEY;
var
  URIAnsi: AnsiString;
  StoreCtx: POSSL_STORE_CTX;
  StoreInfo: POSSL_STORE_INFO;
  InfoType: Integer;
begin
  Result := nil;
  
  if not Assigned(OSSL_STORE_open) or not Assigned(OSSL_STORE_load) or
    not Assigned(OSSL_STORE_eof) or not Assigned(OSSL_STORE_close) then
    Exit;
  
  URIAnsi := AnsiString(URI);
  
  // 打开存储
  StoreCtx := OSSL_STORE_open(PAnsiChar(URIAnsi), nil, nil, nil, nil);
  if StoreCtx = nil then Exit;
  
  try
    // 期望私钥类型
    if Assigned(OSSL_STORE_expect) then
      OSSL_STORE_expect(StoreCtx, OSSL_STORE_INFO_PKEY);
    
    // 加载对象直到找到私钥或到达末尾
    while OSSL_STORE_eof(StoreCtx) = 0 do
    begin
      StoreInfo := OSSL_STORE_load(StoreCtx);
      if StoreInfo = nil then Continue;
      
      try
        if Assigned(OSSL_STORE_INFO_get_type) then
        begin
          InfoType := OSSL_STORE_INFO_get_type(StoreInfo);
          if InfoType = OSSL_STORE_INFO_PKEY then
          begin
            if Assigned(OSSL_STORE_INFO_get1_PKEY) then
            begin
              Result := OSSL_STORE_INFO_get1_PKEY(StoreInfo);
              if Result <> nil then
                Break;
            end;
          end;
        end;
      finally
        if Assigned(OSSL_STORE_INFO_free) then
          OSSL_STORE_INFO_free(StoreInfo);
      end;
    end;
    
  finally
    OSSL_STORE_close(StoreCtx);
  end;
end;

function LoadCertificateChainFromStore(const URI: string): TX509Array;
var
  URIAnsi: AnsiString;
  StoreCtx: POSSL_STORE_CTX;
  StoreInfo: POSSL_STORE_INFO;
  InfoType: Integer;
  Cert: PX509;
  Count: Integer;
begin
  Result := nil;

  if not Assigned(OSSL_STORE_open) or not Assigned(OSSL_STORE_load) or
    not Assigned(OSSL_STORE_eof) or not Assigned(OSSL_STORE_close) then
    Exit;

  URIAnsi := AnsiString(URI);

  // 打开存储
  StoreCtx := OSSL_STORE_open(PAnsiChar(URIAnsi), nil, nil, nil, nil);
  if StoreCtx = nil then Exit;

  Count := 0;

  try
    // 期望证书类型
    if Assigned(OSSL_STORE_expect) then
      OSSL_STORE_expect(StoreCtx, OSSL_STORE_INFO_CERT);

    // 加载所有证书
    while OSSL_STORE_eof(StoreCtx) = 0 do
    begin
      StoreInfo := OSSL_STORE_load(StoreCtx);
      if StoreInfo = nil then Continue;

      try
        if Assigned(OSSL_STORE_INFO_get_type) then
        begin
          InfoType := OSSL_STORE_INFO_get_type(StoreInfo);
          if InfoType = OSSL_STORE_INFO_CERT then
          begin
            if Assigned(OSSL_STORE_INFO_get1_CERT) then
            begin
              Cert := OSSL_STORE_INFO_get1_CERT(StoreInfo);
              if Cert <> nil then
              begin
                Inc(Count);
                SetLength(Result, Count);
                Result[Count - 1] := Cert;
              end;
            end;
          end;
        end;
      finally
        if Assigned(OSSL_STORE_INFO_free) then
          OSSL_STORE_INFO_free(StoreInfo);
      end;
    end;

  finally
    OSSL_STORE_close(StoreCtx);
  end;
end;

function SearchCertificateByAlias(const URI: string; const Alias: string): PX509;
var
  URIAnsi: AnsiString;
  AliasAnsi: AnsiString;
  StoreCtx: POSSL_STORE_CTX;
  StoreInfo: POSSL_STORE_INFO;
  Search: POSSL_STORE_SEARCH;
  InfoType: Integer;
begin
  Result := nil;
  
  if not Assigned(OSSL_STORE_open) or not Assigned(OSSL_STORE_load) or
    not Assigned(OSSL_STORE_close) then
    Exit;
  
  URIAnsi := AnsiString(URI);
  AliasAnsi := AnsiString(Alias);
  
  // 打开存储
  StoreCtx := OSSL_STORE_open(PAnsiChar(URIAnsi), nil, nil, nil, nil);
  if StoreCtx = nil then Exit;
  
  try
    // 创建按别名搜索
    if Assigned(OSSL_STORE_SEARCH_by_alias_func) and Assigned(OSSL_STORE_find) then
    begin
      Search := OSSL_STORE_SEARCH_by_alias_func(PAnsiChar(AliasAnsi));
      if Search <> nil then
      begin
        try
          OSSL_STORE_find(StoreCtx, Search);
        finally
          if Assigned(OSSL_STORE_SEARCH_free) then
            OSSL_STORE_SEARCH_free(Search);
        end;
      end;
    end;
    
    // 期望证书类型
    if Assigned(OSSL_STORE_expect) then
      OSSL_STORE_expect(StoreCtx, OSSL_STORE_INFO_CERT);
    
    // 加载第一个匹配的证书
    if Assigned(OSSL_STORE_eof) then
    begin
      if OSSL_STORE_eof(StoreCtx) = 0 then
      begin
        StoreInfo := OSSL_STORE_load(StoreCtx);
        if StoreInfo <> nil then
        begin
          try
            if Assigned(OSSL_STORE_INFO_get_type) and Assigned(OSSL_STORE_INFO_get1_CERT) then
            begin
              InfoType := OSSL_STORE_INFO_get_type(StoreInfo);
              if InfoType = OSSL_STORE_INFO_CERT then
                Result := OSSL_STORE_INFO_get1_CERT(StoreInfo);
            end;
          finally
            if Assigned(OSSL_STORE_INFO_free) then
              OSSL_STORE_INFO_free(StoreInfo);
          end;
        end;
      end;
    end;
    
  finally
    OSSL_STORE_close(StoreCtx);
  end;
end;

function StoreObjectTypeToString(ObjType: Integer): string;
begin
  case ObjType of
    OSSL_STORE_INFO_NAME: Result := 'Name';
    OSSL_STORE_INFO_PARAMS: Result := 'Parameters';
    OSSL_STORE_INFO_PUBKEY: Result := 'Public Key';
    OSSL_STORE_INFO_PKEY: Result := 'Private Key';
    OSSL_STORE_INFO_CERT: Result := 'Certificate';
    OSSL_STORE_INFO_CRL: Result := 'CRL';
  else
    Result := 'Unknown';
  end;
end;

initialization
  
finalization
  UnloadSTOREFunctions;
  
end.
