program test_lockfree;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.fs,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree,
  nextpas.core.lockfree.base,
  nextpas.core.lockfree.wait,
  nextpas.core.lockfree.ebr,
  nextpas.core.lockfree.channel.spsc,
  nextpas.core.platform.thread,
  nextpas.core.platform.time,
  nextpas.core.text.conv,
  nextpas.core.time;

type
  TIntSpsc = specialize TSpscQueue<Integer>;
  TIntMpmc = specialize TMpmcQueue<Integer>;
  TIntStack = specialize TLockFreeStack<Integer>;
  TIntMpsc = specialize TMpscQueue<Integer>;
  TIntDeque = specialize TWorkStealingDeque<Integer>;
  TIntSegQueue = specialize TSegQueue<Integer>;
  TIntSpmc = specialize TSpmcQueue<Integer>;
  TIntChannel = specialize TLockFreeChannel<Integer>;
  TIntChannelSpsc = specialize TLockFreeChannelSpsc<Integer>;
  TIntSelector = specialize TLockFreeSelector<Integer>;
  TIntIntMap = specialize TShardedHashMap<Integer, Integer>;

const
  CloseWakePendingProbeNs = 50000000;
  QueuePublishWakeDelayNs = 20000000;
  QueuePublishWakeTimeoutNs = Int64(1000000000);
  QueuePublishWakeBudgetMs = 500;
  WaitHelperStaleEpochTimeoutNs = Int64(5000000000);
  WaitHelperImmediateReturnBudgetMs = 100;

var
  T: TTestSuite;
  GForEachSum: Integer;
  GForEachCount: Integer;
  GComputeCallCount: Integer;

function TestMonotonicMs: UInt64; inline;
begin
  Result := platform_monotonic_ns div 1000000;
end;

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
begin
  Result := ReadFileText(APath);
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

function RemoveWhitespace(const AText: string): string;
var
  LIndex: SizeInt;
  LWriteIndex: SizeInt;
