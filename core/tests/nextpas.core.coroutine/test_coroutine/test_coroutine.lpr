program test_coroutine;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.coroutine.base,
  nextpas.core.coroutine.intf,
  nextpas.core.coroutine;

var
  GTestPassed: Integer = 0;
  GTestFailed: Integer = 0;
  GActionCount: Integer = 0;
  GConditionFlag: Boolean = False;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    Inc(GTestPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GTestFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

{ Test helpers }

procedure IncrementAction({%H-}AUserData: Pointer);
begin
  Inc(GActionCount);
end;

function CheckFlag(AUserData: Pointer): Boolean;
begin
  Result := GConditionFlag;
end;

{ Tests }

procedure TestCreateAndDestroy;
var
  LMgr: ICoroutineManager;
begin
  WriteLn('--- TestCreateAndDestroy ---');
  LMgr := CreateCoroutineManager;
  Check('Created', LMgr <> nil);
  Check('ActiveCount=0', LMgr.GetActiveCount = 0);
  LMgr := nil;
end;

procedure TestStartAndFinish;
var
  LMgr: ICoroutineManager;
  LID: TCoroutineID;
  LSteps: array[0..1] of TCoroStep;
begin
  WriteLn('--- TestStartAndFinish ---');
  LMgr := CreateCoroutineManager;
  LSteps[0] := CoroAction(@IncrementAction);
  LSteps[1] := CoroEnd;
  GActionCount := 0;
  LID := LMgr.StartSequence(@LSteps[0], 2);
  Check('ID valid', LID <> COROUTINE_INVALID_ID);
  Check('Action executed', GActionCount = 1);
  Check('Finished', LMgr.GetState(LID) = csFinished);
  Check('ActiveCount=0', LMgr.GetActiveCount = 0);
end;

procedure TestYieldFrames;
var
  LMgr: ICoroutineManager;
  LID: TCoroutineID;
  LSteps: array[0..2] of TCoroStep;
begin
  WriteLn('--- TestYieldFrames ---');
  LMgr := CreateCoroutineManager;
  GActionCount := 0;
  LSteps[0] := CoroAction(@IncrementAction);
  LSteps[1] := CoroWaitFrames(3);
  LSteps[2] := CoroAction(@IncrementAction);
  LID := LMgr.StartSequence(@LSteps[0], 3);
  Check('First action', GActionCount = 1);
  Check('Suspended', LMgr.GetState(LID) = csSuspended);

  LMgr.Update(0.016); // frame 1
  Check('Still suspended after 1', LMgr.GetState(LID) = csSuspended);
  LMgr.Update(0.016); // frame 2
  Check('Still suspended after 2', LMgr.GetState(LID) = csSuspended);
  LMgr.Update(0.016); // frame 3 — resumes
  Check('Resumed after 3', GActionCount = 2);
  Check('Finished', LMgr.GetState(LID) = csFinished);
end;

procedure TestYieldSeconds;
var
  LMgr: ICoroutineManager;
  LID: TCoroutineID;
  LSteps: array[0..2] of TCoroStep;
begin
  WriteLn('--- TestYieldSeconds ---');
  LMgr := CreateCoroutineManager;
  GActionCount := 0;
  LSteps[0] := CoroAction(@IncrementAction);
  LSteps[1] := CoroWaitSeconds(0.5);
  LSteps[2] := CoroAction(@IncrementAction);
  LID := LMgr.StartSequence(@LSteps[0], 3);
  Check('First action', GActionCount = 1);

  LMgr.Update(0.3);
  Check('Not yet at 0.3s', GActionCount = 1);
  LMgr.Update(0.3);
  Check('Resumed at 0.6s', GActionCount = 2);
  Check('Finished', LMgr.GetState(LID) = csFinished);
end;

procedure TestYieldUntil;
var
  LMgr: ICoroutineManager;
  LID: TCoroutineID;
  LSteps: array[0..2] of TCoroStep;
begin
  WriteLn('--- TestYieldUntil ---');
  LMgr := CreateCoroutineManager;
  GActionCount := 0;
  GConditionFlag := False;
  LSteps[0] := CoroAction(@IncrementAction);
  LSteps[1] := CoroWaitUntil(@CheckFlag);
  LSteps[2] := CoroAction(@IncrementAction);
  LID := LMgr.StartSequence(@LSteps[0], 3);
  Check('First action', GActionCount = 1);

  LMgr.Update(0.016);
  Check('Still waiting', GActionCount = 1);
  GConditionFlag := True;
  LMgr.Update(0.016);
  Check('Resumed when true', GActionCount = 2);
end;

procedure TestStop;
var
  LMgr: ICoroutineManager;
  LID: TCoroutineID;
  LSteps: array[0..2] of TCoroStep;
begin
  WriteLn('--- TestStop ---');
  LMgr := CreateCoroutineManager;
  LSteps[0] := CoroAction(@IncrementAction);
  LSteps[1] := CoroWaitSeconds(10);
  LSteps[2] := CoroAction(@IncrementAction);
  LID := LMgr.StartSequence(@LSteps[0], 3);
  Check('Active', LMgr.GetActiveCount = 1);
  LMgr.Stop(LID);
  Check('Stopped', LMgr.GetActiveCount = 0);
  Check('State=Finished', LMgr.GetState(LID) = csFinished);
end;

procedure TestStopAll;
var
  LMgr: ICoroutineManager;
  LSteps: array[0..1] of TCoroStep;
begin
  WriteLn('--- TestStopAll ---');
  LMgr := CreateCoroutineManager;
  LSteps[0] := CoroWaitSeconds(10);
  LSteps[1] := CoroEnd;
  LMgr.StartSequence(@LSteps[0], 2);
  LMgr.StartSequence(@LSteps[0], 2);
  LMgr.StartSequence(@LSteps[0], 2);
  Check('3 active', LMgr.GetActiveCount = 3);
  LMgr.StopAll;
  Check('All stopped', LMgr.GetActiveCount = 0);
end;

procedure TestStopByTag;
var
  LMgr: ICoroutineManager;
  LSteps: array[0..1] of TCoroStep;
begin
  WriteLn('--- TestStopByTag ---');
  LMgr := CreateCoroutineManager;
  LSteps[0] := CoroWaitSeconds(10);
  LSteps[1] := CoroEnd;
  LMgr.StartSequence(@LSteps[0], 2, nil, 1);
  LMgr.StartSequence(@LSteps[0], 2, nil, 2);
  LMgr.StartSequence(@LSteps[0], 2, nil, 1);
  Check('3 active', LMgr.GetActiveCount = 3);
  LMgr.StopByTag(1);
  Check('1 remaining', LMgr.GetActiveCount = 1);
end;

procedure TestMultiStepSequence;
var
  LMgr: ICoroutineManager;
  LID: TCoroutineID;
  LSteps: array[0..5] of TCoroStep;
begin
  WriteLn('--- TestMultiStepSequence ---');
  LMgr := CreateCoroutineManager;
  GActionCount := 0;
  LSteps[0] := CoroAction(@IncrementAction);
  LSteps[1] := CoroWaitFrames(1);
  LSteps[2] := CoroAction(@IncrementAction);
  LSteps[3] := CoroWaitFrames(1);
  LSteps[4] := CoroAction(@IncrementAction);
  LSteps[5] := CoroEnd;
  LID := LMgr.StartSequence(@LSteps[0], 6);
  Check('Step 1', GActionCount = 1);
  LMgr.Update(0.016);
  Check('Step 2', GActionCount = 2);
  LMgr.Update(0.016);
  Check('Step 3', GActionCount = 3);
  Check('Finished', LMgr.GetState(LID) = csFinished);
end;

procedure TestMaxCoroutines;
var
  LMgr: ICoroutineManager;
  LSteps: array[0..1] of TCoroStep;
  LIdx: Integer;
  LID: TCoroutineID;
begin
  WriteLn('--- TestMaxCoroutines ---');
  LMgr := CreateCoroutineManager;
  LSteps[0] := CoroWaitSeconds(100);
  LSteps[1] := CoroEnd;
  for LIdx := 0 to COROUTINE_MAX_ACTIVE - 1 do
    LMgr.StartSequence(@LSteps[0], 2);
  Check('Max reached', LMgr.GetActiveCount = COROUTINE_MAX_ACTIVE);
  LID := LMgr.StartSequence(@LSteps[0], 2);
  Check('Overflow returns invalid', LID = COROUTINE_INVALID_ID);
end;

begin
  WriteLn('=== nextpas.core.coroutine tests ===');
  WriteLn;

  TestCreateAndDestroy;
  TestStartAndFinish;
  TestYieldFrames;
  TestYieldSeconds;
  TestYieldUntil;
  TestStop;
  TestStopAll;
  TestStopByTag;
  TestMultiStepSequence;
  TestMaxCoroutines;

  WriteLn;
  WriteLn('=== Results: ', GTestPassed, ' passed, ', GTestFailed, ' failed ===');
  if GTestFailed > 0 then
    Halt(1);
end.
