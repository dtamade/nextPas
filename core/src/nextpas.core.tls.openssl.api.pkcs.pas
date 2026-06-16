unit nextpas.core.tls.openssl.api.pkcs;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.base, nextpas.core.fs, dynlibs, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.consts, nextpas.core.tls.openssl.api.asn1, nextpas.core.tls.openssl.api.bio, nextpas.core.tls.openssl.loader;

type
  // PKCS7 类型定义
  PKCS7 = Pointer;
  PPKCS7 = ^PKCS7;
  PPPKCS7 = ^PPKCS7;
  PKCS7_SIGNER_INFO = Pointer;
  PPKCS7_SIGNER_INFO = ^PKCS7_SIGNER_INFO;
  PKCS7_RECIP_INFO = Pointer;
  PPKCS7_RECIP_INFO = ^PKCS7_RECIP_INFO;
  PKCS7_SIGNED = Pointer;
  PKCS7_ENC_CONTENT = Pointer;
  PKCS7_ENVELOPE = Pointer;
  PKCS7_SIGN_ENVELOPE = Pointer;
  PKCS7_DIGEST = Pointer;
  PKCS7_ENCRYPTED_TYPE = Pointer;  // Renamed to avoid conflict
  PKCS7_ATTR_SIGN = Pointer;
  PKCS7_ATTR_VERIFY = Pointer;
  
  // Stack types
  PSTACK_OF_PKCS7_SIGNER_INFO = POPENSSL_STACK;
  PSTACK_OF_X509_ATTRIBUTE = POPENSSL_STACK;
  PSTACK_OF_PKCS12_SAFEBAG = POPENSSL_STACK;
  PPSTACK_OF_PKCS12_SAFEBAG = ^PSTACK_OF_PKCS12_SAFEBAG;

  // PKCS12 类型定义
  PKCS12 = Pointer;
  PPKCS12 = ^PKCS12;
  PPPKCS12 = ^PPKCS12;
  PKCS12_MAC_DATA = Pointer;
  PKCS12_SAFEBAG = Pointer;
  PPKCS12_SAFEBAG = ^PKCS12_SAFEBAG;
  PKCS8_PRIV_KEY_INFO = Pointer;
  PPKCS8_PRIV_KEY_INFO = ^PKCS8_PRIV_KEY_INFO;
  PPPKCS8_PRIV_KEY_INFO = ^PPKCS8_PRIV_KEY_INFO;
  X509_SIG = Pointer;
  PX509_SIG = ^X509_SIG;
  PPX509_SIG = ^PX509_SIG;

  // PKCS7 标志
  const
    PKCS7_TEXT             = $1;
    PKCS7_NOCERTS          = $2;
    PKCS7_NOSIGS           = $4;
    PKCS7_NOCHAIN          = $8;
    PKCS7_NOINTERN         = $10;
    PKCS7_NOVERIFY         = $20;
    PKCS7_DETACHED         = $40;
    PKCS7_BINARY           = $80;
    PKCS7_NOATTR           = $100;
    PKCS7_NOSMIMECAP       = $200;
    PKCS7_NOOLDMIMETYPE    = $400;
    PKCS7_CRLFEOL          = $800;
    PKCS7_STREAM           = $1000;
    PKCS7_NOCRL            = $2000;
    PKCS7_PARTIAL          = $4000;
    PKCS7_REUSE_DIGEST     = $8000;
    PKCS7_NO_DUAL_CONTENT  = $10000;

    // PKCS7 签名标志
    PKCS7_OP_SET_DETACHED_SIGNATURE = 1;
    PKCS7_OP_GET_DETACHED_SIGNATURE = 2;

    // PKCS12 密钥标志
    PKCS12_KEY_ID         = 1;
    PKCS12_IV_ID          = 2;
    PKCS12_MAC_ID         = 3;

    // PKCS12 PBE 算法
    PKCS12_RC2_40_SHA     = 1;
    PKCS12_3DES_SHA       = 2;
    PKCS12_RC2_128_SHA    = 3;
    PKCS12_RC4_40_SHA     = 4;
    PKCS12_RC4_128_SHA    = 5;

  // PKCS7 函数类型
  type
    // PKCS7 创建和释放
    TPKCS7_new = function(): PPKCS7; cdecl;
    TPKCS7_free = procedure(p7: PPKCS7); cdecl;
    TPKCS7_dup = function(p7: PPKCS7): PPKCS7; cdecl;
    Td2i_PKCS7 = function(a: PPPKCS7; const pp: PPByte; length: Integer): PPKCS7; cdecl;
    Ti2d_PKCS7 = function(a: PPKCS7; out_: PPByte): Integer; cdecl;
    Td2i_PKCS7_bio = function(bp: PBIO; p7: PPPKCS7): PPKCS7; cdecl;
    Ti2d_PKCS7_bio = function(bp: PBIO; p7: PPKCS7): Integer; cdecl;
    TPKCS7_bio_add_digest = function(pbio: PPBIO; alg: PX509_ALGOR): PBIO; cdecl;

    // PKCS7 签名操作
    TPKCS7_sign = function(signcert: PX509; pkey: PEVP_PKEY; certs: PSTACK_OF_X509; 
      data: PBIO; flags: Integer): PPKCS7; cdecl;
    TPKCS7_sign_add_signer = function(p7: PPKCS7; signcert: PX509; pkey: PEVP_PKEY; 
      const md: PEVP_MD; flags: Integer): PKCS7_SIGNER_INFO; cdecl;
    TPKCS7_final = function(p7: PPKCS7; data: PBIO; flags: Integer): Integer; cdecl;
    TPKCS7_verify = function(p7: PPKCS7; certs: PSTACK_OF_X509; store: PX509_STORE; 
      indata: PBIO; out_: PBIO; flags: Integer): Integer; cdecl;
    TPKCS7_get0_signers = function(p7: PPKCS7; certs: PSTACK_OF_X509; 
      flags: Integer): PSTACK_OF_X509; cdecl;

    // PKCS7 加密操作
    TPKCS7_encrypt = function(certs: PSTACK_OF_X509; in_: PBIO; const cipher: PEVP_CIPHER; 
      flags: Integer): PPKCS7; cdecl;
    TPKCS7_decrypt = function(p7: PPKCS7; pkey: PEVP_PKEY; cert: PX509; 
      data: PBIO; flags: Integer): Integer; cdecl;

    // PKCS7 属性操作
    TPKCS7_add_certificate = function(p7: PPKCS7; x509: PX509): Integer; cdecl;
    TPKCS7_add_crl = function(p7: PPKCS7; x: PX509_CRL): Integer; cdecl;
    TPKCS7_content_new = function(p7: PPKCS7; nid: Integer): Integer; cdecl;
    TPKCS7_set_type = function(p7: PPKCS7; atype: Integer): Integer; cdecl;
    TPKCS7_set_content = function(p7: PPKCS7; p7_data: PPKCS7): Integer; cdecl;
    TPKCS7_set_cipher = function(p7: PPKCS7; const cipher: PEVP_CIPHER): Integer; cdecl;
    TPKCS7_stream = function(boundary: PPBYTE; p7: PPKCS7): Integer; cdecl;

    // PKCS7 数据访问
    TPKCS7_get_signer_info = function(p7: PPKCS7): PSTACK_OF_PKCS7_SIGNER_INFO; cdecl;
    TPKCS7_dataInit = function(p7: PPKCS7; bio: PBIO): PBIO; cdecl;
    TPKCS7_dataFinal = function(p7: PPKCS7; bio: PBIO): Integer; cdecl;
    TPKCS7_dataDecode = function(p7: PPKCS7; pkey: PEVP_PKEY; in_bio: PBIO; 
      pcert: PX509): PBIO; cdecl;
    TPKCS7_dataVerify = function(cert_store: PX509_STORE; ctx: PX509_STORE_CTX; 
      bio: PBIO; p7: PPKCS7; si: PKCS7_SIGNER_INFO): Integer; cdecl;

    // PKCS7 签名信息
    TPKCS7_SIGNER_INFO_new = function(): PKCS7_SIGNER_INFO; cdecl;
    TPKCS7_SIGNER_INFO_free = procedure(a: PKCS7_SIGNER_INFO); cdecl;
    TPKCS7_SIGNER_INFO_set = function(p7i: PKCS7_SIGNER_INFO; x509: PX509; 
      pkey: PEVP_PKEY; const dgst: PEVP_MD): Integer; cdecl;
    TPKCS7_SIGNER_INFO_sign = function(si: PKCS7_SIGNER_INFO): Integer; cdecl;
    TPKCS7_add_signature = function(p7: PPKCS7; x509: PX509; pkey: PEVP_PKEY; 
      const dgst: PEVP_MD): PKCS7_SIGNER_INFO; cdecl;
    TPKCS7_set_signed_attributes = function(p7si: PKCS7_SIGNER_INFO; 
      sk: PSTACK_OF_X509_ATTRIBUTE): Integer; cdecl;
    TPKCS7_set_attributes = function(p7si: PKCS7_SIGNER_INFO; 
      sk: PSTACK_OF_X509_ATTRIBUTE): Integer; cdecl;
    TPKCS7_get_signed_attributes = function(const si: PKCS7_SIGNER_INFO): PSTACK_OF_X509_ATTRIBUTE; cdecl;
    TPKCS7_get_attributes = function(const si: PKCS7_SIGNER_INFO): PSTACK_OF_X509_ATTRIBUTE; cdecl;

    // PKCS7 接收者信息
    TPKCS7_RECIP_INFO_new = function(): PKCS7_RECIP_INFO; cdecl;
    TPKCS7_RECIP_INFO_free = procedure(a: PKCS7_RECIP_INFO); cdecl;
    TPKCS7_RECIP_INFO_set = function(p7i: PKCS7_RECIP_INFO; x509: PX509): Integer; cdecl;
    TPKCS7_set_recipient_info = function(p7: PPKCS7; x509: PX509): PKCS7_RECIP_INFO; cdecl;
    TPKCS7_add_recipient = function(p7: PPKCS7; x509: PX509): PKCS7_RECIP_INFO; cdecl;
    TPKCS7_add_recipient_info = function(p7: PPKCS7; ri: PKCS7_RECIP_INFO): Integer; cdecl;

    // PKCS12 函数类型
    // PKCS12 创建和释放
    TPKCS12_new = function(): PPKCS12; cdecl;
    TPKCS12_free = procedure(a: PPKCS12); cdecl;
    Td2i_PKCS12 = function(a: PPPKCS12; const pp: PPByte; length: Integer): PPKCS12; cdecl;
    Ti2d_PKCS12 = function(a: PPKCS12; out_: PPByte): Integer; cdecl;
    Td2i_PKCS12_bio = function(bp: PBIO; p12: PPPKCS12): PPKCS12; cdecl;
    Ti2d_PKCS12_bio = function(bp: PBIO; p12: PPKCS12): Integer; cdecl;

    // PKCS12 创建
    TPKCS12_create = function(const pass: PAnsiChar; const name: PAnsiChar; pkey: PEVP_PKEY; 
      cert: PX509; ca: PSTACK_OF_X509; nid_key, nid_cert, iter, mac_iter, keytype: Integer): PPKCS12; cdecl;
    TPKCS12_add_cert = function(pbags: PPSTACK_OF_PKCS12_SAFEBAG; cert: PX509): PKCS12_SAFEBAG; cdecl;
    TPKCS12_add_key = function(pbags: PPSTACK_OF_PKCS12_SAFEBAG; key: PEVP_PKEY; 
      key_usage: Integer; iter: Integer; nid_key: Integer; const pass: PAnsiChar): PKCS12_SAFEBAG; cdecl;
    TPKCS12_add_secret = function(pbags: PPSTACK_OF_PKCS12_SAFEBAG; nid_type: Integer; 
      const value: PByte; len: Integer): Integer; cdecl;

    // PKCS12 解析
    TPKCS12_parse = function(p12: PPKCS12; const pass: PAnsiChar; pkey: PPEVP_PKEY; 
      cert: PPX509; ca: PPSTACK_OF_X509): Integer; cdecl;
    TPKCS12_verify_mac = function(p12: PPKCS12; const pass: PAnsiChar; passlen: Integer): Integer; cdecl;
    TPKCS12_set_mac = function(p12: PPKCS12; const pass: PAnsiChar; passlen: Integer; 
      salt: PByte; saltlen: Integer; iter: Integer; const md_type: PEVP_MD): Integer; cdecl;
    TPKCS12_setup_mac = function(p12: PPKCS12; iter: Integer; salt: PByte; 
      saltlen: Integer; const md_type: PEVP_MD): Integer; cdecl;

    // PKCS12 密钥派生
    TPKCS12_key_gen_asc = function(const pass: PAnsiChar; passlen: Integer; salt: PByte; 
      saltlen: Integer; id: Integer; iter: Integer; n: Integer; out_: PByte; 
      const md_type: PEVP_MD): Integer; cdecl;
    TPKCS12_key_gen_uni = function(pass: PByte; passlen: Integer; salt: PByte; 
      saltlen: Integer; id: Integer; iter: Integer; n: Integer; out_: PByte; 
      const md_type: PEVP_MD): Integer; cdecl;
    TPKCS12_key_gen_utf8 = function(const pass: PAnsiChar; passlen: Integer; salt: PByte; 
      saltlen: Integer; id: Integer; iter: Integer; n: Integer; out_: PByte; 
      const md_type: PEVP_MD): Integer; cdecl;
    TPKCS12_key_gen_utf8_ex = function(const pass: PAnsiChar; passlen: Integer; salt: PByte; 
      saltlen: Integer; id: Integer; iter: Integer; n: Integer; out_: PByte; 
      const md_type: PEVP_MD; ctx: POPENSSL_CTX; const propq: PAnsiChar): Integer; cdecl;
    TPKCS12_gen_mac = function(p12: PPKCS12; const pass: PAnsiChar; passlen: Integer; 
      mac: PByte; maclen: PCardinal): Integer; cdecl;

    // PKCS12 PBE
    TPKCS12_PBE_keyivgen = function(ctx: PEVP_CIPHER_CTX; const pass: PAnsiChar; 
      passlen: Integer; param: ASN1_TYPE; const cipher: PEVP_CIPHER; 
      const md: PEVP_MD; en_de: Integer): Integer; cdecl;
    TPKCS12_pbe_crypt = function(const algor: PX509_ALGOR; const pass: PAnsiChar; 
      passlen: Integer; const in_: PByte; inlen: Integer; data: PPByte; 
      datalen: PInteger; en_de: Integer): Integer; cdecl;
    TPKCS12_crypt = function(const pass: PAnsiChar; passlen: Integer; salt: PByte; 
      saltlen: Integer; iter: Integer; const cipher: PEVP_CIPHER; 
      const in_: PByte; inlen: Integer; out_: PPByte; outlen: PInteger; 
      en_de: Integer): Integer; cdecl;
    TPKCS12_decrypt_skey = function(const bag: PKCS12_SAFEBAG; const pass: PAnsiChar; 
      passlen: Integer): PPKCS8_PRIV_KEY_INFO; cdecl;

    // PKCS12 SafeBag
    TPKCS12_SAFEBAG_new = function(): PKCS12_SAFEBAG; cdecl;
    TPKCS12_SAFEBAG_free = procedure(a: PKCS12_SAFEBAG); cdecl;
    TPKCS12_SAFEBAG_get_nid = function(const bag: PKCS12_SAFEBAG): Integer; cdecl;
    TPKCS12_SAFEBAG_get_bag_nid = function(const bag: PKCS12_SAFEBAG): Integer; cdecl;
    TPKCS12_SAFEBAG_get0_bag_type = function(const bag: PKCS12_SAFEBAG): ASN1_TYPE; cdecl;
    TPKCS12_SAFEBAG_get0_bag_obj = function(const bag: PKCS12_SAFEBAG): ASN1_TYPE; cdecl;
    TPKCS12_SAFEBAG_get0_attrs = function(const bag: PKCS12_SAFEBAG): PSTACK_OF_X509_ATTRIBUTE; cdecl;
    TPKCS12_SAFEBAG_set0_attrs = procedure(bag: PKCS12_SAFEBAG; attrs: PSTACK_OF_X509_ATTRIBUTE); cdecl;
    TPKCS12_SAFEBAG_get0_pkcs8 = function(const bag: PKCS12_SAFEBAG): PPKCS8_PRIV_KEY_INFO; cdecl;
    TPKCS12_SAFEBAG_get0_safes = function(const bag: PKCS12_SAFEBAG): PSTACK_OF_PKCS12_SAFEBAG; cdecl;

    // PKCS8 函数
    TPKCS8_PRIV_KEY_INFO_new = function(): PPKCS8_PRIV_KEY_INFO; cdecl;
    TPKCS8_PRIV_KEY_INFO_free = procedure(a: PPKCS8_PRIV_KEY_INFO); cdecl;
    Td2i_PKCS8_PRIV_KEY_INFO = function(a: PPPKCS8_PRIV_KEY_INFO; const pp: PPByte; 
      length: Integer): PPKCS8_PRIV_KEY_INFO; cdecl;
    Ti2d_PKCS8_PRIV_KEY_INFO = function(a: PPKCS8_PRIV_KEY_INFO; out_: PPByte): Integer; cdecl;
    TPKCS8_pkey_set0 = function(priv: PPKCS8_PRIV_KEY_INFO; aobj: ASN1_OBJECT; version: Integer; 
      ptype: Integer; pval: Pointer; penc: PByte; penclen: Integer): Integer; cdecl;
    TPKCS8_pkey_get0 = function(const ppkalg: PPASN1_OBJECT; const pk: PPByte; ppklen: PInteger; 
      const pa: PPX509_ALGOR; const p8: PPKCS8_PRIV_KEY_INFO): Integer; cdecl;
    TPKCS8_pkey_add1_attr_by_NID = function(p8: PPKCS8_PRIV_KEY_INFO; nid: Integer; atype: Integer; 
      const bytes: PByte; len: Integer): Integer; cdecl;

    // EVP_PKEY 转换
    TEVP_PKCS82PKEY = function(const p8: PPKCS8_PRIV_KEY_INFO): PEVP_PKEY; cdecl;
    TEVP_PKEY2PKCS8 = function(pkey: PEVP_PKEY): PPKCS8_PRIV_KEY_INFO; cdecl;

    // X509_SIG 函数
    TX509_SIG_new = function(): PX509_SIG; cdecl;
    TX509_SIG_free = procedure(a: PX509_SIG); cdecl;
    Td2i_X509_SIG = function(a: PPX509_SIG; const pp: PPByte; length: Integer): PX509_SIG; cdecl;
    Ti2d_X509_SIG = function(a: PX509_SIG; out_: PPByte): Integer; cdecl;
    TX509_SIG_get0 = procedure(const sig: PX509_SIG; const palg: PPX509_ALGOR; 
      const pdigest: PPASN1_OCTET_STRING); cdecl;
    TX509_SIG_getm = procedure(sig: PX509_SIG; palg: PPX509_ALGOR; 
      pdigest: PPASN1_OCTET_STRING); cdecl;

