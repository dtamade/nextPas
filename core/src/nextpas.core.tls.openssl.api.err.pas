unit nextpas.core.tls.openssl.api.err;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.text.conv,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.loader;

const
  { Error library codes }
  ERR_LIB_NONE            = 1;
  ERR_LIB_SYS             = 2;
  ERR_LIB_BN              = 3;
  ERR_LIB_RSA             = 4;
  ERR_LIB_DH              = 5;
  ERR_LIB_EVP             = 6;
  ERR_LIB_BUF             = 7;
  ERR_LIB_OBJ             = 8;
  ERR_LIB_PEM             = 9;
  ERR_LIB_DSA             = 10;
  ERR_LIB_X509            = 11;
  ERR_LIB_ASN1            = 12;
  ERR_LIB_CONF            = 14;
  ERR_LIB_CRYPTO          = 15;
  ERR_LIB_EC              = 16;
  ERR_LIB_SSL             = 20;
  ERR_LIB_BIO             = 32;
  ERR_LIB_PKCS7           = 33;
  ERR_LIB_X509V3          = 34;
  ERR_LIB_PKCS12          = 35;
  ERR_LIB_RAND            = 36;
  ERR_LIB_DSO             = 37;
  ERR_LIB_ENGINE          = 38;
  ERR_LIB_OCSP            = 39;
  ERR_LIB_UI              = 40;
  ERR_LIB_COMP            = 41;
  ERR_LIB_ECDSA           = 42;
  ERR_LIB_ECDH            = 43;
  ERR_LIB_HMAC            = 48;
  ERR_LIB_CMS             = 46;
  ERR_LIB_TS              = 47;
  ERR_LIB_CT              = 50;
  ERR_LIB_ASYNC           = 51;
  ERR_LIB_KDF             = 52;
  ERR_LIB_SM2             = 53;
  ERR_LIB_ESS             = 54;
  ERR_LIB_PROP            = 55;
  ERR_LIB_CRMF            = 56;
  ERR_LIB_PROV            = 57;
  ERR_LIB_CMP             = 58;
  ERR_LIB_OSSL_ENCODER    = 59;
  ERR_LIB_OSSL_DECODER    = 60;
  ERR_LIB_HTTP            = 61;
  ERR_LIB_USER            = 128;

  { Error reason flags }
  ERR_R_FATAL                     = 64;
  ERR_R_SYS_LIB                   = ERR_LIB_SYS;
  ERR_R_BN_LIB                    = ERR_LIB_BN;
  ERR_R_RSA_LIB                   = ERR_LIB_RSA;
  ERR_R_DH_LIB                    = ERR_LIB_DH;
  ERR_R_EVP_LIB                   = ERR_LIB_EVP;
  ERR_R_BUF_LIB                   = ERR_LIB_BUF;
  ERR_R_OBJ_LIB                   = ERR_LIB_OBJ;
  ERR_R_PEM_LIB                   = ERR_LIB_PEM;
  ERR_R_DSA_LIB                   = ERR_LIB_DSA;
  ERR_R_X509_LIB                  = ERR_LIB_X509;
  ERR_R_ASN1_LIB                  = ERR_LIB_ASN1;
  ERR_R_EC_LIB                    = ERR_LIB_EC;
  ERR_R_BIO_LIB                   = ERR_LIB_BIO;
  ERR_R_PKCS7_LIB                 = ERR_LIB_PKCS7;
  ERR_R_X509V3_LIB                = ERR_LIB_X509V3;
  ERR_R_ENGINE_LIB                = ERR_LIB_ENGINE;
  ERR_R_UI_LIB                    = ERR_LIB_UI;
  ERR_R_ECDSA_LIB                 = ERR_LIB_ECDSA;

  { Common error reasons }
  ERR_R_NESTED_ASN1_ERROR         = 58;
  ERR_R_MISSING_ASN1_EOS          = 63;
  ERR_R_MALLOC_FAILURE            = 65;
  ERR_R_SHOULD_NOT_HAVE_BEEN_CALLED = 66;
  ERR_R_PASSED_NULL_PARAMETER     = 67;
  ERR_R_INTERNAL_ERROR            = 68;
  ERR_R_DISABLED                  = 69;
  ERR_R_INIT_FAIL                 = 70;
  ERR_R_PASSED_INVALID_ARGUMENT   = 71;
  ERR_R_OPERATION_FAIL            = 72;
  ERR_R_INVALID_PROVIDER_FUNCTIONS = 73;
  ERR_R_INTERRUPTED_OR_CANCELLED  = 74;
  ERR_R_NESTED_ASN1_STRING        = 75;
  ERR_R_MISSING_ASN1_EOC          = 76;

  { Error string buffer sizes }
  ERR_MAX_DATA_SIZE = 1024;
  
  { Error flags }
  ERR_TXT_MALLOCED = $01;
  ERR_TXT_STRING   = $02;
  
  { Error file/line flags }
  ERR_FLAG_MARK    = $01;
  ERR_FLAG_CLEAR   = $02;
  
  { Error queue size }
  ERR_NUM_ERRORS = 16;

