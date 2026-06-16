unit nextpas.core.tls.openssl.api.cms;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.base,
   Classes, dynlibs,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.evp;

type
  // CMS 类型定义
  CMS_ContentInfo = Pointer;
  PCMS_ContentInfo = ^CMS_ContentInfo;
  PPCMS_ContentInfo = ^PCMS_ContentInfo;
  
  CMS_SignerInfo = Pointer;
  PCMS_SignerInfo = ^CMS_SignerInfo;
  
  CMS_RecipientInfo = Pointer;
  PCMS_RecipientInfo = ^CMS_RecipientInfo;
  
  CMS_RevocationInfoChoice = Pointer;
  PCMS_RevocationInfoChoice = ^CMS_RevocationInfoChoice;
  
  CMS_ReceiptRequest = Pointer;
  PCMS_ReceiptRequest = ^CMS_ReceiptRequest;
  PPCMS_ReceiptRequest = ^PCMS_ReceiptRequest;
  
  CMS_Receipt = Pointer;
  PCMS_Receipt = ^CMS_Receipt;
  PPCMS_Receipt = ^PCMS_Receipt;
  
  CMS_RecipientEncryptedKey = Pointer;
  PCMS_RecipientEncryptedKey = ^CMS_RecipientEncryptedKey;
  
  CMS_OtherKeyAttribute = Pointer;
  PCMS_OtherKeyAttribute = ^CMS_OtherKeyAttribute;
  
  // Additional pointer types
  PX509_ATTRIBUTE = Pointer;
  PPASN1_GENERALIZEDTIME = ^PASN1_GENERALIZEDTIME;

  // CMS 内容类型
  const
    CMS_RECIPINFO_NONE            = -1;
    CMS_RECIPINFO_TRANS           = 0;
    CMS_RECIPINFO_AGREE           = 1;
    CMS_RECIPINFO_KEK             = 2;
    CMS_RECIPINFO_PASS            = 3;
    CMS_RECIPINFO_OTHER           = 4;

    // CMS 标志
    CMS_TEXT                      = $1;
    CMS_NOCERTS                   = $2;
    CMS_NO_CONTENT_VERIFY         = $4;
    CMS_NO_ATTR_VERIFY            = $8;
    CMS_NOSIGS                    = $4;  // 与 CMS_NO_CONTENT_VERIFY 相同
    CMS_NOINTERN                  = $10;
    CMS_NO_SIGNER_CERT_VERIFY     = $20;
    CMS_NOVERIFY                  = $20;  // 与 CMS_NO_SIGNER_CERT_VERIFY 相同
    CMS_DETACHED                  = $40;
    CMS_BINARY                    = $80;
    CMS_NOATTR                    = $100;
    CMS_NOSMIMECAP                = $200;
    CMS_NOOLDMIMETYPE             = $400;
    CMS_CRLFEOL                   = $800;
    CMS_STREAM                    = $1000;
    CMS_NOCRL                     = $2000;
    CMS_PARTIAL                   = $4000;
    CMS_REUSE_DIGEST              = $8000;
    CMS_USE_KEYID                 = $10000;
    CMS_DEBUG_DECRYPT             = $20000;
    CMS_KEY_PARAM                 = $40000;
    CMS_ASCIICRLF                 = $80000;

  // CMS 函数类型
  type
    // CMS 创建和释放
    TCMS_ContentInfo_new = function(): PCMS_ContentInfo; cdecl;
    TCMS_ContentInfo_free = procedure(a: PCMS_ContentInfo); cdecl;
    Td2i_CMS_ContentInfo = function(a: PPCMS_ContentInfo; const in_: PPByte; len: Integer): PCMS_ContentInfo; cdecl;
    Ti2d_CMS_ContentInfo = function(a: PCMS_ContentInfo; out_: PPByte): Integer; cdecl;
    Td2i_CMS_bio = function(bp: PBIO; cms: PPCMS_ContentInfo): PCMS_ContentInfo; cdecl;
    Ti2d_CMS_bio = function(bp: PBIO; cms: PCMS_ContentInfo): Integer; cdecl;
    Ti2d_CMS_bio_stream = function(out_: PBIO; cms: PCMS_ContentInfo; in_: PBIO; flags: Integer): Integer; cdecl;
    TCMS_ContentInfo_print_ctx = function(out_: PBIO; cms: PCMS_ContentInfo; indent: Integer; 
      const pctx: ASN1_PCTX): Integer; cdecl;

    // CMS 签名操作
    TCMS_sign = function(signcert: PX509; pkey: PEVP_PKEY; certs: PSTACK_OF_X509; 
      data: PBIO; flags: Cardinal): PCMS_ContentInfo; cdecl;
    TCMS_sign_receipt = function(si: PCMS_SignerInfo; signcert: PX509; pkey: PEVP_PKEY; 
      certs: PSTACK_OF_X509; flags: Cardinal): PCMS_ContentInfo; cdecl;
    TCMS_add1_signer = function(cms: PCMS_ContentInfo; signer: PX509; pk: PEVP_PKEY; 
      const md: PEVP_MD; flags: Cardinal): PCMS_SignerInfo; cdecl;
    TCMS_SignerInfo_sign = function(si: PCMS_SignerInfo): Integer; cdecl;
    TCMS_final = function(cms: PCMS_ContentInfo; data: PBIO; dcont: PBIO; flags: Cardinal): Integer; cdecl;
    TCMS_verify = function(cms: PCMS_ContentInfo; certs: PSTACK_OF_X509; store: PX509_STORE; 
      dcont: PBIO; out_: PBIO; flags: Cardinal): Integer; cdecl;
    TCMS_verify_receipt = function(rcms: PCMS_ContentInfo; ocms: PCMS_ContentInfo; 
      certs: PSTACK_OF_X509; store: PX509_STORE; flags: Cardinal): Integer; cdecl;
    TCMS_get0_signers = function(cms: PCMS_ContentInfo): PSTACK_OF_X509; cdecl;

    // CMS 加密操作
    TCMS_encrypt = function(certs: PSTACK_OF_X509; in_: PBIO; const cipher: PEVP_CIPHER; 
      flags: Cardinal): PCMS_ContentInfo; cdecl;
    TCMS_decrypt = function(cms: PCMS_ContentInfo; pkey: PEVP_PKEY; cert: PX509; 
      dcont: PBIO; out_: PBIO; flags: Cardinal): Integer; cdecl;
    TCMS_decrypt_set1_pkey = function(cms: PCMS_ContentInfo; pk: PEVP_PKEY; cert: PX509): Integer; cdecl;
    TCMS_decrypt_set1_key = function(cms: PCMS_ContentInfo; key: PByte; keylen: Cardinal; 
      const id: PByte; idlen: Cardinal): Integer; cdecl;
    TCMS_decrypt_set1_password = function(cms: PCMS_ContentInfo; pass: PByte; passlen: Integer): Integer; cdecl;

    // CMS RecipientInfo
    TCMS_add0_recipient_key = function(cms: PCMS_ContentInfo; nid: Integer; key: PByte; 
      keylen: Cardinal; id: PByte; idlen: Cardinal; date: ASN1_GENERALIZEDTIME; 
      otherTypeId: ASN1_OBJECT; otherType: ASN1_TYPE): PCMS_RecipientInfo; cdecl;
    TCMS_add0_recipient_password = function(cms: PCMS_ContentInfo; iter: Integer; 
      wrap_nid: Integer; pbe_nid: Integer; pass: PByte; passlen: Integer; 
      const kekciph: PEVP_CIPHER): PCMS_RecipientInfo; cdecl;
    TCMS_add1_recipient_cert = function(cms: PCMS_ContentInfo; recip: PX509; 
      flags: Cardinal): PCMS_RecipientInfo; cdecl;
    TCMS_RecipientInfo_type = function(ri: PCMS_RecipientInfo): Integer; cdecl;
    TCMS_RecipientInfo_ktri_get0_signer_id = function(ri: PCMS_RecipientInfo; keyid: PPASN1_OCTET_STRING; 
      issuer: PPX509_NAME; sno: PPASN1_INTEGER): Integer; cdecl;
    TCMS_RecipientInfo_ktri_cert_cmp = function(ri: PCMS_RecipientInfo; cert: PX509): Integer; cdecl;
    TCMS_RecipientInfo_set0_pkey = function(ri: PCMS_RecipientInfo; pkey: PEVP_PKEY): Integer; cdecl;
    TCMS_RecipientInfo_kekri_get0_id = function(ri: PCMS_RecipientInfo; palg: PPX509_ALGOR; 
      pid: PPASN1_OCTET_STRING; pdate: PPASN1_GENERALIZEDTIME; 
      potherid: PPASN1_OBJECT; pothertype: PPASN1_TYPE): Integer; cdecl;
    TCMS_RecipientInfo_kekri_id_cmp = function(ri: PCMS_RecipientInfo; const id: PByte; 
      idlen: Cardinal): Integer; cdecl;
    TCMS_RecipientInfo_set0_key = function(ri: PCMS_RecipientInfo; key: PByte; keylen: Cardinal): Integer; cdecl;
    TCMS_RecipientInfo_decrypt = function(cms: PCMS_ContentInfo; ri: PCMS_RecipientInfo): Integer; cdecl;
    TCMS_RecipientInfo_encrypt = function(cms: PCMS_ContentInfo; ri: PCMS_RecipientInfo): Integer; cdecl;

    // CMS SignerInfo
    TCMS_get0_SignerInfos = function(cms: PCMS_ContentInfo): POPENSSL_STACK; cdecl;
    TCMS_SignerInfo_get0_signer_id = function(si: PCMS_SignerInfo; keyid: PPASN1_OCTET_STRING; 
      issuer: PPX509_NAME; sno: PPASN1_INTEGER): Integer; cdecl;
    TCMS_SignerInfo_get0_signature = function(si: PCMS_SignerInfo): ASN1_OCTET_STRING; cdecl;
    TCMS_SignerInfo_cert_cmp = function(si: PCMS_SignerInfo; cert: PX509): Integer; cdecl;
    TCMS_set1_signer_cert = function(si: PCMS_SignerInfo; signer: PX509): Integer; cdecl;
    TCMS_SignerInfo_get0_algs = function(si: PCMS_SignerInfo; pk: PPEVP_PKEY; signer: PPX509; 
      pdig: PPX509_ALGOR; psig: PPX509_ALGOR): Integer; cdecl;
    TCMS_SignerInfo_get0_md_ctx = function(si: PCMS_SignerInfo): PEVP_MD_CTX; cdecl;
    TCMS_SignerInfo_verify = function(si: PCMS_SignerInfo): Integer; cdecl;
    TCMS_SignerInfo_verify_content = function(si: PCMS_SignerInfo; chain: PBIO): Integer; cdecl;

    // CMS 属性操作
    TCMS_signed_get_attr_count = function(const si: PCMS_SignerInfo): Integer; cdecl;
    TCMS_signed_get_attr_by_NID = function(const si: PCMS_SignerInfo; nid: Integer; 
      lastpos: Integer): Integer; cdecl;
    TCMS_signed_get_attr_by_OBJ = function(const si: PCMS_SignerInfo; const obj: ASN1_OBJECT; 
      lastpos: Integer): Integer; cdecl;
    TCMS_signed_get_attr = function(const si: PCMS_SignerInfo; loc: Integer): PX509_ATTRIBUTE; cdecl;
    TCMS_signed_delete_attr = function(si: PCMS_SignerInfo; loc: Integer): PX509_ATTRIBUTE; cdecl;
    TCMS_signed_add1_attr = function(si: PCMS_SignerInfo; attr: PX509_ATTRIBUTE): Integer; cdecl;
    TCMS_signed_add1_attr_by_OBJ = function(si: PCMS_SignerInfo; const obj: ASN1_OBJECT; 
      atype: Integer; const data: Pointer; len: Integer): Integer; cdecl;
    TCMS_signed_add1_attr_by_NID = function(si: PCMS_SignerInfo; nid: Integer; atype: Integer; 
      const data: Pointer; len: Integer): Integer; cdecl;
    TCMS_signed_add1_attr_by_txt = function(si: PCMS_SignerInfo; const attrname: PAnsiChar; 
      atype: Integer; const data: Pointer; len: Integer): Integer; cdecl;
    TCMS_signed_get0_data_by_OBJ = function(si: PCMS_SignerInfo; const oid: ASN1_OBJECT; 
      lastpos: Integer; atype: PInteger): Pointer; cdecl;

    // CMS 未签名属性
    TCMS_unsigned_get_attr_count = function(const si: PCMS_SignerInfo): Integer; cdecl;
    TCMS_unsigned_get_attr_by_NID = function(const si: PCMS_SignerInfo; nid: Integer; 
      lastpos: Integer): Integer; cdecl;
    TCMS_unsigned_get_attr_by_OBJ = function(const si: PCMS_SignerInfo; const obj: ASN1_OBJECT; 
      lastpos: Integer): Integer; cdecl;
    TCMS_unsigned_get_attr = function(const si: PCMS_SignerInfo; loc: Integer): PX509_ATTRIBUTE; cdecl;
    TCMS_unsigned_delete_attr = function(si: PCMS_SignerInfo; loc: Integer): PX509_ATTRIBUTE; cdecl;
    TCMS_unsigned_add1_attr = function(si: PCMS_SignerInfo; attr: PX509_ATTRIBUTE): Integer; cdecl;
    TCMS_unsigned_add1_attr_by_OBJ = function(si: PCMS_SignerInfo; const obj: ASN1_OBJECT; 
      atype: Integer; const data: Pointer; len: Integer): Integer; cdecl;
    TCMS_unsigned_add1_attr_by_NID = function(si: PCMS_SignerInfo; nid: Integer; atype: Integer; 
      const data: Pointer; len: Integer): Integer; cdecl;
    TCMS_unsigned_add1_attr_by_txt = function(si: PCMS_SignerInfo; const attrname: PAnsiChar; 
      atype: Integer; const data: Pointer; len: Integer): Integer; cdecl;
    TCMS_unsigned_get0_data_by_OBJ = function(si: PCMS_SignerInfo; oid: ASN1_OBJECT; 
      lastpos: Integer; atype: PInteger): Pointer; cdecl;

    // CMS 实用功能
    TCMS_get0_type = function(const cms: PCMS_ContentInfo): PASN1_OBJECT; cdecl;
    TCMS_set1_eContentType = function(cms: PCMS_ContentInfo; const oid: ASN1_OBJECT): Integer; cdecl;
    TCMS_get0_eContentType = function(cms: PCMS_ContentInfo): PASN1_OBJECT; cdecl;
    TCMS_get0_content = function(cms: PCMS_ContentInfo): PPASN1_OCTET_STRING; cdecl;
    TCMS_is_detached = function(cms: PCMS_ContentInfo): Integer; cdecl;
    TCMS_set_detached = function(cms: PCMS_ContentInfo; detached: Integer): Integer; cdecl;
    TCMS_stream = function(boundary: PPBYTE; cms: PCMS_ContentInfo): Integer; cdecl;
    TCMS_dataInit = function(cms: PCMS_ContentInfo; icont: PBIO): PBIO; cdecl;
    TCMS_dataFinal = function(cms: PCMS_ContentInfo; bio: PBIO): Integer; cdecl;
    TCMS_data = function(cms: PCMS_ContentInfo; out_: PBIO; flags: Cardinal): PCMS_ContentInfo; cdecl;
    TCMS_data_create = function(in_: PBIO; flags: Cardinal): PCMS_ContentInfo; cdecl;
    TCMS_digest_verify = function(cms: PCMS_ContentInfo; dcont: PBIO; out_: PBIO; 
      flags: Cardinal): Integer; cdecl;
    TCMS_digest_create = function(in_: PBIO; const md: PEVP_MD; flags: Cardinal): PCMS_ContentInfo; cdecl;
    TCMS_EncryptedData_decrypt = function(cms: PCMS_ContentInfo; const key: PByte; keylen: Cardinal; 
      dcont: PBIO; out_: PBIO; flags: Cardinal): Integer; cdecl;
    TCMS_EncryptedData_encrypt = function(in_: PBIO; const cipher: PEVP_CIPHER; const key: PByte; 
      keylen: Cardinal; flags: Cardinal): PCMS_ContentInfo; cdecl;
    TCMS_EncryptedData_set1_key = function(cms: PCMS_ContentInfo; const ciph: PEVP_CIPHER; 
      const key: PByte; keylen: Cardinal): Integer; cdecl;

    // CMS 压缩
    TCMS_uncompress = function(cms: PCMS_ContentInfo; dcont: PBIO; out_: PBIO; 
      flags: Cardinal): Integer; cdecl;
    TCMS_compress = function(in_: PBIO; comp_nid: Integer; flags: Cardinal): PCMS_ContentInfo; cdecl;

    // CMS 收据
    TCMS_add1_ReceiptRequest = function(si: PCMS_SignerInfo; rr: PCMS_ReceiptRequest): Integer; cdecl;
    TCMS_get1_ReceiptRequest = function(si: PCMS_SignerInfo; prr: PPCMS_ReceiptRequest): Integer; cdecl;
    TCMS_ReceiptRequest_create0 = function(id: PByte; idlen: Integer; allorfirst: Integer; 
      receiptList: POPENSSL_STACK; receiptsTo: POPENSSL_STACK): PCMS_ReceiptRequest; cdecl;
    TCMS_add1_Receipt = function(si: PCMS_SignerInfo; receipt: PCMS_Receipt): Integer; cdecl;
    TCMS_get1_Receipt = function(si: PCMS_SignerInfo; pr: PPCMS_Receipt): Integer; cdecl;
    TCMS_RecipientInfo_kari_get0_alg = function(ri: PCMS_RecipientInfo; palg: PPX509_ALGOR; 
      pukm: PPASN1_OCTET_STRING): Integer; cdecl;
    TCMS_RecipientInfo_kari_get0_reks = function(ri: PCMS_RecipientInfo): POPENSSL_STACK; cdecl;
    TCMS_RecipientInfo_kari_get0_orig_id = function(ri: PCMS_RecipientInfo; 
      pubalg: PPX509_ALGOR; pubkey: PPASN1_BIT_STRING; keyid: PPASN1_OCTET_STRING; 
      issuer: PPX509_NAME; sno: PPASN1_INTEGER): Integer; cdecl;
    TCMS_RecipientInfo_kari_orig_id_cmp = function(ri: PCMS_RecipientInfo; cert: PX509): Integer; cdecl;

