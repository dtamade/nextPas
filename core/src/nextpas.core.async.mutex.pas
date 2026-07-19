unit nextpas.core.async.mutex;
{**
 * @desc 异步互斥锁：不阻塞线程，而是挂起等待者通过事件循环调度。
 *       适用于异步上下文中的临界区保护。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.async.base, nextpas.core.async.loop;

type
  { 异步互斥锁获取回调 }
  TAsyncMutexCallback = procedure(AContext: Pointer);

  { 异步互斥锁 }
  IAsyncMutex = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-700000000001}']
    { 尝试立即获取（非阻塞） }
    function TryLock: Boolean;

    { 异步获取（通过回调通知） }
    procedure Lock(ACallback: TAsyncCallback; AContext: Pointer = nil);
    procedure LockRef(ACallback: TAsyncCallbackRef; AContext: Pointer = nil);

    { 释放锁 }
    procedure Unlock;

    { 是否被持有 }
    function IsLocked: Boolean;
  end;

{ 创建异步互斥锁 }
function CreateAsyncMutex(const ALoop: TAsyncLoop): IAsyncMutex;

implementation

uses
  nextpas.core.errors,
  nextpas.core.platform.sync;

type

  PWaiterNode = ^TWaiterNode;
  TWaiterNode = record
    Callback: TAsyncCallback;
    Ref: TAsyncCallbackRef;
    Context: Pointer;
    Next: PWaiterNode;
  end;

  TAsyncMutex = class(TInterfacedObject, IAsyncMutex)
  private
    FLoop: TAsyncLoop;  { not owned; must outlive mutex }
    FLocked: Boolean;
    FWaiterHead: PWaiterNode;
    FWaiterTail: PWaiterNode;
    FWaiterCount: UInt32;
    FLock: TPlatformMutex;
    procedure LockInternal(ACallback: TAsyncCallback; ARef: TAsyncCallbackRef;
      AContext: Pointer);
  public
    constructor Create(const ALoop: TAsyncLoop);
    destructor Destroy; override;

    { IAsyncMutex }
    function TryLock: Boolean;
    procedure Lock(ACallback: TAsyncCallback; AContext: Pointer = nil);
    procedure LockRef(ACallback: TAsyncCallbackRef; AContext: Pointer = nil);
    procedure Unlock;
    function IsLocked: Boolean;
  end;

{ TAsyncMutex }

constructor TAsyncMutex.Create(const ALoop: TAsyncLoop);
begin
  inherited Create;
  FLoop := ALoop;  { not owned }
  FLocked := False;
  FWaiterHead := nil;
  FWaiterTail := nil;
  FWaiterCount := 0;
  if platform_mutex_init(FLock, PLATFORM_MUTEX_NORMAL) <> 0 then
    raise EInvalidOperationError.Create('async mutex: mutex init failed');
end;

destructor TAsyncMutex.Destroy;
var
  LCurr, LNext: PWaiterNode;
begin
  LCurr := FWaiterHead;
  while LCurr <> nil do
  begin
    LNext := LCurr^.Next;
    Dispose(LCurr);
    LCurr := LNext;
  end;
  platform_mutex_destroy(FLock);
  { 不 Dispose(FLoop)，因为不拥有 }
  inherited;
end;

function TAsyncMutex.TryLock: Boolean;
begin
  platform_mutex_lock(FLock);
  try
    if FLocked then
      Exit(False);
    FLocked := True;
    Result := True;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TAsyncMutex.LockInternal(ACallback: TAsyncCallback;
  ARef: TAsyncCallbackRef; AContext: Pointer);
var
  LNode: PWaiterNode;
begin
  platform_mutex_lock(FLock);
  try
    if not FLocked then
    begin
      FLocked := True;
      if Assigned(ACallback) then
        FLoop.Post(ACallback, AContext)
      else if Assigned(ARef) then
        FLoop.PostRef(ARef, AContext);
      Exit;
    end;
    New(LNode);
    LNode^.Callback := ACallback;
    LNode^.Ref := ARef;
    LNode^.Context := AContext;
    LNode^.Next := nil;
    if FWaiterTail <> nil then
      FWaiterTail^.Next := LNode
    else
      FWaiterHead := LNode;
    FWaiterTail := LNode;
    Inc(FWaiterCount);
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TAsyncMutex.Lock(ACallback: TAsyncCallback; AContext: Pointer);
begin
  LockInternal(ACallback, nil, AContext);
end;

procedure TAsyncMutex.LockRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
begin
  LockInternal(nil, ACallback, AContext);
end;

procedure TAsyncMutex.Unlock;
var
  LNode: PWaiterNode;
begin
  platform_mutex_lock(FLock);
  try
    if FWaiterHead <> nil then
    begin
      { 唤醒下一个等待者 }
      LNode := FWaiterHead;
      FWaiterHead := LNode^.Next;
      if FWaiterHead = nil then
        FWaiterTail := nil;
      Dec(FWaiterCount);
      { 保持锁持有，通过 Post 通知等待者 }
      if Assigned(LNode^.Callback) then
        FLoop.Post(LNode^.Callback, LNode^.Context)
      else if Assigned(LNode^.Ref) then
        FLoop.PostRef(LNode^.Ref, LNode^.Context);
      Dispose(LNode);
      { 锁仍然持有，等待者获得后会再次 Unlock }
    end
    else
    begin
      FLocked := False;
    end;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAsyncMutex.IsLocked: Boolean;
begin
  platform_mutex_lock(FLock);
  try
    Result := FLocked;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

{ 工厂函数 }

function CreateAsyncMutex(const ALoop: TAsyncLoop): IAsyncMutex;
begin
  Result := TAsyncMutex.Create(ALoop);
end;

end.
