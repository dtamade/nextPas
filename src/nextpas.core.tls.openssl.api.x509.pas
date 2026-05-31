unit nextpas.core.tls.openssl.api.x509;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, DynLibs, ctypes,
  nextpas.core.tls.openssl.base;

type
  { X509 Certificate Functions }
  TX509_new = function: PX509; cdecl;
  TX509_new_ex = function(libctx: Pointer; const propq: PAnsiChar): PX509; cdecl;
  TX509_free = procedure(x: PX509); cdecl;
  TX509_up_ref = function(x: PX509): Integer; cdecl;
  TX509_chain_up_ref = function(chain: PSTACK_OF_X509): PSTACK_OF_X509; cdecl;
  TX509_dup = function(x: PX509): PX509; cdecl;
  TX509_set_version = function(x: PX509; version: clong): Integer; cdecl;
  TX509_get_version = function(const x: PX509): clong; cdecl;
  TX509_set_serialNumber = function(x: PX509; serial: PASN1_INTEGER): Integer; cdecl;
  TX509_get_serialNumber = function(x: PX509): PASN1_INTEGER; cdecl;
  TX509_get0_serialNumber = function(const x: PX509): PASN1_INTEGER; cdecl;
  TX509_set_issuer_name = function(x: PX509; name: PX509_NAME): Integer; cdecl;
  TX509_get_issuer_name = function(const a: PX509): PX509_NAME; cdecl;
  TX509_set_subject_name = function(x: PX509; name: PX509_NAME): Integer; cdecl;
  TX509_get_subject_name = function(const a: PX509): PX509_NAME; cdecl;
  TX509_get0_notBefore = function(const x: PX509): PASN1_TIME; cdecl;
  TX509_get_notBefore = function(const x: PX509): PASN1_TIME; cdecl;
  TX509_getm_notBefore = function(const x: PX509): PASN1_TIME; cdecl;
  TX509_set1_notBefore = function(x: PX509; const tm: PASN1_TIME): Integer; cdecl;
  TX509_get0_notAfter = function(const x: PX509): PASN1_TIME; cdecl;
  TX509_get_notAfter = function(const x: PX509): PASN1_TIME; cdecl;
  TX509_getm_notAfter = function(const x: PX509): PASN1_TIME; cdecl;
  TX509_set1_notAfter = function(x: PX509; const tm: PASN1_TIME): Integer; cdecl;
  TX509_set_pubkey = function(x: PX509; pkey: PEVP_PKEY): Integer; cdecl;
  TX509_get_pubkey = function(x: PX509): PEVP_PKEY; cdecl;
  TX509_get0_pubkey = function(const x: PX509): PEVP_PKEY; cdecl;
  TX509_get_X509_PUBKEY = function(const x: PX509): Pointer; cdecl;
  TX509_get0_signature = procedure(const sig: PPASN1_BIT_STRING; const alg: PPointer; const x: PX509); cdecl;
  TX509_get_signature_nid = function(const x: PX509): Integer; cdecl;
  TX509_get_signature_type = function(const x: PX509): Integer; cdecl;
  TX509_get0_tbs_sigalg = function(const x: PX509): Pointer; cdecl;
  TX509_REQ_get0_signature = procedure(const req: PX509_REQ; const psig: PPASN1_BIT_STRING; const palg: PPointer); cdecl;
  TX509_REQ_get_signature_nid = function(const req: PX509_REQ): Integer; cdecl;
  Ti2d_re_X509_tbs = function(x: PX509; pp: PPByte): Integer; cdecl;
  TX509_get0_uids = procedure(const x: PX509; const piuid: PPASN1_BIT_STRING; const psuid: PPASN1_BIT_STRING); cdecl;
  TX509_get0_extensions = function(const x: PX509): PSTACK_OF_X509_EXTENSION; cdecl;
  
  TX509_get_extension_flags = function(x: PX509): UInt32; cdecl;
  TX509_get_key_usage = function(x: PX509): UInt32; cdecl;
  TX509_get_extended_key_usage = function(x: PX509): UInt32; cdecl;
  TX509_get0_subject_key_id = function(x: PX509): PASN1_OCTET_STRING; cdecl;
  TX509_get0_authority_key_id = function(x: PX509): PASN1_OCTET_STRING; cdecl;
  TX509_get0_authority_issuer = function(x: PX509): PGENERAL_NAMES; cdecl;
  TX509_get0_authority_serial = function(x: PX509): PASN1_INTEGER; cdecl;
  TX509_get_pathlen = function(x: PX509): clong; cdecl;
  TX509_get_proxy_pathlen = function(x: PX509): clong; cdecl;
  
  TX509_sign = function(x: PX509; pkey: PEVP_PKEY; const md: PEVP_MD): Integer; cdecl;
  TX509_sign_ctx = function(x: PX509; ctx: PEVP_MD_CTX): Integer; cdecl;
  TX509_REQ_sign = function(x: PX509_REQ; pkey: PEVP_PKEY; const md: PEVP_MD): Integer; cdecl;
  TX509_REQ_sign_ctx = function(x: PX509_REQ; ctx: PEVP_MD_CTX): Integer; cdecl;
  // X509 CRL functions
  TX509_CRL_new = function: PX509_CRL; cdecl;
  TX509_CRL_free = procedure(a: PX509_CRL); cdecl;
  TX509_CRL_sign = function(x: PX509_CRL; pkey: PEVP_PKEY; const md: PEVP_MD): Integer; cdecl;
  TX509_CRL_sign_ctx = function(x: PX509_CRL; ctx: PEVP_MD_CTX): Integer; cdecl;
  
  TX509_verify = function(a: PX509; r: PEVP_PKEY): Integer; cdecl;
  TX509_REQ_verify_ex = function(a: PX509_REQ; r: PEVP_PKEY; libctx: Pointer; const propq: PAnsiChar): Integer; cdecl;
  TX509_REQ_verify = function(a: PX509_REQ; r: PEVP_PKEY): Integer; cdecl;
  TX509_CRL_verify = function(a: PX509_CRL; r: PEVP_PKEY): Integer; cdecl;
  
  TX509_check_private_key = function(const x509: PX509; const pkey: PEVP_PKEY): Integer; cdecl;
  TX509_check_purpose = function(x: PX509; id: Integer; ca: Integer): Integer; cdecl;
  TX509_check_trust = function(x: PX509; id: Integer; flags: Integer): Integer; cdecl;
  TX509_check_issued = function(issuer: PX509; subject: PX509): Integer; cdecl;
  TX509_check_akid = function(issuer: PX509; akid: PAUTHORITY_KEYID): Integer; cdecl;
  TX509_check_ca = function(a: PX509): Integer; cdecl;
  TX509_check_host = function(x: PX509; const chk: PAnsiChar; chklen: size_t; flags: Cardinal; peername: PPAnsiChar): Integer; cdecl;
  TX509_check_email = function(x: PX509; const chk: PAnsiChar; chklen: size_t; flags: Cardinal): Integer; cdecl;
  TX509_check_ip = function(x: PX509; const chk: PByte; chklen: size_t; flags: Cardinal): Integer; cdecl;
  TX509_check_ip_asc = function(x: PX509; const ipasc: PAnsiChar; flags: Cardinal): Integer; cdecl;
  
  TX509_print = function(bp: PBIO; x: PX509): Integer; cdecl;
  TX509_print_ex = function(bp: PBIO; x: PX509; nmflag: LongWord; cflag: LongWord): Integer; cdecl;
  TX509_print_fp = function(bp: Pointer; x: PX509): Integer; cdecl;
  TX509_print_ex_fp = function(bp: Pointer; x: PX509; nmflag: LongWord; cflag: LongWord): Integer; cdecl;
  TX509_CRL_print = function(bp: PBIO; x: PX509_CRL): Integer; cdecl;
  TX509_CRL_print_fp = function(fp: Pointer; x: PX509_CRL): Integer; cdecl;
  TX509_CRL_print_ex = function(&out: PBIO; x: PX509_CRL; nmflag: LongWord): Integer; cdecl;
  TX509_REQ_print = function(bp: PBIO; req: PX509_REQ): Integer; cdecl;
  TX509_REQ_print_ex = function(bp: PBIO; x: PX509_REQ; nmflag: LongWord; cflag: LongWord): Integer; cdecl;
  TX509_REQ_print_fp = function(fp: Pointer; req: PX509_REQ): Integer; cdecl;
  
  TX509_get_pubkey_parameters = function(pkey: PEVP_PKEY; chain: PSTACK_OF_X509): Integer; cdecl;
  TX509_ocspid_print = function(bp: PBIO; x: PX509): Integer; cdecl;
  TX509_CRL_get0_by_serial = function(crl: PX509_CRL; ret: PPPointer; const serial: PASN1_INTEGER): Integer; cdecl;
  TX509_CRL_get0_by_cert = function(crl: PX509_CRL; ret: PPPointer; x: PX509): Integer; cdecl;
  TX509_CRL_get_REVOKED = function(crl: PX509_CRL): Pointer; cdecl;
  TX509_CRL_get0_extensions = function(const crl: PX509_CRL): PSTACK_OF_X509_EXTENSION; cdecl;
  TX509_CRL_get0_signature = procedure(const crl: PX509_CRL; const psig: PPASN1_BIT_STRING; const palg: PPointer); cdecl;
  TX509_CRL_get_signature_nid = function(const crl: PX509_CRL): Integer; cdecl;
  TX509_CRL_get0_lastUpdate = function(const crl: PX509_CRL): PASN1_TIME; cdecl;
  TX509_CRL_get0_nextUpdate = function(const crl: PX509_CRL): PASN1_TIME; cdecl;
  TX509_CRL_set1_lastUpdate = function(x: PX509_CRL; const tm: PASN1_TIME): Integer; cdecl;
  TX509_CRL_set1_nextUpdate = function(x: PX509_CRL; const tm: PASN1_TIME): Integer; cdecl;
  
  TX509_REVOKED_new = function: Pointer; cdecl;
  TX509_REVOKED_free = procedure(a: Pointer); cdecl;
  TX509_REVOKED_dup = function(a: Pointer): Pointer; cdecl;
  TX509_REVOKED_get0_serialNumber = function(const x: Pointer): PASN1_INTEGER; cdecl;
  TX509_REVOKED_set_serialNumber = function(x: Pointer; serial: PASN1_INTEGER): Integer; cdecl;
  TX509_REVOKED_get0_revocationDate = function(const x: Pointer): PASN1_TIME; cdecl;
  TX509_REVOKED_set_revocationDate = function(r: Pointer; tm: PASN1_TIME): Integer; cdecl;
  TX509_REVOKED_get0_extensions = function(const r: Pointer): PSTACK_OF_X509_EXTENSION; cdecl;
  
  TX509_CRL_add0_revoked = function(crl: PX509_CRL; rev: Pointer): Integer; cdecl;
  TX509_CRL_get0_issuer = function(const crl: PX509_CRL): PX509_NAME; cdecl;
  TX509_CRL_get_version = function(const crl: PX509_CRL): clong; cdecl;
  TX509_CRL_get_issuer = function(const crl: PX509_CRL): PX509_NAME; cdecl;
  TX509_CRL_set_version = function(x: PX509_CRL; version: clong): Integer; cdecl;
  TX509_CRL_set_issuer_name = function(x: PX509_CRL; name: PX509_NAME): Integer; cdecl;
  TX509_CRL_sort = function(crl: PX509_CRL): Integer; cdecl;
  TX509_CRL_up_ref = function(crl: PX509_CRL): Integer; cdecl;
  
  TX509_get_signature_info = function(x: PX509; mdnid: PInteger; pknid: PInteger; secbits: PInteger; flags: PUInt32): Integer; cdecl;
  TX509_get0_distinguishing_id = procedure(x: PX509; distinguishing_id: PPASN1_OCTET_STRING); cdecl;
  TX509_set0_distinguishing_id = procedure(x: PX509; distinguishing_id: PASN1_OCTET_STRING); cdecl;
  TX509_REQ_get0_distinguishing_id = procedure(x: PX509_REQ; distinguishing_id: PPASN1_OCTET_STRING); cdecl;
  TX509_REQ_set0_distinguishing_id = procedure(x: PX509_REQ; distinguishing_id: PASN1_OCTET_STRING); cdecl;
  
  TX509_cmp_time = function(const s: PASN1_TIME; t: Ptime_t): Integer; cdecl;
  TX509_cmp_current_time = function(const s: PASN1_TIME): Integer; cdecl;
  TX509_cmp_timeframe = function(const vpm: PX509_VERIFY_PARAM; const start: PASN1_TIME; const &end: PASN1_TIME): Integer; cdecl;
  TX509_time_adj = function(s: PASN1_TIME; adj: clong; t: Ptime_t): PASN1_TIME; cdecl;
  TX509_time_adj_ex = function(s: PASN1_TIME; offset_day: Integer; offset_sec: clong; t: Ptime_t): PASN1_TIME; cdecl;
  TX509_gmtime_adj = function(s: PASN1_TIME; adj: clong): PASN1_TIME; cdecl;
  
  TX509_get_default_cert_area = function: PAnsiChar; cdecl;
  TX509_get_default_cert_dir = function: PAnsiChar; cdecl;
  TX509_get_default_cert_file = function: PAnsiChar; cdecl;
  TX509_get_default_cert_dir_env = function: PAnsiChar; cdecl;
  TX509_get_default_cert_file_env = function: PAnsiChar; cdecl;
  TX509_get_default_private_dir = function: PAnsiChar; cdecl;
  
  TX509_to_X509_REQ = function(x: PX509; pkey: PEVP_PKEY; const md: PEVP_MD): PX509_REQ; cdecl;
  TX509_REQ_to_X509 = function(r: PX509_REQ; days: Integer; pkey: PEVP_PKEY): PX509; cdecl;
  
  TX509_ALGOR_dup = function(xn: Pointer): Pointer; cdecl;
  TX509_ALGOR_set0 = function(alg: Pointer; aobj: PASN1_OBJECT; ptype: Integer; pval: Pointer): Integer; cdecl;
  TX509_ALGOR_get0 = procedure(const paobj: PPASN1_OBJECT; pptype: PInteger; const ppval: PPointer; const algor: Pointer); cdecl;
  TX509_ALGOR_set_md = procedure(alg: Pointer; const md: PEVP_MD); cdecl;
  TX509_ALGOR_cmp = function(const a: Pointer; const b: Pointer): Integer; cdecl;
  TX509_ALGOR_copy = function(dest: Pointer; const src: Pointer): Integer; cdecl;
  
  TX509_cmp = function(const a: PX509; const b: PX509): Integer; cdecl;
  TX509_NAME_cmp = function(const a: PX509_NAME; const b: PX509_NAME): Integer; cdecl;
  TX509_NAME_hash_old = function(x: PX509_NAME): LongWord; cdecl;
  TX509_issuer_name_cmp = function(const a: PX509; const b: PX509): Integer; cdecl;
  TX509_subject_name_cmp = function(const a: PX509; const b: PX509): Integer; cdecl;
  TX509_CRL_cmp = function(const a: PX509_CRL; const b: PX509_CRL): Integer; cdecl;
  TX509_CRL_match = function(const a: PX509_CRL; const b: PX509_CRL): Integer; cdecl;
  TX509_policy_check = function(policy_tree: PPointer; pexplicit_policy: PInteger; certs: PSTACK_OF_X509; policy_oids: Pointer; flags: Cardinal): Integer; cdecl;
  TX509_policy_tree_free = procedure(tree: Pointer); cdecl;
  TX509_policy_tree_level_count = function(const tree: Pointer): Integer; cdecl;
  TX509_policy_tree_get0_level = function(const tree: Pointer; i: Integer): Pointer; cdecl;
  TX509_policy_level_node_count = function(level: Pointer): Integer; cdecl;
  TX509_policy_level_get0_node = function(const level: Pointer; i: Integer): Pointer; cdecl;
  TX509_policy_node_get0_policy = function(const node: Pointer): PASN1_OBJECT; cdecl;
  TX509_policy_node_get0_qualifiers = function(const node: Pointer): Pointer; cdecl;
  TX509_policy_node_get0_parent = function(const node: Pointer): Pointer; cdecl;
  
  { X509 Name Functions }
  TX509_NAME_new = function: PX509_NAME; cdecl;
  TX509_NAME_free = procedure(a: PX509_NAME); cdecl;
  TX509_NAME_dup = function(xn: PX509_NAME): PX509_NAME; cdecl;
  TX509_NAME_hash = function(x: PX509_NAME): LongWord; cdecl;
  TX509_NAME_hash_ex = function(x: PX509_NAME; libctx: Pointer; const propq: PAnsiChar; ok: PInteger): LongWord; cdecl;
  TX509_NAME_entry_count = function(const name: PX509_NAME): Integer; cdecl;
  TX509_NAME_get_index_by_NID = function(const name: PX509_NAME; nid: Integer; lastpos: Integer): Integer; cdecl;
  TX509_NAME_get_index_by_OBJ = function(const name: PX509_NAME; const obj: PASN1_OBJECT; lastpos: Integer): Integer; cdecl;
  TX509_NAME_get_entry = function(const name: PX509_NAME; loc: Integer): PX509_NAME_ENTRY; cdecl;
  TX509_NAME_delete_entry = function(name: PX509_NAME; loc: Integer): PX509_NAME_ENTRY; cdecl;
  TX509_NAME_add_entry = function(name: PX509_NAME; const ne: PX509_NAME_ENTRY; loc: Integer; &set: Integer): Integer; cdecl;
  TX509_NAME_add_entry_by_OBJ = function(name: PX509_NAME; const obj: PASN1_OBJECT; &type: Integer; const bytes: PByte; len: Integer; loc: Integer; &set: Integer): Integer; cdecl;
  TX509_NAME_add_entry_by_NID = function(name: PX509_NAME; nid: Integer; &type: Integer; const bytes: PByte; len: Integer; loc: Integer; &set: Integer): Integer; cdecl;
  TX509_NAME_add_entry_by_txt = function(name: PX509_NAME; const field: PAnsiChar; &type: Integer; const bytes: PByte; len: Integer; loc: Integer; &set: Integer): Integer; cdecl;
  TX509_NAME_oneline = function(const a: PX509_NAME; buf: PAnsiChar; size: Integer): PAnsiChar; cdecl;
  TX509_NAME_print = function(bp: PBIO; const name: PX509_NAME; obase: Integer): Integer; cdecl;
  TX509_NAME_print_ex = function(&out: PBIO; const nm: PX509_NAME; indent: Integer; flags: LongWord): Integer; cdecl;
  TX509_NAME_print_ex_fp = function(fp: Pointer; const nm: PX509_NAME; indent: Integer; flags: LongWord): Integer; cdecl;
  TX509_NAME_get_text_by_NID = function(name: PX509_NAME; nid: Integer; buf: PAnsiChar; len: Integer): Integer; cdecl;
  TX509_NAME_get_text_by_OBJ = function(name: PX509_NAME; const obj: PASN1_OBJECT; buf: PAnsiChar; len: Integer): Integer; cdecl;
  TX509_NAME_get0_der = function(nm: PX509_NAME; const pder: PPByte; pderlen: Psize_t): Integer; cdecl;
  
  { X509 Name Entry Functions }
  TX509_NAME_ENTRY_new = function: PX509_NAME_ENTRY; cdecl;
  TX509_NAME_ENTRY_free = procedure(a: PX509_NAME_ENTRY); cdecl;
  TX509_NAME_ENTRY_dup = function(ne: PX509_NAME_ENTRY): PX509_NAME_ENTRY; cdecl;
  TX509_NAME_ENTRY_get_object = function(const ne: PX509_NAME_ENTRY): PASN1_OBJECT; cdecl;
  TX509_NAME_ENTRY_get_data = function(const ne: PX509_NAME_ENTRY): PASN1_STRING; cdecl;
  TX509_NAME_ENTRY_set = function(const ne: PX509_NAME_ENTRY): Integer; cdecl;
  TX509_NAME_ENTRY_set_object = function(ne: PX509_NAME_ENTRY; const obj: PASN1_OBJECT): Integer; cdecl;
  TX509_NAME_ENTRY_set_data = function(ne: PX509_NAME_ENTRY; &type: Integer; const bytes: PByte; len: Integer): Integer; cdecl;
  TX509_NAME_ENTRY_create_by_txt = function(ne: PPX509_NAME_ENTRY; const field: PAnsiChar; &type: Integer; const bytes: PByte; len: Integer): PX509_NAME_ENTRY; cdecl;
  TX509_NAME_ENTRY_create_by_NID = function(ne: PPX509_NAME_ENTRY; nid: Integer; &type: Integer; const bytes: PByte; len: Integer): PX509_NAME_ENTRY; cdecl;
  TX509_NAME_ENTRY_create_by_OBJ = function(ne: PPX509_NAME_ENTRY; const obj: PASN1_OBJECT; &type: Integer; const bytes: PByte; len: Integer): PX509_NAME_ENTRY; cdecl;
  
  { X509 Extension Functions }
  TX509_EXTENSION_new = function: PX509_EXTENSION; cdecl;
  TX509_EXTENSION_free = procedure(a: PX509_EXTENSION); cdecl;
  TX509_EXTENSION_dup = function(ex: PX509_EXTENSION): PX509_EXTENSION; cdecl;
  TX509_EXTENSION_create_by_NID = function(ex: PPX509_EXTENSION; nid: Integer; crit: Integer; data: PASN1_OCTET_STRING): PX509_EXTENSION; cdecl;
  TX509_EXTENSION_create_by_OBJ = function(ex: PPX509_EXTENSION; const obj: PASN1_OBJECT; crit: Integer; data: PASN1_OCTET_STRING): PX509_EXTENSION; cdecl;
  TX509_EXTENSION_set_object = function(ex: PX509_EXTENSION; const obj: PASN1_OBJECT): Integer; cdecl;
  TX509_EXTENSION_set_critical = function(ex: PX509_EXTENSION; crit: Integer): Integer; cdecl;
  TX509_EXTENSION_set_data = function(ex: PX509_EXTENSION; data: PASN1_OCTET_STRING): Integer; cdecl;
  TX509_EXTENSION_get_object = function(ex: PX509_EXTENSION): PASN1_OBJECT; cdecl;
  TX509_EXTENSION_get_data = function(ne: PX509_EXTENSION): PASN1_OCTET_STRING; cdecl;
  TX509_EXTENSION_get_critical = function(const ex: PX509_EXTENSION): Integer; cdecl;
  
  TX509v3_get_ext_count = function(const x: PSTACK_OF_X509_EXTENSION): Integer; cdecl;
  TX509v3_get_ext_by_NID = function(const x: PSTACK_OF_X509_EXTENSION; nid: Integer; lastpos: Integer): Integer; cdecl;
  TX509v3_get_ext_by_OBJ = function(const x: PSTACK_OF_X509_EXTENSION; const obj: PASN1_OBJECT; lastpos: Integer): Integer; cdecl;
  TX509v3_get_ext_by_critical = function(const x: PSTACK_OF_X509_EXTENSION; crit: Integer; lastpos: Integer): Integer; cdecl;
  TX509v3_get_ext = function(const x: PSTACK_OF_X509_EXTENSION; loc: Integer): PX509_EXTENSION; cdecl;
  TX509v3_delete_ext = function(x: PSTACK_OF_X509_EXTENSION; loc: Integer): PX509_EXTENSION; cdecl;
  TX509v3_add_ext = function(x: PPSTACK_OF_X509_EXTENSION; ex: PX509_EXTENSION; loc: Integer): PSTACK_OF_X509_EXTENSION; cdecl;
  
  TX509_get_ext_count = function(const x: PX509): Integer; cdecl;
  TX509_get_ext_by_NID = function(const x: PX509; nid: Integer; lastpos: Integer): Integer; cdecl;
  TX509_get_ext_by_OBJ = function(const x: PX509; const obj: PASN1_OBJECT; lastpos: Integer): Integer; cdecl;
  TX509_get_ext_by_critical = function(const x: PX509; crit: Integer; lastpos: Integer): Integer; cdecl;
  TX509_get_ext = function(const x: PX509; loc: Integer): PX509_EXTENSION; cdecl;
  TX509_delete_ext = function(x: PX509; loc: Integer): PX509_EXTENSION; cdecl;
  TX509_add_ext = function(x: PX509; ex: PX509_EXTENSION; loc: Integer): Integer; cdecl;
  TX509_get_ext_d2i = function(const x: PX509; nid: Integer; crit: PInteger; idx: PInteger): Pointer; cdecl;
  TX509_add1_ext_i2d = function(x: PX509; nid: Integer; value: Pointer; crit: Integer; flags: LongWord): Integer; cdecl;
  
  TX509_CRL_get_ext_count = function(const x: PX509_CRL): Integer; cdecl;
  TX509_CRL_get_ext_by_NID = function(const x: PX509_CRL; nid: Integer; lastpos: Integer): Integer; cdecl;
  TX509_CRL_get_ext_by_OBJ = function(const x: PX509_CRL; const obj: PASN1_OBJECT; lastpos: Integer): Integer; cdecl;
  TX509_CRL_get_ext_by_critical = function(const x: PX509_CRL; crit: Integer; lastpos: Integer): Integer; cdecl;
  TX509_CRL_get_ext = function(const x: PX509_CRL; loc: Integer): PX509_EXTENSION; cdecl;
  TX509_CRL_delete_ext = function(x: PX509_CRL; loc: Integer): PX509_EXTENSION; cdecl;
  TX509_CRL_add_ext = function(x: PX509_CRL; ex: PX509_EXTENSION; loc: Integer): Integer; cdecl;
  TX509_CRL_get_ext_d2i = function(const x: PX509_CRL; nid: Integer; crit: PInteger; idx: PInteger): Pointer; cdecl;
  TX509_CRL_add1_ext_i2d = function(x: PX509_CRL; nid: Integer; value: Pointer; crit: Integer; flags: LongWord): Integer; cdecl;
  
  TX509_REVOKED_get_ext_count = function(const x: Pointer): Integer; cdecl;
  TX509_REVOKED_get_ext_by_NID = function(const x: Pointer; nid: Integer; lastpos: Integer): Integer; cdecl;
  TX509_REVOKED_get_ext_by_OBJ = function(const x: Pointer; const obj: PASN1_OBJECT; lastpos: Integer): Integer; cdecl;
  TX509_REVOKED_get_ext_by_critical = function(const x: Pointer; crit: Integer; lastpos: Integer): Integer; cdecl;
  TX509_REVOKED_get_ext = function(const x: Pointer; loc: Integer): PX509_EXTENSION; cdecl;
  TX509_REVOKED_delete_ext = function(x: Pointer; loc: Integer): PX509_EXTENSION; cdecl;
  TX509_REVOKED_add_ext = function(x: Pointer; ex: PX509_EXTENSION; loc: Integer): Integer; cdecl;
  TX509_REVOKED_get_ext_d2i = function(const x: Pointer; nid: Integer; crit: PInteger; idx: PInteger): Pointer; cdecl;
  TX509_REVOKED_add1_ext_i2d = function(x: Pointer; nid: Integer; value: Pointer; crit: Integer; flags: LongWord): Integer; cdecl;
  
  { X509 Store Functions }
  TX509_STORE_new = function: PX509_STORE; cdecl;
  TX509_STORE_free = procedure(v: PX509_STORE); cdecl;
  TX509_STORE_lock = function(ctx: PX509_STORE): Integer; cdecl;
  TX509_STORE_unlock = function(ctx: PX509_STORE): Integer; cdecl;
  TX509_STORE_up_ref = function(v: PX509_STORE): Integer; cdecl;
  TX509_STORE_get0_objects = function(const v: PX509_STORE): Pointer; cdecl;
  TX509_STORE_get1_all_certs = function(st: PX509_STORE): PSTACK_OF_X509; cdecl;
  TX509_STORE_set_flags = function(ctx: PX509_STORE; flags: LongWord): Integer; cdecl;
  TX509_STORE_set_purpose = function(ctx: PX509_STORE; purpose: Integer): Integer; cdecl;
  TX509_STORE_set_trust = function(ctx: PX509_STORE; trust: Integer): Integer; cdecl;
  TX509_STORE_set1_param = function(ctx: PX509_STORE; pm: PX509_VERIFY_PARAM): Integer; cdecl;
  TX509_STORE_get0_param = function(ctx: PX509_STORE): PX509_VERIFY_PARAM; cdecl;
  TX509_STORE_set_verify = procedure(ctx: PX509_STORE; verify: TX509_STORE_CTX_verify_fn); cdecl;
  TX509_STORE_get_verify = function(ctx: PX509_STORE): TX509_STORE_CTX_verify_fn; cdecl;
  TX509_STORE_set_verify_cb = procedure(ctx: PX509_STORE; verify_cb: TX509_STORE_CTX_verify_cb); cdecl;
  TX509_STORE_get_verify_cb = function(ctx: PX509_STORE): TX509_STORE_CTX_verify_cb; cdecl;
  TX509_STORE_set_get_issuer = procedure(ctx: PX509_STORE; get_issuer: TX509_STORE_CTX_get_issuer_fn); cdecl;
  TX509_STORE_get_get_issuer = function(ctx: PX509_STORE): TX509_STORE_CTX_get_issuer_fn; cdecl;
  TX509_STORE_set_check_issued = procedure(ctx: PX509_STORE; check_issued: TX509_STORE_CTX_check_issued_fn); cdecl;
  TX509_STORE_get_check_issued = function(ctx: PX509_STORE): TX509_STORE_CTX_check_issued_fn; cdecl;
  TX509_STORE_set_check_revocation = procedure(ctx: PX509_STORE; check_revocation: TX509_STORE_CTX_check_revocation_fn); cdecl;
  TX509_STORE_get_check_revocation = function(ctx: PX509_STORE): TX509_STORE_CTX_check_revocation_fn; cdecl;
  TX509_STORE_set_get_crl = procedure(ctx: PX509_STORE; get_crl: TX509_STORE_CTX_get_crl_fn); cdecl;
  TX509_STORE_get_get_crl = function(ctx: PX509_STORE): TX509_STORE_CTX_get_crl_fn; cdecl;
  TX509_STORE_set_check_crl = procedure(ctx: PX509_STORE; check_crl: TX509_STORE_CTX_check_crl_fn); cdecl;
  TX509_STORE_get_check_crl = function(ctx: PX509_STORE): TX509_STORE_CTX_check_crl_fn; cdecl;
  TX509_STORE_set_cert_crl = procedure(ctx: PX509_STORE; cert_crl: TX509_STORE_CTX_cert_crl_fn); cdecl;
  TX509_STORE_get_cert_crl = function(ctx: PX509_STORE): TX509_STORE_CTX_cert_crl_fn; cdecl;
  TX509_STORE_set_check_policy = procedure(ctx: PX509_STORE; check_policy: TX509_STORE_CTX_check_policy_fn); cdecl;
  TX509_STORE_get_check_policy = function(ctx: PX509_STORE): TX509_STORE_CTX_check_policy_fn; cdecl;
  TX509_STORE_set_lookup_certs = procedure(ctx: PX509_STORE; lookup: TX509_STORE_CTX_lookup_certs_fn); cdecl;
  TX509_STORE_get_lookup_certs = function(ctx: PX509_STORE): TX509_STORE_CTX_lookup_certs_fn; cdecl;
  TX509_STORE_set_lookup_crls = procedure(ctx: PX509_STORE; lookup: TX509_STORE_CTX_lookup_crls_fn); cdecl;
  TX509_STORE_get_lookup_crls = function(ctx: PX509_STORE): TX509_STORE_CTX_lookup_crls_fn; cdecl;
  TX509_STORE_set_cleanup = procedure(ctx: PX509_STORE; cleanup: TX509_STORE_CTX_cleanup_fn); cdecl;
  TX509_STORE_get_cleanup = function(ctx: PX509_STORE): TX509_STORE_CTX_cleanup_fn; cdecl;
  TX509_STORE_set_ex_data = function(ctx: PX509_STORE; idx: Integer; data: Pointer): Integer; cdecl;
  TX509_STORE_get_ex_data = function(const ctx: PX509_STORE; idx: Integer): Pointer; cdecl;
  
  TX509_STORE_add_cert = function(ctx: PX509_STORE; x: PX509): Integer; cdecl;
  TX509_STORE_add_crl = function(ctx: PX509_STORE; x: PX509_CRL): Integer; cdecl;
  TX509_STORE_load_file = function(ctx: PX509_STORE; const &file: PAnsiChar): Integer; cdecl;
  TX509_STORE_load_path = function(ctx: PX509_STORE; const path: PAnsiChar): Integer; cdecl;
  TX509_STORE_load_store = function(ctx: PX509_STORE; const store: PAnsiChar): Integer; cdecl;
  TX509_STORE_load_locations = function(ctx: PX509_STORE; const &file: PAnsiChar; const path: PAnsiChar): Integer; cdecl;
  TX509_STORE_set_default_paths = function(ctx: PX509_STORE): Integer; cdecl;
  
  TX509_STORE_load_file_ex = function(ctx: PX509_STORE; const &file: PAnsiChar; libctx: Pointer; const propq: PAnsiChar): Integer; cdecl;
  TX509_STORE_load_store_ex = function(ctx: PX509_STORE; const store: PAnsiChar; libctx: Pointer; const propq: PAnsiChar): Integer; cdecl;
  TX509_STORE_load_locations_ex = function(ctx: PX509_STORE; const &file: PAnsiChar; const dir: PAnsiChar; libctx: Pointer; const propq: PAnsiChar): Integer; cdecl;
  TX509_STORE_set_default_paths_ex = function(ctx: PX509_STORE; libctx: Pointer; const propq: PAnsiChar): Integer; cdecl;
  
  { X509 Store Context Functions }
  TX509_STORE_CTX_new_ex = function(libctx: Pointer; const propq: PAnsiChar): PX509_STORE_CTX; cdecl;
  TX509_STORE_CTX_new = function: PX509_STORE_CTX; cdecl;
  TX509_STORE_CTX_free = procedure(ctx: PX509_STORE_CTX); cdecl;
  TX509_STORE_CTX_init = function(ctx: PX509_STORE_CTX; trust_store: PX509_STORE; target: PX509; untrusted: PSTACK_OF_X509): Integer; cdecl;
  TX509_STORE_CTX_set = procedure(ctx: PX509_STORE_CTX; trust_store: PX509_STORE; target: PX509; untrusted: PSTACK_OF_X509); cdecl;
  TX509_STORE_CTX_set0_trusted_stack = procedure(ctx: PX509_STORE_CTX; sk: PSTACK_OF_X509); cdecl;
  TX509_STORE_CTX_cleanup = procedure(ctx: PX509_STORE_CTX); cdecl;
  TX509_STORE_CTX_get0_store = function(ctx: PX509_STORE_CTX): PX509_STORE; cdecl;
  TX509_STORE_CTX_get0_cert = function(const ctx: PX509_STORE_CTX): PX509; cdecl;
  TX509_STORE_CTX_get0_untrusted = function(const ctx: PX509_STORE_CTX): PSTACK_OF_X509; cdecl;
  TX509_STORE_CTX_set0_untrusted = procedure(ctx: PX509_STORE_CTX; sk: PSTACK_OF_X509); cdecl;
  TX509_STORE_CTX_get0_param = function(const ctx: PX509_STORE_CTX): PX509_VERIFY_PARAM; cdecl;
  TX509_STORE_CTX_set0_param = procedure(ctx: PX509_STORE_CTX; param: PX509_VERIFY_PARAM); cdecl;
  TX509_STORE_CTX_set0_dane = function(ctx: PX509_STORE_CTX; dane: Pointer): Integer; cdecl;
  TX509_STORE_CTX_set_default = function(ctx: PX509_STORE_CTX; const name: PAnsiChar): Integer; cdecl;
  TX509_STORE_CTX_set_verify = procedure(ctx: PX509_STORE_CTX; verify: TX509_STORE_CTX_verify_fn); cdecl;
  TX509_STORE_CTX_get_verify = function(ctx: PX509_STORE_CTX): TX509_STORE_CTX_verify_fn; cdecl;
  TX509_STORE_CTX_set_verify_cb = procedure(ctx: PX509_STORE_CTX; verify: TX509_STORE_CTX_verify_cb); cdecl;
  TX509_STORE_CTX_get_verify_cb = function(ctx: PX509_STORE_CTX): TX509_STORE_CTX_verify_cb; cdecl;
  TX509_STORE_CTX_set_cert = procedure(ctx: PX509_STORE_CTX; x: PX509); cdecl;
  TX509_STORE_CTX_set0_crls = procedure(ctx: PX509_STORE_CTX; sk: Pointer); cdecl;
  TX509_STORE_CTX_set_purpose = function(ctx: PX509_STORE_CTX; purpose: Integer): Integer; cdecl;
  TX509_STORE_CTX_set_trust = function(ctx: PX509_STORE_CTX; trust: Integer): Integer; cdecl;
  TX509_STORE_CTX_set_flags = procedure(ctx: PX509_STORE_CTX; flags: LongWord); cdecl;
  TX509_STORE_CTX_get_num_untrusted = function(const ctx: PX509_STORE_CTX): Integer; cdecl;
  TX509_STORE_CTX_set_time = procedure(ctx: PX509_STORE_CTX; flags: LongWord; t: time_t); cdecl;
  TX509_STORE_CTX_get0_policy_tree = function(ctx: PX509_STORE_CTX): Pointer; cdecl;
  TX509_STORE_CTX_get_explicit_policy = function(ctx: PX509_STORE_CTX): Integer; cdecl;
  TX509_STORE_CTX_get_current_cert = function(const ctx: PX509_STORE_CTX): PX509; cdecl;
  TX509_STORE_CTX_get0_current_issuer = function(const ctx: PX509_STORE_CTX): PX509; cdecl;
  TX509_STORE_CTX_get0_current_crl = function(const ctx: PX509_STORE_CTX): PX509_CRL; cdecl;
  TX509_STORE_CTX_get0_parent_ctx = function(const ctx: PX509_STORE_CTX): PX509_STORE_CTX; cdecl;
  TX509_STORE_CTX_get0_chain = function(ctx: PX509_STORE_CTX): PSTACK_OF_X509; cdecl;
  TX509_STORE_CTX_get1_chain = function(ctx: PX509_STORE_CTX): PSTACK_OF_X509; cdecl;
  TX509_STORE_CTX_set0_verified_chain = procedure(ctx: PX509_STORE_CTX; sk: PSTACK_OF_X509); cdecl;
  TX509_STORE_CTX_get_error = function(const ctx: PX509_STORE_CTX): Integer; cdecl;
  TX509_STORE_CTX_set_error = procedure(ctx: PX509_STORE_CTX; s: Integer); cdecl;
  TX509_STORE_CTX_get_error_depth = function(const ctx: PX509_STORE_CTX): Integer; cdecl;
  TX509_STORE_CTX_set_error_depth = procedure(ctx: PX509_STORE_CTX; depth: Integer); cdecl;
  TX509_STORE_CTX_set_current_cert = procedure(ctx: PX509_STORE_CTX; x: PX509); cdecl;
  TX509_STORE_CTX_set_ex_data = function(ctx: PX509_STORE_CTX; idx: Integer; data: Pointer): Integer; cdecl;
  TX509_STORE_CTX_get_ex_data = function(const ctx: PX509_STORE_CTX; idx: Integer): Pointer; cdecl;
  TX509_STORE_CTX_get_check_issued = function(const ctx: PX509_STORE_CTX): TX509_STORE_CTX_check_issued_fn; cdecl;
  TX509_STORE_CTX_get_check_revocation = function(const ctx: PX509_STORE_CTX): TX509_STORE_CTX_check_revocation_fn; cdecl;
  TX509_STORE_CTX_get_get_crl = function(const ctx: PX509_STORE_CTX): TX509_STORE_CTX_get_crl_fn; cdecl;
  TX509_STORE_CTX_get_check_crl = function(const ctx: PX509_STORE_CTX): TX509_STORE_CTX_check_crl_fn; cdecl;
  TX509_STORE_CTX_get_cert_crl = function(const ctx: PX509_STORE_CTX): TX509_STORE_CTX_cert_crl_fn; cdecl;
  TX509_STORE_CTX_get_check_policy = function(const ctx: PX509_STORE_CTX): TX509_STORE_CTX_check_policy_fn; cdecl;
  TX509_STORE_CTX_get_lookup_certs = function(const ctx: PX509_STORE_CTX): TX509_STORE_CTX_lookup_certs_fn; cdecl;
  TX509_STORE_CTX_get_lookup_crls = function(const ctx: PX509_STORE_CTX): TX509_STORE_CTX_lookup_crls_fn; cdecl;
  TX509_STORE_CTX_get_cleanup = function(const ctx: PX509_STORE_CTX): TX509_STORE_CTX_cleanup_fn; cdecl;
  
  { X509 Verification Functions }
  TX509_verify_cert = function(ctx: PX509_STORE_CTX): Integer; cdecl;
  TX509_STORE_CTX_verify = function(ctx: PX509_STORE_CTX): Integer; cdecl;
  TX509_STORE_CTX_verify_fn = function(ctx: PX509_STORE_CTX): Integer; cdecl;
  TX509_STORE_CTX_get0_issuer = function(issuer: PPX509; ctx: PX509_STORE_CTX; x: PX509): Integer; cdecl;
  TX509_verify_cert_error_string = function(n: clong): PAnsiChar; cdecl;
  // TX509_verify already defined above at line 68
  TX509_self_signed = function(cert: PX509; verify_signature: Integer): Integer; cdecl;
  TX509_store_ctx_get_issuer_fn = function(ctx: PX509_STORE_CTX; x: PX509): PX509; cdecl;
  TX509_STORE_get_by_subject = function(vs: PX509_STORE; type_: Integer; name: PX509_NAME; ret: PX509_OBJECT): Integer; cdecl;
  TX509_STORE_CTX_get_by_subject = function(vs: PX509_STORE_CTX; type_: Integer; name: PX509_NAME; ret: PX509_OBJECT): Integer; cdecl;
  
  { X509 Verify Param Functions }
  TX509_VERIFY_PARAM_new = function: PX509_VERIFY_PARAM; cdecl;
  TX509_VERIFY_PARAM_free = procedure(param: PX509_VERIFY_PARAM); cdecl;
  TX509_VERIFY_PARAM_inherit = function(&to: PX509_VERIFY_PARAM; const from: PX509_VERIFY_PARAM): Integer; cdecl;
  TX509_VERIFY_PARAM_set1 = function(&to: PX509_VERIFY_PARAM; const from: PX509_VERIFY_PARAM): Integer; cdecl;
  TX509_VERIFY_PARAM_set1_name = function(param: PX509_VERIFY_PARAM; const name: PAnsiChar): Integer; cdecl;
  TX509_VERIFY_PARAM_set_flags = function(param: PX509_VERIFY_PARAM; flags: LongWord): Integer; cdecl;
  TX509_VERIFY_PARAM_clear_flags = function(param: PX509_VERIFY_PARAM; flags: LongWord): Integer; cdecl;
  TX509_VERIFY_PARAM_get_flags = function(const param: PX509_VERIFY_PARAM): LongWord; cdecl;
  TX509_VERIFY_PARAM_set_purpose = function(param: PX509_VERIFY_PARAM; purpose: Integer): Integer; cdecl;
  TX509_VERIFY_PARAM_set_trust = function(param: PX509_VERIFY_PARAM; trust: Integer): Integer; cdecl;
  TX509_VERIFY_PARAM_set_depth = procedure(param: PX509_VERIFY_PARAM; depth: Integer); cdecl;
  TX509_VERIFY_PARAM_get_depth = function(const param: PX509_VERIFY_PARAM): Integer; cdecl;
  TX509_VERIFY_PARAM_set_auth_level = procedure(param: PX509_VERIFY_PARAM; auth_level: Integer); cdecl;
  TX509_VERIFY_PARAM_get_auth_level = function(const param: PX509_VERIFY_PARAM): Integer; cdecl;
  TX509_VERIFY_PARAM_set_time = procedure(param: PX509_VERIFY_PARAM; t: time_t); cdecl;
  TX509_VERIFY_PARAM_add0_policy = function(param: PX509_VERIFY_PARAM; policy: PASN1_OBJECT): Integer; cdecl;
  TX509_VERIFY_PARAM_set1_policies = function(param: PX509_VERIFY_PARAM; policies: Pointer): Integer; cdecl;
  TX509_VERIFY_PARAM_set_inh_flags = function(param: PX509_VERIFY_PARAM; flags: UInt32): Integer; cdecl;
  TX509_VERIFY_PARAM_get_inh_flags = function(const param: PX509_VERIFY_PARAM): UInt32; cdecl;
  TX509_VERIFY_PARAM_set1_host = function(param: PX509_VERIFY_PARAM; const name: PAnsiChar; namelen: size_t): Integer; cdecl;
  TX509_VERIFY_PARAM_add1_host = function(param: PX509_VERIFY_PARAM; const name: PAnsiChar; namelen: size_t): Integer; cdecl;
  TX509_VERIFY_PARAM_set_hostflags = procedure(param: PX509_VERIFY_PARAM; flags: Cardinal); cdecl;
  TX509_VERIFY_PARAM_get_hostflags = function(const param: PX509_VERIFY_PARAM): Cardinal; cdecl;
  TX509_VERIFY_PARAM_get0_peername = function(const param: PX509_VERIFY_PARAM): PAnsiChar; cdecl;
  TX509_VERIFY_PARAM_move_peername = procedure(param: PX509_VERIFY_PARAM; from: PX509_VERIFY_PARAM); cdecl;
  TX509_VERIFY_PARAM_set1_email = function(param: PX509_VERIFY_PARAM; const email: PAnsiChar; emaillen: size_t): Integer; cdecl;
  TX509_VERIFY_PARAM_set1_ip = function(param: PX509_VERIFY_PARAM; const ip: PByte; iplen: size_t): Integer; cdecl;
  TX509_VERIFY_PARAM_set1_ip_asc = function(param: PX509_VERIFY_PARAM; const ipasc: PAnsiChar): Integer; cdecl;
  TX509_VERIFY_PARAM_get0_name = function(const param: PX509_VERIFY_PARAM): PAnsiChar; cdecl;
  TX509_VERIFY_PARAM_lookup = function(const name: PAnsiChar): PX509_VERIFY_PARAM; cdecl;
  TX509_VERIFY_PARAM_table_cleanup = procedure; cdecl;
  TX509_VERIFY_PARAM_get_count = function: Integer; cdecl;
  TX509_VERIFY_PARAM_get0 = function(id: Integer): PX509_VERIFY_PARAM; cdecl;
  TX509_VERIFY_PARAM_add0_table = function(param: PX509_VERIFY_PARAM): Integer; cdecl;

  { X509 I/O Functions }
  Td2i_X509 = function(a: PPX509; const &in: PPByte; len: clong): PX509; cdecl;
  Ti2d_X509 = function(a: PX509; &out: PPByte): Integer; cdecl;
  Td2i_X509_bio = function(bp: PBIO; x509: PPX509): PX509; cdecl;
  Ti2d_X509_bio = function(bp: PBIO; x509: PX509): Integer; cdecl;
  Td2i_X509_fp = function(fp: Pointer; x509: PPX509): PX509; cdecl;
  Ti2d_X509_fp = function(fp: Pointer; x509: PX509): Integer; cdecl;
  
  Td2i_X509_CRL = function(a: PPX509_CRL; const &in: PPByte; len: clong): PX509_CRL; cdecl;
  Ti2d_X509_CRL = function(a: PX509_CRL; &out: PPByte): Integer; cdecl;
  Td2i_X509_CRL_bio = function(bp: PBIO; crl: PPX509_CRL): PX509_CRL; cdecl;
  Ti2d_X509_CRL_bio = function(bp: PBIO; crl: PX509_CRL): Integer; cdecl;
  Td2i_X509_CRL_fp = function(fp: Pointer; crl: PPX509_CRL): PX509_CRL; cdecl;
  Ti2d_X509_CRL_fp = function(fp: Pointer; crl: PX509_CRL): Integer; cdecl;
  
  Td2i_X509_REQ = function(a: PPX509_REQ; const &in: PPByte; len: clong): PX509_REQ; cdecl;
  Ti2d_X509_REQ = function(a: PX509_REQ; &out: PPByte): Integer; cdecl;
  Td2i_X509_REQ_bio = function(bp: PBIO; req: PPX509_REQ): PX509_REQ; cdecl;
  Ti2d_X509_REQ_bio = function(bp: PBIO; req: PX509_REQ): Integer; cdecl;
  Td2i_X509_REQ_fp = function(fp: Pointer; req: PPX509_REQ): PX509_REQ; cdecl;
  Ti2d_X509_REQ_fp = function(fp: Pointer; req: PX509_REQ): Integer; cdecl;
  
  TPEM_read_bio_X509 = function(bp: PBIO; x: PPX509; cb: Tpem_password_cb; u: Pointer): PX509; cdecl;
  TPEM_write_bio_X509 = function(bp: PBIO; x: PX509): Integer; cdecl;
  TPEM_read_bio_X509_AUX = function(bp: PBIO; x: PPX509; cb: Tpem_password_cb; u: Pointer): PX509; cdecl;
  TPEM_write_bio_X509_AUX = function(bp: PBIO; x: PX509): Integer; cdecl;
  TPEM_read_bio_X509_CERT_PAIR = function(bp: PBIO; x: PPointer; cb: Tpem_password_cb; u: Pointer): Pointer; cdecl;
  TPEM_write_bio_X509_CERT_PAIR = function(bp: PBIO; x: Pointer): Integer; cdecl;
  TPEM_read_bio_X509_CRL = function(bp: PBIO; x: PPX509_CRL; cb: Tpem_password_cb; u: Pointer): PX509_CRL; cdecl;
  TPEM_write_bio_X509_CRL = function(bp: PBIO; x: PX509_CRL): Integer; cdecl;
  TPEM_read_bio_X509_REQ = function(bp: PBIO; x: PPX509_REQ; cb: Tpem_password_cb; u: Pointer): PX509_REQ; cdecl;
  TPEM_write_bio_X509_REQ = function(bp: PBIO; x: PX509_REQ): Integer; cdecl;
  TPEM_write_bio_X509_REQ_NEW = function(bp: PBIO; x: PX509_REQ): Integer; cdecl;

