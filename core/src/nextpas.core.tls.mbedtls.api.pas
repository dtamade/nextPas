{**
 * Unit: nextpas.core.tls.mbedtls.api
 * Purpose: MbedTLS API 动态绑定
 *
 * P3-9: MbedTLS 后端框架 - API 绑定层
 *
 * 实现策略：
 * - 动态加载 MbedTLS 库（三个库：mbedcrypto, mbedx509, mbedtls）
 * - 仅绑定 TLS 主链路所需的最小 API 子集
 * - 其他功能通过能力矩阵标记为不支持
 *
 * MbedTLS 特殊考虑：
 * - 需要显式初始化熵源和随机数生成器
 * - 使用回调函数而非 fd 进行 I/O
 * - 配置和上下文分离（ssl_config 可共享）
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-01-09
 *}

unit nextpas.core.tls.mbedtls.api;

{$mode objfpc}{$H+}

interface

uses nextpas.core.platform.dl, nextpas.core.tls.mbedtls.base;

type
  { BIO 回调类型 - MbedTLS 特有 }
  Tmbedtls_ssl_send = function(ctx: Pointer; const buf: PByte;
    len: NativeUInt): Integer; cdecl;
  Tmbedtls_ssl_recv = function(ctx: Pointer; buf: PByte;
    len: NativeUInt): Integer; cdecl;
  Tmbedtls_ssl_recv_timeout = function(ctx: Pointer; buf: PByte;
    len: NativeUInt; timeout: Cardinal): Integer; cdecl;

  { 熵源回调 }
  Tmbedtls_entropy_f_source_ptr = function(data: Pointer; output: PByte;
    len: NativeUInt; olen: PNativeUInt): Integer; cdecl;

  { 随机数生成器回调 }
  Tmbedtls_f_rng = function(p_rng: Pointer; output: PByte;
    output_len: NativeUInt): Integer; cdecl;

  { API 函数类型定义 }

  // 版本信息
  Tmbedtls_version_get_string = procedure(string_buf: PAnsiChar); cdecl;
  Tmbedtls_version_get_number = function: Cardinal; cdecl;

  // 熵源
  Tmbedtls_entropy_init = procedure(ctx: Pmbedtls_entropy_context); cdecl;
  Tmbedtls_entropy_free = procedure(ctx: Pmbedtls_entropy_context); cdecl;
  Tmbedtls_entropy_func = function(data: Pointer; output: PByte;
    len: NativeUInt): Integer; cdecl;

  // 随机数生成器 (CTR_DRBG)
  Tmbedtls_ctr_drbg_init = procedure(ctx: Pmbedtls_ctr_drbg_context); cdecl;
  Tmbedtls_ctr_drbg_seed = function(ctx: Pmbedtls_ctr_drbg_context;
    f_entropy: Pointer; p_entropy: Pointer;
    custom: PByte; len: NativeUInt): Integer; cdecl;
  Tmbedtls_ctr_drbg_free = procedure(ctx: Pmbedtls_ctr_drbg_context); cdecl;
  Tmbedtls_ctr_drbg_random = function(p_rng: Pointer; output: PByte;
    output_len: NativeUInt): Integer; cdecl;

  // SSL 配置
  Tmbedtls_ssl_config_init = procedure(conf: Pmbedtls_ssl_config); cdecl;
  Tmbedtls_ssl_config_defaults = function(conf: Pmbedtls_ssl_config;
    endpoint: Integer; transport: Integer; preset: Integer): Integer; cdecl;
  Tmbedtls_ssl_config_free = procedure(conf: Pmbedtls_ssl_config); cdecl;
  Tmbedtls_ssl_conf_rng = procedure(conf: Pmbedtls_ssl_config;
    f_rng: Tmbedtls_f_rng; p_rng: Pointer); cdecl;
  Tmbedtls_ssl_conf_authmode = procedure(conf: Pmbedtls_ssl_config;
    authmode: Integer); cdecl;
  Tmbedtls_ssl_conf_ca_chain = procedure(conf: Pmbedtls_ssl_config;
    ca_chain: Pmbedtls_x509_crt; ca_crl: Pmbedtls_x509_crl); cdecl;
  Tmbedtls_ssl_conf_own_cert = function(conf: Pmbedtls_ssl_config;
    own_cert: Pmbedtls_x509_crt; pk_key: Pmbedtls_pk_context): Integer; cdecl;

  // SSL 上下文
  Tmbedtls_ssl_init = procedure(ssl: Pmbedtls_ssl_context); cdecl;
  Tmbedtls_ssl_setup = function(ssl: Pmbedtls_ssl_context;
    conf: Pmbedtls_ssl_config): Integer; cdecl;
  Tmbedtls_ssl_free = procedure(ssl: Pmbedtls_ssl_context); cdecl;
  Tmbedtls_ssl_set_bio = procedure(ssl: Pmbedtls_ssl_context; p_bio: Pointer;
    f_send: Tmbedtls_ssl_send; f_recv: Tmbedtls_ssl_recv;
    f_recv_timeout: Tmbedtls_ssl_recv_timeout); cdecl;
  Tmbedtls_ssl_set_hostname = function(ssl: Pmbedtls_ssl_context;
    hostname: PAnsiChar): Integer; cdecl;

  // SSL 操作
  Tmbedtls_ssl_handshake = function(ssl: Pmbedtls_ssl_context): Integer; cdecl;
  Tmbedtls_ssl_read = function(ssl: Pmbedtls_ssl_context; buf: Pointer;
    len: NativeUInt): Integer; cdecl;
  Tmbedtls_ssl_write = function(ssl: Pmbedtls_ssl_context; const buf: Pointer;
    len: NativeUInt): Integer; cdecl;
  Tmbedtls_ssl_close_notify = function(ssl: Pmbedtls_ssl_context): Integer; cdecl;
  Tmbedtls_ssl_get_verify_result = function(ssl: Pmbedtls_ssl_context): Cardinal; cdecl;
  Tmbedtls_ssl_get_ciphersuite = function(ssl: Pmbedtls_ssl_context): PAnsiChar; cdecl;
  Tmbedtls_ssl_get_ciphersuite_id = function(const ciphersuite_name: PAnsiChar): Integer; cdecl;
  Tmbedtls_ssl_get_ciphersuite_id_from_ssl = function(const ssl: Pmbedtls_ssl_context): Integer; cdecl;
  Tmbedtls_ssl_ciphersuite_from_id = function(ciphersuite_id: Integer): Pmbedtls_ssl_ciphersuite_info; cdecl;
  Tmbedtls_ssl_ciphersuite_get_cipher_key_bitlen = function(
    const info: Pmbedtls_ssl_ciphersuite_info): NativeUInt; cdecl;
  Tmbedtls_ssl_get_alpn_protocol = function(ssl: Pmbedtls_ssl_context): PAnsiChar; cdecl;
  Tmbedtls_ssl_conf_alpn_protocols = function(conf: Pmbedtls_ssl_config;
    protos: PPAnsiChar): Integer; cdecl;

  // SSL 会话
  Tmbedtls_ssl_session_init = procedure(session: Pmbedtls_ssl_session); cdecl;
  Tmbedtls_ssl_session_free = procedure(session: Pmbedtls_ssl_session); cdecl;
  Tmbedtls_ssl_get_session = function(ssl: Pmbedtls_ssl_context;
    session: Pmbedtls_ssl_session): Integer; cdecl;
  Tmbedtls_ssl_set_session = function(ssl: Pmbedtls_ssl_context;
    session: Pmbedtls_ssl_session): Integer; cdecl;
  Tmbedtls_ssl_session_load = function(session: Pmbedtls_ssl_session;
    const buf: PByte; len: NativeUInt): Integer; cdecl;
  Tmbedtls_ssl_session_save = function(const session: Pmbedtls_ssl_session;
    buf: PByte; buf_len: NativeUInt; olen: PNativeUInt): Integer; cdecl;

  // 证书
  Tmbedtls_x509_crt_init = procedure(crt: Pmbedtls_x509_crt); cdecl;
  Tmbedtls_x509_crt_parse = function(chain: Pmbedtls_x509_crt;
    const buf: PByte; buflen: NativeUInt): Integer; cdecl;
  Tmbedtls_x509_crt_parse_file = function(chain: Pmbedtls_x509_crt;
    const path: PAnsiChar): Integer; cdecl;
  Tmbedtls_x509_crt_parse_path = function(chain: Pmbedtls_x509_crt;
    const path: PAnsiChar): Integer; cdecl;
  Tmbedtls_x509_crt_free = procedure(crt: Pmbedtls_x509_crt); cdecl;
  Tmbedtls_x509_crt_info = function(buf: PAnsiChar; size: NativeUInt;
    const prefix: PAnsiChar; const crt: Pmbedtls_x509_crt): Integer; cdecl;
  Tmbedtls_x509_crt_verify = function(crt: Pmbedtls_x509_crt;
    trust_ca: Pmbedtls_x509_crt; ca_crl: Pmbedtls_x509_crl;
    const cn: PAnsiChar; flags: PCardinal;
    f_vrfy: Pointer; p_vrfy: Pointer): Integer; cdecl;
  Tmbedtls_x509_crt_verify_info = function(buf: PAnsiChar; size: NativeUInt;
    const prefix: PAnsiChar; flags: Cardinal): Integer; cdecl;

  // SSL 对端证书
  Tmbedtls_ssl_get_peer_cert = function(ssl: Pmbedtls_ssl_context): Pmbedtls_x509_crt; cdecl;
  Tmbedtls_ssl_get_version = function(ssl: Pmbedtls_ssl_context): PAnsiChar; cdecl;

  // 私钥
  Tmbedtls_pk_init = procedure(ctx: Pmbedtls_pk_context); cdecl;
  Tmbedtls_pk_free = procedure(ctx: Pmbedtls_pk_context); cdecl;
  Tmbedtls_pk_parse_keyfile = function(ctx: Pmbedtls_pk_context;
    const path: PAnsiChar; const password: PAnsiChar;
    f_rng: Tmbedtls_f_rng; p_rng: Pointer): Integer; cdecl;
  Tmbedtls_pk_parse_key = function(ctx: Pmbedtls_pk_context;
    const key: PByte; keylen: NativeUInt;
    const pwd: PByte; pwdlen: NativeUInt;
    f_rng: Tmbedtls_f_rng; p_rng: Pointer): Integer; cdecl;

  // 错误处理
  Tmbedtls_strerror = procedure(errnum: Integer; buffer: PAnsiChar;
    buflen: NativeUInt); cdecl;

  // 消息摘要 (MD) - 用于计算指纹
  Tmbedtls_md_info_from_type = function(md_type: Integer): Pointer; cdecl;
  Tmbedtls_md = function(md_info: Pointer; const input: PByte;
    ilen: NativeUInt; output: PByte): Integer; cdecl;
  Tmbedtls_md_get_size = function(md_info: Pointer): Byte; cdecl;

