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
    FNodes: array of TNode;
    FFreeList: array of TFreeNode;
    FCapacity: Int32;
    FFreeHead: Int64;   // packed: (index:32 | aba:32)
    FHead: Int64;        // packed: (index:32 | aba:32)
    FTail: Int64;        // packed: (index:32 | aba:32)
    FCount: Int64;
    FClosed: Int32;
    FActiveOperations: Int32;
    FResizing: Int32;

    function TryAllocNodeIdx(out AIdx: Int32): Boolean;
    procedure FreeNodeIdx(AIdx: Int32);
    function Pack(AIdx, ATag: Int32): Int64;
    function UnpackIdx(APacked: Int64): Int32;
    function UnpackTag(APacked: Int64): Int32;
    procedure EnterOperation;
    procedure LeaveOperation;
    procedure Grow;
  public
    constructor Create(ACapacity: Int32 = 64);
    destructor Destroy; override;

    {** 入队（无界队列，自动扩容） }
    function TryEnqueue(const AValue: T): Boolean;
    {** 出队 }
    function TryDequeue(out AValue: T): Boolean;
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
begin
  repeat
    LOld := AtomicLoad64(FFreeHead, moAcquire);
    LIdx := UnpackIdx(LOld);
    if LIdx < 0 then
      Exit(False);
    LNew := Pack(FFreeList[LIdx].FNext, UnpackTag(LOld) + 1);
  until AtomicCompareExchange64(FFreeHead, LOld, LNew, moAcqRel) = LOld;
  FNodes[LIdx].FHasValue := False;
  AIdx := LIdx;
  Result := True;
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

procedure TLockFreeMsQueueImpl.EnterOperation;
begin
  while True do
  begin
    while AtomicLoad32(FResizing, moAcquire) <> 0 do
      CpuPause;
    AtomicFetchAdd32(FActiveOperations, 1, moAcqRel);
    if AtomicLoad32(FResizing, moAcquire) = 0 then
      Exit;
    AtomicFetchSub32(FActiveOperations, 1, moAcqRel);
  end;
end;

procedure TLockFreeMsQueueImpl.LeaveOperation;
begin
  AtomicFetchSub32(FActiveOperations, 1, moAcqRel);
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
begin
  if AtomicCompareExchange32(FResizing, 0, 1, moAcqRel) <> 0 then
  begin
    while AtomicLoad32(FResizing, moAcquire) <> 0 do
      CpuPause;
    Exit;
  end;
  try
    while AtomicLoad32(FActiveOperations, moAcquire) <> 0 do
      CpuPause;
    LOldFree := AtomicLoad64(FFreeHead, moAcquire);
    if UnpackIdx(LOldFree) >= 0 then
      Exit;

    LOldCap := AtomicLoad32(FCapacity, moRelaxed);
    if (LOldCap > High(Int32) div 2) or
       (LOldCap > (MaxInt div SizeOf(TNode)) div 2) or
       (LOldCap > (MaxInt div SizeOf(TFreeNode)) div 2) then
      raise EOutOfMemoryError.Create('TLockFreeMsQueue.Grow: capacity overflow');
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
    AtomicStore32(FCapacity, LNewCap, moRelaxed);
    AtomicStore64(FFreeHead, LNewFree, moRelease);
  finally
    AtomicStore32(FResizing, 0, moRelease);
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
  FActiveOperations := 0;
  FResizing := 0;
  if not TryAllocNodeIdx(LSentinel) then
    raise EOutOfMemoryError.Create('TLockFreeMsQueue: sentinel allocation failed');
  FNodes[LSentinel].FHasValue := False;
  FNodes[LSentinel].FNext := Pack(-1, 0);
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
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    EnterOperation;
    if TryAllocNodeIdx(LNodeIdx) then
      Break;
    LeaveOperation;
    Grow;
  end;
  try
    FNodes[LNodeIdx].FValue := AValue;
    FNodes[LNodeIdx].FHasValue := True;
    FNodes[LNodeIdx].FNext := Pack(-1, 0);
    while True do
    begin
      LOldTail := AtomicLoad64(FTail, moAcquire);
      LTailIdx := UnpackIdx(LOldTail);
      LOldNext := AtomicLoad64(FNodes[LTailIdx].FNext, moAcquire);
      LNextIdx := UnpackIdx(LOldNext);
      if LOldTail = AtomicLoad64(FTail, moAcquire) then
      begin
        if LNextIdx < 0 then
        begin
          LNewNext := Pack(LNodeIdx, UnpackTag(LOldNext) + 1);
          if AtomicCompareExchange64(FNodes[LTailIdx].FNext,
            LOldNext, LNewNext, moAcqRel) = LOldNext then
          begin
            LNewTail := Pack(LNodeIdx, UnpackTag(LOldTail) + 1);
            AtomicCompareExchange64(FTail, LOldTail, LNewTail, moAcqRel);
            AtomicFetchAdd64(FCount, 1);
            Exit(True);
          end;
        end
        else
        begin
          LNewTail := Pack(LNextIdx, UnpackTag(LOldTail) + 1);
          AtomicCompareExchange64(FTail, LOldTail, LNewTail, moAcqRel);
        end;
      end;
    end;
  finally
    LeaveOperation;
  end;
