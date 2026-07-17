program test_lockfree_actor;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.lockfree.actor,
  nextpas.core.atomic,
  nextpas.core.platform.thread;

var
  GPassed, GFailed: Int32;
  GActiveHandlers: Int32;
  GConcurrentHandlerSeen: Int32;
  GHandledMessages: Int32;
  GBlockingHandlerEntered: Int32;
  GReleaseBlockingHandler: Int32;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

type
  PActorSendArgs = ^TActorSendArgs;
  TActorSendArgs = record
    Actor: TActor;
    Start: PInt32;
    Message: TActorMessage;
    Result: TActorResult;
  end;

  PActorStopArgs = ^TActorStopArgs;
  TActorStopArgs = record
    Actor: TActor;
    Started: PInt32;
    Returned: PInt32;
  end;

procedure SerialActorHandler(const AMsg: TActorMessage);
var
  LActive: Int32;
begin
  LActive := AtomicFetchAdd32(GActiveHandlers, 1, moAcqRel) + 1;
  if LActive > 1 then
    AtomicStore32(GConcurrentHandlerSeen, 1, moRelease);
  platform_thread_sleep_ns(20000000);
  AtomicFetchAdd32(GHandledMessages, 1, moRelaxed);
  AtomicFetchSub32(GActiveHandlers, 1, moRelease);
end;

function ActorSendThread(AData: Pointer): PtrInt;
var
  LArgs: PActorSendArgs;
begin
  LArgs := PActorSendArgs(AData);
  while AtomicLoad32(LArgs^.Start^, moAcquire) = 0 do
    CpuPause;
  LArgs^.Result := LArgs^.Actor.Send(LArgs^.Message);
  Result := 0;
end;

procedure BlockingActorHandler(const AMsg: TActorMessage);
begin
  AtomicStore32(GBlockingHandlerEntered, 1, moRelease);
  while AtomicLoad32(GReleaseBlockingHandler, moAcquire) = 0 do
    CpuPause;
end;

function ActorStopThread(AData: Pointer): PtrInt;
var
  LArgs: PActorStopArgs;
begin
  LArgs := PActorStopArgs(AData);
  AtomicStore32(LArgs^.Started^, 1, moRelease);
  LArgs^.Actor.Stop;
  AtomicStore32(LArgs^.Returned^, 1, moRelease);
  Result := 0;
end;

procedure TestActorCreate;
var
  LActor: TActor;
  LHandled: Boolean;
begin
  WriteLn('--- TestActorCreate ---');
  LHandled := False;
  LActor := TActor.Create(1, procedure(const AMsg: TActorMessage)
  begin
    LHandled := True;
  end);
  try
    Check(LActor.GetId = 1, 'Actor id = 1');
    Check(LActor.GetState = asRunning, 'State running');
    Check(LActor.MailCount = 0, 'Mail empty');
    LActor.Stop;
    Check(LActor.GetState = asStopped, 'State stopped');
  finally
    LActor.Free;
  end;
end;

procedure TestActorSend;
var
  LActor: TActor;
  LCount: Int32;
  LMsg: TActorMessage;
begin
  WriteLn('--- TestActorSend ---');
  LCount := 0;
  LActor := TActor.Create(1, procedure(const AMsg: TActorMessage)
  begin
    Inc(LCount);
  end);
  try
    LMsg.SenderId := 0;
    LMsg.Data := 'test';
    Check(LActor.Send(LMsg) = arOk, 'Send ok');
    Check(LCount = 1, 'Message handled');
    Check(LActor.MailCount = 0, 'Mail empty after process');
  finally
    LActor.Free;
  end;
end;

procedure TestActorStopRejects;
var
  LActor: TActor;
  LMsg: TActorMessage;
begin
  WriteLn('--- TestActorStopRejects ---');
  LActor := TActor.Create(1, procedure(const AMsg: TActorMessage) begin end);
  try
    LActor.Stop;
    LMsg.SenderId := 0;
    LMsg.Data := 'test';
    Check(LActor.Send(LMsg) = arStopped, 'Send after stop rejected');
  finally
    LActor.Free;
  end;
end;

procedure TestActorSystem;
var
  LSys: TActorSystem;
  L1, L2: TActor;
  LCount1, LCount2: Int32;
begin
  WriteLn('--- TestActorSystem ---');
  LCount1 := 0;
  LCount2 := 0;
  LSys := TActorSystem.Create;
  try
    L1 := LSys.Spawn(procedure(const AMsg: TActorMessage)
    begin
      Inc(LCount1);
    end);
    L2 := LSys.Spawn(procedure(const AMsg: TActorMessage)
    begin
      Inc(LCount2);
    end);
    Check(LSys.Count = 2, 'System has 2 actors');
    Check(LSys.Send(0, L1.GetId, 'hello') = arOk, 'Send to actor1');
    Check(LCount1 = 1, 'Actor1 handled');
    Check(LSys.Send(0, L2.GetId, 'world') = arOk, 'Send to actor2');
    Check(LCount2 = 1, 'Actor2 handled');
    Check(LSys.Find(L1.GetId) = L1, 'Find actor1');
    Check(LSys.Find(999) = nil, 'Find nonexistent');
    LSys.StopAll;
  finally
    LSys.Free;
  end;
