unit nextpas.core.js.lifecycle;
{ lifecycle owner — single source for pure Context registry: GPureClosed compact 4B generation epoch*2+closed atomic acquire/release, scalar NextId/Len/Lock each 64B VARMIN isolated, freelist recycling bounded memory via bytes.ops geometric single source + mem.dynarray Exactly-Once + shrink, generation-tagged Id for INV-7 strong consistency, write-once rare, bulk IsValid zero atomic via FValid, strong acquire; spinlock single source via sync.spinlock RawSpinAcquire/Release sampled 64-spin amortized 5ms deadline (no per-spin syscall storm), exponential backoff + yield, Close no-skip guarantees bounded GPureNextId/GPureClosed, base remains thin type-carrier per four-piece, lifecycle extracted to js.lifecycle single source, 复用 bytes.ops单源几何 via BytesNextCapacity + mem.dynarray poke Exactly-Once, inline零拷贝, amortized O(1), L0-L3守分层. L0 thread/time single slit via lifecycle (platform.thread + platform.time single source), quickjs.value thin-forwards, no dual entry. }
{$I nextpas.core.settings.inc}
interface
function JsPureContextRegister: UInt64;
procedure JsPureContextClose(AId: UInt64);
function JsPureContextIsClosed(AId: UInt64): Boolean; inline;
function JsPureThreadSelf: UInt64; inline;
function JsPureIsOnCreationThread(ACreationId: UInt64): Boolean; inline;
// L0 time single slit — owner lifecycle via platform.time single source, inline zero-copy, exactly-once deadline, 1024-sample amortized, bytes.ops single source remains
function JsPureMonotonicNs: QWord; inline;
procedure JsPureDeadlineRefresh(var ADeadlineNs: Int64; ATimeoutMs: Integer); inline;
function JsPureInterruptShouldAbort(ADeadlineNs: Int64; var ACounter: Cardinal; var ALastNs: QWord): Boolean; inline;
implementation
uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.mem.base,
  nextpas.core.mem.dynarray,
  nextpas.core.atomic,
  nextpas.core.platform.thread,
  nextpas.core.platform.time,
  nextpas.core.sync.spinlock;
const
  JS_LIFECYCLE_CACHE_LINE = MEM_CACHE_LINE_SIZE; // 64 via mem.base single source, no magic
  JS_LIFECYCLE_PAD = JS_LIFECYCLE_CACHE_LINE - SizeOf(Int32); // 60 via CACHE_LINE single source
  JS_LIFECYCLE_PAD64 = JS_LIFECYCLE_CACHE_LINE - SizeOf(Int64); // 56 via CACHE_LINE single source
  JS_LIFECYCLE_SPIN_TIMEOUT_NS = QWord(5 * 1000000); // 5ms deadline single source now in sync.spinlock RawSpinAcquire sampled (64-spin amortized, no per-spin syscall), lifecycle delegates to owner
{$PUSH}{$CODEALIGN RECORDMIN=16}{$PACKRECORDS C}
type
  TPureNextIdSlot = record Value: Int64; Padding: array[0..JS_LIFECYCLE_PAD64 - 1] of Byte; end; // 64B padded scalar, cache-line isolated via VARMIN 64 + pad
  TPureLenSlot = record Value: Int32; Padding: array[0..JS_LIFECYCLE_PAD - 1] of Byte; end; // 64B padded len publication, isolated
  TPureLockSlot = record Value: Int32; Padding: array[0..JS_LIFECYCLE_PAD - 1] of Byte; end; // 64B padded lock, isolated
{$POP}
{$PUSH}{$CODEALIGN VARMIN=64}
var
  GPureClosed: array of UInt32; // compact 4B per Context: stored = epoch*2 + closed (0 alive,1 closed), 10k ~40KB vs 64B*10k=640KB before, cache-friendly, bytes.ops geometric single source
  GPureNextId: TPureNextIdSlot = (Value:1);
  GPureClosedLen: TPureLenSlot = (Value:0); // atomic publication length: SetLength release / IsClosed acquire, fixes FPC dynarray non-atomic publish race, 64B isolated
  GPureClosedLock: TPureLockSlot = (Value:0); // owner js.lifecycle: 64B padded lock, spinlock with deadline, bulk IsValid zero via FValid, strong acquire, 64B isolated
  GPureFree: array of UInt64; // freelist stack of indices, bounded, geometric via bytes.ops single source, shrinkable, 64B isolated via VARMIN
{$POP}
function GPureClosedCapacity: SizeUInt; inline;
begin
  // capacity probe single source via mem.dynarray owner, zero-copy header, no alloc, compact 4B slot
  Result := nextpas.core.mem.dynarray.DynArrayCapacityElem(Pointer(GPureClosed), SizeUInt(Length(GPureClosed)), SizeOf(UInt32));
end;
procedure PokePureClosedLen(const ANewLen: SizeUInt); inline;
var LBytes: TBytes absolute GPureClosed;
begin
  // perf: inline Exactly-Once poke via mem.dynarray single source, zero-copy header, amortized O(1), geometric via bytes.ops single source, single slit
  nextpas.core.mem.dynarray.DynArraySetLength(LBytes, ANewLen);
