program test_async_primitives;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.thread,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.async.mutex,
  nextpas.core.async.semaphore,
  nextpas.core.async.channel,
  nextpas.core.async.condvar;

var
  T: TTestSuite;

{ === Shared state === }

var
  GCallCount: Int32 = 0;
  GLoopRef: ^TAsyncLoop;

procedure ResetState;
begin
  GCallCount := 0;
  GLoopRef := nil;
end;

procedure IncrementCallback(AContext: Pointer);
begin
  Inc(GCallCount);
end;

procedure StopCallback(AContext: Pointer);
begin
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

{ === Test 1: MutexBasicLockUnlock === }

procedure TestMutexBasicLockUnlock;
var
  LLoop: TAsyncLoop;
  LMutex: IAsyncMutex;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  LMutex := CreateAsyncMutex(LLoop);
  Check(not LMutex.IsLocked, 'mutex starts unlocked');
  Check(LMutex.TryLock, 'first try lock succeeds');
  Check(LMutex.IsLocked, 'mutex is locked');
  Check(not LMutex.TryLock, 'second try lock fails');
  LMutex.Unlock;
  Check(not LMutex.IsLocked, 'mutex is unlocked after unlock');
  LLoop.Close;
  LLoop.Free;
end;

{ === Test 2: MutexAsyncLock === }

procedure TestMutexAsyncLock;
var
  LLoop: TAsyncLoop;
  LMutex: IAsyncMutex;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  LMutex := CreateAsyncMutex(LLoop);
  { 第一次 Lock 应该立即获取 }
  LMutex.Lock(@IncrementCallback, nil);
  LLoop.Schedule(TDuration.FromMilliseconds(200), @StopCallback, nil);
  LLoop.Run;
  CheckEqual(Int64(1), Int64(GCallCount), 'first lock callback fired');
  Check(LMutex.IsLocked, 'mutex is locked');
  { Unlock 后再 Lock 第二个 }
  LMutex.Unlock;
  GCallCount := 0;
  LMutex.Lock(@IncrementCallback, nil);
  LLoop.Schedule(TDuration.FromMilliseconds(200), @StopCallback, nil);
  LLoop.Run;
  CheckEqual(Int64(1), Int64(GCallCount), 'second lock callback fired');
  Check(LMutex.IsLocked, 'mutex is still locked (held by second)');
  LMutex.Unlock;
  Check(not LMutex.IsLocked, 'mutex is unlocked');
  LLoop.Close;
  LLoop.Free;
end;

{ === Test 3: MutexFIFOOrder === }

var
  GFifoOrder: array[0..2] of Int32;
  GFifoIdx: Int32 = 0;
  GFifoMutex: IAsyncMutex = nil;

procedure FifoWaiterCallback(AContext: Pointer);
begin
  GFifoOrder[GFifoIdx] := Int32(PtrUInt(AContext));
  Inc(GFifoIdx);
  GFifoMutex.Unlock;
end;

procedure TestMutexFIFOOrder;
var
  LLoop: TAsyncLoop;
begin
  ResetState;
  GFifoIdx := 0;
  FillChar(GFifoOrder, SizeOf(GFifoOrder), 0);
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  GFifoMutex := CreateAsyncMutex(LLoop);
  { 获取锁 }
  GFifoMutex.TryLock;
  { 排队 3 个等待者 }
  GFifoMutex.Lock(@FifoWaiterCallback, Pointer(PtrUInt(1)));
  GFifoMutex.Lock(@FifoWaiterCallback, Pointer(PtrUInt(2)));
  GFifoMutex.Lock(@FifoWaiterCallback, Pointer(PtrUInt(3)));
  { 释放锁，触发链式唤醒 }
  GFifoMutex.Unlock;
  { 运行直到所有回调完成 }
  LLoop.Schedule(TDuration.FromMilliseconds(500), @StopCallback, nil);
  LLoop.Run;
  CheckEqual(Int64(1), Int64(GFifoOrder[0]), 'first waiter got lock first');
  CheckEqual(Int64(2), Int64(GFifoOrder[1]), 'second waiter got lock second');
  CheckEqual(Int64(3), Int64(GFifoOrder[2]), 'third waiter got lock third');
  GFifoMutex := nil;
  LLoop.Close;
  LLoop.Free;
end;

{ === Test 4: SemaphoreBasic === }

