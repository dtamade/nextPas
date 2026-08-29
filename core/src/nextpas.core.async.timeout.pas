unit nextpas.core.async.timeout;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.async.base,
  nextpas.core.async.loop;

type
  { 超时操作的结果 }
  TAsyncTimeoutResult = (
    atrCompleted,  { 操作在超时前完成 }
    atrTimedOut,   { 操作超时 }
    atrCancelled   { 操作被取消 }
  );

  { 超时句柄，可用于取消 }
  IAsyncTimeout = interface
    ['{A8F5E2D1-7C3B-4A9E-8D6F-1B5C9E7A2D4F}']
    { 取消超时监控 }
    procedure Cancel;
    { 剩余时间（毫秒），0 表示已超时 }
    function RemainingMs: UInt32;
    { 是否已完成（超时或操作完成） }
    function IsDone: Boolean;
    { 获取结果 }
    function GetResult: TAsyncTimeoutResult;
  end;

  { 通用超时包装：在 AMs 毫秒内执行 AOperation，超时则调用 AOnComplete }
  function AsyncRunWithTimeout(const ALoop: TAsyncLoop; AMs: UInt32;
    AOperation: TAsyncCallback; AOpContext: Pointer;
    AOnComplete: TAsyncCallback; ACompleteContext: Pointer): IAsyncTimeout;

  { Ref 版本 }
  function AsyncRunWithTimeoutRef(const ALoop: TAsyncLoop; AMs: UInt32;
    AOperation: TAsyncCallbackRef; AOpContext: Pointer;
    AOnComplete: TAsyncCallbackRef; ACompleteContext: Pointer): IAsyncTimeout;

implementation

uses
  nextpas.core.platform.sync;

type

  TAsyncTimeoutHandle = class(TInterfacedObject, IAsyncTimeout)
  private
    FLoop: TAsyncLoop;
    FTimerHandle: TAsyncTimerHandle;
    FDeadline: TDeadline;
    FTimeoutMs: UInt32;
    FDone: Boolean;
    FTimeoutResult: TAsyncTimeoutResult;
    FOnComplete: TAsyncCallback;
    FOnCompleteRef: TAsyncCallbackRef;
    FCompleteContext: Pointer;
    FLock: TPlatformMutex;
  public
    constructor Create(const ALoop: TAsyncLoop; AMs: UInt32;
      AOnComplete: TAsyncCallback; AOnCompleteRef: TAsyncCallbackRef;
      ACompleteContext: Pointer);
    destructor Destroy; override;
    procedure Cancel;
    function RemainingMs: UInt32;
    function IsDone: Boolean;
    function GetResult: TAsyncTimeoutResult;
    procedure HandleTimeout;
    procedure HandleComplete;
  end;

{ 定时器回调：通过 AContext 恢复实例引用，无需全局变量 }
procedure TimeoutCallback(AContext: Pointer);
var
  LHandle: TAsyncTimeoutHandle;
begin
  LHandle := TAsyncTimeoutHandle(AContext);
  LHandle.HandleTimeout;
end;

function AsyncRunWithTimeout(const ALoop: TAsyncLoop; AMs: UInt32;
  AOperation: TAsyncCallback; AOpContext: Pointer;
  AOnComplete: TAsyncCallback; ACompleteContext: Pointer): IAsyncTimeout;
var
  LHandle: TAsyncTimeoutHandle;
begin
  LHandle := TAsyncTimeoutHandle.Create(ALoop, AMs, AOnComplete, nil, ACompleteContext);
  Result := LHandle;
  { 启动超时定时器，通过 AContext 传递实例指针 }
  LHandle.FTimerHandle := ALoop.Schedule(TDuration.FromMilliseconds(AMs),
    @TimeoutCallback, Pointer(LHandle));
  { 执行操作，完成后取消定时器避免 HandleComplete 常驻 }
  try
    AOperation(AOpContext);
    LHandle.HandleComplete;
  except
    LHandle.Cancel;
    raise;
  end;
end;

function AsyncRunWithTimeoutRef(const ALoop: TAsyncLoop; AMs: UInt32;
  AOperation: TAsyncCallbackRef; AOpContext: Pointer;
  AOnComplete: TAsyncCallbackRef; ACompleteContext: Pointer): IAsyncTimeout;
