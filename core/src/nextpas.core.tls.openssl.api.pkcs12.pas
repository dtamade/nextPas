unit nextpas.core.tls.openssl.api.pkcs12;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.evp, nextpas.core.tls.openssl.api.x509, nextpas.core.tls.openssl.api.pkcs7, nextpas.core.tls.openssl.api.asn1, nextpas.core.tls.openssl.api.bio,
  nextpas.core.platform.dl;

type
  // PKCS12 结构体
  PPKCS12 = ^PKCS12;
  PKCS12 = record
    // Opaque structure
  end;

  PPKCS12_SAFEBAG = ^PKCS12_SAFEBAG;
  PKCS12_SAFEBAG = record
    // Opaque structure
  end;

  PPKCS12_BAGS = ^PKCS12_BAGS;
  PKCS12_BAGS = record
    // Opaque structure
  end;

  // SafeBag stack
  PSTACK_OF_PKCS12_SAFEBAG = pointer;
  PSTACK_OF_PKCS7 = pointer;
  
  // PKCS12 常量
const
  // Key types
  PKCS12_KEY_ID = 1;
  PKCS12_IV_ID = 2;
  PKCS12_MAC_ID = 3;

  // PBE 算法
  NID_pbe_WithSHA1And128BitRC4 = 144;
  NID_pbe_WithSHA1And40BitRC4 = 145;
  NID_pbe_WithSHA1And3_Key_TripleDES_CBC = 146;
  NID_pbe_WithSHA1And2_Key_TripleDES_CBC = 147;
  NID_pbe_WithSHA1And128BitRC2_CBC = 148;
  NID_pbe_WithSHA1And40BitRC2_CBC = 149;

  // PKCS12 iterations
  PKCS12_DEFAULT_ITER = 2048;
  PKCS12_MAC_KEY_LENGTH = 20;

