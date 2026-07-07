program test_stack_guard;
{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.stack_guard,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator.rtl,
  nextpas.core.mem.arena.local;

var
  T: TTestSuite;

procedure TestBasicGuard;
begin
  Check(TStackGuard.Enter, 'First enter should succeed');
  TStackGuard.Leave;
end;

procedure TestDepthCounter;
begin
  Check(TStackGuard.CurrentDepth = 0, 'Initial depth should be 0');
  Check(TStackGuard.Enter, 'First enter should succeed');
  Check(TStackGuard.CurrentDepth = 1, 'Depth should be 1');
  TStackGuard.Leave;
  Check(TStackGuard.CurrentDepth = 0, 'Depth should be 0 after leave');
end;

procedure TestMaxDepth;
var
  LOldMax: Integer;
  I: Integer;
begin
  LOldMax := TStackGuard.GetMaxDepth;
  try
    TStackGuard.SetMaxDepth(3);
    Check(TStackGuard.GetMaxDepth = 3, 'Max depth should be 3');

    for I := 1 to 3 do
      Check(TStackGuard.Enter, 'Enter ' + IntToStr(I) + ' should succeed');
    Check(not TStackGuard.Enter, 'Enter 4 should fail');
    Check(TStackGuard.CurrentDepth = 3, 'Depth should be 3');

    for I := 1 to 3 do
      TStackGuard.Leave;
    Check(TStackGuard.CurrentDepth = 0, 'Depth should be 0');
  finally
    TStackGuard.SetMaxDepth(LOldMax);
  end;
end;

procedure TestSetMaxDepthValidation;
var
  LOldMax: Integer;
begin
  LOldMax := TStackGuard.GetMaxDepth;
  try
    TStackGuard.SetMaxDepth(0);
    Check(TStackGuard.GetMaxDepth = 1, 'Max depth should be clamped to 1');
    TStackGuard.SetMaxDepth(-5);
    Check(TStackGuard.GetMaxDepth = 1, 'Max depth should be clamped to 1');
  finally
    TStackGuard.SetMaxDepth(LOldMax);
  end;
end;

procedure TestArenaStackGuard;
var
  LArena: TLocalArena;
  LPtr: Pointer;
begin
  LArena := TLocalArena.Create(1024);
  try
    LPtr := LArena.Alloc(64);
    Check(LPtr <> nil, 'Normal alloc should succeed');
  finally
    LArena.Free;
  end;
end;

procedure TestArenaRecursionDetection;
var
  LOldMax: Integer;
  LArena: TLocalArena;
  LCaught: Boolean;
begin
  LOldMax := TStackGuard.GetMaxDepth;
  try
    TStackGuard.SetMaxDepth(1);
    LArena := TLocalArena.Create(1024);
    try
      // Simulate being inside an allocation (depth = 1)
      Check(TStackGuard.Enter, 'Manual enter should succeed');
      try
        LCaught := False;
        try
          LArena.Alloc(64);  // This should raise EStackOverflow
        except
          on E: EStackOverflow do
            LCaught := True;
        end;
        Check(LCaught, 'Should have caught EStackOverflow');
      finally
        TStackGuard.Leave;
      end;
    finally
      LArena.Free;
    end;
  finally
    TStackGuard.SetMaxDepth(LOldMax);
  end;
end;

procedure TestLeaveWhenZero;
begin
  // Leave when depth is 0 should be safe (no-op)
  Check(TStackGuard.CurrentDepth = 0, 'Initial depth should be 0');
  TStackGuard.Leave;
  Check(TStackGuard.CurrentDepth = 0, 'Depth should still be 0');
end;

begin
  T := TTestSuite.Create('test_stack_guard');

  T.Test('basic_guard', @TestBasicGuard);
  T.Test('depth_counter', @TestDepthCounter);
  T.Test('max_depth', @TestMaxDepth);
  T.Test('set_max_depth_validation', @TestSetMaxDepthValidation);
  T.Test('arena_stack_guard', @TestArenaStackGuard);
  T.Test('arena_recursion_detection', @TestArenaRecursionDetection);
  T.Test('leave_when_zero', @TestLeaveWhenZero);

  T.Run;
  T.Summary;
end.
