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
  LThread := FThreads;
  while LThread <> nil do
  begin
    LNextThread := LThread^.Next;
    SetLength(LThread^.HP, 0);
    FreeMem(LThread);
    LThread := LNextThread;
  end;
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
  repeat
    LThread^.Next := PHazardThreadRec(AtomicLoadPtr(Pointer(FThreads), moRelaxed));
  until AtomicCompareExchangePtr(Pointer(FThreads), LThread^.Next, LThread, moRelease) = LThread^.Next;
  Result := PtrUInt(LThread);
end;

procedure THazardDomain.UnregisterThread(const AThreadId: PtrUInt);
var
  LThread: PHazardThreadRec;
  LPrev: PHazardThreadRec;
  LI: PtrUInt;
begin
  LThread := PHazardThreadRec(AThreadId);
  if LThread = nil then
    Exit;
  for LI := 0 to FHPCount - 1 do
    LThread^.HP[LI] := nil;
  LPrev := nil;
  LThread := FThreads;
  while LThread <> nil do
  begin
    if PtrUInt(LThread) = AThreadId then
    begin
      if LPrev = nil then
        AtomicStorePtr(Pointer(FThreads), LThread^.Next, moRelease)
      else
        LPrev^.Next := LThread^.Next;
      SetLength(LThread^.HP, 0);
      FreeMem(LThread);
      Exit;
    end;
    LPrev := LThread;
    LThread := LThread^.Next;
  end;
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
  LThread := FThreads;
  while LThread <> nil do
  begin
    LThreadId := PtrUInt(LThread);
    LThread := LThread^.Next;
    if AtomicFetchAdd32(PHazardThreadRec(LThreadId)^.RetiredCount, 1, moRelaxed) >= HAZARD_RETIRE_BATCH then
    begin
      AtomicStore32(PHazardThreadRec(LThreadId)^.RetiredCount, 0, moRelaxed);
      Collect(LThreadId);
    end;
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
    Inc(Result);
    LThread := LThread^.Next;
  end;
end;

function THazardDomain.RetiredCount: PtrUInt;
begin
  Result := PtrUInt(AtomicLoad32(FGlobalRetiredCount, moRelaxed));
end;

end.
