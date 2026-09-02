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
  // single vault luxury whitespace: header 64B + 5 fields converged (was 5 arrays + 4 pads scattered -> one vault, luxury留白)
  TJsLifecycleVault = record
    HeaderPad: TCacheLinePad; // 64B luxury header single, false-sharing free, vault isolation
    Closed: array of UInt32; // compact 4B epoch*2+closed
    ClosedLen: PtrUInt;
    NextId: Int64;
    Lock: Int32;
    Free: array of UInt64; // freelist via collections.freelist single source
  end;
  PJsLifecycleVault = ^TJsLifecycleVault;
var
  GLifecycleVault: TJsLifecycleVault;
function VaultRef: PJsLifecycleVault; inline;
begin
  // perf: inline single indirection, zero-copy vault ref, single source for all vault access, no duplicate @GLifecycleVault, inline zero-copy
  Result := @GLifecycleVault;
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
// heap growth single source via bytes.ops geometric single slit, inline zero-copy, amortized O(1)
procedure GPureClosedEnsure(const ANewLen: SizeUInt); inline;
begin
  // bytes.ops single source via BytesDynEnsureLength geometric 0→64→2× amortized O(1), vault single source
  BytesDynEnsureLength(VaultRef^.Closed, SizeOf(UInt32), ANewLen);
end;
function JsPureContextRegister: UInt64;
var LNeed: SizeUInt; LId: Int64; LIdx, LEpoch, LStored: UInt32; LTmp: UInt64; LRetry: Integer;
  LCap, LTargetCap: SizeUInt; LGrowNeed: SizeUInt; LTmpClosed: array of UInt32; LNeedHold: Boolean;
begin
  // freelist via collections.freelist, generation-tagged INV-7, sync.spinlock single source, vault single source
  RawSpinAcquire(VaultRef^.Lock);
  try
    if FreelistPopU64(VaultRef^.Free, LTmp) then
    begin
      LIdx := UInt32(LTmp);
      // generation increment: stored was epoch*2+1 (closed), next alive = (epoch+1)*2
      LStored := atomic_load(VaultRef^.Closed[LIdx], mo_acquire);
      LEpoch := (LStored shr 1) + 1;
      LStored := LEpoch shl 1; // alive  epoch*2
      atomic_store(VaultRef^.Closed[LIdx], LStored, mo_release);
      Result := GPureMakeId(LIdx, LEpoch);
      FreelistTryShrinkU64(VaultRef^.Free);
      Exit;
    end;
  finally
    RawSpinRelease(VaultRef^.Lock);
  end;
  // no free slot — lock-free id via atomic_fetch_add_64, bytes.ops geometric single source via collections.freelist, vault single source
  LId := Int64(atomic_fetch_add_64(VaultRef^.NextId, Int64(1), mo_relaxed));
  // wrap detect: 2^32 index space, long service freelist reuse not hard DoS — bounded freelist retry with backoff, generation-tagged epoch protects ABA per INV-7
  if UInt64(LId) > High(UInt32) then
  begin
    // stability: burst NewContext/Close churn at wrap boundary uses bounded retry (8×) with cpu_pause, not single-shot hard DoS; long service bounded recycling via Free
    for LRetry := 0 to 7 do
    begin
      RawSpinAcquire(VaultRef^.Lock);
      try
        if FreelistPopU64(VaultRef^.Free, LTmp) then
        begin
          LIdx := UInt32(LTmp);
          LStored := atomic_load(VaultRef^.Closed[LIdx], mo_acquire);
          LEpoch := (LStored shr 1) + 1;
          LStored := LEpoch shl 1;
          atomic_store(VaultRef^.Closed[LIdx], LStored, mo_release);
          Result := GPureMakeId(LIdx, LEpoch);
          FreelistTryShrinkU64(VaultRef^.Free);
          Exit;
        end;
      finally
        RawSpinRelease(VaultRef^.Lock);
      end;
      cpu_pause;
    end;
    raise EInvalidOperation.Create('JsPureContextRegister: id space exhausted (2^32 wrap) — no free slots after bounded freelist retry (8×), all 4B contexts live');
  end;
  LIdx := UInt32(UInt64(LId));
  Result := GPureMakeId(LIdx, 0);
  if PtrUInt(LIdx) >= atomic_load(VaultRef^.ClosedLen, mo_relaxed) then
  begin
    // resize rare, sync.spinlock single source, compact 4B, bytes.ops geometric single source via Vault — heap alloc outside spin to avoid blocking concurrent registration
    LNeed := SizeUInt(LIdx) + 1;
    // phase 1: quick probe under spin without allocation to decide if growth needed and capture capacity
    RawSpinAcquire(VaultRef^.Lock);
    try
      if LIdx >= UInt32(Length(VaultRef^.Closed)) then
      begin
        LCap := BytesDynCapacityGeneric(VaultRef^.Closed, SizeOf(UInt32));
        if LCap >= LNeed then
        begin
          // capacity sufficient -> poke logical len under spin, zero alloc, rare but no heap
          BytesDynSetLengthGeneric(VaultRef^.Closed, LNeed);
          atomic_store(VaultRef^.ClosedLen, PtrUInt(Length(VaultRef^.Closed)), mo_release);
          LGrowNeed := 0;
        end
        else
        begin
          LGrowNeed := LNeed;
          LTargetCap := BytesNextCapacity(PtrUInt(Length(VaultRef^.Closed)), LNeed);
        end;
        LNeedHold := LGrowNeed <> 0;
      end
      else
      begin
        // concurrent grow already satisfied, ensure ClosedLen published
        if PtrUInt(Length(VaultRef^.Closed)) > atomic_load(VaultRef^.ClosedLen, mo_relaxed) then
          atomic_store(VaultRef^.ClosedLen, PtrUInt(Length(VaultRef^.Closed)), mo_release);
        LNeedHold := False;
        LGrowNeed := 0;
      end;
    finally
      RawSpinRelease(VaultRef^.Lock);
    end;
    if LNeedHold then
    begin
      // outside spin: allocate new capacity via geometric bytes.ops single source, zero spin-held heap alloc
      SetLength(LTmpClosed, LTargetCap);
      // phase 2: install under spin with copy (copy is single BytesCopy Move single source, zero extra fence)
      RawSpinAcquire(VaultRef^.Lock);
      try
        if LIdx >= UInt32(Length(VaultRef^.Closed)) then
        begin
          LCap := BytesDynCapacityGeneric(VaultRef^.Closed, SizeOf(UInt32));
          if LCap < LNeed then
          begin
            if Length(VaultRef^.Closed) > 0 then
              BytesCopy(@LTmpClosed[0], @VaultRef^.Closed[0], SizeUInt(Length(VaultRef^.Closed)) * SizeOf(UInt32));
            VaultRef^.Closed := LTmpClosed;
            LTmpClosed := nil;
            if PtrUInt(Length(VaultRef^.Closed)) <> LNeed then
              BytesDynSetLengthGeneric(VaultRef^.Closed, LNeed);
            atomic_store(VaultRef^.ClosedLen, PtrUInt(Length(VaultRef^.Closed)), mo_release);
          end
          else
          begin
            BytesDynSetLengthGeneric(VaultRef^.Closed, LNeed);
            atomic_store(VaultRef^.ClosedLen, PtrUInt(Length(VaultRef^.Closed)), mo_release);
            SetLength(LTmpClosed, 0);
          end;
        end
        else
          SetLength(LTmpClosed, 0);
      finally
        RawSpinRelease(VaultRef^.Lock);
        if Length(LTmpClosed) > 0 then
          SetLength(LTmpClosed, 0);
      end;
    end;
  end;
  atomic_store(VaultRef^.Closed[LIdx], UInt32(0), mo_release); // epoch 0 alive