var
  LHandle: TAsyncTimeoutHandle;
begin
  LHandle := TAsyncTimeoutHandle.Create(ALoop, AMs, nil, AOnComplete, ACompleteContext);
  Result := LHandle;
  { 启动超时定时器，通过 AContext 传递实例指针 }
  LHandle.FTimerHandle := ALoop.Schedule(TDuration.FromMilliseconds(AMs),
    @TimeoutCallback, Pointer(LHandle));
  { 执行操作，完成后取消定时器避免 HandleComplete 常驻 }
  try
    AOperation(AOpContext);
    LHandle.HandleComplete;
  except
    LHandle.Cancel;
    raise;
  end;
end;

{ TAsyncTimeoutHandle }

constructor TAsyncTimeoutHandle.Create(const ALoop: TAsyncLoop; AMs: UInt32;
  AOnComplete: TAsyncCallback; AOnCompleteRef: TAsyncCallbackRef;
  ACompleteContext: Pointer);
begin
  inherited Create;
  FLoop := ALoop;
  FTimerHandle := TAsyncTimerHandle.None;
  FDeadline := TDeadline.After(TDuration.FromMilliseconds(AMs));
  FTimeoutMs := AMs;
  FDone := False;
  FTimeoutResult := atrCompleted;
  FOnComplete := AOnComplete;
  FOnCompleteRef := AOnCompleteRef;
  FCompleteContext := ACompleteContext;
  platform_mutex_init(FLock, PLATFORM_MUTEX_NORMAL);
end;

destructor TAsyncTimeoutHandle.Destroy;
begin
  platform_mutex_destroy(FLock);
  inherited Destroy;
end;

procedure TAsyncTimeoutHandle.HandleTimeout;
var
  LCallback: TAsyncCallback;
  LCallbackRef: TAsyncCallbackRef;
  LCtx: Pointer;
begin
  platform_mutex_lock(FLock);
  try
    if FDone then
      Exit;
    FDone := True;
    FTimeoutResult := atrTimedOut;
    LCallback := FOnComplete;
    LCallbackRef := FOnCompleteRef;
    LCtx := FCompleteContext;
  finally
    platform_mutex_unlock(FLock);
  end;
  if Assigned(LCallback) then
    LCallback(LCtx)
  else if Assigned(LCallbackRef) then
    LCallbackRef(LCtx);
end;

procedure TAsyncTimeoutHandle.HandleComplete;
var
  LCallback: TAsyncCallback;
  LCallbackRef: TAsyncCallbackRef;
  LCtx: Pointer;
begin
  platform_mutex_lock(FLock);
  try
    if FDone then
      Exit;
    FDone := True;
    FTimeoutResult := atrCompleted;
    FLoop.CancelTimer(FTimerHandle);
    LCallback := FOnComplete;
    LCallbackRef := FOnCompleteRef;
    LCtx := FCompleteContext;
  finally
    platform_mutex_unlock(FLock);
  end;
  if Assigned(LCallback) then
    LCallback(LCtx)
  else if Assigned(LCallbackRef) then
    LCallbackRef(LCtx);
end;

procedure TAsyncTimeoutHandle.Cancel;
begin
  platform_mutex_lock(FLock);
  try
    if FDone then
      Exit;
    FDone := True;
    FTimeoutResult := atrCancelled;
    FLoop.CancelTimer(FTimerHandle);
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAsyncTimeoutHandle.RemainingMs: UInt32;
var
  LRemainingMs: Int64;
begin
  platform_mutex_lock(FLock);
  try
    if FDone then
      Exit(0);
    LRemainingMs := FDeadline.Remaining.AsMilliseconds;
    if LRemainingMs <= 0 then
      Exit(0);
    if LRemainingMs > High(UInt32) then
      Exit(High(UInt32));
    Result := UInt32(LRemainingMs);
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAsyncTimeoutHandle.IsDone: Boolean;
begin
  platform_mutex_lock(FLock);
  try
    Result := FDone;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAsyncTimeoutHandle.GetResult: TAsyncTimeoutResult;
begin
  platform_mutex_lock(FLock);
  try
    Result := FTimeoutResult;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

end.
