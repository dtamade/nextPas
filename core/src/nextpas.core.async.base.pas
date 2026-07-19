unit nextpas.core.async.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.base,
  nextpas.core.time.base, nextpas.core.time.deadline;

type
  TAsyncCallback = procedure(AContext: Pointer);

  { Anonymous procedure reference for async callbacks }
  TAsyncCallbackRef = reference to procedure(AContext: Pointer);

  { Method pointer for async callbacks }
  TAsyncCallbackMethod = procedure(AContext: Pointer) of object;

  { I/O completion callback types — re-export from io.base }
  TIoCompletion = nextpas.core.io.base.TIoCompletion;
  TIoCompletionRef = nextpas.core.io.base.TIoCompletionRef;

  TAsyncTimerHandle = record
    FId: UInt32;
    FGen: UInt32;
    class function None: TAsyncTimerHandle; static; inline;
    function IsValid: Boolean; inline;
  end;

  TAsyncTaskState = (atsIdle, atsPending, atsCompleted, atsFailed, atsTimedOut, atsCancelled);
  TAsyncTaskStatus = TAsyncTaskState;

  { Ref→Callback 桥接上下文 }
  PIoCompletionRefCtx = ^TIoCompletionRefCtx;
  TIoCompletionRefCtx = record
    Ref: TIoCompletionRef;
    Context: Pointer;
  end;

{ Ref 回调包装：将 TIoCompletionRef 适配为 TIoCompletion }
procedure IoCompletionRefWrapper(AUserData: UInt64; AResult: Int32; AContext: Pointer);

{ 创建 Ref 上下文（调用方负责 Dispose） }
function WrapIoCompletionRef(ACallback: TIoCompletionRef;
  AContext: Pointer): Pointer;

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

{ IoCompletionRefWrapper }

procedure IoCompletionRefWrapper(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LCtx: PIoCompletionRefCtx;
begin
  LCtx := PIoCompletionRefCtx(AContext);
  try
    LCtx^.Ref(AUserData, AResult, LCtx^.Context);
  finally
    Dispose(LCtx);
  end;
end;

function WrapIoCompletionRef(ACallback: TIoCompletionRef;
  AContext: Pointer): Pointer;
var
  LCtx: PIoCompletionRefCtx;
begin
  New(LCtx);
  LCtx^.Ref := ACallback;
  LCtx^.Context := AContext;
  Result := LCtx;
end;

end.