procedure TestSemaphoreBasic;
var
  LLoop: TAsyncLoop;
  LSem: IAsyncSemaphore;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  LSem := CreateAsyncSemaphore(LLoop, 3);
  CheckEqual(Int64(3), Int64(LSem.Available), 'initial count is 3');
  Check(LSem.TryAcquire, 'first acquire succeeds');
  Check(LSem.TryAcquire, 'second acquire succeeds');
  Check(LSem.TryAcquire, 'third acquire succeeds');
  Check(not LSem.TryAcquire, 'fourth acquire fails');
  CheckEqual(Int64(0), Int64(LSem.Available), 'count is 0');
  LSem.Release;
  CheckEqual(Int64(1), Int64(LSem.Available), 'count is 1 after release');
  LSem.Release;
  LSem.Release;
  CheckEqual(Int64(3), Int64(LSem.Available), 'count is 3 after all releases');
  LLoop.Close;
  LLoop.Free;
end;

{ === Test 5: SemaphoreAsyncAcquire === }

procedure TestSemaphoreAsyncAcquire;
var
  LLoop: TAsyncLoop;
  LSem: IAsyncSemaphore;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  LSem := CreateAsyncSemaphore(LLoop, 1);
  { 立即获取 }
  LSem.Acquire(@IncrementCallback, nil);
  LLoop.Schedule(TDuration.FromMilliseconds(200), @StopCallback, nil);
  LLoop.Run;
  CheckEqual(Int64(1), Int64(GCallCount), 'first acquire callback fired');
  { 释放后再次获取 }
  LSem.Release;
  GCallCount := 0;
  LSem.Acquire(@IncrementCallback, nil);
  LLoop.Schedule(TDuration.FromMilliseconds(200), @StopCallback, nil);
  LLoop.Run;
  CheckEqual(Int64(1), Int64(GCallCount), 'second acquire callback fired');
  LSem.Release;
  LLoop.Close;
  LLoop.Free;
end;

{ === Test 6: ChannelBasic === }

procedure TestChannelBasic;
var
  LLoop: TAsyncLoop;
  LCh: IAsyncChannel;
  LBuf: array[0..3] of Byte;
  LReceived: UInt32;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  LCh := CreateAsyncChannel(LLoop);
  Check(not LCh.IsClosed, 'channel is open');
  CheckEqual(Int64(0), Int64(LCh.BufferedSize), 'channel is empty');
  { 发送数据 }
  LBuf[0] := $CA; LBuf[1] := $FE;
  LBuf[2] := $BA; LBuf[3] := $BE;
  Check(LCh.Send(LBuf[0], 4), 'send succeeds');
  CheckEqual(Int64(4), Int64(LCh.BufferedSize), 'channel has 4 bytes');
  { 接收数据 }
  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(LCh.TryReceive(LBuf[0], 4, LReceived), 'try receive succeeds');
  CheckEqual(Int64(4), Int64(LReceived), 'received 4 bytes');
  CheckEqual(Int64($CA), Int64(LBuf[0]), 'byte 0 correct');
  CheckEqual(Int64($FE), Int64(LBuf[1]), 'byte 1 correct');
  CheckEqual(Int64(0), Int64(LCh.BufferedSize), 'channel is empty again');
  { 空通道接收 }
  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(not LCh.TryReceive(LBuf[0], 4, LReceived), 'empty channel receive fails');
  LLoop.Close;
  LLoop.Free;
end;

{ === Test 7: ChannelClose === }

procedure TestChannelClose;
var
  LLoop: TAsyncLoop;
  LCh: IAsyncChannel;
  LBuf: array[0..3] of Byte;
  LReceived: UInt32;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  LCh := CreateAsyncChannel(LLoop);
  { 发送然后关闭 }
  LBuf[0] := $DE; LBuf[1] := $AD;
  LBuf[2] := $BE; LBuf[3] := $EF;
  LCh.Send(LBuf[0], 4);
  LCh.Close;
  Check(LCh.IsClosed, 'channel is closed');
  { 已有数据仍可接收 }
  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(LCh.TryReceive(LBuf[0], 4, LReceived), 'can receive after close');
  CheckEqual(Int64($DE), Int64(LBuf[0]), 'byte 0 correct');
  { 关闭后不能发送 }
  LBuf[0] := $FF;
  Check(not LCh.Send(LBuf[0], 1), 'cannot send after close');
  LLoop.Close;
  LLoop.Free;
end;

{ === Test 8: ChannelMultipleChunks === }

procedure TestChannelMultipleChunks;
var
  LLoop: TAsyncLoop;
  LCh: IAsyncChannel;
  LI: Int32;
  LVal, LReceived: UInt32;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  LCh := CreateAsyncChannel(LLoop);
  { 发送多个块 }
  for LI := 1 to 10 do
  begin
    LVal := LI;
    Check(LCh.Send(LVal, SizeOf(LVal)), 'send chunk ' + IntToStr(LI));
  end;
  CheckEqual(Int64(10 * SizeOf(UInt32)), Int64(LCh.BufferedSize), '10 chunks buffered');
  { 接收并验证顺序 }
  for LI := 1 to 10 do
  begin
    LVal := 0;
    Check(LCh.TryReceive(LVal, SizeOf(LVal), LReceived), 'receive chunk ' + IntToStr(LI));
    CheckEqual(Int64(LI), Int64(LVal), 'chunk ' + IntToStr(LI) + ' value correct');
  end;
  LLoop.Close;
  LLoop.Free;
