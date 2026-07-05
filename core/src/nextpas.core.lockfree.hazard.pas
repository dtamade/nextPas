unit nextpas.core.lockfree.hazard;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.ebr;

const
  HAZARD_DEFAULT_HP_COUNT = 2;
  HAZARD_RETIRE_BATCH = 10;

type
  PHazardThreadRec = ^THazardThreadRec;
  THazardThreadRec = record
    Next: PHazardThreadRec;
    HP: array of Pointer;
    RetiredCount: Int32;
    Deleted: Int32;  // 0=正常, 1=已逻辑删除（CAS 标记删除模式）
  end;

  PHazardRetiredNode = ^THazardRetiredNode;
  THazardRetiredNode = record
    Next: PHazardRetiredNode;
    Data: Pointer;
    Reclaim: TLockFreeReclaimProc;
    UserData: Pointer;
  end;

  {** @desc Hazard Pointer 内存回收域（与 EBR 互补，适合读多写少场景） }
  THazardDomain = class
  private
    FHPCount: PtrUInt;
    FThreads: PHazardThreadRec;
    FRetired: PHazardRetiredNode;
    FRetiredCount: Int32;
    FGlobalRetiredCount: Int32;
    {** @desc 物理删除已逻辑删除的线程节点并释放内存 }
    procedure DrainPendingFree;
  public
    {** @desc 创建 Hazard Domain（AHPCount 每线程 HP 数） }
    constructor Create(const AHPCount: PtrUInt = HAZARD_DEFAULT_HP_COUNT);
    destructor Destroy; override;

    {** @desc 注册调用线程，返回线程 ID }
    function RegisterThread: PtrUInt;
    {** @desc 注销线程 }
    procedure UnregisterThread(const AThreadId: PtrUInt);

    {** @desc 保护指针（返回 APtr，带 memory barrier） }
    function Protect(const AThreadId: PtrUInt; const AHPIndex: PtrUInt; const APtr: Pointer): Pointer;
    {** @desc 清除保护 }
    procedure Clear(const AThreadId: PtrUInt; const AHPIndex: PtrUInt);

    {** @desc 退休指针（批量触发 Collect） }
    procedure Retire(AData: Pointer; AReclaim: TLockFreeReclaimProc; AUserData: Pointer = nil);
    {** @desc 回收未被任何线程保护的退休指针 }
    procedure Collect(const AThreadId: PtrUInt);

    {** @desc 活跃线程数 }
    function ActiveThreads: PtrUInt;
    {** @desc 退休待回收数 }
    function RetiredCount: PtrUInt;
  end;

implementation

{ THazardDomain }

constructor THazardDomain.Create(const AHPCount: PtrUInt);
begin
  inherited Create;
  if AHPCount = 0 then
    raise EArgumentError.Create('THazardDomain: HP count must be > 0');
  FHPCount := AHPCount;
  FThreads := nil;
  FRetired := nil;
  FRetiredCount := 0;
  FGlobalRetiredCount := 0;
end;

destructor THazardDomain.Destroy;
var
  LThread: PHazardThreadRec;
  LNextThread: PHazardThreadRec;
  LNode: PHazardRetiredNode;
  LNext: PHazardRetiredNode;
begin
  // 释放所有线程节点（包括已逻辑删除的）
  LThread := FThreads;
  while LThread <> nil do
  begin
    LNextThread := LThread^.Next;
    SetLength(LThread^.HP, 0);
    FreeMem(LThread);
    LThread := LNextThread;
  end;
  // 释放所有退休节点
  LNode := FRetired;
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    if Assigned(LNode^.Reclaim) then
      LNode^.Reclaim(LNode^.Data, LNode^.UserData);
    FreeMem(LNode);
    LNode := LNext;
  end;
  inherited;
end;

function THazardDomain.RegisterThread: PtrUInt;
var
  LThread: PHazardThreadRec;
  LI: PtrUInt;