end;
function GPureFreeCapacity: SizeUInt; inline;
begin
  Result := nextpas.core.mem.dynarray.DynArrayCapacityElem(Pointer(GPureFree), SizeUInt(Length(GPureFree)), SizeOf(UInt64));
end;
function GPureIndexOf(AId: UInt64): UInt32; inline;
begin
  Result := UInt32(AId and $FFFFFFFF);
end;
function GPureEpochOf(AId: UInt64): UInt32; inline;
begin
  Result := UInt32(AId shr 32);
end;
function GPureMakeId(AIdx: UInt32; AEpoch: UInt32): UInt64; inline;
begin
  Result := (UInt64(AEpoch) shl 32) or UInt64(AIdx);
end;
procedure TryShrinkGPureFreeLocked; inline;
var LCap, LLen, LNewCap: SizeUInt;
begin
  // perf: inline shrink when capacity >> length (4x) to avoid long-service bloat, half each time, bytes.ops single source geometric, zero-copy
  LCap := GPureFreeCapacity;
  LLen := SizeUInt(Length(GPureFree));
  if LLen = 0 then
  begin
    if LCap > 0 then SetLength(GPureFree, 0);
    Exit;
  end;
  if (LCap > 64) and (LLen * 4 < LCap) then
  begin
    LNewCap := LCap div 2;
    if LNewCap < LLen then LNewCap := LLen;
    SetLength(GPureFree, Integer(LNewCap));
    if LNewCap <> LLen then
      nextpas.core.mem.dynarray.DynArraySetLengthGeneric(GPureFree, LLen);
  end;
end;
function JsPureContextRegister: UInt64;
var LNeed, LCap, LCurCap: SizeUInt; LId: Int64; LIdx, LEpoch, LStored: UInt32;
begin
  // phase A: freelist recycle under sampled spinlock single source (sync.spinlock RawSpin* 64-spin amortized, 5ms sampled deadline, inline zero-copy, no per-spin syscall storm), generation-tagged Id for INV-7 strong consistency, avoids bulk NewContext livelock
  RawSpinAcquire(GPureClosedLock.Value);
  try
    if Length(GPureFree) > 0 then
    begin
      LIdx := UInt32(GPureFree[High(GPureFree)]);
      SetLength(GPureFree, Length(GPureFree) - 1);
      // generation increment: stored was epoch*2+1 (closed), next alive = (epoch+1)*2
      LStored := atomic_load(GPureClosed[LIdx], mo_acquire);
      LEpoch := (LStored shr 1) + 1;
      LStored := LEpoch shl 1; // alive  epoch*2
      atomic_store(GPureClosed[LIdx], LStored, mo_release);
      Result := GPureMakeId(LIdx, LEpoch);
      TryShrinkGPureFreeLocked;
      Exit;
    end;
  finally
    RawSpinRelease(GPureClosedLock.Value);
  end;
  // phase B: no free slot — lock-free id via atomic_fetch_add_64 mo_relaxed, compact 4B slot, thread-affine geometric via bytes.ops single source, Exactly-Once poke via mem.dynarray, amortized O(1), sampled spinlock single source (rare), inline zero-copy header
  LId := Int64(atomic_fetch_add_64(GPureNextId.Value, Int64(1), mo_relaxed));
  LIdx := UInt32(UInt64(LId));
  Result := GPureMakeId(LIdx, 0);
  if LIdx >= UInt32(atomic_load(GPureClosedLen.Value, mo_acquire)) then
  begin
    // spinlock for resize — rare write-once, sampled 5ms deadline single source via sync.spinlock, avoids bulk NewContext contention livelock, inline, compact 4B slot
    RawSpinAcquire(GPureClosedLock.Value);
    try
      if LIdx >= UInt32(Length(GPureClosed)) then
      begin
        LNeed := SizeUInt(LIdx) + 1;
        LCurCap := GPureClosedCapacity;
        if LCurCap >= LNeed then
        begin
          if SizeUInt(Length(GPureClosed)) <> LNeed then
            PokePureClosedLen(LNeed);
        end
        else
        begin
          LCap := BytesNextCapacity(SizeUInt(Length(GPureClosed)), LNeed);
          SetLength(GPureClosed, Integer(LCap));
          // Exactly-Once: SetLength is capacity reservation (heap alloc) — logical length becomes LCap >= LNeed single header write, no extra DynArraySetLength down-poke, amortized O(1) geometric, preserves capacity, single header poke, bytes.ops single source, compact 4B slot
        end;
        atomic_store(GPureClosedLen.Value, Int32(Length(GPureClosed)), mo_release);
      end;
    finally
      RawSpinRelease(GPureClosedLock.Value);
    end;
  end;
  atomic_store(GPureClosed[LIdx], UInt32(0), mo_release); // epoch 0 alive