type
  { Error state structure }
  ERR_STATE = record
    tid: TCRYPTO_THREADID;
    err_flags: array[0..ERR_NUM_ERRORS-1] of Integer;
    err_buffer: array[0..ERR_NUM_ERRORS-1] of Cardinal;
    err_data: array[0..ERR_NUM_ERRORS-1] of PAnsiChar;
    err_data_flags: array[0..ERR_NUM_ERRORS-1] of Integer;
    err_file: array[0..ERR_NUM_ERRORS-1] of PAnsiChar;
    err_line: array[0..ERR_NUM_ERRORS-1] of Integer;
    top: Integer;
    bottom: Integer;
  end;
  PERR_STATE = ^ERR_STATE;

type
  { Function types }
  TERR_get_error = function: Cardinal; cdecl;
  TERR_get_error_line = function(const &file: PPAnsiChar; line: PInteger): Cardinal; cdecl;
  TERR_get_error_line_data = function(const &file: PPAnsiChar; line: PInteger; const data: PPAnsiChar; flags: PInteger): Cardinal; cdecl;
  TERR_peek_error = function: Cardinal; cdecl;
  TERR_peek_error_line = function(const &file: PPAnsiChar; line: PInteger): Cardinal; cdecl;
  TERR_peek_error_line_data = function(const &file: PPAnsiChar; line: PInteger; const data: PPAnsiChar; flags: PInteger): Cardinal; cdecl;
  TERR_peek_last_error = function: Cardinal; cdecl;
  TERR_peek_last_error_line = function(const &file: PPAnsiChar; line: PInteger): Cardinal; cdecl;
  TERR_peek_last_error_line_data = function(const &file: PPAnsiChar; line: PInteger; const data: PPAnsiChar; flags: PInteger): Cardinal; cdecl;
  TERR_clear_error = procedure; cdecl;
  TERR_error_string = function(e: Cardinal): PAnsiChar; cdecl;
  TERR_error_string_n = procedure(e: Cardinal; buf: PAnsiChar; len: size_t); cdecl;
  TERR_lib_error_string = function(e: Cardinal): PAnsiChar; cdecl;
  TERR_func_error_string = function(e: Cardinal): PAnsiChar; cdecl;
  TERR_reason_error_string = function(e: Cardinal): PAnsiChar; cdecl;
  TERR_print_errors_cb = procedure(cb: Pointer; u: Pointer); cdecl;
  TERR_print_errors = procedure(bp: PBIO); cdecl;
  TERR_print_errors_fp = procedure(fp: Pointer); cdecl;
  TERR_load_strings = function(lib: Integer; str: Pointer): Integer; cdecl;
  TERR_load_strings_const = function(str: Pointer): Integer; cdecl;
  TERR_unload_strings = function(lib: Integer; str: Pointer): Integer; cdecl;
  TERR_load_ERR_strings = function: Integer; cdecl;
  
  { OpenSSL 1.1.0+ functions }
  TERR_load_BIO_strings = function: Integer; cdecl;
  TERR_load_BN_strings = function: Integer; cdecl;
  TERR_load_BUF_strings = function: Integer; cdecl;
  TERR_load_CMS_strings = function: Integer; cdecl;
  TERR_load_COMP_strings = function: Integer; cdecl;
  TERR_load_CONF_strings = function: Integer; cdecl;
  TERR_load_CRYPTO_strings = function: Integer; cdecl;
  TERR_load_CT_strings = function: Integer; cdecl;
  TERR_load_DH_strings = function: Integer; cdecl;
  TERR_load_DSA_strings = function: Integer; cdecl;
  TERR_load_EC_strings = function: Integer; cdecl;
  TERR_load_ENGINE_strings = function: Integer; cdecl;
  TERR_load_EVP_strings = function: Integer; cdecl;
  TERR_load_KDF_strings = function: Integer; cdecl;
  TERR_load_OBJ_strings = function: Integer; cdecl;
  TERR_load_OCSP_strings = function: Integer; cdecl;
  TERR_load_PEM_strings = function: Integer; cdecl;
  TERR_load_PKCS7_strings = function: Integer; cdecl;
  TERR_load_PKCS12_strings = function: Integer; cdecl;
  TERR_load_RAND_strings = function: Integer; cdecl;
  TERR_load_RSA_strings = function: Integer; cdecl;
  TERR_load_OSSL_STORE_strings = function: Integer; cdecl;
  TERR_load_TS_strings = function: Integer; cdecl;
  TERR_load_UI_strings = function: Integer; cdecl;
  TERR_load_X509_strings = function: Integer; cdecl;
  TERR_load_X509V3_strings = function: Integer; cdecl;

  { Error state management }
  TERR_get_state = function: PERR_STATE; cdecl;
  TERR_get_next_error_library = function: Integer; cdecl;
  TERR_set_mark = function: Integer; cdecl;
  TERR_pop_to_mark = function: Integer; cdecl;
  TERR_clear_last_mark = function: Integer; cdecl;
  
  { Error reporting }
  TERR_put_error = procedure(lib: Integer; func: Integer; reason: Integer; &file: PAnsiChar; line: Integer); cdecl;
  TERR_add_error_data = procedure(num: Integer); cdecl varargs;
  TERR_add_error_vdata = procedure(num: Integer; args: Pointer); cdecl;
  TERR_add_error_txt = procedure(sep: PAnsiChar; txt: PAnsiChar); cdecl;
  TERR_add_error_mem_bio = procedure(sep: PAnsiChar; bio: PBIO); cdecl;
  
  { New error system (OpenSSL 3.0+) }
  TERR_new = procedure; cdecl;
  TERR_set_debug = procedure(&file: PAnsiChar; line: Integer; func: PAnsiChar); cdecl;
  TERR_set_error = procedure(lib: Integer; reason: Integer; fmt: PAnsiChar); cdecl varargs;
  TERR_vset_error = procedure(lib: Integer; reason: Integer; fmt: PAnsiChar; args: Pointer); cdecl;
  TERR_raise = procedure(lib: Integer; reason: Integer); cdecl;
  TERR_raise_data = procedure(lib: Integer; reason: Integer; fmt: PAnsiChar); cdecl varargs;
  
  { Error callback }
  TERR_STATE_free = procedure(s: PERR_STATE); cdecl;
  TERR_remove_thread_state = procedure; cdecl;
  TERR_remove_state = procedure(pid: Cardinal); cdecl;
  TERR_get_err_state_table = function: Pointer; cdecl;
  TERR_release_err_state_table = procedure(table: Pointer); cdecl;
  TERR_get_string_table = function: Pointer; cdecl;
  TERR_PACK = function(lib: Integer; func: Integer; reason: Integer): Cardinal; cdecl;
  TERR_GET_LIB = function(err: Cardinal): Integer; cdecl;
  TERR_GET_FUNC = function(err: Cardinal): Integer; cdecl;
  TERR_GET_REASON = function(err: Cardinal): Integer; cdecl;
  TERR_FATAL_ERROR = function(err: Cardinal): Integer; cdecl;

