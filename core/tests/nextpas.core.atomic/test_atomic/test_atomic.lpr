program test_atomic;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.atomic,
  nextpas.core.atomic.compat,
  nextpas.core.platform.sync;

var
  T: TTestRunner;

function ReadUtf8TextFile(const APath: string): string;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(Result[1], LStream.Size);
  finally
    LStream.Free;
  end;
end;

procedure CheckContains(const AText, AExpected, AMessage: string);
begin
  Check(Pos(AExpected, AText) > 0, AMessage + ': missing "' + AExpected + '"');
end;

procedure CheckNotContains(const AText, AUnexpected, AMessage: string);
begin
  Check(Pos(AUnexpected, AText) = 0, AMessage + ': unexpected "' + AUnexpected + '"');
end;

function ExtractSection(const AText, AStartMarker, AEndMarker: string): string;
var
  LStartPos: SizeInt;
  LEndPos: SizeInt;
  LRelativeEndPos: SizeInt;
begin
  LStartPos := Pos(AStartMarker, AText);
  Check(LStartPos > 0, 'section start missing: ' + AStartMarker);

  LRelativeEndPos := Pos(AEndMarker,
    Copy(AText, LStartPos + Length(AStartMarker), MaxInt));
  if LRelativeEndPos > 0 then
    LEndPos := LStartPos + Length(AStartMarker) + LRelativeEndPos - 1
  else
    LEndPos := 0;
  Check((LEndPos > LStartPos), 'section end missing: ' + AEndMarker);

  Result := Copy(AText, LStartPos, LEndPos - LStartPos);
end;

function ExtractImplementationSection(const AText, AStartMarker, AEndMarker: string): string;
var
  LImplementationPos: SizeInt;
begin
  LImplementationPos := Pos('implementation', AText);
  Check(LImplementationPos > 0, 'implementation marker missing');
  Result := ExtractSection(
    Copy(AText, LImplementationPos, MaxInt),
    AStartMarker,
    AEndMarker
  );
end;

function CountOccurrences(const AText, APattern: string): SizeInt;
var
  LSearchPos: SizeInt;
  LFoundPos: SizeInt;
begin
  Result := 0;
  if APattern = '' then
    Exit;

  LSearchPos := 1;
  repeat
    LFoundPos := Pos(APattern, Copy(AText, LSearchPos, MaxInt));
    if LFoundPos = 0 then
      Break;
    Inc(Result);
    Inc(LSearchPos, LFoundPos + Length(APattern) - 1);
  until False;
end;

procedure TestLoad32Store32;
var
  LVal: Int32;
begin
  LVal := 0;
  AtomicStore32(LVal, 42, moRelaxed);
  CheckEqual(Int64(42), Int64(AtomicLoad32(LVal, moRelaxed)));

  AtomicStore32(LVal, 99, moRelease);
  CheckEqual(Int64(99), Int64(AtomicLoad32(LVal, moAcquire)));

  AtomicStore32(LVal, -1, moSeqCst);
  CheckEqual(Int64(-1), Int64(AtomicLoad32(LVal, moSeqCst)));
end;

procedure TestExchange32;
var
  LVal: Int32;
  LOld: Int32;
begin
  LVal := 10;
  LOld := AtomicExchange32(LVal, 20);
  CheckEqual(Int64(10), Int64(LOld));
  CheckEqual(Int64(20), Int64(LVal));
end;

procedure TestCompareExchange32;
var
  LVal: Int32;
  LOld: Int32;
begin
  LVal := 5;
  LOld := AtomicCompareExchange32(LVal, 5, 10);
  CheckEqual(Int64(5), Int64(LOld), 'CAS success returns old');
  CheckEqual(Int64(10), Int64(LVal), 'CAS success updates target');

  LOld := AtomicCompareExchange32(LVal, 5, 20);
  CheckEqual(Int64(10), Int64(LOld), 'CAS fail returns current');
  CheckEqual(Int64(10), Int64(LVal), 'CAS fail does not update');
end;

procedure TestFetchAdd32;
var
  LVal: Int32;
  LOld: Int32;
begin
  LVal := 100;
  LOld := AtomicFetchAdd32(LVal, 5);
  CheckEqual(Int64(100), Int64(LOld));
  CheckEqual(Int64(105), Int64(LVal));

  LOld := AtomicFetchSub32(LVal, 10);
  CheckEqual(Int64(105), Int64(LOld));
  CheckEqual(Int64(95), Int64(LVal));
end;

procedure TestFetchBitwise32;
var
  LVal: Int32;
  LOld: Int32;
begin
  LVal := $FF;
  LOld := AtomicFetchAnd32(LVal, $0F);
  CheckEqual(Int64($FF), Int64(LOld));
  CheckEqual(Int64($0F), Int64(LVal));

  LOld := AtomicFetchOr32(LVal, $F0);
  CheckEqual(Int64($0F), Int64(LOld));
  CheckEqual(Int64($FF), Int64(LVal));

  LOld := AtomicFetchXor32(LVal, $AA);
  CheckEqual(Int64($FF), Int64(LOld));
  CheckEqual(Int64($55), Int64(LVal));
end;

procedure TestLoad64Store64;
var
  LVal: Int64;
begin
  LVal := 0;
  AtomicStore64(LVal, Int64(1) shl 40, moSeqCst);
  CheckEqual(Int64(1) shl 40, AtomicLoad64(LVal, moSeqCst));
end;

procedure TestExchange64;
var
  LVal: Int64;
  LOld: Int64;
begin
  LVal := Int64(123456789012345);
  LOld := AtomicExchange64(LVal, Int64(987654321098765));
  CheckEqual(Int64(123456789012345), LOld);
  CheckEqual(Int64(987654321098765), LVal);
end;

procedure TestPointerAtomics;
var
  LPtr: Pointer;
  LOld: Pointer;
  LA, LB: Integer;
begin
  LA := 1;
  LB := 2;
  LPtr := @LA;
  LOld := AtomicExchangePtr(LPtr, @LB);
  Check(LOld = @LA, 'exchange returns old');
  Check(LPtr = @LB, 'exchange sets new');

  LOld := AtomicCompareExchangePtr(LPtr, @LB, @LA);
  Check(LOld = @LB, 'CAS success');
  Check(LPtr = @LA, 'CAS updated');
end;

procedure TestFence;
begin
  AtomicThreadFence(moRelaxed);
  AtomicThreadFence(moAcquire);
  AtomicThreadFence(moRelease);
  AtomicThreadFence(moAcqRel);
  AtomicThreadFence(moSeqCst);
  AtomicSignalFence(moSeqCst);
  CpuPause;
end;

procedure TestAtomicDefaultLoadSurface;
var
  LI32: Int32;
  LU32: UInt32;
  LI64: Int64;
  LU64: UInt64;
  LPtr: Pointer;
  LValue: Int32;
  LPtrInt: PtrInt;
  LPtrUInt: PtrUInt;
begin
  LI32 := 41;
  CheckEqual(Int64(41), Int64(atomic_load(LI32)));

  LU32 := 42;
  CheckEqual(Int64(42), Int64(atomic_load(LU32)));

  LI64 := Int64(1) shl 40;
  CheckEqual(Int64(1) shl 40, atomic_load_64(LI64));

  LU64 := UInt64(1) shl 41;
  CheckEqual(Int64(UInt64(1) shl 41), Int64(atomic_load_64(LU64)));

  LValue := 7;
  LPtr := @LValue;
  Check(LPtr = atomic_load(LPtr), 'default pointer atomic_load must be available');

  LPtrInt := PtrInt(@LValue);
  CheckEqual(Int64(LPtrInt), Int64(atomic_load(LPtrInt)));

  LPtrUInt := PtrUInt(@LValue);
  CheckEqual(Int64(LPtrUInt), Int64(atomic_load(LPtrUInt)));
end;

procedure TestAtomicSourceContracts;
const
  AtomicSourcePath = '../../../src/nextpas.core.atomic.pas';
  AtomicCoreSourcePath = '../../../src/nextpas.core.atomic.core.pas';
  AtomicTypesSourcePath = '../../../src/nextpas.core.atomic.types.pas';
  AtomicCompatSourcePath = '../../../src/nextpas.core.atomic.compat.pas';
  AtomicTestSourcePath = 'test_atomic.lpr';
  AtomicDocsReadmePath = '../../../docs/atomic/README.md';
  AtomicBenchMakefilePath = '../../../benchmarks/nextpas.core.atomic/bench_atomic/Makefile';
  AtomicBenchSourcePath = '../../../benchmarks/nextpas.core.atomic/bench_atomic/bench_atomic.lpr';
  AtomicBenchRustComparePath = '../../../benchmarks/nextpas.core.atomic/bench_atomic/compare_rust/main.rs';
  AtomicBenchGoComparePath = '../../../benchmarks/nextpas.core.atomic/bench_atomic/compare_go/main.go';
  AtomicBenchCppComparePath = '../../../benchmarks/nextpas.core.atomic/bench_atomic/compare_cpp/main.cpp';
  AtomicX8664SnapshotLegacyPath = '../../../src/nextpas.core.atomic.x86_64.inc';
  AtomicX8664SnapshotArchivePath = '../../../docs/archive/atomic/nextpas.core.atomic.x86_64.snapshot.txt';
var
  LAtomicSource: string;
  LAtomicCoreSource: string;
  LAtomicTypesSource: string;
  LAtomicCompatSource: string;
  LAtomicTestSource: string;
  LAtomicDocsReadme: string;
  LAtomicBenchMakefile: string;
  LAtomicBenchSource: string;
  LAtomicBenchRustCompareSource: string;
  LAtomicBenchGoCompareSource: string;
  LAtomicBenchCppCompareSource: string;
  LX8664SnapshotSource: string;
  LSignalFenceSection: string;
  LSignalFenceHelperSection: string;
  LSeqCstFenceHelperSection: string;
  LTaggedPtrSection: string;
  LTaggedPtrNextSection: string;
  LTaggedPtrUpdateSection: string;
  LTaggedPtrUpdateTagSection: string;
  LThreadFenceSection: string;
  LSingleStrongCasSection: string;
  LSingleWeakCasSection: string;
  LCompatFailureSection: string;
  LTypesFailureSection: string;
  LTypesInt32LockFreeSection: string;
  LTypesUInt32LockFreeSection: string;
  LTypesInt32FetchSection: string;
  LTypesUInt32FetchSection: string;
  LTypesInt64LockFreeSection: string;
  LTypesUInt64LockFreeSection: string;
  LTypesInt64FetchSection: string;
  LTypesUInt64FetchSection: string;
  LTypesISizeLockFreeSection: string;
  LTypesUSizeLockFreeSection: string;
  LTypesISizeFetchSection: string;
  LTypesUSizeFetchSection: string;
  LTypesRefCountLockFreeSection: string;
  LTypesBoolLockFreeSection: string;
  LTypesBoolFetchNandSection: string;
  LTypesPtrLockFreeSection: string;
  LFetchAddFallbackSection: string;
  LLoad32Section: string;
  LLoad64Section: string;
  LLoad32SeqCstSection: string;
  LLoad64SeqCstSection: string;
  LDefaultLoad32Section: string;
  LDefaultLoad64Section: string;
  LDefaultLoadPtrSection: string;
  LDefaultLoadPtrIntSection: string;
  LStore32Section: string;
  LStore64Section: string;
  LStore32SeqCstSection: string;
  LStore64SeqCstSection: string;
  LDefaultStore32Section: string;
  LDefaultStoreUInt32Section: string;
  LDefaultStore64Section: string;
  LDefaultStoreUInt64Section: string;
  LDefaultStorePtrSection: string;
  LDefaultStorePtrIntSection: string;
  LDefaultStorePtrUIntSection: string;
  LCasStrong32DualSection: string;
  LCasStrongPtrIntDualSection: string;
  LCasStrong64DualSection: string;
  LTaggedPtrLoadSection: string;
  LTaggedPtrStoreSection: string;
  LTaggedPtrStrongCasSection: string;
  LTaggedPtrWeakCasSection: string;
  LPascalCaseCas32Section: string;
  LPascalCaseCas64Section: string;
  LPascalCaseCasPtrSection: string;
  LFacadePtrStrongCasSection: string;
  LFacadePtrWeakCasSection: string;
  LDefaultTaggedPtrLoadSection: string;
  LDefaultTaggedPtrStoreSection: string;
  LAtomicWaitSection: string;
  LAtomicNotifyOneSection: string;
  LAtomicNotifyAllSection: string;
  LCompatFacadeTestSection: string;
  LCompatAliasTestSection: string;
  LTypedInt64ContractSection: string;
  LTypedInt64FetchContractSection: string;
  LRunnerSection: string;
  LAtomicFlagTestAndSetSection: string;
  LAtomicFlagTestSection: string;
  LAtomicFlagClearSection: string;
  LRefCountTypeSection: string;
  LRefCountIncSection: string;
  LRefCountTryIncSection: string;
  LRefCountDecSection: string;
  LFetchAnd64Section: string;
  LFetchOr64Section: string;
  LFetchXor64Section: string;
  LFetchMax64Section: string;
  LFetchMin64Section: string;
  LFetchNand64Section: string;
  LPointerFetchAddSection: string;
  LPointerFetchSubSection: string;
  LDefaultFetchMax32Section: string;
  LDefaultFetchMin32Section: string;
  LDefaultFetchNand32Section: string;
  LDefaultFetchMax64Section: string;
  LDefaultFetchMin64Section: string;
  LDefaultFetchNand64Section: string;