end;

procedure TestActorHandlersAreSerialized;
var
  LActor: TActor;
  LArgs1, LArgs2: TActorSendArgs;
  LThread1, LThread2: TThreadID;
  LStart: Int32;
begin
  GActiveHandlers := 0;
  GConcurrentHandlerSeen := 0;
  GHandledMessages := 0;
  LStart := 0;
  LActor := TActor.Create(1, @SerialActorHandler);
  try
    LArgs1.Actor := LActor;
    LArgs1.Start := @LStart;
    LArgs1.Message.SenderId := 1;
    LArgs1.Message.Data := 'one';
    LArgs1.Result := arStopped;
    LArgs2.Actor := LActor;
    LArgs2.Start := @LStart;
    LArgs2.Message.SenderId := 2;
    LArgs2.Message.Data := 'two';
    LArgs2.Result := arStopped;

    LThread1 := BeginThread(@ActorSendThread, @LArgs1);
    LThread2 := BeginThread(@ActorSendThread, @LArgs2);
    AtomicStore32(LStart, 1, moRelease);
    WaitForThreadTerminate(LThread1, 5000);
    WaitForThreadTerminate(LThread2, 5000);

    Check(LArgs1.Result = arOk, 'First concurrent send succeeds');
    Check(LArgs2.Result = arOk, 'Second concurrent send succeeds');
    Check(AtomicLoad32(GHandledMessages, moAcquire) = 2,
      'Both concurrent messages are handled');
    Check(AtomicLoad32(GConcurrentHandlerSeen, moAcquire) = 0,
      'An actor must never execute two handlers concurrently');
  finally
    LActor.Free;
  end;
end;

procedure TestActorStopWaitsForActiveHandler;
var
  LActor: TActor;
  LSendArgs: TActorSendArgs;
  LStopArgs: TActorStopArgs;
  LSendThread, LStopThread: TThreadID;
  LSendStart, LStopStarted, LStopReturned: Int32;
  LSpin: Int32;
begin
  GBlockingHandlerEntered := 0;
  GReleaseBlockingHandler := 0;
  LSendStart := 0;
  LStopStarted := 0;
  LStopReturned := 0;
  LActor := TActor.Create(1, @BlockingActorHandler);
  try
    LSendArgs.Actor := LActor;
    LSendArgs.Start := @LSendStart;
    LSendArgs.Message.SenderId := 1;
    LSendArgs.Message.Data := 'block';
    LSendArgs.Result := arStopped;
    LSendThread := BeginThread(@ActorSendThread, @LSendArgs);
    AtomicStore32(LSendStart, 1, moRelease);

    LSpin := 0;
    while (AtomicLoad32(GBlockingHandlerEntered, moAcquire) = 0) and
          (LSpin < 1000000) do
    begin
      CpuPause;
      Inc(LSpin);
    end;
    Check(AtomicLoad32(GBlockingHandlerEntered, moAcquire) = 1,
      'Handler enters before Stop');

    LStopArgs.Actor := LActor;
    LStopArgs.Started := @LStopStarted;
    LStopArgs.Returned := @LStopReturned;
    LStopThread := BeginThread(@ActorStopThread, @LStopArgs);
    while AtomicLoad32(LStopStarted, moAcquire) = 0 do
      CpuPause;
    platform_thread_sleep_ns(5000000);
    Check(AtomicLoad32(LStopReturned, moAcquire) = 0,
      'Stop must wait for an active handler owned by another thread');

    AtomicStore32(GReleaseBlockingHandler, 1, moRelease);
    WaitForThreadTerminate(LSendThread, 5000);
    WaitForThreadTerminate(LStopThread, 5000);
    Check(AtomicLoad32(LStopReturned, moAcquire) = 1,
      'Stop returns after the active handler completes');
    Check(LActor.GetState = asStopped, 'Actor reaches stopped state');
  finally
    AtomicStore32(GReleaseBlockingHandler, 1, moRelease);
    LActor.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_actor ===');
  GPassed := 0;
  GFailed := 0;
  TestActorCreate;
  TestActorSend;
  TestActorStopRejects;
  TestActorSystem;
  TestActorHandlersAreSerialized;
  TestActorStopWaitsForActiveHandler;
  WriteLn;
  WriteLn('Results: ', GPassed, ' passed, ', GFailed, ' failed');
  if GFailed > 0 then
    Halt(1);
end.