type
  // 函数类型定义
  TPKCS12_new = function(): PPKCS12; cdecl;
  TPKCS12_free = procedure(p12: PPKCS12); cdecl;
  
  // 创建 PKCS12
  TPKCS12_create = function(pass: PAnsiChar; name: PAnsiChar; pkey: PEVP_PKEY;
    cert: PX509; ca: PSTACK_OF_X509; nid_key, nid_cert, iter, mac_iter,
    keytype: Integer): PPKCS12; cdecl;
    
  // 解析 PKCS12
  TPKCS12_parse = function(p12: PPKCS12; pass: PAnsiChar; 
    var pkey: PEVP_PKEY; var cert: PX509; 
    var ca: PSTACK_OF_X509): Integer; cdecl;
    
  // I/O 函数
  Td2i_PKCS12_bio = function(bp: PBIO; var p12: PPKCS12): PPKCS12; cdecl;
  Ti2d_PKCS12_bio = function(bp: PBIO; p12: PPKCS12): Integer; cdecl;
  Td2i_PKCS12_fp = function(fp: Pointer; var p12: PPKCS12): PPKCS12; cdecl;
  Ti2d_PKCS12_fp = function(fp: Pointer; p12: PPKCS12): Integer; cdecl;
  
  // MAC 函数
  TPKCS12_gen_mac = function(p12: PPKCS12; pass: PAnsiChar; passlen: Integer;
    mac: PByte; var maclen: Cardinal): Integer; cdecl;
  TPKCS12_verify_mac = function(p12: PPKCS12; pass: PAnsiChar; 
    passlen: Integer): Integer; cdecl;
  TPKCS12_set_mac = function(p12: PPKCS12; pass: PAnsiChar; passlen: Integer;
    salt: PByte; saltlen: Integer; iter: Integer; md_type: PEVP_MD): Integer; cdecl;
    
  // SafeBag 函数
  TPKCS12_add_cert = function(var pbags: PSTACK_OF_PKCS12_SAFEBAG; 
    cert: PX509): PPKCS12_SAFEBAG; cdecl;
  TPKCS12_add_key = function(var pbags: PSTACK_OF_PKCS12_SAFEBAG;
    key: PEVP_PKEY; key_usage: Integer; iter: Integer;
    pass: PAnsiChar; passlen: Integer): PPKCS12_SAFEBAG; cdecl;
  TPKCS12_add_safe = function(var psafes: PSTACK_OF_PKCS7; 
    bags: PSTACK_OF_PKCS12_SAFEBAG; safe_nid: Integer; 
    iter: Integer; pass: PAnsiChar): Integer; cdecl;
    
  // Utility 函数
  TPKCS12_add_localkeyid = function(bag: PPKCS12_SAFEBAG; name: PByte;
    namelen: Integer): Integer; cdecl;
  TPKCS12_add_friendlyname_asc = function(bag: PPKCS12_SAFEBAG; 
    name: PAnsiChar; namelen: Integer): Integer; cdecl;
  TPKCS12_add_friendlyname_uni = function(bag: PPKCS12_SAFEBAG;
    name: PByte; namelen: Integer): Integer; cdecl;
    
  // PBE 函数
  TPKCS12_pbe_crypt = function(algor: PX509_ALGOR; pass: PAnsiChar; 
    passlen: Integer; data_in: PByte; datalen: Integer;
    var data_out: PByte; var datalen_out: Integer; en_de: Integer): PByte; cdecl;
  TPKCS12_crypt = function(const pass: PAnsiChar; passlen: Integer; salt: PByte; 
    saltlen: Integer; iter: Integer; const cipher: PEVP_CIPHER; 
    const in_: PByte; inlen: Integer; out_: PPByte; outlen: PInteger; 
    en_de: Integer): Integer; cdecl;
  TPKCS12_key_gen_asc = function(pass: PAnsiChar; passlen: Integer;
    salt: PByte; saltlen: Integer; id: Integer; iter: Integer;
    n: Integer; key_out: PByte; md_type: PEVP_MD): Integer; cdecl;
  TPKCS12_key_gen_uni = function(pass: PByte; passlen: Integer;
    salt: PByte; saltlen: Integer; id: Integer; iter: Integer;
    n: Integer; key_out: PByte; md_type: PEVP_MD): Integer; cdecl;
  TPKCS12_key_gen_utf8 = function(const pass: PAnsiChar; passlen: Integer; salt: PByte; 
    saltlen: Integer; id: Integer; iter: Integer; n: Integer; out_: PByte; 
    const md_type: PEVP_MD): Integer; cdecl;
  TPKCS12_key_gen_utf8_ex = function(const pass: PAnsiChar; passlen: Integer; salt: PByte; 
    saltlen: Integer; id: Integer; iter: Integer; n: Integer; out_: PByte; 
    const md_type: PEVP_MD; ctx: POPENSSL_CTX; const propq: PAnsiChar): Integer; cdecl;

  // SafeBag accessors
  TPKCS12_SAFEBAG_new = function(): PPKCS12_SAFEBAG; cdecl;
  TPKCS12_SAFEBAG_free = procedure(bag: PPKCS12_SAFEBAG); cdecl;
  TPKCS12_SAFEBAG_get_nid = function(bag: PPKCS12_SAFEBAG): Integer; cdecl;
  TPKCS12_SAFEBAG_get_bag_type = function(bag: PPKCS12_SAFEBAG): Pointer; cdecl;
  TPKCS12_SAFEBAG_get0_p8inf = function(bag: PPKCS12_SAFEBAG): PPKCS8_PRIV_KEY_INFO; cdecl;
  TPKCS12_SAFEBAG_get0_pkcs8 = function(bag: PPKCS12_SAFEBAG): PPKCS8_PRIV_KEY_INFO; cdecl;
  TPKCS12_SAFEBAG_get0_certs = function(bag: PPKCS12_SAFEBAG): PSTACK_OF_X509; cdecl;
  TPKCS12_SAFEBAG_get0_safes = function(bag: PPKCS12_SAFEBAG): PSTACK_OF_PKCS12_SAFEBAG; cdecl;
  TPKCS12_SAFEBAG_get1_cert = function(bag: PPKCS12_SAFEBAG): PX509; cdecl;
  TPKCS12_SAFEBAG_get1_crl = function(bag: PPKCS12_SAFEBAG): PX509_CRL; cdecl;
  TPKCS12_get_cert = function(p12: PPKCS12; const pass: PAnsiChar): PX509; cdecl;
  TPKCS12_get_pkey = function(p12: PPKCS12; const pass: PAnsiChar): PEVP_PKEY; cdecl;
  TPKCS12_get_private_key = function(p12: PPKCS12; const pass: PAnsiChar; passlen: Integer): PEVP_PKEY; cdecl;
  TPKCS12_get1_certs = function(p12: PPKCS12; const pass: PAnsiChar): PSTACK_OF_X509; cdecl;
  TPKCS12_keybag = function(pkey: PEVP_PKEY): PPKCS12_SAFEBAG; cdecl;
  TPKCS12_certbag = function(cert: PX509): PPKCS12_SAFEBAG; cdecl;
  TPKCS12_secretbag = function(nid: Integer; data: PByte; len: Integer): PPKCS12_SAFEBAG; cdecl;
  TPKCS12_add_key_bag = function(safes: PSTACK_OF_PKCS12_SAFEBAG; pkey: PEVP_PKEY): Integer; cdecl;
  TPKCS12_add_key_ex = function(safes: PSTACK_OF_PKCS12_SAFEBAG; pkey: PEVP_PKEY; key_usage: Integer; 
    iter: Integer; key_nid: Integer; const pass: PAnsiChar; ctx: POPENSSL_CTX; const propq: PAnsiChar): PPKCS12_SAFEBAG; cdecl;
  
  // PKCS8 函数
  TPKCS8_PRIV_KEY_INFO_new = function(): PPKCS8_PRIV_KEY_INFO; cdecl;
  TPKCS8_PRIV_KEY_INFO_free = procedure(p8: PPKCS8_PRIV_KEY_INFO); cdecl;
  TEVP_PKCS82PKEY = function(p8: PPKCS8_PRIV_KEY_INFO): PEVP_PKEY; cdecl;
  TEVP_PKEY2PKCS8 = function(pkey: PEVP_PKEY): PPKCS8_PRIV_KEY_INFO; cdecl;
  
  // 加密的 PKCS8
  TPKCS8_encrypt = function(pbe_nid: Integer; cipher: PEVP_CIPHER;
    pass: PAnsiChar; passlen: Integer; salt: PByte; saltlen: Integer;
    iter: Integer; p8: PPKCS8_PRIV_KEY_INFO): PX509_SIG; cdecl;
  TPKCS8_decrypt = function(p8: PX509_SIG; pass: PAnsiChar; 
    passlen: Integer): PPKCS8_PRIV_KEY_INFO; cdecl;