var
  { 函数指针 - 版本信息 }
  mbedtls_version_get_string: Tmbedtls_version_get_string = nil;
  mbedtls_version_get_number: Tmbedtls_version_get_number = nil;

  { 函数指针 - 熵源 }
  mbedtls_entropy_init: Tmbedtls_entropy_init = nil;
  mbedtls_entropy_free: Tmbedtls_entropy_free = nil;
  mbedtls_entropy_func: Tmbedtls_entropy_func = nil;

  { 函数指针 - 随机数生成器 }
  mbedtls_ctr_drbg_init: Tmbedtls_ctr_drbg_init = nil;
  mbedtls_ctr_drbg_seed: Tmbedtls_ctr_drbg_seed = nil;
  mbedtls_ctr_drbg_free: Tmbedtls_ctr_drbg_free = nil;
  mbedtls_ctr_drbg_random: Tmbedtls_ctr_drbg_random = nil;

  { 函数指针 - SSL 配置 }
  mbedtls_ssl_config_init: Tmbedtls_ssl_config_init = nil;
  mbedtls_ssl_config_defaults: Tmbedtls_ssl_config_defaults = nil;
  mbedtls_ssl_config_free: Tmbedtls_ssl_config_free = nil;
  mbedtls_ssl_conf_rng: Tmbedtls_ssl_conf_rng = nil;
  mbedtls_ssl_conf_authmode: Tmbedtls_ssl_conf_authmode = nil;
  mbedtls_ssl_conf_ca_chain: Tmbedtls_ssl_conf_ca_chain = nil;
  mbedtls_ssl_conf_own_cert: Tmbedtls_ssl_conf_own_cert = nil;

  { 函数指针 - SSL 上下文 }
  mbedtls_ssl_init: Tmbedtls_ssl_init = nil;
  mbedtls_ssl_setup: Tmbedtls_ssl_setup = nil;
  mbedtls_ssl_free: Tmbedtls_ssl_free = nil;
  mbedtls_ssl_set_bio: Tmbedtls_ssl_set_bio = nil;
  mbedtls_ssl_set_hostname: Tmbedtls_ssl_set_hostname = nil;

  { 函数指针 - SSL 操作 }
  mbedtls_ssl_handshake: Tmbedtls_ssl_handshake = nil;
  mbedtls_ssl_read: Tmbedtls_ssl_read = nil;
  mbedtls_ssl_write: Tmbedtls_ssl_write = nil;
  mbedtls_ssl_close_notify: Tmbedtls_ssl_close_notify = nil;
  mbedtls_ssl_get_verify_result: Tmbedtls_ssl_get_verify_result = nil;
  mbedtls_ssl_get_ciphersuite: Tmbedtls_ssl_get_ciphersuite = nil;
  mbedtls_ssl_get_ciphersuite_id: Tmbedtls_ssl_get_ciphersuite_id = nil;
  mbedtls_ssl_get_ciphersuite_id_from_ssl: Tmbedtls_ssl_get_ciphersuite_id_from_ssl = nil;
  mbedtls_ssl_ciphersuite_from_id: Tmbedtls_ssl_ciphersuite_from_id = nil;
  mbedtls_ssl_ciphersuite_get_cipher_key_bitlen: Tmbedtls_ssl_ciphersuite_get_cipher_key_bitlen = nil;
  mbedtls_ssl_get_alpn_protocol: Tmbedtls_ssl_get_alpn_protocol = nil;
  mbedtls_ssl_conf_alpn_protocols: Tmbedtls_ssl_conf_alpn_protocols = nil;

  { 函数指针 - SSL 会话 }
  mbedtls_ssl_session_init: Tmbedtls_ssl_session_init = nil;
  mbedtls_ssl_session_free: Tmbedtls_ssl_session_free = nil;
  mbedtls_ssl_get_session: Tmbedtls_ssl_get_session = nil;
  mbedtls_ssl_set_session: Tmbedtls_ssl_set_session = nil;
  mbedtls_ssl_session_load: Tmbedtls_ssl_session_load = nil;
  mbedtls_ssl_session_save: Tmbedtls_ssl_session_save = nil;

  { 函数指针 - 证书 }
  mbedtls_x509_crt_init: Tmbedtls_x509_crt_init = nil;
  mbedtls_x509_crt_parse: Tmbedtls_x509_crt_parse = nil;
  mbedtls_x509_crt_parse_file: Tmbedtls_x509_crt_parse_file = nil;
  mbedtls_x509_crt_parse_path: Tmbedtls_x509_crt_parse_path = nil;
  mbedtls_x509_crt_free: Tmbedtls_x509_crt_free = nil;
  mbedtls_x509_crt_info: Tmbedtls_x509_crt_info = nil;
  mbedtls_x509_crt_verify: Tmbedtls_x509_crt_verify = nil;
  mbedtls_x509_crt_verify_info: Tmbedtls_x509_crt_verify_info = nil;

  { 函数指针 - SSL 对端证书 }
  mbedtls_ssl_get_peer_cert: Tmbedtls_ssl_get_peer_cert = nil;
  mbedtls_ssl_get_version: Tmbedtls_ssl_get_version = nil;

  { 函数指针 - 私钥 }
  mbedtls_pk_init: Tmbedtls_pk_init = nil;
  mbedtls_pk_free: Tmbedtls_pk_free = nil;
  mbedtls_pk_parse_keyfile: Tmbedtls_pk_parse_keyfile = nil;
  mbedtls_pk_parse_key: Tmbedtls_pk_parse_key = nil;

  { 函数指针 - 错误处理 }
  mbedtls_strerror: Tmbedtls_strerror = nil;

  { 函数指针 - 消息摘要 }
  mbedtls_md_info_from_type: Tmbedtls_md_info_from_type = nil;
  mbedtls_md: Tmbedtls_md = nil;
  mbedtls_md_get_size: Tmbedtls_md_get_size = nil;

