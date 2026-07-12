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
 *
 * @see Work Stealing — Blumofe & Leiserson, 1999
 * @see Cilk — work-stealing based parallel programming
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
    FTop: Int64;
    {$PUSH} {$WARN 05029 OFF}
    FPadTop: TCacheLinePad;
    {$POP}
    FBottom: Int64;
    {$PUSH} {$WARN 05029 OFF}
    FPadBottom: TCacheLinePad;
    {$POP}
    FClosed: Int32;
  public
    constructor Create(const ACapacity: PtrUInt);
    function TryPush(const AValue: T): Boolean;
    function TryPop(out AValue: T): Boolean;
    function TrySteal(out AValue: T): Boolean;
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
  nextpas.core.atomic;

constructor TWorkStealingDequeImpl.Create(const ACapacity: PtrUInt);
var
  LCap: PtrUInt;
begin
  if IsManagedType(T) then
    raise EArgumentError.Create('TWorkStealingDeque: T must be unmanaged');
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
end;

function TWorkStealingDequeImpl.TryPush(const AValue: T): Boolean;
var
  LBottom, LTop, LSize: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  LBottom := AtomicLoad64(FBottom, moRelaxed);
  LTop := AtomicLoad64(FTop, moAcquire);
  LSize := LBottom - LTop;
  if LSize >= Int64(FCapacity) then
    Exit(False);
  FBuffer[PtrUInt(LBottom) and FMask] := AValue;
  AtomicStore64(FBottom, LBottom + 1, moRelease);
  Result := True;
end;

function TWorkStealingDequeImpl.TryPop(out AValue: T): Boolean;
var
  LBottom, LTop: Int64;
begin
  LBottom := AtomicLoad64(FBottom, moRelaxed) - 1;
  AtomicStore64(FBottom, LBottom, moSeqCst);
  LTop := AtomicLoad64(FTop, moSeqCst);
  if LTop <= LBottom then
  begin
    AValue := FBuffer[PtrUInt(LBottom) and FMask];
    if LTop = LBottom then
    begin
      if AtomicCompareExchange64(FTop, LTop, LTop + 1, moSeqCst) <> LTop then
      begin
        AtomicStore64(FBottom, LBottom + 1, moRelaxed);
        Exit(False);
      end;
      AtomicStore64(FBottom, LBottom + 1, moRelaxed);
    end;
    Result := True;
  end
  else
  begin
    AtomicStore64(FBottom, LBottom + 1, moRelaxed);
    Result := False;
  end;
end;

function TWorkStealingDequeImpl.TrySteal(out AValue: T): Boolean;
var
  LTop, LBottom: Int64;
begin
  LTop := AtomicLoad64(FTop, moSeqCst);
  LBottom := AtomicLoad64(FBottom, moSeqCst);
  if LTop >= LBottom then
    Exit(False);
  AValue := FBuffer[PtrUInt(LTop) and FMask];
  if AtomicCompareExchange64(FTop, LTop, LTop + 1, moSeqCst) <> LTop then
    Exit(False);
  Result := True;
end;

function TWorkStealingDequeImpl.IsEmpty: Boolean; inline;
var
  LTop, LBottom: Int64;
begin
  LTop := AtomicLoad64(FTop, moAcquire);
  LBottom := AtomicLoad64(FBottom, moAcquire);
  Result := LTop >= LBottom;
end;

procedure TWorkStealingDequeImpl.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TWorkStealingDequeImpl.IsClosed: Boolean; inline;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TWorkStealingDequeImpl.ApproxCount: PtrUInt; inline;
var
  LTop, LBottom: Int64;
begin
  LTop := AtomicLoad64(FTop, moAcquire);
  LBottom := AtomicLoad64(FBottom, moAcquire);
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
