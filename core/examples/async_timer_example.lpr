program async_timer_example;

{$I nextpas.core.settings.inc}

{ Demonstrates:
  1. Schedule multiple timers
  2. Cancel a timer
  3. AsyncSleep
  4. Post from callback
  5. Stop after all work done }

uses
  SysUtils,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.async.base,
  nextpas.core.async.loop;

var
  GLoop: TAsyncLoop;
  GWorkRemaining: Int32 = 0;
  LCancelHandle: TAsyncTimerHandle;

procedure CheckDone(AContext: Pointer);
begin
  Dec(GWorkRemaining);
  if GWorkRemaining <= 0 then
  begin
    WriteLn('[done] All work completed, stopping loop.');
    GLoop.Stop;
  end;
end;

{ Demo 1: Multiple timers firing in order }

procedure OnTimer50(AContext: Pointer);
begin
  WriteLn('[timer] 50ms timer fired (first)');
  CheckDone(nil);
end;

procedure OnTimer100(AContext: Pointer);
begin
  WriteLn('[timer] 100ms timer fired (second)');
  CheckDone(nil);
end;

procedure OnTimer150(AContext: Pointer);
begin
  WriteLn('[timer] 150ms timer fired (third)');
  CheckDone(nil);
end;

{ Demo 3: AsyncSleep callback }

procedure OnSleepDone(AContext: Pointer);
begin
  WriteLn('[sleep] AsyncSleep 200ms completed');
  CheckDone(nil);
end;

{ Demo 4: Post from callback }

procedure PostedWork(AContext: Pointer);
begin
  WriteLn('[post]  Posted callback executed on loop thread');
  CheckDone(nil);
end;

procedure OnTimer80(AContext: Pointer);
begin
  WriteLn('[timer] 80ms timer fired -> posting callback');
  GLoop.Post(@PostedWork, nil);
end;

begin
  WriteLn('=== nextpas.core.async Timer Example ===');
  WriteLn;

  GLoop := TAsyncLoop.Create;
  if not GLoop.IsValid then
  begin
    WriteLn('ERROR: Failed to create async loop');
    Halt(1);
  end;

  { We expect 5 completions: 3 timers + 1 sleep + 1 posted callback }
  GWorkRemaining := 5;

  { Demo 1: Schedule multiple timers }
  WriteLn('[setup] Scheduling 50ms, 100ms, 150ms timers...');
  GLoop.Schedule(TDuration.FromMilliseconds(50), @OnTimer50, nil);
  GLoop.Schedule(TDuration.FromMilliseconds(100), @OnTimer100, nil);
  GLoop.Schedule(TDuration.FromMilliseconds(150), @OnTimer150, nil);

  { Demo 2: Schedule and cancel a timer }
  WriteLn('[setup] Scheduling 75ms timer (will be cancelled)...');
  LCancelHandle := GLoop.Schedule(TDuration.FromMilliseconds(75), @OnTimer50, nil);
  if GLoop.CancelTimer(LCancelHandle) then
    WriteLn('[cancel] 75ms timer cancelled successfully')
  else
    WriteLn('[cancel] ERROR: cancel failed');

  { Demo 3: AsyncSleep }
  WriteLn('[setup] AsyncSleep 200ms...');
  GLoop.AsyncSleep(TDuration.FromMilliseconds(200), @OnSleepDone, nil);

  { Demo 4: Post from a timer callback (80ms timer posts work) }
  WriteLn('[setup] Scheduling 80ms timer that will Post a callback...');
  GLoop.Schedule(TDuration.FromMilliseconds(80), @OnTimer80, nil);

  WriteLn;
  WriteLn('[run]   Entering event loop...');
  WriteLn;

  { Demo 5: Run until all work is done (Stop called from CheckDone) }
  GLoop.Run;

  GLoop.Close;
  WriteLn;
  WriteLn('=== Example complete ===');
end.
