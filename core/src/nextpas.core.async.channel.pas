unit nextpas.core.async.channel;
{**
 * @desc 异步通道：生产者-消费者模式的异步消息传递。
 *       支持有界/无界通道，背压控制。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.async.base, nextpas.core.async.loop;

type
  { 通道关闭回调 }
  TChannelCloseCallback = procedure(AContext: Pointer);

  { 异步通道 }
  IAsyncChannel = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-700000000003}']
    { Non-blocking try-send: full or closed → False (no queue). }
    function Send(const AData; ASize: UInt32): Boolean;
    { Alias of Send (symmetric with TryReceive). }
    function TrySend(const AData; ASize: UInt32): Boolean;

    { Async send: queues a copy when full; completion callback when enqueued
      (or when Close wakes waiters — caller must check IsClosed). }
    procedure SendAsync(const AData; ASize: UInt32;
      ACallback: TAsyncCallback; AContext: Pointer = nil);
    procedure SendAsyncRef(const AData; ASize: UInt32;
      ACallback: TAsyncCallbackRef; AContext: Pointer = nil);

    { Async receive notify: data available or closed → Post callback.
      Caller still uses TryReceive to copy bytes out. }
    procedure Receive(ACallback: TAsyncCallback; AContext: Pointer = nil);
    procedure ReceiveRef(ACallback: TAsyncCallbackRef; AContext: Pointer = nil);

    function TryReceive(var AData; ASize: UInt32; out AReceived: UInt32): Boolean;

    procedure Close;
    function IsClosed: Boolean;
    function BufferedSize: UInt32;
  end;

{ 创建无界通道 }
function CreateAsyncChannel(const ALoop: TAsyncLoop): IAsyncChannel;

{ 创建有界通道 }
function CreateBoundedAsyncChannel(const ALoop: TAsyncLoop;
  ACapacity: UInt32): IAsyncChannel;

implementation

uses
  nextpas.core.errors,
  nextpas.core.platform.sync;

type

  PReceiveWaiter = ^TReceiveWaiter;
  TReceiveWaiter = record
    Callback: TAsyncCallback;
    Ref: TAsyncCallbackRef;
    Context: Pointer;
    Next: PReceiveWaiter;
  end;

  PDataChunk = ^TDataChunk;
  TDataChunk = record
    Data: Pointer;
    Size: UInt32;
    Next: PDataChunk;
  end;

  PSendWaiter = ^TSendWaiter;
  TSendWaiter = record
    Data: Pointer;
    Size: UInt32;
    Callback: TAsyncCallback;
    Ref: TAsyncCallbackRef;
    Context: Pointer;
    Next: PSendWaiter;
  end;

  TAsyncChannel = class(TInterfacedObject, IAsyncChannel)
  private
    FLoop: TAsyncLoop;
    FCapacity: UInt32;  { 0 = 无界 }
    FCurrentSize: UInt32;
    FClosed: Boolean;
    FDataHead: PDataChunk;
    FDataTail: PDataChunk;
    FDataCount: UInt32;
    FWaiterHead: PReceiveWaiter;
    FWaiterTail: PReceiveWaiter;
    FSendHead: PSendWaiter;
    FSendTail: PSendWaiter;
    FLock: TPlatformMutex;

    procedure EnqueueData(const AData; ASize: UInt32);
    function DequeueData(var AData; ASize: UInt32; out AReceived: UInt32): Boolean;
    procedure DrainWaiters;
    procedure DrainSenders;
  public
    constructor Create(const ALoop: TAsyncLoop; ACapacity: UInt32);
    destructor Destroy; override;

    { IAsyncChannel }
    function Send(const AData; ASize: UInt32): Boolean;
    function TrySend(const AData; ASize: UInt32): Boolean;
    procedure SendAsync(const AData; ASize: UInt32;
      ACallback: TAsyncCallback; AContext: Pointer = nil);
    procedure SendAsyncRef(const AData; ASize: UInt32;
      ACallback: TAsyncCallbackRef; AContext: Pointer = nil);
    procedure Receive(ACallback: TAsyncCallback; AContext: Pointer = nil);
    procedure ReceiveRef(ACallback: TAsyncCallbackRef; AContext: Pointer = nil);
    function TryReceive(var AData; ASize: UInt32; out AReceived: UInt32): Boolean;
    procedure Close;
    function IsClosed: Boolean;
    function BufferedSize: UInt32;
  end;