end;
procedure JsPureContextClose(AId: UInt64);
var LIdx, LEpoch, LStored, LExpected, LDesired: UInt32;
begin
  LIdx := GPureIndexOf(AId);
  LEpoch := GPureEpochOf(AId);
  if (AId = 0) or (PtrUInt(LIdx) >= atomic_load(VaultRef^.ClosedLen, mo_relaxed)) then Exit;
  LStored := atomic_load(VaultRef^.Closed[LIdx], mo_acquire);
  if (LStored shr 1) <> LEpoch then Exit; // stale generation => already closed/reused per INV-7 strong
  if (LStored and 1) <> 0 then Exit;
  // idempotent close via CAS to avoid double-free push, generation-tagged, strong acquire
  LExpected := LStored;
  LDesired := (LEpoch shl 1) or 1; // epoch*2+1 closed
  if not atomic_compare_exchange_strong(VaultRef^.Closed[LIdx], LExpected, LDesired) then Exit;
  // freelist via collections.freelist single source, sync.spinlock single source, amortized O(1) inline zero-copy, vault single source
  RawSpinAcquire(VaultRef^.Lock);
  try
    FreelistPushU64(VaultRef^.Free, UInt64(LIdx));
  finally
    RawSpinRelease(VaultRef^.Lock);
  end;
end;
function JsPureContextIsClosed(AId: UInt64): Boolean; inline;
var LIdx, LEpoch, LStored: UInt32;
begin
  // perf: single acquire (slot) + relaxed Len, compact 4B, generation mismatch => strong closed INV-7, inline zero-copy, vault single source
  // bulk hot path must use TJsValue.IsValid (FValid only, zero barrier); IsAlive/IsClosed via acquire single source for strong consistency (single acquire slot + relaxed Len reduces fence/false-sharing)
  if AId = 0 then Exit(False);
  LIdx := GPureIndexOf(AId);
  LEpoch := GPureEpochOf(AId);
  if PtrUInt(LIdx) >= atomic_load(VaultRef^.ClosedLen, mo_relaxed) then Exit(False);
  LStored := atomic_load(VaultRef^.Closed[LIdx], mo_acquire);
  if (LStored shr 1) <> LEpoch then Exit(True); // generation mismatch => strong closed INV-7
  Result := (LStored and 1) <> 0;
end;
function JsPureThreadSelf: UInt64; inline;
begin
  // inline thin-forward to platform.thread single source, zero-copy, vault single source
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
  // 64B isolated vault: single luxury header pad, vault convergence of 5 fields, false-sharing free, vault single source
  GLifecycleVault.ClosedLen := 0;
  GLifecycleVault.NextId := 1;
  GLifecycleVault.Lock := 0;
finalization
  SetLength(GLifecycleVault.Closed, 0);
  SetLength(GLifecycleVault.Free, 0);
end.
