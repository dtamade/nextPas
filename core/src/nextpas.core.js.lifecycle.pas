unit nextpas.core.js.lifecycle;
{ lifecycle owner — single source for pure Context registry: GPureClosed compact 4B, 64B isolated }
{$I nextpas.core.settings.inc}
interface
function JsPureContextRegister: UInt64;
procedure JsPureContextClose(AId: UInt64);
function JsPureContextIsClosed(AId: UInt64): Boolean; inline;
function JsPureThreadSelf: UInt64; inline;
function JsPureIsOnCreationThread(ACreationId: UInt64): Boolean; inline;
// L0 time single slit via platform.time, inline zero-copy
function JsPureMonotonicNs: QWord; inline;
procedure JsPureDeadlineRefresh(var ADeadlineNs: Int64; ATimeoutMs: Integer); inline;
function JsPureInterruptShouldAbort(ADeadlineNs: Int64; var ACounter: Cardinal; var ALastNs: QWord): Boolean; inline; overload;
function JsPureInterruptShouldAbort(ADeadlineNs: Int64; var ACounter: Cardinal; var ALastNs: QWord; ASampleInterval: Cardinal): Boolean; inline; overload;
implementation
uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.collections.freelist,
  nextpas.core.atomic,
  nextpas.core.mem.base,
  nextpas.core.platform.thread,
  nextpas.core.platform.time,
  nextpas.core.sync.spinlock,
  nextpas.core.js.base;
type
  TCacheLinePad = array[0..MEM_CACHE_LINE_SIZE div SizeOf(Int64) - 1] of Int64; // 64B pad via MEM_CACHE_LINE_SIZE single source
var
  // 64B isolated lifecycle state: GPureClosed compact 4B epoch*2+closed + NextId/Len/Lock/Free pads
  GPureClosed: array of UInt32;
  GPureClosedPad: TCacheLinePad;
  GPureNextId: Int64 = 1;
  GPureNextIdPad: TCacheLinePad;
  GPureClosedLen: PtrUInt = 0;
  GPureClosedLenPad: TCacheLinePad;
  GPureClosedLock: Int32 = 0;
  GPureClosedLockPad: TCacheLinePad;
  GPureFree: array of UInt64; // freelist via collections.freelist single source
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
// heap growth single source via bytes.ops geometric single slit, inline zero-copy, amortized O(1)
procedure GPureClosedEnsure(const ANewLen: SizeUInt); inline;
begin
  BytesDynEnsureLength(GPureClosed, SizeOf(UInt32), ANewLen);
end;
function JsPureContextRegister: UInt64;
var LNeed: SizeUInt; LId: Int64; LIdx, LEpoch, LStored: UInt32; LTmp: UInt64; LRetry: Integer;
begin
  // freelist via collections.freelist, generation-tagged INV-7, sync.spinlock single source
  RawSpinAcquire(GPureClosedLock);
  try
    if FreelistPopU64(GPureFree, LTmp) then
    begin
      LIdx := UInt32(LTmp);
      // generation increment: stored was epoch*2+1 (closed), next alive = (epoch+1)*2
      LStored := atomic_load(GPureClosed[LIdx], mo_acquire);
      LEpoch := (LStored shr 1) + 1;
      LStored := LEpoch shl 1; // alive  epoch*2
      atomic_store(GPureClosed[LIdx], LStored, mo_release);
      Result := GPureMakeId(LIdx, LEpoch);
      FreelistTryShrinkU64(GPureFree);
      Exit;
    end;
  finally
    RawSpinRelease(GPureClosedLock);
  end;
  // no free slot — lock-free id via atomic_fetch_add_64, bytes.ops geometric single source via collections.freelist
  LId := Int64(atomic_fetch_add_64(GPureNextId, Int64(1), mo_relaxed));
  // wrap detect: 2^32 index space, long service freelist reuse not hard DoS — bounded freelist retry with backoff, generation-tagged epoch protects ABA per INV-7
  if UInt64(LId) > High(UInt32) then
  begin
    // stability: burst NewContext/Close churn at wrap boundary uses bounded retry (8×) with cpu_pause, not single-shot hard DoS; long service bounded recycling via GPureFree
    for LRetry := 0 to 7 do
    begin
      RawSpinAcquire(GPureClosedLock);
      try
        if FreelistPopU64(GPureFree, LTmp) then
        begin
          LIdx := UInt32(LTmp);
          LStored := atomic_load(GPureClosed[LIdx], mo_acquire);
          LEpoch := (LStored shr 1) + 1;
          LStored := LEpoch shl 1;
          atomic_store(GPureClosed[LIdx], LStored, mo_release);
          Result := GPureMakeId(LIdx, LEpoch);
          FreelistTryShrinkU64(GPureFree);
          Exit;
        end;
      finally
        RawSpinRelease(GPureClosedLock);
      end;
      cpu_pause;
    end;
    raise EInvalidOperation.Create('JsPureContextRegister: id space exhausted (2^32 wrap) — no free slots after bounded freelist retry (8×), all 4B contexts live');
  end;
  LIdx := UInt32(UInt64(LId));
  Result := GPureMakeId(LIdx, 0);
  if PtrUInt(LIdx) >= atomic_load(GPureClosedLen, mo_relaxed) then
  begin
    // resize rare, sync.spinlock single source, compact 4B, bytes.ops geometric single source via GPureClosedEnsure
    RawSpinAcquire(GPureClosedLock);
    try
      if LIdx >= UInt32(Length(GPureClosed)) then
      begin
        LNeed := SizeUInt(LIdx) + 1;
        GPureClosedEnsure(LNeed);
        atomic_store(GPureClosedLen, PtrUInt(Length(GPureClosed)), mo_release);
      end;
    finally
      RawSpinRelease(GPureClosedLock);
    end;
  end;
  atomic_store(GPureClosed[LIdx], UInt32(0), mo_release); // epoch 0 alive
