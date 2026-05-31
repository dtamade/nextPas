{
  OpenSSL CT (证书透明度) API 模块
  实现 RFC 6962 证书透明度支持
}
unit nextpas.core.tls.openssl.api.ct;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.evp;

const
  // CT 日志条目类型
  CT_LOG_ENTRY_TYPE_NOT_SET = -1;
  CT_LOG_ENTRY_TYPE_X509 = 0;
  CT_LOG_ENTRY_TYPE_PRECERT = 1;
  
  // SCT 版本
  SCT_VERSION_NOT_SET = -1;
  SCT_VERSION_V1 = 0;
  
  // SCT 来源
  SCT_SOURCE_UNKNOWN = 0;
  SCT_SOURCE_TLS_EXTENSION = 1;
  SCT_SOURCE_X509V3_EXTENSION = 2;
  SCT_SOURCE_OCSP_STAPLED_RESPONSE = 3;
  
  // SCT 验证状态
  SCT_VALIDATION_STATUS_NOT_SET = 0;
  SCT_VALIDATION_STATUS_UNKNOWN_LOG = 1;
  SCT_VALIDATION_STATUS_VALID = 2;
  SCT_VALIDATION_STATUS_INVALID = 3;
  SCT_VALIDATION_STATUS_UNVERIFIED = 4;
  SCT_VALIDATION_STATUS_UNKNOWN_VERSION = 5;
  
  // CT 策略评估结果
  CT_POLICY_EVAL_CTX_SUCCESS = 0;
  CT_POLICY_EVAL_CTX_FAILURE = -1;
  
  // CT 签名算法
  TLSEXT_signature_anonymous = 0;
  TLSEXT_signature_rsa = 1;
  TLSEXT_signature_dsa = 2;
  TLSEXT_signature_ecdsa = 3;
  
  // CT 哈希算法
  TLSEXT_hash_none = 0;
  TLSEXT_hash_md5 = 1;
  TLSEXT_hash_sha1 = 2;
  TLSEXT_hash_sha224 = 3;
  TLSEXT_hash_sha256 = 4;
  TLSEXT_hash_sha384 = 5;
  TLSEXT_hash_sha512 = 6;

  // CT NIDs
  NID_ct_precert_scts = 951;

