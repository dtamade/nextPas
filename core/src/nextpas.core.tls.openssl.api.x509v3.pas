unit nextpas.core.tls.openssl.api.x509v3;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, DynLibs, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.consts;

type
  // Forward declarations for missing types
  PASN1_ITEM = Pointer;
  
  // Double pointer types
  PPBASIC_CONSTRAINTS = ^PBASIC_CONSTRAINTS;
  PPAUTHORITY_KEYID = ^PAUTHORITY_KEYID;
  
  // X509V3 types
  PX509V3_CTX = ^X509V3_CTX;
  X509V3_CTX = record
    flags: Integer;
    issuer_cert: PX509;
    subject_cert: PX509;
    subject_req: PX509_REQ;
    crl: PX509_CRL;
    db_meth: Pointer;
    db: Pointer;
    issuer_pkey: PEVP_PKEY;
  end;
  
  PX509_EXTENSION_METHOD = ^X509_EXTENSION_METHOD;
  X509_EXTENSION_METHOD = record
    ext_nid: Integer;
    ext_flags: Integer;
    it: PASN1_ITEM;
    ext_new: Pointer;
    ext_free: Pointer;
    d2i: Pointer;
    i2d: Pointer;
    i2s: Pointer;
    s2i: Pointer;
    i2v: Pointer;
    v2i: Pointer;
    i2r: Pointer;
    r2i: Pointer;
    usr_data: Pointer;
  end;
  
  PAUTHORITY_INFO_ACCESS = ^AUTHORITY_INFO_ACCESS;
  AUTHORITY_INFO_ACCESS = record
    method: PASN1_OBJECT;
    location: Pointer; // GENERAL_NAME
  end;
  
  PAUTHORITY_KEYID = ^AUTHORITY_KEYID;
  AUTHORITY_KEYID = record
    keyid: PASN1_OCTET_STRING;
    issuer: Pointer; // GENERAL_NAMES
    serial: PASN1_INTEGER;
  end;
  
  PBASIC_CONSTRAINTS = ^BASIC_CONSTRAINTS;
  BASIC_CONSTRAINTS = record
    ca: Integer;
    pathlen: PASN1_INTEGER;
  end;

  // GENERAL_NAME helpers
  TGENERAL_NAME_get0_value = function(const gen: PGENERAL_NAME; ptype: PInteger): Pointer; cdecl;
  TGENERAL_NAMES_free = procedure(names: PGENERAL_NAMES); cdecl;

const
  // X509V3 extension flags
  X509V3_EXT_DYNAMIC      = $1;
  X509V3_EXT_CTX_DEP      = $2;
  X509V3_EXT_MULTILINE    = $4;
  
  // X509V3 context flags
  X509V3_CTX_TEST         = $1;
  X509V3_CTX_REPLACE      = $2;
  
  // Key usage bits
  KU_DIGITAL_SIGNATURE    = $0080;
  KU_NON_REPUDIATION      = $0040;
  KU_KEY_ENCIPHERMENT     = $0020;
  KU_DATA_ENCIPHERMENT    = $0010;
  KU_KEY_AGREEMENT        = $0008;
  KU_KEY_CERT_SIGN        = $0004;
  KU_CRL_SIGN             = $0002;
  KU_ENCIPHER_ONLY        = $0001;
  KU_DECIPHER_ONLY        = $8000;
  
  // Extended key usage
  XKU_SSL_SERVER          = $1;
  XKU_SSL_CLIENT          = $2;
  XKU_SMIME               = $4;
  XKU_CODE_SIGN           = $8;
  XKU_SGC                 = $10;
  XKU_OCSP_SIGN           = $20;
  XKU_TIMESTAMP           = $40;
  XKU_DVCS                = $80;
  XKU_ANYEKU              = $100;

