unit nextpas.core.lockfree.msqueue;

{ Preferred atomics: atomic_* + mo_* (Go/Rust parity / Q2). }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base;

type
  TLockFreeMsQueueResult = (
    msqOk,
    msqClosed,
    msqEmpty
  );

const
  { Resize-guard stripes: threads hash onto separate counter lines so the
    per-op Enter/Leave RMW pair stays uncontended; Grow scans them all. }
  MSQUEUE_OP_STRIPES = 8; { power of 2 }

type
  { One resize-guard counter per stripe. The trailing full-line pad keeps
    consecutive Count fields >= 64B apart, so no two stripes can share a
    cache line at any heap placement phase (same argument as TCacheLinePad). }
  TMsQueueOpStripe = record
    Count: Int32;
    Pad: TCacheLinePad;
  end;

  {** @desc Michael-Scott 无锁无界 MPMC 队列
    @details 经典无锁队列算法，使用 index-based 节点池。
      - 入队: CAS 更新 tail.next，然后 CAS 移动 tail 指针
      - 出队: CAS 更新 head 指针到 head.next
      - Sentinel 节点简化空队列边界处理
      - 支持 Close 语义
      - 节点池自动扩容
      - 生命周期: Close → join producers/consumers → Free
      - Destroy 会 Close；Free 前必须 quiescent（无并发出入队）
 * @concurrency Thread-safe (see source for details).
  }
  generic TLockFreeMsQueueImpl<T> = class
  private
    type TNode = record
        FValue: T;
        FHasValue: Boolean;
        FNext: Int64;  // packed (index:32 | tag:32), index=-1 means nil
      end;
    type
      TFreeNode = record
        FNext: Int32;
      end;
  private
    { Read-mostly header: node/freelist refs + capacity, read on every op;
      padded off the hot RMW lines below (F-032 rule). }
    FNodes: array of TNode;
    FFreeList: array of TFreeNode;
    FCapacity: Int32;
    {$PUSH} {$WARN 05029 OFF} // padding field for cache-line isolation
    FPadHeader: TCacheLinePad;
    {$POP}
    // Producer line: tail pointer + enqueued counter, both RMW'd by every
    // successful enqueue (same writer population, F-033 rule).
    FTail: Int64;        // packed: (index:32 | aba:32)
    FEnqueued: Int64;
    {$PUSH} {$WARN 05029 OFF} // padding field for cache-line isolation
    FPadTail: TCacheLinePad;
    {$POP}
    // Consumer line (mirror): head pointer + dequeued counter.
    FHead: Int64;        // packed: (index:32 | aba:32)
    FDequeued: Int64;
    {$PUSH} {$WARN 05029 OFF} // padding field for cache-line isolation
    FPadHead: TCacheLinePad;
    {$POP}
    // Free-list head is CAS'd by BOTH sides every op (alloc on enqueue,
    // recycle on dequeue) — it cannot join either side's line, so it gets
    // its own.
    FFreeHead: Int64;   // packed: (index:32 | aba:32)
    {$PUSH} {$WARN 05029 OFF} // padding field for cache-line isolation
    FPadFree: TCacheLinePad;
    {$POP}
    // Resize guard striped by thread-id hash so the per-op Enter/Leave RMW
    // pair lands on an uncontended line (each stripe self-padded, F-037).
    FOpStripes: array[0..MSQUEUE_OP_STRIPES - 1] of TMsQueueOpStripe;
    // Cold tail: FResizing flips only during Grow, FClosed once at Close.
    FResizing: Int32;
    FClosed: Int32;

    function TryAllocNodeIdx(out AIdx: Int32): Boolean;
    procedure FreeNodeIdx(AIdx: Int32);
    function Pack(AIdx, ATag: Int32): Int64;
    function UnpackIdx(APacked: Int64): Int32;
    function UnpackTag(APacked: Int64): Int32;
    class function OpStripeIndex: PtrUInt; static; inline;
    procedure EnterOperation(const AStripe: PtrUInt); inline;
    procedure LeaveOperation(const AStripe: PtrUInt); inline;
    procedure Grow;
  public
    constructor Create(ACapacity: Int32 = 64);
    destructor Destroy; override;

    {** 入队（无界队列，自动扩容） }
    function TryEnqueue(const AValue: T): Boolean;
    {** 入队 + 诊断码（H2-1 / A1）。无界：失败 publish 在正常路径上为 lfteClosed。 }
    function TryEnqueueEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
    {** 出队 }
    function TryDequeue(out AValue: T): Boolean;
    {** 出队 + 诊断码。空且未 closed → lfteEmpty；closed 且空 → lfteClosed。 }
    function TryDequeueEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
    function Drain(const AMaxCount: PtrUInt = High(PtrUInt)): PtrUInt;
    {** 关闭队列 }
    procedure Close;
    {** 队列是否已关闭 }
    function IsClosed: Boolean;
    {** 大致数量 }
    function ApproxCount: Int64;
    {** 是否为空 }
    function IsEmpty: Boolean;
  end;

