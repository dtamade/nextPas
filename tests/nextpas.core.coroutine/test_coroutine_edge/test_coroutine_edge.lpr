program test_coroutine_edge;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.coroutine.base,
  nextpas.core.coroutine.intf,
  nextpas.core.coroutine;

var
  GPass: Integer = 0;
  GFail: Integer = 0;
  GCount: Integer = 0;

procedure Check(const AName: string; ACond: Boolean);
begin
  if ACond then begin Inc(GPass); WriteLn('  PASS: ', AName); end
  else begin Inc(GFail); WriteLn('  FAIL: ', AName); end;
end;

procedure IncCount({%H-}AData: Pointer);
begin
  Inc(GCount);
end;

{ Edge cases }

procedure TestZeroFrameYield;
var
  LMgr: ICoroutineManager;
  LSteps: array[0..2] of TCoroStep;
begin
  WriteLn('--- TestZeroFrameYield ---');
  LMgr := CreateCoroutineManager;
  GCount := 0;
  LSteps[0] := CoroAction(@IncCount);
  LSteps[1] := CoroWaitFrames(0);
  LSteps[2] := CoroAction(@IncCount);
  LMgr.StartSequence(@LSteps[0], 3);
  LMgr.Update(0.016);
  Check('Zero frames resumes immediately', GCount = 2);
end;

procedure TestNegativeSeconds;
var
  LMgr: ICoroutineManager;
  LSteps: array[0..2] of TCoroStep;
begin
  WriteLn('--- TestNegativeSeconds ---');
  LMgr := CreateCoroutineManager;
  GCount := 0;
  LSteps[0] := CoroAction(@IncCount);
  LSteps[1] := CoroWaitSeconds(-1.0);
  LSteps[2] := CoroAction(@IncCount);
  LMgr.StartSequence(@LSteps[0], 3);
  LMgr.Update(0.016);
  Check('Negative seconds resumes immediately', GCount = 2);
end;

procedure TestStopInvalidID;
var
  LMgr: ICoroutineManager;
begin
  WriteLn('--- TestStopInvalidID ---');
  LMgr := CreateCoroutineManager;
  LMgr.Stop(99999);
  LMgr.Stop(COROUTINE_INVALID_ID);
  Check('No crash on invalid ID', True);
end;

procedure TestGetStateInvalidID;
var
  LMgr: ICoroutineManager;
begin
  WriteLn('--- TestGetStateInvalidID ---');
  LMgr := CreateCoroutineManager;
  Check('Invalid returns csFinished', LMgr.GetState(99999) = csFinished);
end;

procedure TestUpdateWithZeroDelta;
var
  LMgr: ICoroutineManager;
  LSteps: array[0..2] of TCoroStep;
begin
  WriteLn('--- TestUpdateWithZeroDelta ---');
  LMgr := CreateCoroutineManager;
  GCount := 0;
  LSteps[0] := CoroAction(@IncCount);
  LSteps[1] := CoroWaitSeconds(1.0);
  LSteps[2] := CoroAction(@IncCount);
  LMgr.StartSequence(@LSteps[0], 3);
  LMgr.Update(0);
  LMgr.Update(0);
  Check('Zero dt does not advance', GCount = 1);
end;

procedure TestEmptySequence;
var
  LMgr: ICoroutineManager;
  LID: TCoroutineID;
  LSteps: array[0..0] of TCoroStep;
begin
  WriteLn('--- TestEmptySequence ---');
  LMgr := CreateCoroutineManager;
  LSteps[0] := CoroEnd;
  LID := LMgr.StartSequence(@LSteps[0], 1);
  Check('Immediately finished', LMgr.GetState(LID) = csFinished);
  Check('ActiveCount=0', LMgr.GetActiveCount = 0);
end;

procedure TestRapidStartStop;
var
  LMgr: ICoroutineManager;
  LSteps: array[0..1] of TCoroStep;
  LID: TCoroutineID;
  LIdx: Integer;
begin
  WriteLn('--- TestRapidStartStop ---');
  LMgr := CreateCoroutineManager;
  LSteps[0] := CoroWaitSeconds(100);
  LSteps[1] := CoroEnd;
  for LIdx := 0 to 99 do
  begin
    LID := LMgr.StartSequence(@LSteps[0], 2);
    LMgr.Stop(LID);
  end;
  Check('All stopped', LMgr.GetActiveCount = 0);
end;

procedure TestNilCondition;
var
  LMgr: ICoroutineManager;
  LSteps: array[0..1] of TCoroStep;
begin
  WriteLn('--- TestNilCondition ---');
  LMgr := CreateCoroutineManager;
  LSteps[0] := CoroWaitUntil(nil);
  LSteps[1] := CoroEnd;
  LMgr.StartSequence(@LSteps[0], 2);
  LMgr.Update(0.016);
  Check('Nil condition stays suspended', LMgr.GetActiveCount = 1);
end;

procedure TestLargeDeltaTime;
var
  LMgr: ICoroutineManager;
  LSteps: array[0..2] of TCoroStep;
begin
  WriteLn('--- TestLargeDeltaTime ---');
  LMgr := CreateCoroutineManager;
  GCount := 0;
  LSteps[0] := CoroAction(@IncCount);
  LSteps[1] := CoroWaitSeconds(0.5);
  LSteps[2] := CoroAction(@IncCount);
  LMgr.StartSequence(@LSteps[0], 3);
  LMgr.Update(1000.0);
  Check('Large dt resumes', GCount = 2);
end;

begin
  WriteLn('=== nextpas.core.coroutine edge tests ===');
  WriteLn;
  TestZeroFrameYield;
  TestNegativeSeconds;
  TestStopInvalidID;
  TestGetStateInvalidID;
  TestUpdateWithZeroDelta;
  TestEmptySequence;
  TestRapidStartStop;
  TestNilCondition;
  TestLargeDeltaTime;
  WriteLn;
  WriteLn('=== Results: ', GPass, ' passed, ', GFail, ' failed ===');
  if GFail > 0 then Halt(1);
end.
