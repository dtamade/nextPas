program test_lockfree;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree,
  nextpas.core.lockfree.wait,
  nextpas.core.platform.thread;

type
  TIntSpsc = specialize TSpscQueue<Integer>;
  TIntMpmc = specialize TMpmcQueue<Integer>;
  TIntStack = specialize TLockFreeStack<Integer>;
  TIntMpsc = specialize TMpscQueue<Integer>;
  TIntDeque = specialize TWorkStealingDeque<Integer>;

const
  CloseWakePendingProbeNs = 50000000;
  QueuePublishWakeDelayNs = 20000000;
  QueuePublishWakeTimeoutNs = Int64(1000000000);
  QueuePublishWakeBudgetMs = 500;
  WaitHelperStaleEpochTimeoutNs = Int64(5000000000);
  WaitHelperImmediateReturnBudgetMs = 100;

var
  T: TTestRunner;

function StartThread(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer; const AMessage: string): Int32;
begin
  Result := platform_thread_create(AHandle, AProc, AArg);
  CheckEqual(Int64(0), Int64(Result), AMessage + ': platform_thread_create must succeed');
end;

procedure JoinThread(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer; const AMessage: string);
var
  LResult: Int32;
begin
  LResult := platform_thread_join(AHandle, ARetVal);
  CheckEqual(Int64(0), Int64(LResult), AMessage + ': platform_thread_join must succeed');
end;

procedure JoinStartedThread(const AHandle: TPlatformThreadHandle; var AStarted: Boolean; const AMessage: string);
var
  LRetVal: Pointer;
begin
  if not AStarted then
    Exit;
  JoinThread(AHandle, LRetVal, AMessage);
  AStarted := False;
end;

procedure JoinStartedThreads(const AHandles: array of TPlatformThreadHandle; var AStartedCount: Integer; const AMessage: string);
var
  LI: Integer;
  LRetVal: Pointer;
begin
  for LI := 0 to AStartedCount - 1 do
    JoinThread(AHandles[LI], LRetVal, AMessage);
  AStartedCount := 0;
end;

function ReadUtf8TextFile(const APath: string): string;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(Result[1], LStream.Size);
  finally
    LStream.Free;
  end;
end;

procedure CheckContains(const AText, AExpected, AMessage: string);
begin
  Check(Pos(AExpected, AText) > 0, AMessage + ': missing "' + AExpected + '"');
end;

procedure CheckNotContains(const AText, AUnexpected, AMessage: string);
begin
  Check(Pos(AUnexpected, AText) = 0, AMessage + ': unexpected "' + AUnexpected + '"');
end;

procedure CheckBefore(const AText, AEarlier, ALater, AMessage: string);
var
  LEarlierPos: SizeInt;
  LLaterPos: SizeInt;
begin
  LEarlierPos := Pos(AEarlier, AText);
  LLaterPos := Pos(ALater, AText);
  Check(LEarlierPos > 0, AMessage + ': missing earlier marker "' + AEarlier + '"');
  Check(LLaterPos > 0, AMessage + ': missing later marker "' + ALater + '"');
  Check(LEarlierPos < LLaterPos, AMessage);
end;

function CountOccurrences(const AText, ANeedle: string): SizeInt;
var
  LOffset: SizeInt;
  LPos: SizeInt;
begin
  Result := 0;
  if ANeedle = '' then
    Exit;
  LOffset := 1;
  while LOffset <= Length(AText) do
  begin
    LPos := Pos(ANeedle, Copy(AText, LOffset, Length(AText) - LOffset + 1));
    if LPos = 0 then
      Break;
    Inc(Result);
    Inc(LOffset, LPos + Length(ANeedle) - 1);
  end;
end;

function ExtractSection(const AText, AStartMarker, AEndMarker, AMessage: string): string;
var
  LStart: SizeInt;
  LEnd: SizeInt;
  LRest: string;
begin
  LStart := Pos(AStartMarker, AText);
  Check(LStart > 0, AMessage + ': missing start marker "' + AStartMarker + '"');
  LRest := Copy(AText, LStart, Length(AText) - LStart + 1);
  LEnd := Pos(AEndMarker, LRest);
  Check(LEnd > 0, AMessage + ': missing end marker "' + AEndMarker + '"');
  Result := Copy(LRest, 1, LEnd - 1);
end;

{ SPSC tests }

procedure TestSpscBasic;
var
  LQ: TIntSpsc;
  LV: Integer;
begin
  LQ := TIntSpsc.Create(4);
  Check(LQ.TryEnqueue(10), 'enq 1');
  Check(LQ.TryEnqueue(20), 'enq 2');
  Check(LQ.TryEnqueue(30), 'enq 3');
  Check(LQ.TryEnqueue(40), 'enq 4');
  Check(not LQ.TryEnqueue(50), 'full');
  Check(LQ.TryDequeue(LV), 'deq 1');
  CheckEqual(Int64(10), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 2');
  CheckEqual(Int64(20), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 3');
  CheckEqual(Int64(30), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 4');
  CheckEqual(Int64(40), Int64(LV));
  Check(not LQ.TryDequeue(LV), 'empty');
  LQ.Free;
end;

procedure TestSpscClose;
var
  LQ: TIntSpsc;
  LV: Integer;
begin
  LQ := TIntSpsc.Create(4);
  LQ.TryEnqueue(1);
  LQ.Close;
  Check(LQ.IsClosed, 'closed');
  Check(not LQ.TryEnqueue(2), 'TryEnqueue after close rejected');
  Check(not LQ.EnqueueWait(2), 'EnqueueWait after close rejected');
  Check(not LQ.EnqueueTimeout(2, 1000000), 'EnqueueTimeout after close rejected');
  Check(LQ.TryDequeue(LV), 'drain after close');
  CheckEqual(Int64(1), Int64(LV));
  Check(not LQ.DequeueWait(LV), 'dequeue wait returns false on closed');
  LQ.Free;
end;

var
  GSpscCloseWakeQ: TIntSpsc;
  GSpscCloseProducerStarted: Int32;
  GSpscCloseProducerResult: Int32;
  GSpscCloseConsumerStarted: Int32;
  GSpscCloseConsumerResult: Int32;

function SpscCloseWakeProducer(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  AtomicStore32(GSpscCloseProducerStarted, 1, moRelease);
  if GSpscCloseWakeQ.EnqueueTimeout(2, 5000000000) then
    AtomicStore32(GSpscCloseProducerResult, 1, moRelease)
  else
    AtomicStore32(GSpscCloseProducerResult, 0, moRelease);
end;

function SpscCloseWaitProducer(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  AtomicStore32(GSpscCloseProducerStarted, 1, moRelease);
  if GSpscCloseWakeQ.EnqueueWait(2) then
    AtomicStore32(GSpscCloseProducerResult, 1, moRelease)
  else
    AtomicStore32(GSpscCloseProducerResult, 0, moRelease);
end;

function SpscCloseWakeConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  AtomicStore32(GSpscCloseConsumerStarted, 1, moRelease);
  if GSpscCloseWakeQ.DequeueTimeout(LV, 5000000000) then
    AtomicStore32(GSpscCloseConsumerResult, 1, moRelease)
  else
    AtomicStore32(GSpscCloseConsumerResult, 0, moRelease);
end;

function SpscCloseWaitConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  AtomicStore32(GSpscCloseConsumerStarted, 1, moRelease);
  if GSpscCloseWakeQ.DequeueWait(LV) then
    AtomicStore32(GSpscCloseConsumerResult, 1, moRelease)
  else
    AtomicStore32(GSpscCloseConsumerResult, 0, moRelease);
end;

procedure TestSpscCloseWakeTimeouts;
var
  LQ: TIntSpsc;
  LV: Integer;
  LBlockedProducer: TPlatformThreadHandle;
  LBlockedConsumer: TPlatformThreadHandle;
  LElapsedMs: QWord;
  LSpin: Integer;
  LProducerStarted: Boolean;
  LConsumerStarted: Boolean;
begin
  LQ := TIntSpsc.Create(1);
  LProducerStarted := False;
  try
    Check(LQ.TryEnqueue(1), 'fill queue before blocked producer close');
    GSpscCloseWakeQ := LQ;
    AtomicStore32(GSpscCloseProducerStarted, 0, moRelease);
    AtomicStore32(GSpscCloseProducerResult, -1, moRelease);
    StartThread(LBlockedProducer, @SpscCloseWakeProducer, nil, 'SPSC close timeout producer thread');
    LProducerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GSpscCloseProducerStarted, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GSpscCloseProducerStarted, moAcquire)),
      'blocked EnqueueTimeout producer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(AtomicLoad32(GSpscCloseProducerResult, moAcquire)),
      'blocked EnqueueTimeout should still be pending before close');
    LElapsedMs := GetTickCount64;
    LQ.Close;
    JoinStartedThread(LBlockedProducer, LProducerStarted, 'SPSC close timeout producer thread');
    LElapsedMs := GetTickCount64 - LElapsedMs;
    CheckEqual(Int64(0), Int64(AtomicLoad32(GSpscCloseProducerResult, moAcquire)),
      'blocked EnqueueTimeout woken by close');
    Check(LElapsedMs < 1000, 'blocked EnqueueTimeout should return promptly after close');
    Check(LQ.TryDequeue(LV), 'drain queued item after blocked producer close');
    CheckEqual(Int64(1), Int64(LV));
    Check(not LQ.TryDequeue(LV), 'blocked producer wake must not publish a new item after close');
  finally
    if LProducerStarted then
    begin
      LQ.Close;
      JoinStartedThread(LBlockedProducer, LProducerStarted, 'SPSC close timeout producer thread');
    end;
    LQ.Free;
  end;

  LQ := TIntSpsc.Create(1);
  LConsumerStarted := False;
  try
    GSpscCloseWakeQ := LQ;
    AtomicStore32(GSpscCloseConsumerStarted, 0, moRelease);
    AtomicStore32(GSpscCloseConsumerResult, -1, moRelease);
    StartThread(LBlockedConsumer, @SpscCloseWakeConsumer, nil, 'SPSC close timeout consumer thread');
    LConsumerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GSpscCloseConsumerStarted, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GSpscCloseConsumerStarted, moAcquire)),
      'blocked DequeueTimeout consumer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(AtomicLoad32(GSpscCloseConsumerResult, moAcquire)),
      'blocked DequeueTimeout should still be pending before close');
    LElapsedMs := GetTickCount64;
    LQ.Close;
    JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'SPSC close timeout consumer thread');
    LElapsedMs := GetTickCount64 - LElapsedMs;
    CheckEqual(Int64(0), Int64(AtomicLoad32(GSpscCloseConsumerResult, moAcquire)),
      'blocked DequeueTimeout woken by close');
    Check(LElapsedMs < 1000, 'blocked DequeueTimeout should return promptly after close');
    Check(not LQ.TryDequeue(LV), 'blocked consumer wake must leave the closed empty queue empty');
  finally
    if LConsumerStarted then
    begin
      LQ.Close;
      JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'SPSC close timeout consumer thread');
    end;
    LQ.Free;
  end;
end;

procedure TestSpscCloseWakeWaits;
var
  LQ: TIntSpsc;
  LV: Integer;
  LBlockedProducer: TPlatformThreadHandle;
  LBlockedConsumer: TPlatformThreadHandle;
  LElapsedMs: QWord;
  LSpin: Integer;
  LProducerStarted: Boolean;
  LConsumerStarted: Boolean;
begin
  LQ := TIntSpsc.Create(1);
  LProducerStarted := False;
  try
    Check(LQ.TryEnqueue(1), 'fill queue before blocked EnqueueWait close');
    GSpscCloseWakeQ := LQ;
    AtomicStore32(GSpscCloseProducerStarted, 0, moRelease);
    AtomicStore32(GSpscCloseProducerResult, -1, moRelease);
    StartThread(LBlockedProducer, @SpscCloseWaitProducer, nil, 'SPSC close wait producer thread');
    LProducerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GSpscCloseProducerStarted, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GSpscCloseProducerStarted, moAcquire)),
      'blocked EnqueueWait producer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(AtomicLoad32(GSpscCloseProducerResult, moAcquire)),
      'blocked EnqueueWait should still be pending before close');
    LElapsedMs := GetTickCount64;
    LQ.Close;
    JoinStartedThread(LBlockedProducer, LProducerStarted, 'SPSC close wait producer thread');
    LElapsedMs := GetTickCount64 - LElapsedMs;
    CheckEqual(Int64(0), Int64(AtomicLoad32(GSpscCloseProducerResult, moAcquire)),
      'blocked EnqueueWait woken by close');
    Check(LElapsedMs < 1000, 'blocked EnqueueWait should return promptly after close');
    Check(LQ.TryDequeue(LV), 'drain queued item after blocked EnqueueWait close');
    CheckEqual(Int64(1), Int64(LV));
    Check(not LQ.TryDequeue(LV), 'blocked EnqueueWait wake must not publish a new item after close');
  finally
    if LProducerStarted then
    begin
      LQ.Close;
      JoinStartedThread(LBlockedProducer, LProducerStarted, 'SPSC close wait producer thread');
    end;
    LQ.Free;
  end;

  LQ := TIntSpsc.Create(1);
  LConsumerStarted := False;
  try
    GSpscCloseWakeQ := LQ;
    AtomicStore32(GSpscCloseConsumerStarted, 0, moRelease);
    AtomicStore32(GSpscCloseConsumerResult, -1, moRelease);
    StartThread(LBlockedConsumer, @SpscCloseWaitConsumer, nil, 'SPSC close wait consumer thread');
    LConsumerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GSpscCloseConsumerStarted, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GSpscCloseConsumerStarted, moAcquire)),
      'blocked DequeueWait consumer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(AtomicLoad32(GSpscCloseConsumerResult, moAcquire)),
      'blocked DequeueWait should still be pending before close');
    LElapsedMs := GetTickCount64;
    LQ.Close;
    JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'SPSC close wait consumer thread');
    LElapsedMs := GetTickCount64 - LElapsedMs;
    CheckEqual(Int64(0), Int64(AtomicLoad32(GSpscCloseConsumerResult, moAcquire)),
      'blocked DequeueWait woken by close');
    Check(LElapsedMs < 1000, 'blocked DequeueWait should return promptly after close');
    Check(not LQ.TryDequeue(LV), 'blocked DequeueWait wake must leave the closed empty queue empty');
  finally
    if LConsumerStarted then
    begin
      LQ.Close;
      JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'SPSC close wait consumer thread');
    end;
    LQ.Free;
  end;
end;

procedure TestSpscApproxCount;
var
  LQ: TIntSpsc;
  LV: Integer;
begin
  LQ := TIntSpsc.Create(8);
  CheckEqual(Int64(0), Int64(LQ.ApproxCount));
  LQ.TryEnqueue(1);
  LQ.TryEnqueue(2);
  LQ.TryEnqueue(3);
  CheckEqual(Int64(3), Int64(LQ.ApproxCount));
  LQ.TryDequeue(LV);
  CheckEqual(Int64(2), Int64(LQ.ApproxCount));
  LQ.Free;
end;

var
  GSpscQ: TIntSpsc;

function SpscProducer(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
begin
  Result := nil;
  for LI := 1 to 1000 do
    GSpscQ.EnqueueWait(LI);
end;

procedure TestSpscBlocking;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LV, LSum: Integer;
begin
  GSpscQ := TIntSpsc.Create(16);
  LSum := 0;
  StartThread(LHandle, @SpscProducer, nil, 'SPSC producer thread');
  while True do
  begin
    if not GSpscQ.DequeueWait(LV) then
      Break;
    Inc(LSum, LV);
    if LSum >= 500500 then
      Break;
  end;
  JoinThread(LHandle, LRetVal, 'SPSC producer thread');
  CheckEqual(Int64(500500), Int64(LSum), '1+2+...+1000');
  GSpscQ.Free;
end;

procedure TestSpscTimeout;
var
  LQ: TIntSpsc;
  LV: Integer;
begin
  LQ := TIntSpsc.Create(4);
  Check(not LQ.DequeueTimeout(LV, 1000000), 'timeout 1ms on empty');
  Check(LQ.EnqueueTimeout(42, 1000000), 'enqueue immediate');
  Check(LQ.DequeueTimeout(LV, 1000000), 'dequeue immediate');
  CheckEqual(Int64(42), Int64(LV));
  LQ.Free;
end;

var
  GSpscPublishWakeQ: TIntSpsc;
  GSpscPublishWakeConsumerStarted: Int32;
  GSpscPublishWakeConsumerResult: Int32;
  GSpscPublishWakeConsumerValue: Integer;
  GSpscSpaceWakeProducerStarted: Int32;
  GSpscSpaceWakeProducerObservedFull: Int32;
  GSpscSpaceWakeProducerResult: Int32;

function SpscPublishWakeConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  AtomicStore32(GSpscPublishWakeConsumerStarted, 1, moRelease);
  if GSpscPublishWakeQ.DequeueTimeout(LV, QueuePublishWakeTimeoutNs) then
  begin
    GSpscPublishWakeConsumerValue := LV;
    AtomicStore32(GSpscPublishWakeConsumerResult, 1, moRelease);
  end
  else
    AtomicStore32(GSpscPublishWakeConsumerResult, 0, moRelease);
end;

function SpscSpaceWakeProducer(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  AtomicStore32(GSpscSpaceWakeProducerStarted, 1, moRelease);
  if GSpscPublishWakeQ.TryEnqueue(99) then
  begin
    AtomicStore32(GSpscSpaceWakeProducerResult, 2, moRelease);
    Exit;
  end;
  AtomicStore32(GSpscSpaceWakeProducerObservedFull, 1, moRelease);
  if GSpscPublishWakeQ.EnqueueTimeout(42, QueuePublishWakeTimeoutNs) then
    AtomicStore32(GSpscSpaceWakeProducerResult, 1, moRelease)
  else
    AtomicStore32(GSpscSpaceWakeProducerResult, 0, moRelease);
end;

procedure TestSpscDequeueTimeoutWakesOnPublish;
var
  LQ: TIntSpsc;
  LConsumer: TPlatformThreadHandle;
  LRetVal: Pointer;
  LElapsedMs: QWord;
  LSpin: Integer;
  LThreadCreated: Boolean;
  LJoined: Boolean;
begin
  LQ := TIntSpsc.Create(4);
  LThreadCreated := False;
  LJoined := False;
  try
    GSpscPublishWakeQ := LQ;
    AtomicStore32(GSpscPublishWakeConsumerStarted, 0, moRelease);
    AtomicStore32(GSpscPublishWakeConsumerResult, -1, moRelease);
    GSpscPublishWakeConsumerValue := 0;
    StartThread(LConsumer, @SpscPublishWakeConsumer, nil, 'SPSC publish wake consumer thread');
    LThreadCreated := True;

    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GSpscPublishWakeConsumerStarted, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GSpscPublishWakeConsumerStarted, moAcquire)),
      'SPSC DequeueTimeout consumer thread must start before publish');
    platform_thread_sleep_ns(QueuePublishWakeDelayNs);
    CheckEqual(Int64(-1), Int64(AtomicLoad32(GSpscPublishWakeConsumerResult, moAcquire)),
      'SPSC DequeueTimeout consumer should still be pending before publish');

    LElapsedMs := GetTickCount64;
    Check(LQ.TryEnqueue(42), 'SPSC producer must publish the wake item');
    JoinThread(LConsumer, LRetVal, 'publish wake consumer thread');
    LJoined := True;
    LElapsedMs := GetTickCount64 - LElapsedMs;

    CheckEqual(Int64(1), Int64(AtomicLoad32(GSpscPublishWakeConsumerResult, moAcquire)),
      'SPSC DequeueTimeout must receive the producer-published item');
    CheckEqual(Int64(42), Int64(GSpscPublishWakeConsumerValue));
    Check(LElapsedMs < QueuePublishWakeBudgetMs,
      'SPSC DequeueTimeout consumer must wake on data publish before the full timeout');
  finally
    if LThreadCreated and (not LJoined) then
      JoinThread(LConsumer, LRetVal, 'publish wake consumer thread');
    GSpscPublishWakeQ := nil;
    LQ.Free;
  end;
end;

procedure TestSpscEnqueueTimeoutWakesOnSpace;
var
  LQ: TIntSpsc;
  LProducer: TPlatformThreadHandle;
  LRetVal: Pointer;
  LElapsedMs: QWord;
  LSpin: Integer;
  LV: Integer;
  LThreadCreated: Boolean;
  LJoined: Boolean;