var
  { Error functions }
  ERR_get_error: TERR_get_error;
  ERR_get_error_line: TERR_get_error_line;
  ERR_get_error_line_data: TERR_get_error_line_data;
  ERR_peek_error: TERR_peek_error;
  ERR_peek_error_line: TERR_peek_error_line;
  ERR_peek_error_line_data: TERR_peek_error_line_data;
  ERR_peek_last_error: TERR_peek_last_error;
  ERR_peek_last_error_line: TERR_peek_last_error_line;
  ERR_peek_last_error_line_data: TERR_peek_last_error_line_data;
  ERR_clear_error: TERR_clear_error;
  ERR_error_string: TERR_error_string;
  ERR_error_string_n: TERR_error_string_n;
  ERR_lib_error_string: TERR_lib_error_string;
  ERR_func_error_string: TERR_func_error_string;
  ERR_reason_error_string: TERR_reason_error_string;
  ERR_print_errors_cb: TERR_print_errors_cb;
  ERR_print_errors: TERR_print_errors;
  ERR_print_errors_fp: TERR_print_errors_fp;
  ERR_load_strings: TERR_load_strings;
  ERR_load_strings_const: TERR_load_strings_const;
  ERR_unload_strings: TERR_unload_strings;
  ERR_load_ERR_strings: TERR_load_ERR_strings;
  
  { Library-specific error loaders }
  ERR_load_BIO_strings: TERR_load_BIO_strings;
  ERR_load_BN_strings: TERR_load_BN_strings;
  ERR_load_BUF_strings: TERR_load_BUF_strings;
  ERR_load_CMS_strings: TERR_load_CMS_strings;
  ERR_load_COMP_strings: TERR_load_COMP_strings;
  ERR_load_CONF_strings: TERR_load_CONF_strings;
  ERR_load_CRYPTO_strings: TERR_load_CRYPTO_strings;
  ERR_load_CT_strings: TERR_load_CT_strings;
  ERR_load_DH_strings: TERR_load_DH_strings;
  ERR_load_DSA_strings: TERR_load_DSA_strings;
  ERR_load_EC_strings: TERR_load_EC_strings;
  ERR_load_ENGINE_strings: TERR_load_ENGINE_strings;
  ERR_load_EVP_strings: TERR_load_EVP_strings;
  ERR_load_KDF_strings: TERR_load_KDF_strings;
  ERR_load_OBJ_strings: TERR_load_OBJ_strings;
  ERR_load_OCSP_strings: TERR_load_OCSP_strings;
  ERR_load_PEM_strings: TERR_load_PEM_strings;
  ERR_load_PKCS7_strings: TERR_load_PKCS7_strings;
  ERR_load_PKCS12_strings: TERR_load_PKCS12_strings;
  ERR_load_RAND_strings: TERR_load_RAND_strings;
  ERR_load_RSA_strings: TERR_load_RSA_strings;
  ERR_load_OSSL_STORE_strings: TERR_load_OSSL_STORE_strings;
  ERR_load_TS_strings: TERR_load_TS_strings;
  ERR_load_UI_strings: TERR_load_UI_strings;
  ERR_load_X509_strings: TERR_load_X509_strings;
  ERR_load_X509V3_strings: TERR_load_X509V3_strings;
  
  { Error state management }
  ERR_get_state: TERR_get_state;
  ERR_get_next_error_library: TERR_get_next_error_library;
  ERR_set_mark: TERR_set_mark;
  ERR_pop_to_mark: TERR_pop_to_mark;
  ERR_clear_last_mark: TERR_clear_last_mark;
  
  { Error reporting }
  ERR_put_error: TERR_put_error;
  ERR_add_error_data: TERR_add_error_data;
  ERR_add_error_vdata: TERR_add_error_vdata;
  ERR_add_error_txt: TERR_add_error_txt;
  ERR_add_error_mem_bio: TERR_add_error_mem_bio;
  
  { New error system }
  ERR_new: TERR_new;
  ERR_set_debug: TERR_set_debug;
  ERR_set_error: TERR_set_error;
  ERR_vset_error: TERR_vset_error;
  ERR_raise: TERR_raise;
  ERR_raise_data: TERR_raise_data;
  
  { Error state }
  ERR_STATE_free: TERR_STATE_free;
  ERR_remove_thread_state: TERR_remove_thread_state;
  ERR_remove_state: TERR_remove_state;
  ERR_get_err_state_table: TERR_get_err_state_table;
  ERR_release_err_state_table: TERR_release_err_state_table;
  ERR_get_string_table: TERR_get_string_table;
  ERR_PACK: TERR_PACK;
  ERR_GET_LIB: TERR_GET_LIB;
  ERR_GET_FUNC: TERR_GET_FUNC;
  ERR_GET_REASON: TERR_GET_REASON;
  ERR_FATAL_ERROR: TERR_FATAL_ERROR;