var
  // CMS 创建和释放
  CMS_ContentInfo_new: TCMS_ContentInfo_new = nil;
  CMS_ContentInfo_free: TCMS_ContentInfo_free = nil;
  d2i_CMS_ContentInfo: Td2i_CMS_ContentInfo = nil;
  i2d_CMS_ContentInfo: Ti2d_CMS_ContentInfo = nil;
  d2i_CMS_bio: Td2i_CMS_bio = nil;
  i2d_CMS_bio: Ti2d_CMS_bio = nil;
  i2d_CMS_bio_stream: Ti2d_CMS_bio_stream = nil;
  CMS_ContentInfo_print_ctx: TCMS_ContentInfo_print_ctx = nil;

  // CMS 签名操作
  CMS_sign: TCMS_sign = nil;
  CMS_sign_receipt: TCMS_sign_receipt = nil;
  CMS_add1_signer: TCMS_add1_signer = nil;
  CMS_SignerInfo_sign: TCMS_SignerInfo_sign = nil;
  CMS_final: TCMS_final = nil;
  CMS_verify: TCMS_verify = nil;
  CMS_verify_receipt: TCMS_verify_receipt = nil;
  CMS_get0_signers: TCMS_get0_signers = nil;

  // CMS 加密操作
  CMS_encrypt: TCMS_encrypt = nil;
  CMS_decrypt: TCMS_decrypt = nil;
  CMS_decrypt_set1_pkey: TCMS_decrypt_set1_pkey = nil;
  CMS_decrypt_set1_key: TCMS_decrypt_set1_key = nil;
  CMS_decrypt_set1_password: TCMS_decrypt_set1_password = nil;

  // CMS RecipientInfo
  CMS_add0_recipient_key: TCMS_add0_recipient_key = nil;
  CMS_add0_recipient_password: TCMS_add0_recipient_password = nil;
  CMS_add1_recipient_cert: TCMS_add1_recipient_cert = nil;
  CMS_RecipientInfo_type: TCMS_RecipientInfo_type = nil;
  CMS_RecipientInfo_ktri_get0_signer_id: TCMS_RecipientInfo_ktri_get0_signer_id = nil;
  CMS_RecipientInfo_ktri_cert_cmp: TCMS_RecipientInfo_ktri_cert_cmp = nil;
  CMS_RecipientInfo_set0_pkey: TCMS_RecipientInfo_set0_pkey = nil;
  CMS_RecipientInfo_kekri_get0_id: TCMS_RecipientInfo_kekri_get0_id = nil;
  CMS_RecipientInfo_kekri_id_cmp: TCMS_RecipientInfo_kekri_id_cmp = nil;
  CMS_RecipientInfo_set0_key: TCMS_RecipientInfo_set0_key = nil;
  CMS_RecipientInfo_decrypt: TCMS_RecipientInfo_decrypt = nil;
  CMS_RecipientInfo_encrypt: TCMS_RecipientInfo_encrypt = nil;

  // CMS SignerInfo
  CMS_get0_SignerInfos: TCMS_get0_SignerInfos = nil;
  CMS_SignerInfo_get0_signer_id: TCMS_SignerInfo_get0_signer_id = nil;
  CMS_SignerInfo_get0_signature: TCMS_SignerInfo_get0_signature = nil;
  CMS_SignerInfo_cert_cmp: TCMS_SignerInfo_cert_cmp = nil;
  CMS_set1_signer_cert: TCMS_set1_signer_cert = nil;
  CMS_SignerInfo_get0_algs: TCMS_SignerInfo_get0_algs = nil;
  CMS_SignerInfo_get0_md_ctx: TCMS_SignerInfo_get0_md_ctx = nil;
  CMS_SignerInfo_verify: TCMS_SignerInfo_verify = nil;
  CMS_SignerInfo_verify_content: TCMS_SignerInfo_verify_content = nil;

  // CMS 属性操作
  CMS_signed_get_attr_count: TCMS_signed_get_attr_count = nil;
  CMS_signed_get_attr_by_NID: TCMS_signed_get_attr_by_NID = nil;
  CMS_signed_get_attr_by_OBJ: TCMS_signed_get_attr_by_OBJ = nil;
  CMS_signed_get_attr: TCMS_signed_get_attr = nil;
  CMS_signed_delete_attr: TCMS_signed_delete_attr = nil;
  CMS_signed_add1_attr: TCMS_signed_add1_attr = nil;
  CMS_signed_add1_attr_by_OBJ: TCMS_signed_add1_attr_by_OBJ = nil;
  CMS_signed_add1_attr_by_NID: TCMS_signed_add1_attr_by_NID = nil;
  CMS_signed_add1_attr_by_txt: TCMS_signed_add1_attr_by_txt = nil;
  CMS_signed_get0_data_by_OBJ: TCMS_signed_get0_data_by_OBJ = nil;

  // CMS 未签名属性
  CMS_unsigned_get_attr_count: TCMS_unsigned_get_attr_count = nil;
  CMS_unsigned_get_attr_by_NID: TCMS_unsigned_get_attr_by_NID = nil;
  CMS_unsigned_get_attr_by_OBJ: TCMS_unsigned_get_attr_by_OBJ = nil;
  CMS_unsigned_get_attr: TCMS_unsigned_get_attr = nil;
  CMS_unsigned_delete_attr: TCMS_unsigned_delete_attr = nil;
  CMS_unsigned_add1_attr: TCMS_unsigned_add1_attr = nil;
  CMS_unsigned_add1_attr_by_OBJ: TCMS_unsigned_add1_attr_by_OBJ = nil;
  CMS_unsigned_add1_attr_by_NID: TCMS_unsigned_add1_attr_by_NID = nil;
  CMS_unsigned_add1_attr_by_txt: TCMS_unsigned_add1_attr_by_txt = nil;
  CMS_unsigned_get0_data_by_OBJ: TCMS_unsigned_get0_data_by_OBJ = nil;

  // CMS 实用功能
  CMS_get0_type: TCMS_get0_type = nil;
  CMS_set1_eContentType: TCMS_set1_eContentType = nil;
  CMS_get0_eContentType: TCMS_get0_eContentType = nil;
  CMS_get0_content: TCMS_get0_content = nil;
  CMS_is_detached: TCMS_is_detached = nil;
  CMS_set_detached: TCMS_set_detached = nil;
  CMS_stream_func: TCMS_stream = nil;  // Renamed to avoid conflict with constant
  CMS_dataInit: TCMS_dataInit = nil;
  CMS_dataFinal: TCMS_dataFinal = nil;
  CMS_data: TCMS_data = nil;
  CMS_data_create: TCMS_data_create = nil;
  CMS_digest_verify: TCMS_digest_verify = nil;
  CMS_digest_create: TCMS_digest_create = nil;
  CMS_EncryptedData_decrypt: TCMS_EncryptedData_decrypt = nil;
  CMS_EncryptedData_encrypt: TCMS_EncryptedData_encrypt = nil;
  CMS_EncryptedData_set1_key: TCMS_EncryptedData_set1_key = nil;

  // CMS 压缩
  CMS_uncompress: TCMS_uncompress = nil;
  CMS_compress: TCMS_compress = nil;

  // CMS 收据
  CMS_add1_ReceiptRequest: TCMS_add1_ReceiptRequest = nil;
  CMS_get1_ReceiptRequest: TCMS_get1_ReceiptRequest = nil;
  CMS_ReceiptRequest_create0: TCMS_ReceiptRequest_create0 = nil;
  CMS_add1_Receipt: TCMS_add1_Receipt = nil;
  CMS_get1_Receipt: TCMS_get1_Receipt = nil;
  CMS_RecipientInfo_kari_get0_alg: TCMS_RecipientInfo_kari_get0_alg = nil;
  CMS_RecipientInfo_kari_get0_reks: TCMS_RecipientInfo_kari_get0_reks = nil;
  CMS_RecipientInfo_kari_get0_orig_id: TCMS_RecipientInfo_kari_get0_orig_id = nil;
  CMS_RecipientInfo_kari_orig_id_cmp: TCMS_RecipientInfo_kari_orig_id_cmp = nil;