begin
  SetLength(Result, Length(AText));
  LWriteIndex := 0;
  for LIndex := 1 to Length(AText) do
    if not (AText[LIndex] in [#9, #10, #13, ' ']) then
    begin
      Inc(LWriteIndex);
      Result[LWriteIndex] := AText[LIndex];
    end;
  SetLength(Result, LWriteIndex);
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
  atomic_store(GSpscCloseProducerStarted, 1, mo_release);
  if GSpscCloseWakeQ.EnqueueTimeout(2, 5000000000) then
    atomic_store(GSpscCloseProducerResult, 1, mo_release)
  else
    atomic_store(GSpscCloseProducerResult, 0, mo_release);
end;

function SpscCloseWaitProducer(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  atomic_store(GSpscCloseProducerStarted, 1, mo_release);
  if GSpscCloseWakeQ.EnqueueWait(2) then
    atomic_store(GSpscCloseProducerResult, 1, mo_release)
  else
    atomic_store(GSpscCloseProducerResult, 0, mo_release);
end;

function SpscCloseWakeConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  atomic_store(GSpscCloseConsumerStarted, 1, mo_release);
  if GSpscCloseWakeQ.DequeueTimeout(LV, 5000000000) then
    atomic_store(GSpscCloseConsumerResult, 1, mo_release)
  else
    atomic_store(GSpscCloseConsumerResult, 0, mo_release);
end;

function SpscCloseWaitConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  atomic_store(GSpscCloseConsumerStarted, 1, mo_release);
  if GSpscCloseWakeQ.DequeueWait(LV) then
    atomic_store(GSpscCloseConsumerResult, 1, mo_release)
  else
    atomic_store(GSpscCloseConsumerResult, 0, mo_release);
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
    atomic_store(GSpscCloseProducerStarted, 0, mo_release);
    atomic_store(GSpscCloseProducerResult, -1, mo_release);
    StartThread(LBlockedProducer, @SpscCloseWakeProducer, nil, 'SPSC close timeout producer thread');
    LProducerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GSpscCloseProducerStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GSpscCloseProducerStarted, mo_acquire)),
      'blocked EnqueueTimeout producer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(atomic_load(GSpscCloseProducerResult, mo_acquire)),
      'blocked EnqueueTimeout should still be pending before close');
    LElapsedMs := TestMonotonicMs;
    LQ.Close;
    JoinStartedThread(LBlockedProducer, LProducerStarted, 'SPSC close timeout producer thread');
    LElapsedMs := TestMonotonicMs - LElapsedMs;
    CheckEqual(Int64(0), Int64(atomic_load(GSpscCloseProducerResult, mo_acquire)),
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
    atomic_store(GSpscCloseConsumerStarted, 0, mo_release);
    atomic_store(GSpscCloseConsumerResult, -1, mo_release);
    StartThread(LBlockedConsumer, @SpscCloseWakeConsumer, nil, 'SPSC close timeout consumer thread');
    LConsumerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GSpscCloseConsumerStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GSpscCloseConsumerStarted, mo_acquire)),
      'blocked DequeueTimeout consumer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(atomic_load(GSpscCloseConsumerResult, mo_acquire)),
      'blocked DequeueTimeout should still be pending before close');
    LElapsedMs := TestMonotonicMs;
    LQ.Close;
    JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'SPSC close timeout consumer thread');
    LElapsedMs := TestMonotonicMs - LElapsedMs;
    CheckEqual(Int64(0), Int64(atomic_load(GSpscCloseConsumerResult, mo_acquire)),
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
    atomic_store(GSpscCloseProducerStarted, 0, mo_release);
    atomic_store(GSpscCloseProducerResult, -1, mo_release);
    StartThread(LBlockedProducer, @SpscCloseWaitProducer, nil, 'SPSC close wait producer thread');
    LProducerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GSpscCloseProducerStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GSpscCloseProducerStarted, mo_acquire)),
      'blocked EnqueueWait producer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(atomic_load(GSpscCloseProducerResult, mo_acquire)),
      'blocked EnqueueWait should still be pending before close');
    LElapsedMs := TestMonotonicMs;
    LQ.Close;
    JoinStartedThread(LBlockedProducer, LProducerStarted, 'SPSC close wait producer thread');
    LElapsedMs := TestMonotonicMs - LElapsedMs;
    CheckEqual(Int64(0), Int64(atomic_load(GSpscCloseProducerResult, mo_acquire)),
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
    atomic_store(GSpscCloseConsumerStarted, 0, mo_release);
    atomic_store(GSpscCloseConsumerResult, -1, mo_release);
    StartThread(LBlockedConsumer, @SpscCloseWaitConsumer, nil, 'SPSC close wait consumer thread');
    LConsumerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GSpscCloseConsumerStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GSpscCloseConsumerStarted, mo_acquire)),
      'blocked DequeueWait consumer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(atomic_load(GSpscCloseConsumerResult, mo_acquire)),
      'blocked DequeueWait should still be pending before close');
    LElapsedMs := TestMonotonicMs;
    LQ.Close;
    JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'SPSC close wait consumer thread');
    LElapsedMs := TestMonotonicMs - LElapsedMs;
    CheckEqual(Int64(0), Int64(atomic_load(GSpscCloseConsumerResult, mo_acquire)),
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
  atomic_store(GSpscPublishWakeConsumerStarted, 1, mo_release);
  if GSpscPublishWakeQ.DequeueTimeout(LV, QueuePublishWakeTimeoutNs) then
  begin
    GSpscPublishWakeConsumerValue := LV;
    atomic_store(GSpscPublishWakeConsumerResult, 1, mo_release);
  end
  else
    atomic_store(GSpscPublishWakeConsumerResult, 0, mo_release);
end;

function SpscSpaceWakeProducer(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  atomic_store(GSpscSpaceWakeProducerStarted, 1, mo_release);
  if GSpscPublishWakeQ.TryEnqueue(99) then
  begin
    atomic_store(GSpscSpaceWakeProducerResult, 2, mo_release);
    Exit;
  end;
  atomic_store(GSpscSpaceWakeProducerObservedFull, 1, mo_release);
  if GSpscPublishWakeQ.EnqueueTimeout(42, QueuePublishWakeTimeoutNs) then
    atomic_store(GSpscSpaceWakeProducerResult, 1, mo_release)
  else
    atomic_store(GSpscSpaceWakeProducerResult, 0, mo_release);
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
    atomic_store(GSpscPublishWakeConsumerStarted, 0, mo_release);
    atomic_store(GSpscPublishWakeConsumerResult, -1, mo_release);
    GSpscPublishWakeConsumerValue := 0;
    StartThread(LConsumer, @SpscPublishWakeConsumer, nil, 'SPSC publish wake consumer thread');
    LThreadCreated := True;

    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GSpscPublishWakeConsumerStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GSpscPublishWakeConsumerStarted, mo_acquire)),
      'SPSC DequeueTimeout consumer thread must start before publish');
    platform_thread_sleep_ns(QueuePublishWakeDelayNs);
    CheckEqual(Int64(-1), Int64(atomic_load(GSpscPublishWakeConsumerResult, mo_acquire)),
      'SPSC DequeueTimeout consumer should still be pending before publish');

    LElapsedMs := TestMonotonicMs;
    Check(LQ.TryEnqueue(42), 'SPSC producer must publish the wake item');
    JoinThread(LConsumer, LRetVal, 'publish wake consumer thread');
    LJoined := True;
    LElapsedMs := TestMonotonicMs - LElapsedMs;

    CheckEqual(Int64(1), Int64(atomic_load(GSpscPublishWakeConsumerResult, mo_acquire)),
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
    atomic_store(GSpscSpaceWakeProducerStarted, 0, mo_release);
    atomic_store(GSpscSpaceWakeProducerObservedFull, 0, mo_release);
    atomic_store(GSpscSpaceWakeProducerResult, -1, mo_release);
    StartThread(LProducer, @SpscSpaceWakeProducer, nil, 'SPSC space wake producer thread');
    LThreadCreated := True;

    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GSpscSpaceWakeProducerStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GSpscSpaceWakeProducerStarted, mo_acquire)),
      'SPSC EnqueueTimeout producer thread must start before space release');
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GSpscSpaceWakeProducerObservedFull, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GSpscSpaceWakeProducerObservedFull, mo_acquire)),
      'SPSC EnqueueTimeout producer must observe the full queue before space release');
    platform_thread_sleep_ns(QueuePublishWakeDelayNs);
    CheckEqual(Int64(-1), Int64(atomic_load(GSpscSpaceWakeProducerResult, mo_acquire)),
      'SPSC EnqueueTimeout producer must not complete before space release');

    LElapsedMs := TestMonotonicMs;
    Check(LQ.TryDequeue(LV), 'SPSC consumer must release queue space');
    CheckEqual(Int64(1), Int64(LV));
    JoinThread(LProducer, LRetVal, 'space wake producer thread');
    LJoined := True;
    LElapsedMs := TestMonotonicMs - LElapsedMs;

    CheckEqual(Int64(1), Int64(atomic_load(GSpscSpaceWakeProducerResult, mo_acquire)),
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
  atomic_store(GMpmcCloseWakeStarted, 1, mo_release);
  if GMpmcCloseWakeQ.EnqueueTimeout(2, 5000000000) then
    atomic_store(GMpmcCloseWakeResult, 1, mo_release)
  else
    atomic_store(GMpmcCloseWakeResult, 0, mo_release);
end;

function MpmcCloseWaitProducer(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  atomic_store(GMpmcCloseWakeStarted, 1, mo_release);
  if GMpmcCloseWakeQ.EnqueueWait(2) then
    atomic_store(GMpmcCloseWakeResult, 1, mo_release)
  else
    atomic_store(GMpmcCloseWakeResult, 0, mo_release);
end;

function MpmcCloseWakeConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  atomic_store(GMpmcCloseWakeStarted, 1, mo_release);
  if GMpmcCloseWakeQ.DequeueTimeout(LV, 5000000000) then
    atomic_store(GMpmcCloseWakeResult, 1, mo_release)
  else
    atomic_store(GMpmcCloseWakeResult, 0, mo_release);
end;

function MpmcCloseWaitConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  atomic_store(GMpmcCloseWakeStarted, 1, mo_release);
  if GMpmcCloseWakeQ.DequeueWait(LV) then
    atomic_store(GMpmcCloseWakeResult, 1, mo_release)
  else
    atomic_store(GMpmcCloseWakeResult, 0, mo_release);
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
  atomic_store(GMpmcPublishWakeConsumerStarted, 1, mo_release);
  if GMpmcPublishWakeQ.TryDequeue(LV) then
  begin
    GMpmcPublishWakeConsumerValue := LV;
    atomic_store(GMpmcPublishWakeConsumerResult, 2, mo_release);
    Exit;
  end;
  atomic_store(GMpmcPublishWakeConsumerObservedEmpty, 1, mo_release);
  if GMpmcPublishWakeQ.DequeueTimeout(LV, QueuePublishWakeTimeoutNs) then
  begin
    GMpmcPublishWakeConsumerValue := LV;
    atomic_store(GMpmcPublishWakeConsumerResult, 1, mo_release);
  end
  else
    atomic_store(GMpmcPublishWakeConsumerResult, 0, mo_release);
end;

function MpmcSpaceWakeProducer(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  atomic_store(GMpmcSpaceWakeProducerStarted, 1, mo_release);
  if GMpmcSpaceWakeQ.TryEnqueue(99) then
  begin
    atomic_store(GMpmcSpaceWakeProducerResult, 2, mo_release);
    Exit;
  end;
  atomic_store(GMpmcSpaceWakeProducerObservedFull, 1, mo_release);
  if GMpmcSpaceWakeQ.EnqueueTimeout(42, QueuePublishWakeTimeoutNs) then
    atomic_store(GMpmcSpaceWakeProducerResult, 1, mo_release)
  else
    atomic_store(GMpmcSpaceWakeProducerResult, 0, mo_release);
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
    atomic_store(GMpmcCloseWakeStarted, 0, mo_release);
    atomic_store(GMpmcCloseWakeResult, -1, mo_release);
    StartThread(LBlockedProducer, @MpmcCloseWakeProducer, nil, 'MPMC close timeout producer thread');
    LProducerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GMpmcCloseWakeStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GMpmcCloseWakeStarted, mo_acquire)),
      'blocked producer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(atomic_load(GMpmcCloseWakeResult, mo_acquire)),
      'blocked EnqueueTimeout should still be pending before close');
    LElapsedMs := TestMonotonicMs;
    LQ.Close;
    JoinStartedThread(LBlockedProducer, LProducerStarted, 'MPMC close timeout producer thread');
    LElapsedMs := TestMonotonicMs - LElapsedMs;
    CheckEqual(Int64(0), Int64(atomic_load(GMpmcCloseWakeResult, mo_acquire)),
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
    atomic_store(GMpmcCloseWakeStarted, 0, mo_release);
    atomic_store(GMpmcCloseWakeResult, -1, mo_release);
    StartThread(LBlockedConsumer, @MpmcCloseWakeConsumer, nil, 'MPMC close timeout consumer thread');
    LConsumerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GMpmcCloseWakeStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GMpmcCloseWakeStarted, mo_acquire)),
      'blocked consumer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(atomic_load(GMpmcCloseWakeResult, mo_acquire)),
      'blocked DequeueTimeout should still be pending before close');
    LElapsedMs := TestMonotonicMs;
    LQ.Close;
    JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'MPMC close timeout consumer thread');
    LElapsedMs := TestMonotonicMs - LElapsedMs;
    CheckEqual(Int64(0), Int64(atomic_load(GMpmcCloseWakeResult, mo_acquire)),
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
    atomic_store(GMpmcCloseWakeStarted, 0, mo_release);
    atomic_store(GMpmcCloseWakeResult, -1, mo_release);
    StartThread(LBlockedProducer, @MpmcCloseWaitProducer, nil, 'MPMC close wait producer thread');
    LProducerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GMpmcCloseWakeStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GMpmcCloseWakeStarted, mo_acquire)),
      'blocked MPMC EnqueueWait producer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(atomic_load(GMpmcCloseWakeResult, mo_acquire)),
      'blocked MPMC EnqueueWait should still be pending before close');
    LElapsedMs := TestMonotonicMs;
    LQ.Close;
    JoinStartedThread(LBlockedProducer, LProducerStarted, 'MPMC close wait producer thread');
    LElapsedMs := TestMonotonicMs - LElapsedMs;
    CheckEqual(Int64(0), Int64(atomic_load(GMpmcCloseWakeResult, mo_acquire)),
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
    atomic_store(GMpmcCloseWakeStarted, 0, mo_release);
    atomic_store(GMpmcCloseWakeResult, -1, mo_release);
    StartThread(LBlockedConsumer, @MpmcCloseWaitConsumer, nil, 'MPMC close wait consumer thread');
    LConsumerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GMpmcCloseWakeStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GMpmcCloseWakeStarted, mo_acquire)),
      'blocked MPMC DequeueWait consumer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(atomic_load(GMpmcCloseWakeResult, mo_acquire)),
      'blocked MPMC DequeueWait should still be pending before close');
    LElapsedMs := TestMonotonicMs;
    LQ.Close;
    JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'MPMC close wait consumer thread');
    LElapsedMs := TestMonotonicMs - LElapsedMs;
    CheckEqual(Int64(0), Int64(atomic_load(GMpmcCloseWakeResult, mo_acquire)),
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
    atomic_store(GMpmcPublishWakeConsumerStarted, 0, mo_release);
    atomic_store(GMpmcPublishWakeConsumerObservedEmpty, 0, mo_release);
    atomic_store(GMpmcPublishWakeConsumerResult, -1, mo_release);
    GMpmcPublishWakeConsumerValue := 0;
    StartThread(LConsumer, @MpmcPublishWakeConsumer, nil, 'MPMC publish wake consumer thread');
    LThreadCreated := True;

    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GMpmcPublishWakeConsumerStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GMpmcPublishWakeConsumerStarted, mo_acquire)),
      'MPMC DequeueTimeout consumer thread must start before publish');
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GMpmcPublishWakeConsumerObservedEmpty, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GMpmcPublishWakeConsumerObservedEmpty, mo_acquire)),
      'MPMC DequeueTimeout consumer must observe the empty queue before publish');
    platform_thread_sleep_ns(QueuePublishWakeDelayNs);
    CheckEqual(Int64(-1), Int64(atomic_load(GMpmcPublishWakeConsumerResult, mo_acquire)),
      'MPMC DequeueTimeout consumer should still be pending before publish');

    LElapsedMs := TestMonotonicMs;
    Check(LQ.TryEnqueue(42), 'MPMC producer must publish the wake item');
    JoinThread(LConsumer, LRetVal, 'publish wake consumer thread');
    LJoined := True;
    LElapsedMs := TestMonotonicMs - LElapsedMs;

    CheckEqual(Int64(1), Int64(atomic_load(GMpmcPublishWakeConsumerResult, mo_acquire)),
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
    atomic_store(GMpmcSpaceWakeProducerStarted, 0, mo_release);
    atomic_store(GMpmcSpaceWakeProducerObservedFull, 0, mo_release);
    atomic_store(GMpmcSpaceWakeProducerResult, -1, mo_release);
    StartThread(LProducer, @MpmcSpaceWakeProducer, nil, 'MPMC space wake producer thread');
    LThreadCreated := True;

    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GMpmcSpaceWakeProducerStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GMpmcSpaceWakeProducerStarted, mo_acquire)),
      'MPMC EnqueueTimeout producer thread must start before space release');
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GMpmcSpaceWakeProducerObservedFull, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GMpmcSpaceWakeProducerObservedFull, mo_acquire)),
      'MPMC EnqueueTimeout producer must observe the full queue before space release');
    platform_thread_sleep_ns(QueuePublishWakeDelayNs);
    CheckEqual(Int64(-1), Int64(atomic_load(GMpmcSpaceWakeProducerResult, mo_acquire)),
      'MPMC EnqueueTimeout producer must not complete before space release');

    LElapsedMs := TestMonotonicMs;
    Check(LQ.TryDequeue(LV), 'MPMC consumer must release queue space');
    CheckEqual(Int64(1), Int64(LV));
    JoinThread(LProducer, LRetVal, 'space wake producer thread');
    LJoined := True;
    LElapsedMs := TestMonotonicMs - LElapsedMs;

    CheckEqual(Int64(1), Int64(atomic_load(GMpmcSpaceWakeProducerResult, mo_acquire)),
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

procedure TestStackClose;
var
  LSt: TIntStack;
  LV: Integer;
begin
  LSt := TIntStack.Create(4);
  try
    Check(not LSt.IsClosed, 'stack not closed initially');
    Check(LSt.TryPush(10), 'push before close');
    Check(LSt.TryPush(20), 'push 2 before close');
    LSt.Close;
    Check(LSt.IsClosed, 'stack is closed after Close');
    Check(not LSt.TryPush(30), 'push rejected after close');
    Check(LSt.TryPop(LV), 'pop still works after close');
    CheckEqual(Int64(20), Int64(LV), 'pop LIFO after close');
    Check(LSt.TryPop(LV), 'pop 2 after close');
    CheckEqual(Int64(10), Int64(LV), 'pop 2 LIFO after close');
    Check(not LSt.TryPop(LV), 'empty after close');
  finally
    LSt.Free;
  end;
end;

procedure TestDequeClose;
var
  LD: TIntDeque;
  LV: Integer;
begin
  LD := TIntDeque.Create(4);
  try
    Check(not LD.IsClosed, 'deque not closed initially');
    Check(LD.TryPush(10), 'push before close');
    Check(LD.TryPush(20), 'push 2 before close');
    LD.Close;
    Check(LD.IsClosed, 'deque is closed after Close');
    Check(not LD.TryPush(30), 'push rejected after close');
    Check(LD.TryPop(LV), 'pop still works after close');
    CheckEqual(Int64(20), Int64(LV), 'pop LIFO after close');
    Check(LD.TryPop(LV), 'pop 2 after close');
    CheckEqual(Int64(10), Int64(LV), 'pop 2 LIFO after close');
    Check(not LD.TryPop(LV), 'empty after close');
  finally
    LD.Free;
  end;
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
  atomic_store(GMpscPublishWakeConsumerStarted, 1, mo_release);
  if GMpscPublishWakeQ.TryDequeue(LV) then
  begin
    GMpscPublishWakeConsumerValue := LV;
    atomic_store(GMpscPublishWakeConsumerResult, 2, mo_release);
    Exit;
  end;
  atomic_store(GMpscPublishWakeConsumerObservedEmpty, 1, mo_release);
  if GMpscPublishWakeQ.DequeueTimeout(LV, QueuePublishWakeTimeoutNs) then
  begin
    GMpscPublishWakeConsumerValue := LV;
    atomic_store(GMpscPublishWakeConsumerResult, 1, mo_release);
  end
  else
    atomic_store(GMpscPublishWakeConsumerResult, 0, mo_release);
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
  LGot: Boolean;
begin
  LQ := TIntMpsc.Create;
  LQ.Close;
  Check(LQ.IsClosed, 'closed');
  Check(not LQ.TryEnqueue(42), 'TryEnqueue after close rejected');
  LGot := False;
  try
    LQ.Enqueue(42);
  except
    on E: EInvalidOperationError do
      LGot := True;
  end;
  Check(LGot, 'Enqueue after close raises EInvalidOperationError');
  Check(not LQ.TryDequeue(LV), 'closed empty MPSC stays empty after rejected enqueue');
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
  atomic_store(GMpscCloseWakeStarted, 1, mo_release);
  if GMpscCloseWakeQ.DequeueTimeout(LV, 5000000000) then
    atomic_store(GMpscCloseWakeResult, 1, mo_release)
  else
    atomic_store(GMpscCloseWakeResult, 0, mo_release);
end;

function MpscCloseWaitConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  atomic_store(GMpscCloseWakeStarted, 1, mo_release);
  if GMpscCloseWakeQ.DequeueWait(LV) then
    atomic_store(GMpscCloseWakeResult, 1, mo_release)
  else
    atomic_store(GMpscCloseWakeResult, 0, mo_release);
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
    atomic_store(GMpscCloseWakeStarted, 0, mo_release);
    atomic_store(GMpscCloseWakeResult, -1, mo_release);
    StartThread(LBlockedConsumer, @MpscCloseWakeConsumer, nil, 'MPSC close timeout consumer thread');
    LConsumerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GMpscCloseWakeStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GMpscCloseWakeStarted, mo_acquire)),
      'blocked DequeueTimeout consumer thread must start before MPSC close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(atomic_load(GMpscCloseWakeResult, mo_acquire)),
      'blocked MPSC DequeueTimeout should still be pending before close');
    LElapsedMs := TestMonotonicMs;
    LQ.Close;
    JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'MPSC close timeout consumer thread');
    LElapsedMs := TestMonotonicMs - LElapsedMs;
    CheckEqual(Int64(0), Int64(atomic_load(GMpscCloseWakeResult, mo_acquire)),
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
    atomic_store(GMpscCloseWakeStarted, 0, mo_release);
    atomic_store(GMpscCloseWakeResult, -1, mo_release);
    StartThread(LBlockedConsumer, @MpscCloseWaitConsumer, nil, 'MPSC close wait consumer thread');
    LConsumerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GMpscCloseWakeStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GMpscCloseWakeStarted, mo_acquire)),
      'blocked MPSC DequeueWait consumer thread must start before close');
    platform_thread_sleep_ns(CloseWakePendingProbeNs);
    CheckEqual(Int64(-1), Int64(atomic_load(GMpscCloseWakeResult, mo_acquire)),
      'blocked MPSC DequeueWait should still be pending before close');
    LElapsedMs := TestMonotonicMs;
    LQ.Close;
    JoinStartedThread(LBlockedConsumer, LConsumerStarted, 'MPSC close wait consumer thread');
    LElapsedMs := TestMonotonicMs - LElapsedMs;
    CheckEqual(Int64(0), Int64(atomic_load(GMpscCloseWakeResult, mo_acquire)),
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

procedure TestMpscDestroyAutoCloseAndDrain;
var
  LQ: TIntMpsc;
  LV: Integer;
begin
  { Destroy must Close + drain remaining nodes so Free is safe after producers stop. }
  LQ := TIntMpsc.Create;
  LQ.Enqueue(42);
  LQ.Enqueue(7);
  LQ.Free;

  LQ := TIntMpsc.Create;
  LQ.Enqueue(42);
  LQ.Close;
  Check(LQ.TryDequeue(LV), 'drain queued MPSC item before destroy');
  CheckEqual(Int64(42), Int64(LV));
  LQ.Free;
end;

procedure TestT1DestroyCallsCloseSourceContract;
var
  LMpscSource, LSpscSource, LMpmcSource, LSpmcSource, LChannelSource, LChannelSpscSource,
  LMsQueueSource, LSegQueueSource: string;
begin
  { Safe lifecycle remains Close → join waiters → Free. Destroy must still call Close
    so unblocked teardown paths wake waiters and drain fixed/owned storage. }
  LMpscSource := ReadUtf8TextFile('../../../src/nextpas.core.lockfree.mpsc.pas');
  LSpscSource := ReadUtf8TextFile('../../../src/nextpas.core.lockfree.spsc.pas');
  LMpmcSource := ReadUtf8TextFile('../../../src/nextpas.core.lockfree.mpmc.pas');
  LSpmcSource := ReadUtf8TextFile('../../../src/nextpas.core.lockfree.spmc.pas');
  LChannelSource := ReadUtf8TextFile('../../../src/nextpas.core.lockfree.channel.pas');
  LChannelSpscSource := ReadUtf8TextFile('../../../src/nextpas.core.lockfree.channel.spsc.pas');
  LMsQueueSource := ReadUtf8TextFile('../../../src/nextpas.core.lockfree.msqueue.pas');
  LSegQueueSource := ReadUtf8TextFile('../../../src/nextpas.core.lockfree.segqueue.pas');
  CheckContains(LMpscSource, 'destructor TMpscQueueImpl.Destroy;',
    'MPSC must keep Destroy override');
  CheckContains(ExtractSection(LMpscSource,
    'destructor TMpscQueueImpl.Destroy;',
    'procedure TMpscQueueImpl.PublishNode',
    'MPSC Destroy body'), 'Close;', 'MPSC Destroy must call Close');
  CheckContains(ExtractSection(LSpscSource,
    'destructor TSpscQueueImpl.Destroy;',
    'function TSpscQueueImpl.IsClosed',
    'SPSC Destroy body'), 'Close;', 'SPSC Destroy must call Close');
  CheckContains(ExtractSection(LMpmcSource,
    'destructor TMpmcQueueImpl.Destroy;',
    'function TMpmcQueueImpl.IsClosed',
    'MPMC Destroy body'), 'Close;', 'MPMC Destroy must call Close');
  CheckContains(ExtractSection(LSpmcSource,
    'destructor TSpmcQueueImpl.Destroy;',
    'function TSpmcQueueImpl.IsClosed',
    'SPMC Destroy body'), 'Close;', 'SPMC Destroy must call Close');
  CheckContains(ExtractSection(LChannelSource,
    'destructor TLockFreeChannelImpl.Destroy;',
    'procedure TLockFreeChannelImpl.WakeAllWaiters',
    'Channel Destroy body'), 'Close;', 'Channel Destroy must call Close');
  CheckContains(ExtractSection(LChannelSpscSource,
    'destructor TLockFreeChannelSpscImpl.Destroy;',
    'function TLockFreeChannelSpscImpl.TrySend',
    'ChannelSpsc Destroy body'), 'Close;', 'ChannelSpsc Destroy must call Close');
  CheckContains(ExtractSection(LMsQueueSource,
    'destructor TLockFreeMsQueueImpl.Destroy;',
    'function TLockFreeMsQueueImpl.TryEnqueue',
    'MSQueue Destroy body'), 'Close;', 'MSQueue Destroy must call Close');
  CheckContains(ExtractSection(LSegQueueSource,
    'destructor TSegQueueImpl.Destroy;',
    'class procedure TSegQueueImpl.SegQueueReclaimSegment',
    'SegQueue Destroy body'), 'Close;', 'SegQueue Destroy must call Close');
end;

procedure AssertNoForbiddenRtlUses(const APath, ALabel: string);
var
  LText: string;
  LCompact: string;
  LSysUtils, LClasses, LMath, LWindows, LBaseUnix, LUnix: string;
  LTick, LSleep0, LFreeAndNil: string;
begin
  Check(FileExists(APath), ALabel + ' must exist for RTL isolation contract');
  LText := ReadUtf8TextFile(APath);
  LCompact := RemoveWhitespace(LText);
  { Build needles by concatenation so this harness file does not self-match. }
  LSysUtils := 'Sys' + 'Utils';
  LClasses := 'Cla' + 'sses';
  LMath := 'Ma' + 'th';
  LWindows := 'Win' + 'dows';
  LBaseUnix := 'Base' + 'Unix';
  LUnix := 'Uni' + 'x';
  LTick := 'GetTick' + 'Count64';
  LSleep0 := 'Sle' + 'ep(0)';
  LFreeAndNil := 'FreeAnd' + 'Nil(';
  { Match unit names only inside uses clauses (comma/semicolon delimited), not prose. }
  CheckNotContains(LCompact, 'uses' + LSysUtils + ',', ALabel + ': must not uses SysUtils');
  CheckNotContains(LCompact, 'uses' + LSysUtils + ';', ALabel + ': must not uses SysUtils');
  CheckNotContains(LCompact, ',' + LSysUtils + ',', ALabel + ': must not uses SysUtils');
  CheckNotContains(LCompact, ',' + LSysUtils + ';', ALabel + ': must not uses SysUtils');
  CheckNotContains(LCompact, 'uses' + LClasses + ',', ALabel + ': must not uses Classes');
  CheckNotContains(LCompact, 'uses' + LClasses + ';', ALabel + ': must not uses Classes');
  CheckNotContains(LCompact, ',' + LClasses + ',', ALabel + ': must not uses Classes');
  CheckNotContains(LCompact, ',' + LClasses + ';', ALabel + ': must not uses Classes');
  CheckNotContains(LCompact, 'uses' + LMath + ',', ALabel + ': must not uses Math');
  CheckNotContains(LCompact, 'uses' + LMath + ';', ALabel + ': must not uses Math');
  CheckNotContains(LCompact, ',' + LMath + ',', ALabel + ': must not uses Math');
  CheckNotContains(LCompact, ',' + LMath + ';', ALabel + ': must not uses Math');
  CheckNotContains(LCompact, 'uses' + LWindows + ',', ALabel + ': must not uses Windows');
  CheckNotContains(LCompact, ',' + LWindows + ';', ALabel + ': must not uses Windows');
  CheckNotContains(LCompact, 'uses' + LBaseUnix + ',', ALabel + ': must not uses BaseUnix');
  CheckNotContains(LCompact, ',' + LBaseUnix + ';', ALabel + ': must not uses BaseUnix');
  CheckNotContains(LCompact, 'uses' + LUnix + ',', ALabel + ': must not uses Unix');
  CheckNotContains(LCompact, ',' + LUnix + ';', ALabel + ': must not uses Unix');
  { Symbol-aware: bare SysUtils helpers that remain after uses-clause stripping.
    Message strings also avoid contiguous banned tokens to prevent harness self-match. }
  CheckNotContains(LText, LTick,
    ALabel + ': must not call GetTick' + 'Count64 (use platform_monotonic_ns)');
  CheckNotContains(LCompact, LSleep0,
    ALabel + ': must not call Sle' + 'ep(0) (use ThreadSwitch)');
  CheckNotContains(LCompact, LFreeAndNil,
    ALabel + ': must not call FreeAnd' + 'Nil (use Obj.Free; Obj:=nil or base.utils)');
  if Pos('Int' + 'ToStr', LText) > 0 then
    Check(Pos('nextpas.core.text.conv', LText) > 0,
      ALabel + ': Int' + 'ToStr requires nextpas.core.text.conv');
end;

{ Arch asm belongs to the atomic.core backend seam (F-002); the lockfree
  production surface must stay asm-free.  Line-based scan: this codebase
  writes Pascal keywords in lowercase, so a trimmed line equal to the asm
  keyword (or starting an asm statement) or any assembler-directive marker
  is a violation.  Needles are built by concatenation to avoid self-match. }
procedure AssertNoAssemblerCode(const APath, ALabel: string);
var
  LText, LLine, LAsmKw, LAssemblerKw: string;
  LI, LLen, LStart: Integer;

  procedure CheckLine(const ARaw: string);
  var
    LFirst, LLast: Integer;
  begin
    LFirst := 1;
    LLast := Length(ARaw);
    while (LFirst <= LLast) and (ARaw[LFirst] in [' ', #9]) do
      Inc(LFirst);
    while (LLast >= LFirst) and (ARaw[LLast] in [' ', #9, #13]) do
      Dec(LLast);
    LLine := Copy(ARaw, LFirst, LLast - LFirst + 1);
    Check((LLine <> LAsmKw) and (Pos(LAsmKw + ' ', LLine) <> 1),
      ALabel + ': lockfree production units must not contain ' + LAsmKw +
      ' blocks (arch code lives in the atomic.core backend seam)');
    Check(Pos(LAssemblerKw, LLine) = 0,
      ALabel + ': lockfree production units must not declare ' + LAssemblerKw +
      ' routines (arch code lives in the atomic.core backend seam)');
  end;

begin
  LAsmKw := 'as' + 'm';
  LAssemblerKw := 'assem' + 'bler;';
  Check(FileExists(APath), ALabel + ' must exist for the no-asm contract');
  LText := ReadUtf8TextFile(APath);
  LLen := Length(LText);
  LStart := 1;
  for LI := 1 to LLen do
    if LText[LI] = #10 then
    begin
      CheckLine(Copy(LText, LStart, LI - LStart));
      LStart := LI + 1;
    end;
  if LStart <= LLen then
    CheckLine(Copy(LText, LStart, LLen - LStart + 1));
end;

procedure TestFpcRtlIsolationSourceContract;
const
  Src = '../../../src/';
  { Full production surface: every nextpas.core.atomic* and nextpas.core.lockfree* unit. }
  Paths: array[0..107] of string = (
    'nextpas.core.atomic.pas',
    'nextpas.core.atomic.core.pas',
    'nextpas.core.atomic.types.pas',
    'nextpas.core.atomic.compat.pas',
    'nextpas.core.lockfree.pas',
    'nextpas.core.lockfree.base.pas',
    'nextpas.core.lockfree.wait.pas',
    'nextpas.core.lockfree.ebr.pas',
    'nextpas.core.lockfree.hazard.pas',
    'nextpas.core.lockfree.rcu.pas',
    'nextpas.core.lockfree.spsc.pas',
    'nextpas.core.lockfree.mpmc.pas',
    'nextpas.core.lockfree.mpsc.pas',
    'nextpas.core.lockfree.spmc.pas',
    'nextpas.core.lockfree.segqueue.pas',
    'nextpas.core.lockfree.msqueue.pas',
    'nextpas.core.lockfree.ringbuffer.pas',
    'nextpas.core.lockfree.timeoutqueue.pas',
    'nextpas.core.lockfree.stack.pas',
    'nextpas.core.lockfree.elimination_stack.pas',
    'nextpas.core.lockfree.deque.pas',
    'nextpas.core.lockfree.deque_lf.pas',
    'nextpas.core.lockfree.deque_spin.pas',
    'nextpas.core.lockfree.channel.pas',
    'nextpas.core.lockfree.channel.spsc.pas',
    'nextpas.core.lockfree.hashmap.pas',
    'nextpas.core.lockfree.hashset.pas',
    'nextpas.core.lockfree.hashtable.pas',
    'nextpas.core.lockfree.multimap.pas',
    'nextpas.core.lockfree.trie.pas',
    'nextpas.core.lockfree.trie_map.pas',
    'nextpas.core.lockfree.trie_hmt.pas',
    'nextpas.core.lockfree.skiplist.pas',
    'nextpas.core.lockfree.skiplist_map.pas',
    'nextpas.core.lockfree.robinhood.pas',
    'nextpas.core.lockfree.btree.pas',
    'nextpas.core.lockfree.bplus.pas',
    'nextpas.core.lockfree.rbtree.pas',
    'nextpas.core.lockfree.treap.pas',
    'nextpas.core.lockfree.scapegoat.pas',
    'nextpas.core.lockfree.radix.pas',
    'nextpas.core.lockfree.sortedset.pas',
    'nextpas.core.lockfree.graph.pas',
    'nextpas.core.lockfree.dag.pas',
    'nextpas.core.lockfree.adjmap.pas',
    'nextpas.core.lockfree.disjointset.pas',
    'nextpas.core.lockfree.merkle_tree.pas',
    'nextpas.core.lockfree.fibheap.pas',
    'nextpas.core.lockfree.fenwick.pas',
    'nextpas.core.lockfree.intervaltree.pas',
    'nextpas.core.lockfree.persistent_vector.pas',
    'nextpas.core.lockfree.mutex.pas',
    'nextpas.core.lockfree.rwlock.pas',
    'nextpas.core.lockfree.semaphore.pas',
    'nextpas.core.lockfree.barrier.pas',
    'nextpas.core.lockfree.condvar.pas',
    'nextpas.core.lockfree.countdown.pas',
    'nextpas.core.lockfree.phaser.pas',
    'nextpas.core.lockfree.stampedlock.pas',
    'nextpas.core.lockfree.exchanger.pas',
    'nextpas.core.lockfree.flatcombining.pas',
    'nextpas.core.lockfree.leftright.pas',
    'nextpas.core.lockfree.lru.pas',
    'nextpas.core.lockfree.lru_cache.pas',
    'nextpas.core.lockfree.lfu.pas',
    'nextpas.core.lockfree.ttl_cache.pas',
    'nextpas.core.lockfree.arccache.pas',
    'nextpas.core.lockfree.bloom.pas',
    'nextpas.core.lockfree.counting_bloom.pas',
    'nextpas.core.lockfree.scalable_bloom.pas',
    'nextpas.core.lockfree.cuckooset.pas',
    'nextpas.core.lockfree.hyperloglog.pas',
    'nextpas.core.lockfree.countminsketch.pas',
    'nextpas.core.lockfree.xorfilter.pas',
    'nextpas.core.lockfree.tdigest.pas',
    'nextpas.core.lockfree.spacesaving.pas',
    'nextpas.core.lockfree.misragries.pas',
    'nextpas.core.lockfree.reservoirsampling.pas',
    'nextpas.core.lockfree.ratelimit.pas',
    'nextpas.core.lockfree.leakybucket.pas',
    'nextpas.core.lockfree.slidingwindow.pas',
    'nextpas.core.lockfree.actor.pas',
    'nextpas.core.lockfree.forkjoin.pas',
    'nextpas.core.lockfree.workstealing.pas',
    'nextpas.core.lockfree.selector.pas',
    'nextpas.core.lockfree.selector.impl.pas',
    'nextpas.core.lockfree.counter.pas',
    'nextpas.core.lockfree.bag.pas',
    'nextpas.core.lockfree.bitset.pas',
    'nextpas.core.lockfree.linkedlist.pas',
    'nextpas.core.lockfree.unrolled_list.pas',
    'nextpas.core.lockfree.cowarray.pas',
    'nextpas.core.lockfree.snapshot.pas',
    'nextpas.core.lockfree.statscounter.pas',
    'nextpas.core.lockfree.consistent_hashring.pas',
    'nextpas.core.lockfree.suffixarray.pas',
    'nextpas.core.lockfree.roaring_bitmap.pas',
    'nextpas.core.lockfree.timeseries_ringbuffer.pas',
    'nextpas.core.lockfree.crdt.pas',
    'nextpas.core.lockfree.rope.pas',
    'nextpas.core.lockfree.versionvector.pas',
    'nextpas.core.lockfree.wrr.pas',
    'nextpas.core.lockfree.matrix.pas',
    'nextpas.core.lockfree.hashmap.rtm.pas',
    'nextpas.core.lockfree.hashmap.numa.pas',
    'nextpas.core.lockfree.priority_queue.pas',
    'nextpas.core.lockfree.timerwheel.pas',
    'nextpas.core.lockfree.rtm.pas'
  );
var
  LI: Integer;
  LMakefile: string;
  LTtwoCompile: string;
begin
  for LI := Low(Paths) to High(Paths) do
  begin
    AssertNoForbiddenRtlUses(Src + Paths[LI], Paths[LI]);
    { atomic.* units carry their own seam pins in test_atomic (atomic.core owns
      the sanctioned arch code; atomic.pas has the registered i386 residue). }
    if Pos('lockfree', Paths[LI]) > 0 then
      AssertNoAssemblerCode(Src + Paths[LI], Paths[LI]);
  end;
  AssertNoForbiddenRtlUses('../../../examples/lockfree_example.lpr', 'lockfree_example');

  { Main test harnesses must not direct-uses banned RTL after M6 migration. }
  AssertNoForbiddenRtlUses('test_lockfree.lpr', 'test_lockfree.lpr');
  AssertNoForbiddenRtlUses('../test_lockfree_stress/test_lockfree_stress.lpr',
    'test_lockfree_stress.lpr');
  AssertNoForbiddenRtlUses('../../nextpas.core.atomic/test_atomic/test_atomic.lpr',
    'test_atomic.lpr');
  AssertNoForbiddenRtlUses('../bench_hashmap_read/bench_hashmap_read.lpr',
    'bench_hashmap_read.lpr');
  AssertNoForbiddenRtlUses('../bench_hashmap_read/bench_hashmap_comparison.lpr',
    'bench_hashmap_comparison.lpr');

  LMakefile := ReadUtf8TextFile('Makefile');
  CheckContains(LMakefile, 'T2_ISOLATION_COMPILE_SOURCE := test_lockfree_t2_isolation_compile.lpr',
    'lockfree Makefile must name T2 isolation compile fixture');
  CheckContains(LMakefile, 'compile-t2-isolation-host:',
    'lockfree Makefile must provide T2 isolation compile target');
  CheckContains(LMakefile, 'lockfree-t2-isolation-compile-status=pass',
    'T2 isolation compile target must print pass evidence');
  CheckContains(LMakefile, 'test: compile-t2-isolation-host run',
    'lockfree main test gate must compile T2 isolation smoke first');

  LTtwoCompile := ReadUtf8TextFile('test_lockfree_t2_isolation_compile.lpr');
  CheckContains(LTtwoCompile, 'nextpas.core.lockfree.ttl_cache',
    'T2 isolation compile must touch ttl_cache');
  CheckContains(LTtwoCompile, 'nextpas.core.lockfree.timeseries_ringbuffer',
    'T2 isolation compile must touch timeseries_ringbuffer');
  CheckContains(LTtwoCompile, 'nextpas.core.lockfree.hashmap.rtm',
    'T2 isolation compile must touch hashmap.rtm');
  CheckContains(LTtwoCompile, 'nextpas.core.lockfree.hashmap.numa',
    'T2 isolation compile must touch hashmap.numa');
  CheckContains(LTtwoCompile, 'nextpas.core.lockfree.consistent_hashring',
    'T2 isolation compile must touch consistent_hashring');
  CheckContains(LTtwoCompile, 'nextpas.core.lockfree.trie_hmt',
    'T2 isolation compile must touch trie_hmt');
end;

procedure TestLockFreePrefetchSmoke;
var
  LBuf: array[0..255] of Byte;
begin
  LBuf[128] := $5A;
  { Prefetch is a hint: it must never fault, alter data, or block — including
    on nil.  Also exercises the atomic.core cpu_prefetch_nta delegation. }
  LockFreePrefetch(@LBuf[128]);
  LockFreePrefetch(nil);
  Check(LBuf[128] = $5A, 'prefetch hint must not modify target memory');
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
  LElapsedMs := TestMonotonicMs;
  if AUseSpaceWait then
    LockFreeWaitSpace(@LEpoch, @LWaiters, 0, WaitHelperStaleEpochTimeoutNs)
  else
    LockFreeWaitData(@LEpoch, @LWaiters, 0, WaitHelperStaleEpochTimeoutNs);
  LElapsedMs := TestMonotonicMs - LElapsedMs;
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

procedure TestLockFreeWaitNilSafe;
var
  LEpoch: Int32;
  LWaiters: Int32;
begin
  { Must not crash on nil counters (CONTRACT: defensive early exit). }
  LockFreeWaitData(nil, nil, 0, 1000000);
  LockFreeWaitSpace(nil, nil, 0, 1000000);
  LockFreeNotifyData(nil, nil);
  LockFreeNotifySpace(nil, nil);
  LockFreeWakeAll(nil);
  LEpoch := 0;
  LWaiters := 0;
  LockFreeWaitData(@LEpoch, nil, 0, 1000000);
  LockFreeWaitData(nil, @LWaiters, 0, 1000000);
  CheckEqual(Int64(0), Int64(LWaiters), 'nil epoch path must not register waiters');
end;

procedure TestLockFreeWaitTimeoutUnregistersWaiter;
const
  WaitTimeoutNs = Int64(5000000); { 5ms }
var
  LEpoch: Int32;
  LWaiters: Int32;
  LElapsedMs: QWord;
begin
  LEpoch := 0;
  LWaiters := 0;
  LElapsedMs := TestMonotonicMs;
  LockFreeWaitData(@LEpoch, @LWaiters, 0, WaitTimeoutNs);
  LElapsedMs := TestMonotonicMs - LElapsedMs;
  CheckEqual(Int64(0), Int64(LWaiters),
    'timeout/return must leave waiter count at 0 (finally unregister)');
  Check(LElapsedMs < 2000,
    'bounded wait must not hang for seconds when epoch is stable');
end;

const
  LF_WAIT_NOTIFY_WAITERS = 4;

var
  GLfWaitEpoch: Int32;
  GLfWaitWaiters: Int32;
  GLfWaitDone: Int32;
  GLfWaitStart: Int32;

function LfWaitNotifyWaiter(AArg: Pointer): Pointer; cdecl;
var
  LExpected: Int32;
begin
  Result := nil;
  while atomic_load(GLfWaitStart, mo_acquire) = 0 do
    CpuPause;
  LExpected := atomic_load(GLfWaitEpoch, mo_acquire);
  LockFreeWaitData(@GLfWaitEpoch, @GLfWaitWaiters, LExpected, Int64(2000000000));
  atomic_fetch_add(GLfWaitDone, 1, mo_release);
end;

procedure TestLockFreeWaitNotifyUnblocksWaiters;
var
  LHandles: array[0..LF_WAIT_NOTIFY_WAITERS - 1] of TPlatformThreadHandle;
  LI: Integer;
  LCount: Integer;
  LRet: Pointer;
  LSpin: Integer;
begin
  atomic_store(GLfWaitEpoch, 0, mo_release);
  atomic_store(GLfWaitWaiters, 0, mo_release);
  atomic_store(GLfWaitDone, 0, mo_release);
  atomic_store(GLfWaitStart, 0, mo_release);
  LCount := 0;
  try
    for LI := 0 to LF_WAIT_NOTIFY_WAITERS - 1 do
    begin
      StartThread(LHandles[LI], @LfWaitNotifyWaiter, nil, 'lf wait notify waiter');
      Inc(LCount);
    end;
    atomic_store(GLfWaitStart, 1, mo_release);
    { Give waiters time to enter spin/block path. }
    for LSpin := 1 to 200 do
    begin
      if atomic_load(GLfWaitWaiters, mo_acquire) > 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    LockFreeNotifyData(@GLfWaitEpoch, @GLfWaitWaiters);
    for LI := 0 to LCount - 1 do
      JoinThread(LHandles[LI], LRet, 'lf wait notify join');
    LCount := 0;
    CheckEqual(Int64(LF_WAIT_NOTIFY_WAITERS),
      Int64(atomic_load(GLfWaitDone, mo_acquire)),
      'all waiters must exit after LockFreeNotifyData');
    CheckEqual(Int64(0), Int64(atomic_load(GLfWaitWaiters, mo_acquire)),
      'waiter counter must return to 0 after all leave');
    Check(atomic_load(GLfWaitEpoch, mo_acquire) <> 0,
      'notify must advance epoch');
  finally
    LockFreeWakeAll(@GLfWaitEpoch);
    for LI := 0 to LCount - 1 do
      JoinThread(LHandles[LI], LRet, 'lf wait notify cleanup');
  end;
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
    atomic_store(GMpscPublishWakeConsumerStarted, 0, mo_release);
    atomic_store(GMpscPublishWakeConsumerObservedEmpty, 0, mo_release);
    atomic_store(GMpscPublishWakeConsumerResult, -1, mo_release);
    GMpscPublishWakeConsumerValue := 0;
    StartThread(LConsumer, @MpscPublishWakeConsumer, nil, 'MPSC publish wake consumer thread');
    LThreadCreated := True;

    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GMpscPublishWakeConsumerStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GMpscPublishWakeConsumerStarted, mo_acquire)),
      'MPSC DequeueTimeout consumer thread must start before publish');
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GMpscPublishWakeConsumerObservedEmpty, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GMpscPublishWakeConsumerObservedEmpty, mo_acquire)),
      'MPSC DequeueTimeout consumer must observe the empty queue before publish');
    platform_thread_sleep_ns(QueuePublishWakeDelayNs);
    CheckEqual(Int64(-1), Int64(atomic_load(GMpscPublishWakeConsumerResult, mo_acquire)),
      'MPSC DequeueTimeout consumer must not complete before publish');

    LElapsedMs := TestMonotonicMs;
    LQ.Enqueue(42);
    JoinThread(LConsumer, LRetVal, 'publish wake consumer thread');
    LJoined := True;
    LElapsedMs := TestMonotonicMs - LElapsedMs;

    CheckEqual(Int64(1), Int64(atomic_load(GMpscPublishWakeConsumerResult, mo_acquire)),
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

{ EBR reclamation tests }

var
  GEbrReclaimCount: Int32;
  GEbrOrphanDomain: TEbrDomain;

procedure EbrTestReclaimProc(const AData: Pointer; const AUserData: Pointer);
begin
  atomic_fetch_add(GEbrReclaimCount, 1, mo_seq_cst);
end;

function EbrOrphanRetireThread(AArg: Pointer): Pointer; cdecl;
begin
  GEbrOrphanDomain.Retire(Pointer(1), @EbrTestReclaimProc);
  Result := nil;
end;

procedure TestEbrRetireAndCollect;
var
  LDomain: TEbrDomain;
begin
  LDomain := TEbrDomain.Create;
  try
    GEbrReclaimCount := 0;
    LDomain.Retire(Pointer(1), @EbrTestReclaimProc);
    LDomain.Retire(Pointer(2), @EbrTestReclaimProc);
    CheckEqual(Int64(2), Int64(LDomain.RetiredCount), 'retired count should be 2');
    LDomain.Collect;
    CheckEqual(Int64(2), Int64(GEbrReclaimCount), 'both retirements should be reclaimed');
    CheckEqual(Int64(0), Int64(LDomain.RetiredCount), 'retired count should be 0 after collect');
  finally
    LDomain.Free;
  end;
end;

procedure TestEbrDefersWhileGuardActive;
var
  LDomain: TEbrDomain;
  LGuard: TEbrGuard;
begin
  LDomain := TEbrDomain.Create;
  try
    GEbrReclaimCount := 0;
    LGuard := TEbrGuard.Acquire(LDomain);
    LDomain.Retire(Pointer(1), @EbrTestReclaimProc);
    LDomain.Collect;
    CheckEqual(Int64(0), Int64(GEbrReclaimCount), 'should NOT reclaim while guard active');
    CheckEqual(Int64(1), Int64(LDomain.RetiredCount), 'retired count stays 1');
    LGuard.Release;
    LDomain.Collect;
    CheckEqual(Int64(1), Int64(GEbrReclaimCount), 'should reclaim after guard released');
  finally
    LDomain.Free;
  end;
end;

procedure TestEbrGuardLeaveIdempotent;
var
  LDomain: TEbrDomain;
  LGuard: TEbrGuard;
begin
  LDomain := TEbrDomain.Create;
  try
    LGuard := TEbrGuard.Acquire(LDomain);
    CheckEqual(Int64(1), Int64(LDomain.ActiveCount), 'should be active after acquire');
    LGuard.Release;
    CheckEqual(Int64(0), Int64(LDomain.ActiveCount), 'should be inactive after release');
    LGuard.Release;
    CheckEqual(Int64(0), Int64(LDomain.ActiveCount), 'double release should be idempotent');
  finally
    LDomain.Free;
  end;
end;

procedure TestEbrNilGuardAcquire;
var
  LDomain: TEbrDomain;
  LNilGuard: TEbrGuard;
  LRealGuard: TEbrGuard;
begin
  LDomain := TEbrDomain.Create;
  try
    LNilGuard := TEbrGuard.Acquire(nil);
    CheckEqual(Int64(0), Int64(LDomain.ActiveCount), 'nil guard must not increment active count');
    LNilGuard.Release;
    Check(True, 'nil guard release must not crash');
    LRealGuard := TEbrGuard.Acquire(LDomain);
    CheckEqual(Int64(1), Int64(LDomain.ActiveCount), 'real guard must increment active count');
    LNilGuard.Release;
    CheckEqual(Int64(1), Int64(LDomain.ActiveCount), 'nil guard double release must not affect real guard');
    LRealGuard.Release;
  finally
    LDomain.Free;
  end;
end;

procedure TestEbrMultiGuardRetireCollect;
var
  LDomain: TEbrDomain;
  LGuard1: TEbrGuard;
  LGuard2: TEbrGuard;
begin
  LDomain := TEbrDomain.Create;
  try
    GEbrReclaimCount := 0;
    LGuard1 := TEbrGuard.Acquire(LDomain);
    LGuard2 := TEbrGuard.Acquire(LDomain);
    CheckEqual(Int64(2), Int64(LDomain.ActiveCount), 'two active guards');
    LDomain.Retire(Pointer(1), @EbrTestReclaimProc);
    LDomain.Retire(Pointer(2), @EbrTestReclaimProc);
    LDomain.Retire(Pointer(3), @EbrTestReclaimProc);
    CheckEqual(Int64(3), Int64(LDomain.RetiredCount), 'three retired items');
    LDomain.Collect;
    CheckEqual(Int64(0), Int64(GEbrReclaimCount), 'must not reclaim with two guards active');
    LGuard1.Release;
    LDomain.Collect;
    CheckEqual(Int64(0), Int64(GEbrReclaimCount), 'must not reclaim with one guard still active');
    LGuard2.Release;
    LDomain.Collect;
    CheckEqual(Int64(3), Int64(GEbrReclaimCount), 'must reclaim all after all guards released');
    CheckEqual(Int64(0), Int64(LDomain.RetiredCount), 'retired count must be 0 after full reclaim');
  finally
    LDomain.Free;
  end;
end;

procedure TestEbrDestroyWithRetired;
var
  LDomain: TEbrDomain;
begin
  GEbrReclaimCount := 0;
  LDomain := TEbrDomain.Create;
  LDomain.Retire(Pointer(10), @EbrTestReclaimProc);
  LDomain.Retire(Pointer(20), @EbrTestReclaimProc);
  LDomain.Free;
  CheckEqual(Int64(2), Int64(GEbrReclaimCount), 'destroy must reclaim all retired items');
end;

procedure TestEbrOrphansStayWithOriginDomain;
var
  LOtherDomain: TEbrDomain;
  LGuard: TEbrGuard;
  LThread: TPlatformThreadHandle;
  LRetVal: Pointer;
  LReclaimedWhileActive: Int32;
begin
  GEbrOrphanDomain := TEbrDomain.Create;
  LOtherDomain := TEbrDomain.Create;
  LGuard := TEbrGuard.Acquire(GEbrOrphanDomain);
  try
    GEbrReclaimCount := 0;
    StartThread(LThread, @EbrOrphanRetireThread, nil, 'EBR orphan retire thread');
    JoinThread(LThread, LRetVal, 'EBR orphan retire thread');

    LOtherDomain.Collect;
    LReclaimedWhileActive := atomic_load(GEbrReclaimCount, mo_acquire);

    LGuard.Release;
    GEbrOrphanDomain.Collect;

    CheckEqual(Int64(0), Int64(LReclaimedWhileActive),
      'An unrelated domain must not reclaim origin-domain retirements while its guard is active');
    CheckEqual(Int64(1), Int64(atomic_load(GEbrReclaimCount, mo_acquire)),
      'Origin domain must reclaim the retirement after its guard leaves');
  finally
    LGuard.Release;
    LOtherDomain.Free;
    GEbrOrphanDomain.Free;
    GEbrOrphanDomain := nil;
  end;
end;

{ EBR boundary conditions }

procedure TestEbrBoundaryConditions;
var
  LDomain: TEbrDomain;
  LGuard1, LGuard2: TEbrGuard;
begin
  LDomain := TEbrDomain.Create;
  try
    { Multiple guards from same domain }
    LGuard1 := TEbrGuard.Acquire(LDomain);
    LGuard2 := TEbrGuard.Acquire(LDomain);
    LGuard1.Release;
    LGuard2.Release;
  finally
    LDomain.Free;
  end;
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
    if atomic_load(GStackStressStop, mo_acquire) <> 0 then
      Exit;
    while not GStressStack.TryPush(LI) do
    begin
      if atomic_load(GStackStressStop, mo_acquire) <> 0 then
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
    else if atomic_load(GStackStressStop, mo_acquire) <> 0 then
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
  atomic_store(GStackStressStop, 0, mo_release);
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
    atomic_store(GStackStressStop, 1, mo_release);
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
var
  LGot: Boolean;
  LSpsc: specialize TSpscQueue<AnsiString>;
  LMpmc: specialize TMpmcQueue<AnsiString>;
  LMpsc: specialize TMpscQueue<AnsiString>;
  LSpmc: specialize TSpmcQueue<AnsiString>;
  LStack: specialize TLockFreeStack<AnsiString>;
  LDeque: specialize TWorkStealingDeque<AnsiString>;
  LSeg: specialize TSegQueue<AnsiString>;
  LMsQueue: specialize TLockFreeMsQueue<AnsiString>;
  LChannel: specialize TLockFreeChannel<AnsiString>;
  LChannelSpsc: specialize TLockFreeChannelSpsc<AnsiString>;
  LStrMap: specialize TShardedHashMap<AnsiString, Integer>;
  LIntStrMap: specialize TShardedHashMap<Integer, AnsiString>;
begin
  LGot := False;
  try
    LSpsc := specialize TSpscQueue<AnsiString>.Create(4);
    LSpsc.Free;
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'SPSC managed type rejected');

  LGot := False;
  try
    LMpmc := specialize TMpmcQueue<AnsiString>.Create(4);
    LMpmc.Free;
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'MPMC managed type rejected');

  LGot := False;
  try
    LMpsc := specialize TMpscQueue<AnsiString>.Create;
    LMpsc.Free;
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'MPSC managed type rejected');

  LGot := False;
  try
    LSpmc := specialize TSpmcQueue<AnsiString>.Create(4);
    LSpmc.Free;
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'SPMC managed type rejected');

  LGot := False;
  try
    LStack := specialize TLockFreeStack<AnsiString>.Create(4);
    LStack.Free;
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'Stack managed type rejected');

  LGot := False;
  try
    LDeque := specialize TWorkStealingDeque<AnsiString>.Create(4);
    LDeque.Free;
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'Deque managed type rejected');

  LGot := False;
  try
    LSeg := specialize TSegQueue<AnsiString>.Create;
    LSeg.Free;
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'SegQueue managed type rejected');

  LGot := False;
  try
    LMsQueue := specialize TLockFreeMsQueue<AnsiString>.Create;
    LMsQueue.Free;
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'MsQueue managed type rejected');

  LGot := False;
  try
    LChannel := specialize TLockFreeChannel<AnsiString>.Create(4);
    LChannel.Free;
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'Channel managed type rejected');

  LGot := False;
  try
    LChannelSpsc := specialize TLockFreeChannelSpsc<AnsiString>.Create(4);
    LChannelSpsc.Free;
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'ChannelSpsc managed type rejected');

  LGot := False;
  try
    LStrMap := specialize TShardedHashMap<AnsiString, Integer>.Create(4);
    LStrMap.Free;
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'ShardedHashMap managed key rejected');

  LGot := False;
  try
    LIntStrMap := specialize TShardedHashMap<Integer, AnsiString>.Create(4);
    LIntStrMap.Free;
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'ShardedHashMap managed value rejected');
end;