var
  // X509V3 context functions
  X509V3_set_ctx: procedure(ctx: PX509V3_CTX; issuer: PX509; subject: PX509;
    req: PX509_REQ; crl: PX509_CRL; flags: Integer); cdecl = nil;
  X509V3_set_ctx_test: procedure(ctx: PX509V3_CTX); cdecl = nil;
  X509V3_set_ctx_nodb: procedure(ctx: PX509V3_CTX); cdecl = nil;
  
  // Extension creation functions
  X509V3_EXT_conf: function(conf: Pointer; ctx: PX509V3_CTX; 
    const name: PAnsiChar; const value: PAnsiChar): PX509_EXTENSION; cdecl = nil;
  X509V3_EXT_conf_nid: function(conf: Pointer; ctx: PX509V3_CTX; 
    ext_nid: Integer; const value: PAnsiChar): PX509_EXTENSION; cdecl = nil;
  X509V3_EXT_nconf: function(conf: Pointer; ctx: PX509V3_CTX; 
    const name: PAnsiChar; const value: PAnsiChar): PX509_EXTENSION; cdecl = nil;
  X509V3_EXT_nconf_nid: function(conf: Pointer; ctx: PX509V3_CTX; 
    ext_nid: Integer; const value: PAnsiChar): PX509_EXTENSION; cdecl = nil;
  
  // Extension add functions
  X509V3_EXT_add_conf: function(conf: Pointer; ctx: PX509V3_CTX;
    const section: PAnsiChar; cert: PX509): Integer; cdecl = nil;
  X509V3_EXT_add_nconf: function(conf: Pointer; ctx: PX509V3_CTX;
    const section: PAnsiChar; cert: PX509): Integer; cdecl = nil;
  X509V3_EXT_CRL_add_conf: function(conf: Pointer; ctx: PX509V3_CTX;
    const section: PAnsiChar; crl: PX509_CRL): Integer; cdecl = nil;
  X509V3_EXT_CRL_add_nconf: function(conf: Pointer; ctx: PX509V3_CTX;
    const section: PAnsiChar; crl: PX509_CRL): Integer; cdecl = nil;
  X509V3_EXT_REQ_add_conf: function(conf: Pointer; ctx: PX509V3_CTX;
    const section: PAnsiChar; req: PX509_REQ): Integer; cdecl = nil;
  X509V3_EXT_REQ_add_nconf: function(conf: Pointer; ctx: PX509V3_CTX;
    const section: PAnsiChar; req: PX509_REQ): Integer; cdecl = nil;
  
  // Extension print functions
  X509V3_EXT_print: function(output: PBIO; ext: PX509_EXTENSION; 
    flag: LongWord; indent: Integer): Integer; cdecl = nil;
  X509V3_EXT_print_fp: function(output: Pointer; ext: PX509_EXTENSION; 
    flag: Integer; indent: Integer): Integer; cdecl = nil;
  X509V3_extensions_print: function(output: PBIO; const title: PAnsiChar;
    exts: Pointer; flag: LongWord; indent: Integer): Integer; cdecl = nil;
  
  // Extension get/add functions
  X509V3_EXT_get: function(ext: PX509_EXTENSION): PX509_EXTENSION_METHOD; cdecl = nil;
  X509V3_EXT_get_nid: function(nid: Integer): PX509_EXTENSION_METHOD; cdecl = nil;
  X509V3_EXT_add: function(ext: PX509_EXTENSION_METHOD): Integer; cdecl = nil;
  X509V3_EXT_add_alias: function(nid_to: Integer; nid_from: Integer): Integer; cdecl = nil;
  X509V3_EXT_cleanup: procedure(); cdecl = nil;
  
  // Extension data functions
  X509V3_EXT_d2i: function(ext: PX509_EXTENSION): Pointer; cdecl = nil;
  X509V3_EXT_i2d: function(ext_nid: Integer; crit: Integer; 
    ext_struc: Pointer): PX509_EXTENSION; cdecl = nil;
  X509V3_add1_i2d: function(x: PPX509_EXTENSION; nid: Integer; value: Pointer; 
    crit: Integer; flags: LongWord): Integer; cdecl = nil;
  X509V3_get_d2i: function(const x: Pointer; nid: Integer; 
    var crit: Integer; var idx: Integer): Pointer; cdecl = nil;
  GENERAL_NAME_get0_value: TGENERAL_NAME_get0_value = nil;
  GENERAL_NAMES_free: TGENERAL_NAMES_free = nil;
    
  // Specific extension functions
  BASIC_CONSTRAINTS_new: function(): PBASIC_CONSTRAINTS; cdecl = nil;
  BASIC_CONSTRAINTS_free: procedure(a: PBASIC_CONSTRAINTS); cdecl = nil;
  d2i_BASIC_CONSTRAINTS: function(a: PPBASIC_CONSTRAINTS; 
    const input: PPByte; len: LongInt): PBASIC_CONSTRAINTS; cdecl = nil;
  i2d_BASIC_CONSTRAINTS: function(a: PBASIC_CONSTRAINTS; 
    output: PPByte): Integer; cdecl = nil;
    
  AUTHORITY_KEYID_new: function(): PAUTHORITY_KEYID; cdecl = nil;
  AUTHORITY_KEYID_free: procedure(a: PAUTHORITY_KEYID); cdecl = nil;
  d2i_AUTHORITY_KEYID: function(a: PPAUTHORITY_KEYID; 
    const input: PPByte; len: LongInt): PAUTHORITY_KEYID; cdecl = nil;
  i2d_AUTHORITY_KEYID: function(a: PAUTHORITY_KEYID; 
    output: PPByte): Integer; cdecl = nil;
    
  AUTHORITY_INFO_ACCESS_new: function(): PAUTHORITY_INFO_ACCESS; cdecl = nil;
  AUTHORITY_INFO_ACCESS_free: procedure(a: PAUTHORITY_INFO_ACCESS); cdecl = nil;
  
  // Name constraint functions
  NAME_CONSTRAINTS_check: function(x: PX509; nc: Pointer): Integer; cdecl = nil;
  NAME_CONSTRAINTS_check_CN: function(x: PX509; nc: Pointer): Integer; cdecl = nil;
  
  // Policy functions
  X509_policy_check: function(ptree: Pointer; pexplicit_policy: PInteger;
    certs: Pointer; policy_oids: Pointer; flags: Cardinal): Integer; cdecl = nil;
  X509_policy_tree_free: procedure(tree: Pointer); cdecl = nil;
  X509_policy_tree_level_count: function(const tree: Pointer): Integer; cdecl = nil;
  X509_policy_tree_get0_level: function(const tree: Pointer; 
    i: Integer): Pointer; cdecl = nil;
    
  // Purpose functions
  X509_check_purpose: function(x: PX509; id: Integer; ca: Integer): Integer; cdecl = nil;

