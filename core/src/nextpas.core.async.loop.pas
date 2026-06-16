unit nextpas.core.async.loop;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base, nextpas.core.time.deadline,
  nextpas.core.platform.io.base,
  nextpas.core.platform.sync.base,
  nextpas.core.io.poller,
  nextpas.core.async.base, nextpas.core.async.timer,
  nextpas.core.async.task;

type
  TAsyncPendingItem = record
    Callback: TAsyncCallback;
    Context: Pointer;
  end;

  TAsyncLoop = record
  private
    FPoller: TPoller;
    FWakePoller: TPlatformPoller;
    FWakeReady: Boolean;
    FTimers: TTimerHeap;
    FRunning: Int32;
    FPendingQueue: array of TAsyncPendingItem;
    FPendingCount: UInt32;
    FPendingCap: UInt32;
    FPendingLock: TPlatformMutex;
    FPendingReady: Boolean;
    procedure DrainPending;
    procedure DrainWake;
    procedure WaitForWake(ATimeoutMs: Int32);
  public
    class function Create(AQueueDepth: UInt32 = 64): TAsyncLoop; static;
    procedure Close;
    function IsValid: Boolean; inline;

    { Cross-thread wake }
    procedure Post(ACallback: TAsyncCallback; AContext: Pointer = nil);
    procedure Wake;

    { Timer scheduling }
    function Schedule(const ADelay: TDuration; ACallback: TAsyncCallback;
      AContext: Pointer = nil): TAsyncTimerHandle;
    function ScheduleAt(const ADeadline: TDeadline; ACallback: TAsyncCallback;
      AContext: Pointer = nil): TAsyncTimerHandle;
    function CancelTimer(const AHandle: TAsyncTimerHandle): Boolean;

    { I/O delegates }
    function AsyncRead(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWrite(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncAccept(AFd: PtrInt; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecv(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncSend(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
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

    { Async sleep }
    function AsyncSleep(const ADelay: TDuration; ACallback: TAsyncCallback;
      AContext: Pointer = nil): TAsyncTimerHandle;

    { Event loop }
    function Poll: Int32;
    procedure Run;
    procedure RunOnce;
    procedure Stop;
  end;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.platform.io,
  nextpas.core.platform.sync;

const
  ETIMEDOUT_LINUX = 110;
  PENDING_INITIAL_CAP = 32;
  ASYNC_PENDING_IO_IDLE_POLL_MS = 10;
  TIMEOUT_COMPLETION_PENDING = 0;
  TIMEOUT_COMPLETION_IO = 1;
  TIMEOUT_COMPLETION_TIMER = 2;

type
  PAsyncLoop = ^TAsyncLoop;
  PTimeoutCtx = ^TTimeoutCtx;
  TTimeoutCtx = record
    Loop: PAsyncLoop;
    UserCallback: TIoCompletion;
    UserContext: Pointer;
    TimerHandle: TAsyncTimerHandle;
    CompletionState: Int32;
    RefCount: Int32;
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
begin
  Result := AtomicCompareExchange32(ACtx^.CompletionState,
    TIMEOUT_COMPLETION_PENDING, AState, moAcqRel) = TIMEOUT_COMPLETION_PENDING;
end;

procedure TimeoutCtxRelease(ACtx: PTimeoutCtx);
begin
  if ACtx = nil then
    Exit;
  if AtomicFetchSub32(ACtx^.RefCount, 1, moAcqRel) = 1 then
  begin
    ACtx^.Loop := nil;
    ACtx^.UserCallback := nil;
    ACtx^.UserContext := nil;
    Dispose(ACtx);
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
  if ACtx^.Loop^.FTimers.Cancel(LTimerHandle) then
    TimeoutCtxRelease(ACtx);
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
    end;
  finally
    TimeoutCtxRelease(LCtx);
  end;
end;

function TimeoutCtxCreate(ALoop: PAsyncLoop; const ADeadline: TDeadline;
  ACallback: TIoCompletion; AContext: Pointer): PTimeoutCtx;
begin
  New(Result);
  Result^.Loop := ALoop;
  Result^.UserCallback := ACallback;
  Result^.UserContext := AContext;
  Result^.CompletionState := TIMEOUT_COMPLETION_PENDING;
  Result^.RefCount := 2;
  Result^.TimerHandle := ALoop^.FTimers.Schedule(ADeadline,
    @TimeoutTimerCallback, Result);
end;

{ TAsyncLoop }

class function TAsyncLoop.Create(AQueueDepth: UInt32): TAsyncLoop;
begin
  Result := Default(TAsyncLoop);
  Result.FPoller := TPoller.Create(AQueueDepth);
  Result.FWakeReady := False;
  if platform_poller_create(Result.FWakePoller) = 0 then
  begin
    if platform_poller_enable_wake(Result.FWakePoller, nil) = 0 then
      Result.FWakeReady := True
    else
      platform_poller_close(Result.FWakePoller);
  end;
  Result.FTimers := TTimerHeap.Create;
  Result.FRunning := 0;
  Result.FPendingCount := 0;
  Result.FPendingCap := PENDING_INITIAL_CAP;
  SetLength(Result.FPendingQueue, PENDING_INITIAL_CAP);
  Result.FPendingReady := platform_mutex_init(Result.FPendingLock,
    PLATFORM_MUTEX_NORMAL) = 0;
end;

procedure TAsyncLoop.Close;
var
  LWakeWasReady: Boolean;
  LPendingWasReady: Boolean;
  LI: UInt32;

  procedure ClearPendingQueue;
  begin
    LI := 0;
    while LI < FPendingCount do
    begin
      FPendingQueue[LI].Callback := nil;
      FPendingQueue[LI].Context := nil;
      Inc(LI);
    end;
    FPendingCount := 0;
    FPendingCap := 0;
    SetLength(FPendingQueue, 0);
  end;

begin
  LWakeWasReady := FWakeReady;
  LPendingWasReady := FPendingReady;
  AtomicStore32(FRunning, 0, moRelease);
  FWakeReady := False;
  if LPendingWasReady then
  begin
    platform_mutex_lock(FPendingLock);
    try
      FPendingReady := False;
      ClearPendingQueue;
    finally
      platform_mutex_unlock(FPendingLock);
    end;
  end
  else
    FPendingReady := False;
  try
    FPoller.Close;
  finally
    FTimers.Clear;
    if LPendingWasReady then
      platform_mutex_destroy(FPendingLock);
    if LWakeWasReady then
      platform_poller_close(FWakePoller);
  end;
end;

function TAsyncLoop.IsValid: Boolean;
begin
  Result := FPoller.IsValid and FWakeReady and FPendingReady;
end;

{ Cross-thread wake }

procedure TAsyncLoop.Wake;
begin
  if not FWakeReady then
    Exit;
  platform_poller_wake(FWakePoller);
end;

procedure TAsyncLoop.Post(ACallback: TAsyncCallback; AContext: Pointer);
var
  LNewCap: UInt32;
begin
  if not IsValid then
    Exit;
  platform_mutex_lock(FPendingLock);
  try
    if FPendingCount >= FPendingCap then
    begin
      LNewCap := FPendingCap * 2;
      SetLength(FPendingQueue, LNewCap);
      FPendingCap := LNewCap;
    end;
    FPendingQueue[FPendingCount].Callback := ACallback;
    FPendingQueue[FPendingCount].Context := AContext;
    Inc(FPendingCount);
  finally
    platform_mutex_unlock(FPendingLock);
  end;
  Wake;
end;

procedure TAsyncLoop.DrainWake;
begin
  if FWakeReady then
    platform_poller_drain_wake(FWakePoller);
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

procedure TAsyncLoop.DrainPending;
var
  LI: UInt32;
  LItems: array of TAsyncPendingItem;
  LCount: UInt32;
begin
  if not FPendingReady then
    Exit;
  platform_mutex_lock(FPendingLock);
  try
    LCount := FPendingCount;
    if LCount > 0 then
    begin
      SetLength(LItems, LCount);
      Move(FPendingQueue[0], LItems[0], LCount * SizeOf(TAsyncPendingItem));
      for LI := 0 to LCount - 1 do
      begin
        FPendingQueue[LI].Callback := nil;
        FPendingQueue[LI].Context := nil;
      end;
      FPendingCount := 0;
    end;
  finally
    platform_mutex_unlock(FPendingLock);
  end;
  if LCount = 0 then
    Exit;
  for LI := 0 to LCount - 1 do
  begin
    if Assigned(LItems[LI].Callback) then
      LItems[LI].Callback(LItems[LI].Context);
  end;
end;

function TAsyncLoop.Schedule(const ADelay: TDuration; ACallback: TAsyncCallback;
  AContext: Pointer): TAsyncTimerHandle;
begin
  if not IsValid then
    Exit(TAsyncTimerHandle.None);
  Result := FTimers.ScheduleAfter(ADelay, ACallback, AContext);
end;

function TAsyncLoop.ScheduleAt(const ADeadline: TDeadline; ACallback: TAsyncCallback;
  AContext: Pointer): TAsyncTimerHandle;
begin
  if not IsValid then
    Exit(TAsyncTimerHandle.None);
  Result := FTimers.Schedule(ADeadline, ACallback, AContext);
end;

function TAsyncLoop.CancelTimer(const AHandle: TAsyncTimerHandle): Boolean;
begin
  if not IsValid then
    Exit(False);
  Result := FTimers.Cancel(AHandle);
end;

function TAsyncLoop.AsyncRead(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    Exit(False);
  Result := FPoller.AsyncRead(AFd, ABuf, ALen, AOffset, ACallback, AContext);
end;

function TAsyncLoop.AsyncWrite(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    Exit(False);
  Result := FPoller.AsyncWrite(AFd, ABuf, ALen, AOffset, ACallback, AContext);
end;

function TAsyncLoop.AsyncAccept(AFd: PtrInt; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    Exit(False);
  Result := FPoller.AsyncAccept(AFd, AAddr, AAddrLen, AFlags, ACallback, AContext);
end;

function TAsyncLoop.AsyncRecv(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    Exit(False);
  Result := FPoller.AsyncRecv(AFd, ABuf, ALen, AFlags, ACallback, AContext);
end;

function TAsyncLoop.AsyncSend(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  if not IsValid then
    Exit(False);
  Result := FPoller.AsyncSend(AFd, ABuf, ALen, AFlags, ACallback, AContext);
end;

function TAsyncLoop.Poll: Int32;
var
  LFired: UInt32;
  LIo: Int32;
begin
  if not IsValid then
    Exit(0);
  { Drain wake signal and process pending callbacks }
  DrainWake;
  DrainPending;
  { Fire expired timers }
  LFired := FTimers.FireExpired;
  { Poll I/O non-blocking }
  FPoller.Flush;
  LIo := FPoller.Poll;
  Result := LIo + Int32(LFired);
end;

procedure TAsyncLoop.Run;
var
  LFired: UInt32;
  LIo: Int32;
  LNext: TDeadline;
begin
  if not IsValid then
    Exit;
  AtomicStore32(FRunning, 1, moRelease);
  try
    while AtomicLoad32(FRunning, moAcquire) <> 0 do
    begin
      { Drain wake signal and process pending callbacks }
      DrainWake;
      DrainPending;
      { Fire expired timers }
      LFired := FTimers.FireExpired;
      { Check if stopped from callback }
      if AtomicLoad32(FRunning, moAcquire) = 0 then
        Break;
      { Poll I/O non-blocking }
      FPoller.Flush;
      LIo := FPoller.Poll;
      { If we did work, loop immediately }
      if (LFired > 0) or (LIo > 0) then
        Continue;
      { Nothing happened: sleep on the platform wake seam until woken or next timer. }
      LNext := FTimers.NextDeadline;
      WaitForWake(AsyncIdleWakeTimeoutMs(FPoller, LNext));
    end;
  finally
    AtomicStore32(FRunning, 0, moRelease);
  end;
end;

procedure TAsyncLoop.RunOnce;
var
  LFired: UInt32;
  LIo: Int32;
  LNext: TDeadline;
begin
  if not IsValid then
    Exit;
  AtomicStore32(FRunning, 1, moRelease);
  try
    { Drain pending first }
    DrainWake;
    DrainPending;
    { Timers first (consistent with Run) }
    LFired := FTimers.FireExpired;
    if AtomicLoad32(FRunning, moAcquire) = 0 then
      Exit;
    { Then I/O }
    FPoller.Flush;
    LIo := FPoller.Poll;
    if (LFired > 0) or (LIo > 0) then
      Exit;
    { Block until next timer or wake }
    LNext := FTimers.NextDeadline;
    WaitForWake(AsyncIdleWakeTimeoutMs(FPoller, LNext));
    { Drain and fire after sleep }
    DrainWake;
    DrainPending;
    FTimers.FireExpired;
    if AtomicLoad32(FRunning, moAcquire) = 0 then
      Exit;
    FPoller.Flush;
    FPoller.Poll;
  finally
    AtomicStore32(FRunning, 0, moRelease);
  end;
end;

procedure TAsyncLoop.Stop;
begin
  AtomicStore32(FRunning, 0, moRelease);
  Wake;
end;

function TAsyncLoop.AsyncSleep(const ADelay: TDuration; ACallback: TAsyncCallback;
  AContext: Pointer): TAsyncTimerHandle;
begin
  if not IsValid then
    Exit(TAsyncTimerHandle.None);
  Result := FTimers.ScheduleAfter(ADelay, ACallback, AContext);
end;

function TAsyncLoop.AsyncReadTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if not IsValid then
    Exit(False);
  if ADeadline.IsInfinite then
    Exit(AsyncRead(AFd, ABuf, ALen, AOffset, ACallback, AContext));
  LCtx := TimeoutCtxCreate(@Self, ADeadline, ACallback, AContext);
  Result := FPoller.AsyncRead(AFd, ABuf, ALen, AOffset, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    TimeoutCtxCancelTimerOwner(LCtx);
    TimeoutCtxRelease(LCtx);
  end;
end;

function TAsyncLoop.AsyncWriteTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if not IsValid then
    Exit(False);
  if ADeadline.IsInfinite then
    Exit(AsyncWrite(AFd, ABuf, ALen, AOffset, ACallback, AContext));
  LCtx := TimeoutCtxCreate(@Self, ADeadline, ACallback, AContext);
  Result := FPoller.AsyncWrite(AFd, ABuf, ALen, AOffset, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    TimeoutCtxCancelTimerOwner(LCtx);
    TimeoutCtxRelease(LCtx);
  end;
end;

function TAsyncLoop.AsyncRecvTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if not IsValid then
    Exit(False);
  if ADeadline.IsInfinite then
    Exit(AsyncRecv(AFd, ABuf, ALen, AFlags, ACallback, AContext));
  LCtx := TimeoutCtxCreate(@Self, ADeadline, ACallback, AContext);
  Result := FPoller.AsyncRecv(AFd, ABuf, ALen, AFlags, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    TimeoutCtxCancelTimerOwner(LCtx);
    TimeoutCtxRelease(LCtx);
  end;
end;

function TAsyncLoop.AsyncSendTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if not IsValid then
    Exit(False);
  if ADeadline.IsInfinite then
    Exit(AsyncSend(AFd, ABuf, ALen, AFlags, ACallback, AContext));
  LCtx := TimeoutCtxCreate(@Self, ADeadline, ACallback, AContext);
  Result := FPoller.AsyncSend(AFd, ABuf, ALen, AFlags, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    TimeoutCtxCancelTimerOwner(LCtx);
    TimeoutCtxRelease(LCtx);
  end;
end;

end.
