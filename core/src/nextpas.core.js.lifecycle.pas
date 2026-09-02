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
function JsPureInterruptShouldAbort(ADeadlineNs: Int64; var ACounter: Cardinal; var ALastNs: QWord): Boolean; inline;
implementation
uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.atomic,
  nextpas.core.platform.thread,
  nextpas.core.platform.time,
  nextpas.core.sync.spinlock;
type
  TCacheLinePad = array[0..7] of Int64; // 64B isolation, false-sharing free
var
  GPureClosed: array of UInt32; // compact 4B per Context: epoch*2+closed
  GPureClosedPad: TCacheLinePad; // 64B isolation from NextId
  GPureNextId: Int64 = 1; // atomic monotonic, 64B isolated
  GPureNextIdPad: TCacheLinePad; // 64B isolation from Len
  GPureClosedLen: PtrUInt = 0; // atomic Len, release/acquire, 64B isolated
  GPureClosedLenPad: TCacheLinePad; // 64B isolation from Lock
  GPureClosedLock: Int32 = 0; // spinlock single source, 64B isolated
  GPureClosedLockPad: TCacheLinePad; // 64B isolation from Free
  GPureFree: array of UInt64; // freelist bounded, bytes.ops geometric, 64B tail
function GPureFreeCapacity: SizeUInt; inline;
begin
  Result := BytesDynCapacityElem(Pointer(GPureFree), SizeUInt(Length(GPureFree)), SizeOf(UInt64));
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
var LCap, LLen: SizeUInt;
begin
  // inline shrink when 4x bloat, single SetLength, bytes.ops single source
  LCap := GPureFreeCapacity;
  LLen := SizeUInt(Length(GPureFree));
  if LLen = 0 then
  begin
    if LCap > 0 then SetLength(GPureFree, 0);
    Exit;
  end;
  if (LCap > 64) and (LLen * 4 < LCap) then
    SetLength(GPureFree, Integer(LLen));
end;
// heap growth single source via bytes.ops geometric (BytesDynEnsureLength) single slit, inline zero-copy, amortized O(1)
procedure GPureClosedEnsure(const ANewLen: SizeUInt); inline;
begin
  // perf: inline thin-forward to bytes.ops single source geometric via BytesDynEnsureLength (BytesNextCapacity + probe/poke), zero-copy, amortized O(1), trivial U32
  BytesDynEnsureLength(GPureClosed, SizeOf(UInt32), ANewLen);
end;
procedure GPureFreeEnsure(const ANewLen: SizeUInt); inline;
begin
  // perf: inline thin-forward to bytes.ops single source geometric via BytesDynEnsureLength, zero-copy, amortized O(1), trivial U64
  BytesDynEnsureLength(GPureFree, SizeOf(UInt64), ANewLen);
end;
function JsPureContextRegister: UInt64;
var LNeed: SizeUInt; LId: Int64; LIdx, LEpoch, LStored: UInt32;
begin
  // freelist recycle bounded, generation-tagged INV-7, sync.spinlock single source
  RawSpinAcquire(GPureClosedLock);
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
    RawSpinRelease(GPureClosedLock);
  end;
  // no free slot — lock-free id via atomic_fetch_add_64, bytes.ops geometric, inline zero-copy
  LId := Int64(atomic_fetch_add_64(GPureNextId, Int64(1), mo_relaxed));
  // wrap detect: UInt32 low 32 bits is index, >2^32 would reuse and collide with freelist epoch
  if UInt64(LId) > High(UInt32) then
    raise EInvalidOperation.Create('JsPureContextRegister: id space exhausted (2^32 wrap)');
  LIdx := UInt32(UInt64(LId));
  Result := GPureMakeId(LIdx, 0);
  if PtrUInt(LIdx) >= atomic_load(GPureClosedLen, mo_acquire) then
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
var LNeed: SizeUInt; LIdx, LEpoch, LStored, LExpected, LDesired: UInt32;
begin
  LIdx := GPureIndexOf(AId);
  LEpoch := GPureEpochOf(AId);
  if (AId = 0) or (PtrUInt(LIdx) >= atomic_load(GPureClosedLen, mo_acquire)) then Exit;
  LStored := atomic_load(GPureClosed[LIdx], mo_acquire);
  if (LStored shr 1) <> LEpoch then Exit; // stale generation => already closed/reused per INV-7 strong
  if (LStored and 1) <> 0 then Exit;
  // idempotent close via CAS to avoid double-free push, generation-tagged, strong acquire
  LExpected := LStored;
  LDesired := (LEpoch shl 1) or 1; // epoch*2+1 closed
  if not atomic_compare_exchange_strong(GPureClosed[LIdx], LExpected, LDesired) then Exit;
  // freelist bounded recycling, sync.spinlock single source, bytes.ops geometric single source via GPureFreeEnsure
  RawSpinAcquire(GPureClosedLock);
  try
    LNeed := SizeUInt(Length(GPureFree)) + 1;
    GPureFreeEnsure(LNeed);
    GPureFree[High(GPureFree)] := UInt64(LIdx);
  finally
    RawSpinRelease(GPureClosedLock);
  end;
end;
function JsPureContextIsClosed(AId: UInt64): Boolean; inline;
var LIdx, LEpoch, LStored: UInt32;
begin
  // perf: single acquire (slot) + acquire Len, compact 4B, generation mismatch => strong closed INV-7, inline zero-copy
  // bulk hot path must use TJsValue.IsValid (FValid only, zero barrier); IsAlive/IsClosed via this acquire single source for strong consistency, reduces cache coherence but INV-7 strong requires acquire pair with release
  if AId = 0 then Exit(False);
  LIdx := GPureIndexOf(AId);
  LEpoch := GPureEpochOf(AId);
  if PtrUInt(LIdx) >= atomic_load(GPureClosedLen, mo_acquire) then Exit(False);
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
  // inline sampling 1024 via JsPureMonotonicNs single source
  if ADeadlineNs = 0 then Exit(False);
  Inc(ACounter);
  if (ACounter and 1023) <> 0 then Exit(False);
  ALastNs := JsPureMonotonicNs;
  Result := QWord(ALastNs) >= QWord(ADeadlineNs);
end;
initialization
  // 64B isolated state: GPureClosed 4B compact + 64B pads between NextId/Len/Lock/Free (false-sharing free)
finalization
  SetLength(GPureClosed, 0);
  SetLength(GPureFree, 0);
end.
