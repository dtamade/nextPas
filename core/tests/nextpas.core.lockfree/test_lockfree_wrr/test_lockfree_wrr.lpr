program test_lockfree_wrr;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.wrr,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

procedure TestWRRBasic;
var
  LWRR: TWRRImpl;
  LId: UInt64;
begin
  LWRR := TWRRImpl.Create(8);
  try
    CheckEqual(Ord(wrrOk), Ord(LWRR.AddBackend(1, 5)));
    CheckEqual(Ord(wrrOk), Ord(LWRR.AddBackend(2, 3)));
    CheckEqual(Ord(wrrOk), Ord(LWRR.AddBackend(3, 1)));

    CheckEqual(3, LWRR.GetCount);
    CheckEqual(9, LWRR.GetTotalWeight);

    { Should distribute proportionally }
    CheckEqual(Ord(wrrOk), Ord(LWRR.Next(LId)));
    Check(LId > 0, 'Should return valid backend');
  finally
    LWRR.Free;
  end;
end;

procedure TestWRRDistribution;
var
  LWRR: TWRRImpl;
  LId: UInt64;
  LCounts: array[1..3] of Integer;
  LI: Integer;
begin
  LWRR := TWRRImpl.Create(8);
  try
    LWRR.AddBackend(1, 3);
    LWRR.AddBackend(2, 2);
    LWRR.AddBackend(3, 1);

    FillChar(LCounts, SizeOf(LCounts), 0);

    { Run 60 iterations: expect ~30/20/10 distribution }
    for LI := 1 to 60 do
    begin
      LWRR.Next(LId);
      if LId = 1 then Inc(LCounts[1])
      else if LId = 2 then Inc(LCounts[2])
      else if LId = 3 then Inc(LCounts[3]);
    end;

    { With Nginx smooth WRR, 6 iterations produce exactly 3/2/1, so 60 → 30/20/10 }
    Check(LCounts[1] = 30, 'Backend 1 should get 30, got ' + IntToStr(LCounts[1]));
    Check(LCounts[2] = 20, 'Backend 2 should get 20, got ' + IntToStr(LCounts[2]));
    Check(LCounts[3] = 10, 'Backend 3 should get 10, got ' + IntToStr(LCounts[3]));
  finally
    LWRR.Free;
  end;
end;

procedure TestWRRRemoveBackend;
var
  LWRR: TWRRImpl;
begin
  LWRR := TWRRImpl.Create(8);
  try
    LWRR.AddBackend(1, 5);
    LWRR.AddBackend(2, 3);

    CheckEqual(2, LWRR.GetCount);
    CheckEqual(Ord(wrrOk), Ord(LWRR.RemoveBackend(1)));
    CheckEqual(1, LWRR.GetCount);
    CheckEqual(3, LWRR.GetTotalWeight);

    CheckEqual(Ord(wrrNotFound), Ord(LWRR.RemoveBackend(99)));
  finally
    LWRR.Free;
  end;
end;

procedure TestWRRUpdateWeight;
var
  LWRR: TWRRImpl;
begin
  LWRR := TWRRImpl.Create(8);
  try
    LWRR.AddBackend(1, 5);
    CheckEqual(5, LWRR.GetTotalWeight);

    CheckEqual(Ord(wrrOk), Ord(LWRR.UpdateWeight(1, 10)));
    CheckEqual(10, LWRR.GetTotalWeight);

    CheckEqual(Ord(wrrInvalidWeight), Ord(LWRR.UpdateWeight(1, 0)));
    CheckEqual(Ord(wrrNotFound), Ord(LWRR.UpdateWeight(99, 5)));
  finally
    LWRR.Free;
  end;
end;

procedure TestWRREmpty;
var
  LWRR: TWRRImpl;
  LId: UInt64;
begin
  LWRR := TWRRImpl.Create(8);
  try
    CheckEqual(Ord(wrrNoBackends), Ord(LWRR.Next(LId)));
  finally
    LWRR.Free;
  end;
end;

procedure TestWRRClose;
var
  LWRR: TWRRImpl;
begin
  LWRR := TWRRImpl.Create(8);
  try
    LWRR.AddBackend(1, 5);
    LWRR.Close;
    Check(LWRR.IsClosed, 'Should be closed');
    CheckEqual(Ord(wrrClosed), Ord(LWRR.AddBackend(2, 3)));
  finally
    LWRR.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_wrr ===');
  WriteLn;

  TestWRRBasic;
  WriteLn('  + Basic add/next');

  TestWRRDistribution;
  WriteLn('  + Weight distribution');

  TestWRRRemoveBackend;
  WriteLn('  + Remove backend');

  TestWRRUpdateWeight;
  WriteLn('  + Update weight');

  TestWRREmpty;
  WriteLn('  + Empty state');

  TestWRRClose;
  WriteLn('  + Close semantics');

  WriteLn;
  WriteLn('All WRR tests passed!');
end.
