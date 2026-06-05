program test_atomic;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.atomic,
  nextpas.core.atomic.compat;

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

procedure TestAtomicSourceContracts;
const
  AtomicSourcePath = '../../../src/nextpas.core.atomic.pas';
  AtomicCoreSourcePath = '../../../src/nextpas.core.atomic.core.pas';
  AtomicTypesSourcePath = '../../../src/nextpas.core.atomic.types.pas';
  AtomicCompatSourcePath = '../../../src/nextpas.core.atomic.compat.pas';
  AtomicX8664SnapshotLegacyPath = '../../../src/nextpas.core.atomic.x86_64.inc';
  AtomicX8664SnapshotArchivePath = '../../../docs/archive/atomic/nextpas.core.atomic.x86_64.snapshot.txt';
var
  LAtomicSource: string;
  LAtomicCoreSource: string;
  LAtomicTypesSource: string;
  LAtomicCompatSource: string;
  LX8664SnapshotSource: string;
  LSignalFenceSection: string;
  LSignalFenceHelperSection: string;
  LSeqCstFenceHelperSection: string;
  LTaggedPtrSection: string;
  LThreadFenceSection: string;
  LSingleStrongCasSection: string;
  LSingleWeakCasSection: string;
  LCompatFailureSection: string;
  LTypesFailureSection: string;
  LTypesInt64LockFreeSection: string;
  LTypesUInt64LockFreeSection: string;
  LFetchAddFallbackSection: string;
  LLoad32Section: string;
  LLoad64Section: string;
  LLoad32SeqCstSection: string;
  LLoad64SeqCstSection: string;
  LStore32Section: string;
  LStore64Section: string;
  LStore32SeqCstSection: string;
  LStore64SeqCstSection: string;
  LPascalCaseCas32Section: string;
  LPascalCaseCas64Section: string;
  LPascalCaseCasPtrSection: string;
begin
  LAtomicSource := ReadUtf8TextFile(AtomicSourcePath);
  LAtomicCoreSource := ReadUtf8TextFile(AtomicCoreSourcePath);
  LAtomicTypesSource := ReadUtf8TextFile(AtomicTypesSourcePath);
  LAtomicCompatSource := ReadUtf8TextFile(AtomicCompatSourcePath);
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
  LTypesInt64LockFreeSection := ExtractImplementationSection(LAtomicTypesSource,
    'class function TAtomicInt64.is_lock_free: Boolean;',
    'function TAtomicInt64.Load(AOrder: memory_order_t): Int64;');
  LTypesUInt64LockFreeSection := ExtractImplementationSection(LAtomicTypesSource,
    'class function TAtomicUInt64.is_lock_free: Boolean;',
    'function TAtomicUInt64.Load(AOrder: memory_order_t): UInt64;');
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
  LPascalCaseCas32Section := ExtractImplementationSection(LAtomicSource,
    'function AtomicCompareExchange32(var ATarget: Int32; const AExpected, ADesired: Int32; const AOrder: TMemoryOrder): Int32;',
    'function AtomicFetchAdd32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;');
  LPascalCaseCas64Section := ExtractImplementationSection(LAtomicSource,
    'function AtomicCompareExchange64(var ATarget: Int64; const AExpected, ADesired: Int64; const AOrder: TMemoryOrder): Int64;',
    'function AtomicFetchAdd64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder): Int64;');
  LPascalCaseCasPtrSection := ExtractImplementationSection(LAtomicSource,
    'function AtomicCompareExchangePtr(var ATarget: Pointer; const AExpected, ADesired: Pointer; const AOrder: TMemoryOrder): Pointer;',
    'procedure AtomicThreadFence(const AOrder: TMemoryOrder);');

  Check(Pos('mo_relaxed: 无效，会触发运行时错误', LAtomicSource) = 0,
    'atomic_thread_fence docs must not claim mo_relaxed raises runtime error');
  CheckNotContains(LAtomicSource, '@performance 零开销（仅编译器指令）',
    'atomic_signal_fence docs must not promise zero runtime overhead');
  CheckContains(LAtomicSource, 'Legacy PascalCase compatibility facade.',
    'main atomic unit must mark PascalCase wrappers as legacy compatibility surface');
  CheckContains(LAtomicSource, 'Prefer atomic_* or TAtomic* in new code.',
    'main atomic unit must recommend canonical C-style or typed APIs');
  CheckContains(LAtomicSource,
    'On x86/x86_64, a plain load is already strongly ordered at the CPU level;',
    'seq_cst load docs must describe x86 plain-load mapping');
  CheckContains(LAtomicSource,
    'use only a compiler barrier to prevent reordering.',
    'seq_cst load docs must describe compiler-barrier-only x86 mapping');
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
  CheckContains(LThreadFenceSection, 'mo_seq_cst: atomic_seq_cst_fence;',
    'atomic_thread_fence seq_cst must route through the dedicated seq_cst fence helper');
  CheckContains(LAtomicCompatSource, 'Legacy PascalCase compatibility facade mirrored for older call sites.',
    'compat unit must document PascalCase compatibility ownership');
  CheckContains(LAtomicCompatSource, 'function AtomicLoad32',
    'compat unit must mirror PascalCase load/store facade');
  CheckContains(LAtomicCompatSource, 'procedure AtomicThreadFence',
    'compat unit must mirror PascalCase fence facade');
  CheckContains(LX8664SnapshotSource, 'Archived historical x86_64 atomic implementation snapshot.',
    'archived x86_64 snapshot must be marked historical');
  CheckContains(LX8664SnapshotSource, 'Documentation archive only.',
    'archived x86_64 snapshot must declare documentation-only status');
  CheckContains(LX8664SnapshotSource, 'This file is not part of the live source set.',
    'archived x86_64 snapshot must declare non-live status');
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
  CheckContains(LCompatFailureSection, 'mo_consume',
    'AtomicCompatFailureOrder must treat consume explicitly');
  CheckContains(LTypesFailureSection, 'mo_consume',
    'typed CAS failure-order helper must treat consume explicitly');
  CheckContains(LTypesInt64LockFreeSection, 'atomic_is_lock_free_64',
    'typed Int64 lock-free query must delegate to runtime truth');
  CheckContains(LTypesUInt64LockFreeSection, 'atomic_is_lock_free_64',
    'typed UInt64 lock-free query must delegate to runtime truth');
  CheckContains(LFetchAddFallbackSection, 'try',
    'i386 64-bit fallback add must guard lock release with try/finally');
  CheckContains(LFetchAddFallbackSection, 'finally',
    'i386 64-bit fallback add must guard lock release with try/finally');
  CheckNotContains(LLoad64Section, 'Result := aObj;' + LineEnding + '  {$IF DEFINED(CPUX86) AND NOT DEFINED(CPU64)}',
    'i386 64-bit atomic load must not perform a pre-load plain read');
  CheckContains(LLoad32SeqCstSection, 'atomic_seq_cst_fence;',
    'non-x86 seq_cst 32-bit load must use the dedicated seq_cst fence helper');
  CheckContains(LLoad64SeqCstSection, 'atomic_seq_cst_fence;',
    'non-x86 seq_cst 64-bit load must use the dedicated seq_cst fence helper');
  CheckContains(LStore32SeqCstSection, 'atomic_seq_cst_fence;',
    'non-x86 seq_cst 32-bit store must use the dedicated seq_cst fence helper');
  CheckContains(LStore64SeqCstSection, 'atomic_seq_cst_fence;',
    'non-x86 seq_cst 64-bit store must use the dedicated seq_cst fence helper');
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
var
  LAtomic: TAtomicUInt32;
  LExpected: UInt32;
