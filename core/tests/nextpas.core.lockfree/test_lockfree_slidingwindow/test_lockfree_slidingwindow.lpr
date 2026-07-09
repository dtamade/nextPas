program test_lockfree_slidingwindow;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.slidingwindow,
  nextpas.core.test;

procedure TestBasicAllow;
var
  SW: TSlidingWindowLimiter;
begin
  SW := TSlidingWindowLimiter.Create(10, 1000);
  try
    Check(not SW.IsClosed, 'Should not be closed');
    Check(SW.TryAcquire = swAllowed, 'Should allow');
    Check(SW.GetLimit = 10, 'Limit');
    Check(SW.GetWindowMs = 1000, 'Window');
  finally
    SW.Free;
  end;
end;

procedure TestReject;
var
  SW: TSlidingWindowLimiter;
  I: Integer;
begin
  SW := TSlidingWindowLimiter.Create(3, 10000);
  try
    for I := 1 to 3 do
      Check(SW.TryAcquire = swAllowed, 'Should allow');
    Check(SW.TryAcquire = swRejected, 'Should reject after limit');
  finally
    SW.Free;
  end;
end;

procedure TestMultipleAcquire;
var
  SW: TSlidingWindowLimiter;
begin
  SW := TSlidingWindowLimiter.Create(10, 10000);
  try
    Check(SW.TryAcquireN(5) = swAllowed, 'Acquire 5');
    Check(SW.TryAcquireN(5) = swAllowed, 'Acquire 5 more');
    Check(SW.TryAcquireN(1) = swRejected, 'Should reject');
  finally
    SW.Free;
  end;
end;

procedure TestClose;
var
  SW: TSlidingWindowLimiter;
begin
  SW := TSlidingWindowLimiter.Create(10, 1000);
  try
    SW.Close;
    Check(SW.IsClosed, 'Should be closed');
    Check(SW.TryAcquire = swClosed, 'Should reject on closed');
  finally
    SW.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_slidingwindow ===');
  WriteLn;

  TestBasicAllow;
  WriteLn('  + Basic allow');

  TestReject;
  WriteLn('  + Reject after limit');

  TestMultipleAcquire;
  WriteLn('  + Multiple acquire');

  TestClose;
  WriteLn('  + Close semantics');

  WriteLn;
  WriteLn('All sliding window tests passed!');
end.
