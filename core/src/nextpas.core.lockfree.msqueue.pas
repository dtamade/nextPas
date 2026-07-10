unit nextpas.core.lockfree.msqueue;

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

  {** @desc Michael-Scott 无锁无界 MPMC 队列
    @details 经典无锁队列算法，使用 index-based 节点池。
      - 入队: CAS 更新 tail.next，然后 CAS 移动 tail 指针
      - 出队: CAS 更新 head 指针到 head.next
      - Sentinel 节点简化空队列边界处理
      - 支持 Close 语义
      - 节点池自动扩容
  }
  generic TLockFreeMsQueueImpl<T> = class
  private
    type
      PT = ^T;
      TNode = record
        FValue: T;
        FHasValue: Boolean;
        FNext: Int64;  // packed (index:32 | tag:32), index=-1 means nil
      end;
    type
      TFreeNode = record
        FNext: Int32;
      end;
  private
    FNodes: array of TNode;
    FFreeList: array of TFreeNode;
    FCapacity: Int32;
    FFreeHead: Int64;   // packed: (index:32 | aba:32)
    FHead: Int64;        // packed: (index:32 | aba:32)
    FTail: Int64;        // packed: (index:32 | aba:32)
    FCount: Int64;
    FClosed: Int32;

    function AllocNodeIdx: Int32;
    procedure FreeNodeIdx(AIdx: Int32);
    function Pack(AIdx, ATag: Int32): Int64;
    function UnpackIdx(APacked: Int64): Int32;
    function UnpackTag(APacked: Int64): Int32;
    procedure Grow;
  public
    constructor Create(ACapacity: Int32 = 64);
    destructor Destroy; override;

    {** 入队（无界队列，自动扩容） }
    function TryEnqueue(const AValue: T): Boolean;
    {** 出队 }
    function TryDequeue(out AValue: T): Boolean;
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

function TLockFreeMsQueueImpl.AllocNodeIdx: Int32;
var
  LOld, LNew: Int64;
  LIdx: Int32;
begin
  repeat
    LOld := AtomicLoad64(FFreeHead, moAcquire);
    LIdx := UnpackIdx(LOld);
    if LIdx < 0 then
    begin
      Grow;
      Continue;
    end;
    LNew := Pack(FFreeList[LIdx].FNext, UnpackTag(LOld) + 1);
  until AtomicCompareExchange64(FFreeHead, LOld, LNew, moAcqRel) = LOld;
  FNodes[LIdx].FHasValue := False;
  Result := LIdx;
end;

procedure TLockFreeMsQueueImpl.FreeNodeIdx(AIdx: Int32);
var
  LOld, LNew: Int64;
begin
  FNodes[AIdx].FHasValue := False;
  repeat
    LOld := AtomicLoad64(FFreeHead, moRelaxed);
    FFreeList[AIdx].FNext := UnpackIdx(LOld);
    LNew := Pack(AIdx, UnpackTag(LOld) + 1);
  until AtomicCompareExchange64(FFreeHead, LOld, LNew, moAcqRel) = LOld;
end;

procedure TLockFreeMsQueueImpl.Grow;
var
  I, LOldCap, LNewCap: Int32;
  LOld, LNew: Int64;
begin
  LOldCap := AtomicLoad32(FCapacity, moRelaxed);
  LNewCap := LOldCap * 2;
  // Grow node array
  SetLength(FNodes, LNewCap);
  // Grow free list array
  SetLength(FFreeList, LNewCap);
  // Link new nodes into free list and push them
  for I := LOldCap to LNewCap - 1 do
  begin
    FNodes[I].FHasValue := False;
    FNodes[I].FNext := Pack(-1, 0);
    // Push to free list
    repeat
      LOld := AtomicLoad64(FFreeHead, moRelaxed);
      FFreeList[I].FNext := UnpackIdx(LOld);
      LNew := Pack(I, UnpackTag(LOld) + 1);
    until AtomicCompareExchange64(FFreeHead, LOld, LNew, moAcqRel) = LOld;
  end;
  AtomicStore32(FCapacity, LNewCap, moRelease);
end;

constructor TLockFreeMsQueueImpl.Create(ACapacity: Int32);
var
  I, LSentinel: Int32;
begin
  inherited Create;
  if ACapacity < 4 then
    ACapacity := 4;
  SetLength(FNodes, ACapacity);
  SetLength(FFreeList, ACapacity);
  // Initialize freelist: link all nodes
  for I := 0 to ACapacity - 2 do
    FFreeList[I].FNext := I + 1;
  FFreeList[ACapacity - 1].FNext := -1;
  FCapacity := ACapacity;
  // Initialize free list head
  FFreeHead := Pack(0, 0);
  // Allocate sentinel node
  LSentinel := AllocNodeIdx;
  FNodes[LSentinel].FHasValue := False;
  FNodes[LSentinel].FNext := Pack(-1, 0);
  // Both head and tail point to sentinel
  FHead := Pack(LSentinel, 0);
  FTail := Pack(LSentinel, 0);
  FCount := 0;
  FClosed := 0;