var
  // 全局清理标志 - 防止在库卸载后释放对象
  OpenSSLX509_Finalizing: Boolean = False;

  // X509 Core Functions
  X509_new: TX509_new;
  X509_free: TX509_free;
  X509_dup: TX509_dup;
  X509_up_ref: TX509_up_ref;
  
  // X509 Basic Info Functions
  X509_get_version: TX509_get_version;
  X509_set_version: TX509_set_version;
  X509_get_serialNumber: TX509_get_serialNumber;
  X509_set_serialNumber: TX509_set_serialNumber;
  X509_get_subject_name: TX509_get_subject_name;
  X509_set_subject_name: TX509_set_subject_name;
  X509_get_issuer_name: TX509_get_issuer_name;
  X509_set_issuer_name: TX509_set_issuer_name;
  X509_get0_notBefore: TX509_get0_notBefore;
  X509_get0_notAfter: TX509_get0_notAfter;
  X509_get_notBefore: TX509_get_notBefore;
  X509_get_notAfter: TX509_get_notAfter;
  X509_set1_notBefore: TX509_set1_notBefore;
  X509_set1_notAfter: TX509_set1_notAfter;
  X509_set_pubkey: TX509_set_pubkey;
  X509_get_pubkey: TX509_get_pubkey;
  X509_get0_signature: TX509_get0_signature;
  X509_get_signature_nid: TX509_get_signature_nid;
  
  // X509_CRL Functions
  X509_CRL_new: TX509_CRL_new;
  X509_CRL_free: TX509_CRL_free;
  X509_CRL_get0_by_cert: TX509_CRL_get0_by_cert;
  X509_CRL_get0_nextUpdate: TX509_CRL_get0_nextUpdate;
  X509_REVOKED_get0_revocationDate: TX509_REVOKED_get0_revocationDate;
  X509_REVOKED_get_ext_d2i: TX509_REVOKED_get_ext_d2i;
  X509_sign: TX509_sign;
  X509_gmtime_adj: TX509_gmtime_adj;
  
  // X509 Extension Functions
  X509_get_ext_count: TX509_get_ext_count;
  X509_get_ext_by_NID: TX509_get_ext_by_NID;
  X509_get_ext_by_OBJ: TX509_get_ext_by_OBJ;
  X509_get_ext: TX509_get_ext;
  X509_get_ext_d2i: TX509_get_ext_d2i;
  X509_get_extension_flags: TX509_get_extension_flags;
  X509_check_ca: TX509_check_ca;
  X509_get_key_usage: TX509_get_key_usage;
  X509_get_extended_key_usage: TX509_get_extended_key_usage;
  X509_get_pathlen: TX509_get_pathlen;
  X509_get_proxy_pathlen: TX509_get_proxy_pathlen;
  X509_add_ext: TX509_add_ext;
  X509_EXTENSION_free: TX509_EXTENSION_free;
  
  // X509 Verification Functions
  X509_verify: TX509_verify;
  X509_check_purpose: TX509_check_purpose;
  X509_check_trust: TX509_check_trust;
  X509_check_issued: TX509_check_issued;
  X509_check_akid: TX509_check_akid;
  X509_check_host: TX509_check_host;
  X509_check_email: TX509_check_email;
  X509_check_ip: TX509_check_ip;
  X509_check_ip_asc: TX509_check_ip_asc;
  X509_check_private_key: TX509_check_private_key;
  X509_verify_cert: TX509_verify_cert;
  X509_verify_cert_error_string: TX509_verify_cert_error_string;

  // X509 Compare/Policy Functions
  X509_cmp: TX509_cmp;
  X509_policy_check: TX509_policy_check;
  X509_policy_tree_free: TX509_policy_tree_free;
  X509_policy_tree_level_count: TX509_policy_tree_level_count;
  X509_policy_tree_get0_level: TX509_policy_tree_get0_level;
  
  // X509 Store Functions
  X509_STORE_new: TX509_STORE_new;
  X509_STORE_free: TX509_STORE_free;
  X509_STORE_add_cert: TX509_STORE_add_cert;
  X509_STORE_load_file: TX509_STORE_load_file;
  X509_STORE_load_path: TX509_STORE_load_path;
  X509_STORE_load_locations: TX509_STORE_load_locations;
  X509_STORE_set_default_paths: TX509_STORE_set_default_paths;
  X509_STORE_set_flags: TX509_STORE_set_flags;
  
  // X509 Store Context Functions
  X509_STORE_CTX_new: TX509_STORE_CTX_new;
  X509_STORE_CTX_free: TX509_STORE_CTX_free;
  X509_STORE_CTX_init: TX509_STORE_CTX_init;
  X509_STORE_CTX_get0_chain: TX509_STORE_CTX_get0_chain;
  X509_STORE_CTX_get_current_cert: TX509_STORE_CTX_get_current_cert;
  X509_STORE_CTX_get_error: TX509_STORE_CTX_get_error;
  X509_STORE_CTX_set_error: TX509_STORE_CTX_set_error;
  X509_STORE_CTX_get0_param: TX509_STORE_CTX_get0_param;
  
  // X509 Verify Param Functions
  X509_VERIFY_PARAM_set_flags: TX509_VERIFY_PARAM_set_flags;
  
  // X509 Name Functions
  X509_NAME_new: TX509_NAME_new;
  X509_NAME_free: TX509_NAME_free;
  X509_NAME_add_entry_by_txt: TX509_NAME_add_entry_by_txt;
  X509_NAME_oneline: TX509_NAME_oneline;
  X509_NAME_print_ex: TX509_NAME_print_ex;
  X509_NAME_cmp: TX509_NAME_cmp;
  X509_NAME_entry_count: TX509_NAME_entry_count;
  X509_NAME_get_entry: TX509_NAME_get_entry;
  X509_NAME_get_text_by_NID: TX509_NAME_get_text_by_NID;
  
  // X509 Algorithm Functions
  X509_ALGOR_get0: TX509_ALGOR_get0;
  X509_ALGOR_set_md: TX509_ALGOR_set_md;
  
  // X509 I/O Functions
  d2i_X509_bio: Td2i_X509_bio;
  d2i_X509: Td2i_X509;
  i2d_X509: Ti2d_X509;
  i2d_X509_bio: Ti2d_X509_bio;
  PEM_read_bio_X509: TPEM_read_bio_X509;
  PEM_write_bio_X509: TPEM_write_bio_X509;
  
  // X509 Digest Function
  X509_digest: function(const data: PX509; const &type: PEVP_MD; md: PByte; len: PCardinal): Integer; cdecl;
  
