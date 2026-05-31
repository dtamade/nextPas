unit nextpas.core.tls.openssl.api.asn1;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Classes, dynlibs,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader;

type
  // ASN.1 类型定义
  ASN1_TYPE = Pointer;
  ASN1_OBJECT = Pointer;
  ASN1_STRING = Pointer;
  ASN1_OCTET_STRING = Pointer;
  ASN1_BIT_STRING = Pointer;
  ASN1_INTEGER = Pointer;
  ASN1_ENUMERATED = Pointer;
  ASN1_GENERALIZEDTIME = Pointer;
  ASN1_UTCTIME = Pointer;
  ASN1_TIME = Pointer;
  ASN1_GENERALSTRING = Pointer;
  ASN1_VISIBLESTRING = Pointer;
  ASN1_PRINTABLESTRING = Pointer;
  ASN1_T61STRING = Pointer;
  ASN1_IA5STRING = Pointer;
  ASN1_UTF8STRING = Pointer;
  ASN1_BMPSTRING = Pointer;
  ASN1_UNIVERSALSTRING = Pointer;
  ASN1_NULL = Pointer;
  ASN1_BOOLEAN = Integer;
  ASN1_VALUE = Pointer;
  ASN1_ITEM = Pointer;
  ASN1_PCTX = Pointer;
  ASN1_SCTX = Pointer;

  PASN1_TYPE = ^ASN1_TYPE;
  PASN1_OBJECT = ^ASN1_OBJECT;
  PASN1_STRING = ^ASN1_STRING;
  PASN1_OCTET_STRING = ^ASN1_OCTET_STRING;
  PASN1_BIT_STRING = ^ASN1_BIT_STRING;
  PASN1_INTEGER = ^ASN1_INTEGER;
  PASN1_TIME = ^ASN1_TIME;
  PASN1_ITEM = ^ASN1_ITEM;

  // ASN.1 标签定义
  const
    V_ASN1_EOC                     = 0;
    V_ASN1_BOOLEAN                 = 1;
    V_ASN1_INTEGER                 = 2;
    V_ASN1_BIT_STRING              = 3;
    V_ASN1_OCTET_STRING            = 4;
    V_ASN1_NULL                    = 5;
    V_ASN1_OBJECT                  = 6;
    V_ASN1_OBJECT_DESCRIPTOR       = 7;
    V_ASN1_EXTERNAL                = 8;
    V_ASN1_REAL                    = 9;
    V_ASN1_ENUMERATED              = 10;
    V_ASN1_UTF8STRING              = 12;
    V_ASN1_SEQUENCE                = 16;
    V_ASN1_SET                     = 17;
    V_ASN1_NUMERICSTRING           = 18;
    V_ASN1_PRINTABLESTRING         = 19;
    V_ASN1_T61STRING               = 20;
    V_ASN1_TELETEXSTRING           = 20;
    V_ASN1_VIDEOTEXSTRING          = 21;
    V_ASN1_IA5STRING               = 22;
    V_ASN1_UTCTIME                 = 23;
    V_ASN1_GENERALIZEDTIME         = 24;
    V_ASN1_GRAPHICSTRING           = 25;
    V_ASN1_ISO64STRING             = 26;
    V_ASN1_VISIBLESTRING           = 26;
    V_ASN1_GENERALSTRING           = 27;
    V_ASN1_UNIVERSALSTRING         = 28;
    V_ASN1_BMPSTRING               = 30;

    // ASN.1 标志
    ASN1_STRING_FLAG_BITS_LEFT     = $08;
    ASN1_STRING_FLAG_NDEF          = $010;
    ASN1_STRING_FLAG_CONT          = $020;
    ASN1_STRING_FLAG_MSTRING       = $040;
    ASN1_STRING_FLAG_EMBED         = $080;
    ASN1_STRING_FLAG_X509_TIME     = $100;

  // ASN.1 函数类型
  type
    // 对象函数
    TASN1_OBJECT_new = function(): ASN1_OBJECT; cdecl;
    TASN1_OBJECT_free = procedure(a: ASN1_OBJECT); cdecl;
    TASN1_OBJECT_create = function(nid: Integer; const data: PByte; len: Integer;
      const sn, ln: PAnsiChar): ASN1_OBJECT; cdecl;
    Td2i_ASN1_OBJECT = function(a: PPASN1_OBJECT; const pp: PPByte; len: Integer): ASN1_OBJECT; cdecl;
    Ti2d_ASN1_OBJECT = function(a: ASN1_OBJECT; pp: PPByte): Integer; cdecl;

    // 字符串函数
    TASN1_STRING_new = function(): ASN1_STRING; cdecl;
    TASN1_STRING_free = procedure(a: ASN1_STRING); cdecl;
    TASN1_STRING_type_new = function(atype: Integer): ASN1_STRING; cdecl;
    TASN1_STRING_set = function(str: ASN1_STRING; const data: Pointer; len: Integer): Integer; cdecl;
    TASN1_STRING_set0 = procedure(str: ASN1_STRING; data: Pointer; len: Integer); cdecl;
    TASN1_STRING_length = function(const x: ASN1_STRING): Integer; cdecl;
    TASN1_STRING_get0_data = function(const x: ASN1_STRING): PByte; cdecl;
    TASN1_STRING_data = function(x: ASN1_STRING): PByte; cdecl;
    TASN1_STRING_type = function(const x: ASN1_STRING): Integer; cdecl;
    TASN1_STRING_copy = function(dst: ASN1_STRING; const src: ASN1_STRING): Integer; cdecl;
    TASN1_STRING_dup = function(const a: ASN1_STRING): ASN1_STRING; cdecl;
    TASN1_STRING_cmp = function(const a, b: ASN1_STRING): Integer; cdecl;
    TASN1_STRING_print_ex = function(out_: PBIO; const str: ASN1_STRING; flags: Cardinal): Integer; cdecl;
    TASN1_STRING_print_ex_fp = function(fp: Pointer; const str: ASN1_STRING; flags: Cardinal): Integer; cdecl;

    // 整数函数
    TASN1_INTEGER_new = function(): ASN1_INTEGER; cdecl;
    TASN1_INTEGER_free = procedure(a: ASN1_INTEGER); cdecl;
    TASN1_INTEGER_get = function(const a: ASN1_INTEGER): Integer; cdecl;
    TASN1_INTEGER_set = function(a: ASN1_INTEGER; v: Integer): Integer; cdecl;
    TASN1_INTEGER_get_int64 = function(pr: PInt64; const a: ASN1_INTEGER): Integer; cdecl;
    TASN1_INTEGER_set_int64 = function(a: ASN1_INTEGER; r: Int64): Integer; cdecl;
    TASN1_INTEGER_get_uint64 = function(pr: PUInt64; const a: ASN1_INTEGER): Integer; cdecl;
    TASN1_INTEGER_set_uint64 = function(a: ASN1_INTEGER; r: UInt64): Integer; cdecl;
    TASN1_INTEGER_dup = function(const x: ASN1_INTEGER): ASN1_INTEGER; cdecl;
    TASN1_INTEGER_cmp = function(const x, y: ASN1_INTEGER): Integer; cdecl;
    TBN_to_ASN1_INTEGER = function(const bn: PBIGNUM; ai: ASN1_INTEGER): ASN1_INTEGER; cdecl;
    TASN1_INTEGER_to_BN = function(const ai: ASN1_INTEGER; bn: PBIGNUM): PBIGNUM; cdecl;

    // 时间函数
    TASN1_TIME_new = function(): ASN1_TIME; cdecl;
    TASN1_TIME_free = procedure(a: ASN1_TIME); cdecl;
    TASN1_TIME_set = function(s: ASN1_TIME; t: time_t): ASN1_TIME; cdecl;
    TASN1_TIME_set_string = function(s: ASN1_TIME; const str: PAnsiChar): Integer; cdecl;
    TASN1_TIME_check = function(const t: ASN1_TIME): Integer; cdecl;
    TASN1_TIME_print = function(bp: PBIO; const tm: ASN1_TIME): Integer; cdecl;
    TASN1_TIME_to_tm = function(const s: ASN1_TIME; tm: Pointer): Integer; cdecl;
    TASN1_TIME_normalize = function(s: ASN1_TIME): Integer; cdecl;
    TASN1_TIME_cmp_time_t = function(const s: ASN1_TIME; t: time_t): Integer; cdecl;
    TASN1_TIME_compare = function(const a, b: ASN1_TIME): Integer; cdecl;

    // UTCTIME 函数
    TASN1_UTCTIME_new = function(): ASN1_UTCTIME; cdecl;
    TASN1_UTCTIME_free = procedure(a: ASN1_UTCTIME); cdecl;
    TASN1_UTCTIME_set = function(s: ASN1_UTCTIME; t: time_t): ASN1_UTCTIME; cdecl;
    TASN1_UTCTIME_set_string = function(s: ASN1_UTCTIME; const str: PAnsiChar): Integer; cdecl;
    TASN1_UTCTIME_check = function(const a: ASN1_UTCTIME): Integer; cdecl;
    TASN1_UTCTIME_print = function(bp: PBIO; const tm: ASN1_UTCTIME): Integer; cdecl;

    // GENERALIZEDTIME 函数
    TASN1_GENERALIZEDTIME_new = function(): ASN1_GENERALIZEDTIME; cdecl;
    TASN1_GENERALIZEDTIME_free = procedure(a: ASN1_GENERALIZEDTIME); cdecl;
    TASN1_GENERALIZEDTIME_set = function(s: ASN1_GENERALIZEDTIME; t: time_t): ASN1_GENERALIZEDTIME; cdecl;
    TASN1_GENERALIZEDTIME_set_string = function(s: ASN1_GENERALIZEDTIME; const str: PAnsiChar): Integer; cdecl;
    TASN1_GENERALIZEDTIME_check = function(const a: ASN1_GENERALIZEDTIME): Integer; cdecl;
    TASN1_GENERALIZEDTIME_print = function(bp: PBIO; const tm: ASN1_GENERALIZEDTIME): Integer; cdecl;

    // OCTET STRING 函数
    TASN1_OCTET_STRING_new = function(): ASN1_OCTET_STRING; cdecl;
    TASN1_OCTET_STRING_free = procedure(a: ASN1_OCTET_STRING); cdecl;
    TASN1_OCTET_STRING_set = function(str: ASN1_OCTET_STRING; const data: PByte; len: Integer): Integer; cdecl;
    TASN1_OCTET_STRING_dup = function(const a: ASN1_OCTET_STRING): ASN1_OCTET_STRING; cdecl;
    TASN1_OCTET_STRING_cmp = function(const a, b: ASN1_OCTET_STRING): Integer; cdecl;

    // BIT STRING 函数
    TASN1_BIT_STRING_new = function(): ASN1_BIT_STRING; cdecl;
    TASN1_BIT_STRING_free = procedure(a: ASN1_BIT_STRING); cdecl;
    TASN1_BIT_STRING_set = function(a: ASN1_BIT_STRING; d: PByte; len: Integer): Integer; cdecl;
    TASN1_BIT_STRING_set_bit = function(a: ASN1_BIT_STRING; n: Integer; value: Integer): Integer; cdecl;
    TASN1_BIT_STRING_get_bit = function(const a: ASN1_BIT_STRING; n: Integer): Integer; cdecl;
    TASN1_BIT_STRING_check = function(const a: ASN1_BIT_STRING; const flags: PByte; flags_len: Integer): Integer; cdecl;

    // 类型转换函数
    TASN1_TYPE_new = function(): ASN1_TYPE; cdecl;
    TASN1_TYPE_free = procedure(a: ASN1_TYPE); cdecl;
    TASN1_TYPE_get = function(const a: ASN1_TYPE): Integer; cdecl;
    TASN1_TYPE_set = procedure(a: ASN1_TYPE; atype: Integer; value: Pointer); cdecl;
    TASN1_TYPE_set1 = function(a: ASN1_TYPE; atype: Integer; const value: Pointer): Integer; cdecl;
    TASN1_TYPE_cmp = function(const a, b: ASN1_TYPE): Integer; cdecl;
    TASN1_TYPE_pack_sequence = function(const it: ASN1_ITEM; s: Pointer; t: PPASN1_TYPE): ASN1_TYPE; cdecl;
    TASN1_TYPE_unpack_sequence = function(const it: ASN1_ITEM; const t: ASN1_TYPE): Pointer; cdecl;

    // DER/PEM 编解码
    Td2i_ASN1_TYPE = function(a: PPASN1_TYPE; const pp: PPByte; len: Integer): ASN1_TYPE; cdecl;
    Ti2d_ASN1_TYPE = function(a: ASN1_TYPE; out_: PPByte): Integer; cdecl;
    TASN1_item_d2i = function(val: PPointer; const in_: PPByte; len: Integer; const it: ASN1_ITEM): Pointer; cdecl;
    TASN1_item_i2d = function(val: Pointer; out_: PPByte; const it: ASN1_ITEM): Integer; cdecl;
    TASN1_item_new = function(const it: ASN1_ITEM): Pointer; cdecl;
    TASN1_item_free = procedure(val: Pointer; const it: ASN1_ITEM); cdecl;
    TASN1_item_dup = function(const it: ASN1_ITEM; x: Pointer): Pointer; cdecl;

    // 打印和调试函数
    TASN1_item_print = function(out_: PBIO; ifld: Pointer; indent: Integer; const it: ASN1_ITEM; const pctx: ASN1_PCTX): Integer; cdecl;
    TASN1_parse = function(bp: PBIO; const pp: PByte; len: Integer; indent: Integer): Integer; cdecl;
    TASN1_parse_dump = function(bp: PBIO; const pp: PByte; len: Integer; indent, dump: Integer): Integer; cdecl;

    // 标签和长度函数
    TASN1_get_object = function(const pp: PPByte; plength: PInteger; ptag: PInteger; pclass: PInteger; omax: Integer): Integer; cdecl;
    TASN1_check_infinite_end = function(p: PPByte; len: Integer): Integer; cdecl;
    TASN1_const_check_infinite_end = function(const p: PPByte; len: Integer): Integer; cdecl;
    TASN1_put_object = procedure(pp: PPByte; constructed: Integer; length: Integer; tag: Integer; xclass: Integer); cdecl;
    TASN1_put_eoc = function(pp: PPByte): Integer; cdecl;
    TASN1_object_size = function(constructed: Integer; length: Integer; tag: Integer): Integer; cdecl;