begin
  LQ := TIntSpsc.Create(1);
  LThreadCreated := False;
  LJoined := False;
  try
    Check(LQ.TryEnqueue(1), 'SPSC queue must be full before space-wake producer starts');
    GSpscPublishWakeQ := LQ;
    AtomicStore32(GSpscSpaceWakeProducerStarted, 0, moRelease);
    AtomicStore32(GSpscSpaceWakeProducerObservedFull, 0, moRelease);
    AtomicStore32(GSpscSpaceWakeProducerResult, -1, moRelease);
    StartThread(LProducer, @SpscSpaceWakeProducer, nil, 'SPSC space wake producer thread');
    LThreadCreated := True;

    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GSpscSpaceWakeProducerStarted, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GSpscSpaceWakeProducerStarted, moAcquire)),
      'SPSC EnqueueTimeout producer thread must start before space release');
    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GSpscSpaceWakeProducerObservedFull, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GSpscSpaceWakeProducerObservedFull, moAcquire)),
      'SPSC EnqueueTimeout producer must observe the full queue before space release');
    platform_thread_sleep_ns(QueuePublishWakeDelayNs);
    CheckEqual(Int64(-1), Int64(AtomicLoad32(GSpscSpaceWakeProducerResult, moAcquire)),
      'SPSC EnqueueTimeout producer must not complete before space release');

    LElapsedMs := GetTickCount64;
    Check(LQ.TryDequeue(LV), 'SPSC consumer must release queue space');
    CheckEqual(Int64(1), Int64(LV));
    JoinThread(LProducer, LRetVal, 'space wake producer thread');
    LJoined := True;
    LElapsedMs := GetTickCount64 - LElapsedMs;

    CheckEqual(Int64(1), Int64(AtomicLoad32(GSpscSpaceWakeProducerResult, moAcquire)),
      'SPSC EnqueueTimeout must publish after space release');
    Check(LElapsedMs < QueuePublishWakeBudgetMs,
      'SPSC EnqueueTimeout producer must progress after space release before the full timeout');
    Check(LQ.TryDequeue(LV), 'SPSC space-woken producer item must be drainable');
    CheckEqual(Int64(42), Int64(LV));
    Check(not LQ.TryDequeue(LV), 'SPSC queue must be empty after draining the space-woken item');
  finally
    if LThreadCreated and (not LJoined) then
      JoinThread(LProducer, LRetVal, 'space wake producer thread');
    GSpscPublishWakeQ := nil;
    LQ.Free;
  end;
end;

{ MPMC tests }

procedure TestMpmcBasic;
var
  LQ: TIntMpmc;
  LV: Integer;
begin
  LQ := TIntMpmc.Create(4);
  Check(LQ.TryEnqueue(10), 'enq 1');
  Check(LQ.TryEnqueue(20), 'enq 2');
  Check(LQ.TryEnqueue(30), 'enq 3');
  Check(LQ.TryEnqueue(40), 'enq 4');
  Check(not LQ.TryEnqueue(50), 'full');
  Check(LQ.TryDequeue(LV), 'deq 1');
  CheckEqual(Int64(10), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 2');
  CheckEqual(Int64(20), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 3');
  CheckEqual(Int64(30), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 4');
  CheckEqual(Int64(40), Int64(LV));
  Check(not LQ.TryDequeue(LV), 'empty');
  LQ.Free;
end;

var
  GMpmcCloseWakeQ: TIntMpmc;
  GMpmcCloseWakeStarted: Int32;
  GMpmcCloseWakeResult: Int32;

function MpmcCloseWakeProducer(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  AtomicStore32(GMpmcCloseWakeStarted, 1, moRelease);
  if GMpmcCloseWakeQ.EnqueueTimeout(2, 5000000000) then
    AtomicStore32(GMpmcCloseWakeResult, 1, moRelease)
  else
    AtomicStore32(GMpmcCloseWakeResult, 0, moRelease);
end;

function MpmcCloseWaitProducer(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  AtomicStore32(GMpmcCloseWakeStarted, 1, moRelease);
  if GMpmcCloseWakeQ.EnqueueWait(2) then
    AtomicStore32(GMpmcCloseWakeResult, 1, moRelease)
  else
    AtomicStore32(GMpmcCloseWakeResult, 0, moRelease);
end;

function MpmcCloseWakeConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  AtomicStore32(GMpmcCloseWakeStarted, 1, moRelease);
  if GMpmcCloseWakeQ.DequeueTimeout(LV, 5000000000) then
    AtomicStore32(GMpmcCloseWakeResult, 1, moRelease)
  else
    AtomicStore32(GMpmcCloseWakeResult, 0, moRelease);
end;

function MpmcCloseWaitConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  AtomicStore32(GMpmcCloseWakeStarted, 1, moRelease);
  if GMpmcCloseWakeQ.DequeueWait(LV) then
    AtomicStore32(GMpmcCloseWakeResult, 1, moRelease)
  else
    AtomicStore32(GMpmcCloseWakeResult, 0, moRelease);
end;

var
  GMpmcPublishWakeQ: TIntMpmc;
  GMpmcPublishWakeConsumerStarted: Int32;
  GMpmcPublishWakeConsumerObservedEmpty: Int32;
  GMpmcPublishWakeConsumerResult: Int32;
  GMpmcPublishWakeConsumerValue: Integer;
  GMpmcSpaceWakeQ: TIntMpmc;
  GMpmcSpaceWakeProducerStarted: Int32;
  GMpmcSpaceWakeProducerObservedFull: Int32;
  GMpmcSpaceWakeProducerResult: Int32;

function MpmcPublishWakeConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  AtomicStore32(GMpmcPublishWakeConsumerStarted, 1, moRelease);
  if GMpmcPublishWakeQ.TryDequeue(LV) then
  begin
    GMpmcPublishWakeConsumerValue := LV;
    AtomicStore32(GMpmcPublishWakeConsumerResult, 2, moRelease);
    Exit;
  end;
  AtomicStore32(GMpmcPublishWakeConsumerObservedEmpty, 1, moRelease);
  if GMpmcPublishWakeQ.DequeueTimeout(LV, QueuePublishWakeTimeoutNs) then
  begin
    GMpmcPublishWakeConsumerValue := LV;
    AtomicStore32(GMpmcPublishWakeConsumerResult, 1, moRelease);
  end
  else
    AtomicStore32(GMpmcPublishWakeConsumerResult, 0, moRelease);
end;

function MpmcSpaceWakeProducer(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  AtomicStore32(GMpmcSpaceWakeProducerStarted, 1, moRelease);
  if GMpmcSpaceWakeQ.TryEnqueue(99) then
  begin
    AtomicStore32(GMpmcSpaceWakeProducerResult, 2, moRelease);
    Exit;
  end;
  AtomicStore32(GMpmcSpaceWakeProducerObservedFull, 1, moRelease);
  if GMpmcSpaceWakeQ.EnqueueTimeout(42, QueuePublishWakeTimeoutNs) then
    AtomicStore32(GMpmcSpaceWakeProducerResult, 1, moRelease)
  else
    AtomicStore32(GMpmcSpaceWakeProducerResult, 0, moRelease);
end;

procedure TestMpmcClose;
var
  LQ: TIntMpmc;
  LV: Integer;
  LBlockedProducer: TPlatformThreadHandle;
  LBlockedConsumer: TPlatformThreadHandle;
  LElapsedMs: QWord;
  LSpin: Integer;
  LProducerStarted: Boolean;
  LConsumerStarted: Boolean;
begin
  LQ := TIntMpmc.Create(4);
  LQ.TryEnqueue(1);
  LQ.Close;
  Check(LQ.IsClosed, 'closed');
  Check(not LQ.TryEnqueue(2), 'TryEnqueue after close rejected');
  Check(not LQ.EnqueueWait(2), 'EnqueueWait after close rejected');
  Check(not LQ.EnqueueTimeout(2, 1000000), 'EnqueueTimeout after close rejected');
  Check(LQ.TryDequeue(LV), 'drain after close');
  CheckEqual(Int64(1), Int64(LV));
  Check(not LQ.DequeueWait(LV), 'dequeue wait false on closed');
  LQ.Free;

  LQ := TIntMpmc.Create(1);
  LProducerStarted := False;
  try
    Check(LQ.TryEnqueue(1), 'fill queue before blocked producer close');
    GMpmcCloseWakeQ := LQ;
    AtomicStore32(GMpmcCloseWakeStarted, 0, moRelease);
    AtomicStore32(GMpmcCloseWakeResult, -1, moRelease);
    StartThread(LBlockedProducer, @MpmcCloseWakeProducer, nil, 'MPMC close timeout producer thread');
    LProducerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GMpmcCloseWakeStarted, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GMpmcCloseWakeStarted, moAcquire)),
      'blocked producer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(AtomicLoad32(GMpmcCloseWakeResult, moAcquire)),
      'blocked EnqueueTimeout should still be pending before close');
    LElapsedMs := GetTickCount64;
    LQ.Close;
    JoinStartedThread(LBlockedProducer, LProducerStarted, 'MPMC close timeout producer thread');
    LElapsedMs := GetTickCount64 - LElapsedMs;
    CheckEqual(Int64(0), Int64(AtomicLoad32(GMpmcCloseWakeResult, moAcquire)),
      'blocked EnqueueTimeout woken by close');
    Check(LElapsedMs < 1000, 'blocked EnqueueTimeout should return promptly after close');
    Check(LQ.TryDequeue(LV), 'drain queued item after blocked producer close');
    CheckEqual(Int64(1), Int64(LV));
    Check(not LQ.TryDequeue(LV), 'blocked producer wake must not publish extra item after close');
  finally
    if LProducerStarted then
    begin
      LQ.Close;
      JoinStartedThread(LBlockedProducer, LProducerStarted, 'MPMC close timeout producer thread');
    end;
    LQ.Free;
  end;

  LQ := TIntMpmc.Create(4);
  LConsumerStarted := False;
  try
    GMpmcCloseWakeQ := LQ;
    AtomicStore32(GMpmcCloseWakeStarted, 0, moRelease);
    AtomicStore32(GMpmcCloseWakeResult, -1, moRelease);
    StartThread(LBlockedConsumer, @MpmcCloseWakeConsumer, nil, 'MPMC close timeout consumer thread');
    LConsumerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GMpmcCloseWakeStarted, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GMpmcCloseWakeStarted, moAcquire)),
      'blocked consumer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(AtomicLoad32(GMpmcCloseWakeResult, moAcquire)),
      'blocked DequeueTimeout should still be pending before close');
    LElapsedMs := GetTickCount64;
    LQ.Close;
    JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'MPMC close timeout consumer thread');
    LElapsedMs := GetTickCount64 - LElapsedMs;
    CheckEqual(Int64(0), Int64(AtomicLoad32(GMpmcCloseWakeResult, moAcquire)),
      'blocked DequeueTimeout woken by close');
    Check(LElapsedMs < 1000, 'blocked DequeueTimeout should return promptly after close');
    Check(not LQ.TryDequeue(LV), 'blocked consumer wake must leave the closed empty queue empty');
  finally
    if LConsumerStarted then
    begin
      LQ.Close;
      JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'MPMC close timeout consumer thread');
    end;
    LQ.Free;
  end;
end;

procedure TestMpmcCloseWakeWaits;
var
  LQ: TIntMpmc;
  LV: Integer;
  LBlockedProducer: TPlatformThreadHandle;
  LBlockedConsumer: TPlatformThreadHandle;
  LElapsedMs: QWord;
  LSpin: Integer;
  LProducerStarted: Boolean;
  LConsumerStarted: Boolean;
begin
  LQ := TIntMpmc.Create(1);
  LProducerStarted := False;
  try
    Check(LQ.TryEnqueue(1), 'fill queue before blocked MPMC EnqueueWait close');
    GMpmcCloseWakeQ := LQ;
    AtomicStore32(GMpmcCloseWakeStarted, 0, moRelease);
    AtomicStore32(GMpmcCloseWakeResult, -1, moRelease);
    StartThread(LBlockedProducer, @MpmcCloseWaitProducer, nil, 'MPMC close wait producer thread');
    LProducerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GMpmcCloseWakeStarted, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GMpmcCloseWakeStarted, moAcquire)),
      'blocked MPMC EnqueueWait producer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(AtomicLoad32(GMpmcCloseWakeResult, moAcquire)),
      'blocked MPMC EnqueueWait should still be pending before close');
    LElapsedMs := GetTickCount64;
    LQ.Close;
    JoinStartedThread(LBlockedProducer, LProducerStarted, 'MPMC close wait producer thread');
    LElapsedMs := GetTickCount64 - LElapsedMs;
    CheckEqual(Int64(0), Int64(AtomicLoad32(GMpmcCloseWakeResult, moAcquire)),
      'blocked MPMC EnqueueWait woken by close');
    Check(LElapsedMs < 1000, 'blocked MPMC EnqueueWait should return promptly after close');
    Check(LQ.TryDequeue(LV), 'drain queued item after blocked MPMC EnqueueWait close');
    CheckEqual(Int64(1), Int64(LV));
    Check(not LQ.TryDequeue(LV), 'blocked MPMC EnqueueWait wake must not publish extra item after close');
  finally
    if LProducerStarted then
    begin
      LQ.Close;
      JoinStartedThread(LBlockedProducer, LProducerStarted, 'MPMC close wait producer thread');
    end;
    LQ.Free;
  end;

  LQ := TIntMpmc.Create(4);
  LConsumerStarted := False;
  try
    GMpmcCloseWakeQ := LQ;
    AtomicStore32(GMpmcCloseWakeStarted, 0, moRelease);
    AtomicStore32(GMpmcCloseWakeResult, -1, moRelease);
    StartThread(LBlockedConsumer, @MpmcCloseWaitConsumer, nil, 'MPMC close wait consumer thread');
    LConsumerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GMpmcCloseWakeStarted, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GMpmcCloseWakeStarted, moAcquire)),
      'blocked MPMC DequeueWait consumer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(AtomicLoad32(GMpmcCloseWakeResult, moAcquire)),
      'blocked MPMC DequeueWait should still be pending before close');
    LElapsedMs := GetTickCount64;
    LQ.Close;
    JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'MPMC close wait consumer thread');
    LElapsedMs := GetTickCount64 - LElapsedMs;
    CheckEqual(Int64(0), Int64(AtomicLoad32(GMpmcCloseWakeResult, moAcquire)),
      'blocked MPMC DequeueWait woken by close');
    Check(LElapsedMs < 1000, 'blocked MPMC DequeueWait should return promptly after close');
    Check(not LQ.TryDequeue(LV), 'blocked MPMC DequeueWait wake must leave the closed empty queue empty');
  finally
    if LConsumerStarted then
    begin
      LQ.Close;
      JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'MPMC close wait consumer thread');
    end;
    LQ.Free;
  end;
end;

procedure TestMpmcDequeueTimeoutWakesOnPublish;
var
  LQ: TIntMpmc;
  LConsumer: TPlatformThreadHandle;
  LRetVal: Pointer;
  LElapsedMs: QWord;
  LSpin: Integer;
  LV: Integer;
  LThreadCreated: Boolean;
  LJoined: Boolean;
begin
  LQ := TIntMpmc.Create(4);
  LThreadCreated := False;
  LJoined := False;
  try
    GMpmcPublishWakeQ := LQ;
    AtomicStore32(GMpmcPublishWakeConsumerStarted, 0, moRelease);
    AtomicStore32(GMpmcPublishWakeConsumerObservedEmpty, 0, moRelease);
    AtomicStore32(GMpmcPublishWakeConsumerResult, -1, moRelease);
    GMpmcPublishWakeConsumerValue := 0;
    StartThread(LConsumer, @MpmcPublishWakeConsumer, nil, 'MPMC publish wake consumer thread');
    LThreadCreated := True;

    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GMpmcPublishWakeConsumerStarted, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GMpmcPublishWakeConsumerStarted, moAcquire)),
      'MPMC DequeueTimeout consumer thread must start before publish');
    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GMpmcPublishWakeConsumerObservedEmpty, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GMpmcPublishWakeConsumerObservedEmpty, moAcquire)),
      'MPMC DequeueTimeout consumer must observe the empty queue before publish');
    platform_thread_sleep_ns(QueuePublishWakeDelayNs);
    CheckEqual(Int64(-1), Int64(AtomicLoad32(GMpmcPublishWakeConsumerResult, moAcquire)),
      'MPMC DequeueTimeout consumer should still be pending before publish');

    LElapsedMs := GetTickCount64;
    Check(LQ.TryEnqueue(42), 'MPMC producer must publish the wake item');
    JoinThread(LConsumer, LRetVal, 'publish wake consumer thread');
    LJoined := True;
    LElapsedMs := GetTickCount64 - LElapsedMs;

    CheckEqual(Int64(1), Int64(AtomicLoad32(GMpmcPublishWakeConsumerResult, moAcquire)),
      'MPMC DequeueTimeout must receive the producer-published item');
    CheckEqual(Int64(42), Int64(GMpmcPublishWakeConsumerValue));
    Check(LElapsedMs < QueuePublishWakeBudgetMs,
      'MPMC DequeueTimeout consumer must progress after data publish before the full timeout');
    Check(not LQ.TryDequeue(LV),
      'MPMC queue must be empty after the publish-woken consumer drains the item');
  finally
    if LThreadCreated and (not LJoined) then
      JoinThread(LConsumer, LRetVal, 'publish wake consumer thread');
    GMpmcPublishWakeQ := nil;
    LQ.Free;
  end;
end;

procedure TestMpmcEnqueueTimeoutWakesOnSpace;
var
  LQ: TIntMpmc;
  LProducer: TPlatformThreadHandle;
  LRetVal: Pointer;
  LElapsedMs: QWord;
  LSpin: Integer;
  LV: Integer;
  LThreadCreated: Boolean;
  LJoined: Boolean;
begin
  LQ := TIntMpmc.Create(1);
  LThreadCreated := False;
  LJoined := False;
  try
    Check(LQ.TryEnqueue(1), 'MPMC queue must be full before space-wake producer starts');
    GMpmcSpaceWakeQ := LQ;
    AtomicStore32(GMpmcSpaceWakeProducerStarted, 0, moRelease);
    AtomicStore32(GMpmcSpaceWakeProducerObservedFull, 0, moRelease);
    AtomicStore32(GMpmcSpaceWakeProducerResult, -1, moRelease);
    StartThread(LProducer, @MpmcSpaceWakeProducer, nil, 'MPMC space wake producer thread');
    LThreadCreated := True;

    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GMpmcSpaceWakeProducerStarted, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GMpmcSpaceWakeProducerStarted, moAcquire)),
      'MPMC EnqueueTimeout producer thread must start before space release');
    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GMpmcSpaceWakeProducerObservedFull, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GMpmcSpaceWakeProducerObservedFull, moAcquire)),
      'MPMC EnqueueTimeout producer must observe the full queue before space release');
    platform_thread_sleep_ns(QueuePublishWakeDelayNs);
    CheckEqual(Int64(-1), Int64(AtomicLoad32(GMpmcSpaceWakeProducerResult, moAcquire)),
      'MPMC EnqueueTimeout producer must not complete before space release');

    LElapsedMs := GetTickCount64;
    Check(LQ.TryDequeue(LV), 'MPMC consumer must release queue space');
    CheckEqual(Int64(1), Int64(LV));
    JoinThread(LProducer, LRetVal, 'space wake producer thread');
    LJoined := True;
    LElapsedMs := GetTickCount64 - LElapsedMs;

    CheckEqual(Int64(1), Int64(AtomicLoad32(GMpmcSpaceWakeProducerResult, moAcquire)),
      'MPMC EnqueueTimeout must publish after space release');
    Check(LElapsedMs < QueuePublishWakeBudgetMs,
      'MPMC EnqueueTimeout producer must progress after space release before the full timeout');
    Check(LQ.TryDequeue(LV), 'MPMC space-woken producer item must be drainable');
    CheckEqual(Int64(42), Int64(LV));
    Check(not LQ.TryDequeue(LV), 'MPMC queue must be empty after draining the space-woken item');
  finally
    if LThreadCreated and (not LJoined) then
      JoinThread(LProducer, LRetVal, 'space wake producer thread');
    GMpmcSpaceWakeQ := nil;
    LQ.Free;
  end;
end;

{ MPMC contention helpers }

var
  GMpmcQ: TIntMpmc;
  GMpmcSum: Int64;

function MpmcProducer(AArg: Pointer): Pointer; cdecl;
var
  LI, LStart: Integer;
begin
  Result := nil;
  LStart := Integer(PtrUInt(AArg));
  for LI := LStart to LStart + 249 do
    GMpmcQ.EnqueueWait(LI);
end;

function MpmcConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  while GMpmcQ.DequeueWait(LV) do
    InterlockedExchangeAdd64(GMpmcSum, Int64(LV));
end;

procedure TestMpmcContention;
var
  LProducers: array[0..3] of TPlatformThreadHandle;
  LConsumers: array[0..3] of TPlatformThreadHandle;
  LI: Integer;
  LExpected: Int64;
  LProducerCount: Integer;
  LConsumerCount: Integer;
