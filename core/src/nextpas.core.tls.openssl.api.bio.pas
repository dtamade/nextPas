unit nextpas.core.tls.openssl.api.bio;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.base;

const
  BIO_FLAGS_BASE64_NO_NL = $100;

type
  { BIO Core Functions }
  TBIO_new = function(const &type: PBIO_METHOD): PBIO; cdecl;
  TBIO_new_ex = function(libctx: Pointer; const &type: PBIO_METHOD): PBIO; cdecl;
  TBIO_set = function(a: PBIO; const &type: PBIO_METHOD): Integer; cdecl;
  TBIO_set_ex_data = function(bio: PBIO; idx: Integer; data: Pointer): Integer; cdecl;
  TBIO_get_ex_data = function(const bio: PBIO; idx: Integer): Pointer; cdecl;
  TBIO_get_ex_new_index = function(argl: clong; argp: Pointer; new_func: TCRYPTO_EX_new; dup_func: TCRYPTO_EX_dup; free_func: TCRYPTO_EX_free): Integer; cdecl;
  TBIO_up_ref = function(a: PBIO): Integer; cdecl;
  TBIO_free = function(a: PBIO): Integer; cdecl;
  TBIO_free_all = procedure(a: PBIO); cdecl;
  TBIO_vfree = procedure(a: PBIO); cdecl;
  TBIO_read = function(b: PBIO; data: Pointer; dlen: Integer): Integer; cdecl;
  TBIO_read_ex = function(b: PBIO; data: Pointer; dlen: size_t; readbytes: Psize_t): Integer; cdecl;
  TBIO_gets = function(b: PBIO; buf: PAnsiChar; size: Integer): Integer; cdecl;
  TBIO_get_line = function(bio: PBIO; buf: PAnsiChar; size: Integer): Integer; cdecl;
  TBIO_write = function(b: PBIO; const data: Pointer; dlen: Integer): Integer; cdecl;
  TBIO_write_ex = function(b: PBIO; const data: Pointer; dlen: size_t; written: Psize_t): Integer; cdecl;
  TBIO_puts = function(b: PBIO; const buf: PAnsiChar): Integer; cdecl;
  TBIO_indent = function(b: PBIO; indent: Integer; max: Integer): Integer; cdecl;
  TBIO_ctrl = function(b: PBIO; cmd: Integer; larg: clong; parg: Pointer): clong; cdecl;
  TBIO_callback_ctrl = function(b: PBIO; cmd: Integer; fp: Pointer): clong; cdecl;
  TBIO_ptr_ctrl = function(b: PBIO; cmd: Integer; larg: clong): Pointer; cdecl;
  TBIO_int_ctrl = function(b: PBIO; cmd: Integer; larg: clong; iarg: Integer): clong; cdecl;
  TBIO_push = function(b: PBIO; append: PBIO): PBIO; cdecl;
  TBIO_pop = function(b: PBIO): PBIO; cdecl;
  TBIO_find_type = function(b: PBIO; bio_type: Integer): PBIO; cdecl;
  TBIO_next = function(b: PBIO): PBIO; cdecl;
  TBIO_set_next = procedure(b: PBIO; next: PBIO); cdecl;
  TBIO_get_retry_BIO = function(bio: PBIO; reason: PInteger): PBIO; cdecl;
  TBIO_get_retry_reason = function(bio: PBIO): Integer; cdecl;
  TBIO_set_retry_reason = procedure(bio: PBIO; reason: Integer); cdecl;
  TBIO_dup_chain = function(&in: PBIO): PBIO; cdecl;
  
  TBIO_nread0 = function(bio: PBIO; buf: PPAnsiChar): Integer; cdecl;
  TBIO_nread = function(bio: PBIO; buf: PPAnsiChar; num: Integer): Integer; cdecl;
  TBIO_nwrite0 = function(bio: PBIO; buf: PPAnsiChar): Integer; cdecl;
  TBIO_nwrite = function(bio: PBIO; buf: PPAnsiChar; num: Integer): Integer; cdecl;
  
  TBIO_debug_callback_ex = function(bio: PBIO; cmd: Integer; argp: PAnsiChar; len: size_t; argi: Integer; argl: clong; ret: Integer; processed: Psize_t): clong; cdecl;
  TBIO_debug_callback = function(bio: PBIO; cmd: Integer; argp: PAnsiChar; argi: Integer; argl: clong; ret: clong): clong; cdecl;
  
  { BIO Method Functions }
  TBIO_get_new_index = function: Integer; cdecl;
  TBIO_meth_new = function(bio_type: Integer; const name: PAnsiChar): PBIO_METHOD; cdecl;
  TBIO_meth_free = procedure(biom: PBIO_METHOD); cdecl;
  TBIO_meth_get_write = function(biom: PBIO_METHOD): Pointer; cdecl;
  TBIO_meth_get_write_ex = function(biom: PBIO_METHOD): Pointer; cdecl;
  TBIO_meth_set_write = function(biom: PBIO_METHOD; write: Pointer): Integer; cdecl;
  TBIO_meth_set_write_ex = function(biom: PBIO_METHOD; write: Pointer): Integer; cdecl;
  TBIO_meth_get_read = function(biom: PBIO_METHOD): Pointer; cdecl;
  TBIO_meth_get_read_ex = function(biom: PBIO_METHOD): Pointer; cdecl;
  TBIO_meth_set_read = function(biom: PBIO_METHOD; read: Pointer): Integer; cdecl;
  TBIO_meth_set_read_ex = function(biom: PBIO_METHOD; read: Pointer): Integer; cdecl;
  TBIO_meth_get_puts = function(biom: PBIO_METHOD): Pointer; cdecl;
  TBIO_meth_set_puts = function(biom: PBIO_METHOD; puts: Pointer): Integer; cdecl;
  TBIO_meth_get_gets = function(biom: PBIO_METHOD): Pointer; cdecl;
  TBIO_meth_set_gets = function(biom: PBIO_METHOD; gets: Pointer): Integer; cdecl;
  TBIO_meth_get_ctrl = function(biom: PBIO_METHOD): Pointer; cdecl;
  TBIO_meth_set_ctrl = function(biom: PBIO_METHOD; ctrl: Pointer): Integer; cdecl;
  TBIO_meth_get_create = function(biom: PBIO_METHOD): Pointer; cdecl;
  TBIO_meth_set_create = function(biom: PBIO_METHOD; create: Pointer): Integer; cdecl;
  TBIO_meth_get_destroy = function(biom: PBIO_METHOD): Pointer; cdecl;
  TBIO_meth_set_destroy = function(biom: PBIO_METHOD; destroy: Pointer): Integer; cdecl;
  TBIO_meth_get_callback_ctrl = function(biom: PBIO_METHOD): Pointer; cdecl;
  TBIO_meth_set_callback_ctrl = function(biom: PBIO_METHOD; callback_ctrl: Pointer): Integer; cdecl;
  
  { BIO Type Methods }
  TBIO_s_file = function: PBIO_METHOD; cdecl;
  TBIO_new_file = function(const filename: PAnsiChar; const mode: PAnsiChar): PBIO; cdecl;
  TBIO_new_fp = function(stream: Pointer; close_flag: Integer): PBIO; cdecl;
  TBIO_s_mem = function: PBIO_METHOD; cdecl;
  TBIO_s_secmem = function: PBIO_METHOD; cdecl;
  TBIO_new_mem_buf = function(const buf: Pointer; len: Integer): PBIO; cdecl;
  TBIO_s_socket = function: PBIO_METHOD; cdecl;
  TBIO_s_connect = function: PBIO_METHOD; cdecl;
  TBIO_s_accept = function: PBIO_METHOD; cdecl;
  TBIO_s_fd = function: PBIO_METHOD; cdecl;
  TBIO_s_log = function: PBIO_METHOD; cdecl;
  TBIO_s_bio = function: PBIO_METHOD; cdecl;
  TBIO_s_null = function: PBIO_METHOD; cdecl;
  TBIO_f_null = function: PBIO_METHOD; cdecl;
  TBIO_f_buffer = function: PBIO_METHOD; cdecl;
  TBIO_f_readbuffer = function: PBIO_METHOD; cdecl;
  TBIO_f_linebuffer = function: PBIO_METHOD; cdecl;
  TBIO_f_nbio_test = function: PBIO_METHOD; cdecl;
  TBIO_f_prefix = function: PBIO_METHOD; cdecl;
  TBIO_s_datagram = function: PBIO_METHOD; cdecl;
  TBIO_dgram_non_fatal_error = function(error: Integer): Integer; cdecl;
  TBIO_new_dgram = function(fd: Integer; close_flag: Integer): PBIO; cdecl;
  TBIO_s_datagram_sctp = function: PBIO_METHOD; cdecl;
  TBIO_new_dgram_sctp = function(fd: Integer; close_flag: Integer): PBIO; cdecl;
  TBIO_dgram_is_sctp = function(bio: PBIO): Integer; cdecl;
  TBIO_dgram_sctp_notification_cb = function(bio: PBIO; handle_notifications: Pointer; context: Pointer): Integer; cdecl;
  TBIO_dgram_sctp_wait_for_dry = function(b: PBIO): Integer; cdecl;
  TBIO_dgram_sctp_msg_waiting = function(b: PBIO): Integer; cdecl;
  
  { SSL_SESSION BIO Functions }
  Ti2d_SSL_SESSION_bio = function(bp: PBIO; x: PSSL_SESSION): Integer; cdecl;
  Td2i_SSL_SESSION_bio = function(bp: PBIO; x: PPSSL_SESSION): PSSL_SESSION; cdecl;
  
  { BIO Socket Functions }
  TBIO_sock_should_retry = function(i: Integer): Integer; cdecl;
  TBIO_sock_non_fatal_error = function(error: Integer): Integer; cdecl;
  TBIO_socket_wait = function(fd: Integer; for_read: Integer; max_time: time_t): Integer; cdecl;
  TBIO_wait = function(bio: PBIO; max_time: time_t; nap_milliseconds: Cardinal): Integer; cdecl;
  TBIO_do_connect_retry = function(bio: PBIO; timeout: Integer; nap_milliseconds: Integer): Integer; cdecl;
  
  TBIO_fd_should_retry = function(i: Integer): Integer; cdecl;
  TBIO_fd_non_fatal_error = function(error: Integer): Integer; cdecl;
  TBIO_dump_cb = function(data: Pointer; len: size_t; &out: Pointer): Integer; cdecl;
  TBIO_dump_indent_cb = function(data: Pointer; len: size_t; &out: Pointer; indent: Integer): Integer; cdecl;
  TBIO_dump = function(b: PBIO; const bytes: PAnsiChar; len: Integer): Integer; cdecl;
  TBIO_dump_indent = function(b: PBIO; const bytes: PAnsiChar; len: Integer; indent: Integer): Integer; cdecl;
  TBIO_dump_fp = function(fp: Pointer; const s: PAnsiChar; len: Integer): Integer; cdecl;
  TBIO_dump_indent_fp = function(fp: Pointer; const s: PAnsiChar; len: Integer; indent: Integer): Integer; cdecl;
  TBIO_hex_string = function(&out: PBIO; indent: Integer; width: Integer; data: PByte; datalen: Integer): Integer; cdecl;
  
  { BIO_ADDR Functions }
  TBIO_ADDR_new = function: Pointer; cdecl;
  TBIO_ADDR_free = procedure(a: Pointer); cdecl;
  TBIO_ADDR_clear = procedure(ap: Pointer); cdecl;
  TBIO_ADDR_family = function(const ap: Pointer): Integer; cdecl;
  TBIO_ADDR_rawmake = function(ap: Pointer; family: Integer; const where: Pointer; wherelen: size_t; port: UInt16): Integer; cdecl;
  TBIO_ADDR_rawaddress = function(const ap: Pointer; p: Pointer; l: Psize_t): Integer; cdecl;
  TBIO_ADDR_rawport = function(const ap: Pointer): UInt16; cdecl;
  TBIO_ADDR_hostname_string = function(const ap: Pointer; numeric: Integer): PAnsiChar; cdecl;
  TBIO_ADDR_service_string = function(const ap: Pointer; numeric: Integer): PAnsiChar; cdecl;
  TBIO_ADDR_sockaddr = function(const ap: Pointer): Pointer; cdecl;
  TBIO_ADDR_sockaddr_noconst = function(ap: Pointer): Pointer; cdecl;
  TBIO_ADDR_sockaddr_size = function(const ap: Pointer): Integer; cdecl;
  TBIO_ADDR_path_string = function(const ap: Pointer): PAnsiChar; cdecl;
  
  { BIO_ADDRINFO Functions }
  TBIO_ADDRINFO_next = function(const bai: Pointer): Pointer; cdecl;
  TBIO_ADDRINFO_family = function(const bai: Pointer): Integer; cdecl;
  TBIO_ADDRINFO_socktype = function(const bai: Pointer): Integer; cdecl;
  TBIO_ADDRINFO_protocol = function(const bai: Pointer): Integer; cdecl;
  TBIO_ADDRINFO_address = function(const bai: Pointer): Pointer; cdecl;
  TBIO_ADDRINFO_free = procedure(bai: Pointer); cdecl;
  TBIO_parse_hostserv = function(const hostserv: PAnsiChar; host: PPAnsiChar; service: PPAnsiChar; hostserv_prio: Integer): Integer; cdecl;
  TBIO_lookup = function(const host: PAnsiChar; const service: PAnsiChar; lookup_type: Integer; family: Integer; socktype: Integer; res: PPointer): Integer; cdecl;
  TBIO_lookup_ex = function(const host: PAnsiChar; const service: PAnsiChar; lookup_type: Integer; family: Integer; socktype: Integer; protocol: Integer; res: PPointer): Integer; cdecl;
  
  { BIO Socket Creation Functions }
  TBIO_socket = function(domain: Integer; socktype: Integer; protocol: Integer; options: Integer): Integer; cdecl;
  TBIO_socket_ioctl = function(fd: Integer; &type: clong; arg: Pointer): Integer; cdecl;
  TBIO_socket_nbio = function(fd: Integer; mode: Integer): Integer; cdecl;
  TBIO_sock_init = function: Integer; cdecl;
  TBIO_set_tcp_ndelay = function(sock: Integer; turn_on: Integer): Integer; cdecl;
  
  TBIO_sock_info = function(sock: Integer; &type: Integer; info: PPointer): Integer; cdecl;
  // TBIO_socket_wait already defined above at line 112
  TBIO_connect = function(sock: Integer; const addr: Pointer; options: Integer): Integer; cdecl;
  TBIO_bind = function(sock: Integer; const addr: Pointer; options: Integer): Integer; cdecl;
  TBIO_listen = function(sock: Integer; const addr: Pointer; options: Integer): Integer; cdecl;
  TBIO_accept_ex = function(accept_sock: Integer; addr: Pointer; options: Integer): Integer; cdecl;
  TBIO_closesocket = function(sock: Integer): Integer; cdecl;
  
  { BIO Pair Functions }
  TBIO_new_bio_pair = function(bio1: PPBIO; writebuf1: size_t; bio2: PPBIO; writebuf2: size_t): Integer; cdecl;
  TBIO_new_bio_dgram_pair = function(bio1: PPBIO; writebuf1: size_t; bio2: PPBIO; writebuf2: size_t): Integer; cdecl;
  
  { BIO Copy Functions }
  TBIO_copy_next_retry = procedure(b: PBIO); cdecl;
  
  { BIO Printf Functions }
  TBIO_printf = function(bio: PBIO; const format: PAnsiChar): Integer; cdecl; varargs;
  TBIO_vprintf = function(bio: PBIO; const format: PAnsiChar; args: Pointer): Integer; cdecl;
  TBIO_snprintf = function(buf: PAnsiChar; n: size_t; const format: PAnsiChar): Integer; cdecl; varargs;
  TBIO_vsnprintf = function(buf: PAnsiChar; n: size_t; const format: PAnsiChar; args: Pointer): Integer; cdecl;
  
  { BIO Memory Functions }
  TBUF_MEM_new = function: Pointer; cdecl;
  TBUF_MEM_new_ex = function(flags: LongWord): Pointer; cdecl;
  TBUF_MEM_free = procedure(a: Pointer); cdecl;
  TBUF_MEM_grow = function(str: Pointer; len: size_t): size_t; cdecl;
  TBUF_MEM_grow_clean = function(str: Pointer; len: size_t): size_t; cdecl;
  TBUF_strlcpy = function(dst: PAnsiChar; const src: PAnsiChar; siz: size_t): size_t; cdecl;
  TBUF_strlcat = function(dst: PAnsiChar; const src: PAnsiChar; siz: size_t): size_t; cdecl;
  TBUF_strnlen = function(const str: PAnsiChar; maxlen: size_t): size_t; cdecl;
  TBUF_strdup = function(const str: PAnsiChar): PAnsiChar; cdecl;
  TBUF_strndup = function(const str: PAnsiChar; siz: size_t): PAnsiChar; cdecl;
  TBUF_memdup = function(const data: Pointer; siz: size_t): Pointer; cdecl;
  TBUF_reverse = procedure(&out: PByte; const &in: PByte; size: size_t); cdecl;
  
  { BIO Utility Functions }
  TERR_print_errors = procedure(bp: PBIO); cdecl;
  TERR_print_errors_cb = procedure(cb: Pointer; u: Pointer); cdecl;
  TERR_print_errors_fp = procedure(fp: Pointer); cdecl;
  
  { BIO Get/Set Functions }
  TBIO_get_flags = function(const b: PBIO): Integer; cdecl;
  TBIO_set_flags = procedure(b: PBIO; flags: Integer); cdecl;
  TBIO_test_flags = function(const b: PBIO; flags: Integer): Integer; cdecl;
  TBIO_clear_flags = procedure(b: PBIO; flags: Integer); cdecl;
  
  TBIO_get_callback = function(const b: PBIO): TBIO_callback_fn; cdecl;
  TBIO_set_callback = procedure(b: PBIO; callback: TBIO_callback_fn); cdecl;
  TBIO_get_callback_ex = function(const b: PBIO): TBIO_callback_fn_ex; cdecl;
  TBIO_set_callback_ex = procedure(b: PBIO; callback: TBIO_callback_fn_ex); cdecl;
  TBIO_get_callback_arg = function(const b: PBIO): PAnsiChar; cdecl;
  TBIO_set_callback_arg = procedure(b: PBIO; arg: PAnsiChar); cdecl;
  
  TBIO_get_close = function(b: PBIO): Integer; cdecl;
  TBIO_set_close = function(b: PBIO; close_flag: Integer): Integer; cdecl;
  TBIO_get_shutdown = function(b: PBIO): Integer; cdecl;
  TBIO_set_shutdown = procedure(b: PBIO; shut: Integer); cdecl;
  
  TBIO_get_init = function(b: PBIO): Integer; cdecl;
  TBIO_set_init = procedure(b: PBIO; init: Integer); cdecl;
  TBIO_get_data = function(b: PBIO): Pointer; cdecl;
  TBIO_set_data = procedure(b: PBIO; data: Pointer); cdecl;
  TBIO_get_num = function(b: PBIO): Integer; cdecl;
  TBIO_set_num = procedure(b: PBIO; num: Integer); cdecl;
  TBIO_get_fd = function(b: PBIO; c: PInteger): Integer; cdecl;
  TBIO_set_fd = function(b: PBIO; fd: Integer; c: Integer): Integer; cdecl;
  
  { BIO Control Macros as Functions }
  TBIO_reset = function(b: PBIO): Integer; cdecl;
  TBIO_eof = function(b: PBIO): Integer; cdecl;
  TBIO_pending = function(b: PBIO): Integer; cdecl;
  TBIO_wpending = function(b: PBIO): Integer; cdecl;
  TBIO_flush = function(b: PBIO): Integer; cdecl;
  TBIO_get_info_callback = function(b: PBIO; cbp: PPBIO_info_cb): Integer; cdecl;
  TBIO_set_info_callback = function(b: PBIO; cb: TBIO_info_cb): Integer; cdecl;
  TBIO_buffer_get_num_lines = function(b: PBIO): Integer; cdecl;
  TBIO_buffer_peek = function(b: PBIO; s: PAnsiChar; size: Integer): Integer; cdecl;
  
  TBIO_set_write_buffer_size = function(b: PBIO; size: clong): clong; cdecl;
  TBIO_get_write_buffer_size = function(b: PBIO; size: Pclong): clong; cdecl;
  TBIO_make_bio_pair = function(b1: PBIO; b2: PBIO): Integer; cdecl;
  TBIO_destroy_bio_pair = function(b: PBIO): Integer; cdecl;
  TBIO_shutdown_wr = function(b: PBIO): Integer; cdecl;
  
  TBIO_set_write_buf_size = function(b: PBIO; size: clong): Integer; cdecl;
  
  { BIO Socket Helper Functions }
  TBIO_new_accept = function(host_port: PAnsiChar): PBIO; cdecl;
  TBIO_new_connect = function(host_port: PAnsiChar): PBIO; cdecl;
  TBIO_do_accept = function(b: PBIO): Integer; cdecl;
  TBIO_do_connect = function(b: PBIO): Integer; cdecl;
  TBIO_get_write_buf_size = function(b: PBIO; size: Pclong): Integer; cdecl;
  TBIO_new_fd = function(fd: Integer; close_flag: Integer): PBIO; cdecl;
  TBIO_new_socket = function(sock: Integer; close_flag: Integer): PBIO; cdecl;
  
  TBIO_tell = function(b: PBIO): Integer; cdecl;
  TBIO_seek = function(b: PBIO; ofs: Integer): Integer; cdecl;
  TBIO_get_mem_data = function(b: PBIO; pp: PPAnsiChar): Integer; cdecl;
  TBIO_set_mem_buf = function(b: PBIO; bm: Pointer; c: Integer): Integer; cdecl;
  TBIO_get_mem_ptr = function(b: PBIO; pp: PPointer): Integer; cdecl;
  TBIO_set_mem_eof_return = function(b: PBIO; v: Integer): Integer; cdecl;
  
  { Cipher BIO Functions }
  TBIO_f_cipher = function: PBIO_METHOD; cdecl;
  TBIO_set_cipher = function(b: PBIO; c: PEVP_CIPHER; const k: PByte; const i: PByte; enc: Integer): Integer; cdecl;
  TBIO_get_cipher_status = function(b: PBIO): Integer; cdecl;
  TBIO_get_cipher_ctx = function(b: PBIO; c_ctx: PPEVP_CIPHER_CTX): Integer; cdecl;
  
  { MD BIO Functions }
  TBIO_f_md = function: PBIO_METHOD; cdecl;
  TBIO_set_md = function(b: PBIO; md: PEVP_MD): Integer; cdecl;
  TBIO_get_md = function(b: PBIO; mdp: PPEVP_MD): Integer; cdecl;
  TBIO_get_md_ctx = function(b: PBIO; mdcp: PPEVP_MD_CTX): Integer; cdecl;
  
  { Base64 BIO Functions }
  TBIO_f_base64 = function: PBIO_METHOD; cdecl;
  
  { SSL BIO Functions }
  TBIO_f_ssl = function: PBIO_METHOD; cdecl;
  TBIO_new_ssl = function(ctx: PSSL_CTX; client: Integer): PBIO; cdecl;
  TBIO_new_ssl_connect = function(ctx: PSSL_CTX): PBIO; cdecl;
  TBIO_new_buffer_ssl_connect = function(ctx: PSSL_CTX): PBIO; cdecl;
  TBIO_ssl_copy_session_id = function(&to: PBIO; from: PBIO): Integer; cdecl;
  TBIO_ssl_shutdown = procedure(ssl: PBIO); cdecl;