var
  // 对象函数
  ASN1_OBJECT_new: TASN1_OBJECT_new = nil;
  ASN1_OBJECT_free: TASN1_OBJECT_free = nil;
  ASN1_OBJECT_create: TASN1_OBJECT_create = nil;
  d2i_ASN1_OBJECT: Td2i_ASN1_OBJECT = nil;
  i2d_ASN1_OBJECT: Ti2d_ASN1_OBJECT = nil;

  // 字符串函数
  ASN1_STRING_new: TASN1_STRING_new = nil;
  ASN1_STRING_free: TASN1_STRING_free = nil;
  ASN1_STRING_type_new: TASN1_STRING_type_new = nil;
  ASN1_STRING_set: TASN1_STRING_set = nil;
  ASN1_STRING_set0: TASN1_STRING_set0 = nil;
  ASN1_STRING_length: TASN1_STRING_length = nil;
  ASN1_STRING_get0_data: TASN1_STRING_get0_data = nil;
  ASN1_STRING_data: TASN1_STRING_data = nil;
  ASN1_STRING_type: TASN1_STRING_type = nil;
  ASN1_STRING_copy: TASN1_STRING_copy = nil;
  ASN1_STRING_dup: TASN1_STRING_dup = nil;
  ASN1_STRING_cmp: TASN1_STRING_cmp = nil;
  ASN1_STRING_print_ex: TASN1_STRING_print_ex = nil;
  ASN1_STRING_print_ex_fp: TASN1_STRING_print_ex_fp = nil;

  // 整数函数
  ASN1_INTEGER_new: TASN1_INTEGER_new = nil;
  ASN1_INTEGER_free: TASN1_INTEGER_free = nil;
  ASN1_INTEGER_get: TASN1_INTEGER_get = nil;
  ASN1_INTEGER_set: TASN1_INTEGER_set = nil;
  ASN1_INTEGER_get_int64: TASN1_INTEGER_get_int64 = nil;
  ASN1_INTEGER_set_int64: TASN1_INTEGER_set_int64 = nil;
  ASN1_INTEGER_get_uint64: TASN1_INTEGER_get_uint64 = nil;
  ASN1_INTEGER_set_uint64: TASN1_INTEGER_set_uint64 = nil;
  ASN1_INTEGER_dup: TASN1_INTEGER_dup = nil;
  ASN1_INTEGER_cmp: TASN1_INTEGER_cmp = nil;
  BN_to_ASN1_INTEGER: TBN_to_ASN1_INTEGER = nil;
  ASN1_INTEGER_to_BN: TASN1_INTEGER_to_BN = nil;

  // 时间函数
  ASN1_TIME_new: TASN1_TIME_new = nil;
  ASN1_TIME_free: TASN1_TIME_free = nil;
  ASN1_TIME_set: TASN1_TIME_set = nil;
  ASN1_TIME_set_string: TASN1_TIME_set_string = nil;
  ASN1_TIME_check: TASN1_TIME_check = nil;
  ASN1_TIME_print: TASN1_TIME_print = nil;
  ASN1_TIME_to_tm: TASN1_TIME_to_tm = nil;
  ASN1_TIME_normalize: TASN1_TIME_normalize = nil;
  ASN1_TIME_cmp_time_t: TASN1_TIME_cmp_time_t = nil;
  ASN1_TIME_compare: TASN1_TIME_compare = nil;

  // UTCTIME 函数
  ASN1_UTCTIME_new: TASN1_UTCTIME_new = nil;
  ASN1_UTCTIME_free: TASN1_UTCTIME_free = nil;
  ASN1_UTCTIME_set: TASN1_UTCTIME_set = nil;
  ASN1_UTCTIME_set_string: TASN1_UTCTIME_set_string = nil;
  ASN1_UTCTIME_check: TASN1_UTCTIME_check = nil;
  ASN1_UTCTIME_print: TASN1_UTCTIME_print = nil;

  // GENERALIZEDTIME 函数
  ASN1_GENERALIZEDTIME_new: TASN1_GENERALIZEDTIME_new = nil;
  ASN1_GENERALIZEDTIME_free: TASN1_GENERALIZEDTIME_free = nil;
  ASN1_GENERALIZEDTIME_set: TASN1_GENERALIZEDTIME_set = nil;
  ASN1_GENERALIZEDTIME_set_string: TASN1_GENERALIZEDTIME_set_string = nil;
  ASN1_GENERALIZEDTIME_check: TASN1_GENERALIZEDTIME_check = nil;
  ASN1_GENERALIZEDTIME_print: TASN1_GENERALIZEDTIME_print = nil;

  // OCTET STRING 函数
  ASN1_OCTET_STRING_new: TASN1_OCTET_STRING_new = nil;
  ASN1_OCTET_STRING_free: TASN1_OCTET_STRING_free = nil;
  ASN1_OCTET_STRING_set: TASN1_OCTET_STRING_set = nil;
  ASN1_OCTET_STRING_dup: TASN1_OCTET_STRING_dup = nil;
  ASN1_OCTET_STRING_cmp: TASN1_OCTET_STRING_cmp = nil;

  // BIT STRING 函数
  ASN1_BIT_STRING_new: TASN1_BIT_STRING_new = nil;
  ASN1_BIT_STRING_free: TASN1_BIT_STRING_free = nil;
  ASN1_BIT_STRING_set: TASN1_BIT_STRING_set = nil;
  ASN1_BIT_STRING_set_bit: TASN1_BIT_STRING_set_bit = nil;
  ASN1_BIT_STRING_get_bit: TASN1_BIT_STRING_get_bit = nil;
  ASN1_BIT_STRING_check: TASN1_BIT_STRING_check = nil;

  // 类型函数
  ASN1_TYPE_new: TASN1_TYPE_new = nil;
  ASN1_TYPE_free: TASN1_TYPE_free = nil;
  ASN1_TYPE_get: TASN1_TYPE_get = nil;
  ASN1_TYPE_set: TASN1_TYPE_set = nil;
  ASN1_TYPE_set1: TASN1_TYPE_set1 = nil;
  ASN1_TYPE_cmp: TASN1_TYPE_cmp = nil;
  ASN1_TYPE_pack_sequence: TASN1_TYPE_pack_sequence = nil;
  ASN1_TYPE_unpack_sequence: TASN1_TYPE_unpack_sequence = nil;

  // DER/PEM 编解码
  d2i_ASN1_TYPE: Td2i_ASN1_TYPE = nil;
  i2d_ASN1_TYPE: Ti2d_ASN1_TYPE = nil;
  ASN1_item_d2i: TASN1_item_d2i = nil;
  ASN1_item_i2d: TASN1_item_i2d = nil;
  ASN1_item_new: TASN1_item_new = nil;
  ASN1_item_free: TASN1_item_free = nil;
  ASN1_item_dup: TASN1_item_dup = nil;

  // 打印和调试
  ASN1_item_print: TASN1_item_print = nil;
  ASN1_parse: TASN1_parse = nil;
  ASN1_parse_dump: TASN1_parse_dump = nil;

  // 标签和长度
  ASN1_get_object: TASN1_get_object = nil;
  ASN1_check_infinite_end: TASN1_check_infinite_end = nil;
  ASN1_const_check_infinite_end: TASN1_const_check_infinite_end = nil;
  ASN1_put_object: TASN1_put_object = nil;
  ASN1_put_eoc: TASN1_put_eoc = nil;
  ASN1_object_size: TASN1_object_size = nil;