var
  // PKCS7 函数
  PKCS7_new: TPKCS7_new = nil;
  PKCS7_free: TPKCS7_free = nil;
  PKCS7_dup: TPKCS7_dup = nil;
  d2i_PKCS7: Td2i_PKCS7 = nil;
  i2d_PKCS7: Ti2d_PKCS7 = nil;
  d2i_PKCS7_bio: Td2i_PKCS7_bio = nil;
  i2d_PKCS7_bio: Ti2d_PKCS7_bio = nil;
  PKCS7_bio_add_digest: TPKCS7_bio_add_digest = nil;

  // PKCS7 签名操作
  PKCS7_sign: TPKCS7_sign = nil;
  PKCS7_sign_add_signer: TPKCS7_sign_add_signer = nil;
  PKCS7_final: TPKCS7_final = nil;
  PKCS7_verify: TPKCS7_verify = nil;
  PKCS7_get0_signers: TPKCS7_get0_signers = nil;

  // PKCS7 加密操作
  PKCS7_encrypt_func: TPKCS7_encrypt = nil;
  PKCS7_decrypt_func: TPKCS7_decrypt = nil;

  // PKCS7 属性操作
  PKCS7_add_certificate: TPKCS7_add_certificate = nil;
  PKCS7_add_crl: TPKCS7_add_crl = nil;
  PKCS7_content_new: TPKCS7_content_new = nil;
  PKCS7_set_type: TPKCS7_set_type = nil;
  PKCS7_set_content: TPKCS7_set_content = nil;
  PKCS7_set_cipher: TPKCS7_set_cipher = nil;
  PKCS7_stream_func: TPKCS7_stream = nil;

  // PKCS7 数据访问
  PKCS7_get_signer_info: TPKCS7_get_signer_info = nil;
  PKCS7_dataInit: TPKCS7_dataInit = nil;
  PKCS7_dataFinal: TPKCS7_dataFinal = nil;
  PKCS7_dataDecode: TPKCS7_dataDecode = nil;
  PKCS7_dataVerify: TPKCS7_dataVerify = nil;

  // PKCS7 签名信息
  PKCS7_SIGNER_INFO_new: TPKCS7_SIGNER_INFO_new = nil;
  PKCS7_SIGNER_INFO_free: TPKCS7_SIGNER_INFO_free = nil;
  PKCS7_SIGNER_INFO_set: TPKCS7_SIGNER_INFO_set = nil;
  PKCS7_SIGNER_INFO_sign: TPKCS7_SIGNER_INFO_sign = nil;
  PKCS7_add_signature: TPKCS7_add_signature = nil;
  PKCS7_set_signed_attributes: TPKCS7_set_signed_attributes = nil;
  PKCS7_set_attributes: TPKCS7_set_attributes = nil;
  PKCS7_get_signed_attributes: TPKCS7_get_signed_attributes = nil;
  PKCS7_get_attributes: TPKCS7_get_attributes = nil;

  // PKCS7 接收者信息
  PKCS7_RECIP_INFO_new: TPKCS7_RECIP_INFO_new = nil;
  PKCS7_RECIP_INFO_free: TPKCS7_RECIP_INFO_free = nil;
  PKCS7_RECIP_INFO_set: TPKCS7_RECIP_INFO_set = nil;
  PKCS7_set_recipient_info: TPKCS7_set_recipient_info = nil;
  PKCS7_add_recipient: TPKCS7_add_recipient = nil;
  PKCS7_add_recipient_info: TPKCS7_add_recipient_info = nil;

  // PKCS12 函数
  PKCS12_new: TPKCS12_new = nil;
  PKCS12_free: TPKCS12_free = nil;
  d2i_PKCS12: Td2i_PKCS12 = nil;
  i2d_PKCS12: Ti2d_PKCS12 = nil;
  d2i_PKCS12_bio: Td2i_PKCS12_bio = nil;
  i2d_PKCS12_bio: Ti2d_PKCS12_bio = nil;

  // PKCS12 创建
  PKCS12_create: TPKCS12_create = nil;
  PKCS12_add_cert: TPKCS12_add_cert = nil;
  PKCS12_add_key: TPKCS12_add_key = nil;
  PKCS12_add_secret: TPKCS12_add_secret = nil;

  // PKCS12 解析
  PKCS12_parse: TPKCS12_parse = nil;
  PKCS12_verify_mac: TPKCS12_verify_mac = nil;
  PKCS12_set_mac: TPKCS12_set_mac = nil;
  PKCS12_setup_mac: TPKCS12_setup_mac = nil;

  // PKCS12 密钥派生
  PKCS12_key_gen_asc: TPKCS12_key_gen_asc = nil;
  PKCS12_key_gen_uni: TPKCS12_key_gen_uni = nil;
  PKCS12_key_gen_utf8: TPKCS12_key_gen_utf8 = nil;
  PKCS12_key_gen_utf8_ex: TPKCS12_key_gen_utf8_ex = nil;
  PKCS12_gen_mac: TPKCS12_gen_mac = nil;

  // PKCS12 PBE
  PKCS12_PBE_keyivgen: TPKCS12_PBE_keyivgen = nil;
  PKCS12_pbe_crypt: TPKCS12_pbe_crypt = nil;
  PKCS12_crypt: TPKCS12_crypt = nil;
  PKCS12_decrypt_skey: TPKCS12_decrypt_skey = nil;

  // PKCS12 SafeBag
  PKCS12_SAFEBAG_new: TPKCS12_SAFEBAG_new = nil;
  PKCS12_SAFEBAG_free: TPKCS12_SAFEBAG_free = nil;
  PKCS12_SAFEBAG_get_nid: TPKCS12_SAFEBAG_get_nid = nil;
  PKCS12_SAFEBAG_get_bag_nid: TPKCS12_SAFEBAG_get_bag_nid = nil;
  PKCS12_SAFEBAG_get0_bag_type: TPKCS12_SAFEBAG_get0_bag_type = nil;
  PKCS12_SAFEBAG_get0_bag_obj: TPKCS12_SAFEBAG_get0_bag_obj = nil;
  PKCS12_SAFEBAG_get0_attrs: TPKCS12_SAFEBAG_get0_attrs = nil;
  PKCS12_SAFEBAG_set0_attrs: TPKCS12_SAFEBAG_set0_attrs = nil;
  PKCS12_SAFEBAG_get0_pkcs8: TPKCS12_SAFEBAG_get0_pkcs8 = nil;
  PKCS12_SAFEBAG_get0_safes: TPKCS12_SAFEBAG_get0_safes = nil;

  // PKCS8 函数
  PKCS8_PRIV_KEY_INFO_new: TPKCS8_PRIV_KEY_INFO_new = nil;
  PKCS8_PRIV_KEY_INFO_free: TPKCS8_PRIV_KEY_INFO_free = nil;
  d2i_PKCS8_PRIV_KEY_INFO: Td2i_PKCS8_PRIV_KEY_INFO = nil;
  i2d_PKCS8_PRIV_KEY_INFO: Ti2d_PKCS8_PRIV_KEY_INFO = nil;
  PKCS8_pkey_set0: TPKCS8_pkey_set0 = nil;
  PKCS8_pkey_get0: TPKCS8_pkey_get0 = nil;
  PKCS8_pkey_add1_attr_by_NID: TPKCS8_pkey_add1_attr_by_NID = nil;

  // EVP_PKEY 转换
  EVP_PKCS82PKEY: TEVP_PKCS82PKEY = nil;
  EVP_PKEY2PKCS8: TEVP_PKEY2PKCS8 = nil;

  // X509_SIG 函数
  X509_SIG_new: TX509_SIG_new = nil;
  X509_SIG_free: TX509_SIG_free = nil;
  d2i_X509_SIG: Td2i_X509_SIG = nil;
  i2d_X509_SIG: Ti2d_X509_SIG = nil;
  X509_SIG_get0: TX509_SIG_get0 = nil;
  X509_SIG_getm: TX509_SIG_getm = nil;