begin
  GMpmcQ := TIntMpmc.Create(64);
  GMpmcSum := 0;
  LProducerCount := 0;
  LConsumerCount := 0;
  try
    for LI := 0 to 3 do
    begin
      StartThread(LConsumers[LI], @MpmcConsumer, nil, 'MPMC contention consumer thread');
      Inc(LConsumerCount);
    end;
    for LI := 0 to 3 do
    begin
      StartThread(LProducers[LI], @MpmcProducer, Pointer(PtrInt(LI * 250 + 1)), 'MPMC contention producer thread');
      Inc(LProducerCount);
    end;
    JoinStartedThreads(LProducers, LProducerCount, 'producer thread');
    platform_thread_sleep_ns(10000000);
    GMpmcQ.Close;
    JoinStartedThreads(LConsumers, LConsumerCount, 'consumer thread');
    LExpected := Int64(1000) * 1001 div 2;
    CheckEqual(LExpected, GMpmcSum, '4P+4C sum');
  finally
    GMpmcQ.Close;
    JoinStartedThreads(LProducers, LProducerCount, 'producer thread');
    JoinStartedThreads(LConsumers, LConsumerCount, 'consumer thread');
    GMpmcQ.Free;
  end;
end;

procedure TestCapacityZero;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    TIntSpsc.Create(0);
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'SPSC rejects 0');
  LGot := False;
  try
    TIntMpmc.Create(0);
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'MPMC rejects 0');
end;

function CapacityAboveMaxPowerOfTwo: PtrUInt;
var
  LMax: PtrUInt;
begin
  LMax := not PtrUInt(0);
  Result := (LMax - (LMax shr 1)) + 1;
end;

function StackCapacityAboveIndexLimit: PtrUInt;
begin
  Result := PtrUInt(High(Int32)) + 1;
end;

procedure TestCapacityOverflowReject;
var
  LCapacity: PtrUInt;
  LSpsc: TIntSpsc;
  LMpmc: TIntMpmc;
  LDeque: TIntDeque;
  LGot: Boolean;
begin
  LCapacity := CapacityAboveMaxPowerOfTwo;

  LGot := False;
  LSpsc := nil;
  try
    LSpsc := TIntSpsc.Create(LCapacity);
  except
    on E: EArgumentError do
      LGot := True;
  end;
  LSpsc.Free;
  Check(LGot, 'SPSC rejects capacity above maximum power-of-two');

  LGot := False;
  LMpmc := nil;
  try
    LMpmc := TIntMpmc.Create(LCapacity);
  except
    on E: EArgumentError do
      LGot := True;
  end;
  LMpmc.Free;
  Check(LGot, 'MPMC rejects capacity above maximum power-of-two');

  LGot := False;
  LDeque := nil;
  try
    LDeque := TIntDeque.Create(LCapacity);
  except
    on E: EArgumentError do
      LGot := True;
  end;
  LDeque.Free;
  Check(LGot, 'deque rejects capacity above maximum power-of-two');
end;

procedure TestMpmcSingleSlot;
var
  LQ: TIntMpmc;
  LV: Integer;
  LIn: array[0..1] of Integer;
  LOut: array[0..1] of Integer;
  LN: PtrUInt;
begin
  LQ := TIntMpmc.Create(1);
  CheckEqual(Int64(1), Int64(LQ.Capacity), 'single-slot capacity');
  CheckEqual(Int64(0), Int64(LQ.ApproxCount), 'single-slot initial count');
  Check(LQ.IsEmpty, 'single-slot initially empty');
  Check(not LQ.IsFull, 'single-slot initially not full');
  Check(LQ.TryEnqueue(7), 'single-slot enqueue');
  CheckEqual(Int64(1), Int64(LQ.ApproxCount), 'single-slot count after enqueue');
  Check(not LQ.IsEmpty, 'single-slot not empty after enqueue');
  Check(LQ.IsFull, 'single-slot full after enqueue');
  Check(not LQ.TryEnqueue(8), 'single-slot full rejects second enqueue');
  CheckEqual(Int64(1), Int64(LQ.ApproxCount), 'single-slot failed enqueue preserves count');
  Check(LQ.TryDequeue(LV), 'single-slot dequeue');
  CheckEqual(Int64(7), Int64(LV));
  CheckEqual(Int64(0), Int64(LQ.ApproxCount), 'single-slot count after dequeue');
  Check(LQ.IsEmpty, 'single-slot empty after dequeue');
  Check(not LQ.IsFull, 'single-slot not full after dequeue');
  Check(not LQ.TryDequeue(LV), 'single-slot empty after drain');
  Check(LQ.TryEnqueue(9), 'single-slot enqueue after recycle');
  Check(LQ.TryDequeue(LV), 'single-slot dequeue after recycle');
  CheckEqual(Int64(9), Int64(LV));
  Check(LQ.EnqueueTimeout(11, 1000000), 'single-slot enqueue timeout immediate');
  Check(not LQ.EnqueueTimeout(12, 1000000), 'single-slot enqueue timeout on full');
  Check(LQ.DequeueTimeout(LV, 1000000), 'single-slot dequeue timeout immediate');
  CheckEqual(Int64(11), Int64(LV));
  Check(not LQ.DequeueTimeout(LV, 1000000), 'single-slot dequeue timeout on empty');
  LIn[0] := 21;
  LIn[1] := 22;
  LN := LQ.EnqueueBatch(LIn);
  CheckEqual(Int64(1), Int64(LN), 'single-slot batch enqueue only published one item');
  Check(LQ.IsFull, 'single-slot full after batch enqueue');
  LN := LQ.DequeueBatch(LOut, 2);
  CheckEqual(Int64(1), Int64(LN), 'single-slot batch dequeue only returned one item');
  CheckEqual(Int64(21), Int64(LOut[0]));
  Check(LQ.IsEmpty, 'single-slot empty after batch dequeue');
  LQ.Free;
end;

procedure TestStackCapacityIndexLimitReject;
var
  LCapacity: PtrUInt;
  LStack: TIntStack;
  LGot: Boolean;
  LWrongException: string;
begin
  LCapacity := StackCapacityAboveIndexLimit;

  LGot := False;
  LWrongException := '';
  LStack := nil;
  try
    LStack := TIntStack.Create(LCapacity);
  except
    on E: EArgumentError do
      LGot := True;
    on E: Exception do
      LWrongException := E.ClassName;
  end;
  LStack.Free;
  Check(LGot, 'stack rejects capacity above 32-bit slot index limit; got ' + LWrongException);
end;

{ SPSC Batch }

procedure TestSpscBatch;
var
  LQ: TIntSpsc;
  LIn: array[0..3] of Integer;
  LOut: array[0..3] of Integer;
  LN: PtrUInt;
begin
  LQ := TIntSpsc.Create(8);
  LIn[0] := 10; LIn[1] := 20; LIn[2] := 30; LIn[3] := 40;
  LN := LQ.EnqueueBatch(LIn);
  CheckEqual(Int64(4), Int64(LN), 'batch enq 4');
  LN := LQ.DequeueBatch(LOut, 4);
  CheckEqual(Int64(4), Int64(LN), 'batch deq 4');
  CheckEqual(Int64(10), Int64(LOut[0]));
  CheckEqual(Int64(40), Int64(LOut[3]));
  LQ.Close;
  LN := LQ.EnqueueBatch(LIn);
  CheckEqual(Int64(0), Int64(LN), 'batch enqueue after close rejected');
  Check(LQ.IsEmpty, 'closed queue remains empty after rejected batch enqueue');
  LQ.Free;
end;

procedure TestSpscBatchPartialProgress;
var
  LQ: TIntSpsc;
  LIn: array[0..4] of Integer;
  LRefill: array[0..2] of Integer;
  LOutSmall: array[0..1] of Integer;
  LOutWide: array[0..4] of Integer;
  LV: Integer;
  LN: PtrUInt;
begin
  LQ := TIntSpsc.Create(4);
  try
    LIn[0] := 10; LIn[1] := 20; LIn[2] := 30; LIn[3] := 40; LIn[4] := 50;
    LN := LQ.EnqueueBatch(LIn);
    CheckEqual(Int64(4), Int64(LN), 'partial batch enqueue publishes only currently available slots');

    LN := LQ.DequeueBatch(LOutSmall, 5);
    CheckEqual(Int64(2), Int64(LN), 'partial batch dequeue is capped by output buffer length');
    CheckEqual(Int64(10), Int64(LOutSmall[0]));
    CheckEqual(Int64(20), Int64(LOutSmall[1]));

    Check(LQ.TryEnqueue(50), 'partial batch test seeds producer cache after partial drain');
    Check(LQ.TryDequeue(LV), 'partial batch test drains one item before refill');
    CheckEqual(Int64(30), Int64(LV));

    LRefill[0] := 60; LRefill[1] := 70; LRefill[2] := 80;
    LN := LQ.EnqueueBatch(LRefill);
    CheckEqual(Int64(2), Int64(LN), 'partial batch refill uses all currently available slots');

    LN := LQ.DequeueBatch(LOutWide, 5);
    CheckEqual(Int64(4), Int64(LN), 'partial batch dequeue drains all currently available items');
    CheckEqual(Int64(40), Int64(LOutWide[0]));
    CheckEqual(Int64(50), Int64(LOutWide[1]));
    CheckEqual(Int64(60), Int64(LOutWide[2]));
    CheckEqual(Int64(70), Int64(LOutWide[3]));
    Check(LQ.IsEmpty, 'partial batch dequeue leaves queue empty');
  finally
    LQ.Free;
  end;
end;

{ MPMC Timeout }

procedure TestMpmcTimeout;
var
  LQ: TIntMpmc;
  LV: Integer;
begin
  LQ := TIntMpmc.Create(2);
  LQ.TryEnqueue(1);
  LQ.TryEnqueue(2);
  Check(not LQ.EnqueueTimeout(3, 1000000), 'enq timeout on full');
  Check(LQ.DequeueTimeout(LV, 1000000), 'deq immediate');
  CheckEqual(Int64(1), Int64(LV));
  Check(LQ.EnqueueTimeout(3, 1000000), 'enq after space');
  LQ.Free;
end;

{ Stack }

procedure TestStackBasic;
var
  LSt: TIntStack;
  LV: Integer;
begin
  LSt := TIntStack.Create(16);
  Check(LSt.IsEmpty, 'empty');
  Check(LSt.TryPush(10), 'push 1');
  Check(LSt.TryPush(20), 'push 2');
  Check(LSt.TryPush(30), 'push 3');
  Check(not LSt.IsEmpty, 'not empty');
  Check(LSt.TryPop(LV), 'pop 1');
  CheckEqual(Int64(30), Int64(LV), 'LIFO');
  Check(LSt.TryPop(LV), 'pop 2');
  CheckEqual(Int64(20), Int64(LV));
  Check(LSt.TryPop(LV), 'pop 3');
  CheckEqual(Int64(10), Int64(LV));
  Check(not LSt.TryPop(LV), 'empty after pops');
  LSt.Free;
end;

procedure TestStackQueryContract;
var
  LSt: TIntStack;
  LV: Integer;
begin
  LSt := TIntStack.Create(3);
  Check(LSt.IsEmpty, 'stack query initial empty');
  CheckEqual(Int64(0), Int64(LSt.ApproxCount), 'stack query initial count');

  Check(LSt.TryPush(10), 'stack query push 1');
  CheckEqual(Int64(1), Int64(LSt.ApproxCount), 'stack query count after first push');
  Check(not LSt.IsEmpty, 'stack query not empty after first push');
  Check(LSt.TryPush(20), 'stack query push 2');
  CheckEqual(Int64(2), Int64(LSt.ApproxCount), 'stack query count after second push');
  Check(LSt.TryPush(30), 'stack query push 3');
  CheckEqual(Int64(3), Int64(LSt.ApproxCount), 'stack query full count');
  Check(not LSt.TryPush(40), 'stack query full push rejected');
  CheckEqual(Int64(3), Int64(LSt.ApproxCount), 'stack query failed full push preserves count');

  Check(LSt.TryPop(LV), 'stack query pop 1');
  CheckEqual(Int64(30), Int64(LV), 'stack query LIFO after full push set');
  CheckEqual(Int64(2), Int64(LSt.ApproxCount), 'stack query count after first pop');
  Check(LSt.TryPop(LV), 'stack query pop 2');
  CheckEqual(Int64(20), Int64(LV), 'stack query second pop');
  CheckEqual(Int64(1), Int64(LSt.ApproxCount), 'stack query count after second pop');
  Check(LSt.TryPop(LV), 'stack query pop 3');
  CheckEqual(Int64(10), Int64(LV), 'stack query third pop');
  CheckEqual(Int64(0), Int64(LSt.ApproxCount), 'stack query count after drain');
  Check(LSt.IsEmpty, 'stack query empty after drain');
  Check(not LSt.TryPop(LV), 'stack query pop rejected when empty');
  LSt.Free;
end;

{ MPSC }

var
  GMpscQ: TIntMpsc;
  GMpscPublishWakeQ: TIntMpsc;
  GMpscPublishWakeConsumerStarted: Int32;
  GMpscPublishWakeConsumerObservedEmpty: Int32;
  GMpscPublishWakeConsumerResult: Int32;
  GMpscPublishWakeConsumerValue: Integer;

function MpscProducer(AArg: Pointer): Pointer; cdecl;
var
  LI, LStart: Integer;
begin
  Result := nil;
  LStart := Integer(PtrUInt(AArg));
  for LI := LStart to LStart + 99 do
    GMpscQ.Enqueue(LI);
end;

function MpscPublishWakeConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  AtomicStore32(GMpscPublishWakeConsumerStarted, 1, moRelease);
  if GMpscPublishWakeQ.TryDequeue(LV) then
  begin
    GMpscPublishWakeConsumerValue := LV;
    AtomicStore32(GMpscPublishWakeConsumerResult, 2, moRelease);
    Exit;
  end;
  AtomicStore32(GMpscPublishWakeConsumerObservedEmpty, 1, moRelease);
  if GMpscPublishWakeQ.DequeueTimeout(LV, QueuePublishWakeTimeoutNs) then
  begin
    GMpscPublishWakeConsumerValue := LV;
    AtomicStore32(GMpscPublishWakeConsumerResult, 1, moRelease);
  end
  else
    AtomicStore32(GMpscPublishWakeConsumerResult, 0, moRelease);
end;

procedure TestMpscBasic;
var
  LQ: TIntMpsc;
  LV: Integer;
begin
  LQ := TIntMpsc.Create;
  Check(not LQ.TryDequeue(LV), 'empty');
  LQ.Enqueue(42);
  LQ.Enqueue(77);
  Check(LQ.TryDequeue(LV), 'deq 1');
  CheckEqual(Int64(42), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 2');
  CheckEqual(Int64(77), Int64(LV));
  Check(not LQ.TryDequeue(LV), 'empty again');
  LQ.Close;
  LQ.Free;
end;

procedure TestMpscCloseProducerContract;
var
  LQ: TIntMpsc;
  LV: Integer;
begin
  LQ := TIntMpsc.Create;
  LQ.Close;
  Check(LQ.IsClosed, 'closed');
  LQ.Enqueue(42);
  Check(LQ.TryDequeue(LV), 'MPSC enqueue after close still drains');
  CheckEqual(Int64(42), Int64(LV));
  Check(not LQ.DequeueWait(LV), 'dequeue wait false on closed empty MPSC');
  Check(not LQ.DequeueTimeout(LV, 1000000), 'dequeue timeout false on closed empty MPSC');
  LQ.Free;
end;

var
  GMpscCloseWakeQ: TIntMpsc;
  GMpscCloseWakeStarted: Int32;
  GMpscCloseWakeResult: Int32;

function MpscCloseWakeConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  AtomicStore32(GMpscCloseWakeStarted, 1, moRelease);
  if GMpscCloseWakeQ.DequeueTimeout(LV, 5000000000) then
    AtomicStore32(GMpscCloseWakeResult, 1, moRelease)
  else
    AtomicStore32(GMpscCloseWakeResult, 0, moRelease);
end;

function MpscCloseWaitConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  AtomicStore32(GMpscCloseWakeStarted, 1, moRelease);
  if GMpscCloseWakeQ.DequeueWait(LV) then
    AtomicStore32(GMpscCloseWakeResult, 1, moRelease)
  else
    AtomicStore32(GMpscCloseWakeResult, 0, moRelease);
end;

procedure TestMpscCloseWakeTimeout;
var
  LQ: TIntMpsc;
  LV: Integer;
  LBlockedConsumer: TPlatformThreadHandle;
  LElapsedMs: QWord;
  LSpin: Integer;
  LConsumerStarted: Boolean;
begin
  LQ := TIntMpsc.Create;
  LConsumerStarted := False;
  try
    GMpscCloseWakeQ := LQ;
    AtomicStore32(GMpscCloseWakeStarted, 0, moRelease);
    AtomicStore32(GMpscCloseWakeResult, -1, moRelease);
    StartThread(LBlockedConsumer, @MpscCloseWakeConsumer, nil, 'MPSC close timeout consumer thread');
    LConsumerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GMpscCloseWakeStarted, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GMpscCloseWakeStarted, moAcquire)),
      'blocked DequeueTimeout consumer thread must start before MPSC close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(AtomicLoad32(GMpscCloseWakeResult, moAcquire)),
      'blocked MPSC DequeueTimeout should still be pending before close');
    LElapsedMs := GetTickCount64;
    LQ.Close;
    JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'MPSC close timeout consumer thread');
    LElapsedMs := GetTickCount64 - LElapsedMs;
    CheckEqual(Int64(0), Int64(AtomicLoad32(GMpscCloseWakeResult, moAcquire)),
      'blocked MPSC DequeueTimeout woken by close');
    Check(LElapsedMs < 1000, 'blocked MPSC DequeueTimeout should return promptly after close');
    Check(not LQ.TryDequeue(LV), 'blocked MPSC consumer wake must leave the closed empty queue empty');
  finally
    if LConsumerStarted then
    begin
      LQ.Close;
      JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'MPSC close timeout consumer thread');
    end;
    LQ.Free;
  end;
end;

procedure TestMpscCloseWakeWait;
var
  LQ: TIntMpsc;
  LV: Integer;
  LBlockedConsumer: TPlatformThreadHandle;
  LElapsedMs: QWord;
  LSpin: Integer;
  LConsumerStarted: Boolean;
begin
  LQ := TIntMpsc.Create;
  LConsumerStarted := False;
  try
    GMpscCloseWakeQ := LQ;
    AtomicStore32(GMpscCloseWakeStarted, 0, moRelease);
    AtomicStore32(GMpscCloseWakeResult, -1, moRelease);
    StartThread(LBlockedConsumer, @MpscCloseWaitConsumer, nil, 'MPSC close wait consumer thread');
    LConsumerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GMpscCloseWakeStarted, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GMpscCloseWakeStarted, moAcquire)),
      'blocked MPSC DequeueWait consumer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(AtomicLoad32(GMpscCloseWakeResult, moAcquire)),
      'blocked MPSC DequeueWait should still be pending before close');
    LElapsedMs := GetTickCount64;
    LQ.Close;
    JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'MPSC close wait consumer thread');
    LElapsedMs := GetTickCount64 - LElapsedMs;
    CheckEqual(Int64(0), Int64(AtomicLoad32(GMpscCloseWakeResult, moAcquire)),
      'blocked MPSC DequeueWait woken by close');
    Check(LElapsedMs < 1000, 'blocked MPSC DequeueWait should return promptly after close');
    Check(not LQ.TryDequeue(LV), 'blocked MPSC DequeueWait wake must leave the closed empty queue empty');
  finally
    if LConsumerStarted then
    begin
      LQ.Close;
      JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'MPSC close wait consumer thread');
    end;
    LQ.Free;
  end;
end;

procedure TestMpscDestroyRequiresDrainInDebug;
var
  LQ: TIntMpsc;
  LV: Integer;
  LRaised: Boolean;
begin
  LQ := TIntMpsc.Create;
  LQ.Enqueue(42);
  LQ.Close;
  LRaised := False;
  try
    LQ.Free;
  except
    on E: EAssertionFailed do
      LRaised := True;
  end;
  {$IFDEF DEBUG}
  Check(LRaised, 'DEBUG MPSC destroy must reject close-without-drain');
  if LRaised then
  begin
    Check(LQ.TryDequeue(LV), 'cleanup drain queued MPSC item after failed destroy');
    CheckEqual(Int64(42), Int64(LV));
    LQ.Free;
  end;
  {$ELSE}
  Check(not LRaised, 'non-DEBUG MPSC destroy should not raise close-without-drain assertion');
  {$ENDIF}

  LQ := TIntMpsc.Create;
  LQ.Enqueue(42);
  LQ.Close;
  Check(LQ.TryDequeue(LV), 'drain queued MPSC item before destroy');
  CheckEqual(Int64(42), Int64(LV));
  LQ.Free;
end;

procedure TestMpscMultiProducer;
var
  LHandles: array[0..3] of TPlatformThreadHandle;
  LI, LV: Integer;
  LSum: Int64;
  LHandleCount: Integer;