{ TAsyncChannel }

constructor TAsyncChannel.Create(const ALoop: TAsyncLoop; ACapacity: UInt32);
begin
  inherited Create;
  FLoop := ALoop;  { 存储指向调用者 loop 的指针 }
  FCapacity := ACapacity;
  FCurrentSize := 0;
  FClosed := False;
  FDataHead := nil;
  FDataTail := nil;
  FDataCount := 0;
  FWaiterHead := nil;
  FWaiterTail := nil;
  FSendHead := nil;
  FSendTail := nil;
  if platform_mutex_init(FLock, PLATFORM_MUTEX_NORMAL) <> 0 then
    raise EInvalidOperationError.Create('async channel: mutex init failed');
end;

destructor TAsyncChannel.Destroy;
var
  LChunk, LNextChunk: PDataChunk;
  LWaiter, LNextWaiter: PReceiveWaiter;
  LSender, LNextSender: PSendWaiter;
begin
  LChunk := FDataHead;
  while LChunk <> nil do
  begin
    LNextChunk := LChunk^.Next;
    FreeMem(LChunk^.Data, LChunk^.Size);
    Dispose(LChunk);
    LChunk := LNextChunk;
  end;
  LWaiter := FWaiterHead;
  while LWaiter <> nil do
  begin
    LNextWaiter := LWaiter^.Next;
    Dispose(LWaiter);
    LWaiter := LNextWaiter;
  end;
  LSender := FSendHead;
  while LSender <> nil do
  begin
    LNextSender := LSender^.Next;
    FreeMem(LSender^.Data, LSender^.Size);
    Dispose(LSender);
    LSender := LNextSender;
  end;
  platform_mutex_destroy(FLock);
  { 不 Dispose(FLoop)，因为不拥有 }
  inherited;
end;

procedure TAsyncChannel.EnqueueData(const AData; ASize: UInt32);
var
  LChunk: PDataChunk;
begin
  New(LChunk);
  GetMem(LChunk^.Data, ASize);
  Move(AData, LChunk^.Data^, ASize);
  LChunk^.Size := ASize;
  LChunk^.Next := nil;
  if FDataTail <> nil then
    FDataTail^.Next := LChunk
  else
    FDataHead := LChunk;
  FDataTail := LChunk;
  Inc(FDataCount);
  Inc(FCurrentSize, ASize);
end;

function TAsyncChannel.DequeueData(var AData; ASize: UInt32;
  out AReceived: UInt32): Boolean;
var
  LChunk: PDataChunk;
begin
  Result := False;
  AReceived := 0;
  if FDataHead = nil then
    Exit;
  LChunk := FDataHead;
  FDataHead := LChunk^.Next;
  if FDataHead = nil then
    FDataTail := nil;
  Dec(FDataCount);
  Dec(FCurrentSize, LChunk^.Size);
  AReceived := LChunk^.Size;
  if AReceived > ASize then
    AReceived := ASize;
  Move(LChunk^.Data^, AData, AReceived);
  FreeMem(LChunk^.Data, LChunk^.Size);
  Dispose(LChunk);
  Result := True;
end;

procedure TAsyncChannel.DrainWaiters;
var
  LWaiter: PReceiveWaiter;
begin
  { 如果有数据且有等待者，唤醒一个 }
  while (FDataHead <> nil) and (FWaiterHead <> nil) do
  begin
    LWaiter := FWaiterHead;
    FWaiterHead := LWaiter^.Next;
    if FWaiterHead = nil then
      FWaiterTail := nil;
    if Assigned(LWaiter^.Callback) then
      FLoop.Post(LWaiter^.Callback, LWaiter^.Context)
    else if Assigned(LWaiter^.Ref) then
      FLoop.PostRef(LWaiter^.Ref, LWaiter^.Context);
    Dispose(LWaiter);
  end;