procedure LoadX509V3Functions(AHandle: TLibHandle);
procedure UnloadX509V3Functions;

// Helper functions
function X509AddBasicConstraints(Cert: PX509; CA: Boolean; PathLen: Integer = -1): Boolean;
function X509AddKeyUsage(Cert: PX509; Usage: Cardinal): Boolean;
function X509AddExtKeyUsage(Cert: PX509; const Usage: string): Boolean;
function X509AddSubjectAltName(Cert: PX509; const DNS: string): Boolean;

implementation

uses
  nextpas.core.tls.openssl.api.utils, nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core, nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.x509;

const
  { X509V3 函数绑定数组 - 用于批量加载 }
  X509V3_FUNCTION_COUNT = 44;

var
  X509V3FunctionBindings: array[0..X509V3_FUNCTION_COUNT - 1] of TFunctionBinding = (
    // Context functions
    (Name: 'X509V3_set_ctx';              FuncPtr: @X509V3_set_ctx;              Required: False),
    (Name: 'X509V3_set_ctx_test';         FuncPtr: @X509V3_set_ctx_test;         Required: False),
    (Name: 'X509V3_set_ctx_nodb';         FuncPtr: @X509V3_set_ctx_nodb;         Required: False),
    // Extension creation functions
    (Name: 'X509V3_EXT_conf';             FuncPtr: @X509V3_EXT_conf;             Required: False),
    (Name: 'X509V3_EXT_conf_nid';         FuncPtr: @X509V3_EXT_conf_nid;         Required: False),
    (Name: 'X509V3_EXT_nconf';            FuncPtr: @X509V3_EXT_nconf;            Required: False),
    (Name: 'X509V3_EXT_nconf_nid';        FuncPtr: @X509V3_EXT_nconf_nid;        Required: False),
    // Extension add functions
    (Name: 'X509V3_EXT_add_conf';         FuncPtr: @X509V3_EXT_add_conf;         Required: False),
    (Name: 'X509V3_EXT_add_nconf';        FuncPtr: @X509V3_EXT_add_nconf;        Required: False),
    (Name: 'X509V3_EXT_CRL_add_conf';     FuncPtr: @X509V3_EXT_CRL_add_conf;     Required: False),
    (Name: 'X509V3_EXT_CRL_add_nconf';    FuncPtr: @X509V3_EXT_CRL_add_nconf;    Required: False),
    (Name: 'X509V3_EXT_REQ_add_conf';     FuncPtr: @X509V3_EXT_REQ_add_conf;     Required: False),
    (Name: 'X509V3_EXT_REQ_add_nconf';    FuncPtr: @X509V3_EXT_REQ_add_nconf;    Required: False),
    // Extension print functions
    (Name: 'X509V3_EXT_print';            FuncPtr: @X509V3_EXT_print;            Required: False),
    (Name: 'X509V3_EXT_print_fp';         FuncPtr: @X509V3_EXT_print_fp;         Required: False),
    (Name: 'X509V3_extensions_print';     FuncPtr: @X509V3_extensions_print;     Required: False),
    // Extension get/add functions
    (Name: 'X509V3_EXT_get';              FuncPtr: @X509V3_EXT_get;              Required: False),
    (Name: 'X509V3_EXT_get_nid';          FuncPtr: @X509V3_EXT_get_nid;          Required: False),
    (Name: 'X509V3_EXT_add';              FuncPtr: @X509V3_EXT_add;              Required: False),
    (Name: 'X509V3_EXT_add_alias';        FuncPtr: @X509V3_EXT_add_alias;        Required: False),
    (Name: 'X509V3_EXT_cleanup';          FuncPtr: @X509V3_EXT_cleanup;          Required: False),
    // Extension data functions
    (Name: 'X509V3_EXT_d2i';              FuncPtr: @X509V3_EXT_d2i;              Required: False),
    (Name: 'X509V3_EXT_i2d';              FuncPtr: @X509V3_EXT_i2d;              Required: False),
    (Name: 'X509V3_add1_i2d';             FuncPtr: @X509V3_add1_i2d;             Required: False),
    (Name: 'X509V3_get_d2i';              FuncPtr: @X509V3_get_d2i;              Required: False),
    (Name: 'GENERAL_NAME_get0_value';     FuncPtr: @GENERAL_NAME_get0_value;     Required: False),
    (Name: 'GENERAL_NAMES_free';          FuncPtr: @GENERAL_NAMES_free;          Required: False),
    // Basic constraints functions
    (Name: 'BASIC_CONSTRAINTS_new';       FuncPtr: @BASIC_CONSTRAINTS_new;       Required: False),
    (Name: 'BASIC_CONSTRAINTS_free';      FuncPtr: @BASIC_CONSTRAINTS_free;      Required: False),
    (Name: 'd2i_BASIC_CONSTRAINTS';       FuncPtr: @d2i_BASIC_CONSTRAINTS;       Required: False),
    (Name: 'i2d_BASIC_CONSTRAINTS';       FuncPtr: @i2d_BASIC_CONSTRAINTS;       Required: False),
    // Authority key ID functions
    (Name: 'AUTHORITY_KEYID_new';         FuncPtr: @AUTHORITY_KEYID_new;         Required: False),
    (Name: 'AUTHORITY_KEYID_free';        FuncPtr: @AUTHORITY_KEYID_free;        Required: False),
    (Name: 'd2i_AUTHORITY_KEYID';         FuncPtr: @d2i_AUTHORITY_KEYID;         Required: False),
    (Name: 'i2d_AUTHORITY_KEYID';         FuncPtr: @i2d_AUTHORITY_KEYID;         Required: False),
    // Authority info access functions
    (Name: 'AUTHORITY_INFO_ACCESS_new';   FuncPtr: @AUTHORITY_INFO_ACCESS_new;   Required: False),
    (Name: 'AUTHORITY_INFO_ACCESS_free';  FuncPtr: @AUTHORITY_INFO_ACCESS_free;  Required: False),
    // Name constraint functions
    (Name: 'NAME_CONSTRAINTS_check';      FuncPtr: @NAME_CONSTRAINTS_check;      Required: False),
    (Name: 'NAME_CONSTRAINTS_check_CN';   FuncPtr: @NAME_CONSTRAINTS_check_CN;   Required: False),
    // Policy functions
    (Name: 'X509_policy_check';           FuncPtr: @X509_policy_check;           Required: False),
    (Name: 'X509_policy_tree_free';       FuncPtr: @X509_policy_tree_free;       Required: False),
    (Name: 'X509_policy_tree_level_count'; FuncPtr: @X509_policy_tree_level_count; Required: False),
    (Name: 'X509_policy_tree_get0_level'; FuncPtr: @X509_policy_tree_get0_level; Required: False),
    // Purpose functions
    (Name: 'X509_check_purpose';          FuncPtr: @X509_check_purpose;          Required: False)
  );