{ Helper functions }
function ERR_GET_LIB_INLINE(err: Cardinal): Integer; inline;
function ERR_GET_FUNC_INLINE(err: Cardinal): Integer; inline;
function ERR_GET_REASON_INLINE(err: Cardinal): Integer; inline;
function ERR_FATAL_ERROR_INLINE(err: Cardinal): Boolean; inline;
function ERR_PACK_INLINE(lib, func, reason: Integer): Cardinal; inline;

function LoadOpenSSLERR: Boolean;
procedure UnloadOpenSSLERR;

// Error helper functions
function GetFriendlyErrorMessage(AErrorCode: Cardinal): string;
function ClassifyOpenSSLError(AErrorCode: Cardinal): TSSLErrorCode;
function GetOpenSSLErrorCategory(AErrorCode: Cardinal): string;

implementation

{ Helper functions }

function ERR_GET_LIB_INLINE(err: Cardinal): Integer;
begin
  Result := Integer((err shr 24) and $FF);
end;

function ERR_GET_FUNC_INLINE(err: Cardinal): Integer;
begin
  Result := Integer((err shr 12) and $FFF);
end;

function ERR_GET_REASON_INLINE(err: Cardinal): Integer;
begin
  Result := Integer(err and $FFF);
end;

function ERR_FATAL_ERROR_INLINE(err: Cardinal): Boolean;
begin
  Result := (ERR_GET_REASON_INLINE(err) and ERR_R_FATAL) <> 0;
end;

function ERR_PACK_INLINE(lib, func, reason: Integer): Cardinal;
begin
  Result := Cardinal((lib and $FF) shl 24) or 
            Cardinal((func and $FFF) shl 12) or 
            Cardinal(reason and $FFF);