{ 库加载函数 }
function LoadMbedTLSLibrary: Boolean;
procedure UnloadMbedTLSLibrary;
function IsMbedTLSLoaded: Boolean;
function GetMbedTLSLibraryHandle: TPlatformLibrary;

implementation

var
  GMbedTLSHandle: TPlatformLibrary;
  GMbedCryptoHandle: TPlatformLibrary;
  GMbedX509Handle: TPlatformLibrary;
  GMbedTLSLoaded: Boolean = False;

function GetProcSym(const ALib: TPlatformLibrary; const AName: PAnsiChar): Pointer;
begin
  Result := nil;
  platform_dl_sym(ALib, AName, Result);
end;

procedure ClearAllPointers;
begin
  // 版本
  mbedtls_version_get_string := nil;
  mbedtls_version_get_number := nil;
  // 熵源
  mbedtls_entropy_init := nil;
  mbedtls_entropy_free := nil;
  mbedtls_entropy_func := nil;
  // 随机数
  mbedtls_ctr_drbg_init := nil;
  mbedtls_ctr_drbg_seed := nil;
  mbedtls_ctr_drbg_free := nil;
  mbedtls_ctr_drbg_random := nil;
  // SSL 配置
  mbedtls_ssl_config_init := nil;
  mbedtls_ssl_config_defaults := nil;
  mbedtls_ssl_config_free := nil;
  mbedtls_ssl_conf_rng := nil;
  mbedtls_ssl_conf_authmode := nil;
  mbedtls_ssl_conf_ca_chain := nil;
  mbedtls_ssl_conf_own_cert := nil;
  // SSL 上下文
  mbedtls_ssl_init := nil;
  mbedtls_ssl_setup := nil;
  mbedtls_ssl_free := nil;
  mbedtls_ssl_set_bio := nil;
  mbedtls_ssl_set_hostname := nil;
  // SSL 操作
  mbedtls_ssl_handshake := nil;
  mbedtls_ssl_read := nil;
  mbedtls_ssl_write := nil;
  mbedtls_ssl_close_notify := nil;
  mbedtls_ssl_get_verify_result := nil;
  mbedtls_ssl_get_ciphersuite := nil;
  mbedtls_ssl_get_ciphersuite_id := nil;
  mbedtls_ssl_get_ciphersuite_id_from_ssl := nil;
  mbedtls_ssl_ciphersuite_from_id := nil;
  mbedtls_ssl_ciphersuite_get_cipher_key_bitlen := nil;
  mbedtls_ssl_get_alpn_protocol := nil;
  mbedtls_ssl_conf_alpn_protocols := nil;
  // SSL 会话
  mbedtls_ssl_session_init := nil;
  mbedtls_ssl_session_free := nil;
  mbedtls_ssl_get_session := nil;
  mbedtls_ssl_set_session := nil;
  mbedtls_ssl_session_load := nil;
  mbedtls_ssl_session_save := nil;
  // 证书
  mbedtls_x509_crt_init := nil;
  mbedtls_x509_crt_parse := nil;
  mbedtls_x509_crt_parse_file := nil;
  mbedtls_x509_crt_parse_path := nil;
  mbedtls_x509_crt_free := nil;
  mbedtls_x509_crt_info := nil;
  mbedtls_x509_crt_verify := nil;
  mbedtls_x509_crt_verify_info := nil;
  // SSL 对端证书
  mbedtls_ssl_get_peer_cert := nil;
  mbedtls_ssl_get_version := nil;
  // 私钥
  mbedtls_pk_init := nil;
  mbedtls_pk_free := nil;
  mbedtls_pk_parse_keyfile := nil;
  mbedtls_pk_parse_key := nil;
  // 错误
  mbedtls_strerror := nil;
  // 消息摘要
  mbedtls_md_info_from_type := nil;
  mbedtls_md := nil;
  mbedtls_md_get_size := nil;