// 加载和卸载函数
function LoadOpenSSLCMS(const ACryptoLib: THandle): Boolean;
procedure UnloadOpenSSLCMS;

// 辅助函数
function CMSSignData(const AData: TBytes; ACert: PX509; AKey: PEVP_PKEY; 
  AFlags: Cardinal = CMS_DETACHED): PCMS_ContentInfo;
function CMSVerifySignature(const AData: TBytes; ASignature: PCMS_ContentInfo; 
  ACerts: PSTACK_OF_X509; AStore: PX509_STORE; AFlags: Cardinal = 0): Boolean;
function CMSEncryptData(const AData: TBytes; ARecipients: PSTACK_OF_X509; 
  ACipher: PEVP_CIPHER = nil; AFlags: Cardinal = 0): PCMS_ContentInfo;
function CMSDecryptData(AEncrypted: PCMS_ContentInfo; AKey: PEVP_PKEY; 
  ACert: PX509; AFlags: Cardinal = 0): TBytes;

implementation

// CMS 函数绑定数组（runtime storage, avoid fragile const procvar tables on macOS）
var
  CMS_FUNCTION_BINDINGS: array[0..88] of TFunctionBinding = (
    // CMS 创建和释放
    (Name: 'CMS_ContentInfo_new'; FuncPtr: @CMS_ContentInfo_new; Required: False),
    (Name: 'CMS_ContentInfo_free'; FuncPtr: @CMS_ContentInfo_free; Required: False),
    (Name: 'd2i_CMS_ContentInfo'; FuncPtr: @d2i_CMS_ContentInfo; Required: False),
    (Name: 'i2d_CMS_ContentInfo'; FuncPtr: @i2d_CMS_ContentInfo; Required: False),
    (Name: 'd2i_CMS_bio'; FuncPtr: @d2i_CMS_bio; Required: False),
    (Name: 'i2d_CMS_bio'; FuncPtr: @i2d_CMS_bio; Required: False),
    (Name: 'i2d_CMS_bio_stream'; FuncPtr: @i2d_CMS_bio_stream; Required: False),
    (Name: 'CMS_ContentInfo_print_ctx'; FuncPtr: @CMS_ContentInfo_print_ctx; Required: False),
    // CMS 签名操作
    (Name: 'CMS_sign'; FuncPtr: @CMS_sign; Required: False),
    (Name: 'CMS_sign_receipt'; FuncPtr: @CMS_sign_receipt; Required: False),
    (Name: 'CMS_add1_signer'; FuncPtr: @CMS_add1_signer; Required: False),
    (Name: 'CMS_SignerInfo_sign'; FuncPtr: @CMS_SignerInfo_sign; Required: False),
    (Name: 'CMS_final'; FuncPtr: @CMS_final; Required: False),
    (Name: 'CMS_verify'; FuncPtr: @CMS_verify; Required: False),
    (Name: 'CMS_verify_receipt'; FuncPtr: @CMS_verify_receipt; Required: False),
    (Name: 'CMS_get0_signers'; FuncPtr: @CMS_get0_signers; Required: False),
    // CMS 加密操作
    (Name: 'CMS_encrypt'; FuncPtr: @CMS_encrypt; Required: False),
    (Name: 'CMS_decrypt'; FuncPtr: @CMS_decrypt; Required: False),
    (Name: 'CMS_decrypt_set1_pkey'; FuncPtr: @CMS_decrypt_set1_pkey; Required: False),
    (Name: 'CMS_decrypt_set1_key'; FuncPtr: @CMS_decrypt_set1_key; Required: False),
    (Name: 'CMS_decrypt_set1_password'; FuncPtr: @CMS_decrypt_set1_password; Required: False),
    // CMS RecipientInfo
    (Name: 'CMS_add0_recipient_key'; FuncPtr: @CMS_add0_recipient_key; Required: False),
    (Name: 'CMS_add0_recipient_password'; FuncPtr: @CMS_add0_recipient_password; Required: False),
    (Name: 'CMS_add1_recipient_cert'; FuncPtr: @CMS_add1_recipient_cert; Required: False),
    (Name: 'CMS_RecipientInfo_type'; FuncPtr: @CMS_RecipientInfo_type; Required: False),
    (Name: 'CMS_RecipientInfo_ktri_get0_signer_id'; FuncPtr: @CMS_RecipientInfo_ktri_get0_signer_id; Required: False),
    (Name: 'CMS_RecipientInfo_ktri_cert_cmp'; FuncPtr: @CMS_RecipientInfo_ktri_cert_cmp; Required: False),
    (Name: 'CMS_RecipientInfo_set0_pkey'; FuncPtr: @CMS_RecipientInfo_set0_pkey; Required: False),
    (Name: 'CMS_RecipientInfo_kekri_get0_id'; FuncPtr: @CMS_RecipientInfo_kekri_get0_id; Required: False),
    (Name: 'CMS_RecipientInfo_kekri_id_cmp'; FuncPtr: @CMS_RecipientInfo_kekri_id_cmp; Required: False),
    (Name: 'CMS_RecipientInfo_set0_key'; FuncPtr: @CMS_RecipientInfo_set0_key; Required: False),
    (Name: 'CMS_RecipientInfo_decrypt'; FuncPtr: @CMS_RecipientInfo_decrypt; Required: False),
    (Name: 'CMS_RecipientInfo_encrypt'; FuncPtr: @CMS_RecipientInfo_encrypt; Required: False),
    // CMS SignerInfo
    (Name: 'CMS_get0_SignerInfos'; FuncPtr: @CMS_get0_SignerInfos; Required: False),
    (Name: 'CMS_SignerInfo_get0_signer_id'; FuncPtr: @CMS_SignerInfo_get0_signer_id; Required: False),
    (Name: 'CMS_SignerInfo_get0_signature'; FuncPtr: @CMS_SignerInfo_get0_signature; Required: False),
    (Name: 'CMS_SignerInfo_cert_cmp'; FuncPtr: @CMS_SignerInfo_cert_cmp; Required: False),
    (Name: 'CMS_set1_signer_cert'; FuncPtr: @CMS_set1_signer_cert; Required: False),
    (Name: 'CMS_SignerInfo_get0_algs'; FuncPtr: @CMS_SignerInfo_get0_algs; Required: False),
    (Name: 'CMS_SignerInfo_get0_md_ctx'; FuncPtr: @CMS_SignerInfo_get0_md_ctx; Required: False),
    (Name: 'CMS_SignerInfo_verify'; FuncPtr: @CMS_SignerInfo_verify; Required: False),
    (Name: 'CMS_SignerInfo_verify_content'; FuncPtr: @CMS_SignerInfo_verify_content; Required: False),
    // CMS 属性操作
    (Name: 'CMS_signed_get_attr_count'; FuncPtr: @CMS_signed_get_attr_count; Required: False),
    (Name: 'CMS_signed_get_attr_by_NID'; FuncPtr: @CMS_signed_get_attr_by_NID; Required: False),
    (Name: 'CMS_signed_get_attr_by_OBJ'; FuncPtr: @CMS_signed_get_attr_by_OBJ; Required: False),
    (Name: 'CMS_signed_get_attr'; FuncPtr: @CMS_signed_get_attr; Required: False),
    (Name: 'CMS_signed_delete_attr'; FuncPtr: @CMS_signed_delete_attr; Required: False),
    (Name: 'CMS_signed_add1_attr'; FuncPtr: @CMS_signed_add1_attr; Required: False),
    (Name: 'CMS_signed_add1_attr_by_OBJ'; FuncPtr: @CMS_signed_add1_attr_by_OBJ; Required: False),
    (Name: 'CMS_signed_add1_attr_by_NID'; FuncPtr: @CMS_signed_add1_attr_by_NID; Required: False),
    (Name: 'CMS_signed_add1_attr_by_txt'; FuncPtr: @CMS_signed_add1_attr_by_txt; Required: False),
    (Name: 'CMS_signed_get0_data_by_OBJ'; FuncPtr: @CMS_signed_get0_data_by_OBJ; Required: False),
    // CMS 未签名属性
    (Name: 'CMS_unsigned_get_attr_count'; FuncPtr: @CMS_unsigned_get_attr_count; Required: False),
    (Name: 'CMS_unsigned_get_attr_by_NID'; FuncPtr: @CMS_unsigned_get_attr_by_NID; Required: False),
    (Name: 'CMS_unsigned_get_attr_by_OBJ'; FuncPtr: @CMS_unsigned_get_attr_by_OBJ; Required: False),
    (Name: 'CMS_unsigned_get_attr'; FuncPtr: @CMS_unsigned_get_attr; Required: False),
    (Name: 'CMS_unsigned_delete_attr'; FuncPtr: @CMS_unsigned_delete_attr; Required: False),
    (Name: 'CMS_unsigned_add1_attr'; FuncPtr: @CMS_unsigned_add1_attr; Required: False),
    (Name: 'CMS_unsigned_add1_attr_by_OBJ'; FuncPtr: @CMS_unsigned_add1_attr_by_OBJ; Required: False),
    (Name: 'CMS_unsigned_add1_attr_by_NID'; FuncPtr: @CMS_unsigned_add1_attr_by_NID; Required: False),
    (Name: 'CMS_unsigned_add1_attr_by_txt'; FuncPtr: @CMS_unsigned_add1_attr_by_txt; Required: False),
    (Name: 'CMS_unsigned_get0_data_by_OBJ'; FuncPtr: @CMS_unsigned_get0_data_by_OBJ; Required: False),
    // CMS 实用功能
    (Name: 'CMS_get0_type'; FuncPtr: @CMS_get0_type; Required: False),
    (Name: 'CMS_set1_eContentType'; FuncPtr: @CMS_set1_eContentType; Required: False),
    (Name: 'CMS_get0_eContentType'; FuncPtr: @CMS_get0_eContentType; Required: False),
    (Name: 'CMS_get0_content'; FuncPtr: @CMS_get0_content; Required: False),
    (Name: 'CMS_is_detached'; FuncPtr: @CMS_is_detached; Required: False),
    (Name: 'CMS_set_detached'; FuncPtr: @CMS_set_detached; Required: False),
    (Name: 'CMS_stream'; FuncPtr: @CMS_stream_func; Required: False),
    (Name: 'CMS_dataInit'; FuncPtr: @CMS_dataInit; Required: False),
    (Name: 'CMS_dataFinal'; FuncPtr: @CMS_dataFinal; Required: False),
    (Name: 'CMS_data'; FuncPtr: @CMS_data; Required: False),
    (Name: 'CMS_data_create'; FuncPtr: @CMS_data_create; Required: False),
    (Name: 'CMS_digest_verify'; FuncPtr: @CMS_digest_verify; Required: False),
    (Name: 'CMS_digest_create'; FuncPtr: @CMS_digest_create; Required: False),
    (Name: 'CMS_EncryptedData_decrypt'; FuncPtr: @CMS_EncryptedData_decrypt; Required: False),
    (Name: 'CMS_EncryptedData_encrypt'; FuncPtr: @CMS_EncryptedData_encrypt; Required: False),
    (Name: 'CMS_EncryptedData_set1_key'; FuncPtr: @CMS_EncryptedData_set1_key; Required: False),
    // CMS 压缩
    (Name: 'CMS_uncompress'; FuncPtr: @CMS_uncompress; Required: False),
    (Name: 'CMS_compress'; FuncPtr: @CMS_compress; Required: False),
    // CMS 收据
    (Name: 'CMS_add1_ReceiptRequest'; FuncPtr: @CMS_add1_ReceiptRequest; Required: False),
    (Name: 'CMS_get1_ReceiptRequest'; FuncPtr: @CMS_get1_ReceiptRequest; Required: False),
    (Name: 'CMS_ReceiptRequest_create0'; FuncPtr: @CMS_ReceiptRequest_create0; Required: False),
    (Name: 'CMS_add1_Receipt'; FuncPtr: @CMS_add1_Receipt; Required: False),
    (Name: 'CMS_get1_Receipt'; FuncPtr: @CMS_get1_Receipt; Required: False),
    (Name: 'CMS_RecipientInfo_kari_get0_alg'; FuncPtr: @CMS_RecipientInfo_kari_get0_alg; Required: False),
    (Name: 'CMS_RecipientInfo_kari_get0_reks'; FuncPtr: @CMS_RecipientInfo_kari_get0_reks; Required: False),
    (Name: 'CMS_RecipientInfo_kari_get0_orig_id'; FuncPtr: @CMS_RecipientInfo_kari_get0_orig_id; Required: False),
    (Name: 'CMS_RecipientInfo_kari_orig_id_cmp'; FuncPtr: @CMS_RecipientInfo_kari_orig_id_cmp; Required: False)
  );