var
  // Function pointers will be dynamically loaded
  // This is a partial list - complete implementation would include all functions
  BIO_new: TBIO_new = nil;
  BIO_free: TBIO_free = nil;
  BIO_set_fd: TBIO_set_fd = nil;
  // BIO_get_fd is implemented as a function wrapper
  
  BIO_new_accept: TBIO_new_accept = nil;
  BIO_new_connect: TBIO_new_connect = nil;
  // BIO_do_accept and BIO_do_connect are helpers
  
  BIO_reset: TBIO_reset = nil;
  BIO_ctrl: TBIO_ctrl = nil;
  BIO_s_mem: TBIO_s_mem = nil;
  BIO_new_mem_buf: TBIO_new_mem_buf = nil;
  BIO_new_file: TBIO_new_file = nil;
  BIO_s_file: TBIO_s_file = nil;
  BIO_s_null: TBIO_s_null = nil;
  // BIO_get_mem_data is a macro implemented as helper
  BIO_s_connect: TBIO_s_connect = nil;
  BIO_pending: TBIO_pending = nil;
  BIO_push: TBIO_push = nil;
  BIO_f_base64: TBIO_f_base64 = nil;
  BIO_new_socket: TBIO_new_socket = nil;
  BIO_new_bio_pair: TBIO_new_bio_pair = nil;

  // SSL BIO functions (libssl)
  BIO_f_ssl: TBIO_f_ssl = nil;
  BIO_new_ssl: TBIO_new_ssl = nil;
  BIO_new_ssl_connect: TBIO_new_ssl_connect = nil;
  BIO_new_buffer_ssl_connect: TBIO_new_buffer_ssl_connect = nil;
  BIO_ssl_copy_session_id: TBIO_ssl_copy_session_id = nil;
  BIO_ssl_shutdown: TBIO_ssl_shutdown = nil;
  
  // Missing variables
  BIO_free_all: TBIO_free_all = nil;
  BIO_read: TBIO_read = nil;
  BIO_write: TBIO_write = nil;
  BIO_pop: TBIO_pop = nil;
  BIO_s_accept: TBIO_s_accept = nil;
  
  // SSL_SESSION BIO functions  
  i2d_SSL_SESSION_bio: Ti2d_SSL_SESSION_bio = nil;
  d2i_SSL_SESSION_bio: Td2i_SSL_SESSION_bio = nil;
  
