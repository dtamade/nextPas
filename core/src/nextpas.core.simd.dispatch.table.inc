  TSimdDispatchTable = record
    // Backend information
    Backend: TSimdBackend;
    BackendInfo: TSimdBackendInfo;
    
    // Arithmetic operations - F32x4
    AddF32x4: function(const a, b: TVecF32x4): TVecF32x4;
    SubF32x4: function(const a, b: TVecF32x4): TVecF32x4;
    MulF32x4: function(const a, b: TVecF32x4): TVecF32x4;
    DivF32x4: function(const a, b: TVecF32x4): TVecF32x4;
    
    // Arithmetic operations - F32x8
    AddF32x8: function(const a, b: TVecF32x8): TVecF32x8;
    SubF32x8: function(const a, b: TVecF32x8): TVecF32x8;
    MulF32x8: function(const a, b: TVecF32x8): TVecF32x8;
    DivF32x8: function(const a, b: TVecF32x8): TVecF32x8;
    
    // Arithmetic operations - F64x2
    AddF64x2: function(const a, b: TVecF64x2): TVecF64x2;
    SubF64x2: function(const a, b: TVecF64x2): TVecF64x2;
    MulF64x2: function(const a, b: TVecF64x2): TVecF64x2;
    DivF64x2: function(const a, b: TVecF64x2): TVecF64x2;
    
    // Arithmetic operations - I32x4
    AddI32x4: function(const a, b: TVecI32x4): TVecI32x4;
    SubI32x4: function(const a, b: TVecI32x4): TVecI32x4;
    MulI32x4: function(const a, b: TVecI32x4): TVecI32x4;
    // Bitwise operations - I32x4
    AndI32x4: function(const a, b: TVecI32x4): TVecI32x4;
    OrI32x4: function(const a, b: TVecI32x4): TVecI32x4;
    XorI32x4: function(const a, b: TVecI32x4): TVecI32x4;
    NotI32x4: function(const a: TVecI32x4): TVecI32x4;
    AndNotI32x4: function(const a, b: TVecI32x4): TVecI32x4;
    // Shift operations - I32x4
    ShiftLeftI32x4: function(const a: TVecI32x4; count: Integer): TVecI32x4;
    ShiftRightI32x4: function(const a: TVecI32x4; count: Integer): TVecI32x4;
    ShiftRightArithI32x4: function(const a: TVecI32x4; count: Integer): TVecI32x4;
    // Comparison operations - I32x4
    CmpEqI32x4: function(const a, b: TVecI32x4): TMask4;
    CmpLtI32x4: function(const a, b: TVecI32x4): TMask4;
    CmpGtI32x4: function(const a, b: TVecI32x4): TMask4;
    CmpLeI32x4: function(const a, b: TVecI32x4): TMask4;
    CmpGeI32x4: function(const a, b: TVecI32x4): TMask4;
    CmpNeI32x4: function(const a, b: TVecI32x4): TMask4;
    // Min/Max operations - I32x4
    MinI32x4: function(const a, b: TVecI32x4): TVecI32x4;
    MaxI32x4: function(const a, b: TVecI32x4): TVecI32x4;

    // Arithmetic operations - I64x2 (P1.3)
    AddI64x2: function(const a, b: TVecI64x2): TVecI64x2;
    SubI64x2: function(const a, b: TVecI64x2): TVecI64x2;
    AndI64x2: function(const a, b: TVecI64x2): TVecI64x2;
    OrI64x2: function(const a, b: TVecI64x2): TVecI64x2;
    XorI64x2: function(const a, b: TVecI64x2): TVecI64x2;
    NotI64x2: function(const a: TVecI64x2): TVecI64x2;
    AndNotI64x2: function(const a, b: TVecI64x2): TVecI64x2;
    ShiftLeftI64x2: function(const a: TVecI64x2; count: Integer): TVecI64x2;
    ShiftRightI64x2: function(const a: TVecI64x2; count: Integer): TVecI64x2;
    ShiftRightArithI64x2: function(const a: TVecI64x2; count: Integer): TVecI64x2;
    // Comparison operations - I64x2
    CmpEqI64x2: function(const a, b: TVecI64x2): TMask2;
    CmpLtI64x2: function(const a, b: TVecI64x2): TMask2;
    CmpGtI64x2: function(const a, b: TVecI64x2): TMask2;
    CmpLeI64x2: function(const a, b: TVecI64x2): TMask2;
    CmpGeI64x2: function(const a, b: TVecI64x2): TMask2;
    CmpNeI64x2: function(const a, b: TVecI64x2): TMask2;
    MinI64x2: function(const a, b: TVecI64x2): TVecI64x2;
    MaxI64x2: function(const a, b: TVecI64x2): TVecI64x2;

    // Arithmetic operations - U64x2
    AddU64x2: function(const a, b: TVecU64x2): TVecU64x2;
    SubU64x2: function(const a, b: TVecU64x2): TVecU64x2;
    AndU64x2: function(const a, b: TVecU64x2): TVecU64x2;
    OrU64x2: function(const a, b: TVecU64x2): TVecU64x2;
    XorU64x2: function(const a, b: TVecU64x2): TVecU64x2;
    NotU64x2: function(const a: TVecU64x2): TVecU64x2;
    AndNotU64x2: function(const a, b: TVecU64x2): TVecU64x2;
    CmpEqU64x2: function(const a, b: TVecU64x2): TMask2;
    CmpLtU64x2: function(const a, b: TVecU64x2): TMask2;
    CmpGtU64x2: function(const a, b: TVecU64x2): TMask2;
    MinU64x2: function(const a, b: TVecU64x2): TVecU64x2;
    MaxU64x2: function(const a, b: TVecU64x2): TVecU64x2;

    // Arithmetic operations - F64x4 (256-bit AVX)
    AddF64x4: function(const a, b: TVecF64x4): TVecF64x4;
    SubF64x4: function(const a, b: TVecF64x4): TVecF64x4;
    MulF64x4: function(const a, b: TVecF64x4): TVecF64x4;
    DivF64x4: function(const a, b: TVecF64x4): TVecF64x4;

    // Arithmetic operations - I32x8 (256-bit AVX)
    AddI32x8: function(const a, b: TVecI32x8): TVecI32x8;
    SubI32x8: function(const a, b: TVecI32x8): TVecI32x8;
    MulI32x8: function(const a, b: TVecI32x8): TVecI32x8;
    AndI32x8: function(const a, b: TVecI32x8): TVecI32x8;
    OrI32x8: function(const a, b: TVecI32x8): TVecI32x8;
    XorI32x8: function(const a, b: TVecI32x8): TVecI32x8;
    NotI32x8: function(const a: TVecI32x8): TVecI32x8;
    AndNotI32x8: function(const a, b: TVecI32x8): TVecI32x8;
    // Shift operations - I32x8
    ShiftLeftI32x8: function(const a: TVecI32x8; count: Integer): TVecI32x8;
    ShiftRightI32x8: function(const a: TVecI32x8; count: Integer): TVecI32x8;
    ShiftRightArithI32x8: function(const a: TVecI32x8; count: Integer): TVecI32x8;
    // Comparison operations - I32x8
    CmpEqI32x8: function(const a, b: TVecI32x8): TMask8;
    CmpLtI32x8: function(const a, b: TVecI32x8): TMask8;
    CmpGtI32x8: function(const a, b: TVecI32x8): TMask8;
    CmpLeI32x8: function(const a, b: TVecI32x8): TMask8;
    CmpGeI32x8: function(const a, b: TVecI32x8): TMask8;
    CmpNeI32x8: function(const a, b: TVecI32x8): TMask8;
    // Min/Max operations - I32x8
    MinI32x8: function(const a, b: TVecI32x8): TVecI32x8;
    MaxI32x8: function(const a, b: TVecI32x8): TVecI32x8;

    // I64x4 Operations (256-bit AVX2)
    AddI64x4: function(const a, b: TVecI64x4): TVecI64x4;
    SubI64x4: function(const a, b: TVecI64x4): TVecI64x4;
    AndI64x4: function(const a, b: TVecI64x4): TVecI64x4;
    OrI64x4: function(const a, b: TVecI64x4): TVecI64x4;
    XorI64x4: function(const a, b: TVecI64x4): TVecI64x4;
    NotI64x4: function(const a: TVecI64x4): TVecI64x4;
    AndNotI64x4: function(const a, b: TVecI64x4): TVecI64x4;
    ShiftLeftI64x4: function(const a: TVecI64x4; count: Integer): TVecI64x4;
    ShiftRightI64x4: function(const a: TVecI64x4; count: Integer): TVecI64x4;
    ShiftRightArithI64x4: function(const a: TVecI64x4; count: Integer): TVecI64x4;
    CmpEqI64x4: function(const a, b: TVecI64x4): TMask4;
    CmpLtI64x4: function(const a, b: TVecI64x4): TMask4;
    CmpGtI64x4: function(const a, b: TVecI64x4): TMask4;
    CmpLeI64x4: function(const a, b: TVecI64x4): TMask4;
    CmpGeI64x4: function(const a, b: TVecI64x4): TMask4;
    CmpNeI64x4: function(const a, b: TVecI64x4): TMask4;
    // I64x4 Utility operations
    LoadI64x4: function(p: PInt64): TVecI64x4;
    StoreI64x4: procedure(p: PInt64; const a: TVecI64x4);
    SplatI64x4: function(value: Int64): TVecI64x4;
    ZeroI64x4: function: TVecI64x4;

    // U32x8 Operations (256-bit AVX2)
    AddU32x8: function(const a, b: TVecU32x8): TVecU32x8;
    SubU32x8: function(const a, b: TVecU32x8): TVecU32x8;
    MulU32x8: function(const a, b: TVecU32x8): TVecU32x8;
    AndU32x8: function(const a, b: TVecU32x8): TVecU32x8;
    OrU32x8: function(const a, b: TVecU32x8): TVecU32x8;
    XorU32x8: function(const a, b: TVecU32x8): TVecU32x8;
    NotU32x8: function(const a: TVecU32x8): TVecU32x8;
    AndNotU32x8: function(const a, b: TVecU32x8): TVecU32x8;
    ShiftLeftU32x8: function(const a: TVecU32x8; count: Integer): TVecU32x8;
    ShiftRightU32x8: function(const a: TVecU32x8; count: Integer): TVecU32x8;
    CmpEqU32x8: function(const a, b: TVecU32x8): TMask8;
    CmpLtU32x8: function(const a, b: TVecU32x8): TMask8;
    CmpGtU32x8: function(const a, b: TVecU32x8): TMask8;
    CmpLeU32x8: function(const a, b: TVecU32x8): TMask8;
    CmpGeU32x8: function(const a, b: TVecU32x8): TMask8;
    CmpNeU32x8: function(const a, b: TVecU32x8): TMask8;
    MinU32x8: function(const a, b: TVecU32x8): TVecU32x8;
    MaxU32x8: function(const a, b: TVecU32x8): TVecU32x8;

    // U64x4 Operations (256-bit AVX2)
    AddU64x4: function(const a, b: TVecU64x4): TVecU64x4;
    SubU64x4: function(const a, b: TVecU64x4): TVecU64x4;
    AndU64x4: function(const a, b: TVecU64x4): TVecU64x4;
    OrU64x4: function(const a, b: TVecU64x4): TVecU64x4;
    XorU64x4: function(const a, b: TVecU64x4): TVecU64x4;
    NotU64x4: function(const a: TVecU64x4): TVecU64x4;
    ShiftLeftU64x4: function(const a: TVecU64x4; count: Integer): TVecU64x4;
    ShiftRightU64x4: function(const a: TVecU64x4; count: Integer): TVecU64x4;
    CmpEqU64x4: function(const a, b: TVecU64x4): TMask4;
    CmpLtU64x4: function(const a, b: TVecU64x4): TMask4;
    CmpGtU64x4: function(const a, b: TVecU64x4): TMask4;
    CmpLeU64x4: function(const a, b: TVecU64x4): TMask4;
    CmpGeU64x4: function(const a, b: TVecU64x4): TMask4;
    CmpNeU64x4: function(const a, b: TVecU64x4): TMask4;

    // F64x4 Extended Math
    RcpF64x4: function(const a: TVecF64x4): TVecF64x4;

    // Arithmetic operations - I32x16 (512-bit AVX-512)
    AddI32x16: function(const a, b: TVecI32x16): TVecI32x16;
    SubI32x16: function(const a, b: TVecI32x16): TVecI32x16;
    MulI32x16: function(const a, b: TVecI32x16): TVecI32x16;
    AndI32x16: function(const a, b: TVecI32x16): TVecI32x16;
    OrI32x16: function(const a, b: TVecI32x16): TVecI32x16;
    XorI32x16: function(const a, b: TVecI32x16): TVecI32x16;
    NotI32x16: function(const a: TVecI32x16): TVecI32x16;
    AndNotI32x16: function(const a, b: TVecI32x16): TVecI32x16;
    // Shift operations - I32x16
    ShiftLeftI32x16: function(const a: TVecI32x16; count: Integer): TVecI32x16;
    ShiftRightI32x16: function(const a: TVecI32x16; count: Integer): TVecI32x16;
    ShiftRightArithI32x16: function(const a: TVecI32x16; count: Integer): TVecI32x16;
    // Comparison operations - I32x16
    CmpEqI32x16: function(const a, b: TVecI32x16): TMask16;
    CmpLtI32x16: function(const a, b: TVecI32x16): TMask16;
    CmpGtI32x16: function(const a, b: TVecI32x16): TMask16;
    CmpLeI32x16: function(const a, b: TVecI32x16): TMask16;
    CmpGeI32x16: function(const a, b: TVecI32x16): TMask16;
    CmpNeI32x16: function(const a, b: TVecI32x16): TMask16;
    // Min/Max operations - I32x16
    MinI32x16: function(const a, b: TVecI32x16): TVecI32x16;
    MaxI32x16: function(const a, b: TVecI32x16): TVecI32x16;

    // Arithmetic operations - I64x8 (512-bit AVX-512)
    AddI64x8: function(const a, b: TVecI64x8): TVecI64x8;
    SubI64x8: function(const a, b: TVecI64x8): TVecI64x8;
    // Bitwise operations - I64x8
    AndI64x8: function(const a, b: TVecI64x8): TVecI64x8;
    OrI64x8: function(const a, b: TVecI64x8): TVecI64x8;
    XorI64x8: function(const a, b: TVecI64x8): TVecI64x8;
    NotI64x8: function(const a: TVecI64x8): TVecI64x8;
    // Comparison operations - I64x8
    CmpEqI64x8: function(const a, b: TVecI64x8): TMask8;
    CmpLtI64x8: function(const a, b: TVecI64x8): TMask8;
    CmpGtI64x8: function(const a, b: TVecI64x8): TMask8;
    CmpLeI64x8: function(const a, b: TVecI64x8): TMask8;
    CmpGeI64x8: function(const a, b: TVecI64x8): TMask8;
    CmpNeI64x8: function(const a, b: TVecI64x8): TMask8;

    // Arithmetic operations - U32x16 (512-bit)
    AddU32x16: function(const a, b: TVecU32x16): TVecU32x16;
    SubU32x16: function(const a, b: TVecU32x16): TVecU32x16;
    MulU32x16: function(const a, b: TVecU32x16): TVecU32x16;
    AndU32x16: function(const a, b: TVecU32x16): TVecU32x16;
    OrU32x16: function(const a, b: TVecU32x16): TVecU32x16;
    XorU32x16: function(const a, b: TVecU32x16): TVecU32x16;
    NotU32x16: function(const a: TVecU32x16): TVecU32x16;
    AndNotU32x16: function(const a, b: TVecU32x16): TVecU32x16;
    ShiftLeftU32x16: function(const a: TVecU32x16; count: Integer): TVecU32x16;
    ShiftRightU32x16: function(const a: TVecU32x16; count: Integer): TVecU32x16;
    CmpEqU32x16: function(const a, b: TVecU32x16): TMask16;
    CmpLtU32x16: function(const a, b: TVecU32x16): TMask16;
    CmpGtU32x16: function(const a, b: TVecU32x16): TMask16;
    CmpLeU32x16: function(const a, b: TVecU32x16): TMask16;
    CmpGeU32x16: function(const a, b: TVecU32x16): TMask16;
    CmpNeU32x16: function(const a, b: TVecU32x16): TMask16;
    MinU32x16: function(const a, b: TVecU32x16): TVecU32x16;
    MaxU32x16: function(const a, b: TVecU32x16): TVecU32x16;

    // Arithmetic operations - U64x8 (512-bit)
    AddU64x8: function(const a, b: TVecU64x8): TVecU64x8;
    SubU64x8: function(const a, b: TVecU64x8): TVecU64x8;
    AndU64x8: function(const a, b: TVecU64x8): TVecU64x8;
    OrU64x8: function(const a, b: TVecU64x8): TVecU64x8;
    XorU64x8: function(const a, b: TVecU64x8): TVecU64x8;
    NotU64x8: function(const a: TVecU64x8): TVecU64x8;
    ShiftLeftU64x8: function(const a: TVecU64x8; count: Integer): TVecU64x8;
    ShiftRightU64x8: function(const a: TVecU64x8; count: Integer): TVecU64x8;
    CmpEqU64x8: function(const a, b: TVecU64x8): TMask8;
    CmpLtU64x8: function(const a, b: TVecU64x8): TMask8;
    CmpGtU64x8: function(const a, b: TVecU64x8): TMask8;
    CmpLeU64x8: function(const a, b: TVecU64x8): TMask8;
    CmpGeU64x8: function(const a, b: TVecU64x8): TMask8;
    CmpNeU64x8: function(const a, b: TVecU64x8): TMask8;

    // Arithmetic operations - I16x32 (512-bit)
    AddI16x32: function(const a, b: TVecI16x32): TVecI16x32;
    SubI16x32: function(const a, b: TVecI16x32): TVecI16x32;
    AndI16x32: function(const a, b: TVecI16x32): TVecI16x32;
    OrI16x32: function(const a, b: TVecI16x32): TVecI16x32;
    XorI16x32: function(const a, b: TVecI16x32): TVecI16x32;
    NotI16x32: function(const a: TVecI16x32): TVecI16x32;
    AndNotI16x32: function(const a, b: TVecI16x32): TVecI16x32;
    ShiftLeftI16x32: function(const a: TVecI16x32; count: Integer): TVecI16x32;
    ShiftRightI16x32: function(const a: TVecI16x32; count: Integer): TVecI16x32;
    ShiftRightArithI16x32: function(const a: TVecI16x32; count: Integer): TVecI16x32;
    CmpEqI16x32: function(const a, b: TVecI16x32): TMask32;
    CmpLtI16x32: function(const a, b: TVecI16x32): TMask32;
    CmpGtI16x32: function(const a, b: TVecI16x32): TMask32;
    MinI16x32: function(const a, b: TVecI16x32): TVecI16x32;
    MaxI16x32: function(const a, b: TVecI16x32): TVecI16x32;

    // Arithmetic operations - I8x64 (512-bit)
    AddI8x64: function(const a, b: TVecI8x64): TVecI8x64;
    SubI8x64: function(const a, b: TVecI8x64): TVecI8x64;
    AndI8x64: function(const a, b: TVecI8x64): TVecI8x64;
    OrI8x64: function(const a, b: TVecI8x64): TVecI8x64;
    XorI8x64: function(const a, b: TVecI8x64): TVecI8x64;
    NotI8x64: function(const a: TVecI8x64): TVecI8x64;
    AndNotI8x64: function(const a, b: TVecI8x64): TVecI8x64;
    CmpEqI8x64: function(const a, b: TVecI8x64): TMask64;
    CmpLtI8x64: function(const a, b: TVecI8x64): TMask64;
    CmpGtI8x64: function(const a, b: TVecI8x64): TMask64;
    MinI8x64: function(const a, b: TVecI8x64): TVecI8x64;
    MaxI8x64: function(const a, b: TVecI8x64): TVecI8x64;

    // Arithmetic operations - U8x64 (512-bit)
    AddU8x64: function(const a, b: TVecU8x64): TVecU8x64;
    SubU8x64: function(const a, b: TVecU8x64): TVecU8x64;
    AndU8x64: function(const a, b: TVecU8x64): TVecU8x64;
    OrU8x64: function(const a, b: TVecU8x64): TVecU8x64;
    XorU8x64: function(const a, b: TVecU8x64): TVecU8x64;
    NotU8x64: function(const a: TVecU8x64): TVecU8x64;
    CmpEqU8x64: function(const a, b: TVecU8x64): TMask64;
    CmpLtU8x64: function(const a, b: TVecU8x64): TMask64;
    CmpGtU8x64: function(const a, b: TVecU8x64): TMask64;
    MinU8x64: function(const a, b: TVecU8x64): TVecU8x64;
    MaxU8x64: function(const a, b: TVecU8x64): TVecU8x64;

    // Arithmetic operations - F32x16 (512-bit AVX-512)
    AddF32x16: function(const a, b: TVecF32x16): TVecF32x16;
    SubF32x16: function(const a, b: TVecF32x16): TVecF32x16;
    MulF32x16: function(const a, b: TVecF32x16): TVecF32x16;
    DivF32x16: function(const a, b: TVecF32x16): TVecF32x16;

    // Arithmetic operations - F64x8 (512-bit AVX-512)
    AddF64x8: function(const a, b: TVecF64x8): TVecF64x8;
    SubF64x8: function(const a, b: TVecF64x8): TVecF64x8;
    MulF64x8: function(const a, b: TVecF64x8): TVecF64x8;
    DivF64x8: function(const a, b: TVecF64x8): TVecF64x8;

    // Comparison operations
    CmpEqF32x4: function(const a, b: TVecF32x4): TMask4;
    CmpLtF32x4: function(const a, b: TVecF32x4): TMask4;
    CmpLeF32x4: function(const a, b: TVecF32x4): TMask4;
    CmpGtF32x4: function(const a, b: TVecF32x4): TMask4;
    CmpGeF32x4: function(const a, b: TVecF32x4): TMask4;
    CmpNeF32x4: function(const a, b: TVecF32x4): TMask4;

    // F64x2 比较操作 - 修复派发缺失
    CmpEqF64x2: function(const a, b: TVecF64x2): TMask2;
    CmpLtF64x2: function(const a, b: TVecF64x2): TMask2;
    CmpLeF64x2: function(const a, b: TVecF64x2): TMask2;
    CmpGtF64x2: function(const a, b: TVecF64x2): TMask2;
    CmpGeF64x2: function(const a, b: TVecF64x2): TMask2;
    CmpNeF64x2: function(const a, b: TVecF64x2): TMask2;

    // 512-bit floating-point comparisons
    // F32x16 (512-bit)
    CmpEqF32x16: function(const a, b: TVecF32x16): TMask16;
    CmpLtF32x16: function(const a, b: TVecF32x16): TMask16;
    CmpLeF32x16: function(const a, b: TVecF32x16): TMask16;
    CmpGtF32x16: function(const a, b: TVecF32x16): TMask16;
    CmpGeF32x16: function(const a, b: TVecF32x16): TMask16;
    CmpNeF32x16: function(const a, b: TVecF32x16): TMask16;
    // F64x8 (512-bit)
    CmpEqF64x8: function(const a, b: TVecF64x8): TMask8;
    CmpLtF64x8: function(const a, b: TVecF64x8): TMask8;
    CmpLeF64x8: function(const a, b: TVecF64x8): TMask8;
    CmpGtF64x8: function(const a, b: TVecF64x8): TMask8;
    CmpGeF64x8: function(const a, b: TVecF64x8): TMask8;
    CmpNeF64x8: function(const a, b: TVecF64x8): TMask8;

    // 256-bit floating-point comparisons
    // F32x8 (256-bit)
    CmpEqF32x8: function(const a, b: TVecF32x8): TMask8;
    CmpLtF32x8: function(const a, b: TVecF32x8): TMask8;
    CmpLeF32x8: function(const a, b: TVecF32x8): TMask8;
    CmpGtF32x8: function(const a, b: TVecF32x8): TMask8;
    CmpGeF32x8: function(const a, b: TVecF32x8): TMask8;
    CmpNeF32x8: function(const a, b: TVecF32x8): TMask8;
    // F64x4 (256-bit)
    CmpEqF64x4: function(const a, b: TVecF64x4): TMask4;
    CmpLtF64x4: function(const a, b: TVecF64x4): TMask4;
    CmpLeF64x4: function(const a, b: TVecF64x4): TMask4;
    CmpGtF64x4: function(const a, b: TVecF64x4): TMask4;
    CmpGeF64x4: function(const a, b: TVecF64x4): TMask4;
    CmpNeF64x4: function(const a, b: TVecF64x4): TMask4;

    // Math functions
    AbsF32x4: function(const a: TVecF32x4): TVecF32x4;
    SqrtF32x4: function(const a: TVecF32x4): TVecF32x4;
    MinF32x4: function(const a, b: TVecF32x4): TVecF32x4;
    MaxF32x4: function(const a, b: TVecF32x4): TVecF32x4;
    
    // Extended math functions
    FmaF32x4: function(const a, b, c: TVecF32x4): TVecF32x4;   // a*b+c
    RcpF32x4: function(const a: TVecF32x4): TVecF32x4;          // 1/x (approximate)
    RsqrtF32x4: function(const a: TVecF32x4): TVecF32x4;        // 1/sqrt(x) (approximate)
    FloorF32x4: function(const a: TVecF32x4): TVecF32x4;
    CeilF32x4: function(const a: TVecF32x4): TVecF32x4;
    RoundF32x4: function(const a: TVecF32x4): TVecF32x4;
    TruncF32x4: function(const a: TVecF32x4): TVecF32x4;
    ClampF32x4: function(const a, minVal, maxVal: TVecF32x4): TVecF32x4;

    // Wide vector extended math functions
    // F64x2 (128-bit)
    FmaF64x2: function(const a, b, c: TVecF64x2): TVecF64x2;
    FloorF64x2: function(const a: TVecF64x2): TVecF64x2;
    CeilF64x2: function(const a: TVecF64x2): TVecF64x2;
    RoundF64x2: function(const a: TVecF64x2): TVecF64x2;
    TruncF64x2: function(const a: TVecF64x2): TVecF64x2;
    // F64x2 math functions
    AbsF64x2: function(const a: TVecF64x2): TVecF64x2;
    SqrtF64x2: function(const a: TVecF64x2): TVecF64x2;
    MinF64x2: function(const a, b: TVecF64x2): TVecF64x2;
    MaxF64x2: function(const a, b: TVecF64x2): TVecF64x2;
    ClampF64x2: function(const a, minVal, maxVal: TVecF64x2): TVecF64x2;
    // F32x8 (256-bit)
    FmaF32x8: function(const a, b, c: TVecF32x8): TVecF32x8;
    FloorF32x8: function(const a: TVecF32x8): TVecF32x8;
    CeilF32x8: function(const a: TVecF32x8): TVecF32x8;
    RoundF32x8: function(const a: TVecF32x8): TVecF32x8;
    TruncF32x8: function(const a: TVecF32x8): TVecF32x8;
    // F32x8 math functions
    AbsF32x8: function(const a: TVecF32x8): TVecF32x8;
    SqrtF32x8: function(const a: TVecF32x8): TVecF32x8;
    MinF32x8: function(const a, b: TVecF32x8): TVecF32x8;
    MaxF32x8: function(const a, b: TVecF32x8): TVecF32x8;
    ClampF32x8: function(const a, minVal, maxVal: TVecF32x8): TVecF32x8;
    // F64x4 (256-bit)
    FmaF64x4: function(const a, b, c: TVecF64x4): TVecF64x4;
    FloorF64x4: function(const a: TVecF64x4): TVecF64x4;
    CeilF64x4: function(const a: TVecF64x4): TVecF64x4;
    RoundF64x4: function(const a: TVecF64x4): TVecF64x4;
    TruncF64x4: function(const a: TVecF64x4): TVecF64x4;
    // F32x16 (512-bit)
    FmaF32x16: function(const a, b, c: TVecF32x16): TVecF32x16;
    FloorF32x16: function(const a: TVecF32x16): TVecF32x16;
    CeilF32x16: function(const a: TVecF32x16): TVecF32x16;
    RoundF32x16: function(const a: TVecF32x16): TVecF32x16;
    TruncF32x16: function(const a: TVecF32x16): TVecF32x16;
    // F64x8 (512-bit)
    FmaF64x8: function(const a, b, c: TVecF64x8): TVecF64x8;
    FloorF64x8: function(const a: TVecF64x8): TVecF64x8;
    CeilF64x8: function(const a: TVecF64x8): TVecF64x8;
    RoundF64x8: function(const a: TVecF64x8): TVecF64x8;
    TruncF64x8: function(const a: TVecF64x8): TVecF64x8;
    // F64x4 math functions
    AbsF64x4: function(const a: TVecF64x4): TVecF64x4;
    SqrtF64x4: function(const a: TVecF64x4): TVecF64x4;
    MinF64x4: function(const a, b: TVecF64x4): TVecF64x4;
    MaxF64x4: function(const a, b: TVecF64x4): TVecF64x4;
    ClampF64x4: function(const a, minVal, maxVal: TVecF64x4): TVecF64x4;

    // 512-bit float math functions
    // F32x16 (512-bit)
    AbsF32x16: function(const a: TVecF32x16): TVecF32x16;
    SqrtF32x16: function(const a: TVecF32x16): TVecF32x16;
    MinF32x16: function(const a, b: TVecF32x16): TVecF32x16;
    MaxF32x16: function(const a, b: TVecF32x16): TVecF32x16;
    ClampF32x16: function(const a, minVal, maxVal: TVecF32x16): TVecF32x16;
    // F64x8 (512-bit)
    AbsF64x8: function(const a: TVecF64x8): TVecF64x8;
    SqrtF64x8: function(const a: TVecF64x8): TVecF64x8;
    MinF64x8: function(const a, b: TVecF64x8): TVecF64x8;
    MaxF64x8: function(const a, b: TVecF64x8): TVecF64x8;
    ClampF64x8: function(const a, minVal, maxVal: TVecF64x8): TVecF64x8;

    // 3D/4D Vector math
    DotF32x4: function(const a, b: TVecF32x4): Single;          // Dot product (4 elements)
    DotF32x3: function(const a, b: TVecF32x4): Single;          // Dot product (3 elements)
    CrossF32x3: function(const a, b: TVecF32x4): TVecF32x4;     // Cross product (uses x,y,z)
    LengthF32x4: function(const a: TVecF32x4): Single;          // Length (4 elements)
    LengthF32x3: function(const a: TVecF32x4): Single;          // Length (3 elements)
    NormalizeF32x4: function(const a: TVecF32x4): TVecF32x4;    // Normalize (4 elements)
    NormalizeF32x3: function(const a: TVecF32x4): TVecF32x4;    // Normalize (3 elements, w=0)

    // FMA-optimized Dot Product Functions
    DotF32x8: function(const a, b: TVecF32x8): Single;          // Dot product (8 elements)
    DotF64x2: function(const a, b: TVecF64x2): Double;          // Dot product (2 elements)
    DotF64x4: function(const a, b: TVecF64x4): Double;          // Dot product (4 elements)
    
    // Reduction operations
    ReduceAddF32x4: function(const a: TVecF32x4): Single;
    ReduceMinF32x4: function(const a: TVecF32x4): Single;
    ReduceMaxF32x4: function(const a: TVecF32x4): Single;
    ReduceMulF32x4: function(const a: TVecF32x4): Single;
    // Wide vector reduction operations
    // F64x2 (128-bit)
    ReduceAddF64x2: function(const a: TVecF64x2): Double;
    ReduceMinF64x2: function(const a: TVecF64x2): Double;
    ReduceMaxF64x2: function(const a: TVecF64x2): Double;
    ReduceMulF64x2: function(const a: TVecF64x2): Double;
    // F32x8 (256-bit)
    ReduceAddF32x8: function(const a: TVecF32x8): Single;
    ReduceMinF32x8: function(const a: TVecF32x8): Single;
    ReduceMaxF32x8: function(const a: TVecF32x8): Single;
    ReduceMulF32x8: function(const a: TVecF32x8): Single;
    // F64x4 (256-bit)
    ReduceAddF64x4: function(const a: TVecF64x4): Double;
    ReduceMinF64x4: function(const a: TVecF64x4): Double;
    ReduceMaxF64x4: function(const a: TVecF64x4): Double;
    ReduceMulF64x4: function(const a: TVecF64x4): Double;
    // F32x16 (512-bit)
    ReduceAddF32x16: function(const a: TVecF32x16): Single;
    ReduceMinF32x16: function(const a: TVecF32x16): Single;
    ReduceMaxF32x16: function(const a: TVecF32x16): Single;
    ReduceMulF32x16: function(const a: TVecF32x16): Single;
    // F64x8 (512-bit)
    ReduceAddF64x8: function(const a: TVecF64x8): Double;
    ReduceMinF64x8: function(const a: TVecF64x8): Double;
    ReduceMaxF64x8: function(const a: TVecF64x8): Double;
    ReduceMulF64x8: function(const a: TVecF64x8): Double;
    
    // Memory operations
    LoadF32x4: function(p: PSingle): TVecF32x4;
    LoadF32x4Aligned: function(p: PSingle): TVecF32x4;
    StoreF32x4: procedure(p: PSingle; const a: TVecF32x4);
    StoreF32x4Aligned: procedure(p: PSingle; const a: TVecF32x4);
    
    // Utility operations
    SplatF32x4: function(value: Single): TVecF32x4;
    ZeroF32x4: function: TVecF32x4;
    SelectF32x4: function(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4;
    ExtractF32x4: function(const a: TVecF32x4; index: Integer): Single;
    InsertF32x4: function(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4;

    // Extract/Insert Lane Operations
    // F64x2 (128-bit)
    ExtractF64x2: function(const a: TVecF64x2; index: Integer): Double;
    InsertF64x2: function(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2;
    // I32x4 (128-bit)
    ExtractI32x4: function(const a: TVecI32x4; index: Integer): Int32;
    InsertI32x4: function(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4;
    // I64x2 (128-bit)
    ExtractI64x2: function(const a: TVecI64x2; index: Integer): Int64;
    InsertI64x2: function(const a: TVecI64x2; value: Int64; index: Integer): TVecI64x2;
    // F32x8 (256-bit)
    ExtractF32x8: function(const a: TVecF32x8; index: Integer): Single;
    InsertF32x8: function(const a: TVecF32x8; value: Single; index: Integer): TVecF32x8;
    // F64x4 (256-bit)
    ExtractF64x4: function(const a: TVecF64x4; index: Integer): Double;
    InsertF64x4: function(const a: TVecF64x4; value: Double; index: Integer): TVecF64x4;
    // I32x8 (256-bit)
    ExtractI32x8: function(const a: TVecI32x8; index: Integer): Int32;
    InsertI32x8: function(const a: TVecI32x8; value: Int32; index: Integer): TVecI32x8;
    // I64x4 (256-bit)
    ExtractI64x4: function(const a: TVecI64x4; index: Integer): Int64;
    InsertI64x4: function(const a: TVecI64x4; value: Int64; index: Integer): TVecI64x4;
    // F32x16 (512-bit)
    ExtractF32x16: function(const a: TVecF32x16; index: Integer): Single;
    InsertF32x16: function(const a: TVecF32x16; value: Single; index: Integer): TVecF32x16;
    // I32x16 (512-bit)
    ExtractI32x16: function(const a: TVecI32x16; index: Integer): Int32;
    InsertI32x16: function(const a: TVecI32x16; value: Int32; index: Integer): TVecI32x16;

    // Wide vector Load/Store/Splat/Zero
    // F64x2 (128-bit)
    LoadF64x2: function(p: PDouble): TVecF64x2;
    StoreF64x2: procedure(p: PDouble; const a: TVecF64x2);
    SplatF64x2: function(value: Double): TVecF64x2;
    ZeroF64x2: function: TVecF64x2;
    // F32x8 (256-bit)
    LoadF32x8: function(p: PSingle): TVecF32x8;
    StoreF32x8: procedure(p: PSingle; const a: TVecF32x8);
    SplatF32x8: function(value: Single): TVecF32x8;
    ZeroF32x8: function: TVecF32x8;
    // F64x4 (256-bit)
    LoadF64x4: function(p: PDouble): TVecF64x4;
    StoreF64x4: procedure(p: PDouble; const a: TVecF64x4);
    SplatF64x4: function(value: Double): TVecF64x4;
    ZeroF64x4: function: TVecF64x4;
    // F32x16 (512-bit)
    LoadF32x16: function(p: PSingle): TVecF32x16;
    StoreF32x16: procedure(p: PSingle; const a: TVecF32x16);
    SplatF32x16: function(value: Single): TVecF32x16;
    ZeroF32x16: function: TVecF32x16;
    // F64x8 (512-bit)
    LoadF64x8: function(p: PDouble): TVecF64x8;
    StoreF64x8: procedure(p: PDouble; const a: TVecF64x8);
    SplatF64x8: function(value: Double): TVecF64x8;
    ZeroF64x8: function: TVecF64x8;

    // === Facade Functions (High-Level API) ===
    // Memory operations
    MemEqual: function(a, b: Pointer; len: SizeUInt): LongBool;
    MemFindByte: function(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
    MemDiffRange: function(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean;
    MemCopy: procedure(src, dst: Pointer; len: SizeUInt);
    MemSet: procedure(dst: Pointer; len: SizeUInt; value: Byte);
    MemReverse: procedure(p: Pointer; len: SizeUInt);
    
    // Statistics functions
    SumBytes: function(p: Pointer; len: SizeUInt): UInt64;
    MinMaxBytes: procedure(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte);
    CountByte: function(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;
    
    // Text processing functions
    Utf8Validate: function(p: Pointer; len: SizeUInt): Boolean;
    AsciiIEqual: function(a, b: Pointer; len: SizeUInt): Boolean;
    ToLowerAscii: procedure(p: Pointer; len: SizeUInt);
    ToUpperAscii: procedure(p: Pointer; len: SizeUInt);
    
    // Search functions
    BytesIndexOf: function(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt;
    
    // Bitset functions
    BitsetPopCount: function(p: Pointer; byteLen: SizeUInt): SizeUInt;

    // Saturating Arithmetic (音视频处理必需)
    // 有符号饱和 (I8: [-128, 127], I16: [-32768, 32767])
    I8x16SatAdd: function(const a, b: TVecI8x16): TVecI8x16;
    I8x16SatSub: function(const a, b: TVecI8x16): TVecI8x16;
    I16x8SatAdd: function(const a, b: TVecI16x8): TVecI16x8;
    I16x8SatSub: function(const a, b: TVecI16x8): TVecI16x8;
    // 无符号饱和 (U8: [0, 255], U16: [0, 65535])
    U8x16SatAdd: function(const a, b: TVecU8x16): TVecU8x16;
    U8x16SatSub: function(const a, b: TVecU8x16): TVecU8x16;
    U16x8SatAdd: function(const a, b: TVecU16x8): TVecU16x8;
    U16x8SatSub: function(const a, b: TVecU16x8): TVecU16x8;

    // I16x8 完整操作 (8×Int16)
    AddI16x8: function(const a, b: TVecI16x8): TVecI16x8;
    SubI16x8: function(const a, b: TVecI16x8): TVecI16x8;
    MulI16x8: function(const a, b: TVecI16x8): TVecI16x8;
    AndI16x8: function(const a, b: TVecI16x8): TVecI16x8;
    OrI16x8: function(const a, b: TVecI16x8): TVecI16x8;
    XorI16x8: function(const a, b: TVecI16x8): TVecI16x8;
    NotI16x8: function(const a: TVecI16x8): TVecI16x8;
    AndNotI16x8: function(const a, b: TVecI16x8): TVecI16x8;
    ShiftLeftI16x8: function(const a: TVecI16x8; count: Integer): TVecI16x8;
    ShiftRightI16x8: function(const a: TVecI16x8; count: Integer): TVecI16x8;
    ShiftRightArithI16x8: function(const a: TVecI16x8; count: Integer): TVecI16x8;
    CmpEqI16x8: function(const a, b: TVecI16x8): TMask8;
    CmpLtI16x8: function(const a, b: TVecI16x8): TMask8;
    CmpGtI16x8: function(const a, b: TVecI16x8): TMask8;
    CmpLeI16x8: function(const a, b: TVecI16x8): TMask8;  // Le/Ge/Ne for narrow integers
    CmpGeI16x8: function(const a, b: TVecI16x8): TMask8;
    CmpNeI16x8: function(const a, b: TVecI16x8): TMask8;
    MinI16x8: function(const a, b: TVecI16x8): TVecI16x8;
    MaxI16x8: function(const a, b: TVecI16x8): TVecI16x8;

    // I8x16 完整操作 (16×Int8)
    AddI8x16: function(const a, b: TVecI8x16): TVecI8x16;
    SubI8x16: function(const a, b: TVecI8x16): TVecI8x16;
    AndI8x16: function(const a, b: TVecI8x16): TVecI8x16;
    OrI8x16: function(const a, b: TVecI8x16): TVecI8x16;
    XorI8x16: function(const a, b: TVecI8x16): TVecI8x16;
    NotI8x16: function(const a: TVecI8x16): TVecI8x16;
    CmpEqI8x16: function(const a, b: TVecI8x16): TMask16;
    CmpLtI8x16: function(const a, b: TVecI8x16): TMask16;
    CmpGtI8x16: function(const a, b: TVecI8x16): TMask16;
    CmpLeI8x16: function(const a, b: TVecI8x16): TMask16;  // Le/Ge/Ne for narrow integers
    CmpGeI8x16: function(const a, b: TVecI8x16): TMask16;
    CmpNeI8x16: function(const a, b: TVecI8x16): TMask16;
    MinI8x16: function(const a, b: TVecI8x16): TVecI8x16;
    MaxI8x16: function(const a, b: TVecI8x16): TVecI8x16;

    // U32x4 完整操作 (4×UInt32)
    AddU32x4: function(const a, b: TVecU32x4): TVecU32x4;
    SubU32x4: function(const a, b: TVecU32x4): TVecU32x4;
    MulU32x4: function(const a, b: TVecU32x4): TVecU32x4;
    AndU32x4: function(const a, b: TVecU32x4): TVecU32x4;
    OrU32x4: function(const a, b: TVecU32x4): TVecU32x4;
    XorU32x4: function(const a, b: TVecU32x4): TVecU32x4;
    NotU32x4: function(const a: TVecU32x4): TVecU32x4;
    AndNotU32x4: function(const a, b: TVecU32x4): TVecU32x4;
    ShiftLeftU32x4: function(const a: TVecU32x4; count: Integer): TVecU32x4;
    ShiftRightU32x4: function(const a: TVecU32x4; count: Integer): TVecU32x4;
    CmpEqU32x4: function(const a, b: TVecU32x4): TMask4;
    CmpLtU32x4: function(const a, b: TVecU32x4): TMask4;
    CmpGtU32x4: function(const a, b: TVecU32x4): TMask4;
    CmpLeU32x4: function(const a, b: TVecU32x4): TMask4;
    CmpGeU32x4: function(const a, b: TVecU32x4): TMask4;
    MinU32x4: function(const a, b: TVecU32x4): TVecU32x4;
    MaxU32x4: function(const a, b: TVecU32x4): TVecU32x4;

    // U16x8 完整操作 (8×UInt16)
    AddU16x8: function(const a, b: TVecU16x8): TVecU16x8;
    SubU16x8: function(const a, b: TVecU16x8): TVecU16x8;
    MulU16x8: function(const a, b: TVecU16x8): TVecU16x8;
    AndU16x8: function(const a, b: TVecU16x8): TVecU16x8;
    OrU16x8: function(const a, b: TVecU16x8): TVecU16x8;
    XorU16x8: function(const a, b: TVecU16x8): TVecU16x8;
    NotU16x8: function(const a: TVecU16x8): TVecU16x8;
    ShiftLeftU16x8: function(const a: TVecU16x8; count: Integer): TVecU16x8;
    ShiftRightU16x8: function(const a: TVecU16x8; count: Integer): TVecU16x8;
    CmpEqU16x8: function(const a, b: TVecU16x8): TMask8;
    CmpLtU16x8: function(const a, b: TVecU16x8): TMask8;
    CmpGtU16x8: function(const a, b: TVecU16x8): TMask8;
    CmpLeU16x8: function(const a, b: TVecU16x8): TMask8;  // Le/Ge/Ne for narrow integers
    CmpGeU16x8: function(const a, b: TVecU16x8): TMask8;
    CmpNeU16x8: function(const a, b: TVecU16x8): TMask8;
    MinU16x8: function(const a, b: TVecU16x8): TVecU16x8;
    MaxU16x8: function(const a, b: TVecU16x8): TVecU16x8;

    // U8x16 完整操作 (16×UInt8)
    AddU8x16: function(const a, b: TVecU8x16): TVecU8x16;
    SubU8x16: function(const a, b: TVecU8x16): TVecU8x16;
    AndU8x16: function(const a, b: TVecU8x16): TVecU8x16;
    OrU8x16: function(const a, b: TVecU8x16): TVecU8x16;
    XorU8x16: function(const a, b: TVecU8x16): TVecU8x16;
    NotU8x16: function(const a: TVecU8x16): TVecU8x16;
    CmpEqU8x16: function(const a, b: TVecU8x16): TMask16;
    CmpLtU8x16: function(const a, b: TVecU8x16): TMask16;
    CmpGtU8x16: function(const a, b: TVecU8x16): TMask16;
    CmpLeU8x16: function(const a, b: TVecU8x16): TMask16;  // Le/Ge/Ne for narrow integers
    CmpGeU8x16: function(const a, b: TVecU8x16): TMask16;
    CmpNeU8x16: function(const a, b: TVecU8x16): TMask16;
    MinU8x16: function(const a, b: TVecU8x16): TVecU8x16;
    MaxU8x16: function(const a, b: TVecU8x16): TVecU8x16;

    // Mask 类型操作 (条件分支优化)
    // TMask2 操作 (2 元素)
    Mask2All: function(mask: TMask2): Boolean;
    Mask2Any: function(mask: TMask2): Boolean;
    Mask2None: function(mask: TMask2): Boolean;
    Mask2PopCount: function(mask: TMask2): Integer;
    Mask2FirstSet: function(mask: TMask2): Integer;  // -1 if none
    // TMask4 操作 (4 元素)
    Mask4All: function(mask: TMask4): Boolean;
    Mask4Any: function(mask: TMask4): Boolean;
    Mask4None: function(mask: TMask4): Boolean;
    Mask4PopCount: function(mask: TMask4): Integer;
    Mask4FirstSet: function(mask: TMask4): Integer;  // -1 if none
    // TMask8 操作 (8 元素)
    Mask8All: function(mask: TMask8): Boolean;
    Mask8Any: function(mask: TMask8): Boolean;
    Mask8None: function(mask: TMask8): Boolean;
    Mask8PopCount: function(mask: TMask8): Integer;
    Mask8FirstSet: function(mask: TMask8): Integer;  // -1 if none
    // TMask16 操作 (16 元素)
    Mask16All: function(mask: TMask16): Boolean;
    Mask16Any: function(mask: TMask16): Boolean;
    Mask16None: function(mask: TMask16): Boolean;
    Mask16PopCount: function(mask: TMask16): Integer;
    Mask16FirstSet: function(mask: TMask16): Integer;  // -1 if none

    // F64x2 Select 操作
    SelectF64x2: function(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2;

    // 512-bit Select operations
    SelectF32x16: function(const mask: TMask16; const a, b: TVecF32x16): TVecF32x16;
    SelectF64x8: function(const mask: TMask8; const a, b: TVecF64x8): TVecF64x8;

    // 缺失的 Select 操作 (条件选择: mask ? a : b)
    SelectI32x4: function(const mask: TVecI32x4; const a, b: TVecI32x4): TVecI32x4;
    SelectF32x8: function(const mask: TVecU32x8; const a, b: TVecF32x8): TVecF32x8;
    SelectF64x4: function(const mask: TVecU64x4; const a, b: TVecF64x4): TVecF64x4;

    // Narrow integer AndNot fast-path (PANDN semantics: (NOT a) AND b)
    AndNotI8x16: function(const a, b: TVecI8x16): TVecI8x16;
    AndNotU16x8: function(const a, b: TVecU16x8): TVecU16x8;
    AndNotU8x16: function(const a, b: TVecU8x16): TVecU8x16;

    // === Batch Array Operations (O(1) dispatch, internal loop) ===
    ArrayAddF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
    ArraySubF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
    ArrayMulF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
    ArrayDivF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
    ArrayMinF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
    ArrayMaxF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
    ArrayAbsF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayNegF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArraySqrtF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayRcpF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayRsqrtF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayRcpRefineF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayRsqrtRefineF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayAddScalarF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
    ArrayMulScalarF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
    ArrayClampF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single);
    ArrayFmaF32: procedure(aA, aB, aC, aDst: PSingle; aCount: SizeUInt);
    ArrayAxpyF32: procedure(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt);
    ReduceSumF32: function(aSrc: PSingle; aCount: SizeUInt): Single;
    ReduceDotF32: function(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
    ReduceMinF32: function(aSrc: PSingle; aCount: SizeUInt): Single;
    ReduceMaxF32: function(aSrc: PSingle; aCount: SizeUInt): Single;

    // === Batch Array Operations - F64 ===
    ArrayAddF64: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
    ArraySubF64: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
    ArrayMulF64: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
    ArrayDivF64: procedure(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
    ReduceSumF64: function(aSrc: PDouble; aCount: SizeUInt): Double;
    ReduceDotF64: function(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double;
    ReduceMinF64: function(aSrc: PDouble; aCount: SizeUInt): Double;
    ReduceMaxF64: function(aSrc: PDouble; aCount: SizeUInt): Double;
    ArrayAbsF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
    ArrayNegF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
    ArraySqrtF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt);
    ArrayMulScalarF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
    ArrayAddScalarF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
    ArrayClampF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double);
    ArrayLinearF64: procedure(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double);

    // === Batch Array Operations - Transcendental F32 ===
    ArrayExpF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayLogF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayPowF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aExponent: Single);
    ArraySinF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayCosF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);

    // === Batch Array Operations - Integer ===
    ArrayAddI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
    ArraySubI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
    ArrayMulI16: procedure(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
    ArrayPackSatI32toI16: procedure(aSrc: PInt32; aDst: PInt16; aCount: SizeUInt);

    // === Batch Array Operations - Type Conversion ===
    ArrayF32toI32: procedure(aSrc: PSingle; aDst: PInt32; aCount: SizeUInt);
    ArrayI32toF32: procedure(aSrc: PInt32; aDst: PSingle; aCount: SizeUInt);

    // === Batch Array Operations - Bitwise (I32) ===
    ArrayAndI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
    ArrayOrI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
    ArrayXorI32: procedure(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
    ArrayShlI32: procedure(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
    ArrayShrI32: procedure(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);

    // === Fused Batch Operations (single-pass, reduced memory traffic) ===
    ArrayLinearF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
    ArrayAbsDiffF32: procedure(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
    ArrayReLUF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt);
    ArrayNormF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aMean, aInvStd: Single);
    ArrayLinearReLUF32: procedure(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
  end;