begin
  LThread := AllocMem(SizeOf(THazardThreadRec));
  LThread^.Next := nil;
  SetLength(LThread^.HP, FHPCount);
  for LI := 0 to FHPCount - 1 do
    LThread^.HP[LI] := nil;
  LThread^.RetiredCount := 0;
  LThread^.Deleted := 0;
  repeat
    LThread^.Next := PHazardThreadRec(AtomicLoadPtr(Pointer(FThreads), moRelaxed));
  until AtomicCompareExchangePtr(Pointer(FThreads), LThread^.Next, LThread, moRelease) = LThread^.Next;
  Result := PtrUInt(LThread);
end;

procedure THazardDomain.UnregisterThread(const AThreadId: PtrUInt);
var
  LThread: PHazardThreadRec;
  LI: PtrUInt;
begin
  LThread := PHazardThreadRec(AThreadId);
  if LThread = nil then
    Exit;
  // 1. 清除 HP（必须在标记 Deleted 之前）
  for LI := 0 to FHPCount - 1 do
    LThread^.HP[LI] := nil;
  // 2. 原子标记为已删除（mo_release 保证 HP 清除对后续读者可见）
  //    不修改链表结构，不释放内存 —— 延迟到 Collect 中的 DrainPendingFree 处理
  AtomicStore32(LThread^.Deleted, 1, moRelease);
end;

function THazardDomain.Protect(const AThreadId: PtrUInt; const AHPIndex: PtrUInt; const APtr: Pointer): Pointer;
var
  LThread: PHazardThreadRec;
begin
  LThread := PHazardThreadRec(AThreadId);
  if (LThread = nil) or (AHPIndex >= FHPCount) then
  begin
    Result := APtr;
    Exit;
  end;
  LThread^.HP[AHPIndex] := APtr;
  AtomicThreadFence(moSeqCst);
  Result := APtr;
end;

procedure THazardDomain.Clear(const AThreadId: PtrUInt; const AHPIndex: PtrUInt);
var
  LThread: PHazardThreadRec;
begin
  LThread := PHazardThreadRec(AThreadId);
  if (LThread = nil) or (AHPIndex >= FHPCount) then
    Exit;
  AtomicThreadFence(moSeqCst);
  LThread^.HP[AHPIndex] := nil;
end;

procedure THazardDomain.Retire(AData: Pointer; AReclaim: TLockFreeReclaimProc; AUserData: Pointer);
var
  LNode: PHazardRetiredNode;
  LThread: PHazardThreadRec;
  LThreadId: PtrUInt;
begin
  if AData = nil then
    Exit;
  LNode := GetMem(SizeOf(THazardRetiredNode));
  LNode^.Data := AData;
  LNode^.Reclaim := AReclaim;
  LNode^.UserData := AUserData;
  repeat
    LNode^.Next := PHazardRetiredNode(AtomicLoadPtr(Pointer(FRetired), moRelaxed));
  until AtomicCompareExchangePtr(Pointer(FRetired), LNode^.Next, LNode, moRelease) = LNode^.Next;
  AtomicFetchAdd32(FGlobalRetiredCount, 1, moRelaxed);
  // 遍历线程触发批量回收（跳过已逻辑删除的线程）
  LThread := FThreads;
  while LThread <> nil do
  begin
    if AtomicLoad32(LThread^.Deleted, moAcquire) = 0 then
    begin
      LThreadId := PtrUInt(LThread);
      if AtomicFetchAdd32(PHazardThreadRec(LThreadId)^.RetiredCount, 1, moRelaxed) >= HAZARD_RETIRE_BATCH then
      begin
        AtomicStore32(PHazardThreadRec(LThreadId)^.RetiredCount, 0, moRelaxed);
        Collect(LThreadId);
      end;
    end;
    LThread := LThread^.Next;
  end;
end;

procedure THazardDomain.Collect(const AThreadId: PtrUInt);
var
  LList: PHazardRetiredNode;
  LNode: PHazardRetiredNode;
  LPrev: PHazardRetiredNode;
  LNext: PHazardRetiredNode;
  LThread: PHazardThreadRec;
  LProtected: Boolean;
  LI: PtrUInt;
  LReclaimCount: Int32;