implementation

uses
  nextpas.core.mem,
  nextpas.core.errors;

function TLockFreeMsQueueImpl.Pack(AIdx, ATag: Int32): Int64;
begin
  Result := (Int64(ATag) shl 32) or Int64(UInt32(AIdx));
end;

function TLockFreeMsQueueImpl.UnpackIdx(APacked: Int64): Int32;
begin
  Result := Int32(UInt32(APacked and $FFFFFFFF));
end;

function TLockFreeMsQueueImpl.UnpackTag(APacked: Int64): Int32;
begin
  Result := Int32(APacked shr 32);
end;

function TLockFreeMsQueueImpl.TryAllocNodeIdx(out AIdx: Int32): Boolean;
var
  LOld, LNew: Int64;
  LIdx: Int32;
  LExpected: Int64;
begin
  repeat
    LOld := atomic_load_64(FFreeHead, mo_acquire);
    LIdx := UnpackIdx(LOld);
    if LIdx < 0 then
      Exit(False);
    LNew := Pack(FFreeList[LIdx].FNext, UnpackTag(LOld) + 1);
  LExpected := LOld;
  until atomic_compare_exchange_strong_64(FFreeHead, LExpected, LNew, mo_acq_rel, mo_acquire);
  FNodes[LIdx].FHasValue := False;
  AIdx := LIdx;
  Result := True;
end;

procedure TLockFreeMsQueueImpl.FreeNodeIdx(AIdx: Int32);
var
  LOld, LNew: Int64;
  LExpected: Int64;
begin
  FNodes[AIdx].FHasValue := False;
  repeat
    LOld := atomic_load_64(FFreeHead, mo_relaxed);
    FFreeList[AIdx].FNext := UnpackIdx(LOld);
    LNew := Pack(AIdx, UnpackTag(LOld) + 1);
  LExpected := LOld;
  until atomic_compare_exchange_strong_64(FFreeHead, LExpected, LNew, mo_acq_rel, mo_acquire);
end;

{$PUSH} {$Q-} {$R-} { hash multiply wraps mod 2^N by design }
class function TLockFreeMsQueueImpl.OpStripeIndex: PtrUInt;
begin
  { Thread ids on Linux are pthread descriptor addresses, often exactly 8MB
    apart (stack-top allocation) — a bare shift would collide systematically.
    Multiplying by an odd constant is a bijection mod 2^N and spreads any
    fixed stride across the high bits; take bits 24.. for the stripe. }
  Result := (PtrUInt(GetCurrentThreadId) * PtrUInt($9E3779B9)) shr 24
    and (MSQUEUE_OP_STRIPES - 1);
end;
{$POP}

procedure TLockFreeMsQueueImpl.EnterOperation(const AStripe: PtrUInt);
begin
  while True do
  begin
    while atomic_load(FResizing, mo_acquire) <> 0 do
      CpuPause;
    atomic_fetch_add(FOpStripes[AStripe].Count, 1, mo_acq_rel);
    if atomic_load(FResizing, mo_acquire) = 0 then
      Exit;
    atomic_fetch_sub(FOpStripes[AStripe].Count, 1, mo_acq_rel);
  end;
