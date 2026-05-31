unit nextpas.core.tls.openssl.api.obj;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.asn1;

type
  // OBJ 类型定义
  POBJ_NAME = ^OBJ_NAME;
  OBJ_NAME = record
    type_: Integer;
    alias: Integer;
    name: PAnsiChar;
    data: PAnsiChar;
  end;

const
  // 对象类型
  OBJ_NAME_TYPE_UNDEF = $00;
  OBJ_NAME_TYPE_MD_METH = $01;
  OBJ_NAME_TYPE_CIPHER_METH = $02;
  OBJ_NAME_TYPE_PKEY_METH = $03;
  OBJ_NAME_TYPE_COMP_METH = $04;
  OBJ_NAME_TYPE_NUM = $05;
  
  // 对象别名
  OBJ_NAME_ALIAS = $8000;
  
  // 常用 NID 值
  NID_undef = 0;
  NID_rsaEncryption = 6;
  NID_dsa = 116;
  NID_sha1 = 64;
  NID_sha256 = 672;
  NID_sha384 = 673;
  NID_sha512 = 674;
  NID_sha224 = 675;
  NID_md5 = 4;
  NID_commonName = 13;
  NID_countryName = 14;
  NID_localityName = 15;
  NID_stateOrProvinceName = 16;
  NID_organizationName = 17;
  NID_organizationalUnitName = 18;
  NID_emailAddress = 48;
  NID_subject_key_identifier = 82;
  NID_key_usage = 83;
  NID_basic_constraints = 87;
  NID_authority_key_identifier = 90;
  NID_ext_key_usage = 126;
  NID_subject_alt_name = 85;
  NID_issuer_alt_name = 86;
  NID_crl_distribution_points = 103;
  NID_certificate_policies = 89;
  
type
  // 函数类型定义
  TOBJ_nid2obj = function(n: Integer): PASN1_OBJECT; cdecl;
  TOBJ_nid2ln = function(n: Integer): PAnsiChar; cdecl;
  TOBJ_nid2sn = function(n: Integer): PAnsiChar; cdecl;
  TOBJ_obj2nid = function(const o: PASN1_OBJECT): Integer; cdecl;
  TOBJ_obj2txt = function(buf: PAnsiChar; buf_len: Integer; 
    const a: PASN1_OBJECT; no_name: Integer): Integer; cdecl;
  TOBJ_txt2obj = function(const s: PAnsiChar; no_name: Integer): PASN1_OBJECT; cdecl;
  TOBJ_txt2nid = function(const s: PAnsiChar): Integer; cdecl;
  TOBJ_ln2nid = function(const s: PAnsiChar): Integer; cdecl;
  TOBJ_sn2nid = function(const s: PAnsiChar): Integer; cdecl;
  TOBJ_cmp = function(const a, b: PASN1_OBJECT): Integer; cdecl;
  TOBJ_dup = function(const o: PASN1_OBJECT): PASN1_OBJECT; cdecl;
  TOBJ_create = function(const oid: PAnsiChar; const sn: PAnsiChar; 
    const ln: PAnsiChar): Integer; cdecl;
  TOBJ_create_objects = function(in_: PBIO): Integer; cdecl;
  TOBJ_cleanup = procedure(); cdecl;
  TOBJ_find_sigid_algs = function(signid: Integer; var pdig_nid: Integer;
    var ppkey_nid: Integer): Integer; cdecl;
  TOBJ_find_sigid_by_algs = function(var psignid: Integer; dig_nid: Integer;
    pkey_nid: Integer): Integer; cdecl;
  TOBJ_add_sigid = function(signid: Integer; dig_id: Integer; 
    pkey_id: Integer): Integer; cdecl;
  TOBJ_sigid_free = procedure(); cdecl;
  
  // OBJ_NAME 函数
  TOBJ_NAME_init = function(): Integer; cdecl;
  TOBJ_NAME_get = function(const name: PAnsiChar; type_: Integer): POBJ_NAME; cdecl;
  TOBJ_NAME_add = function(const name: PAnsiChar; type_: Integer; 
    const data: PAnsiChar): Integer; cdecl;
  TOBJ_NAME_remove = function(const name: PAnsiChar; type_: Integer): Integer; cdecl;
  TOBJ_NAME_cleanup = procedure(type_: Integer); cdecl;
  
  // Callback types for OBJ_NAME functions
  TOBJ_NAME_do_all_fn = procedure(const name: POBJ_NAME; arg: Pointer); cdecl;
  TOBJ_NAME_hash_fn = function(const name: PAnsiChar): Cardinal; cdecl;
  TOBJ_NAME_cmp_fn = function(const a, b: PAnsiChar): Integer; cdecl;
  TOBJ_NAME_free_fn = procedure(const name: PAnsiChar; type_: Integer; data: PAnsiChar); cdecl;
  
  TOBJ_NAME_do_all = procedure(type_: Integer; fn: TOBJ_NAME_do_all_fn; arg: Pointer); cdecl;
  TOBJ_NAME_do_all_sorted = procedure(type_: Integer; fn: TOBJ_NAME_do_all_fn; arg: Pointer); cdecl;
  TOBJ_NAME_new_index = function(hash_func: TOBJ_NAME_hash_fn;
    cmp_func: TOBJ_NAME_cmp_fn; free_func: TOBJ_NAME_free_fn): Integer; cdecl;