{ LockFree Channel tests }

procedure TestChannelBasic;
var
  LCh: TIntChannel;
  LV: Integer;
begin
  LCh := TIntChannel.Create(4);
  try
    Check(LCh.TrySend(10), 'TrySend 1');
    Check(LCh.TrySend(20), 'TrySend 2');
    Check(LCh.TrySend(30), 'TrySend 3');
    Check(LCh.TrySend(40), 'TrySend 4');
    Check(not LCh.TrySend(50), 'TrySend full');
    Check(LCh.TryReceive(LV), 'TryReceive 1');
    CheckEqual(Int64(10), Int64(LV));
    Check(LCh.TryReceive(LV), 'TryReceive 2');
    CheckEqual(Int64(20), Int64(LV));
    Check(LCh.TryReceive(LV), 'TryReceive 3');
    CheckEqual(Int64(30), Int64(LV));
    Check(LCh.TryReceive(LV), 'TryReceive 4');
    CheckEqual(Int64(40), Int64(LV));
    Check(not LCh.TryReceive(LV), 'TryReceive empty');
  finally
    LCh.Free;
  end;
end;

procedure TestChannelClose;
var
  LCh: TIntChannel;
  LV: Integer;
begin
  LCh := TIntChannel.Create(4);
  try
    Check(LCh.TrySend(10), 'pre-close send');
    Check(LCh.TrySend(20), 'pre-close send 2');
    LCh.Close;
    Check(LCh.IsClosed, 'IsClosed');
    Check(not LCh.TrySend(30), 'TrySend after close rejected');
    Check(LCh.TryReceive(LV), 'drain after close 1');
    CheckEqual(Int64(10), Int64(LV));
    Check(LCh.TryReceive(LV), 'drain after close 2');
    CheckEqual(Int64(20), Int64(LV));
    Check(not LCh.TryReceive(LV), 'empty after close drain');
  finally
    LCh.Free;
  end;
end;

{ Q3-b: Close is idempotent }
procedure TestChannelCloseIdempotent;
var
  LCh: TIntChannel;
  LV: Integer;
begin
  LCh := TIntChannel.Create(4);
  try
    Check(LCh.TrySend(1), 'seed');
    LCh.Close;
    Check(LCh.IsClosed, 'closed once');
    LCh.Close;
    Check(LCh.IsClosed, 'closed twice still closed');
    Check(not LCh.TrySend(2), 'TrySend still rejected');
    Check(LCh.TryReceive(LV), 'drain still works');
    CheckEqual(Int64(1), Int64(LV), 'drained value');
  finally
    LCh.Free;
  end;
end;

procedure TestChannelCloseRaiseOnSend;
var
  LCh: TIntChannel;
  LGot: Boolean;
begin
  LCh := TIntChannel.Create(4);
  try
    LCh.TrySend(1);
    LCh.TrySend(2);
    LCh.TrySend(3);
    LCh.TrySend(4);
    LCh.Close;
    LGot := False;
    try
      LCh.Send(5);
    except
      on E: EInvalidOperationError do
        LGot := True;
    end;
    Check(LGot, 'Send after close raises EInvalidOperationError');
  finally
    LCh.Free;
  end;
end;

var
  GChannelSendQ: TIntChannel;
  GChannelSendStarted: Int32;
  GChannelSendValue: Integer;

function ChannelSendBlockedConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  atomic_store(GChannelSendStarted, 1, mo_release);
  if GChannelSendQ.Receive(LV) then
    GChannelSendValue := LV;
end;

procedure TestChannelSendReceive;
var
  LCh: TIntChannel;
  LConsumer: TPlatformThreadHandle;
  LRetVal: Pointer;
  LSpin: Integer;
  LConsumerStarted: Boolean;
begin
  LCh := TIntChannel.Create(4);
  LConsumerStarted := False;
  try
    GChannelSendQ := LCh;
    atomic_store(GChannelSendStarted, 0, mo_release);
    GChannelSendValue := 0;
    StartThread(LConsumer, @ChannelSendBlockedConsumer, nil, 'Channel Send/Receive consumer');
    LConsumerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GChannelSendStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    LCh.Send(42);
    JoinStartedThread(LConsumer, LConsumerStarted, 'Channel consumer');
    CheckEqual(Int64(42), Int64(GChannelSendValue), 'Send→Receive delivers value');
  finally
    if LConsumerStarted then
    begin
      LCh.Close;
      JoinStartedThread(LConsumer, LConsumerStarted, 'Channel consumer');
    end;
    GChannelSendQ := nil;
    LCh.Free;
  end;
end;

procedure TestChannelSendTimeout;
var
  LCh: TIntChannel;
  LV: Integer;
begin
  LCh := TIntChannel.Create(4);
  try
    LCh.TrySend(1);
    LCh.TrySend(2);
    LCh.TrySend(3);
    LCh.TrySend(4);
    Check(not LCh.SendTimeout(5, 1000000), 'SendTimeout on full');
    Check(LCh.TryReceive(LV), 'drain');
    CheckEqual(Int64(1), Int64(LV));
    Check(LCh.SendTimeout(5, 1000000), 'SendTimeout after space');
  finally
    LCh.Free;
  end;
end;

procedure TestChannelReceiveTimeout;
var
  LCh: TIntChannel;
  LV: Integer;
begin
  LCh := TIntChannel.Create(4);
  try
    Check(not LCh.ReceiveTimeout(LV, 1000000), 'ReceiveTimeout on empty');
    Check(LCh.TrySend(77), 'send');
    Check(LCh.ReceiveTimeout(LV, 1000000), 'ReceiveTimeout immediate');
    CheckEqual(Int64(77), Int64(LV));
  finally
    LCh.Free;
  end;
end;

procedure TestChannelApproxLen;
var
  LCh: TIntChannel;
begin
  LCh := TIntChannel.Create(8);
  try
    CheckEqual(Int64(8), Int64(LCh.Capacity), 'Capacity');
    CheckEqual(Int64(0), Int64(LCh.ApproxLen), 'initial ApproxLen');
    Check(not LCh.IsClosed, 'not closed initially');
    LCh.TrySend(1);
    LCh.TrySend(2);
    LCh.TrySend(3);
    CheckEqual(Int64(3), Int64(LCh.ApproxLen), 'ApproxLen after sends');
    LCh.Close;
    Check(LCh.IsClosed, 'IsClosed after Close');
  finally
    LCh.Free;
  end;
end;

{ LockFree HashMap tests }

procedure TestHashMapBasic;
var
  LM: TIntIntMap;
  LV: Integer;
begin
  LM := TIntIntMap.Create;
  try
    LM.Insert(1, 100);
    LM.Insert(2, 200);
    LM.Insert(3, 300);
    Check(LM.Contains(1), 'Contains 1');
    Check(LM.Contains(2), 'Contains 2');
    Check(LM.Contains(3), 'Contains 3');
    Check(LM.Find(1, LV), 'Find 1');
    CheckEqual(Int64(100), Int64(LV));
    Check(LM.Find(2, LV), 'Find 2');
    CheckEqual(Int64(200), Int64(LV));
    Check(LM.Find(3, LV), 'Find 3');
    CheckEqual(Int64(300), Int64(LV));
    Check(LM.Remove(2), 'Remove 2');
    Check(not LM.Contains(2), 'not Contains after Remove');
    CheckEqual(Int64(2), Int64(LM.Count), 'Count after remove');
  finally
    LM.Free;
  end;
end;

procedure TestHashMapUpdate;
var
  LM: TIntIntMap;
  LV: Integer;
begin
  LM := TIntIntMap.Create;
  try
    LM.Insert(5, 50);
    LM.Insert(5, 55);
    Check(LM.Find(5, LV), 'Find after update');
    CheckEqual(Int64(55), Int64(LV), 'updated value');
    CheckEqual(Int64(1), Int64(LM.Count), 'Count unchanged after update');
  finally
    LM.Free;
  end;
end;

procedure TestHashMapNotFound;
var
  LM: TIntIntMap;
  LV: Integer;
begin
  LM := TIntIntMap.Create;
  try
    Check(not LM.Find(99, LV), 'Find missing key');
    Check(not LM.Contains(99), 'Contains missing key');
    Check(not LM.Remove(99), 'Remove missing key');
  finally
    LM.Free;
  end;
end;

procedure TestHashMapMultipleKeys;
var
  LM: TIntIntMap;
  LV: Integer;
  LI: Integer;
begin
  LM := TIntIntMap.Create;
  try
    for LI := 1 to 100 do
      LM.Insert(LI, LI * 10);
    CheckEqual(Int64(100), Int64(LM.Count), 'Count after 100 inserts');
    for LI := 1 to 100 do
    begin
      Check(LM.Find(LI, LV), 'Find key ' + IntToStr(LI));
      CheckEqual(Int64(LI * 10), Int64(LV), 'value for key ' + IntToStr(LI));
    end;
    for LI := 1 to 50 do
      Check(LM.Remove(LI), 'Remove key ' + IntToStr(LI));
    CheckEqual(Int64(50), Int64(LM.Count), 'Count after 50 removals');
    for LI := 1 to 50 do
      Check(not LM.Contains(LI), 'not Contains removed key ' + IntToStr(LI));
    for LI := 51 to 100 do
      Check(LM.Contains(LI), 'Contains retained key ' + IntToStr(LI));
  finally
    LM.Free;
  end;
end;

procedure TestHashMapZeroCount;
var
  LM: TIntIntMap;
begin
  LM := TIntIntMap.Create;
  try
    CheckEqual(Int64(0), Int64(LM.Count), 'initial Count zero');
  finally
    LM.Free;
  end;
end;

procedure TestHashMapResize;
var
  LM: TIntIntMap;
  LV: Integer;
  LI: Integer;
begin
  LM := TIntIntMap.Create(4);
  try
    for LI := 1 to 20 do
      LM.Insert(LI, LI);
    CheckEqual(Int64(20), Int64(LM.Count), 'Count after 20 inserts (triggers resize)');
    for LI := 1 to 20 do
    begin
      Check(LM.Find(LI, LV), 'Find after resize key ' + IntToStr(LI));
      CheckEqual(Int64(LI), Int64(LV));
    end;
  finally
    LM.Free;
  end;
end;

procedure ForEachCallback(const AKey: Integer; const AValue: Integer);
begin
  Inc(GForEachSum, AValue);
  Inc(GForEachCount);
end;

procedure TestHashMapForEach;
var
  LM: TIntIntMap;
begin
  LM := TIntIntMap.Create;
  try
    LM.Insert(1, 10);
    LM.Insert(2, 20);
    LM.Insert(3, 30);
    GForEachSum := 0;
    GForEachCount := 0;
    LM.ForEach(@ForEachCallback);
    CheckEqual(Int64(3), Int64(GForEachCount), 'ForEach visited 3 items');
    CheckEqual(Int64(60), Int64(GForEachSum), 'ForEach sum of values');
  finally
    LM.Free;
  end;
end;

procedure TestHashMapForEachEmpty;
var
  LM: TIntIntMap;
begin
  LM := TIntIntMap.Create;
  try
    GForEachCount := 0;
    LM.ForEach(@ForEachCallback);
    CheckEqual(Int64(0), Int64(GForEachCount), 'ForEach empty map visits 0');
  finally
    LM.Free;
  end;
end;

type
  PCtxSum = ^TCtxSum;
  TCtxSum = record
    Sum: Integer;
    Count: Integer;
  end;

procedure ForEachCtxCallback(const AKey: Integer; const AValue: Integer; AContext: Pointer);
var
  LCtx: PCtxSum;
begin
  LCtx := PCtxSum(AContext);
  Inc(LCtx^.Sum, AValue);
  Inc(LCtx^.Count);
end;

procedure TestHashMapForEachCtx;
var
  LM: TIntIntMap;
  LCtx: TCtxSum;
begin
  LM := TIntIntMap.Create;
  try
    LM.Insert(1, 10);
    LM.Insert(2, 20);
    LM.Insert(3, 30);
    LCtx.Sum := 0;
    LCtx.Count := 0;
    LM.ForEachCtx(@ForEachCtxCallback, @LCtx);
    CheckEqual(Int64(3), Int64(LCtx.Count), 'ForEachCtx visited 3 items');
    CheckEqual(Int64(60), Int64(LCtx.Sum), 'ForEachCtx sum of values');
  finally
    LM.Free;
  end;
end;

procedure TestHashMapGetOrInsert;
var
  LM: TIntIntMap;
  LRes: TIntIntMap.TGetOrInsertResult;
begin
  LM := TIntIntMap.Create;
  try
    // First insert - should not exist
    LRes := LM.GetOrInsert(42, 100);
    Check(not LRes.Existed, 'GetOrInsert first call: Existed=False');
    CheckEqual(Int64(100), Int64(LRes.Value), 'GetOrInsert first call: Value=100');
    CheckEqual(Int64(1), Int64(LM.Count), 'Count after first GetOrInsert');

    // Second call - should find existing
    LRes := LM.GetOrInsert(42, 999);
    Check(LRes.Existed, 'GetOrInsert second call: Existed=True');
    CheckEqual(Int64(100), Int64(LRes.Value), 'GetOrInsert second call: returns original value');
    CheckEqual(Int64(1), Int64(LM.Count), 'Count unchanged after second GetOrInsert');

    // Different key
    LRes := LM.GetOrInsert(43, 200);
    Check(not LRes.Existed, 'GetOrInsert new key: Existed=False');
    CheckEqual(Int64(200), Int64(LRes.Value), 'GetOrInsert new key: Value=200');
    CheckEqual(Int64(2), Int64(LM.Count), 'Count after second key');
  finally
    LM.Free;
  end;
end;

procedure TestHashMapClear;
var
  LM: TIntIntMap;
  LI: Integer;
begin
  LM := TIntIntMap.Create;
  try
    for LI := 1 to 100 do
      LM.Insert(LI, LI);
    CheckEqual(Int64(100), Int64(LM.Count), 'Count before Clear');
    LM.Clear;
    CheckEqual(Int64(0), Int64(LM.Count), 'Count after Clear');
    for LI := 1 to 100 do
      Check(not LM.Contains(LI), 'not Contains after Clear key ' + IntToStr(LI));

    // Reuse after clear
    LM.Insert(1, 999);
    Check(LM.Contains(1), 'Contains after re-insert');
    CheckEqual(Int64(1), Int64(LM.Count), 'Count after re-insert');
  finally
    LM.Free;
  end;
end;

procedure TestHashMapCloseLifecycle;
var
  LM: TIntIntMap;
  LV: Integer;
  LRes: TIntIntMap.TGetOrInsertResult;
  LRaised: Boolean;
  LOld: Integer;
begin
  LM := TIntIntMap.Create;
  try
    LM.Insert(1, 10);
    LM.Insert(2, 20);
    LM.Close;
    Check(LM.IsClosed, 'IsClosed after Close');
    LM.Close;
    Check(LM.IsClosed, 'Close idempotent');

    Check(LM.Find(1, LV), 'Find after Close');
    CheckEqual(10, LV, 'value after Close');
    Check(LM.Contains(2), 'Contains after Close');
    Check(not LM.TryInsert(3, 30), 'TryInsert after Close fails');
    Check(not LM.Replace(1, 11, LOld), 'Replace after Close fails');

    LRes := LM.GetOrInsert(1, 99);
    Check(LRes.Existed, 'GetOrInsert existing after Close');
    CheckEqual(10, LRes.Value, 'GetOrInsert returns existing after Close');

    LRaised := False;
    try
      LM.Insert(4, 40);
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'Insert after Close raises');

    LRaised := False;
    try
      LRes := LM.GetOrInsert(99, 1);
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'GetOrInsert missing after Close raises');

    Check(LM.Remove(2), 'Remove after Close still works');
    Check(not LM.Contains(2), 'removed after Close');
  finally
    LM.Free;
  end;
end;

function ComputeDouble(const AKey: Integer): Integer;
begin
  Inc(GComputeCallCount);
  Result := AKey * 2;
end;

procedure TestHashMapGetOrInsertFn;
var
  LM: TIntIntMap;
  LRes: TIntIntMap.TGetOrInsertResult;
begin
  LM := TIntIntMap.Create;
  try
    // First call - should compute
    GComputeCallCount := 0;
    LRes := LM.GetOrInsertFn(21, @ComputeDouble);
    Check(not LRes.Existed, 'GetOrInsertFn first call: Existed=False');
    CheckEqual(Int64(42), Int64(LRes.Value), 'GetOrInsertFn first call: Value=42');
    CheckEqual(Int64(1), Int64(GComputeCallCount), 'GetOrInsertFn first call: compute invoked');
    CheckEqual(Int64(1), Int64(LM.Count), 'Count after first GetOrInsertFn');

    // Second call - should NOT compute
    GComputeCallCount := 0;
    LRes := LM.GetOrInsertFn(21, @ComputeDouble);
    Check(LRes.Existed, 'GetOrInsertFn second call: Existed=True');
    CheckEqual(Int64(42), Int64(LRes.Value), 'GetOrInsertFn second call: returns original');
    CheckEqual(Int64(0), Int64(GComputeCallCount), 'GetOrInsertFn second call: compute NOT invoked');
    CheckEqual(Int64(1), Int64(LM.Count), 'Count unchanged after second GetOrInsertFn');

    // Different key - should compute
    GComputeCallCount := 0;
    LRes := LM.GetOrInsertFn(50, @ComputeDouble);
    Check(not LRes.Existed, 'GetOrInsertFn new key: Existed=False');
    CheckEqual(Int64(100), Int64(LRes.Value), 'GetOrInsertFn new key: Value=100');
    CheckEqual(Int64(1), Int64(GComputeCallCount), 'GetOrInsertFn new key: compute invoked');
    CheckEqual(Int64(2), Int64(LM.Count), 'Count after second key');
  finally
    LM.Free;
  end;
end;

var
  GSingleKeyMap: TIntIntMap;
  GSingleKeyComputeCount: Int32;

function SingleKeyCompute(const AKey: Integer): Integer;
begin
  InterlockedIncrement(GSingleKeyComputeCount);
  // Simulate expensive computation
  platform_thread_sleep_ns(5000000);
  Result := AKey * 10;
end;

function SingleKeyRaceWorker(AArg: Pointer): Pointer; cdecl;
var
  LRes: TIntIntMap.TGetOrInsertResult;
begin
  Result := nil;
  LRes := GSingleKeyMap.GetOrInsertFn(42, @SingleKeyCompute);
  CheckEqual(Int64(420), Int64(LRes.Value), 'Single-key race: all threads must see value=420');
end;

procedure TestHashMapGetOrInsertFnSingleKeyRace;
var
  LHandles: array[0..3] of TPlatformThreadHandle;
  LI: Integer;
  LHandleCount: Integer;
begin
  GSingleKeyMap := TIntIntMap.Create;
  GSingleKeyComputeCount := 0;
  LHandleCount := 0;
  try
    for LI := 0 to 3 do
    begin
      StartThread(LHandles[LI], @SingleKeyRaceWorker, nil,
        'Single-key race worker ' + IntToStr(LI));
      Inc(LHandleCount);
    end;
    JoinStartedThreads(LHandles, LHandleCount, 'Single-key race worker');
    CheckEqual(Int64(1), Int64(GSingleKeyMap.Count), 'Single-key race: exactly 1 entry');
    CheckEqual(Int64(1), Int64(GSingleKeyComputeCount), 'Single-key race: compute called exactly once');
  finally
    JoinStartedThreads(LHandles, LHandleCount, 'Single-key race worker');
    GSingleKeyMap.Free;
  end;
end;

function IncrementValue(const AOld: Integer): Integer;
begin
  Result := AOld + 1;
end;

procedure TestHashMapGetOrUpdate;
var
  LM: TIntIntMap;
  LRes: TIntIntMap.TGetOrInsertResult;
begin
  LM := TIntIntMap.Create;
  try
    // First call - key doesn't exist, inserts default=1
    LRes := LM.GetOrUpdate(10, 1, @IncrementValue);
    Check(not LRes.Existed, 'GetOrUpdate first call: Existed=False');
    CheckEqual(Int64(1), Int64(LRes.Value), 'GetOrUpdate first call: Value=1 (default)');
    CheckEqual(Int64(1), Int64(LM.Count), 'Count after first GetOrUpdate');

    // Second call - key exists, increments
    LRes := LM.GetOrUpdate(10, 1, @IncrementValue);
    Check(LRes.Existed, 'GetOrUpdate second call: Existed=True');
    CheckEqual(Int64(2), Int64(LRes.Value), 'GetOrUpdate second call: Value=2 (incremented)');
    CheckEqual(Int64(1), Int64(LM.Count), 'Count unchanged');

    // Third call - increments again
    LRes := LM.GetOrUpdate(10, 1, @IncrementValue);
    Check(LRes.Existed, 'GetOrUpdate third call: Existed=True');
    CheckEqual(Int64(3), Int64(LRes.Value), 'GetOrUpdate third call: Value=3');

    // Different key - inserts default
    LRes := LM.GetOrUpdate(20, 100, @IncrementValue);
    Check(not LRes.Existed, 'GetOrUpdate new key: Existed=False');
    CheckEqual(Int64(100), Int64(LRes.Value), 'GetOrUpdate new key: Value=100 (default)');
    CheckEqual(Int64(2), Int64(LM.Count), 'Count after second key');
  finally
    LM.Free;
  end;
end;

procedure TestHashMapTryInsert;
var
  LM: TIntIntMap;
  LV: Integer;
begin
  LM := TIntIntMap.Create;
  try
    // First insert - should succeed
    Check(LM.TryInsert(1, 100), 'TryInsert new key succeeds');
    Check(LM.Find(1, LV), 'Find after TryInsert');
    CheckEqual(Int64(100), Int64(LV), 'value after TryInsert');
    CheckEqual(Int64(1), Int64(LM.Count), 'Count after TryInsert');

    // Second insert same key - should fail
    Check(not LM.TryInsert(1, 999), 'TryInsert existing key fails');
    Check(LM.Find(1, LV), 'Find after failed TryInsert');
    CheckEqual(Int64(100), Int64(LV), 'value unchanged after failed TryInsert');
    CheckEqual(Int64(1), Int64(LM.Count), 'Count unchanged after failed TryInsert');

    // Different key - should succeed
    Check(LM.TryInsert(2, 200), 'TryInsert different key succeeds');
    CheckEqual(Int64(2), Int64(LM.Count), 'Count after second TryInsert');
  finally
    LM.Free;
  end;
end;

procedure TestHashMapRemoveWithOldValue;
var
  LM: TIntIntMap;
  LV: Integer;
begin
  LM := TIntIntMap.Create;
  try
    LM.Insert(1, 100);
    LM.Insert(2, 200);

    // Remove existing - returns old value
    Check(LM.Remove(1, LV), 'Remove existing key');
    CheckEqual(Int64(100), Int64(LV), 'returned old value');
    Check(not LM.Contains(1), 'key removed');
    CheckEqual(Int64(1), Int64(LM.Count), 'Count after Remove');

    // Remove non-existing - returns false
    Check(not LM.Remove(99, LV), 'Remove non-existing key returns false');
    CheckEqual(Int64(1), Int64(LM.Count), 'Count unchanged');
  finally
    LM.Free;
  end;
end;

procedure TestHashMapReplace;
var
  LM: TIntIntMap;
  LV: Integer;
begin
  LM := TIntIntMap.Create;
  try
    LM.Insert(1, 100);

    // Replace existing - returns old value
    Check(LM.Replace(1, 200, LV), 'Replace existing key');
    CheckEqual(Int64(100), Int64(LV), 'returned old value');
    Check(LM.Find(1, LV), 'Find after Replace');
    CheckEqual(Int64(200), Int64(LV), 'new value after Replace');
    CheckEqual(Int64(1), Int64(LM.Count), 'Count unchanged');

    // Replace non-existing - returns false
    Check(not LM.Replace(99, 300, LV), 'Replace non-existing returns false');
  finally
    LM.Free;
  end;
end;

{ --- Selector tests --- }

procedure TestSelectorBasic;
var
  LCh1, LCh2: TIntChannel;
  LSel: TIntSelector;
  LResult: TSelectResult;
  LVal: Integer;
begin
  LCh1 := TIntChannel.Create(4);
  LCh2 := TIntChannel.Create(4);
  LSel := TIntSelector.Create;
  try
    // Ch1 有数据，Ch2 空 → 应该选中 Ch1 recv
    LCh1.Send(42);
    LSel.AddRecv(LCh1, LVal);
    LSel.AddRecv(LCh2, LVal);
    LResult := LSel.Select;
    Check(LResult.Completed, 'select completes');
    CheckEqual(Int64(0), Int64(LResult.Index), 'selects Ch1 (index 0)');
    CheckEqual(Int64(42), Int64(LVal), 'received value 42');
  finally
    LSel.Free;
    LCh2.Free;
    LCh1.Free;
  end;
end;

procedure TestSelectorSend;
var
  LCh1: TIntChannel;
  LSel: TIntSelector;
  LResult: TSelectResult;
  LVal: Integer;
begin
  LCh1 := TIntChannel.Create(4);
  LSel := TIntSelector.Create;
  try
    LSel.AddSend(LCh1, 99);
    LResult := LSel.Select;
    Check(LResult.Completed, 'send completes');
    CheckEqual(Int64(0), Int64(LResult.Index), 'send index 0');
    Check(LCh1.TryReceive(LVal), 'can receive sent value');
    CheckEqual(Int64(99), Int64(LVal), 'sent value is 99');
  finally
    LSel.Free;
    LCh1.Free;
  end;
end;

procedure TestSelectorTimeout;
var
  LCh1: TIntChannel;
  LSel: TIntSelector;
  LResult: TSelectResult;
  LVal: Integer;
begin
  LCh1 := TIntChannel.Create(4);
  LSel := TIntSelector.Create;
  try
    // 空 channel，超时应返回 false
    LSel.AddRecv(LCh1, LVal);
    LResult := LSel.SelectTimeout(10000000); // 10ms
    Check(not LResult.Completed, 'timeout returns not completed');
    CheckEqual(Int64(-1), Int64(LResult.Index), 'timeout index is -1');

    // 超时前有数据到达
    LCh1.Send(77);
    LResult := LSel.SelectTimeout(1000000000); // 1s
    Check(LResult.Completed, 'data arrives before timeout');
    CheckEqual(Int64(77), Int64(LVal), 'received value before timeout');
  finally
    LSel.Free;
    LCh1.Free;
  end;
end;

procedure TestSelectorMultiChannel;
var
  LCh1, LCh2, LCh3: TIntChannel;
  LSel: TIntSelector;
  LResult: TSelectResult;
  LVal: Integer;
begin
  LCh1 := TIntChannel.Create(4);
  LCh2 := TIntChannel.Create(4);
  LCh3 := TIntChannel.Create(4);
  LSel := TIntSelector.Create;
  try
    // 只有 Ch3 有数据
    LCh3.Send(55);
    LSel.AddRecv(LCh1, LVal);
    LSel.AddRecv(LCh2, LVal);
    LSel.AddRecv(LCh3, LVal);
    LResult := LSel.Select;
    Check(LResult.Completed, 'select completes');
    CheckEqual(Int64(2), Int64(LResult.Index), 'selects Ch3 (index 2)');
    CheckEqual(Int64(55), Int64(LVal), 'received value 55');
  finally
    LSel.Free;
    LCh3.Free;
    LCh2.Free;
    LCh1.Free;
  end;
end;

procedure TestSelectorClearReuse;
var
  LCh1, LCh2: TIntChannel;
  LSel: TIntSelector;
  LResult: TSelectResult;
  LVal: Integer;
begin
  LCh1 := TIntChannel.Create(4);
  LCh2 := TIntChannel.Create(4);
  LSel := TIntSelector.Create;
  try
    LCh1.Send(10);
    LSel.AddRecv(LCh1, LVal);
    LResult := LSel.Select;
    Check(LResult.Completed, 'first select completes');
    CheckEqual(Int64(10), Int64(LVal), 'first select value');

    // Clear + 重新注册
    LSel.Clear;
    CheckEqual(Int64(0), Int64(LSel.CaseCount), 'clear sets count to 0');
    LCh2.Send(20);
    LSel.AddRecv(LCh2, LVal);
    LResult := LSel.Select;
    Check(LResult.Completed, 'second select completes');
    CheckEqual(Int64(0), Int64(LResult.Index), 'second select index 0');
    CheckEqual(Int64(20), Int64(LVal), 'second select value');
  finally
    LSel.Free;
    LCh2.Free;
    LCh1.Free;
  end;
end;

procedure TestSelectorSendFull;
var
  LCh1: TIntChannel;
  LSel: TIntSelector;
  LResult: TSelectResult;
  LVal: Integer;
begin
  // 测试 selector 在满 channel 上超时
  LCh1 := TIntChannel.Create(2);
  LSel := TIntSelector.Create;
  try
    // 填满 channel
    LCh1.Send(1);
    LCh1.Send(2);
    // send 到满 channel → 应超时
    LSel.AddSend(LCh1, 3);
    LResult := LSel.SelectTimeout(10000000); // 10ms
    Check(not LResult.Completed, 'send to full channel times out');
    CheckEqual(Int64(-1), Int64(LResult.Index), 'timeout index -1');

    // Clear + 清空 channel 后重试
    LSel.Clear;
    while LCh1.TryReceive(LVal) do ; // 排空
    LSel.AddSend(LCh1, 3);
    LResult := LSel.SelectTimeout(1000000000); // 1s
    Check(LResult.Completed, 'send succeeds after drain');
    Check(LCh1.TryReceive(LVal), 'can receive sent value');
    CheckEqual(Int64(3), Int64(LVal), 'sent value is 3');
  finally
    LSel.Free;
    LCh1.Free;
  end;
