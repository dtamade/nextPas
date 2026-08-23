unit nextpas.core.atomic.core;

{$I nextpas.core.settings.inc}
{$MACRO ON}

// Tagged pointer: tag bits (low-bit tagging mode)
{$IFNDEF NEXTPAS_ATOMIC_TAG_BITS_32}
  {$DEFINE NEXTPAS_ATOMIC_TAG_BITS_32 := 2}
{$ENDIF}
{$IFNDEF NEXTPAS_ATOMIC_TAG_BITS_64}
  {$DEFINE NEXTPAS_ATOMIC_TAG_BITS_64 := 3}
{$ENDIF}

// Enable extra runtime checks for tagged pointer packing (debug only)
{$IFDEF DEBUG}
  {$DEFINE NEXTPAS_ATOMIC_TAGGED_PTR_CHECKS}
{$ENDIF}

interface

uses
  nextpas.core.errors;

type
  memory_order_t = (
    mo_relaxed,
    mo_consume,
    mo_acquire,
    mo_release,
    mo_acq_rel,
    mo_seq_cst
  );

procedure cpu_pause;
procedure cpu_prefetch_nta(const aAddr: Pointer); inline;
procedure atomic_seq_cst_fence;
procedure atomic_thread_fence(aOrder: memory_order_t);
procedure atomic_signal_fence(aOrder: memory_order_t);

{ ── Backend seam (F-002) ────────────────────────────────────────────────
  The ONLY sanctioned home for host-compiler atomic primitives (FPC System
  `Interlocked*` intrinsics and Read/Write barriers).  atomic/lockfree
  production units must call this seam instead of the FPC RTL, so a future
  nextpas compiler backend (LLVM atomics / asm) only replaces this surface.

  Contract:
  - RMW seam functions are atomic read-modify-write ops returning the
    PREVIOUS (observed) value.  cmpxchg argument order is
    (target, desired, expected) — mirrors the FPC host intrinsic.
  - Ordering: on the x86/x86_64 host every RMW is a full fence; on
    weakly-ordered hosts only the host RTL's Interlocked semantics are
    guaranteed — memory_order policy (extra fences) stays in the caller
    (see nextpas.core.atomic).
  - Barrier seam procedures map 1:1 to host compiler/hardware barriers.
  - Not a consumer API: use atomic_* / TAtomic* instead. }

function _backend_cmpxchg_i32(var aTarget: Int32; aDesired, aExpected: Int32): Int32; inline;
function _backend_xchg_i32(var aTarget: Int32; aValue: Int32): Int32; inline;
function _backend_xadd_i32(var aTarget: Int32; aValue: Int32): Int32; inline;
{$IFDEF CPU64}
function _backend_cmpxchg_i64(var aTarget: Int64; aDesired, aExpected: Int64): Int64; inline;
function _backend_xchg_i64(var aTarget: Int64; aValue: Int64): Int64; inline;
function _backend_xadd_i64(var aTarget: Int64; aValue: Int64): Int64; inline;
{$ENDIF}
{$IF DEFINED(CPUARM)}
function _backend_xchg_i64(var aTarget: Int64; aValue: Int64): Int64; inline;
{$ENDIF}
procedure _backend_read_barrier; inline;
procedure _backend_write_barrier; inline;
procedure _backend_full_barrier; inline;

{ Weak CAS seam — a single LL/SC attempt on weakly-ordered hosts; may fail
  spuriously.  Returns True on success; on failure aExpected is updated to
  the observed value.  Argument order (target, expected, desired) differs
  from the strong seam because aExpected is in-out.  Only defined where the
  host has a native LL/SC weak CAS: x86 callers use the strong seam instead
  (LOCK CMPXCHG has no weak variant).  Ordering: raw LL/SC without fences —
  memory_order policy stays in the caller. }
{$IF DEFINED(CPUAARCH64) OR DEFINED(CPURISCV64)}
function _backend_cmpxchg_weak_i32(var aObj: Int32; var aExpected: Int32; aDesired: Int32): Boolean;
function _backend_cmpxchg_weak_i64(var aObj: Int64; var aExpected: Int64; aDesired: Int64): Boolean;
{$ELSEIF DEFINED(CPUARM)}
function _backend_cmpxchg_weak_i32(var aObj: Int32; var aExpected: Int32; aDesired: Int32): Boolean;
{$ENDIF}