begin
  LAtomic := TAtomicUInt32.Create(7);
  CheckEqual(Int64(7), Int64(LAtomic.Load(mo_relaxed)));

  CheckEqual(Int64(7), Int64(LAtomic.FetchAdd(5, mo_acq_rel)));
  CheckEqual(Int64(12), Int64(LAtomic.Load(mo_acquire)));

  LExpected := 12;
  Check(LAtomic.CompareExchangeStrong(LExpected, 18, mo_seq_cst),
    'record strong CAS succeeds');
  CheckEqual(Int64(18), Int64(LAtomic.IntoInner));
end;

procedure TestAtomicCompatFacade;
var
  LVal: Int32;
  LOld: Int32;
begin
  LVal := 0;
  nextpas.core.atomic.compat.AtomicStore32(LVal, 9, moRelease);
  CheckEqual(Int64(9), Int64(nextpas.core.atomic.compat.AtomicLoad32(LVal, moAcquire)));

  LOld := nextpas.core.atomic.compat.AtomicFetchAdd32(LVal, 4, moAcqRel);
  CheckEqual(Int64(9), Int64(LOld));
  CheckEqual(Int64(13), Int64(LVal));

  nextpas.core.atomic.compat.AtomicThreadFence(moSeqCst);
  nextpas.core.atomic.compat.AtomicSignalFence(moSeqCst);
  nextpas.core.atomic.compat.CpuPause;
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
  T.Run('atomic source contracts', @TestAtomicSourceContracts);
  T.Run('Concurrent FetchAdd (4 threads x 10000)', @TestConcurrentFetchAdd);
  T.Run('fafafa-style atomic API', @TestFafafaStyleAtomicApi);
  T.Run('typed atomic record API', @TestAtomicRecordTypes);
  T.Run('compat PascalCase facade', @TestAtomicCompatFacade);
  T.Run('tagged pointer atomic API', @TestAtomicTaggedPointer);
  T.Run('tagged pointer rejects out-of-range x86_64 pointer', @TestAtomicTaggedPointerRejectsOutOfRangeX8664Pointer);
  T.Summary;
end.
