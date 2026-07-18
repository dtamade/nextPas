program test_lockfree_semaphore;

{$mode objfpc}{$H+}

uses
  nextpas.core.lockfree.semaphore,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.test;

procedure TestSemaphoreBasic;
var
  LSemaphore: TConcurrentSemaphore;
begin
  LSemaphore := TConcurrentSemaphore.Create(3);
  try
    // Initial state
    Check(not LSemaphore.IsClosed, 'Semaphore should not be closed');
    CheckEqual(Int64(3), LSemaphore.AvailablePermits);
    CheckEqual(Int64(3), LSemaphore.MaxPermits);

    // Acquire permits
    Check(LSemaphore.TryAcquire, 'Should acquire permit');
    CheckEqual(Int64(2), LSemaphore.AvailablePermits);

    Check(LSemaphore.TryAcquire, 'Should acquire permit');
    CheckEqual(Int64(1), LSemaphore.AvailablePermits);

    Check(LSemaphore.TryAcquire, 'Should acquire permit');
    CheckEqual(Int64(0), LSemaphore.AvailablePermits);

    // No more permits
    Check(not LSemaphore.TryAcquire, 'Should not acquire when full');

    // Release permits
    LSemaphore.Release;
    CheckEqual(Int64(1), LSemaphore.AvailablePermits);

    LSemaphore.Release;
    CheckEqual(Int64(2), LSemaphore.AvailablePermits);

    LSemaphore.Release;
    CheckEqual(Int64(3), LSemaphore.AvailablePermits);
  finally
    LSemaphore.Free;
  end;
end;

procedure TestSemaphoreClose;
var
  LSemaphore: TConcurrentSemaphore;
begin
  LSemaphore := TConcurrentSemaphore.Create(2);
  try
    LSemaphore.TryAcquire;
    LSemaphore.Close;
    Check(LSemaphore.IsClosed, 'Semaphore should be closed');

    // Can still release
    LSemaphore.Release;

    // Cannot acquire after close
    Check(not LSemaphore.TryAcquire, 'Should not acquire after close');
  finally
    LSemaphore.Free;
  end;
end;

procedure TestSemaphoreSinglePermit;
var
  LSemaphore: TConcurrentSemaphore;
begin
  LSemaphore := TConcurrentSemaphore.Create(1);
  try
    Check(LSemaphore.TryAcquire, 'Should acquire permit');
    Check(not LSemaphore.TryAcquire, 'Should not acquire when full');

    LSemaphore.Release;
    Check(LSemaphore.TryAcquire, 'Should acquire after release');
  finally
    LSemaphore.Free;
  end;
end;

procedure TestSemaphoreReleaseIsBounded;
var
  LSemaphore: TConcurrentSemaphore;
begin
  LSemaphore := TConcurrentSemaphore.Create(2);
  try
    Check(LSemaphore.TryAcquire, 'Should acquire first permit');
    Check(LSemaphore.TryAcquire, 'Should acquire second permit');
    CheckEqual(Int64(0), LSemaphore.AvailablePermits);

    LSemaphore.Release;
    LSemaphore.Release;
    LSemaphore.Release;

    CheckEqual(Int64(2), LSemaphore.AvailablePermits, 'Release must not exceed max permits');
  finally
    LSemaphore.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_semaphore ===');
  WriteLn;

  TestSemaphoreBasic;
  WriteLn('  + Basic acquire/release');

  TestSemaphoreClose;
  WriteLn('  + Close semantics');

  TestSemaphoreSinglePermit;
  WriteLn('  + Single permit');

  TestSemaphoreReleaseIsBounded;
  WriteLn('  + Bounded release');

  WriteLn;
  WriteLn('All semaphore tests passed!');
end.
