unit nextpas.core.async.loop;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base, nextpas.core.time.deadline,
  nextpas.core.platform.io.base,
  nextpas.core.io.poller,
  nextpas.core.async.base, nextpas.core.async.timer,
  nextpas.core.async.task,
  nextpas.core.async.cancellation,
  nextpas.core.lockfree.mpsc;

type
  { MPSC item must stay unmanaged: Callback/Method/Context/OnDiscard only.
    PostRef uses heap-wrapped TAsyncCallbackRef (managed) via Callback.
    OnDiscard frees Context when Close discards an item without invoking it. }
  TAsyncPendingItem = record
    Callback: TAsyncCallback;
    Method: TAsyncCallbackMethod;
    Context: Pointer;
    OnDiscard: TAsyncCallback;
  end;

  { H3-1: cross-thread Post path uses T1 MPSC (N-prod / 1-cons). }
  TAsyncPendingQueue = specialize TMpscQueueImpl<TAsyncPendingItem>;

  { Heap-owned event loop. Dependents store TAsyncLoop refs (not owned);
    free dependents before Free'ing the loop. Close is idempotent; Destroy calls Close. }
  TAsyncLoop = class
  private
    FPoller: TPoller;
    FWakePoller: TPlatformPoller;
    FWakeReady: Boolean;
    FTimers: TTimerHeap;
    FRunning: Int32;
    FPending: TAsyncPendingQueue;
    FPendingReady: Boolean;
    FClosed: Boolean;
    { Wake coalescing (Go netpollBreak-style): 1 = a wake signal is in flight
      since the consumer's last drain, so producers skip the wake syscall. }
    FWakeSignaled: Int32;
    function DrainPending: UInt32;
    procedure DrainWake;
    procedure ResetWakeSignal;
    procedure WaitForWake(ATimeoutMs: Int32);
  public
    constructor Create(AQueueDepth: UInt32 = 64);
    destructor Destroy; override;
    procedure Close;
    function IsValid: Boolean; inline;

    { Cross-thread wake }
    procedure Post(ACallback: TAsyncCallback; AContext: Pointer = nil);
    procedure PostEx(ACallback: TAsyncCallback; AContext: Pointer;
      AOnDiscard: TAsyncCallback);
    procedure PostRef(ACallback: TAsyncCallbackRef; AContext: Pointer = nil);
    procedure PostMethod(ACallback: TAsyncCallbackMethod; AContext: Pointer = nil);
    procedure Wake;

    { Timer scheduling }
    function Schedule(const ADelay: TDuration; ACallback: TAsyncCallback;
      AContext: Pointer = nil): TAsyncTimerHandle;
    function ScheduleEx(const ADelay: TDuration; ACallback: TAsyncCallback;
      AContext: Pointer; AOnDiscard: TAsyncCallback): TAsyncTimerHandle;
    function ScheduleRef(const ADelay: TDuration; ACallback: TAsyncCallbackRef;
      AContext: Pointer = nil): TAsyncTimerHandle;
    function ScheduleMethod(const ADelay: TDuration; ACallback: TAsyncCallbackMethod;
      AContext: Pointer = nil): TAsyncTimerHandle;
    function ScheduleAt(const ADeadline: TDeadline; ACallback: TAsyncCallback;
      AContext: Pointer = nil): TAsyncTimerHandle;
    function CancelTimer(const AHandle: TAsyncTimerHandle): Boolean;

    { I/O delegates。写路径不拷贝调用方缓冲：提交成功到写回调返回前
      ABuf 必须保持有效。短写回调 AResult=本次实际送达（可能 < ALen），
      不自动续发；一 op 一回调。 }
    function AsyncRead(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWrite(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncAccept(AFd: PtrInt; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncConnect(AFd: PtrInt; AAddr: Pointer; AAddrLen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecv(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecvRef(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletionRef; AContext: Pointer = nil): Boolean;
    function AsyncSend(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncSendTo(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      AAddr: Pointer; AAddrLen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecvFrom(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      AAddr: Pointer; AAddrLen: Pointer;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncClose(AFd: PtrInt;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncReadv(AFd: PtrInt; AIovecs: Pointer; ANrVecs: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWritev(AFd: PtrInt; AIovecs: Pointer; ANrVecs: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;

    { I/O with deadline }
    function AsyncReadTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWriteTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecvTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncSendTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncAcceptTimeout(AFd: PtrInt; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
      const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecvFromTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      AAddr: Pointer; AAddrLen: Pointer; const ADeadline: TDeadline;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncSendToTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      AAddr: Pointer; AAddrLen: UInt32; const ADeadline: TDeadline;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    { Timeout + optional CancellationToken (token cancel ≈ -ECANCELED, races timer/I/O). }
    function AsyncReadTimeoutEx(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      const ADeadline: TDeadline; AToken: IAsyncCancellationToken;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWriteTimeoutEx(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      const ADeadline: TDeadline; AToken: IAsyncCancellationToken;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecvTimeoutEx(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      const ADeadline: TDeadline; AToken: IAsyncCancellationToken;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncSendTimeoutEx(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      const ADeadline: TDeadline; AToken: IAsyncCancellationToken;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;

    { Async sleep }
    function AsyncSleep(const ADelay: TDuration; ACallback: TAsyncCallback;
      AContext: Pointer = nil): TAsyncTimerHandle;
    function AsyncSleepRef(const ADelay: TDuration; ACallback: TAsyncCallbackRef;
      AContext: Pointer = nil): TAsyncTimerHandle;

    { Event loop }
    function Poll: Int32;
    procedure Run;
    procedure RunOnce;
    procedure Stop;
    { True if the I/O poller still has in-flight ops (after timeout cancel drain). }
    function HasPendingIo: Boolean; inline;
  end;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.errors,
  nextpas.core.platform.io;

const
  ETIMEDOUT_LINUX = 110;
  ECANCELED_LINUX = 125;
  ASYNC_PENDING_IO_IDLE_POLL_MS = 10;
  TIMEOUT_COMPLETION_PENDING = 0;
  TIMEOUT_COMPLETION_IO = 1;
  TIMEOUT_COMPLETION_TIMER = 2;
  TIMEOUT_COMPLETION_TOKEN = 3;


type
  PAsyncCallbackRefCtx = ^TAsyncCallbackRefCtx;
  TAsyncCallbackRefCtx = record
    Ref: TAsyncCallbackRef;
    Context: Pointer;
  end;

procedure AsyncCallbackRefWrapper(AContext: Pointer);
var
  LCtx: PAsyncCallbackRefCtx;
begin
  LCtx := PAsyncCallbackRefCtx(AContext);
  try
    if Assigned(LCtx^.Ref) then
      LCtx^.Ref(LCtx^.Context);
  finally
    Dispose(LCtx);
  end;
end;

procedure DiscardPendingItem(const AItem: TAsyncPendingItem);
begin
  if Assigned(AItem.OnDiscard) then
  begin
    AItem.OnDiscard(AItem.Context);
    Exit;
  end;
  if AItem.Callback = @AsyncCallbackRefWrapper then
  begin
    if AItem.Context <> nil then
      Dispose(PAsyncCallbackRefCtx(AItem.Context));
  end;
end;


type
  PTimeoutCtx = ^TTimeoutCtx;
  TTimeoutCtx = record
    Loop: TAsyncLoop;
    UserCallback: TIoCompletion;
    UserContext: Pointer;
    TimerHandle: TAsyncTimerHandle;
    CompletionState: Int32;
    RefCount: Int32;
    TokenOwner: Int32;
    Token: IAsyncCancellationToken;
  end;

function AsyncWakeTimeoutMs(const ADeadline: TDeadline): Int32;
var
  LRemainingNs: Int64;
  LTimeoutMs: Int64;
begin
  if ADeadline.IsInfinite then
    Exit(-1);
  LRemainingNs := ADeadline.Remaining.AsNanoseconds;
  if LRemainingNs <= 0 then
    Exit(0);
  LTimeoutMs := LRemainingNs div NS_PER_MS;
  if LRemainingNs mod NS_PER_MS <> 0 then
    Inc(LTimeoutMs);
  if LTimeoutMs > High(Int32) then
    Exit(High(Int32));
  Result := Int32(LTimeoutMs);
end;

function AsyncIdleWakeTimeoutMs(const APoller: TPoller;
  const ADeadline: TDeadline): Int32;
begin
  Result := AsyncWakeTimeoutMs(ADeadline);
  if APoller.HasPending and
     ((Result < 0) or (Result > ASYNC_PENDING_IO_IDLE_POLL_MS)) then
    Result := ASYNC_PENDING_IO_IDLE_POLL_MS;
end;

function TimeoutCtxClaimCompletion(ACtx: PTimeoutCtx; AState: Int32): Boolean;
var
  LExpected: Int32;
begin
  LExpected := TIMEOUT_COMPLETION_PENDING;
  Result := atomic_compare_exchange_strong(ACtx^.CompletionState, LExpected, AState,
    mo_acq_rel, mo_acquire);
end;

procedure TimeoutCtxRelease(ACtx: PTimeoutCtx);
begin
  if ACtx = nil then
    Exit;
  if atomic_fetch_sub(ACtx^.RefCount, 1, mo_acq_rel) = 1 then
  begin
    ACtx^.Loop := nil;
    ACtx^.UserCallback := nil;
    ACtx^.UserContext := nil;
    ACtx^.Token := nil;
    Dispose(ACtx);
  end;
end;

procedure TimeoutTokenNotify(AContext: Pointer); forward;

procedure TimeoutCtxDropTokenOwner(ACtx: PTimeoutCtx);
var
  LToken: IAsyncCancellationToken;
begin
  if ACtx = nil then
    Exit;
  if atomic_exchange(ACtx^.TokenOwner, 0, mo_acq_rel) = 1 then
  begin
    LToken := ACtx^.Token;
    if LToken <> nil then
      LToken.RemoveOnCancel(@TimeoutTokenNotify, ACtx);
    ACtx^.Token := nil;
    TimeoutCtxRelease(ACtx);
  end;
end;

procedure TimeoutCtxCancelTimerOwner(ACtx: PTimeoutCtx);
var
  LTimerHandle: TAsyncTimerHandle;
begin
  if (ACtx = nil) or (ACtx^.Loop = nil) then
    Exit;
  LTimerHandle := ACtx^.TimerHandle;
  if not LTimerHandle.IsValid then
    Exit;
  ACtx^.TimerHandle := TAsyncTimerHandle.None;
  if ACtx^.Loop.FTimers.Cancel(LTimerHandle) then
    TimeoutCtxRelease(ACtx);
end;

{ Close/Recycle abandoned timeout timer without firing: drop timer ownership only. }
procedure TimeoutCtxDiscardTimer(AContext: Pointer);
var
  LCtx: PTimeoutCtx;
begin
  LCtx := PTimeoutCtx(AContext);
  if LCtx = nil then
    Exit;
  LCtx^.TimerHandle := TAsyncTimerHandle.None;
  TimeoutCtxRelease(LCtx);
end;

procedure TimeoutCtxDetachUserRefs(ACtx: PTimeoutCtx;
  out ACallback: TIoCompletion; out AContext: Pointer);
begin
  ACallback := nil;
  AContext := nil;
  if ACtx = nil then
    Exit;
  ACallback := ACtx^.UserCallback;
  AContext := ACtx^.UserContext;
  ACtx^.UserCallback := nil;
  ACtx^.UserContext := nil;
end;

procedure TimeoutIoCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LCtx: PTimeoutCtx;
  LUserCallback: TIoCompletion;
  LUserContext: Pointer;
begin
  LCtx := PTimeoutCtx(AContext);
  try
    if TimeoutCtxClaimCompletion(LCtx, TIMEOUT_COMPLETION_IO) then
    begin
      TimeoutCtxDetachUserRefs(LCtx, LUserCallback, LUserContext);
      TimeoutCtxCancelTimerOwner(LCtx);
      TimeoutCtxDropTokenOwner(LCtx);
      if Assigned(LUserCallback) then
        LUserCallback(AUserData, AResult, LUserContext);
    end;
  finally
    TimeoutCtxRelease(LCtx);
  end;
end;

procedure TimeoutTimerCallback(AContext: Pointer);
var
  LCtx: PTimeoutCtx;
  LUserCallback: TIoCompletion;
  LUserContext: Pointer;
begin
  LCtx := PTimeoutCtx(AContext);
  try
    if TimeoutCtxClaimCompletion(LCtx, TIMEOUT_COMPLETION_TIMER) then
    begin
      TimeoutCtxDetachUserRefs(LCtx, LUserCallback, LUserContext);
      if Assigned(LUserCallback) then
        LUserCallback(0, -ETIMEDOUT_LINUX, LUserContext);
      if (LCtx^.Loop <> nil) and LCtx^.Loop.IsValid then
      begin
        if LCtx^.Loop.FPoller.TryCancelByContext(LCtx) then
          LCtx^.Loop.FPoller.Flush;
      end;
      TimeoutCtxDropTokenOwner(LCtx);
    end;
  finally
    TimeoutCtxRelease(LCtx);
  end;
end;

procedure TimeoutTokenCallback(AContext: Pointer);
var
  LCtx: PTimeoutCtx;
  LUserCallback: TIoCompletion;
  LUserContext: Pointer;
begin
  LCtx := PTimeoutCtx(AContext);
  try
    if TimeoutCtxClaimCompletion(LCtx, TIMEOUT_COMPLETION_TOKEN) then
    begin
      TimeoutCtxDetachUserRefs(LCtx, LUserCallback, LUserContext);
      if Assigned(LUserCallback) then
        LUserCallback(0, -ECANCELED_LINUX, LUserContext);
      TimeoutCtxCancelTimerOwner(LCtx);
      if (LCtx^.Loop <> nil) and LCtx^.Loop.IsValid then
      begin
        if LCtx^.Loop.FPoller.TryCancelByContext(LCtx) then
          LCtx^.Loop.FPoller.Flush;
      end;
    end;
  finally
    TimeoutCtxDropTokenOwner(LCtx);
    TimeoutCtxRelease(LCtx); { Post pin from TimeoutTokenNotify }
  end;
end;

procedure TimeoutTokenNotify(AContext: Pointer);
var
  LCtx: PTimeoutCtx;
begin
  LCtx := PTimeoutCtx(AContext);
  if LCtx = nil then
    Exit;
  if atomic_load(LCtx^.TokenOwner, mo_acquire) = 0 then
    Exit;
  if atomic_load(LCtx^.CompletionState, mo_acquire) <> TIMEOUT_COMPLETION_PENDING then
    Exit;
  if (LCtx^.Loop = nil) or (not LCtx^.Loop.IsValid) then
    Exit;
  atomic_fetch_add(LCtx^.RefCount, 1, mo_acq_rel);
  LCtx^.Loop.Post(@TimeoutTokenCallback, LCtx);
end;

function TimeoutCtxCreate(ALoop: TAsyncLoop; const ADeadline: TDeadline;
  ACallback: TIoCompletion; AContext: Pointer;
  AToken: IAsyncCancellationToken = nil): PTimeoutCtx;
begin
  New(Result);
  FillChar(Result^, SizeOf(Result^), 0);
  Result^.Loop := ALoop;
  Result^.UserCallback := ACallback;
  Result^.UserContext := AContext;
  Result^.CompletionState := TIMEOUT_COMPLETION_PENDING;
  Result^.RefCount := 2;
  Result^.TokenOwner := 0;
  Result^.Token := AToken;
  Result^.TimerHandle := ALoop.FTimers.ScheduleEx(ADeadline,
    @TimeoutTimerCallback, Result, @TimeoutCtxDiscardTimer);
  if AToken <> nil then
  begin
    atomic_store(Result^.TokenOwner, 1, mo_release);
    atomic_fetch_add(Result^.RefCount, 1, mo_acq_rel);
    AToken.OnCancel(@TimeoutTokenNotify, Result);
  end;
end;

{ TAsyncLoop }

constructor TAsyncLoop.Create(AQueueDepth: UInt32);
begin
  inherited Create;
  FClosed := False;
  FWakeReady := False;
  FPendingReady := False;
  FPending := nil;
  FRunning := 0;
  FWakeSignaled := 0;
  FPoller := TPoller.Create(AQueueDepth);
  if not FPoller.IsValid then
    raise EInvalidOperationError.Create('async loop: poller creation failed');
  if platform_poller_create(FWakePoller) = 0 then
  begin
    if platform_poller_enable_wake(FWakePoller, nil) = 0 then
      FWakeReady := True
    else
    begin
      platform_poller_close(FWakePoller);
      raise EInvalidOperationError.Create('async loop: wake poller init failed');
    end;
  end
  else
    raise EInvalidOperationError.Create('async loop: wake poller creation failed');
  FTimers := TTimerHeap.Create;
  FPending := TAsyncPendingQueue.Create;
  FPendingReady := True;
end;

destructor TAsyncLoop.Destroy;
begin
  { Destroy must not raise: Free/heaptrc paths require a clean teardown. }
  try
    Close;
  except
    { Close already released owned resources; swallow so the instance can free. }
  end;
  inherited Destroy;
end;

procedure TAsyncLoop.Close;
var
  LWakeWasReady: Boolean;
  LPendingWasReady: Boolean;
  LItem: TAsyncPendingItem;
begin
  if FClosed then
    Exit;
  FClosed := True;
  LWakeWasReady := FWakeReady;
  LPendingWasReady := FPendingReady;
  atomic_store(FRunning, 0, mo_release);
  FWakeReady := False;
  { Publish closed before Close/drain so concurrent Post fails IsValid or Enqueue. }
  FPendingReady := False;
  if LPendingWasReady and (FPending <> nil) then
  begin
    FPending.Close;
    { Discard remaining items without firing callbacks (same as prior ClearPendingQueue). }
    while FPending.TryDequeue(LItem) do
    begin
      try
        DiscardPendingItem(LItem);
      except
        { Close must continue releasing owned resources even if a discard hook fails. }
      end;
      LItem.Callback := nil;
      LItem.Method := nil;
      LItem.Context := nil;
      LItem.OnDiscard := nil;
    end;
  end;
  try
    FPoller.Close;
  finally
    FTimers.Close;
    if FPending <> nil then
    begin
      FPending.Free;
      FPending := nil;
    end;
    if LWakeWasReady then
      platform_poller_close(FWakePoller);
  end;
end;

function TAsyncLoop.IsValid: Boolean;
begin
  Result := (not FClosed) and FPoller.IsValid and FWakeReady and FPendingReady;
end;

{ Cross-thread wake }

procedure TAsyncLoop.Wake;
begin
  if not FWakeReady then
    Exit;
  { Coalesce: only the 0→1 transition pays the wake syscall. Must be an RMW
    (not load-then-exchange): the full barrier orders the producer's enqueue
    before this flag op, which the lost-wakeup proof relies on. }
  if atomic_exchange(FWakeSignaled, 1, mo_seq_cst) = 0 then
    platform_poller_wake(FWakePoller);
end;

procedure TAsyncLoop.Post(ACallback: TAsyncCallback; AContext: Pointer);
begin
  PostEx(ACallback, AContext, nil);
end;

procedure TAsyncLoop.PostEx(ACallback: TAsyncCallback; AContext: Pointer;
  AOnDiscard: TAsyncCallback);
var
  LItem: TAsyncPendingItem;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: post after close');
  if not Assigned(ACallback) then
    raise EInvalidOperationError.Create('async loop: post nil callback');
  LItem.Callback := ACallback;
  LItem.Method := nil;
  LItem.Context := AContext;
  LItem.OnDiscard := AOnDiscard;
  { MPSC Enqueue raises EInvalidOperationError when closed (ClosedPublishPolicy). }
  FPending.Enqueue(LItem);
  Wake;
end;

procedure TAsyncLoop.PostRef(ACallback: TAsyncCallbackRef; AContext: Pointer);
var
  LCtx: PAsyncCallbackRefCtx;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: post after close');
  if not Assigned(ACallback) then
    raise EInvalidOperationError.Create('async loop: post nil callback');
  New(LCtx);
  LCtx^.Ref := ACallback;
  LCtx^.Context := AContext;
  try
    Post(@AsyncCallbackRefWrapper, LCtx);
  except
    Dispose(LCtx);
    raise;
  end;
end;

procedure TAsyncLoop.PostMethod(ACallback: TAsyncCallbackMethod; AContext: Pointer);
var
  LItem: TAsyncPendingItem;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: post after close');
  if not Assigned(ACallback) then
    raise EInvalidOperationError.Create('async loop: post nil callback');
  LItem.Callback := nil;
  LItem.Method := ACallback;
  LItem.Context := AContext;
  LItem.OnDiscard := nil;
  FPending.Enqueue(LItem);
  Wake;
end;

procedure TAsyncLoop.DrainWake;
begin
  if FWakeReady then
    platform_poller_drain_wake(FWakePoller);
end;

procedure TAsyncLoop.ResetWakeSignal;
begin
  { Consumer pre-sleep order is mandatory: drain wake fd → RMW-reset flag →
    recheck queue. The RMW's full barrier prevents StoreLoad reordering of the
    reset against the queue recheck, which would allow a lost wakeup. }
  atomic_exchange(FWakeSignaled, 0, mo_seq_cst);
end;

procedure TAsyncLoop.WaitForWake(ATimeoutMs: Int32);
var
  LEntry: TPlatformPollEntry;
  LCount: Int32;
begin
  if not FWakeReady then
    Exit;
  FillChar(LEntry, SizeOf(LEntry), 0);
  LCount := 0;
  platform_poller_wait(FWakePoller, @LEntry, 1, ATimeoutMs, LCount);
end;

function TAsyncLoop.DrainPending: UInt32;
var
  LItem: TAsyncPendingItem;
begin
  Result := 0;
  { Single-consumer: only the loop thread may TryDequeue. }
  if (not FPendingReady) or (FPending = nil) then
    Exit;
  while FPending.TryDequeue(LItem) do
  begin
    try
      if Assigned(LItem.Callback) then
        LItem.Callback(LItem.Context)
      else if Assigned(LItem.Method) then
        LItem.Method(LItem.Context);
    except
      { Isolate per-item failure: keep draining so remaining Posts are not stranded. }
    end;
    Inc(Result);
  end;
end;

function TAsyncLoop.Schedule(const ADelay: TDuration; ACallback: TAsyncCallback;
  AContext: Pointer): TAsyncTimerHandle;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FTimers.ScheduleAfter(ADelay, ACallback, AContext);
  Wake;
end;

function TAsyncLoop.ScheduleEx(const ADelay: TDuration; ACallback: TAsyncCallback;
  AContext: Pointer; AOnDiscard: TAsyncCallback): TAsyncTimerHandle;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FTimers.ScheduleAfterEx(ADelay, ACallback, AContext, AOnDiscard);
  Wake;
end;

function TAsyncLoop.ScheduleRef(const ADelay: TDuration; ACallback: TAsyncCallbackRef;
  AContext: Pointer): TAsyncTimerHandle;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FTimers.ScheduleAfterRef(ADelay, ACallback, AContext);
  Wake;
end;

function TAsyncLoop.ScheduleMethod(const ADelay: TDuration; ACallback: TAsyncCallbackMethod;
  AContext: Pointer): TAsyncTimerHandle;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FTimers.ScheduleAfterMethod(ADelay, ACallback, AContext);
  Wake;
end;

function TAsyncLoop.ScheduleAt(const ADeadline: TDeadline; ACallback: TAsyncCallback;
  AContext: Pointer): TAsyncTimerHandle;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FTimers.Schedule(ADeadline, ACallback, AContext);
  Wake;
end;

function TAsyncLoop.CancelTimer(const AHandle: TAsyncTimerHandle): Boolean;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FTimers.Cancel(AHandle);
  if Result then Wake;
end;

function TAsyncLoop.AsyncRead(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FPoller.AsyncRead(AFd, ABuf, ALen, AOffset, ACallback, AContext);
end;

function TAsyncLoop.AsyncWrite(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FPoller.AsyncWrite(AFd, ABuf, ALen, AOffset, ACallback, AContext);
end;

function TAsyncLoop.AsyncAccept(AFd: PtrInt; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FPoller.AsyncAccept(AFd, AAddr, AAddrLen, AFlags, ACallback, AContext);
end;

function TAsyncLoop.AsyncAcceptTimeout(AFd: PtrInt; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
  const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LCtx: PTimeoutCtx;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  if ADeadline.IsInfinite then
    Exit(AsyncAccept(AFd, AAddr, AAddrLen, AFlags, ACallback, AContext));
  { Same TimeoutCtx machinery as the recv/send timeout ops: the armed timer
    cancels the pending accept by context on expiry and reports -ETIMEDOUT. }
  LCtx := TimeoutCtxCreate(Self, ADeadline, ACallback, AContext);
  Result := FPoller.AsyncAccept(AFd, AAddr, AAddrLen, AFlags, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    TimeoutCtxCancelTimerOwner(LCtx);
    TimeoutCtxDropTokenOwner(LCtx);
    TimeoutCtxRelease(LCtx);
  end;
end;

function TAsyncLoop.AsyncConnect(AFd: PtrInt; AAddr: Pointer; AAddrLen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FPoller.AsyncConnect(AFd, AAddr, AAddrLen, ACallback, AContext);
end;

function TAsyncLoop.AsyncRecv(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FPoller.AsyncRecv(AFd, ABuf, ALen, AFlags, ACallback, AContext);
end;

function TAsyncLoop.AsyncRecvRef(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
var
  LCtx: Pointer;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  LCtx := WrapIoCompletionRef(ACallback, AContext);
  Result := AsyncRecv(AFd, ABuf, ALen, AFlags, @IoCompletionRefWrapper, LCtx);
  if not Result then
    Dispose(PIoCompletionRefCtx(LCtx));
end;

function TAsyncLoop.AsyncSend(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FPoller.AsyncSend(AFd, ABuf, ALen, AFlags, ACallback, AContext);
end;

function TAsyncLoop.AsyncSendTo(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  AAddr: Pointer; AAddrLen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FPoller.AsyncSendTo(AFd, ABuf, ALen, AFlags, AAddr, AAddrLen, ACallback, AContext);
end;

function TAsyncLoop.AsyncRecvFrom(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  AAddr: Pointer; AAddrLen: Pointer;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FPoller.AsyncRecvFrom(AFd, ABuf, ALen, AFlags, AAddr, AAddrLen, ACallback, AContext);
end;

function TAsyncLoop.AsyncClose(AFd: PtrInt;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FPoller.AsyncClose(AFd, ACallback, AContext);
end;

function TAsyncLoop.AsyncReadv(AFd: PtrInt; AIovecs: Pointer; ANrVecs: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FPoller.AsyncReadv(AFd, AIovecs, ANrVecs, AOffset, ACallback, AContext);
end;

function TAsyncLoop.AsyncWritev(AFd: PtrInt; AIovecs: Pointer; ANrVecs: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FPoller.AsyncWritev(AFd, AIovecs, ANrVecs, AOffset, ACallback, AContext);
end;

function TAsyncLoop.Poll: Int32;
var
  LDrained, LFired: UInt32;
  LIo: Int32;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  { No DrainWake here: the MPSC queue is the truth for pending callbacks; the
    wake fd only exists to make WaitForWake return, and Poll never blocks. }
  LDrained := DrainPending;
  LFired := FTimers.FireExpired;
  LIo := 0;
  { HasPending is an O(1) registration counter on every backend; when zero
    there is nothing armed, so Flush/Poll would only burn a syscall. }
  if FPoller.HasPending then
  begin
    FPoller.Flush;
    LIo := FPoller.Poll;
  end;
  Result := LIo + Int32(LFired) + Int32(LDrained);
end;

procedure TAsyncLoop.Run;
var
  LDrained, LFired: UInt32;
  LIo: Int32;
  LNext: TDeadline;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: run after close');
  atomic_store(FRunning, 1, mo_release);
  try
    while atomic_load(FRunning, mo_acquire) <> 0 do
    begin
      { Process pending callbacks; the queue is the truth (no wake-fd syscall
        on the hot path — the fd is only drained on the idle transition). }
      LDrained := DrainPending;
      { Fire expired timers }
      LFired := FTimers.FireExpired;
      { Check if stopped from callback }
      if atomic_load(FRunning, mo_acquire) = 0 then
        Break;
      { Poll I/O non-blocking; skip the syscall when nothing is armed }
      LIo := 0;
      if FPoller.HasPending then
      begin
        FPoller.Flush;
        LIo := FPoller.Poll;
      end;
      { If we did work, loop immediately }
      if (LDrained > 0) or (LFired > 0) or (LIo > 0) then
        Continue;
      { Idle transition: drain the wake fd, reset the coalescing flag, then
        recheck the queue — only sleep when nothing raced in. A producer that
        enqueues after the reset sees FWakeSignaled=0 and pays the wake. }
      DrainWake;
      ResetWakeSignal;
      if DrainPending > 0 then
        Continue;
      LNext := FTimers.NextDeadline;
      WaitForWake(AsyncIdleWakeTimeoutMs(FPoller, LNext));
    end;
  finally
    atomic_store(FRunning, 0, mo_release);
  end;
end;

procedure TAsyncLoop.RunOnce;
var
  LDrained, LFired: UInt32;
  LIo: Int32;
  LNext: TDeadline;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: run once after close');
  atomic_store(FRunning, 1, mo_release);
  try
    { Drain pending first (queue is the truth; no wake-fd syscall) }
    LDrained := DrainPending;
    { Timers first (consistent with Run) }
    LFired := FTimers.FireExpired;
    if atomic_load(FRunning, mo_acquire) = 0 then
      Exit;
    { Then I/O; skip the syscall when nothing is armed }
    LIo := 0;
    if FPoller.HasPending then
    begin
      FPoller.Flush;
      LIo := FPoller.Poll;
    end;
    if (LDrained > 0) or (LFired > 0) or (LIo > 0) then
      Exit;
    { Idle transition: same drain → reset → recheck protocol as Run }
    DrainWake;
    ResetWakeSignal;
    if DrainPending > 0 then
      Exit;
    { Block until next timer or wake }
    LNext := FTimers.NextDeadline;
    WaitForWake(AsyncIdleWakeTimeoutMs(FPoller, LNext));
    { Drain and fire after sleep }
    DrainWake;
    ResetWakeSignal;
    DrainPending;
    FTimers.FireExpired;
    if atomic_load(FRunning, mo_acquire) = 0 then
      Exit;
    if FPoller.HasPending then
    begin
      FPoller.Flush;
      FPoller.Poll;
    end;
  finally
    atomic_store(FRunning, 0, mo_release);
  end;
end;

procedure TAsyncLoop.Stop;
begin
  atomic_store(FRunning, 0, mo_release);
  Wake;
end;

function TAsyncLoop.HasPendingIo: Boolean;
begin
  Result := FPoller.HasPending;
end;

function TAsyncLoop.AsyncSleep(const ADelay: TDuration; ACallback: TAsyncCallback;
  AContext: Pointer): TAsyncTimerHandle;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  Result := FTimers.ScheduleAfter(ADelay, ACallback, AContext);
end;

function TAsyncLoop.AsyncSleepRef(const ADelay: TDuration; ACallback: TAsyncCallbackRef;
  AContext: Pointer): TAsyncTimerHandle;
begin
  Result := ScheduleRef(ADelay, ACallback, AContext);
end;

function TAsyncLoop.AsyncReadTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  if ADeadline.IsInfinite then
    Exit(AsyncRead(AFd, ABuf, ALen, AOffset, ACallback, AContext));
  LCtx := TimeoutCtxCreate(Self, ADeadline, ACallback, AContext);
  Result := FPoller.AsyncRead(AFd, ABuf, ALen, AOffset, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    TimeoutCtxCancelTimerOwner(LCtx);
    TimeoutCtxDropTokenOwner(LCtx);
    TimeoutCtxRelease(LCtx);
  end;
end;

function TAsyncLoop.AsyncWriteTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  if ADeadline.IsInfinite then
    Exit(AsyncWrite(AFd, ABuf, ALen, AOffset, ACallback, AContext));
  LCtx := TimeoutCtxCreate(Self, ADeadline, ACallback, AContext);
  Result := FPoller.AsyncWrite(AFd, ABuf, ALen, AOffset, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    TimeoutCtxCancelTimerOwner(LCtx);
    TimeoutCtxDropTokenOwner(LCtx);
    TimeoutCtxRelease(LCtx);
  end;
end;

function TAsyncLoop.AsyncRecvTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  if ADeadline.IsInfinite then
    Exit(AsyncRecv(AFd, ABuf, ALen, AFlags, ACallback, AContext));
  LCtx := TimeoutCtxCreate(Self, ADeadline, ACallback, AContext);
  Result := FPoller.AsyncRecv(AFd, ABuf, ALen, AFlags, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    TimeoutCtxCancelTimerOwner(LCtx);
    TimeoutCtxDropTokenOwner(LCtx);
    TimeoutCtxRelease(LCtx);
  end;
end;

function TAsyncLoop.AsyncSendTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  if ADeadline.IsInfinite then
    Exit(AsyncSend(AFd, ABuf, ALen, AFlags, ACallback, AContext));
  LCtx := TimeoutCtxCreate(Self, ADeadline, ACallback, AContext);
  Result := FPoller.AsyncSend(AFd, ABuf, ALen, AFlags, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    TimeoutCtxCancelTimerOwner(LCtx);
    TimeoutCtxDropTokenOwner(LCtx);
    TimeoutCtxRelease(LCtx);
  end;
end;

function TAsyncLoop.AsyncRecvFromTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  AAddr: Pointer; AAddrLen: Pointer; const ADeadline: TDeadline;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  if ADeadline.IsInfinite then
    Exit(AsyncRecvFrom(AFd, ABuf, ALen, AFlags, AAddr, AAddrLen, ACallback, AContext));
  LCtx := TimeoutCtxCreate(Self, ADeadline, ACallback, AContext);
  Result := FPoller.AsyncRecvFrom(AFd, ABuf, ALen, AFlags, AAddr, AAddrLen,
    @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    TimeoutCtxCancelTimerOwner(LCtx);
    TimeoutCtxDropTokenOwner(LCtx);
    TimeoutCtxRelease(LCtx);
  end;
end;

function TAsyncLoop.AsyncSendToTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  AAddr: Pointer; AAddrLen: UInt32; const ADeadline: TDeadline;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  if ADeadline.IsInfinite then
    Exit(AsyncSendTo(AFd, ABuf, ALen, AFlags, AAddr, AAddrLen, ACallback, AContext));
  LCtx := TimeoutCtxCreate(Self, ADeadline, ACallback, AContext);
  Result := FPoller.AsyncSendTo(AFd, ABuf, ALen, AFlags, AAddr, AAddrLen,
    @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    TimeoutCtxCancelTimerOwner(LCtx);
    TimeoutCtxDropTokenOwner(LCtx);
    TimeoutCtxRelease(LCtx);
  end;
end;

function TAsyncLoop.AsyncRecvTimeoutEx(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  const ADeadline: TDeadline; AToken: IAsyncCancellationToken;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  if ADeadline.IsInfinite and (AToken = nil) then
    Exit(AsyncRecv(AFd, ABuf, ALen, AFlags, ACallback, AContext));
  if ADeadline.IsInfinite then
  begin
    { Token without finite deadline: use a far deadline so timer path exists;
      token is the practical cancel. }
    LCtx := TimeoutCtxCreate(Self, TDeadline.After(TDuration.FromSeconds(3600 * 24 * 365)),
      ACallback, AContext, AToken);
  end
  else
    LCtx := TimeoutCtxCreate(Self, ADeadline, ACallback, AContext, AToken);
  Result := FPoller.AsyncRecv(AFd, ABuf, ALen, AFlags, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    TimeoutCtxCancelTimerOwner(LCtx);
    TimeoutCtxDropTokenOwner(LCtx);
    TimeoutCtxRelease(LCtx);
  end;
end;

function TAsyncLoop.AsyncSendTimeoutEx(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  const ADeadline: TDeadline; AToken: IAsyncCancellationToken;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  if ADeadline.IsInfinite and (AToken = nil) then
    Exit(AsyncSend(AFd, ABuf, ALen, AFlags, ACallback, AContext));
  if ADeadline.IsInfinite then
    LCtx := TimeoutCtxCreate(Self, TDeadline.After(TDuration.FromSeconds(3600 * 24 * 365)),
      ACallback, AContext, AToken)
  else
    LCtx := TimeoutCtxCreate(Self, ADeadline, ACallback, AContext, AToken);
  Result := FPoller.AsyncSend(AFd, ABuf, ALen, AFlags, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    TimeoutCtxCancelTimerOwner(LCtx);
    TimeoutCtxDropTokenOwner(LCtx);
    TimeoutCtxRelease(LCtx);
  end;
end;

function TAsyncLoop.AsyncReadTimeoutEx(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  const ADeadline: TDeadline; AToken: IAsyncCancellationToken;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  if ADeadline.IsInfinite and (AToken = nil) then
    Exit(AsyncRead(AFd, ABuf, ALen, AOffset, ACallback, AContext));
  if ADeadline.IsInfinite then
    LCtx := TimeoutCtxCreate(Self, TDeadline.After(TDuration.FromSeconds(3600 * 24 * 365)),
      ACallback, AContext, AToken)
  else
    LCtx := TimeoutCtxCreate(Self, ADeadline, ACallback, AContext, AToken);
  Result := FPoller.AsyncRead(AFd, ABuf, ALen, AOffset, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    TimeoutCtxCancelTimerOwner(LCtx);
    TimeoutCtxDropTokenOwner(LCtx);
    TimeoutCtxRelease(LCtx);
  end;
end;

function TAsyncLoop.AsyncWriteTimeoutEx(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  const ADeadline: TDeadline; AToken: IAsyncCancellationToken;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if not IsValid then
    raise EInvalidOperationError.Create('async loop: operation after close');
  if ADeadline.IsInfinite and (AToken = nil) then
    Exit(AsyncWrite(AFd, ABuf, ALen, AOffset, ACallback, AContext));
  if ADeadline.IsInfinite then
    LCtx := TimeoutCtxCreate(Self, TDeadline.After(TDuration.FromSeconds(3600 * 24 * 365)),
      ACallback, AContext, AToken)
  else
    LCtx := TimeoutCtxCreate(Self, ADeadline, ACallback, AContext, AToken);
  Result := FPoller.AsyncWrite(AFd, ABuf, ALen, AOffset, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    TimeoutCtxCancelTimerOwner(LCtx);
    TimeoutCtxDropTokenOwner(LCtx);
    TimeoutCtxRelease(LCtx);
  end;
end;

end.