procedure LoadOpenSSLBIO;
procedure UnloadOpenSSLBIO;

{ Helper functions for BIO connection operations }
function BIO_set_conn_hostname(b: PBIO; const hostname: PAnsiChar): clong;
function BIO_set_conn_port(b: PBIO; const port: PAnsiChar): clong;
function BIO_do_connect(b: PBIO): clong;
function BIO_get_ssl(b: PBIO; sslp: PPSSL): clong;

{ BIO_pending is a macro in OpenSSL, not a real function }
function BIO_pending_impl(b: PBIO): Integer; cdecl;

{ BIO_set_flags is a macro in OpenSSL }
procedure BIO_set_flags(b: PBIO; flags: Integer); cdecl;

{ BIO_flush is a macro in OpenSSL }
function BIO_flush(b: PBIO): Integer; cdecl;

{ BIO_get_mem_data is a macro in OpenSSL }
function BIO_get_mem_data(b: PBIO; pp: PPAnsiChar): Integer; cdecl;

implementation

uses nextpas.core.tls.openssl.api.core,
  nextpas.core.platform.dl;

procedure LoadOpenSSLBIO;
var
  LibSSL, LibCrypto: TPlatformLibrary;
begin
  // Make sure core is loaded first
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    LoadOpenSSLCore;

  // Get handles from core module
  LibSSL := GetSSLLibHandle;
  LibCrypto := GetCryptoLibHandle;

  if not LibLoaded(LibSSL) or not LibLoaded(LibCrypto) then
    Exit;

  // Load function pointers - most BIO functions are in libcrypto
  BIO_new := TBIO_new(GetProcSymbol(LibCrypto, 'BIO_new'));
  BIO_free := TBIO_free(GetProcSymbol(LibCrypto, 'BIO_free'));
  BIO_free_all := TBIO_free_all(GetProcSymbol(LibCrypto, 'BIO_free_all'));
  BIO_read := TBIO_read(GetProcSymbol(LibCrypto, 'BIO_read'));
  BIO_write := TBIO_write(GetProcSymbol(LibCrypto, 'BIO_write'));
  BIO_ctrl := TBIO_ctrl(GetProcSymbol(LibCrypto, 'BIO_ctrl'));
  BIO_s_mem := TBIO_s_mem(GetProcSymbol(LibCrypto, 'BIO_s_mem'));
  BIO_new_mem_buf := TBIO_new_mem_buf(GetProcSymbol(LibCrypto, 'BIO_new_mem_buf'));
  BIO_new_file := TBIO_new_file(GetProcSymbol(LibCrypto, 'BIO_new_file'));
  BIO_s_file := TBIO_s_file(GetProcSymbol(LibCrypto, 'BIO_s_file'));
  BIO_s_null := TBIO_s_null(GetProcSymbol(LibCrypto, 'BIO_s_null'));
  // BIO_get_mem_data is a macro
  BIO_new_connect := TBIO_new_connect(GetProcSymbol(LibCrypto, 'BIO_new_connect'));
  BIO_new_accept := TBIO_new_accept(GetProcSymbol(LibCrypto, 'BIO_new_accept'));
  BIO_s_connect := TBIO_s_connect(GetProcSymbol(LibCrypto, 'BIO_s_connect'));
  BIO_s_accept := TBIO_s_accept(GetProcSymbol(LibCrypto, 'BIO_s_accept'));
  BIO_push := TBIO_push(GetProcSymbol(LibCrypto, 'BIO_push'));
  BIO_pop := TBIO_pop(GetProcSymbol(LibCrypto, 'BIO_pop'));
  BIO_f_base64 := TBIO_f_base64(GetProcSymbol(LibCrypto, 'BIO_f_base64'));
  BIO_new_bio_pair := TBIO_new_bio_pair(GetProcSymbol(LibCrypto, 'BIO_new_bio_pair'));

  // SSL BIO functions (in libssl)
  BIO_f_ssl := TBIO_f_ssl(GetProcSymbol(LibSSL, 'BIO_f_ssl'));
  BIO_new_ssl := TBIO_new_ssl(GetProcSymbol(LibSSL, 'BIO_new_ssl'));
  BIO_new_ssl_connect := TBIO_new_ssl_connect(GetProcSymbol(LibSSL, 'BIO_new_ssl_connect'));
  BIO_new_buffer_ssl_connect := TBIO_new_buffer_ssl_connect(GetProcSymbol(LibSSL, 'BIO_new_buffer_ssl_connect'));
  BIO_ssl_copy_session_id := TBIO_ssl_copy_session_id(GetProcSymbol(LibSSL, 'BIO_ssl_copy_session_id'));
  BIO_ssl_shutdown := TBIO_ssl_shutdown(GetProcSymbol(LibSSL, 'BIO_ssl_shutdown'));

  // BIO_pending is a macro in OpenSSL, use our helper implementation
  BIO_pending := @BIO_pending_impl;

  // SSL_SESSION BIO functions (in libssl, not libcrypto)
  i2d_SSL_SESSION_bio := Ti2d_SSL_SESSION_bio(GetProcSymbol(LibSSL, 'i2d_SSL_SESSION_bio'));
  d2i_SSL_SESSION_bio := Td2i_SSL_SESSION_bio(GetProcSymbol(LibSSL, 'd2i_SSL_SESSION_bio'));

  // Mark module as loaded
  TOpenSSLLoader.SetModuleLoaded(osmBIO, Assigned(BIO_new) and Assigned(BIO_free));