// 加载和卸载函数
function LoadOpenSSLPKCS(const ACryptoLib: THandle): Boolean;
procedure UnloadOpenSSLPKCS;

// 辅助函数
function LoadPKCS12FromFile(const AFileName: string; const APassword: string; 
  out AKey: PEVP_PKEY; out ACert: PX509; out ACAs: PSTACK_OF_X509): Boolean;
function SavePKCS12ToFile(const AFileName: string; const APassword: string; 
  AKey: PEVP_PKEY; ACert: PX509; ACAs: PSTACK_OF_X509): Boolean;
function CreatePKCS7SignedData(AData: TBytes; ACert: PX509; AKey: PEVP_PKEY; 
  AFlags: Integer = PKCS7_DETACHED): PPKCS7;
function VerifyPKCS7SignedData(AData: TBytes; ASignature: PPKCS7; 
  AStore: PX509_STORE; AFlags: Integer = 0): Boolean;

implementation

const
  { PKCS 函数绑定数组 - 用于批量加载 }
  PKCSBindings: array[0..89] of TFunctionBinding = (
    // PKCS7 基本函数
    (Name: 'PKCS7_new'; FuncPtr: @PKCS7_new; Required: True),
    (Name: 'PKCS7_free'; FuncPtr: @PKCS7_free; Required: True),
    (Name: 'PKCS7_dup'; FuncPtr: @PKCS7_dup; Required: False),
    (Name: 'd2i_PKCS7'; FuncPtr: @d2i_PKCS7; Required: False),
    (Name: 'i2d_PKCS7'; FuncPtr: @i2d_PKCS7; Required: False),
    (Name: 'd2i_PKCS7_bio'; FuncPtr: @d2i_PKCS7_bio; Required: False),
    (Name: 'i2d_PKCS7_bio'; FuncPtr: @i2d_PKCS7_bio; Required: False),
    (Name: 'PKCS7_bio_add_digest'; FuncPtr: @PKCS7_bio_add_digest; Required: False),
    // PKCS7 签名操作
    (Name: 'PKCS7_sign'; FuncPtr: @PKCS7_sign; Required: False),
    (Name: 'PKCS7_sign_add_signer'; FuncPtr: @PKCS7_sign_add_signer; Required: False),
    (Name: 'PKCS7_final'; FuncPtr: @PKCS7_final; Required: False),
    (Name: 'PKCS7_verify'; FuncPtr: @PKCS7_verify; Required: False),
    (Name: 'PKCS7_get0_signers'; FuncPtr: @PKCS7_get0_signers; Required: False),
    // PKCS7 加密操作
    (Name: 'PKCS7_encrypt'; FuncPtr: @PKCS7_encrypt_func; Required: False),
    (Name: 'PKCS7_decrypt'; FuncPtr: @PKCS7_decrypt_func; Required: False),
    // PKCS7 属性操作
    (Name: 'PKCS7_add_certificate'; FuncPtr: @PKCS7_add_certificate; Required: False),
    (Name: 'PKCS7_add_crl'; FuncPtr: @PKCS7_add_crl; Required: False),
    (Name: 'PKCS7_content_new'; FuncPtr: @PKCS7_content_new; Required: False),
    (Name: 'PKCS7_set_type'; FuncPtr: @PKCS7_set_type; Required: False),
    (Name: 'PKCS7_set_content'; FuncPtr: @PKCS7_set_content; Required: False),
    (Name: 'PKCS7_set_cipher'; FuncPtr: @PKCS7_set_cipher; Required: False),
    (Name: 'PKCS7_stream'; FuncPtr: @PKCS7_stream_func; Required: False),
    // PKCS7 数据访问
    (Name: 'PKCS7_get_signer_info'; FuncPtr: @PKCS7_get_signer_info; Required: False),
    (Name: 'PKCS7_dataInit'; FuncPtr: @PKCS7_dataInit; Required: False),
    (Name: 'PKCS7_dataFinal'; FuncPtr: @PKCS7_dataFinal; Required: False),
    (Name: 'PKCS7_dataDecode'; FuncPtr: @PKCS7_dataDecode; Required: False),
    (Name: 'PKCS7_dataVerify'; FuncPtr: @PKCS7_dataVerify; Required: False),
    // PKCS7 签名信息
    (Name: 'PKCS7_SIGNER_INFO_new'; FuncPtr: @PKCS7_SIGNER_INFO_new; Required: False),
    (Name: 'PKCS7_SIGNER_INFO_free'; FuncPtr: @PKCS7_SIGNER_INFO_free; Required: False),
    (Name: 'PKCS7_SIGNER_INFO_set'; FuncPtr: @PKCS7_SIGNER_INFO_set; Required: False),
    (Name: 'PKCS7_SIGNER_INFO_sign'; FuncPtr: @PKCS7_SIGNER_INFO_sign; Required: False),
    (Name: 'PKCS7_add_signature'; FuncPtr: @PKCS7_add_signature; Required: False),
    (Name: 'PKCS7_set_signed_attributes'; FuncPtr: @PKCS7_set_signed_attributes; Required: False),
    (Name: 'PKCS7_set_attributes'; FuncPtr: @PKCS7_set_attributes; Required: False),
    (Name: 'PKCS7_get_signed_attributes'; FuncPtr: @PKCS7_get_signed_attributes; Required: False),
    (Name: 'PKCS7_get_attributes'; FuncPtr: @PKCS7_get_attributes; Required: False),
    // PKCS7 接收者信息
    (Name: 'PKCS7_RECIP_INFO_new'; FuncPtr: @PKCS7_RECIP_INFO_new; Required: False),
    (Name: 'PKCS7_RECIP_INFO_free'; FuncPtr: @PKCS7_RECIP_INFO_free; Required: False),
    (Name: 'PKCS7_RECIP_INFO_set'; FuncPtr: @PKCS7_RECIP_INFO_set; Required: False),
    (Name: 'PKCS7_set_recipient_info'; FuncPtr: @PKCS7_set_recipient_info; Required: False),
    (Name: 'PKCS7_add_recipient'; FuncPtr: @PKCS7_add_recipient; Required: False),
    (Name: 'PKCS7_add_recipient_info'; FuncPtr: @PKCS7_add_recipient_info; Required: False),
    // PKCS12 基本函数
    (Name: 'PKCS12_new'; FuncPtr: @PKCS12_new; Required: True),
    (Name: 'PKCS12_free'; FuncPtr: @PKCS12_free; Required: True),
    (Name: 'd2i_PKCS12'; FuncPtr: @d2i_PKCS12; Required: False),
    (Name: 'i2d_PKCS12'; FuncPtr: @i2d_PKCS12; Required: False),
    (Name: 'd2i_PKCS12_bio'; FuncPtr: @d2i_PKCS12_bio; Required: False),
    (Name: 'i2d_PKCS12_bio'; FuncPtr: @i2d_PKCS12_bio; Required: False),
    // PKCS12 创建
    (Name: 'PKCS12_create'; FuncPtr: @PKCS12_create; Required: False),
    (Name: 'PKCS12_add_cert'; FuncPtr: @PKCS12_add_cert; Required: False),
    (Name: 'PKCS12_add_key'; FuncPtr: @PKCS12_add_key; Required: False),
    (Name: 'PKCS12_add_secret'; FuncPtr: @PKCS12_add_secret; Required: False),
    // PKCS12 解析
    (Name: 'PKCS12_parse'; FuncPtr: @PKCS12_parse; Required: False),
    (Name: 'PKCS12_verify_mac'; FuncPtr: @PKCS12_verify_mac; Required: False),
    (Name: 'PKCS12_set_mac'; FuncPtr: @PKCS12_set_mac; Required: False),
    (Name: 'PKCS12_setup_mac'; FuncPtr: @PKCS12_setup_mac; Required: False),
    // PKCS12 密钥派生
    (Name: 'PKCS12_key_gen_asc'; FuncPtr: @PKCS12_key_gen_asc; Required: False),
    (Name: 'PKCS12_key_gen_uni'; FuncPtr: @PKCS12_key_gen_uni; Required: False),
    (Name: 'PKCS12_key_gen_utf8'; FuncPtr: @PKCS12_key_gen_utf8; Required: False),
    (Name: 'PKCS12_key_gen_utf8_ex'; FuncPtr: @PKCS12_key_gen_utf8_ex; Required: False),
    (Name: 'PKCS12_gen_mac'; FuncPtr: @PKCS12_gen_mac; Required: False),
    // PKCS12 PBE
    (Name: 'PKCS12_PBE_keyivgen'; FuncPtr: @PKCS12_PBE_keyivgen; Required: False),
    (Name: 'PKCS12_pbe_crypt'; FuncPtr: @PKCS12_pbe_crypt; Required: False),
    (Name: 'PKCS12_crypt'; FuncPtr: @PKCS12_crypt; Required: False),
    (Name: 'PKCS12_decrypt_skey'; FuncPtr: @PKCS12_decrypt_skey; Required: False),
    // PKCS12 SafeBag
    (Name: 'PKCS12_SAFEBAG_new'; FuncPtr: @PKCS12_SAFEBAG_new; Required: False),
    (Name: 'PKCS12_SAFEBAG_free'; FuncPtr: @PKCS12_SAFEBAG_free; Required: False),
    (Name: 'PKCS12_SAFEBAG_get_nid'; FuncPtr: @PKCS12_SAFEBAG_get_nid; Required: False),
    (Name: 'PKCS12_SAFEBAG_get_bag_nid'; FuncPtr: @PKCS12_SAFEBAG_get_bag_nid; Required: False),
    (Name: 'PKCS12_SAFEBAG_get0_bag_type'; FuncPtr: @PKCS12_SAFEBAG_get0_bag_type; Required: False),
    (Name: 'PKCS12_SAFEBAG_get0_bag_obj'; FuncPtr: @PKCS12_SAFEBAG_get0_bag_obj; Required: False),
    (Name: 'PKCS12_SAFEBAG_get0_attrs'; FuncPtr: @PKCS12_SAFEBAG_get0_attrs; Required: False),
    (Name: 'PKCS12_SAFEBAG_set0_attrs'; FuncPtr: @PKCS12_SAFEBAG_set0_attrs; Required: False),
    (Name: 'PKCS12_SAFEBAG_get0_pkcs8'; FuncPtr: @PKCS12_SAFEBAG_get0_pkcs8; Required: False),
    (Name: 'PKCS12_SAFEBAG_get0_safes'; FuncPtr: @PKCS12_SAFEBAG_get0_safes; Required: False),
    // PKCS8 函数
    (Name: 'PKCS8_PRIV_KEY_INFO_new'; FuncPtr: @PKCS8_PRIV_KEY_INFO_new; Required: False),
    (Name: 'PKCS8_PRIV_KEY_INFO_free'; FuncPtr: @PKCS8_PRIV_KEY_INFO_free; Required: False),
    (Name: 'd2i_PKCS8_PRIV_KEY_INFO'; FuncPtr: @d2i_PKCS8_PRIV_KEY_INFO; Required: False),
    (Name: 'i2d_PKCS8_PRIV_KEY_INFO'; FuncPtr: @i2d_PKCS8_PRIV_KEY_INFO; Required: False),
    (Name: 'PKCS8_pkey_set0'; FuncPtr: @PKCS8_pkey_set0; Required: False),
    (Name: 'PKCS8_pkey_get0'; FuncPtr: @PKCS8_pkey_get0; Required: False),
    (Name: 'PKCS8_pkey_add1_attr_by_NID'; FuncPtr: @PKCS8_pkey_add1_attr_by_NID; Required: False),
    // EVP_PKEY 转换
    (Name: 'EVP_PKCS82PKEY'; FuncPtr: @EVP_PKCS82PKEY; Required: False),
    (Name: 'EVP_PKEY2PKCS8'; FuncPtr: @EVP_PKEY2PKCS8; Required: False),
    // X509_SIG 函数
    (Name: 'X509_SIG_new'; FuncPtr: @X509_SIG_new; Required: False),
    (Name: 'X509_SIG_free'; FuncPtr: @X509_SIG_free; Required: False),
    (Name: 'd2i_X509_SIG'; FuncPtr: @d2i_X509_SIG; Required: False),
    (Name: 'i2d_X509_SIG'; FuncPtr: @i2d_X509_SIG; Required: False),
    (Name: 'X509_SIG_get0'; FuncPtr: @X509_SIG_get0; Required: False),
    (Name: 'X509_SIG_getm'; FuncPtr: @X509_SIG_getm; Required: False)
  );