type
  // 前向声明
  PCT_POLICY_EVAL_CTX = ^CT_POLICY_EVAL_CTX;
  PSCT = ^SCT;
  PPSCT = ^PSCT;
  PCTLOG = ^CTLOG;
  PCTLOG_STORE = ^CTLOG_STORE;
  PSCT_CTX = ^SCT_CTX;
  PSCT_LIST = ^SCT_LIST;
  PPSCT_LIST = ^PSCT_LIST;
  
  // 不透明结构体
  CT_POLICY_EVAL_CTX = record end;
  SCT = record end;
  CTLOG = record end;
  CTLOG_STORE = record end;
  SCT_CTX = record end;
  SCT_LIST = record end;
  
  // SCT 签名算法结构
  TSCT_signature_type = record
    HashAlg: Byte;
    SigAlg: Byte;
  end;
  
  // 回调函数类型
  TCT_VERIFY_CB = function(ctx: PCT_POLICY_EVAL_CTX; sct: PSCT; data: Pointer): Integer; cdecl;
  
  // 函数指针类型
  
  // CT_POLICY_EVAL_CTX 函数
  TCT_POLICY_EVAL_CTX_new = function(): PCT_POLICY_EVAL_CTX; cdecl;
  TCT_POLICY_EVAL_CTX_new_ex = function(libctx: Pointer; propq: PAnsiChar): PCT_POLICY_EVAL_CTX; cdecl;
  TCT_POLICY_EVAL_CTX_free = procedure(ctx: PCT_POLICY_EVAL_CTX); cdecl;
  TCT_POLICY_EVAL_CTX_get0_cert = function(ctx: PCT_POLICY_EVAL_CTX): PX509; cdecl;
  TCT_POLICY_EVAL_CTX_set1_cert = function(ctx: PCT_POLICY_EVAL_CTX; cert: PX509): Integer; cdecl;
  TCT_POLICY_EVAL_CTX_get0_issuer = function(ctx: PCT_POLICY_EVAL_CTX): PX509; cdecl;
  TCT_POLICY_EVAL_CTX_set1_issuer = function(ctx: PCT_POLICY_EVAL_CTX; issuer: PX509): Integer; cdecl;
  TCT_POLICY_EVAL_CTX_get0_log_store = function(ctx: PCT_POLICY_EVAL_CTX): PCTLOG_STORE; cdecl;
  TCT_POLICY_EVAL_CTX_set_shared_CTLOG_STORE = procedure(ctx: PCT_POLICY_EVAL_CTX; log_store: PCTLOG_STORE); cdecl;
  TCT_POLICY_EVAL_CTX_get_time = function(ctx: PCT_POLICY_EVAL_CTX): UInt64; cdecl;
  TCT_POLICY_EVAL_CTX_set_time = procedure(ctx: PCT_POLICY_EVAL_CTX; time_in_ms: UInt64); cdecl;
  
  // SCT 函数
  TSCT_new = function(): PSCT; cdecl;
  TSCT_new_from_base64 = function(version: Byte; logid_base64: PAnsiChar;
                                  entry_type: Integer; timestamp: UInt64;
                                  extensions_base64: PAnsiChar;
                                  signature_base64: PAnsiChar): PSCT; cdecl;
  TSCT_free = procedure(sct: PSCT); cdecl;
  TSCT_LIST_free = procedure(a: PSCT_LIST); cdecl;
  TSCT_get_version = function(sct: PSCT): Integer; cdecl;
  TSCT_set_version = function(sct: PSCT; version: Integer): Integer; cdecl;
  TSCT_get_log_entry_type = function(sct: PSCT): Integer; cdecl;
  TSCT_set_log_entry_type = function(sct: PSCT; entry_type: Integer): Integer; cdecl;
  TSCT_get0_log_id = function(sct: PSCT; log_id: PPByte): NativeUInt; cdecl;
  TSCT_set0_log_id = function(sct: PSCT; log_id: PByte; log_id_len: NativeUInt): Integer; cdecl;
  TSCT_set1_log_id = function(sct: PSCT; log_id: PByte; log_id_len: NativeUInt): Integer; cdecl;
  TSCT_get_timestamp = function(sct: PSCT): UInt64; cdecl;
  TSCT_set_timestamp = procedure(sct: PSCT; timestamp: UInt64); cdecl;
  TSCT_get0_extensions = function(sct: PSCT; ext: PPByte): NativeUInt; cdecl;
  TSCT_set0_extensions = procedure(sct: PSCT; ext: PByte; ext_len: NativeUInt); cdecl;
  TSCT_set1_extensions = function(sct: PSCT; ext: PByte; ext_len: NativeUInt): Integer; cdecl;
  TSCT_get0_signature = function(sct: PSCT; sig: PPByte): NativeUInt; cdecl;
  TSCT_set0_signature = procedure(sct: PSCT; sig: PByte; sig_len: NativeUInt); cdecl;
  TSCT_set1_signature = function(sct: PSCT; sig: PByte; sig_len: NativeUInt): Integer; cdecl;
  TSCT_get_source = function(sct: PSCT): Integer; cdecl;
  TSCT_set_source = function(sct: PSCT; source: Integer): Integer; cdecl;
  
  // SCT 验证函数
  TSCT_validate = function(sct: PSCT; ctx: PCT_POLICY_EVAL_CTX): Integer; cdecl;
  TSCT_LIST_validate = function(scts: PSCT_LIST; ctx: PCT_POLICY_EVAL_CTX): Integer; cdecl;
  TSCT_get_validation_status = function(sct: PSCT): Integer; cdecl;
  TSCT_print = procedure(sct: PSCT; outf: PBIO; indent: Integer; logs: PCTLOG_STORE); cdecl;
  TSCT_LIST_print = procedure(scts: PSCT_LIST; outf: PBIO; indent: Integer;
                            separator: PAnsiChar; logs: PCTLOG_STORE); cdecl;
  
  // CTLOG 函数
  TCTLOG_new = function(public_key: PEVP_PKEY; name: PAnsiChar): PCTLOG; cdecl;
  TCTLOG_new_ex = function(public_key: PEVP_PKEY; name: PAnsiChar;
                          libctx: Pointer; propq: PAnsiChar): PCTLOG; cdecl;
  TCTLOG_new_from_base64 = function(public_key: PCTLOG; name: PAnsiChar;
                                    key_base64: PAnsiChar): Integer; cdecl;
  TCTLOG_new_from_base64_ex = function(public_key: PCTLOG; name: PAnsiChar;
                                      key_base64: PAnsiChar; libctx: Pointer;
                                      propq: PAnsiChar): Integer; cdecl;
  TCTLOG_free = procedure(log: PCTLOG); cdecl;
  TCTLOG_get0_name = function(log: PCTLOG): PAnsiChar; cdecl;
  TCTLOG_get0_log_id = procedure(log: PCTLOG; log_id: PPByte; log_id_len: PNativeUInt); cdecl;
  TCTLOG_get0_public_key = function(log: PCTLOG): PEVP_PKEY; cdecl;
  
  // CTLOG_STORE 函数
  TCTLOG_STORE_new = function(): PCTLOG_STORE; cdecl;
  TCTLOG_STORE_new_ex = function(libctx: Pointer; propq: PAnsiChar): PCTLOG_STORE; cdecl;
  TCTLOG_STORE_free = procedure(store: PCTLOG_STORE); cdecl;
  TCTLOG_STORE_get0_log_by_id = function(store: PCTLOG_STORE; log_id: PByte;
                                        log_id_len: NativeUInt): PCTLOG; cdecl;
  TCTLOG_STORE_load_file = function(store: PCTLOG_STORE; filename: PAnsiChar): Integer; cdecl;
  TCTLOG_STORE_load_default_file = function(store: PCTLOG_STORE): Integer; cdecl;
  
  // i2d/d2i 函数
  Ti2o_SCT_LIST = function(scts: PSCT_LIST; ext: PPByte): Integer; cdecl;
  To2i_SCT_LIST = function(scts: PPSCT_LIST; ext: PPByte; len: NativeUInt): PSCT_LIST; cdecl;
  Ti2o_SCT = function(sct: PSCT; ext: PPByte): Integer; cdecl;
  To2i_SCT = function(sct: PPSCT; pp: PPByte; len: NativeUInt): PSCT; cdecl;
  
  // X509 扩展函数
  TX509_get_ext_d2i_SCT_LIST = function(x: PX509; nid: Integer; crit: PInteger;
                                        idx: PInteger): PSCT_LIST; cdecl;
  TX509_add1_ext_i2d_SCT_LIST = function(x: PX509; nid: Integer; value: PSCT_LIST;
                                        crit: Integer; flags: LongWord): Integer; cdecl;
  // TX509_get_SCT_LIST is a macro, implemented as a helper function
  
  // SSL CT 函数
  TSSL_CTX_enable_ct = function(ctx: PSSL_CTX; validation_mode: Integer): Integer; cdecl;
  TSSL_enable_ct = function(s: PSSL; validation_mode: Integer): Integer; cdecl;
  TSSL_CTX_ct_is_enabled = function(ctx: PSSL_CTX): Integer; cdecl;
  TSSL_ct_is_enabled = function(s: PSSL): Integer; cdecl;
  TSSL_CTX_set_default_ctlog_list_file = function(ctx: PSSL_CTX): Integer; cdecl;
  TSSL_CTX_set_ctlog_list_file = function(ctx: PSSL_CTX; path: PAnsiChar): Integer; cdecl;
  TSSL_CTX_set_ct_validation_callback = procedure(ctx: PSSL_CTX; callback: TCT_VERIFY_CB;
                                                  arg: Pointer); cdecl;
  TSSL_ct_set_validation_callback = procedure(s: PSSL; callback: TCT_VERIFY_CB;
                                            arg: Pointer); cdecl;
  TSSL_CTX_get0_ctlog_store = function(ctx: PSSL_CTX): PCTLOG_STORE; cdecl;
  TSSL_CTX_set0_ctlog_store = procedure(ctx: PSSL_CTX; logs: PCTLOG_STORE); cdecl;
  TSSL_get0_peer_scts = function(s: PSSL): PSCT_LIST; cdecl;
  
  // CT 策略函数
  TCT_POLICY_EVAL_CTX_set0_log_store = procedure(ctx: PCT_POLICY_EVAL_CTX;
                                                log_store: PCTLOG_STORE); cdecl;