end;

procedure TLockFreeMsQueueImpl.LeaveOperation(const AStripe: PtrUInt);
begin
  atomic_fetch_sub(FOpStripes[AStripe].Count, 1, mo_acq_rel);
end;

procedure TLockFreeMsQueueImpl.Grow;
var
  LI: Int32;
  LOldCap: Int32;
  LNewCap: Int32;
  LOldFree: Int64;
  LNewFree: Int64;
  LNewNodes: array of TNode;
  LNewFreeList: array of TFreeNode;
  LResizeExpected: Int32;
begin
  LResizeExpected := 0;
  if not atomic_compare_exchange_strong(FResizing, LResizeExpected, 1, mo_acq_rel, mo_acquire) then
  begin
    while atomic_load(FResizing, mo_acquire) <> 0 do
      CpuPause;
    Exit;
  end;
  try
    { Quiescence: FResizing=1 is published, so EnterOperation cannot admit
      new operations (it re-checks and backs out); each stripe drains to 0.
      Same argument as the single counter, applied per stripe. }
    for LI := 0 to MSQUEUE_OP_STRIPES - 1 do
      while atomic_load(FOpStripes[LI].Count, mo_acquire) <> 0 do
        CpuPause;
    LOldFree := atomic_load_64(FFreeHead, mo_acquire);
    if UnpackIdx(LOldFree) >= 0 then
      Exit;

    LOldCap := atomic_load(FCapacity, mo_relaxed);
    if (LOldCap > High(Int32) div 2) or
       (LOldCap > (MaxInt div SizeOf(TNode)) div 2) or
       (LOldCap > (MaxInt div SizeOf(TFreeNode)) div 2) then
      raise EOutOfMemoryError.Create(FormatAllocErrorMsg('LockFree', 'Grow', 'TLockFreeMsQueue.Grow: capacity overflow'));
    LNewCap := LOldCap * 2;

    SetLength(LNewNodes, LNewCap);
    SetLength(LNewFreeList, LNewCap);
    Move(FNodes[0], LNewNodes[0], LOldCap * SizeOf(TNode));
    Move(FFreeList[0], LNewFreeList[0], LOldCap * SizeOf(TFreeNode));
    for LI := LOldCap to LNewCap - 1 do
    begin
      LNewNodes[LI].FHasValue := False;
      LNewNodes[LI].FNext := Pack(-1, 0);
      if LI < LNewCap - 1 then
        LNewFreeList[LI].FNext := LI + 1
      else
        LNewFreeList[LI].FNext := UnpackIdx(LOldFree);
    end;

    LNewFree := Pack(LOldCap, UnpackTag(LOldFree) + 1);
    FNodes := LNewNodes;
    FFreeList := LNewFreeList;
    atomic_store(FCapacity, LNewCap, mo_relaxed);
    atomic_store_64(FFreeHead, LNewFree, mo_release);
  finally
    atomic_store(FResizing, 0, mo_release);
  end;
end;

constructor TLockFreeMsQueueImpl.Create(ACapacity: Int32);
var
  I, LSentinel: Int32;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TLockFreeMsQueue: T must be unmanaged');
  if ACapacity < 4 then
    ACapacity := 4;
  if (ACapacity > MaxInt div SizeOf(TNode)) or
     (ACapacity > MaxInt div SizeOf(TFreeNode)) then
    raise EArgumentError.Create('TLockFreeMsQueue: capacity exceeds allocation limit');
  inherited Create;
  SetLength(FNodes, ACapacity);
  SetLength(FFreeList, ACapacity);
  for I := 0 to ACapacity - 2 do
    FFreeList[I].FNext := I + 1;
  FFreeList[ACapacity - 1].FNext := -1;
  FCapacity := ACapacity;
  FFreeHead := Pack(0, 0);
  for I := 0 to MSQUEUE_OP_STRIPES - 1 do
    FOpStripes[I].Count := 0;
  FResizing := 0;
  if not TryAllocNodeIdx(LSentinel) then
    raise EOutOfMemoryError.Create(FormatAllocErrorMsg('LockFree', 'Grow', 'TLockFreeMsQueue: sentinel allocation failed'));
  FNodes[LSentinel].FHasValue := False;
  FNodes[LSentinel].FNext := Pack(-1, 0);
  FHead := Pack(LSentinel, 0);
  FTail := Pack(LSentinel, 0);
  FEnqueued := 0;
  FDequeued := 0;
  FClosed := 0;
