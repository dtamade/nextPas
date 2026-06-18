unit nextpas.core.tls.openssl.api.dsa;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.bn, nextpas.core.tls.openssl.loader,
  nextpas.core.platform.dl;

const
  { DSA flags }
  DSA_FLAG_CACHE_MONT_P      = $01;
  DSA_FLAG_NO_EXP_CONSTTIME   = $00;
  DSA_FLAG_FIPS_METHOD        = $0400;
  DSA_FLAG_NON_FIPS_ALLOW     = $0400;
  DSA_FLAG_FIPS_CHECKED       = $0800;

type
  { DSA_METHOD structure }
  DSA_METHOD = record
    name: PAnsiChar;
    dsa_do_sign: function(const dgst: PByte; dlen: Integer; dsa: PDSA): PDSA_SIG; cdecl;
    dsa_sign_setup: function(dsa: PDSA; ctx_in: PBN_CTX; kinvp: PPBIGNUM; rp: PPBIGNUM): Integer; cdecl;
    dsa_do_verify: function(const dgst: PByte; dgst_len: Integer; sig: PDSA_SIG; dsa: PDSA): Integer; cdecl;
    dsa_mod_exp: function(dsa: PDSA; rr: PBIGNUM; a1: PBIGNUM; p1: PBIGNUM; a2: PBIGNUM; p2: PBIGNUM; m: PBIGNUM; ctx: PBN_CTX; in_mont: PBN_MONT_CTX): Integer; cdecl;
    bn_mod_exp: function(dsa: PDSA; r: PBIGNUM; const a: PBIGNUM; const p: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX; m_ctx: PBN_MONT_CTX): Integer; cdecl;
    init: function(dsa: PDSA): Integer; cdecl;
    finish: function(dsa: PDSA): Integer; cdecl;
    flags: Integer;
    app_data: PAnsiChar;
    dsa_paramgen: function(dsa: PDSA; bits: Integer; const seed: PByte; seed_len: Integer; counter_ret: PInteger; h_ret: PCardinal; cb: PBN_GENCB): Integer; cdecl;
    dsa_keygen: function(dsa: PDSA): Integer; cdecl;
  end;
  PDSA_METHOD = ^DSA_METHOD;

  { DSA function types }
  TDSA_new = function: PDSA; cdecl;
  TDSA_new_method = function(engine: PENGINE): PDSA; cdecl;
  TDSA_free = procedure(r: PDSA); cdecl;
  TDSA_up_ref = function(r: PDSA): Integer; cdecl;
  TDSA_bits = function(const d: PDSA): Integer; cdecl;
  TDSA_size = function(const d: PDSA): Integer; cdecl;
  TDSA_security_bits = function(const d: PDSA): Integer; cdecl;
  
  { DSA parameter/key manipulation }
  TDSA_set0_pqg = function(d: PDSA; p: PBIGNUM; q: PBIGNUM; g: PBIGNUM): Integer; cdecl;
  TDSA_get0_pqg = procedure(const d: PDSA; const p: PPBIGNUM; const q: PPBIGNUM; const g: PPBIGNUM); cdecl;
  TDSA_set0_key = function(d: PDSA; pub_key: PBIGNUM; priv_key: PBIGNUM): Integer; cdecl;
  TDSA_get0_key = procedure(const d: PDSA; const pub_key: PPBIGNUM; const priv_key: PPBIGNUM); cdecl;
  TDSA_get0_p = function(const d: PDSA): PBIGNUM; cdecl;
  TDSA_get0_q = function(const d: PDSA): PBIGNUM; cdecl;
  TDSA_get0_g = function(const d: PDSA): PBIGNUM; cdecl;
  TDSA_get0_pub_key = function(const d: PDSA): PBIGNUM; cdecl;
  TDSA_get0_priv_key = function(const d: PDSA): PBIGNUM; cdecl;
  TDSA_clear_flags = procedure(d: PDSA; flags: Integer); cdecl;
  TDSA_test_flags = function(const d: PDSA; flags: Integer): Integer; cdecl;
  TDSA_set_flags = procedure(d: PDSA; flags: Integer); cdecl;
  TDSA_get0_engine = function(d: PDSA): PENGINE; cdecl;
  
  { DSA parameter generation }
  TDSA_generate_parameters = function(bits: Integer; seed: PByte; seed_len: Integer; counter_ret: PInteger; h_ret: PCardinal; callback: Pointer; cb_arg: Pointer): PDSA; cdecl;
  TDSA_generate_parameters_ex = function(dsa: PDSA; bits: Integer; const seed: PByte; seed_len: Integer; counter_ret: PInteger; h_ret: PCardinal; cb: PBN_GENCB): Integer; cdecl;
  
  { DSA key generation }
  TDSA_generate_key = function(a: PDSA): Integer; cdecl;
  
  { DSA signing }
  TDSA_sign = function(&type: Integer; const dgst: PByte; dlen: Integer; sig: PByte; siglen: PCardinal; dsa: PDSA): Integer; cdecl;
  TDSA_sign_setup = function(dsa: PDSA; ctx_in: PBN_CTX; kinvp: PPBIGNUM; rp: PPBIGNUM): Integer; cdecl;
  TDSA_do_sign = function(const dgst: PByte; dlen: Integer; dsa: PDSA): PDSA_SIG; cdecl;
  
  { DSA verification }
  TDSA_verify = function(&type: Integer; const dgst: PByte; dgst_len: Integer; const sigbuf: PByte; siglen: Integer; dsa: PDSA): Integer; cdecl;
  TDSA_do_verify = function(const dgst: PByte; dgst_len: Integer; sig: PDSA_SIG; dsa: PDSA): Integer; cdecl;
  
  { DSA_SIG functions }
  TDSA_SIG_new = function: PDSA_SIG; cdecl;
  TDSA_SIG_free = procedure(a: PDSA_SIG); cdecl;
  TDSA_SIG_get0 = procedure(const sig: PDSA_SIG; const pr: PPBIGNUM; const ps: PPBIGNUM); cdecl;
  TDSA_SIG_set0 = function(sig: PDSA_SIG; r: PBIGNUM; s: PBIGNUM): Integer; cdecl;
  Ti2d_DSA_SIG = function(const a: PDSA_SIG; pp: PPByte): Integer; cdecl;
  Td2i_DSA_SIG = function(v: PPDSA_SIG; const pp: PPByte; length: clong): PDSA_SIG; cdecl;
  
  { DSA ASN1 functions }
  TDSAparams_dup = function(const x: PDSA): PDSA; cdecl;
  Ti2d_DSAPublicKey = function(const a: PDSA; pp: PPByte): Integer; cdecl;
  Td2i_DSAPublicKey = function(a: PPDSA; const pp: PPByte; length: clong): PDSA; cdecl;
  Ti2d_DSAPrivateKey = function(const a: PDSA; pp: PPByte): Integer; cdecl;
  Td2i_DSAPrivateKey = function(a: PPDSA; const pp: PPByte; length: clong): PDSA; cdecl;
  Ti2d_DSAparams = function(const a: PDSA; pp: PPByte): Integer; cdecl;
  Td2i_DSAparams = function(a: PPDSA; const pp: PPByte; length: clong): PDSA; cdecl;
  Ti2d_DSA_PUBKEY = function(const a: PDSA; pp: PPByte): Integer; cdecl;
  Td2i_DSA_PUBKEY = function(a: PPDSA; const pp: PPByte; length: clong): PDSA; cdecl;
  
  { DSA print functions }
  TDSA_print = function(bp: PBIO; const x: PDSA; off: Integer): Integer; cdecl;
  TDSA_print_fp = function(fp: Pointer; const x: PDSA; off: Integer): Integer; cdecl;
  TDSAparams_print = function(bp: PBIO; const x: PDSA): Integer; cdecl;
  TDSAparams_print_fp = function(fp: Pointer; const x: PDSA): Integer; cdecl;
  
  { DSA method functions }
  TDSA_meth_new = function(const name: PAnsiChar; flags: Integer): PDSA_METHOD; cdecl;
  TDSA_meth_free = procedure(dsam: PDSA_METHOD); cdecl;
  TDSA_meth_dup = function(const dsam: PDSA_METHOD): PDSA_METHOD; cdecl;
  TDSA_meth_get0_name = function(const dsam: PDSA_METHOD): PAnsiChar; cdecl;
  TDSA_meth_set1_name = function(dsam: PDSA_METHOD; const name: PAnsiChar): Integer; cdecl;
  TDSA_meth_get_flags = function(const dsam: PDSA_METHOD): Integer; cdecl;
  TDSA_meth_set_flags = function(dsam: PDSA_METHOD; flags: Integer): Integer; cdecl;
  TDSA_meth_get0_app_data = function(const dsam: PDSA_METHOD): Pointer; cdecl;
  TDSA_meth_set0_app_data = function(dsam: PDSA_METHOD; app_data: Pointer): Integer; cdecl;
  TDSA_get_default_method = function: PDSA_METHOD; cdecl;
  TDSA_set_default_method = procedure(meth: PDSA_METHOD); cdecl;
  TDSA_get_method = function(d: PDSA): PDSA_METHOD; cdecl;
  TDSA_set_method = function(dsa: PDSA; meth: PDSA_METHOD): Integer; cdecl;
  TDSA_OpenSSL = function: PDSA_METHOD; cdecl;
  
  { DSA DH compatibility }
  TDSA_dup_DH = function(const r: PDSA): PDH; cdecl;
  TDH_dup_DSA = function(const r: PDH): PDSA; cdecl;

