{
  nextpas.core.async.cancellation.pas — 异步取消传播机制

  功能：
  - CancellationToken: 取消令牌，支持父子传播
  - 类似 Go context.Context / Rust CancellationToken
  - 取消操作沿父子链向下传播
  - 支持注册取消回调

  设计原则：
  - 原子操作保证线程安全
  - 引用计数管理生命周期
  - 回调驱动，无阻塞
}
unit nextpas.core.async.cancellation;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.async.base;

type
  { 取消回调类型 }
  TCancelCallback = procedure(AContext: Pointer);

  { 取消令牌接口 }
  IAsyncCancellationToken = interface
    ['{C4D5E6F7-A8B9-4C0D-1E2F-3A4B5C6D7E8F}']
    { 取消此令牌及其所有子令牌 }
    procedure Cancel;

    { 是否已取消 }
    function IsCancelled: Boolean;

    { 注册取消回调（取消时立即调用，若已取消则立即调用） }
    procedure OnCancel(ACallback: TCancelCallback; AContext: Pointer = nil);

    { 创建子令牌（父取消时子自动取消） }
    function CreateChildToken: IAsyncCancellationToken;

    { 等待取消（返回 True 表示已取消，False 表示超时） }
    function WaitForCancel(ATimeoutMs: UInt32 = 0): Boolean;
  end;

{ 创建根取消令牌 }
function CreateCancellationToken: IAsyncCancellationToken;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.platform.sync;

const
  CANCEL_STATE_ACTIVE = 0;
  CANCEL_STATE_CANCELLED = 1;

type
  PCancelCallbackEntry = ^TCancelCallbackEntry;
  TCancelCallbackEntry = record
    Callback: TCancelCallback;
    Context: Pointer;
    Next: PCancelCallbackEntry;
  end;

  PChildEntry = ^TChildEntry;
  TChildEntry = record
    Child: Pointer;  { TAsyncCancellationTokenImpl, 使用指针避免前向引用 }
    Next: PChildEntry;
  end;

  TAsyncCancellationTokenImpl = class(TInterfacedObject, IAsyncCancellationToken)
  private
    FState: Int32;  { CANCEL_STATE_ACTIVE or CANCEL_STATE_CANCELLED }
    FParent: TAsyncCancellationTokenImpl;
    FCallbacks: PCancelCallbackEntry;
    FCallbackTail: PCancelCallbackEntry;
    FChildren: PChildEntry;
    FChildrenTail: PChildEntry;
    FLock: TPlatformMutex;
    FCond: TPlatformCondVar;
    FCondReady: Boolean;

    procedure FireCallbacks;
    procedure CancelChildren;
    procedure RemoveFromParent;
    procedure AddChild(AChild: TAsyncCancellationTokenImpl);
    procedure RemoveChild(AChild: TAsyncCancellationTokenImpl);
  public
    constructor Create(AParent: TAsyncCancellationTokenImpl);
    destructor Destroy; override;

    { IAsyncCancellationToken }
    procedure Cancel;
    function IsCancelled: Boolean;
    procedure OnCancel(ACallback: TCancelCallback; AContext: Pointer = nil);
    function CreateChildToken: IAsyncCancellationToken;
    function WaitForCancel(ATimeoutMs: UInt32 = 0): Boolean;
  end;

{ TAsyncCancellationTokenImpl }

constructor TAsyncCancellationTokenImpl.Create(AParent: TAsyncCancellationTokenImpl);
begin
  inherited Create;
  FState := CANCEL_STATE_ACTIVE;
  FParent := AParent;
  FCallbacks := nil;
  FCallbackTail := nil;
  FChildren := nil;
  FChildrenTail := nil;
  FCondReady := False;
  if platform_mutex_init(FLock, PLATFORM_MUTEX_ERRORCHECK) <> 0 then
    raise EInvalidOperationError.Create('cancellation token: mutex init failed');
  if platform_condvar_init(FCond) <> 0 then
  begin
    platform_mutex_destroy(FLock);
    raise EInvalidOperationError.Create('cancellation token: cond init failed');
  end;
  { 注册到父令牌 }
  if FParent <> nil then
    FParent.AddChild(Self);
end;

destructor TAsyncCancellationTokenImpl.Destroy;
var
  LEntry, LNextEntry: PCancelCallbackEntry;
  LChild, LNextChild: PChildEntry;
begin
  { 从父令牌注销（仅清除引用，不修改父的子列表） }
  FParent := nil;
  { 释放回调链表 }
  LEntry := FCallbacks;
  while LEntry <> nil do
  begin
    LNextEntry := LEntry^.Next;
    Dispose(LEntry);
    LEntry := LNextEntry;
  end;
  { 释放子令牌引用 }
  LChild := FChildren;
  while LChild <> nil do
  begin
    LNextChild := LChild^.Next;
    LChild^.Child := nil;  { 不拥有子令牌，只清空引用 }
    Dispose(LChild);
    LChild := LNextChild;
  end;
  platform_condvar_destroy(FCond);
  platform_mutex_destroy(FLock);
  inherited Destroy;