begin
  LAtomicSource := ReadUtf8TextFile(AtomicSourcePath);
  LAtomicCoreSource := ReadUtf8TextFile(AtomicCoreSourcePath);
  LAtomicTypesSource := ReadUtf8TextFile(AtomicTypesSourcePath);
  LAtomicCompatSource := ReadUtf8TextFile(AtomicCompatSourcePath);
  LAtomicTestSource := ReadUtf8TextFile(AtomicTestSourcePath);
  LAtomicDocsReadme := ReadUtf8TextFile(AtomicDocsReadmePath);
  Check(FileExists(AtomicBenchMakefilePath),
    'atomic benchmark Makefile must exist as the focused benchmark entrypoint');
  Check(FileExists(AtomicBenchSourcePath),
    'atomic benchmark source must exist as the benchmark entrypoint');
  Check(FileExists(AtomicBenchRustComparePath),
    'atomic benchmark Rust comparison source must exist as an external baseline reference');
  Check(FileExists(AtomicBenchGoComparePath),
    'atomic benchmark Go comparison source must exist as an external baseline reference');
  Check(FileExists(AtomicBenchCppComparePath),
    'atomic benchmark C++ comparison source must exist as an external baseline reference');
  LAtomicBenchMakefile := ReadUtf8TextFile(AtomicBenchMakefilePath);
  LAtomicBenchSource := ReadUtf8TextFile(AtomicBenchSourcePath);
  LAtomicBenchRustCompareSource := ReadUtf8TextFile(AtomicBenchRustComparePath);
  LAtomicBenchGoCompareSource := ReadUtf8TextFile(AtomicBenchGoComparePath);
  LAtomicBenchCppCompareSource := ReadUtf8TextFile(AtomicBenchCppComparePath);
  Check(not FileExists(AtomicX8664SnapshotLegacyPath),
    'x86_64 snapshot must not remain in src');
  LX8664SnapshotSource := ReadUtf8TextFile(AtomicX8664SnapshotArchivePath);
  LThreadFenceSection := ExtractImplementationSection(LAtomicCoreSource,
    'procedure atomic_thread_fence(aOrder: memory_order_t);',
    'procedure atomic_signal_fence(aOrder: memory_order_t);');
  LSignalFenceSection := ExtractImplementationSection(LAtomicCoreSource,
    'procedure atomic_signal_fence(aOrder: memory_order_t);',
    'function atomic_tagged_ptr');
  LSignalFenceHelperSection := ExtractImplementationSection(LAtomicCoreSource,
    'procedure _compiler_signal_fence; assembler; nostackframe;',
    'procedure atomic_thread_fence');
  LSeqCstFenceHelperSection := ExtractSection(LAtomicCoreSource,
    'procedure atomic_seq_cst_fence;',
    'procedure cpu_pause;');
  LTaggedPtrSection := ExtractImplementationSection(LAtomicCoreSource,
    'function atomic_tagged_ptr(aPtr: Pointer; aTag:',
    'function atomic_tagged_ptr_get_ptr');
  LTaggedPtrNextSection := ExtractImplementationSection(LAtomicCoreSource,
    'function atomic_tagged_ptr_next(const aTaggedPtr: atomic_tagged_ptr_t):',
    'end.');
  LSingleStrongCasSection := ExtractImplementationSection(LAtomicSource,
    '// ✅ P1-002: CAS 单内存序版本实现 - 简化常见用法（成功和失败使用相同内存序）',
    'function atomic_compare_exchange_weak(var aObj: Int32; var aExpected: Int32; aDesired: Int32;');
  LSingleWeakCasSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_compare_exchange_weak(var aObj: Int32; var aExpected: Int32; aDesired: Int32;',
    'function atomic_increment(var aObj: Int32): Int32;');
  LCompatFailureSection := ExtractImplementationSection(LAtomicSource,
    'function AtomicCompatFailureOrder(const AOrder: TMemoryOrder): TMemoryOrder; inline;',
    'function AtomicLoad32(var ATarget: Int32; const AOrder: TMemoryOrder): Int32;');
  LTypesFailureSection := ExtractImplementationSection(LAtomicTypesSource,
    'function _cas_failure_order(const ASuccessOrder: memory_order_t): memory_order_t; inline;',
    '{ TAtomicInt32 }');
  LTypesInt32LockFreeSection := ExtractImplementationSection(LAtomicTypesSource,
    'class function TAtomicInt32.is_lock_free: Boolean;',
    'function TAtomicInt32.Load(AOrder: memory_order_t): Int32;');
  LTypesUInt32LockFreeSection := ExtractImplementationSection(LAtomicTypesSource,
    'class function TAtomicUInt32.is_lock_free: Boolean;',
    'function TAtomicUInt32.Load(AOrder: memory_order_t): UInt32;');
  LTypesInt32FetchSection := ExtractImplementationSection(LAtomicTypesSource,
    'function TAtomicInt32.FetchAdd(ADelta: Int32; AOrder: memory_order_t): Int32;',
    'function TAtomicInt32.Increment(AOrder: memory_order_t): Int32;');
  LTypesUInt32FetchSection := ExtractImplementationSection(LAtomicTypesSource,
    'function TAtomicUInt32.FetchAdd(ADelta: UInt32; AOrder: memory_order_t): UInt32;',
    'function TAtomicUInt32.Increment(AOrder: memory_order_t): UInt32;');
  LTypesInt64LockFreeSection := ExtractImplementationSection(LAtomicTypesSource,
    'class function TAtomicInt64.is_lock_free: Boolean;',
    'function TAtomicInt64.Load(AOrder: memory_order_t): Int64;');
  LTypesUInt64LockFreeSection := ExtractImplementationSection(LAtomicTypesSource,
    'class function TAtomicUInt64.is_lock_free: Boolean;',
    'function TAtomicUInt64.Load(AOrder: memory_order_t): UInt64;');
  LTypesInt64FetchSection := ExtractImplementationSection(LAtomicTypesSource,
    'function TAtomicInt64.FetchAdd(ADelta: Int64; AOrder: memory_order_t): Int64;',
    'function TAtomicInt64.Increment(AOrder: memory_order_t): Int64;');
  LTypesUInt64FetchSection := ExtractImplementationSection(LAtomicTypesSource,
    'function TAtomicUInt64.FetchAdd(ADelta: UInt64; AOrder: memory_order_t): UInt64;',
    'function TAtomicUInt64.Increment(AOrder: memory_order_t): UInt64;');
  LTypesISizeLockFreeSection := ExtractImplementationSection(LAtomicTypesSource,
    'class function TAtomicISize.is_lock_free: Boolean;',
    'function TAtomicISize.Load(AOrder: memory_order_t): PtrInt;');
  LTypesUSizeLockFreeSection := ExtractImplementationSection(LAtomicTypesSource,
    'class function TAtomicUSize.is_lock_free: Boolean;',
    'function TAtomicUSize.Load(AOrder: memory_order_t): PtrUInt;');
  LTypesISizeFetchSection := ExtractImplementationSection(LAtomicTypesSource,
    'function TAtomicISize.FetchAdd(ADelta: PtrInt; AOrder: memory_order_t): PtrInt;',
    'function TAtomicISize.Increment(AOrder: memory_order_t): PtrInt;');
  LTypesUSizeFetchSection := ExtractImplementationSection(LAtomicTypesSource,
    'function TAtomicUSize.FetchAdd(ADelta: PtrUInt; AOrder: memory_order_t): PtrUInt;',
    'function TAtomicUSize.Increment(AOrder: memory_order_t): PtrUInt;');
  LTypesRefCountLockFreeSection := ExtractImplementationSection(LAtomicTypesSource,
    'class function TAtomicRefCount.is_lock_free: Boolean;',
    'function TAtomicRefCount.Load(AOrder: memory_order_t): PtrUInt;');
  LTypesBoolLockFreeSection := ExtractImplementationSection(LAtomicTypesSource,
    'class function TAtomicBool.is_lock_free: Boolean;',
    'function TAtomicBool.Load(AOrder: memory_order_t): Boolean;');
  LTypesBoolFetchNandSection := ExtractImplementationSection(LAtomicTypesSource,
    'function TAtomicBool.FetchNand(AValue: Boolean; AOrder: memory_order_t): Boolean;',
    'function TAtomicBool.GetMut: PInt32;');
  LTypesPtrLockFreeSection := ExtractImplementationSection(LAtomicTypesSource,
    'class function TAtomicPtr.is_lock_free: Boolean;',
    'function TAtomicPtr.Load(AOrder: memory_order_t): PT;');
  LFetchAddFallbackSection := ExtractImplementationSection(LAtomicSource,
    'function _atomic_fetch_add_64_x86(var aObj: Int64; aArg: Int64): Int64;',
    '{$ENDIF}');
  LLoad32Section := ExtractImplementationSection(LAtomicSource,
    'function atomic_load(var aObj: Int32; aOrder: memory_order_t): Int32;',
    'function atomic_load(var aObj: Int32): Int32;');
  LLoad64Section := ExtractImplementationSection(LAtomicSource,
    'function atomic_load_64(var aObj: Int64; aOrder: memory_order_t): Int64;',
    'function atomic_load_64(var aObj: Int64): Int64;');
  LLoad32SeqCstSection := ExtractSection(LLoad32Section,
    '    mo_seq_cst:',
    '      end;');
  LLoad64SeqCstSection := ExtractSection(LLoad64Section,
    '    mo_seq_cst:',
    '      end;');
  LDefaultLoad32Section := ExtractImplementationSection(LAtomicSource,
    'function atomic_load(var aObj: Int32): Int32;',
    'function atomic_load(var aObj: UInt32; aOrder: memory_order_t): UInt32;');
  LDefaultLoad64Section := ExtractImplementationSection(LAtomicSource,
    'function atomic_load_64(var aObj: Int64): Int64;',
    'function atomic_load_64(var aObj: UInt64; aOrder: memory_order_t): UInt64;');
  LDefaultLoadPtrSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_load(var aObj: Pointer): Pointer;',
    '{$IFDEF CPU64}');
  LDefaultLoadPtrIntSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_load(var aObj: PtrInt): PtrInt;',
    'function atomic_load(var aObj: PtrUInt; aOrder: memory_order_t): PtrUInt;');
  LStore32Section := ExtractImplementationSection(LAtomicSource,
    'procedure atomic_store(var aObj: Int32; aDesired: Int32; aOrder: memory_order_t);',
    'procedure atomic_store(var aObj: Int32; aDesired: Int32);');
  LStore64Section := ExtractImplementationSection(LAtomicSource,
    'procedure atomic_store_64(var aObj: Int64; aDesired: Int64; aOrder: memory_order_t);',
    'procedure atomic_store_64(var aObj: Int64; aDesired: Int64);');
  LStore32SeqCstSection := ExtractSection(LStore32Section,
    '    mo_seq_cst:',
    '  end;');
  LStore64SeqCstSection := ExtractSection(LStore64Section,
    '    mo_seq_cst:',
    '  end;');
  LDefaultStore32Section := ExtractImplementationSection(LAtomicSource,
    'procedure atomic_store(var aObj: Int32; aDesired: Int32);',
    'procedure atomic_store(var aObj: UInt32; aDesired: UInt32; aOrder: memory_order_t);');
  LDefaultStoreUInt32Section := ExtractImplementationSection(LAtomicSource,
    'procedure atomic_store(var aObj: UInt32; aDesired: UInt32);',
    '{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}');
  LDefaultStore64Section := ExtractImplementationSection(LAtomicSource,
    'procedure atomic_store_64(var aObj: Int64; aDesired: Int64);',
    'procedure atomic_store_64(var aObj: UInt64; aDesired: UInt64; aOrder: memory_order_t);');
  LDefaultStoreUInt64Section := ExtractImplementationSection(LAtomicSource,
    'procedure atomic_store_64(var aObj: UInt64; aDesired: UInt64);',
    '{$ENDIF}');
  LDefaultStorePtrSection := ExtractImplementationSection(LAtomicSource,
    'procedure atomic_store(var aObj: Pointer; aDesired: Pointer);',
    '{$IFDEF CPU64}');
  LDefaultStorePtrIntSection := ExtractImplementationSection(LAtomicSource,
    'procedure atomic_store(var aObj: PtrInt; aDesired: PtrInt);',
    'procedure atomic_store(var aObj: PtrUInt; aDesired: PtrUInt; aOrder: memory_order_t);');
  LDefaultStorePtrUIntSection := ExtractImplementationSection(LAtomicSource,
    'procedure atomic_store(var aObj: PtrUInt; aDesired: PtrUInt);',
    '{$ENDIF}');
  LCasStrong32DualSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_compare_exchange_strong(var aObj: Int32; var aExpected: Int32; aDesired: Int32;' + LineEnding +
    '  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;',
    'function atomic_compare_exchange_strong(var aObj: UInt32; var aExpected: UInt32; aDesired: UInt32;');
  LCasStrongPtrIntDualSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_compare_exchange_strong(var aObj: PtrInt; var aExpected: PtrInt; aDesired: PtrInt;' + LineEnding +
    '  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;',
    'function atomic_compare_exchange_strong(var aObj: PtrUInt; var aExpected: PtrUInt; aDesired: PtrUInt;');
  LCasStrong64DualSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_compare_exchange_strong_64(var aObj: Int64; var aExpected: Int64; aDesired: Int64;' + LineEnding +
    '  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;',
    'function atomic_compare_exchange_strong_64(var aObj: UInt64; var aExpected: UInt64; aDesired: UInt64;');
  LTaggedPtrLoadSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_tagged_ptr_load(var aObj: atomic_tagged_ptr_t; aOrder: memory_order_t): atomic_tagged_ptr_t;',
    'function atomic_tagged_ptr_load(var aObj: atomic_tagged_ptr_t): atomic_tagged_ptr_t;');
  LTaggedPtrStoreSection := ExtractImplementationSection(LAtomicSource,
    'procedure atomic_tagged_ptr_store(var aObj: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t; aOrder: memory_order_t);',
    'procedure atomic_tagged_ptr_store(var aObj: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t);');
  LTaggedPtrStrongCasSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_tagged_ptr_compare_exchange_strong(var aObj: atomic_tagged_ptr_t; var aExpected: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t;' + LineEnding +
    '  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;',
    'function atomic_tagged_ptr_compare_exchange_strong(var aObj: atomic_tagged_ptr_t; var aExpected: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t): Boolean;');
  LTaggedPtrWeakCasSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_tagged_ptr_compare_exchange_weak(var aObj: atomic_tagged_ptr_t; var aExpected: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t;' + LineEnding +
    '  aSuccessOrder, aFailureOrder: memory_order_t): Boolean;',
    'function atomic_tagged_ptr_compare_exchange_weak(var aObj: atomic_tagged_ptr_t; var aExpected: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t): Boolean;');
  LPascalCaseCas32Section := ExtractImplementationSection(LAtomicSource,
    'function AtomicCompareExchange32(var ATarget: Int32; const AExpected, ADesired: Int32; const AOrder: TMemoryOrder): Int32;',
    'function AtomicFetchAdd32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;');
  LPascalCaseCas64Section := ExtractImplementationSection(LAtomicSource,
    'function AtomicCompareExchange64(var ATarget: Int64; const AExpected, ADesired: Int64; const AOrder: TMemoryOrder): Int64;',
    'function AtomicFetchAdd64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder): Int64;');
  LPascalCaseCasPtrSection := ExtractImplementationSection(LAtomicSource,
    'function AtomicCompareExchangePtr(var ATarget: Pointer; const AExpected, ADesired: Pointer; const AOrder: TMemoryOrder): Pointer;',
    'procedure AtomicThreadFence(const AOrder: TMemoryOrder);');
  LFacadePtrStrongCasSection := ExtractImplementationSection(LAtomicSource,
    'function TAtomicPtr.CompareExchangeStrong(var AExpected: PT; ADesired: PT;',
    'function TAtomicPtr.CompareExchangeWeak(var AExpected: PT; ADesired: PT;');
  LFacadePtrWeakCasSection := ExtractImplementationSection(LAtomicSource,
    'function TAtomicPtr.CompareExchangeWeak(var AExpected: PT; ADesired: PT;',
    'function TAtomicPtr.GetMut: Pointer;');
  LDefaultTaggedPtrLoadSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_tagged_ptr_load(var aObj: atomic_tagged_ptr_t): atomic_tagged_ptr_t;',
    'procedure atomic_tagged_ptr_store(var aObj: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t; aOrder: memory_order_t);');
  LDefaultTaggedPtrStoreSection := ExtractImplementationSection(LAtomicSource,
    'procedure atomic_tagged_ptr_store(var aObj: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t);',
    'function atomic_tagged_ptr_exchange(var aObj: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t; aOrder: memory_order_t): atomic_tagged_ptr_t;');
  LTaggedPtrUpdateSection := ExtractImplementationSection(LAtomicSource,
    'procedure atomic_tagged_ptr_update(var aObj: atomic_tagged_ptr_t; aPtr: Pointer);',
    'procedure atomic_tagged_ptr_update_tag(var aObj: atomic_tagged_ptr_t; aTag:');
  LTaggedPtrUpdateTagSection := ExtractImplementationSection(LAtomicSource,
    'procedure atomic_tagged_ptr_update_tag(var aObj: atomic_tagged_ptr_t; aTag:',
    'procedure CpuPause;');
  LAtomicWaitSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_wait(var aObj: Int32; aExpected: Int32; const aTimeoutNs: Int64): Int32;',
    'function atomic_wait(var aObj: UInt32; aExpected: UInt32; const aTimeoutNs: Int64): Int32;');
  LAtomicNotifyOneSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_notify_one(var aObj: Int32): Int32;',
    'function atomic_notify_one(var aObj: UInt32): Int32;');
  LAtomicNotifyAllSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_notify_all(var aObj: Int32): Int32;',
    'function atomic_notify_all(var aObj: UInt32): Int32;');
  LCompatFacadeTestSection := ExtractSection(LAtomicTestSource,
    'procedure TestAtomicCompatFacade;' + LineEnding +
    'var',
    'procedure TestAtomicCompatAliasBehavior;');
  LCompatAliasTestSection := ExtractSection(LAtomicTestSource,
    'procedure TestAtomicCompatAliasBehavior;' + LineEnding +
    'var',
    'procedure TestAtomicTaggedPointer;');
  LTypedInt64ContractSection := ExtractSection(LAtomicTestSource,
    '{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}' + LineEnding +
    'procedure TestAtomicInt64UInt64Contract;',
    '{$ENDIF}' + LineEnding +
    LineEnding +
    '{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}' + LineEnding +
    'procedure TestAtomicInt64UInt64FetchContract;');
  LTypedInt64FetchContractSection := ExtractSection(LAtomicTestSource,
    '{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}' + LineEnding +
    'procedure TestAtomicInt64UInt64FetchContract;',
    '{$ENDIF}' + LineEnding +
    LineEnding +
    'procedure TestAtomicBoolContract;');
  LRunnerSection := ExtractSection(LAtomicTestSource,
    'begin' + LineEnding +
    '  T := TTestRunner.Create(''nextpas.core.atomic'');',
    '  T.Summary;');
  LAtomicFlagTestAndSetSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_flag_test_and_set(var aFlag: atomic_flag_t): Boolean;',
    'function atomic_flag_test(var aFlag: atomic_flag_t): Boolean;');
  LAtomicFlagTestSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_flag_test(var aFlag: atomic_flag_t): Boolean;',
    'procedure atomic_flag_clear(var aFlag: atomic_flag_t);');
  LAtomicFlagClearSection := ExtractImplementationSection(LAtomicSource,
    'procedure atomic_flag_clear(var aFlag: atomic_flag_t);',
    'function atomic_is_lock_free_32: Boolean;');
  LRefCountTypeSection := ExtractSection(LAtomicTypesSource,
    '  TAtomicRefCount = record',
    '  { TAtomicPtr - 泛型原子指针 }');
  LRefCountIncSection := ExtractImplementationSection(LAtomicTypesSource,
    'function TAtomicRefCount.Inc: PtrUInt;',
    'function TAtomicRefCount.TryInc(out ANewValue: PtrUInt): Boolean;');
  LRefCountTryIncSection := ExtractImplementationSection(LAtomicTypesSource,
    'function TAtomicRefCount.TryInc(out ANewValue: PtrUInt): Boolean;',
    'function TAtomicRefCount.Dec: PtrUInt;');
  LRefCountDecSection := ExtractImplementationSection(LAtomicTypesSource,
    'function TAtomicRefCount.Dec: PtrUInt;',
    'function TAtomicRefCount.IntoInner: PtrUInt;');
  LFetchAnd64Section := ExtractImplementationSection(LAtomicSource,
    'function atomic_fetch_and_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64;',
    'function atomic_fetch_and_64(var aObj: UInt64; aArg: UInt64; aOrder: memory_order_t): UInt64;');
  LFetchOr64Section := ExtractImplementationSection(LAtomicSource,
    'function atomic_fetch_or_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64;',
    'function atomic_fetch_or_64(var aObj: UInt64; aArg: UInt64; aOrder: memory_order_t): UInt64;');
  LFetchXor64Section := ExtractImplementationSection(LAtomicSource,
    'function atomic_fetch_xor_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64;',
    'function atomic_fetch_xor_64(var aObj: UInt64; aArg: UInt64; aOrder: memory_order_t): UInt64;');
  LFetchMax64Section := ExtractImplementationSection(LAtomicSource,
    'function atomic_fetch_max_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64;',
    'function atomic_fetch_max_64(var aObj: Int64; aArg: Int64): Int64;');
  LFetchMin64Section := ExtractImplementationSection(LAtomicSource,
    'function atomic_fetch_min_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64;',
    'function atomic_fetch_min_64(var aObj: Int64; aArg: Int64): Int64;');
  LFetchNand64Section := ExtractImplementationSection(LAtomicSource,
    'function atomic_fetch_nand_64(var aObj: Int64; aArg: Int64; aOrder: memory_order_t): Int64;',
    'function atomic_fetch_nand_64(var aObj: Int64; aArg: Int64): Int64;');
  LPointerFetchAddSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_fetch_add(var aObj: Pointer; aOffset: PtrInt): Pointer;',
    '{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}');
  LPointerFetchSubSection := ExtractImplementationSection(LAtomicSource,
    'function atomic_fetch_sub(var aObj: Pointer; aOffset: PtrInt): Pointer;',
    '{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}');
  LDefaultFetchMax32Section := ExtractImplementationSection(LAtomicSource,
    'function atomic_fetch_max(var aObj: Int32; aArg: Int32): Int32;',
    '{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}');
  LDefaultFetchMin32Section := ExtractImplementationSection(LAtomicSource,
    'function atomic_fetch_min(var aObj: Int32; aArg: Int32): Int32;',
    '{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}');
  LDefaultFetchNand32Section := ExtractImplementationSection(LAtomicSource,
    'function atomic_fetch_nand(var aObj: Int32; aArg: Int32): Int32;',
    '{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}');
  LDefaultFetchMax64Section := ExtractImplementationSection(LAtomicSource,
    'function atomic_fetch_max_64(var aObj: Int64; aArg: Int64): Int64;',
    'function atomic_fetch_min(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32;');
  LDefaultFetchMin64Section := ExtractImplementationSection(LAtomicSource,
    'function atomic_fetch_min_64(var aObj: Int64; aArg: Int64): Int64;',
    'function atomic_fetch_nand(var aObj: Int32; aArg: Int32; aOrder: memory_order_t): Int32;');
  LDefaultFetchNand64Section := ExtractImplementationSection(LAtomicSource,
    'function atomic_fetch_nand_64(var aObj: Int64; aArg: Int64): Int64;',
    'function atomic_flag_test_and_set(var aFlag: atomic_flag_t): Boolean;');

  Check(Pos('mo_relaxed: 无效，会触发运行时错误', LAtomicSource) = 0,
    'atomic_thread_fence docs must not claim mo_relaxed raises runtime error');
  CheckNotContains(LAtomicSource, '@performance 零开销（仅编译器指令）',
    'atomic_signal_fence docs must not promise zero runtime overhead');
  CheckContains(LAtomicSource, 'Legacy PascalCase compatibility facade.',
    'main atomic unit must mark PascalCase wrappers as legacy compatibility surface');
  CheckContains(LAtomicSource, 'Prefer atomic_* or TAtomic* in new code.',
    'main atomic unit must recommend canonical C-style or typed APIs');
  CheckNotContains(LAtomicSource,
    'On x86/x86_64, a plain load is already strongly ordered at the CPU level;',
    'seq_cst load docs must not keep the old plain-load x86 mapping');
  CheckNotContains(LAtomicSource,
    'use only a compiler barrier to prevent reordering.',
    'seq_cst load docs must not describe compiler-barrier-only x86 mapping');
  CheckContains(LAtomicCoreSource, 'procedure atomic_seq_cst_fence;',
    'atomic core must define a dedicated seq_cst fence helper');
  CheckNotContains(LSignalFenceSection, 'ReadWriteBarrier',
    'atomic_signal_fence must not use hardware fences in live core path');
  CheckContains(LSignalFenceSection, '_compiler_signal_fence;',
    'atomic_signal_fence must call a compiler barrier helper in live core path');
  CheckContains(LSignalFenceHelperSection, 'asm',
    'atomic_signal_fence compiler barrier helper must be assembler-based');
  CheckContains(LSignalFenceHelperSection, 'end;',
    'atomic_signal_fence compiler barrier helper must remain empty assembler barrier');
  CheckContains(LSeqCstFenceHelperSection, 'CPUPPC',
    'seq_cst fence helper must specialize PPC/PPC64');
  CheckContains(LSeqCstFenceHelperSection, 'sync',
    'seq_cst fence helper must use a heavyweight PPC sync fence');
  CheckContains(LTaggedPtrSection,
    'raise EArgumentError.Create(''atomic_tagged_ptr: pointer not aligned for low-bit tag packing'')',
    'non-x86 tagged pointer packing must reject misaligned pointers in release builds');
  CheckContains(LTaggedPtrSection,
    'raise EArgumentError.Create(''atomic_tagged_ptr: tag does not fit TAG_BITS'')',
    'non-x86 tagged pointer packing must reject oversized tags in release builds');
  CheckContains(LTaggedPtrNextSection,
    'if LTag = MAX_TAG then' + LineEnding +
    '    Result := 0',
    'tagged pointer next must wrap back to zero after MAX_TAG');
  CheckContains(LThreadFenceSection, 'mo_seq_cst: atomic_seq_cst_fence;',
    'atomic_thread_fence seq_cst must route through the dedicated seq_cst fence helper');
  CheckContains(LAtomicCompatSource, 'Legacy PascalCase compatibility facade mirrored for older call sites.',
    'compat unit must document PascalCase compatibility ownership');
  CheckContains(LAtomicCompatSource, 'function AtomicLoad32',
    'compat unit must mirror PascalCase load/store facade');
  CheckContains(LAtomicCompatSource, 'procedure AtomicThreadFence',
    'compat unit must mirror PascalCase fence facade');
  CheckContains(LAtomicCompatSource,
    'function atomic_fetch_add(var aObj: Pointer; aArg: Pointer): Pointer;',
    'compat unit must own the legacy pointer fetch-add overload');
  CheckContains(LAtomicCompatSource,
    'function atomic_fetch_sub(var aObj: Pointer; aArg: Pointer): Pointer;',
    'compat unit must own the legacy pointer fetch-sub overload');
  CheckContains(LAtomicCompatSource,
    'function atomic_fetch_and(var aObj: Pointer; aArg: Pointer): Pointer;',
    'compat unit must own the legacy pointer fetch-and overload');
  CheckContains(LAtomicCompatSource,
    'function atomic_fetch_or(var aObj: Pointer; aArg: Pointer): Pointer;',
    'compat unit must own the legacy pointer fetch-or overload');
  CheckContains(LAtomicCompatSource,
    'function atomic_fetch_xor(var aObj: Pointer; aArg: Pointer): Pointer;',
    'compat unit must own the legacy pointer fetch-xor overload');
  CheckContains(LAtomicCompatSource,
    'function atomic_increment(var aObj: Pointer): Pointer;',
    'compat unit must own the legacy pointer increment overload');
  CheckContains(LAtomicCompatSource,
    'function atomic_decrement(var aObj: Pointer): Pointer;',
    'compat unit must own the legacy pointer decrement overload');
  CheckContains(LAtomicSource,
    'function atomic_fetch_add(var aObj: Pointer; aOffset: PtrInt): Pointer;',
    'main atomic facade must keep canonical pointer offset fetch-add');
  CheckContains(LAtomicSource,
    'function atomic_fetch_sub(var aObj: Pointer; aOffset: PtrInt): Pointer;',
    'main atomic facade must keep canonical pointer offset fetch-sub');
  CheckEqual(Int64(2), Int64(CountOccurrences(LAtomicSource,
    'function atomic_fetch_add(var aObj: Pointer;')),
    'main atomic facade must not add legacy pointer fetch-add overloads');
  CheckEqual(Int64(2), Int64(CountOccurrences(LAtomicSource,
    'function atomic_fetch_sub(var aObj: Pointer;')),
    'main atomic facade must not add legacy pointer fetch-sub overloads');
  CheckNotContains(LAtomicSource,
    'function atomic_fetch_and(var aObj: Pointer;',
    'legacy pointer fetch-and overload must stay out of the main atomic facade');
  CheckNotContains(LAtomicSource,
    'function atomic_fetch_or(var aObj: Pointer;',
    'legacy pointer fetch-or overload must stay out of the main atomic facade');
  CheckNotContains(LAtomicSource,
    'function atomic_fetch_xor(var aObj: Pointer;',
    'legacy pointer fetch-xor overload must stay out of the main atomic facade');
  CheckNotContains(LAtomicSource,
    'function atomic_increment(var aObj: Pointer)',
    'legacy pointer increment overload must stay out of the main atomic facade');
  CheckNotContains(LAtomicSource,
    'function atomic_decrement(var aObj: Pointer)',
    'legacy pointer decrement overload must stay out of the main atomic facade');
  CheckContains(LX8664SnapshotSource, 'Archived historical x86_64 atomic implementation snapshot.',
    'archived x86_64 snapshot must be marked historical');
  CheckContains(LX8664SnapshotSource, 'Documentation archive only.',
    'archived x86_64 snapshot must declare documentation-only status');
  CheckContains(LX8664SnapshotSource, 'This file is not part of the live source set.',
    'archived x86_64 snapshot must declare non-live status');
  CheckContains(LAtomicDocsReadme, '# nextpas.core.atomic',
    'atomic README must exist as the module documentation entrypoint');
  CheckContains(LAtomicDocsReadme, 'nextpas.core.atomic.core',
    'atomic README must explain the core submodule');
  CheckContains(LAtomicDocsReadme, 'nextpas.core.atomic.types',
    'atomic README must explain the typed record submodule');
  CheckContains(LAtomicDocsReadme, 'nextpas.core.atomic.compat',
    'atomic README must document legacy compatibility ownership');
  CheckContains(LAtomicDocsReadme,
    'pointer arithmetic/bitwise overloads stay in `nextpas.core.atomic.compat` and must not be added to the main facade',
    'atomic README must explicitly freeze legacy pointer overload ownership');
  CheckContains(LAtomicDocsReadme,
    'legacy pointer arithmetic/bitwise overloads and helper aliases have focused runtime coverage',
    'atomic README must document compat alias runtime coverage');
  CheckContains(LAtomicTestSource,
    'T.Run(''compat public alias behavior'', @TestAtomicCompatAliasBehavior);',
    'atomic runner must register compat alias runtime coverage');
  CheckContains(LCompatFacadeTestSection,
    'compat AtomicCompareExchange32 must return observed value on mismatch',
    'compat PascalCase runtime test must cover Int32 CAS mismatch observation');
  CheckContains(LCompatFacadeTestSection,
    'compat AtomicCompareExchange32 must publish desired value on match',
    'compat PascalCase runtime test must cover Int32 CAS match publish');
  CheckContains(LCompatFacadeTestSection,
    'compat AtomicCompareExchangePtr must return observed pointer on mismatch',
    'compat PascalCase runtime test must cover pointer CAS mismatch observation');
  CheckContains(LCompatFacadeTestSection,
    'compat AtomicCompareExchangePtr must publish desired pointer on match',
    'compat PascalCase runtime test must cover pointer CAS match publish');
  CheckContains(LCompatFacadeTestSection,
    'AtomicCompareExchange32(LVal, 99, 21, moRelease)',
    'compat PascalCase runtime test must exercise release success-order CAS failure derivation');
  CheckContains(LCompatFacadeTestSection,
    'AtomicCompareExchange32(LVal, 13, 21, moAcqRel)',
    'compat PascalCase runtime test must exercise acq_rel success-order CAS success path');
  CheckContains(LCompatFacadeTestSection,
    'AtomicCompareExchangePtr(LPtr, @LSecond, nil, moRelease)',
    'compat PascalCase runtime test must exercise pointer release success-order CAS failure derivation');
  CheckContains(LCompatFacadeTestSection,
    'AtomicCompareExchangePtr(LPtr, @LFirst, @LSecond, moAcqRel)',
    'compat PascalCase runtime test must exercise pointer acq_rel success-order CAS success path');
  CheckContains(LCompatAliasTestSection, 'nextpas.core.atomic.compat.atomic_fetch_add',
    'compat alias runtime test must call the compat pointer fetch-add overload');
  CheckContains(LCompatAliasTestSection, 'nextpas.core.atomic.compat.atomic_fetch_sub',
    'compat alias runtime test must call the compat pointer fetch-sub overload');
  CheckContains(LCompatAliasTestSection, 'nextpas.core.atomic.compat.atomic_fetch_and',
    'compat alias runtime test must call the compat pointer fetch-and overload');
  CheckContains(LCompatAliasTestSection, 'nextpas.core.atomic.compat.atomic_fetch_or',
    'compat alias runtime test must call the compat pointer fetch-or overload');
  CheckContains(LCompatAliasTestSection, 'nextpas.core.atomic.compat.atomic_fetch_xor',
    'compat alias runtime test must call the compat pointer fetch-xor overload');
  CheckContains(LCompatAliasTestSection, 'nextpas.core.atomic.compat.atomic_increment',
    'compat alias runtime test must call the compat pointer increment overload');
  CheckContains(LCompatAliasTestSection, 'nextpas.core.atomic.compat.atomic_decrement',
    'compat alias runtime test must call the compat pointer decrement overload');
  CheckContains(LCompatAliasTestSection, 'nextpas.core.atomic.compat.atomic_load_ptr',
    'compat alias runtime test must call the compat pointer helper load alias');
  CheckContains(LCompatAliasTestSection, 'nextpas.core.atomic.compat.atomic_store_ptr',
    'compat alias runtime test must call the compat pointer helper store alias');
  CheckContains(LCompatAliasTestSection, 'nextpas.core.atomic.compat.atomic_compare_exchange_strong_ptr',
    'compat alias runtime test must call the compat pointer helper CAS alias');
  CheckContains(LCompatAliasTestSection, 'nextpas.core.atomic.compat.make_atomic_tagged_ptr_t',
    'compat alias runtime test must call the compat tagged pointer constructor alias');
  CheckContains(LCompatAliasTestSection, 'nextpas.core.atomic.compat.atomic_load_atomic_tagged_ptr_t',
    'compat alias runtime test must call the compat tagged pointer load alias');
  CheckContains(LCompatAliasTestSection, 'nextpas.core.atomic.compat.atomic_store_atomic_tagged_ptr_t',
    'compat alias runtime test must call the compat tagged pointer store alias');
  CheckContains(LCompatAliasTestSection, 'nextpas.core.atomic.compat.atomic_compare_exchange_strong_atomic_tagged_ptr_t',
    'compat alias runtime test must call the compat tagged pointer CAS alias');
  CheckContains(LCompatAliasTestSection,
    'compat pointer arithmetic fetch-add must return previous pointer value',
    'compat alias runtime test must cover pointer-sized fetch-add return-old semantics');
  CheckContains(LCompatAliasTestSection,
    'compat pointer bitwise fetch-and must publish masked pointer bits',
    'compat alias runtime test must cover pointer-sized bitwise semantics');
  CheckContains(LCompatAliasTestSection,
    'compat pointer helper CAS must update expected on mismatch',
    'compat alias runtime test must cover helper pointer CAS mismatch write-back');
  CheckContains(LCompatAliasTestSection,
    'compat tagged helper CAS must publish desired tag',
    'compat alias runtime test must cover tagged helper CAS success semantics');
  CheckContains(LAtomicDocsReadme, 'atomic_*',
    'atomic README must name the canonical function API');
  CheckContains(LAtomicDocsReadme, 'TAtomic*',
    'atomic README must name the typed record API');
  CheckContains(LAtomicDocsReadme,
    '`Load` defaults to `mo_relaxed`; `Inc` must not resurrect a zero refcount, and `TryInc` returns `False` instead of resurrecting when the count is already zero.',
    'atomic README must document TAtomicRefCount zero-state increment rules');
  CheckContains(LAtomicDocsReadme,
    '`TryInc` writes `0` to `ANewValue` when the refcount is already zero, so failure leaves a stable non-resurrected out value for destruction-side callers.',
    'atomic README must document TAtomicRefCount zero-state TryInc out-value contract');
  CheckContains(LAtomicDocsReadme,
    '`With at least one live owner and no overflow, `TryInc` is the concurrent borrow path: it succeeds from non-zero state, and balanced `Dec` calls do not publish zero before the last owner releases its reference.',
    'atomic README must document TAtomicRefCount concurrent borrow contract');
  CheckContains(LAtomicDocsReadme,
    '`TryInc` racing the last owner release is linearized by the CAS result: success means the borrow observed and extended a non-zero count before zero, failure means the zero-state release won first and clears `ANewValue` to `0`, and across the owner release plus every successful borrowed release exactly one `Dec` performs the final drop to zero.',
    'atomic README must document TAtomicRefCount terminal-race contract');
  CheckContains(LAtomicDocsReadme,
    '`Dec` publishes the release-side decrement, and a final drop to zero issues an acquire fence before destruction-side cleanup proceeds.',
    'atomic README must document TAtomicRefCount final-drop ordering');
  CheckContains(LAtomicDocsReadme,
    '`Inc` and `TryInc` raise `EResourceExhaustedError` on `High(PtrUInt)` overflow, and `Dec` raises `EInvalidOperationError` if the refcount is already zero.',
    'atomic README must document TAtomicRefCount overflow and underflow errors');
  CheckContains(LAtomicDocsReadme, 'facade exposes scalar typed records, `TAtomicRefCount`, and generic `TAtomicPtr<T>`',
    'atomic README must document the typed-record facade boundary');
  CheckContains(LAtomicDocsReadme,
    '`TAtomicInt32` and `TAtomicUInt32` follow `atomic_is_lock_free_32`; `Increment`/`Decrement` return the new value after adding or subtracting one, and `GetMut` / `IntoInner` stay exclusive-access escape hatches rather than concurrent APIs.',
    'atomic README must document the 32-bit typed-record lock-free and convenience contract');
  CheckContains(LAtomicDocsReadme,
    '`TAtomicInt32` and `TAtomicUInt32` keep the scalar RMW return-old semantics in typed form: `FetchAdd` / `FetchSub` / `FetchAnd` / `FetchOr` / `FetchXor` return the previous value and publish the updated Int32/UInt32 payload through the wrapper storage.',
    'atomic README must document the 32-bit typed-record RMW contract');
  CheckContains(LAtomicDocsReadme,
    '`TAtomicInt64` and `TAtomicUInt64` follow `atomic_is_lock_free_64`; `Increment`/`Decrement` return the new value after adding or subtracting one, and `GetMut` / `IntoInner` stay exclusive-access escape hatches rather than concurrent APIs.',
    'atomic README must document the 64-bit typed-record lock-free and convenience contract');
  CheckContains(LAtomicDocsReadme,
    '`TAtomicInt64` and `TAtomicUInt64` are compiled only under `CPU64 OR CPUX86`; tests for their runtime contracts use the same gate, and targets outside that gate must not be reported as having this public typed 64-bit surface.',
    'atomic README must document the typed 64-bit public-surface compile gate');
  CheckContains(LAtomicDocsReadme,
    'On i386, `atomic_is_lock_free_64` is runtime-detected from CMPXCHG8B support; when CMPXCHG8B is unavailable, the typed 64-bit API is still present but 64-bit operations use the fallback lock path.',
    'atomic README must not equate the i386 typed 64-bit API surface with guaranteed lock-free runtime behavior');
  CheckContains(LAtomicDocsReadme,
    '`TAtomicInt64` and `TAtomicUInt64` keep the scalar 64-bit RMW return-old semantics in typed form: `FetchAdd` / `FetchSub` / `FetchAnd` / `FetchOr` / `FetchXor` return the previous value and publish the updated Int64/UInt64 payload through the wrapper storage.',
    'atomic README must document the 64-bit typed-record RMW contract');
  CheckContains(LAtomicDocsReadme,
    '`TAtomicISize` and `TAtomicUSize` follow `atomic_is_lock_free_ptr`; `Increment`/`Decrement` return the new value after adding or subtracting one, and `GetMut` / `IntoInner` stay exclusive-access escape hatches rather than concurrent APIs.',
    'atomic README must document the pointer-sized typed-record lock-free and convenience contract');
  CheckContains(LAtomicDocsReadme,
    '`TAtomicISize` and `TAtomicUSize` keep the scalar pointer-sized RMW return-old semantics in typed form: `FetchAdd` / `FetchSub` / `FetchAnd` / `FetchOr` / `FetchXor` return the previous value and publish the updated PtrInt/PtrUInt payload through the wrapper storage.',
    'atomic README must document the pointer-sized typed-record RMW contract');
  CheckContains(LAtomicDocsReadme,
    '`TAtomicInt32`/`TAtomicUInt32`, `TAtomicInt64`/`TAtomicUInt64`, and `TAtomicISize`/`TAtomicUSize` share the same convenience CAS contract: `CompareExchangeStrong` / `CompareExchangeWeak` write the observed value back to `AExpected` on mismatch, and a matching weak CAS publishes the replacement value through the typed record facade.',
    'atomic README must freeze scalar typed-record CAS failure write-back and weak-CAS convenience truth');
  CheckContains(LAtomicDocsReadme,
    '`TAtomicBool` stores a normalized `0/1` Int32 payload, `Load`/`Store`/`Exchange` map that payload to Boolean, `FetchAnd/Or/Xor/Nand` return the previous Boolean value while keeping the stored domain within `False/True`, and `is_lock_free` follows `atomic_is_lock_free_32`.',
    'atomic README must document the TAtomicBool normalized bool-domain contract');
  CheckContains(LAtomicDocsReadme,
    '`TAtomicPtr<T>` follows `atomic_is_lock_free_ptr`; `Load`/`Store`/`Exchange` publish the pointed-to address, strong/weak CAS update both the stored pointer and the observed expected pointer, and `GetMut` / `IntoInner` stay exclusive-access escape hatches rather than concurrent APIs.',
    'atomic README must document the TAtomicPtr lock-free and convenience contract');
  CheckContains(LAtomicDocsReadme,
    '`TAtomicPtr<T>` single-order CAS normalizes `mo_consume` success to acquire and derives a legal failure order; failure order never includes release or acq_rel.',
    'atomic README must document facade TAtomicPtr CAS failure-order derivation');
  CheckContains(LAtomicDocsReadme, 'memory_order_t',
    'atomic README must describe memory-order semantics');
  CheckContains(LAtomicDocsReadme, 'mo_seq_cst',
    'atomic README must document the default strongest order');
  CheckContains(LAtomicDocsReadme,
    'Invalid explicit orders raise `EArgumentError`: load rejects `mo_release`/`mo_acq_rel`, store rejects `mo_consume`/`mo_acquire`/`mo_acq_rel`, and dual-order CAS rejects release/acq_rel failure orders or failure orders stronger than success.',
    'atomic README must document invalid explicit memory-order contract');
  CheckContains(LAtomicDocsReadme,
    '`atomic_fetch_add/sub(var Pointer; PtrInt)` are the canonical main-facade pointer arithmetic APIs: they apply byte offsets, return the previous pointer, and publish the adjusted pointer; pointer bitwise overloads remain compat-only.',
    'atomic README must document main-facade pointer arithmetic contract');
  CheckContains(LAtomicDocsReadme,
    '`atomic_fetch_max/min/nand` return the previous value, publish `max(old, arg)` / `min(old, arg)` / `not (old and arg)`, and their no-argument overloads default to `mo_seq_cst`.',
    'atomic README must document fetch_max/min/nand contract');
  CheckContains(LAtomicDocsReadme,
    'Tagged pointer explicit load/store/CAS APIs follow the same invalid-order contract and raise `EArgumentError` when callers pass illegal explicit orders.',
    'atomic README must document tagged pointer invalid explicit-order contract');
  CheckContains(LAtomicDocsReadme, 'AtomicWait/Notify',
    'atomic README must document the wait/notify surface');
  CheckContains(LAtomicDocsReadme, 'platform_wait_address32',
    'atomic README must disclose the current 32-bit wait-address seam');
  CheckContains(LAtomicDocsReadme,
    '`atomic_flag_t` and `TAtomicFlag` model C++ `atomic_flag`: `test_and_set` returns the previous set state, `clear` resets the flag, and `test` observes without modifying.',
    'atomic README must document atomic_flag operation semantics');
  CheckContains(LAtomicDocsReadme, 'core/docs/archive/atomic/nextpas.core.atomic.x86_64.snapshot.txt',
    'atomic README must point to the historical x86_64 archive');
  CheckContains(LAtomicDocsReadme, 'make hygiene',
    'atomic README must list hygiene verification');
  CheckContains(LAtomicDocsReadme, 'make -C core/tests/nextpas.core.atomic/test_atomic clean test',
    'atomic README must list the focused atomic gate');
  CheckContains(LAtomicDocsReadme, 'git diff --check',
    'atomic README must list whitespace verification');
  CheckContains(LAtomicDocsReadme,
    'make -C core/benchmarks/nextpas.core.atomic/bench_atomic clean run',
    'atomic README must list the focused benchmark command');
  CheckContains(LAtomicDocsReadme,
    'make -C core/benchmarks/nextpas.core.atomic/bench_atomic run-rust-compare',
    'atomic README must route the Rust baseline through the benchmark Makefile');
  CheckContains(LAtomicDocsReadme,
    'make -C core/benchmarks/nextpas.core.atomic/bench_atomic run-go-compare',
    'atomic README must route the Go baseline through the benchmark Makefile');
  CheckContains(LAtomicDocsReadme,
    'make -C core/benchmarks/nextpas.core.atomic/bench_atomic run-cpp-compare',
    'atomic README must route the C++ baseline through the benchmark Makefile');
  CheckContains(LAtomicDocsReadme,
    'make -C core/benchmarks/nextpas.core.atomic/bench_atomic compare',
    'atomic README must list the all-baseline benchmark Makefile entrypoint');
  CheckContains(LAtomicDocsReadme,
    'core/benchmarks/nextpas.core.atomic/bench_atomic/bench_atomic.lpr',
    'atomic README must point to the Pascal benchmark source');
  CheckContains(LAtomicDocsReadme, 'compare_rust/main.rs',
    'atomic README must point to the external Rust comparison source');
  CheckContains(LAtomicDocsReadme, 'compare_go/main.go',
    'atomic README must point to the external Go comparison source');
  CheckContains(LAtomicDocsReadme, 'compare_cpp/main.cpp',
    'atomic README must point to the external C++ comparison source');
  CheckContains(LAtomicDocsReadme,
    '这些 target 最终会在 `core/build/projects/nextpas.core.atomic/bench_atomic/...` 下产出并运行：',
    'atomic README must document the compare target output location');
  CheckContains(LAtomicDocsReadme,
    'Rust：`rustc -C opt-level=3 compare_rust/main.rs -o $(RUST_COMPARE_BIN)`',
    'atomic README must document the Rust compare build command behind the Makefile target');
  CheckContains(LAtomicDocsReadme,
    'Go：`go build -o $(GO_COMPARE_BIN) compare_go/main.go`',
    'atomic README must document the Go compare build command behind the Makefile target');
  CheckContains(LAtomicDocsReadme,
    'C++：`g++ -std=c++17 -O2 compare_cpp/main.cpp -o $(CPP_COMPARE_BIN)`',
    'atomic README must document the C++ compare build command behind the Makefile target');
  CheckContains(LAtomicBenchMakefile,
    '.PHONY: build run build-rust-compare run-rust-compare build-go-compare run-go-compare build-cpp-compare run-cpp-compare compare clean',
    'atomic benchmark Makefile must expose Pascal and external baseline entrypoints');
  CheckContains(LAtomicBenchMakefile, 'RUSTC ?= rustc',
    'atomic benchmark Makefile must expose the Rust compiler override');
  CheckContains(LAtomicBenchMakefile, 'GO ?= go',
    'atomic benchmark Makefile must expose the Go compiler override');
  CheckContains(LAtomicBenchMakefile, 'CXX ?= g++',
    'atomic benchmark Makefile must expose the C++ compiler override');
  CheckContains(LAtomicBenchMakefile, 'run-rust-compare: build-rust-compare',
    'atomic benchmark Makefile must provide a runnable Rust baseline target');
  CheckContains(LAtomicBenchMakefile,
    '$(RUSTC) -C opt-level=3 compare_rust/main.rs -o $(RUST_COMPARE_BIN)',
    'atomic benchmark Makefile must build the Rust baseline with the documented command');
  CheckContains(LAtomicBenchMakefile, 'run-go-compare: build-go-compare',
    'atomic benchmark Makefile must provide a runnable Go baseline target');
  CheckContains(LAtomicBenchMakefile,
    '$(GO) build -o $(GO_COMPARE_BIN) compare_go/main.go',
    'atomic benchmark Makefile must build the Go baseline with the documented command');
  CheckContains(LAtomicBenchMakefile, 'run-cpp-compare: build-cpp-compare',
    'atomic benchmark Makefile must provide a runnable C++ baseline target');
  CheckContains(LAtomicBenchMakefile,
    '$(CXX) -std=c++17 -O2 compare_cpp/main.cpp -o $(CPP_COMPARE_BIN)',
    'atomic benchmark Makefile must build the C++ baseline with the documented command');
  CheckContains(LAtomicBenchMakefile,
    'compare: run run-rust-compare run-go-compare run-cpp-compare',
    'atomic benchmark Makefile must provide a single all-baseline compare target');
  CheckContains(LAtomicDocsReadme, 'platform/compiler flags/input size/baseline',
    'atomic README must name the benchmark evidence envelope');
  CheckContains(LAtomicDocsReadme,
    'plain baseline uses loop-index-dependent local integer work to reduce optimizer folding risk',
    'atomic README must document the plain-baseline anti-folding contract');
  CheckContains(LAtomicDocsReadme,
    'The Pascal benchmark keeps only the final per-scenario result in the printed sink; hot loops should use local temporaries instead of per-iteration global sink writes so Rust/Go/C++ comparison sources can mirror the same logical workload.',
    'atomic README must document the final-sink-only benchmark contract');
  CheckContains(LAtomicBenchMakefile,
    'BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.atomic/bench_atomic',
    'atomic benchmark Makefile must isolate build artifacts under core/build');
  CheckContains(LAtomicBenchMakefile, 'FPC_FLAGS ?= -MObjFPC -Sh -O2',
    'atomic benchmark Makefile must default to optimized benchmark flags');
  CheckContains(LAtomicBenchSource, 'WriteLn(''Platform: '', BenchmarkPlatformName)',
    'atomic benchmark must print the platform evidence field');
  CheckContains(LAtomicBenchSource, 'WriteLn(''Compiler flags: -MObjFPC -Sh -O2'')',
    'atomic benchmark must print the compiler flags evidence field');
  CheckContains(LAtomicBenchSource,
    'WriteLn(''Input size: ITERS=1000000; scenarios=plain baseline, AtomicLoad/Store32, AtomicFetchAdd32, AtomicCompareExchange32, TAtomicUInt32'')',
    'atomic benchmark must print the input-size evidence field');
  CheckContains(LAtomicBenchSource,
    'WriteLn(''Baselines: plain local variable operations for single-thread overhead context; compare_rust/main.rs, compare_go/main.go, and compare_cpp/main.cpp external sources (not auto-run)'')',
    'atomic benchmark must print the baseline evidence field');
  CheckContains(LAtomicBenchSource, 'LValue := LValue + Int32((LI and 1) + 1);',
    'atomic benchmark plain baseline must use loop-index-dependent local work');
  CheckContains(LAtomicBenchSource, 'LSink := AtomicLoad32(LValue, moRelaxed);',
    'atomic benchmark load/store hot loop must keep the loaded value in a local sink');
  CheckNotContains(LAtomicBenchSource, 'GSink32 := AtomicLoad32(LValue, moRelaxed);',
    'atomic benchmark load/store hot loop must not pay per-iteration global sink writes');
  CheckNotContains(LAtomicBenchSource, 'GSink32 := AtomicCompareExchange32(LValue, LExpected, LI, moSeqCst);',
    'atomic benchmark compare-exchange hot loop must not pay per-iteration global sink writes');
  CheckContains(LAtomicBenchSource, 'GSink32 := LValue;',
    'atomic benchmark Pascal source must keep the last Int32 scenario result as sink evidence');
  CheckNotContains(LAtomicBenchSource, 'GSink32 := GSink32 xor',
    'atomic benchmark Pascal source must not XOR-aggregate Int32 sink results');
  CheckContains(LAtomicBenchRustCompareSource, 'use std::sync::atomic',
    'atomic Rust comparison source must use Rust std atomic APIs');
  CheckContains(LAtomicBenchRustCompareSource, 'const ITERS: usize = 1_000_000;',
    'atomic Rust comparison source must use the same nominal iteration count');
  CheckContains(LAtomicBenchRustCompareSource,
    'value = black_box(value.wrapping_add(((i & 1) + 1) as i32));',
    'atomic Rust comparison source must mirror the alternating plain baseline work');
  CheckContains(LAtomicBenchRustCompareSource, 'let mut sink32 = bench_plain_baseline();',
    'atomic Rust comparison source must keep the plain baseline sink initialization explicit');
  CheckContains(LAtomicBenchRustCompareSource, 'sink32 = bench_atomic_load_store32();',
    'atomic Rust comparison source must keep the load/store result as sink evidence');
  CheckContains(LAtomicBenchRustCompareSource, 'sink32 = bench_atomic_fetch_add32();',
    'atomic Rust comparison source must keep the fetch-add result as sink evidence');
  CheckContains(LAtomicBenchRustCompareSource, 'sink32 = bench_atomic_compare_exchange32();',
    'atomic Rust comparison source must keep the compare-exchange result as final Int32 sink evidence');
  CheckEqual(Int64(3), Int64(CountOccurrences(LAtomicBenchRustCompareSource, 'black_box(sink32);')),
    'atomic Rust comparison source must keep intermediate Int32 sink results alive before overwrite');
  CheckNotContains(LAtomicBenchRustCompareSource, ' ^ bench_atomic_load_store32()',
    'atomic Rust comparison source must not XOR-aggregate Int32 sink results');
  CheckContains(LAtomicBenchRustCompareSource, 'AtomicLoad/Store32 2M',
    'atomic Rust comparison source must mirror the load/store scenario name');
  CheckContains(LAtomicBenchRustCompareSource, 'AtomicCompareExchange32 1M',
    'atomic Rust comparison source must mirror the compare-exchange scenario name');
  CheckContains(LAtomicBenchGoCompareSource, 'sync/atomic',
    'atomic Go comparison source must use Go sync/atomic APIs');
  CheckContains(LAtomicBenchGoCompareSource, 'const Iters = 1000000',
    'atomic Go comparison source must use the same nominal iteration count');
  CheckContains(LAtomicBenchGoCompareSource, 'sink32 = benchPlainBaseline()',
    'atomic Go comparison source must keep the plain baseline sink initialization explicit');
  CheckContains(LAtomicBenchGoCompareSource, 'sink32 = benchAtomicLoadStore32()',
    'atomic Go comparison source must keep the load/store result as sink evidence');
  CheckContains(LAtomicBenchGoCompareSource, 'sink32 = benchAtomicFetchAdd32()',
    'atomic Go comparison source must keep the fetch-add result as sink evidence');
  CheckContains(LAtomicBenchGoCompareSource, 'sink32 = benchAtomicCompareExchange32()',
    'atomic Go comparison source must keep the compare-exchange result as final Int32 sink evidence');
  CheckNotContains(LAtomicBenchGoCompareSource, ' ^\n\t\tbenchAtomicLoadStore32()',
    'atomic Go comparison source must not XOR-aggregate Int32 sink results');
  CheckContains(LAtomicBenchGoCompareSource, 'fmt.Println("Compiler flags: go build (default optimized gc toolchain; recommended manual command)")',
    'atomic Go comparison source must print the compiler-flags evidence field');
  CheckContains(LAtomicBenchGoCompareSource, 'AtomicLoad/Store32 2M',
    'atomic Go comparison source must mirror the load/store scenario name');
  CheckContains(LAtomicBenchGoCompareSource, 'AtomicCompareExchange32 1M',
    'atomic Go comparison source must mirror the compare-exchange scenario name');
  CheckContains(LAtomicBenchCppCompareSource, '#include <atomic>',
    'atomic C++ comparison source must use C++ std::atomic APIs');
  CheckContains(LAtomicBenchCppCompareSource, 'constexpr int kIters = 1000000;',
    'atomic C++ comparison source must use the same nominal iteration count');
  CheckContains(LAtomicBenchCppCompareSource, 'gSink32 = bench_plain_baseline();',
    'atomic C++ comparison source must keep the plain baseline sink initialization explicit');
  CheckContains(LAtomicBenchCppCompareSource, 'gSink32 = bench_atomic_load_store32();',
    'atomic C++ comparison source must keep the load/store result as sink evidence');
  CheckContains(LAtomicBenchCppCompareSource, 'gSink32 = bench_atomic_fetch_add32();',
    'atomic C++ comparison source must keep the fetch-add result as sink evidence');
  CheckContains(LAtomicBenchCppCompareSource, 'gSink32 = bench_atomic_compare_exchange32();',
    'atomic C++ comparison source must keep the compare-exchange result as final Int32 sink evidence');
  CheckNotContains(LAtomicBenchCppCompareSource, 'gSink32 = bench_plain_baseline() ^',
    'atomic C++ comparison source must not XOR-aggregate Int32 sink results');
  CheckContains(LAtomicBenchCppCompareSource, 'std::cout << "Compiler flags: g++ -std=c++17 -O2 (recommended manual command)"',
    'atomic C++ comparison source must print the compiler-flags evidence field');
  CheckContains(LAtomicBenchCppCompareSource, 'AtomicLoad/Store32 2M',
    'atomic C++ comparison source must mirror the load/store scenario name');
  CheckContains(LAtomicBenchCppCompareSource, 'AtomicCompareExchange32 1M',
    'atomic C++ comparison source must mirror the compare-exchange scenario name');
  CheckContains(LAtomicSource,
    'generic TAtomicPtr<T> = record',
    'atomic facade must expose the generic typed pointer record');
  CheckContains(LSingleStrongCasSection, 'AtomicCompatFailureOrder(aOrder)',
    'single-order strong CAS must derive failure order');
  CheckContains(LSingleWeakCasSection, 'AtomicCompatFailureOrder(aOrder)',
    'single-order weak CAS must derive failure order');
  CheckContains(LPascalCaseCas32Section, '_cas_success_order(AOrder)',
    'PascalCase Int32 CAS must normalize consume to acquire on success path');
  CheckContains(LPascalCaseCas64Section, '_cas_success_order(AOrder)',
    'PascalCase Int64 CAS must normalize consume to acquire on success path');
  CheckContains(LPascalCaseCasPtrSection, '_cas_success_order(AOrder)',
    'PascalCase pointer CAS must normalize consume to acquire on success path');
  CheckContains(LFacadePtrStrongCasSection,
    'if AOrder = mo_consume then' + LineEnding +
    '    LSuccessOrder := mo_acquire',
    'facade TAtomicPtr strong CAS must normalize consume to acquire on success path');
  CheckContains(LFacadePtrWeakCasSection,
    'if AOrder = mo_consume then' + LineEnding +
    '    LSuccessOrder := mo_acquire',
    'facade TAtomicPtr weak CAS must normalize consume to acquire on success path');
  CheckContains(LFacadePtrStrongCasSection, 'mo_release: LFailureOrder := mo_relaxed;',
    'facade TAtomicPtr strong CAS failure order must not include release');
  CheckContains(LFacadePtrWeakCasSection, 'mo_release: LFailureOrder := mo_relaxed;',
    'facade TAtomicPtr weak CAS failure order must not include release');
  CheckContains(LFacadePtrStrongCasSection, 'mo_acq_rel: LFailureOrder := mo_acquire;',
    'facade TAtomicPtr strong CAS failure order must not include acq_rel');
  CheckContains(LFacadePtrWeakCasSection, 'mo_acq_rel: LFailureOrder := mo_acquire;',
    'facade TAtomicPtr weak CAS failure order must not include acq_rel');
  CheckContains(LCompatFailureSection, 'mo_consume',
    'AtomicCompatFailureOrder must treat consume explicitly');
  CheckContains(LTypesFailureSection, 'mo_consume',
    'typed CAS failure-order helper must treat consume explicitly');
  CheckContains(LTypesInt32LockFreeSection, 'atomic_is_lock_free_32',
    'typed Int32 lock-free query must delegate to Int32 runtime truth');
  CheckNotContains(LTypesInt32LockFreeSection, 'Result := True',
    'typed Int32 lock-free query must not hardcode a guaranteed-true result');
  CheckContains(LTypesUInt32LockFreeSection, 'atomic_is_lock_free_32',
    'typed UInt32 lock-free query must delegate to Int32 runtime truth');
  CheckNotContains(LTypesUInt32LockFreeSection, 'Result := True',
    'typed UInt32 lock-free query must not hardcode a guaranteed-true result');
  CheckContains(LTypesInt32FetchSection, 'atomic_fetch_add(FValue, ADelta, AOrder);',
    'typed Int32 FetchAdd must delegate to the Int32 atomic root');
  CheckContains(LTypesInt32FetchSection, 'atomic_fetch_sub(FValue, ADelta, AOrder);',
    'typed Int32 FetchSub must delegate to the Int32 atomic root');
  CheckContains(LTypesInt32FetchSection, 'atomic_fetch_and(FValue, AMask, AOrder);',
    'typed Int32 FetchAnd must delegate to the Int32 atomic root');
  CheckContains(LTypesInt32FetchSection, 'atomic_fetch_or(FValue, AMask, AOrder);',
    'typed Int32 FetchOr must delegate to the Int32 atomic root');
  CheckContains(LTypesInt32FetchSection, 'atomic_fetch_xor(FValue, AMask, AOrder);',
    'typed Int32 FetchXor must delegate to the Int32 atomic root');
  CheckContains(LTypesUInt32FetchSection, 'atomic_fetch_add(FValue, ADelta, AOrder);',
    'typed UInt32 FetchAdd must delegate to the UInt32 atomic root');
  CheckContains(LTypesUInt32FetchSection, 'atomic_fetch_sub(FValue, ADelta, AOrder);',
    'typed UInt32 FetchSub must delegate to the UInt32 atomic root');
  CheckContains(LTypesUInt32FetchSection, 'atomic_fetch_and(FValue, AMask, AOrder);',
    'typed UInt32 FetchAnd must delegate to the UInt32 atomic root');
  CheckContains(LTypesUInt32FetchSection, 'atomic_fetch_or(FValue, AMask, AOrder);',
    'typed UInt32 FetchOr must delegate to the UInt32 atomic root');
  CheckContains(LTypesUInt32FetchSection, 'atomic_fetch_xor(FValue, AMask, AOrder);',
    'typed UInt32 FetchXor must delegate to the UInt32 atomic root');
  CheckContains(LTypesInt64LockFreeSection, 'atomic_is_lock_free_64',
    'typed Int64 lock-free query must delegate to runtime truth');
  CheckNotContains(LTypesInt64LockFreeSection, 'Result := True',
    'typed Int64 lock-free query must not hardcode a guaranteed-true result');
  CheckContains(LTypesUInt64LockFreeSection, 'atomic_is_lock_free_64',
    'typed UInt64 lock-free query must delegate to runtime truth');
  CheckNotContains(LTypesUInt64LockFreeSection, 'Result := True',
    'typed UInt64 lock-free query must not hardcode a guaranteed-true result');
  CheckContains(LTypesInt64FetchSection, 'atomic_fetch_add_64(FValue, ADelta, AOrder);',
    'typed Int64 FetchAdd must delegate to the Int64 atomic root');
  CheckContains(LTypesInt64FetchSection, 'atomic_fetch_sub_64(FValue, ADelta, AOrder);',
    'typed Int64 FetchSub must delegate to the Int64 atomic root');
  CheckContains(LTypesInt64FetchSection, 'atomic_fetch_and_64(FValue, AMask, AOrder);',
    'typed Int64 FetchAnd must delegate to the Int64 atomic root');
  CheckContains(LTypesInt64FetchSection, 'atomic_fetch_or_64(FValue, AMask, AOrder);',
    'typed Int64 FetchOr must delegate to the Int64 atomic root');
  CheckContains(LTypesInt64FetchSection, 'atomic_fetch_xor_64(FValue, AMask, AOrder);',
    'typed Int64 FetchXor must delegate to the Int64 atomic root');
  CheckContains(LTypesUInt64FetchSection, 'atomic_fetch_add_64(FValue, ADelta, AOrder);',
    'typed UInt64 FetchAdd must delegate to the UInt64 atomic root');
  CheckContains(LTypesUInt64FetchSection, 'atomic_fetch_sub_64(FValue, ADelta, AOrder);',
    'typed UInt64 FetchSub must delegate to the UInt64 atomic root');
  CheckContains(LTypesUInt64FetchSection, 'atomic_fetch_and_64(FValue, AMask, AOrder);',
    'typed UInt64 FetchAnd must delegate to the UInt64 atomic root');
  CheckContains(LTypesUInt64FetchSection, 'atomic_fetch_or_64(FValue, AMask, AOrder);',
    'typed UInt64 FetchOr must delegate to the UInt64 atomic root');
  CheckContains(LTypesUInt64FetchSection, 'atomic_fetch_xor_64(FValue, AMask, AOrder);',
    'typed UInt64 FetchXor must delegate to the UInt64 atomic root');
  CheckContains(LTypedInt64ContractSection, '{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}',
    'typed Int64/UInt64 runtime contract section must start with the production 64-bit API gate');
  CheckContains(LTypedInt64ContractSection, 'TAtomicInt64.is_lock_free',
    'typed Int64/UInt64 runtime contract must remain inside the production 64-bit API gate');
  CheckContains(LTypedInt64FetchContractSection, '{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}',
    'typed Int64/UInt64 fetch runtime contract section must start with the production 64-bit API gate');
  CheckContains(LTypedInt64FetchContractSection, 'TAtomicUInt64.FetchAdd',
    'typed Int64/UInt64 fetch runtime contract must remain inside the production 64-bit API gate');
  CheckContains(LRunnerSection,
    '{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}' + LineEnding +
    '  T.Run(''typed atomic int64/uint64 contract'', @TestAtomicInt64UInt64Contract);' + LineEnding +
    '  T.Run(''typed atomic int64/uint64 fetch contract'', @TestAtomicInt64UInt64FetchContract);' + LineEnding +
    '  {$ENDIF}',
    'typed Int64/UInt64 runner registration must match the production 64-bit API gate');
  CheckContains(LTypesISizeLockFreeSection, 'atomic_is_lock_free_ptr',
    'typed ISize lock-free query must delegate to pointer-sized runtime truth');
  CheckNotContains(LTypesISizeLockFreeSection, 'Result := True',
    'typed ISize lock-free query must not hardcode a guaranteed-true result');
  CheckContains(LTypesUSizeLockFreeSection, 'atomic_is_lock_free_ptr',
    'typed USize lock-free query must delegate to pointer-sized runtime truth');
  CheckNotContains(LTypesUSizeLockFreeSection, 'Result := True',
    'typed USize lock-free query must not hardcode a guaranteed-true result');
  CheckContains(LTypesISizeFetchSection, 'atomic_fetch_add(PInt32(@FValue)^, Int32(ADelta), AOrder));',
    'typed ISize FetchAdd must keep the 32-bit pointer-width delegation path');
  CheckContains(LTypesISizeFetchSection, 'atomic_fetch_add_64(PInt64(@FValue)^, Int64(ADelta), AOrder));',
    'typed ISize FetchAdd must keep the 64-bit pointer-width delegation path');
  CheckContains(LTypesISizeFetchSection, 'atomic_fetch_sub(PInt32(@FValue)^, Int32(ADelta), AOrder));',
    'typed ISize FetchSub must keep the 32-bit pointer-width delegation path');
  CheckContains(LTypesISizeFetchSection, 'atomic_fetch_sub_64(PInt64(@FValue)^, Int64(ADelta), AOrder));',
    'typed ISize FetchSub must keep the 64-bit pointer-width delegation path');
  CheckContains(LTypesISizeFetchSection, 'atomic_fetch_and(PInt32(@FValue)^, Int32(AMask), AOrder));',
    'typed ISize FetchAnd must keep the 32-bit pointer-width delegation path');
  CheckContains(LTypesISizeFetchSection, 'atomic_fetch_and_64(PInt64(@FValue)^, Int64(AMask), AOrder));',
    'typed ISize FetchAnd must keep the 64-bit pointer-width delegation path');
  CheckContains(LTypesISizeFetchSection, 'atomic_fetch_or(PInt32(@FValue)^, Int32(AMask), AOrder));',
    'typed ISize FetchOr must keep the 32-bit pointer-width delegation path');
  CheckContains(LTypesISizeFetchSection, 'atomic_fetch_or_64(PInt64(@FValue)^, Int64(AMask), AOrder));',
    'typed ISize FetchOr must keep the 64-bit pointer-width delegation path');
  CheckContains(LTypesISizeFetchSection, 'atomic_fetch_xor(PInt32(@FValue)^, Int32(AMask), AOrder));',
    'typed ISize FetchXor must keep the 32-bit pointer-width delegation path');
  CheckContains(LTypesISizeFetchSection, 'atomic_fetch_xor_64(PInt64(@FValue)^, Int64(AMask), AOrder));',
    'typed ISize FetchXor must keep the 64-bit pointer-width delegation path');
  CheckContains(LTypesUSizeFetchSection, 'atomic_fetch_add(PUInt32(@FValue)^, UInt32(ADelta), AOrder));',
    'typed USize FetchAdd must keep the 32-bit pointer-width delegation path');
  CheckContains(LTypesUSizeFetchSection, 'atomic_fetch_add_64(PUInt64(@FValue)^, UInt64(ADelta), AOrder));',
    'typed USize FetchAdd must keep the 64-bit pointer-width delegation path');
  CheckContains(LTypesUSizeFetchSection, 'atomic_fetch_sub(PUInt32(@FValue)^, UInt32(ADelta), AOrder));',
    'typed USize FetchSub must keep the 32-bit pointer-width delegation path');
  CheckContains(LTypesUSizeFetchSection, 'atomic_fetch_sub_64(PUInt64(@FValue)^, UInt64(ADelta), AOrder));',
    'typed USize FetchSub must keep the 64-bit pointer-width delegation path');
  CheckContains(LTypesUSizeFetchSection, 'atomic_fetch_and(PUInt32(@FValue)^, UInt32(AMask), AOrder));',
    'typed USize FetchAnd must keep the 32-bit pointer-width delegation path');
  CheckContains(LTypesUSizeFetchSection, 'atomic_fetch_and_64(PUInt64(@FValue)^, UInt64(AMask), AOrder));',
    'typed USize FetchAnd must keep the 64-bit pointer-width delegation path');
  CheckContains(LTypesUSizeFetchSection, 'atomic_fetch_or(PUInt32(@FValue)^, UInt32(AMask), AOrder));',
    'typed USize FetchOr must keep the 32-bit pointer-width delegation path');
  CheckContains(LTypesUSizeFetchSection, 'atomic_fetch_or_64(PUInt64(@FValue)^, UInt64(AMask), AOrder));',
    'typed USize FetchOr must keep the 64-bit pointer-width delegation path');
  CheckContains(LTypesUSizeFetchSection, 'atomic_fetch_xor(PUInt32(@FValue)^, UInt32(AMask), AOrder));',
    'typed USize FetchXor must keep the 32-bit pointer-width delegation path');
  CheckContains(LTypesUSizeFetchSection, 'atomic_fetch_xor_64(PUInt64(@FValue)^, UInt64(AMask), AOrder));',
    'typed USize FetchXor must keep the 64-bit pointer-width delegation path');
  CheckContains(LTypesRefCountLockFreeSection, 'atomic_is_lock_free_ptr',
    'typed refcount lock-free query must delegate to pointer-sized runtime truth');
  CheckNotContains(LTypesRefCountLockFreeSection, 'Result := True',
    'typed refcount lock-free query must not hardcode a guaranteed-true result');
  CheckContains(LTypesBoolLockFreeSection, 'atomic_is_lock_free_32',
    'typed bool lock-free query must delegate to Int32 runtime truth');
  CheckNotContains(LTypesBoolLockFreeSection, 'Result := True',
    'typed bool lock-free query must not hardcode a guaranteed-true result');
  CheckContains(LTypesBoolFetchNandSection, 'and 1',
    'typed bool FetchNand must clamp the stored domain back to 0/1');
  CheckContains(LTypesPtrLockFreeSection, 'atomic_is_lock_free_ptr',
    'typed pointer lock-free query must delegate to pointer-sized runtime truth');
  CheckNotContains(LTypesPtrLockFreeSection, 'Result := True',
    'typed pointer lock-free query must not hardcode a guaranteed-true result');
  CheckContains(LFetchAddFallbackSection, 'try',
    'i386 64-bit fallback add must guard lock release with try/finally');
  CheckContains(LFetchAddFallbackSection, 'finally',
    'i386 64-bit fallback add must guard lock release with try/finally');
  CheckContains(LDefaultLoad32Section, 'mo_seq_cst',
    'default Int32 atomic_load must use seq_cst');
  CheckNotContains(LDefaultLoad32Section, 'mo_relaxed',
    'default Int32 atomic_load must not use relaxed');
  CheckContains(LDefaultLoad64Section, 'mo_seq_cst',
    'default Int64 atomic_load must use seq_cst');
  CheckNotContains(LDefaultLoad64Section, 'mo_relaxed',
    'default Int64 atomic_load must not use relaxed');
  CheckContains(LDefaultLoadPtrSection, 'mo_seq_cst',
    'default Pointer atomic_load must use seq_cst');
  CheckNotContains(LDefaultLoadPtrSection, 'mo_relaxed',
    'default Pointer atomic_load must not use relaxed');
  CheckContains(LDefaultLoadPtrIntSection, 'mo_seq_cst',
    'default PtrInt atomic_load must use seq_cst');
  CheckNotContains(LDefaultLoadPtrIntSection, 'mo_relaxed',
    'default PtrInt atomic_load must not use relaxed');
  CheckContains(LDefaultTaggedPtrLoadSection, 'mo_seq_cst',
    'default tagged pointer load must use seq_cst');
  CheckNotContains(LDefaultTaggedPtrLoadSection, 'mo_relaxed',
    'default tagged pointer load must not use relaxed');
  CheckContains(LDefaultTaggedPtrStoreSection, 'atomic_tagged_ptr_store(aObj, aDesired, mo_seq_cst);',
    'default tagged pointer store must use seq_cst');
  CheckNotContains(LDefaultTaggedPtrStoreSection, 'mo_relaxed',
    'default tagged pointer store must not use relaxed');
  CheckNotContains(LDefaultTaggedPtrStoreSection, 'mo_release',
    'default tagged pointer store must not use release');
  CheckContains(LAtomicDocsReadme,
    '`atomic_tagged_ptr_load/store/exchange` and single-order tagged pointer CAS defaults use `mo_seq_cst` unless the caller passes an explicit memory order.',
    'atomic README must document tagged pointer default-order truth');
  CheckContains(LTaggedPtrUpdateSection,
    'LNewV := atomic_tagged_ptr(aPtr, atomic_tagged_ptr_next(LOld));',
    'tagged pointer update must replace the pointer and advance the tag');
  CheckContains(LTaggedPtrUpdateSection, 'atomic_tagged_ptr_compare_exchange_weak',
    'tagged pointer update must retry with weak CAS');
  CheckContains(LTaggedPtrUpdateTagSection,
    'LOldPtr    := atomic_tagged_ptr_get_ptr(LOldTagged);',
    'tagged pointer update_tag must preserve the current pointer');
  CheckContains(LTaggedPtrUpdateTagSection,
    'LNewTagged := atomic_tagged_ptr(LOldPtr, aTag);',
    'tagged pointer update_tag must only replace the tag');
  CheckContains(LTaggedPtrUpdateTagSection, 'atomic_tagged_ptr_compare_exchange_strong',
    'tagged pointer update_tag must retry with strong CAS');
  CheckContains(LAtomicDocsReadme,
    '`atomic_tagged_ptr_next` wraps to `0` after the maximum representable tag, and `atomic_tagged_ptr_update` uses that modulo increment when it swaps in a new pointer.',
    'atomic README must document tagged pointer modulo increment truth');
  CheckContains(LAtomicDocsReadme,
    '`atomic_tagged_ptr_update_tag` preserves the current pointer and only replaces the tag.',
    'atomic README must document tagged pointer update_tag truth');
  CheckContains(LDefaultStore32Section, 'atomic_store(aObj, aDesired, mo_seq_cst);',
    'default Int32 atomic_store must use seq_cst');
  CheckNotContains(LDefaultStore32Section, 'mo_relaxed',
    'default Int32 atomic_store must not use relaxed');
  CheckNotContains(LDefaultStore32Section, 'mo_release',
    'default Int32 atomic_store must not use release');
  CheckContains(LDefaultStoreUInt32Section, 'atomic_store(PInt32(@aObj)^, PInt32(@aDesired)^);',
    'default UInt32 atomic_store must delegate to the Int32 default store');
  CheckNotContains(LDefaultStoreUInt32Section, 'mo_relaxed',
    'default UInt32 atomic_store must not use relaxed directly');
  CheckNotContains(LDefaultStoreUInt32Section, 'mo_release',
    'default UInt32 atomic_store must not use release directly');
  CheckContains(LDefaultStore64Section, 'atomic_store_64(aObj, aDesired, mo_seq_cst);',
    'default Int64 atomic_store must use seq_cst');
  CheckNotContains(LDefaultStore64Section, 'mo_relaxed',
    'default Int64 atomic_store must not use relaxed');
  CheckNotContains(LDefaultStore64Section, 'mo_release',
    'default Int64 atomic_store must not use release');
  CheckContains(LDefaultStoreUInt64Section, 'atomic_store_64(PInt64(@aObj)^, PInt64(@aDesired)^);',
    'default UInt64 atomic_store must delegate to the Int64 default store');
  CheckNotContains(LDefaultStoreUInt64Section, 'mo_relaxed',
    'default UInt64 atomic_store must not use relaxed directly');
  CheckNotContains(LDefaultStoreUInt64Section, 'mo_release',
    'default UInt64 atomic_store must not use release directly');
  CheckContains(LDefaultStorePtrSection, 'atomic_store(aObj, aDesired, mo_seq_cst);',
    'default Pointer atomic_store must use seq_cst');
  CheckNotContains(LDefaultStorePtrSection, 'mo_relaxed',
    'default Pointer atomic_store must not use relaxed');
  CheckNotContains(LDefaultStorePtrSection, 'mo_release',
    'default Pointer atomic_store must not use release');
  CheckContains(LDefaultStorePtrIntSection, 'atomic_store(aObj, aDesired, mo_seq_cst);',
    'default PtrInt atomic_store must use seq_cst');
  CheckNotContains(LDefaultStorePtrIntSection, 'mo_relaxed',
    'default PtrInt atomic_store must not use relaxed');
  CheckNotContains(LDefaultStorePtrIntSection, 'mo_release',
    'default PtrInt atomic_store must not use release');
  CheckContains(LDefaultStorePtrUIntSection,
    'atomic_store(PPtrInt(@aObj)^, PPtrInt(@aDesired)^);',
    'default PtrUInt atomic_store must delegate to the pointer-sized default store');
  CheckNotContains(LDefaultStorePtrUIntSection, 'mo_relaxed',
    'default PtrUInt atomic_store must not use relaxed directly');
  CheckNotContains(LDefaultStorePtrUIntSection, 'mo_release',
    'default PtrUInt atomic_store must not use release directly');
  CheckContains(LAtomicSource, 'procedure AtomicValidateLoadOrder(const AOrder: memory_order_t);',
    'atomic unit must define a shared load-order validator');
  CheckContains(LAtomicSource, 'procedure AtomicValidateStoreOrder(const AOrder: memory_order_t);',
    'atomic unit must define a shared store-order validator');
  CheckContains(LAtomicSource,
    'procedure AtomicValidateCompareExchangeOrders(const ASuccessOrder, AFailureOrder: memory_order_t);',
    'atomic unit must define a shared compare-exchange order validator');
  CheckContains(LLoad32Section, 'AtomicValidateLoadOrder(aOrder);',
    '32-bit atomic_load must validate explicit memory orders');
  CheckContains(LLoad64Section, 'AtomicValidateLoadOrder(aOrder);',
    '64-bit atomic_load must validate explicit memory orders');
  CheckContains(LStore32Section, 'AtomicValidateStoreOrder(aOrder);',
    '32-bit atomic_store must validate explicit memory orders');
  CheckContains(LStore64Section, 'AtomicValidateStoreOrder(aOrder);',
    '64-bit atomic_store must validate explicit memory orders');
  CheckContains(LCasStrong32DualSection,
    'AtomicValidateCompareExchangeOrders(aSuccessOrder, aFailureOrder);',
    '32-bit dual-order strong CAS must validate success/failure orders');
  CheckContains(LCasStrongPtrIntDualSection,
    'AtomicValidateCompareExchangeOrders(aSuccessOrder, aFailureOrder);',
    'pointer-sized dual-order strong CAS must validate success/failure orders');
  CheckContains(LCasStrong64DualSection,
    'AtomicValidateCompareExchangeOrders(aSuccessOrder, aFailureOrder);',
    '64-bit dual-order strong CAS must validate success/failure orders');
  CheckContains(LTaggedPtrLoadSection, 'atomic_load(PInt32(@aObj)^, aOrder);',
    'tagged pointer explicit load must delegate through 32-bit atomic_load validation');
  CheckContains(LTaggedPtrLoadSection, 'atomic_load_64(PInt64(@aObj)^, aOrder);',
    'tagged pointer explicit load must delegate through 64-bit atomic_load validation');
  CheckContains(LTaggedPtrStoreSection, 'atomic_store(PInt32(@aObj)^, PInt32(@aDesired)^, aOrder);',
    'tagged pointer explicit store must delegate through 32-bit atomic_store validation');
  CheckContains(LTaggedPtrStoreSection, 'atomic_store_64(PInt64(@aObj)^, PInt64(@aDesired)^, aOrder);',
    'tagged pointer explicit store must delegate through 64-bit atomic_store validation');
  CheckContains(LTaggedPtrStrongCasSection,
    'atomic_compare_exchange_strong(PInt32(@aObj)^, LExpected32, PInt32(@aDesired)^, aSuccessOrder, aFailureOrder);',
    'tagged pointer strong CAS must delegate through 32-bit compare-exchange validation');
  CheckContains(LTaggedPtrStrongCasSection,
    'atomic_compare_exchange_strong_64(PInt64(@aObj)^, LExpected64, PInt64(@aDesired)^, aSuccessOrder, aFailureOrder);',
    'tagged pointer strong CAS must delegate through 64-bit compare-exchange validation');
  CheckContains(LTaggedPtrWeakCasSection,
    'atomic_compare_exchange_weak(PInt32(@aObj)^, LExpected32, PInt32(@aDesired)^, aSuccessOrder, aFailureOrder);',
    'tagged pointer weak CAS must delegate through 32-bit compare-exchange validation');
  CheckContains(LTaggedPtrWeakCasSection,
    'atomic_compare_exchange_weak_64(PInt64(@aObj)^, LExpected64, PInt64(@aDesired)^, aSuccessOrder, aFailureOrder);',
    'tagged pointer weak CAS must delegate through 64-bit compare-exchange validation');
  CheckContains(LAtomicWaitSection, 'platform_wait_address32',
    'atomic_wait must delegate to platform wait-address primitive');
  CheckContains(LAtomicNotifyOneSection, 'platform_wake_address_one',
    'atomic_notify_one must delegate to platform wake-one primitive');
  CheckContains(LAtomicNotifyAllSection, 'platform_wake_address_all',
    'atomic_notify_all must delegate to platform wake-all primitive');
  CheckContains(LAtomicFlagTestAndSetSection, 'atomic_exchange(PInt32(@aFlag)^, 1, mo_seq_cst)',
    'atomic_flag_test_and_set must set and return the previous flag state');
  CheckContains(LAtomicFlagTestSection, 'atomic_load(PInt32(@aFlag)^, mo_seq_cst)',
    'atomic_flag_test must observe the flag without modifying it using seq_cst default semantics');
  CheckNotContains(LAtomicFlagTestSection, 'mo_relaxed',
    'atomic_flag_test must not use relaxed default semantics');
  CheckNotContains(LAtomicFlagTestSection, 'mo_acquire',
    'atomic_flag_test must not use acquire default semantics');
  CheckContains(LAtomicFlagClearSection, 'atomic_store(PInt32(@aFlag)^, 0, mo_seq_cst)',
    'atomic_flag_clear must reset the flag with seq_cst default semantics');
  CheckContains(LAtomicDocsReadme,
    'No-argument scalar/pointer `atomic_store` wrappers and `atomic_flag_test` route through `mo_seq_cst`; callers must pass an explicit weaker order when they want relaxed/acquire/release behavior.',
    'atomic README must document default store and flag-test order truth');
  CheckContains(LRefCountTypeSection, 'function Load(AOrder: memory_order_t = mo_relaxed): PtrUInt;',
    'TAtomicRefCount Load should default to relaxed');
  CheckContains(LRefCountTypeSection, 'function Inc: PtrUInt;',
    'TAtomicRefCount must expose Inc');
  CheckContains(LRefCountTypeSection, 'function TryInc(out ANewValue: PtrUInt): Boolean;',
    'TAtomicRefCount must expose TryInc');
  CheckContains(LRefCountTypeSection, 'function Dec: PtrUInt;',
    'TAtomicRefCount must expose Dec');
  CheckContains(LRefCountTypeSection, 'function IntoInner: PtrUInt;',
    'TAtomicRefCount must expose IntoInner');
  CheckNotContains(LRefCountTypeSection, 'procedure Store(',
    'TAtomicRefCount must not expose Store');
  CheckNotContains(LRefCountTypeSection, 'function Exchange(',
    'TAtomicRefCount must not expose Exchange');
  CheckNotContains(LRefCountTypeSection, 'function FetchAdd(',
    'TAtomicRefCount must not expose FetchAdd');
  CheckNotContains(LRefCountTypeSection, 'function FetchSub(',
    'TAtomicRefCount must not expose FetchSub');
  CheckNotContains(LRefCountTypeSection, 'function GetMut',
    'TAtomicRefCount must not expose GetMut');
  CheckContains(LRefCountIncSection, 'cannot resurrect zero refcount',
    'TAtomicRefCount.Inc must reject zero-state resurrection');
  CheckContains(LRefCountIncSection,
    '_refcount_compare_exchange_strong(FValue, LCurrent, LNew, mo_relaxed, mo_relaxed)',
    'TAtomicRefCount.Inc must keep relaxed success/failure orders');
  CheckContains(LRefCountTryIncSection, 'ANewValue := 0;',
    'TAtomicRefCount.TryInc must clear the out value on zero-state failure');
  CheckContains(LRefCountTryIncSection, 'Exit(False);',
    'TAtomicRefCount.TryInc must return False when the refcount is already zero');
  CheckContains(LRefCountTryIncSection,
    '_refcount_compare_exchange_strong(FValue, LCurrent, LNew, mo_acquire, mo_relaxed)',
    'TAtomicRefCount.TryInc must publish acquire semantics on successful resurrection-free increments');
  CheckContains(LRefCountDecSection,
    '_refcount_compare_exchange_strong(FValue, LCurrent, LNew, mo_release, mo_relaxed)',
    'TAtomicRefCount.Dec must publish release semantics on decrement');
  CheckContains(LRefCountDecSection, 'if LNew = 0 then',
    'TAtomicRefCount.Dec must special-case the final drop');
  CheckContains(LRefCountDecSection, 'atomic_thread_fence(mo_acquire);',
    'TAtomicRefCount.Dec must issue an acquire fence on the final drop');
  CheckContains(LLoad32SeqCstSection, '_atomic_seq_cst_load_32_x86',
    'x86/x86_64 seq_cst 32-bit load must use a dedicated locked/fenced helper');
  CheckContains(LLoad64SeqCstSection, '_atomic_seq_cst_load_64_x86',
    'x86/x86_64 seq_cst 64-bit load must use a dedicated locked/fenced helper');
  CheckNotContains(LLoad32SeqCstSection, '_compiler_barrier',
    'seq_cst 32-bit load must not be compiler-barrier-only');
  CheckNotContains(LLoad64SeqCstSection, '_compiler_barrier',
    'seq_cst 64-bit load must not be compiler-barrier-only');
  CheckNotContains(LLoad64Section, 'Result := aObj;' + LineEnding + '  {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}',
    'i386 64-bit atomic load must not perform a pre-load plain read');
  CheckContains(LLoad32SeqCstSection, 'atomic_seq_cst_fence;',
    'non-x86 seq_cst 32-bit load must use the dedicated seq_cst fence helper');
  CheckContains(LLoad64SeqCstSection, 'atomic_seq_cst_fence;',
    'non-x86 seq_cst 64-bit load must use the dedicated seq_cst fence helper');
  Check(CountOccurrences(LLoad32SeqCstSection, 'atomic_seq_cst_fence;') >= 2,
    'AArch64/non-x86 seq_cst 32-bit load must keep fence-load-fence ordering');
  Check(CountOccurrences(LLoad64SeqCstSection, 'atomic_seq_cst_fence;') >= 2,
    'AArch64/non-x86 seq_cst 64-bit load must keep fence-load-fence ordering');
  CheckContains(LStore32SeqCstSection, 'atomic_seq_cst_fence;',
    'non-x86 seq_cst 32-bit store must use the dedicated seq_cst fence helper');
  CheckContains(LStore64SeqCstSection, 'atomic_seq_cst_fence;',
    'non-x86 seq_cst 64-bit store must use the dedicated seq_cst fence helper');
  CheckContains(LFetchAnd64Section,
    '    mo_release, mo_acq_rel:' + LineEnding +
    '      WriteBarrier;' + LineEnding +
    '  else' + LineEnding +
    '    ;' + LineEnding +
    '  end;',
    'atomic_fetch_and_64 non-x86 write-order case must have explicit else');
  CheckContains(LFetchAnd64Section,
    '    mo_consume, mo_acquire, mo_acq_rel:' + LineEnding +
    '      ReadBarrier;' + LineEnding +
    '  else' + LineEnding +
    '    ;' + LineEnding +
    '  end;',
    'atomic_fetch_and_64 non-x86 read-order case must have explicit else');
  CheckContains(LFetchOr64Section,
    '    mo_release, mo_acq_rel:' + LineEnding +
    '      WriteBarrier;' + LineEnding +
    '  else' + LineEnding +
    '    ;' + LineEnding +
    '  end;',
    'atomic_fetch_or_64 non-x86 write-order case must have explicit else');
  CheckContains(LFetchOr64Section,
    '    mo_consume, mo_acquire, mo_acq_rel:' + LineEnding +
    '      ReadBarrier;' + LineEnding +
    '  else' + LineEnding +
    '    ;' + LineEnding +
    '  end;',
    'atomic_fetch_or_64 non-x86 read-order case must have explicit else');
  CheckContains(LFetchXor64Section,
    '    mo_release, mo_acq_rel:' + LineEnding +
    '      WriteBarrier;' + LineEnding +
    '  else' + LineEnding +
    '    ;' + LineEnding +
    '  end;',
    'atomic_fetch_xor_64 non-x86 write-order case must have explicit else');
  CheckContains(LFetchXor64Section,
    '    mo_consume, mo_acquire, mo_acq_rel:' + LineEnding +
    '      ReadBarrier;' + LineEnding +
    '  else' + LineEnding +
    '    ;' + LineEnding +
    '  end;',
    'atomic_fetch_xor_64 non-x86 read-order case must have explicit else');
  CheckContains(LFetchMax64Section,
    '    mo_release, mo_acq_rel:' + LineEnding +
    '      WriteBarrier;' + LineEnding +
    '  else' + LineEnding +
    '    ;' + LineEnding +
    '  end;',
    'atomic_fetch_max_64 non-x86 write-order case must have explicit else');
  CheckContains(LFetchMax64Section,
    '    mo_consume, mo_acquire, mo_acq_rel:' + LineEnding +
    '      ReadBarrier;' + LineEnding +
    '  else' + LineEnding +
    '    ;' + LineEnding +
    '  end;',
    'atomic_fetch_max_64 non-x86 read-order case must have explicit else');
  CheckContains(LFetchMin64Section,
    '    mo_release, mo_acq_rel:' + LineEnding +
    '      WriteBarrier;' + LineEnding +
    '  else' + LineEnding +
    '    ;' + LineEnding +
    '  end;',
    'atomic_fetch_min_64 non-x86 write-order case must have explicit else');
  CheckContains(LFetchMin64Section,
    '    mo_consume, mo_acquire, mo_acq_rel:' + LineEnding +
    '      ReadBarrier;' + LineEnding +
    '  else' + LineEnding +
    '    ;' + LineEnding +
    '  end;',
    'atomic_fetch_min_64 non-x86 read-order case must have explicit else');
  CheckContains(LFetchNand64Section,
    '    mo_release, mo_acq_rel:' + LineEnding +
    '      WriteBarrier;' + LineEnding +
    '  else' + LineEnding +
    '    ;' + LineEnding +
    '  end;',
    'atomic_fetch_nand_64 non-x86 write-order case must have explicit else');
  CheckContains(LFetchNand64Section,
    '    mo_consume, mo_acquire, mo_acq_rel:' + LineEnding +
    '      ReadBarrier;' + LineEnding +
    '  else' + LineEnding +
    '    ;' + LineEnding +
    '  end;',
    'atomic_fetch_nand_64 non-x86 read-order case must have explicit else');
  CheckContains(LPointerFetchAddSection,
    'Result := Pointer(atomic_fetch_add(PInt32(@aObj)^, PInt32(@aOffset)^));',
    'pointer atomic_fetch_add 32-bit path must delegate through scalar fetch_add');
  CheckContains(LPointerFetchAddSection,
    'Result := Pointer(atomic_fetch_add_64(PInt64(@aObj)^, PInt64(@aOffset)^));',
    'pointer atomic_fetch_add 64-bit path must delegate through scalar fetch_add_64');
  CheckContains(LPointerFetchSubSection,
    'Result := atomic_fetch_add(aObj, -aOffset);',
    'pointer atomic_fetch_sub must reuse pointer atomic_fetch_add with a negative offset');
  CheckContains(LDefaultFetchMax32Section,
    'Result := atomic_fetch_max(aObj, aArg, mo_seq_cst);',
    'default atomic_fetch_max must use seq_cst');
  CheckContains(LDefaultFetchMin32Section,
    'Result := atomic_fetch_min(aObj, aArg, mo_seq_cst);',
    'default atomic_fetch_min must use seq_cst');
  CheckContains(LDefaultFetchNand32Section,
    'Result := atomic_fetch_nand(aObj, aArg, mo_seq_cst);',
    'default atomic_fetch_nand must use seq_cst');
  CheckContains(LDefaultFetchMax64Section,
    'Result := atomic_fetch_max_64(aObj, aArg, mo_seq_cst);',
    'default atomic_fetch_max_64 must use seq_cst');
  CheckContains(LDefaultFetchMin64Section,
    'Result := atomic_fetch_min_64(aObj, aArg, mo_seq_cst);',
    'default atomic_fetch_min_64 must use seq_cst');
  CheckContains(LDefaultFetchNand64Section,
    'Result := atomic_fetch_nand_64(aObj, aArg, mo_seq_cst);',
    'default atomic_fetch_nand_64 must use seq_cst');