var
  // 函数指针
  PKCS12_new: TPKCS12_new = nil;
  PKCS12_free: TPKCS12_free = nil;
  PKCS12_create: TPKCS12_create = nil;
  PKCS12_parse: TPKCS12_parse = nil;
  d2i_PKCS12_bio: Td2i_PKCS12_bio = nil;
  i2d_PKCS12_bio: Ti2d_PKCS12_bio = nil;
  d2i_PKCS12_fp: Td2i_PKCS12_fp = nil;
  i2d_PKCS12_fp: Ti2d_PKCS12_fp = nil;
  PKCS12_gen_mac: TPKCS12_gen_mac = nil;
  PKCS12_verify_mac: TPKCS12_verify_mac = nil;
  PKCS12_set_mac: TPKCS12_set_mac = nil;
  PKCS12_add_cert: TPKCS12_add_cert = nil;
  PKCS12_add_key: TPKCS12_add_key = nil;
  PKCS12_add_safe: TPKCS12_add_safe = nil;
  PKCS12_add_localkeyid: TPKCS12_add_localkeyid = nil;
  PKCS12_add_friendlyname_asc: TPKCS12_add_friendlyname_asc = nil;
  PKCS12_add_friendlyname_uni: TPKCS12_add_friendlyname_uni = nil;
  PKCS12_pbe_crypt: TPKCS12_pbe_crypt = nil;
  PKCS12_crypt: TPKCS12_crypt = nil;
  PKCS12_key_gen_asc: TPKCS12_key_gen_asc = nil;
  PKCS12_key_gen_uni: TPKCS12_key_gen_uni = nil;
  PKCS12_key_gen_utf8: TPKCS12_key_gen_utf8 = nil;
  PKCS12_key_gen_utf8_ex: TPKCS12_key_gen_utf8_ex = nil;
  PKCS12_SAFEBAG_new: TPKCS12_SAFEBAG_new = nil;
  PKCS12_SAFEBAG_free: TPKCS12_SAFEBAG_free = nil;
  PKCS12_SAFEBAG_get_nid: TPKCS12_SAFEBAG_get_nid = nil;
  PKCS12_SAFEBAG_get_bag_type: TPKCS12_SAFEBAG_get_bag_type = nil;
  PKCS12_SAFEBAG_get0_pkcs8: TPKCS12_SAFEBAG_get0_pkcs8 = nil;
  PKCS12_SAFEBAG_get0_certs: TPKCS12_SAFEBAG_get0_certs = nil;
  PKCS12_get_cert: TPKCS12_get_cert = nil;
  PKCS12_get_pkey: TPKCS12_get_pkey = nil;
  PKCS12_get_private_key: TPKCS12_get_private_key = nil;
  PKCS12_get1_certs: TPKCS12_get1_certs = nil;
  PKCS12_keybag: TPKCS12_keybag = nil;
  PKCS12_certbag: TPKCS12_certbag = nil;
  PKCS12_secretbag: TPKCS12_secretbag = nil;
  PKCS12_add_key_bag: TPKCS12_add_key_bag = nil;
  PKCS12_add_key_ex: TPKCS12_add_key_ex = nil;
  PKCS12_SAFEBAG_get0_p8inf: TPKCS12_SAFEBAG_get0_p8inf = nil;
  PKCS12_SAFEBAG_get0_safes: TPKCS12_SAFEBAG_get0_safes = nil;
  PKCS12_SAFEBAG_get1_cert: TPKCS12_SAFEBAG_get1_cert = nil;
  PKCS12_SAFEBAG_get1_crl: TPKCS12_SAFEBAG_get1_crl = nil;
  PKCS8_PRIV_KEY_INFO_new: TPKCS8_PRIV_KEY_INFO_new = nil;
  PKCS8_PRIV_KEY_INFO_free: TPKCS8_PRIV_KEY_INFO_free = nil;
  EVP_PKCS82PKEY: TEVP_PKCS82PKEY = nil;
  EVP_PKEY2PKCS8: TEVP_PKEY2PKCS8 = nil;
  PKCS8_encrypt: TPKCS8_encrypt = nil;
  PKCS8_decrypt: TPKCS8_decrypt = nil;