end;

procedure TestSelectorNilChannelReject;
var
  LSel: TIntSelector;
  LVal: Integer;
  LCaught: Boolean;
begin
  LSel := TIntSelector.Create;
  try
    LCaught := False;
    try
      LSel.AddRecv(TIntChannel(nil), LVal);
    except
      on E: EArgumentError do
        LCaught := True;
    end;
    Check(LCaught, 'nil channel recv raises EArgumentError');

    LCaught := False;
    try
      LSel.AddSend(TIntChannel(nil), 42);
    except
      on E: EArgumentError do
        LCaught := True;
    end;
    Check(LCaught, 'nil channel send raises EArgumentError');
  finally
    LSel.Free;
  end;
end;

procedure TestChannelCapacityEnforce;
var
  LCh: TIntChannel;
  LI: Integer;
  LVal: Integer;
begin
  // 容量=2 的 channel，只允许 2 个 send，第 3 个必须失败
  LCh := TIntChannel.Create(2);
  try
    Check(LCh.TrySend(1), 'send 1 succeeds');
    Check(LCh.TrySend(2), 'send 2 succeeds');
    Check(not LCh.TrySend(3), 'send 3 rejected (capacity full)');
    Check(not LCh.TrySend(4), 'send 4 also rejected');

    // 消费后可以继续发送
    Check(LCh.TryReceive(LVal), 'receive succeeds');
    CheckEqual(Int64(1), Int64(LVal), 'received value 1');
    Check(LCh.TrySend(3), 'send 3 now succeeds after drain');
    Check(not LCh.TrySend(4), 'send 4 still rejected');

    // 多轮循环验证
    for LI := 0 to 9 do
    begin
      Check(LCh.TryReceive(LVal), 'cycle receive ' + IntToStr(LI));
      Check(LCh.TrySend(10 + LI), 'cycle send ' + IntToStr(LI));
      Check(not LCh.TrySend(99), 'cycle rejected at ' + IntToStr(LI));
    end;
  finally
    LCh.Free;
  end;
end;

procedure TestSegQueueBasic;
var
  LQ: TIntSegQueue;
  LI: Integer;
  LV: Integer;
begin
  LQ := TIntSegQueue.Create;
  try
    Check(LQ.IsEmpty, 'empty initially');
    CheckEqual(Int64(0), Int64(LQ.ApproxCount), 'count 0 initially');
    Check(not LQ.TryDequeue(LV), 'empty TryDequeue returns false');

    for LI := 1 to 100 do
      LQ.Enqueue(LI);

    Check(not LQ.IsEmpty, 'not empty after enqueue');
    CheckEqual(Int64(100), Int64(LQ.ApproxCount), 'count 100');

    for LI := 1 to 100 do
    begin
      Check(LQ.TryDequeue(LV), 'dequeue ' + IntToStr(LI));
      CheckEqual(Int64(LI), Int64(LV), 'FIFO order at ' + IntToStr(LI));
    end;

    Check(LQ.IsEmpty, 'empty after drain');
    Check(not LQ.TryDequeue(LV), 'empty after drain TryDequeue');
  finally
    LQ.Free;
  end;
end;

procedure TestSegQueueSegmentRollover;
var
  LQ: TIntSegQueue;
  LI: Integer;
  LV: Integer;
  LCount: Integer;
begin
  LCount := SEGQUEUE_SEGMENT_CAPACITY * 4 + 3;
  LQ := TIntSegQueue.Create;
  try
    for LI := 1 to LCount do
      LQ.Enqueue(LI);

    CheckEqual(Int64(LCount), Int64(LQ.ApproxCount), 'count after multi-segment enqueue');

    for LI := 1 to LCount do
    begin
      Check(LQ.TryDequeue(LV), 'dequeue ' + IntToStr(LI) + ' of ' + IntToStr(LCount));
      CheckEqual(Int64(LI), Int64(LV), 'FIFO across segments at ' + IntToStr(LI));
    end;

    Check(LQ.IsEmpty, 'empty after multi-segment drain');
  finally
    LQ.Free;
  end;
end;

procedure TestSegQueueEmpty;
var
  LQ: TIntSegQueue;
  LV: Integer;
begin
  LQ := TIntSegQueue.Create;
  try
    Check(not LQ.TryDequeue(LV), 'empty TryDequeue returns false');
  finally
    LQ.Free;
  end;
end;

procedure TestSegQueueApproxCount;
var
  LQ: TIntSegQueue;
  LI: Integer;
  LV: Integer;
begin
  LQ := TIntSegQueue.Create;
  try
    for LI := 1 to 50 do
      LQ.Enqueue(LI);
    CheckEqual(Int64(50), Int64(LQ.ApproxCount), 'count 50');

    for LI := 1 to 25 do
      LQ.TryDequeue(LV);
    CheckEqual(Int64(25), Int64(LQ.ApproxCount), 'count 25 after dequeue');

    while LQ.TryDequeue(LV) do ;
    CheckEqual(Int64(0), Int64(LQ.ApproxCount), 'count 0 after drain');
  finally
    LQ.Free;
  end;
end;

var
  GSegQueueQ: TIntSegQueue;

function SegQueueProducer(AArg: Pointer): Pointer; cdecl;
var
  LI, LStart: Integer;
begin
  Result := nil;
  LStart := Integer(PtrUInt(AArg));
  for LI := LStart to LStart + 249 do
    GSegQueueQ.Enqueue(LI);
end;

procedure TestSegQueueMultiProducer;
var
  LHandles: array[0..3] of TPlatformThreadHandle;
  LI, LV: Integer;
  LSum: Int64;
  LCount: Integer;
  LHandleCount: Integer;
begin
  GSegQueueQ := TIntSegQueue.Create;
  LHandleCount := 0;
  try
    for LI := 0 to 3 do
    begin
      StartThread(LHandles[LI], @SegQueueProducer, Pointer(PtrInt(LI * 250 + 1)), 'SegQueue producer thread');
      Inc(LHandleCount);
    end;
    JoinStartedThreads(LHandles, LHandleCount, 'SegQueue producer thread');
    LSum := 0;
    LCount := 0;
    while GSegQueueQ.TryDequeue(LV) do
    begin
      Inc(LSum, Int64(LV));
      Inc(LCount);
    end;
    CheckEqual(Int64(1000), Int64(LCount), 'SegQueue 4P must dequeue all 1000 items');
    CheckEqual(Int64(500500), LSum, 'SegQueue 4P sum 1+2+...+1000');
  finally
    JoinStartedThreads(LHandles, LHandleCount, 'SegQueue producer thread');
    GSegQueueQ.Free;
  end;
end;

var
  GSegQueueMpmcSum: Int64;
  GSegQueueMpmcCount: Int64;
  GSegQueueMpmcStop: Int32;

function SegQueueConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
  LSum: Int64;
  LCount: Int64;
begin
  Result := nil;
  LSum := 0;
  LCount := 0;
  while (atomic_load(GSegQueueMpmcStop, mo_relaxed) = 0) or (not GSegQueueQ.IsEmpty) do
  begin
    if GSegQueueQ.TryDequeue(LV) then
    begin
      Inc(LSum, Int64(LV));
      Inc(LCount);
    end
    else
      CpuPause;
  end;
  atomic_fetch_add_64(GSegQueueMpmcSum, LSum, mo_relaxed);
  atomic_fetch_add_64(GSegQueueMpmcCount, LCount, mo_relaxed);
end;

procedure TestSegQueueMpmc;
const
  ITEMS_PER_PRODUCER = 250;
  PRODUCER_COUNT = 4;
  CONSUMER_COUNT = 4;
var
  LProducers: array[0..PRODUCER_COUNT - 1] of TPlatformThreadHandle;
  LConsumers: array[0..CONSUMER_COUNT - 1] of TPlatformThreadHandle;
  LI: Integer;
  LProducerCount, LConsumerCount: Integer;
begin
  GSegQueueQ := TIntSegQueue.Create;
  atomic_store_64(GSegQueueMpmcSum, 0, mo_relaxed);
  atomic_store_64(GSegQueueMpmcCount, 0, mo_relaxed);
  atomic_store(GSegQueueMpmcStop, 0, mo_release);
  LProducerCount := 0;
  LConsumerCount := 0;
  try
    for LI := 0 to CONSUMER_COUNT - 1 do
    begin
      StartThread(LConsumers[LI], @SegQueueConsumer, nil, 'SegQueue consumer thread');
      Inc(LConsumerCount);
    end;
    for LI := 0 to PRODUCER_COUNT - 1 do
    begin
      StartThread(LProducers[LI], @SegQueueProducer, Pointer(PtrInt(LI * ITEMS_PER_PRODUCER + 1)), 'SegQueue producer thread');
      Inc(LProducerCount);
    end;
    JoinStartedThreads(LProducers, LProducerCount, 'SegQueue producer thread');
    atomic_store(GSegQueueMpmcStop, 1, mo_release);
    JoinStartedThreads(LConsumers, LConsumerCount, 'SegQueue consumer thread');
    CheckEqual(Int64(PRODUCER_COUNT * ITEMS_PER_PRODUCER), atomic_load_64(GSegQueueMpmcCount, mo_relaxed),
      'SegQueue MPMC total items consumed');
    CheckEqual(Int64(500500), atomic_load_64(GSegQueueMpmcSum, mo_relaxed),
      'SegQueue MPMC sum 1+2+...+1000');
  finally
    atomic_store(GSegQueueMpmcStop, 1, mo_release);
    JoinStartedThreads(LProducers, LProducerCount, 'SegQueue producer thread');
    JoinStartedThreads(LConsumers, LConsumerCount, 'SegQueue consumer thread');
    GSegQueueQ.Free;
  end;
end;

procedure TestSegQueueDestroyActiveSegments;
var
  LQ: TIntSegQueue;
  LI, LV: Integer;
  LCount: Integer;
begin
  LQ := TIntSegQueue.Create;
  try
    for LI := 1 to SEGQUEUE_SEGMENT_CAPACITY * 3 + 5 do
      LQ.Enqueue(LI);
    LCount := 0;
    while LQ.TryDequeue(LV) do
      Inc(LCount);
    CheckEqual(SEGQUEUE_SEGMENT_CAPACITY * 3 + 5, LCount, 'SegQueue must drain all items across segments');
  finally
    LQ.Free;
  end;
end;

procedure TestSpmcBasic;
var
  LQ: TIntSpmc;
  LV: Integer;
begin
  LQ := TIntSpmc.Create(4);
  Check(LQ.TryEnqueue(10), 'enq 1');
  Check(LQ.TryEnqueue(20), 'enq 2');
  Check(LQ.TryEnqueue(30), 'enq 3');
  Check(LQ.TryDequeue(LV), 'deq 1');
  CheckEqual(Int64(10), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 2');
  CheckEqual(Int64(20), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 3');
  CheckEqual(Int64(30), Int64(LV));
  Check(not LQ.TryDequeue(LV), 'empty');
  LQ.Free;
end;

procedure TestSpmcCapacity;
var
  LQ: TIntSpmc;
begin
  LQ := TIntSpmc.Create(5);
  CheckEqual(Int64(8), Int64(LQ.Capacity), 'capacity rounds to pow2');
  LQ.Free;
end;

procedure TestSpmcFullEmpty;
var
  LQ: TIntSpmc;
  LV: Integer;
begin
  LQ := TIntSpmc.Create(2);
  Check(LQ.IsEmpty, 'initially empty');
  Check(not LQ.IsFull, 'initially not full');
  Check(LQ.TryEnqueue(1), 'enq 1');
  Check(LQ.TryEnqueue(2), 'enq 2');
  Check(LQ.TryDequeue(LV), 'deq 1');
  CheckEqual(Int64(1), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 2');
  CheckEqual(Int64(2), Int64(LV));
  Check(LQ.IsEmpty, 'empty after drain');
  LQ.Free;
end;

procedure TestSpmcWrapAround;
var
  LQ: TIntSpmc;
  LI: Integer;
  LV: Integer;
begin
  LQ := TIntSpmc.Create(2);
  try
    for LI := 1 to 16 do
    begin
      Check(LQ.TryEnqueue(LI), 'SPMC wrap enqueue ' + IntToStr(LI));
      Check(LQ.TryDequeue(LV), 'SPMC wrap dequeue ' + IntToStr(LI));
      CheckEqual(Int64(LI), Int64(LV), 'SPMC wrap order ' + IntToStr(LI));
    end;
    Check(LQ.IsEmpty, 'SPMC wrap leaves queue empty');
  finally
    LQ.Free;
  end;
end;

var
  GSpmcSpaceWakeQ: TIntSpmc;
  GSpmcSpaceWakeConsumerStarted: Int32;
  GSpmcSpaceWakeConsumerResult: Int32;
  GSpmcSpaceWakeConsumerValue: Integer;

function SpmcSpaceWakeConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  atomic_store(GSpmcSpaceWakeConsumerStarted, 1, mo_release);
  platform_thread_sleep_ns(QueuePublishWakeDelayNs);
  if GSpmcSpaceWakeQ.TryDequeue(LV) then
  begin
    GSpmcSpaceWakeConsumerValue := LV;
    atomic_store(GSpmcSpaceWakeConsumerResult, 1, mo_release);
  end
  else
    atomic_store(GSpmcSpaceWakeConsumerResult, 0, mo_release);
end;

procedure TestSpmcEnqueueTimeoutOnFull;
var
  LQ: TIntSpmc;
  LElapsedMs: QWord;
  LV: Integer;
begin
  LQ := TIntSpmc.Create(1);
  try
    Check(LQ.TryEnqueue(1), 'SPMC full-timeout test must fill the queue');
    LElapsedMs := TestMonotonicMs;
    Check(not LQ.EnqueueTimeout(2, 1000000),
      'SPMC EnqueueTimeout must return false on a full single-slot queue');
    LElapsedMs := TestMonotonicMs - LElapsedMs;
    Check(LElapsedMs < WaitHelperImmediateReturnBudgetMs,
      'SPMC EnqueueTimeout on full must return promptly instead of spinning forever');
    Check(LQ.TryDequeue(LV), 'SPMC full-timeout test must preserve the queued item');
    CheckEqual(Int64(1), Int64(LV));
    Check(not LQ.TryDequeue(LV), 'SPMC full-timeout test must leave the queue drained after the preserved item');
  finally
    LQ.Free;
  end;
end;

procedure TestSpmcEnqueueTimeoutOnSpace;
var
  LQ: TIntSpmc;
  LConsumer: TPlatformThreadHandle;
  LRetVal: Pointer;
  LElapsedMs: QWord;
  LSpin: Integer;
  LV: Integer;
  LThreadCreated: Boolean;
  LJoined: Boolean;
begin
  LQ := TIntSpmc.Create(1);
  LThreadCreated := False;
  LJoined := False;
  try
    Check(LQ.TryEnqueue(1), 'SPMC queue must be full before the space-release consumer starts');
    GSpmcSpaceWakeQ := LQ;
    atomic_store(GSpmcSpaceWakeConsumerStarted, 0, mo_release);
    atomic_store(GSpmcSpaceWakeConsumerResult, -1, mo_release);
    GSpmcSpaceWakeConsumerValue := 0;
    StartThread(LConsumer, @SpmcSpaceWakeConsumer, nil, 'SPMC space wake consumer thread');
    LThreadCreated := True;

    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GSpmcSpaceWakeConsumerStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GSpmcSpaceWakeConsumerStarted, mo_acquire)),
      'SPMC space-release consumer thread must start before EnqueueTimeout waits');

    LElapsedMs := TestMonotonicMs;
    Check(LQ.EnqueueTimeout(42, QueuePublishWakeTimeoutNs),
      'SPMC EnqueueTimeout must succeed after a consumer releases space');
    LElapsedMs := TestMonotonicMs - LElapsedMs;

    JoinThread(LConsumer, LRetVal, 'SPMC space wake consumer thread');
    LJoined := True;
    CheckEqual(Int64(1), Int64(atomic_load(GSpmcSpaceWakeConsumerResult, mo_acquire)),
      'SPMC background consumer must release space for the waiting producer');
    CheckEqual(Int64(1), Int64(GSpmcSpaceWakeConsumerValue));
    Check(LElapsedMs < QueuePublishWakeBudgetMs,
      'SPMC EnqueueTimeout must publish after space release before the full timeout');
    Check(LQ.TryDequeue(LV), 'SPMC space-woken producer item must be drainable');
    CheckEqual(Int64(42), Int64(LV));
    Check(not LQ.TryDequeue(LV), 'SPMC queue must be empty after draining the space-woken item');
  finally
    if LThreadCreated and (not LJoined) then
      JoinThread(LConsumer, LRetVal, 'SPMC space wake consumer thread');
    GSpmcSpaceWakeQ := nil;
    LQ.Free;
  end;
end;

procedure TestSpmcDequeueTimeoutOnEmpty;
var
  LQ: TIntSpmc;
  LElapsedMs: QWord;
  LV: Integer;
begin
  LQ := TIntSpmc.Create(1);
  try
    LElapsedMs := TestMonotonicMs;
    Check(not LQ.DequeueTimeout(LV, 1000000),
      'SPMC DequeueTimeout must return false on an empty single-slot queue');
    LElapsedMs := TestMonotonicMs - LElapsedMs;
    Check(LElapsedMs < WaitHelperImmediateReturnBudgetMs,
      'SPMC DequeueTimeout on empty must return promptly');
    Check(LQ.IsEmpty, 'SPMC empty-timeout test must leave the queue empty');
  finally
    LQ.Free;
  end;
end;

procedure TestSpmcApproxCount;
var
  LQ: TIntSpmc;
  LV: Integer;
begin
  LQ := TIntSpmc.Create(4);
  try
    CheckEqual(Int64(0), Int64(LQ.ApproxCount), 'SPMC approx count initial 0');
    LQ.TryEnqueue(1);
    LQ.TryEnqueue(2);
    CheckEqual(Int64(2), Int64(LQ.ApproxCount), 'SPMC approx count after 2 enqueues');
    LQ.TryDequeue(LV);
    CheckEqual(Int64(1), Int64(LQ.ApproxCount), 'SPMC approx count after 1 dequeue');
    while LQ.TryDequeue(LV) do ;
    CheckEqual(Int64(0), Int64(LQ.ApproxCount), 'SPMC approx count after drain');
  finally
    LQ.Free;
  end;
end;

var
  GSpmcEnqWaitQ: TIntSpmc;
  GSpmcEnqWaitConsumerStarted: Int32;
  GSpmcEnqWaitConsumerResult: Int32;
  GSpmcEnqWaitConsumerValue: Integer;

function SpmcEnqWaitConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  atomic_store(GSpmcEnqWaitConsumerStarted, 1, mo_release);
  platform_thread_sleep_ns(QueuePublishWakeDelayNs);
  if GSpmcEnqWaitQ.TryDequeue(LV) then
  begin
    GSpmcEnqWaitConsumerValue := LV;
    atomic_store(GSpmcEnqWaitConsumerResult, 1, mo_release);
  end
  else
    atomic_store(GSpmcEnqWaitConsumerResult, 0, mo_release);
end;

procedure TestSpmcEnqueueWaitWake;
var
  LQ: TIntSpmc;
  LConsumer: TPlatformThreadHandle;
  LRetVal: Pointer;
  LElapsedMs: QWord;
  LSpin: Integer;
  LV: Integer;
  LThreadCreated: Boolean;
  LJoined: Boolean;
begin
  LQ := TIntSpmc.Create(1);
  LThreadCreated := False;
  LJoined := False;
  try
    Check(LQ.TryEnqueue(1), 'SPMC EnqueueWait fill queue');
    GSpmcEnqWaitQ := LQ;
    atomic_store(GSpmcEnqWaitConsumerStarted, 0, mo_release);
    atomic_store(GSpmcEnqWaitConsumerResult, -1, mo_release);
    GSpmcEnqWaitConsumerValue := 0;
    StartThread(LConsumer, @SpmcEnqWaitConsumer, nil, 'SPMC EnqueueWait consumer thread');
    LThreadCreated := True;

    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GSpmcEnqWaitConsumerStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GSpmcEnqWaitConsumerStarted, mo_acquire)),
      'SPMC EnqueueWait consumer must start before producer waits');

    LElapsedMs := TestMonotonicMs;
    Check(LQ.EnqueueWait(42), 'SPMC EnqueueWait must succeed after consumer frees space');
    LElapsedMs := TestMonotonicMs - LElapsedMs;

    JoinThread(LConsumer, LRetVal, 'SPMC EnqueueWait consumer thread');
    LJoined := True;
    CheckEqual(Int64(1), Int64(atomic_load(GSpmcEnqWaitConsumerResult, mo_acquire)),
      'SPMC EnqueueWait consumer must have dequeued the original item');
    CheckEqual(Int64(1), Int64(GSpmcEnqWaitConsumerValue));
    Check(LElapsedMs < QueuePublishWakeBudgetMs,
      'SPMC EnqueueWait must publish after space release before the full timeout');
    Check(LQ.TryDequeue(LV), 'SPMC EnqueueWait woken item must be drainable');
    CheckEqual(Int64(42), Int64(LV));
    Check(not LQ.TryDequeue(LV), 'SPMC queue must be empty after draining the EnqueueWait item');
  finally
    if LThreadCreated and (not LJoined) then
      JoinThread(LConsumer, LRetVal, 'SPMC EnqueueWait consumer thread');
    GSpmcEnqWaitQ := nil;
    LQ.Free;
  end;
end;

var
  GSpmcDeqWaitQ: TIntSpmc;
  GSpmcDeqWaitProducerStarted: Int32;
  GSpmcDeqWaitProducerResult: Int32;

function SpmcDeqWaitProducer(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  atomic_store(GSpmcDeqWaitProducerStarted, 1, mo_release);
  platform_thread_sleep_ns(QueuePublishWakeDelayNs);
  if GSpmcDeqWaitQ.TryEnqueue(99) then
    atomic_store(GSpmcDeqWaitProducerResult, 1, mo_release)
  else
    atomic_store(GSpmcDeqWaitProducerResult, 0, mo_release);
end;

procedure TestSpmcDequeueWaitWake;
var
  LQ: TIntSpmc;
  LProducer: TPlatformThreadHandle;
  LRetVal: Pointer;
  LElapsedMs: QWord;
  LSpin: Integer;
  LV: Integer;
  LThreadCreated: Boolean;
  LJoined: Boolean;
begin
  LQ := TIntSpmc.Create(4);
  LThreadCreated := False;
  LJoined := False;
  try
    GSpmcDeqWaitQ := LQ;
    atomic_store(GSpmcDeqWaitProducerStarted, 0, mo_release);
    atomic_store(GSpmcDeqWaitProducerResult, -1, mo_release);
    StartThread(LProducer, @SpmcDeqWaitProducer, nil, 'SPMC DequeueWait producer thread');
    LThreadCreated := True;

    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GSpmcDeqWaitProducerStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GSpmcDeqWaitProducerStarted, mo_acquire)),
      'SPMC DequeueWait producer must start before consumer waits');

    LElapsedMs := TestMonotonicMs;
    Check(LQ.DequeueWait(LV), 'SPMC DequeueWait must succeed after producer publishes');
    LElapsedMs := TestMonotonicMs - LElapsedMs;
    CheckEqual(Int64(99), Int64(LV));

    JoinThread(LProducer, LRetVal, 'SPMC DequeueWait producer thread');
    LJoined := True;
    CheckEqual(Int64(1), Int64(atomic_load(GSpmcDeqWaitProducerResult, mo_acquire)),
      'SPMC DequeueWait background producer must have published');
    Check(LElapsedMs < QueuePublishWakeBudgetMs,
      'SPMC DequeueWait must wake after data publish before the full timeout');
    Check(not LQ.TryDequeue(LV), 'SPMC queue must be empty after DequeueWait consumed the item');
  finally
    if LThreadCreated and (not LJoined) then
      JoinThread(LProducer, LRetVal, 'SPMC DequeueWait producer thread');
    GSpmcDeqWaitQ := nil;
    LQ.Free;
  end;
end;

procedure TestSpmcDequeueTimeoutOnData;
var
  LQ: TIntSpmc;
  LV: Integer;
begin
  LQ := TIntSpmc.Create(4);
  try
    Check(LQ.TryEnqueue(77), 'SPMC dequeue-timeout-data seed');
    Check(LQ.DequeueTimeout(LV, 1000000), 'SPMC DequeueTimeout must return immediately with data');
    CheckEqual(Int64(77), Int64(LV));
    Check(not LQ.TryDequeue(LV), 'SPMC queue must be empty after DequeueTimeout consumed');
  finally
    LQ.Free;
  end;
end;

{ MPSC TryEnqueue + ApproxCount }

procedure TestMpscTryEnqueue;
var
  LQ: TIntMpsc;
  LV: Integer;
begin
  LQ := TIntMpsc.Create;
  try
    Check(LQ.TryEnqueue(10), 'TryEnqueue 1');
    Check(LQ.TryEnqueue(20), 'TryEnqueue 2');
    CheckEqual(Int64(2), Int64(LQ.ApproxCount), 'ApproxCount 2');
    LQ.Close;
    Check(not LQ.TryEnqueue(30), 'TryEnqueue after close rejected');
    Check(LQ.TryDequeue(LV), 'drain 1');
    CheckEqual(Int64(10), Int64(LV));
    Check(LQ.TryDequeue(LV), 'drain 2');
    CheckEqual(Int64(20), Int64(LV));
    CheckEqual(Int64(0), Int64(LQ.ApproxCount), 'ApproxCount 0 after drain');
  finally
    LQ.Free;
  end;
end;

{ MPSC boundary conditions }

procedure TestMpscTryDequeueEmpty;
var
  LQ: TIntMpsc;
  LV: Integer;
begin
  LQ := TIntMpsc.Create;
  try
    Check(not LQ.TryDequeue(LV), 'dequeue from empty returns false');
  finally
    LQ.Free;
  end;
end;

procedure TestMpscTryDequeueClosed;
var
  LQ: TIntMpsc;
  LV: Integer;
begin
  LQ := TIntMpsc.Create;
  try
    LQ.TryEnqueue(1);
    LQ.Close;
    Check(LQ.TryDequeue(LV), 'dequeue from closed with data succeeds');
    CheckEqual(1, LV, 'dequeued value matches');
    Check(not LQ.TryDequeue(LV), 'dequeue from closed empty returns false');
  finally
    LQ.Free;
  end;
end;

{ SegQueue TryEnqueue + Close }

procedure TestSegQueueTryEnqueueClose;
var
  LQ: TIntSegQueue;
  LV: Integer;
begin
  LQ := TIntSegQueue.Create;
  try
    Check(not LQ.IsClosed, 'not closed initially');
    Check(LQ.TryEnqueue(10), 'TryEnqueue 1');
    Check(LQ.TryEnqueue(20), 'TryEnqueue 2');
    LQ.Close;
    Check(LQ.IsClosed, 'closed after Close');
    Check(not LQ.TryEnqueue(30), 'TryEnqueue after close rejected');
    Check(LQ.TryDequeue(LV), 'drain 1');
    CheckEqual(Int64(10), Int64(LV));
    Check(LQ.TryDequeue(LV), 'drain 2');
    CheckEqual(Int64(20), Int64(LV));
    Check(not LQ.TryDequeue(LV), 'empty after drain');
  finally
    LQ.Free;
  end;
end;

{ SPMC Close }

procedure TestSpmcClose;
var
  LQ: TIntSpmc;
  LV: Integer;
begin
  LQ := TIntSpmc.Create(4);
  try
    Check(not LQ.IsClosed, 'not closed initially');
    Check(LQ.TryEnqueue(10), 'enqueue 1');
    Check(LQ.TryEnqueue(20), 'enqueue 2');
    LQ.Close;
    Check(LQ.IsClosed, 'closed after Close');
    Check(not LQ.TryEnqueue(30), 'TryEnqueue after close rejected');
    Check(not LQ.EnqueueWait(30), 'EnqueueWait after close rejected');
    Check(not LQ.EnqueueTimeout(30, 1000000), 'EnqueueTimeout after close rejected');
    Check(LQ.TryDequeue(LV), 'drain 1');
    CheckEqual(Int64(10), Int64(LV));
    Check(LQ.TryDequeue(LV), 'drain 2');
    CheckEqual(Int64(20), Int64(LV));
    Check(not LQ.TryDequeue(LV), 'empty after drain');
    Check(not LQ.DequeueWait(LV), 'DequeueWait on closed empty');
    Check(not LQ.DequeueTimeout(LV, 1000000), 'DequeueTimeout on closed empty');
  finally
    LQ.Free;
  end;
end;

{ SPMC boundary conditions }

procedure TestSpmcTryEnqueueClosed;
var
  LQ: TIntSpmc;
begin
  LQ := TIntSpmc.Create(8);
  try
    LQ.Close;
    Check(not LQ.TryEnqueue(1), 'enqueue to closed returns false');
  finally
    LQ.Free;
  end;
end;

procedure TestSpmcTryDequeueClosed;
var
  LQ: TIntSpmc;
  LV: Integer;
begin
  LQ := TIntSpmc.Create(8);
  try
    LQ.TryEnqueue(1);
    LQ.Close;
    Check(LQ.TryDequeue(LV), 'dequeue from closed with data succeeds');
    CheckEqual(1, LV, 'dequeued value matches');
    Check(not LQ.TryDequeue(LV), 'dequeue from closed empty returns false');
  finally
    LQ.Free;
  end;
end;

{ Channel IsEmpty }

procedure TestChannelIsEmpty;
var
  LCh: TIntChannel;
begin
  LCh := TIntChannel.Create(4);
  try
    Check(LCh.IsEmpty, 'empty initially');
    LCh.TrySend(1);
    Check(not LCh.IsEmpty, 'not empty after send');
    LCh.TrySend(2);
    Check(not LCh.IsEmpty, 'not empty with 2 items');
  finally
    LCh.Free;
  end;
end;

{ Selector TrySelect }

procedure TestSelectorTrySelect;
var
  LCh1, LCh2: TIntChannel;
  LSel: TIntSelector;
  LResult: TSelectResult;
  LVal: Integer;
begin
  LCh1 := TIntChannel.Create(4);
  LCh2 := TIntChannel.Create(4);
  LSel := TIntSelector.Create;
  try
    LSel.AddRecv(LCh1, LVal);
    LSel.AddRecv(LCh2, LVal);

    // 空 channel → TrySelect 应返回 false
    LResult := LSel.TrySelect;
    Check(not LResult.Completed, 'TrySelect on empty returns not completed');
    CheckEqual(Int64(-1), Int64(LResult.Index), 'TrySelect on empty index -1');

    // 有数据 → TrySelect 应返回 true
    LCh2.Send(55);
    LResult := LSel.TrySelect;
    Check(LResult.Completed, 'TrySelect with data completes');
    CheckEqual(Int64(1), Int64(LResult.Index), 'TrySelect selects Ch2 (index 1)');
    CheckEqual(Int64(55), Int64(LVal), 'TrySelect received value 55');
  finally
    LSel.Free;
    LCh2.Free;
    LCh1.Free;
  end;