end;

function LoadOpenSSLERR: Boolean;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmERR) then
    Exit(True);
    
  // Check if crypto library is loaded
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    Exit(False);
    
  // Load error functions
  ERR_get_error := TERR_get_error(GetCryptoProcAddress('ERR_get_error'));
  ERR_get_error_line := TERR_get_error_line(GetCryptoProcAddress('ERR_get_error_line'));
  ERR_get_error_line_data := TERR_get_error_line_data(GetCryptoProcAddress('ERR_get_error_line_data'));
  ERR_peek_error := TERR_peek_error(GetCryptoProcAddress('ERR_peek_error'));
  ERR_peek_error_line := TERR_peek_error_line(GetCryptoProcAddress('ERR_peek_error_line'));
  ERR_peek_error_line_data := TERR_peek_error_line_data(GetCryptoProcAddress('ERR_peek_error_line_data'));
  ERR_peek_last_error := TERR_peek_last_error(GetCryptoProcAddress('ERR_peek_last_error'));
  ERR_peek_last_error_line := TERR_peek_last_error_line(GetCryptoProcAddress('ERR_peek_last_error_line'));
  ERR_peek_last_error_line_data := TERR_peek_last_error_line_data(GetCryptoProcAddress('ERR_peek_last_error_line_data'));
  ERR_clear_error := TERR_clear_error(GetCryptoProcAddress('ERR_clear_error'));
  ERR_error_string := TERR_error_string(GetCryptoProcAddress('ERR_error_string'));
  ERR_error_string_n := TERR_error_string_n(GetCryptoProcAddress('ERR_error_string_n'));
  ERR_lib_error_string := TERR_lib_error_string(GetCryptoProcAddress('ERR_lib_error_string'));
  ERR_func_error_string := TERR_func_error_string(GetCryptoProcAddress('ERR_func_error_string'));
  ERR_reason_error_string := TERR_reason_error_string(GetCryptoProcAddress('ERR_reason_error_string'));
  ERR_print_errors_cb := TERR_print_errors_cb(GetCryptoProcAddress('ERR_print_errors_cb'));
  ERR_print_errors := TERR_print_errors(GetCryptoProcAddress('ERR_print_errors'));
  ERR_print_errors_fp := TERR_print_errors_fp(GetCryptoProcAddress('ERR_print_errors_fp'));
  ERR_load_strings := TERR_load_strings(GetCryptoProcAddress('ERR_load_strings'));
  ERR_load_strings_const := TERR_load_strings_const(GetCryptoProcAddress('ERR_load_strings_const'));
  ERR_unload_strings := TERR_unload_strings(GetCryptoProcAddress('ERR_unload_strings'));
  ERR_load_ERR_strings := TERR_load_ERR_strings(GetCryptoProcAddress('ERR_load_ERR_strings'));
  
  // Load library-specific error string loaders (may not exist in older versions)
  ERR_load_BIO_strings := TERR_load_BIO_strings(GetCryptoProcAddress('ERR_load_BIO_strings'));
  ERR_load_BN_strings := TERR_load_BN_strings(GetCryptoProcAddress('ERR_load_BN_strings'));
  ERR_load_BUF_strings := TERR_load_BUF_strings(GetCryptoProcAddress('ERR_load_BUF_strings'));
  ERR_load_CMS_strings := TERR_load_CMS_strings(GetCryptoProcAddress('ERR_load_CMS_strings'));
  ERR_load_COMP_strings := TERR_load_COMP_strings(GetCryptoProcAddress('ERR_load_COMP_strings'));
  ERR_load_CONF_strings := TERR_load_CONF_strings(GetCryptoProcAddress('ERR_load_CONF_strings'));
  ERR_load_CRYPTO_strings := TERR_load_CRYPTO_strings(GetCryptoProcAddress('ERR_load_CRYPTO_strings'));
  ERR_load_CT_strings := TERR_load_CT_strings(GetCryptoProcAddress('ERR_load_CT_strings'));
  ERR_load_DH_strings := TERR_load_DH_strings(GetCryptoProcAddress('ERR_load_DH_strings'));
  ERR_load_DSA_strings := TERR_load_DSA_strings(GetCryptoProcAddress('ERR_load_DSA_strings'));
  ERR_load_EC_strings := TERR_load_EC_strings(GetCryptoProcAddress('ERR_load_EC_strings'));
  ERR_load_ENGINE_strings := TERR_load_ENGINE_strings(GetCryptoProcAddress('ERR_load_ENGINE_strings'));
  ERR_load_EVP_strings := TERR_load_EVP_strings(GetCryptoProcAddress('ERR_load_EVP_strings'));
  ERR_load_KDF_strings := TERR_load_KDF_strings(GetCryptoProcAddress('ERR_load_KDF_strings'));
  ERR_load_OBJ_strings := TERR_load_OBJ_strings(GetCryptoProcAddress('ERR_load_OBJ_strings'));
  ERR_load_OCSP_strings := TERR_load_OCSP_strings(GetCryptoProcAddress('ERR_load_OCSP_strings'));
  ERR_load_PEM_strings := TERR_load_PEM_strings(GetCryptoProcAddress('ERR_load_PEM_strings'));
  ERR_load_PKCS7_strings := TERR_load_PKCS7_strings(GetCryptoProcAddress('ERR_load_PKCS7_strings'));
  ERR_load_PKCS12_strings := TERR_load_PKCS12_strings(GetCryptoProcAddress('ERR_load_PKCS12_strings'));
  ERR_load_RAND_strings := TERR_load_RAND_strings(GetCryptoProcAddress('ERR_load_RAND_strings'));
  ERR_load_RSA_strings := TERR_load_RSA_strings(GetCryptoProcAddress('ERR_load_RSA_strings'));
  ERR_load_OSSL_STORE_strings := TERR_load_OSSL_STORE_strings(GetCryptoProcAddress('ERR_load_OSSL_STORE_strings'));
  ERR_load_TS_strings := TERR_load_TS_strings(GetCryptoProcAddress('ERR_load_TS_strings'));
  ERR_load_UI_strings := TERR_load_UI_strings(GetCryptoProcAddress('ERR_load_UI_strings'));
  ERR_load_X509_strings := TERR_load_X509_strings(GetCryptoProcAddress('ERR_load_X509_strings'));
  ERR_load_X509V3_strings := TERR_load_X509V3_strings(GetCryptoProcAddress('ERR_load_X509V3_strings'));
  
  // Error state management
  ERR_get_state := TERR_get_state(GetCryptoProcAddress('ERR_get_state'));
  ERR_get_next_error_library := TERR_get_next_error_library(GetCryptoProcAddress('ERR_get_next_error_library'));
  ERR_set_mark := TERR_set_mark(GetCryptoProcAddress('ERR_set_mark'));
  ERR_pop_to_mark := TERR_pop_to_mark(GetCryptoProcAddress('ERR_pop_to_mark'));
  ERR_clear_last_mark := TERR_clear_last_mark(GetCryptoProcAddress('ERR_clear_last_mark'));
  
  // Error reporting
  ERR_put_error := TERR_put_error(GetCryptoProcAddress('ERR_put_error'));
  ERR_add_error_data := TERR_add_error_data(GetCryptoProcAddress('ERR_add_error_data'));
  ERR_add_error_vdata := TERR_add_error_vdata(GetCryptoProcAddress('ERR_add_error_vdata'));
  ERR_add_error_txt := TERR_add_error_txt(GetCryptoProcAddress('ERR_add_error_txt'));
  ERR_add_error_mem_bio := TERR_add_error_mem_bio(GetCryptoProcAddress('ERR_add_error_mem_bio'));
  
  // New error system (OpenSSL 3.0+)
  ERR_new := TERR_new(GetCryptoProcAddress('ERR_new'));
  ERR_set_debug := TERR_set_debug(GetCryptoProcAddress('ERR_set_debug'));
  ERR_set_error := TERR_set_error(GetCryptoProcAddress('ERR_set_error'));
  ERR_vset_error := TERR_vset_error(GetCryptoProcAddress('ERR_vset_error'));
  ERR_raise := TERR_raise(GetCryptoProcAddress('ERR_raise'));
  ERR_raise_data := TERR_raise_data(GetCryptoProcAddress('ERR_raise_data'));
  
  // Error state
  ERR_STATE_free := TERR_STATE_free(GetCryptoProcAddress('ERR_STATE_free'));
  ERR_remove_thread_state := TERR_remove_thread_state(GetCryptoProcAddress('ERR_remove_thread_state'));
  ERR_remove_state := TERR_remove_state(GetCryptoProcAddress('ERR_remove_state'));
  ERR_get_err_state_table := TERR_get_err_state_table(GetCryptoProcAddress('ERR_get_err_state_table'));
  ERR_release_err_state_table := TERR_release_err_state_table(GetCryptoProcAddress('ERR_release_err_state_table'));
  ERR_get_string_table := TERR_get_string_table(GetCryptoProcAddress('ERR_get_string_table'));
  ERR_PACK := TERR_PACK(GetCryptoProcAddress('ERR_PACK'));
  ERR_GET_LIB := TERR_GET_LIB(GetCryptoProcAddress('ERR_GET_LIB'));
  ERR_GET_FUNC := TERR_GET_FUNC(GetCryptoProcAddress('ERR_GET_FUNC'));
  ERR_GET_REASON := TERR_GET_REASON(GetCryptoProcAddress('ERR_GET_REASON'));
  ERR_FATAL_ERROR := TERR_FATAL_ERROR(GetCryptoProcAddress('ERR_FATAL_ERROR'));
  
  // The basic error functions should be available
  TOpenSSLLoader.SetModuleLoaded(osmERR, Assigned(ERR_get_error) and Assigned(ERR_clear_error));
  Result := TOpenSSLLoader.IsModuleLoaded(osmERR);
