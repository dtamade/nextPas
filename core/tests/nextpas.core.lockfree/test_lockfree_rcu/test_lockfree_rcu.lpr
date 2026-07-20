program test_lockfree_rcu;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  nextpas.core.lockfree.rcu,
  nextpas.core.lockfree,
  nextpas.core.atomic,
  nextpas.core.platform.thread,
  nextpas.core.test;

type
  TIntPublisher = specialize TRcuPublisher<Int64>;
  PRcuSynchronizeArgs = ^TRcuSynchronizeArgs;
  TRcuSynchronizeArgs = record
    Domain: TRcuDomain;
    Started: PInt32;
    Done: PInt32;
  end;

function RcuSynchronizeThread(AArg: Pointer): Pointer; cdecl;
var
  LArgs: PRcuSynchronizeArgs;
begin
  LArgs := PRcuSynchronizeArgs(AArg);
  atomic_store(LArgs^.Started^, 1, mo_release);
  LArgs^.Domain.Synchronize;
  atomic_store(LArgs^.Done^, 1, mo_release);
  Result := nil;
end;

procedure TestRcuDomainBasic;
var
  LDomain: TRcuDomain;
  LGuard: TRcuGuard;
begin
  LDomain := TRcuDomain.Create;
  try
    LDomain.EnterRead(LGuard);
    Check(LGuard.ReaderIndex >= 0, 'Reader index should be valid');
    Check(LGuard.ReaderIndex < 64, 'Reader index should be < 64');
    LDomain.ExitRead(LGuard);

    Check(not LDomain.IsClosed, 'Should not be closed');
  finally
    LDomain.Free;
  end;
end;

procedure TestRcuDomainClose;
var
  LDomain: TRcuDomain;
begin
  LDomain := TRcuDomain.Create;
  try
    LDomain.Close;
    Check(LDomain.IsClosed, 'Should be closed');
  finally
    LDomain.Free;
  end;
end;

procedure TestRcuDomainSynchronize;
var
  LDomain: TRcuDomain;
  LGuard: TRcuGuard;
begin
  LDomain := TRcuDomain.Create;
  try
    LDomain.EnterRead(LGuard);
    LDomain.ExitRead(LGuard);
    LDomain.Synchronize;
    // Should complete without hanging
    Check(True, 'Synchronize completed');
  finally
    LDomain.Free;
  end;
end;

procedure TestRcuSynchronizeWaitsForNestedGuard;
var
  LDomain: TRcuDomain;
  LGuard1, LGuard2: TRcuGuard;
  LArgs: TRcuSynchronizeArgs;
  LStarted, LDone: Int32;
  LThread: TPlatformThreadHandle;
  LRetVal: Pointer;
  LReturnedEarly: Boolean;
  LSpin: Integer;
begin
  LDomain := TRcuDomain.Create;
  LStarted := 0;
  LDone := 0;
  try
    LDomain.EnterRead(LGuard1);
    LDomain.EnterRead(LGuard2);
    LDomain.ExitRead(LGuard1);

    LArgs.Domain := LDomain;
    LArgs.Started := @LStarted;
    LArgs.Done := @LDone;
    CheckEqual(Int64(0), Int64(platform_thread_create(LThread,
      @RcuSynchronizeThread, @LArgs)), 'RCU synchronize thread must start');

    for LSpin := 1 to 1000 do
    begin
      if atomic_load(LStarted, mo_acquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    platform_thread_sleep_ns(10000000);
    LReturnedEarly := atomic_load(LDone, mo_acquire) <> 0;

    LDomain.ExitRead(LGuard2);
    CheckEqual(Int64(0), Int64(platform_thread_join(LThread, LRetVal)),
      'RCU synchronize thread must join');

    Check(not LReturnedEarly,
      'Synchronize must not finish while a nested guard remains in the shared reader slot');
    CheckEqual(Int32(1), atomic_load(LDone, mo_acquire),
      'Synchronize must finish after the final nested guard exits');
  finally
    LDomain.Free;
  end;
end;

procedure TestRcuPublisherBasic;
var
  LPublisher: TIntPublisher;
  LValue: Int64;
begin
  LPublisher := TIntPublisher.Create(42);
  try
    Check(LPublisher.Read(LValue), 'Should read successfully');
    CheckEqual(Int64(42), LValue);

    LPublisher.Update(100);
    Check(LPublisher.Read(LValue), 'Should read after update');
    CheckEqual(Int64(100), LValue);
  finally
    LPublisher.Free;
  end;
end;

procedure TestRcuPublisherMultipleUpdates;
var
  LPublisher: TIntPublisher;
  LValue: Int64;
  LI: Integer;
begin
  LPublisher := TIntPublisher.Create(0);
  try
    for LI := 1 to 10 do
      LPublisher.Update(LI);

    Check(LPublisher.Read(LValue), 'Should read');
    CheckEqual(Int64(10), LValue);
  finally
    LPublisher.Free;
  end;
end;

procedure TestRcuPublisherClose;
var
  LPublisher: TIntPublisher;
  LValue: Int64;
begin
  LPublisher := TIntPublisher.Create(42);
  try
    LPublisher.Close;
    Check(LPublisher.IsClosed, 'Should be closed');
    Check(not LPublisher.Read(LValue), 'Should not read after close');
  finally
    LPublisher.Free;
  end;
end;

procedure TestRcuPublisherDefault;
var
  LPublisher: TIntPublisher;
  LValue: Int64;
begin
  LPublisher := TIntPublisher.Create(0);
  try
    Check(LPublisher.Read(LValue), 'Should read default');
    CheckEqual(Int64(0), LValue);
  finally
    LPublisher.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_rcu ===');
  WriteLn;

  TestRcuDomainBasic;
  WriteLn('  + Domain basic');

  TestRcuDomainClose;
  WriteLn('  + Domain close');

  TestRcuDomainSynchronize;
  WriteLn('  + Domain synchronize');

  TestRcuSynchronizeWaitsForNestedGuard;
  WriteLn('  + Synchronize waits for nested guard');

  TestRcuPublisherBasic;
  WriteLn('  + Publisher basic');

  TestRcuPublisherMultipleUpdates;
  WriteLn('  + Publisher multiple updates');

  TestRcuPublisherClose;
  WriteLn('  + Publisher close');

  TestRcuPublisherDefault;
  WriteLn('  + Publisher default');

  WriteLn;
  WriteLn('All RCU tests passed!');
end.