end;

{ === Test 9: BoundedChannel === }

procedure TestBoundedChannel;
var
  LLoop: TAsyncLoop;
  LCh: IAsyncChannel;
  LVal, LOut: UInt32;
  LReceived: UInt32;
begin
  ResetState;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  { 容量 12 字节 = 3 个 UInt32 }
  LCh := CreateBoundedAsyncChannel(LLoop, 12);
  { 填满容量 }
  LVal := 1; Check(LCh.Send(LVal, SizeOf(LVal)), 'send 1');
  LVal := 2; Check(LCh.Send(LVal, SizeOf(LVal)), 'send 2');
  LVal := 3; Check(LCh.Send(LVal, SizeOf(LVal)), 'send 3');
  { 超出容量应失败 }
  LVal := 4; Check(not LCh.Send(LVal, SizeOf(LVal)), 'send 4 fails (bounded)');
  { 释放一个后再发送 }
  LOut := 0;
  LCh.TryReceive(LOut, SizeOf(LOut), LReceived);
  CheckEqual(Int64(1), Int64(LOut), 'received value 1');
  LVal := 4; Check(LCh.Send(LVal, SizeOf(LVal)), 'send 4 succeeds after receive');
  LCh := nil;
  GLoopRef := nil;
  LLoop.Free;
end;

{ === Test 9b: BoundedSendAsyncWaits === }

var
  GSendAsyncDone: Boolean = False;

procedure SendAsyncDoneCallback(AContext: Pointer);
begin
  GSendAsyncDone := True;
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

procedure TestBoundedSendAsyncWaits;
var
  LLoop: TAsyncLoop;
  LCh: IAsyncChannel;
  LVal, LOut: UInt32;
  LReceived: UInt32;
begin
  ResetState;
  GSendAsyncDone := False;
  LLoop := TAsyncLoop.Create(32);
  try
    GLoopRef := @LLoop;
    { capacity 4 bytes = 1 UInt32 }
    LCh := CreateBoundedAsyncChannel(LLoop, 4);
    LVal := 1;
    Check(LCh.Send(LVal, SizeOf(LVal)), 'fill channel');
    Check(not LCh.TrySend(LVal, SizeOf(LVal)), 'TrySend fails when full');
    LVal := 2;
    LCh.SendAsync(LVal, SizeOf(LVal), @SendAsyncDoneCallback, nil);
    Check(not GSendAsyncDone, 'SendAsync not done while full');
    LOut := 0;
    Check(LCh.TryReceive(LOut, SizeOf(LOut), LReceived), 'receive frees space');
    CheckEqual(Int64(1), Int64(LOut), 'got first value');
    LLoop.Schedule(TDuration.FromMilliseconds(50), @StopCallback, nil);
    LLoop.Run;
    Check(GSendAsyncDone, 'SendAsync completed after space');
    Check(LCh.TryReceive(LOut, SizeOf(LOut), LReceived), 'receive async value');
    CheckEqual(Int64(2), Int64(LOut), 'got async value');
    LCh := nil;
  finally
    GLoopRef := nil;
    LLoop.Free;
  end;
end;

{ === Test 9c: SendAsyncOnClose === }

procedure TestSendAsyncOnClose;
var
  LLoop: TAsyncLoop;
  LCh: IAsyncChannel;
  LVal: UInt32;
begin
  ResetState;
  GSendAsyncDone := False;
  LLoop := TAsyncLoop.Create(32);
  try
    GLoopRef := @LLoop;
    LCh := CreateBoundedAsyncChannel(LLoop, 4);
    LVal := 1;
    Check(LCh.Send(LVal, SizeOf(LVal)), 'fill');
    LVal := 2;
    LCh.SendAsync(LVal, SizeOf(LVal), @SendAsyncDoneCallback, nil);
    LCh.Close;
    Check(LCh.IsClosed, 'closed');
    LLoop.Schedule(TDuration.FromMilliseconds(50), @StopCallback, nil);
    LLoop.Run;
    Check(GSendAsyncDone, 'close wakes send waiter');
    LCh := nil;
  finally
    GLoopRef := nil;
    LLoop.Free;
  end;
end;

{ === Test 9d: ReceiveThenTryReceive === }

var
  GRecvNotify: Boolean = False;

procedure RecvNotifyCallback(AContext: Pointer);
begin
  GRecvNotify := True;
  if GLoopRef <> nil then
    GLoopRef^.Stop;
end;

procedure TestReceiveThenTryReceive;
var
  LLoop: TAsyncLoop;
  LCh: IAsyncChannel;
  LVal, LOut: UInt32;
  LReceived: UInt32;
