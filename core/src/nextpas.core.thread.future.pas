unit nextpas.core.thread.future;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.thread.base,
  nextpas.core.thread.intf;

type
  generic TFuturePromise<T> = class(TInterfacedObject,
    specialize IFuture<T>, specialize IPromise<T>)
  private
    FState: Int32;
    FValue: T;
    FErrorClass: ExceptClass;
    FErrorMsg: string;
    FMutex: IInterface;
    FEvent: IInterface;
    procedure WaitDone;
    function GetState: TFutureState;
  public
    constructor Create;
    function Wait: T;
    function WaitTimeout(const ATimeoutNs: Int64): Boolean;
    function State: TFutureState;
    function IsDone: Boolean;
    function Get: T;
    procedure Complete(const AValue: T);
    procedure Fail(const AError: Exception);
    procedure Cancel;
    function GetFuture: specialize IFuture<T>;
  end;

function CreateFutureVoid: IFutureVoid;
procedure FutureVoidComplete(const AFuture: IFutureVoid);
function WhenAll(const AFutures: array of IFutureVoid): IFutureVoid;
function WhenAny(const AFutures: array of IFutureVoid): IFutureVoid;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.sync,
  nextpas.core.sync.intf,
  nextpas.core.platform.thread;

constructor TFuturePromise.Create;
begin
  inherited Create;
  FState := Int32(Ord(fsPending));
  FErrorClass := nil;
  FErrorMsg := '';
  FMutex := Mutex;
  FEvent := Event(True);
end;

procedure TFuturePromise.WaitDone;
begin
  (FEvent as IEvent).Wait;
end;

function TFuturePromise.GetState: TFutureState;
begin
  Result := TFutureState(AtomicLoad32(FState, moAcquire));
end;

function TFuturePromise.Wait: T;
begin
  WaitDone;
  case GetState of
    fsCompleted: Result := FValue;
    fsFailed: raise FErrorClass.Create(FErrorMsg);
    fsCancelled: raise ECancelledError.Create('future cancelled');
  else
    raise EInvalidOperationError.Create('future not done');
  end;
end;

function TFuturePromise.WaitTimeout(const ATimeoutNs: Int64): Boolean;
begin
  Result := (FEvent as IEvent).WaitTimeout(ATimeoutNs);
end;

function TFuturePromise.State: TFutureState;
begin
  Result := GetState;
end;

function TFuturePromise.IsDone: Boolean;
begin
  Result := GetState <> fsPending;
end;

function TFuturePromise.Get: T;
begin
  if GetState = fsPending then
    raise EInvalidOperationError.Create('future not done');
  Result := Wait;
end;

procedure TFuturePromise.Complete(const AValue: T);
begin
  (FMutex as IMutex).Acquire;
  try
    if TFutureState(AtomicLoad32(FState, moAcquire)) <> fsPending then
      raise EInvalidOperationError.Create('future already resolved');
    FValue := AValue;
    AtomicStore32(FState, Int32(Ord(fsCompleted)), moRelease);
  finally
    (FMutex as IMutex).Release;
  end;
  (FEvent as IEvent).SetEvent;
end;

procedure TFuturePromise.Fail(const AError: Exception);
begin
  (FMutex as IMutex).Acquire;
  try
    if TFutureState(AtomicLoad32(FState, moAcquire)) <> fsPending then
      raise EInvalidOperationError.Create('future already resolved');
    FErrorClass := ExceptClass(AError.ClassType);
    FErrorMsg := AError.Message;
    AtomicStore32(FState, Int32(Ord(fsFailed)), moRelease);
  finally
    (FMutex as IMutex).Release;
  end;
  AError.Free;
  (FEvent as IEvent).SetEvent;
end;

procedure TFuturePromise.Cancel;
begin
  (FMutex as IMutex).Acquire;
  try
    if TFutureState(AtomicLoad32(FState, moAcquire)) <> fsPending then
      Exit;
    AtomicStore32(FState, Int32(Ord(fsCancelled)), moRelease);
  finally
    (FMutex as IMutex).Release;
  end;
  (FEvent as IEvent).SetEvent;
