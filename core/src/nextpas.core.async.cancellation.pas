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

    { 创建子令牌（父取消时子自动取消）。父持子引用保活（V3-B6）：
      子任务结束时须调用 DetachFromParent 摘链，否则子滞留至父亡。 }
    function CreateChildToken: IAsyncCancellationToken;

    { 从父令牌摘链并释放父侧引用；幂等。子任务收尾的标准动作。 }
    procedure DetachFromParent;

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
    { V3-B6 修复：父持子令牌接口引用。此前列表只存裸指针且子析构不
      摘链——"子先亡、父后取消"时 CancelChildren 解引用已释放内存
      （UAF 窗口）。持引用后子至少存活到摘链；配套 DetachFromParent
      供消费方在子任务结束时显式摘链，防长命父令牌下的滞留累积。 }
    Ref: IAsyncCancellationToken;
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
    procedure DetachFromParent;
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
  LChild: PChildEntry;
begin
  { 从父令牌摘链（V3-B6：正常路径下父持本对象引用期间析构不可达；
    此处兜底父亡重入路径——父析构释放条目引用时可能触发本析构，
    摘链须在父的 FLock 仍存活时完成，故置于成员清理最前） }
  RemoveFromParent;
  { 释放回调链表 }
  LEntry := FCallbacks;
  while LEntry <> nil do
  begin
    LNextEntry := LEntry^.Next;
    Dispose(LEntry);
    LEntry := LNextEntry;
  end;
  { 释放子令牌条目。逐条先摘链再 Dispose：释放接口引用可能重入
    触发子析构（父亡路径下父持的常是末位引用），子析构内 RemoveChild
    必须找不到已摘链条目，否则双重 Dispose（V3-B6）。
    同时清空存活子的 FParent 反向指针——否则子后续 DetachFromParent
    会解引用已亡父对象。顺序：先断反向指针、再摘链、最后释放引用。 }
  while FChildren <> nil do
  begin
    LChild := FChildren;
    FChildren := LChild^.Next;
    if LChild^.Child <> nil then
      TAsyncCancellationTokenImpl(LChild^.Child).FParent := nil;
    LChild^.Child := nil;
    Dispose(LChild);
  end;
  FChildrenTail := nil;
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
var
  LParent: TAsyncCancellationTokenImpl;
begin
  { 先断字段再摘链：Dispose 释放条目引用可能重入触发本对象析构，
    析构内再次进入本过程时 FParent 已 nil，幂等返回（防双重清理） }
  LParent := FParent;
  if LParent <> nil then
  begin
    FParent := nil;
    LParent.RemoveChild(Self);
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
    LEntry^.Ref := AChild;   { V3-B6：父持引用，子至少存活到摘链 }
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
  LOldState := atomic_exchange(FState, CANCEL_STATE_CANCELLED, mo_acq_rel);
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
  Result := atomic_load(FState, mo_acquire) = CANCEL_STATE_CANCELLED;
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

procedure TAsyncCancellationTokenImpl.DetachFromParent;
begin
  RemoveFromParent;
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
