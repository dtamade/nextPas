unit nextpas.core.tls.openssl.api.ocsp;

{$mode ObjFPC}{$H+}

interface

uses dynlibs, nextpas.core.tls.base, nextpas.core.tls.net.hooks, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.consts, nextpas.core.tls.openssl.api.core, nextpas.core.tls.openssl.api.ssl, nextpas.core.tls.openssl.api.x509, nextpas.core.tls.openssl.api.crypto, nextpas.core.tls.openssl.api.asn1, nextpas.core.tls.openssl.api.bio, nextpas.core.tls.openssl.api.evp, nextpas.core.tls.openssl.api.stack, nextpas.core.text.conv; type // Additional pointer types needed PPASN1_GENERALIZEDTIME = ^PASN1_GENERALIZEDTIME;
  POCSP_REQ_CTX = Pointer;
  PPOCSP_REQ_CTX = ^POCSP_REQ_CTX;
  PPASN1_VALUE = ^ASN1_VALUE;
  PPSTACK_OF = ^POPENSSL_STACK;
  
  // OCSP 类型定义
  OCSP_REQUEST = Pointer;
  POCSP_REQUEST = ^OCSP_REQUEST;
  PPOCSP_REQUEST = ^POCSP_REQUEST;
  
  OCSP_RESPONSE = Pointer;
  POCSP_RESPONSE = ^OCSP_RESPONSE;
  PPOCSP_RESPONSE = ^POCSP_RESPONSE;
  
  OCSP_BASICRESP = Pointer;
  POCSP_BASICRESP = ^OCSP_BASICRESP;
  PPOCSP_BASICRESP = ^POCSP_BASICRESP;
  
  OCSP_CERTID = Pointer;
  POCSP_CERTID = ^OCSP_CERTID;
  PPOCSP_CERTID = ^POCSP_CERTID;
  
  OCSP_ONEREQ = Pointer;
  POCSP_ONEREQ = ^OCSP_ONEREQ;
  
  OCSP_SINGLERESP = Pointer;
  POCSP_SINGLERESP = ^OCSP_SINGLERESP;
  
  OCSP_RESPDATA = Pointer;
  POCSP_RESPDATA = ^OCSP_RESPDATA;
  
  OCSP_RESPBYTES = Pointer;
  POCSP_RESPBYTES = ^OCSP_RESPBYTES;
  
  OCSP_RESPID = Pointer;
  POCSP_RESPID = ^OCSP_RESPID;
  PPOCSP_RESPID = ^POCSP_RESPID;
  
  OCSP_REVOKEDINFO = Pointer;
  POCSP_REVOKEDINFO = ^OCSP_REVOKEDINFO;
  
  OCSP_CERTSTATUS = Pointer;
  POCSP_CERTSTATUS = ^OCSP_CERTSTATUS;
  
  OCSP_REQINFO = Pointer;
  POCSP_REQINFO = ^OCSP_REQINFO;
  
  OCSP_SIGNATURE = Pointer;
  POCSP_SIGNATURE = ^OCSP_SIGNATURE;
  
  OCSP_CRLID = Pointer;
  POCSP_CRLID = ^OCSP_CRLID;
  
  OCSP_SERVICELOC = Pointer;
  POCSP_SERVICELOC = ^OCSP_SERVICELOC;

  // OCSP 响应状态
  const
    OCSP_RESPONSE_STATUS_SUCCESSFUL            = 0;
    OCSP_RESPONSE_STATUS_MALFORMEDREQUEST      = 1;
    OCSP_RESPONSE_STATUS_INTERNALERROR         = 2;
    OCSP_RESPONSE_STATUS_TRYLATER              = 3;
    OCSP_RESPONSE_STATUS_SIGREQUIRED           = 5;
    OCSP_RESPONSE_STATUS_UNAUTHORIZED          = 6;

    // 证书状态
    V_OCSP_CERTSTATUS_GOOD                     = 0;
    V_OCSP_CERTSTATUS_REVOKED                  = 1;
    V_OCSP_CERTSTATUS_UNKNOWN                  = 2;
    V_OCSP_CERTSTATUS_ERROR                    = -1;

    // 吊销原因
    OCSP_REVOKED_STATUS_NOSTATUS               = -1;
    OCSP_REVOKED_STATUS_UNSPECIFIED            = 0;
    OCSP_REVOKED_STATUS_KEYCOMPROMISE          = 1;
    OCSP_REVOKED_STATUS_CACOMPROMISE           = 2;
    OCSP_REVOKED_STATUS_AFFILIATIONCHANGED     = 3;
    OCSP_REVOKED_STATUS_SUPERSEDED             = 4;
    OCSP_REVOKED_STATUS_CESSATIONOFOPERATION   = 5;
    OCSP_REVOKED_STATUS_CERTIFICATEHOLD        = 6;
    OCSP_REVOKED_STATUS_REMOVEFROMCRL          = 8;

    // OCSP 标志
    OCSP_NOCERTS                    = $1;
    OCSP_NOINTERN                   = $2;
    OCSP_NOSIGS                     = $4;
    OCSP_NOCHAIN                    = $8;
    OCSP_NOVERIFY                   = $10;
    OCSP_NOEXPLICIT                 = $20;
    OCSP_NOCASIGN                   = $40;
    OCSP_NODELEGATED                = $80;
    OCSP_NOCHECKS                   = $100;
    OCSP_TRUSTOTHER                 = $200;
    OCSP_RESPID_KEY                 = $400;
    OCSP_NOTIME                     = $800;

    // V_OCSP 标志
    V_OCSP_RESPID_NAME              = 0;
    V_OCSP_RESPID_KEY               = 1;

  type
    TOCSPCheckFailureStage = (
      ocspCheckNone,
      ocspCheckDependenciesUnavailable,
      ocspCheckRequestCreation,
      ocspCheckTransport,
      ocspCheckResponseStatus,
      ocspCheckBasicResponse,
      ocspCheckNonceValidation,
      ocspCheckCryptographicVerification,
      ocspCheckStatusLookup,
      ocspCheckValidity
    );

    TOCSPCheckResult = record
      CertStatus: Integer;
      Verified: Boolean;
      ResponseStatus: Integer;
      FailureStage: TOCSPCheckFailureStage;
      ErrorMessage: string;
    end;

  // OCSP 函数类型
  type
    // OCSP 请求函数
    TOCSP_REQUEST_new = function(): POCSP_REQUEST; cdecl;
    TOCSP_REQUEST_free = procedure(a: POCSP_REQUEST); cdecl;
    Td2i_OCSP_REQUEST = function(a: PPOCSP_REQUEST; const in_: PPByte; len: Integer): POCSP_REQUEST; cdecl;
    Ti2d_OCSP_REQUEST = function(a: POCSP_REQUEST; out_: PPByte): Integer; cdecl;
    TOCSP_REQUEST_add_ext = function(req: POCSP_REQUEST; ex: PX509_EXTENSION; loc: Integer): Integer; cdecl;
    TOCSP_REQUEST_get_ext = function(x: POCSP_REQUEST; loc: Integer): PX509_EXTENSION; cdecl;
    TOCSP_REQUEST_get_ext_by_NID = function(x: POCSP_REQUEST; nid: Integer; lastpos: Integer): Integer; cdecl;
    TOCSP_REQUEST_get_ext_by_OBJ = function(x: POCSP_REQUEST; obj: ASN1_OBJECT; lastpos: Integer): Integer; cdecl;
    TOCSP_REQUEST_get_ext_by_critical = function(x: POCSP_REQUEST; crit: Integer; lastpos: Integer): Integer; cdecl;
    TOCSP_REQUEST_get_ext_count = function(x: POCSP_REQUEST): Integer; cdecl;
    TOCSP_REQUEST_delete_ext = function(x: POCSP_REQUEST; loc: Integer): PX509_EXTENSION; cdecl;
    TOCSP_REQUEST_print = function(bp: PBIO; a: POCSP_REQUEST; flags: Cardinal): Integer; cdecl;
    TOCSP_REQUEST_sign = function(req: POCSP_REQUEST; signer: PX509; key: PEVP_PKEY; 
      const dgst: PEVP_MD; certs: PSTACK_OF_X509; flags: Cardinal): Integer; cdecl;

    // OCSP 响应函数
    TOCSP_RESPONSE_new = function(): POCSP_RESPONSE; cdecl;
    TOCSP_RESPONSE_free = procedure(a: POCSP_RESPONSE); cdecl;
    Td2i_OCSP_RESPONSE = function(a: PPOCSP_RESPONSE; const in_: PPByte; len: Integer): POCSP_RESPONSE; cdecl;
    Ti2d_OCSP_RESPONSE = function(a: POCSP_RESPONSE; out_: PPByte): Integer; cdecl;
    TOCSP_RESPONSE_create = function(status: Integer; bs: POCSP_BASICRESP): POCSP_RESPONSE; cdecl;
    TOCSP_RESPONSE_status = function(resp: POCSP_RESPONSE): Integer; cdecl;
    TOCSP_RESPONSE_get1_basic = function(resp: POCSP_RESPONSE): POCSP_BASICRESP; cdecl;
    TOCSP_RESPONSE_print = function(bp: PBIO; o: POCSP_RESPONSE; flags: Cardinal): Integer; cdecl;

    // OCSP 基本响应函数
    TOCSP_BASICRESP_new = function(): POCSP_BASICRESP; cdecl;
    TOCSP_BASICRESP_free = procedure(a: POCSP_BASICRESP); cdecl;
    Td2i_OCSP_BASICRESP = function(a: PPOCSP_BASICRESP; const in_: PPByte; len: Integer): POCSP_BASICRESP; cdecl;
    Ti2d_OCSP_BASICRESP = function(a: POCSP_BASICRESP; out_: PPByte): Integer; cdecl;
    TOCSP_BASICRESP_add_ext = function(x: POCSP_BASICRESP; ex: PX509_EXTENSION; loc: Integer): Integer; cdecl;
    TOCSP_BASICRESP_get_ext = function(x: POCSP_BASICRESP; loc: Integer): PX509_EXTENSION; cdecl;
    TOCSP_BASICRESP_get_ext_by_NID = function(x: POCSP_BASICRESP; nid: Integer; lastpos: Integer): Integer; cdecl;
    TOCSP_BASICRESP_get_ext_by_OBJ = function(x: POCSP_BASICRESP; obj: ASN1_OBJECT; lastpos: Integer): Integer; cdecl;
    TOCSP_BASICRESP_get_ext_by_critical = function(x: POCSP_BASICRESP; crit: Integer; lastpos: Integer): Integer; cdecl;
    TOCSP_BASICRESP_get_ext_count = function(x: POCSP_BASICRESP): Integer; cdecl;
    TOCSP_BASICRESP_delete_ext = function(x: POCSP_BASICRESP; loc: Integer): PX509_EXTENSION; cdecl;
    TOCSP_BASICRESP_sign = function(brsp: POCSP_BASICRESP; signer: PX509; key: PEVP_PKEY; 
      const dgst: PEVP_MD; certs: PSTACK_OF_X509; flags: Cardinal): Integer; cdecl;
    TOCSP_BASICRESP_sign_ctx = function(brsp: POCSP_BASICRESP; signer: PX509; 
      ctx: PEVP_MD_CTX; certs: PSTACK_OF_X509; flags: Cardinal): Integer; cdecl;
    TOCSP_BASICRESP_verify = function(bs: POCSP_BASICRESP; certs: PSTACK_OF_X509; 
      st: PX509_STORE; flags: Cardinal): Integer; cdecl;

    // OCSP 证书 ID 函数
    TOCSP_CERTID_new = function(): POCSP_CERTID; cdecl;
    TOCSP_CERTID_free = procedure(a: POCSP_CERTID); cdecl;
    TOCSP_CERTID_dup = function(id: POCSP_CERTID): POCSP_CERTID; cdecl;
    TOCSP_cert_to_id = function(const dgst: PEVP_MD; const subject: PX509; const issuer: PX509): POCSP_CERTID; cdecl;
    TOCSP_cert_id_new = function(const dgst: PEVP_MD; const issuerName: PX509_NAME; 
      const issuerKey: ASN1_BIT_STRING; const serialNumber: ASN1_INTEGER): POCSP_CERTID; cdecl;
    TOCSP_id_issuer_cmp = function(a: POCSP_CERTID; b: POCSP_CERTID): Integer; cdecl;
    TOCSP_id_cmp = function(a: POCSP_CERTID; b: POCSP_CERTID): Integer; cdecl;
    TOCSP_id_get0_info = function(piNameHash: PPASN1_OCTET_STRING; pmd: PPEVP_MD; 
      piKeyHash: PPASN1_OCTET_STRING; pserial: PPASN1_INTEGER; cid: POCSP_CERTID): Integer; cdecl;

    // OCSP 请求操作
    TOCSP_request_add0_id = function(req: POCSP_REQUEST; cid: POCSP_CERTID): POCSP_ONEREQ; cdecl;
    TOCSP_request_add1_nonce = function(req: POCSP_REQUEST; val: PByte; len: Integer): Integer; cdecl;
    TOCSP_check_nonce = function(req: POCSP_REQUEST; bs: POCSP_BASICRESP): Integer; cdecl;
    TOCSP_copy_nonce = function(resp: POCSP_BASICRESP; req: POCSP_REQUEST): Integer; cdecl;
    TOCSP_request_add1_cert = function(req: POCSP_REQUEST; cert: PX509): Integer; cdecl;
    TOCSP_request_onereq_count = function(req: POCSP_REQUEST): Integer; cdecl;
    TOCSP_request_onereq_get0 = function(req: POCSP_REQUEST; i: Integer): POCSP_ONEREQ; cdecl;
    TOCSP_onereq_get0_id = function(one: POCSP_ONEREQ): POCSP_CERTID; cdecl;
    TOCSP_single_get0_status = function(single: POCSP_SINGLERESP; reason: PInteger; 
      revtime: PPASN1_GENERALIZEDTIME; thisupd: PPASN1_GENERALIZEDTIME; 
      nextupd: PPASN1_GENERALIZEDTIME): Integer; cdecl;

    // OCSP 响应操作
    TOCSP_resp_count = function(bs: POCSP_BASICRESP): Integer; cdecl;
    TOCSP_resp_get0 = function(bs: POCSP_BASICRESP; idx: Integer): POCSP_SINGLERESP; cdecl;
    TOCSP_resp_get0_respdata = function(bs: POCSP_BASICRESP): POCSP_RESPDATA; cdecl;
    TOCSP_resp_get0_produced_at = function(const bs: POCSP_BASICRESP): ASN1_GENERALIZEDTIME; cdecl;
    TOCSP_resp_get0_signature = function(const bs: POCSP_BASICRESP): POCSP_SIGNATURE; cdecl;
    TOCSP_resp_get1_id = function(bs: POCSP_BASICRESP; id: PPOCSP_RESPID): Integer; cdecl;
    TOCSP_resp_get0_id = function(const bs: POCSP_BASICRESP; id: PPOCSP_RESPID): Integer; cdecl;
    TOCSP_resp_get0_certs = function(const bs: POCSP_BASICRESP): PSTACK_OF_X509; cdecl;
    TOCSP_resp_find = function(bs: POCSP_BASICRESP; id: POCSP_CERTID; idx: PInteger): Integer; cdecl;
    TOCSP_resp_find_status = function(bs: POCSP_BASICRESP; id: POCSP_CERTID; status: PInteger; 
      reason: PInteger; revtime: PPASN1_GENERALIZEDTIME; thisupd: PPASN1_GENERALIZEDTIME; 
      nextupd: PPASN1_GENERALIZEDTIME): Integer; cdecl;

    // OCSP 基本响应添加
    TOCSP_basic_add1_status = function(rsp: POCSP_BASICRESP; cid: POCSP_CERTID; 
      status: Integer; reason: Integer; revtime: ASN1_TIME; thisupd: ASN1_TIME; 
      nextupd: ASN1_TIME): POCSP_SINGLERESP; cdecl;
    TOCSP_basic_add1_nonce = function(resp: POCSP_BASICRESP; val: PByte; len: Integer): Integer; cdecl;
    TOCSP_basic_add1_cert = function(resp: POCSP_BASICRESP; cert: PX509): Integer; cdecl;

    // OCSP 检查函数
    TOCSP_check_validity = function(thisupd: ASN1_GENERALIZEDTIME; nextupd: ASN1_GENERALIZEDTIME; 
      sec: Integer; maxsec: Integer): Integer; cdecl;

    // OCSP HTTP 函数
    TOCSP_sendreq_new = function(io: PBIO; const path: PAnsiChar; req: POCSP_REQUEST; 
      maxline: Integer): POCSP_REQ_CTX; cdecl;
    TOCSP_sendreq_nbio = function(rctx: PPOCSP_REQ_CTX; resp: PPOCSP_RESPONSE): Integer; cdecl;
    TOCSP_REQ_CTX_free = procedure(rctx: POCSP_REQ_CTX); cdecl;
    TOCSP_REQ_CTX_http = function(rctx: POCSP_REQ_CTX; const op: PAnsiChar; const path: PAnsiChar): Integer; cdecl;
    TOCSP_REQ_CTX_set1_req = function(rctx: POCSP_REQ_CTX; req: POCSP_REQUEST): Integer; cdecl;
    TOCSP_REQ_CTX_add1_header = function(rctx: POCSP_REQ_CTX; const name: PAnsiChar; 
      const value: PAnsiChar): Integer; cdecl;
    TOCSP_REQ_CTX_i2d = function(rctx: POCSP_REQ_CTX; const it: ASN1_ITEM; val: ASN1_VALUE): Integer; cdecl;
    TOCSP_REQ_CTX_nbio_d2i = function(rctx: POCSP_REQ_CTX; val: PPASN1_VALUE; const it: ASN1_ITEM): Integer; cdecl;
    TOCSP_REQ_CTX_get0_mem_bio = function(rctx: POCSP_REQ_CTX): PBIO; cdecl;
    TOCSP_REQ_CTX_nbio = function(rctx: POCSP_REQ_CTX): Integer; cdecl;

    // OCSP 服务定位器
    TOCSP_url_svcloc_new = function(issuer: PX509; const urls: PPSTACK_OF): PX509_EXTENSION; cdecl;
    TOCSP_parse_url = function(const url: PAnsiChar; phost: PPAnsiChar; pport: PPAnsiChar; 
      ppath: PPAnsiChar; pssl: PInteger): Integer; cdecl;

    // OCSP 响应者 ID
    TOCSP_RESPID_set_by_name = function(respid: POCSP_RESPID; cert: PX509): Integer; cdecl;
    TOCSP_RESPID_set_by_key = function(respid: POCSP_RESPID; cert: PX509): Integer; cdecl;
    TOCSP_RESPID_match = function(respid: POCSP_RESPID; cert: PX509): Integer; cdecl;

    // OCSP CRL ID
    TOCSP_crlID_new = function(const url: PAnsiChar; n: PInteger; tim: ASN1_TIME): POCSP_CRLID; cdecl;

    // OCSP 存档截止
    TOCSP_archive_cutoff_new = function(tim: PAnsiChar): PX509_EXTENSION; cdecl;

    // OCSP 接受语言
    TOCSP_accept_responses_new = function(const oids: PPSTACK_OF): PX509_EXTENSION; cdecl;


