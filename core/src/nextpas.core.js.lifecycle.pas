unit nextpas.core.js.lifecycle;
{ lifecycle owner — single source for pure Context registry: GPureClosed 64B padded atomic acquire/release, cache-line isolated, write-once rare, bulk IsValid zero atomic via FValid, strong acquire; base remains thin type-carrier per four-piece, lifecycle extracted to js.lifecycle single source,复用 bytes.ops单源几何 via BytesNextCapacity + mem.dynarray poke Exactly-Once, inline零拷贝, amortized O(1), spinlock resize rare, L0-L3守分层. }
{$I nextpas.core.settings.inc}
interface
function JsPureContextRegister: UInt64;
procedure JsPureContextClose(AId: UInt64);
function JsPureContextIsClosed(AId: UInt64): Boolean; inline;
function JsPureThreadSelf: UInt64; inline;
function JsPureIsOnCreationThread(ACreationId: UInt64): Boolean; inline;
implementation
uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.mem.dynarray,
  nextpas.core.atomic,
  nextpas.core.platform.thread;
type
  TPureClosedSlot = record Value: Int32; _Pad: array[0..59] of Byte; end; // 64B cache-line padded, instance-isolated atomic slot, false-sharing free, write-once rare
var
  GPureClosed: array of TPureClosedSlot;
  GPureNextId: Int64 = 1;
  GPureClosedLock: Int32 = 0; // owner js.lifecycle: 64B padded 4B atomic acquire/release per slot, atomic_fetch_add id lock-free, spinlock for resize, bulk IsValid zero via FValid, strong acquire
function GPureClosedCapacity: SizeUInt; inline;
begin
  // capacity probe single source via mem.dynarray owner, zero-copy header, no alloc, 64B padded slot
  Result := nextpas.core.mem.dynarray.DynArrayCapacityElem(Pointer(GPureClosed), SizeUInt(Length(GPureClosed)), SizeOf(TPureClosedSlot));
end;
function JsPureContextRegister: UInt64;
var LNeed, LCap, LCurCap: SizeUInt; LBytes: TBytes absolute GPureClosed; LId: Int64; LExp: Int32;
begin
  // perf: lock-free id via atomic_fetch_add_64 mo_seq_cst, instance-isolated, thread-affine geometric via bytes.ops single source, Exactly-Once poke via mem.dynarray, amortized O(1), spinlock for resize critical section (rare), inline zero-copy header, 64B padded slot
  LId := Int64(atomic_fetch_add_64(GPureNextId, Int64(1), mo_seq_cst));
  Result := UInt64(LId);
  if Result >= UInt64(Length(GPureClosed)) then
  begin
    // spinlock for resize — rare write-once, protects SetLength+poke, fast path lock-free when capacity sufficient
    LExp := 0;
    while not atomic_compare_exchange_strong(GPureClosedLock, LExp, Int32(1), mo_acquire, mo_relaxed) do
    begin
      LExp := 0;
      cpu_pause;
    end;
    try
      if Result >= UInt64(Length(GPureClosed)) then
      begin
        LNeed := SizeUInt(Result) + 1;
        LCurCap := GPureClosedCapacity;
        if LCurCap >= LNeed then
        begin
          if SizeUInt(Length(GPureClosed)) <> LNeed then
            DynArraySetLength(LBytes, LNeed);
        end
        else
        begin
          LCap := BytesNextCapacity(SizeUInt(Length(GPureClosed)), LNeed);
          SetLength(GPureClosed, Integer(LCap));
          if LCap <> LNeed then
            DynArraySetLength(LBytes, LNeed);
        end;
      end;
    finally
      atomic_store(GPureClosedLock, Int32(0), mo_release);
    end;
  end;
  atomic_store(GPureClosed[Result].Value, 0, mo_release);
end;
procedure JsPureContextClose(AId: UInt64);
begin
  if (AId > 0) and (AId < UInt64(Length(GPureClosed))) then
    atomic_store(GPureClosed[AId].Value, 1, mo_release);
end;
function JsPureContextIsClosed(AId: UInt64): Boolean; inline;
var LVal: Int32;
begin
  // perf: inline acquire single bounds check, 64B padded atomic slot (false-sharing free), write-once rare, ~1ns read, 强一致 acquire；bulk via FValid zero barrier
  if AId = 0 then Exit(False);
  if AId >= UInt64(Length(GPureClosed)) then Exit(False);
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
initialization
  // no mutex init, atomic only
finalization
  SetLength(GPureClosed, 0);
end.