function LoadOpenSSLPKCS(const ACryptoLib: THandle): Boolean;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmPKCS) then
    Exit(True);

  if ACryptoLib = 0 then
    Exit(False);

  // 使用批量加载模式
  TOpenSSLLoader.LoadFunctions(ACryptoLib, PKCSBindings);

  TOpenSSLLoader.SetModuleLoaded(osmPKCS, Assigned(PKCS7_new) and Assigned(PKCS12_new));
  Result := TOpenSSLLoader.IsModuleLoaded(osmPKCS);
end;

procedure UnloadOpenSSLPKCS;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmPKCS) then
    Exit;

  // 使用批量清理模式
  TOpenSSLLoader.ClearFunctions(PKCSBindings);

  TOpenSSLLoader.SetModuleLoaded(osmPKCS, False);
end;

// 辅助函数实现
function LoadPKCS12FromFile(const AFileName: string; const APassword: string; 
  out AKey: PEVP_PKEY; out ACert: PX509; out ACAs: PSTACK_OF_X509): Boolean;
var
  Bio: PBIO;
  P12: PPKCS12;
begin
  Result := False;
  AKey := nil;
  ACert := nil;
  ACAs := nil;

  if not TOpenSSLLoader.IsModuleLoaded(osmPKCS) or
    not nextpas.core.fs.IsFile(AFileName) or
    not Assigned(BIO_new_file) or
    not Assigned(d2i_PKCS12_bio) or
    not Assigned(PKCS12_parse) or
    not Assigned(BIO_free) then
    Exit;

  Bio := BIO_new_file(PAnsiChar(AnsiString(AFileName)), 'rb');
  if Bio = nil then
    Exit;

  try
    P12 := d2i_PKCS12_bio(Bio, nil);
    if P12 <> nil then
    begin
      try
        Result := PKCS12_parse(P12, PAnsiChar(AnsiString(APassword)), 
          @AKey, @ACert, @ACAs) = 1;
      finally
        PKCS12_free(P12);
      end;
    end;
  finally
    BIO_free(Bio);
  end;