var
  // OCSP 请求函数
  OCSP_REQUEST_new: TOCSP_REQUEST_new = nil;
  OCSP_REQUEST_free: TOCSP_REQUEST_free = nil;
  d2i_OCSP_REQUEST: Td2i_OCSP_REQUEST = nil;
  i2d_OCSP_REQUEST: Ti2d_OCSP_REQUEST = nil;
  OCSP_REQUEST_add_ext: TOCSP_REQUEST_add_ext = nil;
  OCSP_REQUEST_get_ext: TOCSP_REQUEST_get_ext = nil;
  OCSP_REQUEST_get_ext_by_NID: TOCSP_REQUEST_get_ext_by_NID = nil;
  OCSP_REQUEST_get_ext_by_OBJ: TOCSP_REQUEST_get_ext_by_OBJ = nil;
  OCSP_REQUEST_get_ext_by_critical: TOCSP_REQUEST_get_ext_by_critical = nil;
  OCSP_REQUEST_get_ext_count: TOCSP_REQUEST_get_ext_count = nil;
  OCSP_REQUEST_delete_ext: TOCSP_REQUEST_delete_ext = nil;
  OCSP_REQUEST_print: TOCSP_REQUEST_print = nil;
  OCSP_REQUEST_sign: TOCSP_REQUEST_sign = nil;

  // OCSP 响应函数
  OCSP_RESPONSE_new: TOCSP_RESPONSE_new = nil;
  OCSP_RESPONSE_free: TOCSP_RESPONSE_free = nil;
  d2i_OCSP_RESPONSE: Td2i_OCSP_RESPONSE = nil;
  i2d_OCSP_RESPONSE: Ti2d_OCSP_RESPONSE = nil;
  OCSP_RESPONSE_create: TOCSP_RESPONSE_create = nil;
  OCSP_RESPONSE_status: TOCSP_RESPONSE_status = nil;
  OCSP_RESPONSE_get1_basic: TOCSP_RESPONSE_get1_basic = nil;
  OCSP_RESPONSE_print: TOCSP_RESPONSE_print = nil;

  // OCSP 基本响应函数
  OCSP_BASICRESP_new: TOCSP_BASICRESP_new = nil;
  OCSP_BASICRESP_free: TOCSP_BASICRESP_free = nil;
  d2i_OCSP_BASICRESP: Td2i_OCSP_BASICRESP = nil;
  i2d_OCSP_BASICRESP: Ti2d_OCSP_BASICRESP = nil;
  OCSP_BASICRESP_add_ext: TOCSP_BASICRESP_add_ext = nil;
  OCSP_BASICRESP_get_ext: TOCSP_BASICRESP_get_ext = nil;
  OCSP_BASICRESP_get_ext_by_NID: TOCSP_BASICRESP_get_ext_by_NID = nil;
  OCSP_BASICRESP_get_ext_by_OBJ: TOCSP_BASICRESP_get_ext_by_OBJ = nil;
  OCSP_BASICRESP_get_ext_by_critical: TOCSP_BASICRESP_get_ext_by_critical = nil;
  OCSP_BASICRESP_get_ext_count: TOCSP_BASICRESP_get_ext_count = nil;
  OCSP_BASICRESP_delete_ext: TOCSP_BASICRESP_delete_ext = nil;
  OCSP_BASICRESP_sign: TOCSP_BASICRESP_sign = nil;
  OCSP_BASICRESP_sign_ctx: TOCSP_BASICRESP_sign_ctx = nil;
  OCSP_BASICRESP_verify: TOCSP_BASICRESP_verify = nil;

  // OCSP 证书 ID 函数
  OCSP_CERTID_new: TOCSP_CERTID_new = nil;
  OCSP_CERTID_free: TOCSP_CERTID_free = nil;
  OCSP_CERTID_dup: TOCSP_CERTID_dup = nil;
  OCSP_cert_to_id: TOCSP_cert_to_id = nil;
  OCSP_cert_id_new: TOCSP_cert_id_new = nil;
  OCSP_id_issuer_cmp: TOCSP_id_issuer_cmp = nil;
  OCSP_id_cmp: TOCSP_id_cmp = nil;
  OCSP_id_get0_info: TOCSP_id_get0_info = nil;

  // OCSP 请求操作
  OCSP_request_add0_id: TOCSP_request_add0_id = nil;
  OCSP_request_add1_nonce: TOCSP_request_add1_nonce = nil;
  OCSP_check_nonce: TOCSP_check_nonce = nil;
  OCSP_copy_nonce: TOCSP_copy_nonce = nil;
  OCSP_request_add1_cert: TOCSP_request_add1_cert = nil;
  OCSP_request_onereq_count: TOCSP_request_onereq_count = nil;
  OCSP_request_onereq_get0: TOCSP_request_onereq_get0 = nil;
  OCSP_onereq_get0_id: TOCSP_onereq_get0_id = nil;
  OCSP_single_get0_status: TOCSP_single_get0_status = nil;

  // OCSP 响应操作
  OCSP_resp_count: TOCSP_resp_count = nil;
  OCSP_resp_get0: TOCSP_resp_get0 = nil;
  OCSP_resp_get0_respdata: TOCSP_resp_get0_respdata = nil;
  OCSP_resp_get0_produced_at: TOCSP_resp_get0_produced_at = nil;
  OCSP_resp_get0_signature: TOCSP_resp_get0_signature = nil;
  OCSP_resp_get1_id: TOCSP_resp_get1_id = nil;
  OCSP_resp_get0_id: TOCSP_resp_get0_id = nil;
  OCSP_resp_get0_certs: TOCSP_resp_get0_certs = nil;
  OCSP_resp_find: TOCSP_resp_find = nil;
  OCSP_resp_find_status: TOCSP_resp_find_status = nil;

  // OCSP 基本响应添加
  OCSP_basic_add1_status: TOCSP_basic_add1_status = nil;
  OCSP_basic_add1_nonce: TOCSP_basic_add1_nonce = nil;
  OCSP_basic_add1_cert: TOCSP_basic_add1_cert = nil;

  // OCSP 检查函数
  OCSP_check_validity: TOCSP_check_validity = nil;

  // OCSP HTTP 函数
  OCSP_sendreq_new: TOCSP_sendreq_new = nil;
  OCSP_sendreq_nbio: TOCSP_sendreq_nbio = nil;
  OCSP_REQ_CTX_free: TOCSP_REQ_CTX_free = nil;
  OCSP_REQ_CTX_http: TOCSP_REQ_CTX_http = nil;
  OCSP_REQ_CTX_set1_req: TOCSP_REQ_CTX_set1_req = nil;
  OCSP_REQ_CTX_add1_header: TOCSP_REQ_CTX_add1_header = nil;
  OCSP_REQ_CTX_i2d: TOCSP_REQ_CTX_i2d = nil;
  OCSP_REQ_CTX_nbio_d2i: TOCSP_REQ_CTX_nbio_d2i = nil;
  OCSP_REQ_CTX_get0_mem_bio: TOCSP_REQ_CTX_get0_mem_bio = nil;
  OCSP_REQ_CTX_nbio: TOCSP_REQ_CTX_nbio = nil;

  // OCSP 服务定位器
  OCSP_url_svcloc_new: TOCSP_url_svcloc_new = nil;
  OCSP_parse_url: TOCSP_parse_url = nil;

  // OCSP 响应者 ID
  OCSP_RESPID_set_by_name: TOCSP_RESPID_set_by_name = nil;
  OCSP_RESPID_set_by_key: TOCSP_RESPID_set_by_key = nil;
  OCSP_RESPID_match: TOCSP_RESPID_match = nil;

  // OCSP CRL ID
  OCSP_crlID_new: TOCSP_crlID_new = nil;

  // OCSP 存档截止
  OCSP_archive_cutoff_new: TOCSP_archive_cutoff_new = nil;

  // OCSP 接受语言
  OCSP_accept_responses_new: TOCSP_accept_responses_new = nil;

