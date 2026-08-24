unit nextpas.core.lockfree.msqueue;

{ Preferred atomics: atomic_* + mo_* (Go/Rust parity / Q2). }

{$I nextpas.core.settings.inc}

{ 填充字段刻意零引用;5029 Note 在类解析结束后的阶段发射,
  per-field PUSH/POP 窗口先于发射被 POP 还原,压不住 ——
  只能单元级关闭(本单元其余私有字段本就要求显式使用) }
{$WARN 5029 OFF}

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

  { One free-list head per stripe (same self-padding argument). Each Head is
    a packed (index:32 | aba:32) Treiber-stack top with a per-stripe tag. }
  TMsQueueFreeStripe = record
    Head: Int64;
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
  }
  generic TLockFreeMsQueueImpl<T> = class
  private
    { FFreeNext lives inside the node itself (was a separate 4B-element
      array, 16 links/line), so alloc/recycle touch one line, not two
      (F-046). A full-line pad per node was also measured and showed no
      matched-pair signal: the multi-thread cost is CAS contention on
      head/tail, not neighbor-node false sharing — so nodes stay dense. }
    type TNode = record
        FValue: T;
        FHasValue: Boolean;
        FNext: Int64;  // packed (index:32 | tag:32), index=-1 means nil
        FFreeNext: Int32;  // free-chain link, -1 ends the chain
      end;
  private
    { Read-mostly header: node storage ref + capacity, read on every op;
      padded off the hot RMW lines below (F-032 rule). }
    FNodes: array of TNode;
    FCapacity: Int32;
    FPadHeader: TCacheLinePad;   // padding for cache-line isolation
    // Producer line: tail pointer + enqueued counter, both RMW'd by every
    // successful enqueue (same writer population, F-033 rule).
    FTail: Int64;        // packed: (index:32 | aba:32)
    FEnqueued: Int64;
    FPadTail: TCacheLinePad;   // padding for cache-line isolation
    // Consumer line (mirror): head pointer + dequeued counter.
    FHead: Int64;        // packed: (index:32 | aba:32)
    FDequeued: Int64;
    FPadHead: TCacheLinePad;   // padding for cache-line isolation
    // Free list striped by the SAME thread-id hash as the op guard (the
    // caller passes its already-computed op stripe): alloc on enqueue and
    // recycle on dequeue from differently-hashed threads land on separate
    // heads instead of all CAS'ing one word — the measured serial point
    // left after F-041 (Q2 still > Q1). 1P1C limit: one producer + one
    // consumer still drain through a single stripe pair at steady state.
    FFreeStripes: array[0..MSQUEUE_OP_STRIPES - 1] of TMsQueueFreeStripe;
    // Resize guard striped by thread-id hash so the per-op Enter/Leave RMW
    // pair lands on an uncontended line (each stripe self-padded, F-037).
    FOpStripes: array[0..MSQUEUE_OP_STRIPES - 1] of TMsQueueOpStripe;
    // Cold tail: FResizing flips only during Grow, FClosed once at Close.
    FResizing: Int32;
    FClosed: Int32;

    function TryAllocNodeIdx(const AStripe: PtrUInt; out AIdx: Int32): Boolean;
    procedure FreeNodeIdx(AIdx: Int32; const AStripe: PtrUInt);
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

function TLockFreeMsQueueImpl.TryAllocNodeIdx(const AStripe: PtrUInt; out AIdx: Int32): Boolean;
var
  LOld, LNew: Int64;
  LIdx: Int32;
  LExpected: Int64;
  LProbe, LS: PtrUInt;
begin
  { Fast path: the caller's own stripe, peeled into the same single-loop
    shape as the pre-stripe allocator (micro-sensitive hot path). }
  repeat
    LOld := atomic_load_64(FFreeStripes[AStripe].Head, mo_acquire);
    LIdx := UnpackIdx(LOld);
    if LIdx < 0 then
      Break;
    LNew := Pack(FNodes[LIdx].FFreeNext, UnpackTag(LOld) + 1);
    LExpected := LOld;
    if atomic_compare_exchange_strong_64(FFreeStripes[AStripe].Head, LExpected, LNew, mo_acq_rel, mo_acquire) then
    begin
      FNodes[LIdx].FHasValue := False;
      AIdx := LIdx;
      Exit(True);
    end;
  until False;
  { Slow path: own stripe empty — probe the others (a node recycled by a
    differently-hashed thread sits on THAT stripe). A CAS failure retries
    the SAME stripe; only an observed empty moves on. A stripe-local miss
    is not a capacity miss: only all-empty may report False (→ Grow). }
  for LProbe := 1 to MSQUEUE_OP_STRIPES - 1 do
  begin
    LS := (AStripe + LProbe) and (MSQUEUE_OP_STRIPES - 1);
    while True do
    begin
      LOld := atomic_load_64(FFreeStripes[LS].Head, mo_acquire);
      LIdx := UnpackIdx(LOld);
      if LIdx < 0 then
        Break;
      LNew := Pack(FNodes[LIdx].FFreeNext, UnpackTag(LOld) + 1);
      LExpected := LOld;
      if atomic_compare_exchange_strong_64(FFreeStripes[LS].Head, LExpected, LNew, mo_acq_rel, mo_acquire) then
      begin
        FNodes[LIdx].FHasValue := False;
        AIdx := LIdx;
        Exit(True);
      end;
    end;
  end;
  Result := False;