// 辅助函数
{$IFDEF ENABLE_PKCS12_HELPERS}
function CreatePKCS12(const Password, FriendlyName: string; 
  PrivateKey: PEVP_PKEY; Certificate: PX509; 
  CACerts: PSTACK_OF_X509): PPKCS12;
function ParsePKCS12(P12: PPKCS12; const Password: string;
  out PrivateKey: PEVP_PKEY; out Certificate: PX509;
  out CACerts: PSTACK_OF_X509): Boolean;
function LoadPKCS12FromFile(const FileName, Password: string;
  out PrivateKey: PEVP_PKEY; out Certificate: PX509;
  out CACerts: PSTACK_OF_X509): Boolean;
function SavePKCS12ToFile(const FileName, Password, FriendlyName: string;
  PrivateKey: PEVP_PKEY; Certificate: PX509; 
  CACerts: PSTACK_OF_X509): Boolean;
function LoadPKCS12FromBytes(const Data: TBytes; const Password: string;
  out PrivateKey: PEVP_PKEY; out Certificate: PX509;
  out CACerts: PSTACK_OF_X509): Boolean;
function SavePKCS12ToBytes(const Password, FriendlyName: string;
  PrivateKey: PEVP_PKEY; Certificate: PX509; 
  CACerts: PSTACK_OF_X509): TBytes;
{$ENDIF}

// 模块加载和卸载
procedure LoadPKCS12Module(ALibCrypto: TPlatformLibrary);
procedure UnloadPKCS12Module;

implementation

uses nextpas.core.tls.openssl.api.err, nextpas.core.tls.openssl.loader,

{ PKCS12 函数绑定数组
  runtime storage keeps procvar targets writable across macOS batch-loader runs }
