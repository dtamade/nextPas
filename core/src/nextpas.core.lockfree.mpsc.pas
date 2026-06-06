unit nextpas.core.lockfree.mpsc;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic.core;

type
  generic TMpscQueue<T> = class
  private
    type
      PNode = ^TNode;
      TNode = record
        Value: T;
        Next: PNode;
      end;
  private
    FHead: PNode;
    FTail: PNode;
    FStub: TNode;
    FClosed: Int32;
    FDataEpoch: Int32;
    FDataWaiters: Int32;
    function AtomicLoadNode(var ANode: PNode; const AOrder: memory_order_t): PNode; inline;
    procedure AtomicStoreNode(var ANode: PNode; const AValue: PNode; const AOrder: memory_order_t); inline;
    function AtomicExchangeNode(var ANode: PNode; const AValue: PNode; const AOrder: memory_order_t): PNode; inline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Enqueue(const AValue: T);
    function TryDequeue(out AValue: T): Boolean;
    function DequeueWait(out AValue: T): Boolean;
    function DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    procedure Close;
    function IsClosed: Boolean;
    function IsEmpty: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.wait,
  nextpas.core.time.base;

function TMpscQueue.AtomicLoadNode(var ANode: PNode; const AOrder: memory_order_t): PNode;
begin
  Result := PNode(atomic_load(PPointer(@ANode)^, AOrder));
end;

procedure TMpscQueue.AtomicStoreNode(var ANode: PNode; const AValue: PNode; const AOrder: memory_order_t);
begin
  atomic_store(PPointer(@ANode)^, Pointer(AValue), AOrder);
end;

function TMpscQueue.AtomicExchangeNode(var ANode: PNode; const AValue: PNode; const AOrder: memory_order_t): PNode;
begin
  Result := PNode(atomic_exchange(PPointer(@ANode)^, Pointer(AValue), AOrder));
end;

constructor TMpscQueue.Create;
begin
  inherited Create;
  if IsManagedType(T) then
    raise EArgumentError.Create('TMpscQueue: T must be unmanaged');
  FStub.Next := nil;
  FHead := @FStub;
  FTail := @FStub;
  FClosed := 0;
  FDataEpoch := 0;
  FDataWaiters := 0;
end;

destructor TMpscQueue.Destroy;
var
  LV: T;
begin
  {$IFDEF DEBUG}
  Assert(FClosed <> 0, 'TMpscQueue.Destroy: Close must be called before Destroy to ensure all producers have stopped');
  {$ENDIF}
  while TryDequeue(LV) do;
  inherited;
end;

procedure TMpscQueue.Enqueue(const AValue: T);
var
  LNode, LPrev: PNode;
begin
  New(LNode);
  LNode^.Value := AValue;
  LNode^.Next := nil;
  LPrev := AtomicExchangeNode(FHead, LNode, mo_acq_rel);
  AtomicStoreNode(LPrev^.Next, LNode, mo_release);
  LockFreeNotifyData(@FDataEpoch, @FDataWaiters);
end;

function TMpscQueue.TryDequeue(out AValue: T): Boolean;
var
  LTail, LNext, LPrev: PNode;
begin
  LTail := FTail;
  LNext := AtomicLoadNode(LTail^.Next, mo_acquire);
  if LTail = @FStub then
  begin
    if LNext = nil then
      Exit(False);
    FTail := LNext;
    LTail := LNext;
    LNext := AtomicLoadNode(LTail^.Next, mo_acquire);
  end;
  if LNext <> nil then
  begin
    FTail := LNext;
    AValue := LTail^.Value;
    Dispose(LTail);
    Result := True;
    Exit;
  end;
  if LTail <> AtomicLoadNode(FHead, mo_acquire) then
    Exit(False);
  FStub.Next := nil;
  LPrev := AtomicExchangeNode(FHead, @FStub, mo_acq_rel);
  AtomicStoreNode(LPrev^.Next, @FStub, mo_release);
  LNext := AtomicLoadNode(LTail^.Next, mo_acquire);
  if LNext <> nil then
  begin
    FTail := LNext;
    AValue := LTail^.Value;
    Dispose(LTail);
    Result := True;
    Exit;
  end;
  Result := False;
end;

function TMpscQueue.DequeueWait(out AValue: T): Boolean;
var
  LEpoch: Int32;
begin
  if TryDequeue(AValue) then
    Exit(True);
  while True do
  begin
    LEpoch := AtomicLoad32(FDataEpoch, moAcquire);
    if TryDequeue(AValue) then
      Exit(True);
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(TryDequeue(AValue));
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, -1);
  end;
end;

function TMpscQueue.DequeueTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
var
  LEpoch: Int32;
  LStart: TInstant;
  LRemaining: Int64;
begin
  if TryDequeue(AValue) then
    Exit(True);
  LStart := TInstant.Now;
  while True do
  begin
    LRemaining := ATimeoutNs - LStart.Elapsed.AsNanoseconds;
    if LRemaining <= 0 then
      Exit(TryDequeue(AValue));
    LEpoch := AtomicLoad32(FDataEpoch, moAcquire);
    if TryDequeue(AValue) then
      Exit(True);
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(TryDequeue(AValue));
    LockFreeWaitData(@FDataEpoch, @FDataWaiters, LRemaining);
  end;
end;

procedure TMpscQueue.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
  LockFreeWakeAll(@FDataEpoch);
end;

function TMpscQueue.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TMpscQueue.IsEmpty: Boolean;
var
  LTail, LNext: PNode;
begin
  LTail := FTail;
  LNext := AtomicLoadNode(LTail^.Next, mo_acquire);
  if LTail = @FStub then
    Result := LNext = nil
  else
    Result := False;
end;

end.
