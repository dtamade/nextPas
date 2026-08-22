unit nextpas.core.lockfree.deque;
{**
 * @desc Lock-free work-stealing deque.
 *
 * @details Array-based deque for work-stealing algorithms:
 *   - Owner thread: LIFO push/pop (cache-friendly)
 *   - Thief threads: FIFO steal (load balancing)
 *   - Bounded capacity (power-of-2 required)
 *   - Close semantics with drain support
 *
 * @concurrency Thread-safe for owner and multiple thieves:
 *   - TryPush/TryPop: only owner thread can call
 *   - TrySteal: multiple thief threads compete via CAS
 *   - Close: safe to call from any thread
 *   - $IFDEF LOCKFREE_DEBUG: claim/check owner thread on push/pop (audit F-005)
 *
 * @see Work Stealing — Blumofe & Leiserson, 1999
 * @see Cilk — work-stealing based parallel programming
 *
 * Preferred atomics: atomic_* + mo_* (Go/Rust parity / Q2).
 * Last-item owner/thief arbitration uses mo_seq_cst on top/bottom.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  generic TWorkStealingDequeImpl<T> = class
  private
    type
      TItemArray = array of T;
  private
    FBuffer: TItemArray;
    FCapacity: PtrUInt;
    FMask: PtrUInt;
    {$PUSH} {$WARN 05029 OFF} // keep the read-mostly header off the hot lines
    FPadHeader: TCacheLinePad;
    {$POP}
    FTop: Int64;
    {$PUSH} {$WARN 05029 OFF}
    FPadTop: TCacheLinePad;
    {$POP}
    FBottom: Int64;
    {$PUSH} {$WARN 05029 OFF}
    FPadBottom: TCacheLinePad;
    {$POP}
    FClosed: Int32;
    {$IFDEF LOCKFREE_DEBUG}
    FOwnerThreadId: UInt64;
    procedure DebugClaimOwner; inline;
    {$ENDIF}
  public
    constructor Create(const ACapacity: PtrUInt);
    destructor Destroy; override;
    function TryPush(const AValue: T): Boolean;
    {** @desc Owner push with full/closed diagnostic; Boolean hot path unchanged. }
    function TryPushEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
    function TryPop(out AValue: T): Boolean;
    {** @desc Owner pop with empty/closed-empty diagnostic; Boolean hot path unchanged. }
    function TryPopEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
    function TrySteal(out AValue: T): Boolean;
    {** @desc Thief steal with empty/closed-empty diagnostic; CAS race may report empty. }
    function TryStealEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
    function Drain(const AMaxCount: PtrUInt = High(PtrUInt)): PtrUInt;
    procedure Close;
    function IsClosed: Boolean; inline;
    function IsEmpty: Boolean; inline;
    function ApproxCount: PtrUInt; inline;
    function Capacity: PtrUInt; inline;
  end;

  generic TWorkStealingDeque<T> = class(specialize TWorkStealingDequeImpl<T>)
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic
  {$IFDEF LOCKFREE_DEBUG}
  , nextpas.core.platform.thread
  {$ENDIF};

constructor TWorkStealingDequeImpl.Create(const ACapacity: PtrUInt);
var
  LCap: PtrUInt;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TWorkStealingDeque: T must be unmanaged (no string/interface/dynarray)');
  if ACapacity = 0 then
    raise EArgumentError.Create('TWorkStealingDeque: capacity must be > 0');
  inherited Create;
  LCap := LockFreeNextPow2(ACapacity);
  FCapacity := LCap;
  FMask := LCap - 1;
  SetLength(FBuffer, LCap);
  FTop := 0;
  FBottom := 0;
  FClosed := 0;
  {$IFDEF LOCKFREE_DEBUG}
  FOwnerThreadId := 0;
  {$ENDIF}
end;

{$IFDEF LOCKFREE_DEBUG}
procedure TWorkStealingDequeImpl.DebugClaimOwner;
var
  LSelf: UInt64;
begin
  LSelf := platform_thread_id;
  if FOwnerThreadId = 0 then
    FOwnerThreadId := LSelf
  else if FOwnerThreadId <> LSelf then
    raise EInvalidOperationError.Create(
      'TWorkStealingDeque LOCKFREE_DEBUG: push/pop must run on a single owner thread');
end;
{$ENDIF}

function TWorkStealingDequeImpl.TryPush(const AValue: T): Boolean;
var
  LBottom, LTop, LSize: Int64;
begin
  {$IFDEF LOCKFREE_DEBUG}
  DebugClaimOwner;
  {$ENDIF}
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  LBottom := atomic_load_64(FBottom, mo_relaxed);
  LTop := atomic_load_64(FTop, mo_acquire);
  LSize := LBottom - LTop;
  if LSize >= Int64(FCapacity) then
    Exit(False);
  FBuffer[PtrUInt(LBottom) and FMask] := AValue;
  atomic_store_64(FBottom, LBottom + 1, mo_release);
  Result := True;
end;

function TWorkStealingDequeImpl.TryPushEx(const AValue: T; out AError: TLockFreeTryError): Boolean;
begin
  if TryPush(AValue) then
  begin
    AError := lfteNone;
    Exit(True);
  end;
  if IsClosed then
    AError := lfteClosed
  else
    AError := lfteFull;
  Result := False;
end;

function TWorkStealingDequeImpl.TryPop(out AValue: T): Boolean;
var
  LBottom, LTop: Int64;
  LExpected: Int64;
begin
  {$IFDEF LOCKFREE_DEBUG}
  DebugClaimOwner;
  {$ENDIF}
  LBottom := atomic_load_64(FBottom, mo_relaxed) - 1;
  atomic_store_64(FBottom, LBottom, mo_seq_cst);
  LTop := atomic_load_64(FTop, mo_seq_cst);
  if LTop <= LBottom then
  begin
    AValue := FBuffer[PtrUInt(LBottom) and FMask];
    if LTop = LBottom then
    begin
      LExpected := LTop;
      if not atomic_compare_exchange_strong_64(FTop, LExpected, LTop + 1,
        mo_seq_cst, mo_seq_cst) then
      begin
        atomic_store_64(FBottom, LBottom + 1, mo_relaxed);
        Exit(False);
      end;
      atomic_store_64(FBottom, LBottom + 1, mo_relaxed);
    end;
    Result := True;
  end
  else
  begin
    atomic_store_64(FBottom, LBottom + 1, mo_relaxed);
    Result := False;
  end;
end;

function TWorkStealingDequeImpl.TryPopEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
begin
  if TryPop(AValue) then
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

function TWorkStealingDequeImpl.TrySteal(out AValue: T): Boolean;
var
  LTop, LBottom: Int64;
  LExpected: Int64;
begin
  LTop := atomic_load_64(FTop, mo_seq_cst);
  LBottom := atomic_load_64(FBottom, mo_seq_cst);
  if LTop >= LBottom then
    Exit(False);
  AValue := FBuffer[PtrUInt(LTop) and FMask];
  LExpected := LTop;
  if not atomic_compare_exchange_strong_64(FTop, LExpected, LTop + 1,
    mo_seq_cst, mo_seq_cst) then
    Exit(False);
  Result := True;
end;

function TWorkStealingDequeImpl.TryStealEx(out AValue: T; out AError: TLockFreeTryError): Boolean;
begin
  if TrySteal(AValue) then
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

function TWorkStealingDequeImpl.IsEmpty: Boolean; inline;
var
  LTop, LBottom: Int64;
begin
  LTop := atomic_load_64(FTop, mo_acquire);
  LBottom := atomic_load_64(FBottom, mo_acquire);
  Result := LTop >= LBottom;
end;

function TWorkStealingDequeImpl.Drain(const AMaxCount: PtrUInt): PtrUInt;
var
  LValue: T;
  LCount: PtrUInt;
begin
  LCount := 0;
  while LCount < AMaxCount do
  begin
    if not TryPop(LValue) then
      Break;
    Inc(LCount);
  end;
  Result := LCount;
end;

procedure TWorkStealingDequeImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

destructor TWorkStealingDequeImpl.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TWorkStealingDequeImpl.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TWorkStealingDequeImpl.ApproxCount: PtrUInt; inline;
var
  LTop, LBottom: Int64;
begin
  LTop := atomic_load_64(FTop, mo_acquire);
  LBottom := atomic_load_64(FBottom, mo_acquire);
  if LBottom > LTop then
    Result := PtrUInt(LBottom - LTop)
  else
    Result := 0;
end;

function TWorkStealingDequeImpl.Capacity: PtrUInt; inline;
begin
  Result := FCapacity;
end;

end.
