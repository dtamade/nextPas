{$mode ObjFPC}{$H+}

unit nextpas.core.tls.openssl.api.pkcs7;

interface

uses nextpas.core.tls.base, nextpas.core.tls.exceptions, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.bio, nextpas.core.tls.openssl.api.x509, nextpas.core.tls.openssl.api.evp, nextpas.core.tls.openssl.api.stack;

const
  // PKCS7 content types (NID values)
  NID_pkcs7_data = 21;
  NID_pkcs7_signed = 22;
  NID_pkcs7_enveloped = 23;
  NID_pkcs7_signedAndEnveloped = 24;
  NID_pkcs7_digest = 25;
  NID_pkcs7_encrypted = 26;
  
  // PKCS7 flags for signing
  PKCS7_TEXT = $1;
  PKCS7_NOCERTS = $2;
  PKCS7_NOSIGS = $4;
  PKCS7_NOCHAIN = $8;
  PKCS7_NOINTERN = $10;
  PKCS7_NOVERIFY = $20;
  PKCS7_DETACHED = $40;
  PKCS7_BINARY = $80;
  PKCS7_NOATTR = $100;
  PKCS7_NOSMIMECAP = $200;
  PKCS7_NOOLDMIMETYPE = $400;
  PKCS7_CRLFEOL = $800;
  PKCS7_STREAM = $1000;
  PKCS7_NOCRL = $2000;
  PKCS7_PARTIAL = $4000;
  PKCS7_REUSE_DIGEST = $8000;
  PKCS7_NO_DUAL_CONTENT = $10000;
  
  // PKCS7 operation types
  PKCS7_OP_SET_DETACHED_SIGNATURE = 1;
  PKCS7_OP_GET_DETACHED_SIGNATURE = 2;