begin
  GMpscQ := TIntMpsc.Create;
  LHandleCount := 0;
  try
    for LI := 0 to 3 do
    begin
      StartThread(LHandles[LI], @MpscProducer, Pointer(PtrInt(LI * 100 + 1)), 'MPSC producer thread');
      Inc(LHandleCount);
    end;
    JoinStartedThreads(LHandles, LHandleCount, 'worker thread');
    LSum := 0;
    while GMpscQ.TryDequeue(LV) do
      Inc(LSum, Int64(LV));
    CheckEqual(Int64(80200), LSum, '4 producers sum');
  finally
    JoinStartedThreads(LHandles, LHandleCount, 'worker thread');
    GMpscQ.Close;
    GMpscQ.Free;
  end;
end;

{ Work-stealing Deque }

procedure TestDequeBasic;
var
  LD: TIntDeque;
  LV: Integer;
begin
  LD := TIntDeque.Create(8);
  Check(LD.IsEmpty, 'empty');
  Check(LD.TryPush(10), 'push 1');
  Check(LD.TryPush(20), 'push 2');
  Check(LD.TryPush(30), 'push 3');
  CheckEqual(Int64(3), Int64(LD.ApproxCount), 'count 3');
  Check(LD.TryPop(LV), 'pop');
  CheckEqual(Int64(30), Int64(LV), 'LIFO pop');
  Check(LD.TrySteal(LV), 'steal');
  CheckEqual(Int64(10), Int64(LV), 'FIFO steal');
  Check(LD.TryPop(LV), 'pop last');
  CheckEqual(Int64(20), Int64(LV));
  Check(LD.IsEmpty, 'empty after all');
  LD.Free;
end;

procedure TestDequeQueryContract;
var
  LD: TIntDeque;
  LV: Integer;
begin
  LD := TIntDeque.Create(3);
  CheckEqual(Int64(4), Int64(LD.Capacity), 'deque query capacity rounds to next power-of-two');
  Check(LD.IsEmpty, 'deque query initial empty');
  CheckEqual(Int64(0), Int64(LD.ApproxCount), 'deque query initial count');

  Check(LD.TryPush(10), 'deque query push 1');
  Check(LD.TryPush(20), 'deque query push 2');
  Check(LD.TryPush(30), 'deque query push 3');
  Check(LD.TryPush(40), 'deque query push 4');
  CheckEqual(Int64(4), Int64(LD.ApproxCount), 'deque query full count');
  Check(not LD.IsEmpty, 'deque query not empty when full');
  Check(not LD.TryPush(50), 'deque query full push rejected');
  CheckEqual(Int64(4), Int64(LD.ApproxCount), 'deque query failed full push preserves count');

  Check(LD.TrySteal(LV), 'deque query steal');
  CheckEqual(Int64(10), Int64(LV), 'deque query steal must observe oldest value');
  CheckEqual(Int64(3), Int64(LD.ApproxCount), 'deque query count after steal');
  Check(LD.TryPop(LV), 'deque query pop 1');
  CheckEqual(Int64(40), Int64(LV), 'deque query owner pop must observe newest value');
  CheckEqual(Int64(2), Int64(LD.ApproxCount), 'deque query count after first pop');
  Check(LD.TryPop(LV), 'deque query pop 2');
  CheckEqual(Int64(30), Int64(LV), 'deque query second pop');
  CheckEqual(Int64(1), Int64(LD.ApproxCount), 'deque query count after second pop');
  Check(LD.TryPop(LV), 'deque query pop 3');
  CheckEqual(Int64(20), Int64(LV), 'deque query third pop');
  CheckEqual(Int64(0), Int64(LD.ApproxCount), 'deque query count after drain');
  Check(LD.IsEmpty, 'deque query empty after drain');
  Check(not LD.TrySteal(LV), 'deque query steal rejected when empty');
  LD.Free;
end;

{ Additional coverage tests }

procedure TestSpscCapacity;
var
  LQ: TIntSpsc;
begin
  LQ := TIntSpsc.Create(16);
  CheckEqual(Int64(16), Int64(LQ.Capacity), 'capacity');
  Check(LQ.IsEmpty, 'empty');
  Check(not LQ.IsFull, 'not full');
  LQ.TryEnqueue(1);
  Check(not LQ.IsEmpty, 'not empty');
  LQ.Free;
end;

procedure TestMpmcBatch;
var
  LQ: TIntMpmc;
  LIn: array[0..3] of Integer;
  LOut: array[0..3] of Integer;
  LN: PtrUInt;
begin
  LQ := TIntMpmc.Create(8);
  LIn[0] := 5; LIn[1] := 6; LIn[2] := 7; LIn[3] := 8;
  LN := LQ.EnqueueBatch(LIn);
  CheckEqual(Int64(4), Int64(LN), 'mpmc batch enq');
  LN := LQ.DequeueBatch(LOut, 4);
  CheckEqual(Int64(4), Int64(LN), 'mpmc batch deq');
  CheckEqual(Int64(5), Int64(LOut[0]));
  CheckEqual(Int64(8), Int64(LOut[3]));
  LN := LQ.EnqueueBatch(LIn);
  CheckEqual(Int64(4), Int64(LN), 'mpmc batch re-enqueue before close');
  LQ.Close;
  LN := LQ.DequeueBatch(LOut, 4);
  CheckEqual(Int64(4), Int64(LN), 'mpmc batch dequeue drains already-published items after close');
  CheckEqual(Int64(5), Int64(LOut[0]));
  CheckEqual(Int64(8), Int64(LOut[3]));
  LN := LQ.EnqueueBatch(LIn);
  CheckEqual(Int64(0), Int64(LN), 'mpmc batch enqueue after close rejected');
  Check(LQ.IsEmpty, 'closed MPMC queue remains empty after rejected batch enqueue');
  LQ.Free;
end;

procedure TestMpmcBatchPartialProgress;
var
  LQ: TIntMpmc;
  LIn: array[0..4] of Integer;
  LRefill: array[0..2] of Integer;
  LOutSmall: array[0..1] of Integer;
  LOutWide: array[0..4] of Integer;
  LN: PtrUInt;
begin
  LQ := TIntMpmc.Create(4);
  try
    LIn[0] := 10; LIn[1] := 20; LIn[2] := 30; LIn[3] := 40; LIn[4] := 50;
    LN := LQ.EnqueueBatch(LIn);
    CheckEqual(Int64(4), Int64(LN), 'mpmc partial batch enqueue publishes only currently available slots');

    LN := LQ.DequeueBatch(LOutSmall, 5);
    CheckEqual(Int64(2), Int64(LN), 'mpmc partial batch dequeue is capped by output buffer length');
    CheckEqual(Int64(10), Int64(LOutSmall[0]));
    CheckEqual(Int64(20), Int64(LOutSmall[1]));

    LRefill[0] := 60; LRefill[1] := 70; LRefill[2] := 80;
    LN := LQ.EnqueueBatch(LRefill);
    CheckEqual(Int64(2), Int64(LN), 'mpmc partial batch refill uses all currently available slots');

    LN := LQ.DequeueBatch(LOutWide, 5);
    CheckEqual(Int64(4), Int64(LN), 'mpmc partial batch dequeue drains all currently available items');
    CheckEqual(Int64(30), Int64(LOutWide[0]));
    CheckEqual(Int64(40), Int64(LOutWide[1]));
    CheckEqual(Int64(60), Int64(LOutWide[2]));
    CheckEqual(Int64(70), Int64(LOutWide[3]));
    Check(LQ.IsEmpty, 'mpmc partial batch dequeue leaves queue empty');
  finally
    LQ.Free;
  end;
end;

procedure TestMpmcBatchDequeueRespectsMaxCount;
var
  LQ: TIntMpmc;
  LIn: array[0..3] of Integer;
  LOut: array[0..5] of Integer;
  LV: Integer;
  LN: PtrUInt;
begin
  LQ := TIntMpmc.Create(8);
  try
    LIn[0] := 11; LIn[1] := 22; LIn[2] := 33; LIn[3] := 44;
    LN := LQ.EnqueueBatch(LIn);
    CheckEqual(Int64(4), Int64(LN), 'mpmc dequeue count cap fixture enqueued');

    LN := LQ.DequeueBatch(LOut, 2);
    CheckEqual(Int64(2), Int64(LN), 'mpmc batch dequeue respects AMaxCount even when output buffer is larger');
    CheckEqual(Int64(11), Int64(LOut[0]));
    CheckEqual(Int64(22), Int64(LOut[1]));

    Check(LQ.TryDequeue(LV), 'mpmc dequeue count cap leaves remaining items queued');
    CheckEqual(Int64(33), Int64(LV));
    Check(LQ.TryDequeue(LV), 'mpmc dequeue count cap preserves later queued item order');
    CheckEqual(Int64(44), Int64(LV));
    Check(LQ.IsEmpty, 'mpmc dequeue count cap leaves queue empty after draining remainder');
  finally
    LQ.Free;
  end;
end;

procedure TestMpmcCapacity;
var
  LQ: TIntMpmc;
begin
  LQ := TIntMpmc.Create(8);
  CheckEqual(Int64(8), Int64(LQ.Capacity));
  Check(LQ.IsEmpty, 'empty');
  Check(not LQ.IsFull, 'not full');
  LQ.Free;
end;

procedure CheckWaitHelperSkipsStaleEpoch(const AUseSpaceWait: Boolean; const ALabel: string);
var
  LEpoch: Int32;
  LWaiters: Int32;
  LElapsedMs: QWord;
begin
  LEpoch := 1;
  LWaiters := 0;
  LElapsedMs := GetTickCount64;
  if AUseSpaceWait then
    LockFreeWaitSpace(@LEpoch, @LWaiters, 0, WaitHelperStaleEpochTimeoutNs)
  else
    LockFreeWaitData(@LEpoch, @LWaiters, 0, WaitHelperStaleEpochTimeoutNs);
  LElapsedMs := GetTickCount64 - LElapsedMs;
  Check(LElapsedMs < WaitHelperImmediateReturnBudgetMs,
    ALabel + ' stale epoch must return before timeout');
  CheckEqual(Int64(0), Int64(LWaiters),
    ALabel + ' stale epoch must not leave a waiter registered');
  CheckEqual(Int64(1), Int64(LEpoch),
    ALabel + ' stale epoch fast path must not mutate the caller epoch');
end;

procedure TestLockFreeWaitHelperStaleEpochGuard;
begin
  CheckWaitHelperSkipsStaleEpoch(False, 'data wait helper');
  CheckWaitHelperSkipsStaleEpoch(True, 'space wait helper');
end;

var
  GMpscWaitQ: TIntMpsc;

function MpscWaitProducer(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
begin
  Result := nil;
  platform_thread_sleep_ns(5000000);
  for LI := 1 to 5 do
    GMpscWaitQ.Enqueue(LI);
  GMpscWaitQ.Close;
end;

procedure TestMpscDequeueWait;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LV, LSum: Integer;
begin
  GMpscWaitQ := TIntMpsc.Create;
  LSum := 0;
  StartThread(LHandle, @MpscWaitProducer, nil, 'MPSC wait producer thread');
  while GMpscWaitQ.DequeueWait(LV) do
    Inc(LSum, LV);
  JoinThread(LHandle, LRetVal, 'MPSC wait producer thread');
  CheckEqual(Int64(15), Int64(LSum), '1+2+3+4+5');
  GMpscWaitQ.Free;
end;

procedure TestMpscDequeueTimeoutWakesOnPublish;
var
  LQ: TIntMpsc;
  LConsumer: TPlatformThreadHandle;
  LRetVal: Pointer;
  LElapsedMs: QWord;
  LSpin: Integer;
  LV: Integer;
  LThreadCreated: Boolean;
  LJoined: Boolean;
begin
  LQ := TIntMpsc.Create;
  LThreadCreated := False;
  LJoined := False;
  try
    GMpscPublishWakeQ := LQ;
    AtomicStore32(GMpscPublishWakeConsumerStarted, 0, moRelease);
    AtomicStore32(GMpscPublishWakeConsumerObservedEmpty, 0, moRelease);
    AtomicStore32(GMpscPublishWakeConsumerResult, -1, moRelease);
    GMpscPublishWakeConsumerValue := 0;
    StartThread(LConsumer, @MpscPublishWakeConsumer, nil, 'MPSC publish wake consumer thread');
    LThreadCreated := True;

    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GMpscPublishWakeConsumerStarted, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GMpscPublishWakeConsumerStarted, moAcquire)),
      'MPSC DequeueTimeout consumer thread must start before publish');
    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GMpscPublishWakeConsumerObservedEmpty, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GMpscPublishWakeConsumerObservedEmpty, moAcquire)),
      'MPSC DequeueTimeout consumer must observe the empty queue before publish');
    platform_thread_sleep_ns(QueuePublishWakeDelayNs);
    CheckEqual(Int64(-1), Int64(AtomicLoad32(GMpscPublishWakeConsumerResult, moAcquire)),
      'MPSC DequeueTimeout consumer must not complete before publish');

    LElapsedMs := GetTickCount64;
    LQ.Enqueue(42);
    JoinThread(LConsumer, LRetVal, 'publish wake consumer thread');
    LJoined := True;
    LElapsedMs := GetTickCount64 - LElapsedMs;

    CheckEqual(Int64(1), Int64(AtomicLoad32(GMpscPublishWakeConsumerResult, moAcquire)),
      'MPSC DequeueTimeout must receive the producer-published item');
    CheckEqual(Int64(42), Int64(GMpscPublishWakeConsumerValue));
    Check(LElapsedMs < QueuePublishWakeBudgetMs,
      'MPSC DequeueTimeout consumer must progress after data publish before the full timeout');
    Check(not LQ.TryDequeue(LV),
      'MPSC queue must be empty after the publish-woken consumer drains the item');
  finally
    if LThreadCreated and (not LJoined) then
    begin
      LQ.Close;
      JoinThread(LConsumer, LRetVal, 'publish wake consumer thread');
    end;
    GMpscPublishWakeQ := nil;
    LQ.Close;
    while LQ.TryDequeue(LV) do;
    LQ.Free;
  end;
end;

procedure TestMpscDequeueTimeout;
var
  LQ: TIntMpsc;
  LV: Integer;
begin
  LQ := TIntMpsc.Create;
  Check(not LQ.DequeueTimeout(LV, 1000000), 'timeout 1ms on empty');
  LQ.Enqueue(42);
  Check(LQ.DequeueTimeout(LV, 1000000), 'immediate');
  CheckEqual(Int64(42), Int64(LV));
  LQ.Close;
  LQ.Free;
end;

procedure TestDequeCapacity;
var
  LD: TIntDeque;
begin
  LD := TIntDeque.Create(32);
  CheckEqual(Int64(32), Int64(LD.Capacity));
  LD.Free;
end;

{ Multi-thread stress tests }

const
  STRESS_OPS = 100000;

var
  GStressStack: specialize TLockFreeStack<Integer>;
  GStackPushCount: Int64;
  GStackPopCount: Int64;
  GStackStressStop: Int32;

function StackStressPusher(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
begin
  Result := nil;
  for LI := 1 to STRESS_OPS do
  begin
    if AtomicLoad32(GStackStressStop, moAcquire) <> 0 then
      Exit;
    while not GStressStack.TryPush(LI) do
    begin
      if AtomicLoad32(GStackStressStop, moAcquire) <> 0 then
        Exit;
      CpuPause;
    end;
  end;
  InterlockedExchangeAdd64(GStackPushCount, STRESS_OPS);
end;

function StackStressPopper(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
  LCount: Int64;
begin
  Result := nil;
  LCount := 0;
  while True do
  begin
    if GStressStack.TryPop(LV) then
      Inc(LCount)
    else if AtomicLoad32(GStackStressStop, moAcquire) <> 0 then
      Break
    else if InterlockedCompareExchange64(GStackPushCount, 0, 0) >= STRESS_OPS * 4 then
    begin
      while GStressStack.TryPop(LV) do
        Inc(LCount);
      Break;
    end
    else
      CpuPause;
  end;
  InterlockedExchangeAdd64(GStackPopCount, LCount);
end;

procedure TestStackStress;
var
  LPushers: array[0..3] of TPlatformThreadHandle;
  LPoppers: array[0..3] of TPlatformThreadHandle;
  LI: Integer;
  LPusherCount: Integer;
  LPopperCount: Integer;
begin
  GStressStack := specialize TLockFreeStack<Integer>.Create(4096);
  GStackPushCount := 0;
  GStackPopCount := 0;
  AtomicStore32(GStackStressStop, 0, moRelease);
  LPusherCount := 0;
  LPopperCount := 0;
  try
    for LI := 0 to 3 do
    begin
      StartThread(LPushers[LI], @StackStressPusher, nil, 'stack stress pusher thread');
      Inc(LPusherCount);
    end;
    for LI := 0 to 3 do
    begin
      StartThread(LPoppers[LI], @StackStressPopper, nil, 'stack stress popper thread');
      Inc(LPopperCount);
    end;
    JoinStartedThreads(LPushers, LPusherCount, 'stack stress pusher thread');
    JoinStartedThreads(LPoppers, LPopperCount, 'stack stress popper thread');
    CheckEqual(Int64(STRESS_OPS * 4), GStackPopCount, 'stack 4P+4C all popped');
  finally
    AtomicStore32(GStackStressStop, 1, moRelease);
    JoinStartedThreads(LPushers, LPusherCount, 'stack stress pusher thread');
    JoinStartedThreads(LPoppers, LPopperCount, 'stack stress popper thread');
    GStressStack.Free;
  end;
end;

var
  GStressDeque: specialize TWorkStealingDeque<Integer>;
  GDequeStealCount: Int64;

function DequeThief(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
  LCount: Int64;
begin
  Result := nil;
  LCount := 0;
  while InterlockedCompareExchange64(GDequeStealCount, 0, 0) < STRESS_OPS do
  begin
    if GStressDeque.TrySteal(LV) then
      Inc(LCount);
  end;
  InterlockedExchangeAdd64(GDequeStealCount, LCount);
end;

procedure TestDequeOwnerThief;
var
  LThieves: array[0..2] of TPlatformThreadHandle;
  LI, LV: Integer;
  LOwnerPop: Int64;
  LThiefCount: Integer;
  LStopSignaled: Boolean;
begin
  GStressDeque := specialize TWorkStealingDeque<Integer>.Create(1024);
  GDequeStealCount := 0;
  LOwnerPop := 0;
  LThiefCount := 0;
  LStopSignaled := False;
  try
    for LI := 0 to 2 do
    begin
      StartThread(LThieves[LI], @DequeThief, nil, 'deque thief thread');
      Inc(LThiefCount);
    end;
    for LI := 1 to STRESS_OPS do
    begin
      while not GStressDeque.TryPush(LI) do
      begin
        if GStressDeque.TryPop(LV) then
          Inc(LOwnerPop);
      end;
    end;
    while GStressDeque.TryPop(LV) do
      Inc(LOwnerPop);
    InterlockedExchangeAdd64(GDequeStealCount, STRESS_OPS);
    LStopSignaled := True;
    JoinStartedThreads(LThieves, LThiefCount, 'deque thief thread');
    Check(LOwnerPop + GDequeStealCount - STRESS_OPS > 0, 'deque owner+thieves processed items');
  finally
    if not LStopSignaled then
      InterlockedExchangeAdd64(GDequeStealCount, STRESS_OPS);
    JoinStartedThreads(LThieves, LThiefCount, 'deque thief thread');
    GStressDeque.Free;
  end;
end;

procedure TestManagedTypeReject;
type
  TStrSpsc = specialize TSpscQueue<AnsiString>;
  TStrMpmc = specialize TMpmcQueue<AnsiString>;
  TStrMpsc = specialize TMpscQueue<AnsiString>;
  TStrStack = specialize TLockFreeStack<AnsiString>;
  TStrDeque = specialize TWorkStealingDeque<AnsiString>;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    TStrSpsc.Create(4);
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'SPSC managed type rejected');

  LGot := False;
  try
    TStrMpmc.Create(4);
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'MPMC managed type rejected');

  LGot := False;
  try
    TStrMpsc.Create;
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'MPSC managed type rejected');

  LGot := False;
  try
    TStrStack.Create(4);
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'stack managed type rejected');

  LGot := False;
  try
    TStrDeque.Create(4);
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'deque managed type rejected');
end;

