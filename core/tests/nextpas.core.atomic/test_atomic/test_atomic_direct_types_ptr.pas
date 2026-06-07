unit test_atomic_direct_types_ptr;

{$I nextpas.core.settings.inc}

interface

procedure TestAtomicTypesPtrContract;

implementation

uses
  nextpas.core.testing,
  nextpas.core.atomic,
  nextpas.core.atomic.types;

procedure TestAtomicTypesPtrContract;
type
  TDirectAtomicPtr = specialize TAtomicPtr<Integer>;
  PPInteger = ^PInteger;
var
  LAtomicPtr: TDirectAtomicPtr;
  LExpected: PInteger;
  LMutPtr: PPInteger;
  LValueA: Integer;
  LValueB: Integer;
  LValueC: Integer;
begin
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
  LMutPtr^ := @LValueC;
  Check(LAtomicPtr.IntoInner = @LValueC,
    'direct atomic.types TAtomicPtr.GetMut/IntoInner should expose the exclusive-access pointer');
end;

end.
