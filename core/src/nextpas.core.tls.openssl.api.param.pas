{******************************************************************************}
{                                                                              }
{  nextpas.core.tls.openssl.api.param - OpenSSL 3.0+ OSSL_PARAM Module Pascal Binding   }
{                                                                              }
{  Copyright (c) 2024 fafafa                                                  }
{                                                                              }
{******************************************************************************}
unit nextpas.core.tls.openssl.api.param;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.bn, nextpas.core.tls.openssl.api.consts; const OSSL_PARAM_END = 0;
  OSSL_PARAM_INTEGER = 1;
  OSSL_PARAM_UNSIGNED_INTEGER = 2; 
  OSSL_PARAM_REAL = 3;
  OSSL_PARAM_UTF8_STRING = 4;
  OSSL_PARAM_OCTET_STRING = 5;
  OSSL_PARAM_UTF8_PTR = 6;
  OSSL_PARAM_OCTET_PTR = 7;

type
  { OSSL_PARAM structure }
  OSSL_PARAM = record
    key: PChar;
    data_type: TOpenSSLUInt;
    data: Pointer;
    data_size: TOpenSSLSizeT;
    return_size: TOpenSSLSizeT;
  end;
  POSSL_PARAM = ^OSSL_PARAM;
  PPOSSL_PARAM = ^POSSL_PARAM;

  { OSSL_PARAM_BLD structure }
  OSSL_PARAM_BLD = record end;
  POSSL_PARAM_BLD = ^OSSL_PARAM_BLD;

  { Callback types }
  TOSSL_PARAM_modified_fn = procedure(const params: POSSL_PARAM; arg: Pointer); cdecl;

  { Function pointers for dynamic loading }
  { OSSL_PARAM construction functions }
  TOSSLPARAMInit = function(key: PChar): OSSL_PARAM; cdecl;
  TOSSLPARAMConstruct = function(key: PChar; data_type: TOpenSSLUInt;
                                data: Pointer; data_size: TOpenSSLSizeT): OSSL_PARAM; cdecl;
  TOSSLPARAMConstructInt = function(key: PChar; val: POpenSSLInt): OSSL_PARAM; cdecl;
  TOSSLPARAMConstructUInt = function(key: PChar; val: POpenSSLUInt): OSSL_PARAM; cdecl;
  TOSSLPARAMConstructLong = function(key: PChar; val: POpenSSLLong): OSSL_PARAM; cdecl;
  TOSSLPARAMConstructULong = function(key: PChar; val: POpenSSLULong): OSSL_PARAM; cdecl;
  TOSSLPARAMConstructInt32 = function(key: PChar; val: PInt32): OSSL_PARAM; cdecl;
  TOSSLPARAMConstructUInt32 = function(key: PChar; val: PUInt32): OSSL_PARAM; cdecl;
  TOSSLPARAMConstructInt64 = function(key: PChar; val: PInt64): OSSL_PARAM; cdecl;
  TOSSLPARAMConstructUInt64 = function(key: PChar; val: PUInt64): OSSL_PARAM; cdecl;
  TOSSLPARAMConstructSizeT = function(key: PChar; val: POpenSSLSizeT): OSSL_PARAM; cdecl;
  TOSSLPARAMConstructBN = function(key: PChar; buf: PByte; bsize: TOpenSSLSizeT): OSSL_PARAM; cdecl;
  TOSSLPARAMConstructDouble = function(key: PChar; val: PDouble): OSSL_PARAM; cdecl;
  TOSSLPARAMConstructUtf8String = function(key: PChar; buf: PChar; bsize: TOpenSSLSizeT): OSSL_PARAM; cdecl;
  TOSSLPARAMConstructUtf8Ptr = function(key: PChar; buf: PPChar; bsize: TOpenSSLSizeT): OSSL_PARAM; cdecl;
  TOSSLPARAMConstructOctetString = function(key: PChar; buf: Pointer; bsize: TOpenSSLSizeT): OSSL_PARAM; cdecl;
  TOSSLPARAMConstructOctetPtr = function(key: PChar; buf: PPointer; bsize: TOpenSSLSizeT): OSSL_PARAM; cdecl;
  TOSSLPARAMConstructEnd = function: OSSL_PARAM; cdecl;
  
  { OSSL_PARAM get functions }
  TOSSLPARAMGetInt = function(const p: POSSL_PARAM; val: POpenSSLInt): TOpenSSLInt; cdecl;
  TOSSLPARAMGetUInt = function(const p: POSSL_PARAM; val: POpenSSLUInt): TOpenSSLInt; cdecl;
  TOSSLPARAMGetLong = function(const p: POSSL_PARAM; val: POpenSSLLong): TOpenSSLInt; cdecl;
  TOSSLPARAMGetULong = function(const p: POSSL_PARAM; val: POpenSSLULong): TOpenSSLInt; cdecl;
  TOSSLPARAMGetInt32 = function(const p: POSSL_PARAM; val: PInt32): TOpenSSLInt; cdecl;
  TOSSLPARAMGetUInt32 = function(const p: POSSL_PARAM; val: PUInt32): TOpenSSLInt; cdecl;
  TOSSLPARAMGetInt64 = function(const p: POSSL_PARAM; val: PInt64): TOpenSSLInt; cdecl;
  TOSSLPARAMGetUInt64 = function(const p: POSSL_PARAM; val: PUInt64): TOpenSSLInt; cdecl;
  TOSSLPARAMGetSizeT = function(const p: POSSL_PARAM; val: POpenSSLSizeT): TOpenSSLInt; cdecl;
  TOSSLPARAMGetBN = function(const p: POSSL_PARAM; val: PPBIGNUM): TOpenSSLInt; cdecl;
  TOSSLPARAMGetDouble = function(const p: POSSL_PARAM; val: PDouble): TOpenSSLInt; cdecl;
  TOSSLPARAMGetUtf8String = function(const p: POSSL_PARAM; val: PPChar; max_len: TOpenSSLSizeT): TOpenSSLInt; cdecl;
  TOSSLPARAMGetUtf8StringPtr = function(const p: POSSL_PARAM; val: PPChar): TOpenSSLInt; cdecl;
  TOSSLPARAMGetOctetString = function(const p: POSSL_PARAM; val: PPointer; max_len: TOpenSSLSizeT; used_len: POpenSSLSizeT): TOpenSSLInt; cdecl;
  TOSSLPARAMGetOctetStringPtr = function(const p: POSSL_PARAM; val: PPointer; used_len: POpenSSLSizeT): TOpenSSLInt; cdecl;
  
  { OSSL_PARAM set functions }
  TOSSLPARAMSetInt = function(p: POSSL_PARAM; val: OpenSSLInt): TOpenSSLInt; cdecl;
  TOSSLPARAMSetUInt = function(p: POSSL_PARAM; val: OpenSSLUInt): TOpenSSLInt; cdecl;
  TOSSLPARAMSetLong = function(p: POSSL_PARAM; val: OpenSSLLong): TOpenSSLInt; cdecl;
  TOSSLPARAMSetULong = function(p: POSSL_PARAM; val: OpenSSLULong): TOpenSSLInt; cdecl;
  TOSSLPARAMSetInt32 = function(p: POSSL_PARAM; val: Int32): TOpenSSLInt; cdecl;
  TOSSLPARAMSetUInt32 = function(p: POSSL_PARAM; val: UInt32): TOpenSSLInt; cdecl;
  TOSSLPARAMSetInt64 = function(p: POSSL_PARAM; val: Int64): TOpenSSLInt; cdecl;
  TOSSLPARAMSetUInt64 = function(p: POSSL_PARAM; val: UInt64): TOpenSSLInt; cdecl;
  TOSSLPARAMSetSizeT = function(p: POSSL_PARAM; val: OpenSSLSizeT): TOpenSSLInt; cdecl;
  TOSSLPARAMSetBN = function(p: POSSL_PARAM; val: PBIGNUM): TOpenSSLInt; cdecl;
  TOSSLPARAMSetDouble = function(p: POSSL_PARAM; val: Double): TOpenSSLInt; cdecl;
  TOSSLPARAMSetUtf8String = function(p: POSSL_PARAM; val: PChar): TOpenSSLInt; cdecl;
  TOSSLPARAMSetOctetString = function(p: POSSL_PARAM; val: Pointer; len: TOpenSSLSizeT): TOpenSSLInt; cdecl;
  
  { OSSL_PARAM utility functions }
  TOSSLPARAMAllocateFromText = function(to_: PPOSSL_PARAM; const params: POSSL_PARAM;
                                        key: PChar; type_: PChar; value: PChar;
                                        value_n: TOpenSSLSizeT): TOpenSSLInt; cdecl;
  TOSSLPARAMDup = function(const params: POSSL_PARAM): POSSL_PARAM; cdecl;
  TOSSLPARAMMerge = function(const params1, params2: POSSL_PARAM): POSSL_PARAM; cdecl;
  TOSSLPARAMFree = procedure(params: POSSL_PARAM); cdecl;
  
  { OSSL_PARAM_BLD functions }
  TOSSLPARAMB = function: POSSL_PARAM_BLD; cdecl;
  TOSSLPARAMBLDToParam = function(bld: POSSL_PARAM_BLD): POSSL_PARAM; cdecl;
  TOSSLPARAMBLDFree = procedure(bld: POSSL_PARAM_BLD); cdecl;
  TOSSLPARAMBLDPushInt = function(bld: POSSL_PARAM_BLD; key: PChar; val: OpenSSLInt): TOpenSSLInt; cdecl;
  TOSSLPARAMBLDPushUInt = function(bld: POSSL_PARAM_BLD; key: PChar; val: OpenSSLUInt): TOpenSSLInt; cdecl;
  TOSSLPARAMBLDPushLong = function(bld: POSSL_PARAM_BLD; key: PChar; val: OpenSSLLong): TOpenSSLInt; cdecl;
  TOSSLPARAMBLDPushULong = function(bld: POSSL_PARAM_BLD; key: PChar; val: OpenSSLULong): TOpenSSLInt; cdecl;
  TOSSLPARAMBLDPushInt32 = function(bld: POSSL_PARAM_BLD; key: PChar; val: Int32): TOpenSSLInt; cdecl;
  TOSSLPARAMBLDPushUInt32 = function(bld: POSSL_PARAM_BLD; key: PChar; val: UInt32): TOpenSSLInt; cdecl;
  TOSSLPARAMBLDPushInt64 = function(bld: POSSL_PARAM_BLD; key: PChar; val: Int64): TOpenSSLInt; cdecl;
  TOSSLPARAMBLDPushUInt64 = function(bld: POSSL_PARAM_BLD; key: PChar; val: UInt64): TOpenSSLInt; cdecl;
  TOSSLPARAMBLDPushSizeT = function(bld: POSSL_PARAM_BLD; key: PChar; val: OpenSSLSizeT): TOpenSSLInt; cdecl;
  TOSSLPARAMBLDPushDouble = function(bld: POSSL_PARAM_BLD; key: PChar; val: Double): TOpenSSLInt; cdecl;
  TOSSLPARAMBLDPushBN = function(bld: POSSL_PARAM_BLD; key: PChar; val: PBIGNUM): TOpenSSLInt; cdecl;
  TOSSLPARAMBLDPushBNPad = function(bld: POSSL_PARAM_BLD; key: PChar; val: PBIGNUM; sz: TOpenSSLSizeT): TOpenSSLInt; cdecl;
  TOSSLPARAMBLDPushUtf8String = function(bld: POSSL_PARAM_BLD; key: PChar; buf: PChar; bsize: TOpenSSLSizeT): TOpenSSLInt; cdecl;
  TOSSLPARAMBLDPushUtf8Ptr = function(bld: POSSL_PARAM_BLD; key: PChar; buf: PChar; bsize: TOpenSSLSizeT): TOpenSSLInt; cdecl;
  TOSSLPARAMBLDPushOctetString = function(bld: POSSL_PARAM_BLD; key: PChar; buf: Pointer; bsize: TOpenSSLSizeT): TOpenSSLInt; cdecl;
  TOSSLPARAMBLDPushOctetPtr = function(bld: POSSL_PARAM_BLD; key: PChar; buf: Pointer; bsize: TOpenSSLSizeT): TOpenSSLInt; cdecl;

