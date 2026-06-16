{******************************************************************************}
{                                                                              }
{  fafafa.ssl - OpenSSL EC (Elliptic Curve) Module                           }
{                                                                              }
{  Copyright (c) 2024 fafafa                                                  }
{                                                                              }
{******************************************************************************}

unit nextpas.core.tls.openssl.api.ec;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.tls.base, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.loader;

type
  // EC structures
  PEC_KEY = ^EC_KEY;
  EC_KEY = record end;
  
  PEC_GROUP = ^EC_GROUP;
  EC_GROUP = record end;
  
  PEC_POINT = ^EC_POINT;
  EC_POINT = record end;
  
  PEC_METHOD = ^EC_METHOD;
  EC_METHOD = record end;
  
  PEC_builtin_curve = ^EC_builtin_curve;
  EC_builtin_curve = record
    nid: Integer;
    comment: PAnsiChar;
  end;
  
  // ASN.1 structures for EC parameters
  PECPARAMETERS = ^ECPARAMETERS;
  ECPARAMETERS = record end;
  
  PECPKPARAMETERS = ^ECPKPARAMETERS;
  ECPKPARAMETERS = record end;
  
  Ppoint_conversion_form_t = ^point_conversion_form_t;
  point_conversion_form_t = (
    POINT_CONVERSION_COMPRESSED = 2,
    POINT_CONVERSION_UNCOMPRESSED = 4,
    POINT_CONVERSION_HYBRID = 6
  );

const
  // EC key flags
  EC_FLAG_NON_FIPS_ALLOW = $1;
  EC_FLAG_FIPS_CHECKED = $2;
  EC_FLAG_COFACTOR_ECDH = $1000;
  EC_FLAG_CHECK_NAMED_GROUP = $2000;
  EC_FLAG_CHECK_NAMED_GROUP_NIST = $4000;
  EC_FLAG_CHECK_NAMED_GROUP_MASK = $FF00;
  
  // EC pkey control commands
  EC_PKEY_NO_PARAMETERS = $001;
  EC_PKEY_NO_PUBKEY = $002;
  
  // Common EC curve NIDs
  NID_secp112r1 = 704;
  NID_secp112r2 = 705;
  NID_secp128r1 = 706;
  NID_secp128r2 = 707;
  NID_secp160k1 = 708;
  NID_secp160r1 = 709;
  NID_secp160r2 = 710;
  NID_secp192k1 = 711;
  NID_secp224k1 = 712;
  NID_secp224r1 = 713;
  NID_secp256k1 = 714;
  NID_secp384r1 = 715;
  NID_secp521r1 = 716;
  NID_sect113r1 = 717;
  NID_sect113r2 = 718;
  NID_sect131r1 = 719;
  NID_sect131r2 = 720;
  NID_sect163k1 = 721;
  NID_sect163r1 = 722;
  NID_sect163r2 = 723;
  NID_sect193r1 = 724;
  NID_sect193r2 = 725;
  NID_sect233k1 = 726;
  NID_sect233r1 = 727;
  NID_sect239k1 = 728;
  NID_sect283k1 = 729;
  NID_sect283r1 = 730;
  NID_sect409k1 = 731;
  NID_sect409r1 = 732;
  NID_sect571k1 = 733;
  NID_sect571r1 = 734;
  
  // NIST curves
  NID_X9_62_prime192v1 = 409;
  NID_X9_62_prime192v2 = 410;
  NID_X9_62_prime192v3 = 411;
  NID_X9_62_prime239v1 = 412;
  NID_X9_62_prime239v2 = 413;
  NID_X9_62_prime239v3 = 414;
  NID_X9_62_prime256v1 = 415;
  
  // Brainpool curves
  NID_brainpoolP160r1 = 921;
  NID_brainpoolP160t1 = 922;
  NID_brainpoolP192r1 = 923;
  NID_brainpoolP192t1 = 924;
  NID_brainpoolP224r1 = 925;
  NID_brainpoolP224t1 = 926;
  NID_brainpoolP256r1 = 927;
  NID_brainpoolP256t1 = 928;
  NID_brainpoolP320r1 = 929;
  NID_brainpoolP320t1 = 930;
  NID_brainpoolP384r1 = 931;
  NID_brainpoolP384t1 = 932;
  NID_brainpoolP512r1 = 933;
  NID_brainpoolP512t1 = 934;
  
  // X25519/X448/Ed25519/Ed448 curves
  NID_X25519 = 1034;
  NID_X448 = 1035;
  NID_ED25519 = 1087;
  NID_ED448 = 1088;

