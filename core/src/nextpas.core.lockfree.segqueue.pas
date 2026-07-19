unit nextpas.core.lockfree.segqueue;
{**
 * @desc Lock-free unbounded MPMC queue using linked segments.
 *
 * @details Segment-based queue with dynamic growth:
 *   - Unbounded capacity (grows by allocating segments)
 *   - Non-blocking TryEnqueue/TryDequeue
 *   - Blocking Enqueue with segment allocation
 *   - Close semantics with drain support
 *   - EBR-based memory reclamation for safe segment deallocation
 *
 * @concurrency Thread-safe for multiple producers and consumers:
 *   - Enqueue: producers compete for slots via CAS
 *   - Dequeue: consumers compete for data via CAS
 *   - Close: safe to call from any thread
 *
 * @see Michael & Scott queue — classic lock-free queue design
 * @see Segment-based queues — cache-friendly unbounded queue
 *
 * Preferred atomics: atomic_* + mo_* (Go/Rust parity / Q2).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.base,
  nextpas.core.lockfree.ebr;

const
  SEGQUEUE_SEGMENT_CAPACITY = 32;
  SEGQUEUE_FREE_POOL_LIMIT = 8;

type
  generic TSegQueueImpl<T> = class
  private type
    TSegSlot = record
      Sequence: Int64;
      Value: T;
    end;

    PSegment = ^TSegment;
    TSegment = record
      Next: PSegment;
      StartIndex: Int64;
      Slots: array[0..SEGQUEUE_SEGMENT_CAPACITY - 1] of TSegSlot;
    end;
  private
    FHead: PSegment;
    {$PUSH} {$WARN 05029 OFF}
    FPadHead: TCacheLinePad;
    {$POP}
    FTail: PSegment;
    {$PUSH} {$WARN 05029 OFF}
    FPadTail: TCacheLinePad;
    {$POP}
    FEnqueuePos: Int64;
    {$PUSH} {$WARN 05029 OFF}
    FPadEnqueue: TCacheLinePad;
    {$POP}
    FDequeuePos: Int64;
    {$PUSH} {$WARN 05029 OFF}
    FPadDequeue: TCacheLinePad;
    {$POP}
    FFreePool: PSegment;
    FFreePoolCount: Integer;
    FClosed: Int32;
    FEbr: TEbrDomain;
    class procedure SegQueueReclaimSegment(const AData: Pointer; const AUserData: Pointer); static;
    function AllocSegment(const AStartIndex: Int64): PSegment;
    function FindOrCreateSegment(const APosition: Int64): PSegment;
    procedure Publish(const AValue: T);
  public
    {** @desc 创建无界 MPMC 分段队列（EBR 回收段） }
    constructor Create;
    destructor Destroy; override;
    {** @desc 无界入队；段不足时自动扩展；已关闭时抛 EInvalidOperationError }
    procedure Enqueue(const AValue: T);
    {** @desc 非阻塞入队；已关闭时返回 False }
    function TryEnqueue(const AValue: T): Boolean;
    {** @desc 非阻塞入队并返回失败原因；成功 AError=lfteNone }
    function TryEnqueueEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
    {** @desc 非阻塞出队；队列空时返回 False }
    function TryDequeue(out AValue: T): Boolean;
    {** @desc 非阻塞出队并返回失败原因；empty vs closed-empty }
    function TryDequeueEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
    function Drain(const AMaxCount: PtrUInt = High(PtrUInt)): PtrUInt;
    {** @desc 关闭队列（已入队数据仍可读出） }
    procedure Close;
    {** @desc 队列是否已关闭 }
    function IsClosed: Boolean; inline;
    {** @desc 近似空判断 }
    function IsEmpty: Boolean;
    {** @desc 近似计数 }
    function ApproxCount: PtrUInt;
  end;

  generic TSegQueue<T> = class(specialize TSegQueueImpl<T>)
  end;

implementation

function TSegQueueImpl.AllocSegment(const AStartIndex: Int64): PSegment;
var
  LI: Integer;
  LOldHead: PSegment;
  LExpected: Pointer;
begin
  { Try to pop from free pool (CAS-based lock-free stack) }
  repeat
    LOldHead := PSegment(atomic_load(Pointer(FFreePool), mo_acquire));
    if LOldHead = nil then
      Break;
    LExpected := Pointer(LOldHead);
    if atomic_compare_exchange_strong(Pointer(FFreePool), LExpected, Pointer(LOldHead^.Next), mo_acq_rel, mo_acquire) then
    begin
      atomic_fetch_add(FFreePoolCount, -1, mo_relaxed);
      LOldHead^.Next := nil;
      LOldHead^.StartIndex := AStartIndex;
      for LI := 0 to SEGQUEUE_SEGMENT_CAPACITY - 1 do
        LOldHead^.Slots[LI].Sequence := AStartIndex + LI;
      Exit(LOldHead);
    end;
  until False;

  { Allocate new segment }
  Result := GetMem(SizeOf(TSegment));
  FillChar(Result^, SizeOf(TSegment), 0);
  Result^.StartIndex := AStartIndex;
  for LI := 0 to SEGQUEUE_SEGMENT_CAPACITY - 1 do
    Result^.Slots[LI].Sequence := AStartIndex + LI;
end;

function TSegQueueImpl.FindOrCreateSegment(const APosition: Int64): PSegment;
var
  LNext: PSegment;
  LNewSegment: PSegment;
  LTailSegment: PSegment;
  LExpected: Pointer;
begin
  LTailSegment := PSegment(atomic_load(Pointer(FTail), mo_acquire));
  if (LTailSegment <> nil) and (LTailSegment^.StartIndex <= APosition) and
     ((LTailSegment^.StartIndex + SEGQUEUE_SEGMENT_CAPACITY) > APosition) then
    Result := LTailSegment
  else
    Result := PSegment(atomic_load(Pointer(FHead), mo_acquire));

  while (Result^.StartIndex + SEGQUEUE_SEGMENT_CAPACITY) <= APosition do
  begin
    LNext := PSegment(atomic_load(Pointer(Result^.Next), mo_acquire));
    if LNext = nil then
    begin
      LNewSegment := AllocSegment(Result^.StartIndex + SEGQUEUE_SEGMENT_CAPACITY);
      LExpected := nil;
      if atomic_compare_exchange_strong(Pointer(Result^.Next), LExpected, Pointer(LNewSegment), mo_release, mo_relaxed) then
        LNext := LNewSegment
      else
      begin
        FreeMem(LNewSegment, SizeOf(TSegment));
        LNext := PSegment(atomic_load(Pointer(Result^.Next), mo_acquire));
      end;
    end;
    LockFreePrefetch(LNext);
    LExpected := Pointer(Result);
    atomic_compare_exchange_strong(Pointer(FTail), LExpected, Pointer(LNext), mo_release, mo_relaxed);
    Result := LNext;
  end;
end;

constructor TSegQueueImpl.Create;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TSegQueue: T must be unmanaged');
  inherited Create;
  FEbr := TEbrDomain.Create;
  FHead := AllocSegment(0);
  FTail := FHead;
  FEnqueuePos := 0;
  FDequeuePos := 0;
  FFreePool := nil;
  FFreePoolCount := 0;
  FClosed := 0;
end;

destructor TSegQueueImpl.Destroy;
var
  LSeg: PSegment;
  LNext: PSegment;
begin
  { Close rejects new publishes; callers must still join concurrent
    producers/consumers before Free. }
  Close;
  { Release EBR first: its destructor calls SegQueueReclaimSegment for
    retired segments, which pushes them back into FFreePool. }
  FEbr.Free;
  LSeg := FHead;
  while LSeg <> nil do
  begin
    LNext := LSeg^.Next;
    FreeMem(LSeg, SizeOf(TSegment));
    LSeg := LNext;
  end;
  LSeg := FFreePool;
  while LSeg <> nil do
  begin
    LNext := LSeg^.Next;
    FreeMem(LSeg, SizeOf(TSegment));
    LSeg := LNext;
  end;
  inherited;
end;

class procedure TSegQueueImpl.SegQueueReclaimSegment(const AData: Pointer; const AUserData: Pointer);
var
  LSeg: PSegment;
  LQueue: TSegQueueImpl;
  LOldHead: PSegment;
  LExpected: Pointer;
begin
  LQueue := TSegQueueImpl(AUserData);
  LSeg := PSegment(AData);
  if atomic_load(LQueue.FFreePoolCount, mo_relaxed) < SEGQUEUE_FREE_POOL_LIMIT then
  begin
    { Push to free pool using CAS (lock-free stack) }
    repeat
      LOldHead := PSegment(atomic_load(Pointer(LQueue.FFreePool), mo_acquire));
      LSeg^.Next := LOldHead;
    LExpected := Pointer(LOldHead);
    until atomic_compare_exchange_strong(Pointer(LQueue.FFreePool), LExpected, Pointer(LSeg), mo_acq_rel, mo_acquire);
    atomic_fetch_add(LQueue.FFreePoolCount, 1, mo_relaxed);
  end
  else
    FreeMem(AData, SizeOf(TSegment));
end;

procedure TSegQueueImpl.Publish(const AValue: T);
var
  LPos: Int64;
  LIdx: Integer;
  LSeg: PSegment;
  LGuard: TEbrGuard;
  LPosExpected: Int64;
begin
  LGuard := TEbrGuard.Acquire(FEbr);
  try
    while True do
    begin
      LPos := atomic_load_64(FEnqueuePos, mo_relaxed);
      LSeg := FindOrCreateSegment(LPos);
      LPosExpected := LPos;
      if atomic_compare_exchange_strong_64(FEnqueuePos, LPosExpected, LPos + 1, mo_relaxed, mo_relaxed) then
        Break;
    end;

    LIdx := Integer(LPos mod SEGQUEUE_SEGMENT_CAPACITY);
    LSeg^.Slots[LIdx].Value := AValue;
    atomic_store_64(LSeg^.Slots[LIdx].Sequence, LPos + 1, mo_release);
  finally
    LGuard.Release;
  end;
end;

procedure TSegQueueImpl.Enqueue(const AValue: T);
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    raise EInvalidOperationError.Create('TSegQueue: Enqueue on closed queue');
  Publish(AValue);
end;

function TSegQueueImpl.TryEnqueue(const AValue: T): Boolean;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  Publish(AValue);
  Result := True;
end;

function TSegQueueImpl.TryEnqueueEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
begin
  if TryEnqueue(AValue) then
  begin
    AError := lfteNone;
    Exit(True);
  end;
  { Unbounded: False is closed under ClosedPublishPolicy. }
  if IsClosed then
    AError := lfteClosed
  else
    AError := lfteFull;
  Result := False;
end;

function TSegQueueImpl.Drain(const AMaxCount: PtrUInt): PtrUInt;
var
  LValue: T;
  LCount: PtrUInt;
begin
  LCount := 0;
  while LCount < AMaxCount do
  begin
    if not TryDequeue(LValue) then
      Break;
    Inc(LCount);
  end;
  Result := LCount;
end;

procedure TSegQueueImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TSegQueueImpl.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TSegQueueImpl.TryDequeue(out AValue: T): Boolean;
var
  LPos: Int64;
  LIdx: Integer;
  LSeg: PSegment;
  LNext: PSegment;
  LOldHead: PSegment;
  LSeq: Int64;
  LGuard: TEbrGuard;
  LExpected: Pointer;
  LPosExpected: Int64;
begin
  while True do
  begin
    LPos := atomic_load_64(FDequeuePos, mo_relaxed);
    LGuard := TEbrGuard.Acquire(FEbr);
    try
      LSeg := PSegment(atomic_load(Pointer(FHead), mo_acquire));
      while (LSeg <> nil) and ((LSeg^.StartIndex + SEGQUEUE_SEGMENT_CAPACITY) <= LPos) do
      begin
        LOldHead := LSeg;
        LNext := PSegment(atomic_load(Pointer(LSeg^.Next), mo_acquire));
        if LNext = nil then
        begin
          Result := False;
          Exit;
        end;
        { Prefetch next segment for better cache locality }
        LockFreePrefetch(LNext);
        LExpected := Pointer(LOldHead);
        if atomic_compare_exchange_strong(Pointer(FHead), LExpected, Pointer(LNext), mo_acq_rel, mo_acquire) then
        begin
          LExpected := Pointer(LOldHead);
          atomic_compare_exchange_strong(Pointer(FTail), LExpected, Pointer(LNext), mo_release, mo_relaxed);
          FEbr.Retire(LOldHead, @SegQueueReclaimSegment, Self);
          LSeg := LNext;
        end
        else
          LSeg := PSegment(atomic_load(Pointer(FHead), mo_acquire));
      end;

      if LSeg = nil then
      begin
        Result := False;
        Exit;
      end;

      LIdx := Integer(LPos mod SEGQUEUE_SEGMENT_CAPACITY);
      LSeq := atomic_load_64(LSeg^.Slots[LIdx].Sequence, mo_acquire);
      if LSeq = (LPos + 1) then
      begin
        LPosExpected := LPos;
        if atomic_compare_exchange_strong_64(FDequeuePos, LPosExpected, LPos + 1, mo_relaxed, mo_relaxed) then
        begin
          AValue := LSeg^.Slots[LIdx].Value;
          LSeg^.Slots[LIdx].Value := Default(T);
          Result := True;
          Exit;
        end;
      end
      else if LSeq < (LPos + 1) then
      begin
        Result := False;
        Exit;
      end;
    finally
      LGuard.Release;
    end;
    CpuPause;
  end;
end;

function TSegQueueImpl.TryDequeueEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
begin
  if TryDequeue(AValue) then
  begin
    AError := lfteNone;
    Exit(True);
  end;
  if IsClosed then
    AError := lfteClosed
  else
    AError := lfteEmpty;
  Result := False;
end;

function TSegQueueImpl.IsEmpty: Boolean;
begin
  Result := atomic_load_64(FEnqueuePos, mo_relaxed) <= atomic_load_64(FDequeuePos, mo_relaxed);
end;

function TSegQueueImpl.ApproxCount: PtrUInt;
var
  LEnq: Int64;
  LDeq: Int64;
begin
  LEnq := atomic_load_64(FEnqueuePos, mo_relaxed);
  LDeq := atomic_load_64(FDequeuePos, mo_relaxed);
  if LEnq > LDeq then
    Result := PtrUInt(LEnq - LDeq)
  else
    Result := 0;
end;

end.
