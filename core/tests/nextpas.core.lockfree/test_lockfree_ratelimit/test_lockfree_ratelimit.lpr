program test_lockfree_ratelimit;

{$mode objfpc}{$H+}

uses
  Math,
  SysUtils,
  nextpas.core.lockfree.ratelimit,
  nextpas.core.lockfree,
  nextpas.core.errors,
  nextpas.core.test;

procedure TestRateLimiterBasic;
var
  LLimiter: TTokenBucketLimiter;
  LResult: TLockFreeRateLimiterResult;
begin
  LLimiter := TTokenBucketLimiter.Create(10.0, 5.0); // 10/s, burst=5
  try
    Check(not LLimiter.IsClosed, 'Should not be closed');
    CheckEqual(10.0, LLimiter.GetRate, 0.001);
    CheckEqual(5.0, LLimiter.GetBurst, 0.001);

    // Should allow up to burst
    LResult := LLimiter.TryAcquire;
    Check(rlAllowed = LResult, 'Should allow');

    LResult := LLimiter.TryAcquire;
    Check(rlAllowed = LResult, 'Should allow');

    LResult := LLimiter.TryAcquire;
    Check(rlAllowed = LResult, 'Should allow');

    LResult := LLimiter.TryAcquire;
    Check(rlAllowed = LResult, 'Should allow');

    LResult := LLimiter.TryAcquire;
    Check(rlAllowed = LResult, 'Should allow');
  finally
    LLimiter.Free;
  end;
end;

procedure TestRateLimiterBurstExhausted;
var
  LLimiter: TTokenBucketLimiter;
  LResult: TLockFreeRateLimiterResult;
  LI: Integer;
begin
  LLimiter := TTokenBucketLimiter.Create(1.0, 3.0); // 1/s, burst=3
  try
    // Exhaust burst
    for LI := 1 to 3 do
    begin
      LResult := LLimiter.TryAcquire;
      Check(rlAllowed = LResult, 'Should allow burst');
    end;

    // Should reject now
    LResult := LLimiter.TryAcquire;
    Check(rlRejected = LResult, 'Should reject after burst exhausted');
  finally
    LLimiter.Free;
  end;
end;

procedure TestRateLimiterClose;
var
  LLimiter: TTokenBucketLimiter;
  LResult: TLockFreeRateLimiterResult;
begin
  LLimiter := TTokenBucketLimiter.Create(10.0, 5.0);
  try
    LLimiter.Close;
    Check(LLimiter.IsClosed, 'Should be closed');

    LResult := LLimiter.TryAcquire;
    Check(rlClosed = LResult, 'Should return closed');
  finally
    LLimiter.Free;
  end;
end;

procedure TestRateLimiterAcquireN;
var
  LLimiter: TTokenBucketLimiter;
  LResult: TLockFreeRateLimiterResult;
begin
  LLimiter := TTokenBucketLimiter.Create(10.0, 5.0);
  try
    // Acquire 3 tokens
    LResult := LLimiter.TryAcquireN(3.0);
    Check(rlAllowed = LResult, 'Should allow 3');

    // Only 2 left, try 3
    LResult := LLimiter.TryAcquireN(3.0);
    Check(rlRejected = LResult, 'Should reject 3 when only 2 left');

    // Can still get 2
    LResult := LLimiter.TryAcquireN(2.0);
    Check(rlAllowed = LResult, 'Should allow 2');
  finally
    LLimiter.Free;
  end;
end;

procedure TestRateLimiterRefillsFromElapsedTime;
var
  LLimiter: TTokenBucketLimiter;
begin
  LLimiter := TTokenBucketLimiter.Create(20.0, 1.0);
  try
    Check(LLimiter.TryAcquire = rlAllowed, 'Initial burst token should be available');
    Check(LLimiter.TryAcquire = rlRejected, 'Exhausted bucket should reject');
    Sleep(60);
    Check(LLimiter.TryAcquire = rlAllowed, 'Elapsed time should refill one token');
  finally
    LLimiter.Free;
  end;
end;

procedure TestRateLimiterRejectsNonFiniteInputs;
var
  LLimiter: TTokenBucketLimiter;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    LLimiter := TTokenBucketLimiter.Create(NaN, 1.0);
    LLimiter.Free;
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'NaN rate must be rejected');

  LRaised := False;
  try
    LLimiter := TTokenBucketLimiter.Create(1.0, Infinity);
    LLimiter.Free;
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'Infinite burst must be rejected');
end;

begin
  WriteLn('=== test_lockfree_ratelimit ===');
  WriteLn;

  TestRateLimiterBasic;
  WriteLn('  + Basic acquire');

  TestRateLimiterBurstExhausted;
  WriteLn('  + Burst exhausted');

  TestRateLimiterClose;
  WriteLn('  + Close semantics');

  TestRateLimiterAcquireN;
  WriteLn('  + AcquireN');

  TestRateLimiterRejectsNonFiniteInputs;
  WriteLn('  + Finite input validation');

  TestRateLimiterRefillsFromElapsedTime;
  WriteLn('  + Elapsed-time refill');

  WriteLn;
  WriteLn('All rate limiter tests passed!');
end.