procedure TestLockFreeSourceContracts;
const
  LockFreeSourcePath = '../../../src/nextpas.core.lockfree.pas';
  LockFreeDocsReadmePath = '../../../docs/lockfree/README.md';
  LockFreeTestSourcePath = 'test_lockfree.lpr';
  LockFreeStressTestSourcePath = '../test_lockfree_stress/test_lockfree_stress.lpr';
  LockFreeTestMakefilePath = 'Makefile';
  SpscSourcePath = '../../../src/nextpas.core.lockfree.spsc.pas';
  MpmcSourcePath = '../../../src/nextpas.core.lockfree.mpmc.pas';
  StackSourcePath = '../../../src/nextpas.core.lockfree.stack.pas';
  MpscSourcePath = '../../../src/nextpas.core.lockfree.mpsc.pas';
  DequeSourcePath = '../../../src/nextpas.core.lockfree.deque.pas';
  WaitSourcePath = '../../../src/nextpas.core.lockfree.wait.pas';
  BenchMakefilePath = '../../../benchmarks/nextpas.core.lockfree/bench_lockfree/Makefile';
  BenchSourcePath = '../../../benchmarks/nextpas.core.lockfree/bench_lockfree/bench_lockfree.lpr';
  BenchRustComparePath = '../../../benchmarks/nextpas.core.lockfree/bench_lockfree/compare_rust/main.rs';
  BenchGoComparePath = '../../../benchmarks/nextpas.core.lockfree/bench_lockfree/compare_go/main.go';
  BenchCppComparePath = '../../../benchmarks/nextpas.core.lockfree/bench_lockfree/compare_cpp/main.cpp';
var
  LLockFreeSource: string;
  LDocsReadme: string;
  LTestSource: string;
  LStressTestSource: string;
  LTestRuntimeHarnessSourceSection: string;
  LStressRuntimeHarnessSourceSection: string;
  LTestMakefile: string;
  LSpscSource: string;
  LMpmcSource: string;
  LStackSource: string;
  LMpscSource: string;
  LDequeSource: string;
  LWaitSource: string;
  LBenchMakefile: string;
  LBenchSource: string;
  LRustCompareSource: string;
  LGoCompareSource: string;
  LCppCompareSource: string;
  LSpscCloseTestSection: string;
  LSpscCloseWakeTestSection: string;
  LMpmcCloseTestSection: string;
  LMpmcCloseWakeWaitTestSection: string;
  LMpmcPublishWakeTestSection: string;
  LMpmcSpaceWakeTestSection: string;
  LMpmcTryEnqueueSourceSection: string;
  LMpmcLeaveActiveSourceSection: string;
  LMpmcDequeueWaitSourceSection: string;
  LMpmcDequeueTimeoutSourceSection: string;
  LMpmcActiveCloseStressSection: string;
  LSpscBatchSourceSection: string;
  LSpscDequeueBatchSourceSection: string;
  LSpscBatchTestSection: string;
  LMpmcBatchSourceSection: string;
  LMpmcBatchTestSection: string;
  LMpmcSingleSlotTestSection: string;
  LMpmcSingleSlotStressSection: string;
  LStackABAStressSection: string;
  LMpscBasicTestSection: string;
  LMpscCloseProducerTestSection: string;
  LMpscCloseWakeTestSection: string;
  LMpscCloseWakeWaitTestSection: string;
  LMpscDestroyDrainTestSection: string;
  LMpscMultiProducerTestSection: string;
  LMpscPublishWakeTestSection: string;
  LMpscTimeoutTestSection: string;
  LSpscPublishWakeTestSection: string;
  LSpscSpaceWakeTestSection: string;
