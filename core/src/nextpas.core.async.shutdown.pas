unit nextpas.core.async.shutdown;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.async.base,
  nextpas.core.async.loop;

type
  TShutdownPhase = (
    spRunning,
    spDraining,
    spForceClose,
    spClosed
  );

  TShutdownOption = (
    soGraceful,
    soAbortOnTimeout,
    soLogProgress
  );
  TShutdownOptions = set of TShutdownOption;

  IAsyncShutdown = interface
    ['{C9E6F3A2-8D4B-4A1E-9F7C-3B8D6E5A2C1F}']
    procedure RequestShutdown;
    function Phase: TShutdownPhase;
    procedure SetDrainTimeout(AMs: UInt32);
    procedure OnShutdown(ACallback: TAsyncCallback; AContext: Pointer);
    procedure OnShutdownRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
    function IsShuttingDown: Boolean;
  end;

  { ALoop is not owned; must outlive the manager. }
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
    FDrainTimer: TAsyncTimerHandle;
    FCallbackHead: PShutdownCallback;
    FCallbackTail: PShutdownCallback;
    FLock: TPlatformMutex;
    procedure NotifyCallbacks;
    procedure CancelDrainTimer;
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

procedure DrainTimeoutCallback(AContext: Pointer);
var
  LMgr: TAsyncShutdownManager;
begin
  LMgr := TAsyncShutdownManager(AContext);
  platform_mutex_lock(LMgr.FLock);
  try
    LMgr.FDrainTimer := TAsyncTimerHandle.None;
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

constructor TAsyncShutdownManager.Create(const ALoop: TAsyncLoop;
  AOptions: TShutdownOptions; ADrainTimeoutMs: UInt32);
begin
  inherited Create;
  FLoop := ALoop;
  FOptions := AOptions;
  FPhase := spRunning;
  FDrainTimeoutMs := ADrainTimeoutMs;
  FDrainTimer := TAsyncTimerHandle.None;
  FCallbackHead := nil;
  FCallbackTail := nil;
  platform_mutex_init(FLock, PLATFORM_MUTEX_NORMAL);
end;

procedure TAsyncShutdownManager.CancelDrainTimer;
var
  LTimer: TAsyncTimerHandle;
begin
  LTimer := FDrainTimer;
  FDrainTimer := TAsyncTimerHandle.None;
  { Loop may already be closed/freed by owner; only cancel while still valid. }
  if LTimer.IsValid and (FLoop <> nil) and FLoop.IsValid then
    FLoop.CancelTimer(LTimer);
end;

destructor TAsyncShutdownManager.Destroy;
var
  LNode, LNext: PShutdownCallback;
begin
  CancelDrainTimer;
  LNode := FCallbackHead;
  while LNode <> nil do
  begin
    LNext := LNode^.Next;
    Dispose(LNode);
    LNode := LNext;
  end;
  FCallbackHead := nil;
  FCallbackTail := nil;
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
var
  LShouldArm: Boolean;
begin
  LShouldArm := False;
  platform_mutex_lock(FLock);
  try
    if FPhase <> spRunning then
      Exit;
    FPhase := spDraining;
    LShouldArm := True;
  finally
    platform_mutex_unlock(FLock);
  end;
  if not LShouldArm then
    Exit;
  FDrainTimer := FLoop.Schedule(TDuration.FromMilliseconds(FDrainTimeoutMs),
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
  LPostNow: Boolean;
begin
  LPostNow := False;
  platform_mutex_lock(FLock);
  try
    if FPhase in [spClosed, spForceClose] then
      LPostNow := True
    else
    begin
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
    end;
  finally
    platform_mutex_unlock(FLock);
  end;
  if LPostNow and Assigned(ACallback) and (FLoop <> nil) then
    FLoop.Post(ACallback, AContext);
end;

procedure TAsyncShutdownManager.OnShutdownRef(ACallback: TAsyncCallbackRef;
  AContext: Pointer);
var
  LNode: PShutdownCallback;
  LPostNow: Boolean;
begin
  LPostNow := False;
  platform_mutex_lock(FLock);
  try
    if FPhase in [spClosed, spForceClose] then
      LPostNow := True
    else
    begin
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
    end;
  finally
    platform_mutex_unlock(FLock);
  end;
  if LPostNow and Assigned(ACallback) and (FLoop <> nil) then
    FLoop.PostRef(ACallback, AContext);
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