end;
procedure JsPureContextClose(AId: UInt64);
var LIdx, LEpoch, LStored, LExpected, LDesired: UInt32;
begin
  LIdx := GPureIndexOf(AId);
  LEpoch := GPureEpochOf(AId);
  if (AId = 0) or (PtrUInt(LIdx) >= atomic_load(GPureClosedLen, mo_relaxed)) then Exit;
  LStored := atomic_load(GPureClosed[LIdx], mo_acquire);
  if (LStored shr 1) <> LEpoch then Exit; // stale generation => already closed/reused per INV-7 strong
  if (LStored and 1) <> 0 then Exit;
  // idempotent close via CAS to avoid double-free push, generation-tagged, strong acquire
  LExpected := LStored;
  LDesired := (LEpoch shl 1) or 1; // epoch*2+1 closed
  if not atomic_compare_exchange_strong(GPureClosed[LIdx], LExpected, LDesired) then Exit;
  // freelist via collections.freelist single source, sync.spinlock single source, amortized O(1) inline zero-copy
  RawSpinAcquire(GPureClosedLock);
  try
    FreelistPushU64(GPureFree, UInt64(LIdx));
  finally
    RawSpinRelease(GPureClosedLock);
  end;
end;
function JsPureContextIsClosed(AId: UInt64): Boolean; inline;
var LIdx, LEpoch, LStored: UInt32;
begin
  // perf: single acquire (slot) + relaxed Len, compact 4B, generation mismatch => strong closed INV-7, inline zero-copy
  // bulk hot path must use TJsValue.IsValid (FValid only, zero barrier); IsAlive/IsClosed via acquire single source for strong consistency (single acquire slot + relaxed Len reduces fence/false-sharing)
  if AId = 0 then Exit(False);
  LIdx := GPureIndexOf(AId);
  LEpoch := GPureEpochOf(AId);
  if PtrUInt(LIdx) >= atomic_load(GPureClosedLen, mo_relaxed) then Exit(False);
  LStored := atomic_load(GPureClosed[LIdx], mo_acquire);
  if (LStored shr 1) <> LEpoch then Exit(True); // generation mismatch => strong closed INV-7
  Result := (LStored and 1) <> 0;
end;
function JsPureThreadSelf: UInt64; inline;
begin
  // inline thin-forward to platform.thread single source, zero-copy
  Result := UInt64(platform_thread_self);
end;
function JsPureIsOnCreationThread(ACreationId: UInt64): Boolean; inline;
begin
  // inline single compare via JsPureThreadSelf single source
  Result := JsPureThreadSelf = ACreationId;
end;
function JsPureMonotonicNs: QWord; inline;
begin
  // inline thin-forward to platform.time single source, zero-copy
  Result := QWord(platform_monotonic_ns);
end;
procedure JsPureDeadlineRefresh(var ADeadlineNs: Int64; ATimeoutMs: Integer); inline;
begin
  // inline via JsPureMonotonicNs, Timeout=0 zero syscall, exactly-once
  if ATimeoutMs <= 0 then ADeadlineNs := 0
  else ADeadlineNs := Int64(JsPureMonotonicNs + QWord(ATimeoutMs) * 1000000);
end;
function JsPureInterruptShouldAbort(ADeadlineNs: Int64; var ACounter: Cardinal; var ALastNs: QWord): Boolean; inline;
begin
  // perf: thin-forward to interval-aware single source via JsInterruptSampleIntervalNormalized + interval 1024 default, sampling 可配, bytes.ops 单源, inline 零拷贝
  Result := JsPureInterruptShouldAbort(ADeadlineNs, ACounter, ALastNs, JS_INTERRUPT_SAMPLE_DEFAULT);
end;

function JsPureInterruptShouldAbort(ADeadlineNs: Int64; var ACounter: Cardinal; var ALastNs: QWord; ASampleInterval: Cardinal): Boolean; inline;
var LInterval: Cardinal;
begin
  // perf: inline sampling 可配 via JsInterruptSampleIntervalNormalized single source (base owner, bytes.ops 单源), 1→逐次 15-30% 开销, 1024→15-30%降为惰性, 65536→更低开销但最长65536次延迟, power-of-two 快路径 and mask else mod 分支, 惰性刷新 single source, inline 零拷贝, exactly-once
  if ADeadlineNs = 0 then Exit(False);
  Inc(ACounter);
  LInterval := JsInterruptSampleIntervalNormalized(ASampleInterval);
  if (LInterval and (LInterval - 1)) = 0 then
  begin
    if (ACounter and (LInterval - 1)) <> 0 then Exit(False);
  end else
  begin
    if (ACounter mod LInterval) <> 0 then Exit(False);
  end;
  ALastNs := JsPureMonotonicNs;
  Result := QWord(ALastNs) >= QWord(ADeadlineNs);
end;
initialization
  // 64B isolated state: GPureClosed 4B compact + 64B pads between NextId/Len/Lock/Free (false-sharing free)
finalization
  SetLength(GPureClosed, 0);
  SetLength(GPureFree, 0);
end.