procedure LoadOpenSSLX509;
procedure UnloadOpenSSLX509;

implementation

uses
  nextpas.core.tls.openssl.api.core,  // For shared library handles
  nextpas.core.tls.openssl.loader;    // For TOpenSSLLoader

procedure LoadOpenSSLX509;
var
  LibHandle: TLibHandle;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    Exit;
    
  LibHandle := GetCryptoLibHandle;
  if LibHandle = NilHandle then
    Exit;
  
  // Load X509 Core Functions
  X509_new := TX509_new(GetProcedureAddress(LibHandle, 'X509_new'));
  X509_free := TX509_free(GetProcedureAddress(LibHandle, 'X509_free'));
  X509_dup := TX509_dup(GetProcedureAddress(LibHandle, 'X509_dup'));
  X509_up_ref := TX509_up_ref(GetProcedureAddress(LibHandle, 'X509_up_ref'));
  
  // Load X509 Basic Info Functions
  X509_get_version := TX509_get_version(GetProcedureAddress(LibHandle, 'X509_get_version'));
  X509_set_version := TX509_set_version(GetProcedureAddress(LibHandle, 'X509_set_version'));
  X509_get_serialNumber := TX509_get_serialNumber(GetProcedureAddress(LibHandle, 'X509_get_serialNumber'));
  X509_set_serialNumber := TX509_set_serialNumber(GetProcedureAddress(LibHandle, 'X509_set_serialNumber'));
  X509_get_subject_name := TX509_get_subject_name(GetProcedureAddress(LibHandle, 'X509_get_subject_name'));
  X509_set_subject_name := TX509_set_subject_name(GetProcedureAddress(LibHandle, 'X509_set_subject_name'));
  X509_get_issuer_name := TX509_get_issuer_name(GetProcedureAddress(LibHandle, 'X509_get_issuer_name'));
  X509_set_issuer_name := TX509_set_issuer_name(GetProcedureAddress(LibHandle, 'X509_set_issuer_name'));
  X509_get0_notBefore := TX509_get0_notBefore(GetProcedureAddress(LibHandle, 'X509_get0_notBefore'));
  X509_get0_notAfter := TX509_get0_notAfter(GetProcedureAddress(LibHandle, 'X509_get0_notAfter'));
  // For OpenSSL 3.x, try getm variants first (mutable), fall back to get0
  X509_get_notBefore := TX509_get_notBefore(GetProcedureAddress(LibHandle, 'X509_getm_notBefore'));
  if not Assigned(X509_get_notBefore) then
    X509_get_notBefore := TX509_get_notBefore(GetProcedureAddress(LibHandle, 'X509_get0_notBefore'));
  X509_get_notAfter := TX509_get_notAfter(GetProcedureAddress(LibHandle, 'X509_getm_notAfter'));
  if not Assigned(X509_get_notAfter) then
    X509_get_notAfter := TX509_get_notAfter(GetProcedureAddress(LibHandle, 'X509_get0_notAfter'));
  X509_set1_notBefore := TX509_set1_notBefore(GetProcedureAddress(LibHandle, 'X509_set1_notBefore'));
  X509_set1_notAfter := TX509_set1_notAfter(GetProcedureAddress(LibHandle, 'X509_set1_notAfter'));
  X509_set_pubkey := TX509_set_pubkey(GetProcedureAddress(LibHandle, 'X509_set_pubkey'));
  X509_get_pubkey := TX509_get_pubkey(GetProcedureAddress(LibHandle, 'X509_get_pubkey'));
  X509_get0_signature := TX509_get0_signature(GetProcedureAddress(LibHandle, 'X509_get0_signature'));
  X509_get_signature_nid := TX509_get_signature_nid(GetProcedureAddress(LibHandle, 'X509_get_signature_nid'));
  X509_sign := TX509_sign(GetProcedureAddress(LibHandle, 'X509_sign'));
  X509_gmtime_adj := TX509_gmtime_adj(GetProcedureAddress(LibHandle, 'X509_gmtime_adj'));
  
  // Load X509_CRL Functions
  X509_CRL_new := TX509_CRL_new(GetProcedureAddress(LibHandle, 'X509_CRL_new'));
  X509_CRL_free := TX509_CRL_free(GetProcedureAddress(LibHandle, 'X509_CRL_free'));
  X509_CRL_get0_by_cert := TX509_CRL_get0_by_cert(GetProcedureAddress(LibHandle, 'X509_CRL_get0_by_cert'));
  X509_CRL_get0_nextUpdate := TX509_CRL_get0_nextUpdate(GetProcedureAddress(LibHandle, 'X509_CRL_get0_nextUpdate'));
  X509_REVOKED_get0_revocationDate := TX509_REVOKED_get0_revocationDate(GetProcedureAddress(LibHandle, 'X509_REVOKED_get0_revocationDate'));
  X509_REVOKED_get_ext_d2i := TX509_REVOKED_get_ext_d2i(GetProcedureAddress(LibHandle, 'X509_REVOKED_get_ext_d2i'));
  
  // Load X509 Extension Functions  
  X509_get_ext_count := TX509_get_ext_count(GetProcedureAddress(LibHandle, 'X509_get_ext_count'));
  X509_get_ext_by_NID := TX509_get_ext_by_NID(GetProcedureAddress(LibHandle, 'X509_get_ext_by_NID'));
  X509_get_ext_by_OBJ := TX509_get_ext_by_OBJ(GetProcedureAddress(LibHandle, 'X509_get_ext_by_OBJ'));
  X509_get_ext := TX509_get_ext(GetProcedureAddress(LibHandle, 'X509_get_ext'));
  X509_get_ext_d2i := TX509_get_ext_d2i(GetProcedureAddress(LibHandle, 'X509_get_ext_d2i'));
  X509_get_extension_flags := TX509_get_extension_flags(GetProcedureAddress(LibHandle, 'X509_get_extension_flags'));
  X509_check_ca := TX509_check_ca(GetProcedureAddress(LibHandle, 'X509_check_ca'));
  X509_get_key_usage := TX509_get_key_usage(GetProcedureAddress(LibHandle, 'X509_get_key_usage'));
  X509_get_extended_key_usage := TX509_get_extended_key_usage(GetProcedureAddress(LibHandle, 'X509_get_extended_key_usage'));
  X509_get_pathlen := TX509_get_pathlen(GetProcedureAddress(LibHandle, 'X509_get_pathlen'));
  X509_get_proxy_pathlen := TX509_get_proxy_pathlen(GetProcedureAddress(LibHandle, 'X509_get_proxy_pathlen'));
  X509_add_ext := TX509_add_ext(GetProcedureAddress(LibHandle, 'X509_add_ext'));
  X509_EXTENSION_free := TX509_EXTENSION_free(GetProcedureAddress(LibHandle, 'X509_EXTENSION_free'));
  
  // Load X509 Verification Functions
  X509_verify := TX509_verify(GetProcedureAddress(LibHandle, 'X509_verify'));
  X509_check_purpose := TX509_check_purpose(GetProcedureAddress(LibHandle, 'X509_check_purpose'));
  X509_check_trust := TX509_check_trust(GetProcedureAddress(LibHandle, 'X509_check_trust'));
  X509_check_issued := TX509_check_issued(GetProcedureAddress(LibHandle, 'X509_check_issued'));
  X509_check_akid := TX509_check_akid(GetProcedureAddress(LibHandle, 'X509_check_akid'));
  X509_check_host := TX509_check_host(GetProcedureAddress(LibHandle, 'X509_check_host'));
  X509_check_email := TX509_check_email(GetProcedureAddress(LibHandle, 'X509_check_email'));
  X509_check_ip := TX509_check_ip(GetProcedureAddress(LibHandle, 'X509_check_ip'));
  X509_check_ip_asc := TX509_check_ip_asc(GetProcedureAddress(LibHandle, 'X509_check_ip_asc'));
  X509_check_private_key := TX509_check_private_key(GetProcedureAddress(LibHandle, 'X509_check_private_key'));
  X509_verify_cert := TX509_verify_cert(GetProcedureAddress(LibHandle, 'X509_verify_cert'));
  X509_verify_cert_error_string := TX509_verify_cert_error_string(GetProcedureAddress(LibHandle, 'X509_verify_cert_error_string'));

  // Load X509 Compare/Policy Functions
  X509_cmp := TX509_cmp(GetProcedureAddress(LibHandle, 'X509_cmp'));
  X509_policy_check := TX509_policy_check(GetProcedureAddress(LibHandle, 'X509_policy_check'));
  X509_policy_tree_free := TX509_policy_tree_free(GetProcedureAddress(LibHandle, 'X509_policy_tree_free'));
  X509_policy_tree_level_count := TX509_policy_tree_level_count(GetProcedureAddress(LibHandle, 'X509_policy_tree_level_count'));
  X509_policy_tree_get0_level := TX509_policy_tree_get0_level(GetProcedureAddress(LibHandle, 'X509_policy_tree_get0_level'));
  
  // Load X509 Store Functions
  X509_STORE_new := TX509_STORE_new(GetProcedureAddress(LibHandle, 'X509_STORE_new'));
  X509_STORE_free := TX509_STORE_free(GetProcedureAddress(LibHandle, 'X509_STORE_free'));
  X509_STORE_add_cert := TX509_STORE_add_cert(GetProcedureAddress(LibHandle, 'X509_STORE_add_cert'));
  X509_STORE_load_file := TX509_STORE_load_file(GetProcedureAddress(LibHandle, 'X509_STORE_load_file'));
  X509_STORE_load_path := TX509_STORE_load_path(GetProcedureAddress(LibHandle, 'X509_STORE_load_path'));
  X509_STORE_load_locations := TX509_STORE_load_locations(GetProcedureAddress(LibHandle, 'X509_STORE_load_locations'));
  X509_STORE_set_default_paths := TX509_STORE_set_default_paths(GetProcedureAddress(LibHandle, 'X509_STORE_set_default_paths'));
  X509_STORE_set_flags := TX509_STORE_set_flags(GetProcedureAddress(LibHandle, 'X509_STORE_set_flags'));
  
  // Load X509 Store Context Functions
  X509_STORE_CTX_new := TX509_STORE_CTX_new(GetProcedureAddress(LibHandle, 'X509_STORE_CTX_new'));
  X509_STORE_CTX_free := TX509_STORE_CTX_free(GetProcedureAddress(LibHandle, 'X509_STORE_CTX_free'));
  X509_STORE_CTX_init := TX509_STORE_CTX_init(GetProcedureAddress(LibHandle, 'X509_STORE_CTX_init'));
  X509_STORE_CTX_get0_chain := TX509_STORE_CTX_get0_chain(GetProcedureAddress(LibHandle, 'X509_STORE_CTX_get0_chain'));
  X509_STORE_CTX_get_current_cert := TX509_STORE_CTX_get_current_cert(GetProcedureAddress(LibHandle, 'X509_STORE_CTX_get_current_cert'));
  X509_STORE_CTX_get_error := TX509_STORE_CTX_get_error(GetProcedureAddress(LibHandle, 'X509_STORE_CTX_get_error'));
  X509_STORE_CTX_set_error := TX509_STORE_CTX_set_error(GetProcedureAddress(LibHandle, 'X509_STORE_CTX_set_error'));
  X509_STORE_CTX_get0_param := TX509_STORE_CTX_get0_param(GetProcedureAddress(LibHandle, 'X509_STORE_CTX_get0_param'));
  
  // Load X509 Verify Param Functions
  X509_VERIFY_PARAM_set_flags := TX509_VERIFY_PARAM_set_flags(GetProcedureAddress(LibHandle, 'X509_VERIFY_PARAM_set_flags'));
  
  // Load X509 Name Functions
  X509_NAME_new := TX509_NAME_new(GetProcedureAddress(LibHandle, 'X509_NAME_new'));
  X509_NAME_free := TX509_NAME_free(GetProcedureAddress(LibHandle, 'X509_NAME_free'));
  X509_NAME_add_entry_by_txt := TX509_NAME_add_entry_by_txt(GetProcedureAddress(LibHandle, 'X509_NAME_add_entry_by_txt'));
  X509_NAME_oneline := TX509_NAME_oneline(GetProcedureAddress(LibHandle, 'X509_NAME_oneline'));
  X509_NAME_print_ex := TX509_NAME_print_ex(GetProcedureAddress(LibHandle, 'X509_NAME_print_ex'));
  X509_NAME_cmp := TX509_NAME_cmp(GetProcedureAddress(LibHandle, 'X509_NAME_cmp'));
  X509_NAME_entry_count := TX509_NAME_entry_count(GetProcedureAddress(LibHandle, 'X509_NAME_entry_count'));
  X509_NAME_get_entry := TX509_NAME_get_entry(GetProcedureAddress(LibHandle, 'X509_NAME_get_entry'));
  X509_NAME_get_text_by_NID := TX509_NAME_get_text_by_NID(GetProcedureAddress(LibHandle, 'X509_NAME_get_text_by_NID'));
  
  // Load X509 Algorithm Functions
  X509_ALGOR_get0 := TX509_ALGOR_get0(GetProcedureAddress(LibHandle, 'X509_ALGOR_get0'));
  X509_ALGOR_set_md := TX509_ALGOR_set_md(GetProcedureAddress(LibHandle, 'X509_ALGOR_set_md'));
  
  // Load X509 I/O Functions
  d2i_X509_bio := Td2i_X509_bio(GetProcedureAddress(LibHandle, 'd2i_X509_bio'));
  d2i_X509 := Td2i_X509(GetProcedureAddress(LibHandle, 'd2i_X509'));
  i2d_X509 := Ti2d_X509(GetProcedureAddress(LibHandle, 'i2d_X509'));
  i2d_X509_bio := Ti2d_X509_bio(GetProcedureAddress(LibHandle, 'i2d_X509_bio'));
  PEM_read_bio_X509 := TPEM_read_bio_X509(GetProcedureAddress(LibHandle, 'PEM_read_bio_X509'));
  PEM_write_bio_X509 := TPEM_write_bio_X509(GetProcedureAddress(LibHandle, 'PEM_write_bio_X509'));
  
  // Load X509 Digest Function
  Pointer(X509_digest) := GetProcedureAddress(LibHandle, 'X509_digest');

  // Mark module as loaded
  TOpenSSLLoader.SetModuleLoaded(osmX509, Assigned(X509_new) and Assigned(X509_free));
