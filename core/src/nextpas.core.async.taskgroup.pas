unit nextpas.core.async.taskgroup;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.async.task,
  nextpas.core.async.cancellation;

type
  { Task group state }
  TAsyncTaskGroupState = (
    agsIdle,       { 尚未启动 }
    agsRunning,    { 执行中 }
    agsDraining,   { 排空中：不再接受新任务，等待现有任务完成 }
    agsCompleted,  { 所有任务完成 }
    agsFailed,     { 有任务失败 }
    agsCancelled   { 被取消 }
  );

  { Task group options }
  TAsyncTaskGroupOption = (
    agoFailFast,        { 任一失败则取消其余 }
    agoCancelOnTimeout  { 超时则取消所有任务 }
  );
  TAsyncTaskGroupOptions = set of TAsyncTaskGroupOption;

  IAsyncTaskGroup = interface
    ['{B7E4D3A2-5F8C-4A1E-9D6B-2C8F7E5A3B1D}']
    { 启动一个异步任务 }
    procedure RunTask(ACallback: TAsyncCallback; AContext: Pointer);
    procedure RunTaskRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
    { 等待所有任务完成 }
    procedure WaitAll(ACallback: TAsyncCallback; AContext: Pointer);
    procedure WaitAllRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
    { 取消所有任务 }
    procedure CancelAll;
    { 停止接受新任务，等待现有任务完成 }
    procedure Drain;
    { 组状态 }
    function State: TAsyncTaskGroupState;
    { 活跃任务数 }
    function ActiveCount: UInt32;
    { 已完成任务数 }
    function CompletedCount: UInt32;
    { 总任务数 }
    function TotalCount: UInt32;
  end;

  { 创建任务组。AToken 非 nil 时：token 取消 → CancelAll（组级停）。 }
  function CreateTaskGroup(const ALoop: TAsyncLoop;
    AOptions: TAsyncTaskGroupOptions = [];
    AToken: IAsyncCancellationToken = nil): IAsyncTaskGroup;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.platform.sync;

type

  { 堆分配的上下文记录：保存用户回调+上下文+组指针，通过 AContext 传递 }
  PTaskWrapCtx = ^TTaskWrapCtx;
  TTaskWrapCtx = record
    UserCallback: TAsyncCallback;
    UserRef: TAsyncCallbackRef;
    UserContext: Pointer;
    Group: Pointer; { TAsyncTaskGroup 指针，避免循环依赖 }
    Done: Int32; { 0 pending; 1 finished (invoke or discard) }
  end;

  TAsyncTaskGroup = class
  private
    FLoop: TAsyncLoop;
    FOptions: TAsyncTaskGroupOptions;
    FState: TAsyncTaskGroupState;
    FActiveCount: UInt32;
    FCompletedCount: UInt32;
    FTotalCount: UInt32;
    FOnAllComplete: TAsyncCallbackStorage;
    FLock: TPlatformMutex;
    FToken: IAsyncCancellationToken;
    procedure CheckCompletion;
    procedure TaskDone;
  public
    constructor Create(const ALoop: TAsyncLoop; AOptions: TAsyncTaskGroupOptions;
      AToken: IAsyncCancellationToken);
    destructor Destroy; override;
    procedure RunTask(ACallback: TAsyncCallback; AContext: Pointer);
    procedure RunTaskRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
    procedure WaitAll(ACallback: TAsyncCallback; AContext: Pointer);
    procedure WaitAllRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
    procedure CancelAll;
    procedure Drain;
    function State: TAsyncTaskGroupState;
    function ActiveCount: UInt32;
    function CompletedCount: UInt32;
    function TotalCount: UInt32;
  end;

  TAsyncTaskGroupWrapper = class(TInterfacedObject, IAsyncTaskGroup)
  private
    FGroup: TAsyncTaskGroup;
  public
    constructor Create(const ALoop: TAsyncLoop; AOptions: TAsyncTaskGroupOptions;
      AToken: IAsyncCancellationToken);
    destructor Destroy; override;
    procedure RunTask(ACallback: TAsyncCallback; AContext: Pointer);
    procedure RunTaskRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
    procedure WaitAll(ACallback: TAsyncCallback; AContext: Pointer);
    procedure WaitAllRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
    procedure CancelAll;
    procedure Drain;
    function State: TAsyncTaskGroupState;
    function ActiveCount: UInt32;
    function CompletedCount: UInt32;
    function TotalCount: UInt32;
  end;

{ Finish wrap once: user invoke path or Close discard path. }
procedure TaskWrapFinish(AContext: Pointer; ARunUser: Boolean);
var
  LCtx: PTaskWrapCtx;
  LGroup: TAsyncTaskGroup;
  LExpected: Int32;
