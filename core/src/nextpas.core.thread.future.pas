unit nextpas.core.thread.future;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.thread.base,
  nextpas.core.thread.intf;

type
  generic TFuturePromise<T> = class(TInterfacedObject,
    specialize IFuture<T>, specialize IPromise<T>)
  private
    FState: TFutureState;
    FValue: T;
    FErrorClass: ExceptClass;
    FErrorMsg: string;
    FMutex: IInterface;
    FEvent: IInterface;
    procedure WaitDone;
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

implementation

uses
  nextpas.core.errors,
  nextpas.core.sync,
  nextpas.core.sync.intf;

constructor TFuturePromise.Create;
begin
  inherited Create;
  FState := fsPending;
  FErrorClass := nil;
  FErrorMsg := '';
  FMutex := Mutex;
  FEvent := Event(True);
end;

procedure TFuturePromise.WaitDone;
begin
  (FEvent as IEvent).Wait;
end;

function TFuturePromise.Wait: T;
begin
  WaitDone;
  case FState of
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
  Result := FState;
end;

function TFuturePromise.IsDone: Boolean;
begin
  Result := FState <> fsPending;
end;

function TFuturePromise.Get: T;
begin
  if FState = fsPending then
    raise EInvalidOperationError.Create('future not done');
  Result := Wait;
end;

procedure TFuturePromise.Complete(const AValue: T);
begin
  (FMutex as IMutex).Acquire;
  try
    if FState <> fsPending then
      raise EInvalidOperationError.Create('future already resolved');
    FValue := AValue;
    FState := fsCompleted;
  finally
    (FMutex as IMutex).Release;
  end;
  (FEvent as IEvent).SetEvent;
end;

procedure TFuturePromise.Fail(const AError: Exception);
begin
  (FMutex as IMutex).Acquire;
  try
    if FState <> fsPending then
      raise EInvalidOperationError.Create('future already resolved');
    FErrorClass := ExceptClass(AError.ClassType);
    FErrorMsg := AError.Message;
    FState := fsFailed;
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
    if FState <> fsPending then
      Exit;
    FState := fsCancelled;
  finally
    (FMutex as IMutex).Release;
  end;
  (FEvent as IEvent).SetEvent;
end;

function TFuturePromise.GetFuture: specialize IFuture<T>;
begin
  Result := Self;
end;

end.