var
  PKCS12_BINDINGS: array[0..47] of TFunctionBinding = (
    // 基本 PKCS12 函数
    (Name: 'PKCS12_new'; FuncPtr: @PKCS12_new; Required: False),
    (Name: 'PKCS12_free'; FuncPtr: @PKCS12_free; Required: False),
    (Name: 'PKCS12_create'; FuncPtr: @PKCS12_create; Required: False),
    (Name: 'PKCS12_parse'; FuncPtr: @PKCS12_parse; Required: False),
    // I/O 函数
    (Name: 'd2i_PKCS12_bio'; FuncPtr: @d2i_PKCS12_bio; Required: False),
    (Name: 'i2d_PKCS12_bio'; FuncPtr: @i2d_PKCS12_bio; Required: False),
    (Name: 'd2i_PKCS12_fp'; FuncPtr: @d2i_PKCS12_fp; Required: False),
    (Name: 'i2d_PKCS12_fp'; FuncPtr: @i2d_PKCS12_fp; Required: False),
    // MAC 函数
    (Name: 'PKCS12_gen_mac'; FuncPtr: @PKCS12_gen_mac; Required: False),
    (Name: 'PKCS12_verify_mac'; FuncPtr: @PKCS12_verify_mac; Required: False),
    (Name: 'PKCS12_set_mac'; FuncPtr: @PKCS12_set_mac; Required: False),
    // SafeBag 函数
    (Name: 'PKCS12_add_cert'; FuncPtr: @PKCS12_add_cert; Required: False),
    (Name: 'PKCS12_add_key'; FuncPtr: @PKCS12_add_key; Required: False),
    (Name: 'PKCS12_add_safe'; FuncPtr: @PKCS12_add_safe; Required: False),
    // Utility 函数
    (Name: 'PKCS12_add_localkeyid'; FuncPtr: @PKCS12_add_localkeyid; Required: False),
    (Name: 'PKCS12_add_friendlyname_asc'; FuncPtr: @PKCS12_add_friendlyname_asc; Required: False),
    (Name: 'PKCS12_add_friendlyname_uni'; FuncPtr: @PKCS12_add_friendlyname_uni; Required: False),
    // PBE 函数
    (Name: 'PKCS12_pbe_crypt'; FuncPtr: @PKCS12_pbe_crypt; Required: False),
    (Name: 'PKCS12_crypt'; FuncPtr: @PKCS12_crypt; Required: False),
    (Name: 'PKCS12_key_gen_asc'; FuncPtr: @PKCS12_key_gen_asc; Required: False),
    (Name: 'PKCS12_key_gen_uni'; FuncPtr: @PKCS12_key_gen_uni; Required: False),
    (Name: 'PKCS12_key_gen_utf8'; FuncPtr: @PKCS12_key_gen_utf8; Required: False),
    (Name: 'PKCS12_key_gen_utf8_ex'; FuncPtr: @PKCS12_key_gen_utf8_ex; Required: False),
    // SafeBag accessors
    (Name: 'PKCS12_SAFEBAG_new'; FuncPtr: @PKCS12_SAFEBAG_new; Required: False),
    (Name: 'PKCS12_SAFEBAG_free'; FuncPtr: @PKCS12_SAFEBAG_free; Required: False),
    (Name: 'PKCS12_SAFEBAG_get_nid'; FuncPtr: @PKCS12_SAFEBAG_get_nid; Required: False),
    (Name: 'PKCS12_SAFEBAG_get_bag_type'; FuncPtr: @PKCS12_SAFEBAG_get_bag_type; Required: False),
    (Name: 'PKCS12_SAFEBAG_get0_p8inf'; FuncPtr: @PKCS12_SAFEBAG_get0_p8inf; Required: False),
    (Name: 'PKCS12_SAFEBAG_get0_pkcs8'; FuncPtr: @PKCS12_SAFEBAG_get0_pkcs8; Required: False),
    (Name: 'PKCS12_SAFEBAG_get0_certs'; FuncPtr: @PKCS12_SAFEBAG_get0_certs; Required: False),
    (Name: 'PKCS12_SAFEBAG_get0_safes'; FuncPtr: @PKCS12_SAFEBAG_get0_safes; Required: False),
    (Name: 'PKCS12_SAFEBAG_get1_cert'; FuncPtr: @PKCS12_SAFEBAG_get1_cert; Required: False),
    (Name: 'PKCS12_SAFEBAG_get1_crl'; FuncPtr: @PKCS12_SAFEBAG_get1_crl; Required: False),
    // PKCS12 getter 函数
    (Name: 'PKCS12_get_cert'; FuncPtr: @PKCS12_get_cert; Required: False),
    (Name: 'PKCS12_get_pkey'; FuncPtr: @PKCS12_get_pkey; Required: False),
    (Name: 'PKCS12_get_private_key'; FuncPtr: @PKCS12_get_private_key; Required: False),
    (Name: 'PKCS12_get1_certs'; FuncPtr: @PKCS12_get1_certs; Required: False),
    // PKCS12 bag 创建函数
    (Name: 'PKCS12_keybag'; FuncPtr: @PKCS12_keybag; Required: False),
    (Name: 'PKCS12_certbag'; FuncPtr: @PKCS12_certbag; Required: False),
    (Name: 'PKCS12_secretbag'; FuncPtr: @PKCS12_secretbag; Required: False),
    (Name: 'PKCS12_add_key_bag'; FuncPtr: @PKCS12_add_key_bag; Required: False),
    (Name: 'PKCS12_add_key_ex'; FuncPtr: @PKCS12_add_key_ex; Required: False),
    // PKCS8 函数
    (Name: 'PKCS8_PRIV_KEY_INFO_new'; FuncPtr: @PKCS8_PRIV_KEY_INFO_new; Required: False),
    (Name: 'PKCS8_PRIV_KEY_INFO_free'; FuncPtr: @PKCS8_PRIV_KEY_INFO_free; Required: False),
    (Name: 'EVP_PKCS82PKEY'; FuncPtr: @EVP_PKCS82PKEY; Required: False),
    (Name: 'EVP_PKEY2PKCS8'; FuncPtr: @EVP_PKEY2PKCS8; Required: False),
    (Name: 'PKCS8_encrypt'; FuncPtr: @PKCS8_encrypt; Required: False),
    (Name: 'PKCS8_decrypt'; FuncPtr: @PKCS8_decrypt; Required: False)
  );

