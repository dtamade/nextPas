unit nextpas.core.async.semaphore;
{**
 * @desc 异步信号量：不阻塞线程，支持并发访问计数。
 *       适用于限制并发资源访问（如连接数限制）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.async.base, nextpas.core.async.loop;

type
  { 异步信号量 }
  IAsyncSemaphore = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-700000000002}']
    { 尝试立即获取（非阻塞） }
    function TryAcquire: Boolean;

    { 异步获取 }
    procedure Acquire(ACallback: TAsyncCallback; AContext: Pointer = nil);
    procedure AcquireRef(ACallback: TAsyncCallbackRef; AContext: Pointer = nil);

    { 释放信号量 }
    procedure Release;

    { 当前可用计数 }
    function Available: Int32;
  end;

{ 创建异步信号量 }
function CreateAsyncSemaphore(const ALoop: TAsyncLoop;
  AInitialCount: Int32): IAsyncSemaphore;

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

  TAsyncSemaphore = class(TInterfacedObject, IAsyncSemaphore)
  private
    FLoop: TAsyncLoop;
    FCount: Int32;
    FWaiterHead: PWaiterNode;
    FWaiterTail: PWaiterNode;
    FWaiterCount: UInt32;
    FLock: TPlatformMutex;
    procedure AcquireInternal(ACallback: TAsyncCallback; ARef: TAsyncCallbackRef;
      AContext: Pointer);
  public
    constructor Create(const ALoop: TAsyncLoop; AInitialCount: Int32);
    destructor Destroy; override;

    { IAsyncSemaphore }
    function TryAcquire: Boolean;
    procedure Acquire(ACallback: TAsyncCallback; AContext: Pointer = nil);
    procedure AcquireRef(ACallback: TAsyncCallbackRef; AContext: Pointer = nil);
    procedure Release;
    function Available: Int32;
  end;

{ TAsyncSemaphore }

constructor TAsyncSemaphore.Create(const ALoop: TAsyncLoop; AInitialCount: Int32);
begin
  inherited Create;
  FLoop := ALoop;  { 存储指向调用者 loop 的指针 }
  FCount := AInitialCount;
  FWaiterHead := nil;
  FWaiterTail := nil;
  FWaiterCount := 0;
  if platform_mutex_init(FLock, PLATFORM_MUTEX_NORMAL) <> 0 then
    raise EInvalidOperationError.Create('async semaphore: mutex init failed');
end;

destructor TAsyncSemaphore.Destroy;
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

function TAsyncSemaphore.TryAcquire: Boolean;
begin
  platform_mutex_lock(FLock);
  try
    if FCount <= 0 then
      Exit(False);
    Dec(FCount);
    Result := True;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TAsyncSemaphore.AcquireInternal(ACallback: TAsyncCallback;
  ARef: TAsyncCallbackRef; AContext: Pointer);
var
  LNode: PWaiterNode;
begin
  platform_mutex_lock(FLock);
  try
    if FCount > 0 then
    begin
      Dec(FCount);
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

procedure TAsyncSemaphore.Acquire(ACallback: TAsyncCallback; AContext: Pointer);
begin
  AcquireInternal(ACallback, nil, AContext);
end;

procedure TAsyncSemaphore.AcquireRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
begin
  AcquireInternal(nil, ACallback, AContext);
end;

procedure TAsyncSemaphore.Release;
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
      if Assigned(LNode^.Callback) then
        FLoop.Post(LNode^.Callback, LNode^.Context)
      else if Assigned(LNode^.Ref) then
        FLoop.PostRef(LNode^.Ref, LNode^.Context);
      Dispose(LNode);
      { 不增加 FCount，直接转移给等待者 }
    end
    else
    begin
      Inc(FCount);
    end;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAsyncSemaphore.Available: Int32;
begin
  platform_mutex_lock(FLock);
  try
    Result := FCount;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

{ 工厂函数 }

function CreateAsyncSemaphore(const ALoop: TAsyncLoop;
  AInitialCount: Int32): IAsyncSemaphore;
begin
  Result := TAsyncSemaphore.Create(ALoop, AInitialCount);
end;

end.