end;

procedure UnloadOpenSSLBIO;
begin
  // Reset all function pointers
  BIO_new := nil;
  BIO_free := nil;
  BIO_free_all := nil;
  BIO_read := nil;
  BIO_write := nil;
  BIO_ctrl := nil;
  BIO_s_mem := nil;
  BIO_new_mem_buf := nil;
  BIO_new_file := nil;
  BIO_s_file := nil;
  BIO_s_null := nil;
  // BIO_get_mem_data := nil;
  BIO_new_connect := nil;
  BIO_new_accept := nil;
  BIO_s_connect := nil;
  BIO_s_accept := nil;
  BIO_push := nil;
  BIO_pop := nil;
  BIO_f_base64 := nil;
  BIO_new_bio_pair := nil;

  BIO_f_ssl := nil;
  BIO_new_ssl := nil;
  BIO_new_ssl_connect := nil;
  BIO_new_buffer_ssl_connect := nil;
  BIO_ssl_copy_session_id := nil;
  BIO_ssl_shutdown := nil;

  // Mark module as unloaded
  TOpenSSLLoader.SetModuleLoaded(osmBIO, False);
end;


{ Helper functions for BIO connection operations }
function BIO_set_conn_hostname(b: PBIO; const hostname: PAnsiChar): clong;
const
  BIO_C_SET_CONNECT = 100;
