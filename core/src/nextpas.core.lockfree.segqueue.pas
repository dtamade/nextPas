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
begin
  { Try to pop from free pool (CAS-based lock-free stack) }
  repeat
    LOldHead := PSegment(AtomicLoadPtr(Pointer(FFreePool), moAcquire));
    if LOldHead = nil then
      Break;
    if AtomicCompareExchangePtr(Pointer(FFreePool),
      Pointer(LOldHead), Pointer(LOldHead^.Next), moAcqRel) = Pointer(LOldHead) then
    begin
      AtomicFetchAdd32(FFreePoolCount, -1, moRelaxed);
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
begin
  LTailSegment := PSegment(AtomicLoadPtr(Pointer(FTail), moAcquire));
  if (LTailSegment <> nil) and (LTailSegment^.StartIndex <= APosition) and
     ((LTailSegment^.StartIndex + SEGQUEUE_SEGMENT_CAPACITY) > APosition) then
    Result := LTailSegment
  else
    Result := PSegment(AtomicLoadPtr(Pointer(FHead), moAcquire));

  while (Result^.StartIndex + SEGQUEUE_SEGMENT_CAPACITY) <= APosition do
  begin
    LNext := PSegment(AtomicLoadPtr(Pointer(Result^.Next), moAcquire));
    if LNext = nil then
    begin
      LNewSegment := AllocSegment(Result^.StartIndex + SEGQUEUE_SEGMENT_CAPACITY);
      if AtomicCompareExchangePtr(Pointer(Result^.Next), nil,
        LNewSegment, moRelease) = nil then
        LNext := LNewSegment
      else
      begin
        FreeMem(LNewSegment, SizeOf(TSegment));
        LNext := PSegment(AtomicLoadPtr(Pointer(Result^.Next), moAcquire));
      end;
    end;
    LockFreePrefetch(LNext);
    AtomicCompareExchangePtr(Pointer(FTail), Result, LNext, moRelease);
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
begin
  LQueue := TSegQueueImpl(AUserData);
  LSeg := PSegment(AData);
  if AtomicLoad32(LQueue.FFreePoolCount, moRelaxed) < SEGQUEUE_FREE_POOL_LIMIT then
  begin
    { Push to free pool using CAS (lock-free stack) }
    repeat
      LOldHead := PSegment(AtomicLoadPtr(Pointer(LQueue.FFreePool), moAcquire));
      LSeg^.Next := LOldHead;
    until AtomicCompareExchangePtr(Pointer(LQueue.FFreePool),
      Pointer(LOldHead), Pointer(LSeg), moAcqRel) = Pointer(LOldHead);
    AtomicFetchAdd32(LQueue.FFreePoolCount, 1, moRelaxed);
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
begin
  LGuard := TEbrGuard.Acquire(FEbr);
  try
    while True do
    begin
      LPos := AtomicLoad64(FEnqueuePos, moRelaxed);
      LSeg := FindOrCreateSegment(LPos);
      if AtomicCompareExchange64(FEnqueuePos, LPos, LPos + 1, moRelaxed) = LPos then
        Break;
    end;

    LIdx := Integer(LPos mod SEGQUEUE_SEGMENT_CAPACITY);
    LSeg^.Slots[LIdx].Value := AValue;
    AtomicStore64(LSeg^.Slots[LIdx].Sequence, LPos + 1, moRelease);
  finally
    LGuard.Release;
  end;
end;

procedure TSegQueueImpl.Enqueue(const AValue: T);
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    raise EInvalidOperationError.Create('TSegQueue: Enqueue on closed queue');
  Publish(AValue);
end;

function TSegQueueImpl.TryEnqueue(const AValue: T): Boolean;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
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
  AtomicStore32(FClosed, 1, moRelease);
end;

function TSegQueueImpl.IsClosed: Boolean; inline;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
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
begin
  while True do
  begin
    LPos := AtomicLoad64(FDequeuePos, moRelaxed);
    LGuard := TEbrGuard.Acquire(FEbr);
    try
      LSeg := PSegment(AtomicLoadPtr(Pointer(FHead), moAcquire));
      while (LSeg <> nil) and ((LSeg^.StartIndex + SEGQUEUE_SEGMENT_CAPACITY) <= LPos) do
      begin
        LOldHead := LSeg;
        LNext := PSegment(AtomicLoadPtr(Pointer(LSeg^.Next), moAcquire));
        if LNext = nil then
        begin
          Result := False;
          Exit;
        end;
        { Prefetch next segment for better cache locality }
        LockFreePrefetch(LNext);
        if AtomicCompareExchangePtr(Pointer(FHead), LOldHead, LNext, moAcqRel) = LOldHead then
        begin
          AtomicCompareExchangePtr(Pointer(FTail), LOldHead, LNext, moRelease);
          FEbr.Retire(LOldHead, @SegQueueReclaimSegment, Self);
          LSeg := LNext;
        end
        else
          LSeg := PSegment(AtomicLoadPtr(Pointer(FHead), moAcquire));
      end;

      if LSeg = nil then
      begin
        Result := False;
        Exit;
      end;

      LIdx := Integer(LPos mod SEGQUEUE_SEGMENT_CAPACITY);
      LSeq := AtomicLoad64(LSeg^.Slots[LIdx].Sequence, moAcquire);
      if LSeq = (LPos + 1) then
      begin
        if AtomicCompareExchange64(FDequeuePos, LPos, LPos + 1, moRelaxed) = LPos then
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
  Result := AtomicLoad64(FEnqueuePos, moRelaxed) <= AtomicLoad64(FDequeuePos, moRelaxed);
end;

function TSegQueueImpl.ApproxCount: PtrUInt;
var
  LEnq: Int64;
  LDeq: Int64;
begin
  LEnq := AtomicLoad64(FEnqueuePos, moRelaxed);
  LDeq := AtomicLoad64(FDequeuePos, moRelaxed);
  if LEnq > LDeq then
    Result := PtrUInt(LEnq - LDeq)
  else
    Result := 0;
end;

end.