procedure LoadX509V3Functions(AHandle: TLibHandle);
begin
  if AHandle = 0 then Exit;

  TOpenSSLLoader.LoadFunctions(AHandle, X509V3FunctionBindings);
end;

procedure UnloadX509V3Functions;
begin
  TOpenSSLLoader.ClearFunctions(X509V3FunctionBindings);
end;

function X509AddBasicConstraints(Cert: PX509; CA: Boolean; PathLen: Integer): Boolean;
var
  LBasicConstraints: PBASIC_CONSTRAINTS;
  LExt: PX509_EXTENSION;
  LPathLenValue: ASN1_INTEGER;
begin
  Result := False;

  if Cert = nil then
    Exit;

  if (not Assigned(X509_add_ext)) or (not Assigned(X509_EXTENSION_free)) then
    LoadOpenSSLX509();

  if (not Assigned(BASIC_CONSTRAINTS_new)) or
    (not Assigned(BASIC_CONSTRAINTS_free)) or
    (not Assigned(X509V3_EXT_i2d)) or
    (not Assigned(X509_add_ext)) or
    (not Assigned(X509_EXTENSION_free)) then
    Exit;

  LBasicConstraints := BASIC_CONSTRAINTS_new();
  if LBasicConstraints = nil then
    Exit;

  try
    if CA then
      LBasicConstraints^.ca := $FF
    else
      LBasicConstraints^.ca := 0;

    LBasicConstraints^.pathlen := nil;

    if PathLen >= 0 then
    begin
      if (not Assigned(ASN1_INTEGER_new)) or
        (not Assigned(ASN1_INTEGER_set)) then
        LoadOpenSSLASN1(GetCryptoLibHandle);

      if (not Assigned(ASN1_INTEGER_new)) or
        (not Assigned(ASN1_INTEGER_set)) then
        Exit;

      LPathLenValue := ASN1_INTEGER_new();
      if LPathLenValue = nil then
        Exit;

      if ASN1_INTEGER_set(LPathLenValue, PathLen) <> 1 then
      begin
        if Assigned(ASN1_INTEGER_free) then
          ASN1_INTEGER_free(LPathLenValue);
        Exit;
      end;

      LBasicConstraints^.pathlen := PASN1_INTEGER(LPathLenValue);
    end;

    LExt := X509V3_EXT_i2d(NID_basic_constraints, 1, LBasicConstraints);
    if LExt = nil then
      Exit;

    try
      Result := (X509_add_ext(Cert, LExt, -1) = 1);
    finally
      X509_EXTENSION_free(LExt);
    end;
  finally
    BASIC_CONSTRAINTS_free(LBasicConstraints);
  end;