var
  { DSA functions }
  DSA_new: TDSA_new;
  DSA_new_method: TDSA_new_method;
  DSA_free: TDSA_free;
  DSA_up_ref: TDSA_up_ref;
  DSA_bits: TDSA_bits;
  DSA_size: TDSA_size;
  DSA_security_bits: TDSA_security_bits;
  
  { DSA parameter/key manipulation }
  DSA_set0_pqg: TDSA_set0_pqg;
  DSA_get0_pqg: TDSA_get0_pqg;
  DSA_set0_key: TDSA_set0_key;
  DSA_get0_key: TDSA_get0_key;
  DSA_get0_p: TDSA_get0_p;
  DSA_get0_q: TDSA_get0_q;
  DSA_get0_g: TDSA_get0_g;
  DSA_get0_pub_key: TDSA_get0_pub_key;
  DSA_get0_priv_key: TDSA_get0_priv_key;
  DSA_clear_flags: TDSA_clear_flags;
  DSA_test_flags: TDSA_test_flags;
  DSA_set_flags: TDSA_set_flags;
  DSA_get0_engine: TDSA_get0_engine;
  
  { DSA parameter generation }
  DSA_generate_parameters: TDSA_generate_parameters;
  DSA_generate_parameters_ex: TDSA_generate_parameters_ex;
  
  { DSA key generation }
  DSA_generate_key: TDSA_generate_key;
  
  { DSA signing }
  DSA_sign: TDSA_sign;
  DSA_sign_setup: TDSA_sign_setup;
  DSA_do_sign: TDSA_do_sign;
  
  { DSA verification }
  DSA_verify: TDSA_verify;
  DSA_do_verify: TDSA_do_verify;
  
  { DSA_SIG functions }
  DSA_SIG_new: TDSA_SIG_new;
  DSA_SIG_free: TDSA_SIG_free;
  DSA_SIG_get0: TDSA_SIG_get0;
  DSA_SIG_set0: TDSA_SIG_set0;
  i2d_DSA_SIG: Ti2d_DSA_SIG;
  d2i_DSA_SIG: Td2i_DSA_SIG;
  
  { DSA ASN1 functions }
  DSAparams_dup: TDSAparams_dup;
  i2d_DSAPublicKey: Ti2d_DSAPublicKey;
  d2i_DSAPublicKey: Td2i_DSAPublicKey;
  i2d_DSAPrivateKey: Ti2d_DSAPrivateKey;
  d2i_DSAPrivateKey: Td2i_DSAPrivateKey;
  i2d_DSAparams: Ti2d_DSAparams;
  d2i_DSAparams: Td2i_DSAparams;
  i2d_DSA_PUBKEY: Ti2d_DSA_PUBKEY;
  d2i_DSA_PUBKEY: Td2i_DSA_PUBKEY;
  
  { DSA print functions }
  DSA_print: TDSA_print;
  DSA_print_fp: TDSA_print_fp;
  DSAparams_print: TDSAparams_print;
  DSAparams_print_fp: TDSAparams_print_fp;
  
  { DSA method functions }
  DSA_meth_new: TDSA_meth_new;
  DSA_meth_free: TDSA_meth_free;
  DSA_meth_dup: TDSA_meth_dup;
  DSA_meth_get0_name: TDSA_meth_get0_name;
  DSA_meth_set1_name: TDSA_meth_set1_name;
  DSA_meth_get_flags: TDSA_meth_get_flags;
  DSA_meth_set_flags: TDSA_meth_set_flags;
  DSA_meth_get0_app_data: TDSA_meth_get0_app_data;
  DSA_meth_set0_app_data: TDSA_meth_set0_app_data;
  DSA_get_default_method: TDSA_get_default_method;
  DSA_set_default_method: TDSA_set_default_method;
  DSA_get_method: TDSA_get_method;
  DSA_set_method: TDSA_set_method;
  DSA_OpenSSL: TDSA_OpenSSL;
  
  { DSA DH compatibility }
  DSA_dup_DH: TDSA_dup_DH;
  DH_dup_DSA: TDH_dup_DSA;