end;

procedure TLockFreeMsQueueImpl.FreeNodeIdx(AIdx: Int32; const AStripe: PtrUInt);
var
  LOld, LNew: Int64;
  LExpected: Int64;
begin
  FNodes[AIdx].FHasValue := False;
  repeat
    LOld := atomic_load_64(FFreeStripes[AStripe].Head, mo_relaxed);
    FNodes[AIdx].FFreeNext := UnpackIdx(LOld);
    LNew := Pack(AIdx, UnpackTag(LOld) + 1);
    LExpected := LOld;
  until atomic_compare_exchange_strong_64(FFreeStripes[AStripe].Head, LExpected, LNew, mo_acq_rel, mo_acquire);
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
    { A recycle racing ahead of quiescence may have refilled a stripe; any
      available node anywhere means no growth is needed. }
    for LI := 0 to MSQUEUE_OP_STRIPES - 1 do
      if UnpackIdx(atomic_load_64(FFreeStripes[LI].Head, mo_acquire)) >= 0 then
        Exit;

    LOldCap := atomic_load(FCapacity, mo_relaxed);
    if (LOldCap > High(Int32) div 2) or
       (LOldCap > (MaxInt div SizeOf(TNode)) div 2) then
      raise EOutOfMemoryError.Create(FormatAllocErrorMsg('LockFree', 'Grow', 'TLockFreeMsQueue.Grow: capacity overflow'));
    LNewCap := LOldCap * 2;

    SetLength(LNewNodes, LNewCap);
    Move(FNodes[0], LNewNodes[0], LOldCap * SizeOf(TNode));
    for LI := LOldCap to LNewCap - 1 do
    begin
      LNewNodes[LI].FHasValue := False;
      LNewNodes[LI].FNext := Pack(-1, 0);
      { Round-robin the new nodes into the per-stripe free chains (all
        stripes verified empty above, so each chain is exactly its slice). }
      if LI + MSQUEUE_OP_STRIPES < LNewCap then
        LNewNodes[LI].FFreeNext := LI + MSQUEUE_OP_STRIPES
      else
        LNewNodes[LI].FFreeNext := -1;
    end;

    FNodes := LNewNodes;
    atomic_store(FCapacity, LNewCap, mo_relaxed);
    for LI := 0 to MSQUEUE_OP_STRIPES - 1 do
    begin
      { Keep each stripe's aba tag monotone across the resize (same
        convention as the pre-stripe code) so no stale snapshot can ever
        CAS-succeed against the rebuilt chain. }
      LOldFree := atomic_load_64(FFreeStripes[LI].Head, mo_relaxed);
      if LOldCap + LI < LNewCap then
        LNewFree := Pack(LOldCap + LI, UnpackTag(LOldFree) + 1)
      else
        LNewFree := Pack(-1, UnpackTag(LOldFree) + 1);
      atomic_store_64(FFreeStripes[LI].Head, LNewFree, mo_release);
    end;
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
  if ACapacity > MaxInt div SizeOf(TNode) then
    raise EArgumentError.Create('TLockFreeMsQueue: capacity exceeds allocation limit');
  inherited Create;
  SetLength(FNodes, ACapacity);
  for I := 0 to ACapacity - 1 do
    if I + MSQUEUE_OP_STRIPES < ACapacity then
      FNodes[I].FFreeNext := I + MSQUEUE_OP_STRIPES
    else
      FNodes[I].FFreeNext := -1;
  FCapacity := ACapacity;
  for I := 0 to MSQUEUE_OP_STRIPES - 1 do
    if I < ACapacity then
      FFreeStripes[I].Head := Pack(I, 0)
    else
      FFreeStripes[I].Head := Pack(-1, 0);
  for I := 0 to MSQUEUE_OP_STRIPES - 1 do
    FOpStripes[I].Count := 0;
  FResizing := 0;
  { Create is single-threaded; stripe 0 is as good as any. }
  if not TryAllocNodeIdx(0, LSentinel) then
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
    if TryAllocNodeIdx(LStripe, LNodeIdx) then
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
            FreeNodeIdx(LHeadIdx, LStripe);
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