end;

procedure TAsyncChannel.DrainSenders;
var
  LSender: PSendWaiter;
begin
  { 当有空间时，处理排队的发送者 }
  while (FSendHead <> nil) do
  begin
    { 检查是否有足够空间 }
    if (FCapacity > 0) and (FCurrentSize + FSendHead^.Size > FCapacity) then
      Break;
    LSender := FSendHead;
    FSendHead := LSender^.Next;
    if FSendHead = nil then
      FSendTail := nil;
    EnqueueData(LSender^.Data^, LSender^.Size);
    DrainWaiters;
    if Assigned(LSender^.Callback) then
      FLoop.Post(LSender^.Callback, LSender^.Context)
    else if Assigned(LSender^.Ref) then
      FLoop.PostRef(LSender^.Ref, LSender^.Context);
    FreeMem(LSender^.Data, LSender^.Size);
    Dispose(LSender);
  end;
end;

function TAsyncChannel.Send(const AData; ASize: UInt32): Boolean;
begin
  platform_mutex_lock(FLock);
  try
    if FClosed then
      Exit(False);
    { 有界通道检查容量 }
    if (FCapacity > 0) and (FCurrentSize + ASize > FCapacity) then
      Exit(False);
    EnqueueData(AData, ASize);
    DrainWaiters;
    Result := True;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAsyncChannel.TrySend(const AData; ASize: UInt32): Boolean;
begin
  Result := Send(AData, ASize);
end;

procedure TAsyncChannel.SendAsync(const AData; ASize: UInt32;
  ACallback: TAsyncCallback; AContext: Pointer);
var
  LSender: PSendWaiter;
begin
  platform_mutex_lock(FLock);
  try
    if FClosed then
    begin
      if Assigned(ACallback) then
        FLoop.Post(ACallback, AContext);
      Exit;
    end;
    { 有界通道有空间，直接发送 }
    if (FCapacity = 0) or (FCurrentSize + ASize <= FCapacity) then
    begin
      EnqueueData(AData, ASize);
      DrainWaiters;
      if Assigned(ACallback) then
        FLoop.Post(ACallback, AContext);
      Exit;
    end;
    { 满了，加入发送等待队列 }
    New(LSender);
    GetMem(LSender^.Data, ASize);
    Move(AData, LSender^.Data^, ASize);
    LSender^.Size := ASize;
    LSender^.Callback := ACallback;
    LSender^.Ref := nil;
    LSender^.Context := AContext;
    LSender^.Next := nil;
    if FSendTail <> nil then
      FSendTail^.Next := LSender
    else
      FSendHead := LSender;
    FSendTail := LSender;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TAsyncChannel.SendAsyncRef(const AData; ASize: UInt32;
  ACallback: TAsyncCallbackRef; AContext: Pointer);
var
  LSender: PSendWaiter;
begin
  platform_mutex_lock(FLock);
  try
    if FClosed then
    begin
      if Assigned(ACallback) then
        FLoop.PostRef(ACallback, AContext);
      Exit;
    end;
    { 有界通道有空间，直接发送 }
    if (FCapacity = 0) or (FCurrentSize + ASize <= FCapacity) then
    begin
      EnqueueData(AData, ASize);
      DrainWaiters;
      if Assigned(ACallback) then
        FLoop.PostRef(ACallback, AContext);
      Exit;
    end;
    { 满了，加入发送等待队列 }
    New(LSender);
    GetMem(LSender^.Data, ASize);
    Move(AData, LSender^.Data^, ASize);
    LSender^.Size := ASize;
    LSender^.Callback := nil;
    LSender^.Ref := ACallback;
    LSender^.Context := AContext;
    LSender^.Next := nil;
    if FSendTail <> nil then
      FSendTail^.Next := LSender
    else
      FSendHead := LSender;
    FSendTail := LSender;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TAsyncChannel.Receive(ACallback: TAsyncCallback; AContext: Pointer);