begin
  if Assigned(BIO_ctrl) then
    Result := BIO_ctrl(b, BIO_C_SET_CONNECT, 0, Pointer(hostname))
  else
    Result := -1;
end;

function BIO_set_conn_port(b: PBIO; const port: PAnsiChar): clong;
const
  BIO_C_SET_CONNECT = 100;
begin
  if Assigned(BIO_ctrl) then
    Result := BIO_ctrl(b, BIO_C_SET_CONNECT, 1, Pointer(port))
  else
    Result := -1;
end;

function BIO_do_connect(b: PBIO): clong;
const
  BIO_C_DO_STATE_MACHINE = 101;
begin
  if Assigned(BIO_ctrl) then
    Result := BIO_ctrl(b, BIO_C_DO_STATE_MACHINE, 0, nil)
  else
    Result := -1;
end;

function BIO_get_ssl(b: PBIO; sslp: PPSSL): clong;
const
  BIO_C_GET_SSL = 110;
begin
  if Assigned(BIO_ctrl) then
    Result := BIO_ctrl(b, BIO_C_GET_SSL, 0, Pointer(sslp))
  else
    Result := -1;
end;

{ BIO_pending is a macro in OpenSSL: #define BIO_pending(b) (int)BIO_ctrl(b,BIO_CTRL_PENDING,0,NULL) }
function BIO_pending_impl(b: PBIO): Integer; cdecl;
const
  BIO_CTRL_PENDING = 10;
begin
  if Assigned(BIO_ctrl) then
    Result := Integer(BIO_ctrl(b, BIO_CTRL_PENDING, 0, nil))
  else
    Result := 0;
end;

{ BIO_set_flags is a macro in OpenSSL: #define BIO_set_flags(b,f) BIO_ctrl(b,BIO_CTRL_SET,f,NULL) }
procedure BIO_set_flags(b: PBIO; flags: Integer); cdecl;
const
  BIO_CTRL_SET = 104; // From bio.h
begin
  if Assigned(BIO_ctrl) then
    BIO_ctrl(b, BIO_CTRL_SET, flags, nil);
end;

{ BIO_flush is a macro in OpenSSL: #define BIO_flush(b) (int)BIO_ctrl(b,BIO_CTRL_FLUSH,0,NULL) }
function BIO_flush(b: PBIO): Integer; cdecl;
const
  BIO_CTRL_FLUSH = 11;
begin
  if Assigned(BIO_ctrl) then
    Result := Integer(BIO_ctrl(b, BIO_CTRL_FLUSH, 0, nil))
  else
    Result := 0;
end;

{ BIO_get_mem_data is a macro in OpenSSL: #define BIO_get_mem_data(b,pp) BIO_ctrl(b,BIO_CTRL_INFO,0,(char *)pp) }
function BIO_get_mem_data(b: PBIO; pp: PPAnsiChar): Integer; cdecl;
const
  BIO_CTRL_INFO = 3;
begin
  if Assigned(BIO_ctrl) then
    Result := Integer(BIO_ctrl(b, BIO_CTRL_INFO, 0, Pointer(pp)))
  else
    Result := 0;
end;

{ BIO_get_fd is a macro in OpenSSL: #define BIO_get_fd(b,c) BIO_ctrl(b,BIO_C_GET_FD,0,(char *)c) }
function BIO_get_fd(b: PBIO; c: PInteger): Integer; cdecl;
const
  BIO_C_GET_FD = 105;
begin
  if Assigned(BIO_ctrl) then
    Result := Integer(BIO_ctrl(b, BIO_C_GET_FD, 0, Pointer(c)))
  else
    Result := -1;
end;

{ BIO_do_accept is a macro in OpenSSL: #define BIO_do_accept(b) BIO_ctrl(b,BIO_C_DO_STATE_MACHINE,0,NULL) }
function BIO_do_accept(b: PBIO): Integer; cdecl;
const
  BIO_C_DO_STATE_MACHINE = 101;
begin
  if Assigned(BIO_ctrl) then
    Result := Integer(BIO_ctrl(b, BIO_C_DO_STATE_MACHINE, 0, nil))
  else
    Result := -1;
end;

end.