// 加载和卸载函数
function LoadOpenSSLASN1(const ACryptoLib: THandle): Boolean;
procedure UnloadOpenSSLASN1;

// 辅助函数
function ASN1StringToString(const AStr: ASN1_STRING): string;
function StringToASN1String(const AStr: string; AType: Integer = V_ASN1_UTF8STRING): ASN1_STRING;
function ASN1TimeToDateTime(const ATime: ASN1_TIME): TDateTime;
function DateTimeToASN1Time(const ADateTime: TDateTime): ASN1_TIME;

implementation

const
  // ASN1 函数绑定数组
  ASN1_FUNCTION_BINDINGS: array[0..87] of TFunctionBinding = (
    // 对象函数
    (Name: 'ASN1_OBJECT_new'; FuncPtr: @ASN1_OBJECT_new; Required: False),
    (Name: 'ASN1_OBJECT_free'; FuncPtr: @ASN1_OBJECT_free; Required: False),
    (Name: 'ASN1_OBJECT_create'; FuncPtr: @ASN1_OBJECT_create; Required: False),
    (Name: 'd2i_ASN1_OBJECT'; FuncPtr: @d2i_ASN1_OBJECT; Required: False),
    (Name: 'i2d_ASN1_OBJECT'; FuncPtr: @i2d_ASN1_OBJECT; Required: False),
    // 字符串函数
    (Name: 'ASN1_STRING_new'; FuncPtr: @ASN1_STRING_new; Required: True),
    (Name: 'ASN1_STRING_free'; FuncPtr: @ASN1_STRING_free; Required: True),
    (Name: 'ASN1_STRING_type_new'; FuncPtr: @ASN1_STRING_type_new; Required: False),
    (Name: 'ASN1_STRING_set'; FuncPtr: @ASN1_STRING_set; Required: False),
    (Name: 'ASN1_STRING_set0'; FuncPtr: @ASN1_STRING_set0; Required: False),
    (Name: 'ASN1_STRING_length'; FuncPtr: @ASN1_STRING_length; Required: False),
    (Name: 'ASN1_STRING_get0_data'; FuncPtr: @ASN1_STRING_get0_data; Required: False),
    (Name: 'ASN1_STRING_data'; FuncPtr: @ASN1_STRING_data; Required: False),
    (Name: 'ASN1_STRING_type'; FuncPtr: @ASN1_STRING_type; Required: False),
    (Name: 'ASN1_STRING_copy'; FuncPtr: @ASN1_STRING_copy; Required: False),
    (Name: 'ASN1_STRING_dup'; FuncPtr: @ASN1_STRING_dup; Required: False),
    (Name: 'ASN1_STRING_cmp'; FuncPtr: @ASN1_STRING_cmp; Required: False),
    (Name: 'ASN1_STRING_print_ex'; FuncPtr: @ASN1_STRING_print_ex; Required: False),
    (Name: 'ASN1_STRING_print_ex_fp'; FuncPtr: @ASN1_STRING_print_ex_fp; Required: False),
    // 整数函数
    (Name: 'ASN1_INTEGER_new'; FuncPtr: @ASN1_INTEGER_new; Required: False),
    (Name: 'ASN1_INTEGER_free'; FuncPtr: @ASN1_INTEGER_free; Required: False),
    (Name: 'ASN1_INTEGER_get'; FuncPtr: @ASN1_INTEGER_get; Required: False),
    (Name: 'ASN1_INTEGER_set'; FuncPtr: @ASN1_INTEGER_set; Required: False),
    (Name: 'ASN1_INTEGER_get_int64'; FuncPtr: @ASN1_INTEGER_get_int64; Required: False),
    (Name: 'ASN1_INTEGER_set_int64'; FuncPtr: @ASN1_INTEGER_set_int64; Required: False),
    (Name: 'ASN1_INTEGER_get_uint64'; FuncPtr: @ASN1_INTEGER_get_uint64; Required: False),
    (Name: 'ASN1_INTEGER_set_uint64'; FuncPtr: @ASN1_INTEGER_set_uint64; Required: False),
    (Name: 'ASN1_INTEGER_dup'; FuncPtr: @ASN1_INTEGER_dup; Required: False),
    (Name: 'ASN1_INTEGER_cmp'; FuncPtr: @ASN1_INTEGER_cmp; Required: False),
    (Name: 'BN_to_ASN1_INTEGER'; FuncPtr: @BN_to_ASN1_INTEGER; Required: False),
    (Name: 'ASN1_INTEGER_to_BN'; FuncPtr: @ASN1_INTEGER_to_BN; Required: False),
    // 时间函数
    (Name: 'ASN1_TIME_new'; FuncPtr: @ASN1_TIME_new; Required: False),
    (Name: 'ASN1_TIME_free'; FuncPtr: @ASN1_TIME_free; Required: False),
    (Name: 'ASN1_TIME_set'; FuncPtr: @ASN1_TIME_set; Required: False),
    (Name: 'ASN1_TIME_set_string'; FuncPtr: @ASN1_TIME_set_string; Required: False),
    (Name: 'ASN1_TIME_check'; FuncPtr: @ASN1_TIME_check; Required: False),
    (Name: 'ASN1_TIME_print'; FuncPtr: @ASN1_TIME_print; Required: False),
    (Name: 'ASN1_TIME_to_tm'; FuncPtr: @ASN1_TIME_to_tm; Required: False),
    (Name: 'ASN1_TIME_normalize'; FuncPtr: @ASN1_TIME_normalize; Required: False),
    (Name: 'ASN1_TIME_cmp_time_t'; FuncPtr: @ASN1_TIME_cmp_time_t; Required: False),
    (Name: 'ASN1_TIME_compare'; FuncPtr: @ASN1_TIME_compare; Required: False),
    // UTCTIME 函数
    (Name: 'ASN1_UTCTIME_new'; FuncPtr: @ASN1_UTCTIME_new; Required: False),
    (Name: 'ASN1_UTCTIME_free'; FuncPtr: @ASN1_UTCTIME_free; Required: False),
    (Name: 'ASN1_UTCTIME_set'; FuncPtr: @ASN1_UTCTIME_set; Required: False),
    (Name: 'ASN1_UTCTIME_set_string'; FuncPtr: @ASN1_UTCTIME_set_string; Required: False),
    (Name: 'ASN1_UTCTIME_check'; FuncPtr: @ASN1_UTCTIME_check; Required: False),
    (Name: 'ASN1_UTCTIME_print'; FuncPtr: @ASN1_UTCTIME_print; Required: False),
    // GENERALIZEDTIME 函数
    (Name: 'ASN1_GENERALIZEDTIME_new'; FuncPtr: @ASN1_GENERALIZEDTIME_new; Required: False),
    (Name: 'ASN1_GENERALIZEDTIME_free'; FuncPtr: @ASN1_GENERALIZEDTIME_free; Required: False),
    (Name: 'ASN1_GENERALIZEDTIME_set'; FuncPtr: @ASN1_GENERALIZEDTIME_set; Required: False),
    (Name: 'ASN1_GENERALIZEDTIME_set_string'; FuncPtr: @ASN1_GENERALIZEDTIME_set_string; Required: False),
    (Name: 'ASN1_GENERALIZEDTIME_check'; FuncPtr: @ASN1_GENERALIZEDTIME_check; Required: False),
    (Name: 'ASN1_GENERALIZEDTIME_print'; FuncPtr: @ASN1_GENERALIZEDTIME_print; Required: False),
    // OCTET STRING 函数
    (Name: 'ASN1_OCTET_STRING_new'; FuncPtr: @ASN1_OCTET_STRING_new; Required: False),
    (Name: 'ASN1_OCTET_STRING_free'; FuncPtr: @ASN1_OCTET_STRING_free; Required: False),
    (Name: 'ASN1_OCTET_STRING_set'; FuncPtr: @ASN1_OCTET_STRING_set; Required: False),
    (Name: 'ASN1_OCTET_STRING_dup'; FuncPtr: @ASN1_OCTET_STRING_dup; Required: False),
    (Name: 'ASN1_OCTET_STRING_cmp'; FuncPtr: @ASN1_OCTET_STRING_cmp; Required: False),
    // BIT STRING 函数
    (Name: 'ASN1_BIT_STRING_new'; FuncPtr: @ASN1_BIT_STRING_new; Required: False),
    (Name: 'ASN1_BIT_STRING_free'; FuncPtr: @ASN1_BIT_STRING_free; Required: False),
    (Name: 'ASN1_BIT_STRING_set'; FuncPtr: @ASN1_BIT_STRING_set; Required: False),
    (Name: 'ASN1_BIT_STRING_set_bit'; FuncPtr: @ASN1_BIT_STRING_set_bit; Required: False),
    (Name: 'ASN1_BIT_STRING_get_bit'; FuncPtr: @ASN1_BIT_STRING_get_bit; Required: False),
    (Name: 'ASN1_BIT_STRING_check'; FuncPtr: @ASN1_BIT_STRING_check; Required: False),
    // 类型函数
    (Name: 'ASN1_TYPE_new'; FuncPtr: @ASN1_TYPE_new; Required: False),
    (Name: 'ASN1_TYPE_free'; FuncPtr: @ASN1_TYPE_free; Required: False),
    (Name: 'ASN1_TYPE_get'; FuncPtr: @ASN1_TYPE_get; Required: False),
    (Name: 'ASN1_TYPE_set'; FuncPtr: @ASN1_TYPE_set; Required: False),
    (Name: 'ASN1_TYPE_set1'; FuncPtr: @ASN1_TYPE_set1; Required: False),
    (Name: 'ASN1_TYPE_cmp'; FuncPtr: @ASN1_TYPE_cmp; Required: False),
    (Name: 'ASN1_TYPE_pack_sequence'; FuncPtr: @ASN1_TYPE_pack_sequence; Required: False),
    (Name: 'ASN1_TYPE_unpack_sequence'; FuncPtr: @ASN1_TYPE_unpack_sequence; Required: False),
    // DER/PEM 编解码
    (Name: 'd2i_ASN1_TYPE'; FuncPtr: @d2i_ASN1_TYPE; Required: False),
    (Name: 'i2d_ASN1_TYPE'; FuncPtr: @i2d_ASN1_TYPE; Required: False),
    (Name: 'ASN1_item_d2i'; FuncPtr: @ASN1_item_d2i; Required: False),
    (Name: 'ASN1_item_i2d'; FuncPtr: @ASN1_item_i2d; Required: False),
    (Name: 'ASN1_item_new'; FuncPtr: @ASN1_item_new; Required: False),
    (Name: 'ASN1_item_free'; FuncPtr: @ASN1_item_free; Required: False),
    (Name: 'ASN1_item_dup'; FuncPtr: @ASN1_item_dup; Required: False),
    // 打印和调试
    (Name: 'ASN1_item_print'; FuncPtr: @ASN1_item_print; Required: False),
    (Name: 'ASN1_parse'; FuncPtr: @ASN1_parse; Required: False),
    (Name: 'ASN1_parse_dump'; FuncPtr: @ASN1_parse_dump; Required: False),
    // 标签和长度
    (Name: 'ASN1_get_object'; FuncPtr: @ASN1_get_object; Required: False),
    (Name: 'ASN1_check_infinite_end'; FuncPtr: @ASN1_check_infinite_end; Required: False),
    (Name: 'ASN1_const_check_infinite_end'; FuncPtr: @ASN1_const_check_infinite_end; Required: False),
    (Name: 'ASN1_put_object'; FuncPtr: @ASN1_put_object; Required: False),
    (Name: 'ASN1_put_eoc'; FuncPtr: @ASN1_put_eoc; Required: False),
    (Name: 'ASN1_object_size'; FuncPtr: @ASN1_object_size; Required: False)
  );