var
  // CT_POLICY_EVAL_CTX 函数
  CT_POLICY_EVAL_CTX_new: TCT_POLICY_EVAL_CTX_new;
  CT_POLICY_EVAL_CTX_new_ex: TCT_POLICY_EVAL_CTX_new_ex;
  CT_POLICY_EVAL_CTX_free: TCT_POLICY_EVAL_CTX_free;
  CT_POLICY_EVAL_CTX_get0_cert: TCT_POLICY_EVAL_CTX_get0_cert;
  CT_POLICY_EVAL_CTX_set1_cert: TCT_POLICY_EVAL_CTX_set1_cert;
  CT_POLICY_EVAL_CTX_get0_issuer: TCT_POLICY_EVAL_CTX_get0_issuer;
  CT_POLICY_EVAL_CTX_set1_issuer: TCT_POLICY_EVAL_CTX_set1_issuer;
  CT_POLICY_EVAL_CTX_get0_log_store: TCT_POLICY_EVAL_CTX_get0_log_store;
  CT_POLICY_EVAL_CTX_set_shared_CTLOG_STORE: TCT_POLICY_EVAL_CTX_set_shared_CTLOG_STORE;
  CT_POLICY_EVAL_CTX_get_time: TCT_POLICY_EVAL_CTX_get_time;
  CT_POLICY_EVAL_CTX_set_time: TCT_POLICY_EVAL_CTX_set_time;
  
  // SCT 函数
  SCT_new: TSCT_new;
  SCT_new_from_base64: TSCT_new_from_base64;
  SCT_free: TSCT_free;
  SCT_LIST_free: TSCT_LIST_free;
  SCT_get_version: TSCT_get_version;
  SCT_set_version: TSCT_set_version;
  SCT_get_log_entry_type: TSCT_get_log_entry_type;
  SCT_set_log_entry_type: TSCT_set_log_entry_type;
  SCT_get0_log_id: TSCT_get0_log_id;
  SCT_set0_log_id: TSCT_set0_log_id;
  SCT_set1_log_id: TSCT_set1_log_id;
  SCT_get_timestamp: TSCT_get_timestamp;
  SCT_set_timestamp: TSCT_set_timestamp;
  SCT_get0_extensions: TSCT_get0_extensions;
  SCT_set0_extensions: TSCT_set0_extensions;
  SCT_set1_extensions: TSCT_set1_extensions;
  SCT_get0_signature: TSCT_get0_signature;
  SCT_set0_signature: TSCT_set0_signature;
  SCT_set1_signature: TSCT_set1_signature;
  SCT_get_source: TSCT_get_source;
  SCT_set_source: TSCT_set_source;
  
  // SCT 验证函数
  SCT_validate: TSCT_validate;
  SCT_LIST_validate: TSCT_LIST_validate;
  SCT_get_validation_status: TSCT_get_validation_status;
  SCT_print: TSCT_print;
  SCT_LIST_print: TSCT_LIST_print;
  
  // CTLOG 函数
  CTLOG_new: TCTLOG_new;
  CTLOG_new_ex: TCTLOG_new_ex;
  CTLOG_new_from_base64: TCTLOG_new_from_base64;
  CTLOG_new_from_base64_ex: TCTLOG_new_from_base64_ex;
  CTLOG_free: TCTLOG_free;
  CTLOG_get0_name: TCTLOG_get0_name;
  CTLOG_get0_log_id: TCTLOG_get0_log_id;
  CTLOG_get0_public_key: TCTLOG_get0_public_key;
  
  // CTLOG_STORE 函数
  CTLOG_STORE_new: TCTLOG_STORE_new;
  CTLOG_STORE_new_ex: TCTLOG_STORE_new_ex;
  CTLOG_STORE_free: TCTLOG_STORE_free;
  CTLOG_STORE_get0_log_by_id: TCTLOG_STORE_get0_log_by_id;
  CTLOG_STORE_load_file: TCTLOG_STORE_load_file;
  CTLOG_STORE_load_default_file: TCTLOG_STORE_load_default_file;
  
  // i2d/d2i 函数
  // i2d/d2i 函数 (SCT use i2o/o2i)
  i2o_SCT_LIST: Ti2o_SCT_LIST;
  o2i_SCT_LIST: To2i_SCT_LIST;
  i2o_SCT: Ti2o_SCT;
  o2i_SCT: To2i_SCT;
  
  // X509 扩展函数
  X509_get_ext_d2i_SCT_LIST: TX509_get_ext_d2i_SCT_LIST;
  X509_add1_ext_i2d_SCT_LIST: TX509_add1_ext_i2d_SCT_LIST;
  
  // SSL CT 函数
  SSL_CTX_enable_ct: TSSL_CTX_enable_ct;
  SSL_enable_ct: TSSL_enable_ct;
  SSL_CTX_ct_is_enabled: TSSL_CTX_ct_is_enabled;
  SSL_ct_is_enabled: TSSL_ct_is_enabled;
  SSL_CTX_set_default_ctlog_list_file: TSSL_CTX_set_default_ctlog_list_file;
  SSL_CTX_set_ctlog_list_file: TSSL_CTX_set_ctlog_list_file;
  SSL_CTX_set_ct_validation_callback: TSSL_CTX_set_ct_validation_callback;
  SSL_ct_set_validation_callback: TSSL_ct_set_validation_callback;
  SSL_CTX_get0_ctlog_store: TSSL_CTX_get0_ctlog_store;
  SSL_CTX_set0_ctlog_store: TSSL_CTX_set0_ctlog_store;
  SSL_get0_peer_scts: TSSL_get0_peer_scts;
  
  // CT 策略函数
  CT_POLICY_EVAL_CTX_set0_log_store: TCT_POLICY_EVAL_CTX_set0_log_store;

