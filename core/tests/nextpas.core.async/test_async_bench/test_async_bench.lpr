program test_async_bench;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.time.cpu,
  nextpas.core.platform.thread,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.async.mutex,
  nextpas.core.async.semaphore,
  nextpas.core.async.channel;

var
  T: TTestSuite;

{ === Benchmark helpers === }

procedure BenchNopCallback(AContext: Pointer);
begin
  { intentionally empty — measures Post/Poll overhead only }
end;

function BenchPostThroughput: Double;
var
  LLoop: TAsyncLoop;
  LStart, LEnd: TInstant;
  LI, LCount: Int32;
  LNs: Int64;
begin
  LCount := 100000;
  LLoop := TAsyncLoop.Create(128);
  try
    LStart := TInstant.Now;
    for LI := 1 to LCount do
      LLoop.Post(@BenchNopCallback, nil);
    { Drain all pending }
    for LI := 1 to LCount do
      LLoop.Poll;
    LEnd := TInstant.Now;
    LNs := LEnd.DurationSince(LStart).AsNanoseconds;
    if LNs > 0 then
      Result := LCount / (LNs / 1e9)
    else
      Result := 0;
  finally
    LLoop.Free;
  end;
end;

function BenchTimerSchedule: Double;
var
  LLoop: TAsyncLoop;
  LStart, LEnd: TInstant;
  LI, LCount: Int32;
  LNs: Int64;
begin
  LCount := 10000;
  LLoop := TAsyncLoop.Create(128);
  try
    LStart := TInstant.Now;
    for LI := 1 to LCount do
      LLoop.Schedule(TDuration.FromMilliseconds(1000 + LI), @BenchNopCallback, nil);
    LEnd := TInstant.Now;
    LNs := LEnd.DurationSince(LStart).AsNanoseconds;
    if LNs > 0 then
      Result := LCount / (LNs / 1e9)
    else
      Result := 0;
  finally
    LLoop.Free;
  end;
end;

function BenchMutexLockUnlock: Double;
var
  LLoop: TAsyncLoop;
  LMutex: IAsyncMutex;
  LStart, LEnd: TInstant;
  LI, LCount: Int32;
  LNs: Int64;
begin
  LCount := 100000;
  LLoop := TAsyncLoop.Create(32);
  try
    LMutex := CreateAsyncMutex(LLoop);
    LStart := TInstant.Now;
    for LI := 1 to LCount do
    begin
      LMutex.TryLock;
      LMutex.Unlock;
    end;
    LEnd := TInstant.Now;
    LNs := LEnd.DurationSince(LStart).AsNanoseconds;
    if LNs > 0 then
      Result := LCount / (LNs / 1e9)
    else
      Result := 0;
    LMutex := nil;
  finally
    LLoop.Free;
  end;
end;

function BenchChannelSendReceive: Double;
var
  LLoop: TAsyncLoop;
  LCh: IAsyncChannel;
  LStart, LEnd: TInstant;
  LI, LCount: Int32;
  LVal, LOut: UInt32;
  LReceived: UInt32;
  LNs: Int64;
begin
  LCount := 100000;
  LLoop := TAsyncLoop.Create(32);
  try
    LCh := CreateAsyncChannel(LLoop);
    LStart := TInstant.Now;
    for LI := 1 to LCount do
    begin
      LVal := LI;
      LCh.Send(LVal, SizeOf(LVal));
      LOut := 0;
      LCh.TryReceive(LOut, SizeOf(LOut), LReceived);
    end;
    LEnd := TInstant.Now;
    LNs := LEnd.DurationSince(LStart).AsNanoseconds;
    if LNs > 0 then
      Result := LCount / (LNs / 1e9)
    else
      Result := 0;
    LCh := nil;
  finally
    LLoop.Free;
  end;
end;

{ === Tests === }

procedure TestPostThroughput;
var
  LOpsPerSec: Double;
begin
  LOpsPerSec := BenchPostThroughput;
  WriteLn('metric=post_ops_per_s value=', FormatFloat('0.0', LOpsPerSec));
  Check(LOpsPerSec > 0, 'post throughput: ' + FormatFloat('0.0', LOpsPerSec) + ' ops/sec');
end;

procedure TestTimerSchedule;
var
  LOpsPerSec: Double;
begin
  LOpsPerSec := BenchTimerSchedule;
  WriteLn('metric=timer_schedule_ops_per_s value=', FormatFloat('0.0', LOpsPerSec));
  Check(LOpsPerSec > 0, 'timer schedule: ' + FormatFloat('0.0', LOpsPerSec) + ' ops/sec');
end;

procedure TestMutexLockUnlock;
var
  LOpsPerSec: Double;
begin
  LOpsPerSec := BenchMutexLockUnlock;
  WriteLn('metric=mutex_ops_per_s value=', FormatFloat('0.0', LOpsPerSec));
  Check(LOpsPerSec > 0, 'mutex lock/unlock: ' + FormatFloat('0.0', LOpsPerSec) + ' ops/sec');
end;

procedure TestChannelSendReceive;
var
  LOpsPerSec: Double;
begin
  LOpsPerSec := BenchChannelSendReceive;
  WriteLn('metric=channel_ops_per_s value=', FormatFloat('0.0', LOpsPerSec));
  Check(LOpsPerSec > 0, 'channel send/receive: ' + FormatFloat('0.0', LOpsPerSec) + ' ops/sec');
end;

begin
  T := TTestSuite.Create('nextpas.core.async.bench');

  T.Test('PostThroughput', @TestPostThroughput);
  T.Test('TimerSchedule', @TestTimerSchedule);
  T.Test('MutexLockUnlock', @TestMutexLockUnlock);
  T.Test('ChannelSendReceive', @TestChannelSendReceive);

  if not T.Run then Halt(1);
end.