end;

procedure TestConcurrentFetchAdd;
var
  LCounter: Int32;
  LI: Integer;
  LThreads: array[0..3] of TThread;
begin
  LCounter := 0;
  for LI := 0 to 3 do
  begin
    LThreads[LI] := TThread.CreateAnonymousThread(procedure
    var
      LJ: Integer;
    begin
      for LJ := 0 to 9999 do
        AtomicFetchAdd32(LCounter, 1);
    end);
    LThreads[LI].FreeOnTerminate := False;
    LThreads[LI].Start;
  end;

  for LI := 0 to 3 do
  begin
    LThreads[LI].WaitFor;
    LThreads[LI].Free;
  end;

  CheckEqual(Int64(40000), Int64(LCounter), '4 threads x 10000 increments');
end;

procedure TestFafafaStyleAtomicApi;
var
  LVal: Int32;
  LExpected: Int32;
  LOld: Int32;
  LVal64: Int64;
begin
  LVal := 0;
  atomic_store(LVal, 11, mo_relaxed);
  CheckEqual(Int64(11), Int64(atomic_load(LVal, mo_acquire)));

  LOld := atomic_fetch_add(LVal, 2, mo_acq_rel);
  CheckEqual(Int64(11), Int64(LOld));
  CheckEqual(Int64(13), Int64(LVal));

  LExpected := 20;
  Check(not atomic_compare_exchange_strong(LVal, LExpected, 30, mo_release, mo_relaxed),
    'CAS failure returns False');
  CheckEqual(Int64(13), Int64(LExpected), 'CAS failure writes observed value');

  LExpected := 13;
  Check(atomic_compare_exchange_weak(LVal, LExpected, 30, mo_seq_cst, mo_seq_cst),
    'weak CAS succeeds when expected matches');
  CheckEqual(Int64(30), Int64(LVal));

  LVal64 := 5;
  CheckEqual(Int64(5), atomic_fetch_add_64(LVal64, 10));
  CheckEqual(Int64(15), LVal64);