end;

procedure TAsyncCancellationTokenImpl.FireCallbacks;
var
  LEntry: PCancelCallbackEntry;
begin
  LEntry := FCallbacks;
  while LEntry <> nil do
  begin
    try
      if Assigned(LEntry^.Callback) then
        LEntry^.Callback(LEntry^.Context);
    except
      { 吞掉回调异常，不影响取消传播 }
    end;
    LEntry := LEntry^.Next;
  end;
end;

procedure TAsyncCancellationTokenImpl.CancelChildren;
var
  LChild: PChildEntry;
begin
  LChild := FChildren;
  while LChild <> nil do
  begin
    if LChild^.Child <> nil then
      TAsyncCancellationTokenImpl(LChild^.Child).Cancel;
    LChild := LChild^.Next;
  end;
end;

procedure TAsyncCancellationTokenImpl.RemoveFromParent;
begin
  if FParent <> nil then
  begin
    FParent.RemoveChild(Self);
    FParent := nil;
  end;
end;

procedure TAsyncCancellationTokenImpl.AddChild(AChild: TAsyncCancellationTokenImpl);
var
  LEntry: PChildEntry;
begin
  platform_mutex_lock(FLock);
  try
    { 如果已取消，直接取消子令牌 }
    if FState = CANCEL_STATE_CANCELLED then
    begin
      AChild.Cancel;
      Exit;
    end;
    New(LEntry);
    LEntry^.Child := Pointer(AChild);
    LEntry^.Next := nil;
    if FChildrenTail <> nil then
      FChildrenTail^.Next := LEntry
    else
      FChildren := LEntry;
    FChildrenTail := LEntry;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TAsyncCancellationTokenImpl.RemoveChild(AChild: TAsyncCancellationTokenImpl);
var
  LPrev, LCurr: PChildEntry;
begin
  platform_mutex_lock(FLock);
  try
    LPrev := nil;
    LCurr := FChildren;
    while LCurr <> nil do
    begin
      if TAsyncCancellationTokenImpl(LCurr^.Child) = AChild then
      begin
        if LPrev <> nil then
          LPrev^.Next := LCurr^.Next
        else
          FChildren := LCurr^.Next;
        if LCurr = FChildrenTail then
          FChildrenTail := LPrev;
        Dispose(LCurr);
        Exit;
      end;
      LPrev := LCurr;
      LCurr := LCurr^.Next;
    end;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TAsyncCancellationTokenImpl.Cancel;
var
  LOldState: Int32;
begin
  { 原子状态转换：ACTIVE -> CANCELLED }
  LOldState := AtomicExchange32(FState, CANCEL_STATE_CANCELLED, moAcqRel);
  if LOldState = CANCEL_STATE_CANCELLED then
    Exit;  { 已经取消，避免重复触发 }

  platform_mutex_lock(FLock);
  try
    FCondReady := True;
    platform_condvar_broadcast(FCond);
    FireCallbacks;
    CancelChildren;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAsyncCancellationTokenImpl.IsCancelled: Boolean;
begin
  Result := AtomicLoad32(FState, moAcquire) = CANCEL_STATE_CANCELLED;
end;

procedure TAsyncCancellationTokenImpl.OnCancel(ACallback: TCancelCallback;
  AContext: Pointer);
var
  LEntry: PCancelCallbackEntry;
begin
  platform_mutex_lock(FLock);
  try
    { 如果已取消，立即调用 }
    if FState = CANCEL_STATE_CANCELLED then
    begin
      try
        if Assigned(ACallback) then
          ACallback(AContext);
      except
        { 吞掉回调异常 }
      end;
      Exit;
    end;
    { 否则加入回调链表 }
    New(LEntry);
    LEntry^.Callback := ACallback;
    LEntry^.Context := AContext;
    LEntry^.Next := nil;
    if FCallbackTail <> nil then
      FCallbackTail^.Next := LEntry
    else
      FCallbacks := LEntry;
    FCallbackTail := LEntry;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAsyncCancellationTokenImpl.CreateChildToken: IAsyncCancellationToken;
begin
  Result := TAsyncCancellationTokenImpl.Create(Self);
end;

function TAsyncCancellationTokenImpl.WaitForCancel(ATimeoutMs: UInt32): Boolean;
var
  LTimeoutNs: Int64;
begin
  platform_mutex_lock(FLock);
  try
    if FState = CANCEL_STATE_CANCELLED then
      Exit(True);
    if ATimeoutMs = 0 then
    begin
      { 无限等待 }
      while not FCondReady do
        platform_condvar_wait(FCond, FLock);
      Exit(True);
    end
    else
    begin
      { 超时等待（纳秒） }
      LTimeoutNs := Int64(ATimeoutMs) * 1000000;
      platform_condvar_timedwait(FCond, FLock, LTimeoutNs);
      Result := FState = CANCEL_STATE_CANCELLED;
    end;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

{ 工厂函数 }

function CreateCancellationToken: IAsyncCancellationToken;
begin
  Result := TAsyncCancellationTokenImpl.Create(nil);
end;

end.
