unit nextpas.core.async.task;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.async.base;

type
  TAsyncTaskStatus = nextpas.core.async.base.TAsyncTaskStatus;

  PAsyncTask = ^TAsyncTask;
  TAsyncTask = record
  private
    FStatus: TAsyncTaskStatus;
    FResult: Int32;
    FOnComplete: TAsyncCallback;
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
  end;

implementation

{ TAsyncTask }

class function TAsyncTask.Create: TAsyncTask;
begin
  Result := Default(TAsyncTask);
  Result.FStatus := atsIdle;
end;

procedure TAsyncTask.Finish(AStatus: TAsyncTaskStatus; AResult: Int32);
var
  LCallback: TAsyncCallback;
  LContext: Pointer;
begin
  if FStatus in [atsCompleted, atsFailed, atsTimedOut, atsCancelled] then
    Exit;
  FStatus := AStatus;
  FResult := AResult;
  LCallback := FOnComplete;
  LContext := FOnCompleteCtx;
  FOnComplete := nil;
  FOnCompleteCtx := nil;
  if Assigned(LCallback) then
    LCallback(LContext);
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

end.
