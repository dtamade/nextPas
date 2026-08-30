program test_agent_slot_registry;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.test;

procedure TestBasicFindRegister;
var
  R: TAgentSlotRegistry;
  P: Integer;
  OK: Boolean;
begin
  R.Init;
  OK := R.TryFind(0, P);
  Check(not OK, 'empty miss');
  OK := R.Register(0, P);
  Check(OK and (P = 0), 'register 0 at 0');
  OK := R.TryFind(0, P);
  Check(OK and (P = 0), 'find 0 hit');
  OK := R.Register(0, P);
  Check(not OK and (P = 0), 'duplicate register returns existing');
  Check(R.Count = 1, 'count 1');
end;

procedure TestGeometricGrowthAndCount;
var
  R: TAgentSlotRegistry;
  I, P: Integer;
  OK: Boolean;
begin
  R.Init;
  for I := 0 to 100 do
  begin
    OK := R.Register(I, P);
    Check(OK, 'register ' + IntToStr(I));
    Check(P = I, 'pos equals order');
  end;
  Check(R.Count = 101, 'count 101');
  for I := 0 to 100 do
  begin
    OK := R.TryFind(I, P);
    Check(OK and (P = I), 'find after fill ' + IntToStr(I));
  end;
end;

procedure TestSparseLargeIndexFallback;
var
  R: TAgentSlotRegistry;
  P: Integer;
  OK: Boolean;
begin
  R.Init;
  OK := R.Register(10000, P);
  Check(OK and (P = 0), 'sparse 10000 at 0');
  OK := R.TryFind(10000, P);
  Check(OK and (P = 0), 'find sparse');
  OK := R.Register(10000, P);
  Check(not OK and (P = 0), 'duplicate sparse');
  Check(R.Count = 1, 'count still 1');
  OK := R.Register(20000, P);
  Check(OK and (P = 1), 'second sparse 20000 at 1');
end;

procedure TestBoundaries256;
var
  R: TAgentSlotRegistry;
  I, P: Integer;
  OK: Boolean;
begin
  R.Init;
  for I := 0 to CAgentMaxSlotMap do
  begin
    OK := R.Register(I, P);
    Check(OK, 'fill 0..256');
  end;
  Check(R.Count = CAgentMaxSlotMap + 1, 'full');
  OK := R.Register(257, P);
  Check(not OK, '257 after full rejected (count overflow)');
  OK := R.TryFind(0, P);
  Check(OK and (P = 0), 'still find 0 after full');
  OK := R.TryFind(257, P);
  Check(not OK, '257 not found after reject');
end;

procedure TestClearReuse;
var
  R: TAgentSlotRegistry;
  P: Integer;
  OK: Boolean;
begin
  R.Init;
  R.Register(5, P);
  R.Register(10000, P);
  Check(R.Count = 2, '2 before clear');
  R.Clear;
  Check(R.Count = 0, '0 after clear');
  OK := R.TryFind(5, P);
  Check(not OK, 'miss after clear');
  OK := R.Register(5, P);
  Check(OK and (P = 0), 're-register after clear');
end;

procedure TestNegativeNotRegistered;
var
  R: TAgentSlotRegistry;
  P: Integer;
  OK: Boolean;
begin
  R.Init;
  OK := R.Register(-1, P);
  Check(not OK, 'negative not registered');
  OK := R.TryFind(-1, P);
  Check(not OK, 'negative not found');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.slot.registry');
  T.Test('basic find/register', @TestBasicFindRegister);
  T.Test('geometric growth and count', @TestGeometricGrowthAndCount);
  T.Test('sparse large index fallback', @TestSparseLargeIndexFallback);
  T.Test('boundaries 256', @TestBoundaries256);
  T.Test('clear reuse', @TestClearReuse);
  T.Test('negative not registered', @TestNegativeNotRegistered);
  if not T.Run then Halt(1);
end.