var
  // 函数指针
  OBJ_nid2obj: TOBJ_nid2obj = nil;
  OBJ_nid2ln: TOBJ_nid2ln = nil;
  OBJ_nid2sn: TOBJ_nid2sn = nil;
  OBJ_obj2nid: TOBJ_obj2nid = nil;
  OBJ_obj2txt: TOBJ_obj2txt = nil;
  OBJ_txt2obj: TOBJ_txt2obj = nil;
  OBJ_txt2nid: TOBJ_txt2nid = nil;
  OBJ_ln2nid: TOBJ_ln2nid = nil;
  OBJ_sn2nid: TOBJ_sn2nid = nil;
  OBJ_cmp: TOBJ_cmp = nil;
  OBJ_dup: TOBJ_dup = nil;
  OBJ_create: TOBJ_create = nil;
  OBJ_create_objects: TOBJ_create_objects = nil;
  OBJ_cleanup: TOBJ_cleanup = nil;
  OBJ_find_sigid_algs: TOBJ_find_sigid_algs = nil;
  OBJ_find_sigid_by_algs: TOBJ_find_sigid_by_algs = nil;
  OBJ_add_sigid: TOBJ_add_sigid = nil;
  OBJ_sigid_free: TOBJ_sigid_free = nil;
  OBJ_NAME_init: TOBJ_NAME_init = nil;
  OBJ_NAME_get: TOBJ_NAME_get = nil;
  OBJ_NAME_add: TOBJ_NAME_add = nil;
  OBJ_NAME_remove: TOBJ_NAME_remove = nil;
  OBJ_NAME_cleanup: TOBJ_NAME_cleanup = nil;
  OBJ_NAME_do_all: TOBJ_NAME_do_all = nil;
  OBJ_NAME_do_all_sorted: TOBJ_NAME_do_all_sorted = nil;
  OBJ_NAME_new_index: TOBJ_NAME_new_index = nil;

// 辅助函数
function NIDToOID(NID: Integer): string;
function OIDToNID(const OID: string): Integer;
function NIDToLongName(NID: Integer): string;
function NIDToShortName(NID: Integer): string;
function LongNameToNID(const Name: string): Integer;
function ShortNameToNID(const Name: string): Integer;
function ObjectToString(Obj: PASN1_OBJECT): string;
function StringToObject(const OID: string): PASN1_OBJECT;
function CreateOID(const OID, ShortName, LongName: string): Integer;
function CompareObjects(Obj1, Obj2: PASN1_OBJECT): Boolean;
function DuplicateObject(Obj: PASN1_OBJECT): PASN1_OBJECT;
function GetSignatureAlgorithms(SignatureNID: Integer; 
  out ADigestNID, APublicKeyNID: Integer): Boolean;
