  TSimdDispatchTable = record
    // Backend information
    Backend: TSimdBackend;
    BackendInfo: TSimdBackendInfo;

    // === Nested sub-records (Phase 19 Phase 2–5) ===
    // CoreVectors holds former flat lane/vector slots (AddF32x4, Select*, sat, ...).
    CoreVectors: TSimdCoreVectorOps;
    Memory: TSimdMemoryOps;
    Mask: TSimdMaskOps;
    BatchF32: TSimdBatchF32Ops;
    BatchF64: TSimdBatchF64Ops;
    BatchInteger: TSimdBatchIntegerOps;
  end;
