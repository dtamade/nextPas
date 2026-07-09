program test_lockfree_actor;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  SysUtils,
  nextpas.core.lockfree.actor;

var
  GPassed, GFailed: Int32;

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

begin
  WriteLn('=== test_lockfree_actor ===');
  GPassed := 0;
  GFailed := 0;
  TestActorCreate;
  TestActorSend;
  TestActorStopRejects;
  TestActorSystem;
  WriteLn;
  WriteLn('Results: ', GPassed, ' passed, ', GFailed, ' failed');
  if GFailed > 0 then
    Halt(1);
end.