var
  LWaiter: PReceiveWaiter;
begin
  platform_mutex_lock(FLock);
  try
    { 如果有数据，立即通知 }
    if FDataHead <> nil then
    begin
      if Assigned(ACallback) then
        FLoop.Post(ACallback, AContext);
      Exit;
    end;
    { 通道已关闭且无数据 }
    if FClosed then
    begin
      if Assigned(ACallback) then
        FLoop.Post(ACallback, AContext);
      Exit;
    end;
    { 加入等待队列 }
    New(LWaiter);
    LWaiter^.Callback := ACallback;
    LWaiter^.Ref := nil;
    LWaiter^.Context := AContext;
    LWaiter^.Next := nil;
    if FWaiterTail <> nil then
      FWaiterTail^.Next := LWaiter
    else
      FWaiterHead := LWaiter;
    FWaiterTail := LWaiter;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TAsyncChannel.ReceiveRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
var
  LWaiter: PReceiveWaiter;
begin
  platform_mutex_lock(FLock);
  try
    if FDataHead <> nil then
    begin
      if Assigned(ACallback) then
        FLoop.PostRef(ACallback, AContext);
      Exit;
    end;
    if FClosed then
    begin
      if Assigned(ACallback) then
        FLoop.PostRef(ACallback, AContext);
      Exit;
    end;
    New(LWaiter);
    LWaiter^.Callback := nil;
    LWaiter^.Ref := ACallback;
    LWaiter^.Context := AContext;
    LWaiter^.Next := nil;
    if FWaiterTail <> nil then
      FWaiterTail^.Next := LWaiter
    else
      FWaiterHead := LWaiter;
    FWaiterTail := LWaiter;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAsyncChannel.TryReceive(var AData; ASize: UInt32;
  out AReceived: UInt32): Boolean;
begin
  platform_mutex_lock(FLock);
  try
    Result := DequeueData(AData, ASize, AReceived);
    if Result then
      DrainSenders;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

procedure TAsyncChannel.Close;
var
  LWaiter: PReceiveWaiter;
  LSender: PSendWaiter;
begin
  platform_mutex_lock(FLock);
  try
    FClosed := True;
    { 唤醒所有接收等待者 }
    while FWaiterHead <> nil do
    begin
      LWaiter := FWaiterHead;
      FWaiterHead := LWaiter^.Next;
      if Assigned(LWaiter^.Callback) then
        FLoop.Post(LWaiter^.Callback, LWaiter^.Context)
      else if Assigned(LWaiter^.Ref) then
        FLoop.PostRef(LWaiter^.Ref, LWaiter^.Context);
      Dispose(LWaiter);
    end;
    FWaiterTail := nil;
    { 唤醒所有发送等待者 }
    while FSendHead <> nil do
    begin
      LSender := FSendHead;
      FSendHead := LSender^.Next;
      if Assigned(LSender^.Callback) then
        FLoop.Post(LSender^.Callback, LSender^.Context)
      else if Assigned(LSender^.Ref) then
        FLoop.PostRef(LSender^.Ref, LSender^.Context);
      FreeMem(LSender^.Data, LSender^.Size);
      Dispose(LSender);
    end;
    FSendTail := nil;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAsyncChannel.IsClosed: Boolean;
begin
  platform_mutex_lock(FLock);
  try
    Result := FClosed;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

function TAsyncChannel.BufferedSize: UInt32;
begin
  platform_mutex_lock(FLock);
  try
    Result := FCurrentSize;
  finally
    platform_mutex_unlock(FLock);
  end;
end;

{ 工厂函数 }

function CreateAsyncChannel(const ALoop: TAsyncLoop): IAsyncChannel;
begin
  Result := TAsyncChannel.Create(ALoop, 0);
end;

function CreateBoundedAsyncChannel(const ALoop: TAsyncLoop;
  ACapacity: UInt32): IAsyncChannel;
begin
  Result := TAsyncChannel.Create(ALoop, ACapacity);
end;

end.