end;

procedure TestAtomicRecordTypes;
type
  TIntAtomicPtr = specialize TAtomicPtr<Integer>;
var
  LAtomic: TAtomicUInt32;
  LExpected: UInt32;
  LPtr: TIntAtomicPtr;
  LPtrExpected: PInteger;
  LPtrOld: PInteger;
  LValueA: Integer;
  LValueB: Integer;
begin
  LAtomic := TAtomicUInt32.Create(7);
  CheckEqual(Int64(7), Int64(LAtomic.Load(mo_relaxed)));

  CheckEqual(Int64(7), Int64(LAtomic.FetchAdd(5, mo_acq_rel)));
  CheckEqual(Int64(12), Int64(LAtomic.Load(mo_acquire)));

  LExpected := 12;
  Check(LAtomic.CompareExchangeStrong(LExpected, 18, mo_seq_cst),
    'record strong CAS succeeds');
  CheckEqual(Int64(18), Int64(LAtomic.IntoInner));

  Check(TAtomicISize.is_lock_free = atomic_is_lock_free_ptr,
    'TAtomicISize lock-free surface must match pointer-sized runtime truth');
  Check(TAtomicUSize.is_lock_free = atomic_is_lock_free_ptr,
    'TAtomicUSize lock-free surface must match pointer-sized runtime truth');
  Check(TAtomicRefCount.is_lock_free = atomic_is_lock_free_ptr,
    'TAtomicRefCount lock-free surface must match pointer-sized runtime truth');
  Check(TIntAtomicPtr.is_lock_free = atomic_is_lock_free_ptr,
    'TAtomicPtr lock-free surface must match pointer-sized runtime truth');

  LValueA := 10;
  LValueB := 20;
  LPtr := TIntAtomicPtr.Create(@LValueA);
  Check(LPtr.Load(mo_relaxed) = @LValueA,
    'facade TAtomicPtr Load should return the stored pointer');
  LPtr.Store(@LValueB, mo_release);
  Check(LPtr.Load(mo_acquire) = @LValueB,
    'facade TAtomicPtr Store should publish the new pointer');
  LPtrOld := LPtr.Exchange(@LValueA, mo_acq_rel);
  Check(LPtrOld = @LValueB,
    'facade TAtomicPtr Exchange should return the old pointer');
  Check(LPtr.IntoInner = @LValueA,
    'facade TAtomicPtr IntoInner should return the current pointer');

  LPtrExpected := @LValueB;
  Check(not LPtr.CompareExchangeStrong(LPtrExpected, @LValueB, mo_release),
    'facade TAtomicPtr strong CAS should fail when expected mismatches');
  Check(LPtrExpected = @LValueA,
    'facade TAtomicPtr strong CAS failure should write the observed pointer');
  Check(LPtr.CompareExchangeStrong(LPtrExpected, @LValueB, mo_seq_cst),
    'facade TAtomicPtr strong CAS should update when expected matches');
  Check(LPtr.Load = @LValueB,
    'facade TAtomicPtr default Load should observe the CAS result');
