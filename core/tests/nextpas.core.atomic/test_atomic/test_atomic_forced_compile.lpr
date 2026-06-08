program test_atomic_forced_compile;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.atomic;

type
  TSample = record
    Value: Int32;
  end;
  PSample = ^TSample;
  TAtomicSamplePtr = specialize TAtomicPtr<TSample>;

var
  GInt32: Int32;
  GUInt32: UInt32;
  GPtr: Pointer;
  GTagged: atomic_tagged_ptr_t;
  GSample: TSample;
  GAtomicInt32: TAtomicInt32;
  GAtomicUInt32: TAtomicUInt32;
  GAtomicBool: TAtomicBool;
  GAtomicFlag: TAtomicFlag;
  GAtomicISize: TAtomicISize;
  GAtomicUSize: TAtomicUSize;
  GAtomicRefCount: TAtomicRefCount;
  GAtomicPtr: TAtomicSamplePtr;
  {$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
  GInt64: Int64;
  GUInt64: UInt64;
  GAtomicInt64: TAtomicInt64;
  GAtomicUInt64: TAtomicUInt64;
  {$ENDIF}

procedure TouchScalarSurface;
var
  LExpected32: Int32;
  LExpectedU32: UInt32;
  LExpectedPtr: Pointer;
begin
  atomic_store(GInt32, 1, mo_release);
  GInt32 := atomic_load(GInt32, mo_acquire);
  GInt32 := atomic_exchange(GInt32, 2, mo_acq_rel);
  LExpected32 := 2;
  if atomic_compare_exchange_strong(GInt32, LExpected32, 3, mo_acq_rel, mo_acquire) then
    GInt32 := atomic_fetch_add(GInt32, 1, mo_seq_cst);
  GInt32 := atomic_fetch_sub(GInt32, 1, mo_relaxed);
  GInt32 := atomic_fetch_and(GInt32, 7, mo_acquire);
  GInt32 := atomic_fetch_or(GInt32, 8, mo_release);
  GInt32 := atomic_fetch_xor(GInt32, 3, mo_acq_rel);
  GInt32 := atomic_fetch_max(GInt32, 9, mo_seq_cst);
  GInt32 := atomic_fetch_min(GInt32, 4, mo_seq_cst);
  GInt32 := atomic_fetch_nand(GInt32, 1, mo_seq_cst);

  atomic_store(GUInt32, 1, mo_release);
  GUInt32 := atomic_load(GUInt32, mo_acquire);
  LExpectedU32 := GUInt32;
  if atomic_compare_exchange_weak(GUInt32, LExpectedU32, 5, mo_acq_rel, mo_acquire) then
    GUInt32 := atomic_fetch_add(GUInt32, 1, mo_seq_cst);

  GPtr := @GSample;
  LExpectedPtr := GPtr;
  if atomic_compare_exchange_strong(GPtr, LExpectedPtr, nil, mo_acq_rel, mo_acquire) then
    GPtr := atomic_exchange(GPtr, @GSample, mo_seq_cst);
  GPtr := atomic_fetch_add(GPtr, SizeOf(TSample));
  GPtr := atomic_fetch_sub(GPtr, SizeOf(TSample));

  AtomicStore32(GInt32, 11, moRelease);
  GInt32 := AtomicLoad32(GInt32, moAcquire);
  GInt32 := AtomicExchange32(GInt32, 12, moSeqCst);
  GInt32 := AtomicCompareExchange32(GInt32, 12, 13, moSeqCst);
  GInt32 := AtomicFetchAdd32(GInt32, 1, moRelaxed);
  GInt32 := AtomicFetchSub32(GInt32, 1, moRelaxed);
  GInt32 := AtomicFetchAnd32(GInt32, 7, moSeqCst);
  GInt32 := AtomicFetchOr32(GInt32, 8, moSeqCst);
  GInt32 := AtomicFetchXor32(GInt32, 3, moSeqCst);
  AtomicStorePtr(GPtr, @GSample, moRelease);
  GPtr := AtomicLoadPtr(GPtr, moAcquire);
  GPtr := AtomicExchangePtr(GPtr, nil, moSeqCst);
  GPtr := AtomicCompareExchangePtr(GPtr, nil, @GSample, moSeqCst);
end;

procedure TouchWideSurface;
{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
var
  LExpected64: Int64;
  LExpectedU64: UInt64;
begin
  atomic_store_64(GInt64, 1, mo_release);
  GInt64 := atomic_load_64(GInt64, mo_acquire);
  GInt64 := atomic_exchange_64(GInt64, 2, mo_acq_rel);
  LExpected64 := 2;
  if atomic_compare_exchange_strong_64(GInt64, LExpected64, 3, mo_acq_rel, mo_acquire) then
    GInt64 := atomic_fetch_add_64(GInt64, 1, mo_seq_cst);
  GInt64 := atomic_fetch_sub_64(GInt64, 1, mo_relaxed);
  GInt64 := atomic_fetch_and_64(GInt64, 7, mo_acquire);
  GInt64 := atomic_fetch_or_64(GInt64, 8, mo_release);
  GInt64 := atomic_fetch_xor_64(GInt64, 3, mo_acq_rel);
  GInt64 := atomic_fetch_max_64(GInt64, 9, mo_seq_cst);
  GInt64 := atomic_fetch_min_64(GInt64, 4, mo_seq_cst);
  GInt64 := atomic_fetch_nand_64(GInt64, 1, mo_seq_cst);

  atomic_store_64(GUInt64, 1, mo_release);
  GUInt64 := atomic_load_64(GUInt64, mo_acquire);
  LExpectedU64 := GUInt64;
  if atomic_compare_exchange_weak_64(GUInt64, LExpectedU64, 5, mo_acq_rel, mo_acquire) then
    GUInt64 := atomic_fetch_add_64(GUInt64, 1, mo_seq_cst);

  AtomicStore64(GInt64, 11, moRelease);
  GInt64 := AtomicLoad64(GInt64, moAcquire);
  GInt64 := AtomicExchange64(GInt64, 12, moSeqCst);
  GInt64 := AtomicCompareExchange64(GInt64, 12, 13, moSeqCst);
  GInt64 := AtomicFetchAdd64(GInt64, 1, moRelaxed);
  GInt64 := AtomicFetchSub64(GInt64, 1, moRelaxed);

  GAtomicInt64 := TAtomicInt64.Create(1);
  GInt64 := GAtomicInt64.Load(mo_acquire);
  GAtomicInt64.Store(GInt64 + 1, mo_release);
  GInt64 := GAtomicInt64.Exchange(3, mo_acq_rel);
  LExpected64 := 3;
  if GAtomicInt64.CompareExchangeStrong(LExpected64, 4, mo_seq_cst) then
    GInt64 := GAtomicInt64.FetchAdd(1, mo_relaxed);
  GInt64 := GAtomicInt64.FetchSub(1, mo_relaxed);
  GInt64 := GAtomicInt64.FetchAnd(7, mo_acquire);
  GInt64 := GAtomicInt64.FetchOr(8, mo_release);
  GInt64 := GAtomicInt64.FetchXor(3, mo_acq_rel);
  GInt64 := GAtomicInt64.FetchMax(9, mo_seq_cst);
  GInt64 := GAtomicInt64.FetchMin(4, mo_seq_cst);
  GInt64 := GAtomicInt64.FetchNand(1, mo_seq_cst);
  GInt64 := GAtomicInt64.Increment(mo_seq_cst);
  GInt64 := GAtomicInt64.Decrement(mo_seq_cst);

  GAtomicUInt64 := TAtomicUInt64.Create(1);
  GUInt64 := GAtomicUInt64.Load(mo_acquire);
  GAtomicUInt64.Store(GUInt64 + 1, mo_release);
  LExpectedU64 := GUInt64 + 1;
  if GAtomicUInt64.CompareExchangeWeak(LExpectedU64, 9, mo_seq_cst) then
    GUInt64 := GAtomicUInt64.FetchAdd(1, mo_relaxed);
end;
{$ELSE}
begin
end;
{$ENDIF}

procedure TouchTypedSurface;
var
  LExpected32: Int32;
  LExpectedU32: UInt32;
  LExpectedISize: PtrInt;
  LExpectedUSize: PtrUInt;
  LExpectedBool: Boolean;
  LExpectedSample: PSample;
  LRefValue: PtrUInt;
begin
  GAtomicInt32 := TAtomicInt32.Create(1);
  if TAtomicInt32.is_lock_free then
    GInt32 := GAtomicInt32.GetMut^;
  GInt32 := GAtomicInt32.Load(mo_acquire);
  GAtomicInt32.Store(GInt32 + 1, mo_release);
  GInt32 := GAtomicInt32.Exchange(3, mo_acq_rel);
  LExpected32 := 3;
  if GAtomicInt32.CompareExchangeStrong(LExpected32, 4, mo_seq_cst) then
    GInt32 := GAtomicInt32.FetchAdd(1, mo_relaxed);
  GInt32 := GAtomicInt32.FetchSub(1, mo_relaxed);
  GInt32 := GAtomicInt32.FetchAnd(7, mo_acquire);
  GInt32 := GAtomicInt32.FetchOr(8, mo_release);
  GInt32 := GAtomicInt32.FetchXor(3, mo_acq_rel);
  GInt32 := GAtomicInt32.FetchMax(9, mo_seq_cst);
  GInt32 := GAtomicInt32.FetchMin(4, mo_seq_cst);
  GInt32 := GAtomicInt32.FetchNand(1, mo_seq_cst);
  GInt32 := GAtomicInt32.Increment(mo_seq_cst);
  GInt32 := GAtomicInt32.Decrement(mo_seq_cst);
  GInt32 := GAtomicInt32.IntoInner;

  GAtomicUInt32 := TAtomicUInt32.Create(1);
  if TAtomicUInt32.is_lock_free then
    GUInt32 := GAtomicUInt32.GetMut^;
  GUInt32 := GAtomicUInt32.Load(mo_acquire);
  GAtomicUInt32.Store(GUInt32 + 1, mo_release);
  LExpectedU32 := GUInt32 + 1;
  if GAtomicUInt32.CompareExchangeWeak(LExpectedU32, 9, mo_seq_cst) then
    GUInt32 := GAtomicUInt32.FetchAdd(1, mo_relaxed);
  GUInt32 := GAtomicUInt32.Exchange(3, mo_acq_rel);
  LExpectedU32 := GUInt32;
  if GAtomicUInt32.CompareExchangeStrong(LExpectedU32, 4, mo_seq_cst) then
    GUInt32 := GAtomicUInt32.FetchSub(1, mo_relaxed);
  GUInt32 := GAtomicUInt32.FetchAnd(7, mo_acquire);
  GUInt32 := GAtomicUInt32.FetchOr(8, mo_release);
  GUInt32 := GAtomicUInt32.FetchXor(3, mo_acq_rel);
  GUInt32 := GAtomicUInt32.Increment(mo_seq_cst);
  GUInt32 := GAtomicUInt32.Decrement(mo_seq_cst);
  GUInt32 := GAtomicUInt32.IntoInner;

  GAtomicBool := TAtomicBool.Create(False);
  if TAtomicBool.is_lock_free then
    GInt32 := GAtomicBool.GetMut^;
  GAtomicBool.Store(True, mo_release);
  LExpectedBool := GAtomicBool.Load(mo_acquire);
  LExpectedBool := GAtomicBool.Exchange(False, mo_acq_rel);
  LExpectedBool := True;
  if GAtomicBool.CompareExchangeStrong(LExpectedBool, False, mo_seq_cst) then
    LExpectedBool := GAtomicBool.FetchNand(True, mo_acq_rel);
  LExpectedBool := False;
  if GAtomicBool.CompareExchangeWeak(LExpectedBool, True, mo_seq_cst) then
    LExpectedBool := GAtomicBool.Load(mo_acquire);
  LExpectedBool := GAtomicBool.FetchAnd(True, mo_acquire);
  LExpectedBool := GAtomicBool.FetchOr(False, mo_release);
  LExpectedBool := GAtomicBool.FetchXor(True, mo_acq_rel);
  LExpectedBool := GAtomicBool.IntoInner;

  GAtomicFlag := TAtomicFlag.Create(False);
  LExpectedBool := TAtomicFlag.is_lock_free;
  if GAtomicFlag.test_and_set(mo_acq_rel) then
    GAtomicFlag.clear(mo_release);
  LExpectedBool := GAtomicFlag.test(mo_acquire);

  GAtomicISize := TAtomicISize.Create(1);
  if TAtomicISize.is_lock_free then
    LExpectedISize := GAtomicISize.GetMut^;
  GAtomicISize.Store(GAtomicISize.Load(mo_acquire) + 1, mo_release);
  GAtomicISize.Exchange(3, mo_acq_rel);
  LExpectedISize := GAtomicISize.IntoInner;
  GAtomicISize := TAtomicISize.Create(LExpectedISize);
  if GAtomicISize.CompareExchangeStrong(LExpectedISize, 4, mo_seq_cst) then
    GAtomicISize.Increment(mo_seq_cst);
  LExpectedISize := GAtomicISize.Load(mo_acquire);
  if GAtomicISize.CompareExchangeWeak(LExpectedISize, 5, mo_seq_cst) then
    GAtomicISize.Decrement(mo_seq_cst);
  GAtomicISize.FetchAdd(1, mo_relaxed);
  GAtomicISize.FetchSub(1, mo_relaxed);
  GAtomicISize.FetchAnd(7, mo_acquire);
  GAtomicISize.FetchOr(8, mo_release);
  GAtomicISize.FetchXor(3, mo_acq_rel);

  GAtomicUSize := TAtomicUSize.Create(1);
  if TAtomicUSize.is_lock_free then
    LExpectedUSize := GAtomicUSize.GetMut^;
  GAtomicUSize.Store(GAtomicUSize.Load(mo_acquire) + 1, mo_release);
  GAtomicUSize.Exchange(3, mo_acq_rel);
  LExpectedUSize := GAtomicUSize.IntoInner;
  GAtomicUSize := TAtomicUSize.Create(LExpectedUSize);
  if GAtomicUSize.CompareExchangeStrong(LExpectedUSize, 4, mo_seq_cst) then
    GAtomicUSize.Increment(mo_seq_cst);
  LExpectedUSize := GAtomicUSize.Load(mo_acquire);
  if GAtomicUSize.CompareExchangeWeak(LExpectedUSize, 5, mo_seq_cst) then
    GAtomicUSize.Decrement(mo_seq_cst);
  GAtomicUSize.FetchAdd(1, mo_relaxed);
  GAtomicUSize.FetchSub(1, mo_relaxed);
  GAtomicUSize.FetchAnd(7, mo_acquire);
  GAtomicUSize.FetchOr(8, mo_release);
  GAtomicUSize.FetchXor(3, mo_acq_rel);

  GAtomicRefCount := TAtomicRefCount.Create(1);
  LExpectedBool := TAtomicRefCount.is_lock_free;
  LRefValue := GAtomicRefCount.Load(mo_acquire);
  LRefValue := GAtomicRefCount.Inc;
  if GAtomicRefCount.TryInc(LRefValue) then
    LRefValue := GAtomicRefCount.Dec;
  LRefValue := GAtomicRefCount.IntoInner;

  GAtomicPtr := TAtomicSamplePtr.Create(@GSample);
  if TAtomicSamplePtr.is_lock_free then
    GPtr := GAtomicPtr.GetMut;
  LExpectedSample := GAtomicPtr.Load(mo_acquire);
  GAtomicPtr.Store(LExpectedSample, mo_release);
  LExpectedSample := GAtomicPtr.Exchange(@GSample, mo_acq_rel);
  if GAtomicPtr.CompareExchangeStrong(LExpectedSample, nil, mo_seq_cst) then
    LExpectedSample := GAtomicPtr.Load(mo_acquire);
  GAtomicPtr.CompareExchangeWeak(LExpectedSample, @GSample, mo_seq_cst);
  LExpectedSample := GAtomicPtr.IntoInner;
end;

procedure TouchTaggedAndWaitSurface;
var
  LExpectedTagged: atomic_tagged_ptr_t;
begin
  atomic_thread_fence(mo_relaxed);
  atomic_thread_fence(mo_consume);
  atomic_thread_fence(mo_acquire);
  atomic_thread_fence(mo_release);
  atomic_thread_fence(mo_acq_rel);
  atomic_thread_fence(mo_seq_cst);
  atomic_signal_fence(mo_relaxed);
  atomic_signal_fence(mo_consume);
  atomic_signal_fence(mo_acquire);
  atomic_signal_fence(mo_release);
  atomic_signal_fence(mo_acq_rel);
  atomic_signal_fence(mo_seq_cst);
  AtomicThreadFence(moRelaxed);
  AtomicThreadFence(moConsume);
  AtomicThreadFence(moAcquire);
  AtomicThreadFence(moRelease);
  AtomicThreadFence(moAcqRel);
  AtomicThreadFence(moSeqCst);
  AtomicSignalFence(moRelaxed);
  AtomicSignalFence(moConsume);
  AtomicSignalFence(moAcquire);
  AtomicSignalFence(moRelease);
  AtomicSignalFence(moAcqRel);
  AtomicSignalFence(moSeqCst);
  cpu_pause;
  CpuPause;

  GTagged := atomic_tagged_ptr(@GSample, 0);
  LExpectedTagged := GTagged;
  GTagged := atomic_tagged_ptr_load(GTagged, mo_acquire);
  atomic_tagged_ptr_store(GTagged, LExpectedTagged, mo_release);
  GTagged := atomic_tagged_ptr_exchange(GTagged, LExpectedTagged, mo_acq_rel);
  if atomic_tagged_ptr_compare_exchange_strong(GTagged, LExpectedTagged,
    atomic_tagged_ptr(@GSample, atomic_tagged_ptr_next(LExpectedTagged)),
    mo_acq_rel, mo_acquire) then
    atomic_tagged_ptr_update(GTagged, @GSample);
  atomic_tagged_ptr_compare_exchange_weak(GTagged, LExpectedTagged,
    atomic_tagged_ptr(@GSample, 0), mo_seq_cst, mo_acquire);
  atomic_tagged_ptr_update_tag(GTagged, atomic_tagged_ptr_get_tag(GTagged));
  GPtr := atomic_tagged_ptr_get_ptr(GTagged);

  GInt32 := AtomicWait32(GInt32, GInt32, 0);
  GInt32 := AtomicNotifyOne32(GInt32);
  GInt32 := AtomicNotifyAll32(GInt32);
  GInt32 := atomic_wait(GInt32, GInt32, 0);
  GInt32 := atomic_notify_one(GInt32);
  GInt32 := atomic_notify_all(GInt32);
end;

begin
  TouchScalarSurface;
  TouchWideSurface;
  TouchTypedSurface;
  TouchTaggedAndWaitSurface;
end.