end;

function SavePKCS12ToFile(const AFileName: string; const APassword: string; 
  AKey: PEVP_PKEY; ACert: PX509; ACAs: PSTACK_OF_X509): Boolean;
var
  Bio: PBIO;
  P12: PPKCS12;
begin
  Result := False;
  if not TOpenSSLLoader.IsModuleLoaded(osmPKCS) or
    (AKey = nil) or
    (ACert = nil) or
    not Assigned(BIO_new_file) or
    not Assigned(PKCS12_create) or
    not Assigned(i2d_PKCS12_bio) or
    not Assigned(BIO_free) then
    Exit;

  P12 := PKCS12_create(PAnsiChar(AnsiString(APassword)), nil, AKey, ACert, ACAs, 
    0, 0, 0, 0, 0);
  if P12 = nil then
    Exit;

  try
    Bio := BIO_new_file(PAnsiChar(AnsiString(AFileName)), 'wb');
    if Bio <> nil then
    begin
      try
        Result := i2d_PKCS12_bio(Bio, P12) = 1;
      finally
        BIO_free(Bio);
      end;
    end;
  finally
    PKCS12_free(P12);
  end;
end;

function CreatePKCS7SignedData(AData: TBytes; ACert: PX509; AKey: PEVP_PKEY; 
  AFlags: Integer): PPKCS7;
