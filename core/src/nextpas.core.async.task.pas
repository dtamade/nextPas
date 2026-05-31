unit nextpas.core.async.task;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.async.base;

type
  TAsyncTaskStatus = (atsIdle, atsPending, atsCompleted, atsFailed, atsTimedOut, atsCancelled);

  PAsyncTask = ^TAsyncTask;
  TAsyncTask = record
  private
    FStatus: TAsyncTaskStatus;
    FResult: Int32;
    FOnComplete: TAsyncCallback;
    FOnCompleteCtx: Pointer;
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

procedure TAsyncTask.Complete(AResult: Int32);
begin
  if FStatus in [atsCompleted, atsFailed, atsTimedOut, atsCancelled] then
    Exit;
  FStatus := atsCompleted;
  FResult := AResult;
  if Assigned(FOnComplete) then
    FOnComplete(FOnCompleteCtx);
end;

procedure TAsyncTask.Fail(AResult: Int32);
begin
  if FStatus in [atsCompleted, atsFailed, atsTimedOut, atsCancelled] then
    Exit;
  FStatus := atsFailed;
  FResult := AResult;
  if Assigned(FOnComplete) then
    FOnComplete(FOnCompleteCtx);
end;

procedure TAsyncTask.Timeout;
begin
  if FStatus in [atsCompleted, atsFailed, atsTimedOut, atsCancelled] then
    Exit;
  FStatus := atsTimedOut;
  FResult := -110;
  if Assigned(FOnComplete) then
    FOnComplete(FOnCompleteCtx);
end;

procedure TAsyncTask.Cancel;
begin
  if FStatus in [atsCompleted, atsFailed, atsTimedOut, atsCancelled] then
    Exit;
  FStatus := atsCancelled;
  FResult := 0;
  if Assigned(FOnComplete) then
    FOnComplete(FOnCompleteCtx);
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
  FOnComplete := ACallback;
  FOnCompleteCtx := AContext;
end;

end.
