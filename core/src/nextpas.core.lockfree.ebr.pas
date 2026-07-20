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
 *
 * Preferred atomics: atomic_* + mo_* (Go/Rust parity / Q2).
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
  LNode := PEbrRetiredNode(atomic_exchange(Pointer(FRetired), nil, mo_acq_rel));
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
  LExpected: Int32;
begin
  while True do
  begin
    while atomic_load(FCollecting, mo_acquire) <> 0 do
      ThreadSwitch;
    LActive := atomic_load(FActiveCount, mo_relaxed);
    if LActive = High(Int32) then
      raise EInvalidOperationError.Create('TEbrDomain.Enter: active guard count overflow');
    LExpected := LActive;
    if not atomic_compare_exchange_strong(FActiveCount, LExpected, LActive + 1,
      mo_acq_rel, mo_acquire) then
      Continue;
    if atomic_load(FCollecting, mo_acquire) = 0 then
      Exit;
    atomic_fetch_sub(FActiveCount, 1, mo_release);
  end;
end;

procedure TEbrDomain.Leave;
var
  LActive: Int32;
  LExpected: Int32;
begin
  repeat
    LActive := atomic_load(FActiveCount, mo_acquire);
    if LActive <= 0 then
      Exit;
    LExpected := LActive;
    { success release → failure max is relaxed (C11 / atomic contract). }
    if atomic_compare_exchange_strong(FActiveCount, LExpected, LActive - 1,
      mo_release, mo_relaxed) then
      Exit;
    cpu_pause;
  until False;
end;

procedure TEbrDomain.Retire(const AData: Pointer;
  const AReclaim: TLockFreeReclaimProc; const AUserData: Pointer);
var
  LNode: PEbrRetiredNode;
  LExpected: Pointer;
begin
  if AData = nil then
    Exit;
  LNode := GetMem(SizeOf(TEbrRetiredNode));
  LNode^.Data := AData;
  LNode^.Reclaim := AReclaim;
  LNode^.UserData := AUserData;
  atomic_fetch_add_64(FRetiredCount, 1, mo_relaxed);
  repeat
    LNode^.Next := PEbrRetiredNode(atomic_load(Pointer(FRetired), mo_relaxed));
    LExpected := Pointer(LNode^.Next);
  until atomic_compare_exchange_strong(Pointer(FRetired), LExpected, Pointer(LNode),
    mo_release, mo_relaxed);
end;

procedure TEbrDomain.Collect;
var
  LList: PEbrRetiredNode;
  LNode: PEbrRetiredNode;
  LNext: PEbrRetiredNode;
  LReclaimedCount: Int64;
  LCollectExpected: Int32;
begin
  LCollectExpected := 0;
  if not atomic_compare_exchange_strong(FCollecting, LCollectExpected, 1,
    mo_acq_rel, mo_acquire) then
    Exit;
  LList := nil;
  try
    if atomic_load(FActiveCount, mo_acquire) = 0 then
      LList := PEbrRetiredNode(
        atomic_exchange(Pointer(FRetired), nil, mo_acq_rel));
  finally
    atomic_store(FCollecting, 0, mo_release);
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
    atomic_fetch_sub_64(FRetiredCount, LReclaimedCount, mo_acq_rel);
end;

function TEbrDomain.ActiveCount: PtrUInt; inline;
begin
  Result := PtrUInt(atomic_load(FActiveCount, mo_acquire));
end;

function TEbrDomain.RetiredCount: PtrUInt; inline;
begin
  Result := PtrUInt(atomic_load_64(FRetiredCount, mo_acquire));
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