end;

{ Channel 4P+4C stress test }

var
  GChannelStressQ: TIntChannel;
  GChannelStressSum: Int64;

function ChannelStressProducer(AArg: Pointer): Pointer; cdecl;
var
  LI, LStart: Integer;
begin
  Result := nil;
  LStart := Integer(PtrUInt(AArg));
  for LI := LStart to LStart + 249 do
    GChannelStressQ.Send(LI);
end;

function ChannelStressConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  while GChannelStressQ.Receive(LV) do
    InterlockedExchangeAdd64(GChannelStressSum, Int64(LV));
end;

procedure TestChannelStress;
var
  LProducers: array[0..3] of TPlatformThreadHandle;
  LConsumers: array[0..3] of TPlatformThreadHandle;
  LI: Integer;
  LExpected: Int64;
  LProducerCount: Integer;
  LConsumerCount: Integer;
begin
  GChannelStressQ := TIntChannel.Create(64);
  GChannelStressSum := 0;
  LProducerCount := 0;
  LConsumerCount := 0;
  try
    for LI := 0 to 3 do
    begin
      StartThread(LConsumers[LI], @ChannelStressConsumer, nil, 'Channel stress consumer');
      Inc(LConsumerCount);
    end;
    for LI := 0 to 3 do
    begin
      StartThread(LProducers[LI], @ChannelStressProducer, Pointer(PtrInt(LI * 250 + 1)), 'Channel stress producer');
      Inc(LProducerCount);
    end;
    JoinStartedThreads(LProducers, LProducerCount, 'Channel stress producer');
    platform_thread_sleep_ns(10000000);
    GChannelStressQ.Close;
    JoinStartedThreads(LConsumers, LConsumerCount, 'Channel stress consumer');
    LExpected := Int64(1000) * 1001 div 2;
    CheckEqual(LExpected, GChannelStressSum, 'Channel 4P+4C sum');
  finally
    GChannelStressQ.Close;
    JoinStartedThreads(LProducers, LProducerCount, 'Channel stress producer');
    JoinStartedThreads(LConsumers, LConsumerCount, 'Channel stress consumer');
    GChannelStressQ.Free;
  end;
end;

{ Channel Close-while-Send }

var
  GChannelCloseSendQ: TIntChannel;
  GChannelCloseSendStarted: Int32;
  GChannelCloseSendResult: Int32;

function ChannelCloseSendBlockedProducer(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  atomic_store(GChannelCloseSendStarted, 1, mo_release);
  if GChannelCloseSendQ.SendTimeout(42, 5000000000) then
    atomic_store(GChannelCloseSendResult, 0, mo_release)
  else
    atomic_store(GChannelCloseSendResult, 1, mo_release);
end;

procedure TestChannelCloseWhileSend;
var
  LCh: TIntChannel;
  LProducer: TPlatformThreadHandle;
  LElapsedMs: QWord;
  LSpin: Integer;
  LProducerStarted: Boolean;
  LResult: Int32;
begin
  LCh := TIntChannel.Create(1);
  LProducerStarted := False;
  try
    Check(LCh.TrySend(1), 'fill channel before blocked send');
    GChannelCloseSendQ := LCh;
    atomic_store(GChannelCloseSendStarted, 0, mo_release);
    atomic_store(GChannelCloseSendResult, -1, mo_release);
    StartThread(LProducer, @ChannelCloseSendBlockedProducer, nil, 'Channel close-while-send producer');
    LProducerStarted := True;
    for LSpin := 1 to 1000 do
    begin
      if atomic_load(GChannelCloseSendStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(atomic_load(GChannelCloseSendStarted, mo_acquire)),
      'blocked SendTimeout thread must start before close');
    LElapsedMs := TestMonotonicMs;
    LCh.Close;
    JoinStartedThread(LProducer, LProducerStarted, 'Channel close-while-send producer');
    LElapsedMs := TestMonotonicMs - LElapsedMs;
    LResult := atomic_load(GChannelCloseSendResult, mo_acquire);
    Check(LResult >= 0, 'blocked SendTimeout must complete after close (0=sent before close, 1=closed)');
    Check(LElapsedMs < 1000, 'blocked SendTimeout should return promptly after close');
  finally
    if LProducerStarted then
    begin
      LCh.Close;
      JoinStartedThread(LProducer, LProducerStarted, 'Channel close-while-send producer');
    end;
    GChannelCloseSendQ := nil;
    LCh.Free;
  end;
end;

procedure TestChannelSpscBasic;
var
  LCh: TIntChannelSpsc;
  LVal: Integer;
begin
  LCh := TIntChannelSpsc.Create(4);
  try
    Check(LCh.TrySend(1), 'TrySend(1) should succeed');
    Check(LCh.TrySend(2), 'TrySend(2) should succeed');
    Check(LCh.TrySend(3), 'TrySend(3) should succeed');
    Check(LCh.TrySend(4), 'TrySend(4) should succeed');
    Check(not LCh.TrySend(5), 'TrySend(5) should fail (full)');
    Check(LCh.TryReceive(LVal), 'TryReceive should succeed');
    CheckEqual(1, LVal, 'First value should be 1');
    Check(LCh.TryReceive(LVal), 'TryReceive should succeed');
    CheckEqual(2, LVal, 'Second value should be 2');
    Check(LCh.TryReceive(LVal), 'TryReceive should succeed');
    CheckEqual(3, LVal, 'Third value should be 3');
    Check(LCh.TryReceive(LVal), 'TryReceive should succeed');
    CheckEqual(4, LVal, 'Fourth value should be 4');
    Check(not LCh.TryReceive(LVal), 'TryReceive should fail (empty)');
    Check(LCh.IsEmpty, 'Channel should be empty');
    CheckEqual(4, Integer(LCh.Capacity), 'Capacity should be 4');
  finally
    LCh.Free;
  end;
end;

var
  GChannelSpscQ: TIntChannelSpsc;
  GChannelSpscSum: Int64;
  GChannelSpscIterations: Integer;

function ChannelSpscProducerThread(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
begin
  for LI := 1 to GChannelSpscIterations do
  begin
    while not GChannelSpscQ.TrySend(LI) do
      CpuPause;
  end;
  Result := nil;
end;

function ChannelSpscConsumerThread(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
  LVal: Integer;
begin
  for LI := 1 to GChannelSpscIterations do
  begin
    while not GChannelSpscQ.TryReceive(LVal) do
      CpuPause;
    atomic_fetch_add_64(GChannelSpscSum, Int64(LVal), mo_relaxed);
  end;
  Result := nil;
end;

procedure TestChannelSpscStress;
const
  ITERATIONS = 100000;
var
  LCh: TIntChannelSpsc;
  LProducer, LConsumer: TPlatformThreadHandle;
  LProducerStarted, LConsumerStarted: Boolean;
begin
  LCh := TIntChannelSpsc.Create(64);
  LProducerStarted := False;
  LConsumerStarted := False;
  try
    atomic_store_64(GChannelSpscSum, 0, mo_relaxed);
    GChannelSpscQ := LCh;
    GChannelSpscIterations := ITERATIONS;
    StartThread(LProducer, @ChannelSpscProducerThread, nil, 'SPSC producer');
    LProducerStarted := True;
    StartThread(LConsumer, @ChannelSpscConsumerThread, nil, 'SPSC consumer');
    LConsumerStarted := True;
    JoinStartedThread(LProducer, LProducerStarted, 'SPSC producer');
    JoinStartedThread(LConsumer, LConsumerStarted, 'SPSC consumer');
    CheckEqual(Int64(ITERATIONS * (ITERATIONS + 1) div 2), atomic_load_64(GChannelSpscSum, mo_relaxed),
      'SPSC stress sum mismatch');
  finally
    GChannelSpscQ := nil;
    LCh.Free;
  end;
end;

procedure TestChannelSpscTimeout;
var
  LCh: TIntChannelSpsc;
  LV: Integer;
  LStart, LElapsed: UInt64;
begin
  LCh := TIntChannelSpsc.Create(2);
  try
    { Fill the channel }
    Check(LCh.TrySend(1), 'First send must succeed');
    Check(LCh.TrySend(2), 'Second send must succeed');
    Check(not LCh.TrySend(3), 'Third send must fail (full)');

    { SendTimeout should timeout }
    LStart := TestMonotonicMs;
    Check(not LCh.SendTimeout(3, 10000000), 'SendTimeout must timeout (10ms)');
    LElapsed := TestMonotonicMs - LStart;
    Check(LElapsed >= 8, 'SendTimeout must wait at least 8ms');

    { Receive one item }
    Check(LCh.TryReceive(LV), 'Receive must succeed');
    CheckEqual(1, LV, 'Received value must be 1');

    { Now SendTimeout should succeed }
    Check(LCh.SendTimeout(3, 10000000), 'SendTimeout must succeed after receive');

    { ReceiveTimeout on empty channel should timeout }
    Check(LCh.TryReceive(LV), 'Receive must succeed');
    CheckEqual(2, LV, 'Received value must be 2');
    Check(LCh.TryReceive(LV), 'Receive must succeed');
    CheckEqual(3, LV, 'Received value must be 3');

    LStart := TestMonotonicMs;
    Check(not LCh.ReceiveTimeout(LV, 10000000), 'ReceiveTimeout must timeout (10ms)');
    LElapsed := TestMonotonicMs - LStart;
    Check(LElapsed >= 8, 'ReceiveTimeout must wait at least 8ms');
  finally
    LCh.Free;
  end;
end;

procedure TestChannelSpscClose;
var
  LCh: TIntChannelSpsc;
  LV: Integer;
begin
  LCh := TIntChannelSpsc.Create(4);
  try
    { Send some items before close }
    Check(LCh.TrySend(10), 'Send before close must succeed');
    Check(LCh.TrySend(20), 'Send before close must succeed');

    { Close the channel }
    LCh.Close;
    Check(LCh.IsClosed, 'Channel must be closed');

    { Cannot send after close }
    Check(not LCh.TrySend(30), 'TrySend after close must fail');

    { Can still receive pending items }
    Check(LCh.TryReceive(LV), 'Receive pending item must succeed');
    CheckEqual(10, LV, 'First pending value must be 10');
    Check(LCh.TryReceive(LV), 'Receive pending item must succeed');
    CheckEqual(20, LV, 'Second pending value must be 20');

    { No more items }
    Check(not LCh.TryReceive(LV), 'Receive after drain must fail');
  finally
    LCh.Free;
  end;
end;

procedure TestChannelSpscCapacity;
var
  LCh: TIntChannelSpsc;
begin
  LCh := TIntChannelSpsc.Create(8);
  try
    CheckEqual(8, LCh.Capacity, 'Capacity must be 8');
    Check(LCh.IsEmpty, 'New channel must be empty');
    CheckEqual(0, LCh.ApproxLen, 'ApproxLen must be 0');

    LCh.TrySend(1);
    LCh.TrySend(2);
    LCh.TrySend(3);
    Check(not LCh.IsEmpty, 'Channel with items must not be empty');
    CheckEqual(3, LCh.ApproxLen, 'ApproxLen must be 3');
  finally
    LCh.Free;
  end;
end;

procedure TestChannelSpscWrapAround;
var
  LCh: TIntChannelSpsc;
  LV: Integer;
  I: Integer;
begin
  LCh := TIntChannelSpsc.Create(4);
  try
    { Fill and drain multiple times to test wrap-around }
    for I := 1 to 100 do
    begin
      Check(LCh.TrySend(I), 'Send must succeed');
      Check(LCh.TryReceive(LV), 'Receive must succeed');
      CheckEqual(I, LV, 'Value must match');
    end;
    Check(LCh.IsEmpty, 'Channel must be empty after drain');
  finally
    LCh.Free;
  end;
end;

{ ============================================================ }
{ Edge-case: SPSC capacity=1                                    }
{ ============================================================ }

procedure TestSpscCapacityOne;
var
  LQ: TIntSpsc;
  LV: Integer;
begin
  LQ := TIntSpsc.Create(1);
  try
    CheckEqual(Int64(1), Int64(LQ.Capacity), 'capacity=1');
    Check(LQ.IsEmpty, 'initially empty');
    Check(not LQ.IsFull, 'initially not full');
    Check(LQ.TryEnqueue(42), 'enqueue to capacity=1');
    Check(not LQ.TryEnqueue(99), 'enqueue to full capacity=1');
    Check(LQ.IsFull, 'full after enqueue');
    Check(LQ.TryDequeue(LV), 'dequeue from capacity=1');
    CheckEqual(42, LV, 'value matches');
    Check(LQ.IsEmpty, 'empty after dequeue');
  finally
    LQ.Free;
  end;
end;

{ ============================================================ }
{ Edge-case: SPSC capacity=2                                    }
{ ============================================================ }

procedure TestSpscCapacityTwo;
var
  LQ: TIntSpsc;
  LV: Integer;
begin
  LQ := TIntSpsc.Create(2);
  try
    CheckEqual(Int64(2), Int64(LQ.Capacity), 'capacity=2');
    Check(LQ.TryEnqueue(1), 'enqueue first');
    Check(LQ.TryEnqueue(2), 'enqueue second');
    Check(not LQ.TryEnqueue(3), 'enqueue to full capacity=2');
    Check(LQ.TryDequeue(LV), 'dequeue first');
    CheckEqual(1, LV, 'first value');
    Check(LQ.TryDequeue(LV), 'dequeue second');
    CheckEqual(2, LV, 'second value');
    Check(not LQ.TryDequeue(LV), 'dequeue from empty');
  finally
    LQ.Free;
  end;
end;

{ SPSC boundary conditions }

procedure TestSpscTryEnqueueClosed;
var
  LQ: TIntSpsc;
begin
  LQ := TIntSpsc.Create(8);
  try
    LQ.Close;
    Check(not LQ.TryEnqueue(1), 'enqueue to closed returns false');
  finally
    LQ.Free;
  end;
end;

procedure TestSpscTryDequeueClosed;
var
  LQ: TIntSpsc;
  LV: Integer;
begin
  LQ := TIntSpsc.Create(8);
  try
    LQ.TryEnqueue(1);
    LQ.Close;
    Check(LQ.TryDequeue(LV), 'dequeue from closed with data succeeds');
    CheckEqual(1, LV, 'dequeued value matches');
    Check(not LQ.TryDequeue(LV), 'dequeue from closed empty returns false');
  finally
    LQ.Free;
  end;
end;

{ ============================================================ }
{ Edge-case: MPMC capacity=1                                    }
{ ============================================================ }

procedure TestMpmcCapacityOne;
var
  LQ: TIntMpmc;
  LV: Integer;
begin
  LQ := TIntMpmc.Create(1);
  try
    CheckEqual(Int64(1), Int64(LQ.Capacity), 'capacity=1');
    Check(LQ.TryEnqueue(42), 'enqueue to capacity=1');
    Check(not LQ.TryEnqueue(99), 'enqueue to full capacity=1');
    Check(LQ.TryDequeue(LV), 'dequeue from capacity=1');
    CheckEqual(42, LV, 'value matches');
  finally
    LQ.Free;
  end;
end;

{ MPMC boundary conditions }

procedure TestMpmcTryEnqueueClosed;
var
  LQ: TIntMpmc;
begin
  LQ := TIntMpmc.Create(8);
  try
    LQ.Close;
    Check(not LQ.TryEnqueue(1), 'enqueue to closed returns false');
  finally
    LQ.Free;
  end;
end;

procedure TestMpmcTryDequeueClosed;
var
  LQ: TIntMpmc;
  LV: Integer;
begin
  LQ := TIntMpmc.Create(8);
  try
    LQ.TryEnqueue(1);
    LQ.Close;
    Check(LQ.TryDequeue(LV), 'dequeue from closed with data succeeds');
    CheckEqual(1, LV, 'dequeued value matches');
    Check(not LQ.TryDequeue(LV), 'dequeue from closed empty returns false');
  finally
    LQ.Free;
  end;
end;

{ ============================================================ }
{ Edge-case: Stack capacity=1                                   }
{ ============================================================ }

procedure TestStackCapacityOne;
var
  LS: TIntStack;
  LV: Integer;
begin
  LS := TIntStack.Create(1);
  try
    Check(LS.TryPush(42), 'push to capacity=1');
    Check(not LS.TryPush(99), 'push to full capacity=1');
    Check(LS.TryPop(LV), 'pop from capacity=1');
    CheckEqual(42, LV, 'value matches');
    Check(not LS.TryPop(LV), 'pop from empty');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ Edge-case: Deque capacity=1                                   }
{ ============================================================ }

procedure TestDequeCapacityOne;
var
  LD: TIntDeque;
  LV: Integer;
begin
  LD := TIntDeque.Create(1);
  try
    Check(LD.TryPush(42), 'push to capacity=1');
    Check(not LD.TryPush(99), 'push to full capacity=1');
    Check(LD.TryPop(LV), 'pop from capacity=1');
    CheckEqual(42, LV, 'value matches');
  finally
    LD.Free;
  end;
end;

{ ============================================================ }
{ Deque: TrySteal boundary conditions                          }
{ ============================================================ }

procedure TestDequeTryStealEmpty;
var
  LD: TIntDeque;
  LV: Integer;
begin
  LD := TIntDeque.Create(8);
  try
    Check(not LD.TrySteal(LV), 'steal from empty returns false');
  finally
    LD.Free;
  end;
end;

procedure TestDequeTryStealClosed;
var
  LD: TIntDeque;
  LV: Integer;
begin
  LD := TIntDeque.Create(8);
  try
    LD.TryPush(1);
    LD.Close;
    Check(LD.TrySteal(LV), 'steal from closed with data succeeds');
    CheckEqual(1, LV, 'stolen value matches');
    Check(not LD.TrySteal(LV), 'steal from closed empty returns false');
  finally
    LD.Free;
  end;
end;

procedure TestDequeTryPopEmpty;
var
  LD: TIntDeque;
  LV: Integer;
begin
  LD := TIntDeque.Create(8);
  try
    Check(not LD.TryPop(LV), 'pop from empty returns false');
  finally
    LD.Free;
  end;
end;

procedure TestDequeTryPopClosed;
var
  LD: TIntDeque;
  LV: Integer;
begin
  LD := TIntDeque.Create(8);
  try
    LD.TryPush(1);
    LD.Close;
    Check(LD.TryPop(LV), 'pop from closed with data succeeds');
    CheckEqual(1, LV, 'popped value matches');
    Check(not LD.TryPop(LV), 'pop from closed empty returns false');
  finally
    LD.Free;
  end;
end;

{ ============================================================ }
{ Stack: boundary conditions                                    }
{ ============================================================ }

procedure TestStackTryPopEmpty;
var
  LS: TIntStack;
  LV: Integer;
begin
  LS := TIntStack.Create(8);
  try
    Check(not LS.TryPop(LV), 'pop from empty returns false');
  finally
    LS.Free;
  end;
end;

procedure TestStackTryPopClosed;
var
  LS: TIntStack;
  LV: Integer;
begin
  LS := TIntStack.Create(8);
  try
    LS.TryPush(1);
    LS.Close;
    Check(LS.TryPop(LV), 'pop from closed with data succeeds');
    CheckEqual(1, LV, 'popped value matches');
    Check(not LS.TryPop(LV), 'pop from closed empty returns false');
  finally
    LS.Free;
  end;
end;

procedure TestStackPushFull;
var
  LS: TIntStack;
begin
  LS := TIntStack.Create(2);
  try
    Check(LS.TryPush(1), 'push 1');
    Check(LS.TryPush(2), 'push 2');
    Check(not LS.TryPush(3), 'push to full returns false');
  finally
    LS.Free;
  end;
end;

{ ============================================================ }
{ Edge-case: HashMap single key stress                          }
{ ============================================================ }

procedure TestHashMapSingleKeyStress;
const
  OPS = 10000;
var
  LM: TIntIntMap;
  LI: Integer;
  LV: Integer;
  LFound: Boolean;
begin
  LM := TIntIntMap.Create(4);
  try
    { Repeatedly insert/update/remove the same key }
    for LI := 1 to OPS do
    begin
      LM.Insert(1, LI);
      LFound := LM.Find(1, LV);
      Check(LFound, 'key must exist after insert');
      CheckEqual(LI, LV, 'value must match');
    end;
    LM.Remove(1);
    Check(not LM.Find(1, LV), 'key must not exist after remove');
  finally
    LM.Free;
  end;
end;

{ ============================================================ }
{ Edge-case: HashMap many keys stress                           }
{ ============================================================ }

procedure TestHashMapManyKeysStress;
const
  KEY_COUNT = 1000;
var
  LM: TIntIntMap;
  LI: Integer;
  LV: Integer;
  LFound: Boolean;
begin
  LM := TIntIntMap.Create(16);
  try
    { Insert many keys }
    for LI := 1 to KEY_COUNT do
      LM.Insert(LI, LI * 10);
    CheckEqual(PtrUInt(KEY_COUNT), LM.Count, 'count after insert');
    { Verify all keys }
    for LI := 1 to KEY_COUNT do
    begin
      LFound := LM.Find(LI, LV);
      Check(LFound, 'key must exist');
      CheckEqual(LI * 10, LV, 'value must match');
    end;
    { Remove all keys }
    for LI := 1 to KEY_COUNT do
      Check(LM.Remove(LI), 'remove must succeed');
    CheckEqual(PtrUInt(0), LM.Count, 'count after remove all');
  finally
    LM.Free;
  end;
end;

{ HashMap boundary conditions }

procedure TestHashMapFindEmpty;
var
  LM: TIntIntMap;
  LV: Integer;
begin
  LM := TIntIntMap.Create(4);
  try
    Check(not LM.Find(1, LV), 'find in empty returns false');
  finally
    LM.Free;
  end;
end;

procedure TestHashMapRemoveEmpty;
var
  LM: TIntIntMap;
begin
  LM := TIntIntMap.Create(4);
  try
    Check(not LM.Remove(1), 'remove from empty returns false');
  finally
    LM.Free;
  end;
end;

procedure TestHashMapContainsMissing;
var
  LM: TIntIntMap;
begin
  LM := TIntIntMap.Create(4);
  try
    Check(not LM.Contains(1), 'contains missing returns false');
    LM.Insert(1, 10);
    Check(LM.Contains(1), 'contains existing returns true');
  finally
    LM.Free;
  end;
end;

{ ============================================================ }
{ Edge-case: Channel capacity=1 full/empty (R5)                 }
{ ============================================================ }

procedure TestChannelCapacityOneFullEmpty;
var
  LCh: TIntChannel;
  LV: Integer;
  LErr: TLockFreeTryError;
begin
  LCh := TIntChannel.Create(1);
  try
    CheckEqual(Int64(1), Int64(LCh.Capacity), 'capacity=1');
    Check(LCh.IsEmpty, 'empty initially');
    Check(not LCh.TryReceiveEx(LV, LErr), 'empty TryReceiveEx fails');
    Check(LErr = lfteEmpty, 'empty is lfteEmpty');
    Check(LCh.TrySend(42), 'send to capacity=1');
    Check(not LCh.IsEmpty, 'not empty after send');
    Check(not LCh.TrySend(99), 'send to full capacity=1 fails');
    Check(not LCh.TrySendEx(100, LErr), 'full TrySendEx fails');
    Check(LErr = lfteFull, 'full is lfteFull');
    Check(LCh.TryReceive(LV), 'receive from capacity=1');
    CheckEqual(42, LV, 'value matches');
    Check(LCh.IsEmpty, 'empty after receive');
    Check(not LCh.TryReceive(LV), 'receive from empty fails');
    Check(LCh.TrySendEx(7, LErr), 'resend after drain');
    Check(LErr = lfteNone, 'resend success is lfteNone');
    Check(LCh.TryReceiveEx(LV, LErr), 'rereceive after resend');
    CheckEqual(7, LV, 'resend value matches');
    Check(LErr = lfteNone, 'rereceive success is lfteNone');
  finally
    LCh.Free;
  end;
end;

{ ============================================================ }
{ Edge-case: Channel capacity=2                                 }
{ ============================================================ }

procedure TestChannelCapacityTwo;
var
  LCh: TIntChannel;
  LV: Integer;
begin
  LCh := TIntChannel.Create(2);
  try
    Check(LCh.TrySend(42), 'send to capacity=2');
    Check(LCh.TrySend(99), 'send second to capacity=2');
    Check(not LCh.TrySend(100), 'send to full capacity=2');
    Check(LCh.TryReceive(LV), 'receive from capacity=2');
    CheckEqual(42, LV, 'value matches');
    Check(LCh.TryReceive(LV), 'receive second from capacity=2');
    CheckEqual(99, LV, 'second value matches');
    Check(LCh.IsEmpty, 'empty after receive');
  finally
    LCh.Free;
  end;
end;

{ ============================================================ }
{ Edge-case: Channel SPSC capacity=1                            }
{ ============================================================ }

procedure TestChannelSpscCapacityOne;
var
  LCh: TIntChannelSpsc;
  LV: Integer;
begin
  LCh := TIntChannelSpsc.Create(1);
  try
    Check(LCh.TrySend(42), 'send to capacity=1');
    Check(not LCh.TrySend(99), 'send to full capacity=1');
    Check(LCh.TryReceive(LV), 'receive from capacity=1');
    CheckEqual(42, LV, 'value matches');
    Check(LCh.IsEmpty, 'empty after receive');
  finally
    LCh.Free;
  end;
end;

{ ============================================================ }
{ Channel dynamic resize tests                                  }
{ ============================================================ }

procedure TestChannelResizeGrow;
var
  LCh: TIntChannel;
  LV: Integer;
begin
  LCh := TIntChannel.Create(4);
  try
    { Fill to capacity }
    Check(LCh.TrySend(10), 'send 1');
    Check(LCh.TrySend(20), 'send 2');
    Check(LCh.TrySend(30), 'send 3');
    Check(LCh.TrySend(40), 'send 4');
    Check(not LCh.TrySend(50), 'full before resize');
    CheckEqual(Int64(4), Int64(LCh.Capacity), 'capacity=4 before resize');
    { Grow to 16 }
    Check(LCh.TryResize(16), 'resize to 16');
    CheckEqual(Int64(16), Int64(LCh.Capacity), 'capacity=16 after resize');
    { Now we can send more }
    Check(LCh.TrySend(50), 'send after grow 1');
    Check(LCh.TrySend(60), 'send after grow 2');
    { Verify all data preserved }
    Check(LCh.TryReceive(LV), 'recv 1');
    CheckEqual(Int64(10), Int64(LV), 'value 1');
    Check(LCh.TryReceive(LV), 'recv 2');
    CheckEqual(Int64(20), Int64(LV), 'value 2');
    Check(LCh.TryReceive(LV), 'recv 3');
    CheckEqual(Int64(30), Int64(LV), 'value 3');
    Check(LCh.TryReceive(LV), 'recv 4');
    CheckEqual(Int64(40), Int64(LV), 'value 4');
    Check(LCh.TryReceive(LV), 'recv 5');
    CheckEqual(Int64(50), Int64(LV), 'value 5');
    Check(LCh.TryReceive(LV), 'recv 6');
    CheckEqual(Int64(60), Int64(LV), 'value 6');
    Check(not LCh.TryReceive(LV), 'empty after drain');
  finally
    LCh.Free;
  end;
end;

procedure TestChannelResizeShrink;
var
  LCh: TIntChannel;
  LV: Integer;
begin
  LCh := TIntChannel.Create(16);
  try
    Check(LCh.TrySend(10), 'send 1');
    Check(LCh.TrySend(20), 'send 2');
    Check(LCh.TrySend(30), 'send 3');
    Check(LCh.TrySend(40), 'send 4');
    CheckEqual(Int64(16), Int64(LCh.Capacity), 'capacity=16 before resize');
    { Shrink to 4 (same as current data count) }
    Check(LCh.TryResize(4), 'resize to 4');
    CheckEqual(Int64(4), Int64(LCh.Capacity), 'capacity=4 after resize');
    { Data should still be there }
    Check(LCh.TryReceive(LV), 'recv 1');
    CheckEqual(Int64(10), Int64(LV), 'value 1');
    Check(LCh.TryReceive(LV), 'recv 2');
    CheckEqual(Int64(20), Int64(LV), 'value 2');
    Check(LCh.TryReceive(LV), 'recv 3');
    CheckEqual(Int64(30), Int64(LV), 'value 3');
    Check(LCh.TryReceive(LV), 'recv 4');
    CheckEqual(Int64(40), Int64(LV), 'value 4');
    Check(not LCh.TryReceive(LV), 'empty after drain');
  finally
    LCh.Free;
  end;
end;

procedure TestChannelResizeEmpty;
var
  LCh: TIntChannel;
begin
  LCh := TIntChannel.Create(4);
  try
    Check(LCh.TryResize(8), 'resize empty channel');
    CheckEqual(Int64(8), Int64(LCh.Capacity), 'capacity=8 after resize');
    Check(LCh.IsEmpty, 'still empty');
  finally
    LCh.Free;
  end;
end;

procedure TestChannelResizeSameCapacity;
var
  LCh: TIntChannel;
  LV: Integer;
begin
  LCh := TIntChannel.Create(4);
  try
    LCh.TrySend(42);
    Check(LCh.TryResize(4), 'resize to same capacity');
    CheckEqual(Int64(4), Int64(LCh.Capacity), 'capacity unchanged');
    Check(LCh.TryReceive(LV), 'data preserved');
    CheckEqual(Int64(42), Int64(LV), 'value preserved');
  finally
    LCh.Free;
  end;
end;

procedure TestChannelResizeWhileFull;
var
  LCh: TIntChannel;
  LV: Integer;
begin
  LCh := TIntChannel.Create(4);
  try
    { Fill completely }
    LCh.TrySend(1);
    LCh.TrySend(2);
    LCh.TrySend(3);
    LCh.TrySend(4);
    Check(not LCh.TrySend(5), 'full before resize');
    { Grow while full }
    Check(LCh.TryResize(8), 'resize while full');
    Check(LCh.TrySend(5), 'can send after grow');
    Check(LCh.TrySend(6), 'can send more');
    { Drain all 6 }
    Check(LCh.TryReceive(LV) and (LV = 1), 'v1');
    Check(LCh.TryReceive(LV) and (LV = 2), 'v2');
    Check(LCh.TryReceive(LV) and (LV = 3), 'v3');
    Check(LCh.TryReceive(LV) and (LV = 4), 'v4');
    Check(LCh.TryReceive(LV) and (LV = 5), 'v5');
    Check(LCh.TryReceive(LV) and (LV = 6), 'v6');
    Check(not LCh.TryReceive(LV), 'empty');
  finally
    LCh.Free;
  end;
end;

procedure TestChannelResizeClosed;
var
  LCh: TIntChannel;
begin
  LCh := TIntChannel.Create(4);
  try
    LCh.Close;
    Check(not LCh.TryResize(8), 'resize after close fails');
  finally
    LCh.Free;
  end;
end;

procedure TestChannelResizeRejectShrinkBelowLiveCount;
var
  LCh: TIntChannel;
  LV: Integer;
begin
  LCh := TIntChannel.Create(8);
  try
    Check(LCh.TrySend(10), 'send 1');
    Check(LCh.TrySend(20), 'send 2');
    Check(LCh.TrySend(30), 'send 3');
    Check(LCh.TrySend(40), 'send 4');
    Check(LCh.TrySend(50), 'send 5');
    CheckEqual(Int64(5), Int64(LCh.ApproxLen), 'len before rejected shrink');
    Check(not LCh.TryResize(4), 'resize below live count rejected');
    CheckEqual(Int64(8), Int64(LCh.Capacity), 'capacity unchanged after rejected shrink');
    Check(LCh.TryReceive(LV), 'recv 1');
    CheckEqual(Int64(10), Int64(LV), 'value 1 preserved');
    Check(LCh.TryReceive(LV), 'recv 2');
    CheckEqual(Int64(20), Int64(LV), 'value 2 preserved');
    Check(LCh.TryReceive(LV), 'recv 3');
    CheckEqual(Int64(30), Int64(LV), 'value 3 preserved');
    Check(LCh.TryReceive(LV), 'recv 4');
    CheckEqual(Int64(40), Int64(LV), 'value 4 preserved');
    Check(LCh.TryReceive(LV), 'recv 5');
    CheckEqual(Int64(50), Int64(LV), 'value 5 preserved');
    Check(not LCh.TryReceive(LV), 'empty after preserved drain');
  finally
    LCh.Free;
  end;
end;

{ Channel boundary conditions }

procedure TestChannelTryReceiveEmpty;
var
  LCh: TIntChannel;
  LV: Integer;
begin
  LCh := TIntChannel.Create(8);
  try
    Check(not LCh.TryReceive(LV), 'receive from empty returns false');
  finally
    LCh.Free;
  end;
end;

procedure TestChannelTryReceiveClosed;
var
  LCh: TIntChannel;
  LV: Integer;
begin
  LCh := TIntChannel.Create(8);
  try
    LCh.TrySend(1);
    LCh.Close;
    Check(LCh.TryReceive(LV), 'receive from closed with data succeeds');
    CheckEqual(1, LV, 'received value matches');
    Check(not LCh.TryReceive(LV), 'receive from closed empty returns false');
  finally
    LCh.Free;
  end;
end;

procedure TestChannelTrySendClosed;
var
  LCh: TIntChannel;
begin
  LCh := TIntChannel.Create(8);
  try
    LCh.Close;
    Check(not LCh.TrySend(1), 'send to closed returns false');
  finally
    LCh.Free;
  end;
end;

{ ============================================================ }
{ Edge-case: Selector with single channel                       }
{ ============================================================ }

procedure TestSelectorSingleChannel;
var
  LSel: TIntSelector;
  LCh: TIntChannel;
  LV: Integer;
  LResult: TSelectResult;
begin
  LCh := TIntChannel.Create(8);
  LSel := TIntSelector.Create;
  try
    LV := 0;
    LSel.AddRecv(LCh, LV);
    LCh.TrySend(42);
    LResult := LSel.TrySelect;
    Check(LResult.Completed, 'select must succeed');
    CheckEqual(42, LV, 'value must match');
  finally
    LSel.Free;
    LCh.Free;
  end;
end;

{ Selector boundary conditions }

procedure TestSelectorTrySelectEmpty;
var
  LSel: TIntSelector;
  LResult: TSelectResult;
begin
  LSel := TIntSelector.Create;
  try
    LResult := LSel.TrySelect;
    Check(not LResult.Completed, 'select empty returns not completed');
  finally
    LSel.Free;
  end;
end;

procedure TestSelectorClearResets;
var
  LSel: TIntSelector;
  LCh1, LCh2: TIntChannel;
  LV1, LV2: Integer;
begin
  LCh1 := TIntChannel.Create(8);
  LCh2 := TIntChannel.Create(8);
  LSel := TIntSelector.Create;
  try
    LV1 := 0;
    LV2 := 0;
    LSel.AddRecv(LCh1, LV1);
    LSel.AddRecv(LCh2, LV2);
    CheckEqual(2, LSel.CaseCount, 'case count before clear');
    LSel.Clear;
    CheckEqual(0, LSel.CaseCount, 'case count after clear');
  finally
    LSel.Free;
    LCh1.Free;
    LCh2.Free;
  end;
end;

{ Q3-a: multi-ready prefers first Add (registration order) }
procedure TestSelectorCaseOrderPreferFirst;
var
  LSel: TIntSelector;
  LCh1, LCh2: TIntChannel;
  LVal: Integer;
  LResult: TSelectResult;
begin
  LCh1 := TIntChannel.Create(4);
  LCh2 := TIntChannel.Create(4);
  LSel := TIntSelector.Create;
  try
    LCh1.Send(11);
    LCh2.Send(22);
    LSel.AddRecv(LCh1, LVal);
    LSel.AddRecv(LCh2, LVal);
    LResult := LSel.TrySelect;
    Check(LResult.Completed, 'both ready: TrySelect completes');
    CheckEqual(Int64(0), Int64(LResult.Index), 'both ready: prefers first Add (index 0)');
    CheckEqual(Int64(11), Int64(LVal), 'both ready: receives Ch1 value');
  finally
    LSel.Free;
    LCh2.Free;
    LCh1.Free;
  end;
end;

{ Q3-a: TrySelect ≡ Go select default }
procedure TestSelectorTrySelectAsDefault;
var
  LSel: TIntSelector;
  LCh: TIntChannel;
  LVal: Integer;
  LResult: TSelectResult;
begin
  LCh := TIntChannel.Create(4);
  LSel := TIntSelector.Create;
  try
    LSel.AddRecv(LCh, LVal);
    LResult := LSel.TrySelect;
    Check(not LResult.Completed, 'empty: TrySelect is default path (not completed)');
    LCh.Send(7);
    LResult := LSel.TrySelect;
    Check(LResult.Completed, 'after publish: TrySelect completes');
    CheckEqual(Int64(0), Int64(LResult.Index), 'after publish: index 0');
    CheckEqual(Int64(7), Int64(LVal), 'after publish: value 7');
  finally
    LSel.Free;
    LCh.Free;
  end;
end;

{ Q3-a: closed empty recv aligns with TryReceive=False }
procedure TestSelectorRecvOnClosedEmpty;
var
  LSel: TIntSelector;
  LCh: TIntChannel;
  LVal: Integer;
  LResult: TSelectResult;
begin
  LCh := TIntChannel.Create(4);
  LSel := TIntSelector.Create;
  try
    LCh.Close;
    Check(not LCh.TryReceive(LVal), 'closed empty TryReceive is False');
    LSel.AddRecv(LCh, LVal);
    LResult := LSel.TrySelect;
    Check(not LResult.Completed, 'closed empty: TrySelect does not complete');
    LResult := LSel.SelectTimeout(5 * 1000 * 1000); { 5ms }
    Check(not LResult.Completed, 'closed empty: SelectTimeout does not complete');
    CheckEqual(Int64(-1), Int64(LResult.Index), 'closed empty: timeout Index=-1');
  finally
    LSel.Free;
    LCh.Free;
  end;
end;

{ ============================================================ }
{ Edge-case: EBR with many guards                               }
{ ============================================================ }

procedure TestEbrManyGuards;
const
  GUARD_COUNT = 100;
var
  LDomain: TEbrDomain;
  LGuards: array[0..GUARD_COUNT - 1] of TEbrGuard;
  LI: Integer;
begin
  LDomain := TEbrDomain.Create;
  try
    { Acquire many guards }
    for LI := 0 to GUARD_COUNT - 1 do
      LGuards[LI] := TEbrGuard.Acquire(LDomain);
    { Release all guards }
    for LI := 0 to GUARD_COUNT - 1 do
      LGuards[LI].Release;
  finally
    LDomain.Free;
  end;
end;

procedure TestSegQueueManagedReject;
var
  LStrQ: specialize TSegQueue<AnsiString>;
  LGot: Boolean;
begin
  LGot := False;
  try
    LStrQ := specialize TSegQueue<AnsiString>.Create;
    LStrQ.Free;
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'SegQueue managed type rejected');
end;

{ SegQueue boundary conditions }

procedure TestSegQueueTryDequeueEmpty;
var
  LQ: TIntSegQueue;
  LV: Integer;
begin
  LQ := TIntSegQueue.Create;
  try
    Check(not LQ.TryDequeue(LV), 'dequeue from empty returns false');
  finally
    LQ.Free;
  end;
end;

procedure TestSegQueueTryDequeueClosed;
var
  LQ: TIntSegQueue;
  LV: Integer;
begin
  LQ := TIntSegQueue.Create;
  try
    LQ.Enqueue(1);
    LQ.Close;
    Check(LQ.TryDequeue(LV), 'dequeue from closed with data succeeds');
    CheckEqual(1, LV, 'dequeued value matches');
    Check(not LQ.TryDequeue(LV), 'dequeue from closed empty returns false');
  finally
    LQ.Free;
  end;
end;

procedure TestSegQueueTryEnqueueClosed;
var
  LQ: TIntSegQueue;
begin
  LQ := TIntSegQueue.Create;
  try
    LQ.Close;
    Check(not LQ.TryEnqueue(1), 'enqueue to closed returns false');
  finally
    LQ.Free;
  end;
end;

procedure TestSegQueueEnqueueRaisesWhenClosed;
var
  LQ: TIntSegQueue;
  LV: Integer;
  LRaised: Boolean;
begin
  LQ := TIntSegQueue.Create;
  try
    LQ.Enqueue(7);
    LQ.Close;
    Check(not LQ.TryEnqueue(8), 'TryEnqueue after close returns false');
    LRaised := False;
    try
      LQ.Enqueue(9);
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'plain Enqueue after close must raise EInvalidOperationError');
    Check(LQ.TryDequeue(LV), 'queued item still drainable after close');
    CheckEqual(7, LV, 'drained value matches pre-close enqueue');
    Check(not LQ.TryDequeue(LV), 'queue empty after drain');
  finally
    LQ.Free;
  end;
