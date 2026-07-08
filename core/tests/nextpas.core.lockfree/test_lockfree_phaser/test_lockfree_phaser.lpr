program test_lockfree_phaser;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.lockfree.phaser,
  nextpas.core.lockfree,
  nextpas.core.platform.thread,
  nextpas.core.test;

type
  TPhaserArgs = record
    Phaser: TPhaser;
    PhaseResult: Int64;
  end;
  PPhaserArgs = ^TPhaserArgs;

function PhaserThreadProc(AArg: Pointer): Pointer; cdecl;
var
  LArgs: PPhaserArgs;
begin
  LArgs := PPhaserArgs(AArg);
  LArgs^.PhaseResult := LArgs^.Phaser.ArriveAndAwaitAdvance;
  Result := nil;
end;

procedure TestPhaserBasic;
var
  LPhaser: TPhaser;
begin
  LPhaser := TPhaser.Create(2);
  try
    CheckEqual(Int64(0), LPhaser.GetPhase);
    CheckEqual(Int64(2), LPhaser.GetParties);
    CheckEqual(Int64(0), LPhaser.GetArrived);
    CheckEqual(Int64(2), LPhaser.GetUnarrived);
    Check(not LPhaser.IsClosed, 'Should not be closed');
  finally
    LPhaser.Free;
  end;
end;

procedure TestPhaserRegister;
var
  LPhaser: TPhaser;
begin
  LPhaser := TPhaser.Create(0);
  try
    CheckEqual(Int64(0), LPhaser.GetParties);

    LPhaser.Register;
    CheckEqual(Int64(1), LPhaser.GetParties);

    LPhaser.Register;
    CheckEqual(Int64(2), LPhaser.GetParties);
  finally
    LPhaser.Free;
  end;
end;

procedure TestPhaserArrive;
var
  LPhaser: TPhaser;
  LPhase: Int64;
begin
  LPhaser := TPhaser.Create(2);
  try
    LPhase := LPhaser.Arrive;
    CheckEqual(Int64(0), LPhase);
    CheckEqual(Int64(1), LPhaser.GetArrived);

    // Last party arrives - phase advances
    LPhase := LPhaser.Arrive;
    CheckEqual(Int64(1), LPhase);
    CheckEqual(Int64(0), LPhaser.GetArrived);
    CheckEqual(Int64(1), LPhaser.GetPhase);
  finally
    LPhaser.Free;
  end;
end;

procedure TestPhaserArriveAndDeregister;
var
  LPhaser: TPhaser;
  LPhase: Int64;
begin
  LPhaser := TPhaser.Create(3);
  try
    // 3 parties, deregister 1 -> 2 parties, 1 arrived
    LPhase := LPhaser.ArriveAndDeregister;
    CheckEqual(Int64(0), LPhase);
    CheckEqual(Int64(2), LPhaser.GetParties);
  finally
    LPhaser.Free;
  end;
end;

procedure TestPhaserTwoThreads;
var
  LPhaser: TPhaser;
  LArgs: TPhaserArgs;
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LPhase: Int64;
begin
  LPhaser := TPhaser.Create(2);
  try
    LArgs.Phaser := LPhaser;
    LArgs.PhaseResult := -1;

    CheckEqual(Int64(0), Int64(platform_thread_create(LHandle, @PhaserThreadProc, @LArgs)),
      'thread create must succeed');

    // Both threads call ArriveAndAwaitAdvance - they synchronize
    LPhase := LPhaser.ArriveAndAwaitAdvance;
    CheckEqual(Int64(1), LPhase, 'Main thread should see phase 1');

    CheckEqual(Int64(0), Int64(platform_thread_join(LHandle, LRetVal)),
      'thread join must succeed');

    CheckEqual(Int64(1), LArgs.PhaseResult, 'Thread should see phase 1');
  finally
    LPhaser.Free;
  end;
end;

procedure TestPhaserMultiplePhases;
var
  LPhaser: TPhaser;
  LPhase: Int64;
begin
  LPhaser := TPhaser.Create(1);
  try
    // Phase 0 -> 1
    LPhase := LPhaser.ArriveAndAwaitAdvance;
    CheckEqual(Int64(1), LPhase);

    // Phase 1 -> 2
    LPhase := LPhaser.ArriveAndAwaitAdvance;
    CheckEqual(Int64(2), LPhase);

    // Phase 2 -> 3
    LPhase := LPhaser.ArriveAndAwaitAdvance;
    CheckEqual(Int64(3), LPhase);

    CheckEqual(Int64(3), LPhaser.GetPhase);
  finally
    LPhaser.Free;
  end;
end;

procedure TestPhaserTerminate;
var
  LPhaser: TPhaser;
  LResult: TLockFreePhaserArriveResult;
begin
  LPhaser := TPhaser.Create(1);
  try
    LPhaser.Terminate;
    Check(LPhaser.IsTerminated, 'Should be terminated');
    Check(LPhaser.IsClosed, 'Should be closed');

    LResult := LPhaser.AwaitAdvance(0);
    Check(paClosed = LResult, 'Should return closed');
  finally
    LPhaser.Free;
  end;
end;

procedure TestPhaserZeroParties;
var
  LPhaser: TPhaser;
  LPhase: Int64;
begin
  LPhaser := TPhaser.Create(0);
  try
    // No parties, arrive immediately advances
    LPhase := LPhaser.Arrive;
    CheckEqual(Int64(1), LPhase);
  finally
    LPhaser.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_phaser ===');
  WriteLn;

  TestPhaserBasic;
  WriteLn('  + Basic state');

  TestPhaserRegister;
  WriteLn('  + Register');

  TestPhaserArrive;
  WriteLn('  + Arrive phase advance');

  TestPhaserArriveAndDeregister;
  WriteLn('  + ArriveAndDeregister');

  TestPhaserTwoThreads;
  WriteLn('  + Two thread sync');

  TestPhaserMultiplePhases;
  WriteLn('  + Multiple phases');

  TestPhaserTerminate;
  WriteLn('  + Terminate');

  TestPhaserZeroParties;
  WriteLn('  + Zero parties');

  WriteLn;
  WriteLn('All phaser tests passed!');
end.