end;

destructor TLockFreeMsQueueImpl.Destroy;
var
  LV: T;
begin
  { Failed construction (e.g. managed-type reject before node storage init)
    leaves FNodes empty. Drain would index FNodes[head] and AV. }
  if Length(FNodes) = 0 then
  begin
    inherited Destroy;
    Exit;
  end;
  { Reject new publishes; drain remaining values while quiescent.
    Callers must still join concurrent producers/consumers before Free. }
  Close;
  while TryDequeue(LV) do;
  SetLength(FNodes, 0);
  SetLength(FFreeList, 0);
  inherited Destroy;
end;

function TLockFreeMsQueueImpl.TryEnqueue(const AValue: T): Boolean;
var
  LNodeIdx, LTailIdx, LNextIdx: Int32;
  LOldTail, LOldNext, LNewTail, LNewNext: Int64;
  LExpected: Int64;
  LStripe: PtrUInt;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  { Stripe computed ONCE and passed to the paired Enter/Leave: recomputing
    could decrement a different stripe and let Grow see false quiescence. }
  LStripe := OpStripeIndex;
  while True do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(False);
    EnterOperation(LStripe);
    if TryAllocNodeIdx(LNodeIdx) then
      Break;
    LeaveOperation(LStripe);
    Grow;
  end;
  try
    FNodes[LNodeIdx].FValue := AValue;
    FNodes[LNodeIdx].FHasValue := True;
    FNodes[LNodeIdx].FNext := Pack(-1, 0);
    while True do
    begin
      LOldTail := atomic_load_64(FTail, mo_acquire);
      LTailIdx := UnpackIdx(LOldTail);
      LOldNext := atomic_load_64(FNodes[LTailIdx].FNext, mo_acquire);
      LNextIdx := UnpackIdx(LOldNext);
      if LOldTail = atomic_load_64(FTail, mo_acquire) then
      begin
        if LNextIdx < 0 then
        begin
          LNewNext := Pack(LNodeIdx, UnpackTag(LOldNext) + 1);
          LExpected := LOldNext;
          if atomic_compare_exchange_strong_64(FNodes[LTailIdx].FNext, LExpected, LNewNext, mo_acq_rel, mo_acquire) then
          begin
            LNewTail := Pack(LNodeIdx, UnpackTag(LOldTail) + 1);
            LExpected := LOldTail;
            atomic_compare_exchange_strong_64(FTail, LExpected, LNewTail, mo_acq_rel, mo_acquire);
            { Diagnostic counter only (ApproxCount): relaxed is enough, no
              algorithm invariant orders on it (F-040 rationale). }
            atomic_fetch_add_64(FEnqueued, 1, mo_relaxed);
            Exit(True);
          end;
        end
        else
        begin
          LNewTail := Pack(LNextIdx, UnpackTag(LOldTail) + 1);
          LExpected := LOldTail;
            atomic_compare_exchange_strong_64(FTail, LExpected, LNewTail, mo_acq_rel, mo_acquire);
        end;
      end;
    end;
  finally
    LeaveOperation(LStripe);
  end;
end;

function TLockFreeMsQueueImpl.TryEnqueueEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
begin
  if TryEnqueue(AValue) then
  begin
    AError := lfteNone;
    Exit(True);
  end;
  { Unbounded: False is closed under ClosedPublishPolicy (CONTRACT §1.3/§1.4). }
  if IsClosed then
    AError := lfteClosed
  else
    AError := lfteFull;
  Result := False;
end;