end;

procedure TestSegQueueTryExDiagnostics;
var
  LQ: TIntSegQueue;
  LV: Integer;
  LErr: TLockFreeTryError;
begin
  LQ := TIntSegQueue.Create;
  try
    Check(LQ.TryEnqueueEx(11, LErr), 'SegQueue TryEnqueueEx success');
    Check(LErr = lfteNone, 'SegQueue success error is lfteNone');
    Check(LQ.TryDequeueEx(LV, LErr), 'SegQueue TryDequeueEx success');
    CheckEqual(11, LV, 'SegQueue TryDequeueEx value');
    Check(LErr = lfteNone, 'SegQueue dequeue success error is lfteNone');
    Check(not LQ.TryDequeueEx(LV, LErr), 'SegQueue empty TryDequeueEx fails');
    Check(LErr = lfteEmpty, 'SegQueue empty not closed is lfteEmpty');
    LQ.Close;
    Check(not LQ.TryEnqueueEx(12, LErr), 'SegQueue closed TryEnqueueEx fails');
    Check(LErr = lfteClosed, 'SegQueue closed publish is lfteClosed');
    Check(not LQ.TryDequeueEx(LV, LErr), 'SegQueue closed empty TryDequeueEx fails');
    Check(LErr = lfteClosed, 'SegQueue closed empty is lfteClosed');
  finally
    LQ.Free;
  end;
end;

procedure TestChannelTryExDiagnostics;
var
  LCh: TIntChannel;
  LV: Integer;
  LErr: TLockFreeTryError;
begin
  { R5: empty/full sequence tokens allow capacity=1 full vs empty diagnostics. }
  LCh := TIntChannel.Create(1);
  try
    Check(LCh.TrySendEx(21, LErr), 'Channel TrySendEx success');
    Check(LErr = lfteNone, 'Channel success error is lfteNone');
    Check(not LCh.TrySendEx(22, LErr), 'Channel full TrySendEx fails');
    Check(LErr = lfteFull, 'Channel full is lfteFull');
    Check(LCh.TryReceiveEx(LV, LErr), 'Channel TryReceiveEx success');
    CheckEqual(21, LV, 'Channel TryReceiveEx value');
    Check(LErr = lfteNone, 'Channel receive success error is lfteNone');
    Check(not LCh.TryReceiveEx(LV, LErr), 'Channel empty TryReceiveEx fails');
    Check(LErr = lfteEmpty, 'Channel empty not closed is lfteEmpty');
    LCh.Close;
    Check(not LCh.TrySendEx(23, LErr), 'Channel closed TrySendEx fails');
    Check(LErr = lfteClosed, 'Channel closed publish is lfteClosed');
    Check(not LCh.TryReceiveEx(LV, LErr), 'Channel closed empty TryReceiveEx fails');
    Check(LErr = lfteClosed, 'Channel closed empty is lfteClosed');
  finally
    LCh.Free;
  end;
end;

procedure TestChannelSpscTryExDiagnostics;
var
  LCh: TIntChannelSpsc;
  LV: Integer;
  LErr: TLockFreeTryError;
begin
  LCh := TIntChannelSpsc.Create(1);
  try
    Check(LCh.TrySendEx(31, LErr), 'SPSC Channel TrySendEx success');
    Check(LErr = lfteNone, 'SPSC Channel success error is lfteNone');
    Check(not LCh.TrySendEx(32, LErr), 'SPSC Channel full TrySendEx fails');
    Check(LErr = lfteFull, 'SPSC Channel full is lfteFull');
    Check(LCh.TryReceiveEx(LV, LErr), 'SPSC Channel TryReceiveEx success');
    CheckEqual(31, LV, 'SPSC Channel TryReceiveEx value');
    Check(LErr = lfteNone, 'SPSC Channel receive success error is lfteNone');
    Check(not LCh.TryReceiveEx(LV, LErr), 'SPSC Channel empty TryReceiveEx fails');
    Check(LErr = lfteEmpty, 'SPSC Channel empty not closed is lfteEmpty');
    LCh.Close;
    Check(not LCh.TrySendEx(33, LErr), 'SPSC Channel closed TrySendEx fails');
    Check(LErr = lfteClosed, 'SPSC Channel closed publish is lfteClosed');
    Check(not LCh.TryReceiveEx(LV, LErr), 'SPSC Channel closed empty TryReceiveEx fails');
    Check(LErr = lfteClosed, 'SPSC Channel closed empty is lfteClosed');
  finally
    LCh.Free;
  end;
end;

procedure TestSpscTryExDiagnostics;
var
  LQ: TIntSpsc;
  LV: Integer;
  LErr: TLockFreeTryError;
begin
  LQ := TIntSpsc.Create(1);
  try
    Check(LQ.TryEnqueueEx(41, LErr), 'SPSC TryEnqueueEx success');
    Check(LErr = lfteNone, 'SPSC success error is lfteNone');
    Check(not LQ.TryEnqueueEx(42, LErr), 'SPSC full TryEnqueueEx fails');
    Check(LErr = lfteFull, 'SPSC full is lfteFull');
    Check(LQ.TryDequeueEx(LV, LErr), 'SPSC TryDequeueEx success');
    CheckEqual(41, LV, 'SPSC TryDequeueEx value');
    Check(LErr = lfteNone, 'SPSC dequeue success error is lfteNone');
    Check(not LQ.TryDequeueEx(LV, LErr), 'SPSC empty TryDequeueEx fails');
    Check(LErr = lfteEmpty, 'SPSC empty not closed is lfteEmpty');
    LQ.Close;
    Check(not LQ.TryEnqueueEx(43, LErr), 'SPSC closed TryEnqueueEx fails');
    Check(LErr = lfteClosed, 'SPSC closed publish is lfteClosed');
    Check(not LQ.TryDequeueEx(LV, LErr), 'SPSC closed empty TryDequeueEx fails');
    Check(LErr = lfteClosed, 'SPSC closed empty is lfteClosed');
  finally
    LQ.Free;
  end;
end;

procedure TestMpmcTryExDiagnostics;
var
  LQ: TIntMpmc;
  LV: Integer;
  LErr: TLockFreeTryError;
begin
  LQ := TIntMpmc.Create(1);
  try
    Check(LQ.TryEnqueueEx(51, LErr), 'MPMC TryEnqueueEx success');
    Check(LErr = lfteNone, 'MPMC success error is lfteNone');
    Check(not LQ.TryEnqueueEx(52, LErr), 'MPMC full TryEnqueueEx fails');
    Check(LErr = lfteFull, 'MPMC full is lfteFull');
    Check(LQ.TryDequeueEx(LV, LErr), 'MPMC TryDequeueEx success');
    CheckEqual(51, LV, 'MPMC TryDequeueEx value');
    Check(LErr = lfteNone, 'MPMC dequeue success error is lfteNone');
    Check(not LQ.TryDequeueEx(LV, LErr), 'MPMC empty TryDequeueEx fails');
    Check(LErr = lfteEmpty, 'MPMC empty not closed is lfteEmpty');
    LQ.Close;
    Check(not LQ.TryEnqueueEx(53, LErr), 'MPMC closed TryEnqueueEx fails');
    Check(LErr = lfteClosed, 'MPMC closed publish is lfteClosed');
    Check(not LQ.TryDequeueEx(LV, LErr), 'MPMC closed empty TryDequeueEx fails');
    Check(LErr = lfteClosed, 'MPMC closed empty is lfteClosed');
  finally
    LQ.Free;
  end;
end;

procedure TestSpmcTryExDiagnostics;
var
  LQ: TIntSpmc;
  LV: Integer;
  LErr: TLockFreeTryError;
begin
  LQ := TIntSpmc.Create(1);
  try
    Check(LQ.TryEnqueueEx(61, LErr), 'SPMC TryEnqueueEx success');
    Check(LErr = lfteNone, 'SPMC success error is lfteNone');
    Check(not LQ.TryEnqueueEx(62, LErr), 'SPMC full TryEnqueueEx fails');
    Check(LErr = lfteFull, 'SPMC full is lfteFull');
    Check(LQ.TryDequeueEx(LV, LErr), 'SPMC TryDequeueEx success');
    CheckEqual(61, LV, 'SPMC TryDequeueEx value');
    Check(LErr = lfteNone, 'SPMC dequeue success error is lfteNone');
    Check(not LQ.TryDequeueEx(LV, LErr), 'SPMC empty TryDequeueEx fails');
    Check(LErr = lfteEmpty, 'SPMC empty not closed is lfteEmpty');
    LQ.Close;
    Check(not LQ.TryEnqueueEx(63, LErr), 'SPMC closed TryEnqueueEx fails');
    Check(LErr = lfteClosed, 'SPMC closed publish is lfteClosed');
    Check(not LQ.TryDequeueEx(LV, LErr), 'SPMC closed empty TryDequeueEx fails');
    Check(LErr = lfteClosed, 'SPMC closed empty is lfteClosed');
  finally
    LQ.Free;
  end;
end;

procedure TestMpscTryExDiagnostics;
var
  LQ: TIntMpsc;
  LV: Integer;
  LErr: TLockFreeTryError;
begin
  LQ := TIntMpsc.Create;
  try
    Check(LQ.TryEnqueueEx(71, LErr), 'MPSC TryEnqueueEx success');
    Check(LErr = lfteNone, 'MPSC success error is lfteNone');
    Check(LQ.TryDequeueEx(LV, LErr), 'MPSC TryDequeueEx success');
    CheckEqual(71, LV, 'MPSC TryDequeueEx value');
    Check(LErr = lfteNone, 'MPSC dequeue success error is lfteNone');
    Check(not LQ.TryDequeueEx(LV, LErr), 'MPSC empty TryDequeueEx fails');
    Check(LErr = lfteEmpty, 'MPSC empty not closed is lfteEmpty');
    LQ.Close;
    Check(not LQ.TryEnqueueEx(72, LErr), 'MPSC closed TryEnqueueEx fails');
    Check(LErr = lfteClosed, 'MPSC closed publish is lfteClosed');
    Check(not LQ.TryDequeueEx(LV, LErr), 'MPSC closed empty TryDequeueEx fails');
    Check(LErr = lfteClosed, 'MPSC closed empty is lfteClosed');
  finally
    LQ.Free;
  end;
end;

procedure TestStackTryExDiagnostics;
var
  LS: TIntStack;
  LV: Integer;
  LErr: TLockFreeTryError;
begin
  LS := TIntStack.Create(1);
  try
    Check(LS.TryPushEx(81, LErr), 'Stack TryPushEx success');
    Check(LErr = lfteNone, 'Stack success error is lfteNone');
    Check(not LS.TryPushEx(82, LErr), 'Stack full TryPushEx fails');
    Check(LErr = lfteFull, 'Stack full is lfteFull');
    Check(LS.TryPopEx(LV, LErr), 'Stack TryPopEx success');
    CheckEqual(81, LV, 'Stack TryPopEx value');
    Check(LErr = lfteNone, 'Stack pop success error is lfteNone');
    Check(not LS.TryPopEx(LV, LErr), 'Stack empty TryPopEx fails');
    Check(LErr = lfteEmpty, 'Stack empty not closed is lfteEmpty');
    LS.Close;
    Check(not LS.TryPushEx(83, LErr), 'Stack closed TryPushEx fails');
    Check(LErr = lfteClosed, 'Stack closed publish is lfteClosed');
    Check(not LS.TryPopEx(LV, LErr), 'Stack closed empty TryPopEx fails');
    Check(LErr = lfteClosed, 'Stack closed empty is lfteClosed');
  finally
    LS.Free;
  end;
end;

procedure TestDequeTryExDiagnostics;
var
  LD: TIntDeque;
  LV: Integer;
  LErr: TLockFreeTryError;
begin
  LD := TIntDeque.Create(1);
  try
    Check(LD.TryPushEx(91, LErr), 'Deque TryPushEx success');
    Check(LErr = lfteNone, 'Deque push success error is lfteNone');
    Check(not LD.TryPushEx(92, LErr), 'Deque full TryPushEx fails');
    Check(LErr = lfteFull, 'Deque full is lfteFull');
    Check(LD.TryPopEx(LV, LErr), 'Deque TryPopEx success');
    CheckEqual(91, LV, 'Deque TryPopEx value');
    Check(LErr = lfteNone, 'Deque pop success error is lfteNone');
    Check(not LD.TryPopEx(LV, LErr), 'Deque empty TryPopEx fails');
    Check(LErr = lfteEmpty, 'Deque empty not closed is lfteEmpty');
    Check(not LD.TryStealEx(LV, LErr), 'Deque empty TryStealEx fails');
    Check(LErr = lfteEmpty, 'Deque empty steal not closed is lfteEmpty');
    Check(LD.TryPushEx(93, LErr), 'Deque TryPushEx after empty');
    Check(LErr = lfteNone, 'Deque push after empty is lfteNone');
    Check(LD.TryStealEx(LV, LErr), 'Deque TryStealEx success');
    CheckEqual(93, LV, 'Deque TryStealEx value');
    Check(LErr = lfteNone, 'Deque steal success error is lfteNone');
    LD.Close;
    Check(not LD.TryPushEx(94, LErr), 'Deque closed TryPushEx fails');
    Check(LErr = lfteClosed, 'Deque closed publish is lfteClosed');
    Check(not LD.TryPopEx(LV, LErr), 'Deque closed empty TryPopEx fails');
    Check(LErr = lfteClosed, 'Deque closed empty pop is lfteClosed');
    Check(not LD.TryStealEx(LV, LErr), 'Deque closed empty TryStealEx fails');
    Check(LErr = lfteClosed, 'Deque closed empty steal is lfteClosed');
  finally
    LD.Free;
  end;
end;

procedure TestMsQueueTryExDiagnostics;
var
  LQ: specialize TLockFreeMsQueue<Integer>;
  LV: Integer;
  LErr: TLockFreeTryError;
begin
  LQ := specialize TLockFreeMsQueue<Integer>.Create(16);
  try
    Check(LQ.TryEnqueueEx(101, LErr), 'MSQueue TryEnqueueEx success');
    Check(LErr = lfteNone, 'MSQueue success error is lfteNone');
    Check(LQ.TryDequeueEx(LV, LErr), 'MSQueue TryDequeueEx success');
    CheckEqual(101, LV, 'MSQueue TryDequeueEx value');
    Check(LErr = lfteNone, 'MSQueue dequeue success error is lfteNone');
    Check(not LQ.TryDequeueEx(LV, LErr), 'MSQueue empty TryDequeueEx fails');
    Check(LErr = lfteEmpty, 'MSQueue empty not closed is lfteEmpty');
    LQ.Close;
    Check(not LQ.TryEnqueueEx(102, LErr), 'MSQueue closed TryEnqueueEx fails');
    Check(LErr = lfteClosed, 'MSQueue closed publish is lfteClosed');
    Check(not LQ.TryDequeueEx(LV, LErr), 'MSQueue closed empty TryDequeueEx fails');
    Check(LErr = lfteClosed, 'MSQueue closed empty is lfteClosed');
  finally
    LQ.Free;
  end;
end;

procedure TestMsQueueCloseIdempotent;
var
  LQ: specialize TLockFreeMsQueue<Integer>;
  LV: Integer;
  LErr: TLockFreeTryError;
begin
  LQ := specialize TLockFreeMsQueue<Integer>.Create(8);
  try
    Check(LQ.TryEnqueue(1), 'msq seed');
    LQ.Close;
    Check(LQ.IsClosed, 'msq closed once');
    LQ.Close;
    Check(LQ.IsClosed, 'msq closed twice still closed');
    Check(not LQ.TryEnqueue(2), 'msq TryEnqueue rejected after double Close');
    Check(not LQ.TryEnqueueEx(3, LErr), 'msq TryEnqueueEx rejected');
    Check(LErr = lfteClosed, 'msq double-close publish is lfteClosed');
    Check(LQ.TryDequeue(LV), 'msq drain after Close');
    CheckEqual(1, LV, 'msq drained value');
  finally
    LQ.Free;
  end;
end;

procedure TestStackCloseIdempotent;
var
  LS: TIntStack;
  LV: Integer;
begin
  LS := TIntStack.Create(4);
  try
    Check(LS.TryPush(9), 'stack seed');
    LS.Close;
    Check(LS.IsClosed, 'stack closed once');
    LS.Close;
    Check(LS.IsClosed, 'stack closed twice');
    Check(not LS.TryPush(10), 'stack push rejected after double Close');
    Check(LS.TryPop(LV), 'stack drain after Close');
    CheckEqual(9, LV, 'stack drained value');
  finally
    LS.Free;
  end;
end;

procedure TestSegQueueCloseIdempotent;
var
  LQ: TIntSegQueue;
  LV: Integer;
  LErr: TLockFreeTryError;
begin
  LQ := TIntSegQueue.Create;
  try
    Check(LQ.TryEnqueue(5), 'seg seed');
    LQ.Close;
    Check(LQ.IsClosed, 'seg closed once');
    LQ.Close;
    Check(LQ.IsClosed, 'seg closed twice');
    Check(not LQ.TryEnqueueEx(6, LErr), 'seg TryEnqueueEx after double Close');
    Check(LErr = lfteClosed, 'seg double-close is lfteClosed');
    Check(LQ.TryDequeue(LV), 'seg drain after Close');
    CheckEqual(5, LV, 'seg drained value');
  finally
    LQ.Free;
  end;
end;

procedure TestMsQueueDestroyCloseAndDrain;
var
  LQ: specialize TLockFreeMsQueue<Integer>;
  LV: Integer;
  LSrc, LDestroyBody: string;
begin
  LQ := specialize TLockFreeMsQueue<Integer>.Create(16);
  Check(LQ.TryEnqueue(11), 'msqueue seed enqueue');
  Check(LQ.TryEnqueue(22), 'msqueue seed enqueue 2');
  LQ.Close;
  Check(not LQ.TryEnqueue(33), 'msqueue TryEnqueue after Close is false');
  Check(LQ.TryDequeue(LV), 'msqueue drain after Close');
  CheckEqual(11, LV);
  LQ.Free;

  LQ := specialize TLockFreeMsQueue<Integer>.Create(16);
  Check(LQ.TryEnqueue(44), 'msqueue seed before destroy');
  LQ.Free;

  LSrc := ReadUtf8TextFile('../../../src/nextpas.core.lockfree.msqueue.pas');
  LDestroyBody := ExtractSection(LSrc,
    'destructor TLockFreeMsQueueImpl.Destroy;',
    'function TLockFreeMsQueueImpl.TryEnqueue',
    'MSQueue Destroy body');
  CheckContains(LDestroyBody, 'Close;', 'MSQueue Destroy must call Close');
end;

procedure TestLockFreeSourceContracts;
const
  LockFreeSourcePath = '../../../src/nextpas.core.lockfree.pas';
  LockFreeDocsReadmePath = '../../../docs/lockfree/README.md';
  CoreGoalTreePath = '../../../docs/l1-goal-tree.md';
  LockFreeTestSourcePath = 'test_lockfree.lpr';
  LockFreeStressTestSourcePath = '../test_lockfree_stress/test_lockfree_stress.lpr';
  LockFreeTestMakefilePath = 'Makefile';
  LockFreeFacadeForcedCompilePath = 'test_lockfree_facade_forced_compile.lpr';
  SpscSourcePath = '../../../src/nextpas.core.lockfree.spsc.pas';
  MpmcSourcePath = '../../../src/nextpas.core.lockfree.mpmc.pas';
  StackSourcePath = '../../../src/nextpas.core.lockfree.stack.pas';
  MpscSourcePath = '../../../src/nextpas.core.lockfree.mpsc.pas';
  DequeSourcePath = '../../../src/nextpas.core.lockfree.deque.pas';
  WaitSourcePath = '../../../src/nextpas.core.lockfree.wait.pas';
  BarrierSourcePath = '../../../src/nextpas.core.lockfree.barrier.pas';
  CondVarSourcePath = '../../../src/nextpas.core.lockfree.condvar.pas';
  SemaphoreSourcePath = '../../../src/nextpas.core.lockfree.semaphore.pas';
  FlatCombiningSourcePath = '../../../src/nextpas.core.lockfree.flatcombining.pas';
  WorkStealingSourcePath = '../../../src/nextpas.core.lockfree.workstealing.pas';
  ForkJoinSourcePath = '../../../src/nextpas.core.lockfree.forkjoin.pas';
  ChannelSourcePath = '../../../src/nextpas.core.lockfree.channel.pas';
  HashMapSourcePath = '../../../src/nextpas.core.lockfree.hashmap.pas';
  BTreeSourcePath = '../../../src/nextpas.core.lockfree.btree.pas';
  TrieSourcePath = '../../../src/nextpas.core.lockfree.trie.pas';
  SelectorImplSourcePath = '../../../src/nextpas.core.lockfree.selector.impl.pas';
  HazardSourcePath = '../../../src/nextpas.core.lockfree.hazard.pas';
  LeftRightSourcePath = '../../../src/nextpas.core.lockfree.leftright.pas';
  BenchMakefilePath = '../../../benchmarks/nextpas.core.lockfree/bench_lockfree/Makefile';
  BenchSourcePath = '../../../benchmarks/nextpas.core.lockfree/bench_lockfree/bench_lockfree.lpr';
  BenchRustComparePath = '../../../benchmarks/nextpas.core.lockfree/bench_lockfree/compare_rust/main.rs';
  BenchGoComparePath = '../../../benchmarks/nextpas.core.lockfree/bench_lockfree/compare_go/main.go';
  BenchCppComparePath = '../../../benchmarks/nextpas.core.lockfree/bench_lockfree/compare_cpp/main.cpp';