procedure LoadCTFunctions;
procedure UnloadCTFunctions;

// 辅助函数
function EnableCertificateTransparency(SSLCtx: PSSL_CTX): Boolean;
function ValidateSCTList(SCTs: PSCT_LIST; Cert: PX509; Issuer: PX509 = nil): Boolean;
function GetSCTValidationStatusString(Status: Integer): string;
function LoadCTLogStore(const FileName: string = ''): PCTLOG_STORE;
function PrintSCTInfo(SCT: PSCT): string;
function X509_get_SCT_LIST(x: PX509): PSCT_LIST;

implementation

uses
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.loader;

procedure LoadCTFunctions;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then Exit;
  
  // CT_POLICY_EVAL_CTX 函数
  CT_POLICY_EVAL_CTX_new := TCT_POLICY_EVAL_CTX_new(GetCryptoProcAddress('CT_POLICY_EVAL_CTX_new'));
  CT_POLICY_EVAL_CTX_new_ex := TCT_POLICY_EVAL_CTX_new_ex(GetCryptoProcAddress('CT_POLICY_EVAL_CTX_new_ex'));
  CT_POLICY_EVAL_CTX_free := TCT_POLICY_EVAL_CTX_free(GetCryptoProcAddress('CT_POLICY_EVAL_CTX_free'));
  CT_POLICY_EVAL_CTX_get0_cert := TCT_POLICY_EVAL_CTX_get0_cert(GetCryptoProcAddress('CT_POLICY_EVAL_CTX_get0_cert'));
  CT_POLICY_EVAL_CTX_set1_cert := TCT_POLICY_EVAL_CTX_set1_cert(GetCryptoProcAddress('CT_POLICY_EVAL_CTX_set1_cert'));
  CT_POLICY_EVAL_CTX_get0_issuer := TCT_POLICY_EVAL_CTX_get0_issuer(GetCryptoProcAddress('CT_POLICY_EVAL_CTX_get0_issuer'));
  CT_POLICY_EVAL_CTX_set1_issuer := TCT_POLICY_EVAL_CTX_set1_issuer(GetCryptoProcAddress('CT_POLICY_EVAL_CTX_set1_issuer'));
  CT_POLICY_EVAL_CTX_get0_log_store := TCT_POLICY_EVAL_CTX_get0_log_store(GetCryptoProcAddress('CT_POLICY_EVAL_CTX_get0_log_store'));
  CT_POLICY_EVAL_CTX_set_shared_CTLOG_STORE := TCT_POLICY_EVAL_CTX_set_shared_CTLOG_STORE(GetCryptoProcAddress('CT_POLICY_EVAL_CTX_set_shared_CTLOG_STORE'));
  CT_POLICY_EVAL_CTX_get_time := TCT_POLICY_EVAL_CTX_get_time(GetCryptoProcAddress('CT_POLICY_EVAL_CTX_get_time'));
  CT_POLICY_EVAL_CTX_set_time := TCT_POLICY_EVAL_CTX_set_time(GetCryptoProcAddress('CT_POLICY_EVAL_CTX_set_time'));
  
  // SCT 函数
  SCT_new := TSCT_new(GetCryptoProcAddress('SCT_new'));
  SCT_new_from_base64 := TSCT_new_from_base64(GetCryptoProcAddress('SCT_new_from_base64'));
  SCT_free := TSCT_free(GetCryptoProcAddress('SCT_free'));
  SCT_LIST_free := TSCT_LIST_free(GetCryptoProcAddress('SCT_LIST_free'));
  SCT_get_version := TSCT_get_version(GetCryptoProcAddress('SCT_get_version'));
  SCT_set_version := TSCT_set_version(GetCryptoProcAddress('SCT_set_version'));
  SCT_get_log_entry_type := TSCT_get_log_entry_type(GetCryptoProcAddress('SCT_get_log_entry_type'));
  SCT_set_log_entry_type := TSCT_set_log_entry_type(GetCryptoProcAddress('SCT_set_log_entry_type'));
  SCT_get0_log_id := TSCT_get0_log_id(GetCryptoProcAddress('SCT_get0_log_id'));
  SCT_set0_log_id := TSCT_set0_log_id(GetCryptoProcAddress('SCT_set0_log_id'));
  SCT_set1_log_id := TSCT_set1_log_id(GetCryptoProcAddress('SCT_set1_log_id'));
  SCT_get_timestamp := TSCT_get_timestamp(GetCryptoProcAddress('SCT_get_timestamp'));
  SCT_set_timestamp := TSCT_set_timestamp(GetCryptoProcAddress('SCT_set_timestamp'));
  SCT_get0_extensions := TSCT_get0_extensions(GetCryptoProcAddress('SCT_get0_extensions'));
  SCT_set0_extensions := TSCT_set0_extensions(GetCryptoProcAddress('SCT_set0_extensions'));
  SCT_set1_extensions := TSCT_set1_extensions(GetCryptoProcAddress('SCT_set1_extensions'));
  SCT_get0_signature := TSCT_get0_signature(GetCryptoProcAddress('SCT_get0_signature'));
  SCT_set0_signature := TSCT_set0_signature(GetCryptoProcAddress('SCT_set0_signature'));
  SCT_set1_signature := TSCT_set1_signature(GetCryptoProcAddress('SCT_set1_signature'));
  SCT_get_source := TSCT_get_source(GetCryptoProcAddress('SCT_get_source'));
  SCT_set_source := TSCT_set_source(GetCryptoProcAddress('SCT_set_source'));
  
  // SCT 验证函数
  SCT_validate := TSCT_validate(GetCryptoProcAddress('SCT_validate'));
  SCT_LIST_validate := TSCT_LIST_validate(GetCryptoProcAddress('SCT_LIST_validate'));
  SCT_get_validation_status := TSCT_get_validation_status(GetCryptoProcAddress('SCT_get_validation_status'));
  SCT_print := TSCT_print(GetCryptoProcAddress('SCT_print'));
  SCT_LIST_print := TSCT_LIST_print(GetCryptoProcAddress('SCT_LIST_print'));
  
  // CTLOG 函数
  CTLOG_new := TCTLOG_new(GetCryptoProcAddress('CTLOG_new'));
  CTLOG_new_ex := TCTLOG_new_ex(GetCryptoProcAddress('CTLOG_new_ex'));
  CTLOG_new_from_base64 := TCTLOG_new_from_base64(GetCryptoProcAddress('CTLOG_new_from_base64'));
  CTLOG_new_from_base64_ex := TCTLOG_new_from_base64_ex(GetCryptoProcAddress('CTLOG_new_from_base64_ex'));
  CTLOG_free := TCTLOG_free(GetCryptoProcAddress('CTLOG_free'));
  CTLOG_get0_name := TCTLOG_get0_name(GetCryptoProcAddress('CTLOG_get0_name'));
  CTLOG_get0_log_id := TCTLOG_get0_log_id(GetCryptoProcAddress('CTLOG_get0_log_id'));
  CTLOG_get0_public_key := TCTLOG_get0_public_key(GetCryptoProcAddress('CTLOG_get0_public_key'));
  
  // CTLOG_STORE 函数
  CTLOG_STORE_new := TCTLOG_STORE_new(GetCryptoProcAddress('CTLOG_STORE_new'));
  CTLOG_STORE_new_ex := TCTLOG_STORE_new_ex(GetCryptoProcAddress('CTLOG_STORE_new_ex'));
  CTLOG_STORE_free := TCTLOG_STORE_free(GetCryptoProcAddress('CTLOG_STORE_free'));
  CTLOG_STORE_get0_log_by_id := TCTLOG_STORE_get0_log_by_id(GetCryptoProcAddress('CTLOG_STORE_get0_log_by_id'));
  CTLOG_STORE_load_file := TCTLOG_STORE_load_file(GetCryptoProcAddress('CTLOG_STORE_load_file'));
  CTLOG_STORE_load_default_file := TCTLOG_STORE_load_default_file(GetCryptoProcAddress('CTLOG_STORE_load_default_file'));
  
  // i2d/d2i 函数
  i2o_SCT_LIST := Ti2o_SCT_LIST(GetCryptoProcAddress('i2o_SCT_LIST'));
  o2i_SCT_LIST := To2i_SCT_LIST(GetCryptoProcAddress('o2i_SCT_LIST'));
  i2o_SCT := Ti2o_SCT(GetCryptoProcAddress('i2o_SCT'));
  o2i_SCT := To2i_SCT(GetCryptoProcAddress('o2i_SCT'));
  
  // SSL CT 函数
  SSL_CTX_enable_ct := TSSL_CTX_enable_ct(GetSSLProcAddress('SSL_CTX_enable_ct'));
  SSL_enable_ct := TSSL_enable_ct(GetSSLProcAddress('SSL_enable_ct'));
  SSL_CTX_ct_is_enabled := TSSL_CTX_ct_is_enabled(GetSSLProcAddress('SSL_CTX_ct_is_enabled'));
  SSL_ct_is_enabled := TSSL_ct_is_enabled(GetSSLProcAddress('SSL_ct_is_enabled'));
  SSL_CTX_set_default_ctlog_list_file := TSSL_CTX_set_default_ctlog_list_file(GetSSLProcAddress('SSL_CTX_set_default_ctlog_list_file'));
  SSL_CTX_set_ctlog_list_file := TSSL_CTX_set_ctlog_list_file(GetSSLProcAddress('SSL_CTX_set_ctlog_list_file'));
  SSL_CTX_set_ct_validation_callback := TSSL_CTX_set_ct_validation_callback(GetSSLProcAddress('SSL_CTX_set_ct_validation_callback'));
  SSL_ct_set_validation_callback := TSSL_ct_set_validation_callback(GetSSLProcAddress('SSL_ct_set_validation_callback'));
  SSL_CTX_get0_ctlog_store := TSSL_CTX_get0_ctlog_store(GetSSLProcAddress('SSL_CTX_get0_ctlog_store'));
  SSL_CTX_set0_ctlog_store := TSSL_CTX_set0_ctlog_store(GetSSLProcAddress('SSL_CTX_set0_ctlog_store'));
  SSL_get0_peer_scts := TSSL_get0_peer_scts(GetSSLProcAddress('SSL_get0_peer_scts'));
  
  // CT 策略函数
  CT_POLICY_EVAL_CTX_set0_log_store := TCT_POLICY_EVAL_CTX_set0_log_store(GetCryptoProcAddress('CT_POLICY_EVAL_CTX_set0_log_store'));
  
  // X509 扩展函数
  X509_get_ext_d2i_SCT_LIST := TX509_get_ext_d2i_SCT_LIST(GetCryptoProcAddress('X509_get_ext_d2i_SCT_LIST'));
  X509_add1_ext_i2d_SCT_LIST := TX509_add1_ext_i2d_SCT_LIST(GetCryptoProcAddress('X509_add1_ext_i2d_SCT_LIST'));
