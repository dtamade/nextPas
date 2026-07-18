unit nextpas.core.async.task;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.async.base;

type
  TAsyncTaskStatus = nextpas.core.async.base.TAsyncTaskStatus;

  { Flexible callback storage for multi-form completion hooks }
  TAsyncCallbackStorage = record
    Regular: TAsyncCallback;
    Ref: TAsyncCallbackRef;
    Method: TAsyncCallbackMethod;
    Context: Pointer;
    procedure Invoke;
    function IsEmpty: Boolean;
  end;

  PAsyncTask = ^TAsyncTask;
  TAsyncTask = record
  private
    FStatus: TAsyncTaskStatus;
    FResult: Int32;
    FOnComplete: TAsyncCallback;
    FOnCompleteRef: TAsyncCallbackRef;
    FOnCompleteMethod: TAsyncCallbackMethod;
    FOnCompleteCtx: Pointer;
    procedure Finish(AStatus: TAsyncTaskStatus; AResult: Int32);
  public
    class function Create: TAsyncTask; static;
    procedure Complete(AResult: Int32);
    procedure Fail(AResult: Int32);
    procedure Timeout;
    procedure Cancel;
    function Status: TAsyncTaskStatus; inline;
    function IsCompleted: Boolean; inline;
    function IsDone: Boolean; inline;
    function GetResult: Int32; inline;
    procedure OnComplete(ACallback: TAsyncCallback; AContext: Pointer);
    procedure OnCompleteRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
    procedure OnCompleteMethod(ACallback: TAsyncCallbackMethod; AContext: Pointer);
  end;

implementation

{ TAsyncCallbackStorage }

procedure TAsyncCallbackStorage.Invoke;
begin
  if Assigned(Regular) then
    Regular(Context)
  else if Assigned(Ref) then
    Ref(Context)
  else if Assigned(Method) then
    Method(Context);
end;

function TAsyncCallbackStorage.IsEmpty: Boolean;
begin
  Result := not Assigned(Regular) and not Assigned(Ref) and not Assigned(Method);
end;

{ TAsyncTask }

class function TAsyncTask.Create: TAsyncTask;
begin
  Result := Default(TAsyncTask);
  Result.FStatus := atsIdle;
end;

procedure TAsyncTask.Finish(AStatus: TAsyncTaskStatus; AResult: Int32);
var
  LCallback: TAsyncCallback;
  LRef: TAsyncCallbackRef;
  LMethod: TAsyncCallbackMethod;
  LContext: Pointer;
begin
  if FStatus in [atsCompleted, atsFailed, atsTimedOut, atsCancelled] then
    Exit;
  FStatus := AStatus;
  FResult := AResult;
  LCallback := FOnComplete;
  LRef := FOnCompleteRef;
  LMethod := FOnCompleteMethod;
  LContext := FOnCompleteCtx;
  FOnComplete := nil;
  FOnCompleteRef := nil;
  FOnCompleteMethod := nil;
  FOnCompleteCtx := nil;
  if Assigned(LCallback) then
    LCallback(LContext);
  if (not Assigned(LCallback)) and Assigned(LRef) then
    LRef(LContext);
  if (not Assigned(LCallback)) and (not Assigned(LRef)) and Assigned(LMethod) then
    LMethod(LContext);
end;

procedure TAsyncTask.Complete(AResult: Int32);
begin
  Finish(atsCompleted, AResult);
end;

procedure TAsyncTask.Fail(AResult: Int32);
begin
  Finish(atsFailed, AResult);
end;

procedure TAsyncTask.Timeout;
begin
  Finish(atsTimedOut, -110);
end;

procedure TAsyncTask.Cancel;
begin
  Finish(atsCancelled, 0);
end;

function TAsyncTask.Status: TAsyncTaskStatus;
begin
  Result := FStatus;
end;

function TAsyncTask.IsCompleted: Boolean;
begin
  Result := FStatus = atsCompleted;
end;

function TAsyncTask.IsDone: Boolean;
begin
  Result := FStatus in [atsCompleted, atsFailed, atsTimedOut, atsCancelled];
end;

function TAsyncTask.GetResult: Int32;
begin
  Result := FResult;
end;

procedure TAsyncTask.OnComplete(ACallback: TAsyncCallback; AContext: Pointer);
begin
  if IsDone then
  begin
    if Assigned(ACallback) then
      ACallback(AContext);
    Exit;
  end;
  FOnComplete := ACallback;
  FOnCompleteCtx := AContext;
end;

procedure TAsyncTask.OnCompleteRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
begin
  if IsDone then
  begin
    if Assigned(ACallback) then
      ACallback(AContext);
    Exit;
  end;
  FOnCompleteRef := ACallback;
  FOnCompleteCtx := AContext;
end;

procedure TAsyncTask.OnCompleteMethod(ACallback: TAsyncCallbackMethod; AContext: Pointer);
begin
  if IsDone then
  begin
    if Assigned(ACallback) then
      ACallback(AContext);
    Exit;
  end;
  FOnCompleteMethod := ACallback;
  FOnCompleteCtx := AContext;
end;

end.