var
  { Function variables }
  { Construction }
  OSSL_PARAM_construct_int: TOSSLPARAMConstructInt = nil;
  OSSL_PARAM_construct_uint: TOSSLPARAMConstructUInt = nil;
  OSSL_PARAM_construct_long: TOSSLPARAMConstructLong = nil;
  OSSL_PARAM_construct_ulong: TOSSLPARAMConstructULong = nil;
  OSSL_PARAM_construct_int32: TOSSLPARAMConstructInt32 = nil;
  OSSL_PARAM_construct_uint32: TOSSLPARAMConstructUInt32 = nil;
  OSSL_PARAM_construct_int64: TOSSLPARAMConstructInt64 = nil;
  OSSL_PARAM_construct_uint64: TOSSLPARAMConstructUInt64 = nil;
  OSSL_PARAM_construct_size_t: TOSSLPARAMConstructSizeT = nil;
  OSSL_PARAM_construct_BN: TOSSLPARAMConstructBN = nil;
  OSSL_PARAM_construct_double: TOSSLPARAMConstructDouble = nil;
  OSSL_PARAM_construct_utf8_string: TOSSLPARAMConstructUtf8String = nil;
  OSSL_PARAM_construct_utf8_ptr: TOSSLPARAMConstructUtf8Ptr = nil;
  OSSL_PARAM_construct_octet_string: TOSSLPARAMConstructOctetString = nil;
  OSSL_PARAM_construct_octet_ptr: TOSSLPARAMConstructOctetPtr = nil;
  OSSL_PARAM_construct_end: TOSSLPARAMConstructEnd = nil;
  
  { Get functions }
  OSSL_PARAM_get_int: TOSSLPARAMGetInt = nil;
  OSSL_PARAM_get_uint: TOSSLPARAMGetUInt = nil;
  OSSL_PARAM_get_long: TOSSLPARAMGetLong = nil;
  OSSL_PARAM_get_ulong: TOSSLPARAMGetULong = nil;
  OSSL_PARAM_get_int32: TOSSLPARAMGetInt32 = nil;
  OSSL_PARAM_get_uint32: TOSSLPARAMGetUInt32 = nil;
  OSSL_PARAM_get_int64: TOSSLPARAMGetInt64 = nil;
  OSSL_PARAM_get_uint64: TOSSLPARAMGetUInt64 = nil;
  OSSL_PARAM_get_size_t: TOSSLPARAMGetSizeT = nil;
  OSSL_PARAM_get_BN: TOSSLPARAMGetBN = nil;
  OSSL_PARAM_get_double: TOSSLPARAMGetDouble = nil;
  OSSL_PARAM_get_utf8_string: TOSSLPARAMGetUtf8String = nil;
  OSSL_PARAM_get_utf8_string_ptr: TOSSLPARAMGetUtf8StringPtr = nil;
  OSSL_PARAM_get_octet_string: TOSSLPARAMGetOctetString = nil;
  OSSL_PARAM_get_octet_string_ptr: TOSSLPARAMGetOctetStringPtr = nil;
  
  { Set functions }
  OSSL_PARAM_set_int: TOSSLPARAMSetInt = nil;
  OSSL_PARAM_set_uint: TOSSLPARAMSetUInt = nil;
  OSSL_PARAM_set_long: TOSSLPARAMSetLong = nil;
  OSSL_PARAM_set_ulong: TOSSLPARAMSetULong = nil;
  OSSL_PARAM_set_int32: TOSSLPARAMSetInt32 = nil;
  OSSL_PARAM_set_uint32: TOSSLPARAMSetUInt32 = nil;
  OSSL_PARAM_set_int64: TOSSLPARAMSetInt64 = nil;
  OSSL_PARAM_set_uint64: TOSSLPARAMSetUInt64 = nil;
  OSSL_PARAM_set_size_t: TOSSLPARAMSetSizeT = nil;
  OSSL_PARAM_set_BN: TOSSLPARAMSetBN = nil;
  OSSL_PARAM_set_double: TOSSLPARAMSetDouble = nil;
  OSSL_PARAM_set_utf8_string: TOSSLPARAMSetUtf8String = nil;
  OSSL_PARAM_set_octet_string: TOSSLPARAMSetOctetString = nil;
  
  { Utility functions }
  OSSL_PARAM_allocate_from_text: TOSSLPARAMAllocateFromText = nil;
  OSSL_PARAM_dup: TOSSLPARAMDup = nil;
  OSSL_PARAM_merge: TOSSLPARAMMerge = nil;
  OSSL_PARAM_free: TOSSLPARAMFree = nil;
  
  { Builder functions }
  OSSL_PARAM_BLD_new: TOSSLPARAMB = nil;
  OSSL_PARAM_BLD_to_param: TOSSLPARAMBLDToParam = nil;
  OSSL_PARAM_BLD_free: TOSSLPARAMBLDFree = nil;
  OSSL_PARAM_BLD_push_int: TOSSLPARAMBLDPushInt = nil;
  OSSL_PARAM_BLD_push_uint: TOSSLPARAMBLDPushUInt = nil;
  OSSL_PARAM_BLD_push_long: TOSSLPARAMBLDPushLong = nil;
  OSSL_PARAM_BLD_push_ulong: TOSSLPARAMBLDPushULong = nil;
  OSSL_PARAM_BLD_push_int32: TOSSLPARAMBLDPushInt32 = nil;
  OSSL_PARAM_BLD_push_uint32: TOSSLPARAMBLDPushUInt32 = nil;
  OSSL_PARAM_BLD_push_int64: TOSSLPARAMBLDPushInt64 = nil;
  OSSL_PARAM_BLD_push_uint64: TOSSLPARAMBLDPushUInt64 = nil;
  OSSL_PARAM_BLD_push_size_t: TOSSLPARAMBLDPushSizeT = nil;
  OSSL_PARAM_BLD_push_double: TOSSLPARAMBLDPushDouble = nil;
  OSSL_PARAM_BLD_push_BN: TOSSLPARAMBLDPushBN = nil;
  OSSL_PARAM_BLD_push_BN_pad: TOSSLPARAMBLDPushBNPad = nil;
  OSSL_PARAM_BLD_push_utf8_string: TOSSLPARAMBLDPushUtf8String = nil;
  OSSL_PARAM_BLD_push_utf8_ptr: TOSSLPARAMBLDPushUtf8Ptr = nil;
  OSSL_PARAM_BLD_push_octet_string: TOSSLPARAMBLDPushOctetString = nil;
  OSSL_PARAM_BLD_push_octet_ptr: TOSSLPARAMBLDPushOctetPtr = nil;

