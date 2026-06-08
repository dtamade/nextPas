unit test_atomic_direct_types_ptr;

{$I nextpas.core.settings.inc}

interface

procedure TestAtomicTypesPtrContract;

implementation

uses
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.atomic,
  nextpas.core.atomic.types;

procedure TestAtomicTypesPtrContract;
type
  TDirectAtomicPtr = specialize TAtomicPtr<Integer>;
  TDirectPtrHolder = record
    Prefix: Byte;
    Value: TDirectAtomicPtr;
  end;
  PPInteger = ^PInteger;
var
  LAtomicPtr: TDirectAtomicPtr;
  LExpected: PInteger;
  LMutPtr: PPInteger;
  LValueA: Integer;
  LValueB: Integer;
  LValueC: Integer;
  LHolder: TDirectPtrHolder;
  LInvalidOrder: memory_order_t;
  LRaised: Boolean;
begin
  Check(SizeOf(TDirectAtomicPtr) = SizeOf(Pointer),
    'direct atomic.types TAtomicPtr storage must be exactly one pointer');
  Check((PtrUInt(@LAtomicPtr) mod SizeOf(Pointer)) = 0,
    'direct atomic.types TAtomicPtr local storage must be naturally aligned');
  Check((PtrUInt(@LHolder.Value) mod SizeOf(Pointer)) = 0,
    'direct atomic.types TAtomicPtr embedded field must preserve natural alignment');
  Check(((PtrUInt(@LHolder.Value) - PtrUInt(@LHolder)) mod SizeOf(Pointer)) = 0,
    'direct atomic.types TAtomicPtr embedded field offset must preserve natural alignment');

  Check(TDirectAtomicPtr.is_lock_free = nextpas.core.atomic.atomic_is_lock_free_ptr,
    'direct atomic.types TAtomicPtr lock-free surface must match pointer-sized runtime truth');

  LValueA := 10;
  LValueB := 20;
  LValueC := 30;
  LAtomicPtr := TDirectAtomicPtr.Create(@LValueA);
  Check(LAtomicPtr.Load(mo_relaxed) = @LValueA,
    'direct atomic.types TAtomicPtr.Create should publish the initial pointer');

  LAtomicPtr.Store(@LValueB, mo_release);
  Check(LAtomicPtr.Load(mo_acquire) = @LValueB,
    'direct atomic.types TAtomicPtr.Store should publish the replacement pointer');

  Check(LAtomicPtr.Exchange(@LValueC, mo_acq_rel) = @LValueB,
    'direct atomic.types TAtomicPtr.Exchange should return the previous pointer');
  Check(LAtomicPtr.Load = @LValueC,
    'direct atomic.types TAtomicPtr default Load should observe the exchanged pointer');

  LInvalidOrder := memory_order_t(Ord(mo_seq_cst) + 1);
  LRaised := False;
  try
    LAtomicPtr.Exchange(@LValueA, LInvalidOrder);
    Check(False, 'direct atomic.types TAtomicPtr.Exchange invalid ordinal must raise EArgumentError');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised,
    'direct atomic.types TAtomicPtr.Exchange invalid ordinal should be rejected');
  Check(LAtomicPtr.Load(mo_acquire) = @LValueC,
    'direct atomic.types TAtomicPtr.Exchange invalid ordinal must not mutate storage');

  LExpected := @LValueA;
  Check(not LAtomicPtr.CompareExchangeStrong(LExpected, @LValueB, mo_consume),
    'direct atomic.types TAtomicPtr consume CAS should remain legal on mismatch');
  Check(LExpected = @LValueC,
    'direct atomic.types TAtomicPtr consume CAS mismatch should write the observed pointer');

  Check(LAtomicPtr.CompareExchangeStrong(LExpected, @LValueB, mo_consume),
    'direct atomic.types TAtomicPtr consume CAS should update when expected matches');
  Check(LAtomicPtr.Load(mo_acquire) = @LValueB,
    'direct atomic.types TAtomicPtr consume CAS should publish the replacement pointer');

  LExpected := @LValueB;
  Check(LAtomicPtr.CompareExchangeWeak(LExpected, @LValueA, mo_acq_rel),
    'direct atomic.types TAtomicPtr weak CAS should update when expected matches');
  Check(LAtomicPtr.Load(mo_acquire) = @LValueA,
    'direct atomic.types TAtomicPtr weak CAS should publish the replacement pointer');

  LExpected := @LValueB;
  Check(not LAtomicPtr.CompareExchangeWeak(LExpected, @LValueC, mo_acq_rel),
    'direct atomic.types TAtomicPtr weak CAS should remain legal on mismatch');
  Check(LExpected = @LValueA,
    'direct atomic.types TAtomicPtr weak CAS mismatch should write the observed pointer');

  LMutPtr := PPInteger(LAtomicPtr.GetMut);
  Check(PtrUInt(LMutPtr) = PtrUInt(@LAtomicPtr),
    'direct atomic.types TAtomicPtr GetMut must expose the first backing storage slot');
  LMutPtr^ := @LValueC;
  Check(LAtomicPtr.IntoInner = @LValueC,
    'direct atomic.types TAtomicPtr.GetMut/IntoInner should expose the exclusive-access pointer');
end;

end.