type
  // Pointer types for X509_ALGOR and ASN1_PCTX
  PSTACK_OF_X509_ALGOR = POPENSSL_STACK;
  PSTACK_OF_X509_ATTRIBUTE = POPENSSL_STACK;
  PASN1_PCTX = Pointer;

  // PKCS7 structures (opaque in OpenSSL 1.1.0+)
  PKCS7 = record
    opaque_data: Pointer;
  end;
  PPKCS7 = ^PKCS7;
  
  PKCS7_SIGNED = record
    opaque_data: Pointer;
  end;
  PPKCS7_SIGNED = ^PKCS7_SIGNED;
  
  PKCS7_ENVELOPE = record
    opaque_data: Pointer;
  end;
  PPKCS7_ENVELOPE = ^PKCS7_ENVELOPE;
  
  PKCS7_SIGN_ENVELOPE = record
    opaque_data: Pointer;
  end;
  PPKCS7_SIGN_ENVELOPE = ^PKCS7_SIGN_ENVELOPE;
  
  PKCS7_DIGEST = record
    opaque_data: Pointer;
  end;
  PPKCS7_DIGEST = ^PKCS7_DIGEST;
  
  PKCS7_ENCRYPTED = record
    opaque_data: Pointer;
  end;
  PPKCS7_ENCRYPTED = ^PKCS7_ENCRYPTED;
  
  PKCS7_SIGNER_INFO = record
    opaque_data: Pointer;
  end;
  PPKCS7_SIGNER_INFO = ^PKCS7_SIGNER_INFO;
  
  PKCS7_RECIP_INFO = record
    opaque_data: Pointer;
  end;
  PPKCS7_RECIP_INFO = ^PKCS7_RECIP_INFO;
  
  // Stack types
  PSTACK_OF_PKCS7_SIGNER_INFO = POPENSSL_STACK;
  PSTACK_OF_PKCS7_RECIP_INFO = POPENSSL_STACK;
  
  // Function pointer types for PKCS7 operations
  TPKCS7_new = function: PPKCS7; cdecl;
  TPKCS7_free = procedure(p7: PPKCS7); cdecl;
  TPKCS7_content_new = function(p7: PPKCS7; nid: Integer): Integer; cdecl;
  TPKCS7_set_type = function(p7: PPKCS7; typ: Integer): Integer; cdecl;
  TPKCS7_set0_type_other = function(p7: PPKCS7; typ: Integer; other: PASN1_TYPE): Integer; cdecl;
  TPKCS7_set_content = function(p7: PPKCS7; p7_data: PPKCS7): Integer; cdecl;
  TPKCS7_SIGNER_INFO_new = function: PPKCS7_SIGNER_INFO; cdecl;
  TPKCS7_SIGNER_INFO_free = procedure(si: PPKCS7_SIGNER_INFO); cdecl;
  TPKCS7_RECIP_INFO_new = function: PPKCS7_RECIP_INFO; cdecl;
  TPKCS7_RECIP_INFO_free = procedure(ri: PPKCS7_RECIP_INFO); cdecl;
  TPKCS7_add_signer = function(p7: PPKCS7; si: PPKCS7_SIGNER_INFO): Integer; cdecl;
  TPKCS7_add_certificate = function(p7: PPKCS7; x509: PX509): Integer; cdecl;
  TPKCS7_add_crl = function(p7: PPKCS7; x509: PX509_CRL): Integer; cdecl;
  TPKCS7_digest_from_attributes = function(sk: PSTACK_OF_X509_ATTRIBUTE): PASN1_OCTET_STRING; cdecl;
  TPKCS7_add_signed_attribute = function(si: PPKCS7_SIGNER_INFO; nid: Integer; typ: Integer; data: Pointer): Integer; cdecl;
  TPKCS7_add_attribute = function(si: PPKCS7_SIGNER_INFO; nid: Integer; atrtype: Integer; value: Pointer): Integer; cdecl;
  TPKCS7_get_attribute = function(si: PPKCS7_SIGNER_INFO; nid: Integer): PASN1_TYPE; cdecl;
  TPKCS7_get_signed_attribute = function(si: PPKCS7_SIGNER_INFO; nid: Integer): PASN1_TYPE; cdecl;
  TPKCS7_set_signed_attributes = function(si: PPKCS7_SIGNER_INFO; sk: PSTACK_OF_X509_ATTRIBUTE): Integer; cdecl;
  TPKCS7_set_attributes = function(si: PPKCS7_SIGNER_INFO; sk: PSTACK_OF_X509_ATTRIBUTE): Integer; cdecl;
  TPKCS7_sign = function(signcert: PX509; pkey: PEVP_PKEY; certs: PSTACK_OF_X509; data: PBIO; flags: Integer): PPKCS7; cdecl;
  TPKCS7_sign_add_signer = function(p7: PPKCS7; signcert: PX509; pkey: PEVP_PKEY; const md: PEVP_MD; flags: Integer): PPKCS7_SIGNER_INFO; cdecl;
  TPKCS7_final = function(p7: PPKCS7; data: PBIO; flags: Integer): Integer; cdecl;
  TPKCS7_verify = function(p7: PPKCS7; certs: PSTACK_OF_X509; store: PX509_STORE; indata: PBIO; outp: PBIO; flags: Integer): Integer; cdecl;
  TPKCS7_get0_signers = function(p7: PPKCS7; certs: PSTACK_OF_X509; flags: Integer): PSTACK_OF_X509; cdecl;
  TPKCS7_encrypt = function(certs: PSTACK_OF_X509; inp: PBIO; cipher: PEVP_CIPHER; flags: Integer): PPKCS7; cdecl;
  TPKCS7_decrypt = function(p7: PPKCS7; pkey: PEVP_PKEY; cert: PX509; outp: PBIO; flags: Integer): Integer; cdecl;
  TPKCS7_add_recipient = function(p7: PPKCS7; x509: PX509): PPKCS7_RECIP_INFO; cdecl;
  TPKCS7_RECIP_INFO_set = function(ri: PPKCS7_RECIP_INFO; x509: PX509): Integer; cdecl;
  TPKCS7_set_cipher = function(p7: PPKCS7; const cipher: PEVP_CIPHER): Integer; cdecl;
  TPKCS7_stream = function(boundary: PPBIO; p7: PPKCS7): Integer; cdecl;
  TPKCS7_dataInit = function(p7: PPKCS7; bio: PBIO): PBIO; cdecl;
  TPKCS7_dataFinal = function(p7: PPKCS7; bio: PBIO): Integer; cdecl;
  TPKCS7_dataDecode = function(p7: PPKCS7; pkey: PEVP_PKEY; in_bio: PBIO; pcert: PX509): PBIO; cdecl;
  TPKCS7_dataVerify = function(cert_store: PX509_STORE; ctx: PX509_STORE_CTX; bio: PBIO; p7: PPKCS7; si: PPKCS7_SIGNER_INFO): Integer; cdecl;
  TPKCS7_signatureVerify = function(bio: PBIO; p7: PPKCS7; si: PPKCS7_SIGNER_INFO; x509: PX509): Integer; cdecl;
  TPKCS7_get_signer_info = function(p7: PPKCS7): PSTACK_OF_PKCS7_SIGNER_INFO; cdecl;
  TPKCS7_get_recip_info = function(p7: PPKCS7): PSTACK_OF_PKCS7_RECIP_INFO; cdecl;
  TPKCS7_add_recipient_info = function(p7: PPKCS7; ri: PPKCS7_RECIP_INFO): Integer; cdecl;
  TPKCS7_RECIP_INFO_get0_alg = procedure(ri: PPKCS7_RECIP_INFO; enc_alg: PPX509_ALGOR); cdecl;
  TPKCS7_SIGNER_INFO_get0_algs = procedure(si: PPKCS7_SIGNER_INFO; pk: PPEVP_PKEY; pdig: PPX509_ALGOR; psig: PPX509_ALGOR); cdecl;
  TPKCS7_SIGNER_INFO_set = function(si: PPKCS7_SIGNER_INFO; x509: PX509; pkey: PEVP_PKEY; const dgst: PEVP_MD): Integer; cdecl;
  TPKCS7_add_attrib_smimecap = function(si: PPKCS7_SIGNER_INFO; cap: PSTACK_OF_X509_ALGOR): Integer; cdecl;
  TPKCS7_simple_smimecap = function(sk: PSTACK_OF_X509_ALGOR; nid: Integer; arg: Integer): Integer; cdecl;
  TPKCS7_add_attrib_content_type = function(si: PPKCS7_SIGNER_INFO; coid: PASN1_OBJECT): Integer; cdecl;
  TPKCS7_add0_attrib_signing_time = function(si: PPKCS7_SIGNER_INFO; t: PASN1_TIME): Integer; cdecl;
  TPKCS7_add1_attrib_digest = function(si: PPKCS7_SIGNER_INFO; const md: PByte; mdlen: Integer): Integer; cdecl;
  
  // I/O functions
  Ti2d_PKCS7 = function(a: PPKCS7; pp: PPByte): Integer; cdecl;
  Td2i_PKCS7 = function(a: PPPKCS7; const pp: PPByte; length: LongInt): PPKCS7; cdecl;
  Ti2d_PKCS7_bio = function(bp: PBIO; p7: PPKCS7): Integer; cdecl;
  Td2i_PKCS7_bio = function(bp: PBIO; p7: PPPKCS7): PPKCS7; cdecl;
  TPEM_read_bio_PKCS7 = function(bp: PBIO; x: PPPKCS7; cb: Tpem_password_cb; u: Pointer): PPKCS7; cdecl;
  TPEM_write_bio_PKCS7 = function(bp: PBIO; x: PPKCS7): Integer; cdecl;
  TPKCS7_print_ctx = function(outp: PBIO; x: PPKCS7; indent: Integer; const pctx: PASN1_PCTX): Integer; cdecl;
  
  // SMIME functions
  TSMIME_write_PKCS7 = function(bio: PBIO; p7: PPKCS7; data: PBIO; flags: Integer): Integer; cdecl;
  TSMIME_read_PKCS7 = function(bio: PBIO; bcont: PPBIO): PPKCS7; cdecl;
  TSMIME_text = function(inp: PBIO; outp: PBIO): Integer; cdecl;

