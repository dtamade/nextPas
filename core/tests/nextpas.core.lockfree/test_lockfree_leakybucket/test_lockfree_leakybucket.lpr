program test_lockfree_leakybucket;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  nextpas.core.platform.thread,
  nextpas.core.lockfree.leakybucket,
  nextpas.core.test;

procedure TestBasicAllow;
var
  LB: TLeakyBucket;
begin
  LB := TLeakyBucket.Create(10.0, 5.0);
  try
    Check(not LB.IsClosed, 'Should not be closed');
    Check(LB.TryAdd = lbAllowed, 'Should allow first request');
    Check(LB.GetBucketSize = 5.0, 'Bucket size');
    Check(LB.GetLeakRate = 10.0, 'Leak rate');
  finally
    LB.Free;
  end;
end;

procedure TestBucketOverflow;
var
  LB: TLeakyBucket;
begin
  LB := TLeakyBucket.Create(1.0, 3.0);
  try
    Check(LB.TryAdd = lbAllowed, '1st');
    Check(LB.TryAdd = lbAllowed, '2nd');
    Check(LB.TryAdd = lbAllowed, '3rd');
    Check(LB.TryAdd = lbRejected, '4th should overflow');
  finally
    LB.Free;
  end;
end;

procedure TestMultipleAdd;
var
  LB: TLeakyBucket;
begin
  LB := TLeakyBucket.Create(1.0, 10.0);
  try
    Check(LB.TryAddN(5.0) = lbAllowed, 'Add 5');
    Check(LB.TryAddN(5.0) = lbAllowed, 'Add 5 more');
    Check(LB.TryAddN(1.0) = lbRejected, 'Should overflow');
  finally
    LB.Free;
  end;
end;

procedure TestClose;
var
  LB: TLeakyBucket;
begin
  LB := TLeakyBucket.Create(10.0, 5.0);
  try
    LB.Close;
    Check(LB.IsClosed, 'Should be closed');
    Check(LB.TryAdd = lbClosed, 'Should reject on closed');
  finally
    LB.Free;
  end;
end;

procedure TestLeakUsesElapsedTime;
var
  LB: TLeakyBucket;
begin
  LB := TLeakyBucket.Create(20.0, 1.0);
  try
    Check(LB.TryAdd = lbAllowed, 'Initial request should fill bucket');
    Check(LB.TryAdd = lbRejected, 'Full bucket should reject');
    platform_thread_sleep_ms(60);
    Check(LB.TryAdd = lbAllowed, 'Elapsed time should leak one unit');
  finally
    LB.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_leakybucket ===');
  WriteLn;

  TestBasicAllow;
  WriteLn('  + Basic allow');

  TestBucketOverflow;
  WriteLn('  + Bucket overflow');

  TestMultipleAdd;
  WriteLn('  + Multiple add');

  TestClose;
  WriteLn('  + Close semantics');

  TestLeakUsesElapsedTime;
  WriteLn('  + Elapsed-time leak');

  WriteLn;
  WriteLn('All leaky bucket tests passed!');
end.
