unit nextpas.core.async.loop;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base, nextpas.core.time.deadline,
  nextpas.core.io.poller,
  nextpas.core.async.base, nextpas.core.async.timer;

type
  TAsyncLoop = record
  private
    FPoller: TPoller;
    FTimers: TTimerHeap;
    FRunning: Int32;
  public
    class function Create(AQueueDepth: UInt32 = 64): TAsyncLoop; static;
    procedure Close;
    function IsValid: Boolean; inline;

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

    { Event loop }
    function Poll: Int32;
    procedure Run;
    procedure RunOnce;
    procedure Stop;
  end;

implementation

uses
  nextpas.core.time.cpu;

{ TAsyncLoop }

class function TAsyncLoop.Create(AQueueDepth: UInt32): TAsyncLoop;
begin
  Result := Default(TAsyncLoop);
  Result.FPoller := TPoller.Create(AQueueDepth);
  Result.FTimers := TTimerHeap.Create;
  Result.FRunning := 0;
end;

procedure TAsyncLoop.Close;
begin
  FPoller.Close;
end;

function TAsyncLoop.IsValid: Boolean;
begin
  Result := FPoller.IsValid;
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
  Result := LIo + Int32(LFired);
end;

procedure TAsyncLoop.Run;
var
  LFired: UInt32;
  LIo: Int32;
  LNext: TDeadline;
  LRemaining: TDuration;
  LSleepNs: UInt64;
begin
  FRunning := 1;
  while FRunning <> 0 do
  begin
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
    { Nothing happened — sleep until next timer or short spin }
    LNext := FTimers.NextDeadline;
    LRemaining := LNext.Remaining;
    if LRemaining.AsNanoseconds <= 0 then
      Continue;
    { Cap sleep at 10ms to stay responsive }
    LSleepNs := UInt64(LRemaining.AsNanoseconds);
    if LSleepNs > 10000000 then
      LSleepNs := 10000000;
    NanoSleep(LSleepNs);
  end;
end;

procedure TAsyncLoop.RunOnce;
var
  LFired: UInt32;
  LIo: Int32;
  LNext: TDeadline;
  LRemaining: TDuration;
  LSleepNs: UInt64;
begin
  { Try non-blocking first }
  FPoller.Flush;
  LIo := FPoller.Poll;
  LFired := FTimers.FireExpired;
  if (LFired > 0) or (LIo > 0) then
    Exit;
  { Block until next timer }
  LNext := FTimers.NextDeadline;
  LRemaining := LNext.Remaining;
  if LRemaining.AsNanoseconds > 0 then
  begin
    LSleepNs := UInt64(LRemaining.AsNanoseconds);
    if LSleepNs > 10000000 then
      LSleepNs := 10000000;
    NanoSleep(LSleepNs);
  end;
  { Fire after sleep }
  FPoller.Flush;
  FPoller.Poll;
  FTimers.FireExpired;
end;

procedure TAsyncLoop.Stop;
begin
  FRunning := 0;
end;

end.