end;

procedure UnloadOpenSSLX509;
begin
  // 设置清理标志 - 告诉对象不要再调用 OpenSSL 函数
  OpenSSLX509_Finalizing := True;
  
  // Reset all function pointers
  X509_new := nil;
  X509_free := nil;
  X509_dup := nil;
  X509_up_ref := nil;
  X509_get0_notBefore := nil;
  X509_get0_notAfter := nil;
  X509_REVOKED_get0_revocationDate := nil;
  X509_REVOKED_get_ext_d2i := nil;
  X509_verify := nil;
  X509_check_purpose := nil;
  X509_check_trust := nil;
  X509_check_issued := nil;
  X509_check_akid := nil;
  X509_check_host := nil;
  X509_check_email := nil;
  X509_check_ip := nil;
  X509_check_ip_asc := nil;
  X509_cmp := nil;
  X509_policy_check := nil;
  X509_policy_tree_free := nil;
  X509_policy_tree_level_count := nil;
  X509_policy_tree_get0_level := nil;
  X509_STORE_new := nil;
  X509_STORE_free := nil;
  X509_STORE_add_cert := nil;
  X509_get_ext_count := nil;
  X509_add_ext := nil;
  X509_EXTENSION_free := nil;
  X509_NAME_new := nil;
  X509_NAME_free := nil;
  X509_NAME_oneline := nil;
  X509_NAME_print_ex := nil;
  X509_ALGOR_get0 := nil;
  X509_ALGOR_set_md := nil;
  // ... 其他函数指针也设为 nil

  TOpenSSLLoader.SetModuleLoaded(osmX509, False);
end;


end.