var
  // PKCS7 functions
  PKCS7_new: TPKCS7_new = nil;
  PKCS7_free: TPKCS7_free = nil;
  PKCS7_content_new: TPKCS7_content_new = nil;
  PKCS7_set_type: TPKCS7_set_type = nil;
  PKCS7_set0_type_other: TPKCS7_set0_type_other = nil;
  PKCS7_set_content: TPKCS7_set_content = nil;
  PKCS7_SIGNER_INFO_new: TPKCS7_SIGNER_INFO_new = nil;
  PKCS7_SIGNER_INFO_free: TPKCS7_SIGNER_INFO_free = nil;
  PKCS7_RECIP_INFO_new: TPKCS7_RECIP_INFO_new = nil;
  PKCS7_RECIP_INFO_free: TPKCS7_RECIP_INFO_free = nil;
  PKCS7_add_signer: TPKCS7_add_signer = nil;
  PKCS7_add_certificate: TPKCS7_add_certificate = nil;
  PKCS7_add_crl: TPKCS7_add_crl = nil;
  PKCS7_digest_from_attributes: TPKCS7_digest_from_attributes = nil;
  PKCS7_add_signed_attribute: TPKCS7_add_signed_attribute = nil;
  PKCS7_add_attribute: TPKCS7_add_attribute = nil;
  PKCS7_get_attribute: TPKCS7_get_attribute = nil;
  PKCS7_get_signed_attribute: TPKCS7_get_signed_attribute = nil;
  PKCS7_set_signed_attributes: TPKCS7_set_signed_attributes = nil;
  PKCS7_set_attributes: TPKCS7_set_attributes = nil;
  PKCS7_sign: TPKCS7_sign = nil;
  PKCS7_sign_add_signer: TPKCS7_sign_add_signer = nil;
  PKCS7_final: TPKCS7_final = nil;
  PKCS7_verify: TPKCS7_verify = nil;
  PKCS7_get0_signers: TPKCS7_get0_signers = nil;
  PKCS7_encrypt: TPKCS7_encrypt = nil;
  PKCS7_decrypt: TPKCS7_decrypt = nil;
  PKCS7_add_recipient: TPKCS7_add_recipient = nil;
  PKCS7_RECIP_INFO_set: TPKCS7_RECIP_INFO_set = nil;
  PKCS7_set_cipher: TPKCS7_set_cipher = nil;
  PKCS7_stream_func: TPKCS7_stream = nil;
  PKCS7_dataInit: TPKCS7_dataInit = nil;
  PKCS7_dataFinal: TPKCS7_dataFinal = nil;
  PKCS7_dataDecode: TPKCS7_dataDecode = nil;
  PKCS7_dataVerify: TPKCS7_dataVerify = nil;
  PKCS7_signatureVerify: TPKCS7_signatureVerify = nil;
  PKCS7_get_signer_info: TPKCS7_get_signer_info = nil;
  PKCS7_get_recip_info: TPKCS7_get_recip_info = nil;
  PKCS7_add_recipient_info: TPKCS7_add_recipient_info = nil;
  PKCS7_RECIP_INFO_get0_alg: TPKCS7_RECIP_INFO_get0_alg = nil;
  PKCS7_SIGNER_INFO_get0_algs: TPKCS7_SIGNER_INFO_get0_algs = nil;
  PKCS7_SIGNER_INFO_set: TPKCS7_SIGNER_INFO_set = nil;
  PKCS7_add_attrib_smimecap: TPKCS7_add_attrib_smimecap = nil;
  PKCS7_simple_smimecap: TPKCS7_simple_smimecap = nil;
  PKCS7_add_attrib_content_type: TPKCS7_add_attrib_content_type = nil;
  PKCS7_add0_attrib_signing_time: TPKCS7_add0_attrib_signing_time = nil;
  PKCS7_add1_attrib_digest: TPKCS7_add1_attrib_digest = nil;
  
  // I/O functions
  i2d_PKCS7: Ti2d_PKCS7 = nil;
  d2i_PKCS7: Td2i_PKCS7 = nil;
  i2d_PKCS7_bio: Ti2d_PKCS7_bio = nil;
  d2i_PKCS7_bio: Td2i_PKCS7_bio = nil;
  PEM_read_bio_PKCS7: TPEM_read_bio_PKCS7 = nil;
  PEM_write_bio_PKCS7: TPEM_write_bio_PKCS7 = nil;
  PKCS7_print_ctx: TPKCS7_print_ctx = nil;
  
  // SMIME functions
  SMIME_write_PKCS7: TSMIME_write_PKCS7 = nil;
  SMIME_read_PKCS7: TSMIME_read_PKCS7 = nil;
  SMIME_text: TSMIME_text = nil;