begin
  LCtx := PTaskWrapCtx(AContext);
  if LCtx = nil then
    Exit;
  LExpected := 0;
  if not atomic_compare_exchange_strong(LCtx^.Done, LExpected, 1, mo_acq_rel, mo_acquire) then
    Exit;
  LGroup := TAsyncTaskGroup(LCtx^.Group);
  try
    if ARunUser then
    begin
      if Assigned(LCtx^.UserCallback) then
        LCtx^.UserCallback(LCtx^.UserContext)
      else if Assigned(LCtx^.UserRef) then
        LCtx^.UserRef(LCtx^.UserContext);
      if LGroup <> nil then
        LGroup.TaskDone;
    end;
  finally
    Dispose(LCtx);
  end;
end;

procedure WrappedTaskCallback(AContext: Pointer);
begin
  TaskWrapFinish(AContext, True);
end;

procedure WrappedTaskRefCallback(AContext: Pointer);
begin
  TaskWrapFinish(AContext, True);
end;

procedure DiscardTaskWrap(AContext: Pointer);
begin
  TaskWrapFinish(AContext, False);
end;

function CreateTaskGroup(const ALoop: TAsyncLoop;
  AOptions: TAsyncTaskGroupOptions;
  AToken: IAsyncCancellationToken): IAsyncTaskGroup;
begin
  Result := TAsyncTaskGroupWrapper.Create(ALoop, AOptions, AToken);
end;

procedure TaskGroupTokenNotify(AContext: Pointer);
var
  LGroup: TAsyncTaskGroup;
begin
  LGroup := TAsyncTaskGroup(AContext);
  if LGroup <> nil then
    LGroup.CancelAll;
end;

{ TAsyncTaskGroup }

constructor TAsyncTaskGroup.Create(const ALoop: TAsyncLoop;
  AOptions: TAsyncTaskGroupOptions; AToken: IAsyncCancellationToken);
begin
  inherited Create;
  FLoop := ALoop;
  FOptions := AOptions;
  FState := agsIdle;
  FActiveCount := 0;
  FCompletedCount := 0;
  FTotalCount := 0;
  FToken := AToken;
  platform_mutex_init(FLock, PLATFORM_MUTEX_NORMAL);
  if FToken <> nil then
    FToken.OnCancel(@TaskGroupTokenNotify, Self);
end;

destructor TAsyncTaskGroup.Destroy;
begin
  FToken := nil;
  platform_mutex_destroy(FLock);
  inherited Destroy;
end;

procedure TAsyncTaskGroup.TaskDone;
begin
  platform_mutex_lock(FLock);
  try
    if FActiveCount > 0 then
      Dec(FActiveCount);
    Inc(FCompletedCount);
  finally
    platform_mutex_unlock(FLock);
  end;
  CheckCompletion;
end;

procedure TAsyncTaskGroup.CheckCompletion;
var
  LCallback: TAsyncCallbackStorage;
begin
  platform_mutex_lock(FLock);
  try
    if FState in [agsCompleted, agsFailed, agsCancelled] then
      Exit;
    if FActiveCount > 0 then
      Exit;
    if FState = agsDraining then
      FState := agsCompleted
    else if FState = agsRunning then
      FState := agsCompleted;
    if FState in [agsCompleted, agsFailed] then
    begin
      LCallback := FOnAllComplete;
      FOnAllComplete := Default(TAsyncCallbackStorage);
    end
    else
      Exit;
  finally
    platform_mutex_unlock(FLock);
  end;
  if not LCallback.IsEmpty then
    LCallback.Invoke;
end;

procedure TAsyncTaskGroup.RunTask(ACallback: TAsyncCallback; AContext: Pointer);
var
  LCtx: PTaskWrapCtx;
begin
  platform_mutex_lock(FLock);
  try
    if FState in [agsDraining, agsCompleted, agsFailed, agsCancelled] then
      Exit;
    FState := agsRunning;
    Inc(FActiveCount);
    Inc(FTotalCount);
  finally
    platform_mutex_unlock(FLock);
  end;
  New(LCtx);
  FillChar(LCtx^, SizeOf(LCtx^), 0);
  LCtx^.UserCallback := ACallback;
  LCtx^.UserRef := nil;
  LCtx^.UserContext := AContext;
  LCtx^.Group := Pointer(Self);
  LCtx^.Done := 0;
  FLoop.PostEx(@WrappedTaskCallback, LCtx, @DiscardTaskWrap);
end;

procedure TAsyncTaskGroup.RunTaskRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
var
  LCtx: PTaskWrapCtx;