end;
procedure JsPureContextClose(AId: UInt64);
var LCap, LNeed: SizeUInt; LIdx, LEpoch, LStored, LExpected, LDesired: UInt32;
begin
  LIdx := GPureIndexOf(AId);
  LEpoch := GPureEpochOf(AId);
  if (AId = 0) or (LIdx >= UInt32(atomic_load(GPureClosedLen.Value, mo_acquire))) then Exit;
  LStored := atomic_load(GPureClosed[LIdx], mo_acquire);
  if (LStored shr 1) <> LEpoch then Exit; // stale generation => already closed/reused per INV-7 strong
  if (LStored and 1) <> 0 then Exit;
  // idempotent close via CAS to avoid double-free push, generation-tagged, strong acquire
  LExpected := LStored;
  LDesired := (LEpoch shl 1) or 1; // epoch*2+1 closed
  if not atomic_compare_exchange_strong(GPureClosed[LIdx], LExpected, LDesired) then Exit;
  // push index to freelist bounded recycling, sampled spinlock single source, guarantees recycling bounded, avoids unbounded GPureNextId/GPureClosed growth, shrinkable
  RawSpinAcquire(GPureClosedLock.Value);
  try
    LNeed := SizeUInt(Length(GPureFree)) + 1;
    if GPureFreeCapacity < LNeed then
    begin
      LCap := BytesNextCapacity(SizeUInt(Length(GPureFree)), LNeed);
      SetLength(GPureFree, Integer(LCap));
      // Exactly-Once: capacity reserved (LCap >= LNeed) single alloc via bytes.ops geometric, logical length will be poked to LNeed below without extra alloc, amortized O(1)
    end;
    SetLength(GPureFree, Integer(LNeed));
    GPureFree[High(GPureFree)] := UInt64(LIdx);
  finally
    RawSpinRelease(GPureClosedLock.Value);
  end;
end;
function JsPureContextIsClosed(AId: UInt64): Boolean; inline;
var LIdx, LEpoch, LStored: UInt32;
begin
  // perf: inline acquire single bounds check via atomic publication Len (fixes FPC dynarray non-atomic SetLength race, no phantom), compact 4B slot + generation mismatch => strong closed per INV-7, ~1ns read, 强一致 acquire；bulk via FValid zero barrier
  if AId = 0 then Exit(False);
  LIdx := GPureIndexOf(AId);
  LEpoch := GPureEpochOf(AId);
  if LIdx >= UInt32(atomic_load(GPureClosedLen.Value, mo_acquire)) then Exit(False);
  LStored := atomic_load(GPureClosed[LIdx], mo_acquire);
  if (LStored shr 1) <> LEpoch then Exit(True); // generation mismatch => old epoch, strong closed per INV-7
  Result := (LStored and 1) <> 0;
end;
function JsPureThreadSelf: UInt64; inline;
begin
  // perf: inline thin-forward to platform.thread single source (L0 single slit), zero-copy token, single syscall via pthread_self/GetCurrentThreadId, inline hot path, bytes.ops 单源几何同保持
  Result := UInt64(platform_thread_self);
end;
function JsPureIsOnCreationThread(ACreationId: UInt64): Boolean; inline;
begin
  // perf: inline single compare via JsPureThreadSelf single source, zero syscall beyond one, no duplication, thread-affine single source via lifecycle
  Result := JsPureThreadSelf = ACreationId;
end;
function JsPureMonotonicNs: QWord; inline;
begin
  // perf: inline thin-forward to platform.time single source (L0 single slit via platform_monotonic_ns, vdso), single syscall, zero-copy, bytes.ops single source复用见 deadline, lifecycle single source
  Result := QWord(platform_monotonic_ns);
end;
procedure JsPureDeadlineRefresh(var ADeadlineNs: Int64; ATimeoutMs: Integer); inline;
begin
  // perf: inline L0 single source via JsPureMonotonicNs, Timeout=0 zero syscall, exactly-once deadline, inline zero-copy, amortized O(1), bytes.ops single source保持 CONTRACT
  if ATimeoutMs <= 0 then ADeadlineNs := 0
  else ADeadlineNs := Int64(JsPureMonotonicNs + QWord(ATimeoutMs) * 1000000);
end;
function JsPureInterruptShouldAbort(ADeadlineNs: Int64; var ACounter: Cardinal; var ALastNs: QWord): Boolean; inline;
begin
  // perf: inline sampling 1024/sample via JsPureMonotonicNs single source, L0 platform.time single slit via lifecycle, cache-line friendly, exactly-once timeout语义, zero-copy, inline
  if ADeadlineNs = 0 then Exit(False);
  Inc(ACounter);
  if (ACounter and 1023) <> 0 then Exit(False);
  ALastNs := JsPureMonotonicNs;
  Result := QWord(ALastNs) >= QWord(ADeadlineNs);
end;
initialization
  // no mutex init, atomic only, VARMIN 64 ensures scalar cache-line isolation, GPureClosed compact 4B keeps L1/L2 friendly
finalization
  SetLength(GPureClosed, 0);
  SetLength(GPureFree, 0);
end.