// 加载和卸载函数
function LoadOpenSSLOCSP(const ACryptoLib: THandle): Boolean;
procedure UnloadOpenSSLOCSP;

// 辅助函数
function CheckCertificateStatusDetailed(ACert: PX509; AIssuer: PX509;
  const AOCSPUrl: string; ATimeout: Integer = 10; AStore: PX509_STORE = nil): TOCSPCheckResult;
function CheckCertificateStatus(ACert: PX509; AIssuer: PX509;
  const AOCSPUrl: string; ATimeout: Integer = 10; AStore: PX509_STORE = nil): Integer;
function CreateOCSPRequest(ACert: PX509; AIssuer: PX509): POCSP_REQUEST;
function SendOCSPRequest(ARequest: POCSP_REQUEST; const AOCSPUrl: string;
  ATimeout: Integer = 10; ATrustStore: PX509_STORE = nil): POCSP_RESPONSE;
function VerifyOCSPResponse(AResponse: POCSP_RESPONSE; ACert: PX509;
  AIssuer: PX509; AStore: PX509_STORE; ARequest: POCSP_REQUEST = nil): Boolean;
function VerifyOCSPResponseDER(const AResponseDER, ACertDER, AIssuerDER: TBytes;
  out AError: string): Boolean;

implementation

{ OCSP 函数绑定数组
  runtime storage keeps procvar targets writable across macOS batch-loader runs }