begin
  ResetState;
  GRecvNotify := False;
  LLoop := TAsyncLoop.Create(32);
  try
    GLoopRef := @LLoop;
    LCh := CreateAsyncChannel(LLoop);
    LCh.Receive(@RecvNotifyCallback, nil);
    LVal := 42;
    Check(LCh.Send(LVal, SizeOf(LVal)), 'send after receive wait');
    LLoop.Schedule(TDuration.FromMilliseconds(50), @StopCallback, nil);
    LLoop.Run;
    Check(GRecvNotify, 'receive notify fired');
    Check(LCh.TryReceive(LOut, SizeOf(LOut), LReceived), 'try receive data');
    CheckEqual(Int64(42), Int64(LOut), 'value 42');
    LCh := nil;
  finally
    GLoopRef := nil;
    LLoop.Free;
  end;
end;

{ === Test 10: CondVarSignal === }

var
  GCondVarSignalCount: Int32 = 0;
  GCondVarMutex: IAsyncMutex = nil;
  GCondVar: IAsyncCondVar = nil;

procedure CondVarWaiterCallback(AContext: Pointer);
begin
  Inc(GCondVarSignalCount);
  { 重新获取锁后释放 }
  GCondVarMutex.Unlock;
end;

procedure TestCondVarSignal;
var
  LLoop: TAsyncLoop;
begin
  ResetState;
  GCondVarSignalCount := 0;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  GCondVarMutex := CreateAsyncMutex(LLoop);
  GCondVar := CreateAsyncCondVar(LLoop);
  { 获取锁 }
  GCondVarMutex.TryLock;
  { 等待条件（释放锁并加入等待队列） }
  GCondVar.Wait(GCondVarMutex, @CondVarWaiterCallback, nil);
  { Signal 唤醒一个等待者 }
  GCondVar.Signal;
  LLoop.Schedule(TDuration.FromMilliseconds(200), @StopCallback, nil);
  LLoop.Run;
  CheckEqual(Int64(1), Int64(GCondVarSignalCount), 'signal woke one waiter');
  GCondVarMutex := nil;
  GCondVar := nil;
  LLoop.Close;
  LLoop.Free;
end;

{ === Test 11: CondVarBroadcast === }

var
  GBroadcastCount: Int32 = 0;

procedure BroadcastWaiterCallback(AContext: Pointer);
begin
  Inc(GBroadcastCount);
  GCondVarMutex.Unlock;
end;

procedure TestCondVarBroadcast;
var
  LLoop: TAsyncLoop;
  LI: Int32;
begin
  ResetState;
  GBroadcastCount := 0;
  LLoop := TAsyncLoop.Create(32);
  GLoopRef := @LLoop;
  GCondVarMutex := CreateAsyncMutex(LLoop);
  GCondVar := CreateAsyncCondVar(LLoop);
  { 获取锁 }
  GCondVarMutex.TryLock;
  { 排队 5 个等待者 }
  for LI := 1 to 5 do
    GCondVar.Wait(GCondVarMutex, @BroadcastWaiterCallback, nil);
  { Broadcast 唤醒所有 }
  GCondVar.Broadcast;
  LLoop.Schedule(TDuration.FromMilliseconds(500), @StopCallback, nil);
  LLoop.Run;
  CheckEqual(Int64(5), Int64(GBroadcastCount), 'broadcast woke all waiters');
  GCondVarMutex := nil;
  GCondVar := nil;
  LLoop.Close;
  LLoop.Free;
end;

{ === Main === }

begin
  T := TTestSuite.Create('nextpas.core.async.primitives');

  T.Test('MutexBasicLockUnlock', @TestMutexBasicLockUnlock);
  T.Test('MutexAsyncLock', @TestMutexAsyncLock);
  T.Test('MutexFIFOOrder', @TestMutexFIFOOrder);
  T.Test('SemaphoreBasic', @TestSemaphoreBasic);
  T.Test('SemaphoreAsyncAcquire', @TestSemaphoreAsyncAcquire);
  T.Test('ChannelBasic', @TestChannelBasic);
  T.Test('ChannelClose', @TestChannelClose);
  T.Test('ChannelMultipleChunks', @TestChannelMultipleChunks);
  T.Test('BoundedChannel', @TestBoundedChannel);
  T.Test('BoundedSendAsyncWaits', @TestBoundedSendAsyncWaits);
  T.Test('SendAsyncOnClose', @TestSendAsyncOnClose);
  T.Test('ReceiveThenTryReceive', @TestReceiveThenTryReceive);
  T.Test('CondVarSignal', @TestCondVarSignal);
  T.Test('CondVarBroadcast', @TestCondVarBroadcast);

  if not T.Run then Halt(1);
end.