{ Load/Unload functions }
function LoadOSSLPARAM(const ALibCrypto: THandle): Boolean;
procedure UnloadOSSLPARAM;

{ Helper functions }
function CreateParamArray(const Params: array of OSSL_PARAM): POSSL_PARAM;
procedure FreeParamArray(Params: POSSL_PARAM);
function GetParamValue(const Params: POSSL_PARAM; const Key: string; out Value: string): Boolean;
function SetParamValue(Params: POSSL_PARAM; const Key: string; const Value: string): Boolean;

implementation

uses nextpas.core.tls.openssl.api.utils; const OSSL_PARAM_BINDINGS: array[0..53] of TFunctionBinding = ( (Name: 'OSSL_PARAM_construct_int'; FuncPtr: @OSSL_PARAM_construct_int; Required: False);
    (Name: 'OSSL_PARAM_construct_uint'; FuncPtr: @OSSL_PARAM_construct_uint; Required: False),
    (Name: 'OSSL_PARAM_construct_long'; FuncPtr: @OSSL_PARAM_construct_long; Required: False),
    (Name: 'OSSL_PARAM_construct_ulong'; FuncPtr: @OSSL_PARAM_construct_ulong; Required: False),
    (Name: 'OSSL_PARAM_construct_int32'; FuncPtr: @OSSL_PARAM_construct_int32; Required: False),
    (Name: 'OSSL_PARAM_construct_uint32'; FuncPtr: @OSSL_PARAM_construct_uint32; Required: False),
    (Name: 'OSSL_PARAM_construct_int64'; FuncPtr: @OSSL_PARAM_construct_int64; Required: False),
    (Name: 'OSSL_PARAM_construct_uint64'; FuncPtr: @OSSL_PARAM_construct_uint64; Required: False),
    (Name: 'OSSL_PARAM_construct_size_t'; FuncPtr: @OSSL_PARAM_construct_size_t; Required: False),
    (Name: 'OSSL_PARAM_construct_BN'; FuncPtr: @OSSL_PARAM_construct_BN; Required: False),
    (Name: 'OSSL_PARAM_construct_double'; FuncPtr: @OSSL_PARAM_construct_double; Required: False),
    (Name: 'OSSL_PARAM_construct_utf8_string'; FuncPtr: @OSSL_PARAM_construct_utf8_string; Required: False),
    (Name: 'OSSL_PARAM_construct_utf8_ptr'; FuncPtr: @OSSL_PARAM_construct_utf8_ptr; Required: False),
    (Name: 'OSSL_PARAM_construct_octet_string'; FuncPtr: @OSSL_PARAM_construct_octet_string; Required: False),
    (Name: 'OSSL_PARAM_construct_octet_ptr'; FuncPtr: @OSSL_PARAM_construct_octet_ptr; Required: False),
    (Name: 'OSSL_PARAM_construct_end'; FuncPtr: @OSSL_PARAM_construct_end; Required: False),
    { Get functions }
    (Name: 'OSSL_PARAM_get_int'; FuncPtr: @OSSL_PARAM_get_int; Required: False),
    (Name: 'OSSL_PARAM_get_uint'; FuncPtr: @OSSL_PARAM_get_uint; Required: False),
    (Name: 'OSSL_PARAM_get_long'; FuncPtr: @OSSL_PARAM_get_long; Required: False),
    (Name: 'OSSL_PARAM_get_ulong'; FuncPtr: @OSSL_PARAM_get_ulong; Required: False),
    (Name: 'OSSL_PARAM_get_int32'; FuncPtr: @OSSL_PARAM_get_int32; Required: False),
    (Name: 'OSSL_PARAM_get_uint32'; FuncPtr: @OSSL_PARAM_get_uint32; Required: False),
    (Name: 'OSSL_PARAM_get_int64'; FuncPtr: @OSSL_PARAM_get_int64; Required: False),
    (Name: 'OSSL_PARAM_get_uint64'; FuncPtr: @OSSL_PARAM_get_uint64; Required: False),
    (Name: 'OSSL_PARAM_get_size_t'; FuncPtr: @OSSL_PARAM_get_size_t; Required: False),
    (Name: 'OSSL_PARAM_get_BN'; FuncPtr: @OSSL_PARAM_get_BN; Required: False),
    (Name: 'OSSL_PARAM_get_double'; FuncPtr: @OSSL_PARAM_get_double; Required: False),
    (Name: 'OSSL_PARAM_get_utf8_string'; FuncPtr: @OSSL_PARAM_get_utf8_string; Required: False),
    (Name: 'OSSL_PARAM_get_utf8_string_ptr'; FuncPtr: @OSSL_PARAM_get_utf8_string_ptr; Required: False),
    (Name: 'OSSL_PARAM_get_octet_string'; FuncPtr: @OSSL_PARAM_get_octet_string; Required: False),
    (Name: 'OSSL_PARAM_get_octet_string_ptr'; FuncPtr: @OSSL_PARAM_get_octet_string_ptr; Required: False),
    { Set functions }
    (Name: 'OSSL_PARAM_set_int'; FuncPtr: @OSSL_PARAM_set_int; Required: False),
    (Name: 'OSSL_PARAM_set_uint'; FuncPtr: @OSSL_PARAM_set_uint; Required: False),
    (Name: 'OSSL_PARAM_set_long'; FuncPtr: @OSSL_PARAM_set_long; Required: False),
    (Name: 'OSSL_PARAM_set_ulong'; FuncPtr: @OSSL_PARAM_set_ulong; Required: False),
    (Name: 'OSSL_PARAM_set_int32'; FuncPtr: @OSSL_PARAM_set_int32; Required: False),
    (Name: 'OSSL_PARAM_set_uint32'; FuncPtr: @OSSL_PARAM_set_uint32; Required: False),
    (Name: 'OSSL_PARAM_set_int64'; FuncPtr: @OSSL_PARAM_set_int64; Required: False),
    (Name: 'OSSL_PARAM_set_uint64'; FuncPtr: @OSSL_PARAM_set_uint64; Required: False),
    (Name: 'OSSL_PARAM_set_size_t'; FuncPtr: @OSSL_PARAM_set_size_t; Required: False),
    (Name: 'OSSL_PARAM_set_BN'; FuncPtr: @OSSL_PARAM_set_BN; Required: False),
    (Name: 'OSSL_PARAM_set_double'; FuncPtr: @OSSL_PARAM_set_double; Required: False),
    (Name: 'OSSL_PARAM_set_utf8_string'; FuncPtr: @OSSL_PARAM_set_utf8_string; Required: False),
    (Name: 'OSSL_PARAM_set_octet_string'; FuncPtr: @OSSL_PARAM_set_octet_string; Required: False),
    { Utility functions }
    (Name: 'OSSL_PARAM_allocate_from_text'; FuncPtr: @OSSL_PARAM_allocate_from_text; Required: False),
    (Name: 'OSSL_PARAM_dup'; FuncPtr: @OSSL_PARAM_dup; Required: False),
    (Name: 'OSSL_PARAM_merge'; FuncPtr: @OSSL_PARAM_merge; Required: False),
    (Name: 'OSSL_PARAM_free'; FuncPtr: @OSSL_PARAM_free; Required: False),
    { Builder functions }
    (Name: 'OSSL_PARAM_BLD_new'; FuncPtr: @OSSL_PARAM_BLD_new; Required: False),
    (Name: 'OSSL_PARAM_BLD_to_param'; FuncPtr: @OSSL_PARAM_BLD_to_param; Required: False),
    (Name: 'OSSL_PARAM_BLD_free'; FuncPtr: @OSSL_PARAM_BLD_free; Required: False),
    (Name: 'OSSL_PARAM_BLD_push_int'; FuncPtr: @OSSL_PARAM_BLD_push_int; Required: False),
    (Name: 'OSSL_PARAM_BLD_push_uint'; FuncPtr: @OSSL_PARAM_BLD_push_uint; Required: False),
    (Name: 'OSSL_PARAM_BLD_push_long'; FuncPtr: @OSSL_PARAM_BLD_push_long; Required: False)
  );

  OSSL_PARAM_BINDINGS_EXT: array[0..13] of TFunctionBinding = (
    (Name: 'OSSL_PARAM_BLD_push_ulong'; FuncPtr: @OSSL_PARAM_BLD_push_ulong; Required: False),
    (Name: 'OSSL_PARAM_BLD_push_int32'; FuncPtr: @OSSL_PARAM_BLD_push_int32; Required: False),
    (Name: 'OSSL_PARAM_BLD_push_uint32'; FuncPtr: @OSSL_PARAM_BLD_push_uint32; Required: False),
    (Name: 'OSSL_PARAM_BLD_push_int64'; FuncPtr: @OSSL_PARAM_BLD_push_int64; Required: False),
    (Name: 'OSSL_PARAM_BLD_push_uint64'; FuncPtr: @OSSL_PARAM_BLD_push_uint64; Required: False),
    (Name: 'OSSL_PARAM_BLD_push_size_t'; FuncPtr: @OSSL_PARAM_BLD_push_size_t; Required: False),
    (Name: 'OSSL_PARAM_BLD_push_double'; FuncPtr: @OSSL_PARAM_BLD_push_double; Required: False),
    (Name: 'OSSL_PARAM_BLD_push_BN'; FuncPtr: @OSSL_PARAM_BLD_push_BN; Required: False),
    (Name: 'OSSL_PARAM_BLD_push_BN_pad'; FuncPtr: @OSSL_PARAM_BLD_push_BN_pad; Required: False),
    (Name: 'OSSL_PARAM_BLD_push_utf8_string'; FuncPtr: @OSSL_PARAM_BLD_push_utf8_string; Required: False),
    (Name: 'OSSL_PARAM_BLD_push_utf8_ptr'; FuncPtr: @OSSL_PARAM_BLD_push_utf8_ptr; Required: False),
    (Name: 'OSSL_PARAM_BLD_push_octet_string'; FuncPtr: @OSSL_PARAM_BLD_push_octet_string; Required: False),
    (Name: 'OSSL_PARAM_BLD_push_octet_ptr'; FuncPtr: @OSSL_PARAM_BLD_push_octet_ptr; Required: False),
    (Name: nil; FuncPtr: nil; Required: False)  { Terminator }
  );

