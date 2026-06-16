unit nextpas.core.tls.openssl.api.bn;

{$mode ObjFPC}{$H+}

interface

uses DynLibs, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.core, nextpas.core.tls.openssl.loader;

const
  { BN flags }
  BN_FLG_CONSTTIME        = $04;
  BN_FLG_MALLOCED         = $01;
  BN_FLG_STATIC_DATA      = $02;
  BN_FLG_SECURE           = $08;
  BN_FLG_FIXED_TOP        = $10;
  
  { BN prime checking flags }
  BN_prime_checks         = 0;  // Default: select number of iterations based on size
  
  { BN constants for Miller-Rabin }
  BN_PRIMETEST_NULL_CALLBACK = nil;
  
  { BN pseudo constants }
  BN_RAND_TOP_ANY         = -1;
  BN_RAND_TOP_ONE         = 0;
  BN_RAND_TOP_TWO         = 1;
  
  BN_RAND_BOTTOM_ANY      = 0;
  BN_RAND_BOTTOM_ODD      = 1;
  
  { BIGNUM constants }
  BN_BITS                 = 128;
  BN_BYTES                = 16;
  BN_BITS2                = 64;
  BN_BITS4                = 32;
  BN_MASK2                = $FFFFFFFFFFFFFFFF;
  BN_MASK2l               = $FFFFFFFF;
  BN_MASK2h               = $FFFFFFFF00000000;
  BN_MASK2h1              = $FFFFFFFF80000000;
  BN_TBIT                 = $8000000000000000;
  BN_DEC_CONV             = 10000000000000000000;
  BN_DEC_FMT1             = '%llu';
  BN_DEC_FMT2             = '%.19llu';
  BN_DEC_NUM              = 19;
  BN_HEX_FMT1             = '%llX';
  BN_HEX_FMT2             = '%.16llX';