var
  OCSPBindings: array[0..83] of TFunctionBinding = (
    // OCSP 请求函数
    (Name: 'OCSP_REQUEST_new'; FuncPtr: @OCSP_REQUEST_new; Required: True),
    (Name: 'OCSP_REQUEST_free'; FuncPtr: @OCSP_REQUEST_free; Required: True),
    (Name: 'd2i_OCSP_REQUEST'; FuncPtr: @d2i_OCSP_REQUEST; Required: False),
    (Name: 'i2d_OCSP_REQUEST'; FuncPtr: @i2d_OCSP_REQUEST; Required: False),
    (Name: 'OCSP_REQUEST_add_ext'; FuncPtr: @OCSP_REQUEST_add_ext; Required: False),
    (Name: 'OCSP_REQUEST_get_ext'; FuncPtr: @OCSP_REQUEST_get_ext; Required: False),
    (Name: 'OCSP_REQUEST_get_ext_by_NID'; FuncPtr: @OCSP_REQUEST_get_ext_by_NID; Required: False),
    (Name: 'OCSP_REQUEST_get_ext_by_OBJ'; FuncPtr: @OCSP_REQUEST_get_ext_by_OBJ; Required: False),
    (Name: 'OCSP_REQUEST_get_ext_by_critical'; FuncPtr: @OCSP_REQUEST_get_ext_by_critical; Required: False),
    (Name: 'OCSP_REQUEST_get_ext_count'; FuncPtr: @OCSP_REQUEST_get_ext_count; Required: False),
    (Name: 'OCSP_REQUEST_delete_ext'; FuncPtr: @OCSP_REQUEST_delete_ext; Required: False),
    (Name: 'OCSP_REQUEST_print'; FuncPtr: @OCSP_REQUEST_print; Required: False),
    (Name: 'OCSP_REQUEST_sign'; FuncPtr: @OCSP_REQUEST_sign; Required: False),
    // OCSP 响应函数
    (Name: 'OCSP_RESPONSE_new'; FuncPtr: @OCSP_RESPONSE_new; Required: True),
    (Name: 'OCSP_RESPONSE_free'; FuncPtr: @OCSP_RESPONSE_free; Required: True),
    (Name: 'd2i_OCSP_RESPONSE'; FuncPtr: @d2i_OCSP_RESPONSE; Required: False),
    (Name: 'i2d_OCSP_RESPONSE'; FuncPtr: @i2d_OCSP_RESPONSE; Required: False),
    (Name: 'OCSP_RESPONSE_create'; FuncPtr: @OCSP_RESPONSE_create; Required: False),
    (Name: 'OCSP_RESPONSE_status'; FuncPtr: @OCSP_RESPONSE_status; Required: False),
    (Name: 'OCSP_RESPONSE_get1_basic'; FuncPtr: @OCSP_RESPONSE_get1_basic; Required: False),
    (Name: 'OCSP_RESPONSE_print'; FuncPtr: @OCSP_RESPONSE_print; Required: False),
    // OCSP 基本响应函数
    (Name: 'OCSP_BASICRESP_new'; FuncPtr: @OCSP_BASICRESP_new; Required: False),
    (Name: 'OCSP_BASICRESP_free'; FuncPtr: @OCSP_BASICRESP_free; Required: False),
    (Name: 'd2i_OCSP_BASICRESP'; FuncPtr: @d2i_OCSP_BASICRESP; Required: False),
    (Name: 'i2d_OCSP_BASICRESP'; FuncPtr: @i2d_OCSP_BASICRESP; Required: False),
    (Name: 'OCSP_BASICRESP_add_ext'; FuncPtr: @OCSP_BASICRESP_add_ext; Required: False),
    (Name: 'OCSP_BASICRESP_get_ext'; FuncPtr: @OCSP_BASICRESP_get_ext; Required: False),
    (Name: 'OCSP_BASICRESP_get_ext_by_NID'; FuncPtr: @OCSP_BASICRESP_get_ext_by_NID; Required: False),
    (Name: 'OCSP_BASICRESP_get_ext_by_OBJ'; FuncPtr: @OCSP_BASICRESP_get_ext_by_OBJ; Required: False),
    (Name: 'OCSP_BASICRESP_get_ext_by_critical'; FuncPtr: @OCSP_BASICRESP_get_ext_by_critical; Required: False),
    (Name: 'OCSP_BASICRESP_get_ext_count'; FuncPtr: @OCSP_BASICRESP_get_ext_count; Required: False),
    (Name: 'OCSP_BASICRESP_delete_ext'; FuncPtr: @OCSP_BASICRESP_delete_ext; Required: False),
    (Name: 'OCSP_BASICRESP_sign'; FuncPtr: @OCSP_BASICRESP_sign; Required: False),
    (Name: 'OCSP_BASICRESP_sign_ctx'; FuncPtr: @OCSP_BASICRESP_sign_ctx; Required: False),
    (Name: 'OCSP_BASICRESP_verify'; FuncPtr: @OCSP_BASICRESP_verify; Required: False),
    // OCSP 证书 ID 函数
    (Name: 'OCSP_CERTID_new'; FuncPtr: @OCSP_CERTID_new; Required: False),
    (Name: 'OCSP_CERTID_free'; FuncPtr: @OCSP_CERTID_free; Required: False),
    (Name: 'OCSP_CERTID_dup'; FuncPtr: @OCSP_CERTID_dup; Required: False),
    (Name: 'OCSP_cert_to_id'; FuncPtr: @OCSP_cert_to_id; Required: False),
    (Name: 'OCSP_cert_id_new'; FuncPtr: @OCSP_cert_id_new; Required: False),
    (Name: 'OCSP_id_issuer_cmp'; FuncPtr: @OCSP_id_issuer_cmp; Required: False),
    (Name: 'OCSP_id_cmp'; FuncPtr: @OCSP_id_cmp; Required: False),
    (Name: 'OCSP_id_get0_info'; FuncPtr: @OCSP_id_get0_info; Required: False),
    // OCSP 请求操作
    (Name: 'OCSP_request_add0_id'; FuncPtr: @OCSP_request_add0_id; Required: False),
    (Name: 'OCSP_request_add1_nonce'; FuncPtr: @OCSP_request_add1_nonce; Required: False),
    (Name: 'OCSP_check_nonce'; FuncPtr: @OCSP_check_nonce; Required: False),
    (Name: 'OCSP_copy_nonce'; FuncPtr: @OCSP_copy_nonce; Required: False),
    (Name: 'OCSP_request_add1_cert'; FuncPtr: @OCSP_request_add1_cert; Required: False),
    (Name: 'OCSP_request_onereq_count'; FuncPtr: @OCSP_request_onereq_count; Required: False),
    (Name: 'OCSP_request_onereq_get0'; FuncPtr: @OCSP_request_onereq_get0; Required: False),
    (Name: 'OCSP_onereq_get0_id'; FuncPtr: @OCSP_onereq_get0_id; Required: False),
    (Name: 'OCSP_single_get0_status'; FuncPtr: @OCSP_single_get0_status; Required: False),
    // OCSP 响应操作
    (Name: 'OCSP_resp_count'; FuncPtr: @OCSP_resp_count; Required: False),
    (Name: 'OCSP_resp_get0'; FuncPtr: @OCSP_resp_get0; Required: False),
    (Name: 'OCSP_resp_get0_respdata'; FuncPtr: @OCSP_resp_get0_respdata; Required: False),
    (Name: 'OCSP_resp_get0_produced_at'; FuncPtr: @OCSP_resp_get0_produced_at; Required: False),
    (Name: 'OCSP_resp_get0_signature'; FuncPtr: @OCSP_resp_get0_signature; Required: False),
    (Name: 'OCSP_resp_get1_id'; FuncPtr: @OCSP_resp_get1_id; Required: False),
    (Name: 'OCSP_resp_get0_id'; FuncPtr: @OCSP_resp_get0_id; Required: False),
    (Name: 'OCSP_resp_get0_certs'; FuncPtr: @OCSP_resp_get0_certs; Required: False),
    (Name: 'OCSP_resp_find'; FuncPtr: @OCSP_resp_find; Required: False),
    (Name: 'OCSP_resp_find_status'; FuncPtr: @OCSP_resp_find_status; Required: False),
    // OCSP 基本响应添加
    (Name: 'OCSP_basic_add1_status'; FuncPtr: @OCSP_basic_add1_status; Required: False),
    (Name: 'OCSP_basic_add1_nonce'; FuncPtr: @OCSP_basic_add1_nonce; Required: False),
    (Name: 'OCSP_basic_add1_cert'; FuncPtr: @OCSP_basic_add1_cert; Required: False),
    // OCSP 检查函数
    (Name: 'OCSP_check_validity'; FuncPtr: @OCSP_check_validity; Required: False),
    // OCSP HTTP 函数
    (Name: 'OCSP_sendreq_new'; FuncPtr: @OCSP_sendreq_new; Required: False),
    (Name: 'OCSP_sendreq_nbio'; FuncPtr: @OCSP_sendreq_nbio; Required: False),
    (Name: 'OCSP_REQ_CTX_free'; FuncPtr: @OCSP_REQ_CTX_free; Required: False),
    (Name: 'OCSP_REQ_CTX_http'; FuncPtr: @OCSP_REQ_CTX_http; Required: False),
    (Name: 'OCSP_REQ_CTX_set1_req'; FuncPtr: @OCSP_REQ_CTX_set1_req; Required: False),
    (Name: 'OCSP_REQ_CTX_add1_header'; FuncPtr: @OCSP_REQ_CTX_add1_header; Required: False),
    (Name: 'OCSP_REQ_CTX_i2d'; FuncPtr: @OCSP_REQ_CTX_i2d; Required: False),
    (Name: 'OCSP_REQ_CTX_nbio_d2i'; FuncPtr: @OCSP_REQ_CTX_nbio_d2i; Required: False),
    (Name: 'OCSP_REQ_CTX_get0_mem_bio'; FuncPtr: @OCSP_REQ_CTX_get0_mem_bio; Required: False),
    (Name: 'OCSP_REQ_CTX_nbio'; FuncPtr: @OCSP_REQ_CTX_nbio; Required: False),
    // OCSP 服务定位器
    (Name: 'OCSP_url_svcloc_new'; FuncPtr: @OCSP_url_svcloc_new; Required: False),
    (Name: 'OCSP_parse_url'; FuncPtr: @OCSP_parse_url; Required: False),
    // OCSP 响应者 ID
    (Name: 'OCSP_RESPID_set_by_name'; FuncPtr: @OCSP_RESPID_set_by_name; Required: False),
    (Name: 'OCSP_RESPID_set_by_key'; FuncPtr: @OCSP_RESPID_set_by_key; Required: False),
    (Name: 'OCSP_RESPID_match'; FuncPtr: @OCSP_RESPID_match; Required: False),
    // OCSP CRL ID
    (Name: 'OCSP_crlID_new'; FuncPtr: @OCSP_crlID_new; Required: False),
    // OCSP 存档截止
    (Name: 'OCSP_archive_cutoff_new'; FuncPtr: @OCSP_archive_cutoff_new; Required: False),
    // OCSP 接受语言
    (Name: 'OCSP_accept_responses_new'; FuncPtr: @OCSP_accept_responses_new; Required: False)
  );