end;

procedure TestAtomicInt32UInt32Contract;
var
  LAtomicInt32: TAtomicInt32;
  LAtomicUInt32: TAtomicUInt32;
  LExpectedInt32: Int32;
  LExpectedUInt32: UInt32;
  LMutInt32: PInt32;
  LMutUInt32: PUInt32;
begin
  Check(TAtomicInt32.is_lock_free = atomic_is_lock_free_32,
    'TAtomicInt32 lock-free surface must match Int32 runtime truth');
  Check(TAtomicUInt32.is_lock_free = atomic_is_lock_free_32,
    'TAtomicUInt32 lock-free surface must match Int32 runtime truth');

  LAtomicInt32 := TAtomicInt32.Create(-2);
  CheckEqual(Int64(-2), Int64(LAtomicInt32.Load(mo_relaxed)),
    'TAtomicInt32.Create should publish the initial value');
  CheckEqual(Int64(-1), Int64(LAtomicInt32.Increment(mo_acq_rel)),
    'TAtomicInt32.Increment should return the new value');
  CheckEqual(Int64(-1), Int64(LAtomicInt32.Load(mo_acquire)),
    'TAtomicInt32.Increment should publish the incremented value');
  CheckEqual(Int64(-2), Int64(LAtomicInt32.Decrement(mo_acq_rel)),
    'TAtomicInt32.Decrement should return the new value');

  LExpectedInt32 := -1;
  Check(not LAtomicInt32.CompareExchangeStrong(LExpectedInt32, 4, mo_release),
    'TAtomicInt32 strong CAS should fail when expected mismatches');
  CheckEqual(Int64(-2), Int64(LExpectedInt32),
    'TAtomicInt32 strong CAS failure should write the observed value');

  LExpectedInt32 := -2;
  Check(LAtomicInt32.CompareExchangeStrong(LExpectedInt32, 4, mo_seq_cst),
    'TAtomicInt32 strong CAS should update when expected matches');
  CheckEqual(Int64(4), Int64(LAtomicInt32.Load),
    'TAtomicInt32 default Load should observe the CAS result');
  LExpectedInt32 := 4;
  Check(LAtomicInt32.CompareExchangeWeak(LExpectedInt32, 6, mo_acq_rel),
    'TAtomicInt32 weak CAS should update when expected matches');
  CheckEqual(Int64(6), Int64(LAtomicInt32.Load(mo_acquire)),
    'TAtomicInt32 weak CAS should publish the replacement value');

  LMutInt32 := LAtomicInt32.GetMut;
  LMutInt32^ := 9;
  CheckEqual(Int64(9), Int64(LAtomicInt32.IntoInner),
    'TAtomicInt32.GetMut/IntoInner should expose the exclusive-access value');

  LAtomicUInt32 := TAtomicUInt32.Create(3);
  CheckEqual(Int64(3), Int64(LAtomicUInt32.IntoInner),
    'TAtomicUInt32.IntoInner should expose the initial value');
  CheckEqual(Int64(4), Int64(LAtomicUInt32.Increment(mo_acq_rel)),
    'TAtomicUInt32.Increment should return the new value');
  CheckEqual(Int64(3), Int64(LAtomicUInt32.Decrement(mo_acq_rel)),
    'TAtomicUInt32.Decrement should return the new value');
  LExpectedUInt32 := 2;
  Check(not LAtomicUInt32.CompareExchangeStrong(LExpectedUInt32, 7, mo_release),
    'TAtomicUInt32 strong CAS should fail when expected mismatches');
  CheckEqual(Int64(3), Int64(LExpectedUInt32),
    'TAtomicUInt32 strong CAS failure should write the observed value');
  Check(LAtomicUInt32.CompareExchangeWeak(LExpectedUInt32, 7, mo_acq_rel),
    'TAtomicUInt32 weak CAS should update when expected matches');
  CheckEqual(Int64(7), Int64(LAtomicUInt32.Load(mo_acquire)),
    'TAtomicUInt32 weak CAS should publish the replacement value');

  LMutUInt32 := LAtomicUInt32.GetMut;
  LMutUInt32^ := 11;
  CheckEqual(Int64(11), Int64(LAtomicUInt32.Load(mo_relaxed)),
    'TAtomicUInt32.GetMut should expose the exclusive-access storage');