begin
  // 0. 先清理已逻辑删除的线程节点
  DrainPendingFree;

  LList := PHazardRetiredNode(AtomicExchangePtr(Pointer(FRetired), nil, moAcqRel));
  if LList = nil then
    Exit;
  LReclaimCount := 0;
  LPrev := nil;
  LNode := LList;
  while LNode <> nil do
  begin
    LProtected := False;
    LThread := FThreads;
    while LThread <> nil do
    begin
      // 跳过已逻辑删除的线程
      if AtomicLoad32(LThread^.Deleted, moAcquire) <> 0 then
      begin
        LThread := LThread^.Next;
        Continue;
      end;
      for LI := 0 to FHPCount - 1 do
      begin
        if LThread^.HP[LI] = LNode^.Data then
        begin
          LProtected := True;
          Break;
        end;
      end;
      if LProtected then
        Break;
      LThread := LThread^.Next;
    end;
    if LProtected then
    begin
      LPrev := LNode;
      LNode := LNode^.Next;
    end
    else
    begin
      LNext := LNode^.Next;
      if Assigned(LNode^.Reclaim) then
        LNode^.Reclaim(LNode^.Data, LNode^.UserData);
      FreeMem(LNode);
      Inc(LReclaimCount);
      if LPrev = nil then
        LList := LNext
      else
        LPrev^.Next := LNext;
      LNode := LNext;
    end;
  end;
  if LList <> nil then
  begin
    LNode := LList;
    while LNode^.Next <> nil do
      LNode := LNode^.Next;
    repeat
      LNode^.Next := PHazardRetiredNode(AtomicLoadPtr(Pointer(FRetired), moRelaxed));
    until AtomicCompareExchangePtr(Pointer(FRetired), LNode^.Next, LList, moRelease) = LNode^.Next;
  end;
  AtomicFetchSub32(FGlobalRetiredCount, LReclaimCount, moRelaxed);
end;

function THazardDomain.ActiveThreads: PtrUInt;
var
  LThread: PHazardThreadRec;
begin
  Result := 0;
  LThread := FThreads;
  while LThread <> nil do
  begin
    // 跳过已逻辑删除的线程
    if AtomicLoad32(LThread^.Deleted, moAcquire) = 0 then
      Inc(Result);
    LThread := LThread^.Next;
  end;
end;

function THazardDomain.RetiredCount: PtrUInt;
begin
  Result := PtrUInt(AtomicLoad32(FGlobalRetiredCount, moRelaxed));
end;

procedure THazardDomain.DrainPendingFree;
var
  LPrev: PHazardThreadRec;
  LNode: PHazardThreadRec;
  LNext: PHazardThreadRec;
  LToFreeHead: PHazardThreadRec;
  LToFreeTail: PHazardThreadRec;
begin
  LToFreeHead := nil;
  LToFreeTail := nil;
  LPrev := nil;
  LNode := FThreads;
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    if AtomicLoad32(LNode^.Deleted, moAcquire) <> 0 then
    begin
      // 尝试 CAS 物理删除
      if LPrev = nil then
      begin
        if AtomicCompareExchangePtr(Pointer(FThreads), LNode, LNext, moRelease) = LNode then
        begin
          // 成功将链表头跳过 LNode
          LNode^.Next := LToFreeHead;
          LToFreeHead := LNode;
          if LToFreeTail = nil then
            LToFreeTail := LNode;
          // LPrev 不变（仍为 nil）
          LNode := LNext;
          Continue;
        end;
      end
      else
      begin
        if AtomicCompareExchangePtr(Pointer(LPrev^.Next), LNode, LNext, moRelease) = LNode then
        begin
          LNode^.Next := LToFreeHead;
          LToFreeHead := LNode;
          if LToFreeTail = nil then
            LToFreeTail := LNode;
          LNode := LNext;
          Continue;
        end;
      end;
      // CAS 失败：前驱也被删除或链表被并发修改，跳过本轮
    end;
    LPrev := LNode;
    LNode := LNext;
  end;
  // 释放上一轮收集的待释放节点
  LNode := LToFreeHead;
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    SetLength(LNode^.HP, 0);
    FreeMem(LNode);
    LNode := LNext;
  end;
end;

end.