var
  Bio: PBIO;
begin
  Result := nil;
  if not TOpenSSLLoader.IsModuleLoaded(osmPKCS) or
    (Length(AData) = 0) or
    (ACert = nil) or
    (AKey = nil) or
    not Assigned(BIO_new_mem_buf) or
    not Assigned(PKCS7_sign) or
    not Assigned(BIO_free) then
    Exit;

  Bio := BIO_new_mem_buf(@AData[0], Length(AData));
  if Bio = nil then
    Exit;

  try
    Result := PKCS7_sign(ACert, AKey, nil, Bio, AFlags);
  finally
    BIO_free(Bio);
  end;
end;

function VerifyPKCS7SignedData(AData: TBytes; ASignature: PPKCS7; 
  AStore: PX509_STORE; AFlags: Integer): Boolean;
var
  DataBio, OutBio: PBIO;
begin
  Result := False;
  if not TOpenSSLLoader.IsModuleLoaded(osmPKCS) or
    (Length(AData) = 0) or
    (ASignature = nil) or
    not Assigned(BIO_new_mem_buf) or
    not Assigned(BIO_new) or
    not Assigned(BIO_s_null) or
    not Assigned(PKCS7_verify) or
    not Assigned(BIO_free) then
    Exit;

  DataBio := BIO_new_mem_buf(@AData[0], Length(AData));
  if DataBio = nil then
    Exit;

  OutBio := BIO_new(BIO_s_null());
  try
    Result := PKCS7_verify(ASignature, nil, AStore, DataBio, OutBio, AFlags) = 1;
  finally
    BIO_free(DataBio);
    BIO_free(OutBio);
  end;
end;

end.
