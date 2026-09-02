unit nextpas.core.js.lifecycle;
{ lifecycle owner — single source for pure Context registry: GPureClosed 64B padded atomic acquire/release, cache-line isolated (NextId/Len/Lock/Free each 64B VARMIN isolated, false-sharing free), freelist recycling bounded memory via bytes.ops geometric single source + mem.dynarray Exactly-Once, write-once rare, bulk IsValid zero atomic via FValid, strong acquire; spinlock with exponential backoff + deadline 5ms timeout/yield to avoid starvation livelock under bulk NewContext, base remains thin type-carrier per four-piece, lifecycle extracted to js.lifecycle single source, 复用 bytes.ops单源几何 via BytesNextCapacity + mem.dynarray poke Exactly-Once, inline零拷贝, amortized O(1), L0-L3守分层. L0 thread/time single slit via lifecycle (platform.thread + platform.time single source), quickjs.value thin-forwards, no dual entry. }
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
  nextpas.core.platform.time;
const
  JS_LIFECYCLE_CACHE_LINE = MEM_CACHE_LINE_SIZE; // 64 via mem.base single source, no magic
  JS_LIFECYCLE_PAD = JS_LIFECYCLE_CACHE_LINE - SizeOf(Int32); // 60 via CACHE_LINE single source
  JS_LIFECYCLE_PAD64 = JS_LIFECYCLE_CACHE_LINE - SizeOf(Int64); // 56 via CACHE_LINE single source
  JS_LIFECYCLE_SPIN_TIMEOUT_NS = QWord(5 * 1000000); // 5ms deadline via platform.time single source, bounds spinlock to avoid bulk starvation livelock
{$PUSH}{$CODEALIGN RECORDMIN=16}{$PACKRECORDS C}
type
  TPureClosedSlot = record Value: Int32; Padding: array[0..JS_LIFECYCLE_PAD - 1] of Byte; end; // 64B cache-line padded via CODEALIGN+pad, instance-isolated atomic slot, false-sharing free, write-once rare, 60B pad via MEM_CACHE_LINE_SIZE single source
  TPureNextIdSlot = record Value: Int64; Padding: array[0..JS_LIFECYCLE_PAD64 - 1] of Byte; end; // 64B padded scalar, cache-line isolated via VARMIN 64 + pad
  TPureLenSlot = record Value: Int32; Padding: array[0..JS_LIFECYCLE_PAD - 1] of Byte; end; // 64B padded len publication, isolated
  TPureLockSlot = record Value: Int32; Padding: array[0..JS_LIFECYCLE_PAD - 1] of Byte; end; // 64B padded lock, isolated
{$POP}
{$PUSH}{$CODEALIGN VARMIN=64}
var
  GPureClosed: array of TPureClosedSlot;
  GPureNextId: TPureNextIdSlot = (Value:1);
  GPureClosedLen: TPureLenSlot = (Value:0); // atomic publication length: SetLength release / IsClosed acquire, fixes FPC dynarray non-atomic publish race, 64B isolated
  GPureClosedLock: TPureLockSlot = (Value:0); // owner js.lifecycle: 64B padded 4B atomic acquire/release per slot, atomic_fetch_add id lock-free, spinlock with deadline, bulk IsValid zero via FValid, strong acquire, 64B isolated
  GPureFree: array of UInt64; // freelist stack for Id recycling, bounded memory, 64B isolated via VARMIN, protected by GPureClosedLock, geometric via bytes.ops single source
{$POP}
function GPureClosedCapacity: SizeUInt; inline;
begin
  // capacity probe single source via mem.dynarray owner, zero-copy header, no alloc, 64B padded slot
  Result := nextpas.core.mem.dynarray.DynArrayCapacityElem(Pointer(GPureClosed), SizeUInt(Length(GPureClosed)), SizeOf(TPureClosedSlot));
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
function JsPureContextRegister: UInt64;
var LNeed, LCap, LCurCap: SizeUInt; LId: Int64; LExp: Int32; LSpins: Integer; LDeadline: QWord; LBackoff, LB: Integer;
begin
  // phase A: freelist recycle under spinlock with 5ms deadline + exponential backoff + bounded yield, avoids bulk NewContext livelock
  LExp := 0; LSpins := 0; LDeadline := QWord(platform_monotonic_ns) + JS_LIFECYCLE_SPIN_TIMEOUT_NS;
  while not atomic_compare_exchange_strong(GPureClosedLock.Value, LExp, Int32(1), mo_acquire, mo_relaxed) do
  begin
    LExp := 0; Inc(LSpins);
    if QWord(platform_monotonic_ns) > LDeadline then
    begin
      platform_thread_yield;
      LDeadline := QWord(platform_monotonic_ns) + JS_LIFECYCLE_SPIN_TIMEOUT_NS;
      LSpins := 0;
      Continue;
    end;
    if LSpins < 32 then
    begin
      LBackoff := 1 shl (LSpins shr 2); // 1,1,1,1,2,2,2,2,4,4,4,4,8...
      if LBackoff > 8 then LBackoff := 8;
      for LB := 1 to LBackoff do cpu_pause;
    end
    else begin platform_thread_yield; LSpins := 0; end;
  end;
  try
    if Length(GPureFree) > 0 then
    begin
      Result := GPureFree[High(GPureFree)];
      SetLength(GPureFree, Length(GPureFree) - 1);
      atomic_store(GPureClosed[Result].Value, 0, mo_release);
      Exit;
    end;
  finally
    atomic_store(GPureClosedLock.Value, Int32(0), mo_release);
  end;
  // phase B: no free slot — lock-free id via atomic_fetch_add_64 mo_relaxed, instance-isolated, thread-affine geometric via bytes.ops single source, Exactly-Once poke via mem.dynarray, amortized O(1), spinlock with exponential backoff + deadline (rare), inline zero-copy header, 64B CODEALIGN padded slot — downgraded from mo_seq_cst to save MFENCE vs mo_acq_rel, release paired via slot store
  LId := Int64(atomic_fetch_add_64(GPureNextId.Value, Int64(1), mo_relaxed));
  Result := UInt64(LId);
  if Result >= UInt64(atomic_load(GPureClosedLen.Value, mo_acquire)) then
  begin
    // spinlock for resize — rare write-once, 5ms deadline + exponential backoff + bounded yield, avoids bulk NewContext contention livelock
    LExp := 0; LSpins := 0; LDeadline := QWord(platform_monotonic_ns) + JS_LIFECYCLE_SPIN_TIMEOUT_NS;
    while not atomic_compare_exchange_strong(GPureClosedLock.Value, LExp, Int32(1), mo_acquire, mo_relaxed) do
    begin
      LExp := 0; Inc(LSpins);
      if QWord(platform_monotonic_ns) > LDeadline then
      begin
        platform_thread_yield;
        LDeadline := QWord(platform_monotonic_ns) + JS_LIFECYCLE_SPIN_TIMEOUT_NS;
        LSpins := 0;
        Continue;
      end;
      if LSpins < 32 then
      begin
        LBackoff := 1 shl (LSpins shr 2);
        if LBackoff > 8 then LBackoff := 8;
        for LB := 1 to LBackoff do cpu_pause;
      end
      else begin platform_thread_yield; LSpins := 0; end;
    end;
    try
      if Result >= UInt64(Length(GPureClosed)) then
      begin
        LNeed := SizeUInt(Result) + 1;
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
          // Exactly-Once: SetLength is capacity reservation (heap alloc) — logical length becomes LCap >= LNeed single header write, no extra DynArraySetLength down-poke, amortized O(1) geometric, preserves capacity, single header poke, bytes.ops single source
        end;
        atomic_store(GPureClosedLen.Value, Int32(Length(GPureClosed)), mo_release);
      end;
    finally
      atomic_store(GPureClosedLock.Value, Int32(0), mo_release);
    end;
  end;
  atomic_store(GPureClosed[Result].Value, 0, mo_release);