procedure LoadPKCS12Module(ALibCrypto: TPlatformLibrary);
var
  LLoaded: Boolean;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmPKCS12) then
    Exit;

  if not LibLoaded(ALibCrypto) then Exit;

  // 使用批量加载模式
  TOpenSSLLoader.LoadFunctions(ALibCrypto, PKCS12_BINDINGS);

  LLoaded := Assigned(PKCS12_new) or
    Assigned(PKCS12_create) or
    Assigned(PKCS12_parse) or
    Assigned(PKCS8_encrypt) or
    Assigned(PKCS8_decrypt);
  TOpenSSLLoader.SetModuleLoaded(osmPKCS12, LLoaded);
end;

procedure UnloadPKCS12Module;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmPKCS12) then
    Exit;

  // 使用批量清除模式
  TOpenSSLLoader.ClearFunctions(PKCS12_BINDINGS);
  TOpenSSLLoader.SetModuleLoaded(osmPKCS12, False);
end;

// 辅助函数实现
{$IFDEF ENABLE_PKCS12_HELPERS}
function CreatePKCS12(const Password, FriendlyName: string;
  PrivateKey: PEVP_PKEY; Certificate: PX509; 
  CACerts: PSTACK_OF_X509): PPKCS12;
var
  PassBytes: TBytes;
  NameBytes: TBytes;
begin
  Result := nil;
  if not Assigned(PKCS12_create) then Exit;
  
  PassBytes := nextpas.core.text.conv.StringToUTF8Bytes(Password);
  if FriendlyName <> '' then
    NameBytes := nextpas.core.text.conv.StringToUTF8Bytes(FriendlyName)
  else
    SetLength(NameBytes, 0);
  
  Result := PKCS12_create(
    PAnsiChar(PassBytes),
    PAnsiChar(NameBytes),
    PrivateKey,
    Certificate,
    CACerts,
    0, 0,  // 使用默认的 NID
    PKCS12_DEFAULT_ITER,
    PKCS12_DEFAULT_ITER,
    0  // 默认 key type
  );
end;

function ParsePKCS12(P12: PPKCS12; const Password: string;
  out PrivateKey: PEVP_PKEY; out Certificate: PX509;
  out CACerts: PSTACK_OF_X509): Boolean;
var
  PassBytes: TBytes;
begin
  Result := False;
  PrivateKey := nil;
  Certificate := nil;
  CACerts := nil;
  
  if not Assigned(PKCS12_parse) or not Assigned(P12) then Exit;
  
  PassBytes := nextpas.core.text.conv.StringToUTF8Bytes(Password);
  Result := PKCS12_parse(P12, PAnsiChar(PassBytes), 
    PrivateKey, Certificate, CACerts) = 1;
end;

function LoadPKCS12FromFile(const FileName, Password: string;
  out PrivateKey: PEVP_PKEY; out Certificate: PX509;
  out CACerts: PSTACK_OF_X509): Boolean;
var
  Bio: PBIO;
  P12: PPKCS12;
  FileNameBytes: TBytes;