// 辅助函数 - 将 TDateTime 转换为 Unix 时间戳
function DateTimeToUnixCustom(ADateTime: TDateTime): time_t;
const
  UnixEpoch: TDateTime = 25569; // 1970-01-01 在 TDateTime 中的值
begin
  Result := time_t(Trunc((ADateTime - UnixEpoch) * 86400));
end;

// 辅助函数 - 手动计算 TDateTime 不依赖 DateUtils
function EncodeDateTimeCustom(Year, Month, Day, Hour, Min, Sec, MSec: Word): TDateTime;
const
  DaysInMonth: array[1..12] of Word = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
var
  i: Integer;
  Days: Double;
begin
  // 计算从公元 1 年 1 月 1 日开始的天数
  Days := 0;

  // 加上前几年的天数
  for i := 1 to Year - 1 do
  begin
    if IsLeapYear(i) then
      Days := Days + 366
    else
      Days := Days + 365;
  end;

  // 加上今年前几个月的天数
  for i := 1 to Month - 1 do
  begin
    Days := Days + DaysInMonth[i];
    if (i = 2) and IsLeapYear(Year) then
      Days := Days + 1; // 闰年 2 月
  end;

  // 加上本月天数
  Days := Days + (Day - 1);

  // 转换为 TDateTime（天的小数部分）
  Result := Trunc(Days) + ((Hour * 3600 + Min * 60 + Sec) / 86400.0);