end;

procedure TestAtomicInt32UInt32FetchContract;
var
  LAtomicInt32: TAtomicInt32;
  LAtomicUInt32: TAtomicUInt32;
begin
  LAtomicInt32 := TAtomicInt32.Create(10);
  CheckEqual(Int64(10), Int64(LAtomicInt32.FetchAdd(5, mo_acq_rel)),
    'TAtomicInt32.FetchAdd should return the previous value');
  CheckEqual(Int64(15), Int64(LAtomicInt32.Load(mo_acquire)),
    'TAtomicInt32.FetchAdd should publish the incremented value');
  CheckEqual(Int64(15), Int64(LAtomicInt32.FetchSub(3, mo_acq_rel)),
    'TAtomicInt32.FetchSub should return the previous value');
  CheckEqual(Int64(12), Int64(LAtomicInt32.Load(mo_acquire)),
    'TAtomicInt32.FetchSub should publish the decremented value');
  LAtomicInt32.Store($00FF, mo_release);
  CheckEqual(Int64($00FF), Int64(LAtomicInt32.FetchAnd($000F, mo_acq_rel)),
    'TAtomicInt32.FetchAnd should return the previous value');
  CheckEqual(Int64($000F), Int64(LAtomicInt32.Load(mo_acquire)),
    'TAtomicInt32.FetchAnd should publish the AND result');
  CheckEqual(Int64($000F), Int64(LAtomicInt32.FetchOr($00F0, mo_acq_rel)),
    'TAtomicInt32.FetchOr should return the previous value');
  CheckEqual(Int64($00FF), Int64(LAtomicInt32.Load(mo_acquire)),
    'TAtomicInt32.FetchOr should publish the OR result');
  CheckEqual(Int64($00FF), Int64(LAtomicInt32.FetchXor($0F0F, mo_acq_rel)),
    'TAtomicInt32.FetchXor should return the previous value');
  CheckEqual(Int64($0FF0), Int64(LAtomicInt32.Load(mo_acquire)),
    'TAtomicInt32.FetchXor should publish the XOR result');

  LAtomicUInt32 := TAtomicUInt32.Create(20);
  CheckEqual(Int64(20), Int64(LAtomicUInt32.FetchAdd(6, mo_acq_rel)),
    'TAtomicUInt32.FetchAdd should return the previous value');
  CheckEqual(Int64(26), Int64(LAtomicUInt32.Load(mo_acquire)),
    'TAtomicUInt32.FetchAdd should publish the incremented value');
  CheckEqual(Int64(26), Int64(LAtomicUInt32.FetchSub(5, mo_acq_rel)),
    'TAtomicUInt32.FetchSub should return the previous value');
  CheckEqual(Int64(21), Int64(LAtomicUInt32.Load(mo_acquire)),
    'TAtomicUInt32.FetchSub should publish the decremented value');
  LAtomicUInt32.Store($0F0F0F0F, mo_release);
  CheckEqual(Int64($0F0F0F0F), Int64(LAtomicUInt32.FetchAnd($00FF00FF, mo_acq_rel)),
    'TAtomicUInt32.FetchAnd should return the previous value');
  CheckEqual(Int64($000F000F), Int64(LAtomicUInt32.Load(mo_acquire)),
    'TAtomicUInt32.FetchAnd should publish the AND result');
  CheckEqual(Int64($000F000F), Int64(LAtomicUInt32.FetchOr($0F0000F0, mo_acq_rel)),
    'TAtomicUInt32.FetchOr should return the previous value');
  CheckEqual(Int64($0F0F00FF), Int64(LAtomicUInt32.Load(mo_acquire)),
    'TAtomicUInt32.FetchOr should publish the OR result');
  CheckEqual(Int64($0F0F00FF), Int64(LAtomicUInt32.FetchXor($00FF00FF, mo_acq_rel)),
    'TAtomicUInt32.FetchXor should return the previous value');
  CheckEqual(Int64($0FF00000), Int64(LAtomicUInt32.Load(mo_acquire)),
    'TAtomicUInt32.FetchXor should publish the XOR result');
end;

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
procedure TestAtomicInt64UInt64Contract;
var
  LAtomicInt64: TAtomicInt64;
  LAtomicUInt64: TAtomicUInt64;
  LExpectedInt64: Int64;
  LExpectedUInt64: UInt64;
  LMutInt64: PInt64;
  LMutUInt64: PUInt64;
begin
  Check(TAtomicInt64.is_lock_free = atomic_is_lock_free_64,
    'TAtomicInt64 lock-free surface must match Int64 runtime truth');
  Check(TAtomicUInt64.is_lock_free = atomic_is_lock_free_64,
    'TAtomicUInt64 lock-free surface must match Int64 runtime truth');

  LAtomicInt64 := TAtomicInt64.Create(-(Int64(1) shl 40));
  CheckEqual(-(Int64(1) shl 40), LAtomicInt64.Load(mo_relaxed),
    'TAtomicInt64.Create should publish the initial value');
  CheckEqual(-(Int64(1) shl 40) + 1, LAtomicInt64.Increment(mo_acq_rel),
    'TAtomicInt64.Increment should return the new value');
  CheckEqual(-(Int64(1) shl 40) + 1, LAtomicInt64.Load(mo_acquire),
    'TAtomicInt64.Increment should publish the incremented value');
  CheckEqual(-(Int64(1) shl 40), LAtomicInt64.Decrement(mo_acq_rel),
    'TAtomicInt64.Decrement should return the new value');

  LExpectedInt64 := -(Int64(1) shl 40) + 1;
  Check(not LAtomicInt64.CompareExchangeStrong(LExpectedInt64, Int64(1) shl 41, mo_release),
    'TAtomicInt64 strong CAS should fail when expected mismatches');
  CheckEqual(-(Int64(1) shl 40), LExpectedInt64,
    'TAtomicInt64 strong CAS failure should write the observed value');

  LExpectedInt64 := -(Int64(1) shl 40);
  Check(LAtomicInt64.CompareExchangeStrong(LExpectedInt64, Int64(1) shl 41, mo_seq_cst),
    'TAtomicInt64 strong CAS should update when expected matches');
  CheckEqual(Int64(1) shl 41, LAtomicInt64.Load,
    'TAtomicInt64 default Load should observe the CAS result');
  LExpectedInt64 := Int64(1) shl 41;
  Check(LAtomicInt64.CompareExchangeWeak(LExpectedInt64, -(Int64(1) shl 39), mo_acq_rel),
    'TAtomicInt64 weak CAS should update when expected matches');
  CheckEqual(-(Int64(1) shl 39), LAtomicInt64.Load(mo_acquire),
    'TAtomicInt64 weak CAS should publish the replacement value');

  LMutInt64 := LAtomicInt64.GetMut;
  LMutInt64^ := -(Int64(1) shl 39);
  CheckEqual(-(Int64(1) shl 39), LAtomicInt64.IntoInner,
    'TAtomicInt64.GetMut/IntoInner should expose the exclusive-access value');

  LAtomicUInt64 := TAtomicUInt64.Create((UInt64(1) shl 40) + 3);
  CheckEqual(Int64((UInt64(1) shl 40) + 3), Int64(LAtomicUInt64.IntoInner),
    'TAtomicUInt64.IntoInner should expose the initial value');
  CheckEqual(Int64((UInt64(1) shl 40) + 4), Int64(LAtomicUInt64.Increment(mo_acq_rel)),
    'TAtomicUInt64.Increment should return the new value');
  CheckEqual(Int64((UInt64(1) shl 40) + 3), Int64(LAtomicUInt64.Decrement(mo_acq_rel)),
    'TAtomicUInt64.Decrement should return the new value');

  LExpectedUInt64 := (UInt64(1) shl 40) + 4;
  Check(not LAtomicUInt64.CompareExchangeStrong(LExpectedUInt64, (UInt64(1) shl 41) + 7, mo_release),
    'TAtomicUInt64 strong CAS should fail when expected mismatches');
  CheckEqual(Int64((UInt64(1) shl 40) + 3), Int64(LExpectedUInt64),
    'TAtomicUInt64 strong CAS failure should write the observed value');

  LExpectedUInt64 := (UInt64(1) shl 40) + 3;
  Check(LAtomicUInt64.CompareExchangeStrong(LExpectedUInt64, (UInt64(1) shl 41) + 7, mo_seq_cst),
    'TAtomicUInt64 strong CAS should update when expected matches');
  CheckEqual(Int64((UInt64(1) shl 41) + 7), Int64(LAtomicUInt64.Load(mo_acquire)),
    'TAtomicUInt64 strong CAS should publish the replacement value');
  LExpectedUInt64 := (UInt64(1) shl 41) + 7;
  Check(LAtomicUInt64.CompareExchangeWeak(LExpectedUInt64, (UInt64(1) shl 39) + 11, mo_acq_rel),
    'TAtomicUInt64 weak CAS should update when expected matches');
  CheckEqual(Int64((UInt64(1) shl 39) + 11), Int64(LAtomicUInt64.Load(mo_acquire)),
    'TAtomicUInt64 weak CAS should publish the replacement value');

  LMutUInt64 := LAtomicUInt64.GetMut;
  LMutUInt64^ := (UInt64(1) shl 39) + 11;
  CheckEqual(Int64((UInt64(1) shl 39) + 11), Int64(LAtomicUInt64.Load(mo_relaxed)),
    'TAtomicUInt64.GetMut should expose the exclusive-access storage');
end;
{$ENDIF}

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
procedure TestAtomicInt64UInt64FetchContract;
var
  LAtomicInt64: TAtomicInt64;
  LAtomicUInt64: TAtomicUInt64;
begin
  LAtomicInt64 := TAtomicInt64.Create(-(Int64(1) shl 40));
  CheckEqual(-(Int64(1) shl 40), LAtomicInt64.FetchAdd(9, mo_acq_rel),
    'TAtomicInt64.FetchAdd should return the previous value');
  CheckEqual(-(Int64(1) shl 40) + 9, LAtomicInt64.Load(mo_acquire),
    'TAtomicInt64.FetchAdd should publish the incremented value');
  CheckEqual(-(Int64(1) shl 40) + 9, LAtomicInt64.FetchSub(5, mo_acq_rel),
    'TAtomicInt64.FetchSub should return the previous value');
  CheckEqual(-(Int64(1) shl 40) + 4, LAtomicInt64.Load(mo_acquire),
    'TAtomicInt64.FetchSub should publish the decremented value');
  LAtomicInt64.Store(Int64($0F0F0F0F0F0F0F0F), mo_release);
  CheckEqual(Int64($0F0F0F0F0F0F0F0F), LAtomicInt64.FetchAnd(Int64($00FF00FF00FF00FF), mo_acq_rel),
    'TAtomicInt64.FetchAnd should return the previous value');
  CheckEqual(Int64($000F000F000F000F), LAtomicInt64.Load(mo_acquire),
    'TAtomicInt64.FetchAnd should publish the AND result');
  CheckEqual(Int64($000F000F000F000F), LAtomicInt64.FetchOr(Int64($0F0000000F000000), mo_acq_rel),
    'TAtomicInt64.FetchOr should return the previous value');
  CheckEqual(Int64($0F0F000F0F0F000F), LAtomicInt64.Load(mo_acquire),
    'TAtomicInt64.FetchOr should publish the OR result');
  CheckEqual(Int64($0F0F000F0F0F000F), LAtomicInt64.FetchXor(Int64($00FF00FF00FF00FF), mo_acq_rel),
    'TAtomicInt64.FetchXor should return the previous value');
  CheckEqual(Int64($0FF000F00FF000F0), LAtomicInt64.Load(mo_acquire),
    'TAtomicInt64.FetchXor should publish the XOR result');

  LAtomicUInt64 := TAtomicUInt64.Create((UInt64(1) shl 40) + 12);
  CheckEqual(Int64((UInt64(1) shl 40) + 12), Int64(LAtomicUInt64.FetchAdd(8, mo_acq_rel)),
    'TAtomicUInt64.FetchAdd should return the previous value');
  CheckEqual(Int64((UInt64(1) shl 40) + 20), Int64(LAtomicUInt64.Load(mo_acquire)),
    'TAtomicUInt64.FetchAdd should publish the incremented value');
  CheckEqual(Int64((UInt64(1) shl 40) + 20), Int64(LAtomicUInt64.FetchSub(6, mo_acq_rel)),
    'TAtomicUInt64.FetchSub should return the previous value');
  CheckEqual(Int64((UInt64(1) shl 40) + 14), Int64(LAtomicUInt64.Load(mo_acquire)),
    'TAtomicUInt64.FetchSub should publish the decremented value');
  LAtomicUInt64.Store(UInt64($0F0F0F0F0F0F0F0F), mo_release);
  CheckEqual(Int64($0F0F0F0F0F0F0F0F), Int64(LAtomicUInt64.FetchAnd(UInt64($00FF00FF00FF00FF), mo_acq_rel)),
    'TAtomicUInt64.FetchAnd should return the previous value');
  CheckEqual(Int64($000F000F000F000F), Int64(LAtomicUInt64.Load(mo_acquire)),
    'TAtomicUInt64.FetchAnd should publish the AND result');
  CheckEqual(Int64($000F000F000F000F), Int64(LAtomicUInt64.FetchOr(UInt64($0F0000000F000000), mo_acq_rel)),
    'TAtomicUInt64.FetchOr should return the previous value');
  CheckEqual(Int64($0F0F000F0F0F000F), Int64(LAtomicUInt64.Load(mo_acquire)),
    'TAtomicUInt64.FetchOr should publish the OR result');
  CheckEqual(Int64($0F0F000F0F0F000F), Int64(LAtomicUInt64.FetchXor(UInt64($00FF00FF00FF00FF), mo_acq_rel)),
    'TAtomicUInt64.FetchXor should return the previous value');
  CheckEqual(Int64($0FF000F00FF000F0), Int64(LAtomicUInt64.Load(mo_acquire)),
    'TAtomicUInt64.FetchXor should publish the XOR result');
end;
{$ENDIF}

procedure TestAtomicBoolContract;
var
  LBool: TAtomicBool;
  LExpected: Boolean;
begin
  Check(TAtomicBool.is_lock_free = atomic_is_lock_free_32,
    'TAtomicBool lock-free surface must match Int32 runtime truth');

  LBool := TAtomicBool.Create(False);
  Check(not LBool.Load(mo_relaxed),
    'TAtomicBool.Create(False) should publish False');
  Check(not LBool.IntoInner,
    'TAtomicBool.IntoInner should expose the current false state');

  LBool.Store(True, mo_release);
  Check(LBool.Load(mo_acquire),
    'TAtomicBool.Store should publish True');

  Check(LBool.Exchange(False, mo_acq_rel),
    'TAtomicBool.Exchange should return the previous true state');
  Check(not LBool.Load(mo_acquire),
    'TAtomicBool.Exchange should publish the replacement state');

  LExpected := True;
  Check(not LBool.CompareExchangeStrong(LExpected, True, mo_release),
    'TAtomicBool strong CAS should fail when expected mismatches');
  Check(not LExpected,
    'TAtomicBool strong CAS failure should write the observed false state');

  Check(LBool.CompareExchangeStrong(LExpected, True, mo_seq_cst),
    'TAtomicBool strong CAS should succeed when expected matches');
  Check(LBool.Load,
    'TAtomicBool default Load should observe the strong-CAS result');

  LExpected := True;
  Check(LBool.CompareExchangeWeak(LExpected, False, mo_acq_rel),
    'TAtomicBool weak CAS should update when expected matches');
  Check(not LBool.Load(mo_acquire),
    'TAtomicBool weak CAS should publish the replacement state');

  Check(not LBool.FetchOr(True, mo_acq_rel),
    'TAtomicBool.FetchOr should return the previous false state');
  Check(LBool.Load(mo_acquire),
    'TAtomicBool.FetchOr(True) should publish True');

  Check(LBool.FetchAnd(False, mo_acq_rel),
    'TAtomicBool.FetchAnd should return the previous true state');
  Check(not LBool.Load(mo_acquire),
    'TAtomicBool.FetchAnd(False) should publish False');

  Check(not LBool.FetchXor(True, mo_acq_rel),
    'TAtomicBool.FetchXor should return the previous false state');
  Check(LBool.Load(mo_acquire),
    'TAtomicBool.FetchXor(True) should publish the toggled true state');

  Check(LBool.FetchNand(True, mo_acq_rel),
    'TAtomicBool.FetchNand should return the previous true state');
  Check(not LBool.Load(mo_acquire),
    'TAtomicBool.FetchNand(True) should clamp the stored value back to False');

  Check(not LBool.FetchNand(False, mo_acq_rel),
    'TAtomicBool.FetchNand(False) should return the previous false state');
  Check(LBool.Load(mo_acquire),
    'TAtomicBool.FetchNand(False) should clamp the stored value back to True');
end;

procedure TestAtomicISizeUSizeContract;
var
  LAtomicISize: TAtomicISize;
  LAtomicUSize: TAtomicUSize;
  LExpectedISize: PtrInt;
  LExpectedUSize: PtrUInt;
  LMutISize: PPtrInt;
  LMutUSize: PPtrUInt;
begin
  Check(TAtomicISize.is_lock_free = atomic_is_lock_free_ptr,
    'TAtomicISize lock-free surface must match pointer-sized runtime truth');
  Check(TAtomicUSize.is_lock_free = atomic_is_lock_free_ptr,
    'TAtomicUSize lock-free surface must match pointer-sized runtime truth');

  LAtomicISize := TAtomicISize.Create(-2);
  CheckEqual(Int64(-2), Int64(LAtomicISize.Load(mo_relaxed)),
    'TAtomicISize.Create should publish the initial value');
  CheckEqual(Int64(-1), Int64(LAtomicISize.Increment(mo_acq_rel)),
    'TAtomicISize.Increment should return the new value');
  CheckEqual(Int64(-1), Int64(LAtomicISize.Load(mo_acquire)),
    'TAtomicISize.Increment should publish the incremented value');
  CheckEqual(Int64(-2), Int64(LAtomicISize.Decrement(mo_acq_rel)),
    'TAtomicISize.Decrement should return the new value');

  LExpectedISize := -1;
  Check(not LAtomicISize.CompareExchangeStrong(LExpectedISize, 4, mo_release),
    'TAtomicISize strong CAS should fail when expected mismatches');
  CheckEqual(Int64(-2), Int64(LExpectedISize),
    'TAtomicISize strong CAS failure should write the observed value');

  LExpectedISize := -2;
  Check(LAtomicISize.CompareExchangeStrong(LExpectedISize, 4, mo_seq_cst),
    'TAtomicISize strong CAS should update when expected matches');
  CheckEqual(Int64(4), Int64(LAtomicISize.Load),
    'TAtomicISize default Load should observe the CAS result');
  LExpectedISize := 4;
  Check(LAtomicISize.CompareExchangeWeak(LExpectedISize, 6, mo_acq_rel),
    'TAtomicISize weak CAS should update when expected matches');
  CheckEqual(Int64(6), Int64(LAtomicISize.Load(mo_acquire)),
    'TAtomicISize weak CAS should publish the replacement value');

  LMutISize := LAtomicISize.GetMut;
  LMutISize^ := 9;
  CheckEqual(Int64(9), Int64(LAtomicISize.IntoInner),
    'TAtomicISize.GetMut/IntoInner should expose the exclusive-access value');

  LAtomicUSize := TAtomicUSize.Create(3);
  CheckEqual(Int64(3), Int64(LAtomicUSize.IntoInner),
    'TAtomicUSize.IntoInner should expose the initial value');
  CheckEqual(Int64(4), Int64(LAtomicUSize.Increment(mo_acq_rel)),
    'TAtomicUSize.Increment should return the new value');
  CheckEqual(Int64(3), Int64(LAtomicUSize.Decrement(mo_acq_rel)),
    'TAtomicUSize.Decrement should return the new value');

  LExpectedUSize := 2;
  Check(not LAtomicUSize.CompareExchangeStrong(LExpectedUSize, 7, mo_release),
    'TAtomicUSize strong CAS should fail when expected mismatches');
  CheckEqual(Int64(3), Int64(LExpectedUSize),
    'TAtomicUSize strong CAS failure should write the observed value');

  LExpectedUSize := 3;
  Check(LAtomicUSize.CompareExchangeWeak(LExpectedUSize, 7, mo_acq_rel),
    'TAtomicUSize weak CAS should update when expected matches');
  CheckEqual(Int64(7), Int64(LAtomicUSize.Load(mo_acquire)),
    'TAtomicUSize weak CAS should publish the replacement value');

  LMutUSize := LAtomicUSize.GetMut;
  LMutUSize^ := 11;
  CheckEqual(Int64(11), Int64(LAtomicUSize.Load(mo_relaxed)),
    'TAtomicUSize.GetMut should expose the exclusive-access storage');
end;

procedure TestAtomicISizeUSizeFetchContract;
var
  LAtomicISize: TAtomicISize;
  LAtomicUSize: TAtomicUSize;
begin
  LAtomicISize := TAtomicISize.Create(10);
  CheckEqual(Int64(10), Int64(LAtomicISize.FetchAdd(5, mo_acq_rel)),
    'TAtomicISize.FetchAdd should return the previous value');
  CheckEqual(Int64(15), Int64(LAtomicISize.Load(mo_acquire)),
    'TAtomicISize.FetchAdd should publish the incremented value');
  CheckEqual(Int64(15), Int64(LAtomicISize.FetchSub(3, mo_acq_rel)),
    'TAtomicISize.FetchSub should return the previous value');
  CheckEqual(Int64(12), Int64(LAtomicISize.Load(mo_acquire)),
    'TAtomicISize.FetchSub should publish the decremented value');
  LAtomicISize.Store(PtrInt($0F0F0F0F), mo_release);
  CheckEqual(Int64($0F0F0F0F), Int64(LAtomicISize.FetchAnd(PtrInt($00FF00FF), mo_acq_rel)),
    'TAtomicISize.FetchAnd should return the previous value');
  CheckEqual(Int64($000F000F), Int64(LAtomicISize.Load(mo_acquire)),
    'TAtomicISize.FetchAnd should publish the AND result');
  CheckEqual(Int64($000F000F), Int64(LAtomicISize.FetchOr(PtrInt($0F0000F0), mo_acq_rel)),
    'TAtomicISize.FetchOr should return the previous value');
  CheckEqual(Int64($0F0F00FF), Int64(LAtomicISize.Load(mo_acquire)),
    'TAtomicISize.FetchOr should publish the OR result');
  CheckEqual(Int64($0F0F00FF), Int64(LAtomicISize.FetchXor(PtrInt($00FF00FF), mo_acq_rel)),
    'TAtomicISize.FetchXor should return the previous value');
  CheckEqual(Int64($0FF00000), Int64(LAtomicISize.Load(mo_acquire)),
    'TAtomicISize.FetchXor should publish the XOR result');

  LAtomicUSize := TAtomicUSize.Create(20);
  CheckEqual(Int64(20), Int64(LAtomicUSize.FetchAdd(6, mo_acq_rel)),
    'TAtomicUSize.FetchAdd should return the previous value');
  CheckEqual(Int64(26), Int64(LAtomicUSize.Load(mo_acquire)),
    'TAtomicUSize.FetchAdd should publish the incremented value');
  CheckEqual(Int64(26), Int64(LAtomicUSize.FetchSub(5, mo_acq_rel)),
    'TAtomicUSize.FetchSub should return the previous value');
  CheckEqual(Int64(21), Int64(LAtomicUSize.Load(mo_acquire)),
    'TAtomicUSize.FetchSub should publish the decremented value');
  LAtomicUSize.Store(PtrUInt($0F0F0F0F), mo_release);
  CheckEqual(Int64($0F0F0F0F), Int64(LAtomicUSize.FetchAnd(PtrUInt($00FF00FF), mo_acq_rel)),
    'TAtomicUSize.FetchAnd should return the previous value');
  CheckEqual(Int64($000F000F), Int64(LAtomicUSize.Load(mo_acquire)),
    'TAtomicUSize.FetchAnd should publish the AND result');
  CheckEqual(Int64($000F000F), Int64(LAtomicUSize.FetchOr(PtrUInt($0F0000F0), mo_acq_rel)),
    'TAtomicUSize.FetchOr should return the previous value');
  CheckEqual(Int64($0F0F00FF), Int64(LAtomicUSize.Load(mo_acquire)),
    'TAtomicUSize.FetchOr should publish the OR result');
  CheckEqual(Int64($0F0F00FF), Int64(LAtomicUSize.FetchXor(PtrUInt($00FF00FF), mo_acq_rel)),
    'TAtomicUSize.FetchXor should return the previous value');
  CheckEqual(Int64($0FF00000), Int64(LAtomicUSize.Load(mo_acquire)),
    'TAtomicUSize.FetchXor should publish the XOR result');
