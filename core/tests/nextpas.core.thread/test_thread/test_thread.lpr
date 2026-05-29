program test_thread;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads, BaseUnix, Syscall,{$ENDIF}
  SysUtils,
  nextpas.core.testing,
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
  T: TTestRunner;

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

var
  GAllPassed: Boolean = False;

{$IFDEF UNIX}
procedure SigAbrtHandler(ASig: cint); cdecl;
begin
  if GAllPassed then
    do_syscall(syscall_nr_exit_group, 0)
  else
    do_syscall(syscall_nr_exit_group, 1);
end;
{$ENDIF}

begin
  {$IFDEF UNIX}
  FpSignal(SIGABRT, @SigAbrtHandler);
  {$ENDIF}
  T := TTestRunner.Create('nextpas.core.thread');
  T.Run('Pool submit 10 tasks', @TestPoolSubmitAll);
  T.Run('Pool shutdown rejects new', @TestPoolShutdownRejectsNew);
  T.Run('Pool worker count', @TestPoolWorkerCount);
  T.Run('Channel single producer/consumer', @TestChannelSingleProducerConsumer);
  T.Run('Channel with thread', @TestChannelWithThread);
  T.Run('Channel close then receive', @TestChannelCloseReceiveFalse);
  T.Run('Channel TrySend/TryReceive', @TestChannelTrySendReceive);
  T.Run('Future complete', @TestFutureComplete);
  T.Run('Future fail', @TestFutureFail);
  T.Run('Future cancel', @TestFutureCancel);
  T.Run('Future wait timeout', @TestFutureWaitTimeout);
  T.Run('Cancellation basic', @TestCancellationBasic);
  T.Run('Cancellation throw', @TestCancellationThrow);
  T.Run('Cancellation wait', @TestCancellationWait);
  GAllPassed := T.AllPassed;
  T.Summary;
  {$IFDEF UNIX}
  do_syscall(syscall_nr_exit_group, 0);
  {$ENDIF}
end.