end;

procedure UnloadCTFunctions;
begin
  // 重置所有函数指针
  CT_POLICY_EVAL_CTX_new := nil;
  CT_POLICY_EVAL_CTX_free := nil;
  SCT_new := nil;
  SCT_free := nil;
  SCT_LIST_free := nil;
  SCT_validate := nil;
  CTLOG_new := nil;
  CTLOG_free := nil;
  CTLOG_STORE_new := nil;
  CTLOG_STORE_free := nil;
  SSL_CTX_enable_ct := nil;
  SSL_enable_ct := nil;
  i2o_SCT := nil;
  o2i_SCT := nil;
  i2o_SCT_LIST := nil;
  o2i_SCT_LIST := nil;
end;

function EnableCertificateTransparency(SSLCtx: PSSL_CTX): Boolean;
begin
  Result := False;
  
  if SSLCtx = nil then Exit;
  if not Assigned(SSL_CTX_enable_ct) then Exit;
  
  // 启用 CT 验证
  if SSL_CTX_enable_ct(SSLCtx, 1) <> 1 then Exit;
  
  // 尝试加载默认的 CT 日志列表
  if Assigned(SSL_CTX_set_default_ctlog_list_file) then
    SSL_CTX_set_default_ctlog_list_file(SSLCtx);
  
  Result := True;
