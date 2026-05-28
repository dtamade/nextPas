type
  TFafafaSimdAbiFlags = type UInt32;
  TFafafaSimdPublicApiV2Flags = type UInt32;

const
  FAF_SIMD_ABI_FLAG_SUPPORTED_ON_CPU = UInt32(1) shl 0;
  FAF_SIMD_ABI_FLAG_REGISTERED       = UInt32(1) shl 1;
  FAF_SIMD_ABI_FLAG_DISPATCHABLE     = UInt32(1) shl 2;
  FAF_SIMD_ABI_FLAG_ACTIVE           = UInt32(1) shl 3;
  FAF_SIMD_ABI_FLAG_EXPERIMENTAL     = UInt32(1) shl 4;
  FAF_SIMD_PUBLIC_API_V2_FLAG_SNAPSHOT_BOUND    = UInt32(1) shl 0;
  FAF_SIMD_PUBLIC_API_V2_FLAG_DIRECT_DATA_PLANE = UInt32(1) shl 1;
  FAF_SIMD_PUBLIC_API_V2_FLAG_COMPAT_V1         = UInt32(1) shl 2;

type
  TFafafaSimdBackendPodInfo = packed record
    StructSize: UInt32;
    BackendId: UInt32;
    CapabilityBits: UInt64;
    Flags: TFafafaSimdAbiFlags;
    Priority: Int32;
  end;

  PFafafaSimdBackendPodInfo = ^TFafafaSimdBackendPodInfo;

  TFafafaSimdMemEqualFunc = function(aA, aB: Pointer; aLen: SizeUInt): LongBool; cdecl;
  TFafafaSimdMemFindByteFunc = function(aP: Pointer; aLen: SizeUInt; aValue: Byte): PtrInt; cdecl;
  TFafafaSimdMemDiffRangeFunc = function(aA, aB: Pointer; aLen: SizeUInt;
    out aFirstDiff, aLastDiff: SizeUInt): LongBool; cdecl;
  TFafafaSimdSumBytesFunc = function(aP: Pointer; aLen: SizeUInt): UInt64; cdecl;
  TFafafaSimdCountByteFunc = function(aP: Pointer; aLen: SizeUInt; aValue: Byte): SizeUInt; cdecl;
  TFafafaSimdBitsetPopCountFunc = function(aP: Pointer; aByteLen: SizeUInt): SizeUInt; cdecl;
  TFafafaSimdUtf8ValidateFunc = function(aP: Pointer; aLen: SizeUInt): LongBool; cdecl;
  TFafafaSimdAsciiIEqualFunc = function(aA, aB: Pointer; aLen: SizeUInt): LongBool; cdecl;
  TFafafaSimdBytesIndexOfFunc = function(aHaystack: Pointer; aHaystackLen: SizeUInt;
    aNeedle: Pointer; aNeedleLen: SizeUInt): PtrInt; cdecl;
  TFafafaSimdMemCopyFunc = procedure(aSrc, aDst: Pointer; aLen: SizeUInt); cdecl;
  TFafafaSimdMemSetFunc = procedure(aDst: Pointer; aLen: SizeUInt; aValue: Byte); cdecl;
  TFafafaSimdToLowerAsciiFunc = procedure(aP: Pointer; aLen: SizeUInt); cdecl;
  TFafafaSimdToUpperAsciiFunc = procedure(aP: Pointer; aLen: SizeUInt); cdecl;
  TFafafaSimdMemReverseFunc = procedure(aP: Pointer; aLen: SizeUInt); cdecl;
  TFafafaSimdMinMaxBytesFunc = procedure(aP: Pointer; aLen: SizeUInt; out aMinVal, aMaxVal: Byte); cdecl;

  TFafafaSimdPublicApi = packed record
    StructSize: UInt32;
    AbiVersionMajor: UInt16;
    AbiVersionMinor: UInt16;
    AbiSignatureHi: UInt64;
    AbiSignatureLo: UInt64;
    ActiveBackendId: UInt32;
    ActiveFlags: TFafafaSimdAbiFlags;
    MemEqual: TFafafaSimdMemEqualFunc;
    MemFindByte: TFafafaSimdMemFindByteFunc;
    MemDiffRange: TFafafaSimdMemDiffRangeFunc;
    SumBytes: TFafafaSimdSumBytesFunc;
    CountByte: TFafafaSimdCountByteFunc;
    BitsetPopCount: TFafafaSimdBitsetPopCountFunc;
    Utf8Validate: TFafafaSimdUtf8ValidateFunc;
    AsciiIEqual: TFafafaSimdAsciiIEqualFunc;
    BytesIndexOf: TFafafaSimdBytesIndexOfFunc;
    MemCopy: TFafafaSimdMemCopyFunc;
    MemSet: TFafafaSimdMemSetFunc;
    ToLowerAscii: TFafafaSimdToLowerAsciiFunc;
    ToUpperAscii: TFafafaSimdToUpperAsciiFunc;
    MemReverse: TFafafaSimdMemReverseFunc;
    MinMaxBytes: TFafafaSimdMinMaxBytesFunc;
  end;

  PFafafaSimdPublicApi = ^TFafafaSimdPublicApi;

  TFafafaSimdPublicApiV2 = packed record
    StructSize: UInt32;
    AbiVersionMajor: UInt16;
    AbiVersionMinor: UInt16;
    AbiSignatureHi: UInt64;
    AbiSignatureLo: UInt64;
    ActiveBackendId: UInt32;
    ActiveFlags: TFafafaSimdAbiFlags;
    SnapshotGeneration: UInt64;
    SnapshotFlags: TFafafaSimdPublicApiV2Flags;
    Reserved0: UInt32;
    MemEqual: TFafafaSimdMemEqualFunc;
    MemFindByte: TFafafaSimdMemFindByteFunc;
    MemDiffRange: TFafafaSimdMemDiffRangeFunc;
    SumBytes: TFafafaSimdSumBytesFunc;
    CountByte: TFafafaSimdCountByteFunc;
    BitsetPopCount: TFafafaSimdBitsetPopCountFunc;
    Utf8Validate: TFafafaSimdUtf8ValidateFunc;
    AsciiIEqual: TFafafaSimdAsciiIEqualFunc;
    BytesIndexOf: TFafafaSimdBytesIndexOfFunc;
    MemCopy: TFafafaSimdMemCopyFunc;
    MemSet: TFafafaSimdMemSetFunc;
    ToLowerAscii: TFafafaSimdToLowerAsciiFunc;
    ToUpperAscii: TFafafaSimdToUpperAsciiFunc;
    MemReverse: TFafafaSimdMemReverseFunc;
    MinMaxBytes: TFafafaSimdMinMaxBytesFunc;
  end;

  PFafafaSimdPublicApiV2 = ^TFafafaSimdPublicApiV2;