function LoadOpenSSLCMS(const ACryptoLib: THandle): Boolean;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmCMS) then
    Exit(True);

  if ACryptoLib = 0 then
    Exit(False);

  // 使用批量加载模式
  TOpenSSLLoader.LoadFunctions(ACryptoLib, CMS_FUNCTION_BINDINGS);

  TOpenSSLLoader.SetModuleLoaded(osmCMS, Assigned(CMS_sign) and Assigned(CMS_verify));
  Result := TOpenSSLLoader.IsModuleLoaded(osmCMS);
end;

procedure UnloadOpenSSLCMS;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmCMS) then
    Exit;

  // 使用批量清理模式
  TOpenSSLLoader.ClearFunctions(CMS_FUNCTION_BINDINGS);

  TOpenSSLLoader.SetModuleLoaded(osmCMS, False);
end;

// 辅助函数实现
function CMSSignData(const AData: TBytes; ACert: PX509; AKey: PEVP_PKEY;
  AFlags: Cardinal): PCMS_ContentInfo;
var
  Bio: PBIO;
begin
  Result := nil;
  if not TOpenSSLLoader.IsModuleLoaded(osmCMS) or
    (Length(AData) = 0) or
    (ACert = nil) or
    (AKey = nil) or
    not Assigned(BIO_new_mem_buf) or
    not Assigned(CMS_sign) or
    not Assigned(BIO_free) then
    Exit;

  Bio := BIO_new_mem_buf(@AData[0], Length(AData));
  if Bio = nil then
    Exit;

  try
    Result := CMS_sign(ACert, AKey, nil, Bio, AFlags);
  finally
    BIO_free(Bio);
  end;