end;

function ValidateSCTList(SCTs: PSCT_LIST; Cert: PX509; Issuer: PX509): Boolean;
var
  EvalCtx: PCT_POLICY_EVAL_CTX;
  LogStore: PCTLOG_STORE;
begin
  Result := False;
  
  if SCTs = nil then Exit;
  if Cert = nil then Exit;
  
  if not Assigned(CT_POLICY_EVAL_CTX_new) or
    not Assigned(SCT_LIST_validate) or
    not Assigned(CT_POLICY_EVAL_CTX_free) then Exit;
  
  EvalCtx := CT_POLICY_EVAL_CTX_new();
  if EvalCtx = nil then Exit;
  
  try
    // 设置证书
    if Assigned(CT_POLICY_EVAL_CTX_set1_cert) then
      CT_POLICY_EVAL_CTX_set1_cert(EvalCtx, Cert);
    
    // 设置颁发者（如果提供）
    if (Issuer <> nil) and Assigned(CT_POLICY_EVAL_CTX_set1_issuer) then
      CT_POLICY_EVAL_CTX_set1_issuer(EvalCtx, Issuer);
    
    // 加载日志存储
    LogStore := LoadCTLogStore();
    if LogStore <> nil then
    begin
      if Assigned(CT_POLICY_EVAL_CTX_set_shared_CTLOG_STORE) then
        CT_POLICY_EVAL_CTX_set_shared_CTLOG_STORE(EvalCtx, LogStore);
    end;
    
    // 验证 SCT 列表
    Result := SCT_LIST_validate(SCTs, EvalCtx) = 1;
    
  finally
    CT_POLICY_EVAL_CTX_free(EvalCtx);
    if (LogStore <> nil) and Assigned(CTLOG_STORE_free) then
      CTLOG_STORE_free(LogStore);
  end;
