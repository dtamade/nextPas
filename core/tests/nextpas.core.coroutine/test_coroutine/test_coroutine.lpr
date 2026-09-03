program test_coroutine;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.coroutine.base,
  nextpas.core.coroutine.intf,
  nextpas.core.coroutine,
  nextpas.core.test;

var GActionCount: Integer = 0; GConditionFlag: Boolean = False;

procedure IncrementAction({%H-}AUserData: Pointer); begin Inc(GActionCount); end;
function CheckFlag({%H-}AUserData: Pointer): Boolean; begin Result := GConditionFlag; end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('coroutine');

  LSuite.Test('create and destroy', procedure
  var LMgr: ICoroutineManager;
  begin
    LMgr := CreateCoroutineManager;
    CheckTrue(LMgr <> nil);
    CheckTrue(LMgr.GetActiveCount = 0);
    LMgr := nil;
  end);

  LSuite.Test('start and finish', procedure
  var LMgr: ICoroutineManager; LID: TCoroutineID; LSteps: array[0..1] of TCoroStep;
  begin
    LMgr := CreateCoroutineManager;
    LSteps[0] := CoroAction(@IncrementAction); LSteps[1] := CoroEnd;
    GActionCount := 0;
    LID := LMgr.StartSequence(@LSteps[0], 2);
    CheckTrue(LID <> COROUTINE_INVALID_ID);
    CheckTrue(GActionCount = 1);
    CheckTrue(LMgr.GetState(LID) = csFinished);
    CheckTrue(LMgr.GetActiveCount = 0);
  end);

  LSuite.Test('yield frames', procedure
  var LMgr: ICoroutineManager; LID: TCoroutineID; LSteps: array[0..2] of TCoroStep;
  begin
    LMgr := CreateCoroutineManager; GActionCount := 0;
    LSteps[0] := CoroAction(@IncrementAction);
    LSteps[1] := CoroWaitFrames(3);
    LSteps[2] := CoroAction(@IncrementAction);
    LID := LMgr.StartSequence(@LSteps[0], 3);
    CheckTrue(GActionCount = 1); CheckTrue(LMgr.GetState(LID) = csSuspended);
    LMgr.Update(0.016); CheckTrue(LMgr.GetState(LID) = csSuspended);
    LMgr.Update(0.016); CheckTrue(LMgr.GetState(LID) = csSuspended);
    LMgr.Update(0.016);
    CheckTrue(GActionCount = 2); CheckTrue(LMgr.GetState(LID) = csFinished);
  end);

  LSuite.Test('yield seconds', procedure
  var LMgr: ICoroutineManager; LID: TCoroutineID; LSteps: array[0..2] of TCoroStep;
  begin
    LMgr := CreateCoroutineManager; GActionCount := 0;
    LSteps[0] := CoroAction(@IncrementAction);
    LSteps[1] := CoroWaitSeconds(0.5);
    LSteps[2] := CoroAction(@IncrementAction);
    LID := LMgr.StartSequence(@LSteps[0], 3);
    CheckTrue(GActionCount = 1);
    LMgr.Update(0.3); CheckTrue(GActionCount = 1);
    LMgr.Update(0.3); CheckTrue(GActionCount = 2);
    CheckTrue(LMgr.GetState(LID) = csFinished);
  end);

  LSuite.Test('yield until', procedure
  var LMgr: ICoroutineManager; LID: TCoroutineID; LSteps: array[0..2] of TCoroStep;
  begin
    LMgr := CreateCoroutineManager; GActionCount := 0; GConditionFlag := False;
    LSteps[0] := CoroAction(@IncrementAction);
    LSteps[1] := CoroWaitUntil(@CheckFlag);
    LSteps[2] := CoroAction(@IncrementAction);
    LID := LMgr.StartSequence(@LSteps[0], 3);
    CheckTrue(GActionCount = 1);
    LMgr.Update(0.016); CheckTrue(GActionCount = 1);
    GConditionFlag := True;
    LMgr.Update(0.016); CheckTrue(GActionCount = 2);
  end);

  LSuite.Test('stop', procedure
  var LMgr: ICoroutineManager; LID: TCoroutineID; LSteps: array[0..2] of TCoroStep;
  begin
    LMgr := CreateCoroutineManager;
    LSteps[0] := CoroAction(@IncrementAction);
    LSteps[1] := CoroWaitSeconds(10);
    LSteps[2] := CoroAction(@IncrementAction);
    LID := LMgr.StartSequence(@LSteps[0], 3);
    CheckTrue(LMgr.GetActiveCount = 1);
    LMgr.Stop(LID);
    CheckTrue(LMgr.GetActiveCount = 0);
    CheckTrue(LMgr.GetState(LID) = csFinished);
  end);

  LSuite.Test('stop all', procedure
  var LMgr: ICoroutineManager; LSteps: array[0..1] of TCoroStep;
  begin
    LMgr := CreateCoroutineManager;
    LSteps[0] := CoroWaitSeconds(10); LSteps[1] := CoroEnd;
    LMgr.StartSequence(@LSteps[0], 2);
    LMgr.StartSequence(@LSteps[0], 2);
    LMgr.StartSequence(@LSteps[0], 2);
    CheckTrue(LMgr.GetActiveCount = 3);
    LMgr.StopAll;
    CheckTrue(LMgr.GetActiveCount = 0);
  end);

  LSuite.Test('stop by tag', procedure
  var LMgr: ICoroutineManager; LSteps: array[0..1] of TCoroStep;
  begin
    LMgr := CreateCoroutineManager;
    LSteps[0] := CoroWaitSeconds(10); LSteps[1] := CoroEnd;
    LMgr.StartSequence(@LSteps[0], 2, nil, 1);
    LMgr.StartSequence(@LSteps[0], 2, nil, 2);
    LMgr.StartSequence(@LSteps[0], 2, nil, 1);
    CheckTrue(LMgr.GetActiveCount = 3);
    LMgr.StopByTag(1);
    CheckTrue(LMgr.GetActiveCount = 1);
  end);

  LSuite.Test('multi-step sequence', procedure
  var LMgr: ICoroutineManager; LID: TCoroutineID; LSteps: array[0..5] of TCoroStep;
  begin
    LMgr := CreateCoroutineManager; GActionCount := 0;
    LSteps[0] := CoroAction(@IncrementAction);
    LSteps[1] := CoroWaitFrames(1);
    LSteps[2] := CoroAction(@IncrementAction);
    LSteps[3] := CoroWaitFrames(1);
    LSteps[4] := CoroAction(@IncrementAction);
    LSteps[5] := CoroEnd;
    LID := LMgr.StartSequence(@LSteps[0], 6);
    CheckTrue(GActionCount = 1);
    LMgr.Update(0.016); CheckTrue(GActionCount = 2);
    LMgr.Update(0.016); CheckTrue(GActionCount = 3);
    CheckTrue(LMgr.GetState(LID) = csFinished);
  end);

  LSuite.Test('max coroutines', procedure
  var LMgr: ICoroutineManager; LSteps: array[0..1] of TCoroStep; LIdx: Integer; LID: TCoroutineID;
  begin
    LMgr := CreateCoroutineManager;
    LSteps[0] := CoroWaitSeconds(100); LSteps[1] := CoroEnd;
    for LIdx := 0 to COROUTINE_MAX_ACTIVE - 1 do
      LMgr.StartSequence(@LSteps[0], 2);
    CheckTrue(LMgr.GetActiveCount = COROUTINE_MAX_ACTIVE);
    LID := LMgr.StartSequence(@LSteps[0], 2);
    CheckTrue(LID = COROUTINE_INVALID_ID);
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.coroutine');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