end;

function X509AddKeyUsage(Cert: PX509; Usage: Cardinal): Boolean;
var
  LExt: PX509_EXTENSION;
  LUsageValue: AnsiString;

  procedure AppendUsageName(const AName: AnsiString);
  begin
    if LUsageValue <> '' then
      LUsageValue := LUsageValue + ',';
    LUsageValue := LUsageValue + AName;
  end;

begin
  Result := False;

  if (Cert = nil) or (Usage = 0) then
    Exit;

  if (not Assigned(X509_add_ext)) or (not Assigned(X509_EXTENSION_free)) then
    LoadOpenSSLX509();

  if (not Assigned(X509V3_EXT_conf_nid)) or
    (not Assigned(X509_add_ext)) or
    (not Assigned(X509_EXTENSION_free)) then
    Exit;

  LUsageValue := '';
  if (Usage and KU_DIGITAL_SIGNATURE) <> 0 then
    AppendUsageName('digitalSignature');
  if (Usage and KU_NON_REPUDIATION) <> 0 then
    AppendUsageName('nonRepudiation');
  if (Usage and KU_KEY_ENCIPHERMENT) <> 0 then
    AppendUsageName('keyEncipherment');
  if (Usage and KU_DATA_ENCIPHERMENT) <> 0 then
    AppendUsageName('dataEncipherment');
  if (Usage and KU_KEY_AGREEMENT) <> 0 then
    AppendUsageName('keyAgreement');
  if (Usage and KU_KEY_CERT_SIGN) <> 0 then
    AppendUsageName('keyCertSign');
  if (Usage and KU_CRL_SIGN) <> 0 then
    AppendUsageName('cRLSign');
  if (Usage and KU_ENCIPHER_ONLY) <> 0 then
    AppendUsageName('encipherOnly');
  if (Usage and KU_DECIPHER_ONLY) <> 0 then
    AppendUsageName('decipherOnly');

  if LUsageValue = '' then
    Exit;

  LUsageValue := 'critical,' + LUsageValue;

  LExt := X509V3_EXT_conf_nid(nil, nil, NID_key_usage, PAnsiChar(LUsageValue));
  if LExt = nil then
    Exit;

  try
    Result := (X509_add_ext(Cert, LExt, -1) = 1);
  finally
    X509_EXTENSION_free(LExt);
  end;
