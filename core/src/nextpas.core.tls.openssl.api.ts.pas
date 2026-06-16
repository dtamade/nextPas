{
  OpenSSL TS (时间�? API 模块
  用于 RFC 3161 时间戳协议支�?
}
unit nextpas.core.tls.openssl.api.ts;

{$mode ObjFPC}{$H+}

interface

uses SysUtils, nextpas.core.tls.openssl.api, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.bio, nextpas.core.tls.openssl.api.x509, nextpas.core.tls.openssl.api.asn1, nextpas.core.tls.openssl.api.obj, nextpas.core.tls.openssl.api.evp, nextpas.core.tls.openssl.api.bn, nextpas.core.tls.openssl.api.rand;

const
  // TS 消息类型
  TS_MSG_IMPRINT_FLAG_DIGEST = $01;
  TS_MSG_IMPRINT_FLAG_MSG = $02;
  
  // TS 状态码
  TS_STATUS_GRANTED = 0;
  TS_STATUS_GRANTED_WITH_MODS = 1;
  TS_STATUS_REJECTION = 2;
  TS_STATUS_WAITING = 3;
  TS_STATUS_REVOCATION_WARNING = 4;
  TS_STATUS_REVOCATION_NOTIFICATION = 5;
  
  // TS 信息标志
  TS_INFO_ALL = $FFFF;
  TS_INFO_VERSION = $0001;
  TS_INFO_POLICY = $0002;
  TS_INFO_IMPRINT = $0004;
  TS_INFO_SERIAL = $0008;
  TS_INFO_TIME = $0010;
  TS_INFO_ACCURACY = $0020;
  TS_INFO_ORDERING = $0040;
  TS_INFO_NONCE = $0080;
  TS_INFO_TSA = $0100;
  TS_INFO_EXTENSIONS = $0200;
  
  // TS 精度标志
  TS_ACCURACY_SECONDS = $01;
  TS_ACCURACY_MILLIS = $02;
  TS_ACCURACY_MICROS = $04;
  
  // TS 验证标志
  TS_VFY_VERSION = $01;
  TS_VFY_POLICY = $02;
  TS_VFY_IMPRINT = $04;
  TS_VFY_DATA = $08;
  TS_VFY_NONCE = $10;
  TS_VFY_SIGNER = $20;
  TS_VFY_TSA_NAME = $40;
  TS_VFY_SIGNATURE = $80;
  TS_VFY_ALL_IMPRINT = (TS_VFY_IMPRINT or TS_VFY_DATA);
  TS_VFY_ALL_DATA = (TS_VFY_VERSION or TS_VFY_POLICY or TS_VFY_IMPRINT or 
                    TS_VFY_DATA or TS_VFY_NONCE or TS_VFY_TSA_NAME);

type
  // 前向声明
  PTS_MSG_IMPRINT = ^TS_MSG_IMPRINT;
  PTS_REQ = ^TS_REQ;
  PPTS_REQ = ^PTS_REQ;
  PTS_ACCURACY = ^TS_ACCURACY;
  PTS_TST_INFO = ^TS_TST_INFO;
  PPTS_TST_INFO = ^PTS_TST_INFO;
  PTS_STATUS_INFO = ^TS_STATUS_INFO;
  PTS_RESP = ^TS_RESP;
  PPTS_RESP = ^PTS_RESP;
  PTS_RESP_CTX = ^TS_RESP_CTX;
  PTS_VERIFY_CTX = ^TS_VERIFY_CTX;
  
  // Stack type
  PSTACK_OF_ASN1_UTF8STRING = POPENSSL_STACK;
  
  // 不透明结构�?
  TS_MSG_IMPRINT = record end;
  TS_REQ = record end;
  TS_ACCURACY = record end;
  TS_TST_INFO = record end;
  TS_STATUS_INFO = record end;
  TS_RESP = record end;
  TS_RESP_CTX = record end;
  TS_VERIFY_CTX = record end;
  
  // 回调函数类型
  TS_serial_cb = function(ctx: PTS_RESP_CTX; serial: PASN1_INTEGER): Integer; cdecl;
  TS_time_cb = function(ctx: PTS_RESP_CTX; sec: PInt64; usec: PInt64): Integer; cdecl;
  TS_extension_cb = function(ctx: PTS_RESP_CTX; ext: PX509_EXTENSION; 
                            is_critical: Integer): Integer; cdecl;

  // TS 函数指针类型
  
  // TS_MSG_IMPRINT 函数
  TTS_MSG_IMPRINT_new = function(): PTS_MSG_IMPRINT; cdecl;
  TTS_MSG_IMPRINT_free = procedure(a: PTS_MSG_IMPRINT); cdecl;
  TTS_MSG_IMPRINT_dup = function(a: PTS_MSG_IMPRINT): PTS_MSG_IMPRINT; cdecl;
  TTS_MSG_IMPRINT_set_algo = function(a: PTS_MSG_IMPRINT; alg: PX509_ALGOR): Integer; cdecl;
  TTS_MSG_IMPRINT_get_algo = function(a: PTS_MSG_IMPRINT): PX509_ALGOR; cdecl;
  TTS_MSG_IMPRINT_set_msg = function(a: PTS_MSG_IMPRINT; d: PByte; len: Integer): Integer; cdecl;
  TTS_MSG_IMPRINT_get_msg = function(a: PTS_MSG_IMPRINT): PASN1_OCTET_STRING; cdecl;
  TTS_MSG_IMPRINT_print_bio = function(bio: PBIO; msg: PTS_MSG_IMPRINT): Integer; cdecl;
  
  // TS_REQ 函数
  TTS_REQ_new = function(): PTS_REQ; cdecl;
  TTS_REQ_free = procedure(a: PTS_REQ); cdecl;
  TTS_REQ_dup = function(a: PTS_REQ): PTS_REQ; cdecl;
  TTS_REQ_d2i_bio = function(bio: PBIO; a: PPTS_REQ): PTS_REQ; cdecl;
  TTS_REQ_i2d_bio = function(bio: PBIO; a: PTS_REQ): Integer; cdecl;
  TTS_REQ_set_version = function(a: PTS_REQ; version: Int64): Integer; cdecl;
  TTS_REQ_get_version = function(a: PTS_REQ): Int64; cdecl;
  TTS_REQ_set_msg_imprint = function(a: PTS_REQ; msg: PTS_MSG_IMPRINT): Integer; cdecl;
  TTS_REQ_get_msg_imprint = function(a: PTS_REQ): PTS_MSG_IMPRINT; cdecl;
  TTS_REQ_set_policy_id = function(a: PTS_REQ; policy: PASN1_OBJECT): Integer; cdecl;
  TTS_REQ_get_policy_id = function(a: PTS_REQ): PASN1_OBJECT; cdecl;
  TTS_REQ_set_nonce = function(a: PTS_REQ; nonce: PASN1_INTEGER): Integer; cdecl;
  TTS_REQ_get_nonce = function(a: PTS_REQ): PASN1_INTEGER; cdecl;
  TTS_REQ_set_cert_req = function(a: PTS_REQ; cert_req: Integer): Integer; cdecl;
  TTS_REQ_get_cert_req = function(a: PTS_REQ): Integer; cdecl;
  TTS_REQ_get_ext_count = function(a: PTS_REQ): Integer; cdecl;
  TTS_REQ_get_ext = function(a: PTS_REQ; loc: Integer): PX509_EXTENSION; cdecl;
  TTS_REQ_get_ext_by_NID = function(a: PTS_REQ; nid: Integer; lastpos: Integer): Integer; cdecl;
  TTS_REQ_get_ext_by_OBJ = function(a: PTS_REQ; obj: PASN1_OBJECT; lastpos: Integer): Integer; cdecl;
  TTS_REQ_get_ext_by_critical = function(a: PTS_REQ; crit: Integer; lastpos: Integer): Integer; cdecl;
  TTS_REQ_ext_free = procedure(a: PTS_REQ); cdecl;
  TTS_REQ_get_ext_d2i = function(a: PTS_REQ; nid: Integer; crit: PInteger; 
                                idx: PInteger): Pointer; cdecl;
  TTS_REQ_add_ext = function(a: PTS_REQ; ex: PX509_EXTENSION; loc: Integer): Integer; cdecl;
  TTS_REQ_add1_ext_i2d = function(a: PTS_REQ; nid: Integer; value: Pointer; 
                                  crit: Integer; flags: LongWord): Integer; cdecl;
  TTS_REQ_delete_ext = function(a: PTS_REQ; loc: Integer): PX509_EXTENSION; cdecl;
  TTS_REQ_print_bio = function(bio: PBIO; req: PTS_REQ): Integer; cdecl;
  
  // TS_TST_INFO 函数
  TTS_TST_INFO_new = function(): PTS_TST_INFO; cdecl;
  TTS_TST_INFO_free = procedure(a: PTS_TST_INFO); cdecl;
  TTS_TST_INFO_dup = function(a: PTS_TST_INFO): PTS_TST_INFO; cdecl;
  TTS_TST_INFO_d2i_bio = function(bio: PBIO; a: PPTS_TST_INFO): PTS_TST_INFO; cdecl;
  TTS_TST_INFO_i2d_bio = function(bio: PBIO; a: PTS_TST_INFO): Integer; cdecl;
  TTS_TST_INFO_set_version = function(a: PTS_TST_INFO; version: Int64): Integer; cdecl;
  TTS_TST_INFO_get_version = function(a: PTS_TST_INFO): Int64; cdecl;
  TTS_TST_INFO_set_policy_id = function(a: PTS_TST_INFO; policy: PASN1_OBJECT): Integer; cdecl;
  TTS_TST_INFO_get_policy_id = function(a: PTS_TST_INFO): PASN1_OBJECT; cdecl;
  TTS_TST_INFO_set_msg_imprint = function(a: PTS_TST_INFO; msg: PTS_MSG_IMPRINT): Integer; cdecl;
  TTS_TST_INFO_get_msg_imprint = function(a: PTS_TST_INFO): PTS_MSG_IMPRINT; cdecl;
  TTS_TST_INFO_set_serial = function(a: PTS_TST_INFO; serial: PASN1_INTEGER): Integer; cdecl;
  TTS_TST_INFO_get_serial = function(a: PTS_TST_INFO): PASN1_INTEGER; cdecl;
  TTS_TST_INFO_set_time = function(a: PTS_TST_INFO; gtime: PASN1_GENERALIZEDTIME): Integer; cdecl;
  TTS_TST_INFO_get_time = function(a: PTS_TST_INFO): PASN1_GENERALIZEDTIME; cdecl;
  TTS_TST_INFO_set_accuracy = function(a: PTS_TST_INFO; acc: PTS_ACCURACY): Integer; cdecl;
  TTS_TST_INFO_get_accuracy = function(a: PTS_TST_INFO): PTS_ACCURACY; cdecl;
  TTS_TST_INFO_set_ordering = function(a: PTS_TST_INFO; ordering: Integer): Integer; cdecl;
  TTS_TST_INFO_get_ordering = function(a: PTS_TST_INFO): Integer; cdecl;
  TTS_TST_INFO_set_nonce = function(a: PTS_TST_INFO; nonce: PASN1_INTEGER): Integer; cdecl;
  TTS_TST_INFO_get_nonce = function(a: PTS_TST_INFO): PASN1_INTEGER; cdecl;
  TTS_TST_INFO_set_tsa = function(a: PTS_TST_INFO; tsa: PGENERAL_NAME): Integer; cdecl;
  TTS_TST_INFO_get_tsa = function(a: PTS_TST_INFO): PGENERAL_NAME; cdecl;
  TTS_TST_INFO_print_bio = function(bio: PBIO; info: PTS_TST_INFO): Integer; cdecl;
  
  // TS_STATUS_INFO 函数
  TTS_STATUS_INFO_new = function(): PTS_STATUS_INFO; cdecl;
  TTS_STATUS_INFO_free = procedure(a: PTS_STATUS_INFO); cdecl;
  TTS_STATUS_INFO_dup = function(a: PTS_STATUS_INFO): PTS_STATUS_INFO; cdecl;
  TTS_STATUS_INFO_set_status = function(a: PTS_STATUS_INFO; status: Integer): Integer; cdecl;
  TTS_STATUS_INFO_get0_status = function(a: PTS_STATUS_INFO): PASN1_INTEGER; cdecl;
  TTS_STATUS_INFO_get0_text = function(a: PTS_STATUS_INFO): PSTACK_OF_ASN1_UTF8STRING; cdecl;
  TTS_STATUS_INFO_get0_failure_info = function(a: PTS_STATUS_INFO): PASN1_BIT_STRING; cdecl;
  TTS_STATUS_INFO_print_bio = function(bio: PBIO; info: PTS_STATUS_INFO): Integer; cdecl;
  
  // TS_RESP 函数
  TTS_RESP_new = function(): PTS_RESP; cdecl;
  TTS_RESP_free = procedure(a: PTS_RESP); cdecl;
  TTS_RESP_dup = function(a: PTS_RESP): PTS_RESP; cdecl;
  TTS_RESP_d2i_bio = function(bio: PBIO; a: PPTS_RESP): PTS_RESP; cdecl;
  TTS_RESP_i2d_bio = function(bio: PBIO; a: PTS_RESP): Integer; cdecl;
  TTS_RESP_create_response = function(ctx: PTS_RESP_CTX; req: PTS_REQ): PTS_RESP; cdecl;
  TTS_RESP_set_status_info = function(a: PTS_RESP; info: PTS_STATUS_INFO): Integer; cdecl;
  TTS_RESP_get_status_info = function(a: PTS_RESP): PTS_STATUS_INFO; cdecl;
  TTS_RESP_set_tst_info = function(a: PTS_RESP; token: PPKCS7; tst_info: PTS_TST_INFO): Integer; cdecl;
  TTS_RESP_get_token = function(a: PTS_RESP): PPKCS7; cdecl;
  TTS_RESP_get_tst_info = function(a: PTS_RESP): PTS_TST_INFO; cdecl;
  TTS_RESP_set_gentime_with_precision = function(info: PTS_TST_INFO; sec: Int64; 
                                                usec: Int64; precision: LongWord): Integer; cdecl;
  TTS_RESP_print_bio = function(bio: PBIO; resp: PTS_RESP): Integer; cdecl;
  TTS_RESP_verify_signature = function(token: PPKCS7; certs: PSTACK_OF_X509; 
                                      store: PX509_STORE; signer: PPX509): Integer; cdecl;
  TTS_RESP_verify_token = function(ctx: PTS_VERIFY_CTX; token: PPKCS7): Integer; cdecl;
  TTS_RESP_verify_response = function(ctx: PTS_VERIFY_CTX; resp: PTS_RESP): Integer; cdecl;
  
  // TS_RESP_CTX 函数
  TTS_RESP_CTX_new = function(): PTS_RESP_CTX; cdecl;
  TTS_RESP_CTX_free = procedure(ctx: PTS_RESP_CTX); cdecl;
  TTS_RESP_CTX_set_signer_cert = function(ctx: PTS_RESP_CTX; cert: PX509): Integer; cdecl;
  TTS_RESP_CTX_set_signer_key = function(ctx: PTS_RESP_CTX; key: PEVP_PKEY): Integer; cdecl;
  TTS_RESP_CTX_set_signer_digest = function(ctx: PTS_RESP_CTX; md: PEVP_MD): Integer; cdecl;
  TTS_RESP_CTX_set_ess_cert_id_digest = function(ctx: PTS_RESP_CTX; md: PEVP_MD): Integer; cdecl;
  TTS_RESP_CTX_set_def_policy = function(ctx: PTS_RESP_CTX; policy: PASN1_OBJECT): Integer; cdecl;
  TTS_RESP_CTX_add_policy = function(ctx: PTS_RESP_CTX; policy: PASN1_OBJECT): Integer; cdecl;
  TTS_RESP_CTX_add_md = function(ctx: PTS_RESP_CTX; md: PEVP_MD): Integer; cdecl;
  TTS_RESP_CTX_set_accuracy = function(ctx: PTS_RESP_CTX; secs: Integer; 
                                      millis: Integer; micros: Integer): Integer; cdecl;
  TTS_RESP_CTX_set_clock_precision_digits = function(ctx: PTS_RESP_CTX; digits: LongWord): Integer; cdecl;
  TTS_RESP_CTX_add_flags = procedure(ctx: PTS_RESP_CTX; flags: Integer); cdecl;
  TTS_RESP_CTX_set_serial_cb = procedure(ctx: PTS_RESP_CTX; cb: TS_serial_cb; data: Pointer); cdecl;
  TTS_RESP_CTX_set_time_cb = procedure(ctx: PTS_RESP_CTX; cb: TS_time_cb; data: Pointer); cdecl;
  TTS_RESP_CTX_set_extension_cb = procedure(ctx: PTS_RESP_CTX; cb: TS_extension_cb; data: Pointer); cdecl;
  TTS_RESP_CTX_set_status_info = function(ctx: PTS_RESP_CTX; status: Integer; 
                                          text: PAnsiChar): Integer; cdecl;
  TTS_RESP_CTX_set_status_info_cond = function(ctx: PTS_RESP_CTX; status: Integer; 
                                              text: PAnsiChar): Integer; cdecl;
  TTS_RESP_CTX_add_failure_info = function(ctx: PTS_RESP_CTX; failure: Integer): Integer; cdecl;
  TTS_RESP_CTX_get_request = function(ctx: PTS_RESP_CTX): PTS_REQ; cdecl;
  TTS_RESP_CTX_get_tst_info = function(ctx: PTS_RESP_CTX): PTS_TST_INFO; cdecl;
  
  // TS_VERIFY_CTX 函数  
  TTS_VERIFY_CTX_new = function(): PTS_VERIFY_CTX; cdecl;
  TTS_VERIFY_CTX_init = procedure(ctx: PTS_VERIFY_CTX); cdecl;
  TTS_VERIFY_CTX_free = procedure(ctx: PTS_VERIFY_CTX); cdecl;
  TTS_VERIFY_CTX_cleanup = procedure(ctx: PTS_VERIFY_CTX); cdecl;
  TTS_VERIFY_CTX_set_flags = function(ctx: PTS_VERIFY_CTX; flags: Integer): Integer; cdecl;
  TTS_VERIFY_CTX_add_flags = function(ctx: PTS_VERIFY_CTX; flags: Integer): Integer; cdecl;
  TTS_VERIFY_CTX_set_data = function(ctx: PTS_VERIFY_CTX; bio: PBIO): PBIO; cdecl;
  TTS_VERIFY_CTX_set_imprint = function(ctx: PTS_VERIFY_CTX; hexstr: PByte; 
                                        len: Integer): LongWord; cdecl;
  TTS_VERIFY_CTX_set_store = function(ctx: PTS_VERIFY_CTX; store: PX509_STORE): PX509_STORE; cdecl;
  TTS_VERIFY_CTX_set_certs = function(ctx: PTS_VERIFY_CTX; certs: PSTACK_OF_X509): PSTACK_OF_X509; cdecl;
  TTS_VERIFY_CTX_set_data_bio = function(ctx: PTS_VERIFY_CTX; bio: PBIO): PBIO; cdecl;
  TTS_VERIFY_CTX_set_imprint_bio = function(ctx: PTS_VERIFY_CTX; bio: PBIO): Integer; cdecl;
  
  // TS_ACCURACY 函数
  TTS_ACCURACY_new = function(): PTS_ACCURACY; cdecl;
  TTS_ACCURACY_free = procedure(a: PTS_ACCURACY); cdecl;
  TTS_ACCURACY_dup = function(a: PTS_ACCURACY): PTS_ACCURACY; cdecl;
  TTS_ACCURACY_set_seconds = function(a: PTS_ACCURACY; seconds: PASN1_INTEGER): Integer; cdecl;
  TTS_ACCURACY_get_seconds = function(a: PTS_ACCURACY): PASN1_INTEGER; cdecl;
  TTS_ACCURACY_set_millis = function(a: PTS_ACCURACY; millis: PASN1_INTEGER): Integer; cdecl;
  TTS_ACCURACY_get_millis = function(a: PTS_ACCURACY): PASN1_INTEGER; cdecl;
  TTS_ACCURACY_set_micros = function(a: PTS_ACCURACY; micros: PASN1_INTEGER): Integer; cdecl;
  TTS_ACCURACY_get_micros = function(a: PTS_ACCURACY): PASN1_INTEGER; cdecl;
  
  // 配置函数
  TTS_CONF_load_cert = function(file_name: PAnsiChar): PX509; cdecl;
  TTS_CONF_load_key = function(file_name: PAnsiChar; pass: PAnsiChar): PEVP_PKEY; cdecl;
  TTS_CONF_set_serial = function(conf: Pointer; section: PAnsiChar; 
                                cb: TS_serial_cb; ctx: PTS_RESP_CTX): Integer; cdecl;
  TTS_CONF_get_tsa_section = function(conf: Pointer; section: PAnsiChar): PAnsiChar; cdecl;
  TTS_CONF_set_crypto_device = function(conf: Pointer; section: PAnsiChar; device: PAnsiChar): Integer; cdecl;
  TTS_CONF_set_default_engine = function(name: PAnsiChar): Integer; cdecl;
  TTS_CONF_set_signer_cert = function(conf: Pointer; section: PAnsiChar; 
                                      cert: PAnsiChar; ctx: PTS_RESP_CTX): Integer; cdecl;
  TTS_CONF_set_certs = function(conf: Pointer; section: PAnsiChar; 
                                certs: PAnsiChar; ctx: PTS_RESP_CTX): Integer; cdecl;
  TTS_CONF_set_signer_key = function(conf: Pointer; section: PAnsiChar; 
                                    key: PAnsiChar; pass: PAnsiChar; ctx: PTS_RESP_CTX): Integer; cdecl;
  TTS_CONF_set_signer_digest = function(conf: Pointer; section: PAnsiChar; 
                                        md: PAnsiChar; ctx: PTS_RESP_CTX): Integer; cdecl;
  TTS_CONF_set_def_policy = function(conf: Pointer; section: PAnsiChar; 
                                    policy: PAnsiChar; ctx: PTS_RESP_CTX): Integer; cdecl;
  TTS_CONF_set_policies = function(conf: Pointer; section: PAnsiChar; ctx: PTS_RESP_CTX): Integer; cdecl;
  TTS_CONF_set_digests = function(conf: Pointer; section: PAnsiChar; ctx: PTS_RESP_CTX): Integer; cdecl;
  TTS_CONF_set_accuracy = function(conf: Pointer; section: PAnsiChar; ctx: PTS_RESP_CTX): Integer; cdecl;
  TTS_CONF_set_clock_precision_digits = function(conf: Pointer; section: PAnsiChar; 
                                                ctx: PTS_RESP_CTX): Integer; cdecl;
  TTS_CONF_set_ordering = function(conf: Pointer; section: PAnsiChar; ctx: PTS_RESP_CTX): Integer; cdecl;
  TTS_CONF_set_tsa_name = function(conf: Pointer; section: PAnsiChar; ctx: PTS_RESP_CTX): Integer; cdecl;
  TTS_CONF_set_ess_cert_id_chain = function(conf: Pointer; section: PAnsiChar; 
                                            ctx: PTS_RESP_CTX): Integer; cdecl;
  TTS_CONF_set_ess_cert_id_digest = function(conf: Pointer; section: PAnsiChar; 
                                            ctx: PTS_RESP_CTX): Integer; cdecl;

var
  // TS_MSG_IMPRINT 函数
  TS_MSG_IMPRINT_new: TTS_MSG_IMPRINT_new;
  TS_MSG_IMPRINT_free: TTS_MSG_IMPRINT_free;
  TS_MSG_IMPRINT_dup: TTS_MSG_IMPRINT_dup;
  TS_MSG_IMPRINT_set_algo: TTS_MSG_IMPRINT_set_algo;
  TS_MSG_IMPRINT_get_algo: TTS_MSG_IMPRINT_get_algo;
  TS_MSG_IMPRINT_set_msg: TTS_MSG_IMPRINT_set_msg;
  TS_MSG_IMPRINT_get_msg: TTS_MSG_IMPRINT_get_msg;
  TS_MSG_IMPRINT_print_bio: TTS_MSG_IMPRINT_print_bio;
  
  // TS_REQ 函数
  TS_REQ_new: TTS_REQ_new;
  TS_REQ_free: TTS_REQ_free;
  TS_REQ_dup: TTS_REQ_dup;
  TS_REQ_d2i_bio: TTS_REQ_d2i_bio;
  TS_REQ_i2d_bio: TTS_REQ_i2d_bio;
  TS_REQ_set_version: TTS_REQ_set_version;
  TS_REQ_get_version: TTS_REQ_get_version;
  TS_REQ_set_msg_imprint: TTS_REQ_set_msg_imprint;
  TS_REQ_get_msg_imprint: TTS_REQ_get_msg_imprint;
  TS_REQ_set_policy_id: TTS_REQ_set_policy_id;
  TS_REQ_get_policy_id: TTS_REQ_get_policy_id;
  TS_REQ_set_nonce: TTS_REQ_set_nonce;
  TS_REQ_get_nonce: TTS_REQ_get_nonce;
  TS_REQ_set_cert_req: TTS_REQ_set_cert_req;
  TS_REQ_get_cert_req: TTS_REQ_get_cert_req;
  TS_REQ_get_ext_count: TTS_REQ_get_ext_count;
  TS_REQ_get_ext: TTS_REQ_get_ext;
  TS_REQ_get_ext_by_NID: TTS_REQ_get_ext_by_NID;
  TS_REQ_get_ext_by_OBJ: TTS_REQ_get_ext_by_OBJ;
  TS_REQ_get_ext_by_critical: TTS_REQ_get_ext_by_critical;
  TS_REQ_ext_free: TTS_REQ_ext_free;
  TS_REQ_get_ext_d2i: TTS_REQ_get_ext_d2i;
  TS_REQ_add_ext: TTS_REQ_add_ext;
  TS_REQ_add1_ext_i2d: TTS_REQ_add1_ext_i2d;
  TS_REQ_delete_ext: TTS_REQ_delete_ext;
  TS_REQ_print_bio: TTS_REQ_print_bio;
  
  // TS_TST_INFO 函数
  TS_TST_INFO_new: TTS_TST_INFO_new;
  TS_TST_INFO_free: TTS_TST_INFO_free;
  TS_TST_INFO_dup: TTS_TST_INFO_dup;
  TS_TST_INFO_d2i_bio: TTS_TST_INFO_d2i_bio;
  TS_TST_INFO_i2d_bio: TTS_TST_INFO_i2d_bio;
  TS_TST_INFO_set_version: TTS_TST_INFO_set_version;
  TS_TST_INFO_get_version: TTS_TST_INFO_get_version;
  TS_TST_INFO_set_policy_id: TTS_TST_INFO_set_policy_id;
  TS_TST_INFO_get_policy_id: TTS_TST_INFO_get_policy_id;
  TS_TST_INFO_set_msg_imprint: TTS_TST_INFO_set_msg_imprint;
  TS_TST_INFO_get_msg_imprint: TTS_TST_INFO_get_msg_imprint;
  TS_TST_INFO_set_serial: TTS_TST_INFO_set_serial;
  TS_TST_INFO_get_serial: TTS_TST_INFO_get_serial;
  TS_TST_INFO_set_time: TTS_TST_INFO_set_time;
  TS_TST_INFO_get_time: TTS_TST_INFO_get_time;
  TS_TST_INFO_set_accuracy: TTS_TST_INFO_set_accuracy;
  TS_TST_INFO_get_accuracy: TTS_TST_INFO_get_accuracy;
  TS_TST_INFO_set_ordering: TTS_TST_INFO_set_ordering;
  TS_TST_INFO_get_ordering: TTS_TST_INFO_get_ordering;
  TS_TST_INFO_set_nonce: TTS_TST_INFO_set_nonce;
  TS_TST_INFO_get_nonce: TTS_TST_INFO_get_nonce;
  TS_TST_INFO_set_tsa: TTS_TST_INFO_set_tsa;
  TS_TST_INFO_get_tsa: TTS_TST_INFO_get_tsa;
  TS_TST_INFO_print_bio: TTS_TST_INFO_print_bio;
  
  // TS_STATUS_INFO 函数
  TS_STATUS_INFO_new: TTS_STATUS_INFO_new;
  TS_STATUS_INFO_free: TTS_STATUS_INFO_free;
  TS_STATUS_INFO_dup: TTS_STATUS_INFO_dup;
  TS_STATUS_INFO_set_status: TTS_STATUS_INFO_set_status;
  TS_STATUS_INFO_get0_status: TTS_STATUS_INFO_get0_status;
  TS_STATUS_INFO_get0_text: TTS_STATUS_INFO_get0_text;
  TS_STATUS_INFO_get0_failure_info: TTS_STATUS_INFO_get0_failure_info;
  TS_STATUS_INFO_print_bio: TTS_STATUS_INFO_print_bio;
  
  // TS_RESP 函数
  TS_RESP_new: TTS_RESP_new;
  TS_RESP_free: TTS_RESP_free;
  TS_RESP_dup: TTS_RESP_dup;
  TS_RESP_d2i_bio: TTS_RESP_d2i_bio;
  TS_RESP_i2d_bio: TTS_RESP_i2d_bio;
  TS_RESP_create_response: TTS_RESP_create_response;
  TS_RESP_set_status_info: TTS_RESP_set_status_info;
  TS_RESP_get_status_info: TTS_RESP_get_status_info;
  TS_RESP_set_tst_info: TTS_RESP_set_tst_info;
  TS_RESP_get_token: TTS_RESP_get_token;
  TS_RESP_get_tst_info: TTS_RESP_get_tst_info;
  TS_RESP_set_gentime_with_precision: TTS_RESP_set_gentime_with_precision;
  TS_RESP_print_bio: TTS_RESP_print_bio;
  TS_RESP_verify_signature: TTS_RESP_verify_signature;
  TS_RESP_verify_token: TTS_RESP_verify_token;
  TS_RESP_verify_response: TTS_RESP_verify_response;
  
  // TS_RESP_CTX 函数
  TS_RESP_CTX_new: TTS_RESP_CTX_new;
  TS_RESP_CTX_free: TTS_RESP_CTX_free;
  TS_RESP_CTX_set_signer_cert: TTS_RESP_CTX_set_signer_cert;
  TS_RESP_CTX_set_signer_key: TTS_RESP_CTX_set_signer_key;
  TS_RESP_CTX_set_signer_digest: TTS_RESP_CTX_set_signer_digest;
  TS_RESP_CTX_set_ess_cert_id_digest: TTS_RESP_CTX_set_ess_cert_id_digest;
  TS_RESP_CTX_set_def_policy: TTS_RESP_CTX_set_def_policy;
  TS_RESP_CTX_add_policy: TTS_RESP_CTX_add_policy;
  TS_RESP_CTX_add_md: TTS_RESP_CTX_add_md;
  TS_RESP_CTX_set_accuracy: TTS_RESP_CTX_set_accuracy;
  TS_RESP_CTX_set_clock_precision_digits: TTS_RESP_CTX_set_clock_precision_digits;
  TS_RESP_CTX_add_flags: TTS_RESP_CTX_add_flags;
  TS_RESP_CTX_set_serial_cb: TTS_RESP_CTX_set_serial_cb;
  TS_RESP_CTX_set_time_cb: TTS_RESP_CTX_set_time_cb;
  TS_RESP_CTX_set_extension_cb: TTS_RESP_CTX_set_extension_cb;
  TS_RESP_CTX_set_status_info: TTS_RESP_CTX_set_status_info;
  TS_RESP_CTX_set_status_info_cond: TTS_RESP_CTX_set_status_info_cond;
  TS_RESP_CTX_add_failure_info: TTS_RESP_CTX_add_failure_info;
  TS_RESP_CTX_get_request: TTS_RESP_CTX_get_request;
  TS_RESP_CTX_get_tst_info: TTS_RESP_CTX_get_tst_info;
  
  // TS_VERIFY_CTX 函数
  TS_VERIFY_CTX_new: TTS_VERIFY_CTX_new;
  TS_VERIFY_CTX_init: TTS_VERIFY_CTX_init;
  TS_VERIFY_CTX_free: TTS_VERIFY_CTX_free;
  TS_VERIFY_CTX_cleanup: TTS_VERIFY_CTX_cleanup;
  TS_VERIFY_CTX_set_flags: TTS_VERIFY_CTX_set_flags;
  TS_VERIFY_CTX_add_flags: TTS_VERIFY_CTX_add_flags;
  TS_VERIFY_CTX_set_data: TTS_VERIFY_CTX_set_data;
  TS_VERIFY_CTX_set_imprint: TTS_VERIFY_CTX_set_imprint;
  TS_VERIFY_CTX_set_store: TTS_VERIFY_CTX_set_store;
  TS_VERIFY_CTX_set_certs: TTS_VERIFY_CTX_set_certs;
  TS_VERIFY_CTX_set_data_bio: TTS_VERIFY_CTX_set_data_bio;
  TS_VERIFY_CTX_set_imprint_bio: TTS_VERIFY_CTX_set_imprint_bio;
  
  // TS_ACCURACY 函数
  TS_ACCURACY_new: TTS_ACCURACY_new;
  TS_ACCURACY_free: TTS_ACCURACY_free;
  TS_ACCURACY_dup: TTS_ACCURACY_dup;
  TS_ACCURACY_set_seconds: TTS_ACCURACY_set_seconds;
  TS_ACCURACY_get_seconds: TTS_ACCURACY_get_seconds;
  TS_ACCURACY_set_millis: TTS_ACCURACY_set_millis;
  TS_ACCURACY_get_millis: TTS_ACCURACY_get_millis;
  TS_ACCURACY_set_micros: TTS_ACCURACY_set_micros;
  TS_ACCURACY_get_micros: TTS_ACCURACY_get_micros;
  
  // 配置函数
  TS_CONF_load_cert: TTS_CONF_load_cert;
  TS_CONF_load_key: TTS_CONF_load_key;
  TS_CONF_set_serial: TTS_CONF_set_serial;
  TS_CONF_get_tsa_section: TTS_CONF_get_tsa_section;
  TS_CONF_set_crypto_device: TTS_CONF_set_crypto_device;
  TS_CONF_set_default_engine: TTS_CONF_set_default_engine;
  TS_CONF_set_signer_cert: TTS_CONF_set_signer_cert;
  TS_CONF_set_certs: TTS_CONF_set_certs;
  TS_CONF_set_signer_key: TTS_CONF_set_signer_key;
  TS_CONF_set_signer_digest: TTS_CONF_set_signer_digest;
  TS_CONF_set_def_policy: TTS_CONF_set_def_policy;
  TS_CONF_set_policies: TTS_CONF_set_policies;
  TS_CONF_set_digests: TTS_CONF_set_digests;
  TS_CONF_set_accuracy: TTS_CONF_set_accuracy;
  TS_CONF_set_clock_precision_digits: TTS_CONF_set_clock_precision_digits;
  TS_CONF_set_ordering: TTS_CONF_set_ordering;
  TS_CONF_set_tsa_name: TTS_CONF_set_tsa_name;
  TS_CONF_set_ess_cert_id_chain: TTS_CONF_set_ess_cert_id_chain;
  TS_CONF_set_ess_cert_id_digest: TTS_CONF_set_ess_cert_id_digest;

procedure LoadTSFunctions;
procedure UnloadTSFunctions;

// 辅助函数
function CreateTimestampRequest(const Data: TBytes; const PolicyOID: string = ''): PTS_REQ;
function VerifyTimestampResponse(Response: PTS_RESP; Request: PTS_REQ; 
                                Store: PX509_STORE = nil): Boolean;
function GetTimestampTime(Response: PTS_RESP): TDateTime;

implementation

uses nextpas.core.tls.openssl.api.core, nextpas.core.tls.openssl.loader;

procedure LoadTSFunctions;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then Exit;
  
  // TS_MSG_IMPRINT 函数
  TS_MSG_IMPRINT_new := TTS_MSG_IMPRINT_new(GetCryptoProcAddress('TS_MSG_IMPRINT_new'));
  TS_MSG_IMPRINT_free := TTS_MSG_IMPRINT_free(GetCryptoProcAddress('TS_MSG_IMPRINT_free'));
  TS_MSG_IMPRINT_dup := TTS_MSG_IMPRINT_dup(GetCryptoProcAddress('TS_MSG_IMPRINT_dup'));
  TS_MSG_IMPRINT_set_algo := TTS_MSG_IMPRINT_set_algo(GetCryptoProcAddress('TS_MSG_IMPRINT_set_algo'));
  TS_MSG_IMPRINT_get_algo := TTS_MSG_IMPRINT_get_algo(GetCryptoProcAddress('TS_MSG_IMPRINT_get_algo'));
  TS_MSG_IMPRINT_set_msg := TTS_MSG_IMPRINT_set_msg(GetCryptoProcAddress('TS_MSG_IMPRINT_set_msg'));
  TS_MSG_IMPRINT_get_msg := TTS_MSG_IMPRINT_get_msg(GetCryptoProcAddress('TS_MSG_IMPRINT_get_msg'));
  TS_MSG_IMPRINT_print_bio := TTS_MSG_IMPRINT_print_bio(GetCryptoProcAddress('TS_MSG_IMPRINT_print_bio'));
  
  // TS_REQ 函数
  TS_REQ_new := TTS_REQ_new(GetCryptoProcAddress('TS_REQ_new'));
  TS_REQ_free := TTS_REQ_free(GetCryptoProcAddress('TS_REQ_free'));
  TS_REQ_dup := TTS_REQ_dup(GetCryptoProcAddress('TS_REQ_dup'));
  // Note: OpenSSL 3.x uses d2i_TS_REQ_bio and i2d_TS_REQ_bio (not TS_REQ_d2i_bio/TS_REQ_i2d_bio)
  TS_REQ_d2i_bio := TTS_REQ_d2i_bio(GetCryptoProcAddress('d2i_TS_REQ_bio'));
  TS_REQ_i2d_bio := TTS_REQ_i2d_bio(GetCryptoProcAddress('i2d_TS_REQ_bio'));
  TS_REQ_set_version := TTS_REQ_set_version(GetCryptoProcAddress('TS_REQ_set_version'));
  TS_REQ_get_version := TTS_REQ_get_version(GetCryptoProcAddress('TS_REQ_get_version'));
  TS_REQ_set_msg_imprint := TTS_REQ_set_msg_imprint(GetCryptoProcAddress('TS_REQ_set_msg_imprint'));
  TS_REQ_get_msg_imprint := TTS_REQ_get_msg_imprint(GetCryptoProcAddress('TS_REQ_get_msg_imprint'));
  TS_REQ_set_policy_id := TTS_REQ_set_policy_id(GetCryptoProcAddress('TS_REQ_set_policy_id'));
  TS_REQ_get_policy_id := TTS_REQ_get_policy_id(GetCryptoProcAddress('TS_REQ_get_policy_id'));
  TS_REQ_set_nonce := TTS_REQ_set_nonce(GetCryptoProcAddress('TS_REQ_set_nonce'));
  TS_REQ_get_nonce := TTS_REQ_get_nonce(GetCryptoProcAddress('TS_REQ_get_nonce'));
  TS_REQ_set_cert_req := TTS_REQ_set_cert_req(GetCryptoProcAddress('TS_REQ_set_cert_req'));
  TS_REQ_get_cert_req := TTS_REQ_get_cert_req(GetCryptoProcAddress('TS_REQ_get_cert_req'));
  TS_REQ_print_bio := TTS_REQ_print_bio(GetCryptoProcAddress('TS_REQ_print_bio'));
  
  // TS_TST_INFO 函数
  TS_TST_INFO_new := TTS_TST_INFO_new(GetCryptoProcAddress('TS_TST_INFO_new'));
  TS_TST_INFO_free := TTS_TST_INFO_free(GetCryptoProcAddress('TS_TST_INFO_free'));
  TS_TST_INFO_dup := TTS_TST_INFO_dup(GetCryptoProcAddress('TS_TST_INFO_dup'));
  TS_TST_INFO_d2i_bio := TTS_TST_INFO_d2i_bio(GetCryptoProcAddress('TS_TST_INFO_d2i_bio'));
  TS_TST_INFO_i2d_bio := TTS_TST_INFO_i2d_bio(GetCryptoProcAddress('TS_TST_INFO_i2d_bio'));
  TS_TST_INFO_set_version := TTS_TST_INFO_set_version(GetCryptoProcAddress('TS_TST_INFO_set_version'));
  TS_TST_INFO_get_version := TTS_TST_INFO_get_version(GetCryptoProcAddress('TS_TST_INFO_get_version'));
  TS_TST_INFO_get_serial := TTS_TST_INFO_get_serial(GetCryptoProcAddress('TS_TST_INFO_get_serial'));
  TS_TST_INFO_set_time := TTS_TST_INFO_set_time(GetCryptoProcAddress('TS_TST_INFO_set_time'));
  TS_TST_INFO_get_time := TTS_TST_INFO_get_time(GetCryptoProcAddress('TS_TST_INFO_get_time'));
  TS_TST_INFO_print_bio := TTS_TST_INFO_print_bio(GetCryptoProcAddress('TS_TST_INFO_print_bio'));
  
  // TS_STATUS_INFO 函数
  TS_STATUS_INFO_new := TTS_STATUS_INFO_new(GetCryptoProcAddress('TS_STATUS_INFO_new'));
  TS_STATUS_INFO_free := TTS_STATUS_INFO_free(GetCryptoProcAddress('TS_STATUS_INFO_free'));
  TS_STATUS_INFO_dup := TTS_STATUS_INFO_dup(GetCryptoProcAddress('TS_STATUS_INFO_dup'));
  TS_STATUS_INFO_set_status := TTS_STATUS_INFO_set_status(GetCryptoProcAddress('TS_STATUS_INFO_set_status'));
  TS_STATUS_INFO_get0_status := TTS_STATUS_INFO_get0_status(GetCryptoProcAddress('TS_STATUS_INFO_get0_status'));
  TS_STATUS_INFO_get0_text := TTS_STATUS_INFO_get0_text(GetCryptoProcAddress('TS_STATUS_INFO_get0_text'));
  TS_STATUS_INFO_get0_failure_info := TTS_STATUS_INFO_get0_failure_info(GetCryptoProcAddress('TS_STATUS_INFO_get0_failure_info'));
  TS_STATUS_INFO_print_bio := TTS_STATUS_INFO_print_bio(GetCryptoProcAddress('TS_STATUS_INFO_print_bio'));
  
  // TS_RESP 函数
  TS_RESP_new := TTS_RESP_new(GetCryptoProcAddress('TS_RESP_new'));
  TS_RESP_free := TTS_RESP_free(GetCryptoProcAddress('TS_RESP_free'));
  // Note: OpenSSL 3.x uses d2i_TS_RESP_bio and i2d_TS_RESP_bio (not TS_RESP_d2i_bio/TS_RESP_i2d_bio)
  TS_RESP_d2i_bio := TTS_RESP_d2i_bio(GetCryptoProcAddress('d2i_TS_RESP_bio'));
  TS_RESP_i2d_bio := TTS_RESP_i2d_bio(GetCryptoProcAddress('i2d_TS_RESP_bio'));
  TS_RESP_create_response := TTS_RESP_create_response(GetCryptoProcAddress('TS_RESP_create_response'));
  TS_RESP_set_status_info := TTS_RESP_set_status_info(GetCryptoProcAddress('TS_RESP_set_status_info'));
  TS_RESP_get_status_info := TTS_RESP_get_status_info(GetCryptoProcAddress('TS_RESP_get_status_info'));
  TS_RESP_get_token := TTS_RESP_get_token(GetCryptoProcAddress('TS_RESP_get_token'));
  TS_RESP_get_tst_info := TTS_RESP_get_tst_info(GetCryptoProcAddress('TS_RESP_get_tst_info'));
  TS_RESP_print_bio := TTS_RESP_print_bio(GetCryptoProcAddress('TS_RESP_print_bio'));
  TS_RESP_verify_signature := TTS_RESP_verify_signature(GetCryptoProcAddress('TS_RESP_verify_signature'));
  TS_RESP_verify_response := TTS_RESP_verify_response(GetCryptoProcAddress('TS_RESP_verify_response'));
  
  // TS_RESP_CTX 函数
  TS_RESP_CTX_new := TTS_RESP_CTX_new(GetCryptoProcAddress('TS_RESP_CTX_new'));
  TS_RESP_CTX_free := TTS_RESP_CTX_free(GetCryptoProcAddress('TS_RESP_CTX_free'));
  TS_RESP_CTX_set_signer_cert := TTS_RESP_CTX_set_signer_cert(GetCryptoProcAddress('TS_RESP_CTX_set_signer_cert'));
  TS_RESP_CTX_set_signer_key := TTS_RESP_CTX_set_signer_key(GetCryptoProcAddress('TS_RESP_CTX_set_signer_key'));
  TS_RESP_CTX_set_def_policy := TTS_RESP_CTX_set_def_policy(GetCryptoProcAddress('TS_RESP_CTX_set_def_policy'));
  
  // TS_VERIFY_CTX 函数
  TS_VERIFY_CTX_new := TTS_VERIFY_CTX_new(GetCryptoProcAddress('TS_VERIFY_CTX_new'));
  TS_VERIFY_CTX_free := TTS_VERIFY_CTX_free(GetCryptoProcAddress('TS_VERIFY_CTX_free'));
  TS_VERIFY_CTX_set_flags := TTS_VERIFY_CTX_set_flags(GetCryptoProcAddress('TS_VERIFY_CTX_set_flags'));
  TS_VERIFY_CTX_set_store := TTS_VERIFY_CTX_set_store(GetCryptoProcAddress('TS_VERIFY_CTX_set_store'));
  TS_VERIFY_CTX_set_certs := TTS_VERIFY_CTX_set_certs(GetCryptoProcAddress('TS_VERIFY_CTX_set_certs'));
end;

procedure UnloadTSFunctions;
begin
  // 重置所有函数指针
  TS_MSG_IMPRINT_new := nil;
  TS_MSG_IMPRINT_free := nil;
  TS_REQ_new := nil;
  TS_REQ_free := nil;
  TS_TST_INFO_new := nil;
  TS_TST_INFO_free := nil;
  TS_STATUS_INFO_new := nil;
  TS_STATUS_INFO_free := nil;
  TS_STATUS_INFO_dup := nil;
  TS_STATUS_INFO_set_status := nil;
  TS_STATUS_INFO_get0_status := nil;
  TS_STATUS_INFO_get0_text := nil;
  TS_STATUS_INFO_get0_failure_info := nil;
  TS_STATUS_INFO_print_bio := nil;
  TS_RESP_new := nil;
  TS_RESP_free := nil;
  TS_RESP_CTX_new := nil;
  TS_RESP_CTX_free := nil;
  TS_VERIFY_CTX_new := nil;
  TS_VERIFY_CTX_free := nil;
end;

function CreateTimestampRequest(const Data: TBytes; const PolicyOID: string = ''): PTS_REQ;
var
  MsgImprint: PTS_MSG_IMPRINT;
  Policy: PASN1_OBJECT;
  Nonce: PASN1_INTEGER;
  NonceBN: PBIGNUM;
  MD: PEVP_MD;
  MDCtx: PEVP_MD_CTX;
  Hash: array[0..EVP_MAX_MD_SIZE-1] of Byte;
  HashLen: Cardinal;
  DataPtr: PByte;
  ImprintAlgo: Pointer;
  RandomBytes: array[0..7] of Byte;
begin
  Result := nil;
  
  // Create new request
  if not Assigned(TS_REQ_new) then Exit;
    
  Result := TS_REQ_new();
  if Result = nil then Exit;
  
  try
    // Set version to 1
    if Assigned(TS_REQ_set_version) then
      TS_REQ_set_version(Result, 1);
      
    // Create message imprint
    if not Assigned(TS_MSG_IMPRINT_new) then
    begin
      if Assigned(TS_REQ_free) then
        TS_REQ_free(Result);
      Exit(nil);
    end;

    MsgImprint := TS_MSG_IMPRINT_new();
    if MsgImprint = nil then
    begin
      if Assigned(TS_REQ_free) then
        TS_REQ_free(Result);
      Exit(nil);
    end;

    // Calculate SHA-256 digest for RFC3161 message imprint
    MD := EVP_sha256();
    if (MD = nil) or
      (not Assigned(EVP_MD_CTX_new)) or
      (not Assigned(EVP_DigestInit_ex)) or
      (not Assigned(EVP_DigestUpdate)) or
      (not Assigned(EVP_DigestFinal_ex)) or
      (not Assigned(TS_MSG_IMPRINT_set_msg)) or
      (not Assigned(TS_REQ_set_msg_imprint)) then
    begin
      if Assigned(TS_MSG_IMPRINT_free) then
        TS_MSG_IMPRINT_free(MsgImprint);
      if Assigned(TS_REQ_free) then
        TS_REQ_free(Result);
      Exit(nil);
    end;

    MDCtx := EVP_MD_CTX_new();
    if MDCtx = nil then
    begin
      if Assigned(TS_MSG_IMPRINT_free) then
        TS_MSG_IMPRINT_free(MsgImprint);
      if Assigned(TS_REQ_free) then
        TS_REQ_free(Result);
      Exit(nil);
    end;

    try
      DataPtr := nil;
      if Length(Data) > 0 then
        DataPtr := @Data[0];

      if (EVP_DigestInit_ex(MDCtx, MD, nil) <> 1) or
        (EVP_DigestUpdate(MDCtx, DataPtr, Cardinal(Length(Data))) <> 1) then
      begin
        if Assigned(TS_MSG_IMPRINT_free) then
          TS_MSG_IMPRINT_free(MsgImprint);
        if Assigned(TS_REQ_free) then
          TS_REQ_free(Result);
        Exit(nil);
      end;

      HashLen := 0;
      if EVP_DigestFinal_ex(MDCtx, @Hash[0], HashLen) <> 1 then
      begin
        if Assigned(TS_MSG_IMPRINT_free) then
          TS_MSG_IMPRINT_free(MsgImprint);
        if Assigned(TS_REQ_free) then
          TS_REQ_free(Result);
        Exit(nil);
      end;
    finally
      if Assigned(EVP_MD_CTX_free) then
        EVP_MD_CTX_free(MDCtx);
    end;

    // Configure digest algorithm in imprint when API is available.
    if Assigned(TS_MSG_IMPRINT_get_algo) and Assigned(X509_ALGOR_set_md) then
    begin
      ImprintAlgo := TS_MSG_IMPRINT_get_algo(MsgImprint);
      if ImprintAlgo <> nil then
        X509_ALGOR_set_md(ImprintAlgo, MD);
    end;

    if TS_MSG_IMPRINT_set_msg(MsgImprint, @Hash[0], Integer(HashLen)) <> 1 then
    begin
      if Assigned(TS_MSG_IMPRINT_free) then
        TS_MSG_IMPRINT_free(MsgImprint);
      if Assigned(TS_REQ_free) then
        TS_REQ_free(Result);
      Exit(nil);
    end;

    if TS_REQ_set_msg_imprint(Result, MsgImprint) <> 1 then
    begin
      if Assigned(TS_MSG_IMPRINT_free) then
        TS_MSG_IMPRINT_free(MsgImprint);
      if Assigned(TS_REQ_free) then
        TS_REQ_free(Result);
      Exit(nil);
    end;
    
    // Set policy OID when provided: strict parse + strict attach
    if PolicyOID <> '' then
    begin
      if not Assigned(TS_REQ_set_policy_id) then
      begin
        if Assigned(TS_REQ_free) then
          TS_REQ_free(Result);
        Exit(nil);
      end;

      if not Assigned(OBJ_txt2obj) then
      begin
        LoadOBJModule(GetCryptoLibHandle);
      end;

      if not Assigned(OBJ_txt2obj) then
      begin
        if Assigned(TS_REQ_free) then
          TS_REQ_free(Result);
        Exit(nil);
      end;

      Policy := OBJ_txt2obj(PAnsiChar(AnsiString(PolicyOID)), 1);
      if Policy = nil then
      begin
        if Assigned(TS_REQ_free) then
          TS_REQ_free(Result);
        Exit(nil);
      end;

      if TS_REQ_set_policy_id(Result, Policy) <> 1 then
      begin
        if Assigned(TS_REQ_free) then
          TS_REQ_free(Result);
        Exit(nil);
      end;

      // Note: ASN1_OBJECT_free may not be available, object will be freed with request
    end;
    // Set nonce (random number)
    if Assigned(TS_REQ_set_nonce) then
    begin
      FillChar(RandomBytes, SizeOf(RandomBytes), 0);
      if Assigned(RAND_bytes) then
        RAND_bytes(@RandomBytes[0], Length(RandomBytes))
      else
        PQWord(@RandomBytes[0])^ := QWord(GetTickCount64);

      Nonce := nil;

      // Prefer BN-based conversion for full 64-bit random nonce
      if not TOpenSSLLoader.IsModuleLoaded(osmBN) then
        LoadOpenSSLBN;

      if Assigned(BN_bin2bn) and Assigned(BN_to_ASN1_INTEGER) then
      begin
        NonceBN := BN_bin2bn(@RandomBytes[0], Length(RandomBytes), nil);
        if NonceBN <> nil then
        begin
          try
            Nonce := BN_to_ASN1_INTEGER(NonceBN, nil);
          finally
            if Assigned(BN_free) then
              BN_free(NonceBN);
          end;
        end;
      end;

      // Fallback path for environments where BN helpers are unavailable
      if (Nonce = nil) and Assigned(ASN1_INTEGER_new) and Assigned(ASN1_INTEGER_set) then
      begin
        Nonce := ASN1_INTEGER_new();
        if Nonce <> nil then
        begin
          if ASN1_INTEGER_set(Nonce,
            LongInt((LongWord(RandomBytes[4]) shl 24) or
                    (LongWord(RandomBytes[5]) shl 16) or
                    (LongWord(RandomBytes[6]) shl 8) or
                    LongWord(RandomBytes[7]))) <> 1 then
          begin
            if Assigned(ASN1_INTEGER_free) then
              ASN1_INTEGER_free(Nonce);
            Nonce := nil;
          end;
        end;
      end;

      if Nonce <> nil then
      begin
        if TS_REQ_set_nonce(Result, Nonce) <> 1 then
        begin
          if Assigned(ASN1_INTEGER_free) then
            ASN1_INTEGER_free(Nonce);
        end
        else if Assigned(ASN1_INTEGER_free) then
          ASN1_INTEGER_free(Nonce);
      end;
    end;
    
    // 请求包含证书
    if Assigned(TS_REQ_set_cert_req) then
      TS_REQ_set_cert_req(Result, 1);
      
  except
    if Assigned(TS_REQ_free) then
      TS_REQ_free(Result);
    Result := nil;
  end;
end;

function VerifyTimestampResponse(Response: PTS_RESP; Request: PTS_REQ; 
                                Store: PX509_STORE): Boolean;
var
  VerifyCtx: PTS_VERIFY_CTX;
  StatusInfo: PTS_STATUS_INFO;
  Status: PASN1_INTEGER;
  StatusValue: Integer;
  StatusInt64: Int64;
  StatusUInt64: UInt64;
  StatusExtracted: Boolean;
begin
  Result := False;
  
  if not Assigned(TS_RESP_get_status_info) or not Assigned(TS_STATUS_INFO_get0_status) then
    Exit;
  
  // 检查响应状?
  StatusInfo := TS_RESP_get_status_info(Response);
  if StatusInfo = nil then Exit;
  
  Status := TS_STATUS_INFO_get0_status(StatusInfo);
  if Status = nil then Exit;
  
  // Status check: only GRANTED / GRANTED_WITH_MODS may continue verification
  StatusExtracted := False;
  StatusValue := -1;

  if Assigned(ASN1_INTEGER_get_int64) then
  begin
    StatusInt64 := 0;
    if ASN1_INTEGER_get_int64(@StatusInt64, Status) = 1 then
    begin
      if (StatusInt64 >= Low(Integer)) and (StatusInt64 <= High(Integer)) then
      begin
        StatusValue := Integer(StatusInt64);
        StatusExtracted := True;
      end;
    end;
  end;

  if (not StatusExtracted) and Assigned(ASN1_INTEGER_get_uint64) then
  begin
    StatusUInt64 := 0;
    if ASN1_INTEGER_get_uint64(@StatusUInt64, Status) = 1 then
    begin
      if StatusUInt64 <= High(Integer) then
      begin
        StatusValue := Integer(StatusUInt64);
        StatusExtracted := True;
      end;
    end;
  end;

  if (not StatusExtracted) and Assigned(ASN1_INTEGER_get) then
  begin
    StatusValue := ASN1_INTEGER_get(Status);
    StatusExtracted := True;
  end;

  // Fail-safe: cannot extract status => reject
  if not StatusExtracted then
    Exit;

  // RFC3161 status gate
  if (StatusValue <> TS_STATUS_GRANTED) and
    (StatusValue <> TS_STATUS_GRANTED_WITH_MODS) then
    Exit;
  
  // 创建验证上下?
  if not Assigned(TS_VERIFY_CTX_new) then Exit;
  
  VerifyCtx := TS_VERIFY_CTX_new();
  if VerifyCtx = nil then Exit;
  
  try
    // 设置验证标志
    if Assigned(TS_VERIFY_CTX_set_flags) then
      TS_VERIFY_CTX_set_flags(VerifyCtx, TS_VFY_VERSION or TS_VFY_POLICY or 
                              TS_VFY_IMPRINT or TS_VFY_SIGNATURE);
    
    // 设置证书存储
    if (Store <> nil) and Assigned(TS_VERIFY_CTX_set_store) then
      TS_VERIFY_CTX_set_store(VerifyCtx, Store);
    
    // 执行验证
    if Assigned(TS_RESP_verify_response) then
      Result := TS_RESP_verify_response(VerifyCtx, Response) = 1;
      
  finally
    if Assigned(TS_VERIFY_CTX_free) then
      TS_VERIFY_CTX_free(VerifyCtx);
  end;
end;

function GetTimestampTime(Response: PTS_RESP): TDateTime;
var
  TstInfo: PTS_TST_INFO;
  GenTime: PASN1_GENERALIZEDTIME;
  TimeStr: string;
begin
  Result := 0;
  
  if not Assigned(TS_RESP_get_tst_info) or not Assigned(TS_TST_INFO_get_time) then
    Exit;
  
  TstInfo := TS_RESP_get_tst_info(Response);
  if TstInfo = nil then Exit;
  
  GenTime := TS_TST_INFO_get_time(TstInfo);
  if GenTime = nil then Exit;
  
  // Implemented: Convert ASN1_GENERALIZEDTIME to TDateTime
  // Parse time string format: YYYYMMDDhhmmss[.fff]Z
  if Assigned(ASN1_STRING_get0_data) then
  begin
    TimeStr := string(PAnsiChar(ASN1_STRING_get0_data(PASN1_STRING(GenTime))));
    if Length(TimeStr) >= 14 then
    begin
      try
        Result := EncodeDate(
          StrToInt(Copy(TimeStr, 1, 4)),
          StrToInt(Copy(TimeStr, 5, 2)),
          StrToInt(Copy(TimeStr, 7, 2))
        ) + EncodeTime(
          StrToInt(Copy(TimeStr, 9, 2)),
          StrToInt(Copy(TimeStr, 11, 2)),
          StrToInt(Copy(TimeStr, 13, 2)),
          0
        );
      except
        Result := 0;
      end;
    end;
  end;
end;

initialization
  
finalization
  UnloadTSFunctions;
  
end.
