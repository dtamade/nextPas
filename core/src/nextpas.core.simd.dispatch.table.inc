  TSimdDispatchTable = record
    // Backend information
    Backend: TSimdBackend;
    BackendInfo: TSimdBackendInfo;

    // === Nested sub-records (Phase 19 complete) ===
    // CoreVectors holds lane/vector slots (AddF32x4, Select*, sat, ...); field names full.
    CoreVectors: TSimdCoreVectorOps;
    Memory: TSimdMemoryOps;
    Mask: TSimdMaskOps;
    BatchF32: TSimdBatchF32Ops;
    BatchF64: TSimdBatchF64Ops;
    BatchInteger: TSimdBatchIntegerOps;
  end;