end;

function LoadOpenSSLASN1(const ACryptoLib: THandle): Boolean;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmASN1) then
    Exit(True);

  if ACryptoLib = 0 then
    Exit(False);

  // 使用批量加载模式
  TOpenSSLLoader.LoadFunctions(ACryptoLib, ASN1_FUNCTION_BINDINGS);

  TOpenSSLLoader.SetModuleLoaded(osmASN1, Assigned(ASN1_STRING_new) and Assigned(ASN1_STRING_free));
  Result := TOpenSSLLoader.IsModuleLoaded(osmASN1);
end;

procedure UnloadOpenSSLASN1;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmASN1) then
    Exit;

  // 使用批量清理模式
  TOpenSSLLoader.ClearFunctions(ASN1_FUNCTION_BINDINGS);

  TOpenSSLLoader.SetModuleLoaded(osmASN1, False);
end;

// 辅助函数实现
function ASN1StringToString(const AStr: ASN1_STRING): string;
var
  Len: Integer;
  Data: PByte;
begin
  Result := '';
  if AStr = nil then
    Exit;

  Len := ASN1_STRING_length(AStr);
  if Assigned(ASN1_STRING_get0_data) then
    Data := ASN1_STRING_get0_data(AStr)
  else
    Data := ASN1_STRING_data(AStr);

  if (Data <> nil) and (Len > 0) then
  begin
    SetLength(Result, Len);
    Move(Data^, Result[1], Len);
  end;