function LoadOpenSSLOCSP(const ACryptoLib: THandle): Boolean;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmOCSP) then
    Exit(True);

  if ACryptoLib = 0 then
    Exit(False);

  // 使用批量加载模式
  TOpenSSLLoader.LoadFunctions(ACryptoLib, OCSPBindings);

  // OpenSSL 3.x 中部分 OCSP API 使用小写命名（非旧式宏导出）
  if not Assigned(OCSP_RESPONSE_create) then
    OCSP_RESPONSE_create := TOCSP_RESPONSE_create(GetProcedureAddress(ACryptoLib, 'OCSP_response_create'));

  if not Assigned(OCSP_RESPONSE_status) then
    OCSP_RESPONSE_status := TOCSP_RESPONSE_status(GetProcedureAddress(ACryptoLib, 'OCSP_response_status'));

  if not Assigned(OCSP_RESPONSE_get1_basic) then
    OCSP_RESPONSE_get1_basic := TOCSP_RESPONSE_get1_basic(GetProcedureAddress(ACryptoLib, 'OCSP_response_get1_basic'));

  TOpenSSLLoader.SetModuleLoaded(osmOCSP, Assigned(OCSP_REQUEST_new) and Assigned(OCSP_RESPONSE_new));
  Result := TOpenSSLLoader.IsModuleLoaded(osmOCSP);