end;

procedure UnloadOpenSSLERR;
begin
  // Clear all function pointers
  ERR_get_error := nil;
  ERR_get_error_line := nil;
  ERR_get_error_line_data := nil;
  ERR_peek_error := nil;
  ERR_peek_error_line := nil;
  ERR_peek_error_line_data := nil;
  ERR_peek_last_error := nil;
  ERR_peek_last_error_line := nil;
  ERR_peek_last_error_line_data := nil;
  ERR_clear_error := nil;
  ERR_error_string := nil;
  ERR_error_string_n := nil;
  ERR_lib_error_string := nil;
  ERR_func_error_string := nil;
  ERR_reason_error_string := nil;
  ERR_print_errors_cb := nil;
  ERR_print_errors := nil;
  ERR_print_errors_fp := nil;
  ERR_load_strings := nil;
  ERR_load_strings_const := nil;
  ERR_unload_strings := nil;
  ERR_load_ERR_strings := nil;
  
  // Clear library-specific loaders
  ERR_load_BIO_strings := nil;
  ERR_load_BN_strings := nil;
  ERR_load_BUF_strings := nil;
  ERR_load_CMS_strings := nil;
  ERR_load_COMP_strings := nil;
  ERR_load_CONF_strings := nil;
  ERR_load_CRYPTO_strings := nil;
  ERR_load_CT_strings := nil;
  ERR_load_DH_strings := nil;
  ERR_load_DSA_strings := nil;
  ERR_load_EC_strings := nil;
  ERR_load_ENGINE_strings := nil;
  ERR_load_EVP_strings := nil;
  ERR_load_KDF_strings := nil;
  ERR_load_OBJ_strings := nil;
  ERR_load_OCSP_strings := nil;
  ERR_load_PEM_strings := nil;
  ERR_load_PKCS7_strings := nil;
  ERR_load_PKCS12_strings := nil;
  ERR_load_RAND_strings := nil;
  ERR_load_RSA_strings := nil;
  ERR_load_OSSL_STORE_strings := nil;
  ERR_load_TS_strings := nil;
  ERR_load_UI_strings := nil;
  ERR_load_X509_strings := nil;
  ERR_load_X509V3_strings := nil;
  
  // Clear state management
  ERR_get_state := nil;
  ERR_get_next_error_library := nil;
  ERR_set_mark := nil;
  ERR_pop_to_mark := nil;
  ERR_clear_last_mark := nil;
  
  // Clear error reporting
  ERR_put_error := nil;
  ERR_add_error_data := nil;
  ERR_add_error_vdata := nil;
  ERR_add_error_txt := nil;
  ERR_add_error_mem_bio := nil;
  
  // Clear new error system
  ERR_new := nil;
  ERR_set_debug := nil;
  ERR_set_error := nil;
  ERR_vset_error := nil;
  ERR_raise := nil;
  ERR_raise_data := nil;
  
  // Clear error state
  ERR_STATE_free := nil;
  ERR_remove_thread_state := nil;
  ERR_remove_state := nil;
  ERR_get_err_state_table := nil;
  ERR_release_err_state_table := nil;
  ERR_get_string_table := nil;
  ERR_PACK := nil;
  ERR_GET_LIB := nil;
  ERR_GET_FUNC := nil;
  ERR_GET_REASON := nil;
  ERR_FATAL_ERROR := nil;

  TOpenSSLLoader.SetModuleLoaded(osmERR, False);