end;

function StringToASN1String(const AStr: string; AType: Integer): ASN1_STRING;
begin
  Result := ASN1_STRING_type_new(AType);
  if Result <> nil then
  begin
    if ASN1_STRING_set(Result, PAnsiChar(AnsiString(AStr)), Length(AStr)) = 0 then
    begin
      ASN1_STRING_free(Result);
      Result := nil;
    end;
  end;
end;

function ASN1TimeToDateTime(const ATime: ASN1_TIME): TDateTime;
var
  TimeStr: string;
  Year, Month, Day, Hour, Min, Sec: Integer;
  TimeType: Integer;
begin
  Result := 0;
  if ATime = nil then
    Exit;

  TimeStr := ASN1StringToString(ASN1_STRING(ATime));
  TimeType := ASN1_STRING_type(ASN1_STRING(ATime));

  if TimeType = V_ASN1_UTCTIME then
  begin
    // YYMMDDHHMMSSZ 格式
    if Length(TimeStr) >= 12 then
    begin
      Year := StrToIntDef(Copy(TimeStr, 1, 2), 0);
      if Year < 50 then
        Year := 2000 + Year
      else
        Year := 1900 + Year;
      Month := StrToIntDef(Copy(TimeStr, 3, 2), 1);
      Day := StrToIntDef(Copy(TimeStr, 5, 2), 1);
      Hour := StrToIntDef(Copy(TimeStr, 7, 2), 0);
      Min := StrToIntDef(Copy(TimeStr, 9, 2), 0);
      Sec := StrToIntDef(Copy(TimeStr, 11, 2), 0);
      try
        Result := EncodeDate(Year, Month, Day) + EncodeTime(Hour, Min, Sec, 0);
      except
        Result := 0;
      end;
    end;
  end
  else if TimeType = V_ASN1_GENERALIZEDTIME then
  begin
    // YYYYMMDDHHMMSSZ 格式
    if Length(TimeStr) >= 14 then
    begin
      Year := StrToIntDef(Copy(TimeStr, 1, 4), 0);
      Month := StrToIntDef(Copy(TimeStr, 5, 2), 1);
      Day := StrToIntDef(Copy(TimeStr, 7, 2), 1);
      Hour := StrToIntDef(Copy(TimeStr, 9, 2), 0);
      Min := StrToIntDef(Copy(TimeStr, 11, 2), 0);
      Sec := StrToIntDef(Copy(TimeStr, 13, 2), 0);
      try
        Result := EncodeDate(Year, Month, Day) + EncodeTime(Hour, Min, Sec, 0);
      except
        Result := 0;
      end;
    end;
  end;
end;

function DateTimeToASN1Time(const ADateTime: TDateTime): ASN1_TIME;
var
  UnixTime: time_t;
begin
  UnixTime := DateTimeToUnixCustom(ADateTime);
  Result := ASN1_TIME_set(nil, UnixTime);
end;

end.