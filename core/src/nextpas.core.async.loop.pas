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
    function AsyncConnect(AFd: PtrInt; AAddr: Pointer; AAddrLen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecv(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncSend(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncClose(AFd: PtrInt;
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

procedure TimeoutIoCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LCtx: PTimeoutCtx;
begin
  LCtx := PTimeoutCtx(AContext);
  try
    if TimeoutCtxClaimCompletion(LCtx, TIMEOUT_COMPLETION_IO) then
    begin
      TimeoutCtxCancelTimerOwner(LCtx);
      if Assigned(LCtx^.UserCallback) then
        LCtx^.UserCallback(AUserData, AResult, LCtx^.UserContext);
    end;
  finally
    TimeoutCtxRelease(LCtx);
  end;
end;

procedure TimeoutTimerCallback(AContext: Pointer);
var
  LCtx: PTimeoutCtx;
begin
  LCtx := PTimeoutCtx(AContext);
  try
    if TimeoutCtxClaimCompletion(LCtx, TIMEOUT_COMPLETION_TIMER) then
    begin
      if Assigned(LCtx^.UserCallback) then
        LCtx^.UserCallback(0, -ETIMEDOUT_LINUX, LCtx^.UserContext);
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
  ALoop^.Wake;
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
  platform_mutex_init(Result.FPendingLock, PLATFORM_MUTEX_NORMAL);
end;

procedure TAsyncLoop.Close;
begin
  Stop;
  Wake;
  FPoller.Close;
  FTimers.Clear;
  platform_mutex_destroy(FPendingLock);
  if FWakeReady then
  begin
    platform_poller_close(FWakePoller);
    FWakeReady := False;
  end;
end;

function TAsyncLoop.IsValid: Boolean;
begin
  Result := FPoller.IsValid and FWakeReady;
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
  if not FWakeReady then
    Exit;
  platform_mutex_lock(FPendingLock);
  if FPendingCount >= FPendingCap then
  begin
    LNewCap := FPendingCap * 2;
    SetLength(FPendingQueue, LNewCap);
    FPendingCap := LNewCap;
  end;
  FPendingQueue[FPendingCount].Callback := ACallback;
  FPendingQueue[FPendingCount].Context := AContext;
  Inc(FPendingCount);
  platform_mutex_unlock(FPendingLock);
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
  platform_mutex_lock(FPendingLock);
  LCount := FPendingCount;
  if LCount = 0 then
  begin
    platform_mutex_unlock(FPendingLock);
    Exit;
  end;
  SetLength(LItems, LCount);
  Move(FPendingQueue[0], LItems[0], LCount * SizeOf(TAsyncPendingItem));
  FPendingCount := 0;
  platform_mutex_unlock(FPendingLock);
  for LI := 0 to LCount - 1 do
  begin
    if Assigned(LItems[LI].Callback) then
      LItems[LI].Callback(LItems[LI].Context);
  end;
end;

function TAsyncLoop.Schedule(const ADelay: TDuration; ACallback: TAsyncCallback;
  AContext: Pointer): TAsyncTimerHandle;
begin
  if not FWakeReady then
    Exit(TAsyncTimerHandle.None);
  Result := FTimers.ScheduleAfter(ADelay, ACallback, AContext);
  Wake;
end;

function TAsyncLoop.ScheduleAt(const ADeadline: TDeadline; ACallback: TAsyncCallback;
  AContext: Pointer): TAsyncTimerHandle;
begin
  if not FWakeReady then
    Exit(TAsyncTimerHandle.None);
  Result := FTimers.Schedule(ADeadline, ACallback, AContext);
  Wake;
end;

function TAsyncLoop.CancelTimer(const AHandle: TAsyncTimerHandle): Boolean;
begin
  if not FWakeReady then
    Exit(False);
  Result := FTimers.Cancel(AHandle);
  if Result then
    Wake;
end;

function TAsyncLoop.AsyncRead(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := FPoller.AsyncRead(AFd, ABuf, ALen, AOffset, ACallback, AContext);
end;

function TAsyncLoop.AsyncWrite(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := FPoller.AsyncWrite(AFd, ABuf, ALen, AOffset, ACallback, AContext);
end;

function TAsyncLoop.AsyncAccept(AFd: PtrInt; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := FPoller.AsyncAccept(AFd, AAddr, AAddrLen, AFlags, ACallback, AContext);
end;

function TAsyncLoop.AsyncConnect(AFd: PtrInt; AAddr: Pointer; AAddrLen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := FPoller.AsyncConnect(AFd, AAddr, AAddrLen, ACallback, AContext);
end;

function TAsyncLoop.AsyncRecv(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := FPoller.AsyncRecv(AFd, ABuf, ALen, AFlags, ACallback, AContext);
end;

function TAsyncLoop.AsyncSend(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := FPoller.AsyncSend(AFd, ABuf, ALen, AFlags, ACallback, AContext);
end;

function TAsyncLoop.AsyncClose(AFd: PtrInt;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := FPoller.AsyncClose(AFd, ACallback, AContext);
end;

function TAsyncLoop.Poll: Int32;
var
  LFired: UInt32;
  LIo: Int32;
begin
  { Timers first (consistent with Run) }
  LFired := FTimers.FireExpired;
  { Then I/O }
  FPoller.Flush;
  LIo := FPoller.Poll;
  { Drain wake signal and pending queue }
  DrainWake;
  DrainPending;
  Result := LIo + Int32(LFired);
end;

procedure TAsyncLoop.Run;
var
  LFired: UInt32;
  LIo: Int32;
  LNext: TDeadline;
  LRemaining: TDuration;
  LTimeoutMs: Int32;
begin
  AtomicStore32(FRunning, 1, moRelease);
  try
    while AtomicLoad32(FRunning, moAcquire) <> 0 do
    begin
      { Drain wake signal and process pending callbacks }
      DrainWake;
      DrainPending;
      { Check if stopped from pending callback }
      if AtomicLoad32(FRunning, moAcquire) = 0 then
        Break;
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
      LRemaining := LNext.Remaining;
      if LRemaining.AsNanoseconds <= 0 then
        Continue;
      { Cap sleep at 10ms to stay responsive }
      LTimeoutMs := Int32(UInt64(LRemaining.AsNanoseconds) div 1000000);
      if LTimeoutMs > 10 then
        LTimeoutMs := 10;
      if LTimeoutMs <= 0 then
        LTimeoutMs := 1;
      WaitForWake(LTimeoutMs);
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
  LRemaining: TDuration;
  LTimeoutMs: Int32;
begin
  { Drain pending first }
  DrainWake;
  DrainPending;
  { Timers first (consistent with Run) }
  LFired := FTimers.FireExpired;
  { Then I/O }
  FPoller.Flush;
  LIo := FPoller.Poll;
  if (LFired > 0) or (LIo > 0) then
    Exit;
  { Block until next timer or wake }
  LNext := FTimers.NextDeadline;
  LRemaining := LNext.Remaining;
  if LRemaining.AsNanoseconds > 0 then
  begin
    LTimeoutMs := Int32(UInt64(LRemaining.AsNanoseconds) div 1000000);
    if LTimeoutMs > 10 then
      LTimeoutMs := 10;
    if LTimeoutMs <= 0 then
      LTimeoutMs := 1;
    WaitForWake(LTimeoutMs);
  end;
  { Drain and fire after sleep }
  DrainWake;
  DrainPending;
  FPoller.Flush;
  FPoller.Poll;
  FTimers.FireExpired;
end;

procedure TAsyncLoop.Stop;
begin
  AtomicStore32(FRunning, 0, moRelease);
  Wake;
end;

function TAsyncLoop.AsyncSleep(const ADelay: TDuration; ACallback: TAsyncCallback;
  AContext: Pointer): TAsyncTimerHandle;
begin
  if not FWakeReady then
    Exit(TAsyncTimerHandle.None);
  Result := FTimers.ScheduleAfter(ADelay, ACallback, AContext);
  Wake;
end;

function TAsyncLoop.AsyncReadTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
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