{ Lightweight acquire/release barrier: on x86 (TSO) a compiler-only barrier,
  on weakly-ordered hosts a hardware read barrier. }
{$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
procedure _backend_compiler_barrier;
{$ELSE}
procedure _backend_compiler_barrier; inline;
{$ENDIF}

type
  atomic_tagged_ptr_t = type PtrUInt;

function atomic_tagged_ptr(aPtr: Pointer; aTag: {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF}): atomic_tagged_ptr_t; inline;
function atomic_tagged_ptr_get_ptr(const aTaggedPtr: atomic_tagged_ptr_t): Pointer; inline;
function atomic_tagged_ptr_get_tag(const aTaggedPtr: atomic_tagged_ptr_t): {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF}; inline;
function atomic_tagged_ptr_next(const aTaggedPtr: atomic_tagged_ptr_t): {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF}; inline;

{ Shared arithmetic helpers — used by both atomic.types and atomic.pas }

function _cas_success_order(const AOrder: memory_order_t): memory_order_t; inline;
function _cas_failure_order(const ASuccessOrder: memory_order_t): memory_order_t; inline;

function _uint32_inc_result(const AOld: UInt32): UInt32; inline;
function _uint32_dec_result(const AOld: UInt32): UInt32; inline;
function _uint64_inc_result(const AOld: UInt64): UInt64; inline;
function _uint64_dec_result(const AOld: UInt64): UInt64; inline;
function _ptruint_inc_result(const AOld: PtrUInt): PtrUInt; inline;
function _ptruint_dec_result(const AOld: PtrUInt): PtrUInt; inline;

function _int32_from_bits(const AValue: UInt32): Int32; inline;
function _int32_to_bits(const AValue: Int32): UInt32; inline;
function _int64_from_bits(const AValue: UInt64): Int64; inline;
function _int64_to_bits(const AValue: Int64): UInt64; inline;
function _ptrint_from_bits(const AValue: PtrUInt): PtrInt; inline;
function _ptrint_to_bits(const AValue: PtrInt): PtrUInt; inline;

function _int32_inc_result(const AOld: Int32): Int32; inline;
function _int32_dec_result(const AOld: Int32): Int32; inline;
function _int64_inc_result(const AOld: Int64): Int64; inline;
function _int64_dec_result(const AOld: Int64): Int64; inline;
function _ptrint_inc_result(const AOld: PtrInt): PtrInt; inline;
function _ptrint_dec_result(const AOld: PtrInt): PtrInt; inline;

function _uint32_neg_delta(const AValue: UInt32): UInt32; inline;
function _uint64_neg_delta(const AValue: UInt64): UInt64; inline;
function _ptruint_neg_delta(const AValue: PtrUInt): PtrUInt; inline;
function _int32_neg_delta(const AValue: Int32): Int32; inline;
function _int64_neg_delta(const AValue: Int64): Int64; inline;
function _ptrint_neg_delta(const AValue: PtrInt): PtrInt; inline;

function _int64_wrapping_add(const ALeft, ARight: Int64): Int64; inline;

implementation

{$IF DEFINED(CPUX86_64)}
const
  TAG_BITS = 16;
  TAG_SHIFT = (SizeOf(PtrUInt) * 8) - TAG_BITS;
  PTR_MASK: PtrUInt = (PtrUInt(1) shl TAG_SHIFT) - 1;
{$ELSE}
const
  {$IFDEF CPU64}
  TAG_BITS = NEXTPAS_ATOMIC_TAG_BITS_64;
  {$ELSE}
  TAG_BITS = NEXTPAS_ATOMIC_TAG_BITS_32;
  {$ENDIF}
  TAG_MASK: PtrUInt = (PtrUInt(1) shl TAG_BITS) - 1;
  PTR_MASK: PtrUInt = ((not PtrUInt(0)) shr TAG_BITS) shl TAG_BITS;
{$ENDIF}

{$IF DEFINED(CPUX86_64)}
const
  MAX_TAG: UInt16 = $FFFF;
{$ELSEIF DEFINED(CPU64)}
const
  MAX_TAG: UInt16 = UInt16((PtrUInt(1) shl TAG_BITS) - 1);
{$ELSE}
const
  MAX_TAG: UInt32 = UInt32((PtrUInt(1) shl TAG_BITS) - 1);
{$ENDIF}

{$IF DEFINED(CPUX86_64)}
function _x86_64_pointer_to_low48(const aPtr: Pointer): PtrUInt; inline;
var
  LValue: PtrUInt;
  LLow48: PtrUInt;
  LCanonical: PtrUInt;
  LSignBit: PtrUInt;
  LHighMask: PtrUInt;
begin
  LValue := PtrUInt(aPtr);
  LLow48 := LValue and PTR_MASK;
  LSignBit := PtrUInt(1) shl (TAG_SHIFT - 1);
  LHighMask := not PTR_MASK;
  if (LLow48 and LSignBit) <> 0 then
    LCanonical := LLow48 or LHighMask
  else
    LCanonical := LLow48;

  if LCanonical <> LValue then
    raise EArgumentError.Create('atomic_tagged_ptr: pointer out of range for x86_64 packing');

  Result := LLow48;
end;

function _x86_64_low48_to_pointer(const aValue: PtrUInt): Pointer; inline;
var
  LCanonical: PtrUInt;
  LSignBit: PtrUInt;
  LHighMask: PtrUInt;
begin
  LSignBit := PtrUInt(1) shl (TAG_SHIFT - 1);
  LHighMask := not PTR_MASK;
  if (aValue and LSignBit) <> 0 then
    LCanonical := aValue or LHighMask
  else
    LCanonical := aValue and PTR_MASK;
  Result := Pointer(LCanonical);
end;
{$ENDIF}

{$IF DEFINED(CPUPPC) OR DEFINED(CPUPPC64)}
procedure atomic_seq_cst_fence; assembler; nostackframe;
asm
  sync
end;
{$ELSEIF DEFINED(CPUAARCH64)}
procedure atomic_seq_cst_fence; assembler; nostackframe;
asm
  dmb #11  // dmb ish — full inner-shareable barrier
end;
{$ELSEIF DEFINED(CPUARM)}
procedure atomic_seq_cst_fence; assembler; nostackframe;
asm
  .long 0xf57ff05b  // dmb ish — inner-shareable barrier (ARM32 encoding)
end;
{$ELSEIF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
procedure atomic_seq_cst_fence; assembler; nostackframe;
asm
  fence rw, rw
end;
{$ELSE}
procedure atomic_seq_cst_fence;
begin
  ReadWriteBarrier;
end;
{$ENDIF}

procedure cpu_pause;
begin
  {$IF DEFINED(CPUX86_64)}
    asm
      pause
    end;
  {$ELSEIF DEFINED(CPUX86)}
    asm
      pause
    end;
  {$ELSEIF DEFINED(CPUAARCH64)}
    asm
      yield
    end;
  {$ELSEIF DEFINED(CPUARM)}
    asm
      .long 0xe320f001  // yield (ARM32 encoding: NOP-like hint)
    end;
  {$ELSEIF DEFINED(CPURISCV64)}
    asm
      nop
    end;
  {$ELSEIF DEFINED(CPURISCV32)}
    asm
      nop
    end;
  {$ELSE}
  {$ENDIF}
end;

// Non-temporal prefetch hint.  The FPC Prefetch intrinsic emits PREFETCHNTA
// on x86 targets and degrades to a no-op where the backend has no prefetch
// support; prefetch never faults, so any address (including nil) is safe.
// Being an intrinsic (not an asm statement) it stays inlinable, unlike the
// former hand-written asm block this replaces.
procedure cpu_prefetch_nta(const aAddr: Pointer); inline;
begin
  Prefetch(PByte(aAddr)^);
end;

// FPC does not expose a dedicated compiler-fence intrinsic here, so use an
// empty assembler procedure as a compiler-only barrier for signal fences.
procedure _compiler_signal_fence; assembler; nostackframe;
asm
end;

procedure AtomicValidateFenceOrder(const AOrder: memory_order_t);
begin
  case Ord(AOrder) of
    Ord(mo_relaxed), Ord(mo_consume), Ord(mo_acquire),
    Ord(mo_release), Ord(mo_acq_rel), Ord(mo_seq_cst):
      ;
  else
    raise EArgumentError.Create('atomic_fence: invalid memory order');
  end;
end;

procedure atomic_thread_fence(aOrder: memory_order_t);
begin
  AtomicValidateFenceOrder(aOrder);
  case aOrder of
    mo_relaxed:;
    mo_consume: ReadBarrier;
    mo_acquire: ReadBarrier;
    mo_release: WriteBarrier;
    mo_acq_rel: ReadWriteBarrier;
    mo_seq_cst: atomic_seq_cst_fence;
  end;
end;

procedure atomic_signal_fence(aOrder: memory_order_t);
begin
  AtomicValidateFenceOrder(aOrder);
  case aOrder of
    mo_relaxed:;
    mo_consume,
    mo_acquire,
    mo_release,
    mo_acq_rel,
    mo_seq_cst:
      _compiler_signal_fence;
  end;
end;

function atomic_tagged_ptr(aPtr: Pointer; aTag: {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF}): atomic_tagged_ptr_t;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF DEFINED(CPUX86_64)}
    {$IFDEF NEXTPAS_ATOMIC_TAGGED_PTR_CHECKS}
      _x86_64_pointer_to_low48(aPtr);
    {$ENDIF}
  {$ELSE}
    if (PtrUInt(aPtr) and TAG_MASK) <> 0 then
      raise EArgumentError.Create('atomic_tagged_ptr: pointer not aligned for low-bit tag packing');
    if (PtrUInt(aTag) and (not TAG_MASK)) <> 0 then
      raise EArgumentError.Create('atomic_tagged_ptr: tag does not fit TAG_BITS');
    {$IFDEF NEXTPAS_ATOMIC_TAGGED_PTR_CHECKS}
      Assert((PtrUInt(aPtr) and TAG_MASK) = 0, 'atomic_tagged_ptr: pointer not aligned for low-bit tag packing');
      Assert((PtrUInt(aTag) and (not TAG_MASK)) = 0, 'atomic_tagged_ptr: tag does not fit TAG_BITS');
    {$ENDIF}
  {$ENDIF}

  {$IF DEFINED(CPUX86_64)}
  Result := _x86_64_pointer_to_low48(aPtr) or (PtrUInt(aTag) shl TAG_SHIFT);
  {$ELSE}
  Result := (PtrUInt(aPtr) and PTR_MASK) or (PtrUInt(aTag) and TAG_MASK);
  {$ENDIF}
  {$POP}
end;

function atomic_tagged_ptr_get_ptr(const aTaggedPtr: atomic_tagged_ptr_t): Pointer;
begin
  {$PUSH}
  {$WARN 4055 OFF}
  {$IF DEFINED(CPUX86_64)}
  Result := _x86_64_low48_to_pointer(PtrUInt(aTaggedPtr) and PTR_MASK);
  {$ELSE}
  Result := Pointer(PtrUInt(aTaggedPtr) and PTR_MASK);
  {$ENDIF}
  {$POP}
end;

function atomic_tagged_ptr_get_tag(const aTaggedPtr: atomic_tagged_ptr_t): {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF};
begin
  {$IF DEFINED(CPUX86_64)}
  Result := UInt16(PtrUInt(aTaggedPtr) shr TAG_SHIFT);
  {$ELSEIF DEFINED(CPU64)}
  Result := UInt16(PtrUInt(aTaggedPtr) and TAG_MASK);
  {$ELSE}
  Result := UInt32(PtrUInt(aTaggedPtr) and TAG_MASK);
  {$ENDIF}
end;

function atomic_tagged_ptr_next(const aTaggedPtr: atomic_tagged_ptr_t): {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF};
var
  LTag: {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF};
begin
  LTag := atomic_tagged_ptr_get_tag(aTaggedPtr);
  if LTag = MAX_TAG then
    Result := 0
  else
    Result := LTag + 1;
end;

{ Shared arithmetic helpers }

function _cas_success_order(const AOrder: memory_order_t): memory_order_t; inline;
begin
  if AOrder = mo_consume then
    Result := mo_acquire
  else
    Result := AOrder;
end;

function _cas_failure_order(const ASuccessOrder: memory_order_t): memory_order_t; inline;
begin
  if ASuccessOrder = mo_relaxed then
    Result := mo_relaxed
  else if (ASuccessOrder = mo_consume) or (ASuccessOrder = mo_acquire) then
    Result := mo_acquire
  else if ASuccessOrder = mo_release then
    Result := mo_relaxed
  else if ASuccessOrder = mo_acq_rel then
    Result := mo_acquire
  else
    Result := mo_seq_cst;
end;

function _uint32_inc_result(const AOld: UInt32): UInt32; inline;
begin
  if AOld = High(UInt32) then
    Result := UInt32(0)
  else
    Result := AOld + UInt32(1);
end;

function _uint32_dec_result(const AOld: UInt32): UInt32; inline;
begin
  if AOld = UInt32(0) then
    Result := High(UInt32)
  else
    Result := AOld - UInt32(1);
end;

function _uint64_inc_result(const AOld: UInt64): UInt64; inline;
begin
  if AOld = High(UInt64) then
    Result := UInt64(0)
  else
    Result := AOld + UInt64(1);
end;

function _uint64_dec_result(const AOld: UInt64): UInt64; inline;
begin
  if AOld = UInt64(0) then
    Result := High(UInt64)
  else
    Result := AOld - UInt64(1);
end;

function _ptruint_inc_result(const AOld: PtrUInt): PtrUInt; inline;
begin
  if AOld = High(PtrUInt) then
    Result := PtrUInt(0)
  else
    Result := AOld + PtrUInt(1);
end;

function _ptruint_dec_result(const AOld: PtrUInt): PtrUInt; inline;
begin
  if AOld = PtrUInt(0) then
    Result := High(PtrUInt)
  else
    Result := AOld - PtrUInt(1);
end;

function _int32_from_bits(const AValue: UInt32): Int32; inline;
var
  LBits: UInt32;
begin
  LBits := AValue;
  Result := PInt32(@LBits)^;
end;

function _int32_to_bits(const AValue: Int32): UInt32; inline;
var
  LValue: Int32;
begin
  LValue := AValue;
  Result := PUInt32(@LValue)^;
end;

function _int64_from_bits(const AValue: UInt64): Int64; inline;
var
  LBits: UInt64;
begin
  LBits := AValue;
  Result := PInt64(@LBits)^;
end;

function _int64_to_bits(const AValue: Int64): UInt64; inline;
var
  LValue: Int64;
begin
  LValue := AValue;
  Result := PUInt64(@LValue)^;
end;

function _ptrint_from_bits(const AValue: PtrUInt): PtrInt; inline;
var
  LBits: PtrUInt;
begin
  LBits := AValue;
  Result := PPtrInt(@LBits)^;
end;

function _ptrint_to_bits(const AValue: PtrInt): PtrUInt; inline;
var
  LValue: PtrInt;
begin
  LValue := AValue;
  Result := PPtrUInt(@LValue)^;
end;

function _int32_inc_result(const AOld: Int32): Int32; inline;
begin
  Result := _int32_from_bits(_uint32_inc_result(_int32_to_bits(AOld)));
end;

function _int32_dec_result(const AOld: Int32): Int32; inline;
begin
  Result := _int32_from_bits(_uint32_dec_result(_int32_to_bits(AOld)));
end;

function _int64_inc_result(const AOld: Int64): Int64; inline;
begin
  Result := _int64_from_bits(_uint64_inc_result(_int64_to_bits(AOld)));
end;

function _int64_dec_result(const AOld: Int64): Int64; inline;
begin
  Result := _int64_from_bits(_uint64_dec_result(_int64_to_bits(AOld)));
end;

function _ptrint_inc_result(const AOld: PtrInt): PtrInt; inline;
begin
  Result := _ptrint_from_bits(_ptruint_inc_result(_ptrint_to_bits(AOld)));
end;

function _ptrint_dec_result(const AOld: PtrInt): PtrInt; inline;
begin
  Result := _ptrint_from_bits(_ptruint_dec_result(_ptrint_to_bits(AOld)));
end;

function _uint32_neg_delta(const AValue: UInt32): UInt32; inline;
begin
  if AValue = UInt32(0) then
    Result := UInt32(0)
  else
    Result := UInt32(not AValue) + UInt32(1);
end;

function _uint64_neg_delta(const AValue: UInt64): UInt64; inline;
begin
  if AValue = UInt64(0) then
    Result := UInt64(0)
  else
    Result := UInt64(not AValue) + UInt64(1);
end;

function _ptruint_neg_delta(const AValue: PtrUInt): PtrUInt; inline;
begin
  if AValue = PtrUInt(0) then
    Result := PtrUInt(0)
  else
    Result := PtrUInt(not AValue) + PtrUInt(1);
end;

function _int32_neg_delta(const AValue: Int32): Int32; inline;
begin
  Result := _int32_from_bits(_uint32_neg_delta(_int32_to_bits(AValue)));
end;

function _int64_neg_delta(const AValue: Int64): Int64; inline;
begin
  Result := _int64_from_bits(_uint64_neg_delta(_int64_to_bits(AValue)));
end;

function _ptrint_neg_delta(const AValue: PtrInt): PtrInt; inline;
begin
  Result := _ptrint_from_bits(_ptruint_neg_delta(_ptrint_to_bits(AValue)));
end;

function _int64_wrapping_add(const ALeft, ARight: Int64): Int64; inline;
var
  LLeftBits: UInt64;
  LRightBits: UInt64;
  LLowSum: UInt64;
  LHighSum: UInt64;
  LResultBits: UInt64;
begin
  LLeftBits := PUInt64(@ALeft)^;
  LRightBits := PUInt64(@ARight)^;
  LLowSum := UInt64(UInt32(LLeftBits)) + UInt64(UInt32(LRightBits));
  LHighSum := UInt64(UInt32(LLeftBits shr 32)) +
    UInt64(UInt32(LRightBits shr 32)) + (LLowSum shr 32);
  LResultBits := ((LHighSum and UInt64($FFFFFFFF)) shl 32) or
    (LLowSum and UInt64($FFFFFFFF));
  Result := PInt64(@LResultBits)^;
end;

{ Backend seam (F-002) — FPC host backend.
  A nextpas compiler backend replaces the bodies below (LLVM atomics / asm)
  while keeping the seam signatures and the previous-value contract. }

function _backend_cmpxchg_i32(var aTarget: Int32; aDesired, aExpected: Int32): Int32; inline;
begin
  Result := InterlockedCompareExchange(aTarget, aDesired, aExpected);
end;

function _backend_xchg_i32(var aTarget: Int32; aValue: Int32): Int32; inline;
begin
  Result := InterlockedExchange(aTarget, aValue);
end;

function _backend_xadd_i32(var aTarget: Int32; aValue: Int32): Int32; inline;
begin
  Result := InterlockedExchangeAdd(aTarget, aValue);
end;

{$IFDEF CPU64}
function _backend_cmpxchg_i64(var aTarget: Int64; aDesired, aExpected: Int64): Int64; inline;
begin
  Result := InterlockedCompareExchange64(aTarget, aDesired, aExpected);
end;

function _backend_xchg_i64(var aTarget: Int64; aValue: Int64): Int64; inline;
begin
  Result := InterlockedExchange64(aTarget, aValue);
end;

function _backend_xadd_i64(var aTarget: Int64; aValue: Int64): Int64; inline;
begin
  Result := InterlockedExchangeAdd64(aTarget, aValue);
end;
{$ENDIF}

{$IF DEFINED(CPUARM)}
// arm32 无 64 位原生交换：LDREXD/STREXD 独占环构造 xchg（返回旧值）。
// AAPCS：r0=@aTarget，aValue 低字在 r2、高字在 r3；返回值低字 r0、高字 r1。
function _backend_xchg_i64(var aTarget: Int64; aValue: Int64): Int64; assembler; nostackframe;
asm
.Larmxchg64_loop:
  ldrexd  r4, r5, [r0]
  strexd  r6, r2, r3, [r0]
  cmp     r6, #0
  bne     .Larmxchg64_loop
  mov     r0, r4
  mov     r1, r5
end;
{$ENDIF}

procedure _backend_read_barrier; inline;
begin
  ReadBarrier;
end;

procedure _backend_write_barrier; inline;
begin
  WriteBarrier;
end;

procedure _backend_full_barrier; inline;
begin
  ReadWriteBarrier;
end;

{ Weak CAS seam — single LL/SC attempt, no retry loop.  Moved verbatim from
  nextpas.core.atomic (F-002 seam completion); a nextpas backend replaces
  these bodies together with the rest of the seam. }

{$IF DEFINED(CPUAARCH64)}
function _backend_cmpxchg_weak_i32(var aObj: Int32; var aExpected: Int32; aDesired: Int32): Boolean; assembler; nostackframe;
asm
  // x0 = @aObj, x1 = @aExpected, w2 = aDesired
  ldaxr  w3,[x0]          // Load-Exclusive with acquire
  ldr    w4,[x1]          // Load expected
  subs   w6,w3,w4         // Compare (sets flags)
  cbnz   w6,.Lweak32_fail // Branch if not equal
  stlxr  w5,w2,[x0]       // Store-Conditional with release (single attempt)
  cbnz   w5,.Lweak32_fail
  mov    w0,#1            // Success
  ret
.Lweak32_fail:
  str    w3,[x1]          // Update expected to actual value
  mov    w0,#0            // Failure
  ret
end;

function _backend_cmpxchg_weak_i64(var aObj: Int64; var aExpected: Int64; aDesired: Int64): Boolean; assembler; nostackframe;
asm
  // x0 = @aObj, x1 = @aExpected, x2 = aDesired
  ldaxr  x3,[x0]          // Load-Exclusive with acquire
  ldr    x4,[x1]          // Load expected
  subs   x6,x3,x4         // Compare (sets flags)
  cbnz   x6,.Lweak64_fail // Branch if not equal
  stlxr  w5,x2,[x0]       // Store-Conditional with release (single attempt)
  cbnz   w5,.Lweak64_fail
  mov    w0,#1            // Success
  ret
.Lweak64_fail:
  str    x3,[x1]          // Update expected to actual value
  mov    w0,#0            // Failure
  ret
end;

{$ELSEIF DEFINED(CPUARM)}
function _backend_cmpxchg_weak_i32(var aObj: Int32; var aExpected: Int32; aDesired: Int32): Boolean; assembler; nostackframe;
asm
  // r0 = @aObj, r1 = @aExpected, r2 = aDesired
  ldrex  r3,[r0]          // Load-Exclusive
  ldr    r4,[r1]          // Load expected
  cmp    r3,r4            // Compare
  bne    .Lweak32_arm_fail
  strex  r5,r2,[r0]       // Store-Conditional (single attempt)
  cmp    r5,#0
  bne    .Lweak32_arm_fail
  mov    r0,#1            // Success
  bx     lr
.Lweak32_arm_fail:
  str    r3,[r1]          // Update expected to actual value
  mov    r0,#0            // Failure
  bx     lr
end;

{$ELSEIF DEFINED(CPURISCV64)}
function _backend_cmpxchg_weak_i32(var aObj: Int32; var aExpected: Int32; aDesired: Int32): Boolean; assembler; nostackframe;
asm
  // a0 = @aObj, a1 = @aExpected, a2 = aDesired
  lr.w    a3, 0(a0)       // Load-Reserved
  lw      a4, 0(a1)       // Load expected
  bne     a3, a4, .Lweak32_rv_fail
  sc.w    a4, a2, 0(a0)   // Store-Conditional (single attempt)
  bne     a4, x0, .Lweak32_rv_fail
  addi    a0, x0, 1       // Success
  ret
.Lweak32_rv_fail:
  sw      a3, 0(a1)       // Update expected to actual value
  addi    a0, x0, 0       // Failure
  ret
end;

function _backend_cmpxchg_weak_i64(var aObj: Int64; var aExpected: Int64; aDesired: Int64): Boolean; assembler; nostackframe;
asm
  // a0 = @aObj, a1 = @aExpected, a2 = aDesired
  lr.d    a3, 0(a0)       // Load-Reserved
  ld      a4, 0(a1)       // Load expected
  bne     a3, a4, .Lweak64_rv_fail
  sc.d    a4, a2, 0(a0)   // Store-Conditional (single attempt)
  bne     a4, x0, .Lweak64_rv_fail
  addi    a0, x0, 1       // Success
  ret
.Lweak64_rv_fail:
  sd      a3, 0(a1)       // Update expected to actual value
  addi    a0, x0, 0       // Failure
  ret
end;
{$ENDIF}

{$IF DEFINED(CPUX86_64) OR DEFINED(CPUX86)}
procedure _backend_compiler_barrier; assembler; nostackframe;
asm
end;
{$ELSE}
procedure _backend_compiler_barrier; inline;
begin
  ReadBarrier;
end;
{$ENDIF}

end.