function TLockFreeMsQueueImpl.TryDequeue(out AValue: T): Boolean;
var
  LHeadIdx, LTailIdx, LNextIdx: Int32;
  LOldHead, LOldTail, LNewHead: Int64;
  LOldNext: Int64;
  LCandidateValue: T;
  LHasCandidate: Boolean;
  LExpected: Int64;
  LStripe: PtrUInt;
begin
  Result := False;
  LStripe := OpStripeIndex;
  EnterOperation(LStripe);
  try
    while True do
    begin
      LOldHead := atomic_load_64(FHead, mo_acquire);
      LHeadIdx := UnpackIdx(LOldHead);
      LOldTail := atomic_load_64(FTail, mo_acquire);
      LTailIdx := UnpackIdx(LOldTail);
      LOldNext := atomic_load_64(FNodes[LHeadIdx].FNext, mo_acquire);
      LNextIdx := UnpackIdx(LOldNext);
      if LOldHead = atomic_load_64(FHead, mo_acquire) then
      begin
        if LHeadIdx = LTailIdx then
        begin
          if LNextIdx < 0 then
            Exit(False);
          LNewHead := Pack(LNextIdx, UnpackTag(LOldTail) + 1);
          LExpected := LOldTail;
          atomic_compare_exchange_strong_64(FTail, LExpected, LNewHead, mo_acq_rel, mo_acquire);
        end
        else
        begin
          LHasCandidate := FNodes[LNextIdx].FHasValue;
          if LHasCandidate then
            LCandidateValue := FNodes[LNextIdx].FValue;
          LNewHead := Pack(LNextIdx, UnpackTag(LOldHead) + 1);
          LExpected := LOldHead;
          if atomic_compare_exchange_strong_64(FHead, LExpected, LNewHead, mo_acq_rel, mo_acquire) then
          begin
            if LHasCandidate then
            begin
              AValue := LCandidateValue;
              Result := True;
            end;
            FreeNodeIdx(LHeadIdx);
            atomic_fetch_add_64(FDequeued, 1, mo_relaxed);
            Exit;
          end;
        end;
      end;
    end;
  finally
    LeaveOperation(LStripe);
  end;
end;

function TLockFreeMsQueueImpl.TryDequeueEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
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

function TLockFreeMsQueueImpl.Drain(const AMaxCount: PtrUInt): PtrUInt;
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

procedure TLockFreeMsQueueImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TLockFreeMsQueueImpl.IsClosed: Boolean;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TLockFreeMsQueueImpl.ApproxCount: Int64;
var
  LEnq, LDeq: Int64;
begin
  { Read FDequeued first (acquire): FEnqueued read afterwards is at least as
    fresh, so the difference is biased toward overstating count — the
    conservative direction for callers polling for drain (F-038 argument).
    The clamp also covers the pre-existing transient window where a consumer
    counts its dequeue before the producer counts the matching enqueue (the
    old single FCount could momentarily read negative there). }
  LDeq := atomic_load_64(FDequeued, mo_acquire);
  LEnq := atomic_load_64(FEnqueued, mo_relaxed);
  if LEnq > LDeq then
    Result := LEnq - LDeq
  else
    Result := 0;
end;

function TLockFreeMsQueueImpl.IsEmpty: Boolean;
var
  LHeadIdx, LTailIdx, LNextIdx: Int32;
  LOldHead, LOldTail, LOldNext: Int64;
  LStripe: PtrUInt;
begin
  LStripe := OpStripeIndex;
  EnterOperation(LStripe);
  try
    LOldHead := atomic_load_64(FHead, mo_acquire);
    LHeadIdx := UnpackIdx(LOldHead);
    LOldTail := atomic_load_64(FTail, mo_acquire);
    LTailIdx := UnpackIdx(LOldTail);
    LOldNext := atomic_load_64(FNodes[LHeadIdx].FNext, mo_acquire);
    LNextIdx := UnpackIdx(LOldNext);
    Result := (LHeadIdx = LTailIdx) and (LNextIdx < 0);
  finally
    LeaveOperation(LStripe);
  end;
end;

end.