function LoadOSSLPARAM(const ALibCrypto: THandle): Boolean;
begin
  Result := False;
  if TOpenSSLLoader.IsModuleLoaded(osmParam) then Exit(True);
  if ALibCrypto = 0 then Exit;

  { Batch load all functions }
  TOpenSSLLoader.LoadFunctions(ALibCrypto, OSSL_PARAM_BINDINGS);
  TOpenSSLLoader.LoadFunctions(ALibCrypto, OSSL_PARAM_BINDINGS_EXT);

  { Check for OpenSSL 3.0+ }
  Result := Assigned(OSSL_PARAM_BLD_new);
  TOpenSSLLoader.SetModuleLoaded(osmParam, Result);
end;

procedure UnloadOSSLPARAM;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmParam) then Exit;

  { Clear all function pointers }
  TOpenSSLLoader.ClearFunctions(OSSL_PARAM_BINDINGS);
  TOpenSSLLoader.ClearFunctions(OSSL_PARAM_BINDINGS_EXT);

  TOpenSSLLoader.SetModuleLoaded(osmParam, False);
end;

{ Helper functions }

function CreateParamArray(const Params: array of OSSL_PARAM): POSSL_PARAM;
var
  i: Integer;
begin
  GetMem(Result, (Length(Params) + 1) * SizeOf(OSSL_PARAM));
  for i := 0 to High(Params) do
    Result[i] := Params[i];
  
  { Add terminator }
  if Assigned(OSSL_PARAM_construct_end) then
    Result[Length(Params)] := OSSL_PARAM_construct_end()
  else
  begin
    Result[Length(Params)].key := nil;
    Result[Length(Params)].data_type := OSSL_PARAM_END;
    Result[Length(Params)].data := nil;
    Result[Length(Params)].data_size := 0;
    Result[Length(Params)].return_size := 0;
  end;
