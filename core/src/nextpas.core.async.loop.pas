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

type
  PAsyncLoop = ^TAsyncLoop;
  PTimeoutCtx = ^TTimeoutCtx;
  TTimeoutCtx = record
    Loop: PAsyncLoop;
    UserCallback: TIoCompletion;
    UserContext: Pointer;
    TimerHandle: TAsyncTimerHandle;
    IoCompleted: Boolean;
    TimerFired: Boolean;
  end;

procedure TimeoutIoCallback(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LCtx: PTimeoutCtx;
begin
  LCtx := PTimeoutCtx(AContext);
  if LCtx^.TimerFired then
  begin
    Dispose(LCtx);
    Exit;
  end;
  LCtx^.IoCompleted := True;
  // Cancel timer (best effort, may already be fired)
  if LCtx^.TimerHandle.IsValid then
    LCtx^.Loop^.FTimers.Cancel(LCtx^.TimerHandle);
  if Assigned(LCtx^.UserCallback) then
    LCtx^.UserCallback(AUserData, AResult, LCtx^.UserContext);
  Dispose(LCtx);
end;

procedure TimeoutTimerCallback(AContext: Pointer);
var
  LCtx: PTimeoutCtx;
begin
  LCtx := PTimeoutCtx(AContext);
  if LCtx^.IoCompleted then
  begin
    Dispose(LCtx);
    Exit;
  end;
  LCtx^.TimerFired := True;
  if Assigned(LCtx^.UserCallback) then
    LCtx^.UserCallback(0, -ETIMEDOUT_LINUX, LCtx^.UserContext);
  { Note: LCtx will be freed when the I/O eventually completes }
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
  FTimers.Clear;
  platform_mutex_destroy(FPendingLock);
  if FWakeReady then
  begin
    platform_poller_close(FWakePoller);
    FWakeReady := False;
  end;
  FPoller.Close;
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
end;

function TAsyncLoop.ScheduleAt(const ADeadline: TDeadline; ACallback: TAsyncCallback;
  AContext: Pointer): TAsyncTimerHandle;
begin
  if not FWakeReady then
    Exit(TAsyncTimerHandle.None);
  Result := FTimers.Schedule(ADeadline, ACallback, AContext);
end;

function TAsyncLoop.CancelTimer(const AHandle: TAsyncTimerHandle): Boolean;
begin
  if not FWakeReady then
    Exit(False);
  Result := FTimers.Cancel(AHandle);
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
end;

function TAsyncLoop.AsyncSleep(const ADelay: TDuration; ACallback: TAsyncCallback;
  AContext: Pointer): TAsyncTimerHandle;
begin
  if not FWakeReady then
    Exit(TAsyncTimerHandle.None);
  Result := FTimers.ScheduleAfter(ADelay, ACallback, AContext);
end;

function TAsyncLoop.AsyncReadTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if ADeadline.IsInfinite then
    Exit(AsyncRead(AFd, ABuf, ALen, AOffset, ACallback, AContext));
  New(LCtx);
  LCtx^.Loop := @Self;
  LCtx^.UserCallback := ACallback;
  LCtx^.UserContext := AContext;
  LCtx^.IoCompleted := False;
  LCtx^.TimerFired := False;
  LCtx^.TimerHandle := FTimers.Schedule(ADeadline, @TimeoutTimerCallback, LCtx);
  Result := FPoller.AsyncRead(AFd, ABuf, ALen, AOffset, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    FTimers.Cancel(LCtx^.TimerHandle);
    Dispose(LCtx);
  end;
end;

function TAsyncLoop.AsyncWriteTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if ADeadline.IsInfinite then
    Exit(AsyncWrite(AFd, ABuf, ALen, AOffset, ACallback, AContext));
  New(LCtx);
  LCtx^.Loop := @Self;
  LCtx^.UserCallback := ACallback;
  LCtx^.UserContext := AContext;
  LCtx^.IoCompleted := False;
  LCtx^.TimerFired := False;
  LCtx^.TimerHandle := FTimers.Schedule(ADeadline, @TimeoutTimerCallback, LCtx);
  Result := FPoller.AsyncWrite(AFd, ABuf, ALen, AOffset, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    FTimers.Cancel(LCtx^.TimerHandle);
    Dispose(LCtx);
  end;
end;

function TAsyncLoop.AsyncRecvTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if ADeadline.IsInfinite then
    Exit(AsyncRecv(AFd, ABuf, ALen, AFlags, ACallback, AContext));
  New(LCtx);
  LCtx^.Loop := @Self;
  LCtx^.UserCallback := ACallback;
  LCtx^.UserContext := AContext;
  LCtx^.IoCompleted := False;
  LCtx^.TimerFired := False;
  LCtx^.TimerHandle := FTimers.Schedule(ADeadline, @TimeoutTimerCallback, LCtx);
  Result := FPoller.AsyncRecv(AFd, ABuf, ALen, AFlags, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    FTimers.Cancel(LCtx^.TimerHandle);
    Dispose(LCtx);
  end;
end;

function TAsyncLoop.AsyncSendTimeout(AFd: PtrInt; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer): Boolean;
var LCtx: PTimeoutCtx;
begin
  if ADeadline.IsInfinite then
    Exit(AsyncSend(AFd, ABuf, ALen, AFlags, ACallback, AContext));
  New(LCtx);
  LCtx^.Loop := @Self;
  LCtx^.UserCallback := ACallback;
  LCtx^.UserContext := AContext;
  LCtx^.IoCompleted := False;
  LCtx^.TimerFired := False;
  LCtx^.TimerHandle := FTimers.Schedule(ADeadline, @TimeoutTimerCallback, LCtx);
  Result := FPoller.AsyncSend(AFd, ABuf, ALen, AFlags, @TimeoutIoCallback, LCtx);
  if not Result then
  begin
    FTimers.Cancel(LCtx^.TimerHandle);
    Dispose(LCtx);
  end;
end;

end.