end;


function GetOpenSSLErrorCategory(AErrorCode: Cardinal): string;
var
  LibCode: Integer;
begin
  LibCode := ERR_GET_LIB_INLINE(AErrorCode);
  case LibCode of
    ERR_LIB_SSL: Result := 'SSL';
    ERR_LIB_X509: Result := 'X.509';
    ERR_LIB_PEM: Result := 'PEM';
    ERR_LIB_ASN1: Result := 'ASN1';
    ERR_LIB_EVP: Result := 'EVP';
    ERR_LIB_BIO: Result := 'BIO';
    ERR_LIB_RSA: Result := 'RSA';
    ERR_LIB_EC: Result := 'EC';
    ERR_LIB_PKCS12: Result := 'PKCS12';
    ERR_LIB_PKCS7: Result := 'PKCS7';
    ERR_LIB_SYS: Result := 'SYSTEM';
  else
    Result := Format('LIB_%d', [LibCode]);
  end;
end;

function ClassifyOpenSSLError(AErrorCode: Cardinal): TSSLErrorCode;
var
  LibCode, ReasonCode: Integer;
begin
  LibCode := ERR_GET_LIB_INLINE(AErrorCode);
  ReasonCode := ERR_GET_REASON_INLINE(AErrorCode);

  case ReasonCode of
    ERR_R_MALLOC_FAILURE:
      Exit(sslErrMemory);
    ERR_R_PASSED_NULL_PARAMETER,
    ERR_R_PASSED_INVALID_ARGUMENT:
      Exit(sslErrInvalidParam);
    ERR_R_INIT_FAIL:
      Exit(sslErrNotInitialized);
  end;
  
  // Classify by library and reason
  case LibCode of
    ERR_LIB_SSL:
      Result := sslErrProtocol;
    ERR_LIB_X509:
      Result := sslErrCertificate;
    ERR_LIB_PEM:
      Result := sslErrGeneral;  // PEM format errors
    ERR_LIB_SYS:
      Result := sslErrIO;  // System errors typically I/O related
    ERR_LIB_BIO:
      Result := sslErrIO;
    ERR_LIB_RSA, ERR_LIB_DSA, ERR_LIB_EC, ERR_LIB_DH, ERR_LIB_EVP:
      Result := sslErrGeneral;  // Crypto errors
    ERR_LIB_NONE:
      Result := sslErrNone;
  else
    Result := sslErrOther;
  end;