end;

procedure UnloadOpenSSLOCSP;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmOCSP) then
    Exit;

  // 使用批量清理模式
  TOpenSSLLoader.ClearFunctions(OCSPBindings);

  TOpenSSLLoader.SetModuleLoaded(osmOCSP, False);
end;

// 辅助函数实现
function CheckCertificateStatusDetailed(ACert: PX509; AIssuer: PX509;
  const AOCSPUrl: string; ATimeout: Integer; AStore: PX509_STORE): TOCSPCheckResult;
var
  Req: POCSP_REQUEST;
  Resp: POCSP_RESPONSE;
  BasicResp: POCSP_BASICRESP;
  CertID: POCSP_CERTID;
  Certs: PSTACK_OF_X509;
  LCertStatus, Reason: Integer;
  RevTime, ThisUpd, NextUpd: PASN1_GENERALIZEDTIME;
  LVerifyStore: PX509_STORE;
  LOwnsStore: Boolean;
  LNonceRes: Integer;
  LLib: THandle;

  procedure Fail(AStage: TOCSPCheckFailureStage; const AMessage: string);
  begin
    Result.CertStatus := V_OCSP_CERTSTATUS_ERROR;
    Result.Verified := False;
    Result.FailureStage := AStage;
    Result.ErrorMessage := AMessage;
  end;

  function EnsureDependenciesLoaded: Boolean;
  begin
    Result := True;

    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      try
        LoadOpenSSLCore;
      except
        Exit(False);
      end;
    end;

    if not TOpenSSLLoader.IsModuleLoaded(osmBIO) then
      LoadOpenSSLBIO;

    if not TOpenSSLLoader.IsModuleLoaded(osmStack) then
      LoadStackFunctions;

    if not TOpenSSLLoader.IsModuleLoaded(osmEVP) then
    begin
      LLib := GetCryptoLibHandle;
      if LLib <> 0 then
        LoadEVP(LLib);
    end;

    if not Assigned(EVP_sha1) then
      Exit(False);

    if not TOpenSSLLoader.IsModuleLoaded(osmX509) then
      LoadOpenSSLX509;
  end;

