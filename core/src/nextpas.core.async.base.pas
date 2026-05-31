unit nextpas.core.async.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base, nextpas.core.time.deadline;

type
  TAsyncCallback = procedure(AContext: Pointer);

  TAsyncTimerHandle = record
    FId: UInt32;
    FGen: UInt32;
    class function None: TAsyncTimerHandle; static; inline;
    function IsValid: Boolean; inline;
  end;

  TAsyncTaskState = (atsPending, atsCompleted, atsFailed, atsCancelled);

implementation

{ TAsyncTimerHandle }

class function TAsyncTimerHandle.None: TAsyncTimerHandle;
begin
  Result.FId := High(UInt32);
  Result.FGen := 0;
end;

function TAsyncTimerHandle.IsValid: Boolean;
begin
  Result := FId <> High(UInt32);
end;

end.
