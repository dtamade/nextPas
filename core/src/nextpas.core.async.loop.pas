unit nextpas.core.async.loop;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base, nextpas.core.time.deadline,
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
    FTimers: TTimerHeap;
    FRunning: Int32;
    FWakeFd: Int32;
    FPendingQueue: array of TAsyncPendingItem;
    FPendingCount: UInt32;
    FPendingCap: UInt32;
    FPendingLock: TPlatformMutex;
    procedure DrainPending;
    procedure DrainWakeFd;
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
    function AsyncRead(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWrite(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncAccept(AFd: Int32; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecv(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncSend(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;

    { I/O with deadline }
    function AsyncReadTimeout(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWriteTimeout(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecvTimeout(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      const ADeadline: TDeadline; ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncSendTimeout(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
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
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.linux.base,
  nextpas.core.platform.linux.ffi,
  nextpas.core.platform.sync;

const
  ETIMEDOUT_LINUX = 110;
  PENDING_INITIAL_CAP = 32;

type
  PTimeoutCtx = ^TTimeoutCtx;
  TTimeoutCtx = record
    Loop: Pointer;
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
    TAsyncLoop(LCtx^.Loop^).FTimers.Cancel(LCtx^.TimerHandle);
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
  Result.FTimers := TTimerHeap.Create;
  Result.FRunning := 0;
  Result.FWakeFd := eventfd(0, EFD_NONBLOCK or EFD_CLOEXEC);
  Result.FPendingCount := 0;
  Result.FPendingCap := PENDING_INITIAL_CAP;
  SetLength(Result.FPendingQueue, PENDING_INITIAL_CAP);
  platform_mutex_init(Result.FPendingLock, PLATFORM_MUTEX_NORMAL);
end;

procedure TAsyncLoop.Close;
begin
  platform_mutex_destroy(FPendingLock);
  if FWakeFd >= 0 then
  begin
    nextpas.core.platform.posix.ffi.close(FWakeFd);
    FWakeFd := -1;
  end;
  FPoller.Close;
end;

function TAsyncLoop.IsValid: Boolean;
begin
  if not FPoller.IsValid then
    Exit(False);
  Result := FWakeFd >= 0;
end;

{ Cross-thread wake }

procedure TAsyncLoop.Wake;
var
  LVal: UInt64;
begin
  LVal := 1;
  nextpas.core.platform.posix.ffi.write(FWakeFd, @LVal, 8);
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

procedure TAsyncLoop.DrainWakeFd;
var
  LVal: UInt64;
begin
  { Read 8 bytes to drain the eventfd counter }
  nextpas.core.platform.posix.ffi.read(FWakeFd, @LVal, 8);
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
  Result := FTimers.ScheduleAfter(ADelay, ACallback, AContext);
end;

function TAsyncLoop.ScheduleAt(const ADeadline: TDeadline; ACallback: TAsyncCallback;
  AContext: Pointer): TAsyncTimerHandle;
begin
  Result := FTimers.Schedule(ADeadline, ACallback, AContext);
end;

function TAsyncLoop.CancelTimer(const AHandle: TAsyncTimerHandle): Boolean;
begin
  Result := FTimers.Cancel(AHandle);
end;

function TAsyncLoop.AsyncRead(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := FPoller.AsyncRead(AFd, ABuf, ALen, AOffset, ACallback, AContext);
end;

function TAsyncLoop.AsyncWrite(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := FPoller.AsyncWrite(AFd, ABuf, ALen, AOffset, ACallback, AContext);
end;

function TAsyncLoop.AsyncAccept(AFd: Int32; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := FPoller.AsyncAccept(AFd, AAddr, AAddrLen, AFlags, ACallback, AContext);
end;

function TAsyncLoop.AsyncRecv(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := FPoller.AsyncRecv(AFd, ABuf, ALen, AFlags, ACallback, AContext);
end;

function TAsyncLoop.AsyncSend(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := FPoller.AsyncSend(AFd, ABuf, ALen, AFlags, ACallback, AContext);
end;

function TAsyncLoop.Poll: Int32;
var
  LFired: UInt32;
  LIo: Int32;
begin
  FPoller.Flush;
  LIo := FPoller.Poll;
  LFired := FTimers.FireExpired;
  { Drain wake fd and pending queue }
  DrainWakeFd;
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
  LPfd: pollfd;
begin
  FRunning := 1;
  while FRunning <> 0 do
  begin
    { Drain wake fd and process pending callbacks }
    DrainWakeFd;
    DrainPending;
    { Check if stopped from pending callback }
    if FRunning = 0 then
      Break;
    { Fire expired timers }
    LFired := FTimers.FireExpired;
    { Check if stopped from callback }
    if FRunning = 0 then
      Break;
    { Poll I/O non-blocking }
    FPoller.Flush;
    LIo := FPoller.Poll;
    { If we did work, loop immediately }
    if (LFired > 0) or (LIo > 0) then
      Continue;
    { Nothing happened — sleep on eventfd until woken or next timer }
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
    { Use poll() on eventfd so Wake/Post can interrupt the sleep }
    LPfd.fd := FWakeFd;
    LPfd.events := cshort(POLLIN);
    LPfd.revents := 0;
    nextpas.core.platform.posix.ffi.poll(@LPfd, 1, cint(LTimeoutMs));
  end;
end;

procedure TAsyncLoop.RunOnce;
var
  LFired: UInt32;
  LIo: Int32;
  LNext: TDeadline;
  LRemaining: TDuration;
  LTimeoutMs: Int32;
  LPfd: pollfd;
begin
  { Drain pending first }
  DrainWakeFd;
  DrainPending;
  { Try non-blocking first }
  FPoller.Flush;
  LIo := FPoller.Poll;
  LFired := FTimers.FireExpired;
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
    LPfd.fd := FWakeFd;
    LPfd.events := cshort(POLLIN);
    LPfd.revents := 0;
    nextpas.core.platform.posix.ffi.poll(@LPfd, 1, cint(LTimeoutMs));
  end;
  { Drain and fire after sleep }
  DrainWakeFd;
  DrainPending;
  FPoller.Flush;
  FPoller.Poll;
  FTimers.FireExpired;
end;

procedure TAsyncLoop.Stop;
begin
  FRunning := 0;
end;

function TAsyncLoop.AsyncSleep(const ADelay: TDuration; ACallback: TAsyncCallback;
  AContext: Pointer): TAsyncTimerHandle;
begin
  Result := FTimers.ScheduleAfter(ADelay, ACallback, AContext);
end;

function TAsyncLoop.AsyncReadTimeout(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
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

function TAsyncLoop.AsyncWriteTimeout(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
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

function TAsyncLoop.AsyncRecvTimeout(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
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

function TAsyncLoop.AsyncSendTimeout(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
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