begin
  Check(FileExists(LockFreeDocsReadmePath),
    'lockfree README must exist as the module documentation entrypoint');
  Check(FileExists(LockFreeTestMakefilePath),
    'lockfree test Makefile must exist as the focused verification entrypoint');
  Check(FileExists(LockFreeStressTestSourcePath),
    'lockfree stress test source must exist as the stress verification entrypoint');
  Check(FileExists(BenchMakefilePath),
    'lockfree benchmark Makefile must exist as the benchmark verification entrypoint');
  Check(FileExists(BenchSourcePath),
    'lockfree benchmark source must exist as the benchmark entrypoint');
  Check(FileExists(BenchRustComparePath),
    'lockfree Rust comparison source must exist as an external baseline reference');
  Check(FileExists(BenchGoComparePath),
    'lockfree Go comparison source must exist as an external baseline reference');
  Check(FileExists(BenchCppComparePath),
    'lockfree C++ comparison source must exist as an external baseline reference');

  LLockFreeSource := ReadUtf8TextFile(LockFreeSourcePath);
  LDocsReadme := ReadUtf8TextFile(LockFreeDocsReadmePath);
  LTestSource := ReadUtf8TextFile(LockFreeTestSourcePath);
  LStressTestSource := ReadUtf8TextFile(LockFreeStressTestSourcePath);
  LTestRuntimeHarnessSourceSection := ExtractSection(LTestSource,
    'function StartThread(',
    'procedure TestLockFreeSourceContracts;',
    'lockfree behavior runtime harness source section');
  LStressRuntimeHarnessSourceSection := ExtractSection(LStressTestSource,
    'function StartThread(',
    '{ Main',
    'lockfree stress runtime harness source section');
  LTestMakefile := ReadUtf8TextFile(LockFreeTestMakefilePath);
  LSpscSource := ReadUtf8TextFile(SpscSourcePath);
  LMpmcSource := ReadUtf8TextFile(MpmcSourcePath);
  LStackSource := ReadUtf8TextFile(StackSourcePath);
  LMpscSource := ReadUtf8TextFile(MpscSourcePath);
  LDequeSource := ReadUtf8TextFile(DequeSourcePath);
  LWaitSource := ReadUtf8TextFile(WaitSourcePath);
  LBenchMakefile := ReadUtf8TextFile(BenchMakefilePath);
  LBenchSource := ReadUtf8TextFile(BenchSourcePath);
  LRustCompareSource := ReadUtf8TextFile(BenchRustComparePath);
  LGoCompareSource := ReadUtf8TextFile(BenchGoComparePath);
  LCppCompareSource := ReadUtf8TextFile(BenchCppComparePath);
  LSpscCloseTestSection := ExtractSection(LTestSource,
    'procedure TestSpscClose;',
    'function SpscCloseWakeProducer',
    'SPSC close test source section');
  LSpscCloseWakeTestSection := ExtractSection(LTestSource,
    'procedure TestSpscCloseWakeTimeouts;',
    'procedure TestSpscApproxCount;',
    'SPSC close wake test source section');
  LSpscPublishWakeTestSection := ExtractSection(LTestSource,
    'procedure TestSpscDequeueTimeoutWakesOnPublish;',
    'procedure TestSpscEnqueueTimeoutWakesOnSpace;',
    'SPSC publish wake test source section');
  LSpscSpaceWakeTestSection := ExtractSection(LTestSource,
    'procedure TestSpscEnqueueTimeoutWakesOnSpace;',
    '{ MPMC tests }',
    'SPSC space wake test source section');
  LMpmcCloseTestSection := ExtractSection(LTestSource,
    'procedure TestMpmcClose;',
    'procedure TestMpmcCloseWakeWaits;',
    'MPMC close timeout wake test source section');
  LMpmcCloseWakeWaitTestSection := ExtractSection(LTestSource,
    'procedure TestMpmcCloseWakeWaits;',
    'procedure TestMpmcDequeueTimeoutWakesOnPublish;',
    'MPMC close wait wake test source section');
  LMpmcPublishWakeTestSection := ExtractSection(LTestSource,
    'procedure TestMpmcDequeueTimeoutWakesOnPublish;',
    'procedure TestMpmcEnqueueTimeoutWakesOnSpace;',
    'MPMC publish wake test source section');
  LMpmcSpaceWakeTestSection := ExtractSection(LTestSource,
    'procedure TestMpmcEnqueueTimeoutWakesOnSpace;',
    '{ MPMC contention helpers }',
    'MPMC space wake test source section');
  LMpmcTryEnqueueSourceSection := ExtractSection(LMpmcSource,
    'function TMpmcQueueImpl.TryEnqueue',
    'function TMpmcQueueImpl.TryDequeue',
    'MPMC TryEnqueue source section');
  LMpmcLeaveActiveSourceSection := ExtractSection(LMpmcSource,
    'procedure TMpmcQueueImpl.LeaveActiveEnqueue;',
    'function TMpmcQueueImpl.TryEnqueue',
    'MPMC active enqueue leave source section');
  LMpmcDequeueWaitSourceSection := ExtractSection(LMpmcSource,
    'function TMpmcQueueImpl.DequeueWait',
    'function TMpmcQueueImpl.EnqueueTimeout',
    'MPMC DequeueWait source section');
  LMpmcDequeueTimeoutSourceSection := ExtractSection(LMpmcSource,
    'function TMpmcQueueImpl.DequeueTimeout',
    'procedure TMpmcQueueImpl.Close',
    'MPMC DequeueTimeout source section');
  LMpmcActiveCloseStressSection := ExtractSection(LStressTestSource,
    'procedure TestMpmcCloseRacesActiveProducers;',
    '{ TEST 7: Stack Capacity Exhaustion + Recovery',
    'MPMC active-producer close stress source section');
  LSpscBatchSourceSection := ExtractSection(LSpscSource,
    'function TSpscQueueImpl.EnqueueBatch',
    'function TSpscQueueImpl.DequeueBatch',
    'SPSC batch source section');
  LSpscDequeueBatchSourceSection := ExtractSection(LSpscSource,
    'function TSpscQueueImpl.DequeueBatch',
    'procedure TSpscQueueImpl.Close',
    'SPSC dequeue batch source section');
  LSpscBatchTestSection := ExtractSection(LTestSource,
    'procedure TestSpscBatch;',
    '{ MPMC Timeout }',
    'SPSC batch test source section');
  LMpmcBatchSourceSection := ExtractSection(LMpmcSource,
    'function TMpmcQueueImpl.EnqueueBatch',
    'function TMpmcQueueImpl.DequeueBatch',
    'MPMC batch source section');
  LMpmcBatchTestSection := ExtractSection(LTestSource,
    'procedure TestMpmcBatch;',
    'procedure TestMpmcCapacity;',
    'MPMC batch test source section');
  LMpmcSingleSlotTestSection := ExtractSection(LTestSource,
    'procedure TestMpmcSingleSlot;',
    'procedure TestStackCapacityIndexLimitReject;',
    'MPMC single-slot test source section');
  LMpmcSingleSlotStressSection := ExtractSection(LStressTestSource,
    'procedure TestMpmcSingleSlotContention;',
    '{ TEST 2: Stack ABA Stress',
    'MPMC single-slot stress test source section');
  LStackABAStressSection := ExtractSection(LStressTestSource,
    '{ TEST 2: Stack ABA Stress',
    '{ TEST 3: MPSC High-Frequency Close Race',
    'Stack ABA stress test source section');
  LMpscBasicTestSection := ExtractSection(LTestSource,
    'procedure TestMpscBasic;',
    'procedure TestMpscCloseProducerContract;',
    'MPSC basic test source section');
  LMpscCloseProducerTestSection := ExtractSection(LTestSource,
    'procedure TestMpscCloseProducerContract;',
    'function MpscCloseWakeConsumer',
    'MPSC close producer contract test source section');
  LMpscCloseWakeTestSection := ExtractSection(LTestSource,
    'procedure TestMpscCloseWakeTimeout;',
    'procedure TestMpscCloseWakeWait;',
    'MPSC close wake timeout test source section');
  LMpscCloseWakeWaitTestSection := ExtractSection(LTestSource,
    'procedure TestMpscCloseWakeWait;',
    'procedure TestMpscDestroyRequiresDrainInDebug;',
    'MPSC close wake wait test source section');
  LMpscDestroyDrainTestSection := ExtractSection(LTestSource,
    'procedure TestMpscDestroyRequiresDrainInDebug;',
    'procedure TestMpscMultiProducer;',
    'MPSC destroy drain contract test source section');
  LMpscMultiProducerTestSection := ExtractSection(LTestSource,
    'procedure TestMpscMultiProducer;',
    '{ Work-stealing Deque }',
    'MPSC multi-producer test source section');
  LMpscPublishWakeTestSection := ExtractSection(LTestSource,
    'procedure TestMpscDequeueTimeoutWakesOnPublish;',
    'procedure TestMpscDequeueTimeout;',
    'MPSC publish wake test source section');
  LMpscTimeoutTestSection := ExtractSection(LTestSource,
    'procedure TestMpscDequeueTimeout;',
    'procedure TestDequeCapacity;',
    'MPSC timeout test source section');

  CheckContains(LDocsReadme, '# nextpas.core.lockfree',
    'lockfree README must use the module title');
  CheckContains(LDocsReadme,
    '`nextpas.core.lockfree` facade exposes `TSpscQueue<T>`, `TMpmcQueue<T>`, `TMpscQueue<T>`',
    'lockfree README must document the facade re-export surface');
  CheckContains(LDocsReadme,
    '`TLockFreeStack<T>`, and `TWorkStealingDeque<T>`',
    'lockfree README must document the facade stack/deque surface');
  CheckContains(LDocsReadme,
    'The facade and submodule public names are wrapper classes over shared `*Impl<T>` implementation',
    'lockfree README must document the generic facade wrapper boundary');
  CheckContains(LDocsReadme,
    'not Pascal type aliases',
    'lockfree README must document that generic facade wrappers are not aliases');
  CheckContains(LSpscSource,
    'generic TSpscQueueImpl<T> = class',
    'SPSC source must keep a shared implementation base for facade re-export');
  CheckContains(LMpmcSource,
    'generic TMpmcQueueImpl<T> = class',
    'MPMC source must keep a shared implementation base for facade re-export');
  CheckContains(LMpscSource,
    'generic TMpscQueueImpl<T> = class',
    'MPSC source must keep a shared implementation base for facade re-export');
  CheckContains(LStackSource,
    'generic TLockFreeStackImpl<T> = class',
    'stack source must keep a shared implementation base for facade re-export');
  CheckContains(LDequeSource,
    'generic TWorkStealingDequeImpl<T> = class',
    'deque source must keep a shared implementation base for facade re-export');
  CheckContains(LSpscSource,
    'generic TSpscQueue<T> = class(specialize TSpscQueueImpl<T>)',
    'SPSC submodule must keep the public wrapper type');
  CheckContains(LMpmcSource,
    'generic TMpmcQueue<T> = class(specialize TMpmcQueueImpl<T>)',
    'MPMC submodule must keep the public wrapper type');
  CheckContains(LMpscSource,
    'generic TMpscQueue<T> = class(specialize TMpscQueueImpl<T>)',
    'MPSC submodule must keep the public wrapper type');
  CheckContains(LStackSource,
    'generic TLockFreeStack<T> = class(specialize TLockFreeStackImpl<T>)',
    'stack submodule must keep the public wrapper type');
  CheckContains(LDequeSource,
    'generic TWorkStealingDeque<T> = class(specialize TWorkStealingDequeImpl<T>)',
    'deque submodule must keep the public wrapper type');
  CheckContains(LLockFreeSource,
    'generic TSpscQueue<T> = class(specialize TSpscQueueImpl<T>)',
    'lockfree facade must explicitly expose the SPSC queue type');
  CheckContains(LLockFreeSource,
    'generic TMpmcQueue<T> = class(specialize TMpmcQueueImpl<T>)',
    'lockfree facade must explicitly expose the MPMC queue type');
  CheckContains(LLockFreeSource,
    'generic TMpscQueue<T> = class(specialize TMpscQueueImpl<T>)',
    'lockfree facade must explicitly expose the MPSC queue type');
  CheckContains(LLockFreeSource,
    'generic TLockFreeStack<T> = class(specialize TLockFreeStackImpl<T>)',
    'lockfree facade must explicitly expose the stack type');
  CheckContains(LLockFreeSource,
    'generic TWorkStealingDeque<T> = class(specialize TWorkStealingDequeImpl<T>)',
    'lockfree facade must explicitly expose the work-stealing deque type');
  CheckContains(LDocsReadme, '`TSpscQueue<T>`',
    'lockfree README must document SPSC queue ownership');
  CheckContains(LDocsReadme, '`TMpmcQueue<T>`',
    'lockfree README must document MPMC queue ownership');
  CheckContains(LDocsReadme, '`TMpscQueue<T>`',
    'lockfree README must document MPSC queue ownership');
  CheckContains(LDocsReadme, '`TLockFreeStack<T>`',
    'lockfree README must document stack ownership');
  CheckContains(LDocsReadme, '`TWorkStealingDeque<T>`',
    'lockfree README must document deque ownership');
  CheckContains(LDocsReadme, 'Thread safety contract',
    'lockfree README must document the consolidated thread-safety contract');
  CheckContains(LDocsReadme,
    '`TSpscQueue<T>` permits exactly one producer-side caller and exactly one consumer-side caller; multiple producers or multiple consumers on the same queue are outside the contract.',
    'lockfree README must document the SPSC caller-role contract');
  CheckContains(LDocsReadme,
    '`TMpmcQueue<T>` permits multiple concurrent producers and consumers; `Close` may race with producers. Enqueue calls admitted before observing the closed flag may still publish at their normal per-item linearization point; calls that observe `Close` fail, and consumers only treat closed-empty as terminal after no admitted producer can still publish.',
    'lockfree README must document the MPMC caller-role and active-producer close contract');
  CheckContains(LDocsReadme,
    '`TSpscQueue<T>.EnqueueBatch` returns 0 after `Close` and must not publish new items.',
    'lockfree README must document SPSC batch close semantics');
  CheckContains(LDocsReadme,
    '`TSpscQueue<T>.EnqueueBatch` / `DequeueBatch` publish or consume only the prefix that currently fits or is available, capped by the caller-provided array/count, and return that partial count instead of waiting for the remainder.',
    'lockfree README must document the SPSC batch partial-progress contract');
  CheckContains(LDocsReadme,
    '`TMpmcQueue<T>.EnqueueBatch` returns 0 when it observes `Close` before publishing any item; under concurrent `Close`, it returns the prefix already published by its underlying `TryEnqueue` calls.',
    'lockfree README must document MPMC batch close semantics');
  CheckContains(LDocsReadme,
    '`TMpmcQueue<T>.EnqueueBatch` / `DequeueBatch` are convenience loops over consecutive `TryEnqueue` / `TryDequeue` calls: they return the successful prefix so far when the next single-item operation would fail, instead of waiting for the remainder or promising a shared batch linearization point.',
    'lockfree README must document the MPMC batch partial-progress contract');
  CheckContains(LDocsReadme,
    '`TMpmcQueue<T>` accepts requested capacity 1; its per-slot sequence token uses separate empty/full states so a single-slot queue still distinguishes full from empty.',
    'lockfree README must document single-slot MPMC support');
  CheckContains(LDocsReadme,
    '`TMpscQueue<T>` permits multiple producers and exactly one consumer; `Enqueue` does not observe `Close`, so callers must stop and join producers before destroy.',
    'lockfree README must document the MPSC caller-role and destroy contract');
  CheckContains(LDocsReadme,
    '`TSpscQueue<T>.Close` wakes already-blocked `EnqueueTimeout` / `DequeueTimeout` calls so a closed queue stops waiting promptly instead of sleeping until the full timeout.',
    'lockfree README must document the SPSC close wake contract for blocked timeout waits');
  CheckContains(LDocsReadme,
    '`TSpscQueue<T>.Close` wakes already-blocked `EnqueueWait` / `DequeueWait` calls so a closed queue stops waiting even without a timeout.',
    'lockfree README must document the SPSC close wake contract for blocked wait calls');
  CheckContains(LDocsReadme,
    '`TMpmcQueue<T>.Close` wakes already-blocked `EnqueueTimeout` / `DequeueTimeout` calls so blocked producers and consumers stop waiting promptly instead of sleeping until the full timeout.',
    'lockfree README must document the MPMC close wake contract for blocked timeout waits');
  CheckContains(LDocsReadme,
    '`Close` is not a lifetime barrier: callers must keep the queue object alive until all producer and consumer calls have returned, then join/quiesce those threads before `Free`.',
    'lockfree README must document that Close is not a lifetime or destroy barrier');
  CheckContains(LDocsReadme,
    '`TMpmcQueue<T>.Close` wakes already-blocked `EnqueueWait` / `DequeueWait` calls so blocked producers and consumers stop waiting even without a timeout.',
    'lockfree README must document the MPMC close wake contract for blocked wait calls');
  CheckContains(LDocsReadme,
    '`TMpscQueue<T>.Close` wakes already-blocked `DequeueTimeout` consumers so a closed-empty queue stops waiting promptly.',
    'lockfree README must document the MPSC close wake contract for blocked timeout waits');
  CheckContains(LDocsReadme,
    '`TMpscQueue<T>.Close` wakes already-blocked `DequeueWait` consumers so a closed-empty queue stops waiting even without a timeout.',
    'lockfree README must document the MPSC close wake contract for blocked wait calls');
  CheckContains(LDocsReadme,
    '`TSpscQueue<T>`, `TMpmcQueue<T>`, `TMpscQueue<T>`, `TLockFreeStack<T>`, and `TWorkStealingDeque<T>` reject managed element types at construction time with `EArgumentError`.',
    'lockfree README must document constructor-time managed-type rejection for every public structure');
  CheckContains(LDocsReadme,
    'debug build 中 `TMpscQueue.Destroy` 保留 close-before-destroy 和 drained-before-destroy assert，用来冻结这条纪律。',
    'lockfree README must document the DEBUG close-and-drain destroy asserts');
  CheckContains(LDocsReadme,
    '`TLockFreeStack<T>` permits multiple concurrent `TryPush` / `TryPop` callers over its fixed slot pool; capacity bounds and unmanaged element restrictions still apply.',
    'lockfree README must document the stack caller-role contract');
  CheckContains(LDocsReadme,
    '`TWorkStealingDeque<T>` permits exactly one owner thread for `TryPush` / `TryPop` and multiple thief threads for `TrySteal`; owner methods are not multi-owner safe.',
    'lockfree README must document the deque caller-role contract');
  CheckContains(LDocsReadme, 'Linearization points',
    'lockfree README must name linearization points');
  CheckContains(LDocsReadme, 'ABA',
    'lockfree README must document ABA boundaries');
  CheckContains(LDocsReadme, 'Memory reclamation',
    'lockfree README must document reclamation policy');
  CheckContains(LDocsReadme, 'Close/Destroy discipline',
    'lockfree README must document close and destroy discipline');
  CheckContains(LDocsReadme,
    '`TLockFreeStack<T>` capacity is limited to `High(Int32)` because tagged heads pack a 32-bit slot index',
    'lockfree README must document stack 32-bit slot index capacity limit');
  CheckContains(LDocsReadme,
    '`TLockFreeStack<T>` is a fixed-capacity stack: `TryPush` returns `False` when no free slot remains, and `IsEmpty` / `ApproxCount` are snapshot helpers over the current top-linked list rather than linearization guarantees under contention.',
    'lockfree README must document the stack query surface contract');
  CheckContains(LDocsReadme,
    '`TWorkStealingDeque<T>` rounds requested capacity up to power-of-two storage; `Capacity` returns that live ring bound, `TryPush` returns `False` when the deque is full, and `ApproxCount` / `IsEmpty` are snapshot helpers over current top/bottom counters rather than multi-thread linearization guarantees.',
    'lockfree README must document the deque query surface contract');
  CheckContains(LDocsReadme, 'Atomic dependency',
    'lockfree README must document dependency on atomic wait/notify');
  CheckContains(LDocsReadme,
    'Pointer-sized `atomic_load` / `atomic_store` / `atomic_exchange` for `TMpscQueue<T>` node links',
    'lockfree README must document pointer-sized MPSC node atomic dependency');
  CheckContains(LDocsReadme,
    'node pointers must not be widened through legacy `AtomicLoad64` / `AtomicStore64` / `AtomicExchange64` casts',
    'lockfree README must reject legacy 64-bit pointer casts for MPSC node links');
  CheckContains(LDocsReadme,
    'make -C core/tests/nextpas.core.lockfree/test_lockfree clean test',
    'lockfree README must list the focused lockfree gate');
  CheckContains(LDocsReadme,
    'make -C core/tests/nextpas.core.lockfree/test_lockfree clean test-debug',
    'lockfree README must list the DEBUG close-before-destroy gate');
  CheckContains(LDocsReadme,
    'make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test',
    'lockfree README must list the lockfree stress gate');
  CheckContains(LDocsReadme, 'source-contract',
    'lockfree README must distinguish source-contract coverage from runtime proof');
  CheckContains(LDocsReadme,
    'MPMC producer-published data (`DequeueTimeout`)',
    'lockfree README must document the local MPMC publish timeout runtime evidence');
  CheckContains(LDocsReadme,
    'MPMC consumer-released space (`EnqueueTimeout`)',
    'lockfree README must document the local MPMC space-release timeout runtime evidence');
  CheckContains(LDocsReadme,
    'MPSC producer-published data (`DequeueTimeout`)',
    'lockfree README must document the local MPSC publish timeout runtime evidence');
  CheckContains(LDocsReadme,
    'make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree clean run',
    'lockfree README must list the focused benchmark command');
  CheckContains(LDocsReadme,
    'make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree run-rust-compare',
    'lockfree README must route the Rust baseline through the benchmark Makefile');
  CheckContains(LDocsReadme,
    'make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree run-go-compare',
    'lockfree README must route the Go baseline through the benchmark Makefile');
  CheckContains(LDocsReadme,
    'make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree run-cpp-compare',
    'lockfree README must route the C++ baseline through the benchmark Makefile');
  CheckContains(LDocsReadme,
    'make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree compare',
    'lockfree README must list the all-baseline benchmark Makefile entrypoint');
  CheckContains(LDocsReadme,
    'core/benchmarks/nextpas.core.lockfree/bench_lockfree/bench_lockfree.lpr',
    'lockfree README must point to the Pascal benchmark source');
  CheckContains(LDocsReadme, 'compare_rust/main.rs',
    'lockfree README must point to the external Rust comparison source');
  CheckContains(LDocsReadme, 'compare_go/main.go',
    'lockfree README must point to the external Go comparison source');
  CheckContains(LDocsReadme, 'compare_cpp/main.cpp',
    'lockfree README must point to the external C++ comparison source');
  CheckContains(LDocsReadme,
    '这些 target 最终会在 `core/build/projects/nextpas.core.lockfree/bench_lockfree/...` 下产出并运行：',
    'lockfree README must document the compare target output location');
  CheckContains(LDocsReadme,
    'Rust：`rustc -C opt-level=3 compare_rust/main.rs -o $(RUST_COMPARE_BIN)`',
    'lockfree README must document the Rust compare build command behind the Makefile target');
  CheckContains(LDocsReadme,
    'Go：`go build -o $(GO_COMPARE_BIN) compare_go/main.go`',
    'lockfree README must document the Go compare build command behind the Makefile target');
  CheckContains(LDocsReadme,
    'C++：`g++ -std=c++17 -O2 -pthread compare_cpp/main.cpp -o $(CPP_COMPARE_BIN)`',
    'lockfree README must document the C++ compare build command behind the Makefile target');
  CheckContains(LDocsReadme,
    'Rust std nearest equivalents: `std::sync::mpsc` for 1P+1C, `Mutex + Condvar + VecDeque` for bounded 2P+2C approximation, and `Mutex<VecDeque>` for the 1T baseline.',
    'lockfree README must describe the manual Rust comparison source approximations');
  CheckContains(LDocsReadme,
    'Go std nearest equivalents: buffered `chan uint64` for 1P+1C and 2P+2C, and same-goroutine buffered channel send/receive for the 1T baseline.',
    'lockfree README must describe the manual Go comparison source approximations');
  CheckContains(LDocsReadme,
    'C++ std nearest equivalents: `std::queue<uint64_t>` guarded by `std::mutex` and `std::condition_variable` for bounded 1P+1C and 2P+2C, and the same guarded queue for the 1T baseline.',
    'lockfree README must describe the manual C++ comparison source approximations');
  CheckContains(LDocsReadme, 'platform/compiler flags/input size/baseline',
    'lockfree README must name the benchmark evidence envelope');
  CheckContains(LDocsReadme,
    'benchmark keeps consumed values in a printed sink to reduce optimizer-elision risk',
    'lockfree README must document the benchmark sink keepalive contract');
  CheckContains(LDocsReadme,
    'Pascal benchmark hot paths should not add extra per-item progress atomics that Rust/Go/C++ comparison sources do not pay; keep only scenario-result sink accumulation and synchronization required by the queue contract itself.',
    'lockfree README must document the no-extra-progress-atomics benchmark contract');
  CheckContains(LDocsReadme,
    'External Rust/Go/C++ comparison sources should follow the same consumed-value sink discipline.',
    'lockfree README must document the external comparison sink contract');
  CheckContains(LDocsReadme,
    'External Rust/Go/C++ comparison sources should follow the same logical input ranges as the Pascal benchmark: SPSC/mutex/1T use 1..OPS, and bounded MPMC uses two producers each sending 1..OPS div 2.',
    'lockfree README must document the external comparison input-range contract');
  CheckNotContains(LDocsReadme, '当前模块还缺少正式 benchmark harness',
    'lockfree README must not say the benchmark harness is missing when it exists');

  CheckContains(LSpscSource, 'if IsManagedType(T) then',
    'SPSC queue must reject managed element types');
  CheckContains(LSpscSource, 'LockFreeNotifyData(@FDataEpoch, @FDataWaiters)',
    'SPSC queue must notify data waiters after publish');
  CheckContains(LSpscSource, 'LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters)',
    'SPSC queue must notify space waiters after consume');
  CheckContains(LSpscPublishWakeTestSection,
    'SPSC DequeueTimeout consumer should still be pending before publish',
    'SPSC publish wake runtime test must prove the consumer is pending before publish');
  CheckContains(LSpscPublishWakeTestSection,
    'SPSC DequeueTimeout consumer must wake on data publish before the full timeout',
    'SPSC publish wake runtime test must bound data-wake latency');
  CheckContains(LSpscSpaceWakeTestSection,
    'SPSC EnqueueTimeout producer must observe the full queue before space release',
    'SPSC space wake runtime test must prove the producer observed the full queue before release');
  CheckContains(LSpscSpaceWakeTestSection,
    'SPSC EnqueueTimeout producer must not complete before space release',
    'SPSC space wake runtime test must prove the producer does not complete before space release');
  CheckContains(LSpscSpaceWakeTestSection,
    'SPSC consumer must release queue space',
    'SPSC space wake runtime test must release space through TryDequeue');
  CheckContains(LSpscSpaceWakeTestSection,
    'SPSC EnqueueTimeout producer must progress after space release before the full timeout',
    'SPSC space release runtime test must bound producer progress latency');
  CheckContains(LSpscSpaceWakeTestSection,
    'SPSC space-woken producer item must be drainable',
    'SPSC space wake runtime test must prove the woken producer published an item');
  CheckContains(LSpscCloseTestSection, 'TryEnqueue after close rejected',
    'SPSC close behavior test must cover TryEnqueue rejection');
  CheckContains(LSpscCloseTestSection, 'EnqueueWait after close rejected',
    'SPSC close behavior test must cover EnqueueWait rejection');
  CheckContains(LSpscCloseTestSection, 'EnqueueTimeout after close rejected',
    'SPSC close behavior test must cover EnqueueTimeout rejection');
  CheckContains(LSpscCloseWakeTestSection, 'blocked EnqueueTimeout should still be pending before close',
    'SPSC close wake test must prove the producer-side timeout wait is actually blocked before close');
  CheckContains(LSpscCloseWakeTestSection, 'blocked EnqueueTimeout woken by close',
    'SPSC close wake test must prove Close wakes a blocked producer-side timeout wait');
  CheckContains(LSpscCloseWakeTestSection, 'blocked EnqueueTimeout should return promptly after close',
    'SPSC close wake test must bound the blocked producer wake latency');
  CheckContains(LSpscCloseWakeTestSection, 'blocked producer wake must not publish a new item after close',
    'SPSC close wake test must prove the blocked producer wake does not publish a new item');
  CheckContains(LSpscCloseWakeTestSection, 'blocked DequeueTimeout should still be pending before close',
    'SPSC close wake test must prove the consumer-side timeout wait is actually blocked before close');
  CheckContains(LSpscCloseWakeTestSection, 'blocked DequeueTimeout woken by close',
    'SPSC close wake test must prove Close wakes a blocked consumer-side timeout wait');
  CheckContains(LSpscCloseWakeTestSection, 'blocked DequeueTimeout should return promptly after close',
    'SPSC close wake test must bound the blocked consumer wake latency');
  CheckContains(LSpscCloseWakeTestSection, 'blocked consumer wake must leave the closed empty queue empty',
    'SPSC close wake test must prove the closed empty queue stays empty after the blocked consumer returns');
  CheckContains(LSpscCloseWakeTestSection, 'blocked EnqueueWait should still be pending before close',
    'SPSC close wait test must prove the producer-side wait is actually blocked before close');
  CheckContains(LSpscCloseWakeTestSection, 'blocked EnqueueWait woken by close',
    'SPSC close wait test must prove Close wakes a blocked producer-side wait');
  CheckContains(LSpscCloseWakeTestSection, 'blocked EnqueueWait should return promptly after close',
    'SPSC close wait test must bound the blocked producer wait wake latency');
  CheckContains(LSpscCloseWakeTestSection, 'blocked EnqueueWait wake must not publish a new item after close',
    'SPSC close wait test must prove the blocked producer wait wake does not publish a new item');
  CheckContains(LSpscCloseWakeTestSection, 'blocked DequeueWait should still be pending before close',
    'SPSC close wait test must prove the consumer-side wait is actually blocked before close');
  CheckContains(LSpscCloseWakeTestSection, 'blocked DequeueWait woken by close',
    'SPSC close wait test must prove Close wakes a blocked consumer-side wait');
  CheckContains(LSpscCloseWakeTestSection, 'blocked DequeueWait should return promptly after close',
    'SPSC close wait test must bound the blocked consumer wait wake latency');
  CheckContains(LSpscCloseWakeTestSection, 'blocked DequeueWait wake must leave the closed empty queue empty',
    'SPSC close wait test must prove the closed empty queue stays empty after the blocked consumer wait returns');
  CheckContains(LSpscBatchSourceSection, 'if AtomicLoad32(FClosed, moAcquire) <> 0 then',
    'SPSC batch enqueue must reject new items after close');
  CheckContains(LSpscBatchSourceSection, 'FHeadCache := AtomicLoad64(FHeadPublished, moAcquire);',
    'SPSC batch enqueue must refresh published head before sizing batch progress');
  CheckContains(LSpscBatchSourceSection, 'if LCount > PtrUInt(LAvail) then',
    'SPSC batch enqueue must cap published items to currently available space');
  CheckContains(LSpscDequeueBatchSourceSection, 'FTailCache := AtomicLoad64(FTailPublished, moAcquire);',
    'SPSC batch dequeue must refresh published tail before sizing batch progress');
  CheckContains(LSpscDequeueBatchSourceSection, 'if LCount > PtrUInt(LAvail) then',
    'SPSC batch dequeue must cap returned items to currently available data');
  CheckContains(LSpscDequeueBatchSourceSection, 'if LCount > PtrUInt(Length(AValues)) then',
    'SPSC batch dequeue must cap returned items to the caller buffer length');
  CheckContains(LSpscBatchTestSection, 'batch enqueue after close rejected',
    'SPSC batch behavior test must cover close rejection');
  CheckContains(LSpscBatchTestSection, 'partial batch enqueue publishes only currently available slots',
    'SPSC batch behavior test must cover partial enqueue under limited space');
  CheckContains(LSpscBatchTestSection, 'partial batch dequeue is capped by output buffer length',
    'SPSC batch behavior test must cover output-buffer-limited dequeue progress');
  CheckContains(LSpscBatchTestSection, 'partial batch test seeds producer cache after partial drain',
    'SPSC batch behavior test must exercise producer-side stale-cache refill progress');
  CheckContains(LSpscBatchTestSection, 'partial batch refill uses all currently available slots',
    'SPSC batch behavior test must cover refill progress against the live free-space bound');
  CheckContains(LSpscBatchTestSection, 'partial batch dequeue drains all currently available items',
    'SPSC batch behavior test must cover available-data-limited dequeue progress');
  CheckContains(LMpmcSource, 'class function EmptySequence(const APos: Int64): Int64; static; inline;',
    'MPMC queue must define the empty-state slot sequence helper');
  CheckContains(LMpmcSource, 'class function FullSequence(const APos: Int64): Int64; static; inline;',
    'MPMC queue must define the full-state slot sequence helper');
  CheckNotContains(LMpmcSource, 'function MpmcEmptySequence',
    'MPMC sequence helpers must stay private to the generic implementation class');
  CheckContains(LMpmcSource, 'FSlots[LI].Sequence := EmptySequence(Int64(LI));',
    'MPMC queue must initialize slot sequence tokens with empty-state encoding');
  CheckContains(LMpmcSource, 'LExpected := EmptySequence(LPos);',
    'MPMC enqueue must compare against the empty-state token for the target position');
  CheckContains(LMpmcSource, 'AtomicStore64(FSlots[LIdx].Sequence, FullSequence(LPos), moRelease)',
    'MPMC enqueue linearization must publish slot sequence with release ordering');
  CheckContains(LMpmcSource, 'FActiveEnqueues: Int32;',
    'MPMC queue must track admitted producer operations that may still publish after Close');
  CheckContains(LMpmcSource, 'function ClosedAndNoActiveEnqueues: Boolean; inline;',
    'MPMC queue must centralize closed-empty terminal checks behind active producer tracking');
  CheckContains(LMpmcSource, 'procedure LeaveActiveEnqueue; inline;',
    'MPMC queue must centralize active producer decrement and wake handling');
  CheckContains(LMpmcTryEnqueueSourceSection, 'AtomicFetchAdd32(FActiveEnqueues, 1, moAcqRel);',
    'MPMC TryEnqueue must admit active producers before any slot reservation can happen');
  CheckBefore(LMpmcTryEnqueueSourceSection,
    'AtomicFetchAdd32(FActiveEnqueues, 1, moAcqRel);',
    'if AtomicLoad32(FClosed, moAcquire) <> 0 then',
    'MPMC TryEnqueue must admit active producers before the first Close observation');
  CheckContains(LMpmcTryEnqueueSourceSection, 'LeaveActiveEnqueue;',
    'MPMC TryEnqueue must decrement active producer tracking on every exit path');
  CheckContains(LMpmcTryEnqueueSourceSection, 'if AtomicLoad32(FClosed, moAcquire) <> 0 then' + LineEnding + '      Exit(False);',
    'MPMC TryEnqueue must re-check Close after admission but before reserving a slot');
  CheckContains(LMpmcLeaveActiveSourceSection, 'AtomicFetchSub32(FActiveEnqueues, 1, moAcqRel) = 1',
    'MPMC active producer tracking must decrement with acquire-release ordering');
  CheckContains(LMpmcLeaveActiveSourceSection, 'LockFreeWakeAll(@FDataEpoch);',
    'MPMC active producer completion must wake all closed consumers waiting for terminal closed-empty');
  CheckContains(LMpmcDequeueWaitSourceSection, 'ClosedAndNoActiveEnqueues',
    'MPMC DequeueWait must not return closed-empty while an admitted producer may still publish');
  CheckContains(LMpmcDequeueWaitSourceSection,
    'if ClosedAndNoActiveEnqueues then' + LineEnding + '    begin' + LineEnding + '      if TryDequeue(AValue) then',
    'MPMC DequeueWait must prove the queue is still empty after observing no active producers');
  CheckContains(LMpmcDequeueTimeoutSourceSection, 'ClosedAndNoActiveEnqueues',
    'MPMC DequeueTimeout must not return closed-empty early before timeout while an admitted producer may still publish');
  CheckContains(LMpmcDequeueTimeoutSourceSection,
    'if ClosedAndNoActiveEnqueues then' + LineEnding + '    begin' + LineEnding + '      if TryDequeue(AValue) then',
    'MPMC DequeueTimeout must prove the queue is still empty after observing no active producers');
  CheckContains(LMpmcSource, 'LExpected := FullSequence(LPos);',
    'MPMC dequeue must compare against the full-state token for the target position');
  CheckContains(LMpmcSource, 'AtomicStore64(FSlots[LIdx].Sequence, EmptySequence(LPos + Int64(FCapacity)), moRelease)',
    'MPMC dequeue must recycle slot sequence with release ordering');
  CheckContains(LMpmcSingleSlotTestSection, 'TIntMpmc.Create(1);',
    'MPMC single-slot test must construct a single-slot queue');
  CheckContains(LMpmcSingleSlotTestSection, 'single-slot capacity',
    'MPMC single-slot test must cover the public capacity surface');
  CheckContains(LMpmcSingleSlotTestSection, 'single-slot count after enqueue',
    'MPMC single-slot test must cover ApproxCount after publishing one item');
  CheckContains(LMpmcSingleSlotTestSection, 'single-slot full after enqueue',
    'MPMC single-slot test must cover IsFull after publishing one item');
  CheckContains(LMpmcSingleSlotTestSection, 'single-slot enqueue after recycle',
    'MPMC single-slot test must prove the slot recycles after a dequeue');
  CheckContains(LMpmcSingleSlotTestSection, 'single-slot enqueue timeout on full',
    'MPMC single-slot test must cover EnqueueTimeout on a full single-slot queue');
  CheckContains(LMpmcSingleSlotTestSection, 'single-slot dequeue timeout on empty',
    'MPMC single-slot test must cover DequeueTimeout on an empty single-slot queue');
  CheckContains(LMpmcSingleSlotTestSection, 'single-slot batch enqueue only published one item',
    'MPMC single-slot test must cover EnqueueBatch on a single-slot queue');
  CheckContains(LMpmcSingleSlotTestSection, 'single-slot batch dequeue only returned one item',
    'MPMC single-slot test must cover DequeueBatch on a single-slot queue');
  CheckContains(LStressTestSource,
    'T.Run(''MPMC single-slot 2P+2C exactly-once'', @TestMpmcSingleSlotContention);',
    'MPMC stress suite must run the single-slot contention test');
  CheckContains(LTestSource, 'function StartThread(',
    'lockfree behavior tests must wrap platform_thread_create with return-value checks');
  CheckContains(LTestSource, 'procedure JoinThread(',
    'lockfree behavior tests must wrap platform_thread_join with return-value checks');
  CheckContains(LStressTestSource, 'function StartThread(',
    'lockfree stress tests must wrap platform_thread_create with return-value checks');
  CheckContains(LStressTestSource, 'procedure JoinThread(',
    'lockfree stress tests must wrap platform_thread_join with return-value checks');
  CheckContains(LTestSource, 'procedure JoinStartedThread(',
    'lockfree behavior tests must join started threads from failure cleanup paths');
  CheckContains(LTestSource, 'procedure JoinStartedThreads(',
    'lockfree behavior tests must join started thread arrays from failure cleanup paths');
  CheckContains(LStressTestSource, 'procedure JoinStartedThreads(',
    'lockfree stress tests must join started thread arrays from failure cleanup paths');
  CheckEqual(Int64(1), Int64(CountOccurrences(LTestRuntimeHarnessSourceSection, 'platform_thread_create(')),
    'lockfree behavior tests must call platform_thread_create only through StartThread');
  CheckEqual(Int64(1), Int64(CountOccurrences(LTestRuntimeHarnessSourceSection, 'platform_thread_join(')),
    'lockfree behavior tests must call platform_thread_join only through JoinThread');
  CheckEqual(Int64(1), Int64(CountOccurrences(LStressRuntimeHarnessSourceSection, 'platform_thread_create(')),
    'lockfree stress tests must call platform_thread_create only through StartThread');
  CheckEqual(Int64(1), Int64(CountOccurrences(LStressRuntimeHarnessSourceSection, 'platform_thread_join(')),
    'lockfree stress tests must call platform_thread_join only through JoinThread');
  CheckContains(LMpmcSingleSlotStressSection, 'TIntMpmc.Create(1);',
    'MPMC stress test must construct a single-slot queue');
  CheckContains(LMpmcSingleSlotStressSection, 'GMpmcSingleSlotOutOfRangeCount',
    'MPMC stress test must count out-of-range single-slot messages defensively');
  CheckContains(LMpmcSingleSlotStressSection, 'single-slot contention no out-of-range messages',
    'MPMC stress test must prove single-slot contention has no out-of-range messages');
  CheckContains(LMpmcSingleSlotStressSection, 'single-slot contention no missing messages',
    'MPMC stress test must prove single-slot contention has no missing messages');
  CheckContains(LMpmcSingleSlotStressSection, 'single-slot contention no duplicate messages',
    'MPMC stress test must prove single-slot contention has no duplicate messages');
  CheckContains(LStackABAStressSection, 'GStackABASeen',
    'Stack ABA stress must track every pushed token for exactly-once ownership');
  CheckContains(LStackABAStressSection, 'GStackABAOutOfRange',
    'Stack ABA stress must count out-of-range popped tokens defensively');
  CheckContains(LStackABAStressSection, 'stack ABA no missing tokens',
    'Stack ABA stress must prove no pushed token is lost');
  CheckContains(LStackABAStressSection, 'stack ABA no duplicate tokens',
    'Stack ABA stress must prove no pushed token is popped more than once');
  CheckContains(LStackABAStressSection, 'stack ABA no out-of-range tokens',
    'Stack ABA stress must prove popped tokens are within the pushed-token domain');
  CheckNotContains(LMpmcSource, 'TMpmcQueue: capacity must be >= 2',
    'MPMC queue must not reject requested capacity 1 once single-slot support is implemented');
  CheckContains(LMpmcCloseTestSection, 'TryEnqueue after close rejected',
    'MPMC close behavior test must cover TryEnqueue rejection');
  CheckContains(LMpmcCloseTestSection, 'EnqueueWait after close rejected',
    'MPMC close behavior test must cover EnqueueWait rejection');
  CheckContains(LMpmcCloseTestSection, 'EnqueueTimeout after close rejected',
    'MPMC close behavior test must cover EnqueueTimeout rejection');
  CheckContains(LMpmcCloseTestSection, 'blocked EnqueueTimeout should still be pending before close',
    'MPMC close behavior test must prove the producer-side timeout wait is actually blocked before close');
  CheckContains(LMpmcCloseTestSection, 'blocked EnqueueTimeout woken by close',
    'MPMC close behavior test must prove Close wakes a blocked producer-side timeout wait');
  CheckContains(LMpmcCloseTestSection, 'blocked EnqueueTimeout should return promptly after close',
    'MPMC close behavior test must bound the blocked producer wake latency');
  CheckContains(LMpmcCloseTestSection, 'blocked producer wake must not publish extra item after close',
    'MPMC close behavior test must prove the blocked producer wake does not publish a new item');
  CheckContains(LMpmcCloseTestSection, 'blocked DequeueTimeout should still be pending before close',
    'MPMC close behavior test must prove the consumer-side timeout wait is actually blocked before close');
  CheckContains(LMpmcCloseTestSection, 'blocked DequeueTimeout woken by close',
    'MPMC close behavior test must prove Close wakes a blocked consumer-side timeout wait');
  CheckContains(LMpmcCloseTestSection, 'blocked DequeueTimeout should return promptly after close',
    'MPMC close behavior test must bound the blocked consumer wake latency');
  CheckContains(LMpmcCloseTestSection, 'blocked consumer wake must leave the closed empty queue empty',
    'MPMC close behavior test must prove the blocked consumer wake leaves the closed empty queue empty');
  CheckContains(LMpmcCloseTestSection, 'TIntMpmc.Create(1);',
    'MPMC close behavior test must cover the single-slot blocked producer wake path');
  CheckContains(LMpmcCloseWakeWaitTestSection, 'blocked MPMC EnqueueWait should still be pending before close',
    'MPMC close wait test must prove the producer-side wait is actually blocked before close');
  CheckContains(LMpmcCloseWakeWaitTestSection, 'blocked MPMC EnqueueWait woken by close',
    'MPMC close wait test must prove Close wakes a blocked producer-side wait');
  CheckContains(LMpmcCloseWakeWaitTestSection, 'blocked MPMC EnqueueWait should return promptly after close',
    'MPMC close wait test must bound the blocked producer wait wake latency');
  CheckContains(LMpmcCloseWakeWaitTestSection, 'blocked MPMC EnqueueWait wake must not publish extra item after close',
    'MPMC close wait test must prove the blocked producer wait wake does not publish an extra item');
  CheckContains(LMpmcCloseWakeWaitTestSection, 'blocked MPMC DequeueWait should still be pending before close',
    'MPMC close wait test must prove the consumer-side wait is actually blocked before close');
  CheckContains(LMpmcCloseWakeWaitTestSection, 'blocked MPMC DequeueWait woken by close',
    'MPMC close wait test must prove Close wakes a blocked consumer-side wait');
  CheckContains(LMpmcCloseWakeWaitTestSection, 'blocked MPMC DequeueWait should return promptly after close',
    'MPMC close wait test must bound the blocked consumer wait wake latency');
  CheckContains(LMpmcCloseWakeWaitTestSection, 'blocked MPMC DequeueWait wake must leave the closed empty queue empty',
    'MPMC close wait test must prove the blocked consumer wait wake leaves the closed empty queue empty');
  CheckContains(LMpmcPublishWakeTestSection,
    'MPMC DequeueTimeout consumer must observe the empty queue before publish',
    'MPMC publish wake runtime test must prove the consumer observed an empty queue before publish');
  CheckContains(LMpmcPublishWakeTestSection,
    'MPMC DequeueTimeout consumer should still be pending before publish',
    'MPMC publish wake runtime test must prove the consumer is pending before publish');
  CheckContains(LMpmcPublishWakeTestSection,
    'MPMC producer must publish the wake item',
    'MPMC publish wake runtime test must publish through TryEnqueue');
  CheckContains(LMpmcPublishWakeTestSection,
    'MPMC DequeueTimeout consumer must progress after data publish before the full timeout',
    'MPMC publish wake runtime test must bound consumer progress latency');
  CheckContains(LTestSource,
    'T.Run(''MPMC timeout wakes on publish'', @TestMpmcDequeueTimeoutWakesOnPublish);',
    'lockfree test runner must register the MPMC publish wake runtime test');
  CheckContains(LMpmcSpaceWakeTestSection,
    'MPMC EnqueueTimeout producer must observe the full queue before space release',
    'MPMC space wake runtime test must prove the producer observed a full queue before release');
  CheckContains(LMpmcSpaceWakeTestSection,
    'MPMC EnqueueTimeout producer must not complete before space release',
    'MPMC space wake runtime test must prove the producer is pending before release');
  CheckContains(LMpmcSpaceWakeTestSection,
    'MPMC consumer must release queue space',
    'MPMC space wake runtime test must release space through TryDequeue');
  CheckContains(LMpmcSpaceWakeTestSection,
    'MPMC EnqueueTimeout producer must progress after space release before the full timeout',
    'MPMC space wake runtime test must bound producer progress latency');
  CheckContains(LMpmcSpaceWakeTestSection,
    'MPMC space-woken producer item must be drainable',
    'MPMC space wake runtime test must prove the woken producer published an item');
  CheckContains(LTestSource,
    'T.Run(''MPMC timeout wakes on space release'', @TestMpmcEnqueueTimeoutWakesOnSpace);',
    'lockfree test runner must register the MPMC space wake runtime test');
  CheckContains(LMpmcBatchSourceSection, 'if AtomicLoad32(FClosed, moAcquire) <> 0 then',
    'MPMC batch enqueue must reject new items after close');
  CheckContains(LMpmcBatchTestSection, 'mpmc batch enqueue after close rejected',
    'MPMC batch behavior test must cover close rejection');
  CheckContains(LMpmcBatchTestSection, 'mpmc batch dequeue drains already-published items after close',
    'MPMC batch behavior test must cover batch drain after close');
  CheckContains(LMpmcBatchTestSection, 'mpmc partial batch enqueue publishes only currently available slots',
    'MPMC batch behavior test must cover partial enqueue under limited space');
  CheckContains(LMpmcBatchTestSection, 'mpmc partial batch dequeue is capped by output buffer length',
    'MPMC batch behavior test must cover output-buffer-limited dequeue progress');
  CheckContains(LMpmcBatchTestSection, 'mpmc partial batch refill uses all currently available slots',
    'MPMC batch behavior test must cover refill progress against the live free-space bound');
  CheckContains(LMpmcBatchTestSection, 'mpmc partial batch dequeue drains all currently available items',
    'MPMC batch behavior test must cover available-data-limited dequeue progress');
  CheckContains(LStressTestSource,
    'T.Run(''MPMC close races active producers'', @TestMpmcCloseRacesActiveProducers);',
    'MPMC stress suite must run active-producer close race coverage');
  CheckContains(LStressTestSource,
    'T.Run(''MPMC close races active producers timeout'', @TestMpmcCloseRacesActiveProducersTimeout);',
    'MPMC stress suite must run active-producer close race timeout coverage');
  CheckContains(LMpmcActiveCloseStressSection, 'GMpmcCloseRaceQ.Close;',
    'MPMC active-producer close stress must close while producers are still live');
  CheckContains(LStressTestSource, 'function MpmcCloseRaceTimeoutConsumer',
    'MPMC active-producer close stress must include a DequeueTimeout consumer variant');
  CheckContains(LStressTestSource, 'GMpmcCloseRaceQ.DequeueTimeout',
    'MPMC active-producer close timeout stress must exercise DequeueTimeout terminal checks');
  CheckContains(LMpmcActiveCloseStressSection, 'close race leaves no drainable items after consumers exit',
    'MPMC active-producer close stress must prove consumers do not exit before admitted items are drained');
  CheckContains(LMpmcActiveCloseStressSection, 'close race timeout leaves no drainable items after consumers exit',
    'MPMC active-producer close timeout stress must prove consumers do not exit before admitted items are drained');
  CheckContains(LStackSource, 'FFreeHead: Int64',
    'stack must keep a tagged free-list head');
  CheckContains(LStackSource, 'function PackTagIdx',
    'stack must keep tag/index packing helper for ABA resistance');
  CheckContains(LStackSource, 'FSlots[LIdx].Value := Default(T)',
    'stack pop must clear the slot before returning it to the free list');
  CheckContains(LStackSource, 'if ACapacity > PtrUInt(High(Int32)) then',
    'stack constructor must reject capacity beyond its 32-bit slot index');
  CheckContains(LStackSource, 'TLockFreeStack: capacity exceeds 32-bit slot index limit',
    'stack constructor must expose a stable argument error for capacity overflow');
  CheckContains(LStackSource, 'if LCount > FCapacity then Break;',
    'stack ApproxCount must keep traversal best-effort instead of trusting an unbounded chain');
  CheckContains(LDequeSource, 'LCap := LockFreeNextPow2(ACapacity);',
    'deque constructor must round requested capacity to power-of-two storage');
  CheckContains(LDequeSource, 'if LSize >= Int64(FCapacity) then',
    'deque owner push must reject writes once the bounded ring is full');
  CheckContains(LMpscSource, 'Assert(FClosed <> 0',
    'MPSC destroy must keep the close-before-destroy debug guard');
  CheckContains(LMpscSource, 'Close must be called before Destroy',
    'MPSC destroy guard must document the close-before-destroy discipline');
  CheckContains(LMpscSource, 'Assert(IsEmpty',
    'MPSC destroy must keep the drained-before-destroy debug guard');
  CheckContains(LMpscSource, 'queue must be drained before Destroy after Close',
    'MPSC destroy guard must document the drain-before-destroy discipline');
  CheckContains(LMpscBasicTestSection, 'LQ.Close;' + LineEnding + '  LQ.Free;',
    'MPSC basic test must close before freeing the queue');
  CheckContains(LMpscCloseProducerTestSection,
    'Check(LQ.IsClosed, ''closed'');',
    'MPSC close producer contract test must assert closed state first');
  CheckContains(LMpscCloseProducerTestSection, 'LQ.Enqueue(42);',
    'MPSC close producer contract test must enqueue after close');
  CheckContains(LMpscCloseProducerTestSection,
    'Check(LQ.TryDequeue(LV), ''MPSC enqueue after close still drains'');',
    'MPSC close producer contract test must drain the close-published item');
  CheckContains(LMpscCloseProducerTestSection,
    'Check(not LQ.DequeueWait(LV), ''dequeue wait false on closed empty MPSC'');',
    'MPSC close producer contract test must freeze closed-empty wait termination');
  CheckContains(LMpscCloseProducerTestSection,
    'Check(not LQ.DequeueTimeout(LV, 1000000), ''dequeue timeout false on closed empty MPSC'');',
    'MPSC close producer contract test must freeze closed-empty timeout termination');
  CheckContains(LMpscCloseWakeTestSection, 'blocked MPSC DequeueTimeout should still be pending before close',
    'MPSC close wake test must prove the consumer-side timeout wait is actually blocked before close');
  CheckContains(LMpscCloseWakeTestSection, 'blocked MPSC DequeueTimeout woken by close',
    'MPSC close wake test must prove Close wakes the blocked MPSC consumer timeout wait');
  CheckContains(LMpscCloseWakeTestSection, 'blocked MPSC DequeueTimeout should return promptly after close',
    'MPSC close wake test must bound the blocked MPSC consumer wake latency');
  CheckContains(LMpscCloseWakeTestSection, 'blocked MPSC consumer wake must leave the closed empty queue empty',
    'MPSC close wake test must prove the closed empty MPSC queue stays empty after the blocked consumer returns');
  CheckContains(LMpscCloseWakeWaitTestSection, 'blocked MPSC DequeueWait should still be pending before close',
    'MPSC close wait test must prove the consumer-side wait is actually blocked before close');
  CheckContains(LMpscCloseWakeWaitTestSection, 'blocked MPSC DequeueWait woken by close',
    'MPSC close wait test must prove Close wakes the blocked MPSC consumer wait');
  CheckContains(LMpscCloseWakeWaitTestSection, 'blocked MPSC DequeueWait should return promptly after close',
    'MPSC close wait test must bound the blocked MPSC consumer wait wake latency');
  CheckContains(LMpscCloseWakeWaitTestSection, 'blocked MPSC DequeueWait wake must leave the closed empty queue empty',
    'MPSC close wait test must prove the closed empty MPSC queue stays empty after the blocked consumer wait returns');
  CheckContains(LMpscDestroyDrainTestSection,
    'Check(LRaised, ''DEBUG MPSC destroy must reject close-without-drain'');',
    'MPSC destroy drain contract test must reject freeing a closed but undrained queue in DEBUG builds');
  CheckContains(LMpscDestroyDrainTestSection,
    'Check(LQ.TryDequeue(LV), ''drain queued MPSC item before destroy'');',
    'MPSC destroy drain contract test must drain queued items before the final free');
  CheckContains(LMpscMultiProducerTestSection, 'JoinStartedThreads(LHandles, LHandleCount, ''worker thread'');',
    'MPSC multi-producer test must join every started producer in cleanup paths');
  CheckContains(LMpscMultiProducerTestSection,
    'finally' + LineEnding + '    JoinStartedThreads(LHandles, LHandleCount, ''worker thread'');' + LineEnding + '    GMpscQ.Close;' + LineEnding + '    GMpscQ.Free;',
    'MPSC multi-producer test must close after producers stop and before freeing the queue');
  CheckContains(LMpscPublishWakeTestSection,
    'MPSC DequeueTimeout consumer must observe the empty queue before publish',
    'MPSC publish wake runtime test must prove the consumer observed an empty queue before publish');
  CheckContains(LMpscPublishWakeTestSection,
    'MPSC DequeueTimeout consumer must not complete before publish',
    'MPSC publish wake runtime test must prove the consumer is pending before publish');
  CheckContains(LMpscPublishWakeTestSection,
    'LQ.Enqueue(42);',
    'MPSC publish wake runtime test must publish through Enqueue');
  CheckContains(LMpscPublishWakeTestSection,
    'MPSC DequeueTimeout consumer must progress after data publish before the full timeout',
    'MPSC publish wake runtime test must bound consumer progress latency');
  CheckContains(LMpscPublishWakeTestSection,
    'MPSC DequeueTimeout must receive the producer-published item',
    'MPSC publish wake runtime test must prove the woken consumer received the published item');
  CheckContains(LMpscPublishWakeTestSection, 'LQ.Close;',
    'MPSC publish wake runtime test must close before freeing the queue');
  CheckContains(LMpscPublishWakeTestSection, 'while LQ.TryDequeue(LV) do;',
    'MPSC publish wake runtime test must drain defensively before freeing the queue');
  CheckContains(LMpscPublishWakeTestSection, 'LQ.Free;',
    'MPSC publish wake runtime test must release the queue after close and drain');
  CheckContains(LTestSource,
    'T.Run(''MPSC timeout wakes on publish'', @TestMpscDequeueTimeoutWakesOnPublish);',
    'lockfree test runner must register the MPSC publish wake runtime test');
  CheckContains(LMpscTimeoutTestSection, 'LQ.Close;' + LineEnding + '  LQ.Free;',
    'MPSC timeout test must close before freeing the queue');
  CheckContains(LTestMakefile, '.PHONY: build run test test-debug clean',
    'lockfree test Makefile must expose the DEBUG verification target');
  CheckContains(LTestMakefile, '-dDEBUG',
    'lockfree test DEBUG target must compile with DEBUG defined');
  CheckContains(LTestMakefile, 'test-debug: run-debug',
    'lockfree test Makefile must provide a runnable DEBUG gate');
  CheckContains(LTestMakefile,
    'DEBUG_BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.lockfree/test_lockfree_debug',
    'lockfree test Makefile must isolate DEBUG artifacts in a dedicated build dir');
  CheckContains(LTestMakefile, '$(DEBUG_FPC_FLAGS) -FU$(DEBUG_BUILD_DIR) -FE$(DEBUG_BUILD_DIR)',
    'lockfree test DEBUG target must compile into the dedicated DEBUG build dir');
  CheckContains(LTestMakefile, '$(DEBUG_BUILD_DIR)/$(PROGRAM)',
    'lockfree test DEBUG run target must execute from the dedicated DEBUG build dir');
  CheckContains(LTestMakefile, 'CLEAN_BUILD_DIRS := $(BUILD_DIR) $(DEBUG_BUILD_DIR)',
    'lockfree test clean target must remove both default and DEBUG build dirs by default');
  CheckContains(LTestMakefile, 'CLEAN_BUILD_DIRS := $(BUILD_DIR)',
    'lockfree test clean target must keep the default build dir for non-DEBUG gates');
  CheckContains(LTestMakefile, 'CLEAN_BUILD_DIRS := $(DEBUG_BUILD_DIR)',
    'lockfree test clean target must select the DEBUG build dir when the DEBUG gate is requested');
  CheckContains(LMpscSource,
    'function AtomicLoadNode(var ANode: PNode; const AOrder: memory_order_t): PNode;',
    'MPSC queue must define a pointer-sized atomic node load helper');
  CheckContains(LMpscSource,
    'procedure AtomicStoreNode(var ANode: PNode; const AValue: PNode; const AOrder: memory_order_t);',
    'MPSC queue must define a pointer-sized atomic node store helper');
  CheckContains(LMpscSource,
    'function AtomicExchangeNode(var ANode: PNode; const AValue: PNode; const AOrder: memory_order_t): PNode;',
    'MPSC queue must define a pointer-sized atomic node exchange helper');
  CheckContains(LMpscSource, 'atomic_load(PPointer(@ANode)^, AOrder)',
    'MPSC node load helper must use pointer-sized atomic_load');
  CheckContains(LMpscSource, 'atomic_store(PPointer(@ANode)^, Pointer(AValue), AOrder)',
    'MPSC node store helper must use pointer-sized atomic_store');
  CheckContains(LMpscSource, 'atomic_exchange(PPointer(@ANode)^, Pointer(AValue), AOrder)',
    'MPSC node exchange helper must use pointer-sized atomic_exchange');
  CheckNotContains(LMpscSource, 'AtomicLoad64(Int64(PtrUInt(',
    'MPSC queue must not load pointer links through 64-bit pointer casts');
  CheckNotContains(LMpscSource, 'AtomicStore64(Int64(PtrUInt(',
    'MPSC queue must not store pointer links through 64-bit pointer casts');
  CheckNotContains(LMpscSource, 'AtomicExchange64(Int64(PtrUInt(',
    'MPSC queue must not exchange pointer links through 64-bit pointer casts');
  CheckContains(LDequeSource, 'AtomicCompareExchange64(FTop',
    'work-stealing deque must linearize steals through top CAS');
  CheckContains(LWaitSource, 'platform_wait_address32',
    'lockfree wait helper must use the atomic/platform wait-address seam');
  CheckContains(LWaitSource,
    'procedure LockFreeWaitData(AEpoch: PInt32; AWaiters: PInt32;' + LineEnding +
    '  const AExpectedEpoch: Int32; const ATimeoutNs: Int64);',
    'lockfree data wait helper must receive the caller-observed epoch');
  CheckContains(LWaitSource,
    'procedure LockFreeWaitSpace(AEpoch: PInt32; AWaiters: PInt32;' + LineEnding +
    '  const AExpectedEpoch: Int32; const ATimeoutNs: Int64);',
    'lockfree space wait helper must receive the caller-observed epoch');
  CheckContains(LWaitSource,
    'if AtomicLoad32(AEpoch^, moAcquire) <> AExpectedEpoch then',
    'lockfree wait helper must skip blocking when the epoch already advanced');
  CheckContains(LWaitSource, 'platform_wait_address32(AEpoch, AExpectedEpoch, ATimeoutNs);',
    'lockfree wait helper must wait on the caller-observed epoch');
  CheckContains(LSpscSource, 'LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, -1);',
    'SPSC blocking enqueue must pass the observed space epoch to wait helper');
  CheckContains(LSpscSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, -1);',
    'SPSC blocking dequeue must pass the observed data epoch to wait helper');
  CheckContains(LSpscSource, 'LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LRemaining);',
    'SPSC timeout enqueue must pass the observed space epoch to wait helper');
  CheckContains(LSpscSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);',
    'SPSC timeout dequeue must pass the observed data epoch to wait helper');
  CheckContains(LMpmcSource, 'LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, -1);',
    'MPMC blocking enqueue must pass the observed space epoch to wait helper');
  CheckContains(LMpmcSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, -1);',
    'MPMC blocking dequeue must pass the observed data epoch to wait helper');
  CheckContains(LMpmcSource, 'LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LRemaining);',
    'MPMC timeout enqueue must pass the observed space epoch to wait helper');
  CheckContains(LMpmcSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);',
    'MPMC timeout dequeue must pass the observed data epoch to wait helper');
  CheckContains(LMpscSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, -1);',
    'MPSC blocking dequeue must pass the observed data epoch to wait helper');
  CheckContains(LMpscSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);',
    'MPSC timeout dequeue must pass the observed data epoch to wait helper');
  CheckContains(LWaitSource, 'AtomicFetchAdd32(AWaiters^, 1, moAcqRel)',
    'lockfree wait helper must register waiters before blocking');
  CheckContains(LWaitSource, 'AtomicFetchSub32(AWaiters^, 1, moAcqRel)',
    'lockfree wait helper must unregister waiters after blocking');
  CheckContains(LBenchMakefile,
    '.PHONY: build run build-rust-compare run-rust-compare build-go-compare run-go-compare build-cpp-compare run-cpp-compare compare clean',
    'lockfree benchmark Makefile must expose Pascal and external baseline entrypoints');
  CheckContains(LBenchMakefile, 'RUSTC ?= rustc',
    'lockfree benchmark Makefile must expose the Rust compiler override');
  CheckContains(LBenchMakefile, 'GO ?= go',
    'lockfree benchmark Makefile must expose the Go compiler override');
  CheckContains(LBenchMakefile, 'CXX ?= g++',
    'lockfree benchmark Makefile must expose the C++ compiler override');
  CheckContains(LBenchMakefile, 'run-rust-compare: build-rust-compare',
    'lockfree benchmark Makefile must provide a runnable Rust baseline target');
  CheckContains(LBenchMakefile,
    '$(RUSTC) -C opt-level=3 compare_rust/main.rs -o $(RUST_COMPARE_BIN)',
    'lockfree benchmark Makefile must build the Rust baseline with the documented command');
  CheckContains(LBenchMakefile, 'run-go-compare: build-go-compare',
    'lockfree benchmark Makefile must provide a runnable Go baseline target');
  CheckContains(LBenchMakefile,
    '$(GO) build -o $(GO_COMPARE_BIN) compare_go/main.go',
    'lockfree benchmark Makefile must build the Go baseline with the documented command');
  CheckContains(LBenchMakefile, 'run-cpp-compare: build-cpp-compare',
    'lockfree benchmark Makefile must provide a runnable C++ baseline target');
  CheckContains(LBenchMakefile,
    '$(CXX) -std=c++17 -O2 -pthread compare_cpp/main.cpp -o $(CPP_COMPARE_BIN)',
    'lockfree benchmark Makefile must build the C++ baseline with the documented command');
  CheckContains(LBenchMakefile,
    'compare: run run-rust-compare run-go-compare run-cpp-compare',
    'lockfree benchmark Makefile must provide a single all-baseline compare target');
  CheckContains(LDocsReadme,
    'Wait helpers receive the caller-observed epoch and only block while the epoch is unchanged',
    'lockfree README must document the wait helper lost-wake guard');
  CheckContains(LBenchSource, 'WriteLn(''Platform: '', BenchmarkPlatformName)',
    'lockfree benchmark must print the platform evidence field');
  CheckContains(LBenchSource, 'WriteLn(''Compiler flags: -MObjFPC -Sh -O2'')',
    'lockfree benchmark must print the compiler flags evidence field');
  CheckContains(LBenchSource, 'WriteLn(''Input size: OPS=1000000; capacity=1024; scenarios=SPSC 1P+1C, MPMC 2P+2C, mutex channel baseline, Try* 1T'')',
    'lockfree benchmark must print the input-size evidence field');
  CheckContains(LBenchSource, 'WriteLn(''Baselines: nextpas.core.thread.channel mutex channel; compare_rust/main.rs, compare_go/main.go, and compare_cpp/main.cpp external sources (not auto-run)'')',
    'lockfree benchmark must print the baseline evidence field');
  CheckContains(LBenchSource, 'GBenchSink: Int64;',
    'lockfree benchmark must keep a visible consumed-value sink');
  CheckContains(LBenchSource, 'WriteLn(''Sink: '', GBenchSink);',
    'lockfree benchmark must print the consumed-value sink');
  CheckNotContains(LBenchSource, 'InterlockedIncrement(GMpmcDone);',
    'lockfree benchmark MPMC hot path must not add an unused per-item progress atomic');
  CheckContains(LRustCompareSource, 'use std::sync::mpsc',
    'Rust comparison source must use Rust std channel APIs');
  CheckContains(LRustCompareSource, 'use std::sync::{Arc, Condvar, Mutex};',
    'Rust comparison source must use Rust std synchronization primitives for bounded MPMC approximation');
  CheckContains(LRustCompareSource, 'const N: usize = 1_000_000;',
    'Rust comparison source must use the same nominal operation count');
  CheckContains(LRustCompareSource, 'const CAPACITY: usize = 1024;',
    'Rust comparison source must use the same nominal bounded-capacity context');
  CheckContains(LRustCompareSource, 'println!("Platform: {} {}", std::env::consts::OS, std::env::consts::ARCH);',
    'Rust comparison source must print the platform evidence field');
  CheckContains(LRustCompareSource, 'println!("Compiler flags: rustc -C opt-level=3 (recommended manual command)");',
    'Rust comparison source must print the compiler-flags evidence field');
  CheckContains(LRustCompareSource, 'println!("Input size: OPS=1000000; capacity=1024; scenarios=std::sync::mpsc 1P+1C, Mutex+Condvar VecDeque 2P+2C, Mutex<VecDeque> 1T");',
    'Rust comparison source must print the input-size evidence field');
  CheckContains(LRustCompareSource, 'println!("Baselines: Rust std synchronization primitives only; manual comparison source, not auto-run by Pascal benchmark");',
    'Rust comparison source must print the baseline evidence field');
  CheckContains(LRustCompareSource, 'std::sync::mpsc 1P+1C',
    'Rust comparison source must mirror the SPSC scenario name');
  CheckContains(LRustCompareSource, 'Mutex+Condvar VecDeque 2P+2C',
    'Rust comparison source must mirror the bounded MPMC approximation scenario name');
  CheckContains(LRustCompareSource, 'Mutex<VecDeque> 1T',
    'Rust comparison source must mirror the single-thread std baseline scenario name');
  CheckContains(LRustCompareSource, 'let mut sink = bench_std_mpsc_spsc();',
    'Rust comparison source must initialize the consumed-value sink from the first scenario');
  CheckContains(LRustCompareSource, 'sink = sink.wrapping_add(bench_bounded_mutex_condvar_mpmc());',
    'Rust comparison source must accumulate the bounded MPMC consumed-value sink');
  CheckContains(LRustCompareSource, 'sink = sink.wrapping_add(bench_mutex_vecdeque_single_thread());',
    'Rust comparison source must accumulate the single-thread consumed-value sink');
  CheckNotContains(LRustCompareSource, ' ^ bench_bounded_mutex_condvar_mpmc()',
    'Rust comparison source must not XOR-aggregate consumed-value sinks');
  CheckContains(LRustCompareSource, 'for value in 1..=(N as u64) {',
    'Rust comparison source must use 1..N inclusive for SPSC and 1T input values');
  CheckContains(LRustCompareSource, 'for value in 1..=((N / 2) as u64) {',
    'Rust comparison source must mirror the Pascal bounded MPMC per-producer input range');
  CheckNotContains(LRustCompareSource, 'let start_value = producer_index * (N / 2);',
    'Rust comparison source must not use disjoint half-range MPMC inputs');
  CheckContains(LGoCompareSource, 'package main',
    'Go comparison source must be a standalone Go program');
  CheckContains(LGoCompareSource, 'sync.WaitGroup',
    'Go comparison source must use Go std synchronization primitives for concurrent scenarios');
  CheckContains(LGoCompareSource, 'make(chan uint64, Capacity)',
    'Go comparison source must use a bounded buffered channel context');
  CheckContains(LGoCompareSource, 'const Ops = 1000000',
    'Go comparison source must use the same nominal operation count');
  CheckContains(LGoCompareSource, 'const Capacity = 1024',
    'Go comparison source must use the same nominal bounded-capacity context');
  CheckContains(LGoCompareSource, 'fmt.Println("Platform:", runtime.GOOS, runtime.GOARCH)',
    'Go comparison source must print the platform evidence field');
  CheckContains(LGoCompareSource, 'fmt.Println("Compiler flags: go build (default optimized gc toolchain; recommended manual command)")',
    'Go comparison source must print the compiler-flags evidence field');
  CheckContains(LGoCompareSource, 'fmt.Println("Input size: OPS=1000000; capacity=1024; scenarios=chan uint64 1P+1C, chan uint64 2P+2C, chan uint64 1T")',
    'Go comparison source must print the input-size evidence field');
  CheckContains(LGoCompareSource, 'fmt.Println("Baselines: Go channel synchronization primitives only; manual comparison source, not auto-run by Pascal benchmark")',
    'Go comparison source must print the baseline evidence field');
  CheckContains(LGoCompareSource, 'chan uint64 1P+1C',
    'Go comparison source must mirror the SPSC channel scenario name');
  CheckContains(LGoCompareSource, 'chan uint64 2P+2C',
    'Go comparison source must mirror the MPMC channel scenario name');
  CheckContains(LGoCompareSource, 'chan uint64 1T',
    'Go comparison source must mirror the single-thread channel baseline scenario name');
  CheckContains(LGoCompareSource, 'sink = benchChannelSPSC()',
    'Go comparison source must initialize the consumed-value sink from the first scenario');
  CheckContains(LGoCompareSource, 'sink += benchChannelMPMC()',
    'Go comparison source must accumulate the bounded MPMC consumed-value sink');
  CheckContains(LGoCompareSource, 'sink += benchChannelSingleThread()',
    'Go comparison source must accumulate the single-thread consumed-value sink');
  CheckNotContains(LGoCompareSource, 'sink = benchChannelSPSC() ^',
    'Go comparison source must not XOR-aggregate consumed-value sinks');
  CheckContains(LGoCompareSource, 'for value := uint64(1); value <= Ops; value++ {',
    'Go comparison source must use 1..OPS inclusive for SPSC and 1T input values');
  CheckContains(LGoCompareSource, 'for value := uint64(1); value <= Ops/2; value++ {',
    'Go comparison source must mirror the Pascal bounded MPMC per-producer input range');
  CheckNotContains(LGoCompareSource, 'startValue := uint64(producerIndex * (Ops / 2))',
    'Go comparison source must not use disjoint half-range MPMC inputs');
  CheckContains(LCppCompareSource, '#include <condition_variable>',
    'C++ comparison source must use C++ std synchronization primitives');
  CheckContains(LCppCompareSource, '#include <mutex>',
    'C++ comparison source must use C++ std mutex primitives');
  CheckContains(LCppCompareSource, '#include <queue>',
    'C++ comparison source must use a std queue context');
  CheckContains(LCppCompareSource, 'constexpr int kOps = 1000000;',
    'C++ comparison source must use the same nominal operation count');
  CheckContains(LCppCompareSource, 'constexpr std::size_t kCapacity = 1024;',
    'C++ comparison source must use the same nominal bounded-capacity context');
  CheckContains(LCppCompareSource, 'std::cout << "Platform: " << platform_name() << ''\n'';',
    'C++ comparison source must print the platform evidence field');
  CheckContains(LCppCompareSource, 'std::cout << "Compiler flags: g++ -std=c++17 -O2 -pthread (recommended manual command)"',
    'C++ comparison source must print the compiler-flags evidence field');
  CheckContains(LCppCompareSource, 'Input size: OPS=1000000; capacity=1024; scenarios=mutex+condvar queue 1P+1C, mutex+condvar queue 2P+2C, mutex queue 1T',
    'C++ comparison source must print the input-size evidence field');
  CheckContains(LCppCompareSource, 'Baselines: C++ std synchronization primitives only; manual comparison source, not auto-run by Pascal benchmark',
    'C++ comparison source must print the baseline evidence field');
  CheckContains(LCppCompareSource, 'mutex+condvar queue 1P+1C',
    'C++ comparison source must mirror the SPSC approximation scenario name');
  CheckContains(LCppCompareSource, 'mutex+condvar queue 2P+2C',
    'C++ comparison source must mirror the bounded MPMC approximation scenario name');
  CheckContains(LCppCompareSource, 'mutex queue 1T',
    'C++ comparison source must mirror the single-thread std baseline scenario name');
  CheckContains(LCppCompareSource, 'gSink = bench_bounded_spsc();',
    'C++ comparison source must initialize the consumed-value sink from the first scenario');
  CheckContains(LCppCompareSource, 'gSink += bench_bounded_mpmc();',
    'C++ comparison source must accumulate the bounded MPMC consumed-value sink');
  CheckContains(LCppCompareSource, 'gSink += bench_mutex_queue_single_thread();',
    'C++ comparison source must accumulate the single-thread consumed-value sink');
  CheckNotContains(LCppCompareSource, 'gSink = bench_bounded_spsc() ^',
    'C++ comparison source must not XOR-aggregate consumed-value sinks');
  CheckContains(LCppCompareSource,
    'for (std::uint64_t value = 1; value <= static_cast<std::uint64_t>(kOps);',
    'C++ comparison source must use 1..kOps inclusive for SPSC and 1T input values');
  CheckContains(LCppCompareSource,
    'for (std::uint64_t value = 1; value <= static_cast<std::uint64_t>(kOps / 2);',
    'C++ comparison source must mirror the Pascal bounded MPMC per-producer input range');
  CheckNotContains(LCppCompareSource, 'const int first = producer_index * (kOps / 2);',
    'C++ comparison source must not use disjoint half-range MPMC inputs');