type
  // EC_KEY functions
  Td2i_ECPrivateKey = function(key: PEC_KEY; in_: PPByte; len: NativeUInt): PEC_KEY; cdecl;
  TEC_KEY_new = function: PEC_KEY; cdecl;
  TEC_KEY_new_by_curve_name = function(nid: Integer): PEC_KEY; cdecl;
  TEC_KEY_free = procedure(key: PEC_KEY); cdecl;
  TEC_KEY_copy = function(dst: PEC_KEY; const src: PEC_KEY): PEC_KEY; cdecl;
  TEC_KEY_dup = function(const src: PEC_KEY): PEC_KEY; cdecl;
  TEC_KEY_up_ref = function(key: PEC_KEY): Integer; cdecl;
  TEC_KEY_get0_engine = function(const eckey: PEC_KEY): PENGINE; cdecl;
  
  TEC_KEY_get0_group = function(const key: PEC_KEY): PEC_GROUP; cdecl;
  TEC_KEY_set_group = function(key: PEC_KEY; const group: PEC_GROUP): Integer; cdecl;
  TEC_KEY_get0_private_key = function(const key: PEC_KEY): PBIGNUM; cdecl;
  TEC_KEY_set_private_key = function(key: PEC_KEY; const prv: PBIGNUM): Integer; cdecl;
  TEC_KEY_get0_public_key = function(const key: PEC_KEY): PEC_POINT; cdecl;
  TEC_KEY_set_public_key = function(key: PEC_KEY; const pub: PEC_POINT): Integer; cdecl;
  
  TEC_KEY_get_enc_flags = function(const key: PEC_KEY): Cardinal; cdecl;
  TEC_KEY_set_enc_flags = procedure(eckey: PEC_KEY; flags: Cardinal); cdecl;
  TEC_KEY_get_conv_form = function(const key: PEC_KEY): point_conversion_form_t; cdecl;
  TEC_KEY_set_conv_form = procedure(eckey: PEC_KEY; cform: point_conversion_form_t); cdecl;
  
  TEC_KEY_get_key_method_data = function(key: PEC_KEY; dup_func: Pointer; free_func: Pointer; clear_free_func: Pointer): Pointer; cdecl;
  TEC_KEY_set_key_method_data = function(key: PEC_KEY; data: Pointer; dup_func: Pointer; free_func: Pointer; clear_free_func: Pointer): Pointer; cdecl;
  
  TEC_KEY_set_asn1_flag = procedure(eckey: PEC_KEY; asn1_flag: Integer); cdecl;
  TEC_KEY_precompute_mult = function(key: PEC_KEY; ctx: PBN_CTX): Integer; cdecl;
  TEC_KEY_generate_key = function(key: PEC_KEY): Integer; cdecl;
  TEC_KEY_check_key = function(const key: PEC_KEY): Integer; cdecl;
  TEC_KEY_can_sign = function(const eckey: PEC_KEY): Integer; cdecl;
  
  TEC_KEY_set_public_key_affine_coordinates = function(key: PEC_KEY; x: PBIGNUM; y: PBIGNUM): Integer; cdecl;
  TEC_KEY_key2buf = function(const key: PEC_KEY; form: point_conversion_form_t; var pbuf: PByte; ctx: PBN_CTX): NativeUInt; cdecl;
  TEC_KEY_oct2key = function(key: PEC_KEY; const buf: PByte; len: NativeUInt; ctx: PBN_CTX): Integer; cdecl;
  TEC_KEY_oct2priv = function(key: PEC_KEY; const buf: PByte; len: NativeUInt): Integer; cdecl;
  TEC_KEY_priv2oct = function(const key: PEC_KEY; buf: PByte; len: NativeUInt): NativeUInt; cdecl;
  TEC_KEY_priv2buf = function(const eckey: PEC_KEY; var pbuf: PByte): NativeUInt; cdecl;
  
  // EC_GROUP functions
  TEC_GROUP_new = function(const meth: PEC_METHOD): PEC_GROUP; cdecl;
  TEC_GROUP_new_from_ecparameters = function(const params: PECPARAMETERS): PEC_GROUP; cdecl;
  TEC_GROUP_new_from_ecpkparameters = function(const params: PECPKPARAMETERS): PEC_GROUP; cdecl;
  TEC_GROUP_free = procedure(group: PEC_GROUP); cdecl;
  TEC_GROUP_clear_free = procedure(group: PEC_GROUP); cdecl;
  TEC_GROUP_copy = function(dst: PEC_GROUP; const src: PEC_GROUP): Integer; cdecl;
  TEC_GROUP_dup = function(const src: PEC_GROUP): PEC_GROUP; cdecl;
  
  TEC_GROUP_method_of = function(const group: PEC_GROUP): PEC_METHOD; cdecl;
  TEC_METHOD_get_field_type = function(const meth: PEC_METHOD): Integer; cdecl;
  
  TEC_GROUP_set_generator = function(group: PEC_GROUP; const generator: PEC_POINT; const order: PBIGNUM; const cofactor: PBIGNUM): Integer; cdecl;
  TEC_GROUP_get0_generator = function(const group: PEC_GROUP): PEC_POINT; cdecl;
  TEC_GROUP_get_mont_data = function(const group: PEC_GROUP): PBN_MONT_CTX; cdecl;
  TEC_GROUP_get_order = function(const group: PEC_GROUP; order: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TEC_GROUP_get0_order = function(const group: PEC_GROUP): PBIGNUM; cdecl;
  TEC_GROUP_order_bits = function(const group: PEC_GROUP): Integer; cdecl;
  TEC_GROUP_get_cofactor = function(const group: PEC_GROUP; cofactor: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TEC_GROUP_get0_cofactor = function(const group: PEC_GROUP): PBIGNUM; cdecl;
  
  TEC_GROUP_set_curve_name = procedure(group: PEC_GROUP; nid: Integer); cdecl;
  TEC_GROUP_get_curve_name = function(const group: PEC_GROUP): Integer; cdecl;
  
  TEC_GROUP_set_asn1_flag = procedure(group: PEC_GROUP; flag: Integer); cdecl;
  TEC_GROUP_get_asn1_flag = function(const group: PEC_GROUP): Integer; cdecl;
  
  TEC_GROUP_set_point_conversion_form = procedure(group: PEC_GROUP; form: point_conversion_form_t); cdecl;
  TEC_GROUP_get_point_conversion_form = function(const group: PEC_GROUP): point_conversion_form_t; cdecl;
  
  TEC_GROUP_get0_seed = function(const x: PEC_GROUP): PByte; cdecl;
  TEC_GROUP_get_seed_len = function(const x: PEC_GROUP): NativeUInt; cdecl;
  TEC_GROUP_set_seed = function(x: PEC_GROUP; const p: PByte; len: NativeUInt): NativeUInt; cdecl;
  
  TEC_GROUP_set_curve = function(group: PEC_GROUP; const p: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TEC_GROUP_get_curve = function(const group: PEC_GROUP; p: PBIGNUM; a: PBIGNUM; b: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TEC_GROUP_set_curve_GFp = function(group: PEC_GROUP; const p: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TEC_GROUP_get_curve_GFp = function(const group: PEC_GROUP; p: PBIGNUM; a: PBIGNUM; b: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TEC_GROUP_set_curve_GF2m = function(group: PEC_GROUP; const p: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TEC_GROUP_get_curve_GF2m = function(const group: PEC_GROUP; p: PBIGNUM; a: PBIGNUM; b: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  
  TEC_GROUP_get_degree = function(const group: PEC_GROUP): Integer; cdecl;
  TEC_GROUP_check = function(const group: PEC_GROUP; ctx: PBN_CTX): Integer; cdecl;
  TEC_GROUP_check_discriminant = function(const group: PEC_GROUP; ctx: PBN_CTX): Integer; cdecl;
  
  TEC_GROUP_cmp = function(const a: PEC_GROUP; const b: PEC_GROUP; ctx: PBN_CTX): Integer; cdecl;
  
  TEC_GROUP_new_curve_GFp = function(const p: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM; ctx: PBN_CTX): PEC_GROUP; cdecl;
  TEC_GROUP_new_curve_GF2m = function(const p: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM; ctx: PBN_CTX): PEC_GROUP; cdecl;
  TEC_GROUP_new_by_curve_name = function(nid: Integer): PEC_GROUP; cdecl;
  TEC_GROUP_new_by_curve_name_ex = function(libctx: POSSL_LIB_CTX; const propq: PAnsiChar; nid: Integer): PEC_GROUP; cdecl;
  
  TEC_get_builtin_curves = function(r: PEC_builtin_curve; nitems: NativeUInt): NativeUInt; cdecl;
  
  TEC_curve_nid2nist = function(nid: Integer): PAnsiChar; cdecl;
  TEC_curve_nist2nid = function(const name: PAnsiChar): Integer; cdecl;
  TEC_GROUP_get_field_type = function(const group: PEC_GROUP): Integer; cdecl;
  
  // EC_POINT functions
  TEC_POINT_new = function(const group: PEC_GROUP): PEC_POINT; cdecl;
  TEC_POINT_free = procedure(point: PEC_POINT); cdecl;
  TEC_POINT_clear_free = procedure(point: PEC_POINT); cdecl;
  TEC_POINT_copy = function(dst: PEC_POINT; const src: PEC_POINT): Integer; cdecl;
  TEC_POINT_dup = function(const src: PEC_POINT; const group: PEC_GROUP): PEC_POINT; cdecl;
  
  TEC_POINT_method_of = function(const point: PEC_POINT): PEC_METHOD; cdecl;
  
  TEC_POINT_set_to_infinity = function(const group: PEC_GROUP; point: PEC_POINT): Integer; cdecl;
  TEC_POINT_set_Jprojective_coordinates_GFp = function(const group: PEC_GROUP; p: PEC_POINT; const x: PBIGNUM; const y: PBIGNUM; const z: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TEC_POINT_get_Jprojective_coordinates_GFp = function(const group: PEC_GROUP; const p: PEC_POINT; x: PBIGNUM; y: PBIGNUM; z: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TEC_POINT_set_affine_coordinates = function(const group: PEC_GROUP; p: PEC_POINT; const x: PBIGNUM; const y: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TEC_POINT_get_affine_coordinates = function(const group: PEC_GROUP; const p: PEC_POINT; x: PBIGNUM; y: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TEC_POINT_set_affine_coordinates_GFp = function(const group: PEC_GROUP; p: PEC_POINT; const x: PBIGNUM; const y: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TEC_POINT_get_affine_coordinates_GFp = function(const group: PEC_GROUP; const point: PEC_POINT; x: PBIGNUM; y: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TEC_POINT_set_affine_coordinates_GF2m = function(const group: PEC_GROUP; p: PEC_POINT; const x: PBIGNUM; const y: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TEC_POINT_get_affine_coordinates_GF2m = function(const group: PEC_GROUP; const point: PEC_POINT; x: PBIGNUM; y: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TEC_POINT_set_compressed_coordinates = function(const group: PEC_GROUP; p: PEC_POINT; const x: PBIGNUM; y_bit: Integer; ctx: PBN_CTX): Integer; cdecl;
  TEC_POINT_set_compressed_coordinates_GFp = function(const group: PEC_GROUP; p: PEC_POINT; const x: PBIGNUM; y_bit: Integer; ctx: PBN_CTX): Integer; cdecl;
  TEC_POINT_set_compressed_coordinates_GF2m = function(const group: PEC_GROUP; p: PEC_POINT; const x: PBIGNUM; y_bit: Integer; ctx: PBN_CTX): Integer; cdecl;
  
  TEC_POINT_point2oct = function(const group: PEC_GROUP; const p: PEC_POINT; form: point_conversion_form_t; buf: PByte; len: NativeUInt; ctx: PBN_CTX): NativeUInt; cdecl;
  TEC_POINT_oct2point = function(const group: PEC_GROUP; p: PEC_POINT; const buf: PByte; len: NativeUInt; ctx: PBN_CTX): Integer; cdecl;
  TEC_POINT_point2buf = function(const group: PEC_GROUP; const point: PEC_POINT; form: point_conversion_form_t; var pbuf: PByte; ctx: PBN_CTX): NativeUInt; cdecl;
  
  TEC_POINT_point2bn = function(const group: PEC_GROUP; const p: PEC_POINT; form: point_conversion_form_t; ret: PBIGNUM; ctx: PBN_CTX): PBIGNUM; cdecl;
  TEC_POINT_bn2point = function(const group: PEC_GROUP; const bn: PBIGNUM; p: PEC_POINT; ctx: PBN_CTX): PEC_POINT; cdecl;
  TEC_POINT_point2hex = function(const group: PEC_GROUP; const p: PEC_POINT; form: point_conversion_form_t; ctx: PBN_CTX): PAnsiChar; cdecl;
  TEC_POINT_hex2point = function(const group: PEC_GROUP; const hex: PAnsiChar; p: PEC_POINT; ctx: PBN_CTX): PEC_POINT; cdecl;
  
  TEC_POINT_add = function(const group: PEC_GROUP; r: PEC_POINT; const a: PEC_POINT; const b: PEC_POINT; ctx: PBN_CTX): Integer; cdecl;
  TEC_POINT_dbl = function(const group: PEC_GROUP; r: PEC_POINT; const a: PEC_POINT; ctx: PBN_CTX): Integer; cdecl;
  TEC_POINT_invert = function(const group: PEC_GROUP; a: PEC_POINT; ctx: PBN_CTX): Integer; cdecl;
  
  TEC_POINT_is_at_infinity = function(const group: PEC_GROUP; const p: PEC_POINT): Integer; cdecl;
  TEC_POINT_is_on_curve = function(const group: PEC_GROUP; const point: PEC_POINT; ctx: PBN_CTX): Integer; cdecl;
  TEC_POINT_cmp = function(const group: PEC_GROUP; const a: PEC_POINT; const b: PEC_POINT; ctx: PBN_CTX): Integer; cdecl;
  
  TEC_POINT_make_affine = function(const group: PEC_GROUP; point: PEC_POINT; ctx: PBN_CTX): Integer; cdecl;
  TEC_POINTs_make_affine = function(const group: PEC_GROUP; num: NativeUInt; points: PPEC_POINT; ctx: PBN_CTX): Integer; cdecl;
  
  TEC_POINTs_mul = function(const group: PEC_GROUP; r: PEC_POINT; const n: PBIGNUM; num: NativeUInt; const p: PPEC_POINT; const m: PPBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TEC_POINT_mul = function(const group: PEC_GROUP; r: PEC_POINT; const n: PBIGNUM; const q: PEC_POINT; const m: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  
  TEC_GROUP_precompute_mult = function(group: PEC_GROUP; ctx: PBN_CTX): Integer; cdecl;
  TEC_GROUP_have_precompute_mult = function(const group: PEC_GROUP): Integer; cdecl;
  
  // GFp/GF2m methods
  TEC_GFp_simple_method = function: PEC_METHOD; cdecl;
  TEC_GFp_mont_method = function: PEC_METHOD; cdecl;
  TEC_GFp_nist_method = function: PEC_METHOD; cdecl;
  TEC_GFp_nistp224_method = function: PEC_METHOD; cdecl;
  TEC_GFp_nistp256_method = function: PEC_METHOD; cdecl;
  TEC_GFp_nistp521_method = function: PEC_METHOD; cdecl;
  
  TEC_GF2m_simple_method = function: PEC_METHOD; cdecl;

var
  // Function pointers - will be loaded dynamically
  d2i_ECPrivateKey: Td2i_ECPrivateKey = nil;
  EC_KEY_new: TEC_KEY_new = nil;
  EC_KEY_new_by_curve_name: TEC_KEY_new_by_curve_name = nil;
  EC_KEY_free: TEC_KEY_free = nil;
  EC_KEY_copy: TEC_KEY_copy = nil;
  EC_KEY_dup: TEC_KEY_dup = nil;
  EC_KEY_up_ref: TEC_KEY_up_ref = nil;
  EC_KEY_get0_engine: TEC_KEY_get0_engine = nil;
  EC_KEY_get0_group: TEC_KEY_get0_group = nil;
  EC_KEY_set_group: TEC_KEY_set_group = nil;
  EC_KEY_get0_private_key: TEC_KEY_get0_private_key = nil;
  EC_KEY_set_private_key: TEC_KEY_set_private_key = nil;
  EC_KEY_get0_public_key: TEC_KEY_get0_public_key = nil;
  EC_KEY_set_public_key: TEC_KEY_set_public_key = nil;
  EC_KEY_generate_key: TEC_KEY_generate_key = nil;
  EC_KEY_check_key: TEC_KEY_check_key = nil;
  
  EC_GROUP_new_by_curve_name: TEC_GROUP_new_by_curve_name = nil;
  EC_GROUP_free: TEC_GROUP_free = nil;
  EC_GROUP_get_curve_name: TEC_GROUP_get_curve_name = nil;
  EC_GROUP_get_order: TEC_GROUP_get_order = nil;
  EC_GROUP_get_cofactor: TEC_GROUP_get_cofactor = nil;
  EC_GROUP_get_degree: TEC_GROUP_get_degree = nil;
  
  EC_POINT_new: TEC_POINT_new = nil;
  EC_POINT_free: TEC_POINT_free = nil;
  EC_POINT_copy: TEC_POINT_copy = nil;
  EC_POINT_dup: TEC_POINT_dup = nil;
  EC_POINT_set_affine_coordinates: TEC_POINT_set_affine_coordinates = nil;
  EC_POINT_get_affine_coordinates: TEC_POINT_get_affine_coordinates = nil;
  EC_POINT_point2oct: TEC_POINT_point2oct = nil;
  EC_POINT_oct2point: TEC_POINT_oct2point = nil;
  EC_POINT_add: TEC_POINT_add = nil;
  EC_POINT_dbl: TEC_POINT_dbl = nil;
  EC_POINT_mul: TEC_POINT_mul = nil;
  EC_POINT_cmp: TEC_POINT_cmp = nil;
  
  // ... declare all other function pointers

// Helper functions
function LoadECFunctions(ALibHandle: TOpenSSLLibHandle): Boolean;
procedure UnloadECFunctions;

// High-level helper functions
function EC_KEY_new_secp256k1: PEC_KEY;
function EC_KEY_new_prime256v1: PEC_KEY;
function EC_KEY_new_secp384r1: PEC_KEY;
function EC_KEY_new_secp521r1: PEC_KEY;
function EC_GROUP_get_curve_name_string(const group: PEC_GROUP): string;

implementation

uses nextpas.core.tls.openssl.api;

const
  { EC Function Bindings - 批量加载函数绑定定义 }
  EC_FUNCTION_BINDINGS: array[0..37] of TFunctionBinding = (
    // EC_KEY functions
    (Name: 'd2i_ECPrivateKey'; FuncPtr: @d2i_ECPrivateKey; Required: False),
    (Name: 'EC_KEY_new'; FuncPtr: @EC_KEY_new; Required: False),
    (Name: 'EC_KEY_new_by_curve_name'; FuncPtr: @EC_KEY_new_by_curve_name; Required: False),
    (Name: 'EC_KEY_free'; FuncPtr: @EC_KEY_free; Required: False),
    (Name: 'EC_KEY_copy'; FuncPtr: @EC_KEY_copy; Required: False),
    (Name: 'EC_KEY_dup'; FuncPtr: @EC_KEY_dup; Required: False),
    (Name: 'EC_KEY_up_ref'; FuncPtr: @EC_KEY_up_ref; Required: False),
    (Name: 'EC_KEY_get0_engine'; FuncPtr: @EC_KEY_get0_engine; Required: False),
    (Name: 'EC_KEY_get0_group'; FuncPtr: @EC_KEY_get0_group; Required: False),
    (Name: 'EC_KEY_set_group'; FuncPtr: @EC_KEY_set_group; Required: False),
    (Name: 'EC_KEY_get0_private_key'; FuncPtr: @EC_KEY_get0_private_key; Required: False),
    (Name: 'EC_KEY_set_private_key'; FuncPtr: @EC_KEY_set_private_key; Required: False),
    (Name: 'EC_KEY_get0_public_key'; FuncPtr: @EC_KEY_get0_public_key; Required: False),
    (Name: 'EC_KEY_set_public_key'; FuncPtr: @EC_KEY_set_public_key; Required: False),
    (Name: 'EC_KEY_generate_key'; FuncPtr: @EC_KEY_generate_key; Required: False),
    (Name: 'EC_KEY_check_key'; FuncPtr: @EC_KEY_check_key; Required: False),
    // EC_GROUP functions
    (Name: 'EC_GROUP_new_by_curve_name'; FuncPtr: @EC_GROUP_new_by_curve_name; Required: False),
    (Name: 'EC_GROUP_free'; FuncPtr: @EC_GROUP_free; Required: False),
    (Name: 'EC_GROUP_get_curve_name'; FuncPtr: @EC_GROUP_get_curve_name; Required: False),
    (Name: 'EC_GROUP_get_order'; FuncPtr: @EC_GROUP_get_order; Required: False),
    (Name: 'EC_GROUP_get_cofactor'; FuncPtr: @EC_GROUP_get_cofactor; Required: False),
    (Name: 'EC_GROUP_get_degree'; FuncPtr: @EC_GROUP_get_degree; Required: False),
    // EC_POINT functions
    (Name: 'EC_POINT_new'; FuncPtr: @EC_POINT_new; Required: False),
    (Name: 'EC_POINT_free'; FuncPtr: @EC_POINT_free; Required: False),
    (Name: 'EC_POINT_copy'; FuncPtr: @EC_POINT_copy; Required: False),
    (Name: 'EC_POINT_dup'; FuncPtr: @EC_POINT_dup; Required: False),
    (Name: 'EC_POINT_set_affine_coordinates'; FuncPtr: @EC_POINT_set_affine_coordinates; Required: False),
    (Name: 'EC_POINT_get_affine_coordinates'; FuncPtr: @EC_POINT_get_affine_coordinates; Required: False),
    (Name: 'EC_POINT_point2oct'; FuncPtr: @EC_POINT_point2oct; Required: False),
    (Name: 'EC_POINT_oct2point'; FuncPtr: @EC_POINT_oct2point; Required: False),
    (Name: 'EC_POINT_add'; FuncPtr: @EC_POINT_add; Required: False),
    (Name: 'EC_POINT_dbl'; FuncPtr: @EC_POINT_dbl; Required: False),
    (Name: 'EC_POINT_mul'; FuncPtr: @EC_POINT_mul; Required: False),
    (Name: 'EC_POINT_cmp'; FuncPtr: @EC_POINT_cmp; Required: False),
    // Legacy GFp/GF2m coordinate functions (fallback for older OpenSSL)
    (Name: 'EC_POINT_set_affine_coordinates_GFp'; FuncPtr: @EC_POINT_set_affine_coordinates; Required: False),
    (Name: 'EC_POINT_get_affine_coordinates_GFp'; FuncPtr: @EC_POINT_get_affine_coordinates; Required: False),
    (Name: 'EC_POINT_set_affine_coordinates_GF2m'; FuncPtr: @EC_POINT_set_affine_coordinates; Required: False),
    (Name: 'EC_POINT_get_affine_coordinates_GF2m'; FuncPtr: @EC_POINT_get_affine_coordinates; Required: False)
  );

function LoadECFunctions(ALibHandle: TOpenSSLLibHandle): Boolean;
var
  LLoadedCount: Integer;
begin
  Result := False;

  if ALibHandle = 0 then Exit;

  // 使用 TOpenSSLLoader.LoadFunctions 批量加载
  LLoadedCount := TOpenSSLLoader.LoadFunctions(ALibHandle, EC_FUNCTION_BINDINGS);

  // 至少加载了一些核心函数才算成功
  Result := LLoadedCount > 0;

  if Result then
    TOpenSSLLoader.SetModuleLoaded(osmEC, True);
end;

procedure UnloadECFunctions;
begin
  // 使用 TOpenSSLLoader.ClearFunctions 批量清除
  TOpenSSLLoader.ClearFunctions(EC_FUNCTION_BINDINGS);

  TOpenSSLLoader.SetModuleLoaded(osmEC, False);
end;


// Helper functions
function EC_KEY_new_secp256k1: PEC_KEY;
begin
  if Assigned(EC_KEY_new_by_curve_name) then
    Result := EC_KEY_new_by_curve_name(NID_secp256k1)
  else
    Result := nil;
end;

function EC_KEY_new_prime256v1: PEC_KEY;
begin
  if Assigned(EC_KEY_new_by_curve_name) then
    Result := EC_KEY_new_by_curve_name(NID_X9_62_prime256v1)
  else
    Result := nil;
end;

function EC_KEY_new_secp384r1: PEC_KEY;
begin
  if Assigned(EC_KEY_new_by_curve_name) then
    Result := EC_KEY_new_by_curve_name(NID_secp384r1)
  else
    Result := nil;
end;

function EC_KEY_new_secp521r1: PEC_KEY;
begin
  if Assigned(EC_KEY_new_by_curve_name) then
    Result := EC_KEY_new_by_curve_name(NID_secp521r1)
  else
    Result := nil;
end;

function EC_GROUP_get_curve_name_string(const group: PEC_GROUP): string;
var
  nid: Integer;
begin
  Result := '';
  if not Assigned(EC_GROUP_get_curve_name) then Exit;
  
  nid := EC_GROUP_get_curve_name(group);
  case nid of
    NID_secp112r1: Result := 'secp112r1';
    NID_secp112r2: Result := 'secp112r2';
    NID_secp128r1: Result := 'secp128r1';
    NID_secp128r2: Result := 'secp128r2';
    NID_secp160k1: Result := 'secp160k1';
    NID_secp160r1: Result := 'secp160r1';
    NID_secp160r2: Result := 'secp160r2';
    NID_secp192k1: Result := 'secp192k1';
    NID_secp224k1: Result := 'secp224k1';
    NID_secp224r1: Result := 'secp224r1';
    NID_secp256k1: Result := 'secp256k1';
    NID_secp384r1: Result := 'secp384r1';
    NID_secp521r1: Result := 'secp521r1';
    NID_X9_62_prime192v1: Result := 'prime192v1';
    NID_X9_62_prime256v1: Result := 'prime256v1';
    NID_brainpoolP256r1: Result := 'brainpoolP256r1';
    NID_brainpoolP384r1: Result := 'brainpoolP384r1';
    NID_brainpoolP512r1: Result := 'brainpoolP512r1';
    NID_X25519: Result := 'X25519';
    NID_X448: Result := 'X448';
    NID_ED25519: Result := 'ED25519';
    NID_ED448: Result := 'ED448';
  else
    Result := Format('Unknown(%d)', [nid]);
  end;
end;

end.