end;

procedure TestAtomicPtrContract;
type
  TIntAtomicPtr = specialize TAtomicPtr<Integer>;
  PPInteger = ^PInteger;
var
  LAtomicPtr: TIntAtomicPtr;
  LExpected: PInteger;
  LMutPtr: PPInteger;
  LValueA: Integer;
  LValueB: Integer;
  LValueC: Integer;
begin
  Check(TIntAtomicPtr.is_lock_free = atomic_is_lock_free_ptr,
    'TAtomicPtr lock-free surface must match pointer-sized runtime truth');

  LValueA := 10;
  LValueB := 20;
  LValueC := 30;
  LAtomicPtr := TIntAtomicPtr.Create(@LValueA);
  Check(LAtomicPtr.Load(mo_relaxed) = @LValueA,
    'TAtomicPtr.Create should publish the initial pointer');

  LAtomicPtr.Store(@LValueB, mo_release);
  Check(LAtomicPtr.Load(mo_acquire) = @LValueB,
    'TAtomicPtr.Store should publish the replacement pointer');

  Check(LAtomicPtr.Exchange(@LValueC, mo_acq_rel) = @LValueB,
    'TAtomicPtr.Exchange should return the previous pointer');
  Check(LAtomicPtr.Load = @LValueC,
    'TAtomicPtr default Load should observe the exchanged pointer');

  LExpected := @LValueA;
  Check(not LAtomicPtr.CompareExchangeStrong(LExpected, @LValueB, mo_release),
    'TAtomicPtr strong CAS should fail when expected mismatches');
  Check(LExpected = @LValueC,
    'TAtomicPtr strong CAS failure should write the observed pointer');

  Check(LAtomicPtr.CompareExchangeStrong(LExpected, @LValueB, mo_seq_cst),
    'TAtomicPtr strong CAS should update when expected matches');
  Check(LAtomicPtr.Load(mo_acquire) = @LValueB,
    'TAtomicPtr strong CAS should publish the replacement pointer');

  LExpected := @LValueB;
  Check(LAtomicPtr.CompareExchangeWeak(LExpected, @LValueA, mo_acq_rel),
    'TAtomicPtr weak CAS should update when expected matches');
  Check(LAtomicPtr.Load(mo_acquire) = @LValueA,
    'TAtomicPtr weak CAS should publish the replacement pointer');

  LMutPtr := PPInteger(LAtomicPtr.GetMut);
  LMutPtr^ := @LValueC;
  Check(LAtomicPtr.IntoInner = @LValueC,
    'TAtomicPtr.GetMut/IntoInner should expose the exclusive-access pointer');
end;

procedure TestAtomicFlagApi;
var
  LFlag: atomic_flag_t;
  LTypedFlag: TAtomicFlag;
begin
  LFlag := 0;
  Check(not atomic_flag_test(LFlag),
    'atomic_flag_test should observe the initial clear state');
  Check(not atomic_flag_test_and_set(LFlag),
    'atomic_flag_test_and_set should return the previous clear state');
  Check(atomic_flag_test(LFlag),
    'atomic_flag_test should observe the set state after test_and_set');
  Check(atomic_flag_test_and_set(LFlag),
    'atomic_flag_test_and_set should return the previous set state');
  atomic_flag_clear(LFlag);
  Check(not atomic_flag_test(LFlag),
    'atomic_flag_clear should reset the flag');

  LTypedFlag := TAtomicFlag.Create(False);
  Check(TAtomicFlag.is_lock_free,
    'TAtomicFlag must expose the guaranteed lock-free surface');
  Check(not LTypedFlag.test(mo_relaxed),
    'TAtomicFlag.test should observe the initial clear state');
  Check(not LTypedFlag.test_and_set(mo_acq_rel),
    'TAtomicFlag.test_and_set should return the previous clear state');
  Check(LTypedFlag.test(mo_acquire),
    'TAtomicFlag.test should observe the set state after test_and_set');
  LTypedFlag.clear(mo_release);
  Check(not LTypedFlag.test(mo_acquire),
    'TAtomicFlag.clear should reset the typed flag');

  LTypedFlag := TAtomicFlag.Create(True);
  Check(LTypedFlag.test(mo_relaxed),
    'TAtomicFlag.Create(True) should create a set flag');
end;

procedure TestAtomicFetchMaxMinNandContract;
var
  LVal32: Int32;
  LOld32: Int32;
  LVal64: Int64;
  LOld64: Int64;
begin
  LVal32 := 10;
  LOld32 := atomic_fetch_max(LVal32, 7);
  CheckEqual(Int64(10), Int64(LOld32),
    'atomic_fetch_max must return the previous 32-bit value');
  CheckEqual(Int64(10), Int64(LVal32),
    'atomic_fetch_max must keep the larger 32-bit value');
  LOld32 := atomic_fetch_max(LVal32, 12);
  CheckEqual(Int64(10), Int64(LOld32),
    'atomic_fetch_max must still report the previous 32-bit value when it raises the target');
  CheckEqual(Int64(12), Int64(LVal32),
    'atomic_fetch_max must publish max(old, arg) for 32-bit values');

  LOld32 := atomic_fetch_min(LVal32, 15);
  CheckEqual(Int64(12), Int64(LOld32),
    'atomic_fetch_min must return the previous 32-bit value');
  CheckEqual(Int64(12), Int64(LVal32),
    'atomic_fetch_min must keep the smaller 32-bit value');
  LOld32 := atomic_fetch_min(LVal32, 9);
  CheckEqual(Int64(12), Int64(LOld32),
    'atomic_fetch_min must still report the previous 32-bit value when it lowers the target');
  CheckEqual(Int64(9), Int64(LVal32),
    'atomic_fetch_min must publish min(old, arg) for 32-bit values');

  LVal32 := $0F0F;
  LOld32 := atomic_fetch_nand(LVal32, $00FF);
  CheckEqual(Int64($0F0F), Int64(LOld32),
    'atomic_fetch_nand must return the previous 32-bit value');
  CheckEqual(Int64(not ($0F0F and $00FF)), Int64(LVal32),
    'atomic_fetch_nand must publish not(old and arg) for 32-bit values');

  LVal64 := Int64(High(Int32)) + 10;
  LOld64 := atomic_fetch_max_64(LVal64, Int64(High(Int32)) + 5);
  CheckEqual(Int64(High(Int32)) + 10, LOld64,
    'atomic_fetch_max_64 must return the previous 64-bit value');
  CheckEqual(Int64(High(Int32)) + 10, LVal64,
    'atomic_fetch_max_64 must keep the larger 64-bit value');
  LOld64 := atomic_fetch_max_64(LVal64, Int64(High(Int32)) + 20);
  CheckEqual(Int64(High(Int32)) + 10, LOld64,
    'atomic_fetch_max_64 must report the previous 64-bit value when it raises the target');
  CheckEqual(Int64(High(Int32)) + 20, LVal64,
    'atomic_fetch_max_64 must publish max(old, arg) for 64-bit values');

  LOld64 := atomic_fetch_min_64(LVal64, Int64(High(Int32)) + 25);
  CheckEqual(Int64(High(Int32)) + 20, LOld64,
    'atomic_fetch_min_64 must return the previous 64-bit value');
  CheckEqual(Int64(High(Int32)) + 20, LVal64,
    'atomic_fetch_min_64 must keep the smaller 64-bit value');
  LOld64 := atomic_fetch_min_64(LVal64, Int64(High(Int32)) + 3);
  CheckEqual(Int64(High(Int32)) + 20, LOld64,
    'atomic_fetch_min_64 must report the previous 64-bit value when it lowers the target');
  CheckEqual(Int64(High(Int32)) + 3, LVal64,
    'atomic_fetch_min_64 must publish min(old, arg) for 64-bit values');

  LVal64 := Int64($0F0F0F0F0F0F0F0F);
  LOld64 := atomic_fetch_nand_64(LVal64, Int64($00FF00FF00FF00FF));
  CheckEqual(Int64($0F0F0F0F0F0F0F0F), LOld64,
    'atomic_fetch_nand_64 must return the previous 64-bit value');
  CheckEqual(Int64(not (Int64($0F0F0F0F0F0F0F0F) and Int64($00FF00FF00FF00FF))), LVal64,
    'atomic_fetch_nand_64 must publish not(old and arg) for 64-bit values');
end;

procedure TestAtomicPointerOffsetFetchContract;
var
  LBytes: array[0..7] of Byte;
  LPtr: Pointer;
  LOld: Pointer;
begin
  LPtr := @LBytes[1];
  LOld := atomic_fetch_add(LPtr, 3);
  Check(LOld = @LBytes[1],
    'pointer atomic_fetch_add must return the previous pointer');
  Check(LPtr = @LBytes[4],
    'pointer atomic_fetch_add must publish the byte-offset pointer');

  LOld := atomic_fetch_sub(LPtr, 2);
  Check(LOld = @LBytes[4],
    'pointer atomic_fetch_sub must return the previous pointer');
  Check(LPtr = @LBytes[2],
    'pointer atomic_fetch_sub must publish the byte-offset pointer');
end;

procedure TestAtomicInvalidMemoryOrderContract;
var
  LVal: Int32;
  LExpected: Int32;
  LTypedAtomic: TAtomicUInt32;
  LTaggedStorage: atomic_tagged_ptr_t;
  LTaggedExpected: atomic_tagged_ptr_t;
  LTaggedDesired: atomic_tagged_ptr_t;
  LTaggedValue: Int32;
  LInvalidOrderValue: Integer;
  LInvalidOrder: memory_order_t;
  LRaised: Boolean;
begin
  LVal := 11;
  LTaggedValue := 29;
  LTaggedStorage := atomic_tagged_ptr(@LTaggedValue, 1);
  LTaggedExpected := LTaggedStorage;
  LTaggedDesired := atomic_tagged_ptr(@LTaggedValue, 2);

  LRaised := False;
  try
    atomic_load(LVal, mo_release);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'atomic_load release must raise EArgumentError');

  LRaised := False;
  try
    atomic_load(LVal, mo_acq_rel);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'atomic_load acq_rel must raise EArgumentError');

  LRaised := False;
  try
    atomic_store(LVal, 12, mo_consume);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'atomic_store consume must raise EArgumentError');

  LRaised := False;
  try
    atomic_store(LVal, 12, mo_acquire);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'atomic_store acquire must raise EArgumentError');

  LRaised := False;
  try
    atomic_store(LVal, 12, mo_acq_rel);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'atomic_store acq_rel must raise EArgumentError');

  LRaised := False;
  try
    atomic_tagged_ptr_load(LTaggedStorage, mo_release);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'tagged pointer load release must raise EArgumentError');

  LRaised := False;
  try
    atomic_tagged_ptr_store(LTaggedStorage, LTaggedDesired, mo_acquire);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'tagged pointer store acquire must raise EArgumentError');

  LExpected := 11;
  LRaised := False;
  try
    atomic_compare_exchange_strong(LVal, LExpected, 13, mo_acquire, mo_release);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'dual-order CAS failure release must raise EArgumentError');

  LExpected := 11;
  LRaised := False;
  try
    atomic_compare_exchange_strong(LVal, LExpected, 13, mo_seq_cst, mo_acq_rel);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'dual-order CAS failure acq_rel must raise EArgumentError');

  LExpected := 11;
  LRaised := False;
  try
    atomic_compare_exchange_strong(LVal, LExpected, 13, mo_relaxed, mo_consume);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'dual-order CAS failure stronger than relaxed success must raise EArgumentError');

  LExpected := 11;
  LRaised := False;
  try
    atomic_compare_exchange_strong(LVal, LExpected, 13, mo_consume, mo_acquire);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'dual-order CAS failure stronger than consume success must raise EArgumentError');

  LRaised := False;
  try
    atomic_tagged_ptr_compare_exchange_strong(
      LTaggedStorage, LTaggedExpected, LTaggedDesired, mo_acquire, mo_release);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'tagged pointer strong CAS failure release must raise EArgumentError');

  CheckEqual(Int64(11), Int64(atomic_load(LVal, mo_acquire)),
    'valid acquire load must remain accepted');
  atomic_store(LVal, 17, mo_release);
  CheckEqual(Int64(17), Int64(atomic_load(LVal, mo_acquire)),
    'valid release store must remain accepted');
  Check(atomic_tagged_ptr_get_ptr(atomic_tagged_ptr_load(LTaggedStorage, mo_acquire)) = @LTaggedValue,
    'valid tagged pointer acquire load must remain accepted');
  atomic_tagged_ptr_store(LTaggedStorage, LTaggedDesired, mo_release);
  CheckEqual(Int64(2), Int64(atomic_tagged_ptr_get_tag(atomic_tagged_ptr_load(LTaggedStorage, mo_acquire))),
    'valid tagged pointer release store must remain accepted');

  LTypedAtomic := TAtomicUInt32.Create(17);
  LRaised := False;
  try
    LTypedAtomic.Load(mo_release);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'typed atomic Load release must raise EArgumentError');

  LRaised := False;
  try
    LTypedAtomic.Store(19, mo_acquire);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'typed atomic Store acquire must raise EArgumentError');

  LInvalidOrderValue := Ord(mo_seq_cst) + 1;
  LInvalidOrder := memory_order_t(LInvalidOrderValue);

  LRaised := False;
  try
    atomic_load(LVal, LInvalidOrder);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'atomic_load invalid ordinal order must raise EArgumentError');

  LRaised := False;
  try
    atomic_store(LVal, 21, LInvalidOrder);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'atomic_store invalid ordinal order must raise EArgumentError');

  LRaised := False;
  try
    atomic_tagged_ptr_load(LTaggedStorage, LInvalidOrder);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'tagged pointer load invalid ordinal order must raise EArgumentError');

  LExpected := 17;
  LRaised := False;
  try
    atomic_compare_exchange_strong(LVal, LExpected, 23, LInvalidOrder, mo_relaxed);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'dual-order CAS invalid success ordinal must raise EArgumentError');

  LExpected := 17;
  LRaised := False;
  try
    atomic_compare_exchange_strong(LVal, LExpected, 23, mo_seq_cst, LInvalidOrder);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'dual-order CAS invalid failure ordinal must raise EArgumentError');

  LTaggedExpected := LTaggedDesired;
  LRaised := False;
  try
    atomic_tagged_ptr_compare_exchange_weak(
      LTaggedStorage, LTaggedExpected, LTaggedDesired, mo_seq_cst, LInvalidOrder);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'tagged pointer weak CAS invalid failure ordinal must raise EArgumentError');
end;

procedure TestAtomicCompatFacade;
var
  LVal: Int32;
  LOld: Int32;
  LFirst: Int32;
  LSecond: Int32;
  LPtr: Pointer;
  LObservedPtr: Pointer;
begin
  LVal := 0;
  nextpas.core.atomic.compat.AtomicStore32(LVal, 9, moRelease);
  CheckEqual(Int64(9), Int64(nextpas.core.atomic.compat.AtomicLoad32(LVal, moAcquire)));

  LOld := nextpas.core.atomic.compat.AtomicFetchAdd32(LVal, 4, moAcqRel);
  CheckEqual(Int64(9), Int64(LOld));
  CheckEqual(Int64(13), Int64(LVal));

  LOld := nextpas.core.atomic.compat.AtomicCompareExchange32(LVal, 99, 21, moRelease);
  CheckEqual(Int64(13), Int64(LOld),
    'compat AtomicCompareExchange32 must return observed value on mismatch');
  CheckEqual(Int64(13), Int64(LVal),
    'compat AtomicCompareExchange32 mismatch must leave target unchanged');

  LOld := nextpas.core.atomic.compat.AtomicCompareExchange32(LVal, 13, 21, moAcqRel);
  CheckEqual(Int64(13), Int64(LOld),
    'compat AtomicCompareExchange32 must return previous value on match');
  CheckEqual(Int64(21), Int64(LVal),
    'compat AtomicCompareExchange32 must publish desired value on match');

  LFirst := 1;
  LSecond := 2;
  LPtr := @LFirst;
  LObservedPtr := nextpas.core.atomic.compat.AtomicCompareExchangePtr(LPtr, @LSecond, nil, moRelease);
  Check(LObservedPtr = @LFirst,
    'compat AtomicCompareExchangePtr must return observed pointer on mismatch');
  Check(LPtr = @LFirst,
    'compat AtomicCompareExchangePtr mismatch must leave target unchanged');

  LObservedPtr := nextpas.core.atomic.compat.AtomicCompareExchangePtr(LPtr, @LFirst, @LSecond, moAcqRel);
  Check(LObservedPtr = @LFirst,
    'compat AtomicCompareExchangePtr must return previous pointer on match');
  Check(LPtr = @LSecond,
    'compat AtomicCompareExchangePtr must publish desired pointer on match');

  nextpas.core.atomic.compat.AtomicThreadFence(moSeqCst);
  nextpas.core.atomic.compat.AtomicSignalFence(moSeqCst);
  nextpas.core.atomic.compat.CpuPause;

  CheckEqual(Int64(PLATFORM_ERR_AGAIN),
    Int64(nextpas.core.atomic.compat.AtomicWait32(LVal, 99, 1000000)),
    'compat AtomicWait32 should surface wait-address mismatch result');
  CheckEqual(Int64(0), Int64(nextpas.core.atomic.compat.AtomicNotifyOne32(LVal)),
    'compat AtomicNotifyOne32 should succeed on supported platforms');
  CheckEqual(Int64(0), Int64(nextpas.core.atomic.compat.AtomicNotifyAll32(LVal)),
    'compat AtomicNotifyAll32 should succeed on supported platforms');
end;

procedure TestAtomicCompatAliasBehavior;
var
  LPtr: Pointer;
  LOldPtr: Pointer;
  LExpectedPtr: Pointer;
  LValue: Int32;
  LTagged: atomic_tagged_ptr_t;
  LExpectedTagged: atomic_tagged_ptr_t;
  LDesiredTagged: atomic_tagged_ptr_t;
begin
  LPtr := Pointer(PtrUInt($1000));
  LOldPtr := nextpas.core.atomic.compat.atomic_fetch_add(LPtr, Pointer(PtrUInt($20)));
  Check(LOldPtr = Pointer(PtrUInt($1000)),
    'compat pointer arithmetic fetch-add must return previous pointer value');
  Check(LPtr = Pointer(PtrUInt($1020)),
    'compat pointer arithmetic fetch-add must publish pointer-sized addition');

  LOldPtr := nextpas.core.atomic.compat.atomic_fetch_sub(LPtr, Pointer(PtrUInt($10)));
  Check(LOldPtr = Pointer(PtrUInt($1020)),
    'compat pointer arithmetic fetch-sub must return previous pointer value');
  Check(LPtr = Pointer(PtrUInt($1010)),
    'compat pointer arithmetic fetch-sub must publish pointer-sized subtraction');

  LPtr := Pointer(PtrUInt($F0F0));
  LOldPtr := nextpas.core.atomic.compat.atomic_fetch_and(LPtr, Pointer(PtrUInt($0FF0)));
  Check(LOldPtr = Pointer(PtrUInt($F0F0)),
    'compat pointer bitwise fetch-and must return previous pointer value');
  Check(LPtr = Pointer(PtrUInt($00F0)),
    'compat pointer bitwise fetch-and must publish masked pointer bits');

  LOldPtr := nextpas.core.atomic.compat.atomic_fetch_or(LPtr, Pointer(PtrUInt($0F00)));
  Check(LOldPtr = Pointer(PtrUInt($00F0)),
    'compat pointer bitwise fetch-or must return previous pointer value');
  Check(LPtr = Pointer(PtrUInt($0FF0)),
    'compat pointer bitwise fetch-or must publish combined pointer bits');

  LOldPtr := nextpas.core.atomic.compat.atomic_fetch_xor(LPtr, Pointer(PtrUInt($00FF)));
  Check(LOldPtr = Pointer(PtrUInt($0FF0)),
    'compat pointer bitwise fetch-xor must return previous pointer value');
  Check(LPtr = Pointer(PtrUInt($0F0F)),
    'compat pointer bitwise fetch-xor must publish toggled pointer bits');

  LPtr := Pointer(PtrUInt($2000));
  LOldPtr := nextpas.core.atomic.compat.atomic_increment(LPtr);
  Check(LOldPtr = Pointer(PtrUInt($2001)),
    'compat pointer increment must return updated pointer-sized value');
  Check(LPtr = Pointer(PtrUInt($2001)),
    'compat pointer increment must publish updated pointer-sized value');

  LOldPtr := nextpas.core.atomic.compat.atomic_decrement(LPtr);
  Check(LOldPtr = Pointer(PtrUInt($2000)),
    'compat pointer decrement must return updated pointer-sized value');
  Check(LPtr = Pointer(PtrUInt($2000)),
    'compat pointer decrement must publish updated pointer-sized value');

  LValue := 42;
  LPtr := @LValue;
  Check(nextpas.core.atomic.compat.atomic_load_ptr(LPtr, mo_acquire) = @LValue,
    'compat pointer helper load must return the stored pointer');
  nextpas.core.atomic.compat.atomic_store_ptr(LPtr, nil, mo_release);
  Check(nextpas.core.atomic.compat.atomic_load_ptr(LPtr) = nil,
    'compat pointer helper store must publish the desired pointer');

  LExpectedPtr := @LValue;
  Check(not nextpas.core.atomic.compat.atomic_compare_exchange_strong_ptr(LPtr, LExpectedPtr, @LValue),
    'compat pointer helper CAS must fail on expected mismatch');
  Check(LExpectedPtr = nil,
    'compat pointer helper CAS must update expected on mismatch');

  LExpectedPtr := nil;
  Check(nextpas.core.atomic.compat.atomic_compare_exchange_strong_ptr(LPtr, LExpectedPtr, @LValue),
    'compat pointer helper CAS must succeed on expected match');
  Check(LPtr = @LValue,
    'compat pointer helper CAS must publish desired pointer');

  LTagged := nextpas.core.atomic.compat.make_atomic_tagged_ptr_t(@LValue, 1);
  Check(atomic_tagged_ptr_get_ptr(
    nextpas.core.atomic.compat.atomic_load_atomic_tagged_ptr_t(LTagged, mo_acquire)) = @LValue,
    'compat tagged helper load must preserve pointer');
  CheckEqual(Int64(1), Int64(atomic_tagged_ptr_get_tag(
    nextpas.core.atomic.compat.atomic_load_atomic_tagged_ptr_t(LTagged, mo_acquire))),
    'compat tagged helper load must preserve tag');

  LDesiredTagged := nextpas.core.atomic.compat.make_atomic_tagged_ptr_t(@LValue, 2);
  nextpas.core.atomic.compat.atomic_store_atomic_tagged_ptr_t(LTagged, LDesiredTagged, mo_release);
  CheckEqual(Int64(2), Int64(atomic_tagged_ptr_get_tag(
    nextpas.core.atomic.compat.atomic_load_atomic_tagged_ptr_t(LTagged, mo_acquire))),
    'compat tagged helper store must publish desired tag');

  LExpectedTagged := LDesiredTagged;
  LDesiredTagged := nextpas.core.atomic.compat.make_atomic_tagged_ptr_t(@LValue, 3);
  Check(nextpas.core.atomic.compat.atomic_compare_exchange_strong_atomic_tagged_ptr_t(
    LTagged, LExpectedTagged, LDesiredTagged),
    'compat tagged helper CAS must succeed on expected match');
  CheckEqual(Int64(3), Int64(atomic_tagged_ptr_get_tag(
    nextpas.core.atomic.compat.atomic_load_atomic_tagged_ptr_t(LTagged, mo_acquire))),
    'compat tagged helper CAS must publish desired tag');

  LExpectedTagged := nextpas.core.atomic.compat.make_atomic_tagged_ptr_t(nil, 0);
  Check(not nextpas.core.atomic.compat.atomic_compare_exchange_strong_atomic_tagged_ptr_t(
    LTagged, LExpectedTagged, LDesiredTagged),
    'compat tagged helper CAS must fail on expected mismatch');
  CheckEqual(Int64(3), Int64(atomic_tagged_ptr_get_tag(LExpectedTagged)),
    'compat tagged helper CAS must update expected tag on mismatch');