end;

function LoadMbedTLSLibrary: Boolean;
begin
  Result := False;

  if GMbedTLSLoaded then
    Exit(True);

  // MbedTLS 分为三个库，需要按依赖顺序加载
  // 1. mbedcrypto - 基础加密功能
  if platform_dl_open(PAnsiChar(AnsiString(MBEDCRYPTO_LIB_NAME)), PLATFORM_DL_NOW, GMbedCryptoHandle) <> 0 then
    Exit(False);

  // 2. mbedx509 - 证书处理（依赖 mbedcrypto）
  if platform_dl_open(PAnsiChar(AnsiString(MBEDX509_LIB_NAME)), PLATFORM_DL_NOW, GMbedX509Handle) <> 0 then
  begin
    platform_dl_close(GMbedCryptoHandle);
    Exit(False);
  end;

  // 3. mbedtls - SSL/TLS 功能（依赖 mbedx509 和 mbedcrypto）
  if platform_dl_open(PAnsiChar(AnsiString(MBEDTLS_LIB_NAME)), PLATFORM_DL_NOW, GMbedTLSHandle) <> 0 then
  begin
    platform_dl_close(GMbedX509Handle);
    platform_dl_close(GMbedCryptoHandle);
    Exit(False);
  end;

  // 加载版本函数（从 mbedcrypto）
  mbedtls_version_get_string := Tmbedtls_version_get_string(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_version_get_string'));
  mbedtls_version_get_number := Tmbedtls_version_get_number(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_version_get_number'));

  // 加载熵源函数（从 mbedcrypto）
  mbedtls_entropy_init := Tmbedtls_entropy_init(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_entropy_init'));
  mbedtls_entropy_free := Tmbedtls_entropy_free(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_entropy_free'));
  mbedtls_entropy_func := Tmbedtls_entropy_func(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_entropy_func'));

  // 加载随机数函数（从 mbedcrypto）
  mbedtls_ctr_drbg_init := Tmbedtls_ctr_drbg_init(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_ctr_drbg_init'));
  mbedtls_ctr_drbg_seed := Tmbedtls_ctr_drbg_seed(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_ctr_drbg_seed'));
  mbedtls_ctr_drbg_free := Tmbedtls_ctr_drbg_free(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_ctr_drbg_free'));
  mbedtls_ctr_drbg_random := Tmbedtls_ctr_drbg_random(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_ctr_drbg_random'));

  // 加载 SSL 配置函数（从 mbedtls）
  mbedtls_ssl_config_init := Tmbedtls_ssl_config_init(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_config_init'));
  mbedtls_ssl_config_defaults := Tmbedtls_ssl_config_defaults(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_config_defaults'));
  mbedtls_ssl_config_free := Tmbedtls_ssl_config_free(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_config_free'));
  mbedtls_ssl_conf_rng := Tmbedtls_ssl_conf_rng(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_conf_rng'));
  mbedtls_ssl_conf_authmode := Tmbedtls_ssl_conf_authmode(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_conf_authmode'));
  mbedtls_ssl_conf_ca_chain := Tmbedtls_ssl_conf_ca_chain(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_conf_ca_chain'));
  mbedtls_ssl_conf_own_cert := Tmbedtls_ssl_conf_own_cert(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_conf_own_cert'));

  // 加载 SSL 上下文函数（从 mbedtls）
  mbedtls_ssl_init := Tmbedtls_ssl_init(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_init'));
  mbedtls_ssl_setup := Tmbedtls_ssl_setup(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_setup'));
  mbedtls_ssl_free := Tmbedtls_ssl_free(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_free'));
  mbedtls_ssl_set_bio := Tmbedtls_ssl_set_bio(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_set_bio'));
  mbedtls_ssl_set_hostname := Tmbedtls_ssl_set_hostname(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_set_hostname'));

  // 加载 SSL 操作函数（从 mbedtls）
  mbedtls_ssl_handshake := Tmbedtls_ssl_handshake(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_handshake'));
  mbedtls_ssl_read := Tmbedtls_ssl_read(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_read'));
  mbedtls_ssl_write := Tmbedtls_ssl_write(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_write'));
  mbedtls_ssl_close_notify := Tmbedtls_ssl_close_notify(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_close_notify'));
  mbedtls_ssl_get_verify_result := Tmbedtls_ssl_get_verify_result(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_get_verify_result'));
  mbedtls_ssl_get_ciphersuite := Tmbedtls_ssl_get_ciphersuite(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_get_ciphersuite'));
  mbedtls_ssl_get_ciphersuite_id := Tmbedtls_ssl_get_ciphersuite_id(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_get_ciphersuite_id'));
  mbedtls_ssl_get_ciphersuite_id_from_ssl := Tmbedtls_ssl_get_ciphersuite_id_from_ssl(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_get_ciphersuite_id_from_ssl'));
  mbedtls_ssl_ciphersuite_from_id := Tmbedtls_ssl_ciphersuite_from_id(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_ciphersuite_from_id'));
  mbedtls_ssl_ciphersuite_get_cipher_key_bitlen := Tmbedtls_ssl_ciphersuite_get_cipher_key_bitlen(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_ciphersuite_get_cipher_key_bitlen'));
  mbedtls_ssl_get_alpn_protocol := Tmbedtls_ssl_get_alpn_protocol(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_get_alpn_protocol'));
  mbedtls_ssl_conf_alpn_protocols := Tmbedtls_ssl_conf_alpn_protocols(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_conf_alpn_protocols'));

  // 加载 SSL 会话函数（从 mbedtls）
  mbedtls_ssl_session_init := Tmbedtls_ssl_session_init(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_session_init'));
  mbedtls_ssl_session_free := Tmbedtls_ssl_session_free(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_session_free'));
  mbedtls_ssl_get_session := Tmbedtls_ssl_get_session(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_get_session'));
  mbedtls_ssl_set_session := Tmbedtls_ssl_set_session(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_set_session'));
  mbedtls_ssl_session_load := Tmbedtls_ssl_session_load(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_session_load'));
  mbedtls_ssl_session_save := Tmbedtls_ssl_session_save(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_session_save'));

  // 加载证书函数（从 mbedx509）
  mbedtls_x509_crt_init := Tmbedtls_x509_crt_init(
    GetProcSym(GMbedX509Handle, 'mbedtls_x509_crt_init'));
  mbedtls_x509_crt_parse := Tmbedtls_x509_crt_parse(
    GetProcSym(GMbedX509Handle, 'mbedtls_x509_crt_parse'));
  mbedtls_x509_crt_parse_file := Tmbedtls_x509_crt_parse_file(
    GetProcSym(GMbedX509Handle, 'mbedtls_x509_crt_parse_file'));
  mbedtls_x509_crt_parse_path := Tmbedtls_x509_crt_parse_path(
    GetProcSym(GMbedX509Handle, 'mbedtls_x509_crt_parse_path'));
  mbedtls_x509_crt_free := Tmbedtls_x509_crt_free(
    GetProcSym(GMbedX509Handle, 'mbedtls_x509_crt_free'));
  mbedtls_x509_crt_info := Tmbedtls_x509_crt_info(
    GetProcSym(GMbedX509Handle, 'mbedtls_x509_crt_info'));
  mbedtls_x509_crt_verify := Tmbedtls_x509_crt_verify(
    GetProcSym(GMbedX509Handle, 'mbedtls_x509_crt_verify'));
  mbedtls_x509_crt_verify_info := Tmbedtls_x509_crt_verify_info(
    GetProcSym(GMbedX509Handle, 'mbedtls_x509_crt_verify_info'));

  // 加载 SSL 对端证书函数（从 mbedtls）
  mbedtls_ssl_get_peer_cert := Tmbedtls_ssl_get_peer_cert(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_get_peer_cert'));
  mbedtls_ssl_get_version := Tmbedtls_ssl_get_version(
    GetProcSym(GMbedTLSHandle, 'mbedtls_ssl_get_version'));

  // 加载私钥函数（从 mbedcrypto）
  mbedtls_pk_init := Tmbedtls_pk_init(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_pk_init'));
  mbedtls_pk_free := Tmbedtls_pk_free(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_pk_free'));
  mbedtls_pk_parse_keyfile := Tmbedtls_pk_parse_keyfile(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_pk_parse_keyfile'));
  mbedtls_pk_parse_key := Tmbedtls_pk_parse_key(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_pk_parse_key'));

  // 加载错误函数（从 mbedcrypto）
  mbedtls_strerror := Tmbedtls_strerror(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_strerror'));

  // 加载消息摘要函数（从 mbedcrypto）
  mbedtls_md_info_from_type := Tmbedtls_md_info_from_type(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_md_info_from_type'));
  mbedtls_md := Tmbedtls_md(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_md'));
  mbedtls_md_get_size := Tmbedtls_md_get_size(
    GetProcSym(GMbedCryptoHandle, 'mbedtls_md_get_size'));

  // 验证必需函数
  if not Assigned(mbedtls_entropy_init) or
    not Assigned(mbedtls_ctr_drbg_init) or
    not Assigned(mbedtls_ssl_config_init) or
    not Assigned(mbedtls_ssl_init) then
  begin
    UnloadMbedTLSLibrary;
    Exit(False);
  end;

  GMbedTLSLoaded := True;
  Result := True;
end;

procedure UnloadMbedTLSLibrary;
begin
  // 按相反顺序卸载
  platform_dl_close(GMbedTLSHandle);
  platform_dl_close(GMbedX509Handle);
  platform_dl_close(GMbedCryptoHandle);

  ClearAllPointers;
  GMbedTLSLoaded := False;
end;

function IsMbedTLSLoaded: Boolean;
begin
  Result := GMbedTLSLoaded;
end;

function GetMbedTLSLibraryHandle: TPlatformLibrary;
begin
  Result := GMbedTLSHandle;
end;

end.