end;

function GetSCTValidationStatusString(Status: Integer): string;
begin
  case Status of
    SCT_VALIDATION_STATUS_NOT_SET: Result := 'Not Set';
    SCT_VALIDATION_STATUS_UNKNOWN_LOG: Result := 'Unknown Log';
    SCT_VALIDATION_STATUS_VALID: Result := 'Valid';
    SCT_VALIDATION_STATUS_INVALID: Result := 'Invalid';
    SCT_VALIDATION_STATUS_UNVERIFIED: Result := 'Unverified';
    SCT_VALIDATION_STATUS_UNKNOWN_VERSION: Result := 'Unknown Version';
  else
    Result := 'Unknown Status';
  end;
end;

function LoadCTLogStore(const FileName: string): PCTLOG_STORE;
var
  FileNameAnsi: AnsiString;
begin
  Result := nil;
  
  if not Assigned(CTLOG_STORE_new) then Exit;
  
  Result := CTLOG_STORE_new();
  if Result = nil then Exit;
  
  if FileName <> '' then
  begin
    // 加载指定文件
    if Assigned(CTLOG_STORE_load_file) then
    begin
      FileNameAnsi := AnsiString(FileName);
      if CTLOG_STORE_load_file(Result, PAnsiChar(FileNameAnsi)) <> 1 then
      begin
        if Assigned(CTLOG_STORE_free) then
          CTLOG_STORE_free(Result);
        Result := nil;
      end;
    end;
  end
  else
  begin
    // 加载默认文件
    if Assigned(CTLOG_STORE_load_default_file) then
    begin
      if CTLOG_STORE_load_default_file(Result) <> 1 then
      begin
        if Assigned(CTLOG_STORE_free) then
          CTLOG_STORE_free(Result);
        Result := nil;
      end;
    end;
  end;