end;

procedure TestAtomicTaggedPointer;
var
  LValue: Int32;
  LTagged: atomic_tagged_ptr_t;
  LExpected: atomic_tagged_ptr_t;
  LNext: atomic_tagged_ptr_t;
begin
  LValue := 42;
  LTagged := atomic_tagged_ptr(@LValue, 1);
  Check(atomic_tagged_ptr_get_ptr(LTagged) = @LValue, 'tagged pointer preserves pointer');
  CheckEqual(Int64(1), Int64(atomic_tagged_ptr_get_tag(LTagged)));

  LExpected := LTagged;
  LNext := atomic_tagged_ptr(@LValue, 2);
  Check(atomic_tagged_ptr_compare_exchange_strong(LTagged, LExpected, LNext),
    'tagged pointer CAS succeeds');
  CheckEqual(Int64(2), Int64(atomic_tagged_ptr_get_tag(LTagged)));
end;

procedure TestAtomicTaggedPointerUpdateContracts;
var
  LFirst: Int32;
  LSecond: Int32;
  LTagged: atomic_tagged_ptr_t;
  LWrapped: atomic_tagged_ptr_t;
  LMaxTag: {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF};
  LCycleGuard: Integer;
begin
  LFirst := 11;
  LSecond := 22;

  LTagged := atomic_tagged_ptr(@LFirst, 0);
  atomic_tagged_ptr_update(LTagged, @LSecond);
  Check(atomic_tagged_ptr_get_ptr(LTagged) = @LSecond,
    'tagged pointer update must replace pointer');
  CheckEqual(Int64(1), Int64(atomic_tagged_ptr_get_tag(LTagged)),
    'tagged pointer update must increment tag');

  atomic_tagged_ptr_update_tag(LTagged, 0);
  Check(atomic_tagged_ptr_get_ptr(LTagged) = @LSecond,
    'tagged pointer update_tag must preserve pointer');
  CheckEqual(Int64(0), Int64(atomic_tagged_ptr_get_tag(LTagged)),
    'tagged pointer update_tag must replace tag exactly');

  LMaxTag := 0;
  LCycleGuard := 0;
  while atomic_tagged_ptr_next(atomic_tagged_ptr(@LFirst, LMaxTag)) <> 0 do
  begin
    LMaxTag := atomic_tagged_ptr_next(atomic_tagged_ptr(@LFirst, LMaxTag));
    Inc(LCycleGuard);
    Check(LCycleGuard <= 1 shl 20,
      'tagged pointer next must wrap within a bounded public tag domain');
  end;

  LWrapped := atomic_tagged_ptr(@LFirst, LMaxTag);
  atomic_tagged_ptr_update(LWrapped, @LFirst);
  CheckEqual(Int64(0), Int64(atomic_tagged_ptr_get_tag(LWrapped)),
    'tagged pointer update must wrap MAX_TAG back to zero');
end;

procedure TestAtomicTaggedPointerRejectsOutOfRangeX8664Pointer;
{$IFDEF CPUX86_64}
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    atomic_tagged_ptr(Pointer(PtrUInt($0123456789ABCDEF)), 1);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'x86_64 tagged pointer must reject non-canonical packed pointer input');
end;
{$ELSE}
begin
end;
{$ENDIF}

type
  PAtomicWaitState = ^TAtomicWaitState;
  TAtomicWaitState = record
    Value: PInt32;
    WaitRet: Int32;
  end;

procedure TestAtomicWaitNotifySurfaceAndBehavior;
var
  LValue: Int32;
  LRet: Int32;
  LStarted: Int32;
  LState1: TAtomicWaitState;
  LState2: TAtomicWaitState;
  LThread1: TThread;
  LThread2: TThread;
  LSpin: Integer;
begin
  LValue := 7;
  LRet := atomic_wait(LValue, 9, 1000000);
  CheckEqual(Int64(PLATFORM_ERR_AGAIN), Int64(LRet),
    'atomic_wait must return AGAIN on value mismatch');

  LValue := 11;
  LRet := atomic_wait(LValue, 11, 0);
  CheckEqual(Int64(PLATFORM_ERR_TIMEOUT), Int64(LRet),
    'atomic_wait timeout=0 must report TIMEOUT when still equal');

  LState1.Value := @LValue;
  LState1.WaitRet := -1;
  LState2.Value := @LValue;
  LState2.WaitRet := -1;
  LValue := 0;
  LStarted := 0;

  LThread1 := TThread.CreateAnonymousThread(procedure
    var
      LWaitRet: Int32;
    begin
      atomic_fetch_add(LStarted, 1, mo_seq_cst);
      repeat
        if atomic_load(LState1.Value^, mo_seq_cst) <> 0 then
        begin
          LState1.WaitRet := 0;
          Exit;
        end;

        LWaitRet := atomic_wait(LState1.Value^, 0, 1000000000);
        if LWaitRet = 0 then
          Continue;
        if LWaitRet <> PLATFORM_ERR_AGAIN then
        begin
          LState1.WaitRet := LWaitRet;
          Exit;
        end;
      until False;
    end);
  LThread1.FreeOnTerminate := False;
  LThread2 := TThread.CreateAnonymousThread(procedure
    var
      LWaitRet: Int32;
    begin
      atomic_fetch_add(LStarted, 1, mo_seq_cst);
      repeat
        if atomic_load(LState2.Value^, mo_seq_cst) <> 0 then
        begin
          LState2.WaitRet := 0;
          Exit;
        end;

        LWaitRet := atomic_wait(LState2.Value^, 0, 1000000000);
        if LWaitRet = 0 then
          Continue;
        if LWaitRet <> PLATFORM_ERR_AGAIN then
        begin
          LState2.WaitRet := LWaitRet;
          Exit;
        end;
      until False;
    end);
  LThread2.FreeOnTerminate := False;

  LThread1.Start;
  LThread2.Start;

  for LSpin := 1 to 1000 do
  begin
    if atomic_load(LStarted, mo_seq_cst) = 2 then
      Break;
    Sleep(1);
  end;
  CheckEqual(Int64(2), Int64(atomic_load(LStarted, mo_seq_cst)),
    'waiter threads must start before notify path is exercised');

  atomic_store(LValue, 1, mo_seq_cst);
  LRet := atomic_notify_all(LValue);
  CheckEqual(Int64(0), Int64(LRet), 'atomic_notify_all should succeed on supported platforms');

  LThread1.WaitFor;
  LThread2.WaitFor;
  LThread1.Free;
  LThread2.Free;

  CheckEqual(Int64(0), Int64(LState1.WaitRet), 'first waiter should be released by notify_all');
  CheckEqual(Int64(0), Int64(LState2.WaitRet), 'second waiter should be released by notify_all');

  CheckEqual(Int64(0), Int64(atomic_notify_one(LValue)),
    'atomic_notify_one should succeed on supported platforms');
end;

procedure TestAtomicRefCountContract;
var
  LRef: TAtomicRefCount;
  LNewValue: PtrUInt;
  LRaised: Boolean;
begin
  LRef := TAtomicRefCount.Create(1);
  Check(TAtomicRefCount.is_lock_free = atomic_is_lock_free_ptr,
    'TAtomicRefCount lock-free surface must match pointer-sized runtime truth');
  CheckEqual(Int64(1), Int64(LRef.Load()));
  CheckEqual(Int64(2), Int64(LRef.Inc()));
  CheckEqual(Int64(2), Int64(LRef.Load()));
  Check(LRef.TryInc(LNewValue), 'TryInc should succeed from non-zero refcount');
  CheckEqual(Int64(3), Int64(LNewValue));
  CheckEqual(Int64(3), Int64(LRef.Load()));
  CheckEqual(Int64(3), Int64(LRef.IntoInner),
    'IntoInner should expose the current refcount');
  CheckEqual(Int64(2), Int64(LRef.Dec()));
  CheckEqual(Int64(1), Int64(LRef.Dec()));
  CheckEqual(Int64(0), Int64(LRef.Dec()));

  LRaised := False;
  try
    LRef.Dec();
  except
    on E: EInvalidOperationError do
      LRaised := True;
  end;
  Check(LRaised, 'Dec on zero refcount must raise EInvalidOperationError');

  LRaised := False;
  try
    LRef.Inc();
  except
    on E: EInvalidOperationError do
      LRaised := True;
  end;
  Check(LRaised, 'Inc on zero refcount must raise EInvalidOperationError');

  LRef := TAtomicRefCount.Create(0);
  LNewValue := 1234;
  Check(not LRef.TryInc(LNewValue), 'TryInc should fail from zero refcount');
  CheckEqual(Int64(0), Int64(LNewValue),
    'TryInc zero-state failure should clear the out value to 0');
  CheckEqual(Int64(0), Int64(LRef.Load()));

  LRef := TAtomicRefCount.Create(High(PtrUInt));
  LRaised := False;
  try
    LRef.Inc();
  except
    on E: EResourceExhaustedError do
      LRaised := True;
  end;
  Check(LRaised, 'Inc at High(PtrUInt) must raise EResourceExhaustedError');

  LRaised := False;
  try
    LRef.TryInc(LNewValue);
  except
    on E: EResourceExhaustedError do
      LRaised := True;
  end;
  Check(LRaised, 'TryInc at High(PtrUInt) must raise EResourceExhaustedError');
end;

procedure TestAtomicRefCountConcurrentBorrowContract;
const
  ThreadCount = 4;
  IterationsPerThread = 5000;
var
  LRef: TAtomicRefCount;
  LThreads: array[0..ThreadCount - 1] of TThread;
  LStarted: Int32;
  LGo: Int32;
  LSuccessCount: Int32;
  LTryIncFailureCount: Int32;
  LBadNewValueCount: Int32;
  LZeroDropCount: Int32;
  LThreadErrorCount: Int32;
  LI: Integer;
  LSpin: Integer;
begin
  LRef := TAtomicRefCount.Create(1);
  LStarted := 0;
  LGo := 0;
  LSuccessCount := 0;
  LTryIncFailureCount := 0;
  LBadNewValueCount := 0;
  LZeroDropCount := 0;
  LThreadErrorCount := 0;

  for LI := 0 to High(LThreads) do
  begin
    LThreads[LI] := TThread.CreateAnonymousThread(procedure
      var
        LJ: Integer;
        LNewValue: PtrUInt;
        LAfterDec: PtrUInt;
      begin
        atomic_fetch_add(LStarted, 1, mo_seq_cst);
        while atomic_load(LGo, mo_seq_cst) = 0 do
          cpu_pause;

        try
          for LJ := 1 to IterationsPerThread do
          begin
            if not LRef.TryInc(LNewValue) then
            begin
              atomic_fetch_add(LTryIncFailureCount, 1, mo_seq_cst);
              Continue;
            end;

            atomic_fetch_add(LSuccessCount, 1, mo_seq_cst);
            if LNewValue < 2 then
              atomic_fetch_add(LBadNewValueCount, 1, mo_seq_cst);

            LAfterDec := LRef.Dec;
            if LAfterDec = 0 then
              atomic_fetch_add(LZeroDropCount, 1, mo_seq_cst);
          end;
        except
          atomic_fetch_add(LThreadErrorCount, 1, mo_seq_cst);
        end;
      end);
    LThreads[LI].FreeOnTerminate := False;
    LThreads[LI].Start;
  end;

  for LSpin := 1 to 1000 do
  begin
    if atomic_load(LStarted, mo_seq_cst) = ThreadCount then
      Break;
    Sleep(1);
  end;
  CheckEqual(Int64(ThreadCount), Int64(atomic_load(LStarted, mo_seq_cst)),
    'refcount workers must start before the borrow phase is released');

  atomic_store(LGo, 1, mo_seq_cst);

  for LI := 0 to High(LThreads) do
  begin
    LThreads[LI].WaitFor;
    LThreads[LI].Free;
  end;

  CheckEqual(Int64(ThreadCount * IterationsPerThread), Int64(atomic_load(LSuccessCount, mo_seq_cst)),
    'every concurrent borrow attempt should succeed while one owner keeps the refcount alive');
  CheckEqual(Int64(0), Int64(atomic_load(LTryIncFailureCount, mo_seq_cst)),
    'TryInc must not report a zero-state failure while one owner stays live');
  CheckEqual(Int64(0), Int64(atomic_load(LBadNewValueCount, mo_seq_cst)),
    'successful TryInc must publish a refcount of at least 2 while one owner stays live');
  CheckEqual(Int64(0), Int64(atomic_load(LZeroDropCount, mo_seq_cst)),
    'balanced concurrent Dec calls must not drop the refcount to zero before the owner release');
  CheckEqual(Int64(0), Int64(atomic_load(LThreadErrorCount, mo_seq_cst)),
    'concurrent borrow workers must not raise unexpected exceptions');
  CheckEqual(Int64(1), Int64(LRef.Load()),
    'balanced concurrent borrows must restore the single owner count');
  CheckEqual(Int64(1), Int64(LRef.IntoInner),
    'IntoInner must expose the surviving owner count after concurrent borrows');
  CheckEqual(Int64(0), Int64(LRef.Dec()),
    'owner release should perform the only final drop after the borrow phase');
end;

procedure TestAtomicRefCountTerminalRaceContract;
const
  BorrowerCount = 4;
  RoundCount = 64;
var
  LRound: Integer;

  procedure RunRound;
  var
    LRef: TAtomicRefCount;
    LOwnerThread: TThread;
    LBorrowerThreads: array[0..BorrowerCount - 1] of TThread;
    LStarted: Int32;
    LGo: Int32;
    LBorrowSuccessCount: Int32;
    LBorrowFailureCount: Int32;
    LBorrowFailureNonZeroOutCount: Int32;
    LBorrowBadSuccessValueCount: Int32;
    LBorrowZeroDropCount: Int32;
    LThreadErrorCount: Int32;
    LOwnerDecValue: PtrUInt;
    LAllStarted: Boolean;
    LFinalDropCount: Int32;
    LI: Integer;
    LSpin: Integer;
  begin
    LRef := TAtomicRefCount.Create(1);
    LStarted := 0;
    LGo := 0;
    LBorrowSuccessCount := 0;
    LBorrowFailureCount := 0;
    LBorrowFailureNonZeroOutCount := 0;
    LBorrowBadSuccessValueCount := 0;
    LBorrowZeroDropCount := 0;
    LThreadErrorCount := 0;
    LOwnerDecValue := High(PtrUInt);

    LOwnerThread := TThread.CreateAnonymousThread(procedure
      begin
        atomic_fetch_add(LStarted, 1, mo_seq_cst);
        while atomic_load(LGo, mo_seq_cst) = 0 do
          cpu_pause;

        try
          LOwnerDecValue := LRef.Dec;
        except
          atomic_fetch_add(LThreadErrorCount, 1, mo_seq_cst);
        end;
      end);
    LOwnerThread.FreeOnTerminate := False;
    LOwnerThread.Start;

    for LI := 0 to High(LBorrowerThreads) do
    begin
      LBorrowerThreads[LI] := TThread.CreateAnonymousThread(procedure
        var
          LNewValue: PtrUInt;
          LAfterDec: PtrUInt;
        begin
          atomic_fetch_add(LStarted, 1, mo_seq_cst);
          while atomic_load(LGo, mo_seq_cst) = 0 do
            cpu_pause;

          try
            LNewValue := High(PtrUInt);
            if LRef.TryInc(LNewValue) then
            begin
              atomic_fetch_add(LBorrowSuccessCount, 1, mo_seq_cst);
              if LNewValue < 2 then
                atomic_fetch_add(LBorrowBadSuccessValueCount, 1, mo_seq_cst);

              LAfterDec := LRef.Dec;
              if LAfterDec = 0 then
                atomic_fetch_add(LBorrowZeroDropCount, 1, mo_seq_cst);
            end
            else
            begin
              atomic_fetch_add(LBorrowFailureCount, 1, mo_seq_cst);
              if LNewValue <> 0 then
                atomic_fetch_add(LBorrowFailureNonZeroOutCount, 1, mo_seq_cst);
            end;
          except
            atomic_fetch_add(LThreadErrorCount, 1, mo_seq_cst);
          end;
        end);
      LBorrowerThreads[LI].FreeOnTerminate := False;
      LBorrowerThreads[LI].Start;
    end;

    LAllStarted := False;
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(LStarted, mo_seq_cst) = BorrowerCount + 1 then
      begin
        LAllStarted := True;
        Break;
      end;
      Sleep(1);
    end;

    atomic_store(LGo, 1, mo_seq_cst);

    LOwnerThread.WaitFor;
    LOwnerThread.Free;
    for LI := 0 to High(LBorrowerThreads) do
    begin
      LBorrowerThreads[LI].WaitFor;
      LBorrowerThreads[LI].Free;
    end;

    Check(LAllStarted,
      'terminal-race workers must start before the release race is opened');
    Check(LOwnerDecValue <> High(PtrUInt),
      'owner release must publish a terminal-race result');
    CheckEqual(Int64(0), Int64(atomic_load(LThreadErrorCount, mo_seq_cst)),
      'terminal-race workers must not raise unexpected exceptions');
    CheckEqual(Int64(BorrowerCount),
      Int64(atomic_load(LBorrowSuccessCount, mo_seq_cst) + atomic_load(LBorrowFailureCount, mo_seq_cst)),
      'every terminal-race borrower must complete exactly one TryInc attempt');
    CheckEqual(Int64(0), Int64(atomic_load(LBorrowFailureNonZeroOutCount, mo_seq_cst)),
      'terminal-race TryInc failure must clear the out value to 0');
    CheckEqual(Int64(0), Int64(atomic_load(LBorrowBadSuccessValueCount, mo_seq_cst)),
      'terminal-race TryInc success must publish a borrowed refcount of at least 2');

    LFinalDropCount := atomic_load(LBorrowZeroDropCount, mo_seq_cst);
    if LOwnerDecValue = 0 then
      Inc(LFinalDropCount);
    CheckEqual(Int64(1), Int64(LFinalDropCount),
      'terminal race must have exactly one final drop to zero');

    if atomic_load(LBorrowSuccessCount, mo_seq_cst) = 0 then
    begin
      CheckEqual(Int64(0), Int64(LOwnerDecValue),
        'if no borrower extends the refcount, the owner release must perform the final drop');
      CheckEqual(Int64(BorrowerCount), Int64(atomic_load(LBorrowFailureCount, mo_seq_cst)),
        'if no borrower extends the refcount, every competing TryInc must observe zero-state failure');
    end;

    if LOwnerDecValue = 0 then
      CheckEqual(Int64(0), Int64(atomic_load(LBorrowZeroDropCount, mo_seq_cst)),
        'if the owner performs the final drop, no borrower release may also report zero')
    else
    begin
      Check(LOwnerDecValue > 0,
        'owner not performing the final drop must still leave a positive borrowed refcount');
      Check(atomic_load(LBorrowSuccessCount, mo_seq_cst) > 0,
        'a nonzero owner release result must mean at least one borrower won the race');
      CheckEqual(Int64(1), Int64(atomic_load(LBorrowZeroDropCount, mo_seq_cst)),
        'if the owner does not perform the final drop, exactly one borrower release must do so');
    end;

    CheckEqual(Int64(0), Int64(LRef.Load()),
      'terminal-race round must end at zero after all matched releases');
    CheckEqual(Int64(0), Int64(LRef.IntoInner),
      'IntoInner must expose zero after the terminal-race round');
  end;

begin
  for LRound := 1 to RoundCount do
    RunRound;
end;

begin
  T := TTestRunner.Create('nextpas.core.atomic');
  T.Run('Load32/Store32 all orders', @TestLoad32Store32);
  T.Run('Exchange32', @TestExchange32);
  T.Run('CompareExchange32', @TestCompareExchange32);
  T.Run('FetchAdd32/FetchSub32', @TestFetchAdd32);
  T.Run('FetchAnd32/Or32/Xor32', @TestFetchBitwise32);
  T.Run('Load64/Store64', @TestLoad64Store64);
  T.Run('Exchange64', @TestExchange64);
  T.Run('Pointer atomics', @TestPointerAtomics);
  T.Run('Fences (no crash)', @TestFence);
  T.Run('default atomic_load surface', @TestAtomicDefaultLoadSurface);
  T.Run('atomic source contracts', @TestAtomicSourceContracts);
  T.Run('Concurrent FetchAdd (4 threads x 10000)', @TestConcurrentFetchAdd);
  T.Run('fafafa-style atomic API', @TestFafafaStyleAtomicApi);
  T.Run('typed atomic record API', @TestAtomicRecordTypes);
  T.Run('typed atomic int32/uint32 contract', @TestAtomicInt32UInt32Contract);
  T.Run('typed atomic int32/uint32 fetch contract', @TestAtomicInt32UInt32FetchContract);
  {$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
  T.Run('typed atomic int64/uint64 contract', @TestAtomicInt64UInt64Contract);
  T.Run('typed atomic int64/uint64 fetch contract', @TestAtomicInt64UInt64FetchContract);
  {$ENDIF}
  T.Run('typed atomic bool contract', @TestAtomicBoolContract);
  T.Run('typed atomic isize/usize contract', @TestAtomicISizeUSizeContract);
  T.Run('typed atomic isize/usize fetch contract', @TestAtomicISizeUSizeFetchContract);
  T.Run('typed atomic ptr contract', @TestAtomicPtrContract);
  T.Run('atomic flag API', @TestAtomicFlagApi);
  T.Run('fetch max/min/nand contract', @TestAtomicFetchMaxMinNandContract);
  T.Run('pointer offset fetch contract', @TestAtomicPointerOffsetFetchContract);
  T.Run('invalid memory-order contract', @TestAtomicInvalidMemoryOrderContract);
  T.Run('compat PascalCase facade', @TestAtomicCompatFacade);
  T.Run('compat public alias behavior', @TestAtomicCompatAliasBehavior);
  T.Run('tagged pointer atomic API', @TestAtomicTaggedPointer);
  T.Run('tagged pointer update contracts', @TestAtomicTaggedPointerUpdateContracts);
  T.Run('tagged pointer rejects out-of-range x86_64 pointer', @TestAtomicTaggedPointerRejectsOutOfRangeX8664Pointer);
  T.Run('atomic wait/notify API', @TestAtomicWaitNotifySurfaceAndBehavior);
  T.Run('atomic refcount contract', @TestAtomicRefCountContract);
  T.Run('atomic refcount concurrent borrow contract', @TestAtomicRefCountConcurrentBorrowContract);
  T.Run('atomic refcount terminal race contract', @TestAtomicRefCountTerminalRaceContract);
  T.Summary;
end.
