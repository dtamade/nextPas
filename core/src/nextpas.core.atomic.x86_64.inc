{
  nextpas.core.atomic.x86_64.inc
  x86_64 atomic operations implementation.

  x86_64 has Total Store Order (TSO):
  - All stores are release stores (visible to other cores in order)
  - All loads are acquire loads (see prior stores from other cores)
  - Only store-load reordering is possible

  Implications:
  - moRelaxed load/store: plain mov (compiler barrier only if needed)
  - moAcquire load: plain mov + compiler barrier after
  - moRelease store: compiler barrier before + plain mov
  - moSeqCst load: plain mov + mfence (or use locked op)
  - moSeqCst store: xchg (implicit lock) or mov + mfence
  - RMW (exchange, CAS, fetch_add): always use LOCK prefix = seq_cst
}

{ Compiler barrier: prevents compiler from reordering across this point }
procedure CompilerBarrier; inline;
begin
  asm
    { empty asm block acts as compiler barrier in FPC }
  end;
end;

{ ============================================================ }
{ Int32 atomics - x86_64                                       }
{ ============================================================ }

function AtomicLoad32(var ATarget: Int32; const AOrder: TMemoryOrder): Int32;
begin
  case AOrder of
    moRelaxed:
      Result := ATarget;
    moAcquire:
    begin
      Result := ATarget;
      CompilerBarrier;
    end;
  else
    { moSeqCst: on x86_64, a plain load is sufficient for acquire semantics
      due to TSO, but seq_cst load needs to prevent store-load reordering.
      Use a locked operation to get full fence. }
    Result := InterlockedExchangeAdd(ATarget, 0);
  end;
end;

procedure AtomicStore32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder);
begin
  case AOrder of
    moRelaxed:
      ATarget := AValue;
    moRelease:
    begin
      CompilerBarrier;
      ATarget := AValue;
    end;
  else
    { moSeqCst: use xchg which has implicit lock prefix }
    InterlockedExchange(ATarget, AValue);
  end;
end;

function AtomicExchange32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := InterlockedExchange(ATarget, AValue);
end;

function AtomicCompareExchange32(var ATarget: Int32; const AExpected, ADesired: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := InterlockedCompareExchange(ATarget, ADesired, AExpected);
end;

function AtomicFetchAdd32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := InterlockedExchangeAdd(ATarget, AValue);
end;

function AtomicFetchSub32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := InterlockedExchangeAdd(ATarget, -AValue);
end;

function AtomicFetchAnd32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
var
  LOld, LNew: Int32;
begin
  repeat
    LOld := ATarget;
    LNew := LOld and AValue;
  until InterlockedCompareExchange(ATarget, LNew, LOld) = LOld;
  Result := LOld;
end;

function AtomicFetchOr32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
var
  LOld, LNew: Int32;
begin
  repeat
    LOld := ATarget;
    LNew := LOld or AValue;
  until InterlockedCompareExchange(ATarget, LNew, LOld) = LOld;
  Result := LOld;
end;

function AtomicFetchXor32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
var
  LOld, LNew: Int32;
begin
  repeat
    LOld := ATarget;
    LNew := LOld xor AValue;
  until InterlockedCompareExchange(ATarget, LNew, LOld) = LOld;
  Result := LOld;
end;

{ ============================================================ }
{ Int64 atomics - x86_64                                       }
{ ============================================================ }

function AtomicLoad64(var ATarget: Int64; const AOrder: TMemoryOrder): Int64;
begin
  case AOrder of
    moRelaxed:
      Result := ATarget;
    moAcquire:
    begin
      Result := ATarget;
      CompilerBarrier;
    end;
  else
    Result := InterlockedExchangeAdd64(ATarget, 0);
  end;
end;

procedure AtomicStore64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder);
begin
  case AOrder of
    moRelaxed:
      ATarget := AValue;
    moRelease:
    begin
      CompilerBarrier;
      ATarget := AValue;
    end;
  else
    InterlockedExchange64(ATarget, AValue);
  end;
end;

function AtomicExchange64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder): Int64;
begin
  Result := InterlockedExchange64(ATarget, AValue);
end;

function AtomicCompareExchange64(var ATarget: Int64; const AExpected, ADesired: Int64; const AOrder: TMemoryOrder): Int64;
begin
  Result := InterlockedCompareExchange64(ATarget, ADesired, AExpected);
end;

function AtomicFetchAdd64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder): Int64;
begin
  Result := InterlockedExchangeAdd64(ATarget, AValue);
end;

function AtomicFetchSub64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder): Int64;
begin
  Result := InterlockedExchangeAdd64(ATarget, -AValue);
end;

{ ============================================================ }
{ Pointer atomics - x86_64 (64-bit pointers)                   }
{ ============================================================ }

function AtomicLoadPtr(var ATarget: Pointer; const AOrder: TMemoryOrder): Pointer;
begin
  case AOrder of
    moRelaxed:
      Result := ATarget;
    moAcquire:
    begin
      Result := ATarget;
      CompilerBarrier;
    end;
  else
    Result := Pointer(InterlockedExchangeAdd64(Int64(ATarget), 0));
  end;
end;

procedure AtomicStorePtr(var ATarget: Pointer; const AValue: Pointer; const AOrder: TMemoryOrder);
begin
  case AOrder of
    moRelaxed:
      ATarget := AValue;
    moRelease:
    begin
      CompilerBarrier;
      ATarget := AValue;
    end;
  else
    InterlockedExchange64(Int64(ATarget), Int64(AValue));
  end;
end;

function AtomicExchangePtr(var ATarget: Pointer; const AValue: Pointer; const AOrder: TMemoryOrder): Pointer;
begin
  Result := Pointer(InterlockedExchange64(Int64(ATarget), Int64(AValue)));
end;

function AtomicCompareExchangePtr(var ATarget: Pointer; const AExpected, ADesired: Pointer; const AOrder: TMemoryOrder): Pointer;
begin
  Result := Pointer(InterlockedCompareExchange64(Int64(ATarget), Int64(ADesired), Int64(AExpected)));
end;

{ ============================================================ }
{ Fences - x86_64                                              }
{ ============================================================ }

procedure AtomicThreadFence(const AOrder: TMemoryOrder);
begin
  case AOrder of
    moRelaxed:
      { no-op };
    moAcquire, moRelease, moAcqRel:
      CompilerBarrier;
    moSeqCst:
      asm
        mfence
      end;
  end;
end;

procedure AtomicSignalFence(const AOrder: TMemoryOrder);
begin
  if AOrder <> moRelaxed then
    CompilerBarrier;
end;

procedure CpuPause;
begin
  asm
    pause
  end;
end;