var
  LLockFreeSource: string;
  LDocsReadme: string;
  LCoreGoalTree: string;
  LTestSource: string;
  LStressTestSource: string;
  LFacadeForcedCompileSource: string;
  LFacadeForcedCompileCompactSource: string;
  LTestRuntimeHarnessSourceSection: string;
  LStressRuntimeHarnessSourceSection: string;
  LTestMakefile: string;
  LSpscSource: string;
  LMpmcSource: string;
  LStackSource: string;
  LMpscSource: string;
  LDequeSource: string;
  LWaitSource: string;
  LBarrierSource: string;
  LCondVarSource: string;
  LSemaphoreSource: string;
  LFlatCombiningSource: string;
  LWorkStealingSource: string;
  LForkJoinSource: string;
  LChannelSource: string;
  LHashMapSource: string;
  LBTreeSource: string;
  LTrieSource: string;
  LSelectorImplSource: string;
  LHazardSource: string;
  LLeftRightSource: string;
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
  LMpscCloseRaceStressSection: string;
  LMpscBasicTestSection: string;
  LMpscCloseProducerTestSection: string;
  LMpscCloseWakeTestSection: string;
  LMpscCloseWakeWaitTestSection: string;
  LMpscDestroyDrainTestSection: string;
  LFacadeUsesSection: string;
  LMpscMultiProducerTestSection: string;
  LMpscPublishWakeTestSection: string;
  LMpscTimeoutTestSection: string;
  LSpscTryEnqueueSourceSection: string;
  LStackTryPushSourceSection: string;
  LMpscEnqueueSourceSection: string;
  LDequeTryPushSourceSection: string;
  LDequeTryStealSourceSection: string;
  LSpscPublishWakeTestSection: string;
  LSpscSpaceWakeTestSection: string;