begin
  platform_mutex_lock(FLock);
  try
    if FState in [agsDraining, agsCompleted, agsFailed, agsCancelled] then
      Exit;
    FState := agsRunning;
    Inc(FActiveCount);
    Inc(FTotalCount);
  finally
    platform_mutex_unlock(FLock);
  end;
  New(LCtx);
  FillChar(LCtx^, SizeOf(LCtx^), 0);
  LCtx^.UserCallback := nil;
  LCtx^.UserRef := ACallback;
  LCtx^.UserContext := AContext;
  LCtx^.Group := Pointer(Self);
  LCtx^.Done := 0;
  FLoop.PostEx(@WrappedTaskRefCallback, LCtx, @DiscardTaskWrap);
end;

procedure TAsyncTaskGroup.WaitAll(ACallback: TAsyncCallback; AContext: Pointer);
var
  LImmediate: Boolean;
begin
  LImmediate := False;
  platform_mutex_lock(FLock);
  try
    if FActiveCount = 0 then
      LImmediate := True
    else
    begin
      FOnAllComplete.Regular := ACallback;
      FOnAllComplete.Context := AContext;
    end;
  finally
    platform_mutex_unlock(FLock);
  end;
  if LImmediate then
    FLoop.Post(ACallback, AContext);
end;

procedure TAsyncTaskGroup.WaitAllRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
var
  LImmediate: Boolean;
begin
  LImmediate := False;
  platform_mutex_lock(FLock);
  try
    if FActiveCount = 0 then
      LImmediate := True
    else
    begin
      FOnAllComplete.Ref := ACallback;
      FOnAllComplete.Context := AContext;
    end;
  finally
    platform_mutex_unlock(FLock);
  end;
  if LImmediate then
    FLoop.PostRef(ACallback, AContext);
end;

procedure TAsyncTaskGroup.CancelAll;
begin
  platform_mutex_lock(FLock);
  try
    FState := agsCancelled;
    FActiveCount := 0;
  finally
    platform_mutex_unlock(FLock);
  end;
  CheckCompletion;
end;

procedure TAsyncTaskGroup.Drain;
begin
  platform_mutex_lock(FLock);
  try
    if FState = agsRunning then
      FState := agsDraining;
  finally
    platform_mutex_unlock(FLock);
  end;
  CheckCompletion;
end;

function TAsyncTaskGroup.State: TAsyncTaskGroupState;
begin
  platform_mutex_lock(FLock);
  try
    Result := FState;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAsyncTaskGroup.ActiveCount: UInt32;
begin
  platform_mutex_lock(FLock);
  try
    Result := FActiveCount;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAsyncTaskGroup.CompletedCount: UInt32;
begin
  platform_mutex_lock(FLock);
  try
    Result := FCompletedCount;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAsyncTaskGroup.TotalCount: UInt32;
begin
  platform_mutex_lock(FLock);
  try
    Result := FTotalCount;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

{ TAsyncTaskGroupWrapper }

constructor TAsyncTaskGroupWrapper.Create(const ALoop: TAsyncLoop;
  AOptions: TAsyncTaskGroupOptions; AToken: IAsyncCancellationToken);
begin
  inherited Create;
  FGroup := TAsyncTaskGroup.Create(ALoop, AOptions, AToken);
end;

destructor TAsyncTaskGroupWrapper.Destroy;
begin
  FGroup.Free;
  inherited Destroy;
end;

procedure TAsyncTaskGroupWrapper.RunTask(ACallback: TAsyncCallback; AContext: Pointer);
begin
  FGroup.RunTask(ACallback, AContext);
end;

procedure TAsyncTaskGroupWrapper.RunTaskRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
begin
  FGroup.RunTaskRef(ACallback, AContext);
end;

procedure TAsyncTaskGroupWrapper.WaitAll(ACallback: TAsyncCallback; AContext: Pointer);
begin
  FGroup.WaitAll(ACallback, AContext);
end;

procedure TAsyncTaskGroupWrapper.WaitAllRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
begin
  FGroup.WaitAllRef(ACallback, AContext);
end;

procedure TAsyncTaskGroupWrapper.CancelAll;
begin
  FGroup.CancelAll;
end;

procedure TAsyncTaskGroupWrapper.Drain;
begin
  FGroup.Drain;
end;

function TAsyncTaskGroupWrapper.State: TAsyncTaskGroupState;
begin
  Result := FGroup.State;
end;

function TAsyncTaskGroupWrapper.ActiveCount: UInt32;
begin
  Result := FGroup.ActiveCount;
end;

function TAsyncTaskGroupWrapper.CompletedCount: UInt32;
begin
  Result := FGroup.CompletedCount;
end;

function TAsyncTaskGroupWrapper.TotalCount: UInt32;
begin
  Result := FGroup.TotalCount;
end;

end.
