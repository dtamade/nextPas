program test_thread;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.testing,
  nextpas.core.thread,
  nextpas.core.thread.base,
  nextpas.core.thread.intf,
  nextpas.core.thread.channel,
  nextpas.core.platform.thread;

type
  TIntChannel = specialize TChannel<Integer>;
  IIntChannel = specialize IChannel<Integer>;

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

begin
  T := TTestRunner.Create('nextpas.core.thread');
  T.Run('Pool submit 10 tasks', @TestPoolSubmitAll);
  T.Run('Pool shutdown rejects new', @TestPoolShutdownRejectsNew);
  T.Run('Pool worker count', @TestPoolWorkerCount);
  T.Run('Channel single producer/consumer', @TestChannelSingleProducerConsumer);
  T.Run('Channel with thread', @TestChannelWithThread);
  T.Run('Channel close then receive', @TestChannelCloseReceiveFalse);
  T.Summary;
end.
