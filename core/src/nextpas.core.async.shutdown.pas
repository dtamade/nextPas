unit nextpas.core.async.shutdown;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.async.base,
  nextpas.core.async.loop;

type
  { 关闭阶段 }
  TShutdownPhase = (
    spRunning,      { 正常运行 }
    spDraining,     { 排空中：停止接受新工作，等待现有工作完成 }
    spForceClose,   { 强制关闭：超时后强制关闭 }
    spClosed        { 已关闭 }
  );

  { 关闭选项 }
  TShutdownOption = (
    soGraceful,       { 优雅关闭：排空后关闭 }
    soAbortOnTimeout, { 超时后中止 }
    soLogProgress     { 记录排空进度 }
  );
  TShutdownOptions = set of TShutdownOption;

  IAsyncShutdown = interface
    ['{C9E6F3A2-8D4B-4A1E-9F7C-3B8D6E5A2C1F}']
    { 请求关闭 }
    procedure RequestShutdown;
    { 关闭阶段 }
    function Phase: TShutdownPhase;
    { 设置排空超时（毫秒） }
    procedure SetDrainTimeout(AMs: UInt32);
    { 注册关闭回调 }
    procedure OnShutdown(ACallback: TAsyncCallback; AContext: Pointer);
    procedure OnShutdownRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
    { 是否正在关闭 }
    function IsShuttingDown: Boolean;
  end;

  { 创建优雅关闭管理器 }
  function CreateShutdownManager(const ALoop: TAsyncLoop;
    AOptions: TShutdownOptions = [soGraceful];
    ADrainTimeoutMs: UInt32 = 5000): IAsyncShutdown;

implementation

uses
  nextpas.core.platform.sync;

type
  PShutdownCallback = ^TShutdownCallback;
  TShutdownCallback = record
    Regular: TAsyncCallback;
    Ref: TAsyncCallbackRef;
    Context: Pointer;
    Next: PShutdownCallback;
  end;


  TAsyncShutdownManager = class(TInterfacedObject, IAsyncShutdown)
  private
    FLoop: TAsyncLoop;
    FOptions: TShutdownOptions;
    FPhase: TShutdownPhase;
    FDrainTimeoutMs: UInt32;
    FCallbackHead: PShutdownCallback;
    FCallbackTail: PShutdownCallback;
    FLock: TPlatformMutex;
    procedure NotifyCallbacks;
  public
    constructor Create(const ALoop: TAsyncLoop; AOptions: TShutdownOptions;
      ADrainTimeoutMs: UInt32);
    destructor Destroy; override;
    procedure RequestShutdown;
    function Phase: TShutdownPhase;
    procedure SetDrainTimeout(AMs: UInt32);
    procedure OnShutdown(ACallback: TAsyncCallback; AContext: Pointer);
    procedure OnShutdownRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
    function IsShuttingDown: Boolean;
  end;

{ 排空超时回调：通过 AContext 恢复实例引用，无需全局变量 }
procedure DrainTimeoutCallback(AContext: Pointer);
var
  LMgr: TAsyncShutdownManager;
begin
  LMgr := TAsyncShutdownManager(AContext);
  platform_mutex_lock(LMgr.FLock);
  try
    if LMgr.FPhase <> spDraining then
      Exit;
    if soAbortOnTimeout in LMgr.FOptions then
      LMgr.FPhase := spForceClose
    else
      LMgr.FPhase := spClosed;
  finally
    platform_mutex_unlock(LMgr.FLock);
  end;
  LMgr.NotifyCallbacks;
end;

function CreateShutdownManager(const ALoop: TAsyncLoop;
  AOptions: TShutdownOptions; ADrainTimeoutMs: UInt32): IAsyncShutdown;
begin
  Result := TAsyncShutdownManager.Create(ALoop, AOptions, ADrainTimeoutMs);
end;

{ TAsyncShutdownManager }

constructor TAsyncShutdownManager.Create(const ALoop: TAsyncLoop;
  AOptions: TShutdownOptions; ADrainTimeoutMs: UInt32);
begin
  inherited Create;
  FLoop := ALoop;
  FOptions := AOptions;
  FPhase := spRunning;
  FDrainTimeoutMs := ADrainTimeoutMs;
  FCallbackHead := nil;
  FCallbackTail := nil;
  platform_mutex_init(FLock, PLATFORM_MUTEX_NORMAL);
end;

destructor TAsyncShutdownManager.Destroy;
var
  LNode, LNext: PShutdownCallback;
begin
  LNode := FCallbackHead;
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    Dispose(LNode);
    LNode := LNext;
  end;
  platform_mutex_destroy(FLock);
  inherited Destroy;
end;

procedure TAsyncShutdownManager.NotifyCallbacks;
var
  LNode: PShutdownCallback;
begin
  LNode := FCallbackHead;
  while LNode <> nil do
  begin
    if Assigned(LNode^.Regular) then
      LNode^.Regular(LNode^.Context)
    else if Assigned(LNode^.Ref) then
      LNode^.Ref(LNode^.Context);
    LNode := LNode^.Next;
  end;
end;

procedure TAsyncShutdownManager.RequestShutdown;
begin
  platform_mutex_lock(FLock);
  try
    if FPhase <> spRunning then
      Exit;
    FPhase := spDraining;
  finally
    platform_mutex_unlock(FLock);
  end;
  { 启动排空超时定时器，通过 AContext 传递 Self 指针 }
  FLoop.Schedule(TDuration.FromMilliseconds(FDrainTimeoutMs),
    @DrainTimeoutCallback, Pointer(Self));
end;

function TAsyncShutdownManager.Phase: TShutdownPhase;
begin
  platform_mutex_lock(FLock);
  try
    Result := FPhase;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TAsyncShutdownManager.SetDrainTimeout(AMs: UInt32);
begin
  platform_mutex_lock(FLock);
  try
    FDrainTimeoutMs := AMs;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TAsyncShutdownManager.OnShutdown(ACallback: TAsyncCallback;
  AContext: Pointer);
var
  LNode: PShutdownCallback;
begin
  platform_mutex_lock(FLock);
  try
    if FPhase = spClosed then
    begin
      platform_mutex_unlock(FLock);
      { 通过 Post 调度，避免在调用者栈上直接执行 }
      FLoop.Post(ACallback, AContext);
      Exit;
    end;
    New(LNode);
    LNode^.Regular := ACallback;
    LNode^.Ref := nil;
    LNode^.Context := AContext;
    LNode^.Next := nil;
    if FCallbackTail <> nil then
      FCallbackTail^.Next := LNode
    else
      FCallbackHead := LNode;
    FCallbackTail := LNode;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TAsyncShutdownManager.OnShutdownRef(ACallback: TAsyncCallbackRef;
  AContext: Pointer);
var
  LNode: PShutdownCallback;
begin
  platform_mutex_lock(FLock);
  try
    if FPhase = spClosed then
    begin
      platform_mutex_unlock(FLock);
      { 通过 Post 调度，避免在调用者栈上直接执行 }
      FLoop.PostRef(ACallback, AContext);
      Exit;
    end;
    New(LNode);
    LNode^.Regular := nil;
    LNode^.Ref := ACallback;
    LNode^.Context := AContext;
    LNode^.Next := nil;
    if FCallbackTail <> nil then
      FCallbackTail^.Next := LNode
    else
      FCallbackHead := LNode;
    FCallbackTail := LNode;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAsyncShutdownManager.IsShuttingDown: Boolean;
begin
  platform_mutex_lock(FLock);
  try
    Result := FPhase <> spRunning;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

end.