end;

function TFuturePromise.GetFuture: specialize IFuture<T>;
begin
  Result := Self;
end;

{ TFutureVoid — non-generic void future for combinators }

type
  TFutureVoid = class(TInterfacedObject, IFutureVoid)
  private
    FEvent: IEvent;
    FDone: Int32;
  public
    constructor Create;
    procedure Wait;
    function WaitTimeout(const ATimeoutNs: Int64): Boolean;
    function IsDone: Boolean;
    procedure MarkDone;
  end;

constructor TFutureVoid.Create;
begin
  inherited Create;
  FDone := 0;
  FEvent := nextpas.core.sync.Event(True);
end;

procedure TFutureVoid.Wait;
begin
  FEvent.Wait;
end;

function TFutureVoid.WaitTimeout(const ATimeoutNs: Int64): Boolean;
begin
  Result := FEvent.WaitTimeout(ATimeoutNs);
end;

function TFutureVoid.IsDone: Boolean;
begin
  Result := AtomicLoad32(FDone, moAcquire) <> 0;
end;

procedure TFutureVoid.MarkDone;
begin
  AtomicStore32(FDone, 1, moRelease);
  FEvent.SetEvent;
end;

function CreateFutureVoid: IFutureVoid;
begin
  Result := TFutureVoid.Create;
end;

procedure FutureVoidComplete(const AFuture: IFutureVoid);
begin
  (AFuture as TFutureVoid).MarkDone;
end;

{ WhenAll — returns a future that completes when all inputs are done }

type
  TWhenAllState = class(TInterfacedObject, IFutureVoid)
  private
    FRemaining: Int32;
    FEvent: IEvent;
  public
    constructor Create(const ACount: Int32);
    procedure DecrementAndCheck;
    procedure Wait;
    function WaitTimeout(const ATimeoutNs: Int64): Boolean;
    function IsDone: Boolean;
  end;

constructor TWhenAllState.Create(const ACount: Int32);
begin
  inherited Create;
  FRemaining := ACount;
  FEvent := nextpas.core.sync.Event(True);
  if ACount = 0 then
    FEvent.SetEvent;
end;

procedure TWhenAllState.DecrementAndCheck;
begin
  if AtomicFetchSub32(FRemaining, 1, moAcqRel) = 1 then
    FEvent.SetEvent;
end;

procedure TWhenAllState.Wait;
begin
  FEvent.Wait;
end;

function TWhenAllState.WaitTimeout(const ATimeoutNs: Int64): Boolean;
begin
  Result := FEvent.WaitTimeout(ATimeoutNs);
end;

function TWhenAllState.IsDone: Boolean;
begin
  Result := AtomicLoad32(FRemaining, moAcquire) = 0;
end;

function WhenAll(const AFutures: array of IFutureVoid): IFutureVoid;
var
  LI: Integer;
  LResult: TFutureVoid;
begin
  LResult := TFutureVoid.Create;
  for LI := 0 to High(AFutures) do
    AFutures[LI].Wait;
  LResult.MarkDone;
  Result := LResult;
end;

{ WhenAny — returns when any one input is done }

function WhenAny(const AFutures: array of IFutureVoid): IFutureVoid;
var
  LI: Integer;
begin
  Result := TFutureVoid.Create;
  for LI := 0 to High(AFutures) do
  begin
    if AFutures[LI].IsDone then
    begin
      (Result as TFutureVoid).MarkDone;
      Exit;
    end;
  end;
  { Poll with short sleep until one is done. }
  while True do
  begin
    for LI := 0 to High(AFutures) do
    begin
      if AFutures[LI].IsDone then
      begin
        (Result as TFutureVoid).MarkDone;
        Exit;
      end;
    end;
    platform_thread_yield;
  end;
end;

end.