function LoadOpenSSLDSA: Boolean;
procedure UnloadOpenSSLDSA;

implementation

uses nextpas.core.tls.openssl.api.core;

const
  { DSA 函数绑定数组 - 用于批量加载 }
  DSA_FUNCTION_BINDINGS: array[0..27] of TFunctionBinding = (
    // DSA basic functions
    (Name: 'DSA_new';              FuncPtr: @DSA_new;              Required: True),
    (Name: 'DSA_new_method';       FuncPtr: @DSA_new_method;       Required: False),
    (Name: 'DSA_free';             FuncPtr: @DSA_free;             Required: True),
    (Name: 'DSA_up_ref';           FuncPtr: @DSA_up_ref;           Required: False),
    (Name: 'DSA_bits';             FuncPtr: @DSA_bits;             Required: False),
    (Name: 'DSA_size';             FuncPtr: @DSA_size;             Required: False),
    (Name: 'DSA_security_bits';    FuncPtr: @DSA_security_bits;    Required: False),
    // DSA parameter/key manipulation
    (Name: 'DSA_set0_pqg';         FuncPtr: @DSA_set0_pqg;         Required: False),
    (Name: 'DSA_get0_pqg';         FuncPtr: @DSA_get0_pqg;         Required: False),
    (Name: 'DSA_set0_key';         FuncPtr: @DSA_set0_key;         Required: False),
    (Name: 'DSA_get0_key';         FuncPtr: @DSA_get0_key;         Required: False),
    (Name: 'DSA_get0_p';           FuncPtr: @DSA_get0_p;           Required: False),
    (Name: 'DSA_get0_q';           FuncPtr: @DSA_get0_q;           Required: False),
    (Name: 'DSA_get0_g';           FuncPtr: @DSA_get0_g;           Required: False),
    (Name: 'DSA_get0_pub_key';     FuncPtr: @DSA_get0_pub_key;     Required: False),
    (Name: 'DSA_get0_priv_key';    FuncPtr: @DSA_get0_priv_key;    Required: False),
    // DSA parameter generation
    (Name: 'DSA_generate_parameters';    FuncPtr: @DSA_generate_parameters;    Required: False),
    (Name: 'DSA_generate_parameters_ex'; FuncPtr: @DSA_generate_parameters_ex; Required: False),
    // DSA key generation
    (Name: 'DSA_generate_key';     FuncPtr: @DSA_generate_key;     Required: True),
    // DSA signing
    (Name: 'DSA_sign';             FuncPtr: @DSA_sign;             Required: True),
    (Name: 'DSA_sign_setup';       FuncPtr: @DSA_sign_setup;       Required: False),
    (Name: 'DSA_do_sign';          FuncPtr: @DSA_do_sign;          Required: False),
    // DSA verification
    (Name: 'DSA_verify';           FuncPtr: @DSA_verify;           Required: False),
    (Name: 'DSA_do_verify';        FuncPtr: @DSA_do_verify;        Required: False),
    // DSA_SIG functions
    (Name: 'DSA_SIG_new';          FuncPtr: @DSA_SIG_new;          Required: False),
    (Name: 'DSA_SIG_free';         FuncPtr: @DSA_SIG_free;         Required: False),
    (Name: 'DSA_SIG_get0';         FuncPtr: @DSA_SIG_get0;         Required: False),
    (Name: 'DSA_SIG_set0';         FuncPtr: @DSA_SIG_set0;         Required: False)
  );

function LoadOpenSSLDSA: Boolean;
var
  LLib: TPlatformLibrary;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmDSA) then
    Exit(True);

  // Use the crypto library handle from core module
  LLib := GetCryptoLibHandle;
  if not LibLoaded(LLib) then
  begin
    LoadOpenSSLCore;
    LLib := GetCryptoLibHandle;
  end;

  if not LibLoaded(LLib) then
    Exit(False);

  // 使用批量加载模式
  TOpenSSLLoader.LoadFunctions(LLib, DSA_FUNCTION_BINDINGS);

  TOpenSSLLoader.SetModuleLoaded(osmDSA, Assigned(DSA_new) and Assigned(DSA_free) and
                Assigned(DSA_generate_key) and Assigned(DSA_sign));
  Result := TOpenSSLLoader.IsModuleLoaded(osmDSA);
end;

procedure UnloadOpenSSLDSA;
begin
  // 使用批量清除模式
  TOpenSSLLoader.ClearFunctions(DSA_FUNCTION_BINDINGS);

  TOpenSSLLoader.SetModuleLoaded(osmDSA, False);
end;


end.
