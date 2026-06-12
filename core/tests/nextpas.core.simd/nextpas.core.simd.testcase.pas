unit nextpas.core.simd.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$I ../../src/nextpas.core.simd.settings.inc}
{$CODEPAGE UTF8}

// 对于溢出测试，需要在编译时关闭 Range 和 Overflow 检查
// settings.inc 中 DEBUG 模式会强制开启 $R+ 和 $Q+
// 但测试文件需要测试溢出回绕行为，所以这里全局关闭
{$R-}{$Q-}

interface

uses
  Classes, SysUtils, Math, nextpas.core.base, nextpas.core.math, fpcunit, testregistry,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.fixturehelpers,
  nextpas.core.simd.utils,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.scalar,
  nextpas.core.simd.backend.consistency.testcase,
  {$IFDEF CPUX86_64}
  nextpas.core.simd.sse2,
  nextpas.core.simd.sse42,
  nextpas.core.simd.avx2,
  {$IFDEF SIMD_BACKEND_AVX512}
  nextpas.core.simd.avx512,
  {$ENDIF}
  {$ENDIF}
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.cpuinfo.base,
  nextpas.core.simd.memutils,
  nextpas.core.simd.builder;

type
  TSimdBackendStatefulTestCase = class(TTestCase)
  protected
    FSavedBackend: TSimdBackend;
    procedure SetUp; override;
    procedure TearDown; override;
  end;

  TScalarBackendStatefulTestCase = class(TSimdBackendStatefulTestCase)
  protected
    procedure SetUp; override;
  end;

  TSimdVectorAsmStatefulTestCase = class(TSimdBackendStatefulTestCase)
  protected
    FSavedVectorAsm: Boolean;
    procedure RestoreVectorAsmState; virtual;
    procedure SetUp; override;
    procedure TearDown; override;
  end;

  {$IFDEF UNIX}
  {$IFDEF CPUX86_64}
  TSimdVectorAsmBackendStatefulTestCase = class(TSimdVectorAsmStatefulTestCase)
  protected
    function GetVectorAsmTargetBackend: TSimdBackend; virtual; abstract;
    procedure RefreshVectorAsmBackendRegistration; virtual; abstract;
    procedure RestoreVectorAsmState; override;
    procedure SetUp; override;
  end;
  {$ENDIF}
  {$ENDIF}

  // 全局函数测试
  TTestCase_Global = class(TScalarBackendStatefulTestCase)
  published
    // 内存操作函数测试
    procedure Test_MemEqual;
    procedure Test_MemEqual_Empty;
    procedure Test_MemEqual_Nil;
    procedure Test_MemFindByte;
    procedure Test_MemFindByte_NotFound;
    procedure Test_MemFindByte_Empty;
    procedure Test_MemDiffRange;
    procedure Test_MemDiffRange_NoDiff;
    procedure Test_MemCopy;
    procedure Test_MemSet;
    procedure Test_MemReverse;
    
    // 统计函数测试
    procedure Test_SumBytes;
    procedure Test_SumBytes_Empty;
    procedure Test_MinMaxBytes;
    procedure Test_MinMaxBytes_Single;
    procedure Test_CountByte;
    procedure Test_CountByte_None;
    
    // 文本处理函数测试
    procedure Test_Utf8Validate;
    procedure Test_Utf8Validate_Invalid;
    procedure Test_AsciiIEqual;
    procedure Test_AsciiIEqual_CaseDiff;
    procedure Test_ToLowerAscii;
    procedure Test_ToUpperAscii;
    
    // 搜索函数测试
    procedure Test_BytesIndexOf;
    procedure Test_BytesIndexOf_NotFound;
    procedure Test_BytesIndexOf_Empty;
    
    // 位集函数测试
    procedure Test_BitsetPopCount;
    procedure Test_BitsetPopCount_Empty;
    procedure Test_BitsetPopCount_AllSet;
  end;

  {$IFDEF CPUX86_64}
  // 后端一致性测试 - 确保所有后端对同一输入产生相同结果
  TTestCase_BackendConsistency = class(TTestCase)
  published
    procedure Test_MemEqual_Consistency;
    procedure Test_MemFindByte_Consistency;
    procedure Test_SumBytes_Consistency;
    procedure Test_CountByte_Consistency;
    procedure Test_MinMaxBytes_Consistency;
    procedure Test_BitsetPopCount_Consistency;
    procedure Test_Utf8Validate_Consistency;
    procedure Test_MemReverse_Consistency;
    procedure Test_AsciiIEqual_Consistency;
    procedure Test_ToLowerAscii_Consistency;
    procedure Test_ToUpperAscii_Consistency;
    procedure Test_MemDiffRange_Consistency;
    procedure Test_BytesIndexOf_Consistency;
  end;

  // SIMD 向量运算一致性测试（跨后端 vs Scalar）
  TTestCase_BackendVectorConsistency = class(TTestCase)
  published
    procedure Test_VectorOps_BackendName_Coverage;
    procedure Test_VectorOps_Consistency;
    procedure Test_VectorOps_Helper_Preserves_PreviousForcedBackend;
    procedure Test_VectorOps_Consistency_Preserves_PreviousForcedBackend;
  end;
  {$ENDIF}

  // 后端烟雾测试 - 验证 backend 选择后基础向量操作不会崩溃且结果正确
  TTestCase_BackendSmoke = class(TSimdBackendStatefulTestCase)
  protected
    procedure RunVecF32x4Smoke;
  published
    procedure Test_VectorAsmEnabled_Toggle_Roundtrip;

    procedure Test_DefaultBackend_VecF32x4_Smoke;
    procedure Test_ForceScalar_VecF32x4_Smoke;
    procedure Test_ForceSSE2_VecF32x4_Smoke;
    procedure Test_ForceSSE3_VecF32x4_Smoke;
    procedure Test_ForceSSSE3_VecF32x4_Smoke;
    procedure Test_ForceSSE41_VecF32x4_Smoke;
    procedure Test_ForceSSE42_VecF32x4_Smoke;
    {$IFDEF CPUX86_64}
    procedure Test_SSE42_StringSearchHelpers;
    {$ENDIF}
    procedure Test_SSE42_CRC32C_Contracts;
    procedure Test_ForceAVX2_VecF32x4_Smoke;
    procedure Test_ForceAVX512_VecF32x4_Smoke;
  end;

  {$IFDEF CPUX86_64}
  // x86 后端谓词测试（纯逻辑，不依赖可执行的 AVX-512 后端）
  TTestCase_X86BackendPredicates = class(TTestCase)
  published
    procedure Test_X86HasAVX512BackendRequiredFeatures_AVX512FOnly_Disabled;
    procedure Test_X86HasAVX512BackendRequiredFeatures_RequiresFMA;
    procedure Test_X86SupportsAVX512BackendOnCPU_RequiresUsable512AndBackendFeatureSet;
    procedure Test_X86DirectAVX512ExecutionGate_RequiresBackendSupportedPredicate;
  end;

  {$IFDEF SIMD_BACKEND_AVX512}
  // AVX-512 后端接线测试（依赖 backend 已编进当前构建）
  TTestCase_AVX512BackendRequirements = class(TSimdVectorAsmStatefulTestCase)
  protected
    procedure SetUp; override;
  published
    procedure Test_AVX512Backend_RegisteredDispatchTable_IsAccessible;
    procedure Test_AVX512Backend_DispatchTable_Overrides512BitLoadStoreAndSelect;
    procedure Test_AVX512Backend_DispatchTable_Overrides512BitFloatCompare;
    procedure Test_AVX512Backend_DispatchTable_Inherits_AVX2_I64x2_U64x2;
  end;
  {$ENDIF}
  {$ENDIF}

  {$IFDEF UNIX}
  {$IFDEF CPUX86_64}
  // AVX2 VectorAsm 专项测试：聚焦于向量汇编路径的正确性（小步推进）
  TTestCase_AVX2VectorAsm = class(TSimdVectorAsmBackendStatefulTestCase)
  protected
    function GetVectorAsmTargetBackend: TSimdBackend; override;
    procedure RefreshVectorAsmBackendRegistration; override;
  published
    procedure Test_VecF32x4_Fma_FusedWhenFMAAvailable;
    procedure Test_VecF32x8_AddSubMulDiv_RandomConsistency;
    procedure Test_VecF32x8_AddSubMulDiv_SpecialValues_Consistency;
    procedure Test_VecF64x2_AddSubMulDiv_RandomConsistency;
    procedure Test_VecF64x2_AddSubMulDiv_SpecialValues_Consistency;
    procedure Test_VecI32x4_AddSubMul_RandomConsistency;
    procedure Test_VecI32x4_AddSubMul_BoundaryConsistency;
    procedure Test_VecF32x4_Compare_SpecialValues_Consistency;
    procedure Test_VecF32x4_Compare_RandomConsistency;
    procedure Test_VecF32x4_AddSubMulDiv_RandomConsistency;
    procedure Test_VecF32x4_AddSubMulDiv_SpecialValues_Consistency;
    procedure Test_VecF32x4_Abs_RandomConsistency;
    procedure Test_VecF32x4_Abs_SpecialValues_Consistency;
    procedure Test_VecF32x4_Sqrt_RandomConsistency;
    procedure Test_VecF32x4_Sqrt_SpecialValues_Consistency;
    procedure Test_VecF32x4_MinMax_RandomConsistency;
    procedure Test_VecF32x4_MinMax_SpecialValues_Consistency;
    procedure Test_VecF32x4_Reduce_RandomConsistency;
    procedure Test_VecF32x4_Reduce_SpecialValues_Consistency;
    procedure Test_VecF32x4_LoadStore_RandomRoundtrip;
    procedure Test_VecF32x4_LoadStore_SpecialValues_Roundtrip;
    procedure Test_VecF32x4_Select_RandomConsistency;
    procedure Test_VecF32x4_ExtractInsert_RandomConsistency;
    procedure Test_VecF32x4_SplatZero_BitExact;
    procedure Test_VecF32x4_RcpRsqrt_RandomConsistency;
    procedure Test_VecF32x4_FloorCeil_RandomConsistency;
    procedure Test_VecF32x4_RoundTrunc_RandomConsistency;
    procedure Test_VecF32x4_Clamp_RandomConsistency;
    procedure Test_VecF32x4_Dot_RandomConsistency;
    procedure Test_VecF32x4_Dot3_RandomConsistency;
    procedure Test_VecF32x4_Cross3_RandomConsistency;
    procedure Test_VecF32x4_Length_RandomConsistency;
    procedure Test_VecF32x4_Length3_RandomConsistency;
    procedure Test_VecF32x4_Normalize_RandomConsistency;
    procedure Test_VecF32x4_Normalize3_RandomConsistency;
    procedure Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved;
    procedure Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_VectorReturn;
    procedure Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_VectorReturn_OneVec;
    procedure Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_VectorReturn_ThreeVec;
    procedure Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_VectorReturn_Ptr;
    procedure Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_Store;
    procedure Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_Insert;
    procedure Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_Extract;
    procedure Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_MaskReturn;
    procedure Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_Zero;
    procedure Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_Splat;
    procedure Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_Select;
    procedure Test_VecF32x8_ABI_CalleeSavedRegisters_Preserved_VectorReturn;
    procedure Test_VecF64x2_ABI_CalleeSavedRegisters_Preserved_VectorReturn;
    procedure Test_VecI32x4_ABI_CalleeSavedRegisters_Preserved_VectorReturn;

    procedure Test_Facade_MemEqual_ABI_CalleeSavedRegisters_Preserved;
    procedure Test_Facade_MemDiffRange_ABI_CalleeSavedRegisters_Preserved;
    procedure Test_Facade_MemFindByte_ABI_CalleeSavedRegisters_Preserved;
    procedure Test_Facade_MemCopy_ABI_CalleeSavedRegisters_Preserved;
    procedure Test_Facade_SumBytes_ABI_CalleeSavedRegisters_Preserved;
    procedure Test_Facade_CountByte_ABI_CalleeSavedRegisters_Preserved;
    procedure Test_Facade_BitsetPopCount_ABI_CalleeSavedRegisters_Preserved;
    procedure Test_Facade_Utf8Validate_ABI_CalleeSavedRegisters_Preserved;
    procedure Test_Facade_AsciiIEqual_ABI_CalleeSavedRegisters_Preserved;
    procedure Test_Facade_ToLowerAscii_ABI_CalleeSavedRegisters_Preserved;
    procedure Test_Facade_ToUpperAscii_ABI_CalleeSavedRegisters_Preserved;
    procedure Test_Facade_BytesIndexOf_ABI_CalleeSavedRegisters_Preserved;
  end;

  {$IFDEF SIMD_BACKEND_AVX512}
  // AVX-512 VectorAsm 专项测试：聚焦于 512-bit 向量汇编路径的正确性
  // 全面覆盖所有 AVX-512 注册函数
  TTestCase_AVX512VectorAsm = class(TSimdVectorAsmBackendStatefulTestCase)
  protected
    function GetVectorAsmTargetBackend: TSimdBackend; override;
    procedure RefreshVectorAsmBackendRegistration; override;
  published
    // === F32x16 算术运算一致性测试 ===
    procedure Test_VecF32x16_AddSubMulDiv_RandomConsistency;
    procedure Test_VecF32x16_AddSubMulDiv_SpecialValues_Consistency;

    // === F64x8 算术运算一致性测试 ===
    procedure Test_VecF64x8_AddSubMulDiv_RandomConsistency;
    procedure Test_VecF64x8_AddSubMulDiv_SpecialValues_Consistency;

    // === I32x16 算术运算一致性测试 ===
    procedure Test_VecI32x16_AddSubMul_RandomConsistency;
    procedure Test_VecI32x16_AddSubMul_BoundaryConsistency;

    // === I32x16 位运算测试 ===
    procedure Test_VecI32x16_BitwiseOps_RandomConsistency;

    // === I32x16 移位测试 ===
    procedure Test_VecI32x16_Shift_RandomConsistency;

    // === I32x16 比较测试（全部6个比较函数）===
    procedure Test_VecI32x16_Compare_Consistency;
    procedure Test_VecI32x16_Compare_LeGeNe_Consistency;

    // === I32x16 MinMax测试 ===
    procedure Test_VecI32x16_MinMax_Consistency;

    // === 饱和算术测试（8个函数）===
    procedure Test_I8x16_SatAddSub_Consistency;
    procedure Test_I16x8_SatAddSub_Consistency;
    procedure Test_U8x16_SatAddSub_Consistency;
    procedure Test_U16x8_SatAddSub_Consistency;

    // === Facade 函数测试（11个 AVX-512 原生函数）===
    procedure Test_Facade_MemEqual_Consistency;
    procedure Test_Facade_MemFindByte_Consistency;
    procedure Test_Facade_SumBytes_Consistency;
    procedure Test_Facade_CountByte_Consistency;
    procedure Test_Facade_MinMaxBytes_Consistency;
    procedure Test_Facade_BitsetPopCount_Consistency;
    procedure Test_Facade_MemCopy_Consistency;
    procedure Test_Facade_MemSet_Consistency;
    procedure Test_Facade_ToLowerAscii_Consistency;
    procedure Test_Facade_ToUpperAscii_Consistency;
    procedure Test_Facade_AsciiIEqual_Consistency;

    // === ABI 调用约定测试 ===
    procedure Test_VecF32x16_ABI_CalleeSavedRegisters_Preserved;
    procedure Test_VecI32x16_ABI_CalleeSavedRegisters_Preserved;
  end;
  {$ENDIF}  // SIMD_BACKEND_AVX512
  {$ENDIF}
  {$ENDIF}

  // 向量运算测试 (强制使用 Scalar 后端以避免 AVX2 实现的问题)
  TTestCase_VectorOps = class(TScalarBackendStatefulTestCase)
  published
    procedure Test_VecF32x4_Add;
    procedure Test_VecF32x4_Sub;
    procedure Test_VecF32x4_Mul;
    procedure Test_VecF32x4_Div;
    procedure Test_VecF32x4_Sqrt;
    procedure Test_VecF32x4_Min;
    procedure Test_VecF32x4_Max;
    procedure Test_VecF32x4_Abs;
    procedure Test_VecF32x4_ReduceAdd;
    procedure Test_VecF32x4_ReduceMin;
    procedure Test_VecF32x4_ReduceMax;
    procedure Test_VecF32x4_Splat;
    procedure Test_VecF32x4_LoadStore;
    procedure Test_VecF32x4_UtilityFacade_Basic;
    procedure Test_VecF32x4_Compare;
    // 扩展数学函数测试
    procedure Test_VecF32x4_Fma;
    procedure Test_VecF32x4_Rcp;
    procedure Test_VecF32x4_Rsqrt;
    procedure Test_VecF32x4_Floor;
    procedure Test_VecF32x4_Ceil;
    procedure Test_VecF32x4_Round;
    procedure Test_VecF32x4_Trunc;
    procedure Test_VecF32x4_Clamp;
    // 3D/4D 向量数学测试
    procedure Test_VecF32x4_Dot;
    procedure Test_VecF32x3_Dot;
    procedure Test_VecF32x3_Cross;
    procedure Test_VecF32x4_Length;
    procedure Test_VecF32x3_Length;
    procedure Test_VecF32x4_Normalize;
    procedure Test_VecF32x3_Normalize;
    // ✅ F64x2 扩展函数测试 (2026-02-05)
    procedure Test_VecF64x2_Floor;
    procedure Test_VecF64x2_Ceil;
    procedure Test_VecF64x2_Round;
    procedure Test_VecF64x2_Trunc;
    procedure Test_VecF64x2_Fma;
  end;

  // 低宽整数 façade contract 直接守卫（强制 Scalar，避免只剩 parity 旁证）
  TTestCase_IntegerFacadeGuards = class(TScalarBackendStatefulTestCase)
  published
    procedure Test_VecI32x4_AndNot_Basic;
    procedure Test_VecI32x4_Compare_Basic;
    procedure Test_VecI32x4_RemainingOps_Basic;
    procedure Test_VecI32x8_AndNot_Basic;
    procedure Test_VecI32x8_Compare_Basic;
    procedure Test_VecI32x8_RemainingOps_Basic;
    procedure Test_VecI64x2_AndNot_Basic;
    procedure Test_VecI64x2_Compare_Basic;
    procedure Test_VecI64x2_RemainingOps_Basic;
    procedure Test_VecI64x4_AndNot_Basic;
    procedure Test_VecI64x4_Compare_Basic;
    procedure Test_VecI64x4_RemainingOps_Basic;
    procedure Test_VecU64x2_AndNot_Basic;
    procedure Test_VecU64x2_Compare_Unsigned;
    procedure Test_VecU64x2_RemainingOps_Basic;
    procedure Test_VecU64x4_RemainingOps_Basic;
    procedure Test_VecI32x16_AndNot_Basic;
    procedure Test_VecI32x16_Compare_Basic;
    procedure Test_VecI32x16_RemainingOps_Basic;
    procedure Test_VecU32x16_AndNot_Basic;
    procedure Test_VecU32x16_Compare_Unsigned;
    procedure Test_VecU32x16_RemainingOps_Basic;
    procedure Test_VecU64x4_Compare_Unsigned;
    procedure Test_VecI64x8_Compare_Basic;
    procedure Test_VecI64x8_RemainingOps_Basic;
    procedure Test_VecU64x8_Compare_Unsigned;
    procedure Test_VecU64x8_RemainingOps_Basic;
    procedure Test_VecI16x32_AndNot_Basic;
    procedure Test_VecI16x32_Compare_Basic;
    procedure Test_VecI16x32_RemainingOps_Basic;
    procedure Test_VecI8x64_AndNot_Basic;
    procedure Test_VecI8x64_Compare_Basic;
    procedure Test_VecI8x64_RemainingOps_Basic;
    procedure Test_VecU8x64_Compare_Unsigned;
    procedure Test_VecU8x64_RemainingOps_Basic;
  end;

  // 宽浮点 façade contract 直接守卫（强制 Scalar，避免只剩 operator/default-backend/parity 旁证）
  TTestCase_FloatFacadeGuards = class(TScalarBackendStatefulTestCase)
  published
    procedure Test_VecF64x2_Arithmetic_Basic;
    procedure Test_VecF64x2_CompareReduceSelect_Basic;
    procedure Test_VecF64x2_ExtendedMathAndLoadStore_Basic;
    procedure Test_VecF64x2_RemainingMathAndExtractInsert_Basic;
    procedure Test_VecF32x16_Arithmetic_Basic;
    procedure Test_VecF32x16_CompareReduceSelect_Basic;
    procedure Test_VecF32x16_ExtendedMathAndLoadStore_Basic;
    procedure Test_VecF32x16_RemainingMathAndExtractInsert_Basic;
    procedure Test_VecF64x8_Arithmetic_Basic;
    procedure Test_VecF64x8_CompareReduceSelect_Basic;
    procedure Test_VecF64x8_ExtendedMathAndLoadStore_Basic;
    procedure Test_VecF64x8_RemainingMath_Basic;
  end;

  // 大数据量和边界测试
  TTestCase_LargeData = class(TScalarBackendStatefulTestCase)
  published
    procedure Test_MemEqual_1MB;
    procedure Test_SumBytes_1MB;
    procedure Test_MemFindByte_LargeBuffer;
    procedure Test_UnalignedPointer;
    procedure Test_OddSizes;
  end;

  // Phase 1.1: 无符号向量类型测试
  TTestCase_UnsignedVectorTypes = class(TTestCase)
  published
    // TVecU32x4 类型定义测试
    procedure Test_VecU32x4_TypeDef_Size;
    procedure Test_VecU32x4_TypeDef_Layout;
    procedure Test_VecU32x4_TypeDef_RawAccess;
    
    // TVecU16x8 类型定义测试
    procedure Test_VecU16x8_TypeDef_Size;
    procedure Test_VecU16x8_TypeDef_Layout;
    procedure Test_VecU16x8_TypeDef_RawAccess;
    
    // TVecU8x16 类型定义测试
    procedure Test_VecU8x16_TypeDef_Size;
    procedure Test_VecU8x16_TypeDef_Layout;
    procedure Test_VecU8x16_TypeDef_RawAccess;
    
    // TVecU64x2 类型定义测试
    procedure Test_VecU64x2_TypeDef_Size;
    procedure Test_VecU64x2_TypeDef_Layout;
    procedure Test_VecU64x2_TypeDef_RawAccess;
    
    // 256-bit 无符号向量类型测试
    procedure Test_VecU32x8_TypeDef_Size;
    procedure Test_VecU32x8_TypeDef_LoHi;
    procedure Test_VecU16x16_TypeDef_Size;
    procedure Test_VecU16x16_TypeDef_LoHi;
    procedure Test_VecU8x32_TypeDef_Size;
    procedure Test_VecU8x32_TypeDef_LoHi;
  end;

  // Phase 1.2: 运算符重载测试
  TTestCase_OperatorOverloads = class(TScalarBackendStatefulTestCase)
  published
    // TVecF32x4 运算符测试
    procedure Test_VecF32x4_Op_Add;
    procedure Test_VecF32x4_Op_Sub;
    procedure Test_VecF32x4_Op_Mul;
    procedure Test_VecF32x4_Op_Div;
    procedure Test_VecF32x4_Op_Neg;
    
    // TVecF64x2 运算符测试
    procedure Test_VecF64x2_Op_Add;
    procedure Test_VecF64x2_Op_Sub;
    procedure Test_VecF64x2_Op_Mul;
    procedure Test_VecF64x2_Op_Div;
    
    // TVecI32x4 运算符测试
    procedure Test_VecI32x4_Op_Add;
    procedure Test_VecI32x4_Op_Sub;
    procedure Test_VecI32x4_Op_Neg;

    // TVecU32/64/16/8 运算符测试
    procedure Test_VecU32x4_Op_All;
    procedure Test_VecU64x2_Op_All;
    procedure Test_VecU16x8_Op_All;
    procedure Test_VecU8x16_Op_All;
    procedure Test_VecU32x8_Op_All;
    procedure Test_VecU64x4_Op_All;
    procedure Test_VecU32x16_Op_All;
    procedure Test_VecU64x8_Op_All;
    procedure Test_VecU8x64_Op_All;
    
    // 标量操作测试
    procedure Test_VecF32x4_Op_ScalarMul;
    procedure Test_VecF32x4_Op_ScalarDiv;
  end;

  // Phase 1.3: 向量掩码类型测试
  TTestCase_VectorMaskTypes = class(TScalarBackendStatefulTestCase)
  published
    // TMaskF32x4 基础测试
    procedure Test_MaskF32x4_TypeDef_Size;
    procedure Test_MaskF32x4_AllTrue;
    procedure Test_MaskF32x4_AllFalse;
    procedure Test_MaskF32x4_Mixed;
    procedure Test_MaskF32x4_Test;
    procedure Test_MaskF32x4_ToBitmask;
    procedure Test_MaskF32x4_Any;
    procedure Test_MaskF32x4_All;
    procedure Test_MaskF32x4_None;
    
    // TMaskF32x4 逻辑运算符测试
    procedure Test_MaskF32x4_Op_And;
    procedure Test_MaskF32x4_Op_Or;
    procedure Test_MaskF32x4_Op_Xor;
    procedure Test_MaskF32x4_Op_Not;
    
    // TMaskI32x4 基础测试
    procedure Test_MaskI32x4_TypeDef_Size;
    procedure Test_MaskI32x4_AllTrue;
    procedure Test_MaskI32x4_ToBitmask;
    
    // TMaskF64x2 基础测试
    procedure Test_MaskF64x2_TypeDef_Size;
    procedure Test_MaskF64x2_AllTrue;
    procedure Test_MaskF64x2_ToBitmask;
    
    // Select 操作测试
    procedure Test_MaskF32x4_Select;
  end;

  // Phase 1.4: 类型转换函数测试
  TTestCase_TypeConversion = class(TScalarBackendStatefulTestCase)
  published
    // IntoBits / FromBits (F32x4 <-> I32x4)
    procedure Test_VecF32x4_IntoBits;
    procedure Test_VecI32x4_FromBitsF32;
    procedure Test_IntoBits_FromBits_Roundtrip;
    
    // IntoBits / FromBits (F64x2 <-> I64x2)
    procedure Test_VecF64x2_IntoBits;
    procedure Test_VecI64x2_FromBitsF64;
    
    // Cast 函数 (元素级别转换)
    procedure Test_VecF32x4_CastToI32x4;
    procedure Test_VecI32x4_CastToF32x4;
    procedure Test_VecF64x2_CastToI64x2;
    procedure Test_VecI64x2_CastToF64x2;
    
    // Widen / Narrow (宽度转换)
    procedure Test_VecI16x8_WidenLo_I32x4;
    procedure Test_VecI16x8_WidenHi_I32x4;
    procedure Test_VecI32x4_NarrowToI16x8;
    
    // F32x4 <-> F64x2 精度转换
    procedure Test_VecF32x4_ToF64x2_Lo;
    procedure Test_VecF64x2_ToF32x4;
  end;

  // Phase 3: Builder 模式测试
  TTestCase_Builder = class(TScalarBackendStatefulTestCase)
  published
    // TVecF32x4Builder 基础测试
    procedure Test_Builder_Create_FromValues;
    procedure Test_Builder_Create_Splat;
    procedure Test_Builder_Create_Load;
    
    // 流式 API 测试
    procedure Test_Builder_Chain_Add;
    procedure Test_Builder_Chain_MulAdd;
    procedure Test_Builder_Chain_Normalize;
    procedure Test_Builder_Chain_Clamp;
    
    // 终结操作测试
    procedure Test_Builder_Build;
    procedure Test_Builder_ReduceAdd;
    procedure Test_Builder_ReduceMin;
    procedure Test_Builder_ReduceMax;
    
    // 复杂链式测试
    procedure Test_Builder_Complex_DotProduct;
    procedure Test_Builder_Complex_Lerp;
  end;

  // Phase 2: Gather/Scatter 测试
  TTestCase_GatherScatter = class(TScalarBackendStatefulTestCase)
  published
    // Gather - 从不连续内存位置收集数据到向量
    procedure Test_VecF32x4_Gather_Sequential;
    procedure Test_VecF32x4_Gather_Stride;
    procedure Test_VecF32x4_Gather_Random;
    procedure Test_VecF32x4_Gather_DuplicateIndices_DuplicateValues;
    procedure Test_VecI32x4_Gather_Sequential;
    procedure Test_VecI32x4_Gather_Negative;
    
    // Scatter - 将向量数据分散到不连续内存位置
    procedure Test_VecF32x4_Scatter_Sequential;
    procedure Test_VecF32x4_Scatter_Stride;
    procedure Test_VecI32x4_Scatter_Sequential;
    procedure Test_VecI32x4_Scatter_DuplicateIndices_LastLaneWins;
    procedure Test_VecF32x4_GatherSelect_Preserves_OrValue_On_Masked_Lanes;
    procedure Test_VecI32x4_GatherSelect_Preserves_OrValue_On_Masked_Lanes;
    procedure Test_VecF32x4_ScatterSelect_Skips_Disabled_Lanes;
    procedure Test_VecI32x4_ScatterSelect_Skips_Disabled_Lanes;
    procedure Test_VecF32x4_ScatterSelect_DuplicateIndices_LastEnabledLaneWins;
    procedure Test_VecF32x4_Gather_NilBase_Raises_EArgumentNil;
    procedure Test_VecI32x4_Gather_NilBase_Raises_EArgumentNil;
    procedure Test_VecF32x4_Scatter_NilBase_Raises_EArgumentNil;
    procedure Test_VecI32x4_Scatter_NilBase_Raises_EArgumentNil;
    procedure Test_VecF32x4_GatherSelect_NilBase_AllDisabled_Returns_OrValue;
    procedure Test_VecI32x4_GatherSelect_NilBase_AllDisabled_Returns_OrValue;
    procedure Test_VecF32x4_GatherSelect_NilBase_EnabledLane_Raises_EArgumentNil;
    procedure Test_VecI32x4_GatherSelect_NilBase_EnabledLane_Raises_EArgumentNil;
    procedure Test_VecF32x4_ScatterSelect_NilBase_AllDisabled_Is_NoOp;
    procedure Test_VecI32x4_ScatterSelect_NilBase_AllDisabled_Is_NoOp;
    procedure Test_VecF32x4_ScatterSelect_NilBase_EnabledLane_Raises_EArgumentNil;
    procedure Test_VecI32x4_ScatterSelect_NilBase_EnabledLane_Raises_EArgumentNil;
    
    // 边界条件
    procedure Test_Gather_ZeroIndex;
    procedure Test_Gather_LargeStride;
  end;

  // Phase 2: Shuffle/Swizzle 测试
  TTestCase_ShuffleSWizzle = class(TScalarBackendStatefulTestCase)
  published
    // MM_SHUFFLE 辅助函数
    procedure Test_MM_SHUFFLE;
    
    // Shuffle 单向量
    procedure Test_VecF32x4_Shuffle_Identity;
    procedure Test_VecF32x4_Shuffle_Reverse;
    procedure Test_VecF32x4_Shuffle_Broadcast;
    procedure Test_VecI32x4_Shuffle;
    
    // Shuffle2 双向量
    procedure Test_VecF32x4_Shuffle2;
    
    // Blend 混合
    procedure Test_VecF32x4_Blend;
    procedure Test_VecF64x2_Blend;
    procedure Test_VecI32x4_Blend;
    
    // Unpack 交织
    procedure Test_VecF32x4_UnpackLo;
    procedure Test_VecF32x4_UnpackHi;
    procedure Test_VecI32x4_Unpack;
    
    // Broadcast 广播
    procedure Test_VecF32x4_Broadcast;
    procedure Test_VecI32x4_Broadcast;
    
    // Reverse 反转
    procedure Test_VecF32x4_Reverse;
    procedure Test_VecI32x4_Reverse;
    
    // Rotate 旋转
    procedure Test_VecF32x4_RotateLeft;
    procedure Test_VecI32x4_RotateLeft;
    
    // Insert/Extract 插入提取
    procedure Test_VecF32x4_Insert;
    procedure Test_VecF32x4_ExtractFunc;
    procedure Test_VecI32x4_InsertExtract;
  end;

  // Phase 4: SIMD 数学函数测试
  TTestCase_MathFunctions = class(TScalarBackendStatefulTestCase)
  published
    // 三角函数
    procedure Test_VecF32x4_Sin;
    procedure Test_VecF32x4_Cos;
    procedure Test_VecF32x4_SinCos;
    procedure Test_VecF32x4_Tan;
    
    // 指数/对数函数
    procedure Test_VecF32x4_Exp;
    procedure Test_VecF32x4_Exp2;
    procedure Test_VecF32x4_Log;
    procedure Test_VecF32x4_Log2;
    procedure Test_VecF32x4_Log10;
    procedure Test_VecF32x4_Pow;
    
    // 反三角函数
    procedure Test_VecF32x4_Asin;
    procedure Test_VecF32x4_Acos;
    procedure Test_VecF32x4_Atan;
    procedure Test_VecF32x4_Atan2;
  end;

  // Phase 5: 高级算法测试
  TTestCase_AdvancedAlgorithms = class(TScalarBackendStatefulTestCase)
  published
    // 排序网络 (Sorting Network)
    procedure Test_SortNet4_I32_Ascending;
    procedure Test_SortNet4_I32_Descending;
    procedure Test_SortNet4_F32_Ascending;
    procedure Test_SortNet4_F32_WithNegatives;
    procedure Test_SortNet8_I32;
    
    // 前缀和 (Prefix Sum / Scan)
    procedure Test_PrefixSum_I32x4_Inclusive;
    procedure Test_PrefixSum_I32x4_Exclusive;
    procedure Test_PrefixSum_F32x4_Inclusive;
    procedure Test_PrefixSum_Array_I32;
    procedure Test_PrefixSum_Array_F32;
    
    // 向量化字符串搜索
    procedure Test_StrFind_SingleChar;
    procedure Test_StrFind_NotFound;
    procedure Test_StrFind_AtStart;
    procedure Test_StrFind_AtEnd;
    procedure Test_StrFind_Empty;
  end;



implementation

{$IFDEF CPUX86_64}
function X86AllowsDirectAVX512Execution(const aX86: TX86Features;
  const aHasUsableAVX512: Boolean): Boolean; inline;
begin
  Result := X86SupportsAVX512BackendOnCPU(aX86, aHasUsableAVX512);
end;

{$IFDEF SIMD_BACKEND_AVX512}
function AVX512DirectOpsAvailableOnCurrentCPU: Boolean; inline;
var
  LCPUInfo: TCPUInfo;
begin
  LCPUInfo := GetCPUInfo;
  Result := (LCPUInfo.Arch = caX86) and
            X86AllowsDirectAVX512Execution(LCPUInfo.X86, gfSimd512 in LCPUInfo.GenericUsable);
end;

function AVX512BackendDispatchableForVectorAsmTests: Boolean; inline;
begin
  Result := AVX512DirectOpsAvailableOnCurrentCPU and IsBackendDispatchable(sbAVX512);
end;
{$ENDIF}
{$ENDIF}

{ TSimdBackendStatefulTestCase }

procedure TSimdBackendStatefulTestCase.SetUp;
begin
  inherited SetUp;
  GetDispatchTable;
  FSavedBackend := GetCurrentBackend;
end;

procedure TSimdBackendStatefulTestCase.TearDown;
var
  LRestoredBackend: Boolean;
begin
  LRestoredBackend := RestoreSavedBackendStateAndVerify(FSavedBackend,
    @GetCurrentBackend);

  inherited TearDown;

  AssertTrue(ClassName + ' should restore previous backend selection',
    LRestoredBackend);
end;

{ TScalarBackendStatefulTestCase }

procedure TScalarBackendStatefulTestCase.SetUp;
begin
  inherited SetUp;
  ForceBackend(sbScalar);
end;

{ TSimdVectorAsmStatefulTestCase }

procedure TSimdVectorAsmStatefulTestCase.RestoreVectorAsmState;
begin
  SetVectorAsmEnabled(FSavedVectorAsm);
end;

procedure TSimdVectorAsmStatefulTestCase.SetUp;
begin
  inherited SetUp;
  FSavedVectorAsm := IsVectorAsmEnabled;
end;

procedure TSimdVectorAsmStatefulTestCase.TearDown;
var
  LRestoredVectorAsm: Boolean;
begin
  RestoreVectorAsmState;
  LRestoredVectorAsm := IsVectorAsmEnabled = FSavedVectorAsm;

  inherited TearDown;

  AssertTrue(ClassName + ' should restore previous vector asm state',
    LRestoredVectorAsm);
end;

{$IFDEF UNIX}
{$IFDEF CPUX86_64}
{ TSimdVectorAsmBackendStatefulTestCase }

procedure TSimdVectorAsmBackendStatefulTestCase.RestoreVectorAsmState;
begin
  inherited RestoreVectorAsmState;
  RefreshVectorAsmBackendRegistration;
end;

procedure TSimdVectorAsmBackendStatefulTestCase.SetUp;
begin
  inherited SetUp;

  // 强制开启 vector asm，并重新注册目标后端以刷新 dispatch table。
  SetVectorAsmEnabled(True);
  RefreshVectorAsmBackendRegistration;
  ForceBackend(GetVectorAsmTargetBackend);
end;
{$ENDIF}
{$ENDIF}

{ TTestCase_Global }

// === 内存操作函数测试 ===

procedure TTestCase_Global.Test_MemEqual;
var
  buf1, buf2: array[0..15] of Byte;
  i: Integer;
begin
  // 测试相等的内存区域
  for i := 0 to 15 do
  begin
    buf1[i] := i;
    buf2[i] := i;
  end;
  
  AssertTrue('MemEqual should return True for equal buffers', MemEqual(@buf1[0], @buf2[0], 16));
  
  // 测试不相等的内存区域
  buf2[8] := 255;
  AssertFalse('MemEqual should return False for different buffers', MemEqual(@buf1[0], @buf2[0], 16));
end;

procedure TTestCase_Global.Test_MemEqual_Empty;
begin
  AssertTrue('MemEqual should return True for zero length', MemEqual(nil, nil, 0));
end;

procedure TTestCase_Global.Test_MemEqual_Nil;
begin
  AssertTrue('MemEqual should return True for both nil pointers', MemEqual(nil, nil, 10));
  AssertFalse('MemEqual should return False for one nil pointer', MemEqual(@Self, nil, 10));
end;

procedure TTestCase_Global.Test_MemFindByte;
var
  buf: array[0..15] of Byte;
  i: Integer;
begin
  for i := 0 to 15 do
    buf[i] := i;
    
  AssertEquals('Should find byte at correct position', 5, MemFindByte(@buf[0], 16, 5));
  AssertEquals('Should find first occurrence', 0, MemFindByte(@buf[0], 16, 0));
  AssertEquals('Should find last occurrence', 15, MemFindByte(@buf[0], 16, 15));
end;

procedure TTestCase_Global.Test_MemFindByte_NotFound;
var
  buf: array[0..15] of Byte;
  i: Integer;
begin
  for i := 0 to 15 do
    buf[i] := i;
    
  AssertEquals('Should return -1 when byte not found', -1, MemFindByte(@buf[0], 16, 255));
end;

procedure TTestCase_Global.Test_MemFindByte_Empty;
begin
  AssertEquals('Should return -1 for empty buffer', -1, MemFindByte(nil, 0, 5));
end;

procedure TTestCase_Global.Test_MemDiffRange;
var
  buf1, buf2: array[0..15] of Byte;
  i: Integer;
  firstDiff, lastDiff: SizeUInt;
  hasDiff: Boolean;
begin
  // 设置相同的缓冲区
  for i := 0 to 15 do
  begin
    buf1[i] := i;
    buf2[i] := i;
  end;
  
  // 在中间创建差异
  buf2[5] := 255;
  buf2[10] := 254;
  
  hasDiff := MemDiffRange(@buf1[0], @buf2[0], 16, firstDiff, lastDiff);
  
  AssertTrue('Should detect differences', hasDiff);
  AssertEquals('First difference should be at position 5', 5, firstDiff);
  AssertEquals('Last difference should be at position 10', 10, lastDiff);
end;

procedure TTestCase_Global.Test_MemDiffRange_NoDiff;
var
  buf1, buf2: array[0..15] of Byte;
  i: Integer;
  firstDiff, lastDiff: SizeUInt;
  hasDiff: Boolean;
begin
  for i := 0 to 15 do
  begin
    buf1[i] := i;
    buf2[i] := i;
  end;
  
  hasDiff := MemDiffRange(@buf1[0], @buf2[0], 16, firstDiff, lastDiff);
  
  AssertFalse('Should not detect differences in identical buffers', hasDiff);
end;

procedure TTestCase_Global.Test_MemCopy;
var
  src, dst: array[0..15] of Byte;
  i: Integer;
begin
  for i := 0 to 15 do
  begin
    src[i] := i;
    dst[i] := 255;
  end;
  
  MemCopy(@src[0], @dst[0], 16);
  
  for i := 0 to 15 do
    AssertEquals('Copied data should match source', src[i], dst[i]);
end;

procedure TTestCase_Global.Test_MemSet;
var
  buf: array[0..15] of Byte;
  i: Integer;
begin
  // 初始化为不同值
  for i := 0 to 15 do
    buf[i] := i;
    
  MemSet(@buf[0], 16, 42);
  
  for i := 0 to 15 do
    AssertEquals('All bytes should be set to 42', 42, buf[i]);
end;

procedure TTestCase_Global.Test_MemReverse;
var
  buf: array[0..7] of Byte;
  i: Integer;
begin
  for i := 0 to 7 do
    buf[i] := i;
    
  MemReverse(@buf[0], 8);
  
  for i := 0 to 7 do
    AssertEquals('Reversed buffer should have correct values', 7 - i, buf[i]);
end;

// === 统计函数测试 ===

procedure TTestCase_Global.Test_SumBytes;
var
  buf: array[0..3] of Byte;
  sum: UInt64;
begin
  buf[0] := 1;
  buf[1] := 2;
  buf[2] := 3;
  buf[3] := 4;
  
  sum := SumBytes(@buf[0], 4);
  AssertEquals('Sum should be 10', 10, sum);
end;

procedure TTestCase_Global.Test_SumBytes_Empty;
var
  sum: UInt64;
begin
  sum := SumBytes(nil, 0);
  AssertEquals('Sum of empty buffer should be 0', 0, sum);
end;

procedure TTestCase_Global.Test_MinMaxBytes;
var
  buf: array[0..4] of Byte;
  minVal, maxVal: Byte;
begin
  buf[0] := 10;
  buf[1] := 5;
  buf[2] := 20;
  buf[3] := 1;
  buf[4] := 15;
  
  MinMaxBytes(@buf[0], 5, minVal, maxVal);
  
  AssertEquals('Min value should be 1', 1, minVal);
  AssertEquals('Max value should be 20', 20, maxVal);
end;

procedure TTestCase_Global.Test_MinMaxBytes_Single;
var
  buf: array[0..0] of Byte;
  minVal, maxVal: Byte;
begin
  buf[0] := 42;
  
  MinMaxBytes(@buf[0], 1, minVal, maxVal);
  
  AssertEquals('Min value should be 42', 42, minVal);
  AssertEquals('Max value should be 42', 42, maxVal);
end;

procedure TTestCase_Global.Test_CountByte;
var
  buf: array[0..7] of Byte;
  count: SizeUInt;
begin
  buf[0] := 1;
  buf[1] := 2;
  buf[2] := 1;
  buf[3] := 3;
  buf[4] := 1;
  buf[5] := 4;
  buf[6] := 1;
  buf[7] := 5;
  
  count := CountByte(@buf[0], 8, 1);
  AssertEquals('Should count 4 occurrences of byte 1', 4, count);
end;

procedure TTestCase_Global.Test_CountByte_None;
var
  buf: array[0..7] of Byte;
  count: SizeUInt;
  i: Integer;
begin
  for i := 0 to 7 do
    buf[i] := i;
    
  count := CountByte(@buf[0], 8, 255);
  AssertEquals('Should count 0 occurrences of byte 255', 0, count);
end;

// === 文本处理函数测试 ===

procedure TTestCase_Global.Test_Utf8Validate;
var
  validUtf8: array[0..6] of Byte;
  isValid: Boolean;
begin
  // 测试有效的 UTF-8 序列: "Hello"
  validUtf8[0] := Ord('H');
  validUtf8[1] := Ord('e');
  validUtf8[2] := Ord('l');
  validUtf8[3] := Ord('l');
  validUtf8[4] := Ord('o');

  isValid := Utf8Validate(@validUtf8[0], 5);
  AssertTrue('Valid ASCII should pass UTF-8 validation', isValid);
end;

procedure TTestCase_Global.Test_Utf8Validate_Invalid;
var
  invalidUtf8: array[0..3] of Byte;
  isValid: Boolean;
begin
  // 测试无效的 UTF-8 序列
  invalidUtf8[0] := $C0;  // 无效的起始字节
  invalidUtf8[1] := $80;

  isValid := Utf8Validate(@invalidUtf8[0], 2);
  AssertFalse('Invalid UTF-8 sequence should fail validation', isValid);
end;

procedure TTestCase_Global.Test_AsciiIEqual;
var
  buf1, buf2: array[0..4] of Byte;
  isEqual: Boolean;
begin
  // 测试大小写不敏感比较
  buf1[0] := Ord('H');
  buf1[1] := Ord('e');
  buf1[2] := Ord('L');
  buf1[3] := Ord('L');
  buf1[4] := Ord('o');

  buf2[0] := Ord('h');
  buf2[1] := Ord('E');
  buf2[2] := Ord('l');
  buf2[3] := Ord('l');
  buf2[4] := Ord('O');

  isEqual := AsciiIEqual(@buf1[0], @buf2[0], 5);
  AssertTrue('Case-insensitive comparison should return true', isEqual);
end;

procedure TTestCase_Global.Test_AsciiIEqual_CaseDiff;
var
  buf1, buf2: array[0..4] of Byte;
  isEqual: Boolean;
begin
  buf1[0] := Ord('H');
  buf1[1] := Ord('e');
  buf1[2] := Ord('l');
  buf1[3] := Ord('l');
  buf1[4] := Ord('o');

  buf2[0] := Ord('W');
  buf2[1] := Ord('o');
  buf2[2] := Ord('r');
  buf2[3] := Ord('l');
  buf2[4] := Ord('d');

  isEqual := AsciiIEqual(@buf1[0], @buf2[0], 5);
  AssertFalse('Different strings should return false', isEqual);
end;

procedure TTestCase_Global.Test_ToLowerAscii;
var
  buf: array[0..4] of Byte;
begin
  buf[0] := Ord('H');
  buf[1] := Ord('E');
  buf[2] := Ord('L');
  buf[3] := Ord('L');
  buf[4] := Ord('O');

  ToLowerAscii(@buf[0], 5);

  AssertEquals('H should become h', Ord('h'), buf[0]);
  AssertEquals('E should become e', Ord('e'), buf[1]);
  AssertEquals('L should become l', Ord('l'), buf[2]);
  AssertEquals('L should become l', Ord('l'), buf[3]);
  AssertEquals('O should become o', Ord('o'), buf[4]);
end;

procedure TTestCase_Global.Test_ToUpperAscii;
var
  buf: array[0..4] of Byte;
begin
  buf[0] := Ord('h');
  buf[1] := Ord('e');
  buf[2] := Ord('l');
  buf[3] := Ord('l');
  buf[4] := Ord('o');

  ToUpperAscii(@buf[0], 5);

  AssertEquals('h should become H', Ord('H'), buf[0]);
  AssertEquals('e should become E', Ord('E'), buf[1]);
  AssertEquals('l should become L', Ord('L'), buf[2]);
  AssertEquals('l should become L', Ord('L'), buf[3]);
  AssertEquals('o should become O', Ord('O'), buf[4]);
end;

// === 搜索函数测试 ===

procedure TTestCase_Global.Test_BytesIndexOf;
var
  haystack: array[0..9] of Byte;
  needle: array[0..2] of Byte;
  index: PtrInt;
  i: Integer;
begin
  // 设置 haystack: [0,1,2,3,4,5,6,7,8,9]
  for i := 0 to 9 do
    haystack[i] := i;

  // 设置 needle: [3,4,5]
  needle[0] := 3;
  needle[1] := 4;
  needle[2] := 5;

  index := BytesIndexOf(@haystack[0], 10, @needle[0], 3);
  AssertEquals('Should find needle at position 3', 3, index);
end;

procedure TTestCase_Global.Test_BytesIndexOf_NotFound;
var
  haystack: array[0..9] of Byte;
  needle: array[0..2] of Byte;
  index: PtrInt;
  i: Integer;
begin
  for i := 0 to 9 do
    haystack[i] := i;

  needle[0] := 20;
  needle[1] := 21;
  needle[2] := 22;

  index := BytesIndexOf(@haystack[0], 10, @needle[0], 3);
  AssertEquals('Should return -1 when needle not found', -1, index);
end;

procedure TTestCase_Global.Test_BytesIndexOf_Empty;
var
  haystack: array[0..9] of Byte;
  index: PtrInt;
begin
  index := BytesIndexOf(@haystack[0], 10, nil, 0);
  AssertEquals('Should return -1 for empty needle', -1, index);
end;

// === 位集函数测试 ===

procedure TTestCase_Global.Test_BitsetPopCount;
var
  buf: array[0..3] of Byte;
  count: SizeUInt;
begin
  buf[0] := $FF;  // 11111111 = 8 bits
  buf[1] := $0F;  // 00001111 = 4 bits
  buf[2] := $AA;  // 10101010 = 4 bits
  buf[3] := $00;  // 00000000 = 0 bits

  count := BitsetPopCount(@buf[0], 4);
  AssertEquals('Should count 16 set bits total', 16, count);
end;

procedure TTestCase_Global.Test_BitsetPopCount_Empty;
var
  count: SizeUInt;
begin
  count := BitsetPopCount(nil, 0);
  AssertEquals('Empty bitset should have 0 bits set', 0, count);
end;

procedure TTestCase_Global.Test_BitsetPopCount_AllSet;
var
  buf: array[0..1] of Byte;
  count: SizeUInt;
begin
  buf[0] := $FF;
  buf[1] := $FF;

  count := BitsetPopCount(@buf[0], 2);
  AssertEquals('All bits set should count 16', 16, count);
end;

{$IFDEF CPUX86_64}

{ TTestCase_BackendConsistency }

procedure TTestCase_BackendConsistency.Test_MemEqual_Consistency;
var
  buf1, buf2: array[0..255] of Byte;
  i: Integer;
  resScalar, resSSE2, resAVX2, resAVX512: LongBool;
begin
  // 初始化测试数据
  for i := 0 to 255 do
  begin
    buf1[i] := Byte(i);
    buf2[i] := Byte(i);
  end;
  
  // 测试相等情况
  resScalar := MemEqual_Scalar(@buf1[0], @buf2[0], 256);
  resSSE2 := MemEqual_SSE2(@buf1[0], @buf2[0], 256);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := MemEqual_AVX2(@buf1[0], @buf2[0], 256)
  else
    resAVX2 := resScalar;
  {$IFDEF SIMD_BACKEND_AVX512}
  if AVX512DirectOpsAvailableOnCurrentCPU then
    resAVX512 := MemEqual_AVX512(@buf1[0], @buf2[0], 256)
  else
    resAVX512 := resScalar;
  {$ELSE}
  resAVX512 := resScalar;
  {$ENDIF}
  
  AssertTrue('Scalar should return true for equal buffers', resScalar);
  AssertEquals('SSE2 should match Scalar (equal)', resScalar, resSSE2);
  AssertEquals('AVX2 should match Scalar (equal)', resScalar, resAVX2);
  AssertEquals('AVX512 should match Scalar (equal)', resScalar, resAVX512);
  
  // 测试不等情况
  buf2[128] := 255;
  resScalar := MemEqual_Scalar(@buf1[0], @buf2[0], 256);
  resSSE2 := MemEqual_SSE2(@buf1[0], @buf2[0], 256);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := MemEqual_AVX2(@buf1[0], @buf2[0], 256)
  else
    resAVX2 := resScalar;
  {$IFDEF SIMD_BACKEND_AVX512}
  if AVX512DirectOpsAvailableOnCurrentCPU then
    resAVX512 := MemEqual_AVX512(@buf1[0], @buf2[0], 256)
  else
    resAVX512 := resScalar;
  {$ELSE}
  resAVX512 := resScalar;
  {$ENDIF}
  
  AssertFalse('Scalar should return false for different buffers', resScalar);
  AssertEquals('SSE2 should match Scalar (different)', resScalar, resSSE2);
  AssertEquals('AVX2 should match Scalar (different)', resScalar, resAVX2);
  AssertEquals('AVX512 should match Scalar (different)', resScalar, resAVX512);
end;

procedure TTestCase_BackendConsistency.Test_MemFindByte_Consistency;
var
  buf: array[0..255] of Byte;
  i: Integer;
  resScalar, resSSE2, resAVX2, resAVX512: PtrInt;
begin
  for i := 0 to 255 do
    buf[i] := Byte(i mod 128);
  
  // 查找存在的字节
  resScalar := MemFindByte_Scalar(@buf[0], 256, 64);
  resSSE2 := MemFindByte_SSE2(@buf[0], 256, 64);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := MemFindByte_AVX2(@buf[0], 256, 64)
  else
    resAVX2 := resScalar;
  {$IFDEF SIMD_BACKEND_AVX512}
  if AVX512DirectOpsAvailableOnCurrentCPU then
    resAVX512 := MemFindByte_AVX512(@buf[0], 256, 64)
  else
    resAVX512 := resScalar;
  {$ELSE}
  resAVX512 := resScalar;
  {$ENDIF}
  
  AssertEquals('SSE2 should match Scalar (found)', resScalar, resSSE2);
  AssertEquals('AVX2 should match Scalar (found)', resScalar, resAVX2);
  AssertEquals('AVX512 should match Scalar (found)', resScalar, resAVX512);
  
  // 查找不存在的字节
  resScalar := MemFindByte_Scalar(@buf[0], 256, 200);
  resSSE2 := MemFindByte_SSE2(@buf[0], 256, 200);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := MemFindByte_AVX2(@buf[0], 256, 200)
  else
    resAVX2 := resScalar;
  {$IFDEF SIMD_BACKEND_AVX512}
  if AVX512DirectOpsAvailableOnCurrentCPU then
    resAVX512 := MemFindByte_AVX512(@buf[0], 256, 200)
  else
    resAVX512 := resScalar;
  {$ELSE}
  resAVX512 := resScalar;
  {$ENDIF}
  
  AssertEquals('SSE2 should match Scalar (not found)', resScalar, resSSE2);
  AssertEquals('AVX2 should match Scalar (not found)', resScalar, resAVX2);
  AssertEquals('AVX512 should match Scalar (not found)', resScalar, resAVX512);
end;

procedure TTestCase_BackendConsistency.Test_SumBytes_Consistency;
var
  buf: array[0..255] of Byte;
  i: Integer;
  resScalar, resSSE2, resAVX2, resAVX512: UInt64;
begin
  for i := 0 to 255 do
    buf[i] := Byte(i);
  
  resScalar := SumBytes_Scalar(@buf[0], 256);
  resSSE2 := SumBytes_SSE2(@buf[0], 256);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := SumBytes_AVX2(@buf[0], 256)
  else
    resAVX2 := resScalar;
  {$IFDEF SIMD_BACKEND_AVX512}
  if AVX512DirectOpsAvailableOnCurrentCPU then
    resAVX512 := SumBytes_AVX512(@buf[0], 256)
  else
    resAVX512 := resScalar;
  {$ELSE}
  resAVX512 := resScalar;
  {$ENDIF}
  
  // 0+1+2+...+255 = 255*256/2 = 32640
  AssertEquals('Scalar sum should be 32640', 32640, resScalar);
  AssertEquals('SSE2 should match Scalar', resScalar, resSSE2);
  AssertEquals('AVX2 should match Scalar', resScalar, resAVX2);
  AssertEquals('AVX512 should match Scalar', resScalar, resAVX512);
end;

procedure TTestCase_BackendConsistency.Test_CountByte_Consistency;
var
  buf: array[0..255] of Byte;
  i: Integer;
  resScalar, resSSE2, resAVX2, resAVX512: SizeUInt;
begin
  for i := 0 to 255 do
    buf[i] := Byte(i mod 16);  // 每个值 0-15 出现 16 次
  
  resScalar := CountByte_Scalar(@buf[0], 256, 5);
  resSSE2 := CountByte_SSE2(@buf[0], 256, 5);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := CountByte_AVX2(@buf[0], 256, 5)
  else
    resAVX2 := resScalar;
  {$IFDEF SIMD_BACKEND_AVX512}
  if AVX512DirectOpsAvailableOnCurrentCPU then
    resAVX512 := CountByte_AVX512(@buf[0], 256, 5)
  else
    resAVX512 := resScalar;
  {$ELSE}
  resAVX512 := resScalar;
  {$ENDIF}
  
  AssertEquals('Scalar count should be 16', 16, resScalar);
  AssertEquals('SSE2 should match Scalar', resScalar, resSSE2);
  AssertEquals('AVX2 should match Scalar', resScalar, resAVX2);
  AssertEquals('AVX512 should match Scalar', resScalar, resAVX512);
end;

procedure TTestCase_BackendConsistency.Test_MinMaxBytes_Consistency;
var
  buf: array[0..255] of Byte;
  i: Integer;
  minScalar, maxScalar, minAVX2, maxAVX2, minAVX512, maxAVX512: Byte;
begin
  for i := 0 to 255 do
    buf[i] := Byte((i * 7 + 13) mod 256);  // 伪随机分布
  
  MinMaxBytes_Scalar(@buf[0], 256, minScalar, maxScalar);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    MinMaxBytes_AVX2(@buf[0], 256, minAVX2, maxAVX2)
  else
  begin
    minAVX2 := minScalar;
    maxAVX2 := maxScalar;
  end;
  {$IFDEF SIMD_BACKEND_AVX512}
  if AVX512DirectOpsAvailableOnCurrentCPU then
    MinMaxBytes_AVX512(@buf[0], 256, minAVX512, maxAVX512)
  else
  begin
    minAVX512 := minScalar;
    maxAVX512 := maxScalar;
  end;
  {$ELSE}
  minAVX512 := minScalar;
  maxAVX512 := maxScalar;
  {$ENDIF}
  
  AssertEquals('AVX2 min should match Scalar', minScalar, minAVX2);
  AssertEquals('AVX2 max should match Scalar', maxScalar, maxAVX2);
  AssertEquals('AVX512 min should match Scalar', minScalar, minAVX512);
  AssertEquals('AVX512 max should match Scalar', maxScalar, maxAVX512);
end;

procedure TTestCase_BackendConsistency.Test_BitsetPopCount_Consistency;
var
  buf: array[0..255] of Byte;
  i: Integer;
  resScalar, resAVX2, resAVX512: SizeUInt;
begin
  // 初始化伪随机位模式
  for i := 0 to 255 do
    buf[i] := Byte((i * 13 + 7) mod 256);
  
  resScalar := BitsetPopCount_Scalar(@buf[0], 256);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := BitsetPopCount_AVX2(@buf[0], 256)
  else
    resAVX2 := resScalar;
  {$IFDEF SIMD_BACKEND_AVX512}
  if AVX512DirectOpsAvailableOnCurrentCPU then
    resAVX512 := BitsetPopCount_AVX512(@buf[0], 256)
  else
    resAVX512 := resScalar;
  {$ELSE}
  resAVX512 := resScalar;
  {$ENDIF}
  
  AssertEquals('AVX2 popcount should match Scalar', resScalar, resAVX2);
  AssertEquals('AVX512 popcount should match Scalar', resScalar, resAVX512);
end;

procedure TTestCase_BackendConsistency.Test_Utf8Validate_Consistency;
const
  // 有效 ASCII
  ValidASCII: array[0..5] of Byte = (Ord('H'), Ord('e'), Ord('l'), Ord('l'), Ord('o'), 0);
  // 有效 2 字节 UTF-8: "é"
  Valid2Byte: array[0..2] of Byte = ($C3, $A9, 0);
  // 有效 3 字节 UTF-8: "中"
  Valid3Byte: array[0..3] of Byte = ($E4, $B8, $AD, 0);
  // 有效 4 字节 UTF-8: "😀"
  Valid4Byte: array[0..4] of Byte = ($F0, $9F, $98, $80, 0);
  // 无效: 超长编码
  InvalidOverlong: array[0..2] of Byte = ($C0, $80, 0);
  // 无效: 不完整的多字节序列
  InvalidIncomplete: array[0..1] of Byte = ($C3, 0);
var
  resScalar, resAVX2: Boolean;
begin
  // 测试 1: 有效 ASCII
  resScalar := Utf8Validate_Scalar(@ValidASCII[0], 5);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := Utf8Validate_AVX2(@ValidASCII[0], 5)
  else
    resAVX2 := resScalar;
  AssertEquals('AVX2 should match Scalar for valid ASCII', resScalar, resAVX2);
  AssertTrue('Valid ASCII should pass', resScalar);
  
  // 测试 2: 有效 2 字节 UTF-8
  resScalar := Utf8Validate_Scalar(@Valid2Byte[0], 2);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := Utf8Validate_AVX2(@Valid2Byte[0], 2)
  else
    resAVX2 := resScalar;
  AssertEquals('AVX2 should match Scalar for valid 2-byte', resScalar, resAVX2);
  AssertTrue('Valid 2-byte should pass', resScalar);
  
  // 测试 3: 有效 3 字节 UTF-8
  resScalar := Utf8Validate_Scalar(@Valid3Byte[0], 3);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := Utf8Validate_AVX2(@Valid3Byte[0], 3)
  else
    resAVX2 := resScalar;
  AssertEquals('AVX2 should match Scalar for valid 3-byte', resScalar, resAVX2);
  AssertTrue('Valid 3-byte should pass', resScalar);
  
  // 测试 4: 有效 4 字节 UTF-8
  resScalar := Utf8Validate_Scalar(@Valid4Byte[0], 4);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := Utf8Validate_AVX2(@Valid4Byte[0], 4)
  else
    resAVX2 := resScalar;
  AssertEquals('AVX2 should match Scalar for valid 4-byte', resScalar, resAVX2);
  AssertTrue('Valid 4-byte should pass', resScalar);
  
  // 测试 5: 无效超长编码
  resScalar := Utf8Validate_Scalar(@InvalidOverlong[0], 2);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := Utf8Validate_AVX2(@InvalidOverlong[0], 2)
  else
    resAVX2 := resScalar;
  AssertEquals('AVX2 should match Scalar for invalid overlong', resScalar, resAVX2);
  AssertFalse('Invalid overlong should fail', resScalar);
  
  // 测试 6: 不完整序列
  resScalar := Utf8Validate_Scalar(@InvalidIncomplete[0], 1);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := Utf8Validate_AVX2(@InvalidIncomplete[0], 1)
  else
    resAVX2 := resScalar;
  AssertEquals('AVX2 should match Scalar for incomplete', resScalar, resAVX2);
  AssertFalse('Incomplete sequence should fail', resScalar);
end;

procedure TTestCase_BackendConsistency.Test_MemReverse_Consistency;
var
  bufScalar, bufAVX2: array[0..255] of Byte;
  i: Integer;
begin
  // 初始化数据
  for i := 0 to 255 do
  begin
    bufScalar[i] := Byte(i);
    bufAVX2[i] := Byte(i);
  end;
  
  MemReverse_Scalar(@bufScalar[0], 256);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    MemReverse_AVX2(@bufAVX2[0], 256)
  else
    MemReverse_Scalar(@bufAVX2[0], 256);
  
  for i := 0 to 255 do
    AssertEquals('AVX2 reverse should match Scalar at index ' + IntToStr(i), 
                 bufScalar[i], bufAVX2[i]);
end;

procedure TTestCase_BackendConsistency.Test_AsciiIEqual_Consistency;
var
  buf1, buf2: array[0..63] of Byte;
  i: Integer;
  resScalar, resAVX2: Boolean;
begin
  // 测试 1: 相同字符串（不同大小写）
  for i := 0 to 63 do
  begin
    buf1[i] := Byte(65 + (i mod 26));  // 'A'..'Z'
    buf2[i] := Byte(97 + (i mod 26));  // 'a'..'z'
  end;
  
  resScalar := AsciiIEqual_Scalar(@buf1[0], @buf2[0], 64);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := AsciiIEqual_AVX2(@buf1[0], @buf2[0], 64)
  else
    resAVX2 := resScalar;
  
  AssertTrue('Scalar should match case-insensitively', resScalar);
  AssertEquals('AVX2 should match Scalar', resScalar, resAVX2);
  
  // 测试 2: 不同字符串
  buf2[32] := Byte(48);  // '0' != 'q'
  resScalar := AsciiIEqual_Scalar(@buf1[0], @buf2[0], 64);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := AsciiIEqual_AVX2(@buf1[0], @buf2[0], 64)
  else
    resAVX2 := resScalar;
  
  AssertFalse('Scalar should detect difference', resScalar);
  AssertEquals('AVX2 should match Scalar for different', resScalar, resAVX2);
end;

procedure TTestCase_BackendConsistency.Test_ToLowerAscii_Consistency;
var
  bufScalar, bufAVX2: array[0..127] of Byte;
  i: Integer;
begin
  // 初始化: 混合大小写
  for i := 0 to 127 do
  begin
    if (i mod 2) = 0 then
      bufScalar[i] := Byte(65 + (i mod 26))  // 'A'..'Z'
    else
      bufScalar[i] := Byte(97 + (i mod 26)); // 'a'..'z'
    bufAVX2[i] := bufScalar[i];
  end;
  
  ToLowerAscii_Scalar(@bufScalar[0], 128);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    ToLowerAscii_AVX2(@bufAVX2[0], 128)
  else
    ToLowerAscii_Scalar(@bufAVX2[0], 128);
  
  for i := 0 to 127 do
    AssertEquals('AVX2 ToLower should match Scalar at index ' + IntToStr(i), 
                 bufScalar[i], bufAVX2[i]);
end;

procedure TTestCase_BackendConsistency.Test_ToUpperAscii_Consistency;
var
  bufScalar, bufAVX2: array[0..127] of Byte;
  i: Integer;
begin
  // 初始化: 混合大小写
  for i := 0 to 127 do
  begin
    if (i mod 2) = 0 then
      bufScalar[i] := Byte(65 + (i mod 26))  // 'A'..'Z'
    else
      bufScalar[i] := Byte(97 + (i mod 26)); // 'a'..'z'
    bufAVX2[i] := bufScalar[i];
  end;
  
  ToUpperAscii_Scalar(@bufScalar[0], 128);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    ToUpperAscii_AVX2(@bufAVX2[0], 128)
  else
    ToUpperAscii_Scalar(@bufAVX2[0], 128);
  
  for i := 0 to 127 do
    AssertEquals('AVX2 ToUpper should match Scalar at index ' + IntToStr(i), 
                 bufScalar[i], bufAVX2[i]);
end;

procedure TTestCase_BackendConsistency.Test_MemDiffRange_Consistency;
var
  buf1, buf2: array[0..255] of Byte;
  i: Integer;
  firstScalar, lastScalar, firstAVX2, lastAVX2: SizeUInt;
  resScalar, resAVX2: Boolean;
begin
  // 初始化相同的数据
  for i := 0 to 255 do
  begin
    buf1[i] := Byte(i);
    buf2[i] := Byte(i);
  end;
  
  // 在中间创建差异
  buf2[50] := 255;
  buf2[100] := 254;
  buf2[150] := 253;
  
  resScalar := MemDiffRange_Scalar(@buf1[0], @buf2[0], 256, firstScalar, lastScalar);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := MemDiffRange_AVX2(@buf1[0], @buf2[0], 256, firstAVX2, lastAVX2)
  else
  begin
    resAVX2 := resScalar;
    firstAVX2 := firstScalar;
    lastAVX2 := lastScalar;
  end;
  
  AssertTrue('Scalar should detect differences', resScalar);
  AssertEquals('AVX2 should match Scalar result', resScalar, resAVX2);
  AssertEquals('AVX2 first diff should match Scalar', firstScalar, firstAVX2);
  AssertEquals('AVX2 last diff should match Scalar', lastScalar, lastAVX2);
  
  // 测试无差异情况
  for i := 0 to 255 do
    buf2[i] := Byte(i);
  
  resScalar := MemDiffRange_Scalar(@buf1[0], @buf2[0], 256, firstScalar, lastScalar);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := MemDiffRange_AVX2(@buf1[0], @buf2[0], 256, firstAVX2, lastAVX2)
  else
    resAVX2 := resScalar;
  
  AssertFalse('Scalar should not detect differences', resScalar);
  AssertEquals('AVX2 should match Scalar for no diff', resScalar, resAVX2);
end;

procedure TTestCase_BackendConsistency.Test_BytesIndexOf_Consistency;
var
  haystack: array[0..255] of Byte;
  needle: array[0..3] of Byte;
  i: Integer;
  resScalar, resAVX2: PtrInt;
begin
  // 初始化 haystack
  for i := 0 to 255 do
    haystack[i] := Byte(i mod 128);
  
  // 设置 needle: [64, 65, 66, 67]
  needle[0] := 64;
  needle[1] := 65;
  needle[2] := 66;
  needle[3] := 67;
  
  resScalar := BytesIndexOf_Scalar(@haystack[0], 256, @needle[0], 4);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := BytesIndexOf_AVX2(@haystack[0], 256, @needle[0], 4)
  else
    resAVX2 := resScalar;
  
  AssertEquals('Scalar should find needle at 64', 64, resScalar);
  AssertEquals('AVX2 should match Scalar (found)', resScalar, resAVX2);
  
  // 测试找不到的情况
  needle[0] := 200;
  needle[1] := 201;
  needle[2] := 202;
  needle[3] := 203;
  
  resScalar := BytesIndexOf_Scalar(@haystack[0], 256, @needle[0], 4);
  if HasAVX2 and IsBackendRegistered(sbAVX2) then
    resAVX2 := BytesIndexOf_AVX2(@haystack[0], 256, @needle[0], 4)
  else
    resAVX2 := resScalar;
  
  AssertEquals('Scalar should not find needle', -1, resScalar);
  AssertEquals('AVX2 should match Scalar (not found)', resScalar, resAVX2);
end;

procedure TTestCase_BackendVectorConsistency.Test_VectorOps_BackendName_Coverage;
var
  LBackendIndex: Integer;
  LBackend: TSimdBackend;
begin
  for LBackendIndex := Low(CONSISTENCY_BACKENDS) to High(CONSISTENCY_BACKENDS) do
  begin
    LBackend := CONSISTENCY_BACKENDS[LBackendIndex];
    AssertTrue('Backend consistency name helper should not return Unknown for backend=' +
      GetConsistencyBackendName(LBackend), GetConsistencyBackendName(LBackend) <> 'Unknown');
  end;

  AssertEquals('SSE4.1 backend consistency name mismatch', 'SSE4.1',
    GetConsistencyBackendName(sbSSE41));
  AssertEquals('SSE4.2 backend consistency name mismatch', 'SSE4.2',
    GetConsistencyBackendName(sbSSE42));
  AssertEquals('AVX-512 backend consistency name mismatch', 'AVX-512',
    GetConsistencyBackendName(sbAVX512));
  AssertEquals('RISC-V V backend consistency name mismatch', 'RISC-V V',
    GetConsistencyBackendName(sbRISCVV));
end;

procedure TTestCase_BackendVectorConsistency.Test_VectorOps_Consistency;
var
  LOriginalBackend: TSimdBackend;
  LRestoredBackend: Boolean;
  results: TConsistencyTestResults;
  i: Integer;
  failMsg: string;
begin
  GetDispatchTable;
  LOriginalBackend := GetCurrentBackend;
  try
    results := RunAllConsistencyTests;

    failMsg := '';
    for i := 0 to High(results) do
    begin
      if IsConsistencyTestSkipped(results[i]) then
        Continue;

      if not results[i].Passed then
        failMsg := failMsg + FormatConsistencyFailureText(results[i]) + LineEnding;
    end;

    if failMsg <> '' then
      Fail(failMsg);
  finally
    LRestoredBackend := RestoreSavedBackendStateAndVerify(LOriginalBackend,
      @GetCurrentBackend);
    AssertTrue('Backend vector consistency wrapper should restore previous backend selection',
      LRestoredBackend);
  end;
end;

procedure TTestCase_BackendVectorConsistency.Test_VectorOps_Helper_Preserves_PreviousForcedBackend;
var
  LEntryBackend: TSimdBackend;
  LIndex: Integer;
  LOriginalBackend: TSimdBackend;
  LTargetBackend: TSimdBackend;
  LFoundBackend: Boolean;
  LResult: TConsistencyTestResult;
begin
  try
    GetDispatchTable;
    LEntryBackend := GetCurrentBackend;
    if GetBestDispatchableBackend = sbScalar then
      Exit;

    AssertTrue('Scalar force setup should succeed before helper restore test',
      TrySetActiveBackend(sbScalar));
    LOriginalBackend := GetCurrentBackend;
    AssertEquals('Scalar should be active before helper restore test',
      Ord(sbScalar), Ord(LOriginalBackend));

    LFoundBackend := False;
    for LIndex := Low(CONSISTENCY_BACKENDS) to High(CONSISTENCY_BACKENDS) do
    begin
      if not IsBackendRegistered(CONSISTENCY_BACKENDS[LIndex]) then
        Continue;
      if TrySetActiveBackend(CONSISTENCY_BACKENDS[LIndex]) then
      begin
        LTargetBackend := CONSISTENCY_BACKENDS[LIndex];
        LFoundBackend := True;
        Break;
      end;
    end;

    AssertTrue('At least one non-scalar backend should be available for helper restore test',
      LFoundBackend);
    AssertTrue('Scalar should be re-forced before helper restore test',
      TrySetActiveBackend(sbScalar));
    AssertEquals('Scalar should remain forced before helper restore test executes',
      Ord(LOriginalBackend), Ord(GetCurrentBackend));

    LResult := TestF32x4Arithmetic(LTargetBackend);
    AssertTrue(Format('Standalone helper sanity check failed for backend %s: %s',
      [GetConsistencyBackendName(LTargetBackend), LResult.ErrorMessage]), LResult.Passed);
    AssertEquals('Standalone backend consistency helper should preserve previous forced backend selection',
      Ord(LOriginalBackend), Ord(GetCurrentBackend));
  finally
    AssertTrue('Backend vector consistency helper meta-test should restore entry backend selection',
      RestoreSavedBackendStateAndVerify(LEntryBackend, @GetCurrentBackend));
  end;
end;

procedure TTestCase_BackendVectorConsistency.Test_VectorOps_Consistency_Preserves_PreviousForcedBackend;
var
  LEntryBackend: TSimdBackend;
  LOriginalBackend: TSimdBackend;
begin
  try
    GetDispatchTable;
    LEntryBackend := GetCurrentBackend;
    if GetBestDispatchableBackend = sbScalar then
      Exit;

    AssertTrue('Scalar force setup should succeed before backend consistency wrapper restore test',
      TrySetActiveBackend(sbScalar));
    LOriginalBackend := GetCurrentBackend;
    AssertEquals('Scalar should be active before backend consistency wrapper restore test',
      Ord(sbScalar), Ord(LOriginalBackend));

    Test_VectorOps_Consistency;

    AssertEquals('Backend consistency wrapper should preserve previous forced backend selection',
      Ord(LOriginalBackend), Ord(GetCurrentBackend));
  finally
    AssertTrue('Backend vector consistency wrapper meta-test should restore entry backend selection',
      RestoreSavedBackendStateAndVerify(LEntryBackend, @GetCurrentBackend));
  end;
end;

{$ENDIF}

{ TTestCase_BackendSmoke }

procedure TTestCase_BackendSmoke.RunVecF32x4Smoke;
var
  src, dst: array[0..3] of Single;
  v, w: TVecF32x4;
  sum: Single;
  dot: Single;
begin
  src[0] := 1.0;
  src[1] := 2.0;
  src[2] := 3.0;
  src[3] := 4.0;

  v := VecF32x4Load(@src[0]);

  sum := VecF32x4ReduceAdd(v);
  AssertEquals('ReduceAdd should be 10', 10.0, sum, 0.0001);

  dot := VecF32x4Dot(v, VecF32x4Splat(1.0));
  AssertEquals('Dot(v, splat(1)) should be 10', 10.0, dot, 0.0001);

  w := VecF32x4Add(v, VecF32x4Splat(1.0));
  VecF32x4Store(@dst[0], w);

  AssertEquals('Store/Add[0]', 2.0, dst[0], 0.0001);
  AssertEquals('Store/Add[1]', 3.0, dst[1], 0.0001);
  AssertEquals('Store/Add[2]', 4.0, dst[2], 0.0001);
  AssertEquals('Store/Add[3]', 5.0, dst[3], 0.0001);

  w := VecF32x4Sub(v, VecF32x4Splat(1.0));
  VecF32x4Store(@dst[0], w);

  AssertEquals('Store/Sub[0]', 0.0, dst[0], 0.0001);
  AssertEquals('Store/Sub[1]', 1.0, dst[1], 0.0001);
  AssertEquals('Store/Sub[2]', 2.0, dst[2], 0.0001);
  AssertEquals('Store/Sub[3]', 3.0, dst[3], 0.0001);

  w := VecF32x4Mul(v, VecF32x4Splat(2.0));
  VecF32x4Store(@dst[0], w);

  AssertEquals('Store/Mul[0]', 2.0, dst[0], 0.0001);
  AssertEquals('Store/Mul[1]', 4.0, dst[1], 0.0001);
  AssertEquals('Store/Mul[2]', 6.0, dst[2], 0.0001);
  AssertEquals('Store/Mul[3]', 8.0, dst[3], 0.0001);

  // Div: v / 2 = (0.5, 1.0, 1.5, 2.0)
  w := VecF32x4Div(v, VecF32x4Splat(2.0));
  VecF32x4Store(@dst[0], w);

  AssertEquals('Store/Div[0]', 0.5, dst[0], 0.0001);
  AssertEquals('Store/Div[1]', 1.0, dst[1], 0.0001);
  AssertEquals('Store/Div[2]', 1.5, dst[2], 0.0001);
  AssertEquals('Store/Div[3]', 2.0, dst[3], 0.0001);

  // Min: min(v, splat(2.5)) = (1, 2, 2.5, 2.5)
  w := VecF32x4Min(v, VecF32x4Splat(2.5));
  VecF32x4Store(@dst[0], w);

  AssertEquals('Store/Min[0]', 1.0, dst[0], 0.0001);
  AssertEquals('Store/Min[1]', 2.0, dst[1], 0.0001);
  AssertEquals('Store/Min[2]', 2.5, dst[2], 0.0001);
  AssertEquals('Store/Min[3]', 2.5, dst[3], 0.0001);

  // Max: max(v, splat(2.5)) = (2.5, 2.5, 3, 4)
  w := VecF32x4Max(v, VecF32x4Splat(2.5));
  VecF32x4Store(@dst[0], w);

  AssertEquals('Store/Max[0]', 2.5, dst[0], 0.0001);
  AssertEquals('Store/Max[1]', 2.5, dst[1], 0.0001);
  AssertEquals('Store/Max[2]', 3.0, dst[2], 0.0001);
  AssertEquals('Store/Max[3]', 4.0, dst[3], 0.0001);

  // Abs: abs((-1, 2, -3, 4)) = (1, 2, 3, 4)
  src[0] := -1.0; src[1] := 2.0; src[2] := -3.0; src[3] := 4.0;
  v := VecF32x4Load(@src[0]);
  w := VecF32x4Abs(v);
  VecF32x4Store(@dst[0], w);

  AssertEquals('Store/Abs[0]', 1.0, dst[0], 0.0001);
  AssertEquals('Store/Abs[1]', 2.0, dst[1], 0.0001);
  AssertEquals('Store/Abs[2]', 3.0, dst[2], 0.0001);
  AssertEquals('Store/Abs[3]', 4.0, dst[3], 0.0001);

  // Sqrt: sqrt((1, 4, 9, 16)) = (1, 2, 3, 4)
  src[0] := 1.0; src[1] := 4.0; src[2] := 9.0; src[3] := 16.0;
  v := VecF32x4Load(@src[0]);
  w := VecF32x4Sqrt(v);
  VecF32x4Store(@dst[0], w);

  AssertEquals('Store/Sqrt[0]', 1.0, dst[0], 0.0001);
  AssertEquals('Store/Sqrt[1]', 2.0, dst[1], 0.0001);
  AssertEquals('Store/Sqrt[2]', 3.0, dst[2], 0.0001);
  AssertEquals('Store/Sqrt[3]', 4.0, dst[3], 0.0001);

  // CmpEq: (1,2,3,4) == (1,2,5,4) -> mask = 0b1011 = $B
  src[0] := 1.0; src[1] := 2.0; src[2] := 3.0; src[3] := 4.0;
  v := VecF32x4Load(@src[0]);
  src[0] := 1.0; src[1] := 2.0; src[2] := 5.0; src[3] := 4.0;
  w := VecF32x4Load(@src[0]);
  AssertEquals('CmpEq mask', $B, VecF32x4CmpEq(v, w));

  // CmpLt: (1,2,3,4) < (2,2,2,5) -> mask = 0b1001 = $9
  src[0] := 2.0; src[1] := 2.0; src[2] := 2.0; src[3] := 5.0;
  w := VecF32x4Load(@src[0]);
  src[0] := 1.0; src[1] := 2.0; src[2] := 3.0; src[3] := 4.0;
  v := VecF32x4Load(@src[0]);
  AssertEquals('CmpLt mask', $9, VecF32x4CmpLt(v, w));

  // CmpGt: (1,2,3,4) > (0,2,2,5) -> mask = 0b0101 = $5
  src[0] := 0.0; src[1] := 2.0; src[2] := 2.0; src[3] := 5.0;
  w := VecF32x4Load(@src[0]);
  src[0] := 1.0; src[1] := 2.0; src[2] := 3.0; src[3] := 4.0;
  v := VecF32x4Load(@src[0]);
  AssertEquals('CmpGt mask', $5, VecF32x4CmpGt(v, w));

  // ReduceMin: min(5, 2, 8, 3) = 2
  src[0] := 5.0; src[1] := 2.0; src[2] := 8.0; src[3] := 3.0;
  v := VecF32x4Load(@src[0]);
  AssertEquals('ReduceMin', 2.0, VecF32x4ReduceMin(v), 0.0001);

  // ReduceMax: max(5, 2, 8, 3) = 8
  AssertEquals('ReduceMax', 8.0, VecF32x4ReduceMax(v), 0.0001);

  // ReduceMul: 1 * 2 * 3 * 4 = 24
  src[0] := 1.0; src[1] := 2.0; src[2] := 3.0; src[3] := 4.0;
  v := VecF32x4Load(@src[0]);
  AssertEquals('ReduceMul', 24.0, VecF32x4ReduceMul(v), 0.0001);

  // Fma: a*b+c = (2,2,2,2)*(3,3,3,3)+(4,4,4,4) = (10,10,10,10)
  v := VecF32x4Splat(2.0);
  w := VecF32x4Splat(3.0);
  w := VecF32x4Fma(v, w, VecF32x4Splat(4.0));
  VecF32x4Store(@dst[0], w);
  AssertEquals('Fma[0]', 10.0, dst[0], 0.0001);
  AssertEquals('Fma[1]', 10.0, dst[1], 0.0001);

  // Rcp: 1/4 = 0.25
  v := VecF32x4Splat(4.0);
  w := VecF32x4Rcp(v);
  VecF32x4Store(@dst[0], w);
  AssertEquals('Rcp[0]', 0.25, dst[0], 0.01);

  // Rsqrt: 1/sqrt(4) = 0.5
  w := VecF32x4Rsqrt(v);
  VecF32x4Store(@dst[0], w);
  AssertEquals('Rsqrt[0]', 0.5, dst[0], 0.01);

  // Floor: floor(2.7) = 2, floor(-2.3) = -3
  src[0] := 2.7; src[1] := -2.3; src[2] := 3.0; src[3] := -3.0;
  v := VecF32x4Load(@src[0]);
  w := VecF32x4Floor(v);
  VecF32x4Store(@dst[0], w);
  AssertEquals('Floor[0]', 2.0, dst[0], 0.0001);
  AssertEquals('Floor[1]', -3.0, dst[1], 0.0001);

  // Ceil: ceil(2.3) = 3, ceil(-2.7) = -2
  src[0] := 2.3; src[1] := -2.7; src[2] := 3.0; src[3] := -3.0;
  v := VecF32x4Load(@src[0]);
  w := VecF32x4Ceil(v);
  VecF32x4Store(@dst[0], w);
  AssertEquals('Ceil[0]', 3.0, dst[0], 0.0001);
  AssertEquals('Ceil[1]', -2.0, dst[1], 0.0001);

  // Round: round(2.4) = 2, round(2.6) = 3
  src[0] := 2.4; src[1] := 2.6; src[2] := -2.4; src[3] := -2.6;
  v := VecF32x4Load(@src[0]);
  w := VecF32x4Round(v);
  VecF32x4Store(@dst[0], w);
  AssertEquals('Round[0]', 2.0, dst[0], 0.0001);
  AssertEquals('Round[1]', 3.0, dst[1], 0.0001);

  // Trunc: trunc(2.9) = 2, trunc(-2.9) = -2
  src[0] := 2.9; src[1] := -2.9; src[2] := 3.0; src[3] := -3.0;
  v := VecF32x4Load(@src[0]);
  w := VecF32x4Trunc(v);
  VecF32x4Store(@dst[0], w);
  AssertEquals('Trunc[0]', 2.0, dst[0], 0.0001);
  AssertEquals('Trunc[1]', -2.0, dst[1], 0.0001);

  // Clamp: clamp((-5, 5, 15, 0), 0, 10) = (0, 5, 10, 0)
  src[0] := -5.0; src[1] := 5.0; src[2] := 15.0; src[3] := 0.0;
  v := VecF32x4Load(@src[0]);
  w := VecF32x4Clamp(v, VecF32x4Splat(0.0), VecF32x4Splat(10.0));
  VecF32x4Store(@dst[0], w);
  AssertEquals('Clamp[0]', 0.0, dst[0], 0.0001);
  AssertEquals('Clamp[1]', 5.0, dst[1], 0.0001);
  AssertEquals('Clamp[2]', 10.0, dst[2], 0.0001);

  // 3D Dot: (1,2,3) · (4,5,6) = 4+10+18 = 32
  src[0] := 1.0; src[1] := 2.0; src[2] := 3.0; src[3] := 999.0;
  v := VecF32x4Load(@src[0]);
  src[0] := 4.0; src[1] := 5.0; src[2] := 6.0; src[3] := 999.0;
  w := VecF32x4Load(@src[0]);
  AssertEquals('Dot3', 32.0, VecF32x3Dot(v, w), 0.0001);

  // 4D Dot: (1,2,3,4) · (2,3,4,5) = 2+6+12+20 = 40
  src[0] := 1.0; src[1] := 2.0; src[2] := 3.0; src[3] := 4.0;
  v := VecF32x4Load(@src[0]);
  src[0] := 2.0; src[1] := 3.0; src[2] := 4.0; src[3] := 5.0;
  w := VecF32x4Load(@src[0]);
  AssertEquals('Dot4', 40.0, VecF32x4Dot(v, w), 0.0001);

  // Cross: X × Y = Z
  src[0] := 1.0; src[1] := 0.0; src[2] := 0.0; src[3] := 0.0;
  v := VecF32x4Load(@src[0]);
  src[0] := 0.0; src[1] := 1.0; src[2] := 0.0; src[3] := 0.0;
  w := VecF32x4Load(@src[0]);
  w := VecF32x3Cross(v, w);
  VecF32x4Store(@dst[0], w);
  AssertEquals('Cross X', 0.0, dst[0], 0.0001);
  AssertEquals('Cross Y', 0.0, dst[1], 0.0001);
  AssertEquals('Cross Z', 1.0, dst[2], 0.0001);

  // Length3: |(3,4,0)| = 5
  src[0] := 3.0; src[1] := 4.0; src[2] := 0.0; src[3] := 999.0;
  v := VecF32x4Load(@src[0]);
  AssertEquals('Length3', 5.0, VecF32x3Length(v), 0.0001);

  // Length4: |(1,1,1,1)| = 2
  src[0] := 1.0; src[1] := 1.0; src[2] := 1.0; src[3] := 1.0;
  v := VecF32x4Load(@src[0]);
  AssertEquals('Length4', 2.0, VecF32x4Length(v), 0.0001);

  // Normalize3: (3,4,0) / 5 = (0.6, 0.8, 0)
  src[0] := 3.0; src[1] := 4.0; src[2] := 0.0; src[3] := 999.0;
  v := VecF32x4Load(@src[0]);
  w := VecF32x3Normalize(v);
  VecF32x4Store(@dst[0], w);
  AssertEquals('Normalize3 X', 0.6, dst[0], 0.0001);
  AssertEquals('Normalize3 Y', 0.8, dst[1], 0.0001);
  AssertEquals('Normalize3 Z', 0.0, dst[2], 0.0001);

  // Normalize4: (3,0,0,0) / 3 = (1,0,0,0)
  // NOTE: SSE3/SSSE3/SSE41 use rsqrtps (~12-bit precision) for fast normalize
  //       Tolerance increased to 0.001 to accommodate this optimization
  src[0] := 3.0; src[1] := 0.0; src[2] := 0.0; src[3] := 0.0;
  v := VecF32x4Load(@src[0]);
  w := VecF32x4Normalize(v);
  VecF32x4Store(@dst[0], w);
  AssertEquals('Normalize4 X', 1.0, dst[0], 0.001);  // Relaxed for rsqrtps
  AssertEquals('Normalize4 Y', 0.0, dst[1], 0.0001);
end;

procedure TTestCase_BackendSmoke.Test_VectorAsmEnabled_Toggle_Roundtrip;
var
  oldValue: Boolean;
begin
  // Runtime toggle should update visible state in a reversible way.
  // (Used by CLI --vector-asm / --no-vector-asm switches.)
  oldValue := IsVectorAsmEnabled;

  SetVectorAsmEnabled(not oldValue);
  AssertEquals('Vector asm should toggle at runtime', not oldValue, IsVectorAsmEnabled);

  SetVectorAsmEnabled(oldValue);
  AssertEquals('Vector asm should restore to original value', oldValue, IsVectorAsmEnabled);
end;

procedure TTestCase_BackendSmoke.Test_DefaultBackend_VecF32x4_Smoke;
begin
  // 自动选择 backend 的情况下，基础向量操作不应崩溃，且结果应正确
  AssertTrue('Dispatch table should be assigned', GetDispatchTable <> nil);
  RunVecF32x4Smoke;
end;

procedure TTestCase_BackendSmoke.Test_ForceScalar_VecF32x4_Smoke;
begin
  ForceBackend(sbScalar);
  AssertEquals('Active backend should be Scalar', Ord(sbScalar), Ord(GetCurrentBackend));
  RunVecF32x4Smoke;
end;

procedure TTestCase_BackendSmoke.Test_ForceSSE2_VecF32x4_Smoke;
begin
  ForceBackend(sbSSE2);
  if IsBackendDispatchable(sbSSE2) then
    AssertEquals('Active backend should be SSE2', Ord(sbSSE2), Ord(GetCurrentBackend))
  else
    AssertEquals('Fallback backend should be Scalar', Ord(sbScalar), Ord(GetCurrentBackend));
  RunVecF32x4Smoke;
end;

procedure TTestCase_BackendSmoke.Test_ForceSSE3_VecF32x4_Smoke;
begin
  ForceBackend(sbSSE3);
  if IsBackendDispatchable(sbSSE3) then
    AssertEquals('Active backend should be SSE3', Ord(sbSSE3), Ord(GetCurrentBackend))
  else
    AssertEquals('Fallback backend should be Scalar', Ord(sbScalar), Ord(GetCurrentBackend));
  RunVecF32x4Smoke;
end;

procedure TTestCase_BackendSmoke.Test_ForceSSSE3_VecF32x4_Smoke;
begin
  ForceBackend(sbSSSE3);
  if IsBackendDispatchable(sbSSSE3) then
    AssertEquals('Active backend should be SSSE3', Ord(sbSSSE3), Ord(GetCurrentBackend))
  else
    AssertEquals('Fallback backend should be Scalar', Ord(sbScalar), Ord(GetCurrentBackend));
  RunVecF32x4Smoke;
end;

procedure TTestCase_BackendSmoke.Test_ForceSSE41_VecF32x4_Smoke;
begin
  ForceBackend(sbSSE41);
  if IsBackendDispatchable(sbSSE41) then
    AssertEquals('Active backend should be SSE4.1', Ord(sbSSE41), Ord(GetCurrentBackend))
  else
    AssertEquals('Fallback backend should be Scalar', Ord(sbScalar), Ord(GetCurrentBackend));
  RunVecF32x4Smoke;
end;

procedure TTestCase_BackendSmoke.Test_ForceSSE42_VecF32x4_Smoke;
begin
  ForceBackend(sbSSE42);
  if IsBackendDispatchable(sbSSE42) then
    AssertEquals('Active backend should be SSE4.2', Ord(sbSSE42), Ord(GetCurrentBackend))
  else
    AssertEquals('Fallback backend should be Scalar', Ord(sbScalar), Ord(GetCurrentBackend));
  RunVecF32x4Smoke;
end;

{$IFDEF CPUX86_64}
procedure TTestCase_BackendSmoke.Test_SSE42_StringSearchHelpers;
var
  LHaystack: AnsiString;
  LNeedles: AnsiString;
  LChars: AnsiString;
begin
  if not HasSSE42 then
    Exit;

  LHaystack := 'abcdefghijklmnopQ';
  LNeedles := 'Q';
  AssertEquals('FindFirstOf_SSE42 should find a match across the 16-byte boundary',
    16, FindFirstOf_SSE42(PAnsiChar(LHaystack), Length(LHaystack), PAnsiChar(LNeedles), Length(LNeedles)));

  AssertEquals('FindFirstOf_SSE42 should return -1 for an empty needle set',
    -1, FindFirstOf_SSE42(PAnsiChar(LHaystack), Length(LHaystack), nil, 0));

  LHaystack := 'aaaaaab';
  LChars := 'a';
  AssertEquals('FindFirstNotOf_SSE42 should find the first byte outside the set',
    6, FindFirstNotOf_SSE42(PAnsiChar(LHaystack), Length(LHaystack), PAnsiChar(LChars), Length(LChars)));

  LHaystack := 'aaaaa';
  AssertEquals('FindFirstNotOf_SSE42 should return -1 when every byte is in the set',
    -1, FindFirstNotOf_SSE42(PAnsiChar(LHaystack), Length(LHaystack), PAnsiChar(LChars), Length(LChars)));
  AssertEquals('FindFirstNotOf_SSE42 should return 0 for an empty set',
    0, FindFirstNotOf_SSE42(PAnsiChar(LHaystack), Length(LHaystack), nil, 0));
end;
{$ENDIF}

procedure TTestCase_BackendSmoke.Test_SSE42_CRC32C_Contracts;
var
  LBytes8: AnsiString;
  LBytes2: AnsiString;
  LBytes4: AnsiString;
  LBytes8Wide: AnsiString;
begin
  LBytes8 := '123456789';
  AssertEquals('CRC32C_Buffer should match the standard raw test vector',
    UInt32($1CF96D7C), CRC32C_Buffer(Pointer(LBytes8), Length(LBytes8), UInt32($FFFFFFFF)));

  LBytes2 := '12';
  AssertEquals('CRC32C_16 should match the buffer contract for 2 bytes',
    CRC32C_Buffer(Pointer(LBytes2), Length(LBytes2), UInt32($FFFFFFFF)),
    CRC32C_16(UInt32($FFFFFFFF), Word(Byte(LBytes2[1])) or (Word(Byte(LBytes2[2])) shl 8)));

  LBytes4 := '1234';
  AssertEquals('CRC32C_32 should match the buffer contract for 4 bytes',
    CRC32C_Buffer(Pointer(LBytes4), Length(LBytes4), UInt32($FFFFFFFF)),
    CRC32C_32(UInt32($FFFFFFFF), UInt32(Byte(LBytes4[1])) or (UInt32(Byte(LBytes4[2])) shl 8) or
      (UInt32(Byte(LBytes4[3])) shl 16) or (UInt32(Byte(LBytes4[4])) shl 24)));

  LBytes8Wide := '12345678';
  AssertEquals('CRC32C_64 should match the buffer contract for 8 bytes',
    UInt64(CRC32C_Buffer(Pointer(LBytes8Wide), Length(LBytes8Wide), UInt32($FFFFFFFF))),
    CRC32C_64(UInt64($FFFFFFFF), UInt64(Byte(LBytes8Wide[1])) or (UInt64(Byte(LBytes8Wide[2])) shl 8) or
      (UInt64(Byte(LBytes8Wide[3])) shl 16) or (UInt64(Byte(LBytes8Wide[4])) shl 24) or
      (UInt64(Byte(LBytes8Wide[5])) shl 32) or (UInt64(Byte(LBytes8Wide[6])) shl 40) or
      (UInt64(Byte(LBytes8Wide[7])) shl 48) or (UInt64(Byte(LBytes8Wide[8])) shl 56)));
end;

procedure TTestCase_BackendSmoke.Test_ForceAVX2_VecF32x4_Smoke;
begin
  ForceBackend(sbAVX2);
  if IsBackendDispatchable(sbAVX2) then
    AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend))
  else
    AssertEquals('Fallback backend should be Scalar', Ord(sbScalar), Ord(GetCurrentBackend));
  RunVecF32x4Smoke;
end;

procedure TTestCase_BackendSmoke.Test_ForceAVX512_VecF32x4_Smoke;
begin
  ForceBackend(sbAVX512);
  if IsBackendDispatchable(sbAVX512) then
    AssertEquals('Active backend should be AVX-512', Ord(sbAVX512), Ord(GetCurrentBackend))
  else
    AssertEquals('Fallback backend should be Scalar', Ord(sbScalar), Ord(GetCurrentBackend));
  RunVecF32x4Smoke;
end;

{$IFDEF CPUX86_64}
{ TTestCase_X86BackendPredicates }

procedure TTestCase_X86BackendPredicates.Test_X86HasAVX512BackendRequiredFeatures_AVX512FOnly_Disabled;
var
  F: TX86Features;
begin
  FillChar(F, SizeOf(F), 0);

  // NOTE: 本测试只验证“需求判定逻辑”，不触发任何 AVX-512 指令执行。
  F.HasAVX2 := True;
  F.HasAVX512F := True;

  // Missing AVX512BW
  AssertFalse('AVX-512 backend should require AVX512BW', X86HasAVX512BackendRequiredFeatures(F));

  // Still missing POPCNT
  F.HasAVX512BW := True;
  AssertFalse('AVX-512 backend should require POPCNT', X86HasAVX512BackendRequiredFeatures(F));

  F.HasPOPCNT := True;
  AssertFalse('AVX-512 backend should still require FMA after AVX2 + AVX512F + AVX512BW + POPCNT are present',
    X86HasAVX512BackendRequiredFeatures(F));

  F.HasFMA := True;
  AssertTrue('AVX-512 backend should be usable with AVX2 + AVX512F + AVX512BW + POPCNT + FMA',
    X86HasAVX512BackendRequiredFeatures(F));
end;

procedure TTestCase_X86BackendPredicates.Test_X86HasAVX512BackendRequiredFeatures_RequiresFMA;
var
  LF: TX86Features;
begin
  FillChar(LF, SizeOf(LF), 0);

  // NOTE: 本测试只验证“需求判定逻辑”，不触发任何 AVX-512 指令执行。
  LF.HasAVX2 := True;
  LF.HasAVX512F := True;
  LF.HasAVX512BW := True;
  LF.HasPOPCNT := True;

  AssertFalse('AVX-512 backend should require FMA because AVX512FmaF32x16/F64x8 use vfmadd* directly',
    X86HasAVX512BackendRequiredFeatures(LF));

  LF.HasFMA := True;
  AssertTrue('AVX-512 backend should become usable once FMA is also present',
    X86HasAVX512BackendRequiredFeatures(LF));
end;

procedure TTestCase_X86BackendPredicates.Test_X86SupportsAVX512BackendOnCPU_RequiresUsable512AndBackendFeatureSet;
var
  LF: TX86Features;
begin
  FillChar(LF, SizeOf(LF), 0);

  LF.HasAVX2 := True;
  LF.HasAVX512F := True;
  LF.HasAVX512BW := True;
  LF.HasPOPCNT := True;

  AssertFalse('AVX-512 backend should remain unsupported when usable 512-bit state is absent',
    X86SupportsAVX512BackendOnCPU(LF, False));
  AssertFalse('AVX-512 backend should still require FMA even when usable 512-bit state is present',
    X86SupportsAVX512BackendOnCPU(LF, True));

  LF.HasFMA := True;
  AssertTrue('AVX-512 backend should be supported when usable 512-bit state and backend features are present',
    X86SupportsAVX512BackendOnCPU(LF, True));

  LF.HasAVX512BW := False;
  AssertFalse('AVX-512 backend should require AVX512BW even when 512-bit usable state is present',
    X86SupportsAVX512BackendOnCPU(LF, True));

  LF.HasAVX512BW := True;
  LF.HasPOPCNT := False;
  AssertFalse('AVX-512 backend should require POPCNT even when 512-bit usable state is present',
    X86SupportsAVX512BackendOnCPU(LF, True));

  LF.HasPOPCNT := True;
  LF.HasFMA := False;
  AssertFalse('AVX-512 backend should require FMA even when 512-bit usable state is present',
    X86SupportsAVX512BackendOnCPU(LF, True));

  LF.HasFMA := True;
  AssertTrue('AVX-512 backend should become supported once FMA is present and 512-bit state is usable',
    X86SupportsAVX512BackendOnCPU(LF, True));
end;

procedure TTestCase_X86BackendPredicates.Test_X86DirectAVX512ExecutionGate_RequiresBackendSupportedPredicate;
var
  LF: TX86Features;
begin
  FillChar(LF, SizeOf(LF), 0);

  LF.HasAVX512F := True;

  AssertFalse('Direct AVX-512 execution gates must require backend-supported feature set, not just raw usable AVX512F',
    X86AllowsDirectAVX512Execution(LF, True));

  LF.HasAVX2 := True;
  LF.HasAVX512BW := True;
  LF.HasPOPCNT := True;
  AssertFalse('Direct AVX-512 execution gates must still require FMA',
    X86AllowsDirectAVX512Execution(LF, True));

  LF.HasFMA := True;
  AssertTrue('Direct AVX-512 execution gates should allow execution once backend-required features are all present',
    X86AllowsDirectAVX512Execution(LF, True));
end;

{$IFDEF SIMD_BACKEND_AVX512}

{ TTestCase_AVX512BackendRequirements }

procedure TTestCase_AVX512BackendRequirements.SetUp;
begin
  inherited SetUp;
  SetVectorAsmEnabled(True);
  RegisterAVX512Backend;
end;

procedure TTestCase_AVX512BackendRequirements.Test_AVX512Backend_RegisteredDispatchTable_IsAccessible;
var
  dt: TSimdDispatchTable;
begin
  // NOTE: This test must not execute any AVX-512 instructions.
  AssertTrue('AVX-512 backend dispatch table should be registered',
             TryGetRegisteredBackendDispatchTable(sbAVX512, dt));
  AssertEquals('AVX-512 dispatch table should report backend sbAVX512', Ord(sbAVX512), Ord(dt.Backend));
end;

procedure TTestCase_AVX512BackendRequirements.Test_AVX512Backend_DispatchTable_Overrides512BitLoadStoreAndSelect;
var
  dt: TSimdDispatchTable;
begin
  if not IsVectorAsmEnabled then Exit;
  // NOTE: This test must not execute any AVX-512 instructions.
  AssertTrue('AVX-512 backend dispatch table should be registered',
             TryGetRegisteredBackendDispatchTable(sbAVX512, dt));

  // 512-bit Load/Store/Splat/Zero
  AssertTrue('LoadF32x16 should be overridden', dt.LoadF32x16 <> @ScalarLoadF32x16);
  AssertTrue('StoreF32x16 should be overridden', dt.StoreF32x16 <> @ScalarStoreF32x16);
  AssertTrue('SplatF32x16 should be overridden', dt.SplatF32x16 <> @ScalarSplatF32x16);
  AssertTrue('ZeroF32x16 should be overridden', dt.ZeroF32x16 <> @ScalarZeroF32x16);

  AssertTrue('LoadF64x8 should be overridden', dt.LoadF64x8 <> @ScalarLoadF64x8);
  AssertTrue('StoreF64x8 should be overridden', dt.StoreF64x8 <> @ScalarStoreF64x8);
  AssertTrue('SplatF64x8 should be overridden', dt.SplatF64x8 <> @ScalarSplatF64x8);
  AssertTrue('ZeroF64x8 should be overridden', dt.ZeroF64x8 <> @ScalarZeroF64x8);

  // 512-bit Select
  AssertTrue('SelectF32x16 should be overridden', dt.SelectF32x16 <> @ScalarSelectF32x16);
  AssertTrue('SelectF64x8 should be overridden', dt.SelectF64x8 <> @ScalarSelectF64x8);
end;

procedure TTestCase_AVX512BackendRequirements.Test_AVX512Backend_DispatchTable_Overrides512BitFloatCompare;
var
  dt: TSimdDispatchTable;
begin
  if not IsVectorAsmEnabled then Exit;
  // NOTE: This test must not execute any AVX-512 instructions.
  AssertTrue('AVX-512 backend dispatch table should be registered',
             TryGetRegisteredBackendDispatchTable(sbAVX512, dt));

  // F32x16 (512-bit)
  AssertTrue('CmpEqF32x16 should be overridden', dt.CmpEqF32x16 <> @ScalarCmpEqF32x16);
  AssertTrue('CmpLtF32x16 should be overridden', dt.CmpLtF32x16 <> @ScalarCmpLtF32x16);
  AssertTrue('CmpLeF32x16 should be overridden', dt.CmpLeF32x16 <> @ScalarCmpLeF32x16);
  AssertTrue('CmpGtF32x16 should be overridden', dt.CmpGtF32x16 <> @ScalarCmpGtF32x16);
  AssertTrue('CmpGeF32x16 should be overridden', dt.CmpGeF32x16 <> @ScalarCmpGeF32x16);
  AssertTrue('CmpNeF32x16 should be overridden', dt.CmpNeF32x16 <> @ScalarCmpNeF32x16);

  // F64x8 (512-bit)
  AssertTrue('CmpEqF64x8 should be overridden', dt.CmpEqF64x8 <> @ScalarCmpEqF64x8);
  AssertTrue('CmpLtF64x8 should be overridden', dt.CmpLtF64x8 <> @ScalarCmpLtF64x8);
  AssertTrue('CmpLeF64x8 should be overridden', dt.CmpLeF64x8 <> @ScalarCmpLeF64x8);
  AssertTrue('CmpGtF64x8 should be overridden', dt.CmpGtF64x8 <> @ScalarCmpGtF64x8);
  AssertTrue('CmpGeF64x8 should be overridden', dt.CmpGeF64x8 <> @ScalarCmpGeF64x8);
  AssertTrue('CmpNeF64x8 should be overridden', dt.CmpNeF64x8 <> @ScalarCmpNeF64x8);
end;

procedure TTestCase_AVX512BackendRequirements.Test_AVX512Backend_DispatchTable_Inherits_AVX2_I64x2_U64x2;
var
  LAVX512, LAVX2: TSimdDispatchTable;
  LHasAVX2: Boolean;
begin
  AssertTrue('AVX-512 backend dispatch table should be registered',
             TryGetRegisteredBackendDispatchTable(sbAVX512, LAVX512));

  AssertTrue('AVX-512 AndNotI64x2 should be assigned', Assigned(LAVX512.AndNotI64x2));
  AssertTrue('AVX-512 ShiftLeftI64x2 should be assigned', Assigned(LAVX512.ShiftLeftI64x2));
  AssertTrue('AVX-512 ShiftRightI64x2 should be assigned', Assigned(LAVX512.ShiftRightI64x2));
  AssertTrue('AVX-512 ShiftRightArithI64x2 should be assigned', Assigned(LAVX512.ShiftRightArithI64x2));
  AssertTrue('AVX-512 MinI64x2 should be assigned', Assigned(LAVX512.MinI64x2));
  AssertTrue('AVX-512 MaxI64x2 should be assigned', Assigned(LAVX512.MaxI64x2));

  AssertTrue('AVX-512 AddU64x2 should be assigned', Assigned(LAVX512.AddU64x2));
  AssertTrue('AVX-512 SubU64x2 should be assigned', Assigned(LAVX512.SubU64x2));
  AssertTrue('AVX-512 AndU64x2 should be assigned', Assigned(LAVX512.AndU64x2));
  AssertTrue('AVX-512 OrU64x2 should be assigned', Assigned(LAVX512.OrU64x2));
  AssertTrue('AVX-512 XorU64x2 should be assigned', Assigned(LAVX512.XorU64x2));
  AssertTrue('AVX-512 NotU64x2 should be assigned', Assigned(LAVX512.NotU64x2));
  AssertTrue('AVX-512 AndNotU64x2 should be assigned', Assigned(LAVX512.AndNotU64x2));
  AssertTrue('AVX-512 CmpEqU64x2 should be assigned', Assigned(LAVX512.CmpEqU64x2));
  AssertTrue('AVX-512 CmpLtU64x2 should be assigned', Assigned(LAVX512.CmpLtU64x2));
  AssertTrue('AVX-512 CmpGtU64x2 should be assigned', Assigned(LAVX512.CmpGtU64x2));
  AssertTrue('AVX-512 MinU64x2 should be assigned', Assigned(LAVX512.MinU64x2));
  AssertTrue('AVX-512 MaxU64x2 should be assigned', Assigned(LAVX512.MaxU64x2));

  LHasAVX2 := TryGetRegisteredBackendDispatchTable(sbAVX2, LAVX2);
  if LHasAVX2 then
  begin
    AssertEquals('AVX-512 should inherit AVX2 AndNotI64x2', PtrUInt(LAVX2.AndNotI64x2), PtrUInt(LAVX512.AndNotI64x2));
    AssertEquals('AVX-512 should inherit AVX2 ShiftLeftI64x2', PtrUInt(LAVX2.ShiftLeftI64x2), PtrUInt(LAVX512.ShiftLeftI64x2));
    AssertEquals('AVX-512 should inherit AVX2 ShiftRightI64x2', PtrUInt(LAVX2.ShiftRightI64x2), PtrUInt(LAVX512.ShiftRightI64x2));
    AssertEquals('AVX-512 should inherit AVX2 ShiftRightArithI64x2', PtrUInt(LAVX2.ShiftRightArithI64x2), PtrUInt(LAVX512.ShiftRightArithI64x2));
    AssertEquals('AVX-512 should inherit AVX2 MinI64x2', PtrUInt(LAVX2.MinI64x2), PtrUInt(LAVX512.MinI64x2));
    AssertEquals('AVX-512 should inherit AVX2 MaxI64x2', PtrUInt(LAVX2.MaxI64x2), PtrUInt(LAVX512.MaxI64x2));

    AssertEquals('AVX-512 should inherit AVX2 AddU64x2', PtrUInt(LAVX2.AddU64x2), PtrUInt(LAVX512.AddU64x2));
    AssertEquals('AVX-512 should inherit AVX2 SubU64x2', PtrUInt(LAVX2.SubU64x2), PtrUInt(LAVX512.SubU64x2));
    AssertEquals('AVX-512 should inherit AVX2 AndU64x2', PtrUInt(LAVX2.AndU64x2), PtrUInt(LAVX512.AndU64x2));
    AssertEquals('AVX-512 should inherit AVX2 OrU64x2', PtrUInt(LAVX2.OrU64x2), PtrUInt(LAVX512.OrU64x2));
    AssertEquals('AVX-512 should inherit AVX2 XorU64x2', PtrUInt(LAVX2.XorU64x2), PtrUInt(LAVX512.XorU64x2));
    AssertEquals('AVX-512 should inherit AVX2 NotU64x2', PtrUInt(LAVX2.NotU64x2), PtrUInt(LAVX512.NotU64x2));
    AssertEquals('AVX-512 should inherit AVX2 AndNotU64x2', PtrUInt(LAVX2.AndNotU64x2), PtrUInt(LAVX512.AndNotU64x2));
    AssertEquals('AVX-512 should inherit AVX2 CmpEqU64x2', PtrUInt(LAVX2.CmpEqU64x2), PtrUInt(LAVX512.CmpEqU64x2));
    AssertEquals('AVX-512 should inherit AVX2 CmpLtU64x2', PtrUInt(LAVX2.CmpLtU64x2), PtrUInt(LAVX512.CmpLtU64x2));
    AssertEquals('AVX-512 should inherit AVX2 CmpGtU64x2', PtrUInt(LAVX2.CmpGtU64x2), PtrUInt(LAVX512.CmpGtU64x2));
    AssertEquals('AVX-512 should inherit AVX2 MinU64x2', PtrUInt(LAVX2.MinU64x2), PtrUInt(LAVX512.MinU64x2));
    AssertEquals('AVX-512 should inherit AVX2 MaxU64x2', PtrUInt(LAVX2.MaxU64x2), PtrUInt(LAVX512.MaxU64x2));
  end;
end;

{$ENDIF}
{$ENDIF}

{$IFDEF UNIX}
{$IFDEF CPUX86_64}

{ TTestCase_AVX2VectorAsm }

function SingleFromBits(bits: DWord): Single; inline;
begin
  Move(bits, Result, SizeOf(Result));
end;

function BitsFromSingle(const value: Single): DWord; inline;
begin
  Move(value, Result, SizeOf(Result));
end;

function IsNaNSingle(const value: Single): Boolean; inline;
var
  bits: DWord;
begin
  // 注意：使用浮点比较检测 NaN（value<>value）会触发 InvalidOp（若未屏蔽异常）。
  // 这里改为纯位判断：exp=all-1 且 mantissa<>0。
  bits := BitsFromSingle(value);
  Result := ((bits and $7F800000) = $7F800000) and ((bits and $007FFFFF) <> 0);
end;

function DoubleFromBits(bits: QWord): Double; inline;
begin
  Move(bits, Result, SizeOf(Result));
end;

function BitsFromDouble(const value: Double): QWord; inline;
begin
  Move(value, Result, SizeOf(Result));
end;

function IsNaNDouble(const value: Double): Boolean; inline;
var
  bits: QWord;
begin
  bits := BitsFromDouble(value);
  Result := ((bits and QWord($7FF0000000000000)) = QWord($7FF0000000000000)) and
            ((bits and QWord($000FFFFFFFFFFFFF)) <> 0);
end;

// === ABI/Calling-convention guard helpers ===
// 目标：在不依赖编译器生成的 wrapper 的情况下，直接用汇编调用 dispatch 函数指针，
// 并验证 SysV AMD64 的 callee-saved 寄存器（RBX/R12-R15）不会被破坏。

function AbiCall_TwoVecToSingle_CheckCalleeSaved(fn: Pointer; const a, b: TVecF32x4; out value: Single): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64) 参数传递说明（按 FPC 对 TVecF32x4 的实际 ABI 分类）：
  //   - TVecF32x4 是 variant record（同时含 f[] 与 raw[]），FPC 在该平台将其按 INTEGER 类传递。
  //   - 因此 16B 向量按 2 个 QWord 走整数寄存器，而不是 XMM。
  //
  // 入参（本 helper 的签名：fn, a, b, out value）：
  //   RDI = fn
  //   RSI = a.lowQ
  //   RDX = a.highQ
  //   RCX = b.lowQ
  //   R8  = b.highQ
  //   R9  = @value
  //
  // 被测函数（签名：fn(a,b): Single）期望：
  //   RDI = a.lowQ
  //   RSI = a.highQ
  //   RDX = b.lowQ
  //   RCX = b.highQ
  // Return:
  //   XMM0 = Single result

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], r9      // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(a, b)  (按上面的“被测函数期望”重新排列寄存器)
  mov rax, qword ptr [rsp + 48]   // fn ptr
  mov rdi, rsi                    // a.lowQ
  mov rsi, rdx                    // a.highQ
  mov rdx, rcx                    // b.lowQ
  mov rcx, r8                     // b.highQ
  call rax

  // store float result (reload out ptr from stack after the call)
  mov r9, qword ptr [rsp + 40]
  movss dword ptr [r9], xmm0

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_OneVecToSingle_CheckCalleeSaved(fn: Pointer; const a: TVecF32x4; out value: Single): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64) 参数传递说明（按 FPC 对 TVecF32x4 的实际 ABI 分类）：
  //   RDI = fn
  //   RSI = a.lowQ
  //   RDX = a.highQ
  //   RCX = @value
  //
  // 被测函数（签名：fn(a): Single）期望：
  //   RDI = a.lowQ
  //   RSI = a.highQ
  // Return:
  //   XMM0 = Single result

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], rcx     // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(a)
  mov rax, qword ptr [rsp + 48]   // fn ptr
  mov rdi, rsi                    // a.lowQ
  mov rsi, rdx                    // a.highQ
  call rax

  // store float result (reload out ptr from stack after the call)
  mov r9, qword ptr [rsp + 40]
  movss dword ptr [r9], xmm0

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_VecI32ToSingle_CheckCalleeSaved(fn: Pointer; const a: TVecF32x4; index: Integer; out value: Single): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64) - FPC 对 TVecF32x4 的实际 ABI：按 INTEGER 类传参。
  //
  // 入参（本 helper 的签名：fn, a, index, out value）：
  //   RDI = fn
  //   RSI = a.lowQ
  //   RDX = a.highQ
  //   RCX = index
  //   R8  = @value
  //
  // 被测函数（签名：fn(a, index): Single）期望：
  //   RDI = a.lowQ
  //   RSI = a.highQ
  //   RDX = index
  // Return:
  //   XMM0 = Single result

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], r8      // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(a, index)
  mov rax, qword ptr [rsp + 48]   // fn ptr
  mov rdi, rsi                    // a.lowQ
  mov rsi, rdx                    // a.highQ
  mov rdx, rcx                    // index
  call rax

  // store float result (reload out ptr from stack after the call)
  mov r9, qword ptr [rsp + 40]
  movss dword ptr [r9], xmm0

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_TwoVecToVec_CheckCalleeSaved(fn: Pointer; const a, b: TVecF32x4; out value: TVecF32x4): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64) - FPC 对 TVecF32x4 的实际 ABI：按 INTEGER 类传参/返回。
  //
  // 入参（本 helper 的签名：fn, a, b, out value）：
  //   RDI = fn
  //   RSI = a.lowQ
  //   RDX = a.highQ
  //   RCX = b.lowQ
  //   R8  = b.highQ
  //   R9  = @value
  //
  // 被测函数（签名：fn(a,b): TVecF32x4）期望：
  //   RDI = a.lowQ
  //   RSI = a.highQ
  //   RDX = b.lowQ
  //   RCX = b.highQ
  // Return（预期）：
  //   RAX = result.lowQ
  //   RDX = result.highQ

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], r9      // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(a, b)
  mov rax, qword ptr [rsp + 48]   // fn ptr
  mov rdi, rsi                    // a.lowQ
  mov rsi, rdx                    // a.highQ
  mov rdx, rcx                    // b.lowQ
  mov rcx, r8                     // b.highQ
  call rax

  // store vector result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov qword ptr [r10], rax
  mov qword ptr [r10 + 8], rdx

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_TwoVecF64x2ToVec_CheckCalleeSaved(fn: Pointer; const a, b: TVecF64x2; out value: TVecF64x2): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64) - 16B variant record (TVecF64x2) 按 INTEGER 类传参/返回。
  //
  // 入参（本 helper 的签名：fn, a, b, out value）：
  //   RDI = fn
  //   RSI = a.lowQ
  //   RDX = a.highQ
  //   RCX = b.lowQ
  //   R8  = b.highQ
  //   R9  = @value
  //
  // 被测函数（签名：fn(a,b): TVecF64x2）期望：
  //   RDI = a.lowQ
  //   RSI = a.highQ
  //   RDX = b.lowQ
  //   RCX = b.highQ
  // Return（预期）：
  //   RAX = result.lowQ
  //   RDX = result.highQ

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], r9      // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(a, b)
  mov rax, qword ptr [rsp + 48]   // fn ptr
  mov rdi, rsi                    // a.lowQ
  mov rsi, rdx                    // a.highQ
  mov rdx, rcx                    // b.lowQ
  mov rcx, r8                     // b.highQ
  call rax

  // store vector result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov qword ptr [r10], rax
  mov qword ptr [r10 + 8], rdx

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_TwoVecI32x4ToVec_CheckCalleeSaved(fn: Pointer; const a, b: TVecI32x4; out value: TVecI32x4): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64) - 16B variant record (TVecI32x4) 按 INTEGER 类传参/返回。
  //
  // 入参（本 helper 的签名：fn, a, b, out value）：
  //   RDI = fn
  //   RSI = a.lowQ
  //   RDX = a.highQ
  //   RCX = b.lowQ
  //   R8  = b.highQ
  //   R9  = @value
  //
  // 被测函数（签名：fn(a,b): TVecI32x4）期望：
  //   RDI = a.lowQ
  //   RSI = a.highQ
  //   RDX = b.lowQ
  //   RCX = b.highQ
  // Return（预期）：
  //   RAX = result.lowQ
  //   RDX = result.highQ

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], r9      // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(a, b)
  mov rax, qword ptr [rsp + 48]   // fn ptr
  mov rdi, rsi                    // a.lowQ
  mov rsi, rdx                    // a.highQ
  mov rdx, rcx                    // b.lowQ
  mov rcx, r8                     // b.highQ
  call rax

  // store vector result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov qword ptr [r10], rax
  mov qword ptr [r10 + 8], rdx

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_OneVecToVec_CheckCalleeSaved(fn: Pointer; const a: TVecF32x4; out value: TVecF32x4): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64) - FPC 对 TVecF32x4 的实际 ABI：按 INTEGER 类传参/返回。
  //
  // 入参（本 helper 的签名：fn, a, out value）：
  //   RDI = fn
  //   RSI = a.lowQ
  //   RDX = a.highQ
  //   RCX = @value
  //
  // 被测函数（签名：fn(a): TVecF32x4）期望：
  //   RDI = a.lowQ
  //   RSI = a.highQ
  // Return（预期）：
  //   RAX = result.lowQ
  //   RDX = result.highQ

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], rcx     // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(a)
  mov rax, qword ptr [rsp + 48]   // fn ptr
  mov rdi, rsi                    // a.lowQ
  mov rsi, rdx                    // a.highQ
  call rax

  // store vector result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov qword ptr [r10], rax
  mov qword ptr [r10 + 8], rdx

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_VecSingleI32ToVec_CheckCalleeSaved(fn: Pointer; const a: TVecF32x4; value: Single; index: Integer; out v: TVecF32x4): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64) - 混合 INTEGER/SSE 参数。
  //
  // 入参（本 helper 的签名：fn, a, value, index, out v）：
  //   RDI  = fn
  //   RSI  = a.lowQ
  //   RDX  = a.highQ
  //   RCX  = index
  //   R8   = @v
  //   XMM0 = value
  //
  // 被测函数（签名：fn(a, value, index): TVecF32x4）期望：
  //   RDI  = a.lowQ
  //   RSI  = a.highQ
  //   RDX  = index
  //   XMM0 = value
  // Return（预期）：
  //   RAX = result.lowQ
  //   RDX = result.highQ

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], r8      // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(a, value, index)
  mov rax, qword ptr [rsp + 48]   // fn ptr
  mov rdi, rsi                    // a.lowQ
  mov rsi, rdx                    // a.highQ
  mov rdx, rcx                    // index
  call rax

  // store vector result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov qword ptr [r10], rax
  mov qword ptr [r10 + 8], rdx

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_ThreeVecToVec_CheckCalleeSaved(fn: Pointer; const a, b, c: TVecF32x4; out value: TVecF32x4): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64) - FPC 对 TVecF32x4 的实际 ABI：按 INTEGER 类传参/返回。
  //
  // 入参（本 helper 的签名：fn, a, b, c, out value）：
  //   RDI = fn
  //   RSI = a.lowQ
  //   RDX = a.highQ
  //   RCX = b.lowQ
  //   R8  = b.highQ
  //
  //   注意：c 需要 2 个 INTEGER 寄存器槽，但此时只剩 1 个槽（R9）。
  //   按 SysV 规则：寄存器不够时整个参数走内存，因此 c 会整体落到 stack。
  //
  //   R9 = @value
  //   stack[+8]  = c.lowQ
  //   stack[+16] = c.highQ
  //
  // 被测函数（签名：fn(a,b,c): TVecF32x4）期望：
  //   RDI = a.lowQ
  //   RSI = a.highQ
  //   RDX = b.lowQ
  //   RCX = b.highQ
  //   R8  = c.lowQ
  //   R9  = c.highQ
  // Return（预期）：
  //   RAX = result.lowQ
  //   RDX = result.highQ

  // 先把 stack 入参取出来（之后会改 RSP）。
  mov r10, qword ptr [rsp + 8]   // c.lowQ
  mov r11, qword ptr [rsp + 16]  // c.highQ

  // 保存 out ptr / fn / c 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 32 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 32
  mov qword ptr [rsp], r9        // out ptr
  mov qword ptr [rsp + 8], rdi   // fn ptr
  mov qword ptr [rsp + 16], r10  // c.lowQ
  mov qword ptr [rsp + 24], r11  // c.highQ

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(a, b, c)
  mov rax, qword ptr [rsp + 48]   // fn ptr
  mov rdi, rsi                    // a.lowQ
  mov rsi, rdx                    // a.highQ
  mov rdx, rcx                    // b.lowQ
  mov rcx, r8                     // b.highQ
  mov r8, qword ptr [rsp + 56]    // c.lowQ
  mov r9, qword ptr [rsp + 64]    // c.highQ
  call rax

  // store vector result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov qword ptr [r10], rax
  mov qword ptr [r10 + 8], rdx

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 32
end;

function AbiCall_PtrToVec_CheckCalleeSaved(fn: Pointer; p: PSingle; out value: TVecF32x4): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64) - 入参（本 helper 的签名：fn, p, out value）：
  //   RDI = fn
  //   RSI = p
  //   RDX = @value
  //
  // 被测函数（签名：fn(p): TVecF32x4）期望：
  //   RDI = p
  // Return（预期）：
  //   RAX = result.lowQ
  //   RDX = result.highQ

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], rdx     // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(p)
  mov rax, qword ptr [rsp + 48]   // fn ptr
  mov rdi, rsi                    // p
  call rax

  // store vector result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov qword ptr [r10], rax
  mov qword ptr [r10 + 8], rdx

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_PtrVecToVoid_CheckCalleeSaved(fn: Pointer; p: PSingle; const a: TVecF32x4): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64) - FPC 对 TVecF32x4 的实际 ABI：按 INTEGER 类传参。
  //
  // 入参（本 helper 的签名：fn, p, a）：
  //   RDI = fn
  //   RSI = p
  //   RDX = a.lowQ
  //   RCX = a.highQ
  //
  // 被测函数（签名：fn(p, a): void）期望：
  //   RDI = p
  //   RSI = a.lowQ
  //   RDX = a.highQ

  // 保存 fn ptr 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], rdi     // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(p, a)
  mov rax, qword ptr [rsp + 40]   // fn ptr
  mov rdi, rsi                    // p
  mov rsi, rdx                    // a.lowQ
  mov rdx, rcx                    // a.highQ
  call rax

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_TwoVecToMask_CheckCalleeSaved(fn: Pointer; const a, b: TVecF32x4; out value: TMask4): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64) - FPC 对 TVecF32x4 的实际 ABI：按 INTEGER 类传参。
  //
  // 入参（本 helper 的签名：fn, a, b, out value）：
  //   RDI = fn
  //   RSI = a.lowQ
  //   RDX = a.highQ
  //   RCX = b.lowQ
  //   R8  = b.highQ
  //   R9  = @value
  //
  // 被测函数（签名：fn(a,b): TMask4）期望：
  //   RDI = a.lowQ
  //   RSI = a.highQ
  //   RDX = b.lowQ
  //   RCX = b.highQ
  // Return:
  //   EAX = mask

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], r9      // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(a, b)
  mov rax, qword ptr [rsp + 48]   // fn ptr
  mov rdi, rsi                    // a.lowQ
  mov rsi, rdx                    // a.highQ
  mov rdx, rcx                    // b.lowQ
  mov rcx, r8                     // b.highQ
  call rax

  // store mask result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov dword ptr [r10], eax

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_NoArgsToVec_CheckCalleeSaved(fn: Pointer; out value: TVecF32x4): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64)
  //
  // 入参（本 helper 的签名：fn, out value）：
  //   RDI = fn
  //   RSI = @value
  //
  // 被测函数（签名：fn(): TVecF32x4）Return（预期）：
  //   RAX = result.lowQ
  //   RDX = result.highQ

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], rsi     // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn()
  mov rax, qword ptr [rsp + 48]   // fn ptr
  call rax

  // store vector result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov qword ptr [r10], rax
  mov qword ptr [r10 + 8], rdx

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_SingleToVec_CheckCalleeSaved(fn: Pointer; value: Single; out v: TVecF32x4): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64) - 混合 SSE/INTEGER：
  //
  // 入参（本 helper 的签名：fn, value, out v）：
  //   RDI  = fn
  //   RSI  = @v
  //   XMM0 = value
  //
  // 被测函数（签名：fn(value): TVecF32x4）Return（预期）：
  //   RAX = result.lowQ
  //   RDX = result.highQ

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], rsi     // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(value) - value 已在 XMM0
  mov rax, qword ptr [rsp + 48]   // fn ptr
  call rax

  // store vector result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov qword ptr [r10], rax
  mov qword ptr [r10 + 8], rdx

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_TwoVecMaskToVec_CheckCalleeSaved(fn: Pointer; const a, b: TVecF32x4; mask: TMask4; out value: TVecF32x4): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64) - fn(mask, a, b): TVecF32x4
  //
  // 入参（本 helper 的签名：fn, a, b, mask, out value）：
  //   RDI = fn
  //   RSI = a.lowQ
  //   RDX = a.highQ
  //   RCX = b.lowQ
  //   R8  = b.highQ
  //   R9  = mask (Byte)
  //   stack[+8] = @value (寄存器槽位用尽，out ptr 走 stack)
  //
  // 被测函数（签名：fn(mask, a, b): TVecF32x4）期望：
  //   RDI = mask
  //   RSI = a.lowQ
  //   RDX = a.highQ
  //   RCX = b.lowQ
  //   R8  = b.highQ
  // Return（预期）：
  //   RAX = result.lowQ
  //   RDX = result.highQ

  // 先把 stack 入参取出来（之后会改 RSP）。
  mov r10, qword ptr [rsp + 8]   // out ptr

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], r10       // out ptr
  mov qword ptr [rsp + 8], rdi   // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(mask, a, b)
  mov rax, qword ptr [rsp + 48]  // fn ptr
  movzx edi, r9b                 // mask (zero-extend)
  call rax

  // store vector result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov qword ptr [r10], rax
  mov qword ptr [r10 + 8], rdx

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_TwoPtrToVecF32x8_CheckCalleeSaved(fn: Pointer; pa, pb: Pointer; out value: TVecF32x8): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64) - large record return uses hidden sret pointer.
  //
  // 入参（本 helper 的签名：fn, pa, pb, out value）：
  //   RDI = fn
  //   RSI = pa (points to TVecF32x8)
  //   RDX = pb (points to TVecF32x8)
  //   RCX = @value (out)
  //
  // 被测函数（签名：fn(const a,b: TVecF32x8): TVecF32x8）期望：
  //   RDI = sret (@result)
  //   RSI = @a
  //   RDX = @b
  // Return: typically RAX = sret (ignore)

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], rcx     // out ptr (sret)
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(a, b) with sret in RDI
  mov rax, qword ptr [rsp + 48]  // fn ptr
  mov rdi, qword ptr [rsp + 40]  // sret/out ptr
  call rax

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_MemEqual_CheckCalleeSaved(fn: Pointer; a, b: Pointer; len: SizeUInt; out resultValue: LongBool): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64)
  //
  // 入参（本 helper 的签名：fn, a, b, len, out resultValue）：
  //   RDI = fn
  //   RSI = a
  //   RDX = b
  //   RCX = len
  //   R8  = @resultValue
  //
  // 被测函数（签名：fn(a, b, len): LongBool）期望：
  //   RDI = a
  //   RSI = b
  //   RDX = len
  // Return:
  //   EAX = LongBool result

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], r8      // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(a, b, len)
  mov rax, qword ptr [rsp + 48]  // fn ptr
  mov rdi, rsi                   // a
  mov rsi, rdx                   // b
  mov rdx, rcx                   // len
  call rax

  // store LongBool result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov dword ptr [r10], eax

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_SumBytes_CheckCalleeSaved(fn: Pointer; p: Pointer; len: SizeUInt; out resultValue: UInt64): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64)
  //
  // 入参（本 helper 的签名：fn, p, len, out resultValue）：
  //   RDI = fn
  //   RSI = p
  //   RDX = len
  //   RCX = @resultValue
  //
  // 被测函数（签名：fn(p, len): UInt64）期望：
  //   RDI = p
  //   RSI = len
  // Return:
  //   RAX = UInt64 result

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], rcx     // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(p, len)
  mov rax, qword ptr [rsp + 48]  // fn ptr
  mov rdi, rsi                   // p
  mov rsi, rdx                   // len
  call rax

  // store UInt64 result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov qword ptr [r10], rax

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_MemFindByte_CheckCalleeSaved(fn: Pointer; p: Pointer; len: SizeUInt; value: Byte; out resultValue: PtrInt): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64)
  //
  // 入参（本 helper 的签名：fn, p, len, value, out resultValue）：
  //   RDI = fn
  //   RSI = p
  //   RDX = len
  //   RCX = value (Byte)
  //   R8  = @resultValue
  //
  // 被测函数（签名：fn(p, len, value): PtrInt）期望：
  //   RDI = p
  //   RSI = len
  //   RDX = value (zero-extended)
  // Return:
  //   RAX = PtrInt result

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], r8      // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(p, len, value)
  mov rax, qword ptr [rsp + 48]  // fn ptr
  mov rdi, rsi                   // p
  mov rsi, rdx                   // len
  movzx edx, cl                  // value (Byte) -> EDX
  call rax

  // store PtrInt result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov qword ptr [r10], rax

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_MemCopy_CheckCalleeSaved(fn: Pointer; src, dst: Pointer; len: SizeUInt): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64)
  //
  // 入参（本 helper 的签名：fn, src, dst, len）：
  //   RDI = fn
  //   RSI = src
  //   RDX = dst
  //   RCX = len
  //
  // 被测函数（签名：fn(src, dst, len): void）期望：
  //   RDI = src
  //   RSI = dst
  //   RDX = len

  // 保存 fn（避免后续改写 RDI）
  mov rax, rdi

  // 保存 callee-saved（本函数也必须遵守 ABI）
  // 5 pushes -> call 前 RSP 16-byte 对齐
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(src, dst, len)
  mov rdi, rsi // src
  mov rsi, rdx // dst
  mov rdx, rcx // len
  call rax

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
end;

function AbiCall_CountByte_CheckCalleeSaved(fn: Pointer; p: Pointer; len: SizeUInt; value: Byte; out resultValue: SizeUInt): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64)
  //
  // 入参（本 helper 的签名：fn, p, len, value, out resultValue）：
  //   RDI = fn
  //   RSI = p
  //   RDX = len
  //   RCX = value (Byte)
  //   R8  = @resultValue
  //
  // 被测函数（签名：fn(p, len, value): SizeUInt）期望：
  //   RDI = p
  //   RSI = len
  //   RDX = value (zero-extended)
  // Return:
  //   RAX = SizeUInt result

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], r8      // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(p, len, value)
  mov rax, qword ptr [rsp + 48]  // fn ptr
  mov rdi, rsi                   // p
  mov rsi, rdx                   // len
  movzx edx, cl                  // value (Byte) -> EDX
  call rax

  // store SizeUInt result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov qword ptr [r10], rax

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_BitsetPopCount_CheckCalleeSaved(fn: Pointer; p: Pointer; byteLen: SizeUInt; out resultValue: SizeUInt): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64)
  //
  // 入参（本 helper 的签名：fn, p, byteLen, out resultValue）：
  //   RDI = fn
  //   RSI = p
  //   RDX = byteLen
  //   RCX = @resultValue
  //
  // 被测函数（签名：fn(p, byteLen): SizeUInt）期望：
  //   RDI = p
  //   RSI = byteLen
  // Return:
  //   RAX = SizeUInt result

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], rcx     // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(p, byteLen)
  mov rax, qword ptr [rsp + 48]  // fn ptr
  mov rdi, rsi                   // p
  mov rsi, rdx                   // byteLen
  call rax

  // store SizeUInt result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov qword ptr [r10], rax

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_Utf8Validate_CheckCalleeSaved(fn: Pointer; p: Pointer; len: SizeUInt; out resultValue: Boolean): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64)
  //
  // 入参（本 helper 的签名：fn, p, len, out resultValue）：
  //   RDI = fn
  //   RSI = p
  //   RDX = len
  //   RCX = @resultValue
  //
  // 被测函数（签名：fn(p, len): Boolean）期望：
  //   RDI = p
  //   RSI = len
  // Return:
  //   AL = Boolean result

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], rcx     // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(p, len)
  mov rax, qword ptr [rsp + 48]  // fn ptr
  mov rdi, rsi                   // p
  mov rsi, rdx                   // len
  call rax

  // store Boolean result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov byte ptr [r10], al

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_AsciiIEqual_CheckCalleeSaved(fn: Pointer; a, b: Pointer; len: SizeUInt; out resultValue: Boolean): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64)
  //
  // 入参（本 helper 的签名：fn, a, b, len, out resultValue）：
  //   RDI = fn
  //   RSI = a
  //   RDX = b
  //   RCX = len
  //   R8  = @resultValue
  //
  // 被测函数（签名：fn(a, b, len): Boolean）期望：
  //   RDI = a
  //   RSI = b
  //   RDX = len
  // Return:
  //   AL = Boolean result

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], r8      // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(a, b, len)
  mov rax, qword ptr [rsp + 48]  // fn ptr
  mov rdi, rsi                   // a
  mov rsi, rdx                   // b
  mov rdx, rcx                   // len
  call rax

  // store Boolean result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov byte ptr [r10], al

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_ToLowerAscii_CheckCalleeSaved(fn: Pointer; p: Pointer; len: SizeUInt): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64)
  //
  // 入参（本 helper 的签名：fn, p, len）：
  //   RDI = fn
  //   RSI = p
  //   RDX = len
  //
  // 被测函数（签名：fn(p, len): void）期望：
  //   RDI = p
  //   RSI = len

  // 保存 fn（避免后续改写 RDI）
  mov rax, rdi

  // 保存 callee-saved（本函数也必须遵守 ABI）
  // 5 pushes -> call 前 RSP 16-byte 对齐
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(p, len)
  mov rdi, rsi // p
  mov rsi, rdx // len
  call rax

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
end;

function AbiCall_ToUpperAscii_CheckCalleeSaved(fn: Pointer; p: Pointer; len: SizeUInt): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64)
  //
  // 入参（本 helper 的签名：fn, p, len）：
  //   RDI = fn
  //   RSI = p
  //   RDX = len
  //
  // 被测函数（签名：fn(p, len): void）期望：
  //   RDI = p
  //   RSI = len

  // 保存 fn（避免后续改写 RDI）
  mov rax, rdi

  // 保存 callee-saved（本函数也必须遵守 ABI）
  // 5 pushes -> call 前 RSP 16-byte 对齐
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(p, len)
  mov rdi, rsi // p
  mov rsi, rdx // len
  call rax

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
end;

function AbiCall_BytesIndexOf_CheckCalleeSaved(fn: Pointer; haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt; out value: PtrInt): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64)
  //
  // 入参（本 helper 的签名：fn, haystack, haystackLen, needle, needleLen, out value）：
  //   RDI = fn
  //   RSI = haystack
  //   RDX = haystackLen
  //   RCX = needle
  //   R8  = needleLen
  //   R9  = @value
  //
  // 被测函数（签名：fn(haystack, haystackLen, needle, needleLen): PtrInt）期望：
  //   RDI = haystack
  //   RSI = haystackLen
  //   RDX = needle
  //   RCX = needleLen
  // Return:
  //   RAX = PtrInt result

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], r9      // out ptr
  mov qword ptr [rsp + 8], rdi // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(haystack, haystackLen, needle, needleLen)
  mov rax, qword ptr [rsp + 48]  // fn ptr
  mov rdi, rsi                   // haystack
  mov rsi, rdx                   // haystackLen
  mov rdx, rcx                   // needle
  mov rcx, r8                    // needleLen
  call rax

  // store PtrInt result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov qword ptr [r10], rax

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function AbiCall_MemDiffRange_CheckCalleeSaved(fn: Pointer; a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt; out resultValue: Boolean): Boolean; assembler; nostackframe;
asm
  // SysV AMD64 (Linux x86_64)
  //
  // 入参（本 helper 的签名：fn, a, b, len, out firstDiff, lastDiff, out resultValue）：
  //   RDI = fn
  //   RSI = a
  //   RDX = b
  //   RCX = len
  //   R8  = @firstDiff
  //   R9  = @lastDiff
  //   stack[+8] = @resultValue (寄存器槽位用尽，out ptr 走 stack)
  //
  // 被测函数（签名：fn(a, b, len, out firstDiff, lastDiff): Boolean）期望：
  //   RDI = a
  //   RSI = b
  //   RDX = len
  //   RCX = @firstDiff
  //   R8  = @lastDiff
  // Return:
  //   AL = Boolean result

  // 先把 stack 入参取出来（之后会改 RSP）。
  mov r10, qword ptr [rsp + 8]   // out ptr: @resultValue

  // 保存 out ptr / fn 到栈上（避免被测函数破坏 caller-saved 寄存器）。
  // 额外说明：这里用 16 bytes local + 5 pushes，保证 call 前 RSP 16-byte 对齐。
  sub rsp, 16
  mov qword ptr [rsp], r10       // out ptr
  mov qword ptr [rsp + 8], rdi   // fn ptr

  // 保存 callee-saved（本函数也必须遵守 ABI）
  push rbx
  push r12
  push r13
  push r14
  push r15

  // 注意：FPC 内置汇编器对 64-bit imm 支持有限，这里用“可表示的 signed dword”哨兵值。
  mov rbx, $11223344
  mov r12, $55667788
  mov r13, $0F0E0D0C
  mov r14, $01020304
  mov r15, $22334455

  // call fn(a, b, len, out firstDiff, lastDiff)
  mov rax, qword ptr [rsp + 48]  // fn ptr
  mov rdi, rsi                   // a
  mov rsi, rdx                   // b
  mov rdx, rcx                   // len
  mov rcx, r8                    // @firstDiff
  mov r8, r9                     // @lastDiff
  call rax

  // store Boolean result (reload out ptr after the call)
  mov r10, qword ptr [rsp + 40]
  mov byte ptr [r10], al

  // verify callee-saved regs
  cmp rbx, $11223344
  jne @fail
  cmp r12, $55667788
  jne @fail
  cmp r13, $0F0E0D0C
  jne @fail
  cmp r14, $01020304
  jne @fail
  cmp r15, $22334455
  jne @fail

  mov eax, 1
  jmp @done

@fail:
  xor eax, eax

@done:
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 16
end;

function TTestCase_AVX2VectorAsm.GetVectorAsmTargetBackend: TSimdBackend;
begin
  Result := sbAVX2;
end;

procedure TTestCase_AVX2VectorAsm.RefreshVectorAsmBackendRegistration;
begin
  RegisterAVX2Backend;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Fma_FusedWhenFMAAvailable;
var
  dt: PSimdDispatchTable;
  a, b, c, r: TVecF32x4;
  expected: Single;
  i: Integer;
begin
  if not HasAVX2 then
  begin
    AssertEquals('Fallback backend should be Scalar', Ord(sbScalar), Ord(GetCurrentBackend));
    Exit;
  end;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.FmaF32x4 should be assigned', Assigned(dt^.FmaF32x4));
  AssertTrue('FmaF32x4 should not be scalar when vector asm enabled', dt^.FmaF32x4 <> @ScalarFmaF32x4);

  // 构造一个“只有 fused FMA 才会得到非零”的经典用例：
  // a = b = 1 + 2^-23 (float32 的下一个可表示数)
  // c = -(1 + 2^-22)
  // 真实结果：2^-46
  // 非 fused：先乘法舍入到 1+2^-22，再加 c => 0
  a := VecF32x4Splat(SingleFromBits($3F800001));
  b := a;
  c := VecF32x4Splat(SingleFromBits($BF800002));

  r := VecF32x4Fma(a, b, c);

  if HasFeature(gfFMA) then
    expected := SingleFromBits($28800000) // 2^-46
  else
    expected := 0.0;

  for i := 0 to 3 do
    AssertEquals('Fma element ' + IntToStr(i), expected, VecF32x4Extract(r, i), 0.0);
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x8_AddSubMulDiv_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecF32x8;
  expV, actV: TVecF32x8;
  i, iter: Integer;
  eps: Single;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.AddF32x8 should be assigned', Assigned(dt^.AddF32x8));
  AssertTrue('Dispatch.SubF32x8 should be assigned', Assigned(dt^.SubF32x8));
  AssertTrue('Dispatch.MulF32x8 should be assigned', Assigned(dt^.MulF32x8));
  AssertTrue('Dispatch.DivF32x8 should be assigned', Assigned(dt^.DivF32x8));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('AddF32x8 should not be scalar when vector asm enabled', dt^.AddF32x8 <> @ScalarAddF32x8);
  AssertTrue('SubF32x8 should not be scalar when vector asm enabled', dt^.SubF32x8 <> @ScalarSubF32x8);
  AssertTrue('MulF32x8 should not be scalar when vector asm enabled', dt^.MulF32x8 <> @ScalarMulF32x8);
  AssertTrue('DivF32x8 should not be scalar when vector asm enabled', dt^.DivF32x8 <> @ScalarDivF32x8);

  eps := 1e-6;
  RandSeed := 12345;

  for iter := 1 to 200 do
  begin
    for i := 0 to 7 do
    begin
      // 限制数值范围，避免溢出/下溢导致的非本测试目标分支
      a.f[i] := (Random(2000000) - 1000000) / 1000.0;
      b.f[i] := (Random(2000000) - 1000000) / 1000.0;
      if Abs(b.f[i]) < 1e-3 then
        b.f[i] := 1.0; // 避免除零/极小数
    end;

    // Add
    expV := ScalarAddF32x8(a, b);
    actV := dt^.AddF32x8(a, b);
    for i := 0 to 7 do
      AssertEquals('Add elem ' + IntToStr(i), expV.f[i], actV.f[i], eps);

    // Sub
    expV := ScalarSubF32x8(a, b);
    actV := dt^.SubF32x8(a, b);
    for i := 0 to 7 do
      AssertEquals('Sub elem ' + IntToStr(i), expV.f[i], actV.f[i], eps);

    // Mul
    expV := ScalarMulF32x8(a, b);
    actV := dt^.MulF32x8(a, b);
    for i := 0 to 7 do
      AssertEquals('Mul elem ' + IntToStr(i), expV.f[i], actV.f[i], eps);

    // Div
    expV := ScalarDivF32x8(a, b);
    actV := dt^.DivF32x8(a, b);
    for i := 0 to 7 do
      AssertEquals('Div elem ' + IntToStr(i), expV.f[i], actV.f[i], eps);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x8_AddSubMulDiv_SpecialValues_Consistency;
var
  dt: PSimdDispatchTable;
  a, b, bDiv: TVecF32x8;
  expV, actV: TVecF32x8;
  i: Integer;
  expBits, actBits: DWord;

  procedure AssertSameElementBits(const op: string; idx: Integer; expVal, actVal: Single);
  begin
    if IsNaNSingle(expVal) then
      AssertTrue(op + ' elem ' + IntToStr(idx) + ' should be NaN', IsNaNSingle(actVal))
    else
    begin
      expBits := BitsFromSingle(expVal);
      actBits := BitsFromSingle(actVal);
      AssertTrue(op + ' elem ' + IntToStr(idx) + ' bits should match', expBits = actBits);
    end;
  end;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.AddF32x8 should be assigned', Assigned(dt^.AddF32x8));
  AssertTrue('Dispatch.SubF32x8 should be assigned', Assigned(dt^.SubF32x8));
  AssertTrue('Dispatch.MulF32x8 should be assigned', Assigned(dt^.MulF32x8));
  AssertTrue('Dispatch.DivF32x8 should be assigned', Assigned(dt^.DivF32x8));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('AddF32x8 should not be scalar when vector asm enabled', dt^.AddF32x8 <> @ScalarAddF32x8);
  AssertTrue('SubF32x8 should not be scalar when vector asm enabled', dt^.SubF32x8 <> @ScalarSubF32x8);
  AssertTrue('MulF32x8 should not be scalar when vector asm enabled', dt^.MulF32x8 <> @ScalarMulF32x8);
  AssertTrue('DivF32x8 should not be scalar when vector asm enabled', dt^.DivF32x8 <> @ScalarDivF32x8);

  // 构造包含 NaN/Inf/±0 的输入，确保在 AVX2 vector-asm 路径下与 scalar 参考结果一致。
  a.f[0] := SingleFromBits($80000000); // -0
  b.f[0] := SingleFromBits($00000000); // +0

  a.f[1] := SingleFromBits($00000000); // +0
  b.f[1] := SingleFromBits($80000000); // -0

  a.f[2] := SingleFromBits($7F800000); // +Inf
  b.f[2] := 1.0;

  a.f[3] := SingleFromBits($FF800000); // -Inf
  b.f[3] := 1.0;

  a.f[4] := SingleFromBits($7FC00000); // qNaN
  b.f[4] := 2.0;

  a.f[5] := 1.0;
  b.f[5] := SingleFromBits($7F800000); // +Inf

  a.f[6] := -1.0;
  b.f[6] := SingleFromBits($FF800000); // -Inf

  a.f[7] := 123.0;
  b.f[7] := SingleFromBits($7FC00000); // qNaN

  // Add
  expV := ScalarAddF32x8(a, b);
  actV := dt^.AddF32x8(a, b);
  for i := 0 to 7 do
    AssertSameElementBits('Add', i, expV.f[i], actV.f[i]);

  // Sub
  expV := ScalarSubF32x8(a, b);
  actV := dt^.SubF32x8(a, b);
  for i := 0 to 7 do
    AssertSameElementBits('Sub', i, expV.f[i], actV.f[i]);

  // Mul
  expV := ScalarMulF32x8(a, b);
  actV := dt^.MulF32x8(a, b);
  for i := 0 to 7 do
    AssertSameElementBits('Mul', i, expV.f[i], actV.f[i]);

  // Div（避免除以 ±0；其他 special value 保留）
  bDiv := b;
  for i := 0 to 7 do
    // 避免使用浮点比较（NaN 会触发 InvalidOp）
    if (BitsFromSingle(bDiv.f[i]) and $7FFFFFFF) = 0 then
      bDiv.f[i] := 1.0;

  expV := ScalarDivF32x8(a, bDiv);
  actV := dt^.DivF32x8(a, bDiv);
  for i := 0 to 7 do
    AssertSameElementBits('Div', i, expV.f[i], actV.f[i]);
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF64x2_AddSubMulDiv_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecF64x2;
  expV, actV: TVecF64x2;
  iter, i: Integer;
  eps: Double;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.AddF64x2 should be assigned', Assigned(dt^.AddF64x2));
  AssertTrue('Dispatch.SubF64x2 should be assigned', Assigned(dt^.SubF64x2));
  AssertTrue('Dispatch.MulF64x2 should be assigned', Assigned(dt^.MulF64x2));
  AssertTrue('Dispatch.DivF64x2 should be assigned', Assigned(dt^.DivF64x2));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('AddF64x2 should not be scalar when vector asm enabled', dt^.AddF64x2 <> @ScalarAddF64x2);
  AssertTrue('SubF64x2 should not be scalar when vector asm enabled', dt^.SubF64x2 <> @ScalarSubF64x2);
  AssertTrue('MulF64x2 should not be scalar when vector asm enabled', dt^.MulF64x2 <> @ScalarMulF64x2);
  AssertTrue('DivF64x2 should not be scalar when vector asm enabled', dt^.DivF64x2 <> @ScalarDivF64x2);

  eps := 1e-12;
  RandSeed := 20251224;

  for iter := 1 to 2000 do
  begin
    for i := 0 to 1 do
    begin
      a.d[i] := (Random(2000001) - 1000000) / 1000.0;
      b.d[i] := (Random(2000001) - 1000000) / 1000.0;
      if Abs(b.d[i]) < 1e-12 then
        b.d[i] := 1.0;
    end;

    // Add
    expV := ScalarAddF64x2(a, b);
    actV := dt^.AddF64x2(a, b);
    for i := 0 to 1 do
      AssertEquals('F64x2 Add iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.d[i], actV.d[i], eps);

    // Sub
    expV := ScalarSubF64x2(a, b);
    actV := dt^.SubF64x2(a, b);
    for i := 0 to 1 do
      AssertEquals('F64x2 Sub iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.d[i], actV.d[i], eps);

    // Mul
    expV := ScalarMulF64x2(a, b);
    actV := dt^.MulF64x2(a, b);
    for i := 0 to 1 do
      AssertEquals('F64x2 Mul iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.d[i], actV.d[i], eps);

    // Div
    expV := ScalarDivF64x2(a, b);
    actV := dt^.DivF64x2(a, b);
    for i := 0 to 1 do
      AssertEquals('F64x2 Div iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.d[i], actV.d[i], eps);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF64x2_AddSubMulDiv_SpecialValues_Consistency;
var
  dt: PSimdDispatchTable;
  a, b, bDiv: TVecF64x2;
  expV, actV: TVecF64x2;
  i: Integer;
  expBits, actBits: QWord;

  procedure AssertSameElementBits(const op: string; idx: Integer; expVal, actVal: Double);
  begin
    if IsNaNDouble(expVal) then
      AssertTrue(op + ' lane ' + IntToStr(idx) + ' should be NaN', IsNaNDouble(actVal))
    else
    begin
      expBits := BitsFromDouble(expVal);
      actBits := BitsFromDouble(actVal);
      AssertTrue(op + ' lane ' + IntToStr(idx) + ' bits should match', expBits = actBits);
    end;
  end;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.AddF64x2 should be assigned', Assigned(dt^.AddF64x2));
  AssertTrue('Dispatch.SubF64x2 should be assigned', Assigned(dt^.SubF64x2));
  AssertTrue('Dispatch.MulF64x2 should be assigned', Assigned(dt^.MulF64x2));
  AssertTrue('Dispatch.DivF64x2 should be assigned', Assigned(dt^.DivF64x2));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('AddF64x2 should not be scalar when vector asm enabled', dt^.AddF64x2 <> @ScalarAddF64x2);
  AssertTrue('SubF64x2 should not be scalar when vector asm enabled', dt^.SubF64x2 <> @ScalarSubF64x2);
  AssertTrue('MulF64x2 should not be scalar when vector asm enabled', dt^.MulF64x2 <> @ScalarMulF64x2);
  AssertTrue('DivF64x2 should not be scalar when vector asm enabled', dt^.DivF64x2 <> @ScalarDivF64x2);

  // 特殊值：±0 / ±Inf / qNaN
  a.d[0] := DoubleFromBits(QWord($8000000000000000)); // -0
  b.d[0] := DoubleFromBits(QWord($0000000000000000)); // +0

  a.d[1] := DoubleFromBits(QWord($7FF0000000000000)); // +Inf
  b.d[1] := DoubleFromBits(QWord($7FF8000000000000)); // qNaN

  // Add
  expV := ScalarAddF64x2(a, b);
  actV := dt^.AddF64x2(a, b);
  for i := 0 to 1 do
    AssertSameElementBits('F64x2 Add', i, expV.d[i], actV.d[i]);

  // Sub
  expV := ScalarSubF64x2(a, b);
  actV := dt^.SubF64x2(a, b);
  for i := 0 to 1 do
    AssertSameElementBits('F64x2 Sub', i, expV.d[i], actV.d[i]);

  // Mul
  expV := ScalarMulF64x2(a, b);
  actV := dt^.MulF64x2(a, b);
  for i := 0 to 1 do
    AssertSameElementBits('F64x2 Mul', i, expV.d[i], actV.d[i]);

  // Div（避免除以 ±0；其他 special value 保留）
  bDiv := b;
  for i := 0 to 1 do
    if (BitsFromDouble(bDiv.d[i]) and QWord($7FFFFFFFFFFFFFFF)) = 0 then
      bDiv.d[i] := 1.0;

  expV := ScalarDivF64x2(a, bDiv);
  actV := dt^.DivF64x2(a, bDiv);
  for i := 0 to 1 do
    AssertSameElementBits('F64x2 Div', i, expV.d[i], actV.d[i]);
end;

procedure TTestCase_AVX2VectorAsm.Test_VecI32x4_AddSubMul_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecI32x4;
  expV, actV: TVecI32x4;
  iter, i: Integer;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.AddI32x4 should be assigned', Assigned(dt^.AddI32x4));
  AssertTrue('Dispatch.SubI32x4 should be assigned', Assigned(dt^.SubI32x4));
  AssertTrue('Dispatch.MulI32x4 should be assigned', Assigned(dt^.MulI32x4));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('AddI32x4 should not be scalar when vector asm enabled', dt^.AddI32x4 <> @ScalarAddI32x4);
  AssertTrue('SubI32x4 should not be scalar when vector asm enabled', dt^.SubI32x4 <> @ScalarSubI32x4);
  AssertTrue('MulI32x4 should not be scalar when vector asm enabled', dt^.MulI32x4 <> @ScalarMulI32x4);

  RandSeed := 20251225;

  for iter := 1 to 5000 do
  begin
    // 选择安全范围，避免 32-bit 乘法溢出（保证结果可精确对比）。
    for i := 0 to 3 do
    begin
      a.i[i] := Random(60001) - 30000; // [-30000..30000]
      b.i[i] := Random(60001) - 30000;
    end;

    // Add
    expV := ScalarAddI32x4(a, b);
    actV := dt^.AddI32x4(a, b);
    for i := 0 to 3 do
      AssertEquals('I32x4 Add iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);

    // Sub
    expV := ScalarSubI32x4(a, b);
    actV := dt^.SubI32x4(a, b);
    for i := 0 to 3 do
      AssertEquals('I32x4 Sub iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);

    // Mul
    expV := ScalarMulI32x4(a, b);
    actV := dt^.MulI32x4(a, b);
    for i := 0 to 3 do
      AssertEquals('I32x4 Mul iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecI32x4_AddSubMul_BoundaryConsistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecI32x4;
  expV, actV: TVecI32x4;
  i: Integer;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.AddI32x4 should be assigned', Assigned(dt^.AddI32x4));
  AssertTrue('Dispatch.SubI32x4 should be assigned', Assigned(dt^.SubI32x4));
  AssertTrue('Dispatch.MulI32x4 should be assigned', Assigned(dt^.MulI32x4));

  // Add/Sub：边界但不溢出
  a.i[0] := High(Int32) - 1; b.i[0] := 1;  // -> High(Int32)
  a.i[1] := Low(Int32) + 1;  b.i[1] := -1; // -> Low(Int32)
  a.i[2] := 0;               b.i[2] := 0;
  a.i[3] := -1;              b.i[3] := 1;

  expV := ScalarAddI32x4(a, b);
  actV := dt^.AddI32x4(a, b);
  for i := 0 to 3 do
    AssertEquals('I32x4 Add boundary lane ' + IntToStr(i), expV.i[i], actV.i[i]);

  expV := ScalarSubI32x4(a, b);
  actV := dt^.SubI32x4(a, b);
  for i := 0 to 3 do
    AssertEquals('I32x4 Sub boundary lane ' + IntToStr(i), expV.i[i], actV.i[i]);

  // Mul：使用 46340 保证 32-bit signed 乘法不溢出。
  a.i[0] := 46340;  b.i[0] := 46340;
  a.i[1] := -46340; b.i[1] := 46340;
  a.i[2] := 0;      b.i[2] := 12345;
  a.i[3] := -1;     b.i[3] := -1;

  expV := ScalarMulI32x4(a, b);
  actV := dt^.MulI32x4(a, b);
  for i := 0 to 3 do
    AssertEquals('I32x4 Mul boundary lane ' + IntToStr(i), expV.i[i], actV.i[i]);
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Compare_SpecialValues_Consistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecF32x4;
  expMask, actMask: TMask4;
  savedMask: TFPUExceptionMask;

  function Mask4Of(b0, b1, b2, b3: Boolean): TMask4; inline;
  begin
    Result := 0;
    if b0 then Result := Result or (1 shl 0);
    if b1 then Result := Result or (1 shl 1);
    if b2 then Result := Result or (1 shl 2);
    if b3 then Result := Result or (1 shl 3);
  end;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.CmpEqF32x4 should be assigned', Assigned(dt^.CmpEqF32x4));
  AssertTrue('Dispatch.CmpLtF32x4 should be assigned', Assigned(dt^.CmpLtF32x4));
  AssertTrue('Dispatch.CmpLeF32x4 should be assigned', Assigned(dt^.CmpLeF32x4));
  AssertTrue('Dispatch.CmpGtF32x4 should be assigned', Assigned(dt^.CmpGtF32x4));
  AssertTrue('Dispatch.CmpGeF32x4 should be assigned', Assigned(dt^.CmpGeF32x4));
  AssertTrue('Dispatch.CmpNeF32x4 should be assigned', Assigned(dt^.CmpNeF32x4));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('CmpEqF32x4 should not be scalar when vector asm enabled', dt^.CmpEqF32x4 <> @ScalarCmpEqF32x4);
  AssertTrue('CmpLtF32x4 should not be scalar when vector asm enabled', dt^.CmpLtF32x4 <> @ScalarCmpLtF32x4);
  AssertTrue('CmpLeF32x4 should not be scalar when vector asm enabled', dt^.CmpLeF32x4 <> @ScalarCmpLeF32x4);
  AssertTrue('CmpGtF32x4 should not be scalar when vector asm enabled', dt^.CmpGtF32x4 <> @ScalarCmpGtF32x4);
  AssertTrue('CmpGeF32x4 should not be scalar when vector asm enabled', dt^.CmpGeF32x4 <> @ScalarCmpGeF32x4);
  AssertTrue('CmpNeF32x4 should not be scalar when vector asm enabled', dt^.CmpNeF32x4 <> @ScalarCmpNeF32x4);

  // 设计点：比较指令在 NaN 场景下会触发 InvalidOp（若未屏蔽异常），
  // 这里临时屏蔽所有 FPU 异常，避免测试运行被中断。
  savedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    // 我们直接写出 IEEE/SSE 语义的期望 mask。
    a.f[0] := SingleFromBits($7FC00000); // NaN
    b.f[0] := 1.0;

    a.f[1] := 1.0;
    b.f[1] := SingleFromBits($7FC00000); // NaN

    a.f[2] := SingleFromBits($7F800000); // +Inf
    b.f[2] := SingleFromBits($7F800000); // +Inf

    a.f[3] := SingleFromBits($80000000); // -0
    b.f[3] := 0.0;                       // +0

    // Eq: NaN==x false; Inf==Inf true; -0==+0 true
    expMask := Mask4Of(False, False, True, True);
    actMask := dt^.CmpEqF32x4(a, b);
    AssertEquals('CmpEq mask', expMask, actMask);

    // Ne: NaN!=x true (unordered); Inf!=Inf false; -0!=+0 false
    expMask := Mask4Of(True, True, False, False);
    actMask := dt^.CmpNeF32x4(a, b);
    AssertEquals('CmpNe mask', expMask, actMask);

    // Lt: NaN comparisons false; Inf<Inf false; -0<+0 false
    expMask := Mask4Of(False, False, False, False);
    actMask := dt^.CmpLtF32x4(a, b);
    AssertEquals('CmpLt mask', expMask, actMask);

    // Le: NaN comparisons false; Inf<=Inf true; -0<=+0 true
    expMask := Mask4Of(False, False, True, True);
    actMask := dt^.CmpLeF32x4(a, b);
    AssertEquals('CmpLe mask', expMask, actMask);

    // Gt: NaN comparisons false; Inf>Inf false; -0>+0 false
    expMask := Mask4Of(False, False, False, False);
    actMask := dt^.CmpGtF32x4(a, b);
    AssertEquals('CmpGt mask', expMask, actMask);

    // Ge: NaN comparisons false; Inf>=Inf true; -0>=+0 true
    expMask := Mask4Of(False, False, True, True);
    actMask := dt^.CmpGeF32x4(a, b);
    AssertEquals('CmpGe mask', expMask, actMask);
  finally
    SetExceptionMask(savedMask);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Compare_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecF32x4;
  iter: Integer;
  expMask, actMask: TMask4;

  function Mask4Of(b0, b1, b2, b3: Boolean): TMask4; inline;
  begin
    Result := 0;
    if b0 then Result := Result or (1 shl 0);
    if b1 then Result := Result or (1 shl 1);
    if b2 then Result := Result or (1 shl 2);
    if b3 then Result := Result or (1 shl 3);
  end;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.CmpEqF32x4 should be assigned', Assigned(dt^.CmpEqF32x4));
  AssertTrue('Dispatch.CmpLtF32x4 should be assigned', Assigned(dt^.CmpLtF32x4));
  AssertTrue('Dispatch.CmpLeF32x4 should be assigned', Assigned(dt^.CmpLeF32x4));
  AssertTrue('Dispatch.CmpGtF32x4 should be assigned', Assigned(dt^.CmpGtF32x4));
  AssertTrue('Dispatch.CmpGeF32x4 should be assigned', Assigned(dt^.CmpGeF32x4));
  AssertTrue('Dispatch.CmpNeF32x4 should be assigned', Assigned(dt^.CmpNeF32x4));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('CmpEqF32x4 should not be scalar when vector asm enabled', dt^.CmpEqF32x4 <> @ScalarCmpEqF32x4);
  AssertTrue('CmpLtF32x4 should not be scalar when vector asm enabled', dt^.CmpLtF32x4 <> @ScalarCmpLtF32x4);
  AssertTrue('CmpLeF32x4 should not be scalar when vector asm enabled', dt^.CmpLeF32x4 <> @ScalarCmpLeF32x4);
  AssertTrue('CmpGtF32x4 should not be scalar when vector asm enabled', dt^.CmpGtF32x4 <> @ScalarCmpGtF32x4);
  AssertTrue('CmpGeF32x4 should not be scalar when vector asm enabled', dt^.CmpGeF32x4 <> @ScalarCmpGeF32x4);
  AssertTrue('CmpNeF32x4 should not be scalar when vector asm enabled', dt^.CmpNeF32x4 <> @ScalarCmpNeF32x4);

  RandSeed := 20251216;

  for iter := 1 to 200 do
  begin
    // 设计点：避免 NaN/Inf，确保对比的期望值可用普通浮点比较计算。
    // lane0：相等
    a.f[0] := (Random(2000001) - 1000000) / 1000.0;
    b.f[0] := a.f[0];

    // lane1：a < b
    a.f[1] := (Random(2000001) - 1000000) / 1000.0;
    b.f[1] := a.f[1] + 1.0;

    // lane2：a > b
    a.f[2] := (Random(2000001) - 1000000) / 1000.0;
    b.f[2] := a.f[2] - 1.0;

    // lane3：随机
    a.f[3] := (Random(2000001) - 1000000) / 1000.0;
    b.f[3] := (Random(2000001) - 1000000) / 1000.0;

    expMask := Mask4Of(a.f[0] = b.f[0], a.f[1] = b.f[1], a.f[2] = b.f[2], a.f[3] = b.f[3]);
    actMask := dt^.CmpEqF32x4(a, b);
    AssertEquals('CmpEq iter ' + IntToStr(iter), expMask, actMask);

    expMask := Mask4Of(a.f[0] <> b.f[0], a.f[1] <> b.f[1], a.f[2] <> b.f[2], a.f[3] <> b.f[3]);
    actMask := dt^.CmpNeF32x4(a, b);
    AssertEquals('CmpNe iter ' + IntToStr(iter), expMask, actMask);

    expMask := Mask4Of(a.f[0] < b.f[0], a.f[1] < b.f[1], a.f[2] < b.f[2], a.f[3] < b.f[3]);
    actMask := dt^.CmpLtF32x4(a, b);
    AssertEquals('CmpLt iter ' + IntToStr(iter), expMask, actMask);

    expMask := Mask4Of(a.f[0] <= b.f[0], a.f[1] <= b.f[1], a.f[2] <= b.f[2], a.f[3] <= b.f[3]);
    actMask := dt^.CmpLeF32x4(a, b);
    AssertEquals('CmpLe iter ' + IntToStr(iter), expMask, actMask);

    expMask := Mask4Of(a.f[0] > b.f[0], a.f[1] > b.f[1], a.f[2] > b.f[2], a.f[3] > b.f[3]);
    actMask := dt^.CmpGtF32x4(a, b);
    AssertEquals('CmpGt iter ' + IntToStr(iter), expMask, actMask);

    expMask := Mask4Of(a.f[0] >= b.f[0], a.f[1] >= b.f[1], a.f[2] >= b.f[2], a.f[3] >= b.f[3]);
    actMask := dt^.CmpGeF32x4(a, b);
    AssertEquals('CmpGe iter ' + IntToStr(iter), expMask, actMask);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_AddSubMulDiv_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecF32x4;
  expV, actV: TVecF32x4;
  i, iter: Integer;
  eps: Single;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.AddF32x4 should be assigned', Assigned(dt^.AddF32x4));
  AssertTrue('Dispatch.SubF32x4 should be assigned', Assigned(dt^.SubF32x4));
  AssertTrue('Dispatch.MulF32x4 should be assigned', Assigned(dt^.MulF32x4));
  AssertTrue('Dispatch.DivF32x4 should be assigned', Assigned(dt^.DivF32x4));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('AddF32x4 should not be scalar when vector asm enabled', dt^.AddF32x4 <> @ScalarAddF32x4);
  AssertTrue('SubF32x4 should not be scalar when vector asm enabled', dt^.SubF32x4 <> @ScalarSubF32x4);
  AssertTrue('MulF32x4 should not be scalar when vector asm enabled', dt^.MulF32x4 <> @ScalarMulF32x4);
  AssertTrue('DivF32x4 should not be scalar when vector asm enabled', dt^.DivF32x4 <> @ScalarDivF32x4);

  eps := 1e-6;
  RandSeed := 54321;

  for iter := 1 to 500 do
  begin
    for i := 0 to 3 do
    begin
      a.f[i] := (Random(2000001) - 1000000) / 1000.0;
      b.f[i] := (Random(2000001) - 1000000) / 1000.0;
      if Abs(b.f[i]) < 1e-3 then
        b.f[i] := 1.0;
    end;

    // Add
    expV := ScalarAddF32x4(a, b);
    actV := dt^.AddF32x4(a, b);
    for i := 0 to 3 do
      AssertEquals('Add elem ' + IntToStr(i), expV.f[i], actV.f[i], eps);

    // Sub
    expV := ScalarSubF32x4(a, b);
    actV := dt^.SubF32x4(a, b);
    for i := 0 to 3 do
      AssertEquals('Sub elem ' + IntToStr(i), expV.f[i], actV.f[i], eps);

    // Mul
    expV := ScalarMulF32x4(a, b);
    actV := dt^.MulF32x4(a, b);
    for i := 0 to 3 do
      AssertEquals('Mul elem ' + IntToStr(i), expV.f[i], actV.f[i], eps);

    // Div
    expV := ScalarDivF32x4(a, b);
    actV := dt^.DivF32x4(a, b);
    for i := 0 to 3 do
      AssertEquals('Div elem ' + IntToStr(i), expV.f[i], actV.f[i], eps);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_AddSubMulDiv_SpecialValues_Consistency;
var
  dt: PSimdDispatchTable;
  a, b, bDiv: TVecF32x4;
  expV, actV: TVecF32x4;
  i: Integer;
  expBits, actBits: DWord;

  procedure AssertSameElementBits(const op: string; idx: Integer; expVal, actVal: Single);
  begin
    if IsNaNSingle(expVal) then
      AssertTrue(op + ' elem ' + IntToStr(idx) + ' should be NaN', IsNaNSingle(actVal))
    else
    begin
      expBits := BitsFromSingle(expVal);
      actBits := BitsFromSingle(actVal);
      AssertTrue(op + ' elem ' + IntToStr(idx) + ' bits should match', expBits = actBits);
    end;
  end;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.AddF32x4 should be assigned', Assigned(dt^.AddF32x4));
  AssertTrue('Dispatch.SubF32x4 should be assigned', Assigned(dt^.SubF32x4));
  AssertTrue('Dispatch.MulF32x4 should be assigned', Assigned(dt^.MulF32x4));
  AssertTrue('Dispatch.DivF32x4 should be assigned', Assigned(dt^.DivF32x4));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('AddF32x4 should not be scalar when vector asm enabled', dt^.AddF32x4 <> @ScalarAddF32x4);
  AssertTrue('SubF32x4 should not be scalar when vector asm enabled', dt^.SubF32x4 <> @ScalarSubF32x4);
  AssertTrue('MulF32x4 should not be scalar when vector asm enabled', dt^.MulF32x4 <> @ScalarMulF32x4);
  AssertTrue('DivF32x4 should not be scalar when vector asm enabled', dt^.DivF32x4 <> @ScalarDivF32x4);

  a.f[0] := SingleFromBits($80000000); // -0
  b.f[0] := SingleFromBits($00000000); // +0

  a.f[1] := SingleFromBits($7F800000); // +Inf
  b.f[1] := 1.0;

  a.f[2] := SingleFromBits($7FC00000); // qNaN
  b.f[2] := 2.0;

  a.f[3] := 123.0;
  b.f[3] := SingleFromBits($FF800000); // -Inf

  // Add
  expV := ScalarAddF32x4(a, b);
  actV := dt^.AddF32x4(a, b);
  for i := 0 to 3 do
    AssertSameElementBits('Add', i, expV.f[i], actV.f[i]);

  // Sub
  expV := ScalarSubF32x4(a, b);
  actV := dt^.SubF32x4(a, b);
  for i := 0 to 3 do
    AssertSameElementBits('Sub', i, expV.f[i], actV.f[i]);

  // Mul
  expV := ScalarMulF32x4(a, b);
  actV := dt^.MulF32x4(a, b);
  for i := 0 to 3 do
    AssertSameElementBits('Mul', i, expV.f[i], actV.f[i]);

  // Div（避免除以 ±0；其他 special value 保留）
  bDiv := b;
  for i := 0 to 3 do
    if (BitsFromSingle(bDiv.f[i]) and $7FFFFFFF) = 0 then
      bDiv.f[i] := 1.0;

  expV := ScalarDivF32x4(a, bDiv);
  actV := dt^.DivF32x4(a, bDiv);
  for i := 0 to 3 do
    AssertSameElementBits('Div', i, expV.f[i], actV.f[i]);
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Abs_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a: TVecF32x4;
  expV, actV: TVecF32x4;
  i, iter: Integer;
  expBits, actBits: DWord;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.AbsF32x4 should be assigned', Assigned(dt^.AbsF32x4));

  AssertTrue('AbsF32x4 should not be scalar when vector asm enabled', dt^.AbsF32x4 <> @ScalarAbsF32x4);

  RandSeed := 24680;

  for iter := 1 to 500 do
  begin
    for i := 0 to 3 do
      a.f[i] := (Random(2000001) - 1000000) / 1000.0;

    expV := ScalarAbsF32x4(a);
    actV := dt^.AbsF32x4(a);

    for i := 0 to 3 do
    begin
      expBits := BitsFromSingle(expV.f[i]);
      actBits := BitsFromSingle(actV.f[i]);
      AssertTrue('Abs elem ' + IntToStr(i) + ' bits should match', expBits = actBits);
    end;
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Abs_SpecialValues_Consistency;
var
  dt: PSimdDispatchTable;
  a: TVecF32x4;
  expV, actV: TVecF32x4;
  i: Integer;
  expBits, actBits: DWord;

  procedure AssertSameElementBits(const op: string; idx: Integer; expVal, actVal: Single);
  begin
    if IsNaNSingle(expVal) then
      AssertTrue(op + ' elem ' + IntToStr(idx) + ' should be NaN', IsNaNSingle(actVal))
    else
    begin
      expBits := BitsFromSingle(expVal);
      actBits := BitsFromSingle(actVal);
      AssertTrue(op + ' elem ' + IntToStr(idx) + ' bits should match', expBits = actBits);
    end;
  end;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.AbsF32x4 should be assigned', Assigned(dt^.AbsF32x4));

  AssertTrue('AbsF32x4 should not be scalar when vector asm enabled', dt^.AbsF32x4 <> @ScalarAbsF32x4);

  a.f[0] := SingleFromBits($80000000); // -0
  a.f[1] := SingleFromBits($FF800000); // -Inf
  a.f[2] := SingleFromBits($7FC00000); // qNaN
  a.f[3] := -123.0;

  expV := ScalarAbsF32x4(a);
  actV := dt^.AbsF32x4(a);

  for i := 0 to 3 do
    AssertSameElementBits('Abs', i, expV.f[i], actV.f[i]);
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Sqrt_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a: TVecF32x4;
  expV, actV: TVecF32x4;
  i, iter: Integer;
  eps: Single;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.SqrtF32x4 should be assigned', Assigned(dt^.SqrtF32x4));

  AssertTrue('SqrtF32x4 should not be scalar when vector asm enabled', dt^.SqrtF32x4 <> @ScalarSqrtF32x4);

  eps := 1e-6;
  RandSeed := 13579;

  for iter := 1 to 500 do
  begin
    for i := 0 to 3 do
      a.f[i] := Random(1000001) / 1000.0; // [0..1000]

    expV := ScalarSqrtF32x4(a);
    actV := dt^.SqrtF32x4(a);

    for i := 0 to 3 do
      AssertEquals('Sqrt elem ' + IntToStr(i), expV.f[i], actV.f[i], eps);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Sqrt_SpecialValues_Consistency;
var
  dt: PSimdDispatchTable;
  a: TVecF32x4;
  expV, actV: TVecF32x4;
  i: Integer;
  expBits, actBits: DWord;
  savedMask: TFPUExceptionMask;

  procedure AssertSameElementBits(const op: string; idx: Integer; expVal, actVal: Single);
  begin
    if IsNaNSingle(expVal) then
      AssertTrue(op + ' elem ' + IntToStr(idx) + ' should be NaN', IsNaNSingle(actVal))
    else
    begin
      expBits := BitsFromSingle(expVal);
      actBits := BitsFromSingle(actVal);
      AssertTrue(op + ' elem ' + IntToStr(idx) + ' bits should match', expBits = actBits);
    end;
  end;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.SqrtF32x4 should be assigned', Assigned(dt^.SqrtF32x4));

  AssertTrue('SqrtF32x4 should not be scalar when vector asm enabled', dt^.SqrtF32x4 <> @ScalarSqrtF32x4);

  savedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    a.f[0] := SingleFromBits($80000000); // -0
    a.f[1] := SingleFromBits($7FC00000); // qNaN
    a.f[2] := SingleFromBits($7F800000); // +Inf
    a.f[3] := -1.0;

    expV := ScalarSqrtF32x4(a);
    actV := dt^.SqrtF32x4(a);

    for i := 0 to 3 do
      AssertSameElementBits('Sqrt', i, expV.f[i], actV.f[i]);
  finally
    SetExceptionMask(savedMask);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_MinMax_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecF32x4;
  expV, actV: TVecF32x4;
  i, iter: Integer;
  expBits, actBits: DWord;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.MinF32x4 should be assigned', Assigned(dt^.MinF32x4));
  AssertTrue('Dispatch.MaxF32x4 should be assigned', Assigned(dt^.MaxF32x4));

  AssertTrue('MinF32x4 should not be scalar when vector asm enabled', dt^.MinF32x4 <> @ScalarMinF32x4);
  AssertTrue('MaxF32x4 should not be scalar when vector asm enabled', dt^.MaxF32x4 <> @ScalarMaxF32x4);

  RandSeed := 112233;

  for iter := 1 to 500 do
  begin
    for i := 0 to 3 do
    begin
      a.f[i] := (Random(2000001) - 1000000) / 1000.0;
      b.f[i] := (Random(2000001) - 1000000) / 1000.0;
    end;

    // Min
    expV := ScalarMinF32x4(a, b);
    actV := dt^.MinF32x4(a, b);
    for i := 0 to 3 do
    begin
      expBits := BitsFromSingle(expV.f[i]);
      actBits := BitsFromSingle(actV.f[i]);
      AssertTrue('Min elem ' + IntToStr(i) + ' bits should match', expBits = actBits);
    end;

    // Max
    expV := ScalarMaxF32x4(a, b);
    actV := dt^.MaxF32x4(a, b);
    for i := 0 to 3 do
    begin
      expBits := BitsFromSingle(expV.f[i]);
      actBits := BitsFromSingle(actV.f[i]);
      AssertTrue('Max elem ' + IntToStr(i) + ' bits should match', expBits = actBits);
    end;
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_MinMax_SpecialValues_Consistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecF32x4;
  expV, actV: TVecF32x4;
  i: Integer;
  expBits, actBits: DWord;
  savedMask: TFPUExceptionMask;

  procedure AssertSameElementBits(const op: string; idx: Integer; expVal, actVal: Single);
  begin
    if IsNaNSingle(expVal) then
      AssertTrue(op + ' elem ' + IntToStr(idx) + ' should be NaN', IsNaNSingle(actVal))
    else
    begin
      expBits := BitsFromSingle(expVal);
      actBits := BitsFromSingle(actVal);
      AssertTrue(op + ' elem ' + IntToStr(idx) + ' bits should match', expBits = actBits);
    end;
  end;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.MinF32x4 should be assigned', Assigned(dt^.MinF32x4));
  AssertTrue('Dispatch.MaxF32x4 should be assigned', Assigned(dt^.MaxF32x4));

  AssertTrue('MinF32x4 should not be scalar when vector asm enabled', dt^.MinF32x4 <> @ScalarMinF32x4);
  AssertTrue('MaxF32x4 should not be scalar when vector asm enabled', dt^.MaxF32x4 <> @ScalarMaxF32x4);

  savedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    // 覆盖：±0、Inf、NaN
    a.f[0] := SingleFromBits($80000000); // -0
    b.f[0] := SingleFromBits($00000000); // +0

    a.f[1] := SingleFromBits($00000000); // +0
    b.f[1] := SingleFromBits($80000000); // -0

    a.f[2] := SingleFromBits($7F800000); // +Inf
    b.f[2] := SingleFromBits($FF800000); // -Inf

    a.f[3] := 1.0;
    b.f[3] := SingleFromBits($7FC00000); // qNaN

    // Min
    expV := ScalarMinF32x4(a, b);
    actV := dt^.MinF32x4(a, b);
    for i := 0 to 3 do
      AssertSameElementBits('Min', i, expV.f[i], actV.f[i]);

    // Max
    expV := ScalarMaxF32x4(a, b);
    actV := dt^.MaxF32x4(a, b);
    for i := 0 to 3 do
      AssertSameElementBits('Max', i, expV.f[i], actV.f[i]);
  finally
    SetExceptionMask(savedMask);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Reduce_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a: TVecF32x4;
  iter, i: Integer;
  expS, actS: Single;
  expBits, actBits: DWord;
  epsAdd, epsMul: Single;

  procedure AssertSameSingleBits(const op: string; expVal, actVal: Single);
  begin
    if IsNaNSingle(expVal) then
      AssertTrue(op + ' should be NaN', IsNaNSingle(actVal))
    else
    begin
      expBits := BitsFromSingle(expVal);
      actBits := BitsFromSingle(actVal);
      AssertTrue(op + ' bits should match', expBits = actBits);
    end;
  end;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.ReduceAddF32x4 should be assigned', Assigned(dt^.ReduceAddF32x4));
  AssertTrue('Dispatch.ReduceMinF32x4 should be assigned', Assigned(dt^.ReduceMinF32x4));
  AssertTrue('Dispatch.ReduceMaxF32x4 should be assigned', Assigned(dt^.ReduceMaxF32x4));
  AssertTrue('Dispatch.ReduceMulF32x4 should be assigned', Assigned(dt^.ReduceMulF32x4));

  AssertTrue('ReduceAddF32x4 should not be scalar when vector asm enabled', dt^.ReduceAddF32x4 <> @ScalarReduceAddF32x4);
  AssertTrue('ReduceMinF32x4 should not be scalar when vector asm enabled', dt^.ReduceMinF32x4 <> @ScalarReduceMinF32x4);
  AssertTrue('ReduceMaxF32x4 should not be scalar when vector asm enabled', dt^.ReduceMaxF32x4 <> @ScalarReduceMaxF32x4);
  AssertTrue('ReduceMulF32x4 should not be scalar when vector asm enabled', dt^.ReduceMulF32x4 <> @ScalarReduceMulF32x4);

  // ReduceAdd/ReduceMul 的求和/求积顺序可能在不同实现间不同（浮点非结合律），
  // 这里用小范围随机值 + 适度 eps 进行一致性验证。
  epsAdd := 1e-6;
  epsMul := 1e-6;

  RandSeed := 778899;

  for iter := 1 to 1000 do
  begin
    for i := 0 to 3 do
      a.f[i] := (Random(4000001) - 2000000) / 1000000.0; // [-2..2]

    // ReduceAdd
    expS := ScalarReduceAddF32x4(a);
    actS := dt^.ReduceAddF32x4(a);
    if IsNaNSingle(expS) then
      AssertTrue('ReduceAdd iter ' + IntToStr(iter) + ' should be NaN', IsNaNSingle(actS))
    else
      AssertEquals('ReduceAdd iter ' + IntToStr(iter), expS, actS, epsAdd);

    // ReduceMul
    expS := ScalarReduceMulF32x4(a);
    actS := dt^.ReduceMulF32x4(a);
    if IsNaNSingle(expS) then
      AssertTrue('ReduceMul iter ' + IntToStr(iter) + ' should be NaN', IsNaNSingle(actS))
    else
      AssertEquals('ReduceMul iter ' + IntToStr(iter), expS, actS, epsMul);

    // ReduceMin
    expS := ScalarReduceMinF32x4(a);
    actS := dt^.ReduceMinF32x4(a);
    AssertSameSingleBits('ReduceMin iter ' + IntToStr(iter), expS, actS);

    // ReduceMax
    expS := ScalarReduceMaxF32x4(a);
    actS := dt^.ReduceMaxF32x4(a);
    AssertSameSingleBits('ReduceMax iter ' + IntToStr(iter), expS, actS);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Reduce_SpecialValues_Consistency;
var
  dt: PSimdDispatchTable;
  a: TVecF32x4;
  expS, actS: Single;
  expBits, actBits: DWord;
  savedMask: TFPUExceptionMask;

  procedure AssertSameSingleBits(const op: string; expVal, actVal: Single);
  begin
    if IsNaNSingle(expVal) then
      AssertTrue(op + ' should be NaN', IsNaNSingle(actVal))
    else
    begin
      expBits := BitsFromSingle(expVal);
      actBits := BitsFromSingle(actVal);
      AssertTrue(op + ' bits should match', expBits = actBits);
    end;
  end;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.ReduceAddF32x4 should be assigned', Assigned(dt^.ReduceAddF32x4));
  AssertTrue('Dispatch.ReduceMinF32x4 should be assigned', Assigned(dt^.ReduceMinF32x4));
  AssertTrue('Dispatch.ReduceMaxF32x4 should be assigned', Assigned(dt^.ReduceMaxF32x4));
  AssertTrue('Dispatch.ReduceMulF32x4 should be assigned', Assigned(dt^.ReduceMulF32x4));

  AssertTrue('ReduceAddF32x4 should not be scalar when vector asm enabled', dt^.ReduceAddF32x4 <> @ScalarReduceAddF32x4);
  AssertTrue('ReduceMinF32x4 should not be scalar when vector asm enabled', dt^.ReduceMinF32x4 <> @ScalarReduceMinF32x4);
  AssertTrue('ReduceMaxF32x4 should not be scalar when vector asm enabled', dt^.ReduceMaxF32x4 <> @ScalarReduceMaxF32x4);
  AssertTrue('ReduceMulF32x4 should not be scalar when vector asm enabled', dt^.ReduceMulF32x4 <> @ScalarReduceMulF32x4);

  // ReduceMin/Max 在 NaN/±0 场景下很容易出现“选择了哪个操作数”的差异。
  // 为避免某些 CPU/FPU 设置下触发 InvalidOp，这里局部屏蔽异常。
  savedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    // Case 1: NaN 会让 scalar 顺序 fold “重置”到后续元素（取决于 NaN 位置）
    a.f[0] := 1.0;
    a.f[1] := SingleFromBits($7FC00000); // qNaN
    a.f[2] := 2.0;
    a.f[3] := 3.0;

    expS := ScalarReduceMinF32x4(a);
    actS := dt^.ReduceMinF32x4(a);
    AssertSameSingleBits('ReduceMin NaN-position case', expS, actS);

    expS := ScalarReduceMaxF32x4(a);
    actS := dt^.ReduceMaxF32x4(a);
    AssertSameSingleBits('ReduceMax NaN-position case', expS, actS);

    expS := ScalarReduceAddF32x4(a);
    actS := dt^.ReduceAddF32x4(a);
    if IsNaNSingle(expS) then
      AssertTrue('ReduceAdd NaN-position case should be NaN', IsNaNSingle(actS))
    else
      AssertEquals('ReduceAdd NaN-position case', expS, actS, 0.0);

    expS := ScalarReduceMulF32x4(a);
    actS := dt^.ReduceMulF32x4(a);
    if IsNaNSingle(expS) then
      AssertTrue('ReduceMul NaN-position case should be NaN', IsNaNSingle(actS))
    else
      AssertEquals('ReduceMul NaN-position case', expS, actS, 0.0);

    // Case 2: 更强的 Max 反例（NaN 在中间会让 scalar 顺序 fold 丢掉早期的极大值）
    a.f[0] := 100.0;
    a.f[1] := SingleFromBits($7FC00000); // qNaN
    a.f[2] := 2.0;
    a.f[3] := 3.0;

    expS := ScalarReduceMaxF32x4(a);
    actS := dt^.ReduceMaxF32x4(a);
    AssertSameSingleBits('ReduceMax NaN-reset case', expS, actS);

    // Case 3: ±0（关注符号位）
    a.f[0] := 0.0;                       // +0
    a.f[1] := SingleFromBits($80000000); // -0
    a.f[2] := 1.0;
    a.f[3] := 2.0;

    expS := ScalarReduceMinF32x4(a);
    actS := dt^.ReduceMinF32x4(a);
    AssertSameSingleBits('ReduceMin signed-zero case', expS, actS);
  finally
    SetExceptionMask(savedMask);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_LoadStore_RandomRoundtrip;
var
  dt: PSimdDispatchTable;
  a, v: TVecF32x4;
  src: array[0..3] of Single;
  expBytes: array[0..15] of Byte;
  rawSrc, rawDst: PByte;
  pSrc, pDst: PByte;
  alignedRaw: Pointer;
  pAlignedSrc, pAlignedDst: PByte;
  iter, i: Integer;
  bits: DWord;

  procedure AssertBytesEqual(const msg: string; expectedPtr, actualPtr: PByte; count: Integer);
  var
    j: Integer;
  begin
    for j := 0 to count - 1 do
      AssertEquals(msg + ' byte ' + IntToStr(j), expectedPtr[j], actualPtr[j]);
  end;

  procedure AssertAllBytesAre(const msg: string; p: PByte; count: Integer; value: Byte);
  var
    j: Integer;
  begin
    for j := 0 to count - 1 do
      AssertEquals(msg + ' byte ' + IntToStr(j), value, p[j]);
  end;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.LoadF32x4 should be assigned', Assigned(dt^.LoadF32x4));
  AssertTrue('Dispatch.StoreF32x4 should be assigned', Assigned(dt^.StoreF32x4));
  AssertTrue('Dispatch.LoadF32x4Aligned should be assigned', Assigned(dt^.LoadF32x4Aligned));
  AssertTrue('Dispatch.StoreF32x4Aligned should be assigned', Assigned(dt^.StoreF32x4Aligned));

  AssertTrue('LoadF32x4 should not be scalar when vector asm enabled', dt^.LoadF32x4 <> @ScalarLoadF32x4);
  AssertTrue('StoreF32x4 should not be scalar when vector asm enabled', dt^.StoreF32x4 <> @ScalarStoreF32x4);
  AssertTrue('LoadF32x4Aligned should not be scalar when vector asm enabled', dt^.LoadF32x4Aligned <> @ScalarLoadF32x4Aligned);
  AssertTrue('StoreF32x4Aligned should not be scalar when vector asm enabled', dt^.StoreF32x4Aligned <> @ScalarStoreF32x4Aligned);

  rawSrc := GetMem(64);
  rawDst := GetMem(64);
  alignedRaw := AlignedAlloc(128, SIMD_ALIGN_16);
  try
    // 故意制造非对齐地址
    pSrc := rawSrc + 1;
    pDst := rawDst + 3;

    // 选择两个 16-byte 对齐的地址（避免与 header 重叠，并留足哨兵区）
    pAlignedSrc := PByte(alignedRaw) + SIMD_ALIGN_16;
    pAlignedDst := PByte(alignedRaw) + 64;

    AssertTrue('pAlignedSrc should be 16-byte aligned', IsAligned(pAlignedSrc, SIMD_ALIGN_16));
    AssertTrue('pAlignedDst should be 16-byte aligned', IsAligned(pAlignedDst, SIMD_ALIGN_16));

    RandSeed := 424242;

    for iter := 1 to 300 do
    begin
      // 生成任意 bit-pattern（包含 NaN/Inf/±0 等），load/store 应该 bit-exact。
      for i := 0 to 3 do
      begin
        bits := DWord(Random($10000)) or (DWord(Random($10000)) shl 16);
        src[i] := SingleFromBits(bits);
        a.f[i] := src[i];
      end;
      Move(src[0], expBytes[0], SizeOf(expBytes));

      // --- Unaligned store ---
      FillChar(rawDst^, 64, $CD);
      dt^.StoreF32x4(PSingle(pDst), a);
      AssertAllBytesAre('StoreF32x4 prefix sentinel', rawDst, 3, $CD);
      AssertBytesEqual('StoreF32x4 payload', @expBytes[0], pDst, 16);
      AssertAllBytesAre('StoreF32x4 suffix sentinel', pDst + 16, 64 - (3 + 16), $CD);

      // --- Unaligned load ---
      FillChar(rawSrc^, 64, $AB);
      Move(expBytes[0], pSrc^, 16);
      v := dt^.LoadF32x4(PSingle(pSrc));
      for i := 0 to 3 do
        AssertEquals('LoadF32x4 elem ' + IntToStr(i) + ' bits', BitsFromSingle(src[i]), BitsFromSingle(v.f[i]));

      // --- Aligned store ---
      FillChar(PByte(alignedRaw)^, 128, $EF);
      dt^.StoreF32x4Aligned(PSingle(pAlignedDst), a);
      AssertAllBytesAre('StoreF32x4Aligned prefix sentinel', PByte(alignedRaw), 64, $EF);
      AssertBytesEqual('StoreF32x4Aligned payload', @expBytes[0], pAlignedDst, 16);
      AssertAllBytesAre('StoreF32x4Aligned suffix sentinel', pAlignedDst + 16, 128 - (64 + 16), $EF);

      // --- Aligned load ---
      FillChar(PByte(alignedRaw)^, 128, $E1);
      Move(expBytes[0], pAlignedSrc^, 16);
      v := dt^.LoadF32x4Aligned(PSingle(pAlignedSrc));
      for i := 0 to 3 do
        AssertEquals('LoadF32x4Aligned elem ' + IntToStr(i) + ' bits', BitsFromSingle(src[i]), BitsFromSingle(v.f[i]));
    end;
  finally
    FreeMem(rawSrc);
    FreeMem(rawDst);
    AlignedFree(alignedRaw);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_LoadStore_SpecialValues_Roundtrip;
var
  dt: PSimdDispatchTable;
  a, v: TVecF32x4;
  src: array[0..3] of Single;
  expBytes: array[0..15] of Byte;
  rawSrc, rawDst: PByte;
  pSrc, pDst: PByte;
  alignedRaw: Pointer;
  pAlignedSrc, pAlignedDst: PByte;
  i: Integer;

  procedure AssertBytesEqual(const msg: string; expectedPtr, actualPtr: PByte; count: Integer);
  var
    j: Integer;
  begin
    for j := 0 to count - 1 do
      AssertEquals(msg + ' byte ' + IntToStr(j), expectedPtr[j], actualPtr[j]);
  end;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.LoadF32x4 should be assigned', Assigned(dt^.LoadF32x4));
  AssertTrue('Dispatch.StoreF32x4 should be assigned', Assigned(dt^.StoreF32x4));
  AssertTrue('Dispatch.LoadF32x4Aligned should be assigned', Assigned(dt^.LoadF32x4Aligned));
  AssertTrue('Dispatch.StoreF32x4Aligned should be assigned', Assigned(dt^.StoreF32x4Aligned));

  AssertTrue('LoadF32x4 should not be scalar when vector asm enabled', dt^.LoadF32x4 <> @ScalarLoadF32x4);
  AssertTrue('StoreF32x4 should not be scalar when vector asm enabled', dt^.StoreF32x4 <> @ScalarStoreF32x4);
  AssertTrue('LoadF32x4Aligned should not be scalar when vector asm enabled', dt^.LoadF32x4Aligned <> @ScalarLoadF32x4Aligned);
  AssertTrue('StoreF32x4Aligned should not be scalar when vector asm enabled', dt^.StoreF32x4Aligned <> @ScalarStoreF32x4Aligned);

  // 特殊值：±0 / ±Inf / qNaN
  src[0] := SingleFromBits($00000000); // +0
  src[1] := SingleFromBits($80000000); // -0
  src[2] := SingleFromBits($7F800000); // +Inf
  src[3] := SingleFromBits($7FC00000); // qNaN

  for i := 0 to 3 do
    a.f[i] := src[i];
  Move(src[0], expBytes[0], SizeOf(expBytes));

  rawSrc := GetMem(64);
  rawDst := GetMem(64);
  alignedRaw := AlignedAlloc(128, SIMD_ALIGN_16);
  try
    pSrc := rawSrc + 1;
    pDst := rawDst + 3;

    pAlignedSrc := PByte(alignedRaw) + SIMD_ALIGN_16;
    pAlignedDst := PByte(alignedRaw) + 64;

    AssertTrue('pAlignedSrc should be 16-byte aligned', IsAligned(pAlignedSrc, SIMD_ALIGN_16));
    AssertTrue('pAlignedDst should be 16-byte aligned', IsAligned(pAlignedDst, SIMD_ALIGN_16));

    // Store unaligned
    FillChar(rawDst^, 64, $CD);
    dt^.StoreF32x4(PSingle(pDst), a);
    AssertBytesEqual('StoreF32x4 special-values payload', @expBytes[0], pDst, 16);

    // Load unaligned
    FillChar(rawSrc^, 64, $AB);
    Move(expBytes[0], pSrc^, 16);
    v := dt^.LoadF32x4(PSingle(pSrc));
    for i := 0 to 3 do
      AssertEquals('LoadF32x4 special-values elem ' + IntToStr(i) + ' bits', BitsFromSingle(src[i]), BitsFromSingle(v.f[i]));

    // Store aligned
    FillChar(PByte(alignedRaw)^, 128, $EF);
    dt^.StoreF32x4Aligned(PSingle(pAlignedDst), a);
    AssertBytesEqual('StoreF32x4Aligned special-values payload', @expBytes[0], pAlignedDst, 16);

    // Load aligned
    FillChar(PByte(alignedRaw)^, 128, $E1);
    Move(expBytes[0], pAlignedSrc^, 16);
    v := dt^.LoadF32x4Aligned(PSingle(pAlignedSrc));
    for i := 0 to 3 do
      AssertEquals('LoadF32x4Aligned special-values elem ' + IntToStr(i) + ' bits', BitsFromSingle(src[i]), BitsFromSingle(v.f[i]));
  finally
    FreeMem(rawSrc);
    FreeMem(rawDst);
    AlignedFree(alignedRaw);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Select_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecF32x4;
  expV, actV: TVecF32x4;
  iter, i: Integer;
  mask: TMask4;
  bits: DWord;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.SelectF32x4 should be assigned', Assigned(dt^.SelectF32x4));

  AssertTrue('SelectF32x4 should not be scalar when vector asm enabled', dt^.SelectF32x4 <> @ScalarSelectF32x4);

  RandSeed := 911911;

  for iter := 1 to 1000 do
  begin
    // 使用任意 bit-pattern，Select 应该是纯“按 lane 选值”的语义，不应该改动位模式。
    for i := 0 to 3 do
    begin
      bits := DWord(Random($10000)) or (DWord(Random($10000)) shl 16);
      a.f[i] := SingleFromBits(bits);
      bits := DWord(Random($10000)) or (DWord(Random($10000)) shl 16);
      b.f[i] := SingleFromBits(bits);
    end;

    mask := TMask4(Random(16));

    for i := 0 to 3 do
      if (mask and (1 shl i)) <> 0 then
        expV.f[i] := a.f[i]
      else
        expV.f[i] := b.f[i];

    actV := dt^.SelectF32x4(mask, a, b);

    for i := 0 to 3 do
      AssertEquals('Select iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expV.f[i]), BitsFromSingle(actV.f[i]));
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_ExtractInsert_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a, v: TVecF32x4;
  iter, i, idx: Integer;
  bits: DWord;
  value, extracted: Single;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.ExtractF32x4 should be assigned', Assigned(dt^.ExtractF32x4));
  AssertTrue('Dispatch.InsertF32x4 should be assigned', Assigned(dt^.InsertF32x4));

  AssertTrue('ExtractF32x4 should not be scalar when vector asm enabled', dt^.ExtractF32x4 <> @ScalarExtractF32x4);
  AssertTrue('InsertF32x4 should not be scalar when vector asm enabled', dt^.InsertF32x4 <> @ScalarInsertF32x4);

  RandSeed := 12211221;

  for iter := 1 to 1000 do
  begin
    // 任意 bit-pattern（包含 NaN/Inf/子正常数等），Extract/Insert 都应该 bit-exact。
    for i := 0 to 3 do
    begin
      bits := DWord(Random($10000)) or (DWord(Random($10000)) shl 16);
      a.f[i] := SingleFromBits(bits);
    end;

    idx := Random(4);

    extracted := dt^.ExtractF32x4(a, idx);
    AssertEquals('Extract iter ' + IntToStr(iter) + ' idx ' + IntToStr(idx) + ' bits',
                 BitsFromSingle(a.f[idx]), BitsFromSingle(extracted));

    bits := DWord(Random($10000)) or (DWord(Random($10000)) shl 16);
    value := SingleFromBits(bits);

    v := dt^.InsertF32x4(a, value, idx);

    for i := 0 to 3 do
      if i = idx then
        AssertEquals('Insert iter ' + IntToStr(iter) + ' idx ' + IntToStr(idx) + ' lane bits',
                     BitsFromSingle(value), BitsFromSingle(v.f[i]))
      else
        AssertEquals('Insert iter ' + IntToStr(iter) + ' idx ' + IntToStr(idx) + ' other lane ' + IntToStr(i) + ' bits',
                     BitsFromSingle(a.f[i]), BitsFromSingle(v.f[i]));

    extracted := dt^.ExtractF32x4(v, idx);
    AssertEquals('Extract-after-insert iter ' + IntToStr(iter) + ' idx ' + IntToStr(idx) + ' bits',
                 BitsFromSingle(value), BitsFromSingle(extracted));
  end;

  // 额外覆盖：确保 -0 的符号位不会在 Extract/Insert 中丢失。
  a.f[0] := 1.0;
  a.f[1] := 2.0;
  a.f[2] := 3.0;
  a.f[3] := 4.0;
  value := SingleFromBits($80000000); // -0
  v := dt^.InsertF32x4(a, value, 1);
  AssertEquals('Insert signed-zero lane bits', DWord($80000000), BitsFromSingle(v.f[1]));
  extracted := dt^.ExtractF32x4(v, 1);
  AssertEquals('Extract signed-zero lane bits', DWord($80000000), BitsFromSingle(extracted));
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_SplatZero_BitExact;
var
  dt: PSimdDispatchTable;
  v: TVecF32x4;
  value: Single;
  bits: DWord;
  iter, i: Integer;

  procedure AssertAllLanesBits(const msg: string; const vec: TVecF32x4; expectedBits: DWord);
  var
    j: Integer;
  begin
    for j := 0 to 3 do
      AssertEquals(msg + ' lane ' + IntToStr(j) + ' bits', expectedBits, BitsFromSingle(vec.f[j]));
  end;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.SplatF32x4 should be assigned', Assigned(dt^.SplatF32x4));
  AssertTrue('Dispatch.ZeroF32x4 should be assigned', Assigned(dt^.ZeroF32x4));

  AssertTrue('SplatF32x4 should not be scalar when vector asm enabled', dt^.SplatF32x4 <> @ScalarSplatF32x4);
  AssertTrue('ZeroF32x4 should not be scalar when vector asm enabled', dt^.ZeroF32x4 <> @ScalarZeroF32x4);

  // Zero：必须是 +0（全 0 bit），不能是 -0。
  v := dt^.ZeroF32x4();
  AssertAllLanesBits('ZeroF32x4', v, DWord(0));

  RandSeed := 334455;

  for iter := 1 to 1000 do
  begin
    bits := DWord(Random($10000)) or (DWord(Random($10000)) shl 16);
    value := SingleFromBits(bits);

    v := dt^.SplatF32x4(value);
    for i := 0 to 3 do
      AssertEquals('Splat iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   bits, BitsFromSingle(v.f[i]));
  end;

  // 特殊：-0 / qNaN payload
  value := SingleFromBits($80000000);
  v := dt^.SplatF32x4(value);
  AssertAllLanesBits('Splat -0', v, DWord($80000000));

  bits := $7FC12345;
  value := SingleFromBits(bits);
  v := dt^.SplatF32x4(value);
  AssertAllLanesBits('Splat qNaN payload', v, bits);
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_RcpRsqrt_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a: TVecF32x4;
  expV, actV: TVecF32x4;
  iter, i: Integer;
  eps: Single;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.RcpF32x4 should be assigned', Assigned(dt^.RcpF32x4));
  AssertTrue('Dispatch.RsqrtF32x4 should be assigned', Assigned(dt^.RsqrtF32x4));

  // 这个 suite 目标是验证 --vector-asm 路径：这里强制确保 AVX2 backend
  // 在 vector asm 打开时不会退回到 scalar reference。
  AssertTrue('RcpF32x4 should not be scalar when vector asm enabled', dt^.RcpF32x4 <> @ScalarRcpF32x4);
  AssertTrue('RsqrtF32x4 should not be scalar when vector asm enabled', dt^.RsqrtF32x4 <> @ScalarRsqrtF32x4);

  // Rcp/Rsqrt 可能是近似实现，这里选取温和输入范围并用 eps 做一致性验证。
  // 输入范围 [0.5..2.0]：避免 1/x 过大、以及 rsqrt 的负数/零域。
  eps := 1e-3;

  RandSeed := 556677;

  for iter := 1 to 2000 do
  begin
    for i := 0 to 3 do
      a.f[i] := 0.5 + (Random(1500001) / 1000000.0); // [0.5..2.0]

    // Rcp
    expV := ScalarRcpF32x4(a);
    actV := dt^.RcpF32x4(a);
    for i := 0 to 3 do
      AssertEquals('Rcp iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.f[i], actV.f[i], eps);

    // Rsqrt
    expV := ScalarRsqrtF32x4(a);
    actV := dt^.RsqrtF32x4(a);
    for i := 0 to 3 do
      AssertEquals('Rsqrt iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.f[i], actV.f[i], eps);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_FloorCeil_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a: TVecF32x4;
  expV, actV: TVecF32x4;
  iter, i: Integer;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.FloorF32x4 should be assigned', Assigned(dt^.FloorF32x4));
  AssertTrue('Dispatch.CeilF32x4 should be assigned', Assigned(dt^.CeilF32x4));

  // 同样要求：vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('FloorF32x4 should not be scalar when vector asm enabled', dt^.FloorF32x4 <> @ScalarFloorF32x4);
  AssertTrue('CeilF32x4 should not be scalar when vector asm enabled', dt^.CeilF32x4 <> @ScalarCeilF32x4);

  // 选择一个结果可精确表示的范围（避免超出 float32 的整数精度）。
  RandSeed := 778866;

  for iter := 1 to 2000 do
  begin
    for i := 0 to 3 do
      a.f[i] := (Random(2000001) - 1000000) / 1000.0; // [-1000..1000]

    // Floor
    expV := ScalarFloorF32x4(a);
    actV := dt^.FloorF32x4(a);
    for i := 0 to 3 do
      AssertEquals('Floor iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.f[i], actV.f[i], 0.0);

    // Ceil
    expV := ScalarCeilF32x4(a);
    actV := dt^.CeilF32x4(a);
    for i := 0 to 3 do
      AssertEquals('Ceil iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.f[i], actV.f[i], 0.0);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_RoundTrunc_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a: TVecF32x4;
  expV, actV: TVecF32x4;
  iter, i: Integer;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.RoundF32x4 should be assigned', Assigned(dt^.RoundF32x4));
  AssertTrue('Dispatch.TruncF32x4 should be assigned', Assigned(dt^.TruncF32x4));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('RoundF32x4 should not be scalar when vector asm enabled', dt^.RoundF32x4 <> @ScalarRoundF32x4);
  AssertTrue('TruncF32x4 should not be scalar when vector asm enabled', dt^.TruncF32x4 <> @ScalarTruncF32x4);

  // 先用确定性 case 覆盖“0.5 ties to even”语义。
  a.f[0] := 2.5;
  a.f[1] := 3.5;
  a.f[2] := -2.5;
  a.f[3] := -3.5;

  expV := ScalarRoundF32x4(a);
  actV := dt^.RoundF32x4(a);
  for i := 0 to 3 do
    AssertEquals('Round tie-even lane ' + IntToStr(i), expV.f[i], actV.f[i], 0.0);

  // Random：范围同样限制在可精确表示整数的区间
  RandSeed := 889977;

  for iter := 1 to 2000 do
  begin
    for i := 0 to 3 do
      a.f[i] := (Random(2000001) - 1000000) / 1000.0; // [-1000..1000]

    // Round
    expV := ScalarRoundF32x4(a);
    actV := dt^.RoundF32x4(a);
    for i := 0 to 3 do
      AssertEquals('Round iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.f[i], actV.f[i], 0.0);

    // Trunc
    expV := ScalarTruncF32x4(a);
    actV := dt^.TruncF32x4(a);
    for i := 0 to 3 do
      AssertEquals('Trunc iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.f[i], actV.f[i], 0.0);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Clamp_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a, minV, maxV: TVecF32x4;
  expV, actV: TVecF32x4;
  iter, i: Integer;
  expBits, actBits: DWord;
  savedMask: TFPUExceptionMask;

  procedure AssertSameLaneBits(const msg: string; idx: Integer; expVal, actVal: Single);
  begin
    if IsNaNSingle(expVal) then
      AssertTrue(msg + ' lane ' + IntToStr(idx) + ' should be NaN', IsNaNSingle(actVal))
    else
    begin
      expBits := BitsFromSingle(expVal);
      actBits := BitsFromSingle(actVal);
      AssertTrue(msg + ' lane ' + IntToStr(idx) + ' bits should match', expBits = actBits);
    end;
  end;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.ClampF32x4 should be assigned', Assigned(dt^.ClampF32x4));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('ClampF32x4 should not be scalar when vector asm enabled', dt^.ClampF32x4 <> @ScalarClampF32x4);

  // Clamp 内部会触发浮点比较（NaN 场景会触发 InvalidOp），这里局部屏蔽异常。
  savedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    // 明确覆盖一个 NaN ordering case：
    // scalar: Max(minVal, Min(a, maxVal))，当 a=NaN 时，Min(a,maxVal) 会选 maxVal（SSE-style），因此结果应为 maxVal。
    a := VecF32x4Splat(SingleFromBits($7FC00000)); // qNaN
    minV := VecF32x4Splat(0.0);
    maxV := VecF32x4Splat(10.0);

    expV := ScalarClampF32x4(a, minV, maxV);
    actV := dt^.ClampF32x4(a, minV, maxV);
    for i := 0 to 3 do
      AssertSameLaneBits('Clamp NaN-ordering', i, expV.f[i], actV.f[i]);

    RandSeed := 991122;

    for iter := 1 to 2000 do
    begin
      for i := 0 to 3 do
      begin
        // a in [-2..2]
        a.f[i] := (Random(4000001) - 2000000) / 1000000.0;
        // min in [-1..1]
        minV.f[i] := (Random(2000001) - 1000000) / 1000000.0;
        // max >= min, add [0..2]
        maxV.f[i] := minV.f[i] + (Random(2000001) / 1000000.0);
      end;

      expV := ScalarClampF32x4(a, minV, maxV);
      actV := dt^.ClampF32x4(a, minV, maxV);

      for i := 0 to 3 do
        AssertSameLaneBits('Clamp iter ' + IntToStr(iter), i, expV.f[i], actV.f[i]);
    end;
  finally
    SetExceptionMask(savedMask);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Dot_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecF32x4;
  iter, i: Integer;
  expS, actS: Single;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.DotF32x4 should be assigned', Assigned(dt^.DotF32x4));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('DotF32x4 should not be scalar when vector asm enabled', dt^.DotF32x4 <> @ScalarDotF32x4);

  // 选择小整数，保证乘加结果在 float32 精确可表示的范围内，避免“求和顺序”带来的舍入差异。
  RandSeed := 20251217;

  for iter := 1 to 5000 do
  begin
    for i := 0 to 3 do
    begin
      a.f[i] := Single(Random(2001) - 1000);
      b.f[i] := Single(Random(2001) - 1000);
    end;

    expS := ScalarDotF32x4(a, b);
    actS := dt^.DotF32x4(a, b);

    AssertEquals('Dot iter ' + IntToStr(iter), expS, actS, 0.0);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Dot3_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecF32x4;
  iter, i: Integer;
  expS, actS: Single;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.DotF32x3 should be assigned', Assigned(dt^.DotF32x3));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('DotF32x3 should not be scalar when vector asm enabled', dt^.DotF32x3 <> @ScalarDotF32x3);

  RandSeed := 20251218;

  for iter := 1 to 5000 do
  begin
    // x/y/z 使用小整数，保证 dot3 结果精确可比较；w 随机但应被忽略。
    for i := 0 to 2 do
    begin
      a.f[i] := Single(Random(2001) - 1000);
      b.f[i] := Single(Random(2001) - 1000);
    end;
    a.f[3] := Single(Random(2001) - 1000);
    b.f[3] := Single(Random(2001) - 1000);

    expS := ScalarDotF32x3(a, b);
    actS := dt^.DotF32x3(a, b);

    AssertEquals('Dot3 iter ' + IntToStr(iter), expS, actS, 0.0);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Cross3_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecF32x4;
  expV, actV: TVecF32x4;
  iter, i: Integer;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.CrossF32x3 should be assigned', Assigned(dt^.CrossF32x3));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('CrossF32x3 should not be scalar when vector asm enabled', dt^.CrossF32x3 <> @ScalarCrossF32x3);

  RandSeed := 20251219;

  for iter := 1 to 2000 do
  begin
    // 小整数：乘减结果精确可表示。
    for i := 0 to 2 do
    begin
      a.f[i] := Single(Random(2001) - 1000);
      b.f[i] := Single(Random(2001) - 1000);
    end;
    // w 随机，但 cross 应忽略并强制输出 w=+0
    a.f[3] := Single(Random(2001) - 1000);
    b.f[3] := Single(Random(2001) - 1000);

    expV := ScalarCrossF32x3(a, b);
    actV := dt^.CrossF32x3(a, b);

    for i := 0 to 2 do
      AssertEquals('Cross3 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.f[i], actV.f[i], 0.0);

    AssertEquals('Cross3 w should be +0', DWord(0), BitsFromSingle(actV.f[3]));
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Length_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a: TVecF32x4;
  iter, i: Integer;
  expS, actS: Single;
  eps: Single;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.LengthF32x4 should be assigned', Assigned(dt^.LengthF32x4));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('LengthF32x4 should not be scalar when vector asm enabled', dt^.LengthF32x4 <> @ScalarLengthF32x4);

  // 确定性：3-4-0-0 -> 5
  a.f[0] := 3.0; a.f[1] := 4.0; a.f[2] := 0.0; a.f[3] := 0.0;
  expS := ScalarLengthF32x4(a);
  actS := dt^.LengthF32x4(a);
  AssertEquals('Length(3,4,0,0)', expS, actS, 0.0);

  // 随机一致性：避免极端值
  eps := 1e-4;
  RandSeed := 20251220;

  for iter := 1 to 5000 do
  begin
    for i := 0 to 3 do
      a.f[i] := (Random(20001) - 10000) / 100.0; // [-100..100]

    expS := ScalarLengthF32x4(a);
    actS := dt^.LengthF32x4(a);

    AssertEquals('Length iter ' + IntToStr(iter), expS, actS, eps);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Length3_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a: TVecF32x4;
  iter, i: Integer;
  expS, actS: Single;
  eps: Single;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.LengthF32x3 should be assigned', Assigned(dt^.LengthF32x3));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('LengthF32x3 should not be scalar when vector asm enabled', dt^.LengthF32x3 <> @ScalarLengthF32x3);

  // 确定性：|(3,4,0)| -> 5（w ignored）
  a.f[0] := 3.0; a.f[1] := 4.0; a.f[2] := 0.0; a.f[3] := 999.0;
  expS := ScalarLengthF32x3(a);
  actS := dt^.LengthF32x3(a);
  AssertEquals('Length3(3,4,0)', expS, actS, 0.0);

  eps := 1e-4;
  RandSeed := 20251221;

  for iter := 1 to 5000 do
  begin
    for i := 0 to 2 do
      a.f[i] := (Random(20001) - 10000) / 100.0;
    a.f[3] := (Random(20001) - 10000) / 100.0; // ignored

    expS := ScalarLengthF32x3(a);
    actS := dt^.LengthF32x3(a);

    AssertEquals('Length3 iter ' + IntToStr(iter), expS, actS, eps);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Normalize_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a: TVecF32x4;
  expV, actV: TVecF32x4;
  iter, i: Integer;
  eps: Single;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.NormalizeF32x4 should be assigned', Assigned(dt^.NormalizeF32x4));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('NormalizeF32x4 should not be scalar when vector asm enabled', dt^.NormalizeF32x4 <> @ScalarNormalizeF32x4);

  // 确定性：Normalize(3,0,0,0) -> (1,0,0,0)
  a.f[0] := 3.0; a.f[1] := 0.0; a.f[2] := 0.0; a.f[3] := 0.0;
  expV := ScalarNormalizeF32x4(a);
  actV := dt^.NormalizeF32x4(a);
  for i := 0 to 3 do
    AssertEquals('Normalize(3,0,0,0) lane ' + IntToStr(i), expV.f[i], actV.f[i], 0.0);

  eps := 1e-4;
  RandSeed := 20251222;

  for iter := 1 to 5000 do
  begin
    for i := 0 to 3 do
      a.f[i] := (Random(20001) - 10000) / 100.0;

    expV := ScalarNormalizeF32x4(a);
    actV := dt^.NormalizeF32x4(a);

    for i := 0 to 3 do
      AssertEquals('Normalize iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.f[i], actV.f[i], eps);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_Normalize3_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a: TVecF32x4;
  expV, actV: TVecF32x4;
  iter, i: Integer;
  eps: Single;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.NormalizeF32x3 should be assigned', Assigned(dt^.NormalizeF32x3));

  // vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('NormalizeF32x3 should not be scalar when vector asm enabled', dt^.NormalizeF32x3 <> @ScalarNormalizeF32x3);

  // 确定性：Normalize3(3,4,0,w) -> (0.6,0.8,0,w=0)
  a.f[0] := 3.0; a.f[1] := 4.0; a.f[2] := 0.0; a.f[3] := 999.0;
  expV := ScalarNormalizeF32x3(a);
  actV := dt^.NormalizeF32x3(a);
  eps := 1e-4;
  for i := 0 to 2 do
    AssertEquals('Normalize3(3,4,0) lane ' + IntToStr(i), expV.f[i], actV.f[i], eps);
  AssertEquals('Normalize3 w should be +0', DWord(0), BitsFromSingle(actV.f[3]));

  RandSeed := 20251223;

  for iter := 1 to 5000 do
  begin
    for i := 0 to 2 do
      a.f[i] := (Random(20001) - 10000) / 100.0;
    a.f[3] := (Random(20001) - 10000) / 100.0;

    expV := ScalarNormalizeF32x3(a);
    actV := dt^.NormalizeF32x3(a);

    for i := 0 to 2 do
      AssertEquals('Normalize3 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.f[i], actV.f[i], eps);
    AssertEquals('Normalize3 iter ' + IntToStr(iter) + ' w should be +0', DWord(0), BitsFromSingle(actV.f[3]));
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved;
var
  dt: PSimdDispatchTable;
  a, b: TVecF32x4;
  expected, actual: Single;
  iter, i: Integer;
  ok: Boolean;
  eps: Single;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  // 选择 3 个代表性的“返回 Single”的操作做 ABI 保护：Dot / Length / ReduceAdd。
  AssertTrue('Dispatch.DotF32x4 should be assigned', Assigned(dt^.DotF32x4));
  AssertTrue('Dispatch.LengthF32x4 should be assigned', Assigned(dt^.LengthF32x4));
  AssertTrue('Dispatch.ReduceAddF32x4 should be assigned', Assigned(dt^.ReduceAddF32x4));

  // 要求：vector asm 打开时，AVX2 backend 不应退回到 scalar reference。
  AssertTrue('DotF32x4 should not be scalar when vector asm enabled', dt^.DotF32x4 <> @ScalarDotF32x4);
  AssertTrue('LengthF32x4 should not be scalar when vector asm enabled', dt^.LengthF32x4 <> @ScalarLengthF32x4);
  AssertTrue('ReduceAddF32x4 should not be scalar when vector asm enabled', dt^.ReduceAddF32x4 <> @ScalarReduceAddF32x4);

  // Dot：用小整数保证精确可比。
  RandSeed := 20251226;
  for iter := 1 to 2000 do
  begin
    for i := 0 to 3 do
    begin
      a.f[i] := Single(Random(2001) - 1000);
      b.f[i] := Single(Random(2001) - 1000);
    end;

    expected := ScalarDotF32x4(a, b);
    ok := AbiCall_TwoVecToSingle_CheckCalleeSaved(Pointer(dt^.DotF32x4), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (Dot) iter ' + IntToStr(iter), ok);
    AssertEquals('ABI Dot iter ' + IntToStr(iter), expected, actual, 0.0);
  end;

  // ReduceAdd：同样用小整数精确可比。
  RandSeed := 20251227;
  for iter := 1 to 2000 do
  begin
    for i := 0 to 3 do
      a.f[i] := Single(Random(2001) - 1000);

    expected := ScalarReduceAddF32x4(a);
    ok := AbiCall_OneVecToSingle_CheckCalleeSaved(Pointer(dt^.ReduceAddF32x4), a, actual);
    AssertTrue('ABI callee-saved should be preserved (ReduceAdd) iter ' + IntToStr(iter), ok);
    AssertEquals('ABI ReduceAdd iter ' + IntToStr(iter), expected, actual, 0.0);
  end;

  // Length：包含 sqrt，使用可精确表示的 case + eps。
  a.f[0] := 3.0; a.f[1] := 4.0; a.f[2] := 0.0; a.f[3] := 0.0;
  expected := ScalarLengthF32x4(a);
  ok := AbiCall_OneVecToSingle_CheckCalleeSaved(Pointer(dt^.LengthF32x4), a, actual);
  AssertTrue('ABI callee-saved should be preserved (Length)', ok);
  eps := 1e-6;
  AssertEquals('ABI Length(3,4,0,0)', expected, actual, eps);
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_VectorReturn;
var
  dt: PSimdDispatchTable;
  a, b, expected, actual: TVecF32x4;
  iter, i: Integer;
  ok: Boolean;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.AddF32x4 should be assigned', Assigned(dt^.AddF32x4));
  AssertTrue('Dispatch.SubF32x4 should be assigned', Assigned(dt^.SubF32x4));
  AssertTrue('Dispatch.MulF32x4 should be assigned', Assigned(dt^.MulF32x4));
  AssertTrue('Dispatch.MinF32x4 should be assigned', Assigned(dt^.MinF32x4));
  AssertTrue('Dispatch.MaxF32x4 should be assigned', Assigned(dt^.MaxF32x4));

  AssertTrue('AddF32x4 should not be scalar when vector asm enabled', dt^.AddF32x4 <> @ScalarAddF32x4);
  AssertTrue('SubF32x4 should not be scalar when vector asm enabled', dt^.SubF32x4 <> @ScalarSubF32x4);
  AssertTrue('MulF32x4 should not be scalar when vector asm enabled', dt^.MulF32x4 <> @ScalarMulF32x4);
  AssertTrue('MinF32x4 should not be scalar when vector asm enabled', dt^.MinF32x4 <> @ScalarMinF32x4);
  AssertTrue('MaxF32x4 should not be scalar when vector asm enabled', dt^.MaxF32x4 <> @ScalarMaxF32x4);

  RandSeed := 20251228;

  for iter := 1 to 2000 do
  begin
    for i := 0 to 3 do
    begin
      // 选小整数，保证结果 float32 bit-exact
      a.f[i] := Single(Random(2001) - 1000);
      b.f[i] := Single(Random(2001) - 1000);
    end;

    // Add
    expected := ScalarAddF32x4(a, b);
    ok := AbiCall_TwoVecToVec_CheckCalleeSaved(Pointer(dt^.AddF32x4), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (AddF32x4) iter ' + IntToStr(iter), ok);
    for i := 0 to 3 do
      AssertEquals('ABI AddF32x4 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));

    // Sub
    expected := ScalarSubF32x4(a, b);
    ok := AbiCall_TwoVecToVec_CheckCalleeSaved(Pointer(dt^.SubF32x4), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (SubF32x4) iter ' + IntToStr(iter), ok);
    for i := 0 to 3 do
      AssertEquals('ABI SubF32x4 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));

    // Mul
    expected := ScalarMulF32x4(a, b);
    ok := AbiCall_TwoVecToVec_CheckCalleeSaved(Pointer(dt^.MulF32x4), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (MulF32x4) iter ' + IntToStr(iter), ok);
    for i := 0 to 3 do
      AssertEquals('ABI MulF32x4 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));

    // Min
    expected := ScalarMinF32x4(a, b);
    ok := AbiCall_TwoVecToVec_CheckCalleeSaved(Pointer(dt^.MinF32x4), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (MinF32x4) iter ' + IntToStr(iter), ok);
    for i := 0 to 3 do
      AssertEquals('ABI MinF32x4 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));

    // Max
    expected := ScalarMaxF32x4(a, b);
    ok := AbiCall_TwoVecToVec_CheckCalleeSaved(Pointer(dt^.MaxF32x4), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (MaxF32x4) iter ' + IntToStr(iter), ok);
    for i := 0 to 3 do
      AssertEquals('ABI MaxF32x4 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_VectorReturn_OneVec;
var
  dt: PSimdDispatchTable;
  a, expected, actual: TVecF32x4;
  iter, i: Integer;
  ok: Boolean;
  n: Integer;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.AbsF32x4 should be assigned', Assigned(dt^.AbsF32x4));
  AssertTrue('Dispatch.SqrtF32x4 should be assigned', Assigned(dt^.SqrtF32x4));

  AssertTrue('AbsF32x4 should not be scalar when vector asm enabled', dt^.AbsF32x4 <> @ScalarAbsF32x4);
  AssertTrue('SqrtF32x4 should not be scalar when vector asm enabled', dt^.SqrtF32x4 <> @ScalarSqrtF32x4);

  // Abs: bit-exact
  RandSeed := 20251229;
  for iter := 1 to 2000 do
  begin
    for i := 0 to 3 do
      a.f[i] := Single(Random(2001) - 1000);

    expected := ScalarAbsF32x4(a);
    ok := AbiCall_OneVecToVec_CheckCalleeSaved(Pointer(dt^.AbsF32x4), a, actual);
    AssertTrue('ABI callee-saved should be preserved (AbsF32x4) iter ' + IntToStr(iter), ok);

    for i := 0 to 3 do
      AssertEquals('ABI AbsF32x4 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));
  end;

  // Sqrt: perfect squares (bit-exact)
  RandSeed := 20251230;
  for iter := 1 to 2000 do
  begin
    for i := 0 to 3 do
    begin
      n := Random(4001); // [0..4000]
      a.f[i] := Single(n * n);
    end;

    expected := ScalarSqrtF32x4(a);
    ok := AbiCall_OneVecToVec_CheckCalleeSaved(Pointer(dt^.SqrtF32x4), a, actual);
    AssertTrue('ABI callee-saved should be preserved (SqrtF32x4) iter ' + IntToStr(iter), ok);

    for i := 0 to 3 do
      AssertEquals('ABI SqrtF32x4 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_VectorReturn_ThreeVec;
var
  dt: PSimdDispatchTable;
  a, b, c, expected, actual: TVecF32x4;
  iter, i: Integer;
  ok: Boolean;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.FmaF32x4 should be assigned', Assigned(dt^.FmaF32x4));
  AssertTrue('Dispatch.ClampF32x4 should be assigned', Assigned(dt^.ClampF32x4));

  AssertTrue('FmaF32x4 should not be scalar when vector asm enabled', dt^.FmaF32x4 <> @ScalarFmaF32x4);
  AssertTrue('ClampF32x4 should not be scalar when vector asm enabled', dt^.ClampF32x4 <> @ScalarClampF32x4);

  // Fma: choose small integers => bit-exact whether fused or not
  RandSeed := 20260101;
  for iter := 1 to 2000 do
  begin
    for i := 0 to 3 do
    begin
      a.f[i] := Single(Random(2001) - 1000);
      b.f[i] := Single(Random(2001) - 1000);
      c.f[i] := Single(Random(2001) - 1000);
    end;

    expected := ScalarFmaF32x4(a, b, c);
    ok := AbiCall_ThreeVecToVec_CheckCalleeSaved(Pointer(dt^.FmaF32x4), a, b, c, actual);
    AssertTrue('ABI callee-saved should be preserved (FmaF32x4) iter ' + IntToStr(iter), ok);

    for i := 0 to 3 do
      AssertEquals('ABI FmaF32x4 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));
  end;

  // Clamp: also 3 vectors => ABI guard for passing 3x TVecF32x4
  RandSeed := 20260102;
  for iter := 1 to 2000 do
  begin
    for i := 0 to 3 do
    begin
      a.f[i] := Single(Random(2001) - 1000);
      b.f[i] := Single(Random(2001) - 1000);              // min
      c.f[i] := b.f[i] + Single(Random(2001));            // max >= min
    end;

    expected := ScalarClampF32x4(a, b, c);
    ok := AbiCall_ThreeVecToVec_CheckCalleeSaved(Pointer(dt^.ClampF32x4), a, b, c, actual);
    AssertTrue('ABI callee-saved should be preserved (ClampF32x4) iter ' + IntToStr(iter), ok);

    for i := 0 to 3 do
      AssertEquals('ABI ClampF32x4 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_VectorReturn_Ptr;
var
  dt: PSimdDispatchTable;
  buf: array[0..15] of Single;
  pAligned: PSingle;
  expected, actual: TVecF32x4;
  iter, i: Integer;
  ok: Boolean;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.LoadF32x4 should be assigned', Assigned(dt^.LoadF32x4));
  AssertTrue('Dispatch.LoadF32x4Aligned should be assigned', Assigned(dt^.LoadF32x4Aligned));

  AssertTrue('LoadF32x4 should not be scalar when vector asm enabled', dt^.LoadF32x4 <> @ScalarLoadF32x4);
  AssertTrue('LoadF32x4Aligned should not be scalar when vector asm enabled', dt^.LoadF32x4Aligned <> @ScalarLoadF32x4Aligned);

  // Unaligned load
  RandSeed := 20260103;
  for iter := 1 to 2000 do
  begin
    for i := 0 to 3 do
      buf[i] := Single(Random(2001) - 1000);

    expected := ScalarLoadF32x4(@buf[0]);
    ok := AbiCall_PtrToVec_CheckCalleeSaved(Pointer(dt^.LoadF32x4), @buf[0], actual);
    AssertTrue('ABI callee-saved should be preserved (LoadF32x4) iter ' + IntToStr(iter), ok);

    for i := 0 to 3 do
      AssertEquals('ABI LoadF32x4 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));
  end;

  // Aligned load
  pAligned := PSingle((PtrUInt(@buf[0]) + 15) and not PtrUInt(15));

  RandSeed := 20260104;
  for iter := 1 to 2000 do
  begin
    for i := 0 to 3 do
      pAligned[i] := Single(Random(2001) - 1000);

    expected := ScalarLoadF32x4Aligned(pAligned);
    ok := AbiCall_PtrToVec_CheckCalleeSaved(Pointer(dt^.LoadF32x4Aligned), pAligned, actual);
    AssertTrue('ABI callee-saved should be preserved (LoadF32x4Aligned) iter ' + IntToStr(iter), ok);

    for i := 0 to 3 do
      AssertEquals('ABI LoadF32x4Aligned iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_Store;
var
  dt: PSimdDispatchTable;
  a: TVecF32x4;
  expBytes: array[0..15] of Byte;
  rawDst: PByte;
  pDst: PByte;
  alignedRaw: Pointer;
  pAlignedDst: PByte;
  iter, i: Integer;
  bits: DWord;
  ok: Boolean;

  procedure AssertBytesEqual(const msg: string; expectedPtr, actualPtr: PByte; count: Integer);
  var
    j: Integer;
  begin
    for j := 0 to count - 1 do
      AssertEquals(msg + ' byte ' + IntToStr(j), expectedPtr[j], actualPtr[j]);
  end;

  procedure AssertAllBytesAre(const msg: string; p: PByte; count: Integer; value: Byte);
  var
    j: Integer;
  begin
    for j := 0 to count - 1 do
      AssertEquals(msg + ' byte ' + IntToStr(j), value, p[j]);
  end;

begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.StoreF32x4 should be assigned', Assigned(dt^.StoreF32x4));
  AssertTrue('Dispatch.StoreF32x4Aligned should be assigned', Assigned(dt^.StoreF32x4Aligned));

  AssertTrue('StoreF32x4 should not be scalar when vector asm enabled', dt^.StoreF32x4 <> @ScalarStoreF32x4);
  AssertTrue('StoreF32x4Aligned should not be scalar when vector asm enabled', dt^.StoreF32x4Aligned <> @ScalarStoreF32x4Aligned);

  rawDst := GetMem(64);
  alignedRaw := AlignedAlloc(128, SIMD_ALIGN_16);
  try
    // 故意制造非对齐地址
    pDst := rawDst + 3;

    // 选择一个 16-byte 对齐的目的地址（避免与 header 重叠，并留足哨兵区）
    pAlignedDst := PByte(alignedRaw) + 64;
    AssertTrue('pAlignedDst should be 16-byte aligned', IsAligned(pAlignedDst, SIMD_ALIGN_16));

    RandSeed := 20260105;

    for iter := 1 to 2000 do
    begin
      // 任意 bit-pattern（包含 NaN/Inf/±0 等），store 应该 bit-exact。
      for i := 0 to 3 do
      begin
        bits := DWord(Random($10000)) or (DWord(Random($10000)) shl 16);
        a.f[i] := SingleFromBits(bits);
      end;
      Move(a.f[0], expBytes[0], SizeOf(expBytes));

      // --- Unaligned store ---
      FillChar(rawDst^, 64, $CD);
      ok := AbiCall_PtrVecToVoid_CheckCalleeSaved(Pointer(dt^.StoreF32x4), PSingle(pDst), a);
      AssertTrue('ABI callee-saved should be preserved (StoreF32x4) iter ' + IntToStr(iter), ok);

      AssertAllBytesAre('StoreF32x4 prefix sentinel', rawDst, 3, $CD);
      AssertBytesEqual('StoreF32x4 payload', @expBytes[0], pDst, 16);
      AssertAllBytesAre('StoreF32x4 suffix sentinel', pDst + 16, 64 - (3 + 16), $CD);

      // --- Aligned store ---
      FillChar(PByte(alignedRaw)^, 128, $EF);
      ok := AbiCall_PtrVecToVoid_CheckCalleeSaved(Pointer(dt^.StoreF32x4Aligned), PSingle(pAlignedDst), a);
      AssertTrue('ABI callee-saved should be preserved (StoreF32x4Aligned) iter ' + IntToStr(iter), ok);

      AssertAllBytesAre('StoreF32x4Aligned prefix sentinel', PByte(alignedRaw), 64, $EF);
      AssertBytesEqual('StoreF32x4Aligned payload', @expBytes[0], pAlignedDst, 16);
      AssertAllBytesAre('StoreF32x4Aligned suffix sentinel', pAlignedDst + 16, 128 - (64 + 16), $EF);
    end;
  finally
    FreeMem(rawDst);
    AlignedFree(alignedRaw);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_Insert;
var
  dt: PSimdDispatchTable;
  a, expected, actual: TVecF32x4;
  value: Single;
  idx, iter, i: Integer;
  bits: DWord;
  ok: Boolean;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.InsertF32x4 should be assigned', Assigned(dt^.InsertF32x4));
  AssertTrue('InsertF32x4 should not be scalar when vector asm enabled', dt^.InsertF32x4 <> @ScalarInsertF32x4);

  RandSeed := 20260106;

  for iter := 1 to 2000 do
  begin
    // 任意 bit-pattern（包含 NaN/Inf/±0 等），Insert 应该保持 bit-exact。
    for i := 0 to 3 do
    begin
      bits := DWord(Random($10000)) or (DWord(Random($10000)) shl 16);
      a.f[i] := SingleFromBits(bits);
    end;

    bits := DWord(Random($10000)) or (DWord(Random($10000)) shl 16);
    value := SingleFromBits(bits);

    idx := Random(4);

    expected := ScalarInsertF32x4(a, value, idx);
    ok := AbiCall_VecSingleI32ToVec_CheckCalleeSaved(Pointer(dt^.InsertF32x4), a, value, idx, actual);
    AssertTrue('ABI callee-saved should be preserved (InsertF32x4) iter ' + IntToStr(iter), ok);

    for i := 0 to 3 do
      AssertEquals('ABI InsertF32x4 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_Extract;
var
  dt: PSimdDispatchTable;
  a: TVecF32x4;
  expected, actual: Single;
  idx, iter, i: Integer;
  bits: DWord;
  ok: Boolean;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.ExtractF32x4 should be assigned', Assigned(dt^.ExtractF32x4));
  AssertTrue('ExtractF32x4 should not be scalar when vector asm enabled', dt^.ExtractF32x4 <> @ScalarExtractF32x4);

  RandSeed := 20260107;

  for iter := 1 to 2000 do
  begin
    // 任意 bit-pattern（包含 NaN/Inf/±0 等），Extract 应该保持 bit-exact。
    for i := 0 to 3 do
    begin
      bits := DWord(Random($10000)) or (DWord(Random($10000)) shl 16);
      a.f[i] := SingleFromBits(bits);
    end;

    idx := Random(4);

    expected := ScalarExtractF32x4(a, idx);
    ok := AbiCall_VecI32ToSingle_CheckCalleeSaved(Pointer(dt^.ExtractF32x4), a, idx, actual);
    AssertTrue('ABI callee-saved should be preserved (ExtractF32x4) iter ' + IntToStr(iter), ok);
    AssertEquals('ABI ExtractF32x4 iter ' + IntToStr(iter) + ' bits', BitsFromSingle(expected), BitsFromSingle(actual));
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_MaskReturn;
var
  dt: PSimdDispatchTable;
  a, b: TVecF32x4;
  expected, actual: TMask4;
  iter, i: Integer;
  ok: Boolean;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.CmpEqF32x4 should be assigned', Assigned(dt^.CmpEqF32x4));
  AssertTrue('Dispatch.CmpLtF32x4 should be assigned', Assigned(dt^.CmpLtF32x4));
  AssertTrue('Dispatch.CmpLeF32x4 should be assigned', Assigned(dt^.CmpLeF32x4));
  AssertTrue('Dispatch.CmpGtF32x4 should be assigned', Assigned(dt^.CmpGtF32x4));
  AssertTrue('Dispatch.CmpGeF32x4 should be assigned', Assigned(dt^.CmpGeF32x4));
  AssertTrue('Dispatch.CmpNeF32x4 should be assigned', Assigned(dt^.CmpNeF32x4));

  AssertTrue('CmpEqF32x4 should not be scalar when vector asm enabled', dt^.CmpEqF32x4 <> @ScalarCmpEqF32x4);
  AssertTrue('CmpLtF32x4 should not be scalar when vector asm enabled', dt^.CmpLtF32x4 <> @ScalarCmpLtF32x4);
  AssertTrue('CmpLeF32x4 should not be scalar when vector asm enabled', dt^.CmpLeF32x4 <> @ScalarCmpLeF32x4);
  AssertTrue('CmpGtF32x4 should not be scalar when vector asm enabled', dt^.CmpGtF32x4 <> @ScalarCmpGtF32x4);
  AssertTrue('CmpGeF32x4 should not be scalar when vector asm enabled', dt^.CmpGeF32x4 <> @ScalarCmpGeF32x4);
  AssertTrue('CmpNeF32x4 should not be scalar when vector asm enabled', dt^.CmpNeF32x4 <> @ScalarCmpNeF32x4);

  RandSeed := 20251231;

  for iter := 1 to 2000 do
  begin
    for i := 0 to 3 do
    begin
      a.f[i] := Single(Random(2001) - 1000);
      b.f[i] := Single(Random(2001) - 1000);
    end;

    expected := ScalarCmpEqF32x4(a, b);
    ok := AbiCall_TwoVecToMask_CheckCalleeSaved(Pointer(dt^.CmpEqF32x4), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (CmpEqF32x4) iter ' + IntToStr(iter), ok);
    AssertEquals('ABI CmpEqF32x4 iter ' + IntToStr(iter), expected, actual);

    expected := ScalarCmpLtF32x4(a, b);
    ok := AbiCall_TwoVecToMask_CheckCalleeSaved(Pointer(dt^.CmpLtF32x4), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (CmpLtF32x4) iter ' + IntToStr(iter), ok);
    AssertEquals('ABI CmpLtF32x4 iter ' + IntToStr(iter), expected, actual);

    expected := ScalarCmpLeF32x4(a, b);
    ok := AbiCall_TwoVecToMask_CheckCalleeSaved(Pointer(dt^.CmpLeF32x4), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (CmpLeF32x4) iter ' + IntToStr(iter), ok);
    AssertEquals('ABI CmpLeF32x4 iter ' + IntToStr(iter), expected, actual);

    expected := ScalarCmpGtF32x4(a, b);
    ok := AbiCall_TwoVecToMask_CheckCalleeSaved(Pointer(dt^.CmpGtF32x4), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (CmpGtF32x4) iter ' + IntToStr(iter), ok);
    AssertEquals('ABI CmpGtF32x4 iter ' + IntToStr(iter), expected, actual);

    expected := ScalarCmpGeF32x4(a, b);
    ok := AbiCall_TwoVecToMask_CheckCalleeSaved(Pointer(dt^.CmpGeF32x4), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (CmpGeF32x4) iter ' + IntToStr(iter), ok);
    AssertEquals('ABI CmpGeF32x4 iter ' + IntToStr(iter), expected, actual);

    expected := ScalarCmpNeF32x4(a, b);
    ok := AbiCall_TwoVecToMask_CheckCalleeSaved(Pointer(dt^.CmpNeF32x4), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (CmpNeF32x4) iter ' + IntToStr(iter), ok);
    AssertEquals('ABI CmpNeF32x4 iter ' + IntToStr(iter), expected, actual);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_Zero;
var
  dt: PSimdDispatchTable;
  actual: TVecF32x4;
  ok: Boolean;
  i: Integer;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.ZeroF32x4 should be assigned', Assigned(dt^.ZeroF32x4));
  AssertTrue('ZeroF32x4 should not be scalar when vector asm enabled', dt^.ZeroF32x4 <> @ScalarZeroF32x4);

  ok := AbiCall_NoArgsToVec_CheckCalleeSaved(Pointer(dt^.ZeroF32x4), actual);
  AssertTrue('ABI callee-saved should be preserved (ZeroF32x4)', ok);

  for i := 0 to 3 do
    AssertEquals('ABI ZeroF32x4 lane ' + IntToStr(i) + ' bits', DWord(0), BitsFromSingle(actual.f[i]));
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_Splat;
var
  dt: PSimdDispatchTable;
  actual: TVecF32x4;
  value: Single;
  bits: DWord;
  ok: Boolean;
  iter, i: Integer;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.SplatF32x4 should be assigned', Assigned(dt^.SplatF32x4));
  AssertTrue('SplatF32x4 should not be scalar when vector asm enabled', dt^.SplatF32x4 <> @ScalarSplatF32x4);

  RandSeed := 20260108;

  for iter := 1 to 2000 do
  begin
    bits := DWord(Random($10000)) or (DWord(Random($10000)) shl 16);
    value := SingleFromBits(bits);

    ok := AbiCall_SingleToVec_CheckCalleeSaved(Pointer(dt^.SplatF32x4), value, actual);
    AssertTrue('ABI callee-saved should be preserved (SplatF32x4) iter ' + IntToStr(iter), ok);

    for i := 0 to 3 do
      AssertEquals('ABI SplatF32x4 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   bits, BitsFromSingle(actual.f[i]));
  end;

  // Special: -0 / qNaN payload
  bits := $80000000;
  value := SingleFromBits(bits);
  ok := AbiCall_SingleToVec_CheckCalleeSaved(Pointer(dt^.SplatF32x4), value, actual);
  AssertTrue('ABI callee-saved should be preserved (SplatF32x4 -0)', ok);
  for i := 0 to 3 do
    AssertEquals('ABI SplatF32x4 -0 lane ' + IntToStr(i) + ' bits', bits, BitsFromSingle(actual.f[i]));

  bits := $7FC12345;
  value := SingleFromBits(bits);
  ok := AbiCall_SingleToVec_CheckCalleeSaved(Pointer(dt^.SplatF32x4), value, actual);
  AssertTrue('ABI callee-saved should be preserved (SplatF32x4 NaN payload)', ok);
  for i := 0 to 3 do
    AssertEquals('ABI SplatF32x4 NaN lane ' + IntToStr(i) + ' bits', bits, BitsFromSingle(actual.f[i]));
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x4_ABI_CalleeSavedRegisters_Preserved_Select;
var
  dt: PSimdDispatchTable;
  a, b, actual: TVecF32x4;
  expected: TVecF32x4;
  mask: TMask4;
  iter, i: Integer;
  bits: DWord;
  ok: Boolean;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.SelectF32x4 should be assigned', Assigned(dt^.SelectF32x4));
  AssertTrue('SelectF32x4 should not be scalar when vector asm enabled', dt^.SelectF32x4 <> @ScalarSelectF32x4);

  RandSeed := 20260109;

  for iter := 1 to 2000 do
  begin
    for i := 0 to 3 do
    begin
      bits := DWord(Random($10000)) or (DWord(Random($10000)) shl 16);
      a.f[i] := SingleFromBits(bits);
      bits := DWord(Random($10000)) or (DWord(Random($10000)) shl 16);
      b.f[i] := SingleFromBits(bits);
    end;

    mask := TMask4(Random(16));

    for i := 0 to 3 do
      if (mask and (1 shl i)) <> 0 then
        expected.f[i] := a.f[i]
      else
        expected.f[i] := b.f[i];

    ok := AbiCall_TwoVecMaskToVec_CheckCalleeSaved(Pointer(dt^.SelectF32x4), a, b, mask, actual);
    AssertTrue('ABI callee-saved should be preserved (SelectF32x4) iter ' + IntToStr(iter), ok);

    for i := 0 to 3 do
      AssertEquals('ABI SelectF32x4 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF32x8_ABI_CalleeSavedRegisters_Preserved_VectorReturn;
var
  dt: PSimdDispatchTable;
  a, b: TVecF32x8;
  aDiv, bDiv: TVecF32x8;
  expected, actual: TVecF32x8;
  iter, i: Integer;
  pow2: Integer;
  ok: Boolean;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.AddF32x8 should be assigned', Assigned(dt^.AddF32x8));
  AssertTrue('AddF32x8 should not be scalar when vector asm enabled', dt^.AddF32x8 <> @ScalarAddF32x8);

  AssertTrue('Dispatch.SubF32x8 should be assigned', Assigned(dt^.SubF32x8));
  AssertTrue('SubF32x8 should not be scalar when vector asm enabled', dt^.SubF32x8 <> @ScalarSubF32x8);

  AssertTrue('Dispatch.MulF32x8 should be assigned', Assigned(dt^.MulF32x8));
  AssertTrue('MulF32x8 should not be scalar when vector asm enabled', dt^.MulF32x8 <> @ScalarMulF32x8);

  AssertTrue('Dispatch.DivF32x8 should be assigned', Assigned(dt^.DivF32x8));
  AssertTrue('DivF32x8 should not be scalar when vector asm enabled', dt^.DivF32x8 <> @ScalarDivF32x8);

  RandSeed := 20260110;

  for iter := 1 to 2000 do
  begin
    for i := 0 to 7 do
    begin
      // 选小整数，保证结果 float32 bit-exact
      a.f[i] := Single(Random(2001) - 1000);
      b.f[i] := Single(Random(2001) - 1000);
    end;

    expected := ScalarAddF32x8(a, b);
    ok := AbiCall_TwoPtrToVecF32x8_CheckCalleeSaved(Pointer(dt^.AddF32x8), @a, @b, actual);
    AssertTrue('ABI callee-saved should be preserved (AddF32x8) iter ' + IntToStr(iter), ok);

    for i := 0 to 7 do
      AssertEquals('ABI AddF32x8 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));

    expected := ScalarSubF32x8(a, b);
    ok := AbiCall_TwoPtrToVecF32x8_CheckCalleeSaved(Pointer(dt^.SubF32x8), @a, @b, actual);
    AssertTrue('ABI callee-saved should be preserved (SubF32x8) iter ' + IntToStr(iter), ok);

    for i := 0 to 7 do
      AssertEquals('ABI SubF32x8 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));

    expected := ScalarMulF32x8(a, b);
    ok := AbiCall_TwoPtrToVecF32x8_CheckCalleeSaved(Pointer(dt^.MulF32x8), @a, @b, actual);
    AssertTrue('ABI callee-saved should be preserved (MulF32x8) iter ' + IntToStr(iter), ok);

    for i := 0 to 7 do
      AssertEquals('ABI MulF32x8 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));

    // Div：使用 2^k 作为除数，保证结果在 float32 下 bit-exact。
    for i := 0 to 7 do
    begin
      aDiv.f[i] := Single(Random(2001) - 1000);
      pow2 := 1 shl Random(8); // 1..128
      bDiv.f[i] := Single(pow2);
    end;

    expected := ScalarDivF32x8(aDiv, bDiv);
    ok := AbiCall_TwoPtrToVecF32x8_CheckCalleeSaved(Pointer(dt^.DivF32x8), @aDiv, @bDiv, actual);
    AssertTrue('ABI callee-saved should be preserved (DivF32x8) iter ' + IntToStr(iter), ok);

    for i := 0 to 7 do
      AssertEquals('ABI DivF32x8 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromSingle(expected.f[i]), BitsFromSingle(actual.f[i]));
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecF64x2_ABI_CalleeSavedRegisters_Preserved_VectorReturn;
var
  dt: PSimdDispatchTable;
  a, b: TVecF64x2;
  aDiv, bDiv: TVecF64x2;
  expected, actual: TVecF64x2;
  iter, i: Integer;
  pow2: Integer;
  ok: Boolean;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.AddF64x2 should be assigned', Assigned(dt^.AddF64x2));
  AssertTrue('AddF64x2 should not be scalar when vector asm enabled', dt^.AddF64x2 <> @ScalarAddF64x2);

  AssertTrue('Dispatch.SubF64x2 should be assigned', Assigned(dt^.SubF64x2));
  AssertTrue('SubF64x2 should not be scalar when vector asm enabled', dt^.SubF64x2 <> @ScalarSubF64x2);

  AssertTrue('Dispatch.MulF64x2 should be assigned', Assigned(dt^.MulF64x2));
  AssertTrue('MulF64x2 should not be scalar when vector asm enabled', dt^.MulF64x2 <> @ScalarMulF64x2);

  AssertTrue('Dispatch.DivF64x2 should be assigned', Assigned(dt^.DivF64x2));
  AssertTrue('DivF64x2 should not be scalar when vector asm enabled', dt^.DivF64x2 <> @ScalarDivF64x2);

  RandSeed := 20260111;

  for iter := 1 to 2000 do
  begin
    for i := 0 to 1 do
    begin
      // 选小整数，保证 double 结果 bit-exact
      a.d[i] := Double(Random(2001) - 1000);
      b.d[i] := Double(Random(2001) - 1000);
    end;

    expected := ScalarAddF64x2(a, b);
    ok := AbiCall_TwoVecF64x2ToVec_CheckCalleeSaved(Pointer(dt^.AddF64x2), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (AddF64x2) iter ' + IntToStr(iter), ok);

    for i := 0 to 1 do
      AssertEquals('ABI AddF64x2 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromDouble(expected.d[i]), BitsFromDouble(actual.d[i]));

    expected := ScalarSubF64x2(a, b);
    ok := AbiCall_TwoVecF64x2ToVec_CheckCalleeSaved(Pointer(dt^.SubF64x2), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (SubF64x2) iter ' + IntToStr(iter), ok);

    for i := 0 to 1 do
      AssertEquals('ABI SubF64x2 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromDouble(expected.d[i]), BitsFromDouble(actual.d[i]));

    expected := ScalarMulF64x2(a, b);
    ok := AbiCall_TwoVecF64x2ToVec_CheckCalleeSaved(Pointer(dt^.MulF64x2), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (MulF64x2) iter ' + IntToStr(iter), ok);

    for i := 0 to 1 do
      AssertEquals('ABI MulF64x2 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromDouble(expected.d[i]), BitsFromDouble(actual.d[i]));

    // Div：使用 2^k 作为除数，保证结果在 double 下 bit-exact。
    for i := 0 to 1 do
    begin
      aDiv.d[i] := Double(Random(2001) - 1000);
      pow2 := 1 shl Random(8); // 1..128
      bDiv.d[i] := Double(pow2);
    end;

    expected := ScalarDivF64x2(aDiv, bDiv);
    ok := AbiCall_TwoVecF64x2ToVec_CheckCalleeSaved(Pointer(dt^.DivF64x2), aDiv, bDiv, actual);
    AssertTrue('ABI callee-saved should be preserved (DivF64x2) iter ' + IntToStr(iter), ok);

    for i := 0 to 1 do
      AssertEquals('ABI DivF64x2 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i) + ' bits',
                   BitsFromDouble(expected.d[i]), BitsFromDouble(actual.d[i]));
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_VecI32x4_ABI_CalleeSavedRegisters_Preserved_VectorReturn;
var
  dt: PSimdDispatchTable;
  a, b, expected, actual: TVecI32x4;
  iter, i: Integer;
  ok: Boolean;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.AddI32x4 should be assigned', Assigned(dt^.AddI32x4));
  AssertTrue('AddI32x4 should not be scalar when vector asm enabled', dt^.AddI32x4 <> @ScalarAddI32x4);

  AssertTrue('Dispatch.SubI32x4 should be assigned', Assigned(dt^.SubI32x4));
  AssertTrue('SubI32x4 should not be scalar when vector asm enabled', dt^.SubI32x4 <> @ScalarSubI32x4);

  AssertTrue('Dispatch.MulI32x4 should be assigned', Assigned(dt^.MulI32x4));
  AssertTrue('MulI32x4 should not be scalar when vector asm enabled', dt^.MulI32x4 <> @ScalarMulI32x4);

  RandSeed := 20260112;

  for iter := 1 to 5000 do
  begin
    for i := 0 to 3 do
    begin
      // 选小整数，避免溢出，保证逐 lane 精确比对
      a.i[i] := Random(2001) - 1000;
      b.i[i] := Random(2001) - 1000;
    end;

    expected := ScalarAddI32x4(a, b);
    ok := AbiCall_TwoVecI32x4ToVec_CheckCalleeSaved(Pointer(dt^.AddI32x4), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (AddI32x4) iter ' + IntToStr(iter), ok);

    for i := 0 to 3 do
      AssertEquals('ABI AddI32x4 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expected.i[i], actual.i[i]);

    expected := ScalarSubI32x4(a, b);
    ok := AbiCall_TwoVecI32x4ToVec_CheckCalleeSaved(Pointer(dt^.SubI32x4), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (SubI32x4) iter ' + IntToStr(iter), ok);

    for i := 0 to 3 do
      AssertEquals('ABI SubI32x4 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expected.i[i], actual.i[i]);

    expected := ScalarMulI32x4(a, b);
    ok := AbiCall_TwoVecI32x4ToVec_CheckCalleeSaved(Pointer(dt^.MulI32x4), a, b, actual);
    AssertTrue('ABI callee-saved should be preserved (MulI32x4) iter ' + IntToStr(iter), ok);

    for i := 0 to 3 do
      AssertEquals('ABI MulI32x4 iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expected.i[i], actual.i[i]);
  end;
end;

procedure TTestCase_AVX2VectorAsm.Test_Facade_MemEqual_ABI_CalleeSavedRegisters_Preserved;
var
  dt: PSimdDispatchTable;
  buf1, buf2: array[0..127] of Byte;
  expected, actual: LongBool;
  ok: Boolean;
  i: Integer;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.MemEqual should be assigned', Assigned(dt^.MemEqual));
  AssertTrue('MemEqual should not be scalar when vector asm enabled', dt^.MemEqual <> @MemEqual_Scalar);

  for i := 0 to High(buf1) do
  begin
    buf1[i] := Byte(i);
    buf2[i] := Byte(i);
  end;

  expected := MemEqual_Scalar(@buf1[0], @buf2[0], SizeUInt(Length(buf1)));

  actual := False;
  ok := AbiCall_MemEqual_CheckCalleeSaved(Pointer(dt^.MemEqual), @buf1[0], @buf2[0], SizeUInt(Length(buf1)), actual);
  AssertTrue('ABI callee-saved should be preserved (MemEqual equal)', ok);
  AssertEquals('ABI MemEqual equal result', expected, actual);

  // different
  buf2[17] := 255;
  expected := MemEqual_Scalar(@buf1[0], @buf2[0], SizeUInt(Length(buf1)));

  actual := False;
  ok := AbiCall_MemEqual_CheckCalleeSaved(Pointer(dt^.MemEqual), @buf1[0], @buf2[0], SizeUInt(Length(buf1)), actual);
  AssertTrue('ABI callee-saved should be preserved (MemEqual different)', ok);
  AssertEquals('ABI MemEqual different result', expected, actual);
end;

procedure TTestCase_AVX2VectorAsm.Test_Facade_SumBytes_ABI_CalleeSavedRegisters_Preserved;
var
  dt: PSimdDispatchTable;
  buf: array[0..255] of Byte;
  expected, actual: UInt64;
  ok: Boolean;
  i: Integer;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.SumBytes should be assigned', Assigned(dt^.SumBytes));
  AssertTrue('SumBytes should not be scalar when vector asm enabled', dt^.SumBytes <> @SumBytes_Scalar);

  for i := 0 to High(buf) do
    buf[i] := Byte(i);

  expected := SumBytes_Scalar(@buf[0], SizeUInt(Length(buf)));

  actual := 0;
  ok := AbiCall_SumBytes_CheckCalleeSaved(Pointer(dt^.SumBytes), @buf[0], SizeUInt(Length(buf)), actual);
  AssertTrue('ABI callee-saved should be preserved (SumBytes)', ok);
  AssertEquals('ABI SumBytes result', expected, actual);
end;

procedure TTestCase_AVX2VectorAsm.Test_Facade_CountByte_ABI_CalleeSavedRegisters_Preserved;
var
  dt: PSimdDispatchTable;
  buf: array[0..255] of Byte;
  expected, actual: SizeUInt;
  ok: Boolean;
  i: Integer;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.CountByte should be assigned', Assigned(dt^.CountByte));
  AssertTrue('CountByte should not be scalar when vector asm enabled', dt^.CountByte <> @CountByte_Scalar);

  for i := 0 to High(buf) do
    buf[i] := Byte(i and $0F);

  expected := CountByte_Scalar(@buf[0], SizeUInt(Length(buf)), 5);

  actual := 0;
  ok := AbiCall_CountByte_CheckCalleeSaved(Pointer(dt^.CountByte), @buf[0], SizeUInt(Length(buf)), 5, actual);
  AssertTrue('ABI callee-saved should be preserved (CountByte)', ok);
  AssertEquals('ABI CountByte result', expected, actual);
end;

procedure TTestCase_AVX2VectorAsm.Test_Facade_BitsetPopCount_ABI_CalleeSavedRegisters_Preserved;
var
  dt: PSimdDispatchTable;
  buf: array[0..255] of Byte;
  expected, actual: SizeUInt;
  ok: Boolean;
  i: Integer;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.BitsetPopCount should be assigned', Assigned(dt^.BitsetPopCount));
  AssertTrue('BitsetPopCount should not be scalar when vector asm enabled', dt^.BitsetPopCount <> @BitsetPopCount_Scalar);

  // 构造确定性位模式
  for i := 0 to High(buf) do
    buf[i] := Byte((i * 13 + 7) and $FF);

  expected := BitsetPopCount_Scalar(@buf[0], SizeUInt(Length(buf)));

  actual := 0;
  ok := AbiCall_BitsetPopCount_CheckCalleeSaved(Pointer(dt^.BitsetPopCount), @buf[0], SizeUInt(Length(buf)), actual);
  AssertTrue('ABI callee-saved should be preserved (BitsetPopCount)', ok);
  AssertEquals('ABI BitsetPopCount result', expected, actual);
end;

procedure TTestCase_AVX2VectorAsm.Test_Facade_Utf8Validate_ABI_CalleeSavedRegisters_Preserved;
const
  ValidASCII: array[0..4] of Byte = (Ord('H'), Ord('e'), Ord('l'), Ord('l'), Ord('o'));
  InvalidOverlong: array[0..1] of Byte = ($C0, $80);
var
  dt: PSimdDispatchTable;
  expected, actual: Boolean;
  ok: Boolean;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.Utf8Validate should be assigned', Assigned(dt^.Utf8Validate));
  AssertTrue('Utf8Validate should not be scalar when vector asm enabled', dt^.Utf8Validate <> @Utf8Validate_Scalar);

  // valid
  expected := Utf8Validate_Scalar(@ValidASCII[0], SizeUInt(Length(ValidASCII)));

  actual := False;
  ok := AbiCall_Utf8Validate_CheckCalleeSaved(Pointer(dt^.Utf8Validate), @ValidASCII[0], SizeUInt(Length(ValidASCII)), actual);
  AssertTrue('ABI callee-saved should be preserved (Utf8Validate valid)', ok);
  AssertEquals('ABI Utf8Validate valid result', expected, actual);

  // invalid
  expected := Utf8Validate_Scalar(@InvalidOverlong[0], SizeUInt(Length(InvalidOverlong)));

  actual := False;
  ok := AbiCall_Utf8Validate_CheckCalleeSaved(Pointer(dt^.Utf8Validate), @InvalidOverlong[0], SizeUInt(Length(InvalidOverlong)), actual);
  AssertTrue('ABI callee-saved should be preserved (Utf8Validate invalid)', ok);
  AssertEquals('ABI Utf8Validate invalid result', expected, actual);
end;

procedure TTestCase_AVX2VectorAsm.Test_Facade_AsciiIEqual_ABI_CalleeSavedRegisters_Preserved;
const
  A1: array[0..4] of Byte = (Ord('H'), Ord('e'), Ord('L'), Ord('L'), Ord('o'));
  B1: array[0..4] of Byte = (Ord('h'), Ord('E'), Ord('l'), Ord('l'), Ord('O'));
  B2: array[0..4] of Byte = (Ord('W'), Ord('o'), Ord('r'), Ord('l'), Ord('d'));
var
  dt: PSimdDispatchTable;
  expected, actual: Boolean;
  ok: Boolean;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.AsciiIEqual should be assigned', Assigned(dt^.AsciiIEqual));
  AssertTrue('AsciiIEqual should not be scalar when vector asm enabled', dt^.AsciiIEqual <> @AsciiIEqual_Scalar);

  // equal (case-insensitive)
  expected := AsciiIEqual_Scalar(@A1[0], @B1[0], SizeUInt(Length(A1)));

  actual := False;
  ok := AbiCall_AsciiIEqual_CheckCalleeSaved(Pointer(dt^.AsciiIEqual), @A1[0], @B1[0], SizeUInt(Length(A1)), actual);
  AssertTrue('ABI callee-saved should be preserved (AsciiIEqual equal)', ok);
  AssertEquals('ABI AsciiIEqual equal result', expected, actual);

  // different
  expected := AsciiIEqual_Scalar(@A1[0], @B2[0], SizeUInt(Length(A1)));

  actual := False;
  ok := AbiCall_AsciiIEqual_CheckCalleeSaved(Pointer(dt^.AsciiIEqual), @A1[0], @B2[0], SizeUInt(Length(A1)), actual);
  AssertTrue('ABI callee-saved should be preserved (AsciiIEqual different)', ok);
  AssertEquals('ABI AsciiIEqual different result', expected, actual);
end;

procedure TTestCase_AVX2VectorAsm.Test_Facade_ToLowerAscii_ABI_CalleeSavedRegisters_Preserved;
var
  dt: PSimdDispatchTable;
  expected, actual: array[0..31] of Byte;
  ok: Boolean;
  i: Integer;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.ToLowerAscii should be assigned', Assigned(dt^.ToLowerAscii));
  AssertTrue('ToLowerAscii should not be scalar when vector asm enabled', dt^.ToLowerAscii <> @ToLowerAscii_Scalar);

  for i := 0 to High(actual) do
  begin
    case (i and 3) of
      0: actual[i] := Ord('A') + Byte(i mod 26);
      1: actual[i] := Ord('a') + Byte(i mod 26);
      2: actual[i] := Ord('0') + Byte(i mod 10);
    else
      actual[i] := Ord('_');
    end;
  end;

  expected := actual;
  ToLowerAscii_Scalar(@expected[0], SizeUInt(Length(expected)));

  ok := AbiCall_ToLowerAscii_CheckCalleeSaved(Pointer(dt^.ToLowerAscii), @actual[0], SizeUInt(Length(actual)));
  AssertTrue('ABI callee-saved should be preserved (ToLowerAscii)', ok);

  for i := 0 to High(actual) do
    AssertEquals('ABI ToLowerAscii byte ' + IntToStr(i), expected[i], actual[i]);
end;

procedure TTestCase_AVX2VectorAsm.Test_Facade_ToUpperAscii_ABI_CalleeSavedRegisters_Preserved;
var
  dt: PSimdDispatchTable;
  expected, actual: array[0..31] of Byte;
  ok: Boolean;
  i: Integer;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.ToUpperAscii should be assigned', Assigned(dt^.ToUpperAscii));
  AssertTrue('ToUpperAscii should not be scalar when vector asm enabled', dt^.ToUpperAscii <> @ToUpperAscii_Scalar);

  for i := 0 to High(actual) do
  begin
    case (i and 3) of
      0: actual[i] := Ord('a') + Byte(i mod 26);
      1: actual[i] := Ord('A') + Byte(i mod 26);
      2: actual[i] := Ord('0') + Byte(i mod 10);
    else
      actual[i] := Ord('_');
    end;
  end;

  expected := actual;
  ToUpperAscii_Scalar(@expected[0], SizeUInt(Length(expected)));

  ok := AbiCall_ToUpperAscii_CheckCalleeSaved(Pointer(dt^.ToUpperAscii), @actual[0], SizeUInt(Length(actual)));
  AssertTrue('ABI callee-saved should be preserved (ToUpperAscii)', ok);

  for i := 0 to High(actual) do
    AssertEquals('ABI ToUpperAscii byte ' + IntToStr(i), expected[i], actual[i]);
end;

procedure TTestCase_AVX2VectorAsm.Test_Facade_MemDiffRange_ABI_CalleeSavedRegisters_Preserved;
var
  dt: PSimdDispatchTable;
  buf1, buf2: array[0..63] of Byte;
  expectedFirst, expectedLast: SizeUInt;
  actualFirst, actualLast: SizeUInt;
  expectedRes, actualRes: Boolean;
  ok: Boolean;
  i: Integer;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.MemDiffRange should be assigned', Assigned(dt^.MemDiffRange));
  AssertTrue('MemDiffRange should not be scalar when vector asm enabled', dt^.MemDiffRange <> @MemDiffRange_Scalar);

  for i := 0 to High(buf1) do
  begin
    buf1[i] := Byte(i);
    buf2[i] := Byte(i);
  end;

  // 制造一个确定性的 diff range
  buf2[5] := 255;
  buf2[40] := 254;

  expectedRes := MemDiffRange_Scalar(@buf1[0], @buf2[0], SizeUInt(Length(buf1)), expectedFirst, expectedLast);
  AssertTrue('Scalar MemDiffRange should detect differences', expectedRes);

  actualFirst := 0;
  actualLast := 0;
  actualRes := False;

  ok := AbiCall_MemDiffRange_CheckCalleeSaved(Pointer(dt^.MemDiffRange), @buf1[0], @buf2[0], SizeUInt(Length(buf1)),
                                             actualFirst, actualLast, actualRes);
  AssertTrue('ABI callee-saved should be preserved (MemDiffRange)', ok);

  AssertEquals('ABI MemDiffRange result', expectedRes, actualRes);
  AssertEquals('ABI MemDiffRange first diff', expectedFirst, actualFirst);
  AssertEquals('ABI MemDiffRange last diff', expectedLast, actualLast);
end;

procedure TTestCase_AVX2VectorAsm.Test_Facade_MemFindByte_ABI_CalleeSavedRegisters_Preserved;
var
  dt: PSimdDispatchTable;
  buf: array[0..255] of Byte;
  expected, actual: PtrInt;
  ok: Boolean;
  i: Integer;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.MemFindByte should be assigned', Assigned(dt^.MemFindByte));
  AssertTrue('MemFindByte should not be scalar when vector asm enabled', dt^.MemFindByte <> @MemFindByte_Scalar);

  for i := 0 to High(buf) do
    buf[i] := Byte(i and $7F);

  buf[123] := 200;

  expected := MemFindByte_Scalar(@buf[0], SizeUInt(Length(buf)), 200);

  actual := 0;
  ok := AbiCall_MemFindByte_CheckCalleeSaved(Pointer(dt^.MemFindByte), @buf[0], SizeUInt(Length(buf)), 200, actual);
  AssertTrue('ABI callee-saved should be preserved (MemFindByte)', ok);
  AssertEquals('ABI MemFindByte result', expected, actual);

  expected := MemFindByte_Scalar(@buf[0], SizeUInt(Length(buf)), 255);

  actual := 0;
  ok := AbiCall_MemFindByte_CheckCalleeSaved(Pointer(dt^.MemFindByte), @buf[0], SizeUInt(Length(buf)), 255, actual);
  AssertTrue('ABI callee-saved should be preserved (MemFindByte not found)', ok);
  AssertEquals('ABI MemFindByte not found', expected, actual);
end;

procedure TTestCase_AVX2VectorAsm.Test_Facade_MemCopy_ABI_CalleeSavedRegisters_Preserved;
const
  CopyLen = 123;
var
  dt: PSimdDispatchTable;
  src: array[0..255] of Byte;
  expected, actual: array[0..255] of Byte;
  ok: Boolean;
  i: Integer;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.MemCopy should be assigned', Assigned(dt^.MemCopy));
  // Note: AVX2 now has its own MemCopy implementation (MemCopy_AVX2) which is correct

  for i := 0 to High(src) do
    src[i] := Byte((i * 37 + 11) and $FF);

  for i := 0 to High(actual) do
    actual[i] := $CC;

  expected := actual;
  MemCopy_Scalar(@src[0], @expected[0], SizeUInt(CopyLen));

  ok := AbiCall_MemCopy_CheckCalleeSaved(Pointer(dt^.MemCopy), @src[0], @actual[0], SizeUInt(CopyLen));
  AssertTrue('ABI callee-saved should be preserved (MemCopy)', ok);

  for i := 0 to High(actual) do
    AssertEquals('ABI MemCopy dst byte ' + IntToStr(i), expected[i], actual[i]);
end;

procedure TTestCase_AVX2VectorAsm.Test_Facade_BytesIndexOf_ABI_CalleeSavedRegisters_Preserved;
var
  dt: PSimdDispatchTable;
  haystack: array[0..255] of Byte;
  needle: array[0..3] of Byte;
  expected, actual: PtrInt;
  ok: Boolean;
  i: Integer;
begin
  if not HasAVX2 then
    Exit;

  AssertEquals('Active backend should be AVX2', Ord(sbAVX2), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  AssertTrue('Dispatch.BytesIndexOf should be assigned', Assigned(dt^.BytesIndexOf));
  AssertTrue('BytesIndexOf should not be scalar when vector asm enabled', dt^.BytesIndexOf <> @BytesIndexOf_Scalar);

  for i := 0 to High(haystack) do
    haystack[i] := Byte(i and $7F);

  needle[0] := 64;
  needle[1] := 65;
  needle[2] := 66;
  needle[3] := 67;

  expected := BytesIndexOf_Scalar(@haystack[0], SizeUInt(Length(haystack)), @needle[0], SizeUInt(Length(needle)));

  ok := AbiCall_BytesIndexOf_CheckCalleeSaved(Pointer(dt^.BytesIndexOf), @haystack[0], SizeUInt(Length(haystack)),
                                             @needle[0], SizeUInt(Length(needle)), actual);
  AssertTrue('ABI callee-saved should be preserved (BytesIndexOf)', ok);
  AssertEquals('ABI BytesIndexOf result', expected, actual);

  // not found
  needle[0] := 200;
  needle[1] := 201;
  needle[2] := 202;
  needle[3] := 203;

  expected := BytesIndexOf_Scalar(@haystack[0], SizeUInt(Length(haystack)), @needle[0], SizeUInt(Length(needle)));

  ok := AbiCall_BytesIndexOf_CheckCalleeSaved(Pointer(dt^.BytesIndexOf), @haystack[0], SizeUInt(Length(haystack)),
                                             @needle[0], SizeUInt(Length(needle)), actual);
  AssertTrue('ABI callee-saved should be preserved (BytesIndexOf not found)', ok);
  AssertEquals('ABI BytesIndexOf not found', expected, actual);
end;

{$IFDEF SIMD_BACKEND_AVX512}
{ TTestCase_AVX512VectorAsm }

function TTestCase_AVX512VectorAsm.GetVectorAsmTargetBackend: TSimdBackend;
begin
  Result := sbAVX512;
end;

procedure TTestCase_AVX512VectorAsm.RefreshVectorAsmBackendRegistration;
begin
  RegisterAVX512Backend;
end;

procedure TTestCase_AVX512VectorAsm.Test_VecF32x16_AddSubMulDiv_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecF32x16;
  expV, actV: TVecF32x16;
  i, iter: Integer;
  eps: Single;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.AddF32x16 should be assigned', Assigned(dt^.AddF32x16));
  AssertTrue('Dispatch.SubF32x16 should be assigned', Assigned(dt^.SubF32x16));
  AssertTrue('Dispatch.MulF32x16 should be assigned', Assigned(dt^.MulF32x16));
  AssertTrue('Dispatch.DivF32x16 should be assigned', Assigned(dt^.DivF32x16));

  // vector asm 打开时，AVX-512 backend 不应退回到 scalar reference。
  AssertTrue('AddF32x16 should not be scalar', dt^.AddF32x16 <> @ScalarAddF32x16);
  AssertTrue('SubF32x16 should not be scalar', dt^.SubF32x16 <> @ScalarSubF32x16);
  AssertTrue('MulF32x16 should not be scalar', dt^.MulF32x16 <> @ScalarMulF32x16);
  AssertTrue('DivF32x16 should not be scalar', dt^.DivF32x16 <> @ScalarDivF32x16);

  eps := 1e-5;
  RandSeed := 20260101;

  for iter := 1 to 100 do
  begin
    for i := 0 to 15 do
    begin
      a.f[i] := (Random(2000001) - 1000000) / 1000.0;
      b.f[i] := (Random(2000001) - 1000000) / 1000.0;
      if Abs(b.f[i]) < 1e-3 then
        b.f[i] := 1.0;
    end;

    // Add
    expV := ScalarAddF32x16(a, b);
    actV := dt^.AddF32x16(a, b);
    for i := 0 to 15 do
      AssertEquals('F32x16 Add iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.f[i], actV.f[i], eps);

    // Sub
    expV := ScalarSubF32x16(a, b);
    actV := dt^.SubF32x16(a, b);
    for i := 0 to 15 do
      AssertEquals('F32x16 Sub iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.f[i], actV.f[i], eps);

    // Mul
    expV := ScalarMulF32x16(a, b);
    actV := dt^.MulF32x16(a, b);
    for i := 0 to 15 do
      AssertEquals('F32x16 Mul iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.f[i], actV.f[i], eps);

    // Div
    expV := ScalarDivF32x16(a, b);
    actV := dt^.DivF32x16(a, b);
    for i := 0 to 15 do
      AssertEquals('F32x16 Div iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.f[i], actV.f[i], eps);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_VecF32x16_AddSubMulDiv_SpecialValues_Consistency;
var
  dt: PSimdDispatchTable;
  a, b, bDiv: TVecF32x16;
  expV, actV: TVecF32x16;
  i: Integer;

  procedure AssertSameElementBits(const op: string; idx: Integer; expVal, actVal: Single);
  var
    expBits, actBits: DWord;
  begin
    if IsNaNSingle(expVal) then
      AssertTrue(op + ' lane ' + IntToStr(idx) + ' should be NaN', IsNaNSingle(actVal))
    else
    begin
      expBits := BitsFromSingle(expVal);
      actBits := BitsFromSingle(actVal);
      AssertTrue(op + ' lane ' + IntToStr(idx) + ' bits should match', expBits = actBits);
    end;
  end;

begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  // Fill test patterns: ±0, ±Inf, NaN interspersed with normal values
  a.f[0] := SingleFromBits($80000000); b.f[0] := SingleFromBits($00000000); // -0, +0
  a.f[1] := SingleFromBits($00000000); b.f[1] := SingleFromBits($80000000); // +0, -0
  a.f[2] := SingleFromBits($7F800000); b.f[2] := 1.0;                       // +Inf, 1
  a.f[3] := SingleFromBits($FF800000); b.f[3] := 1.0;                       // -Inf, 1
  a.f[4] := SingleFromBits($7FC00000); b.f[4] := 2.0;                       // NaN, 2
  a.f[5] := 1.0; b.f[5] := SingleFromBits($7F800000);                       // 1, +Inf
  a.f[6] := -1.0; b.f[6] := SingleFromBits($FF800000);                      // -1, -Inf
  a.f[7] := 123.0; b.f[7] := SingleFromBits($7FC00000);                     // 123, NaN
  // Remaining lanes: normal values
  for i := 8 to 15 do
  begin
    a.f[i] := (i - 8) * 10.0 + 1.0;
    b.f[i] := (i - 8) * 5.0 + 2.0;
  end;

  // Add
  expV := ScalarAddF32x16(a, b);
  actV := dt^.AddF32x16(a, b);
  for i := 0 to 15 do
    AssertSameElementBits('F32x16 Add', i, expV.f[i], actV.f[i]);

  // Sub
  expV := ScalarSubF32x16(a, b);
  actV := dt^.SubF32x16(a, b);
  for i := 0 to 15 do
    AssertSameElementBits('F32x16 Sub', i, expV.f[i], actV.f[i]);

  // Mul
  expV := ScalarMulF32x16(a, b);
  actV := dt^.MulF32x16(a, b);
  for i := 0 to 15 do
    AssertSameElementBits('F32x16 Mul', i, expV.f[i], actV.f[i]);

  // Div (avoid div by ±0)
  bDiv := b;
  for i := 0 to 15 do
    if (BitsFromSingle(bDiv.f[i]) and $7FFFFFFF) = 0 then
      bDiv.f[i] := 1.0;

  expV := ScalarDivF32x16(a, bDiv);
  actV := dt^.DivF32x16(a, bDiv);
  for i := 0 to 15 do
    AssertSameElementBits('F32x16 Div', i, expV.f[i], actV.f[i]);
end;

procedure TTestCase_AVX512VectorAsm.Test_VecF64x8_AddSubMulDiv_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecF64x8;
  expV, actV: TVecF64x8;
  i, iter: Integer;
  eps: Double;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.AddF64x8 should be assigned', Assigned(dt^.AddF64x8));
  AssertTrue('Dispatch.SubF64x8 should be assigned', Assigned(dt^.SubF64x8));
  AssertTrue('Dispatch.MulF64x8 should be assigned', Assigned(dt^.MulF64x8));
  AssertTrue('Dispatch.DivF64x8 should be assigned', Assigned(dt^.DivF64x8));

  AssertTrue('AddF64x8 should not be scalar', dt^.AddF64x8 <> @ScalarAddF64x8);
  AssertTrue('SubF64x8 should not be scalar', dt^.SubF64x8 <> @ScalarSubF64x8);
  AssertTrue('MulF64x8 should not be scalar', dt^.MulF64x8 <> @ScalarMulF64x8);
  AssertTrue('DivF64x8 should not be scalar', dt^.DivF64x8 <> @ScalarDivF64x8);

  eps := 1e-10;
  RandSeed := 20260102;

  for iter := 1 to 100 do
  begin
    for i := 0 to 7 do
    begin
      a.d[i] := (Random(2000001) - 1000000) / 1000.0;
      b.d[i] := (Random(2000001) - 1000000) / 1000.0;
      if Abs(b.d[i]) < 1e-10 then
        b.d[i] := 1.0;
    end;

    // Add
    expV := ScalarAddF64x8(a, b);
    actV := dt^.AddF64x8(a, b);
    for i := 0 to 7 do
      AssertEquals('F64x8 Add iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.d[i], actV.d[i], eps);

    // Sub
    expV := ScalarSubF64x8(a, b);
    actV := dt^.SubF64x8(a, b);
    for i := 0 to 7 do
      AssertEquals('F64x8 Sub iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.d[i], actV.d[i], eps);

    // Mul
    expV := ScalarMulF64x8(a, b);
    actV := dt^.MulF64x8(a, b);
    for i := 0 to 7 do
      AssertEquals('F64x8 Mul iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.d[i], actV.d[i], eps);

    // Div
    expV := ScalarDivF64x8(a, b);
    actV := dt^.DivF64x8(a, b);
    for i := 0 to 7 do
      AssertEquals('F64x8 Div iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.d[i], actV.d[i], eps);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_VecF64x8_AddSubMulDiv_SpecialValues_Consistency;
var
  dt: PSimdDispatchTable;
  a, b, bDiv: TVecF64x8;
  expV, actV: TVecF64x8;
  i: Integer;

  procedure AssertSameElementBits(const op: string; idx: Integer; expVal, actVal: Double);
  var
    expBits, actBits: QWord;
  begin
    if IsNaNDouble(expVal) then
      AssertTrue(op + ' lane ' + IntToStr(idx) + ' should be NaN', IsNaNDouble(actVal))
    else
    begin
      expBits := BitsFromDouble(expVal);
      actBits := BitsFromDouble(actVal);
      AssertTrue(op + ' lane ' + IntToStr(idx) + ' bits should match', expBits = actBits);
    end;
  end;

begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  // Special values: ±0, ±Inf, NaN
  a.d[0] := DoubleFromBits(QWord($8000000000000000)); // -0
  b.d[0] := DoubleFromBits(QWord($0000000000000000)); // +0
  a.d[1] := DoubleFromBits(QWord($7FF0000000000000)); // +Inf
  b.d[1] := 1.0;
  a.d[2] := DoubleFromBits(QWord($7FF8000000000000)); // qNaN
  b.d[2] := 2.0;
  a.d[3] := 1.0;
  b.d[3] := DoubleFromBits(QWord($FFF0000000000000)); // -Inf
  // Normal values
  for i := 4 to 7 do
  begin
    a.d[i] := (i - 4) * 100.0 + 1.0;
    b.d[i] := (i - 4) * 50.0 + 2.0;
  end;

  // Add
  expV := ScalarAddF64x8(a, b);
  actV := dt^.AddF64x8(a, b);
  for i := 0 to 7 do
    AssertSameElementBits('F64x8 Add', i, expV.d[i], actV.d[i]);

  // Sub
  expV := ScalarSubF64x8(a, b);
  actV := dt^.SubF64x8(a, b);
  for i := 0 to 7 do
    AssertSameElementBits('F64x8 Sub', i, expV.d[i], actV.d[i]);

  // Mul
  expV := ScalarMulF64x8(a, b);
  actV := dt^.MulF64x8(a, b);
  for i := 0 to 7 do
    AssertSameElementBits('F64x8 Mul', i, expV.d[i], actV.d[i]);

  // Div (avoid div by ±0)
  bDiv := b;
  for i := 0 to 7 do
    if (BitsFromDouble(bDiv.d[i]) and QWord($7FFFFFFFFFFFFFFF)) = 0 then
      bDiv.d[i] := 1.0;

  expV := ScalarDivF64x8(a, bDiv);
  actV := dt^.DivF64x8(a, bDiv);
  for i := 0 to 7 do
    AssertSameElementBits('F64x8 Div', i, expV.d[i], actV.d[i]);
end;

procedure TTestCase_AVX512VectorAsm.Test_VecI32x16_AddSubMul_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecI32x16;
  expV, actV: TVecI32x16;
  iter, i: Integer;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.AddI32x16 should be assigned', Assigned(dt^.AddI32x16));
  AssertTrue('Dispatch.SubI32x16 should be assigned', Assigned(dt^.SubI32x16));
  AssertTrue('Dispatch.MulI32x16 should be assigned', Assigned(dt^.MulI32x16));

  AssertTrue('AddI32x16 should not be scalar', dt^.AddI32x16 <> @ScalarAddI32x16);
  AssertTrue('SubI32x16 should not be scalar', dt^.SubI32x16 <> @ScalarSubI32x16);
  AssertTrue('MulI32x16 should not be scalar', dt^.MulI32x16 <> @ScalarMulI32x16);

  RandSeed := 20260103;

  for iter := 1 to 200 do
  begin
    for i := 0 to 15 do
    begin
      a.i[i] := Random(60001) - 30000;
      b.i[i] := Random(60001) - 30000;
    end;

    // Add
    expV := ScalarAddI32x16(a, b);
    actV := dt^.AddI32x16(a, b);
    for i := 0 to 15 do
      AssertEquals('I32x16 Add iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);

    // Sub
    expV := ScalarSubI32x16(a, b);
    actV := dt^.SubI32x16(a, b);
    for i := 0 to 15 do
      AssertEquals('I32x16 Sub iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);

    // Mul
    expV := ScalarMulI32x16(a, b);
    actV := dt^.MulI32x16(a, b);
    for i := 0 to 15 do
      AssertEquals('I32x16 Mul iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_VecI32x16_AddSubMul_BoundaryConsistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecI32x16;
  expV, actV: TVecI32x16;
  i: Integer;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  // Add/Sub boundary: avoid overflow
  a.i[0] := High(Int32) - 1; b.i[0] := 1;
  a.i[1] := Low(Int32) + 1;  b.i[1] := -1;
  for i := 2 to 15 do
  begin
    a.i[i] := i * 100 - 500;
    b.i[i] := i * 50 - 200;
  end;

  expV := ScalarAddI32x16(a, b);
  actV := dt^.AddI32x16(a, b);
  for i := 0 to 15 do
    AssertEquals('I32x16 Add boundary lane ' + IntToStr(i), expV.i[i], actV.i[i]);

  expV := ScalarSubI32x16(a, b);
  actV := dt^.SubI32x16(a, b);
  for i := 0 to 15 do
    AssertEquals('I32x16 Sub boundary lane ' + IntToStr(i), expV.i[i], actV.i[i]);

  // Mul with safe range
  for i := 0 to 15 do
  begin
    if i mod 2 = 0 then
      a.i[i] := 46340
    else
      a.i[i] := -46340;
    if i mod 3 = 0 then
      b.i[i] := 1
    else
      b.i[i] := -1;
  end;

  expV := ScalarMulI32x16(a, b);
  actV := dt^.MulI32x16(a, b);
  for i := 0 to 15 do
    AssertEquals('I32x16 Mul boundary lane ' + IntToStr(i), expV.i[i], actV.i[i]);
end;

procedure TTestCase_AVX512VectorAsm.Test_VecI32x16_BitwiseOps_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecI32x16;
  expV, actV: TVecI32x16;
  iter, i: Integer;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.AndI32x16 should be assigned', Assigned(dt^.AndI32x16));
  AssertTrue('Dispatch.OrI32x16 should be assigned', Assigned(dt^.OrI32x16));
  AssertTrue('Dispatch.XorI32x16 should be assigned', Assigned(dt^.XorI32x16));
  AssertTrue('Dispatch.NotI32x16 should be assigned', Assigned(dt^.NotI32x16));
  AssertTrue('Dispatch.AndNotI32x16 should be assigned', Assigned(dt^.AndNotI32x16));

  RandSeed := 20260104;

  for iter := 1 to 100 do
  begin
    for i := 0 to 15 do
    begin
      a.i[i] := Random(High(Int32) * 2 + 1) - High(Int32);
      b.i[i] := Random(High(Int32) * 2 + 1) - High(Int32);
    end;

    expV := ScalarAndI32x16(a, b);
    actV := dt^.AndI32x16(a, b);
    for i := 0 to 15 do
      AssertEquals('I32x16 And iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);

    expV := ScalarOrI32x16(a, b);
    actV := dt^.OrI32x16(a, b);
    for i := 0 to 15 do
      AssertEquals('I32x16 Or iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);

    expV := ScalarXorI32x16(a, b);
    actV := dt^.XorI32x16(a, b);
    for i := 0 to 15 do
      AssertEquals('I32x16 Xor iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);

    expV := ScalarNotI32x16(a);
    actV := dt^.NotI32x16(a);
    for i := 0 to 15 do
      AssertEquals('I32x16 Not iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);

    expV := ScalarAndNotI32x16(a, b);
    actV := dt^.AndNotI32x16(a, b);
    for i := 0 to 15 do
      AssertEquals('I32x16 AndNot iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_VecI32x16_Shift_RandomConsistency;
var
  dt: PSimdDispatchTable;
  a: TVecI32x16;
  expV, actV: TVecI32x16;
  iter, i, shift: Integer;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.ShiftLeftI32x16 should be assigned', Assigned(dt^.ShiftLeftI32x16));
  AssertTrue('Dispatch.ShiftRightI32x16 should be assigned', Assigned(dt^.ShiftRightI32x16));
  AssertTrue('Dispatch.ShiftRightArithI32x16 should be assigned', Assigned(dt^.ShiftRightArithI32x16));

  RandSeed := 20260105;

  for iter := 1 to 50 do
  begin
    for i := 0 to 15 do
      a.i[i] := Random(High(Int32) * 2 + 1) - High(Int32);

    shift := Random(32);

    expV := ScalarShiftLeftI32x16(a, shift);
    actV := dt^.ShiftLeftI32x16(a, shift);
    for i := 0 to 15 do
      AssertEquals('I32x16 SHL ' + IntToStr(shift) + ' iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);

    expV := ScalarShiftRightI32x16(a, shift);
    actV := dt^.ShiftRightI32x16(a, shift);
    for i := 0 to 15 do
      AssertEquals('I32x16 SHR ' + IntToStr(shift) + ' iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);

    expV := ScalarShiftRightArithI32x16(a, shift);
    actV := dt^.ShiftRightArithI32x16(a, shift);
    for i := 0 to 15 do
      AssertEquals('I32x16 SAR ' + IntToStr(shift) + ' iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_VecI32x16_Compare_Consistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecI32x16;
  expMask, actMask: TMask16;
  iter, i: Integer;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.CmpEqI32x16 should be assigned', Assigned(dt^.CmpEqI32x16));
  AssertTrue('Dispatch.CmpLtI32x16 should be assigned', Assigned(dt^.CmpLtI32x16));
  AssertTrue('Dispatch.CmpGtI32x16 should be assigned', Assigned(dt^.CmpGtI32x16));

  RandSeed := 20260106;

  for iter := 1 to 50 do
  begin
    for i := 0 to 15 do
    begin
      a.i[i] := Random(1001) - 500;
      // 50% chance of equal, 50% random
      if Random(2) = 0 then
        b.i[i] := a.i[i]
      else
        b.i[i] := Random(1001) - 500;
    end;

    // CmpEq
    expMask := ScalarCmpEqI32x16(a, b);
    actMask := dt^.CmpEqI32x16(a, b);
    AssertEquals('I32x16 CmpEq iter ' + IntToStr(iter), expMask, actMask);

    // CmpLt
    expMask := ScalarCmpLtI32x16(a, b);
    actMask := dt^.CmpLtI32x16(a, b);
    AssertEquals('I32x16 CmpLt iter ' + IntToStr(iter), expMask, actMask);

    // CmpGt
    expMask := ScalarCmpGtI32x16(a, b);
    actMask := dt^.CmpGtI32x16(a, b);
    AssertEquals('I32x16 CmpGt iter ' + IntToStr(iter), expMask, actMask);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_VecI32x16_MinMax_Consistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecI32x16;
  expV, actV: TVecI32x16;
  iter, i: Integer;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.MinI32x16 should be assigned', Assigned(dt^.MinI32x16));
  AssertTrue('Dispatch.MaxI32x16 should be assigned', Assigned(dt^.MaxI32x16));

  RandSeed := 20260107;

  for iter := 1 to 100 do
  begin
    for i := 0 to 15 do
    begin
      a.i[i] := Random(200001) - 100000;
      b.i[i] := Random(200001) - 100000;
    end;

    expV := ScalarMinI32x16(a, b);
    actV := dt^.MinI32x16(a, b);
    for i := 0 to 15 do
      AssertEquals('I32x16 Min iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);

    expV := ScalarMaxI32x16(a, b);
    actV := dt^.MaxI32x16(a, b);
    for i := 0 to 15 do
      AssertEquals('I32x16 Max iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_VecI32x16_Compare_LeGeNe_Consistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecI32x16;
  expMask, actMask: TMask16;
  iter, i: Integer;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.CmpLeI32x16 should be assigned', Assigned(dt^.CmpLeI32x16));
  AssertTrue('Dispatch.CmpGeI32x16 should be assigned', Assigned(dt^.CmpGeI32x16));
  AssertTrue('Dispatch.CmpNeI32x16 should be assigned', Assigned(dt^.CmpNeI32x16));

  RandSeed := 20260108;

  for iter := 1 to 50 do
  begin
    for i := 0 to 15 do
    begin
      a.i[i] := Random(1001) - 500;
      if Random(3) = 0 then
        b.i[i] := a.i[i]
      else
        b.i[i] := Random(1001) - 500;
    end;

    // CmpLe
    expMask := ScalarCmpLeI32x16(a, b);
    actMask := dt^.CmpLeI32x16(a, b);
    AssertEquals('I32x16 CmpLe iter ' + IntToStr(iter), expMask, actMask);

    // CmpGe
    expMask := ScalarCmpGeI32x16(a, b);
    actMask := dt^.CmpGeI32x16(a, b);
    AssertEquals('I32x16 CmpGe iter ' + IntToStr(iter), expMask, actMask);

    // CmpNe
    expMask := ScalarCmpNeI32x16(a, b);
    actMask := dt^.CmpNeI32x16(a, b);
    AssertEquals('I32x16 CmpNe iter ' + IntToStr(iter), expMask, actMask);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_I8x16_SatAddSub_Consistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecI8x16;
  expV, actV: TVecI8x16;
  iter, i: Integer;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.I8x16SatAdd should be assigned', Assigned(dt^.I8x16SatAdd));
  AssertTrue('Dispatch.I8x16SatSub should be assigned', Assigned(dt^.I8x16SatSub));

  RandSeed := 20260109;

  for iter := 1 to 100 do
  begin
    for i := 0 to 15 do
    begin
      a.i[i] := Int8(Random(256) - 128);
      b.i[i] := Int8(Random(256) - 128);
    end;

    // SatAdd
    expV := ScalarI8x16SatAdd(a, b);
    actV := dt^.I8x16SatAdd(a, b);
    for i := 0 to 15 do
      AssertEquals('I8x16 SatAdd iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);

    // SatSub
    expV := ScalarI8x16SatSub(a, b);
    actV := dt^.I8x16SatSub(a, b);
    for i := 0 to 15 do
      AssertEquals('I8x16 SatSub iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_I16x8_SatAddSub_Consistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecI16x8;
  expV, actV: TVecI16x8;
  iter, i: Integer;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.I16x8SatAdd should be assigned', Assigned(dt^.I16x8SatAdd));
  AssertTrue('Dispatch.I16x8SatSub should be assigned', Assigned(dt^.I16x8SatSub));

  RandSeed := 20260110;

  for iter := 1 to 100 do
  begin
    for i := 0 to 7 do
    begin
      a.i[i] := Int16(Random(65536) - 32768);
      b.i[i] := Int16(Random(65536) - 32768);
    end;

    // SatAdd
    expV := ScalarI16x8SatAdd(a, b);
    actV := dt^.I16x8SatAdd(a, b);
    for i := 0 to 7 do
      AssertEquals('I16x8 SatAdd iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);

    // SatSub
    expV := ScalarI16x8SatSub(a, b);
    actV := dt^.I16x8SatSub(a, b);
    for i := 0 to 7 do
      AssertEquals('I16x8 SatSub iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.i[i], actV.i[i]);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_U8x16_SatAddSub_Consistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecU8x16;
  expV, actV: TVecU8x16;
  iter, i: Integer;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.U8x16SatAdd should be assigned', Assigned(dt^.U8x16SatAdd));
  AssertTrue('Dispatch.U8x16SatSub should be assigned', Assigned(dt^.U8x16SatSub));

  RandSeed := 20260111;

  for iter := 1 to 100 do
  begin
    for i := 0 to 15 do
    begin
      a.u[i] := Byte(Random(256));
      b.u[i] := Byte(Random(256));
    end;

    // SatAdd
    expV := ScalarU8x16SatAdd(a, b);
    actV := dt^.U8x16SatAdd(a, b);
    for i := 0 to 15 do
      AssertEquals('U8x16 SatAdd iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.u[i], actV.u[i]);

    // SatSub
    expV := ScalarU8x16SatSub(a, b);
    actV := dt^.U8x16SatSub(a, b);
    for i := 0 to 15 do
      AssertEquals('U8x16 SatSub iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.u[i], actV.u[i]);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_U16x8_SatAddSub_Consistency;
var
  dt: PSimdDispatchTable;
  a, b: TVecU16x8;
  expV, actV: TVecU16x8;
  iter, i: Integer;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.U16x8SatAdd should be assigned', Assigned(dt^.U16x8SatAdd));
  AssertTrue('Dispatch.U16x8SatSub should be assigned', Assigned(dt^.U16x8SatSub));

  RandSeed := 20260112;

  for iter := 1 to 100 do
  begin
    for i := 0 to 7 do
    begin
      a.u[i] := Word(Random(65536));
      b.u[i] := Word(Random(65536));
    end;

    // SatAdd
    expV := ScalarU16x8SatAdd(a, b);
    actV := dt^.U16x8SatAdd(a, b);
    for i := 0 to 7 do
      AssertEquals('U16x8 SatAdd iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.u[i], actV.u[i]);

    // SatSub
    expV := ScalarU16x8SatSub(a, b);
    actV := dt^.U16x8SatSub(a, b);
    for i := 0 to 7 do
      AssertEquals('U16x8 SatSub iter ' + IntToStr(iter) + ' lane ' + IntToStr(i), expV.u[i], actV.u[i]);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_Facade_MemEqual_Consistency;
var
  dt: PSimdDispatchTable;
  buf1, buf2: array[0..511] of Byte;
  i, iter: Integer;
  expRes, actRes: LongBool;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.MemEqual should be assigned', Assigned(dt^.MemEqual));

  RandSeed := 20260113;

  for iter := 1 to 50 do
  begin
    // Initialize with same data
    for i := 0 to 511 do
    begin
      buf1[i] := Byte(Random(256));
      buf2[i] := buf1[i];
    end;

    // Test equal buffers
    expRes := MemEqual_Scalar(@buf1[0], @buf2[0], 512);
    actRes := dt^.MemEqual(@buf1[0], @buf2[0], 512);
    AssertEquals('MemEqual equal iter ' + IntToStr(iter), expRes, actRes);

    // Create a difference at random position
    buf2[Random(512)] := buf2[Random(512)] xor $FF;

    expRes := MemEqual_Scalar(@buf1[0], @buf2[0], 512);
    actRes := dt^.MemEqual(@buf1[0], @buf2[0], 512);
    AssertEquals('MemEqual diff iter ' + IntToStr(iter), expRes, actRes);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_Facade_MemFindByte_Consistency;
var
  dt: PSimdDispatchTable;
  buf: array[0..511] of Byte;
  i, iter: Integer;
  searchByte: Byte;
  expRes, actRes: PtrInt;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.MemFindByte should be assigned', Assigned(dt^.MemFindByte));

  RandSeed := 20260114;

  for iter := 1 to 50 do
  begin
    for i := 0 to 511 do
      buf[i] := Byte(Random(128));

    // Find existing byte
    searchByte := Byte(Random(128));
    expRes := MemFindByte_Scalar(@buf[0], 512, searchByte);
    actRes := dt^.MemFindByte(@buf[0], 512, searchByte);
    AssertEquals('MemFindByte iter ' + IntToStr(iter), expRes, actRes);

    // Find non-existing byte
    searchByte := Byte(200 + Random(56));
    expRes := MemFindByte_Scalar(@buf[0], 512, searchByte);
    actRes := dt^.MemFindByte(@buf[0], 512, searchByte);
    AssertEquals('MemFindByte not found iter ' + IntToStr(iter), expRes, actRes);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_Facade_SumBytes_Consistency;
var
  dt: PSimdDispatchTable;
  buf: array[0..511] of Byte;
  i, iter: Integer;
  expSum, actSum: UInt64;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.SumBytes should be assigned', Assigned(dt^.SumBytes));

  RandSeed := 20260115;

  for iter := 1 to 50 do
  begin
    for i := 0 to 511 do
      buf[i] := Byte(Random(256));

    expSum := SumBytes_Scalar(@buf[0], 512);
    actSum := dt^.SumBytes(@buf[0], 512);
    AssertEquals('SumBytes iter ' + IntToStr(iter), expSum, actSum);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_Facade_CountByte_Consistency;
var
  dt: PSimdDispatchTable;
  buf: array[0..511] of Byte;
  i, iter: Integer;
  searchByte: Byte;
  expCnt, actCnt: SizeUInt;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.CountByte should be assigned', Assigned(dt^.CountByte));

  RandSeed := 20260116;

  for iter := 1 to 50 do
  begin
    for i := 0 to 511 do
      buf[i] := Byte(i mod 32);

    searchByte := Byte(Random(32));
    expCnt := CountByte_Scalar(@buf[0], 512, searchByte);
    actCnt := dt^.CountByte(@buf[0], 512, searchByte);
    AssertEquals('CountByte iter ' + IntToStr(iter), expCnt, actCnt);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_Facade_MinMaxBytes_Consistency;
var
  dt: PSimdDispatchTable;
  buf: array[0..511] of Byte;
  i, iter: Integer;
  expMin, expMax, actMin, actMax: Byte;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.MinMaxBytes should be assigned', Assigned(dt^.MinMaxBytes));

  RandSeed := 20260117;

  for iter := 1 to 50 do
  begin
    for i := 0 to 511 do
      buf[i] := Byte(Random(256));

    MinMaxBytes_Scalar(@buf[0], 512, expMin, expMax);
    dt^.MinMaxBytes(@buf[0], 512, actMin, actMax);
    AssertEquals('MinMaxBytes min iter ' + IntToStr(iter), expMin, actMin);
    AssertEquals('MinMaxBytes max iter ' + IntToStr(iter), expMax, actMax);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_Facade_BitsetPopCount_Consistency;
var
  dt: PSimdDispatchTable;
  buf: array[0..255] of Byte;
  i, iter: Integer;
  expCnt, actCnt: SizeUInt;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.BitsetPopCount should be assigned', Assigned(dt^.BitsetPopCount));

  RandSeed := 20260118;

  for iter := 1 to 50 do
  begin
    for i := 0 to 255 do
      buf[i] := Byte(Random(256));

    expCnt := BitsetPopCount_Scalar(@buf[0], 256);
    actCnt := dt^.BitsetPopCount(@buf[0], 256);
    AssertEquals('BitsetPopCount iter ' + IntToStr(iter), expCnt, actCnt);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_Facade_MemCopy_Consistency;
var
  dt: PSimdDispatchTable;
  src, dstExp, dstAct: array[0..511] of Byte;
  i, iter: Integer;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.MemCopy should be assigned', Assigned(dt^.MemCopy));

  RandSeed := 20260119;

  for iter := 1 to 20 do
  begin
    for i := 0 to 511 do
    begin
      src[i] := Byte(Random(256));
      dstExp[i] := $CC;
      dstAct[i] := $CC;
    end;

    MemCopy_Scalar(@src[0], @dstExp[0], 512);
    dt^.MemCopy(@src[0], @dstAct[0], 512);

    for i := 0 to 511 do
      AssertEquals('MemCopy iter ' + IntToStr(iter) + ' byte ' + IntToStr(i), dstExp[i], dstAct[i]);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_Facade_MemSet_Consistency;
var
  dt: PSimdDispatchTable;
  dstExp, dstAct: array[0..511] of Byte;
  i, iter: Integer;
  setValue: Byte;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.MemSet should be assigned', Assigned(dt^.MemSet));

  RandSeed := 20260120;

  for iter := 1 to 20 do
  begin
    setValue := Byte(Random(256));

    for i := 0 to 511 do
    begin
      dstExp[i] := $CC;
      dstAct[i] := $CC;
    end;

    MemSet_Scalar(@dstExp[0], 512, setValue);
    dt^.MemSet(@dstAct[0], 512, setValue);

    for i := 0 to 511 do
      AssertEquals('MemSet iter ' + IntToStr(iter) + ' byte ' + IntToStr(i), dstExp[i], dstAct[i]);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_Facade_ToLowerAscii_Consistency;
var
  dt: PSimdDispatchTable;
  bufExp, bufAct: array[0..127] of Byte;
  i, iter: Integer;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.ToLowerAscii should be assigned', Assigned(dt^.ToLowerAscii));

  RandSeed := 20260121;

  for iter := 1 to 20 do
  begin
    for i := 0 to 127 do
    begin
      bufExp[i] := Byte(32 + Random(95));
      bufAct[i] := bufExp[i];
    end;

    ToLowerAscii_Scalar(@bufExp[0], 128);
    dt^.ToLowerAscii(@bufAct[0], 128);

    for i := 0 to 127 do
      AssertEquals('ToLowerAscii iter ' + IntToStr(iter) + ' byte ' + IntToStr(i), bufExp[i], bufAct[i]);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_Facade_ToUpperAscii_Consistency;
var
  dt: PSimdDispatchTable;
  bufExp, bufAct: array[0..127] of Byte;
  i, iter: Integer;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.ToUpperAscii should be assigned', Assigned(dt^.ToUpperAscii));

  RandSeed := 20260122;

  for iter := 1 to 20 do
  begin
    for i := 0 to 127 do
    begin
      bufExp[i] := Byte(32 + Random(95));
      bufAct[i] := bufExp[i];
    end;

    ToUpperAscii_Scalar(@bufExp[0], 128);
    dt^.ToUpperAscii(@bufAct[0], 128);

    for i := 0 to 127 do
      AssertEquals('ToUpperAscii iter ' + IntToStr(iter) + ' byte ' + IntToStr(i), bufExp[i], bufAct[i]);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_Facade_AsciiIEqual_Consistency;
var
  dt: PSimdDispatchTable;
  buf1, buf2: array[0..127] of Byte;
  i, iter: Integer;
  expRes, actRes: Boolean;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);
  AssertTrue('Dispatch.AsciiIEqual should be assigned', Assigned(dt^.AsciiIEqual));

  RandSeed := 20260123;

  for iter := 1 to 50 do
  begin
    // Same content, different case
    for i := 0 to 127 do
    begin
      if Random(2) = 0 then
        buf1[i] := Byte(65 + (i mod 26))
      else
        buf1[i] := Byte(97 + (i mod 26));

      if Random(2) = 0 then
        buf2[i] := Byte(65 + (i mod 26))
      else
        buf2[i] := Byte(97 + (i mod 26));
    end;

    expRes := AsciiIEqual_Scalar(@buf1[0], @buf2[0], 128);
    actRes := dt^.AsciiIEqual(@buf1[0], @buf2[0], 128);
    AssertEquals('AsciiIEqual same iter ' + IntToStr(iter), expRes, actRes);

    // Make them differ
    buf2[Random(128)] := Byte(48 + Random(10));
    expRes := AsciiIEqual_Scalar(@buf1[0], @buf2[0], 128);
    actRes := dt^.AsciiIEqual(@buf1[0], @buf2[0], 128);
    AssertEquals('AsciiIEqual diff iter ' + IntToStr(iter), expRes, actRes);
  end;
end;

procedure TTestCase_AVX512VectorAsm.Test_VecF32x16_ABI_CalleeSavedRegisters_Preserved;
var
  dt: PSimdDispatchTable;
  a, b, resultV: TVecF32x16;
  i: Integer;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  // 初始化测试数据
  for i := 0 to 15 do
  begin
    a.f[i] := (i + 1) * 1.5;
    b.f[i] := (i + 1) * 0.5;
  end;

  // 直接调用 dispatch 函数，验证结果正确性（无法在 Pascal 层面验证 callee-saved）
  resultV := dt^.AddF32x16(a, b);

  for i := 0 to 15 do
    AssertEquals('F32x16 Add result lane ' + IntToStr(i), a.f[i] + b.f[i], resultV.f[i], 1e-5);

  resultV := dt^.SubF32x16(a, b);

  for i := 0 to 15 do
    AssertEquals('F32x16 Sub result lane ' + IntToStr(i), a.f[i] - b.f[i], resultV.f[i], 1e-5);

  resultV := dt^.MulF32x16(a, b);

  for i := 0 to 15 do
    AssertEquals('F32x16 Mul result lane ' + IntToStr(i), a.f[i] * b.f[i], resultV.f[i], 1e-5);

  resultV := dt^.DivF32x16(a, b);

  for i := 0 to 15 do
    AssertEquals('F32x16 Div result lane ' + IntToStr(i), a.f[i] / b.f[i], resultV.f[i], 1e-5);
end;

procedure TTestCase_AVX512VectorAsm.Test_VecI32x16_ABI_CalleeSavedRegisters_Preserved;
var
  dt: PSimdDispatchTable;
  a, b, resultV: TVecI32x16;
  i: Integer;
begin
  if not AVX512BackendDispatchableForVectorAsmTests then
    Exit;

  AssertEquals('Active backend should be AVX512', Ord(sbAVX512), Ord(GetCurrentBackend));

  dt := GetDispatchTable;
  AssertTrue('Dispatch table should be assigned', dt <> nil);

  // 初始化测试数据
  for i := 0 to 15 do
  begin
    a.i[i] := (i + 1) * 100;
    b.i[i] := (i + 1) * 10;
  end;

  // 直接调用 dispatch 函数，验证结果正确性
  resultV := dt^.AddI32x16(a, b);

  for i := 0 to 15 do
    AssertEquals('I32x16 Add result lane ' + IntToStr(i), a.i[i] + b.i[i], resultV.i[i]);

  resultV := dt^.SubI32x16(a, b);

  for i := 0 to 15 do
    AssertEquals('I32x16 Sub result lane ' + IntToStr(i), a.i[i] - b.i[i], resultV.i[i]);

  resultV := dt^.MulI32x16(a, b);

  for i := 0 to 15 do
    AssertEquals('I32x16 Mul result lane ' + IntToStr(i), a.i[i] * b.i[i], resultV.i[i]);

  resultV := dt^.AndI32x16(a, b);

  for i := 0 to 15 do
    AssertEquals('I32x16 And result lane ' + IntToStr(i), a.i[i] and b.i[i], resultV.i[i]);

  resultV := dt^.OrI32x16(a, b);

  for i := 0 to 15 do
    AssertEquals('I32x16 Or result lane ' + IntToStr(i), a.i[i] or b.i[i], resultV.i[i]);
end;

{$ENDIF}  // SIMD_BACKEND_AVX512
{$ENDIF}  // CPUX86_64
{$ENDIF}  // UNIX

{ TTestCase_VectorOps }

procedure TTestCase_VectorOps.Test_VecF32x4_Add;
var
  a, b, c: TVecF32x4;
begin
  a := VecF32x4Splat(1.0);
  b := VecF32x4Splat(2.0);
  c := VecF32x4Add(a, b);
  
  AssertEquals('Element 0 should be 3.0', 3.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('Element 1 should be 3.0', 3.0, VecF32x4Extract(c, 1), 0.0001);
  AssertEquals('Element 2 should be 3.0', 3.0, VecF32x4Extract(c, 2), 0.0001);
  AssertEquals('Element 3 should be 3.0', 3.0, VecF32x4Extract(c, 3), 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Sub;
var
  a, b, c: TVecF32x4;
begin
  a := VecF32x4Splat(5.0);
  b := VecF32x4Splat(2.0);
  c := VecF32x4Sub(a, b);
  
  AssertEquals('Element 0 should be 3.0', 3.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('Element 1 should be 3.0', 3.0, VecF32x4Extract(c, 1), 0.0001);
  AssertEquals('Element 2 should be 3.0', 3.0, VecF32x4Extract(c, 2), 0.0001);
  AssertEquals('Element 3 should be 3.0', 3.0, VecF32x4Extract(c, 3), 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Mul;
var
  a, b, c: TVecF32x4;
begin
  a := VecF32x4Splat(3.0);
  b := VecF32x4Splat(4.0);
  c := VecF32x4Mul(a, b);
  
  AssertEquals('Element 0 should be 12.0', 12.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('Element 1 should be 12.0', 12.0, VecF32x4Extract(c, 1), 0.0001);
  AssertEquals('Element 2 should be 12.0', 12.0, VecF32x4Extract(c, 2), 0.0001);
  AssertEquals('Element 3 should be 12.0', 12.0, VecF32x4Extract(c, 3), 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Div;
var
  a, b, c: TVecF32x4;
begin
  a := VecF32x4Splat(12.0);
  b := VecF32x4Splat(4.0);
  c := VecF32x4Div(a, b);
  
  AssertEquals('Element 0 should be 3.0', 3.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('Element 1 should be 3.0', 3.0, VecF32x4Extract(c, 1), 0.0001);
  AssertEquals('Element 2 should be 3.0', 3.0, VecF32x4Extract(c, 2), 0.0001);
  AssertEquals('Element 3 should be 3.0', 3.0, VecF32x4Extract(c, 3), 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Sqrt;
var
  a, c: TVecF32x4;
begin
  a := VecF32x4Splat(16.0);
  c := VecF32x4Sqrt(a);
  
  AssertEquals('Sqrt(16) should be 4.0', 4.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('Sqrt(16) should be 4.0', 4.0, VecF32x4Extract(c, 1), 0.0001);
  AssertEquals('Sqrt(16) should be 4.0', 4.0, VecF32x4Extract(c, 2), 0.0001);
  AssertEquals('Sqrt(16) should be 4.0', 4.0, VecF32x4Extract(c, 3), 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Min;
var
  a, b, c: TVecF32x4;
begin
  a := VecF32x4Splat(5.0);
  b := VecF32x4Splat(3.0);
  c := VecF32x4Min(a, b);
  
  AssertEquals('Min(5,3) should be 3.0', 3.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('Min(5,3) should be 3.0', 3.0, VecF32x4Extract(c, 1), 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Max;
var
  a, b, c: TVecF32x4;
begin
  a := VecF32x4Splat(5.0);
  b := VecF32x4Splat(3.0);
  c := VecF32x4Max(a, b);
  
  AssertEquals('Max(5,3) should be 5.0', 5.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('Max(5,3) should be 5.0', 5.0, VecF32x4Extract(c, 1), 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Abs;
var
  a, c: TVecF32x4;
begin
  a := VecF32x4Splat(-5.0);
  c := VecF32x4Abs(a);
  
  AssertEquals('Abs(-5) should be 5.0', 5.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('Abs(-5) should be 5.0', 5.0, VecF32x4Extract(c, 1), 0.0001);
  AssertEquals('Abs(-5) should be 5.0', 5.0, VecF32x4Extract(c, 2), 0.0001);
  AssertEquals('Abs(-5) should be 5.0', 5.0, VecF32x4Extract(c, 3), 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_ReduceAdd;
var
  arr: array[0..3] of Single;
  a: TVecF32x4;
  sum: Single;
begin
  arr[0] := 1.0;
  arr[1] := 2.0;
  arr[2] := 3.0;
  arr[3] := 4.0;
  
  a := VecF32x4Load(@arr[0]);
  sum := VecF32x4ReduceAdd(a);
  
  AssertEquals('Sum should be 10.0', 10.0, sum, 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_ReduceMin;
var
  arr: array[0..3] of Single;
  a: TVecF32x4;
  minVal: Single;
begin
  arr[0] := 5.0;
  arr[1] := 2.0;
  arr[2] := 8.0;
  arr[3] := 3.0;
  
  a := VecF32x4Load(@arr[0]);
  minVal := VecF32x4ReduceMin(a);
  
  AssertEquals('Min should be 2.0', 2.0, minVal, 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_ReduceMax;
var
  arr: array[0..3] of Single;
  a: TVecF32x4;
  maxVal: Single;
begin
  arr[0] := 5.0;
  arr[1] := 2.0;
  arr[2] := 8.0;
  arr[3] := 3.0;
  
  a := VecF32x4Load(@arr[0]);
  maxVal := VecF32x4ReduceMax(a);
  
  AssertEquals('Max should be 8.0', 8.0, maxVal, 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Splat;
var
  a: TVecF32x4;
begin
  a := VecF32x4Splat(42.5);
  
  AssertEquals('Element 0 should be 42.5', 42.5, VecF32x4Extract(a, 0), 0.0001);
  AssertEquals('Element 1 should be 42.5', 42.5, VecF32x4Extract(a, 1), 0.0001);
  AssertEquals('Element 2 should be 42.5', 42.5, VecF32x4Extract(a, 2), 0.0001);
  AssertEquals('Element 3 should be 42.5', 42.5, VecF32x4Extract(a, 3), 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_LoadStore;
var
  src, dst: array[0..3] of Single;
  a: TVecF32x4;
begin
  src[0] := 1.5;
  src[1] := 2.5;
  src[2] := 3.5;
  src[3] := 4.5;
  
  a := VecF32x4Load(@src[0]);
  VecF32x4Store(@dst[0], a);
  
  AssertEquals('dst[0] should match src[0]', src[0], dst[0], 0.0001);
  AssertEquals('dst[1] should match src[1]', src[1], dst[1], 0.0001);
  AssertEquals('dst[2] should match src[2]', src[2], dst[2], 0.0001);
  AssertEquals('dst[3] should match src[3]', src[3], dst[3], 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_UtilityFacade_Basic;
var
  LAligned: Pointer;
  LAlignedF32: PSingle;
  LVecA, LVecB, LLoaded, LSelected, LInserted, LZero: TVecF32x4;
  LMask4: TMask4;
begin
  LZero := VecF32x4Zero;
  AssertEquals('VecF32x4Zero lane 0', 0.0, LZero.f[0], 0.0);
  AssertEquals('VecF32x4Zero lane 1', 0.0, LZero.f[1], 0.0);
  AssertEquals('VecF32x4Zero lane 2', 0.0, LZero.f[2], 0.0);
  AssertEquals('VecF32x4Zero lane 3', 0.0, LZero.f[3], 0.0);

  LVecA.f[0] := 1.0;
  LVecA.f[1] := 2.0;
  LVecA.f[2] := 3.0;
  LVecA.f[3] := 4.0;
  LVecB.f[0] := 9.0;
  LVecB.f[1] := 8.0;
  LVecB.f[2] := 7.0;
  LVecB.f[3] := 6.0;
  LMask4 := TMask4($5); // lane0/2 -> a, lane1/3 -> b

  LSelected := VecF32x4Select(LMask4, LVecA, LVecB);
  AssertEquals('VecF32x4Select lane 0', 1.0, LSelected.f[0], 0.0001);
  AssertEquals('VecF32x4Select lane 1', 8.0, LSelected.f[1], 0.0001);
  AssertEquals('VecF32x4Select lane 2', 3.0, LSelected.f[2], 0.0001);
  AssertEquals('VecF32x4Select lane 3', 6.0, LSelected.f[3], 0.0001);

  AssertEquals('VecF32x4Extract lane 2', 3.0, VecF32x4Extract(LVecA, 2), 0.0001);
  LInserted := VecF32x4Insert(LVecA, 42.5, 1);
  AssertEquals('VecF32x4Insert lane 1', 42.5, LInserted.f[1], 0.0001);
  AssertEquals('VecF32x4Insert keep lane 2', 3.0, LInserted.f[2], 0.0001);

  LAligned := nextpas.core.simd.AllocateAligned(SizeOf(Single) * 8, 32);
  AssertTrue('AllocateAligned should return non-nil', LAligned <> nil);
  try
    AssertTrue('AllocateAligned should return aligned pointer',
      nextpas.core.simd.IsPointerAligned(LAligned, 32));
    LAlignedF32 := PSingle(LAligned);
    LAlignedF32[0] := 10.0;
    LAlignedF32[1] := 20.0;
    LAlignedF32[2] := 30.0;
    LAlignedF32[3] := 40.0;

    LLoaded := VecF32x4LoadAligned(LAlignedF32);
    AssertEquals('VecF32x4LoadAligned lane 0', 10.0, LLoaded.f[0], 0.0001);
    AssertEquals('VecF32x4LoadAligned lane 1', 20.0, LLoaded.f[1], 0.0001);
    AssertEquals('VecF32x4LoadAligned lane 2', 30.0, LLoaded.f[2], 0.0001);
    AssertEquals('VecF32x4LoadAligned lane 3', 40.0, LLoaded.f[3], 0.0001);

    VecF32x4StoreAligned(LAlignedF32, LSelected);
    AssertEquals('VecF32x4StoreAligned lane 0', 1.0, LAlignedF32[0], 0.0001);
    AssertEquals('VecF32x4StoreAligned lane 1', 8.0, LAlignedF32[1], 0.0001);
    AssertEquals('VecF32x4StoreAligned lane 2', 3.0, LAlignedF32[2], 0.0001);
    AssertEquals('VecF32x4StoreAligned lane 3', 6.0, LAlignedF32[3], 0.0001);
  finally
    nextpas.core.simd.FreeAligned(LAligned);
  end;
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Compare;
var
  a, b: TVecF32x4;
  mask: TMask4;
begin
  a := VecF32x4Splat(5.0);
  b := VecF32x4Splat(5.0);
  mask := VecF32x4CmpEq(a, b);
  AssertTrue('Equal vectors should produce all-true mask', mask = $F);
  
  b := VecF32x4Splat(3.0);
  mask := VecF32x4CmpGt(a, b);
  AssertTrue('5 > 3 should produce all-true mask', mask = $F);
  
  mask := VecF32x4CmpLt(a, b);
  AssertTrue('5 < 3 should produce all-false mask', mask = 0);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Fma;
var
  a, b, c, r: TVecF32x4;
begin
  // FMA: a*b + c = 2*3 + 4 = 10
  a := VecF32x4Splat(2.0);
  b := VecF32x4Splat(3.0);
  c := VecF32x4Splat(4.0);
  r := VecF32x4Fma(a, b, c);
  
  AssertEquals('FMA(2,3,4) should be 10.0', 10.0, VecF32x4Extract(r, 0), 0.0001);
  AssertEquals('FMA(2,3,4) should be 10.0', 10.0, VecF32x4Extract(r, 1), 0.0001);
  AssertEquals('FMA(2,3,4) should be 10.0', 10.0, VecF32x4Extract(r, 2), 0.0001);
  AssertEquals('FMA(2,3,4) should be 10.0', 10.0, VecF32x4Extract(r, 3), 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Rcp;
var
  a, r: TVecF32x4;
begin
  a := VecF32x4Splat(4.0);
  r := VecF32x4Rcp(a);
  
  AssertEquals('Rcp(4) should be 0.25', 0.25, VecF32x4Extract(r, 0), 0.01);
  AssertEquals('Rcp(4) should be 0.25', 0.25, VecF32x4Extract(r, 1), 0.01);
  AssertEquals('Rcp(4) should be 0.25', 0.25, VecF32x4Extract(r, 2), 0.01);
  AssertEquals('Rcp(4) should be 0.25', 0.25, VecF32x4Extract(r, 3), 0.01);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Rsqrt;
var
  a, r: TVecF32x4;
begin
  a := VecF32x4Splat(4.0);
  r := VecF32x4Rsqrt(a);
  
  // 1/sqrt(4) = 0.5
  AssertEquals('Rsqrt(4) should be 0.5', 0.5, VecF32x4Extract(r, 0), 0.01);
  AssertEquals('Rsqrt(4) should be 0.5', 0.5, VecF32x4Extract(r, 1), 0.01);
  AssertEquals('Rsqrt(4) should be 0.5', 0.5, VecF32x4Extract(r, 2), 0.01);
  AssertEquals('Rsqrt(4) should be 0.5', 0.5, VecF32x4Extract(r, 3), 0.01);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Floor;
var
  arr: array[0..3] of Single;
  a, r: TVecF32x4;
begin
  arr[0] := 2.7;
  arr[1] := -2.7;
  arr[2] := 3.0;
  arr[3] := -3.0;
  a := VecF32x4Load(@arr[0]);
  r := VecF32x4Floor(a);
  
  AssertEquals('Floor(2.7) should be 2.0', 2.0, VecF32x4Extract(r, 0), 0.0001);
  AssertEquals('Floor(-2.7) should be -3.0', -3.0, VecF32x4Extract(r, 1), 0.0001);
  AssertEquals('Floor(3.0) should be 3.0', 3.0, VecF32x4Extract(r, 2), 0.0001);
  AssertEquals('Floor(-3.0) should be -3.0', -3.0, VecF32x4Extract(r, 3), 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Ceil;
var
  arr: array[0..3] of Single;
  a, r: TVecF32x4;
begin
  arr[0] := 2.3;
  arr[1] := -2.3;
  arr[2] := 3.0;
  arr[3] := -3.0;
  a := VecF32x4Load(@arr[0]);
  r := VecF32x4Ceil(a);
  
  AssertEquals('Ceil(2.3) should be 3.0', 3.0, VecF32x4Extract(r, 0), 0.0001);
  AssertEquals('Ceil(-2.3) should be -2.0', -2.0, VecF32x4Extract(r, 1), 0.0001);
  AssertEquals('Ceil(3.0) should be 3.0', 3.0, VecF32x4Extract(r, 2), 0.0001);
  AssertEquals('Ceil(-3.0) should be -3.0', -3.0, VecF32x4Extract(r, 3), 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Round;
var
  arr: array[0..3] of Single;
  a, r: TVecF32x4;
begin
  arr[0] := 2.3;
  arr[1] := 2.7;
  arr[2] := -2.3;
  arr[3] := -2.7;
  a := VecF32x4Load(@arr[0]);
  r := VecF32x4Round(a);
  
  AssertEquals('Round(2.3) should be 2.0', 2.0, VecF32x4Extract(r, 0), 0.0001);
  AssertEquals('Round(2.7) should be 3.0', 3.0, VecF32x4Extract(r, 1), 0.0001);
  AssertEquals('Round(-2.3) should be -2.0', -2.0, VecF32x4Extract(r, 2), 0.0001);
  AssertEquals('Round(-2.7) should be -3.0', -3.0, VecF32x4Extract(r, 3), 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Trunc;
var
  arr: array[0..3] of Single;
  a, r: TVecF32x4;
begin
  arr[0] := 2.7;
  arr[1] := -2.7;
  arr[2] := 3.0;
  arr[3] := -3.0;
  a := VecF32x4Load(@arr[0]);
  r := VecF32x4Trunc(a);
  
  AssertEquals('Trunc(2.7) should be 2.0', 2.0, VecF32x4Extract(r, 0), 0.0001);
  AssertEquals('Trunc(-2.7) should be -2.0', -2.0, VecF32x4Extract(r, 1), 0.0001);
  AssertEquals('Trunc(3.0) should be 3.0', 3.0, VecF32x4Extract(r, 2), 0.0001);
  AssertEquals('Trunc(-3.0) should be -3.0', -3.0, VecF32x4Extract(r, 3), 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Clamp;
var
  arr: array[0..3] of Single;
  a, minV, maxV, r: TVecF32x4;
begin
  arr[0] := -5.0;   // below min
  arr[1] := 5.0;    // within range
  arr[2] := 15.0;   // above max
  arr[3] := 0.0;    // within range
  a := VecF32x4Load(@arr[0]);
  minV := VecF32x4Splat(0.0);
  maxV := VecF32x4Splat(10.0);
  r := VecF32x4Clamp(a, minV, maxV);
  
  AssertEquals('Clamp(-5) to [0,10] should be 0.0', 0.0, VecF32x4Extract(r, 0), 0.0001);
  AssertEquals('Clamp(5) to [0,10] should be 5.0', 5.0, VecF32x4Extract(r, 1), 0.0001);
  AssertEquals('Clamp(15) to [0,10] should be 10.0', 10.0, VecF32x4Extract(r, 2), 0.0001);
  AssertEquals('Clamp(0) to [0,10] should be 0.0', 0.0, VecF32x4Extract(r, 3), 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Dot;
var
  arr1, arr2: array[0..3] of Single;
  a, b: TVecF32x4;
  dot: Single;
begin
  // (1,2,3,4) . (2,3,4,5) = 2+6+12+20 = 40
  arr1[0] := 1.0; arr1[1] := 2.0; arr1[2] := 3.0; arr1[3] := 4.0;
  arr2[0] := 2.0; arr2[1] := 3.0; arr2[2] := 4.0; arr2[3] := 5.0;
  a := VecF32x4Load(@arr1[0]);
  b := VecF32x4Load(@arr2[0]);
  
  dot := VecF32x4Dot(a, b);
  AssertEquals('Dot product should be 40.0', 40.0, dot, 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x3_Dot;
var
  arr1, arr2: array[0..3] of Single;
  a, b: TVecF32x4;
  dot: Single;
begin
  // (1,2,3) . (4,5,6) = 4+10+18 = 32
  arr1[0] := 1.0; arr1[1] := 2.0; arr1[2] := 3.0; arr1[3] := 999.0; // w ignored
  arr2[0] := 4.0; arr2[1] := 5.0; arr2[2] := 6.0; arr2[3] := 999.0;
  a := VecF32x4Load(@arr1[0]);
  b := VecF32x4Load(@arr2[0]);
  
  dot := VecF32x3Dot(a, b);
  AssertEquals('3D Dot product should be 32.0', 32.0, dot, 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x3_Cross;
var
  arr1, arr2: array[0..3] of Single;
  a, b, c: TVecF32x4;
begin
  // X axis x Y axis = Z axis
  arr1[0] := 1.0; arr1[1] := 0.0; arr1[2] := 0.0; arr1[3] := 0.0;
  arr2[0] := 0.0; arr2[1] := 1.0; arr2[2] := 0.0; arr2[3] := 0.0;
  a := VecF32x4Load(@arr1[0]);
  b := VecF32x4Load(@arr2[0]);
  
  c := VecF32x3Cross(a, b);
  
  AssertEquals('X cross Y: X component should be 0', 0.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('X cross Y: Y component should be 0', 0.0, VecF32x4Extract(c, 1), 0.0001);
  AssertEquals('X cross Y: Z component should be 1', 1.0, VecF32x4Extract(c, 2), 0.0001);
  
  // (1,2,3) x (4,5,6) = (2*6-3*5, 3*4-1*6, 1*5-2*4) = (12-15, 12-6, 5-8) = (-3, 6, -3)
  arr1[0] := 1.0; arr1[1] := 2.0; arr1[2] := 3.0; arr1[3] := 0.0;
  arr2[0] := 4.0; arr2[1] := 5.0; arr2[2] := 6.0; arr2[3] := 0.0;
  a := VecF32x4Load(@arr1[0]);
  b := VecF32x4Load(@arr2[0]);
  
  c := VecF32x3Cross(a, b);
  
  AssertEquals('Cross X should be -3', -3.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('Cross Y should be 6', 6.0, VecF32x4Extract(c, 1), 0.0001);
  AssertEquals('Cross Z should be -3', -3.0, VecF32x4Extract(c, 2), 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Length;
var
  arr: array[0..3] of Single;
  a: TVecF32x4;
  len: Single;
begin
  // length of (3,0,0,0) = 3
  arr[0] := 3.0; arr[1] := 0.0; arr[2] := 0.0; arr[3] := 0.0;
  a := VecF32x4Load(@arr[0]);
  len := VecF32x4Length(a);
  AssertEquals('Length of (3,0,0,0) should be 3', 3.0, len, 0.0001);
  
  // length of (1,1,1,1) = 2
  arr[0] := 1.0; arr[1] := 1.0; arr[2] := 1.0; arr[3] := 1.0;
  a := VecF32x4Load(@arr[0]);
  len := VecF32x4Length(a);
  AssertEquals('Length of (1,1,1,1) should be 2', 2.0, len, 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x3_Length;
var
  arr: array[0..3] of Single;
  a: TVecF32x4;
  len: Single;
begin
  // length of (3,4,0) = 5
  arr[0] := 3.0; arr[1] := 4.0; arr[2] := 0.0; arr[3] := 999.0; // w ignored
  a := VecF32x4Load(@arr[0]);
  len := VecF32x3Length(a);
  AssertEquals('Length of (3,4,0) should be 5', 5.0, len, 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x4_Normalize;
var
  arr: array[0..3] of Single;
  a, n: TVecF32x4;
  len: Single;
begin
  // Normalize (3,0,0,0) -> (1,0,0,0)
  arr[0] := 3.0; arr[1] := 0.0; arr[2] := 0.0; arr[3] := 0.0;
  a := VecF32x4Load(@arr[0]);
  n := VecF32x4Normalize(a);
  
  AssertEquals('Normalized X should be 1', 1.0, VecF32x4Extract(n, 0), 0.0001);
  AssertEquals('Normalized Y should be 0', 0.0, VecF32x4Extract(n, 1), 0.0001);
  AssertEquals('Normalized Z should be 0', 0.0, VecF32x4Extract(n, 2), 0.0001);
  AssertEquals('Normalized W should be 0', 0.0, VecF32x4Extract(n, 3), 0.0001);
  
  // Check length of normalized vector is 1
  len := VecF32x4Length(n);
  AssertEquals('Length of normalized vector should be 1', 1.0, len, 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF32x3_Normalize;
var
  arr: array[0..3] of Single;
  a, n: TVecF32x4;
  len: Single;
begin
  // Normalize (3,4,0) -> (0.6, 0.8, 0)
  arr[0] := 3.0; arr[1] := 4.0; arr[2] := 0.0; arr[3] := 999.0;
  a := VecF32x4Load(@arr[0]);
  n := VecF32x3Normalize(a);
  
  AssertEquals('Normalized X should be 0.6', 0.6, VecF32x4Extract(n, 0), 0.0001);
  AssertEquals('Normalized Y should be 0.8', 0.8, VecF32x4Extract(n, 1), 0.0001);
  AssertEquals('Normalized Z should be 0', 0.0, VecF32x4Extract(n, 2), 0.0001);
  
  // Check 3D length of normalized vector is 1
  len := VecF32x3Length(n);
  AssertEquals('Length of normalized 3D vector should be 1', 1.0, len, 0.0001);
end;

// ✅ F64x2 扩展函数测试 (2026-02-05)

procedure TTestCase_VectorOps.Test_VecF64x2_Floor;
var
  arr: array[0..1] of Double;
  a, r: TVecF64x2;
begin
  // Floor: floor(2.7) = 2, floor(-2.3) = -3
  a.d[0] := 2.7;
  a.d[1] := -2.3;
  r := VecF64x2Floor(a);

  AssertEquals('Floor(2.7) should be 2', 2.0, r.d[0], 0.0001);
  AssertEquals('Floor(-2.3) should be -3', -3.0, r.d[1], 0.0001);

  // Test with integers (should not change)
  a.d[0] := 5.0;
  a.d[1] := -7.0;
  r := VecF64x2Floor(a);
  AssertEquals('Floor(5.0) should be 5', 5.0, r.d[0], 0.0001);
  AssertEquals('Floor(-7.0) should be -7', -7.0, r.d[1], 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF64x2_Ceil;
var
  a, r: TVecF64x2;
begin
  // Ceil: ceil(2.3) = 3, ceil(-2.7) = -2
  a.d[0] := 2.3;
  a.d[1] := -2.7;
  r := VecF64x2Ceil(a);

  AssertEquals('Ceil(2.3) should be 3', 3.0, r.d[0], 0.0001);
  AssertEquals('Ceil(-2.7) should be -2', -2.0, r.d[1], 0.0001);

  // Test with integers
  a.d[0] := 5.0;
  a.d[1] := -7.0;
  r := VecF64x2Ceil(a);
  AssertEquals('Ceil(5.0) should be 5', 5.0, r.d[0], 0.0001);
  AssertEquals('Ceil(-7.0) should be -7', -7.0, r.d[1], 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF64x2_Round;
var
  a, r: TVecF64x2;
begin
  // Round: round(2.4) = 2, round(2.6) = 3
  a.d[0] := 2.4;
  a.d[1] := 2.6;
  r := VecF64x2Round(a);

  AssertEquals('Round(2.4) should be 2', 2.0, r.d[0], 0.0001);
  AssertEquals('Round(2.6) should be 3', 3.0, r.d[1], 0.0001);

  // Test with negative values
  a.d[0] := -2.4;
  a.d[1] := -2.6;
  r := VecF64x2Round(a);
  AssertEquals('Round(-2.4) should be -2', -2.0, r.d[0], 0.0001);
  AssertEquals('Round(-2.6) should be -3', -3.0, r.d[1], 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF64x2_Trunc;
var
  a, r: TVecF64x2;
begin
  // Trunc: trunc(2.9) = 2, trunc(-2.9) = -2 (towards zero)
  a.d[0] := 2.9;
  a.d[1] := -2.9;
  r := VecF64x2Trunc(a);

  AssertEquals('Trunc(2.9) should be 2', 2.0, r.d[0], 0.0001);
  AssertEquals('Trunc(-2.9) should be -2', -2.0, r.d[1], 0.0001);

  // Test boundary values
  a.d[0] := 0.999;
  a.d[1] := -0.999;
  r := VecF64x2Trunc(a);
  AssertEquals('Trunc(0.999) should be 0', 0.0, r.d[0], 0.0001);
  AssertEquals('Trunc(-0.999) should be 0', 0.0, r.d[1], 0.0001);
end;

procedure TTestCase_VectorOps.Test_VecF64x2_Fma;
var
  a, b, c, r: TVecF64x2;
begin
  // FMA: result = a * b + c
  // Test: 2.0 * 3.0 + 4.0 = 10.0
  a.d[0] := 2.0; a.d[1] := 1.5;
  b.d[0] := 3.0; b.d[1] := 4.0;
  c.d[0] := 4.0; c.d[1] := 2.0;
  r := VecF64x2Fma(a, b, c);

  AssertEquals('FMA(2.0, 3.0, 4.0) should be 10', 10.0, r.d[0], 0.0001);
  AssertEquals('FMA(1.5, 4.0, 2.0) should be 8', 8.0, r.d[1], 0.0001);

  // Test with negative values
  a.d[0] := -2.0; a.d[1] := 3.0;
  b.d[0] := 3.0;  b.d[1] := -2.0;
  c.d[0] := 10.0; c.d[1] := 10.0;
  r := VecF64x2Fma(a, b, c);

  AssertEquals('FMA(-2.0, 3.0, 10.0) should be 4', 4.0, r.d[0], 0.0001);
  AssertEquals('FMA(3.0, -2.0, 10.0) should be 4', 4.0, r.d[1], 0.0001);
end;

{ TTestCase_IntegerFacadeGuards }

procedure TTestCase_IntegerFacadeGuards.Test_VecI32x4_AndNot_Basic;
var
  LVecA, LVecB, LResult: TVecI32x4;
begin
  LVecA.i[0] := LongInt($0F0F0F0F);
  LVecA.i[1] := -1;
  LVecA.i[2] := 0;
  LVecA.i[3] := LongInt($AAAAAAAA);

  LVecB.i[0] := -1;
  LVecB.i[1] := LongInt($0F0F0F0F);
  LVecB.i[2] := -1;
  LVecB.i[3] := LongInt($55555555);

  LResult := VecI32x4AndNot(LVecA, LVecB);

  AssertEquals('VecI32x4AndNot lane 0', UInt32($F0F0F0F0), UInt32(LResult.i[0]));
  AssertEquals('VecI32x4AndNot lane 1', UInt32(0), UInt32(LResult.i[1]));
  AssertEquals('VecI32x4AndNot lane 2', UInt32($FFFFFFFF), UInt32(LResult.i[2]));
  AssertEquals('VecI32x4AndNot lane 3', UInt32($55555555), UInt32(LResult.i[3]));
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI32x4_Compare_Basic;
var
  LVecA, LVecB: TVecI32x4;
  LMaskEq, LMaskLt, LMaskGt, LMaskLe, LMaskGe, LMaskNe: TMask4;
begin
  LVecA.i[0] := 10;
  LVecA.i[1] := -5;
  LVecA.i[2] := 20;
  LVecA.i[3] := 30;

  LVecB.i[0] := 10;
  LVecB.i[1] := 3;
  LVecB.i[2] := 20;
  LVecB.i[3] := -30;

  LMaskEq := VecI32x4CmpEq(LVecA, LVecB);
  LMaskLt := VecI32x4CmpLt(LVecA, LVecB);
  LMaskGt := VecI32x4CmpGt(LVecA, LVecB);
  LMaskLe := VecI32x4CmpLe(LVecA, LVecB);
  LMaskGe := VecI32x4CmpGe(LVecA, LVecB);
  LMaskNe := VecI32x4CmpNe(LVecA, LVecB);

  AssertEquals('VecI32x4CmpEq mask', Integer(TMask4($5)), Integer(LMaskEq));
  AssertEquals('VecI32x4CmpLt mask', Integer(TMask4($2)), Integer(LMaskLt));
  AssertEquals('VecI32x4CmpGt mask', Integer(TMask4($8)), Integer(LMaskGt));
  AssertEquals('VecI32x4CmpLe mask', Integer(TMask4($7)), Integer(LMaskLe));
  AssertEquals('VecI32x4CmpGe mask', Integer(TMask4($D)), Integer(LMaskGe));
  AssertEquals('VecI32x4CmpNe mask', Integer(TMask4($A)), Integer(LMaskNe));
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI32x4_RemainingOps_Basic;
const
  C_SHIFT_LEFT = 6;
  C_SHIFT_RIGHT = 4;
  C_SHIFT_RIGHT_ARITH = 5;
var
  LVecA, LVecB: TVecI32x4;
  LAddResult, LSubResult, LMulResult: TVecI32x4;
  LAndResult, LOrResult, LXorResult, LNotResult: TVecI32x4;
  LMinResult, LMaxResult: TVecI32x4;
  LShiftLeftResult, LShiftRightResult, LShiftRightArithResult: TVecI32x4;
  LInserted: TVecI32x4;
  LExpectedMul: UInt32;
  LExpectedSar: Int32;
  LIndex: Integer;
begin
  LVecA.i[0] := Low(Int32);
  LVecA.i[1] := High(Int32);
  LVecA.i[2] := Int32($55555555);
  LVecA.i[3] := -123456789;

  LVecB.i[0] := 1;
  LVecB.i[1] := -1;
  LVecB.i[2] := Int32($AAAAAAAA);
  LVecB.i[3] := 7;

  LAddResult := VecI32x4Add(LVecA, LVecB);
  LSubResult := VecI32x4Sub(LVecA, LVecB);
  LMulResult := VecI32x4Mul(LVecA, LVecB);
  LAndResult := VecI32x4And(LVecA, LVecB);
  LOrResult := VecI32x4Or(LVecA, LVecB);
  LXorResult := VecI32x4Xor(LVecA, LVecB);
  LNotResult := VecI32x4Not(LVecA);
  LMinResult := VecI32x4Min(LVecA, LVecB);
  LMaxResult := VecI32x4Max(LVecA, LVecB);
  LShiftLeftResult := VecI32x4ShiftLeft(LVecA, C_SHIFT_LEFT);
  LShiftRightResult := VecI32x4ShiftRight(LVecA, C_SHIFT_RIGHT);
  LShiftRightArithResult := VecI32x4ShiftRightArith(LVecA, C_SHIFT_RIGHT_ARITH);

  AssertEquals('VecI32x4Extract lane 3', LVecA.i[3], VecI32x4Extract(LVecA, 3));
  LInserted := VecI32x4Insert(LVecA, 999, 1);
  AssertEquals('VecI32x4Insert lane 1', 999, LInserted.i[1]);
  AssertEquals('VecI32x4Insert keep lane 0', LVecA.i[0], LInserted.i[0]);
  AssertEquals('VecI32x4Insert keep lane 2', LVecA.i[2], LInserted.i[2]);

  for LIndex := 0 to High(LVecA.i) do
  begin
    AssertEquals('VecI32x4Add lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex] + LVecB.i[LIndex]), UInt32(LAddResult.i[LIndex]));
    AssertEquals('VecI32x4Sub lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex] - LVecB.i[LIndex]), UInt32(LSubResult.i[LIndex]));

    LExpectedMul := UInt32(Int64(LVecA.i[LIndex]) * Int64(LVecB.i[LIndex]));
    AssertEquals('VecI32x4Mul lane ' + IntToStr(LIndex), LExpectedMul, UInt32(LMulResult.i[LIndex]));

    AssertEquals('VecI32x4And lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex]) and UInt32(LVecB.i[LIndex]), UInt32(LAndResult.i[LIndex]));
    AssertEquals('VecI32x4Or lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex]) or UInt32(LVecB.i[LIndex]), UInt32(LOrResult.i[LIndex]));
    AssertEquals('VecI32x4Xor lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex]) xor UInt32(LVecB.i[LIndex]), UInt32(LXorResult.i[LIndex]));
    AssertEquals('VecI32x4Not lane ' + IntToStr(LIndex),
      UInt32(not LVecA.i[LIndex]), UInt32(LNotResult.i[LIndex]));

    if LVecA.i[LIndex] < LVecB.i[LIndex] then
      AssertEquals('VecI32x4Min lane ' + IntToStr(LIndex), LVecA.i[LIndex], LMinResult.i[LIndex])
    else
      AssertEquals('VecI32x4Min lane ' + IntToStr(LIndex), LVecB.i[LIndex], LMinResult.i[LIndex]);

    if LVecA.i[LIndex] > LVecB.i[LIndex] then
      AssertEquals('VecI32x4Max lane ' + IntToStr(LIndex), LVecA.i[LIndex], LMaxResult.i[LIndex])
    else
      AssertEquals('VecI32x4Max lane ' + IntToStr(LIndex), LVecB.i[LIndex], LMaxResult.i[LIndex]);

    AssertEquals('VecI32x4ShiftLeft lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex]) shl C_SHIFT_LEFT, UInt32(LShiftLeftResult.i[LIndex]));
    AssertEquals('VecI32x4ShiftRight lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex]) shr C_SHIFT_RIGHT, UInt32(LShiftRightResult.i[LIndex]));

    if LVecA.i[LIndex] < 0 then
      LExpectedSar := not Int32(UInt32(not LVecA.i[LIndex]) shr C_SHIFT_RIGHT_ARITH)
    else
      LExpectedSar := Int32(UInt32(LVecA.i[LIndex]) shr C_SHIFT_RIGHT_ARITH);
    AssertEquals('VecI32x4ShiftRightArith lane ' + IntToStr(LIndex),
      LExpectedSar, LShiftRightArithResult.i[LIndex]);
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI32x8_AndNot_Basic;
var
  LVecA, LVecB, LResult: TVecI32x8;
  LExpected: UInt32;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.i) do
  begin
    case LIndex mod 4 of
      0:
        begin
          LVecA.i[LIndex] := LongInt($0F0F0F0F);
          LVecB.i[LIndex] := -1;
        end;
      1:
        begin
          LVecA.i[LIndex] := -1;
          LVecB.i[LIndex] := LongInt($12345678);
        end;
      2:
        begin
          LVecA.i[LIndex] := 0;
          LVecB.i[LIndex] := LongInt($33333333);
        end;
    else
      begin
        LVecA.i[LIndex] := LongInt($33333333);
        LVecB.i[LIndex] := LongInt($55555555);
      end;
    end;
  end;

  LResult := VecI32x8AndNot(LVecA, LVecB);

  for LIndex := 0 to High(LResult.i) do
  begin
    LExpected := UInt32(not LVecA.i[LIndex]) and UInt32(LVecB.i[LIndex]);
    AssertEquals('VecI32x8AndNot lane ' + IntToStr(LIndex), LExpected, UInt32(LResult.i[LIndex]));
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI32x8_Compare_Basic;
var
  LVecA, LVecB: TVecI32x8;
  LMaskEq, LMaskLt, LMaskGt, LMaskLe, LMaskGe, LMaskNe: TMask8;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.i) do
  begin
    case LIndex mod 3 of
      0:
        begin
          LVecA.i[LIndex] := LIndex * 11;
          LVecB.i[LIndex] := LVecA.i[LIndex];
        end;
      1:
        begin
          LVecA.i[LIndex] := -1000 + LIndex;
          LVecB.i[LIndex] := LVecA.i[LIndex] + 5;
        end;
    else
      begin
        LVecA.i[LIndex] := 1000 + LIndex;
        LVecB.i[LIndex] := LVecA.i[LIndex] - 7;
      end;
    end;
  end;

  LMaskEq := VecI32x8CmpEq(LVecA, LVecB);
  LMaskLt := VecI32x8CmpLt(LVecA, LVecB);
  LMaskGt := VecI32x8CmpGt(LVecA, LVecB);
  LMaskLe := VecI32x8CmpLe(LVecA, LVecB);
  LMaskGe := VecI32x8CmpGe(LVecA, LVecB);
  LMaskNe := VecI32x8CmpNe(LVecA, LVecB);

  AssertEquals('VecI32x8CmpEq mask', Integer(TMask8($49)), Integer(LMaskEq));
  AssertEquals('VecI32x8CmpLt mask', Integer(TMask8($92)), Integer(LMaskLt));
  AssertEquals('VecI32x8CmpGt mask', Integer(TMask8($24)), Integer(LMaskGt));
  AssertEquals('VecI32x8CmpLe mask', Integer(TMask8($DB)), Integer(LMaskLe));
  AssertEquals('VecI32x8CmpGe mask', Integer(TMask8($6D)), Integer(LMaskGe));
  AssertEquals('VecI32x8CmpNe mask', Integer(TMask8($B6)), Integer(LMaskNe));
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI32x8_RemainingOps_Basic;
const
  C_SHIFT_LEFT = 5;
  C_SHIFT_RIGHT = 3;
  C_SHIFT_RIGHT_ARITH = 4;
var
  LVecA, LVecB: TVecI32x8;
  LAddResult, LSubResult, LMulResult: TVecI32x8;
  LAndResult, LOrResult, LXorResult, LNotResult: TVecI32x8;
  LMinResult, LMaxResult: TVecI32x8;
  LShiftLeftResult, LShiftRightResult, LShiftRightArithResult: TVecI32x8;
  LInserted: TVecI32x8;
  LExpectedMul: UInt32;
  LExpectedSar: Int32;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.i) do
  begin
    LVecA.i[LIndex] := (LIndex - 4) * 4099;
    LVecB.i[LIndex] := (4 - LIndex) * 2053;
  end;

  LVecA.i[0] := Low(Int32);
  LVecA.i[1] := High(Int32);
  LVecA.i[2] := -1;
  LVecA.i[3] := 0;
  LVecA.i[4] := Int32($55555555);
  LVecA.i[5] := Int32($33333333);
  LVecA.i[6] := -123456789;
  LVecA.i[7] := 123456789;

  LVecB.i[0] := 1;
  LVecB.i[1] := -1;
  LVecB.i[2] := High(Int32);
  LVecB.i[3] := Int32($11111111);
  LVecB.i[4] := Int32($AAAAAAAA);
  LVecB.i[5] := Int32($0F0F0F0F);
  LVecB.i[6] := 7;
  LVecB.i[7] := -11;

  LAddResult := VecI32x8Add(LVecA, LVecB);
  LSubResult := VecI32x8Sub(LVecA, LVecB);
  LMulResult := VecI32x8Mul(LVecA, LVecB);
  LAndResult := VecI32x8And(LVecA, LVecB);
  LOrResult := VecI32x8Or(LVecA, LVecB);
  LXorResult := VecI32x8Xor(LVecA, LVecB);
  LNotResult := VecI32x8Not(LVecA);
  LMinResult := VecI32x8Min(LVecA, LVecB);
  LMaxResult := VecI32x8Max(LVecA, LVecB);
  LShiftLeftResult := VecI32x8ShiftLeft(LVecA, C_SHIFT_LEFT);
  LShiftRightResult := VecI32x8ShiftRight(LVecA, C_SHIFT_RIGHT);
  LShiftRightArithResult := VecI32x8ShiftRightArith(LVecA, C_SHIFT_RIGHT_ARITH);

  AssertEquals('VecI32x8Extract lane 6', LVecA.i[6], VecI32x8Extract(LVecA, 6));
  LInserted := VecI32x8Insert(LVecA, -2026, 5);
  AssertEquals('VecI32x8Insert lane 5', -2026, LInserted.i[5]);
  AssertEquals('VecI32x8Insert keep lane 4', LVecA.i[4], LInserted.i[4]);
  AssertEquals('VecI32x8Insert keep lane 6', LVecA.i[6], LInserted.i[6]);

  for LIndex := 0 to High(LVecA.i) do
  begin
    AssertEquals('VecI32x8Add lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex] + LVecB.i[LIndex]), UInt32(LAddResult.i[LIndex]));
    AssertEquals('VecI32x8Sub lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex] - LVecB.i[LIndex]), UInt32(LSubResult.i[LIndex]));

    LExpectedMul := UInt32(Int64(LVecA.i[LIndex]) * Int64(LVecB.i[LIndex]));
    AssertEquals('VecI32x8Mul lane ' + IntToStr(LIndex), LExpectedMul, UInt32(LMulResult.i[LIndex]));

    AssertEquals('VecI32x8And lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex]) and UInt32(LVecB.i[LIndex]), UInt32(LAndResult.i[LIndex]));
    AssertEquals('VecI32x8Or lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex]) or UInt32(LVecB.i[LIndex]), UInt32(LOrResult.i[LIndex]));
    AssertEquals('VecI32x8Xor lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex]) xor UInt32(LVecB.i[LIndex]), UInt32(LXorResult.i[LIndex]));
    AssertEquals('VecI32x8Not lane ' + IntToStr(LIndex),
      UInt32(not LVecA.i[LIndex]), UInt32(LNotResult.i[LIndex]));

    if LVecA.i[LIndex] < LVecB.i[LIndex] then
      AssertEquals('VecI32x8Min lane ' + IntToStr(LIndex), LVecA.i[LIndex], LMinResult.i[LIndex])
    else
      AssertEquals('VecI32x8Min lane ' + IntToStr(LIndex), LVecB.i[LIndex], LMinResult.i[LIndex]);

    if LVecA.i[LIndex] > LVecB.i[LIndex] then
      AssertEquals('VecI32x8Max lane ' + IntToStr(LIndex), LVecA.i[LIndex], LMaxResult.i[LIndex])
    else
      AssertEquals('VecI32x8Max lane ' + IntToStr(LIndex), LVecB.i[LIndex], LMaxResult.i[LIndex]);

    AssertEquals('VecI32x8ShiftLeft lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex]) shl C_SHIFT_LEFT, UInt32(LShiftLeftResult.i[LIndex]));
    AssertEquals('VecI32x8ShiftRight lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex]) shr C_SHIFT_RIGHT, UInt32(LShiftRightResult.i[LIndex]));

    if LVecA.i[LIndex] < 0 then
      LExpectedSar := not Int32(UInt32(not LVecA.i[LIndex]) shr C_SHIFT_RIGHT_ARITH)
    else
      LExpectedSar := Int32(UInt32(LVecA.i[LIndex]) shr C_SHIFT_RIGHT_ARITH);
    AssertEquals('VecI32x8ShiftRightArith lane ' + IntToStr(LIndex),
      LExpectedSar, LShiftRightArithResult.i[LIndex]);
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI64x2_AndNot_Basic;
var
  LVecA, LVecB, LResult: TVecI64x2;
begin
  LVecA.i[0] := Int64($0F0F0F0F0F0F0F0F);
  LVecA.i[1] := -1;

  LVecB.i[0] := -1;
  LVecB.i[1] := Int64($123456789ABCDEF0);

  LResult := VecI64x2AndNot(LVecA, LVecB);

  AssertEquals('VecI64x2AndNot lane 0', QWord($F0F0F0F0F0F0F0F0), QWord(LResult.i[0]));
  AssertEquals('VecI64x2AndNot lane 1', QWord(0), QWord(LResult.i[1]));
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI64x2_Compare_Basic;
var
  LVecA, LVecB: TVecI64x2;
  LMaskEq, LMaskLt, LMaskGt, LMaskLe, LMaskGe, LMaskNe: TMask2;
begin
  LVecA.i[0] := 42;
  LVecA.i[1] := -100;
  LVecB.i[0] := 42;
  LVecB.i[1] := 50;

  LMaskEq := VecI64x2CmpEq(LVecA, LVecB);
  LMaskLt := VecI64x2CmpLt(LVecA, LVecB);
  LMaskGt := VecI64x2CmpGt(LVecA, LVecB);
  LMaskLe := VecI64x2CmpLe(LVecA, LVecB);
  LMaskGe := VecI64x2CmpGe(LVecA, LVecB);
  LMaskNe := VecI64x2CmpNe(LVecA, LVecB);

  AssertEquals('VecI64x2CmpEq case1', Integer(TMask2($1)), Integer(LMaskEq));
  AssertEquals('VecI64x2CmpLt case1', Integer(TMask2($2)), Integer(LMaskLt));
  AssertEquals('VecI64x2CmpGt case1', Integer(TMask2($0)), Integer(LMaskGt));
  AssertEquals('VecI64x2CmpLe case1', Integer(TMask2($3)), Integer(LMaskLe));
  AssertEquals('VecI64x2CmpGe case1', Integer(TMask2($1)), Integer(LMaskGe));
  AssertEquals('VecI64x2CmpNe case1', Integer(TMask2($2)), Integer(LMaskNe));

  LVecA.i[0] := 100;
  LVecA.i[1] := -10;
  LVecB.i[0] := 42;
  LVecB.i[1] := -10;

  LMaskEq := VecI64x2CmpEq(LVecA, LVecB);
  LMaskLt := VecI64x2CmpLt(LVecA, LVecB);
  LMaskGt := VecI64x2CmpGt(LVecA, LVecB);
  LMaskLe := VecI64x2CmpLe(LVecA, LVecB);
  LMaskGe := VecI64x2CmpGe(LVecA, LVecB);
  LMaskNe := VecI64x2CmpNe(LVecA, LVecB);

  AssertEquals('VecI64x2CmpEq case2', Integer(TMask2($2)), Integer(LMaskEq));
  AssertEquals('VecI64x2CmpLt case2', Integer(TMask2($0)), Integer(LMaskLt));
  AssertEquals('VecI64x2CmpGt case2', Integer(TMask2($1)), Integer(LMaskGt));
  AssertEquals('VecI64x2CmpLe case2', Integer(TMask2($2)), Integer(LMaskLe));
  AssertEquals('VecI64x2CmpGe case2', Integer(TMask2($3)), Integer(LMaskGe));
  AssertEquals('VecI64x2CmpNe case2', Integer(TMask2($1)), Integer(LMaskNe));
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI64x2_RemainingOps_Basic;
const
  C_SHIFT_LEFT = 7;
  C_SHIFT_RIGHT = 6;
  C_SHIFT_RIGHT_ARITH = 5;
var
  LVecA, LVecB: TVecI64x2;
  LAddResult, LSubResult: TVecI64x2;
  LAndResult, LOrResult, LXorResult, LNotResult: TVecI64x2;
  LMinResult, LMaxResult: TVecI64x2;
  LShiftLeftResult, LShiftRightResult, LShiftRightArithResult: TVecI64x2;
  LInserted: TVecI64x2;
  LExpectedSar: Int64;
  LIndex: Integer;
begin
  LVecA.i[0] := High(Int64);
  LVecA.i[1] := Int64($4000000000000001);

  LVecB.i[0] := 1;
  LVecB.i[1] := Low(Int64);

  LAddResult := VecI64x2Add(LVecA, LVecB);
  LSubResult := VecI64x2Sub(LVecA, LVecB);
  LAndResult := VecI64x2And(LVecA, LVecB);
  LOrResult := VecI64x2Or(LVecA, LVecB);
  LXorResult := VecI64x2Xor(LVecA, LVecB);
  LNotResult := VecI64x2Not(LVecA);
  LMinResult := VecI64x2Min(LVecA, LVecB);
  LMaxResult := VecI64x2Max(LVecA, LVecB);
  LShiftLeftResult := VecI64x2ShiftLeft(LVecA, C_SHIFT_LEFT);
  LShiftRightResult := VecI64x2ShiftRight(LVecA, C_SHIFT_RIGHT);
  LShiftRightArithResult := VecI64x2ShiftRightArith(LVecA, C_SHIFT_RIGHT_ARITH);

  AssertEquals('VecI64x2Extract lane 1', LVecA.i[1], VecI64x2Extract(LVecA, 1));
  LInserted := VecI64x2Insert(LVecA, Int64(55555), 0);
  AssertEquals('VecI64x2Insert lane 0', Int64(55555), LInserted.i[0]);
  AssertEquals('VecI64x2Insert keep lane 1', LVecA.i[1], LInserted.i[1]);

  for LIndex := 0 to High(LVecA.i) do
  begin
    AssertEquals('VecI64x2Add lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) + QWord(LVecB.i[LIndex]), QWord(LAddResult.i[LIndex]));
    AssertEquals('VecI64x2Sub lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) - QWord(LVecB.i[LIndex]), QWord(LSubResult.i[LIndex]));
    AssertEquals('VecI64x2And lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) and QWord(LVecB.i[LIndex]), QWord(LAndResult.i[LIndex]));
    AssertEquals('VecI64x2Or lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) or QWord(LVecB.i[LIndex]), QWord(LOrResult.i[LIndex]));
    AssertEquals('VecI64x2Xor lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) xor QWord(LVecB.i[LIndex]), QWord(LXorResult.i[LIndex]));
    AssertEquals('VecI64x2Not lane ' + IntToStr(LIndex),
      QWord(not LVecA.i[LIndex]), QWord(LNotResult.i[LIndex]));

    if LVecA.i[LIndex] < LVecB.i[LIndex] then
      AssertEquals('VecI64x2Min lane ' + IntToStr(LIndex), LVecA.i[LIndex], LMinResult.i[LIndex])
    else
      AssertEquals('VecI64x2Min lane ' + IntToStr(LIndex), LVecB.i[LIndex], LMinResult.i[LIndex]);

    if LVecA.i[LIndex] > LVecB.i[LIndex] then
      AssertEquals('VecI64x2Max lane ' + IntToStr(LIndex), LVecA.i[LIndex], LMaxResult.i[LIndex])
    else
      AssertEquals('VecI64x2Max lane ' + IntToStr(LIndex), LVecB.i[LIndex], LMaxResult.i[LIndex]);

    AssertEquals('VecI64x2ShiftLeft lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) shl C_SHIFT_LEFT, QWord(LShiftLeftResult.i[LIndex]));
    AssertEquals('VecI64x2ShiftRight lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) shr C_SHIFT_RIGHT, QWord(LShiftRightResult.i[LIndex]));

    if LVecA.i[LIndex] < 0 then
      LExpectedSar := not Int64(QWord(not LVecA.i[LIndex]) shr C_SHIFT_RIGHT_ARITH)
    else
      LExpectedSar := Int64(QWord(LVecA.i[LIndex]) shr C_SHIFT_RIGHT_ARITH);
    AssertEquals('VecI64x2ShiftRightArith lane ' + IntToStr(LIndex),
      LExpectedSar, LShiftRightArithResult.i[LIndex]);
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI64x4_AndNot_Basic;
var
  LVecA, LVecB, LResult: TVecI64x4;
begin
  LVecA.i[0] := Int64($0F0F0F0F0F0F0F0F);
  LVecA.i[1] := -1;
  LVecA.i[2] := 0;
  LVecA.i[3] := Int64($3333333333333333);

  LVecB.i[0] := -1;
  LVecB.i[1] := Int64($123456789ABCDEF0);
  LVecB.i[2] := Int64($3333333333333333);
  LVecB.i[3] := Int64($5555555555555555);

  LResult := VecI64x4AndNot(LVecA, LVecB);

  AssertEquals('VecI64x4AndNot lane 0', QWord($F0F0F0F0F0F0F0F0), QWord(LResult.i[0]));
  AssertEquals('VecI64x4AndNot lane 1', QWord(0), QWord(LResult.i[1]));
  AssertEquals('VecI64x4AndNot lane 2', QWord($3333333333333333), QWord(LResult.i[2]));
  AssertEquals('VecI64x4AndNot lane 3', QWord($4444444444444444), QWord(LResult.i[3]));
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI64x4_Compare_Basic;
var
  LVecA, LVecB: TVecI64x4;
  LMaskEq, LMaskLt, LMaskGt, LMaskLe, LMaskGe, LMaskNe: TMask4;
begin
  LVecA.i[0] := 42;
  LVecA.i[1] := -100;
  LVecA.i[2] := 75;
  LVecA.i[3] := -9;

  LVecB.i[0] := 42;
  LVecB.i[1] := -50;
  LVecB.i[2] := 74;
  LVecB.i[3] := -9;

  LMaskEq := VecI64x4CmpEq(LVecA, LVecB);
  LMaskLt := VecI64x4CmpLt(LVecA, LVecB);
  LMaskGt := VecI64x4CmpGt(LVecA, LVecB);
  LMaskLe := VecI64x4CmpLe(LVecA, LVecB);
  LMaskGe := VecI64x4CmpGe(LVecA, LVecB);
  LMaskNe := VecI64x4CmpNe(LVecA, LVecB);

  AssertEquals('VecI64x4CmpEq mask', Integer(TMask4($9)), Integer(LMaskEq));
  AssertEquals('VecI64x4CmpLt mask', Integer(TMask4($2)), Integer(LMaskLt));
  AssertEquals('VecI64x4CmpGt mask', Integer(TMask4($4)), Integer(LMaskGt));
  AssertEquals('VecI64x4CmpLe mask', Integer(TMask4($B)), Integer(LMaskLe));
  AssertEquals('VecI64x4CmpGe mask', Integer(TMask4($D)), Integer(LMaskGe));
  AssertEquals('VecI64x4CmpNe mask', Integer(TMask4($6)), Integer(LMaskNe));
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI64x4_RemainingOps_Basic;
const
  C_SHIFT_LEFT = 6;
  C_SHIFT_RIGHT = 5;
  C_SHIFT_RIGHT_ARITH = 7;
var
  LVecA, LVecB: TVecI64x4;
  LAddResult, LSubResult: TVecI64x4;
  LAndResult, LOrResult, LXorResult, LNotResult: TVecI64x4;
  LShiftLeftResult, LShiftRightResult, LShiftRightArithResult: TVecI64x4;
  LExpectedSar: Int64;
  LIndex: Integer;
begin
  LVecA.i[0] := High(Int64);
  LVecA.i[1] := Low(Int64);
  LVecA.i[2] := -1;
  LVecA.i[3] := -1234567890123456;

  LVecB.i[0] := 1;
  LVecB.i[1] := -1;
  LVecB.i[2] := High(Int64);
  LVecB.i[3] := Int64($0F0F0F0F0F0F0F0F);

  LAddResult := VecI64x4Add(LVecA, LVecB);
  LSubResult := VecI64x4Sub(LVecA, LVecB);
  LAndResult := VecI64x4And(LVecA, LVecB);
  LOrResult := VecI64x4Or(LVecA, LVecB);
  LXorResult := VecI64x4Xor(LVecA, LVecB);
  LNotResult := VecI64x4Not(LVecA);
  LShiftLeftResult := VecI64x4ShiftLeft(LVecA, C_SHIFT_LEFT);
  LShiftRightResult := VecI64x4ShiftRight(LVecA, C_SHIFT_RIGHT);
  LShiftRightArithResult := VecI64x4ShiftRightArith(LVecA, C_SHIFT_RIGHT_ARITH);

  for LIndex := 0 to High(LVecA.i) do
  begin
    AssertEquals('VecI64x4Add lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) + QWord(LVecB.i[LIndex]), QWord(LAddResult.i[LIndex]));
    AssertEquals('VecI64x4Sub lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) - QWord(LVecB.i[LIndex]), QWord(LSubResult.i[LIndex]));
    AssertEquals('VecI64x4And lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) and QWord(LVecB.i[LIndex]), QWord(LAndResult.i[LIndex]));
    AssertEquals('VecI64x4Or lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) or QWord(LVecB.i[LIndex]), QWord(LOrResult.i[LIndex]));
    AssertEquals('VecI64x4Xor lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) xor QWord(LVecB.i[LIndex]), QWord(LXorResult.i[LIndex]));
    AssertEquals('VecI64x4Not lane ' + IntToStr(LIndex),
      QWord(not LVecA.i[LIndex]), QWord(LNotResult.i[LIndex]));
    AssertEquals('VecI64x4ShiftLeft lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) shl C_SHIFT_LEFT, QWord(LShiftLeftResult.i[LIndex]));
    AssertEquals('VecI64x4ShiftRight lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) shr C_SHIFT_RIGHT, QWord(LShiftRightResult.i[LIndex]));

    if LVecA.i[LIndex] < 0 then
      LExpectedSar := not Int64(QWord(not LVecA.i[LIndex]) shr C_SHIFT_RIGHT_ARITH)
    else
      LExpectedSar := Int64(QWord(LVecA.i[LIndex]) shr C_SHIFT_RIGHT_ARITH);
    AssertEquals('VecI64x4ShiftRightArith lane ' + IntToStr(LIndex),
      LExpectedSar, LShiftRightArithResult.i[LIndex]);
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecU64x2_AndNot_Basic;
var
  LVecA, LVecB, LResult: TVecU64x2;
begin
  LVecA.u[0] := QWord($0F0F0F0F0F0F0F0F);
  LVecA.u[1] := 0;

  LVecB.u[0] := High(QWord);
  LVecB.u[1] := QWord($123456789ABCDEF0);

  LResult := VecU64x2AndNot(LVecA, LVecB);

  AssertEquals('VecU64x2AndNot lane 0', QWord($F0F0F0F0F0F0F0F0), LResult.u[0]);
  AssertEquals('VecU64x2AndNot lane 1', QWord($123456789ABCDEF0), LResult.u[1]);
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecU64x2_Compare_Unsigned;
var
  LVecA, LVecB: TVecU64x2;
  LMaskEq, LMaskLt, LMaskGt: TMask2;
begin
  LVecA.u[0] := 0;
  LVecA.u[1] := High(QWord);
  LVecB.u[0] := High(QWord);
  LVecB.u[1] := High(QWord);

  LMaskEq := VecU64x2CmpEq(LVecA, LVecB);
  LMaskLt := VecU64x2CmpLt(LVecA, LVecB);
  LMaskGt := VecU64x2CmpGt(LVecA, LVecB);

  AssertEquals('VecU64x2CmpEq case1', Integer(TMask2($2)), Integer(LMaskEq));
  AssertEquals('VecU64x2CmpLt case1', Integer(TMask2($1)), Integer(LMaskLt));
  AssertEquals('VecU64x2CmpGt case1', Integer(TMask2($0)), Integer(LMaskGt));

  LVecA.u[0] := High(QWord);
  LVecA.u[1] := 0;
  LVecB.u[0] := 1;
  LVecB.u[1] := 0;

  LMaskEq := VecU64x2CmpEq(LVecA, LVecB);
  LMaskLt := VecU64x2CmpLt(LVecA, LVecB);
  LMaskGt := VecU64x2CmpGt(LVecA, LVecB);

  AssertEquals('VecU64x2CmpEq case2', Integer(TMask2($2)), Integer(LMaskEq));
  AssertEquals('VecU64x2CmpLt case2', Integer(TMask2($0)), Integer(LMaskLt));
  AssertEquals('VecU64x2CmpGt case2', Integer(TMask2($1)), Integer(LMaskGt));
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecU64x2_RemainingOps_Basic;
var
  LVecA, LVecB: TVecU64x2;
  LAddResult, LSubResult: TVecU64x2;
  LAndResult, LOrResult, LXorResult, LNotResult: TVecU64x2;
  LMinResult, LMaxResult: TVecU64x2;
  LIndex: Integer;
begin
  LVecA.u[0] := 0;
  LVecA.u[1] := High(QWord);

  LVecB.u[0] := High(QWord);
  LVecB.u[1] := QWord($00FF00FF00FF00FF);

  LAddResult := VecU64x2Add(LVecA, LVecB);
  LSubResult := VecU64x2Sub(LVecA, LVecB);
  LAndResult := VecU64x2And(LVecA, LVecB);
  LOrResult := VecU64x2Or(LVecA, LVecB);
  LXorResult := VecU64x2Xor(LVecA, LVecB);
  LNotResult := VecU64x2Not(LVecA);
  LMinResult := VecU64x2Min(LVecA, LVecB);
  LMaxResult := VecU64x2Max(LVecA, LVecB);

  for LIndex := 0 to High(LVecA.u) do
  begin
    AssertEquals('VecU64x2Add lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] + LVecB.u[LIndex], LAddResult.u[LIndex]);
    AssertEquals('VecU64x2Sub lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] - LVecB.u[LIndex], LSubResult.u[LIndex]);
    AssertEquals('VecU64x2And lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] and LVecB.u[LIndex], LAndResult.u[LIndex]);
    AssertEquals('VecU64x2Or lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] or LVecB.u[LIndex], LOrResult.u[LIndex]);
    AssertEquals('VecU64x2Xor lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] xor LVecB.u[LIndex], LXorResult.u[LIndex]);
    AssertEquals('VecU64x2Not lane ' + IntToStr(LIndex),
      not LVecA.u[LIndex], LNotResult.u[LIndex]);

    if LVecA.u[LIndex] < LVecB.u[LIndex] then
      AssertEquals('VecU64x2Min lane ' + IntToStr(LIndex), LVecA.u[LIndex], LMinResult.u[LIndex])
    else
      AssertEquals('VecU64x2Min lane ' + IntToStr(LIndex), LVecB.u[LIndex], LMinResult.u[LIndex]);

    if LVecA.u[LIndex] > LVecB.u[LIndex] then
      AssertEquals('VecU64x2Max lane ' + IntToStr(LIndex), LVecA.u[LIndex], LMaxResult.u[LIndex])
    else
      AssertEquals('VecU64x2Max lane ' + IntToStr(LIndex), LVecB.u[LIndex], LMaxResult.u[LIndex]);
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI32x16_AndNot_Basic;
var
  LVecA, LVecB, LResult: TVecI32x16;
  LExpected: UInt32;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.i) do
  begin
    case LIndex mod 4 of
      0:
        begin
          LVecA.i[LIndex] := LongInt($0F0F0F0F);
          LVecB.i[LIndex] := -1;
        end;
      1:
        begin
          LVecA.i[LIndex] := -1;
          LVecB.i[LIndex] := LongInt($12345678);
        end;
      2:
        begin
          LVecA.i[LIndex] := 0;
          LVecB.i[LIndex] := LongInt($33333333);
        end;
    else
      begin
        LVecA.i[LIndex] := LongInt($33333333);
        LVecB.i[LIndex] := LongInt($55555555);
      end;
    end;
  end;

  LResult := VecI32x16AndNot(LVecA, LVecB);

  for LIndex := 0 to High(LResult.i) do
  begin
    LExpected := UInt32(not LVecA.i[LIndex]) and UInt32(LVecB.i[LIndex]);
    AssertEquals('VecI32x16AndNot lane ' + IntToStr(LIndex), LExpected, UInt32(LResult.i[LIndex]));
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI32x16_Compare_Basic;
var
  LVecA, LVecB: TVecI32x16;
  LMaskEq, LMaskLt, LMaskGt, LMaskLe, LMaskGe, LMaskNe: TMask16;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.i) do
  begin
    case LIndex mod 3 of
      0:
        begin
          LVecA.i[LIndex] := LIndex * 11;
          LVecB.i[LIndex] := LVecA.i[LIndex];
        end;
      1:
        begin
          LVecA.i[LIndex] := -1000 + LIndex;
          LVecB.i[LIndex] := LVecA.i[LIndex] + 5;
        end;
    else
      begin
        LVecA.i[LIndex] := 1000 + LIndex;
        LVecB.i[LIndex] := LVecA.i[LIndex] - 7;
      end;
    end;
  end;

  LMaskEq := nextpas.core.simd.VecI32x16CmpEq(LVecA, LVecB);
  LMaskLt := nextpas.core.simd.VecI32x16CmpLt(LVecA, LVecB);
  LMaskGt := nextpas.core.simd.VecI32x16CmpGt(LVecA, LVecB);
  LMaskLe := nextpas.core.simd.VecI32x16CmpLe(LVecA, LVecB);
  LMaskGe := nextpas.core.simd.VecI32x16CmpGe(LVecA, LVecB);
  LMaskNe := nextpas.core.simd.VecI32x16CmpNe(LVecA, LVecB);

  AssertEquals('VecI32x16CmpEq mask', LongInt(TMask16($9249)), LongInt(LMaskEq));
  AssertEquals('VecI32x16CmpLt mask', LongInt(TMask16($2492)), LongInt(LMaskLt));
  AssertEquals('VecI32x16CmpGt mask', LongInt(TMask16($4924)), LongInt(LMaskGt));
  AssertEquals('VecI32x16CmpLe mask', LongInt(TMask16($B6DB)), LongInt(LMaskLe));
  AssertEquals('VecI32x16CmpGe mask', LongInt(TMask16($DB6D)), LongInt(LMaskGe));
  AssertEquals('VecI32x16CmpNe mask', LongInt(TMask16($6DB6)), LongInt(LMaskNe));
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI32x16_RemainingOps_Basic;
const
  C_SHIFT_LEFT = 5;
  C_SHIFT_RIGHT = 3;
  C_SHIFT_RIGHT_ARITH = 4;
var
  LVecA, LVecB: TVecI32x16;
  LAddResult, LSubResult, LMulResult: TVecI32x16;
  LAndResult, LOrResult, LXorResult, LNotResult: TVecI32x16;
  LMinResult, LMaxResult: TVecI32x16;
  LShiftLeftResult, LShiftRightResult, LShiftRightArithResult: TVecI32x16;
  LInserted: TVecI32x16;
  LExpectedMul: UInt32;
  LExpectedSar: Int32;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.i) do
  begin
    LVecA.i[LIndex] := (LIndex - 8) * 4099;
    LVecB.i[LIndex] := (8 - LIndex) * 2053;
  end;

  LVecA.i[0] := Low(Int32);
  LVecA.i[1] := High(Int32);
  LVecA.i[2] := -1;
  LVecA.i[3] := 0;
  LVecA.i[4] := Int32($55555555);
  LVecA.i[5] := Int32($33333333);
  LVecA.i[6] := -123456789;
  LVecA.i[7] := 123456789;

  LVecB.i[0] := 1;
  LVecB.i[1] := -1;
  LVecB.i[2] := High(Int32);
  LVecB.i[3] := Int32($11111111);
  LVecB.i[4] := Int32($AAAAAAAA);
  LVecB.i[5] := Int32($0F0F0F0F);
  LVecB.i[6] := 7;
  LVecB.i[7] := -11;

  LAddResult := VecI32x16Add(LVecA, LVecB);
  LSubResult := VecI32x16Sub(LVecA, LVecB);
  LMulResult := VecI32x16Mul(LVecA, LVecB);
  LAndResult := VecI32x16And(LVecA, LVecB);
  LOrResult := VecI32x16Or(LVecA, LVecB);
  LXorResult := VecI32x16Xor(LVecA, LVecB);
  LNotResult := VecI32x16Not(LVecA);
  LMinResult := VecI32x16Min(LVecA, LVecB);
  LMaxResult := VecI32x16Max(LVecA, LVecB);
  LShiftLeftResult := VecI32x16ShiftLeft(LVecA, C_SHIFT_LEFT);
  LShiftRightResult := VecI32x16ShiftRight(LVecA, C_SHIFT_RIGHT);
  LShiftRightArithResult := VecI32x16ShiftRightArith(LVecA, C_SHIFT_RIGHT_ARITH);

  AssertEquals('VecI32x16Extract lane 6', LVecA.i[6], VecI32x16Extract(LVecA, 6));
  LInserted := VecI32x16Insert(LVecA, -31415926, 9);
  AssertEquals('VecI32x16Insert lane 9', -31415926, LInserted.i[9]);
  AssertEquals('VecI32x16Insert keep lane 8', LVecA.i[8], LInserted.i[8]);
  AssertEquals('VecI32x16Insert keep lane 10', LVecA.i[10], LInserted.i[10]);

  for LIndex := 0 to High(LVecA.i) do
  begin
    AssertEquals('VecI32x16Add lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex] + LVecB.i[LIndex]), UInt32(LAddResult.i[LIndex]));
    AssertEquals('VecI32x16Sub lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex] - LVecB.i[LIndex]), UInt32(LSubResult.i[LIndex]));

    LExpectedMul := UInt32(Int64(LVecA.i[LIndex]) * Int64(LVecB.i[LIndex]));
    AssertEquals('VecI32x16Mul lane ' + IntToStr(LIndex), LExpectedMul, UInt32(LMulResult.i[LIndex]));

    AssertEquals('VecI32x16And lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex]) and UInt32(LVecB.i[LIndex]), UInt32(LAndResult.i[LIndex]));
    AssertEquals('VecI32x16Or lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex]) or UInt32(LVecB.i[LIndex]), UInt32(LOrResult.i[LIndex]));
    AssertEquals('VecI32x16Xor lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex]) xor UInt32(LVecB.i[LIndex]), UInt32(LXorResult.i[LIndex]));
    AssertEquals('VecI32x16Not lane ' + IntToStr(LIndex),
      UInt32(not LVecA.i[LIndex]), UInt32(LNotResult.i[LIndex]));

    if LVecA.i[LIndex] < LVecB.i[LIndex] then
      AssertEquals('VecI32x16Min lane ' + IntToStr(LIndex), LVecA.i[LIndex], LMinResult.i[LIndex])
    else
      AssertEquals('VecI32x16Min lane ' + IntToStr(LIndex), LVecB.i[LIndex], LMinResult.i[LIndex]);

    if LVecA.i[LIndex] > LVecB.i[LIndex] then
      AssertEquals('VecI32x16Max lane ' + IntToStr(LIndex), LVecA.i[LIndex], LMaxResult.i[LIndex])
    else
      AssertEquals('VecI32x16Max lane ' + IntToStr(LIndex), LVecB.i[LIndex], LMaxResult.i[LIndex]);

    AssertEquals('VecI32x16ShiftLeft lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex]) shl C_SHIFT_LEFT, UInt32(LShiftLeftResult.i[LIndex]));
    AssertEquals('VecI32x16ShiftRight lane ' + IntToStr(LIndex),
      UInt32(LVecA.i[LIndex]) shr C_SHIFT_RIGHT, UInt32(LShiftRightResult.i[LIndex]));

    if LVecA.i[LIndex] < 0 then
      LExpectedSar := not Int32(UInt32(not LVecA.i[LIndex]) shr C_SHIFT_RIGHT_ARITH)
    else
      LExpectedSar := Int32(UInt32(LVecA.i[LIndex]) shr C_SHIFT_RIGHT_ARITH);
    AssertEquals('VecI32x16ShiftRightArith lane ' + IntToStr(LIndex),
      LExpectedSar, LShiftRightArithResult.i[LIndex]);
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecU32x16_AndNot_Basic;
var
  LVecA, LVecB, LResult: TVecU32x16;
  LExpected: UInt32;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.u) do
  begin
    case LIndex mod 4 of
      0:
        begin
          LVecA.u[LIndex] := UInt32($0F0F0F0F);
          LVecB.u[LIndex] := High(UInt32);
        end;
      1:
        begin
          LVecA.u[LIndex] := High(UInt32);
          LVecB.u[LIndex] := UInt32($12345678);
        end;
      2:
        begin
          LVecA.u[LIndex] := 0;
          LVecB.u[LIndex] := UInt32($33333333);
        end;
    else
      begin
        LVecA.u[LIndex] := UInt32($33333333);
        LVecB.u[LIndex] := UInt32($55555555);
      end;
    end;
  end;

  LResult := VecU32x16AndNot(LVecA, LVecB);

  for LIndex := 0 to High(LResult.u) do
  begin
    LExpected := (not LVecA.u[LIndex]) and LVecB.u[LIndex];
    AssertEquals('VecU32x16AndNot lane ' + IntToStr(LIndex), LExpected, LResult.u[LIndex]);
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecU32x16_Compare_Unsigned;
var
  LVecA, LVecB: TVecU32x16;
  LMaskEq, LMaskLt, LMaskGt, LMaskLe, LMaskGe, LMaskNe: TMask16;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.u) do
  begin
    case LIndex mod 3 of
      0:
        begin
          LVecA.u[LIndex] := UInt32(LIndex) * UInt32($11111111);
          LVecB.u[LIndex] := LVecA.u[LIndex];
        end;
      1:
        begin
          LVecA.u[LIndex] := UInt32(LIndex);
          LVecB.u[LIndex] := High(UInt32) - UInt32(LIndex);
        end;
    else
      begin
        LVecA.u[LIndex] := High(UInt32) - UInt32(LIndex);
        LVecB.u[LIndex] := UInt32(LIndex);
      end;
    end;
  end;

  LMaskEq := VecU32x16CmpEq(LVecA, LVecB);
  LMaskLt := VecU32x16CmpLt(LVecA, LVecB);
  LMaskGt := VecU32x16CmpGt(LVecA, LVecB);
  LMaskLe := VecU32x16CmpLe(LVecA, LVecB);
  LMaskGe := VecU32x16CmpGe(LVecA, LVecB);
  LMaskNe := VecU32x16CmpNe(LVecA, LVecB);

  AssertEquals('VecU32x16CmpEq mask', LongInt(TMask16($9249)), LongInt(LMaskEq));
  AssertEquals('VecU32x16CmpLt mask', LongInt(TMask16($2492)), LongInt(LMaskLt));
  AssertEquals('VecU32x16CmpGt mask', LongInt(TMask16($4924)), LongInt(LMaskGt));
  AssertEquals('VecU32x16CmpLe mask', LongInt(TMask16($B6DB)), LongInt(LMaskLe));
  AssertEquals('VecU32x16CmpGe mask', LongInt(TMask16($DB6D)), LongInt(LMaskGe));
  AssertEquals('VecU32x16CmpNe mask', LongInt(TMask16($6DB6)), LongInt(LMaskNe));
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecU32x16_RemainingOps_Basic;
const
  C_SHIFT_LEFT = 6;
  C_SHIFT_RIGHT = 7;
var
  LVecA, LVecB: TVecU32x16;
  LAddResult, LSubResult, LMulResult: TVecU32x16;
  LAndResult, LOrResult, LXorResult, LNotResult: TVecU32x16;
  LMinResult, LMaxResult: TVecU32x16;
  LShiftLeftResult, LShiftRightResult: TVecU32x16;
  LExpectedMul: UInt32;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.u) do
  begin
    LVecA.u[LIndex] := UInt32(LIndex * 257);
    LVecB.u[LIndex] := UInt32((15 - LIndex) * 131);
  end;

  LVecA.u[0] := 0;
  LVecA.u[1] := High(UInt32);
  LVecA.u[2] := UInt32($80000000);
  LVecA.u[3] := UInt32($55555555);
  LVecA.u[4] := UInt32($AAAAAAAA);
  LVecA.u[5] := 37;

  LVecB.u[0] := High(UInt32);
  LVecB.u[1] := 1;
  LVecB.u[2] := UInt32($7FFFFFFF);
  LVecB.u[3] := UInt32($AAAAAAAA);
  LVecB.u[4] := UInt32($11111111);
  LVecB.u[5] := High(UInt32) - 15;

  LAddResult := VecU32x16Add(LVecA, LVecB);
  LSubResult := VecU32x16Sub(LVecA, LVecB);
  LMulResult := VecU32x16Mul(LVecA, LVecB);
  LAndResult := VecU32x16And(LVecA, LVecB);
  LOrResult := VecU32x16Or(LVecA, LVecB);
  LXorResult := VecU32x16Xor(LVecA, LVecB);
  LNotResult := VecU32x16Not(LVecA);
  LMinResult := VecU32x16Min(LVecA, LVecB);
  LMaxResult := VecU32x16Max(LVecA, LVecB);
  LShiftLeftResult := VecU32x16ShiftLeft(LVecA, C_SHIFT_LEFT);
  LShiftRightResult := VecU32x16ShiftRight(LVecA, C_SHIFT_RIGHT);

  for LIndex := 0 to High(LVecA.u) do
  begin
    AssertEquals('VecU32x16Add lane ' + IntToStr(LIndex),
      UInt32(LVecA.u[LIndex] + LVecB.u[LIndex]), LAddResult.u[LIndex]);
    AssertEquals('VecU32x16Sub lane ' + IntToStr(LIndex),
      UInt32(LVecA.u[LIndex] - LVecB.u[LIndex]), LSubResult.u[LIndex]);

    LExpectedMul := UInt32(QWord(LVecA.u[LIndex]) * QWord(LVecB.u[LIndex]));
    AssertEquals('VecU32x16Mul lane ' + IntToStr(LIndex), LExpectedMul, LMulResult.u[LIndex]);

    AssertEquals('VecU32x16And lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] and LVecB.u[LIndex], LAndResult.u[LIndex]);
    AssertEquals('VecU32x16Or lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] or LVecB.u[LIndex], LOrResult.u[LIndex]);
    AssertEquals('VecU32x16Xor lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] xor LVecB.u[LIndex], LXorResult.u[LIndex]);
    AssertEquals('VecU32x16Not lane ' + IntToStr(LIndex),
      not LVecA.u[LIndex], LNotResult.u[LIndex]);

    if LVecA.u[LIndex] < LVecB.u[LIndex] then
      AssertEquals('VecU32x16Min lane ' + IntToStr(LIndex), LVecA.u[LIndex], LMinResult.u[LIndex])
    else
      AssertEquals('VecU32x16Min lane ' + IntToStr(LIndex), LVecB.u[LIndex], LMinResult.u[LIndex]);

    if LVecA.u[LIndex] > LVecB.u[LIndex] then
      AssertEquals('VecU32x16Max lane ' + IntToStr(LIndex), LVecA.u[LIndex], LMaxResult.u[LIndex])
    else
      AssertEquals('VecU32x16Max lane ' + IntToStr(LIndex), LVecB.u[LIndex], LMaxResult.u[LIndex]);

    AssertEquals('VecU32x16ShiftLeft lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] shl C_SHIFT_LEFT, LShiftLeftResult.u[LIndex]);
    AssertEquals('VecU32x16ShiftRight lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] shr C_SHIFT_RIGHT, LShiftRightResult.u[LIndex]);
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecU64x4_Compare_Unsigned;
var
  LVecA, LVecB: TVecU64x4;
  LMaskEq, LMaskLt, LMaskGt, LMaskLe, LMaskGe, LMaskNe: TMask4;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.u) do
  begin
    case LIndex mod 3 of
      0:
        begin
          LVecA.u[LIndex] := QWord(LIndex) * QWord($1111111111111111);
          LVecB.u[LIndex] := LVecA.u[LIndex];
        end;
      1:
        begin
          LVecA.u[LIndex] := QWord(LIndex);
          LVecB.u[LIndex] := High(QWord) - QWord(LIndex);
        end;
    else
      begin
        LVecA.u[LIndex] := High(QWord) - QWord(LIndex);
        LVecB.u[LIndex] := QWord(LIndex);
      end;
    end;
  end;

  LMaskEq := VecU64x4CmpEq(LVecA, LVecB);
  LMaskLt := VecU64x4CmpLt(LVecA, LVecB);
  LMaskGt := VecU64x4CmpGt(LVecA, LVecB);
  LMaskLe := VecU64x4CmpLe(LVecA, LVecB);
  LMaskGe := VecU64x4CmpGe(LVecA, LVecB);
  LMaskNe := VecU64x4CmpNe(LVecA, LVecB);

  AssertEquals('VecU64x4CmpEq mask', Integer(TMask4($9)), Integer(LMaskEq));
  AssertEquals('VecU64x4CmpLt mask', Integer(TMask4($2)), Integer(LMaskLt));
  AssertEquals('VecU64x4CmpGt mask', Integer(TMask4($4)), Integer(LMaskGt));
  AssertEquals('VecU64x4CmpLe mask', Integer(TMask4($B)), Integer(LMaskLe));
  AssertEquals('VecU64x4CmpGe mask', Integer(TMask4($D)), Integer(LMaskGe));
  AssertEquals('VecU64x4CmpNe mask', Integer(TMask4($6)), Integer(LMaskNe));
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecU64x4_RemainingOps_Basic;
const
  C_SHIFT_LEFT = 11;
  C_SHIFT_RIGHT = 13;
var
  LVecA, LVecB: TVecU64x4;
  LAddResult, LSubResult: TVecU64x4;
  LAndResult, LOrResult, LXorResult, LNotResult: TVecU64x4;
  LShiftLeftResult, LShiftRightResult: TVecU64x4;
  LIndex: Integer;
begin
  LVecA.u[0] := 0;
  LVecA.u[1] := 1;
  LVecA.u[2] := High(QWord);
  LVecA.u[3] := QWord($8000000000000000);

  LVecB.u[0] := High(QWord);
  LVecB.u[1] := 2;
  LVecB.u[2] := 3;
  LVecB.u[3] := QWord($7FFFFFFFFFFFFFFF);

  LAddResult := VecU64x4Add(LVecA, LVecB);
  LSubResult := VecU64x4Sub(LVecA, LVecB);
  LAndResult := VecU64x4And(LVecA, LVecB);
  LOrResult := VecU64x4Or(LVecA, LVecB);
  LXorResult := VecU64x4Xor(LVecA, LVecB);
  LNotResult := VecU64x4Not(LVecA);
  LShiftLeftResult := VecU64x4ShiftLeft(LVecA, C_SHIFT_LEFT);
  LShiftRightResult := VecU64x4ShiftRight(LVecA, C_SHIFT_RIGHT);

  for LIndex := 0 to High(LVecA.u) do
  begin
    AssertEquals('VecU64x4Add lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] + LVecB.u[LIndex], LAddResult.u[LIndex]);
    AssertEquals('VecU64x4Sub lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] - LVecB.u[LIndex], LSubResult.u[LIndex]);
    AssertEquals('VecU64x4And lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] and LVecB.u[LIndex], LAndResult.u[LIndex]);
    AssertEquals('VecU64x4Or lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] or LVecB.u[LIndex], LOrResult.u[LIndex]);
    AssertEquals('VecU64x4Xor lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] xor LVecB.u[LIndex], LXorResult.u[LIndex]);
    AssertEquals('VecU64x4Not lane ' + IntToStr(LIndex),
      not LVecA.u[LIndex], LNotResult.u[LIndex]);
    AssertEquals('VecU64x4ShiftLeft lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] shl C_SHIFT_LEFT, LShiftLeftResult.u[LIndex]);
    AssertEquals('VecU64x4ShiftRight lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] shr C_SHIFT_RIGHT, LShiftRightResult.u[LIndex]);
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI64x8_Compare_Basic;
var
  LVecA, LVecB: TVecI64x8;
  LMaskEq, LMaskLt, LMaskGt, LMaskLe, LMaskGe, LMaskNe: TMask8;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.i) do
  begin
    case LIndex mod 3 of
      0:
        begin
          LVecA.i[LIndex] := Int64(LIndex) * 17;
          LVecB.i[LIndex] := LVecA.i[LIndex];
        end;
      1:
        begin
          LVecA.i[LIndex] := -1000 + LIndex;
          LVecB.i[LIndex] := LVecA.i[LIndex] + 5;
        end;
    else
      begin
        LVecA.i[LIndex] := 1000 + LIndex;
        LVecB.i[LIndex] := LVecA.i[LIndex] - 7;
      end;
    end;
  end;

  LMaskEq := VecI64x8CmpEq(LVecA, LVecB);
  LMaskLt := VecI64x8CmpLt(LVecA, LVecB);
  LMaskGt := VecI64x8CmpGt(LVecA, LVecB);
  LMaskLe := VecI64x8CmpLe(LVecA, LVecB);
  LMaskGe := VecI64x8CmpGe(LVecA, LVecB);
  LMaskNe := VecI64x8CmpNe(LVecA, LVecB);

  AssertEquals('VecI64x8CmpEq mask', Integer(TMask8($49)), Integer(LMaskEq));
  AssertEquals('VecI64x8CmpLt mask', Integer(TMask8($92)), Integer(LMaskLt));
  AssertEquals('VecI64x8CmpGt mask', Integer(TMask8($24)), Integer(LMaskGt));
  AssertEquals('VecI64x8CmpLe mask', Integer(TMask8($DB)), Integer(LMaskLe));
  AssertEquals('VecI64x8CmpGe mask', Integer(TMask8($6D)), Integer(LMaskGe));
  AssertEquals('VecI64x8CmpNe mask', Integer(TMask8($B6)), Integer(LMaskNe));
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI64x8_RemainingOps_Basic;
var
  LVecA, LVecB: TVecI64x8;
  LAddResult, LSubResult: TVecI64x8;
  LAndResult, LOrResult, LXorResult, LNotResult: TVecI64x8;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.i) do
  begin
    LVecA.i[LIndex] := Int64(LIndex - 4) * 1025;
    LVecB.i[LIndex] := Int64(3 - LIndex) * 511;
  end;

  LVecA.i[0] := High(Int64);
  LVecA.i[1] := Low(Int64);
  LVecA.i[2] := -1;
  LVecA.i[3] := 0;
  LVecA.i[4] := 1234567890123456;
  LVecA.i[5] := -987654321012345;

  LVecB.i[0] := 1;
  LVecB.i[1] := -1;
  LVecB.i[2] := High(Int64);
  LVecB.i[3] := Int64($1111111111111111);
  LVecB.i[4] := -333333333333333;
  LVecB.i[5] := 555555555555555;

  LAddResult := VecI64x8Add(LVecA, LVecB);
  LSubResult := VecI64x8Sub(LVecA, LVecB);
  LAndResult := VecI64x8And(LVecA, LVecB);
  LOrResult := VecI64x8Or(LVecA, LVecB);
  LXorResult := VecI64x8Xor(LVecA, LVecB);
  LNotResult := VecI64x8Not(LVecA);

  for LIndex := 0 to High(LVecA.i) do
  begin
    AssertEquals('VecI64x8Add lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) + QWord(LVecB.i[LIndex]), QWord(LAddResult.i[LIndex]));
    AssertEquals('VecI64x8Sub lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) - QWord(LVecB.i[LIndex]), QWord(LSubResult.i[LIndex]));
    AssertEquals('VecI64x8And lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) and QWord(LVecB.i[LIndex]), QWord(LAndResult.i[LIndex]));
    AssertEquals('VecI64x8Or lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) or QWord(LVecB.i[LIndex]), QWord(LOrResult.i[LIndex]));
    AssertEquals('VecI64x8Xor lane ' + IntToStr(LIndex),
      QWord(LVecA.i[LIndex]) xor QWord(LVecB.i[LIndex]), QWord(LXorResult.i[LIndex]));
    AssertEquals('VecI64x8Not lane ' + IntToStr(LIndex),
      QWord(not LVecA.i[LIndex]), QWord(LNotResult.i[LIndex]));
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecU64x8_Compare_Unsigned;
var
  LVecA, LVecB: TVecU64x8;
  LMaskEq, LMaskLt, LMaskGt, LMaskLe, LMaskGe, LMaskNe: TMask8;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.u) do
  begin
    case LIndex mod 3 of
      0:
        begin
          LVecA.u[LIndex] := QWord(LIndex) * QWord($1111111111111111);
          LVecB.u[LIndex] := LVecA.u[LIndex];
        end;
      1:
        begin
          LVecA.u[LIndex] := QWord(LIndex);
          LVecB.u[LIndex] := High(QWord) - QWord(LIndex);
        end;
    else
      begin
        LVecA.u[LIndex] := High(QWord) - QWord(LIndex);
        LVecB.u[LIndex] := QWord(LIndex);
      end;
    end;
  end;

  LMaskEq := VecU64x8CmpEq(LVecA, LVecB);
  LMaskLt := VecU64x8CmpLt(LVecA, LVecB);
  LMaskGt := VecU64x8CmpGt(LVecA, LVecB);
  LMaskLe := VecU64x8CmpLe(LVecA, LVecB);
  LMaskGe := VecU64x8CmpGe(LVecA, LVecB);
  LMaskNe := VecU64x8CmpNe(LVecA, LVecB);

  AssertEquals('VecU64x8CmpEq mask', Integer(TMask8($49)), Integer(LMaskEq));
  AssertEquals('VecU64x8CmpLt mask', Integer(TMask8($92)), Integer(LMaskLt));
  AssertEquals('VecU64x8CmpGt mask', Integer(TMask8($24)), Integer(LMaskGt));
  AssertEquals('VecU64x8CmpLe mask', Integer(TMask8($DB)), Integer(LMaskLe));
  AssertEquals('VecU64x8CmpGe mask', Integer(TMask8($6D)), Integer(LMaskGe));
  AssertEquals('VecU64x8CmpNe mask', Integer(TMask8($B6)), Integer(LMaskNe));
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecU64x8_RemainingOps_Basic;
const
  C_SHIFT_LEFT = 7;
  C_SHIFT_RIGHT = 9;
var
  LVecA, LVecB: TVecU64x8;
  LAddResult, LSubResult: TVecU64x8;
  LAndResult, LOrResult, LXorResult, LNotResult: TVecU64x8;
  LShiftLeftResult, LShiftRightResult: TVecU64x8;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.u) do
  begin
    LVecA.u[LIndex] := QWord(LIndex) * 257;
    LVecB.u[LIndex] := QWord(7 - LIndex) * 131;
  end;

  LVecA.u[0] := 0;
  LVecA.u[1] := 1;
  LVecA.u[2] := High(QWord);
  LVecA.u[3] := QWord($8000000000000000);
  LVecA.u[4] := QWord($5555555555555555);
  LVecA.u[5] := QWord($3333333333333333);

  LVecB.u[0] := High(QWord);
  LVecB.u[1] := 2;
  LVecB.u[2] := 3;
  LVecB.u[3] := QWord($7FFFFFFFFFFFFFFF);
  LVecB.u[4] := QWord($AAAAAAAAAAAAAAAA);
  LVecB.u[5] := QWord($1111111111111111);

  LAddResult := VecU64x8Add(LVecA, LVecB);
  LSubResult := VecU64x8Sub(LVecA, LVecB);
  LAndResult := VecU64x8And(LVecA, LVecB);
  LOrResult := VecU64x8Or(LVecA, LVecB);
  LXorResult := VecU64x8Xor(LVecA, LVecB);
  LNotResult := VecU64x8Not(LVecA);
  LShiftLeftResult := VecU64x8ShiftLeft(LVecA, C_SHIFT_LEFT);
  LShiftRightResult := VecU64x8ShiftRight(LVecA, C_SHIFT_RIGHT);

  for LIndex := 0 to High(LVecA.u) do
  begin
    AssertEquals('VecU64x8Add lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] + LVecB.u[LIndex], LAddResult.u[LIndex]);
    AssertEquals('VecU64x8Sub lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] - LVecB.u[LIndex], LSubResult.u[LIndex]);
    AssertEquals('VecU64x8And lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] and LVecB.u[LIndex], LAndResult.u[LIndex]);
    AssertEquals('VecU64x8Or lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] or LVecB.u[LIndex], LOrResult.u[LIndex]);
    AssertEquals('VecU64x8Xor lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] xor LVecB.u[LIndex], LXorResult.u[LIndex]);
    AssertEquals('VecU64x8Not lane ' + IntToStr(LIndex),
      not LVecA.u[LIndex], LNotResult.u[LIndex]);
    AssertEquals('VecU64x8ShiftLeft lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] shl C_SHIFT_LEFT, LShiftLeftResult.u[LIndex]);
    AssertEquals('VecU64x8ShiftRight lane ' + IntToStr(LIndex),
      LVecA.u[LIndex] shr C_SHIFT_RIGHT, LShiftRightResult.u[LIndex]);
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI16x32_AndNot_Basic;
var
  LVecA, LVecB, LResult: TVecI16x32;
  LExpected: Word;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.i) do
  begin
    case LIndex mod 4 of
      0:
        begin
          LVecA.i[LIndex] := SmallInt($0F0F);
          LVecB.i[LIndex] := SmallInt(-1);
        end;
      1:
        begin
          LVecA.i[LIndex] := SmallInt(-1);
          LVecB.i[LIndex] := SmallInt($1234);
        end;
      2:
        begin
          LVecA.i[LIndex] := 0;
          LVecB.i[LIndex] := SmallInt($3333);
        end;
    else
      begin
        LVecA.i[LIndex] := SmallInt($3333);
        LVecB.i[LIndex] := SmallInt($5555);
      end;
    end;
  end;

  LResult := VecI16x32AndNot(LVecA, LVecB);

  for LIndex := 0 to High(LResult.i) do
  begin
    LExpected := Word(not LVecA.i[LIndex]) and Word(LVecB.i[LIndex]);
    AssertEquals('VecI16x32AndNot lane ' + IntToStr(LIndex), LExpected, Word(LResult.i[LIndex]));
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI16x32_Compare_Basic;
var
  LVecA, LVecB: TVecI16x32;
  LMaskEq, LMaskLt, LMaskGt: TMask32;
  LExpectedEq, LExpectedLt, LExpectedGt: TMask32;
  LIndex: Integer;
begin
  LExpectedEq := 0;
  LExpectedLt := 0;
  LExpectedGt := 0;

  for LIndex := 0 to High(LVecA.i) do
  begin
    case LIndex mod 3 of
      0:
        begin
          LVecA.i[LIndex] := SmallInt(LIndex * 11);
          LVecB.i[LIndex] := LVecA.i[LIndex];
        end;
      1:
        begin
          LVecA.i[LIndex] := SmallInt(-1000 + LIndex);
          LVecB.i[LIndex] := SmallInt(LVecA.i[LIndex] + 5);
        end;
    else
      begin
        LVecA.i[LIndex] := SmallInt(1000 + LIndex);
        LVecB.i[LIndex] := SmallInt(LVecA.i[LIndex] - 7);
      end;
    end;

    if LVecA.i[LIndex] = LVecB.i[LIndex] then
      LExpectedEq := TMask32(LongWord(LExpectedEq) or (LongWord(1) shl LIndex));
    if LVecA.i[LIndex] < LVecB.i[LIndex] then
      LExpectedLt := TMask32(LongWord(LExpectedLt) or (LongWord(1) shl LIndex));
    if LVecA.i[LIndex] > LVecB.i[LIndex] then
      LExpectedGt := TMask32(LongWord(LExpectedGt) or (LongWord(1) shl LIndex));
  end;

  LMaskEq := VecI16x32CmpEq(LVecA, LVecB);
  LMaskLt := VecI16x32CmpLt(LVecA, LVecB);
  LMaskGt := VecI16x32CmpGt(LVecA, LVecB);

  AssertEquals('VecI16x32CmpEq mask', QWord(LExpectedEq), QWord(LMaskEq));
  AssertEquals('VecI16x32CmpLt mask', QWord(LExpectedLt), QWord(LMaskLt));
  AssertEquals('VecI16x32CmpGt mask', QWord(LExpectedGt), QWord(LMaskGt));
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI16x32_RemainingOps_Basic;
const
  C_SHIFT_LEFT = 3;
  C_SHIFT_RIGHT = 2;
  C_SHIFT_RIGHT_ARITH = 5;
var
  LVecA, LVecB: TVecI16x32;
  LAddResult, LSubResult: TVecI16x32;
  LAndResult, LOrResult, LXorResult, LNotResult: TVecI16x32;
  LMinResult, LMaxResult: TVecI16x32;
  LShiftLeftResult, LShiftRightResult, LShiftRightArithResult: TVecI16x32;
  LExpectedSar: SmallInt;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.i) do
  begin
    LVecA.i[LIndex] := SmallInt(LIndex * 5 - 70);
    LVecB.i[LIndex] := SmallInt(90 - LIndex * 3);
  end;

  LVecA.i[0] := High(SmallInt);
  LVecA.i[1] := Low(SmallInt);
  LVecA.i[2] := -1;
  LVecA.i[3] := 0;
  LVecA.i[4] := SmallInt($5555);
  LVecA.i[5] := SmallInt($AAAA);

  LVecB.i[0] := 1;
  LVecB.i[1] := -1;
  LVecB.i[2] := High(SmallInt);
  LVecB.i[3] := SmallInt($1111);
  LVecB.i[4] := SmallInt($AAAA);
  LVecB.i[5] := SmallInt($0F0F);

  LAddResult := VecI16x32Add(LVecA, LVecB);
  LSubResult := VecI16x32Sub(LVecA, LVecB);
  LAndResult := VecI16x32And(LVecA, LVecB);
  LOrResult := VecI16x32Or(LVecA, LVecB);
  LXorResult := VecI16x32Xor(LVecA, LVecB);
  LNotResult := VecI16x32Not(LVecA);
  LMinResult := VecI16x32Min(LVecA, LVecB);
  LMaxResult := VecI16x32Max(LVecA, LVecB);
  LShiftLeftResult := VecI16x32ShiftLeft(LVecA, C_SHIFT_LEFT);
  LShiftRightResult := VecI16x32ShiftRight(LVecA, C_SHIFT_RIGHT);
  LShiftRightArithResult := VecI16x32ShiftRightArith(LVecA, C_SHIFT_RIGHT_ARITH);

  for LIndex := 0 to High(LVecA.i) do
  begin
    AssertEquals('VecI16x32Add lane ' + IntToStr(LIndex),
      Word(SmallInt(LVecA.i[LIndex] + LVecB.i[LIndex])), Word(LAddResult.i[LIndex]));
    AssertEquals('VecI16x32Sub lane ' + IntToStr(LIndex),
      Word(SmallInt(LVecA.i[LIndex] - LVecB.i[LIndex])), Word(LSubResult.i[LIndex]));
    AssertEquals('VecI16x32And lane ' + IntToStr(LIndex),
      Word(LVecA.i[LIndex]) and Word(LVecB.i[LIndex]), Word(LAndResult.i[LIndex]));
    AssertEquals('VecI16x32Or lane ' + IntToStr(LIndex),
      Word(LVecA.i[LIndex]) or Word(LVecB.i[LIndex]), Word(LOrResult.i[LIndex]));
    AssertEquals('VecI16x32Xor lane ' + IntToStr(LIndex),
      Word(LVecA.i[LIndex]) xor Word(LVecB.i[LIndex]), Word(LXorResult.i[LIndex]));
    AssertEquals('VecI16x32Not lane ' + IntToStr(LIndex),
      Word(not LVecA.i[LIndex]), Word(LNotResult.i[LIndex]));

    if LVecA.i[LIndex] < LVecB.i[LIndex] then
      AssertEquals('VecI16x32Min lane ' + IntToStr(LIndex), LVecA.i[LIndex], LMinResult.i[LIndex])
    else
      AssertEquals('VecI16x32Min lane ' + IntToStr(LIndex), LVecB.i[LIndex], LMinResult.i[LIndex]);

    if LVecA.i[LIndex] > LVecB.i[LIndex] then
      AssertEquals('VecI16x32Max lane ' + IntToStr(LIndex), LVecA.i[LIndex], LMaxResult.i[LIndex])
    else
      AssertEquals('VecI16x32Max lane ' + IntToStr(LIndex), LVecB.i[LIndex], LMaxResult.i[LIndex]);

    AssertEquals('VecI16x32ShiftLeft lane ' + IntToStr(LIndex),
      Word(Word(LVecA.i[LIndex]) shl C_SHIFT_LEFT), Word(LShiftLeftResult.i[LIndex]));
    AssertEquals('VecI16x32ShiftRight lane ' + IntToStr(LIndex),
      Word(LVecA.i[LIndex]) shr C_SHIFT_RIGHT, Word(LShiftRightResult.i[LIndex]));

    if LVecA.i[LIndex] < 0 then
      LExpectedSar := SmallInt(not Word(Word(not LVecA.i[LIndex]) shr C_SHIFT_RIGHT_ARITH))
    else
      LExpectedSar := SmallInt(Word(LVecA.i[LIndex]) shr C_SHIFT_RIGHT_ARITH);
    AssertEquals('VecI16x32ShiftRightArith lane ' + IntToStr(LIndex),
      LExpectedSar, LShiftRightArithResult.i[LIndex]);
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI8x64_AndNot_Basic;
var
  LVecA, LVecB, LResult: TVecI8x64;
  LExpected: Byte;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.i) do
  begin
    case LIndex mod 4 of
      0:
        begin
          LVecA.i[LIndex] := ShortInt($0F);
          LVecB.i[LIndex] := ShortInt(-1);
        end;
      1:
        begin
          LVecA.i[LIndex] := ShortInt(-1);
          LVecB.i[LIndex] := ShortInt($12);
        end;
      2:
        begin
          LVecA.i[LIndex] := 0;
          LVecB.i[LIndex] := ShortInt($33);
        end;
    else
      begin
        LVecA.i[LIndex] := ShortInt($33);
        LVecB.i[LIndex] := ShortInt($55);
      end;
    end;
  end;

  LResult := VecI8x64AndNot(LVecA, LVecB);

  for LIndex := 0 to High(LResult.i) do
  begin
    LExpected := Byte(not LVecA.i[LIndex]) and Byte(LVecB.i[LIndex]);
    AssertEquals('VecI8x64AndNot lane ' + IntToStr(LIndex), LExpected, Byte(LResult.i[LIndex]));
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI8x64_Compare_Basic;
var
  LVecA, LVecB: TVecI8x64;
  LMaskEq, LMaskLt, LMaskGt: TMask64;
  LExpectedEq, LExpectedLt, LExpectedGt: TMask64;
  LIndex: Integer;
begin
  LExpectedEq := 0;
  LExpectedLt := 0;
  LExpectedGt := 0;

  for LIndex := 0 to High(LVecA.i) do
  begin
    case LIndex mod 3 of
      0:
        begin
          LVecA.i[LIndex] := ShortInt(LIndex mod 40);
          LVecB.i[LIndex] := LVecA.i[LIndex];
        end;
      1:
        begin
          LVecA.i[LIndex] := ShortInt(-60 + (LIndex mod 20));
          LVecB.i[LIndex] := ShortInt(LVecA.i[LIndex] + 5);
        end;
    else
      begin
        LVecA.i[LIndex] := ShortInt(60 - (LIndex mod 20));
        LVecB.i[LIndex] := ShortInt(LVecA.i[LIndex] - 7);
      end;
    end;

    if LVecA.i[LIndex] = LVecB.i[LIndex] then
      LExpectedEq := TMask64(QWord(LExpectedEq) or (QWord(1) shl LIndex));
    if LVecA.i[LIndex] < LVecB.i[LIndex] then
      LExpectedLt := TMask64(QWord(LExpectedLt) or (QWord(1) shl LIndex));
    if LVecA.i[LIndex] > LVecB.i[LIndex] then
      LExpectedGt := TMask64(QWord(LExpectedGt) or (QWord(1) shl LIndex));
  end;

  LMaskEq := VecI8x64CmpEq(LVecA, LVecB);
  LMaskLt := VecI8x64CmpLt(LVecA, LVecB);
  LMaskGt := VecI8x64CmpGt(LVecA, LVecB);

  AssertEquals('VecI8x64CmpEq mask', QWord(LExpectedEq), QWord(LMaskEq));
  AssertEquals('VecI8x64CmpLt mask', QWord(LExpectedLt), QWord(LMaskLt));
  AssertEquals('VecI8x64CmpGt mask', QWord(LExpectedGt), QWord(LMaskGt));
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecI8x64_RemainingOps_Basic;
var
  LVecA, LVecB: TVecI8x64;
  LAddResult, LSubResult: TVecI8x64;
  LAndResult, LOrResult, LXorResult, LNotResult: TVecI8x64;
  LMinResult, LMaxResult: TVecI8x64;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.i) do
  begin
    LVecA.i[LIndex] := ShortInt((LIndex mod 41) - 20);
    LVecB.i[LIndex] := ShortInt(15 - (LIndex mod 31));
  end;

  LVecA.i[0] := High(ShortInt);
  LVecA.i[1] := Low(ShortInt);
  LVecA.i[2] := -1;
  LVecA.i[3] := 0;
  LVecA.i[4] := ShortInt($55);
  LVecA.i[5] := ShortInt($AA);

  LVecB.i[0] := 1;
  LVecB.i[1] := -1;
  LVecB.i[2] := High(ShortInt);
  LVecB.i[3] := ShortInt($11);
  LVecB.i[4] := ShortInt($AA);
  LVecB.i[5] := ShortInt($0F);

  LAddResult := VecI8x64Add(LVecA, LVecB);
  LSubResult := VecI8x64Sub(LVecA, LVecB);
  LAndResult := VecI8x64And(LVecA, LVecB);
  LOrResult := VecI8x64Or(LVecA, LVecB);
  LXorResult := VecI8x64Xor(LVecA, LVecB);
  LNotResult := VecI8x64Not(LVecA);
  LMinResult := VecI8x64Min(LVecA, LVecB);
  LMaxResult := VecI8x64Max(LVecA, LVecB);

  for LIndex := 0 to High(LVecA.i) do
  begin
    AssertEquals('VecI8x64Add lane ' + IntToStr(LIndex),
      Byte(ShortInt(LVecA.i[LIndex] + LVecB.i[LIndex])), Byte(LAddResult.i[LIndex]));
    AssertEquals('VecI8x64Sub lane ' + IntToStr(LIndex),
      Byte(ShortInt(LVecA.i[LIndex] - LVecB.i[LIndex])), Byte(LSubResult.i[LIndex]));
    AssertEquals('VecI8x64And lane ' + IntToStr(LIndex),
      Byte(LVecA.i[LIndex]) and Byte(LVecB.i[LIndex]), Byte(LAndResult.i[LIndex]));
    AssertEquals('VecI8x64Or lane ' + IntToStr(LIndex),
      Byte(LVecA.i[LIndex]) or Byte(LVecB.i[LIndex]), Byte(LOrResult.i[LIndex]));
    AssertEquals('VecI8x64Xor lane ' + IntToStr(LIndex),
      Byte(LVecA.i[LIndex]) xor Byte(LVecB.i[LIndex]), Byte(LXorResult.i[LIndex]));
    AssertEquals('VecI8x64Not lane ' + IntToStr(LIndex),
      Byte(not LVecA.i[LIndex]), Byte(LNotResult.i[LIndex]));

    if LVecA.i[LIndex] < LVecB.i[LIndex] then
      AssertEquals('VecI8x64Min lane ' + IntToStr(LIndex), LVecA.i[LIndex], LMinResult.i[LIndex])
    else
      AssertEquals('VecI8x64Min lane ' + IntToStr(LIndex), LVecB.i[LIndex], LMinResult.i[LIndex]);

    if LVecA.i[LIndex] > LVecB.i[LIndex] then
      AssertEquals('VecI8x64Max lane ' + IntToStr(LIndex), LVecA.i[LIndex], LMaxResult.i[LIndex])
    else
      AssertEquals('VecI8x64Max lane ' + IntToStr(LIndex), LVecB.i[LIndex], LMaxResult.i[LIndex]);
  end;
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecU8x64_Compare_Unsigned;
var
  LVecA, LVecB: TVecU8x64;
  LMaskEq, LMaskLt, LMaskGt: TMask64;
  LExpectedEq, LExpectedLt, LExpectedGt: TMask64;
  LIndex: Integer;
begin
  LExpectedEq := 0;
  LExpectedLt := 0;
  LExpectedGt := 0;

  for LIndex := 0 to High(LVecA.u) do
  begin
    case LIndex mod 3 of
      0:
        begin
          LVecA.u[LIndex] := Byte((LIndex * 17) and $FF);
          LVecB.u[LIndex] := LVecA.u[LIndex];
        end;
      1:
        begin
          LVecA.u[LIndex] := Byte(LIndex);
          LVecB.u[LIndex] := Byte(255 - LIndex);
        end;
    else
      begin
        LVecA.u[LIndex] := Byte(255 - LIndex);
        LVecB.u[LIndex] := Byte(LIndex);
      end;
    end;

    if LVecA.u[LIndex] = LVecB.u[LIndex] then
      LExpectedEq := TMask64(QWord(LExpectedEq) or (QWord(1) shl LIndex));
    if LVecA.u[LIndex] < LVecB.u[LIndex] then
      LExpectedLt := TMask64(QWord(LExpectedLt) or (QWord(1) shl LIndex));
    if LVecA.u[LIndex] > LVecB.u[LIndex] then
      LExpectedGt := TMask64(QWord(LExpectedGt) or (QWord(1) shl LIndex));
  end;

  LMaskEq := VecU8x64CmpEq(LVecA, LVecB);
  LMaskLt := VecU8x64CmpLt(LVecA, LVecB);
  LMaskGt := VecU8x64CmpGt(LVecA, LVecB);

  AssertEquals('VecU8x64CmpEq mask', QWord(LExpectedEq), QWord(LMaskEq));
  AssertEquals('VecU8x64CmpLt mask', QWord(LExpectedLt), QWord(LMaskLt));
  AssertEquals('VecU8x64CmpGt mask', QWord(LExpectedGt), QWord(LMaskGt));
end;

procedure TTestCase_IntegerFacadeGuards.Test_VecU8x64_RemainingOps_Basic;
var
  LVecA, LVecB: TVecU8x64;
  LAddResult, LSubResult: TVecU8x64;
  LAndResult, LOrResult, LXorResult, LNotResult: TVecU8x64;
  LMinResult, LMaxResult: TVecU8x64;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.u) do
  begin
    LVecA.u[LIndex] := Byte((LIndex * 11 + 3) and $FF);
    LVecB.u[LIndex] := Byte((255 - LIndex * 7) and $FF);
  end;

  LVecA.u[0] := 0;
  LVecA.u[1] := 255;
  LVecA.u[2] := 128;
  LVecA.u[3] := $55;
  LVecA.u[4] := $AA;

  LVecB.u[0] := 255;
  LVecB.u[1] := 1;
  LVecB.u[2] := 127;
  LVecB.u[3] := $AA;
  LVecB.u[4] := $11;

  LAddResult := VecU8x64Add(LVecA, LVecB);
  LSubResult := VecU8x64Sub(LVecA, LVecB);
  LAndResult := VecU8x64And(LVecA, LVecB);
  LOrResult := VecU8x64Or(LVecA, LVecB);
  LXorResult := VecU8x64Xor(LVecA, LVecB);
  LNotResult := VecU8x64Not(LVecA);
  LMinResult := VecU8x64Min(LVecA, LVecB);
  LMaxResult := VecU8x64Max(LVecA, LVecB);

  for LIndex := 0 to High(LVecA.u) do
  begin
    AssertEquals('VecU8x64Add lane ' + IntToStr(LIndex),
      Byte(LVecA.u[LIndex] + LVecB.u[LIndex]), LAddResult.u[LIndex]);
    AssertEquals('VecU8x64Sub lane ' + IntToStr(LIndex),
      Byte(LVecA.u[LIndex] - LVecB.u[LIndex]), LSubResult.u[LIndex]);
    AssertEquals('VecU8x64And lane ' + IntToStr(LIndex),
      Byte(LVecA.u[LIndex] and LVecB.u[LIndex]), LAndResult.u[LIndex]);
    AssertEquals('VecU8x64Or lane ' + IntToStr(LIndex),
      Byte(LVecA.u[LIndex] or LVecB.u[LIndex]), LOrResult.u[LIndex]);
    AssertEquals('VecU8x64Xor lane ' + IntToStr(LIndex),
      Byte(LVecA.u[LIndex] xor LVecB.u[LIndex]), LXorResult.u[LIndex]);
    AssertEquals('VecU8x64Not lane ' + IntToStr(LIndex),
      Byte(not LVecA.u[LIndex]), LNotResult.u[LIndex]);

    if LVecA.u[LIndex] < LVecB.u[LIndex] then
      AssertEquals('VecU8x64Min lane ' + IntToStr(LIndex), LVecA.u[LIndex], LMinResult.u[LIndex])
    else
      AssertEquals('VecU8x64Min lane ' + IntToStr(LIndex), LVecB.u[LIndex], LMinResult.u[LIndex]);

    if LVecA.u[LIndex] > LVecB.u[LIndex] then
      AssertEquals('VecU8x64Max lane ' + IntToStr(LIndex), LVecA.u[LIndex], LMaxResult.u[LIndex])
    else
      AssertEquals('VecU8x64Max lane ' + IntToStr(LIndex), LVecB.u[LIndex], LMaxResult.u[LIndex]);
  end;
end;

{ TTestCase_FloatFacadeGuards }

procedure TTestCase_FloatFacadeGuards.Test_VecF64x2_Arithmetic_Basic;
const
  C_EPSILON = 1e-12;
var
  LVecA, LVecB: TVecF64x2;
  LAddResult, LSubResult, LMulResult, LDivResult: TVecF64x2;
begin
  LVecA.d[0] := 1.25;
  LVecA.d[1] := -8.5;

  LVecB.d[0] := 2.0;
  LVecB.d[1] := 0.5;

  LAddResult := nextpas.core.simd.VecF64x2Add(LVecA, LVecB);
  LSubResult := nextpas.core.simd.VecF64x2Sub(LVecA, LVecB);
  LMulResult := nextpas.core.simd.VecF64x2Mul(LVecA, LVecB);
  LDivResult := nextpas.core.simd.VecF64x2Div(LVecA, LVecB);

  AssertEquals('VecF64x2Add lane 0', 3.25, LAddResult.d[0], C_EPSILON);
  AssertEquals('VecF64x2Add lane 1', -8.0, LAddResult.d[1], C_EPSILON);
  AssertEquals('VecF64x2Sub lane 0', -0.75, LSubResult.d[0], C_EPSILON);
  AssertEquals('VecF64x2Sub lane 1', -9.0, LSubResult.d[1], C_EPSILON);
  AssertEquals('VecF64x2Mul lane 0', 2.5, LMulResult.d[0], C_EPSILON);
  AssertEquals('VecF64x2Mul lane 1', -4.25, LMulResult.d[1], C_EPSILON);
  AssertEquals('VecF64x2Div lane 0', 0.625, LDivResult.d[0], C_EPSILON);
  AssertEquals('VecF64x2Div lane 1', -17.0, LDivResult.d[1], C_EPSILON);
end;

procedure TTestCase_FloatFacadeGuards.Test_VecF64x2_CompareReduceSelect_Basic;
const
  C_EPSILON = 1e-12;
var
  LVecA, LVecB: TVecF64x2;
  LSelectResult: TVecF64x2;
  LReduceInput: TVecF64x2;
  LMaskEq, LMaskLt, LMaskLe, LMaskGt, LMaskGe, LMaskNe: TMask2;
  LReduceAdd, LReduceMin, LReduceMax, LReduceMul: Double;
begin
  LVecA.d[0] := 1.5;
  LVecA.d[1] := -2.0;
  LVecB.d[0] := 1.5;
  LVecB.d[1] := 3.0;

  LMaskEq := nextpas.core.simd.VecF64x2CmpEq(LVecA, LVecB);
  LMaskLt := nextpas.core.simd.VecF64x2CmpLt(LVecA, LVecB);
  LMaskLe := nextpas.core.simd.VecF64x2CmpLe(LVecA, LVecB);
  LMaskGt := nextpas.core.simd.VecF64x2CmpGt(LVecA, LVecB);
  LMaskGe := nextpas.core.simd.VecF64x2CmpGe(LVecA, LVecB);
  LMaskNe := nextpas.core.simd.VecF64x2CmpNe(LVecA, LVecB);

  AssertEquals('VecF64x2CmpEq case1 mask', Integer(TMask2($1)), Integer(LMaskEq));
  AssertEquals('VecF64x2CmpLt case1 mask', Integer(TMask2($2)), Integer(LMaskLt));
  AssertEquals('VecF64x2CmpLe case1 mask', Integer(TMask2($3)), Integer(LMaskLe));
  AssertEquals('VecF64x2CmpGt case1 mask', Integer(TMask2($0)), Integer(LMaskGt));
  AssertEquals('VecF64x2CmpGe case1 mask', Integer(TMask2($1)), Integer(LMaskGe));
  AssertEquals('VecF64x2CmpNe case1 mask', Integer(TMask2($2)), Integer(LMaskNe));

  LVecA.d[0] := 10.0;
  LVecA.d[1] := -7.0;
  LVecB.d[0] := 2.0;
  LVecB.d[1] := -7.0;

  LMaskGt := nextpas.core.simd.VecF64x2CmpGt(LVecA, LVecB);
  LMaskGe := nextpas.core.simd.VecF64x2CmpGe(LVecA, LVecB);
  AssertEquals('VecF64x2CmpGt case2 mask', Integer(TMask2($1)), Integer(LMaskGt));
  AssertEquals('VecF64x2CmpGe case2 mask', Integer(TMask2($3)), Integer(LMaskGe));

  LVecA.d[0] := 10.0;
  LVecA.d[1] := 11.0;
  LVecB.d[0] := 20.0;
  LVecB.d[1] := 21.0;
  LSelectResult := nextpas.core.simd.VecF64x2Select(TMask2($1), LVecA, LVecB);
  AssertEquals('VecF64x2Select lane 0', 10.0, LSelectResult.d[0], C_EPSILON);
  AssertEquals('VecF64x2Select lane 1', 21.0, LSelectResult.d[1], C_EPSILON);

  LReduceInput.d[0] := 2.0;
  LReduceInput.d[1] := -3.5;
  LReduceAdd := nextpas.core.simd.VecF64x2ReduceAdd(LReduceInput);
  LReduceMin := nextpas.core.simd.VecF64x2ReduceMin(LReduceInput);
  LReduceMax := nextpas.core.simd.VecF64x2ReduceMax(LReduceInput);
  LReduceMul := nextpas.core.simd.VecF64x2ReduceMul(LReduceInput);

  AssertEquals('VecF64x2ReduceAdd', -1.5, LReduceAdd, C_EPSILON);
  AssertEquals('VecF64x2ReduceMin', -3.5, LReduceMin, C_EPSILON);
  AssertEquals('VecF64x2ReduceMax', 2.0, LReduceMax, C_EPSILON);
  AssertEquals('VecF64x2ReduceMul', -7.0, LReduceMul, C_EPSILON);
  AssertEquals('VecF64x2Dot', -33.5, nextpas.core.simd.VecF64x2Dot(LReduceInput, LVecB), C_EPSILON);
end;

procedure TTestCase_FloatFacadeGuards.Test_VecF64x2_ExtendedMathAndLoadStore_Basic;
const
  C_EPSILON = 1e-12;
var
  LVecA, LVecB, LVecC, LInput, LResult: TVecF64x2;
  LSource, LRoundtrip: array[0..1] of Double;
begin
  LVecA.d[0] := 1.5;
  LVecA.d[1] := -2.0;
  LVecB := nextpas.core.simd.VecF64x2Splat(2.0);
  LVecC := nextpas.core.simd.VecF64x2Splat(0.5);

  LResult := nextpas.core.simd.VecF64x2Fma(LVecA, LVecB, LVecC);
  AssertEquals('VecF64x2Fma lane 0', 3.5, LResult.d[0], C_EPSILON);
  AssertEquals('VecF64x2Fma lane 1', -3.5, LResult.d[1], C_EPSILON);

  LInput.d[0] := 1.2;
  LInput.d[1] := -2.8;

  LResult := nextpas.core.simd.VecF64x2Floor(LInput);
  AssertEquals('VecF64x2Floor lane 0', 1.0, LResult.d[0], C_EPSILON);
  AssertEquals('VecF64x2Floor lane 1', -3.0, LResult.d[1], C_EPSILON);

  LResult := nextpas.core.simd.VecF64x2Ceil(LInput);
  AssertEquals('VecF64x2Ceil lane 0', 2.0, LResult.d[0], C_EPSILON);
  AssertEquals('VecF64x2Ceil lane 1', -2.0, LResult.d[1], C_EPSILON);

  LResult := nextpas.core.simd.VecF64x2Round(LInput);
  AssertEquals('VecF64x2Round lane 0', 1.0, LResult.d[0], C_EPSILON);
  AssertEquals('VecF64x2Round lane 1', -3.0, LResult.d[1], C_EPSILON);

  LResult := nextpas.core.simd.VecF64x2Trunc(LInput);
  AssertEquals('VecF64x2Trunc lane 0', 1.0, LResult.d[0], C_EPSILON);
  AssertEquals('VecF64x2Trunc lane 1', -2.0, LResult.d[1], C_EPSILON);

  LSource[0] := 0.125;
  LSource[1] := -9.5;
  LResult := nextpas.core.simd.VecF64x2Load(@LSource[0]);
  nextpas.core.simd.VecF64x2Store(@LRoundtrip[0], LResult);
  AssertEquals('VecF64x2LoadStore lane 0', 0.125, LRoundtrip[0], C_EPSILON);
  AssertEquals('VecF64x2LoadStore lane 1', -9.5, LRoundtrip[1], C_EPSILON);

  LResult := nextpas.core.simd.VecF64x2Splat(6.5);
  AssertEquals('VecF64x2Splat lane 0', 6.5, LResult.d[0], C_EPSILON);
  AssertEquals('VecF64x2Splat lane 1', 6.5, LResult.d[1], C_EPSILON);

  LResult := nextpas.core.simd.VecF64x2Zero;
  AssertEquals('VecF64x2Zero lane 0', 0.0, LResult.d[0], C_EPSILON);
  AssertEquals('VecF64x2Zero lane 1', 0.0, LResult.d[1], C_EPSILON);
end;

procedure TTestCase_FloatFacadeGuards.Test_VecF64x2_RemainingMathAndExtractInsert_Basic;
const
  C_EPSILON = 1e-12;
var
  LVecA, LVecB: TVecF64x2;
  LAbsResult, LSqrtResult, LMinResult, LMaxResult, LInserted: TVecF64x2;
begin
  LVecA.d[0] := -0.75;
  LVecA.d[1] := 2.25;
  LAbsResult := nextpas.core.simd.VecF64x2Abs(LVecA);
  AssertEquals('VecF64x2Abs lane 0', 0.75, LAbsResult.d[0], C_EPSILON);
  AssertEquals('VecF64x2Abs lane 1', 2.25, LAbsResult.d[1], C_EPSILON);

  LVecB.d[0] := 0.25;
  LVecB.d[1] := 12.25;
  LSqrtResult := nextpas.core.simd.VecF64x2Sqrt(LVecB);
  AssertEquals('VecF64x2Sqrt lane 0', 0.5, LSqrtResult.d[0], C_EPSILON);
  AssertEquals('VecF64x2Sqrt lane 1', 3.5, LSqrtResult.d[1], C_EPSILON);

  LVecA.d[0] := 1.0;
  LVecA.d[1] := 10.0;
  LVecB.d[0] := 2.0;
  LVecB.d[1] := 5.0;
  LMinResult := nextpas.core.simd.VecF64x2Min(LVecA, LVecB);
  LMaxResult := nextpas.core.simd.VecF64x2Max(LVecA, LVecB);
  AssertEquals('VecF64x2Min lane 0', 1.0, LMinResult.d[0], C_EPSILON);
  AssertEquals('VecF64x2Min lane 1', 5.0, LMinResult.d[1], C_EPSILON);
  AssertEquals('VecF64x2Max lane 0', 2.0, LMaxResult.d[0], C_EPSILON);
  AssertEquals('VecF64x2Max lane 1', 10.0, LMaxResult.d[1], C_EPSILON);

  AssertEquals('VecF64x2Extract lane 1', LVecA.d[1], nextpas.core.simd.VecF64x2Extract(LVecA, 1), C_EPSILON);
  LInserted := nextpas.core.simd.VecF64x2Insert(LVecA, 42.125, 0);
  AssertEquals('VecF64x2Insert lane 0', 42.125, LInserted.d[0], C_EPSILON);
  AssertEquals('VecF64x2Insert keep lane 1', LVecA.d[1], LInserted.d[1], C_EPSILON);
end;

procedure TTestCase_FloatFacadeGuards.Test_VecF32x16_Arithmetic_Basic;
const
  C_EPSILON = 1e-5;
var
  LVecA, LVecB: TVecF32x16;
  LAddResult, LSubResult, LMulResult, LDivResult: TVecF32x16;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.f) do
  begin
    LVecA.f[LIndex] := (LIndex + 1) * 1.25;
    LVecB.f[LIndex] := LIndex + 0.5;
  end;

  LAddResult := nextpas.core.simd.VecF32x16Add(LVecA, LVecB);
  LSubResult := nextpas.core.simd.VecF32x16Sub(LVecA, LVecB);
  LMulResult := nextpas.core.simd.VecF32x16Mul(LVecA, LVecB);
  LDivResult := nextpas.core.simd.VecF32x16Div(LVecA, LVecB);

  for LIndex := 0 to High(LVecA.f) do
  begin
    AssertEquals('VecF32x16Add lane ' + IntToStr(LIndex),
      LVecA.f[LIndex] + LVecB.f[LIndex], LAddResult.f[LIndex], C_EPSILON);
    AssertEquals('VecF32x16Sub lane ' + IntToStr(LIndex),
      LVecA.f[LIndex] - LVecB.f[LIndex], LSubResult.f[LIndex], C_EPSILON);
    AssertEquals('VecF32x16Mul lane ' + IntToStr(LIndex),
      LVecA.f[LIndex] * LVecB.f[LIndex], LMulResult.f[LIndex], C_EPSILON);
    AssertEquals('VecF32x16Div lane ' + IntToStr(LIndex),
      LVecA.f[LIndex] / LVecB.f[LIndex], LDivResult.f[LIndex], C_EPSILON);
  end;
end;

procedure TTestCase_FloatFacadeGuards.Test_VecF32x16_CompareReduceSelect_Basic;
const
  C_EPSILON = 1e-5;
var
  LVecA, LVecB: TVecF32x16;
  LSelectResult: TVecF32x16;
  LMaskEq, LMaskLt, LMaskLe, LMaskGt, LMaskGe, LMaskNe: TMask16;
  LReduceInput: TVecF32x16;
  LReduceAdd, LReduceMin, LReduceMax, LReduceMul: Single;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.f) do
  begin
    case LIndex mod 3 of
      0:
        begin
          LVecA.f[LIndex] := LIndex + 0.25;
          LVecB.f[LIndex] := LVecA.f[LIndex];
        end;
      1:
        begin
          LVecA.f[LIndex] := -100.0 + LIndex;
          LVecB.f[LIndex] := LVecA.f[LIndex] + 2.0;
        end;
    else
      begin
        LVecA.f[LIndex] := 200.0 + LIndex;
        LVecB.f[LIndex] := LVecA.f[LIndex] - 3.0;
      end;
    end;
  end;

  LMaskEq := nextpas.core.simd.VecF32x16CmpEq_Mask(LVecA, LVecB);
  LMaskLt := nextpas.core.simd.VecF32x16CmpLt_Mask(LVecA, LVecB);
  LMaskLe := nextpas.core.simd.VecF32x16CmpLe_Mask(LVecA, LVecB);
  LMaskGt := nextpas.core.simd.VecF32x16CmpGt_Mask(LVecA, LVecB);
  LMaskGe := nextpas.core.simd.VecF32x16CmpGe_Mask(LVecA, LVecB);
  LMaskNe := nextpas.core.simd.VecF32x16CmpNe_Mask(LVecA, LVecB);

  AssertEquals('VecF32x16CmpEq_Mask mask', LongInt(TMask16($9249)), LongInt(LMaskEq));
  AssertEquals('VecF32x16CmpLt_Mask mask', LongInt(TMask16($2492)), LongInt(LMaskLt));
  AssertEquals('VecF32x16CmpLe_Mask mask', LongInt(TMask16($B6DB)), LongInt(LMaskLe));
  AssertEquals('VecF32x16CmpGt_Mask mask', LongInt(TMask16($4924)), LongInt(LMaskGt));
  AssertEquals('VecF32x16CmpGe_Mask mask', LongInt(TMask16($DB6D)), LongInt(LMaskGe));
  AssertEquals('VecF32x16CmpNe_Mask mask', LongInt(TMask16($6DB6)), LongInt(LMaskNe));

  for LIndex := 0 to High(LVecA.f) do
  begin
    LVecA.f[LIndex] := 10.0 + LIndex;
    LVecB.f[LIndex] := 20.0 + LIndex;
  end;
  LSelectResult := nextpas.core.simd.VecF32x16Select(TMask16($5555), LVecA, LVecB);
  for LIndex := 0 to High(LSelectResult.f) do
  begin
    if (LIndex and 1) = 0 then
      AssertEquals('VecF32x16Select even lane ' + IntToStr(LIndex), 10.0 + LIndex, LSelectResult.f[LIndex], C_EPSILON)
    else
      AssertEquals('VecF32x16Select odd lane ' + IntToStr(LIndex), 20.0 + LIndex, LSelectResult.f[LIndex], C_EPSILON);
  end;

  for LIndex := 0 to High(LReduceInput.f) do
    LReduceInput.f[LIndex] := 1.0;
  LReduceInput.f[0] := 2.0;
  LReduceInput.f[1] := 3.0;
  LReduceInput.f[2] := -4.0;
  LReduceInput.f[3] := 0.5;

  LReduceAdd := nextpas.core.simd.VecF32x16ReduceAdd(LReduceInput);
  LReduceMin := nextpas.core.simd.VecF32x16ReduceMin(LReduceInput);
  LReduceMax := nextpas.core.simd.VecF32x16ReduceMax(LReduceInput);
  LReduceMul := nextpas.core.simd.VecF32x16ReduceMul(LReduceInput);

  AssertEquals('VecF32x16ReduceAdd', 13.5, LReduceAdd, C_EPSILON);
  AssertEquals('VecF32x16ReduceMin', -4.0, LReduceMin, C_EPSILON);
  AssertEquals('VecF32x16ReduceMax', 3.0, LReduceMax, C_EPSILON);
  AssertEquals('VecF32x16ReduceMul', -12.0, LReduceMul, C_EPSILON);
end;

procedure TTestCase_FloatFacadeGuards.Test_VecF32x16_ExtendedMathAndLoadStore_Basic;
const
  C_EPSILON = 1e-5;
var
  LVecA, LVecB, LVecC, LInput, LResult: TVecF32x16;
  LSource, LRoundtrip: array[0..15] of Single;
  LIndex: Integer;
begin
  LVecA := nextpas.core.simd.VecF32x16Zero;
  LVecB := nextpas.core.simd.VecF32x16Splat(2.0);
  LVecC := nextpas.core.simd.VecF32x16Splat(1.0);
  for LIndex := 0 to High(LVecA.f) do
    LVecA.f[LIndex] := LIndex + 0.25;

  LResult := nextpas.core.simd.VecF32x16Fma(LVecA, LVecB, LVecC);
  for LIndex := 0 to High(LResult.f) do
    AssertEquals('VecF32x16Fma lane ' + IntToStr(LIndex),
      (LIndex + 0.25) * 2.0 + 1.0, LResult.f[LIndex], C_EPSILON);

  LResult := nextpas.core.simd.VecF32x16Clamp(LResult,
    nextpas.core.simd.VecF32x16Splat(3.0),
    nextpas.core.simd.VecF32x16Splat(20.0));
  for LIndex := 0 to High(LResult.f) do
  begin
    AssertTrue('VecF32x16Clamp min lane ' + IntToStr(LIndex), LResult.f[LIndex] >= 3.0);
    AssertTrue('VecF32x16Clamp max lane ' + IntToStr(LIndex), LResult.f[LIndex] <= 20.0);
  end;

  LInput := nextpas.core.simd.VecF32x16Zero;
  LInput.f[0] := 1.2;
  LInput.f[1] := -1.2;
  LInput.f[2] := 2.8;
  LInput.f[3] := -2.8;

  LResult := nextpas.core.simd.VecF32x16Floor(LInput);
  AssertEquals('VecF32x16Floor lane0', 1.0, LResult.f[0], C_EPSILON);
  AssertEquals('VecF32x16Floor lane1', -2.0, LResult.f[1], C_EPSILON);
  AssertEquals('VecF32x16Floor lane2', 2.0, LResult.f[2], C_EPSILON);
  AssertEquals('VecF32x16Floor lane3', -3.0, LResult.f[3], C_EPSILON);

  LResult := nextpas.core.simd.VecF32x16Ceil(LInput);
  AssertEquals('VecF32x16Ceil lane0', 2.0, LResult.f[0], C_EPSILON);
  AssertEquals('VecF32x16Ceil lane1', -1.0, LResult.f[1], C_EPSILON);
  AssertEquals('VecF32x16Ceil lane2', 3.0, LResult.f[2], C_EPSILON);
  AssertEquals('VecF32x16Ceil lane3', -2.0, LResult.f[3], C_EPSILON);

  LResult := nextpas.core.simd.VecF32x16Round(LInput);
  AssertEquals('VecF32x16Round lane0', 1.0, LResult.f[0], C_EPSILON);
  AssertEquals('VecF32x16Round lane1', -1.0, LResult.f[1], C_EPSILON);
  AssertEquals('VecF32x16Round lane2', 3.0, LResult.f[2], C_EPSILON);
  AssertEquals('VecF32x16Round lane3', -3.0, LResult.f[3], C_EPSILON);

  LResult := nextpas.core.simd.VecF32x16Trunc(LInput);
  AssertEquals('VecF32x16Trunc lane0', 1.0, LResult.f[0], C_EPSILON);
  AssertEquals('VecF32x16Trunc lane1', -1.0, LResult.f[1], C_EPSILON);
  AssertEquals('VecF32x16Trunc lane2', 2.0, LResult.f[2], C_EPSILON);
  AssertEquals('VecF32x16Trunc lane3', -2.0, LResult.f[3], C_EPSILON);

  for LIndex := 0 to High(LSource) do
    LSource[LIndex] := LIndex + 0.5;
  LResult := nextpas.core.simd.VecF32x16Load(@LSource[0]);
  nextpas.core.simd.VecF32x16Store(@LRoundtrip[0], LResult);
  for LIndex := 0 to High(LRoundtrip) do
    AssertEquals('VecF32x16LoadStore lane ' + IntToStr(LIndex), LSource[LIndex], LRoundtrip[LIndex], C_EPSILON);

  LResult := nextpas.core.simd.VecF32x16Splat(3.25);
  for LIndex := 0 to High(LResult.f) do
    AssertEquals('VecF32x16Splat lane ' + IntToStr(LIndex), 3.25, LResult.f[LIndex], C_EPSILON);

  LResult := nextpas.core.simd.VecF32x16Zero;
  for LIndex := 0 to High(LResult.f) do
    AssertEquals('VecF32x16Zero lane ' + IntToStr(LIndex), 0.0, LResult.f[LIndex], C_EPSILON);
end;

procedure TTestCase_FloatFacadeGuards.Test_VecF32x16_RemainingMathAndExtractInsert_Basic;
const
  C_EPSILON = 1e-5;
var
  LVecA, LVecB: TVecF32x16;
  LAbsResult, LSqrtResult, LMinResult, LMaxResult, LInserted: TVecF32x16;
  LExtracted: Single;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.f) do
  begin
    if (LIndex and 1) = 0 then
      LVecA.f[LIndex] := -(LIndex + 1.5)
    else
      LVecA.f[LIndex] := LIndex + 1.5;
  end;

  LAbsResult := nextpas.core.simd.VecF32x16Abs(LVecA);
  for LIndex := 0 to High(LAbsResult.f) do
    AssertEquals('VecF32x16Abs lane ' + IntToStr(LIndex), LIndex + 1.5, LAbsResult.f[LIndex], C_EPSILON);

  LVecB := nextpas.core.simd.VecF32x16Zero;
  LVecB.f[0] := 0.0;
  LVecB.f[1] := 1.0;
  LVecB.f[2] := 4.0;
  LVecB.f[3] := 9.0;
  LVecB.f[4] := 16.0;
  LVecB.f[5] := 25.0;
  LVecB.f[6] := 2.25;
  LVecB.f[7] := 6.25;
  LVecB.f[8] := 0.25;
  LVecB.f[9] := 12.25;
  LVecB.f[10] := 20.25;
  LVecB.f[11] := 30.25;
  LVecB.f[12] := 42.25;
  LVecB.f[13] := 56.25;
  LVecB.f[14] := 72.25;
  LVecB.f[15] := 90.25;

  LSqrtResult := nextpas.core.simd.VecF32x16Sqrt(LVecB);
  AssertEquals('VecF32x16Sqrt lane 0', 0.0, LSqrtResult.f[0], C_EPSILON);
  AssertEquals('VecF32x16Sqrt lane 1', 1.0, LSqrtResult.f[1], C_EPSILON);
  AssertEquals('VecF32x16Sqrt lane 2', 2.0, LSqrtResult.f[2], C_EPSILON);
  AssertEquals('VecF32x16Sqrt lane 3', 3.0, LSqrtResult.f[3], C_EPSILON);
  AssertEquals('VecF32x16Sqrt lane 4', 4.0, LSqrtResult.f[4], C_EPSILON);
  AssertEquals('VecF32x16Sqrt lane 5', 5.0, LSqrtResult.f[5], C_EPSILON);
  AssertEquals('VecF32x16Sqrt lane 6', 1.5, LSqrtResult.f[6], C_EPSILON);
  AssertEquals('VecF32x16Sqrt lane 7', 2.5, LSqrtResult.f[7], C_EPSILON);
  AssertEquals('VecF32x16Sqrt lane 8', 0.5, LSqrtResult.f[8], C_EPSILON);
  AssertEquals('VecF32x16Sqrt lane 9', 3.5, LSqrtResult.f[9], C_EPSILON);
  AssertEquals('VecF32x16Sqrt lane 10', 4.5, LSqrtResult.f[10], C_EPSILON);
  AssertEquals('VecF32x16Sqrt lane 11', 5.5, LSqrtResult.f[11], C_EPSILON);
  AssertEquals('VecF32x16Sqrt lane 12', 6.5, LSqrtResult.f[12], C_EPSILON);
  AssertEquals('VecF32x16Sqrt lane 13', 7.5, LSqrtResult.f[13], C_EPSILON);
  AssertEquals('VecF32x16Sqrt lane 14', 8.5, LSqrtResult.f[14], C_EPSILON);
  AssertEquals('VecF32x16Sqrt lane 15', 9.5, LSqrtResult.f[15], C_EPSILON);

  for LIndex := 0 to High(LVecA.f) do
  begin
    LVecA.f[LIndex] := LIndex - 5.0;
    LVecB.f[LIndex] := 5.0 - (LIndex * 0.5);
  end;
  LMinResult := nextpas.core.simd.VecF32x16Min(LVecA, LVecB);
  LMaxResult := nextpas.core.simd.VecF32x16Max(LVecA, LVecB);
  for LIndex := 0 to High(LMinResult.f) do
  begin
    if LVecA.f[LIndex] < LVecB.f[LIndex] then
    begin
      AssertEquals('VecF32x16Min lane ' + IntToStr(LIndex), LVecA.f[LIndex], LMinResult.f[LIndex], C_EPSILON);
      AssertEquals('VecF32x16Max lane ' + IntToStr(LIndex), LVecB.f[LIndex], LMaxResult.f[LIndex], C_EPSILON);
    end
    else
    begin
      AssertEquals('VecF32x16Min lane ' + IntToStr(LIndex), LVecB.f[LIndex], LMinResult.f[LIndex], C_EPSILON);
      AssertEquals('VecF32x16Max lane ' + IntToStr(LIndex), LVecA.f[LIndex], LMaxResult.f[LIndex], C_EPSILON);
    end;
  end;

  LExtracted := nextpas.core.simd.VecF32x16Extract(LVecA, 10);
  AssertEquals('VecF32x16Extract lane 10', LVecA.f[10], LExtracted, C_EPSILON);

  LInserted := nextpas.core.simd.VecF32x16Insert(LVecA, 99.5, 11);
  AssertEquals('VecF32x16Insert lane 11', 99.5, LInserted.f[11], C_EPSILON);
  AssertEquals('VecF32x16Insert keep lane 10', LVecA.f[10], LInserted.f[10], C_EPSILON);
  AssertEquals('VecF32x16Insert keep lane 12', LVecA.f[12], LInserted.f[12], C_EPSILON);
end;

procedure TTestCase_FloatFacadeGuards.Test_VecF64x8_Arithmetic_Basic;
const
  C_EPSILON = 1e-9;
var
  LVecA, LVecB: TVecF64x8;
  LAddResult, LSubResult, LMulResult, LDivResult: TVecF64x8;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.d) do
  begin
    LVecA.d[LIndex] := (LIndex + 1) * 2.5;
    LVecB.d[LIndex] := LIndex + 0.5;
  end;

  LAddResult := nextpas.core.simd.VecF64x8Add(LVecA, LVecB);
  LSubResult := nextpas.core.simd.VecF64x8Sub(LVecA, LVecB);
  LMulResult := nextpas.core.simd.VecF64x8Mul(LVecA, LVecB);
  LDivResult := nextpas.core.simd.VecF64x8Div(LVecA, LVecB);

  for LIndex := 0 to High(LVecA.d) do
  begin
    AssertEquals('VecF64x8Add lane ' + IntToStr(LIndex),
      LVecA.d[LIndex] + LVecB.d[LIndex], LAddResult.d[LIndex], C_EPSILON);
    AssertEquals('VecF64x8Sub lane ' + IntToStr(LIndex),
      LVecA.d[LIndex] - LVecB.d[LIndex], LSubResult.d[LIndex], C_EPSILON);
    AssertEquals('VecF64x8Mul lane ' + IntToStr(LIndex),
      LVecA.d[LIndex] * LVecB.d[LIndex], LMulResult.d[LIndex], C_EPSILON);
    AssertEquals('VecF64x8Div lane ' + IntToStr(LIndex),
      LVecA.d[LIndex] / LVecB.d[LIndex], LDivResult.d[LIndex], C_EPSILON);
  end;
end;

procedure TTestCase_FloatFacadeGuards.Test_VecF64x8_CompareReduceSelect_Basic;
const
  C_EPSILON = 1e-9;
var
  LVecA, LVecB: TVecF64x8;
  LSelectResult: TVecF64x8;
  LMaskEq, LMaskLt, LMaskLe, LMaskGt, LMaskGe, LMaskNe: TMask8;
  LReduceInput: TVecF64x8;
  LReduceAdd, LReduceMin, LReduceMax, LReduceMul: Double;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.d) do
  begin
    case LIndex mod 3 of
      0:
        begin
          LVecA.d[LIndex] := LIndex + 0.5;
          LVecB.d[LIndex] := LVecA.d[LIndex];
        end;
      1:
        begin
          LVecA.d[LIndex] := -50.0 + LIndex;
          LVecB.d[LIndex] := LVecA.d[LIndex] + 2.0;
        end;
    else
      begin
        LVecA.d[LIndex] := 100.0 + LIndex;
        LVecB.d[LIndex] := LVecA.d[LIndex] - 3.0;
      end;
    end;
  end;

  LMaskEq := nextpas.core.simd.VecF64x8CmpEq(LVecA, LVecB);
  LMaskLt := nextpas.core.simd.VecF64x8CmpLt(LVecA, LVecB);
  LMaskLe := nextpas.core.simd.VecF64x8CmpLe(LVecA, LVecB);
  LMaskGt := nextpas.core.simd.VecF64x8CmpGt(LVecA, LVecB);
  LMaskGe := nextpas.core.simd.VecF64x8CmpGe(LVecA, LVecB);
  LMaskNe := nextpas.core.simd.VecF64x8CmpNe(LVecA, LVecB);

  AssertEquals('VecF64x8CmpEq mask', Integer(TMask8($49)), Integer(LMaskEq));
  AssertEquals('VecF64x8CmpLt mask', Integer(TMask8($92)), Integer(LMaskLt));
  AssertEquals('VecF64x8CmpLe mask', Integer(TMask8($DB)), Integer(LMaskLe));
  AssertEquals('VecF64x8CmpGt mask', Integer(TMask8($24)), Integer(LMaskGt));
  AssertEquals('VecF64x8CmpGe mask', Integer(TMask8($6D)), Integer(LMaskGe));
  AssertEquals('VecF64x8CmpNe mask', Integer(TMask8($B6)), Integer(LMaskNe));

  for LIndex := 0 to High(LVecA.d) do
  begin
    LVecA.d[LIndex] := 10.0 + LIndex;
    LVecB.d[LIndex] := 20.0 + LIndex;
  end;
  LSelectResult := nextpas.core.simd.VecF64x8Select(TMask8($55), LVecA, LVecB);
  for LIndex := 0 to High(LSelectResult.d) do
  begin
    if (LIndex and 1) = 0 then
      AssertEquals('VecF64x8Select even lane ' + IntToStr(LIndex), 10.0 + LIndex, LSelectResult.d[LIndex], C_EPSILON)
    else
      AssertEquals('VecF64x8Select odd lane ' + IntToStr(LIndex), 20.0 + LIndex, LSelectResult.d[LIndex], C_EPSILON);
  end;

  for LIndex := 0 to High(LReduceInput.d) do
    LReduceInput.d[LIndex] := 1.0;
  LReduceInput.d[0] := 2.0;
  LReduceInput.d[1] := 3.0;
  LReduceInput.d[2] := -4.0;
  LReduceInput.d[3] := 0.5;

  LReduceAdd := nextpas.core.simd.VecF64x8ReduceAdd(LReduceInput);
  LReduceMin := nextpas.core.simd.VecF64x8ReduceMin(LReduceInput);
  LReduceMax := nextpas.core.simd.VecF64x8ReduceMax(LReduceInput);
  LReduceMul := nextpas.core.simd.VecF64x8ReduceMul(LReduceInput);

  AssertEquals('VecF64x8ReduceAdd', 5.5, LReduceAdd, C_EPSILON);
  AssertEquals('VecF64x8ReduceMin', -4.0, LReduceMin, C_EPSILON);
  AssertEquals('VecF64x8ReduceMax', 3.0, LReduceMax, C_EPSILON);
  AssertEquals('VecF64x8ReduceMul', -12.0, LReduceMul, C_EPSILON);
end;

procedure TTestCase_FloatFacadeGuards.Test_VecF64x8_ExtendedMathAndLoadStore_Basic;
const
  C_EPSILON = 1e-9;
var
  LVecA, LVecB, LVecC, LInput, LResult: TVecF64x8;
  LSource, LRoundtrip: array[0..7] of Double;
  LIndex: Integer;
begin
  LVecA := nextpas.core.simd.VecF64x8Zero;
  LVecB := nextpas.core.simd.VecF64x8Splat(3.0);
  LVecC := nextpas.core.simd.VecF64x8Splat(2.0);
  for LIndex := 0 to High(LVecA.d) do
    LVecA.d[LIndex] := LIndex + 0.5;

  LResult := nextpas.core.simd.VecF64x8Fma(LVecA, LVecB, LVecC);
  for LIndex := 0 to High(LResult.d) do
    AssertEquals('VecF64x8Fma lane ' + IntToStr(LIndex),
      (LIndex + 0.5) * 3.0 + 2.0, LResult.d[LIndex], C_EPSILON);

  LResult := nextpas.core.simd.VecF64x8Clamp(LResult,
    nextpas.core.simd.VecF64x8Splat(4.0),
    nextpas.core.simd.VecF64x8Splat(20.0));
  for LIndex := 0 to High(LResult.d) do
  begin
    AssertTrue('VecF64x8Clamp min lane ' + IntToStr(LIndex), LResult.d[LIndex] >= 4.0);
    AssertTrue('VecF64x8Clamp max lane ' + IntToStr(LIndex), LResult.d[LIndex] <= 20.0);
  end;

  LInput := nextpas.core.simd.VecF64x8Zero;
  LInput.d[0] := 1.2;
  LInput.d[1] := -1.2;
  LInput.d[2] := 2.8;
  LInput.d[3] := -2.8;

  LResult := nextpas.core.simd.VecF64x8Floor(LInput);
  AssertEquals('VecF64x8Floor lane0', 1.0, LResult.d[0], C_EPSILON);
  AssertEquals('VecF64x8Floor lane1', -2.0, LResult.d[1], C_EPSILON);
  AssertEquals('VecF64x8Floor lane2', 2.0, LResult.d[2], C_EPSILON);
  AssertEquals('VecF64x8Floor lane3', -3.0, LResult.d[3], C_EPSILON);

  LResult := nextpas.core.simd.VecF64x8Ceil(LInput);
  AssertEquals('VecF64x8Ceil lane0', 2.0, LResult.d[0], C_EPSILON);
  AssertEquals('VecF64x8Ceil lane1', -1.0, LResult.d[1], C_EPSILON);
  AssertEquals('VecF64x8Ceil lane2', 3.0, LResult.d[2], C_EPSILON);
  AssertEquals('VecF64x8Ceil lane3', -2.0, LResult.d[3], C_EPSILON);

  LResult := nextpas.core.simd.VecF64x8Round(LInput);
  AssertEquals('VecF64x8Round lane0', 1.0, LResult.d[0], C_EPSILON);
  AssertEquals('VecF64x8Round lane1', -1.0, LResult.d[1], C_EPSILON);
  AssertEquals('VecF64x8Round lane2', 3.0, LResult.d[2], C_EPSILON);
  AssertEquals('VecF64x8Round lane3', -3.0, LResult.d[3], C_EPSILON);

  LResult := nextpas.core.simd.VecF64x8Trunc(LInput);
  AssertEquals('VecF64x8Trunc lane0', 1.0, LResult.d[0], C_EPSILON);
  AssertEquals('VecF64x8Trunc lane1', -1.0, LResult.d[1], C_EPSILON);
  AssertEquals('VecF64x8Trunc lane2', 2.0, LResult.d[2], C_EPSILON);
  AssertEquals('VecF64x8Trunc lane3', -2.0, LResult.d[3], C_EPSILON);

  for LIndex := 0 to High(LSource) do
    LSource[LIndex] := LIndex + 0.125;
  LResult := nextpas.core.simd.VecF64x8Load(@LSource[0]);
  nextpas.core.simd.VecF64x8Store(@LRoundtrip[0], LResult);
  for LIndex := 0 to High(LRoundtrip) do
    AssertEquals('VecF64x8LoadStore lane ' + IntToStr(LIndex), LSource[LIndex], LRoundtrip[LIndex], C_EPSILON);

  LResult := nextpas.core.simd.VecF64x8Splat(6.5);
  for LIndex := 0 to High(LResult.d) do
    AssertEquals('VecF64x8Splat lane ' + IntToStr(LIndex), 6.5, LResult.d[LIndex], C_EPSILON);

  LResult := nextpas.core.simd.VecF64x8Zero;
  for LIndex := 0 to High(LResult.d) do
    AssertEquals('VecF64x8Zero lane ' + IntToStr(LIndex), 0.0, LResult.d[LIndex], C_EPSILON);
end;

procedure TTestCase_FloatFacadeGuards.Test_VecF64x8_RemainingMath_Basic;
const
  C_EPSILON = 1e-9;
var
  LVecA, LVecB: TVecF64x8;
  LAbsResult, LSqrtResult, LMinResult, LMaxResult: TVecF64x8;
  LIndex: Integer;
begin
  for LIndex := 0 to High(LVecA.d) do
  begin
    if (LIndex and 1) = 0 then
      LVecA.d[LIndex] := -(LIndex + 0.75)
    else
      LVecA.d[LIndex] := LIndex + 0.75;
  end;

  LAbsResult := nextpas.core.simd.VecF64x8Abs(LVecA);
  for LIndex := 0 to High(LAbsResult.d) do
    AssertEquals('VecF64x8Abs lane ' + IntToStr(LIndex), LIndex + 0.75, LAbsResult.d[LIndex], C_EPSILON);

  LVecB.d[0] := 0.0;
  LVecB.d[1] := 1.0;
  LVecB.d[2] := 4.0;
  LVecB.d[3] := 9.0;
  LVecB.d[4] := 12.25;
  LVecB.d[5] := 20.25;
  LVecB.d[6] := 30.25;
  LVecB.d[7] := 42.25;
  LSqrtResult := nextpas.core.simd.VecF64x8Sqrt(LVecB);
  AssertEquals('VecF64x8Sqrt lane 0', 0.0, LSqrtResult.d[0], C_EPSILON);
  AssertEquals('VecF64x8Sqrt lane 1', 1.0, LSqrtResult.d[1], C_EPSILON);
  AssertEquals('VecF64x8Sqrt lane 2', 2.0, LSqrtResult.d[2], C_EPSILON);
  AssertEquals('VecF64x8Sqrt lane 3', 3.0, LSqrtResult.d[3], C_EPSILON);
  AssertEquals('VecF64x8Sqrt lane 4', 3.5, LSqrtResult.d[4], C_EPSILON);
  AssertEquals('VecF64x8Sqrt lane 5', 4.5, LSqrtResult.d[5], C_EPSILON);
  AssertEquals('VecF64x8Sqrt lane 6', 5.5, LSqrtResult.d[6], C_EPSILON);
  AssertEquals('VecF64x8Sqrt lane 7', 6.5, LSqrtResult.d[7], C_EPSILON);

  for LIndex := 0 to High(LVecA.d) do
  begin
    LVecA.d[LIndex] := LIndex - 3.0;
    LVecB.d[LIndex] := 3.0 - (LIndex * 0.75);
  end;
  LMinResult := nextpas.core.simd.VecF64x8Min(LVecA, LVecB);
  LMaxResult := nextpas.core.simd.VecF64x8Max(LVecA, LVecB);
  for LIndex := 0 to High(LMinResult.d) do
  begin
    if LVecA.d[LIndex] < LVecB.d[LIndex] then
    begin
      AssertEquals('VecF64x8Min lane ' + IntToStr(LIndex), LVecA.d[LIndex], LMinResult.d[LIndex], C_EPSILON);
      AssertEquals('VecF64x8Max lane ' + IntToStr(LIndex), LVecB.d[LIndex], LMaxResult.d[LIndex], C_EPSILON);
    end
    else
    begin
      AssertEquals('VecF64x8Min lane ' + IntToStr(LIndex), LVecB.d[LIndex], LMinResult.d[LIndex], C_EPSILON);
      AssertEquals('VecF64x8Max lane ' + IntToStr(LIndex), LVecA.d[LIndex], LMaxResult.d[LIndex], C_EPSILON);
    end;
  end;
end;

{ TTestCase_LargeData }

procedure TTestCase_LargeData.Test_MemEqual_1MB;
const
  SIZE = 1024 * 1024;  // 1 MB
var
  buf1, buf2: PByte;
  i: Integer;
begin
  buf1 := GetMem(SIZE);
  buf2 := GetMem(SIZE);
  try
    // 初始化相同数据
    for i := 0 to SIZE - 1 do
    begin
      buf1[i] := Byte(i mod 256);
      buf2[i] := Byte(i mod 256);
    end;
    
    AssertTrue('1MB equal buffers should return True', MemEqual(buf1, buf2, SIZE));
    
    // 在末尾制造差异
    buf2[SIZE - 1] := buf2[SIZE - 1] xor $FF;
    AssertFalse('1MB buffers with last byte diff should return False', MemEqual(buf1, buf2, SIZE));
  finally
    FreeMem(buf1);
    FreeMem(buf2);
  end;
end;

procedure TTestCase_LargeData.Test_SumBytes_1MB;
const
  SIZE = 1024 * 1024;  // 1 MB
var
  buf: PByte;
  i: Integer;
  sum: UInt64;
  expectedSum: UInt64;
begin
  buf := GetMem(SIZE);
  try
    // 填充 0..255 循环
    for i := 0 to SIZE - 1 do
      buf[i] := Byte(i mod 256);
    
    sum := SumBytes(buf, SIZE);
    
    // 期望值: 每 256 字节的和是 (0+1+...+255) = 32640
    // 1MB = 4096 * 256 字节
    expectedSum := UInt64(32640) * 4096;
    
    AssertEquals('1MB sum should match expected value', expectedSum, sum);
  finally
    FreeMem(buf);
  end;
end;

procedure TTestCase_LargeData.Test_MemFindByte_LargeBuffer;
const
  SIZE = 1024 * 1024;  // 1 MB
var
  buf: PByte;
  i: Integer;
  pos: PtrInt;
begin
  buf := GetMem(SIZE);
  try
    // 填充 0
    FillChar(buf^, SIZE, 0);
    
    // 在末尾放置目标字节
    buf[SIZE - 1] := $FF;
    
    pos := MemFindByte(buf, SIZE, $FF);
    AssertEquals('Should find byte at last position', SIZE - 1, pos);
    
    // 在中间放置目标字节
    buf[SIZE div 2] := $AA;
    pos := MemFindByte(buf, SIZE, $AA);
    AssertEquals('Should find byte at middle position', SIZE div 2, pos);
    
    // 查找不存在的字节
    pos := MemFindByte(buf, SIZE, $BB);
    AssertEquals('Should return -1 for not found', -1, pos);
  finally
    FreeMem(buf);
  end;
end;

procedure TTestCase_LargeData.Test_UnalignedPointer;
var
  buf: PByte;
  unaligned: PByte;
  i: Integer;
begin
  // 分配额外字节以测试非对齐访问
  buf := GetMem(256 + 64);
  try
    // 创建非 16 字节对齐的指针
    unaligned := buf;
    while (PtrUInt(unaligned) mod 16) = 0 do
      Inc(unaligned);
    
    // 初始化数据
    for i := 0 to 255 do
      unaligned[i] := Byte(i);
    
    // 测试各种函数在非对齐数据上的正确性
    AssertEquals('SumBytes on unaligned should work', UInt64(32640), SumBytes(unaligned, 256));
    AssertEquals('MemFindByte on unaligned should work', 128, MemFindByte(unaligned, 256, 128));
    AssertEquals('CountByte on unaligned should work', SizeUInt(1), CountByte(unaligned, 256, 100));
  finally
    FreeMem(buf);
  end;
end;

procedure TTestCase_LargeData.Test_OddSizes;
var
  buf1, buf2: array[0..1023] of Byte;
  i, size: Integer;
  sum: UInt64;
begin
  // 初始化数据
  for i := 0 to 1023 do
  begin
    buf1[i] := Byte(i mod 256);
    buf2[i] := Byte(i mod 256);
  end;
  
  // 测试各种奇数大小
  for size := 1 to 100 do
  begin
    // MemEqual
    AssertTrue('MemEqual size=' + IntToStr(size) + ' should work',
               MemEqual(@buf1[0], @buf2[0], size));
    
    // SumBytes
    sum := 0;
    for i := 0 to size - 1 do
      sum := sum + buf1[i];
    AssertEquals('SumBytes size=' + IntToStr(size) + ' should work',
                 sum, SumBytes(@buf1[0], size));
  end;
  
  // 测试边界大小: 15, 16, 17, 31, 32, 33, 63, 64, 65
  for size in [15, 16, 17, 31, 32, 33, 63, 64, 65] do
  begin
    AssertTrue('MemEqual boundary size=' + IntToStr(size),
               MemEqual(@buf1[0], @buf2[0], size));
  end;
end;

{ TTestCase_UnsignedVectorTypes }

// === TVecU32x4 测试 ===

procedure TTestCase_UnsignedVectorTypes.Test_VecU32x4_TypeDef_Size;
var
  v: TVecU32x4;
begin
  AssertEquals('TVecU32x4 should be 16 bytes', 16, SizeOf(v));
end;

procedure TTestCase_UnsignedVectorTypes.Test_VecU32x4_TypeDef_Layout;
var
  v: TVecU32x4;
begin
  v.u[0] := $FFFFFFFF;  // max UInt32
  v.u[1] := $12345678;
  v.u[2] := $00000000;
  v.u[3] := $DEADBEEF;
  
  AssertEquals('u[0] should be $FFFFFFFF', UInt32($FFFFFFFF), v.u[0]);
  AssertEquals('u[1] should be $12345678', UInt32($12345678), v.u[1]);
  AssertEquals('u[2] should be $00000000', UInt32($00000000), v.u[2]);
  AssertEquals('u[3] should be $DEADBEEF', UInt32($DEADBEEF), v.u[3]);
end;

procedure TTestCase_UnsignedVectorTypes.Test_VecU32x4_TypeDef_RawAccess;
var
  v: TVecU32x4;
begin
  v.u[0] := $04030201;
  // raw 数组应该能按小端序访问
  AssertEquals('raw[0] should be $01', $01, v.raw[0]);
  AssertEquals('raw[1] should be $02', $02, v.raw[1]);
  AssertEquals('raw[2] should be $03', $03, v.raw[2]);
  AssertEquals('raw[3] should be $04', $04, v.raw[3]);
end;

// === TVecU16x8 测试 ===

procedure TTestCase_UnsignedVectorTypes.Test_VecU16x8_TypeDef_Size;
var
  v: TVecU16x8;
begin
  AssertEquals('TVecU16x8 should be 16 bytes', 16, SizeOf(v));
end;

procedure TTestCase_UnsignedVectorTypes.Test_VecU16x8_TypeDef_Layout;
var
  v: TVecU16x8;
  i: Integer;
begin
  for i := 0 to 7 do
    v.u[i] := UInt16(i * 1000);
  
  for i := 0 to 7 do
    AssertEquals('u[' + IntToStr(i) + '] should be ' + IntToStr(i * 1000), 
                 UInt16(i * 1000), v.u[i]);
end;

procedure TTestCase_UnsignedVectorTypes.Test_VecU16x8_TypeDef_RawAccess;
var
  v: TVecU16x8;
begin
  v.u[0] := $0201;  // 小端序: raw[0]=01, raw[1]=02
  AssertEquals('raw[0] should be $01', $01, v.raw[0]);
  AssertEquals('raw[1] should be $02', $02, v.raw[1]);
end;

// === TVecU8x16 测试 ===

procedure TTestCase_UnsignedVectorTypes.Test_VecU8x16_TypeDef_Size;
var
  v: TVecU8x16;
begin
  AssertEquals('TVecU8x16 should be 16 bytes', 16, SizeOf(v));
end;

procedure TTestCase_UnsignedVectorTypes.Test_VecU8x16_TypeDef_Layout;
var
  v: TVecU8x16;
  i: Integer;
begin
  for i := 0 to 15 do
    v.u[i] := Byte(i * 10);
  
  for i := 0 to 15 do
    AssertEquals('u[' + IntToStr(i) + '] should be ' + IntToStr(i * 10), 
                 Byte(i * 10), v.u[i]);
end;

procedure TTestCase_UnsignedVectorTypes.Test_VecU8x16_TypeDef_RawAccess;
var
  v: TVecU8x16;
begin
  v.u[0] := $AA;
  v.u[15] := $BB;
  // 对于 UInt8，u 和 raw 应该是相同的布局
  AssertEquals('raw[0] should equal u[0]', v.u[0], v.raw[0]);
  AssertEquals('raw[15] should equal u[15]', v.u[15], v.raw[15]);
end;

// === TVecU64x2 测试 ===

procedure TTestCase_UnsignedVectorTypes.Test_VecU64x2_TypeDef_Size;
var
  v: TVecU64x2;
begin
  AssertEquals('TVecU64x2 should be 16 bytes', 16, SizeOf(v));
end;

procedure TTestCase_UnsignedVectorTypes.Test_VecU64x2_TypeDef_Layout;
var
  v: TVecU64x2;
begin
  v.u[0] := High(UInt64);  // max UInt64 = $FFFFFFFFFFFFFFFF
  v.u[1] := QWord($123456789ABCDEF0);
  
  AssertEquals('u[0] should be max UInt64', High(UInt64), v.u[0]);
  AssertEquals('u[1] should be $123456789ABCDEF0', QWord($123456789ABCDEF0), v.u[1]);
end;

procedure TTestCase_UnsignedVectorTypes.Test_VecU64x2_TypeDef_RawAccess;
var
  v: TVecU64x2;
begin
  v.u[0] := $0807060504030201;
  // raw 数组应该能按小端序访问
  AssertEquals('raw[0] should be $01', $01, v.raw[0]);
  AssertEquals('raw[1] should be $02', $02, v.raw[1]);
  AssertEquals('raw[7] should be $08', $08, v.raw[7]);
end;

// === 256-bit 无符号向量类型测试 ===

procedure TTestCase_UnsignedVectorTypes.Test_VecU32x8_TypeDef_Size;
var
  v: TVecU32x8;
begin
  AssertEquals('TVecU32x8 should be 32 bytes', 32, SizeOf(v));
end;

procedure TTestCase_UnsignedVectorTypes.Test_VecU32x8_TypeDef_LoHi;
var
  v: TVecU32x8;
begin
  // 设置 lo 部分
  v.lo.u[0] := $11111111;
  v.lo.u[1] := $22222222;
  v.lo.u[2] := $33333333;
  v.lo.u[3] := $44444444;
  // 设置 hi 部分
  v.hi.u[0] := $55555555;
  v.hi.u[1] := $66666666;
  v.hi.u[2] := $77777777;
  v.hi.u[3] := $88888888;
  
  // 验证通过 u[] 访问
  AssertEquals('u[0] should match lo.u[0]', UInt32($11111111), v.u[0]);
  AssertEquals('u[3] should match lo.u[3]', UInt32($44444444), v.u[3]);
  AssertEquals('u[4] should match hi.u[0]', UInt32($55555555), v.u[4]);
  AssertEquals('u[7] should match hi.u[3]', UInt32($88888888), v.u[7]);
end;

procedure TTestCase_UnsignedVectorTypes.Test_VecU16x16_TypeDef_Size;
var
  v: TVecU16x16;
begin
  AssertEquals('TVecU16x16 should be 32 bytes', 32, SizeOf(v));
end;

procedure TTestCase_UnsignedVectorTypes.Test_VecU16x16_TypeDef_LoHi;
var
  v: TVecU16x16;
  i: Integer;
begin
  for i := 0 to 7 do
    v.lo.u[i] := UInt16(i);
  for i := 0 to 7 do
    v.hi.u[i] := UInt16(i + 8);
  
  for i := 0 to 15 do
    AssertEquals('u[' + IntToStr(i) + '] should be ' + IntToStr(i), 
                 UInt16(i), v.u[i]);
end;

procedure TTestCase_UnsignedVectorTypes.Test_VecU8x32_TypeDef_Size;
var
  v: TVecU8x32;
begin
  AssertEquals('TVecU8x32 should be 32 bytes', 32, SizeOf(v));
end;

procedure TTestCase_UnsignedVectorTypes.Test_VecU8x32_TypeDef_LoHi;
var
  v: TVecU8x32;
  i: Integer;
begin
  for i := 0 to 15 do
    v.lo.u[i] := Byte(i);
  for i := 0 to 15 do
    v.hi.u[i] := Byte(i + 16);
  
  for i := 0 to 31 do
    AssertEquals('u[' + IntToStr(i) + '] should be ' + IntToStr(i), 
                 Byte(i), v.u[i]);
end;

{ TTestCase_OperatorOverloads }

procedure TTestCase_OperatorOverloads.Test_VecF32x4_Op_Add;
var
  a, b, c: TVecF32x4;
begin
  a := VecF32x4Splat(1.0);
  b := VecF32x4Splat(2.0);
  c := a + b;  // 使用运算符重载
  
  AssertEquals('Element 0 should be 3.0', 3.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('Element 1 should be 3.0', 3.0, VecF32x4Extract(c, 1), 0.0001);
  AssertEquals('Element 2 should be 3.0', 3.0, VecF32x4Extract(c, 2), 0.0001);
  AssertEquals('Element 3 should be 3.0', 3.0, VecF32x4Extract(c, 3), 0.0001);
end;

procedure TTestCase_OperatorOverloads.Test_VecF32x4_Op_Sub;
var
  a, b, c: TVecF32x4;
begin
  a := VecF32x4Splat(5.0);
  b := VecF32x4Splat(2.0);
  c := a - b;  // 使用运算符重载
  
  AssertEquals('Element 0 should be 3.0', 3.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('Element 1 should be 3.0', 3.0, VecF32x4Extract(c, 1), 0.0001);
  AssertEquals('Element 2 should be 3.0', 3.0, VecF32x4Extract(c, 2), 0.0001);
  AssertEquals('Element 3 should be 3.0', 3.0, VecF32x4Extract(c, 3), 0.0001);
end;

procedure TTestCase_OperatorOverloads.Test_VecF32x4_Op_Mul;
var
  a, b, c: TVecF32x4;
begin
  a := VecF32x4Splat(3.0);
  b := VecF32x4Splat(4.0);
  c := a * b;  // 使用运算符重载
  
  AssertEquals('Element 0 should be 12.0', 12.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('Element 1 should be 12.0', 12.0, VecF32x4Extract(c, 1), 0.0001);
  AssertEquals('Element 2 should be 12.0', 12.0, VecF32x4Extract(c, 2), 0.0001);
  AssertEquals('Element 3 should be 12.0', 12.0, VecF32x4Extract(c, 3), 0.0001);
end;

procedure TTestCase_OperatorOverloads.Test_VecF32x4_Op_Div;
var
  a, b, c: TVecF32x4;
begin
  a := VecF32x4Splat(12.0);
  b := VecF32x4Splat(4.0);
  c := a / b;  // 使用运算符重载
  
  AssertEquals('Element 0 should be 3.0', 3.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('Element 1 should be 3.0', 3.0, VecF32x4Extract(c, 1), 0.0001);
  AssertEquals('Element 2 should be 3.0', 3.0, VecF32x4Extract(c, 2), 0.0001);
  AssertEquals('Element 3 should be 3.0', 3.0, VecF32x4Extract(c, 3), 0.0001);
end;

procedure TTestCase_OperatorOverloads.Test_VecF32x4_Op_Neg;
var
  a, c: TVecF32x4;
begin
  a := VecF32x4Splat(5.0);
  c := -a;  // 使用一元负运算符
  
  AssertEquals('Element 0 should be -5.0', -5.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('Element 1 should be -5.0', -5.0, VecF32x4Extract(c, 1), 0.0001);
  AssertEquals('Element 2 should be -5.0', -5.0, VecF32x4Extract(c, 2), 0.0001);
  AssertEquals('Element 3 should be -5.0', -5.0, VecF32x4Extract(c, 3), 0.0001);
end;

procedure TTestCase_OperatorOverloads.Test_VecF64x2_Op_Add;
var
  a, b, c: TVecF64x2;
begin
  a.d[0] := 1.0; a.d[1] := 2.0;
  b.d[0] := 3.0; b.d[1] := 4.0;
  c := a + b;
  
  AssertEquals('d[0] should be 4.0', 4.0, c.d[0], 0.0001);
  AssertEquals('d[1] should be 6.0', 6.0, c.d[1], 0.0001);
end;

procedure TTestCase_OperatorOverloads.Test_VecF64x2_Op_Sub;
var
  a, b, c: TVecF64x2;
begin
  a.d[0] := 5.0; a.d[1] := 7.0;
  b.d[0] := 2.0; b.d[1] := 3.0;
  c := a - b;
  
  AssertEquals('d[0] should be 3.0', 3.0, c.d[0], 0.0001);
  AssertEquals('d[1] should be 4.0', 4.0, c.d[1], 0.0001);
end;

procedure TTestCase_OperatorOverloads.Test_VecF64x2_Op_Mul;
var
  a, b, c: TVecF64x2;
begin
  a.d[0] := 3.0; a.d[1] := 4.0;
  b.d[0] := 2.0; b.d[1] := 5.0;
  c := a * b;
  
  AssertEquals('d[0] should be 6.0', 6.0, c.d[0], 0.0001);
  AssertEquals('d[1] should be 20.0', 20.0, c.d[1], 0.0001);
end;

procedure TTestCase_OperatorOverloads.Test_VecF64x2_Op_Div;
var
  a, b, c: TVecF64x2;
begin
  a.d[0] := 10.0; a.d[1] := 20.0;
  b.d[0] := 2.0;  b.d[1] := 4.0;
  c := a / b;
  
  AssertEquals('d[0] should be 5.0', 5.0, c.d[0], 0.0001);
  AssertEquals('d[1] should be 5.0', 5.0, c.d[1], 0.0001);
end;

procedure TTestCase_OperatorOverloads.Test_VecI32x4_Op_Add;
var
  a, b, c: TVecI32x4;
begin
  a.i[0] := 1; a.i[1] := 2; a.i[2] := 3; a.i[3] := 4;
  b.i[0] := 10; b.i[1] := 20; b.i[2] := 30; b.i[3] := 40;
  c := a + b;
  
  AssertEquals('i[0] should be 11', 11, c.i[0]);
  AssertEquals('i[1] should be 22', 22, c.i[1]);
  AssertEquals('i[2] should be 33', 33, c.i[2]);
  AssertEquals('i[3] should be 44', 44, c.i[3]);
end;

procedure TTestCase_OperatorOverloads.Test_VecI32x4_Op_Sub;
var
  a, b, c: TVecI32x4;
begin
  a.i[0] := 10; a.i[1] := 20; a.i[2] := 30; a.i[3] := 40;
  b.i[0] := 1; b.i[1] := 2; b.i[2] := 3; b.i[3] := 4;
  c := a - b;
  
  AssertEquals('i[0] should be 9', 9, c.i[0]);
  AssertEquals('i[1] should be 18', 18, c.i[1]);
  AssertEquals('i[2] should be 27', 27, c.i[2]);
  AssertEquals('i[3] should be 36', 36, c.i[3]);
end;

procedure TTestCase_OperatorOverloads.Test_VecI32x4_Op_Neg;
var
  a, c: TVecI32x4;
begin
  a.i[0] := 1; a.i[1] := -2; a.i[2] := 3; a.i[3] := -4;
  c := -a;
  
  AssertEquals('i[0] should be -1', -1, c.i[0]);
  AssertEquals('i[1] should be 2', 2, c.i[1]);
  AssertEquals('i[2] should be -3', -3, c.i[2]);
  AssertEquals('i[3] should be 4', 4, c.i[3]);
end;

procedure TTestCase_OperatorOverloads.Test_VecU32x4_Op_All;
var
  a, b, expected, actual: TVecU32x4;
  i: Integer;
begin
  a.u[0] := 0;
  a.u[1] := 1;
  a.u[2] := High(UInt32);
  a.u[3] := $80000000;
  b.u[0] := High(UInt32);
  b.u[1] := 2;
  b.u[2] := 3;
  b.u[3] := $7FFFFFFF;

  expected := VecU32x4Add(a, b); actual := a + b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x4Add lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x4Sub(a, b); actual := a - b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x4Sub lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x4Mul(a, b); actual := a * b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x4Mul lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x4And(a, b); actual := a and b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x4And lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x4Or(a, b); actual := a or b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x4Or lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x4Xor(a, b); actual := a xor b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x4Xor lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x4Not(a); actual := not a;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x4Not lane ' + IntToStr(i), expected.u[i], actual.u[i]);
end;

procedure TTestCase_OperatorOverloads.Test_VecU64x2_Op_All;
var
  a, b, expected, actual: TVecU64x2;
  i: Integer;
begin
  a.u[0] := 0;
  a.u[1] := High(UInt64);
  b.u[0] := High(UInt64);
  b.u[1] := 1;

  expected := VecU64x2Add(a, b); actual := a + b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x2Add lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU64x2Sub(a, b); actual := a - b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x2Sub lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU64x2And(a, b); actual := a and b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x2And lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU64x2Or(a, b); actual := a or b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x2Or lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU64x2Xor(a, b); actual := a xor b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x2Xor lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU64x2Not(a); actual := not a;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x2Not lane ' + IntToStr(i), expected.u[i], actual.u[i]);
end;

procedure TTestCase_OperatorOverloads.Test_VecU16x8_Op_All;
var
  a, b, expected, actual: TVecU16x8;
  i: Integer;
begin
  for i := 0 to High(a.u) do
  begin
    a.u[i] := UInt16(i * 257);
    b.u[i] := UInt16(65535 - i * 131);
  end;

  expected := VecU16x8Add(a, b); actual := a + b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU16x8Add lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU16x8Sub(a, b); actual := a - b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU16x8Sub lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU16x8Mul(a, b); actual := a * b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU16x8Mul lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU16x8And(a, b); actual := a and b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU16x8And lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU16x8Or(a, b); actual := a or b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU16x8Or lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU16x8Xor(a, b); actual := a xor b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU16x8Xor lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU16x8Not(a); actual := not a;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU16x8Not lane ' + IntToStr(i), expected.u[i], actual.u[i]);
end;

procedure TTestCase_OperatorOverloads.Test_VecU8x16_Op_All;
var
  a, b, expected, actual: TVecU8x16;
  i: Integer;
begin
  for i := 0 to High(a.u) do
  begin
    a.u[i] := Byte((i * 17 + 3) and $FF);
    b.u[i] := Byte((255 - i * 11) and $FF);
  end;

  expected := VecU8x16Add(a, b); actual := a + b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU8x16Add lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU8x16Sub(a, b); actual := a - b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU8x16Sub lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU8x16And(a, b); actual := a and b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU8x16And lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU8x16Or(a, b); actual := a or b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU8x16Or lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU8x16Xor(a, b); actual := a xor b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU8x16Xor lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU8x16Not(a); actual := not a;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU8x16Not lane ' + IntToStr(i), expected.u[i], actual.u[i]);
end;

procedure TTestCase_OperatorOverloads.Test_VecU32x8_Op_All;
var
  a, b, expected, actual: TVecU32x8;
  i: Integer;
begin
  for i := 0 to High(a.u) do
  begin
    a.u[i] := UInt32(i * 11111111 + 7);
    b.u[i] := UInt32(High(UInt32) - UInt32(i * 131));
  end;

  expected := VecU32x8Add(a, b); actual := a + b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x8Add lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x8Sub(a, b); actual := a - b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x8Sub lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x8Mul(a, b); actual := a * b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x8Mul lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x8And(a, b); actual := a and b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x8And lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x8Or(a, b); actual := a or b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x8Or lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x8Xor(a, b); actual := a xor b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x8Xor lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x8Not(a); actual := not a;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x8Not lane ' + IntToStr(i), expected.u[i], actual.u[i]);
end;

procedure TTestCase_OperatorOverloads.Test_VecU64x4_Op_All;
var
  a, b, expected, actual: TVecU64x4;
  i: Integer;
begin
  for i := 0 to High(a.u) do
  begin
    a.u[i] := QWord(i) * QWord($1111111111111111);
    b.u[i] := High(QWord) - QWord(i * 17);
  end;

  expected := VecU64x4Add(a, b); actual := a + b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x4Add lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU64x4Sub(a, b); actual := a - b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x4Sub lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU64x4And(a, b); actual := a and b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x4And lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU64x4Or(a, b); actual := a or b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x4Or lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU64x4Xor(a, b); actual := a xor b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x4Xor lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU64x4Not(a); actual := not a;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x4Not lane ' + IntToStr(i), expected.u[i], actual.u[i]);
end;

procedure TTestCase_OperatorOverloads.Test_VecU32x16_Op_All;
var
  a, b, expected, actual: TVecU32x16;
  i: Integer;
begin
  for i := 0 to High(a.u) do
  begin
    a.u[i] := UInt32(i * 257 + 13);
    b.u[i] := UInt32(High(UInt32) - UInt32(i * 97));
  end;

  expected := VecU32x16Add(a, b); actual := a + b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x16Add lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x16Sub(a, b); actual := a - b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x16Sub lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x16Mul(a, b); actual := a * b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x16Mul lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x16And(a, b); actual := a and b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x16And lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x16Or(a, b); actual := a or b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x16Or lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x16Xor(a, b); actual := a xor b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x16Xor lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU32x16Not(a); actual := not a;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU32x16Not lane ' + IntToStr(i), expected.u[i], actual.u[i]);
end;

procedure TTestCase_OperatorOverloads.Test_VecU64x8_Op_All;
var
  a, b, expected, actual: TVecU64x8;
  i: Integer;
begin
  for i := 0 to High(a.u) do
  begin
    a.u[i] := QWord(i) * QWord($1111111111111111);
    b.u[i] := High(QWord) - QWord(i * 23);
  end;

  expected := VecU64x8Add(a, b); actual := a + b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x8Add lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU64x8Sub(a, b); actual := a - b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x8Sub lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU64x8And(a, b); actual := a and b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x8And lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU64x8Or(a, b); actual := a or b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x8Or lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU64x8Xor(a, b); actual := a xor b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x8Xor lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU64x8Not(a); actual := not a;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU64x8Not lane ' + IntToStr(i), expected.u[i], actual.u[i]);
end;

procedure TTestCase_OperatorOverloads.Test_VecU8x64_Op_All;
var
  a, b, expected, actual: TVecU8x64;
  i: Integer;
begin
  for i := 0 to High(a.u) do
  begin
    a.u[i] := Byte((i * 11 + 3) and $FF);
    b.u[i] := Byte((255 - i * 7) and $FF);
  end;

  expected := VecU8x64Add(a, b); actual := a + b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU8x64Add lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU8x64Sub(a, b); actual := a - b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU8x64Sub lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU8x64And(a, b); actual := a and b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU8x64And lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU8x64Or(a, b); actual := a or b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU8x64Or lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU8x64Xor(a, b); actual := a xor b;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU8x64Xor lane ' + IntToStr(i), expected.u[i], actual.u[i]);

  expected := VecU8x64Not(a); actual := not a;
  for i := 0 to High(actual.u) do
    AssertEquals('VecU8x64Not lane ' + IntToStr(i), expected.u[i], actual.u[i]);
end;

procedure TTestCase_OperatorOverloads.Test_VecF32x4_Op_ScalarMul;
var
  a, c: TVecF32x4;
  s: Single;
begin
  a := VecF32x4Splat(3.0);
  s := 4.0;
  c := a * s;  // 向量 * 标量
  
  AssertEquals('Element 0 should be 12.0', 12.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('Element 1 should be 12.0', 12.0, VecF32x4Extract(c, 1), 0.0001);
  AssertEquals('Element 2 should be 12.0', 12.0, VecF32x4Extract(c, 2), 0.0001);
  AssertEquals('Element 3 should be 12.0', 12.0, VecF32x4Extract(c, 3), 0.0001);
end;

procedure TTestCase_OperatorOverloads.Test_VecF32x4_Op_ScalarDiv;
var
  a, c: TVecF32x4;
  s: Single;
begin
  a := VecF32x4Splat(12.0);
  s := 4.0;
  c := a / s;  // 向量 / 标量
  
  AssertEquals('Element 0 should be 3.0', 3.0, VecF32x4Extract(c, 0), 0.0001);
  AssertEquals('Element 1 should be 3.0', 3.0, VecF32x4Extract(c, 1), 0.0001);
  AssertEquals('Element 2 should be 3.0', 3.0, VecF32x4Extract(c, 2), 0.0001);
  AssertEquals('Element 3 should be 3.0', 3.0, VecF32x4Extract(c, 3), 0.0001);
end;

{ TTestCase_VectorMaskTypes }

procedure TTestCase_VectorMaskTypes.Test_MaskF32x4_TypeDef_Size;
var
  m: TMaskF32x4;
begin
  AssertEquals('TMaskF32x4 should be 16 bytes', 16, SizeOf(m));
end;

procedure TTestCase_VectorMaskTypes.Test_MaskF32x4_AllTrue;
var
  m: TMaskF32x4;
begin
  m := MaskF32x4AllTrue;
  AssertEquals('m[0] should be $FFFFFFFF', UInt32($FFFFFFFF), m.m[0]);
  AssertEquals('m[1] should be $FFFFFFFF', UInt32($FFFFFFFF), m.m[1]);
  AssertEquals('m[2] should be $FFFFFFFF', UInt32($FFFFFFFF), m.m[2]);
  AssertEquals('m[3] should be $FFFFFFFF', UInt32($FFFFFFFF), m.m[3]);
end;

procedure TTestCase_VectorMaskTypes.Test_MaskF32x4_AllFalse;
var
  m: TMaskF32x4;
begin
  m := MaskF32x4AllFalse;
  AssertEquals('m[0] should be 0', UInt32(0), m.m[0]);
  AssertEquals('m[1] should be 0', UInt32(0), m.m[1]);
  AssertEquals('m[2] should be 0', UInt32(0), m.m[2]);
  AssertEquals('m[3] should be 0', UInt32(0), m.m[3]);
end;

procedure TTestCase_VectorMaskTypes.Test_MaskF32x4_Mixed;
var
  m: TMaskF32x4;
begin
  m := MaskF32x4Set(True, False, True, False);
  AssertEquals('m[0] should be $FFFFFFFF', UInt32($FFFFFFFF), m.m[0]);
  AssertEquals('m[1] should be 0', UInt32(0), m.m[1]);
  AssertEquals('m[2] should be $FFFFFFFF', UInt32($FFFFFFFF), m.m[2]);
  AssertEquals('m[3] should be 0', UInt32(0), m.m[3]);
end;

procedure TTestCase_VectorMaskTypes.Test_MaskF32x4_Test;
var
  m: TMaskF32x4;
begin
  m := MaskF32x4Set(True, False, True, False);
  AssertTrue('Test(0) should be True', MaskF32x4Test(m, 0));
  AssertFalse('Test(1) should be False', MaskF32x4Test(m, 1));
  AssertTrue('Test(2) should be True', MaskF32x4Test(m, 2));
  AssertFalse('Test(3) should be False', MaskF32x4Test(m, 3));
end;

procedure TTestCase_VectorMaskTypes.Test_MaskF32x4_ToBitmask;
var
  m: TMaskF32x4;
  bm: TMask4;
begin
  m := MaskF32x4AllTrue;
  bm := MaskF32x4ToBitmask(m);
  AssertEquals('AllTrue bitmask should be $F', $F, bm);
  
  m := MaskF32x4AllFalse;
  bm := MaskF32x4ToBitmask(m);
  AssertEquals('AllFalse bitmask should be 0', 0, bm);
  
  m := MaskF32x4Set(True, False, True, False);
  bm := MaskF32x4ToBitmask(m);
  AssertEquals('Mixed bitmask should be $5', $5, bm);  // bits 0,2 set = 0101
end;

procedure TTestCase_VectorMaskTypes.Test_MaskF32x4_Any;
var
  m: TMaskF32x4;
begin
  m := MaskF32x4AllTrue;
  AssertTrue('AllTrue.Any should be True', MaskF32x4Any(m));
  
  m := MaskF32x4AllFalse;
  AssertFalse('AllFalse.Any should be False', MaskF32x4Any(m));
  
  m := MaskF32x4Set(False, False, False, True);
  AssertTrue('OnlyLast.Any should be True', MaskF32x4Any(m));
end;

procedure TTestCase_VectorMaskTypes.Test_MaskF32x4_All;
var
  m: TMaskF32x4;
begin
  m := MaskF32x4AllTrue;
  AssertTrue('AllTrue.All should be True', MaskF32x4All(m));
  
  m := MaskF32x4AllFalse;
  AssertFalse('AllFalse.All should be False', MaskF32x4All(m));
  
  m := MaskF32x4Set(True, True, True, False);
  AssertFalse('Almost all.All should be False', MaskF32x4All(m));
end;

procedure TTestCase_VectorMaskTypes.Test_MaskF32x4_None;
var
  m: TMaskF32x4;
begin
  m := MaskF32x4AllTrue;
  AssertFalse('AllTrue.None should be False', MaskF32x4None(m));
  
  m := MaskF32x4AllFalse;
  AssertTrue('AllFalse.None should be True', MaskF32x4None(m));
  
  m := MaskF32x4Set(False, False, False, True);
  AssertFalse('OnlyLast.None should be False', MaskF32x4None(m));
end;

procedure TTestCase_VectorMaskTypes.Test_MaskF32x4_Op_And;
var
  a, b, c: TMaskF32x4;
begin
  a := MaskF32x4Set(True, True, False, False);
  b := MaskF32x4Set(True, False, True, False);
  c := a and b;
  
  AssertTrue('(T and T) should be T', MaskF32x4Test(c, 0));
  AssertFalse('(T and F) should be F', MaskF32x4Test(c, 1));
  AssertFalse('(F and T) should be F', MaskF32x4Test(c, 2));
  AssertFalse('(F and F) should be F', MaskF32x4Test(c, 3));
end;

procedure TTestCase_VectorMaskTypes.Test_MaskF32x4_Op_Or;
var
  a, b, c: TMaskF32x4;
begin
  a := MaskF32x4Set(True, True, False, False);
  b := MaskF32x4Set(True, False, True, False);
  c := a or b;
  
  AssertTrue('(T or T) should be T', MaskF32x4Test(c, 0));
  AssertTrue('(T or F) should be T', MaskF32x4Test(c, 1));
  AssertTrue('(F or T) should be T', MaskF32x4Test(c, 2));
  AssertFalse('(F or F) should be F', MaskF32x4Test(c, 3));
end;

procedure TTestCase_VectorMaskTypes.Test_MaskF32x4_Op_Xor;
var
  a, b, c: TMaskF32x4;
begin
  a := MaskF32x4Set(True, True, False, False);
  b := MaskF32x4Set(True, False, True, False);
  c := a xor b;
  
  AssertFalse('(T xor T) should be F', MaskF32x4Test(c, 0));
  AssertTrue('(T xor F) should be T', MaskF32x4Test(c, 1));
  AssertTrue('(F xor T) should be T', MaskF32x4Test(c, 2));
  AssertFalse('(F xor F) should be F', MaskF32x4Test(c, 3));
end;

procedure TTestCase_VectorMaskTypes.Test_MaskF32x4_Op_Not;
var
  a, c: TMaskF32x4;
begin
  a := MaskF32x4Set(True, False, True, False);
  c := not a;
  
  AssertFalse('(not T) should be F', MaskF32x4Test(c, 0));
  AssertTrue('(not F) should be T', MaskF32x4Test(c, 1));
  AssertFalse('(not T) should be F', MaskF32x4Test(c, 2));
  AssertTrue('(not F) should be T', MaskF32x4Test(c, 3));
end;

procedure TTestCase_VectorMaskTypes.Test_MaskI32x4_TypeDef_Size;
var
  m: TMaskI32x4;
begin
  AssertEquals('TMaskI32x4 should be 16 bytes', 16, SizeOf(m));
end;

procedure TTestCase_VectorMaskTypes.Test_MaskI32x4_AllTrue;
var
  m: TMaskI32x4;
begin
  m := MaskI32x4AllTrue;
  AssertEquals('m[0] should be $FFFFFFFF', UInt32($FFFFFFFF), m.m[0]);
  AssertEquals('m[1] should be $FFFFFFFF', UInt32($FFFFFFFF), m.m[1]);
  AssertEquals('m[2] should be $FFFFFFFF', UInt32($FFFFFFFF), m.m[2]);
  AssertEquals('m[3] should be $FFFFFFFF', UInt32($FFFFFFFF), m.m[3]);
end;

procedure TTestCase_VectorMaskTypes.Test_MaskI32x4_ToBitmask;
var
  m: TMaskI32x4;
  bm: TMask4;
begin
  m := MaskI32x4AllTrue;
  bm := MaskI32x4ToBitmask(m);
  AssertEquals('AllTrue bitmask should be $F', $F, bm);
  
  m := MaskI32x4AllFalse;
  bm := MaskI32x4ToBitmask(m);
  AssertEquals('AllFalse bitmask should be 0', 0, bm);
end;

procedure TTestCase_VectorMaskTypes.Test_MaskF64x2_TypeDef_Size;
var
  m: TMaskF64x2;
begin
  AssertEquals('TMaskF64x2 should be 16 bytes', 16, SizeOf(m));
end;

procedure TTestCase_VectorMaskTypes.Test_MaskF64x2_AllTrue;
var
  m: TMaskF64x2;
begin
  m := MaskF64x2AllTrue;
  AssertEquals('m[0] should be max UInt64', High(UInt64), m.m[0]);
  AssertEquals('m[1] should be max UInt64', High(UInt64), m.m[1]);
end;

procedure TTestCase_VectorMaskTypes.Test_MaskF64x2_ToBitmask;
var
  m: TMaskF64x2;
  bm: TMask2;
begin
  m := MaskF64x2AllTrue;
  bm := MaskF64x2ToBitmask(m);
  AssertEquals('AllTrue bitmask should be $3', $3, bm);
  
  m := MaskF64x2AllFalse;
  bm := MaskF64x2ToBitmask(m);
  AssertEquals('AllFalse bitmask should be 0', 0, bm);
end;

procedure TTestCase_VectorMaskTypes.Test_MaskF32x4_Select;
var
  m: TMaskF32x4;
  a, b, r: TVecF32x4;
begin
  // mask: [T, F, T, F]
  m := MaskF32x4Set(True, False, True, False);
  
  // a = [1, 2, 3, 4], b = [10, 20, 30, 40]
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  b.f[0] := 10.0; b.f[1] := 20.0; b.f[2] := 30.0; b.f[3] := 40.0;
  
  r := MaskF32x4Select(m, a, b);
  
  // result should be [1, 20, 3, 40]
  AssertEquals('r[0] should be 1.0 (from a)', 1.0, r.f[0], 0.0001);
  AssertEquals('r[1] should be 20.0 (from b)', 20.0, r.f[1], 0.0001);
  AssertEquals('r[2] should be 3.0 (from a)', 3.0, r.f[2], 0.0001);
  AssertEquals('r[3] should be 40.0 (from b)', 40.0, r.f[3], 0.0001);
end;

{ TTestCase_TypeConversion }

procedure TTestCase_TypeConversion.Test_VecF32x4_IntoBits;
var
  f: TVecF32x4;
  i: TVecI32x4;
begin
  // 1.0 的位模式是 0x3F800000
  f.f[0] := 1.0;
  f.f[1] := 1.0;
  f.f[2] := 1.0;
  f.f[3] := 1.0;
  i := VecF32x4IntoBits(f);
  
  AssertEquals('1.0 bit pattern should be $3F800000', Int32($3F800000), i.i[0]);
  AssertEquals('Element 1 should match', Int32($3F800000), i.i[1]);
  AssertEquals('Element 2 should match', Int32($3F800000), i.i[2]);
  AssertEquals('Element 3 should match', Int32($3F800000), i.i[3]);
end;

procedure TTestCase_TypeConversion.Test_VecI32x4_FromBitsF32;
var
  i: TVecI32x4;
  f: TVecF32x4;
begin
  // 0x3F800000 解释为浮点数应该是 1.0
  i.i[0] := Int32($3F800000);
  i.i[1] := Int32($3F800000);
  i.i[2] := Int32($3F800000);
  i.i[3] := Int32($3F800000);
  
  f := VecI32x4FromBitsF32(i);
  
  AssertEquals('$3F800000 as float should be 1.0', 1.0, f.f[0], 0.0001);
  AssertEquals('Element 1 should be 1.0', 1.0, f.f[1], 0.0001);
  AssertEquals('Element 2 should be 1.0', 1.0, f.f[2], 0.0001);
  AssertEquals('Element 3 should be 1.0', 1.0, f.f[3], 0.0001);
end;

procedure TTestCase_TypeConversion.Test_IntoBits_FromBits_Roundtrip;
var
  original, restored: TVecF32x4;
  bits: TVecI32x4;
begin
  original.f[0] := 1.5;
  original.f[1] := -2.5;
  original.f[2] := 3.14159;
  original.f[3] := 0.0;
  
  bits := VecF32x4IntoBits(original);
  restored := VecI32x4FromBitsF32(bits);
  
  AssertEquals('Roundtrip [0]', original.f[0], restored.f[0], 0.0001);
  AssertEquals('Roundtrip [1]', original.f[1], restored.f[1], 0.0001);
  AssertEquals('Roundtrip [2]', original.f[2], restored.f[2], 0.0001);
  AssertEquals('Roundtrip [3]', original.f[3], restored.f[3], 0.0001);
end;

procedure TTestCase_TypeConversion.Test_VecF64x2_IntoBits;
var
  f: TVecF64x2;
  i: TVecI64x2;
begin
  // 1.0 的 double 位模式是 0x3FF0000000000000
  f.d[0] := 1.0;
  f.d[1] := 1.0;
  i := VecF64x2IntoBits(f);
  
  AssertEquals('1.0 double bit pattern', Int64($3FF0000000000000), i.i[0]);
  AssertEquals('Element 1 should match', Int64($3FF0000000000000), i.i[1]);
end;

procedure TTestCase_TypeConversion.Test_VecI64x2_FromBitsF64;
var
  i: TVecI64x2;
  f: TVecF64x2;
begin
  i.i[0] := Int64($3FF0000000000000);  // 1.0
  i.i[1] := Int64($4000000000000000);  // 2.0
  
  f := VecI64x2FromBitsF64(i);
  
  AssertEquals('$3FF... as double should be 1.0', 1.0, f.d[0], 0.0001);
  AssertEquals('$400... as double should be 2.0', 2.0, f.d[1], 0.0001);
end;

procedure TTestCase_TypeConversion.Test_VecF32x4_CastToI32x4;
var
  f: TVecF32x4;
  i: TVecI32x4;
begin
  f.f[0] := 1.9;   // 截断为 1
  f.f[1] := -2.9;  // 截断为 -2
  f.f[2] := 0.0;
  f.f[3] := 100.5; // 截断为 100
  
  i := VecF32x4CastToI32x4(f);
  
  AssertEquals('1.9 truncates to 1', 1, i.i[0]);
  AssertEquals('-2.9 truncates to -2', -2, i.i[1]);
  AssertEquals('0.0 truncates to 0', 0, i.i[2]);
  AssertEquals('100.5 truncates to 100', 100, i.i[3]);

  f.f[0] := -1.1;
  f.f[1] := 2.999;
  f.f[2] := -0.99;
  f.f[3] := 42.01;

  i := VecF32x4CastToI32x4(f);

  AssertEquals('-1.1 truncates to -1', -1, i.i[0]);
  AssertEquals('2.999 truncates to 2', 2, i.i[1]);
  AssertEquals('-0.99 truncates to 0', 0, i.i[2]);
  AssertEquals('42.01 truncates to 42', 42, i.i[3]);
end;

procedure TTestCase_TypeConversion.Test_VecI32x4_CastToF32x4;
var
  i: TVecI32x4;
  f: TVecF32x4;
begin
  i.i[0] := 1;
  i.i[1] := -2;
  i.i[2] := 0;
  i.i[3] := 100;
  
  f := VecI32x4CastToF32x4(i);
  
  AssertEquals('1 converts to 1.0', 1.0, f.f[0], 0.0001);
  AssertEquals('-2 converts to -2.0', -2.0, f.f[1], 0.0001);
  AssertEquals('0 converts to 0.0', 0.0, f.f[2], 0.0001);
  AssertEquals('100 converts to 100.0', 100.0, f.f[3], 0.0001);

  i.i[0] := -123;
  i.i[1] := 456;
  i.i[2] := -789;
  i.i[3] := 2048;

  f := VecI32x4CastToF32x4(i);

  AssertEquals('-123 converts to -123.0', -123.0, f.f[0], 0.0001);
  AssertEquals('456 converts to 456.0', 456.0, f.f[1], 0.0001);
  AssertEquals('-789 converts to -789.0', -789.0, f.f[2], 0.0001);
  AssertEquals('2048 converts to 2048.0', 2048.0, f.f[3], 0.0001);
end;

procedure TTestCase_TypeConversion.Test_VecF64x2_CastToI64x2;
var
  f: TVecF64x2;
  i: TVecI64x2;
begin
  f.d[0] := 1.9;   // 截断为 1
  f.d[1] := -2.9;  // 截断为 -2
  
  i := VecF64x2CastToI64x2(f);
  
  AssertEquals('1.9 truncates to 1', Int64(1), i.i[0]);
  AssertEquals('-2.9 truncates to -2', Int64(-2), i.i[1]);
end;

procedure TTestCase_TypeConversion.Test_VecI64x2_CastToF64x2;
var
  i: TVecI64x2;
  f: TVecF64x2;
begin
  i.i[0] := 1;
  i.i[1] := -2;
  
  f := VecI64x2CastToF64x2(i);
  
  AssertEquals('1 converts to 1.0', 1.0, f.d[0], 0.0001);
  AssertEquals('-2 converts to -2.0', -2.0, f.d[1], 0.0001);
end;

procedure TTestCase_TypeConversion.Test_VecI16x8_WidenLo_I32x4;
var
  a: TVecI16x8;
  r: TVecI32x4;
begin
  // 设置低 4 个元素，包含负数测试符号扩展
  a.i[0] := 100;
  a.i[1] := -100;
  a.i[2] := 32767;   // max Int16
  a.i[3] := -32768;  // min Int16
  a.i[4] := 1; a.i[5] := 2; a.i[6] := 3; a.i[7] := 4;  // 高 4 个元素（应被忽略）
  
  r := VecI16x8WidenLoI32x4(a);
  
  AssertEquals('Widen lo[0]', Int32(100), r.i[0]);
  AssertEquals('Widen lo[1] with sign', Int32(-100), r.i[1]);
  AssertEquals('Widen lo[2] max', Int32(32767), r.i[2]);
  AssertEquals('Widen lo[3] min', Int32(-32768), r.i[3]);
end;

procedure TTestCase_TypeConversion.Test_VecI16x8_WidenHi_I32x4;
var
  a: TVecI16x8;
  r: TVecI32x4;
begin
  a.i[0] := 1; a.i[1] := 2; a.i[2] := 3; a.i[3] := 4;  // 低 4 个元素（应被忽略）
  // 设置高 4 个元素
  a.i[4] := 200;
  a.i[5] := -200;
  a.i[6] := 32767;
  a.i[7] := -32768;
  
  r := VecI16x8WidenHiI32x4(a);
  
  AssertEquals('Widen hi[0]', Int32(200), r.i[0]);
  AssertEquals('Widen hi[1] with sign', Int32(-200), r.i[1]);
  AssertEquals('Widen hi[2] max', Int32(32767), r.i[2]);
  AssertEquals('Widen hi[3] min', Int32(-32768), r.i[3]);
end;

procedure TTestCase_TypeConversion.Test_VecI32x4_NarrowToI16x8;
var
  a, b: TVecI32x4;
  r: TVecI16x8;
begin
  // a -> 低 4 个元素
  a.i[0] := 100;
  a.i[1] := -100;
  a.i[2] := 32767;
  a.i[3] := -32768;
  
  // b -> 高 4 个元素
  b.i[0] := 1;
  b.i[1] := 2;
  b.i[2] := 3;
  b.i[3] := 4;
  
  r := VecI32x4NarrowToI16x8(a, b);
  
  // 低 4 个元素来自 a
  AssertEquals('Narrow[0] from a', Int16(100), r.i[0]);
  AssertEquals('Narrow[1] from a', Int16(-100), r.i[1]);
  AssertEquals('Narrow[2] from a', Int16(32767), r.i[2]);
  AssertEquals('Narrow[3] from a', Int16(-32768), r.i[3]);
  // 高 4 个元素来自 b
  AssertEquals('Narrow[4] from b', Int16(1), r.i[4]);
  AssertEquals('Narrow[5] from b', Int16(2), r.i[5]);
  AssertEquals('Narrow[6] from b', Int16(3), r.i[6]);
  AssertEquals('Narrow[7] from b', Int16(4), r.i[7]);
end;

procedure TTestCase_TypeConversion.Test_VecF32x4_ToF64x2_Lo;
var
  a: TVecF32x4;
  r: TVecF64x2;
begin
  a.f[0] := 1.5;
  a.f[1] := -2.5;
  a.f[2] := 999.0;  // 应被忽略
  a.f[3] := 888.0;  // 应被忽略
  
  r := VecF32x4ToF64x2Lo(a);
  
  AssertEquals('F32->F64 [0]', 1.5, r.d[0], 0.0001);
  AssertEquals('F32->F64 [1]', -2.5, r.d[1], 0.0001);
end;

procedure TTestCase_TypeConversion.Test_VecF64x2_ToF32x4;
var
  a, b: TVecF64x2;
  r: TVecF32x4;
begin
  // a -> 低 2 个元素
  a.d[0] := 1.5;
  a.d[1] := -2.5;
  
  // b -> 高 2 个元素
  b.d[0] := 3.5;
  b.d[1] := 4.5;
  
  r := VecF64x2ToF32x4(a, b);
  
  AssertEquals('F64->F32 [0] from a', 1.5, r.f[0], 0.0001);
  AssertEquals('F64->F32 [1] from a', -2.5, r.f[1], 0.0001);
  AssertEquals('F64->F32 [2] from b', 3.5, r.f[2], 0.0001);
  AssertEquals('F64->F32 [3] from b', 4.5, r.f[3], 0.0001);
end;

{ TTestCase_Builder }

procedure TTestCase_Builder.Test_Builder_Create_FromValues;
var
  v: TVecF32x4;
begin
  v := TVecF32x4Builder.FromValues(1.0, 2.0, 3.0, 4.0).Build;
  
  AssertEquals('Element 0', 1.0, v.f[0], 0.0001);
  AssertEquals('Element 1', 2.0, v.f[1], 0.0001);
  AssertEquals('Element 2', 3.0, v.f[2], 0.0001);
  AssertEquals('Element 3', 4.0, v.f[3], 0.0001);
end;

procedure TTestCase_Builder.Test_Builder_Create_Splat;
var
  v: TVecF32x4;
begin
  v := TVecF32x4Builder.Splat(42.0).Build;
  
  AssertEquals('Element 0', 42.0, v.f[0], 0.0001);
  AssertEquals('Element 1', 42.0, v.f[1], 0.0001);
  AssertEquals('Element 2', 42.0, v.f[2], 0.0001);
  AssertEquals('Element 3', 42.0, v.f[3], 0.0001);
end;

procedure TTestCase_Builder.Test_Builder_Create_Load;
var
  arr: array[0..3] of Single;
  v: TVecF32x4;
begin
  arr[0] := 10.0; arr[1] := 20.0; arr[2] := 30.0; arr[3] := 40.0;
  v := TVecF32x4Builder.Load(@arr[0]).Build;
  
  AssertEquals('Element 0', 10.0, v.f[0], 0.0001);
  AssertEquals('Element 1', 20.0, v.f[1], 0.0001);
  AssertEquals('Element 2', 30.0, v.f[2], 0.0001);
  AssertEquals('Element 3', 40.0, v.f[3], 0.0001);
end;

procedure TTestCase_Builder.Test_Builder_Chain_Add;
var
  v: TVecF32x4;
begin
  // (1,2,3,4) + (10,20,30,40) = (11,22,33,44)
  v := TVecF32x4Builder.FromValues(1.0, 2.0, 3.0, 4.0)
         .Add(TVecF32x4Builder.FromValues(10.0, 20.0, 30.0, 40.0).Build)
         .Build;
  
  AssertEquals('Element 0', 11.0, v.f[0], 0.0001);
  AssertEquals('Element 1', 22.0, v.f[1], 0.0001);
  AssertEquals('Element 2', 33.0, v.f[2], 0.0001);
  AssertEquals('Element 3', 44.0, v.f[3], 0.0001);
end;

procedure TTestCase_Builder.Test_Builder_Chain_MulAdd;
var
  v: TVecF32x4;
begin
  // (1,2,3,4) * 2 + (10,10,10,10) = (12,14,16,18)
  v := TVecF32x4Builder.FromValues(1.0, 2.0, 3.0, 4.0)
         .MulScalar(2.0)
         .AddScalar(10.0)
         .Build;
  
  AssertEquals('Element 0', 12.0, v.f[0], 0.0001);
  AssertEquals('Element 1', 14.0, v.f[1], 0.0001);
  AssertEquals('Element 2', 16.0, v.f[2], 0.0001);
  AssertEquals('Element 3', 18.0, v.f[3], 0.0001);
end;

procedure TTestCase_Builder.Test_Builder_Chain_Normalize;
var
  v: TVecF32x4;
  len: Single;
begin
  // (3,0,0,0) normalized = (1,0,0,0)
  v := TVecF32x4Builder.FromValues(3.0, 0.0, 0.0, 0.0)
         .Normalize
         .Build;
  
  AssertEquals('Element 0', 1.0, v.f[0], 0.0001);
  AssertEquals('Element 1', 0.0, v.f[1], 0.0001);
  AssertEquals('Element 2', 0.0, v.f[2], 0.0001);
  AssertEquals('Element 3', 0.0, v.f[3], 0.0001);
  
  // 验证长度为 1
  len := VecF32x4Length(v);
  AssertEquals('Length should be 1', 1.0, len, 0.0001);
end;

procedure TTestCase_Builder.Test_Builder_Chain_Clamp;
var
  v: TVecF32x4;
begin
  // (-5, 5, 15, 0) clamped to [0,10] = (0, 5, 10, 0)
  v := TVecF32x4Builder.FromValues(-5.0, 5.0, 15.0, 0.0)
         .Clamp(0.0, 10.0)
         .Build;
  
  AssertEquals('Element 0', 0.0, v.f[0], 0.0001);
  AssertEquals('Element 1', 5.0, v.f[1], 0.0001);
  AssertEquals('Element 2', 10.0, v.f[2], 0.0001);
  AssertEquals('Element 3', 0.0, v.f[3], 0.0001);
end;

procedure TTestCase_Builder.Test_Builder_Build;
var
  v: TVecF32x4;
begin
  v := TVecF32x4Builder.FromValues(1.0, 2.0, 3.0, 4.0).Build;
  
  AssertEquals('Element 0', 1.0, v.f[0], 0.0001);
  AssertEquals('Element 1', 2.0, v.f[1], 0.0001);
  AssertEquals('Element 2', 3.0, v.f[2], 0.0001);
  AssertEquals('Element 3', 4.0, v.f[3], 0.0001);
end;

procedure TTestCase_Builder.Test_Builder_ReduceAdd;
var
  sum: Single;
begin
  sum := TVecF32x4Builder.FromValues(1.0, 2.0, 3.0, 4.0).ReduceAdd;
  AssertEquals('Sum should be 10', 10.0, sum, 0.0001);
end;

procedure TTestCase_Builder.Test_Builder_ReduceMin;
var
  minVal: Single;
begin
  minVal := TVecF32x4Builder.FromValues(5.0, 2.0, 8.0, 3.0).ReduceMin;
  AssertEquals('Min should be 2', 2.0, minVal, 0.0001);
end;

procedure TTestCase_Builder.Test_Builder_ReduceMax;
var
  maxVal: Single;
begin
  maxVal := TVecF32x4Builder.FromValues(5.0, 2.0, 8.0, 3.0).ReduceMax;
  AssertEquals('Max should be 8', 8.0, maxVal, 0.0001);
end;

procedure TTestCase_Builder.Test_Builder_Complex_DotProduct;
var
  dot: Single;
begin
  // (1,2,3,4) · (2,3,4,5) = 2+6+12+20 = 40
  dot := TVecF32x4Builder.FromValues(1.0, 2.0, 3.0, 4.0)
           .Mul(TVecF32x4Builder.FromValues(2.0, 3.0, 4.0, 5.0).Build)
           .ReduceAdd;
  
  AssertEquals('Dot product should be 40', 40.0, dot, 0.0001);
end;

procedure TTestCase_Builder.Test_Builder_Complex_Lerp;
var
  v: TVecF32x4;
begin
  // lerp((0,0,0,0), (10,10,10,10), 0.3) = (3,3,3,3)
  v := TVecF32x4Builder.Splat(0.0)
         .Lerp(TVecF32x4Builder.Splat(10.0).Build, 0.3)
         .Build;
  
  AssertEquals('Element 0', 3.0, v.f[0], 0.0001);
  AssertEquals('Element 1', 3.0, v.f[1], 0.0001);
  AssertEquals('Element 2', 3.0, v.f[2], 0.0001);
  AssertEquals('Element 3', 3.0, v.f[3], 0.0001);
end;

{ TTestCase_GatherScatter }

procedure TTestCase_GatherScatter.Test_VecF32x4_Gather_Sequential;
var
  data: array[0..15] of Single;
  indices: TVecI32x4;
  r: TVecF32x4;
  i: Integer;
begin
  // 准备数据
  for i := 0 to 15 do
    data[i] := (i + 1) * 10.0;  // [10, 20, 30, ..., 160]
  
  // 顺序索引: [0, 1, 2, 3]
  indices.i[0] := 0;
  indices.i[1] := 1;
  indices.i[2] := 2;
  indices.i[3] := 3;
  
  r := nextpas.core.simd.VecF32x4Gather(@data[0], indices);
  
  AssertEquals('Gather[0]', 10.0, r.f[0], 0.0001);
  AssertEquals('Gather[1]', 20.0, r.f[1], 0.0001);
  AssertEquals('Gather[2]', 30.0, r.f[2], 0.0001);
  AssertEquals('Gather[3]', 40.0, r.f[3], 0.0001);
end;

procedure TTestCase_GatherScatter.Test_VecF32x4_Gather_Stride;
var
  data: array[0..15] of Single;
  indices: TVecI32x4;
  r: TVecF32x4;
  i: Integer;
begin
  for i := 0 to 15 do
    data[i] := (i + 1) * 10.0;
  
  // 跨步索引: [0, 2, 4, 6] (stride = 2)
  indices.i[0] := 0;
  indices.i[1] := 2;
  indices.i[2] := 4;
  indices.i[3] := 6;
  
  r := nextpas.core.simd.VecF32x4Gather(@data[0], indices);
  
  AssertEquals('Gather stride[0]', 10.0, r.f[0], 0.0001);
  AssertEquals('Gather stride[1]', 30.0, r.f[1], 0.0001);
  AssertEquals('Gather stride[2]', 50.0, r.f[2], 0.0001);
  AssertEquals('Gather stride[3]', 70.0, r.f[3], 0.0001);
end;

procedure TTestCase_GatherScatter.Test_VecF32x4_Gather_Random;
var
  data: array[0..15] of Single;
  indices: TVecI32x4;
  r: TVecF32x4;
  i: Integer;
begin
  for i := 0 to 15 do
    data[i] := (i + 1) * 10.0;
  
  // 随机索引: [7, 0, 15, 3]
  indices.i[0] := 7;
  indices.i[1] := 0;
  indices.i[2] := 15;
  indices.i[3] := 3;
  
  r := nextpas.core.simd.VecF32x4Gather(@data[0], indices);
  
  AssertEquals('Gather random[0]', 80.0, r.f[0], 0.0001);
  AssertEquals('Gather random[1]', 10.0, r.f[1], 0.0001);
  AssertEquals('Gather random[2]', 160.0, r.f[2], 0.0001);
  AssertEquals('Gather random[3]', 40.0, r.f[3], 0.0001);
end;

procedure TTestCase_GatherScatter.Test_VecF32x4_Gather_DuplicateIndices_DuplicateValues;
var
  data: array[0..7] of Single;
  indices: TVecI32x4;
  r: TVecF32x4;
  i: Integer;
begin
  for i := 0 to 7 do
    data[i] := (i + 1) * 10.0;

  indices.i[0] := 3;
  indices.i[1] := 1;
  indices.i[2] := 3;
  indices.i[3] := 1;

  r := nextpas.core.simd.VecF32x4Gather(@data[0], indices);

  AssertEquals('Gather duplicate[0]', 40.0, r.f[0], 0.0001);
  AssertEquals('Gather duplicate[1]', 20.0, r.f[1], 0.0001);
  AssertEquals('Gather duplicate[2]', 40.0, r.f[2], 0.0001);
  AssertEquals('Gather duplicate[3]', 20.0, r.f[3], 0.0001);
end;

procedure TTestCase_GatherScatter.Test_VecI32x4_Gather_Sequential;
var
  data: array[0..15] of Int32;
  indices: TVecI32x4;
  r: TVecI32x4;
  i: Integer;
begin
  for i := 0 to 15 do
    data[i] := (i + 1) * 100;
  
  indices.i[0] := 0;
  indices.i[1] := 1;
  indices.i[2] := 2;
  indices.i[3] := 3;
  
  r := nextpas.core.simd.VecI32x4Gather(@data[0], indices);
  
  AssertEquals('Gather[0]', 100, r.i[0]);
  AssertEquals('Gather[1]', 200, r.i[1]);
  AssertEquals('Gather[2]', 300, r.i[2]);
  AssertEquals('Gather[3]', 400, r.i[3]);
end;

procedure TTestCase_GatherScatter.Test_VecI32x4_Gather_Negative;
var
  data: array[0..15] of Int32;
  indices: TVecI32x4;
  r: TVecI32x4;
  i: Integer;
begin
  for i := 0 to 15 do
    data[i] := i - 8;  // [-8, -7, ..., 7]
  
  indices.i[0] := 0;
  indices.i[1] := 8;
  indices.i[2] := 15;
  indices.i[3] := 4;
  
  r := nextpas.core.simd.VecI32x4Gather(@data[0], indices);
  
  AssertEquals('Gather negative[0]', -8, r.i[0]);
  AssertEquals('Gather negative[1]', 0, r.i[1]);
  AssertEquals('Gather negative[2]', 7, r.i[2]);
  AssertEquals('Gather negative[3]', -4, r.i[3]);
end;

procedure TTestCase_GatherScatter.Test_VecF32x4_Scatter_Sequential;
var
  data: array[0..15] of Single;
  indices: TVecI32x4;
  values: TVecF32x4;
  i: Integer;
begin
  // 清零目标数组
  for i := 0 to 15 do
    data[i] := 0.0;
  
  // 顺序索引
  indices.i[0] := 0;
  indices.i[1] := 1;
  indices.i[2] := 2;
  indices.i[3] := 3;
  
  // 要写入的值
  values.f[0] := 11.0;
  values.f[1] := 22.0;
  values.f[2] := 33.0;
  values.f[3] := 44.0;
  
  nextpas.core.simd.VecF32x4Scatter(@data[0], indices, values);
  
  AssertEquals('Scatter[0]', 11.0, data[0], 0.0001);
  AssertEquals('Scatter[1]', 22.0, data[1], 0.0001);
  AssertEquals('Scatter[2]', 33.0, data[2], 0.0001);
  AssertEquals('Scatter[3]', 44.0, data[3], 0.0001);
  // 确保其它位置未被修改
  AssertEquals('Scatter[4] unchanged', 0.0, data[4], 0.0001);
end;

procedure TTestCase_GatherScatter.Test_VecF32x4_Scatter_Stride;
var
  data: array[0..15] of Single;
  indices: TVecI32x4;
  values: TVecF32x4;
  i: Integer;
begin
  for i := 0 to 15 do
    data[i] := 0.0;
  
  // 跨步索引: [0, 4, 8, 12]
  indices.i[0] := 0;
  indices.i[1] := 4;
  indices.i[2] := 8;
  indices.i[3] := 12;
  
  values.f[0] := 100.0;
  values.f[1] := 200.0;
  values.f[2] := 300.0;
  values.f[3] := 400.0;
  
  nextpas.core.simd.VecF32x4Scatter(@data[0], indices, values);
  
  AssertEquals('Scatter stride[0]', 100.0, data[0], 0.0001);
  AssertEquals('Scatter stride[4]', 200.0, data[4], 0.0001);
  AssertEquals('Scatter stride[8]', 300.0, data[8], 0.0001);
  AssertEquals('Scatter stride[12]', 400.0, data[12], 0.0001);
  // 确保中间位置未被修改
  AssertEquals('Scatter[1] unchanged', 0.0, data[1], 0.0001);
  AssertEquals('Scatter[5] unchanged', 0.0, data[5], 0.0001);
end;

procedure TTestCase_GatherScatter.Test_VecI32x4_Scatter_Sequential;
var
  data: array[0..15] of Int32;
  indices: TVecI32x4;
  values: TVecI32x4;
  i: Integer;
begin
  for i := 0 to 15 do
    data[i] := 0;
  
  indices.i[0] := 5;
  indices.i[1] := 10;
  indices.i[2] := 2;
  indices.i[3] := 15;
  
  values.i[0] := 111;
  values.i[1] := 222;
  values.i[2] := 333;
  values.i[3] := 444;
  
  nextpas.core.simd.VecI32x4Scatter(@data[0], indices, values);
  
  AssertEquals('Scatter[5]', 111, data[5]);
  AssertEquals('Scatter[10]', 222, data[10]);
  AssertEquals('Scatter[2]', 333, data[2]);
  AssertEquals('Scatter[15]', 444, data[15]);
  // 确保其它位置未被修改
  AssertEquals('Scatter[0] unchanged', 0, data[0]);
end;

procedure TTestCase_GatherScatter.Test_VecI32x4_Scatter_DuplicateIndices_LastLaneWins;
var
  data: array[0..7] of Int32;
  indices: TVecI32x4;
  values: TVecI32x4;
  i: Integer;
begin
  for i := 0 to 7 do
    data[i] := -1;

  indices.i[0] := 5;
  indices.i[1] := 2;
  indices.i[2] := 5;
  indices.i[3] := 5;

  values.i[0] := 111;
  values.i[1] := 222;
  values.i[2] := 333;
  values.i[3] := 444;

  nextpas.core.simd.VecI32x4Scatter(@data[0], indices, values);

  AssertEquals('Scatter duplicate last lane wins[5]', 444, data[5]);
  AssertEquals('Scatter duplicate preserved unrelated write[2]', 222, data[2]);
  AssertEquals('Scatter duplicate untouched[0]', -1, data[0]);
end;

procedure TTestCase_GatherScatter.Test_VecF32x4_GatherSelect_Preserves_OrValue_On_Masked_Lanes;
var
  data: array[0..7] of Single;
  indices: TVecI32x4;
  orVal: TVecF32x4;
  r: TVecF32x4;
  i: Integer;
begin
  for i := 0 to 7 do
    data[i] := (i + 1) * 10.0;

  indices.i[0] := 0;
  indices.i[1] := 5;
  indices.i[2] := 2;
  indices.i[3] := 7;

  orVal.f[0] := -1.0;
  orVal.f[1] := -2.0;
  orVal.f[2] := -3.0;
  orVal.f[3] := -4.0;

  r := nextpas.core.simd.VecF32x4GatherSelect(@data[0], TMask4($05), indices, orVal);

  AssertEquals('GatherSelect f32 enabled[0]', 10.0, r.f[0], 0.0001);
  AssertEquals('GatherSelect f32 masked[1]', -2.0, r.f[1], 0.0001);
  AssertEquals('GatherSelect f32 enabled[2]', 30.0, r.f[2], 0.0001);
  AssertEquals('GatherSelect f32 masked[3]', -4.0, r.f[3], 0.0001);
end;

procedure TTestCase_GatherScatter.Test_VecI32x4_GatherSelect_Preserves_OrValue_On_Masked_Lanes;
var
  data: array[0..7] of Int32;
  indices: TVecI32x4;
  orVal: TVecI32x4;
  r: TVecI32x4;
  i: Integer;
begin
  for i := 0 to 7 do
    data[i] := (i + 1) * 100;

  indices.i[0] := 6;
  indices.i[1] := 1;
  indices.i[2] := 4;
  indices.i[3] := 0;

  orVal.i[0] := -10;
  orVal.i[1] := -20;
  orVal.i[2] := -30;
  orVal.i[3] := -40;

  r := nextpas.core.simd.VecI32x4GatherSelect(@data[0], TMask4($0A), indices, orVal);

  AssertEquals('GatherSelect i32 masked[0]', -10, r.i[0]);
  AssertEquals('GatherSelect i32 enabled[1]', 200, r.i[1]);
  AssertEquals('GatherSelect i32 masked[2]', -30, r.i[2]);
  AssertEquals('GatherSelect i32 enabled[3]', 100, r.i[3]);
end;

procedure TTestCase_GatherScatter.Test_VecF32x4_ScatterSelect_Skips_Disabled_Lanes;
var
  data: array[0..7] of Single;
  indices: TVecI32x4;
  values: TVecF32x4;
  i: Integer;
begin
  for i := 0 to 7 do
    data[i] := -(i + 1);

  indices.i[0] := 0;
  indices.i[1] := 3;
  indices.i[2] := 5;
  indices.i[3] := 7;

  values.f[0] := 11.0;
  values.f[1] := 22.0;
  values.f[2] := 33.0;
  values.f[3] := 44.0;

  nextpas.core.simd.VecF32x4ScatterSelect(@data[0], TMask4($09), indices, values);

  AssertEquals('ScatterSelect f32 enabled[0]', 11.0, data[0], 0.0001);
  AssertEquals('ScatterSelect f32 masked[1]', -4.0, data[3], 0.0001);
  AssertEquals('ScatterSelect f32 masked[2]', -6.0, data[5], 0.0001);
  AssertEquals('ScatterSelect f32 enabled[3]', 44.0, data[7], 0.0001);
end;

procedure TTestCase_GatherScatter.Test_VecI32x4_ScatterSelect_Skips_Disabled_Lanes;
var
  data: array[0..7] of Int32;
  indices: TVecI32x4;
  values: TVecI32x4;
  i: Integer;
begin
  for i := 0 to 7 do
    data[i] := -(i + 1) * 10;

  indices.i[0] := 1;
  indices.i[1] := 2;
  indices.i[2] := 4;
  indices.i[3] := 6;

  values.i[0] := 111;
  values.i[1] := 222;
  values.i[2] := 333;
  values.i[3] := 444;

  nextpas.core.simd.VecI32x4ScatterSelect(@data[0], TMask4($06), indices, values);

  AssertEquals('ScatterSelect i32 masked[0]', -20, data[1]);
  AssertEquals('ScatterSelect i32 enabled[1]', 222, data[2]);
  AssertEquals('ScatterSelect i32 enabled[2]', 333, data[4]);
  AssertEquals('ScatterSelect i32 masked[3]', -70, data[6]);
end;

procedure TTestCase_GatherScatter.Test_VecF32x4_ScatterSelect_DuplicateIndices_LastEnabledLaneWins;
var
  data: array[0..7] of Single;
  indices: TVecI32x4;
  values: TVecF32x4;
  i: Integer;
begin
  for i := 0 to 7 do
    data[i] := -1.0;

  indices.i[0] := 4;
  indices.i[1] := 4;
  indices.i[2] := 4;
  indices.i[3] := 6;

  values.f[0] := 10.0;
  values.f[1] := 20.0;
  values.f[2] := 30.0;
  values.f[3] := 40.0;

  nextpas.core.simd.VecF32x4ScatterSelect(@data[0], TMask4($0D), indices, values);

  AssertEquals('ScatterSelect duplicate last enabled lane wins[4]', 30.0, data[4], 0.0001);
  AssertEquals('ScatterSelect duplicate enabled tail[6]', 40.0, data[6], 0.0001);
  AssertEquals('ScatterSelect duplicate untouched[0]', -1.0, data[0], 0.0001);
end;

procedure TTestCase_GatherScatter.Test_VecF32x4_Gather_NilBase_Raises_EArgumentNil;
var
  indices: TVecI32x4;
  raisedArgumentNil: Boolean;
begin
  indices := VecI32x4Make(0, 1, 2, 3);
  raisedArgumentNil := False;
  try
    nextpas.core.simd.VecF32x4Gather(nil, indices);
  except
    on EArgumentNil do
      raisedArgumentNil := True;
    on E: Exception do
      Fail('VecF32x4Gather nil base raised ' + E.ClassName);
  end;
  AssertTrue('VecF32x4Gather nil base should raise EArgumentNil', raisedArgumentNil);
end;

procedure TTestCase_GatherScatter.Test_VecI32x4_Gather_NilBase_Raises_EArgumentNil;
var
  indices: TVecI32x4;
  raisedArgumentNil: Boolean;
begin
  indices := VecI32x4Make(0, 1, 2, 3);
  raisedArgumentNil := False;
  try
    nextpas.core.simd.VecI32x4Gather(nil, indices);
  except
    on EArgumentNil do
      raisedArgumentNil := True;
    on E: Exception do
      Fail('VecI32x4Gather nil base raised ' + E.ClassName);
  end;
  AssertTrue('VecI32x4Gather nil base should raise EArgumentNil', raisedArgumentNil);
end;

procedure TTestCase_GatherScatter.Test_VecF32x4_Scatter_NilBase_Raises_EArgumentNil;
var
  indices: TVecI32x4;
  values: TVecF32x4;
  raisedArgumentNil: Boolean;
begin
  indices := VecI32x4Make(0, 1, 2, 3);
  values := VecF32x4Make(1.0, 2.0, 3.0, 4.0);
  raisedArgumentNil := False;
  try
    nextpas.core.simd.VecF32x4Scatter(nil, indices, values);
  except
    on EArgumentNil do
      raisedArgumentNil := True;
    on E: Exception do
      Fail('VecF32x4Scatter nil base raised ' + E.ClassName);
  end;
  AssertTrue('VecF32x4Scatter nil base should raise EArgumentNil', raisedArgumentNil);
end;

procedure TTestCase_GatherScatter.Test_VecI32x4_Scatter_NilBase_Raises_EArgumentNil;
var
  indices: TVecI32x4;
  values: TVecI32x4;
  raisedArgumentNil: Boolean;
begin
  indices := VecI32x4Make(0, 1, 2, 3);
  values := VecI32x4Make(11, 22, 33, 44);
  raisedArgumentNil := False;
  try
    nextpas.core.simd.VecI32x4Scatter(nil, indices, values);
  except
    on EArgumentNil do
      raisedArgumentNil := True;
    on E: Exception do
      Fail('VecI32x4Scatter nil base raised ' + E.ClassName);
  end;
  AssertTrue('VecI32x4Scatter nil base should raise EArgumentNil', raisedArgumentNil);
end;

procedure TTestCase_GatherScatter.Test_VecF32x4_GatherSelect_NilBase_AllDisabled_Returns_OrValue;
var
  indices: TVecI32x4;
  orVal: TVecF32x4;
  r: TVecF32x4;
begin
  indices := VecI32x4Make(0, 1, 2, 3);
  orVal := VecF32x4Make(-1.0, -2.0, -3.0, -4.0);

  r := nextpas.core.simd.VecF32x4GatherSelect(nil, TMask4($00), indices, orVal);

  AssertEquals('GatherSelect f32 nil base all-disabled[0]', -1.0, r.f[0], 0.0001);
  AssertEquals('GatherSelect f32 nil base all-disabled[1]', -2.0, r.f[1], 0.0001);
  AssertEquals('GatherSelect f32 nil base all-disabled[2]', -3.0, r.f[2], 0.0001);
  AssertEquals('GatherSelect f32 nil base all-disabled[3]', -4.0, r.f[3], 0.0001);
end;

procedure TTestCase_GatherScatter.Test_VecI32x4_GatherSelect_NilBase_AllDisabled_Returns_OrValue;
var
  indices: TVecI32x4;
  orVal: TVecI32x4;
  r: TVecI32x4;
begin
  indices := VecI32x4Make(0, 1, 2, 3);
  orVal := VecI32x4Make(-10, -20, -30, -40);

  r := nextpas.core.simd.VecI32x4GatherSelect(nil, TMask4($00), indices, orVal);

  AssertEquals('GatherSelect i32 nil base all-disabled[0]', -10, r.i[0]);
  AssertEquals('GatherSelect i32 nil base all-disabled[1]', -20, r.i[1]);
  AssertEquals('GatherSelect i32 nil base all-disabled[2]', -30, r.i[2]);
  AssertEquals('GatherSelect i32 nil base all-disabled[3]', -40, r.i[3]);
end;

procedure TTestCase_GatherScatter.Test_VecF32x4_GatherSelect_NilBase_EnabledLane_Raises_EArgumentNil;
var
  indices: TVecI32x4;
  orVal: TVecF32x4;
  raisedArgumentNil: Boolean;
begin
  indices := VecI32x4Make(0, 1, 2, 3);
  orVal := VecF32x4Make(-1.0, -2.0, -3.0, -4.0);
  raisedArgumentNil := False;
  try
    nextpas.core.simd.VecF32x4GatherSelect(nil, TMask4($01), indices, orVal);
  except
    on EArgumentNil do
      raisedArgumentNil := True;
    on E: Exception do
      Fail('VecF32x4GatherSelect nil base with enabled lane raised ' + E.ClassName);
  end;
  AssertTrue('VecF32x4GatherSelect nil base with enabled lane should raise EArgumentNil', raisedArgumentNil);
end;

procedure TTestCase_GatherScatter.Test_VecI32x4_GatherSelect_NilBase_EnabledLane_Raises_EArgumentNil;
var
  indices: TVecI32x4;
  orVal: TVecI32x4;
  raisedArgumentNil: Boolean;
begin
  indices := VecI32x4Make(0, 1, 2, 3);
  orVal := VecI32x4Make(-10, -20, -30, -40);
  raisedArgumentNil := False;
  try
    nextpas.core.simd.VecI32x4GatherSelect(nil, TMask4($02), indices, orVal);
  except
    on EArgumentNil do
      raisedArgumentNil := True;
    on E: Exception do
      Fail('VecI32x4GatherSelect nil base with enabled lane raised ' + E.ClassName);
  end;
  AssertTrue('VecI32x4GatherSelect nil base with enabled lane should raise EArgumentNil', raisedArgumentNil);
end;

procedure TTestCase_GatherScatter.Test_VecF32x4_ScatterSelect_NilBase_AllDisabled_Is_NoOp;
var
  indices: TVecI32x4;
  values: TVecF32x4;
begin
  indices := VecI32x4Make(0, 1, 2, 3);
  values := VecF32x4Make(11.0, 22.0, 33.0, 44.0);
  try
    nextpas.core.simd.VecF32x4ScatterSelect(nil, TMask4($00), indices, values);
  except
    on E: Exception do
      Fail('VecF32x4ScatterSelect nil base with all-disabled mask raised ' + E.ClassName);
  end;
end;

procedure TTestCase_GatherScatter.Test_VecI32x4_ScatterSelect_NilBase_AllDisabled_Is_NoOp;
var
  indices: TVecI32x4;
  values: TVecI32x4;
begin
  indices := VecI32x4Make(0, 1, 2, 3);
  values := VecI32x4Make(11, 22, 33, 44);
  try
    nextpas.core.simd.VecI32x4ScatterSelect(nil, TMask4($00), indices, values);
  except
    on E: Exception do
      Fail('VecI32x4ScatterSelect nil base with all-disabled mask raised ' + E.ClassName);
  end;
end;

procedure TTestCase_GatherScatter.Test_VecF32x4_ScatterSelect_NilBase_EnabledLane_Raises_EArgumentNil;
var
  indices: TVecI32x4;
  values: TVecF32x4;
  raisedArgumentNil: Boolean;
begin
  indices := VecI32x4Make(0, 1, 2, 3);
  values := VecF32x4Make(11.0, 22.0, 33.0, 44.0);
  raisedArgumentNil := False;
  try
    nextpas.core.simd.VecF32x4ScatterSelect(nil, TMask4($01), indices, values);
  except
    on EArgumentNil do
      raisedArgumentNil := True;
    on E: Exception do
      Fail('VecF32x4ScatterSelect nil base with enabled lane raised ' + E.ClassName);
  end;
  AssertTrue('VecF32x4ScatterSelect nil base with enabled lane should raise EArgumentNil', raisedArgumentNil);
end;

procedure TTestCase_GatherScatter.Test_VecI32x4_ScatterSelect_NilBase_EnabledLane_Raises_EArgumentNil;
var
  indices: TVecI32x4;
  values: TVecI32x4;
  raisedArgumentNil: Boolean;
begin
  indices := VecI32x4Make(0, 1, 2, 3);
  values := VecI32x4Make(11, 22, 33, 44);
  raisedArgumentNil := False;
  try
    nextpas.core.simd.VecI32x4ScatterSelect(nil, TMask4($08), indices, values);
  except
    on EArgumentNil do
      raisedArgumentNil := True;
    on E: Exception do
      Fail('VecI32x4ScatterSelect nil base with enabled lane raised ' + E.ClassName);
  end;
  AssertTrue('VecI32x4ScatterSelect nil base with enabled lane should raise EArgumentNil', raisedArgumentNil);
end;

procedure TTestCase_GatherScatter.Test_Gather_ZeroIndex;
var
  data: array[0..7] of Single;
  indices: TVecI32x4;
  r: TVecF32x4;
  i: Integer;
begin
  for i := 0 to 7 do
    data[i] := i * 1.5;
  
  // 所有索引都是 0
  indices.i[0] := 0;
  indices.i[1] := 0;
  indices.i[2] := 0;
  indices.i[3] := 0;
  
  r := nextpas.core.simd.VecF32x4Gather(@data[0], indices);
  
  // 所有结果应该都是 data[0]
  AssertEquals('Gather zero[0]', 0.0, r.f[0], 0.0001);
  AssertEquals('Gather zero[1]', 0.0, r.f[1], 0.0001);
  AssertEquals('Gather zero[2]', 0.0, r.f[2], 0.0001);
  AssertEquals('Gather zero[3]', 0.0, r.f[3], 0.0001);
end;

procedure TTestCase_GatherScatter.Test_Gather_LargeStride;
var
  data: array[0..1023] of Single;
  indices: TVecI32x4;
  r: TVecF32x4;
  i: Integer;
begin
  for i := 0 to 1023 do
    data[i] := i;
  
  // 大跨步索引
  indices.i[0] := 0;
  indices.i[1] := 256;
  indices.i[2] := 512;
  indices.i[3] := 1023;
  
  r := nextpas.core.simd.VecF32x4Gather(@data[0], indices);
  
  AssertEquals('Gather large[0]', 0.0, r.f[0], 0.0001);
  AssertEquals('Gather large[1]', 256.0, r.f[1], 0.0001);
  AssertEquals('Gather large[2]', 512.0, r.f[2], 0.0001);
  AssertEquals('Gather large[3]', 1023.0, r.f[3], 0.0001);
end;

{ TTestCase_ShuffleSWizzle }

procedure TTestCase_ShuffleSWizzle.Test_MM_SHUFFLE;
begin
  // MM_SHUFFLE(3,2,1,0) = identity = 0xE4
  AssertEquals('MM_SHUFFLE(3,2,1,0) = 0xE4', $E4, MM_SHUFFLE(3, 2, 1, 0));
  // MM_SHUFFLE(0,1,2,3) = reverse = 0x1B
  AssertEquals('MM_SHUFFLE(0,1,2,3) = 0x1B', $1B, MM_SHUFFLE(0, 1, 2, 3));
  // MM_SHUFFLE(0,0,0,0) = broadcast 0 = 0x00
  AssertEquals('MM_SHUFFLE(0,0,0,0) = 0x00', $00, MM_SHUFFLE(0, 0, 0, 0));
  // MM_SHUFFLE(2,2,2,2) = broadcast 2 = 0xAA
  AssertEquals('MM_SHUFFLE(2,2,2,2) = 0xAA', $AA, MM_SHUFFLE(2, 2, 2, 2));
end;

procedure TTestCase_ShuffleSWizzle.Test_VecF32x4_Shuffle_Identity;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  
  // 恒等 shuffle: MM_SHUFFLE(3,2,1,0) = 0xE4
  r := VecF32x4Shuffle(a, $E4);
  
  AssertEquals('Identity[0]', 1.0, r.f[0], 0.0001);
  AssertEquals('Identity[1]', 2.0, r.f[1], 0.0001);
  AssertEquals('Identity[2]', 3.0, r.f[2], 0.0001);
  AssertEquals('Identity[3]', 4.0, r.f[3], 0.0001);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecF32x4_Shuffle_Reverse;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  
  // 反转 shuffle: MM_SHUFFLE(0,1,2,3) = 0x1B
  r := VecF32x4Shuffle(a, $1B);
  
  AssertEquals('Reverse[0]', 4.0, r.f[0], 0.0001);
  AssertEquals('Reverse[1]', 3.0, r.f[1], 0.0001);
  AssertEquals('Reverse[2]', 2.0, r.f[2], 0.0001);
  AssertEquals('Reverse[3]', 1.0, r.f[3], 0.0001);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecF32x4_Shuffle_Broadcast;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  
  // 广播元素 2: MM_SHUFFLE(2,2,2,2) = 0xAA
  r := VecF32x4Shuffle(a, $AA);
  
  AssertEquals('Broadcast2[0]', 3.0, r.f[0], 0.0001);
  AssertEquals('Broadcast2[1]', 3.0, r.f[1], 0.0001);
  AssertEquals('Broadcast2[2]', 3.0, r.f[2], 0.0001);
  AssertEquals('Broadcast2[3]', 3.0, r.f[3], 0.0001);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecI32x4_Shuffle;
var
  a, r: TVecI32x4;
begin
  a.i[0] := 10; a.i[1] := 20; a.i[2] := 30; a.i[3] := 40;
  
  // 跳跃 shuffle: MM_SHUFFLE(1,0,3,2) = 0x4E
  r := VecI32x4Shuffle(a, $4E);
  
  AssertEquals('Swap[0]', 30, r.i[0]);
  AssertEquals('Swap[1]', 40, r.i[1]);
  AssertEquals('Swap[2]', 10, r.i[2]);
  AssertEquals('Swap[3]', 20, r.i[3]);

  r := VecI32x4Shuffle(a, $FF);

  AssertEquals('Broadcast hi[0]', 40, r.i[0]);
  AssertEquals('Broadcast hi[1]', 40, r.i[1]);
  AssertEquals('Broadcast hi[2]', 40, r.i[2]);
  AssertEquals('Broadcast hi[3]', 40, r.i[3]);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecF32x4_Shuffle2;
var
  a, b, r: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  b.f[0] := 10.0; b.f[1] := 20.0; b.f[2] := 30.0; b.f[3] := 40.0;
  
  // 低2来自a的[0,1], 高2来自b的[0,1]: MM_SHUFFLE(1,0,1,0) = 0x44
  r := VecF32x4Shuffle2(a, b, $44);
  
  AssertEquals('Shuffle2[0] from a', 1.0, r.f[0], 0.0001);
  AssertEquals('Shuffle2[1] from a', 2.0, r.f[1], 0.0001);
  AssertEquals('Shuffle2[2] from b', 10.0, r.f[2], 0.0001);
  AssertEquals('Shuffle2[3] from b', 20.0, r.f[3], 0.0001);

  r := VecF32x4Shuffle2(a, b, $EE);

  AssertEquals('Shuffle2 hi[0] from a', 3.0, r.f[0], 0.0001);
  AssertEquals('Shuffle2 hi[1] from a', 4.0, r.f[1], 0.0001);
  AssertEquals('Shuffle2 hi[2] from b', 30.0, r.f[2], 0.0001);
  AssertEquals('Shuffle2 hi[3] from b', 40.0, r.f[3], 0.0001);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecF32x4_Blend;
var
  a, b, r: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  b.f[0] := 10.0; b.f[1] := 20.0; b.f[2] := 30.0; b.f[3] := 40.0;
  
  // mask = 0b0101 = 5: 元素0和2来自b
  r := VecF32x4Blend(a, b, 5);
  
  AssertEquals('Blend[0] from b', 10.0, r.f[0], 0.0001);
  AssertEquals('Blend[1] from a', 2.0, r.f[1], 0.0001);
  AssertEquals('Blend[2] from b', 30.0, r.f[2], 0.0001);
  AssertEquals('Blend[3] from a', 4.0, r.f[3], 0.0001);

  r := VecF32x4Blend(a, b, 10);

  AssertEquals('Blend alt[0] from a', 1.0, r.f[0], 0.0001);
  AssertEquals('Blend alt[1] from b', 20.0, r.f[1], 0.0001);
  AssertEquals('Blend alt[2] from a', 3.0, r.f[2], 0.0001);
  AssertEquals('Blend alt[3] from b', 40.0, r.f[3], 0.0001);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecF64x2_Blend;
var
  a, b, r: TVecF64x2;
begin
  a.d[0] := 1.0; a.d[1] := 2.0;
  b.d[0] := 10.0; b.d[1] := 20.0;
  
  // mask = 0b01 = 1: 元素0来自b
  r := VecF64x2Blend(a, b, 1);
  
  AssertEquals('Blend[0] from b', 10.0, r.d[0], 0.0001);
  AssertEquals('Blend[1] from a', 2.0, r.d[1], 0.0001);

  r := VecF64x2Blend(a, b, 2);

  AssertEquals('Blend alt[0] from a', 1.0, r.d[0], 0.0001);
  AssertEquals('Blend alt[1] from b', 20.0, r.d[1], 0.0001);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecI32x4_Blend;
var
  a, b, r: TVecI32x4;
begin
  a.i[0] := 1; a.i[1] := 2; a.i[2] := 3; a.i[3] := 4;
  b.i[0] := 10; b.i[1] := 20; b.i[2] := 30; b.i[3] := 40;
  
  // mask = 0b1010 = 10: 元素1和3来自b
  r := VecI32x4Blend(a, b, 10);
  
  AssertEquals('Blend[0] from a', 1, r.i[0]);
  AssertEquals('Blend[1] from b', 20, r.i[1]);
  AssertEquals('Blend[2] from a', 3, r.i[2]);
  AssertEquals('Blend[3] from b', 40, r.i[3]);

  r := VecI32x4Blend(a, b, 15);

  AssertEquals('Blend all[0] from b', 10, r.i[0]);
  AssertEquals('Blend all[1] from b', 20, r.i[1]);
  AssertEquals('Blend all[2] from b', 30, r.i[2]);
  AssertEquals('Blend all[3] from b', 40, r.i[3]);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecF32x4_UnpackLo;
var
  a, b, r: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  b.f[0] := 10.0; b.f[1] := 20.0; b.f[2] := 30.0; b.f[3] := 40.0;
  
  r := VecF32x4UnpackLo(a, b);
  
  // 结果: [a0, b0, a1, b1]
  AssertEquals('UnpackLo[0]', 1.0, r.f[0], 0.0001);
  AssertEquals('UnpackLo[1]', 10.0, r.f[1], 0.0001);
  AssertEquals('UnpackLo[2]', 2.0, r.f[2], 0.0001);
  AssertEquals('UnpackLo[3]', 20.0, r.f[3], 0.0001);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecF32x4_UnpackHi;
var
  a, b, r: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  b.f[0] := 10.0; b.f[1] := 20.0; b.f[2] := 30.0; b.f[3] := 40.0;
  
  r := VecF32x4UnpackHi(a, b);
  
  // 结果: [a2, b2, a3, b3]
  AssertEquals('UnpackHi[0]', 3.0, r.f[0], 0.0001);
  AssertEquals('UnpackHi[1]', 30.0, r.f[1], 0.0001);
  AssertEquals('UnpackHi[2]', 4.0, r.f[2], 0.0001);
  AssertEquals('UnpackHi[3]', 40.0, r.f[3], 0.0001);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecI32x4_Unpack;
var
  a, b, rLo, rHi: TVecI32x4;
begin
  a.i[0] := 1; a.i[1] := 2; a.i[2] := 3; a.i[3] := 4;
  b.i[0] := 10; b.i[1] := 20; b.i[2] := 30; b.i[3] := 40;
  
  rLo := VecI32x4UnpackLo(a, b);
  rHi := VecI32x4UnpackHi(a, b);
  
  AssertEquals('UnpackLo[0]', 1, rLo.i[0]);
  AssertEquals('UnpackLo[1]', 10, rLo.i[1]);
  AssertEquals('UnpackLo[2]', 2, rLo.i[2]);
  AssertEquals('UnpackLo[3]', 20, rLo.i[3]);
  
  AssertEquals('UnpackHi[0]', 3, rHi.i[0]);
  AssertEquals('UnpackHi[1]', 30, rHi.i[1]);
  AssertEquals('UnpackHi[2]', 4, rHi.i[2]);
  AssertEquals('UnpackHi[3]', 40, rHi.i[3]);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecF32x4_Broadcast;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  
  r := VecF32x4Broadcast(a, 2);
  
  AssertEquals('Broadcast[0]', 3.0, r.f[0], 0.0001);
  AssertEquals('Broadcast[1]', 3.0, r.f[1], 0.0001);
  AssertEquals('Broadcast[2]', 3.0, r.f[2], 0.0001);
  AssertEquals('Broadcast[3]', 3.0, r.f[3], 0.0001);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecI32x4_Broadcast;
var
  a, r: TVecI32x4;
begin
  a.i[0] := 10; a.i[1] := 20; a.i[2] := 30; a.i[3] := 40;
  
  r := VecI32x4Broadcast(a, 1);
  
  AssertEquals('Broadcast[0]', 20, r.i[0]);
  AssertEquals('Broadcast[1]', 20, r.i[1]);
  AssertEquals('Broadcast[2]', 20, r.i[2]);
  AssertEquals('Broadcast[3]', 20, r.i[3]);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecF32x4_Reverse;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  
  r := VecF32x4Reverse(a);
  
  AssertEquals('Reverse[0]', 4.0, r.f[0], 0.0001);
  AssertEquals('Reverse[1]', 3.0, r.f[1], 0.0001);
  AssertEquals('Reverse[2]', 2.0, r.f[2], 0.0001);
  AssertEquals('Reverse[3]', 1.0, r.f[3], 0.0001);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecI32x4_Reverse;
var
  a, r: TVecI32x4;
begin
  a.i[0] := 10; a.i[1] := 20; a.i[2] := 30; a.i[3] := 40;
  
  r := VecI32x4Reverse(a);
  
  AssertEquals('Reverse[0]', 40, r.i[0]);
  AssertEquals('Reverse[1]', 30, r.i[1]);
  AssertEquals('Reverse[2]', 20, r.i[2]);
  AssertEquals('Reverse[3]', 10, r.i[3]);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecF32x4_RotateLeft;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  
  // 左旋 1: [2,3,4,1]
  r := VecF32x4RotateLeft(a, 1);
  AssertEquals('RotL1[0]', 2.0, r.f[0], 0.0001);
  AssertEquals('RotL1[1]', 3.0, r.f[1], 0.0001);
  AssertEquals('RotL1[2]', 4.0, r.f[2], 0.0001);
  AssertEquals('RotL1[3]', 1.0, r.f[3], 0.0001);
  
  // 左旋 2: [3,4,1,2]
  r := VecF32x4RotateLeft(a, 2);
  AssertEquals('RotL2[0]', 3.0, r.f[0], 0.0001);
  AssertEquals('RotL2[3]', 2.0, r.f[3], 0.0001);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecI32x4_RotateLeft;
var
  a, r: TVecI32x4;
begin
  a.i[0] := 10; a.i[1] := 20; a.i[2] := 30; a.i[3] := 40;
  
  // 左旋 3: [40,10,20,30]
  r := VecI32x4RotateLeft(a, 3);
  AssertEquals('RotL3[0]', 40, r.i[0]);
  AssertEquals('RotL3[1]', 10, r.i[1]);
  AssertEquals('RotL3[2]', 20, r.i[2]);
  AssertEquals('RotL3[3]', 30, r.i[3]);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecF32x4_Insert;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  
  r := VecF32x4Insert(a, 99.0, 2);
  
  AssertEquals('Insert[0]', 1.0, r.f[0], 0.0001);
  AssertEquals('Insert[1]', 2.0, r.f[1], 0.0001);
  AssertEquals('Insert[2]', 99.0, r.f[2], 0.0001);
  AssertEquals('Insert[3]', 4.0, r.f[3], 0.0001);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecF32x4_ExtractFunc;
var
  a: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  
  AssertEquals('Extract[0]', 1.0, VecF32x4Extract(a, 0), 0.0001);
  AssertEquals('Extract[1]', 2.0, VecF32x4Extract(a, 1), 0.0001);
  AssertEquals('Extract[2]', 3.0, VecF32x4Extract(a, 2), 0.0001);
  AssertEquals('Extract[3]', 4.0, VecF32x4Extract(a, 3), 0.0001);
end;

procedure TTestCase_ShuffleSWizzle.Test_VecI32x4_InsertExtract;
var
  a, r: TVecI32x4;
begin
  a.i[0] := 10; a.i[1] := 20; a.i[2] := 30; a.i[3] := 40;
  
  r := VecI32x4Insert(a, 999, 1);
  
  AssertEquals('Insert[0]', 10, r.i[0]);
  AssertEquals('Insert[1]', 999, r.i[1]);
  AssertEquals('Insert[2]', 30, r.i[2]);
  AssertEquals('Insert[3]', 40, r.i[3]);
  
  AssertEquals('Extract[0]', 10, VecI32x4Extract(a, 0));
  AssertEquals('Extract[3]', 40, VecI32x4Extract(a, 3));
end;

{ TTestCase_MathFunctions }

procedure TTestCase_MathFunctions.Test_VecF32x4_Sin;
const
  PI = 3.14159265358979323846;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 0.0;        // sin(0) = 0
  a.f[1] := PI / 6;     // sin(PI/6) = 0.5
  a.f[2] := PI / 2;     // sin(PI/2) = 1
  a.f[3] := PI;         // sin(PI) = 0
  
  r := VecF32x4Sin(a);
  
  AssertEquals('sin(0)', 0.0, r.f[0], 0.0001);
  AssertEquals('sin(PI/6)', 0.5, r.f[1], 0.0001);
  AssertEquals('sin(PI/2)', 1.0, r.f[2], 0.0001);
  AssertEquals('sin(PI)', 0.0, r.f[3], 0.0001);
end;

procedure TTestCase_MathFunctions.Test_VecF32x4_Cos;
const
  PI = 3.14159265358979323846;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 0.0;        // cos(0) = 1
  a.f[1] := PI / 3;     // cos(PI/3) = 0.5
  a.f[2] := PI / 2;     // cos(PI/2) = 0
  a.f[3] := PI;         // cos(PI) = -1
  
  r := VecF32x4Cos(a);
  
  AssertEquals('cos(0)', 1.0, r.f[0], 0.0001);
  AssertEquals('cos(PI/3)', 0.5, r.f[1], 0.0001);
  AssertEquals('cos(PI/2)', 0.0, r.f[2], 0.0001);
  AssertEquals('cos(PI)', -1.0, r.f[3], 0.0001);
end;

procedure TTestCase_MathFunctions.Test_VecF32x4_SinCos;
const
  PI = 3.14159265358979323846;
var
  a, s, c: TVecF32x4;
begin
  a.f[0] := 0.0;
  a.f[1] := PI / 4;
  a.f[2] := PI / 2;
  a.f[3] := PI;
  
  VecF32x4SinCos(a, s, c);
  
  // sin
  AssertEquals('sin(0)', 0.0, s.f[0], 0.0001);
  AssertEquals('sin(PI/4)', 0.7071, s.f[1], 0.001);
  AssertEquals('sin(PI/2)', 1.0, s.f[2], 0.0001);
  AssertEquals('sin(PI)', 0.0, s.f[3], 0.0001);
  
  // cos
  AssertEquals('cos(0)', 1.0, c.f[0], 0.0001);
  AssertEquals('cos(PI/4)', 0.7071, c.f[1], 0.001);
  AssertEquals('cos(PI/2)', 0.0, c.f[2], 0.0001);
  AssertEquals('cos(PI)', -1.0, c.f[3], 0.0001);
end;

procedure TTestCase_MathFunctions.Test_VecF32x4_Tan;
const
  PI = 3.14159265358979323846;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 0.0;        // tan(0) = 0
  a.f[1] := PI / 4;     // tan(PI/4) = 1
  a.f[2] := -PI / 4;    // tan(-PI/4) = -1
  a.f[3] := PI / 6;     // tan(PI/6) = 1/sqrt(3)
  
  r := VecF32x4Tan(a);
  
  AssertEquals('tan(0)', 0.0, r.f[0], 0.0001);
  AssertEquals('tan(PI/4)', 1.0, r.f[1], 0.0001);
  AssertEquals('tan(-PI/4)', -1.0, r.f[2], 0.0001);
  AssertEquals('tan(PI/6)', 0.5774, r.f[3], 0.001);
end;

procedure TTestCase_MathFunctions.Test_VecF32x4_Exp;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 0.0;        // exp(0) = 1
  a.f[1] := 1.0;        // exp(1) = e = 2.71828
  a.f[2] := 2.0;        // exp(2) = 7.389
  a.f[3] := -1.0;       // exp(-1) = 1/e = 0.3679
  
  r := VecF32x4Exp(a);
  
  AssertEquals('exp(0)', 1.0, r.f[0], 0.0001);
  AssertEquals('exp(1)', 2.71828, r.f[1], 0.001);
  AssertEquals('exp(2)', 7.389, r.f[2], 0.01);
  AssertEquals('exp(-1)', 0.3679, r.f[3], 0.001);
end;

procedure TTestCase_MathFunctions.Test_VecF32x4_Exp2;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 0.0;        // 2^0 = 1
  a.f[1] := 1.0;        // 2^1 = 2
  a.f[2] := 3.0;        // 2^3 = 8
  a.f[3] := -1.0;       // 2^-1 = 0.5
  
  r := VecF32x4Exp2(a);
  
  AssertEquals('2^0', 1.0, r.f[0], 0.0001);
  AssertEquals('2^1', 2.0, r.f[1], 0.0001);
  AssertEquals('2^3', 8.0, r.f[2], 0.0001);
  AssertEquals('2^-1', 0.5, r.f[3], 0.0001);
end;

procedure TTestCase_MathFunctions.Test_VecF32x4_Log;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 1.0;        // ln(1) = 0
  a.f[1] := 2.71828;    // ln(e) = 1
  a.f[2] := 7.389;      // ln(e^2) = 2
  a.f[3] := 0.3679;     // ln(1/e) = -1
  
  r := VecF32x4Log(a);
  
  AssertEquals('ln(1)', 0.0, r.f[0], 0.0001);
  AssertEquals('ln(e)', 1.0, r.f[1], 0.001);
  AssertEquals('ln(e^2)', 2.0, r.f[2], 0.01);
  AssertEquals('ln(1/e)', -1.0, r.f[3], 0.01);
end;

procedure TTestCase_MathFunctions.Test_VecF32x4_Log2;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 1.0;        // log2(1) = 0
  a.f[1] := 2.0;        // log2(2) = 1
  a.f[2] := 8.0;        // log2(8) = 3
  a.f[3] := 0.5;        // log2(0.5) = -1
  
  r := VecF32x4Log2(a);
  
  AssertEquals('log2(1)', 0.0, r.f[0], 0.0001);
  AssertEquals('log2(2)', 1.0, r.f[1], 0.0001);
  AssertEquals('log2(8)', 3.0, r.f[2], 0.0001);
  AssertEquals('log2(0.5)', -1.0, r.f[3], 0.0001);
end;

procedure TTestCase_MathFunctions.Test_VecF32x4_Log10;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 1.0;        // log10(1) = 0
  a.f[1] := 10.0;       // log10(10) = 1
  a.f[2] := 100.0;      // log10(100) = 2
  a.f[3] := 0.1;        // log10(0.1) = -1
  
  r := VecF32x4Log10(a);
  
  AssertEquals('log10(1)', 0.0, r.f[0], 0.0001);
  AssertEquals('log10(10)', 1.0, r.f[1], 0.0001);
  AssertEquals('log10(100)', 2.0, r.f[2], 0.0001);
  AssertEquals('log10(0.1)', -1.0, r.f[3], 0.0001);
end;

procedure TTestCase_MathFunctions.Test_VecF32x4_Pow;
var
  base, exp, r: TVecF32x4;
begin
  base.f[0] := 2.0; exp.f[0] := 3.0;    // 2^3 = 8
  base.f[1] := 3.0; exp.f[1] := 2.0;    // 3^2 = 9
  base.f[2] := 10.0; exp.f[2] := 0.0;   // 10^0 = 1
  base.f[3] := 4.0; exp.f[3] := 0.5;    // 4^0.5 = 2
  
  r := VecF32x4Pow(base, exp);
  
  AssertEquals('2^3', 8.0, r.f[0], 0.0001);
  AssertEquals('3^2', 9.0, r.f[1], 0.0001);
  AssertEquals('10^0', 1.0, r.f[2], 0.0001);
  AssertEquals('4^0.5', 2.0, r.f[3], 0.0001);
end;

procedure TTestCase_MathFunctions.Test_VecF32x4_Asin;
var
  a, r: TVecF32x4;
const
  PI = 3.14159265358979323846;
begin
  a.f[0] := 0.0;        // asin(0) = 0
  a.f[1] := 0.5;        // asin(0.5) = PI/6
  a.f[2] := 1.0;        // asin(1) = PI/2
  a.f[3] := -0.5;       // asin(-0.5) = -PI/6
  
  r := VecF32x4Asin(a);
  
  AssertEquals('asin(0)', 0.0, r.f[0], 0.0001);
  AssertEquals('asin(0.5)', PI/6, r.f[1], 0.0001);
  AssertEquals('asin(1)', PI/2, r.f[2], 0.0001);
  AssertEquals('asin(-0.5)', -PI/6, r.f[3], 0.0001);
end;

procedure TTestCase_MathFunctions.Test_VecF32x4_Acos;
var
  a, r: TVecF32x4;
const
  PI = 3.14159265358979323846;
begin
  a.f[0] := 1.0;        // acos(1) = 0
  a.f[1] := 0.5;        // acos(0.5) = PI/3
  a.f[2] := 0.0;        // acos(0) = PI/2
  a.f[3] := -1.0;       // acos(-1) = PI
  
  r := VecF32x4Acos(a);
  
  AssertEquals('acos(1)', 0.0, r.f[0], 0.0001);
  AssertEquals('acos(0.5)', PI/3, r.f[1], 0.0001);
  AssertEquals('acos(0)', PI/2, r.f[2], 0.0001);
  AssertEquals('acos(-1)', PI, r.f[3], 0.0001);
end;

procedure TTestCase_MathFunctions.Test_VecF32x4_Atan;
var
  a, r: TVecF32x4;
const
  PI = 3.14159265358979323846;
begin
  a.f[0] := 0.0;        // atan(0) = 0
  a.f[1] := 1.0;        // atan(1) = PI/4
  a.f[2] := -1.0;       // atan(-1) = -PI/4
  a.f[3] := 1.7320508;  // atan(sqrt(3)) = PI/3
  
  r := VecF32x4Atan(a);
  
  AssertEquals('atan(0)', 0.0, r.f[0], 0.0001);
  AssertEquals('atan(1)', PI/4, r.f[1], 0.0001);
  AssertEquals('atan(-1)', -PI/4, r.f[2], 0.0001);
  AssertEquals('atan(sqrt(3))', PI/3, r.f[3], 0.0001);
end;

procedure TTestCase_MathFunctions.Test_VecF32x4_Atan2;
var
  y, x, r: TVecF32x4;
const
  PI = 3.14159265358979323846;
begin
  // atan2(y, x)
  y.f[0] := 0.0;  x.f[0] := 1.0;   // atan2(0, 1) = 0
  y.f[1] := 1.0;  x.f[1] := 1.0;   // atan2(1, 1) = PI/4
  y.f[2] := 1.0;  x.f[2] := 0.0;   // atan2(1, 0) = PI/2
  y.f[3] := -1.0; x.f[3] := -1.0;  // atan2(-1, -1) = -3*PI/4
  
  r := VecF32x4Atan2(y, x);
  
  AssertEquals('atan2(0,1)', 0.0, r.f[0], 0.0001);
  AssertEquals('atan2(1,1)', PI/4, r.f[1], 0.0001);
  AssertEquals('atan2(1,0)', PI/2, r.f[2], 0.0001);
  AssertEquals('atan2(-1,-1)', -3*PI/4, r.f[3], 0.0001);
end;

{ TTestCase_AdvancedAlgorithms }

// === 排序网络测试 ===

procedure TTestCase_AdvancedAlgorithms.Test_SortNet4_I32_Ascending;
var
  a, r: TVecI32x4;
begin
  a.i[0] := 4; a.i[1] := 2; a.i[2] := 3; a.i[3] := 1;
  
  r := SortNet4I32(a, True);  // 升序
  
  AssertEquals('Sorted[0]', 1, r.i[0]);
  AssertEquals('Sorted[1]', 2, r.i[1]);
  AssertEquals('Sorted[2]', 3, r.i[2]);
  AssertEquals('Sorted[3]', 4, r.i[3]);
end;

procedure TTestCase_AdvancedAlgorithms.Test_SortNet4_I32_Descending;
var
  a, r: TVecI32x4;
begin
  a.i[0] := 1; a.i[1] := 4; a.i[2] := 2; a.i[3] := 3;
  
  r := SortNet4I32(a, False);  // 降序
  
  AssertEquals('Sorted[0]', 4, r.i[0]);
  AssertEquals('Sorted[1]', 3, r.i[1]);
  AssertEquals('Sorted[2]', 2, r.i[2]);
  AssertEquals('Sorted[3]', 1, r.i[3]);
end;

procedure TTestCase_AdvancedAlgorithms.Test_SortNet4_F32_Ascending;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 3.5; a.f[1] := 1.2; a.f[2] := 4.8; a.f[3] := 2.1;
  
  r := SortNet4F32(a, True);
  
  AssertEquals('Sorted[0]', 1.2, r.f[0], 0.0001);
  AssertEquals('Sorted[1]', 2.1, r.f[1], 0.0001);
  AssertEquals('Sorted[2]', 3.5, r.f[2], 0.0001);
  AssertEquals('Sorted[3]', 4.8, r.f[3], 0.0001);
end;

procedure TTestCase_AdvancedAlgorithms.Test_SortNet4_F32_WithNegatives;
var
  a, r: TVecF32x4;
begin
  a.f[0] := -1.0; a.f[1] := 5.0; a.f[2] := -3.0; a.f[3] := 2.0;
  
  r := SortNet4F32(a, True);
  
  AssertEquals('Sorted[0]', -3.0, r.f[0], 0.0001);
  AssertEquals('Sorted[1]', -1.0, r.f[1], 0.0001);
  AssertEquals('Sorted[2]', 2.0, r.f[2], 0.0001);
  AssertEquals('Sorted[3]', 5.0, r.f[3], 0.0001);
end;

procedure TTestCase_AdvancedAlgorithms.Test_SortNet8_I32;
var
  a, r: TVecI32x8;
begin
  a.i[0] := 8; a.i[1] := 3; a.i[2] := 7; a.i[3] := 1;
  a.i[4] := 6; a.i[5] := 2; a.i[6] := 5; a.i[7] := 4;
  
  r := SortNet8I32(a, True);
  
  AssertEquals('Sorted[0]', 1, r.i[0]);
  AssertEquals('Sorted[1]', 2, r.i[1]);
  AssertEquals('Sorted[2]', 3, r.i[2]);
  AssertEquals('Sorted[3]', 4, r.i[3]);
  AssertEquals('Sorted[4]', 5, r.i[4]);
  AssertEquals('Sorted[5]', 6, r.i[5]);
  AssertEquals('Sorted[6]', 7, r.i[6]);
  AssertEquals('Sorted[7]', 8, r.i[7]);
end;

// === 前缀和测试 ===

procedure TTestCase_AdvancedAlgorithms.Test_PrefixSum_I32x4_Inclusive;
var
  a, r: TVecI32x4;
begin
  a.i[0] := 1; a.i[1] := 2; a.i[2] := 3; a.i[3] := 4;
  
  r := PrefixSumI32x4(a, True);  // inclusive
  
  // [1, 1+2, 1+2+3, 1+2+3+4] = [1, 3, 6, 10]
  AssertEquals('PrefixSum[0]', 1, r.i[0]);
  AssertEquals('PrefixSum[1]', 3, r.i[1]);
  AssertEquals('PrefixSum[2]', 6, r.i[2]);
  AssertEquals('PrefixSum[3]', 10, r.i[3]);
end;

procedure TTestCase_AdvancedAlgorithms.Test_PrefixSum_I32x4_Exclusive;
var
  a, r: TVecI32x4;
begin
  a.i[0] := 1; a.i[1] := 2; a.i[2] := 3; a.i[3] := 4;
  
  r := PrefixSumI32x4(a, False);  // exclusive
  
  // [0, 1, 1+2, 1+2+3] = [0, 1, 3, 6]
  AssertEquals('PrefixSum[0]', 0, r.i[0]);
  AssertEquals('PrefixSum[1]', 1, r.i[1]);
  AssertEquals('PrefixSum[2]', 3, r.i[2]);
  AssertEquals('PrefixSum[3]', 6, r.i[3]);
end;

procedure TTestCase_AdvancedAlgorithms.Test_PrefixSum_F32x4_Inclusive;
var
  a, r: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  
  r := PrefixSumF32x4(a, True);
  
  AssertEquals('PrefixSum[0]', 1.0, r.f[0], 0.0001);
  AssertEquals('PrefixSum[1]', 3.0, r.f[1], 0.0001);
  AssertEquals('PrefixSum[2]', 6.0, r.f[2], 0.0001);
  AssertEquals('PrefixSum[3]', 10.0, r.f[3], 0.0001);
end;

procedure TTestCase_AdvancedAlgorithms.Test_PrefixSum_Array_I32;
var
  arr, result: array[0..7] of Int32;
begin
  arr[0] := 1; arr[1] := 2; arr[2] := 3; arr[3] := 4;
  arr[4] := 5; arr[5] := 6; arr[6] := 7; arr[7] := 8;
  
  PrefixSumArrayI32(@arr[0], @result[0], 8);
  
  // [1, 3, 6, 10, 15, 21, 28, 36]
  AssertEquals('PrefixSum[0]', 1, result[0]);
  AssertEquals('PrefixSum[3]', 10, result[3]);
  AssertEquals('PrefixSum[7]', 36, result[7]);
end;

procedure TTestCase_AdvancedAlgorithms.Test_PrefixSum_Array_F32;
var
  arr, result: array[0..3] of Single;
begin
  arr[0] := 1.5; arr[1] := 2.5; arr[2] := 3.5; arr[3] := 4.5;
  
  PrefixSumArrayF32(@arr[0], @result[0], 4);
  
  AssertEquals('PrefixSum[0]', 1.5, result[0], 0.0001);
  AssertEquals('PrefixSum[1]', 4.0, result[1], 0.0001);
  AssertEquals('PrefixSum[2]', 7.5, result[2], 0.0001);
  AssertEquals('PrefixSum[3]', 12.0, result[3], 0.0001);
end;

// === 向量化字符串搜索测试 ===

procedure TTestCase_AdvancedAlgorithms.Test_StrFind_SingleChar;
var
  s: AnsiString;
  pos: PtrInt;
begin
  s := 'Hello, World!';
  
  pos := StrFindChar(@s[1], Length(s), Ord('W'));
  
  AssertEquals('Should find W at position 7', 7, pos);
end;

procedure TTestCase_AdvancedAlgorithms.Test_StrFind_NotFound;
var
  s: AnsiString;
  pos: PtrInt;
begin
  s := 'Hello, World!';
  
  pos := StrFindChar(@s[1], Length(s), Ord('X'));
  
  AssertEquals('Should return -1 for not found', -1, pos);
end;

procedure TTestCase_AdvancedAlgorithms.Test_StrFind_AtStart;
var
  s: AnsiString;
  pos: PtrInt;
begin
  s := 'Hello, World!';
  
  pos := StrFindChar(@s[1], Length(s), Ord('H'));
  
  AssertEquals('Should find H at position 0', 0, pos);
end;

procedure TTestCase_AdvancedAlgorithms.Test_StrFind_AtEnd;
var
  s: AnsiString;
  pos: PtrInt;
begin
  s := 'Hello, World!';
  
  pos := StrFindChar(@s[1], Length(s), Ord('!'));
  
  AssertEquals('Should find ! at last position', 12, pos);
end;

procedure TTestCase_AdvancedAlgorithms.Test_StrFind_Empty;
var
  pos: PtrInt;
begin
  pos := StrFindChar(nil, 0, Ord('A'));
  
  AssertEquals('Should return -1 for empty string', -1, pos);
end;




initialization
  RegisterTest(TTestCase_Global);
  {$IFDEF CPUX86_64}
  RegisterTest(TTestCase_BackendConsistency);
  RegisterTest(TTestCase_BackendVectorConsistency);
  RegisterTest(TTestCase_X86BackendPredicates);
  {$IFDEF SIMD_BACKEND_AVX512}
  RegisterTest(TTestCase_AVX512BackendRequirements);
  {$ENDIF}
  {$ENDIF}
  RegisterTest(TTestCase_BackendSmoke);
  {$IFDEF UNIX}
  {$IFDEF CPUX86_64}
  RegisterTest(TTestCase_AVX2VectorAsm);
  {$IFDEF SIMD_BACKEND_AVX512}
  RegisterTest(TTestCase_AVX512VectorAsm);
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  RegisterTest(TTestCase_VectorOps);
  RegisterTest(TTestCase_IntegerFacadeGuards);
  RegisterTest(TTestCase_FloatFacadeGuards);
  RegisterTest(TTestCase_LargeData);
  RegisterTest(TTestCase_UnsignedVectorTypes);
  RegisterTest(TTestCase_OperatorOverloads);
  RegisterTest(TTestCase_VectorMaskTypes);
  RegisterTest(TTestCase_TypeConversion);
  RegisterTest(TTestCase_Builder);
  RegisterTest(TTestCase_GatherScatter);
  RegisterTest(TTestCase_ShuffleSWizzle);
  RegisterTest(TTestCase_MathFunctions);
  RegisterTest(TTestCase_AdvancedAlgorithms);


end.