end;

destructor TLockFreeMsQueueImpl.Destroy;
begin
  SetLength(FNodes, 0);
  SetLength(FFreeList, 0);
  inherited Destroy;
end;

function TLockFreeMsQueueImpl.TryEnqueue(const AValue: T): Boolean;
var
  LNodeIdx, LTailIdx, LNextIdx: Int32;
  LOldTail, LOldNext, LNewTail, LNewNext: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  // Allocate a new node and store the value
  LNodeIdx := AllocNodeIdx;
  FNodes[LNodeIdx].FValue := AValue;
  FNodes[LNodeIdx].FHasValue := True;
  FNodes[LNodeIdx].FNext := Pack(-1, 0);
  // Enqueue loop
  while True do
  begin
    LOldTail := AtomicLoad64(FTail, moAcquire);
    LTailIdx := UnpackIdx(LOldTail);
    LOldNext := AtomicLoad64(FNodes[LTailIdx].FNext, moAcquire);
    LNextIdx := UnpackIdx(LOldNext);
    // Is tail still the tail?
    if LOldTail = AtomicLoad64(FTail, moAcquire) then
    begin
      if LNextIdx < 0 then
      begin
        // Tail points to last node, try to link new node
        LNewNext := Pack(LNodeIdx, UnpackTag(LOldNext) + 1);
        if AtomicCompareExchange64(FNodes[LTailIdx].FNext,
          LOldNext, LNewNext, moAcqRel) = LOldNext then
        begin
          // Success, try to swing tail to new node (non-critical)
          LNewTail := Pack(LNodeIdx, UnpackTag(LOldTail) + 1);
          AtomicCompareExchange64(FTail, LOldTail, LNewTail, moAcqRel);
          AtomicFetchAdd64(FCount, 1);
          Exit(True);
        end;
      end
      else
      begin
        // Tail is lagging, help move it forward
        LNewTail := Pack(LNextIdx, UnpackTag(LOldTail) + 1);
        AtomicCompareExchange64(FTail, LOldTail, LNewTail, moAcqRel);
      end;
    end;
  end;
end;

function TLockFreeMsQueueImpl.TryDequeue(out AValue: T): Boolean;
var
  LHeadIdx, LTailIdx, LNextIdx: Int32;
  LOldHead, LOldTail, LNewHead: Int64;
  LOldNext: Int64;
begin
  Result := False;
  while True do
  begin
    LOldHead := AtomicLoad64(FHead, moAcquire);
    LHeadIdx := UnpackIdx(LOldHead);
    LOldTail := AtomicLoad64(FTail, moAcquire);
    LTailIdx := UnpackIdx(LOldTail);
    LOldNext := AtomicLoad64(FNodes[LHeadIdx].FNext, moAcquire);
    LNextIdx := UnpackIdx(LOldNext);
    // Is head still the head?
    if LOldHead = AtomicLoad64(FHead, moAcquire) then
    begin
      if LHeadIdx = LTailIdx then
      begin
        if LNextIdx < 0 then
          Exit(False); // Queue is empty
        // Tail is lagging, help move it
        LNewHead := Pack(LNextIdx, UnpackTag(LOldTail) + 1);
        AtomicCompareExchange64(FTail, LOldTail, LNewHead, moAcqRel);
      end
      else
      begin
        // Try to swing head to next node
        LNewHead := Pack(LNextIdx, UnpackTag(LOldHead) + 1);
        if AtomicCompareExchange64(FHead, LOldHead, LNewHead, moAcqRel) = LOldHead then
        begin
          // CAS succeeded — read value from next node (now becomes sentinel)
          if FNodes[LNextIdx].FHasValue then
          begin
            AValue := FNodes[LNextIdx].FValue;
            Result := True;
          end;
          // Free old head (sentinel)
          FreeNodeIdx(LHeadIdx);
          AtomicFetchAdd64(FCount, -1);
          Exit;
        end;
      end;
    end;
  end;
end;

procedure TLockFreeMsQueueImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TLockFreeMsQueueImpl.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TLockFreeMsQueueImpl.ApproxCount: Int64;
begin
  Result := AtomicLoad64(FCount, moRelaxed);
end;

function TLockFreeMsQueueImpl.IsEmpty: Boolean;
var
  LHeadIdx, LTailIdx, LNextIdx: Int32;
  LOldHead, LOldTail, LOldNext: Int64;
begin
  LOldHead := AtomicLoad64(FHead, moAcquire);
  LHeadIdx := UnpackIdx(LOldHead);
  LOldTail := AtomicLoad64(FTail, moAcquire);
  LTailIdx := UnpackIdx(LOldTail);
  LOldNext := AtomicLoad64(FNodes[LHeadIdx].FNext, moAcquire);
  LNextIdx := UnpackIdx(LOldNext);
  Result := (LHeadIdx = LTailIdx) and (LNextIdx < 0);
end;

end.