begin
  Result := False;
  PrivateKey := nil;
  Certificate := nil;
  CACerts := nil;
  
  if not Assigned(d2i_PKCS12_bio) or not Assigned(BIO_new_file) then Exit;
  
  FileNameBytes := nextpas.core.text.conv.StringToUTF8Bytes(FileName);
  Bio := BIO_new_file(PAnsiChar(FileNameBytes), 'rb');
  if not Assigned(Bio) then Exit;
  
  try
    P12 := nil;
    P12 := d2i_PKCS12_bio(Bio, P12);
    if Assigned(P12) then
    begin
      try
        Result := ParsePKCS12(P12, Password, PrivateKey, Certificate, CACerts);
      finally
        if Assigned(PKCS12_free) then
          PKCS12_free(P12);
      end;
    end;
  finally
    if Assigned(BIO_free) then
      BIO_free(Bio);
  end;
end;

function SavePKCS12ToFile(const FileName, Password, FriendlyName: string;
  PrivateKey: PEVP_PKEY; Certificate: PX509; 
  CACerts: PSTACK_OF_X509): Boolean;
var
  Bio: PBIO;
  P12: PPKCS12;
  FileNameBytes: TBytes;
begin
  Result := False;
  
  if not Assigned(i2d_PKCS12_bio) or not Assigned(BIO_new_file) then Exit;
  
  P12 := CreatePKCS12(Password, FriendlyName, PrivateKey, Certificate, CACerts);
  if not Assigned(P12) then Exit;
  
  try
    FileNameBytes := nextpas.core.text.conv.StringToUTF8Bytes(FileName);
    Bio := BIO_new_file(PAnsiChar(FileNameBytes), 'wb');
    if not Assigned(Bio) then Exit;
    
    try
      Result := i2d_PKCS12_bio(Bio, P12) = 1;
    finally
      if Assigned(BIO_free) then
        BIO_free(Bio);
    end;
  finally
    if Assigned(PKCS12_free) then
      PKCS12_free(P12);
  end;
end;

function LoadPKCS12FromBytes(const Data: TBytes; const Password: string;
  out PrivateKey: PEVP_PKEY; out Certificate: PX509;
  out CACerts: PSTACK_OF_X509): Boolean;
var
  Bio: PBIO;
  P12: PPKCS12;
begin
  Result := False;
  PrivateKey := nil;
  Certificate := nil;
  CACerts := nil;
  
  if not Assigned(d2i_PKCS12_bio) or not Assigned(BIO_new_mem_buf) then Exit;
  if Length(Data) = 0 then Exit;
  
  Bio := BIO_new_mem_buf(@Data[0], Length(Data));
  if not Assigned(Bio) then Exit;
  
  try
    P12 := nil;
    P12 := d2i_PKCS12_bio(Bio, P12);
    if Assigned(P12) then
    begin
      try
        Result := ParsePKCS12(P12, Password, PrivateKey, Certificate, CACerts);
      finally
        if Assigned(PKCS12_free) then
          PKCS12_free(P12);
      end;
    end;
  finally
    if Assigned(BIO_free) then
      BIO_free(Bio);
  end;
end;

function SavePKCS12ToBytes(const Password, FriendlyName: string;
  PrivateKey: PEVP_PKEY; Certificate: PX509; 
  CACerts: PSTACK_OF_X509): TBytes;
var
  Bio: PBIO;
  P12: PPKCS12;
  DataPtr: PAnsiChar;
  DataLen: Integer;
begin
  SetLength(Result, 0);
  
  if not Assigned(i2d_PKCS12_bio) or not Assigned(BIO_new) or 
    not Assigned(BIO_s_mem) then Exit;
  
  P12 := CreatePKCS12(Password, FriendlyName, PrivateKey, Certificate, CACerts);
  if not Assigned(P12) then Exit;
  
  try
    Bio := BIO_new(BIO_s_mem());
    if not Assigned(Bio) then Exit;
    
    try
      if i2d_PKCS12_bio(Bio, P12) = 1 then
      begin
        DataLen := BIO_get_mem_data(Bio, @DataPtr);
        if (DataLen > 0) and Assigned(DataPtr) then
        begin
          SetLength(Result, DataLen);
          Move(DataPtr^, Result[0], DataLen);
        end;
      end;
    finally
      if Assigned(BIO_free) then
        BIO_free(Bio);
    end;
  finally
    if Assigned(PKCS12_free) then
      PKCS12_free(P12);
  end;
end;
{$ENDIF}

end.