end;

function X509AddExtKeyUsage(Cert: PX509; const Usage: string): Boolean;
var
  LExt: PX509_EXTENSION;
  LUsageValue: AnsiString;
begin
  Result := False;

  if Cert = nil then
    Exit;

  LUsageValue := Trim(Usage);
  if LUsageValue = '' then
    Exit;

  if (not Assigned(X509_add_ext)) or (not Assigned(X509_EXTENSION_free)) then
    LoadOpenSSLX509();

  if (not Assigned(X509V3_EXT_conf_nid)) or
    (not Assigned(X509_add_ext)) or
    (not Assigned(X509_EXTENSION_free)) then
    Exit;

  LExt := X509V3_EXT_conf_nid(nil, nil, NID_ext_key_usage, PAnsiChar(LUsageValue));
  if LExt = nil then
    Exit;

  try
    Result := (X509_add_ext(Cert, LExt, -1) = 1);
  finally
    X509_EXTENSION_free(LExt);
  end;
end;

function X509AddSubjectAltName(Cert: PX509; const DNS: string): Boolean;
var
  LExt: PX509_EXTENSION;
  LDNSValue: AnsiString;
begin
  Result := False;

  if Cert = nil then
    Exit;

  LDNSValue := Trim(DNS);
  if LDNSValue = '' then
    Exit;

  if UpperCase(Copy(LDNSValue, 1, 4)) <> 'DNS:' then
    LDNSValue := 'DNS:' + LDNSValue;

  if (not Assigned(X509_add_ext)) or (not Assigned(X509_EXTENSION_free)) then
    LoadOpenSSLX509();

  if (not Assigned(X509V3_EXT_conf_nid)) or
    (not Assigned(X509_add_ext)) or
    (not Assigned(X509_EXTENSION_free)) then
    Exit;

  LExt := X509V3_EXT_conf_nid(nil, nil, NID_subject_alt_name, PAnsiChar(LDNSValue));
  if LExt = nil then
    Exit;

  try
    Result := (X509_add_ext(Cert, LExt, -1) = 1);
  finally
    X509_EXTENSION_free(LExt);
  end;
end;

end.