end;

begin
  T := TTestRunner.Create('nextpas.core.lockfree');
  T.Run('SPSC basic', @TestSpscBasic);
  T.Run('SPSC close', @TestSpscClose);
  T.Run('SPSC close wake timeouts', @TestSpscCloseWakeTimeouts);
  T.Run('SPSC close wake waits', @TestSpscCloseWakeWaits);
  T.Run('SPSC approx count', @TestSpscApproxCount);
  T.Run('SPSC blocking', @TestSpscBlocking);
  T.Run('SPSC timeout', @TestSpscTimeout);
  T.Run('SPSC timeout wakes on publish', @TestSpscDequeueTimeoutWakesOnPublish);
  T.Run('SPSC timeout wakes on space', @TestSpscEnqueueTimeoutWakesOnSpace);
  T.Run('MPMC basic', @TestMpmcBasic);
  T.Run('MPMC close', @TestMpmcClose);
  T.Run('MPMC close wake waits', @TestMpmcCloseWakeWaits);
  T.Run('MPMC timeout wakes on publish', @TestMpmcDequeueTimeoutWakesOnPublish);
  T.Run('MPMC timeout wakes on space release', @TestMpmcEnqueueTimeoutWakesOnSpace);
  T.Run('MPMC 4P+4C contention', @TestMpmcContention);
  T.Run('Capacity zero reject', @TestCapacityZero);
  T.Run('Capacity overflow reject', @TestCapacityOverflowReject);
  T.Run('MPMC single-slot', @TestMpmcSingleSlot);
  T.Run('Stack capacity index limit reject', @TestStackCapacityIndexLimitReject);
  T.Run('SPSC batch', @TestSpscBatch);
  T.Run('SPSC batch partial progress', @TestSpscBatchPartialProgress);
  T.Run('MPMC timeout', @TestMpmcTimeout);
  T.Run('Stack basic', @TestStackBasic);
  T.Run('Stack query contract', @TestStackQueryContract);
  T.Run('MPSC basic', @TestMpscBasic);
  T.Run('MPSC close producer contract', @TestMpscCloseProducerContract);
  T.Run('MPSC close wake timeout', @TestMpscCloseWakeTimeout);
  T.Run('MPSC close wake wait', @TestMpscCloseWakeWait);
  T.Run('MPSC destroy requires drain in DEBUG', @TestMpscDestroyRequiresDrainInDebug);
  T.Run('MPSC multi-producer', @TestMpscMultiProducer);
  T.Run('Deque basic', @TestDequeBasic);
  T.Run('Deque query contract', @TestDequeQueryContract);
  T.Run('SPSC capacity/empty/full', @TestSpscCapacity);
  T.Run('MPMC batch', @TestMpmcBatch);
  T.Run('MPMC batch partial progress', @TestMpmcBatchPartialProgress);
  T.Run('MPMC batch dequeue AMaxCount cap', @TestMpmcBatchDequeueRespectsMaxCount);
  T.Run('MPMC capacity/empty/full', @TestMpmcCapacity);
  T.Run('LockFree wait stale epoch guard', @TestLockFreeWaitHelperStaleEpochGuard);
  T.Run('MPSC dequeue wait', @TestMpscDequeueWait);
  T.Run('MPSC timeout wakes on publish', @TestMpscDequeueTimeoutWakesOnPublish);
  T.Run('MPSC dequeue timeout', @TestMpscDequeueTimeout);
  T.Run('Deque capacity', @TestDequeCapacity);
  T.Run('Stack 4P+4C stress', @TestStackStress);
  T.Run('Deque owner+thief stress', @TestDequeOwnerThief);
  T.Run('Managed type reject', @TestManagedTypeReject);
  T.Run('Source contracts', @TestLockFreeSourceContracts);

  T.Summary;
end.