begin
  Result.CertStatus := V_OCSP_CERTSTATUS_ERROR;
  Result.Verified := False;
  Result.ResponseStatus := -1;
  Result.FailureStage := ocspCheckNone;
  Result.ErrorMessage := '';

  if (not TOpenSSLLoader.IsModuleLoaded(osmOCSP)) or
    (ACert = nil) or (AIssuer = nil) or (AOCSPUrl = '') then
  begin
    Fail(ocspCheckDependenciesUnavailable, 'OCSP verification prerequisites are unavailable');
    Exit;
  end;

  if not EnsureDependenciesLoaded then
  begin
    Fail(ocspCheckDependenciesUnavailable, 'OCSP verification prerequisites are unavailable');
    Exit;
  end;

  if (not Assigned(OCSP_RESPONSE_status)) or
    (not Assigned(OCSP_RESPONSE_get1_basic)) or
    (not Assigned(OCSP_BASICRESP_verify)) or
    (not Assigned(OCSP_cert_to_id)) or
    (not Assigned(OCSP_resp_find_status)) or
    (not Assigned(OCSP_check_validity)) then
  begin
    Fail(ocspCheckDependenciesUnavailable, 'OCSP verification API is incomplete');
    Exit;
  end;

  Req := CreateOCSPRequest(ACert, AIssuer);
  if Req = nil then
  begin
    Fail(ocspCheckRequestCreation, 'Failed to create OCSP request');
    Exit;
  end;

  try
    Resp := SendOCSPRequest(Req, AOCSPUrl, ATimeout, AStore);
    if Resp = nil then
    begin
      Fail(ocspCheckTransport, 'OCSP transport or response parsing failed');
      Exit;
    end;

    try
      Result.ResponseStatus := OCSP_RESPONSE_status(Resp);
      if Result.ResponseStatus <> OCSP_RESPONSE_STATUS_SUCCESSFUL then
      begin
        Fail(
          ocspCheckResponseStatus,
          Format('OCSP responder returned unsuccessful response status (%d)', [Result.ResponseStatus])
        );
        Exit;
      end;

      BasicResp := OCSP_RESPONSE_get1_basic(Resp);
      if BasicResp = nil then
      begin
        Fail(ocspCheckBasicResponse, 'OCSP basic response is unavailable');
        Exit;
      end;

      try
        if Assigned(OCSP_check_nonce) then
        begin
          LNonceRes := OCSP_check_nonce(Req, BasicResp);
          if LNonceRes = -1 then
          begin
            Fail(ocspCheckNonceValidation, 'OCSP nonce validation failed');
            Exit;
          end;
        end;

        LVerifyStore := AStore;
        LOwnsStore := False;

        if LVerifyStore = nil then
        begin
          if not Assigned(X509_STORE_new) then
          begin
            Fail(ocspCheckDependenciesUnavailable, 'OCSP verification store helper is unavailable');
            Exit;
          end;

          LVerifyStore := X509_STORE_new();
          if LVerifyStore = nil then
          begin
            Fail(ocspCheckDependenciesUnavailable, 'Failed to create OCSP verification store');
            Exit;
          end;

          LOwnsStore := True;
          if Assigned(X509_STORE_set_default_paths) then
            X509_STORE_set_default_paths(LVerifyStore);
        end;

        try
          Certs := nil;
          if Assigned(sk_X509_new_null) and Assigned(sk_X509_push) then
          begin
            Certs := sk_X509_new_null();
            if (Certs <> nil) and (AIssuer <> nil) then
              sk_X509_push(Certs, AIssuer);
          end;

          try
            if OCSP_BASICRESP_verify(BasicResp, Certs, LVerifyStore, 0) <> 1 then
            begin
              Fail(
                ocspCheckCryptographicVerification,
                'OCSP responder signature or delegated-responder verification failed'
              );
              Exit;
            end;
          finally
            if Certs <> nil then
              sk_X509_free(Certs);
          end;
        finally
          if LOwnsStore and Assigned(X509_STORE_free) then
            X509_STORE_free(LVerifyStore);
        end;

        CertID := OCSP_cert_to_id(EVP_sha1(), ACert, AIssuer);
        if CertID = nil then
        begin
          Fail(ocspCheckStatusLookup, 'Failed to create OCSP certificate identifier');
          Exit;
        end;

        try
          if OCSP_resp_find_status(BasicResp, CertID, @LCertStatus, @Reason,
            @RevTime, @ThisUpd, @NextUpd) <> 1 then
          begin
            Fail(ocspCheckStatusLookup,
              'OCSP responder did not return status for the peer certificate');
            Exit;
          end;

          if OCSP_check_validity(ThisUpd, NextUpd, 300, -1) <> 1 then
          begin
            Fail(ocspCheckValidity, 'OCSP response validity check failed');
            Exit;
          end;

          Result.CertStatus := LCertStatus;
          Result.Verified := True;
          Result.FailureStage := ocspCheckNone;
          Result.ErrorMessage := '';
        finally
          OCSP_CERTID_free(CertID);
        end;

      finally
        OCSP_BASICRESP_free(BasicResp);
      end;

    finally
      OCSP_RESPONSE_free(Resp);
    end;

  finally
    OCSP_REQUEST_free(Req);
  end;
end;

function CheckCertificateStatus(ACert: PX509; AIssuer: PX509;
  const AOCSPUrl: string; ATimeout: Integer; AStore: PX509_STORE): Integer;
var
  LResult: TOCSPCheckResult;
begin
  LResult := CheckCertificateStatusDetailed(ACert, AIssuer, AOCSPUrl, ATimeout, AStore);
  if LResult.Verified then
    Result := LResult.CertStatus
  else
    Result := V_OCSP_CERTSTATUS_ERROR;
end;

function CreateOCSPRequest(ACert: PX509; AIssuer: PX509): POCSP_REQUEST;
var
  CertID: POCSP_CERTID;
begin
  Result := nil;
  if not TOpenSSLLoader.IsModuleLoaded(osmOCSP) or (ACert = nil) or (AIssuer = nil) then
    Exit;

  Result := OCSP_REQUEST_new();
  if Result = nil then
    Exit;

  // 创建证书 ID
  CertID := OCSP_cert_to_id(EVP_sha1(), ACert, AIssuer);
  if CertID = nil then
  begin
    OCSP_REQUEST_free(Result);
    Result := nil;
    Exit;
  end;

  // 添加证书 ID 到请求
  if OCSP_request_add0_id(Result, CertID) = nil then
  begin
    OCSP_CERTID_free(CertID);
    OCSP_REQUEST_free(Result);
    Result := nil;
    Exit;
  end;

  // 添加 nonce
  OCSP_request_add1_nonce(Result, nil, -1);
end;

function SendOCSPRequest(ARequest: POCSP_REQUEST; const AOCSPUrl: string;
  ATimeout: Integer; ATrustStore: PX509_STORE): POCSP_RESPONSE;
var
  LReqLen: Integer;
  LReqDER: TBytes;
  LReqPtr: PByte;
  LPostRes: TSSLDataResult;
  LRespPtr: PByte;