function FindSignatureNID(ADigestNID, APublicKeyNID: Integer): Integer;

// 模块加载和卸载
procedure LoadOBJModule(ALibCrypto: THandle);
procedure UnloadOBJModule;

implementation

uses
  nextpas.core.tls.openssl.loader;

const
  { OBJ 模块函数绑定表 }
  OBJ_FUNCTION_BINDINGS: array[0..25] of TFunctionBinding = (
    (Name: 'OBJ_nid2obj';           FuncPtr: @OBJ_nid2obj;           Required: False),
    (Name: 'OBJ_nid2ln';            FuncPtr: @OBJ_nid2ln;            Required: False),
    (Name: 'OBJ_nid2sn';            FuncPtr: @OBJ_nid2sn;            Required: False),
    (Name: 'OBJ_obj2nid';           FuncPtr: @OBJ_obj2nid;           Required: False),
    (Name: 'OBJ_obj2txt';           FuncPtr: @OBJ_obj2txt;           Required: False),
    (Name: 'OBJ_txt2obj';           FuncPtr: @OBJ_txt2obj;           Required: False),
    (Name: 'OBJ_txt2nid';           FuncPtr: @OBJ_txt2nid;           Required: False),
    (Name: 'OBJ_ln2nid';            FuncPtr: @OBJ_ln2nid;            Required: False),
    (Name: 'OBJ_sn2nid';            FuncPtr: @OBJ_sn2nid;            Required: False),
    (Name: 'OBJ_cmp';               FuncPtr: @OBJ_cmp;               Required: False),
    (Name: 'OBJ_dup';               FuncPtr: @OBJ_dup;               Required: False),
    (Name: 'OBJ_create';            FuncPtr: @OBJ_create;            Required: False),
    (Name: 'OBJ_create_objects';    FuncPtr: @OBJ_create_objects;    Required: False),
    (Name: 'OBJ_cleanup';           FuncPtr: @OBJ_cleanup;           Required: False),
    (Name: 'OBJ_find_sigid_algs';   FuncPtr: @OBJ_find_sigid_algs;   Required: False),
    (Name: 'OBJ_find_sigid_by_algs'; FuncPtr: @OBJ_find_sigid_by_algs; Required: False),
    (Name: 'OBJ_add_sigid';         FuncPtr: @OBJ_add_sigid;         Required: False),
    (Name: 'OBJ_sigid_free';        FuncPtr: @OBJ_sigid_free;        Required: False),
    (Name: 'OBJ_NAME_init';         FuncPtr: @OBJ_NAME_init;         Required: False),
    (Name: 'OBJ_NAME_get';          FuncPtr: @OBJ_NAME_get;          Required: False),
    (Name: 'OBJ_NAME_add';          FuncPtr: @OBJ_NAME_add;          Required: False),
    (Name: 'OBJ_NAME_remove';       FuncPtr: @OBJ_NAME_remove;       Required: False),
    (Name: 'OBJ_NAME_cleanup';      FuncPtr: @OBJ_NAME_cleanup;      Required: False),
    (Name: 'OBJ_NAME_do_all';       FuncPtr: @OBJ_NAME_do_all;       Required: False),
    (Name: 'OBJ_NAME_do_all_sorted'; FuncPtr: @OBJ_NAME_do_all_sorted; Required: False),
    (Name: 'OBJ_NAME_new_index';    FuncPtr: @OBJ_NAME_new_index;    Required: False)
  );

procedure LoadOBJModule(ALibCrypto: THandle);
begin
  if ALibCrypto = 0 then Exit;
  TOpenSSLLoader.LoadFunctions(ALibCrypto, OBJ_FUNCTION_BINDINGS);
end;

procedure UnloadOBJModule;
begin
  TOpenSSLLoader.ClearFunctions(OBJ_FUNCTION_BINDINGS);
end;

// 辅助函数实现
function NIDToOID(NID: Integer): string;
var
  Obj: PASN1_OBJECT;
  Buffer: array[0..127] of AnsiChar;
  Len: Integer;