begin
  Check(FileExists(LockFreeDocsReadmePath),
    'lockfree README must exist as the module documentation entrypoint');
  Check(FileExists(LockFreeTestMakefilePath),
    'lockfree test Makefile must exist as the focused verification entrypoint');
  Check(FileExists(LockFreeFacadeForcedCompilePath),
    'lockfree facade-only forced compile fixture must exist');
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
  LCoreGoalTree := ReadUtf8TextFile(CoreGoalTreePath);
  LTestSource := ReadUtf8TextFile(LockFreeTestSourcePath);
  LStressTestSource := ReadUtf8TextFile(LockFreeStressTestSourcePath);
  LFacadeForcedCompileSource := ReadUtf8TextFile(LockFreeFacadeForcedCompilePath);
  LFacadeForcedCompileCompactSource := RemoveWhitespace(LFacadeForcedCompileSource);
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
  LBarrierSource := ReadUtf8TextFile(BarrierSourcePath);
  LCondVarSource := ReadUtf8TextFile(CondVarSourcePath);
  LSemaphoreSource := ReadUtf8TextFile(SemaphoreSourcePath);
  LFlatCombiningSource := ReadUtf8TextFile(FlatCombiningSourcePath);
  LWorkStealingSource := ReadUtf8TextFile(WorkStealingSourcePath);
  LForkJoinSource := ReadUtf8TextFile(ForkJoinSourcePath);
  LChannelSource := ReadUtf8TextFile(ChannelSourcePath);
  LHashMapSource := ReadUtf8TextFile(HashMapSourcePath);
  LBTreeSource := ReadUtf8TextFile(BTreeSourcePath);
  LTrieSource := ReadUtf8TextFile(TrieSourcePath);
  LSelectorImplSource := ReadUtf8TextFile(SelectorImplSourcePath);
  LHazardSource := ReadUtf8TextFile(HazardSourcePath);
  LLeftRightSource := ReadUtf8TextFile(LeftRightSourcePath);
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
  LMpscCloseRaceStressSection := ExtractSection(LStressTestSource,
    '{ TEST 3: MPSC High-Frequency Close Race',
    '{ TEST 4: Chase-Lev Extreme Steal Contention',
    'MPSC close-race stress test source section');
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
    'procedure TestMpscDestroyAutoCloseAndDrain;',
    'MPSC close wake wait test source section');
  LMpscDestroyDrainTestSection := ExtractSection(LTestSource,
    'procedure TestMpscDestroyAutoCloseAndDrain;',
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
  LSpscTryEnqueueSourceSection := ExtractSection(LSpscSource,
    'function TSpscQueueImpl.TryEnqueue',
    'function TSpscQueueImpl.TryDequeue',
    'SPSC TryEnqueue source section');
  LStackTryPushSourceSection := ExtractSection(LStackSource,
    'function TLockFreeStackImpl.TryPush',
    'function TLockFreeStackImpl.TryPop',
    'stack TryPush source section');
  LMpscEnqueueSourceSection := ExtractSection(LMpscSource,
    'procedure TMpscQueueImpl.PublishNode',
    'function TMpscQueueImpl.TryDequeue',
    'MPSC Enqueue source section');
  LDequeTryPushSourceSection := ExtractSection(LDequeSource,
    'function TWorkStealingDequeImpl.TryPush',
    'function TWorkStealingDequeImpl.TryPop',
    'deque TryPush source section');
  LDequeTryStealSourceSection := ExtractSection(LDequeSource,
    'function TWorkStealingDequeImpl.TrySteal',
    'function TWorkStealingDequeImpl.IsEmpty',
    'deque TrySteal source section');

  CheckContains(LDocsReadme, '# nextpas.core.lockfree',
    'lockfree README must use the module title');
  CheckContains(LTestMakefile, 'FACADE_FORCED_COMPILE_SOURCE := test_lockfree_facade_forced_compile.lpr',
    'lockfree Makefile must name the facade-only forced compile fixture');
  CheckContains(LTestMakefile, 'compile-facade-host:',
    'lockfree Makefile must provide a host facade-only forced compile target');
  CheckContains(LTestMakefile, 'lockfree-facade-forced-compile-target=host status=pass',
    'lockfree facade forced compile target must print a pass evidence line');
  CheckContains(LTestMakefile, 'test-forced-compile: compile-facade-host',
    'lockfree Makefile must expose the facade forced compile gate');
  CheckContains(LTestMakefile, 'lockfree-forced-compile-status=pass',
    'lockfree forced compile target must print a pass evidence line');
  CheckContains(LDocsReadme,
    'make -C core/tests/nextpas.core.lockfree/test_lockfree clean test-forced-compile',
    'lockfree README must list the facade-only forced compile gate');
  CheckContains(LFacadeForcedCompileCompactSource,
    'usesnextpas.core.lockfree;',
    'lockfree facade forced compile fixture must import only the public facade unit');
  CheckContains(LFacadeForcedCompileSource, 'specialize TSpscQueue<Integer>',
    'lockfree facade forced compile fixture must touch the SPSC public wrapper');
  CheckContains(LFacadeForcedCompileSource, 'specialize TMpmcQueue<Integer>',
    'lockfree facade forced compile fixture must touch the MPMC public wrapper');
  CheckContains(LFacadeForcedCompileSource, 'specialize TMpscQueue<Integer>',
    'lockfree facade forced compile fixture must touch the MPSC public wrapper');
  CheckContains(LFacadeForcedCompileSource, 'specialize TLockFreeStack<Integer>',
    'lockfree facade forced compile fixture must touch the stack public wrapper');
  CheckContains(LFacadeForcedCompileSource, 'specialize TWorkStealingDeque<Integer>',
    'lockfree facade forced compile fixture must touch the deque public wrapper');
  CheckContains(LFacadeForcedCompileSource, 'EnqueueBatch(',
    'lockfree facade forced compile fixture must touch queue batch enqueue signatures');
  CheckContains(LFacadeForcedCompileSource, 'DequeueBatch(',
    'lockfree facade forced compile fixture must touch queue batch dequeue signatures');
  CheckContains(LFacadeForcedCompileSource, 'DequeueWait(',
    'lockfree facade forced compile fixture must touch blocking dequeue signatures');
  CheckContains(LFacadeForcedCompileSource, 'DequeueTimeout(',
    'lockfree facade forced compile fixture must touch timeout dequeue signatures');
  CheckContains(LFacadeForcedCompileSource, 'TryPush(',
    'lockfree facade forced compile fixture must touch stack/deque push signatures');
  CheckContains(LFacadeForcedCompileSource, 'TrySteal(',
    'lockfree facade forced compile fixture must touch deque steal signatures');
  CheckContains(LFacadeForcedCompileSource, 'specialize TSegQueue<Integer>',
    'lockfree facade forced compile fixture must touch the SegQueue public wrapper');
  CheckContains(LFacadeForcedCompileSource, 'specialize TSpmcQueue<Integer>',
    'lockfree facade forced compile fixture must touch the SPMC public wrapper');
  CheckNotContains(LFacadeForcedCompileSource, 'TSpscQueueImpl',
    'lockfree facade forced compile fixture must not rely on the SPSC implementation type');
  CheckNotContains(LFacadeForcedCompileSource, 'TMpmcQueueImpl',
    'lockfree facade forced compile fixture must not rely on the MPMC implementation type');
  CheckNotContains(LFacadeForcedCompileSource, 'TMpscQueueImpl',
    'lockfree facade forced compile fixture must not rely on the MPSC implementation type');
  CheckNotContains(LFacadeForcedCompileSource, 'TLockFreeStackImpl',
    'lockfree facade forced compile fixture must not rely on the stack implementation type');
  CheckNotContains(LFacadeForcedCompileSource, 'TWorkStealingDequeImpl',
    'lockfree facade forced compile fixture must not rely on the deque implementation type');
  CheckNotContains(LFacadeForcedCompileSource, 'TSegQueueImpl',
    'lockfree facade forced compile fixture must not rely on the SegQueue implementation type');
  CheckNotContains(LFacadeForcedCompileSource, 'TSpmcQueueImpl',
    'lockfree facade forced compile fixture must not rely on the SPMC implementation type');
  CheckNotContains(LFacadeForcedCompileSource, 'nextpas.core.lockfree.base',
    'lockfree facade forced compile fixture must not import lockfree base helpers directly');
  CheckNotContains(LFacadeForcedCompileSource, 'nextpas.core.lockfree.wait',
    'lockfree facade forced compile fixture must not import lockfree wait helpers directly');
  CheckNotContains(LFacadeForcedCompileSource, 'nextpas.core.lockfree.spsc',
    'lockfree facade forced compile fixture must not import the SPSC implementation unit');
  CheckNotContains(LFacadeForcedCompileSource, 'nextpas.core.lockfree.mpmc',
    'lockfree facade forced compile fixture must not import the MPMC implementation unit');
  CheckNotContains(LFacadeForcedCompileSource, 'nextpas.core.lockfree.mpsc',
    'lockfree facade forced compile fixture must not import the MPSC implementation unit');
  CheckNotContains(LFacadeForcedCompileSource, 'nextpas.core.lockfree.stack',
    'lockfree facade forced compile fixture must not import the stack implementation unit');
  CheckNotContains(LFacadeForcedCompileSource, 'nextpas.core.lockfree.deque',
    'lockfree facade forced compile fixture must not import the deque implementation unit');
  CheckNotContains(LFacadeForcedCompileSource, 'nextpas.core.lockfree.ebr',
    'lockfree facade forced compile fixture must not import the EBR implementation unit');
  CheckNotContains(LFacadeForcedCompileSource, 'nextpas.core.lockfree.segqueue',
    'lockfree facade forced compile fixture must not import the SegQueue implementation unit');
  CheckNotContains(LFacadeForcedCompileSource, 'nextpas.core.lockfree.spmc',
    'lockfree facade forced compile fixture must not import the SPMC implementation unit');
  CheckContains(LDocsReadme,
    'Progress-guarantee matrix',
    'lockfree README must include an explicit progress-guarantee matrix');
  CheckContains(LDocsReadme,
    'TShardedHashMap` / `TConcurrentHashMap` | **lock-based concurrent**',
    'lockfree README matrix must mark sharded HashMap as lock-based concurrent');
  CheckContains(LDocsReadme,
    '**T1-only** 默认 facade',
    'lockfree README must document T1-only default facade');
  CheckContains(LDocsReadme, 'TSegQueue<T>',
    'lockfree README must document SegQueue in the facade re-export surface');
  CheckContains(LDocsReadme, 'TSpmcQueue<T>',
    'lockfree README must document SPMC queue in the facade re-export surface');
  CheckContains(LDocsReadme,
    'SPSC/MPMC/MPSC/SPMC/SegQueue/MSQueue, Stack, WorkStealingDeque, EBR/Hazard, Channel, Selector, ShardedHashMap',
    'lockfree README must document the T1 runtime-core surface');
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
  CheckContains(LLockFreeSource,
    'generic TSegQueue<T> = class(specialize TSegQueueImpl<T>)',
    'lockfree facade must explicitly expose the SegQueue type');
  CheckContains(LLockFreeSource,
    'generic TSpmcQueue<T> = class(specialize TSpmcQueueImpl<T>)',
    'lockfree facade must explicitly expose the SPMC queue type');
  CheckContains(LDocsReadme, '`TSpscQueue<T>`',
    'lockfree README must document SPSC queue ownership');
  CheckContains(LDocsReadme, '`TMpmcQueue<T>`',
    'lockfree README must document MPMC queue ownership');
  CheckContains(LDocsReadme, '`TMpscQueue<T>`',
    'lockfree README must document MPSC queue ownership');
  CheckContains(LDocsReadme, '`TSegQueue<T>`',
    'lockfree README must document SegQueue ownership');
  CheckContains(LDocsReadme, '`TSpmcQueue<T>`',
    'lockfree README must document SPMC queue ownership');
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
    '`TSpmcQueue<T>` permits exactly one producer and multiple concurrent consumers',
    'lockfree README must document the SPMC caller-role contract');
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
    '`TMpscQueue<T>` permits multiple producers and exactly one consumer; `TryEnqueue` observes `Close` and returns False; plain `Enqueue` raises `EInvalidOperationError` after `Close`; callers must Close → join producers/waiters → Free.',
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
    'All T1 element-generic containers (`TSpscQueue`, `TMpmcQueue`, `TMpscQueue`, `TSpmcQueue`, `TSegQueue`, `TLockFreeMsQueue`, `TLockFreeStack`, `TWorkStealingDeque`, `TLockFreeChannel`, `TLockFreeChannelSpsc`, `TShardedHashMap` keys/values) reject managed types at construction with `EArgumentError`.',
    'lockfree README must document constructor-time managed-type rejection for every public structure');
  CheckContains(LDocsReadme,
    '`TMpscQueue.Destroy` 会调用 `Close` 以唤醒阻塞中的单消费者，然后 drain 剩余节点。',
    'lockfree README must document MPSC Destroy Close+drain wake discipline');
  CheckContains(LDocsReadme,
    '`TLockFreeStack<T>` permits multiple concurrent `TryPush` / `TryPop` callers over its fixed slot pool; capacity bounds and unmanaged element restrictions still apply.',
    'lockfree README must document the stack caller-role contract');
  CheckContains(LDocsReadme,
    '`TWorkStealingDeque<T>` permits exactly one owner thread for `TryPush` / `TryPop` and multiple thief threads for `TrySteal`; owner methods are not multi-owner safe.',
    'lockfree README must document the deque caller-role contract');
  CheckContains(LDocsReadme, 'Linearization points',
    'lockfree README must name linearization points');
  CheckContains(LDocsReadme,
    '`TSpmcQueue<T>.TryEnqueue`',
    'lockfree README must document SPMC linearization points');
  CheckContains(LDocsReadme,
    '`TSpmcQueue<T>.TryDequeue`',
    'lockfree README must document SPMC dequeue linearization point');
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
    '`TWorkStealingDeque<T>` rounds requested capacity up to power-of-two storage; `Capacity` returns that live ring bound, `TryPush` returns `False` when the deque is full or closed, and `ApproxCount` / `IsEmpty` are snapshot helpers over current top/bottom counters rather than multi-thread linearization guarantees.',
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
  CheckContains(LMpmcSource, 'if IsManagedType(T) then',
    'MPMC queue must reject managed element types');
  CheckContains(LMpscSource, 'if IsManagedType(T) then',
    'MPSC queue must reject managed element types');
  CheckContains(LStackSource, 'if IsManagedType(T) then',
    'stack must reject managed element types');
  CheckContains(LDequeSource, 'if IsManagedType(T) then',
    'deque must reject managed element types');
  CheckContains(LChannelSource, 'if IsManagedType(T) then',
    'channel must reject managed element types');
  CheckContains(LHashMapSource, 'if IsManagedType(TKey) then',
    'sharded hashmap must reject managed keys');
  CheckContains(LHashMapSource, 'if IsManagedType(TValue) then',
    'sharded hashmap must reject managed values');
  CheckContains(LBTreeSource, 'if IsManagedType(TKey) then',
    'btree must reject managed keys');
  CheckContains(LBTreeSource, 'if IsManagedType(TValue) then',
    'btree must reject managed values');
  CheckContains(LTrieSource, 'if IsManagedType(TValue) then',
    'trie must reject managed values');
  CheckContains(LSelectorImplSource, 'if IsManagedType(T) then',
    'selector must reject managed element types');
  CheckContains(LSelectorImplSource, 'atomic_load(FNotifyEpoch, mo_acquire)',
    'selector wait path must use preferred atomic_load on FNotifyEpoch');
  CheckContains(LSelectorImplSource, 'atomic_fetch_add(FNotifyWaiters, 1, mo_acq_rel)',
    'selector wait path must use preferred atomic_fetch_add on FNotifyWaiters');
  CheckContains(LSelectorImplSource, 'atomic_fetch_sub(FNotifyWaiters, 1, mo_acq_rel)',
    'selector wait path must use preferred atomic_fetch_sub on FNotifyWaiters');
  CheckContains(LSelectorImplSource, 'LockFreeWaitData(@FNotifyEpoch, @FNotifyWaiters',
    'selector must wait via LockFreeWaitData (wait-address), not pure spin only');
  CheckNotContains(LSelectorImplSource, 'AtomicLoad32(',
    'selector must not use legacy AtomicLoad32 on hot path (Q3-a preferred)');
  CheckNotContains(LSelectorImplSource, 'AtomicFetchAdd32(',
    'selector must not use legacy AtomicFetchAdd32 (Q3-a preferred)');
  CheckContains(LSpscSource, 'LockFreeNotifyData(@FDataEpoch, @FDataWaiters)',
    'SPSC queue must notify data waiters after publish');
  CheckContains(LSpscSource, 'LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters)',
    'SPSC queue must notify space waiters after consume');
  CheckBefore(LSpscTryEnqueueSourceSection,
    'FSlots[LTail and Int64(FMask)] := AValue;',
    'atomic_store_64(FTailPublished, LTail + 1, mo_release);',
    'SPSC TryEnqueue must write the slot value before publishing the tail');
  CheckContains(LSpscTryEnqueueSourceSection,
    'atomic_store_64(FTailPublished, LTail + 1, mo_release);',
    'SPSC TryEnqueue tail publish must use release ordering');
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
  CheckContains(LSpscBatchSourceSection, 'if atomic_load(FClosed, mo_acquire) <> 0 then',
    'SPSC batch enqueue must reject new items after close');
  CheckContains(LSpscBatchSourceSection, 'FHeadCache := atomic_load_64(FHeadPublished, mo_acquire);',
    'SPSC batch enqueue must refresh published head before sizing batch progress');
  CheckContains(LSpscBatchSourceSection, 'if LCount > PtrUInt(LAvail) then',
    'SPSC batch enqueue must cap published items to currently available space');
  CheckContains(LSpscDequeueBatchSourceSection, 'FTailCache := atomic_load_64(FTailPublished, mo_acquire);',
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
  CheckContains(LMpmcSource, 'atomic_store_64(FSlots[LIdx].Sequence, FullSequence(LPos), mo_release)',
    'MPMC enqueue linearization must publish slot sequence with release ordering');
  CheckContains(LMpmcSource, 'FActiveEnqueues: Int32;',
    'MPMC queue must track admitted producer operations that may still publish after Close');
  CheckContains(LMpmcSource, 'function ClosedAndNoActiveEnqueues: Boolean; inline;',
    'MPMC queue must centralize closed-empty terminal checks behind active producer tracking');
  CheckContains(LMpmcSource, 'procedure LeaveActiveEnqueue; inline;',
    'MPMC queue must centralize active producer decrement and wake handling');
  CheckContains(LMpmcTryEnqueueSourceSection, 'atomic_fetch_add(FActiveEnqueues, 1, mo_acq_rel);',
    'MPMC TryEnqueue must admit active producers before any slot reservation can happen');
  CheckBefore(LMpmcTryEnqueueSourceSection,
    'atomic_fetch_add(FActiveEnqueues, 1, mo_acq_rel);',
    'if atomic_load(FClosed, mo_acquire) <> 0 then',
    'MPMC TryEnqueue must admit active producers before the first Close observation');
  CheckContains(LMpmcTryEnqueueSourceSection, 'LeaveActiveEnqueue;',
    'MPMC TryEnqueue must decrement active producer tracking on every exit path');
  CheckContains(LMpmcTryEnqueueSourceSection, 'if atomic_load(FClosed, mo_acquire) <> 0 then' + LineEnding + '      Exit(False);',
    'MPMC TryEnqueue must re-check Close after admission but before reserving a slot');
  CheckContains(LMpmcLeaveActiveSourceSection, 'atomic_fetch_sub(FActiveEnqueues, 1, mo_acq_rel) = 1',
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
  CheckContains(LMpmcSource, 'atomic_store_64(FSlots[LIdx].Sequence, EmptySequence(LPos + Int64(FCapacity)), mo_release)',
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
    'T.Test(''MPMC single-slot 2P+2C exactly-once'', @TestMpmcSingleSlotContention);',
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
  CheckContains(LMpscCloseRaceStressSection, 'GMpscCloseSeen',
    'MPSC close-race stress must track every dequeued token for exactly-once ownership');
  CheckContains(LMpscCloseRaceStressSection, 'GMpscCloseOutOfRange',
    'MPSC close-race stress must count out-of-range dequeued tokens defensively');
  CheckContains(LMpscCloseRaceStressSection, 'MPSC close race no out-of-range messages',
    'MPSC close-race stress must prove dequeued tokens stay inside the sent-token domain');
  CheckContains(LMpscCloseRaceStressSection, 'MPSC close race no duplicate messages',
    'MPSC close-race stress must prove no producer token is dequeued more than once');
  CheckContains(LMpscCloseRaceStressSection, 'MPSC close race no missing messages',
    'MPSC close-race stress must prove every sent producer token is drained after close');
  CheckContains(LMpscCloseRaceStressSection, 'GMpscCloseFinished',
    'MPSC close-race stress must track whether close interrupts active producers');
  CheckContains(LMpscCloseRaceStressSection, 'MPSC close race closed while producers were still live',
    'MPSC close-race stress must not degenerate into a completed-producers drain test');
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
    'T.Test(''MPMC timeout wakes on publish'', @TestMpmcDequeueTimeoutWakesOnPublish);',
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
    'T.Test(''MPMC timeout wakes on space release'', @TestMpmcEnqueueTimeoutWakesOnSpace);',
    'lockfree test runner must register the MPMC space wake runtime test');
  CheckContains(LMpmcBatchSourceSection, 'if atomic_load(FClosed, mo_acquire) <> 0 then',
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
    'T.Test(''MPMC close races active producers'', @TestMpmcCloseRacesActiveProducers);',
    'MPMC stress suite must run active-producer close race coverage');
  CheckContains(LStressTestSource,
    'T.Test(''MPMC close races active producers timeout'', @TestMpmcCloseRacesActiveProducersTimeout);',
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
  CheckBefore(LStackTryPushSourceSection,
    'FSlots[LIdx].Value := AValue;',
    'atomic_compare_exchange_strong_64(FTop, LExpected, LNewTop',
    'stack TryPush must write the slot value before publishing it through the top CAS');
  CheckBefore(LStackTryPushSourceSection,
    'FSlots[LIdx].Next := UnpackIdx(LOldTop);',
    'atomic_compare_exchange_strong_64(FTop, LExpected, LNewTop',
    'stack TryPush must link the previous top before publishing through the top CAS');
  CheckContains(LStackTryPushSourceSection,
    'atomic_compare_exchange_strong_64(FTop, LExpected, LNewTop,' + LineEnding +
    '    mo_acq_rel, mo_acquire)',
    'stack TryPush top CAS must use acquire-release success with acquire failure');
  CheckContains(LDequeSource, 'LCap := LockFreeNextPow2(ACapacity);',
    'deque constructor must round requested capacity to power-of-two storage');
  CheckContains(LDequeSource, 'if LSize >= Int64(FCapacity) then',
    'deque owner push must reject writes once the bounded ring is full');
  CheckBefore(LDequeTryPushSourceSection,
    'FBuffer[PtrUInt(LBottom) and FMask] := AValue;',
    'atomic_store_64(FBottom, LBottom + 1, mo_release);',
    'deque owner TryPush must write the buffer slot before release-publishing bottom');
  CheckContains(LDequeTryPushSourceSection, 'atomic_store_64(FBottom, LBottom + 1, mo_release);',
    'deque owner TryPush bottom publish must use release ordering');
  CheckContains(LDequeSource, 'atomic_store_64(FBottom, LBottom, mo_seq_cst);',
    'deque owner pop must publish the speculative bottom decrement as seq_cst before last-item arbitration');
  CheckContains(LDequeSource, 'LTop := atomic_load_64(FTop, mo_seq_cst);',
    'deque owner pop must observe top with seq_cst before last-item arbitration');
  CheckContains(LDequeSource,
    'atomic_compare_exchange_strong_64(FTop, LExpected, LTop + 1,' + LineEnding +
    '        mo_seq_cst, mo_seq_cst)',
    'deque owner pop must arbitrate the last item with a seq_cst top CAS');
  CheckContains(LDequeSource, 'LTop := atomic_load_64(FTop, mo_seq_cst);' + LineEnding +
    '  LBottom := atomic_load_64(FBottom, mo_seq_cst);',
    'deque thief steal must observe top and bottom with seq_cst before stealing');
  CheckBefore(LDequeTryStealSourceSection,
    'AValue := FBuffer[PtrUInt(LTop) and FMask];',
    'atomic_compare_exchange_strong_64(FTop, LExpected, LTop + 1,' + LineEnding +
    '    mo_seq_cst, mo_seq_cst)',
    'deque thief TrySteal must read the candidate value before winning it through the top CAS');
  CheckContains(LDequeTryStealSourceSection,
    'atomic_compare_exchange_strong_64(FTop, LExpected, LTop + 1,' + LineEnding +
    '    mo_seq_cst, mo_seq_cst)',
    'deque thief TrySteal top CAS must use seq_cst ordering');
  CheckContains(LDocsReadme,
    '`TWorkStealingDeque<T>` last-item owner/thief arbitration uses `seq_cst` ordering on `FTop` / `FBottom` loads, bottom store, and top CAS so the single remaining item is won exactly once.',
    'lockfree README must document the deque seq_cst last-item arbitration contract');
  CheckContains(LCoreGoalTree,
    '| `lockfree` | 无锁 (MPMC/SPSC/MPSC/Stack/Deque) | source-contract / focused runtime / stress:',
    'goal tree must report lockfree by evidence level instead of broad completion wording');
  CheckContains(LCoreGoalTree, 'lockfree stress 14/14',
    'goal tree evidence header must report the current lockfree stress count');
  CheckNotContains(LCoreGoalTree, 'lockfree stress 13/13',
    'goal tree evidence header must not keep stale lockfree stress count');
  CheckNotContains(LCoreGoalTree,
    '| `lockfree` | 无锁 (MPMC/SPSC/MPSC/Stack/Deque) | ✅ 完成/强化中',
    'goal tree must not report lockfree as broad completion without evidence-level truth');
  CheckContains(LChannelSource, 'TLockFreeChannel.Send: channel closed',
    'channel Send on closed must raise EInvalidOperationError');
  CheckContains(LHashMapSource, 'atomic_exchange(AShard.Lock, 1, mo_acquire)',
    'hashmap ShardLock must use atomic_exchange with mo_acquire');
  CheckContains(LHazardSource, 'AllocMem(SizeOf(THazardThreadRec))',
    'hazard RegisterThread must use AllocMem for zero-init');
  CheckNotContains(LHazardSource, 'AtomicStorePtr(Pointer(FThreads), nil, moRelease)',
    'hazard UnregisterThread must not blindly nil FThreads');
  CheckContains(LHazardSource,
    'atomic_store(LThread^.HP[AHPIndex], APtr, mo_release);',
    'hazard Protect must publish its pointer with a release store');
  CheckContains(LHazardSource,
    'atomic_load(LThread^.HP[LI], mo_acquire)',
    'hazard Collect must scan pointer publications with acquire loads');
  CheckNotContains(LHazardSource, 'procedure THazardDomain.DrainPendingFree;',
    'hazard thread records must not be reclaimed by an unprotected list traversal');
  CheckContains(LHazardSource, 'function THazardDomain.ProtectSource',
    'hazard domain must expose a publish-and-revalidate source protection loop');
  CheckBefore(LHazardSource,
    'IncrementRetiredCount;',
    'atomic_compare_exchange_strong(Pointer(FRetired), LExpected, Pointer(LNode), mo_release, mo_relaxed)',
    'hazard retired count must be published before the retired node becomes collectable');
  CheckContains(LCondVarSource, 'PConditionWaiter = ^TConditionWaiter;',
    'condition-variable notifications must be attached to registered waiter lifetimes');
  CheckNotContains(LCondVarSource, 'FSignalCount:',
    'condition-variable Signal must not leave a shared token consumable by future waiters');
  CheckContains(LBarrierSource, 'PBarrierGeneration = ^TBarrierGeneration;',
    'barrier outcomes must remain attached to a generation until its waiters leave');
  CheckNotContains(LBarrierSource, 'BARRIER_BROKEN_BIT',
    'barrier must not retain only one previous generation broken bit');
  CheckContains(LLeftRightSource,
    'if atomic_load(FReadIndex, mo_acquire) = LReadIdx then' + LineEnding +
    '      Break;',
    'left-right readers must revalidate the replica index after publishing their presence');
  CheckContains(LSemaphoreSource,
    'atomic_compare_exchange_strong_64(FAvailable, LOld, LOld - 1, mo_acquire, mo_acquire)',
    'semaphore acquire must synchronize with permit release');
  CheckContains(LSemaphoreSource,
    'atomic_compare_exchange_strong_64(FAvailable, LOld, LOld + 1, mo_release, mo_relaxed)',
    'semaphore release must publish protected writes before handing off a permit');
  CheckContains(LFlatCombiningSource,
    'atomic_store(LPub^.OwnerThreadId, 0, mo_release);',
    'flat-combining Apply must release its publication slot after consuming the result');
  CheckNotContains(LFlatCombiningSource, 'Fallback: should not happen with 256 slots',
    'flat-combining publication exhaustion must wait for a free slot instead of aliasing an active slot');
  CheckContains(LWorkStealingSource, 'AcquireOwner(LWorkerIndex);',
    'work-stealing Submit must serialize the single-owner deque push side');
  CheckContains(LWorkStealingSource, 'AcquireOwner(LQueueIndex);',
    'work-stealing fallback pop must serialize the single-owner deque pop side');
  CheckContains(LForkJoinSource,
    'if (AWorkerId < 0) or (AWorkerId >= FWorkerCount) then',
    'fork-join PopOrSteal must reject invalid worker IDs before indexing a deque');
  CheckContains(LWaitSource, 'if (AEpoch = nil) or (AWaiters = nil) then',
    'lockfree wait helper must reject nil counter addresses before dereferencing them');
  CheckContains(LMpscSource, 'Close;' + LineEnding + '  while TryDequeue(LV) do;',
    'MPSC destroy must Close then drain remaining nodes');
  CheckContains(LMpscSource, 'Wake any blocked single-consumer DequeueWait/Timeout',
    'MPSC destroy must document wake-on-destroy for blocked consumers');
  CheckContains(LMpscBasicTestSection, 'LQ.Close;' + LineEnding + '  LQ.Free;',
    'MPSC basic test must close before freeing the queue');
  CheckContains(LMpscCloseProducerTestSection,
    'Check(LQ.IsClosed, ''closed'');',
    'MPSC close producer contract test must assert closed state first');
  CheckContains(LMpscCloseProducerTestSection,
    'Check(not LQ.TryEnqueue(42), ''TryEnqueue after close rejected'');',
    'MPSC close producer contract test must reject TryEnqueue after close');
  CheckContains(LMpscCloseProducerTestSection,
    'Check(LGot, ''Enqueue after close raises EInvalidOperationError'');',
    'MPSC close producer contract test must raise on Enqueue after close');
  CheckContains(LMpscSource,
    'raise EInvalidOperationError.Create(''TMpscQueue: Enqueue on closed queue'');',
    'MPSC Enqueue must raise on closed queue');
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
    'LQ.Free;',
    'MPSC destroy auto-drain contract test must free an undrained queue safely');
  CheckContains(LMpscDestroyDrainTestSection,
    'Check(LQ.TryDequeue(LV), ''drain queued MPSC item before destroy'');',
    'MPSC destroy drain contract test must still cover explicit drain before free');
  { Restrict T2/T3 absence checks to the interface uses clause so documentation
    may still mention direct-unit import examples (e.g. skiplist) without failing. }
  LFacadeUsesSection := ExtractSection(LLockFreeSource,
    LineEnding + 'uses' + LineEnding,
    LineEnding + 'const' + LineEnding,
    'T1 facade uses clause');
  CheckContains(LFacadeUsesSection, 'nextpas.core.lockfree.msqueue',
    'T1 facade must pull MSQueue');
  CheckContains(LFacadeUsesSection, 'nextpas.core.lockfree.hashmap',
    'T1 facade must pull sharded HashMap');
  CheckNotContains(LFacadeUsesSection, 'nextpas.core.lockfree.skiplist',
    'T1 facade must not pull T2 skiplist');
  CheckNotContains(LFacadeUsesSection, 'nextpas.core.lockfree.rbtree',
    'T1 facade must not pull T2 rbtree');
  CheckNotContains(LFacadeUsesSection, 'nextpas.core.lockfree.crdt',
    'T1 facade must not pull T3 CRDT');
  CheckNotContains(LFacadeUsesSection, 'nextpas.core.lockfree.hashmap.rtm',
    'T1 facade must not pull RTM HashMap extension');
  CheckNotContains(LFacadeUsesSection, 'nextpas.core.lockfree.hashmap.numa',
    'T1 facade must not pull NUMA HashMap extension');
  CheckNotContains(LFacadeUsesSection, 'nextpas.core.lockfree.mutex',
    'T1 facade must not pull mutex (sync-style primitive stays direct-unit)');
  CheckNotContains(LFacadeUsesSection, 'nextpas.core.lockfree.bloom',
    'T1 facade must not pull T2 bloom filter');
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
    'T.Test(''MPSC timeout wakes on publish'', @TestMpscDequeueTimeoutWakesOnPublish);',
    'lockfree test runner must register the MPSC publish wake runtime test');
  CheckContains(LMpscTimeoutTestSection, 'LQ.Close;' + LineEnding + '  LQ.Free;',
    'MPSC timeout test must close before freeing the queue');
  CheckContains(LTestMakefile, '.PHONY: build run test compile-facade-host compile-t2-isolation-host test-forced-compile test-t2-isolation-compile test-debug clean',
    'lockfree test Makefile must expose focused, forced compile, T2 isolation, and DEBUG verification targets');
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
    'function LoadNode(var ANode: PNode; const AOrder: memory_order_t): PNode;',
    'MPSC queue must define a pointer-sized atomic node load helper');
  CheckContains(LMpscSource,
    'procedure StoreNode(var ANode: PNode; const AValue: PNode; const AOrder: memory_order_t);',
    'MPSC queue must define a pointer-sized atomic node store helper');
  CheckContains(LMpscSource,
    'function ExchangeNode(var ANode: PNode; const AValue: PNode; const AOrder: memory_order_t): PNode;',
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
  CheckBefore(LMpscEnqueueSourceSection,
    'LNode^.Value := AValue;',
    'LPrev := ExchangeNode(FHead, LNode, mo_acq_rel);',
    'MPSC Enqueue must initialize the node value before exchanging the head');
  CheckBefore(LMpscEnqueueSourceSection,
    'LNode^.Next := nil;',
    'LPrev := ExchangeNode(FHead, LNode, mo_acq_rel);',
    'MPSC Enqueue must initialize the node link before exchanging the head');
  CheckContains(LMpscEnqueueSourceSection,
    'LPrev := ExchangeNode(FHead, LNode, mo_acq_rel);',
    'MPSC Enqueue head exchange must use acquire-release ordering');
  CheckBefore(LMpscEnqueueSourceSection,
    'LPrev := ExchangeNode(FHead, LNode, mo_acq_rel);',
    'StoreNode(LPrev^.Next, LNode, mo_release);',
    'MPSC Enqueue must exchange the head before release-linking the previous node');
  CheckContains(LMpscEnqueueSourceSection,
    'StoreNode(LPrev^.Next, LNode, mo_release);',
    'MPSC Enqueue previous-node link publish must use release ordering');
  if Pos('atomic_compare_exchange_strong_64(FTop', LDequeSource) = 0 then
    raise EAssertionFailed.Create(
      'work-stealing deque must linearize steals through top CAS ' +
      '(preferred atomic_compare_exchange_strong_64 or legacy AtomicCompareExchange64)');
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
  { Preferred path atomic_load(…, mo_acquire); legacy AtomicLoad32 still accepted. }
  if (Pos('if atomic_load(AEpoch^, mo_acquire) <> AExpectedEpoch then', LWaitSource) = 0) and
     (Pos('if atomic_load(AEpoch^, mo_acquire) <> AExpectedEpoch then', LWaitSource) = 0) then
    raise EAssertionFailed.Create(
      'lockfree wait helper must skip blocking when the epoch already advanced ' +
      '(preferred atomic_load+mo_acquire or legacy AtomicLoad32+mo_acquire)');
  CheckContains(LWaitSource, 'platform_wait_address32(AEpoch, AExpectedEpoch, ATimeoutNs);',
    'lockfree wait helper must wait on the caller-observed epoch');
  CheckContains(LSpscSource, 'LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LOCKFREE_WAIT_TIMEOUT_NS);',
    'SPSC blocking enqueue must pass the observed space epoch to wait helper');
  CheckContains(LSpscSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LOCKFREE_WAIT_TIMEOUT_NS);',
    'SPSC blocking dequeue must pass the observed data epoch to wait helper');
  CheckContains(LSpscSource, 'LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LRemaining);',
    'SPSC timeout enqueue must pass the observed space epoch to wait helper');
  CheckContains(LSpscSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);',
    'SPSC timeout dequeue must pass the observed data epoch to wait helper');
  CheckContains(LMpmcSource, 'LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LOCKFREE_WAIT_TIMEOUT_NS);',
    'MPMC blocking enqueue must pass the observed space epoch to wait helper');
  CheckContains(LMpmcSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LOCKFREE_WAIT_TIMEOUT_NS);',
    'MPMC blocking dequeue must pass the observed data epoch to wait helper');
  CheckContains(LMpmcSource, 'LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LRemaining);',
    'MPMC timeout enqueue must pass the observed space epoch to wait helper');
  CheckContains(LMpmcSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);',
    'MPMC timeout dequeue must pass the observed data epoch to wait helper');
  CheckContains(LMpscSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LOCKFREE_WAIT_TIMEOUT_NS);',
    'MPSC blocking dequeue must pass the observed data epoch to wait helper');
  CheckContains(LMpscSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);',
    'MPSC timeout dequeue must pass the observed data epoch to wait helper');
  if (Pos('atomic_fetch_add(AWaiters^, 1, mo_acq_rel)', LWaitSource) = 0) and
     (Pos('atomic_fetch_add(AWaiters^, 1, mo_acq_rel)', LWaitSource) = 0) then
    raise EAssertionFailed.Create(
      'lockfree wait helper must register waiters before blocking ' +
      '(preferred atomic_fetch_add+mo_acq_rel or legacy AtomicFetchAdd32)');
  if (Pos('atomic_fetch_sub(AWaiters^, 1, mo_acq_rel)', LWaitSource) = 0) and
     (Pos('atomic_fetch_sub(AWaiters^, 1, mo_acq_rel)', LWaitSource) = 0) then
    raise EAssertionFailed.Create(
      'lockfree wait helper must unregister waiters after blocking ' +
      '(preferred atomic_fetch_sub+mo_acq_rel or legacy AtomicFetchSub32)');
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
  CheckContains(LBenchSource, 'WriteLn(''Platform: '', OSName, ''/'', CPUName)',
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
  CheckContains(LRustCompareSource, '"Platform: {} {}"',
    'Rust comparison source must print the platform evidence field');
  CheckContains(LRustCompareSource, 'std::env::consts::OS',
    'Rust comparison source platform line must use std::env::consts::OS');
  CheckContains(LRustCompareSource, 'std::env::consts::ARCH',
    'Rust comparison source platform line must use std::env::consts::ARCH');
  CheckContains(LRustCompareSource, 'Compiler flags: rustc -C opt-level=3',
    'Rust comparison source must print the compiler-flags evidence field');
  CheckContains(LRustCompareSource, 'Input size: OPS=1000000; capacity=1024',
    'Rust comparison source must print the input-size evidence field');
  CheckContains(LRustCompareSource, 'manual comparison source, not auto-run',
    'Rust comparison source must print honesty/envelope baseline guidance');
  CheckContains(LRustCompareSource, 'std::sync::mpsc 1P+1C',
    'Rust comparison source must mirror the Q5 C1 mpsc scenario name');
  CheckContains(LRustCompareSource, 'Mutex+Condvar VecDeque 2P+2C',
    'Rust comparison source must mirror the Q5 C2 bounded MPMC scenario name');
  CheckContains(LRustCompareSource, 'fn bench_std_mpsc_spsc()',
    'Rust comparison source must define the C1 mpsc bench function');
  CheckContains(LRustCompareSource, 'fn bench_bounded_mutex_condvar_mpmc()',
    'Rust comparison source must define the C2 bounded mpmc bench function');
  CheckContains(LRustCompareSource, 'let mut sink = bench_std_mpsc_spsc();',
    'Rust comparison source must initialize the consumed-value sink from C1');
  CheckContains(LRustCompareSource, 'sink = sink.wrapping_add(bench_bounded_mutex_condvar_mpmc());',
    'Rust comparison source must accumulate the C2 consumed-value sink');
  CheckNotContains(LRustCompareSource, ' ^ bench_bounded_mutex_condvar_mpmc()',
    'Rust comparison source must not XOR-aggregate consumed-value sinks');
  CheckContains(LRustCompareSource, 'for value in 1..=(N as u64) {',
    'Rust comparison source must use 1..N inclusive for C1 input values');
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
  CheckContains(LGoCompareSource, 'Compiler flags: go build',
    'Go comparison source must print the compiler-flags evidence field');
  CheckContains(LGoCompareSource, 'Input size: OPS=1000000; capacity=1024',
    'Go comparison source must print the input-size evidence field');
  CheckContains(LGoCompareSource, 'manual comparison source, not auto-run',
    'Go comparison source must print honesty/envelope baseline guidance');
  CheckContains(LGoCompareSource, 'chan uint64 1P+1C',
    'Go comparison source must mirror the Q5 C1 channel scenario name');
  CheckContains(LGoCompareSource, 'chan uint64 2P+2C',
    'Go comparison source must mirror the Q5 C2 channel scenario name');
  CheckContains(LGoCompareSource, 'func benchChannelSPSC()',
    'Go comparison source must define the C1 bench function');
  CheckContains(LGoCompareSource, 'func benchChannelMPMC()',
    'Go comparison source must define the C2 bench function');
  CheckContains(LGoCompareSource, 'sink = benchChannelSPSC()',
    'Go comparison source must initialize the consumed-value sink from C1');
  CheckContains(LGoCompareSource, 'sink += benchChannelMPMC()',
    'Go comparison source must accumulate the C2 consumed-value sink');
  CheckNotContains(LGoCompareSource, 'sink = benchChannelSPSC() ^',
    'Go comparison source must not XOR-aggregate consumed-value sinks');
  CheckContains(LGoCompareSource, 'for value := uint64(1); value <= Ops; value++ {',
    'Go comparison source must use 1..OPS inclusive for C1 input values');
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
  T := TTestSuite.Create('nextpas.core.lockfree');
  T.Test('SPSC basic', @TestSpscBasic);
  T.Test('SPSC close', @TestSpscClose);
  T.Test('SPSC close wake timeouts', @TestSpscCloseWakeTimeouts);
  T.Test('SPSC close wake waits', @TestSpscCloseWakeWaits);
  T.Test('SPSC approx count', @TestSpscApproxCount);
  T.Test('SPSC blocking', @TestSpscBlocking);
  T.Test('SPSC timeout', @TestSpscTimeout);
  T.Test('SPSC timeout wakes on publish', @TestSpscDequeueTimeoutWakesOnPublish);
  T.Test('SPSC timeout wakes on space', @TestSpscEnqueueTimeoutWakesOnSpace);
  T.Test('MPMC basic', @TestMpmcBasic);
  T.Test('MPMC close', @TestMpmcClose);
  T.Test('MPMC close wake waits', @TestMpmcCloseWakeWaits);
  T.Test('MPMC timeout wakes on publish', @TestMpmcDequeueTimeoutWakesOnPublish);
  T.Test('MPMC timeout wakes on space release', @TestMpmcEnqueueTimeoutWakesOnSpace);
  T.Test('MPMC 4P+4C contention', @TestMpmcContention);
  T.Test('Capacity zero reject', @TestCapacityZero);
  T.Test('Capacity overflow reject', @TestCapacityOverflowReject);
  T.Test('MPMC single-slot', @TestMpmcSingleSlot);
  T.Test('Stack capacity index limit reject', @TestStackCapacityIndexLimitReject);
  T.Test('SPSC batch', @TestSpscBatch);
  T.Test('SPSC batch partial progress', @TestSpscBatchPartialProgress);
  T.Test('MPMC timeout', @TestMpmcTimeout);
  T.Test('Stack basic', @TestStackBasic);
  T.Test('Stack query contract', @TestStackQueryContract);
  T.Test('Stack close', @TestStackClose);
  T.Test('MPSC basic', @TestMpscBasic);
  T.Test('MPSC close producer contract', @TestMpscCloseProducerContract);
  T.Test('MPSC close wake timeout', @TestMpscCloseWakeTimeout);
  T.Test('MPSC close wake wait', @TestMpscCloseWakeWait);
  T.Test('MPSC destroy auto-close and drain', @TestMpscDestroyAutoCloseAndDrain);
  T.Test('T1 Destroy calls Close (source-contract)', @TestT1DestroyCallsCloseSourceContract);
  T.Test('FPC RTL isolation (source-contract)', @TestFpcRtlIsolationSourceContract);
  T.Test('LockFreePrefetch smoke', @TestLockFreePrefetchSmoke);
  T.Test('MPSC multi-producer', @TestMpscMultiProducer);
  T.Test('Deque basic', @TestDequeBasic);
  T.Test('Deque query contract', @TestDequeQueryContract);
  T.Test('Deque close', @TestDequeClose);
  T.Test('SPSC capacity/empty/full', @TestSpscCapacity);
  T.Test('MPMC batch', @TestMpmcBatch);
  T.Test('MPMC batch partial progress', @TestMpmcBatchPartialProgress);
  T.Test('MPMC batch dequeue AMaxCount cap', @TestMpmcBatchDequeueRespectsMaxCount);
  T.Test('MPMC capacity/empty/full', @TestMpmcCapacity);
  T.Test('LockFree wait stale epoch guard', @TestLockFreeWaitHelperStaleEpochGuard);
  T.Test('LockFree wait nil-safe', @TestLockFreeWaitNilSafe);
  T.Test('LockFree wait timeout unregisters waiter', @TestLockFreeWaitTimeoutUnregistersWaiter);
  T.Test('LockFree wait notify unblocks waiters', @TestLockFreeWaitNotifyUnblocksWaiters);
  T.Test('MPSC dequeue wait', @TestMpscDequeueWait);
  T.Test('MPSC timeout wakes on publish', @TestMpscDequeueTimeoutWakesOnPublish);
  T.Test('MPSC dequeue timeout', @TestMpscDequeueTimeout);
  T.Test('Deque capacity', @TestDequeCapacity);
  T.Test('EBR retire and collect', @TestEbrRetireAndCollect);
  T.Test('EBR defers while guard active', @TestEbrDefersWhileGuardActive);
  T.Test('EBR guard leave idempotent', @TestEbrGuardLeaveIdempotent);
  T.Test('EBR nil guard acquire', @TestEbrNilGuardAcquire);
  T.Test('EBR multi-guard retire+collect', @TestEbrMultiGuardRetireCollect);
  T.Test('EBR destroy reclaims retired', @TestEbrDestroyWithRetired);
  T.Test('EBR orphan remains with origin domain', @TestEbrOrphansStayWithOriginDomain);
  T.Test('EBR boundary conditions', @TestEbrBoundaryConditions);
  T.Test('Channel basic', @TestChannelBasic);
  T.Test('Channel close', @TestChannelClose);
  T.Test('Channel close idempotent', @TestChannelCloseIdempotent);
  T.Test('Channel close raises on Send', @TestChannelCloseRaiseOnSend);
  T.Test('Channel Send/Receive', @TestChannelSendReceive);
  T.Test('Channel SendTimeout', @TestChannelSendTimeout);
  T.Test('Channel ReceiveTimeout', @TestChannelReceiveTimeout);
  T.Test('Channel ApproxLen/Capacity', @TestChannelApproxLen);
  T.Test('HashMap basic', @TestHashMapBasic);
  T.Test('HashMap update', @TestHashMapUpdate);
  T.Test('HashMap not found', @TestHashMapNotFound);
  T.Test('HashMap multiple keys', @TestHashMapMultipleKeys);
  T.Test('HashMap zero count', @TestHashMapZeroCount);
  T.Test('HashMap resize', @TestHashMapResize);
  T.Test('HashMap ForEach', @TestHashMapForEach);
  T.Test('HashMap ForEach empty', @TestHashMapForEachEmpty);
  T.Test('HashMap ForEachCtx', @TestHashMapForEachCtx);
  T.Test('HashMap GetOrInsert', @TestHashMapGetOrInsert);
  T.Test('HashMap GetOrInsertFn', @TestHashMapGetOrInsertFn);
  T.Test('HashMap GetOrInsertFn single-key race', @TestHashMapGetOrInsertFnSingleKeyRace);
  T.Test('HashMap GetOrUpdate', @TestHashMapGetOrUpdate);
  T.Test('HashMap TryInsert', @TestHashMapTryInsert);
  T.Test('HashMap Remove with old value', @TestHashMapRemoveWithOldValue);
  T.Test('HashMap Replace', @TestHashMapReplace);
  T.Test('HashMap Clear', @TestHashMapClear);
  T.Test('HashMap Close lifecycle', @TestHashMapCloseLifecycle);
  T.Test('Selector basic recv', @TestSelectorBasic);
  T.Test('Selector send', @TestSelectorSend);
  T.Test('Selector timeout', @TestSelectorTimeout);
  T.Test('Selector multi-channel', @TestSelectorMultiChannel);
  T.Test('Selector clear+reuse', @TestSelectorClearReuse);
  T.Test('Selector send full', @TestSelectorSendFull);
  T.Test('Selector nil channel reject', @TestSelectorNilChannelReject);
  T.Test('Channel capacity enforce', @TestChannelCapacityEnforce);
  T.Test('Stack 4P+4C stress', @TestStackStress);
  T.Test('Deque owner+thief stress', @TestDequeOwnerThief);
  T.Test('SegQueue basic', @TestSegQueueBasic);
  T.Test('SegQueue segment rollover', @TestSegQueueSegmentRollover);
  T.Test('SegQueue empty', @TestSegQueueEmpty);
  T.Test('SegQueue approx count', @TestSegQueueApproxCount);
  T.Test('SegQueue multi-producer', @TestSegQueueMultiProducer);
  T.Test('SegQueue 4P+4C MPMC', @TestSegQueueMpmc);
  T.Test('SegQueue destroy active segments', @TestSegQueueDestroyActiveSegments);
  T.Test('SPMC basic', @TestSpmcBasic);
  T.Test('SPMC capacity', @TestSpmcCapacity);
  T.Test('SPMC full/empty', @TestSpmcFullEmpty);
  T.Test('SPMC wrap-around', @TestSpmcWrapAround);
  T.Test('SPMC enqueue timeout on full', @TestSpmcEnqueueTimeoutOnFull);
  T.Test('SPMC enqueue timeout wakes on space', @TestSpmcEnqueueTimeoutOnSpace);
  T.Test('SPMC dequeue timeout on empty', @TestSpmcDequeueTimeoutOnEmpty);
  T.Test('SPMC approx count', @TestSpmcApproxCount);
  T.Test('SPMC enqueue wait wakes on space', @TestSpmcEnqueueWaitWake);
  T.Test('SPMC dequeue wait wakes on data', @TestSpmcDequeueWaitWake);
  T.Test('SPMC dequeue timeout on data', @TestSpmcDequeueTimeoutOnData);

  T.Test('MPSC TryEnqueue + ApproxCount', @TestMpscTryEnqueue);
  T.Test('MPSC TryDequeue empty', @TestMpscTryDequeueEmpty);
  T.Test('MPSC TryDequeue closed', @TestMpscTryDequeueClosed);
  T.Test('SegQueue TryEnqueue + Close', @TestSegQueueTryEnqueueClose);
  T.Test('SPMC Close', @TestSpmcClose);
  T.Test('SPMC TryEnqueue closed', @TestSpmcTryEnqueueClosed);
  T.Test('SPMC TryDequeue closed', @TestSpmcTryDequeueClosed);
  T.Test('Channel IsEmpty', @TestChannelIsEmpty);
  T.Test('Selector TrySelect', @TestSelectorTrySelect);
  T.Test('Channel 4P+4C stress', @TestChannelStress);
  T.Test('Channel close while Send', @TestChannelCloseWhileSend);

  T.Test('Channel SPSC basic', @TestChannelSpscBasic);
  T.Test('Channel SPSC 1P1C stress', @TestChannelSpscStress);
  T.Test('Channel SPSC timeout', @TestChannelSpscTimeout);
  T.Test('Channel SPSC close', @TestChannelSpscClose);
  T.Test('Channel SPSC capacity', @TestChannelSpscCapacity);
  T.Test('Channel SPSC wrap-around', @TestChannelSpscWrapAround);

  T.Test('SegQueue managed reject', @TestSegQueueManagedReject);
  T.Test('SegQueue TryDequeue empty', @TestSegQueueTryDequeueEmpty);
  T.Test('SegQueue TryDequeue closed', @TestSegQueueTryDequeueClosed);
  T.Test('SegQueue TryEnqueue closed', @TestSegQueueTryEnqueueClosed);
  T.Test('SegQueue Enqueue raises when closed', @TestSegQueueEnqueueRaisesWhenClosed);
  T.Test('SegQueue Try*Ex diagnostics', @TestSegQueueTryExDiagnostics);
  T.Test('Channel Try*Ex diagnostics', @TestChannelTryExDiagnostics);
  T.Test('Channel SPSC Try*Ex diagnostics', @TestChannelSpscTryExDiagnostics);
  T.Test('SPSC Try*Ex diagnostics', @TestSpscTryExDiagnostics);
  T.Test('MPMC Try*Ex diagnostics', @TestMpmcTryExDiagnostics);
  T.Test('SPMC Try*Ex diagnostics', @TestSpmcTryExDiagnostics);
  T.Test('MPSC Try*Ex diagnostics', @TestMpscTryExDiagnostics);
  T.Test('Stack Try*Ex diagnostics', @TestStackTryExDiagnostics);
  T.Test('Deque Try*Ex diagnostics', @TestDequeTryExDiagnostics);
  T.Test('MSQueue Try*Ex diagnostics', @TestMsQueueTryExDiagnostics);
  T.Test('MSQueue Close idempotent', @TestMsQueueCloseIdempotent);
  T.Test('Stack Close idempotent', @TestStackCloseIdempotent);
  T.Test('SegQueue Close idempotent', @TestSegQueueCloseIdempotent);
  T.Test('MSQueue Destroy Close and drain', @TestMsQueueDestroyCloseAndDrain);
  T.Test('Managed type reject', @TestManagedTypeReject);
  T.Test('Source contracts', @TestLockFreeSourceContracts);

  { Edge-case tests }
  T.Test('SPSC capacity=1', @TestSpscCapacityOne);
  T.Test('SPSC capacity=2', @TestSpscCapacityTwo);
  T.Test('SPSC TryEnqueue closed', @TestSpscTryEnqueueClosed);
  T.Test('SPSC TryDequeue closed', @TestSpscTryDequeueClosed);
  T.Test('MPMC capacity=1', @TestMpmcCapacityOne);
  T.Test('MPMC TryEnqueue closed', @TestMpmcTryEnqueueClosed);
  T.Test('MPMC TryDequeue closed', @TestMpmcTryDequeueClosed);
  T.Test('Stack capacity=1', @TestStackCapacityOne);
  T.Test('Deque capacity=1', @TestDequeCapacityOne);
  T.Test('Deque TrySteal empty', @TestDequeTryStealEmpty);
  T.Test('Deque TrySteal closed', @TestDequeTryStealClosed);
  T.Test('Deque TryPop empty', @TestDequeTryPopEmpty);
  T.Test('Deque TryPop closed', @TestDequeTryPopClosed);
  T.Test('Stack TryPop empty', @TestStackTryPopEmpty);
  T.Test('Stack TryPop closed', @TestStackTryPopClosed);
  T.Test('Stack push full', @TestStackPushFull);
  T.Test('HashMap single key stress', @TestHashMapSingleKeyStress);
  T.Test('HashMap many keys stress', @TestHashMapManyKeysStress);
  T.Test('HashMap Find empty', @TestHashMapFindEmpty);
  T.Test('HashMap Remove empty', @TestHashMapRemoveEmpty);
  T.Test('HashMap Contains missing', @TestHashMapContainsMissing);
  T.Test('Channel capacity=1 full/empty', @TestChannelCapacityOneFullEmpty);
  T.Test('Channel capacity=2', @TestChannelCapacityTwo);
  T.Test('Channel SPSC capacity=1', @TestChannelSpscCapacityOne);

  T.Test('Channel resize grow', @TestChannelResizeGrow);
  T.Test('Channel resize shrink', @TestChannelResizeShrink);
  T.Test('Channel resize empty', @TestChannelResizeEmpty);
  T.Test('Channel resize same capacity', @TestChannelResizeSameCapacity);
  T.Test('Channel resize while full', @TestChannelResizeWhileFull);
  T.Test('Channel resize closed', @TestChannelResizeClosed);
  T.Test('Channel resize reject shrink below live count', @TestChannelResizeRejectShrinkBelowLiveCount);
  T.Test('Channel TryReceive empty', @TestChannelTryReceiveEmpty);
  T.Test('Channel TryReceive closed', @TestChannelTryReceiveClosed);
  T.Test('Channel TrySend closed', @TestChannelTrySendClosed);

  T.Test('Selector single channel', @TestSelectorSingleChannel);
  T.Test('Selector TrySelect empty', @TestSelectorTrySelectEmpty);
  T.Test('Selector clear resets', @TestSelectorClearResets);
  T.Test('Selector case order prefer first', @TestSelectorCaseOrderPreferFirst);
  T.Test('Selector TrySelect as default', @TestSelectorTrySelectAsDefault);
  T.Test('Selector recv on closed empty', @TestSelectorRecvOnClosedEmpty);
  T.Test('EBR many guards', @TestEbrManyGuards);

  if not T.Run then Halt(1);
end.
