// === Modular Dispatch Table ===
// Split into logical sub-records for better organization

TSimdDispatchTable = record
  // Backend information
  Backend: TSimdBackend;
  BackendInfo: TSimdBackendInfo;

  // Core vector operations (organized by type)
  F32x4: TSimdVecF32x4Ops;
  F64x2: TSimdVecF64x2Ops;
  I32x4: TSimdVecI32x4Ops;

  // Memory operations
  Memory: TSimdMemoryOps;

  // Mask operations
  Mask: TSimdMaskOps;

  // Batch array operations (organized by type)
  BatchF32: TSimdBatchF32Ops;
  BatchF64: TSimdBatchF64Ops;
  BatchInteger: TSimdBatchIntegerOps;

  // Wide vector operations (256-bit, 512-bit)
  // These are kept flat for now due to their specialized nature
  // F32x8 (256-bit)
  AddF32x8: function(const a, b: TVecF32x8): TVecF32x8;
  SubF32x8: function(const a, b: TVecF32x8): TVecF32x8;
  MulF32x8: function(const a, b: TVecF32x8): TVecF32x8;
  DivF32x8: function(const a, b: TVecF32x8): TVecF32x8;
  NegF32x8: function(const a: TVecF32x8): TVecF32x8;
  AbsF32x8: function(const a: TVecF32x8): TVecF32x8;
  SqrtF32x8: function(const a: TVecF32x8): TVecF32x8;
  MinF32x8: function(const a, b: TVecF32x8): TVecF32x8;
  MaxF32x8: function(const a, b: TVecF32x8): TVecF32x8;
  ClampF32x8: function(const a, minVal, maxVal: TVecF32x8): TVecF32x8;
  DotF32x8: function(const a, b: TVecF32x8): Single;
  ReduceAddF32x8: function(const a: TVecF32x8): Single;
  ReduceMinF32x8: function(const a: TVecF32x8): Single;
  ReduceMaxF32x8: function(const a: TVecF32x8): Single;
  ReduceMulF32x8: function(const a: TVecF32x8): Single;
  FmaF32x8: function(const a, b, c: TVecF32x8): TVecF32x8;
  FloorF32x8: function(const a: TVecF32x8): TVecF32x8;
  CeilF32x8: function(const a: TVecF32x8): TVecF32x8;
  RoundF32x8: function(const a: TVecF32x8): TVecF32x8;
  TruncF32x8: function(const a: TVecF32x8): TVecF32x8;
  RcpF32x8: function(const a: TVecF32x8): TVecF32x8;
  RsqrtF32x8: function(const a: TVecF32x8): TVecF32x8;
  LoadF32x8: function(p: PSingle): TVecF32x8;
  LoadF32x8Aligned: function(p: PSingle): TVecF32x8;
  StoreF32x8: procedure(p: PSingle; const a: TVecF32x8);
  StoreF32x8Aligned: procedure(p: PSingle; const a: TVecF32x8);
  SplatF32x8: function(value: Single): TVecF32x8;
  ZeroF32x8: function: TVecF32x8;
  MakeF32x8: function(v0, v1, v2, v3, v4, v5, v6, v7: Single): TVecF32x8;
  CmpEqF32x8: function(const a, b: TVecF32x8): TMask8;
  CmpLtF32x8: function(const a, b: TVecF32x8): TMask8;
  CmpLeF32x8: function(const a, b: TVecF32x8): TMask8;
  CmpGtF32x8: function(const a, b: TVecF32x8): TMask8;
  CmpGeF32x8: function(const a, b: TVecF32x8): TMask8;
  CmpNeF32x8: function(const a, b: TVecF32x8): TMask8;
  SelectF32x8: function(const mask: TVecU32x8; const a, b: TVecF32x8): TVecF32x8;
  ExtractF32x8: function(const a: TVecF32x8; index: Integer): Single;
  InsertF32x8: function(const a: TVecF32x8; value: Single; index: Integer): TVecF32x8;

  // F64x4 (256-bit)
  AddF64x4: function(const a, b: TVecF64x4): TVecF64x4;
  SubF64x4: function(const a, b: TVecF64x4): TVecF64x4;
  MulF64x4: function(const a, b: TVecF64x4): TVecF64x4;
  DivF64x4: function(const a, b: TVecF64x4): TVecF64x4;
  NegF64x4: function(const a: TVecF64x4): TVecF64x4;
  AbsF64x4: function(const a: TVecF64x4): TVecF64x4;
  SqrtF64x4: function(const a: TVecF64x4): TVecF64x4;
  MinF64x4: function(const a, b: TVecF64x4): TVecF64x4;
  MaxF64x4: function(const a, b: TVecF64x4): TVecF64x4;
  ClampF64x4: function(const a, minVal, maxVal: TVecF64x4): TVecF64x4;
  DotF64x4: function(const a, b: TVecF64x4): Double;
  ReduceAddF64x4: function(const a: TVecF64x4): Double;
  ReduceMinF64x4: function(const a: TVecF64x4): Double;
  ReduceMaxF64x4: function(const a: TVecF64x4): Double;
  ReduceMulF64x4: function(const a: TVecF64x4): Double;
  FmaF64x4: function(const a, b, c: TVecF64x4): TVecF64x4;
  FloorF64x4: function(const a: TVecF64x4): TVecF64x4;
  CeilF64x4: function(const a: TVecF64x4): TVecF64x4;
  RoundF64x4: function(const a: TVecF64x4): TVecF64x4;
  TruncF64x4: function(const a: TVecF64x4): TVecF64x4;
  RcpF64x4: function(const a: TVecF64x4): TVecF64x4;
  LoadF64x4: function(p: PDouble): TVecF64x4;
  LoadF64x4Aligned: function(p: PDouble): TVecF64x4;
  StoreF64x4: procedure(p: PDouble; const a: TVecF64x4);
  StoreF64x4Aligned: procedure(p: PDouble; const a: TVecF64x4);
  SplatF64x4: function(value: Double): TVecF64x4;
  ZeroF64x4: function: TVecF64x4;
  MakeF64x4: function(v0, v1, v2, v3: Double): TVecF64x4;
  SelectF64x4: function(const mask: TVecU64x4; const a, b: TVecF64x4): TVecF64x4;
  ExtractF64x4: function(const a: TVecF64x4; index: Integer): Double;
  InsertF64x4: function(const a: TVecF64x4; value: Double; index: Integer): TVecF64x4;

  // I32x8 (256-bit)
  AddI32x8: function(const a, b: TVecI32x8): TVecI32x8;
  SubI32x8: function(const a, b: TVecI32x8): TVecI32x8;
  MulI32x8: function(const a, b: TVecI32x8): TVecI32x8;
  AndI32x8: function(const a, b: TVecI32x8): TVecI32x8;
  OrI32x8: function(const a, b: TVecI32x8): TVecI32x8;
  XorI32x8: function(const a, b: TVecI32x8): TVecI32x8;
  NotI32x8: function(const a: TVecI32x8): TVecI32x8;
  AndNotI32x8: function(const a, b: TVecI32x8): TVecI32x8;
  ShiftLeftI32x8: function(const a: TVecI32x8; count: Integer): TVecI32x8;
  ShiftRightI32x8: function(const a: TVecI32x8; count: Integer): TVecI32x8;
  ShiftRightArithI32x8: function(const a: TVecI32x8; count: Integer): TVecI32x8;
  CmpEqI32x8: function(const a, b: TVecI32x8): TMask8;
  CmpLtI32x8: function(const a, b: TVecI32x8): TMask8;
  CmpGtI32x8: function(const a, b: TVecI32x8): TMask8;
  CmpLeI32x8: function(const a, b: TVecI32x8): TMask8;
  CmpGeI32x8: function(const a, b: TVecI32x8): TMask8;
  CmpNeI32x8: function(const a, b: TVecI32x8): TMask8;
  MinI32x8: function(const a, b: TVecI32x8): TVecI32x8;
  MaxI32x8: function(const a, b: TVecI32x8): TVecI32x8;
  LoadI32x8: function(p: PInt32): TVecI32x8;
  StoreI32x8: procedure(p: PInt32; const a: TVecI32x8);
  SplatI32x8: function(value: Int32): TVecI32x8;
  ZeroI32x8: function: TVecI32x8;
  SelectI32x8: function(const mask: TVecI32x8; const a, b: TVecI32x8): TVecI32x8;
  ExtractI32x8: function(const a: TVecI32x8; index: Integer): Int32;
  InsertI32x8: function(const a: TVecI32x8; value: Int32; index: Integer): TVecI32x8;

  // 512-bit operations (AVX-512)
  // F32x16
  AddF32x16: function(const a, b: TVecF32x16): TVecF32x16;
  SubF32x16: function(const a, b: TVecF32x16): TVecF32x16;
  MulF32x16: function(const a, b: TVecF32x16): TVecF32x16;
  DivF32x16: function(const a, b: TVecF32x16): TVecF32x16;
  NegF32x16: function(const a: TVecF32x16): TVecF32x16;
  AbsF32x16: function(const a: TVecF32x16): TVecF32x16;
  SqrtF32x16: function(const a: TVecF32x16): TVecF32x16;
  MinF32x16: function(const a, b: TVecF32x16): TVecF32x16;
  MaxF32x16: function(const a, b: TVecF32x16): TVecF32x16;
  ClampF32x16: function(const a, minVal, maxVal: TVecF32x16): TVecF32x16;
  FmaF32x16: function(const a, b, c: TVecF32x16): TVecF32x16;
  FloorF32x16: function(const a: TVecF32x16): TVecF32x16;
  CeilF32x16: function(const a: TVecF32x16): TVecF32x16;
  RoundF32x16: function(const a: TVecF32x16): TVecF32x16;
  TruncF32x16: function(const a: TVecF32x16): TVecF32x16;
  LoadF32x16: function(p: PSingle): TVecF32x16;
  LoadF32x16Aligned: function(p: PSingle): TVecF32x16;
  StoreF32x16: procedure(p: PSingle; const a: TVecF32x16);
  StoreF32x16Aligned: procedure(p: PSingle; const a: TVecF32x16);
  SplatF32x16: function(value: Single): TVecF32x16;
  ZeroF32x16: function: TVecF32x16;
  SelectF32x16: function(const mask: TMask16; const a, b: TVecF32x16): TVecF32x16;
  ExtractF32x16: function(const a: TVecF32x16; index: Integer): Single;
  InsertF32x16: function(const a: TVecF32x16; value: Single; index: Integer): TVecF32x16;
  ReduceAddF32x16: function(const a: TVecF32x16): Single;
  ReduceMinF32x16: function(const a: TVecF32x16): Single;
  ReduceMaxF32x16: function(const a: TVecF32x16): Single;
  ReduceMulF32x16: function(const a: TVecF32x16): Single;

  // F64x8
  AddF64x8: function(const a, b: TVecF64x8): TVecF64x8;
  SubF64x8: function(const a, b: TVecF64x8): TVecF64x8;
  MulF64x8: function(const a, b: TVecF64x8): TVecF64x8;
  DivF64x8: function(const a, b: TVecF64x8): TVecF64x8;
  NegF64x8: function(const a: TVecF64x8): TVecF64x8;
  AbsF64x8: function(const a: TVecF64x8): TVecF64x8;
  SqrtF64x8: function(const a: TVecF64x8): TVecF64x8;
  MinF64x8: function(const a, b: TVecF64x8): TVecF64x8;
  MaxF64x8: function(const a, b: TVecF64x8): TVecF64x8;
  ClampF64x8: function(const a, minVal, maxVal: TVecF64x8): TVecF64x8;
  FmaF64x8: function(const a, b, c: TVecF64x8): TVecF64x8;
  FloorF64x8: function(const a: TVecF64x8): TVecF64x8;
  CeilF64x8: function(const a: TVecF64x8): TVecF64x8;
  RoundF64x8: function(const a: TVecF64x8): TVecF64x8;
  TruncF64x8: function(const a: TVecF64x8): TVecF64x8;
  LoadF64x8: function(p: PDouble): TVecF64x8;
  LoadF64x8Aligned: function(p: PDouble): TVecF64x8;
  StoreF64x8: procedure(p: PDouble; const a: TVecF64x8);
  StoreF64x8Aligned: procedure(p: PDouble; const a: TVecF64x8);
  SplatF64x8: function(value: Double): TVecF64x8;
  ZeroF64x8: function: TVecF64x8;
  SelectF64x8: function(const mask: TMask8; const a, b: TVecF64x8): TVecF64x8;
  ExtractF64x8: function(const a: TVecF64x8; index: Integer): Double;
  InsertF64x8: function(const a: TVecF64x8; value: Double; index: Integer): TVecF64x8;
  ReduceAddF64x8: function(const a: TVecF64x8): Double;
  ReduceMinF64x8: function(const a: TVecF64x8): Double;
  ReduceMaxF64x8: function(const a: TVecF64x8): Double;
  ReduceMulF64x8: function(const a: TVecF64x8): Double;

  // I32x16 (512-bit)
  AddI32x16: function(const a, b: TVecI32x16): TVecI32x16;
  SubI32x16: function(const a, b: TVecI32x16): TVecI32x16;
  MulI32x16: function(const a, b: TVecI32x16): TVecI32x16;
  AndI32x16: function(const a, b: TVecI32x16): TVecI32x16;
  OrI32x16: function(const a, b: TVecI32x16): TVecI32x16;
  XorI32x16: function(const a, b: TVecI32x16): TVecI32x16;
  NotI32x16: function(const a: TVecI32x16): TVecI32x16;
  AndNotI32x16: function(const a, b: TVecI32x16): TVecI32x16;
  ShiftLeftI32x16: function(const a: TVecI32x16; count: Integer): TVecI32x16;
  ShiftRightI32x16: function(const a: TVecI32x16; count: Integer): TVecI32x16;
  ShiftRightArithI32x16: function(const a: TVecI32x16; count: Integer): TVecI32x16;
  CmpEqI32x16: function(const a, b: TVecI32x16): TMask16;
  CmpLtI32x16: function(const a, b: TVecI32x16): TMask16;
  CmpGtI32x16: function(const a, b: TVecI32x16): TMask16;
  CmpLeI32x16: function(const a, b: TVecI32x16): TMask16;
  CmpGeI32x16: function(const a, b: TVecI32x16): TMask16;
  CmpNeI32x16: function(const a, b: TVecI32x16): TMask16;
  MinI32x16: function(const a, b: TVecI32x16): TVecI32x16;
  MaxI32x16: function(const a, b: TVecI32x16): TVecI32x16;
  LoadI32x16: function(p: PInt32): TVecI32x16;
  StoreI32x16: procedure(p: PInt32; const a: TVecI32x16);
  SplatI32x16: function(value: Int32): TVecI32x16;
  ZeroI32x16: function: TVecI32x16;
  SelectI32x16: function(const mask: TMask16; const a, b: TVecI32x16): TVecI32x16;
  ExtractI32x16: function(const a: TVecI32x16; index: Integer): Int32;
  InsertI32x16: function(const a: TVecI32x16; value: Int32; index: Integer): TVecI32x16;
end;
