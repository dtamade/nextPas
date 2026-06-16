unit nextpas.core.lockfree.ebr;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.atomic;

type
  {** @desc EBR 回调类型：回收时调用 }
  TLockFreeReclaimProc = procedure(const AData: Pointer; const AUserData: Pointer);

  PEbrRetiredNode = ^TEbrRetiredNode;
  {** @desc EBR 退休节点 }
  TEbrRetiredNode = record
    Next: PEbrRetiredNode;
    Data: Pointer;
    Reclaim: TLockFreeReclaimProc;
    UserData: Pointer;
  end;

  {** @desc Epoch-Based Reclamation 域（保守单次检查设计） }
  TEbrDomain = class
  private
    FRetired: PEbrRetiredNode;
    FActiveCount: Int32;
    FRetiredCount: Int32;
  public
    constructor Create;
    destructor Destroy; override;
    {** @desc 进入临界区（ActiveCount+1） }
    procedure Enter;
    {** @desc 离开临界区（ActiveCount-1） }
    procedure Leave;
    {** @desc 退休指针；Collect 时若无活跃者则回收 }
    procedure Retire(const AData: Pointer; const AReclaim: TLockFreeReclaimProc; const AUserData: Pointer = nil);
    {** @desc 尝试回收所有退休项（ActiveCount=0 时生效） }
    procedure Collect;
    {** @desc 当前活跃临界区数 }
    function ActiveCount: PtrUInt;
    {** @desc 当前退休待回收数 }
    function RetiredCount: PtrUInt;
  end;

  {** @desc EBR 哨兵守卫（RAII 自动 Leave） }
  TEbrGuard = record
  private
    FDomain: TEbrDomain;
    FActive: Boolean;
  public
    {** @desc 获取守卫并进入临界区（ADomain=nil 时为 no-op） }
    class function Acquire(const ADomain: TEbrDomain): TEbrGuard; static;
    {** @desc 释放守卫并离开临界区（重复调用安全） }
    procedure Release;
  end;

implementation

constructor TEbrDomain.Create;
begin
  inherited Create;
  FRetired := nil;
  FActiveCount := 0;
  FRetiredCount := 0;
end;

destructor TEbrDomain.Destroy;
var
  LNode, LNext: PEbrRetiredNode;
begin
  LNode := PEbrRetiredNode(atomic_exchange(PPointer(@FRetired)^, nil, moAcqRel));
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

procedure TEbrDomain.Enter;
begin
  AtomicFetchAdd32(FActiveCount, 1, moAcquire);
end;

procedure TEbrDomain.Leave;
begin
  AtomicFetchSub32(FActiveCount, 1, moRelease);
end;

procedure TEbrDomain.Retire(const AData: Pointer; const AReclaim: TLockFreeReclaimProc; const AUserData: Pointer);
var
  LNode: PEbrRetiredNode;
begin
  if AData = nil then
    Exit;
  LNode := GetMem(SizeOf(TEbrRetiredNode));
  LNode^.Data := AData;
  LNode^.Reclaim := AReclaim;
  LNode^.UserData := AUserData;
  repeat
    LNode^.Next := PEbrRetiredNode(atomic_load(PPointer(@FRetired)^, moRelaxed));
  until atomic_compare_exchange_strong(PPointer(@FRetired)^, PPointer(@LNode^.Next)^, LNode, moRelease, moRelaxed);
  AtomicFetchAdd32(FRetiredCount, 1, moRelaxed);
end;

procedure TEbrDomain.Collect;
var
  LList: PEbrRetiredNode;
  LNode, LNext: PEbrRetiredNode;
begin
  if AtomicLoad32(FActiveCount, moAcquire) <> 0 then
    Exit;
  LList := PEbrRetiredNode(atomic_exchange(PPointer(@FRetired)^, nil, moAcqRel));
  if LList = nil then
    Exit;
  LNode := LList;
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    if Assigned(LNode^.Reclaim) then
      LNode^.Reclaim(LNode^.Data, LNode^.UserData);
    FreeMem(LNode);
    LNode := LNext;
  end;
  AtomicStore32(FRetiredCount, 0, moRelease);
end;

function TEbrDomain.ActiveCount: PtrUInt;
begin
  Result := PtrUInt(AtomicLoad32(FActiveCount, moRelaxed));
end;

function TEbrDomain.RetiredCount: PtrUInt;
begin
  Result := AtomicLoad32(FRetiredCount, moRelaxed);
end;

class function TEbrGuard.Acquire(ADomain: TEbrDomain): TEbrGuard;
begin
  Result.FDomain := ADomain;
  Result.FActive := False;
  if ADomain <> nil then
  begin
    ADomain.Enter;
    Result.FActive := True;
  end;
end;

procedure TEbrGuard.Release;
begin
  if FActive and (FDomain <> nil) then
  begin
    FDomain.Leave;
    FActive := False;
  end;
end;

end.