begin
  Result := '';
  if not Assigned(OBJ_nid2obj) or not Assigned(OBJ_obj2txt) then Exit;
  
  Obj := OBJ_nid2obj(NID);
  if not Assigned(Obj) then Exit;
  
  Len := OBJ_obj2txt(@Buffer[0], SizeOf(Buffer), Obj, 1);
  if Len > 0 then
    Result := string(PAnsiChar(@Buffer[0]));
end;

function OIDToNID(const OID: string): Integer;
begin
  Result := NID_undef;
  if not Assigned(OBJ_txt2nid) then Exit;

  Result := OBJ_txt2nid(PAnsiChar(AnsiString(OID)));
end;

function NIDToLongName(NID: Integer): string;
var
  Name: PAnsiChar;
begin
  Result := '';
  if not Assigned(OBJ_nid2ln) then Exit;
  
  Name := OBJ_nid2ln(NID);
  if Assigned(Name) then
    Result := string(Name);
end;

function NIDToShortName(NID: Integer): string;
var
  Name: PAnsiChar;
begin
  Result := '';
  if not Assigned(OBJ_nid2sn) then Exit;
  
  Name := OBJ_nid2sn(NID);
  if Assigned(Name) then
    Result := string(Name);
end;

function LongNameToNID(const Name: string): Integer;
begin
  Result := NID_undef;
  if not Assigned(OBJ_ln2nid) then Exit;

  Result := OBJ_ln2nid(PAnsiChar(AnsiString(Name)));
end;

function ShortNameToNID(const Name: string): Integer;
begin
  Result := NID_undef;
  if not Assigned(OBJ_sn2nid) then Exit;

  Result := OBJ_sn2nid(PAnsiChar(AnsiString(Name)));
end;

function ObjectToString(Obj: PASN1_OBJECT): string;
var
  Buffer: array[0..255] of AnsiChar;
  Len: Integer;
begin
  Result := '';
  if not Assigned(OBJ_obj2txt) or not Assigned(Obj) then Exit;
  
  Len := OBJ_obj2txt(@Buffer[0], SizeOf(Buffer), Obj, 0);
  if Len > 0 then
    Result := string(PAnsiChar(@Buffer[0]));
end;

function StringToObject(const OID: string): PASN1_OBJECT;
begin
  Result := nil;
  if not Assigned(OBJ_txt2obj) then Exit;

  Result := OBJ_txt2obj(PAnsiChar(AnsiString(OID)), 1);
end;

function CreateOID(const OID, ShortName, LongName: string): Integer;
begin
  Result := NID_undef;
  if not Assigned(OBJ_create) then Exit;

  Result := OBJ_create(
    PAnsiChar(AnsiString(OID)),
    PAnsiChar(AnsiString(ShortName)),
    PAnsiChar(AnsiString(LongName))
  );
end;

function CompareObjects(Obj1, Obj2: PASN1_OBJECT): Boolean;
begin
  Result := False;
  if not Assigned(OBJ_cmp) then Exit;
  
  Result := OBJ_cmp(Obj1, Obj2) = 0;
end;

function DuplicateObject(Obj: PASN1_OBJECT): PASN1_OBJECT;
begin
  Result := nil;
  if not Assigned(OBJ_dup) then Exit;
  
  Result := OBJ_dup(Obj);
end;

function GetSignatureAlgorithms(SignatureNID: Integer; 
  out ADigestNID, APublicKeyNID: Integer): Boolean;
begin
  Result := False;
  ADigestNID := NID_undef;
  APublicKeyNID := NID_undef;
  
  if not Assigned(OBJ_find_sigid_algs) then Exit;
  
  Result := OBJ_find_sigid_algs(SignatureNID, ADigestNID, APublicKeyNID) = 1;
end;

function FindSignatureNID(ADigestNID, APublicKeyNID: Integer): Integer;
begin
  Result := NID_undef;
  if not Assigned(OBJ_find_sigid_by_algs) then Exit;
  
  OBJ_find_sigid_by_algs(Result, ADigestNID, APublicKeyNID);
end;

end.