end;

function TLockFreeMsQueueImpl.TryDequeue(out AValue: T): Boolean;
var
  LHeadIdx, LTailIdx, LNextIdx: Int32;
  LOldHead, LOldTail, LNewHead: Int64;
  LOldNext: Int64;
  LCandidateValue: T;
  LHasCandidate: Boolean;
begin
  Result := False;
  EnterOperation;
  try
    while True do
    begin
      LOldHead := AtomicLoad64(FHead, moAcquire);
      LHeadIdx := UnpackIdx(LOldHead);
      LOldTail := AtomicLoad64(FTail, moAcquire);
      LTailIdx := UnpackIdx(LOldTail);
      LOldNext := AtomicLoad64(FNodes[LHeadIdx].FNext, moAcquire);
      LNextIdx := UnpackIdx(LOldNext);
      if LOldHead = AtomicLoad64(FHead, moAcquire) then
      begin
        if LHeadIdx = LTailIdx then
        begin
          if LNextIdx < 0 then
            Exit(False);
          LNewHead := Pack(LNextIdx, UnpackTag(LOldTail) + 1);
          AtomicCompareExchange64(FTail, LOldTail, LNewHead, moAcqRel);
        end
        else
        begin
          LHasCandidate := FNodes[LNextIdx].FHasValue;
          if LHasCandidate then
            LCandidateValue := FNodes[LNextIdx].FValue;
          LNewHead := Pack(LNextIdx, UnpackTag(LOldHead) + 1);
          if AtomicCompareExchange64(FHead, LOldHead, LNewHead, moAcqRel) = LOldHead then
          begin
            if LHasCandidate then
            begin
              AValue := LCandidateValue;
              Result := True;
            end;
            FreeNodeIdx(LHeadIdx);
            AtomicFetchAdd64(FCount, -1);
            Exit;
          end;
        end;
      end;
    end;
  finally
    LeaveOperation;
  end;
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
  EnterOperation;
  try
    LOldHead := AtomicLoad64(FHead, moAcquire);
    LHeadIdx := UnpackIdx(LOldHead);
    LOldTail := AtomicLoad64(FTail, moAcquire);
    LTailIdx := UnpackIdx(LOldTail);
    LOldNext := AtomicLoad64(FNodes[LHeadIdx].FNext, moAcquire);
    LNextIdx := UnpackIdx(LOldNext);
    Result := (LHeadIdx = LTailIdx) and (LNextIdx < 0);
  finally
    LeaveOperation;
  end;
end;

end.