end;

function PrintSCTInfo(SCT: PSCT): string;
var
  Version: Integer;
  LogEntryType: Integer;
  Timestamp: UInt64;
  Source: Integer;
  Status: Integer;
  LogId: PByte;
  LogIdLen: NativeUInt;
  I: Integer;
begin
  Result := '';
  
  if SCT = nil then Exit;
  
  // 获取版本
  if Assigned(SCT_get_version) then
  begin
    Version := SCT_get_version(SCT);
    Result := Result + Format('Version: %d' + sLineBreak, [Version]);
  end;
  
  // 获取日志条目类型
  if Assigned(SCT_get_log_entry_type) then
  begin
    LogEntryType := SCT_get_log_entry_type(SCT);
    case LogEntryType of
      CT_LOG_ENTRY_TYPE_X509: Result := Result + 'Type: X.509 Certificate' + sLineBreak;
      CT_LOG_ENTRY_TYPE_PRECERT: Result := Result + 'Type: Pre-Certificate' + sLineBreak;
    else
      Result := Result + Format('Type: Unknown (%d)' + sLineBreak, [LogEntryType]);
    end;
  end;
  
  // 获取时间戳
  if Assigned(SCT_get_timestamp) then
  begin
    Timestamp := SCT_get_timestamp(SCT);
    Result := Result + Format('Timestamp: %d' + sLineBreak, [Timestamp]);
  end;
  
  // 获取来源
  if Assigned(SCT_get_source) then
  begin
    Source := SCT_get_source(SCT);
    case Source of
      SCT_SOURCE_TLS_EXTENSION: Result := Result + 'Source: TLS Extension' + sLineBreak;
      SCT_SOURCE_X509V3_EXTENSION: Result := Result + 'Source: X.509v3 Extension' + sLineBreak;
      SCT_SOURCE_OCSP_STAPLED_RESPONSE: Result := Result + 'Source: OCSP Stapled Response' + sLineBreak;
    else
      Result := Result + 'Source: Unknown' + sLineBreak;
    end;
  end;
  
  // 获取验证状态
  if Assigned(SCT_get_validation_status) then
  begin
    Status := SCT_get_validation_status(SCT);
    Result := Result + 'Status: ' + GetSCTValidationStatusString(Status) + sLineBreak;
  end;
  
  // 获取日志 ID
  if Assigned(SCT_get0_log_id) then
  begin
    LogIdLen := SCT_get0_log_id(SCT, @LogId);
    if LogIdLen > 0 then
    begin
      Result := Result + 'Log ID: ';
      for I := 0 to LogIdLen - 1 do
        Result := Result + Format('%.2x', [LogId[I]]);
      Result := Result + sLineBreak;
    end;
  end;
end;

function X509_get_SCT_LIST(x: PX509): PSCT_LIST;
begin
  Result := nil;
  if (x <> nil) and Assigned(X509_get_ext_d2i) then
    Result := PSCT_LIST(X509_get_ext_d2i(x, NID_ct_precert_scts, nil, nil));
end;

initialization
  
finalization
  UnloadCTFunctions;
  
end.