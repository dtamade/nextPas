unit nextpas.core.lockfree.ebr;
{**
 * @desc Epoch-Based Reclamation (EBR) memory reclamation.
 *
 * @details Lock-free memory reclamation using epoch counters:
 *   - Enter/Leave: register/unregister as active reader
 *   - Retire: mark memory for future reclamation
 *   - Collect: reclaim memory when safe (no active readers)
 *   - Domain-based: multiple independent reclamation domains
 *
 * @concurrency Thread-safe for multiple threads:
 *   - Enter/Leave: per-thread guard management
 *   - Retire: thread-safe retirement list
 *   - Collect: safe reclamation when no guards exist
 *
 * @see Epoch-Based Reclamation — Fraser, 2004
 * @see Hazard Pointers — complementary reclamation approach
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem,
  nextpas.core.errors,
  nextpas.core.atomic;

type
  TLockFreeReclaimProc = procedure(const AData: Pointer; const AUserData: Pointer);

  PEbrRetiredNode = ^TEbrRetiredNode;
  TEbrRetiredNode = record
    Next: PEbrRetiredNode;
    Data: Pointer;
    Reclaim: TLockFreeReclaimProc;
    UserData: Pointer;
  end;

  {** @desc Zero-active QSBR reclamation domain
    @details Retired nodes remain domain-local. Collect briefly blocks new
      entrants, detaches nodes only after all established guards leave, then
      reopens the read side before invoking reclaim callbacks. }
  TEbrDomain = class
  private
    FRetired: PEbrRetiredNode;
    FActiveCount: Int32;
    FRetiredCount: Int64;
    FCollecting: Int32;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Enter;
    procedure Leave;
    procedure Retire(const AData: Pointer; const AReclaim: TLockFreeReclaimProc;
      const AUserData: Pointer = nil);
    procedure Collect;
    function ActiveCount: PtrUInt; inline;
    function RetiredCount: PtrUInt; inline;
  end;

  TEbrGuard = record
  private
    FDomain: TEbrDomain;
    FActive: Boolean;
  public
    class function Acquire(const ADomain: TEbrDomain): TEbrGuard; static;
    procedure Release;
  end;

implementation

constructor TEbrDomain.Create;
begin
  inherited Create;
  FRetired := nil;
  FActiveCount := 0;
  FRetiredCount := 0;
  FCollecting := 0;
end;

destructor TEbrDomain.Destroy;
var
  LNode: PEbrRetiredNode;
  LNext: PEbrRetiredNode;
begin
  LNode := PEbrRetiredNode(AtomicExchangePtr(Pointer(FRetired), nil, moAcqRel));
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    if Assigned(LNode^.Reclaim) then
      LNode^.Reclaim(LNode^.Data, LNode^.UserData);
    FreeMem(LNode, SizeOf(TEbrRetiredNode));
    LNode := LNext;
  end;
  inherited Destroy;
end;

procedure TEbrDomain.Enter;
var
  LActive: Int32;
begin
  while True do
  begin
    while AtomicLoad32(FCollecting, moAcquire) <> 0 do
      ThreadSwitch;
    LActive := AtomicLoad32(FActiveCount, moRelaxed);
    if LActive = High(Int32) then
      raise EInvalidOperationError.Create('TEbrDomain.Enter: active guard count overflow');
    if AtomicCompareExchange32(FActiveCount, LActive, LActive + 1, moAcqRel) <> LActive then
      Continue;
    if AtomicLoad32(FCollecting, moAcquire) = 0 then
      Exit;
    AtomicFetchSub32(FActiveCount, 1, moRelease);
  end;
end;

procedure TEbrDomain.Leave;
var
  LActive: Int32;
begin
  repeat
    LActive := AtomicLoad32(FActiveCount, moAcquire);
    if LActive <= 0 then
      Exit;
    if AtomicCompareExchange32(FActiveCount, LActive, LActive - 1,
      moRelease) = LActive then
      Exit;
    cpu_pause;
  until False;
end;

procedure TEbrDomain.Retire(const AData: Pointer;
  const AReclaim: TLockFreeReclaimProc; const AUserData: Pointer);
var
  LNode: PEbrRetiredNode;
begin
  if AData = nil then
    Exit;
  LNode := GetMem(SizeOf(TEbrRetiredNode));
  LNode^.Data := AData;
  LNode^.Reclaim := AReclaim;
  LNode^.UserData := AUserData;
  AtomicFetchAdd64(FRetiredCount, 1, moRelaxed);
  repeat
    LNode^.Next := PEbrRetiredNode(AtomicLoadPtr(Pointer(FRetired), moRelaxed));
  until AtomicCompareExchangePtr(Pointer(FRetired), LNode^.Next, LNode,
    moRelease) = LNode^.Next;
end;

procedure TEbrDomain.Collect;
var
  LList: PEbrRetiredNode;
  LNode: PEbrRetiredNode;
  LNext: PEbrRetiredNode;
  LReclaimedCount: Int64;
begin
  if AtomicCompareExchange32(FCollecting, 0, 1, moAcqRel) <> 0 then
    Exit;
  LList := nil;
  try
    if AtomicLoad32(FActiveCount, moAcquire) = 0 then
      LList := PEbrRetiredNode(
        AtomicExchangePtr(Pointer(FRetired), nil, moAcqRel));
  finally
    AtomicStore32(FCollecting, 0, moRelease);
  end;

  LReclaimedCount := 0;
  LNode := LList;
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    if Assigned(LNode^.Reclaim) then
      LNode^.Reclaim(LNode^.Data, LNode^.UserData);
    FreeMem(LNode, SizeOf(TEbrRetiredNode));
    Inc(LReclaimedCount);
    LNode := LNext;
  end;
  if LReclaimedCount > 0 then
    AtomicFetchSub64(FRetiredCount, LReclaimedCount, moAcqRel);
end;

function TEbrDomain.ActiveCount: PtrUInt; inline;
begin
  Result := PtrUInt(AtomicLoad32(FActiveCount, moAcquire));
end;

function TEbrDomain.RetiredCount: PtrUInt; inline;
begin
  Result := PtrUInt(AtomicLoad64(FRetiredCount, moAcquire));
end;

class function TEbrGuard.Acquire(const ADomain: TEbrDomain): TEbrGuard;
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
