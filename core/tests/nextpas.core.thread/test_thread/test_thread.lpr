program test_thread;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init, {$IFDEF UNIX}BaseUnix, Syscall,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.thread,
  nextpas.core.thread.base,
  nextpas.core.thread.intf,
  nextpas.core.thread.channel,
  nextpas.core.thread.future,
  nextpas.core.thread.cancel,
  nextpas.core.platform.thread;

type
  TIntChannel = specialize TChannel<Integer>;
  IIntChannel = specialize IChannel<Integer>;
  TIntFuture = specialize TFuturePromise<Integer>;
  IIntFuture = specialize IFuture<Integer>;
  IIntPromise = specialize IPromise<Integer>;

var
  T: TTestSuite;

var
  GCounter: Int32 = 0;

procedure TestPoolSubmitAll;
var
  LPool: IThreadPool;
  LI: Integer;
begin
  GCounter := 0;
  LPool := ThreadPool(4);

  for LI := 1 to 10 do
    LPool.Submit(procedure
    begin
      InterlockedIncrement(GCounter);
    end);

  LPool.WaitAll;
  CheckEqual(Int64(10), Int64(InterlockedCompareExchange(GCounter, 0, 0)));
  LPool.Shutdown;
  LPool := nil;
end;

procedure TestPoolShutdownRejectsNew;
var
  LPool: IThreadPool;
begin
  GCounter := 0;
  LPool := ThreadPool(2);
  platform_thread_sleep_ns(1000000);
  LPool.Shutdown;

  LPool.Submit(procedure
  begin
    InterlockedIncrement(GCounter);
  end);

  platform_thread_sleep_ns(5000000);
  CheckEqual(Int64(0), Int64(InterlockedCompareExchange(GCounter, 0, 0)));
end;

procedure TestPoolWorkerCount;
var
  LPool: IThreadPool;
begin
  LPool := ThreadPool(3);
  CheckEqual(Int64(3), Int64(LPool.WorkerCount));
  LPool.Shutdown;
end;

procedure TestPoolH4SegQueueSourceContract;
var
  LSource: string;
begin
  LSource := '';
  with TStringList.Create do
  try
    LoadFromFile('../../../src/nextpas.core.thread.pool.pas');
    LSource := Text;
  finally
    Free;
  end;
  Check(Pos('nextpas.core.lockfree.segqueue', LowerCase(LSource)) > 0,
    'H4-1 pool must use lockfree.segqueue');
  Check(Pos('TSegQueueImpl', LSource) > 0,
    'H4-1 pool must specialize TSegQueueImpl for multi-worker queue');
  Check(Pos('FQueue.Close', LSource) > 0,
    'H4-1 Shutdown must Close the task queue');
end;

procedure TestChannelSingleProducerConsumer;
var
  LCh: IIntChannel;
  LVal: Integer;
begin
  LCh := TIntChannel.Create(8);

  LCh.Send(42);
  LCh.Send(99);

  Check(LCh.Receive(LVal), 'receive 1');
  CheckEqual(Int64(42), Int64(LVal));
  Check(LCh.Receive(LVal), 'receive 2');
  CheckEqual(Int64(99), Int64(LVal));
end;

var
  GChannelForThread: IIntChannel = nil;