function GetSimdAbiVersionMajor: UInt16; cdecl;
function GetSimdAbiVersionMinor: UInt16; cdecl;
procedure GetSimdAbiSignature(out aHi, aLo: UInt64); cdecl;
function TryGetSimdBackendPodInfo(aBackend: TSimdBackend; out aInfo: TFafafaSimdBackendPodInfo): Boolean; cdecl;
function GetSimdBackendNamePtr(aBackend: TSimdBackend): PAnsiChar; cdecl;
function GetSimdBackendDescriptionPtr(aBackend: TSimdBackend): PAnsiChar; cdecl;
function GetSimdPublicApi: PFafafaSimdPublicApi; cdecl; inline;
function GetSimdPublicApiV2: PFafafaSimdPublicApiV2; cdecl; inline;

function fafafa_simd_abi_version_major: UInt16; cdecl;
function fafafa_simd_abi_version_minor: UInt16; cdecl;
procedure fafafa_simd_abi_signature(out aHi, aLo: UInt64); cdecl;
function fafafa_simd_get_backend_pod_info(aBackendId: UInt32; out aInfo: TFafafaSimdBackendPodInfo): LongBool; cdecl;
function fafafa_simd_backend_name(aBackendId: UInt32): PAnsiChar; cdecl;
function fafafa_simd_backend_description(aBackendId: UInt32): PAnsiChar; cdecl;
function fafafa_simd_get_public_api: PFafafaSimdPublicApi; cdecl;
function fafafa_simd_get_public_api_v2: PFafafaSimdPublicApiV2; cdecl;