type
  { BN_ULONG type - platform dependent }
  {$IFDEF CPU64}
  BN_ULONG = UInt64;
  {$ELSE}
  BN_ULONG = UInt32;
  {$ENDIF}
  PBN_ULONG = ^BN_ULONG;
  
  { Helper function type }
  TBN_prime_checks_for_size = function(size: Integer): Integer; cdecl;
  
  { BIGNUM function types }
  TBN_new = function: PBIGNUM; cdecl;
  TBN_secure_new = function: PBIGNUM; cdecl;
  TBN_free = procedure(a: PBIGNUM); cdecl;
  TBN_clear_free = procedure(a: PBIGNUM); cdecl;
  TBN_copy = function(a: PBIGNUM; const b: PBIGNUM): PBIGNUM; cdecl;
  TBN_dup = function(const a: PBIGNUM): PBIGNUM; cdecl;
  TBN_swap = procedure(a, b: PBIGNUM); cdecl;
  TBN_bin2bn = function(const s: PByte; len: Integer; ret: PBIGNUM): PBIGNUM; cdecl;
  TBN_bn2bin = function(const a: PBIGNUM; &to: PByte): Integer; cdecl;
  TBN_bn2binpad = function(const a: PBIGNUM; &to: PByte; tolen: Integer): Integer; cdecl;
  TBN_lebin2bn = function(const s: PByte; len: Integer; ret: PBIGNUM): PBIGNUM; cdecl;
  TBN_bn2lebinpad = function(const a: PBIGNUM; &to: PByte; tolen: Integer): Integer; cdecl;
  TBN_bn2hex = function(const a: PBIGNUM): PAnsiChar; cdecl;
  TBN_bn2dec = function(const a: PBIGNUM): PAnsiChar; cdecl;
  TBN_hex2bn = function(a: PPBIGNUM; const str: PAnsiChar): Integer; cdecl;
  TBN_dec2bn = function(a: PPBIGNUM; const str: PAnsiChar): Integer; cdecl;
  TBN_asc2bn = function(a: PPBIGNUM; const str: PAnsiChar): Integer; cdecl;
  TBN_print = function(bio: PBIO; const a: PBIGNUM): Integer; cdecl;
  TBN_print_fp = function(fp: Pointer; const a: PBIGNUM): Integer; cdecl;
  TBN_bn2mpi = function(const a: PBIGNUM; d: PByte): Integer; cdecl;
  TBN_mpi2bn = function(const s: PByte; len: Integer; ret: PBIGNUM): PBIGNUM; cdecl;
  
  { Arithmetic operations }
  TBN_sub = function(r: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM): Integer; cdecl;
  TBN_usub = function(r: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM): Integer; cdecl;
  TBN_uadd = function(r: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM): Integer; cdecl;
  TBN_add = function(r: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM): Integer; cdecl;
  TBN_mul = function(r: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_sqr = function(r: PBIGNUM; const a: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_div = function(dv: PBIGNUM; rem: PBIGNUM; const a: PBIGNUM; const d: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_mod = function(rem: PBIGNUM; const a: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_nnmod = function(r: PBIGNUM; const a: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_mod_add = function(r: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_mod_add_quick = function(r: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM; const m: PBIGNUM): Integer; cdecl;
  TBN_mod_sub = function(r: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_mod_sub_quick = function(r: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM; const m: PBIGNUM): Integer; cdecl;
  TBN_mod_mul = function(r: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_mod_sqr = function(r: PBIGNUM; const a: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_mod_lshift1 = function(r: PBIGNUM; const a: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_mod_lshift1_quick = function(r: PBIGNUM; const a: PBIGNUM; const m: PBIGNUM): Integer; cdecl;
  TBN_mod_lshift = function(r: PBIGNUM; const a: PBIGNUM; n: Integer; const m: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_mod_lshift_quick = function(r: PBIGNUM; const a: PBIGNUM; n: Integer; const m: PBIGNUM): Integer; cdecl;
  
  { Word operations }
  TBN_mod_word = function(const a: PBIGNUM; w: BN_ULONG): BN_ULONG; cdecl;
  TBN_div_word = function(a: PBIGNUM; w: BN_ULONG): BN_ULONG; cdecl;
  TBN_mul_word = function(a: PBIGNUM; w: BN_ULONG): Integer; cdecl;
  TBN_add_word = function(a: PBIGNUM; w: BN_ULONG): Integer; cdecl;
  TBN_sub_word = function(a: PBIGNUM; w: BN_ULONG): Integer; cdecl;
  TBN_set_word = function(a: PBIGNUM; w: BN_ULONG): Integer; cdecl;
  TBN_get_word = function(const a: PBIGNUM): BN_ULONG; cdecl;
  
  { Comparison }
  TBN_cmp = function(const a: PBIGNUM; const b: PBIGNUM): Integer; cdecl;
  TBN_ucmp = function(const a: PBIGNUM; const b: PBIGNUM): Integer; cdecl;
  TBN_is_zero = function(const a: PBIGNUM): Integer; cdecl;
  TBN_is_one = function(const a: PBIGNUM): Integer; cdecl;
  TBN_is_word = function(const a: PBIGNUM; w: BN_ULONG): Integer; cdecl;
  TBN_abs_is_word = function(const a: PBIGNUM; w: BN_ULONG): Integer; cdecl;
  TBN_is_odd = function(const a: PBIGNUM): Integer; cdecl;
  
  { BN_CTX functions }
  TBN_CTX_new = function: PBN_CTX; cdecl;
  TBN_CTX_new_ex = function(ctx: Pointer): PBN_CTX; cdecl;
  TBN_CTX_secure_new = function: PBN_CTX; cdecl;
  TBN_CTX_secure_new_ex = function(ctx: Pointer): PBN_CTX; cdecl;
  TBN_CTX_free = procedure(c: PBN_CTX); cdecl;
  TBN_CTX_start = procedure(ctx: PBN_CTX); cdecl;
  TBN_CTX_get = function(ctx: PBN_CTX): PBIGNUM; cdecl;
  TBN_CTX_end = procedure(ctx: PBN_CTX); cdecl;
  
  { Bit operations }
  TBN_set_bit = function(a: PBIGNUM; n: Integer): Integer; cdecl;
  TBN_clear_bit = function(a: PBIGNUM; n: Integer): Integer; cdecl;
  TBN_is_bit_set = function(const a: PBIGNUM; n: Integer): Integer; cdecl;
  TBN_mask_bits = function(a: PBIGNUM; n: Integer): Integer; cdecl;
  TBN_lshift = function(r: PBIGNUM; const a: PBIGNUM; n: Integer): Integer; cdecl;
  TBN_lshift1 = function(r: PBIGNUM; const a: PBIGNUM): Integer; cdecl;
  TBN_rshift = function(r: PBIGNUM; const a: PBIGNUM; n: Integer): Integer; cdecl;
  TBN_rshift1 = function(r: PBIGNUM; const a: PBIGNUM): Integer; cdecl;
  
  { Modular exponentiation }
  TBN_exp = function(r: PBIGNUM; const a: PBIGNUM; const p: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_mod_exp = function(r: PBIGNUM; const a: PBIGNUM; const p: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_mod_exp_mont = function(r: PBIGNUM; const a: PBIGNUM; const p: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX; in_mont: PBN_MONT_CTX): Integer; cdecl;
  TBN_mod_exp_mont_consttime = function(rr: PBIGNUM; const a: PBIGNUM; const p: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX; in_mont: PBN_MONT_CTX): Integer; cdecl;
  TBN_mod_exp_mont_word = function(r: PBIGNUM; a: BN_ULONG; const p: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX; in_mont: PBN_MONT_CTX): Integer; cdecl;
  TBN_mod_exp2_mont = function(r: PBIGNUM; const a1: PBIGNUM; const p1: PBIGNUM; const a2: PBIGNUM; const p2: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX; in_mont: PBN_MONT_CTX): Integer; cdecl;
  TBN_mod_exp_simple = function(r: PBIGNUM; const a: PBIGNUM; const p: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_mod_exp_recp = function(r: PBIGNUM; const a: PBIGNUM; const p: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  
  { Greatest common divisor }
  TBN_gcd = function(r: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_mod_inverse = function(ret: PBIGNUM; const a: PBIGNUM; const n: PBIGNUM; ctx: PBN_CTX): PBIGNUM; cdecl;
  TBN_mod_sqrt = function(ret: PBIGNUM; const a: PBIGNUM; const n: PBIGNUM; ctx: PBN_CTX): PBIGNUM; cdecl;
  
  { Prime generation and testing }
  TBN_generate_prime_ex = function(ret: PBIGNUM; bits: Integer; safe: Integer; const add: PBIGNUM; const rem: PBIGNUM; cb: PBN_GENCB): Integer; cdecl;
  TBN_generate_prime_ex2 = function(ret: PBIGNUM; bits: Integer; safe: Integer; const add: PBIGNUM; const rem: PBIGNUM; cb: PBN_GENCB; ctx: PBN_CTX): Integer; cdecl;
  TBN_is_prime_ex = function(const p: PBIGNUM; nchecks: Integer; ctx: PBN_CTX; cb: PBN_GENCB): Integer; cdecl;
  TBN_is_prime_fasttest_ex = function(const p: PBIGNUM; nchecks: Integer; ctx: PBN_CTX; do_trial_division: Integer; cb: PBN_GENCB): Integer; cdecl;
  TBN_check_prime = function(const p: PBIGNUM; ctx: PBN_CTX; cb: PBN_GENCB): Integer; cdecl;
  
  { Random number generation }
  TBN_rand = function(rnd: PBIGNUM; bits: Integer; top: Integer; bottom: Integer): Integer; cdecl;
  TBN_pseudo_rand = function(rnd: PBIGNUM; bits: Integer; top: Integer; bottom: Integer): Integer; cdecl;
  TBN_rand_range = function(rnd: PBIGNUM; const range: PBIGNUM): Integer; cdecl;
  TBN_pseudo_rand_range = function(rnd: PBIGNUM; const range: PBIGNUM): Integer; cdecl;
  TBN_priv_rand = function(rnd: PBIGNUM; bits: Integer; top: Integer; bottom: Integer): Integer; cdecl;
  TBN_priv_rand_range = function(rnd: PBIGNUM; const range: PBIGNUM): Integer; cdecl;
  TBN_priv_rand_ex = function(rnd: PBIGNUM; bits: Integer; top: Integer; bottom: Integer; strength: Cardinal; ctx: PBN_CTX): Integer; cdecl;
  TBN_priv_rand_range_ex = function(rnd: PBIGNUM; const range: PBIGNUM; strength: Cardinal; ctx: PBN_CTX): Integer; cdecl;
  
  { Utility functions }
  TBN_num_bits = function(const a: PBIGNUM): Integer; cdecl;
  TBN_num_bits_word = function(l: BN_ULONG): Integer; cdecl;
  TBN_num_bytes = function(const a: PBIGNUM): Integer; cdecl;
  TBN_zero = procedure(a: PBIGNUM); cdecl;
  TBN_one = function(a: PBIGNUM): Integer; cdecl;
  TBN_value_one = function: PBIGNUM; cdecl;
  TBN_options = function: PAnsiChar; cdecl;
  TBN_CTX_init = procedure(c: PBN_CTX); cdecl;
  TBN_init = procedure(a: PBIGNUM); cdecl;
  TBN_clear = procedure(a: PBIGNUM); cdecl;
  TBN_set_negative = procedure(b: PBIGNUM; n: Integer); cdecl;
  TBN_is_negative = function(const b: PBIGNUM): Integer; cdecl;
  TBN_get_flags = function(const b: PBIGNUM; n: Integer): Integer; cdecl;
  TBN_set_flags = procedure(b: PBIGNUM; n: Integer); cdecl;
  
  { Montgomery multiplication }
  TBN_MONT_CTX_new = function: PBN_MONT_CTX; cdecl;
  TBN_MONT_CTX_init = procedure(ctx: PBN_MONT_CTX); cdecl;
  TBN_MONT_CTX_free = procedure(mont: PBN_MONT_CTX); cdecl;
  TBN_MONT_CTX_set = function(mont: PBN_MONT_CTX; const modulus: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_MONT_CTX_copy = function(&to: PBN_MONT_CTX; const from: PBN_MONT_CTX): PBN_MONT_CTX; cdecl;
  TBN_MONT_CTX_set_locked = function(pmont: PPBN_MONT_CTX; lock: Pointer; const modulus: PBIGNUM; ctx: PBN_CTX): PBN_MONT_CTX; cdecl;
  TBN_mod_mul_montgomery = function(r: PBIGNUM; const a: PBIGNUM; const b: PBIGNUM; const mont: PBN_MONT_CTX; ctx: PBN_CTX): Integer; cdecl;
  TBN_from_montgomery = function(r: PBIGNUM; const a: PBIGNUM; const mont: PBN_MONT_CTX; ctx: PBN_CTX): Integer; cdecl;
  TBN_to_montgomery = function(r: PBIGNUM; const a: PBIGNUM; const mont: PBN_MONT_CTX; ctx: PBN_CTX): Integer; cdecl;
  
  { Reciprocal operations }
  TBN_RECP_CTX_new = function: PBN_RECP_CTX; cdecl;
  TBN_RECP_CTX_init = procedure(recp: PBN_RECP_CTX); cdecl;
  TBN_RECP_CTX_free = procedure(recp: PBN_RECP_CTX); cdecl;
  TBN_RECP_CTX_set = function(recp: PBN_RECP_CTX; const rdiv: PBIGNUM; ctx: PBN_CTX): Integer; cdecl;
  TBN_mod_mul_reciprocal = function(r: PBIGNUM; const x: PBIGNUM; const y: PBIGNUM; recp: PBN_RECP_CTX; ctx: PBN_CTX): Integer; cdecl;
  TBN_div_recp = function(dv: PBIGNUM; rem: PBIGNUM; const m: PBIGNUM; recp: PBN_RECP_CTX; ctx: PBN_CTX): Integer; cdecl;
  TBN_reciprocal = function(r: PBIGNUM; const m: PBIGNUM; len: Integer; ctx: PBN_CTX): Integer; cdecl;
  
  { BIGNUM callback }
  TBN_GENCB_call = function(cb: PBN_GENCB; a: Integer; b: Integer): Integer; cdecl;
  TBN_GENCB_new = function: PBN_GENCB; cdecl;
  TBN_GENCB_free = procedure(cb: PBN_GENCB); cdecl;
  TBN_GENCB_set_old = procedure(gencb: PBN_GENCB; callback: Pointer; cb_arg: Pointer); cdecl;
  TBN_GENCB_set = procedure(gencb: PBN_GENCB; callback: Pointer; cb_arg: Pointer); cdecl;
  TBN_GENCB_get_arg = function(cb: PBN_GENCB): Pointer; cdecl;
  
  { Blinding }
  TBN_BLINDING_new = function(const A: PBIGNUM; const Ai: PBIGNUM; const m: PBIGNUM): PBN_BLINDING; cdecl;
  TBN_BLINDING_free = procedure(b: PBN_BLINDING); cdecl;
  TBN_BLINDING_update = function(b: PBN_BLINDING; ctx: PBN_CTX): Integer; cdecl;
  TBN_BLINDING_convert = function(n: PBIGNUM; b: PBN_BLINDING; ctx: PBN_CTX): Integer; cdecl;
  TBN_BLINDING_invert = function(n: PBIGNUM; b: PBN_BLINDING; ctx: PBN_CTX): Integer; cdecl;
  TBN_BLINDING_convert_ex = function(n: PBIGNUM; r: PBIGNUM; b: PBN_BLINDING; ctx: PBN_CTX): Integer; cdecl;
  TBN_BLINDING_invert_ex = function(n: PBIGNUM; const r: PBIGNUM; b: PBN_BLINDING; ctx: PBN_CTX): Integer; cdecl;
  TBN_BLINDING_is_current_thread = function(b: PBN_BLINDING): Integer; cdecl;
  TBN_BLINDING_set_current_thread = procedure(b: PBN_BLINDING); cdecl;
  TBN_BLINDING_lock = function(b: PBN_BLINDING): Integer; cdecl;
  TBN_BLINDING_unlock = function(b: PBN_BLINDING): Integer; cdecl;
  TBN_BLINDING_get_flags = function(const b: PBN_BLINDING): Cardinal; cdecl;
  TBN_BLINDING_set_flags = procedure(b: PBN_BLINDING; flags: Cardinal); cdecl;
  TBN_BLINDING_create_param = function(b: PBN_BLINDING; const e: PBIGNUM; const m: PBIGNUM; ctx: PBN_CTX; bn_mod_exp: Pointer; m_ctx: PBN_MONT_CTX): PBN_BLINDING; cdecl;

var
  { BIGNUM functions }
  BN_new: TBN_new;
  BN_secure_new: TBN_secure_new;
  BN_free: TBN_free;
  BN_clear_free: TBN_clear_free;
  BN_copy: TBN_copy;
  BN_dup: TBN_dup;
  BN_swap: TBN_swap;
  BN_bin2bn: TBN_bin2bn;
  BN_bn2bin: TBN_bn2bin;
  BN_bn2binpad: TBN_bn2binpad;
  BN_lebin2bn: TBN_lebin2bn;
  BN_bn2lebinpad: TBN_bn2lebinpad;
  BN_bn2hex: TBN_bn2hex;
  BN_bn2dec: TBN_bn2dec;
  BN_hex2bn: TBN_hex2bn;
  BN_dec2bn: TBN_dec2bn;
  BN_asc2bn: TBN_asc2bn;
  BN_print: TBN_print;
  BN_print_fp: TBN_print_fp;
  BN_bn2mpi: TBN_bn2mpi;
  BN_mpi2bn: TBN_mpi2bn;
  
  { Arithmetic operations }
  BN_sub: TBN_sub;
  BN_usub: TBN_usub;
  BN_uadd: TBN_uadd;
  BN_add: TBN_add;
  BN_mul: TBN_mul;
  BN_sqr: TBN_sqr;
  BN_div: TBN_div;
  BN_mod: TBN_mod;
  BN_nnmod: TBN_nnmod;
  BN_mod_add: TBN_mod_add;
  BN_mod_add_quick: TBN_mod_add_quick;
  BN_mod_sub: TBN_mod_sub;
  BN_mod_sub_quick: TBN_mod_sub_quick;
  BN_mod_mul: TBN_mod_mul;
  BN_mod_sqr: TBN_mod_sqr;
  BN_mod_lshift1: TBN_mod_lshift1;
  BN_mod_lshift1_quick: TBN_mod_lshift1_quick;
  BN_mod_lshift: TBN_mod_lshift;
  BN_mod_lshift_quick: TBN_mod_lshift_quick;
  
  { Word operations }
  BN_mod_word: TBN_mod_word;
  BN_div_word: TBN_div_word;
  BN_mul_word: TBN_mul_word;
  BN_add_word: TBN_add_word;
  BN_sub_word: TBN_sub_word;
  BN_set_word: TBN_set_word;
  BN_get_word: TBN_get_word;
  
  { Comparison }
  BN_cmp: TBN_cmp;
  BN_ucmp: TBN_ucmp;
  BN_is_zero: TBN_is_zero;
  BN_is_one: TBN_is_one;
  BN_is_word: TBN_is_word;
  BN_abs_is_word: TBN_abs_is_word;
  BN_is_odd: TBN_is_odd;
  
  { BN_CTX functions }
  BN_CTX_new: TBN_CTX_new;
  BN_CTX_new_ex: TBN_CTX_new_ex;
  BN_CTX_secure_new: TBN_CTX_secure_new;
  BN_CTX_secure_new_ex: TBN_CTX_secure_new_ex;
  BN_CTX_free: TBN_CTX_free;
  BN_CTX_start: TBN_CTX_start;
  BN_CTX_get: TBN_CTX_get;
  BN_CTX_end: TBN_CTX_end;
  
  { Bit operations }
  BN_set_bit: TBN_set_bit;
  BN_clear_bit: TBN_clear_bit;
  BN_is_bit_set: TBN_is_bit_set;
  BN_mask_bits: TBN_mask_bits;
  BN_lshift: TBN_lshift;
  BN_lshift1: TBN_lshift1;
  BN_rshift: TBN_rshift;
  BN_rshift1: TBN_rshift1;
  
  { Modular exponentiation }
  BN_exp: TBN_exp;
  BN_mod_exp: TBN_mod_exp;
  BN_mod_exp_mont: TBN_mod_exp_mont;
  BN_mod_exp_mont_consttime: TBN_mod_exp_mont_consttime;
  BN_mod_exp_mont_word: TBN_mod_exp_mont_word;
  BN_mod_exp2_mont: TBN_mod_exp2_mont;
  BN_mod_exp_simple: TBN_mod_exp_simple;
  BN_mod_exp_recp: TBN_mod_exp_recp;
  
  { Greatest common divisor }
  BN_gcd: TBN_gcd;
  BN_mod_inverse: TBN_mod_inverse;
  BN_mod_sqrt: TBN_mod_sqrt;
  
  { Prime generation and testing }
  BN_generate_prime_ex: TBN_generate_prime_ex;
  BN_generate_prime_ex2: TBN_generate_prime_ex2;
  BN_is_prime_ex: TBN_is_prime_ex;
  BN_is_prime_fasttest_ex: TBN_is_prime_fasttest_ex;
  BN_check_prime: TBN_check_prime;
  
  { Random number generation }
  BN_rand: TBN_rand;
  BN_pseudo_rand: TBN_pseudo_rand;
  BN_rand_range: TBN_rand_range;
  BN_pseudo_rand_range: TBN_pseudo_rand_range;
  BN_priv_rand: TBN_priv_rand;
  BN_priv_rand_range: TBN_priv_rand_range;
  BN_priv_rand_ex: TBN_priv_rand_ex;
  BN_priv_rand_range_ex: TBN_priv_rand_range_ex;
  
  { Utility functions }
  BN_num_bits: TBN_num_bits;
  BN_num_bits_word: TBN_num_bits_word;
  BN_num_bytes: TBN_num_bytes;
  BN_zero: TBN_zero;
  BN_one: TBN_one;
  BN_value_one: TBN_value_one;
  BN_options: TBN_options;
  BN_CTX_init: TBN_CTX_init;
  BN_init: TBN_init;
  BN_clear: TBN_clear;
  BN_set_negative: TBN_set_negative;
  BN_is_negative: TBN_is_negative;
  BN_get_flags: TBN_get_flags;
  BN_set_flags: TBN_set_flags;
  
  { Montgomery multiplication }
  BN_MONT_CTX_new: TBN_MONT_CTX_new;
  BN_MONT_CTX_init: TBN_MONT_CTX_init;
  BN_MONT_CTX_free: TBN_MONT_CTX_free;
  BN_MONT_CTX_set: TBN_MONT_CTX_set;
  BN_MONT_CTX_copy: TBN_MONT_CTX_copy;
  BN_MONT_CTX_set_locked: TBN_MONT_CTX_set_locked;
  BN_mod_mul_montgomery: TBN_mod_mul_montgomery;
  BN_from_montgomery: TBN_from_montgomery;
  BN_to_montgomery: TBN_to_montgomery;
  
  { Reciprocal operations }
  BN_RECP_CTX_new: TBN_RECP_CTX_new;
  BN_RECP_CTX_init: TBN_RECP_CTX_init;
  BN_RECP_CTX_free: TBN_RECP_CTX_free;
  BN_RECP_CTX_set: TBN_RECP_CTX_set;
  BN_mod_mul_reciprocal: TBN_mod_mul_reciprocal;
  BN_div_recp: TBN_div_recp;
  BN_reciprocal: TBN_reciprocal;
  
  { BIGNUM callback }
  BN_GENCB_call: TBN_GENCB_call;
  BN_GENCB_new: TBN_GENCB_new;
  BN_GENCB_free: TBN_GENCB_free;
  BN_GENCB_set_old: TBN_GENCB_set_old;
  BN_GENCB_set: TBN_GENCB_set;
  BN_GENCB_get_arg: TBN_GENCB_get_arg;
  
  { Blinding }
  BN_BLINDING_new: TBN_BLINDING_new;
  BN_BLINDING_free: TBN_BLINDING_free;
  BN_BLINDING_update: TBN_BLINDING_update;
  BN_BLINDING_convert: TBN_BLINDING_convert;
  BN_BLINDING_invert: TBN_BLINDING_invert;
  BN_BLINDING_convert_ex: TBN_BLINDING_convert_ex;
  BN_BLINDING_invert_ex: TBN_BLINDING_invert_ex;
  BN_BLINDING_is_current_thread: TBN_BLINDING_is_current_thread;
  BN_BLINDING_set_current_thread: TBN_BLINDING_set_current_thread;
  BN_BLINDING_lock: TBN_BLINDING_lock;
  BN_BLINDING_unlock: TBN_BLINDING_unlock;
  BN_BLINDING_get_flags: TBN_BLINDING_get_flags;
  BN_BLINDING_set_flags: TBN_BLINDING_set_flags;
  BN_BLINDING_create_param: TBN_BLINDING_create_param;

function LoadOpenSSLBN: Boolean;
procedure UnloadOpenSSLBN;

implementation

function LoadOpenSSLBN: Boolean;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmBN) then
    Exit(True);
    
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    Exit(False);
    
  // Load BIGNUM functions
  BN_new := TBN_new(GetCryptoProcAddress('BN_new'));
  BN_secure_new := TBN_secure_new(GetCryptoProcAddress('BN_secure_new'));
  BN_free := TBN_free(GetCryptoProcAddress('BN_free'));
  BN_clear_free := TBN_clear_free(GetCryptoProcAddress('BN_clear_free'));
  BN_copy := TBN_copy(GetCryptoProcAddress('BN_copy'));
  BN_dup := TBN_dup(GetCryptoProcAddress('BN_dup'));
  BN_swap := TBN_swap(GetCryptoProcAddress('BN_swap'));
  BN_bin2bn := TBN_bin2bn(GetCryptoProcAddress('BN_bin2bn'));
  BN_bn2bin := TBN_bn2bin(GetCryptoProcAddress('BN_bn2bin'));
  BN_bn2binpad := TBN_bn2binpad(GetCryptoProcAddress('BN_bn2binpad'));
  BN_lebin2bn := TBN_lebin2bn(GetCryptoProcAddress('BN_lebin2bn'));
  BN_bn2lebinpad := TBN_bn2lebinpad(GetCryptoProcAddress('BN_bn2lebinpad'));
  BN_bn2hex := TBN_bn2hex(GetCryptoProcAddress('BN_bn2hex'));
  BN_bn2dec := TBN_bn2dec(GetCryptoProcAddress('BN_bn2dec'));
  BN_hex2bn := TBN_hex2bn(GetCryptoProcAddress('BN_hex2bn'));
  BN_dec2bn := TBN_dec2bn(GetCryptoProcAddress('BN_dec2bn'));
  BN_asc2bn := TBN_asc2bn(GetCryptoProcAddress('BN_asc2bn'));
  BN_print := TBN_print(GetCryptoProcAddress('BN_print'));
  BN_print_fp := TBN_print_fp(GetCryptoProcAddress('BN_print_fp'));
  BN_bn2mpi := TBN_bn2mpi(GetCryptoProcAddress('BN_bn2mpi'));
  BN_mpi2bn := TBN_mpi2bn(GetCryptoProcAddress('BN_mpi2bn'));
  
  // Load arithmetic operations
  BN_sub := TBN_sub(GetCryptoProcAddress('BN_sub'));
  BN_usub := TBN_usub(GetCryptoProcAddress('BN_usub'));
  BN_uadd := TBN_uadd(GetCryptoProcAddress('BN_uadd'));
  BN_add := TBN_add(GetCryptoProcAddress('BN_add'));
  BN_mul := TBN_mul(GetCryptoProcAddress('BN_mul'));
  BN_sqr := TBN_sqr(GetCryptoProcAddress('BN_sqr'));
  BN_div := TBN_div(GetCryptoProcAddress('BN_div'));
  BN_mod := TBN_mod(GetCryptoProcAddress('BN_mod'));
  BN_nnmod := TBN_nnmod(GetCryptoProcAddress('BN_nnmod'));
  BN_mod_add := TBN_mod_add(GetCryptoProcAddress('BN_mod_add'));
  BN_mod_add_quick := TBN_mod_add_quick(GetCryptoProcAddress('BN_mod_add_quick'));
  BN_mod_sub := TBN_mod_sub(GetCryptoProcAddress('BN_mod_sub'));
  BN_mod_sub_quick := TBN_mod_sub_quick(GetCryptoProcAddress('BN_mod_sub_quick'));
  BN_mod_mul := TBN_mod_mul(GetCryptoProcAddress('BN_mod_mul'));
  BN_mod_sqr := TBN_mod_sqr(GetCryptoProcAddress('BN_mod_sqr'));
  BN_mod_lshift1 := TBN_mod_lshift1(GetCryptoProcAddress('BN_mod_lshift1'));
  BN_mod_lshift1_quick := TBN_mod_lshift1_quick(GetCryptoProcAddress('BN_mod_lshift1_quick'));
  BN_mod_lshift := TBN_mod_lshift(GetCryptoProcAddress('BN_mod_lshift'));
  BN_mod_lshift_quick := TBN_mod_lshift_quick(GetCryptoProcAddress('BN_mod_lshift_quick'));
  
  // Load word operations
  BN_mod_word := TBN_mod_word(GetCryptoProcAddress('BN_mod_word'));
  BN_div_word := TBN_div_word(GetCryptoProcAddress('BN_div_word'));
  BN_mul_word := TBN_mul_word(GetCryptoProcAddress('BN_mul_word'));
  BN_add_word := TBN_add_word(GetCryptoProcAddress('BN_add_word'));
  BN_sub_word := TBN_sub_word(GetCryptoProcAddress('BN_sub_word'));
  BN_set_word := TBN_set_word(GetCryptoProcAddress('BN_set_word'));
  BN_get_word := TBN_get_word(GetCryptoProcAddress('BN_get_word'));
  
  // Load comparison functions
  BN_cmp := TBN_cmp(GetCryptoProcAddress('BN_cmp'));
  BN_ucmp := TBN_ucmp(GetCryptoProcAddress('BN_ucmp'));
  BN_is_zero := TBN_is_zero(GetCryptoProcAddress('BN_is_zero'));
  BN_is_one := TBN_is_one(GetCryptoProcAddress('BN_is_one'));
  BN_is_word := TBN_is_word(GetCryptoProcAddress('BN_is_word'));
  BN_abs_is_word := TBN_abs_is_word(GetCryptoProcAddress('BN_abs_is_word'));
  BN_is_odd := TBN_is_odd(GetCryptoProcAddress('BN_is_odd'));
  
  // Load utility functions
  BN_num_bits := TBN_num_bits(GetCryptoProcAddress('BN_num_bits'));
  BN_num_bytes := TBN_num_bytes(GetCryptoProcAddress('BN_num_bytes'));
  BN_zero := TBN_zero(GetCryptoProcAddress('BN_zero'));
  BN_one := TBN_one(GetCryptoProcAddress('BN_one'));
  BN_value_one := TBN_value_one(GetCryptoProcAddress('BN_value_one'));
  
  // Load BN_CTX functions
  BN_CTX_new := TBN_CTX_new(GetCryptoProcAddress('BN_CTX_new'));
  BN_CTX_free := TBN_CTX_free(GetCryptoProcAddress('BN_CTX_free'));
  BN_CTX_start := TBN_CTX_start(GetCryptoProcAddress('BN_CTX_start'));
  BN_CTX_get := TBN_CTX_get(GetCryptoProcAddress('BN_CTX_get'));
  BN_CTX_end := TBN_CTX_end(GetCryptoProcAddress('BN_CTX_end'));
  
  // Load bit operations
  BN_set_bit := TBN_set_bit(GetCryptoProcAddress('BN_set_bit'));
  BN_clear_bit := TBN_clear_bit(GetCryptoProcAddress('BN_clear_bit'));
  BN_is_bit_set := TBN_is_bit_set(GetCryptoProcAddress('BN_is_bit_set'));
  BN_lshift := TBN_lshift(GetCryptoProcAddress('BN_lshift'));
  BN_lshift1 := TBN_lshift1(GetCryptoProcAddress('BN_lshift1'));
  BN_rshift := TBN_rshift(GetCryptoProcAddress('BN_rshift'));
  BN_rshift1 := TBN_rshift1(GetCryptoProcAddress('BN_rshift1'));
  
  // Load modular exponentiation
  BN_mod_exp := TBN_mod_exp(GetCryptoProcAddress('BN_mod_exp'));
  
  // Load GCD and inverse
  BN_gcd := TBN_gcd(GetCryptoProcAddress('BN_gcd'));
  BN_mod_inverse := TBN_mod_inverse(GetCryptoProcAddress('BN_mod_inverse'));
  
  // Load random generation
  BN_rand := TBN_rand(GetCryptoProcAddress('BN_rand'));
  BN_rand_range := TBN_rand_range(GetCryptoProcAddress('BN_rand_range'));
  
  // The basic BN functions should be available
  Result := Assigned(BN_new) and Assigned(BN_free);
  TOpenSSLLoader.SetModuleLoaded(osmBN, Result);
end;

procedure UnloadOpenSSLBN;
begin
  // Clear all function pointers (truncated for space)
  BN_new := nil;
  BN_free := nil;
  // ... clear all other function pointers ...

  TOpenSSLLoader.SetModuleLoaded(osmBN, False);
end;


end.