end;

function CMSVerifySignature(const AData: TBytes; ASignature: PCMS_ContentInfo;
  ACerts: PSTACK_OF_X509; AStore: PX509_STORE; AFlags: Cardinal): Boolean;
var
  DataBio, OutBio: PBIO;
begin
  Result := False;
  if not TOpenSSLLoader.IsModuleLoaded(osmCMS) or
    (Length(AData) = 0) or
    (ASignature = nil) or
    not Assigned(BIO_new_mem_buf) or
    not Assigned(BIO_new) or
    not Assigned(BIO_s_null) or
    not Assigned(CMS_verify) or
    not Assigned(BIO_free) then
    Exit;

  DataBio := BIO_new_mem_buf(@AData[0], Length(AData));
  if DataBio = nil then
    Exit;

  OutBio := BIO_new(BIO_s_null());
  try
    Result := CMS_verify(ASignature, ACerts, AStore, DataBio, OutBio, AFlags) = 1;
  finally
    BIO_free(DataBio);
    BIO_free(OutBio);
  end;
end;

function CMSEncryptData(const AData: TBytes; ARecipients: PSTACK_OF_X509;
  ACipher: PEVP_CIPHER; AFlags: Cardinal): PCMS_ContentInfo;
var
  Bio: PBIO;
begin
  Result := nil;
  if not TOpenSSLLoader.IsModuleLoaded(osmCMS) or
    (Length(AData) = 0) or
    (ARecipients = nil) or
    not Assigned(BIO_new_mem_buf) or
    not Assigned(CMS_encrypt) or
    not Assigned(BIO_free) then
    Exit;

  // 默认使用 AES-256-CBC
  if ACipher = nil then
    ACipher := EVP_aes_256_cbc();

  Bio := BIO_new_mem_buf(@AData[0], Length(AData));
  if Bio = nil then
    Exit;

  try
    Result := CMS_encrypt(ARecipients, Bio, ACipher, AFlags);
  finally
    BIO_free(Bio);
  end;