begin
  Result := nil;

  if (not TOpenSSLLoader.IsModuleLoaded(osmOCSP)) or (ARequest = nil) or (AOCSPUrl = '') then
    Exit;

  // Silence unused parameter hints: transport is provided by caller hooks.
  if ATrustStore <> nil then ;

  // Need DER encode/decode helpers for hook-based transport.
  if (not Assigned(i2d_OCSP_REQUEST)) or (not Assigned(d2i_OCSP_RESPONSE)) then
    Exit;

  // Normalize timeout
  if ATimeout <= 0 then
    ATimeout := 10;

  LReqLen := i2d_OCSP_REQUEST(ARequest, nil);
  if LReqLen <= 0 then
    Exit;

  SetLength(LReqDER, LReqLen);
  LReqPtr := @LReqDER[0];
  if i2d_OCSP_REQUEST(ARequest, @LReqPtr) <> LReqLen then
    Exit;

  // HTTP transport is provided by caller/framework (nextpas.core.tls.net.hooks).
  LPostRes := SSLHTTPPost(AOCSPUrl, 'application/ocsp-request', LReqDER, ATimeout * 1000);
  if (not LPostRes.Success) or (Length(LPostRes.Data) = 0) then
    Exit;

  LRespPtr := @LPostRes.Data[0];
  Result := d2i_OCSP_RESPONSE(nil, @LRespPtr, Length(LPostRes.Data));
end;

function VerifyOCSPResponse(AResponse: POCSP_RESPONSE; ACert: PX509;
  AIssuer: PX509; AStore: PX509_STORE; ARequest: POCSP_REQUEST): Boolean;
var
  BasicResp: POCSP_BASICRESP;
  Certs: PSTACK_OF_X509;
  LVerifyStore: PX509_STORE;
  LOwnsStore: Boolean;
  LNonceRes: Integer;
begin
  Result := False;

  if (not TOpenSSLLoader.IsModuleLoaded(osmOCSP)) or (AResponse = nil) then
    Exit;

  if not TOpenSSLLoader.IsModuleLoaded(osmStack) then
    LoadStackFunctions;

  if not TOpenSSLLoader.IsModuleLoaded(osmX509) then
    LoadOpenSSLX509;

  if (not Assigned(OCSP_RESPONSE_status)) or
    (not Assigned(OCSP_RESPONSE_get1_basic)) or
    (not Assigned(OCSP_BASICRESP_verify)) then
    Exit;

  // 检查响应状态
  if OCSP_RESPONSE_status(AResponse) <> OCSP_RESPONSE_STATUS_SUCCESSFUL then
    Exit;

  // 获取基本响应
  BasicResp := OCSP_RESPONSE_get1_basic(AResponse);
  if BasicResp = nil then
    Exit;

  try
    // Nonce mismatch must fail (no nonce is acceptable)
    if (ARequest <> nil) and Assigned(OCSP_check_nonce) then
    begin
      LNonceRes := OCSP_check_nonce(ARequest, BasicResp);
      if LNonceRes = -1 then
        Exit(False);
    end;

    LVerifyStore := AStore;
    LOwnsStore := False;

    if LVerifyStore = nil then
    begin
      if not Assigned(X509_STORE_new) then
        Exit;

      LVerifyStore := X509_STORE_new();
      if LVerifyStore = nil then
        Exit;

      LOwnsStore := True;
      if Assigned(X509_STORE_set_default_paths) then
        X509_STORE_set_default_paths(LVerifyStore);
    end;

    try
      Certs := nil;
      if Assigned(sk_X509_new_null) and Assigned(sk_X509_push) then
      begin
        Certs := sk_X509_new_null();
        if (Certs <> nil) and (AIssuer <> nil) then
          sk_X509_push(Certs, AIssuer);
      end;

      try
        Result := (OCSP_BASICRESP_verify(BasicResp, Certs, LVerifyStore, 0) = 1);
      finally
        if Certs <> nil then
          sk_X509_free(Certs);
      end;

    finally
      if LOwnsStore and Assigned(X509_STORE_free) then
        X509_STORE_free(LVerifyStore);
    end;

  finally
    OCSP_BASICRESP_free(BasicResp);
  end;
end;


function VerifyOCSPResponseDER(const AResponseDER, ACertDER, AIssuerDER: TBytes;
  out AError: string): Boolean;
var
  LCryptoLib: THandle;
  LResponse: POCSP_RESPONSE;
  LLeaf: PX509;
  LIssuer: PX509;
  LStore: PX509_STORE;
  LResponsePtr: PByte;
  LLeafPtr: PByte;
  LIssuerPtr: PByte;
begin
  AError := '';
  Result := False;
  LResponse := nil;
  LLeaf := nil;
  LIssuer := nil;
  LStore := nil;

  if Length(AResponseDER) = 0 then
  begin
    AError := 'OCSP response bytes are empty';
    Exit;
  end;

  if Length(ACertDER) = 0 then
  begin
    AError := 'Leaf certificate DER is empty';
    Exit;
  end;

  if Length(AIssuerDER) = 0 then
  begin
    AError := 'Issuer certificate DER is empty';
    Exit;
  end;

  try
    try
      LoadOpenSSLCore;
      LoadOpenSSLX509;
      LoadOpenSSLBIO;
      LoadStackFunctions;
    except
      on E: Exception do
      begin
        AError := 'Failed to initialize OpenSSL verification modules: ' + E.Message;
        Exit;
      end;
    end;

    LCryptoLib := GetCryptoLibHandle;
    if (LCryptoLib = 0) or (not LoadOpenSSLOCSP(LCryptoLib)) then
    begin
      AError := 'OpenSSL OCSP verification helper is unavailable';
      Exit;
    end;

    if (not Assigned(d2i_OCSP_RESPONSE)) or
      (not Assigned(d2i_X509)) or
      (not Assigned(OCSP_RESPONSE_free)) or
      (not Assigned(X509_free)) or
      (not Assigned(X509_STORE_new)) or
      (not Assigned(X509_STORE_free)) or
      (not Assigned(X509_STORE_add_cert)) then
    begin
      AError := 'Required OpenSSL OCSP/X509 functions are unavailable';
      Exit;
    end;

    LResponsePtr := @AResponseDER[0];
    LResponse := d2i_OCSP_RESPONSE(nil, @LResponsePtr, Length(AResponseDER));
    if LResponse = nil then
    begin
      AError := 'Failed to parse OCSP response DER for cryptographic verification';
      Exit;
    end;

    LLeafPtr := @ACertDER[0];
    LLeaf := d2i_X509(nil, @LLeafPtr, Length(ACertDER));
    if LLeaf = nil then
    begin
      AError := 'Failed to parse leaf certificate DER for OCSP verification';
      Exit;
    end;

    LIssuerPtr := @AIssuerDER[0];
    LIssuer := d2i_X509(nil, @LIssuerPtr, Length(AIssuerDER));
    if LIssuer = nil then
    begin
      AError := 'Failed to parse issuer certificate DER for OCSP verification';
      Exit;
    end;

    LStore := X509_STORE_new();
    if LStore = nil then
    begin
      AError := 'Failed to create OpenSSL OCSP verification store';
      Exit;
    end;

    if Assigned(X509_STORE_set_default_paths) then
      X509_STORE_set_default_paths(LStore);

    if X509_STORE_add_cert(LStore, LIssuer) <> 1 then
    begin
      AError := 'Failed to seed issuer certificate into OCSP verification store';
      Exit;
    end;

    Result := VerifyOCSPResponse(LResponse, LLeaf, LIssuer, LStore, nil);
    if (not Result) and (AError = '') then
      AError := 'OCSP response cryptographic verification failed';
  finally
    if LStore <> nil then
      X509_STORE_free(LStore);
    if LIssuer <> nil then
      X509_free(LIssuer);
    if LLeaf <> nil then
      X509_free(LLeaf);
    if LResponse <> nil then
      OCSP_RESPONSE_free(LResponse);
  end;
end;

end.