function ChannelProducer(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
begin
  Result := nil;
  for LI := 1 to 5 do
    GChannelForThread.Send(LI);
  GChannelForThread.Close;
end;

procedure TestChannelWithThread;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LVal: Integer;
  LSum: Integer;
begin
  GChannelForThread := TIntChannel.Create(16);
  LSum := 0;

  platform_thread_create(LHandle, @ChannelProducer, nil);

  while GChannelForThread.Receive(LVal) do
    Inc(LSum, LVal);

  platform_thread_join(LHandle, LRetVal);
  CheckEqual(Int64(15), Int64(LSum));
  GChannelForThread := nil;
end;

procedure TestChannelCloseReceiveFalse;
var
  LCh: IIntChannel;
  LVal: Integer;
begin
  LCh := TIntChannel.Create(4);
  LCh.Send(1);
  LCh.Close;

  Check(LCh.Receive(LVal), 'should get buffered value');
  CheckEqual(Int64(1), Int64(LVal));

  Check(not LCh.Receive(LVal), 'should return false after close + empty');
end;

{ 多生产者 + 单消费者压力：4 线程 × 25000 条(小容量 64 迫使 senders 阻塞等
  空位——验证「等待计数驱动 signal」下多 sender 唤醒正确性),全部 join 后
  Close → 消费者 drain 退出;总和守恒证明无丢唤醒/死锁/丢数据。
  (2026-08-17 回归:曾 40% 概率三方互等挂死,见 channel.pas 教训注释。) }
const
  cMPProducers = 4;
  cMPPerProducer = 25000;
  cMPChannelCapacity = 64;

var
  GMPChannel: IIntChannel = nil;
  GMPConsumerSum: Int64 = 0;

function MPProducer(AArg: Pointer): Pointer; cdecl;
var
  I: Integer;
  LBias: Int64;
begin
  Result := nil;
  LBias := Int64(PtrUInt(AArg)) * 1000000;   { 线程 id → 值域隔离 }
  for I := 1 to cMPPerProducer do
    GMPChannel.Send(LBias + I);              { 阻塞 Send: 满时等待空位 }
end;

function MPConsumer(AArg: Pointer): Pointer; cdecl;
var
  LVal: Integer;
begin
  Result := nil;
  while GMPChannel.Receive(LVal) do
    Inc(GMPConsumerSum, LVal);
end;

procedure TestChannelMultiProducerSum;
var
  LProdHandles: array[0..cMPProducers - 1] of TPlatformThreadHandle;
  LConsHandle: TPlatformThreadHandle;
  LRet: Pointer;
  I: Integer;
  LExpect: Int64;
begin
  GMPChannel := TIntChannel.Create(cMPChannelCapacity);
  GMPConsumerSum := 0;
  LExpect := 0;
  for I := 0 to cMPProducers - 1 do
    LExpect := LExpect +
      Int64(1000000 * I) * cMPPerProducer +
      Int64(cMPPerProducer) * (cMPPerProducer + 1) div 2;

  platform_thread_create(LConsHandle, @MPConsumer, nil);
  for I := 0 to cMPProducers - 1 do
    platform_thread_create(LProdHandles[I], @MPProducer, Pointer(PtrUInt(I)));
  for I := 0 to cMPProducers - 1 do
    platform_thread_join(LProdHandles[I], LRet);
  GMPChannel.Close;                          { 生产完毕: drain 后消费者退出 }
  platform_thread_join(LConsHandle, LRet);
  CheckEqual(LExpect, GMPConsumerSum, 'multi-producer sum conserved');
  GMPChannel := nil;
end;

{ Channel TrySend/TryReceive }

procedure TestChannelTrySendReceive;
var
  LCh: IIntChannel;
  LVal: Integer;
begin
  LCh := TIntChannel.Create(2);
  Check(LCh.TrySend(10), 'trysend 1');
  Check(LCh.TrySend(20), 'trysend 2');
  Check(not LCh.TrySend(30), 'trysend full');
  Check(LCh.TryReceive(LVal), 'tryrecv 1');
  CheckEqual(Int64(10), Int64(LVal));
  Check(LCh.TryReceive(LVal), 'tryrecv 2');
  CheckEqual(Int64(20), Int64(LVal));
  Check(not LCh.TryReceive(LVal), 'tryrecv empty');
  LCh.Close;
end;

{ Future/Promise }

procedure TestFutureComplete;
var
  LFP: TIntFuture;
  LF: IIntFuture;
  LP: IIntPromise;
begin
  LFP := TIntFuture.Create;
  LF := LFP;
  LP := LFP;
  Check(not LF.IsDone, 'pending');
  Check(LF.State = fsPending, 'state pending');
  LP.Complete(42);
  Check(LF.IsDone, 'done');
  Check(LF.State = fsCompleted, 'state completed');
  CheckEqual(Int64(42), Int64(LF.Wait), 'wait returns value');
  CheckEqual(Int64(42), Int64(LF.Get), 'get returns value');
end;

procedure TestFutureFail;
var
  LFP: TIntFuture;
  LF: IIntFuture;
  LP: IIntPromise;
  LGot: Boolean;
begin
  LFP := TIntFuture.Create;
  LF := LFP;
  LP := LFP;
  LP.Fail(EIOError.Create('test error'));
  Check(LF.State = fsFailed, 'state failed');
  LGot := False;
  try
    LF.Wait;
  except
    on E: EIOError do
      LGot := True;
  end;
  Check(LGot, 'wait re-raises');
end;

procedure TestFutureCancel;
var
  LFP: TIntFuture;
  LF: IIntFuture;
  LP: IIntPromise;
  LGot: Boolean;
begin
  LFP := TIntFuture.Create;
  LF := LFP;
  LP := LFP;
  LP.Cancel;
  Check(LF.State = fsCancelled, 'state cancelled');
  LGot := False;
  try
    LF.Wait;
  except
    on E: ECancelledError do
      LGot := True;
  end;
  Check(LGot, 'wait throws cancelled');
end;

procedure TestFutureWaitTimeout;
var
  LFP: TIntFuture;
  LF: IIntFuture;
  LP: IIntPromise;
begin
  LFP := TIntFuture.Create;
  LF := LFP;
  LP := LFP;
  Check(not LF.WaitTimeout(1000000), 'timeout 1ms');
  LP.Complete(7);
  Check(LF.WaitTimeout(1000000), 'immediate after complete');
end;

{ CancellationToken }

procedure TestCancellationBasic;
var
  LCS: ICancellationSource;
  LTok: ICancellationToken;
begin
  LCS := CreateCancellationSource;
  LTok := LCS.Token;
  Check(not LTok.IsCancelled, 'not cancelled');
  LCS.Cancel;
  Check(LTok.IsCancelled, 'cancelled');
end;

procedure TestCancellationThrow;
var
  LCS: ICancellationSource;
  LGot: Boolean;
begin
  LCS := CreateCancellationSource;
  LCS.Cancel;
  LGot := False;
  try
    LCS.Token.ThrowIfCancelled;
  except
    on E: ECancelledError do
      LGot := True;
  end;
  Check(LGot, 'ThrowIfCancelled raises');
end;

procedure TestCancellationWait;
var
  LCS: ICancellationSource;
begin
  LCS := CreateCancellationSource;
  Check(not LCS.Token.WaitCancellation(1000000), 'timeout');
  LCS.Cancel;
  Check(LCS.Token.WaitCancellation(1000000), 'immediate after cancel');
end;

{ Channel timeout tests }

procedure TestChannelSendTimeout;
var
  LCh: IIntChannel;
begin
  LCh := TIntChannel.Create(1);
  LCh.Send(1);
  Check(not LCh.SendTimeout(2, 1000000), 'timeout on full (1ms)');
  LCh.Close;
end;

procedure TestChannelReceiveTimeout;
var
  LCh: IIntChannel;
  LVal: Integer;
begin
  LCh := TIntChannel.Create(1);
  Check(not LCh.ReceiveTimeout(LVal, 1000000), 'timeout on empty (1ms)');
  LCh.Send(42);
  Check(LCh.ReceiveTimeout(LVal, 1000000), 'immediate when available');
  CheckEqual(Int64(42), Int64(LVal));
  LCh.Close;
end;

{ FutureVoid + WhenAll tests }

procedure TestFutureVoid;
var
  LF: IFutureVoid;
begin
  LF := CreateFutureVoid;
  Check(not LF.IsDone, 'not done');
  FutureVoidComplete(LF);
  Check(LF.IsDone, 'done');
  LF.Wait;
end;

procedure TestWhenAll;
var
  LF1, LF2, LAll: IFutureVoid;
begin
  LF1 := CreateFutureVoid;
  LF2 := CreateFutureVoid;
  FutureVoidComplete(LF1);
  FutureVoidComplete(LF2);
  LAll := WhenAll([LF1, LF2]);
  Check(LAll.IsDone, 'all done');
end;

{$IFDEF UNIX}
procedure SigAbrtHandler(ASig: cint); cdecl;
begin
  { Watchdog path only: a hang that got SIGABRT'd is a failure regardless
    of any earlier suite result (PH33 P5f). }
  do_syscall(syscall_nr_exit_group, 1);
end;
{$ENDIF}

begin
  {$IFDEF UNIX}
  FpSignal(SIGABRT, @SigAbrtHandler);
  {$ENDIF}
  T := TTestSuite.Create('nextpas.core.thread');
  T.Test('Pool submit 10 tasks', @TestPoolSubmitAll);
  T.Test('Pool shutdown rejects new', @TestPoolShutdownRejectsNew);
  T.Test('Pool worker count', @TestPoolWorkerCount);
  T.Test('Pool H4 SegQueue source-contract', @TestPoolH4SegQueueSourceContract);
  T.Test('Channel single producer/consumer', @TestChannelSingleProducerConsumer);
  T.Test('Channel with thread', @TestChannelWithThread);
  T.Test('Channel multi-producer sum', @TestChannelMultiProducerSum);
  T.Test('Channel close then receive', @TestChannelCloseReceiveFalse);
  T.Test('Channel TrySend/TryReceive', @TestChannelTrySendReceive);
  T.Test('Future complete', @TestFutureComplete);
  T.Test('Future fail', @TestFutureFail);
  T.Test('Future cancel', @TestFutureCancel);
  T.Test('Future wait timeout', @TestFutureWaitTimeout);
  T.Test('Cancellation basic', @TestCancellationBasic);
  T.Test('Cancellation throw', @TestCancellationThrow);
  T.Test('Cancellation wait', @TestCancellationWait);
  T.Test('Channel send timeout', @TestChannelSendTimeout);
  T.Test('Channel receive timeout', @TestChannelReceiveTimeout);
  T.Test('FutureVoid basic', @TestFutureVoid);
  T.Test('WhenAll', @TestWhenAll);
  { Single Run, then leave via normal RTL shutdown — the raw
    exit_group call here used to bypass heaptrc's exit dump and made the
    leak gate fail-closed on this suite; it also ran the suite twice
    (PH33 P5f). }
  if not T.Run then Halt(1);
end.