end;

procedure FreeParamArray(Params: POSSL_PARAM);
begin
  if Params <> nil then
  begin
    if Assigned(OSSL_PARAM_free) then
      OSSL_PARAM_free(Params)
    else
      FreeMem(Params);
  end;
end;

function GetParamValue(const Params: POSSL_PARAM; const Key: string; out Value: string): Boolean;
var
  p: POSSL_PARAM;
  str: PChar;
begin
  Result := False;
  Value := '';
  if Params = nil then Exit;
  
  p := Params;
  while p^.key <> nil do
  begin
    if string(p^.key) = Key then
    begin
      if (p^.data_type = OSSL_PARAM_UTF8_STRING) and Assigned(OSSL_PARAM_get_utf8_string_ptr) then
      begin
        if OSSL_PARAM_get_utf8_string_ptr(p, @str) = 1 then
        begin
          Value := string(str);
          Result := True;
        end;
      end;
      Break;
    end;
    Inc(p);
  end;
end;

function SetParamValue(Params: POSSL_PARAM; const Key: string; const Value: string): Boolean;
var
  p: POSSL_PARAM;
begin
  Result := False;
  if Params = nil then Exit;
  
  p := Params;
  while p^.key <> nil do
  begin
    if string(p^.key) = Key then
    begin
      if (p^.data_type = OSSL_PARAM_UTF8_STRING) and Assigned(OSSL_PARAM_set_utf8_string) then
      begin
        Result := OSSL_PARAM_set_utf8_string(p, PChar(Value)) = 1;
      end;
      Break;
    end;
    Inc(p);
  end;
end;

initialization

finalization
  UnloadOSSLPARAM;

end.