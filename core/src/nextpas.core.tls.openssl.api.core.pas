unit nextpas.core.tls.openssl.api.core;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.tls.exceptions,
  SysUtils, DynLibs, ctypes,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.loader;  // P0-1.1: 使用统一的加载器

type
  { SSL Library Management }
  TOPENSSL_init_ssl = function(opts: UInt64; const settings: Pointer): Integer; cdecl;
  TOPENSSL_cleanup = procedure; cdecl;
  TOpenSSL_version_num = function: LongWord; cdecl;
  TOpenSSL_version = function(&type: Integer): PAnsiChar; cdecl;
  
  { SSL Method Functions }
  TTLS_method = function: PSSL_METHOD; cdecl;
  TTLS_server_method = function: PSSL_METHOD; cdecl;
  TTLS_client_method = function: PSSL_METHOD; cdecl;
  TSSLv23_method = function: PSSL_METHOD; cdecl;
  TSSLv23_server_method = function: PSSL_METHOD; cdecl;
  TSSLv23_client_method = function: PSSL_METHOD; cdecl;
  TDTLS_method = function: PSSL_METHOD; cdecl;
  TDTLS_server_method = function: PSSL_METHOD; cdecl;
  TDTLS_client_method = function: PSSL_METHOD; cdecl;
  
  { SSL Context Functions }
  TSSL_CTX_new = function(const meth: PSSL_METHOD): PSSL_CTX; cdecl;
  TSSL_CTX_new_ex = function(libctx: Pointer; const propq: PAnsiChar; const meth: PSSL_METHOD): PSSL_CTX; cdecl;
  TSSL_CTX_free = procedure(ctx: PSSL_CTX); cdecl;
  TSSL_CTX_up_ref = function(ctx: PSSL_CTX): Integer; cdecl;
  TSSL_CTX_set_timeout = function(ctx: PSSL_CTX; t: clong): clong; cdecl;
  TSSL_CTX_get_timeout = function(const ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_get_cert_store = function(const ctx: PSSL_CTX): PX509_STORE; cdecl;
  TSSL_CTX_set_cert_store = procedure(ctx: PSSL_CTX; store: PX509_STORE); cdecl;
  TSSL_CTX_set1_cert_store = procedure(ctx: PSSL_CTX; store: PX509_STORE); cdecl;
  TSSL_CTX_get0_certificate = function(const ctx: PSSL_CTX): PX509; cdecl;
  TSSL_CTX_get0_privatekey = function(const ctx: PSSL_CTX): PEVP_PKEY; cdecl;
  
  { SSL Connection Functions }
  TSSL_new = function(ctx: PSSL_CTX): PSSL; cdecl;
  TSSL_free = procedure(ssl: PSSL); cdecl;
  TSSL_up_ref = function(ssl: PSSL): Integer; cdecl;
  TSSL_dup = function(ssl: PSSL): PSSL; cdecl;
  TSSL_get_SSL_CTX = function(const ssl: PSSL): PSSL_CTX; cdecl;
  TSSL_set_SSL_CTX = function(ssl: PSSL; ctx: PSSL_CTX): PSSL_CTX; cdecl;
  
  { SSL Connection Setup }
  TSSL_set_fd = function(ssl: PSSL; fd: Integer): Integer; cdecl;
  TSSL_set_rfd = function(ssl: PSSL; fd: Integer): Integer; cdecl;
  TSSL_set_wfd = function(ssl: PSSL; fd: Integer): Integer; cdecl;
  TSSL_get_fd = function(const ssl: PSSL): Integer; cdecl;
  TSSL_get_rfd = function(const ssl: PSSL): Integer; cdecl;
  TSSL_get_wfd = function(const ssl: PSSL): Integer; cdecl;
  TSSL_set_bio = procedure(ssl: PSSL; rbio: PBIO; wbio: PBIO); cdecl;
  TSSL_set0_rbio = procedure(ssl: PSSL; rbio: PBIO); cdecl;
  TSSL_set0_wbio = procedure(ssl: PSSL; wbio: PBIO); cdecl;
  TSSL_get_rbio = function(const ssl: PSSL): PBIO; cdecl;
  TSSL_get_wbio = function(const ssl: PSSL): PBIO; cdecl;
  
  { SSL Handshake Functions }
  TSSL_connect = function(ssl: PSSL): Integer; cdecl;
  TSSL_accept = function(ssl: PSSL): Integer; cdecl;
  TSSL_do_handshake = function(ssl: PSSL): Integer; cdecl;
  TSSL_connect_ex = function(ssl: PSSL; timeout: UInt64): Integer; cdecl;
  TSSL_accept_ex = function(ssl: PSSL; timeout: UInt64): Integer; cdecl;
  TSSL_do_handshake_ex = function(ssl: PSSL; timeout: UInt64): Integer; cdecl;
  TSSL_renegotiate = function(ssl: PSSL): Integer; cdecl;
  TSSL_renegotiate_abbreviated = function(ssl: PSSL): Integer; cdecl;
  TSSL_renegotiate_pending = function(const ssl: PSSL): Integer; cdecl;
  TSSL_key_update = function(ssl: PSSL; updatetype: Integer): Integer; cdecl;
  TSSL_get_key_update_type = function(const ssl: PSSL): Integer; cdecl;
  
  { SSL Data Transfer Functions }
  TSSL_read = function(ssl: PSSL; buf: Pointer; num: Integer): Integer; cdecl;
  TSSL_read_ex = function(ssl: PSSL; buf: Pointer; num: size_t; readbytes: Psize_t): Integer; cdecl;
  TSSL_read_early_data = function(ssl: PSSL; buf: Pointer; num: size_t; readbytes: Psize_t): Integer; cdecl;
  TSSL_peek = function(ssl: PSSL; buf: Pointer; num: Integer): Integer; cdecl;
  TSSL_peek_ex = function(ssl: PSSL; buf: Pointer; num: size_t; readbytes: Psize_t): Integer; cdecl;
  TSSL_write = function(ssl: PSSL; const buf: Pointer; num: Integer): Integer; cdecl;
  TSSL_write_ex = function(ssl: PSSL; const buf: Pointer; num: size_t; written: Psize_t): Integer; cdecl;
  TSSL_write_early_data = function(ssl: PSSL; const buf: Pointer; num: size_t; written: Psize_t): Integer; cdecl;
  TSSL_sendfile = function(ssl: PSSL; fd: Integer; offset: off_t; size: size_t; flags: Integer): LongInt; cdecl;
  
  { SSL Shutdown Functions }
  TSSL_shutdown = function(ssl: PSSL): Integer; cdecl;
  TSSL_shutdown_ex = function(ssl: PSSL; flags: UInt64; timeout: UInt64): Integer; cdecl;
  TSSL_CTX_set_quiet_shutdown = procedure(ctx: PSSL_CTX; mode: Integer); cdecl;
  TSSL_CTX_get_quiet_shutdown = function(const ctx: PSSL_CTX): Integer; cdecl;
  TSSL_set_quiet_shutdown = procedure(ssl: PSSL; mode: Integer); cdecl;
  TSSL_get_quiet_shutdown = function(const ssl: PSSL): Integer; cdecl;
  TSSL_set_shutdown = procedure(ssl: PSSL; mode: Integer); cdecl;
  TSSL_get_shutdown = function(const ssl: PSSL): Integer; cdecl;
  
  { SSL Error Handling }
  TSSL_get_error = function(const ssl: PSSL; ret: Integer): Integer; cdecl;
  TSSL_get_error_line = function(const ssl: PSSL; ret: Integer; const &file: PPAnsiChar; line: PInteger): Integer; cdecl;
  TSSL_want = function(const ssl: PSSL): Integer; cdecl;
  TSSL_want_nothing = function(const ssl: PSSL): Integer; cdecl;
  TSSL_want_read = function(const ssl: PSSL): Integer; cdecl;
  TSSL_want_write = function(const ssl: PSSL): Integer; cdecl;
  TSSL_want_x509_lookup = function(const ssl: PSSL): Integer; cdecl;
  TSSL_want_async = function(const ssl: PSSL): Integer; cdecl;
  TSSL_want_async_job = function(const ssl: PSSL): Integer; cdecl;
  TSSL_want_client_hello_cb = function(const ssl: PSSL): Integer; cdecl;
  
  { SSL Certificate Functions }
  TSSL_use_certificate = function(ssl: PSSL; x: PX509): Integer; cdecl;
  TSSL_use_certificate_ASN1 = function(ssl: PSSL; const d: PByte; len: Integer): Integer; cdecl;
  TSSL_use_certificate_file = function(ssl: PSSL; const &file: PAnsiChar; &type: Integer): Integer; cdecl;
  TSSL_use_certificate_chain_file = function(ssl: PSSL; const &file: PAnsiChar): Integer; cdecl;
  TSSL_use_PrivateKey = function(ssl: PSSL; pkey: PEVP_PKEY): Integer; cdecl;
  TSSL_use_PrivateKey_ASN1 = function(pk: Integer; ssl: PSSL; const d: PByte; len: clong): Integer; cdecl;
  TSSL_use_PrivateKey_file = function(ssl: PSSL; const &file: PAnsiChar; &type: Integer): Integer; cdecl;
  TSSL_use_RSAPrivateKey = function(ssl: PSSL; rsa: PRSA): Integer; cdecl;
  TSSL_use_RSAPrivateKey_ASN1 = function(ssl: PSSL; const d: PByte; len: clong): Integer; cdecl;
  TSSL_use_RSAPrivateKey_file = function(ssl: PSSL; const &file: PAnsiChar; &type: Integer): Integer; cdecl;
  TSSL_check_private_key = function(const ssl: PSSL): Integer; cdecl;
  TSSL_get_certificate = function(const ssl: PSSL): PX509; cdecl;
  TSSL_get_privatekey = function(const ssl: PSSL): PEVP_PKEY; cdecl;
  
  { SSL Context Certificate Functions }
  TSSL_CTX_use_certificate = function(ctx: PSSL_CTX; x: PX509): Integer; cdecl;
  TSSL_CTX_use_certificate_ASN1 = function(ctx: PSSL_CTX; len: Integer; const d: PByte): Integer; cdecl;
  TSSL_CTX_use_certificate_file = function(ctx: PSSL_CTX; const &file: PAnsiChar; &type: Integer): Integer; cdecl;
  TSSL_CTX_use_certificate_chain_file = function(ctx: PSSL_CTX; const &file: PAnsiChar): Integer; cdecl;
  TSSL_CTX_use_PrivateKey = function(ctx: PSSL_CTX; pkey: PEVP_PKEY): Integer; cdecl;
  TSSL_CTX_use_PrivateKey_ASN1 = function(pk: Integer; ctx: PSSL_CTX; const d: PByte; len: clong): Integer; cdecl;
  TSSL_CTX_use_PrivateKey_file = function(ctx: PSSL_CTX; const &file: PAnsiChar; &type: Integer): Integer; cdecl;
  TSSL_CTX_use_RSAPrivateKey = function(ctx: PSSL_CTX; rsa: PRSA): Integer; cdecl;
  TSSL_CTX_use_RSAPrivateKey_ASN1 = function(ctx: PSSL_CTX; const d: PByte; len: clong): Integer; cdecl;
  TSSL_CTX_use_RSAPrivateKey_file = function(ctx: PSSL_CTX; const &file: PAnsiChar; &type: Integer): Integer; cdecl;
  TSSL_CTX_check_private_key = function(const ctx: PSSL_CTX): Integer; cdecl;
  TSSL_CTX_set_default_passwd_cb = procedure(ctx: PSSL_CTX; cb: Tpem_password_cb); cdecl;
  TSSL_CTX_set_default_passwd_cb_userdata = procedure(ctx: PSSL_CTX; u: Pointer); cdecl;
  TSSL_CTX_get_default_passwd_cb = function(ctx: PSSL_CTX): Tpem_password_cb; cdecl;
  TSSL_CTX_get_default_passwd_cb_userdata = function(ctx: PSSL_CTX): Pointer; cdecl;
  TSSL_set_default_passwd_cb = procedure(ssl: PSSL; cb: Tpem_password_cb); cdecl;
  TSSL_set_default_passwd_cb_userdata = procedure(ssl: PSSL; u: Pointer); cdecl;
  TSSL_get_default_passwd_cb = function(ssl: PSSL): Tpem_password_cb; cdecl;
  TSSL_get_default_passwd_cb_userdata = function(ssl: PSSL): Pointer; cdecl;
  
  { SSL Peer Certificate Functions }
  TSSL_get_peer_certificate = function(const ssl: PSSL): PX509; cdecl;
  TSSL_get_peer_cert_chain = function(const ssl: PSSL): PSTACK_OF_X509; cdecl;
  TSSL_get0_peer_certificate = function(const ssl: PSSL): PX509; cdecl;
  TSSL_get1_peer_certificate = function(const ssl: PSSL): PX509; cdecl;
  TSSL_get0_verified_chain = function(const ssl: PSSL): PSTACK_OF_X509; cdecl;
  TSSL_get_peer_signature_type_nid = function(const ssl: PSSL; pnid: PInteger): Integer; cdecl;
  TSSL_get_signature_type_nid = function(const ssl: PSSL; pnid: PInteger): Integer; cdecl;
  
  { SSL Verification Functions }
  TSSL_get_verify_mode = function(const ssl: PSSL): Integer; cdecl;
  TSSL_get_verify_depth = function(const ssl: PSSL): Integer; cdecl;
  TSSL_get_verify_callback = function(const ssl: PSSL): TSSL_verify_cb; cdecl;
  TSSL_set_verify = procedure(ssl: PSSL; mode: Integer; callback: TSSL_verify_cb); cdecl;
  TSSL_set_verify_depth = procedure(ssl: PSSL; depth: Integer); cdecl;
  TSSL_set_read_ahead = procedure(ssl: PSSL; yes: Integer); cdecl;
  TSSL_get_read_ahead = function(const ssl: PSSL): Integer; cdecl;
  TSSL_pending = function(const ssl: PSSL): Integer; cdecl;
  TSSL_has_pending = function(const ssl: PSSL): Integer; cdecl;
  TSSL_get_verify_result = function(const ssl: PSSL): clong; cdecl;
  TSSL_set_verify_result = procedure(ssl: PSSL; v: clong); cdecl;
  TSSL_get_client_CA_list = function(const ssl: PSSL): PSTACK_OF_X509_NAME; cdecl;
  TSSL_CTX_get_verify_mode = function(const ctx: PSSL_CTX): Integer; cdecl;
  TSSL_CTX_get_verify_depth = function(const ctx: PSSL_CTX): Integer; cdecl;
  TSSL_CTX_get_verify_callback = function(const ctx: PSSL_CTX): TSSL_verify_cb; cdecl;
  TSSL_CTX_set_verify = procedure(ctx: PSSL_CTX; mode: Integer; callback: TSSL_verify_cb); cdecl;
  TSSL_CTX_set_verify_depth = procedure(ctx: PSSL_CTX; depth: Integer); cdecl;
  TSSL_CTX_set_cert_verify_callback = procedure(ctx: PSSL_CTX; cb: TX509_STORE_CTX_verify_cb; arg: Pointer); cdecl;
  TSSL_CTX_set_cert_cb = procedure(ctx: PSSL_CTX; cb: TClient_cert_cb; arg: Pointer); cdecl;
  TSSL_CTX_set_read_ahead = procedure(ctx: PSSL_CTX; yes: Integer); cdecl;
  TSSL_CTX_get_read_ahead = function(const ctx: PSSL_CTX): Integer; cdecl;
  TSSL_CTX_load_verify_locations = function(ctx: PSSL_CTX; const CAfile: PAnsiChar; const CApath: PAnsiChar): Integer; cdecl;
  TSSL_CTX_set_default_verify_paths = function(ctx: PSSL_CTX): Integer; cdecl;
  TSSL_CTX_get_client_CA_list = function(const ctx: PSSL_CTX): PSTACK_OF_X509_NAME; cdecl;
  TSSL_CTX_set_client_CA_list = procedure(ctx: PSSL_CTX; name_list: PSTACK_OF_X509_NAME); cdecl;
  TSSL_set_client_CA_list = procedure(ssl: PSSL; name_list: PSTACK_OF_X509_NAME); cdecl;
  TSSL_set0_CA_list = procedure(ssl: PSSL; name_list: PSTACK_OF_X509_NAME); cdecl;
  TSSL_CTX_set0_CA_list = procedure(ctx: PSSL_CTX; name_list: PSTACK_OF_X509_NAME); cdecl;
  TSSL_get0_CA_list = function(const ssl: PSSL): PSTACK_OF_X509_NAME; cdecl;
  TSSL_CTX_get0_CA_list = function(const ctx: PSSL_CTX): PSTACK_OF_X509_NAME; cdecl;
  TSSL_add_client_CA = function(ssl: PSSL; x: PX509): Integer; cdecl;
  TSSL_CTX_add_client_CA = function(ctx: PSSL_CTX; x: PX509): Integer; cdecl;
  TSSL_set_connect_state = procedure(ssl: PSSL); cdecl;
  TSSL_set_accept_state = procedure(ssl: PSSL); cdecl;
  
  { SSL Session Functions }
  TSSL_get_session = function(const ssl: PSSL): PSSL_SESSION; cdecl;
  TSSL_get1_session = function(ssl: PSSL): PSSL_SESSION; cdecl;
  TSSL_get0_session = function(const ssl: PSSL): PSSL_SESSION; cdecl;
  TSSL_set_session = function(ssl: PSSL; session: PSSL_SESSION): Integer; cdecl;
  TSSL_CTX_add_session = function(ctx: PSSL_CTX; c: PSSL_SESSION): Integer; cdecl;
  TSSL_CTX_remove_session = function(ctx: PSSL_CTX; c: PSSL_SESSION): Integer; cdecl;
  TSSL_CTX_set_generate_session_id = function(ctx: PSSL_CTX; cb: Pointer): Integer; cdecl;
  TSSL_set_generate_session_id = function(ssl: PSSL; cb: Pointer): Integer; cdecl;
  TSSL_has_matching_session_id = function(const ssl: PSSL; const id: PByte; id_len: Cardinal): Integer; cdecl;
  TSSL_SESSION_new = function: PSSL_SESSION; cdecl;
  TSSL_SESSION_free = procedure(sess: PSSL_SESSION); cdecl;
  TSSL_session_reused = function(const ssl: PSSL): Integer; cdecl;
  TSSL_SESSION_up_ref = function(sess: PSSL_SESSION): Integer; cdecl;
  TSSL_SESSION_get_id = function(const s: PSSL_SESSION; len: PCardinal): PByte; cdecl;
  TSSL_SESSION_get0_id_context = function(const s: PSSL_SESSION; len: PCardinal): PByte; cdecl;
  TSSL_SESSION_get_compress_id = function(const s: PSSL_SESSION): Cardinal; cdecl;
  TSSL_SESSION_print = function(bio: PBIO; const sess: PSSL_SESSION): Integer; cdecl;
  TSSL_SESSION_print_keylog = function(bp: PBIO; const x: PSSL_SESSION): Integer; cdecl;
  TSSL_SESSION_get0_peer = function(s: PSSL_SESSION): PX509; cdecl;
  TSSL_SESSION_set1_id_context = function(s: PSSL_SESSION; const sid_ctx: PByte; sid_ctx_len: Cardinal): Integer; cdecl;
  TSSL_SESSION_set1_id = function(s: PSSL_SESSION; const sid: PByte; sid_len: Cardinal): Integer; cdecl;
  TSSL_SESSION_is_resumable = function(const s: PSSL_SESSION): Integer; cdecl;
  TSSL_SESSION_get_time = function(const s: PSSL_SESSION): clong; cdecl;
  TSSL_SESSION_set_time = function(s: PSSL_SESSION; t: clong): clong; cdecl;
  TSSL_SESSION_get_timeout = function(const s: PSSL_SESSION): clong; cdecl;
  TSSL_SESSION_set_timeout = function(s: PSSL_SESSION; t: clong): clong; cdecl;
  TSSL_SESSION_get_protocol_version = function(const s: PSSL_SESSION): Integer; cdecl;
  TSSL_SESSION_set_protocol_version = function(s: PSSL_SESSION; version: Integer): Integer; cdecl;
  TSSL_SESSION_get0_cipher = function(const s: PSSL_SESSION): PSSL_CIPHER; cdecl;
  TSSL_SESSION_set_cipher = function(s: PSSL_SESSION; cipher: PSSL_CIPHER): Integer; cdecl;
  TSSL_SESSION_has_ticket = function(const s: PSSL_SESSION): Integer; cdecl;
  TSSL_SESSION_get_ticket_lifetime_hint = function(const s: PSSL_SESSION): LongWord; cdecl;
  TSSL_SESSION_get0_ticket = procedure(const s: PSSL_SESSION; const tick: PPByte; len: Psize_t); cdecl;
  TSSL_SESSION_set1_ticket = function(s: PSSL_SESSION; const ext: PByte; ext_len: size_t): Integer; cdecl;
  TSSL_SESSION_get_max_early_data = function(const s: PSSL_SESSION): UInt32; cdecl;
  TSSL_SESSION_set_max_early_data = function(s: PSSL_SESSION; max_early_data: UInt32): Integer; cdecl;
  TSSL_copy_session_id = function(&to: PSSL; const from: PSSL): Integer; cdecl;
  
  { SSL Cipher Functions }
  TSSL_get_current_cipher = function(const ssl: PSSL): PSSL_CIPHER; cdecl;
  TSSL_get_pending_cipher = function(const ssl: PSSL): PSSL_CIPHER; cdecl;
  TSSL_get_cipher_list = function(const ssl: PSSL; n: Integer): PAnsiChar; cdecl;
  TSSL_get_shared_ciphers = function(const ssl: PSSL; buf: PAnsiChar; size: Integer): PAnsiChar; cdecl;
  TSSL_get_ciphers = function(const ssl: PSSL): PSTACK_OF_SSL_CIPHER; cdecl;
  TSSL_get_client_ciphers = function(const ssl: PSSL): PSTACK_OF_SSL_CIPHER; cdecl;
  TSSL_get1_supported_ciphers = function(ssl: PSSL): PSTACK_OF_SSL_CIPHER; cdecl;
  TSSL_CTX_get_ciphers = function(const ctx: PSSL_CTX): PSTACK_OF_SSL_CIPHER; cdecl;
  TSSL_bytes_to_cipher_list = function(ssl: PSSL; const bytes: PByte; len: size_t; isv2format: Integer; sk: PPSTACK_OF_SSL_CIPHER; scsvs: PPSTACK_OF_SSL_CIPHER): Integer; cdecl;
  TSSL_set_cipher_list = function(ssl: PSSL; const str: PAnsiChar): Integer; cdecl;
  TSSL_CTX_set_cipher_list = function(ctx: PSSL_CTX; const str: PAnsiChar): Integer; cdecl;
  TSSL_set_ciphersuites = function(ssl: PSSL; const str: PAnsiChar): Integer; cdecl;
  TSSL_CTX_set_ciphersuites = function(ctx: PSSL_CTX; const str: PAnsiChar): Integer; cdecl;
  TSSL_get_cipher = function(const ssl: PSSL): PAnsiChar; cdecl;
  TSSL_get_cipher_bits = function(const ssl: PSSL; np: PInteger): Integer; cdecl;
  TSSL_get_cipher_version = function(const ssl: PSSL): PAnsiChar; cdecl;
  TSSL_get_cipher_name = function(const ssl: PSSL): PAnsiChar; cdecl;
  TSSL_get_shared_curve = function(ssl: PSSL; n: Integer): Integer; cdecl;
  TSSL_get_shared_group = function(ssl: PSSL; n: Integer): Integer; cdecl;
  TSSL_get_negotiated_group = function(ssl: PSSL): Integer; cdecl;
  
  { SSL Cipher Suite Functions }
  TSSL_CIPHER_get_name = function(const c: PSSL_CIPHER): PAnsiChar; cdecl;
  TSSL_CIPHER_standard_name = function(const c: PSSL_CIPHER): PAnsiChar; cdecl;
  TSSL_CIPHER_get_bits = function(const c: PSSL_CIPHER; alg_bits: PInteger): Integer; cdecl;
  TSSL_CIPHER_get_version = function(const c: PSSL_CIPHER): PAnsiChar; cdecl;
  TSSL_CIPHER_get_auth_nid = function(const c: PSSL_CIPHER): Integer; cdecl;
  TSSL_CIPHER_get_cipher_nid = function(const c: PSSL_CIPHER): Integer; cdecl;
  TSSL_CIPHER_get_digest_nid = function(const c: PSSL_CIPHER): Integer; cdecl;
  TSSL_CIPHER_get_kx_nid = function(const c: PSSL_CIPHER): Integer; cdecl;
  TSSL_CIPHER_is_aead = function(const c: PSSL_CIPHER): Integer; cdecl;
  TSSL_CIPHER_find = function(ssl: PSSL; const ptr: PByte): PSSL_CIPHER; cdecl;
  TSSL_CIPHER_get_id = function(const c: PSSL_CIPHER): UInt32; cdecl;
  TSSL_CIPHER_get_protocol_id = function(const c: PSSL_CIPHER): UInt16; cdecl;
  TSSL_CIPHER_description = function(const cipher: PSSL_CIPHER; buf: PAnsiChar; size: Integer): PAnsiChar; cdecl;
  
  { SSL Options and Control Functions }
  TSSL_CTX_ctrl = function(ctx: PSSL_CTX; cmd: Integer; larg: clong; parg: Pointer): clong; cdecl;
  TSSL_CTX_callback_ctrl = function(ctx: PSSL_CTX; cmd: Integer; fp: Pointer): clong; cdecl;
  TSSL_CTX_set_options = function(ctx: PSSL_CTX; op: clong): clong; cdecl;
  TSSL_CTX_clear_options = function(ctx: PSSL_CTX; op: clong): clong; cdecl;
  TSSL_CTX_get_options = function(const ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_set_mode = function(ctx: PSSL_CTX; op: clong): clong; cdecl;
  TSSL_CTX_clear_mode = function(ctx: PSSL_CTX; op: clong): clong; cdecl;
  TSSL_CTX_get_mode = function(const ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_set_max_cert_list = function(ctx: PSSL_CTX; m: clong): clong; cdecl;
  TSSL_CTX_get_max_cert_list = function(const ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_set_max_send_fragment = function(ctx: PSSL_CTX; m: clong): clong; cdecl;
  TSSL_CTX_set_split_send_fragment = function(ctx: PSSL_CTX; m: clong): clong; cdecl;
  TSSL_CTX_set_max_pipelines = function(ctx: PSSL_CTX; m: clong): clong; cdecl;
  TSSL_CTX_set_default_read_buffer_len = procedure(ctx: PSSL_CTX; len: size_t); cdecl;
  TSSL_CTX_set_session_id_context = function(ctx: PSSL_CTX; const sid_ctx: PByte; sid_ctx_len: Cardinal): Integer; cdecl;
  TSSL_CTX_set_min_proto_version = function(ctx: PSSL_CTX; version: Integer): Integer; cdecl;
  TSSL_CTX_set_max_proto_version = function(ctx: PSSL_CTX; version: Integer): Integer; cdecl;
  TSSL_CTX_get_min_proto_version = function(ctx: PSSL_CTX): Integer; cdecl;
  TSSL_CTX_get_max_proto_version = function(ctx: PSSL_CTX): Integer; cdecl;
  TSSL_set_min_proto_version = function(ssl: PSSL; version: Integer): Integer; cdecl;
  TSSL_set_max_proto_version = function(ssl: PSSL; version: Integer): Integer; cdecl;
  TSSL_get_min_proto_version = function(ssl: PSSL): Integer; cdecl;
  TSSL_get_max_proto_version = function(ssl: PSSL): Integer; cdecl;
  
  { SSL Control Functions }
  TSSL_ctrl = function(ssl: PSSL; cmd: Integer; larg: clong; parg: Pointer): clong; cdecl;
  TSSL_callback_ctrl = function(ssl: PSSL; cmd: Integer; fp: Pointer): clong; cdecl;
  TSSL_set_options = function(ssl: PSSL; op: clong): clong; cdecl;
  TSSL_clear_options = function(ssl: PSSL; op: clong): clong; cdecl;
  TSSL_get_options = function(const ssl: PSSL): clong; cdecl;
  TSSL_set_mode = function(ssl: PSSL; op: clong): clong; cdecl;
  TSSL_clear_mode = function(ssl: PSSL; op: clong): clong; cdecl;
  TSSL_get_mode = function(const ssl: PSSL): clong; cdecl;
  TSSL_set_max_cert_list = function(ssl: PSSL; m: clong): clong; cdecl;
  TSSL_get_max_cert_list = function(const ssl: PSSL): clong; cdecl;
  TSSL_set_max_send_fragment = function(ssl: PSSL; m: clong): clong; cdecl;
  TSSL_set_split_send_fragment = function(ssl: PSSL; m: clong): clong; cdecl;
  TSSL_set_max_pipelines = function(ssl: PSSL; m: clong): clong; cdecl;
  TSSL_set_read_buffer_len = procedure(ssl: PSSL; len: size_t); cdecl;
  TSSL_set_session_id_context = function(ssl: PSSL; const sid_ctx: PByte; sid_ctx_len: Cardinal): Integer; cdecl;
  TSSL_get_session_id_context = function(const ssl: PSSL; sid_ctx: PByte; sid_ctx_len: PCardinal): Integer; cdecl;
  
  { SSL State and Version Functions }
  TSSL_get_state = function(const ssl: PSSL): Integer; cdecl;
  TSSL_state = function(const ssl: PSSL): Integer; cdecl;
  TSSL_is_init_finished = function(const ssl: PSSL): Integer; cdecl;
  TSSL_in_init = function(const ssl: PSSL): Integer; cdecl;
  TSSL_in_before = function(const ssl: PSSL): Integer; cdecl;
  TSSL_is_server = function(const ssl: PSSL): Integer; cdecl;
  TSSL_version = function(const ssl: PSSL): Integer; cdecl;
  TSSL_client_version = function(const ssl: PSSL): Integer; cdecl;
  TSSL_get_version = function(const ssl: PSSL): PAnsiChar; cdecl;
  TSSL_get_ssl_method = function(const ssl: PSSL): PSSL_METHOD; cdecl;
  TSSL_set_ssl_method = function(ssl: PSSL; const meth: PSSL_METHOD): Integer; cdecl;
  
  { SSL Callbacks }
  TSSL_CTX_set_msg_callback = procedure(ctx: PSSL_CTX; cb: Pointer); cdecl;
  TSSL_set_msg_callback = procedure(ssl: PSSL; cb: Pointer); cdecl;
  TSSL_CTX_set_msg_callback_arg = procedure(ctx: PSSL_CTX; arg: Pointer); cdecl;
  TSSL_set_msg_callback_arg = procedure(ssl: PSSL; arg: Pointer); cdecl;
  TSSL_CTX_set_info_callback = procedure(ctx: PSSL_CTX; cb: TInfo_cb); cdecl;
  TSSL_CTX_get_info_callback = function(ctx: PSSL_CTX): TInfo_cb; cdecl;
  TSSL_set_info_callback = procedure(ssl: PSSL; cb: TInfo_cb); cdecl;
  TSSL_get_info_callback = function(const ssl: PSSL): TInfo_cb; cdecl;
  TSSL_set_state = procedure(ssl: PSSL; state: Integer); cdecl;
  
  { SSL Extension Functions }
  TSSL_set_tlsext_host_name = function(ssl: PSSL; const name: PAnsiChar): Integer; cdecl;
  TSSL_get_servername = function(const ssl: PSSL; const &type: Integer): PAnsiChar; cdecl;
  TSSL_get_servername_type = function(const ssl: PSSL): Integer; cdecl;
  TSSL_export_keying_material = function(ssl: PSSL; &out: PByte; olen: size_t; const &label: PAnsiChar; llen: size_t; const context: PByte; contextlen: size_t; use_context: Integer): Integer; cdecl;
  TSSL_export_keying_material_early = function(ssl: PSSL; &out: PByte; olen: size_t; const &label: PAnsiChar; llen: size_t; const context: PByte; contextlen: size_t): Integer; cdecl;
  
  { SSL ALPN Functions }
  TSSL_CTX_set_alpn_protos = function(ctx: PSSL_CTX; const protos: PByte; protos_len: Cardinal): Integer; cdecl;
  TSSL_set_alpn_protos = function(ssl: PSSL; const protos: PByte; protos_len: Cardinal): Integer; cdecl;
  TSSL_CTX_set_alpn_select_cb = procedure(ctx: PSSL_CTX; cb: TSSL_CTX_alpn_select_cb_func; arg: Pointer); cdecl;
  TSSL_get0_alpn_selected = procedure(const ssl: PSSL; const data: PPByte; len: PCardinal); cdecl;
  TSSL_select_next_proto = function(&out: PPByte; outlen: PByte; const server: PByte; server_len: Cardinal; const client: PByte; client_len: Cardinal): Integer; cdecl;
  
  { SSL PSK Functions }
  TSSL_CTX_set_psk_client_callback = procedure(ctx: PSSL_CTX; cb: TSSL_psk_client_cb_func); cdecl;
  TSSL_set_psk_client_callback = procedure(ssl: PSSL; cb: TSSL_psk_client_cb_func); cdecl;
  TSSL_CTX_set_psk_server_callback = procedure(ctx: PSSL_CTX; cb: TSSL_psk_server_cb_func); cdecl;
  TSSL_set_psk_server_callback = procedure(ssl: PSSL; cb: TSSL_psk_server_cb_func); cdecl;
  TSSL_CTX_use_psk_identity_hint = function(ctx: PSSL_CTX; const identity_hint: PAnsiChar): Integer; cdecl;
  TSSL_use_psk_identity_hint = function(ssl: PSSL; const identity_hint: PAnsiChar): Integer; cdecl;
  TSSL_get_psk_identity_hint = function(const ssl: PSSL): PAnsiChar; cdecl;
  TSSL_get_psk_identity = function(const ssl: PSSL): PAnsiChar; cdecl;
  
  { SSL Session Callbacks }
  TSSL_CTX_sess_set_new_cb = procedure(ctx: PSSL_CTX; new_session_cb: TNew_session_cb); cdecl;
  TSSL_CTX_sess_get_new_cb = function(ctx: PSSL_CTX): TNew_session_cb; cdecl;
  TSSL_CTX_sess_set_remove_cb = procedure(ctx: PSSL_CTX; remove_session_cb: TRemove_session_cb); cdecl;
  TSSL_CTX_sess_get_remove_cb = function(ctx: PSSL_CTX): TRemove_session_cb; cdecl;
  TSSL_CTX_sess_set_get_cb = procedure(ctx: PSSL_CTX; get_session_cb: TGet_session_cb); cdecl;
  TSSL_CTX_sess_get_get_cb = function(ctx: PSSL_CTX): TGet_session_cb; cdecl;
  TSSL_CTX_set_cookie_generate_cb = procedure(ctx: PSSL_CTX; app_gen_cookie_cb: Pointer); cdecl;
  TSSL_CTX_set_cookie_verify_cb = procedure(ctx: PSSL_CTX; app_verify_cookie_cb: Pointer); cdecl;
  
  { SSL Statistics Functions }
  TSSL_CTX_sess_number = function(ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_sess_connect = function(ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_sess_connect_good = function(ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_sess_connect_renegotiate = function(ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_sess_accept = function(ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_sess_accept_good = function(ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_sess_accept_renegotiate = function(ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_sess_hits = function(ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_sess_cb_hits = function(ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_sess_misses = function(ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_sess_timeouts = function(ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_sess_cache_full = function(ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_sess_set_cache_size = function(ctx: PSSL_CTX; t: clong): clong; cdecl;
  TSSL_CTX_sess_get_cache_size = function(ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_set_session_cache_mode = function(ctx: PSSL_CTX; mode: clong): clong; cdecl;
  TSSL_CTX_get_session_cache_mode = function(ctx: PSSL_CTX): clong; cdecl;
  TSSL_CTX_sessions = function(ctx: PSSL_CTX): Pointer; cdecl;
  
  { SSL Compression Functions }
  TSSL_get_current_compression = function(const ssl: PSSL): Pointer; cdecl;
  TSSL_get_current_expansion = function(const ssl: PSSL): Pointer; cdecl;
  TSSL_COMP_get_name = function(const comp: Pointer): PAnsiChar; cdecl;
  TSSL_COMP_get_id = function(const comp: Pointer): Integer; cdecl;
  TSSL_COMP_get_compression_methods = function: Pointer; cdecl;
  TSSL_COMP_set0_compression_methods = function(meths: Pointer): Integer; cdecl;
  
  { SSL Async Functions }
  TSSL_get_all_async_fds = function(ssl: PSSL; fds: PInteger; numfds: Psize_t): Integer; cdecl;
  TSSL_get_changed_async_fds = function(ssl: PSSL; addfd: PInteger; numaddfd: Psize_t; delfd: PInteger; numdelfd: Psize_t): Integer; cdecl;
  TSSL_CTX_set_async_callback = function(ctx: PSSL_CTX; callback: Pointer): Integer; cdecl;
  TSSL_CTX_set_async_callback_arg = function(ctx: PSSL_CTX; arg: Pointer): Integer; cdecl;
  TSSL_set_async_callback = function(ssl: PSSL; callback: Pointer): Integer; cdecl;
  TSSL_set_async_callback_arg = function(ssl: PSSL; arg: Pointer): Integer; cdecl;
  TSSL_get_async_status = function(ssl: PSSL; status: PInteger): Integer; cdecl;
  TSSL_async_capable = function(ssl: PSSL): Integer; cdecl;
  TSSL_waiting_for_async = function(ssl: PSSL): Integer; cdecl;
  
  { SSL Security Level Functions }
  TSSL_CTX_set_security_level = procedure(ctx: PSSL_CTX; level: Integer); cdecl;
  TSSL_CTX_get_security_level = function(const ctx: PSSL_CTX): Integer; cdecl;
  TSSL_CTX_set_security_callback = procedure(ctx: PSSL_CTX; cb: Pointer); cdecl;
  TSSL_CTX_get_security_callback = function(const ctx: PSSL_CTX): Pointer; cdecl;
  TSSL_CTX_set0_security_ex_data = procedure(ctx: PSSL_CTX; ex: Pointer); cdecl;
  TSSL_CTX_get0_security_ex_data = function(const ctx: PSSL_CTX): Pointer; cdecl;
  TSSL_set_security_level = procedure(ssl: PSSL; level: Integer); cdecl;
  TSSL_get_security_level = function(const ssl: PSSL): Integer; cdecl;
  TSSL_set_security_callback = procedure(ssl: PSSL; cb: Pointer); cdecl;
  TSSL_get_security_callback = function(const ssl: PSSL): Pointer; cdecl;
  TSSL_set0_security_ex_data = procedure(ssl: PSSL; ex: Pointer); cdecl;
  TSSL_get0_security_ex_data = function(const ssl: PSSL): Pointer; cdecl;
  
  { SSL Record Functions }
  TSSL_get_record_padding_callback_arg = function(const ssl: PSSL): Pointer; cdecl;
  TSSL_set_record_padding_callback = procedure(ssl: PSSL; cb: Pointer); cdecl;
  TSSL_set_record_padding_callback_arg = procedure(ssl: PSSL; arg: Pointer); cdecl;
  TSSL_CTX_get_record_padding_callback_arg = function(const ctx: PSSL_CTX): Pointer; cdecl;
  TSSL_CTX_set_record_padding_callback = procedure(ctx: PSSL_CTX; cb: Pointer); cdecl;
  TSSL_CTX_set_record_padding_callback_arg = procedure(ctx: PSSL_CTX; arg: Pointer); cdecl;
  TSSL_set_block_padding = procedure(ssl: PSSL; block_size: size_t); cdecl;
  TSSL_CTX_set_block_padding = procedure(ctx: PSSL_CTX; block_size: size_t); cdecl;
  
  { SSL DH Functions }
  TSSL_CTX_set_tmp_dh = function(ctx: PSSL_CTX; dh: PDH): clong; cdecl;
  TSSL_CTX_set_tmp_dh_callback = procedure(ctx: PSSL_CTX; cb: Pointer); cdecl;
  TSSL_CTX_set_dh_auto = function(ctx: PSSL_CTX; onoff: clong): clong; cdecl;
  TSSL_set_tmp_dh = function(ssl: PSSL; dh: PDH): clong; cdecl;
  TSSL_set_tmp_dh_callback = procedure(ssl: PSSL; cb: Pointer); cdecl;
  TSSL_set_dh_auto = function(ssl: PSSL; onoff: clong): clong; cdecl;
  
  { SSL ECDH Functions }
  TSSL_CTX_set_tmp_ecdh = function(ctx: PSSL_CTX; ecdh: PEC_KEY): clong; cdecl;
  TSSL_CTX_set_tmp_ecdh_callback = procedure(ctx: PSSL_CTX; cb: Pointer); cdecl;
  TSSL_CTX_set_ecdh_auto = function(ctx: PSSL_CTX; onoff: Integer): clong; cdecl;
  TSSL_set_tmp_ecdh = function(ssl: PSSL; ecdh: PEC_KEY): clong; cdecl;
  TSSL_set_tmp_ecdh_callback = procedure(ssl: PSSL; cb: Pointer); cdecl;
  TSSL_set_ecdh_auto = function(ssl: PSSL; onoff: Integer): clong; cdecl;
  TSSL_CTX_set1_groups = function(ctx: PSSL_CTX; glist: PInteger; glistlen: size_t): Integer; cdecl;
  TSSL_CTX_set1_groups_list = function(ctx: PSSL_CTX; const list: PAnsiChar): Integer; cdecl;
  TSSL_set1_groups = function(ssl: PSSL; glist: PInteger; glistlen: size_t): Integer; cdecl;
  TSSL_set1_groups_list = function(ssl: PSSL; const list: PAnsiChar): Integer; cdecl;
  TSSL_CTX_set1_curves = function(ctx: PSSL_CTX; clist: PInteger; clistlen: size_t): Integer; cdecl;
  TSSL_CTX_set1_curves_list = function(ctx: PSSL_CTX; const list: PAnsiChar): Integer; cdecl;
  TSSL_set1_curves = function(ssl: PSSL; clist: PInteger; clistlen: size_t): Integer; cdecl;
  TSSL_set1_curves_list = function(ssl: PSSL; const list: PAnsiChar): Integer; cdecl;
  TSSL_CTX_set1_sigalgs = function(ctx: PSSL_CTX; slist: PInteger; slistlen: size_t): clong; cdecl;
  TSSL_CTX_set1_sigalgs_list = function(ctx: PSSL_CTX; const list: PAnsiChar): clong; cdecl;
  TSSL_set1_sigalgs = function(ssl: PSSL; slist: PInteger; slistlen: size_t): clong; cdecl;
  TSSL_set1_sigalgs_list = function(ssl: PSSL; const list: PAnsiChar): clong; cdecl;
  TSSL_CTX_set1_client_sigalgs = function(ctx: PSSL_CTX; slist: PInteger; slistlen: size_t): clong; cdecl;
  TSSL_CTX_set1_client_sigalgs_list = function(ctx: PSSL_CTX; const list: PAnsiChar): clong; cdecl;
  TSSL_set1_client_sigalgs = function(ssl: PSSL; slist: PInteger; slistlen: size_t): clong; cdecl;
  TSSL_set1_client_sigalgs_list = function(ssl: PSSL; const list: PAnsiChar): clong; cdecl;
  TSSL_CTX_set1_sigalgs_cert = function(ctx: PSSL_CTX; slist: PInteger; slistlen: size_t): clong; cdecl;
  TSSL_CTX_set1_sigalgs_cert_list = function(ctx: PSSL_CTX; const list: PAnsiChar): clong; cdecl;
  TSSL_set1_sigalgs_cert = function(ssl: PSSL; slist: PInteger; slistlen: size_t): clong; cdecl;
  TSSL_set1_sigalgs_cert_list = function(ssl: PSSL; const list: PAnsiChar): clong; cdecl;
  TSSL_CTX_set1_client_sigalgs_cert = function(ctx: PSSL_CTX; slist: PInteger; slistlen: size_t): clong; cdecl;
  TSSL_CTX_set1_client_sigalgs_cert_list = function(ctx: PSSL_CTX; const list: PAnsiChar): clong; cdecl;
  TSSL_set1_client_sigalgs_cert = function(ssl: PSSL; slist: PInteger; slistlen: size_t): clong; cdecl;
  TSSL_set1_client_sigalgs_cert_list = function(ssl: PSSL; const list: PAnsiChar): clong; cdecl;

var
  // Function pointers - will be dynamically loaded
  OPENSSL_init_ssl: TOPENSSL_init_ssl = nil;
  OPENSSL_cleanup: TOPENSSL_cleanup = nil;
  OpenSSL_version_num: TOpenSSL_version_num = nil;
  OpenSSL_version: TOpenSSL_version = nil;
  
  // SSL Method Functions
  TLS_method: TTLS_method = nil;
  TLS_server_method: TTLS_server_method = nil;
  TLS_client_method: TTLS_client_method = nil;
  SSLv23_method: TSSLv23_method = nil;
  SSLv23_server_method: TSSLv23_server_method = nil;
  SSLv23_client_method: TSSLv23_client_method = nil;
  DTLS_method: TDTLS_method = nil;
  DTLS_server_method: TDTLS_server_method = nil;
  DTLS_client_method: TDTLS_client_method = nil;
  
  // Context functions
  SSL_CTX_new: TSSL_CTX_new = nil;
  SSL_CTX_new_ex: TSSL_CTX_new_ex = nil;
  SSL_CTX_free: TSSL_CTX_free = nil;
  SSL_CTX_up_ref: TSSL_CTX_up_ref = nil;
  SSL_CTX_set_timeout: TSSL_CTX_set_timeout = nil;
  SSL_CTX_get_timeout: TSSL_CTX_get_timeout = nil;
  SSL_CTX_get_cert_store: TSSL_CTX_get_cert_store = nil;
  SSL_CTX_set_cert_store: TSSL_CTX_set_cert_store = nil;
  SSL_CTX_set1_cert_store: TSSL_CTX_set1_cert_store = nil;
  SSL_CTX_get0_certificate: TSSL_CTX_get0_certificate = nil;
  SSL_CTX_get0_privatekey: TSSL_CTX_get0_privatekey = nil;
  
  // Connection functions
  SSL_new: TSSL_new = nil;
  SSL_free: TSSL_free = nil;
  SSL_up_ref: TSSL_up_ref = nil;
  SSL_dup: TSSL_dup = nil;
  SSL_get_SSL_CTX: TSSL_get_SSL_CTX = nil;
  SSL_set_SSL_CTX: TSSL_set_SSL_CTX = nil;
  
  // Connection setup
  SSL_set_fd: TSSL_set_fd = nil;
  SSL_set_rfd: TSSL_set_rfd = nil;
  SSL_set_wfd: TSSL_set_wfd = nil;
  SSL_get_fd: TSSL_get_fd = nil;
  SSL_get_rfd: TSSL_get_rfd = nil;
  SSL_get_wfd: TSSL_get_wfd = nil;
  SSL_set_bio: TSSL_set_bio = nil;
  SSL_set0_rbio: TSSL_set0_rbio = nil;
  SSL_set0_wbio: TSSL_set0_wbio = nil;
  SSL_get_rbio: TSSL_get_rbio = nil;
  SSL_get_wbio: TSSL_get_wbio = nil;
  
  // Handshake functions
  SSL_connect: TSSL_connect = nil;
  SSL_accept: TSSL_accept = nil;
  SSL_do_handshake: TSSL_do_handshake = nil;
  SSL_renegotiate: TSSL_renegotiate = nil;
  SSL_renegotiate_abbreviated: TSSL_renegotiate_abbreviated = nil;
  SSL_renegotiate_pending: TSSL_renegotiate_pending = nil;
  SSL_key_update: TSSL_key_update = nil;
  SSL_get_key_update_type: TSSL_get_key_update_type = nil;
  
  // Data transfer functions
  SSL_read: TSSL_read = nil;
  SSL_read_ex: TSSL_read_ex = nil;
  SSL_read_early_data: TSSL_read_early_data = nil;
  SSL_peek: TSSL_peek = nil;
  SSL_peek_ex: TSSL_peek_ex = nil;
  SSL_write: TSSL_write = nil;
  SSL_write_ex: TSSL_write_ex = nil;
  SSL_write_early_data: TSSL_write_early_data = nil;
  SSL_sendfile: TSSL_sendfile = nil;
  
  // Shutdown functions
  SSL_shutdown: TSSL_shutdown = nil;
  SSL_CTX_set_quiet_shutdown: TSSL_CTX_set_quiet_shutdown = nil;
  SSL_CTX_get_quiet_shutdown: TSSL_CTX_get_quiet_shutdown = nil;
  SSL_set_quiet_shutdown: TSSL_set_quiet_shutdown = nil;
  SSL_get_quiet_shutdown: TSSL_get_quiet_shutdown = nil;
  SSL_set_shutdown: TSSL_set_shutdown = nil;
  SSL_get_shutdown: TSSL_get_shutdown = nil;
  
  // Error handling functions
  SSL_get_error: TSSL_get_error = nil;
  SSL_want: TSSL_want = nil;
  SSL_want_nothing: TSSL_want_nothing = nil;
  SSL_want_read: TSSL_want_read = nil;
  SSL_want_write: TSSL_want_write = nil;
  SSL_want_x509_lookup: TSSL_want_x509_lookup = nil;
  SSL_want_async: TSSL_want_async = nil;
  SSL_want_async_job: TSSL_want_async_job = nil;
  SSL_want_client_hello_cb: TSSL_want_client_hello_cb = nil;
  
  // Context certificate and key functions
  SSL_CTX_use_certificate: TSSL_CTX_use_certificate = nil;
  SSL_CTX_use_certificate_file: TSSL_CTX_use_certificate_file = nil;
  SSL_CTX_use_certificate_chain_file: TSSL_CTX_use_certificate_chain_file = nil;
  SSL_CTX_use_PrivateKey: TSSL_CTX_use_PrivateKey = nil;
  SSL_CTX_use_PrivateKey_file: TSSL_CTX_use_PrivateKey_file = nil;
  SSL_CTX_check_private_key: TSSL_CTX_check_private_key = nil;
  SSL_CTX_set_default_passwd_cb: TSSL_CTX_set_default_passwd_cb = nil;
  SSL_CTX_set_default_passwd_cb_userdata: TSSL_CTX_set_default_passwd_cb_userdata = nil;
  SSL_CTX_get_default_passwd_cb: TSSL_CTX_get_default_passwd_cb = nil;
  SSL_CTX_get_default_passwd_cb_userdata: TSSL_CTX_get_default_passwd_cb_userdata = nil;
  
  // Context verification and options
  SSL_CTX_set_verify: TSSL_CTX_set_verify = nil;
  SSL_CTX_set_verify_depth: TSSL_CTX_set_verify_depth = nil;
  SSL_CTX_get_verify_mode: TSSL_CTX_get_verify_mode = nil;
  SSL_CTX_get_verify_depth: TSSL_CTX_get_verify_depth = nil;
  SSL_CTX_get_verify_callback: TSSL_CTX_get_verify_callback = nil;
  SSL_CTX_load_verify_locations: TSSL_CTX_load_verify_locations = nil;
  SSL_CTX_set_default_verify_paths: TSSL_CTX_set_default_verify_paths = nil;
  SSL_CTX_set_options: TSSL_CTX_set_options = nil;
  SSL_CTX_clear_options: TSSL_CTX_clear_options = nil;
  SSL_CTX_get_options: TSSL_CTX_get_options = nil;
  SSL_CTX_set_session_cache_mode: TSSL_CTX_set_session_cache_mode = nil;
  SSL_CTX_get_session_cache_mode: TSSL_CTX_get_session_cache_mode = nil;
  SSL_CTX_sess_set_cache_size: TSSL_CTX_sess_set_cache_size = nil;
  SSL_CTX_sess_get_cache_size: TSSL_CTX_sess_get_cache_size = nil;
  SSL_CTX_set_cert_verify_callback: TSSL_CTX_set_cert_verify_callback = nil;

  // Control functions
  SSL_CTX_ctrl: TSSL_CTX_ctrl = nil;
  SSL_ctrl: TSSL_ctrl = nil;
  
  // Connection state functions
  SSL_set_connect_state: TSSL_set_connect_state = nil;
  SSL_set_accept_state: TSSL_set_accept_state = nil;
  
  // Peer certificate functions
  SSL_get_peer_certificate: TSSL_get_peer_certificate = nil;
  SSL_get1_peer_certificate: TSSL_get1_peer_certificate = nil;  // OpenSSL 3.x version
  SSL_get_peer_cert_chain: TSSL_get_peer_cert_chain = nil;
  SSL_get0_verified_chain: TSSL_get0_verified_chain = nil;
  
  // Verification result functions
  SSL_get_verify_result: TSSL_get_verify_result = nil;
  SSL_set_verify_result: TSSL_set_verify_result = nil;
  
  // Session functions
  SSL_session_reused: TSSL_session_reused = nil;
  SSL_get_session: TSSL_get_session = nil;
  SSL_get1_session: TSSL_get1_session = nil;
  SSL_get0_session: TSSL_get0_session = nil;
  SSL_set_session: TSSL_set_session = nil;
  
  // SSL_SESSION functions
  SSL_SESSION_new: TSSL_SESSION_new = nil;
  SSL_SESSION_free: TSSL_SESSION_free = nil;
  SSL_SESSION_up_ref: TSSL_SESSION_up_ref = nil;
  SSL_SESSION_get_id: TSSL_SESSION_get_id = nil;
  SSL_SESSION_get_time: TSSL_SESSION_get_time = nil;
  SSL_SESSION_set_time: TSSL_SESSION_set_time = nil;
  SSL_SESSION_get_timeout: TSSL_SESSION_get_timeout = nil;
  SSL_SESSION_set_timeout: TSSL_SESSION_set_timeout = nil;
  SSL_SESSION_get_protocol_version: TSSL_SESSION_get_protocol_version = nil;
  SSL_SESSION_get0_cipher: TSSL_SESSION_get0_cipher = nil;
  SSL_SESSION_get0_peer: TSSL_SESSION_get0_peer = nil;
  SSL_SESSION_is_resumable: TSSL_SESSION_is_resumable = nil;
  SSL_SESSION_get_max_early_data: TSSL_SESSION_get_max_early_data = nil;
  SSL_SESSION_set_max_early_data: TSSL_SESSION_set_max_early_data = nil;
  
  // State and version functions
  SSL_get_state: TSSL_get_state = nil;
  SSL_state: TSSL_state = nil;
  SSL_is_init_finished: TSSL_is_init_finished = nil;
  SSL_in_init: TSSL_in_init = nil;
  SSL_in_before: TSSL_in_before = nil;
  SSL_is_server: TSSL_is_server = nil;
  SSL_version: TSSL_version = nil;
  SSL_client_version: TSSL_client_version = nil;
  SSL_get_version: TSSL_get_version = nil;
  SSL_get_ssl_method: TSSL_get_ssl_method = nil;
  SSL_set_ssl_method: TSSL_set_ssl_method = nil;
  
  // Cipher functions
  SSL_get_current_cipher: TSSL_get_current_cipher = nil;
  SSL_get_pending_cipher: TSSL_get_pending_cipher = nil;
  SSL_CIPHER_get_name: TSSL_CIPHER_get_name = nil;
  SSL_CIPHER_get_bits: TSSL_CIPHER_get_bits = nil;
  SSL_CIPHER_get_version: TSSL_CIPHER_get_version = nil;

  { Dynamic Library Loading }
  
procedure LoadOpenSSLCore;
procedure LoadOpenSSLCoreWithVersion(AVersion: TOpenSSLVersion);
procedure UnloadOpenSSLCore;
function GetSSLLibHandle: TLibHandle;
function GetCryptoLibHandle: TLibHandle;
function GetOpenSSLVersion: TOpenSSLVersion;
function GetOpenSSLVersionString: string;

// Helper functions for module loading
function GetCryptoProcAddress(const ProcName: string): Pointer;
function GetSSLProcAddress(const ProcName: string): Pointer;

{ Helper functions for SSL_want macros }
function SSL_want_read_impl(const ssl: PSSL): Integer; cdecl;
function SSL_want_write_impl(const ssl: PSSL): Integer; cdecl;

{ Helper functions for SSL_CTX session cache mode (OpenSSL 3.x compatibility) }
function SSL_CTX_set_session_cache_mode_impl(ctx: PSSL_CTX; mode: clong): clong;
function SSL_CTX_get_session_cache_mode_impl(ctx: PSSL_CTX): clong;

implementation

var
  // P0-1.1: 不再在本单元存储库句柄，改为委托给 TOpenSSLLoader
  // LibSSLHandle 和 LibCryptoHandle 现在通过 TOpenSSLLoader 获取
  LoadedOpenSSLVersion: TOpenSSLVersion = sslUnknown;
  LoadedCryptoLibName: string = '';
  LoadedSSLLibName: string = '';

// P0-1.1: 委托函数，用于向后兼容
function LibCryptoHandle: TLibHandle; inline;
begin
  Result := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
end;

function LibSSLHandle: TLibHandle; inline;
begin
  Result := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
end;

function TryLoadOpenSSLLibraries(const ACryptoLib, ASSLLib: string): Boolean;
begin
  // P0-1.1: 委托给 TOpenSSLLoader 进行加载
  // 注意: TOpenSSLLoader 使用自己的库名列表，这里的参数仅用于记录
  Result := TOpenSSLLoader.IsLoaded(osslLibCrypto) and TOpenSSLLoader.IsLoaded(osslLibSSL);

  if not Result then
  begin
    // 触发加载
    TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
    TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
    Result := TOpenSSLLoader.IsLoaded(osslLibCrypto) and TOpenSSLLoader.IsLoaded(osslLibSSL);
  end;

  if Result then
  begin
    LoadedCryptoLibName := ACryptoLib;
    LoadedSSLLibName := ASSLLib;
  end;
end;

procedure LoadOpenSSLCoreWithVersion(AVersion: TOpenSSLVersion);
var
  CryptoLib, SSLLib: string;
begin
  // P0-1.1: 核心模块已加载则无需重复初始化
  if TOpenSSLLoader.IsModuleLoaded(osmCore) then
    Exit;

  // Set library names based on requested version
  case AVersion of
    sslVersion_3_0:
    begin
      CryptoLib := LIBCRYPTO_3;
      SSLLib := LIBSSL_3;
      LoadedOpenSSLVersion := sslVersion_3_0;
    end;
    sslVersion_1_1:
    begin
      CryptoLib := LIBCRYPTO_1_1;
      SSLLib := LIBSSL_1_1;
      LoadedOpenSSLVersion := sslVersion_1_1;
    end;
  else
    raise ESSLException.Create('Unknown OpenSSL version requested');
  end;

  // Try to load the specified version
  if not TryLoadOpenSSLLibraries(CryptoLib, SSLLib) then
    raise ESSLException.CreateFmt('Failed to load OpenSSL %s libraries: %s and %s',
      [GetOpenSSLVersionString, CryptoLib, SSLLib]);
end;

procedure LoadOpenSSLCore;
begin
  // P0-1.1: 核心模块已加载则无需重复初始化
  if TOpenSSLLoader.IsModuleLoaded(osmCore) then
    Exit;
  
  // Try OpenSSL 3.x first (recommended version)
  if TryLoadOpenSSLLibraries(LIBCRYPTO_3, LIBSSL_3) then
  begin
    LoadedOpenSSLVersion := sslVersion_3_0;
  end
  // Fall back to OpenSSL 1.1.x
  else if TryLoadOpenSSLLibraries(LIBCRYPTO_1_1, LIBSSL_1_1) then
  begin
    LoadedOpenSSLVersion := sslVersion_1_1;
  end
  else
  begin
    // Both versions failed
    raise ESSLException.Create(
      'Failed to load any OpenSSL library. Tried:' + sLineBreak +
      '  - OpenSSL 3.x: ' + LIBCRYPTO_3 + ', ' + LIBSSL_3 + sLineBreak +
      '  - OpenSSL 1.1.x: ' + LIBCRYPTO_1_1 + ', ' + LIBSSL_1_1
    );
  end;
  
  // Load function pointers
  OPENSSL_init_ssl := TOPENSSL_init_ssl(GetProcedureAddress(LibSSLHandle, 'OPENSSL_init_ssl'));
  OPENSSL_cleanup := TOPENSSL_cleanup(GetProcedureAddress(LibCryptoHandle, 'OPENSSL_cleanup'));
  OpenSSL_version_num := TOpenSSL_version_num(GetProcedureAddress(LibCryptoHandle, 'OpenSSL_version_num'));
  OpenSSL_version := TOpenSSL_version(GetProcedureAddress(LibCryptoHandle, 'OpenSSL_version'));
  
  // Methods
  TLS_method := TTLS_method(GetProcedureAddress(LibSSLHandle, 'TLS_method'));
  TLS_server_method := TTLS_server_method(GetProcedureAddress(LibSSLHandle, 'TLS_server_method'));
  TLS_client_method := TTLS_client_method(GetProcedureAddress(LibSSLHandle, 'TLS_client_method'));
  SSLv23_method := TSSLv23_method(GetProcedureAddress(LibSSLHandle, 'SSLv23_method'));
  SSLv23_server_method := TSSLv23_server_method(GetProcedureAddress(LibSSLHandle, 'SSLv23_server_method'));
  SSLv23_client_method := TSSLv23_client_method(GetProcedureAddress(LibSSLHandle, 'SSLv23_client_method'));
  DTLS_method := TDTLS_method(GetProcedureAddress(LibSSLHandle, 'DTLS_method'));
  DTLS_server_method := TDTLS_server_method(GetProcedureAddress(LibSSLHandle, 'DTLS_server_method'));
  DTLS_client_method := TDTLS_client_method(GetProcedureAddress(LibSSLHandle, 'DTLS_client_method'));
  
  // Context functions
  SSL_CTX_new := TSSL_CTX_new(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_new'));
  SSL_CTX_free := TSSL_CTX_free(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_free'));
  SSL_CTX_up_ref := TSSL_CTX_up_ref(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_up_ref'));
  SSL_CTX_set_timeout := TSSL_CTX_set_timeout(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_set_timeout'));
  SSL_CTX_get_timeout := TSSL_CTX_get_timeout(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_get_timeout'));
  SSL_CTX_get_cert_store := TSSL_CTX_get_cert_store(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_get_cert_store'));
  SSL_CTX_set_cert_store := TSSL_CTX_set_cert_store(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_set_cert_store'));
  SSL_CTX_set1_cert_store := TSSL_CTX_set1_cert_store(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_set1_cert_store'));
  SSL_CTX_get0_certificate := TSSL_CTX_get0_certificate(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_get0_certificate'));
  SSL_CTX_get0_privatekey := TSSL_CTX_get0_privatekey(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_get0_privatekey'));
  
  // Connection functions
  SSL_new := TSSL_new(GetProcedureAddress(LibSSLHandle, 'SSL_new'));
  SSL_free := TSSL_free(GetProcedureAddress(LibSSLHandle, 'SSL_free'));
  SSL_up_ref := TSSL_up_ref(GetProcedureAddress(LibSSLHandle, 'SSL_up_ref'));
  SSL_dup := TSSL_dup(GetProcedureAddress(LibSSLHandle, 'SSL_dup'));
  SSL_get_SSL_CTX := TSSL_get_SSL_CTX(GetProcedureAddress(LibSSLHandle, 'SSL_get_SSL_CTX'));
  SSL_set_SSL_CTX := TSSL_set_SSL_CTX(GetProcedureAddress(LibSSLHandle, 'SSL_set_SSL_CTX'));
  
  // Connection setup
  SSL_set_fd := TSSL_set_fd(GetProcedureAddress(LibSSLHandle, 'SSL_set_fd'));
  SSL_set_rfd := TSSL_set_rfd(GetProcedureAddress(LibSSLHandle, 'SSL_set_rfd'));
  SSL_set_wfd := TSSL_set_wfd(GetProcedureAddress(LibSSLHandle, 'SSL_set_wfd'));
  SSL_get_fd := TSSL_get_fd(GetProcedureAddress(LibSSLHandle, 'SSL_get_fd'));
  SSL_get_rfd := TSSL_get_rfd(GetProcedureAddress(LibSSLHandle, 'SSL_get_rfd'));
  SSL_get_wfd := TSSL_get_wfd(GetProcedureAddress(LibSSLHandle, 'SSL_get_wfd'));
  SSL_set_bio := TSSL_set_bio(GetProcedureAddress(LibSSLHandle, 'SSL_set_bio'));
  SSL_set0_rbio := TSSL_set0_rbio(GetProcedureAddress(LibSSLHandle, 'SSL_set0_rbio'));
  SSL_set0_wbio := TSSL_set0_wbio(GetProcedureAddress(LibSSLHandle, 'SSL_set0_wbio'));
  SSL_get_rbio := TSSL_get_rbio(GetProcedureAddress(LibSSLHandle, 'SSL_get_rbio'));
  SSL_get_wbio := TSSL_get_wbio(GetProcedureAddress(LibSSLHandle, 'SSL_get_wbio'));
  
  // Handshake
  SSL_connect := TSSL_connect(GetProcedureAddress(LibSSLHandle, 'SSL_connect'));
  SSL_accept := TSSL_accept(GetProcedureAddress(LibSSLHandle, 'SSL_accept'));
  SSL_do_handshake := TSSL_do_handshake(GetProcedureAddress(LibSSLHandle, 'SSL_do_handshake'));
  SSL_renegotiate := TSSL_renegotiate(GetProcedureAddress(LibSSLHandle, 'SSL_renegotiate'));
  SSL_renegotiate_abbreviated := TSSL_renegotiate_abbreviated(GetProcedureAddress(LibSSLHandle, 'SSL_renegotiate_abbreviated'));
  SSL_renegotiate_pending := TSSL_renegotiate_pending(GetProcedureAddress(LibSSLHandle, 'SSL_renegotiate_pending'));
  SSL_key_update := TSSL_key_update(GetProcedureAddress(LibSSLHandle, 'SSL_key_update'));
  SSL_get_key_update_type := TSSL_get_key_update_type(GetProcedureAddress(LibSSLHandle, 'SSL_get_key_update_type'));
  
  // Data transfer
  SSL_read := TSSL_read(GetProcedureAddress(LibSSLHandle, 'SSL_read'));
  SSL_read_ex := TSSL_read_ex(GetProcedureAddress(LibSSLHandle, 'SSL_read_ex'));
  SSL_read_early_data := TSSL_read_early_data(GetProcedureAddress(LibSSLHandle, 'SSL_read_early_data'));
  SSL_peek := TSSL_peek(GetProcedureAddress(LibSSLHandle, 'SSL_peek'));
  SSL_peek_ex := TSSL_peek_ex(GetProcedureAddress(LibSSLHandle, 'SSL_peek_ex'));
  SSL_write := TSSL_write(GetProcedureAddress(LibSSLHandle, 'SSL_write'));
  SSL_write_ex := TSSL_write_ex(GetProcedureAddress(LibSSLHandle, 'SSL_write_ex'));
  SSL_write_early_data := TSSL_write_early_data(GetProcedureAddress(LibSSLHandle, 'SSL_write_early_data'));
  SSL_sendfile := TSSL_sendfile(GetProcedureAddress(LibSSLHandle, 'SSL_sendfile'));
  
  // Shutdown
  SSL_shutdown := TSSL_shutdown(GetProcedureAddress(LibSSLHandle, 'SSL_shutdown'));
  SSL_CTX_set_quiet_shutdown := TSSL_CTX_set_quiet_shutdown(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_set_quiet_shutdown'));
  SSL_CTX_get_quiet_shutdown := TSSL_CTX_get_quiet_shutdown(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_get_quiet_shutdown'));
  SSL_set_quiet_shutdown := TSSL_set_quiet_shutdown(GetProcedureAddress(LibSSLHandle, 'SSL_set_quiet_shutdown'));
  SSL_get_quiet_shutdown := TSSL_get_quiet_shutdown(GetProcedureAddress(LibSSLHandle, 'SSL_get_quiet_shutdown'));
  SSL_set_shutdown := TSSL_set_shutdown(GetProcedureAddress(LibSSLHandle, 'SSL_set_shutdown'));
  SSL_get_shutdown := TSSL_get_shutdown(GetProcedureAddress(LibSSLHandle, 'SSL_get_shutdown'));
  
  // Error handling
  SSL_get_error := TSSL_get_error(GetProcedureAddress(LibSSLHandle, 'SSL_get_error'));
  SSL_want := TSSL_want(GetProcedureAddress(LibSSLHandle, 'SSL_want'));
  SSL_want_nothing := TSSL_want_nothing(GetProcedureAddress(LibSSLHandle, 'SSL_want_nothing'));
  SSL_want_read := TSSL_want_read(GetProcedureAddress(LibSSLHandle, 'SSL_want_read'));
  SSL_want_write := TSSL_want_write(GetProcedureAddress(LibSSLHandle, 'SSL_want_write'));
  SSL_want_x509_lookup := TSSL_want_x509_lookup(GetProcedureAddress(LibSSLHandle, 'SSL_want_x509_lookup'));
  SSL_want_async := TSSL_want_async(GetProcedureAddress(LibSSLHandle, 'SSL_want_async'));
  SSL_want_async_job := TSSL_want_async_job(GetProcedureAddress(LibSSLHandle, 'SSL_want_async_job'));
  SSL_want_client_hello_cb := TSSL_want_client_hello_cb(GetProcedureAddress(LibSSLHandle, 'SSL_want_client_hello_cb'));
  
  // SSL Context options and verification
  SSL_CTX_set_options := TSSL_CTX_set_options(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_set_options'));
  SSL_CTX_clear_options := TSSL_CTX_clear_options(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_clear_options'));
  SSL_CTX_get_options := TSSL_CTX_get_options(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_get_options'));
  SSL_CTX_set_verify := TSSL_CTX_set_verify(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_set_verify'));
  SSL_CTX_set_verify_depth := TSSL_CTX_set_verify_depth(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_set_verify_depth'));
  SSL_CTX_get_verify_mode := TSSL_CTX_get_verify_mode(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_get_verify_mode'));
  SSL_CTX_get_verify_depth := TSSL_CTX_get_verify_depth(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_get_verify_depth'));
  SSL_CTX_get_verify_callback := TSSL_CTX_get_verify_callback(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_get_verify_callback'));
  SSL_CTX_load_verify_locations := TSSL_CTX_load_verify_locations(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_load_verify_locations'));
  SSL_CTX_set_default_verify_paths := TSSL_CTX_set_default_verify_paths(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_set_default_verify_paths'));
  SSL_CTX_set_session_cache_mode := TSSL_CTX_set_session_cache_mode(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_set_session_cache_mode'));
  SSL_CTX_get_session_cache_mode := TSSL_CTX_get_session_cache_mode(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_get_session_cache_mode'));
  SSL_CTX_sess_set_cache_size := TSSL_CTX_sess_set_cache_size(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_sess_set_cache_size'));
  SSL_CTX_sess_get_cache_size := TSSL_CTX_sess_get_cache_size(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_sess_get_cache_size'));
  SSL_CTX_set_cert_verify_callback := TSSL_CTX_set_cert_verify_callback(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_set_cert_verify_callback'));

  // Control functions
  SSL_CTX_ctrl := TSSL_CTX_ctrl(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_ctrl'));
  SSL_ctrl := TSSL_ctrl(GetProcedureAddress(LibSSLHandle, 'SSL_ctrl'));
  
  // Certificate and private key functions
  SSL_CTX_use_certificate := TSSL_CTX_use_certificate(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_use_certificate'));
  SSL_CTX_use_certificate_file := TSSL_CTX_use_certificate_file(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_use_certificate_file'));
  SSL_CTX_use_certificate_chain_file := TSSL_CTX_use_certificate_chain_file(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_use_certificate_chain_file'));
  SSL_CTX_use_PrivateKey := TSSL_CTX_use_PrivateKey(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_use_PrivateKey'));
  SSL_CTX_use_PrivateKey_file := TSSL_CTX_use_PrivateKey_file(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_use_PrivateKey_file'));
  SSL_CTX_check_private_key := TSSL_CTX_check_private_key(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_check_private_key'));
  SSL_CTX_set_default_passwd_cb := TSSL_CTX_set_default_passwd_cb(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_set_default_passwd_cb'));
  SSL_CTX_set_default_passwd_cb_userdata := TSSL_CTX_set_default_passwd_cb_userdata(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_set_default_passwd_cb_userdata'));
  SSL_CTX_get_default_passwd_cb := TSSL_CTX_get_default_passwd_cb(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_get_default_passwd_cb'));
  SSL_CTX_get_default_passwd_cb_userdata := TSSL_CTX_get_default_passwd_cb_userdata(GetProcedureAddress(LibSSLHandle, 'SSL_CTX_get_default_passwd_cb_userdata'));
  
  // Connection state functions
  SSL_set_connect_state := TSSL_set_connect_state(GetProcedureAddress(LibSSLHandle, 'SSL_set_connect_state'));
  SSL_set_accept_state := TSSL_set_accept_state(GetProcedureAddress(LibSSLHandle, 'SSL_set_accept_state'));
  
  // Peer certificate functions
  // Try deprecated name first (OpenSSL 1.1.x), fall back to new name (OpenSSL 3.x)
  SSL_get_peer_certificate := TSSL_get_peer_certificate(GetProcedureAddress(LibSSLHandle, 'SSL_get_peer_certificate'));
  if not Assigned(SSL_get_peer_certificate) then
  begin
    // In OpenSSL 3.x, SSL_get_peer_certificate was renamed to SSL_get1_peer_certificate
    SSL_get1_peer_certificate := TSSL_get1_peer_certificate(GetProcedureAddress(LibSSLHandle, 'SSL_get1_peer_certificate'));
    SSL_get_peer_certificate := TSSL_get_peer_certificate(SSL_get1_peer_certificate);
  end;
  SSL_get_peer_cert_chain := TSSL_get_peer_cert_chain(GetProcedureAddress(LibSSLHandle, 'SSL_get_peer_cert_chain'));
  SSL_get0_verified_chain := TSSL_get0_verified_chain(GetProcedureAddress(LibSSLHandle, 'SSL_get0_verified_chain'));
  
  // Verification result functions
  SSL_get_verify_result := TSSL_get_verify_result(GetProcedureAddress(LibSSLHandle, 'SSL_get_verify_result'));
  SSL_set_verify_result := TSSL_set_verify_result(GetProcedureAddress(LibSSLHandle, 'SSL_set_verify_result'));
  
  // Session functions
  SSL_session_reused := TSSL_session_reused(GetProcedureAddress(LibSSLHandle, 'SSL_session_reused'));
  SSL_get_session := TSSL_get_session(GetProcedureAddress(LibSSLHandle, 'SSL_get_session'));
  SSL_get1_session := TSSL_get1_session(GetProcedureAddress(LibSSLHandle, 'SSL_get1_session'));
  SSL_get0_session := TSSL_get0_session(GetProcedureAddress(LibSSLHandle, 'SSL_get0_session'));
  SSL_set_session := TSSL_set_session(GetProcedureAddress(LibSSLHandle, 'SSL_set_session'));
  
  // SSL_SESSION functions
  SSL_SESSION_new := TSSL_SESSION_new(GetProcedureAddress(LibSSLHandle, 'SSL_SESSION_new'));
  SSL_SESSION_free := TSSL_SESSION_free(GetProcedureAddress(LibSSLHandle, 'SSL_SESSION_free'));
  SSL_SESSION_up_ref := TSSL_SESSION_up_ref(GetProcedureAddress(LibSSLHandle, 'SSL_SESSION_up_ref'));
  SSL_SESSION_get_id := TSSL_SESSION_get_id(GetProcedureAddress(LibSSLHandle, 'SSL_SESSION_get_id'));
  SSL_SESSION_get_time := TSSL_SESSION_get_time(GetProcedureAddress(LibSSLHandle, 'SSL_SESSION_get_time'));
  SSL_SESSION_set_time := TSSL_SESSION_set_time(GetProcedureAddress(LibSSLHandle, 'SSL_SESSION_set_time'));
  SSL_SESSION_get_timeout := TSSL_SESSION_get_timeout(GetProcedureAddress(LibSSLHandle, 'SSL_SESSION_get_timeout'));
  SSL_SESSION_set_timeout := TSSL_SESSION_set_timeout(GetProcedureAddress(LibSSLHandle, 'SSL_SESSION_set_timeout'));
  SSL_SESSION_get_protocol_version := TSSL_SESSION_get_protocol_version(GetProcedureAddress(LibSSLHandle, 'SSL_SESSION_get_protocol_version'));
  SSL_SESSION_get0_cipher := TSSL_SESSION_get0_cipher(GetProcedureAddress(LibSSLHandle, 'SSL_SESSION_get0_cipher'));
  SSL_SESSION_get0_peer := TSSL_SESSION_get0_peer(GetProcedureAddress(LibSSLHandle, 'SSL_SESSION_get0_peer'));
  SSL_SESSION_is_resumable := TSSL_SESSION_is_resumable(GetProcedureAddress(LibSSLHandle, 'SSL_SESSION_is_resumable'));
  SSL_SESSION_get_max_early_data := TSSL_SESSION_get_max_early_data(GetProcedureAddress(LibSSLHandle, 'SSL_SESSION_get_max_early_data'));
  SSL_SESSION_set_max_early_data := TSSL_SESSION_set_max_early_data(GetProcedureAddress(LibSSLHandle, 'SSL_SESSION_set_max_early_data'));
  
  // State and version functions
  SSL_get_state := TSSL_get_state(GetProcedureAddress(LibSSLHandle, 'SSL_get_state'));
  SSL_state := TSSL_state(GetProcedureAddress(LibSSLHandle, 'SSL_state'));
  SSL_is_init_finished := TSSL_is_init_finished(GetProcedureAddress(LibSSLHandle, 'SSL_is_init_finished'));
  SSL_in_init := TSSL_in_init(GetProcedureAddress(LibSSLHandle, 'SSL_in_init'));
  SSL_in_before := TSSL_in_before(GetProcedureAddress(LibSSLHandle, 'SSL_in_before'));
  SSL_is_server := TSSL_is_server(GetProcedureAddress(LibSSLHandle, 'SSL_is_server'));
  SSL_version := TSSL_version(GetProcedureAddress(LibSSLHandle, 'SSL_version'));
  SSL_client_version := TSSL_client_version(GetProcedureAddress(LibSSLHandle, 'SSL_client_version'));
  SSL_get_version := TSSL_get_version(GetProcedureAddress(LibSSLHandle, 'SSL_get_version'));
  SSL_get_ssl_method := TSSL_get_ssl_method(GetProcedureAddress(LibSSLHandle, 'SSL_get_ssl_method'));
  SSL_set_ssl_method := TSSL_set_ssl_method(GetProcedureAddress(LibSSLHandle, 'SSL_set_ssl_method'));
  
  // Cipher functions
  SSL_get_current_cipher := TSSL_get_current_cipher(GetProcedureAddress(LibSSLHandle, 'SSL_get_current_cipher'));
  SSL_get_pending_cipher := TSSL_get_pending_cipher(GetProcedureAddress(LibSSLHandle, 'SSL_get_pending_cipher'));
  SSL_CIPHER_get_name := TSSL_CIPHER_get_name(GetProcedureAddress(LibSSLHandle, 'SSL_CIPHER_get_name'));
  SSL_CIPHER_get_bits := TSSL_CIPHER_get_bits(GetProcedureAddress(LibSSLHandle, 'SSL_CIPHER_get_bits'));
  SSL_CIPHER_get_version := TSSL_CIPHER_get_version(GetProcedureAddress(LibSSLHandle, 'SSL_CIPHER_get_version'));
  
  // SSL_want_read and SSL_want_write are often macros in OpenSSL headers
  // Try to load them directly, if not available, use our helper implementations
  if not Assigned(SSL_want_read) then
    SSL_want_read := @SSL_want_read_impl;
  if not Assigned(SSL_want_write) then
    SSL_want_write := @SSL_want_write_impl;

  // Continue loading all other functions...
  // This is just a partial list, the complete implementation would load all 300+ functions

  // P1-2.1: Mark core module as loaded for test framework
  TOpenSSLLoader.SetModuleLoaded(osmCore, True);
end;

procedure UnloadOpenSSLCore;
begin
  // P0-1.1: 委托给 TOpenSSLLoader 卸载库
  TOpenSSLLoader.UnloadLibraries;

  LoadedOpenSSLVersion := sslUnknown;
  LoadedCryptoLibName := '';
  LoadedSSLLibName := '';

  // Reset all function pointers
  OPENSSL_init_ssl := nil;
  OPENSSL_cleanup := nil;
  OpenSSL_version_num := nil;
  OpenSSL_version := nil;

  // Continue resetting all function pointers...
end;

function GetSSLLibHandle: TLibHandle;
begin
  // P0-1.1: 委托给 TOpenSSLLoader
  Result := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
end;

function GetCryptoLibHandle: TLibHandle;
begin
  // P0-1.1: 委托给 TOpenSSLLoader
  Result := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
end;

function GetCryptoProcAddress(const ProcName: string): Pointer;
var
  LHandle: TLibHandle;
begin
  Result := nil;
  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
  if LHandle <> NilHandle then
    Result := GetProcedureAddress(LHandle, PChar(ProcName));
end;

function GetSSLProcAddress(const ProcName: string): Pointer;
var
  LHandle: TLibHandle;
begin
  Result := nil;
  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);
  if LHandle <> NilHandle then
    Result := GetProcedureAddress(LHandle, PChar(ProcName));
end;

function GetOpenSSLVersion: TOpenSSLVersion;
begin
  Result := LoadedOpenSSLVersion;
end;

function GetOpenSSLVersionString: string;
begin
  case LoadedOpenSSLVersion of
    sslVersion_1_1: Result := '1.1.x';
    sslVersion_3_0: Result := '3.x';
  else
    Result := 'Unknown';
  end;
  
  if LoadedCryptoLibName <> '' then
    Result := Result + ' (' + LoadedCryptoLibName + ')';
end;

{ Helper functions for SSL_want macros }
{ In OpenSSL, SSL_want_read and SSL_want_write are often macros,
  so we implement them using SSL_want() }
function SSL_want_read_impl(const ssl: PSSL): Integer; cdecl;
begin
  Result := 0;
  if Assigned(SSL_want) then
    Result := Ord(SSL_want(ssl) = SSL_READING);
end;

function SSL_want_write_impl(const ssl: PSSL): Integer; cdecl;
begin
  Result := 0;
  if Assigned(SSL_want) then
    Result := Ord(SSL_want(ssl) = SSL_WRITING);
end;

{ Helper functions for SSL_CTX session cache mode }
{ In OpenSSL 3.x, these are macros that call SSL_CTX_ctrl }
function SSL_CTX_set_session_cache_mode_impl(ctx: PSSL_CTX; mode: clong): clong;
begin
  Result := 0;
  // 首先尝试直接函数调用
  if Assigned(SSL_CTX_set_session_cache_mode) then
    Result := SSL_CTX_set_session_cache_mode(ctx, mode)
  // 回退到 SSL_CTX_ctrl
  else if Assigned(SSL_CTX_ctrl) then
    Result := SSL_CTX_ctrl(ctx, SSL_CTRL_SET_SESS_CACHE_MODE, mode, nil);
end;

function SSL_CTX_get_session_cache_mode_impl(ctx: PSSL_CTX): clong;
begin
  Result := 0;
  // 首先尝试直接函数调用
  if Assigned(SSL_CTX_get_session_cache_mode) then
    Result := SSL_CTX_get_session_cache_mode(ctx)
  // 回退到 SSL_CTX_ctrl
  else if Assigned(SSL_CTX_ctrl) then
    Result := SSL_CTX_ctrl(ctx, SSL_CTRL_GET_SESS_CACHE_MODE, 0, nil);
end;

initialization

finalization
  UnloadOpenSSLCore;
  
end.
