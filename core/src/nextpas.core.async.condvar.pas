unit nextpas.core.async.condvar;
{**
 * @desc 异步条件变量：不阻塞线程，支持异步等待条件满足。
 *       配合 AsyncMutex 使用，实现异步 Monitor 模式。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.async.base, nextpas.core.async.loop, nextpas.core.async.mutex;

type
  { 异步条件变量 }
  IAsyncCondVar = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-700000000004}']
    { 通知一个等待者 }
    procedure Signal;

    { 通知所有等待者 }
    procedure Broadcast;

    { 等待条件满足（需要持有 Mutex） }
    procedure Wait(AMutex: IAsyncMutex;
      ACallback: TAsyncCallback; AContext: Pointer = nil);
    procedure WaitRef(AMutex: IAsyncMutex;
      ACallback: TAsyncCallbackRef; AContext: Pointer = nil);
  end;

{ 创建异步条件变量 }
function CreateAsyncCondVar(const ALoop: TAsyncLoop): IAsyncCondVar;

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

  TAsyncCondVar = class(TInterfacedObject, IAsyncCondVar)
  private
    FLoop: TAsyncLoop;
    FWaiterHead: PWaiterNode;
    FWaiterTail: PWaiterNode;
    FLock: TPlatformMutex;
  public
    constructor Create(const ALoop: TAsyncLoop);
    destructor Destroy; override;

    { IAsyncCondVar }
    procedure Signal;
    procedure Broadcast;
    procedure Wait(AMutex: IAsyncMutex;
      ACallback: TAsyncCallback; AContext: Pointer = nil);
    procedure WaitRef(AMutex: IAsyncMutex;
      ACallback: TAsyncCallbackRef; AContext: Pointer = nil);
  end;

{ TAsyncCondVar }

constructor TAsyncCondVar.Create(const ALoop: TAsyncLoop);
begin
  inherited Create;
  FLoop := ALoop;
  FWaiterHead := nil;
  FWaiterTail := nil;
  if platform_mutex_init(FLock, PLATFORM_MUTEX_NORMAL) <> 0 then
    raise EInvalidOperationError.Create('async condvar: mutex init failed');
end;

destructor TAsyncCondVar.Destroy;
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
  inherited;
end;

procedure TAsyncCondVar.Signal;
var
  LNode: PWaiterNode;
begin
  platform_mutex_lock(FLock);
  try
    if FWaiterHead = nil then
      Exit;
    LNode := FWaiterHead;
    FWaiterHead := LNode^.Next;
    if FWaiterHead = nil then
      FWaiterTail := nil;
    if Assigned(LNode^.Callback) then
      FLoop.Post(LNode^.Callback, LNode^.Context)
    else if Assigned(LNode^.Ref) then
      FLoop.PostRef(LNode^.Ref, LNode^.Context);
    Dispose(LNode);
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TAsyncCondVar.Broadcast;
var
  LNode: PWaiterNode;
begin
  platform_mutex_lock(FLock);
  try
    while FWaiterHead <> nil do
    begin
      LNode := FWaiterHead;
      FWaiterHead := LNode^.Next;
      if Assigned(LNode^.Callback) then
        FLoop.Post(LNode^.Callback, LNode^.Context)
      else if Assigned(LNode^.Ref) then
        FLoop.PostRef(LNode^.Ref, LNode^.Context);
      Dispose(LNode);
    end;
    FWaiterTail := nil;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TAsyncCondVar.Wait(AMutex: IAsyncMutex;
  ACallback: TAsyncCallback; AContext: Pointer);
var
  LNode: PWaiterNode;
begin
  { 加入等待队列 }
  platform_mutex_lock(FLock);
  try
    New(LNode);
    LNode^.Callback := ACallback;
    LNode^.Ref := nil;
    LNode^.Context := AContext;
    LNode^.Next := nil;
    if FWaiterTail <> nil then
      FWaiterTail^.Next := LNode
    else
      FWaiterHead := LNode;
    FWaiterTail := LNode;
  finally
    platform_mutex_unlock(FLock);
  end;
  { 释放互斥锁 }
  AMutex.Unlock;
end;

procedure TAsyncCondVar.WaitRef(AMutex: IAsyncMutex;
  ACallback: TAsyncCallbackRef; AContext: Pointer);
var
  LNode: PWaiterNode;
begin
  platform_mutex_lock(FLock);
  try
    New(LNode);
    LNode^.Callback := nil;
    LNode^.Ref := ACallback;
    LNode^.Context := AContext;
    LNode^.Next := nil;
    if FWaiterTail <> nil then
      FWaiterTail^.Next := LNode
    else
      FWaiterHead := LNode;
    FWaiterTail := LNode;
  finally
    platform_mutex_unlock(FLock);
  end;
  AMutex.Unlock;
end;

{ 工厂函数 }

function CreateAsyncCondVar(const ALoop: TAsyncLoop): IAsyncCondVar;
begin
  Result := TAsyncCondVar.Create(ALoop);
end;

end.