end;

function CMSDecryptData(AEncrypted: PCMS_ContentInfo; AKey: PEVP_PKEY;
  ACert: PX509; AFlags: Cardinal): TBytes;
var
  InBio, OutBio: PBIO;
  Len: Integer;
  Buf: array[0..4095] of Byte;
  Stream: TMemoryStream;
begin
  Result := nil;
  SetLength(Result, 0);
  if not TOpenSSLLoader.IsModuleLoaded(osmCMS) or
    (AEncrypted = nil) or
    (AKey = nil) or
    not Assigned(BIO_new) or
    not Assigned(BIO_s_null) or
    not Assigned(BIO_s_mem) or
    not Assigned(BIO_free) or
    not Assigned(CMS_decrypt) or
    not Assigned(BIO_read) then
    Exit;

  InBio := BIO_new(BIO_s_null());
  OutBio := BIO_new(BIO_s_mem());
  
  try
    if CMS_decrypt(AEncrypted, AKey, ACert, InBio, OutBio, AFlags) = 1 then
    begin
      Stream := TMemoryStream.Create;
      try
        repeat
          Len := BIO_read(OutBio, @Buf[0], SizeOf(Buf));
          if Len > 0 then
            Stream.Write(Buf, Len);
        until Len <= 0;
        
        SetLength(Result, Stream.Size);
        if Stream.Size > 0 then
          Move(Stream.Memory^, Result[0], Stream.Size);
      finally
        Stream.Free;
      end;
    end;
  finally
    BIO_free(InBio);
    BIO_free(OutBio);
  end;
end;

end.