end;

function GetFriendlyErrorMessage(AErrorCode: Cardinal): string;
var
  Category: string;
  Classification: TSSLErrorCode;
  LibCode, ReasonCode: Integer;
  ErrorString: string;
  ProblemText: string;
  DetailsText: string;
  SuggestionText: string;
  LErrorCStr: PAnsiChar;
begin
  if AErrorCode = 0 then
  begin
    Result := 'No error';
    Exit;
  end;

  if not TOpenSSLLoader.IsModuleLoaded(osmERR) then
    LoadOpenSSLERR;
  
  Category := GetOpenSSLErrorCategory(AErrorCode);
  Classification := ClassifyOpenSSLError(AErrorCode);
  LibCode := ERR_GET_LIB_INLINE(AErrorCode);
  ReasonCode := ERR_GET_REASON_INLINE(AErrorCode);

  case Classification of
    sslErrProtocol:
      ProblemText := 'TLS/SSL protocol error';
    sslErrCertificate:
      ProblemText := 'Certificate error';
    sslErrIO:
      ProblemText := 'I/O error';
    sslErrMemory:
      ProblemText := 'Out of memory';
    sslErrInvalidParam:
      ProblemText := 'Invalid parameter';
    sslErrNotInitialized:
      ProblemText := 'Library not initialized';
  else
    ProblemText := 'OpenSSL error';
  end;

  case Classification of
    sslErrProtocol:
      SuggestionText := 'Check protocol versions, cipher suites, and peer compatibility';
    sslErrCertificate:
      SuggestionText := 'Check certificate format, trust chain, and validity period';
    sslErrIO:
      SuggestionText := 'Check file path and permissions';
    sslErrMemory:
      SuggestionText := 'Check system memory availability';
    sslErrInvalidParam:
      SuggestionText := 'Check function parameters';
    sslErrNotInitialized:
      SuggestionText := 'Ensure the SSL library is initialized before use';
  else
    SuggestionText := 'Check OpenSSL error documentation and logs';
  end;

  ErrorString := '';
  if Assigned(ERR_error_string) then
  begin
    try
      LErrorCStr := ERR_error_string(AErrorCode);
      if LErrorCStr <> nil then
        ErrorString := string(LErrorCStr);
    except
      ErrorString := '';
    end;
  end;

  if ErrorString <> '' then
    DetailsText := ErrorString
  else
    DetailsText := 'Error details not available';

  DetailsText := DetailsText +
    ' (Lib:' + IntToStr(LibCode) +
    ', Reason:' + IntToStr(ReasonCode) +
    ', Code:0x' + IntToHex(AErrorCode, 8) + ')';

  Result := '[' + Category + ']' + LineEnding +
    'Problem: ' + ProblemText + LineEnding +
    'Details: ' + DetailsText + LineEnding +
    'Suggestion: ' + SuggestionText;
end;

end.