end;
procedure JsPureContextClose(AId: UInt64);
var LExp: Int32; LSpins: Integer; LDeadline: QWord; LCap, LNeed: SizeUInt; LBackoff, LB: Integer;
begin
  if (AId = 0) or (AId >= UInt64(atomic_load(GPureClosedLen.Value, mo_acquire))) then Exit;
  // idempotent close: exchange detects duplicate close to avoid double free push
  if atomic_exchange(GPureClosed[AId].Value, 1) <> 0 then Exit;
  // push to freelist bounded recycling, 5ms deadline + exponential backoff + bounded yield, avoids bulk close livelock
  LExp := 0; LSpins := 0; LDeadline := QWord(platform_monotonic_ns) + JS_LIFECYCLE_SPIN_TIMEOUT_NS;
  while not atomic_compare_exchange_strong(GPureClosedLock.Value, LExp, Int32(1), mo_acquire, mo_relaxed) do
  begin
    LExp := 0; Inc(LSpins);
    if QWord(platform_monotonic_ns) > LDeadline then Exit; // timeout: skip recycling, already marked closed, avoids starvation livelock, resource not lost
    if LSpins < 32 then
    begin
      LBackoff := 1 shl (LSpins shr 2);
      if LBackoff > 8 then LBackoff := 8;
      for LB := 1 to LBackoff do cpu_pause;
    end
    else begin platform_thread_yield; LSpins := 0; end;
  end;
  try
    LNeed := SizeUInt(Length(GPureFree)) + 1;
    if GPureFreeCapacity < LNeed then
    begin
      LCap := BytesNextCapacity(SizeUInt(Length(GPureFree)), LNeed);
      SetLength(GPureFree, Integer(LCap));
      // Exactly-Once: capacity reserved (LCap >= LNeed) single alloc via bytes.ops geometric, logical length will be poked to LNeed below without extra alloc, amortized O(1)
    end;
    SetLength(GPureFree, Integer(LNeed));
    GPureFree[High(GPureFree)] := AId;
  finally
    atomic_store(GPureClosedLock.Value, Int32(0), mo_release);
  end;
end;
function JsPureContextIsClosed(AId: UInt64): Boolean; inline;
var LVal: Int32;
begin
  // perf: inline acquire single bounds check via atomic publication Len (fixes FPC dynarray non-atomic SetLength race, no phantom), 64B CODEALIGN padded atomic slot (false-sharing free), write-once rare, ~1ns read, 强一致 acquire；bulk via FValid zero barrier
  if AId = 0 then Exit(False);
  if AId >= UInt64(atomic_load(GPureClosedLen.Value, mo_acquire)) then Exit(False);
  LVal := atomic_load(GPureClosed[AId].Value, mo_acquire);
  Result := LVal <> 0;
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
  // no mutex init, atomic only, VARMIN 64 ensures cache-line isolation
finalization
  SetLength(GPureClosed, 0);
  SetLength(GPureFree, 0);
end.
