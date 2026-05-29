type
  TNextPasSimdAbiFlags = type UInt32;
  TNextPasSimdPublicApiV2Flags = type UInt32;

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
  TNextPasSimdBackendPodInfo = packed record
    StructSize: UInt32;
    BackendId: UInt32;
    CapabilityBits: UInt64;
    Flags: TNextPasSimdAbiFlags;
    Priority: Int32;
  end;

  PNextPasSimdBackendPodInfo = ^TNextPasSimdBackendPodInfo;

  TNextPasSimdMemEqualFunc = function(aA, aB: Pointer; aLen: SizeUInt): LongBool; cdecl;
  TNextPasSimdMemFindByteFunc = function(aP: Pointer; aLen: SizeUInt; aValue: Byte): PtrInt; cdecl;
  TNextPasSimdMemDiffRangeFunc = function(aA, aB: Pointer; aLen: SizeUInt;
    out aFirstDiff, aLastDiff: SizeUInt): LongBool; cdecl;
  TNextPasSimdSumBytesFunc = function(aP: Pointer; aLen: SizeUInt): UInt64; cdecl;
  TNextPasSimdCountByteFunc = function(aP: Pointer; aLen: SizeUInt; aValue: Byte): SizeUInt; cdecl;
  TNextPasSimdBitsetPopCountFunc = function(aP: Pointer; aByteLen: SizeUInt): SizeUInt; cdecl;
  TNextPasSimdUtf8ValidateFunc = function(aP: Pointer; aLen: SizeUInt): LongBool; cdecl;
  TNextPasSimdAsciiIEqualFunc = function(aA, aB: Pointer; aLen: SizeUInt): LongBool; cdecl;
  TNextPasSimdBytesIndexOfFunc = function(aHaystack: Pointer; aHaystackLen: SizeUInt;
    aNeedle: Pointer; aNeedleLen: SizeUInt): PtrInt; cdecl;
  TNextPasSimdMemCopyFunc = procedure(aSrc, aDst: Pointer; aLen: SizeUInt); cdecl;
  TNextPasSimdMemSetFunc = procedure(aDst: Pointer; aLen: SizeUInt; aValue: Byte); cdecl;
  TNextPasSimdToLowerAsciiFunc = procedure(aP: Pointer; aLen: SizeUInt); cdecl;
  TNextPasSimdToUpperAsciiFunc = procedure(aP: Pointer; aLen: SizeUInt); cdecl;
  TNextPasSimdMemReverseFunc = procedure(aP: Pointer; aLen: SizeUInt); cdecl;
  TNextPasSimdMinMaxBytesFunc = procedure(aP: Pointer; aLen: SizeUInt; out aMinVal, aMaxVal: Byte); cdecl;

  TNextPasSimdPublicApi = packed record
    StructSize: UInt32;
    AbiVersionMajor: UInt16;
    AbiVersionMinor: UInt16;
    AbiSignatureHi: UInt64;
    AbiSignatureLo: UInt64;
    ActiveBackendId: UInt32;
    ActiveFlags: TNextPasSimdAbiFlags;
    MemEqual: TNextPasSimdMemEqualFunc;
    MemFindByte: TNextPasSimdMemFindByteFunc;
    MemDiffRange: TNextPasSimdMemDiffRangeFunc;
    SumBytes: TNextPasSimdSumBytesFunc;
    CountByte: TNextPasSimdCountByteFunc;
    BitsetPopCount: TNextPasSimdBitsetPopCountFunc;
    Utf8Validate: TNextPasSimdUtf8ValidateFunc;
    AsciiIEqual: TNextPasSimdAsciiIEqualFunc;
    BytesIndexOf: TNextPasSimdBytesIndexOfFunc;
    MemCopy: TNextPasSimdMemCopyFunc;
    MemSet: TNextPasSimdMemSetFunc;
    ToLowerAscii: TNextPasSimdToLowerAsciiFunc;
    ToUpperAscii: TNextPasSimdToUpperAsciiFunc;
    MemReverse: TNextPasSimdMemReverseFunc;
    MinMaxBytes: TNextPasSimdMinMaxBytesFunc;
  end;

  PNextPasSimdPublicApi = ^TNextPasSimdPublicApi;

  TNextPasSimdPublicApiV2 = packed record
    StructSize: UInt32;
    AbiVersionMajor: UInt16;
    AbiVersionMinor: UInt16;
    AbiSignatureHi: UInt64;
    AbiSignatureLo: UInt64;
    ActiveBackendId: UInt32;
    ActiveFlags: TNextPasSimdAbiFlags;
    SnapshotGeneration: UInt64;
    SnapshotFlags: TNextPasSimdPublicApiV2Flags;
    Reserved0: UInt32;
    MemEqual: TNextPasSimdMemEqualFunc;
    MemFindByte: TNextPasSimdMemFindByteFunc;
    MemDiffRange: TNextPasSimdMemDiffRangeFunc;
    SumBytes: TNextPasSimdSumBytesFunc;
    CountByte: TNextPasSimdCountByteFunc;
    BitsetPopCount: TNextPasSimdBitsetPopCountFunc;
    Utf8Validate: TNextPasSimdUtf8ValidateFunc;
    AsciiIEqual: TNextPasSimdAsciiIEqualFunc;
    BytesIndexOf: TNextPasSimdBytesIndexOfFunc;
    MemCopy: TNextPasSimdMemCopyFunc;
    MemSet: TNextPasSimdMemSetFunc;
    ToLowerAscii: TNextPasSimdToLowerAsciiFunc;
    ToUpperAscii: TNextPasSimdToUpperAsciiFunc;
    MemReverse: TNextPasSimdMemReverseFunc;
    MinMaxBytes: TNextPasSimdMinMaxBytesFunc;
  end;

  PNextPasSimdPublicApiV2 = ^TNextPasSimdPublicApiV2;

function GetSimdAbiVersionMajor: UInt16; cdecl;
function GetSimdAbiVersionMinor: UInt16; cdecl;
procedure GetSimdAbiSignature(out aHi, aLo: UInt64); cdecl;
function TryGetSimdBackendPodInfo(aBackend: TSimdBackend; out aInfo: TNextPasSimdBackendPodInfo): Boolean; cdecl;
function GetSimdBackendNamePtr(aBackend: TSimdBackend): PAnsiChar; cdecl;
function GetSimdBackendDescriptionPtr(aBackend: TSimdBackend): PAnsiChar; cdecl;
function GetSimdPublicApi: PNextPasSimdPublicApi; cdecl; inline;
function GetSimdPublicApiV2: PNextPasSimdPublicApiV2; cdecl; inline;

function nextpas_simd_abi_version_major: UInt16; cdecl;
function nextpas_simd_abi_version_minor: UInt16; cdecl;
procedure nextpas_simd_abi_signature(out aHi, aLo: UInt64); cdecl;
function nextpas_simd_get_backend_pod_info(aBackendId: UInt32; out aInfo: TNextPasSimdBackendPodInfo): LongBool; cdecl;
function nextpas_simd_backend_name(aBackendId: UInt32): PAnsiChar; cdecl;
function nextpas_simd_backend_description(aBackendId: UInt32): PAnsiChar; cdecl;
function nextpas_simd_get_public_api: PNextPasSimdPublicApi; cdecl;
function nextpas_simd_get_public_api_v2: PNextPasSimdPublicApiV2; cdecl;