// Load and unload functions
function LoadPKCS7Functions: Boolean;
procedure UnloadPKCS7Functions;

// High-level helper functions
function SignData(const AData: TBytes; ASignCert: PX509; APrivKey: PEVP_PKEY; 
                  ACACerts: PSTACK_OF_X509; AFlags: Integer): TBytes;
function VerifySignedData(const ASignedData: TBytes; ACACerts: PSTACK_OF_X509; 
                        AStore: PX509_STORE; out AOutData: TBytes; AFlags: Integer): Boolean;
function EncryptData(const AData: TBytes; ARecipCerts: PSTACK_OF_X509; 
                    ACipher: PEVP_CIPHER; AFlags: Integer): TBytes;
function DecryptData(const AEncryptedData: TBytes; ARecipCert: PX509; 
                    APrivKey: PEVP_PKEY; out AOutData: TBytes; AFlags: Integer): Boolean;

implementation

function LoadPKCS7Functions: Boolean;
var
  LHandle: TLibHandle;
begin
  Result := False;

  // Phase 3.3 P0+ - 使用统一的动态库加载器（替换 ~25 行重复代码）
  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
  if LHandle = 0 then
    Exit;
    
  // Load PKCS7 functions
  PKCS7_new := TPKCS7_new(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_new'));
  PKCS7_free := TPKCS7_free(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_free'));
  PKCS7_content_new := TPKCS7_content_new(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_content_new'));
  PKCS7_set_type := TPKCS7_set_type(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_set_type'));
  PKCS7_set0_type_other := TPKCS7_set0_type_other(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_set0_type_other'));
  PKCS7_set_content := TPKCS7_set_content(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_set_content'));
  PKCS7_SIGNER_INFO_new := TPKCS7_SIGNER_INFO_new(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_SIGNER_INFO_new'));
  PKCS7_SIGNER_INFO_free := TPKCS7_SIGNER_INFO_free(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_SIGNER_INFO_free'));
  PKCS7_RECIP_INFO_new := TPKCS7_RECIP_INFO_new(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_RECIP_INFO_new'));
  PKCS7_RECIP_INFO_free := TPKCS7_RECIP_INFO_free(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_RECIP_INFO_free'));
  PKCS7_add_signer := TPKCS7_add_signer(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_add_signer'));
  PKCS7_add_certificate := TPKCS7_add_certificate(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_add_certificate'));
  PKCS7_add_crl := TPKCS7_add_crl(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_add_crl'));

  // Load attribute functions
  PKCS7_digest_from_attributes := TPKCS7_digest_from_attributes(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_digest_from_attributes'));
  PKCS7_add_signed_attribute := TPKCS7_add_signed_attribute(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_add_signed_attribute'));
  PKCS7_add_attribute := TPKCS7_add_attribute(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_add_attribute'));
  PKCS7_get_attribute := TPKCS7_get_attribute(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_get_attribute'));
  PKCS7_get_signed_attribute := TPKCS7_get_signed_attribute(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_get_signed_attribute'));
  PKCS7_set_signed_attributes := TPKCS7_set_signed_attributes(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_set_signed_attributes'));
  PKCS7_set_attributes := TPKCS7_set_attributes(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_set_attributes'));

  PKCS7_sign := TPKCS7_sign(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_sign'));
  PKCS7_sign_add_signer := TPKCS7_sign_add_signer(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_sign_add_signer'));
  PKCS7_final := TPKCS7_final(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_final'));
  PKCS7_verify := TPKCS7_verify(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_verify'));
  PKCS7_get0_signers := TPKCS7_get0_signers(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_get0_signers'));
  PKCS7_encrypt := TPKCS7_encrypt(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_encrypt'));
  PKCS7_decrypt := TPKCS7_decrypt(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_decrypt'));
  PKCS7_add_recipient := TPKCS7_add_recipient(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_add_recipient'));
  PKCS7_RECIP_INFO_set := TPKCS7_RECIP_INFO_set(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_RECIP_INFO_set'));
  PKCS7_set_cipher := TPKCS7_set_cipher(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_set_cipher'));

  // Load data operation functions
  PKCS7_stream_func := TPKCS7_stream(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_stream'));
  PKCS7_dataInit := TPKCS7_dataInit(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_dataInit'));
  PKCS7_dataFinal := TPKCS7_dataFinal(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_dataFinal'));
  PKCS7_dataDecode := TPKCS7_dataDecode(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_dataDecode'));
  PKCS7_dataVerify := TPKCS7_dataVerify(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_dataVerify'));
  PKCS7_signatureVerify := TPKCS7_signatureVerify(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_signatureVerify'));

  // Load info functions
  PKCS7_get_signer_info := TPKCS7_get_signer_info(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_get_signer_info'));
  PKCS7_get_recip_info := TPKCS7_get_recip_info(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_get_recip_info'));
  PKCS7_add_recipient_info := TPKCS7_add_recipient_info(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_add_recipient_info'));
  PKCS7_RECIP_INFO_get0_alg := TPKCS7_RECIP_INFO_get0_alg(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_RECIP_INFO_get0_alg'));
  PKCS7_SIGNER_INFO_get0_algs := TPKCS7_SIGNER_INFO_get0_algs(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_SIGNER_INFO_get0_algs'));
  PKCS7_SIGNER_INFO_set := TPKCS7_SIGNER_INFO_set(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_SIGNER_INFO_set'));

  // Load S/MIME capability functions
  PKCS7_add_attrib_smimecap := TPKCS7_add_attrib_smimecap(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_add_attrib_smimecap'));
  PKCS7_simple_smimecap := TPKCS7_simple_smimecap(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_simple_smimecap'));
  PKCS7_add_attrib_content_type := TPKCS7_add_attrib_content_type(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_add_attrib_content_type'));
  PKCS7_add0_attrib_signing_time := TPKCS7_add0_attrib_signing_time(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_add0_attrib_signing_time'));
  PKCS7_add1_attrib_digest := TPKCS7_add1_attrib_digest(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_add1_attrib_digest'));

  // Load I/O functions
  i2d_PKCS7 := Ti2d_PKCS7(TOpenSSLLoader.GetFunction(LHandle, 'i2d_PKCS7'));
  d2i_PKCS7 := Td2i_PKCS7(TOpenSSLLoader.GetFunction(LHandle, 'd2i_PKCS7'));
  i2d_PKCS7_bio := Ti2d_PKCS7_bio(TOpenSSLLoader.GetFunction(LHandle, 'i2d_PKCS7_bio'));
  d2i_PKCS7_bio := Td2i_PKCS7_bio(TOpenSSLLoader.GetFunction(LHandle, 'd2i_PKCS7_bio'));
  PEM_read_bio_PKCS7 := TPEM_read_bio_PKCS7(TOpenSSLLoader.GetFunction(LHandle, 'PEM_read_bio_PKCS7'));
  PEM_write_bio_PKCS7 := TPEM_write_bio_PKCS7(TOpenSSLLoader.GetFunction(LHandle, 'PEM_write_bio_PKCS7'));
  
  // Load SMIME functions
  SMIME_write_PKCS7 := TSMIME_write_PKCS7(TOpenSSLLoader.GetFunction(LHandle, 'SMIME_write_PKCS7'));
  SMIME_read_PKCS7 := TSMIME_read_PKCS7(TOpenSSLLoader.GetFunction(LHandle, 'SMIME_read_PKCS7'));
  SMIME_text := TSMIME_text(TOpenSSLLoader.GetFunction(LHandle, 'SMIME_text'));

  // Load print function
  PKCS7_print_ctx := TPKCS7_print_ctx(TOpenSSLLoader.GetFunction(LHandle, 'PKCS7_print_ctx'));

  Result := Assigned(PKCS7_new) and Assigned(PKCS7_sign) and Assigned(PKCS7_verify);
  TOpenSSLLoader.SetModuleLoaded(osmPKCS7, Result);
end;

procedure UnloadPKCS7Functions;
begin
  // Clear all function pointers
  PKCS7_new := nil;
  PKCS7_free := nil;
  PKCS7_content_new := nil;
  PKCS7_set_type := nil;
  PKCS7_set0_type_other := nil;
  PKCS7_set_content := nil;
  PKCS7_SIGNER_INFO_new := nil;
  PKCS7_SIGNER_INFO_free := nil;
  PKCS7_RECIP_INFO_new := nil;
  PKCS7_RECIP_INFO_free := nil;
  PKCS7_add_signer := nil;
  PKCS7_add_certificate := nil;
  PKCS7_add_crl := nil;
  PKCS7_sign := nil;
  PKCS7_sign_add_signer := nil;
  PKCS7_final := nil;
  PKCS7_verify := nil;
  PKCS7_get0_signers := nil;
  PKCS7_encrypt := nil;
  PKCS7_decrypt := nil;
  PKCS7_add_recipient := nil;
  PKCS7_RECIP_INFO_set := nil;
  PKCS7_set_cipher := nil;
  
  i2d_PKCS7 := nil;
  d2i_PKCS7 := nil;
  i2d_PKCS7_bio := nil;
  d2i_PKCS7_bio := nil;
  PEM_read_bio_PKCS7 := nil;
  PEM_write_bio_PKCS7 := nil;
  
  SMIME_write_PKCS7 := nil;
  SMIME_read_PKCS7 := nil;
  SMIME_text := nil;

  TOpenSSLLoader.SetModuleLoaded(osmPKCS7, False);

  // 注意: 库卸载由 TOpenSSLLoader 自动处理（在 finalization 部分）
end;


// High-level helper function implementations

function SignData(const AData: TBytes; ASignCert: PX509; APrivKey: PEVP_PKEY; 
                  ACACerts: PSTACK_OF_X509; AFlags: Integer): TBytes;
var
  LBioIn, LBioOut: PBIO;
  p7: PPKCS7;
  buf: array[0..4095] of Byte;
  len: Integer;
begin
  Result := nil;

  if not TOpenSSLLoader.IsModuleLoaded(osmPKCS7) then
    raise ESSLException.Create('PKCS7 functions not loaded');
  if not Assigned(BIO_new_mem_buf) or
    not Assigned(BIO_new) or
    not Assigned(BIO_s_mem) or
    not Assigned(BIO_free) or
    not Assigned(BIO_read) then
    Exit;
  
  // Create input BIO from data
  LBioIn := BIO_new_mem_buf(@AData[0], Length(AData));
  if LBioIn = nil then
    raise ESSLException.Create('Failed to create input BIO');
    
  try
    // Sign data
    p7 := PKCS7_sign(ASignCert, APrivKey, ACACerts, LBioIn, AFlags);
    if p7 = nil then
      raise ESSLException.Create('Failed to sign data');
      
    try
      // Create output BIO
      LBioOut := BIO_new(BIO_s_mem());
      if LBioOut = nil then
        raise ESSLException.Create('Failed to create output BIO');
        
      try
        // Write PKCS7 to output BIO
        if i2d_PKCS7_bio(LBioOut, p7) <= 0 then
          raise ESSLException.Create('Failed to write PKCS7');
          
        // Read data from BIO
        SetLength(Result, 0);
        repeat
          len := BIO_read(LBioOut, @buf[0], SizeOf(buf));
          if len > 0 then
          begin
            SetLength(Result, Length(Result) + len);
            Move(buf[0], Result[Length(Result) - len], len);
          end;
        until len <= 0;
      finally
        BIO_free(LBioOut);
      end;
    finally
      PKCS7_free(p7);
    end;
  finally
    BIO_free(LBioIn);
  end;
end;

function VerifySignedData(const ASignedData: TBytes; ACACerts: PSTACK_OF_X509; 
                        AStore: PX509_STORE; out AOutData: TBytes; AFlags: Integer): Boolean;
var
  LBioIn, LBioOut: PBIO;
  p7: PPKCS7;
  buf: array[0..4095] of Byte;
  len: Integer;
begin
  Result := False;
  AOutData := nil;

  if not TOpenSSLLoader.IsModuleLoaded(osmPKCS7) then
    Exit;
  if not Assigned(BIO_new_mem_buf) or
    not Assigned(BIO_new) or
    not Assigned(BIO_s_mem) or
    not Assigned(BIO_free) or
    not Assigned(BIO_read) then
    Exit;
  
  // Create input BIO from signed data
  LBioIn := BIO_new_mem_buf(@ASignedData[0], Length(ASignedData));
  if LBioIn = nil then
    Exit;
    
  try
    // Read PKCS7 from BIO
    p7 := d2i_PKCS7_bio(LBioIn, nil);
    if p7 = nil then
      Exit;
      
    try
      // Create output BIO for verified data
      LBioOut := BIO_new(BIO_s_mem());
      if LBioOut = nil then
        Exit;
        
      try
        // Verify signature
        Result := PKCS7_verify(p7, ACACerts, AStore, nil, LBioOut, AFlags) = 1;
        
        if Result then
        begin
          // Read verified data from BIO
          SetLength(AOutData, 0);
          repeat
            len := BIO_read(LBioOut, @buf[0], SizeOf(buf));
            if len > 0 then
            begin
              SetLength(AOutData, Length(AOutData) + len);
              Move(buf[0], AOutData[Length(AOutData) - len], len);
            end;
          until len <= 0;
        end;
      finally
        BIO_free(LBioOut);
      end;
    finally
      PKCS7_free(p7);
    end;
  finally
    BIO_free(LBioIn);
  end;
end;

function EncryptData(const AData: TBytes; ARecipCerts: PSTACK_OF_X509; 
                    ACipher: PEVP_CIPHER; AFlags: Integer): TBytes;
var
  LBioIn, LBioOut: PBIO;
  p7: PPKCS7;
  buf: array[0..4095] of Byte;
  len: Integer;
begin
  Result := nil;

  if not TOpenSSLLoader.IsModuleLoaded(osmPKCS7) then
    raise ESSLException.Create('PKCS7 functions not loaded');
  if not Assigned(BIO_new_mem_buf) or
    not Assigned(BIO_new) or
    not Assigned(BIO_s_mem) or
    not Assigned(BIO_free) or
    not Assigned(BIO_read) then
    Exit;
  
  // Create input BIO from data
  LBioIn := BIO_new_mem_buf(@AData[0], Length(AData));
  if LBioIn = nil then
    raise ESSLException.Create('Failed to create input BIO');
    
  try
    // Encrypt data
    p7 := PKCS7_encrypt(ARecipCerts, LBioIn, ACipher, AFlags);
    if p7 = nil then
      raise ESSLException.Create('Failed to encrypt data');
      
    try
      // Create output BIO
      LBioOut := BIO_new(BIO_s_mem());
      if LBioOut = nil then
        raise ESSLException.Create('Failed to create output BIO');
        
      try
        // Write PKCS7 to output BIO
        if i2d_PKCS7_bio(LBioOut, p7) <= 0 then
          raise ESSLException.Create('Failed to write PKCS7');
          
        // Read data from BIO
        SetLength(Result, 0);
        repeat
          len := BIO_read(LBioOut, @buf[0], SizeOf(buf));
          if len > 0 then
          begin
            SetLength(Result, Length(Result) + len);
            Move(buf[0], Result[Length(Result) - len], len);
          end;
        until len <= 0;
      finally
        BIO_free(LBioOut);
      end;
    finally
      PKCS7_free(p7);
    end;
  finally
    BIO_free(LBioIn);
  end;
end;

function DecryptData(const AEncryptedData: TBytes; ARecipCert: PX509; 
                    APrivKey: PEVP_PKEY; out AOutData: TBytes; AFlags: Integer): Boolean;
var
  LBioIn, LBioOut: PBIO;
  p7: PPKCS7;
  buf: array[0..4095] of Byte;
  len: Integer;
begin
  Result := False;
  AOutData := nil;

  if not TOpenSSLLoader.IsModuleLoaded(osmPKCS7) then
    Exit;
  if not Assigned(BIO_new_mem_buf) or
    not Assigned(BIO_new) or
    not Assigned(BIO_s_mem) or
    not Assigned(BIO_free) or
    not Assigned(BIO_read) then
    Exit;
  
  // Create input BIO from encrypted data
  LBioIn := BIO_new_mem_buf(@AEncryptedData[0], Length(AEncryptedData));
  if LBioIn = nil then
    Exit;
    
  try
    // Read PKCS7 from BIO
    p7 := d2i_PKCS7_bio(LBioIn, nil);
    if p7 = nil then
      Exit;
      
    try
      // Create output BIO for decrypted data
      LBioOut := BIO_new(BIO_s_mem());
      if LBioOut = nil then
        Exit;
        
      try
        // Decrypt data
        Result := PKCS7_decrypt(p7, APrivKey, ARecipCert, LBioOut, AFlags) = 1;
        
        if Result then
        begin
          // Read decrypted data from BIO
          SetLength(AOutData, 0);
          repeat
            len := BIO_read(LBioOut, @buf[0], SizeOf(buf));
            if len > 0 then
            begin
              SetLength(AOutData, Length(AOutData) + len);
              Move(buf[0], AOutData[Length(AOutData) - len], len);
            end;
          until len <= 0;
        end;
      finally
        BIO_free(LBioOut);
      end;
    finally
      PKCS7_free(p7);
    end;
  finally
    BIO_free(LBioIn);
  end;
end;

initialization
  
finalization
  UnloadPKCS7Functions;
  
end.
