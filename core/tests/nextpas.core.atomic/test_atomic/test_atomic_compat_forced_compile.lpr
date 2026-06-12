program test_atomic_compat_forced_compile;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.atomic.compat;

type
  TSample = record
    Value: Int32;
  end;

var
  GInt32: Int32;
  GPtr: Pointer;
  GOtherPtr: Pointer;
  GExpectedPtr: Pointer;
  GTagged: atomic_tagged_ptr_t;
  GExpectedTagged: atomic_tagged_ptr_t;
  GDesiredTagged: atomic_tagged_ptr_t;
  GSample: TSample;
  {$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
  GInt64: Int64;
  {$ENDIF}

procedure TouchCompatPointerAliases;
begin
  GPtr := Pointer(PtrUInt($1000));
  GOtherPtr := Pointer(PtrUInt($20));

  GPtr := nextpas.core.atomic.compat.atomic_fetch_add(GPtr, GOtherPtr);
  GPtr := nextpas.core.atomic.compat.atomic_fetch_sub(GPtr, GOtherPtr);
  GPtr := nextpas.core.atomic.compat.atomic_fetch_and(GPtr, Pointer(PtrUInt($0FF0)));
  GPtr := nextpas.core.atomic.compat.atomic_fetch_or(GPtr, Pointer(PtrUInt($00F0)));
  GPtr := nextpas.core.atomic.compat.atomic_fetch_xor(GPtr, Pointer(PtrUInt($000F)));
  GPtr := nextpas.core.atomic.compat.atomic_increment(GPtr);
  GPtr := nextpas.core.atomic.compat.atomic_decrement(GPtr);

  GPtr := @GSample;
  GExpectedPtr := nil;
  GPtr := nextpas.core.atomic.compat.atomic_load_ptr(GPtr, mo_acquire);
  nextpas.core.atomic.compat.atomic_store_ptr(GPtr, @GSample, mo_release);
  GPtr := nextpas.core.atomic.compat.atomic_load_ptr(GPtr);
  nextpas.core.atomic.compat.atomic_store_ptr(GPtr, nil);
  if nextpas.core.atomic.compat.atomic_compare_exchange_strong_ptr(
    GPtr, GExpectedPtr, @GSample) then
    GPtr := GExpectedPtr;
end;

procedure TouchCompatTaggedAliases;
begin
  GTagged := nextpas.core.atomic.compat.make_atomic_tagged_ptr_t(@GSample, 1);
  GDesiredTagged := nextpas.core.atomic.compat.make_atomic_tagged_ptr_t(@GSample, 2);
  GExpectedTagged := nextpas.core.atomic.compat.atomic_load_atomic_tagged_ptr_t(
    GTagged, mo_acquire);
  nextpas.core.atomic.compat.atomic_store_atomic_tagged_ptr_t(
    GTagged, GDesiredTagged, mo_release);
  if nextpas.core.atomic.compat.atomic_compare_exchange_strong_atomic_tagged_ptr_t(
    GTagged, GExpectedTagged, GDesiredTagged) then
    GTagged := GExpectedTagged;
end;

procedure TouchCompatPascalCaseFacade;
begin
  nextpas.core.atomic.compat.AtomicStore32(GInt32, 1, moRelease);
  GInt32 := nextpas.core.atomic.compat.AtomicLoad32(GInt32, moAcquire);
  GInt32 := nextpas.core.atomic.compat.AtomicExchange32(GInt32, 2, moAcqRel);
  GInt32 := nextpas.core.atomic.compat.AtomicCompareExchange32(GInt32, 2, 3, moSeqCst);
  GInt32 := nextpas.core.atomic.compat.AtomicFetchAdd32(GInt32, 1, moRelaxed);
  GInt32 := nextpas.core.atomic.compat.AtomicFetchSub32(GInt32, 1, moRelaxed);
  GInt32 := nextpas.core.atomic.compat.AtomicFetchAnd32(GInt32, 7, moSeqCst);
  GInt32 := nextpas.core.atomic.compat.AtomicFetchOr32(GInt32, 8, moSeqCst);
  GInt32 := nextpas.core.atomic.compat.AtomicFetchXor32(GInt32, 3, moSeqCst);

  nextpas.core.atomic.compat.AtomicStorePtr(GPtr, @GSample, moRelease);
  GPtr := nextpas.core.atomic.compat.AtomicLoadPtr(GPtr, moAcquire);
  GPtr := nextpas.core.atomic.compat.AtomicExchangePtr(GPtr, nil, moSeqCst);
  GPtr := nextpas.core.atomic.compat.AtomicCompareExchangePtr(GPtr, nil, @GSample, moSeqCst);
  GInt32 := nextpas.core.atomic.compat.AtomicWait32(GInt32, GInt32, 0);
  GInt32 := nextpas.core.atomic.compat.AtomicNotifyOne32(GInt32);
  GInt32 := nextpas.core.atomic.compat.AtomicNotifyAll32(GInt32);
  nextpas.core.atomic.compat.AtomicThreadFence(moSeqCst);
  nextpas.core.atomic.compat.AtomicThreadFence;
  nextpas.core.atomic.compat.AtomicSignalFence(moSeqCst);
  nextpas.core.atomic.compat.AtomicSignalFence;
  nextpas.core.atomic.compat.CpuPause;

  {$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
  nextpas.core.atomic.compat.AtomicStore64(GInt64, 1, moRelease);
  GInt64 := nextpas.core.atomic.compat.AtomicLoad64(GInt64, moAcquire);
  GInt64 := nextpas.core.atomic.compat.AtomicExchange64(GInt64, 2, moAcqRel);
  GInt64 := nextpas.core.atomic.compat.AtomicCompareExchange64(GInt64, 2, 3, moSeqCst);
  GInt64 := nextpas.core.atomic.compat.AtomicFetchAdd64(GInt64, 1, moRelaxed);
  GInt64 := nextpas.core.atomic.compat.AtomicFetchSub64(GInt64, 1, moRelaxed);
  {$ENDIF}
end;

begin
  TouchCompatPointerAliases;
  TouchCompatTaggedAliases;
  TouchCompatPascalCaseFacade;
end.
